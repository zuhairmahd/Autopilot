function Get-IntuneReport() {
    [CmdletBinding()]
    param(
        [string]$accessToken,
        [Parameter(Mandatory = $true)]
        [string]$reportInfo,
        [int]$waitTimeBetweenChecks = 10,
        [switch]$uncompress,
        [string]$uncompressPath
    )

    $functionName = $MyInvocation.MyCommand.Name
    $uri = "deviceManagement/reports/exportJobs"
    $success = $false
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
        return $success
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
        return $success
    }
    $newURI = "$uri/$($Output.id)"
    $newOutput = CallGraphAPI -ResourcePath $newURI -accessToken $accessToken -method GET
    #Get the start time
    $startTime = Get-Date
    while ($newOutput.status -in @("notStarted", "inProgress")) {
        Write-Host "Current status: $($newOutput.status). Waiting for $waitTimeBetweenChecks more seconds..."
        #provide information in minutes and seconds about how long the report has been running
        $elapsedTime = (Get-Date) - $startTime
        Write-Host "Elapsed time: $($elapsedTime.Minutes) minutes and $($elapsedTime.Seconds) seconds."
        Write-Log -logFile $logFile -module $functionName -Message "Current status: $($newOutput.status). Elapsed time: $($elapsedTime.Minutes) minutes and $($elapsedTime.Seconds) seconds."
        Start-Sleep -Seconds $waitTimeBetweenChecks
        $newOutput = CallGraphAPI -ResourcePath $newURI -accessToken $accessToken -method GET
    }
    #if the status is complete, get the URL attribute and download the CSV
    if ($newOutput.status -eq "completed") {
        $downloadUrl = $newOutput.url
        $reportName = $newOutput.reportName
        $compressedReportName = "$reportName-$($newOutput.id)-$(Get-Date -Format 'yyyyMMddHHmmss' ).zip"
        Write-Host "Report generation completed. Downloading the report to $compressedReportName" -ForegroundColor Green
        Write-Log -logFile $logFile -module $functionName -Message "Report generation completed. Downloading the report from: $downloadUrl"
        # Download the CSV file
        $downloadResult = Invoke-WebRequest -Uri $downloadUrl -OutFile $compressedReportName -PassThru -UseBasicParsing
        #Verify that the download was successful
        if ($downloadResult.StatusCode -eq 200) {
            Write-Host "Report downloaded successfully to`n $compressedReportName" -ForegroundColor Green
            Write-Log -logFile $logFile -module $functionName -Message "Report downloaded successfully to $compressedReportName"
            if ($uncompress) {
                #unzip the downloaded file
                $unzipPath = if ($uncompressPath) { $uncompressPath } else { Join-Path -Path (Get-Location) -ChildPath "$($reportName)-$($newOutput.id)-$(Get-Date -Format 'yyyyMMddHHmmss')" }
                Write-Host "Uncompressing the report to $unzipPath" -ForegroundColor Green
                Write-Log -logFile $logFile -module $functionName -Message "Uncompressing the report to $unzipPath"
                if (-not (Test-Path -Path $unzipPath)) {
                    New-Item -ItemType Directory -Path $unzipPath | Out-Null
                    write-log -logFile $logFile -module $functionName -Message "Created directory $unzipPath for uncompressed report."
                }
                Expand-Archive -Path $compressedReportName -DestinationPath $unzipPath -Force
            }
            $success = $true
        }
        else {
            Write-Host "Failed to download the report. Status code: $($downloadResult.StatusCode)" -ForegroundColor Red
            Write-Log -logFile $logFile -module $functionName -Message "Failed to download the report. Status code: $($downloadResult.StatusCode)" -logLevel Error
        }
    }
    else {
        Write-Host "Report generation failed with status: $($newOutput.status)" -ForegroundColor Red
    }
    return $success
}