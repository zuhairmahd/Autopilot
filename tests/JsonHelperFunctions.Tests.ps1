BeforeAll {
    # Dot source the helper functions
    . "$PSScriptRoot/../functions/JsonHelperFunctions.ps1"
}

Describe 'ConvertTo-JsonCompatible' {
    It 'returns null string for null input' {
        ConvertTo-JsonCompatible -InputObject $null | Should -Be 'null'
    }

    It 'serializes nested hashtable correctly' {
        $obj = [ordered]@{
            Name = 'Test'
            Nested = [ordered]@{Value = 1}
        }
        $json = ConvertTo-JsonCompatible -InputObject $obj -Depth 5
        $parsed = $json | ConvertFrom-Json
        $parsed.Name | Should -Be 'Test'
        $parsed.Nested.Value | Should -Be 1
    }
}

Describe 'Save-JsonToFile' {
    It 'writes valid JSON to file and returns true' {
        $json = '{"a":1}'
        $path = Join-Path $TestDrive 'good.json'
        $result = $json | Save-JsonToFile -FilePath $path -Force
        $result | Should -Be $true
        Test-Path $path | Should -Be $true
    }

    It 'returns false and does not create file when content is empty' {
        $path = Join-Path $TestDrive 'empty.json'
        $result = '' | Save-JsonToFile -FilePath $path -Force
        $result | Should -Be $false
        Test-Path $path | Should -Be $false
    }

    It 'writes file even if JSON is invalid' {
        $invalidJson = '{"a":}'
        $path = Join-Path $TestDrive 'invalid.json'
        $result = $invalidJson | Save-JsonToFile -FilePath $path -Force
        $result | Should -Be $true
        Test-Path $path | Should -Be $true
    }
}

Describe 'Test-JsonContent' {
    It 'returns true for valid JSON' {
        Test-JsonContent -JsonString '{"a":1}' | Should -Be $true
    }

    It 'returns false for invalid JSON' {
        Test-JsonContent -JsonString '{"a":}' | Should -Be $false
    }
}
