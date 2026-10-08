local Util = require('Internal.Util')
local Renderer = {}
Renderer.__index = Renderer
function Renderer.new()
    assert(Drawing and type(Drawing.new)=='function', 'Iris Drawing requires Drawing.new')
    local self = setmetatable({pools={Square={},Text={},Circle={},Triangle={}}, used={Square=0,Text=0,Circle=0,Triangle=0},
        create=Drawing.new}, Renderer)
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
    object[property]=value
end
function Renderer:Get(object,property)
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
    for kind in pairs(self.used) do self.used[kind]=0 end
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
        if kind=='Square' or kind=='Circle' or kind=='Triangle' then
            self:Set(object,'Filled',true); self:Set(object,'Thickness',1)
            if kind=='Circle' then pcall(function() self:Set(object,'NumSides',64) end) end
        elseif kind=='Text' then self:Set(object,'Font',2); self:Set(object,'Center',false); self:Set(object,'Outline',false) end
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
    -- Synapse Drawing Transparency is opacity: 1=opaque, 0=invisible.
    self:Set(d,'Transparency',self.alpha*(opacity or 1))
    self:Set(d,'Visible',true)
end
function Renderer:Round(r, radius, color, clip, z, opacity)
    radius=math.max(0,math.min(radius,r.w/2,r.h/2))
    if radius < 1 then return self:Rect(r,color,clip,z,opacity) end
    -- Native circles keep small knobs smooth. Partially clipped disks use bands.
    if math.abs(r.w-radius*2)<.001 and math.abs(r.h-radius*2)<.001 and Util.contains(r,clip) then
        local d=self:Acquire('Circle',z)
        self:Set(d,'Position',Vector2.new(r.x+radius,r.y+radius))
        self:Set(d,'Radius',radius); self:Set(d,'Color',color)
        self:Set(d,'Transparency',self.alpha*(opacity or 1)); self:Set(d,'Visible',true)
        return
    end
    self:Rect(Util.rect(r.x,r.y+radius,r.w,r.h-radius*2),color,clip,z,opacity)
    -- Non-overlapping bands prevent alpha seams from overlapping primitives.
    local y=0
    while y < radius do
        local h=math.min(1,radius-y)
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
function Renderer:Cursor(p)
    -- Put the pointer in the same Drawing canvas as the interface.
    local outer=self:Acquire('Triangle',90)
    self:Set(outer,'PointA',p)
    self:Set(outer,'PointB',Vector2.new(p.X,p.Y+17))
    self:Set(outer,'PointC',Vector2.new(p.X+12,p.Y+12))
    self:Set(outer,'Color',Color3.new(1,1,1))
    self:Set(outer,'Transparency',1); self:Set(outer,'Visible',true)
    local inner=self:Acquire('Triangle',91)
    self:Set(inner,'PointA',Vector2.new(p.X+2,p.Y+4))
    self:Set(inner,'PointB',Vector2.new(p.X+2,p.Y+14))
    self:Set(inner,'PointC',Vector2.new(p.X+9,p.Y+11))
    self:Set(inner,'Color',Color3.new(0,0,0))
    self:Set(inner,'Transparency',1); self:Set(inner,'Visible',true)
end
function Renderer:Finish()
    for kind,pool in pairs(self.pools) do
        for i=self.used[kind]+1,#pool do self:Set(pool[i],'Visible',false) end
    end
end
function Renderer:Destroy()
    if self.measure then self.measure:Remove(); self.measure=nil end
    for _,pool in pairs(self.pools) do for _,d in ipairs(pool) do d:Remove() end end
    self.pools={Square={},Text={},Circle={},Triangle={}}
end
return Renderer
