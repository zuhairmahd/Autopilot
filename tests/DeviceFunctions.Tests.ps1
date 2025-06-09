$script:modulePath = Join-Path $PSScriptRoot '..' 'functions' 'DeviceFunctions.ps1'
$expectedFunctions = Select-String -Path $modulePath -Pattern '^[Ff]function\s+([^\s(]+)' | ForEach-Object { $_.Matches[0].Groups[1].Value }
Describe 'DeviceFunctions.ps1' {
    BeforeAll { . $modulePath }
    foreach ($func in $expectedFunctions) {
        It "defines $func" {
            Get-Command $func -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
    }
}
