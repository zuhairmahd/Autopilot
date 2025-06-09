$module = Join-Path $HOME '.local/share/powershell/Modules/Pester5/Pester.psd1'
Import-Module $module -ErrorAction Stop
Invoke-Pester -Path $PSScriptRoot
