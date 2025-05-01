
-- Constants for level size and positions
local WIDTH = 800
local HEIGHT = 600
local GROUND_Y = 500
local PILLAR_WIDTH = 30
local PILLAR_HEIGHT = 200
local COLUMN_SPACING = 50
local GROUND_HEIGHT = 5
local PYRAMID_HEIGHT = 5
local MARIO_SPEED = 200
local GRAVITY = 400
local JUMP_STRENGTH = -200

-- Game variables
local player = {x = 100, y = GROUND_Y - 50, width = 32, height = 64, vx = 0, vy = 0, onGround = true}
local pillars = {}
local pyramid = {}
local flagpole = {x = WIDTH - 100, y = GROUND_Y - 200, width = 10, height = 200}
local victory = false

-- Sprites
local spritesheet
local quads = {}

-- Love2D setup
function love.load()
    -- Load the spritesheet
    spritesheet = love.graphics.newImage("spritesheet.png")

    -- Define quads (coordinates may need adjusting based on your spritesheet)
    quads.brick = love.graphics.newQuad(0, 0, 16, 16, spritesheet:getDimensions())
    quads.flagpole = love.graphics.newQuad(64, 0, 16, 160, spritesheet:getDimensions())

    -- Generate pillars and pyramid
    generatePillars()
    generatePyramid()
end

-- Generate pillars (columns) and the ground
function generatePillars()
    for i = 0, WIDTH // COLUMN_SPACING do
        local pillarX = i * COLUMN_SPACING
        for y = GROUND_Y - PILLAR_HEIGHT, GROUND_Y - 1 do
            table.insert(pillars, {x = pillarX, y = y, width = PILLAR_WIDTH, height = 1})
        end
    end
end

-- Generate pyramid blocks
function generatePyramid()
    local pyramidStartX = 300
    local pyramidTopY = GROUND_Y - PILLAR_HEIGHT - PYRAMID_HEIGHT * 30

    for i = 0, PYRAMID_HEIGHT - 1 do
        local rowWidth = PYRAMID_HEIGHT - i
        for j = 0, rowWidth - 1 do
            table.insert(pyramid, {x = pyramidStartX + (j * 30) + (i * 15), y = pyramidTopY + (i * 30), width = 30, height = 30})
        end
    end
end

-- Update player movement and physics
function love.update(dt)
    if not victory then
        -- Player controls (left/right and jump)
        if love.keyboard.isDown("right") then
            player.vx = MARIO_SPEED
        elseif love.keyboard.isDown("left") then
            player.vx = -MARIO_SPEED
        else
            player.vx = 0
        end

        -- Jumping
        if love.keyboard.isDown("space") and player.onGround then
            player.vy = JUMP_STRENGTH
            player.onGround = false
        end

        -- Gravity
        player.vy = player.vy + GRAVITY * dt
        player.x = player.x + player.vx * dt
        player.y = player.y + player.vy * dt

        -- Ground collision
        if player.y >= GROUND_Y - player.height then
            player.y = GROUND_Y - player.height
            player.vy = 0
            player.onGround = true
        end

        -- Check flagpole collision
        if checkFlagpoleCollision() then
            victory = true
        end
    end
end

-- Check collision with the flagpole
function checkFlagpoleCollision()
    if player.x + player.width > flagpole.x and player.x < flagpole.x + flagpole.width and
       player.y + player.height > flagpole.y then
        return true
    end
    return false
end

-- Draw the level (columns, pyramid, player, flagpole)
function love.draw()
    love.graphics.setColor(1, 1, 1)

    -- Draw columns (ground)
    for _, pillar in ipairs(pillars) do
        love.graphics.draw(spritesheet, quads.brick, pillar.x, pillar.y, 0, 2, 2) -- scaling 2x to fit pillar size
    end

    -- Draw pyramid
    for _, block in ipairs(pyramid) do
        love.graphics.draw(spritesheet, quads.brick, block.x, block.y, 0, 2, 2)
    end

    -- Draw player (Mario)
    love.graphics.setColor(0, 0, 1)
    love.graphics.rectangle("fill", player.x, player.y, player.width, player.height)
    love.graphics.setColor(1, 1, 1)

    -- Draw flagpole
    love.graphics.draw(spritesheet, quads.flagpole, flagpole.x, flagpole.y)

    -- Draw flag
    love.graphics.setColor(1, 0, 0)
    love.graphics.rectangle("fill", flagpole.x, flagpole.y - 50, 50, 30)
    love.graphics.setColor(1, 1, 1)

    -- Victory message
    if victory then
        love.graphics.setColor(1, 1, 1)
        love.graphics.print("Victory! Press R to restart.", 300, 200)
    end
end

-- Restart the level on key press
function love.keypressed(key)
    if key == "r" then
        -- Reset game variables for restarting the level
        player.x = 100
        player.y = GROUND_Y - 50
        player.vx = 0
        player.vy = 0
        player.onGround = true
        victory = false
    end
end
