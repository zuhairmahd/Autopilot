@{
    groupsToInclude = @()
    groupsToExclude = @()
    autopilotProfilesToInclude = @()
    autopilotDeviceAllowedVendors = @()
    domain = ''
    companyName = ''
    version = '4.1.0.30119'
    validateScopes = $false
    maxWaitTime = 30
    showLicenseBanner = $true
    deviceContactThresholdInDays = 30
    checkStrongMapping = $false
    strongMappingOptional = $true
    appModes = @(
        'full'
    )
    timeInSeconds = 60
    maxUserMatchDisplay = 20
    maxGroupMatchDisplay = 20
    release = 'master'
    repoInfo = @{
        repoPath = 'zuhairmahd'
        baseURL = 'https://www.github.com'
        baseSourceURL = 'https://raw.githubusercontent.com'
        repoName = 'Autopilot'
    }
    autoUpdate = $true
    deviceNamePrefix = ''
    operatingSystem = 'Windows'
    minUsernameLength = 3
    maxUserNameLength = 50
    maxSerialNumberLength = 50
    minSerialNumberLength = 7
    minimumDevicePhysicalMemoryInGB = 8
    maxNumberOfDevicesAllowed = 15
    preferredBrowser = 'Chrome'
    privateSession = $false
    userPatternsToExclude = @(
        '-test',
        'onmicrosoft.com'
    )
    groupPatternsToExclude = @()
    groupTag = ''
    assignedUser = ''
    additionalScopes = @()
}
