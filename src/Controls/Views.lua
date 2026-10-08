local Util=require('Internal.Util')
local Theme=require('Internal.Theme')
local Views={Theme=Theme}
local function blend(a,b,t)
    return Color3.new(a.R+(b.R-a.R)*t,a.G+(b.G-a.G)*t,a.B+(b.B-a.B)*t)
end
local function surface(rt,c,role,base,data)
    local amount=rt:Visual(c,role,data)
    local pressed=rt.pressedHit
    if pressed and pressed.owner==c and pressed.role==role and (data==nil or pressed.data==data) then return Theme.pressed end
    return blend(base,Theme.hover,amount)
end
local function fieldBox(rt,c,role,r,clip,focused,base)
    local d=rt.renderer
    local fill=role=='textbox' and Theme.field or surface(rt,c,role,base or Theme.field)
    d:Rect(r,fill,clip,12)
    d:Border(r,focused and Theme.accent or Theme.Mix(Theme.controlBorder,Theme.borderHover,rt:Visual(c,role)),clip,13,role=='button' and 1 or 2)
end
function Views.Field(r)
    local width=math.min(180,math.max(120,r.w*.4))
    local height=Theme.metrics.fieldHeight
    return Util.rect(r.x+r.w-width,r.y+(r.h-height)/2,width,height)
