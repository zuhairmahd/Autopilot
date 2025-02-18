function Get-SignatureStatus()
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [string[]]$scriptFolders
    )
    Write-Verbose "Received $scriptFolders to check"
    $scriptFolders = $scriptFolders -split ',' | ForEach-Object { $_.Trim() }
    $unsignedScripts = @()
    Write-Verbose "Checking $($scriptFolders.Count) folders for scripts."
    foreach ($folder in $scriptFolders)
    {
        Write-Verbose "Checking folder $folder for scripts."
        $scripts = Get-ChildItem -Path "$folder\*.ps1"
        Write-Verbose "Checking scripts in $folder for signatures."
        Write-Verbose "Found $($scripts.Count) scripts in $folder."
        foreach ($script in $scripts)
        {
            Write-Verbose "Checking $($script.Name) for a valid signature."
            $signature = Get-AuthenticodeSignature -FilePath $script.FullName
            if ($signature.Status -ne 'Valid')
            {
                $unsignedScripts += $script.FullName
                Write-Verbose "Script $($script.Name) failed the signature check."
            }
        }
    }
    if ($unsignedScripts.Count -gt 0)
    {
        Write-Host 'The following scripts are not signed:' -ForegroundColor Yellow
        $unsignedScripts
    }
    else
    {
        Write-Host 'All scripts are signed.' -ForegroundColor Green
    }
    Write-Verbose "Returning $unsignedScripts."
    return $unsignedScripts
}