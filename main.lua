local json = require("dkjson")
state = 1
--- MODIFY GAMEFOLDER HERE ---
gamefolder = "C:/Program Files (x86)/Steam/steamapps/common/A Dance Of Fire And Ice"
--gamefolder = "D:/SteamLibrary/steamapps/common/A Dance of Fire and Ice"
--- 

if not io.open(gamefolder .. "/A Dance of Fire and Ice.exe", "r") then
    state = 0
end


local file = io.open(gamefolder .. "/User/data.sav", "r")
local stb


local function crankColor(crank)
    if crank == 3 then return 0.3,0.7,0
    elseif crank == 2 then return 0.5,0.5,0
    elseif crank == 1 then return 0.7,0.3,0
    elseif crank == 0 then return 0.9,0.1,0
    end
    return 0,1,0.5
end

local button = {
    x = 200,
    y = 200,
    w = 200,
    h = 50,
    text = "select folder"
}

local function okColor(cond)
    if cond then
        return 0.3,0.8,0.8
    else
        return 0.9,0.1,0
    end
end

function love.load()
    love.window.setMode(500,500)
end

if file then
    local content = file:read("*a")
    local tbl, pos, err = json.decode(content, 1, nil)

    if not err then
        stb = tbl
    else
        print("JSON Error:", err)
    end

    file:close()
end

local lvlnames = {
    [1] = {"A Dance of Fire and Ice","1-X"},
    [2] = {"Offbeats","2-X"},
    [3] = {"THE WIND-UP","3-X"},
    [4] = {"Love Letters","4-X"},
    [5] = {"The Midnight Train","5-X"},
    [6] = {"PULSE","6-X"},
    [7] = {"Thanks For Playing My Game","B-X"},
    [8] = {"Spin 2 Win","7-X"},
    [9] = {"Jungle City","8-X"},
    [10] = {"Classic Pursuit","9-X"},
    [11] = {"Butterfly City","10-X"},
    [12] = {"Heracles","11-X"},
    [13] = {"Artificial Chariot","12-X"},
    [51] = {"Third Wave Flip-Flop","XF-X"},
    [52] = {"One Forgotten Night", "XO-X"},
    [53] = {"Credits", "XC-X"},
    [54] = {"Final Hope", "XH-X"},
    [55] = {"Distance", "PA-X"},
    [56] = {"Options", "XT-X"},
    [57] = {"Rose Garden", "XR-X"},
    [59] = {"Night Wander", "MN-X"},
    [60] = {"La nuit de vif", "ML-X"},
    [61] = {"EMOMOMO", "MO-X"},
    [62] = {"Fear Grows", "RJ-X"},
    [63] = {"Trans-Neptunian Object", "XN-X"},
    [64] = {"It Go", "XI-X"},
    [65] = {"Miko Skip", "XM-X"},
    [66] = {"Party of Spirits", "XS-X"},
    [67] = {"Libertas", "AR-X"},
    [102]= {"NEW LIFE", "T1-X"},
    [103]= {"sing sing red indigo", "T2-X"},
    [104]= {"No Hints Here!", "T3-X"},
    [105]= {"Third Sun", "T4-X"},
    [106]= {"Divine Intervention", "T5-X"},
    [112]= {"NEW LIFE", "T1-EX"},
    [113]= {"sing sing red indigo", "T2-EX"},
    [114]= {"No Hints Here!", "T3-EX"},
    [115]= {"Third Sun", "T4-EX"}
}

local levels = {}

if stb then
    for i = 0, 120 do
        local id = string.format("%02d", i)

        local cp = stb["percentCompletion"..id] or 0
        local ac = stb["bestPercentAccuracy"..id] or 0
        local sp = stb["bestSpeedMultiplier"..id] or 0
        local ap = stb["isHighestPossibleAcc"..id] or false

        local clear = cp == 1 and 1 or 0
        local accuracy = ac > 1 and 1 or 0
        local speed = sp >= 1 and 1 or 0
        local allperfect = ap and 1 or 0

        local score = clear + accuracy + speed + allperfect

        levels[#levels+1] = {
            level = i + 1,
            crank = score,
            cp = cp,
            ac = ac,
            sp = sp,
            ap = ap
        }
    end
end

local scroll = 0
local scrollvel = 0

function love.wheelmoved(mx, my)
    scrollvel = scrollvel + my * 2
end

function love.update(dt)
    scroll = math.min(scroll + scrollvel, 0)
    scrollvel = scrollvel / 1.05
end
function love.draw()
    if state == 1 then
        local offset = 20
        love.graphics.setColor(1,1,1)
        love.graphics.print("jollified | ADOFAI stats v1", 5,scroll+offset, 0, 1, 1)

        for _, v in ipairs(levels) do
            local y = 50 * v.level - 20 + scroll
            local name = lvlnames[v.level] or {v.level .. "-X","nil"}

            love.graphics.setColor(0,0,0)

            if v.crank == 0 and v.ac == 0 then
                offset = offset - 50
                goto continue
            end

            if v.crank == 4 then
                love.graphics.setColor(0.05,0.1,0.05)
            end

            love.graphics.rectangle("fill", 0,y+offset, 1000, 45)

            love.graphics.setColor(crankColor(v.crank))
            love.graphics.print(name[2] .." "..name[1] .. " |  Completion Rank: "..v.crank.."/4", 5, y+offset)

            love.graphics.setColor(okColor(v.cp >= 1))
            love.graphics.print(v.cp * 100 .. "% complete", 5, y+offset + 15)

            love.graphics.setColor(okColor(v.ac > 1))
            love.graphics.print("accuracy: "..(v.ac * 100).."%", 140, y+offset + 15)

            love.graphics.setColor(okColor(v.sp >= 1))
            love.graphics.print(string.sub(tostring(v.sp),1,4).."x speed", 5, y+offset + 30)

            love.graphics.setColor(okColor(v.ap))
            love.graphics.print("AP: "..tostring(v.ap), 140, y+offset + 30)

            ::continue::
        end

    else
        love.graphics.printf("Please ensure ADOFAI is installed in the \n default steam installation location. (C:/ drive)", button.x, button.y + 15, button.w, "center")
    end
end