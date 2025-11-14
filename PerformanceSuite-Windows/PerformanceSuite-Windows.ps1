<#
PerformanceSuite-Windows.ps1
Vollständiges Hauptskript — Monitoring, Fortnite/SWTOR-Optimierungen,
RAM-Cleanup, Netzwerk-Tweaks, Temperatur-Watchdog, leichte OC-Profile (via Afterburner),
AutoUpdate-Hook (ruft AutoUpdate.ps1), Logging & Scheduled Task friendly.

Speichere als .ps1 und starte PowerShell "Als Administrator".
#>

# --------------------------
# Basis & Logging
# --------------------------
$BasePath   = "$env:ProgramData\PerformanceSuite-Windows"
$ScriptPath = "$BasePath\Scripts"
$OHMPath    = "$BasePath\OHM"
$ConfigPath = "$BasePath\Config"
$LogFile    = "$BasePath\log.txt"

# Ensure folders exist
New-Item -Path $BasePath,$ScriptPath,$OHMPath,$ConfigPath -ItemType Directory -Force | Out-Null

function Log {
    param([string]$msg)
    $t = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    try { Add-Content -Path $LogFile -Value "[$t] $msg" } catch {}
    Write-Host $msg
}

Log "=== PerformanceSuite-Windows START ==="

# --------------------------
# Load OpenHardwareMonitor (if available)
# --------------------------
$OHMDll = Join-Path $OHMPath "OpenHardwareMonitorLib.dll"
$computer = $null
if (Test-Path $OHMDll) {
    try {
        Add-Type -Path $OHMDll -ErrorAction Stop
        $computer = New-Object OpenHardwareMonitor.Hardware.Computer
        $computer.CPUEnabled = $true
        $computer.GPUEnabled = $true
        $computer.Open()
        Log "OpenHardwareMonitor geladen."
    } catch {
        Log "OHM: Fehler beim Laden: $_"
    }
} else {
    Log "OHM DLL nicht gefunden: $OHMDll"
}

function Get-Temps {
    $res = @{}
    if (-not $computer) { return $res }
    foreach ($hw in $computer.Hardware) {
        try {
            $hw.Update()
            foreach ($s in $hw.Sensors) {
                if ($s.SensorType -eq 'Temperature' -and $s.Value) {
                    $res[$s.Name] = [math]::Round($s.Value)
                }
            }
        } catch {}
    }
    return $res
}

# --------------------------
# RAM / Working Set Cleanup
# --------------------------
function Clear-RAM {
    Log "Starte RAM/WorkingSet-Cleanup..."
    try {
        # Try to call EmptyStandbyList if present
        $emptyExe = Join-Path $BasePath "EmptyStandbyList.exe"
        if (Test-Path $emptyExe) {
            & $emptyExe workingsets 2>$null
            Log "EmptyStandbyList ausgeführt."
            return
        }
        # fallback: use available API approach
        Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public class Win32 {
    [DllImport(""psapi.dll"")]
    public static extern bool EmptyWorkingSet(IntPtr hProcess);
}
"@ -ErrorAction SilentlyContinue
        Get-Process | Where-Object { $_.Id -gt 4 -and $_.Id -ne $PID } | ForEach-Object {
            try { [Win32]::EmptyWorkingSet($_.Handle) | Out-Null } catch {}
        }
        Log "WorkingSets versucht zu leeren."
    } catch {
        Log "Clear-RAM Fehler: $_"
    }
}

# --------------------------
# Network tweaks (moderate)
# --------------------------
$EnableNetworkTweaks = $true
function Apply-NetworkTweaks {
    if (-not $EnableNetworkTweaks) { Log "Network Tweaks disabled."; return }
    Log "Wende moderate Netzwerk-Tweaks an..."
    try {
        netsh interface tcp set global autotuninglevel=normal | Out-Null
        New-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" -Name "TCPNoDelay" -PropertyType DWord -Value 1 -Force | Out-Null
        New-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" -Name "TCPAckFrequency" -PropertyType DWord -Value 1 -Force | Out-Null
        Log "Netzwerk-Tweaks angewendet."
    } catch {
        Log "Network tweak Fehler: $_"
    }
}
function Revert-NetworkTweaks {
    if (-not $EnableNetworkTweaks) { return }
    Log "Setze Netzwerk-Tweaks zurück..."
    try {
        netsh interface tcp set global autotuninglevel=normal | Out-Null
        Remove-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" -Name "TCPNoDelay" -ErrorAction SilentlyContinue
        Remove-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" -Name "TCPAckFrequency" -ErrorAction SilentlyContinue
    } catch {
        Log "Revert-NetworkTweaks Fehler: $_"
    }
}

