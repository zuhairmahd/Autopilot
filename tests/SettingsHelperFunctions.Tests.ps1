$script:modulePathJson = Join-Path $PSScriptRoot '..' 'functions' 'JsonHelperFunctions.ps1'
$modulePath = Join-Path $PSScriptRoot '..' 'functions' 'SettingsHelperFunctions.ps1'
$expectedFunctions = Select-String -Path $modulePath -Pattern '^[Ff]unction\s+([^(\s]+)' | ForEach-Object { $_.Matches[0].Groups[1].Value }
Describe 'SettingsHelperFunctions.ps1' {
    BeforeAll {
        . $modulePathJson
        . $modulePath
    }
    foreach ($func in $expectedFunctions) {
        It "defines $func" {
            Get-Command $func -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
    }
    It 'Format-SettingsJson preserves keys' {
        $json = '{"a":1,"b":{"c":2}}'
        $formatted = Format-SettingsJson -JsonString $json
        $formatted | Should -Match '"c"'
    }
}
