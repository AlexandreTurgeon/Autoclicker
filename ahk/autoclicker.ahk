#Requires AutoHotkey v2.0
#SingleInstance Force
CoordMode "Mouse", "Screen"

Points := []
Running := false
IntervalMs := 50
JitterMs := 0
NextIdx := 1

CaptureHotkey := "F6"
ToggleHotkey := "F8"
CurrentCaptureKey := ""
CurrentToggleKey := ""

WindowTitle := "Multi-Point Autoclicker"
InputLevel := 0
UseHook := true
StartWithWindows := false
StartMinimized := false

RunValueName := "Autoclicker"
RunKey := "HKCU\Software\Microsoft\Windows\CurrentVersion\Run"

ConfigFile := A_ScriptDir "\autoclicker.ini"
LoadingConfig := false

for arg in A_Args {
    if (arg = "--minimized")
        StartMinimized := true
}

MyGui := Gui("+Resize", WindowTitle)
MyGui.MarginX := 10
MyGui.MarginY := 10
MyGui.SetFont("s10")

StatusTxt := MyGui.Add("Text", "w280 h22 cBlue", "IDLE")

MyGui.Add("Text", "xm y+10", "Capture key:")
CaptureLbl := MyGui.Add("Text", "x+6 yp w60 +Border Center", CaptureHotkey)
MyGui.Add("Button", "x+6 yp-4 w70", "Rebind").OnEvent("Click", (*) => RebindKey("capture"))
MyGui.Add("Text", "x+20 yp+4", "Start/Stop:")
ToggleLbl := MyGui.Add("Text", "x+6 yp w60 +Border Center", ToggleHotkey)
MyGui.Add("Button", "x+6 yp-4 w70", "Rebind").OnEvent("Click", (*) => RebindKey("toggle"))

MyGui.Add("Text", "xm y+12", "Interval (ms):")
IntervalEdit := MyGui.Add("Edit", "x+6 yp-3 w70", "50")
IntervalEdit.OnEvent("Change", (*) => OnTimingChanged())
MyGui.Add("Text", "x+12 yp+3", "Jitter " Chr(0xB1) " (ms):")
JitterEdit := MyGui.Add("Edit", "x+6 yp-3 w70", "0")
JitterEdit.OnEvent("Change", (*) => OnTimingChanged())
MyGui.Add("Text", "x+12 yp+3", "Capture as:")
BtnDD := MyGui.Add("DropDownList", "x+6 yp-3 w80 Choose1", ["Left", "Right", "Middle"])

LV := MyGui.Add("ListView", "xm y+12 w500 h220", ["#", "X", "Y", "Button"])
LV.ModifyCol(1, 40, "Center")
LV.ModifyCol(2, 100, "Center")
LV.ModifyCol(3, 100, "Center")
LV.ModifyCol(4, 100, "Center")

MyGui.Add("Button", "xm y+10 w130", "Remove selected").OnEvent("Click", RemoveSelected)
MyGui.Add("Button", "x+6 w110", "Clear all").OnEvent("Click", ClearAll)
MyGui.Add("Button", "x+6 w160", "Cycle button on selected").OnEvent("Click", CycleBtn)
MyGui.Add("Button", "x+6 w70", "Exit").OnEvent("Click", (*) => ExitApp())

MyGui.Add("Text", "xm y+14", "Input level:")
InputLevelEdit := MyGui.Add("Edit", "x+6 yp-3 w50 Number", "0")
InputLevelEdit.OnEvent("Change", (*) => OnHotkeyOptionsChanged())
UseHookCb := MyGui.Add("Checkbox", "x+12 yp+3 Checked", "Use keyboard hook ($)")
UseHookCb.OnEvent("Click", (*) => OnHotkeyOptionsChanged())
StartupCb := MyGui.Add("Checkbox", "x+20 yp", "Start with Windows")
StartupCb.OnEvent("Click", (*) => OnStartupToggled())

MyGui.OnEvent("Close", (*) => MyGui.Hide())

A_TrayMenu.Delete()
A_TrayMenu.Add("Show", (*) => ShowGui())
A_TrayMenu.Add()
A_TrayMenu.Add("Start/Stop clicking", (*) => ToggleRunning())
A_TrayMenu.Add()
A_TrayMenu.Add("Start with Windows", (*) => OnStartupToggledFromTray())
A_TrayMenu.Add()
A_TrayMenu.Add("Exit", (*) => ExitApp())
A_TrayMenu.Default := "Show"
A_TrayMenu.ClickCount := 1

