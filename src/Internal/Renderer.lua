local Util = require('Internal.Util')
local Renderer = {}
Renderer.__index = Renderer
function Renderer.new()
    assert(Drawing and type(Drawing.new)=='function', 'Iris Drawing requires Drawing.new')
    local self = setmetatable({pools={Square={},Text={}}, used={Square=0,Text=0}}, Renderer)
    local ok, err = pcall(function()
        self.measure = Drawing.new('Text')
        self.measure.Visible=false
        self.measure.Font=2
        self.measure.Size=15
    end)
    if not ok then self:Destroy(); error('Drawing Text is unsupported: '..tostring(err)) end
    return self
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
        object = Drawing.new(kind)
        self.pools[kind][index] = object
        if kind=='Square' then object.Filled=true else object.Font=2; object.Center=false; object.Outline=false end
    end
    object.ZIndex=z or 10
    object.Transparency=self.alpha
    object.Visible=true
    return object
end
function Renderer:Rect(r, color, clip, z, opacity)
    local visible = Util.intersect(r,clip)
    if not visible or visible.w <= 0 or visible.h <= 0 then return end
    local d = self:Acquire('Square',z)
    d.Position=Vector2.new(visible.x,visible.y)
    d.Size=Vector2.new(visible.w,visible.h)
    d.Color=color
    d.Transparency=self.alpha*(opacity or 1)
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
    self.measure.Text=text
    self.measure.Size=size or 15
    return self.measure.TextBounds.X
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
    self.measure.Text=text; self.measure.Size=size
    local bounds=self.measure.TextBounds
    local r=Util.rect(x,y,bounds.X,bounds.Y)
    if not Util.contains(r,clip) then return end
    local d=self:Acquire('Text',z)
    d.Position=Vector2.new(x,y); d.Size=size; d.Text=text; d.Color=color
end
function Renderer:Finish()
    for kind,pool in pairs(self.pools) do
        for i=self.used[kind]+1,#pool do pool[i].Visible=false end
    end
end
function Renderer:Destroy()
    if self.measure then self.measure:Remove(); self.measure=nil end
    for _,pool in pairs(self.pools) do for _,d in ipairs(pool) do d:Remove() end end
    self.pools={Square={},Text={}}
end
return Renderer
