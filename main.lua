-- Infinite Runner Game - Love2D
-- License: MIT
-- Copyright (c) 2025 Jericho Crosby (Chalwk)

local lg = love.graphics
local math_min = math.min

local Game = require("classes.Game")
local Menu = require("classes.Menu")
local BackgroundManager = require("classes.BackgroundManager")

local game, menu, backgroundManager
local gameState = "menu"
local screenWidth, screenHeight
local stateTransition = { alpha = 0, duration = 0.5, timer = 0, active = false }

local function updateScreenSize()
    screenWidth = lg.getWidth()
    screenHeight = lg.getHeight()
end

local function startStateTransition(newState)
    stateTransition = {
        alpha = 0,
        duration = 0.3,
        timer = 0,
        active = true,
        targetState = newState
    }
end

function love.load()
    lg.setDefaultFilter("nearest", "nearest")
    lg.setLineStyle("smooth")

    game = Game.new()
    menu = Menu.new(game)
    backgroundManager = BackgroundManager.new()

    updateScreenSize()
    menu:setScreenSize(screenWidth, screenHeight)
    game:setScreenSize(screenWidth, screenHeight)
end

function love.update(dt)
    updateScreenSize()

    -- Handle state transitions
    if stateTransition.active then
        stateTransition.timer = stateTransition.timer + dt
        stateTransition.alpha = math_min(stateTransition.timer / stateTransition.duration, 1)

        if stateTransition.timer >= stateTransition.duration then
            gameState = stateTransition.targetState
            stateTransition.active = false
            stateTransition.alpha = 0

            if gameState == "gameover" then
                menu:setFinalScore(game.score, game.score > game.highScore)
            end
        end
    end

    if gameState == "menu" then
        menu:update(dt, screenWidth, screenHeight)
    elseif gameState == "playing" then
        game:update(dt)
        if game:isGameOver() then gameState = "gameover" end
    elseif gameState == "gameover" then
        menu:update(dt, screenWidth, screenHeight)
    end

    backgroundManager:update(dt)
end

function love.draw()
    local time = love.timer.getTime()

    -- Draw background based on state
    if gameState == "menu" or gameState == "gameover" then
        backgroundManager:drawMenuBackground(screenWidth, screenHeight, time)
    elseif gameState == "playing" then
        backgroundManager:drawGameBackground(screenWidth, screenHeight, time)
    end

    -- Draw game content
    if gameState == "menu" then
        menu:draw(screenWidth, screenHeight, "menu")
    elseif gameState == "playing" then
        game:draw()
    elseif gameState == "gameover" then
        menu:draw(screenWidth, screenHeight, "gameover")
    end

    -- Draw transition overlay
    if stateTransition.active then
        lg.setColor(0, 0, 0, stateTransition.alpha)
        lg.rectangle("fill", 0, 0, screenWidth, screenHeight)
    end
end

function love.mousepressed(x, y, button, istouch)
    if button == 1 then
        local currentState = gameState

        if currentState == "menu" then
            local action = menu:handleClick(x, y, "menu")
            if action == "start" then
                startStateTransition("playing")
                game:startNewGame()
            elseif action == "quit" then
                love.event.quit()
            end
        elseif currentState == "gameover" then
            local action = menu:handleClick(x, y, "gameover")
            if action == "restart" then
                startStateTransition("playing")
                game:startNewGame()
            elseif action == "menu" then
                startStateTransition("menu")
            end
        end
    end
end

function love.keypressed(key)
    local currentState = gameState

    if key == "escape" then
        if currentState == "playing" then
            startStateTransition("menu")
        elseif currentState == "gameover" then
            startStateTransition("menu")
        elseif currentState == "menu" then
            love.event.quit()
        end
    elseif key == "f11" then
        local fullscreen = love.window.getFullscreen()
        love.window.setFullscreen(not fullscreen)
    elseif currentState == "playing" then
        if not game:isGameOver() then
            if key == "space" or key == "up" or key == "w" then
                game:playerJump()
            elseif key == "down" or key == "s" then
                game:playerCrouch(true)
            end
        end
    end
end

function love.keyreleased(key)
    local currentState = stateTransition.active and stateTransition.targetState or gameState

    if currentState == "playing" then
        if key == "down" or key == "s" then
            game:playerCrouch(false)
        end
    end
end

function love.resize(w, h)
    updateScreenSize()
    menu:setScreenSize(screenWidth, screenHeight)
    game:setScreenSize(screenWidth, screenHeight)
end