end
function Views.Control(rt,c,r,clip)
    local d,t=rt.renderer,Theme
    local x,y,w=r.x,r.y,r.w
    local kind=c.Kind
    if kind=='Separator' then
        if c.Name~='' then d:Text(c.Name,x,y+5,t.muted,w,clip,12,t.bodySize,t.headingFont) end
        d:Rect(Util.rect(x,y+28,w,1),t.line,clip,11); return
    end
    if kind=='Label' then d:Text(c.Name,x,y+4,t.muted,w,clip,12,t.captionSize); return end
    if kind=='Button' then
        local button=Util.rect(x,y+4,math.min(w,math.max(88,math.ceil(d:Width(c.Name,t.bodySize))+24)),t.metrics.fieldHeight)
        fieldBox(rt,c,'button',button,clip,false,t.button)
        d:Text(c.Name,button.x+12,button.y+8,t.text,button.w-24,clip,14)
        rt:Hit(button,c,'button',clip); return
    end
    if kind=='Slider' then
        local value=tostring(c.Value)
        local valueWidth=math.min(w*.3,d:Width(value,t.bodySize))
        d:Text(c.Name,x,y+4,t.text,w-valueWidth-t.metrics.columnGap,clip,12)
        d:Text(value,x+w-valueWidth,y+4,t.muted,valueWidth,clip,12)
        local track=Util.rect(x+7,y+34,w-14,2)
        local ratio=c._visual or (c.Value-c.Min)/(c.Max-c.Min)
        local active=rt.drag and rt.drag.control==c
        local amount=rt:Visual(c,'slider')
        local color=active and t.accentHover or blend(t.accent,t.accentHover,amount)
        d:Rect(track,t.line,clip,12)
        d:Rect(Util.rect(track.x,track.y,track.w*ratio,track.h),color,clip,13)
        d:Round(Util.rect(track.x+track.w*ratio-7,track.y-6,14,14),7,color,clip,14)
        rt:Hit(r,c,'slider',clip,track); return
    end
    local field=c._anchor or Views.Field(r)
    d:Text(c.Name,x,y+12,t.text,field.x-x-t.metrics.columnGap,clip,12)
    if kind=='Toggle' then
        local switch=Util.rect(x+w-40,y+10,40,20)
        d:Text(c.Value and 'On' or 'Off',switch.x-36,y+12,t.muted,30,clip,12,t.bodySize)
        local ratio=c._visual or (c.Value and 1 or 0)
        local amount=rt:Visual(c,'toggle')
        local on=blend(t.accent,t.accentHover,amount)
        if rt.pressedHit and rt.pressedHit.owner==c then on=t.accentHover end
        d:Round(switch,10,c.Value and on or blend(t.muted,t.text,amount),clip,12)
        if not c.Value then d:Round(Util.rect(switch.x+2,switch.y+2,36,16),8,t.white,clip,13) end
        d:Round(Util.rect(switch.x+4+20*ratio,switch.y+4,12,12),6,c.Value and t.white or t.muted,clip,14)
        rt:Hit(r,c,'toggle',clip)
    elseif kind=='Dropdown' or kind=='MultiDropdown' then
        local open=rt.popup and rt.popup.control==c
        fieldBox(rt,c,'dropdown',field,clip,open)
        local text=kind=='Dropdown' and c.Value or (#c.Value==0 and 'None' or table.concat(c.Value,', '))
        d:Text(text,field.x+8,field.y+8,t.text,field.w-30,clip,14,t.bodySize)
        local cx,cy=field.x+field.w-15,field.y+14
        d:Line(cx-4,cy,cx,cy+4,t.text,clip,14)
        d:Line(cx,cy+4,cx+4,cy,t.text,clip,14)
        rt:Hit(r,c,'dropdown',clip,field)
    elseif kind=='Textbox' then
        fieldBox(rt,c,'textbox',field,clip,rt.edit==c)
        if rt.edit==c then rt:DrawEditing(c,field,clip)
        else d:Text(c.Value=='' and c.Placeholder or c.Value,field.x+8,field.y+8,c.Value=='' and t.muted or t.text,field.w-16,clip,14,t.bodySize) end
        rt:Hit(r,c,'textbox',clip,field)
    elseif kind=='Keybind' then
        fieldBox(rt,c,'keybind',field,clip,rt.capture==c)
        d:Text(rt.capture==c and 'Press a key...' or c.Value,field.x+8,field.y+8,rt.capture==c and t.accent or t.text,field.w-16,clip,14,t.bodySize)
        rt:Hit(r,c,'keybind',clip)
    elseif kind=='ColorPicker' then
        fieldBox(rt,c,'color',field,clip,rt.popup and rt.popup.control==c)
        local swatch=Util.rect(field.x+6,field.y+6,20,20)
        d:Rect(swatch,c.Value,clip,14); d:Border(swatch,t.line,clip,15)
        local color=c.Value
        d:Text(string.format('#%02X%02X%02X',math.floor(color.R*255+.5),math.floor(color.G*255+.5),math.floor(color.B*255+.5)),field.x+34,field.y+8,t.text,field.w-42,clip,14,t.bodySize)
        rt:Hit(r,c,'color',clip,field)
    end
end
function Views.Popup(rt,popup,retiring)
    popup=popup or rt.popup
    if not popup then return end
    local c=popup.control
    local anchor=c._anchor
    if not anchor or not Util.contains(c._row,rt.contentClip) then if not retiring then rt:ClosePopup() end; return end
    local view=rt:Viewport()
    local d,t=rt.renderer,Views.Theme
    local width=c.Kind=='ColorPicker' and 230 or anchor.w
    local itemHeight=t.metrics.itemHeight
    local padding=t.metrics.popupPadding
    width=math.min(width,view.X-16)
    local wanted=c.Kind=='ColorPicker' and 214 or math.min(math.max(1,#c.Options)*itemHeight+padding*2,264)
    local below=view.Y-(anchor.y+anchor.h+6)-8
    local above=anchor.y-14
    local down=below>=wanted or below>=above
    local height=math.min(wanted,math.max(0,down and below or above))
    if height<40 then if not retiring then rt:ClosePopup() end; return end
    local r=Util.rect(Util.clamp(anchor.x,8,view.X-width-8),down and anchor.y+anchor.h+6 or anchor.y-height-6,width,height)
    popup.rect=r
    if c.Kind=='ColorPicker' and height<214 then if not retiring then rt:ClosePopup() end; return end
    local alpha=d.alpha
    d.alpha=alpha*(popup.alpha or 1)
    local function hit(...) if not retiring then rt:Hit(...) end end
    d:Rect(r,t.card,nil,41); d:Border(r,t.line,nil,42)
    hit(r,c,'popup',nil)
    if c.Kind=='ColorPicker' then
        if height<214 then if not retiring then rt:ClosePopup() end; return end
        local sv=Util.rect(r.x+12,r.y+12,r.w-24,126)
        local hue=Util.rect(r.x+12,r.y+148,r.w-24,14)
        local h,s,v=c.Value:ToHSV()
        if popup.hue==nil then popup.hue=h end
        h=popup.hue
        if popup.paletteHue~=h then
            popup.paletteHue=h; popup.palette={}
            for row=0,15 do for col=0,23 do table.insert(popup.palette,Color3.fromHSV(h,col/23,1-row/15)) end end
        end
        if not popup.hueColors then
            popup.hueColors={}
            for col=0,35 do popup.hueColors[col+1]=Color3.fromHSV(col/35,1,1) end
        end
        local index=1
        for row=0,15 do for col=0,23 do
            d:Rect(Util.rect(sv.x+sv.w*col/24,sv.y+sv.h*row/16,sv.w/24+.01,sv.h/16+.01),popup.palette[index],nil,42)
            index=index+1
        end end
        for col=0,35 do d:Rect(Util.rect(hue.x+hue.w*col/36,hue.y,hue.w/36+.01,hue.h),popup.hueColors[col+1],nil,42) end
        d:Round(Util.rect(sv.x+s*sv.w-5,sv.y+(1-v)*sv.h-5,10,10),5,t.white,r,43)
        d:Round(Util.rect(sv.x+s*sv.w-3,sv.y+(1-v)*sv.h-3,6,6),3,c.Value,r,44)
        d:Rect(Util.rect(hue.x+h*hue.w-1,hue.y-2,2,hue.h+4),t.white,r,43)
        d:Text(string.format('RGB  %d  %d  %d',math.floor(c.Value.R*255+.5),math.floor(c.Value.G*255+.5),math.floor(c.Value.B*255+.5)),r.x+12,r.y+178,t.text,r.w-24,r,43,t.captionSize)
        hit(sv,c,'sv',r,sv); hit(hue,c,'hue',r,hue)
    else
        local clip=Util.rect(r.x+padding,r.y+padding,r.w-padding*2,r.h-padding*2)
        local max=math.max(0,#c.Options*itemHeight-clip.h)
        popup.scroll=Util.clamp(popup.scroll or 0,0,max); popup.maxScroll=max
        local first=math.max(1,math.floor(popup.scroll/itemHeight)+1)
        local last=math.min(#c.Options,math.ceil((popup.scroll+clip.h)/itemHeight))
        for i=first,last do
            local item=c.Options[i]
            local row=Util.rect(clip.x,clip.y+(i-1)*itemHeight-popup.scroll,clip.w,itemHeight)
            local selected=c.Kind=='Dropdown' and c.Value==item
            if c.Kind=='MultiDropdown' then for _,name in ipairs(c.Value) do if name==item then selected=true end end end
            local amount=rt:Visual(c,'option',item)
            local base=selected and c.Kind=='Dropdown' and t.selection or t.card
            d:Rect(row,blend(base,t.hover,amount),clip,42)
            local inset=8
            if c.Kind=='MultiDropdown' then
                local box=Util.rect(row.x+8,row.y+8,16,16)
                d:Rect(box,selected and t.accent or t.white,clip,43)
                d:Border(box,selected and t.accent or t.muted,clip,44)
                if selected then
                    d:Line(box.x+3,box.y+8,box.x+6,box.y+11,t.white,clip,45,2)
                    d:Line(box.x+6,box.y+11,box.x+13,box.y+4,t.white,clip,45,2)
                end
                inset=32
            end
            d:Text(item,row.x+inset,row.y+7,t.text,row.w-inset-8,clip,43,t.bodySize)
            hit(row,c,'option',clip,item)
        end
        if #c.Options==0 then d:Text('No options',clip.x+8,clip.y+7,t.muted,clip.w-16,clip,43,t.bodySize) end
        if max>0 then
            local hbar=math.max(16,clip.h*clip.h/(#c.Options*itemHeight))
            d:Round(Util.rect(r.x+r.w-4,clip.y+(clip.h-hbar)*popup.scroll/max,2,hbar),1,t.muted,r,44)
        end
    end
    d.alpha=alpha
end
return Views
