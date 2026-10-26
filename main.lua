-- MM2 Traderie: label-only UI overlay, no dashboard.
-- NOTE: identifies icons ONLY when UI provides item names/attributes or an icon map.
local Players = game:GetService('Players')
local HttpService = game:GetService('HttpService')
local player = Players.LocalPlayer
local playerGui = player:WaitForChild('PlayerGui')
local base = 'https://raw.githubusercontent.com/zeebinski/MM2-Values/main/'
local shared = getgenv and getgenv()
if shared and shared.MM2ValuesStop then pcall(shared.MM2ValuesStop) end
local active = true
local labels = {}
local valueMap = {}
local iconMap = {}
local function clean(s)
    return tostring(s or ''):lower():gsub('[^%w]', '')
end
local function fetchJSON(file)
    local success, result = pcall(function()
        return HttpService:JSONDecode(game:HttpGet(base .. file .. '?t=' .. tostring(os.time()), true))
    end)
    return success and type(result)=='table' and result or {}
end
local function refresh()
    local data = fetchJSON('values.json')
    valueMap = {}
    for n,v in pairs(data.items or {}) do
        if type(v) == 'number' and v >= 0 then valueMap[clean(n)] = v end
    end
    -- Optional icon ID -> Traderie item name mapping, when UI has no textual name.
    -- Empty mapping is safe; we don't guess item identities.
    local icons = fetchJSON('icons.json')
    iconMap = icons.items or {}
end
local function visible(obj)
    local a=obj
    while a and a~=playerGui do
        if a:IsA('GuiObject') and not a.Visible then return false end
        a=a.Parent
    end
    return a==playerGui
end
local function appropriate(slot)
    local a=slot
    while a and a~=playerGui do
        local n=clean(a.Name)
        if n:find('inventory',1,true) or n:find('trade',1,true) or n:find('offer',1,true) then return true end
        a=a.Parent
    end
    return false
end
local function resolvedName(slot)
    local candidates={slot:GetAttribute('ItemName'),slot:GetAttribute('WeaponName'),slot.Name}
    for _,obj in ipairs(slot:GetDescendants()) do
        if obj:IsA('TextLabel') or obj:IsA('TextButton') then
            table.insert(candidates,obj.Text)
        elseif obj:IsA('ImageLabel') or obj:IsA('ImageButton') then
            local id=tostring(obj.Image):match('(%d+)')
            if id and iconMap[id] then table.insert(candidates,iconMap[id]) end
        end
    end
    local id=tostring(slot.Image):match('(%d+)')
    if id and iconMap[id] then table.insert(candidates,iconMap[id]) end
    for _,name in ipairs(candidates) do
        if type(name)=='string' and valueMap[clean(name)]~=nil then return name end
    end
    return nil
end
local function cleanup()
    for slot,tag in pairs(labels) do
        if tag and tag.Parent then tag:Destroy() end
        labels[slot]=nil
    end
end
local function scan()
    local found={}
    for _,obj in ipairs(playerGui:GetDescendants()) do
        if obj:IsA('ImageButton') and visible(obj) and appropriate(obj) then
            local n=resolvedName(obj)
            if n then
                found[obj]=true
                local v=valueMap[clean(n)]
                local tag=labels[obj]
                if not tag or not tag.Parent then
                    tag=Instance.new('TextLabel')
                    tag.Name='MM2TraderiePrice'
                    tag.Size=UDim2.fromOffset(52,17)
                    tag.Position=UDim2.fromOffset(2,2)
                    tag.BackgroundColor3=Color3.fromRGB(15,15,20)
                    tag.BackgroundTransparency=.2
                    tag.TextColor3=Color3.fromRGB(255,235,135)
                    tag.Font=Enum.Font.GothamBold
                    tag.TextSize=12
                    tag.TextXAlignment=Enum.TextXAlignment.Center
                    tag.ZIndex=obj.ZIndex+5
                    tag.Parent=obj
                    labels[obj]=tag
                end
                tag.Text=(v==nil and 'N/A' or tostring(v))
            end
        end
    end
    for obj,tag in pairs(labels) do
        if not found[obj] then
            if tag and tag.Parent then tag:Destroy() end
            labels[obj]=nil
        end
    end
end
refresh()
task.spawn(function()
    local last=0
    while active do
        if os.clock()-last > 300 then refresh(); last=os.clock() end
        pcall(scan)
        task.wait(1.5)
    end
end)
local function stop() active=false; cleanup() end
if shared then shared.MM2ValuesStop=stop end
print('MM2 Traderie labels loaded; no dashboard. Matched slots require item names or icons.json mappings.')