LoadConfig()
ApplyHotkeys()
UpdateStartupUI()
if !StartMinimized
    MyGui.Show("w520 h490")

CapturePoint() {
    global Points, LV
    MouseGetPos &x, &y
    btn := BtnDD.Text
    Points.Push({ x: x, y: y, btn: btn })
    LV.Add(, Points.Length, x, y, btn)
    SaveConfig()
}

ShowGui() {
    global MyGui
    MyGui.Show("w520 h490")
}

ToggleRunning() {
    global Running, Points, StatusTxt, NextIdx
    if (Running) {
        SetTimer ClickOnce, 0
        Running := false
        StatusTxt.Value := "IDLE"
        return
    }
    if (Points.Length = 0) {
        StatusTxt.Value := "IDLE " Chr(0x2014) " no points configured"
        return
    }
    if !ReadConfigFromGui() {
        return
    }
    Running := true
    NextIdx := 1
    StatusTxt.Value := "RUNNING"
    SetTimer ClickOnce, -1
}

ReadConfigFromGui() {
    global IntervalMs, JitterMs, StatusTxt
    intVal := Trim(IntervalEdit.Value)
    jitVal := Trim(JitterEdit.Value)
    if !IsInteger(intVal) || (intVal + 0) < 0 {
        StatusTxt.Value := "IDLE " Chr(0x2014) " interval must be a non-negative integer"
        return false
    }
    if !IsInteger(jitVal) || (jitVal + 0) < 0 {
        StatusTxt.Value := "IDLE " Chr(0x2014) " jitter must be a non-negative integer"
        return false
    }
    IntervalMs := intVal + 0
    JitterMs := jitVal + 0
    SaveConfig()
    return true
}

ClickOnce() {
    global Running, Points, NextIdx, IntervalMs, JitterMs
    if !Running
        return
    if (NextIdx < 1 || NextIdx > Points.Length)
        NextIdx := 1
    p := Points[NextIdx]
    try Click(p.x " " p.y " " p.btn)
    NextIdx := Mod(NextIdx, Points.Length) + 1
    delay := IntervalMs
    if (JitterMs > 0)
        delay += Random(-JitterMs, JitterMs)
    if (delay < 0)
        delay := 0
    SetTimer ClickOnce, -Max(delay, 1)
}

RemoveSelected(*) {
    global LV, Points
    row := LV.GetNext(0)
    if !row
        return
    Points.RemoveAt(row)
    RefreshList()
    SaveConfig()
}

ClearAll(*) {
    global Points
    Points := []
    RefreshList()
    SaveConfig()
}

CycleBtn(*) {
    global LV, Points
    row := LV.GetNext(0)
    if !row
        return
    order := ["Left", "Right", "Middle"]
    cur := Points[row].btn
    idx := 1
    for i, name in order {
        if (name = cur) {
            idx := i
            break
        }
    }
    Points[row].btn := order[Mod(idx, 3) + 1]
    RefreshList()
    SaveConfig()
}

RefreshList() {
    global LV, Points
    LV.Delete()
    for i, p in Points
        LV.Add(, i, p.x, p.y, p.btn)
}

OnTimingChanged() {
    global LoadingConfig
    if LoadingConfig
        return
    intVal := Trim(IntervalEdit.Value)
    jitVal := Trim(JitterEdit.Value)
    if !IsInteger(intVal) || (intVal + 0) < 0
        return
    if !IsInteger(jitVal) || (jitVal + 0) < 0
        return
    SaveConfig()
}

OnHotkeyOptionsChanged() {
    global InputLevel, UseHook, LoadingConfig, InputLevelEdit, UseHookCb, StatusTxt
    if LoadingConfig
        return
    val := Trim(InputLevelEdit.Value)
    if !IsInteger(val) || (val + 0) < 0 || (val + 0) > 100 {
        StatusTxt.Value := "IDLE " Chr(0x2014) " input level must be 0-100"
        return
    }
    InputLevel := val + 0
    UseHook := UseHookCb.Value ? true : false
    SaveConfig()
    ApplyHotkeys()
}

