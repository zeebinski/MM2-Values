-- MM2 Traderie item labels V6 - screen-visible named item cards only.
-- Price source: your own values.json (Traderie); no fabricated numbers.
local Players=game:GetService('Players')
local HttpService=game:GetService('HttpService')
local UIS=game:GetService('UserInputService')
local player=Players.LocalPlayer
local playerGui=player:WaitForChild('PlayerGui')
local env=(type(getgenv)=='function' and getgenv()) or _G
if type(env.MM2ValuesStop)=='function' then pcall(env.MM2ValuesStop) end
local previous=playerGui:FindFirstChild('MM2TraderieV6')
if previous then previous:Destroy() end
local live=true
local connections={}
local cards={}
local prices={}
local count=0
local function connect(signal,fn)
 local c=signal:Connect(fn); table.insert(connections,c); return c
end
local function log(...) print('[MM2 V6]',...) end
local function norm(s) return tostring(s or ''):lower():gsub('[^%w]','') end
local url='https://raw.githubusercontent.com/zeebinski/MM2-Values/main/values.json'
local ok,data=pcall(function() return HttpService:JSONDecode(game:HttpGet(url,true)) end)
if ok and type(data)=='table' then
 for item,value in pairs(data.items or {}) do
  if type(value)=='number' then prices[norm(item)]=value; count=count+1 end
 end
else warn('[MM2 V6] Cannot load Traderie values.json; all item prices N/A') end
log('Prices loaded:',count)
local overlay=Instance.new('ScreenGui')
overlay.Name='MM2TraderieV6';overlay.IgnoreGuiInset=true;overlay.ResetOnSpawn=false
-- The overlay uses absolute screen coordinates; IgnoreGuiInset prevents offsets.
overlay.ZIndexBehavior=Enum.ZIndexBehavior.Sibling;overlay.DisplayOrder=5000
overlay.Parent=playerGui
local function mk(class,props,parent)
 local x=Instance.new(class)
 for k,v in pairs(props) do x[k]=v end
 x.Parent=parent;return x
end
local bar=mk('Frame',{Size=UDim2.fromOffset(213,31),Position=UDim2.fromOffset(285,8),BackgroundColor3=Color3.fromRGB(25,27,32),BorderSizePixel=0,Active=true,ZIndex=20},overlay)
mk('UICorner',{CornerRadius=UDim.new(0,6)},bar)
local status=mk('TextLabel',{Size=UDim2.new(1,-38,1,0),Position=UDim2.fromOffset(9,0),Text='MM2 Values | 0 visible',TextColor3=Color3.fromRGB(130,238,163),Font=Enum.Font.GothamBold,TextSize=12,TextXAlignment=Enum.TextXAlignment.Left,BackgroundTransparency=1,ZIndex=21},bar)
local close=mk('TextButton',{Size=UDim2.fromOffset(29,27),Position=UDim2.new(1,-31,0,2),Text='X',TextColor3=Color3.fromRGB(255,130,130),TextSize=15,Font=Enum.Font.GothamBold,BackgroundTransparency=1,ZIndex=22},bar)
local dragging=false;local dragStart;local origin
connect(bar.InputBegan,function(input)
 if input.UserInputType==Enum.UserInputType.MouseButton1 then dragging=true;dragStart=input.Position;origin=bar.Position end
end)
connect(UIS.InputChanged,function(input)
 if dragging and input.UserInputType==Enum.UserInputType.MouseMovement then
  local d=input.Position-dragStart;bar.Position=UDim2.new(origin.X.Scale,origin.X.Offset+d.X,origin.Y.Scale,origin.Y.Offset+d.Y)
 end
end)
connect(UIS.InputEnded,function(input) if input.UserInputType==Enum.UserInputType.MouseButton1 then dragging=false end end)
local function stop()
 if not live then return end;live=false
 for _,c in ipairs(connections) do pcall(function()c:Disconnect()end)end
 table.clear(cards);overlay:Destroy();env.MM2ValuesStop=nil
 log('Stopped; labels removed')
end
connect(close.MouseButton1Click,stop)
env.MM2ValuesStop=stop
local function underInventory(o)
 local p=o
 while p and p~=playerGui do
  local n=p.Name:lower()
  if n:find('inventory',1,true) or n:find('weapons',1,true) or n:find('trading',1,true) or n:find('trade',1,true) then return true end
  p=p.Parent
 end
 return false
end
local invalid={['search']=true,['season 1']=true,['classic']=true,['holiday']=true,['weapons']=true,['powers']=true,['emotes']=true,['radios']=true,['pets']=true,['inventory']=true,['shop']=true,['crafting station']=true,['view']=true,['enter code']=true,['redeem']=true,['effects']=true}
local function cleanName(s)
 s=tostring(s or ''):gsub('^%s+',''):gsub('%s+$','')
 if s=='' or #s>45 or invalid[s:lower()] or s:match('^%d+$') or s:lower()=='n/a' then return nil end
 return s
