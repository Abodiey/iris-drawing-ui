local Util=require('Internal.Util')
local Renderer=require('Internal.Renderer')
local Views=require('Controls.Views')
local Runtime={}; Runtime.__index=Runtime
function Runtime.new(ui)
    local self=setmetatable({ui=ui,connections={},hits={},hitFrames={},hitCount=0,dirty=true,alpha=0,height=52,notifications={},held={},animations={},focused=true,pointer=Vector2.new(0,0)},Runtime)
    local ok,message=pcall(function()
        self.input=game:GetService('UserInputService')
        self.actionService=game:GetService('ContextActionService')
        self.renderService=game:GetService('RunService')
        self.workspace=game:GetService('Workspace')
        self.renderer=Renderer.new()
        self.gui=Instance.new('ScreenGui')
        self.gui.Name='IrisDrawingInput'; self.gui.IgnoreGuiInset=true; self.gui.ResetOnSpawn=false
        self.box=Instance.new('TextBox')
        self.box.Name='InvisibleInput'; self.box.BackgroundTransparency=1; self.box.TextTransparency=1
        self.box.TextStrokeTransparency=1; self.box.BorderSizePixel=0; self.box.ClearTextOnFocus=false
        self.box.MultiLine=false; self.box.Text=''; self.box.Size=UDim2.fromOffset(1,1)
        self.box.Position=UDim2.fromOffset(-10000,-10000); self.box.Parent=self.gui
        self.gui.Parent=game:GetService('CoreGui')
        self:Connect(self.gui:GetPropertyChangedSignal('AbsolutePosition'),function() self:Dirty() end)
        self:Connect(self.box:GetPropertyChangedSignal('Text'),function()
            if self.edit and not self.syncing then
                local value=Util.clean(self.box.Text,self.edit.MaxLength)
                if value~=self.box.Text then self.syncing=true; self.box.Text=value; self.syncing=false end
                self:Dirty()
            end
        end)
        self:Connect(self.box:GetPropertyChangedSignal('CursorPosition'),function() if self.edit then self:Dirty() end end)
        self:Connect(self.box:GetPropertyChangedSignal('SelectionStart'),function() if self.edit then self:Dirty() end end)
        self:Connect(self.box.FocusLost,function() if self.edit then self:Blur(true) end end)
        self:Connect(self.input.InputBegan,function(input,processed) self:Began(input,processed) end)
        self:Connect(self.input.InputChanged,function(input) self:Changed(input) end)
        self:Connect(self.input.InputEnded,function(input) self:Ended(input) end)
        self:Connect(self.input.WindowFocusReleased,function()
            self.focused=false; self:SetCursor(false); self:CancelInteraction(true)
        end)
        self:Connect(self.input.WindowFocused,function() self.focused=true; self.pointer=self:MousePosition(); self:Dirty() end)
        self.scrollAction='IrisDrawingWheel_'..tostring(self)
        self.actionService:BindActionAtPriority(self.scrollAction,function()
            if self.ui._destroyed then return Enum.ContextActionResult.Pass end
            local p=self:MousePosition()
            if self:OwnsPointer(p) then return Enum.ContextActionResult.Sink end
            return Enum.ContextActionResult.Pass
        end,false,Enum.ContextActionPriority.High.Value+100,Enum.UserInputType.MouseWheel)
        self.lastRenderSignal=os.clock()
        self.lastUpdate=self.lastRenderSignal
        self:Connect(self.renderService.RenderStepped,function(dt)
            self.lastRenderSignal=os.clock()
            self:Frame(dt)
        end)
        self:StartWatchdog()
        self.pointer=self:MousePosition()
    end)
    if not ok then self:Destroy(); error('Iris Drawing initialization failed: '..tostring(message)) end
    return self
end
function Runtime:Frame(dt)
    if self.ui._destroyed then return end
    if type(dt)~='number' or dt~=dt or dt<=0 then dt=1/60 end
    self.lastUpdate=os.clock()
    local ok,message=pcall(self.Step,self,dt)
    if not ok then
        self:Dirty()
        message=tostring(message)
        if self.frameError~=message then warn('[Iris Drawing render] '..message) end
        self.frameError=message
    else self.frameError=nil end
    return ok,message
