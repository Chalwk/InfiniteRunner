-- Infinite Runner Game - Love2D
-- License: MIT
-- Copyright (c) 2025 Jericho Crosby (Chalwk)

local ipairs = ipairs
local math_sin = math.sin
local math_floor = math.floor

local lg = love.graphics

local Menu = {}
Menu.__index = Menu

local function updateButtonPositions(self)
    local centerX = self.screenWidth / 2
    local startY = self.screenHeight / 2 - 50

    -- Main menu buttons
    if self.menuButtons then
        for i, button in ipairs(self.menuButtons) do
            button.x = centerX - button.width / 2
            button.y = startY + (i - 1) * 70
        end
    end

    -- Game over buttons
    if self.gameOverButtons then
        for i, button in ipairs(self.gameOverButtons) do
            button.x = centerX - button.width / 2
            button.y = self.screenHeight / 2 + 60 + (i - 1) * 60
        end
    end
end

local function createMenuButtons(self)
    self.menuButtons = {
        {
            text = "Start Game",
            action = "start",
            width = 200,
            height = 50,
            x = 0,
            y = 0,
            color = {0.2, 0.7, 0.3}
        },
        {
            text = "Quit Game",
            action = "quit",
            width = 200,
            height = 50,
            x = 0,
            y = 0,
            color = {0.8, 0.3, 0.3}
        }
    }
end

local function createGameOverButtons(self)
    self.gameOverButtons = {
        {
            text = "Play Again",
            action = "restart",
            width = 180,
            height = 45,
            x = 0,
            y = 0,
            color = {0.2, 0.7, 0.3}
        },
        {
            text = "Main Menu",
            action = "menu",
            width = 180,
            height = 45,
            x = 0,
            y = 0,
            color = {0.3, 0.5, 0.8}
        }
    }
end

local function drawButton(self, button, isHovered)
    local pulse = math_sin(self.time * 6) * 0.1 + 0.9

    -- Button background with hover effect
    lg.setColor(button.color[1], button.color[2], button.color[3], isHovered and 0.9 or 0.7)
    lg.rectangle("fill", button.x, button.y, button.width, button.height, 10)

    -- Button border
    lg.setColor(1, 1, 1, isHovered and 1 or 0.8)
    lg.setLineWidth(isHovered and 3 or 2)
    lg.rectangle("line", button.x, button.y, button.width, button.height, 10)

    -- Button text with shadow
    lg.setFont(self.mediumFont)
    local textWidth = self.mediumFont:getWidth(button.text)
    local textHeight = self.mediumFont:getHeight()

    -- Text shadow
    lg.setColor(0, 0, 0, 0.5)
    lg.print(button.text, button.x + (button.width - textWidth) / 2 + 2,
        button.y + (button.height - textHeight) / 2 + 2)

    -- Main text
    lg.setColor(1, 1, 1, pulse)
    lg.print(button.text, button.x + (button.width - textWidth) / 2,
        button.y + (button.height - textHeight) / 2)

    lg.setLineWidth(1)
end

local function drawRunningStickFigure(self, x, y, scale)
    lg.push()
    lg.translate(x, y)
    lg.scale(scale, scale)

    local runCycle = self.time * 8
    local legOffset = math_sin(runCycle) * 8
    local armOffset = math_sin(runCycle + math.pi) * 6

    lg.setColor(0.9, 0.9, 0.9)
    lg.setLineWidth(3)

    -- Head
    lg.circle("line", 0, -40, 10)

    -- Body
    lg.line(0, -30, 0, 0)

    -- Legs
    lg.line(0, 0, -15, 20 + legOffset)
    lg.line(0, 0, 15, 20 - legOffset)

    -- Arms
    lg.line(0, -15, -20, -10 + armOffset)
    lg.line(0, -15, 20, -10 - armOffset)

    lg.setLineWidth(1)
    lg.pop()
end

