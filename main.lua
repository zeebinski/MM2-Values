-- MM2 UI LABEL VISIBILITY FIX / V4
-- Displays N/A for unknown items, 0 for items explicitly valued at zero.
-- A value file without prices cannot produce real Traderie prices.
local Players = game:GetService('Players')
local HttpService = game:GetService('HttpService')
local RunService = game:GetService('RunService')
local p = Players.LocalPlayer
local pg = p:WaitForChild('PlayerGui')
local env = getgenv and getgenv() or _G
if type(env.MM2ValuesStop) == 'function' then pcall(env.MM2ValuesStop) end

local active = true
local conns = {}
local labels = {}
local slots = {}
local prices, iconNames = {}, {}
local maxLabels = 100
local root = 'https://raw.githubusercontent.com/zeebinski/MM2-Values/main/'
local function log(...) print('[MM2 VALUES V4]', ...) end
local function norm(s) return tostring(s or ''):lower():gsub('[^%w]','') end
local function loadFile(path)
    local ok, result = pcall(function()
        return HttpService:JSONDecode(game:HttpGet(root .. path .. '?v=4', true))
    end)
    if ok and type(result) == 'table' then return result end
    warn('[MM2 VALUES V4] Could not read',path, tostring(result))
    return {}
end
local valData = loadFile('values.json')
for n,v in pairs(valData.items or {}) do
    if type(v) == 'number' then prices[norm(n)] = v end
end
local iconData = loadFile('icons.json')
for id,name in pairs(iconData.items or {}) do iconNames[tostring(id)] = tostring(name) end

local gui = Instance.new('ScreenGui')
gui.Name = 'MM2ValuesOverlayV4'
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 10000
gui.ZIndexBehavior = Enum.ZIndexBehavior.Global
gui.Parent = pg

-- Small sanity-check label. If this is invisible, item positions are not the issue.
local status = Instance.new('TextLabel')
status.Name = 'MM2OverlayStatus'
status.Size = UDim2.fromOffset(225,25)
status.Position = UDim2.fromOffset(8,68)
status.Text = 'MM2 overlay V4: ON'
status.BackgroundColor3 = Color3.fromRGB(20,20,20)
status.BackgroundTransparency = 0.15
status.TextColor3 = Color3.fromRGB(120,255,140)
status.TextSize = 13
status.Font = Enum.Font.GothamBold
status.ZIndex = 100
status.Parent = gui

local function inInventory(obj)
    local parent = obj
    while parent and parent ~= pg do
        local n = parent.Name:lower()
        if n:find('inventory',1,true) or n:find('trade',1,true)
        or n:find('weapon',1,true) or n:find('items',1,true)
        or n:find('offer',1,true) then return true end
        parent = parent.Parent
    end
    return false
end
local function visible(obj)
    local parent = obj
    while parent and parent ~= pg do
        if parent:IsA('GuiObject') and not parent.Visible then return false end
        parent = parent.Parent
    end
    if parent ~= pg then return false end
    local pos,sz = obj.AbsolutePosition,obj.AbsoluteSize
    local vp = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize
    if not vp then return false end
    return sz.X>=28 and sz.Y>=28 and sz.X<=170 and sz.Y<=170
        and pos.X < vp.X and pos.Y < vp.Y
        and pos.X+sz.X > 0 and pos.Y+sz.Y > 0
end
local function findName(obj)
    local id = tostring(obj.Image):match('%d+')
    if id and iconNames[id] then return iconNames[id] end
    local par = obj
    for _=1,3 do
        if not par or par==pg then break end
        for _,v in ipairs({par.Name, par:GetAttribute('ItemName'),par:GetAttribute('WeaponName')}) do
            if v and prices[norm(v)] ~= nil then return v end
        end
        par=par.Parent
    end
    return nil
end
local function attach(obj)
    if labels[obj] or not inInventory(obj) or not visible(obj) then return end
    if #slots >= maxLabels then return end
    local label = Instance.new('TextLabel')
    label.Name = 'MM2ValueTag'
    label.Size = UDim2.fromOffset(43,18)
    label.BorderSizePixel = 0
    label.BackgroundColor3 = Color3.fromRGB(15,15,15)
    label.BackgroundTransparency = 0.1
    label.TextColor3 = Color3.fromRGB(255,225,105)
    label.TextSize = 12
    label.Font = Enum.Font.GothamBold
    label.ZIndex = 50
    label.Text = 'N/A'
    label.Parent = gui
    labels[obj] = label
    table.insert(slots,obj)
end
local function check(obj)
    if obj:IsA('ImageLabel') or obj:IsA('ImageButton') then
        if obj.Image ~= '' then attach(obj) end
    end
end

local scanned=0
-- Single bounded inventory scan. Yield to avoid freezing Roblox.
for i,obj in ipairs(pg:GetDescendants()) do
    if obj ~= gui and not obj:IsDescendantOf(gui) then check(obj) end
    scanned += 1
    if i % 150 == 0 then task.wait() end
end
log('Initial GUI descendants scanned:',scanned,'visible candidate tags:',#slots)

-- Only new additions are checked. No repeated GetDescendants calls.
table.insert(conns,pg.DescendantAdded:Connect(function(obj)
    if not active or obj:IsDescendantOf(gui) then return end
    if obj:IsA('ImageLabel') or obj:IsA('ImageButton') then
        task.defer(function()
            if active and obj.Parent then check(obj) end
        end)
    end
end))

local elapsed=0
table.insert(conns,RunService.Heartbeat:Connect(function(dt)
    elapsed += dt
    if elapsed < 0.35 then return end
    elapsed = 0
    local shown=0
    for i=#slots,1,-1 do
        local slot=slots[i]
        local label=labels[slot]
        if not slot.Parent or not label then
            if label then label:Destroy() end
            labels[slot]=nil
            table.remove(slots,i)
        else
            local show=visible(slot)
            label.Visible=show
            if show then
                local name=findName(slot)
                local price = name and prices[norm(name)]
                label.Text = price ~= nil and tostring(price) or 'N/A'
                local pos=slot.AbsolutePosition
                label.Position=UDim2.fromOffset(math.floor(pos.X)+2,math.floor(pos.Y)+2)
                shown += 1
            end
        end
    end
    status.Text = 'MM2 overlay V4: '..shown..' labels'
end))

local function stop()
    active=false
    for _,c in ipairs(conns) do c:Disconnect() end
    for _,label in pairs(labels) do if label.Parent then label:Destroy() end end
    gui:Destroy()
    log('Stopped')
end
env.MM2ValuesStop=stop
log('Ready. Values loaded:',(function() local n=0 for _ in pairs(prices) do n+=1 end return n end)())
log('You should see a GREEN status label at top left.')
