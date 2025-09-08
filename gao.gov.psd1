@{
    maxGroupMatchDisplay = 20
    groupsToExclude = @{}
    companyName = 'Government Accountability Office'
    desiredAutopilotProfiles = @(
        'msb'
    )
    additionalScopes = @{}
    groupsToInclude = @(
        'sg_Office_365_License_G5_wth_windows_pilot',
        'sg_passwrd_hash_stage',
        'ITN-USR-CON-WIN-ENROLLMENT-PROD-ALLMSB',
        'ITN-USR-CON-WIN-ENROLLMENT-PROD-AUTOENROLLMENTENABLED'
    )
    maxSerialNumberLength = 11
    maxUserMatchDisplay = 20
    minimumDevicePhysicalMemoryInGB = 16
    validateScopes = $false
    settings = @{
        MinSerialNumberLength = 7
        MinUsernameLength = 3
        DesiredAutopilotProfiles = @(
            'msb'
        )
        MaxSerialNumberLength = 100
        GroupTag = 'MSB01'
        MinimumDevicePhysicalMemoryInGB = 16
        MaxUserNameLength = 50
        domain = 'gao.gov'
        preferredBrowser = 'Chrome'
        appMode = 'full'
        deviceNamePrefix = 'w11-'
        privateSession = $true
        maxNumberOfDevicesAllowed = 20
        userPatternsToExclude = @(
            '-cma',
            '-test',
            'onmicrosoft.com',
            '-sup',
            '-a'
        )
        showLicenseBanner = $false
    }
    deviceNamePrefix = 'w11-'
    privateSession = $true
    maxNumberOfDevicesAllowed = 20
    userPatternsToExclude = @(
        '-test',
        'onmicrosoft.com',
        '-rsa',
        '-cma',
        '-a',
        '-sup'
    )
    release = 'master'
    showLicenseBanner = $false
    groupTag = 'MSB01'
}
