@{
    groupsToInclude = @(
        @{
            name = 'sg_Office_365_License_G5_wth_windows_pilot'
            id = '74d8cfe5-7934-4bd7-bcf3-593dcc6639ed'
        },
        @{
            name = 'sg_passwrd_hash_stage'
            id = 'be87a9ef-3e44-4e6b-8a9e-d1696e2f7db5'
        },
        @{
            name = 'ITN-USR-CON-WIN-ENROLLMENT-PROD-ALLMSB'
            id = '27d943bc-77cc-44eb-9f81-13c76841129b'
        }
    )
    groupsToExclude = @()
    autopilotProfilesToInclude = @()
    domain = 'gao.gov'
    companyName = 'Government Accountability Office'
    version = '1.3.0.0'
    validateScopes = $false
    maxWaitTime = 30
    showLicenseBanner = $false
    deviceContactThresholdInDays = 30
    appMode = 'registration'
    timeInSeconds = 60
    maxUserMatchDisplay = 10
    maxGroupMatchDisplay = 10
    release = 'lhm'
    repoInfo = @{
        baseURL = 'https://www.github.com'
        repoPath = 'zuhairmahd'
        repoName = 'Autopilot'
        baseSourceURL = 'https://raw.githubusercontent.com'
    }
    autoUpdate = $true
    deviceNamePrefix = 'w11-'
    operatingSystem = 'Windows'
    minUsernameLength = 3
    maxUserNameLength = 50
    maxSerialNumberLength = 11
    minSerialNumberLength = 7
    minimumDevicePhysicalMemoryInGB = 16
    maxNumberOfDevicesAllowed = 20
    preferredBrowser = 'Chrome'
    privateSession = $true
    userPatternsToExclude = @(
        '-test',
        'onmicrosoft.com',
        '-cma',
        '-a',
        '-rsa',
        '-sup'
    )
    groupPatternsToExclude = @()
    groupTag = 'MSB01'
    assignedUser = ''
    additionalScopes = @()
    desiredAutopilotProfiles = @(
        'msb'
    )
}
