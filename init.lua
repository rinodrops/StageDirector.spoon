--- StageDirector.spoon/init.lua
-- Window management Spoon for Hammerspoon, compatible with macOS Stage Manager
-- by Rino, Aug 2024

local obj = {}
obj.__index = obj

-- Metadata
obj.name = "StageDirector"
obj.version = "1.0"
obj.author = "Rino"
obj.homepage = "https://github.com/rinodrops/StageDirector.spoon"
obj.license = "MIT - https://opensource.org/licenses/MIT"

-- Logger
obj.logger = hs.logger.new('StageDirector')

-- Configuration (can be changed by the user)
obj.stageManagerWidth = 64  -- Width of Stage Manager sidebar
obj.windowGap = 8           -- Gap between windows
obj.edgeGap = 8             -- Gap between windows and screen edges
obj.almostMaximizeSizes = {0.9, 0.65}  -- Default sizes for Almost Maximize

-- Internal variables
local stageManagerEnabled = false
local dockPosition = "bottom"
local currentMaximizeState = 0

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
end

-- Get the adjusted frame considering Stage Manager and gaps
local function getAdjustedFrame(screen)
    local max = screen:frame()
    local leftOffset = (stageManagerEnabled and dockPosition ~= "left") and obj.stageManagerWidth or 0
    local rightOffset = (stageManagerEnabled and dockPosition == "left") and obj.stageManagerWidth or 0
    return {
        x = max.x + leftOffset + obj.edgeGap,
        y = max.y + obj.edgeGap,
        w = max.w - leftOffset - rightOffset - (2 * obj.edgeGap),
        h = max.h - (2 * obj.edgeGap)
    }
end

-- Calculate width considering gaps
local function calculateWidth(sf, fraction)
    return (sf.w - ((1 / fraction) - 1) * obj.windowGap) * fraction
end

-- Calculate height considering gaps
local function calculateHeight(sf, fraction)
    return (sf.h - ((1 / fraction) - 1) * obj.windowGap) * fraction
end

-- Check if two numbers are almost equal (within 5% tolerance)
local function isAlmostEqual(a, b)
    return math.abs(a - b) <= 0.05 * b
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

-- Check if a window is almost centered on the screen
local function isAlmostCentered(win, screen)
    local wf = win:frame()
    local sf = getAdjustedFrame(screen)
    local centerX = sf.x + (sf.w - wf.w) / 2
    local centerY = sf.y + (sf.h - wf.h) / 2
    return isAlmostEqual(wf.x, centerX) and isAlmostEqual(wf.y, centerY)
end

-- Get the current size index for almost maximize
local function getCurrentSizeIndex(win, screen)
    local wf = win:frame()
    local sf = getAdjustedFrame(screen)
    local currentSize = math.min(wf.w / sf.w, wf.h / sf.h)
    for i, size in ipairs(obj.almostMaximizeSizes) do
        if isAlmostEqual(currentSize, size) then
            return i
        end
    end
    return nil
end

-- Public Methods

-- Initialize the Spoon
function obj:init()
    updateStageManagerAndDockInfo()
end

-- Move or resize window in a specific direction
function obj:moveOrResize(direction)
    return function()
        local win = hs.window.focusedWindow()
        local screen = win:screen()
        local sf = getAdjustedFrame(screen)
        local wf = win:frame()

        local atEdge = isAtEdge(win, screen, direction)
        local currentFractionW = getCurrentSizeFraction(win, screen, "w")
        local currentFractionH = getCurrentSizeFraction(win, screen, "h")

        if direction == "left" or direction == "right" then
            local isLeft = (direction == "left")
            if not atEdge then
                wf.x = isLeft and sf.x or (sf.x + sf.w - wf.w)
            else
                if isAlmostEqual(currentFractionW, 1/2) then
                    wf.w = calculateWidth(sf, 1/3)
                elseif isAlmostEqual(currentFractionW, 1/3) then
                    wf.w = calculateWidth(sf, 1/4)
                else
                    wf.w = calculateWidth(sf, 1/2)
                end
                wf.x = isLeft and sf.x or (sf.x + sf.w - wf.w)
                wf.y = sf.y
                wf.h = sf.h
            end
        elseif direction == "top" or direction == "bottom" then
            local isTop = (direction == "top")
            if not atEdge then
                wf.y = isTop and sf.y or (sf.y + sf.h - wf.h)
            else
                if isAlmostEqual(currentFractionH, 1/2) then
                    wf.h = calculateHeight(sf, 1/3)
                elseif isAlmostEqual(currentFractionH, 1/3) then
                    wf.h = calculateHeight(sf, 1/4)
                else
                    wf.h = calculateHeight(sf, 1/2)
                end
                wf.x = sf.x
                wf.y = isTop and sf.y or (sf.y + sf.h - wf.h)
                wf.w = sf.w
            end
        end

        win:setFrame(wf)
    end
