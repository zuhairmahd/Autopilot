function Invoke-ParallelFileOperations()
{
    <#
    .SYNOPSIS
        Phase 4B Optimization: Executes file operations in parallel for improved performance.
    
    .DESCRIPTION
        Provides parallel processing capabilities for independent file operations such as
        file validation, creation, and configuration loading. Uses PowerShell jobs for
        compatibility with PowerShell 5.1 while optimizing I/O throughput.
    
    .PARAMETER Operations
        Array of operation objects containing file operation details
    
    .PARAMETER MaxConcurrency
        Maximum number of parallel operations (default: 3)
    
    .PARAMETER TimeoutSeconds
        Timeout for each operation in seconds (default: 30)
    
    .OUTPUTS
        Array of operation results with success status and data
    
    .EXAMPLE
        $operations = @(
            @{ Type = "Validate"; Path = "settings.psd1"; Function = "Test-SettingsPsd1Exists" }
            @{ Type = "Validate"; Path = "strings.psd1"; Function = "Test-StringsPsd1Exists" }
            @{ Type = "Validate"; Path = "menu.psd1"; Function = "Test-MenuPsd1Exists" }
        )
        $results = Invoke-ParallelFileOperations -Operations $operations
    
    .NOTES
        Phase 4B optimization for file I/O performance
        Maintains PowerShell 5.1 compatibility using Start-Job
        Provides timeout protection and error handling
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [array]$Operations,
        [int]$MaxConcurrency = 3,
        [int]$TimeoutSeconds = 30
    )
    
    $functionName = $MyInvocation.MyCommand.Name
    Write-Verbose "[$functionName] Starting parallel file operations: $($Operations.Count) operations with max concurrency: $MaxConcurrency"
    
    # Phase 4B: Track performance metrics
    $startTime = Get-Date
    $results = @()
    $activeJobs = @()
    
    try
    {
        # Start jobs for each operation
        foreach ($operation in $Operations)
        {
            Write-Verbose "[$functionName] Starting job for operation: $($operation.Type) - $($operation.Path)"
            
            # Create script block for the operation
            $scriptBlock = {
                param($op)
                try
                {
                    $result = @{
                        Type = $op.Type
                        Path = $op.Path
                        Success = $false
                        Data = $null
                        Error = $null
                        StartTime = Get-Date
                    }
                    
                    # Execute the operation based on type
                    switch ($op.Type)
                    {
                        "Validate"
                        {
                            $result.Success = Test-Path -Path $op.Path
                            $result.Data = @{ Exists = $result.Success }
                        }
                        "Load"
                        {
                            if (Test-Path -Path $op.Path)
                            {
                                $content = Get-Content -Path $op.Path -Raw
                                $result.Data = $content | ConvertFrom-Json
                                $result.Success = $true
                            }
                            else
                            {
                                $result.Error = "File not found: $($op.Path)"
                            }
                        }
                        "Create"
                        {
                            if ($op.Content)
                            {
                                $op.Content | Out-File -FilePath $op.Path -Encoding UTF8 -Force
                                $result.Success = Test-Path -Path $op.Path
                                $result.Data = @{ Created = $result.Success }
                            }
                            else
                            {
                                $result.Error = "No content provided for file creation"
                            }
                        }
                        default
                        {
                            $result.Error = "Unknown operation type: $($op.Type)"
                        }
                    }
                    
                    $result.EndTime = Get-Date
                    $result.Duration = ($result.EndTime - $result.StartTime).TotalMilliseconds
                    return $result
                }
                catch
                {
                    return @{
                        Type = $op.Type
                        Path = $op.Path
                        Success = $false
                        Error = $_.Exception.Message
                        EndTime = Get-Date
                    }
                }
            }
            
            # Start the job
            $job = Start-Job -ScriptBlock $scriptBlock -ArgumentList $operation
            $activeJobs += @{
                Job = $job
                Operation = $operation
                StartTime = Get-Date
            }
            
            # Respect concurrency limit
            if ($activeJobs.Count -ge $MaxConcurrency)
            {
                Write-Verbose "[$functionName] Reached max concurrency ($MaxConcurrency), waiting for jobs to complete"
                $completedJobs = Wait-ParallelJobs -Jobs $activeJobs -TimeoutSeconds $TimeoutSeconds
                $results += $completedJobs.Results
                $activeJobs = $completedJobs.RemainingJobs
            }
        }
        
        # Wait for remaining jobs
        if ($activeJobs.Count -gt 0)
        {
            Write-Verbose "[$functionName] Waiting for remaining $($activeJobs.Count) jobs to complete"
            $completedJobs = Wait-ParallelJobs -Jobs $activeJobs -TimeoutSeconds $TimeoutSeconds
            $results += $completedJobs.Results
        }
        
        # Phase 4B: Log performance metrics
        $totalTime = (Get-Date) - $startTime
        $successCount = ($results | Where-Object { $_.Success }).Count
        Write-Verbose "[$functionName] Parallel operations completed: $successCount/$($Operations.Count) successful in $($totalTime.TotalMilliseconds)ms"
        
        return $results
    }
    catch
    {
        Write-Verbose "[$functionName] Error in parallel file operations: $($_.Exception.Message)"
        
        # Clean up any remaining jobs
        foreach ($jobInfo in $activeJobs)
        {
            if ($jobInfo.Job.State -eq 'Running')
            {
                Stop-Job -Job $jobInfo.Job
            }
            Remove-Job -Job $jobInfo.Job -Force
        }
        
        throw
    }
}

