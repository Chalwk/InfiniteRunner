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

local function rectIntersect(x1, y1, w1, h1, x2, y2, w2, h2)
    return x1 < x2 + w2 and
        x1 + w1 > x2 and
        y1 < y2 + h2 and
        y1 + h1 > y2
end

local function isOverGap(self)
    local player = self.player
    for _, obstacle in ipairs(self.obstacles) do
        if obstacle.isGap then
            -- Check if player's horizontal center is within the gap area
            local px = player.x + player.width / 2
            if px >= obstacle.x and px <= obstacle.x + obstacle.width then
                return true
            end
        end
    end
    return false
end

local function initGround(self)
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

local function spawnObstacle(self)
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

local function createParticles(self, x, y, color, count)
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

local function updatePowerUps(self, dt)
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

local function spawnPowerUp(self)
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

local function activatePowerUp(self, powerUp)
    local effect = powerUp.effect(self.player)
    effect.endTime = self.time + powerUp.duration
    self.activePowerUps[effect.type] = effect

    -- Visual feedback
    createParticles(self, powerUp.x + powerUp.width / 2, powerUp.y + powerUp.height / 2, powerUp.color, 15)
end

local function updatePowerUpsList(self, dt)
    local speed = self.gameSpeed * dt

    -- Update power-ups
    for i = #self.powerUps, 1, -1 do
        local powerUp = self.powerUps[i]
        powerUp.x = powerUp.x - speed
        powerUp.bounce = powerUp.bounce + dt * 5

        -- Check collection
        if not powerUp.collected and rectIntersect(
                self.player.x, self.player.y, self.player.width, self.player.height,
                powerUp.x, powerUp.y, powerUp.width, powerUp.height) then
            powerUp.collected = true
            activatePowerUp(self, powerUp)
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
        if love_random() < 0.3 then spawnPowerUp(self) end
        self.powerUpSpawnTimer = self.powerUpSpawnRate
    end
end

local function updateObstacles(self, dt)
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

        -- Handle bouncing ball obstacle
        if obstacle.isBouncing then
            obstacle.bounceTime = (obstacle.bounceTime or 0) + dt * obstacle.bounceSpeed
            local bounceOffset = math_sin(obstacle.bounceTime) * obstacle.bounceHeight
            obstacle.y = obstacle.originalY + bounceOffset
        end

        -- Handle disappearing platform
        if obstacle.isDisappearing then
            obstacle.timer = obstacle.timer + dt
            if obstacle.active then
                if obstacle.timer >= obstacle.disappearTime then
                    obstacle.active = false
                    obstacle.timer = 0
                end
            else
                if obstacle.timer >= obstacle.reappearTime then
                    obstacle.active = true
                    obstacle.timer = 0
                end
            end
        end

        -- Handle laser beam
        if obstacle.isLaser then
            obstacle.timer = (obstacle.timer or 0) + dt
            local cycleTime = obstacle.activeTime + obstacle.inactiveTime

            if obstacle.timer > cycleTime then
                obstacle.timer = obstacle.timer - cycleTime
            end

            local wasActive = obstacle.isActive
            obstacle.isActive = obstacle.timer > obstacle.inactiveTime

            -- Create warning particles when about to activate
            if not wasActive and obstacle.isActive and obstacle.timer - obstacle.inactiveTime < 0.1 then
                createParticles(self, obstacle.x, obstacle.y + obstacle.height / 2,
                    obstacle.warningColor, 10)
            end
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
        spawnObstacle(self)
        self.obstacleSpawnTimer = math_max(self.obstacleSpawnRate, self.minObstacleSpawnRate)
        self.obstacleSpawnRate = self.obstacleSpawnRate - self.spawnRateDecrease
    end
end