end
function Runtime:StartWatchdog()
    if not task or type(task.spawn)~='function' or type(task.wait)~='function' then return end
    -- One monitor, not a second active render loop: only step when the signal stalls.
    self.watchdog=task.spawn(function()
        local fallback=false
        while not self.ui._destroyed do
            task.wait(fallback and 1/60 or .25)
            if self.ui._destroyed then return end
            local now=os.clock()
            fallback=now-self.lastRenderSignal>=.25
            if fallback then self:Frame(now-self.lastUpdate) end
        end
    end)
end
function Runtime:Connect(signal,fn) table.insert(self.connections,signal:Connect(fn)) end
function Runtime:Dirty() self.dirty=true end
function Runtime:MousePosition()
    return self.input:GetMouseLocation()
end
function Runtime:SetCursor(active)
    if active then
        if not self.cursorOwned then
            self.savedMouseIcon=self.input.MouseIconEnabled
            self.cursorOwned=true
        end
        self.input.MouseIconEnabled=false
    elseif self.cursorOwned then
        self.input.MouseIconEnabled=self.savedMouseIcon
        self.cursorOwned=false; self.savedMouseIcon=nil
    end
end
function Runtime:OwnsPointer(p)
    return self:At(p)~=nil
end
function Runtime:Viewport()
    local camera=self.workspace.CurrentCamera
    return camera and camera.ViewportSize or Vector2.new(1280,720)
end
function Runtime:ClosePopup() if self.popup then self.popup=nil; self:Dirty() end end
function Runtime:ReleaseKey(c)
    if self.held[c] then self.held[c]=nil; Util.safe(c.Callback,false) end
end
function Runtime:CancelInteraction(commit)
    self.drag=nil; self.capture=nil; self:ClosePopup(); self:Blur(commit)
    local keys={}; for c in pairs(self.held) do table.insert(keys,c) end
    for _,c in ipairs(keys) do self:ReleaseKey(c) end
    self:Dirty()
end
function Runtime:Blur(commit)
    local c=self.edit
    if not c then return end
    self.edit=nil
    local value=self.box.Text
    self.box:ReleaseFocus()
    if commit and not self.ui._destroyed then c:SetValue(value) end
    self:Dirty()
end
function Runtime:Focus(c,field)
    if self.edit~=c then
        self:Blur(true); self:ClosePopup(); self.capture=nil
        if self.ui._destroyed then return end
        self.edit=c; self.box.Text=c.Value; self.box:CaptureFocus()
        self.box.CursorPosition=#self.box.Text+1; self.box.SelectionStart=-1
        self.editStart=1
    end
    self.editField=field
    if Util.inside(field,self.pointer) then
        self:SetCaret(self.pointer)
        self.box.SelectionStart=self.box.CursorPosition
        self.drag={role='textselect'}
    end
    self:Dirty()
end
function Runtime:SetCaret(pointer)
    if not self.edit or not self.editField then return end
    local text=self.box.Text
    local start=self.editStart or 1
    local relative=pointer.X-self.editField.x-8
    local chosen=start-1
    local prefix=''
    for byte,code in utf8.codes(text:sub(start)) do
        local character=utf8.char(code)
        local width=self.renderer:Width(prefix,13)
        local nextWidth=self.renderer:Width(prefix..character,13)
        if relative<(width+nextWidth)/2 then break end
        chosen=start+byte-2+#character
        prefix=prefix..character
    end
    self.box.CursorPosition=chosen+1
    self:Dirty()
