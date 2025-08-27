PleaseWaitNotification(){
    {
        ToolTip("Please Wait....")
    }
}

;................................................................................
;                                 ...............                               ;
;                                  C L A S S E S                                ;
;................................................................................

; Monitor Configuration Class
; https://git.io/MonitorConfigurationClass
; This is a stripped down version, including only what's needed for app

class Monitor 
{ 
    ; ===== PUBLIC METHODS ===== ;
    
    GetInfo() => this.EnumDisplayMonitors()
    
    GetBrightness(Display := "") => this.GetSetting("GetMonitorBrightness", Display)
    
    GetContrast(Display := "") => this.GetSetting("GetMonitorContrast", Display)
    
    GetGammaRamp(Display := "") => this.GammaSetting("GetDeviceGammaRamp", , , , Display)
    
    GetPowerMode(Display := "")
    {
        static PowerModes := Map(
            0x01, "On",
            0x02, "Standby",
            0x03, "Suspend",
            0x04, "Off",
            0x05, "PowerOff")
        
        return PowerModes[this.GetSetting("GetVCPFeatureAndVCPFeatureReply", Display, 0xD6)["Current"]]
    }
    
    SetBrightness(Brightness, Display := "") => this.SetSetting("SetMonitorBrightness", Brightness, Display)
    
    SetContrast(Contrast, Display := "") => this.SetSetting("SetMonitorContrast", Contrast, Display)
    
    SetGammaRamp(Red := 100, Green := 100, Blue := 100, Display := "") => this.GammaSetting("SetDeviceGammaRamp", Red, Green, Blue, Display)

    SetPowerMode(PowerMode, Display := "")
    {
        static PowerModes := Map(
            "On", 0x01,
            "Standby", 0x02,
            "Suspend", 0x03,
            "Off", 0x04,
            "PowerOff", 0x05)
        
        if (PowerModes.Has(PowerMode))
            if (this.SetSetting("SetMonitorVCPFeature", 0xD6, Display, PowerModes[PowerMode]))
                return PowerMode
        throw Error("An invalid [PowerMode] parameter was passed to the SetPowerMode() Method.")
    }

    RestoreFactoryDefaults(Display := "") => this.VoidSetting("RestoreMonitorFactoryDefaults", Display)
    
    ; ===== PRIVATE METHODS ===== ;
    
    EnumDisplayMonitors(hMonitor := "")
    {
        static EnumProc := CallbackCreate(Monitor.GetMethod("MonitorEnumProc").Bind(Monitor),, 4)
        static DisplayMonitors := []
        
        if (!DisplayMonitors.Length)
            if !(DllCall("user32\EnumDisplayMonitors", "ptr", 0, "ptr", 0, "ptr", EnumProc, "ptr", ObjPtrAddRef(DisplayMonitors), "uint"))
                return false
        return DisplayMonitors    
    }
    
    static MonitorEnumProc(hMonitor, hDC, pRECT, ObjectAddr)
    {
        DisplayMonitors := ObjFromPtrAddRef(ObjectAddr)
        MonitorData := Monitor.GetMonitorInfo(hMonitor)
        DisplayMonitors.Push(MonitorData)
        return true
    }

	gammaAllTitle := Map()
	gammaAllSliderStart := Map()
	gammaAllSliderEnd := Map()

    static GetMonitorInfo(hMonitor)
    {
        NumPut("uint", 104, MONITORINFOEX := Buffer(104))
        if (DllCall("user32\GetMonitorInfo", "ptr", hMonitor, "ptr", MONITORINFOEX))
        {
            MONITORINFO := Map()
            MONITORINFO["Handle"]   := hMonitor
            MONITORINFO["Name"]     := Name := StrGet(MONITORINFOEX.Ptr + 40, 32)
            MONITORINFO["Number"]   := RegExReplace(Name, ".*(\d+)$", "$1")
            MONITORINFO["Left"]     := NumGet(MONITORINFOEX,  4, "int")
            MONITORINFO["Top"]      := NumGet(MONITORINFOEX,  8, "int")
            MONITORINFO["Right"]    := NumGet(MONITORINFOEX, 12, "int")
            MONITORINFO["Bottom"]   := NumGet(MONITORINFOEX, 16, "int")
            MONITORINFO["WALeft"]   := NumGet(MONITORINFOEX, 20, "int")
            MONITORINFO["WATop"]    := NumGet(MONITORINFOEX, 24, "int")
            MONITORINFO["WARight"]  := NumGet(MONITORINFOEX, 28, "int")
            MONITORINFO["WABottom"] := NumGet(MONITORINFOEX, 32, "int")
            MONITORINFO["Primary"]  := NumGet(MONITORINFOEX, 36, "uint")
            return MONITORINFO
        }
        throw Error("GetMonitorInfo: " A_LastError, -1)
    }
    
    GetMonitorHandle(Display := "", hMonitor := 0)
    {
        MonitorInfo := this.EnumDisplayMonitors()
        if ((Display != ""))
        {
            for Info in MonitorInfo 
            {
                if (InStr(Info["Name"], Display))
                {
                    hMonitor := Info["Handle"]
                    break
                }
            }
        }

        if (!hMonitor) ; MONITOR_DEFAULTTONEAREST = 0x00000002
            hMonitor := DllCall("user32\MonitorFromWindow", "ptr", hWindow := 0, "uint", 0x00000002)
        return hMonitor
    }
    
    GetNumberOfPhysicalMonitorsFromHMONITOR(hMonitor)
    {
        if (DllCall("dxva2\GetNumberOfPhysicalMonitorsFromHMONITOR", "ptr", hMonitor, "uint*", &NumberOfPhysicalMonitors := 0))
            return NumberOfPhysicalMonitors
        return false
    }
    
    GetPhysicalMonitorsFromHMONITOR(hMonitor, PhysicalMonitorArraySize, &PHYSICAL_MONITOR)
    {
        PHYSICAL_MONITOR := Buffer((A_PtrSize + 256) * PhysicalMonitorArraySize)
        if (DllCall("dxva2\GetPhysicalMonitorsFromHMONITOR", "ptr", hMonitor, "uint", PhysicalMonitorArraySize, "ptr", PHYSICAL_MONITOR))
            return NumGet(PHYSICAL_MONITOR, 0, "ptr")
        return false
    }
    
    DestroyPhysicalMonitors(PhysicalMonitorArraySize, PHYSICAL_MONITOR)
    {
        if (DllCall("dxva2\DestroyPhysicalMonitors", "uint", PhysicalMonitorArraySize, "ptr", PHYSICAL_MONITOR))
            return true
        return false
    }
    
    CreateDC(DisplayName)
    {
        if (hDC := DllCall("gdi32\CreateDC", "str", DisplayName, "ptr", 0, "ptr", 0, "ptr", 0, "ptr"))
            return hDC
        return false
    }
    
    DeleteDC(hDC)
    {
        if (DllCall("gdi32\DeleteDC", "ptr", hDC))
            return true
        return false
    }
    
    ; ===== HELPER METHODS ===== ;
    
    GetSetting(GetMethodName, Display := "", params*)
    {
        if (hMonitor := this.GetMonitorHandle(Display))
        {
            PHYSICAL_MONITOR := ""
            PhysicalMonitors := this.GetNumberOfPhysicalMonitorsFromHMONITOR(hMonitor)
            hPhysicalMonitor := this.GetPhysicalMonitorsFromHMONITOR(hMonitor, PhysicalMonitors, &PHYSICAL_MONITOR)
            Setting := this.%GetMethodName%(hPhysicalMonitor, params*)
            this.DestroyPhysicalMonitors(PhysicalMonitors, PHYSICAL_MONITOR)
            return Setting
        }
        throw Error("Unable to get handle to monitor.`n`nError code: " Format("0x{:X}", A_LastError))
    }
    
    SetSetting(SetMethodName, Setting, Display := "", params*)
    {
        if (hMonitor := this.GetMonitorHandle(Display))
        {
            PHYSICAL_MONITOR := ""
            PhysicalMonitors := this.GetNumberOfPhysicalMonitorsFromHMONITOR(hMonitor)
            hPhysicalMonitor := this.GetPhysicalMonitorsFromHMONITOR(hMonitor, PhysicalMonitors, &PHYSICAL_MONITOR)

            if (SetMethodName = "SetMonitorVCPFeature" || SetMethodName = "SetMonitorColorTemperature")
            {
                Setting := this.%SetMethodName%(hPhysicalMonitor, Setting, params*)
                this.DestroyPhysicalMonitors(PhysicalMonitors, PHYSICAL_MONITOR)
                return Setting
            }
            else 
            {
                GetMethodName := RegExReplace(SetMethodName, "S(.*)", "G$1")
                GetSetting := this.%GetMethodName%(hPhysicalMonitor)
                Setting := (Setting < GetSetting["Minimum"]) ? GetSetting["Minimum"]
                        :  (Setting > GetSetting["Maximum"]) ? GetSetting["Maximum"]
                        :  (Setting)
                this.%SetMethodName%(hPhysicalMonitor, Setting)
                this.DestroyPhysicalMonitors(PhysicalMonitors, PHYSICAL_MONITOR)
                return Setting
            }
        } 
        throw Error("Unable to get handle to monitor.`n`nError code: " Format("0x{:X}", A_LastError))
    }

