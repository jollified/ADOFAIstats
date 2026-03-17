local json = require("dkjson")
local inc = 0
local GAME_FOLDER = "C:/Program Files (x86)/Steam/steamapps/common/A Dance Of Fire And Ice"
local FONT_PATH = "godoMaum.ttf"
local FONT_SIZE = 45
local FONT_SIZE_SMALL = 24
local BLUR_RADIUS = 10
local SCROLL_LERP_SPEED = 10
local ROW_FONT_MULTIPLIER = 20
local ROW_CENTER_OFFSET = 200
local ROW_VISIBLE_OFFSET = 1.5

local state = 1
local stb
local levels = {}
local imageCache = {}
local portalImageCache = {}
local font
local fontSmall
local lanterns = {}
local scroll = 0
local scrollto = 0
local rh = 0
local maxScrollRows = 37

-- base resolution for scaling math
local BASE_WIDTH = 1920
local BASE_HEIGHT = 1080
local scaleX, scaleY = 1, 1

-- figures out how stretched things should be
local function updateScale()
    local w, h = love.graphics.getDimensions()
    scaleX = w / BASE_WIDTH
    scaleY = h / BASE_HEIGHT
end

-- helpers for the stretching
local function sx(val) return val * scaleX end
local function sy(val) return val * scaleY end

-- horizontal blur math
local hBlurShader = love.graphics.newShader([[
    uniform vec2 texSize;
    uniform int radius;
    vec4 effect(vec4 color, Image tex, vec2 tc, vec2 sc) {
        float sigma = float(radius) / 2.0;
        float twoSigmaSq = 2.0 * sigma * sigma;
        vec4 result = vec4(0.0);
        float weightSum = 0.0;
        for (int i = -radius; i <= radius; i++) {
            float w = exp(-float(i * i) / twoSigmaSq);
            result += Texel(tex, tc + vec2(float(i) / texSize.x, 0.0)) * w;
            weightSum += w;
        }
        return result / weightSum;
    }
]])

-- vertical blur math
local vBlurShader = love.graphics.newShader([[
    uniform vec2 texSize;
    uniform int radius;
    vec4 effect(vec4 color, Image tex, vec2 tc, vec2 sc) {
        float sigma = float(radius) / 2.0;
        float twoSigmaSq = 2.0 * sigma * sigma;
        vec4 result = vec4(0.0);
        float weightSum = 0.0;
        for (int i = -radius; i <= radius; i++) {
            float w = exp(-float(i * i) / twoSigmaSq);
            result += Texel(tex, tc + vec2(0.0, float(i) / texSize.y)) * w;
            weightSum += w;
        }
        return result / weightSum;
    }
]])

-- makes images fuzzy
local function blurImage(image, radius)
    local w, h = image:getDimensions()
    local c1 = love.graphics.newCanvas(w, h)
    local c2 = love.graphics.newCanvas(w, h)

    love.graphics.setCanvas(c1)
    love.graphics.clear()
    love.graphics.setShader(hBlurShader)
    hBlurShader:send("texSize", { w, h })
    hBlurShader:send("radius", radius)
    love.graphics.draw(image, 0, 0)

    love.graphics.setCanvas(c2)
    love.graphics.clear()
    love.graphics.setShader(vBlurShader)
    vBlurShader:send("texSize", { w, h })
    vBlurShader:send("radius", radius)
    love.graphics.draw(c1, 0, 0)

    love.graphics.setShader()
    love.graphics.setCanvas()
    return love.graphics.newImage(c2:newImageData())
end

-- picks a color based on how good you are
local function crankColor(crank)
    local colors = {
        [0] = { 0.9, 0.1, 0 },
        [1] = { 0.7, 0.3, 0 },
        [2] = { 0.5, 0.5, 0 },
        [3] = { 0.3, 0.7, 0 },
    }
    return unpack(colors[crank] or { 0, 1, 0.5 })
end

-- green if yes red if no
local function okColor(cond)
    if cond then return 0.3, 0.8, 0.8 end
    return 0.9, 0.1, 0
end

