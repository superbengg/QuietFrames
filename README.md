# QuietFrames

A small, library-free World of Warcraft addon that adjusts the foreground FPS cap to help reduce fan noise and power use.

**Only `maxFPS` is changed.** Graphics quality, resolution, render scale, VSync, sound, and the background FPS cap are untouched.

## Versions

- **Retail:** interface 120100 (12.1.0). Fishing means the **Fishing for Attention** buff is active (spell 394009 or 1303610).
- **Forever:** interface 16001 (1.60.1). Fishing means a **fishing pole is equipped in the main-hand slot**.

Both versions have been tried in-game by the author, including the settings menu and AFK behavior.

## Default caps

| Rule or mode | FPS |
| --- | ---: |
| Auto: AFK | 30 |
| Auto: Fishing | 60 |
| Auto: Normal / open world | 100 |
| Auto: Dungeon / raid | 141 |
| Quiet mode | 100 |
| Full mode | 141 |

Auto priority is **AFK > Fishing > Location**. Retail scenarios, including Delves, use the dungeon/raid cap (141 FPS by default). Battlegrounds and arenas use the normal cap. Forever scenarios continue to use the normal cap. Leaving AFK or ending fishing restores the appropriate location cap.

Quiet and Full force their configured cap regardless of activity, including AFK, until Auto is selected again. AFK follows WoW's AFK flag (including `/afk`), not a separate inactivity timer.

## Installation

1. Select **Code > Download ZIP** on this repository and extract it.
2. Choose exactly one version:
   - Retail: copy `Retail/QuietFrames` into `World of Warcraft/_retail_/Interface/AddOns/`.
   - Forever beta: copy `Forever/QuietFrames` into `World of Warcraft/_classic_beta_/Interface/AddOns/`.
3. The installed folder must be named `QuietFrames`, with `QuietFrames.toc` and `QuietFrames.lua` directly inside it.
4. Restart the client and enable **QuietFrames** (or **QuietFrames - Forever**) in the AddOns list.

Do not copy the entire repository into AddOns. For later updates to an existing installation, replace the version's files and run `/reload`.

## Controls and configuration

- **Left-click minimap button:** Auto → Quiet → Full.
- **Right-click minimap button:** open FPS settings.
- **Hover:** show mode, detected activity/location, and the current foreground cap.
- **Settings > AddOns > QuietFrames:** edit all six caps, then click **Save**.
- **Restore defaults:** fills in the original values; click **Save** to apply.

Values must be whole numbers from 1 to 1000. Mode and caps are stored account-wide in `QuietFramesDB` for each client. Existing saved values survive updates.

### Commands

```text
/qf auto
/qf quiet
/qf full
/qf status
/qf settings
/qf set afk 30
/qf set fishing 60
/qf set normal 100
/qf set instance 141
/qf set quiet 100
/qf set full 141
```

`/quietframes` is an alias for `/qf`; `/qf config` also opens settings.

## Notes

- FPS caps are limits, not guaranteed frame rates. Hardware load and other game settings may result in a lower rate.
- Detection is event-driven; there is no continuous polling.
- If WoW marks an AFK or aura result as secret, the addon does not use that result for decisions.
- Another addon or a manual setting change can also change `maxFPS`; QuietFrames reapplies its cap on its next relevant event.
- Disabling QuietFrames does not restore a previous cap. Adjust WoW's foreground FPS setting if needed.

## Reporting problems

Open an issue with your client/version, current mode, `/qf status` output, expected behavior, and any Lua error. Please omit personal account information.

