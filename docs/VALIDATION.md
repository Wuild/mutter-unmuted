# Validation

## Current coordinated revision: .unmuted5

Built against the current session's Mutter 50.4 / GNOME Shell 50.5 and
Xwayland 24.1.13 on Nobara 44. `install.sh` requires this exact validated stack.

The final Mutter RPM build tested against the executable extracted from the
patched Xwayland runtime RPM:

```text
mutter:xwayland               OK    2.51s
mutter:xwayland-legacy-input  OK   14.20s
mutter:wayland-xdg-session-management OK 1.67s
```

The integration tests start a separate headless Mutter, real Xwayland and a
native Wayland client. An XI2.2 observer checks:

- Default-off behavior, keyboard filters and modifier release order.
- All five extra mouse buttons, simultaneous holds and primary-button exclusion.
- Desktop, native-window and Shell-grab forwarding.
- Desktop-to-Xwayland entry with all five buttons held: **zero releases and zero
  replacement presses**, followed by exactly five physical releases.
- The same handoff followed by returning to the desktop before physical release.
- Ordinary Xwayland enter-time reset when forwarding is disabled.
- Cancellation on settings changes and lock inhibition; no forwarding while
  inhibited, including nested inhibition, and resumption afterward.
- Focused-Xwayland duplicate prevention and Xwayland-to-native holds.

The handoff regression explicitly retargets focus because the minimal headless
stage otherwise retains its desktop implicit grab. Tests exercise GNOME Shell's
synchronous lock-inhibition controller, not a complete authentication screen.
The new coordinated revision still needs a live Wine/Discord check after login.

Three standalone Xwayland suites also pass: `request-length`,
`damage-primitives` and `sync`. The full external XTS suite was not run.
Nine installer/spec tests pass with fake package commands; they never call
real sudo or DNF. These cover version detection, a single paired runtime
transaction, build-only mode, source mismatch, either build failing, and spec
adaptation and rejection of mismatched session component versions.

The complete `install.sh --build-only --skip-dependency-install` path downloaded
the exact matching Fedora/Nobara source RPMs, built both packages with the
already installed toolchain, and passed all three mandatory tests. The resulting
`.unmuted5` Mutter, Mutter Common, Mutter Devkit, Xwayland, and installed
Xwayland development companion packages were installed together through DNF.

## Wayland window restoration

The installed Mutter 50.4 source already implements the experimental
session-management protocol. This revision publishes that protocol normally
instead of requiring `MUTTER_DEBUG_SESSION_MANAGEMENT_PROTOCOL=1` before the
compositor starts.

The regression client creates two toplevels under one stable session ID with
distinct names. The test saves and independently restores a floating window's
rectangle and a second window's maximized state. Genuinely new, unpositioned
normal Wayland windows start centered on the primary monitor; restored and
transient windows retain their established placement paths.

## Earlier revisions

The original Mutter-only implementation was confirmed working by the original
user across their GNOME session, but Xwayland pointer entry ended held PTT.
The .unmuted2 resend workaround restored PTT but created a release/press pair
that caused Discord's audible PTT notifications. The coordinated .unmuted3
protocol replaces that workaround; no enter-time button replay remains.
