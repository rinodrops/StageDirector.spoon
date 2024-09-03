-- StageDirector.spoon/init.lua
-- Advanced Window management Spoon for Hammerspoon, compatible with macOS Stage Manager
-- by Rino, Sep 2024

local obj = {}
obj.__index = obj

-- Metadata
obj.name = "StageDirector"
obj.version = "2.1.1"
obj.author = "Rino"
obj.homepage = "https://github.com/rinodrops/StageDirector.spoon"
obj.license = "MIT - https://opensource.org/licenses/MIT"

-- Logger
obj.logger = hs.logger.new('StageDirector', "debug")

-- Configuration (can be changed by the user)
obj.stageManagerWidth = 40  -- Width of Stage Manager sidebar
obj.windowGap = 8           -- Gap between windows
obj.edgeGap = 8             -- Gap between windows and screen edges
obj.almostMaximizeSizes = {0.9, 0.65}  -- Default sizes for Almost Maximize
obj.animationDelay = 0      -- Animation delay in seconds

-- Internal variables
local stageManagerEnabled = false
local dockPosition = "bottom"
local equalityTolerance = 0.02  -- 2% tolerance for "almost equal" comparisons
local currentStage = 1  -- Keep track of the current stage

-- Helper Functions

-- Run a shell command and return its output
local function runCommand(cmd)
    local handle = io.popen(cmd)
    local result = handle:read("*a")
    handle:close()
    return result:gsub("%s+", "")  -- Trim whitespace
end

-- Update Stage Manager and Dock information
local function updateStageManagerAndDockInfo()
    stageManagerEnabled = (runCommand("defaults read com.apple.WindowManager GloballyEnabled") == "1")
    dockPosition = runCommand("defaults read com.apple.dock orientation")
    obj.logger.i("Stage Manager: " .. (stageManagerEnabled and "Enabled" or "Disabled") .. ", Dock: " .. dockPosition)
end

-- Get the adjusted frame considering Stage Manager and gaps
local function getAdjustedFrame(screen)
    local max = screen:frame()  -- This already accounts for the menu bar
    local leftOffset = (stageManagerEnabled and dockPosition ~= "left") and obj.stageManagerWidth or 0
    local rightOffset = (stageManagerEnabled and dockPosition == "left") and obj.stageManagerWidth or 0

    return {
        x = max.x + leftOffset + obj.edgeGap,
        y = max.y + obj.edgeGap,
        w = max.w - leftOffset - rightOffset - (2 * obj.edgeGap),
        h = max.h - (2 * obj.edgeGap)
    }
end

-- Check if two numbers are almost equal
local function isAlmostEqual(a, b)
    return math.abs(a - b) <= equalityTolerance * math.max(math.abs(a), math.abs(b))
end

-- Check if a window is at a specific edge of the screen
local function isAtEdge(win, screen, edge)
    local wf = win:frame()
    local sf = getAdjustedFrame(screen)
    if edge == "left" then
        return isAlmostEqual(wf.x, sf.x)
    elseif edge == "right" then
        return isAlmostEqual(wf.x + wf.w, sf.x + sf.w)
    elseif edge == "top" then
        return isAlmostEqual(wf.y, sf.y)
    elseif edge == "bottom" then
        return isAlmostEqual(wf.y + wf.h, sf.y + sf.h)
    end
    return false
end

-- Check if a window is at a corner
local function isAtCorner(win, screen, corner)
    local edges = {
        [1] = {"left", "top"},
        [2] = {"right", "top"},
        [3] = {"left", "bottom"},
        [4] = {"right", "bottom"}
    }
    return isAtEdge(win, screen, edges[corner][1]) and isAtEdge(win, screen, edges[corner][2])
end

