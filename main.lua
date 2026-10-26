-- MM2 Traderie overlay V3: no dashboard; low-frequency tracking.
-- This reads visible Roblox UI and a GitHub-hosted value list.
-- Unknown prices: N/A; known zero prices: 0.
local Players = game:GetService('Players')
local HttpService = game:GetService('HttpService')
local GuiService = game:GetService('GuiService')
local player = Players.LocalPlayer
local pg = player:WaitForChild('PlayerGui')
local env = getgenv and getgenv() or _G
if type(env.MM2ValuesStop) == 'function' then pcall(env.MM2ValuesStop) end

local alive, connections, tags = true, {}, {}
local function log(...) print('[MM2 VALUES]', ...) end
local function key(s) return tostring(s or ''):lower():gsub('[^%w]', '') end
local function wire(c) table.insert(connections, c) end
local values, icons = {}, {}
local base = 'https://raw.githubusercontent.com/zeebinski/MM2-Values/main/'
local function readJSON(file)
    local ok, data = pcall(function()
        return HttpService:JSONDecode(game:HttpGet(base .. file .. '?v=' .. tostring(os.time()), true))
    end)
    if not ok or type(data) ~= 'table' then
        warn('[MM2 VALUES] Could not load', file, tostring(data))
        return {}
    end
    return data
end
local db = readJSON('values.json')
local priceCount = 0
for name, price in pairs(db.items or {}) do
    if type(price) == 'number' and price >= 0 then
        values[key(name)] = price
        priceCount += 1
    end
end
local iconDB = readJSON('icons.json')
local iconCount = 0
for id, name in pairs(iconDB.items or {}) do
    icons[tostring(id)] = tostring(name)
    iconCount += 1
end
log('Prices loaded:', priceCount, '| image mappings:', iconCount)
if priceCount == 0 then warn('[MM2 VALUES] values.json has no prices. Labels will say N/A.') end

-- This independent overlay avoids clipping within Roblox inventory slots.
local overlay = Instance.new('ScreenGui')
overlay.Name = 'MM2TraderieOverlay'
overlay.IgnoreGuiInset = true
overlay.ResetOnSpawn = false
overlay.DisplayOrder = 10000
overlay.Parent = pg

local function isTarget(obj)
    local node = obj
    while node and node ~= pg do
        local n = node.Name:lower()
        if n:find('inventory', 1, true) or n:find('trade', 1, true)
           or n:find('offer', 1, true) or n:find('weapons', 1, true)
           or n:find('items', 1, true) then return true end
        node = node.Parent
    end
    return false
end
local function shown(obj)
    local node = obj
    while node and node ~= pg do
        if node:IsA('GuiObject') and not node.Visible then return false end
        if node:IsA('ScrollingFrame') then
            local p, sz = obj.AbsolutePosition, obj.AbsoluteSize
            local a, b = node.AbsolutePosition, node.AbsoluteSize
            if p.X + sz.X <= a.X or p.X >= a.X + b.X
                or p.Y + sz.Y <= a.Y or p.Y >= a.Y + b.Y then return false end
        end
        node = node.Parent
    end
    return node == pg
end
local function guessName(obj)
    local imageId = tostring(obj.Image):match('%d+')
    if imageId and icons[imageId] then return icons[imageId] end
    local node = obj
    for _ = 1, 3 do
        if not node or node == pg then break end
        local opts = {node.Name, node:GetAttribute('ItemName'), node:GetAttribute('WeaponName')}
        for _, name in pairs(opts) do
            if type(name) == 'string' and values[key(name)] ~= nil then return name end
        end
        for _, child in ipairs(node:GetChildren()) do
            if child:IsA('TextLabel') or child:IsA('TextButton') then
                if values[key(child.Text)] ~= nil then return child.Text end
            end
        end
        node = node.Parent
    end
    return nil
end
local function qualify(obj)
    if not (obj:IsA('ImageLabel') or obj:IsA('ImageButton')) then return false end
    if obj:IsDescendantOf(overlay) or not isTarget(obj) then return false end
    if obj.Image == '' then return false end
    local s = obj.AbsoluteSize
    return s.X >= 30 and s.Y >= 30 and s.X <= 160 and s.Y <= 160
end
local count, maxSlots = 0, 220
local function add(obj)
    if not alive or tags[obj] or count >= maxSlots or not qualify(obj) then return end
    local tag = Instance.new('TextLabel')
    tag.Name = 'MM2ValueTag'
    tag.Size = UDim2.fromOffset(49, 18)
    tag.BackgroundColor3 = Color3.fromRGB(14, 14, 19)
    tag.BackgroundTransparency = 0.2
    tag.BorderSizePixel = 0
    tag.Font = Enum.Font.GothamBold
    tag.TextSize = 12
    tag.TextColor3 = Color3.fromRGB(255, 229, 115)
    tag.ZIndex = 10
    tag.Visible = false
    tag.Parent = overlay
    local name = guessName(obj)
    local price = name and values[key(name)] or nil
    tag.Text = price ~= nil and tostring(price) or 'N/A'
    tags[obj] = tag
    count += 1
end
local descendants = pg:GetDescendants()
for i, obj in ipairs(descendants) do
    if obj ~= overlay and qualify(obj) then add(obj) end
    if i % 300 == 0 then task.wait() end -- spread discovery across frames
end
log('Candidate image slots:', count, '| no dashboard')
wire(pg.DescendantAdded:Connect(function(obj)
    if alive and (obj:IsA('ImageLabel') or obj:IsA('ImageButton')) then
        -- Defer until layout and parent tree settle.
        task.defer(function() if alive then add(obj) end end)
    end
end))

local function stop()
    if not alive then return end
    alive = false
    for _, c in ipairs(connections) do pcall(function() c:Disconnect() end) end
    table.clear(connections)
    overlay:Destroy()
    table.clear(tags)
    log('Stopped')
end
env.MM2ValuesStop = stop

-- Position only existing tags. No repeated PlayerGui:GetDescendants() calls.
task.spawn(function()
    while alive do
        for slot, tag in pairs(tags) do
            if not slot.Parent then
                tag:Destroy()
                tags[slot] = nil
                count -= 1
            else
                local s = slot.AbsoluteSize
                local visible = s.X >= 30 and s.Y >= 30 and shown(slot)
                tag.Visible = visible
                if visible then
                    local p = slot.AbsolutePosition
                    -- IgnoreGuiInset=true uses screen coordinates.
                    tag.Position = UDim2.fromOffset(math.floor(p.X + 2), math.floor(p.Y + 2))
                end
            end
        end
        task.wait(0.5)
    end
end)
log('Overlay active. To stop: getgenv().MM2ValuesStop()')
