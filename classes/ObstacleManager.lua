-- Infinite Runner
-- License: MIT
-- Copyright (c) 2025 Jericho Crosby (Chalwk)

local ObstacleManager = {}
ObstacleManager.__index = ObstacleManager

function ObstacleManager.new()
    local instance = setmetatable({}, ObstacleManager)

    instance.screenWidth = 800
    instance.screenHeight = 600
    instance.groundY = 450 -- This will be set in setScreenSize

    instance.obstacles = {}
    instance.spawnTimer = 0
    instance.spawnInterval = 2.0
    instance.minSpawnInterval = 0.8

    instance.obstacleTypes = {
        {
            name = "pit",
            width = 80,
            height = 50,
            color = { 0.2, 0.2, 0.4 },
            requires = "jump"
        },
        {
            name = "wall",
            width = 40,
            height = 80,
            color = { 0.8, 0.2, 0.2 },
            requires = "jump"
        },
        {
            name = "low_wall",
            width = 60,
            height = 40,
            color = { 0.8, 0.5, 0.2 },
            requires = "crouch"
        },
        {
            name = "spikes",
            width = 60,
            height = 20,
            color = { 0.8, 0.1, 0.1 },
            requires = "jump"
        }
    }

    -- Moving obstacles
    instance.movingObstacles = {
        {
            name = "projectile",
            width = 20,
            height = 20,
            color = { 0.9, 0.9, 0.1 },
            speedY = 0,
            pattern = "horizontal"
        },
        {
            name = "swinging",
            width = 50,
            height = 10,
            color = { 0.2, 0.8, 0.2 },
            pattern = "pendulum"
        }
    }

    return instance
end

function ObstacleManager:setScreenSize(width, height)
    self.screenWidth = width
    self.screenHeight = height
    self.groundY = height - 150 -- Ground is 150px from bottom
end

function ObstacleManager:update(dt, gameSpeed)
    -- Update spawn timer and interval
    self.spawnTimer = self.spawnTimer + dt
    self.spawnInterval = math.max(self.minSpawnInterval, 2.0 - (gameSpeed - 200) / 1000)

    -- Spawn new obstacles
    if self.spawnTimer >= self.spawnInterval then
        self.spawnTimer = 0
        self:spawnObstacle()
    end

    -- Update existing obstacles
    for i = #self.obstacles, 1, -1 do
        local obstacle = self.obstacles[i]
        obstacle.x = obstacle.x - gameSpeed * dt

        -- Update moving obstacles
        if obstacle.pattern == "horizontal" then
            obstacle.y = obstacle.baseY + math.sin(obstacle.time * 3) * 50
            obstacle.time = obstacle.time + dt
        elseif obstacle.pattern == "pendulum" then
            obstacle.angle = obstacle.angle + dt * 4
            obstacle.y = obstacle.baseY + math.sin(obstacle.angle) * 100
        end

        -- Remove off-screen obstacles
        if obstacle.x + obstacle.width < 0 then
            table.remove(self.obstacles, i)
        end
    end
end

function ObstacleManager:spawnObstacle()
    local obstacleType = math.random(1, #self.obstacleTypes + #self.movingObstacles)
    local obstacle

    if obstacleType <= #self.obstacleTypes then
        -- Static obstacle - place on ground
        local staticType = self.obstacleTypes[obstacleType]
        obstacle = {
            x = self.screenWidth,
            y = self.groundY - staticType.height, -- Position on ground
            width = staticType.width,
            height = staticType.height,
            color = staticType.color,
            name = staticType.name,
            requires = staticType.requires,
            pattern = "static"
        }
    else
        -- Moving obstacle
        local movingType = self.movingObstacles[obstacleType - #self.obstacleTypes]
        obstacle = {
            x = self.screenWidth,
            baseY = self.groundY - 100, -- Reference from ground
            y = self.groundY - 100,
            width = movingType.width,
            height = movingType.height,
            color = movingType.color,
            name = movingType.name,
            pattern = movingType.pattern,
            time = 0,
            angle = math.random() * math.pi * 2
        }
    end

    table.insert(self.obstacles, obstacle)
end

function ObstacleManager:draw()
    for _, obstacle in ipairs(self.obstacles) do
        love.graphics.setColor(obstacle.color)

        if obstacle.name == "spikes" then
            -- Draw triangular spikes
            for i = 0, obstacle.width / 10 - 1 do
                local spikeX = obstacle.x + i * 10
                love.graphics.polygon("fill",
                    spikeX, obstacle.y + obstacle.height,
                    spikeX + 5, obstacle.y,
                    spikeX + 10, obstacle.y + obstacle.height
                )
            end
        elseif obstacle.pattern == "pendulum" then
            -- Draw swinging obstacle with chain
            love.graphics.setColor(0.5, 0.5, 0.5)
            love.graphics.line(obstacle.x + obstacle.width / 2, obstacle.baseY - 100,
                obstacle.x + obstacle.width / 2, obstacle.y)
            love.graphics.setColor(obstacle.color)
            love.graphics.rectangle("fill", obstacle.x, obstacle.y, obstacle.width, obstacle.height)
        else
            love.graphics.rectangle("fill", obstacle.x, obstacle.y, obstacle.width, obstacle.height)
        end
    end
end

function ObstacleManager:checkCollisions(player)
    local playerHitbox = player:getHitbox()

    -- Debug: draw player hitbox (optional)
    -- love.graphics.setColor(0, 1, 0, 0.3)
    -- love.graphics.rectangle("line", playerHitbox.x, playerHitbox.y, playerHitbox.width, playerHitbox.height)

    for _, obstacle in ipairs(self.obstacles) do
        local obstacleHitbox = {
            x = obstacle.x,
            y = obstacle.y,
            width = obstacle.width,
            height = obstacle.height
        }

        -- Debug: draw obstacle hitbox (optional)
        -- love.graphics.setColor(1, 0, 0, 0.3)
        -- love.graphics.rectangle("line", obstacleHitbox.x, obstacleHitbox.y, obstacleHitbox.width, obstacleHitbox.height)

        if self:checkRectCollision(playerHitbox, obstacleHitbox) then
            return true
        end
    end

    return false
end

function ObstacleManager:checkRectCollision(rect1, rect2)
    return rect1.x < rect2.x + rect2.width and
        rect1.x + rect1.width > rect2.x and
        rect1.y < rect2.y + rect2.height and
        rect1.y + rect1.height > rect2.y
end

function ObstacleManager:reset()
    self.obstacles = {}
    self.spawnTimer = 0
end

return ObstacleManager
