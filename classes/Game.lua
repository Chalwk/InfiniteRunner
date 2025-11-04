-- Infinite Runner Game - Love2D
-- License: MIT
-- Copyright (c) 2025 Jericho Crosby (Chalwk)

local pairs = pairs
local ipairs = ipairs
local math_floor = math.floor
local math_sin = math.sin
local math_min = math.min
local math_max = math.max
local table_insert = table.insert
local table_remove = table.remove

local love_random = love.math.random
local lg = love.graphics

local Game = {}
Game.__index = Game

function Game.new()
    local instance = setmetatable({}, Game)

    instance.screenWidth = 800
    instance.screenHeight = 600
    instance.gameOver = false
    instance.score = 0
    instance.highScore = 0
    instance.distance = 0
    instance.gameSpeed = 200
    instance.baseSpeed = 200
    instance.maxSpeed = 600
    instance.speedIncreaseRate = 0.1
    instance.time = 0

    -- Player properties
    instance.player = {
        x = 150,
        y = 0,
        width = 30,
        height = 60,
        groundY = 400,
        jumpVelocity = 0,
        jumpPower = -600,
        gravity = 1600,
        isJumping = false,
        isCrouching = false,
        normalHeight = 60,
        crouchHeight = 30,
        animationTime = 0,
        runCycle = 0
    }

    instance.player.y = instance.player.groundY - instance.player.height

    -- Game objects
    instance.obstacles = {}
    instance.powerUps = {}
    instance.particles = {}
    instance.groundSegments = {}

    -- Game settings
    instance.obstacleSpawnTimer = 0
    instance.obstacleSpawnRate = 1.5 -- seconds between obstacles
    instance.minObstacleSpawnRate = 0.8
    instance.spawnRateDecrease = 0.05

    instance.powerUpSpawnTimer = 0
    instance.powerUpSpawnRate = 8 -- seconds between power-ups

    -- Active power-ups
    instance.activePowerUps = {}

    instance.obstacleTypes = {
        {
            name = "low_barrier",
            width = 20,
            height = 40,
            yOffset = 0,
            requireJump = true,
            color = { 0.8, 0.3, 0.3 }
        },
        {
            name = "high_barrier",
            width = 40,
            height = 60,
            yOffset = -20,
            requireCrouch = true,
            color = { 0.8, 0.5, 0.2 }
        },
        {
            name = "gap",
            width = 80,
            height = 10,
            yOffset = 10,
            isGap = true,
            color = { 0.3, 0.3, 0.8 }
        },
        {
            name = "spikes",
            width = 60,
            height = 20,
            yOffset = 0,
            isSpikes = true,
            color = { 0.8, 0.2, 0.2 }
        },
        {
            name = "moving_barrier",
            width = 25,
            height = 50,
            yOffset = 0,
            isMoving = true,
            moveRange = 100,
            moveSpeed = 2,
            moveDirection = 1,
            requireJump = true,
            color = { 0.7, 0.3, 0.7 }
        }
    }

    instance.powerUpTypes = {
        {
            name = "speed_boost",
            width = 25,
            height = 25,
            color = { 0.2, 0.8, 0.2 },
            duration = 5,
            effect = function(player) return { type = "speed", multiplier = 1.5 } end
        },
        {
            name = "invincibility",
            width = 25,
            height = 25,
            color = { 1, 1, 0.2 },
            duration = 3,
            effect = function(player) return { type = "invincible" } end
        },
        {
            name = "magnet",
            width = 25,
            height = 25,
            color = { 0.8, 0.3, 0.8 },
            duration = 6,
            effect = function(player) return { type = "magnet" } end
        },
        {
            name = "double_points",
            width = 25,
            height = 25,
            color = { 0.2, 0.7, 1 },
            duration = 8,
            effect = function(player) return { type = "double_points" } end
        },
        {
            name = "slow_motion",
            width = 25,
            height = 25,
            color = { 0.5, 0.5, 1 },
            duration = 4,
            effect = function(player) return { type = "slow_mo", multiplier = 0.5 } end
        }
    }

    -- Initialize ground
    instance:initGround()

    return instance
