# AutoUpdate.ps1
param()
try {
    Write-Host "Prüfe Updates..." -ForegroundColor Yellow
    $latestVersion = Invoke-WebRequest "https://raw.githubusercontent.com/Luzifer-Black/PerformanceSuite-Windows/main/version.txt" -UseBasicParsing
    $localVersionFile = "$env:ProgramData\PerformanceSuite-Windows\Config\version.txt"
    if (-not (Test-Path $localVersionFile)) { "0.0.0" | Out-File $localVersionFile }
    $localVersion = Get-Content $localVersionFile -ErrorAction SilentlyContinue

    if ($latestVersion.Content.Trim() -ne $localVersion.Trim()) {
        Write-Host "Update gefunden. Lade neue Version..." -ForegroundColor Green
        Invoke-WebRequest "https://raw.githubusercontent.com/Luzifer-Black/PerformanceSuite-Windows/main/PerformanceSuite-Windows.ps1" -OutFile "$env:ProgramData\PerformanceSuite-Windows\Scripts\PerformanceSuite-Windows.ps1" -UseBasicParsing -ErrorAction Stop
        $latestVersion.Content.Trim() | Out-File $localVersionFile -Force
        Write-Host "Update installiert!"
    } else {
        Write-Host "Keine Updates gefunden."
    }
}
catch { Write-Host "Update fehlgeschlagen: $_" -ForegroundColor Red }