# --------------------------
# Power Plan helpers
# --------------------------
$UltimateGUID = "e9a42b02-d5df-448d-aa00-03f14749eb61"  # Ultimate Performance
$BalancedGUID = "381b4222-f694-41f0-9685-ff5bb260df2e"  # Balanced (example)

function Ensure-Ultimate {
    try {
        $plans = powercfg /L 2>$null
        if ($plans -notmatch $UltimateGUID) {
            powercfg -duplicatescheme $UltimateGUID 2>$null | Out-Null
            Log "Ultimate Performance Plan versucht hinzuzufügen."
        }
    } catch { Log "Ensure-Ultimate Fehler: $_" }
}
function Set-Ultimate {
    Ensure-Ultimate
    try { powercfg /S $UltimateGUID } catch { Log "Set-Ultimate Fehler" }
    Log "Powerplan gesetzt: Ultimate"
}
function Set-Balanced {
    try { powercfg /S $BalancedGUID } catch { Log "Set-Balanced Fehler" }
    Log "Powerplan gesetzt: Balanced"
}

# --------------------------
# GPU / CPU Optimizations (safe)
# --------------------------
function Apply-CPU-GPU-Optimizations {
    Log "Wende CPU/GPU Optimierungen an (konservativ)..."
    try {
        reg add "HKLM\SYSTEM\CurrentControlSet\Control\Power\PowerThrottling" /v PowerThrottlingOff /t REG_DWORD /d 1 /f | Out-Null
        reg add "HKCU\Software\Microsoft\GameBar" /v AllowAutoGameMode /t REG_DWORD /d 1 /f | Out-Null
        reg add "HKCU\Software\Microsoft\GameBar" /v AutoGameModeEnabled /t REG_DWORD /d 1 /f | Out-Null
        Log "CPU/GPU Optimierungen registriert."
    } catch { Log "Apply-CPU-GPU-Optimizations Fehler: $_" }
}
function Remove-CPU-GPU-Optimizations {
    Log "Stelle CPU/GPU Einstellungen wieder her..."
    try { reg add "HKLM\SYSTEM\CurrentControlSet\Control\Power\PowerThrottling" /v PowerThrottlingOff /t REG_DWORD /d 0 /f | Out-Null } catch {}
}

