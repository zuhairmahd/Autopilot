#region help
<#PSScriptInfo
.VERSION 1.0.0
.GUID 3f8a1c2d-9b47-4e65-a731-0d2f85c6e498
.AUTHOR Zuhair Mahmoud
.COMPANYNAME Government Accountability Office
.COPYRIGHT GPL
.SYNOPSIS
    Applies a two-layer VS Code agentic-tool security lockdown.
.DESCRIPTION
    Enforces restrictions on VS Code's AI chat/agentic auto-approval capabilities via:
      Layer 1 - Machine-wide registry policies under HKLM (tamper-proof, applies to all users).
      Layer 2 - Per-user settings.json updates for every profile that has launched VS Code.
    Both layers disable automatic approval for terminal commands, task execution, URL fetches,
    and other potentially dangerous agentic actions.
.PARAMETER ProfileRoot
    Root directory containing user profile folders. Defaults to C:\Users.
.EXAMPLE
    .\vscode-lockdown.ps1
    Applies the lockdown using the default profile root (C:\Users).
.EXAMPLE
    .\vscode-lockdown.ps1 -ProfileRoot "D:\Users" -Verbose
    Applies the lockdown against an alternate profile root with verbose output.
.NOTES
    Must be run as Administrator (registry write to HKLM requires elevation).
#>
#endregion help

[CmdletBinding(SupportsShouldProcess)]
param(
    [string] $ProfileRoot = 'C:\Users'
)

#region Helper Functions
function Set-JsonProperty
{
    <#
    .SYNOPSIS
        Sets or adds a NoteProperty on a PSCustomObject.
    .PARAMETER InputObject
        The PSCustomObject to modify.
    .PARAMETER Name
        The property name to set or add.
    .PARAMETER Value
        The value to assign.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [PSCustomObject] $InputObject,
        [Parameter(Mandatory)] [string]         $Name,
        [Parameter(Mandatory)]                  $Value
    )

    if ($InputObject.PSObject.Properties[$Name])
    {
        Write-Verbose "    Updating existing property '$Name'."
        $InputObject.$Name = $Value
    }
    else
    {
        Write-Verbose "    Adding new property '$Name'."
        $InputObject | Add-Member -NotePropertyName $Name -NotePropertyValue $Value -Force
    }
}

#endregion Helper Functions

#region Layer 1: Registry Policies (machine-wide, tamper-proof)

Write-Verbose 'Layer 1: Applying HKLM registry policies for VS Code.'

$regPath = 'HKLM:\SOFTWARE\Policies\Microsoft\VSCode'

if (-not (Test-Path $regPath))
{
    Write-Verbose "Registry path '$regPath' not found. Creating it."
    if ($PSCmdlet.ShouldProcess($regPath, 'Create registry key'))
    {
        $null = New-Item -Path $regPath -Force
    }
}

# Disable all agentic auto-approval via registry (these values override user settings)
$registryValues = @(
    @{ Name = 'ChatToolsAutoApprove'; Value = 0; Type = 'DWord'  }
    @{ Name = 'ChatToolsTerminalEnableAutoApprove'; Value = 0; Type = 'DWord'  }
    @{ Name = 'ChatToolsEligibleForAutoApproval'; Value = '{"fetch":false,"runTask":false,"runCommand":false,"killTerminal":false,"createAndRunTask":false,"runInTerminal":false}'; Type = 'String' }
)

foreach ($entry in $registryValues)
{
    Write-Verbose "  Setting registry value '$($entry.Name)' = $($entry.Value)."
    if ($PSCmdlet.ShouldProcess("$regPath\$($entry.Name)", 'Set registry value'))
    {
        Set-ItemProperty -Path $regPath -Name $entry.Name -Value $entry.Value -Type $entry.Type -Force
    }
}

Write-Verbose 'Layer 1 complete.'

#endregion

#region Layer 2: Per-User settings.json

Write-Verbose "Layer 2: Updating VS Code settings.json for all user profiles under '$ProfileRoot'."

# Exclude built-in system accounts that are not real user profiles
$excludedProfiles = @('Public', 'Default', 'Default User', 'All Users')

$userDirs = Get-ChildItem -Path $ProfileRoot -Directory |
    Where-Object { $_.Name -notin $excludedProfiles }

Write-Verbose "Found $($userDirs.Count) candidate user profile(s) to process."

foreach ($userDir in $userDirs)
{
    $settingsDir = Join-Path $userDir.FullName 'AppData\Roaming\Code\User'
    $settingsPath = Join-Path $settingsDir 'settings.json'

    Write-Verbose "Processing user: $($userDir.Name)"

    # Skip users who have never launched VS Code (settings directory won't exist)
    if (-not (Test-Path $settingsDir))
    {
        Write-Verbose "  VS Code settings directory not found. Skipping."
        continue
    }

    # Load existing settings, or start with an empty object
    if (Test-Path $settingsPath)
    {
        try
        {
            Write-Verbose "  Loading existing settings from '$settingsPath'."
            $settings = Get-Content -Path $settingsPath -Raw | ConvertFrom-Json
        }
        catch
        {
            Write-Warning "  Could not parse '$settingsPath'. Backing up and starting fresh. Error: $_"
            if ($PSCmdlet.ShouldProcess($settingsPath, 'Backup corrupt settings file'))
            {
                Copy-Item -Path $settingsPath -Destination "$settingsPath.bak" -Force
            }
            $settings = [PSCustomObject]@{}
        }
    }
    else
    {
        Write-Verbose "  No settings.json found. A new one will be created."
        $settings = [PSCustomObject]@{}
    }

    # Define which agentic tools are NOT eligible for auto-approval
    $eligibleForAutoApproval = [PSCustomObject]@{
        fetch            = $false
        runTask          = $false
        runCommand       = $false
        killTerminal     = $false
        createAndRunTask = $false
        runInTerminal    = $false
    }

    # Apply all security settings
    Set-JsonProperty -InputObject $settings -Name 'chat.tools.eligibleForAutoApproval' -Value $eligibleForAutoApproval
    Set-JsonProperty -InputObject $settings -Name 'chat.tools.terminal.ignoreDefaultAutoApproveRules' -Value $true
    Set-JsonProperty -InputObject $settings -Name 'chat.tools.terminal.autoApprove' -Value ([PSCustomObject]@{ '*' = $false })
    Set-JsonProperty -InputObject $settings -Name 'chat.tools.urls.autoApprove' -Value ([PSCustomObject]@{ '*' = $false })

    if ($PSCmdlet.ShouldProcess($settingsPath, 'Write updated settings.json'))
    {
        $settings | ConvertTo-Json -Depth 10 | Set-Content -Path $settingsPath -Encoding UTF8 -Force
        Write-Verbose "  Settings saved to '$settingsPath'."
    }
}

Write-Verbose 'Layer 2 complete.'

#endregion

Write-Output 'VS Code security lockdown applied (registry + all user profiles).'
