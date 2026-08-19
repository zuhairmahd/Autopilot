function Get-IntuneBaselineSettings {
    <#
    .SYNOPSIS
        Modular function: retrieves every setting (and its current value) of an Intune Security Baseline
        on the Settings Catalog platform, given a policy id and an access token.

    .DESCRIPTION
        Get-IntuneBaselineSettings takes a deviceManagementConfigurationPolicy id (the "baseline" - the
        historical "intent" terminology carries over from the older, now-migrated API, but this targets
        the current Settings Catalog platform: deviceManagement/configurationPolicies) and a bearer token,
        and returns its flattened settings as CSV text, JSON text, or PowerShell objects.

        No dependency on the Microsoft.Graph SDK - only Invoke-RestMethod. Bring your own token
        (e.g. from MSAL.PS, az account get-access-token, or your own auth flow).

        Docs:
          https://learn.microsoft.com/en-us/graph/api/intune-deviceconfigv2-devicemanagementconfigurationpolicy-get?view=graph-rest-beta
          https://learn.microsoft.com/en-us/graph/api/resources/intune-deviceconfigv2-devicemanagementconfigurationtemplatefamily?view=graph-rest-beta

        Required permission on the token: DeviceManagementConfiguration.Read.All.

    .PARAMETER BaselineId
        The Id (GUID) of the deviceManagementConfigurationPolicy to export. Aliases: -IntentId, -PolicyId.

    .PARAMETER AccessToken
        A bearer token for Graph beta with DeviceManagementConfiguration.Read.All.

    .PARAMETER OutputFormat
        'Csv' (default) - returns a single CSV-formatted string (as produced by ConvertTo-Csv).
        'Json' - returns a single JSON-formatted string.
        'Object' - returns the raw array of PSCustomObject rows, for further pipeline processing.

    .PARAMETER GraphBaseUri
        Override for sovereign clouds, e.g. https://graph.microsoft.us/beta. Defaults to the public cloud.

    .EXAMPLE
        $csv = Get-IntuneBaselineSettings -BaselineId $id -AccessToken $token
        $csv | Set-Content .\baseline.csv -Encoding UTF8

    .EXAMPLE
        $rows = Get-IntuneBaselineSettings -BaselineId $id -AccessToken $token -OutputFormat Object
        $rows | Where-Object Value -eq $null

    .EXAMPLE
        Get-IntuneBaselineSettings -BaselineId $id -AccessToken $token -OutputFormat Json | Set-Content .\baseline.json
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)]
        [Alias('IntentId', 'PolicyId')]
        [string]$BaselineId,
        [Parameter(Mandatory, Position = 1)]
        [string]$AccessToken,
        [Parameter(Position = 2)]
        [ValidateSet('Csv', 'Json', 'Object')]
        [string]$OutputFormat = 'Csv',
        [string]$GraphBaseUri = 'https://graph.microsoft.com/beta'
    )

    function Invoke-IntuneGraphGetAll {
        <#
        Private helper: GETs a Graph URI and follows @odata.nextLink until exhausted.
        Returns the combined 'value' array, or the single object if the response has no 'value' collection.
    #>
        [CmdletBinding()]
        param(
            [Parameter(Mandatory)][string]$Uri,
            [Parameter(Mandatory)][hashtable]$Headers
        )

        $results = [System.Collections.Generic.List[object]]::new()
        $nextUri = $Uri

        while ($nextUri) {
            try {
                $response = Invoke-RestMethod -Method GET -Uri $nextUri -Headers $Headers -ErrorAction Stop
            }
            catch {
                $status = $null
                if ($_.Exception.Response) { $status = [int]$_.Exception.Response.StatusCode }
                switch ($status) {
                    401 { throw "Graph returned 401 Unauthorized calling '$nextUri'. The access token is missing, expired, or lacks DeviceManagementConfiguration.Read.All." }
                    403 { throw "Graph returned 403 Forbidden calling '$nextUri'. The token's app/user is authenticated but not authorized for this resource." }
                    404 { throw "Graph returned 404 Not Found calling '$nextUri'. Check the BaselineId is a valid deviceManagementConfigurationPolicy id." }
                    default { throw "Graph request to '$nextUri' failed: $($_.Exception.Message)" }
                }
            }

            if ($response.PSObject.Properties.Name -contains 'value') {
                foreach ($item in $response.value) { $results.Add($item) }
                $nextUri = $response.'@odata.nextLink'
            }
            else {
                return $response  # single-object response
            }
        }

        return $results
    }

    function Resolve-IntuneChoiceValue {
        <# Private helper: resolves a choice setting's opaque option id to its human-readable displayName. #>
        param($Definition, $RawValue)

        if ($Definition -and $Definition.options) {
            $opt = $Definition.options | Where-Object { $_.itemId -eq $RawValue } | Select-Object -First 1
            if ($opt -and $opt.displayName) { return $opt.displayName }
        }
        return $RawValue
    }

    function Expand-IntuneSettingInstance {
        <#
        Private helper: recursively flattens a (possibly nested) deviceManagementConfigurationSettingInstance
        into one or more rows. Handles simple, simple-collection, choice, choice-collection, and
        group-collection instance kinds. Anything unrecognized falls back to a raw JSON dump so nothing
        is silently dropped.
    #>
        param(
            [Parameter(Mandatory)] $Instance,
            [Parameter(Mandatory)] [hashtable]$DefLookup,
            [string]$ParentDefinitionId
        )

        $rows = [System.Collections.Generic.List[object]]::new()

        $type = $Instance.'@odata.type' -replace '^#?microsoft\.graph\.', ''
        $defId = $Instance.settingDefinitionId
        $def = $DefLookup[$defId]
        $name = if ($def -and $def.displayName) { $def.displayName } else { $defId }

        switch -Wildcard ($type) {

            '*ChoiceSettingCollectionInstance' {
                $vals = @()
                foreach ($cv in $Instance.choiceSettingCollectionValue) {
                    $vals += (Resolve-IntuneChoiceValue -Definition $def -RawValue $cv.value)
                    foreach ($child in $cv.children) {
                        $rows.AddRange([object[]](Expand-IntuneSettingInstance -Instance $child -DefLookup $DefLookup -ParentDefinitionId $defId))
                    }
                }
                $rows.Add([PSCustomObject]@{
                        DefinitionId       = $defId
                        SettingName        = $name
                        Value              = ($vals -join '; ')
                        InstanceType       = $type
                        ParentDefinitionId = $ParentDefinitionId
                    })
            }

            '*ChoiceSettingInstance' {
                $cv = $Instance.choiceSettingValue
                $resolved = Resolve-IntuneChoiceValue -Definition $def -RawValue $cv.value
                $rows.Add([PSCustomObject]@{
                        DefinitionId       = $defId
                        SettingName        = $name
                        Value              = $resolved
                        InstanceType       = $type
                        ParentDefinitionId = $ParentDefinitionId
                    })
                foreach ($child in $cv.children) {
                    $rows.AddRange([object[]](Expand-IntuneSettingInstance -Instance $child -DefLookup $DefLookup -ParentDefinitionId $defId))
                }
            }

            '*SimpleSettingCollectionInstance' {
                $vals = $Instance.simpleSettingCollectionValue | ForEach-Object { $_.value }
                $rows.Add([PSCustomObject]@{
                        DefinitionId       = $defId
                        SettingName        = $name
                        Value              = ($vals -join '; ')
                        InstanceType       = $type
                        ParentDefinitionId = $ParentDefinitionId
                    })
            }

            '*SimpleSettingInstance' {
                $rows.Add([PSCustomObject]@{
                        DefinitionId       = $defId
                        SettingName        = $name
                        Value              = $Instance.simpleSettingValue.value
                        InstanceType       = $type
                        ParentDefinitionId = $ParentDefinitionId
                    })
            }

            '*GroupSettingCollectionInstance' {
                foreach ($grp in $Instance.groupSettingCollectionValue) {
                    foreach ($child in $grp.children) {
                        $rows.AddRange([object[]](Expand-IntuneSettingInstance -Instance $child -DefLookup $DefLookup -ParentDefinitionId $defId))
                    }
                }
            }

            default {
                # Unrecognized instance kind - keep the raw JSON so nothing is silently lost.
                $rows.Add([PSCustomObject]@{
                        DefinitionId       = $defId
                        SettingName        = $name
                        Value              = ($Instance | ConvertTo-Json -Compress -Depth 8)
                        InstanceType       = $type
                        ParentDefinitionId = $ParentDefinitionId
                    })
            }
        }

        return $rows
    }

    if ([string]::IsNullOrWhiteSpace($AccessToken)) {
        throw "AccessToken is required."
    }

    $headers = @{ Authorization = "Bearer $AccessToken" }

    Write-Verbose "Fetching policy metadata for $BaselineId"
    $policy = Invoke-IntuneGraphGetAll -Uri "$GraphBaseUri/deviceManagement/configurationPolicies('$BaselineId')" -Headers $headers

    if (-not $policy -or -not $policy.id) {
        throw "No deviceManagementConfigurationPolicy found for Id '$BaselineId'."
    }

    Write-Verbose "Fetching settings (with expanded definitions) for '$($policy.name)'"
    $settingsUri = "$GraphBaseUri/deviceManagement/configurationPolicies('$BaselineId')/settings?`$expand=settingDefinitions&`$top=1000"
    $settingItems = @(Invoke-IntuneGraphGetAll -Uri $settingsUri -Headers $headers)

    # Build one combined definitionId -> definition lookup from every expanded settingDefinitions array
    $defLookup = @{}
    foreach ($item in $settingItems) {
        foreach ($def in $item.settingDefinitions) {
            if ($def.id -and -not $defLookup.ContainsKey($def.id)) {
                $defLookup[$def.id] = $def
            }
        }
    }

    $rows = [System.Collections.Generic.List[object]]::new()
    foreach ($item in $settingItems) {
        $rows.AddRange([object[]](Expand-IntuneSettingInstance -Instance $item.settingInstance -DefLookup $defLookup -ParentDefinitionId $null))
    }

    Write-Verbose "Flattened $($rows.Count) settings from policy '$($policy.name)'"

    switch ($OutputFormat) {
        'Object' { return $rows }
        'Json' { return ($rows | ConvertTo-Json -Depth 10) }
        'Csv' { return ($rows | ConvertTo-Csv -NoTypeInformation) }
    }
}