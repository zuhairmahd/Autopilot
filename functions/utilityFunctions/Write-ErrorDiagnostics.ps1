<#
.SYNOPSIS
    Writes comprehensive error diagnostics for use in catch blocks.

.DESCRIPTION
    This function provides detailed error information including exception details,
    stack traces, invocation info, and environment context. It's designed to be
    called from catch blocks to provide maximum diagnostic information.

.PARAMETER ErrorRecord
    The error record to analyze. If not provided, uses $_ from the current scope.

.PARAMETER FunctionName
    The name of the function where the error occurred. Used for logging context.

.PARAMETER ModuleName
    The name of the module where the error occurred. Used for logging context.

.PARAMETER AdditionalContext
    A hashtable of additional context information to include in the diagnostics.

.PARAMETER IncludeEnvironment
    Include PowerShell version and OS information in the output.

.PARAMETER IncludeModules
    Include loaded module versions in the output. Can specify module names.

.PARAMETER LogLevel
    The log level to use when writing to the log file. Default is "Error".

.PARAMETER SuppressConsoleOutput
    If specified, suppresses writing to the error stream (only logs to file).

.EXAMPLE
    try {
        # Some operation
    }
    catch {
        Write-ErrorDiagnostics -FunctionName $MyInvocation.MyCommand.Name
    }

.EXAMPLE
    try {
        # Some operation
    }
    catch {
        Write-ErrorDiagnostics -ErrorRecord $_ -FunctionName "MyFunction" -AdditionalContext @{
            UserID = $userID
            Operation = "Device Assignment"
        }
    }
