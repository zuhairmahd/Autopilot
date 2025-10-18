@{
    groupsToInclude = @()
    groupsToExclude = @()
    autopilotProfilesToInclude = @()
    autopilotDeviceAllowedVendors = @(
        'Dell',
        'VMWare'
    )
    domain = ''
    companyName = ''
    version = '1.3.0.0'
    validateScopes = $false
    maxWaitTime = 30
    showLicenseBanner = $true
    deviceContactThresholdInDays = 30
    checkStrongMapping = $false
    strongMappingOptional = $true
    migrateLegacyConfiguration = $true
    appModes = ,@('full')
    timeInSeconds = 60
    maxUserMatchDisplay = 20
    maxGroupMatchDisplay = 20
    release = 'master'
    repoInfo = @{
        repoName = 'Autopilot'
        baseURL = 'https://www.github.com'
        baseSourceURL = 'https://raw.githubusercontent.com'
        repoPath = 'zuhairmahd'
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
