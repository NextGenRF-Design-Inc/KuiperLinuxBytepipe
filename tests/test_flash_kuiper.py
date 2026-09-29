"""Tests use temporary files and mocked commands; they never open a real disk."""
import copy
import importlib.util
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
import zipfile

SPEC = importlib.util.spec_from_file_location('flash_kuiper', Path(__file__).resolve().parents[1] / 'sw/flash-kuiper.py')
flash = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(flash)


def disk(name='/dev/sdz'):
    return dict(name=name, type='disk', size=1000000, ro=False, rm=True, tran='usb',
                model='Test SD', serial='123', **{'maj:min': '8:240'}, mountpoints=[None],
                children=[dict(name=name+'1', type='part', size=900000, ro=False, rm=True,
                               **{'maj:min': '8:241'}, mountpoints=[None], fstype='vfat', partn=1)])


class DiskSafety(unittest.TestCase):
    def test_accepts_removable_disk(self):
        node = disk()
        self.assertIs(flash.validate_disk('/dev/sdz', [node], {'8:0'}, 100), node)

    def test_rejects_system_partition_readonly_internal_small_and_mapped_disks(self):
        base = disk()
        cases = []
        for key, value in [('type', 'part'), ('ro', True), ('size', 1)]:
            node = copy.deepcopy(base)
            node[key] = value
            cases.append(node)
        internal = copy.deepcopy(base)
        internal.update(rm=False, tran='nvme')
        cases.append(internal)
        for field, value in [('mountpoints', ['/']), ('type', 'crypt'), ('fstype', 'swap')]:
            node = copy.deepcopy(base)
            node['children'][0][field] = value
            cases.append(node)
        for node in cases:
            with self.subTest(node=node), self.assertRaises(RuntimeError):
                flash.validate_disk('/dev/sdz', [node], set(), 100)
        with self.assertRaises(RuntimeError):
            flash.validate_disk('/dev/sdz', [base], {'8:241'}, 100)

    def fixture(self):
        temp = tempfile.TemporaryDirectory()
        self.addCleanup(temp.cleanup)
        base = Path(temp.name)
        device = base / 'device'
        device.touch()
        image = base / 'image'
        image.write_bytes(b'kuiper')
        node = disk(str(device))
        return base, device, image, node

    def test_cancel_never_writes(self):
        base, device, image, node = self.fixture()
        with patch.object(flash, 'inventory', return_value=[node]), \
             patch.object(flash, 'protected_devices', return_value=set()), \
             patch('builtins.input', return_value='no'), patch.object(flash, 'run') as run:
            with self.assertRaisesRegex(RuntimeError, 'Cancelled'):
                flash.flash(str(device), image, 'prebuilt', base/'mount', base)
            self.assertFalse(any('dd' in call.args for call in run.call_args_list))

    def test_write_verify_mount_copy_order(self):
        base, device, image, node = self.fixture()
        with patch.object(flash, 'inventory', return_value=[node]), \
             patch.object(flash, 'protected_devices', return_value=set()), \
             patch('builtins.input', return_value=f'ERASE {device}'), \
             patch.object(flash, 'run') as run:
            flash.flash(str(device), image, 'prebuilt', base/'mount', base)
        commands = [call.args for call in run.call_args_list]
        indices = [next(i for i, cmd in enumerate(commands) if len(cmd) > 1 and cmd[1] == name)
                   for name in ['dd', 'cmp', 'partprobe', 'mount', 'cp']]
        self.assertEqual(indices, sorted(indices))
        self.assertIn(f'of={device}', commands[indices[0]])
        self.assertIn(str(image.stat().st_size), commands[indices[1]])

    def test_identity_change_prevents_write(self):
        base, device, image, node = self.fixture()
        changed = copy.deepcopy(node)
        changed['serial'] = 'replacement'
        with patch.object(flash, 'inventory', side_effect=[[node], [changed]]), \
             patch.object(flash, 'protected_devices', return_value=set()), \
             patch('builtins.input', return_value=f'ERASE {device}'), patch.object(flash, 'run') as run:
            with self.assertRaisesRegex(RuntimeError, 'identity changed'):
                flash.flash(str(device), image, 'prebuilt', base/'mount', base)
            self.assertFalse(any('dd' in call.args for call in run.call_args_list))

    def test_still_mounted_prevents_write(self):
        base, device, image, node = self.fixture()
        node['children'][0]['mountpoints'] = ['/media/test/BOOT']
        with patch.object(flash, 'inventory', return_value=[node]), \
             patch.object(flash, 'protected_devices', return_value=set()), \
             patch('builtins.input', return_value=f'ERASE {device}'), patch.object(flash, 'run') as run:
            with self.assertRaisesRegex(RuntimeError, 'remains mounted'):
                flash.flash(str(device), image, 'prebuilt', base/'mount', base)
            self.assertFalse(any('dd' in call.args for call in run.call_args_list))

    def test_readback_failure_prevents_mount_and_copy(self):
        base, device, image, node = self.fixture()
        calls = []
        def command(*args, **kwargs):
            calls.append(args)
            if 'cmp' in args:
                raise RuntimeError('readback mismatch')
        with patch.object(flash, 'inventory', return_value=[node]), \
             patch.object(flash, 'protected_devices', return_value=set()), \
             patch('builtins.input', return_value=f'ERASE {device}'), patch.object(flash, 'run', side_effect=command):
            with self.assertRaisesRegex(RuntimeError, 'readback mismatch'):
                flash.flash(str(device), image, 'prebuilt', base/'mount', base)
        self.assertFalse(any('mount' in c or 'cp' in c for c in calls))


