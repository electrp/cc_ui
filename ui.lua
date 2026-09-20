ui = { version = "0.0.1" }

-- The data structures are only here for visibility, arangement can be converted to visibility

local function no_bound(display) return {0, 0} end
local function max_rect(a, b) 
    return {
        math.max(a[1], b[1]),
        math.max(a[2], b[2]),
    }
end
local function min_rect(a, b) 
    return {
        math.max(a[1], b[1]),
        math.max(a[2], b[3]),
    }
end
local function apply_padding(rect, padding) 
    if type(padding) == "number" then
        return {
            rect[1] + padding * 2,
            rect[2] + padding * 2,
        }
    else
        return {
            rect[1] + padding[1] + padding[2],
            rect[2] + padding[3] + padding[4],
        }
    end
end

local function calculate_final_size(element, context, dimension)
    local extend = element.extend[dimension]
    local max = 9999999999
    if element.max_bounds then
        if element.max_bounds.percentage and element.max_bounds.percentage[dimension] then
            max = context.size * element.max_bounds[dimension]
        else
            max = element.max_bounds[dimension]
        end
    end
    local ret
    -- If fill
    if extend == 3 then
        ret = context.size[dimension]
    -- If fit
    elseif extend == 2 then
        ret = element.calculated_bounds[dimension]
    -- If none
    else
        ret = element.min_bounds[dimension]
    end
    return math.min(max, ret)
end

-- Computes our minimum size basedon how much the child requests from us
local function compute_child_requested_size(element, dimension)
    -- Add percentages together from position and min_bounds to get the percent that
    -- the element covers
    local coverage = 0
    -- Offset is the offset from either corner, adding values of position and min_bounds
    local offset = 0

    if element.position.percentage and element.position.percentage[dimension] then
        coverage = coverage + element.position.percentage[dimension]
    else
        offset = offset + element.position[dimension] 
    end
    if element.min_bounds.percentage and element.min_bounds.percentage[dimension] then
        coverage = coverage + element.min_bounds.percentage[dimension]
    else
        offset = offset + element.min_bounds[dimension]
    end

    -- Max bounds may clamp down on our estimate
    local clamped = element.computed_bounds[dimension] * (1 / coverage)
    if element.max_bounds then
        if element.max_bounds.percentage and element.max_bounds.percentage[dimension] then
            -- Reduce coverage if we are limited by percentage
            coverage = math.min(coverage, element.max_bounds.percentage[dimension])
            clamped = element.computed_bounds[dimension] * (1 / coverage)
        else
            -- Reduce space if limited by pixels
            clamped = math.min(element.computed_bounds[dimension] * (1 / coverage), element.max_bounds[dimension]) 
        end
    else 
        clamped = element.computed_bounds[dimension] * (1 / coverage)
    end

    return clamped + offset
end

ui.Extend = {
    None = 1,
    -- Fit based on children's rules
    Fit = 2,
    -- Fill based on parents size
    Fill = 3,
}

ui.Direction = {
    Up = 1,
    Down = 2,
    Left = 3,
    Right = 4,
}

ui.DisplayType = {
    None = 1,
    -- Drawing of text
    Text = 2,
    -- Draws image from a image source
    Image = 3,
    -- Draws a filled box
    FilledBox = 4,
    -- Draws an outline
    Box = 5,
}

ui.Justification = {
    Left = 0x01, Middle = 0x02, Right = 0x03,
    Top = 0x10, Center = 0x20, Bottom = 0x30
}

ui.PassthroughColor = 0
ui.MaxBoundsExactSizing = 1
ui.MaxBoundsExtend = 1


