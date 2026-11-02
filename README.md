# Field Notes

A compact multi-page note widget for Quickshell with optional calendar scheduling.

## Requirements

- Linux with a running Wayland session
- Quickshell 0.3 or later
- `xdg-open` for opening generated iCalendar events in the desktop calendar app

## Run

From this directory, launch the widget with:

```sh
quickshell --path "$PWD/shell.qml"
```

Notes are stored locally in `~/.local/share/qs-notes/notes.json`.

## Schedule a note

Expand Notes, open the **Calendar** section, choose a date and time, and select **Create calendar event**. The widget saves the event for Daymark and opens a standard `.ics` event with the desktop calendar handler.