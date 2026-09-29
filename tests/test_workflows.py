#!/usr/bin/env python3
"""Exercise README workflows in disposable fixtures; no downloads or hardware tools.

Run: python3 -m unittest discover -s tests -v
Build commands and mountpoint are mocked. These tests check orchestration and
artifact destinations, not the correctness of generated FPGA/Linux binaries.
"""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

REPO = Path(__file__).resolve().parents[1]


class Workflows(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='bytepipe-')
        self.addCleanup(self.temp.cleanup)
        self.base = Path(self.temp.name)
        self.repo = self.base / 'repo'
        shutil.copytree(REPO / 'sw', self.repo / 'sw')
        self.boot = self.base / 'BOOT partition'
        self.boot.mkdir()
        self.prebuilt = self.repo / 'prebuilt'
        self.prebuilt.mkdir()
        for name in ['Image', 'system.dtb', 'boot.scr', 'u-boot.elf',
                     'BOOT_3CG.BIN', 'BOOT_3EG.BIN',
                     'zynqmp_fsbl_3cg.elf', 'zynqmp_fsbl_3eg.elf',
                     '3CG/system_top.xsa', '3EG/system_top.xsa']:
            path = self.prebuilt / name
            path.parent.mkdir(exist_ok=True)
            path.write_text(name)
        self.bin = self.base / 'bin'
        self.bin.mkdir()
        self.env = dict(os.environ, PATH=f'{self.bin}:{os.environ["PATH"]}',
                        BOOT_PATH=str(self.boot), MY_APP_DIR='/deliberately/wrong')
        self.env.pop('CROSS_COMPILE', None)
        self.mock('mountpoint', 'exit 0')

    def mock(self, name, body):
        path = self.bin / name
        path.write_text('#!/usr/bin/env bash\nset -eu\n' + body + '\n')
        path.chmod(0o755)

    def run_script(self, name, *args, ok=True):
        result = subprocess.run(['bash', str(self.repo / 'sw' / name), *args],
                                cwd=self.base, env=self.env, text=True,
                                stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        if ok:
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        else:
            self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
        return result

    def test_prebuilt_pipeline_both_models(self):
        self.run_script('setup-workspace.sh')
        for model in ['3CG', '3EG']:
            self.run_script('install-kernel.sh', 'prebuilt')
            self.run_script('use-prebuilt-boot-bin.sh', model)
            self.run_script('use-prebuilt-dtb.sh')
            self.run_script('use-prebuilt-xsa.sh', model)
            self.run_script('use-prebuilt-uboot.sh')
            self.run_script('finalize-sd.sh')
            self.assertEqual((self.boot / 'Image').read_text(), 'Image')
            self.assertEqual((self.boot / 'BOOT.BIN').read_text(), f'BOOT_{model}.BIN')
            self.assertEqual((self.boot / 'system.dtb').read_text(), 'system.dtb')
            self.assertEqual((self.boot / 'boot.scr').read_text(), 'boot.scr')
            self.assertEqual((self.repo / 'workspace/system_top.xsa').read_text(),
                             f'{model}/system_top.xsa')
        (self.boot / 'zynqmp-common').mkdir()
        (self.boot / 'zynqmp-common/Image').write_text('stock')
        self.run_script('install-kernel.sh', 'stock', str(self.boot))
        self.assertEqual((self.boot / 'Image').read_text(), 'stock')

    def test_flash_mode_forwards_arguments_without_running_disk_tools(self):
        self.mock('python3', "printf '%s\\n' \"$@\"")
        result = self.run_script('install-kernel.sh', 'stock', '--device', '/dev/sdz',
                                 '--cache-dir', '/tmp/cache with spaces')
        self.assertEqual(result.stdout.splitlines(),
                         [str(self.repo / 'sw/flash-kuiper.py'), '--kernel', 'stock',
                          '--device', '/dev/sdz', '--cache-dir', '/tmp/cache with spaces'])

    def test_invalid_inputs_fail_before_copy(self):
        self.run_script('use-prebuilt-boot-bin.sh', 'wrong', ok=False)
        self.run_script('install-kernel.sh', 'wrong', ok=False)
        self.run_script('use-prebuilt-dtb.sh', 'relative', ok=False)
        self.run_script('finalize-sd.sh', ok=False)
        self.mock('mountpoint', 'exit 1')
        self.run_script('use-prebuilt-dtb.sh', ok=False)
        self.assertEqual(list(self.boot.iterdir()), [])

    def test_source_build_orchestration(self):
        self.mock('aarch64-linux-gnu-gcc', 'exit 0')
        self.mock('git', '''target="${@: -1}"
mkdir -p "$target/arch/arm64/boot/dts/xilinx" "$target/arch/arm/dts"
printf '# test\\n' > "$target/arch/arm64/boot/dts/xilinx/Makefile"
printf '# test\\n' > "$target/arch/arm/dts/Makefile"''')
        self.mock('make', '''case "$*" in
  *xilinx/bytepipe.dtb*)
    test -f arch/arm64/boot/dts/xilinx/bytepipe.dts
    printf dtb > arch/arm64/boot/dts/xilinx/bytepipe.dtb ;;
  *DEVICE_TREE=bytepipe_uboot*)
    test -f arch/arm/dts/bytepipe_uboot.dts
    printf elf > u-boot.elf ;;
  *../hdl/Makefile*) printf xsa > system_top.xsa ;;
esac''')
        self.run_script('compile-dtb.sh')
        self.assertEqual((self.boot / 'system.dtb').read_text(), 'dtb')
        self.run_script('compile-uboot.sh')
        self.assertEqual((self.repo / 'workspace/u-boot.elf').read_text(), 'elf')
        # A rerun must preserve existing source rather than clean/reset it.
        marker = self.repo / 'u-boot-xlnx/keep-me'
        marker.write_text('user work')
        self.run_script('compile-uboot.sh', ok=False)
        self.assertEqual(marker.read_text(), 'user work')
        xilinx = self.base / 'Xilinx tools'
        for tool in ['Vivado', 'Vitis']:
            settings = xilinx / tool / '2023.2/settings64.sh'
            settings.parent.mkdir(parents=True)
            settings.write_text(':\n')
        self.env['XILINX_ROOT'] = str(xilinx)
        for tool in ['vivado', 'vitis', 'xsct', 'bootgen']:
            self.mock(tool, 'exit 0')
        self.run_script('compile-xsa.sh', '3CG')
        self.assertEqual((self.repo / 'workspace/system_top.xsa').read_text(), 'xsa')
        # Isolate the wrapper from the legacy proprietary-tool builder.
        helper = self.repo / 'sw/build_zynqmp_boot_bin_external_fsbl.sh'
        helper.write_text('''#!/bin/bash
set -eu
[[ "$*" == 'system_top.xsa u-boot.elf download' ]]
test -f fsbl.elf
mkdir -p output_boot_bin
printf boot > output_boot_bin/BOOT.BIN
''')
        (self.boot / 'Image').write_text('kernel sentinel')
        self.run_script('compile-boot-bin.sh', '3EG')
        self.assertEqual((self.boot / 'BOOT.BIN').read_text(), 'boot')
        self.assertEqual((self.boot / 'Image').read_text(), 'kernel sentinel')
        self.assertEqual((self.repo / 'workspace/fsbl.elf').read_text(),
                         'zynqmp_fsbl_3eg.elf')

    def test_help_has_no_side_effects(self):
        for script in (self.repo / 'sw').glob('*.sh'):
            if 'workflow-common.sh' in script.read_text() and script.name != 'workflow-common.sh':
                self.run_script(script.name, '--help')
        self.assertFalse((self.repo / 'workspace').exists())

    def test_readme_local_links(self):
        import re
        for target in re.findall(r'\]\(([^)]+)\)', (REPO / 'README.md').read_text()):
            if not target.startswith(('http', '#')):
                self.assertTrue((REPO / target).exists(), target)


if __name__ == '__main__':
    unittest.main()
