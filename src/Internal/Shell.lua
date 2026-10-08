local Util=require('Internal.Util')
local Theme=require('Internal.Theme')
local Shell={}
function Shell.Width(width)
    if width>=900 then return 320 end
    if width>=720 then return 256 end
    if width>=600 then return 200 end
    return 0
end
local function home(d,x,y,color,clip,z)
    d:Line(x,y+6,x+6,y,color,clip,z)
    d:Line(x+6,y,x+12,y+6,color,clip,z)
    d:Line(x+2,y+5,x+2,y+12,color,clip,z)
    d:Line(x+10,y+5,x+10,y+12,color,clip,z)
    d:Line(x+2,y+12,x+10,y+12,color,clip,z)
    d:Border(Util.rect(x+5,y+7,3,5),color,clip,z)
end
local function sectionIcon(d,x,y,color,clip,z)
    d:Border(Util.rect(x,y,14,10),color,clip,z)
    d:Line(x+7,y+10,x+7,y+14,color,clip,z)
    d:Line(x+3,y+14,x+11,y+14,color,clip,z)
end
function Shell.Sidebar(rt,r,width)
    local d,t,w=rt.renderer,Theme,rt.window
    rt.navigationClip=nil
    if width==0 or r.h<=32 then return end
    local pane=Util.rect(r.x,r.y,width,r.h)
    -- Opaque neutral material; Drawing has no desktop backdrop-blur primitive.
    for i=0,31 do
        local color=Theme.Mix(t.navigationTop,t.navigationBottom,i/31)
        d:Rect(Util.rect(pane.x,pane.y+pane.h*i/32,pane.w,pane.h/32+1),color,pane,3)
    end
    local homeRow=Util.rect(r.x,r.y+48,width,48)
    local homeHover=rt:Visual(w,'home')
    if homeHover>0 then d:Rect(homeRow,Theme.Mix(t.navigationTop,t.navigationHover,homeHover),pane,4) end
    home(d,r.x+18,r.y+67,t.text,pane,5)
    d:Text('Home',r.x+48,r.y+64,t.text,width-64,pane,5)
    rt:Hit(homeRow,w,'home',pane)
    local field=Util.rect(r.x+16,r.y+104,width-32,32)
    local search=rt.search
    search._anchor=field
    d:Rect(field,t.white,pane,4)
    d:Border(field,t.accent,pane,5,2)
    if rt.edit==search then rt:DrawEditing(search,field,pane)
    else d:Text(search.Value=='' and 'Find a setting' or search.Value,field.x+12,field.y+8,search.Value=='' and t.placeholder or t.text,field.w-40,pane,5) end
    d:Round(Util.rect(field.x+field.w-20,field.y+9,8,8),4,t.muted,pane,6)
    d:Round(Util.rect(field.x+field.w-19,field.y+10,6,6),3,t.white,pane,7)
    d:Line(field.x+field.w-20,field.y+17,field.x+field.w-24,field.y+21,t.muted,pane,7)
    rt:Hit(field,search,'textbox',pane,field)
    d:Text(w.Name,r.x+16,r.y+160,t.text,width-32,pane,5,14,t.headingFont)
    local clip=Util.intersect(Util.rect(r.x,r.y+200,width,math.max(0,r.h-212)),pane)
    if not clip then return end
    rt.navigationClip=clip
    local query=(rt.edit==search and rt.box.Text or search.Value):lower()
    local entries={}
    for _,section in ipairs(w.Sections) do
        local target=rt.sectionOffsets[section]
        local match=query=='' or section.Name:lower():find(query,1,true)
        if not match then
            for _,control in ipairs(section.Controls) do
                if control.Name:lower():find(query,1,true) then
                    match=true
                    target=rt.controlOffsets[control]
                    break
                end
            end
        end
        if match then entries[#entries+1]={section=section,target=target} end
    end
    rt.navigationMaxScroll=math.max(0,#entries*48-clip.h)
    rt.navigationScroll=Util.clamp(rt.navigationScroll or 0,0,rt.navigationMaxScroll)
    local active=w.Sections[1]
    for _,section in ipairs(w.Sections) do
        if (rt.sectionOffsets[section] or 0)<=w.Scroll+1 then active=section end
    end
    for i,entry in ipairs(entries) do
        local section=entry.section
        local row=Util.rect(r.x,clip.y+(i-1)*48-rt.navigationScroll,width,48)
        if Util.intersect(row,clip) then
            local base=section==active and t.navigationSelected or t.navigationBottom
            local amount=rt:Visual(section,'sectionNavigation')
            if section==active or amount>0 then d:Rect(row,Theme.Mix(base,t.navigationHover,amount),clip,4) end
            if section==active then d:Rect(Util.rect(row.x,row.y+12,4,24),t.accent,clip,5) end
            sectionIcon(d,row.x+16,row.y+16,t.text,clip,5)
            d:Text(section.Name,row.x+48,row.y+16,t.text,width-64,clip,5)
            rt:Hit(row,section,'sectionNavigation',clip,entry.target)
        end
    end
    if #entries==0 then d:Text('No settings found',clip.x+16,clip.y+16,t.muted,width-32,clip,5) end
end
return Shell
