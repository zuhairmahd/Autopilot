BeforeAll {
    # Import helper modules
    Import-Module "$PSScriptRoot/../Helpers/AutopilotTestHelpers.psm1" -Force

    # Direct dot-sourcing of the function to test
    $script:RepoRoot = (Get-Item $PSScriptRoot).Parent.Parent.FullName
    . "$script:RepoRoot/functions/setupFunctions/Initialize-FastStart.ps1"
    . "$script:RepoRoot/functions/utilityFunctions/write-log.ps1"

    # Setup test environment
    $script:TestContext = Initialize-AutopilotTestEnvironment
    $script:TestRoot = $script:TestContext.TestFolder

    # Initialize global variables required by Initialize-FastStart
    $global:logFile = Join-Path $script:TestRoot "Logs\test.log"
    New-Item -Path (Split-Path $global:logFile -Parent) -ItemType Directory -Force | Out-Null

    # Helper function to create test configuration files
    function New-TestFastStartFiles
    {
        param(
            [string]$TestFolder,
            [string]$Domain = "test.contoso.com",
            [bool]$IncludeInitFile = $true,
            [bool]$IncludeStringsFile = $true,
            [bool]$IncludeMenuFile = $true,
            [bool]$IncludeDomainFile = $true,
            [bool]$IncludeMenuCache = $true
        )

        $files = @{
            InitFile      = Join-Path $TestFolder "settings.psd1"
            StringsFile   = Join-Path $TestFolder "strings.psd1"
            MenuFile      = Join-Path $TestFolder "menu.psd1"
            DomainFile    = Join-Path $TestFolder "$Domain.psd1"
            MenuCacheFile = Join-Path $TestFolder "menu-cache.json"
        }

        if ($IncludeInitFile)
        {
            @"
@{
    auth = @{
        delegated = `$false
        authType = 'application'
        scope = 'https://graph.microsoft.com/.default'
    }
    globalSettings = @{
        appMode = 'helpdesk'
        LogLevel = 'Information'
        domain = '$Domain'
    }
    repoInfo = @{
        baseSourceURL = 'https://raw.githubusercontent.com'
        repoPath = 'test'
        repoName = 'Autopilot'
    }
    requiredScopes = @(
        @{ Scope = 'Device.Read.All'; Endpoints = @('devices'); Reason = 'Test' }
    )
    cacheSettings = @{
        enableCache = `$true
        cacheExpirationMinutes = 30
    }
}
"@ | Out-File -FilePath $files.InitFile -Encoding UTF8
        }

        if ($IncludeStringsFile)
        {
            @"
@{
    returnValues = @{
        Back = '[B]ack'
        MainMenu = '[M]ain Menu'
    }
}
"@ | Out-File -FilePath $files.StringsFile -Encoding UTF8
        }

        if ($IncludeMenuFile)
        {
            @"
@{
    mainMenu = @{
        Title = 'Main Menu'
        Type = 'menu'
        Items = @()
    }
}
"@ | Out-File -FilePath $files.MenuFile -Encoding UTF8
        }

        if ($IncludeDomainFile)
        {
            @"
@{
    groupsToInclude = @()
    groupsToExclude = @()
    LogLevel = 'Information'
}
"@ | Out-File -FilePath $files.DomainFile -Encoding UTF8
        }

        if ($IncludeMenuCache)
        {
            @'
[
    {"id": 1, "title": "Menu Item 1"},
    {"id": 2, "title": "Menu Item 2"}
]
'@ | Out-File -FilePath $files.MenuCacheFile -Encoding UTF8
        }

        return $files
    }

    $script:NewTestFastStartFiles = ${function:New-TestFastStartFiles}
}

