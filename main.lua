-- GLOBAL VARIABLES

-- game configuration

local tiles_y, tiles_x, num_mines
local text_colours = {
    {0, 0, 1},
    {0, 0.8, 0},
    {1, 0, 0},
    {0, 0.8, 0.8},
    {1, 0, 1},
    {0.8, 0.8, 0},
    {0, 0, 0},
    {0.8, 0.8, 0.8}
}

local diffs = {
    easy = { 9, 9, 10 },
    medium = { 16, 16, 40 },
    hard = { 16, 30, 99 }
}

local cur_diff, seed
local num_flags_left, num_tiles_left

-- window configuration
local tile_size = 40
local inner_scale = 0.9
local tile_offset_y = 1
local tile_offset_x = 0

local inner_size = tile_size * inner_scale
local middle = (inner_scale + 1) / 2

local screen_tiles_y, screen_tiles_x
local screen_y, screen_x

-- game state
local tiles = {}
local mines_pos = {}
local game_over = false
local game_started = false
local timer = 0

-- HELPER FUNCTIONS

-- get the adjacent positions of (y, x), which is a 3x3 grid
local function get_neighbours(y, x)
    local neighbours = {}
    for i = y-1, y+1 do
        for j = x-1, x+1 do
            if not (i == y and j == x)
            and i >= 1 and j >= 1
            and i <= tiles_y and j <= tiles_x then
                table.insert(neighbours, {i, j})
            end
        end
    end
    return neighbours
end

local function create_tiles()
    for i = 1, tiles_y do
        tiles[i] = {}
        for j = 1, tiles_x do
            tiles[i][j] = {
                adj_mines = 0,
                is_mine = false,
                exploded = false,
                hidden = true,
                flagged = false
            }
        end
    end
end

-- randomly spawn num_mines amount of mines
-- places a safe zone at (y, x) for the player's first click
local function create_mines(y, x)
    local indices = {}
    -- get all tile positions, minus a 3x3 area around (y, x)
    for i = 1, tiles_y do
        for j = 1, tiles_x do
            if not (i >= y-1 and i <= y+1 and j >= x-1 and j <= x+1) then
                table.insert(indices, {i, j})
            end
        end
    end
    -- fisher-yates shuffle algorithm
    for i = #indices, 2, -1 do
        local j = math.random(i)
        indices[i], indices[j] = indices[j], indices[i]
    end
    -- select the mine positions and store them,
    -- while updating the tiles
    for i = 1, num_mines do
        local idx = indices[i]
        tiles[idx[1]][idx[2]].is_mine = true
        table.insert(mines_pos, idx)
    end
    -- compute the number of adjacent mines at each tile
    for _, pos in ipairs(mines_pos) do
        local adj = get_neighbours(pos[1], pos[2])
        for _, pos1 in ipairs(adj) do
            local tile = tiles[pos1[1]][pos1[2]]
            tile.adj_mines = tile.adj_mines + 1
        end
    end
end

-- flood-fill algorithm to reveal all tiles
local function reveal_flood(y, x)
    local stack = {{y, x}}
    while #stack > 0 do
        local cur = table.remove(stack)
        local tile = tiles[cur[1]][cur[2]]
        if not tile.hidden or tile.flagged then
            goto continue
        end
        tile.hidden = false
        if tile.is_mine then
            game_over = true
            tile.exploded = true
            goto continue
        end
        num_tiles_left = num_tiles_left - 1
        if tile.adj_mines > 0 then
            goto continue
        end
        local neighbours = get_neighbours(cur[1], cur[2])
        for _, pos in ipairs(neighbours) do
            table.insert(stack, pos)
        end
        ::continue::
    end
end

-- if the player hit a mine (bad), then reveal all other mines
-- if the player cleared all mines (good), then flag all other mines
local function do_game_over()
    for _, pos in ipairs(mines_pos) do
        local tile = tiles[pos[1]][pos[2]]
        if game_over and not tile.flagged then
            tile.hidden = false
        else
            tile.flagged = true
        end
    end
    game_over = true
end

local function restart_game(diff)
    -- generate random seed for mine placement
    -- NOTE: press the S key to print the current seed to the console.
    -- you can override the randomly generated seed here
    -- an example seed is commented out below
    seed = math.random(-2^63, 2^63 - 1)
    -- seed = 123456789
    math.randomseed(seed)

    tiles_y, tiles_x, num_mines = table.unpack(diff)

    tiles = {}
    mines_pos = {}
    game_over = false
    game_started = false
    timer = 0

    screen_tiles_y = tiles_y+tile_offset_y
    screen_tiles_x = tiles_x+tile_offset_x*2
    screen_y = screen_tiles_y * tile_size
    screen_x = screen_tiles_x * tile_size

    if cur_diff ~= diff then
        love.window.setMode(screen_x, screen_y)
    end
    cur_diff = diff

    num_flags_left = num_mines
    num_tiles_left = tiles_y * tiles_x

    create_tiles()
end

-- MAIN FUNCTIONS

function love.load()
    math.randomseed(os.time())
    love.window.setTitle("Scuffed Minesweeper")
    local font = love.graphics.newFont(inner_size)
    love.graphics.setFont(font)
    love.graphics.setBackgroundColor(0.2 ,0.2 ,0.2)
    restart_game(diffs.easy)
end

function love.update(dt)
    -- update timer
    if game_started and not game_over then
        timer = timer + dt
    end
end

function love.keypressed(key)
    if key == "1" then
        restart_game(diffs.easy)
    elseif key == "2" then
        restart_game(diffs.medium)
    elseif key == "3" then
        restart_game(diffs.hard)
    elseif key == "s" then
        print("Seed: "..string.format("%.0f", seed))
    elseif key == "escape" then
        love.event.quit()
    end
