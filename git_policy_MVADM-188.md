# Git Workflow Policy - MVADM-188

**Ticket:** MVADM-188 - Bill Review UAT Bugs  
**Repository:** https://github.com/AlexiaAbrego-Trinity/BCN-QuoteAdjudication.git  
**Created:** 2026-01-05  
**Developer:** Alexia Abrego  

---

## Repository Configuration

### Remote Repository
```bash
URL: https://github.com/AlexiaAbrego-Trinity/BCN-QuoteAdjudication.git
Remote name: origin
```

### Branch Strategy

**Main Branch:** `main`
- Production-ready code
- Protected branch (requires PR approval)
- Never commit directly to main

**Feature Branch:** `feature/MVADM-188`
- All work for MVADM-188 happens here
- Created from: `main`
- Merged to: `main` (via Pull Request after UAT approval)

---

## Initial Setup Commands

### 1. Initialize Repository (COMPLETED ✅)
```bash
cd c:\Users\AlexiaAbrego\Documents\Projects\Medivest-eob
git init
git remote add origin https://github.com/AlexiaAbrego-Trinity/BCN-QuoteAdjudication.git
```

### 2. Create Initial Commit on Main Branch
```bash
# Create .gitignore for Salesforce project
git add .gitignore

# Add requirements document
git add requirements_MVADM-188.md
git add git_policy_MVADM-188.md

# Initial commit
git commit -m "chore(setup): Initialize repository for MVADM-188 Bill Review UAT Bugs

- Add requirements analysis document
- Add Git workflow policy
- Configure Salesforce project structure

MVADM-188"

# Push to remote and set upstream
git push -u origin main
```

### 3. Create Feature Branch
```bash
# Ensure we're on main
git checkout main

# Pull latest changes (if any)
git pull origin main

# Create and switch to feature branch
git checkout -b feature/MVADM-188

# Push feature branch to remote
git push -u origin feature/MVADM-188
```

---

## Daily Workflow Commands

### Start of Day
```bash
# Switch to feature branch
git checkout feature/MVADM-188

# Pull latest changes from remote
git pull origin feature/MVADM-188

# Optional: Sync with main if needed
git fetch origin main
git merge origin/main
```

### During Development
```bash
# Check current status
git status

# Stage specific files
git add <file1> <file2>

# Or stage all changes (use carefully)
git add .

# Commit with proper format (see Commit Message Format below)
git commit -m "feat(component): description MVADM-188"

# Push to remote feature branch
git push origin feature/MVADM-188
```

### End of Day
```bash
# Ensure all work is committed
git status

# Push all commits to remote
git push origin feature/MVADM-188
```

---

## Commit Message Format

### Standard Format
```
<type>(<scope>): <short description> MVADM-188

<body - optional but recommended>
- Task IDs covered: [list]
- Validation commands executed: [list]
- Results: [summary]

<footer - optional>
```

### Commit Types
- `feat`: New feature or enhancement
- `fix`: Bug fix
- `refactor`: Code refactoring (no functional change)
- `test`: Adding or updating tests
- `docs`: Documentation changes
- `chore`: Maintenance tasks (build, config, etc.)
- `style`: Code style changes (formatting, no logic change)

### Scope Examples
- `(LWC)`: Lightning Web Component changes
- `(Apex)`: Apex class changes
- `(Flow)`: Flow changes
- `(Config)`: Configuration/metadata changes
- `(Test)`: Test class changes
- `(Docs)`: Documentation changes

### Example Commits
```bash
# Bug fix example
git commit -m "fix(LWC): Resolve undefined values in cloned rows MVADM-188

- Fixed processedDuplicates mapping to correctly access date fields
- Added null checks for Service_Start_Date__c and Service_End_Date__c
- Validation: Cloned 5 rows with dates, all displayed correctly
- Results: No undefined values in UI grid

Resolves cloning bug reported by Chris Caines in UAT"

# Feature example
git commit -m "feat(Apex): Add line number validation logic MVADM-188

- Enhanced createBillLineItem to validate sequential numbering
- Added debug logging for line number calculation
- Validation: Created 10 draft items, all numbered sequentially
- Results: Line numbers 1-10 assigned correctly

Addresses auto-numbering issue from UAT feedback"

# Test example
git commit -m "test(Apex): Add test coverage for duplication edge cases MVADM-188

- Added test for cloning rows with null dates
- Added test for cloning rows with special characters in CPT codes
- Validation: Run all tests - 100% pass rate
- Results: Code coverage increased to 95%"
```

---

## Commit Policy

### When to Commit

✅ **DO commit after:**
- Completing a logical unit of work (single bug fix, single feature)
- All related tests pass
- Code has been validated in sandbox
- Documentation is updated

❌ **DO NOT commit:**
- Broken code that doesn't compile
- Code that fails existing tests
- Incomplete features (unless using feature flags)
- Sensitive data (credentials, API keys, etc.)

### Commit Frequency

**Small, frequent commits are preferred:**
- After fixing one bug
- After adding one test class
- After updating one component
- After validating one change in sandbox

