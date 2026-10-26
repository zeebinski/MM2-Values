
-- MM2 TRADERIE VALUE LABELS V2
-- No dashboard / no repeated full scans

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")

local player = Players.LocalPlayer
local pg = player:WaitForChild("PlayerGui")
local env = getgenv()

-- Stop older version
if type(env.MM2ValuesStop) == "function" then
    pcall(env.MM2ValuesStop)
end

local running = true
local connections = {}
local slots = {}
local values = {}
local icons = {}
local loaded = 0

local base =
    "https://raw.githubusercontent.com/" ..
    "zeebinski/MM2-Values/main/"

local function log(...)
    print("[MM2 VALUES]", ...)
end

local function normalize(s)
    return tostring(s or ""):lower()
        :gsub("[^%w]", "")
end

local function fetch(name)
    local ok, data = pcall(function()
        return HttpService:JSONDecode(
            game:HttpGet(base .. name, true)
        )
    end)

    if ok and type(data) == "table" then
        return data
    end

    warn("[MM2 VALUES] Cannot load", name)
    return {}
end

local function loadData()
    local data = fetch("values.json")
    local iconData = fetch("icons.json")

    values = {}
    icons = {}
    loaded = 0

    for name, value in pairs(data.items or {}) do
        if type(value) == "number" then
            values[normalize(name)] = value
            loaded += 1
        end
    end

    for id, name in pairs(iconData.items or {}) do
        icons[tostring(id)] = tostring(name)
    end

    log("Traderie prices loaded:", loaded)
    log("Icon mappings loaded:", 
        (function()
            local n = 0
            for _ in pairs(icons) do n += 1 end
            return n
        end)()
    )
end

local function targetUI(obj)
    local p = obj

    while p and p ~= pg do
        local n = p.Name:lower()

        if n:find("inventory", 1, true)
            or n:find("trade", 1, true)
            or n:find("weapons", 1, true)
            or n:find("offer", 1, true)
            or n:find("items", 1, true) then
            return true
        end

        p = p.Parent
    end

    return false
end

local function getName(obj)
    -- First try image-ID mappings
    local image = tostring(obj.Image or "")
    local id = image:match("%d+")

    if id and icons[id] then
        return icons[id]
    end

    -- Next look for actual item names
    local p = obj

    for _ = 1, 3 do
        if not p or p == pg then break end

        local candidates = {
            p.Name,
            p:GetAttribute("ItemName"),
            p:GetAttribute("WeaponName"),
            p:GetAttribute("Name"),
        }

        for _, name in pairs(candidates) do
            if type(name) == "string"
                and values[normalize(name)] ~= nil then
                return name
            end
        end

        for _, child in ipairs(p:GetChildren()) do
            if child:IsA("TextLabel")
                or child:IsA("TextButton") then

                if values[normalize(child.Text)] ~= nil then
                    return child.Text
                end
            end
        end

        p = p.Parent
    end

    return nil
end

local function qualifies(obj)
    if not (
        obj:IsA("ImageLabel")
        or obj:IsA("ImageButton")
    ) then
        return false
    end

    if not targetUI(obj) then return false end

    -- Avoid tiny decorative icons and giant images
    local size = obj.AbsoluteSize
    if size.X < 25 or size.Y < 25 then
        return false
    end

    if size.X > 200 or size.Y > 200 then
        return false
    end

    return obj.Image ~= ""
end

local function createLabel(slot)
    if slots[slot] then return end

    local name = getName(slot)
    local value = name and values[normalize(name)]

    local label = Instance.new("TextLabel")
    label.Name = "MM2TraderieValue"
    label.Size = UDim2.fromOffset(52, 18)
    label.Position = UDim2.fromOffset(2, 2)
    label.BackgroundColor3 = Color3.fromRGB(15,15,20)
    label.BackgroundTransparency = 0.2
    label.TextColor3 = Color3.fromRGB(255,230,100)
    label.Font = Enum.Font.GothamBold
    label.TextSize = 12
    label.TextScaled = false
    label.BorderSizePixel = 0
    label.ZIndex = slot.ZIndex + 5
    label.Text = value ~= nil
        and tostring(value)
        or "N/A"
    label.Parent = slot

    slots[slot] = label
end

local function updateSlot(slot, label)
    if not slot.Parent then
        if label.Parent then label:Destroy() end
        slots[slot] = nil
        return
    end

    local name = getName(slot)
    local value = name and values[normalize(name)]

    local newText = value ~= nil
        and tostring(value)
        or "N/A"

    if label.Text ~= newText then
        label.Text = newText
    end
end

local function stop()
    running = false

    for _, c in ipairs(connections) do
        c:Disconnect()
    end

    for slot, label in pairs(slots) do
        if label.Parent then label:Destroy() end
        slots[slot] = nil
    end

    log("Stopped")
end

env.MM2ValuesStop = stop

log("Starting")
loadData()

-- Initial scan
local scanned = 0

for _, obj in ipairs(pg:GetDescendants()) do
    if qualifies(obj) then
        createLabel(obj)
        scanned += 1
    end

    if scanned >= 250 then break end
end

log("Initial candidate slots:", scanned)

-- Track newly added inventory images
table.insert(connections,
    pg.DescendantAdded:Connect(function(obj)
        if not running then return end

        if qualifies(obj) then
            createLabel(obj)
        end
    end)
)

-- Update tracked labels without rescanning PlayerGui
task.spawn(function()
    while running do
        task.wait(1.5)

        local total = 0

        for slot, label in pairs(slots) do
            updateSlot(slot, label)
            total += 1
        end
    end
end)

log("Label tracker active")
log("No dashboard created")
log("Stop with getgenv().MM2ValuesStop()")
