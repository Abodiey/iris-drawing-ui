local Util=require('Internal.Util')
local Views={}
Views.Theme={bg=Color3.fromRGB(23,24,28),card=Color3.fromRGB(34,35,41),hover=Color3.fromRGB(43,45,52),field=Color3.fromRGB(48,50,58),text=Color3.fromRGB(242,242,247),muted=Color3.fromRGB(152,154,165),accent=Color3.fromRGB(10,132,255),green=Color3.fromRGB(48,209,88),line=Color3.fromRGB(55,57,65),white=Color3.new(1,1,1)}
function Views.Control(rt,c,r,clip)
    local d,t=rt.renderer,Views.Theme
    local hover=rt.hoverOwner==c
    local x,y,w=r.x,r.y,r.w
    if c.Kind=='Separator' then
        if c.Name~='' then d:Text(c.Name,x+12,y+4,t.muted,w-24,clip,12,12) end
        d:Rect(Util.rect(x+12,y+24,w-24,1),t.line,clip,11); return
    end
    if c.Kind=='Label' then d:Text(c.Name,x+12,y+13,t.muted,w-24,clip,12); return end
    d:Round(Util.rect(x,y,w,r.h-2),8,hover and t.hover or t.card,clip,11)
    local kind=c.Kind
    if kind=='Slider' then
        d:Text(c.Name,x+12,y+8,t.text,w-108,clip,12)
        d:Text(tostring(c.Value),x+w-90,y+8,t.muted,78,clip,12)
        local track=Util.rect(x+14,y+42,w-28,4)
        local ratio=c._visual or (c.Value-c.Min)/(c.Max-c.Min)
        d:Round(track,2,t.field,clip,12)
        d:Round(Util.rect(track.x,track.y,track.w*ratio,track.h),2,t.accent,clip,13)
        d:Round(Util.rect(track.x+track.w*ratio-7,track.y-5,14,14),7,t.white,clip,14)
        rt:Hit(r,c,'slider',clip,track); return
    end
    local valueWidth=math.min(180,w*0.45)
    local field=Util.rect(x+w-valueWidth-12,y+8,valueWidth,28)
    d:Text(c.Name,x+12,y+13,t.text,w-valueWidth-36,clip,12)
    if kind=='Toggle' then
        local switch=Util.rect(x+w-54,y+10,42,24)
        local ratio=c._visual or (c.Value and 1 or 0)
        d:Round(switch,12,c.Value and t.green or t.field,clip,12)
        d:Round(Util.rect(switch.x+3+18*ratio,switch.y+3,18,18),9,t.white,clip,13)
        rt:Hit(r,c,'toggle',clip)
    elseif kind=='Button' then
        d:Text('Run',x+w-44,y+13,t.accent,32,clip,12)
        rt:Hit(r,c,'button',clip)
    elseif kind=='Dropdown' or kind=='MultiDropdown' then
        d:Round(field,6,t.field,clip,12)
        local text=kind=='Dropdown' and c.Value or (#c.Value==0 and 'None' or table.concat(c.Value,', '))
        d:Text(text,field.x+8,field.y+5,t.text,field.w-28,clip,13,13)
        d:Text('v',field.x+field.w-17,field.y+5,t.muted,10,clip,13,13)
        rt:Hit(r,c,'dropdown',clip,field)
    elseif kind=='Textbox' then
        d:Round(field,6,rt.edit==c and t.accent or t.field,clip,12)
        if rt.edit==c then
            d:Round(Util.rect(field.x+1,field.y+1,field.w-2,field.h-2),5,t.field,clip,13)
            rt:DrawEditing(c,field,clip)
        else d:Text(c.Value=='' and c.Placeholder or c.Value,field.x+8,field.y+5,c.Value=='' and t.muted or t.text,field.w-16,clip,14,13) end
        rt:Hit(r,c,'textbox',clip,field)
    elseif kind=='Keybind' then
        d:Round(field,6,rt.capture==c and t.accent or t.field,clip,12)
        d:Text(rt.capture==c and 'Press key...' or c.Value,field.x+8,field.y+5,t.text,field.w-16,clip,13,13)
        rt:Hit(r,c,'keybind',clip)
    elseif kind=='ColorPicker' then
        d:Round(field,6,t.field,clip,12)
        d:Round(Util.rect(field.x+4,field.y+4,20,20),5,c.Value,clip,13)
        local color=c.Value
        d:Text(string.format('#%02X%02X%02X',math.floor(color.R*255+.5),math.floor(color.G*255+.5),math.floor(color.B*255+.5)),field.x+32,field.y+5,t.text,field.w-40,clip,13,13)
        rt:Hit(r,c,'color',clip,field)
    end
end
function Views.Popup(rt)
    local popup=rt.popup
    if not popup then return end
    local c=popup.control
    local anchor=c._anchor
    if not anchor or not Util.contains(c._row,rt.contentClip) then rt:ClosePopup(); return end
    local view=rt:Viewport()
    local d,t=rt.renderer,Views.Theme
    local width=c.Kind=='ColorPicker' and 230 or math.max(180,anchor.w)
    width=math.min(width,view.X-16)
    local wanted=c.Kind=='ColorPicker' and 214 or math.min(math.max(1,#c.Options)*30+12,252)
    local below=view.Y-(anchor.y+anchor.h+6)-8
    local above=anchor.y-14
    local down=below>=wanted or below>=above
    local height=math.min(wanted,math.max(0,down and below or above))
    if height<40 then rt:ClosePopup(); return end
    local r=Util.rect(Util.clamp(anchor.x,8,view.X-width-8),down and anchor.y+anchor.h+6 or anchor.y-height-6,width,height)
    popup.rect=r
    d:Round(Util.rect(r.x-2,r.y-2,r.w+4,r.h+4),10,t.line,nil,40)
    d:Round(r,8,t.card,nil,41)
    rt:Hit(r,c,'popup',nil)
    if c.Kind=='ColorPicker' then
        if height<214 then rt:ClosePopup(); return end
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
        d:Text(string.format('RGB  %d  %d  %d',math.floor(c.Value.R*255+.5),math.floor(c.Value.G*255+.5),math.floor(c.Value.B*255+.5)),r.x+12,r.y+178,t.text,r.w-24,r,43,13)
        rt:Hit(sv,c,'sv',r,sv); rt:Hit(hue,c,'hue',r,hue)
    else
        local clip=Util.rect(r.x+6,r.y+6,r.w-12,r.h-12)
        local max=math.max(0,#c.Options*30-clip.h)
        popup.scroll=Util.clamp(popup.scroll or 0,0,max); popup.maxScroll=max
        local first=math.max(1,math.floor(popup.scroll/30)+1)
        local last=math.min(#c.Options,math.ceil((popup.scroll+clip.h)/30))
        for i=first,last do
            local item=c.Options[i]
            local row=Util.rect(clip.x,clip.y+(i-1)*30-popup.scroll,clip.w,30)
            local selected=c.Kind=='Dropdown' and c.Value==item
            if c.Kind=='MultiDropdown' then for _,name in ipairs(c.Value) do if name==item then selected=true end end end
            if selected or (rt.hoverOwner==c and rt.hoverRole=='option' and rt.hoverData==item) then d:Round(row,5,selected and t.accent or t.hover,clip,42) end
            d:Text(item,row.x+8,row.y+7,t.text,row.w-16,clip,43,13)
            rt:Hit(row,c,'option',clip,item)
        end
        if #c.Options==0 then d:Text('No options',clip.x+8,clip.y+7,t.muted,clip.w-16,clip,43,13) end
        if max>0 then
            local hbar=math.max(16,clip.h*clip.h/(#c.Options*30))
            d:Round(Util.rect(r.x+r.w-4,clip.y+(clip.h-hbar)*popup.scroll/max,2,hbar),1,t.muted,r,44)
        end
    end
end
return Views
