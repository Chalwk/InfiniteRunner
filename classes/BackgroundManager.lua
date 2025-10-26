-- Infinite Runner
-- License: MIT
-- Copyright (c) 2025 Jericho Crosby (Chalwk)

local BackgroundManager = {}
BackgroundManager.__index = BackgroundManager

function BackgroundManager.new()
    local instance = setmetatable({}, BackgroundManager)

    instance.screenWidth = 800
    instance.screenHeight = 600

    -- Parallax layers
    instance.layers = {
        {
            speed = 0.2,
            color = { 0.1, 0.05, 0.15 },
            elements = {}
        },
        {
            speed = 0.5,
            color = { 0.15, 0.08, 0.25 },
            elements = {}
        },
        {
            speed = 0.8,
            color = { 0.2, 0.12, 0.35 },
            elements = {}
        }
    }

    instance:generateBackgroundElements()

    return instance
end

function BackgroundManager:setScreenSize(width, height)
    self.screenWidth = width
    self.screenHeight = height
    self:generateBackgroundElements()
end

function BackgroundManager:generateBackgroundElements()
    for _, layer in ipairs(self.layers) do
        layer.elements = {}

        -- Generate mountains/buildings for each layer
        local elementCount = 10
        for i = 1, elementCount do
            local x = (i - 1) * (self.screenWidth / elementCount)
            local height = math.random(50, 200) * (1 - layer.speed * 0.5)
            local width = math.random(80, 200) * (1 - layer.speed * 0.5)

            table.insert(layer.elements, {
                x = x,
                y = self.screenHeight - height,
                width = width,
                height = height,
                peaks = math.random(2, 5)
            })
        end
    end
end

function BackgroundManager:update(dt, gameSpeed)
    for _, layer in ipairs(self.layers) do
        for _, element in ipairs(layer.elements) do
            element.x = element.x - gameSpeed * dt * layer.speed

            -- Wrap around when off screen
            if element.x + element.width < 0 then
                element.x = element.x + self.screenWidth + element.width
            end
        end
    end
end

function BackgroundManager:draw()
    -- Draw sky gradient
    for i = 0, self.screenHeight do
        local progress = i / self.screenHeight
        local r = 0.05 + progress * 0.1
        local g = 0.02 + progress * 0.05
        local b = 0.1 + progress * 0.15
        love.graphics.setColor(r, g, b)
        love.graphics.line(0, i, self.screenWidth, i)
    end

    -- Draw parallax layers
    for _, layer in ipairs(self.layers) do
        love.graphics.setColor(layer.color)

        for _, element in ipairs(layer.elements) do
            -- Draw mountain/building silhouette
            self:drawMountain(element.x, element.y, element.width, element.height, element.peaks)
        end
    end

    -- Draw ground
    love.graphics.setColor(0.3, 0.2, 0.1)
    love.graphics.rectangle("fill", 0, self.screenHeight - 150, self.screenWidth, 150)

    -- Ground details
    love.graphics.setColor(0.4, 0.3, 0.2)
    for i = 0, self.screenWidth, 20 do
        love.graphics.line(i, self.screenHeight - 150, i + 10, self.screenHeight - 140)
    end
end

function BackgroundManager:drawMountain(x, y, width, height, peaks)
    local points = { x, y + height }

    -- Generate mountain peaks
    local segmentWidth = width / (peaks * 2 - 1)
    for i = 0, peaks * 2 - 1 do
        local pointX = x + i * segmentWidth
        local pointY = y

        if i % 2 == 1 then
            -- Peak
            pointY = y - height * math.random(80, 100) / 100
        else
            -- Valley
            pointY = y - height * math.random(20, 40) / 100
        end

        table.insert(points, pointX)
        table.insert(points, pointY)
    end

    table.insert(points, x + width)
    table.insert(points, y + height)

    love.graphics.polygon("fill", points)
end

return BackgroundManager
