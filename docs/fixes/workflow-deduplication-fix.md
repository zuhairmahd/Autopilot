# Workflow Deduplication Fix

## Issue

When pushing to a branch that has an open pull request, **both workflows would run**:
1. `pr-checks.yml` - Triggered by the `pull_request` event
2. `publish.yml` - Triggered by the `push` event

This caused duplicate test runs, wasting CI minutes and creating confusion about which test results to review.

## Root Cause

The `publish.yml` workflow was configured to trigger on both events:
```yaml
on:
  push:
    branches:
      - "**"  # All branches
  pull_request:
    branches:
      - "**"  # All PRs
```

When you push to a PR branch (e.g., `tests-refactor`), GitHub fires both events:
- A `push` event (because code was pushed)
- A `pull_request` synchronize event (because the PR was updated)

## Solution

Modified `publish.yml` to **only trigger on direct pushes** to specific branches (`dev` and `lhm`), removing the `pull_request` trigger entirely.

### Changes Made

**Before:**
```yaml
on:
  push:
    branches:
      - "**"
  pull_request:
    branches:
      - "**"
```

**After:**
```yaml
on:
  push:
    branches:
      - dev
      - lhm
```

### Additional Improvements

Simplified job conditions to remove now-unnecessary `github.event_name` checks:

**Before:**
```yaml
if: >
  github.event_name != 'push' ||
  !contains((github.event.head_commit.message || github.event.pull_request.title || ''), '[skip ci]')
```

**After:**
```yaml
if: ${{ !contains(github.event.head_commit.message, '[skip ci]') }}
```

## Workflow Responsibilities

### `pr-checks.yml` - Pull Request Testing
- **Triggers:** Pull requests to `master`, `dev`, `lhm`
- **Purpose:** Validate PR changes before merge
- **Tests:** Unit, Integration, Comprehensive (conditional), Code Quality
- **Coverage:** Enabled for unit tests
- **Results:** Published to PR with check annotations

### `publish.yml` - Branch Build & Sign
- **Triggers:** Direct pushes to `dev`, `lhm` branches
- **Purpose:** Build and sign executables for specific branches
- **Tests:** Unit, Integration (smoke test to ensure buildability)
- **Coverage:** Disabled (faster execution)
- **Output:** Signed artifacts committed back to branch

### `release.yml` - Release Publishing
- **Triggers:** GitHub release published
- **Purpose:** Create production release artifacts
- **Tests:** Unit, Integration, Comprehensive (all tests)
- **Coverage:** Enabled for unit tests
- **Output:** Signed executables attached to GitHub release

### `target-build.yml` - Manual Build
- **Triggers:** Manual workflow dispatch
- **Purpose:** Build specific targets on-demand
- **Tests:** Configurable (user selects which tests to run)
- **Coverage:** Optional (user-controlled)
- **Output:** Artifacts for selected target

## Behavior After Fix

### Scenario 1: Push to PR Branch (e.g., `tests-refactor` → PR to `master`)
- ✅ **Runs:** `pr-checks.yml` only
- ❌ **Skipped:** `publish.yml` (not `dev` or `lhm`)
- **Result:** Single test run, results visible in PR

### Scenario 2: Push Directly to `dev` Branch (No PR)
- ✅ **Runs:** `publish.yml` only
- ❌ **Skipped:** `pr-checks.yml` (no PR event)
- **Result:** Build + sign + commit artifacts

### Scenario 3: Push to `dev` Branch via PR Merge
- ✅ **Runs:** `publish.yml` only (on the merge commit)
- ❌ **Skipped:** `pr-checks.yml` (PR already closed)
- **Result:** Build + sign + commit artifacts

### Scenario 4: Create PR from `feature-branch` to `dev`
- ✅ **Runs:** `pr-checks.yml` on each push to `feature-branch`
- ❌ **Skipped:** `publish.yml` (not `dev` or `lhm` branch)
- **Result:** PR validation only

### Scenario 5: Publish GitHub Release
- ✅ **Runs:** `release.yml` only
- ❌ **Skipped:** `pr-checks.yml` and `publish.yml` (different trigger)
- **Result:** Production release with all tests + signed artifacts

## Benefits

1. ✅ **No duplicate test runs** - Each push triggers only the appropriate workflow
2. ✅ **Faster PR feedback** - PR checks focus on validation without build overhead
3. ✅ **Clear separation** - Distinct workflows for different purposes
4. ✅ **Cost savings** - Reduced GitHub Actions minutes usage
5. ✅ **Better UX** - No confusion about which test results to review

## Migration Notes

If you need to test `publish.yml` changes on a PR branch:
1. Use `target-build.yml` manual workflow instead
2. Or temporarily add your branch to `publish.yml` push branches
3. Or merge to `dev` branch to trigger the full workflow

## Verification

After this fix, you can verify behavior:
```bash
# Create PR from feature branch
git checkout -b test-workflow-fix
git push origin test-workflow-fix
# Open PR to master → Only pr-checks.yml should run

# Push directly to dev
git checkout dev
git push origin dev
# → Only publish.yml should run
```

## Related Files

- Modified: `.github/workflows/publish.yml`
- Reference: `.github/workflows/pr-checks.yml`
- Reference: `.github/workflows/release.yml`
- Reference: `.github/workflows/target-build.yml`

## Date

October 15, 2025
