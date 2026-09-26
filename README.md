# Mutter Unmuted

**Push to talk, across your GNOME desktop.**

An opt-in Mutter patch that lets legacy X11 applications receive selected keyboard
and extra mouse-button input while you use GNOME on Wayland. Built to make
Discord's forward-thumb-button push to talk work across native Wayland apps,
the empty desktop, overview, app grid and Shell menus.

**Forward while unlocked. Stop at the lock screen.**

This is an experimental community patch, tested with **Mutter 50.4 / GNOME Shell
50.4 on Nobara 44**. The installer detects your installed Mutter version and
builds from matching source; it is not pinned to 50.4. It is inspired by KDE's legacy X11 input support and is
not an official GNOME, KDE or Discord project.

The current revision restores held mouse PTT when crossing into an Xwayland
window (including Wine). Xwayland resets buttons on entry, so the patch resends
still-held extra buttons immediately afterward. A brief release/press transition
can occur, but PTT no longer stays off until you press again.

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

The installer reads your installed Mutter version, release and architecture,
obtains its matching distribution source RPM, preserves that recipe and its
patches, installs build dependencies, adds this patch, builds as your normal
user, runs the tests, and installs only `mutter` and `mutter-common`. It asks for
sudo when needed and shows DNF transaction prompts. Allow several minutes; the
build directory and log path are printed at startup.

If your repositories no longer provide the exact source, use
`./install.sh --source-rpm /path/to/matching-mutter.src.rpm`. For the original
Nobara 44 / 50.4-1.fc44 setup, an included recipe and checksum-verified upstream
archive provide an automatic fallback. Other versions never silently fall back
to 50.4. Patch, build or test failures stop before replacing the compositor.

Use `./install.sh --build-only` to stop before installing the runtime RPMs,
`--jobs 4` to limit build parallelism, or `--yes` to accept DNF transactions
automatically. Run the script without sudo. It leaves forwarding disabled by
default and preserves existing settings.

See [the build guide](docs/BUILDING.md) for manual steps or other distributions.
Built packages keep your Mutter version and add `.unmuted2` to the distribution
release. Re-running the installer rebuilds and reinstalls that local release.

This repository contains source and packaging, not prebuilt RPMs. Automatic RPM packaging is implemented for Fedora/Nobara; other distributions
need their own packaging integration. After installing, **log out and back in**
to start the patched compositor; the running Wayland session does not change
when a package is installed.

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
4. Lock while holding PTT: transmission should stop. New presses while locked
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
`mutter` and `mutter-common` packages, then log out and back in. Keep those stock
packages available before replacing a compositor. Distribution updates can
replace this build; rebase the patch instead of indefinitely pinning Mutter.

## How it works

The patch adds GSettings keys and forwarding in Mutter's Wayland keyboard and
pointer handling. It sends `wl_keyboard` and `wl_pointer` events to the existing
Xwayland client without synthesizing focus enters or using XTEST. Held inputs
are tracked so releases are paired, including across desktop and Shell UI
transitions. Settings changes cancel forwarded holds.

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
accessibility or text-input filters are outside this hook. Applying and compiling successfully on another version is not proof that its
Shell lock behavior is unchanged. Other Mutter/Shell versions need live
lock-screen testing; the confirmed setup remains GNOME 50.4.

## Validation

The upstream Xwayland suite and the added integration suite passed in the final
RPM build. Tests use a separate headless Mutter instance, a real Xwayland server,
a native Wayland client and an XI2.2 observer. They cover input filtering,
press/release pairing, desktop transitions, Shell grabs, lock inhibition,
nested inhibition and duplicate prevention.

The original user confirmed the final revision works in their live GNOME setup.
Automated lock tests exercise the controller signal used by Shell, rather than
running a full GNOME authentication screen. See [validation details](docs/VALIDATION.md).

## Repository contents

- `patches/`: Mutter implementation, schema changes and integration tests.
- `packaging/nobara/`: RPM spec and the existing Nobara patches/schema override.
- `install.sh`: version detection, source acquisition, dependencies, build and installation.
- `tools/`: spec adaptation and an independent native Wayland test window.
- `tests/`: isolated installer and packaging checks.
- `docs/`: build instructions and validation notes.

When reporting an issue, include distribution, Mutter and GNOME Shell versions,
Discord launch mode, forwarding settings, and whether press or release fails.
Specify whether it happens in an app, the desktop, overview, app grid or a menu.

## License and credits

GPL-2.0-or-later; see [LICENSE](LICENSE). Existing upstream notices are retained.
Mutter and GNOME Shell are GNOME projects. The RPM recipe and distribution
patches derive from Fedora/Nobara packaging. KDE's legacy X11 support inspired
the feature; this implementation is not a direct KWin port.
