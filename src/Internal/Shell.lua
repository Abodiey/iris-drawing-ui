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
local function pageIcon(d,x,y,color,clip,z)
    d:Border(Util.rect(x+2,y,12,15),color,clip,z)
    d:Line(x+5,y+4,x+11,y+4,color,clip,z)
    d:Line(x+5,y+7,x+11,y+7,color,clip,z)
    d:Line(x+5,y+10,x+11,y+10,color,clip,z)
end
local function magnifier(d,x,y,width,color,clip,z)
    d:Round(Util.rect(x,y,width,width),width/2,color,clip,z)
    d:Round(Util.rect(x+1,y+1,width-2,width-2),(width-2)/2,Theme.field,clip,z+1)
    d:Line(x+width-2,y+width-1,x+width+2,y+width+4,color,clip,z+2)
end
-- The Settings navigation pane material spans the whole window height, including
-- the caption area, so the title bar text sits over the acrylic surface.
function Shell.Pane(rt,r,width)
    if width==0 or r.h<=0 then return end
    rt.renderer:Rect(Util.rect(r.x,r.y,width,r.h),Theme.navigation,nil,3)
end
function Shell.Sidebar(rt,r,width)
    local d,t,w=rt.renderer,Theme,rt.window
    local m=t.metrics
    rt.navigationClip=nil
    if width==0 or r.h<=t.titleHeight then return end
    local pane=Util.rect(r.x,r.y,width,r.h)
    local homeRow=Util.rect(r.x,r.y+m.homeTop,width,m.navRow)
    local homeHover=rt:Visual(w,'home')
    local homePressed=rt.pressedHit and rt.pressedHit.owner==w and rt.pressedHit.role=='home'
    if homePressed then d:Rect(homeRow,t.navigationPressed,pane,4)
    elseif homeHover>0 then d:Rect(homeRow,Theme.Mix(t.navigation,t.navigationHover,homeHover),pane,4) end
    home(d,r.x+16,homeRow.y+16,t.text,pane,5)
    d:Text('Home',r.x+m.navText,homeRow.y+(m.navRow-19)/2,t.text,width-64,pane,5,t.bodySize)
    rt:Hit(homeRow,w,'home',pane)
    local field=Util.rect(r.x+m.searchInset,r.y+m.searchTop,width-m.searchInset*2,m.fieldHeight)
    local search=rt.search
    search._anchor=field
    local focused=rt.edit==search
    d:Rect(field,t.field,pane,4)
    d:Border(field,focused and t.accent or t.controlBorder,pane,5,2)
    if focused then rt:DrawEditing(search,field,pane)
    else d:Text(search.Value=='' and 'Find a setting' or search.Value,field.x+12,field.y+8,search.Value=='' and t.placeholder or t.text,field.w-46,pane,5,t.bodySize) end
    magnifier(d,field.x+field.w-25,field.y+11,10,t.muted,pane,6)
    rt:Hit(field,search,'textbox',pane,field)
    d:Text(w.Name,r.x+m.searchInset,r.y+m.headerTop,t.text,width-m.searchInset*2,pane,5,t.bodySize,t.headingFont)
    local top=r.y+m.navTop
    local clip=Util.intersect(Util.rect(r.x,top,width,math.max(0,r.h-(top-r.y)-12)),pane)
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
    rt.navigationMaxScroll=math.max(0,#entries*m.navRow-clip.h)
    rt.navigationScroll=Util.clamp(rt.navigationScroll or 0,0,rt.navigationMaxScroll)
    local active=w.Sections[1]
    for _,section in ipairs(w.Sections) do
        if (rt.sectionOffsets[section] or 0)<=w.Scroll+1 then active=section end
    end
    local pressed=rt.pressedHit
    for i,entry in ipairs(entries) do
        local section=entry.section
        local row=Util.rect(r.x,clip.y+(i-1)*m.navRow-rt.navigationScroll,width,m.navRow)
        if Util.intersect(row,clip) then
            if pressed and pressed.owner==section and pressed.role=='sectionNavigation' then
                d:Rect(row,t.navigationPressed,clip,4)
            else
                local amount=rt:Visual(section,'sectionNavigation')
                local base=section==active and t.navigationSelected or t.navigation
                if section==active or amount>0 then d:Rect(row,Theme.Mix(base,t.navigationHover,amount),clip,4) end
            end
            if section==active then d:Rect(Util.rect(row.x,row.y+(m.navRow-m.navBarHeight)/2,m.navBarWidth,m.navBarHeight),t.accent,clip,5) end
            pageIcon(d,row.x+16,row.y+(m.navRow-16)/2,t.text,clip,5)
            d:Text(section.Name,row.x+m.navText,row.y+(m.navRow-19)/2,t.text,width-64,clip,5,t.bodySize)
            rt:Hit(row,section,'sectionNavigation',clip,entry.target)
        end
    end
    if #entries==0 then d:Text('No settings found',clip.x+16,clip.y+16,t.muted,width-32,clip,5,t.bodySize) end
end
return Shell
