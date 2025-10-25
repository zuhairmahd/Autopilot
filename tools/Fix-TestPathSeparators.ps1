<#
.SYNOPSIS
    Fixes path separator inconsistencies in Pester test files.

.DESCRIPTION
    Scans Pester test files for path separators and normalizes them to use
    the correct separator for the current operating system. This ensures
    tests run correctly on both Windows (backslash) and Linux (forward slash).
    
    The script uses [System.IO.Path]::DirectorySeparatorChar to determine
    the correct separator and updates:
    - Import-Module paths
    - Dot-sourcing paths
    - Join-Path operations
    - File path strings

.PARAMETER TestPath
    Path to the tests directory or specific test file. Defaults to tests folder.

.PARAMETER WhatIf
    Shows what would be changed without making actual changes.

.PARAMETER Recurse
    Process all test files recursively.

.EXAMPLE
    .\tools\Fix-TestPathSeparators.ps1
    Fixes all test files in the tests directory

.EXAMPLE
    .\tools\Fix-TestPathSeparators.ps1 -TestPath "tests\Unit" -WhatIf
    Shows what would be fixed in Unit tests without making changes

.EXAMPLE
    .\tools\Fix-TestPathSeparators.ps1 -TestPath "tests\Unit\MyTest.Tests.ps1"
    Fixes a specific test file
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter()]
    [string]$TestPath = "tests"
)

function Find-FolderPath()
{
    <#
    .SYNOPSIS
        Searches upward from the given path for a folder with the specified name.
    .PARAMETER Path
        The starting path to begin searching from.
    .PARAMETER FolderName
        The name of the folder to search for.
    .OUTPUTS
        Returns the full path to the folder if found, otherwise $null.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,
        [Parameter(Mandatory = $true)]
        [string]$FolderName
    )
    $functionName = $MyInvocation.MyCommand.Name
    #write verbose log of received parameters
    Write-Verbose "[$functionName] Find-FolderPath called with Path: $Path, FolderName: $FolderName"
    try
    {
        $currentPath = (Resolve-Path -Path $Path).Path
        Write-Verbose "[$functionName] Current path resolved to: $currentPath"

        # 1. Search children (recursively) of the starting path
        Write-Verbose "[$functionName] Searching children of $currentPath for folder named $FolderName"
        $childMatch = Get-ChildItem -Path $currentPath -Directory -Recurse -ErrorAction SilentlyContinue | Where-Object { $_.Name -ieq $FolderName } | Select-Object -First 1
        Write-Verbose "[$functionName] Checking child match: $($childMatch.FullName)"
        if ($childMatch)
        {
            Write-Verbose "[$functionName] Found folder in children: $($childMatch.FullName)"
            return $childMatch.FullName
        }
        # Also check if the starting path itself matches
        if ((Split-Path -Path $currentPath -Leaf) -ieq $FolderName)
        {
            Write-Verbose "[$functionName] Starting path itself matches: $currentPath"
            return $currentPath
        }

        # 2. Search up the parent chain, at each level search its children for the folder
        while ($currentPath)
        {
            $parent = Split-Path -Path $currentPath -Parent
            if ($parent -eq $currentPath -or [string]::IsNullOrEmpty($parent))
            {
                break
            } # Reached root
            Write-Verbose "[$functionName] Searching children of parent: $parent for folder named $FolderName"
            $siblingMatch = Get-ChildItem -Path $parent -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -ieq $FolderName } | Select-Object -First 1
            if ($siblingMatch)
            {
                Write-Verbose "[$functionName] Found folder in parent: $($siblingMatch.FullName)"
                return $siblingMatch.FullName
            }
            # Also check if the parent itself matches
            if ((Split-Path -Path $parent -Leaf) -ieq $FolderName)
            {
                Write-Verbose "[$functionName] Parent itself matches: $parent"
                return $parent
            }
            $currentPath = $parent
        }
        Write-Verbose "[$functionName] No folder found with name $FolderName in children or parent hierarchy."
        return $null
    }
    catch
    {
        Write-Error "[$functionName] Error occurred while searching for folder: $_"
        return $null
    }
}

$recurse = $true

