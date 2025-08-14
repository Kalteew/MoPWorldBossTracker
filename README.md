# MoP World Boss Tracker

**MoPWorldBossTracker** is a lightweight World of Warcraft addon for Mists of Pandaria Classic that tracks which of your level 90+ characters still need to defeat MoP world bosses for the current weekly reset.

---

## Features

- Minimap button and `/mopwb` slash commands to toggle the tracker frame
- Draggable frame with persistent position
- Option to display all characters or only those who still need world boss kills
- Shows each world boss a character still needs this week
- Automatically handles weekly reset boundaries
- Low memory usage
- `/mopwb version` prints the addon version and currently active bosses
- Configurable logging with three verbosity levels

---

## Usage

Toggle the tracker frame via the minimap button or `/mopwb toggle`. The frame shows your level 90+ characters that still need MoP world boss kills for the week. Use `/mopwb show` or `/mopwb hide` to control visibility, `/mopwb minimap` to toggle the minimap button, `/mopwb all` to display every character, and `/mopwb todo` to show only those still needing kills.
Check the addon version and default active bosses with `/mopwb version`.

---

## Tracked World Bosses

- Sha of Anger — Quest 32099 (NPC 60491)
- Galleon — Quest 32098 (NPC 62346)
- Nalak — Quest 32518 (NPC 69099)
- Oondasta — Quest 32519 (NPC 69161)
- Xuen — Quest 33117 (NPC 71954)
- Chi-Ji — Quest 33118 (NPC 71953)
- Yu'lon — Quest 33119 (NPC 71955)
- Niuzao — Quest 33120 (NPC 71952)
- Ordos — Quest 33121 (NPC 72057)

Only Sha of Anger and Galleon are enabled by default; other bosses can be activated in the options panel.

---

## Supported Languages

MoPWorldBossTracker is available in:

- English (US/GB)

---

## Data Storage

- Uses per-account saved variables (`MoPWorldBossTrackerDB`)
- Stores tracked character data and frame position
- Updates automatically during normal gameplay and weekly resets

---

## Limitations

- Only tracks characters on your account
- Only monitors Mists of Pandaria world bosses
- Requires characters to be level 90 or higher

---

## Support

Found a bug or have a suggestion?  
Open an issue here: [GitHub - Kalteew/MoPWorldBossTracker](https://github.com/Kalteew/MoPWorldBossTracker)

---

## License

This addon is open-source under the MIT License.

---

Thank you for using MoPWorldBossTracker!

