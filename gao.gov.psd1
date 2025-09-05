@{
    'additionalScopes' = @{
    }
    'groupsToExclude' = @{
    }
    'groupsToInclude' = @(
        'sg_Office_365_License_G5_wth_windows_pilot',
        'sg_passwrd_hash_stage',
        'ITN-USR-CON-WIN-ENROLLMENT-PROD-ALLMSB',
        'ITN-USR-CON-WIN-ENROLLMENT-PROD-AUTOENROLLMENTENABLED'
    )
    'settings' = @{
        'MinSerialNumberLength' = 7
        'MinUsernameLength' = 3
        'DesiredAutopilotProfiles' = @(
            'msb'
        )
        'MaxSerialNumberLength' = 100
        'GroupTag' = 'MSB01'
        'MinimumDevicePhysicalMemoryInGB' = 16
        'MaxUserNameLength' = 50
        'domain' = 'gao.gov'
        'preferredBrowser' = 'Chrome'
        'appMode' = 'test'
        'deviceNamePrefix' = 'w11-'
        'privateSession' = $true
        'maxNumberOfDevicesAllowed' = 20
        'userPatternsToExclude' = @(
            '-cma',
            '-test',
            'onmicrosoft.com',
            '-sup',
            '-a'
        )
        'showLicenseBanner' = $false
    }
}
