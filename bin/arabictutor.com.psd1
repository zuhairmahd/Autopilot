@{
    groupsToInclude = @(
        @{
            id = 'f1752bdb-7abd-438c-a54e-7faca7cecf61'
            name = 'Cloud Managed PC User 3.26.2023_18:43:44'
        }
    )
    groupsToExclude = @(
        @{
            id = 'a0138743-e4fe-45db-a231-737b10a2615d'
            name = 'autoPilot-device-preparation-user'
        }
    )
    autopilotProfilesToInclude = @(
        @{
            id = 'edaca6f4-58e4-4a55-a985-52c8f74fb6c4'
            name = 'windowsCloudConfig Autopilot profile'
        },
        @{
            id = '78a4c8b8-c7fb-4fbb-9db6-7c91eb1db7d1'
            name = 'Hybrid join profile'
        }
    )
    domain = 'arabictutor.com'
    companyName = 'ZM Consulting'
    version = '4.0.0.30055'
    validateScopes = $false
    maxWaitTime = 30
    showLicenseBanner = $false
    deviceContactThresholdInDays = 30
    checkStrongMapping = $false
    strongMappingOptional = $true
    appMode = 'full'
    timeInSeconds = 60
    maxUserMatchDisplay = 10
    maxGroupMatchDisplay = 10
    release = 'master'
    repoInfo = @{
        repoPath = 'zuhairmahd'
        baseURL = 'https://www.github.com'
        baseSourceURL = 'https://raw.githubusercontent.com'
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
