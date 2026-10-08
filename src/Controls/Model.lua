local Util = require('Internal.Util')
local Theme = require('Internal.Theme')
local Controls = {}
local Control = {}; Control.__index=Control
local common={Name=true,Flag=true,Default=true,Callback=true}
local extras={Slider={Min=true,Max=true,Step=true},Dropdown={Options=true},MultiDropdown={Options=true},Textbox={Placeholder=true,MaxLength=true},Keybind={OnChanged=true},ColorPicker={},Toggle={},Button={},Label={},Separator={}}
local valueKinds={Toggle=true,Slider=true,Dropdown=true,MultiDropdown=true,Textbox=true,Keybind=true,ColorPicker=true}
function Control:Validate(value)
    local kind=self.Kind
    if kind=='Toggle' then assert(type(value)=='boolean','Toggle value must be boolean')
    elseif kind=='Slider' then
        Util.number(value,'Slider value')
        value=Util.clamp(value,self.Min,self.Max)
        value=self.Min+math.floor((value-self.Min)/self.Step+0.5)*self.Step
        value=Util.clamp(value,self.Min,self.Max)
        value=tonumber(string.format('%.10g',value))
    elseif kind=='Textbox' then value=Util.clean(value,self.MaxLength)
    elseif kind=='Keybind' then
        Util.string(value,'Keybind value')
        assert(value=='None' or (Enum.KeyCode[value] and value~='Unknown' and value~='Escape'), 'Keybind must be a KeyCode name or None (Escape cancels capture)')
        assert(value=='None' or value~=self.UI._toggleKey,'Keybind conflicts with window ToggleKey')
    elseif kind=='ColorPicker' then
        assert(typeof(value)=='Color3','ColorPicker value must be Color3')
        Util.number(value.R,'Red'); Util.number(value.G,'Green'); Util.number(value.B,'Blue')
        value=Color3.new(Util.clamp(value.R,0,1),Util.clamp(value.G,0,1),Util.clamp(value.B,0,1))
    elseif kind=='Dropdown' then
        Util.string(value,'Dropdown value')
        local found=#self.Options==0 and value==''
        for _,item in ipairs(self.Options) do if value==item then found=true end end
        assert(found,'Dropdown value is not in Options')
    elseif kind=='MultiDropdown' then
        assert(type(value)=='table','MultiDropdown value must be an array')
        local selected={}
        for key in pairs(value) do assert(type(key)=='number' and key%1==0 and key>=1 and key<=#value,'MultiDropdown value must be a dense array') end
        for _,item in ipairs(value) do
            Util.string(item,'Selection'); assert(not selected[item],'Duplicate selection')
            local found=false
            for _,option in ipairs(self.Options) do if item==option then found=true; break end end
            assert(found,'Selection is not in Options'); selected[item]=true
        end
        value={}
        for _,option in ipairs(self.Options) do if selected[option] then table.insert(value,option) end end
    else error('This control has no value') end
    return value
end
function Control:GetValue() Util.live(self.UI); assert(valueKinds[self.Kind],'This control has no value'); return Util.copy(self.Value) end
function Control:_Commit(value)
    self.Value=value
    if self.Flag then self.UI.Flags[self.Flag]=Util.copy(value) end
    local rt=self.UI._runtime
    if self.Kind=='ColorPicker' and rt.popup and rt.popup.control==self then
        local drag=rt.drag
        if not drag or drag.control~=self or (drag.role~='sv' and drag.role~='hue') then rt.popup.hue=self.Value:ToHSV() end
    end
    rt:Animate(self)
    self.UI._runtime:Dirty()
end
function Control:_Notify()
    local callback=self.Callback
    if self.Kind=='Keybind' then callback=self.OnChanged end
    Util.safe(callback, self:GetValue())
end
function Control:SetValue(value,silent)
    Util.live(self.UI)
    value=self:Validate(value)
    if Util.equal(value,self.Value) then return self end
    local rt=self.UI._runtime
    if rt.edit==self then rt:Blur(false) end
    self:_Commit(value)
    if self.Kind=='Keybind' then rt:ReleaseKey(self) end
    if not silent and not self.UI._destroyed then self:_Notify() end
    return self
end
function Control:SetText(text)
    Util.live(self.UI); assert(self.Kind=='Label','SetText is only for labels')
    self.Name=Util.clean(text,512); self.UI._runtime:Dirty(); return self
end
function Control:SetOptions(options,silent)
    Util.live(self.UI)
    assert(self.Kind=='Dropdown' or self.Kind=='MultiDropdown','SetOptions is only for dropdowns')
    options=Util.options(options)
    local value=self.Value
    if self.Kind=='Dropdown' then
        local found=false; for _,item in ipairs(options) do if value==item then found=true end end
        if not found then value=options[1] or '' end
    else
        value={}
        for _,item in ipairs(options) do for _,old in ipairs(self.Value) do if item==old then table.insert(value,item) end end end
    end
    self.Options=options
    self.UI._runtime:ClosePopup()
    self:SetValue(value,silent); self.UI._runtime:Dirty(); return self
end
function Controls.Create(section,kind,opts)
    local ui=section.UI; Util.live(ui)
    assert(type(opts)=='table','Control requires an options table')
    for key in pairs(opts) do assert(common[key] or extras[kind][key], 'Unknown '..kind..' option: '..tostring(key)) end
    assert(opts.Callback==nil or type(opts.Callback)=='function','Callback must be a function')
    if not valueKinds[kind] then assert(opts.Flag==nil and opts.Default==nil,kind..' does not support Flag or Default') end
    if kind=='Label' or kind=='Separator' then assert(opts.Callback==nil,kind..' does not support Callback') end
    local c=setmetatable({UI=ui,Section=section,Kind=kind,Name=Util.clean(opts.Name or (kind=='Separator' and '' or error('Name is required')),512),Callback=opts.Callback,Flag=opts.Flag},Control)
    if c.Flag~=nil then
        Util.string(c.Flag,'Flag'); assert(#c.Flag>0,'Flag cannot be empty')
        assert(not ui._flags[c.Flag], 'Duplicate Flag: '..c.Flag)
    end
    local default=opts.Default
    if kind=='Slider' then
        c.Min=Util.number(opts.Min,'Min'); c.Max=Util.number(opts.Max,'Max'); assert(c.Max>c.Min,'Max must be greater than Min')
        c.Step=Util.number(opts.Step or 1,'Step'); assert(c.Step>0,'Step must be positive')
        if default==nil then default=c.Min end
    elseif kind=='Toggle' then if default==nil then default=false end
    elseif kind=='Dropdown' or kind=='MultiDropdown' then c.Options=Util.options(opts.Options); if default==nil then default=kind=='Dropdown' and (c.Options[1] or '') or {} end
    elseif kind=='Textbox' then
        c.Placeholder=Util.clean(opts.Placeholder or 'Enter text',256)
        c.MaxLength=Util.number(opts.MaxLength or 256,'MaxLength'); assert(c.MaxLength%1==0 and c.MaxLength>=1 and c.MaxLength<=4096,'MaxLength must be an integer from 1 to 4096')
        if default==nil then default='' end
    elseif kind=='Keybind' then
        assert(opts.OnChanged==nil or type(opts.OnChanged)=='function','OnChanged must be a function')
        c.OnChanged=opts.OnChanged; if default==nil then default='None' end
    elseif kind=='ColorPicker' then if default==nil then default=Color3.fromRGB(0,122,255) end end
    if valueKinds[kind] then c.Value=c:Validate(default) end
    local metrics=Theme.metrics
    local heights={Slider=metrics.sliderHeight,Toggle=metrics.toggleHeight,Button=metrics.buttonHeight,Separator=metrics.separatorHeight,Label=metrics.labelHeight}
    c.Height=heights[kind] or metrics.rowHeight
    if c.Flag then ui._flags[c.Flag]=c; ui.Flags[c.Flag]=Util.copy(c.Value) end
    table.insert(section.Controls,c); table.insert(ui._controls,c)
    ui._runtime:Dirty()
    return c
end
return Controls