# Get the correct path separator for the current OS
$separator = [System.IO.Path]::DirectorySeparatorChar
$wrongSeparator = if ($separator -eq '\') { '/' } else { '\' }

Write-Host "Path Separator Fix Utility" -ForegroundColor Cyan
Write-Host "Current OS separator: '$separator'" -ForegroundColor Yellow
Write-Host "Will replace: '$wrongSeparator' with '$separator'" -ForegroundColor Yellow
Write-Host ""

# Resolve test path
$fullTestPath = if ([System.IO.Path]::IsPathRooted($TestPath))
{
    $TestPath
}
else
{
    Join-Path $PSScriptRoot ".." $TestPath
}

if (-not (Test-Path $fullTestPath))
{
    Write-Error "Test path not found: $fullTestPath"
    exit 1
}

# Get test files
$testFiles = if ((Get-Item $fullTestPath).PSIsContainer)
{
    Get-ChildItem -Path $fullTestPath -Filter "*.Tests.ps1" -Recurse:$Recurse -File
}
else
{
    Get-Item $fullTestPath
}

if ($testFiles.Count -eq 0)
{
    Write-Host "No test files found in: $fullTestPath" -ForegroundColor Yellow
    exit 0
}

Write-Host "Found $($testFiles.Count) test file(s) to process" -ForegroundColor Green
Write-Host ""

$totalChanges = 0
$filesChanged = 0

foreach ($file in $testFiles)
{
    $relativePath = $file.FullName.Replace($PSScriptRoot, "").TrimStart('\', '/')
    Write-Verbose "Processing: $relativePath"
    
    $content = Get-Content -Path $file.FullName -Raw
    $fileChanges = 0
    
    # Pattern 1: Import-Module with wrong separator
    # Example: Import-Module "$PSScriptRoot/../../Helpers/AutopilotTestHelpers.psm1"
    $pattern1 = "\`$PSScriptRoot[$wrongSeparator]+([^`"']+)"
    $matches1 = [regex]::Matches($content, $pattern1)
    foreach ($match in $matches1)
    {
        $oldPath = $match.Value
        $newPath = $oldPath -replace [regex]::Escape($wrongSeparator), $separator
        if ($oldPath -ne $newPath)
        {
            $content = $content.Replace($oldPath, $newPath)
            $fileChanges++
            Write-Verbose "  Fixed: $oldPath -> $newPath"
        }
    }
    
    # Pattern 2: $script:RepoRoot with wrong separator
    # Example: . "$script:RepoRoot\functions\utilityFunctions\Write-Log.ps1"
    $pattern2 = "\`$script:RepoRoot[$wrongSeparator]+([^`"']+)"
    $matches2 = [regex]::Matches($content, $pattern2)
    foreach ($match in $matches2)
    {
        $oldPath = $match.Value
        $newPath = $oldPath -replace [regex]::Escape($wrongSeparator), $separator
        if ($oldPath -ne $newPath)
        {
            $content = $content.Replace($oldPath, $newPath)
            $fileChanges++
            Write-Verbose "  Fixed: $oldPath -> $newPath"
        }
    }
    
    # Pattern 3: Mixed separators in paths (e.g., "../folder\file.ps1")
    # This catches any remaining path-like strings with wrong separator
    $pattern3 = "['`"]([^'`"]*[$wrongSeparator][^'`"]*)['`"]"
    $matches3 = [regex]::Matches($content, $pattern3)
    foreach ($match in $matches3)
    {
        $fullMatch = $match.Value
        $pathPart = $match.Groups[1].Value
        
        # Only process if it looks like a file path (has .ps1, .psm1, or multiple segments)
        if ($pathPart -match '\.(ps1|psm1|psd1)' -or ($pathPart.Split($wrongSeparator).Count -gt 2))
        {
            $newPathPart = $pathPart -replace [regex]::Escape($wrongSeparator), $separator
            if ($pathPart -ne $newPathPart)
            {
                $newMatch = $fullMatch.Replace($pathPart, $newPathPart)
                $content = $content.Replace($fullMatch, $newMatch)
                $fileChanges++
                Write-Verbose "  Fixed: $pathPart -> $newPathPart"
            }
        }
    }
    
    # Save changes if any were made
    if ($fileChanges -gt 0)
    {
        Write-Host "  $relativePath" -ForegroundColor Yellow -NoNewline
        Write-Host " - $fileChanges change(s)" -ForegroundColor Cyan
        
        if ($PSCmdlet.ShouldProcess($file.FullName, "Update path separators"))
        {
            Set-Content -Path $file.FullName -Value $content -NoNewline
            $filesChanged++
        }
        
        $totalChanges += $fileChanges
    }
}

Write-Host ""
Write-Host "Summary:" -ForegroundColor Cyan
Write-Host "  Files processed: $($testFiles.Count)" -ForegroundColor White
Write-Host "  Files changed: $filesChanged" -ForegroundColor $(if ($filesChanged -gt 0) { 'Yellow' } else { 'Green' })
Write-Host "  Total changes: $totalChanges" -ForegroundColor $(if ($totalChanges -gt 0) { 'Yellow' } else { 'Green' })

if ($WhatIfPreference)
{
    Write-Host ""
    Write-Host "Run without -WhatIf to apply changes" -ForegroundColor Yellow
}
