#!/usr/bin/env python3
"""Exercise installer sequencing with fake package commands; never calls sudo/DNF."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]

class InstallerTests(unittest.TestCase):
    def run_installer(self, *args, scenario='ok', version='50.4'):
        with tempfile.TemporaryDirectory(prefix='mutter-unmuted-test-') as tmp:
            base = Path(tmp)
            project = base / 'project with spaces'
            shutil.copytree(ROOT, project, ignore=shutil.ignore_patterns('build', '.git', '__pycache__'))
            commands = base / 'bin'
            commands.mkdir()
            log = base / 'commands.log'
            shim = commands / 'shim'
            shim.write_text('''#!/usr/bin/env python3
import os, pathlib, shutil, sys
name = pathlib.Path(sys.argv[0]).name
args = sys.argv[1:]
with open(os.environ['TEST_LOG'], 'a') as f:
    f.write(name + ' ' + repr(args) + '\\n')
scenario = os.environ['TEST_SCENARIO']
version = os.environ['TEST_VERSION']
if name == 'rpm':
    if '-i' in args:
        top = next(a[len('_topdir '):] for a in args if a.startswith('_topdir '))
        shutil.copy(pathlib.Path(os.environ['TEST_ROOT']) / 'packaging/nobara/mutter.spec',
                    pathlib.Path(top) / 'SPECS/mutter.spec')
    else:
        q = args[args.index('--qf') + 1]
        fields = {'NAME': 'mutter-common' if 'mutter-common' in args[-1] else 'mutter',
                  'VERSION': version, 'RELEASE': '1.fc44', 'ARCH': 'x86_64', 'SOURCEPACKAGE': '1'}
        if scenario == 'source-mismatch' and '-qp' in args: fields['VERSION'] = '99.0'
        for k,v in fields.items(): q = q.replace('%{' + k + '}', v)
        print(q, end='')
elif name == 'nproc': print('4')
elif name in ('sudo', 'rpmkeys'): pass
elif name == 'dnf':
    if scenario == 'unavailable': sys.exit(1)
    dest = pathlib.Path(args[args.index('--destdir') + 1])
    (dest / 'mutter.src.rpm').touch()
elif name == 'curl':
    pathlib.Path(args[args.index('--output') + 1]).write_text('test archive')
elif name == 'sha256sum':
    sys.stdin.read()
    sys.exit(1 if scenario == 'checksum' else 0)
elif name == 'rpmbuild':
    if scenario == 'build': sys.exit(1)
    top = next(a[len('_topdir '):] for a in args if a.startswith('_topdir '))
    for p in [f'x86_64/mutter-{version}-1.fc44.unmuted1.x86_64.rpm',
              f'noarch/mutter-common-{version}-1.fc44.unmuted1.noarch.rpm']:
        dest = pathlib.Path(top) / 'RPMS' / p
        dest.parent.mkdir(parents=True, exist_ok=True)
        dest.touch()
''')
            shim.chmod(0o755)
            for name in ('rpm', 'nproc', 'sudo', 'dnf', 'rpmkeys', 'curl', 'sha256sum', 'rpmbuild'):
                (commands / name).symlink_to(shim)
            script = project / 'install.sh'
            script.write_text(script.read_text().replace('source /etc/os-release', 'ID=nobara; VERSION_ID=44'))
            env = dict(os.environ, PATH=f'{commands}:{os.environ["PATH"]}', TEST_ROOT=str(project),
                       TEST_LOG=str(log), TEST_SCENARIO=scenario, TEST_VERSION=version)
            result = subprocess.run(['bash', str(script), *args], env=env, text=True,
                                    stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
            return result, log.read_text() if log.exists() else ''

    def test_install(self):
        result, log = self.run_installer('--yes', '--jobs', '2')
        self.assertEqual(result.returncode, 0, result.stdout)
        self.assertIn("'_smp_build_ncpus 2'", log)
        self.assertIn("'builddep', '-y'", log)
        self.assertIn('mutter-common-50.4-1.fc44.unmuted1.noarch.rpm', log)
        self.assertLess(log.index('\nrpmbuild '), log.rindex('\nsudo '))

    def test_detects_other_installed_version(self):
        result, log = self.run_installer('--build-only', version='51.2')
        self.assertEqual(result.returncode, 0, result.stdout)
        self.assertIn('mutter-51.2-1.fc44.x86_64', log)
        self.assertIn('mutter-common-51.2-1.fc44.unmuted1.noarch.rpm', result.stdout)
        self.assertNotIn('sudo [\'dnf\', \'install\', \'/', log)

    def test_failures_never_install_runtime(self):
        for scenario in ('source-mismatch', 'build', 'unavailable'):
            with self.subTest(scenario=scenario):
                # Non-baseline version must never fall back to the 50.4 recipe.
                result, log = self.run_installer(scenario=scenario, version='51.2')
                self.assertNotEqual(result.returncode, 0)
                self.assertNotIn('sudo [\'dnf\', \'install\', \'/', log)

    def test_invalid_arguments(self):
        for args in (('--jobs', '0'), ('--jobs',), ('--unknown',)):
            result, log = self.run_installer(*args)
            self.assertEqual(result.returncode, 2)
            self.assertNotIn('sudo', log)

if __name__ == '__main__':
    unittest.main()
