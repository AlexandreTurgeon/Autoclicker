#Requires AutoHotkey v2.0
#SingleInstance Force
CoordMode "Mouse", "Screen"

Points := []
Running := false
IntervalMs := 50
JitterMs := 0
NextIdx := 1

MyGui := Gui("+Resize", "Multi-Point Autoclicker")
MyGui.MarginX := 10
MyGui.MarginY := 10
MyGui.SetFont("s10")

StatusTxt := MyGui.Add("Text", "w200 h22 cBlue", "IDLE")
MyGui.Add("Text", "x+10 yp+3", "F6 = capture point   F8 = start/stop")

MyGui.Add("Text", "xm y+12", "Interval (ms):")
IntervalEdit := MyGui.Add("Edit", "x+6 yp-3 w70", "50")
MyGui.Add("Text", "x+12 yp+3", "Jitter " Chr(0xB1) " (ms):")
JitterEdit := MyGui.Add("Edit", "x+6 yp-3 w70", "0")
MyGui.Add("Text", "x+12 yp+3", "Capture as:")
BtnDD := MyGui.Add("DropDownList", "x+6 yp-3 w80 Choose1", ["Left", "Right", "Middle"])

LV := MyGui.Add("ListView", "xm y+12 w500 h240", ["#", "X", "Y", "Button"])
LV.ModifyCol(1, 40, "Center")
LV.ModifyCol(2, 100, "Center")
LV.ModifyCol(3, 100, "Center")
LV.ModifyCol(4, 100, "Center")

MyGui.Add("Button", "xm y+10 w130", "Remove selected").OnEvent("Click", RemoveSelected)
MyGui.Add("Button", "x+6 w110", "Clear all").OnEvent("Click", ClearAll)
MyGui.Add("Button", "x+6 w160", "Cycle button on selected").OnEvent("Click", CycleBtn)

MyGui.OnEvent("Close", (*) => ExitApp())
MyGui.Show("w520 h420")

F6::CapturePoint()
F8::ToggleRunning()

CapturePoint() {
    global Points, LV
    MouseGetPos &x, &y
    btn := BtnDD.Text
    Points.Push({ x: x, y: y, btn: btn })
    LV.Add(, Points.Length, x, y, btn)
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
}

ClearAll(*) {
    global Points
    Points := []
    RefreshList()
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
}

RefreshList() {
    global LV, Points
    LV.Delete()
    for i, p in Points
        LV.Add(, i, p.x, p.y, p.btn)
}