local function drawMenuTitle(self, screenWidth, screenHeight)
    local centerX = screenWidth / 2
    local centerY = screenHeight / 4

    -- Title with glow effect
    local glow = (math_sin(self.time * 3) + 1) * 0.3 + 0.4

    lg.setFont(self.titleFont)

    -- Title shadow
    lg.setColor(0, 0, 0, 0.5)
    lg.printf("INFINITE RUNNER", 0, centerY - 48, screenWidth, "center")

    -- Main title
    lg.setColor(0.2, 0.8, 0.9, glow)
    lg.printf("INFINITE RUNNER", 0, centerY - 50, screenWidth, "center")

    -- Subtitle
    lg.setColor(1, 1, 1, 0.8)
    lg.setFont(self.mediumFont)
    lg.printf("Endless Adventure", 0, centerY, screenWidth, "center")

    -- Draw running stick figures on sides
    drawRunningStickFigure(self, centerX - 200, centerY + 20, 1.2)
    drawRunningStickFigure(self, centerX + 200, centerY + 20, 1.2)
end

local function drawGameOverTitle(self, screenWidth, screenHeight)
    local centerX = screenWidth / 2
    local centerY = screenHeight / 4

    lg.setFont(self.titleFont)
    lg.setColor(0.9, 0.2, 0.2)
    lg.printf("GAME OVER", 0, centerY - 50, screenWidth, "center")

    -- Score display
    lg.setColor(1, 1, 1)
    lg.setFont(self.largeFont)
    lg.printf("Score: " .. math_floor(self.finalScore), 0, centerY + 20, screenWidth, "center")

    if self.newHighScore then
        lg.setColor(1, 0.8, 0.2)
        lg.setFont(self.mediumFont)
        lg.printf("NEW HIGH SCORE!", 0, centerY + 70, screenWidth, "center")
    end
end

function Menu.new()
    local instance = setmetatable({}, Menu)

    instance.screenWidth = 800
    instance.screenHeight = 600
    instance.time = 0
    instance.buttonHover = nil
    instance.finalScore = 0
    instance.newHighScore = false

    instance.smallFont = lg.newFont(16)
    instance.mediumFont = lg.newFont(24)
    instance.largeFont = lg.newFont(36)
    instance.titleFont = lg.newFont(64)

    createMenuButtons(instance)
    createGameOverButtons(instance)

    return instance
end

function Menu:update(dt, screenWidth, screenHeight)
    self.time = self.time + dt

    if screenWidth ~= self.screenWidth or screenHeight ~= self.screenHeight then
        self.screenWidth = screenWidth
        self.screenHeight = screenHeight
        updateButtonPositions(self)
    end

    -- Update button hover state
    self:updateButtonHover(love.mouse.getX(), love.mouse.getY())
end

function Menu:updateButtonHover(x, y)
    self.buttonHover = nil

    local buttons = self.state == "gameover" and self.gameOverButtons or self.menuButtons

    for _, button in ipairs(buttons) do
        if x >= button.x and x <= button.x + button.width and
            y >= button.y and y <= button.y + button.height then
            self.buttonHover = button.action
            return
        end
    end
end

function Menu:draw(screenWidth, screenHeight, state)
    self.state = state

    if state == "menu" then
        drawMenuTitle(self, screenWidth, screenHeight)

        -- Draw menu buttons
        for _, button in ipairs(self.menuButtons) do
            drawButton(self, button, self.buttonHover == button.action)
        end

        -- Instructions
        lg.setColor(1, 1, 1, 0.7)
        lg.setFont(self.smallFont)
        lg.printf("Use SPACE/UP to jump and DOWN to crouch. Avoid obstacles and collect power-ups!",
            50, screenHeight - 100, screenWidth - 100, "center")

    elseif state == "gameover" then
        drawGameOverTitle(self, screenWidth, screenHeight)

        -- Draw game over buttons
        for _, button in ipairs(self.gameOverButtons) do
            drawButton(self, button, self.buttonHover == button.action)
        end
    end

    -- Copyright
    lg.setColor(1, 1, 1, 0.6)
    lg.setFont(self.smallFont)
    lg.printf("© 2025 Jericho Crosby – Infinite Runner",
        10, screenHeight - 30, screenWidth - 20, "right")
end

function Menu:handleClick(x, y, state)
    local buttons = state == "menu" and self.menuButtons or self.gameOverButtons

    for _, button in ipairs(buttons) do
        if x >= button.x and x <= button.x + button.width and
            y >= button.y and y <= button.y + button.height then
            return button.action
        end
    end

    return nil
end

function Menu:setScreenSize(width, height)
    self.screenWidth = width
    self.screenHeight = height
    updateButtonPositions(self)
end

function Menu:setFinalScore(score, isNewHighScore)
    self.finalScore = score
    self.newHighScore = isNewHighScore
end

return Menu