-- Check if a window is in a specific corner
local function isWindowInCorner(screen, corner)
    local windows = hs.window.visibleWindows()
    local sf = getAdjustedFrame(screen)
    for _, win in ipairs(windows) do
        if win:screen() == screen and not win:isFullScreen() then
            local wf = win:frame()
            if corner == "top-left" and isAlmostEqual(wf.x, sf.x) and isAlmostEqual(wf.y, sf.y) and isAlmostEqual(wf.h, sf.h / 4) then
                return win
            elseif corner == "top-right" and isAlmostEqual(wf.x + wf.w, sf.x + sf.w) and isAlmostEqual(wf.y, sf.y) and isAlmostEqual(wf.h, sf.h / 4) then
                return win
            elseif corner == "bottom-left" and isAlmostEqual(wf.x, sf.x) and isAlmostEqual(wf.y + wf.h, sf.y + sf.h) and isAlmostEqual(wf.h, sf.h / 4) then
                return win
            elseif corner == "bottom-right" and isAlmostEqual(wf.x + wf.w, sf.x + sf.w) and isAlmostEqual(wf.y + wf.h, sf.y + sf.h) and isAlmostEqual(wf.h, sf.h / 4) then
                return win
            end
        end
    end
    return nil
end

-- Check if a window's height is approximately 1/4 of the screen height
local function isWindowHeightQuarter(window, screen)
    local wf = window:frame()
    local sf = getAdjustedFrame(screen)
    return isAlmostEqual(wf.h, sf.h / 4)
end

-- Calculate width considering gaps
local function calculateWidth(sf, fraction)
    return math.floor((sf.w - ((1 / fraction) - 1) * obj.windowGap) * fraction)
end

-- Calculate height considering gaps
local function calculateHeight(sf, fraction)
    return math.floor((sf.h - ((1 / fraction) - 1) * obj.windowGap) * fraction)
end

-- Get the current size fraction of a window
local function getCurrentSizeFraction(win, screen, dimension)
    local wf = win:frame()
    local sf = getAdjustedFrame(screen)
    local fraction = (dimension == "w") and (wf.w / sf.w) or (wf.h / sf.h)
    if isAlmostEqual(fraction, 1/2) then return 1/2
    elseif isAlmostEqual(fraction, 1/3) then return 1/3
    elseif isAlmostEqual(fraction, 1/4) then return 1/4
    else return fraction end
end

-- Main Functions