    GammaSetting(GammaMethodName, Red := "", Green := "", Blue := "", Display := "", DisplayName := "")
    {
        MonitorInfo := this.EnumDisplayMonitors()
        if (Display = "")
        {
            for Info in MonitorInfo 
            {
                if (Info["Primary"])
                {
                    PrimaryMonitor := A_Index
                    break
                }
            }
        }

        if (DisplayName := MonitorInfo[Display ? Display : PrimaryMonitor]["Name"])
        {
            if (hDC := this.CreateDC(DisplayName))
            {
                if (GammaMethodName = "SetDeviceGammaRamp")
                {
                    for Color in ["Red", "Green", "Blue"]
                    {
                        %Color% := (%Color% <    0) ?    0 
                                :  (%Color% >  100) ?  100
                                :  (%Color%)
                        %Color% := Round((2.56 * %Color%) - 128, 1) ; convert to decimal
                    }
                    this.SetDeviceGammaRamp(hDC, Red, Green, Blue)
                    this.DeleteDC(hDC)
                    
                    for Color in ["Red", "Green", "Blue"]
                        %Color% := Round((%Color% + 128) / 2.56, 1) ; convert back to percentage

                    return Map("Red", Red, "Green", Green, "Blue", Blue)
                }
                else ; if (GammaMethodName = "GetDeviceGammaRamp")
                {
                    GammaRamp := this.GetDeviceGammaRamp(hDC)
                    for Color, GammaLevel in GammaRamp
                        GammaRamp[Color] := Round((GammaLevel + 128) / 2.56, 1) ; convert to percentage
                    this.DeleteDC(hDC)
                    return GammaRamp
                }
            }
            this.DeleteDC(hDC)
            throw Error("Unable to get handle to Device Context.`n`nError code: " Format("0x{:X}", A_LastError))
        }
    }
    
    VoidSetting(VoidMethodName, Display := "")
    {
        if (hMonitor := this.GetMonitorHandle(Display))
        {
            PHYSICAL_MONITOR := ""
            PhysicalMonitors := this.GetNumberOfPhysicalMonitorsFromHMONITOR(hMonitor)
            hPhysicalMonitor := this.GetPhysicalMonitorsFromHMONITOR(hMonitor, PhysicalMonitors, &PHYSICAL_MONITOR)
            bool := this.%VoidMethodName%(hPhysicalMonitor)
            this.DestroyPhysicalMonitors(PhysicalMonitors, PHYSICAL_MONITOR)
            return bool
        }
        throw Error("Unable to get handle to monitor.`n`nError code: " Format("0x{:X}", A_LastError))
    }

    ; ===== GET METHODS ===== ;
    
    GetMonitorBrightness(hMonitor, Minimum := 0, Current := 0, Maximum := 0)
    {
        if (DllCall("dxva2\GetMonitorBrightness", "ptr", hMonitor, "uint*", &Minimum, "uint*", &Current, "uint*", &Maximum))
            return Map("Minimum", Minimum, "Current", Current, "Maximum", Maximum)
        throw Error("Unable to retreive values.`n`nError code: " Format("0x{:X}", A_LastError))
    }
    
    GetMonitorContrast(hMonitor, Minimum := 0, Current := 0, Maximum := 0)
    {
        if (DllCall("dxva2\GetMonitorContrast", "ptr", hMonitor, "uint*", &Minimum, "uint*", &Current, "uint*", &Maximum))
            return Map("Minimum", Minimum, "Current", Current, "Maximum", Maximum)
        throw Error("Unable to retreive values.`n`nError code: " Format("0x{:X}", A_LastError))
    }
    
    GetDeviceGammaRamp(hMonitor)
    {
        if (DllCall("gdi32\GetDeviceGammaRamp", "ptr", hMonitor, "ptr", GAMMA_RAMP := Buffer(1536)))
            return Map(
                "Red"  , NumGet(GAMMA_RAMP,        2, "ushort") - 128,
                "Green", NumGet(GAMMA_RAMP,  512 + 2, "ushort") - 128,
                "Blue" , NumGet(GAMMA_RAMP, 1024 + 2, "ushort") - 128)
        throw Error("Unable to retreive values.`n`nError code: " Format("0x{:X}", A_LastError))
    }

    GetVCPFeatureAndVCPFeatureReply(hMonitor, VCPCode, vct := 0, CurrentValue := 0, MaximumValue := 0)
    {
        static VCP_CODE_TYPE := Map(
            0x00000000, "MC_MOMENTARY — Momentary VCP code. Sending a command of this type causes the monitor to initiate a self-timed operation and then revert to its original state. Examples include display tests and degaussing.",
            0x00000001, "MC_SET_PARAMETER — Set Parameter VCP code. Sending a command of this type changes some aspect of the monitor's operation.")
        
        if (DllCall("dxva2\GetVCPFeatureAndVCPFeatureReply", "ptr", hMonitor, "ptr", VCPCode, "uint*", &vct, "uint*", &CurrentValue, "uint*", &MaximumValue))
            return Map("VCPCode", Format("0x{:X}", VCPCode),
                       "VCPCodeType", VCP_CODE_TYPE[vct], 
                       "Current", CurrentValue, 
                       "Maximum", (MaximumValue ? MaximumValue : "Undefined due to non-continuous (NC) VCP Code."))
        throw Error("Unable to retreive values.`n`nError code: " Format("0x{:X}", A_LastError))
    }
    
    ; ===== SET METHODS ===== ;
    
    SetMonitorBrightness(hMonitor, Brightness)
    {
        if (DllCall("dxva2\SetMonitorBrightness", "ptr", hMonitor, "uint", Brightness))
            return Brightness
        throw Error("Unable to set value.`n`nError code: " Format("0x{:X}", A_LastError))
    }
    
    SetMonitorContrast(hMonitor, Contrast)
    {
        if (DllCall("dxva2\SetMonitorContrast", "ptr", hMonitor, "uint", Contrast))
            return Contrast
        throw Error("Unable to set value.`n`nError code: " Format("0x{:X}", A_LastError))
    }
    
    SetDeviceGammaRamp(hMonitor, red, green, blue)
    {
        GAMMA_RAMP := Buffer(1536)
        i := 0
        while ((i := A_Index - 1) < 256 )
        {
            NumPut("ushort", (r := (red   + 128) * i) > 65535 ? 65535 : r, GAMMA_RAMP,        2 * i)
            NumPut("ushort", (g := (green + 128) * i) > 65535 ? 65535 : g, GAMMA_RAMP,  512 + 2 * i)
            NumPut("ushort", (b := (blue  + 128) * i) > 65535 ? 65535 : b, GAMMA_RAMP, 1024 + 2 * i)
        }
        if (DllCall("gdi32\SetDeviceGammaRamp", "ptr", hMonitor, "ptr", GAMMA_RAMP))
            return true
        throw Error("Unable to set values.`n`nError code: " Format("0x{:X}", A_LastError))
    }
    
    SetMonitorVCPFeature(hMonitor, VCPCode, NewValue)
    {
        if (DllCall("dxva2\SetVCPFeature", "ptr", hMonitor, "ptr", VCPCode, "uint", NewValue))
            return Map("VCPCode", Format("0x{:X}", VCPCode), "NewValue", NewValue)
        throw Error("Unable to set value.`n`nError code: " Format("0x{:X}", A_LastError))
    }

    ; ===== VOID METHODS ===== ;
    
    RestoreMonitorFactoryDefaults(hMonitor)
    {
        if (DllCall("dxva2\RestoreMonitorFactoryDefaults", "ptr", hMonitor))
            return true
        throw Error("Unable to restore monitor to factory defaults.`n`nError code: " Format("0x{:X}", A_LastError))
    }
}
;...............................................................................;
;                                                                               ;
; app ...........: the Screen Dimmer                                           ;
; version .......: 0.5.1 (Updated for AHK v2.0)                               ;
;                                                                               ;
;...............................................................................;
;                                                                               ;
; author ........: 348bestbox (updated for v2.0 compatibility)                 ;
; language ......: AutoHotkey V2.0                                            ;
;                                                                               ;
;...............................................................................;

;................................................................................
;          ...........................................................          ;
;           A U T O - E X E C U T E   &   I N I T I A L I Z A T I O N           ;
;................................................................................

#SingleInstance
global mon := Monitor()

;................................................................................
;                     ..................................                        ;
;                      T R A Y  M E N U   &   I C O N S                         ;
;................................................................................


; Set Icon ToolTip and App Name
A_IconTip := "the Screen Dimmer"

; Create tray menu with only a "Close App" option
A_TrayMenu.Delete()
A_TrayMenu.Add(A_IconTip, (*) => monitorMenu.Show()) 
A_TrayMenu.Add() 
A_TrayMenu.Add("Close", (*) => ExitApp()) 

; Allows a single left-click on taskbar icon to open monitor menu
OnMessage(0x404, (wParam, lParam, *) => lParam = 0x201 ? monitorMenu.Show() : "") 

; Try to download and set tray/menu icons without keeping images saved locally
try Download("https://i.imgur.com/VoXGvak.png", A_ScriptDir "\tray-icon.png")
try Download("https://i.imgur.com/Ea1kZrE.png", A_ScriptDir "\close-app.png")
try TraySetIcon(A_ScriptDir "\tray-icon.png")
try A_TrayMenu.SetIcon(A_IconTip , A_ScriptDir "\tray-icon.png")
try A_TrayMenu.SetIcon("Close" , A_ScriptDir "\close-app.png")
try (FileExist(A_ScriptDir "\tray-icon.png")) ? FileDelete(A_ScriptDir "\tray-icon.png") : ""
try (FileExist(A_ScriptDir "\close-app.png")) ? FileDelete(A_ScriptDir "\close-app.png") : ""

;................................................................................
;                                    .......                                    ;
;                                     G U I                                     ;
;................................................................................

; Create monitor config menu
monitorMenu := Gui("Resize", A_IconTip)
monitorMenu.OnEvent("Close", (*) => monitorMenu.Hide())
monitorMenu.OnEvent("Size" , (thisGui, MinMax, *) => (MinMax = -1 ? monitorMenu.Hide() : ""))
monitorMenu.SetFont("c0x7678D0 s9 bold q5")
monitorMenu.BackColor := 0x000000
monitorMenu.MarginX := 20
monitorMenu.MarginY := 20

; Get all monitor info
info := mon.GetInfo()
monitorCount := info.Length

; x, y, width, height associative arrays to hold monitor coords, etc.
x := Map(), y := Map(), w := Map(), h := Map()

; Create config tabs
monitorMenuTabs := monitorMenu.Add("Tab3", , MonitorTabs(info, monitorCount))

