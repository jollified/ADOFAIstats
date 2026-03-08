local json = require("dkjson")

local gamefolder = "C:/Program Files (x86)/Steam/steamapps/common/A Dance Of Fire And Ice"

local state = 1
local stb
local levels = {}
local images = {}
local portalimages = {}

local scroll = 0
local scrollto = 0
local fontsize = 45
local rh = 0
local font
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
            vec2 offset = vec2(float(i) / texSize.x, 0.0);
            result += Texel(tex, tc + offset) * w;
            weightSum += w;
        }
        return result / weightSum;
    }
]])

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
            vec2 offset = vec2(0.0, float(i) / texSize.y);
            result += Texel(tex, tc + offset) * w;
            weightSum += w;
        }
        return result / weightSum;
    }
]])

--- Returns a blurred Image using GPU shaders (much faster than CPU).
--- @param image  love.Image  -- a standard Image object
--- @param radius number      -- blur radius in pixels (e.g. 2–20)
--- @return love.Image
function blurImage(image, radius)
    local width   = image:getWidth()
    local height  = image:getHeight()

    local canvas1 = love.graphics.newCanvas(width, height)
    local canvas2 = love.graphics.newCanvas(width, height)

    -- Horizontal pass: image -> canvas1
    love.graphics.setCanvas(canvas1)
    love.graphics.clear()
    love.graphics.setShader(hBlurShader)
    hBlurShader:send("texSize", { width, height })
    hBlurShader:send("radius", radius)
    love.graphics.draw(image, 0, 0)

    -- Vertical pass: canvas1 -> canvas2
    love.graphics.setCanvas(canvas2)
    love.graphics.clear()
    love.graphics.setShader(vBlurShader)
    vBlurShader:send("texSize", { width, height })
    vBlurShader:send("radius", radius)
    love.graphics.draw(canvas1, 0, 0)

    -- Restore default state
    love.graphics.setShader()
    love.graphics.setCanvas()

    -- Capture canvas2 as a new Image
    local imageData = canvas2:newImageData()
    return love.graphics.newImage(imageData)
end

-- Color helpers
local function crankColor(crank)
    if crank == 3 then
        return 0.3, 0.7, 0
    elseif crank == 2 then
        return 0.5, 0.5, 0
    elseif crank == 1 then
        return 0.7, 0.3, 0
    elseif crank == 0 then
        return 0.9, 0.1, 0
    end
    return 0, 1, 0.5
end

local function okColor(cond)
    if cond then
        return 0.3, 0.8, 0.8
    end
    return 0.9, 0.1, 0
end

-- Image loader with caching
local function loadImage(id, v)
    local img
    if v == 1 then
        if not images[id] then
            img = love.graphics.newImage("BGs/" .. id .. ".jpg")
            images[id] = blurImage(img, 10)
        end
        return images[id]
    else
        if not portalimages[id] then
            img = love.graphics.newImage("portals/" .. id .. ".jpg")
            portalimages[id] = img
        end
        return portalimages[id]
    end
end

-- Level names table
local lvlnames = {
    [1] = { "A Dance of Fire and Ice", "1-X" },
    [2] = { "Offbeats", "2-X" },
    [3] = { "THE WIND-UP", "3-X" },
    [4] = { "Love Letters", "4-X" },
    [5] = { "The Midnight Train", "5-X" },
    [6] = { "PULSE", "6-X" },
    [7] = { "Thanks For Playing My Game", "B-X" },
    [8] = { "Spin 2 Win", "7-X" },
    [9] = { "Jungle City", "8-X" },
    [10] = { "Classic Pursuit", "9-X" },
    [11] = { "Butterfly City", "10-X" },
    [12] = { "Heracles", "11-X" },
    [13] = { "Artificial Chariot", "12-X" },
    [51] = { "Third Wave Flip-Flop", "XF-X" },
    [52] = { "One Forgotten Night", "XO-X" },
    [53] = { "Credits", "XC-X" },
    [54] = { "Final Hope", "XH-X" },
    [55] = { "Distance", "PA-X" },
    [56] = { "Options", "XT-X" },
    [57] = { "Rose Garden", "XR-X" },
    [59] = { "Night Wander", "MN-X" },
    [60] = { "La nuit de vif", "ML-X" },
    [61] = { "EMOMOMO", "MO-X" },
    [62] = { "Fear Grows", "RJ-X" },
    [63] = { "Trans-Neptunian Object", "XN-X" },
    [64] = { "It Go", "XI-X" },
    [65] = { "Miko Skip", "XM-X" },
    [66] = { "Party of Spirits", "XS-X" },
    [67] = { "Libertas", "AR-X" },
    [102] = { "NEW LIFE", "T1-X" },
    [103] = { "sing sing red indigo", "T2-X" },
    [104] = { "No Hints Here!", "T3-X" },
    [105] = { "Third Sun", "T4-X" },
    [106] = { "Divine Intervention", "T5-X" },
    [112] = { "NEW LIFE", "T1-EX" },
    [113] = { "sing sing red indigo", "T2-EX" },
    [114] = { "No Hints Here!", "T3-EX" },
    [115] = { "Third Sun", "T4-EX" }
}