-- Move or resize window in a specific direction
function obj:moveOrResize(direction)
    return function()
        local win = hs.window.focusedWindow()
        if not win then return end

        local screen = win:screen()
        local sf = getAdjustedFrame(screen)
        local wf = win:frame()

        local currentFractionW = getCurrentSizeFraction(win, screen, "w")
        local currentFractionH = getCurrentSizeFraction(win, screen, "h")

        if direction == "left" or direction == "right" then
            local isLeft = (direction == "left")
            local topCorner = isLeft and "top-left" or "top-right"
            local bottomCorner = isLeft and "bottom-left" or "bottom-right"

            local topWindow = isWindowInCorner(screen, topCorner)
            local bottomWindow = isWindowInCorner(screen, bottomCorner)

            -- Check if the corner windows are not the selected window and have 1/4 height
            local topQuarter = topWindow and topWindow ~= win and isWindowHeightQuarter(topWindow, screen)
            local bottomQuarter = bottomWindow and bottomWindow ~= win and isWindowHeightQuarter(bottomWindow, screen)

            -- Determine if we're moving from one side to the other
            local movingAcross = (isLeft and wf.x > sf.x + sf.w/2) or (not isLeft and wf.x < sf.x + sf.w/2)

            -- Determine the next width
            local nextWidth
            if movingAcross then
                nextWidth = calculateWidth(sf, 1/2)
            else
                if isAlmostEqual(currentFractionW, 1/2) then
                    nextWidth = calculateWidth(sf, 1/3)
                elseif isAlmostEqual(currentFractionW, 1/3) then
                    nextWidth = calculateWidth(sf, 1/4)
                elseif isAlmostEqual(currentFractionW, 1/4) then
                    nextWidth = calculateWidth(sf, 2/3)
                elseif isAlmostEqual(currentFractionW, 2/3) then
                    nextWidth = calculateWidth(sf, 3/4)
                elseif isAlmostEqual(currentFractionW, 3/4) then
                    nextWidth = calculateWidth(sf, 1/2)
                else
                    nextWidth = calculateWidth(sf, 1/2)
                end
            end

            -- Scenario 1: No 1/4-height windows at corners
            if not topQuarter and not bottomQuarter then
                if isAtEdge(win, screen, direction) or movingAcross then
                    wf.w = nextWidth
                end
                wf.h = sf.h
                wf.y = sf.y
            -- Scenario 2: 1/4-height window at top corner
            elseif topQuarter and not bottomQuarter then
                wf.y = sf.y + sf.h / 4 + obj.windowGap/2
                wf.h = sf.h * 3/4 - obj.windowGap/2
                wf.w = nextWidth
            -- Scenario 3: 1/4-height window at bottom corner
            elseif bottomQuarter and not topQuarter then
                wf.y = sf.y
                wf.h = sf.h * 3/4 - obj.windowGap/2
                wf.w = nextWidth
            -- Scenario 4: 1/4-height windows at both corners
            elseif topQuarter and bottomQuarter then
                -- wf.y = sf.y + sf.h / 4 + obj.windowGap
                -- wf.h = sf.h / 2 - obj.windowGap * 2
                wf.y = sf.y + sf.h / 4 + obj.windowGap/2
                wf.h = sf.h / 2 - obj.windowGap
                wf.w = nextWidth
            end

            wf.x = isLeft and sf.x or (sf.x + sf.w - wf.w)

        elseif direction == "top" or direction == "bottom" then
            local isTop = (direction == "top")
            if not isAtEdge(win, screen, direction) then
                wf.y = isTop and sf.y or (sf.y + sf.h - wf.h)
            else
                if not isAlmostEqual(wf.w, sf.w) then
                    wf.w = sf.w
                    wf.h = calculateHeight(sf, 1/2)
                else
                    if isAlmostEqual(currentFractionH, 1/2) then
                        wf.h = calculateHeight(sf, 1/3)
                    elseif isAlmostEqual(currentFractionH, 1/3) then
                        wf.h = calculateHeight(sf, 1/4)
                    else
                        wf.h = calculateHeight(sf, 1/2)
                    end
                end
                wf.y = isTop and sf.y or (sf.y + sf.h - wf.h)
                wf.x = sf.x
                wf.w = sf.w
            end
        end

        win:setFrame(wf, obj.animationDelay)
    end
end

-- Move or resize window to a specific corner
function obj:moveOrResizeCorner(corner)
    return function()
        local win = hs.window.focusedWindow()
        if not win then return end

        local screen = win:screen()
        local sf = getAdjustedFrame(screen)
        local wf = win:frame()

        local isLeft = (corner == 1 or corner == 3)
        local isTop = (corner == 1 or corner == 2)

        -- Always set the position first
        wf.x = isLeft and sf.x or (sf.x + sf.w - wf.w)
        wf.y = isTop and sf.y or (sf.y + sf.h - wf.h)

        if not isAtCorner(win, screen, corner) then
            -- If not at the corner, just move to the corner without resizing
            win:setFrame(wf, obj.animationDelay)
        else
            -- If already at the corner, cycle through sizes
            local currentFractionW = getCurrentSizeFraction(win, screen, "w")
            local currentFractionH = getCurrentSizeFraction(win, screen, "h")

            if isAlmostEqual(currentFractionW, 1/2) and isAlmostEqual(currentFractionH, 1/2) then
                wf.w = calculateWidth(sf, 1/3)
                wf.h = calculateHeight(sf, 1/2)
            elseif isAlmostEqual(currentFractionW, 1/3) and isAlmostEqual(currentFractionH, 1/2) then
                wf.w = calculateWidth(sf, 1/4)
                wf.h = calculateHeight(sf, 1/2)
            elseif isAlmostEqual(currentFractionW, 1/4) and isAlmostEqual(currentFractionH, 1/2) then
                wf.w = calculateWidth(sf, 1/2)
                wf.h = calculateHeight(sf, 1/4)
            elseif isAlmostEqual(currentFractionW, 1/2) and isAlmostEqual(currentFractionH, 1/4) then
                wf.w = calculateWidth(sf, 1/3)
                wf.h = calculateHeight(sf, 1/4)
            else
                wf.w = calculateWidth(sf, 1/2)
                wf.h = calculateHeight(sf, 1/2)
            end

            -- Reposition after resizing to ensure it stays in the corner
            wf.x = isLeft and sf.x or (sf.x + sf.w - wf.w)
            wf.y = isTop and sf.y or (sf.y + sf.h - wf.h)
        end

        win:setFrame(wf, obj.animationDelay)
    end