end
function Runtime:DrawEditing(c,field,clip)
    local d,t=self.renderer,Views.Theme
    local text=self.box.Text
    -- Roblox cursor/selection offsets are UTF-8 byte offsets.
    local cursor=Util.clamp(self.box.CursorPosition-1,0,#text)
    while cursor>0 and not utf8.len(text:sub(1,cursor)) do cursor=cursor-1 end
    local prefix=text:sub(1,cursor)
    local available=field.w-16
    local start=1
    while d:Width(prefix,13)>available-2 and #prefix>0 do
        local nextByte=utf8.offset(text,2,start) or (#text+1)
        start=nextByte; prefix=text:sub(start,cursor)
    end
    self.editStart=start
    local remainder=text:sub(start)
    local visible=d:Fit(remainder,available,13)
    local shown=visible~=remainder and visible:sub(1,-4) or visible
    local selection=self.box.SelectionStart
    if selection>0 then
        local a,b=math.min(cursor,selection-1),math.max(cursor,selection-1)
        a=math.max(a,start-1); b=math.min(b,start-1+#shown)
        while a>0 and not utf8.len(text:sub(1,a)) do a=a-1 end
        while b>0 and not utf8.len(text:sub(1,b)) do b=b-1 end
        if b>a then
            local left=d:Width(text:sub(start,a),13)
            local right=d:Width(text:sub(start,b),13)
            d:Rect(Util.rect(field.x+8+left,field.y+4,math.min(available-left,right-left),19),t.accent,clip,14,.5)
        end
    end
    d:Text(visible,field.x+8,field.y+5,t.text,available,clip,15,13)
    local caret=d:Width(prefix,13)
    d:Rect(Util.rect(field.x+8+caret,field.y+5,1,18),t.white,clip,16)
end
function Runtime:Hit(rect,owner,role,clip,data)
    local w=self.window
    if w and (not w.Visible or w.Minimized) and (owner~=w or role=='scrollbar' or role=='content') then return end
    local visible=Util.intersect(rect,clip)
    if not visible then return end
    self.hitCount=self.hitCount+1
    local frame=self.hitFrames[self.hitCount]
    if not frame then
        frame=Instance.new('Frame')
        frame.Name='IrisDrawingHitRegion'
        frame.BackgroundTransparency=1; frame.BorderSizePixel=0
        frame.Active=false; frame.Selectable=false; frame.Visible=false
        frame.Parent=self.gui
        self.hitFrames[self.hitCount]=frame
    end
    -- CoreGui can report a nonzero origin even with IgnoreGuiInset enabled.
    -- Convert Drawing screen coordinates into the GUI's actual local space.
    local origin=self.hitOrigin
    frame.Position=UDim2.fromOffset(visible.x-origin.X,visible.y-origin.Y)
    frame.Size=UDim2.fromOffset(visible.w,visible.h)
    frame.Visible=true
    self.hits[self.hitCount]={frame=frame,owner=owner,role=role,data=data}
end
function Runtime:At(pointer)
    for i=self.hitCount,1,-1 do
        local hit=self.hits[i]
        local frame=hit.frame
        local position,size=frame.AbsolutePosition,frame.AbsoluteSize
        if pointer.X>=position.X and pointer.Y>=position.Y
            and pointer.X<position.X+size.X and pointer.Y<position.Y+size.Y then return hit end
    end
end
function Runtime:Hover()
    if self.dirty then self:Draw() end
    local hit=self:At(self.pointer)
    local owner,role,data=hit and hit.owner,hit and hit.role,hit and hit.data
    if owner~=self.hoverOwner or role~=self.hoverRole or data~=self.hoverData then
        self.hoverOwner,self.hoverRole,self.hoverData=owner,role,data; self:Dirty()
    end
end
function Runtime:Animate(c)
    local target
    if c.Kind=='Toggle' then target=c.Value and 1 or 0
    elseif c.Kind=='Slider' then target=(c.Value-c.Min)/(c.Max-c.Min) end
    if target then self.animations[c]=target end
end
function Runtime:Step(dt)
    if self.ui._destroyed then return end
    local view=self:Viewport()
    if not self.view or view.X~=self.view.X or view.Y~=self.view.Y then
        self.view=view
        if self.window then self:ClampWindow(); self:ClosePopup() end
        self:Dirty()
    end
    local w=self.window
    local targetAlpha=w and w.Visible and 1 or 0
    local targetHeight=w and (w.Minimized and 52 or w.Size.Y) or 52
    local ease=1-math.exp(-math.min(dt,.1)*20)
    if math.abs(self.alpha-targetAlpha)>.001 then self.alpha=self.alpha+(targetAlpha-self.alpha)*ease; self:Dirty()
    elseif self.alpha~=targetAlpha then self.alpha=targetAlpha; self:Dirty() end
    if math.abs(self.height-targetHeight)>.1 then self.height=self.height+(targetHeight-self.height)*ease; self:Dirty()
    elseif self.height~=targetHeight then self.height=targetHeight; self:Dirty() end
    for c,target in pairs(self.animations) do
        c._visual=c._visual+(target-c._visual)*ease
        if math.abs(c._visual-target)<.002 then c._visual=target; self.animations[c]=nil end
        self:Dirty()
    end
    local now=os.clock()
    for i=#self.notifications,1,-1 do
        local n=self.notifications[i]
        local target=now<n.expires and 1 or 0
        n.alpha=n.alpha+(target-n.alpha)*ease
        if target==0 and n.alpha<.01 then table.remove(self.notifications,i) end
        self:Dirty()
    end
    if self.dirty then self:Draw() end
end
function Runtime:ClampWindow()
    local w=self.window; if not w then return end
    local view=self:Viewport()
    w.Size=Vector2.new(math.min(w.RequestedSize.X,math.max(180,view.X-16)),math.min(w.RequestedSize.Y,math.max(100,view.Y-16)))
    w.Position=Vector2.new(Util.clamp(w.Position.X,0,math.max(0,view.X-w.Size.X)),Util.clamp(w.Position.Y,0,math.max(0,view.Y-(w.Minimized and 52 or w.Size.Y))))
end
function Runtime:Draw()
    self.dirty=false; self.hitCount=0
    self.hitOrigin=self.gui.AbsolutePosition
    local d,t,w=self.renderer,Views.Theme,self.window
    d:Begin(self.alpha)
    if w and self.alpha>.001 then
        local x,y,width=w.Position.X,w.Position.Y,w.Size.X
        local height=self.height
        local r=Util.rect(x,y,width,height)
        d:Round(Util.rect(x-3,y+2,width+6,height+3),15,Color3.new(0,0,0),nil,1,.22)
        d:Round(r,12,t.bg,nil,2,.97)
        d:Text(w.Name,x+18,y+17,t.text,width-106,r,4,17)
        local close=Util.rect(x+width-35,y+14,22,22)
        local minimize=Util.rect(x+width-65,y+14,22,22)
        d:Round(close,11,self.hoverRole=='close' and Color3.fromRGB(255,105,98) or Color3.fromRGB(255,95,87),r,4)
        d:Text('x',close.x+7,close.y+2,t.bg,12,r,5,13)
        d:Round(minimize,11,Color3.fromRGB(254,188,46),r,4)
        d:Text(w.Minimized and '+' or '-',minimize.x+6,minimize.y+2,t.bg,14,r,5,13)
        if w.Visible then
            self:Hit(Util.rect(x,y,width,52),w,'windowDrag')
            self:Hit(minimize,w,'minimize'); self:Hit(close,w,'close')
        end
        self.contentClip=Util.rect(x+12,y+56,width-24,math.max(0,height-68))
        local contentHeight=0
        for _,section in ipairs(w.Sections) do
            contentHeight=contentHeight+32
            for _,c in ipairs(section.Controls) do contentHeight=contentHeight+c.Height end
            contentHeight=contentHeight+12
        end
        w.MaxScroll=math.max(0,contentHeight-math.max(0,w.Size.Y-68))
        w.Scroll=Util.clamp(w.Scroll,0,w.MaxScroll)
        if self.contentClip.h>0 then
            self:Hit(self.contentClip,w,'content')
            local cy=y+56-w.Scroll
            for _,section in ipairs(w.Sections) do
                d:Text(section.Name,x+24,cy+7,t.muted,width-48,self.contentClip,10,12)
                cy=cy+32
                for _,c in ipairs(section.Controls) do
                    local row=Util.rect(x+12,cy,width-32,c.Height)
                    c._row=row
                    c._anchor=Util.rect(row.x+row.w-math.min(180,row.w*.45)-12,row.y+8,math.min(180,row.w*.45),28)
                    if Util.intersect(row,self.contentClip) then Views.Control(self,c,row,self.contentClip) end
                    cy=cy+c.Height
                end
                cy=cy+12
            end
            if w.MaxScroll>0 then
                local track=self.contentClip
                local thumb=math.max(24,track.h*track.h/contentHeight)
                local bar=Util.rect(x+width-8,track.y+(track.h-thumb)*w.Scroll/w.MaxScroll,3,thumb)
                d:Round(bar,1.5,t.muted,nil,20)
                self:Hit(Util.rect(bar.x-4,bar.y,11,bar.h),w,'scrollbar',nil,{track=track,thumb=thumb})
            end
            Views.Popup(self)
        end
    end
    d.alpha=1
    local viewport=self:Viewport()
    local ny=viewport.Y-16
    for i=#self.notifications,1,-1 do
        local n=self.notifications[i]
        local width=math.min(300,viewport.X-24)
        local r=Util.rect(viewport.X-width-12+(1-n.alpha)*20,ny-78,width,72)
        ny=ny-84
        d.alpha=n.alpha
        d:Round(r,10,t.card,nil,60,.97)
        d:Text(n.Title,r.x+14,r.y+10,t.text,width-28,r,61,15)
        d:Text(n.Content,r.x+14,r.y+37,t.muted,width-28,r,61,13)
    end
    local cursorActive=w and w.Visible and self.focused and (self.drag~=nil or self:OwnsPointer(self.pointer))
    self:SetCursor(cursorActive)
    if cursorActive then d:Cursor(self.pointer) end
    d:Finish()
    for i=self.hitCount+1,#self.hitFrames do self.hitFrames[i].Visible=false end
    for i=#self.hits,self.hitCount+1,-1 do self.hits[i]=nil end
end
function Runtime:OpenPopup(c)
    self:Blur(true); self.capture=nil
    if self.ui._destroyed then return end
    if self.popup and self.popup.control==c then self:ClosePopup()
    else self.popup={control=c,scroll=0}; self:Dirty() end
end
function Runtime:UpdateDrag()
    local drag=self.drag; if not drag then return end
    local p=self.pointer
    if drag.role=='textselect' then
        self:SetCaret(p)
    elseif drag.role=='windowDrag' then
        local w=self.window
        w.Position=Vector2.new(p.X-drag.dx,p.Y-drag.dy)
        self:ClampWindow(); self:Dirty()
    elseif drag.role=='slider' then
        local c,r=drag.control,drag.rect
        c:SetValue(c.Min+Util.clamp((p.X-r.x)/r.w,0,1)*(c.Max-c.Min))
    elseif drag.role=='sv' or drag.role=='hue' then
        local c,r=drag.control,drag.rect
        local popup=self.popup
        if not popup or popup.control~=c then self.drag=nil; return end
        local h,s,v=c.Value:ToHSV()
        h=popup.hue or h
        if drag.role=='sv' then s=Util.clamp((p.X-r.x)/r.w,0,1); v=1-Util.clamp((p.Y-r.y)/r.h,0,1)
        else h=Util.clamp((p.X-r.x)/r.w,0,1); popup.hue=h end
        c:SetValue(Color3.fromHSV(h,s,v)); self:Dirty()
    elseif drag.role=='scrollbar' then
        local w,r=self.window,drag.rect
        w.Scroll=Util.clamp((p.Y-r.track.y-drag.offset)/math.max(1,r.track.h-r.thumb),0,1)*w.MaxScroll
        self:Dirty()
    end
end
function Runtime:Began(input,processed)
    if self.ui._destroyed then return end
    local kind=input.UserInputType
    local keyboard=kind==Enum.UserInputType.Keyboard
    if keyboard then
        local key=input.KeyCode.Name
        if self.edit then
            if key=='Escape' then self:Blur(false)
            elseif key=='Return' or key=='KeypadEnter' then self:Blur(true) end
            return
        end
        if self.input:GetFocusedTextBox() then return end
        if self.capture then
            local c=self.capture
            if key=='Escape' then self.capture=nil
            elseif key=='Backspace' or key=='Delete' then self.capture=nil; c:SetValue('None')
            elseif key~=self.ui._toggleKey and key~='Unknown' then self.capture=nil; c:SetValue(key) end
            self:Dirty(); return
        end
        if key=='Escape' and self.popup then self:ClosePopup(); return end
        if processed then return end
        if self.window and key==self.ui._toggleKey then self.window:SetVisible(not self.window.Visible); return end
        local controls=self.ui._controls
        for _,c in ipairs(controls) do
            if c.Kind=='Keybind' and c.Value==key and not self.held[c] then
                self.held[c]=true; Util.safe(c.Callback,true)
                if self.ui._destroyed then return end
            end
        end
        return
    end
    if kind~=Enum.UserInputType.MouseButton1 then return end
    self.pointer=self:MousePosition()
    if self.dirty then self:Draw() end
    if self.popup and not Util.inside(self.popup.rect,self.pointer) then self:ClosePopup(); return end
    local hit=self:At(self.pointer)
    if self.edit and (not hit or hit.owner~=self.edit) then
        self:Blur(true)
        if self.ui._destroyed then return end
        if self.dirty then self:Draw(); hit=self:At(self.pointer) end
    end
    if not hit then self.capture=nil; self:Dirty(); return end
    local c,role=hit.owner,hit.role
    if role=='windowDrag' then
        self:ClosePopup(); self.capture=nil
        self.drag={role=role,dx=self.pointer.X-c.Position.X,dy=self.pointer.Y-c.Position.Y}
    elseif role=='minimize' then c:SetMinimized(not c.Minimized)
    elseif role=='close' then c:SetVisible(false)
    elseif role=='toggle' then self.capture=nil; c:SetValue(not c.Value)
    elseif role=='button' then self.capture=nil; Util.safe(c.Callback)
    elseif role=='slider' or role=='sv' or role=='hue' then
        self.capture=nil; self.drag={role=role,control=c,rect=hit.data}; self:UpdateDrag()
    elseif role=='dropdown' or role=='color' then self:OpenPopup(c)
    elseif role=='option' then
        if c.Kind=='Dropdown' then self:ClosePopup(); c:SetValue(hit.data)
        else
            local value=c:GetValue(); local index=nil
            for i,item in ipairs(value) do if item==hit.data then index=i end end
            if index then table.remove(value,index) else table.insert(value,hit.data) end
            c:SetValue(value)
        end
    elseif role=='textbox' then self:Focus(c,hit.data)
    elseif role=='keybind' then
        self:Blur(true); self:ClosePopup(); self.capture=c; self:ReleaseKey(c); self:Dirty()
    elseif role=='scrollbar' then
        self:ClosePopup(); self.capture=nil
        local r=hit.data
        local current=(r.track.h-r.thumb)*self.window.Scroll/math.max(1,self.window.MaxScroll)
        self.drag={role=role,rect=r,offset=self.pointer.Y-r.track.y-current}
    elseif role=='content' then self.capture=nil; self:Dirty() end
end
function Runtime:Changed(input)
    if self.ui._destroyed then return end
    if input.UserInputType==Enum.UserInputType.MouseMovement then
        self.pointer=self:MousePosition()
        if self.drag then self:UpdateDrag() else self:Hover() end
        self:Dirty() -- The Drawing cursor follows every pointer movement.
    elseif input.UserInputType==Enum.UserInputType.MouseWheel then
        self.pointer=self:MousePosition()
        if self.dirty then self:Draw() end
        if self.drag then return end
        local delta=input.Position.Z*30
        if self.popup then
            if Util.inside(self.popup.rect,self.pointer) then
                self.popup.scroll=Util.clamp((self.popup.scroll or 0)-delta,0,self.popup.maxScroll or 0); self:Dirty()
            end
            return
        end
        local w=self.window
        if w and w.Visible and not w.Minimized and Util.inside(self.contentClip,self.pointer) then
            self:Blur(true)
            if self.ui._destroyed then return end
            self.capture=nil; w.Scroll=Util.clamp(w.Scroll-delta,0,w.MaxScroll); self:Dirty()
        end
    end
end
function Runtime:Ended(input)
    if self.ui._destroyed then return end
    if input.UserInputType==Enum.UserInputType.MouseButton1 then
        if self.drag and self.drag.role=='textselect' and self.box.CursorPosition==self.box.SelectionStart then self.box.SelectionStart=-1 end
        self.drag=nil
    elseif input.UserInputType==Enum.UserInputType.Keyboard then
        local keys={}
        for c in pairs(self.held) do if c.Value==input.KeyCode.Name then table.insert(keys,c) end end
        for _,c in ipairs(keys) do self:ReleaseKey(c) end
    end
end
function Runtime:Notify(opts)
    local duration=Util.number(opts.Duration or 4,'Duration')
    assert(duration>0 and duration<=120,'Duration must be > 0 and <= 120 seconds')
    local title=Util.clean(opts.Title or 'Iris',256)
    local content=Util.clean(opts.Content or '',512)
    local cap=math.max(1,math.min(5,math.floor((self:Viewport().Y-24)/84)))
    while #self.notifications>=cap do table.remove(self.notifications,1) end
    table.insert(self.notifications,{Title=title,Content=content,expires=os.clock()+duration,alpha=0})
    self:Dirty()
end
function Runtime:Destroy()
    if self.input then self:SetCursor(false) end
    if self.scrollAction and self.actionService then self.actionService:UnbindAction(self.scrollAction) end
    self.scrollAction=nil
    if self.watchdog and task and type(task.cancel)=='function' and self.watchdog~=coroutine.running() then
        pcall(task.cancel,self.watchdog)
    end
    self.watchdog=nil
    self.edit=nil; self.capture=nil; self.drag=nil; self.popup=nil
    for _,connection in ipairs(self.connections) do connection:Disconnect() end
    self.connections={}
    for c in pairs(self.held) do self:ReleaseKey(c) end
    if self.box then self.box:ReleaseFocus() end
    for _,frame in ipairs(self.hitFrames) do frame:Destroy() end
    self.hitFrames={}; self.hitCount=0
    if self.gui then self.gui:Destroy(); self.gui=nil end
    if self.renderer then self.renderer:Destroy() end
    self.hits={}; self.notifications={}; self.animations={}; self.window=nil
end
return Runtime
