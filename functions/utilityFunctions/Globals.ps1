# Ensures shared global defaults are available when functions are dot-sourced in tests or scripts
# PowerShell 5.1 compatible

# Initialize a sane default for JSON depth if not already set in the current session
try
{
    $existing = Get-Variable -Name maxJSONDepth -Scope Global -ErrorAction Ignore
}
catch
{
    $existing = $null
}
if (-not $existing -or ($null -eq $global:maxJSONDepth) -or ($global:maxJSONDepth -isnot [int]) -or $global:maxJSONDepth -le 0)
{
    $global:maxJSONDepth = 100
}

# Initialize a sane default for global log file, PS 5.1-safe
try
{
    $logVar = Get-Variable -Name LogFile -Scope Global -ErrorAction Ignore
}
catch
{
    $logVar = $null
}

$needsInit = $true
if ($logVar)
{
    # Coerce to string safely
    $candidate = "" + $global:LogFile
    if ($candidate)
    {
        $candidate = $candidate.Trim()
        if ($candidate -ne '')
        {
            # If not rooted, place under a Logs folder if available, else TEMP
            if (-not ([System.IO.Path]::IsPathRooted($candidate)))
            {
                $p1 = Split-Path $PSScriptRoot -Parent
                $p2 = Split-Path $p1 -Parent
                $p3 = Split-Path $p2 -Parent
                $baseLogs = $null
                foreach ($d in @(
                        (Join-Path $p3 'Logs'),
                        (Join-Path $p2 'Logs'),
                        (Join-Path $p1 'Logs')
                    ))
                {
                    if ($d -and (Test-Path $d))
                    {
                        $baseLogs = $d; break 
                    }
                }
                if (-not $baseLogs)
                {
                    $baseLogs = $env:TEMP 
                }
                $candidate = Join-Path $baseLogs $candidate
            }
            # Ensure directory exists
            try
            {
                $dir = Split-Path $candidate -Parent
                if ($dir -and -not (Test-Path $dir))
                {
                    New-Item -ItemType Directory -Path $dir -Force | Out-Null 
                }
            }
            catch
            { 
            }
            $global:LogFile = $candidate
            $needsInit = $false
        }
    }
}

if ($needsInit)
{
    # Choose Logs dir relative to repo if present, otherwise TEMP\Autopilot
    $p1 = Split-Path $PSScriptRoot -Parent
    $p2 = Split-Path $p1 -Parent
    $p3 = Split-Path $p2 -Parent
    $logDir = $null
    foreach ($d in @(
            (Join-Path $p3 'Logs'),
            (Join-Path $p2 'Logs'),
            (Join-Path $p1 'Logs')
        ))
    {
        if ($d -and (Test-Path $d))
        {
            $logDir = $d; break 
        }
    }
    if (-not $logDir)
    {
        $logDir = Join-Path $env:TEMP 'Autopilot'
    }
    if (-not (Test-Path $logDir))
    {
        New-Item -ItemType Directory -Path $logDir -Force | Out-Null 
    }
    $global:LogFile = Join-Path $logDir 'Autopilot.log'
}
