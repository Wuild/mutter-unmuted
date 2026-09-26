# Mutter Unmuted

**Push to talk, across your GNOME desktop.**

An opt-in pair of Mutter and Xwayland patches that lets legacy X11 applications
receive selected keyboard and extra mouse-button input while you use GNOME on
Wayland. Built to make
Discord's forward-thumb-button push to talk work across native Wayland apps,
the empty desktop, overview, app grid and Shell menus.

**Forward while unlocked. Stop at the lock screen.**

This is an experimental community patch, tested with **Mutter 50.4 / GNOME Shell
50.4 and Xwayland 24.1.13 on Nobara 44**. The installer detects the installed
version of each component and builds both from matching distribution sources.
It is inspired by KDE's legacy X11 input support and is not an official GNOME,
KDE or Discord project.

The current revision preserves held mouse PTT when crossing into Xwayland/Wine
windows **without an artificial release/press pair**. Both patched components
are required. This replaces the earlier Mutter-only resend workaround that
could trigger Discord's PTT sounds.

## Why this exists

Discord running through Xwayland can listen for input inside the shared X11
server, but it does not automatically receive global input from native Wayland
windows or GNOME's own UI. That leaves push to talk working in some places and
silent in others.

Mutter Unmuted adds forwarding inside the compositor. It sends selected input
to the existing Xwayland client without changing focus or requiring Discord to
implement the Global Shortcuts portal. It does not add portal support to Discord.

## What it does

- Forwards five extra mouse buttons: side, extra, forward, back and task.
- Offers four keyboard modes, from disabled to all keys.
- Continues through native applications, desktop space, overview, app grid and menus.
- Preserves held PTT when entering and leaving Xwayland/Wine windows, without
  generating a release/repress cycle.
- Releases forwarded holds and blocks new forwarded input when GNOME locks.
- Preserves normal input delivery and avoids duplicate delivery to focused Xwayland.
- Uses persistent GSettings controls. Both features default to **off**.

Primary mouse buttons and scrolling are not forwarded by this feature.

## Build and install

On **Nobara or Fedora**, clone this repository and run:

```bash
git clone https://github.com/Wuild/mutter-unmuted.git
cd mutter-unmuted
./install.sh
```

Or download and extract the source ZIP from GitHub, open a terminal in its
folder, and run `bash install.sh`. No Git installation is needed for that route.

The installer reads the installed versions, releases and architectures of
Mutter and Xwayland, obtains their matching source RPMs, preserves distribution
recipes and patches, installs dependencies, and builds as your normal user.
It builds Xwayland first, then tests Mutter against that freshly built Xwayland
executable. Only after both builds and the paired tests pass does it install
`mutter`, `mutter-common` and `xorg-x11-server-Xwayland` together, plus matching
already-installed companion packages such as `Xwayland-devel` that require the
exact runtime release. It asks for sudo when needed and shows DNF transaction prompts. Allow several minutes; the
build directory and log path are printed at startup.

If your repositories no longer provide the exact source, use
`./install.sh --source-rpm /path/to/matching-mutter.src.rpm` and/or
`--xwayland-source-rpm /path/to/matching-xwayland.src.rpm`. For the original
Nobara 44 / 50.4-1.fc44 setup, an included recipe and checksum-verified upstream
archive provide an automatic fallback. Other versions never silently fall back
to 50.4. Patch, build or test failures stop before replacing the compositor.

Use `./install.sh --build-only` to stop before installing the runtime RPMs,
`--jobs 4` to limit build parallelism, or `--yes` to accept DNF transactions
automatically. Run the script without sudo. It leaves forwarding disabled by
default and preserves existing settings.

See [the build guide](docs/BUILDING.md) for manual steps or other distributions.
Built packages keep each installed upstream version and add `.unmuted3` to its
distribution release. Re-running the installer rebuilds and reinstalls that local release.

This repository contains source and packaging, not prebuilt RPMs. Automatic
RPM packaging is implemented for Fedora/Nobara; other distributions need their
own packaging integration. After installing, **log out and back in**
to start the patched compositor; the running Wayland session does not change
when a package is installed.

## Update or rebuild after system updates

From your existing checkout:

```bash
git pull --ff-only
./install.sh
```

Then **log out and back in**. Existing forwarding settings carry over.

Use the same commands after a distribution update to **either Mutter or
Xwayland**. The installer detects both currently installed versions, fetches
matching sources, reapplies both patches, and tests the pair before installing
it. You do not need to edit version numbers manually.

Version detection does not guarantee every future release is compatible. If
sources are unavailable, a patch conflicts, or paired tests fail, the installer
stops before installing either local build. No version pinning or background
updater is added. Until both patches are present again, seamless handoff is not
assured.

## Enable it

For forward/back mouse-button PTT:

```bash
gsettings set org.gnome.mutter.wayland xwayland-legacy-pointer-buttons true
```

For keyboard forwarding too:

```bash
gsettings set org.gnome.mutter.wayland xwayland-legacy-keyboard-mode 'all'
```

| Keyboard mode | Forwarded input |
| --- | --- |
| `disabled` | None |
| `non-character` | Control, navigation, function, modifier and media keys; excludes printable text, Compose, dead keys and input-method keys |
| `modifiers` | The above, plus keys pressed with Ctrl, Alt or Super |
| `all` | All keys reaching the Wayland seat update, including Shell shortcuts |

Changes take effect immediately once the patched compositor is running. No
GNOME Settings patch or Shell extension is required.

