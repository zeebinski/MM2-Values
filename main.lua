-- MM2 Values overlay starter; client-side read-only UI
-- Requires an executor supporting game:HttpGet + loadstring.
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local player = Players.LocalPlayer
local repo = "REPLACE_USER/REPLACE_REPO" -- GitHub username/repo
local url = "https://raw.githubusercontent.com/"..repo.."/main/values.json"

if getgenv and getgenv().MM2ValuesStop then getgenv().MM2ValuesStop() end
local alive = true
local added = {}
local connections = {}
local gui = Instance.new("ScreenGui")
gui.Name = "MM2TraderieValues"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.Parent = player:WaitForChild("PlayerGui")

local function key(s)
    return tostring(s or ""):lower():gsub("[^%w]", "")
end
local values = {}
local count = 0
local function loadValues()
    local ok, result = pcall(function()
        return HttpService:JSONDecode(game:HttpGet(url, true))
    end)
    if not ok or type(result) ~= "table" or type(result.items) ~= "table" then
        warn("MM2 Values: could not load values.json from GitHub")
        return false
    end
    values = {}
    count = 0
    for name, val in pairs(result.items) do
        if type(val) == "number" and val >= 0 then
            values[key(name)] = val
            count += 1
        end
    end
    return true
end

local panel = Instance.new("Frame")
panel.Name = "Summary"
panel.Size = UDim2.fromOffset(245, 94)
panel.Position = UDim2.new(1, -255, 0, 65)
panel.BackgroundColor3 = Color3.fromRGB(25,25,30)
panel.BackgroundTransparency = 0.12
panel.Parent = gui
Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 8)
local summary = Instance.new("TextLabel")
summary.BackgroundTransparency = 1
summary.Size = UDim2.fromScale(1,1)
summary.TextColor3 = Color3.new(1,1,1)
summary.Font = Enum.Font.GothamBold
summary.TextSize = 13
summary.TextWrapped = true
summary.Text = "Traderie MM2 • Loading..."
summary.Parent = panel

-- This is deliberately conservative: only exact item names found in a
-- visible inventory/trade GUI are recognized. Icon-only slots need a
-- game-specific icon-ID-to-name map; this script does not guess identities.
local function isVisible(inst)
    local node = inst
    while node and node ~= player.PlayerGui do
        if node:IsA("GuiObject") and not node.Visible then return false end
        node = node.Parent
    end
    return node == player.PlayerGui
end
local function inTargetUI(inst)
    local node = inst
    while node and node ~= player.PlayerGui do
        local n = node.Name:lower()
        if n:find("inventory",1,true) or n:find("trade",1,true)
          or n:find("offer",1,true) then return true end
        node = node.Parent
    end
    return false
end
local function findItemName(slot)
    for _, candidate in ipairs({slot:GetAttribute("ItemName"), slot:GetAttribute("WeaponName"), slot.Name}) do
        if type(candidate) == "string" and values[key(candidate)] ~= nil then
            return candidate
        end
    end
    for _, d in ipairs(slot:GetDescendants()) do
        if d:IsA("TextLabel") or d:IsA("TextButton") then
            if values[key(d.Text)] ~= nil then return d.Text end
        end
    end
    return nil
end
local function removeLabels()
    for _, object in ipairs(added) do
        if object and object.Parent then object:Destroy() end
    end
    table.clear(added)
end
local function valueText(value)
    return tostring(value):gsub("%.0$", "")
end
local function scan()
    removeLabels()
    local scanned = {}
    local recognized = 0
    local total = 0
    local playerGui = player:FindFirstChild("PlayerGui")
    if not playerGui then return end
    for _, slot in ipairs(playerGui:GetDescendants()) do
        if slot:IsA("ImageButton") and slot.Visible and isVisible(slot)
            and inTargetUI(slot) and not slot:IsDescendantOf(gui) then
            local name = findItemName(slot)
            if name and not scanned[slot] then
                scanned[slot] = true
                local amount = values[key(name)]
                if amount then
                    recognized += 1
                    total += amount
                    local tag = Instance.new("TextLabel")
                    tag.Name = "MM2ValueTag"
                    tag.Size = UDim2.fromOffset(48,16)
                    tag.Position = UDim2.fromOffset(2,2)
                    tag.BackgroundColor3 = Color3.fromRGB(10,10,15)
                    tag.BackgroundTransparency = 0.2
                    tag.TextColor3 = Color3.fromRGB(255,232,115)
                    tag.TextSize = 12
                    tag.Font = Enum.Font.GothamBold
                    tag.Text = valueText(amount)
                    tag.ZIndex = slot.ZIndex + 10
                    tag.Parent = slot
                    table.insert(added,tag)
                end
            end
        end
    end
    summary.Text = string.format("TRADERIE • %d prices loaded\nVisible identified slots: %d\nRecognized subtotal: %s\nIcon-only / unknown: not counted",count,recognized,valueText(total))
end
local ok = loadValues()
if not ok then summary.Text = "Traderie • No GitHub values loaded\nCheck repository configuration" end
local thread = task.spawn(function()
    while alive do
        if ok then pcall(scan) end
        task.wait(2)
    end
end)
local function stop()
    alive = false
    removeLabels()
    gui:Destroy()
    for _, connection in ipairs(connections) do connection:Disconnect() end
end
if getgenv then getgenv().MM2ValuesStop = stop end

local close = Instance.new("TextButton")
close.Size = UDim2.fromOffset(20,20)
close.Position = UDim2.new(1,-22,0,2)
close.BackgroundColor3 = Color3.fromRGB(90,35,35)
close.Text = "×"
close.TextColor3 = Color3.new(1,1,1)
close.TextSize = 16
close.ZIndex = 100
close.Parent = panel
table.insert(connections,close.MouseButton1Click:Connect(stop))
