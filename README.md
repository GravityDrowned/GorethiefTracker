# Gorethief Tracker

[![ESO API Version](https://img.shields.io/badge/ESO%20API-101044%20%7C%20101045-blue)]()
[![Version](https://img.shields.io/badge/Version-1.0.0-green)]()
[![License](https://img.shields.io/badge/License-MIT-yellow)]()

A lightweight Elder Scrolls Online addon that tracks the stack counter for the **Gorethief** item set, helping you maximize your proc uptime and damage output.

---

## Table of Contents

- [Overview](#overview)
- [Features](#features)
- [Installation](#installation)
- [Usage](#usage)
- [Slash Commands](#slash-commands)
- [Settings](#settings)
- [FAQ](#faq)
- [Troubleshooting](#troubleshooting)
- [Support](#support)
- [Credits](#credits)

---

## Overview

### What is Gorethief?

Gorethief is a weapon set in Elder Scrolls Online that activates after dealing **10 direct damage attacks**. Each direct damage hit adds a "stack" to your player buff, and when you reach 10 stacks, the set procs with powerful bonus effects.

### Why Use This Addon?

Without a visual tracker, it's difficult to know:
- How many stacks you've built up
- When the set is about to proc
- How long the buff will remain active

**Gorethief Tracker** solves these problems by displaying a clear, color-coded visual indicator showing your current stack count and remaining duration.

```
+-------------------+
|                   |
|    [Icon: 7/10]   |  <-- Red = Almost Proccing!
|      (25s)        |
+-------------------+
```

---

## Features

- **Real-time Stack Tracking** - Monitors your direct damage and displays current stacks (0-10)
- **Duration Display** - Shows remaining time on the buff (in seconds)
- **Color-Coded Display** - Visual feedback based on stack level:
  - Green (1-3 stacks): Building up
  - Yellow (4-7 stacks): Getting close
  - Red (8-10 stacks): Proc imminent!
  - Gold (10 stacks): Max stacks!
- **Movable UI** - Position the display anywhere on your screen
- **Configurable Size** - Adjust display size from 32px to 128px
- **Always Show Option** - Keep the display visible even with 0 stacks
- **Roll Dodge Detection** - Detects when Roll Dodge consumes a stack
- **Bash Detection** - Detects Bash attacks at max stacks for AoE bleed proc
- **Debug Mode** - Detailed logging for troubleshooting
- **Minimal Performance Impact** - Efficient event-based tracking

---

## Installation

### Method 1: Manual Installation

1. Download the latest release
2. Extract the `GorethiefTracker` folder
3. Copy the folder to your ESO addons directory:
   - **Windows**: `Documents\Elder Scrolls Online\live\AddOns\`
   - **Mac**: `~/Documents/Elder Scrolls Online/live/AddOns/`
4. Restart ESO or type `/reloadui` in chat

### Method 2: Minion (Addon Manager)

1. Open Minion
2. Search for "Gorethief Tracker"
3. Click Install
4. Restart ESO or type `/reloadui`

### Dependencies

This addon requires:
- **LibAddonMenu-2.0** (version 30 or higher) - For the settings panel

> **Note**: LibAddonMenu-2.0 is typically installed automatically by Minion or can be downloaded separately from ESOUI.

### Verifying Installation

1. Log into ESO
2. Open the Addon Manager (before character select)
3. Ensure "Gorethief Tracker" is checked
4. Ensure "LibAddonMenu-2.0" is also enabled

---

## Usage

### Basic Usage

1. **Equip the Gorethief weapon set**
2. **Enter combat** with an enemy
3. **Deal direct damage** - the tracker will appear and count your stacks
4. **Watch the color change** as you approach 10 stacks
5. When the display turns **red**, your set is about to proc!

### Understanding the Display

| Stack Count | Color  | Meaning                    |
|-------------|--------|----------------------------|
| 0           | Hidden | No stacks (unless "Always Show" enabled) |
| 1-3         | Green  | Building stacks            |
| 4-7         | Yellow | Almost at proc threshold   |
| 8-10        | Red    | Proc imminent!             |
| 10 (Max)    | Gold   | Maximum stacks!            |

### Duration Display

The addon shows the remaining duration of your buff in seconds next to the stack count. Example: `7 (25s)` means 7 stacks with 25 seconds remaining.

### Positioning the Display

1. Open Settings (ESC > Settings > Addons > Gorethief Tracker)
2. Check "Unlock Position"
3. Drag the display to your preferred location
4. Uncheck "Unlock Position" to lock it in place

---

## Slash Commands

All commands use the `/gtc` prefix:

| Command        | Description                              | Example        |
|----------------|------------------------------------------|----------------|
| `/gtc`         | Show addon status                        | `/gtc`         |
| `/gtc toggle`  | Enable/disable the addon                 | `/gtc toggle`  |
| `/gtc reset`   | Reset current stack count to 0           | `/gtc reset`   |
| `/gtc debug`   | Toggle debug mode for troubleshooting    | `/gtc debug`   |

### Example Output

```
/gtc
> Gorethief Tracker - Status: true

/gtc toggle
> Gorethief Tracker - Enabled: false

/gtc debug
> Gorethief Tracker - Debug Mode: true
```

---

## Settings

Access settings via: **ESC > Settings > Addons > Gorethief Tracker**

| Setting             | Type     | Default | Description                                           |
|---------------------|----------|---------|-------------------------------------------------------|
| Enable Addon        | Checkbox | On      | Master toggle for the addon                           |
| Always Show Display | Checkbox | Off     | Show the tracker even when you have 0 stacks          |
| Unlock Position     | Checkbox | Off     | Allow dragging the display to reposition it           |
| Reset Position      | Button   | -       | Reset display to center-bottom of screen              |
| Display Size        | Slider   | 64px    | Size of the tracker icon (32-128 pixels)              |
| Debug Mode          | Checkbox | Off     | Enable detailed logging to chat                       |

---

## FAQ

### How do I know when the set will proc?

When the display turns **red** (8-10 stacks), the set is about to proc. At exactly **10 stacks**, the set will proc and consume all stacks.

### What consumes stacks?

- **Roll Dodge** - Consumes 1 stack when performed
- **Bash at max stacks** - Triggers AoE bleed proc (consumes all stacks)
- **Buff expiration** - If the buff expires naturally, all stacks are lost

### Why isn't the tracker showing up?

Check the following:
1. Is the addon enabled? Type `/gtc` to check status
2. Do you have the Gorethief set equipped?
3. Is "Always Show Display" disabled and you have 0 stacks?
4. Try `/reloadui` to refresh the UI

### Can I use this with other tracking addons?

Yes! Gorethief Tracker is designed to coexist with other addons like:
- Srendarr (buff/debuff tracking)
- Action Duration Reminder
- Buff Timers

### How do I reset the display position if it's off-screen?

1. Open Settings (ESC > Settings > Addons > Gorethief Tracker)
2. Click "Reset Position"
3. The display will return to screen center

### Does this work with all ESO game modes?

Yes, the addon works in:
- Overland/Questing
- Dungeons
- Trials
- PvP (Cyrodiil, Battlegrounds)
- Arenas

---

## Troubleshooting

### Common Issues

| Issue                          | Solution                                              |
|--------------------------------|-------------------------------------------------------|
| "LibAddonMenu-2.0 not found"   | Install LibAddonMenu-2.0 via Minion                   |
| Display stuck on screen        | Use `/gtc reset` or disable "Always Show"             |
| No settings panel              | Ensure LibAddonMenu-2.0 is enabled and updated        |
| Stacks not counting            | Check if addon is enabled, verify set is equipped     |
| UI errors on login             | Try `/reloadui` or reinstall the addon                |

### Debug Mode

Enable debug mode to see detailed tracking information:

```
/gtc debug
> Gorethief Tracker - Debug Mode: true
```

With debug mode enabled, you'll see messages like:
```
[GTC] Poll update: 6 -> 7 stacks, 28s remaining
[GTC] Poll update: 9 -> 10 stacks, 30s remaining
[GTC] *** SET PROCCED! ***
```

### Reporting Bugs

When reporting issues, please include:
1. ESO game version
2. Addon version (1.0.0)
3. Debug mode output (if applicable)
4. Steps to reproduce the issue
5. Any error messages from the UI error window

---

## Support

- **Bug Reports**: Open an issue on GitHub or comment on ESOUI
- **Feature Requests**: Welcome! Open an issue describing your idea
- **Questions**: Check the FAQ above or ask in the comments

---

## Credits

### Development

This addon was developed by analyzing and learning from these excellent ESO addons:

- **[GrimFocusCounter](https://www.esoui.com/)** - UI patterns and stack tracking logic
- **[Srendarr](https://www.esoui.com/downloads/info655-Srendarr-AuraBuffDebuffTracker.html)** - Buff tracking and effect change patterns
- **[SquishyAutoMarker](https://www.esoui.com/)** - Target tracking and reticle change patterns

Thank you to all the addon developers who share their work with the ESO community!

### Libraries

- **LibAddonMenu-2.0** by Seerah, sirinsidiator, and others

### Special Thanks

- The ESO addon development community
- ESOUI.com for hosting addons
- ZeniMax Online Studios for the robust addon API

---

## License

This addon is released under the MIT License. See LICENSE file for details.

---

## Version History

See [CHANGELOG.md](CHANGELOG.md) for detailed version history.

**Current Version**: 1.0.0

---

*Made with love for the Elder Scrolls Online community*
