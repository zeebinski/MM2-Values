-- MM2 Values V7: Traderie-only; item labels are CHILDREN of the cards,
-- so scrolling and clipping happen naturally with MM2's inventory.
local Players=game:GetService('Players')
local HttpService=game:GetService('HttpService')
local UIS=game:GetService('UserInputService')
local pg=Players.LocalPlayer:WaitForChild('PlayerGui')
local env=type(getgenv)=='function' and getgenv() or _G
if type(env.MM2ValuesStop)=='function' then pcall(env.MM2ValuesStop) end
for _,g in ipairs(pg:GetChildren()) do
 if g.Name=='MM2ValuesV7' then g:Destroy() end
end
local alive=true;local connections={};local tracked={};local values={}
local function conn(s,fn) local c=s:Connect(fn);connections[#connections+1]=c;return c end
local function norm(s) return tostring(s or ''):lower():gsub('[^%w]','') end
local function log(...) print('[MM2 V7]',...) end
local function getPrices()
 local ok,t=pcall(function() return HttpService:JSONDecode(game:HttpGet('https://raw.githubusercontent.com/zeebinski/MM2-Values/main/values.json',true)) end)
 if not ok or type(t)~='table' then warn('[MM2 V7] Price file could not load');return end
 local n=0
 for k,v in pairs(t.items or {}) do
  if type(v)=='number' then values[norm(k)]=v;n+=1 end
 end
 log('Traderie entries:',n)
end
getPrices()
local root=Instance.new('ScreenGui');root.Name='MM2ValuesV7';root.ResetOnSpawn=false;root.DisplayOrder=9000;root.Parent=pg
local function new(kind,parent,props)
 local o=Instance.new(kind)
 for k,v in pairs(props or {}) do o[k]=v end
 o.Parent=parent;return o
end
local bar=new('Frame',root,{Size=UDim2.fromOffset(215,31),Position=UDim2.fromOffset(285,8),BackgroundColor3=Color3.fromRGB(24,27,32),BorderSizePixel=0,Active=true})
new('UICorner',bar,{CornerRadius=UDim.new(0,6)})
local stat=new('TextLabel',bar,{Size=UDim2.new(1,-37,1,0),Position=UDim2.fromOffset(8,0),BackgroundTransparency=1,Text='MM2 Values V7',TextColor3=Color3.fromRGB(127,235,156),Font=Enum.Font.GothamBold,TextSize=12,TextXAlignment=Enum.TextXAlignment.Left})
local x=new('TextButton',bar,{Size=UDim2.fromOffset(29,27),Position=UDim2.new(1,-32,0,2),BackgroundTransparency=1,Text='X',TextColor3=Color3.fromRGB(250,120,120),TextSize=16,Font=Enum.Font.GothamBold})
local drag,start,orig=false,nil,nil
conn(bar.InputBegan,function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 then drag=true;start=i.Position;orig=bar.Position end end)
conn(UIS.InputChanged,function(i) if drag and i.UserInputType==Enum.UserInputType.MouseMovement then local d=i.Position-start;bar.Position=UDim2.new(orig.X.Scale,orig.X.Offset+d.X,orig.Y.Scale,orig.Y.Offset+d.Y) end end)
conn(UIS.InputEnded,function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 then drag=false end end)
local function stop()
 if not alive then return end;alive=false
 for _,c in ipairs(connections) do c:Disconnect() end
 for card,e in pairs(tracked) do
  if e.label and e.label.Parent then e.label:Destroy() end
  tracked[card]=nil
 end
 root:Destroy();env.MM2ValuesStop=nil;log('Stopped')
end
conn(x.MouseButton1Click,stop);env.MM2ValuesStop=stop
local invalid={['season 1']=true,classic=true,holiday=true,weapons=true,powers=true,emotes=true,radios=true,pets=true,inventory=true,shop=true,['crafting station']=true,view=true,['enter code']=true,redeem=true,effects=true,['default knife']=false,['default gun']=false}
local function relevant(o)
 local p=o;while p and p~=pg do
  local n=p.Name:lower()
  if n:find('inventory',1,true) or n:find('weapons',1,true) or n:find('trade',1,true) then return true end
  p=p.Parent
 end
 return false
end
local function validText(t)
 if not (t:IsA('TextLabel') or t:IsA('TextButton')) then return nil end
 if t.Name=='MM2V7Price' or not relevant(t) then return nil end
 local s=t.Text:gsub('^%s+',''):gsub('%s+$','')
 if s=='' or #s>48 or invalid[s:lower()]==true or s:lower()=='n/a' or s:match('^%d+$') then return nil end
 return s
end
local function imageSibling(card)
 for _,child in ipairs(card:GetChildren()) do
  if (child:IsA('ImageLabel') or child:IsA('ImageButton')) and child.Image~='' then return true end
 end
 return false
end
local function cardFor(t)
 local p=t.Parent
 for _=1,3 do
  if not p or p==pg or not p:IsA('GuiObject') then break end
  local s=p.AbsoluteSize
  if s.X>=55 and s.X<=185 and s.Y>=60 and s.Y<=195 and imageSibling(p) then return p end
  p=p.Parent
 end
end
local function check(t)
 if not alive then return end
 local name=validText(t);if not name then return end
 local card=cardFor(t);if not card then return end
 local entry=tracked[card]
 if entry then
  -- Prefer the bottom text caption; do not create multiple labels per card.
  if t.AbsolutePosition.Y>=entry.source.AbsolutePosition.Y then entry.source=t end
  return
 end
 -- Crucially, attach to item TILE rather than free-floating ScreenGui.
 local label=new('TextLabel',card,{Name='MM2V7Price',Size=UDim2.fromOffset(54,17),Position=UDim2.fromOffset(3,3),BackgroundColor3=Color3.fromRGB(12,12,15),BackgroundTransparency=.12,BorderSizePixel=0,TextColor3=Color3.fromRGB(255,228,115),Font=Enum.Font.GothamBold,TextSize=11,ZIndex=math.max(card.ZIndex+5,t.ZIndex+3),Text='N/A'})
 new('UICorner',label,{CornerRadius=UDim.new(0,2)})
 tracked[card]={label=label,source=t}
 local value=values[norm(name)]
 label.Text=value==nil and 'N/A' or tostring(value)
end
-- Only one startup traversal, instead of scanning the entire game every 0.35s.
for _,o in ipairs(pg:GetDescendants()) do
 if o:IsA('TextLabel') or o:IsA('TextButton') then check(o) end
end
conn(pg.DescendantAdded,function(o)
 if not alive or o:IsDescendantOf(root) then return end
 if o:IsA('TextLabel') or o:IsA('TextButton') then
  task.defer(function()if alive then check(o) end end)
 elseif o:IsA('ImageLabel') or o:IsA('ImageButton') then
  local p=o.Parent
  task.defer(function()
   if not alive or not p then return end
   for _,sibling in ipairs(p:GetChildren()) do
    if sibling:IsA('TextLabel') or sibling:IsA('TextButton') then check(sibling) end
   end
  end)
 end
end)
-- Low-frequency sync: only already tracked cards. Each tile handles its own movement.
task.spawn(function()
 while alive do
  local count=0;local changed=0
  for card,e in pairs(tracked) do
   if not card.Parent or not e.source.Parent then
    if e.label.Parent then e.label:Destroy() end
    tracked[card]=nil
   else
    local name=validText(e.source)
    local v=name and values[norm(name)]
    local text=v==nil and 'N/A' or tostring(v)
    if e.label.Text~=text then e.label.Text=text;changed+=1 end
    count+=1
   end
  end
  stat.Text='MM2 Values | '..count..' cards'
  task.wait(.65)
 end
end)
log('Running; tile-anchored price labels:',(function()local n=0;for _ in pairs(tracked)do n+=1 end;return n end)())
