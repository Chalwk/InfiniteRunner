-- Infinite Runner
-- License: MIT
-- Copyright (c) 2025 Jericho Crosby (Chalwk)

local BackgroundManager = {}
BackgroundManager.__index = BackgroundManager

function BackgroundManager.new()
    local instance = setmetatable({}, BackgroundManager)

    instance.screenWidth = 800
    instance.screenHeight = 600

    -- Parallax layers (distant to foreground)
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
        local elementCount = 10

        for i = 1, elementCount do
            local x = (i - 1) * (self.screenWidth / elementCount)
            local height = math.random(50, 200) * (1 - layer.speed * 0.5)
            local width = math.random(80, 200) * (1 - layer.speed * 0.5)

            local element = {
                x = x,
                y = self.screenHeight - height,
                width = width,
                height = height,
                peaks = math.random(3, 6),
                points = {}
            }

            -- Pre-generate a smooth, natural mountain silhouette
            local peakCount = element.peaks
            local segmentWidth = element.width / peakCount
            local lastY = element.y + element.height

            for j = 0, peakCount do
                local px = element.x + j * segmentWidth
                local t = j / peakCount
                local falloff = 1 - math.abs(t - 0.5) * 2
                local variance = math.random() * 0.4 + 0.6
                local py = element.y - element.height * falloff * variance
                py = (py + lastY) / 2
                lastY = py
                table.insert(element.points, { x = px, y = py })
            end

            table.insert(layer.elements, element)
        end
    end
end

function BackgroundManager:update(dt, gameSpeed)
    for _, layer in ipairs(self.layers) do
        for _, element in ipairs(layer.elements) do
            element.x = element.x - gameSpeed * dt * layer.speed

            -- Move pre-generated points too
            for _, p in ipairs(element.points) do
                p.x = p.x - gameSpeed * dt * layer.speed
            end

            -- Wrap around when fully off screen
            if element.x + element.width < 0 then
                local offset = self.screenWidth + element.width
                element.x = element.x + offset
                for _, p in ipairs(element.points) do
                    p.x = p.x + offset
                end
            end
        end
    end
end

function BackgroundManager:draw()
    -- Sky gradient
    for i = 0, self.screenHeight do
        local progress = i / self.screenHeight
        local r = 0.05 + progress * 0.1
        local g = 0.02 + progress * 0.05
        local b = 0.1 + progress * 0.15
        love.graphics.setColor(r, g, b)
        love.graphics.line(0, i, self.screenWidth, i)
    end

    -- Parallax mountain layers
    for _, layer in ipairs(self.layers) do
        for _, element in ipairs(layer.elements) do
            love.graphics.setColor(layer.color)
            self:drawMountain(
                element.x,
                element.y,
                element.width,
                element.height,
                element.peaks,
                element.points
            )
        end
    end

    -- Ground base
    love.graphics.setColor(0.3, 0.2, 0.1)
    love.graphics.rectangle("fill", 0, self.screenHeight - 150, self.screenWidth, 150)

    -- Ground texture lines
    love.graphics.setColor(0.4, 0.3, 0.2)
    for i = 0, self.screenWidth, 20 do
        love.graphics.line(i, self.screenHeight - 150, i + 10, self.screenHeight - 140)
    end
end

function BackgroundManager:drawMountain(x, y, width, height, peaks, points)
    local poly = { x, y + height }

    for _, p in ipairs(points) do
        table.insert(poly, p.x)
        table.insert(poly, p.y)
    end

    table.insert(poly, x + width)
    table.insert(poly, y + height)

    love.graphics.polygon("fill", poly)
end

return BackgroundManager
