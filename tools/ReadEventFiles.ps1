$inputFolder = $pwd
$outputPath = "$pwd\Combined_Errors_Warnings.csv"

# How many events before and after each matching event to include for context
$contextSize = 5

# Level 0 = LogAlways, 1 = Critical, 2 = Error, 3 = Warning
$targetLevels = @(0, 1, 2, 3)

Write-Host "Scanning $inputFolder for .etl and .evtx files..." -ForegroundColor Cyan

$allEvents = Get-ChildItem -Path $inputFolder -File |
    Where-Object { $_.Extension -in '.etl', '.evtx' } |
    ForEach-Object {
        $currentFile = $_.Name
        $currentFilePath = $_.FullName
        Write-Host "Processing: $currentFile" -ForegroundColor Gray

        try
        {
            # Load all events into an array so we can index around matches for context
            $fileEvents = @(Get-WinEvent -Path $currentFilePath -Oldest -ErrorAction Stop)

            if ($fileEvents.Count -eq 0)
            {
                return
            }

            # Identify indices of events that match the target levels
            $matchIndices = [System.Collections.Generic.HashSet[int]]::new()
            for ($i = 0; $i -lt $fileEvents.Count; $i++)
            {
                if ($fileEvents[$i].Level -in $targetLevels)
                {
                    $matchIndices.Add($i) | Out-Null
                }
            }

            if ($matchIndices.Count -eq 0)
            {
                Write-Host "  No matching events in $currentFile" -ForegroundColor DarkGray
                return
            }

            Write-Host "  Found $($matchIndices.Count) matching event(s) in $currentFile" -ForegroundColor Gray

            # Expand each match by $contextSize on each side; SortedSet deduplicates and orders
            $includeIndices = [System.Collections.Generic.SortedSet[int]]::new()
            foreach ($idx in $matchIndices)
            {
                $start = [Math]::Max(0, $idx - $contextSize)
                $end = [Math]::Min($fileEvents.Count - 1, $idx + $contextSize)
                for ($j = $start; $j -le $end; $j++)
                {
                    $includeIndices.Add($j) | Out-Null
                }
            }

            # Emit each selected event; tag it as Match or Context
            foreach ($idx in $includeIndices)
            {
                $evt = $fileEvents[$idx]
                $role = if ($matchIndices.Contains($idx))
                {
                    'Match'
                }
                else
                {
                    'Context'
                }

                [PSCustomObject]@{
                    SourceFile       = $currentFile
                    EventIndex       = $idx
                    EventRole        = $role
                    TimeCreated      = $evt.TimeCreated
                    Id               = $evt.Id
                    Level            = $evt.Level
                    LevelDisplayName = $evt.LevelDisplayName
                    ProviderName     = $evt.ProviderName
                    Message          = $evt.Message
                }
            }
        }
        catch
        {
            if ($_.Exception.Message -notlike "*No events were found*")
            {
                Write-Warning "Could not process $currentFilePath`: $($_.Exception.Message)"
            }
            else
            {
                Write-Host "  No matching events in $currentFile" -ForegroundColor DarkGray
            }
        }
    }

if ($allEvents)
{
    $allEvents | Export-Csv -Path $outputPath -NoTypeInformation
    Write-Host "`nSuccess! Combined $($allEvents.Count) events into: $outputPath" -ForegroundColor Green
}
else
{
    Write-Host "`nNo matching events found in the provided files." -ForegroundColor Yellow
}

