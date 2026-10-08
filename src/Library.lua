local Util=require('Internal.Util')
local Runtime=require('Internal.Runtime')
local Controls=require('Controls.Model')
local UI={Flags={},_flags={},_controls={},_destroyed=false,Version='1.0.8'}
local Window={}; Window.__index=Window
local Section={}; Section.__index=Section
local function options(opts,allowed)
    assert(type(opts)=='table','Expected an options table')
    for key in pairs(opts) do assert(allowed[key],'Unknown option: '..tostring(key)) end
end
local function vector(value,name)
    assert(typeof(value)=='Vector2',name..' must be Vector2')
    Util.number(value.X,name..'.X'); Util.number(value.Y,name..'.Y'); return value
end
function UI:_Runtime()
    if not self._runtime then self._runtime=Runtime.new(self) end
    return self._runtime
end
function UI:CreateWindow(opts)
    Util.live(self); options(opts,{Name=true,Size=true,Position=true,ToggleKey=true})
    assert(not self._window,'Version 1 supports one window per UI instance')
    local name=Util.clean(opts.Name or 'Iris',256)
    local size=vector(opts.Size or Vector2.new(480,560),'Size')
    assert(size.X>=320 and size.Y>=180,'Size minimum is 320 x 180')
    local toggle=opts.ToggleKey or 'RightShift'
    assert(type(toggle)=='string' and (toggle=='None' or Enum.KeyCode[toggle]) and toggle~='Unknown' and toggle~='Escape','ToggleKey must be a KeyCode name or None')
    local position=opts.Position and vector(opts.Position,'Position')
    local rt=self:_Runtime(); local view=rt:Viewport()
    position=position or Vector2.new(math.max(0,(view.X-size.X)/2),math.max(0,(view.Y-size.Y)/2))
    local w=setmetatable({UI=self,Name=name,RequestedSize=size,Size=size,Position=position,Visible=true,Minimized=false,Sections={},Scroll=0,MaxScroll=0},Window)
    self._toggleKey=toggle; self._window=w; rt.window=w; rt:ClampWindow()
    -- Paint during the caller's execution, before any deferred engine callback.
    rt.alpha=.35; rt.height=math.min(160,w.Size.Y)
    local ok,message=pcall(rt.Draw,rt)
    if not ok then
        rt:Destroy(); self._runtime=nil; self._window=nil
        error('Iris Drawing first frame failed: '..tostring(message))
    end
    rt:Dirty(); return w
end
function Window:AddSection(name)
    Util.live(self.UI)
    local section=setmetatable({UI=self.UI,Window=self,Name=Util.clean(name,256),Controls={}},Section)
    table.insert(self.Sections,section); self.UI._runtime:Dirty(); return section
end
function Window:SetVisible(visible)
    Util.live(self.UI); assert(type(visible)=='boolean','Visible must be boolean')
    if visible==self.Visible then return self end
    self.Visible=visible; self.UI._runtime:CancelInteraction(true)
    if not self.UI._destroyed then self.UI._runtime:Dirty() end
    return self
end
function Window:SetMinimized(minimized)
    Util.live(self.UI); assert(type(minimized)=='boolean','Minimized must be boolean')
    self.Minimized=minimized; self.UI._runtime:CancelInteraction(true)
    if not self.UI._destroyed then self.UI._runtime:ClampWindow(); self.UI._runtime:Dirty() end
    return self
end
function Window:SetSize(size)
    Util.live(self.UI); vector(size,'Size'); assert(size.X>=320 and size.Y>=180,'Size minimum is 320 x 180')
    self.RequestedSize=size; self.UI._runtime:CancelInteraction(true)
    if not self.UI._destroyed then self.UI._runtime:ClampWindow(); self.UI._runtime:Dirty() end
    return self
end
function Window:Destroy() self.UI:Destroy() end
for _,kind in ipairs({'Button','Toggle','Slider','Dropdown','MultiDropdown','Textbox','Keybind','ColorPicker','Label','Separator'}) do
    Section['Add'..kind]=function(section,opts)
        local c=Controls.Create(section,kind,opts)
        if kind=='Toggle' then c._visual=c.Value and 1 or 0
        elseif kind=='Slider' then c._visual=(c.Value-c.Min)/(c.Max-c.Min) end
        return c
    end
end
function UI:GetFlag(name)
    Util.live(self); assert(self._flags[name],'Unknown Flag: '..tostring(name))
    return self._flags[name]:GetValue()
end
function UI:SetFlag(name,value,silent)
    Util.live(self); assert(self._flags[name],'Unknown Flag: '..tostring(name))
    self._flags[name]:SetValue(value,silent); return self
end
function UI:GetConfig()
    Util.live(self)
    local flags={}
    for name,c in pairs(self._flags) do
        local v=c:GetValue()
        if c.Kind=='ColorPicker' then v={v.R,v.G,v.B} end
        flags[name]=v
    end
    return {Version=1,Flags=flags}
end
function UI:LoadConfig(config,silent)
    Util.live(self)
    assert(type(config)=='table' and config.Version==1 and type(config.Flags)=='table','Config must be {Version=1, Flags={...}}')
    for key in pairs(config) do assert(key=='Version' or key=='Flags','Unknown config field') end
    local values={}
    for name,value in pairs(config.Flags) do
        local c=self._flags[name]; assert(c,'Unknown Flag: '..tostring(name))
        if c.Kind=='ColorPicker' then
            assert(type(value)=='table' and #value==3,'Color config must be {r,g,b}')
            for key in pairs(value) do assert(key==1 or key==2 or key==3,'Color config must be an RGB array') end
            for i=1,3 do Util.number(value[i],'RGB'); assert(value[i]>=0 and value[i]<=1,'RGB values must be in [0,1]') end
            value=Color3.new(value[1],value[2],value[3])
        end
        values[c]=c:Validate(value)
    end
    local changed={}
    -- Stable creation order, never arbitrary pairs order, for callback dispatch.
    for _,c in ipairs(self._controls) do
        if values[c]~=nil and not Util.equal(c.Value,values[c]) then table.insert(changed,c) end
    end
    local rt=self._runtime
    if rt then rt:Blur(false); rt:ClosePopup(); rt.capture=nil end
    for _,c in ipairs(changed) do c:_Commit(values[c]) end
    for _,c in ipairs(changed) do
        if self._destroyed then break end
        if c.Kind=='Keybind' then rt:ReleaseKey(c) end
        if not silent and not self._destroyed then c:_Notify() end
    end
    return self
end
function UI:Notify(opts)
    Util.live(self); options(opts,{Title=true,Content=true,Duration=true})
    self:_Runtime():Notify(opts); return self
end
function UI:Destroy()
    if self._destroyed then return end
    self._destroyed=true
    if self._runtime then self._runtime:Destroy() end
    for _,c in ipairs(self._controls) do c.Callback=nil; c.OnChanged=nil; c._row=nil; c._anchor=nil end
    if self._window then
        for _,section in ipairs(self._window.Sections) do section.Controls={} end
        self._window.Sections={}
    end
    self._runtime=nil; self._window=nil; self._flags={}; self._controls={}; self.Flags={}
end
return UI