-- grabs images from folders
local function loadImage(id, isPortal)
    if isPortal then
        if not portalImageCache[id] then
            portalImageCache[id] = love.graphics.newImage("portals/" .. id .. ".jpg")
        end
        return portalImageCache[id]
    else
        if not imageCache[id] then
            local raw = love.graphics.newImage("BGs/" .. id .. ".jpg")
            imageCache[id] = blurImage(raw, BLUR_RADIUS)
        end
        return imageCache[id]
    end
end

-- all the level names and their codes
local lvlnames = {
    [1]   = { "A Dance of Fire and Ice", "1-X" },
    [2]   = { "Offbeats", "2-X" },
    [3]   = { "THE WIND-UP", "3-X" },
    [4]   = { "Love Letters", "4-X" },
    [5]   = { "The Midnight Train", "5-X" },
    [6]   = { "PULSE", "6-X" },
    [7]   = { "Thanks For Playing My Game", "B-X" },
    [8]   = { "Spin 2 Win", "7-X" },
    [9]   = { "Jungle City", "8-X" },
    [10]  = { "Classic Pursuit", "9-X" },
    [11]  = { "Butterfly City", "10-X" },
    [12]  = { "Heracles", "11-X" },
    [13]  = { "Artificial Chariot", "12-X" },
    [51]  = { "Third Wave Flip-Flop", "XF-X" },
    [52]  = { "One Forgotten Night", "XO-X" },
    [53]  = { "Credits", "XC-X" },
    [54]  = { "Final Hope", "XH-X" },
    [55]  = { "Distance", "PA-X" },
    [56]  = { "Options", "XT-X" },
    [57]  = { "Rose Garden", "XR-X" },
    [59]  = { "Night Wander", "MN-X" },
    [60]  = { "La nuit de vif", "ML-X" },
    [61]  = { "EMOMOMO", "MO-X" },
    [62]  = { "Fear Grows", "RJ-X" },
    [63]  = { "Trans-Neptunian Object", "XN-X" },
    [64]  = { "It Go", "XI-X" },
    [65]  = { "Miko Skip", "XM-X" },
    [66]  = { "Party of Spirits", "XS-X" },
    [67]  = { "Libertas", "AR-X" },
    [102] = { "NEW LIFE", "T1-X" },
    [103] = { "sing sing red indigo", "T2-X" },
    [104] = { "No Hints Here!", "T3-X" },
    [105] = { "Third Sun", "T4-X" },
    [106] = { "Divine Intervention", "T5-X" },
    [112] = { "NEW LIFE", "T1-EX" },
    [113] = { "sing sing red indigo", "T2-EX" },
    [114] = { "No Hints Here!", "T3-EX" },
    [115] = { "Third Sun", "T4-EX" },
}

-- where the lanterns hang
local lanternOffsets = {
    { ox = 2.00,  oy = 1.5 },
    { ox = -2.00, oy = 1.5 },
    { ox = 0.66,  oy = 1.16 },
    { ox = -0.66, oy = 1.16 },
}

-- the four things you can achieve
local lanternFlags = { "cp", "ac", "sp", "ap" }
local lanternConds = {
    cp = function(v) return v.cp == 1 end,
    ac = function(v) return v.ac > 1 end,
    sp = function(v) return v.sp >= 1 end,
    ap = function(v) return v.ap == 1 end,
}

-- makes sure the game is actually there
local function checkInstall()
    local f = io.open(GAME_FOLDER .. "/A Dance of Fire and Ice.exe", "r")
    if not f then
        state = 0
    else
        f:close()
    end
end

-- reads your save file
local function loadSave()
    local f = io.open(GAME_FOLDER .. "/User/data.sav", "r")
    if not f then return end
    local content = f:read("*a")
    f:close()
    local tbl, _, err = json.decode(content, 1, nil)
    if err then
        print("JSON Error:", err)
        return
    end
    stb = tbl
end

