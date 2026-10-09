-- Windows 10 (1903+) UWP light-theme tokens.
-- Values are the in-box themeresources.xaml Light dictionary entries, composited
-- over white where the source brush is translucent, plus measurements taken from
-- the stock Windows 10 Settings app at 100% scaling. No visible Roblox GUI objects.
local fonts=Drawing and Drawing.Fonts or {}
local segoe=fonts.SegoeUI or fonts['Segoe UI']
local body=segoe or fonts.Plex or 2
local Theme={
    -- Surfaces
    bg=Color3.fromRGB(255,255,255),            -- ApplicationPageBackgroundThemeBrush
    chrome=Color3.fromRGB(242,242,242),        -- SystemControlPageBackgroundChromeLowBrush
    card=Color3.fromRGB(242,242,242),          -- SystemControlTransientBackgroundBrush fallback
    surface=Color3.fromRGB(242,242,242),
    field=Color3.fromRGB(255,255,255),         -- TextControlBackground
    -- Controls
    button=Color3.fromRGB(204,204,204),        -- ButtonBackground #33000000
    buttonHover=Color3.fromRGB(204,204,204),   -- PointerOver background is unchanged in Windows 10
    buttonPressed=Color3.fromRGB(153,153,153), -- #66000000
    buttonBorder=Color3.fromRGB(153,153,153),  -- ButtonBorderBrushPointerOver #66000000
    hover=Color3.fromRGB(230,230,230),         -- SystemListLowColor #19000000
    pressed=Color3.fromRGB(204,204,204),       -- SystemListMediumColor #33000000
    selection=Color3.fromRGB(230,230,230),     -- selected list row
    -- Lines and borders
    line=Color3.fromRGB(219,219,219),          -- SystemControlTransientBorderBrush (1903) #00000014
    controlBorder=Color3.fromRGB(153,153,153), -- TextControlBorderBrush #66000000
    borderHover=Color3.fromRGB(102,102,102),   -- TextControlBorderBrushPointerOver #99000000
    -- Text
    text=Color3.fromRGB(0,0,0),                -- SystemControlForegroundBaseHighBrush
    muted=Color3.fromRGB(102,102,102),         -- BaseMedium #99000000
    placeholder=Color3.fromRGB(153,153,153),   -- BaseMediumLow #66000000
    -- Accent (#0078D7 is the Windows 10 default; #0078D4 is Windows 11)
    accent=Color3.fromRGB(0,120,215),
    accentHover=Color3.fromRGB(77,161,227),    -- accent at 0.7 over white #4DA1E3
    accentPressed=Color3.fromRGB(0,90,158),    -- accent Dark1 #005A9E
    accentLow=Color3.fromRGB(153,201,239),     -- SystemControlHighlightListAccentLowBrush
    -- States
    disabled=Color3.fromRGB(204,204,204),      -- SystemControlDisabledBaseLowBrush
    disabledText=Color3.fromRGB(153,153,153),  -- SystemControlDisabledBaseMediumLowBrush
    white=Color3.new(1,1,1),
    checkBorder=Color3.fromRGB(51,51,51),      -- CheckBoxCheckBackgroundStrokeUnchecked #CC000000
    checkBorderHover=Color3.fromRGB(0,0,0),
    switchStroke=Color3.fromRGB(51,51,51),     -- ToggleSwitchStrokeOff #CC000000
    switchStrokeHover=Color3.fromRGB(0,0,0),
    togglePressed=Color3.fromRGB(102,102,102), -- ToggleSwitchFillOnPressed #99000000
    thumbHover=Color3.fromRGB(23,23,23),       -- SliderThumbBackgroundPointerOver #171717
    thumbPressed=Color3.fromRGB(204,204,204),
    sliderTrack=Color3.fromRGB(153,153,153),   -- SliderTrackFill #66000000
    scrollbar=Color3.fromRGB(153,153,153),
    scrollbarHover=Color3.fromRGB(102,102,102),
    closeHover=Color3.fromRGB(232,17,35),
    closePressed=Color3.fromRGB(196,15,31),
    -- Navigation pane
    navigation=Color3.fromRGB(242,242,242),
    navigationHover=Color3.fromRGB(230,230,230),
    navigationSelected=Color3.fromRGB(230,230,230),
    navigationPressed=Color3.fromRGB(204,204,204),
    -- Typography (Windows 10 type ramp: Caption 12, Body 14, Subtitle 20, Title 28)
    font=body, fontScale=segoe and 1 or 1.12, headingFont=fonts.SegoeUISemibold or fonts['Segoe UI Semibold'] or body,
    bodySize=14, captionSize=12, headingSize=20, pageSize=28, titleHeight=32,
    -- Measured Settings metrics
    metrics={
        padding=24, contentTop=44, contentBottom=16, scrollbarGutter=12,
        sectionHeight=44, pageHeight=64, sectionGap=24, rowHeight=72, labelHeight=22,
        sliderHeight=56, toggleHeight=56, buttonHeight=40, separatorHeight=28,
        fieldHeight=32, fieldWidth=280, controlTop=24, sliderWidth=320,
        itemHeight=32, popupPadding=4,
        toggleWidth=44, toggleTrackHeight=20, toggleKnob=12, toggleInset=4, toggleLabelGap=14,
        sliderTrack=2, sliderThumbWidth=8, sliderThumbHeight=24, sliderHit=32, sliderValueHeight=24,
        checkbox=20, checkGlyph=12,
        navRow=48, navText=48, navTop=194, navIcon=16, navBarWidth=4, navBarHeight=24,
        homeTop=40, searchTop=97, searchInset=16, headerTop=151,
        scrollbarWidth=12, scrollbarThumb=2, scrollbarThumbHover=6, scrollbarMinThumb=32,
    },
    motion={hover=.10,control=.15,popup=.16,scrollbar=.20},
}
function Theme.Mix(a,b,t)
    return Color3.new(a.R+(b.R-a.R)*t,a.G+(b.G-a.G)*t,a.B+(b.B-a.B)*t)
end
return Theme