OnStartupToggled() {
    global StartWithWindows, StartupCb, LoadingConfig
    if LoadingConfig
        return
    StartWithWindows := StartupCb.Value ? true : false
    ApplyStartWithWindows()
    SaveConfig()
    UpdateTrayStartupCheck()
}

OnStartupToggledFromTray() {
    global StartWithWindows, StartupCb, LoadingConfig
    StartWithWindows := !StartWithWindows
    LoadingConfig := true
    StartupCb.Value := StartWithWindows ? 1 : 0
    LoadingConfig := false
    ApplyStartWithWindows()
    SaveConfig()
    UpdateTrayStartupCheck()
}

UpdateTrayStartupCheck() {
    global StartWithWindows
    if StartWithWindows
        A_TrayMenu.Check("Start with Windows")
    else
        A_TrayMenu.Uncheck("Start with Windows")
}

UpdateStartupUI() {
    global StartWithWindows, StartupCb, LoadingConfig
    LoadingConfig := true
    StartupCb.Value := StartWithWindows ? 1 : 0
    LoadingConfig := false
    UpdateTrayStartupCheck()
}

ApplyStartWithWindows() {
    global StartWithWindows, RunValueName, RunKey, StatusTxt
    if StartWithWindows {
        if A_IsCompiled
            cmd := '"' A_ScriptFullPath '" --minimized'
        else
            cmd := '"' A_AhkPath '" "' A_ScriptFullPath '" --minimized'
        try {
            RegWrite cmd, "REG_SZ", RunKey, RunValueName
        } catch as e {
            StatusTxt.Value := "IDLE " Chr(0x2014) " failed to write Run key: " e.Message
        }
    } else {
        try RegDelete RunKey, RunValueName
    }
}

BuildHotkeyName(key) {
    global UseHook
    if (UseHook && SubStr(key, 1, 1) != "$")
        return "$" key
    return key
}

ApplyHotkeys() {
    global CaptureHotkey, ToggleHotkey, CurrentCaptureKey, CurrentToggleKey, InputLevel, StatusTxt
    warn := ""

    if (CurrentCaptureKey != "") {
        try Hotkey CurrentCaptureKey, "Off"
        CurrentCaptureKey := ""
    }
    if (CurrentToggleKey != "") {
        try Hotkey CurrentToggleKey, "Off"
        CurrentToggleKey := ""
    }

    opts := "On I" InputLevel

    captureName := BuildHotkeyName(CaptureHotkey)
    try {
        Hotkey captureName, (*) => CapturePoint(), opts
        CurrentCaptureKey := captureName
    } catch {
        warn := "capture hotkey '" CaptureHotkey "' invalid, using F6"
        CaptureHotkey := "F6"
        captureName := BuildHotkeyName(CaptureHotkey)
        try {
            Hotkey captureName, (*) => CapturePoint(), opts
            CurrentCaptureKey := captureName
        }
    }

    toggleName := BuildHotkeyName(ToggleHotkey)
    try {
        Hotkey toggleName, (*) => ToggleRunning(), opts
        CurrentToggleKey := toggleName
    } catch {
        warn := (warn = "" ? "" : warn ", ") "toggle hotkey '" ToggleHotkey "' invalid, using F8"
        ToggleHotkey := "F8"
        toggleName := BuildHotkeyName(ToggleHotkey)
        try {
            Hotkey toggleName, (*) => ToggleRunning(), opts
            CurrentToggleKey := toggleName
        }
    }

    UpdateHotkeyLabels()
    if (warn != "")
        StatusTxt.Value := "IDLE " Chr(0x2014) " " warn
    return warn = ""
}

UpdateHotkeyLabels() {
    global CaptureLbl, ToggleLbl, CaptureHotkey, ToggleHotkey
    CaptureLbl.Value := CaptureHotkey
    ToggleLbl.Value := ToggleHotkey
}