; Create empty associative arrays to hold each GUI control object for each monitor found
for feature in features := ["gammaAll", "gammaRed", "gammaGreen", "gammaBlue", "contrast", "brightness", "dimmer"]
{
    %feature%            := Map() ; slider controls
    %feature%Title       := Map() ; title text controls
    %feature%SliderStart := Map() ; slider front-end control ("0")
    %feature%SliderEnd   := Map() ; slider back-end control ("100")
}

gammaAll := Map()
gammaAllTitle := Map()
gammaAllSliderStart := Map()
gammaAllSliderEnd := Map()

gammaRed := Map()
gammaRedTitle := Map()
gammaRedSliderStart := Map()
gammaRedSliderEnd := Map()

gammaGreen := Map()
gammaGreenTitle := Map()
gammaGreenSliderStart := Map()
gammaGreenSliderEnd := Map()

gammaBlue := Map()
gammaBlueTitle := Map()
gammaBlueSliderStart := Map()
gammaBlueSliderEnd := Map()

contrast := Map()
contrastTitle := Map()
contrastSliderStart := Map()
contrastSliderEnd := Map()

brightness := Map()
brightnessTitle := Map()
brightnessSliderStart := Map()
brightnessSliderEnd := Map()

dimmer := Map()
dimmerTitle := Map()
dimmerSliderStart := Map()
dimmerSliderEnd := Map()

PowerOn := Map()
PowerOff := Map()
overlay := Map()
dimmerVisible := Map()
ResetSettingsCtrl := Map()
PowerOn  := Map(), PowerOff := Map()
overlay  := Map(), dimmerVisible := Map(), ResetSettingsCtrl := Map()

; Global variables for scheduler
global schedulerActive := false
global scheduleTimer := ""
global schedulesData := []

ToggleSchedule(chkbox, *)
{
    global
    
    ; Get schedule number from control name
    schedNum := Integer(SubStr(chkbox.Name, -1))
    
    if (chkbox.Value)
    {
        ; Validate time format
        startTime := scheduleStartTime[schedNum].Text
        endTime := scheduleEndTime[schedNum].Text
        dimLevel := scheduleDimLevel[schedNum].Text
        
        if (!ValidateTimeFormat(startTime) || !ValidateTimeFormat(endTime))
        {
            MsgBox("Invalid time format. Use HH:MM (24-hour format)", "Schedule Error", "Icon!")
            chkbox.Value := 0
            return
        }
        
        if (dimLevel < 0 || dimLevel > 99)
        {
            MsgBox("Dim level must be between 0 and 99", "Schedule Error", "Icon!")
            chkbox.Value := 0
            return
        }
    }
    
    UpdateScheduler()
}

ValidateTimeFormat(timeStr)
{
    if (!RegExMatch(timeStr, "^([0-1]?[0-9]|2[0-3]):([0-5][0-9])$"))
        return false
    return true
}

UpdateScheduler()
{
    global
    
    ; Clear existing timer
    if (scheduleTimer)
    {
        SetTimer(CheckSchedule, 0)
        scheduleTimer := ""
    }
    
    ; Check if any schedule is enabled
    schedulerActive := false
    Loop 5
    {
        if (scheduleEnabled[A_Index].Value)
        {
            schedulerActive := true
            break
        }
    }
    
    if (schedulerActive)
    {
        ; Start checking every 30 seconds
        SetTimer(CheckSchedule, 30000)
        scheduleTimer := "Active"
        scheduleStatus.Text := "`nScheduler Status: Active - Checking every 30 seconds"
        CheckSchedule()  ; Check immediately
    }
    else
    {
        scheduleStatus.Text := "`nScheduler Status: Inactive"
    }
}

CheckSchedule()
{
    global
    
    currentTime := FormatTime(, "HH:mm")
    currentMinutes := TimeToMinutes(currentTime)
    
    Loop 5
    {
        if (!scheduleEnabled[A_Index].Value)
            continue
            
        startTime := scheduleStartTime[A_Index].Text
        endTime := scheduleEndTime[A_Index].Text
        dimLevel := Integer(scheduleDimLevel[A_Index].Text)
        
        startMinutes := TimeToMinutes(startTime)
        endMinutes := TimeToMinutes(endTime)
        
        inSchedule := false
        
        ; Handle schedules that cross midnight
        if (endMinutes < startMinutes)
        {
            ; Schedule crosses midnight
            if (currentMinutes >= startMinutes || currentMinutes <= endMinutes)
                inSchedule := true
        }
        else
        {
            ; Normal schedule
            if (currentMinutes >= startMinutes && currentMinutes <= endMinutes)
                inSchedule := true
        }
        
        if (inSchedule)
        {
            ; Apply dimming and gamma shift
            targetMonitor := 0  ; Default to all
            if (monitorCount > 1)
            {
                selectedValue := scheduleMonitorSelect[A_Index].Value
                if (selectedValue > 1)  ; Not "All"
                    targetMonitor := selectedValue - 1
            }
            else
            {
                targetMonitor := 1
            }
            
            ApplyScheduledSettings(dimLevel, targetMonitor)
            scheduleStatus.Text := "`nScheduler Status: Active - Schedule " A_Index " applied (" dimLevel "%)"
            return  ; Only apply first matching schedule
        }
    }
    
    ; No active schedule, reset to defaults
    ApplyScheduledSettings(0, 0)
    scheduleStatus.Text := "`nScheduler Status: Active - No schedule matches current time"
}

TimeToMinutes(timeStr)
{
    parts := StrSplit(timeStr, ":")
    return Integer(parts[1]) * 60 + Integer(parts[2])
}

ApplyScheduledSettings(level, targetMonitor)
{
    global
    
    ; Calculate gamma reduction based on dim level
    ; At 90% dim, reduce blue light to 30%, green to 50%, red to 70%
    gammaReduction := level / 90.0
    newGammaRed := 100 - (30 * gammaReduction)
    newGammaGreen := 100 - (50 * gammaReduction)
    newGammaBlue := 100 - (70 * gammaReduction)
    
    if (targetMonitor = 0)
    {
        ; Apply to all monitors
        dimmer[0].Value := level
        AdjustDimmer(dimmer[0])
        
        ; Apply gamma shift
        gammaRed[0].Value := newGammaRed
        gammaGreen[0].Value := newGammaGreen
        gammaBlue[0].Value := newGammaBlue
        AdjustGamma(gammaRed[0])
        AdjustGamma(gammaGreen[0])
        AdjustGamma(gammaBlue[0])
    }
    else
    {
        ; Apply to specific monitor
        dimmer[targetMonitor].Value := level
        AdjustDimmer(dimmer[targetMonitor])
        
        ; Apply gamma shift
        gammaRed[targetMonitor].Value := newGammaRed
        gammaGreen[targetMonitor].Value := newGammaGreen
        gammaBlue[targetMonitor].Value := newGammaBlue
        AdjustGamma(gammaRed[targetMonitor])
        AdjustGamma(gammaGreen[targetMonitor])
        AdjustGamma(gammaBlue[targetMonitor])
    }
}

SaveSchedule(*)
{
    global
    
    ; Create schedule data string
    scheduleData := ""
    Loop 5
    {
        i := A_Index
        scheduleData .= scheduleEnabled[i].Value ","
        scheduleData .= scheduleStartTime[i].Text ","
        scheduleData .= scheduleEndTime[i].Text ","
        scheduleData .= scheduleDimLevel[i].Text ","
        if (monitorCount > 1)
            scheduleData .= scheduleMonitorSelect[i].Value
        else
            scheduleData .= "1"
        scheduleData .= "`n"
    }
    
    ; Save to file
    FileAppend(scheduleData, A_ScriptDir "\dimmer_schedule.txt")
    MsgBox("Schedule saved successfully!", "Save Schedule", "Iconi T2")
}

LoadSchedule(*)
{
    global
    
    if (!FileExist(A_ScriptDir "\dimmer_schedule.txt"))
    {
        MsgBox("No saved schedule found!", "Load Schedule", "Icon!")
        return
    }
    
    scheduleData := FileRead(A_ScriptDir "\dimmer_schedule.txt")
    lines := StrSplit(scheduleData, "`n")
    
    Loop 5
    {
        if (A_Index > lines.Length)
            break
            
        if (!lines[A_Index])
            continue
            
        parts := StrSplit(lines[A_Index], ",")
        if (parts.Length >= 5)
        {
            i := A_Index
            scheduleEnabled[i].Value := Integer(parts[1])
            scheduleStartTime[i].Text := parts[2]
            scheduleEndTime[i].Text := parts[3]
            scheduleDimLevel[i].Text := parts[4]
            if (monitorCount > 1)
                scheduleMonitorSelect[i].Value := Integer(parts[5])
        }
    }
    
    UpdateScheduler()
    MsgBox("Schedule loaded successfully!", "Load Schedule", "Iconi T2")
}

ApplyScheduleNow(*)
{
    CheckSchedule()
    MsgBox("Schedule applied based on current time!", "Apply Now", "Iconi T2")
}
; Detect hidden windows so script can see transparent dimmer overlay GUIs when present
DetectHiddenWindows(true)

