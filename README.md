PerformanceSuite-Windows - Quick Start Guide

1) Installation
   - Öffne PowerShell als Administrator.
   - Führe den Installer aus:
     powershell -ExecutionPolicy Bypass -Command "irm 'https://raw.githubusercontent.com/GitHub-Namen-Angeben/PerformanceSuite-Windows/main/install.ps1' | iex"

2) Was passiert:
   - OpenHardwareMonitor wird heruntergeladen.
   - Skripte werden in C:\ProgramData\PerformanceSuite-Windows\Scripts angelegt.
   - AutoUpdate eingerichtet.
   - Scheduled Task erstellt, startet das Hauptskript beim Login.

3) Hinweise:
   - MSI Afterburner für Overclocking-Profile (Profile1=default, Profile3=OC) empfohlen.
   - Lege EmptyStandbyList.exe in das BasePath (optional).
   - Prüfe Log: C:\ProgramData\PerformanceSuite-Windows\log.txt