#>
function Write-ErrorDiagnostics
{
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline = $true)]
        [System.Management.Automation.ErrorRecord]$ErrorRecord,

        [Parameter()]
        [string]$FunctionName,

        [Parameter()]
        [string]$ModuleName,

        [Parameter()]
        [hashtable]$AdditionalContext,

        [Parameter()]
        [switch]$IncludeEnvironment,

        [Parameter()]
        [string[]]$IncludeModules,

        [Parameter()]
        [ValidateSet("Error", "Warning", "Info", "Debug", "Verbose")]
        [string]$LogLevel = "Error",

        [Parameter()]
        [switch]$SuppressConsoleOutput
    )

    begin
    {
        $functionName = $MyInvocation.MyCommand.Name

        # Helper function to write diagnostic messages
        function Write-DiagnosticMessage
        {
            param(
                [Parameter(Mandatory = $true)]
                [string]$Message,
                [string]$Module = $(if ($PSBoundParameters.ContainsKey('FunctionName') -and $PSBoundParameters['FunctionName']) { $PSBoundParameters['FunctionName'] } else { $functionName }),
                [string]$Level = $LogLevel
            )

            # Write to console unless suppressed
            if (-not $SuppressConsoleOutput)
            {
                Write-Error $Message
            }

            # Write to log file if available
            if (Get-Command Write-Log -ErrorAction SilentlyContinue)
            {
                if ($script:logFile -or $global:logFile)
                {
                    $logFileToUse = if ($script:logFile)
                    {
                        $script:logFile 
                    }
                    else
                    {
                        $global:logFile 
                    }
                    Write-Log -logFile $logFileToUse -Module $Module -Message $Message -LogLevel $Level
                }
            }
        }
    }

    process
    {
        # If no error record provided, try to get it from the current scope
        if (-not $ErrorRecord)
        {
            $ErrorRecord = $_
            if (-not $ErrorRecord)
            {
                Write-Warning "Write-ErrorDiagnostics: No error record provided or available in current scope."
                return
            }
        }

        # Start diagnostic output
        Write-DiagnosticMessage "`n=========================================="
        Write-DiagnosticMessage "ERROR DIAGNOSTIC INFORMATION"
        Write-DiagnosticMessage "=========================================="

        # Context information
        if ($FunctionName)
        {
            Write-DiagnosticMessage "Function: $FunctionName"
        }
        if ($ModuleName)
        {
            Write-DiagnosticMessage "Module: $ModuleName"
        }
        Write-DiagnosticMessage "Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss.fff')"

        # Additional context if provided
        if ($AdditionalContext -and $AdditionalContext.Count -gt 0)
        {
            Write-DiagnosticMessage "`nAdditional Context:"
            foreach ($key in $AdditionalContext.Keys)
            {
                $value = $AdditionalContext[$key]
                if ($value -is [hashtable] -or $value -is [PSCustomObject])
                {
                    $valueStr = $value | ConvertTo-Json -Depth 2 -Compress -ErrorAction SilentlyContinue
                }
                else
                {
                    $valueStr = $value.ToString()
                }
                Write-DiagnosticMessage " $key : $valueStr"
            }
        }

        # Error message and type
        Write-DiagnosticMessage "`nError Message: $($ErrorRecord.Exception.Message)"
        Write-DiagnosticMessage "Error Type: $($ErrorRecord.Exception.GetType().FullName)"

        # Error location from invocation info
        if ($ErrorRecord.InvocationInfo)
        {
            Write-DiagnosticMessage "`nError Location:"
            if ($ErrorRecord.InvocationInfo.ScriptName)
            {
                Write-DiagnosticMessage " Script Name: $($ErrorRecord.InvocationInfo.ScriptName)"
            }
            if ($ErrorRecord.InvocationInfo.ScriptLineNumber)
            {
                Write-DiagnosticMessage " Line Number: $($ErrorRecord.InvocationInfo.ScriptLineNumber)"
            }
            if ($ErrorRecord.InvocationInfo.Line)
            {
                Write-DiagnosticMessage " Line Content: $($ErrorRecord.InvocationInfo.Line.Trim())"
            }
            if ($ErrorRecord.InvocationInfo.OffsetInLine)
            {
                Write-DiagnosticMessage " Position: Column $($ErrorRecord.InvocationInfo.OffsetInLine)"
            }
            if ($ErrorRecord.InvocationInfo.MyCommand)
            {
                Write-DiagnosticMessage " Command: $($ErrorRecord.InvocationInfo.MyCommand.Name)"
            }
        }

        # Exception details
        Write-DiagnosticMessage "`nException Details:"
        if ($ErrorRecord.Exception.Source)
        {
            Write-DiagnosticMessage " Source: $($ErrorRecord.Exception.Source)"
        }
        if ($ErrorRecord.Exception.HResult)
        {
            Write-DiagnosticMessage " HResult: 0x$($ErrorRecord.Exception.HResult.ToString('X8'))"
        }

        # Inner exceptions
        if ($ErrorRecord.Exception.InnerException)
        {
            Write-DiagnosticMessage "`nInner Exception(s):"
            $innerEx = $ErrorRecord.Exception.InnerException
            $depth = 1
            while ($innerEx -and $depth -le 10)
            {
                Write-DiagnosticMessage " [$depth] Type: $($innerEx.GetType().FullName)"
                Write-DiagnosticMessage " [$depth] Message: $($innerEx.Message)"
                if ($innerEx.HResult)
                {
                    Write-DiagnosticMessage " [$depth] HResult: 0x$($innerEx.HResult.ToString('X8'))"
                }
                $innerEx = $innerEx.InnerException
                $depth++
            }
            if ($depth -gt 10)
            {
                Write-DiagnosticMessage " [Note: Additional inner exceptions truncated]"
            }
        }

        # Stack trace
        if ($ErrorRecord.Exception.StackTrace)
        {
            Write-DiagnosticMessage "`nStack Trace:"
            Write-DiagnosticMessage $ErrorRecord.Exception.StackTrace
        }
        elseif ($ErrorRecord.ScriptStackTrace)
        {
            Write-DiagnosticMessage "`nScript Stack Trace:"
            Write-DiagnosticMessage $ErrorRecord.ScriptStackTrace
        }

        # PowerShell error record details
        Write-DiagnosticMessage "`nPowerShell Error Record:"
        Write-DiagnosticMessage " Category: $($ErrorRecord.CategoryInfo.Category)"
        if ($ErrorRecord.CategoryInfo.Activity)
        {
            Write-DiagnosticMessage " Activity: $($ErrorRecord.CategoryInfo.Activity)"
        }
        Write-DiagnosticMessage " Reason: $($ErrorRecord.CategoryInfo.Reason)"
        if ($ErrorRecord.CategoryInfo.TargetName)
        {
            Write-DiagnosticMessage " Target Name: $($ErrorRecord.CategoryInfo.TargetName)"
        }
        if ($ErrorRecord.CategoryInfo.TargetType)
        {
            Write-DiagnosticMessage " Target Type: $($ErrorRecord.CategoryInfo.TargetType)"
        }

        # Target object if present
        if ($ErrorRecord.TargetObject)
        {
            try
            {
                $targetJson = $ErrorRecord.TargetObject | ConvertTo-Json -Depth 2 -Compress -ErrorAction SilentlyContinue
                Write-DiagnosticMessage " Target Object: $targetJson"
            }
            catch
            {
                Write-DiagnosticMessage " Target Object: $($ErrorRecord.TargetObject.ToString())"
            }
        }

        # Fully qualified error ID
        if ($ErrorRecord.FullyQualifiedErrorId)
        {
            Write-DiagnosticMessage " Fully Qualified Error ID: $($ErrorRecord.FullyQualifiedErrorId)"
        }

        # Environment information
        if ($IncludeEnvironment)
        {
            Write-DiagnosticMessage "`nEnvironment Information:"
            Write-DiagnosticMessage " PowerShell Version: $($PSVersionTable.PSVersion)"
            if ($PSVersionTable.OS)
            {
                Write-DiagnosticMessage " OS: $($PSVersionTable.OS)"
            }
            if ($PSVersionTable.Platform)
            {
                Write-DiagnosticMessage " Platform: $($PSVersionTable.Platform)"
            }
            Write-DiagnosticMessage " PSEdition: $($PSVersionTable.PSEdition)"
        }

        # Module information
        if ($IncludeModules -and $IncludeModules.Count -gt 0)
        {
            Write-DiagnosticMessage "`nLoaded Module Versions:"
            foreach ($moduleName in $IncludeModules)
            {
                $loadedModule = Get-Module -Name $moduleName -ErrorAction SilentlyContinue
                if ($loadedModule)
                {
                    Write-DiagnosticMessage " $moduleName : $($loadedModule.Version)"
                }
                else
                {
                    Write-DiagnosticMessage " $moduleName : Not loaded"
                }
            }
        }

        # End diagnostic output
        Write-DiagnosticMessage "=========================================="
        Write-DiagnosticMessage "END OF ERROR DIAGNOSTIC INFORMATION"
        Write-DiagnosticMessage "=========================================="
    }
}