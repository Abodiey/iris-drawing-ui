-- Windows 10-era light Fluent tokens. No visible Roblox GUI objects.
local fonts=Drawing and Drawing.Fonts or {}
local segoe=fonts.SegoeUI or fonts['Segoe UI']
local body=segoe or fonts.Plex or 2
local Theme={
    bg=Color3.fromRGB(255,255,255), card=Color3.fromRGB(255,255,255),
    surface=Color3.fromRGB(243,243,243), button=Color3.fromRGB(204,204,204), field=Color3.fromRGB(255,255,255),
    hover=Color3.fromRGB(229,229,229), pressed=Color3.fromRGB(204,204,204),
    line=Color3.fromRGB(209,209,209), controlBorder=Color3.fromRGB(153,153,153), borderHover=Color3.fromRGB(122,122,122),
    text=Color3.fromRGB(32,32,32), muted=Color3.fromRGB(102,102,102),
    accent=Color3.fromRGB(0,120,212), accentHover=Color3.fromRGB(0,103,184),
    selection=Color3.fromRGB(205,232,255), white=Color3.new(1,1,1),
    disabled=Color3.fromRGB(243,243,243), disabledText=Color3.fromRGB(160,160,160),
    switchBorder=Color3.fromRGB(51,51,51),
    placeholder=Color3.fromRGB(153,153,153),
    navigationTop=Color3.fromRGB(237,238,239), navigationBottom=Color3.fromRGB(224,224,225),
    navigationHover=Color3.fromRGB(204,204,205), navigationSelected=Color3.fromRGB(233,233,234),
    closeHover=Color3.fromRGB(232,17,35), closePressed=Color3.fromRGB(196,15,31),
    font=body, fontScale=segoe and 1 or 1.12, headingFont=fonts.SegoeUISemibold or fonts['Segoe UI Semibold'] or body,
    bodySize=14, captionSize=12, headingSize=20, pageSize=28, titleHeight=32,
    metrics={
        padding=24, contentTop=56, contentBottom=16, scrollbarGutter=12,
        sectionHeight=44, pageHeight=64, sectionGap=24, rowHeight=72, labelHeight=22,
        sliderHeight=56, toggleHeight=56, buttonHeight=40, separatorHeight=28, fieldHeight=32, fieldWidth=280, controlTop=24, sliderWidth=320,
        itemHeight=32, popupPadding=4,
    },
    motion={hover=.10,control=.15,popup=.16},
}
function Theme.Mix(a,b,t)
    return Color3.new(a.R+(b.R-a.R)*t,a.G+(b.G-a.G)*t,a.B+(b.B-a.B)*t)
end
return Theme
