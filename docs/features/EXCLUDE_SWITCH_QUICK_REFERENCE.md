# Exclude Switch Quick Reference

**Quick guide for using the `-Exclude` switch in `Invoke-PesterTests.ps1`**

---

## What Does `-Exclude` Do?

The `-Exclude` switch **inverts** the filtering logic for test selection parameters:

| Without `-Exclude` | With `-Exclude` |
|-------------------|-----------------|
| Run **only** matching tests | Run **everything except** matching tests |

---

## Basic Usage

### Exclude by Tag

```powershell
# Run everything except slow tests
.\Invoke-PesterTests.ps1 -Tags "Slow" -Exclude

# Exclude multiple tags
.\Invoke-PesterTests.ps1 -Tags "Slow","Integration" -Exclude
```

### Exclude by Test Type

```powershell
# Run Integration + Comprehensive (exclude Unit)
.\Invoke-PesterTests.ps1 -TestType Unit -Exclude

# Run Unit + Comprehensive (exclude Integration)
.\Invoke-PesterTests.ps1 -TestType Integration -Exclude

# Run Unit + Integration (exclude Comprehensive)
.\Invoke-PesterTests.ps1 -TestType Comprehensive -Exclude
```

### Exclude by File

```powershell
# Run everything except Graph API tests
.\Invoke-PesterTests.ps1 -TestFile "GraphAPI" -Exclude

# Exclude specific file by path
.\Invoke-PesterTests.ps1 -TestFile ".\tests\Unit\Get-EntraDirectoryObject.Tests.ps1" -Exclude
```

---

## Interactive Mode

### Interactive Tag Exclusion

```powershell
.\Invoke-PesterTests.ps1 -Tags "Interactive" -Exclude
```

**What happens**:
1. Shows list of available tags
2. You select tag(s) to **exclude**
3. Runs all tests **except** those with selected tags

### Interactive File Exclusion

```powershell
.\Invoke-PesterTests.ps1 -TestFile "Interactive" -Exclude
```

**What happens**:
1. Shows list of all test files
2. You select file(s) to **exclude**
3. Runs all tests **except** selected files

---

## Combined Exclusions

You can combine multiple exclusions:

```powershell
# Exclude Unit tests AND slow tests
.\Invoke-PesterTests.ps1 -TestType Unit -Tags "Slow" -Exclude

# Result: Runs Integration + Comprehensive tests, but skips any tagged "Slow"
```

---

## Common Scenarios

### Development Workflow

```powershell
# Quick feedback: skip slow integration tests
.\Invoke-PesterTests.ps1 -Tags "Slow" -Exclude

# Run fast tests only
.\Invoke-PesterTests.ps1 -TestType Integration -Exclude
```

### Debugging

```powershell
# Skip problematic test file while debugging
.\Invoke-PesterTests.ps1 -TestFile "ProblematicTest" -Exclude

# Skip comprehensive tests during rapid iteration
.\Invoke-PesterTests.ps1 -TestType Comprehensive -Exclude
```

### CI/CD

```powershell
# Run all tests except known flaky ones
.\Invoke-PesterTests.ps1 -Tags "Flaky" -Exclude

# Parallel jobs: exclude what other jobs run
# Job 1: Run Unit tests
.\Invoke-PesterTests.ps1 -TestType Unit

# Job 2: Run everything else
.\Invoke-PesterTests.ps1 -TestType Unit -Exclude
```

---

## Output Examples

### Tag Exclusion Output

```
Test Configuration:
  Test Type: All
  Excluding Tags: Slow, Integration
```

### TestType Exclusion Output

```
Test Configuration:
  Test Type: Unit (EXCLUDING)
  Test Path: .\tests\Integration, .\tests\Comprehensive
```

### File Exclusion Output

```
Excluding this file, running 144 remaining test(s)

Test Configuration:
  Test Type: All
  Test Files: 144 files selected
```

---

## Important Notes

### ⚠️ Edge Cases

1. **`-TestType All -Exclude`**: Has no effect (you can't exclude "all" tests)
2. **`-Exclude` alone**: Has no effect (nothing to exclude without other parameters)
3. **Fuzzy search**: Works with exclusion - selects files to exclude interactively

### ✅ Works With

- Fuzzy file search
- Multiple file selection
- Interactive tag/file selection
- Code coverage (`-EnableCodeCoverage`)
- CI mode (`-CI`)
- All output verbosity levels

---

## Quick Tips

1. **Use Interactive Mode**: When unsure what to exclude, use "Interactive" to see options
   ```powershell
   .\Invoke-PesterTests.ps1 -Tags "Interactive" -Exclude
   ```

2. **Check Output**: Always review "Test Configuration" output to confirm exclusions

3. **Combine Wisely**: Multiple exclusions are AND'ed together (test must not match ANY criteria)

4. **Development Speed**: Exclude slow tests for faster feedback loops
   ```powershell
   .\Invoke-PesterTests.ps1 -Tags "Slow" -Exclude
   ```

5. **Parallel Testing**: Use exclusions to split test runs across multiple processes
   ```powershell
   # Terminal 1
   .\Invoke-PesterTests.ps1 -TestType Unit
   
   # Terminal 2
   .\Invoke-PesterTests.ps1 -TestType Unit -Exclude
   ```

---

## See Also

- **Full Documentation**: `docs\features\EXCLUDE_SWITCH_IMPLEMENTATION.md`
- **Tag Selection**: `docs\features\TAG_SELECTION_FEATURE.md`
- **File Selection**: `docs\features\MULTIPLE_FILE_SELECTION_FEATURE.md`
- **Help**: `Get-Help .\Invoke-PesterTests.ps1 -Detailed`

---

**Quick Start**: Try it now!

```powershell
# See what tags are available
.\Invoke-PesterTests.ps1 -Tags "Interactive"

# Exclude a tag and see what runs
.\Invoke-PesterTests.ps1 -Tags "Unit" -Exclude
```
