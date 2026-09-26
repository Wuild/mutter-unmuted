#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-or-later
set -euo pipefail
usage() {
  cat <<'HELP'
Usage: ./install.sh [--build-only] [--yes] [--jobs N] [--source-rpm FILE] [--xwayland-source-rpm FILE]

Detect installed Mutter and Xwayland versions, obtain matching distribution source,
install build dependencies, apply the patch, build/test RPMs and install them.
Supports Fedora/Nobara RPM packaging; other distributions need a packaging port.
Run without sudo. sudo is used only for dependency/package installation.
  --build-only       Build without installing the runtime packages.
  --yes              Accept DNF transactions automatically.
  --jobs N           Parallel build jobs (default: at most 8).
  --source-rpm FILE  Use matching local Mutter source.
  --xwayland-source-rpm FILE  Use matching local Xwayland source.
HELP
}
build_only=false
assume_yes=false
source_rpm=''
xwayland_source_rpm=''
jobs=$(nproc)
(( jobs <= 8 )) || jobs=8
while (( $# )); do
  case "$1" in
    --build-only) build_only=true; shift ;;
    --yes) assume_yes=true; shift ;;
    --source-rpm)
      [[ -n ${2:-} && -f $2 ]] || { echo '--source-rpm requires an existing file' >&2; exit 2; }
      source_rpm=$(realpath -- "$2"); shift 2 ;;
    --xwayland-source-rpm)
      [[ -n ${2:-} && -f $2 ]] || { echo '--xwayland-source-rpm requires an existing file' >&2; exit 2; }
      xwayland_source_rpm=$(realpath -- "$2"); shift 2 ;;
    --jobs)
      [[ ${2:-} =~ ^[1-9][0-9]*$ ]] || { echo '--jobs requires a positive integer' >&2; exit 2; }
      jobs=$2; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) usage >&2; exit 2 ;;
  esac
done
[[ $EUID != 0 ]] || { echo 'Run as your normal user, without sudo.' >&2; exit 1; }
source /etc/os-release
case ${ID:-} in
  nobara|fedora) ;;
  *) echo 'Automatic packaging currently supports Fedora/Nobara. See docs/BUILDING.md.' >&2; exit 1 ;;
