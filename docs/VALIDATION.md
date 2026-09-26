# Validation

Tested build: Mutter `50.4-1.legacy3.fc44`, with Nobara packaging options.
GNOME Shell: 50.4. Distribution: Nobara 44. Discord: official RPM through Xwayland.

Final RPM `%check` results:

```text
mutter:xwayland               OK    2.56s
mutter:xwayland-legacy-input  OK   11.61s
Ok: 2
Fail: 0
```

The added integration suite checks:

- Default-off behavior, non-character filtering and Ctrl+A release order.
- All-key press/release delivery and cancellation on settings changes.
- All five extra mouse buttons, simultaneous holds and primary-button exclusion.
- Press/release over empty desktop space and holds across window/desktop boundaries.
- Continued forwarding through Shell grabs, including grabs starting with no focus.
- Immediate held-key and held-button release when remote access is inhibited.
- Suppression during inhibition, nested inhibition and resuming after uninhibition.
- No extra late mouse release after a lock-triggered cancellation.
- Normal focused-Xwayland delivery without duplicates.
- A mouse hold crossing from Xwayland to a native Wayland window.

The upstream suite runs separately to preserve its startup/keymap assumptions.
The lock test calls the controller GNOME Shell uses synchronously when locking;
it does not run a complete Shell lock screen or enter authentication credentials.

The original user reported that the final revision works in their live GNOME
session after installation. This is validation of one setup, not a claim of
compatibility with all applications, distributions or future GNOME versions.

## Source-only installer validation

The version-detecting installer also completed a real `--build-only` run from
the matching 50.4 source RPM. Dependency commands were replaced by a test harness
because the required dependencies were already installed; the source unpack,
spec adaptation, compilation, RPM creation and compositor tests ran normally.
No runtime package installation was performed by this validation run.

```text
mutter:xwayland               OK    2.71s
mutter:xwayland-legacy-input  OK   11.61s
Installer/spec unit tests: 7 passed
```

The installer tests simulate another installed version (51.2) to check version
selection and packaging control flow. That is not a real Mutter 51.2 build or
a claim that the forwarding patch works on that version.