-- Check if game is installed
local function checkInstall()
    local test = io.open(gamefolder .. "/A Dance of Fire and Ice.exe", "r")
    if not test then
        state = 0
    else
        test:close()
    end
end

-- Load saved stats
local function loadSave()
    local file = io.open(gamefolder .. "/User/data.sav", "r")
    if not file then return end

    local content = file:read("*a")
    file:close()

    local tbl, _, err = json.decode(content, 1, nil)
    if err then
        print("JSON Error:", err)
        return
    end

    stb = tbl
end

-- Build compacted levels list
local function buildLevels()
    if not stb then return end

    local displayIndex = 1
    for i = 1, 120 do
        local name = lvlnames[i]
        if name then
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

            local image = loadImage(i, 1)
            local portalimage = loadImage(i, 2)

            levels[#levels + 1] = {
                level = displayIndex, -- sequential visual row
                originalLevel = i,    -- original index for text
                crank = score,
                cp = cp,
                ac = ac,
                sp = sp,
                ap = ap,
                img = image,
                pimg = portalimage
            }

            displayIndex = displayIndex + 1
        end
    end
end

-- Linear interpolation for smooth scrolling
local function lerp(a, b, t)
    return a + (b - a) * t
end

-- LOVE2D callbacks
function love.load()
    love.graphics.setDefaultFilter("linear", "linear", 4)
    font = love.graphics.newFont("godoMaum.ttf", fontsize)
    love.graphics.setFont(font)

    checkInstall()
    loadSave()
    buildLevels()

    -- Set window width dynamically
    local maxWidth = 1920
    for _, v in ipairs(levels) do
        local imgW, imgH = v.img:getDimensions()
        local targetHeight = font:getHeight() * 10 * 0.9
        local scale = targetHeight / imgH
        local w = imgW * scale + 600
        if w > maxWidth then maxWidth = w end
    end
    love.window.setMode(maxWidth, 1080)
end

function love.wheelmoved(_, y)
    if y > 0 then
        scrollto = rh + scrollto
    else
        scrollto = scrollto - rh
    end
end

function love.keypressed(key)
    if key == "escape" then
        love.event.quit()
    elseif key == "up" then
        scrollto = rh + scrollto
    elseif key == "down" then
        scrollto = scrollto - rh
    end
end

function love.update(dt)
    scroll = lerp(scroll, scrollto, dt * 10)
    scroll = math.max(scroll, -rh * 37)
    scroll = math.min(scroll, 0)
    if scrollto > 0 then
        scrollto = 0
    elseif scrollto < -rh * 37 then
        scrollto = -rh * 37
    end
end