-- builds the list of levels with your stats
local function buildLevels()
    if not stb then return end
    local displayIndex = 1
    for i = 1, 120 do
        if lvlnames[i] then
            local id = string.format("%02d", i - 1)
            local cp = stb["percentCompletion" .. id] or 0
            local ac = stb["bestPercentAccuracy" .. id] or 0
            local sp = stb["bestSpeedMultiplier" .. id] or 0
            local ap = stb["bestPercentXAccuracy" .. id] or 0
            local score =
                (cp == 1 and 1 or 0) +
                (ac > 1 and 1 or 0) +
                (sp >= 1 and 1 or 0) +
                (ap == 1 and 1 or 0)
            levels[#levels + 1] = {
                level         = displayIndex,
                originalLevel = i,
                crank         = score,
                cp            = cp,
                ac            = ac,
                sp            = sp,
                ap            = ap,
                img           = loadImage(i, false),
                pimg          = loadImage(i, true),
            }
            displayIndex = displayIndex + 1
        end
    end
end

-- keeps scroll from going too far
local function clampScroll(s)
    return math.max(math.min(s, 0), -rh * maxScrollRows)
end

-- smooth movement between two numbers
local function lerp(a, b, t)
    return a + (b - a) * t
end

local NUM_PUFFS     = 67
local BASE_RADIUS   = 0
local RING_LAYERS   = 5
local LAYER_SPACING = 2
local PUFF_SIZE     = 22
local RING_SPEED    = 0.05

-- draws the floating cloud ring around portals
local function drawCloudRing(cx2, cy2, bw, bh, il)
    local baseRadius = math.min(bw, bh) / 2 + sy(30)
    local squircleN  = 2

    local function mathSign(x)
        if x > 0 then return 1 elseif x < 0 then return -1 else return 0 end
    end

    for layer = 1, RING_LAYERS do
        local layerOffset = (layer - 2) * LAYER_SPACING
        local layerRadius = baseRadius + layerOffset

        for p = 1, NUM_PUFFS do
            local angle = (p / NUM_PUFFS) * math.pi * 2 - inc * RING_SPEED + il * 0.3

            local cosA = math.cos(angle)
            local sinA = math.sin(angle)

            local ox = (bw / 2 + layerRadius - baseRadius) * mathSign(cosA) * math.abs(cosA) ^ (2 / squircleN)
            local oy = (bh / 2 + layerRadius - baseRadius) * mathSign(sinA) * math.abs(sinA) ^ (2 / squircleN)

            local wobble = inc * 1.5 + p * 0.9 + layer * cosA * 2
            local wx = math.sin(wobble) * 5 + math.sin(wobble * 2.3 + p) * 2
            local wy = math.cos(wobble * 0.7) * 4 + math.cos(wobble * 1.9 + p) * 2

            local sizeVar = 1 + 0.5 * math.abs(math.sin(p * 1.618 + layer))
            local thisPuffSize = PUFF_SIZE * sizeVar * math.min(scaleX, scaleY)

            local pw, ph = cloudPuff:getDimensions()
            local scale = (thisPuffSize * 2) / pw
            love.graphics.setColor(0.9, 0.95, 1, 0.25)
            love.graphics.draw(cloudPuff, cx2 + ox + wx, cy2 + oy + wy,
                angle, scale, scale, pw / 2, ph / 2)
        end
    end
end

-- sets everything up
function love.load()
    cloudPuff = love.graphics.newImage("cloud.png")
    chain = love.graphics.newImage("chain.png")
    love.graphics.setDefaultFilter("linear", "linear", 4)
    
    local screenH = select(2, love.window.getDesktopDimensions(1))
    local fontSize = math.floor(FONT_SIZE * (screenH / BASE_HEIGHT))
    local fontSizeSmall = math.floor(FONT_SIZE_SMALL * (screenH / BASE_HEIGHT))
    
    font      = love.graphics.newFont(FONT_PATH, fontSize)
    fontSmall = love.graphics.newFont(FONT_PATH, fontSizeSmall)
    love.graphics.setFont(font)

    for i = 1, 4 do
        lanterns[i] = love.graphics.newImage("lanterns/" .. i .. ".png")
    end

    checkInstall()
    loadSave()
    buildLevels()

    -- figures out how big the window should be
    local maxWidth = 0
    for _, v in ipairs(levels) do
        local iw, ih = v.img:getDimensions()
        local targetH = font:getHeight() * 10 * 0.9
        local w = iw * (targetH / ih) + sx(600)
        if w > maxWidth then maxWidth = w end
    end
    
    local desktopW, desktopH = love.window.getDesktopDimensions(1)
    local windowW = math.min(math.max(maxWidth, sx(1000)), desktopW)
    local windowH = math.min(sy(1000), desktopH)
    
    love.window.setMode(windowW, windowH, {resizable = true})
    updateScale()
