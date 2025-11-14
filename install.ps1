# -----------------------------
# PerformanceSuite-Windows Installer
# Repository: https://github.com/Luzifer-Black/PerformanceSuite-Windows
# -----------------------------
Write-Host "PerformanceSuite-Windows Installer gestartet..." -ForegroundColor Cyan

$BasePath = "$env:ProgramData\PerformanceSuite-Windows"
$ScriptPath = "$BasePath\Scripts"
$OHMPath = "$BasePath\OHM"
$ConfigPath = "$BasePath\Config"

New-Item -ItemType Directory -Force -Path $BasePath, $ScriptPath, $OHMPath, $ConfigPath | Out-Null

# OpenHardwareMonitor herunterladen
$ohmUrl = "https://openhardwaremonitor.org/files/openhardwaremonitor-v0.9.6.zip"
$ohmZip = "$OHMPath\ohm.zip"
Invoke-WebRequest $ohmUrl -OutFile $ohmZip
Expand-Archive $ohmZip -DestinationPath $OHMPath -Force
Remove-Item $ohmZip

# AutoUpdate.ps1 erzeugen
@"
# AutoUpdate.ps1
param()
try {
    Write-Host "Prüfe Updates..." -ForegroundColor Yellow
    $latestVersion = Invoke-WebRequest "https://raw.githubusercontent.com/Luzifer-Black/PerformanceSuite-Windows/main/version.txt" -UseBasicParsing
    $localVersion = Get-Content "$ConfigPath\version.txt"

    if ($latestVersion.Content -ne $localVersion) {
        Write-Host "Update gefunden. Installiere..." -ForegroundColor Green
        Invoke-WebRequest "https://raw.githubusercontent.com/Luzifer-Black/PerformanceSuite-Windows/main/PerformanceSuite-Windows.ps1" -OutFile "$ScriptPath\PerformanceSuite-Windows.ps1"
        Set-Content -Path "$ConfigPath\version.txt" -Value $latestVersion.Content
        Write-Host "Update abgeschlossen!"
    }
}
catch { Write-Host "Update fehlgeschlagen." -ForegroundColor Red }
"@ | Set-Content "$ScriptPath\AutoUpdate.ps1"

# Hauptskript speichern
Invoke-WebRequest "https://raw.githubusercontent.com/Luzifer-Black/PerformanceSuite-Windows/main/PerformanceSuite-Windows.ps1" -OutFile "$ScriptPath\PerformanceSuite-Windows.ps1"

# README GUI
Invoke-WebRequest "https://raw.githubusercontent.com/Luzifer-Black/PerformanceSuite-Windows/main/ShowReadme.ps1" -OutFile "$ScriptPath\ShowReadme.ps1"

# Version Datei
Invoke-WebRequest "https://raw.githubusercontent.com/Luzifer-Black/PerformanceSuite-Windows/main/version.txt" -OutFile "$ConfigPath\version.txt"

# Autostart einrichten
$Task = @{
    TaskName = "PerformanceSuite-Windows"
    Trigger = New-ScheduledTaskTrigger -AtLogOn
    Action  = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-ExecutionPolicy Bypass -File `"$ScriptPath\PerformanceSuite-Windows.ps1`""
    RunLevel = "Highest"
}
Register-ScheduledTask @Task -Force | Out-Null

Write-Host "Installation abgeschlossen!" -ForegroundColor Green
Start-Process "powershell.exe" -Argument "-ExecutionPolicy Bypass -File `"$ScriptPath\PerformanceSuite-Windows.ps1`""
