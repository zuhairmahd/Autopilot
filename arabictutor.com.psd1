@{
    privateSession = $false
    groupsToExclude = @{}
    desiredAutopilotProfiles = @()
    maxUserMatchDisplay = 20
    appMode = 'full'
    userPatternsToExclude = @(
        '-test',
        'onmicrosoft.com'
    )
    minimumDevicePhysicalMemoryInGB = 8
    maxGroupMatchDisplay = 20
    autoUpdate = $true
    preferredBrowser = 'Chrome'
    minUsernameLength = 3
    version = '1.0.0'
    operatingSystem = 'Windows'
    minSerialNumberLength = 7
    maxUserNameLength = 50
    validateScopes = $false
    showLicenseBanner = $false
    timeInSeconds = '60'
    groupsToInclude = @(
        @{
            id = 'f1752bdb-7abd-438c-a54e-7faca7cecf61'
            name = 'Cloud Managed PC User 3.26.2023_18:43:44'
        }
    )
    groupTag = 'ENTRA'
    repo = 'Github'
    groupPatternsToExclude = @()
    companyName = 'ZM Consulting'
    release = 'master'
    deviceContactThresholdInDays = 30
    additionalScopes = @{}
    maxNumberOfDevicesAllowed = 15
    maxSerialNumberLength = 50
    maxWaitTime = '30'
    domain = 'arabictutor.com'
    deviceNamePrefix = 'vmware'
}
