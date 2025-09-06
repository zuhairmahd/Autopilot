@echo off
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0register.ps1" -label 'win' -ignoreLabelIfOnlyOne %*