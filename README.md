# StageDirector.spoon

StageDirector is a powerful and flexible window management Spoon for Hammerspoon, designed to work seamlessly with macOS Stage Manager while providing precise control over window positioning and sizing.

## Features

- Compatible with macOS Stage Manager
- Precise window positioning and resizing
- Customizable window gaps and edge gaps
- Adjustable Stage Manager width
- Multiple maximize states (including "almost maximize")
- Corner snapping with intelligent resizing
- Center and upper-center window positioning
- Easy to configure and extend

## Requirements

- macOS 10.10+
- [Hammerspoon](http://www.hammerspoon.org/)

## Installation

1. Install Hammerspoon if you haven't already.
2. Download the StageDirector.spoon directory.
3. Open your Hammerspoon configuration directory (usually `~/.hammerspoon/`).
4. Place the StageDirector.spoon directory in the `Spoons` subdirectory.
5. Add the following to your `init.lua`:

```lua
hs.loadSpoon("StageDirector")
```

## Configuration

Here's a basic configuration to get you started:

```lua
local StageDirector = hs.loadSpoon("StageDirector")

if StageDirector then
    StageDirector:init()

    -- Configure gaps and Stage Manager width
    StageDirector:setWindowGap(8)
    StageDirector:setEdgeGap(8)
    StageDirector:setStageManagerWidth(64)
    StageDirector:setCustomMaximizeSizes({0.9, 0.65})

    -- Set up hotkeys
    local ctrlCmd = {"cmd", "ctrl"}
    hs.hotkey.bind(ctrlCmd, "left", StageDirector:moveOrResize("left"))
    hs.hotkey.bind(ctrlCmd, "right", StageDirector:moveOrResize("right"))
    hs.hotkey.bind(ctrlCmd, "up", StageDirector:moveOrResize("top"))
    hs.hotkey.bind(ctrlCmd, "down", StageDirector:moveOrResize("bottom"))

    hs.hotkey.bind(ctrlCmd, "1", StageDirector:moveOrResizeCorner(1))
    hs.hotkey.bind(ctrlCmd, "2", StageDirector:moveOrResizeCorner(2))
    hs.hotkey.bind(ctrlCmd, "3", StageDirector:moveOrResizeCorner(3))
    hs.hotkey.bind(ctrlCmd, "4", StageDirector:moveOrResizeCorner(4))

    hs.hotkey.bind(ctrlCmd, "return", StageDirector:toggleMaximize())
    hs.hotkey.bind(ctrlCmd, "c", StageDirector:center())
    hs.hotkey.bind(ctrlCmd, "u", StageDirector:upperCenter())
else
    hs.alert.show("Failed to load StageDirector Spoon")
end
```

## Usage

### Basic Window Management

- Move window to left half of screen: `⌃⌘ Left`
- Move window to right half of screen: `⌃⌘ Right`
- Move window to top half of screen: `⌃⌘ Up`
- Move window to bottom half of screen: `⌃⌘ Down`

### Corner Positioning

- Move window to top-left corner: `⌃⌘1`
- Move window to top-right corner: `⌃⌘2`
- Move window to bottom-left corner: `⌃⌘3`
- Move window to bottom-right corner: `⌃⌘4`

### Special Functions

- Toggle maximize (cycles through almost maximize states): `⌃⌘ Return`
- Center window: `⌃⌘c`
- Move window to upper-center: `⌃⌘u`

## API Reference

StageDirector provides the following public methods:

1. `init()`: Initializes the Spoon.
2. `moveOrResize(direction)`: Moves or resizes the window in the specified direction ("left", "right", "top", "bottom").
3. `moveOrResizeCorner(corner)`: Moves or resizes the window to the specified corner (1: top-left, 2: top-right, 3: bottom-left, 4: bottom-right).
4. `setCustomMaximizeSizes(sizes)`: Sets custom sizes for the "almost maximize" feature. Expects a table of numbers between 0 and 1.
5. `toggleMaximize()`: Toggles between different maximize states (including "almost maximize" states).
6. `maximizeHeight()`: Maximizes the window height while maintaining its width.
7. `center()`: Centers the window on the screen.
8. `upperCenter()`: Positions the window at the upper center of the screen.
9. `setStageManagerWidth(width)`: Sets the width of the Stage Manager sidebar in pixels.
10. `setWindowGap(gap)`: Sets the gap between windows in pixels.
11. `setEdgeGap(gap)`: Sets the gap between windows and screen edges in pixels.
12. `setAllGaps(windowGap, edgeGap, stageManagerWidth)`: Sets all gaps and Stage Manager width at once.

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

`toggleMaximize` toggles these sizes and the maximized.

## Contributing

Contributions to StageDirector are welcome! Please feel free to submit a Pull Request.

## Acknowledgements

StageDirector was created by Rino and is inspired by various window management tools and the macOS Stage Manager feature.