; iterate [once for each monitor found plus 1] OR [only once for single-monitor setups]
i := 0
while ((i := A_Index - (monitorCount > 1 ? 1 : 0)) <= monitorCount)
{
    ; Use the correct tab for each monitor / all monitor config
    monitorMenuTabs.UseTab(monitorCount = 1 ? info[1]["Name"] : (!i ? "All Monitors" : (info[i]["Primary"] ? info[i]["Name"] " [Primary]" : info[i]["Name"])))

    ; Get gamma output for each monitor and set All Monitors Config gamma to 100% initially
    g := (i ? mon.GetGammaRamp(i) : 100) 

    if (i) ; Specific to each monitor (e.g. not ALL monitors)
    {
        ; Get each monitor's x & y coords, width, height
        x[i] := info[i]["Left"], w[i] := (info[i]["Right"] - x[i])
        y[i] := info[i]["Top"] , h[i] := (info[i]["Bottom"] - y[i])
    
        ; Create Dimmer (Black Overlay)
		overlay[i] := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x20 -DPIScale")
        overlay[i].BackColor := "0x000000" ; Sets dimmer color as pure black

        ; Determine monitor capabilities for each monitor for gamma, brightness, contrast, power mode
        ; Get each monitor's gamma output levels
        try
        {
            gR := g["Red"], gG := g["Green"], gB := g["Blue"]
            gammaCapability := true
        }
        catch
            gammaCapability := false    
        
        try 
        {
            b := mon.GetBrightness(i)["Current"]
            brightnessCapability := true
        }    
        catch
            brightnessCapability := false
            
        try 
        {
            c := mon.GetContrast(i)["Current"]
            contrastCapability := true
        }    
        catch
            contrastCapability := false
            
        try 
        {
            p := mon.GetPowerMode(i)
            powerCapability := true
        }    
        catch
            powerCapability := false    
            
        if (brightnessCapability && contrastCapability && powerCapability) 
            resetCapability := true
        else
            resetCapability := false 

        if (!gammaCapability && !resetCapability)
            resetAbility := "Disabled"
        else
            resetAbility := ""
    }

    ; Create Monitor Config controls
    gammaAllTitle[i]   := monitorMenu.Add("Text", "w200 Section Center", "Gamma (All):`t`t" 100 "%")
    gammaAll[i]        := monitorMenu.Add("Slider", "xp AltSubmit ToolTip TickInterval10 Page10 Thick30 vGammaAll" i, 100)

    gammaRedTitle[i]   := monitorMenu.Add("Text", "w200 xp Center", "Gamma (Red):`t`t" Round(i ? gR : 100) "%")
    gammaRed[i]        := monitorMenu.Add("Slider", "xp AltSubmit ToolTip TickInterval10 Page10 Thick30 vGammaRed" i, (i ? gR : 100))

    gammaGreenTitle[i] := monitorMenu.Add("Text", "w200 xp Center", "Gamma (Green):`t" Round(i ? gG : 100) "%")
    gammaGreen[i]      := monitorMenu.Add("Slider", "xp AltSubmit ToolTip TickInterval10 Page10 Thick30 vGammaGreen" i, (i ? gG : 100))

    gammaBlueTitle[i]  := monitorMenu.Add("Text", "w200 xp Center", "Gamma (Blue):`t`t" Round(i ? gB : 100) "%")
    gammaBlue[i]       := monitorMenu.Add("Slider", "xp AltSubmit ToolTip TickInterval10 Page10 Thick30 vGammaBlue" i, (i ? gB : 100))

    brightnessTitle[i] := monitorMenu.Add("Text", "w200 xs+220 ys Center", "Brightness:`t`t" Round(i ? (IsSet(b) ? b : 0) : 100) "%")
    brightness[i]      := monitorMenu.Add("Slider", "xp AltSubmit ToolTip TickInterval10 Page10 Thick30 " (i ? (IsSet(b) ? "" : "Disabled") : "") " vBrightnessSlider" i, (i ? (IsSet(b) ? b : 0) : 100))

    contrastTitle[i]   := monitorMenu.Add("Text", "w200 xp Center", "Contrast:`t`t" Round(i ? (IsSet(c) ? c : 0) : 100) "%")
    contrast[i]        := monitorMenu.Add("Slider", "xp AltSubmit ToolTip TickInterval10 Page10 Thick30 " (i ? (IsSet(c) ? "" : "Disabled") : "") " vContrastSlider" i, (i ? (IsSet(c) ? c : 0) : 100))

    dimmerTitle[i]     := monitorMenu.Add("Text", "w200 xp Center", "Dimmer (Overlay):`t" 0 "%")
    dimmer[i] := monitorMenu.Add("Slider", "xp AltSubmit ToolTip TickInterval10 Page10 Thick30 vDimmerSlider" i " Range0-90", 0)
    dimmerVisible[i]   := false

    PowerOn[i]  := monitorMenu.Add("Radio", "xp Group " (i ? (IsSet(p) ? "" : "Disabled") : "") " vPowerOnRadio" i, "Turn " ( i ? "[" info[i]["Name"] "]" : "All Monitors" ) " On")
    PowerOff[i] := monitorMenu.Add("Radio", "xp " (i ? (IsSet(p) ? "" : "Disabled") : "") " vPowerOffRadio" i, "Turn " ( i ? "[" info[i]["Name"] "]" : "All Monitors" ) " Off")

    ResetSettingsCtrl[i] := monitorMenu.Add("Checkbox", "xp " (i ? (resetCapability ? "" : "Disabled") : "") " vResetSettings" i, "Reset to Factory Settings")

    gammaAll[i].OnEvent("Change", AdjustGamma)
    gammaRed[i].OnEvent("Change", AdjustGamma)
    gammaGreen[i].OnEvent("Change", AdjustGamma)
    gammaBlue[i].OnEvent("Change", AdjustGamma)
    brightness[i].OnEvent("Change", AdjustBrightnessOrContrast)
    contrast[i].OnEvent("Change", AdjustBrightnessOrContrast)    
    dimmer[i].OnEvent("Change", AdjustDimmer)    
    PowerOn[i].OnEvent("Click", ChangePowerState)    
    PowerOff[i].OnEvent("Click", ChangePowerState)    
    ResetSettingsCtrl[i].OnEvent("Click", ResetSettings)    
}

; Make additional tabs
monitorMenuTabs.UseTab("Background Modes")
monitorMenu.Add("Text", "w400", "Background Modes:`n`n"
    . "Some backgrounds in programs like Excel or Notepad are terribly white and even in the day time can be way too bright. The following Background Modes helps partially solve this issue by changing the background, window, and text colors system-wide.`n`n"
    . "(This will reset to default system colors when you close this app)")

BackgroundNormalModeRadio   := monitorMenu.Add("Radio", "Group vNormal", "Normal Mode (default)").OnEvent("Click", ChangeBackgroundMode) 
BackgroundMorningModeRadio  := monitorMenu.Add("Radio", "vMorning", "Morning Mode").OnEvent("Click", ChangeBackgroundMode)
BackgroundDayModeRadio      := monitorMenu.Add("Radio", "vDay", "Day Mode").OnEvent("Click", ChangeBackgroundMode)
BackgroundNightModeRadio    := monitorMenu.Add("Radio", "vNight", "Night Mode").OnEvent("Click", ChangeBackgroundMode)
BackgroundEveningModeRadio  := monitorMenu.Add("Radio", "vEvening", "Evening Mode").OnEvent("Click", ChangeBackgroundMode)
BackgroundMidnightModeRadio := monitorMenu.Add("Radio", "vMidnight", "Midnight Mode").OnEvent("Click", ChangeBackgroundMode)
BackgroundTwilightModeRadio := monitorMenu.Add("Radio", "vTwilight", "Twilight Mode").OnEvent("Click", ChangeBackgroundMode)

monitorMenuTabs.UseTab("Background Themes")
monitorMenu.Add("Text", "w400", "Background Themes:`n`n"
    . "This alters your Windows Theme and will not reset when you reboot, log back in, or close this app. A known limitation is that in Excel you cannot see the font or background cell colors (except black && white) since it places your system into High Contrast mode.`n`n"
    . "This is the best way to have your entire system color set be ultra dark / low-light. To change it back to your Custom User Theme, go to`n`n"
    . "Windows Settings > Personalization > Themes")
    
midnightTheme := monitorMenu.Add("Radio", "vMidnightTheme", "Midnight Theme").OnEvent("Click", ActivateTheme)
twilightTheme := monitorMenu.Add("Radio", "vTwilightTheme", "Twilight Theme").OnEvent("Click", ActivateTheme)
darkTheme     := monitorMenu.Add("Radio", "vDarkTheme", "Windows Default (Dark) Theme").OnEvent("Click", ActivateTheme)
lightTheme    := monitorMenu.Add("Radio", "vLightTheme", "Windows Default (Light) Theme").OnEvent("Click", ActivateTheme)

monitorMenuTabs.UseTab("Advanced Settings")
monitorMenu.Add("Text", "w400", "Custom hotkey support coming soon.")

monitorMenuTabs.UseTab("App Info / Report Bug")
monitorMenu.Add("Link", "w400 Center", "Thanks so much for choosing to use the Screen Dimmer!`n`n"
    . "I hope you really enjoy this screen dimmer as I believe it is the best one out there. f.lux, iris, and other well known screen dimmers do not give as much control as I would like and sometimes only create a transparent black screen overlay, which is prone to annoyances.`n`n"
    . "This screen dimmer allows you to adjust actual gamma color output, making your screen completely stop emitting blue, green, or red light if desired, which is way more beneficial than an arbitrary color temperature or simple screen overlay. `n`n"
    . "It also allows you to turn on/off your monitors with a click of a button, which can sometimes help with focusing on a multi-monitor setup.`n`n"
    . "This is a work in progress, but will eventually contain customizable hotkeys, custom timers, color temperature settings, and more.`n`n`n"
    . "Please report any bugs / feedback / comments at either:`n`n"
    . "Feel free email me directly about bugs and about any desired features you want me to add at: ")

monitorMenuTabs.UseTab("Dimming Scheduler")
monitorMenu.Add("Text", "w400", "Automatic Dimming Scheduler`n`nSet up automatic dimming based on system time. The dimmer will gradually adjust to your specified levels.")
monitorMenu.Add("Text", "w400 Section", "`nSchedule Slots:")
monitorMenu.Add("Text", "xm w400", "`n")  ; Spacing



global scheduleEnabled := Map()
global scheduleStartTime := Map()
global scheduleEndTime := Map()
global scheduleDimLevel := Map()
global scheduleMonitorSelect := Map()


