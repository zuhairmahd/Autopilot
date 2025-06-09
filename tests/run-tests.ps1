Import-Module -name pester -ErrorAction Stop
Invoke-Pester -Path $PSScriptRoot
