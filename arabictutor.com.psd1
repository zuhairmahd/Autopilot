@{
    privateSession = $false
    groupsToExclude = @{}
    desiredAutopilotProfiles = @()
    maxUserMatchDisplay = '10'
    appMode = 'full'
    userPatternsToExclude = @(
        '-test',
        'onmicrosoft.com'
    )
    minimumDevicePhysicalMemoryInGB = 8
    maxNumberOfDevicesAllowed = 15
    maxGroupMatchDisplay = 10
    autoUpdate = $true
    preferredBrowser = 'Chrome'
    minUsernameLength = 3
    version = '1.0.0'
    operatingSystem = 'Windows'
    showLicenseBanner = $false
    maxUserNameLength = 50
    release = 'master'
    groupsToInclude = @(
        @{
            id = 'f1752bdb-7abd-438c-a54e-7faca7cecf61'
            name = 'Cloud Managed PC User 3.26.2023_18:43:44'
        }
    )
    repo = 'Github'
    groupPatternsToExclude = @()
    timeInSeconds = '60'
    deviceContactThresholdInDays = 30
    additionalScopes = @{}
    minSerialNumberLength = 7
    companyName = 'ArabicTutor'
    maxSerialNumberLength = 50
    maxWaitTime = '30'
    domain = 'arabictutor.com'
    deviceNamePrefix = ''
}
