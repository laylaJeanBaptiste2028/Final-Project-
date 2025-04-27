#Final project

-- File: main.lua
--[[
    Demonstrates rendering a screen of tiles.
]]

Class = require 'class'
push = require 'push'

require 'Animation'
require 'Map'
require 'Player'

-- close resolution to NES but 16:9
VIRTUAL_WIDTH = 432
VIRTUAL_HEIGHT = 243

-- actual window resolution
WINDOW_WIDTH = 1280
WINDOW_HEIGHT = 720

-- seed RNG
math.randomseed(os.time())

-- makes upscaling look pixel-y instead of blurry
love.graphics.setDefaultFilter('nearest', 'nearest')

-- an object to contain our map data
map = Map()

-- performs initialization of all objects and data needed by program
function love.load()

    -- sets up a different, better-looking retro font as our default
    love.graphics.setFont(love.graphics.newFont('fonts/font.ttf', 8))

    -- sets up virtual screen resolution for an authentic retro feel
    push:setupScreen(VIRTUAL_WIDTH, VIRTUAL_HEIGHT, WINDOW_WIDTH, WINDOW_HEIGHT, {
        fullscreen = false,
        resizable = true
    })

    love.window.setTitle('Super Mario 50')

    love.keyboard.keysPressed = {}
    love.keyboard.keysReleased = {}
end

-- called whenever window is resized
function love.resize(w, h)
    push:resize(w, h)
end

-- global key pressed function
function love.keyboard.wasPressed(key)
    if (love.keyboard.keysPressed[key]) then
        return true
    else
        return false
    end
end

-- global key released function
function love.keyboard.wasReleased(key)
    if (love.keyboard.keysReleased[key]) then
        return true
    else
        return false
    end
end

-- called whenever a key is pressed
function love.keypressed(key)
    if key == 'escape' then
        love.event.quit()
    end

    love.keyboard.keysPressed[key] = true
end

-- called whenever a key is released
function love.keyreleased(key)
    love.keyboard.keysReleased[key] = true
end

-- called every frame, with dt passed in as delta in time since last frame
function love.update(dt)
    map:update(dt)

    -- reset all keys pressed and released this frame
    love.keyboard.keysPressed = {}
    love.keyboard.keysReleased = {}
end

-- called each frame, used to render to the screen
function love.draw()
    -- begin virtual resolution drawing
    push:apply('start')

    -- clear screen using Mario background blue
    love.graphics.clear(108/255, 140/255, 255/255, 255/255)

    -- renders our map object onto the screen
    love.graphics.translate(math.floor(-map.camX + 0.5), math.floor(-map.camY + 0.5))
    map:render()

    -- end virtual resolution
    push:apply('end')
end

---------------------------------------------------

-- File: Map.lua
--[[
    Contains tile data and necessary code for rendering a tile map to the
    screen.
]]

require 'Util'

Map = Class{}

TILE_BRICK = 1
TILE_EMPTY = -1

-- cloud tiles
CLOUD_LEFT = 6
CLOUD_RIGHT = 7

-- bush tiles
BUSH_LEFT = 2
BUSH_RIGHT = 3

-- mushroom tiles
MUSHROOM_TOP = 10
MUSHROOM_BOTTOM = 11

-- jump block
JUMP_BLOCK = 5
JUMP_BLOCK_HIT = 9

-- a speed to multiply delta time to scroll map; smooth value
local SCROLL_SPEED = 62

