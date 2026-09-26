#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-or-later
# Called by install.sh. All build operations run unprivileged.
set -euo pipefail
root=$1
build_root=$2
version=$3
release=$4
arch=$5
jobs=$6
assume_yes=$7
source_rpm=$8
mkdir -p "$build_root"/{BUILD,BUILDROOT,RPMS,SOURCES,SPECS,SRPMS,download,extracted}
flags=()
$assume_yes && flags+=(-y)
if [[ -z $source_rpm ]]; then
  dnf download --source --destdir "$build_root/download" "xorg-x11-server-Xwayland-${version}-${release}.${arch}" || {
    echo 'Matching Xwayland source unavailable. Supply --xwayland-source-rpm /path/to/matching.src.rpm' >&2
    exit 1
  }
  shopt -s nullglob
  sources=("$build_root/download/"*.src.rpm)
  (( ${#sources[@]} == 1 )) || { echo 'Expected one Xwayland source RPM.' >&2; exit 1; }
  source_rpm=${sources[0]}
fi
[[ $(rpm -qp --qf '%{NAME} %{VERSION} %{SOURCEPACKAGE}' "$source_rpm") == "xorg-x11-server-Xwayland $version 1" ]] || {
  echo 'Xwayland source name/version does not match the installed package.' >&2; exit 1;
}
source_release=$(rpm -qp --qf '%{RELEASE}' "$source_rpm")
source_base=$(printf '%s' "$source_release" | sed -E 's/\.unmuted[0-9]+$//')
[[ $source_base == "$release" ]] || { echo 'Xwayland source release mismatch.' >&2; exit 1; }
rpmkeys --checksig "$source_rpm"
rpm -i --define "_topdir $build_root" "$source_rpm"
spec="$build_root/SPECS/xorg-x11-server-Xwayland.spec"
python3 "$root/tools/prepare-spec.py" "$spec" "$version" "$release" xwayland
cp "$root/patches/xwayland-unmuted.patch" "$build_root/SOURCES/"
sudo dnf builddep "${flags[@]}" "$spec"
echo "Building Xwayland $version; log: $build_root/build.log"
if ! rpmbuild -ba --define "_topdir $build_root" --define "_smp_build_ncpus $jobs" "$spec" > "$build_root/build.log" 2>&1; then
  tail -n 60 "$build_root/build.log" >&2
  echo 'Xwayland build failed; neither patched component has been installed.' >&2
  exit 1
fi
packages=()
while IFS= read -r -d '' package; do
  if [[ $(rpm -qp --qf '%{NAME}' "$package") == xorg-x11-server-Xwayland ]]; then
    packages+=("$package")
  fi
done < <(find "$build_root/RPMS" -type f -name '*.rpm' -print0)
(( ${#packages[@]} == 1 )) || { echo 'Expected one Xwayland runtime RPM.' >&2; exit 1; }
[[ $(rpm -qp --qf '%{VERSION}' "${packages[0]}") == "$version" ]] || exit 1
printf '%s\n' "${packages[0]}" > "$build_root/runtime-rpm.txt"
# Run paired tests with the packaged executable without installing it system-wide.
(cd "$build_root/extracted"; rpm2cpio "${packages[0]}" | cpio -idm --quiet './usr/bin/Xwayland')
[[ -x $build_root/extracted/usr/bin/Xwayland ]] || { echo 'Missing packaged Xwayland binary.' >&2; exit 1; }
