Import-Module Pester -MinimumVersion 5.0 -Force
$config = New-PesterConfiguration
$config.Run.Path = '.\tests\Unit\Get-CachedData.Tests.ps1'
$config.Output.Verbosity = 'Detailed'
$config.Should.ErrorAction = 'Continue'
Invoke-Pester -Configuration $config
