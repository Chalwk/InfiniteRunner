-- Infinite Runner
-- License: MIT
-- Copyright (c) 2025 Jericho Crosby (Chalwk)

local Player = {}
Player.__index = Player

function Player.new()
    local instance = setmetatable({}, Player)

    instance.screenWidth = 800
    instance.screenHeight = 600

    -- Player properties
    instance.width = 30
    instance.normalHeight = 60
    instance.crouchHeight = 30
    instance.height = instance.normalHeight

    -- Physics
    instance.velocityY = 0
    instance.jumpForce = -500
    instance.gravity = 1200
    instance.isOnGround = true

    -- Movement
    instance.moveSpeed = 300
    instance.lanes = { 150, 300, 450 }
    instance.currentLane = 2
    instance.targetX = instance.lanes[instance.currentLane]

    -- Ground position
    instance.groundY = instance.screenHeight - 150
    instance.x = instance.targetX
    instance.y = instance.groundY - instance.height -- ensure on ground

    -- States / animation
    instance.state = "running"
    instance.animationTime = 0
    instance.legAngle = 0
    instance.armAngle = 0

    return instance
end

function Player:setScreenSize(width, height)
    self.screenWidth = width
    self.screenHeight = height
    self.groundY = height - 80 -- Ground is 150px from bottom

    -- Adjust lanes based on screen width
    self.lanes = {
        width * 0.25,
        width * 0.5,
        width * 0.75
    }
    self.targetX = self.lanes[self.currentLane]
    self.x = self.targetX

    -- Set player position ON the ground
    self.y = self.groundY - self.height
end

function Player:update(dt, gameSpeed)
    -- Handle horizontal movement between lanes
    local moveSpeed = self.moveSpeed * dt
    if math.abs(self.x - self.targetX) > moveSpeed then
        if self.x < self.targetX then
            self.x = self.x + moveSpeed
        else
            self.x = self.x - moveSpeed
        end
    else
        self.x = self.targetX
    end

    -- Handle vertical movement (jumping)
    if not self.isOnGround then
        self.velocityY = self.velocityY + self.gravity * dt
        self.y = self.y + self.velocityY * dt

        -- Check if player has landed on ground
        if self.y >= self.groundY - self.height then
            self.y = self.groundY - self.height
            self.velocityY = 0
            self.isOnGround = true
            if self.state == "jumping" then
                self.state = "running"
            end
        end
    else
        -- Ensure player stays on ground when not jumping
        self.y = self.groundY - self.height
    end

    -- Update animations
    self.animationTime = self.animationTime + dt
    if self.state == "running" then
        self.legAngle = math.sin(self.animationTime * 10) * 0.5
        self.armAngle = math.sin(self.animationTime * 10 + math.pi) * 0.3
    elseif self.state == "crouching" then
        self.legAngle = 0
        self.armAngle = 0
    elseif self.state == "sliding" then
        self.legAngle = 0
        self.armAngle = -0.7
    end

    -- Auto-stand from crouch/slide after time
    if (self.state == "crouching" or self.state == "sliding") and self.animationTime > 1.0 then
        self.state = "running"
        self.height = self.normalHeight
        self.y = self.groundY - self.height -- Maintain ground position
    end
end

function Player:draw()
    love.graphics.push()
    love.graphics.translate(self.x, self.y)

    -- Draw stick figure based on state
    if self.state == "running" then
        self:drawRunningStickFigure()
    elseif self.state == "jumping" then
        self:drawJumpingStickFigure()
    elseif self.state == "crouching" then
        self:drawCrouchingStickFigure()
    elseif self.state == "sliding" then
        self:drawSlidingStickFigure()
    end

    -- Debug: Draw player bounding box
    love.graphics.setColor(1, 0, 0, 0.3)
    love.graphics.rectangle("line", -self.width / 2, -self.height, self.width, self.height)

    love.graphics.pop()
end

function Player:drawRunningStickFigure()
    -- Head (at top of body)
    love.graphics.setColor(1, 1, 1)
    love.graphics.circle("fill", 0, -self.height + 10, 8)

    -- Body (from head to hips)
    love.graphics.line(0, -self.height + 18, 0, -self.height + 40)

    -- Arms (from shoulders)
    love.graphics.line(0, -self.height + 25, 15 * math.cos(self.armAngle),
        -self.height + 25 + 15 * math.sin(self.armAngle))
    love.graphics.line(0, -self.height + 25, -15 * math.cos(self.armAngle),
        -self.height + 25 + 15 * math.sin(self.armAngle))

    -- Legs (from hips to feet - feet should be at y=0)
    love.graphics.line(0, -self.height + 40, 15 * math.cos(self.legAngle),
        -self.height + 40 + 20 * math.sin(math.abs(self.legAngle)))
    love.graphics.line(0, -self.height + 40, -15 * math.cos(self.legAngle),
        -self.height + 40 + 20 * math.sin(math.abs(self.legAngle)))
