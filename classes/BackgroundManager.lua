-- Infinite Runner Game - Love2D
-- License: MIT
-- Copyright (c) 2025 Jericho Crosby (Chalwk)

local ipairs = ipairs
local math_pi = math.pi
local math_sin = math.sin
local math_random = math.random
local table_insert = table.insert
local lg = love.graphics

local BackgroundManager = {}
BackgroundManager.__index = BackgroundManager

local function initFloatingElements(self)
    self.floatingElements = {}
    local elementCount = 25

    for _ = 1, elementCount do
        local elementType = math_random(1, 3)
        local element = {
            x = math_random() * 1200,
            y = math_random() * 600,
            size = math_random(15, 35),
            speedX = math_random(-40, -80),
            speedY = math_random(-5, 5),
            rotation = math_random() * math_pi * 2,
            rotationSpeed = (math_random() - 0.5) * 1,
            bobSpeed = math_random(1, 3),
            bobAmount = math_random(2, 6),
            alpha = math_random(0.2, 0.6)
        }

        if elementType == 1 then
            -- Running stick figure
            element.type = "runner"
            element.color = { math_random(0.7, 0.9), math_random(0.7, 0.9), math_random(0.8, 1.0) }
        elseif elementType == 2 then
            -- Obstacle
            element.type = "obstacle"
            element.color = { math_random(0.8, 0.9), math_random(0.3, 0.5), math_random(0.3, 0.5) }
        else
            -- Power-up
            element.type = "powerup"
            element.color = { math_random(0.3, 0.6), math_random(0.7, 0.9), math_random(0.3, 0.6) }
        end

        table_insert(self.floatingElements, element)
    end
end

local function initClouds(self)
    self.clouds = {}
    local cloudCount = 8

    for _ = 1, cloudCount do
        table_insert(self.clouds, {
            x = math_random() * 1000,
            y = math_random(50, 200),
            width = math_random(80, 150),
            height = math_random(30, 60),
            speed = math_random(20, 50),
            alpha = math_random(0.3, 0.7)
        })
    end
end

function BackgroundManager.new()
    local instance = setmetatable({}, BackgroundManager)
    instance.floatingElements = {}
    instance.clouds = {}
    instance.time = 0
    instance.parallaxOffset = 0

    initFloatingElements(instance)
    initClouds(instance)

    return instance
end

function BackgroundManager:update(dt)
    self.time = self.time + dt
    -- Remove the modulo operation to prevent resetting
    self.parallaxOffset = self.parallaxOffset + dt * 50

    -- Update floating elements (unchanged)
    for _, element in ipairs(self.floatingElements) do
        element.x = element.x + element.speedX * dt
        element.y = element.y + element.speedY * dt

        -- Bobbing motion
        element.y = element.y + math_sin(self.time * element.bobSpeed) * element.bobAmount * dt
        element.rotation = element.rotation + element.rotationSpeed * dt

        -- Wrap around screen edges
        if element.x < -100 then element.x = 1300 end
        if element.x > 1300 then element.x = -100 end
        if element.y < -100 then element.y = 700 end
        if element.y > 700 then element.y = -100 end
    end

    -- Update clouds
    for _, cloud in ipairs(self.clouds) do
        cloud.x = cloud.x - cloud.speed * dt
        -- Reset cloud when it goes completely off-screen
        if cloud.x + cloud.width < 0 then
            cloud.x = 1200 -- Reset to right side
            cloud.y = math_random(50, 200)
        end
    end
end

