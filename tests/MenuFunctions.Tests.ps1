$script:modulePath = Join-Path $PSScriptRoot '..' 'functions' 'MenuFunctions.ps1'
$expectedFunctions = Select-String -Path $modulePath -Pattern '^[Ff]unction\s+([^(\s]+)' | ForEach-Object { $_.Matches[0].Groups[1].Value }
Describe 'MenuFunctions.ps1' {
    BeforeAll { . $modulePath }
    foreach ($func in $expectedFunctions) {
        It "defines $func" {
            Get-Command $func -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
    }
}
