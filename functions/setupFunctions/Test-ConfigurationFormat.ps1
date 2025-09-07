function Test-ConfigurationFormat() {
<#
.SYNOPSIS
    Detects and validates configuration file formats (.json, .psd1).

.DESCRIPTION
    This function provides intelligent format detection for configuration files,
    supporting both JSON and PowerShell Data File formats. It validates file
    structure and provides compatibility information.

.PARAMETER FilePath
    The full path to the configuration file to analyze.

.PARAMETER CheckCompatibility
    Performs additional compatibility checks beyond basic format detection.

.PARAMETER ReturnDetails
    Returns detailed information about the file format and structure.

.OUTPUTS
    System.String or System.Object
    Returns format name ('JSON', 'PSD1', 'Unknown') by default.
    With -ReturnDetails, returns object with comprehensive format information.

.EXAMPLE
    Test-ConfigurationFormat -FilePath "settings.json"
    # Returns: "JSON"

.EXAMPLE
    $details = Test-ConfigurationFormat -FilePath "settings.psd1" -ReturnDetails -CheckCompatibility
    # Returns detailed object with format info

.NOTES
    - PowerShell 5.1 compatible
    - Handles both existing and missing files gracefully
    - Validates file syntax without fully loading content
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath,
        
        [switch]$CheckCompatibility,
        [switch]$ReturnDetails
    )
    
    $functionName = $MyInvocation.MyCommand.Name
    Write-Verbose "[$functionName] Analyzing configuration file: $FilePath"
    
    # Initialize result object
    $result = @{
        FilePath = $FilePath
        Exists = $false
        Format = 'Unknown'
        IsValid = $false
        FileSize = 0
        LastModified = $null
        ErrorMessage = $null
        CompatibilityInfo = @{}
    }
    
    try {
        # Check if file exists
        if (-not (Test-Path $FilePath)) {
            $result.ErrorMessage = "File not found"
            Write-Verbose "[$functionName] File not found: $FilePath"
            if ($ReturnDetails) { return $result } else { return $result.Format }
        }
        
        $result.Exists = $true
        $fileInfo = Get-Item $FilePath
        $result.FileSize = $fileInfo.Length
        $result.LastModified = $fileInfo.LastWriteTime
        
        # Determine format based on extension and content
        $extension = [System.IO.Path]::GetExtension($FilePath).ToLower()
        
        switch ($extension) {
            '.json' {
                Write-Verbose "[$functionName] Detected JSON extension"
                $result.Format = 'JSON'
                
                # Validate JSON syntax
                try {
                    $content = Get-Content -Path $FilePath -Raw -ErrorAction Stop
                    $testLoad = $content | ConvertFrom-Json -ErrorAction Stop
                    $result.IsValid = $true
                    Write-Verbose "[$functionName] JSON syntax validation successful"
                }
                catch {
                    $result.ErrorMessage = "Invalid JSON syntax: $($_.Exception.Message)"
                    Write-Verbose "[$functionName] JSON validation failed: $($_.Exception.Message)"
                }
            }
            
            '.psd1' {
                Write-Verbose "[$functionName] Detected PSD1 extension"
                $result.Format = 'PSD1'
                
                # Validate PSD1 syntax
                try {
                    $testLoad = Import-PowerShellDataFile -Path $FilePath -ErrorAction Stop
                    $result.IsValid = $true
                    Write-Verbose "[$functionName] PSD1 syntax validation successful"
                }
                catch {
                    $result.ErrorMessage = "Invalid PSD1 syntax: $($_.Exception.Message)"
                    Write-Verbose "[$functionName] PSD1 validation failed: $($_.Exception.Message)"
                }
            }
            
            default {
                Write-Verbose "[$functionName] Unknown extension: $extension"
                # Try to detect format by content
                try {
                    $content = Get-Content -Path $FilePath -Raw -ErrorAction Stop
                    
                    # Test JSON first
                    try {
                        $testJson = $content | ConvertFrom-Json -ErrorAction Stop
                        $result.Format = 'JSON'
                        $result.IsValid = $true
                        Write-Verbose "[$functionName] Content detected as JSON"
                    }
                    catch {
                        # Test PSD1
                        try {
                            $tempFile = [System.IO.Path]::GetTempFileName() + '.psd1'
                            $content | Set-Content -Path $tempFile
                            $testPsd1 = Import-PowerShellDataFile -Path $tempFile -ErrorAction Stop
                            Remove-Item -Path $tempFile -Force
                            $result.Format = 'PSD1'
                            $result.IsValid = $true
                            Write-Verbose "[$functionName] Content detected as PSD1"
                        }
                        catch {
                            $result.ErrorMessage = "Unable to determine format from content"
                            Write-Verbose "[$functionName] Unable to determine format from content"
                        }
                    }
                }
                catch {
                    $result.ErrorMessage = "Unable to read file content: $($_.Exception.Message)"
                    Write-Verbose "[$functionName] Unable to read file: $($_.Exception.Message)"
                }
            }
        }
        
        # Perform compatibility checks if requested
        if ($CheckCompatibility -and $result.IsValid) {
            Write-Verbose "[$functionName] Performing compatibility checks"
            
            $result.CompatibilityInfo = @{
                PowerShell51Compatible = $true
                PowerShell7Compatible = $true
                CrossPlatformCompatible = $false
                HumanReadable = $false
                ToolingSupport = @()
            }
            
            switch ($result.Format) {
                'JSON' {
                    $result.CompatibilityInfo.CrossPlatformCompatible = $true
                    $result.CompatibilityInfo.HumanReadable = $true
                    $result.CompatibilityInfo.ToolingSupport = @('VS Code', 'Notepad++', 'Web browsers', 'Most editors')
                }
                'PSD1' {
                    $result.CompatibilityInfo.CrossPlatformCompatible = $false
                    $result.CompatibilityInfo.HumanReadable = $true
                    $result.CompatibilityInfo.ToolingSupport = @('PowerShell ISE', 'VS Code', 'PowerShell-aware editors')
                }
            }
        }
        
        Write-Verbose "[$functionName] Analysis completed for: $FilePath (Format: $($result.Format), Valid: $($result.IsValid))"
        
        if ($ReturnDetails) {
            return $result
        } else {
            return $result.Format
        }
    }
    catch {
        $result.ErrorMessage = $_.Exception.Message
        Write-Error "[$functionName] Analysis failed: $($_.Exception.Message)"
        
        if ($ReturnDetails) {
            return $result
        } else {
            return 'Unknown'
        }
    }
}