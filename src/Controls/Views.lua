local Util=require('Internal.Util')
local Theme=require('Internal.Theme')
local Views={Theme=Theme}
local function blend(a,b,t)
    return Color3.new(a.R+(b.R-a.R)*t,a.G+(b.G-a.G)*t,a.B+(b.B-a.B)*t)
end
local function isPressed(rt,c,role,data)
    local pressed=rt.pressedHit
    return pressed and pressed.owner==c and pressed.role==role and (data==nil or pressed.data==data)
end
local function surface(rt,c,role,base,data)
    local amount=rt:Visual(c,role,data)
    if isPressed(rt,c,role,data) then return Theme.pressed end
    return blend(base,Theme.hover,amount)
end
-- Windows 10 text fields use a 2 px border that turns accent on focus and
-- #666666 on pointer over; buttons keep their fill and gain a 1 px border.
local function fieldBox(rt,c,role,r,clip,focused,base,borderWidth)
    local d=rt.renderer
    local fill=role=='textbox' and Theme.field or surface(rt,c,role,base or Theme.field)
    if role=='dropdown' and not isPressed(rt,c,role) then
        fill=blend(base or Theme.field,Theme.pressed,rt:Visual(c,role))
    end
    d:Rect(r,fill,clip,12)
    local color=focused and Theme.accent or Theme.Mix(Theme.controlBorder,Theme.borderHover,rt:Visual(c,role))
    d:Border(r,color,clip,13,borderWidth or 2)
end
function Views.Field(r)
    local width=math.min(Theme.metrics.fieldWidth,r.w)
    local height=Theme.metrics.fieldHeight
    return Util.rect(r.x,r.y+Theme.metrics.controlTop,width,height)