function BackgroundManager:drawMenuBackground(screenWidth, screenHeight, time)
    -- Sky gradient with time-based color shifts
    for y = 0, screenHeight, 2 do
        local progress = y / screenHeight
        local timeShift = math_sin(time * 0.5) * 0.1
        local wave = math_sin(progress * 6 + time * 2) * 0.03

        local r = 0.1 + progress * 0.4 + timeShift + wave
        local g = 0.2 + progress * 0.3 + timeShift
        local b = 0.4 + progress * 0.5 + timeShift

        lg.setColor(r, g, b, 0.9)
        lg.rectangle("fill", 0, y, screenWidth, 2)
    end

    -- Draw clouds
    for _, cloud in ipairs(self.clouds) do
        lg.setColor(1, 1, 1, cloud.alpha)

        -- Cloud with multiple circles for fluffy effect
        local segments = 4
        for i = 1, segments do
            local offsetX = (i - 1) * (cloud.width / segments)
            local circleSize = cloud.height * (0.6 + math_sin(time + i) * 0.2)
            lg.circle("fill", cloud.x + offsetX, cloud.y, circleSize)
        end
    end

    -- Draw floating elements
    for _, element in ipairs(self.floatingElements) do
        local bobOffset = math_sin(time * element.bobSpeed) * element.bobAmount
        local currentY = element.y + bobOffset
        local currentAlpha = element.alpha * (0.7 + math_sin(time * 2) * 0.3)

        lg.push()
        lg.translate(element.x, currentY)
        lg.rotate(element.rotation)

        lg.setColor(element.color[1], element.color[2], element.color[3], currentAlpha)

        if element.type == "runner" then
            -- Draw simplified running stick figure
            lg.setLineWidth(2)
            lg.circle("line", 0, -element.size / 3, element.size / 4)         -- Head
            lg.line(0, -element.size / 6, 0, element.size / 3)                -- Body
            lg.line(0, element.size / 3, -element.size / 3, element.size / 2) -- Left leg
            lg.line(0, element.size / 3, element.size / 3, element.size / 2)  -- Right leg
            lg.line(0, 0, -element.size / 2, -element.size / 6)               -- Left arm
            lg.line(0, 0, element.size / 2, -element.size / 6)                -- Right arm
            lg.setLineWidth(1)
        elseif element.type == "obstacle" then
            -- Draw obstacle
            lg.rectangle("fill", -element.size / 2, -element.size / 3, element.size, element.size / 1.5)
        else
            -- Draw power-up as diamond
            lg.polygon("fill",
                0, -element.size / 2,
                element.size / 2, 0,
                0, element.size / 2,
                -element.size / 2, 0
            )
        end

        lg.pop()
    end

    -- Distant mountains
    lg.setColor(0.2, 0.3, 0.4, 0.6)
    for i = 1, 3 do
        local mountainHeight = 150 + i * 30
        local mountainWidth = screenWidth / (4 - i)
        local peakOffset = (math_sin(time * 0.2 + i) + 1) * 20

        for x = 0, screenWidth, mountainWidth do
            lg.polygon("fill",
                x, screenHeight - 100,
                x + mountainWidth / 2, screenHeight - 100 - mountainHeight + peakOffset,
                x + mountainWidth, screenHeight - 100
            )
        end
    end
end

function BackgroundManager:drawGameBackground(screenWidth, screenHeight, time)
    -- Dynamic sky that changes with time
    local skyPulse = math_sin(time * 0.3) * 0.1 + 0.9

    for y = 0, screenHeight, 1.5 do
        local progress = y / screenHeight
        local wave = math_sin(progress * 8 + time * 1.5) * 0.02
        local pulse = math_sin(progress * 4 + time) * 0.01

        local r = 0.05 * skyPulse + wave + pulse
        local g = 0.1 * skyPulse + progress * 0.1 + wave
        local b = 0.2 * skyPulse + progress * 0.2 + pulse

        lg.setColor(r, g, b, 0.9)
        lg.rectangle("fill", 0, y, screenWidth, 1.5)
    end

    -- Moving clouds with parallax
    for _, cloud in ipairs(self.clouds) do
        local parallaxFactor = cloud.speed / 50
        local cloudX = cloud.x - self.parallaxOffset * parallaxFactor

        -- Only draw if cloud is visible on screen
        if cloudX + cloud.width > 0 and cloudX < screenWidth then
            lg.setColor(0.9, 0.9, 1, cloud.alpha * 0.8)

            -- Simple cloud shape
            lg.rectangle("fill", cloudX, cloud.y, cloud.width, cloud.height, 10)
            lg.circle("fill", cloudX + cloud.width / 4, cloud.y, cloud.height)
            lg.circle("fill", cloudX + cloud.width * 3 / 4, cloud.y, cloud.height)
        end
    end

    -- Distant scenery that moves slower (parallax)
    lg.setColor(0.3, 0.4, 0.5, 0.4)
    for i = 1, 10 do
        -- Use modulo to create seamless looping without jumps
        local treeX = (i * 120 - self.parallaxOffset * 0.3) % (screenWidth + 120)
        local treeHeight = 80 + math_sin(time + i) * 10

        -- Simple trees
        lg.rectangle("fill", treeX, screenHeight - 180, 15, treeHeight)
        lg.setColor(0.2, 0.5, 0.2, 0.4)
        lg.circle("fill", treeX + 7, screenHeight - 180 - 20, 25)
        lg.setColor(0.3, 0.4, 0.5, 0.4)
    end

    -- Floating particles in background
    for _, element in ipairs(self.floatingElements) do
        if element.type == "powerup" then -- Only draw power-ups in game background
            local bobOffset = math_sin(time * element.bobSpeed) * element.bobAmount
            local currentY = element.y + bobOffset
            local pulse = math_sin(time * 3 + element.x * 0.01) * 0.4 + 0.6
            local currentAlpha = element.alpha * pulse * 0.5

            lg.push()
            lg.translate(element.x, currentY)
            lg.rotate(element.rotation + time * 0.5)

            lg.setColor(element.color[1], element.color[2], element.color[3], currentAlpha)
            lg.polygon("fill",
                0, -element.size / 3,
                element.size / 3, 0,
                0, element.size / 3,
                -element.size / 3, 0
            )

            lg.pop()
        end
    end

    -- Horizon line
    lg.setColor(0.4, 0.5, 0.6, 0.3)
    lg.setLineWidth(2)
    lg.line(0, screenHeight - 200, screenWidth, screenHeight - 200)
    lg.setLineWidth(1)
end

return BackgroundManager