Loop 5
{
    i := A_Index
    
    ; Enable checkbox
    scheduleEnabled[i] := monitorMenu.Add("Checkbox", "xm vScheduleEnabled" i, "Schedule " i " - Enabled")
    
    ; Time inputs
    monitorMenu.Add("Text", "x+20 yp w50", "Start:")
    scheduleStartTime[i] := monitorMenu.Add("Edit", "x+5 yp-3 w50 vStartTime" i, "00:00")
    
    monitorMenu.Add("Text", "x+10 yp+3 w30", "End:")
    scheduleEndTime[i] := monitorMenu.Add("Edit", "x+5 yp-3 w50 vEndTime" i, "00:00")
    
    monitorMenu.Add("Text", "x+10 yp+3 w40", "Dim %:")
    scheduleDimLevel[i] := monitorMenu.Add("Edit", "x+5 yp-3 w30 Number vDimLevel" i, "50")
    
    ; Monitor selection
    monitorMenu.Add("Text", "x+10 yp+3 w50", "Monitor:")
    if (monitorCount > 1)
    {
        monitorList := ["All"]
        Loop monitorCount
            monitorList.Push(A_Index)
        scheduleMonitorSelect[i] := monitorMenu.Add("DropDownList", "x+5 yp-3 w50 vMonitorSelect" i, monitorList)
        scheduleMonitorSelect[i].Value := 1  ; Default to "All"
    }
    else
    {
        scheduleMonitorSelect[i] := monitorMenu.Add("Text", "x+5 yp w30", "1")
    }
    
    ; Events
    scheduleEnabled[i].OnEvent("Click", ToggleSchedule)
}

saveScheduleBtn := monitorMenu.Add("Button", "xm w100", "Save Schedule")
loadScheduleBtn := monitorMenu.Add("Button", "x+10 w100", "Load Schedule")
applyNowBtn := monitorMenu.Add("Button", "x+10 w100", "Apply Now")

saveScheduleBtn.OnEvent("Click", SaveSchedule)
loadScheduleBtn.OnEvent("Click", LoadSchedule)
applyNowBtn.OnEvent("Click", ApplyScheduleNow)
global scheduleStatus := monitorMenu.Add("Text", "xm w400", "`nScheduler Status: Inactive")

; Sets "All Monitors" Tab sliders if all monitors have matching current feature setting values
if (monitorCount > 1)
{
    for feature in ["gammaRed", "gammaGreen", "gammaBlue", "contrast", "brightness"]
    {
        i := 0
        while ((i := A_Index) <= monitorCount)
        {
            z := (i < monitorCount ? (i + 1) : 1)
            if (%feature%[i].Value = %feature%[z].Value)
            {
                %feature%LoadAll := true
            }
            else
            {
                %feature%LoadAll := false
                break
            }
        }

		if (feature = "gammaRed"   && %feature%LoadAll = true 
		||  feature = "gammaGreen" && %feature%LoadAll = true 
		||  feature = "gammaBlue"  && %feature%LoadAll = true)
		{
			if (feature = "gammaRed")
				gammaRedAllLoadAll := true
			else if (feature = "gammaGreen")
				gammaGreenAllLoadAll := true
			else if (feature = "gammaBlue")
				gammaBlueAllLoadAll := true
		}
		else
		{
			if (feature = "gammaRed")
				gammaRedAllLoadAll := false
			else if (feature = "gammaGreen")
				gammaGreenAllLoadAll := false
			else if (feature = "gammaBlue")
				gammaBlueAllLoadAll := false
		}
    }
    
	gammaRedLoadAll := false
	gammaGreenLoadAll := false
	gammaBlueLoadAll := false
	gammaRedAllLoadAll := false
	gammaGreenAllLoadAll := false
	gammaBlueAllLoadAll := false
	contrastLoadAll := false
	brightnessLoadAll := false

    if (gammaRedAllLoadAll = true && gammaGreenAllLoadAll = true && gammaBlueAllLoadAll = true)
    {
        gammaAll[0].Value := gammaRed[1].Value
        gammaAllTitle[0].Value := "Gamma (All):`t`t" Round(gammaAll[0].Value) "%"
        Loop(monitorCount)
        {
            gammaAll[A_Index].Value := gammaAll[0].Value 
            gammaAllTitle[A_Index].Value := gammaAllTitle[0].Value 
        }
    }
}



monitorMenu.Show()

;................................................................................
;                                  ...............                              ;
;                                   H O T K E Y S                               ;
;................................................................................

; Close app
^Esc::ExitApp()

; Open config
!t::monitorMenu.Show()

;................................................................................
;                               ...................                             ;
;                                F U N C T I O N S                              ;
;................................................................................

MonitorTabs(info, monitorCount)
{ 
    ; Creates tabs based on # of monitors found
    ; Additional Tabs:
    static adv      := "Advanced Settings"
    static bgThemes := "Background Themes"
    static bgModes  := "Background Modes"
    static scheduler := "Dimming Scheduler"
    static appInfo  := "App Info / Report Bug"

    if (monitorCount = 1)
        return [info[1]["Name"], bgModes, bgThemes, scheduler, adv, appInfo]
    else
    {    
        monitorTabs := ["All Monitors"]
        i := 0
        while ((i := A_Index) <= monitorCount)
            monitorTabs.Push((info[i]["Primary"] ? info[i]["Name"] " [Primary]" : info[i]["Name"]))
        monitorTabs.Push(bgModes, bgThemes, scheduler, adv, appInfo)
        return monitorTabs
    }
}

AdjustGamma(slider, *)
{
    global
    if (gammaCapability)
    {
        name := slider.Name, v := slider.Value, n := Integer(SubStr(name, -1)), _R := "Red", _G := "Green", _B := "Blue"
        try
        {
            if (n)
            {
                g := mon.GetGammaRamp(n)
                InStr(name, _R) ? ((gR := v), (color := _R), (gG := g[_G]), (gB := g[_B]), mon.SetGammaRamp(gamma%color%[n].Value := gR, gG, gB, n), gamma%color%Title[n].Value := "Gamma (" color "):`t`t" Round(gR) "%")     
            :   InStr(name, _G) ? ((gG := v), (color := _G), (gR := g[_R]), (gB := g[_B]), mon.SetGammaRamp(gR, gamma%color%[n].Value := gG, gB, n), gamma%color%Title[n].Value := "Gamma (" color "):`t" Round(gG) "%")
            :   InStr(name, _B) ? ((gB := v), (color := _B), (gR := g[_R]), (gG := g[_G]), mon.SetGammaRamp(gR, gG, gamma%color%[n].Value := gB, n), gamma%color%Title[n].Value := "Gamma (" color "):`t`t" Round(gB) "%")
            :   (mon.SetGammaRamp(gammaRed[n].Value := v, gammaGreen[n].Value := v, gammaBlue[n].Value := v, n), (gammaAllTitle[n].Value := "Gamma (All):`t`t" Round(v) "%"), (gammaRedTitle[n].Value := "Gamma (Red):`t`t" Round(v) "%"), (gammaGreenTitle[n].Value := "Gamma (Green):`t" Round(v) "%"), (gammaBlueTitle[n].Value := "Gamma (Blue):`t`t" Round(v) "%"))
            }
            else
            {
                i := 0
                while ((i := A_Index) <= monitorCount)
                {
                    g := mon.GetGammaRamp(i)
                    InStr(name, _R) ? ((gR := v), (color := _R), (gG := g[_G]), (gB := g[_B]), mon.SetGammaRamp(gamma%color%[i].Value := gR, gG, gB, i), gamma%color%Title[0].Value := gamma%color%Title[i].Value := "Gamma (" color "):`t`t" Round(gR) "%")     
                :   InStr(name, _G) ? ((gG := v), (color := _G), (gR := g[_R]), (gB := g[_B]), mon.SetGammaRamp(gR, gamma%color%[i].Value := gG, gB, i), gamma%color%Title[0].Value := gamma%color%Title[i].Value := "Gamma (" color "):`t" Round(gG) "%")
                :   InStr(name, _B) ? ((gB := v), (color := _B), (gR := g[_R]), (gG := g[_G]), mon.SetGammaRamp(gR, gG, gamma%Color%[i].Value := gB, i), gamma%color%Title[0].Value := gamma%color%Title[i].Value := "Gamma (" color "):`t`t" Round(gB) "%")
                :   (mon.SetGammaRamp(gammaAll[0].Value := gammaRed[0].Value := gammaGreen[0].Value := gammaBlue[0].Value := gammaAll[i].Value := gammaRed[i].Value := v, gammaGreen[i].Value := v, gammaBlue[i].Value := v, i), (gammaAllTitle[0].Value := gammaAllTitle[i].Value := "Gamma (All):`t`t" Round(v) "%"), (gammaRedTitle[0].Value := gammaRedTitle[i].Value := "Gamma (Red):`t`t" Round(v) "%"), (gammaGreenTitle[0].Value := gammaGreenTitle[i].Value := "Gamma (Green):`t" Round(v) "%"), (gammaBlueTitle[0].Value := gammaBlueTitle[i].Value := "Gamma (Blue):`t`t" Round(v) "%"))   
                }
            }  
        }
    }
}

AdjustBrightnessOrContrast(slider, *)
{
    global       
    try
    {
        v := slider.Value, name := slider.Name
        if (n := Integer(SubStr(name, -1)))
            InStr(name, "Brightness") ? (mon.SetBrightness(v, n), (brightnessTitle[n].Value := "Brightness:`t`t" Round(v) "%")) 
                                      : (mon.SetContrast(v, n), (contrastTitle[n].Value := "Contrast:`t`t" Round(v) "%"))
        else
        {
            i := 0
            while ((i := A_Index) <= monitorCount)
                InStr(name, "Brightness") ? (mon.SetBrightness(brightness[i].Value := v, i), (brightnessTitle[0].Value := brightnessTitle[i].Value := "Brightness:`t`t" Round(v) "%"))  
                                          : (mon.SetContrast(contrast[i].Value := v, i), (contrastTitle[0].Value := contrastTitle[i].Value := "Contrast:`t`t" Round(v) "%"))
        }
        Sleep(100) ; Calling these methods below too fast can throw errors, so give 100 ms break
    }
}