end

function love.mousepressed(x, y, button)
    -- get the mouse coordinates in terms of tiles, rather than pixels
    local rel_y = math.ceil(y/screen_y*screen_tiles_y) - tile_offset_y
    local rel_x = math.ceil(x/screen_x*screen_tiles_x) - tile_offset_x
    -- restart game by clicking the smiley face
    if rel_y < 1 and x >= screen_x/2 - tile_size/2 and x <= screen_x/2 + tile_size/2 then
        restart_game(cur_diff)
    end
    -- range check
    if rel_y < 1 or rel_x < 1 or rel_y > tiles_y or rel_x > tiles_x or game_over then
        return
    end
    local tile = tiles[rel_y][rel_x]
    -- left click to "reveal" a tile
    if button == 1 and tile.hidden and not tile.flagged then
        -- generate the mines if this is the first click
        if not game_started then
            create_mines(rel_y, rel_x)
            game_started = true
        end
        -- reveal current tile (and possibly more, if tile is blank)
        reveal_flood(rel_y, rel_x)
        if game_over or num_tiles_left == num_mines then
            do_game_over()
        end
    -- right click to "flag" a tile
    elseif button == 2 and tile.hidden then
        if tile.flagged == true then
            tile.flagged = false
            num_flags_left = num_flags_left + 1
        else
            tile.flagged = true
            num_flags_left = num_flags_left - 1
        end
    -- middle click to "chord" on a numbered tile
    elseif button == 3 then
        if not tile.hidden and tile.adj_mines > 0 then
            local adj = get_neighbours(rel_y, rel_x)
            local count = 0
            -- count the number of adjacent flags
            for _, pos in ipairs(adj) do
                if tiles[pos[1]][pos[2]].flagged then
                    count = count + 1
                end
            end
            -- if the count matches the number then reveal all surrounding tiles
            if count == tile.adj_mines then
                for _, pos in ipairs(adj) do
                    reveal_flood(pos[1], pos[2])
                end
                if game_over or num_tiles_left == num_mines then
                    do_game_over()
                end
            end
        end
    end
end

function love.draw()
    local font = love.graphics.getFont()
    local text = love.graphics.newText(font, "")
    -- draw timer and flag count
    love.graphics.setColor(1, 1, 1)
    text:set({{1, 1, 1}, num_flags_left})
    -- local flag_str = love.graphics.newText(font, {{1, 1, 1}, num_flags_left})
    love.graphics.draw(text, 0, 0)
    local timer_str = math.floor(timer)
    text:set({{1, 1, 1}, timer_str})
    love.graphics.draw(text, screen_x-font:getWidth(timer_str),0)
    -- draw smiley face
    local smiley = ""
    if num_tiles_left == num_mines then
        smiley = ":-D"
    elseif game_over then
        smiley = ":-("
    else
        smiley = ":-)"
    end
    text:set({{1, 1, 1}, smiley})
    love.graphics.draw(text, screen_x/2-font:getWidth(smiley)+tile_size/2,0)
    -- draw tiles
    for i = 1, tiles_y do
        for j = 1, tiles_x do
            local tile = tiles[i][j]
            -- tile is hidden
            if tile.hidden then
                if tile.flagged and game_over and not tile.is_mine then
                    love.graphics.setColor(0.4, 0.4, 0.4)
                else
                    love.graphics.setColor(0.6, 0.6, 0.6)
                end
                love.graphics.rectangle("fill", (j+tile_offset_x-middle)*tile_size, (i+tile_offset_y-middle)*tile_size, inner_size, inner_size)
                if tile.flagged then
                    love.graphics.setColor(0.2, 0.2, 0.2)
                    love.graphics.rectangle("fill", (j+tile_offset_x-middle+0.5/2)*tile_size, (i+tile_offset_y-middle+0.5/2)*tile_size, inner_size*0.1, inner_size*0.6)
                    love.graphics.setColor(1, 0, 0)
                    if game_over and not tile.is_mine then
                        love.graphics.setColor(0.2, 0.2, 0.2)
                    end
                    love.graphics.rectangle("fill", (j+tile_offset_x-middle+0.5/2)*tile_size, (i+tile_offset_y-middle+0.2)*tile_size, inner_size*0.5, inner_size*0.3)
                end
            -- tile is a mine
            elseif tile.is_mine then
                if tile.exploded then
                    love.graphics.setColor(1, 0, 0)
                else
                    love.graphics.setColor(0.4, 0.4, 0.4)
                end
                love.graphics.rectangle("fill", (j+tile_offset_x-middle)*tile_size, (i+tile_offset_y-middle)*tile_size, inner_size, inner_size)
                love.graphics.setColor(0, 0, 0)
                love.graphics.circle("fill", (j+tile_offset_x-middle/2)*tile_size, (i+tile_offset_y-middle/2)*tile_size, (inner_size*0.8)/2)
            else
                love.graphics.setColor(0.4, 0.4, 0.4)
                love.graphics.rectangle("fill", (j+tile_offset_x-middle)*tile_size, (i+tile_offset_y-middle)*tile_size, inner_size, inner_size)
                love.graphics.setColor(1, 1, 1)
                local text_str = tile.adj_mines
                if text_str ~= 0 then
                    text:set({text_colours[text_str], text_str})
                    local align_x = font:getWidth(text_str) / inner_size
                    love.graphics.draw(text, (j+tile_offset_x-middle+align_x/4)*tile_size, (i+tile_offset_y-middle-0.05)*tile_size)
                end
            end
        end
    end
end