end

function Game:initGround()
    self.groundSegments = {}
    local segmentWidth = 100
    local numSegments = math_floor(self.screenWidth / segmentWidth) + 2

    for i = 1, numSegments do
        table_insert(self.groundSegments, {
            x = (i - 1) * segmentWidth,
            y = self.player.groundY,
            width = segmentWidth,
            height = 20
        })
    end
end

function Game:spawnObstacle()
    local obstacle = self.obstacleTypes[love_random(#self.obstacleTypes)]
    local newObstacle = {
        x = self.screenWidth,
        y = self.player.groundY - obstacle.height + obstacle.yOffset,
        width = obstacle.width,
        height = obstacle.height,
        type = obstacle.name,
        color = obstacle.color,
        passed = false
    }

    -- Copy additional properties
    for k, v in pairs(obstacle) do
        if k ~= "name" and k ~= "width" and k ~= "height" and k ~= "yOffset" and k ~= "color" then
            newObstacle[k] = v
        end
    end

    if newObstacle.isMoving then
        newObstacle.originalY = newObstacle.y
        newObstacle.moveTime = 0
    end

    table_insert(self.obstacles, newObstacle)
end

function Game:spawnPowerUp()
    local powerUp = self.powerUpTypes[love_random(#self.powerUpTypes)]

    table_insert(self.powerUps, {
        x = self.screenWidth,
        y = self.player.groundY - 60,
        width = powerUp.width,
        height = powerUp.height,
        type = powerUp.name,
        color = powerUp.color,
        duration = powerUp.duration,
        effect = powerUp.effect,
        collected = false,
        bounce = 0
    })
end

function Game:activatePowerUp(powerUp)
    local effect = powerUp.effect(self.player)
    effect.endTime = self.time + powerUp.duration
    self.activePowerUps[effect.type] = effect

    -- Visual feedback
    self:createParticles(powerUp.x + powerUp.width / 2, powerUp.y + powerUp.height / 2, powerUp.color, 15)
end

function Game:updatePowerUps(dt)
    -- Check for expired power-ups
    for powerType, effect in pairs(self.activePowerUps) do
        if self.time >= effect.endTime then
            self.activePowerUps[powerType] = nil
        end
    end

    -- Apply power-up effects
    if self.activePowerUps.speed then
        self.gameSpeed = self.baseSpeed * self.activePowerUps.speed.multiplier
    elseif self.activePowerUps.slow_mo then
        self.gameSpeed = self.baseSpeed * self.activePowerUps.slow_mo.multiplier
    else
        -- Gradually increase speed
        self.gameSpeed = math_min(self.baseSpeed + self.distance * self.speedIncreaseRate, self.maxSpeed)
    end
end

function Game:checkCollisions()
    if self.activePowerUps.invincible then return false end

    local player = self.player
    for _, obstacle in ipairs(self.obstacles) do
        if self:rectIntersect(player.x, player.y, player.width, player.height,
                obstacle.x, obstacle.y, obstacle.width, obstacle.height) then
            return true
        end
    end

    return false
end

function Game:rectIntersect(x1, y1, w1, h1, x2, y2, w2, h2)
    return x1 < x2 + w2 and
        x1 + w1 > x2 and
        y1 < y2 + h2 and
        y1 + h1 > y2
end

function Game:playerJump()
    if not self.player.isJumping and not self.player.isCrouching then
        self.player.isJumping = true
        self.player.jumpVelocity = self.player.jumpPower
        self:createParticles(self.player.x + self.player.width / 2, self.player.y + self.player.height,
            { 0.7, 0.7, 0.9 }, 8)
    end
end

function Game:playerCrouch(crouching)
    if not self.player.isJumping then
        self.player.isCrouching = crouching
        if crouching then
            self.player.height = self.player.crouchHeight
            self.player.y = self.player.groundY - self.player.height
        else
            self.player.height = self.player.normalHeight
            self.player.y = self.player.groundY - self.player.height
        end
    end
end

function Game:updatePlayer(dt)
    local player = self.player

    -- Update running animation
    player.animationTime = player.animationTime + dt
    player.runCycle = (player.runCycle + dt * 10) % (2 * math.pi)

    -- Handle jumping physics
    if player.isJumping then
        player.jumpVelocity = player.jumpVelocity + player.gravity * dt
        player.y = player.y + player.jumpVelocity * dt

        -- Check if landed
        if player.y >= player.groundY - player.height then
            player.y = player.groundY - player.height
            player.isJumping = false
            player.jumpVelocity = 0
            self:createParticles(player.x + player.width / 2, player.y + player.height,
                { 0.9, 0.9, 0.9 }, 5)
        end
    end
end

function Game:updateObstacles(dt)
    local speed = self.gameSpeed * dt

    -- Update obstacles
    for i = #self.obstacles, 1, -1 do
        local obstacle = self.obstacles[i]
        obstacle.x = obstacle.x - speed

        -- Update moving obstacles
        if obstacle.isMoving then
            obstacle.moveTime = obstacle.moveTime + dt * obstacle.moveSpeed
            obstacle.y = obstacle.originalY + math_sin(obstacle.moveTime) * obstacle.moveRange
        end

        -- Check if passed
        if not obstacle.passed and obstacle.x + obstacle.width < self.player.x then
            obstacle.passed = true
            self.score = self.score + 10
            if self.activePowerUps.double_points then
                self.score = self.score + 10 -- Bonus points
            end
        end

        -- Remove off-screen obstacles
        if obstacle.x + obstacle.width < 0 then
            table_remove(self.obstacles, i)
        end
    end

    -- Spawn new obstacles
    self.obstacleSpawnTimer = self.obstacleSpawnTimer - dt
    if self.obstacleSpawnTimer <= 0 then
        self:spawnObstacle()
        self.obstacleSpawnTimer = math_max(self.obstacleSpawnRate, self.minObstacleSpawnRate)
        self.obstacleSpawnRate = self.obstacleSpawnRate - self.spawnRateDecrease
    end
end

function Game:updatePowerUpsList(dt)
    local speed = self.gameSpeed * dt

    -- Update power-ups
    for i = #self.powerUps, 1, -1 do
        local powerUp = self.powerUps[i]
        powerUp.x = powerUp.x - speed
        powerUp.bounce = powerUp.bounce + dt * 5

        -- Check collection
        if not powerUp.collected and self:rectIntersect(
                self.player.x, self.player.y, self.player.width, self.player.height,
                powerUp.x, powerUp.y, powerUp.width, powerUp.height) then
            powerUp.collected = true
            self:activatePowerUp(powerUp)
            self.score = self.score + 50
        end

        -- Remove off-screen or collected power-ups
        if powerUp.x + powerUp.width < 0 or powerUp.collected then
            table_remove(self.powerUps, i)
        end
    end

    -- Spawn new power-ups
    self.powerUpSpawnTimer = self.powerUpSpawnTimer - dt
    if self.powerUpSpawnTimer <= 0 then
        if love_random() < 0.3 then -- 30% chance to spawn
            self:spawnPowerUp()
        end
        self.powerUpSpawnTimer = self.powerUpSpawnRate
    end
end

function Game:updateGround(dt)
    local speed = self.gameSpeed * dt

    -- Update ground segments
    for _, segment in ipairs(self.groundSegments) do
        segment.x = segment.x - speed

        -- Wrap ground segments
        if segment.x + segment.width < 0 then
            segment.x = segment.x + #self.groundSegments * segment.width
        end
    end
end

function Game:createParticles(x, y, color, count)
    for _ = 1, count do
        table_insert(self.particles, {
            x = x,
            y = y,
            dx = (love_random() - 0.5) * 200,
            dy = (love_random() - 0.5) * 200 - 50,
            life = love_random(0.5, 1.5),
            color = color or { 1, 1, 1 },
            size = love_random(2, 6),
            rotation = love_random() * 6.28
        })
    end
end

function Game:updateParticles(dt)
    for i = #self.particles, 1, -1 do
        local particle = self.particles[i]
        particle.life = particle.life - dt
        particle.x = particle.x + particle.dx * dt
        particle.y = particle.y + particle.dy * dt
        particle.dy = particle.dy + 400 * dt -- gravity

        if particle.life <= 0 then
            table_remove(self.particles, i)
        end
    end
end

function Game:drawPlayer()
    local player = self.player
    local centerX = player.x + player.width / 2
    local centerY = player.y + player.height / 2

    lg.push()
    lg.translate(centerX, centerY)

    -- Body color based on power-ups
    local bodyColor = { 0.9, 0.9, 0.9 }
    if self.activePowerUps.invincible then
        local pulse = (math_sin(self.time * 10) + 1) * 0.5
        bodyColor = { 1, 1, pulse }
    elseif self.activePowerUps.speed then
        bodyColor = { 0.2, 0.9, 0.2 }
    elseif self.activePowerUps.double_points then
        bodyColor = { 0.2, 0.7, 1 }
    end

    lg.setColor(bodyColor)
    lg.setLineWidth(3)

    if player.isCrouching then
        -- Crouching pose
        lg.circle("line", 0, -5, 8) -- Head
        lg.line(0, 3, 0, 10)        -- Body
        lg.line(0, 10, -10, 15)     -- Left leg
        lg.line(0, 10, 10, 15)      -- Right leg
        lg.line(0, 5, -8, 8)        -- Left arm
        lg.line(0, 5, 8, 8)         -- Right arm
    elseif player.isJumping then
        -- Jumping pose
        lg.circle("line", 0, -10, 8) -- Head
        lg.line(0, -2, 0, 8)         -- Body
        lg.line(0, 8, -12, 15)       -- Left leg
        lg.line(0, 8, 12, 15)        -- Right leg
        lg.line(0, 0, -15, -5)       -- Left arm
        lg.line(0, 0, 15, -5)        -- Right arm
    else
        -- Running pose
        local legOffset = math_sin(player.runCycle) * 8
        local armOffset = math_sin(player.runCycle + math.pi) * 6

        lg.circle("line", 0, -10, 8)       -- Head
        lg.line(0, -2, 0, 10)              -- Body
        lg.line(0, 10, -8, 15 + legOffset) -- Left leg
        lg.line(0, 10, 8, 15 - legOffset)  -- Right leg
        lg.line(0, 2, -12, 2 + armOffset)  -- Left arm
        lg.line(0, 2, 12, 2 - armOffset)   -- Right arm
    end

    lg.setLineWidth(1)
    lg.pop()
end

function Game:drawObstacles()
    for _, obstacle in ipairs(self.obstacles) do
        lg.setColor(obstacle.color)

        if obstacle.type == "spikes" then
            -- Draw spikes
            for i = 1, 6 do
                local spikeX = obstacle.x + (i - 1) * 10
                lg.polygon("fill",
                    spikeX, obstacle.y + obstacle.height,
                    spikeX + 5, obstacle.y,
                    spikeX + 10, obstacle.y + obstacle.height
                )
            end
        elseif obstacle.isGap then
            -- Draw gap as a dark rectangle
            lg.setColor(0.2, 0.2, 0.3)
            lg.rectangle("fill", obstacle.x, obstacle.y, obstacle.width, obstacle.height)
            lg.setColor(0.4, 0.4, 0.6)
            lg.rectangle("line", obstacle.x, obstacle.y, obstacle.width, obstacle.height)
        else
            -- Regular obstacle
            lg.rectangle("fill", obstacle.x, obstacle.y, obstacle.width, obstacle.height)
            lg.setColor(1, 1, 1, 0.3)
            lg.rectangle("line", obstacle.x, obstacle.y, obstacle.width, obstacle.height)
        end
    end
end

function Game:drawPowerUps()
    for _, powerUp in ipairs(self.powerUps) do
        local bounce = math_sin(powerUp.bounce) * 5
        local centerX = powerUp.x + powerUp.width / 2
        local centerY = powerUp.y + powerUp.height / 2 + bounce

        lg.push()
        lg.translate(centerX, centerY)

        -- Pulsing glow effect
        local pulse = (math_sin(self.time * 5) + 1) * 0.3 + 0.7
        lg.setColor(powerUp.color[1], powerUp.color[2], powerUp.color[3], 0.3)
        lg.circle("fill", 0, 0, powerUp.width * 0.8 * pulse)

        -- Main power-up
        lg.setColor(powerUp.color)

        if powerUp.type == "speed_boost" then
            lg.rectangle("fill", -6, -6, 12, 12)
            lg.setColor(1, 1, 1)
            lg.print("⚡", -4, -8)
        elseif powerUp.type == "invincibility" then
            lg.circle("fill", 0, 0, 8)
            lg.setColor(1, 1, 1)
            lg.print("🛡", -4, -8)
        elseif powerUp.type == "magnet" then
            lg.rectangle("fill", -8, -4, 16, 8)
            lg.setColor(1, 1, 1)
            lg.print("🧲", -4, -8)
        elseif powerUp.type == "double_points" then
            lg.polygon("fill", 0, -8, -8, 8, 8, 8)
            lg.setColor(1, 1, 1)
            lg.print("2×", -4, -4)
        elseif powerUp.type == "slow_motion" then
            lg.circle("fill", 0, 0, 10)
            lg.setColor(1, 1, 1)
            lg.print("🐌", -4, -8)
        end

        lg.pop()
    end
end

function Game:drawGround()
    for _, segment in ipairs(self.groundSegments) do
        -- Ground fill
        lg.setColor(0.3, 0.6, 0.3)
        lg.rectangle("fill", segment.x, segment.y, segment.width, segment.height)

        -- Ground pattern
        lg.setColor(0.4, 0.7, 0.4)
        for i = 1, 5 do
            local patternX = segment.x + (i - 1) * 20
            lg.rectangle("fill", patternX, segment.y, 10, 5)
        end
    end
end

function Game:drawUI()
    -- Score display
    lg.setColor(1, 1, 1)
    lg.setFont(lg.newFont(24))
    lg.print("Score: " .. math_floor(self.score), 20, 20)
    lg.print("High Score: " .. math_floor(self.highScore), 20, 50)

    -- Distance
    lg.print("Distance: " .. math_floor(self.distance) .. "m", 20, 80)

    -- Speed indicator
    local speedPercent = (self.gameSpeed - self.baseSpeed) / (self.maxSpeed - self.baseSpeed)
    lg.setColor(0.8, 0.8, 1)
    lg.rectangle("fill", 20, 110, 150 * speedPercent, 15)
    lg.setColor(1, 1, 1)
    lg.rectangle("line", 20, 110, 150, 15)
    lg.print("Speed", 25, 112)

    -- Active power-ups
    local yPos = 140
    for powerType, effect in pairs(self.activePowerUps) do
        local timeLeft = effect.endTime - self.time
        local color = { 1, 1, 1 }
        local text = ""

        if powerType == "speed" then
            color = { 0.2, 0.8, 0.2 }
            text = "Speed Boost: " .. math_floor(timeLeft) .. "s"
        elseif powerType == "invincible" then
            color = { 1, 1, 0.2 }
            text = "Invincible: " .. math_floor(timeLeft) .. "s"
        elseif powerType == "magnet" then
            color = { 0.8, 0.3, 0.8 }
            text = "Magnet: " .. math_floor(timeLeft) .. "s"
        elseif powerType == "double_points" then
            color = { 0.2, 0.7, 1 }
            text = "2× Points: " .. math_floor(timeLeft) .. "s"
        elseif powerType == "slow_mo" then
            color = { 0.5, 0.5, 1 }
            text = "Slow Mo: " .. math_floor(timeLeft) .. "s"
        end

        lg.setColor(color)
        lg.print(text, 20, yPos)
        yPos = yPos + 25
    end

    -- Controls hint
    lg.setColor(1, 1, 1, 0.6)
    lg.setFont(lg.newFont(14))
    lg.print("SPACE/UP: Jump | DOWN: Crouch | ESC: Menu", 20, self.screenHeight - 30)
end

function Game:drawParticles()
    for _, particle in ipairs(self.particles) do
        local alpha = math_min(1, particle.life * 2)
        lg.setColor(particle.color[1], particle.color[2], particle.color[3], alpha)
        lg.push()
        lg.translate(particle.x, particle.y)
        lg.rotate(particle.rotation)
        lg.rectangle("fill", -particle.size / 2, -particle.size / 2, particle.size, particle.size)
        lg.pop()
    end
end

function Game:drawGameOver()
    -- Dark overlay
    lg.setColor(0, 0, 0, 0.7)
    lg.rectangle("fill", 0, 0, self.screenWidth, self.screenHeight)

    -- Game over text
    lg.setColor(0.9, 0.2, 0.2)
    lg.setFont(lg.newFont(48))
    lg.printf("GAME OVER", 0, self.screenHeight / 2 - 100, self.screenWidth, "center")

    -- Score summary
    lg.setColor(1, 1, 1)
    lg.setFont(lg.newFont(32))
    lg.printf("Final Score: " .. math_floor(self.score), 0, self.screenHeight / 2 - 20, self.screenWidth, "center")
    lg.printf("Distance: " .. math_floor(self.distance) .. "m", 0, self.screenHeight / 2 + 20, self.screenWidth, "center")

    if self.score > self.highScore then
        lg.setColor(1, 0.8, 0.2)
        lg.printf("NEW HIGH SCORE!", 0, self.screenHeight / 2 + 60, self.screenWidth, "center")
    end

    -- Instructions
    lg.setColor(1, 1, 1, 0.8)
    lg.setFont(lg.newFont(20))
    lg.printf("Click to continue", 0, self.screenHeight / 2 + 120, self.screenWidth, "center")
end

function Game:update(dt)
    self.time = self.time + dt

    if not self.gameOver then
        -- Update distance (based on speed)
        self.distance = self.distance + self.gameSpeed * dt * 0.01

        -- Update score based on distance
        self.score = self.score + self.gameSpeed * dt * 0.1

        self:updatePlayer(dt)
        self:updateObstacles(dt)
        self:updatePowerUpsList(dt)
        self:updatePowerUps(dt)
        self:updateGround(dt)
        self:updateParticles(dt)

        -- Check for collisions
        if self:checkCollisions() then
            self.gameOver = true
            if self.score > self.highScore then
                self.highScore = self.score
            end
        end
    end
end

function Game:draw()
    self:drawGround()
    self:drawObstacles()
    self:drawPowerUps()
    self:drawPlayer()
    self:drawParticles()
    self:drawUI()

    if self.gameOver then
        self:drawGameOver()
    end
end

function Game:startNewGame()
    self.gameOver = false
    self.score = 0
    self.distance = 0
    self.gameSpeed = self.baseSpeed
    self.obstacleSpawnRate = 1.5
    self.obstacleSpawnTimer = 1.0 -- Start with a brief delay
    self.powerUpSpawnTimer = self.powerUpSpawnRate

    -- Reset player
    self.player.y = self.player.groundY - self.player.height
    self.player.isJumping = false
    self.player.isCrouching = false
    self.player.jumpVelocity = 0
    self.player.height = self.player.normalHeight

    -- Clear game objects
    self.obstacles = {}
    self.powerUps = {}
    self.particles = {}
    self.activePowerUps = {}
end

function Game:setScreenSize(width, height)
    self.screenWidth = width
    self.screenHeight = height
    self.player.groundY = height - 100
    self.player.y = self.player.groundY - self.player.height
    self:initGround()
end

function Game:isGameOver() return self.gameOver end

function Game:handleClick(x, y)
    -- Game over screen handles clicks in main.lua
    if self.gameOver then return end
end

return Game