-- constructor for our map object
function Map:init()

    self.spritesheet = love.graphics.newImage('graphics/spritesheet.png')
    self.sprites = generateQuads(self.spritesheet, 16, 16)
    self.music = love.audio.newSource('sounds/music.wav', 'static')

    self.tileWidth = 16
    self.tileHeight = 16
    self.mapWidth = 30
    self.mapHeight = 28
    self.tiles = {}

    -- applies positive Y influence on anything affected
    self.gravity = 15

    -- associate player with map
    self.player = Player(self)

    -- camera offsets
    self.camX = 0
    self.camY = -3

    -- cache width and height of map in pixels
    self.mapWidthPixels = self.mapWidth * self.tileWidth
    self.mapHeightPixels = self.mapHeight * self.tileHeight

    -- first, fill map with empty tiles
    for y = 1, self.mapHeight do
        for x = 1, self.mapWidth do
            
            -- support for multiple sheets per tile; storing tiles as tables 
            self:setTile(x, y, TILE_EMPTY)
        end
    end

    -- begin generating the terrain using vertical scan lines
    local x = 1
    while x < self.mapWidth do
        
        -- 2% chance to generate a cloud
        -- make sure we're 2 tiles from edge at least
        if x < self.mapWidth - 2 then
            if math.random(20) == 1 then
                
                -- choose a random vertical spot above where blocks/pipes generate
                local cloudStart = math.random(self.mapHeight / 2 - 6)

                self:setTile(x, cloudStart, CLOUD_LEFT)
                self:setTile(x + 1, cloudStart, CLOUD_RIGHT)
            end
        end

        -- 5% chance to generate a mushroom
        if math.random(20) == 1 then
            -- left side of pipe
            self:setTile(x, self.mapHeight / 2 - 2, MUSHROOM_TOP)
            self:setTile(x, self.mapHeight / 2 - 1, MUSHROOM_BOTTOM)

            -- creates column of tiles going to bottom of map
            for y = self.mapHeight / 2, self.mapHeight do
                self:setTile(x, y, TILE_BRICK)
            end

            -- next vertical scan line
            x = x + 1

        -- 10% chance to generate bush, being sure to generate away from edge
        elseif math.random(10) == 1 and x < self.mapWidth - 3 then
            local bushLevel = self.mapHeight / 2 - 1

            -- place bush component and then column of bricks
            self:setTile(x, bushLevel, BUSH_LEFT)
            for y = self.mapHeight / 2, self.mapHeight do
                self:setTile(x, y, TILE_BRICK)
            end
            x = x + 1

            self:setTile(x, bushLevel, BUSH_RIGHT)
            for y = self.mapHeight / 2, self.mapHeight do
                self:setTile(x, y, TILE_BRICK)
            end
            x = x + 1

        -- 10% chance to not generate anything, creating a gap
        elseif math.random(10) ~= 1 then
            
            -- creates column of tiles going to bottom of map
            for y = self.mapHeight / 2, self.mapHeight do
                self:setTile(x, y, TILE_BRICK)
            end

            -- chance to create a block for Mario to hit
            if math.random(15) == 1 then
                self:setTile(x, self.mapHeight / 2 - 4, JUMP_BLOCK)
            end

            -- next vertical scan line
            x = x + 1
        else
            -- increment X so we skip two scanlines, creating a 2-tile gap
            x = x + 2
        end
    end

    -- start the background music
    self.music:setLooping(true)
    self.music:play()
end

-- return whether a given tile is collidable
function Map:collides(tile)
    -- define our collidable tiles
    local collidables = {
        TILE_BRICK, JUMP_BLOCK, JUMP_BLOCK_HIT,
        MUSHROOM_TOP, MUSHROOM_BOTTOM
    }

    -- iterate and return true if our tile type matches
    for _, v in ipairs(collidables) do
        if tile.id == v then
            return true
        end
    end

    return false
end

-- function to update camera offset with delta time
function Map:update(dt)
    self.player:update(dt)
    
    -- keep camera's X coordinate following the player, preventing camera from
    -- scrolling past 0 to the left and the map's width
    self.camX = math.max(0, math.min(self.player.x - VIRTUAL_WIDTH / 2,
        math.min(self.mapWidthPixels - VIRTUAL_WIDTH, self.player.x)))
end

-- gets the tile type at a given pixel coordinate
function Map:tileAt(x, y)
    return {
        x = math.floor(x / self.tileWidth) + 1,
        y = math.floor(y / self.tileHeight) + 1,
        id = self:getTile(math.floor(x / self.tileWidth) + 1, math.floor(y / self.tileHeight) + 1)
    }
end

-- returns an integer value for the tile at a given x-y coordinate
function Map:getTile(x, y)
    return self.tiles[(y - 1) * self.mapWidth + x]
end

-- sets a tile at a given x-y coordinate to an integer value
function Map:setTile(x, y, id)
    self.tiles[(y - 1) * self.mapWidth + x] = id
end

-- renders our map to the screen, to be called by main's render
function Map:render()
    for y = 1, self.mapHeight do
        for x = 1, self.mapWidth do
            local tile = self:getTile(x, y)
            if tile ~= TILE_EMPTY then
                love.graphics.draw(self.spritesheet, self.sprites[tile],
                    (x - 1) * self.tileWidth, (y - 1) * self.tileHeight)
            end
        end
    end

    self.player:render()
end


-- Player.lua
--[[ 
    Represents our player in the game, with its own sprite. 
]]

