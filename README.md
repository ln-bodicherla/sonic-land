# SonicLand

A fast, keyboard-driven tiling window manager for macOS. SonicLand uses BSP (Binary Space Partitioning) to automatically arrange your windows, supports multiple workspaces, multi-monitor setups, and is fully configurable through a simple text file.

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

SonicLand runs as a menu bar app. It watches for new windows via the macOS Accessibility API and automatically tiles them using a BSP tree layout. Each workspace maintains its own independent layout tree.

When a new window appears, it splits the smallest existing tile (alternating between horizontal and vertical splits). You can navigate between windows, move them around the tree, swap them by dragging, and toggle individual windows to float freely.

## Configuration

Create a config file at `~/.config/sonicland/sonicland.conf`. An example is included in the repo at `Config/sonicland.conf.example`.

### General Settings

```
general.gaps_in = 5          # Gap between tiled windows (pixels)
general.gaps_out = 10         # Gap from screen edges (pixels)
general.border_size = 2       # Border size
general.monitor = all         # Monitor filter: "all", "built-in", "external", or monitor name
```

### Animation

```
animation.enabled = true      # Enable smooth window animations
animation.duration = 200      # Duration in milliseconds
animation.curve = easeOut     # Curve: linear, easeIn, easeOut, easeInOut, spring
```

### Window Rules

Float specific apps or assign them to workspaces automatically.

Format: `windowrule = <action>, <condition>`

Actions:
- `float` - Exclude from tiling
- `workspace <n>` - Assign to workspace 1-9

Conditions:
- `app:<name>` - Match by app name (case-insensitive substring)
- `bundle:<id>` - Match by bundle identifier
- `title:<regex>` - Match by window title (regex)

```
windowrule = float, app:Spotify
windowrule = float, app:Calculator
windowrule = float, app:System Settings
windowrule = workspace 3, app:Slack
windowrule = workspace 4, app:Discord
```

## Keyboard Shortcuts

All shortcuts are configurable in the config file. Defaults use vim-style navigation.

### Focus Navigation

| Shortcut | Action |
|---|---|
| Cmd + Alt + H | Focus window to the left |
| Cmd + Alt + L | Focus window to the right |
| Cmd + Alt + J | Focus window below |
| Cmd + Alt + K | Focus window above |

### Move Windows

| Shortcut | Action |
|---|---|
| Cmd + Alt + Shift + H | Move window left |
| Cmd + Alt + Shift + L | Move window right |
| Cmd + Alt + Shift + J | Move window down |
| Cmd + Alt + Shift + K | Move window up |

### Workspaces

| Shortcut | Action |
|---|---|
| Cmd + Alt + 1-9 | Switch to workspace 1-9 |
| Cmd + Alt + Shift + 1-9 | Move focused window to workspace 1-9 |

### Other

| Shortcut | Action |
|---|---|
| Cmd + Alt + F | Toggle float/tile for focused window |
| Cmd + Alt + Space | Toggle split direction (horizontal/vertical) |
| Cmd + Alt + R | Reload configuration |

### Custom Keybindings

```
bind = <modifiers+key>, <action>
```

Modifiers: `cmd`, `alt` (or `option`), `shift`, `ctrl`

Available actions: `focus_left`, `focus_right`, `focus_up`, `focus_down`, `move_left`, `move_right`, `move_up`, `move_down`, `workspace <n>`, `move_to_workspace <n>`, `toggle_float`, `toggle_layout`, `reload_config`

## Menu Bar

Click the SonicLand icon in the menu bar to access:

- **Monitor Mode** - Choose which monitors to tile:
  - External Monitor - Tile only external displays
  - Built-in Monitor - Tile only the laptop display
  - Shared Space - Distribute windows across all monitors
- **Disable/Enable Tiling** - Toggle tiling without quitting the app
- **Quit SonicLand**

The monitor mode selection persists across app restarts.

## CLI Tool (sonicctl)

SonicLand includes a command-line tool for scripting and automation. It communicates with the running app via a local socket.

```bash
sonicctl switch-workspace <id>           # Switch to workspace (1-9)
sonicctl move-window --workspace <id>    # Move focused window to workspace
sonicctl focus-window <id>               # Focus window by ID
sonicctl list-windows                    # List all managed windows (JSON)
sonicctl list-workspaces                 # List all workspaces (JSON)
sonicctl active-workspace                # Print active workspace ID
sonicctl reload                          # Reload configuration file
```

Build sonicctl:

```bash
swift build -c release
# Binary at .build/release/sonicctl
```

## Window Swapping

Drag any tiled window over another window's position and release. SonicLand detects the overlap and swaps their positions in the layout tree. This works across monitors in Shared Space mode.

## Multi-Monitor

SonicLand supports three monitor modes, selectable from the menu bar:

- **External Monitor** - Only external displays are tiled. Windows on the built-in display float freely.
- **Built-in Monitor** - Only the laptop display is tiled. External monitor windows float.
- **Shared Space** - All monitors participate in tiling. Windows are grouped by their current monitor, and each monitor maintains its own BSP tree.

Each monitor gets its own set of 9 workspaces.

## Project Structure

```
Sources/
  SonicLand/          # Main app
    Core/             # Window management, accessibility
    Input/            # Hotkey handling
    Config/           # Config file parsing
    Layout/           # BSP tree layout engine
    Monitor/          # Display detection, tiling modes
    Workspace/        # Workspace management
    Rules/            # Window rules engine
    Animation/        # Window animation
    IPC/              # Socket server for sonicctl
    Tick/             # Refresh loop
  sonicctl/           # CLI tool
Config/
  sonicland.conf.example
Resources/
  Info.plist
  AppIcon.icns
```

## License

See [LICENSE](LICENSE) for details. Free for personal use.
