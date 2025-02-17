function Get-requiredModules()
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$moduleNames,
        [parameter(Mandatory = $true)]
        [string]$ModulesFolder,
        [switch]$NoImport
    )
    $returnValue = @{}
    $imported = $false
    $installed = $false
    if (-not($NoImport))
    {
        Write-Verbose "NoImport switch is $NoImport"
        Write-Host 'Importing modules.'
        $importedModuleCount = 0
        foreach ($module in $moduleNames)
        {
            Write-Host "Importing $module"
            Import-Module -Name "$ModulesFolder\$module" -ErrorAction Stop
            $importedModuleCount++
        }
        $imported = $true
    }
    Write-Verbose "NoImport is $NoImport"
    Write-Verbose "Success is $imported"
    if ( - (not($imported)) -or $NoImport)
    {
        Write-Host 'Checking for Nuget.'
        $provider = Get-PackageProvider NuGet -ErrorAction Ignore
        if (-not $provider)
        {
            Write-Host 'Attempting to install Nuget from the Internet.' -ForegroundColor Yellow
            Find-PackageProvider -Name NuGet -ForceBootstrap -IncludeDependencies
        }
        else
        {
            Write-Host 'NuGet is already installed.' -ForegroundColor Green
        }
        Write-Host 'Checkin for installed modules.'
        $installedModulesCount = 0
        $checkedModulesCount = 0
        $installedModules = Get-Module -ListAvailable | Select-Object -ExpandProperty Name
        foreach ($module in $moduleNames)
        {
            Write-Verbose "Checking for $module"
            if ($installedModules -notcontains $module)
            {
                Write-Verbose "Installing $module"
                Install-Module -Name $module -Force -AllowClobber -Scope AllUsers -ErrorAction Stop
                $installedModulesCount++
            }
            else
            {
                Write-Verbose "$module is already installed."
                $checkedModulesCount++
            }
        }
        Write-Verbose "Required module(s): $checkedModulesCount"
        Write-Verbose "module(s) requiring installation: $installedModulesCount "
        $installed = $true
    }
    $returnValue.Add('ImportedModuleCount', $importedModuleCount)
    $returnValue.Add('InstalledModulesCount', $installedModulesCount)
    $returnValue.Add('PreviouslyInstalledModulesCount', $checkedModulesCount)
    $returnValue.Add('Imported', $imported)
    $returnValue.Add('Installed', $installed)
    return $returnValue
}
