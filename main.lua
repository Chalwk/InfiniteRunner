-- Infinite Runner
-- License: MIT
-- Copyright (c) 2025 Jericho Crosby (Chalwk)

local Player = require("classes/Player")
local ObstacleManager = require("classes/ObstacleManager")
local BackgroundManager = require("classes/BackgroundManager")

local player, obstacleManager, backgroundManager
local gameState = "playing" -- playing, game_over
local score = 0
local highScore = 0
local gameSpeed = 200
local baseSpeed = 200
local speedIncreaseTimer = 0
local speedIncreaseInterval = 10
local screenWidth, screenHeight
local fonts = {}

function love.load()
    love.window.setTitle("Infinite Runner")
    screenWidth = love.graphics.getWidth()
    screenHeight = love.graphics.getHeight()

    -- Load fonts
    fonts.large = love.graphics.newFont(36)
    fonts.medium = love.graphics.newFont(24)
    fonts.small = love.graphics.newFont(18)

    player = Player.new()
    obstacleManager = ObstacleManager.new()
    backgroundManager = BackgroundManager.new()

    player:setScreenSize(screenWidth, screenHeight)
    obstacleManager:setScreenSize(screenWidth, screenHeight)
    backgroundManager:setScreenSize(screenWidth, screenHeight)

    player:reset()
end

function love.update(dt)
    if gameState == "playing" then
        -- Increase game speed over time
        speedIncreaseTimer = speedIncreaseTimer + dt
        if speedIncreaseTimer >= speedIncreaseInterval then
            speedIncreaseTimer = 0
            gameSpeed = gameSpeed + 20
        end

        player:update(dt, gameSpeed)
        obstacleManager:update(dt, gameSpeed)
        backgroundManager:update(dt, gameSpeed)

        -- Update score based on distance
        score = score + dt * 10

        -- Check collisions
        if obstacleManager:checkCollisions(player) then
            gameState = "game_over"
            if score > highScore then
                highScore = score
            end
        end
    end
end

function love.draw()
    backgroundManager:draw()

    if gameState == "playing" then
        player:draw()
        obstacleManager:draw()
    end

    -- Draw UI
    love.graphics.setFont(fonts.medium)
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("Score: " .. math.floor(score), 20, 20)
    love.graphics.print("High Score: " .. math.floor(highScore), 20, 50)
    love.graphics.print("Speed: " .. math.floor(gameSpeed), 20, 80)

    if gameState == "game_over" then
        love.graphics.setFont(fonts.large)
        love.graphics.setColor(1, 0, 0, 0.8)
        love.graphics.rectangle("fill", 0, 0, screenWidth, screenHeight)

        love.graphics.setColor(1, 1, 1)
        love.graphics.printf("GAME OVER", 0, screenHeight / 2 - 50, screenWidth, "center")
        love.graphics.setFont(fonts.medium)
        love.graphics.printf("Final Score: " .. math.floor(score), 0, screenHeight / 2, screenWidth, "center")
        love.graphics.printf("Press R to restart", 0, screenHeight / 2 + 50, screenWidth, "center")
    end

    -- Draw controls help
    love.graphics.setFont(fonts.small)
    love.graphics.setColor(1, 1, 1, 0.7)
    love.graphics.print("WASD: Move | Space: Jump | CTRL: Crouch | Shift: Slide", 20, screenHeight - 30)
end

function love.keypressed(key)
    if gameState == "playing" then
        player:handleKeyPress(key)

        if key == "escape" then
            love.event.quit()
        end
    elseif gameState == "game_over" then
        if key == "r" then
            -- Restart game
            gameState = "playing"
            score = 0
            gameSpeed = baseSpeed
            speedIncreaseTimer = 0
            player:reset()
            obstacleManager:reset()
        end
    end
end

function love.keyreleased(key)
    if gameState == "playing" then
        player:handleKeyRelease(key)
    end
end
