-- MM2 live Traderie overlay V8. No fixed item value list.
-- Configure LOOKUP_URL to your deployed Worker /value endpoint.
-- Source-dependent: shows N/A if Traderie refuses automated access.
local LOOKUP_URL = "https://REPLACE-WITH-YOUR-WORKER.workers.dev/value?item="
local Players=game:GetService('Players')
local HttpService=game:GetService('HttpService')
local UIS=game:GetService('UserInputService')
local player=Players.LocalPlayer
local pg=player:WaitForChild('PlayerGui')
local env=getgenv and getgenv() or _G
if type(env.MM2ValuesStop)=='function' then pcall(env.MM2ValuesStop) end
local alive=true
local connections,tracked,cache,pending,queue={},{},{},{},{}
local activeRequests=0
local CACHE_SECONDS=300
local function log(...) print('[MM2 LIVE]',...) end
local function norm(s) return tostring(s or ''):lower():gsub('[^%w]','') end
local root=Instance.new('ScreenGui')
root.Name='MM2LiveTraderieOverlay'
root.ResetOnSpawn=false
root.IgnoreGuiInset=false
root.DisplayOrder=10000
root.Parent=pg
local bar=Instance.new('Frame')
bar.Size=UDim2.fromOffset(224,32)
bar.Position=UDim2.fromOffset(280,8)
bar.BackgroundColor3=Color3.fromRGB(24,26,32)
bar.BorderSizePixel=0
bar.Active=true
bar.Parent=root
local corner=Instance.new('UICorner',bar);corner.CornerRadius=UDim.new(0,6)
local title=Instance.new('TextLabel')
title.Size=UDim2.new(1,-35,1,0)
title.Position=UDim2.fromOffset(8,0)
title.BackgroundTransparency=1
title.Font=Enum.Font.GothamBold
title.TextSize=12
title.TextColor3=Color3.fromRGB(124,236,162)
title.TextXAlignment=Enum.TextXAlignment.Left
title.Text='MM2 Live | waiting'
title.Parent=bar
local close=Instance.new('TextButton')
close.Size=UDim2.fromOffset(30,28)
close.Position=UDim2.new(1,-32,0,2)
close.BackgroundTransparency=1
close.Text='X'
close.TextColor3=Color3.fromRGB(255,112,112)
close.Font=Enum.Font.GothamBold
close.TextSize=16
close.Parent=bar
local function bind(conn)table.insert(connections,conn);return conn end
local dragging=false;local dragStart,startPos
bind(bar.InputBegan:Connect(function(input)
 if input.UserInputType==Enum.UserInputType.MouseButton1 and not UIS:GetFocusedTextBox() then
  dragging=true;dragStart=input.Position;startPos=bar.Position
 end
end))
bind(UIS.InputChanged:Connect(function(input)
 if dragging and input.UserInputType==Enum.UserInputType.MouseMovement then
  local d=input.Position-dragStart
  bar.Position=UDim2.new(startPos.X.Scale,startPos.X.Offset+d.X,startPos.Y.Scale,startPos.Y.Offset+d.Y)
 end
end))
bind(UIS.InputEnded:Connect(function(input)if input.UserInputType==Enum.UserInputType.MouseButton1 then dragging=false end end))
local function stop()
 if not alive then return end
 alive=false
 for _,c in ipairs(connections) do pcall(function()c:Disconnect()end) end
 for card,record in pairs(tracked)do
  for _,c in ipairs(record.connections)do pcall(function()c:Disconnect()end)end
  pcall(function()record.label:Destroy()end)
  tracked[card]=nil
 end
 table.clear(queue)
 root:Destroy()
 log('Stopped')
end
env.MM2ValuesStop=stop
bind(close.MouseButton1Click:Connect(stop))
local function setStatus(s)if alive then title.Text='MM2 Live | '..s end end
local function getCached(name)
 local c=cache[norm(name)]
 if c and os.clock()-c.t<CACHE_SECONDS then return c,true end
 return nil,false
end
local function applyToName(name)
 local cached,ok=getCached(name)
 for _,rec in pairs(tracked) do
  if norm(rec.name)==norm(name) then
   rec.label.Text=ok and (cached.value~=nil and tostring(cached.value) or 'N/A') or '...'
  end
 end
end
local function enqueue(name)
 local key=norm(name)
 if key=='' or pending[key] or LOOKUP_URL:find('REPLACE%-WITH') then return end
 local _,fresh=getCached(name)
 if fresh then return end
 pending[key]=true
 table.insert(queue,name)
end
local function lookup(name)
 local data
 local ok,err=pcall(function()
  local url=LOOKUP_URL..HttpService:UrlEncode(name)
  data=HttpService:JSONDecode(game:HttpGet(url,true))
 end)
 local value=nil
 if ok and type(data)=='table' and data.status=='found' and type(data.value)=='number' then value=data.value end
 cache[norm(name)]={t=os.clock(),value=value,status=ok and (data.status or 'unknown') or 'request_failed'}
 if not ok then log('Lookup failed:',name,tostring(err)) end
 log('Lookup:',name,'=>',value~=nil and value or 'N/A',cache[norm(name)].status)
 applyToName(name)
end
-- Max 2 in-flight HTTP requests; requests only for visible discovered cards.
task.spawn(function()
 while alive do
  if activeRequests<2 and #queue>0 then
   local name=table.remove(queue,1)
   activeRequests+=1
   task.spawn(function()
    lookup(name)
    activeRequests-=1
    pending[norm(name)]=nil
   end)
  else task.wait(.1) end
 end
end)
local BLOCKED = {
 weapons=true,effects=true,powers=true,emotes=true,radios=true,pets=true,
 inventory=true,shop=true,craftingstation=true,view=true,enterCode=true,
 redeem=true,search=true,classic=true,holiday=true,season1=true,
 default=true
}
local function hasInventoryAncestor(obj)
 local p=obj
 while p and p~=pg do
  local n=p.Name:lower()
  if n:find('inventory',1,true) or n:find('trade',1,true)
    or n:find('weapons',1,true) then return true end
  p=p.Parent
 end
 return false