RebindKey(which) {
    global CaptureHotkey, ToggleHotkey, StatusTxt
    StatusTxt.Value := "Press a key for " which " " Chr(0x2026) " (Esc to cancel)"
    ih := InputHook("L0 V")
    ih.KeyOpt("{All}", "E")
    ih.Start()
    ih.Wait()
    endKey := ih.EndKey
    if (endKey = "" || endKey = "Escape") {
        StatusTxt.Value := "IDLE"
        UpdateHotkeyLabels()
        return
    }
    other := (which = "capture") ? ToggleHotkey : CaptureHotkey
    if (endKey = other) {
        StatusTxt.Value := "IDLE " Chr(0x2014) " " endKey " already bound to other action"
        return
    }
    prev := (which = "capture") ? CaptureHotkey : ToggleHotkey
    if (which = "capture")
        CaptureHotkey := endKey
    else
        ToggleHotkey := endKey
    if !ApplyHotkeys() {
        if (which = "capture")
            CaptureHotkey := prev
        else
            ToggleHotkey := prev
        ApplyHotkeys()
        return
    }
    SaveConfig()
    StatusTxt.Value := "IDLE"
}

LoadConfig() {
    global ConfigFile, CaptureHotkey, ToggleHotkey, IntervalEdit, JitterEdit, Points, LoadingConfig
    global WindowTitle, MyGui, InputLevel, UseHook, StartWithWindows, InputLevelEdit, UseHookCb
    if !FileExist(ConfigFile)
        return
    LoadingConfig := true
    CaptureHotkey := IniRead(ConfigFile, "hotkeys", "capture", "F6")
    ToggleHotkey := IniRead(ConfigFile, "hotkeys", "toggle", "F8")
    intVal := IniRead(ConfigFile, "timing", "interval_ms", "50")
    jitVal := IniRead(ConfigFile, "timing", "jitter_ms", "0")
    if IsInteger(intVal) && (intVal + 0) >= 0
        IntervalEdit.Value := intVal
    if IsInteger(jitVal) && (jitVal + 0) >= 0
        JitterEdit.Value := jitVal

    title := IniRead(ConfigFile, "identity", "window_title", "Multi-Point Autoclicker")
    if (title != "") {
        WindowTitle := title
        MyGui.Title := title
    }

    lvlVal := IniRead(ConfigFile, "hotkeys", "input_level", "0")
    if IsInteger(lvlVal) && (lvlVal + 0) >= 0 && (lvlVal + 0) <= 100 {
        InputLevel := lvlVal + 0
        InputLevelEdit.Value := InputLevel
    }
    hookVal := IniRead(ConfigFile, "hotkeys", "use_hook", "1")
    UseHook := (hookVal = "1") ? true : false
    UseHookCb.Value := UseHook ? 1 : 0

    startVal := IniRead(ConfigFile, "startup", "enabled", "0")
    StartWithWindows := (startVal = "1") ? true : false

    count := IniRead(ConfigFile, "points", "count", "0")
    if !IsInteger(count) || (count + 0) <= 0 {
        LoadingConfig := false
        return
    }
    count := count + 0
    Loop count {
        raw := IniRead(ConfigFile, "points", A_Index, "")
        if (raw = "")
            continue
        parts := StrSplit(raw, ",")
        if (parts.Length < 3)
            continue
        x := Trim(parts[1])
        y := Trim(parts[2])
        btn := Trim(parts[3])
        if !IsInteger(x) || !IsInteger(y)
            continue
        if (btn != "Left" && btn != "Right" && btn != "Middle")
            btn := "Left"
        Points.Push({ x: x + 0, y: y + 0, btn: btn })
    }
    RefreshList()
    LoadingConfig := false
}

SaveConfig() {
    global ConfigFile, CaptureHotkey, ToggleHotkey, IntervalEdit, JitterEdit, Points, LoadingConfig
    global WindowTitle, InputLevel, UseHook, StartWithWindows
    if LoadingConfig
        return
    try {
        IniWrite CaptureHotkey, ConfigFile, "hotkeys", "capture"
        IniWrite ToggleHotkey, ConfigFile, "hotkeys", "toggle"
        IniWrite IntervalEdit.Value, ConfigFile, "timing", "interval_ms"
        IniWrite JitterEdit.Value, ConfigFile, "timing", "jitter_ms"
        IniWrite WindowTitle, ConfigFile, "identity", "window_title"
        IniWrite InputLevel, ConfigFile, "hotkeys", "input_level"
        IniWrite (UseHook ? "1" : "0"), ConfigFile, "hotkeys", "use_hook"
        IniWrite (StartWithWindows ? "1" : "0"), ConfigFile, "startup", "enabled"
        try IniDelete ConfigFile, "points"
        IniWrite Points.Length, ConfigFile, "points", "count"
        for i, p in Points
            IniWrite p.x "," p.y "," p.btn, ConfigFile, "points", i
    }
}