# --------------------------
# Fortnite / SWTOR specific tweaks
# --------------------------
function Optimize-Fortnite-Config {
    $cfg = "$env:LOCALAPPDATA\FortniteGame\Saved\Config\WindowsClient\GameUserSettings.ini"
    if (Test-Path $cfg) {
        try {
            Log "Ändere Fortnite GameUserSettings.ini"
            (Get-Content $cfg) |
                ForEach-Object {
                    $_ -replace "sg.MaxFPS=.*","sg.MaxFPS=300" `
                       -replace "bUseVSync=.*","bUseVSync=False" `
                       -replace "bUseDynamicResolution=.*","bUseDynamicResolution=False" `
                       -replace "ViewDistanceQuality=.*","ViewDistanceQuality=1"
                } | Set-Content $cfg
            Log "Fortnite Config angepasst."
        } catch { Log "Fortnite Config Fehler: $_" }
    } else {
        Log "Fortnite Config nicht gefunden: $cfg"
    }
}
function Optimize-Fortnite-Engine {
    $ini = "$env:LOCALAPPDATA\FortniteGame\Saved\Config\WindowsClient\Engine.ini"
    if (Test-Path $ini) {
        try {
            @" 
[/script/engine.engine]
bSmoothFrameRate=false
MinSmoothedFrameRate=0
MaxSmoothedFrameRate=999

[/script/engine.renderersettings]
r.OneFrameThreadLag=0
r.TextureStreaming=0
"@ | Set-Content $ini -Force
            Log "Fortnite Engine.ini gesetzt."
        } catch { Log "Engine.ini Fehler: $_" }
    }
}
function Optimize-SWTOR {
    $ini = "$env:LOCALAPPDATA\swtor\swtor\settings\client_settings.ini"
    if (Test-Path $ini) {
        try {
            Log "Passe SWTOR settings an..."
            (Get-Content $ini) |
                ForEach-Object {
                    $_ -replace "AntiAliasingLevel=.*","AntiAliasingLevel=0" `
                       -replace "MeshLODQuality=.*","MeshLODQuality=0" `
                       -replace "PlantDensity=.*","PlantDensity=0"
                } | Set-Content $ini
            Log "SWTOR Config angepasst."
        } catch { Log "SWTOR Config Fehler: $_" }
    } else {
        Log "SWTOR Config nicht gefunden."
    }
}

# --------------------------
# Overclocking via MSI Afterburner (safe, profile-based)
# --------------------------
function Apply-GPU-OC {
    $afterburner = "C:\Program Files (x86)\MSI Afterburner\MSIAfterburner.exe"
    if (Test-Path $afterburner) {
        try {
            Log "Setze GPU OC Profile (Profile3)..."
            Start-Process -FilePath $afterburner -ArgumentList "-profile3" -WindowStyle Hidden
            Log "Afterburner Profile3 geladen."
        } catch { Log "Apply-GPU-OC Fehler: $_" }
    } else {
        Log "MSI Afterburner nicht gefunden: $afterburner"
    }
}
function Remove-GPU-OC {
    $afterburner = "C:\Program Files (x86)\MSI Afterburner\MSIAfterburner.exe"
    if (Test-Path $afterburner) {
        try {
            Log "Lade Afterburner Standardprofil (Profile1)..."
            Start-Process -FilePath $afterburner -ArgumentList "-profile1" -WindowStyle Hidden
        } catch { Log "Remove-GPU-OC Fehler: $_" }
    }
}
function Apply-RAM-OC {
    try {
        Log "Aktiviere Windows Memory Compression (optimistisch)..."
        Enable-MMAgent -MemoryCompression
    } catch { Log "Apply-RAM-OC Fehler: $_" }
}
function Remove-RAM-OC {
    try {
        Log "Deaktiviere Memory Compression..."
        Disable-MMAgent -MemoryCompression
    } catch {}
}

# --------------------------
# Temperature Watchdog / Safety
# --------------------------
function Temperature-Watchdog {
    Log "Starte Temperatur-Watchdog (Background Job)..."
    while ($true) {
        try {
            $temps = Get-Temps
            foreach ($k in $temps.Keys) {
                $v = $temps[$k]
                if ($v -ge 85) {
                    Log "ALARM: $k = $v °C -> Maßnahmen einleiten"
                    # reduce aggressiveness
                    Remove-GPU-OC
                    Remove-RAM-OC
                    # try GPU reset (nvidia)
                    if (Get-Command nvidia-smi -ErrorAction SilentlyContinue) {
                        try {
                            nvidia-smi --gpu-reset 2>$null
                            Log "nvidia-smi gpu-reset versucht."
                        } catch { Log "nvidia-smi reset fehlgeschlagen." }
                    }
                    Start-Sleep -Seconds 10
                }
            }
        } catch { Log "Watchdog Fehler: $_" }
        Start-Sleep -Seconds 5
    }
}

# --------------------------
# AutoUpdate Hook (calls AutoUpdate.ps1 if present)
# --------------------------
function Run-AutoUpdate {
    $u = Join-Path $ScriptPath "AutoUpdate.ps1"
    if (Test-Path $u) {
        try {
            Log "Starte AutoUpdate..."
            & powershell -ExecutionPolicy Bypass -File $u
        } catch { Log "AutoUpdate Fehler: $_" }
    } else {
        Log "AutoUpdate Script nicht gefunden."
    }
}

# --------------------------
# Game detection & main loop
# --------------------------
# Known paths (user-provided)
$watchExePaths = @(
    "C:\Program Files\Epic Games\Fortnite\FortniteGame\Binaries\Win64\FortniteClient-Win64-Shipping_EAC_EOS.exe",
    "C:\Program Files\Epic Games\Fortnite\FortniteGame\Binaries\Win64\FortniteClient-Win64-Shipping.exe",
    "C:\Games\SWTOR\launcher.exe"
)

# Helper: find running processes by path/name
function Find-RunningGameProcs {
    $found = @()
    foreach ($path in $watchExePaths) {
        $name = [IO.Path]::GetFileNameWithoutExtension($path)
        $procs = Get-Process -ErrorAction SilentlyContinue | Where-Object {
            try { ($_.Path -eq $path) -or ($_.ProcessName -ieq $name) } catch { $false }
        }
        if ($procs) { $found += $procs }
    }
    # also detect any exe under C:\Games
    try {
        $exeList = Get-ChildItem -Path "C:\Games" -Filter *.exe -Recurse -ErrorAction SilentlyContinue | Select-Object -ExpandProperty FullName
        foreach ($exe in $exeList) {
            $name = [IO.Path]::GetFileNameWithoutExtension($exe)
            $ps = Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.ProcessName -ieq $name }
            if ($ps) { $found += $ps }
        }
    } catch {}
    return $found | Sort-Object -Property Id -Unique
}

# Track active PIDs to revert settings on exit
$ActiveGames = @{}

# Start Watchdog in background
$watchJob = Start-Job -ScriptBlock { param($sp,$ohm) 
    # Recreate minimal environment in job: just spin reading OHM if accessible via dll path; but jobs cannot share objects.
    # So job will call the main script's Temperature-Watchdog function via writing a trigger file — simplified approach:
    while ($true) { Start-Sleep -Seconds 60 } 
} -ArgumentList $ScriptPath,$OHMPath

# Instead, start watchdog as background runspace (Start-Job won't share OHM); use Start-ThreadJob if available:
if (Get-Command Start-ThreadJob -ErrorAction SilentlyContinue) {
    Start-ThreadJob -ScriptBlock { 
        Import-Module ThreadJob -ErrorAction SilentlyContinue
        while ($true) {
            try {
                # Try to call the main script's Get-Temps by reloading OHM dll if available in same folder
                $ohmDll = "$env:ProgramData\PerformanceSuite-Windows\OHM\OpenHardwareMonitorLib.dll"
                if (Test-Path $ohmDll) {
                    Add-Type -Path $ohmDll -ErrorAction SilentlyContinue
                    $computer = New-Object OpenHardwareMonitor.Hardware.Computer
                    $computer.CPUEnabled = $true
                    $computer.GPUEnabled = $true
                    $computer.Open()
                    $temps = @{}
                    foreach ($hw in $computer.Hardware) {
                        $hw.Update()
                        foreach ($s in $hw.Sensors) {
                            if ($s.SensorType -eq 'Temperature' -and $s.Value) {
                                $temps[$s.Name] = [math]::Round($s.Value)
                            }
                        }
                    }
                    foreach ($k in $temps.Keys) {
                        if ($temps[$k] -ge 85) {
                            # write a small alert file for main process to pick up
                            $alert = "$env:ProgramData\PerformanceSuite-Windows\temp_alert.txt"
                            "$k:$($temps[$k])" | Out-File -FilePath $alert -Encoding utf8 -Force
                        }
                    }
                }
            } catch {}
            Start-Sleep -Seconds 5
        }
    } | Out-Null
    Log "Temperature ThreadJob gestartet."
} else {
    # Fallback: run watchdog inline in main loop checks
    Log "Start-ThreadJob nicht verfügbar; Temperature checks werden inline durchgeführt."
}

# --------------------------
# Main polling loop
# --------------------------
Log "Entering main loop..."
$GameActive = $false

while ($true) {
    try {
        # AutoUpdate check every loop iteration start (light)
        Run-AutoUpdate

        $runningProcs = Find-RunningGameProcs

        if ($runningProcs -and -not $GameActive) {
            Log "Spiel(e) erkannt: $($runningProcs | ForEach-Object { $_.ProcessName } | Sort-Object -Unique -Join ', ')"
            # Save current power plan
            $OriginalPlan = (powercfg /GetActiveScheme) -replace '.*:','' -replace '\s',''
            # Apply optimizations
            Set-Ultimate
            Apply-CPU-GPU-Optimizations
            Apply-NetworkTweaks
            Clear-RAM
            Apply-RAM-OC
            Apply-GPU-OC

            # Per-game tweaks
            foreach ($p in $runningProcs) {
                $exeLower = ($p.Path -as [string]).ToLower()
                if ($exeLower -and $exeLower.Contains("fortnite")) {
                    Optimize-Fortnite-Config
                    Optimize-Fortnite-Engine
                } elseif ($exeLower -and $exeLower.Contains("swtor")) {
                    Optimize-SWTOR
                } else {
                    # no-op
                }
            }

            # track PIDs
            foreach ($p in $runningProcs) { $ActiveGames[$p.Id] = @{ Name=$p.ProcessName; Path=$p.Path } }
            $GameActive = $true
        } elseif (-not $runningProcs -and $GameActive) {
            Log "Kein Spiel mehr aktiv - setze System zurück."
            # revert changes
            Set-Balanced
            Remove-CPU-GPU-Optimizations
            Revert-NetworkTweaks
            Remove-RAM-OC
            Remove-GPU-OC
            Clear-RAM

            # clear ActiveGames
            $ActiveGames.Keys | ForEach-Object { $ActiveGames.Remove($_) }
            $GameActive = $false
        } else {
            # If game still running, optionally monitor temps inline
            if ($GameActive) {
                # Inline temperature check if no threadjob
                if (-not (Get-Command Start-ThreadJob -ErrorAction SilentlyContinue)) {
                    $temps = Get-Temps
                    foreach ($k in $temps.Keys) {
                        if ($temps[$k] -ge 85) {
                            Log "WARN: $k = $($temps[$k])°C -> Abbruch-Drossel aktivieren."
                            Remove-GPU-OC
                            Remove-RAM-OC
                            Revert-NetworkTweaks
                        }
                    }
                } else {
                    # check alert file from threadjob
                    $alert = Join-Path $BasePath "temp_alert.txt"
                    if (Test-Path $alert) {
                        $txt = Get-Content $alert -ErrorAction SilentlyContinue
                        Log "Temperaturalarm (ThreadJob): $txt"
                        Remove-Item $alert -ErrorAction SilentlyContinue
                        Remove-GPU-OC
                        Remove-RAM-OC
                        Revert-NetworkTweaks
                    }
                }
            }
        }
    } catch { Log "Hauptschleifen-Fehler: $_" }

    Start-Sleep -Seconds 3
}