AdjustDimmer(slider, *)
{
    global   
    v := slider.Value
    dim := Round(v * 2.55) ; Make sure it's rounded
    
    try 
    {
        if (n := Integer(SubStr(slider.Name, -1)))  
        {   
            if (dim > 0) ; Changed from just 'dim'
            {
                overlay[n].Show("x" x[n] " y" y[n] " w" w[n] " h" h[n] " NoActivate")
                WinSetTransparent(dim, "ahk_id " overlay[n].Hwnd) ; Note: Hwnd not hWnd
                dimmerVisible[n] := true
                dimmerTitle[n].Text := "Dimmer (Overlay):`t" Round(v) "%" ; .Text not .Value
            }
            else
            {
                overlay[n].Hide()
                dimmerVisible[n] := false
                dimmerTitle[n].Text := "Dimmer (Overlay):`t0%"
            }
        }
        else
        {
            i := 0
            while ((i := A_Index) <= monitorCount)
            {
                if (dim)
                {
                    WinSetTransparent(dim, "ahk_id " overlay[i].hWnd)
                    if (dimmerVisible[i] = false)
                    {
                        overlay[i].Show("x" x[i] " y" y[i] " w" w[i] " h" h[i])
                        dimmerVisible[i] := true
                    }
                    dimmerTitle[0].Value := dimmerTitle[i].Value := "Dimmer (Overlay):`t" Round(dimmer[i].Value := v) "%"
                }
                else
                {
                    overlay[i].Hide(), dimmerVisible[i] := false, dimmerTitle[0].Value := dimmerTitle[i].Value := "Dimmer (Overlay):`t" Round(v) "%"
                }  
            }      
        }        
    }
}

ChangePowerState(radio, *)
{
    global   
    name := radio.Name
    try  
    {     
        if (powerCapability) 
        {
            if (InStr(name, "On"))
            {
                if (n := Integer(SubStr(name, -1)))
                    mon.SetPowerMode("On", n), PowerOn[n].Value := 0
                else
                {
                    PowerOn[0].Value := 0 
                    Loop(monitorCount)
                        mon.SetPowerMode("On", A_Index)    
                }
            }        
            else
            {
                if (n := Integer(SubStr(name, -1)))
                    mon.SetPowerMode("PowerOff", n), PowerOff[n].Value := 0
                else
                {
                    PowerOff[0].Value := 0       
                    Loop(monitorCount)
                        mon.SetPowerMode("PowerOff", A_Index)
                }
            }
        }        
    }
}

ChangeBackgroundMode(radio, *)
{
    static userBg := DllCall("user32\GetSysColor", "int", 1) ; Desktop background color
    static backgroundModes := Map(
        "Normal"  , Map(0x000000, 0xC8C8C8, 1,   userBg, 2, 0xD1B499, 3, 0xDBCDBF, 4, 0xF0F0F0, 5, 0xFFFFFF, 6, 0x646464, 7, 0x000000, 8, 0x000000, 9, 0x000000, 10, 0xB4B4B4, 11, 0xFCF7F4, 12, 0xABABAB, 13, 0xD77800, 14, 0xFFFFFF, 15, 0xF0F0F0, 16, 0xA0A0A0, 17, 0x6D6D6D, 18, 0x000000, 19, 0x000000, 20, 0xFFFFFF, 21, 0x696969, 22, 0xE3E3E3, 23, 0x000000, 24, 0xE1FFFF, 26, 0xCC6600, 27, 0xEAD1B9, 28, 0xF2E4D7, 29, 0xD77800, 30, 0xF0F0F0),
        "Morning" , Map(0x000000, 0xC7EDCC, 1,   userBg, 2, 0xD1B499, 3, 0xC7EDCC, 4, 0xC7EDCC, 5, 0xC7EDCC, 6, 0x646464, 7, 0x000000, 8, 0x000000, 9, 0x000000, 10, 0xB4B4B4, 11, 0xFCF7F4, 12, 0xC7EDCC, 13, 0xD77800, 14, 0xFFFFFF, 15, 0xC7EDCC, 16, 0xA0A0A0, 17, 0x6D6D6D, 18, 0x000000, 19, 0x000000, 20, 0xFFFFFF, 21, 0x696969, 22, 0xE3E3E3, 23, 0x000000, 24, 0xE1FFFF, 26, 0xCC6600, 27, 0xEAD1B9, 28, 0xF2E4D7, 29, 0xD77800, 30, 0xF0F0F0),
        "Day"     , Map(0x000000, 0xABABAB, 1,   userBg, 2, 0xD1B499, 3, 0xABABAB, 4, 0xABABAB, 5, 0xABABAB, 6, 0x646464, 7, 0x000000, 8, 0x000000, 9, 0x000000, 10, 0xB4B4B4, 11, 0xFCF7F4, 12, 0xABABAB, 13, 0xD77800, 14, 0xFFFFFF, 15, 0xABABAB, 16, 0xA0A0A0, 17, 0x6D6D6D, 18, 0x000000, 19, 0x000000, 20, 0xFFFFFF, 21, 0x696969, 22, 0xE3E3E3, 23, 0x000000, 24, 0xE1FFFF, 26, 0xCC6600, 27, 0xEAD1B9, 28, 0xF2E4D7, 29, 0xD77800, 30, 0xF0F0F0),
        "Night"   , Map(0x000000, 0x000000, 1, 0x000000, 2, 0x595757, 3, 0x595757, 4, 0x595757, 5, 0x595757, 6, 0x000000, 7, 0x000000, 8, 0xC6C8C5, 9, 0xC6C8C5, 10, 0x000000, 11, 0x000000, 12, 0x595757, 13, 0x5A5A57, 14, 0xC6C8C5, 15, 0x595757, 16, 0x000000, 17, 0x808080, 18, 0xC6C8C5, 19, 0xC6C8C5, 20, 0x5A5A57, 21, 0x000000, 22, 0x5A5A57, 23, 0xC6C8C5, 24, 0x000000, 26, 0xF0B000, 27, 0x000000, 28, 0x000000, 29, 0x5A5A57, 30, 0x000000),
        "Evening" , Map(0x000000, 0x000000, 1, 0x000000, 2, 0x222223, 3, 0x222223, 4, 0x222223, 5, 0x222223, 6, 0x000000, 7, 0x000000, 8, 0xC6C8C5, 9, 0xC6C8C5, 10, 0x000000, 11, 0x000000, 12, 0x222223, 13, 0x5A5A57, 14, 0xC6C8C5, 15, 0x222223, 16, 0x000000, 17, 0x808080, 18, 0xC6C8C5, 19, 0xC6C8C5, 20, 0x5A5A57, 21, 0x000000, 22, 0x5A5A57, 23, 0xC6C8C5, 24, 0x000000, 26, 0xF0B000, 27, 0x000000, 28, 0x000000, 29, 0x5A5A57, 30, 0x000000),
        "Midnight", Map(0x000000, 0x000000, 1, 0x000000, 2, 0xC6C8C5, 3, 0x000000, 4, 0x000000, 5, 0x000000, 6, 0x000000, 7, 0x000000, 8, 0xC6C8C5, 9, 0xC6C8C5, 10, 0x000000, 11, 0x000000, 12, 0x000000, 13, 0x5A5A57, 14, 0xC6C8C5, 15, 0x000000, 16, 0x000000, 17, 0x808080, 18, 0xC6C8C5, 19, 0xC6C8C5, 20, 0x000000, 21, 0x000000, 22, 0x000000, 23, 0xC6C8C5, 24, 0x000000, 26, 0xF0B000, 27, 0x000000, 28, 0x000000, 29, 0x5A5A57, 30, 0x000000),
        "Twilight", Map(0x000000, 0x000000, 1, 0x000000, 2, 0x8C3230, 3, 0x000000, 4, 0x000000, 5, 0x000000, 6, 0x000000, 7, 0x000000, 8, 0x8C3230, 9, 0xC6C8C5, 10, 0x000000, 11, 0x000000, 12, 0x000000, 13, 0x080816, 14, 0xC04B48, 15, 0x000000, 16, 0x000000, 17, 0x808080, 18, 0x8C3230, 19, 0x8C3230, 20, 0x000000, 21, 0x000000, 22, 0x000000, 23, 0x8C3230, 24, 0x000000, 26, 0xC04B48, 27, 0x000000, 28, 0x000000, 29, 0x5A5A57, 30, 0x000000))
    try 
        for displayElement, color in backgroundModes[radio.Name]
            DllCall("user32\SetSysColors", "Int", 1, "IntP", displayElement, "UIntP", color)
}