AfterAll {
    # Cleanup test environment
    if ($script:TestContext -and $script:TestContext.TestFolder)
    {
        if (Test-Path $script:TestContext.TestFolder)
        {
            Remove-Item -Path $script:TestContext.TestFolder -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

Describe 'Initialize-FastStart' -Tags 'Unit' {

    Context 'Successful Configuration Loading' {
        BeforeAll {
            $testFolder = Join-Path $script:TestRoot "SuccessTest"
            New-Item -Path $testFolder -ItemType Directory -Force | Out-Null

            $script:TestFiles = & $script:NewTestFastStartFiles -TestFolder $testFolder

            $result = Initialize-FastStart `
                -InitFile $script:TestFiles.InitFile `
                -stringsFile $script:TestFiles.StringsFile `
                -menuFile $script:TestFiles.MenuFile `
                -menuCacheFile $script:TestFiles.MenuCacheFile `
                -domain "test.contoso.com" `
                -ScriptPath $testFolder `
                -Verbose

            $script:SuccessResult = $result
        }

        It 'Should return a hashtable' {
            $script:SuccessResult | Should -BeOfType [hashtable]
        }

        It 'Should have Success property set to true' {
            $script:SuccessResult.Success | Should -Be $true
        }

        It 'Should have allFilesLoaded property set to true' {
            $script:SuccessResult.allFilesLoaded | Should -Be $true
        }

        It 'Should load auth configuration' {
            $script:SuccessResult.auth | Should -Not -BeNullOrEmpty
            $script:SuccessResult.auth.authType | Should -Be 'application'
        }

        It 'Should load globalSettings' {
            $script:SuccessResult.globalSettings | Should -Not -BeNullOrEmpty
            $script:SuccessResult.globalSettings.appMode | Should -Be 'helpdesk'
        }

        It 'Should load localSettings (domain configuration)' {
            $script:SuccessResult.localSettings | Should -Not -BeNullOrEmpty
        }

        It 'Should load repoInfo' {
            $script:SuccessResult.RepoInfo | Should -Not -BeNullOrEmpty
            $script:SuccessResult.RepoInfo.repoName | Should -Be 'Autopilot'
        }

        It 'Should load requiredScopes' {
            $script:SuccessResult.RequiredScopes | Should -Not -BeNullOrEmpty
            $script:SuccessResult.RequiredScopes.Count | Should -BeGreaterThan 0
        }

        It 'Should load cacheSettings' {
            $script:SuccessResult.CacheSettings | Should -Not -BeNullOrEmpty
        }

        It 'Should load menu configuration' {
            $script:SuccessResult.menu | Should -Not -BeNullOrEmpty
        }

        It 'Should load menus (menu cache)' {
            $script:SuccessResult.menus | Should -Not -BeNullOrEmpty
        }

        It 'Should load strings configuration' {
            $script:SuccessResult.strings | Should -Not -BeNullOrEmpty
        }
    }

    Context 'Missing InitFile' {
        BeforeAll {
            $testFolder = Join-Path $script:TestRoot "MissingInitTest"
            New-Item -Path $testFolder -ItemType Directory -Force | Out-Null

            $files = & $script:NewTestFastStartFiles -TestFolder $testFolder -IncludeInitFile $false

            $result = Initialize-FastStart `
                -InitFile $files.InitFile `
                -stringsFile $files.StringsFile `
                -menuFile $files.MenuFile `
                -menuCacheFile $files.MenuCacheFile `
                -domain "test.contoso.com" `
                -ScriptPath $testFolder

            $script:MissingInitResult = $result
        }

        It 'Should set allFilesLoaded to false' {
            $script:MissingInitResult.allFilesLoaded | Should -Be $false
        }

        It 'Should set Success to false' {
            $script:MissingInitResult.Success | Should -Be $false
        }

        It 'Should have null auth configuration' {
            $script:MissingInitResult.auth | Should -BeNullOrEmpty
        }
    }

    Context 'Missing Domain File' {
        BeforeAll {
            $testFolder = Join-Path $script:TestRoot "MissingDomainTest"
            New-Item -Path $testFolder -ItemType Directory -Force | Out-Null

            $files = & $script:NewTestFastStartFiles -TestFolder $testFolder -IncludeDomainFile $false

            $result = Initialize-FastStart `
                -InitFile $files.InitFile `
                -stringsFile $files.StringsFile `
                -menuFile $files.MenuFile `
                -menuCacheFile $files.MenuCacheFile `
                -domain "test.contoso.com" `
                -ScriptPath $testFolder

            $script:MissingDomainResult = $result
        }

        It 'Should set allFilesLoaded to false' {
            $script:MissingDomainResult.allFilesLoaded | Should -Be $false
        }

        It 'Should set Success to false' {
            $script:MissingDomainResult.Success | Should -Be $false
        }

        It 'Should have null localSettings' {
            $script:MissingDomainResult.localSettings | Should -BeNullOrEmpty
        }
    }

    Context 'Missing Menu Cache File (Non-Strict Validation)' {
        BeforeAll {
            $testFolder = Join-Path $script:TestRoot "MissingMenuCacheTest"
            New-Item -Path $testFolder -ItemType Directory -Force | Out-Null

            $files = & $script:NewTestFastStartFiles -TestFolder $testFolder -IncludeMenuCache $false

            $result = Initialize-FastStart `
                -InitFile $files.InitFile `
                -stringsFile $files.StringsFile `
                -menuFile $files.MenuFile `
                -menuCacheFile $files.MenuCacheFile `
                -domain "test.contoso.com" `
                -ScriptPath $testFolder

            $script:MissingMenuCacheResult = $result
        }

        It 'Should set allFilesLoaded to true (menu cache is optional in non-strict mode)' {
            # In non-strict mode, missing menu cache does not affect allFilesLoaded
            $script:MissingMenuCacheResult.allFilesLoaded | Should -Be $true
        }

        It 'Should still set Success to true (non-strict validation)' {
            $script:MissingMenuCacheResult.Success | Should -Be $true
        }

        It 'Should have null menus (menu cache)' {
            $script:MissingMenuCacheResult.menus | Should -BeNullOrEmpty
        }
    }

    Context 'Missing Menu Cache File (Strict Validation)' {
        BeforeAll {
            $testFolder = Join-Path $script:TestRoot "MissingMenuCacheStrictTest"
            New-Item -Path $testFolder -ItemType Directory -Force | Out-Null

            $files = & $script:NewTestFastStartFiles -TestFolder $testFolder -IncludeMenuCache $false

            $result = Initialize-FastStart `
                -InitFile $files.InitFile `
                -stringsFile $files.StringsFile `
                -menuFile $files.MenuFile `
                -menuCacheFile $files.MenuCacheFile `
                -domain "test.contoso.com" `
                -ScriptPath $testFolder `
                -strictValidation

            $script:StrictMissingMenuCacheResult = $result
        }

        It 'Should set allFilesLoaded to false' {
            $script:StrictMissingMenuCacheResult.allFilesLoaded | Should -Be $false
        }

        It 'Should set Success to false (strict validation enforces menu cache)' {
            $script:StrictMissingMenuCacheResult.Success | Should -Be $false
        }
    }

    Context 'Incomplete InitFile Configuration' {
        BeforeAll {
            $testFolder = Join-Path $script:TestRoot "IncompleteInitTest"
            New-Item -Path $testFolder -ItemType Directory -Force | Out-Null

            # Create init file missing requiredScopes
            $incompleteInitFile = Join-Path $testFolder "settings.psd1"
            @"
@{
    auth = @{
        delegated = `$false
    }
    globalSettings = @{
        appMode = 'helpdesk'
    }
    repoInfo = @{
        repoName = 'Autopilot'
    }
    # Missing requiredScopes
    cacheSettings = @{
        enableCache = `$true
    }
}
"@ | Out-File -FilePath $incompleteInitFile -Encoding UTF8

            $files = & $script:NewTestFastStartFiles -TestFolder $testFolder -IncludeInitFile $false
            $files.InitFile = $incompleteInitFile

            $result = Initialize-FastStart `
                -InitFile $files.InitFile `
                -stringsFile $files.StringsFile `
                -menuFile $files.MenuFile `
                -menuCacheFile $files.MenuCacheFile `
                -domain "test.contoso.com" `
                -ScriptPath $testFolder

            $script:IncompleteResult = $result
        }

        It 'Should set Success to false when required sections are missing' {
            $script:IncompleteResult.Success | Should -Be $false
        }

        It 'Should have null requiredScopes' {
            $script:IncompleteResult.RequiredScopes | Should -BeNullOrEmpty
        }
    }
}