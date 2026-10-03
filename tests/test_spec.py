#!/usr/bin/env python3
import importlib.util
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('prepare_spec', ROOT / 'tools/prepare-spec.py')
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)

class SpecTests(unittest.TestCase):
    def setUp(self):
        self.text = (ROOT / 'packaging/nobara/mutter.spec').read_text()

    def test_preserves_packaging_and_changes_version(self):
        result = module.prepare(self.text, '51.2', '4.fc45')
        self.assertIn('Version: 51.2', result)
        self.assertIn('Release: 4.fc45.unmuted5', result)
        self.assertIn('%meson -Degl_device=true', result)
        self.assertIn('mutter_increase_check_alive_timeout.patch', result)
        self.assertNotIn('mutter-50.4-legacy-input.patch', result)
        self.assertEqual(result.count('mutter-unmuted.patch'), 1)
        self.assertLess(result.index('Patch10000:'), result.index('%description'))

    def test_reapplying_does_not_duplicate_patch_or_tests(self):
        first = module.prepare(self.text, '50.4', '1.fc44')
        second = module.prepare(first, '50.4', '1.fc44')
        self.assertEqual(second.count('mutter-unmuted.patch'), 1)
        self.assertEqual(second.count('xwayland-legacy-input'), 1)
        self.assertEqual(second.count('wayland-xdg-session-management'), 1)

    def test_xwayland_spec_keeps_its_checks(self):
        text = """Name: xorg-x11-server-Xwayland
Version: 24.1.13
Release: 2%{?dist}
Patch1: distro.patch
%description
Xwayland
%prep
%autosetup -S git_am
%build
%meson_build
%install
%meson_install
%check
desktop-file-validate example.desktop
"""
        result = module.prepare(text, '24.1.14', '3.fc45', 'xwayland')
        self.assertIn('Version: 24.1.14', result)
        self.assertIn('xwayland-unmuted.patch', result)
        self.assertIn('desktop-file-validate example.desktop', result)
        self.assertNotIn('xwayland-legacy-input --print-errorlogs', result)
        self.assertIn('%autosetup -S git_am', result)

    def test_rejects_unsupported_prep(self):
        for prep in ('%setup -q', '%autosetup -N'):
            with self.assertRaises(ValueError):
                module.prepare(self.text.replace('%autosetup -S git', prep), '50.4', '1.fc44')

if __name__ == '__main__':
    unittest.main()
