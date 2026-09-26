#!/usr/bin/env python3
"""Add the feature to a matching distribution spec without replacing its packaging."""
import re
import sys
from pathlib import Path


def prepare(text, version, release):
    if not re.search(r'^%autosetup\b', text, re.M):
        raise ValueError('This spec does not use %autosetup; manual adaptation is required.')
    if re.search(r'^%autosetup[^\n]*\s-N(?:\s|$)', text, re.M):
        raise ValueError('%autosetup -N skips patches; manual adaptation is required.')
    if not re.search(r'^%prep\b', text, re.M) or not re.search(r'^%install\b', text, re.M):
        raise ValueError('Missing expected RPM sections; manual adaptation is required.')
    # Rebuilding our previous SRPM replaces the existing patch instead of applying it twice.
    text = re.sub(r'^Patch\d*:\s*.*(?:mutter-50\.4-legacy-input|mutter-unmuted)\.patch\s*$', '', text, flags=re.M)
    text, count = re.subn(r'^Version:\s*.*$', f'Version: {version}', text, count=1, flags=re.M)
    if count != 1:
        raise ValueError('Missing Version tag.')
    text, count = re.subn(r'^Release:\s*.*$', f'Release: {release}.unmuted1', text, count=1, flags=re.M)
    if count != 1:
        raise ValueError('Missing Release tag.')
    # Explicitly numbered high patch avoids collisions with distro auto numbering.
    numbers = [int(n) for n in re.findall(r'^Patch(\d+):', text, re.M)]
    number = max([9999, *numbers]) + 1
    text, count = re.subn(r'^%description\b', f'Patch{number}: mutter-unmuted.patch\n\n%description', text, count=1, flags=re.M)
    if count != 1:
        raise ValueError('Missing main description boundary.')
    check = 'env -u GDK_BACKEND -u XAUTHORITY meson test -C %{_vpath_builddir} xwayland xwayland-legacy-input --print-errorlogs'
    if 'xwayland-legacy-input --print-errorlogs' not in text:
        if re.search(r'^%check\s*$', text, re.M):
            text = re.sub(r'^%check\s*$', '%check\n' + check, text, count=1, flags=re.M)
        else:
            text = text.replace('%install', '%check\n' + check + '\n\n%install', 1)
    return text


if __name__ == '__main__':
    path = Path(sys.argv[1])
    try:
        result = prepare(path.read_text(), sys.argv[2], sys.argv[3])
    except ValueError as error:
        sys.exit(str(error))
    path.write_text(result)