**Forwarded input is visible to every application on the shared Xwayland
server, not just Discord.** In `all` mode this includes text typed in other
applications. Enable only the input categories you want to expose; mouse-only
PTT does not require keyboard forwarding.

## Use with Discord

1. Fully quit Discord, including its background process, then launch it through
   Xwayland:

   ```bash
   discord --ozone-platform=x11
   ```

2. Enable Push to Talk in Discord and bind your forward thumb button.
3. Join a voice channel and test press **and release** with a native Wayland app
   focused, over empty desktop space, in overview, in the app grid and with a
   Shell menu open.
4. Hold PTT over the desktop, move into a Wine/Xwayland window, and move back
   out without releasing. Transmission should continue without Discord playing
   its PTT stop/start sounds. Release the button and verify transmission stops.
5. Lock while holding PTT: transmission should stop. New presses while locked
   should do nothing. After unlocking, release and press again to resume.

An optional native Wayland test window is included:

```bash
python3 tools/native-test-window.py
```

It requires Python GObject bindings and GTK 4, and does not capture background
input. The working setup used the official Discord RPM client through Xwayland;
other clients and packaging formats have not been validated here.

## Disable or roll back

```bash
gsettings set org.gnome.mutter.wayland xwayland-legacy-pointer-buttons false
gsettings set org.gnome.mutter.wayland xwayland-legacy-keyboard-mode 'disabled'
```

To remove the patch completely, reinstall your distribution's matching stock
`mutter`, `mutter-common` and `xorg-x11-server-Xwayland` packages, along with
matching installed companion packages such as `xorg-x11-server-Xwayland-devel`.
Then log out and back in. Keep those stock packages available before replacing
the compositor and Xwayland. Distribution updates can
replace this build; rebase the patch instead of indefinitely pinning Mutter.

## How it works

The patch adds GSettings keys and forwarding in Mutter's Wayland keyboard and
pointer handling. It sends `wl_keyboard` and `wl_pointer` events to the existing
Xwayland client without synthesizing focus enters or using XTEST. Held inputs
are tracked so releases are paired, including across desktop and Shell UI
transitions. Settings changes cancel forwarded holds.

The private `mutter_unmuted_v1` Wayland protocol coordinates pointer entry.
Mutter sends a per-pointer bitmask of the five extra buttons still held,
immediately before `wl_pointer.enter`. Patched Xwayland skips its usual
synthetic release only for those buttons, then consumes the mask. With
forwarding disabled the mask is zero and normal Xwayland reset behavior remains.
Only Mutter's own Xwayland client can bind the protocol. Physical releases,
settings changes and lock cancellation still deliver normal release events.

Input is observed before ordinary Shell grabs and compositor shortcuts consume
it. Those shortcuts continue to work normally.

For the lock boundary, GNOME Shell 50.4 synchronously inhibits Mutter's remote
access controller when entering its unlock-dialog/greeter session mode. The
patch exposes an internal inhibition query and signal, cancels held input on
inhibition, and blocks forwarding until inhibition ends. Nested inhibition is
respected. This avoids treating every overview or menu grab as a lock screen.

This boundary targets a **physical GNOME session**. GNOME Shell skips that
remote-access call in headless sessions; any other caller inhibiting remote
access also stops forwarding. Events consumed earlier by input-capture,
accessibility or text-input filters are outside this hook. Applying and
compiling successfully on another version is not proof that its Shell lock
behavior is unchanged. Other Mutter/Shell versions need live
lock-screen testing; the confirmed setup remains GNOME 50.4.

## Validation

The upstream Xwayland suite and the added integration suite passed in the final
RPM build. Tests use a separate headless Mutter instance, a real Xwayland server,
a native Wayland client and an XI2.2 observer. They cover input filtering,
press/release pairing, desktop transitions, Shell grabs, lock inhibition,
nested inhibition and duplicate prevention. The coordinated handoff test holds
all five extra buttons across pointer entry and verifies **zero release or
replacement-press events**, followed by the expected physical releases.

The complete build-only installer path, three standalone Xwayland test suites
and nine installer/spec tests also passed. The earlier Mutter-only behavior
was confirmed in the original user's live GNOME session; the new coordinated
revision still needs a live Wine/Discord check after installation.
Automated lock tests exercise the controller signal used by Shell, rather than
running a full GNOME authentication screen. See [validation details](docs/VALIDATION.md).

## Repository contents

- `patches/`: Mutter implementation/tests and the coordinated Xwayland patch.
- `packaging/nobara/`: RPM spec and the existing Nobara patches/schema override.
- `install.sh`: version detection, source acquisition, dependencies and paired installation.
- `tools/`: spec adaptation and an independent native Wayland test window.
- `tests/`: isolated installer and packaging checks.
- `docs/`: build instructions and validation notes.

When reporting an issue, include distribution, Mutter, GNOME Shell and Xwayland versions,
Discord launch mode, forwarding settings, and whether press or release fails.
Specify whether it happens in an app, the desktop, overview, app grid or a menu.

## License and credits

The Mutter patch and installer are GPL-2.0-or-later; see [LICENSE](LICENSE).
The Xwayland changes and shared protocol are MIT-licensed; see
[LICENSES/MIT.txt](LICENSES/MIT.txt). Existing upstream notices are retained.
Mutter and GNOME Shell are GNOME projects. The RPM recipe and distribution
patches derive from Fedora/Nobara packaging. KDE's legacy X11 support inspired
the feature; this implementation is not a direct KWin port.
