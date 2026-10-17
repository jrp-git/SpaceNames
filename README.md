# SpaceNames

Rename your desktops in macOS Mission Control.

SpaceNames hangs a small black flag with your custom name under each desktop thumbnail in
Mission Control's Spaces bar. The selected desktop's blue highlight wraps around the flag too.

- No need to disable System Integrity Protection (SIP), no MacForge, and nothing injected into the Dock
- Works on Apple silicon and Intel (universal binary)
- Supports multiple displays
- Names follow the desktop when you reorder desktops
- Optionally shows the name across the screen when you switch desktops (Control-←/→ or swipe)
- Lives in the menu bar; the only permission it needs is Accessibility

## Requirements

- macOS 13 Ventura or later (developed and tested on macOS 26 with two displays)
- "Displays have separate Spaces" turned on (the macOS default)

## Install

1. Download `SpaceNames-<version>.pkg` from the [latest release](https://github.com/jrp-git/SpaceNames/releases/latest).
2. Open it. Because SpaceNames isn't notarized by Apple, macOS will block it the first time:
   go to **System Settings → Privacy & Security**, scroll down, click **Open Anyway** next to the
   message about SpaceNames, and confirm.
3. Follow the installer. It puts **SpaceNames.app** in `/Applications`.
4. Open **SpaceNames** from `/Applications`. When macOS asks, allow Accessibility access
   (see [Accessibility](#accessibility) below).

A plain `SpaceNames-<version>.zip` of the app is also attached to each release if you'd rather
drag it into `/Applications` yourself. You'll need the same **Open Anyway** step on first launch.

## Use

1. Click the flag icon in the menu bar → **Rename Desktops…**
2. Type a name for any desktop. Leave a field empty to keep the macOS label ("Desktop 3").
3. Open Mission Control (F3, Control-↑, or swipe up). Named desktops show their flag.

When you switch desktops outside Mission Control (Control-←/→ or a trackpad swipe), the
desktop's name appears across the middle of that display in white and fades away. Configure it
from the same menu:

- **Show Name When Switching**: turn it on or off (on by default)
- **Name Opacity**: 25%, 50% (default), 75% or 100%
- **Fade Duration**: 0.5, 1 (default), 1.5, 2 or 3 seconds

From the same menu you can also turn on **Open at Login**.

## Accessibility

SpaceNames needs Accessibility access to read where Mission Control draws each desktop.

To get there: **System Settings → Privacy & Security → Accessibility**, or run:

```sh
open "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
```

If the switch for SpaceNames is on but no flags appear (this can happen after installing a new
build), turning it off and on is **not** enough. Select **SpaceNames**, click **–** to remove it,
click **+** and add `/Applications/SpaceNames.app` again, then quit and reopen SpaceNames.

## How it works

While Mission Control is open, the Dock exposes the Spaces bar through the public Accessibility
API: each display, each desktop button, its exact position on screen, and which one is selected.
SpaceNames reads that layout, matches each button to a Space ID from macOS (a read-only private
call), and draws a click-through window under each named thumbnail. Nothing in the Dock is
modified, which is why SIP can stay on.

Names are stored in `~/Library/Preferences/com.jrp.SpaceNames.plist`, keyed by each Space's ID.

## Limitations

- The selection band color is fixed to Mission Control's default blue (`#3B99FC`).
- Flags may lag slightly while Mission Control animates open/closed or while you drag desktops.
- Apple could change how the Dock describes Mission Control in a future macOS version.

## Build from source

Requires the Xcode command line tools (`xcode-select --install`).

```sh
./build.sh      # builds build/SpaceNames.app (universal)
./package.sh    # also builds build/SpaceNames-<version>.pkg and .zip
```

`build.sh` signs the app with a local code-signing identity named **SpaceNames Local Signing**
if one exists, otherwise it falls back to ad-hoc signing. With ad-hoc signing, macOS treats every
build as a new app, so you'd have to remove and re-add the Accessibility entry after each
rebuild. To create the identity once (macOS asks for your login password to trust it):

```sh
./create-signing-cert.sh
```

To remove it later, delete **SpaceNames Local Signing** from the login keychain in Keychain Access.

## Credits

Inspired by [spaces-renamer](https://github.com/dado3212/spaces-renamer) by Alex Beals, which
renames Spaces by injecting into the Dock (requires disabling SIP). SpaceNames is a separate
implementation that doesn't need injection.

## License

[MIT](LICENSE)