-- Helpers
local calculate_display_bounds = {
    [ui.DisplayType.None] = no_bound,
    [ui.DisplayType.FilledBox] = no_bound,
    [ui.DisplayType.Box] = no_bound,

    [ui.DisplayType.Text] = function(element) 
        return {#display.text, 1} 
    end,
    [ui.DisplayType.Image] = function(element) 
        if element.image then
            return {#element.image, #element.image[1]} 
        else
            return {0, 0}
        end
    end
}

local display_element = {
    [ui.DisplayType.None] = function(element, context) end,
    [ui.DisplayType.FilledBox] = function(element, context) 
        paintutils.drawFilledBox(
            context.position[1], 
            context.position[2], 
            context.position[1] + context.size[1] - 1,
            context.position[2] + context.size[2] - 1)
    end,
    [ui.DisplayType.Box] = function(element, context)
        paintutils.drawFilledBox(
            context.position[1], 
            context.position[2], 
            context.position[1] + context.size[1] - 1,
            context.position[2] + context.size[2] - 1)
    end,
    [ui.DisplayType.Text] = function(element, context)
        local pos = {}
        local out = ""
        -- Handle l/r justification and clipping
        if bit.band(element.justification, Justifaction.Left) then
            pos[1] = 0
            out = string.sub(element.text, 1, context.size[1])
        elseif bit.band(element.justification, ui.Justification.Right) then
            pos[1] = math.max(0, context.size[1] - #element.text)
            over = #element.text - context.size[1]
            out = string.sub(element.text, math.max(over + 1, 1))
        else
            pos[1] = math.max(0, math.floor((context.size[1] - #element.text) / 2))
            over = (#element.text - context.size[1]) / 2
            out = string.sub(element.text, math.max(math.floor(over) + 1, 1), #element.text - math.ceil(over))
        end
        -- Handle top/bottom justification
        if bit.band(element.justification, ui.Justification.Top) then
            pos[2] = 0
        elseif bit.band(element.justification, ui.Justification.Bottom) then
            pos[2] = context.size[2]
        else
            pos[2] = context.size[2] / 2
        end
        term.setCursorPos(pos[1], pos[2])
        term.write(out)
    end,
    [ui.DisplayType.Image] = function(element, context) 
        -- TODO: draw image that gets clipped by context
    end
}

-- Like html/ecs, we check elements to see what they do and render them as such.
-- children are stored in the array section
-- Default to 1x1 size so you can actually see if theres a random pixel
ui.Element = {
    new = function(table)
        table = table or {}
        setmetatable(a, self)
        self.__index = self
        return table
    end,


    add_child = function(self, params, front)
        local sub = Element:new(params)
        if front then
            table.insert(self, 1, sub)
        else
            table.insert(self, sub)
        end
    end,

    -- Calculates bounds for all children
    -- index is 1 or 2, x or y
    calculate_bounds = function(self, dimension)
        if self.dirty.size == true then
            -- Quickly recalculate bounds based on display and min_bounds
            local display_size = calculate_display_bounds[self.display_type](self.display)[dimension]
            computed_bounds[dimension] = self.min_bounds[dimension] + display_size
        end

        -- If we care about our children's size
        if self.extend[dimension] == Extend.Fit and self.dirty.size == true then
            -- precompute padding
            local padding
            if type(self.padding) == "number" then
                padding = self.padding * 2
            else    
                padding = self.padding[1 + (dimension - 1) * 2] + self.padding[2 + (dimension - 1) * 2]
            end

            -- Check the children for their computed sizes
            for i, child in ipairs(self) do
                child:calculate_bounds(dimension)
                local c_bound = compute_child_requested_size(child, dimension) + padding
                c_bound = c_bound + self.index * inner_padding[dimension]
                self.computed_bounds[dimension] = math.max(self.computed_bounds[dimension], c_bound)
            end
        else
            for i, child in ipairs(self) do
                child:calculate_bounds(dimension)
            end
        end
    end,

    -- Context is { position [x, y], size [x, y] } of allowed space
    display_search = function(self, context)
        -- If theres no dirty subtrees return
        if self.dirty.child_content == false then
            return
        end

        if self.dirty.content then
            display(self)
        else
            for i, child in ipairs(self) do
                display_search(child) 
            end
        end
    end,

    -- Context is { position [x, y], size [x, y] } of allowed space
    display = function(self, context)
        -- Save and update our colors
        local prev_primary = term.getBackgroundColor()
        local prev_secondary = term.getTextColor()
        if self.primary_color then
            term.setBackgroundColor(self.primary_color)
        end
        if self.secondary_color then
            term.setTextColor(self.secondary_color)
        end

        -- Calculate our size
        local final_size = {
            calculate_final_size(self, context, 1),
            calculate_final_size(self, context, 2),
        }

        local display_context = { context.position, final_size }
        -- use our display
        display_element(self, display_context)

        -- display our children
        for i, child in ipairs(self) do
            display(child)
        end
        
        term.setBackgroundColor(prev_primary)
        term.setTextColor(prev_secondary)
    end,

    draw = function(self)
        calculate_bounds(self)
        display(self)
    end,
    
    -- prototype data, see below for more details
    hide = false,
    position = { 1, 1 },
    index = { 1, 1 },
    min_bounds = { 1, 1 },
    extend = { ui.Extend.Fit, ui.Extend.Fit},
    padding = 0,
    inner_padding = 0,
    display_type = ui.DisplayType.None,
    primary_color = ui.PassthroughColor,
    secondary_color = ui.PassthroughColor,
    display_type = ui.DisplayType.None,
    text =  "??!!??",
    justification = bit.bor(ui.Justification.Middle, ui.Justification.Center),
    image = nil,
    primary_color = ui.PassthroughColor,
    secondary_color = ui.PassthroughColor,
    mouse_through = true,
    -- runtime data
    parent = nil,
    calculated_bounds = {
        0, 0
    },
    dirty = {
        size = true,
        content = true,
    }
}

return ui

-- Element has a lot of different settings, with optinal behavior based on variables set
--[[

hide : bool = false

-- Array with table component
position = {
    -- x and y position
    1 : int = 1
    2 : int = 1

    -- Specify either pixel or percent based positioning
    percentage : nil
               : { 1 : bool, 2 : bool }
}


-- Used for inner padding. If you have a grid, use this to specify
-- where in the grid you are.
index = {
    1 : int = 1
    2 : int = 1
}

min_bounds = {
    1 : int
    2 : int

    -- Specify either pixel or percent based positioning
    percentage : nil
               : { 1 : bool, 2 : bool }
}
max_bounds : nil
           : {
                 1 : int
                 2 : int

                 -- Specify either pixel or percent based positioning
                 percentage : nil
                            : { 1 : bool, 2 : bool }       
             }

extend {
    1 : Extend = Fit
    2 : Extend = Fit
}

-- Padding can either be a constant or an array of directional paddings
padding : int
        : { Direction.Up : int, Down : int, Left : int, Right : int }
inner_padding : int
              : { Direction.Up : int, Down : int, Left : int, Right : int }

-- how it displays
display_type : DisplayType = DisplayType.None
text : string =  "??!!??"
justification : Justification = Middle | Center
image : image = nil

-- color as -1 means passthrough
-- Color used for drawing boxes and text background
primary_color : color = PassthroughColor
-- Color used for text 
secondary_color : color = PassthroughColor

-- If the mouse passes through
mouse_through : bool = false
              : array[int]

-- These are computed values when displaying the image. This does not necesarially
-- specify the minimum bounds of the object, but the amount of space it needs to
-- display itself with its given parameters
calculated_bounds = {
    1 : int
    2 : int
}
dirty = {
    -- True if the sizing information changed and requires reflow
    -- Applies up the tree if parent element relies on child
    size: bool
    -- True if only content changed
    content: bool
    -- True if a child had content changed
    child_content: bool
}
]]
