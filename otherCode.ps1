
# Create a clean breadcrumb path without duplicates
Write-Verbose "[$functionName] Cleaning history to remove duplicates."
$cleanHistory = @()
$previousItem = ""
foreach ($item in $History)
{
    if ($item -ne $previousItem -and ![string]::IsNullOrWhiteSpace($item))
    {
        Write-Verbose "[$functionName] Adding item to clean history: $item since it is not equal to $previousItem"
        $cleanHistory += $item
        $previousItem = $item
    }
}
if ($cleanHistory.Count -gt 0)
{
    $path = $cleanHistory -join " > "
    $banner += "`nBreadcrumb: [$path > $($Menu.Title)]"
}
else
{
    $banner += "`nBreadcrumb: [$($Menu.Title)]"
}

        