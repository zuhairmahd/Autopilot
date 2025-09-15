@{
    groupsToInclude = @(
        @{
            name = 'Cloud Managed PC User 3.26.2023_18:43:44'
            id = 'f1752bdb-7abd-438c-a54e-7faca7cecf61'
        }
    )
    groupsToExclude = @(
        @{
            name = 'autoPilot-device-preparation-user'
            id = 'a0138743-e4fe-45db-a231-737b10a2615d'
        }
    )
    autopilotProfilesToInclude = @(
        @{
            name = 'windowsCloudConfig Autopilot profile'
            id = 'edaca6f4-58e4-4a55-a985-52c8f74fb6c4'
        },
        @{
            name = 'Hybrid join profile'
            id = '78a4c8b8-c7fb-4fbb-9db6-7c91eb1db7d1'
        }
    )
    domain = 'arabictutor.com'
    companyName = 'ZM Consulting'
    version = '4.0.0.30055'
    validateScopes = $false
    maxWaitTime = 30
    showLicenseBanner = $false
    deviceContactThresholdInDays = 30
    appMode = 'full'
    timeInSeconds = 60
    maxUserMatchDisplay = 10
    maxGroupMatchDisplay = 10
    release = 'master'
    repoInfo = @{
        repoPath = 'zuhairmahd'
        baseSourceURL = 'https://raw.githubusercontent.com'
        baseURL = 'https://www.github.com'
        repoName = 'Autopilot'
    }
    autoUpdate = $false
    deviceNamePrefix = 'vmware'
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
    groupTag = 'ENTRA'
    assignedUser = ''
    additionalScopes = @()
}
