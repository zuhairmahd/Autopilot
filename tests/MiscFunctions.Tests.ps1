$script:modulePath = Join-Path $PSScriptRoot '..' 'functions' 'MiscFunctions.ps1'
$settings = @{ domain = 'example.com' }
$expectedFunctions = Select-String -Path $modulePath -Pattern '^[Ff]function\s+([^\s(]+)' | ForEach-Object { $_.Matches[0].Groups[1].Value }
Describe 'MiscFunctions.ps1' {
    BeforeAll { . $modulePath }
    foreach ($func in $expectedFunctions) {
        It "defines $func" {
            Get-Command $func -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
    }
    It 'NormalizeUserName appends domain' {
        NormalizeUserName -UserName 'user' -Settings $settings | Should -Be 'user@example.com'
    }
}
