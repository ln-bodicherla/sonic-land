# SonicLand

A programmable desktop operating layer for macOS that turns windows, workspaces, and monitors into a rule-driven system instead of a manual arrangement problem.

SonicLand uses BSP (Binary Space Partitioning) and multiple layout engines to automatically arrange windows, supports named workspaces with templates, scratchpads, context-aware rules, session persistence, profiles, and is fully configurable through a simple text file.

## Requirements

- macOS 14.0 (Sonoma) or later
- Accessibility permission (System Settings > Privacy & Security > Accessibility)

## Installation

### From GitHub Release

1. Download `SonicLand.dmg` from the [latest release](https://github.com/ln-bodicherla/sonic-land/releases/latest)
2. Open the DMG and drag `SonicLand.app` to your Applications folder
3. If macOS says the app is "damaged" or can't be opened, run:
   ```bash
   xattr -cr /Applications/SonicLand.app
   ```
4. Launch SonicLand
5. Grant accessibility permission when prompted

### From Source

```bash
git clone https://github.com/ln-bodicherla/sonic-land.git
cd sonic-land
swift build -c release
```

The binary will be at `.build/release/SonicLand`.

## How It Works

SonicLand runs as a menu bar app. It watches for new windows via the macOS Accessibility API and automatically tiles them using configurable layout engines. Each workspace maintains its own independent layout tree with its own layout mode.

## Layout Modes

| Mode | Description |
|------|-------------|
| **BSP** | Binary space partitioning — splits space dynamically based on aspect ratio |
| **Master-Stack** | Master pane on the left, remaining windows stacked on the right |
| **Columns** | Equal-width vertical columns |
| **Rows** | Equal-height horizontal rows |
| **Monocle** | All windows fullscreen, overlapping — only focused is visible |
| **Floating** | All windows float freely, no auto-tiling |

Cycle through layouts with `Cmd+Alt+Space` or set per-workspace in config.

## Configuration

Create a config file at `~/.config/sonicland/sonicland.conf`. An example is included in the repo at `Config/sonicland.conf.example`.

### General Settings

```
general.gaps_in = 5              # Gap between tiled windows (pixels)
general.gaps_out = 10            # Gap from screen edges (pixels)
general.border_size = 2          # Border size
general.monitor = all            # Monitor filter: "all", "built-in", "external", or name
general.layout = bsp             # Default layout: bsp, masterStack, columns, rows, monocle, floating
general.master_ratio = 0.55      # Master area ratio (0.1-0.9)
general.master_count = 1         # Number of master windows
general.dnd = false              # Do not disturb — suppress auto-retile
```

### Animation

```
animation.enabled = true
animation.duration = 200
animation.curve = easeOut        # linear, easeIn, easeOut, easeInOut, spring
```

### Session Persistence

```
session.enabled = true           # Save/restore workspace state
session.save_on_quit = true      # Auto-save on quit
session.restore_apps = false     # Relaunch missing apps on restore
```

### Visual Overlays

```
overlay.workspace_name = true    # Show workspace name on switch
overlay.layout_name = true       # Show layout name on change
overlay.focus_ring = false       # Show border around focused window
overlay.workspace_map = true     # Show mini workspace map on switch
```

### Workspace Configuration

Per-workspace settings for names, layouts, types, and startup actions:

```
workspace.1.name = Dev
workspace.1.layout = masterStack
workspace.1.type = coding
workspace.1.master_ratio = 0.6

workspace.2.name = Web
workspace.2.layout = bsp
workspace.2.type = research

workspace.3.name = Chat
workspace.3.layout = columns
workspace.3.type = communication
```

Workspace types: `general`, `coding`, `communication`, `research`, `design`, `media`, `system`

### Window Rules

Rules match windows and apply actions automatically.

Format: `windowrule = <action>, <condition>`

**Actions:**
| Action | Description |
|--------|-------------|
| `float` | Exclude from tiling |
| `workspace <n>` | Assign to workspace |
| `pin` / `pin_master` | Pin to master area |
| `sticky` | Show on all workspaces |
| `center` | Center and float on open |
| `size <W>x<H>` | Set float size |
| `geometry <X> <Y> <W> <H>` | Set exact position and size |
| `hide` | Hide on launch |
| `ignore` | Don't manage window |
| `tag <name>` | Assign a category tag |
| `always_on_top` | Keep above tiled windows |
| `layout <mode>` | Set workspace layout when app opens |

**Conditions:**
| Condition | Description |
|-----------|-------------|
| `app:<name>` | Match by app name (case-insensitive substring) |
| `bundle:<id>` | Match by bundle identifier |
| `title:<regex>` | Match by window title (regex) |
| `role:<role>` | Match by accessibility role |
| `title_contains:<text>` | Match by title substring |
| `title_not_contains:<text>` | Exclude by title substring |

Multiple conditions with `&&`:
```
windowrule = float, app:Safari && title_contains:PiP
windowrule = center, app:1Password
windowrule = size 1000x800, app:Slack
windowrule = sticky, app:Music
windowrule = pin_master, app:Terminal
```

### Context Rules

Rules that trigger based on environment, not window properties:

```
contextrule = <name>, <condition>, <action>
```

**Conditions:** `external_monitor`, `no_external_monitor`, `on_battery`, `on_power`, `monitors:<n>`, `app_running:<bundle_id>`, `app_not_running:<bundle_id>`

**Actions:** `profile <name>`, `layout <mode>`, `dnd_on`, `dnd_off`, `notify <message>`

```
contextrule = undocked, no_external_monitor, layout columns
contextrule = docked, external_monitor, profile Work
contextrule = battery_saver, on_battery, dnd_on
```

### Scratchpads

Hidden, toggle-able windows for quick access:

```
scratchpad = terminal, app:Terminal, width:900, height:600, center:true, autohide:true
scratchpad = notes, bundle:com.apple.Notes, width:700, height:500
scratchpad = music, app:Spotify, width:1000, height:700, center:true
```

Toggle with keybinding: `bind = cmd+alt+t, scratchpad terminal`

## Keyboard Shortcuts

All shortcuts are configurable. Defaults use vim-style navigation.

### Focus Navigation

| Shortcut | Action |
|---|---|
| Cmd + Alt + H | Focus left |
| Cmd + Alt + L | Focus right |
| Cmd + Alt + J | Focus down |
| Cmd + Alt + K | Focus up |

### Move Windows

| Shortcut | Action |
|---|---|
| Cmd + Alt + Shift + H | Move left |
| Cmd + Alt + Shift + L | Move right |
| Cmd + Alt + Shift + J | Move down |
| Cmd + Alt + Shift + K | Move up |
| Cmd + Alt + Shift + M | Move to master |

### Resize

| Shortcut | Action |
|---|---|
| Cmd + Alt + = | Grow width |
| Cmd + Alt + - | Shrink width |
| Cmd + Alt + Shift + = | Grow height |
| Cmd + Alt + Shift + - | Shrink height |
| Cmd + Alt + 0 | Normalize sizes |
| Cmd + Alt + I | Increase master ratio |
| Cmd + Alt + D | Decrease master ratio |

### Layout

| Shortcut | Action |
|---|---|
| Cmd + Alt + F | Toggle float/tile |
| Cmd + Alt + Space | Cycle layout mode |
| Cmd + Alt + M | Toggle monocle |
| Cmd + Alt + Shift + F | Toggle pseudo-fullscreen |
| Cmd + Alt + Shift + R | Rotate windows |
| Cmd + Alt + G | Toggle gaps |

### Workspaces

| Shortcut | Action |
|---|---|
| Cmd + Alt + 1-9 | Switch to workspace 1-9 |
| Cmd + Alt + Shift + 1-9 | Move focused window to workspace 1-9 |
| Cmd + Alt + Tab | Next workspace |
| Cmd + Alt + Shift + Tab | Previous workspace |
| Cmd + Alt + ` | Recent workspace |

### System

| Shortcut | Action |
|---|---|
| Cmd + Alt + R | Reload configuration |

### Available Keybinding Actions

Focus: `focus_left`, `focus_right`, `focus_up`, `focus_down`, `focus_recent`, `focus_parent`, `focus_master`

Move: `move_left`, `move_right`, `move_up`, `move_down`, `move_to_master`, `pull_to_tile`, `eject_to_float`

Resize: `grow_width`, `shrink_width`, `grow_height`, `shrink_height`, `normalize`, `increase_master_ratio`, `decrease_master_ratio`, `increase_master_count`, `decrease_master_count`

Layout: `toggle_float`, `cycle_layout`, `layout <mode>`, `rotate_cw`, `rotate_ccw`, `toggle_fullscreen`, `toggle_monocle`

Workspace: `workspace <n>`, `move_to_workspace <n>`, `next_workspace`, `previous_workspace`, `recent_workspace`

Scratchpad: `scratchpad <name>`

System: `reload_config`, `toggle_gaps`, `toggle_overlay`

## Menu Bar

Click the SonicLand icon in the menu bar to access:

- **Monitor Mode** — Choose which monitors to tile (External, Built-in, Shared Space)
- **Layout Mode** — Switch layout for current workspace
- **Profiles** — Activate saved desktop profiles
- **Disable/Enable Tiling** — Toggle tiling without quitting
- **Quit SonicLand**

## CLI Tool (sonicctl)

SonicLand includes a comprehensive CLI tool for scripting and automation.

```bash
# Window management
sonicctl focus left|right|up|down
sonicctl move left|right|up|down
sonicctl toggle-float
sonicctl move-to-master
sonicctl rotate [cw|ccw]
sonicctl toggle-fullscreen

# Resize
sonicctl grow-width | shrink-width | grow-height | shrink-height
sonicctl normalize
sonicctl master-ratio 0.05      # Adjust by delta
sonicctl master-count 1         # Adjust by delta

# Layout
sonicctl set-layout masterStack
sonicctl cycle-layout
sonicctl get-layout

# Workspaces
sonicctl switch-workspace 3
sonicctl move-window --workspace 2
sonicctl rename-workspace 1 "Dev"
sonicctl create-workspace "Temp"
sonicctl list-workspaces
sonicctl active-workspace

# Scratchpads
sonicctl toggle-scratchpad terminal
sonicctl list-scratchpads

# Session & Profiles
sonicctl save-session
sonicctl restore-session
sonicctl list-profiles
sonicctl activate-profile Work
sonicctl save-profile "My Setup"

# Query
sonicctl list-windows
sonicctl event-log 20

# System
sonicctl reload
```

## Profiles

Save and restore complete desktop configurations:

```bash
# Save current state
sonicctl save-profile "Work"

# Activate later
sonicctl activate-profile "Work"
```

Profiles store: workspace names, layouts, master ratios, gap settings, window rules, and scratchpad configs. Profiles are saved as JSON in `~/.config/sonicland/profiles/`.

## Session Persistence

SonicLand automatically saves workspace state on quit and restores it on relaunch. This includes workspace names, layout modes, master ratios, and window-to-workspace assignments.

Configure in config:
```
session.enabled = true
session.save_on_quit = true
```

## Event Log

SonicLand logs all internal events for debugging and observability:

```bash
sonicctl event-log 20
```

Events include: window created/destroyed, rules matched, workspace switches, layout changes, monitor connects/disconnects, config reloads, and more.

## Multi-Monitor

SonicLand supports three monitor modes:

- **External Monitor** — Only external displays are tiled
- **Built-in Monitor** — Only the laptop display is tiled
- **Shared Space** — All monitors participate, each with independent layouts

Features:
- Automatic hot-plug detection
- Docked/undocked profile detection
- Per-monitor workspace assignment
- Context rules that react to monitor changes

## Project Structure

```
Sources/
  SonicLand/              # Main app
    Core/                 # Window management, accessibility
    Input/                # Hotkey handling
    Config/               # Config file parsing
    Layout/               # BSP tree + layout engines (master-stack, columns, rows, monocle)
    Monitor/              # Display detection, tiling modes
    Workspace/            # Workspace management, templates
    Rules/                # Window rules + context rules engine
    Animation/            # Window animation
    IPC/                  # Socket server for sonicctl
    Tick/                 # Refresh loop
    EventLog/             # Event logging system
    Scratchpad/           # Scratchpad manager
    Overlay/              # Visual overlays (workspace name, focus ring, workspace map)
    Profile/              # Profile system
    Session/              # Session persistence
    Plugin/               # Plugin system
  sonicctl/               # CLI tool
Config/
  sonicland.conf.example
Resources/
  Info.plist
  AppIcon.icns
```

## License

See [LICENSE](LICENSE) for details. Free for personal use.
