#!/usr/bin/env python3
"""Linux download/flash implementation for install-kernel.sh (no third-party modules)."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import zipfile

# Published by ADI: https://wiki.analog.com/resources/tools-software/linux-software/adi-kuiper_images/release_notes
IMAGE_URL = 'https://swdownloads.analog.com/cse/kuiper/image_2025-03-18-ADI-Kuiper-full.zip'
ZIP_MD5 = '6c92259dd61520d08244012f6c92d7c6'
IMAGE_MD5 = '873b4977617e40725025aa4958f3ca7e'
REPO = Path(__file__).resolve().parents[1]


def run(*args, capture=False):
    result = subprocess.run([str(a) for a in args], check=True, text=True,
                            stdout=subprocess.PIPE if capture else None)
    return result.stdout.strip() if capture else None


def digest(path):
    value = hashlib.md5()  # ADI publishes MD5 for corruption detection, not authentication.
    with path.open('rb') as stream:
        for block in iter(lambda: stream.read(8 * 1024 * 1024), b''):
            value.update(block)
    return value.hexdigest()


def download_image(cache):
    cache.mkdir(parents=True, exist_ok=True)
    archive = cache / 'image_2025-03-18-ADI-Kuiper-full.zip'
    image = cache / '2025-03-18-ADI-Kuiper-full.img'
    if image.is_file() and digest(image) == IMAGE_MD5:
        print(f'Using verified cached image: {image}', flush=True)
        return image
    if not archive.is_file() or digest(archive) != ZIP_MD5:
        partial = archive.with_suffix('.zip.part')
        print(f'Downloading {IMAGE_URL}', flush=True)
        run('curl', '--fail', '--location', '--proto', '=https', '--proto-redir', '=https',
            '--retry', '3', '--output', partial, IMAGE_URL)
        if digest(partial) != ZIP_MD5:
            partial.unlink()
            raise RuntimeError('Downloaded archive checksum does not match the ADI release.')
        partial.replace(archive)
    with zipfile.ZipFile(archive) as bundle:
        candidates = [entry for entry in bundle.infolist()
                      if not entry.is_dir() and entry.filename.endswith('.img')]
        if len(candidates) != 1:
            raise RuntimeError('Expected exactly one .img file in the Kuiper archive.')
        if shutil.disk_usage(cache).free < candidates[0].file_size:
            raise RuntimeError('Insufficient free space to extract the Kuiper image.')
        partial = image.with_suffix('.img.part')
        try:
            # Extract one stream to our own filename; never trust archive paths.
            with bundle.open(candidates[0]) as source, partial.open('wb') as dest:
                shutil.copyfileobj(source, dest, 8 * 1024 * 1024)
            if digest(partial) != IMAGE_MD5:
                raise RuntimeError('Extracted image checksum does not match the ADI release.')
            partial.replace(image)
        finally:
            partial.unlink(missing_ok=True)
    return image


def descendants(node):
    yield node
    for child in node.get('children', []):
        yield from descendants(child)


def inventory():
    return json.loads(run('lsblk', '--json', '--bytes', '--paths', '--output',
                          'NAME,TYPE,SIZE,RO,RM,TRAN,MODEL,SERIAL,MAJ:MIN,MOUNTPOINTS,FSTYPE,PARTN',
                          capture=True))['blockdevices']


def protected_devices(paths):
    protected = set()
    for path in paths:
        # findmnt also resolves device-mapper and partition-backed host mounts.
        data = json.loads(run('findmnt', '--json', '--target', path, '--output',
                              'MAJ:MIN', capture=True))
        entries = data.get('filesystems', [])
        if not entries:
            raise RuntimeError(f'Cannot determine the filesystem backing {path}.')
        protected.update(entry['maj:min'] for entry in entries)
    return protected


def validate_disk(device, tree, protected, image_size=0):
    matches = [node for root in tree for node in descendants(root) if node['name'] == device]
    if len(matches) != 1:
        raise RuntimeError('Target must identify exactly one disk in lsblk.')
    disk = matches[0]
    if disk['type'] != 'disk' or disk['ro']:
        raise RuntimeError('Target must be a writable whole disk, not a partition.')
    if not disk['rm'] and disk.get('tran') != 'usb':
        raise RuntimeError('Only removable media or USB disks may be flashed.')
    if int(disk['size']) < image_size:
        raise RuntimeError('The selected disk is smaller than the Kuiper image.')
    for node in descendants(disk):
        if node['maj:min'] in protected:
            raise RuntimeError('Refusing a disk backing a system, working, or download directory.')
        if node is not disk and node['type'] != 'part':
            raise RuntimeError('Refusing a disk with active RAID, LVM, or encrypted mappings.')
        if node.get('fstype') == 'swap':
            raise RuntimeError('Refusing a disk containing swap; use dedicated installation media.')
        for mount in node.get('mountpoints') or []:
            if mount and not mount.startswith(('/media/', '/run/media/', '/mnt/')):
                raise RuntimeError(f'Refusing a disk mounted at protected location {mount}.')
    return disk


def identity(disk):
    return tuple(disk.get(key) for key in ('name', 'maj:min', 'size', 'model', 'serial'))


def flash(device, image, kernel, mount_dir, cache):
    device = str(Path(device).resolve(strict=True))
    paths = ['/', '/boot', '/home', '/usr', '/var', str(REPO), str(cache), str(Path.cwd())]
    paths = [path for path in paths if Path(path).exists()]
    size = image.stat().st_size
    protected = protected_devices(paths)
    disk = validate_disk(device, inventory(), protected, size)
    initial = identity(disk)
    print('\nALL DATA ON THIS DISK WILL BE ERASED:', flush=True)
    run('lsblk', '--paths', '--output', 'NAME,SIZE,MODEL,SERIAL,TYPE,MOUNTPOINTS', device)
    reply = input(f'Type ERASE {device} to continue: ')
    if reply != f'ERASE {device}':
        raise RuntimeError('Cancelled; no disk was written.')
    run('sudo', '-v')
    disk = validate_disk(device, inventory(), protected_devices(paths), size)
    if identity(disk) != initial:
        raise RuntimeError('Device identity changed; refusing to flash.')
    for node in reversed(list(descendants(disk))):
        if any(node.get('mountpoints') or []):
            run('sudo', 'umount', '--all-targets', '--', node['name'])
    disk = validate_disk(device, inventory(), protected_devices(paths), size)
    if identity(disk) != initial or any(m for n in descendants(disk) for m in n.get('mountpoints') or []):
        raise RuntimeError('Disk changed or remains mounted; refusing to flash.')
    run('sudo', 'dd', f'if={image}', f'of={device}', 'bs=4M', 'conv=fsync', 'status=progress')
    print('Verifying the written image (this may take several minutes)...', flush=True)
    run('sudo', 'cmp', '--bytes', str(size), '--', image, device)
    run('sudo', 'partprobe', device)
    run('sudo', 'udevadm', 'settle')
    disk = validate_disk(device, inventory(), protected_devices(paths), size)
    if identity(disk) != initial:
        raise RuntimeError('Device identity changed after writing; refusing to mount.')
    parts = [node for node in descendants(disk)
             if node['type'] == 'part' and str(node.get('partn')) == '1' and node.get('fstype') == 'vfat']
    if len(parts) != 1:
        raise RuntimeError('Image written, but no FAT BOOT partition 1 was found. Reinsert the card and use copy-only mode.')
    part = parts[0]
    mounts = [m for m in part.get('mountpoints') or [] if m]
    mounted_here = False
    if mounts:
        boot = Path(mounts[0])
    else:
        boot = mount_dir
        boot.mkdir(parents=True, exist_ok=True)
        if boot.is_symlink() or os.path.ismount(boot) or any(boot.iterdir()):
            raise RuntimeError('BOOT mount directory must be empty and unmounted.')
        run('sudo', 'mount', '-t', 'vfat', '-o',
            f'uid={os.getuid()},gid={os.getgid()},nodev,nosuid,noexec', '--', part['name'], boot)
        mounted_here = True
    try:
        source = REPO / 'prebuilt/Image' if kernel == 'prebuilt' else boot / 'zynqmp-common/Image'
        if not source.is_file():
            raise RuntimeError(f'Kernel not found: {source}')
        run('sudo', 'cp', '--', source, boot / 'Image')
        run('sync')
    except BaseException:
        if mounted_here:
            run('sudo', 'umount', '--', boot)
        raise
    print(f'Image flashed, verified, and {kernel} kernel installed. BOOT remains mounted.')
    import shlex
    print(f'For the remaining README sections, run:\nexport BOOT_PATH={shlex.quote(str(boot))}')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--kernel', choices=['prebuilt', 'stock'], required=True)
    parser.add_argument('--device', required=True, help='Whole removable/USB disk, e.g. /dev/sdb')
    parser.add_argument('--cache-dir', type=Path, default=REPO / 'workspace/downloads')
    args = parser.parse_args()
    if sys.platform != 'linux':
        raise RuntimeError('Flashing is supported on Linux only.')
    if not sys.stdin.isatty():
        raise RuntimeError('Flashing requires an interactive terminal for erase confirmation.')
    for cmd in ['curl', 'lsblk', 'findmnt', 'sudo', 'umount', 'dd', 'cmp', 'partprobe', 'udevadm', 'mount', 'cp', 'sync']:
        if not shutil.which(cmd):
            raise RuntimeError(f'Required command not found: {cmd}')
    if args.kernel == 'prebuilt' and not (REPO / 'prebuilt/Image').is_file():
        raise RuntimeError('Prebuilt kernel is missing.')
    cache = args.cache_dir.resolve()
    cache.mkdir(parents=True, exist_ok=True)
    # Reject invalid/system disks before starting a large download, then recheck before writing.
    device = str(Path(args.device).resolve(strict=True))
    paths = [p for p in ['/', '/boot', '/home', '/usr', '/var', str(REPO), str(cache), str(Path.cwd())] if Path(p).exists()]
    validate_disk(device, inventory(), protected_devices(paths))
    image = download_image(cache)
    flash(device, image, args.kernel, REPO / 'workspace/sd-boot', cache)


if __name__ == '__main__':
    try:
        main()
    except (RuntimeError, OSError, ValueError, zipfile.BadZipFile, subprocess.CalledProcessError, EOFError) as error:
        sys.exit(f'Error: {error}')
    except KeyboardInterrupt:
        sys.exit('Interrupted. If flashing had started, the SD card may need to be flashed again.')
