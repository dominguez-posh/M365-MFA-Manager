@echo off
rem Starts the M365 MFA Administration Tool by double-click (Windows PowerShell 5.1).
rem -ExecutionPolicy Bypass applies to this process only and does not change any system setting.
rem -WindowStyle Hidden: no console window; the tool shows it briefly only during the sign-in (the Microsoft sign-in dialog belongs to it).
start "" powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "%~dp0Start-M365MfaTool.ps1" -HideConsole
