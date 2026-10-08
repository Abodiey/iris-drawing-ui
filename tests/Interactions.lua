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
    clickHit(rt,text,'textbox'); rt.box.Text=string.rep('é',40); equal(utf8.len(rt.box.Text),24)
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
    window:SetSize(Vector2.new(480,640)); Mock.tick(40); window.Position=Vector2.new(500,160); rt:Dirty(); Mock.tick(1)
    clickHit(rt,color,'color'); Mock.tick(1)
    assert(rt.popup.rect.y<color._anchor.y); assert(rt.popup.rect.x+rt.popup.rect.w<=1000)
    window:SetSize(Vector2.new(500,640)); assert(not rt.popup)
    Mock.viewport(600,400); assert(window.Size.X<=584); assert(window.Size.Y<=384)
    assert(window.Position.X+window.Size.X<=600)
    Mock.viewport(1000,800); window.Position=Vector2.new(80,40); window:SetSize(Vector2.new(480,650)); Mock.tick(50)
end)
test('minimize and hide cancel input, reopen with toggle key',function()
    clickHit(rt,text,'textbox'); rt.box.Text='Committed'; window:SetMinimized(true)
    equal(text.Value,'Committed'); assert(not rt.edit); Mock.tick(50); equal(rt.height,52)
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
    text:SetValue('abcdefé')
    local h=hit(rt,text,'textbox'); local field=h.data
    Mock.click(field.x+8,field.y+10); equal(rt.box.CursorPosition,1)
    Mock.down(field.x+8,field.y+10)
    Mock.move(field.x+8+rt.renderer:Width('abc',13),field.y+10)
    Mock.up(); equal(rt.box.CursorPosition,4); equal(rt.box.SelectionStart,1)
    Mock.tick(1); Mock.press('Escape')
    text:SetValue(string.rep('é',24)); clickHit(rt,text,'textbox')
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
    Mock.tick(40)
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
                    assert(typeof(state.Position)=='Vector2','Visibility set before position')
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
    assert(background and math.abs(background.Transparency-.97)<.00001,'Background opacity was inverted')
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
        equal(record.frame.AbsolutePosition.Y,row.y)
        equal(record.frame.AbsoluteSize.X,row.w)
        equal(record.frame.AbsoluteSize.Y,row.h)
        local value=toggle.Value
        Mock.click(row.x+20,row.y+20)
        equal(toggle.Value,not value)
        equal(rt.pointer.X,row.x+20); equal(rt.pointer.Y,row.y+20)
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
