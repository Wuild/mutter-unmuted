# Validation

## Current coordinated revision: .unmuted3

Built against Mutter 50.4 / GNOME Shell 50.4 and Xwayland 24.1.13 on Nobara 44.
The installed upstream versions are detected independently by `install.sh`;
these versions describe the tested setup, not a fixed installer requirement.

The final Mutter RPM build tested against the executable extracted from the
patched Xwayland runtime RPM:

```text
mutter:xwayland               OK    2.51s
mutter:xwayland-legacy-input  OK   14.18s
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
adaptation. A simulated different upstream version tests installer control flow,
not actual source compatibility with that version.

The complete `install.sh --build-only` path also built both matching source
RPMs and passed the paired tests. Its sudo dependency commands were replaced
with a validation harness because those dependencies were already installed;
source extraction, spec adaptation, builds and tests ran normally. The final
DNF preview resolves with the matching installed Xwayland-devel package included.
No patched runtime packages were installed during validation.

## Earlier revisions

The original Mutter-only implementation was confirmed working by the original
user across their GNOME session, but Xwayland pointer entry ended held PTT.
The .unmuted2 resend workaround restored PTT but created a release/press pair
that caused Discord's audible PTT notifications. The coordinated .unmuted3
protocol replaces that workaround; no enter-time button replay remains.