ActivateTheme(radio, *)
{
    global

lightThemeFile := "[Theme]`n"
    . "; Windows - IDS_THEME_DISPLAYNAME_AERO_LIGHT`n"
    . "DisplayName=Windows Default (Light)`n"
    . "SetLogonBackground=0`n"
    . "`n"
    . "; Computer - SHIDI_SERVER`n"
    . "[CLSID\{20D04FE0-3AEA-1069-A2D8-08002B30309D}\DefaultIcon]`n"
    . "DefaultValue=%SystemRoot%\System32\imageres.dll,-109`n"
    . "`n"
    . "; UsersFiles - SHIDI_USERFILES`n"
    . "[CLSID\{59031A47-3F72-44A7-89C5-5595FE6B30EE}\DefaultIcon]`n"
    . "DefaultValue=%SystemRoot%\System32\imageres.dll,-123`n"
    . "`n"
    . "; Network - SHIDI_MYNETWORK`n"
    . "[CLSID\{F02C1A0D-BE21-4350-88B0-7367FC96EF3C}\DefaultIcon]`n"
    . "DefaultValue=%SystemRoot%\System32\imageres.dll,-25`n"
    . "`n"
    . "; Recycle Bin - SHIDI_RECYCLERFULL SHIDI_RECYCLER`n"
    . "[CLSID\{645FF040-5081-101B-9F08-00AA002F954E}\DefaultIcon]`n"
    . "Full=%SystemRoot%\System32\imageres.dll,-54`n"
    . "Empty=%SystemRoot%\System32\imageres.dll,-55`n"
    . "`n"
    . "[Control Panel\Cursors]`n"
    . "AppStarting=%SystemRoot%\cursors\aero_working.ani`n"
    . "Arrow=%SystemRoot%\cursors\aero_arrow.cur`n"
    . "Crosshair=`n"
    . "Hand=%SystemRoot%\cursors\aero_link.cur`n"
    . "Help=%SystemRoot%\cursors\aero_helpsel.cur`n"
    . "IBeam=`n"
    . "No=%SystemRoot%\cursors\aero_unavail.cur`n"
    . "NWPen=%SystemRoot%\cursors\aero_pen.cur`n"
    . "SizeAll=%SystemRoot%\cursors\aero_move.cur`n"
    . "SizeNESW=%SystemRoot%\cursors\aero_nesw.cur`n"
    . "SizeNS=%SystemRoot%\cursors\aero_ns.cur`n"
    . "SizeNWSE=%SystemRoot%\cursors\aero_nwse.cur`n"
    . "SizeWE=%SystemRoot%\cursors\aero_ew.cur`n"
    . "UpArrow=%SystemRoot%\cursors\aero_up.cur`n"
    . "Wait=%SystemRoot%\cursors\aero_busy.ani`n"
    . "DefaultValue=Windows Default`n"
    . "DefaultValue.MUI=@main.cpl,-1020`n"
    . "`n"
    . "[Control Panel\Desktop]`n"
    . "Wallpaper=%SystemRoot%\web\wallpaper\Windows\img0.jpg`n"
    . "TileWallpaper=0`n"
    . "WallpaperStyle=10`n"
    . "Pattern=`n"
    . "`n"
    . "[VisualStyles]`n"
    . "Path=%ResourceDir%\Themes\Aero\Aero.msstyles`n"
    . "ColorStyle=NormalColor`n"
    . "Size=NormalSize`n"
    . "AutoColorization=0`n"
    . "ColorizationColor=0XC40078D7`n"
    . "SystemMode=Light`n"
    . "AppMode=Light`n"
    . "`n"
    . "[boot]`n"
    . "SCRNSAVE.EXE=`n"
    . "`n"
    . "[MasterThemeSelector]`n"
    . "MTSM=RJSPBS`n"
    . "`n"
    . "[Sounds]`n"
    . "; IDS_SCHEME_DEFAULT`n"
    . "SchemeName=@%SystemRoot%\System32\mmres.dll,-800"

darkThemeFile := "[Theme]`n"
    . "DisplayName=Windows Default (Dark)`n"
    . "SetLogonBackground=0`n"
    . "`n"
    . "; Computer - SHIDI_SERVER`n"
    . "[CLSID\{20D04FE0-3AEA-1069-A2D8-08002B30309D}\DefaultIcon]`n"
    . "DefaultValue=%SystemRoot%\System32\imageres.dll,-109`n"
    . "`n"
    . "; UsersFiles - SHIDI_USERFILES`n"
    . "[CLSID\{59031A47-3F72-44A7-89C5-5595FE6B30EE}\DefaultIcon]`n"
    . "DefaultValue=%SystemRoot%\System32\imageres.dll,-123`n"
    . "`n"
    . "; Network - SHIDI_MYNETWORK`n"
    . "[CLSID\{F02C1A0D-BE21-4350-88B0-7367FC96EF3C}\DefaultIcon]`n"
    . "DefaultValue=%SystemRoot%\System32\imageres.dll,-25`n"
    . "`n"
    . "; Recycle Bin - SHIDI_RECYCLERFULL SHIDI_RECYCLER`n"
    . "[CLSID\{645FF040-5081-101B-9F08-00AA002F954E}\DefaultIcon]`n"
    . "Full=%SystemRoot%\System32\imageres.dll,-54`n"
    . "Empty=%SystemRoot%\System32\imageres.dll,-55`n"
    . "`n"
    . "[Control Panel\Cursors]`n"
    . "AppStarting=%SystemRoot%\cursors\aero_working.ani`n"
    . "Arrow=%SystemRoot%\cursors\aero_arrow.cur`n"
    . "Crosshair=`n"
    . "Hand=%SystemRoot%\cursors\aero_link.cur`n"
    . "Help=%SystemRoot%\cursors\aero_helpsel.cur`n"
    . "IBeam=`n"
    . "No=%SystemRoot%\cursors\aero_unavail.cur`n"
    . "NWPen=%SystemRoot%\cursors\aero_pen.cur`n"
    . "SizeAll=%SystemRoot%\cursors\aero_move.cur`n"
    . "SizeNESW=%SystemRoot%\cursors\aero_nesw.cur`n"
    . "SizeNS=%SystemRoot%\cursors\aero_ns.cur`n"
    . "SizeNWSE=%SystemRoot%\cursors\aero_nwse.cur`n"
    . "SizeWE=%SystemRoot%\cursors\aero_ew.cur`n"
    . "UpArrow=%SystemRoot%\cursors\aero_up.cur`n"
    . "Wait=%SystemRoot%\cursors\aero_busy.ani`n"
    . "DefaultValue=Windows Default`n"
    . "DefaultValue.MUI=@main.cpl,-1020`n"
    . "`n"
    . "[Control Panel\Desktop]`n"
    . "Wallpaper=%SystemRoot%\web\wallpaper\Windows\img0.jpg`n"
    . "TileWallpaper=0`n"
    . "WallpaperStyle=10`n"
    . "Pattern=`n"
    . "`n"
    . "[VisualStyles]`n"
    . "Path=%ResourceDir%\Themes\Aero\Aero.msstyles`n"
    . "ColorStyle=NormalColor`n"
    . "Size=NormalSize`n"
    . "AutoColorization=0`n"
    . "ColorizationColor=0XC40078D7`n"
    . "SystemMode=Dark`n"
    . "AppMode=Dark`n"
    . "`n"
    . "[boot]`n"
    . "SCRNSAVE.EXE=`n"
    . "`n"
    . "[MasterThemeSelector]`n"
    . "MTSM=RJSPBS`n"
    . "`n"
    . "[Sounds]`n"
    . "; IDS_SCHEME_DEFAULT`n"
    . "SchemeName=@%SystemRoot%\System32\mmres.dll,-800"

midnightThemeFile := "[Theme]`n"
    . "; Windows - IDS_THEME_DISPLAYNAME_AERO`n"
    . "DisplayName=Midnight Theme`n"
    . "ThemeId={09FBF740-B58E-4297-AFDE-F7F599CAB875}`n"
    . "`n"
    . "; Computer - SHIDI_SERVER`n"
    . "[CLSID\{20D04FE0-3AEA-1069-A2D8-08002B30309D}\DefaultIcon]`n"
    . "DefaultValue=%SystemRoot%\System32\imageres.dll,-109`n"
    . "`n"
    . "; UsersFiles - SHIDI_USERFILES`n"
    . "[CLSID\{59031A47-3F72-44A7-89C5-5595FE6B30EE}\DefaultIcon]`n"
    . "DefaultValue=%SystemRoot%\System32\imageres.dll,-123`n"
    . "`n"
    . "; Network - SHIDI_MYNETWORK`n"
    . "[CLSID\{F02C1A0D-BE21-4350-88B0-7367FC96EF3C}\DefaultIcon]`n"
    . "DefaultValue=%SystemRoot%\System32\imageres.dll,-25`n"
    . "`n"
    . "; Recycle Bin - SHIDI_RECYCLERFULL SHIDI_RECYCLER`n"
    . "[CLSID\{645FF040-5081-101B-9F08-00AA002F954E}\DefaultIcon]`n"
    . "Full=%SystemRoot%\System32\imageres.dll,-54`n"
    . "Empty=%SystemRoot%\System32\imageres.dll,-55`n"
    . "`n"
    . "[Control Panel\Cursors]`n"
    . "AppStarting=%SystemRoot%\cursors\aero_working.ani`n"
    . "Arrow=%SystemRoot%\cursors\aero_arrow.cur`n"
    . "Crosshair=`n"
    . "Hand=%SystemRoot%\cursors\aero_link.cur`n"
    . "Help=%SystemRoot%\cursors\aero_helpsel.cur`n"
    . "IBeam=`n"
    . "No=%SystemRoot%\cursors\aero_unavail.cur`n"
    . "NWPen=%SystemRoot%\cursors\aero_pen.cur`n"
    . "SizeAll=%SystemRoot%\cursors\aero_move.cur`n"
    . "SizeNESW=%SystemRoot%\cursors\aero_nesw.cur`n"
    . "SizeNS=%SystemRoot%\cursors\aero_ns.cur`n"
    . "SizeNWSE=%SystemRoot%\cursors\aero_nwse.cur`n"
    . "SizeWE=%SystemRoot%\cursors\aero_ew.cur`n"
    . "UpArrow=%SystemRoot%\cursors\aero_up.cur`n"
    . "Wait=%SystemRoot%\cursors\aero_busy.ani`n"
    . "DefaultValue=Windows Default`n"
    . "`n"
    . "[Control Panel\Desktop]`n"
    . "Wallpaper=`n"
    . "Pattern=`n"
    . "MultimonBackgrounds=0`n"
    . "PicturePosition=4`n"
    . "`n"
    . "[VisualStyles]`n"
    . "Path=%SystemRoot%\resources\themes\Aero\AeroLite.msstyles`n"
    . "ColorStyle=NormalColor`n"
    . "Size=NormalSize`n"
    . "AutoColorization=0`n"
    . "ColorizationColor=0XC4000000`n"
    . "SystemMode=Dark`n"
    . "AppMode=Dark`n"
    . "VisualStyleVersion=10`n"
    . "HighContrast=3`n"
    . "`n"
    . "[boot]`n"
    . "SCRNSAVE.EXE=`n"
    . "`n"
    . "[MasterThemeSelector]`n"
    . "MTSM=RJSPBS`n"
    . "`n"
    . "[Sounds]`n"
    . "; IDS_SCHEME_DEFAULT`n"
    . "SchemeName=@mmres.dll,-800`n"
    . "`n"
    . "[Control Panel\Colors]`n"
    . "ActiveBorder=0`n"
    . "ActiveTitle=0`n"
    . "AppWorkspace=0`n"
    . "Background=0`n"
    . "ButtonAlternateFace=0`n"
    . "ButtonDkShadow=0`n"
    . "ButtonFace=0`n"
    . "ButtonHilight=0`n"
    . "ButtonLight=0`n"
    . "ButtonShadow=0`n"
    . "ButtonText=197 200 198`n"
    . "GradientActiveTitle=0`n"
    . "GradientlnactiveTitle=0`n"
    . "GrayText=105 101 101`n"
    . "Hilight=64 61 61`n"
    . "HilightText=227 229 228`n"
    . "HotTrackingColor=240 176 0`n"
    . "InactiveBorder=0`n"
    . "InactiveTitle=0`n"
    . "InactiveTitleText=197 200 198`n"
    . "InfoText=197 200 198`n"
    . "InfoWindow=0`n"
    . "Menu=0`n"
    . "MenuBar=0`n"
    . "MenuHilight=35 34 34`n"
    . "MenuText=197 200 198`n"
    . "Scrollbar=0`n"
    . "TitleText=197 200 198`n"
    . "Window=0`n"
    . "WindowFrame=0`n"
    . "WindowText=197 200 198"

twilightThemeFile := "[Theme]`n"
    . "; Windows - IDS_THEME_DISPLAYNAME_AERO`n"
    . "DisplayName=Twilight Theme`n"
    . "ThemeId={09FBF740-B58E-4297-AFDE-F7F599CAB875}`n"
    . "`n"
    . "; Computer - SHIDI_SERVER`n"
    . "[CLSID\{20D04FE0-3AEA-1069-A2D8-08002B30309D}\DefaultIcon]`n"
    . "DefaultValue=%SystemRoot%\System32\imageres.dll,-109`n"
    . "`n"
    . "; UsersFiles - SHIDI_USERFILES`n"
    . "[CLSID\{59031A47-3F72-44A7-89C5-5595FE6B30EE}\DefaultIcon]`n"
    . "DefaultValue=%SystemRoot%\System32\imageres.dll,-123`n"
    . "`n"
    . "; Network - SHIDI_MYNETWORK`n"
    . "[CLSID\{F02C1A0D-BE21-4350-88B0-7367FC96EF3C}\DefaultIcon]`n"
    . "DefaultValue=%SystemRoot%\System32\imageres.dll,-25`n"
    . "`n"
    . "; Recycle Bin - SHIDI_RECYCLERFULL SHIDI_RECYCLER`n"
    . "[CLSID\{645FF040-5081-101B-9F08-00AA002F954E}\DefaultIcon]`n"
    . "Full=%SystemRoot%\System32\imageres.dll,-54`n"
    . "Empty=%SystemRoot%\System32\imageres.dll,-55`n"
    . "`n"
    . "[Control Panel\Cursors]`n"
    . "AppStarting=%SystemRoot%\cursors\aero_working.ani`n"
    . "Arrow=%SystemRoot%\cursors\aero_arrow.cur`n"
    . "Crosshair=`n"
    . "Hand=%SystemRoot%\cursors\aero_link.cur`n"
    . "Help=%SystemRoot%\cursors\aero_helpsel.cur`n"
    . "IBeam=`n"
    . "No=%SystemRoot%\cursors\aero_unavail.cur`n"
    . "NWPen=%SystemRoot%\cursors\aero_pen.cur`n"
    . "SizeAll=%SystemRoot%\cursors\aero_move.cur`n"
    . "SizeNESW=%SystemRoot%\cursors\aero_nesw.cur`n"
    . "SizeNS=%SystemRoot%\cursors\aero_ns.cur`n"
    . "SizeNWSE=%SystemRoot%\cursors\aero_nwse.cur`n"
    . "SizeWE=%SystemRoot%\cursors\aero_ew.cur`n"
    . "UpArrow=%SystemRoot%\cursors\aero_up.cur`n"
    . "Wait=%SystemRoot%\cursors\aero_busy.ani`n"
    . "DefaultValue=Windows Default`n"
    . "`n"
    . "[Control Panel\Desktop]`n"
    . "Wallpaper=`n"
    . "Pattern=`n"
    . "MultimonBackgrounds=0`n"
    . "PicturePosition=4`n"
    . "`n"
    . "[VisualStyles]`n"
    . "Path=%SystemRoot%\resources\themes\Aero\AeroLite.msstyles`n"
    . "ColorStyle=NormalColor`n"
    . "Size=NormalSize`n"
    . "AutoColorization=0`n"
    . "ColorizationColor=0XC4000000`n"
    . "SystemMode=Dark`n"
    . "AppMode=Dark`n"
    . "VisualStyleVersion=10`n"
    . "HighContrast=3`n"
    . "`n"
    . "[boot]`n"
    . "SCRNSAVE.EXE=`n"
    . "`n"
    . "[MasterThemeSelector]`n"
    . "MTSM=RJSPBS`n"
    . "`n"
    . "[Sounds]`n"
    . "; IDS_SCHEME_DEFAULT`n"
    . "SchemeName=@mmres.dll,-800`n"
    . "`n"
    . "[Control Panel\Colors]`n"
    . "ActiveBorder=0`n"
    . "ActiveTitle=0`n"
    . "AppWorkspace=0`n"
    . "Background=0`n"
    . "ButtonAlternateFace=0`n"
    . "ButtonDkShadow=0`n"
    . "ButtonFace=0`n"
    . "ButtonHilight=0`n"
    . "ButtonLight=0`n"
    . "ButtonShadow=0`n"
    . "ButtonText=48 50 140`n"
    . "GradientActiveTitle=0`n"
    . "GradientlnactiveTitle=0`n"
    . "GrayText=105 101 101`n"
    . "Hilight=8 8 22`n"
    . "HilightText=72 75 192`n"
    . "HotTrackingColor=72 75 192`n"
    . "InactiveBorder=0`n"
    . "InactiveTitle=0`n"
    . "InactiveTitleText=48 50 140`n"
    . "InfoText=48 50 140`n"
    . "InfoWindow=0`n"
    . "Menu=0`n"
    . "MenuBar=0`n"
    . "MenuHilight=35 34 34`n"
    . "MenuText=48 50 140`n"
    . "Scrollbar=0`n"
    . "TitleText=48 50 140`n"
    . "Window=0`n"
    . "WindowFrame=0`n"
    . "WindowText=48 50 140"

    name := StrReplace(radio.Name, "Theme")
    themeFileName := name " Theme.theme"
    themeFilePath := A_ScriptDir "\" themeFileName

    FileExist(themeFilePath) ? Run(themeFilePath) 
                              : (FileAppend(%name%ThemeFile, themeFilePath), Run(themeFilePath))

    if (WinWaitActive("Settings ahk_class ApplicationFrameWindow"))
        WinClose()
}