**Avoid large commits:**
- Don't bundle multiple unrelated changes
- Don't wait until end of day to commit everything
- Don't commit "work in progress" without clear WIP label

---

## Validation Before Commit

### Required Validations

1. **Code Compiles**
   ```bash
   sf project deploy validate --source-dir force-app
   ```

2. **Tests Pass**
   ```bash
   sf apex run test --test-level RunLocalTests --result-format human
   ```

3. **No Lint Errors**
   ```bash
   # For LWC
   npm run lint
   ```

4. **Sandbox Validation**
   - Deploy to medivest-eobbcnb
   - Manual testing of changed functionality
   - Verify no regressions

### Validation Log Template
```
Validation executed: [date/time]
Commands run:
  - sf project deploy validate --source-dir force-app
  - sf apex run test --class TRM_MedicalBillingServiceTest
  - Manual test: Clone row with dates in BCN-12345

Results:
  - Deployment: SUCCESS
  - Tests: 45/45 passed (100%)
  - Manual test: Dates displayed correctly, no undefined values
```

---

## Branch Protection Rules

### Main Branch
- ✅ Require pull request before merging
- ✅ Require approvals (minimum 1)
- ✅ Require status checks to pass
- ✅ Require conversation resolution
- ❌ No direct commits allowed

### Feature Branch (feature/MVADM-188)
- ✅ Direct commits allowed
- ✅ Force push allowed (use carefully)
- ✅ Can be deleted after merge

---

## Pull Request Process

### When to Create PR
- After all bugs are fixed
- After all tests pass
- After UAT approval from Chris Caines
- After requirements document is updated

### PR Template
```markdown
## MVADM-188: Bill Review UAT Bugs

### Summary
Fixes two critical UI bugs in bill review component:
1. Cloning rows produces undefined service code and dates
2. Draft lines do not auto-number correctly

### Changes Made
- [ ] Fixed LWC duplication mapping logic
- [ ] Enhanced Apex line numbering validation
- [ ] Added test coverage for edge cases
- [ ] Updated documentation

### Testing Performed
- Unit tests: [X/X passed]
- Integration tests: [X/X passed]
- Manual UAT: [Approved by Chris Caines on DATE]

### Validation Commands
```bash
sf project deploy validate --source-dir force-app
sf apex run test --test-level RunLocalTests
```

### Deployment Notes
- Deploy to production after PR approval
- No data migration required
- No configuration changes required

### Checklist
- [ ] Code reviewed
- [ ] Tests passing
- [ ] Documentation updated
- [ ] UAT approved
- [ ] No regressions found
```

---

## Emergency Procedures

### Rollback Procedure
```bash
# If feature branch has issues, reset to last known good commit
git log --oneline  # Find last good commit hash
git reset --hard <commit-hash>
git push --force origin feature/MVADM-188

# If main branch has issues after merge
git revert <merge-commit-hash>
git push origin main
```

### Hotfix Procedure
```bash
# Create hotfix branch from main
git checkout main
git pull origin main
git checkout -b hotfix/MVADM-188-critical

# Make fix, test, commit
git commit -m "hotfix: Critical fix for MVADM-188"

# Merge to main immediately
git checkout main
git merge hotfix/MVADM-188-critical
git push origin main

# Merge back to feature branch
git checkout feature/MVADM-188
git merge main
git push origin feature/MVADM-188
```

---

## Commit History Log

### 2026-01-05

**Commit 1: Initial Setup** ✅ COMPLETED
- **Commit Hash:** `8998d1d`
- **Branch:** `main`
- **Type:** `chore(setup)`
- **Files Added:** 106 files (26,743 insertions)
  - `.gitignore` - Salesforce project gitignore
  - `requirements_MVADM-188.md` - Requirements analysis document
  - `git_policy_MVADM-188.md` - Git workflow policy
  - `ADJUDICATION_COMPONENTS.md` - Component inventory
  - 24 Apex classes (12 classes + 12 meta.xml)
  - 15 LWC components (60 files)
  - 2 triggers (4 files)
  - Salesforce DX configuration
- **Validation:** N/A (documentation and initial code baseline)
- **Status:** ✅ Pushed to `origin/main`
- **Timestamp:** 2026-01-05 (exact time from terminal output)

**Branch Creation: feature/MVADM-188** ✅ COMPLETED
- **Created from:** `main` (commit `8998d1d`)
- **Status:** ✅ Pushed to `origin/feature/MVADM-188`
- **Purpose:** All MVADM-188 bug fixes will be committed to this branch
- **Pull Request URL:** https://github.com/AlexiaAbrego-Trinity/BCN-QuoteAdjudication/pull/new/feature/MVADM-188

---

## Notes and Best Practices

1. **Always pull before starting work** to avoid merge conflicts
2. **Write descriptive commit messages** - future you will thank you
3. **Commit early, commit often** - easier to revert small changes
4. **Never commit secrets** - use environment variables
5. **Test before committing** - broken code blocks the team
6. **Keep commits atomic** - one logical change per commit
7. **Use branches** - never work directly on main
8. **Document validation** - include test results in commit body

---

**Last Updated:** 2026-01-05  
**Status:** Active  
**Next Review:** After MVADM-188 completion