Player = Class{}

local WALKING_SPEED = 140
local JUMP_VELOCITY = 400

function Player:init(map)
    self.x = 0
    self.y = 0
    self.width = 16
    self.height = 20

    self.xOffset = 8
    self.yOffset = 10

    self.map = map
    self.texture = love.graphics.newImage('graphics/blue_alien.png')

    self.sounds = {
        ['jump'] = love.audio.newSource('sounds/jump.wav', 'static'),
        ['hit'] = love.audio.newSource('sounds/hit.wav', 'static'),
        ['coin'] = love.audio.newSource('sounds/coin.wav', 'static')
    }

    self.frames = {}
    self.currentFrame = nil
    self.state = 'idle'
    self.direction = 'left'
    self.dx = 0
    self.dy = 0

    self.y = map.tileHeight * ((map.mapHeight - 2) / 2) - self.height
    self.x = map.tileWidth * 10

    self.animations = {
        ['idle'] = Animation({
            texture = self.texture,
            frames = { love.graphics.newQuad(0, 0, 16, 20, self.texture:getDimensions()) }
        }),
        ['walking'] = Animation({
            texture = self.texture,
            frames = {
                love.graphics.newQuad(128, 0, 16, 20, self.texture:getDimensions()),
                love.graphics.newQuad(144, 0, 16, 20, self.texture:getDimensions()),
                love.graphics.newQuad(160, 0, 16, 20, self.texture:getDimensions()),
                love.graphics.newQuad(144, 0, 16, 20, self.texture:getDimensions())
            },
            interval = 0.15
        }),
        ['jumping'] = Animation({
            texture = self.texture,
            frames = { love.graphics.newQuad(32, 0, 16, 20, self.texture:getDimensions()) }
        })
    }

    self.animation = self.animations['idle']
    self.currentFrame = self.animation:getCurrentFrame()

    self.behaviors = {
        ['idle'] = function(dt)
            if love.keyboard.wasPressed('space') then
                self.dy = -JUMP_VELOCITY
                self.state = 'jumping'
                self.animation = self.animations['jumping']
                self.sounds['jump']:play()
            elseif love.keyboard.isDown('left') then
                self.direction = 'left'
                self.dx = -WALKING_SPEED
                self.state = 'walking'
                self.animations['walking']:restart()
                self.animation = self.animations['walking']
            elseif love.keyboard.isDown('right') then
                self.direction = 'right'
                self.dx = WALKING_SPEED
                self.state = 'walking'
                self.animations['walking']:restart()
                self.animation = self.animations['walking']
            else
                self.dx = 0
            end
        end,
        ['walking'] = function(dt)
            if love.keyboard.wasPressed('space') then
                self.dy = -JUMP_VELOCITY
                self.state = 'jumping'
                self.animation = self.animations['jumping']
                self.sounds['jump']:play()
            elseif love.keyboard.isDown('left') then
                self.direction = 'left'
                self.dx = -WALKING_SPEED
            elseif love.keyboard.isDown('right') then
                self.direction = 'right'
                self.dx = WALKING_SPEED
            else
                self.dx = 0
                self.state = 'idle'
                self.animation = self.animations['idle']
            end

            self:checkRightCollision()
            self:checkLeftCollision()

            if not self.map:collides(self.map:tileAt(self.x, self.y + self.height)) and
                not self.map:collides(self.map:tileAt(self.x + self.width - 1, self.y + self.height)) then
                self.state = 'jumping'
                self.animation = self.animations['jumping']
            end
        end,
        ['jumping'] = function(dt)
            if self.y > 300 then return end

            if love.keyboard.isDown('left') then
                self.direction = 'left'
                self.dx = -WALKING_SPEED
            elseif love.keyboard.isDown('right') then
                self.direction = 'right'
                self.dx = WALKING_SPEED
            end

            self.dy = self.dy + self.map.gravity

            if self.map:collides(self.map:tileAt(self.x, self.y + self.height)) or
                self.map:collides(self.map:tileAt(self.x + self.width - 1, self.y + self.height)) then
                self.dy = 0
                self.state = 'idle'
                self.animation = self.animations['idle']
                self.y = (self.map:tileAt(self.x, self.y + self.height).y - 1) * self.map.tileHeight - self.height
            end

            self:checkRightCollision()
            self:checkLeftCollision()
        end
    }
end