function Wait-ParallelJobs()
{
    <#
    .SYNOPSIS
        Helper function to wait for parallel jobs with timeout support.
    #>
    [CmdletBinding()]
    param(
        [array]$Jobs,
        [int]$TimeoutSeconds
    )
    
    $functionName = $MyInvocation.MyCommand.Name
    $results = @()
    $remainingJobs = @()
    
    foreach ($jobInfo in $Jobs)
    {
        $job = $jobInfo.Job
        $operation = $jobInfo.Operation
        $startTime = $jobInfo.StartTime
        
        try
        {
            # Calculate remaining timeout
            $elapsed = (Get-Date) - $startTime
            $remainingTimeout = $TimeoutSeconds - $elapsed.TotalSeconds
            
            if ($remainingTimeout -gt 0)
            {
                # Wait for job with timeout
                $completed = Wait-Job -Job $job -Timeout $remainingTimeout
                
                if ($completed)
                {
                    $result = Receive-Job -Job $job
                    $results += $result
                    Remove-Job -Job $job
                    Write-Verbose "[$functionName] Job completed for: $($operation.Path)"
                }
                else
                {
                    # Job timed out
                    Stop-Job -Job $job
                    Remove-Job -Job $job -Force
                    $results += @{
                        Type = $operation.Type
                        Path = $operation.Path
                        Success = $false
                        Error = "Operation timed out after $TimeoutSeconds seconds"
                        EndTime = Get-Date
                    }
                    Write-Verbose "[$functionName] Job timed out for: $($operation.Path)"
                }
            }
            else
            {
                # Already timed out
                Stop-Job -Job $job
                Remove-Job -Job $job -Force
                $results += @{
                    Type = $operation.Type
                    Path = $operation.Path
                    Success = $false
                    Error = "Operation timed out"
                    EndTime = Get-Date
                }
                Write-Verbose "[$functionName] Job already timed out for: $($operation.Path)"
            }
        }
        catch
        {
            $results += @{
                Type = $operation.Type
                Path = $operation.Path
                Success = $false
                Error = $_.Exception.Message
                EndTime = Get-Date
            }
            Write-Verbose "[$functionName] Job failed for: $($operation.Path) - $($_.Exception.Message)"
        }
    }
    
    return @{
        Results = $results
        RemainingJobs = $remainingJobs
    }
}