end

-- handles window resizing
function love.resize(w, h)
    updateScale()
    local newFontSize = math.floor(FONT_SIZE * scaleY)
    local newFontSizeSmall = math.floor(FONT_SIZE_SMALL * scaleY)
    font = love.graphics.newFont(FONT_PATH, newFontSize)
    fontSmall = love.graphics.newFont(FONT_PATH, newFontSizeSmall)
end

-- mouse wheel scrolling
function love.wheelmoved(_, y)
    local step = rh
    scrollto = clampScroll(scrollto + (y > 0 and step or -step))
end

-- keyboard controls
function love.keypressed(key)
    if key == "escape" then
        love.event.quit()
    elseif key == "up" then
        scrollto = clampScroll(scrollto + rh)
    elseif key == "down" then
        scrollto = clampScroll(scrollto - rh)
    end
end

-- updates scroll position smoothly
function love.update(dt)
    scroll = lerp(scroll, scrollto, dt * SCROLL_LERP_SPEED)
    scroll = clampScroll(scroll)
end

-- draws the achievement lanterns
local function drawLanterns(v, bx, by, bw, bh, o)
    for i, key in ipairs(lanternFlags) do
        if lanternConds[key](v) then
            local loff = lanternOffsets[i]
            local lw, lh = lanterns[i]:getDimensions()
            local lscale = math.min(bw / lw / 3, bh / lh / 3)
            local lox = (lw - bw / lscale) / 2 + loff.ox * lw
            local loy = (lh - bh / lscale) / 2 + loff.oy * lh
            love.graphics.setColor(1, 1, 1, 1)
            local rot = math.sin((inc + o + i) * 1.5) * 0.2
            if i == 1 or i == 4 then
                rot = -rot
            end
            love.graphics.draw(lanterns[i], bx - lox, by - loy, rot, lscale, lscale, lw / 2, 0)
        end
    end
end