function Player:update(dt)
    self.behaviors[self.state](dt)
    self.animation:update(dt)
    self.currentFrame = self.animation:getCurrentFrame()
    self.x = self.x + self.dx * dt

    self:calculateJumps()
    self.y = self.y + self.dy * dt
end

function Player:calculateJumps()
    if self.dy < 0 then
        if self.map:tileAt(self.x, self.y).id ~= TILE_EMPTY or
           self.map:tileAt(self.x + self.width - 1, self.y).id ~= TILE_EMPTY then
            self.dy = 0

            local playCoin = false
            local playHit = false

            if self.map:tileAt(self.x, self.y).id == JUMP_BLOCK then
                self.map:setTile(math.floor(self.x / self.map.tileWidth) + 1,
                    math.floor(self.y / self.map.tileHeight) + 1, JUMP_BLOCK_HIT)
                playCoin = true
            else
                playHit = true
            end

            if self.map:tileAt(self.x + self.width - 1, self.y).id == JUMP_BLOCK then
                self.map:setTile(math.floor((self.x + self.width - 1) / self.map.tileWidth) + 1,
                    math.floor(self.y / self.map.tileHeight) + 1, JUMP_BLOCK_HIT)
                playCoin = true
            else
                playHit = true
            end

            if playCoin then
                self.sounds['coin']:play()
            elseif playHit then
                self.sounds['hit']:play()
            end
        end
    end
end

function Player:checkLeftCollision()
    if self.dx < 0 then
        if self.map:collides(self.map:tileAt(self.x - 1, self.y)) or
           self.map:collides(self.map:tileAt(self.x - 1, self.y + self.height - 1)) then
            self.dx = 0
            self.x = self.map:tileAt(self.x - 1, self.y).x * self.map.tileWidth
        end
    end
end

function Player:checkRightCollision()
    if self.dx > 0 then
        if self.map:collides(self.map:tileAt(self.x + self.width, self.y)) or
           self.map:collides(self.map:tileAt(self.x + self.width, self.y + self.height - 1)) then
            self.dx = 0
            self.x = (self.map:tileAt(self.x + self.width, self.y).x - 1) * self.map.tileWidth - self.width
        end
    end
end

function Player:render()
    local scaleX = self.direction == 'right' and 1 or -1

    love.graphics.draw(self.texture, self.currentFrame, math.floor(self.x + self.xOffset),
        math.floor(self.y + self.yOffset), 0, scaleX, 1, self.xOffset, self.yOffset)
end


-- push.lua

local love11 = love.getVersion() == 11
local getDPI = love11 and love.window.getDPIScale or love.window.getPixelScale
local windowUpdateMode = love11 and love.window.updateMode or function(width, height, settings)
    local _, _, flags = love.window.getMode()
    for k, v in pairs(settings) do flags[k] = v end
    love.window.setMode(width, height, flags)
end

local push = {
    defaults = {
        fullscreen = false,
        resizable = false,
        pixelperfect = false,
        highdpi = true,
        canvas = true,
        stencil = true
    }
}
setmetatable(push, push)

function push:applySettings(settings)
    for k, v in pairs(settings) do
        self["_" .. k] = v
    end
end

function push:resetSettings()
    return self:applySettings(self.defaults)
end

function push:setupScreen(WWIDTH, WHEIGHT, RWIDTH, RHEIGHT, settings)
    settings = settings or {}

    self._WWIDTH, self._WHEIGHT = WWIDTH, WHEIGHT
    self._RWIDTH, self._RHEIGHT = RWIDTH, RHEIGHT

    self:applySettings(self.defaults)
    self:applySettings(settings)

    windowUpdateMode(self._RWIDTH, self._RHEIGHT, {
        fullscreen = self._fullscreen,
        resizable = self._resizable,
        highdpi = self._highdpi
    })

    self:initValues()

    if self._canvas then
        self:setupCanvas({ "default" })
    end

    self._borderColor = {0, 0, 0}
    self._drawFunctions = {
        ["start"] = self.start,
        ["end"] = self.finish
    }

    return self
end

function push:setupCanvas(canvases)
    table.insert(canvases, { name = "_render", private = true })
    self._canvas = true
    self.canvases = {}

    for i = 1, #canvases do
        push:addCanvas(canvases[i])
    end

    return self
end

function push:addCanvas(params)
    table.insert(self.canvases, {
        name = params.name,
        private = params.private,
        shader = params.shader,
        canvas = love.graphics.newCanvas(self._WWIDTH, self._WHEIGHT),
        stencil = params.stencil or self._stencil
    })