esac
version=$(rpm -q --qf '%{VERSION}' mutter)
release=$(rpm -q --qf '%{RELEASE}' mutter)
arch=$(rpm -q --qf '%{ARCH}' mutter)
[[ $version =~ ^[0-9][A-Za-z0-9.~_+-]*$ && $release =~ ^[A-Za-z0-9._+~%-]+$ && $arch =~ ^[A-Za-z0-9_]+$ ]] || {
  echo 'Cannot determine a supported installed Mutter package version.' >&2; exit 1;
}
xwayland_version=$(rpm -q --qf '%{VERSION}' xorg-x11-server-Xwayland)
xwayland_release=$(rpm -q --qf '%{RELEASE}' xorg-x11-server-Xwayland)
xwayland_arch=$(rpm -q --qf '%{ARCH}' xorg-x11-server-Xwayland)
xwayland_base=$(printf '%s' "$xwayland_release" | sed -E 's/\.unmuted[0-9]+$//')
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# Strip this project's local release suffix when locating distribution sources.
base_release=$(printf '%s' "$release" | sed -E 's/\.unmuted[0-9]+$//; s/\.legacy[0-9]+//')
mkdir -p "$root/build"
# Every invocation uses a fresh build directory so stale RPMs cannot be installed.
build_root=$(mktemp -d "$root/build/mutter-${version}.XXXXXX")
mkdir -p "$build_root"/{BUILD,BUILDROOT,RPMS,SOURCES,SPECS,SRPMS,download}
log="$build_root/build.log"
dnf_flags=()
$assume_yes && dnf_flags+=(-y)
printf 'Detected Mutter %s-%s (%s). Build directory: %s\n' "$version" "$release" "$arch" "$build_root"
sudo dnf install "${dnf_flags[@]}" rpm-build dnf5-plugins curl python3 cpio patch git-core
if [[ -z $source_rpm ]]; then
  echo 'Downloading the exact matching distribution source RPM.'
  if dnf download --source --destdir "$build_root/download" "mutter-${version}-${base_release}.${arch}"; then
    shopt -s nullglob
    sources=("$build_root/download/"*.src.rpm)
    (( ${#sources[@]} == 1 )) && source_rpm=${sources[0]}
    shopt -u nullglob
  fi
fi
if [[ -n $source_rpm ]]; then
  [[ $(rpm -qp --qf '%{NAME} %{VERSION} %{SOURCEPACKAGE}' "$source_rpm") == "mutter $version 1" ]] || {
    echo 'Source RPM must be mutter, with exactly the installed version.' >&2; exit 1;
  }
  source_release=$(rpm -qp --qf '%{RELEASE}' "$source_rpm")
  source_base=$(printf '%s' "$source_release" | sed -E 's/\.unmuted[0-9]+$//; s/\.legacy[0-9]+//')
  [[ $source_base == "$base_release" ]] || {
    echo 'Source RPM release differs from the installed package; obtain its matching source.' >&2; exit 1;
  }
  rpmkeys --checksig "$source_rpm"
  # Installing an SRPM as a normal user only unpacks its source/spec into _topdir.
  rpm -i --define "_topdir $build_root" "$source_rpm"
elif [[ $ID == nobara && ${VERSION_ID:-} == 44 && $version == 50.4 && $base_release == 1.fc44 ]]; then
  echo 'Exact source RPM unavailable; using the included, tested Nobara 50.4 recipe.'
  cp "$root/packaging/nobara/mutter.spec" "$build_root/SPECS/"
  cp "$root/packaging/nobara/"*.patch "$root/packaging/nobara/"*.override "$build_root/SOURCES/"
  archive="$build_root/SOURCES/mutter-50.4.tar.xz"
  curl --fail --location --retry 3 --output "$archive" \
    https://download.gnome.org/sources/mutter/50/mutter-50.4.tar.xz
  printf '%s  %s\n' '273d33c875abcb4b6cbea3f4ec045d18155fbc510c3521fc7e47926371310988' "$archive" | sha256sum --check
else
  echo 'The exact source is unavailable. Enable matching source repositories or run:' >&2
  echo '  ./install.sh --source-rpm /path/to/matching-mutter.src.rpm' >&2
  exit 1
fi
echo "Detected Xwayland $xwayland_version-$xwayland_release ($xwayland_arch)."
bash "$root/tools/build-xwayland.sh" "$root" "$build_root/xwayland"   "$xwayland_version" "$xwayland_base" "$xwayland_arch" "$jobs" "$assume_yes" "$xwayland_source_rpm"
# Only the test context reads this variable; installed Mutter keeps its normal path.
export MUTTER_TEST_XWAYLAND_PATH="$build_root/xwayland/extracted/usr/bin/Xwayland"
python3 "$root/tools/prepare-spec.py" "$build_root/SPECS/mutter.spec" "$version" "$base_release"
cp "$root/patches/mutter-50.4-legacy-input.patch" "$build_root/SOURCES/mutter-unmuted.patch"
sudo dnf builddep "${dnf_flags[@]}" "$build_root/SPECS/mutter.spec"
printf 'Applying patch, building and testing with %s jobs. Follow: tail -f %q\n' "$jobs" "$log"
if ! rpmbuild -ba --define "_topdir $build_root" --define "_smp_build_ncpus $jobs" \
     "$build_root/SPECS/mutter.spec" > "$log" 2>&1; then
  tail -n 60 "$log" >&2
  echo "Patch/build/tests failed; no runtime packages installed. Full log: $log" >&2
  exit 1
fi
packages=()
while IFS= read -r -d '' package; do
  name=$(rpm -qp --qf '%{NAME}' "$package")
  case $name in mutter|mutter-common) packages+=("$package");; esac
done < <(find "$build_root/RPMS" -type f -name '*.rpm' -print0)
(( ${#packages[@]} == 2 )) || { echo 'Expected exactly two runtime packages; refusing installation.' >&2; exit 1; }
for package in "${packages[@]}"; do
  [[ $(rpm -qp --qf '%{VERSION}' "$package") == "$version" ]] || { echo 'Built version mismatch.' >&2; exit 1; }
done
packages+=("$(cat "$build_root/xwayland/runtime-rpm.txt")")
# Build dependencies (notably Xwayland-devel) may require the exact runtime
# release. Upgrade already-installed companion packages from these same builds.
while IFS= read -r -d '' package; do
  name=$(rpm -qp --qf '%{NAME}' "$package")
  case $name in mutter|mutter-common|xorg-x11-server-Xwayland) continue;; esac
  if rpm -q --quiet "$name"; then
    packages+=("$package")
  fi
done < <(find "$build_root/RPMS" "$build_root/xwayland/RPMS" -type f -name '*.rpm' -print0)

printf 'Build and paired tests passed. Packages:\n'
printf '%s\n' "${packages[@]}"
$build_only && exit 0
[[ $(rpm -q --qf '%{VERSION}-%{RELEASE}' mutter) == "$version-$release" ]] || {
  echo 'Installed Mutter changed during the build. Run this script again.' >&2; exit 1;
}
# A repeated install of the same local release should refresh its files too.
[[ $(rpm -q --qf '%{VERSION}-%{RELEASE}' xorg-x11-server-Xwayland) == "$xwayland_version-$xwayland_release" ]] || {
  echo 'Installed Xwayland changed during the build. Run this script again.' >&2; exit 1;
}
operation=install
[[ $release == "${base_release}.unmuted3" && $xwayland_release == "${xwayland_base}.unmuted3" ]] && operation=reinstall
sudo dnf "$operation" "${dnf_flags[@]}" "${packages[@]}"
cat <<'NEXT'
Installed. Save your work, then log out and back in.
After logging back in, enable mouse-button forwarding with:
  gsettings set org.gnome.mutter.wayland xwayland-legacy-pointer-buttons true
Optional keyboard forwarding (exposes typed input to all Xwayland apps):
  gsettings set org.gnome.mutter.wayland xwayland-legacy-keyboard-mode 'all'
Existing settings are preserved. Fully quit Discord and run: discord --ozone-platform=x11
NEXT
