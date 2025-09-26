@{
    groupsToInclude                 = @()
    groupsToExclude                 = @()
    autopilotProfilesToInclude      = @()
    domain                          = 'arabictutor.com'
    companyName                     = ''
    autopilotDeviceAllowedVendors   = @(
        'Dell Inc.',
        'VMWare'
    )
    version                         = '1.3.0.0'
    validateScopes                  = $true
    maxWaitTime                     = 30
    showLicenseBanner               = $true
    deviceContactThresholdInDays    = 30
    checkStrongMapping              = $false
    strongMappingOptional           = $true
    appMode                         = 'full'
    timeInSeconds                   = 60
    maxUserMatchDisplay             = 10
    maxGroupMatchDisplay            = 10
    release                         = 'master'
    repoInfo                        = @{
        repoName      = 'Autopilot'
        repoPath      = 'zuhairmahd'
        baseSourceURL = 'https://raw.githubusercontent.com'
        baseURL       = 'https://www.github.com'
    }
    autoUpdate                      = $true
    deviceNamePrefix                = ''
    operatingSystem                 = 'Windows'
    minUsernameLength               = 3
    maxUserNameLength               = 50
    maxSerialNumberLength           = 50
    minSerialNumberLength           = 7
    minimumDevicePhysicalMemoryInGB = 8
    maxNumberOfDevicesAllowed       = 15
    preferredBrowser                = 'Chrome'
    privateSession                  = $false
    userPatternsToExclude           = @(
        '-test',
        'onmicrosoft.com'
    )
    groupPatternsToExclude          = @()
    groupTag                        = ''
    assignedUser                    = ''
    additionalScopes                = @()
}