end

-- Move or resize window to a specific corner
function obj:moveOrResizeCorner(corner)
    return function()
        local win = hs.window.focusedWindow()
        local screen = win:screen()
        local sf = getAdjustedFrame(screen)
        local wf = win:frame()

        local isLeft = (corner == 1 or corner == 3)
        local isTop = (corner == 1 or corner == 2)

        local atCorner = isAtEdge(win, screen, isLeft and "left" or "right") and
                         isAtEdge(win, screen, isTop and "top" or "bottom")

        if not atCorner then
            wf.x = isLeft and sf.x or (sf.x + sf.w - wf.w)
            wf.y = isTop and sf.y or (sf.y + sf.h - wf.h)
        else
            local currentFractionW = getCurrentSizeFraction(win, screen, "w")
            local currentFractionH = getCurrentSizeFraction(win, screen, "h")
            if currentFractionW == 1/2 and currentFractionH == 1/2 then
                wf.w = calculateWidth(sf, 1/3)
                wf.h = calculateHeight(sf, 1/3)
            elseif currentFractionW == 1/3 and currentFractionH == 1/3 then
                wf.w = calculateWidth(sf, 1/4)
                wf.h = calculateHeight(sf, 1/4)
            else
                wf.w = calculateWidth(sf, 1/2)
                wf.h = calculateHeight(sf, 1/2)
            end
            wf.x = isLeft and sf.x or (sf.x + sf.w - wf.w)
            wf.y = isTop and sf.y or (sf.y + sf.h - wf.h)
        end

        win:setFrame(wf)
    end
end

-- Toggle between different maximize states
function obj:toggleMaximize()
    return function()
        local win = hs.window.focusedWindow()
        local screen = win:screen()
        local sf = getAdjustedFrame(screen)
        local wf = win:frame()

        local isCentered = isAlmostCentered(win, screen)
        local currentIndex = getCurrentSizeIndex(win, screen)

        local newSize
        if not isCentered or not currentIndex then
            newSize = obj.almostMaximizeSizes[1]
        else
            local nextIndex = (currentIndex % (#obj.almostMaximizeSizes + 1)) + 1
            if nextIndex > #obj.almostMaximizeSizes then
                wf = sf
                win:setFrame(wf)
                return
            else
                newSize = obj.almostMaximizeSizes[nextIndex]
            end
        end

        wf.w = sf.w * newSize
        wf.h = sf.h * newSize
        wf.x = sf.x + (sf.w - wf.w) / 2
        wf.y = sf.y + (sf.h - wf.h) / 2

        win:setFrame(wf)
    end
end

-- Maximize the height of the window
function obj:maximizeHeight()
    return function()
        local win = hs.window.focusedWindow()
        local f = win:frame()
        local screen = win:screen()
        local max = getAdjustedFrame(screen)
        f.y = max.y
        f.h = max.h
        win:setFrame(f)
    end
end

-- Center the window on the screen
function obj:center()
    return function()
        local win = hs.window.focusedWindow()
        local f = win:frame()
        local screen = win:screen()
        local max = getAdjustedFrame(screen)
        f.x = max.x + (max.w - f.w) / 2
        f.y = max.y + (max.h - f.h) / 2
        win:setFrame(f)
    end
end

-- Move the window to the upper center of the screen
function obj:upperCenter()
    return function()
        local win = hs.window.focusedWindow()
        local f = win:frame()
        local screen = win:screen()
        local max = getAdjustedFrame(screen)
        f.x = max.x + (max.w - f.w) / 2
        f.y = max.y + (max.h - f.h) / 3
        win:setFrame(f)
    end
end

-- Set custom sizes for almost maximize feature
function obj:setCustomMaximizeSizes(sizes)
    if type(sizes) == "table" and #sizes > 0 then
        obj.almostMaximizeSizes = sizes
        currentMaximizeState = 0  -- Reset the state when changing sizes
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

-- Set all gaps and Stage Manager width at once
function obj:setAllGaps(windowGap, edgeGap, stageManagerWidth)
    self:setWindowGap(windowGap)
    self:setEdgeGap(edgeGap)
    self:setStageManagerWidth(stageManagerWidth)
end

return obj