-- draws everything on screen
function love.draw()
    inc = inc + 0.01
    love.graphics.setFont(font)
    local fh               = font:getHeight()
    local rowHeight        = fh * ROW_FONT_MULTIPLIER
    local padding          = fh * 1.2
    local screenW, screenH = love.graphics.getDimensions()

    -- error screen if game not found
    if state ~= 1 then
        love.graphics.printf(
            "Please ensure ADOFAI is installed in the\n default steam installation location. (C:/ drive)",
            0, sy(215), screenW, "center"
        )
        return
    end

    rh           = rowHeight
    local wd, ht = love.graphics.getDimensions()

    -- math for which rows to show
    local rowPos = -(scroll - screenH / 2) / rowHeight - (9 / 17)
    local base   = math.floor(rowPos)
    local frac   = rowPos - base

    love.graphics.print(math.floor(rowPos + 1.1), sx(10), 0)

    -- background images that fade between levels
    for i = 1, 2 do
        local lvl = levels[base + i]
        if lvl then
            local iw, ih = lvl.img:getDimensions()
            local scale  = math.max(screenW / iw, screenH / ih)
            love.graphics.setColor(1, 1, 1, (i == 1 and 1 - frac or frac) * 0.5)
            love.graphics.draw(lvl.img, screenW / 2, screenH / 2, 0, scale, scale, iw / 2, ih / 2)
        end
    end

    -- purple glow effect in middle
    love.graphics.setBlendMode("add")
    love.graphics.setColor(0.7, 0.2, 0.7, 0.1)
    love.graphics.rectangle("fill", wd / 2 - wd / 4, -sy(1000), wd / 2, sy(100000))
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setBlendMode("alpha")
    love.graphics.rectangle("fill", wd / 2 + wd / 4 - sx(5), -scroll / 36, sx(10), ht / 36)

    -- draws each level row
    local skipped = 0
    for il, v in ipairs(levels) do
        if v.ap == 0 then
            skipped = skipped + 1
        else
            local visualRow = v.level - skipped
            local y         = rowHeight * visualRow - fh - sy(20) + scroll - rowHeight / ROW_VISIBLE_OFFSET -
                sy(ROW_CENTER_OFFSET)
            local name      = lvlnames[v.originalLevel]
            local gap       = font:getWidth("   ")

            -- level name and rank
            love.graphics.setColor(crankColor(v.crank))
            love.graphics.printf(name[2] .. " " .. name[1] .. " | Completion Rank: " .. v.crank .. "/4", 0, y + sy(20),
                screenW, "center")

            -- completion and accuracy stats
            local completeText = string.format("%.2f%% Complete", v.cp * 100)
            local accuracyText = string.format("Accuracy: %.2f%%", v.ac * 100)
            local cw           = font:getWidth(completeText)
            local aw           = font:getWidth(accuracyText)
            local line2X       = (screenW - cw - gap - aw) / 2
            love.graphics.setColor(okColor(v.cp >= 1))
            love.graphics.print(completeText, line2X, y + sy(20) + fh)
            love.graphics.setColor(okColor(v.ac >= 1))
            love.graphics.print(accuracyText, line2X + cw + gap, y + sy(20) + fh)

            -- speed and xaccuracy stats
            local speedText = string.format("%.2fx Speed", v.sp)
            local apText    = string.format("XAccuracy: %.2f%%", v.ap * 100)
            local sw        = font:getWidth(speedText)
            local pw        = font:getWidth(apText)
            local line3X    = (screenW - sw - gap - pw) / 2
            love.graphics.setColor(okColor(v.sp >= 1))
            love.graphics.print(speedText, line3X, y + sy(20) + fh * 2)
            love.graphics.setColor(okColor(v.ap == 1))
            love.graphics.print(apText, line3X + sw + gap, y + sy(20) + fh * 2)

            -- portal image box
            local bx     = (wd / 2 - wd / 5) * 1.33333
            local by     = y + rh / 2.5
            local bw     = wd / (8 / 1.5)
            local bh     = rh / (3.5 / 1.5)
            local radius = sy(10000)

            love.graphics.stencil(function()
                love.graphics.rectangle("fill", bx, by, bw, bh, radius, radius)
            end, "replace", 1)
            love.graphics.setStencilTest("greater", 0)

            local iw, ih = v.pimg:getDimensions()
            local scale  = math.max(bw / iw, bh / ih)
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.draw(v.pimg, bx - (iw * scale - bw) / 2, by - (ih * scale - bh) / 2, 0, scale, scale)

            love.graphics.setStencilTest()

            -- clouds and lanterns around portal
            local cx2 = bx + bw / 2
            local cy2 = by + bh / 2
            drawCloudRing(cx2, cy2, bw, bh, il)

            drawLanterns(v, bx, by, bw, bh, il)
            
            -- chain above portal
            local chainW = chain:getWidth() * (rh / chain:getHeight() / 4)
            local chainX = bx + bw/2
            local chainScale = rh / chain:getHeight() / 5
            local chainH = chain:getHeight() * chainScale
            love.graphics.draw(chain, chainX, by - chainH - sy(25), 0, chainScale, chainScale, chain:getWidth()/2, 0)
            love.graphics.printf("World " .. name[2], -sy(15), sy(232) + y, screenW, "center")
        end
    end

    -- footer text
    love.graphics.setColor(1, 1, 1)
    love.graphics.setFont(fontSmall)
    love.graphics.printf("jollified  ADOFAI stats v3", 0, 0, screenW, "center")
    love.graphics.print("ESC to exit \nscroll or use arrow keys to see other levels", sx(10), screenH - sy(60))
    love.graphics.setFont(font)
end