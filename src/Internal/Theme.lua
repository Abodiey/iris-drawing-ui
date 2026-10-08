-- Windows 10-era light Fluent tokens. No visible Roblox GUI objects.
local fonts=Drawing and Drawing.Fonts or {}
local body=fonts.SegoeUI or fonts['Segoe UI'] or fonts.Plex or 2
local Theme={
    bg=Color3.fromRGB(255,255,255), card=Color3.fromRGB(255,255,255),
    surface=Color3.fromRGB(243,243,243), button=Color3.fromRGB(225,225,225), field=Color3.fromRGB(255,255,255),
    hover=Color3.fromRGB(229,229,229), pressed=Color3.fromRGB(204,204,204),
    line=Color3.fromRGB(209,209,209), controlBorder=Color3.fromRGB(166,166,166), borderHover=Color3.fromRGB(122,122,122),
    text=Color3.fromRGB(32,32,32), muted=Color3.fromRGB(102,102,102),
    accent=Color3.fromRGB(0,120,212), accentHover=Color3.fromRGB(0,103,184),
    selection=Color3.fromRGB(205,232,255), white=Color3.new(1,1,1),
    disabled=Color3.fromRGB(243,243,243), disabledText=Color3.fromRGB(160,160,160),
    closeHover=Color3.fromRGB(232,17,35), closePressed=Color3.fromRGB(196,15,31),
    font=body, headingFont=fonts.SegoeUISemibold or fonts['Segoe UI Semibold'] or body,
    bodySize=14, captionSize=12, headingSize=20, titleHeight=32,
    metrics={
        padding=24, contentTop=48, contentBottom=16, scrollbarGutter=12,
        sectionHeight=36, sectionGap=16, rowHeight=64, labelHeight=22,
        sliderHeight=56, toggleHeight=56, buttonHeight=40, separatorHeight=28, fieldHeight=32, fieldWidth=240, controlTop=24, sliderWidth=320,
        itemHeight=32, popupPadding=4,
    },
    motion={hover=.10,control=.15,popup=.16},
}
function Theme.Mix(a,b,t)
    return Color3.new(a.R+(b.R-a.R)*t,a.G+(b.G-a.G)*t,a.B+(b.B-a.B)*t)
end
return Theme
