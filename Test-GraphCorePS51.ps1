<#
.SYNOPSIS
    Diagnoses GraphCore DLL loading issues in PowerShell 5.1
#>

$dllPath = "bin\Release\netstandard2.0\Autopilot.GraphCore.dll"
$dllDir = Split-Path (Resolve-Path $dllPath).Path -Parent
$resolvedPath = (Resolve-Path $dllPath).Path

Write-Host "Testing GraphCore DLL loading in PowerShell 5.1" -ForegroundColor Cyan
Write-Host "PowerShell Version: $($PSVersionTable.PSVersion)" -ForegroundColor Gray
Write-Host "CLR Version: $($PSVersionTable.CLRVersion)" -ForegroundColor Gray
Write-Host "DLL Path: $resolvedPath" -ForegroundColor Gray
Write-Host "DLL Directory: $dllDir" -ForegroundColor Gray
Write-Host ""

# Pre-load dependencies from same directory
Write-Host "Pre-loading dependencies..." -ForegroundColor Yellow
$dependencies = @('System.Text.Json.dll', 'System.Memory.dll', 'System.Buffers.dll')
foreach ($dep in $dependencies)
{
    $depPath = Join-Path $dllDir $dep
    if (Test-Path $depPath)
    {
        try
        {
            [System.Reflection.Assembly]::LoadFile($depPath) | Out-Null
            Write-Host "  Loaded: $dep" -ForegroundColor Green
        }
        catch
        {
            Write-Host "  Warning: Could not load $dep - $($_.Exception.Message)" -ForegroundColor Yellow
        }
    }
}
Write-Host ""

try
{
    Write-Host "Attempting to load assembly..." -ForegroundColor Yellow
    $assembly = [System.Reflection.Assembly]::LoadFile($resolvedPath)
    Write-Host "Assembly loaded successfully!" -ForegroundColor Green
    Write-Host "Assembly FullName: $($assembly.FullName)" -ForegroundColor Gray
    
    Write-Host "`nAttempting to get types..." -ForegroundColor Yellow
    $types = $assembly.GetTypes()
    Write-Host "Successfully retrieved $($types.Count) types" -ForegroundColor Green
    
}
catch [System.Reflection.ReflectionTypeLoadException]
{
    Write-Host "ReflectionTypeLoadException caught!" -ForegroundColor Red
    Write-Host "`nLoader Exceptions:" -ForegroundColor Yellow
    
    $_.Exception.LoaderExceptions | ForEach-Object {
        Write-Host "  - $($_.GetType().Name): $($_.Message)" -ForegroundColor Red
        if ($_.InnerException)
        {
            Write-Host "    Inner: $($_.InnerException.Message)" -ForegroundColor DarkRed
        }
    }
    
    Write-Host "`nTypes that did load:" -ForegroundColor Yellow
    $_.Exception.Types | Where-Object { $_ -ne $null } | ForEach-Object {
        Write-Host "  + $($_.FullName)" -ForegroundColor Green
    }
    
    Write-Host "`nUnique missing assemblies:" -ForegroundColor Yellow
    $_.Exception.LoaderExceptions | 
        Where-Object { $_ -is [System.IO.FileNotFoundException] } |
        Select-Object -ExpandProperty Message -Unique |
        ForEach-Object {
            if ($_ -match "Could not load file or assembly '([^']+)'")
            {
                Write-Host "  ! $($matches[1])" -ForegroundColor Magenta
            }
        }
        
}
catch
{
    Write-Host "Unexpected error: $($_.Exception.GetType().Name)" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    Write-Host $_.Exception.StackTrace -ForegroundColor DarkRed
}