end
local function inventoryGrid(card)
 -- Item cards must be in a scrolling item grid, never in category buttons.
 local p=card.Parent
 local depth=0
 while p and p~=pg and depth<7 do
  if p:IsA('ScrollingFrame') then return p end
  p=p.Parent
  depth+=1
 end
 return nil
end
local function isVisible(obj)
 local p=obj
 while p and p~=pg do
  if p:IsA('GuiObject') and not p.Visible then return false end
  p=p.Parent
 end
 return p==pg
end
local function looksLikeIcon(card)
 if (card:IsA('ImageLabel') or card:IsA('ImageButton')) and card.Image~='' then return true end
 for _,child in ipairs(card:GetChildren()) do
  if (child:IsA('ImageLabel') or child:IsA('ImageButton')) and child.Image~='' then
   if child.AbsoluteSize.X>=25 and child.AbsoluteSize.Y>=25 then return true end
  end
 end
 return false
end
local function itemText(card)
 local best,bottom=nil,-1
 for _,node in ipairs(card:GetChildren()) do
  if (node:IsA('TextLabel') or node:IsA('TextButton')) and node.Name~='MM2ItemValue' then
   local t=node.Text:gsub('^%s+',''):gsub('%s+$','')
   local k=norm(t)
   if #t>=2 and #t<=45 and not BLOCKED[k] and not t:match('^%d+$')
     and not t:match('^[xX]%d+$') and node.AbsolutePosition.Y>bottom then
    best=t;bottom=node.AbsolutePosition.Y
   end
  end
 end
 return best
end
local function cardForText(obj)
 if not (obj:IsA('TextLabel') or obj:IsA('TextButton')) then return nil end
 if obj.Name=='MM2ItemValue' then return nil end
 local card=obj.Parent
 if not card or not card:IsA('GuiObject') then return nil end
 local sz=card.AbsoluteSize
 if sz.X<65 or sz.Y<65 or sz.X>185 or sz.Y>190 then return nil end
 if not inventoryGrid(card) then return nil end
 if not hasInventoryAncestor(card) then return nil end
 if not looksLikeIcon(card) then return nil end
 local item=itemText(card)
 if not item then return nil end
 -- The item name belongs near the bottom of the item card, not a header.
 if obj.Text:gsub('^%s+',''):gsub('%s+$','')~=item then return nil end
 return card
end
local function discover(obj)
 local card=cardForText(obj)
 if not card or tracked[card] then return end
 local name=itemText(card)
 if not name then return end
 local label=Instance.new('TextLabel')
 label.Name='MM2ItemValue'
 label.Size=UDim2.fromOffset(55,17)
 label.Position=UDim2.fromOffset(2,2)
 label.ZIndex=card.ZIndex+10
 label.BackgroundColor3=Color3.fromRGB(12,12,15)
 label.BackgroundTransparency=.1
 label.BorderSizePixel=0
 label.Font=Enum.Font.GothamBold
 label.TextSize=12
 label.TextColor3=Color3.fromRGB(255,225,120)
 label.Text='...'
 label.Visible=isVisible(card)
 label.Parent=card
 local rec={name=name,label=label,connections={}}
 tracked[card]=rec
 local function refresh()
  if not alive or not card.Parent then return end
  rec.name=itemText(card) or rec.name
  label.Visible=isVisible(card)
  if label.Visible then
   local c,exists=getCached(rec.name)
   label.Text=exists and (c.value~=nil and tostring(c.value) or 'N/A') or '...'
   if not exists then enqueue(rec.name) end
  end
 end
 table.insert(rec.connections,card:GetPropertyChangedSignal('Visible'):Connect(refresh))
 for _,child in ipairs(card:GetChildren())do
  if child:IsA('TextLabel') and child~=label then
   table.insert(rec.connections,child:GetPropertyChangedSignal('Text'):Connect(refresh))
  end
 end
 refresh()
end
-- One initial discovery pass and event-driven discovery, not constant full rescan.
local initial=0
for _,node in ipairs(pg:GetDescendants())do
 if node:IsA('TextLabel') or node:IsA('TextButton') then discover(node) end
 initial+=1
 if initial%400==0 then task.wait() end
end
bind(pg.DescendantAdded:Connect(function(node)
 if not alive then return end
 if node:IsA('TextLabel') or node:IsA('TextButton') then
  task.defer(function()if alive then discover(node) end end)
 end
end))
-- Cheap visibility update for tracked cards only; no GUI tree scan.
task.spawn(function()
 while alive do
  local count,visible=0,0
  for card,rec in pairs(tracked)do
   if not card.Parent then
    for _,c in ipairs(rec.connections)do c:Disconnect()end
    tracked[card]=nil
   else
    local v=isVisible(card)
    rec.label.Visible=v
    count+=1
    if v then
     visible+=1
     local c,fresh=getCached(rec.name)
     rec.label.Text=fresh and (c.value~=nil and tostring(c.value) or 'N/A') or '...'
     if not fresh then enqueue(rec.name)end
    end
   end
  end
  setStatus(visible..' visible | '..activeRequests..' requests')
  task.wait(.4)
 end
end)
log('V9 item-grid only. Started. Recognized cards:',(function()local n=0 for _ in pairs(tracked)do n+=1 end return n end)())
if LOOKUP_URL:find('REPLACE%-WITH')then warn('[MM2 LIVE] Set LOOKUP_URL to your Worker URL in main.lua first!') end
