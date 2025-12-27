#Requires AutoHotkey v1.1
#NoEnv
#SingleInstance, Force
#Persistent
SetWorkingDir %A_ScriptDir%

prevBiome := ""
isRunning := false
iniFilePath := A_ScriptDir "\settings.ini"
EnvGet, LocalAppData, LOCALAPPDATA

; ================= BIOME DATA =================
biomeColors := { "NORMAL":16777215, "SAND STORM":16040572, "HELL":6033945
, "STARFALL":6784224, "CORRUPTION":9454335, "NULL":0
, "WINDY":9566207, "SNOWY":12908022
, "RAINY":4425215, "DREAMSPACE":16743935, "PUMPKIN MOON":13983497
, "GRAVEYARD":16777215, "BLOOD RAIN":16711680
, "CYBERSPACE":2904999, "GLITCH":657930 }

; Rare biomes that trigger @everyone
rareBiomes := { "CYBERSPACE":1, "BLOOD RAIN":1, "GLITCH":1, "DREAMSPACE":1 }

; ================= GUI =================
Gui, Font, s10, Segoe UI
Gui, +AlwaysOnTop
Gui, Add, Button, w100 gStart, ▶ Start
Gui, Add, Button, x+10 w100 gStop, ■ Stop
Gui, Add, Text, xm y+20 vStatus w280, Status: Idle
Gui, Show, w320 h120, Mika's Biome Detector V1.2.0
return

; ================= START =================
Start:
    IniRead, webhookURL, %iniFilePath%, Macro, webhookURL
    if !InStr(webhookURL, "discord")
    {
        InputBox, webhookURL, Discord Webhook, Paste your Discord webhook URL:
        if ErrorLevel
            return
        IniWrite, %webhookURL%, %iniFilePath%, Macro, webhookURL
    }

    IniRead, privateServerLink, %iniFilePath%, Biomes, privateServerLink
    if (privateServerLink = "" || privateServerLink = "ERROR")
    {
        InputBox, privateServerLink, Private Server, Paste your private server link:
        if ErrorLevel
            return
        IniWrite, %privateServerLink%, %iniFilePath%, Biomes, privateServerLink
    }

    prevBiome := ""
    isRunning := true
    GuiControl,, Status, Status: Monitoring for biome change
    SetTimer, CheckBiome, 1000
return

; ================= STOP =================
Stop:
    isRunning := false
    SetTimer, CheckBiome, Off
    GuiControl,, Status, Status: Stopped
return

; ================= SEND WEBHOOK =================
SendWebhook:
    IniRead, webhookURL, %iniFilePath%, Macro, webhookURL
    IniRead, privateServerLink, %iniFilePath%, Biomes, privateServerLink

    color := biomeColors.HasKey(biome) ? biomeColors[biome] : 16777215
    ping := rareBiomes.HasKey(biome) ? "@everyone" : ""
    thumb := "https://thenerdstash.com/wp-content/uploads/2024/03/roblox-sols-rng.jpg"

    json := "{"
    json .= """content"":""" ping ""","
    json .= """embeds"":[{"
    json .= """description"": ""> ### Biome Started - " biome
        . "\n> ### [Join Server](" privateServerLink ")"
        . "\n> *Mika's Biome Detector*"","
    json .= """color"":" color ","
    json .= """thumbnail"":{""url"":""" thumb """}"
    json .= "}]}" 

    http := ComObjCreate("WinHttp.WinHttpRequest.5.1")
    http.Open("POST", webhookURL, false)
    http.SetRequestHeader("Content-Type", "application/json")
    http.Send(json)

    GuiControl,, Status, Status: %biome%
return

GuiClose:
ExitApp

; ================= PROCESS CHECK =================
ProcessExist(name) {
    Process, Exist, %name%
    return ErrorLevel
}

; ================= BIOME DETECTION =================
CheckBiome:
    if !isRunning
        return
    if !ProcessExist("RobloxPlayerBeta.exe")
        return

    logDir := LocalAppData "\Roblox\logs"
    newest := "", newestTime := 0

    Loop, Files, %logDir%\*.log
        if (A_LoopFileTimeModified > newestTime)
            newest := A_LoopFileFullPath, newestTime := A_LoopFileTimeModified

    if !newest
        return

    file := FileOpen(newest, "r")
    if !file
        return

    if (file.Length > 8192)
        file.Seek(-8192, 2)

    data := file.Read()
    file.Close()

    lines := StrSplit(data, "`n")
    regex := """largeImage"":\{""hoverText"":""([^""]+)"""

    biome := ""
    Loop % lines.MaxIndex()
    {
        line := lines[lines.MaxIndex() - A_Index + 1]
        if InStr(line, "[BloxstrapRPC]") && RegExMatch(line, regex, m)
        {
            biome := m1
            break
        }
    }

    if (!biome || biome = prevBiome)
        return

    prevBiome := biome
    Gosub, SendWebhook
return
