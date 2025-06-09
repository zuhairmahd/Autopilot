$script:modulePath = Join-Path $PSScriptRoot '..' 'functions' 'JsonHelperFunctions.ps1'
$expectedFunctions = Select-String -Path $modulePath -Pattern '^[Ff]unction\s+([^(\s]+)' | ForEach-Object { $_.Matches[0].Groups[1].Value }
Describe 'JsonHelperFunctions.ps1' {
    BeforeAll { . $modulePath }
    foreach ($func in $expectedFunctions) {
        It "defines $func" {
            Get-Command $func -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
    }
    It 'ConvertTo-JsonCompatible returns valid JSON' {
        $obj = @{Name='Test'; Value=1}
        $json = ConvertTo-JsonCompatible -InputObject $obj
        Test-JsonContent -JsonString $json | Should -Be $true
    }
}
