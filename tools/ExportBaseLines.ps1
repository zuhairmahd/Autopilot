<#
.SYNOPSIS
    Exports every setting (and its current value) of an Intune Security Baseline to CSV or JSON.

.DESCRIPTION
    Baselines now live in one of two places depending on when they were created/migrated:

      - NEW (default): the unified Settings Catalog platform, as a deviceManagementConfigurationPolicy
        whose templateReference.templateFamily = 'baseline'. Microsoft migrated Endpoint Security
        policies (including baselines) here; as of late March 2025 the old beta APIs below no longer
        support creating/managing them, and many tenants will now return zero baselines from /intents.
        Reference: https://learn.microsoft.com/en-us/graph/api/resources/intune-deviceconfigv2-devicemanagementconfigurationtemplatefamily?view=graph-rest-beta

      - LEGACY (-Legacy switch): the older deviceManagementIntent API
        (deviceManagement/intents -> categories -> settings), for baselines that predate the migration
        and have not been recreated on the new platform.
        Reference: https://learn.microsoft.com/en-us/graph/api/resources/intune-deviceintent-securitybaselinetemplate?view=graph-rest-beta

    In both modes: if -BaselineId is omitted, the script lists matching baselines and lets you pick one
    from a numbered, keyboard-only menu.

    Required permission: DeviceManagementConfiguration.Read.All (delegated or application).

.PARAMETER BaselineId
    Optional. The Id (GUID) of the baseline to export.
      - New (default) mode: the deviceManagementConfigurationPolicy id.
      - Legacy mode: the deviceManagementIntent id.
    If omitted, the script lists candidates and prompts you to choose one.

.PARAMETER Legacy
    Use the old deviceManagement/intents API instead of the Settings Catalog. Only useful for baselines
    that have not been migrated to the new platform (rare on current tenants).

.PARAMETER IncludeAllPolicies
    When browsing the menu (i.e. -BaselineId was not supplied), also list non-baseline policies/intents.
    By default the menu is filtered to baseline template types only.

.PARAMETER AccessToken
    Optional. A bearer token for Graph beta, if you're already handling auth yourself.
    If omitted, the script falls back to Connect-MgGraph / Invoke-MgGraphRequest (SDK).

.PARAMETER OutputPath
    Where to write the export. Defaults to .\SecurityBaseline_<Name>_<Id>.csv (or .json with -AsJson).

.PARAMETER AsJson
    Export as JSON instead of CSV.

.EXAMPLE
    .\Get-SecurityBaselineSettings.ps1
    Lists all baselines on the Settings Catalog platform and prompts you to choose one.

.EXAMPLE
    .\Get-SecurityBaselineSettings.ps1 -BaselineId 6c6a1caf-1111-2222-3333-abcdef123456

.EXAMPLE
    .\Get-SecurityBaselineSettings.ps1 -Legacy
    Browses baselines on the old deviceManagement/intents API instead.
#>

[CmdletBinding()]
param(
    [string]$BaselineId,
    [switch]$Legacy,
    [switch]$IncludeAllPolicies,
    [string]$AccessToken,
    [string]$OutputPath,
    [switch]$AsJson
)

$ErrorActionPreference = 'Stop'
$graphBase = 'https://graph.microsoft.com/beta'

#region --- Request helper (works with either a raw bearer token or Connect-MgGraph) ---

$useSdk = -not $AccessToken

if ($useSdk) {
    if (-not (Get-Module -ListAvailable -Name Microsoft.Graph.Authentication)) {
        throw "Microsoft.Graph.Authentication module not found. Install-Module Microsoft.Graph.Authentication, or pass -AccessToken to use your own auth."
    }
    Import-Module Microsoft.Graph.Authentication -ErrorAction Stop
    if (-not (Get-MgContext)) {
        Connect-MgGraph -NoWelcome -Scopes 'DeviceManagementConfiguration.Read.All'
    }
}

