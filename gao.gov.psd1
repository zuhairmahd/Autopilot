@{
    maxGroupMatchDisplay            = 20
    groupsToExclude                 = @{}
    companyName                     = 'Government Accountability Office'
    desiredAutopilotProfiles        = @(
        'msb'
    )
    additionalScopes                = @{}
    groupsToInclude                 = @(
        'sg_Office_365_License_G5_wth_windows_pilot',
        'sg_passwrd_hash_stage',
        'ITN-USR-CON-WIN-ENROLLMENT-PROD-ALLMSB'
    )
    maxSerialNumberLength           = 11
    maxUserMatchDisplay             = 20
    minimumDevicePhysicalMemoryInGB = 16
    validateScopes                  = $false
    MinSerialNumberLength           = 7
    MinUsernameLength               = 3
    GroupTag                        = 'MSB01'
    MaxUserNameLength               = 50
    domain                          = 'gao.gov'
    preferredBrowser                = 'Chrome'
    appMode                         = 'full'
    deviceNamePrefix                = 'w11-'
    privateSession                  = $true
    maxNumberOfDevicesAllowed       = 20
    userPatternsToExclude           = @(
        '-cma',
        '-test',
        'onmicrosoft.com',
        '-sup',
        '-a'
    )
    showLicenseBanner               = $false
    release                         = 'master'
}
