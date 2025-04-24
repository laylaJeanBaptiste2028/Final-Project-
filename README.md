# Final-Project


WINDOW_WIDTH = 1280
WINDOW_HEIGHT = 72

VIRTUAL_WIDTH = 432
VIRTUAL_HEIGHT = 243

Class = require 'class'
push = require 'push'

require 'Map'
function love.load()
 map = Map()
end 

function love.update(dt)

end

function love.draw()
map:render()
end