end
function Views.Control(rt,c,r,clip)
    local d,t=rt.renderer,Theme
    local m=t.metrics
    local x,y,w=r.x,r.y,r.w
    local kind=c.Kind
    if kind=='Separator' then
        if c.Name~='' then d:Text(c.Name,x,y+4,t.muted,w,clip,12,t.bodySize) end
        d:Rect(Util.rect(x,y+24,w,1),t.line,clip,11); return
    end
    if kind=='Label' then d:Text(c.Name,x,y+3,t.muted,w,clip,12,t.bodySize); return end
    if kind=='Button' then
        local button=Util.rect(x,y+4,math.min(w,math.max(88,math.ceil(d:Width(c.Name,t.bodySize))+24)),m.fieldHeight)
        local amount=rt:Visual(c,'button')
        local pressed=isPressed(rt,c,'button')
        d:Rect(button,pressed and t.buttonPressed or t.button,clip,12)
        if amount>0 or pressed then
            d:Border(button,Theme.Mix(t.button,t.buttonBorder,amount),clip,13,1)
        end
        d:Text(c.Name,button.x+12,button.y+7,t.text,button.w-24,clip,14)
        rt:Hit(button,c,'button',clip); return
    end
    if kind=='Slider' then
        local width=math.min(w,m.sliderWidth)
        local ratio=c._visual or (c.Value-c.Min)/(c.Max-c.Min)
        local track=Util.rect(x+4,y+34,width-8,m.sliderTrack)
        local active=rt.drag and rt.drag.control==c
        local amount=rt:Visual(c,'slider')
        d:Text(c.Name,x,y+3,t.text,width,clip,12)
        d:Rect(track,t.sliderTrack,clip,12)
        local filled=track.w*ratio
        if filled>0 then d:Rect(Util.rect(track.x,track.y,filled,track.h),active and t.accentPressed or t.accent,clip,13) end
        local cx=track.x+filled
        local thumbW,thumbH=m.sliderThumbWidth,m.sliderThumbHeight
        local thumb=Util.rect(cx-thumbW/2,track.y+track.h/2-thumbH/2,thumbW,thumbH)
        local color=t.accent
        if active then color=t.thumbPressed
        elseif amount>0 then color=Theme.Mix(t.accent,t.thumbHover,amount) end
        d:Round(thumb,thumbW/2,color,clip,14)
        d:Text(tostring(c.Value),track.x+width+16,y+34-m.sliderThumbHeight/2,t.muted,w-width-16,clip,12)
        rt:Hit(Util.rect(x,track.y+track.h/2-m.sliderHit/2,width,m.sliderHit),c,'slider',clip,track); return
    end
    local field=c._anchor or Views.Field(r)
    d:Text(c.Name,x,y+3,t.text,w,clip,12)
    if kind=='Toggle' then
        local trackHeight=m.toggleTrackHeight
        local switch=Util.rect(x,y+m.controlTop+2,m.toggleWidth,trackHeight)
        local ratio=c._visual or (c.Value and 1 or 0)
        local amount=rt:Visual(c,'toggle')
        local pressed=isPressed(rt,c,'toggle')
        d:Text(c.Value and 'On' or 'Off',switch.x+m.toggleWidth+m.toggleLabelGap,switch.y+3,t.text,40,clip,12,t.bodySize)
        if ratio<1 then
            local stroke=pressed and t.togglePressed or Theme.Mix(t.switchStroke,t.switchStrokeHover,amount)
            d:Round(switch,trackHeight/2,stroke,clip,12,1-ratio)
            d:Round(Util.rect(switch.x+2,switch.y+2,switch.w-4,switch.h-4),trackHeight/2-2,t.field,clip,13,1-ratio)
        end
        if ratio>0 then
            local on=pressed and t.togglePressed or Theme.Mix(t.accent,t.accentHover,amount)
            d:Round(switch,trackHeight/2,on,clip,12,ratio)
        end
        local knob=m.toggleKnob
        local knobX=switch.x+m.toggleInset+(switch.w-knob-m.toggleInset*2)*ratio
        local offKnob=pressed and t.white or Theme.Mix(t.checkBorder,t.checkBorderHover,amount)
        d:Round(Util.rect(knobX,switch.y+(trackHeight-knob)/2,knob,knob),knob/2,blend(offKnob,t.white,ratio),clip,14)
        rt:Hit(switch,c,'toggle',clip)
    elseif kind=='Dropdown' or kind=='MultiDropdown' then
        local open=rt.popup and rt.popup.control==c
        local text=kind=='Dropdown' and c.Value or (#c.Value==0 and 'None' or table.concat(c.Value,', '))
        if #c.Options==0 then
            -- Windows 10 disables a combo box that has nothing to choose.
            d:Rect(field,t.disabled,clip,12)
            d:Border(field,t.disabled,clip,13,2)
            d:Text(text=='' and 'None' or text,field.x+12,field.y+8,t.disabledText,field.w-44,clip,14,t.bodySize)
            return
        end
        fieldBox(rt,c,'dropdown',field,clip,open)
        d:Text(text,field.x+12,field.y+8,t.text,field.w-44,clip,14,t.bodySize)
        local cx,cy=field.x+field.w-16,field.y+16
        d:Line(cx-5,cy-2,cx,cy+3,t.text,clip,14)
        d:Line(cx,cy+3,cx+5,cy-2,t.text,clip,14)
        rt:Hit(field,c,'dropdown',clip,field)
    elseif kind=='Textbox' then
        fieldBox(rt,c,'textbox',field,clip,rt.edit==c)
        if rt.edit==c then rt:DrawEditing(c,field,clip)
        else d:Text(c.Value=='' and c.Placeholder or c.Value,field.x+12,field.y+8,c.Value=='' and t.placeholder or t.text,field.w-24,clip,14,t.bodySize) end
        rt:Hit(field,c,'textbox',clip,field)
    elseif kind=='Keybind' then
        fieldBox(rt,c,'keybind',field,clip,rt.capture==c)
        d:Text(rt.capture==c and 'Press a key...' or c.Value,field.x+12,field.y+8,rt.capture==c and t.accent or t.text,field.w-24,clip,14,t.bodySize)
        rt:Hit(field,c,'keybind',clip)
    elseif kind=='ColorPicker' then
        fieldBox(rt,c,'color',field,clip,rt.popup and rt.popup.control==c)
        local swatch=Util.rect(field.x+5,field.y+5,22,22)
        d:Rect(swatch,c.Value,clip,14); d:Border(swatch,t.controlBorder,clip,15,1)
        local color=c.Value
        d:Text(string.format('#%02X%02X%02X',math.floor(color.R*255+.5),math.floor(color.G*255+.5),math.floor(color.B*255+.5)),field.x+36,field.y+8,t.text,field.w-48,clip,14,t.bodySize)
        rt:Hit(field,c,'color',clip,field)
    end
end
function Views.Popup(rt,popup,retiring)
    popup=popup or rt.popup
    if not popup then return end
    local c=popup.control
    local anchor=c._anchor
    if not anchor or not Util.contains(anchor,rt.contentClip) then if not retiring then rt:ClosePopup() end; return end
    local view=rt:Viewport()
    local d,t=rt.renderer,Views.Theme
    local m=t.metrics
    local width=c.Kind=='ColorPicker' and 230 or anchor.w
    local itemHeight=m.itemHeight
    local padding=m.popupPadding
    width=math.min(width,view.X-16)
    local wanted=c.Kind=='ColorPicker' and 214 or math.min(math.max(1,#c.Options)*itemHeight+padding*2,504)
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
    -- Windows 10 flyouts use the transient background with a 1 px border.
    d:Rect(r,t.card,nil,41); d:Border(r,t.line,nil,42,1)
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
            local base=selected and t.accentLow or t.card
            d:Rect(row,surface(rt,c,'option',base,item),clip,42)
            local inset=12
            if c.Kind=='MultiDropdown' then
                local box=Util.rect(row.x+11,row.y+(itemHeight-m.checkbox)/2,m.checkbox,m.checkbox)
                local checked=selected
                local pressed=isPressed(rt,c,'option',item)
                local hover=Theme.Mix(t.checkBorder,t.checkBorderHover,amount)
                if checked then
                    d:Rect(box,pressed and t.pressed or (amount>0 and t.accentHover or t.accent),clip,43)
                    d:Border(box,pressed and t.pressed or (amount>0 and t.accentHover or t.accent),clip,44,1)
                    local glyph=m.checkGlyph
                    local gx,gy=box.x+(m.checkbox-glyph)/2,box.y+(m.checkbox-glyph)/2
                    d:Line(gx+1,gy+glyph/2,gx+glyph/2-1,gy+glyph-3,t.white,clip,45,2)
                    d:Line(gx+glyph/2-1,gy+glyph-3,gx+glyph-1,gy+2,t.white,clip,45,2)
                else
                    d:Rect(box,pressed and t.pressed or t.field,clip,43)
                    d:Border(box,pressed and t.pressed or hover,clip,44,1)
                end
                inset=11+m.checkbox+8
            end
            d:Text(item,row.x+inset,row.y+7,t.text,row.w-inset-8,clip,43,t.bodySize)
            hit(row,c,'option',clip,item)
        end
        if #c.Options==0 then d:Text('No options',clip.x+11,clip.y+7,t.muted,clip.w-22,clip,43,t.bodySize) end
        if max>0 then
            local hbar=math.max(16,clip.h*clip.h/(#c.Options*itemHeight))
            d:Round(Util.rect(r.x+r.w-6,clip.y+(clip.h-hbar)*popup.scroll/max,2,hbar),1,t.scrollbar,r,44)
        end
    end
    d.alpha=alpha
end
return Views