function love.draw()
    font = love.graphics.newFont("godoMaum.ttf", fontsize)
    love.graphics.setFont(font)
    local fh = font:getHeight()
    local rowHeight = fh * 20
    local padding = fh * 1.2
    local screenW, screenH = love.graphics.getDimensions()
    if state ~= 1 then
        love.graphics.printf(
            "Please ensure ADOFAI is installed in the\n default steam installation location. (C:/ drive)",
            0, 215, screenW, "center"
        )
        return
    end

    local centerY = screenH / 2
    local rowPos = -(scroll - centerY) / rowHeight - 0.52941176470588
    local base = math.floor(rowPos)
    local frac = rowPos - base
    love.graphics.print(math.floor(rowPos + 1.1), 10, 0)
    -- Draw current and next image
    for i = 1, 2 do
        local lvl = levels[base + i]
        if lvl then
            local img = lvl.img
            local iw, ih = img:getDimensions()
            local scale = math.max(screenW / iw, screenH / ih)
            love.graphics.setColor(1, 1, 1, (i == 1 and 1 - frac or frac) * 0.5)
            love.graphics.draw(img, screenW / 2, screenH / 2, 0, scale, scale, iw / 2, ih / 2)
        end
    end
    local offset = 20
    rh = rowHeight
    local wd = love.graphics.getWidth()
    local ht = love.graphics.getHeight()
    -- Draw foreground
    love.graphics.setBlendMode("add")
    love.graphics.setColor(0.7, 0.2, 0.7, 0.1)
    love.graphics.rectangle("fill", wd / 2 - wd / 4, -1000, wd / 2, 100000)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setBlendMode("alpha")
    love.graphics.rectangle("fill", wd / 2 + wd / 4 - 5, -scroll / 36, 10, ht / 36)
    -- Draw stats

    for _, v in ipairs(levels) do
        local y = (rowHeight * v.level) - fh - offset + scroll - rowHeight / 1.5 - 200
        if not (v.ap == 0) then
            local name = lvlnames[v.originalLevel]
            local gap = font:getWidth("   ")

            -- Line 1: level name and rank (centered)
            local text = name[2] .. " " .. name[1] .. " | Completion Rank: " .. v.crank .. "/4"
            love.graphics.setColor(crankColor(v.crank))
            love.graphics.printf(text, 0, y + offset, screenW, "center")

            -- Line 2: Complete % and Accuracy (centered as a pair)
            local completeText = string.format("%.2f%% Complete", v.cp * 100)
            local accuracyText = string.format("Accuracy: %.2f%%", v.ac * 100)
            local completeWidth = font:getWidth(completeText)
            local accuracyWidth = font:getWidth(accuracyText)
            local line2TotalWidth = completeWidth + gap + accuracyWidth
            local line2StartX = (screenW - line2TotalWidth) / 2
            love.graphics.setColor(okColor(v.cp >= 1))
            love.graphics.print(completeText, line2StartX, y + offset + fh)
            love.graphics.setColor(okColor(v.ac >= 1))
            love.graphics.print(accuracyText, line2StartX + completeWidth + gap, y + offset + fh)

            -- Line 3: Speed and XAccuracy (centered as a pair)
            local speedText = string.format("%.2fx Speed", v.sp)
            local apText = string.format("XAccuracy: %.2f%%", v.ap * 100)
            local speedWidth = font:getWidth(speedText)
            local apWidth = font:getWidth(apText)
            local line3TotalWidth = speedWidth + gap + apWidth
            local line3StartX = (screenW - line3TotalWidth) / 2
            love.graphics.setColor(okColor(v.sp >= 1))
            love.graphics.print(speedText, line3StartX, y + offset + fh * 2)
            love.graphics.setColor(okColor(v.ap == 1))
            love.graphics.print(apText, line3StartX + speedWidth + gap, y + offset + fh * 2)

            --line 4: images
            local bx, by, bw, bh = wd / 2 - wd / 5, y + rh / 4, wd / (8 / 1.5), rh / (3.5 / 1.5)
            local radius = 10000 -- adjust this for more/less rounding

            local function sfunc()
                love.graphics.rectangle("fill", bx, by, bw, bh, radius, radius)
            end

            love.graphics.stencil(sfunc, "replace", 1)
            love.graphics.setStencilTest("greater", 0)


            -- Scale image to fit the box
            local iw, ih = v.pimg:getDimensions()
            local scale = math.max(bw / iw, bh / ih) -- "cover" fit
            local ox = (iw * scale - bw) / 2 -- center crop X (was missing / 2)
            local oy = (ih * scale - bh) / 2 -- center crop Y (was missing / 2)

            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.draw(v.pimg, bx - ox, by - oy, 0, scale, scale)

            love.graphics.setStencilTest()
            love.graphics.setColor(1, 1, 1, 1) -- adjust color/alpha as you like
            love.graphics.setLineWidth(5)      -- adjust thickness
            love.graphics.rectangle("line", bx, by, bw, bh, radius, radius)
            love.graphics.setLineWidth(1)      -- reset to default
        else
            offset = offset - rowHeight
        end
    end

    love.graphics.setColor(1, 1, 1)
    font = love.graphics.newFont("godoMaum.ttf", 24)
    love.graphics.setFont(font)
    love.graphics.printf("jollified  ADOFAI stats v2", 0, 0, screenW, "center")
    love.graphics.print("ESC to exit \nscroll or use arrow keys to see other levels", 10,1020)
end
