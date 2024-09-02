# StageDirector.spoon

StageDirector is a powerful and flexible window management Spoon for Hammerspoon, designed to work seamlessly with macOS Stage Manager while providing precise control over window positioning and sizing. It offers advanced features for single and multi-monitor setups, with special consideration for the macOS Stage Manager.

## Features

- Compatible with macOS Stage Manager
- Precise window positioning and resizing
- Customizable window gaps and edge gaps
- Adjustable Stage Manager width
- Multiple maximize states (including "almost maximize")
- Corner snapping with intelligent resizing
- Center and upper-center window positioning
- Multi-monitor support
- Easy to configure and extend

## Requirements

- macOS
- [Hammerspoon](http://www.hammerspoon.org/)

## Installation

1. Install Hammerspoon if you haven't already.
2. Download the StageDirector.spoon directory.
3. Open your Hammerspoon configuration directory (usually `~/.hammerspoon/`).
4. Place the StageDirector.spoon directory in the `Spoons` subdirectory.
5. Add the following to your `init.lua`:

```lua
local StageDirector = hs.loadSpoon("StageDirector")
```

## Configuration

Here's a comprehensive configuration to get you started:

```lua
local StageDirector = hs.loadSpoon("StageDirector")

if StageDirector then
    -- Initialize the Spoon
    StageDirector:init()

    -- Configure gaps and Stage Manager width
    StageDirector:setWindowGap(8)
    StageDirector:setEdgeGap(8)
    StageDirector:setStageManagerWidth(64)
    StageDirector:setCustomMaximizeSizes({0.9, 0.75, 0.6})

    -- Set up hotkeys
    local ctrlCmd = {"cmd", "ctrl"}
    local ctrlOptCmd = {"ctrl", "alt", "cmd"}

    -- Edge movement and resizing
    hs.hotkey.bind(ctrlCmd, "left", StageDirector:moveOrResize("left"))
    hs.hotkey.bind(ctrlCmd, "right", StageDirector:moveOrResize("right"))
    hs.hotkey.bind(ctrlCmd, "up", StageDirector:moveOrResize("top"))
    hs.hotkey.bind(ctrlCmd, "down", StageDirector:moveOrResize("bottom"))

    -- Corner movement and resizing
    hs.hotkey.bind(ctrlCmd, "1", StageDirector:moveOrResizeCorner(1))
    hs.hotkey.bind(ctrlCmd, "2", StageDirector:moveOrResizeCorner(2))
    hs.hotkey.bind(ctrlCmd, "3", StageDirector:moveOrResizeCorner(3))
    hs.hotkey.bind(ctrlCmd, "4", StageDirector:moveOrResizeCorner(4))

    -- Maximize and almost maximize
    hs.hotkey.bind(ctrlCmd, "return", StageDirector:toggleMaximize())

    -- Center and upper-center positioning
    hs.hotkey.bind(ctrlCmd, "c", StageDirector:center())
    hs.hotkey.bind(ctrlCmd, "u", StageDirector:upperCenter())

    -- Multi-monitor movement
    hs.hotkey.bind(ctrlOptCmd, "right", StageDirector:moveToScreen("next"))
    hs.hotkey.bind(ctrlOptCmd, "left", StageDirector:moveToScreen("prev"))

    -- Stage Manager stage change (example for first 4 stages)
    for i = 1, 4 do
        hs.hotkey.bind(ctrlOptCmd, tostring(i), function() StageDirector:changeStage(i) end)
    end
else
    hs.alert.show("Failed to load StageDirector Spoon")
end
```

## Usage and Behavior

### Basic Window Management

- Move window to left/right half of screen: `⌃⌘ Left/Right`
  - If not at edge: Moves to edge without resizing (snap)
  - If at edge: Cycles through widths (1/2 -> 1/3 -> 1/4 -> 1/2) while maintaining full height
- Move window to top/bottom half of screen: `⌃⌘ Up/Down`
  - If not at edge: Moves to edge without resizing (snap)
  - If at edge: Cycles through heights (1/2 -> 1/3 -> 1/4 -> 1/2) while maintaining full width

### Corner Positioning

- Move window to corners: `⌃⌘1` (top-left), `⌃⌘2` (top-right), `⌃⌘3` (bottom-left), `⌃⌘4` (bottom-right)
  - If not at corner: Moves to corner without resizing (snap)
  - If at corner: Cycles through sizes (1/2x1/2 -> 1/3x1/2 -> 1/4x1/2 -> 1/2x1/4 -> back to start)

### Special Functions

- Toggle maximize (cycles through almost maximize states): `⌃⌘ Return`
  - Cycles through custom "almost maximize" sizes and full maximize
- Center window: `⌃⌘C`
- Move window to upper-center: `⌃⌘U`

### Multi-Monitor Support

- Move window to next screen: `⌃⌥⌘ Right`
- Move window to previous screen: `⌃⌥⌘ Left`
  - Maintains relative size and position when moving between screens

### Stage Manager Integration

- Change to specific Stage Manager stage: `⌃⌥⌘1`, `⌃⌥⌘2`, `⌃⌥⌘3`, `⌃⌥⌘4` (for stages 1-4)
- Automatically detects Stage Manager state (enabled/disabled)
- Accounts for Stage Manager sidebar in all calculations

### Overlap Avoidance

- When resizing to left/right and there's a window at top/bottom with 1/4 height, sets current window to 3/4 height
- When resizing to top/bottom and there's a window at left/right with 1/4 width, sets current window to 3/4 width

## API Reference

StageDirector provides the following public methods:

1. `init()`: Initializes the Spoon.
2. `moveOrResize(direction)`: Moves or resizes the window in the specified direction ("left", "right", "top", "bottom").
3. `moveOrResizeCorner(corner)`: Moves or resizes the window to the specified corner (1: top-left, 2: top-right, 3: bottom-left, 4: bottom-right).
4. `setCustomMaximizeSizes(sizes)`: Sets custom sizes for the "almost maximize" feature. Expects a table of numbers between 0 and 1.
5. `toggleMaximize()`: Toggles between different maximize states (including "almost maximize" states).
6. `center()`: Centers the window on the screen.
7. `upperCenter()`: Positions the window at the upper center of the screen.
8. `moveToScreen(direction)`: Moves the window to the next or previous screen.
9. `changeStage(stageNumber)`: Changes the Stage Manager stage.
10. `setStageManagerWidth(width)`: Sets the width of the Stage Manager sidebar in pixels.
11. `setWindowGap(gap)`: Sets the gap between windows in pixels.
12. `setEdgeGap(gap)`: Sets the gap between windows and screen edges in pixels.
13. `setAllGaps(windowGap, edgeGap)`: Sets all gaps at once.

## Customization

### Adjusting Gaps

You can adjust window gaps and edge gaps at runtime:

```lua
StageDirector:setWindowGap(10)
StageDirector:setEdgeGap(12)
```

### Changing Stage Manager Width

If the default Stage Manager width doesn't match your system, you can adjust it:

```lua
StageDirector:setStageManagerWidth(70)
```

### Customizing Almost Maximize Sizes

You can set custom sizes for the "almost maximize" feature:

```lua
StageDirector:setCustomMaximizeSizes({0.8, 0.7, 0.6})
```

## Performance and Compatibility

StageDirector is designed to work efficiently with both single and multi-monitor setups. It periodically updates Stage Manager and Dock information to ensure compatibility with system changes.

## Contributing

Contributions to StageDirector are welcome! Please feel free to submit a Pull Request or open an issue on the GitHub repository.

## License

StageDirector is released under the MIT License. See the LICENSE file for more details.

## Acknowledgements

StageDirector was created by Rino and is inspired by various window management tools and the needs of power users in the macOS ecosystem.
