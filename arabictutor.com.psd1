@{
    'additionalScopes' = @{
    }
    'groupsToExclude' = @{
    }
    'groupsToInclude' = @(
        @{
            'id' = $null
            'name' = 'autopilot'
        }
    )
    'settings' = @{
        'operatingSystem' = 'Windows'
        'repo' = 'Github'
        'minUsernameLength' = 3
        'timeInSeconds' = '60'
        'desiredAutopilotProfiles' = @(
        )
        'maxSerialNumberLength' = 50
        'maxUserMatchDisplay' = '10'
        'maxWaitTime' = '30'
        'showLicenseBanner' = $true
        'autoUpdate' = $true
        'minimumDevicePhysicalMemoryInGB' = 8
        'maxUserNameLength' = 50
        'domain' = 'arabictutor.com'
        'preferredBrowser' = 'Chrome'
        'appMode' = 'full'
        'groupPatternsToExclude' = @(
        )
        'maxGroupMatchDisplay' = 10
        'deviceNamePrefix' = ''
        'privateSession' = $false
        'maxNumberOfDevicesAllowed' = 15
        'userPatternsToExclude' = @(
            '-test',
            'onmicrosoft.com'
        )
        'release' = 'master'
        'minSerialNumberLength' = 7
        'deviceContactThresholdInDays' = 30
    }
}