ResetSettings(chkbx, *)
{
    global  

    SetTimer(PleaseWaitNotification, 50)

    ; Reset Dimmers
    if (n := Integer(SubStr(chkbx.Name, -1)))
    {
        overlay[n].Hide() 
        dimmerTitle[n].Value := "Dimmer (Overlay):`t" (dimmer[n].Value := 0) "%"
    }
    else
    {
        dimmer[0].Value := 0, dimmerTitle[0].Value := "Dimmer (Overlay):`t" 0 "%"
        i := 0
        while ((i := A_Index) <= monitorCount)
        {
            overlay[i].Hide(), dimmerTitle[i].Value := "Dimmer (Overlay):`t" (dimmer[i].Value := 0) "%"
        }
    }

    ; Reset Gamma
    try
    {
        if (n := Integer(SubStr(chkbx.Name, -1)))
        {
            mon.SetGammaRamp(gammaAll[n].Value := gammaRed[n].Value := 100, gammaGreen[n].Value := 100, gammaBlue[n].Value := 100, n)
            ResetSettingsCtrl[n].Value := 0
            for color in ["All", "Red", "Green", "Blue"]
                gamma%color%Title[0].Value := gamma%color%Title[n].Value := "Gamma (" color "):" (color = "Green" ? "`t" : "`t`t") " 100%"
        }
        else
        {
            ResetSettingsCtrl[0].Value := 0  
            gammaAll[0].Value := gammaRed[0].Value := gammaGreen[0].Value := gammaBlue[0].Value := 100 
            i := 0
            while ((i := A_Index) <= monitorCount)
            {
                mon.SetGammaRamp(gammaAll[i].Value := gammaRed[i].Value := 100, gammaGreen[i].Value := 100, gammaBlue[i].Value := 100, i)  
                for color in ["All", "Red", "Green", "Blue"]
                    gamma%color%Title[0].Value := gamma%color%Title[i].Value := "Gamma (" color "):" (color = "Green" ? "`t" : "`t`t") " 100%"
            }
        }
    }

    ; Reset Brightness and Contrast
    try       
    {
        if (mon.RestoreFactoryDefaults(i)) 
        {
            if (n := Integer(SubStr(chkbx.Name, -1)))
            {
                mon.RestoreFactoryDefaults(n)
                ResetSettingsCtrl[n].Value := 0 
                Sleep(1000)
                brightnessTitle[n].Value := "Brightness:`t`t" mon.GetBrightness(n)["Current"] "%"
                Sleep(1000)
                contrastTitle[n].Value   := "Contrast:`t`t" mon.GetContrast(n)["Current"] "%"
                Sleep(1000)
            }
            else
            {
                ResetSettings[0].Value := 0 
                i := 0
                while ((i := A_Index) <= monitorCount)
                {
                    mon.RestoreFactoryDefaults(i)  
                    Sleep(1000)
                    brightnessTitle[0].Value := brightnessTitle[i].Value := "Brightness:`t`t" (brightness[0].Value := brightness[i].Value := mon.GetBrightness(i)["Current"]) "%"
                    Sleep(1000)
                    contrastTitle[0].Value := contrastTitle[i].Value := "Contrast:`t`t" (contrast[0].Value := contrast[i].Value := mon.GetContrast(i)["Current"]) "%"
                    Sleep(1000)
                }
            }
        }        
    }

    n ? (SetTimer(PleaseWaitNotification, 0), ToolTip(), MsgBox("Monitor " n " restored to factory settings!", A_IconTip, "T6"))
      : (SetTimer(PleaseWaitNotification, 0), ToolTip(), MsgBox("All monitors restored to factory settings!" , A_IconTip, "T6"))
            
    PleaseWaitNotification()
    {
        ToolTip("Please Wait....")
    }
}