function Invoke-GraphGetAll {
    <#
        GETs a Graph URI and follows @odata.nextLink until exhausted.
        Returns the combined 'value' array, or the single object if the response has no 'value' collection.
    #>
    param([Parameter(Mandatory)][string]$Uri)

    $results = [System.Collections.Generic.List[object]]::new()
    $nextUri = $Uri

    while ($nextUri) {
        if ($useSdk) {
            # -OutputType PSObject is required: Invoke-MgGraphRequest defaults to returning nested
            # Hashtables, and dot-notation property access (e.g. $p.name) silently returns $null
            # against a Hashtable instead of erroring - it just looks like every field is blank.
            $response = Invoke-MgGraphRequest -Method GET -Uri $nextUri -OutputType PSObject
        }
        else {
            $headers = @{ Authorization = "Bearer $AccessToken" }
            $response = Invoke-RestMethod -Method GET -Uri $nextUri -Headers $headers
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

#endregion

#region --- NEW: Settings Catalog (deviceManagementConfigurationPolicy) path ---

function Select-ConfigurationPolicy {

    $filter = if ($IncludeAllPolicies) { $null } else { "templateReference/templateFamily eq 'baseline'" }
    $uri = "$graphBase/deviceManagement/configurationPolicies"
    if ($filter) { $uri += "?`$filter=$([uri]::EscapeDataString($filter))" }

    Write-Host "Fetching policies..."
    $policies = @(Invoke-GraphGetAll -Uri $uri)

    if ($policies.Count -eq 0) {
        throw "No configurationPolicies found with templateFamily 'baseline'. Try -IncludeAllPolicies to browse every policy, or -Legacy if this baseline predates the Settings Catalog migration."
    }

    $policies = $policies | Sort-Object name

    Write-Host ""
    Write-Host "Available baselines:"
    for ($idx = 0; $idx -lt $policies.Count; $idx++) {
        $p = $policies[$idx]
        $fam = if ($p.templateReference) { $p.templateReference.templateFamily } else { '(none)' }
        Write-Host ("{0}. {1}  [{2}]  ({3})" -f ($idx + 1), $p.name, $fam, $p.id)
    }
    Write-Host ""

    do {
        $selection = Read-Host "Enter the number of the baseline to export (or Q to quit)"
        if ($selection -match '^[Qq]$') { throw "Cancelled by user." }
        $valid = ($selection -as [int]) -and ([int]$selection -ge 1) -and ([int]$selection -le $policies.Count)
        if (-not $valid) { Write-Host "Enter a number between 1 and $($policies.Count), or Q to quit." }
    } while (-not $valid)

    return $policies[[int]$selection - 1].id
}

function Resolve-ChoiceDisplayValue {
    param($Definition, $RawValue)

    if ($Definition -and $Definition.options) {
        $opt = $Definition.options | Where-Object { $_.itemId -eq $RawValue } | Select-Object -First 1
        if ($opt -and $opt.displayName) { return $opt.displayName }
    }
    return $RawValue
}

function Expand-SettingInstance {
    <#
        Recursively flattens a (possibly nested) deviceManagementConfigurationSettingInstance into
        one or more rows. Handles the common instance kinds: simple, simple collection, choice,
        choice collection, group collection. Anything unrecognized falls back to a raw JSON dump
        so nothing is silently dropped.
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
                $vals += (Resolve-ChoiceDisplayValue -Definition $def -RawValue $cv.value)
                foreach ($child in $cv.children) {
                    $rows.AddRange([object[]](Expand-SettingInstance -Instance $child -DefLookup $DefLookup -ParentDefinitionId $defId))
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
            $resolved = Resolve-ChoiceDisplayValue -Definition $def -RawValue $cv.value
            $rows.Add([PSCustomObject]@{
                    DefinitionId       = $defId
                    SettingName        = $name
                    Value              = $resolved
                    InstanceType       = $type
                    ParentDefinitionId = $ParentDefinitionId
                })
            foreach ($child in $cv.children) {
                $rows.AddRange([object[]](Expand-SettingInstance -Instance $child -DefLookup $DefLookup -ParentDefinitionId $defId))
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
                    $rows.AddRange([object[]](Expand-SettingInstance -Instance $child -DefLookup $DefLookup -ParentDefinitionId $defId))
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

function Export-FromConfigurationPolicy {
    param([Parameter(Mandatory)][string]$PolicyId)

    Write-Verbose "Fetching policy metadata for $PolicyId"
    $policy = Invoke-GraphGetAll -Uri "$graphBase/deviceManagement/configurationPolicies('$PolicyId')"

    if (-not $policy -or -not $policy.id) {
        throw "No deviceManagementConfigurationPolicy found for Id '$PolicyId'. If this baseline predates the Settings Catalog migration, try -Legacy."
    }

    if (-not $script:OutputPath) {
        $ext = if ($AsJson) { 'json' } else { 'csv' }
        $safeName = ($policy.name -replace '[^\w\-]', '_')
        $script:OutputPath = ".\SecurityBaseline_${safeName}_${PolicyId}.$ext"
    }

    Write-Verbose "Fetching settings (with expanded definitions)"
    $settingsUri = "$graphBase/deviceManagement/configurationPolicies('$PolicyId')/settings?`$expand=settingDefinitions&`$top=1000"
    $settingItems = @(Invoke-GraphGetAll -Uri $settingsUri)

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
        $rows.AddRange([object[]](Expand-SettingInstance -Instance $item.settingInstance -DefLookup $defLookup -ParentDefinitionId $null))
    }

    Write-Verbose "Writing $($rows.Count) settings to $script:OutputPath"

    if ($AsJson) {
        $rows | ConvertTo-Json -Depth 10 | Set-Content -Path $script:OutputPath -Encoding UTF8
    }
    else {
        $rows | Export-Csv -Path $script:OutputPath -NoTypeInformation -Encoding UTF8
    }

    Write-Host "Baseline '$($policy.name)' - $($rows.Count) settings exported to $script:OutputPath"
}

#endregion

#region --- LEGACY: deviceManagement/intents path ---

function Select-Intent {

    $baselineTemplateTypes = @(
        'securityBaseline',
        'advancedThreatProtectionSecurityBaseline',
        'microsoftEdgeSecurityBaseline',
        'microsoftOffice365ProPlusSecurityBaseline'
    )

    Write-Host "Fetching intents..."
    $allIntents = @(Invoke-GraphGetAll -Uri "$graphBase/deviceManagement/intents")

    Write-Host "Fetching templates..."
    $allTemplates = @(Invoke-GraphGetAll -Uri "$graphBase/deviceManagement/templates")
    $templateLookup = @{}
    foreach ($tmpl in $allTemplates) { $templateLookup[$tmpl.id] = $tmpl }

    $candidates = foreach ($i in $allIntents) {
        $tmpl = $templateLookup[$i.templateId]
        if ($IncludeAllPolicies -or ($tmpl -and $tmpl.templateType -in $baselineTemplateTypes)) {
            [PSCustomObject]@{
                Intent       = $i
                TemplateName = if ($tmpl) { $tmpl.displayName } else { '(unknown template)' }
            }
        }
    }
    $candidates = @($candidates)

    if ($candidates.Count -eq 0) {
        throw "No matching intents found. Your tenant may have migrated these baselines to the Settings Catalog - try running without -Legacy."
    }

    $candidates = $candidates | Sort-Object { $_.Intent.displayName }

    Write-Host ""
    Write-Host "Available baselines (legacy API):"
    for ($idx = 0; $idx -lt $candidates.Count; $idx++) {
        $c = $candidates[$idx]
        Write-Host ("{0}. {1}  [{2}]  ({3})" -f ($idx + 1), $c.Intent.displayName, $c.TemplateName, $c.Intent.id)
    }
    Write-Host ""

    do {
        $selection = Read-Host "Enter the number of the baseline to export (or Q to quit)"
        if ($selection -match '^[Qq]$') { throw "Cancelled by user." }
        $valid = ($selection -as [int]) -and ([int]$selection -ge 1) -and ([int]$selection -le $candidates.Count)
        if (-not $valid) { Write-Host "Enter a number between 1 and $($candidates.Count), or Q to quit." }
    } while (-not $valid)

    return $candidates[[int]$selection - 1].Intent.id
}

function Export-FromIntent {
    param([Parameter(Mandatory)][string]$IntentId)

    Write-Verbose "Fetching baseline metadata for $IntentId"
    $intent = Invoke-GraphGetAll -Uri "$graphBase/deviceManagement/intents/$IntentId"

    if (-not $intent -or -not $intent.id) {
        throw "No deviceManagementIntent found for Id '$IntentId'."
    }

    if (-not $script:OutputPath) {
        $ext = if ($AsJson) { 'json' } else { 'csv' }
        $safeName = ($intent.displayName -replace '[^\w\-]', '_')
        $script:OutputPath = ".\SecurityBaseline_${safeName}_${IntentId}.$ext"
    }

    $categories = @(Invoke-GraphGetAll -Uri "$graphBase/deviceManagement/intents/$IntentId/categories")
    $rows = [System.Collections.Generic.List[object]]::new()

    foreach ($category in $categories) {

        $definitions = @(Invoke-GraphGetAll -Uri "$graphBase/deviceManagement/intents/$IntentId/categories/$($category.id)/settingDefinitions")
        $defLookup = @{}
        foreach ($def in $definitions) { $defLookup[$def.id] = $def }

        $settings = @(Invoke-GraphGetAll -Uri "$graphBase/deviceManagement/intents/$IntentId/categories/$($category.id)/settings")

        foreach ($setting in $settings) {
            $def = $defLookup[$setting.definitionId]

            $rawValue = $null
            if ($setting.PSObject.Properties.Name -contains 'value' -and $null -ne $setting.value) {
                $rawValue = $setting.value
            }
            elseif ($setting.valueJson) {
                try { $rawValue = $setting.valueJson | ConvertFrom-Json -ErrorAction Stop }
                catch { $rawValue = $setting.valueJson }
            }

            $displayValue =
            if ($rawValue -is [PSCustomObject] -or ($rawValue -is [System.Collections.IEnumerable] -and $rawValue -isnot [string])) {
                ($rawValue | ConvertTo-Json -Compress -Depth 10)
            }
            else {
                $rawValue
            }

            $rows.Add([PSCustomObject]@{
                    Category     = $category.displayName
                    SettingName  = if ($def) { $def.displayName } else { '(definition not resolved)' }
                    Value        = $displayValue
                    ValueType    = if ($def) { $def.valueType } else { $null }
                    DefinitionId = $setting.definitionId
                    SettingType  = ($setting.'@odata.type' -replace '^#microsoft\.graph\.', '')
                    Description  = if ($def) { $def.description } else { $null }
                })
        }
    }

    if ($AsJson) {
        $rows | ConvertTo-Json -Depth 10 | Set-Content -Path $script:OutputPath -Encoding UTF8
    }
    else {
        $rows | Export-Csv -Path $script:OutputPath -NoTypeInformation -Encoding UTF8
    }

    Write-Host "Baseline '$($intent.displayName)' - $($rows.Count) settings exported to $script:OutputPath"
}

#endregion

# --- Main ---

if ($Legacy) {
    if (-not $BaselineId) { $BaselineId = Select-Intent }
    Export-FromIntent -IntentId $BaselineId
}
else {
    if (-not $BaselineId) { $BaselineId = Select-ConfigurationPolicy }
    Export-FromConfigurationPolicy -PolicyId $BaselineId
}