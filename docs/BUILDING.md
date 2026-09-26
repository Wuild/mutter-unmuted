# Building Mutter Unmuted

## Automatic build and install

On Nobara or Fedora, run as your normal user:

```bash
./install.sh
```

The script detects **version, release and architecture** independently for
installed Mutter and `xorg-x11-server-Xwayland`.
It downloads the exact matching distribution source RPM for each with DNF and unpacks it
into a fresh directory under `build/`. It preserves the distribution's build
options, API version, dependencies, source files, patches and package layout.
The spec adapter adds our patch, sets the same version with a local `.unmuted3`
release suffix, and adds the Xwayland integration tests if they are not present.
The existing distribution tests are preserved too.

Build dependencies are installed through `dnf builddep`. RPM preparation applies
the patch; conflicts, compilation errors or failed tests stop the process before
runtime package installation. Build logs remain in the printed build directory.
Xwayland builds first. Its runtime RPM is extracted locally, and the Mutter
test context uses that executable via `MUTTER_TEST_XWAYLAND_PATH`. Installed
Mutter ignores this test-only variable and keeps its normal Xwayland path.
The final DNF transaction installs the freshly built `mutter`, `mutter-common`
and `xorg-x11-server-Xwayland` together, including matching already-installed
companion packages (for example `Xwayland-devel`), after checking that neither installed
component changed during the build. A failure leaves both local builds uninstalled.

Save your work and log out and back in afterward, then enable forwarding using
the README's GSettings commands. Existing settings are preserved.

Options:

```bash
./install.sh --build-only       # Dependencies + build/tests, no runtime installation
./install.sh --jobs 4           # Limit parallel build jobs (default at most 8)
./install.sh --yes              # Accept DNF transactions automatically
./install.sh --source-rpm /path/to/matching-mutter.src.rpm \
  --xwayland-source-rpm /path/to/matching-xwayland.src.rpm
```

Run without sudo; the script invokes sudo only for package/dependency operations.
Local source RPMs must match the installed version and distribution release.
Use a trusted distribution source RPM: RPM recipes execute build commands.
Locally generated RPMs are unsigned unless you sign them yourself.

## Source availability and compatibility

Repositories sometimes remove older builds. Enable the appropriate source
repositories or provide the exact matching source RPM with `--source-rpm`.
The installer does not switch to the latest version or downgrade either
component to make a patch apply. After distribution updates, rerun the script
to detect the new versions and rebuild both patches.

For the original Nobara 44 installation with Mutter 50.4-1.fc44, an automatic
fallback uses the included recipe and the checksum-verified upstream archive.
That recipe preserves Nobara's EGL-device option, 30-second responsiveness
timeout, Tegra KMS patch and VRR/fractional-scaling schema override. It was
adapted from Nobara's available 50.5 recipe to the tested 50.4 source.

The forwarding patches were developed against Mutter 50.4 and Xwayland 24.1.13. Its filename records that
baseline, not an installer version restriction. New or older source may need a
rebase. The spec adapter requires `%autosetup` with patch application enabled;
unrecognized preparation layouts stop for manual adaptation. Passing patch and
build checks does not establish the lock boundary on another GNOME Shell version.
Test lock/unlock behavior in the target physical GNOME session.

## Other distributions / manual application

Use your distribution's source package and build tooling. This repository does
not yet automate Debian, Ubuntu, Arch or other packaging formats.

Apply each patch inside the matching component source directory. For Mutter:

```bash
patch -p1 --dry-run < /path/to/mutter-unmuted/patches/mutter-50.4-legacy-input.patch
patch -p1 < /path/to/mutter-unmuted/patches/mutter-50.4-legacy-input.patch
```

Follow Mutter's build instructions and preserve your distribution's patches.
Apply `patches/xwayland-unmuted.patch` to matching Xwayland source with
`patch -p1` and build it first. Enable tests in the Mutter Meson configuration,
then run the paired tests against the newly built Xwayland:

```bash
env -u GDK_BACKEND -u XAUTHORITY \
  MUTTER_TEST_XWAYLAND_PATH=/path/to/patched/Xwayland \
  meson test -C /path/to/mutter-build \
  xwayland xwayland-legacy-input --print-errorlogs
```

Tests start isolated D-Bus, Wayland and Xwayland sessions, so the environment
must allow local sockets. Avoid installing a second Mutter into `/usr/local`
over your desktop's packaged compositor.

## Packaging checks

```bash
python3 -m unittest discover -s tests -p 'test_*.py'
bash -n install.sh
```

Installer checks use fake package commands and never call real sudo or DNF.
They exercise version detection, build-only behavior and aborts before runtime
installation. These are separate from the real compositor tests in `%check`.

## Baseline source provenance

- [Upstream Mutter 50.4 archive](https://download.gnome.org/sources/mutter/50/mutter-50.4.tar.xz)
- [Fedora 50.4 source RPM](https://kojipkgs.fedoraproject.org/packages/mutter/50.4/1.fc44/src/mutter-50.4-1.fc44.src.rpm)
- [Nobara 50.5 packaging source RPM](https://download.copr.fedorainfracloud.org/results/gloriouseggroll/nobara-44/fedora-44-x86_64/11035363-mutter/mutter-50.5-1.fc44.src.rpm)

The upstream 50.4 archive matched the one in Fedora's source RPM. Its SHA-256 is
`273d33c875abcb4b6cbea3f4ec045d18155fbc510c3521fc7e47926371310988`.
No complete upstream tree or binary package is stored in this repository.