end

function push:setCanvas(name)
    if not self._canvas then return true end
    return love.graphics.setCanvas(self:getCanvasTable(name).canvas)
end

function push:getCanvasTable(name)
    for i = 1, #self.canvases do
        if self.canvases[i].name == name then
            return self.canvases[i]
        end
    end
end
function push:initValues()
    self._PSCALE = getDPI()

    self._SCALE = {
        x = self._RWIDTH / self._WWIDTH,
        y = self._RHEIGHT / self._WHEIGHT
    }

    self._SCALE.x = math.min(self._SCALE.x, self._SCALE.y)

    if self._pixelperfect or self._highdpi then
        self._SCALE.x = math.floor(self._SCALE.x)
    end

    self._OFFSET = {
        x = (self._RWIDTH - (self._WWIDTH * self._SCALE.x)) * 0.5,
        y = (self._RHEIGHT - (self._WHEIGHT * self._SCALE.x)) * 0.5
    }
end

function push:apply(operation, shader)
    self._drawFunctions[operation](self, shader)
end

function push:start()
    if self._canvas then
        love.graphics.setCanvas(self:getCanvasTable("_render").canvas)
    else
        love.graphics.push()
        love.graphics.origin()
    end
end

function push:finish(shader)
    if self._canvas then
        love.graphics.setCanvas()
        if shader then
            love.graphics.setShader(shader)
        end

        love.graphics.push()
        love.graphics.origin()
        self:applyScale()
        love.graphics.draw(self:getCanvasTable("_render").canvas)
        love.graphics.pop()

        if shader then
            love.graphics.setShader()
        end
    else
        love.graphics.pop()
    end
end

function push:applyScale()
    love.graphics.translate(self._OFFSET.x, self._OFFSET.y)
    love.graphics.scale(self._SCALE.x, self._SCALE.x)
end

function push:setBorderColor(color, g, b)
    if type(color) == "table" then
        self._borderColor = color
    else
        self._borderColor = {color, g, b}
    end
end

function push:getDimensions()
    return self._WWIDTH, self._WHEIGHT
end

function push:getWindowDimensions()
    return self._RWIDTH, self._RHEIGHT
end

function push:getPixelScale()
    return self._SCALE.x
end

function push:toGame(x, y)
    x, y = x - self._OFFSET.x, y - self._OFFSET.y
    x = x / self._SCALE.x
    y = y / self._SCALE.x

    return x, y
end

function push:toReal(x, y)
    x = x * self._SCALE.x + self._OFFSET.x
    y = y * self._SCALE.x + self._OFFSET.y

    return x, y
end

function push:resize(w, h)
    self._RWIDTH = w
    self._RHEIGHT = h
    self:initValues()
    if self._canvas then
        local canvas = self:getCanvasTable("_render").canvas
        canvas:setFilter("nearest", "nearest")
        canvas:release()
        self:getCanvasTable("_render").canvas = love.graphics.newCanvas(self._WWIDTH, self._WHEIGHT)
    end
end

function push:switchFullscreen(winw, winh)
    self._fullscreen = not self._fullscreen
    local windowWidth, windowHeight = love.window.getDesktopDimensions()
    if self._fullscreen then
        self._RWIDTH, self._RHEIGHT = windowWidth, windowHeight
    else
        self._RWIDTH, self._RHEIGHT = winw, winh
    end
    self:initValues()
    windowUpdateMode(self._RWIDTH, self._RHEIGHT, { fullscreen = self._fullscreen })
end

return push


-- Util.lua --
[[ 
    Stores utility functions used by our game engine.
]]

-- takes a texture, width, and height of tiles and splits it into quads
-- that can be individually drawn
function generateQuads(atlas, tilewidth, tileheight)
    local sheetWidth = atlas:getWidth() / tilewidth
    local sheetHeight = atlas:getHeight() / tileheight

    local sheetCounter = 1
    local quads = {}

    for y = 0, sheetHeight - 1 do
        for x = 0, sheetWidth - 1 do
            -- this quad represents a square cutout of our atlas that we can
            -- individually draw instead of the whole atlas
            quads[sheetCounter] =
                love.graphics.newQuad(x * tilewidth, y * tileheight, tilewidth,
                tileheight, atlas:getDimensions())
            sheetCounter = sheetCounter + 1
        end
    end

    return quads
end

-- Pyramids.lua
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