end

-- Toggle between different maximize states
function obj:toggleMaximize()
    return function()
        local win = hs.window.focusedWindow()
        if not win then return end

        local screen = win:screen()
        local sf = getAdjustedFrame(screen)
        local wf = win:frame()

        local currentSize = math.min(wf.w / sf.w, wf.h / sf.h)
        local nextSize

        for i, size in ipairs(obj.almostMaximizeSizes) do
            if isAlmostEqual(currentSize, size) then
                if i == #obj.almostMaximizeSizes then
                    -- If we're at the last almost maximize size, go to full maximize
                    nextSize = 1
                else
                    nextSize = obj.almostMaximizeSizes[i + 1]
                end
                break
            end
        end

        if not nextSize then
            if isAlmostEqual(currentSize, 1) then
                -- If we're at full maximize, go back to the first almost maximize size
                nextSize = obj.almostMaximizeSizes[1]
            else
                -- If we're not at any known size, start with the first almost maximize size
                nextSize = obj.almostMaximizeSizes[1]
            end
        end

        wf.w = sf.w * nextSize
        wf.h = sf.h * nextSize
        wf.x = sf.x + (sf.w - wf.w) / 2
        wf.y = sf.y + (sf.h - wf.h) / 2

        win:setFrame(wf, obj.animationDelay)
    end
end

-- Center the window on the screen
function obj:center()
    return function()
        local win = hs.window.focusedWindow()
        if not win then return end

        local f = win:frame()
        local screen = win:screen()
        local max = getAdjustedFrame(screen)
        f.x = max.x + (max.w - f.w) / 2
        f.y = max.y + (max.h - f.h) / 2
        win:setFrame(f, obj.animationDelay)
    end
end

-- Move the window to the upper center of the screen
function obj:upperCenter()
    return function()
        local win = hs.window.focusedWindow()
        if not win then return end

        local f = win:frame()
        local screen = win:screen()
        local max = getAdjustedFrame(screen)
        f.x = max.x + (max.w - f.w) / 2
        f.y = max.y + (max.h - f.h) / 3
        win:setFrame(f, obj.animationDelay)
    end
end

-- Move window to another screen
function obj:moveToScreen(direction)
    return function()
        local win = hs.window.focusedWindow()
        if not win then return end

        local screen = win:screen()
        local nextScreen = screen:next()

        if direction == "prev" then
            nextScreen = screen:previous()
        end

        local currentFrame = win:frame()
        local currentScreenFrame = screen:frame()

        -- Calculate relative position
        local relativeX = (currentFrame.x - currentScreenFrame.x) / currentScreenFrame.w
        local relativeY = (currentFrame.y - currentScreenFrame.y) / currentScreenFrame.h
        local relativeW = currentFrame.w / currentScreenFrame.w
        local relativeH = currentFrame.h / currentScreenFrame.h

        win:moveToScreen(nextScreen)

        -- Re-apply the relative position on the new screen
        local newScreenFrame = nextScreen:frame()
        local newFrame = {
            x = math.floor(newScreenFrame.x + (relativeX * newScreenFrame.w)),
            y = math.floor(newScreenFrame.y + (relativeY * newScreenFrame.h)),
            w = math.floor(relativeW * newScreenFrame.w),
            h = math.floor(relativeH * newScreenFrame.h)
        }

        win:setFrame(newFrame, obj.animationDelay)
    end
end

