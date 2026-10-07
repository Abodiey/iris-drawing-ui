local Util = require('Internal.Util')
local Renderer = {}
Renderer.__index = Renderer
function Renderer.new()
    assert(Drawing and type(Drawing.new)=='function', 'Iris Drawing requires Drawing.new')
    local self = setmetatable({pools={Square={},Text={}}, used={Square=0,Text=0},
        create=Drawing.new,
        setProperty=type(setrenderproperty)=='function' and setrenderproperty or nil,
        getProperty=type(getrenderproperty)=='function' and getrenderproperty or nil}, Renderer)
    local ok, err = pcall(function()
        self.measure = self.create('Text')
        self:Set(self.measure,'Visible',false)
        self:Set(self.measure,'Font',2)
        self:Set(self.measure,'Size',15)
    end)
    if not ok then self:Destroy(); error('Drawing Text is unsupported: '..tostring(err)) end
    return self
end
function Renderer:Set(object,property,value)
    if self.setProperty then self.setProperty(object,property,value)
    else object[property]=value end
end
function Renderer:Get(object,property)
    if self.getProperty then return self.getProperty(object,property) end
    return object[property]
end
function Renderer:Bounds(text,size)
    self:Set(self.measure,'Size',size or 15)
    self:Set(self.measure,'Text',text)
    local bounds=self:Get(self.measure,'TextBounds')
    assert(typeof(bounds)=='Vector2','Drawing TextBounds must return Vector2')
    return bounds
end
function Renderer:Begin(alpha)
    self.used.Square, self.used.Text = 0, 0
    self.alpha = alpha or 1
end
function Renderer:Acquire(kind, z)
    local index = self.used[kind]+1
    self.used[kind] = index
    local object = self.pools[kind][index]
    if not object then
        object = self.create(kind)
        self.pools[kind][index] = object
        self:Set(object,'Visible',false)
        if kind=='Square' then self:Set(object,'Filled',true)
        else self:Set(object,'Font',2); self:Set(object,'Center',false); self:Set(object,'Outline',false) end
    end
    self:Set(object,'ZIndex',z or 10)
    return object
end
function Renderer:Rect(r, color, clip, z, opacity)
    local visible = Util.intersect(r,clip)
    if not visible or visible.w <= 0 or visible.h <= 0 then return end
    local d = self:Acquire('Square',z)
    self:Set(d,'Position',Vector2.new(visible.x,visible.y))
    self:Set(d,'Size',Vector2.new(visible.w,visible.h))
    self:Set(d,'Color',color)
    self:Set(d,'Transparency',self.alpha*(opacity or 1))
    self:Set(d,'Visible',true)
end
function Renderer:Round(r, radius, color, clip, z, opacity)
    radius=math.max(0,math.min(radius,r.w/2,r.h/2))
    if radius < 1 then return self:Rect(r,color,clip,z,opacity) end
    self:Rect(Util.rect(r.x,r.y+radius,r.w,r.h-radius*2),color,clip,z,opacity)
    -- Non-overlapping bands prevent alpha seams from overlapping primitives.
    local y=0
    while y < radius do
        local h=math.min(2,radius-y)
        local inset=radius-math.sqrt(math.max(0,radius*radius-(radius-y-h/2)^2))
        self:Rect(Util.rect(r.x+inset,r.y+y,r.w-inset*2,h),color,clip,z,opacity)
        self:Rect(Util.rect(r.x+inset,r.y+r.h-y-h,r.w-inset*2,h),color,clip,z,opacity)
        y=y+h
    end
end
function Renderer:Width(text, size)
    return self:Bounds(text,size).X
end
function Renderer:Fit(text, width, size)
    if self:Width(text,size)<=width then return text end
    local suffix='...'
    if self:Width(suffix,size)>width then return '' end
    local lo,hi=0,utf8.len(text)
    while lo<hi do
        local mid=math.ceil((lo+hi)/2)
        if self:Width(Util.prefix(text,mid)..suffix,size)<=width then lo=mid else hi=mid-1 end
    end
    return Util.prefix(text,lo)..suffix
end
function Renderer:Text(text, x, y, color, width, clip, z, size)
    size=size or 15
    text=self:Fit(text,math.max(0,width),size)
    if text=='' then return end
    local bounds=self:Bounds(text,size)
    local r=Util.rect(x,y,bounds.X,bounds.Y)
    if not Util.contains(r,clip) then return end
    local d=self:Acquire('Text',z)
    self:Set(d,'Position',Vector2.new(x,y)); self:Set(d,'Size',size)
    self:Set(d,'Text',text); self:Set(d,'Color',color)
    self:Set(d,'Transparency',self.alpha); self:Set(d,'Visible',true)
end
function Renderer:Finish()
    for kind,pool in pairs(self.pools) do
        for i=self.used[kind]+1,#pool do self:Set(pool[i],'Visible',false) end
    end
end
function Renderer:Destroy()
    if self.measure then self.measure:Remove(); self.measure=nil end
    for _,pool in pairs(self.pools) do for _,d in ipairs(pool) do d:Remove() end end
    self.pools={Square={},Text={}}
end
return Renderer
