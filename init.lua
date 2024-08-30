--- StageDirector.spoon/init.lua
-- by Rino, Aug 2024

local obj = {}
obj.__index = obj

-- Metadata
obj.name = "StageDirector"
obj.version = "1.0"
obj.author = "Rino"
obj.homepage = "https://github.com/rinodrops/StageDirector.spoon"
obj.license = "MIT - https://opensource.org/licenses/MIT"

-- Configuration
obj.stageManagerWidth = 64
obj.windowGap = 8
obj.edgeGap = 8
obj.almostMaximizeSizes = {0.9, 0.65}  -- Default sizes for Almost Maximize

-- Internal variables
local stageManagerEnabled = false
local dockPosition = "bottom"
local currentMaximizeState = 0

-- Helper functions
local function runCommand(cmd)
    local handle = io.popen(cmd)
    local result = handle:read("*a")
    handle:close()
    return result:gsub("%s+", "")  -- Trim whitespace
end

local function updateStageManagerAndDockInfo()
    stageManagerEnabled = (runCommand("defaults read com.apple.WindowManager GloballyEnabled") == "1")
    dockPosition = runCommand("defaults read com.apple.dock orientation")
end

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

local function calculateWidth(sf, fraction)
    return (sf.w - ((1 / fraction) - 1) * obj.windowGap) * fraction
end

local function calculateHeight(sf, fraction)
    return (sf.h - ((1 / fraction) - 1) * obj.windowGap) * fraction
end

local function isAlmostEqual(a, b)
    return math.abs(a - b) <= 0.05 * b
end

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

local function getCurrentSizeFraction(win, screen, dimension)
    local wf = win:frame()
    local sf = getAdjustedFrame(screen)
    local fraction = (dimension == "w") and (wf.w / sf.w) or (wf.h / sf.h)
    if isAlmostEqual(fraction, 1/2) then return 1/2
    elseif isAlmostEqual(fraction, 1/3) then return 1/3
    elseif isAlmostEqual(fraction, 1/4) then return 1/4
    else return fraction end
end

local function isAlmostCentered(win, screen)
    local wf = win:frame()
    local sf = getAdjustedFrame(screen)
    local centerX = sf.x + (sf.w - wf.w) / 2
    local centerY = sf.y + (sf.h - wf.h) / 2
    return isAlmostEqual(wf.x, centerX) and isAlmostEqual(wf.y, centerY)
end

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

-- Main functions
function obj:moveOrResize(direction)
    return function()
        local win = hs.window.focusedWindow()
        local screen = win:screen()
        local sf = getAdjustedFrame(screen)
        local wf = win:frame()

        local atEdge = isAtEdge(win, screen, direction)
        local currentFractionW = getCurrentSizeFraction(win, screen, "w")
        local currentFractionH = getCurrentSizeFraction(win, screen, "h")

        local function isAlmostMaxHeight()
            return isAlmostEqual(wf.h, sf.h)
        end

        if direction == "left" or direction == "right" then
            local isLeft = (direction == "left")
            if not atEdge then
                -- Move to edge without resizing
                wf.x = isLeft and sf.x or (sf.x + sf.w - wf.w)
            else
                -- At edge, determine next action
                if isAlmostEqual(currentFractionW, 1/2) and isAlmostMaxHeight() then
                    wf.w = calculateWidth(sf, 1/3)
                elseif isAlmostEqual(currentFractionW, 1/3) and isAlmostMaxHeight() then
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
                -- Move to edge without resizing
                wf.y = isTop and sf.y or (sf.y + sf.h - wf.h)
            else
                -- At edge, determine next action
                if isAlmostEqual(currentFractionH, 1/2) and isAlmostEqual(wf.w, sf.w) then
                    wf.h = calculateHeight(sf, 1/3)
                elseif isAlmostEqual(currentFractionH, 1/3) and isAlmostEqual(wf.w, sf.w) then
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
            -- Move to corner without resizing
            wf.x = isLeft and sf.x or (sf.x + sf.w - wf.w)
            wf.y = isTop and sf.y or (sf.y + sf.h - wf.h)
        else
            -- Resize
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