-- Get the number of stages
local function getNumberOfStages()
    local script = [[
        tell application "System Events" to tell process "WindowManager"
            tell list 1 of group 1
                return count buttons
            end tell
        end tell
    ]]
    local ok, result = hs.osascript.applescript(script)
    if ok then
        return tonumber(result)
    else
        obj.logger.w("Failed to get number of stages")
        return nil
    end
end

-- Change Stage Manager stage
function obj:changeStage(stageNumber)
    return function()
        local numberOfStages = getNumberOfStages()
        if not numberOfStages then return end

        if stageNumber < 1 or stageNumber > numberOfStages then
            obj.logger.w("Invalid stage number: " .. stageNumber)
            return
        end

        local script = string.format([[
            tell application "System Events" to tell process "WindowManager"
                tell list 1 of group 1
                    click button %d
                end tell
            end tell
        ]], stageNumber)

        local ok, _, _ = hs.osascript.applescript(script)
        if ok then
            currentStage = stageNumber
            obj.logger.i("Changed to Stage " .. stageNumber)
        else
            obj.logger.w("Failed to change Stage")
        end
    end
end

-- Change to the next stage
function obj:nextStage()
    return function()
        local numberOfStages = getNumberOfStages()
        if not numberOfStages then return end

        local nextStage = (currentStage % numberOfStages) + 1

        self:changeStage(nextStage)()
    end
end

-- Change to the previous stage
function obj:prevStage()
    return function()
        local numberOfStages = getNumberOfStages()
        if not numberOfStages then return end

        local prevStage = ((currentStage - 2 + numberOfStages) % numberOfStages) + 1
        self:changeStage(prevStage)()
    end
end

-- Get the current stage number
function obj:getCurrentStage()
    return currentStage
end

-- Configuration functions

-- Set custom sizes for almost maximize feature
function obj:setCustomMaximizeSizes(sizes)
    if type(sizes) == "table" and #sizes > 0 then
        table.sort(sizes, function(a, b) return a > b end)
        obj.almostMaximizeSizes = sizes
        obj.logger.i("Custom maximize sizes set: " .. table.concat(sizes, ", "))
    else
        obj.logger.w("Invalid input. Please provide a table with at least one size value.")
    end
end

-- Set the width of the Stage Manager sidebar
function obj:setStageManagerWidth(width)
    if type(width) == "number" and width > 0 then
        self.stageManagerWidth = width
        updateStageManagerAndDockInfo()
        obj.logger.i("Stage Manager width set to " .. width .. " pixels")
    else
        obj.logger.w("Invalid input. Please provide a positive number for the Stage Manager width.")
    end
end

-- Set the gap between windows
function obj:setWindowGap(gap)
    if type(gap) == "number" and gap >= 0 then
        self.windowGap = gap
        obj.logger.i("Window gap set to " .. gap .. " pixels")
    else
        obj.logger.w("Invalid input. Please provide a non-negative number for the window gap.")
    end
end

-- Set the gap between windows and screen edges
function obj:setEdgeGap(gap)
    if type(gap) == "number" and gap >= 0 then
        self.edgeGap = gap
        obj.logger.i("Edge gap set to " .. gap .. " pixels")
    else
        obj.logger.w("Invalid input. Please provide a non-negative number for the edge gap.")
    end
end

-- Set all gaps at once
function obj:setAllGaps(windowGap, edgeGap)
    self:setWindowGap(windowGap)
    self:setEdgeGap(edgeGap)
end

-- Set the animation delay
function obj:setAnimationDelay(sec)
    if type(sec) == "number" and sec >= 0 then
        self.animationDelay = sec
        obj.logger.i("Animation delay set to " .. sec .. " seconds")
    else
        obj.logger.w("Invalid input. Please provide a non-negative number for the animation delay.")
    end
end

-- Initialize the Spoon
function obj:init()
    updateStageManagerAndDockInfo()

    -- Set up a timer to periodically update Stage Manager and Dock info
    hs.timer.doEvery(300, updateStageManagerAndDockInfo)

    -- Initialize currentStage
    currentStage = 1
end

return obj