end
local function findCard(t)
 if not (t:IsA('TextLabel') or t:IsA('TextButton')) or t.Name=='MM2ValueText' then return nil end
 if not underInventory(t) then return nil end
 -- MM2 items have a name text label inside their item tile.
 -- Do NOT attach to arbitrary ImageLabels or accessory/sidebar icons.
 local name=cleanName(t.Text)
 if not name then return nil end
 local card=t.Parent
 for depth=1,2 do
  if not card or card==playerGui or card:IsA('ScreenGui') then break end
  if card:IsA('GuiObject') then
   local s=card.AbsoluteSize
   if s.X>=55 and s.X<=180 and s.Y>=65 and s.Y<=195 then
    local hasImage=false
    for _,child in ipairs(card:GetChildren()) do
     if (child:IsA('ImageLabel') or child:IsA('ImageButton')) and child.Image~='' then hasImage=true;break end
    end
    if hasImage then return card,name end
   end
  end
  card=card.Parent
 end
 return nil
end
local function intersection(a,b)
 local x1=math.max(a.x,b.x);local y1=math.max(a.y,b.y)
 local x2=math.min(a.x+a.w,b.x+b.w);local y2=math.min(a.y+a.h,b.y+b.h)
 if x2<=x1 or y2<=y1 then return nil end
 return {x=x1,y=y1,w=x2-x1,h=y2-y1}
end
local function onScreen(card)
 if not card.Parent then return false end
 local camera=workspace.CurrentCamera
 if not camera then return false end
 local vp=camera.ViewportSize
 local r={x=0,y=0,w=vp.X,h=vp.Y}
 local p=card
 while p and p~=playerGui do
  if p:IsA('GuiObject') then
   if not p.Visible or p.AbsoluteSize.X<=0 or p.AbsoluteSize.Y<=0 then return false end
   -- ScrollingFrames are always clipped; also respect any ClipsDescendants container.
   if p==card or p:IsA('ScrollingFrame') or p.ClipsDescendants then
    local at=p.AbsolutePosition;local sz=p.AbsoluteSize
    r=intersection(r,{x=at.X,y=at.Y,w=sz.X,h=sz.Y})
    if not r then return false end
   end
  elseif p:IsA('ScreenGui') and not p.Enabled then return false end
  p=p.Parent
 end
 -- Only show a label if the TOP-LEFT corner of the tile is visible.
 local at=card.AbsolutePosition
 return r and at.X+12>=r.x and at.X+12<r.x+r.w and at.Y+12>=r.y and at.Y+12<r.y+r.h
end
local function track(t)
 local card,name=findCard(t)
 if not card then return end
 if cards[card] then return end
 local label=mk('TextLabel',{Name='MM2ValueText',Size=UDim2.fromOffset(54,17),BackgroundColor3=Color3.fromRGB(10,10,12),BackgroundTransparency=0.1,BorderSizePixel=0,TextColor3=Color3.fromRGB(255,224,115),Font=Enum.Font.GothamBold,TextSize=11,ZIndex=10,Visible=false},overlay)
 mk('UICorner',{CornerRadius=UDim.new(0,2)},label)
 cards[card]={source=t,label=label,name=name}
end
-- One initial scan; subsequent new cards are picked up as they're created.
for _,obj in ipairs(playerGui:GetDescendants()) do
 if obj:IsA('TextLabel') or obj:IsA('TextButton') then track(obj) end
end
connect(playerGui.DescendantAdded,function(obj)
 if not live or obj:IsDescendantOf(overlay) then return end
 if obj:IsA('TextLabel') or obj:IsA('TextButton') then
  task.defer(function()if live then track(obj)end end)
 elseif obj:IsA('ImageLabel') or obj:IsA('ImageButton') then
  local parent=obj.Parent
  task.defer(function()
   if not live or not parent then return end
   for _,sibling in ipairs(parent:GetChildren()) do
    if sibling:IsA('TextLabel') or sibling:IsA('TextButton') then track(sibling) end
   end
  end)
 end
end)
-- Refresh positions of TRACKED item tiles only. No repeated PlayerGui:GetDescendants().
task.spawn(function()
 while live do
  local shown=0
  for card,item in pairs(cards) do
   if not card.Parent or not item.source.Parent then
    item.label:Destroy();cards[card]=nil
   else
    local name=cleanName(item.source.Text)
    local visible=name~=nil and onScreen(card)
    item.label.Visible=visible or false
    if visible then
     item.name=name
     local price=prices[norm(name)]
     item.label.Text=price==nil and 'N/A' or tostring(price)
     local pos=card.AbsolutePosition
     item.label.Position=UDim2.fromOffset(pos.X+3,pos.Y+3)
     shown=shown+1
    end
   end
  end
  status.Text='MM2 Values | '..shown..' visible'
  task.wait(0.35)
 end
end)
log('Running. Named item cards tracked. Prices:',count,'X stops everything.')
