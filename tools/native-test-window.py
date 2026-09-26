#!/usr/bin/env python3
"""A separate, explicitly native Wayland window for testing background PTT."""
import os

os.environ['GDK_BACKEND'] = 'wayland'

import gi

gi.require_version('Gtk', '4.0')
from gi.repository import Gio, Gtk


def activate(app):
    window = Gtk.ApplicationWindow(application=app)
    window.set_title('Native Wayland — Discord PTT test')
    window.set_default_size(580, 280)
    box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=20)
    for side in ('top', 'bottom', 'start', 'end'):
        getattr(box, f'set_margin_{side}')(24)
    instructions = Gtk.Label(
        label='Keep this window focused.\nHold and release your forward mouse button.\n'
              'Discord should transmit only while it is held.\n\n'
              'This window uses native Wayland and does not read background input.'
    )
    instructions.set_wrap(True)
    box.append(instructions)
    entry = Gtk.Entry(placeholder_text='Optional: type here to keep keyboard focus')
    box.append(entry)
    window.set_child(box)
    window.present()
    entry.grab_focus()


app = Gtk.Application(application_id='local.LegacyInputTest',
                      flags=Gio.ApplicationFlags.NON_UNIQUE)
app.connect('activate', activate)
raise SystemExit(app.run())
