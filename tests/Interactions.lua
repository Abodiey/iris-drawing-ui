local passed=0
local function test(name,fn)
    local ok,err=pcall(fn)
    if not ok then error('FAIL '..name..': '..tostring(err)) end
    passed=passed+1; print('PASS '..name)
end
local function fails(fn) assert(not pcall(fn),'Expected validation failure') end
local function equal(a,b) assert(a==b,tostring(a)..' ~= '..tostring(b)) end
local function hit(rt,c,role)
    if rt.dirty then rt:Draw() end
    for _,h in ipairs(rt.hits) do
        if h.owner==c and h.role==role then
            local p,s=h.frame.AbsolutePosition,h.frame.AbsoluteSize
            h.rect={x=p.X,y=p.Y,w=s.X,h=s.Y}
            return h
        end
    end
    error('Missing hit '..role)
end
local function clickHit(rt,c,role)
    local h=hit(rt,c,role); Mock.click(h.rect.x+h.rect.w/2,h.rect.y+h.rect.h/2)
end
local ui=NewUI(Bundle)
local window=ui:CreateWindow({Name='Iris Drawing',Size=Vector2.new(480,650),Position=Vector2.new(80,40)})
local section=window:AddSection('GENERAL')
local counts={toggle=0,slider=0,button=0,binding=0,key=0,color=0}
local toggle=section:AddToggle({Name='Enabled',Flag='enabled',Callback=function() counts.toggle=counts.toggle+1 end})
local slider=section:AddSlider({Name='Intensity',Flag='amount',Min=0,Max=100,Step=.5,Default=50,Callback=function() counts.slider=counts.slider+1 end})
local dropdown=section:AddDropdown({Name='Style',Flag='style',Options={'Light','Dark','Auto'},Default='Dark'})
local multi=section:AddMultiDropdown({Name='Panels',Flag='panels',Options={'Alpha','Beta','Gamma'},Default={'Gamma','Alpha'}})
local text=section:AddTextbox({Name='Profile',Flag='profile',Placeholder='Name',MaxLength=24})
local key=section:AddKeybind({Name='Action key',Flag='key',Default='F',OnChanged=function() counts.binding=counts.binding+1 end,Callback=function(state) counts.key=counts.key+(state and 1 or 10) end})
local color=section:AddColorPicker({Name='Accent',Flag='accent',Default=Color3.fromRGB(10,132,255),Callback=function() counts.color=counts.color+1 end})
local button=section:AddButton({Name='Notify',Callback=function() counts.button=counts.button+1; ui:Notify({Title='Saved',Content='Profile updated',Duration=.5}) end})
local label=section:AddLabel({Name='Drawing-only interface'})
section:AddSeparator({Name='STATUS'})
Mock.tick(50)
local rt=ui._runtime

