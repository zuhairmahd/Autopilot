$repoRoot = (Resolve-Path "$PSScriptRoot/..").Path

Describe 'main.ps1' {
    BeforeEach {
        $repoRoot = (Resolve-Path "$PSScriptRoot/..").Path
        $tempConfig = New-TemporaryFile
        $tempSettings = New-TemporaryFile

        # prevent Export-ModuleMember errors when dot-sourcing helper scripts
        function Export-ModuleMember { param() }

        # prepare config copy with domain matching settings
        $config = Get-Content -Raw -Path (Join-Path $repoRoot 'config-sample.json') | ConvertFrom-Json
        $config.domain = 'gao.gov'
        $config | ConvertTo-Json -Depth 10 | Set-Content -Path $tempConfig.FullName

        # prepare settings copy with test mode enabled
        $settings = Get-Content -Raw -Path (Join-Path $repoRoot 'settings.json') | ConvertFrom-Json
        $settings.globalSettings.testMode = $true
        $settings | ConvertTo-Json -Depth 10 | Set-Content -Path $tempSettings.FullName

        # clear global variables
        Remove-Variable -Name globalSettings -Scope Global -ErrorAction SilentlyContinue
        Remove-Variable -Name localSettings -Scope Global -ErrorAction SilentlyContinue

        $oldPref = $ErrorActionPreference
        $ErrorActionPreference = 'SilentlyContinue'
        try {
            . (Join-Path $repoRoot 'main.ps1') -configFile $tempConfig.FullName -InitFile $tempSettings.FullName
        } catch {
            # ignore errors triggered by module export commands
        }
        $ErrorActionPreference = $oldPref
    }

    It 'populates global and local settings' {
        $global:globalSettings.testMode | Should -Be $true
        $global:localSettings.settings.domain | Should -Be 'gao.gov'
    }

    It 'sets localVersion to 3.0.0' {
        $localVersion.Trim() | Should -Be '3.0.0'
    }

    It 'creates version file with version string' {
        $versionPath = Join-Path $repoRoot 'version.txt'
        Test-Path $versionPath | Should -BeTrue
        (Get-Content -Path $versionPath -Raw).Trim() | Should -Be '3.0.0'
    }
}
