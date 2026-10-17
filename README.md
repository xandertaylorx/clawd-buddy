<div align="center">

<img src="docs/hero.gif" width="640" alt="Clawd walking along the bottom of the screen, talking, jumping, dancing and napping">

# clawd-buddy

**A tiny pixel crab that lives on your Mac.**<br>
He wanders along the bottom of your screen, says silly things, and can be dragged up into the menu bar to live there.<br>
He's also a focus timer, a file shelf, a calculator, a color picker, and he'll tell you when Claude Code is done.

<img src="https://img.shields.io/badge/macOS-14%2B-d97757?style=flat-square" alt="macOS 14+">
<img src="https://img.shields.io/badge/Swift-single%20file%20app-d97757?style=flat-square" alt="Swift">
<img src="https://img.shields.io/badge/dependencies-none-d97757?style=flat-square" alt="No dependencies">
<img src="https://img.shields.io/badge/license-MIT-d97757?style=flat-square" alt="MIT">

</div>

<br>

> *Not affiliated with Anthropic. This is a fan project inspired by the little Clawd mascot from Claude Code. The art is drawn entirely in code, from rectangles.*

## Install

You need macOS 14+ and the Swift toolchain (Xcode or the Command Line Tools). No Xcode project, no packages:

```bash
git clone https://github.com/xandertaylorx/clawd-buddy.git
cd clawd-buddy
./build.sh
open build/Clawd.app
```

He drops in from the top of your screen. Right-click him for the menu. The app is ad-hoc signed, so if macOS complains the first time, right-click `Clawd.app` and choose **Open**.

## He lives in the menu bar

Drag him up to the menu bar and let go. He shrinks into a status item and carries on from there: blinking, walking in place, dancing, and popping up short phrases next to his icon. Click him there and pick **Let Clawd out** to drop him back on the desktop.

<div align="center">
<img src="docs/menubar.png" width="640" alt="Clawd in the menu bar, idle, talking, and as a timer">
</div>

He's notch-aware: if macOS doesn't have room for his icon (a crowded menu bar next to the notch), he notices, hops back out and tells you instead of silently disappearing.

## He's a timer

Start a focus session or a break and Clawd **turns into a timer**: an alarm-clock Clawd with a pixel LCD, a draining progress bar and little bells on top. In the menu bar the same face sits in the icon with the countdown next to it. When it's done he hops out of the menu bar to tell you.

<div align="center">
<img src="docs/timer.gif" width="420" alt="Clawd as a countdown timer, then celebrating">
</div>

## Drag files onto him

Drag any file over Clawd and a tray of drop targets appears:

<div align="center">
<img src="docs/tray.png" width="640" alt="The drop tray above Clawd: Hold, PNG, JPG, Shrink, Zip, Path, Trash">
</div>

| Target | What it does |
| --- | --- |
| **Hold** | Puts the file on his shelf. Nothing is moved or copied; drag it back out whenever and wherever you like. |
| **→ PNG / → JPG** | Converts images, saving a copy next to the original. |
| **Shrink** | Makes a smaller copy (`name-small`), and deletes it if it wouldn't actually be smaller. |
| **Zip** | Zips everything you dropped into one archive. |
| **Path** | Copies the file paths to your clipboard. |
| **Trash** | Moves the files to the Trash (recoverable). |

Dropping straight on him is the same as **Hold**. Dropping text saves it as a note.

<div align="center">
<img src="docs/shelf.png" width="640" alt="The file shelf holding three files">
</div>

## Little tools

| Tool | How |
| --- | --- |
| **Color picker**, an eyedropper for anywhere on screen. Copies the hex code. | `⌃⌥C` |
| **Ask Clawd**, a calculator that also converts units and currency: `15% of 240`, `5 ft in cm`, `72 f in c`, `40 usd to eur`, `(3+4)*2^2`, `time in tokyo` | `⌃⌥Space` |
| **Password generator** (12 / 20 / 32 characters or a PIN). Copied to the clipboard, kept out of clipboard history, and cleared after 45 seconds. | `⌃⌥P` |
| **Quick notes**, jot something down; click a note later to copy it. | `⌃⌥N` |

Also in the menu: reminders, an in-memory clipboard history (off by default, skips passwords), calendar heads-ups, and break nudges (water, stretch, posture).

## Claude Code buddy

Clawd watches for a busy `claude` process. While Claude Code works he sits down and types, cycling through spinner words like *Flibbertigibbeting…* When it goes quiet after a real run he tells you it's finished, popping out of the menu bar if he has to.

For "Claude needs you" moments, point a Claude Code notification hook (or any script) at his command line:

```bash
build/Clawd.app/Contents/MacOS/Clawd --say "Claude needs your attention"
npm test && build/Clawd.app/Contents/MacOS/Clawd --say "Tests passed"
```

## He plays

<table>
<tr>
<td width="50%">

**Token Catch.** A 30-second mini-game from his menu. Move your mouse to move Clawd along the bottom of the screen. Catch coins, grab rare gems, dodge the bugs. It speeds up as you go, and your best score is saved.

</td>
<td width="50%">
<img src="docs/game.gif" alt="Token Catch mini-game">
</td>
</tr>
</table>

He also climbs onto the top edge of your windows and sits there, riding along if you move them. His eyes follow your cursor, and he sometimes chases it. Hold the mouse on him to pet him. He naps when you step away, wakes when you're back, and cheers when you plug in. Click **Climb a window** in his menu to see him do it on demand.

## Dress-up

Santa in December, a pumpkin from mid-October, or pick a hat yourself under **Outfit**:

<div align="center">
<img src="docs/hats.png" width="640" alt="Party hat, Santa hat, wizard hat, crown and pumpkin">
</div>

<div align="center">
<img src="docs/poses.png" width="640" alt="Clawd's poses: idle, walking, waving, dancing, sleeping, surprised, thinking">
</div>

## Good to know

- **Privacy.** Everything runs locally. The only network request is the currency rate lookup for `Ask Clawd` (to `open.er-api.com`, no account, nothing about you sent). The clipboard history lives in memory only. Nothing is uploaded.
- **Permissions.** Calendar heads-ups are off until you turn them on, which triggers the normal macOS Calendar prompt.
- **Quiet mode.** One toggle silences his chatter. It switches on by itself during Zoom meetings and while a focus timer runs.
- **Launch at login** is in his menu.
- **No room in the menu bar?** On notch Macs, macOS silently drops status icons that don't fit. Clawd detects this and pops back out. Hold `⌘` and drag a couple of icons off the bar to make room.
- The images in this README are rendered by the app's own drawing code (`Clawd --art docs`), not screenshots.

## How it's built

A single-purpose Swift/AppKit app with no dependencies. Clawd is drawn from filled rectangles every frame, so the same code makes the desktop sprite, the menu bar icon, the timer face and these README images.

```
Sources/main.swift   the app: sprite, behavior, menus, tools
Sources/Art.swift    renders the README visuals
build.sh             compiles, makes the icon, bundles Clawd.app
```

## License

MIT. See [LICENSE](LICENSE).