end

function Player:drawJumpingStickFigure()
    -- Head
    love.graphics.setColor(1, 1, 1)
    love.graphics.circle("fill", 0, -self.height + 10, 8)

    -- Body
    love.graphics.line(0, -self.height + 18, 0, -self.height + 40)

    -- Arms (up in air)
    love.graphics.line(0, -self.height + 25, 10, -self.height + 15)
    love.graphics.line(0, -self.height + 25, -10, -self.height + 15)

    -- Legs (bent in air)
    love.graphics.line(0, -self.height + 40, 10, -self.height + 50)
    love.graphics.line(0, -self.height + 40, -10, -self.height + 50)
end

function Player:drawCrouchingStickFigure()
    -- Head (lower due to crouch)
    love.graphics.setColor(1, 1, 1)
    love.graphics.circle("fill", 0, -self.height + 5, 8)

    -- Body (angled forward)
    love.graphics.line(0, -self.height + 13, 0, -self.height + 25)

    -- Arms (supporting)
    love.graphics.line(0, -self.height + 20, 10, -self.height + 30)
    love.graphics.line(0, -self.height + 20, -10, -self.height + 30)

    -- Legs (crouched position)
    love.graphics.line(0, -self.height + 25, 15, -self.height + 30)
    love.graphics.line(0, -self.height + 25, -15, -self.height + 30)
end

function Player:drawSlidingStickFigure()
    -- Head
    love.graphics.setColor(1, 1, 1)
    love.graphics.circle("fill", 0, -self.height + 5, 8)

    -- Body (horizontal)
    love.graphics.line(0, -self.height + 13, 20, -self.height + 13)

    -- Arms (forward)
    love.graphics.line(0, -self.height + 13, 10, -self.height + 5)
    love.graphics.line(0, -self.height + 13, -5, -self.height + 8)

    -- Legs (extended back)
    love.graphics.line(0, -self.height + 13, -15, -self.height + 20)
    love.graphics.line(0, -self.height + 13, -15, -self.height + 5)
end

function Player:handleKeyPress(key)
    if key == "a" or key == "left" then
        self.currentLane = math.max(1, self.currentLane - 1)
        self.targetX = self.lanes[self.currentLane]
    elseif key == "d" or key == "right" then
        self.currentLane = math.min(3, self.currentLane + 1)
        self.targetX = self.lanes[self.currentLane]
    elseif (key == "w" or key == "up" or key == "space") and self.isOnGround then
        self:jump()
    elseif key == "s" or key == "down" then
        self:crouch()
    elseif key == "lctrl" or key == "rctrl" then
        self:slide()
    end
end

function Player:handleKeyRelease(key)
    if (key == "s" or key == "down") and self.state == "crouching" then
        self.state = "running"
        self.height = self.normalHeight
        self.y = self.groundY - self.height -- Adjust position for new height
    end
end

function Player:jump()
    if self.isOnGround then
        self.velocityY = self.jumpForce
        self.isOnGround = false
        self.state = "jumping"
        self.animationTime = 0
    end
end

function Player:crouch()
    if self.isOnGround and self.state ~= "crouching" and self.state ~= "sliding" then
        self.state = "crouching"
        self.height = self.crouchHeight
        self.y = self.groundY - self.height
        self.animationTime = 0
    end
end

function Player:slide()
    if self.isOnGround and self.state ~= "sliding" and self.state ~= "crouching" then
        self.state = "sliding"
        self.height = self.crouchHeight
        self.y = self.groundY - self.height
        self.animationTime = 0
    end
end

function Player:reset()
    self.x = self.lanes[self.currentLane] or 200
    self.y = self.groundY - self.height -- Position on ground
    self.velocityY = 0
    self.isOnGround = true
    self.state = "running"
    self.height = self.normalHeight
    self.currentLane = 2
    self.targetX = self.lanes[self.currentLane]
    self.animationTime = 0
end

function Player:getHitbox()
    -- Return collision hitbox
    if self.state == "crouching" or self.state == "sliding" then
        return {
            x = self.x - 15,
            y = self.y - self.crouchHeight,
            width = 30,
            height = self.crouchHeight
        }
    else
        return {
            x = self.x - 15,
            y = self.y - self.height,
            width = 30,
            height = self.height
        }
    end
end

return Player
