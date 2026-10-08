_G={}
-- Deterministic Roblox/Drawing model. This does not impersonate a live client.
Mock={drawings={},instances={},connections={},warnings={},time=0,mouse=nil}
local function signal()
    local s={listeners={}}
    function s:Connect(fn)
        local c={Connected=true}
        function c:Disconnect() self.Connected=false end
        c.fn=fn; table.insert(self.listeners,c); table.insert(Mock.connections,c); return c
    end
    function s:Fire(...)
        local copy={}; for i,c in ipairs(self.listeners) do copy[i]=c end
        for _,c in ipairs(copy) do if c.Connected then c.fn(...) end end
    end
    return s
end
Vector2={new=function(x,y) return setmetatable({X=x,Y=y},{__type='Vector2'}) end}
Mock.mouse=Vector2.new(0,0)
Mock.guiOrigin=Vector2.new(0,0)
UDim2={fromOffset=function(x,y) return {X=x,Y=y} end}
local colorMethods={}
function colorMethods:ToHSV()
    local max,min=math.max(self.R,self.G,self.B),math.min(self.R,self.G,self.B)
    local delta=max-min; local h=0
    if delta>0 then
        if max==self.R then h=((self.G-self.B)/delta)%6
        elseif max==self.G then h=(self.B-self.R)/delta+2
        else h=(self.R-self.G)/delta+4 end
        h=h/6
    end
    return h,max==0 and 0 or delta/max,max
end
local colorMeta={__type='Color3',__index=colorMethods,__eq=function(a,b) return math.abs(a.R-b.R)<1e-9 and math.abs(a.G-b.G)<1e-9 and math.abs(a.B-b.B)<1e-9 end}
Color3={}
function Color3.new(r,g,b) return setmetatable({R=r,G=g,B=b},colorMeta) end
function Color3.fromRGB(r,g,b) return Color3.new(r/255,g/255,b/255) end
function Color3.fromHSV(h,s,v)
    local sector=(h%1)*6; local i=math.floor(sector); local f=sector-i
    local p,q,t=v*(1-s),v*(1-f*s),v*(1-(1-f)*s)
    local colors={{v,t,p},{q,v,p},{p,v,t},{p,q,v},{t,p,v},{v,p,q}}
    local c=colors[i+1]; return Color3.new(c[1],c[2],c[3])
end
function typeof(v) return type(v)=='table' and (getmetatable(v) or {}).__type or type(v) end
Enum={KeyCode={},UserInputType={},ContextActionResult={Pass='Pass',Sink='Sink'},ContextActionPriority={High={Value=3000}}}
for word in ('None Unknown Escape Return KeypadEnter Backspace Delete RightShift LeftShift LeftControl RightControl Space Tab Insert Home End PageUp PageDown F1 F2 F3 F4 F5 F6 F7 F8 F9 F10 F11 F12 A B C D E F G H I J K L M N O P Q R S T U V W X Y Z One Two Three Four Five Six Seven Eight Nine Zero'):gmatch('%S+') do Enum.KeyCode[word]={Name=word} end
for _,name in ipairs({'Keyboard','MouseButton1','MouseButton2','MouseMovement','MouseWheel'}) do Enum.UserInputType[name]={Name=name} end
Drawing={}
function Drawing.new(kind)
    assert(kind=='Square' or kind=='Text' or kind=='Circle')
    local object={_props={Visible=false,Text='',Size=15},_kind=kind,Removed=false}
    function object:Remove() assert(not self.Removed,'Double Remove'); self.Removed=true end
    setmetatable(object,{__index=function(o,k)
        if k=='TextBounds' then return Vector2.new(utf8.len(o._props.Text)*o._props.Size*.53,o._props.Size+1) end
        return o._props[k]
    end,__newindex=function(o,k,v) o._props[k]=v end})
    table.insert(Mock.drawings,object); return object
end
local uis={InputBegan=signal(),InputChanged=signal(),InputEnded=signal(),WindowFocusReleased=signal()}
function uis:GetMouseLocation() return Mock.mouse end
function uis:GetFocusedTextBox() return Mock.focused end
local run={RenderStepped=signal()}
local workspace={CurrentCamera={ViewportSize=Vector2.new(1000,800)}}
local core={}
Mock.actions={}
local cas={}
function cas:BindActionAtPriority(name,fn,touch,priority,input)
    Mock.actions[name]={fn=fn,priority=priority,input=input}