test('silent construction and consistent values',function()
    equal(counts.toggle,0); equal(counts.slider,0); equal(counts.binding,0)
    equal(ui:GetFlag('amount'),50); equal(ui.Flags.enabled,false)
    local v=multi:GetValue(); equal(v[1],'Alpha'); equal(v[2],'Gamma')
    v[1]='oops'; equal(multi:GetValue()[1],'Alpha')
end)
test('strict options and duplicate flags leave no controls',function()
    local n=#ui._controls
    fails(function() section:AddToggle({Name='Duplicate',Flag='enabled'}) end)
    fails(function() section:AddToggle({Name='Typo',Defualt=true}) end)
    fails(function() section:AddSlider({Name='Invalid',Min=1,Max=1}) end)
    fails(function() section:AddDropdown({Name='Invalid',Options={'x','x'}}) end)
    fails(function() section:AddButton({Name='Invalid',Flag='button'}) end)
    fails(function() section:AddKeybind({Name='Conflict',Default='RightShift'}) end)
    equal(#ui._controls,n)
end)
test('programmatic changes, normalization, no-op and silent callbacks',function()
    toggle:SetValue(true); equal(counts.toggle,1); equal(ui.Flags.enabled,true)
    toggle:SetValue(true); equal(counts.toggle,1)
    ui:SetFlag('enabled',false,true); equal(counts.toggle,1)
    slider:SetValue(51.24); equal(slider:GetValue(),51)
    slider:SetValue(1000); equal(slider:GetValue(),100)
    fails(function() slider:SetValue(0/0) end)
    fails(function() toggle:SetValue('true') end)
    fails(function() ui:SetFlag('missing',true) end)
    label:SetText('Updated label'); equal(label.Name,'Updated label')
end)
test('pointer toggle/button and smooth values',function()
    clickHit(rt,toggle,'toggle'); equal(toggle.Value,true)
    Mock.tick(25); assert(toggle._visual>.99)
    clickHit(rt,button,'button'); equal(counts.button,1)
    assert(#rt.notifications==1)
end)
test('slider drag clamps beyond bounds and release stops capture',function()
    local h=hit(rt,slider,'slider'); local r=h.data
    Mock.down(r.x+r.w*.25,r.y); equal(slider.Value,25)
    Mock.move(r.x+r.w+400,r.y); equal(slider.Value,100)
    Mock.move(r.x-400,r.y); equal(slider.Value,0)
    Mock.up(); assert(not rt.drag)
    Mock.move(r.x+r.w/2,r.y); equal(slider.Value,0)
end)
test('window dragging clamps to viewport',function()
    Mock.down(window.Position.X+100,window.Position.Y+20)
    Mock.move(-100,-100); equal(window.Position.X,0); equal(window.Position.Y,0)
    Mock.move(2000,2000); assert(window.Position.X+window.Size.X<=1000); assert(window.Position.Y+window.Size.Y<=800)
    Mock.up(); window.Position=Vector2.new(80,40); rt:Dirty(); Mock.tick(30)
end)
test('dropdown modal selection and outside click ownership',function()
    clickHit(rt,dropdown,'dropdown'); Mock.tick(1); assert(rt.popup.control==dropdown)
    local h=hit(rt,dropdown,'option'); Mock.click(h.rect.x+10,h.rect.y+10)
    equal(dropdown.Value,'Light'); assert(not rt.popup)
    clickHit(rt,dropdown,'dropdown'); Mock.tick(1)
    local old=toggle.Value; clickHit(rt,toggle,'toggle'); equal(toggle.Value,old); assert(not rt.popup)
end)
test('multi dropdown stays open and canonicalizes selection',function()
    clickHit(rt,multi,'dropdown'); Mock.tick(1)
    local h=hit(rt,multi,'option'); Mock.click(h.rect.x+10,h.rect.y+10)
    equal(multi.Value[1],'Gamma'); assert(rt.popup)
    Mock.press('Escape'); assert(not rt.popup)
    fails(function() multi:SetValue({'Alpha','Alpha'}) end)
    fails(function() multi:SetValue({'missing'}) end)
end)
test('SetOptions repairs values and closes popup',function()
    clickHit(rt,dropdown,'dropdown'); Mock.tick(1)
    dropdown:SetOptions({'New','Other'}); equal(dropdown.Value,'New'); assert(not rt.popup)
    multi:SetOptions({'Gamma','Delta'}); equal(#multi.Value,1); equal(multi.Value[1],'Gamma')
    dropdown:SetOptions({}); equal(dropdown.Value,'')
    fails(function() dropdown:SetValue('Invalid') end)
    dropdown:SetOptions({'Light','Dark','Auto'})
end)
test('textbox native editing commit/cancel/UTF8 and programmatic update',function()
    clickHit(rt,text,'textbox'); assert(rt.edit==text and Mock.focused==rt.box)
    rt.box.Text='A\nB'; equal(rt.box.Text,'A B'); rt.box.CursorPosition=4
    Mock.tick(1); Mock.press('Return'); equal(text.Value,'A B'); assert(not rt.edit)
    clickHit(rt,text,'textbox'); rt.box.Text='Cancel'; Mock.press('Escape'); equal(text.Value,'A B')
    clickHit(rt,text,'textbox'); rt.box.Text='Uncommitted'; text:SetValue('External'); equal(text.Value,'External'); assert(not rt.edit)
    clickHit(rt,text,'textbox'); rt.box.Text=string.rep('أ©',40); equal(utf8.len(rt.box.Text),24)
    rt.box.CursorPosition=#rt.box.Text+1; Mock.tick(1); rt.box:ReleaseFocus(); equal(utf8.len(text.Value),24)
end)
test('keybind press/release, capture, clear, focus suppression',function()
    Mock.press('F'); Mock.press('F'); equal(counts.key,1); Mock.release('F'); equal(counts.key,11)
    clickHit(rt,key,'keybind'); Mock.press('G'); equal(key.Value,'G'); equal(counts.binding,1); equal(counts.key,11)
    Mock.release('G'); equal(counts.key,11)
    Mock.press('G'); equal(counts.key,12)
    key:SetValue('H'); equal(counts.key,22); equal(counts.binding,2)
    Mock.release('G'); equal(counts.key,22)
    clickHit(rt,key,'keybind'); Mock.press('Escape'); equal(key.Value,'H')
    clickHit(rt,key,'keybind'); Mock.press('Backspace'); equal(key.Value,'None')
    key:SetValue('F',true); equal(counts.binding,3)
    clickHit(rt,text,'textbox'); Mock.press('F'); equal(counts.key,22); Mock.press('Escape')
    Mock.focused={}; Mock.press('F'); equal(counts.key,22); Mock.focused=nil
    Mock.press('F',true); equal(counts.key,22)
end)
test('color HSV popup, hue memory, drags and callback values',function()
    clickHit(rt,color,'color'); Mock.tick(1); assert(rt.popup)
    local h=hit(rt,color,'sv'); Mock.down(h.data.x+h.data.w*.5,h.data.y+h.data.h*.25); Mock.up()
    local hue,s,v=color.Value:ToHSV(); assert(math.abs(s-.5)<.01 and math.abs(v-.75)<.01)
    Mock.tick(1); h=hit(rt,color,'hue'); Mock.down(h.data.x+h.data.w*.25,h.data.y+3); Mock.up()
    hue,s,v=color.Value:ToHSV(); assert(math.abs(hue-.25)<.01); assert(counts.color>=2)
    Mock.press('Escape'); assert(not rt.popup)
end)
test('config JSON-safe roundtrip, atomic rejection, stable callback order',function()
    local config=ui:GetConfig(); assert(type(config.Flags.accent)=='table'); equal(config.Version,1)
    config.Flags.enabled=false; config.Flags.amount=35.3
    ui:LoadConfig(config,true); equal(toggle.Value,false); equal(slider.Value,35.5)
    local before=ui:GetFlag('amount')
    fails(function() ui:LoadConfig({Version=1,Flags={amount=70,style='invalid'}}) end)
    equal(slider.Value,before)
    fails(function() ui:LoadConfig({Version=2,Flags={}}) end)
    fails(function() ui:LoadConfig({Version=1,Flags={missing=true}}) end)
    fails(function() ui:LoadConfig({Version=1,Flags={accent={2,0,0}}}) end)
    local seen={}
    toggle.Callback=function() equal(slider.Value,80); table.insert(seen,'toggle') end
    slider.Callback=function() equal(toggle.Value,true); table.insert(seen,'slider') end
    ui:LoadConfig({Version=1,Flags={enabled=true,amount=80}})
    equal(table.concat(seen,','),'toggle,slider')
    toggle.Callback=function() counts.toggle=counts.toggle+1 end
    slider.Callback=function() counts.slider=counts.slider+1 end
end)
test('scroll clipping and independent popup scroll',function()
    local more=window:AddSection('MORE')
    for i=1,30 do more:AddLabel({Name='Row '..i}) end
    window:SetSize(Vector2.new(480,350)); Mock.tick(40)
    Mock.move(window.Position.X+40,window.Position.Y+100); Mock.wheel(-100)
    equal(window.Scroll,window.MaxScroll)
    fails(function() hit(rt,toggle,'toggle') end)
    Mock.wheel(1000); equal(window.Scroll,0); Mock.tick(1)
    local list={}; for i=1,100 do list[i]='Option '..i end
    dropdown:SetOptions(list); clickHit(rt,dropdown,'dropdown'); Mock.tick(1)
    local pop=rt.popup; assert(pop.rect.y+pop.rect.h<=800)
    Mock.move(pop.rect.x+20,pop.rect.y+20); Mock.wheel(-4); assert(pop.scroll>0); equal(window.Scroll,0)
    Mock.tick(1); assert(#rt.hits<40,'Popup should virtualize rows')
    Mock.press('Escape'); window:SetSize(Vector2.new(480,650)); Mock.tick(40)
end)
test('popup opens above low anchor, viewport and resize dismiss',function()
    window:SetSize(Vector2.new(480,540)); Mock.tick(40); window.Position=Vector2.new(500,240); window.Scroll=80; rt:Dirty(); Mock.tick(1)
    clickHit(rt,color,'color'); Mock.tick(1)
    assert(rt.popup.rect.y<color._anchor.y); assert(rt.popup.rect.x+rt.popup.rect.w<=1000)
    window:SetSize(Vector2.new(500,640)); assert(not rt.popup)
    Mock.viewport(600,400); assert(window.Size.X<=584); assert(window.Size.Y<=384)
    assert(window.Position.X+window.Size.X<=600)
    Mock.viewport(1000,800); window.Position=Vector2.new(80,40); window:SetSize(Vector2.new(480,650)); Mock.tick(50)
end)
test('minimize and hide cancel input, reopen with toggle key',function()
    clickHit(rt,text,'textbox'); rt.box.Text='Committed'; window:SetMinimized(true)
    equal(text.Value,'Committed'); assert(not rt.edit); Mock.tick(50); equal(rt.height,32)
    fails(function() hit(rt,toggle,'toggle') end)
    clickHit(rt,window,'minimize'); Mock.tick(50); assert(not window.Minimized)
    clickHit(rt,window,'close'); Mock.tick(50); assert(not window.Visible); equal(Mock.visibleDrawings(),0)
    Mock.press('RightShift'); Mock.tick(50); assert(window.Visible); assert(Mock.visibleDrawings()>0)
end)
test('focus loss ends drags, captures and held key states',function()
    Mock.press('F'); local before=counts.key
    local h=hit(rt,slider,'slider'); Mock.down(h.data.x+10,h.data.y)
    Mock.focusLost(); assert(not rt.drag and not rt.capture); equal(counts.key,before+10)
    clickHit(rt,key,'keybind'); Mock.focusLost(); assert(not rt.capture)
end)
test('notification cap, stacking and expiry',function()
    for i=1,10 do ui:Notify({Title='Message '..i,Content='Content',Duration=.2}) end
    equal(#rt.notifications,5); Mock.tick(10)
    local ys={}
    for _,d in ipairs(Mock.drawings) do if not d.Removed and d.Visible and d.ZIndex==61 and d.Text:match('Message') then assert(not ys[d.Position.Y]); ys[d.Position.Y]=true end end
    Mock.tick(60); equal(#rt.notifications,0)
    fails(function() ui:Notify({Duration=0}) end)
end)
test('single centralized connections and idle primitive reuse',function()
    local count=Mock.liveConnections(); equal(count,10)
    Mock.tick(60); local objects=#Mock.drawings
    Mock.tick(100); equal(#Mock.drawings,objects)
    for _=1,10 do rt:Dirty(); Mock.tick(1) end
    equal(#Mock.drawings,objects)
    for _,instance in ipairs(Mock.instances) do
        if instance._kind=='TextBox' then equal(instance.TextTransparency,1); equal(instance.BackgroundTransparency,1); assert(instance.Position.X<0) end
    end
end)
test('callback errors isolated and destruction inside callbacks',function()
    toggle.Callback=function() error('expected callback error') end
    toggle:SetValue(not toggle.Value); assert(#Mock.warnings>0)
    local temporary=NewUI(Bundle); local w=temporary:CreateWindow({}); local s=w:AddSection('A')
    s:AddToggle({Name='Destroy',Flag='a',Callback=function() temporary:Destroy() end})
    s:AddToggle({Name='Later',Flag='b',Callback=function() error('must not run') end})
    temporary:LoadConfig({Version=1,Flags={a=true,b=true}}); assert(temporary._destroyed)
end)
test('textbox mouse caret and selection use UTF8 boundaries',function()
    text:SetValue('abcdefأ©')
    local h=hit(rt,text,'textbox'); local field=h.data
    Mock.click(field.x+8,field.y+10); equal(rt.box.CursorPosition,1)
    Mock.down(field.x+8,field.y+10)
    Mock.move(field.x+8+rt.renderer:Width('abc',14),field.y+10)
    Mock.up(); equal(rt.box.CursorPosition,4); equal(rt.box.SelectionStart,1)
    Mock.tick(1); Mock.press('Escape')
    text:SetValue(string.rep('أ©',24)); clickHit(rt,text,'textbox')
    rt.box.CursorPosition=#rt.box.Text+1; rt.box.SelectionStart=1; Mock.tick(1)
    assert(utf8.len(rt.box.Text)); Mock.press('Escape')
end)
test('key binding setter never invokes pressed callback without OnChanged',function()
    local c=section:AddKeybind({Name='No change handler',Callback=function() error('pressed callback must not be used') end})
    local warnings=#Mock.warnings
    c:SetValue('P'); equal(#Mock.warnings,warnings)
end)
test('key release callbacks may destroy during setter and config',function()
    for _,config in ipairs({false,true}) do
        local item=NewUI(Bundle); local w=item:CreateWindow({ToggleKey='None'}); local s=w:AddSection('Test')
        local c=s:AddKeybind({Name='Dispose',Flag='key',Default='J',Callback=function(pressed) if not pressed then item:Destroy() end end})
        Mock.press('J')
        if config then item:LoadConfig({Version=1,Flags={key='K'}}) else c:SetValue('K') end
        assert(item._destroyed)
    end
end)
test('geometry clipping covers every band and hides crossing text',function()
    local original=rt.renderer
    original:Begin(1)
    local clip={x=10,y=10,w=20,h=20}
    original:Round({x=0,y=0,w=50,h=50},12,Color3.new(1,1,1),clip)
    original:Text('crossing',11,25,Color3.new(1,1,1),100,clip)
    original:Finish()
    equal(original.used.Text,0)
    for i=1,original.used.Square do
        local d=original.pools.Square[i]
        assert(d.Position.X>=10 and d.Position.Y>=10)
        assert(d.Position.X+d.Size.X<=30 and d.Position.Y+d.Size.Y<=30)
    end
    rt:Dirty(); Mock.tick(1)
end)
test('close and minimize animate content while blocking interactions',function()
    window.Scroll=0; rt:Dirty(); Mock.tick(40)
    window:SetVisible(false); Mock.tick(1)
    assert(rt.alpha>0 and rt.alpha<1)
    local textVisible=false
    for _,d in ipairs(Mock.drawings) do if not d.Removed and d.Visible and d.Text==toggle.Name and d.ZIndex==12 then textVisible=true end end
    assert(textVisible,'Window content must fade during close')
    fails(function() hit(rt,toggle,'toggle') end)
    window:SetVisible(true); Mock.tick(40)
    window:SetMinimized(true); Mock.tick(1); assert(rt.height>52)
    fails(function() hit(rt,toggle,'toggle') end)
    window:SetMinimized(false); Mock.tick(40)
end)
test('programmatic colors synchronize an already open picker',function()
    clickHit(rt,color,'color'); Mock.tick(1)
    color:SetValue(Color3.fromHSV(.75,.8,.9)); Mock.tick(1)
    assert(math.abs(rt.popup.hue-.75)<.001)
    local h=hit(rt,color,'sv'); Mock.down(h.data.x,h.data.y+h.data.h); Mock.up(); Mock.tick(1)
    assert(math.abs(rt.popup.hue-.75)<.001,'Black must preserve hue during picker drag')
    Mock.press('Escape')
end)
test('partial initialization failure cleans allocated resources',function()
    local prior=Mock.liveConnections()
    local original=game.GetService
    game.GetService=function(self,name) if name=='CoreGui' then error('denied CoreGui') end; return original(self,name) end
    local item=NewUI(Bundle)
    fails(function() item:CreateWindow({}) end)
    game.GetService=original
    equal(Mock.liveConnections(),prior)
    item:CreateWindow({Name='Recovered'}); Mock.tick(10); item:Destroy()
    equal(Mock.liveConnections(),prior)
end)
test('window paints before any RenderStepped delivery',function()
    local item=NewUI(Bundle)
    item:CreateWindow({Name='Immediate'})
    local renderer=item._runtime.renderer
    assert(renderer.used.Square>0,'No startup shapes were painted')
    assert(renderer.used.Text>0,'No startup title was painted')
    assert(item._runtime.alpha>0)
    item:Destroy()
end)
test('direct Drawing properties and visibility-last work with unrelated helpers present',function()
    local oldDrawing,oldSet,oldGet=Drawing,setrenderproperty,getrenderproperty
    local states={}
    Drawing={new=function(kind)
        local object={}
        local state={Kind=kind,Visible=false,Text='',Size=15}
        states[object]=state
        function object:Remove() assert(not state.removed); state.removed=true end
        setmetatable(object,{
            __newindex=function(_,property,value)
                if property=='Visible' and value then
                    if kind=='Line' then
                        assert(typeof(state.From)=='Vector2' and typeof(state.To)=='Vector2','Visibility set before line endpoints')
                    else assert(typeof(state.Position)=='Vector2','Visibility set before position') end
                    if kind=='Square' then assert(typeof(state.Size)=='Vector2' and state.Size.X>0 and state.Size.Y>0,'Visibility set before valid geometry') end
                end
                state[property]=value
            end,
            __index=function(_,property)
                if property=='TextBounds' then return Vector2.new(utf8.len(state.Text)*state.Size*.53,state.Size+1) end
                return state[property]
            end,
        })
        return object
    end}
    setrenderproperty=function() error('Unrelated helper must not be called') end
    getrenderproperty=function() error('Unrelated helper must not be called') end
    local item=NewUI(Bundle)
    item:CreateWindow({Name='Backend'}):AddSection('Test'):AddToggle({Name='Toggle'})
    Mock.tick(40)
    local visible=0
    for _,state in pairs(states) do if state.Visible and not state.removed and state.Transparency>0 then visible=visible+1 end end
    assert(visible>0)
    item:Destroy()
    for _,state in pairs(states) do assert(state.removed,'Backend object leaked') end
    Drawing,setrenderproperty,getrenderproperty=oldDrawing,oldSet,oldGet
end)
test('stalled render signal has one cancellable task fallback and resumes cleanly',function()
    local previousTask=task
    local scheduled={}
    task={}
    function task.wait(seconds) return coroutine.yield(seconds) end
    function task.spawn(fn)
        local co=coroutine.create(fn)
        local ok,delay=coroutine.resume(co); assert(ok,delay)
        scheduled[co]={wake=Mock.time+delay,cancelled=false}
        return co
    end
    function task.cancel(co) scheduled[co].cancelled=true end
    local function advance(seconds)
        local untilTime=Mock.time+seconds
        while Mock.time<untilTime do
            Mock.time=math.min(untilTime,Mock.time+1/120)
            for co,entry in pairs(scheduled) do
                if not entry.cancelled and Mock.time>=entry.wake then
                    local ok,delay=coroutine.resume(co); assert(ok,delay)
                    if coroutine.status(co)=='dead' then entry.cancelled=true
                    else entry.wake=Mock.time+delay end
                end
            end
        end
    end
    local item=NewUI(Bundle)
    item:CreateWindow({Name='Fallback'}):AddSection('Test'):AddToggle({Name='Toggle'})
    local runtime=item._runtime
    assert(runtime.watchdog)
    local frames=0; local step=runtime.Step
    runtime.Step=function(self,dt) frames=frames+1; return step(self,dt) end
    advance(.8) -- No RenderStepped events.
    assert(frames>1 and runtime.alpha>.99 and runtime.renderer.used.Text>1)
    Mock.tick(1) -- Signal delivery recovers.
    local before=frames
    advance(.1)
    equal(frames,before,'Fallback must not also render after signal recovery')
    local monitor=runtime.watchdog
    item:Destroy(); assert(scheduled[monitor].cancelled)
    task=previousTask
end)
test('startup Drawing failures throw synchronously and clean up',function()
    local create=Drawing.new
    Drawing.new=function(kind) if kind=='Square' then error('Square backend unavailable') end; return create(kind) end
    local prior=Mock.liveConnections()
    local item=NewUI(Bundle)
    local ok,message=pcall(function() item:CreateWindow({}) end)
    assert(not ok and tostring(message):find('first frame failed',1,true))
    equal(Mock.liveConnections(),prior)
    assert(not item._runtime and not item._window)
    Drawing.new=create
    item:CreateWindow({Name='Recovered'}); item:Destroy()
end)
test('asynchronous frame failures are explicit and do not spam',function()
    local item=NewUI(Bundle); item:CreateWindow({})
    local runtime=item._runtime; local step=runtime.Step
    local warnings=#Mock.warnings
    runtime.Step=function() error('expected render failure') end
    Mock.tick(2); equal(#Mock.warnings,warnings+1)
    assert(runtime.frameError:find('expected render failure',1,true))
    assert(Mock.warnings[#Mock.warnings]:find('Iris Drawing render',1,true))
    runtime.Step=step; Mock.tick(1); assert(not runtime.frameError)
    item:Destroy()
end)
test('settled window text and controls remain opaque under the Synapse Drawing contract',function()
    window:SetVisible(true); window:SetMinimized(false); window.Scroll=0; rt:Dirty(); Mock.tick(60)
    local title,toggleText,background
    for _,d in ipairs(Mock.drawings) do
        if not d.Removed and d.Visible then
            if d._kind=='Text' and d.Text==window.Name then title=d end
            if d._kind=='Text' and d.Text==toggle.Name and d.ZIndex==12 then toggleText=d end
            if d._kind=='Square' and d.ZIndex==2 then background=d end
        end
    end
    assert(title and title.Transparency==1,'Settled title is invisible on Synapse Drawing')
    assert(toggleText and toggleText.Transparency==1,'Settled control text is invisible on Synapse Drawing')
    assert(background and math.abs(background.Transparency-1)<.00001,'Background opacity was inverted')
end)
test('Synapse hide animation decreases Drawing opacity',function()
    window:SetVisible(false); Mock.tick(1)
    local title
    for _,d in ipairs(Mock.drawings) do if not d.Removed and d.Visible and d._kind=='Text' and d.Text==window.Name then title=d end end
    assert(title and title.Transparency>0 and title.Transparency<1,'Hide must fade pixels toward transparent')
    Mock.tick(60); equal(Mock.visibleDrawings(),0)
    window:SetVisible(true); Mock.tick(60)
end)
test('notification text stays visible after its fade-in completes',function()
    ui:Notify({Title='Opacity regression',Content='Visible notification',Duration=4})
    Mock.tick(60)
    local title
    for _,d in ipairs(Mock.drawings) do if not d.Removed and d.Visible and d._kind=='Text' and d.Text=='Opacity regression' then title=d end end
    assert(title and title.Transparency>.999,'Notification became transparent after fading in')
    Mock.tick(300); equal(#rt.notifications,0)
end)
test('raw UIS hitboxes align with Drawing under changing GUI origins',function()
    window.Scroll=0; rt:Dirty(); Mock.tick(60)
    for _,origin in ipairs({Vector2.new(0,-58),Vector2.new(0,24),Vector2.new(12,-31),Vector2.new(0,0)}) do
        Mock.guiOrigin=origin
        rt.gui:GetPropertyChangedSignal('AbsolutePosition'):Fire()
        assert(rt.dirty,'GUI origin changes must invalidate layout')
        Mock.tick(1)
        local record=hit(rt,toggle,'toggle')
        local row=toggle._row
        equal(record.frame.AbsolutePosition.X,row.x)
        equal(record.frame.AbsolutePosition.Y,row.y+26)
        equal(record.frame.AbsoluteSize.X,44)
        equal(record.frame.AbsoluteSize.Y,20)
        local value=toggle.Value
        Mock.click(row.x+20,row.y+36)
        equal(toggle.Value,not value)
        equal(rt.pointer.X,row.x+20); equal(rt.pointer.Y,row.y+36)
    end
end)

test('wheel capture is scoped and unbound independently on destroy',function()
    local action=Mock.actions[rt.scrollAction]
    assert(action and action.priority>Enum.ContextActionPriority.High.Value)
    equal(action.input,Enum.UserInputType.MouseWheel)
    Mock.move(window.Position.X+10,window.Position.Y+10)
    equal(action.fn(),Enum.ContextActionResult.Sink)
    Mock.move(0,0); equal(action.fn(),Enum.ContextActionResult.Pass)
    window:SetVisible(false); equal(action.fn(),Enum.ContextActionResult.Pass)
    window:SetVisible(true); window:SetMinimized(true); Mock.tick(60)
    Mock.move(window.Position.X+10,window.Position.Y+80)
    equal(action.fn(),Enum.ContextActionResult.Pass)
    window:SetMinimized(false); Mock.tick(60)
    clickHit(rt,dropdown,'dropdown'); Mock.tick(1)
    local rect=rt.popup.rect
    Mock.move(rect.x+8,rect.y+8); equal(action.fn(),Enum.ContextActionResult.Sink)
    rt:ClosePopup()
    local other=NewUI(Bundle); other:CreateWindow({Name='Other'})
    local name=other._runtime.scrollAction
    assert(name~=rt.scrollAction and Mock.actions[name])
    other:Destroy(); assert(not Mock.actions[name] and Mock.actions[rt.scrollAction])
end)

test('native circles are smooth pooled and fall back to clipping bands',function()
    local d=rt.renderer
    d:Begin(1)
    d:Round({x=10,y=10,w=20,h=20},10,Color3.new(1,1,1),{x=0,y=0,w=50,h=50})
    d:Finish()
    equal(d.used.Circle,1); equal(d.used.Square,0)
    local circle=d.pools.Circle[1]
    equal(circle.NumSides,64); equal(circle.Radius,10)
    equal(circle.Position.X,20); equal(circle.Transparency,1)
    d:Begin(1); d:Round({x=10,y=10,w=20,h=20},10,Color3.new(1,1,1)); d:Finish()
    equal(d.pools.Circle[1],circle)
    d:Begin(1)
    local clip={x=15,y=15,w=10,h=10}
    d:Round({x=10,y=10,w=20,h=20},10,Color3.new(1,1,1),clip); d:Finish()
    equal(d.used.Circle,0); assert(not circle.Visible and d.used.Square>0)
    for i=1,d.used.Square do
        local band=d.pools.Square[i]
        assert(band.Position.X>=15 and band.Position.Y>=15)
        assert(band.Position.X+band.Size.X<=25 and band.Position.Y+band.Size.Y<=25)
    end
    rt:Dirty(); Mock.tick(1)
end)

test('viewport ratio origin translates every primitive without changing hit tests',function()
    local camera=game:GetService('Workspace').CurrentCamera
    local original=camera.ViewportSize
    local d=rt.renderer
    camera.ViewportSize=Vector2.new(1280,1001)
    Mock.tick(60)
    equal(d.offsetY,23)
    local h=hit(rt,toggle,'toggle')
    equal(h.frame.AbsolutePosition.Y,toggle._row.y+26)
    clickHit(rt,toggle,'toggle')
    d:Begin(1)
    d:Rect({x=10,y=20,w=30,h=40},Color3.new(1,1,1))
    d:Text('Origin',10,20,Color3.new(1,1,1),100,nil,12,13)
    d:Round({x=10,y=20,w=20,h=20},10,Color3.new(1,1,1))
    d:Finish()
    equal(d.pools.Square[1].Position.Y,43)
    equal(d.pools.Text[1].Position.Y,43)
    equal(d.pools.Circle[1].Position.Y,53)
    local square=d.pools.Square[1]
    camera.ViewportSize=Vector2.new(1280,1024); Mock.tick(60)
    equal(d.offsetY,0)
    equal(d.pools.Square[1],square)
    camera.ViewportSize=Vector2.new(1280,1001); Mock.tick(60)
    equal(d.offsetY,23)
    camera.ViewportSize=original; Mock.tick(60)
    equal(d.offsetY,0)
end)

test('viewport ratio fallback tracks largest observed height',function()
    local isolated=NewUI(Bundle)
    isolated:CreateWindow({Name='Fallback'})
    local d=isolated._runtime.renderer
    d:SetViewport(Vector2.new(1000,1100)); equal(d.offsetY,0)
    d:SetViewport(Vector2.new(1000,1077)); equal(d.offsetY,23)
    d:SetViewport(Vector2.new(1000,1100)); equal(d.offsetY,0)
    d:SetViewport(Vector2.new(0,0)); equal(d.offsetY,0)
    isolated:Destroy()
end)

test('Windows 10 caption buttons, rectangular fields, checkbox options and focus styling',function()
    window:SetVisible(true); window:SetMinimized(false); window:SetSize(Vector2.new(480,650)); window.Scroll=0; rt:ClosePopup(); rt:Dirty(); Mock.tick(60)
    local minimize=hit(rt,window,'minimize')
    local close=hit(rt,window,'close')
    equal(minimize.rect.w,46); equal(close.rect.w,46)
    local font=rt.renderer.measure.Font
    assert(type(font)=='number')
    clickHit(rt,text,'textbox'); Mock.tick(1)
    assert(rt.edit==text)
    -- Caret is near black on a white field instead of white on white.
    local caretFound=false
    for _,d in ipairs(Mock.drawings) do
        if d._kind=='Square' and d.Visible and d.Color==Color3.fromRGB(0,0,0) and d.Size.X==1 and d.Size.Y==18 then caretFound=true end
    end
    assert(caretFound)
    rt:Blur(false)
    clickHit(rt,multi,'dropdown'); Mock.tick(20)
    local checkboxFound=false
    for _,d in ipairs(Mock.drawings) do
        if d._kind=='Square' and d.Visible and d.Size.X==20 and d.Size.Y==20 then checkboxFound=true end
    end
    assert(checkboxFound)
    rt:ClosePopup(); Mock.tick(20)
end)

test('hover and popup motion settle without per-control connections',function()
    local before=Mock.liveConnections()
    clickHit(rt,dropdown,'dropdown')
    assert(rt.popup and rt.popup.alpha==0)
    Mock.tick(12); equal(rt.popup.alpha,1)
    rt:ClosePopup()
    assert(not rt.popup and rt.retiringPopup)
    Mock.tick(12); assert(not rt.retiringPopup)
    local c=hit(rt,toggle,'toggle')
    Mock.move(c.rect.x+c.rect.w/2,c.rect.y+c.rect.h/2)
    Mock.tick(12)
    equal(rt:Visual(toggle,'toggle'),1)
    Mock.move(0,0); Mock.tick(12)
    equal(rt:Visual(toggle,'toggle'),0)
    assert(next(rt.visualAnimations)==nil)
    equal(Mock.liveConnections(),before)
end)

test('Drawing line icons share the existing viewport Y correction',function()
    local d=rt.renderer
    d:SetViewport(Vector2.new(1280,1001))
    d:Begin(1); d:Line(10,20,15,25,Color3.new(1,1,1)); d:Finish()
    local line=d.pools.Line[1]
    equal(line.From.Y,43); equal(line.To.Y,48)
    d:SetViewport(rt:Viewport()); rt:Dirty(); Mock.tick(1)
end)

test('compact metadata, section hierarchy and shared field alignment',function()
    local item=NewUI(Bundle)
    local w=item:CreateWindow({Name='Settings',Size=Vector2.new(560,640),Position=Vector2.new(20,20)})
    local info=w:AddSection('Application')
    local labels={}
    for i=1,5 do labels[i]=info:AddLabel({Name='Status '..i}) end
    local settings=w:AddSection('Preferences')
    local sw=settings:AddToggle({Name='Enabled'})
    local dd=settings:AddDropdown({Name='Mode',Options={'Default','Custom'}})
    local tb=settings:AddTextbox({Name='Profile',Default='Work'})
    local sl=settings:AddSlider({Name='Intensity',Min=0,Max=100,Default=50})
    local b=settings:AddButton({Name='Apply settings changes'})
    Mock.tick(60)
    equal(labels[1].Height,22)
    equal(labels[5]._row.y-labels[1]._row.y,88)
    equal(sw.Height,56); equal(sl.Height,56)
    equal(dd._anchor.h,32); equal(tb._anchor.h,32)
    equal(dd._anchor.x,tb._anchor.x)
    equal(dd._anchor.x,sw._row.x)
    equal(dd._anchor.w,280)
    equal(dd._anchor.y,dd._row.y+24)
    local buttonHit=hit(item._runtime,b,'button')
    equal(buttonHit.rect.h,32)
    assert(buttonHit.rect.w<sw._row.w/2,'Button must use its native content width')
    local heading,buttonLabel=false,false
    for _,d in ipairs(Mock.drawings) do
        if not d.Removed and d.Visible and d._kind=='Text' and d.Text=='Preferences' then
            equal(d.Size,22); heading=true
        end
    end
    for _,d in ipairs(Mock.drawings) do
        if not d.Removed and d.Visible and d._kind=='Text' and d.Text==b.Name then buttonLabel=true end
    end
    assert(heading and buttonLabel,'Heading and complete button text must render')
    item:Destroy()
end)

test('widgets reject clicks outside their visual X and Y bounds',function()
    window.Scroll=0; window:SetVisible(true); window:SetMinimized(false); rt:ClosePopup(); rt:Dirty(); Mock.tick(60)
    local record=hit(rt,toggle,'toggle')
    local r=record.rect
    local old=toggle.Value
    Mock.click(r.x+r.w+12,r.y+r.h/2); equal(toggle.Value,old)
    Mock.click(r.x-1,r.y+r.h/2); equal(toggle.Value,old)
    Mock.click(r.x+10,r.y-1); equal(toggle.Value,old)
    Mock.click(r.x+r.w,r.y+10); equal(toggle.Value,old)
    Mock.click(r.x+r.w/2,r.y+r.h/2); equal(toggle.Value,not old)
    local field=dropdown._anchor
    Mock.click(field.x+field.w+12,field.y+16); assert(not rt.popup)
    Mock.click(field.x-1,field.y+16); assert(not rt.popup)
    Mock.click(field.x+16,field.y-1); assert(not rt.popup)
    Mock.click(field.x+field.w,field.y+16); assert(not rt.popup)
    Mock.click(field.x+16,field.y+16); assert(rt.popup and rt.popup.control==dropdown)
    rt:ClosePopup()
    for _,entry in ipairs({{text,'textbox'},{key,'keybind'},{color,'color'},{multi,'dropdown'}}) do
        local c,role=entry[1],entry[2]
        window.Scroll=math.max(0,c._row.y-window.Position.Y-100); rt:Dirty(); Mock.tick(1)
        local h=hit(rt,c,role)
        local a=c._anchor
        equal(h.rect.x,a.x); equal(h.rect.w,a.w)
        Mock.click(a.x+a.w+12,a.y+16)
        assert(not rt.edit and not rt.capture and not rt.popup)
    end
    window.Scroll=0; rt:Dirty(); Mock.tick(1)
end)

test('Settings sidebar navigation, search, history and resize preserve controls',function()
    local before=Mock.liveConnections()
    local item=NewUI(Bundle)
    local w=item:CreateWindow({Name='Settings',Size=Vector2.new(960,760),Position=Vector2.new(0,0)})
    local sections={}
    for i=1,15 do
        local s=w:AddSection('Section '..i); sections[i]=s
        s:AddToggle({Name='Feature '..i,Flag='feature'..i})
        s:AddTextbox({Name='Profile '..i,Default='Name'})
    end
    Mock.tick(60)
    local runtime=item._runtime
    equal(runtime.contentClip.x,344)
    assert(runtime.navigationClip and runtime.navigationMaxScroll>0)
    clickHit(runtime,sections[2],'sectionNavigation'); Mock.tick(1)
    equal(w.Scroll,runtime.sectionOffsets[sections[2]])
    assert(#runtime.history==1)
    local previousScroll=w.Scroll
    Mock.move(10,10)
    equal(w.Scroll,previousScroll); equal(#runtime.history,1)
    clickHit(runtime,w,'back'); Mock.tick(1); equal(w.Scroll,0)
    clickHit(runtime,runtime.search,'textbox')
    runtime.box.Text='Feature 7'; Mock.tick(1)
    local target=hit(runtime,sections[7],'sectionNavigation')
    assert(target.data==runtime.controlOffsets[item._flags.feature7])
    local search=runtime.search
    Mock.move(10,10); equal(runtime.search,search)
    clickHit(runtime,sections[7],'sectionNavigation'); Mock.tick(1)
    equal(search.Value,'Feature 7')
    equal(w.Scroll,runtime.controlOffsets[item._flags.feature7])
    clickHit(runtime,w,'home'); Mock.tick(1); equal(w.Scroll,0)
    search:SetValue(''); Mock.tick(1)
    Mock.move(runtime.navigationClip.x+10,runtime.navigationClip.y+10)
    Mock.wheel(-4); assert(runtime.navigationScroll>0)
    equal(w.Scroll,0)
    local navigationScroll=runtime.navigationScroll
    w:SetMinimized(true); Mock.wheel(-2)
    equal(runtime.navigationScroll,navigationScroll)
    Mock.tick(60); assert(not runtime.navigationClip)
    w:SetMinimized(false); Mock.tick(60)
    clickHit(runtime,runtime.search,'textbox')
    Mock.viewport(500,800)
    Mock.tick(60); assert(not runtime.edit and not runtime.navigationClip)
    Mock.viewport(1000,800); Mock.tick(60)
    item:SetFlag('feature7',true,true)
    w:SetSize(Vector2.new(480,650)); Mock.tick(60)
    assert(not runtime.navigationClip)
    equal(runtime.contentClip.x,w.Position.X+24)
    equal(item:GetFlag('feature7'),true)
    assert(not runtime.popup and not runtime.edit)
    item:Destroy(); equal(Mock.liveConnections(),before)
end)

test('Settings caption maximize restores size and position',function()
    local item=NewUI(Bundle)
    local w=item:CreateWindow({Name='Settings',Size=Vector2.new(700,600),Position=Vector2.new(40,50)})
    local s=w:AddSection('Display'); s:AddToggle({Name='Night light'})
    Mock.tick(60)
    local runtime=item._runtime
    clickHit(runtime,w,'maximize'); Mock.tick(60)
    equal(w.Size.X,984); equal(w.Size.Y,784)
    assert(w._restore and runtime.navigationClip)
    clickHit(runtime,w,'maximize'); Mock.tick(60)
    equal(w.Size.X,700); equal(w.Size.Y,600)
    equal(w.Position.X,40); equal(w.Position.Y,50)
    assert(not w._restore)
    item:Destroy()
end)

test('Windows 10 light palette uses the in-box theme resource colours',function()
    window:SetVisible(true); window:SetMinimized(false); window.Scroll=0; rt:ClosePopup(); rt:Dirty(); Mock.tick(60)
    local background,border,field
    for _,d in ipairs(Mock.drawings) do
        if not d.Removed and d.Visible and d._kind=='Square' then
            if d.ZIndex==2 and d.Color==Color3.fromRGB(255,255,255) and d.Size.X==window.Size.X then background=d end
            if d.ZIndex==3 and d.Color==Color3.fromRGB(219,219,219) then border=d end
            if d.Color==Color3.fromRGB(255,255,255) and d.Size.Y==32 and d.Size.X==280 then field=d end
        end
    end
    assert(background,'Window background must be white')
    assert(border,'Window border must use SystemControlTransientBorderBrush #DBDBDB')
    assert(field,'Text fields must stay white')
end)

test('Settings navigation pane: 320 px chrome, 48 px rows, list-low selection and 4x24 accent bar',function()
    local item=NewUI(Bundle)
    local w=item:CreateWindow({Name='Settings',Size=Vector2.new(960,760),Position=Vector2.new(0,0)})
    local sections={}
    for i=1,6 do
        local s=w:AddSection('Section '..i); sections[i]=s
        s:AddToggle({Name='Feature '..i,Flag='feature'..i})
    end
    Mock.tick(60)
    local runtime=item._runtime
    local pane
    for _,d in ipairs(Mock.drawings) do
        if not d.Removed and d.Visible and d._kind=='Square' and d.Color==Color3.fromRGB(242,242,242)
            and d.Size.X==320 and d.Size.Y>=w.Size.Y-2 then pane=d end
    end
    assert(pane,'Navigation pane must use SystemControlPageBackgroundChromeLowBrush #F2F2F2')
    equal(pane.Position.X,w.Position.X)
    -- The acrylic pane runs behind the transparent caption bar.
    equal(pane.Position.Y,w.Position.Y)
    local rows={}
    for _,h in ipairs(runtime.hits) do if h.role=='sectionNavigation' then table.insert(rows,h) end end
    assert(#rows==6,'Expected six navigation rows')
    for _,h in ipairs(rows) do
        equal(h.frame.AbsoluteSize.X,320)
        equal(h.frame.AbsoluteSize.Y,48)
    end
    equal(rows[2].frame.AbsolutePosition.Y-rows[1].frame.AbsolutePosition.Y,48)
    local home=hit(runtime,w,'home')
    equal(home.frame.AbsolutePosition.Y,w.Position.Y+40)
    equal(home.frame.AbsoluteSize.Y,48)
    local fill,bar
    for _,d in ipairs(Mock.drawings) do
        if not d.Removed and d.Visible and d._kind=='Square' then
            if d.Color==Color3.fromRGB(230,230,230) and d.Size.X>=300 and d.Size.Y==48 then fill=d end
            if d.Color==Color3.fromRGB(0,120,215) and d.Size.X==4 and d.Size.Y==24 then bar=d end
        end
    end
    assert(fill,'Selected navigation row must use SystemListLowColor #E6E6E6')
    assert(bar,'Selected row must draw the 4x24 accent indicator')
    equal(bar.Position.X,w.Position.X)
    local label
    for _,d in ipairs(Mock.drawings) do
        if not d.Removed and d.Visible and d._kind=='Text' and d.Text==sections[1].Name then label=d end
    end
    assert(label and label.Position.X==rows[1].frame.AbsolutePosition.X+48,'Navigation labels start 48 px in')
    item:Destroy()
end)

test('Settings search box: 2 px border, accent focus and a right-hand magnifier',function()
    local item=NewUI(Bundle)
    local w=item:CreateWindow({Name='Search',Size=Vector2.new(960,700),Position=Vector2.new(0,0)})
    w:AddSection('System'):AddToggle({Name='Thing'})
    Mock.tick(60)
    local runtime=item._runtime
    local search=runtime.search
    local function borderOf(color)
        for _,d in ipairs(Mock.drawings) do
            if not d.Removed and d.Visible and d._kind=='Square' and d.Color==color
                and d.Size.X==search._anchor.w and d.Size.Y==2 then return d end
        end
    end
    assert(borderOf(Color3.fromRGB(153,153,153)),'Unfocused search box needs a 2 px #999999 border')
    equal(search._anchor.w,288)
    equal(search._anchor.h,32)
    local magnifier=false
    for _,d in ipairs(Mock.drawings) do
        if not d.Removed and d.Visible and d._kind=='Circle' and d.Radius==5
            and d.Position.X>search._anchor.x+search._anchor.w-30 then magnifier=true end
    end
    assert(magnifier,'The magnifier glyph belongs at the right of the box')
    clickHit(runtime,search,'textbox'); Mock.tick(1)
    assert(runtime.edit==search)
    assert(borderOf(Color3.fromRGB(0,120,215)),'Focused search box border must turn accent')
    Mock.press('Escape'); Mock.tick(1)
    item:Destroy()
end)

test('toggle and slider follow the Windows 10 control templates',function()
    local item=NewUI(Bundle)
    local w=item:CreateWindow({Name='Controls',Size=Vector2.new(900,700),Position=Vector2.new(0,0)})
    local s=w:AddSection('System')
    local toggle=s:AddToggle({Name='Night light',Flag='night',Default=true})
    local slider=s:AddSlider({Name='Brightness',Flag='bright',Min=0,Max=100,Default=50})
    Mock.tick(60)
    local runtime=item._runtime
    local track=hit(runtime,toggle,'toggle')
    equal(track.frame.AbsoluteSize.X,44)
    equal(track.frame.AbsoluteSize.Y,20)
    local knob,label,offTrack
    for _,d in ipairs(Mock.drawings) do
        if not d.Removed and d.Visible then
            if d._kind=='Circle' and d.Radius==6 and d.Color==Color3.fromRGB(255,255,255) then knob=d end
            if d._kind=='Text' and d.Text=='On' then label=d end
        end
    end
    assert(knob,'Toggle knob must stay a 12 px circle')
    local switch=track.frame
    assert(label and label.Position.X>=switch.AbsolutePosition.X+switch.AbsoluteSize.X+13
        and label.Position.X<=switch.AbsolutePosition.X+switch.AbsoluteSize.X+15,'On label sits 14 px after the track')
    equal(knob.Position.X,switch.AbsolutePosition.X+44-4-6)
    toggle:SetValue(false); Mock.tick(25)
    local stroke,interior,pill
    for _,d in ipairs(Mock.drawings) do
        if not d.Removed and d.Visible and (d.Transparency or 0)>0 and d._kind=='Square' then
            local inside=d.Position.Y>=switch.AbsolutePosition.Y-1
                and d.Position.Y<=switch.AbsolutePosition.Y+switch.AbsoluteSize.Y
                and d.Position.X>=switch.AbsolutePosition.X-1
                and d.Position.X<=switch.AbsolutePosition.X+switch.AbsoluteSize.X
            if inside and d.Color==Color3.fromRGB(51,51,51) then stroke=d end
            if inside and d.Color==Color3.fromRGB(255,255,255) then interior=d end
            if inside and d.Color==Color3.fromRGB(0,120,215) then pill=d end
        end
    end
    assert(stroke,'Off toggle keeps a #333333 stroke')
    assert(interior,'Off toggle is hollow rather than grey-filled')
    assert(not pill,'The accent fill must be gone when the toggle is off')
    local sliderHit=hit(runtime,slider,'slider')
    equal(sliderHit.frame.AbsoluteSize.Y,32)
    local rail,thumb
    for _,d in ipairs(Mock.drawings) do
        if not d.Removed and d.Visible and d._kind=='Square' then
            if d.Color==Color3.fromRGB(153,153,153) and d.Size.Y==2 and d.Size.X==sliderHit.data.w then rail=d end
            if d.Color==Color3.fromRGB(0,120,215) and d.Size.X==8 then thumb=d end
        end
    end
    assert(rail,'Slider rail must use SliderTrackFill #999999 at 2 px')
    assert(thumb,'Slider thumb must be an 8 px wide gripper')
    item:Destroy()
end)

test('combo fields, flyout lists and checkboxes use the Windows 10 surfaces',function()
    window:SetVisible(true); window:SetMinimized(false); window.Scroll=0; rt:ClosePopup(); rt:Dirty(); Mock.tick(60)
    local field=dropdown._anchor
    local border
    for _,d in ipairs(Mock.drawings) do
        if not d.Removed and d.Visible and d._kind=='Square' and d.Color==Color3.fromRGB(153,153,153)
            and d.Size.X==field.w and d.Size.Y==2 then border=d end
    end
    assert(border,'Combo fields use a 2 px #999999 border')
    clickHit(rt,dropdown,'dropdown'); Mock.tick(20)
    local popup=rt.popup
    assert(popup,'Dropdown must open')
    local surface,flyoutBorder,selected
    for _,d in ipairs(Mock.drawings) do
        if not d.Removed and d.Visible and d._kind=='Square' then
            if d.Color==Color3.fromRGB(242,242,242) and d.Size.X==popup.rect.w and d.Size.Y==popup.rect.h then surface=d end
            if d.Color==Color3.fromRGB(219,219,219) and d.Size.X==popup.rect.w and d.Size.Y==1 then flyoutBorder=d end
            if d.Color==Color3.fromRGB(153,201,239) then selected=d end
        end
    end
    assert(surface,'Flyout surface must use the transient background #F2F2F2')
    assert(flyoutBorder,'Flyout border must use the transient border #DBDBDB')
    assert(selected,'The selected option must use the accent-low highlight')
    rt:ClosePopup(); Mock.tick(1)
    clickHit(rt,multi,'dropdown'); Mock.tick(20)
    local box
    for _,d in ipairs(Mock.drawings) do
        if not d.Removed and d.Visible and d._kind=='Square' and d.Size.X==20 and d.Size.Y==20 then box=d end
    end
    assert(box,'Multi-select checkboxes are 20 x 20')
    rt:ClosePopup(); Mock.tick(1)
end)

test('notifications use the transient flyout surface without an accent stripe',function()
    ui:Notify({Title='Flyout',Content='Body',Duration=4}); Mock.tick(30)
    local card,stripe
    for _,d in ipairs(Mock.drawings) do
        if not d.Removed and d.Visible and d._kind=='Square' then
            if d.Color==Color3.fromRGB(242,242,242) and d.Size.Y==72 then card=d end
            if d.Color==Color3.fromRGB(0,120,215) and d.Size.X==3 then stripe=d end
        end
    end
    assert(card,'Notification card must use the transient surface')
    assert(not stripe,'Windows 10 toasts have no accent stripe')
    Mock.tick(300); equal(#rt.notifications,0)
end)

test('back button appears only while history is available',function()
    local item=NewUI(Bundle)
    local w=item:CreateWindow({Name='History',Size=Vector2.new(960,700),Position=Vector2.new(0,0)})
    local first=w:AddSection('First'); first:AddLabel({Name='Start'})
    local second=w:AddSection('Second')
    for i=1,30 do second:AddLabel({Name='Row '..i}) end
    Mock.tick(60)
    local runtime=item._runtime
    assert(w.MaxScroll>0,'Content must overflow for a history entry')
    fails(function() hit(runtime,w,'back') end)
    clickHit(runtime,second,'sectionNavigation'); Mock.tick(1)
    assert(hit(runtime,w,'back'),'Back button must exist once history is recorded')
    clickHit(runtime,w,'back'); Mock.tick(1)
    equal(w.Scroll,0)
    fails(function() hit(runtime,w,'back') end)
    item:Destroy()
end)

test('overlay scrollbar fades in while scrolling and thickens under the pointer',function()
    local item=NewUI(Bundle)
    local w=item:CreateWindow({Name='Scrolling',Size=Vector2.new(900,400),Position=Vector2.new(0,0)})
    local section=w:AddSection('List')
    for i=1,40 do section:AddLabel({Name='Row '..i}) end
    Mock.tick(60)
    local runtime=item._runtime
    assert(w.MaxScroll>0,'Content must overflow')
    Mock.tick(90); equal(runtime.scrollbarAlpha,0)
    Mock.move(600,250); Mock.wheel(-100); Mock.tick(12)
    assert(runtime.scrollbarAlpha>.5,'Scrollbar must fade in while scrolling')
    equal(runtime.scrollbarGrow,0)
    local clip=runtime.contentClip
    Mock.move(w.Position.X+w.Size.X-6,clip.y+20); Mock.tick(30)
    assert(runtime.scrollbarGrow>.5,'Scrollbar must thicken under the pointer')
    Mock.move(600,250); Mock.tick(200)
    equal(runtime.scrollbarAlpha,0)
    equal(runtime.scrollbarGrow,0)
    item:Destroy()
end)

test('a combo with no options is disabled like the Settings app',function()
    local item=NewUI(Bundle)
    local w=item:CreateWindow({Name='Disabled',Size=Vector2.new(900,600),Position=Vector2.new(0,0)})
    local s=w:AddSection('System')
    local dd=s:AddDropdown({Name='Mode',Flag='mode',Options={}})
    Mock.tick(60)
    local runtime=item._runtime
    fails(function() hit(runtime,dd,'dropdown') end)
    local disabled
    for _,d in ipairs(Mock.drawings) do
        if not d.Removed and d.Visible and d._kind=='Square' and d.Color==Color3.fromRGB(204,204,204)
            and d.Size.Y==32 and d.Size.X==280 then disabled=d end
    end
    assert(disabled,'An empty combo must use SystemControlDisabledBaseLowBrush')
    dd:SetOptions({'Light','Dark'}); Mock.tick(1)
    assert(hit(runtime,dd,'dropdown'),'Supplying options must re-enable the combo')
    item:Destroy()
end)

test('slider values are click-to-edit with validation and arrow stepping',function()
    local item=NewUI(Bundle)
    local w=item:CreateWindow({Name='Values',Size=Vector2.new(900,600),Position=Vector2.new(0,0)})
    local s=w:AddSection('System')
    local counts=0
    local slider=s:AddSlider({Name='Delay',Flag='delay',Min=0,Max=1000,Step=5,Default=350,Callback=function() counts=counts+1 end})
    local other=s:AddToggle({Name='Enabled',Flag='enabled'})
    Mock.tick(60)
    local runtime=item._runtime
    local session=slider._valueEdit
    assert(session,'The slider value must expose an edit session')
    local function openValue()
        local record=hit(runtime,session,'value')
        Mock.click(record.rect.x+12,record.rect.y+record.rect.h/2)
        assert(runtime.edit==session,'Clicking the value must start editing')
    end
    openValue()
    equal(runtime.box.SelectionStart,1)
    runtime.box.Text='250'; Mock.tick(1)
    Mock.press('Return'); Mock.tick(1)
    equal(slider.Value,250); equal(counts,1); assert(not runtime.edit)
    openValue(); runtime.box.Text='abc'; Mock.press('Return'); equal(slider.Value,250); equal(counts,1)
    openValue(); runtime.box.Text='12x3'; equal(runtime.box.Text,'123'); Mock.press('Escape')
    equal(slider.Value,250); assert(not runtime.edit)
    openValue(); runtime.box.Text='9999'; Mock.press('Return'); equal(slider.Value,1000)
    openValue(); runtime.box.Text='352'; Mock.press('Up'); Mock.press('Return'); equal(slider.Value,355)
    openValue(); Mock.press('Down'); Mock.press('Return'); equal(slider.Value,350)
    openValue(); runtime.box.Text='400'
    clickHit(runtime,other,'toggle')
    equal(slider.Value,400); equal(other.Value,true); assert(not runtime.edit)
    -- A window too narrow for the value field falls back to plain text.
    local narrow=NewUI(Bundle)
    local narrowWindow=narrow:CreateWindow({Name='Narrow',Size=Vector2.new(320,300),Position=Vector2.new(0,0)})
    narrowWindow:AddSection('Tight'):AddSlider({Name='Level',Flag='level',Min=0,Max=10,Default=5})
    Mock.tick(30)
    local narrowRuntime=narrow._runtime
    fails(function() hit(narrowRuntime,narrowWindow.Sections[1].Controls[1]._valueEdit,'value') end)
    equal(narrowWindow.Sections[1].Controls[1].Value,5)
    narrow:Destroy()
    item:Destroy()
end)

test('Destroy idempotent cleanup and fresh reload',function()
    ui:Destroy(); ui:Destroy(); assert(next(Mock.actions)==nil); equal(Mock.liveConnections(),0); equal(Mock.visibleDrawings(),0)
    for _,d in ipairs(Mock.drawings) do assert(d.Removed,'Leaked drawing') end
    for _,g in ipairs(Mock.instances) do assert(g.Destroyed,'Leaked invisible instance') end
    assert(next(ui.Flags)==nil and next(ui._flags)==nil and #ui._controls==0)
    fails(function() toggle:SetValue(true) end)
    local fresh=NewUI(Bundle); fresh:CreateWindow({Name='Reload'}):AddSection('A'):AddToggle({Name='Enabled',Flag='enabled'})
    Mock.tick(40); equal(Mock.liveConnections(),10); fresh:Destroy(); equal(Mock.liveConnections(),0)
end)
print(string.format('%d interaction groups passed',passed))
