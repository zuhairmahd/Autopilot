function Get-IntuneReport() {
    [CmdletBinding()]
    param(
        [string]$accessToken,
        [string]$reportInfo
    )

    $functionName = $MyInvocation.MyCommand.Name
    $uri = "deviceManagement/reports/exportJobs"
    #Check to make sure the $reportInfo is a valid JSON file (but do not convert it)
    Write-Host "Validating the provided reportInfo JSON string..."
    try {
        $json = $reportInfo | ConvertFrom-Json -ErrorAction Stop
        write-log -logFile $logFile -module $functionName -Message $json
        Write-Host "The provided reportInfo is a valid JSON string." -ForegroundColor Green
    }
    catch {
        Write-Host "The provided reportInfo is not a valid JSON string. Please provide a valid JSON string." -ForegroundColor Red
        Write-Log -logFile $logFile -module $functionName -Message "The provided reportInfo is not a valid JSON string. Please provide a valid JSON string." -logLevel Error
        return $null
    }

    if ($null -eq $output) {
        Write-Host "Initiating report generation..."
        Write-Log -logFile $logFile -module $functionName -Message "Initiating report generation..."
        $Output = CallGraphAPI -ResourcePath $uri -accessToken $accessToken -method POST -body $reportInfo
        Write-Log -logFile $logFile -module $functionName -Message "Report generation initiated. Report ID: $($Output.id) with status $($Output.status)."
    }
    else {
        Write-Host "Report generation already initiated. Report ID: $($Output.id) with status $($Output.status). Checking status..."
    }
    if ($null -ne $Output) {
        Write-Host "Report generation initiated. Report ID: $($Output.id) with status $($Output.status). Checking status..."
    }
    else {
        Write-Host "Failed to initiate report generation." -ForegroundColor Red
        Write-Log -logFile $logFile -module $functionName -Message "Failed to initiate report generation." -logLevel Error
        return $null
    }
    $newURI = "$uri/$($Output.id)"
    $newOutput = CallGraphAPI -ResourcePath $newURI -accessToken $accessToken -method GET
    #Get the start time
    $startTime = Get-Date
    while ($newOutput.status -ne "completed") {
        Write-Host "Current status: $($newOutput.status). Waiting for 10 seconds..."
        #provide information in minutes and seconds about how long the report has been running
        $elapsedTime = (Get-Date) - $startTime
        Write-Host "Elapsed time: $($elapsedTime.Minutes) minutes and $($elapsedTime.Seconds) seconds."
        Write-Log -logFile $logFile -module $functionName -Message "Current status: $($newOutput.status). Elapsed time: $($elapsedTime.Minutes) minutes and $($elapsedTime.Seconds) seconds."
        Start-Sleep -Seconds 10
        $newOutput = CallGraphAPI -ResourcePath $newURI -accessToken $accessToken -method GET
    }
    #if the status is complete, get the URL attribute and download the CSV
    if ($newOutput.status -eq "completed") {
        $downloadUrl = $newOutput.url
        Write-Host "Report generation completed. Downloading the CSV from: $downloadUrl"
        Write-Log -logFile $logFile -module $functionName -Message "Report generation completed. Downloading the CSV from: $downloadUrl"
        # Download the CSV file
        $downloadResult = Invoke-WebRequest -Uri $downloadUrl -OutFile "report.csv" -PassThru
        #Verify that the download was successful
        if ($downloadResult.StatusCode -eq 200) {
            Write-Host "Report downloaded successfully to report.csv" -ForegroundColor Green
            Write-Log -logFile $logFile -module $functionName -Message "Report downloaded successfully to report.csv"
        }
        else {
            Write-Host "Failed to download the report. Status code: $($downloadResult.StatusCode)" -ForegroundColor Red
            Write-Log -logFile $logFile -module $functionName -Message "Failed to download the report. Status code: $($downloadResult.StatusCode)" -logLevel Error
        }
    }
    else {
        Write-Host "Report generation failed with status: $($newOutput.status)" -ForegroundColor Red
    }
}