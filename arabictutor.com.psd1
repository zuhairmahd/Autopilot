@{
    desiredAutopilotProfiles = @()
    privateSession = $false
    groupsToExclude = @{}
    companyName = 'ZM Consulting'
    maxUserMatchDisplay = 20
    appMode = 'full'
    minimumDevicePhysicalMemoryInGB = 8
    maxNumberOfDevicesAllowed = 15
    maxGroupMatchDisplay = 20
    maxWaitTime = '30'
    autoUpdate = $true
    preferredBrowser = 'Chrome'
    maxSerialNumberLength = 50
    minUsernameLength = 3
    version = '1.0.0'
    operatingSystem = 'Windows'
    minSerialNumberLength = 7
    maxUserNameLength = 50
    validateScopes = $false
    groupsToInclude = @(
        @{
            id = 'f1752bdb-7abd-438c-a54e-7faca7cecf61'
            name = 'Cloud Managed PC User 3.26.2023_18:43:44'
        },
        @{
            id = '57d1aba1-180a-4856-b497-bc6d5014f06f'
            name = 'AutoPilot'
        }
    )
    groupTag = 'ENTRA'
    repo = 'Github'
    groupPatternsToExclude = @()
    release = 'master'
    deviceContactThresholdInDays = 30
    additionalScopes = @{}
    userPatternsToExclude = @(
        '-test',
        'onmicrosoft.com'
    )
    timeInSeconds = '60'
    showLicenseBanner = $false
    domain = 'arabictutor.com'
    deviceNamePrefix = 'vmware'
}
