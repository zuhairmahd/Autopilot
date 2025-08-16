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