end
function cas:UnbindAction(name) Mock.actions[name]=nil end
local services={UserInputService=uis,ContextActionService=cas,RunService=run,Workspace=workspace,CoreGui=core}
game={GetService=function(_,name) assert(services[name],name); return services[name] end}
Instance={}
function Instance.new(kind)
    assert(kind=='ScreenGui' or kind=='TextBox' or kind=='Frame','Unexpected GUI: '..kind)
    local o={_kind=kind,_props={Text='',CursorPosition=-1,SelectionStart=-1},_signals={},Destroyed=false,FocusLost=signal()}
    function o:GetPropertyChangedSignal(name)
        if not self._signals[name] then self._signals[name]=signal() end
        return self._signals[name]
    end
    function o:CaptureFocus() Mock.focused=self end
    function o:ReleaseFocus()
        if Mock.focused==self then Mock.focused=nil; self.FocusLost:Fire(false) end
    end
    function o:Destroy()
        assert(not self.Destroyed,'Double Destroy'); self.Destroyed=true; self:ReleaseFocus()
        for _,child in ipairs(Mock.instances) do if child.Parent==self and not child.Destroyed then child:Destroy() end end
    end
    setmetatable(o,{__index=function(obj,k)
        if obj._kind=='ScreenGui' and k=='AbsolutePosition' then return Mock.guiOrigin end
        if obj._kind=='Frame' and (k=='AbsolutePosition' or k=='AbsoluteSize') then
            local key=k=='AbsolutePosition' and 'Position' or 'Size'; local value=obj._props[key] or {X=0,Y=0}
            if k=='AbsolutePosition' and obj.Parent then
                local origin=obj.Parent.AbsolutePosition
                return Vector2.new(value.X+origin.X,value.Y+origin.Y)
            end
            return Vector2.new(value.X,value.Y)
        end
        return obj._props[k]
    end,__newindex=function(obj,k,v)
        local old=obj._props[k]; obj._props[k]=v
        if old~=v and obj._signals[k] then obj._signals[k]:Fire() end
    end})
    table.insert(Mock.instances,o); return o
end
warn=function(text) table.insert(Mock.warnings,text) end
os={clock=function() return Mock.time end}
function Mock.tick(count)
    for _=1,count or 1 do Mock.time=Mock.time+1/60; run.RenderStepped:Fire(1/60) end
end
function Mock.move(x,y)
    Mock.mouse=Vector2.new(x,y); uis.InputChanged:Fire({UserInputType=Enum.UserInputType.MouseMovement})
end
function Mock.click(x,y)
    Mock.move(x,y); uis.InputBegan:Fire({UserInputType=Enum.UserInputType.MouseButton1},false)
    uis.InputEnded:Fire({UserInputType=Enum.UserInputType.MouseButton1})
end

function Mock.press(key,processed)
    uis.InputBegan:Fire({UserInputType=Enum.UserInputType.Keyboard,KeyCode=Enum.KeyCode[key]},processed or false)
end
function Mock.release(key) uis.InputEnded:Fire({UserInputType=Enum.UserInputType.Keyboard,KeyCode=Enum.KeyCode[key]}) end
function Mock.wheel(z) uis.InputChanged:Fire({UserInputType=Enum.UserInputType.MouseWheel,Position={Z=z}}) end
function Mock.down(x,y)
    Mock.move(x,y); uis.InputBegan:Fire({UserInputType=Enum.UserInputType.MouseButton1},false)
end
function Mock.up() uis.InputEnded:Fire({UserInputType=Enum.UserInputType.MouseButton1}) end
function Mock.liveConnections()
    local n=0; for _,c in ipairs(Mock.connections) do if c.Connected then n=n+1 end end; return n
end
function Mock.visibleDrawings()
    local n=0; for _,d in ipairs(Mock.drawings) do if not d.Removed and d.Visible and (d.Transparency or 0)>0 then n=n+1 end end; return n
end
function Mock.focusLost() uis.WindowFocusReleased:Fire() end
function Mock.viewport(x,y) workspace.CurrentCamera.ViewportSize=Vector2.new(x,y); Mock.tick(1) end