function obj:toggleMaximize()
    local win = hs.window.focusedWindow()
    local screen = win:screen()
    local sf = getAdjustedFrame(screen)
    local wf = win:frame()

    local isCentered = isAlmostCentered(win, screen)
    local currentIndex = getCurrentSizeIndex(win, screen)

    local newSize
    if not isCentered or not currentIndex then
        -- If not centered or size doesn't match any in the table, use the first size
        newSize = obj.almostMaximizeSizes[1]
    else
        -- If centered, cycle through sizes
        local nextIndex = (currentIndex % (#obj.almostMaximizeSizes + 1)) + 1
        if nextIndex > #obj.almostMaximizeSizes then
            -- Full maximize
            wf = sf
            win:setFrame(wf)
            return
        else
            newSize = obj.almostMaximizeSizes[nextIndex]
        end
    end

    -- Apply the new size
    wf.w = sf.w * newSize
    wf.h = sf.h * newSize
    wf.x = sf.x + (sf.w - wf.w) / 2
    wf.y = sf.y + (sf.h - wf.h) / 2

    win:setFrame(wf)
end

function obj:maximizeHeight()
    local win = hs.window.focusedWindow()
    local f = win:frame()
    local screen = win:screen()
    local max = getAdjustedFrame(screen)
    f.y = max.y
    f.h = max.h
    win:setFrame(f)
end

function obj:center()
    local win = hs.window.focusedWindow()
    local f = win:frame()
    local screen = win:screen()
    local max = getAdjustedFrame(screen)
    f.x = max.x + (max.w - f.w) / 2
    f.y = max.y + (max.h - f.h) / 2
    win:setFrame(f)
end

function obj:upperCenter()
    local win = hs.window.focusedWindow()
    local f = win:frame()
    local screen = win:screen()
    local max = getAdjustedFrame(screen)
    f.x = max.x + (max.w - f.w) / 2
    f.y = max.y + (max.h - f.h) / 3
    win:setFrame(f)
end

function obj:setCustomMaximizeSizes(sizes)
    if type(sizes) == "table" and #sizes > 0 then
        obj.almostMaximizeSizes = sizes
        currentMaximizeState = 0  -- Reset the state when changing sizes
    else
        print("Invalid input. Please provide a table with at least one size value.")
    end
end

function obj:setStageManagerWidth(width)
    if type(width) == "number" and width > 0 then
        self.stageManagerWidth = width
        updateStageManagerAndDockInfo()  -- Refresh internal state
        print("Stage Manager width set to " .. width .. " pixels")
    else
        print("Invalid input. Please provide a positive number for the Stage Manager width.")
    end
end

function obj:setWindowGap(gap)
    if type(gap) == "number" and gap >= 0 then
        self.windowGap = gap
        print("Window gap set to " .. gap .. " pixels")
    else
        print("Invalid input. Please provide a non-negative number for the window gap.")
    end
end

function obj:setEdgeGap(gap)
    if type(gap) == "number" and gap >= 0 then
        self.edgeGap = gap
        print("Edge gap set to " .. gap .. " pixels")
    else
        print("Invalid input. Please provide a non-negative number for the edge gap.")
    end
end

function obj:setStageManagerWidth(width)
    if type(width) == "number" and width > 0 then
        self.stageManagerWidth = width
        updateStageManagerAndDockInfo()  -- Refresh internal state
        print("Stage Manager width set to " .. width .. " pixels")
    else
        print("Invalid input. Please provide a positive number for the Stage Manager width.")
    end
end

function obj:setAllGaps(windowGap, edgeGap, stageManagerWidth)
    self:setWindowGap(windowGap)
    self:setEdgeGap(edgeGap)
    self:setStageManagerWidth(stageManagerWidth)
end

function obj:init()
    updateStageManagerAndDockInfo()
end

return obj