local function teleportPlayer(self, teleporter)
    -- Find a target teleporter (could be another one on screen or create one ahead)
    local targetX = teleporter.x + 400 -- Teleport 400 pixels forward
    local targetY = self.player.groundY - self.player.height

    -- Create teleport effects at current position
    createParticles(self, self.player.x + self.player.width / 2,
        self.player.y + self.player.height / 2,
        { 0.8, 0.6, 1 }, 20)

    -- Actually move the player
    self.player.x = targetX
    self.player.y = targetY

    -- Create teleport effects at new position
    createParticles(self, self.player.x + self.player.width / 2,
        self.player.y + self.player.height / 2,
        { 0.8, 0.6, 1 }, 20)

    -- Add a brief invincibility period after teleporting
    self.activePowerUps.teleport_invincible = {
        endTime = self.time + 1.5, -- 1.5 seconds of invincibility
        type = "teleport_invincible"
    }

    -- Add score bonus for using teleporter
    self.score = self.score + 25
end

local function checkCollisions(self)
    if self.activePowerUps.invincible then return false end

    local player = self.player
    for _, obstacle in ipairs(self.obstacles) do
        -- Skip collision for inactive disappearing platforms
        if obstacle.isDisappearing and not obstacle.active then goto continue end

        -- Skip collision for inactive lasers
        if obstacle.isLaser and not obstacle.isActive then goto continue end

        -- Handle teleport gate collision (special case - doesn't kill player)
        if obstacle.type == "teleport_gate" then
            if rectIntersect(player.x, player.y, player.width, player.height,
                    obstacle.x, obstacle.y, obstacle.width, obstacle.height) then
                teleportPlayer(self, obstacle)
                goto continue -- Don't treat this as a deadly collision
            end
        end

        if rectIntersect(player.x, player.y, player.width, player.height,
                obstacle.x, obstacle.y, obstacle.width, obstacle.height) then
            return true
        end

        ::continue::
    end

    return false
end

local function updatePlayer(self, dt)
    local player = self.player

    -- Handle horizontal movement
    if player.moveLeft then
        player.x = math_max(player.minX, player.x - player.moveSpeed * dt)
    elseif player.moveRight then
        player.x = math_min(player.maxX, player.x + player.moveSpeed * dt)
    end

    -- Update running animation
    player.animationTime = player.animationTime + dt
    player.runCycle = (player.runCycle + dt * 10) % (2 * math.pi)

    -- If player is over a gap and not already jumping, start falling
    if not player.isJumping and isOverGap(self) then
        player.isJumping = true
        player.jumpVelocity = 0
    end

    -- Handle jumping or falling physics
    if player.isJumping then
        player.jumpVelocity = player.jumpVelocity + player.gravity * dt
        player.y = player.y + player.jumpVelocity * dt

        -- Check if landed or still falling through a gap
        if player.y >= player.groundY - player.height then
            if not isOverGap(self) then
                -- Land on solid ground
                player.y = player.groundY - player.height
                player.isJumping = false
                player.jumpVelocity = 0
                createParticles(self, player.x + player.width / 2, player.y + player.height,
                    { 0.9, 0.9, 0.9 }, 5)
            else
                -- Still over a gap: keep falling
                player.isJumping = true
            end
        end
    end

    -- Check if player fell off the screen (death condition)
    if player.y > self.screenHeight then
        self.gameOver = true
        if self.score > self.highScore then
            self.highScore = self.score
        end
    end
end

local function updateGround(self, dt)
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

local function updateParticles(self, dt)
    for i = #self.particles, 1, -1 do
        local particle = self.particles[i]
        particle.life = particle.life - dt
        particle.x = particle.x + particle.dx * dt
        particle.y = particle.y + particle.dy * dt
        particle.dy = particle.dy + 400 * dt -- gravity

        if particle.life <= 0 then table_remove(self.particles, i) end
    end
end

local function drawPlayer(self)
    local player = self.player
    local centerX = player.x + player.width / 2
    local centerY = player.y + player.height / 2 + 5

    lg.push()
    lg.translate(centerX, centerY)

    -- Body color based on power-ups
    local bodyColor = { 0.9, 0.9, 0.9 }
    if self.activePowerUps.invincible or self.activePowerUps.teleport_invincible then
        local pulse = (math_sin(self.time * 10) + 1) * 0.5
        bodyColor = { 1, 1, pulse }
        if self.activePowerUps.teleport_invincible then
            bodyColor = { 0.8, 0.6, pulse }
        end
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

local function drawParticles(self)
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

local function drawUI(self)
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
    lg.rectangle("fill", 20, 140, 150 * speedPercent, 15)
    lg.setColor(1, 1, 1)
    lg.rectangle("line", 20, 140, 150, 15)
    lg.print("Speed:", 20, 108)

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
        elseif powerType == "teleport_invincible" then
            color = { 0.8, 0.6, 1 }
            text = "Teleport Shield: " .. math_floor(timeLeft) .. "s"
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

local function drawObstacles(self)
    for _, obstacle in ipairs(self.obstacles) do
        -- Skip drawing inactive disappearing platforms
        if obstacle.isDisappearing and not obstacle.active then
            goto continue
        end

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
        elseif obstacle.type == "bouncing_ball" then
            -- Draw bouncing ball
            lg.setColor(obstacle.color)
            lg.circle("fill", obstacle.x + obstacle.width / 2,
                obstacle.y + obstacle.height / 2, obstacle.width / 2)
            lg.setColor(1, 1, 1, 0.3)
            lg.circle("line", obstacle.x + obstacle.width / 2,
                obstacle.y + obstacle.height / 2, obstacle.width / 2)

            -- Add a highlight to make it look more like a ball
            lg.setColor(1, 1, 1, 0.4)
            lg.circle("fill", obstacle.x + obstacle.width / 2 - obstacle.width / 6,
                obstacle.y + obstacle.height / 2 - obstacle.height / 6, obstacle.width / 6)
        elseif obstacle.type == "disappearing_platform" then
            -- Draw disappearing platform with transparency based on active state
            local alpha = obstacle.active and 1 or 0.3
            lg.setColor(obstacle.color[1], obstacle.color[2], obstacle.color[3], alpha)
            lg.rectangle("fill", obstacle.x, obstacle.y, obstacle.width, obstacle.height)

            -- Pattern on the platform
            lg.setColor(0.2, 0.5, 0.6, alpha * 0.8)
            for i = 1, 4 do
                local patternX = obstacle.x + (i - 1) * 20
                lg.rectangle("fill", patternX, obstacle.y, 10, 5)
            end

            -- Blinking effect when about to disappear
            if obstacle.active and obstacle.timer > obstacle.disappearTime * 0.7 then
                local blink = math_sin(self.time * 10) > 0
                if blink then
                    lg.setColor(1, 1, 1, 0.8)
                    lg.rectangle("line", obstacle.x, obstacle.y, obstacle.width, obstacle.height)
                end
            end
        elseif obstacle.type == "laser_beam" then
            if obstacle.isActive then
                -- Active laser beam with glow effect
                lg.setColor(obstacle.color)
                lg.rectangle("fill", obstacle.x, obstacle.y, obstacle.width, obstacle.height)

                -- Laser glow
                lg.setColor(1, 0.5, 0.5, 0.6)
                lg.rectangle("fill", obstacle.x - 5, obstacle.y - 5, obstacle.width + 10, obstacle.height + 10)

                -- Core of the laser
                lg.setColor(1, 1, 1, 0.8)
                lg.rectangle("fill", obstacle.x + 2, obstacle.y, obstacle.width - 4, obstacle.height)
            else
                -- Inactive/warning state with pulsing effect
                local warningProgress = (obstacle.timer / obstacle.inactiveTime) * math.pi * 2
                local pulse = (math_sin(warningProgress * 5) + 1) * 0.5
                lg.setColor(obstacle.warningColor[1], obstacle.warningColor[2],
                    obstacle.warningColor[3], pulse)
                lg.rectangle("fill", obstacle.x, obstacle.y, obstacle.width, obstacle.height)

                -- Warning stripes
                lg.setColor(1, 1, 1, pulse * 0.8)
                for i = 1, 3 do
                    local stripeY = obstacle.y + (i - 1) * (obstacle.height / 3)
                    lg.rectangle("fill", obstacle.x, stripeY, obstacle.width, obstacle.height / 8)
                end
            end
        elseif obstacle.type == "moving_spikes_wall" then
            -- Draw the main wall
            lg.setColor(obstacle.color)
            lg.rectangle("fill", obstacle.x, obstacle.y, obstacle.width, obstacle.height)

            -- Draw spikes on the left side of the wall (previously on the right)
            lg.setColor(0.3, 0.1, 0.1)
            for i = 1, 6 do
                local spikeY = obstacle.y + (i - 1) * 35
                lg.polygon("fill",
                    obstacle.x, spikeY,
                    obstacle.x - 15, spikeY + 15,
                    obstacle.x, spikeY + 30
                )
            end

            -- Add some texture to the wall
            lg.setColor(0.5, 0.2, 0.2, 0.3)
            for i = 1, 3 do
                for j = 1, 4 do
                    local brickX = obstacle.x + (j - 1) * 8
                    local brickY = obstacle.y + (i - 1) * 15
                    lg.rectangle("line", brickX, brickY, 6, 12)
                end
            end
        elseif obstacle.type == "teleport_gate" then
            -- Draw teleporter with animated portal effect
            local pulse = (math_sin(self.time * 8) + 1) * 0.3 + 0.4
            lg.setColor(obstacle.color[1], obstacle.color[2], obstacle.color[3], pulse)
            lg.rectangle("fill", obstacle.x, obstacle.y, obstacle.width, obstacle.height)

            -- Outer frame
            lg.setColor(1, 1, 1, 0.8)
            lg.setLineWidth(3)
            lg.rectangle("line", obstacle.x, obstacle.y, obstacle.width, obstacle.height)
            lg.setLineWidth(1)

            -- Animated inner portal with swirling effect
            local innerPulse = (math_sin(self.time * 6) + 1) * 0.5
            local swirl = self.time * 10

            lg.push()
            lg.translate(obstacle.x + obstacle.width / 2, obstacle.y + obstacle.height / 2)
            lg.rotate(swirl)

            lg.setColor(0.8, 0.6, 1, innerPulse)
            for i = 1, 3 do
                local size = (obstacle.width - 20 - (i - 1) * 8) / 2
                lg.circle("line", 0, 0, size)
            end

            lg.setColor(0.9, 0.8, 1, innerPulse * 0.7)
            lg.rectangle("fill", -15, -15, 30, 30)

            lg.pop()

            -- Sparkle particles around the teleporter
            local sparkleTime = self.time * 12
            for i = 1, 4 do
                local angle = sparkleTime + (i - 1) * math.pi / 2
                local sparkleX = obstacle.x + obstacle.width / 2 + math.cos(angle) * 25
                local sparkleY = obstacle.y + obstacle.height / 2 + math.sin(angle) * 25
                local sparkleSize = (math_sin(angle * 2) + 1) * 1.5 + 1

                lg.setColor(1, 1, 1, 0.8)
                lg.rectangle("fill", sparkleX - sparkleSize / 2, sparkleY - sparkleSize / 2,
                    sparkleSize, sparkleSize)
            end
        else
            -- Default drawing for regular obstacles
            lg.rectangle("fill", obstacle.x, obstacle.y, obstacle.width, obstacle.height)
            lg.setColor(1, 1, 1, 0.3)
            lg.rectangle("line", obstacle.x, obstacle.y, obstacle.width, obstacle.height)

            -- Add some visual interest to regular obstacles
            lg.setColor(0.8, 0.8, 0.8, 0.2)
            lg.rectangle("fill", obstacle.x + 5, obstacle.y + 5,
                obstacle.width - 10, obstacle.height - 10)
        end

        ::continue::
    end
end

local function drawPowerUps(self)
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

local function drawGround(self)
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

local function updateScreenSize(self)
    local newWidth = lg.getWidth()
    local newHeight = lg.getHeight()

    -- Only update if dimensions actually changed
    if newWidth ~= self.screenWidth or newHeight ~= self.screenHeight then
        self.screenWidth = newWidth
        self.screenHeight = newHeight

        -- Update player boundaries and ground position
        self.player.maxX = self.screenWidth - 50
        self.player.minX = 50
        self.player.groundY = self.screenHeight - 100
        self.player.y = self.player.groundY - self.player.height

        -- Reinitialize ground segments for new width
        initGround(self)
    end
end

function Game.new(screenWidth, screenHeight)
    local instance = setmetatable({}, Game)

    instance.screenWidth = screenWidth
    instance.screenHeight = screenHeight
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
        groundY = instance.screenHeight - 100,
        gravity = 1600,
        isJumping = false,
        isCrouching = false,
        normalHeight = 60,
        crouchHeight = 30,
        animationTime = 0,
        runCycle = 0,
        maxX = screenWidth - 100,
        minX = 50,
        -- Movement properties
        jumpVelocity = 0,
        jumpPower = -600,
        moveSpeed = 300,
        moveLeft = false,
        moveRight = false
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
            height = 120,
            yOffset = -35,
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
        },
        {
            name = "bouncing_ball",
            width = 40,
            height = 40,
            yOffset = 0,
            isMoving = true,
            isBouncing = true,
            moveRange = 150,
            moveSpeed = 3,
            bounceHeight = 100,
            bounceSpeed = 5,
            color = { 0.9, 0.4, 0.1 },
            requireJump = true
        },
        {
            name = "disappearing_platform",
            width = 80,
            height = 20,
            yOffset = -15,
            isDisappearing = true,
            disappearTime = 1.0,
            reappearTime = 1.5,
            timer = 0,
            active = true,
            color = { 0.3, 0.7, 0.8 },
            requireTiming = true
        },
        {
            name = "laser_beam",
            width = 10,
            height = 200,
            yOffset = -180,
            isLaser = true,
            isActive = true,
            activeTime = 2.0,
            inactiveTime = 1.5,
            timer = 0,
            warningTime = 0.5,
            color = { 1, 0.2, 0.2 },
            warningColor = { 1, 0.5, 0.5 },
            requireCrouch = true
        },
        {
            name = "moving_spikes_wall",
            width = 30,
            height = 200,
            yOffset = -180,
            isMoving = true,
            moveRange = 300,
            moveSpeed = 2,
            hasSpikes = true,
            color = { 0.8, 0.2, 0.3 },
            requireJumpOrCrouch = true
        },
        {
            name = "teleport_gate",
            width = 60,
            height = 120,
            yOffset = -60,
            isTeleporter = true,
            pairId = 0, -- Will be set when spawned
            color = { 0.6, 0.2, 0.8 },
            teleportOffset = 200
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
    initGround(instance)

    return instance
end

function Game:playerJump()
    if not self.player.isJumping and not self.player.isCrouching then
        self.player.isJumping = true
        self.player.jumpVelocity = self.player.jumpPower
        createParticles(self, self.player.x + self.player.width / 2, self.player.y + self.player.height,
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

function Game:update(dt)
    updateScreenSize(self)
    self.time = self.time + dt

    if not self:isGameOver() then
        -- Update distance (based on speed)
        self.distance = self.distance + self.gameSpeed * dt * 0.01

        -- Update score based on distance
        self.score = self.score + self.gameSpeed * dt * 0.1

        updatePlayer(self, dt)
        updateObstacles(self, dt)
        updatePowerUpsList(self, dt)
        updatePowerUps(self, dt)
        updateGround(self, dt)
        updateParticles(self, dt)

        -- Check for collisions
        if checkCollisions(self) then
            self.gameOver = true
            if self.score > self.highScore then
                self.highScore = self.score
            end
        end
    end
end

function Game:draw()
    drawGround(self)
    drawObstacles(self)
    drawPowerUps(self)
    drawPlayer(self)
    drawParticles(self)
    drawUI(self)
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
    self.player.x = self.screenWidth * 0.1
    self.player.y = self.player.groundY - self.player.height
    self.player.isJumping = false
    self.player.isCrouching = false
    self.player.jumpVelocity = 0
    self.player.height = self.player.normalHeight

    self.player.moveLeft = false
    self.player.moveRight = false

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
    self.player.maxX = width - 50
    self.player.minX = 50
    initGround(self)
end

function Game:playerMoveLeft(moving)
    self.player.moveLeft = moving
end

function Game:playerMoveRight(moving)
    self.player.moveRight = moving
end

function Game:playerMoveUp()
    self:playerJump()
end

function Game:playerMoveDown(moving)
    self:playerCrouch(moving)
end

function Game:isGameOver() return self.gameOver end

return Game
