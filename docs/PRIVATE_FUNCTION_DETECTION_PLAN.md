# Private Function Detection Improvement Plan

## Problem Statement

The `Analyze-FunctionDependencies.ps1` tool is flagging nested/private helper functions as "unused" because it:
1. Scans all files globally for function definitions
2. Scans all files globally for function calls
3. Does not distinguish between public (top-level) and private (nested) functions

## Affected Functions

### Private Helper Functions (Nested within parent functions)
1. **Display-SettingInfoForViewer** - Nested in `Show-SettingsViewer.ps1` (called at line 251)
2. **Write-SafeLogFallback** - Nested in `Test-AuthDefaults.ps1` (called multiple times)
3. **Test-RequiresFlattening** - Nested in `MergeSettings.ps1` (called at lines 150, 151)
4. **Get-SimpleKey** - Nested in `MergeSettings.ps1` (called at lines 207, 215)
5. **Test-ScopeAuthorization** - Nested in `HasScope.ps1` (called at line 255) ✅ Already annotated

### Public Functions Incorrectly Flagged (Need investigation)
1. **Show-AppModeHierarchyInfo** - Called from `Get-MultipleAppModeInput.ps1` (line 145)
2. **Show-SettingsViewer** - Top-level function with examples in docs

## Solution Strategy

### Phase 1: Standardize Private Function Annotations ✅

Add consistent suppression attributes to all nested helper functions:

```powershell
# Helper function description
# Note: This is a private nested function called within ParentFunctionName
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', '', 
    Justification='Nested helper function called by parent function')]
function PrivateHelperName()
{
    # implementation
}
```

**Benefits:**
- Clear documentation for developers
- Suppresses PSScriptAnalyzer false positives
- Consistent pattern across codebase
- Easy to identify private functions during code review

### Phase 2: Enhance Analyze-FunctionDependencies.ps1 Tool ✅

Improve detection logic to handle nested functions:

1. **Detect Nesting Level**
   - Track brace depth when scanning for function definitions
   - Identify functions defined at depth > 1 as nested/private
   - Store nesting information in function metadata

2. **Scope-Aware Call Detection**
   - For private functions: only scan parent file for calls
   - For public functions: scan all files globally
   - Track parent function relationship

3. **Enhanced Reporting**
   - Add `Scope` column: "Public" or "Private"
   - Add `ParentFunction` column for nested functions
   - Filter private functions from "unused" warnings (or separate category)
   - Add statistics for private vs public functions

4. **Detection Algorithm**
```powershell
# Pseudocode
foreach file in functions:
    content = read file
    braceDepth = 0
    foreach line in content:
        if line contains '{': braceDepth++
        if line matches 'function Name':
            if braceDepth > 1:
                mark as PRIVATE
                set parent = current top-level function
            else:
                mark as PUBLIC
        if line contains '}': braceDepth--
```

### Phase 3: Update Repository Guidelines 📝

Add to `AGENTS.md`:

```markdown
## Private (Nested) Helper Functions

**Pattern**: Functions defined within other functions are private helpers, scoped to the parent.

**Requirements**:
1. Add suppression attribute above nested function
2. Include comment indicating parent function and approximate call line
3. Use descriptive names (prefixing with internal convention optional)

**Example**:
```powershell
function Public-MainFunction() {
    # Main logic
    
    # Helper for specific task within this function
    # Note: Private nested function called at line ~150
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', '', 
        Justification='Nested helper function called by parent Public-MainFunction')]
    function Private-Helper() {
        # helper implementation
    }
    
    # Use the helper
    $result = Private-Helper -Param $value
}
```

**Benefits**:
- Encapsulation: Helper logic stays with the function that uses it
- No namespace pollution: Private functions don't clutter global scope
- Clearer intent: Obvious that helper is single-purpose
- Better analysis: Tools can correctly identify usage patterns
```

## Implementation Checklist

### Immediate Actions (Phase 1)
- [x] Add annotation to `Test-ScopeAuthorization` in `HasScope.ps1` (already done)
- [ ] Add annotation to `Display-SettingInfoForViewer` in `Show-SettingsViewer.ps1`
- [ ] Add annotation to `Write-SafeLogFallback` in `Test-AuthDefaults.ps1`
- [ ] Add annotation to `Test-RequiresFlattening` in `MergeSettings.ps1`
- [ ] Add annotation to `Get-SimpleKey` in `MergeSettings.ps1`

### Tool Enhancement (Phase 2)
- [ ] Add nesting detection to `Get-FunctionDefinitions()` in Analyze-FunctionDependencies.ps1
- [ ] Modify function metadata to include: `IsNested`, `NestingDepth`, `ParentFunction`
- [ ] Update call detection to be scope-aware
- [ ] Add new CSV columns: `Scope`, `ParentFunction`, `NestingDepth`
- [ ] Update summary statistics to separate public/private counts
- [ ] Add filter option to exclude private functions from unused warnings

### Documentation (Phase 3)
- [ ] Update `AGENTS.md` with private function pattern
- [ ] Update `docs/CONTRIBUTOR_GUIDE.md` with nesting guidelines
- [ ] Add examples to `docs/TECHNICAL_DOCUMENTATION.md`

### Validation (Phase 4)
- [ ] Run enhanced analysis tool and verify correct detection
- [ ] Confirm no false positives for nested functions
- [ ] Verify public function detection still works correctly
- [ ] Review report for any remaining issues

## Expected Outcomes

1. **Zero false positives** for private helper functions
2. **Accurate usage detection** for public functions
3. **Clear visibility** into code organization (public vs private)
4. **Consistent pattern** across entire codebase
5. **Better tooling** for future dependency analysis

## Technical Notes

### Why Nested Functions?
- **Encapsulation**: Keep helper logic near where it's used
- **Single Responsibility**: Each file = one public function + private helpers
- **Readability**: Clear parent-child relationships
- **Maintainability**: Changes to helpers stay localized

### Alternative Approaches Considered
1. **Prefix convention** (`_HelperFunction`): Not standard in PowerShell
2. **Separate files**: Creates too many tiny files, harder to navigate
3. **Script block variables**: Less clear, no IntelliSense support
4. **Module-scoped functions**: Requires module context, more complex

### Related PowerShell Concepts
- Script scope vs function scope
- Nested function closures (can access parent variables)
- Module exports (only explicit exports are public)
- PSScriptAnalyzer rules and suppressions

## References

- [PowerShell Function Scopes](https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_scopes)
- [PSScriptAnalyzer Suppressions](https://learn.microsoft.com/en-us/powershell/utility-modules/psscriptanalyzer/using-scriptanalyzer)
- Repository: `AGENTS.md` - Coding standards
- Repository: `tests/AGENTS.md` - Testing patterns