class Downloads(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.cache = Path(self.temp.name)
        self.archive = self.cache/'image_2025-03-18-ADI-Kuiper-full.zip'
        self.image = self.cache/'2025-03-18-ADI-Kuiper-full.img'

    def test_verified_cache_skips_download(self):
        self.image.write_bytes(b'image')
        with patch.object(flash, 'IMAGE_MD5', flash.digest(self.image)), patch.object(flash, 'run') as run:
            self.assertEqual(flash.download_image(self.cache), self.image)
            run.assert_not_called()

    def test_extracts_only_image_to_fixed_path(self):
        with zipfile.ZipFile(self.archive, 'w') as archive:
            archive.writestr('../../escape.img', b'image')
        import hashlib
        with patch.object(flash, 'ZIP_MD5', flash.digest(self.archive)), \
             patch.object(flash, 'IMAGE_MD5', hashlib.md5(b'image').hexdigest()), \
             patch.object(flash, 'run') as run:
            self.assertEqual(flash.download_image(self.cache).read_bytes(), b'image')
            run.assert_not_called()

    def test_download_verifies_archive_and_image(self):
        fixture = self.cache / 'fixture.zip'
        with zipfile.ZipFile(fixture, 'w') as archive:
            archive.writestr('kuiper.img', b'image')
        import hashlib
        def download(*args):
            self.assertIn('=https', args)
            Path(args[args.index('--output') + 1]).write_bytes(fixture.read_bytes())
        with patch.object(flash, 'ZIP_MD5', flash.digest(fixture)), \
             patch.object(flash, 'IMAGE_MD5', hashlib.md5(b'image').hexdigest()), \
             patch.object(flash, 'run', side_effect=download):
            self.assertEqual(flash.download_image(self.cache).read_bytes(), b'image')
        self.assertTrue(self.archive.exists())

    def test_bad_download_is_rejected(self):
        def download(*args):
            Path(args[args.index('--output') + 1]).write_bytes(b'bad download')
        with patch.object(flash, 'run', side_effect=download):
            with self.assertRaisesRegex(RuntimeError, 'archive checksum'):
                flash.download_image(self.cache)
        self.assertFalse(self.image.exists())
        self.assertFalse(self.archive.with_suffix('.zip.part').exists())

    def test_bad_extracted_image_is_rejected(self):
        with zipfile.ZipFile(self.archive, 'w') as archive:
            archive.writestr('kuiper.img', b'bad image')
        with patch.object(flash, 'ZIP_MD5', flash.digest(self.archive)):
            with self.assertRaisesRegex(RuntimeError, 'Extracted image checksum'):
                flash.download_image(self.cache)
        self.assertFalse(self.image.exists())
        self.assertFalse(self.image.with_suffix('.img.part').exists())
