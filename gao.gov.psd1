@{
    maxNumberOfDevicesAllowed = 20
    groupsToExclude = @{}
    companyName = 'Government Accountability Office'
    desiredAutopilotProfiles = @(
        'msb'
    )
    additionalScopes = @{}
    maxSerialNumberLength = 11
    maxUserMatchDisplay = 20
    minimumDevicePhysicalMemoryInGB = 16
    validateScopes = $false
    userPatternsToExclude = @(
        '-test',
        'onmicrosoft.com',
        '-rsa',
        '-cma',
        '-a',
        '-sup'
    )
    maxGroupMatchDisplay = 20
    deviceNamePrefix = 'w11-'
    privateSession = $true
    groupsToInclude = @(
        'sg_Office_365_License_G5_wth_windows_pilot',
        'sg_passwrd_hash_stage',
        'ITN-USR-CON-WIN-ENROLLMENT-PROD-ALLMSB',
        'ITN-USR-CON-WIN-ENROLLMENT-PROD-AUTOENROLLMENTENABLED'
    )
    settings = @{
        maxNumberOfDevicesAllowed = 20
        DesiredAutopilotProfiles = @(
            'msb'
        )
        MaxSerialNumberLength = 100
        GroupTag = 'MSB01'
        showLicenseBanner = $false
        MinimumDevicePhysicalMemoryInGB = 16
        MaxUserNameLength = 50
        domain = 'gao.gov'
        preferredBrowser = 'Chrome'
        appMode = 'full'
        deviceNamePrefix = 'w11-'
        privateSession = $true
        MinUsernameLength = 3
        userPatternsToExclude = @(
            '-cma',
            '-test',
            'onmicrosoft.com',
            '-sup',
            '-a'
        )
        MinSerialNumberLength = 7
    }
    release = 'master'
    showLicenseBanner = $false
    groupTag = 'MSB01'
}
