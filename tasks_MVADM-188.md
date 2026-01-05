# Task List - MVADM-188: Bill Review UAT Bugs

**Ticket:** [MVADM-188](https://trinitycrm.atlassian.net/browse/MVADM-188)  
**SDR Version:** 1.1  
**Requirements Version:** 1.0  
**Generated:** 2026-01-05  
**Status:** Ready for Execution

---

## Task Execution Rules

1. **Sequential Execution:** Tasks MUST be executed in order unless explicitly marked as parallelizable
2. **Validation Required:** Each task MUST pass validation before proceeding to next task
3. **Rollback on Failure:** If validation fails, execute rollback plan immediately
4. **Human Review Points:** Tasks marked with 🔴 require explicit human approval before execution
5. **Documentation:** Update Jira ticket after each phase completion

---

## Quick Reference: Task Dependencies

```
Phase 1 (Pre-Implementation) ✅ COMPLETE
├── Task 1.1: Client Clarification ✅ COMPLETE
├── Task 1.2: Reproduce Bugs ✅ COMPLETE
└── Task 1.3: Validate Design ✅ COMPLETE

Phase 2 (Apex Implementation)
├── Task 2.1: Modify Apex Class
├── Task 2.2: Deploy Apex to Sandbox
└── Task 2.3: Validate Apex Changes

Phase 3 (LWC Implementation) [Can run parallel to Phase 2]
├── Task 3.1: Add formatDateSafely Helper
├── Task 3.2: Fix Field Mapping (depends on 3.1)
├── Task 3.3: Deploy LWC to Sandbox
└── Task 3.4: Validate LWC Changes

Phase 4 (Testing) [Requires Phase 2 & 3 complete]
├── Task 4.1: Update Apex Tests [Can run parallel to 4.2]
└── Task 4.2: End-to-End Integration Test

Phase 5 (UAT) [Requires Phase 4 complete]
├── Task 5.1: Prepare UAT Environment
├── Task 5.2: Conduct UAT 🔴 HUMAN REQUIRED
└── Task 5.3: Obtain UAT Sign-Off 🔴 HUMAN REQUIRED

Phase 6 (Production) [Requires Phase 5 complete] 🔴 REQUIRES EXPLICIT PERMISSION
├── Task 6.1: Create Deployment Package
├── Task 6.2: Deploy to Production 🔴 HUMAN APPROVAL REQUIRED
├── Task 6.3: Production Smoke Test
└── Task 6.4: Close Ticket
```

---

## PHASE 1: PRE-IMPLEMENTATION ✅ COMPLETE

All Phase 1 tasks have been completed. Client provided screenshots and clarification on 2026-01-05.

**Confirmed Bugs:**
- Bug #1: Duplicated rows have blank Line # column
- Bug #2: Service dates, Revenue Code, POS, and CPT fields show placeholders instead of copied values

**Root Causes Identified:**
- Bug #1: Apex `createDuplicateBillLineItems` sets `Bill_Line_Item_Number__c = null` without auto-assignment
- Bug #2: LWC `confirmDuplication` only maps `*Display` fields, missing `revenueCode`, `posCode`, `cptCode`

---

## PHASE 2: APEX IMPLEMENTATION

### Task 2.1: Modify createDuplicateBillLineItems Method

**ID:** MVADM-188-T2.1  
**Title:** Add Line Number Auto-Assignment to Apex Duplication Logic

#### Context
- **Requirements:** Satisfies Requirement #2 from `requirements_MVADM-188.md` - "Fix Draft Line Auto-Numbering"
- **SDR Reference:** Section 1 "Apex Class Modifications", Step 2.1 (lines 475-511)
- **Root Cause:** Bug #1 - Apex sets `Bill_Line_Item_Number__c = null` without calculating next sequential number

#### Exact Changes

**File:** `force-app/main/default/classes/TRM_MedicalBillingService.cls`  
**Method:** `createDuplicateBillLineItems` (lines 730-781)  
**Change Type:** MODIFY - Add line number assignment logic

**Location Anchors:**
- Start: Line 746 (beginning of outer `for` loop)
- End: Line 758 (end of inner `for` loop)

**Code to Add:**

1. **BEFORE outer loop** (insert after line 745):
```apex
// MVADM-188: Map to cache max line number per Bill (prevents redundant queries)
Map<Id, Decimal> billToMaxLineNumber = new Map<Id, Decimal>();
```

2. **INSIDE outer loop, BEFORE inner loop** (insert after line 752, before line 754):
```apex
// MVADM-188: Get or calculate max line number for this Bill (query once per Bill)
if (!billToMaxLineNumber.containsKey(original.Bill__c)) {
    List<Bill_Line_Item__c> existingItems = [
        SELECT Bill_Line_Item_Number__c
        FROM Bill_Line_Item__c
        WHERE Bill__c = :original.Bill__c
        ORDER BY Bill_Line_Item_Number__c DESC NULLS LAST
        LIMIT 1
        FOR UPDATE  // Row-level locking to prevent race conditions
    ];
    
    Decimal maxNumber = 0;
    if (!existingItems.isEmpty() && existingItems[0].Bill_Line_Item_Number__c != null) {
        maxNumber = existingItems[0].Bill_Line_Item_Number__c;
    }
    billToMaxLineNumber.put(original.Bill__c, maxNumber);
}
```

3. **REPLACE line 755** (change from `newItem.Bill_Line_Item_Number__c = null;` to):
```apex
// MVADM-188: Assign next sequential line number
Decimal nextNumber = billToMaxLineNumber.get(original.Bill__c) + 1;
newItem.Bill_Line_Item_Number__c = nextNumber;
billToMaxLineNumber.put(original.Bill__c, nextNumber); // Increment for next duplicate
```

#### Implementation Instructions

**Step-by-Step:**

1. Create feature branch:
   ```bash
   git checkout -b fix/MVADM-188-bill-line-item-bugs
   ```

2. Open file in VS Code:
   ```bash
   code force-app/main/default/classes/TRM_MedicalBillingService.cls
   ```

3. Navigate to line 746 (use Ctrl+G in VS Code)

4. Make the three code changes listed above in exact order

5. Save file (Ctrl+S)

6. Review changes in Source Control view (Ctrl+Shift+G)

7. Commit changes:
   ```bash
   git add force-app/main/default/classes/TRM_MedicalBillingService.cls
   git commit -m "fix(MVADM-188): Add line number assignment to Bill Line Item duplication

- Added billToMaxLineNumber map to cache max line numbers per Bill
- Query max line number once per Bill with FOR UPDATE locking
- Assign sequential line numbers to duplicated items
- Fixes Bug #1: Blank Line # column in duplicated rows"
   ```

#### Validation

**PASS Criteria:**
- ✅ Code compiles without errors (no red squiggles in VS Code)
- ✅ Diff shows only expected changes (3 additions, 1 modification)
- ✅ No accidental modifications to other methods
- ✅ Validation command succeeds

**Validation Commands:**
```bash
# Validate syntax and compilation
sf project deploy validate --source-dir force-app/main/default/classes/TRM_MedicalBillingService.cls --target-org medivest-eobbcnb
```

**Expected Output:**
```
Status: Succeeded
Component Failures: 0
Test Failures: 0
```

**What Counts as PASS:**
- Validation command exits with code 0
- Output shows "Status: Succeeded"
- No compilation errors in output

#### Rollback Plan

**If validation fails:**

1. Revert changes:
   ```bash
   git checkout -- force-app/main/default/classes/TRM_MedicalBillingService.cls
   ```

2. Review error messages from validation command

3. Fix syntax errors if any

4. Retry from Step 3 of Implementation Instructions

**If accidental changes detected:**

1. Use VS Code diff view to identify unintended changes

2. Revert file:
   ```bash
   git checkout -- force-app/main/default/classes/TRM_MedicalBillingService.cls
   ```

3. Carefully re-apply only the intended changes

#### Dependencies

**Prerequisites:**
- ✅ Phase 1 complete (client clarification received)
- ✅ Git repository is clean (`git status` shows no uncommitted changes)
- ✅ VS Code is open with workspace loaded

**Org Dependencies:**
- `Bill_Line_Item__c` object exists with `Bill_Line_Item_Number__c` field (Decimal type)
- `Bill__c` object exists with relationship to `Bill_Line_Item__c`

**No dependencies on other tasks** - This task can be executed independently

---

### Task 2.2: Deploy Apex Changes to Sandbox

**ID:** MVADM-188-T2.2
**Title:** Deploy Modified Apex Class to medivest-eobbcnb Sandbox

#### Context
- **Requirements:** Satisfies Requirement #2 from `requirements_MVADM-188.md`
- **SDR Reference:** Step 2.2 (lines 515-553)
- **Purpose:** Deploy Apex changes to sandbox for testing

#### Exact Changes

**Target Org:** medivest-eobbcnb (sandbox)
**Components to Deploy:**
- `TRM_MedicalBillingService.cls`
- `TRM_MedicalBillingService.cls-meta.xml`

#### Implementation Instructions

**Step-by-Step:**

1. Verify no uncommitted changes:
   ```bash
   git status
   ```
   Expected: "nothing to commit, working tree clean"

2. Deploy to sandbox:
   ```bash
   sf project deploy start --source-dir force-app/main/default/classes/TRM_MedicalBillingService.cls --target-org medivest-eobbcnb --test-level NoTestRun
   ```

3. Monitor deployment (command will show progress)

4. Wait for completion (typically 30-60 seconds)

5. Verify deployment success in output

#### Validation

**PASS Criteria:**
- ✅ Deployment status: "Succeeded"
- ✅ No compilation errors
- ✅ Component deployed: 1
- ✅ Component failures: 0

**Validation Commands:**
```bash
# Check deployment status
sf project deploy report --target-org medivest-eobbcnb

# Verify class is deployed
sf data query --query "SELECT Id, Name, ApiVersion FROM ApexClass WHERE Name = 'TRM_MedicalBillingService'" --target-org medivest-eobbcnb
```

**Expected Output:**
```
=== Deploy Status
Status: Succeeded
Component Deployed: 1
Component Failures: 0
Test Failures: 0
```

**What Counts as PASS:**
- Deployment command exits with code 0
- Status shows "Succeeded"
- Query returns 1 record for TRM_MedicalBillingService

#### Rollback Plan

**If deployment fails:**

1. Review error messages in deployment output

2. If compilation error:
   - Return to Task 2.1
   - Fix code issues
   - Re-validate
   - Retry deployment

3. If org issue (permissions, locks, etc.):
   - Wait 5 minutes
   - Retry deployment
   - If still fails, contact Salesforce admin

**If deployment succeeds but class is broken:**

1. Retrieve previous version from org:
   ```bash
   sf project retrieve start --metadata ApexClass:TRM_MedicalBillingService --target-org medivest-eobbcnb
   ```

2. Deploy previous version:
   ```bash
   sf project deploy start --source-dir force-app/main/default/classes/TRM_MedicalBillingService.cls --target-org medivest-eobbcnb
   ```

#### Dependencies

**Prerequisites:**
- ✅ Task 2.1 complete (Apex code modified and validated)
- ✅ Git commit created (changes are saved)
- ✅ Salesforce CLI authenticated to medivest-eobbcnb

**Org Dependencies:**
- medivest-eobbcnb sandbox is accessible
- User has deployment permissions
- No active deployments in progress

**Blocks:**
- Task 2.3 (cannot validate Apex without deployment)
- Task 4.2 (cannot run integration tests without deployment)

---

### Task 2.3: Validate Apex Changes with Anonymous Apex

**ID:** MVADM-188-T2.3
**Title:** Test Duplication Method Directly via Anonymous Apex

#### Context
- **Requirements:** Satisfies Requirement #2 from `requirements_MVADM-188.md`
- **SDR Reference:** Step 2.3 (lines 557-630)
- **Purpose:** Verify line number assignment logic works correctly before UI testing

#### Exact Changes

**No code changes** - This is a testing task

**Test Scope:**
- Method: `TRM_MedicalBillingService.createDuplicateBillLineItems`
- Sandbox: medivest-eobbcnb
- Test Data: BCN Case 00375197 or any Bill with existing line items

#### Implementation Instructions

**Step-by-Step:**

1. Log into medivest-eobbcnb sandbox via browser

2. Open Developer Console (Setup → Developer Console)

3. Click "Debug" → "Open Execute Anonymous Window"

4. Paste the following test script:

```apex
// MVADM-188: Test line number assignment in duplication
// Get BCN Case 00375197 or any test Bill
List<Bill__c> testBills = [
    SELECT Id, Name
    FROM Bill__c
    WHERE Name LIKE '%00375197%' OR Name LIKE '%Test%'
    LIMIT 1
];

if (testBills.isEmpty()) {
    System.debug('ERROR: No test Bill found');
    return;
}

Bill__c testBill = testBills[0];
System.debug('Using Bill: ' + testBill.Name + ' (ID: ' + testBill.Id + ')');

// Get existing line items
List<Bill_Line_Item__c> existingItems = [
    SELECT Id, Bill__c, Bill_Line_Item_Number__c,
           Service_Start_Date__c, Service_End_Date__c, CPT_HCPCS_NDC__c
    FROM Bill_Line_Item__c
    WHERE Bill__c = :testBill.Id
    ORDER BY Bill_Line_Item_Number__c ASC NULLS LAST
    LIMIT 5
];

if (existingItems.isEmpty()) {
    System.debug('ERROR: No existing line items found');
    return;
}

System.debug('Existing line items: ' + existingItems.size());
for (Bill_Line_Item__c item : existingItems) {
    System.debug('  Line #' + item.Bill_Line_Item_Number__c +
                 ' - CPT: ' + item.CPT_HCPCS_NDC__c);
}

// Get max line number before duplication
Decimal maxBefore = 0;
for (Bill_Line_Item__c item : existingItems) {
    if (item.Bill_Line_Item_Number__c != null &&
        item.Bill_Line_Item_Number__c > maxBefore) {
        maxBefore = item.Bill_Line_Item_Number__c;
    }
}
System.debug('Max line number before duplication: ' + maxBefore);

// Create duplicate request (duplicate first item 3 times)
List<Map<String, Object>> requests = new List<Map<String, Object>>{
    new Map<String, Object>{
        'originalItemId' => existingItems[0].Id,
        'count' => 3
    }
};

System.debug('--- CALLING createDuplicateBillLineItems ---');

// Call duplication method
List<Bill_Line_Item__c> duplicates =
    TRM_MedicalBillingService.createDuplicateBillLineItems(requests);

System.debug('--- DUPLICATION COMPLETE ---');
System.debug('Duplicates created: ' + duplicates.size());

// Verify line numbers
Boolean allHaveLineNumbers = true;
Boolean allSequential = true;
Decimal expectedLineNumber = maxBefore + 1;

for (Bill_Line_Item__c dup : duplicates) {
    System.debug('Duplicate Line #' + dup.Bill_Line_Item_Number__c +
                 ' - CPT: ' + dup.CPT_HCPCS_NDC__c);

    // Check for null
    if (dup.Bill_Line_Item_Number__c == null) {
        System.debug('❌ FAIL: Line number is null');
        allHaveLineNumbers = false;
    }

    // Check for sequential
    if (dup.Bill_Line_Item_Number__c != expectedLineNumber) {
        System.debug('❌ FAIL: Expected line #' + expectedLineNumber +
                     ', got #' + dup.Bill_Line_Item_Number__c);
        allSequential = false;
    }

    expectedLineNumber++;
}

// Final verdict
if (allHaveLineNumbers && allSequential) {
    System.debug('✅ TEST PASSED: All duplicates have sequential line numbers');
} else {
    System.debug('❌ TEST FAILED: Line number assignment has issues');
}

// Query database to verify persistence
List<Bill_Line_Item__c> allItems = [
    SELECT Id, Bill_Line_Item_Number__c
    FROM Bill_Line_Item__c
    WHERE Bill__c = :testBill.Id
    ORDER BY Bill_Line_Item_Number__c ASC NULLS LAST
];

System.debug('Total line items after duplication: ' + allItems.size());
System.debug('Expected: ' + (existingItems.size() + 3));
```

5. Check "Open Log" checkbox

6. Click "Execute"

7. Review debug log output

8. Verify test passes (look for "✅ TEST PASSED")

9. Query database to double-check:
   ```bash
   sf data query --query "SELECT Id, Bill_Line_Item_Number__c, CPT_HCPCS_NDC__c FROM Bill_Line_Item__c WHERE Bill__c = '<BILL_ID>' ORDER BY Bill_Line_Item_Number__c" --target-org medivest-eobbcnb
   ```

#### Validation

**PASS Criteria:**
- ✅ No exceptions thrown during execution
- ✅ All duplicates have non-null `Bill_Line_Item_Number__c`
- ✅ Line numbers are sequential (e.g., if max was 4, duplicates are 5, 6, 7)
- ✅ No duplicate line numbers in database
- ✅ Debug log shows "✅ TEST PASSED"

**Validation Method:**
- Anonymous Apex execution
- Debug log analysis
- Database query verification

**What Counts as PASS:**
- Debug log contains "✅ TEST PASSED"
- Database query shows sequential line numbers with no gaps or duplicates
- No exceptions in debug log

#### Rollback Plan

**If test fails:**

1. **Analyze failure:**
   - Review debug log for error messages
   - Check which assertion failed
   - Query database to see actual line numbers

2. **Common issues and fixes:**

   **Issue: "Line number is null"**
   - Root cause: Code change not applied correctly
   - Fix: Return to Task 2.1, verify code changes
   - Re-deploy (Task 2.2)
   - Retry test

   **Issue: "Expected line #X, got #Y"**
   - Root cause: Calculation logic error
   - Fix: Review billToMaxLineNumber increment logic in Task 2.1
   - Correct code
   - Re-deploy
   - Retry test

   **Issue: "No test Bill found"**
   - Root cause: Test data missing
   - Fix: Create test Bill or use different query
   - Retry test

3. **Rollback deployment if needed:**
   ```bash
   # Retrieve previous version
   sf project retrieve start --metadata ApexClass:TRM_MedicalBillingService --target-org medivest-eobbcnb

   # Deploy previous version
   sf project deploy start --source-dir force-app/main/default/classes/TRM_MedicalBillingService.cls --target-org medivest-eobbcnb
   ```

4. **Clean up test data:**
   - Delete duplicated line items created during failed test
   - Use Developer Console or Data Loader

#### Dependencies

**Prerequisites:**
- ✅ Task 2.2 complete (Apex deployed to sandbox)
- ✅ Test data exists (Bill with line items)
- ✅ User has Execute Anonymous Apex permission

**Org Dependencies:**
- medivest-eobbcnb sandbox accessible
- BCN Case 00375197 exists OR other test Bills available
- Bill has at least 1 existing line item

**Blocks:**
- Task 4.2 (integration test requires Apex validation)

---

## PHASE 3: LWC IMPLEMENTATION

### Task 3.1: Add formatDateSafely Helper Method

**ID:** MVADM-188-T3.1
**Title:** Create Safe Date Formatting Helper in LWC JavaScript

#### Context
- **Requirements:** Satisfies Requirement #1 from `requirements_MVADM-188.md` - "Fix Row Cloning Bug"
- **SDR Reference:** Section 2B "Add Safe Date Formatting Helper" (lines 269-322), Step 3.1 (lines 636-674)
- **Root Cause:** Bug #2 - Date fields show blank instead of formatted dates in duplicated rows

#### Exact Changes

**File:** `force-app/main/default/lwc/customBillLineItemGrid/customBillLineItemGrid.js`
**Location:** After line 2440 (after `confirmDuplication` method closes)
**Change Type:** CREATE - Add new method

**Code to Add:**

Insert the following method after line 2440:

```javascript
/**
 * MVADM-188: Safely formats a date value to locale string
 * Prevents "undefined" or "Invalid Date" from appearing in UI
 * @param {String|Date|null|undefined} dateValue - Date value to format
 * @returns {String} Formatted date string or empty string if invalid
 */
formatDateSafely(dateValue) {
    // Handle null, undefined, or empty string
    if (!dateValue) {
        return '';
    }

    try {
        const date = new Date(dateValue);

        // Check if date is valid (Invalid Date has NaN time value)
        if (isNaN(date.getTime())) {
            console.warn('[customBillLineItemGrid] Invalid date value:', dateValue);
            return '';
        }

        return date.toLocaleDateString();
    } catch (error) {
        console.error('[customBillLineItemGrid] Error formatting date:', dateValue, error);
        return '';
    }
}
```

#### Implementation Instructions

**Step-by-Step:**

1. Open file in VS Code:
   ```bash
   code force-app/main/default/lwc/customBillLineItemGrid/customBillLineItemGrid.js
   ```

2. Navigate to line 2440 (use Ctrl+G)

3. Verify you're at the end of the `confirmDuplication` method (look for closing brace `}`)

4. Add a blank line after line 2440

5. Paste the `formatDateSafely` method code

6. Ensure proper indentation (4 spaces, same level as other methods)

7. Save file (Ctrl+S)

8. Review changes in Source Control view

9. Commit changes:
   ```bash
   git add force-app/main/default/lwc/customBillLineItemGrid/customBillLineItemGrid.js
   git commit -m "fix(MVADM-188): Add safe date formatting helper to Bill Line Item grid

- Added formatDateSafely() method with null/undefined handling
- Returns empty string for invalid dates instead of 'undefined'
- Logs warnings for debugging without breaking UI
- Part of fix for Bug #2: Blank date fields in duplicated rows"
   ```

#### Validation

**PASS Criteria:**
- ✅ No JavaScript syntax errors (no red squiggles in VS Code)
- ✅ No ESLint warnings
- ✅ Method is properly indented and formatted
- ✅ JSDoc comment is present and complete

**Validation Commands:**
```bash
# Run ESLint on LWC
cd force-app/main/default/lwc/customBillLineItemGrid
npx eslint customBillLineItemGrid.js

# Or use Salesforce CLI scanner
sf scanner run --target "force-app/main/default/lwc/customBillLineItemGrid/**/*.js" --format table
```

**Expected Output:**
```
No issues found
```

**What Counts as PASS:**
- ESLint exits with code 0
- No errors or warnings in output
- VS Code shows no red squiggles in file

#### Rollback Plan

**If validation fails:**

1. **Syntax error:**
   - Review error message
   - Fix syntax (missing comma, brace, etc.)
   - Save and re-validate

2. **ESLint warning:**
   - Review warning message
   - Fix code style issue
   - Save and re-validate

3. **Complete rollback:**
   ```bash
   git checkout -- force-app/main/default/lwc/customBillLineItemGrid/customBillLineItemGrid.js
   ```
   - Carefully re-add method
   - Ensure proper indentation and syntax

#### Dependencies

**Prerequisites:**
- ✅ Phase 1 complete
- ✅ Git repository clean
- ✅ VS Code open with workspace loaded

**Org Dependencies:**
- None (pure JavaScript, no Salesforce dependencies)

**Blocks:**
- Task 3.2 (field mapping depends on this helper method)

**Can Run in Parallel With:**
- Task 2.1, 2.2, 2.3 (Apex changes are independent)

---

### Task 3.2: Fix Field Mapping in confirmDuplication Method

**ID:** MVADM-188-T3.2
**Title:** Add Missing Field Mappings for Code Fields in Duplication Logic

#### Context
- **Requirements:** Satisfies Requirement #1 from `requirements_MVADM-188.md` - "Fix Row Cloning Bug"
- **SDR Reference:** Section 2A "Add Null Safety to Field Mapping" (lines 203-266), Step 3.2 (lines 678-716)
- **Root Cause:** Bug #2 - LWC only maps `*Display` fields, missing `revenueCode`, `posCode`, `cptCode` that HTML template uses

#### Exact Changes

**File:** `force-app/main/default/lwc/customBillLineItemGrid/customBillLineItemGrid.js`
**Method:** `confirmDuplication` (lines 2336-2440)
**Specific Section:** `processedDuplicates` mapping (lines 2371-2414)
**Change Type:** MODIFY - Add missing field mappings

**Current Code (Lines 2371-2414):**
```javascript
const processedDuplicates = duplicatedItems.map(item => ({
    ...item,
    // Selection state
    selected: false,

    // Date formatting for display
    serviceStartDateFormatted: item.Service_Start_Date__c ?
        new Date(item.Service_Start_Date__c).toLocaleDateString() : '',
    serviceEndDateFormatted: item.Service_End_Date__c ?
        new Date(item.Service_End_Date__c).toLocaleDateString() : '',

    // Currency formatting
    chargeFormatted: this.formatCurrency(item.Charge__c),
    // ... other currency fields ...

    // Medicare status display
    medicareStatusDisplay: item.Code__r?.Medicare_Covered__c === true ? 'Yes' :
                         item.Code__r?.Medicare_Covered__c === false ? 'No' : 'Possible',
    // ... other medicare fields ...

    // Duplicate detection flag
    isDuplicate: item.Duplicate_Status__c && item.Duplicate_Status__c !== 'None',
    duplicateStatus: item.Duplicate_Status__c,
    duplicateStatusLabel: this.getDuplicateStatusLabel(item.Duplicate_Status__c),

    // Display names for codes
    revenueCodeDisplay: item.Revenue_Code__c || '',
    posDisplay: item.Place_of_Service__c || '',
    cptDisplay: item.CPT_HCPCS_NDC__c || '',
    modifierDisplay: item.Modifier__c || '',
    quantityDisplay: item.Quantity__c || '',
    descriptionDisplay: item.Description__c || '',
    codeDisplay: item.Code__r?.Name || '',
    accountDisplay: item.Account__r?.Name || ''
}));
```

**Changes to Make:**

1. **REPLACE lines 2377-2380** (date formatting):
```javascript
// MVADM-188: Use safe date formatting helper
serviceStartDateFormatted: this.formatDateSafely(item.Service_Start_Date__c),
serviceEndDateFormatted: this.formatDateSafely(item.Service_End_Date__c),
```

2. **ADD AFTER line 2403** (before `revenueCodeDisplay`):
```javascript
// MVADM-188: Add missing field mappings for code lookup components
// These fields are used by c-code-lookup-field components in HTML template
revenueCode: item.Revenue_Code__c || '',
revenueCodeDescription: '', // Will be populated via batch lookup
```

3. **MODIFY line 2406** (change `revenueCodeDisplay`):
```javascript
revenueCodeDisplay: item.Revenue_Code__c || '',
```

4. **ADD AFTER line 2406**:
```javascript
posCode: item.Place_of_Service__c || '',
posCodeDescription: '', // Will be populated via batch lookup
```

5. **MODIFY line 2407** (change `posDisplay`):
```javascript
posDisplay: item.Place_of_Service__c || '',
```

6. **ADD AFTER line 2407**:
```javascript
cptCode: item.CPT_HCPCS_NDC__c || '',
cptCodeDescription: item.Code__r?.Description__c || '', // From Code__r relationship
```

7. **MODIFY line 2408** (change `cptDisplay`):
```javascript
cptDisplay: item.CPT_HCPCS_NDC__c || '',
```

8. **ADD AFTER line 2409** (after `modifierDisplay`):
```javascript
modifierCode: item.Modifier__c || '',
modifierCodeDescription: '', // Will be populated via batch lookup
```

**Final Result Should Match Pattern from `processLineItems` (lines 821-831):**
```javascript
// Code values and descriptions (matching processLineItems pattern)
revenueCode: item.Revenue_Code__c || '',
revenueCodeDescription: '',
revenueCodeDisplay: item.Revenue_Code__c || '',

posCode: item.Place_of_Service__c || '',
posCodeDescription: '',
posDisplay: item.Place_of_Service__c || '',

cptCode: item.CPT_HCPCS_NDC__c || '',
cptCodeDescription: item.Code__r?.Description__c || '',
cptDisplay: item.CPT_HCPCS_NDC__c || '',

modifierCode: item.Modifier__c || '',
modifierCodeDescription: '',
modifierDisplay: item.Modifier__c || '',
```

#### Implementation Instructions

**Step-by-Step:**

1. Open file in VS Code:
   ```bash
   code force-app/main/default/lwc/customBillLineItemGrid/customBillLineItemGrid.js
   ```

2. Navigate to line 2371 (use Ctrl+G)

3. Locate the `processedDuplicates` mapping

4. Make changes in this order:
   - First: Replace date formatting (lines 2377-2380)
   - Second: Add missing field mappings (after line 2403)
   - Third: Verify all fields match `processLineItems` pattern

5. Use Find (Ctrl+F) to locate `processLineItems` method (line 757)

6. Compare your changes with lines 821-831 to ensure consistency

7. Save file (Ctrl+S)

8. Review changes in Source Control diff view

9. Commit changes:
   ```bash
   git add force-app/main/default/lwc/customBillLineItemGrid/customBillLineItemGrid.js
   git commit -m "fix(MVADM-188): Add missing field mappings to Bill Line Item duplication

- Added revenueCode, posCode, cptCode, modifierCode mappings
- Added *CodeDescription fields for tooltip support
- Replaced date formatting with formatDateSafely() helper
- Matches processLineItems pattern for consistency
- Fixes Bug #2: Code fields showing placeholders instead of values"
   ```

#### Validation

**PASS Criteria:**
- ✅ No JavaScript syntax errors
- ✅ No ESLint warnings
- ✅ All code field mappings present (revenueCode, posCode, cptCode, modifierCode)
- ✅ All *Display fields present
- ✅ All *Description fields present
- ✅ Pattern matches `processLineItems` method (lines 821-831)

**Validation Commands:**
```bash
# Run ESLint
npx eslint force-app/main/default/lwc/customBillLineItemGrid/customBillLineItemGrid.js

# Verify field mappings exist
grep -n "revenueCode:" force-app/main/default/lwc/customBillLineItemGrid/customBillLineItemGrid.js
grep -n "posCode:" force-app/main/default/lwc/customBillLineItemGrid/customBillLineItemGrid.js
grep -n "cptCode:" force-app/main/default/lwc/customBillLineItemGrid/customBillLineItemGrid.js
grep -n "modifierCode:" force-app/main/default/lwc/customBillLineItemGrid/customBillLineItemGrid.js
```

**Expected Output:**
```
No ESLint errors
grep shows matches in both processLineItems and confirmDuplication methods
```

**What Counts as PASS:**
- ESLint exits with code 0
- grep finds field mappings in confirmDuplication method
- VS Code shows no errors

#### Rollback Plan

**If validation fails:**

1. **Syntax error:**
   - Review error message
   - Check for missing commas, braces
   - Fix and re-validate

2. **Missing field:**
   - Compare with `processLineItems` method (lines 821-831)
   - Add missing field mapping
   - Re-validate

3. **Complete rollback:**
   ```bash
   git checkout -- force-app/main/default/lwc/customBillLineItemGrid/customBillLineItemGrid.js
   ```
   - Return to Task 3.1 (ensure formatDateSafely exists)
   - Carefully re-apply changes
   - Use diff view to compare with processLineItems

#### Dependencies

**Prerequisites:**
- ✅ Task 3.1 complete (formatDateSafely method exists)
- ✅ Git repository clean

**Org Dependencies:**
- None (pure JavaScript)

**Blocks:**
- Task 3.3 (cannot deploy without this change)
- Task 3.4 (cannot validate UI without this change)

---

### Task 3.3: Deploy LWC Changes to Sandbox

**ID:** MVADM-188-T3.3
**Title:** Deploy Modified LWC to medivest-eobbcnb Sandbox

#### Context
- **Requirements:** Satisfies Requirement #1 from `requirements_MVADM-188.md`
- **SDR Reference:** Step 3.3 (lines 720-757)
- **Purpose:** Deploy LWC changes to sandbox for UI testing

#### Exact Changes

**Target Org:** medivest-eobbcnb (sandbox)
**Components to Deploy:**
- `customBillLineItemGrid.js`
- `customBillLineItemGrid.html` (no changes, but part of bundle)
- `customBillLineItemGrid.css` (no changes, but part of bundle)
- `customBillLineItemGrid.js-meta.xml` (no changes, but part of bundle)

#### Implementation Instructions

**Step-by-Step:**

1. Verify no uncommitted changes:
   ```bash
   git status
   ```
   Expected: "nothing to commit, working tree clean"

2. Deploy LWC bundle to sandbox:
   ```bash
   sf project deploy start --source-dir force-app/main/default/lwc/customBillLineItemGrid --target-org medivest-eobbcnb
   ```

3. Monitor deployment (command will show progress)

4. Wait for completion (typically 30-60 seconds)

5. Verify deployment success in output

#### Validation

**PASS Criteria:**
- ✅ Deployment status: "Succeeded"
- ✅ No compilation errors
- ✅ Components deployed: 4 (js, html, css, meta.xml)
- ✅ Component failures: 0

**Validation Commands:**
```bash
# Check deployment status
sf project deploy report --target-org medivest-eobbcnb

# Verify LWC is deployed
sf data query --query "SELECT Id, DeveloperName, MasterLabel FROM LightningComponentBundle WHERE DeveloperName = 'customBillLineItemGrid'" --target-org medivest-eobbcnb
```

**Expected Output:**
```
=== Deploy Status
Status: Succeeded
Components Deployed: 4
Component Failures: 0
```

**What Counts as PASS:**
- Deployment command exits with code 0
- Status shows "Succeeded"
- Query returns 1 record for customBillLineItemGrid

#### Rollback Plan

**If deployment fails:**

1. **Review error messages:**
   - Check deployment output for specific errors
   - Common issues: syntax errors, missing dependencies

2. **If JavaScript error:**
   - Return to Task 3.1 or 3.2
   - Fix code issues
   - Re-validate with ESLint
   - Retry deployment

3. **If org issue:**
   - Wait 5 minutes
   - Retry deployment
   - If still fails, contact Salesforce admin

4. **Rollback to previous version:**
   ```bash
   # Retrieve previous version from org
   sf project retrieve start --metadata LightningComponentBundle:customBillLineItemGrid --target-org medivest-eobbcnb

   # Deploy previous version
   sf project deploy start --source-dir force-app/main/default/lwc/customBillLineItemGrid --target-org medivest-eobbcnb
   ```

#### Dependencies

**Prerequisites:**
- ✅ Task 3.1 complete (formatDateSafely method added)
- ✅ Task 3.2 complete (field mappings fixed)
- ✅ Git commits created
- ✅ Salesforce CLI authenticated to medivest-eobbcnb

**Org Dependencies:**
- medivest-eobbcnb sandbox accessible
- User has deployment permissions
- No active deployments in progress

**Blocks:**
- Task 3.4 (cannot validate UI without deployment)
- Task 4.2 (cannot run integration tests without deployment)

---

### Task 3.4: Validate LWC Changes with Manual UI Testing

**ID:** MVADM-188-T3.4
**Title:** Test Duplication in UI with Various Data Scenarios

#### Context
- **Requirements:** Satisfies Requirement #1 from `requirements_MVADM-188.md`
- **SDR Reference:** Step 3.4 (lines 761-825)
- **Purpose:** Verify field mapping fixes work correctly in UI

#### Exact Changes

**No code changes** - This is a testing task

**Test Scope:**
- LWC: customBillLineItemGrid
- Sandbox: medivest-eobbcnb
- Test Case: BCN Case 00375197 or similar Bills

#### Implementation Instructions

**Step-by-Step:**

1. Log into medivest-eobbcnb sandbox via browser

2. Navigate to BCN Case 00375197 (or test Bill)

3. Open browser Developer Console (F12)

4. Open Bill Line Items grid

5. **Test Scenario 1: Duplicate row with all fields populated**
   - Select a row with Service Start Date, Service End Date, Revenue Code, POS, CPT populated
   - Click "Duplicate" button
   - Enter count: 2
   - Click "Create Duplicates"
   - **Verify:**
     - ✅ No "undefined" appears in any column
     - ✅ Service dates show formatted dates (e.g., "1/1/2014")
     - ✅ Revenue Code shows value (e.g., "02"), not placeholder
     - ✅ POS shows value (e.g., "02"), not placeholder
     - ✅ CPT shows value (e.g., "A0021"), not placeholder
     - ✅ Line numbers are sequential
   - Take screenshot

6. **Test Scenario 2: Duplicate row with null dates**
   - Select a row with null Service Start Date and Service End Date
   - Click "Duplicate" button
   - Enter count: 1
   - Click "Create Duplicates"
   - **Verify:**
     - ✅ Date columns show empty (not "undefined" or "Invalid Date")
     - ✅ Line number is assigned
   - Take screenshot

7. **Test Scenario 3: Duplicate row with null Code**
   - Select a row with null Code__c
   - Click "Duplicate" button
   - Enter count: 1
   - Click "Create Duplicates"
   - **Verify:**
     - ✅ Code columns show placeholder (expected behavior for null)
     - ✅ No "undefined" appears
     - ✅ Line number is assigned
   - Take screenshot

8. **Test Scenario 4: Duplicate multiple rows**
   - Select 3 rows
   - Click "Duplicate" button
   - Enter count: 2 for each
   - Click "Create Duplicates"
   - **Verify:**
     - ✅ 6 new rows created
     - ✅ All have sequential line numbers
     - ✅ No "undefined" in any column
   - Take screenshot

9. Check browser console for errors:
   - Look for red errors
   - Look for warnings (yellow)
   - Document any issues

10. Query database to verify:
    ```bash
    sf data query --query "SELECT Id, Bill_Line_Item_Number__c, Service_Start_Date__c, Service_End_Date__c, Revenue_Code__c, Place_of_Service__c, CPT_HCPCS_NDC__c FROM Bill_Line_Item__c WHERE Bill__c = '<BILL_ID>' ORDER BY Bill_Line_Item_Number__c" --target-org medivest-eobbcnb
    ```

#### Validation

**PASS Criteria:**
- ✅ No "undefined" appears in UI under any scenario
- ✅ No "Invalid Date" appears in UI
- ✅ All duplicated rows have non-null line numbers
- ✅ Line numbers are sequential
- ✅ Code fields show values (not placeholders) when original has values
- ✅ Code fields show placeholders (not "undefined") when original is null
- ✅ No JavaScript errors in browser console
- ✅ No Apex errors in Salesforce debug logs

**Validation Method:**
- Manual UI testing
- Browser console inspection
- Database query verification
- Screenshots for documentation

**What Counts as PASS:**
- All 4 test scenarios pass
- No "undefined" text visible in grid
- Database query shows correct field values

#### Rollback Plan

**If test fails:**

1. **Analyze failure:**
   - Which scenario failed?
   - What specific field shows "undefined"?
   - Check browser console for errors

2. **Common issues and fixes:**

   **Issue: "undefined" still appears in code fields**
   - Root cause: Field mapping not applied correctly
   - Fix: Return to Task 3.2, verify all field mappings
   - Re-deploy (Task 3.3)
   - Retry test

   **Issue: "Invalid Date" appears**
   - Root cause: formatDateSafely not being called
   - Fix: Return to Task 3.2, verify date formatting lines
   - Re-deploy (Task 3.3)
   - Retry test

   **Issue: Line numbers still blank**
   - Root cause: Apex issue, not LWC
   - Fix: Return to Task 2.3, verify Apex changes
   - This is NOT an LWC issue

3. **Rollback LWC deployment if needed:**
   ```bash
   # Retrieve previous version
   sf project retrieve start --metadata LightningComponentBundle:customBillLineItemGrid --target-org medivest-eobbcnb

   # Deploy previous version
   sf project deploy start --source-dir force-app/main/default/lwc/customBillLineItemGrid --target-org medivest-eobbcnb
   ```

4. **Clean up test data:**
   - Delete duplicated line items created during testing
   - Use UI or Data Loader

#### Dependencies

**Prerequisites:**
- ✅ Task 3.3 complete (LWC deployed to sandbox)
- ✅ Test data exists (Bill with line items)
- ✅ User has access to sandbox

**Org Dependencies:**
- medivest-eobbcnb sandbox accessible
- BCN Case 00375197 exists OR other test Bills available
- Bill has line items with various field combinations (populated and null)

**Blocks:**
- Task 4.2 (integration test requires LWC validation)

---

## PHASE 4: TESTING AND VALIDATION

### Task 4.1: Update Apex Test Class

**ID:** MVADM-188-T4.1
**Title:** Add Test Methods for Line Number Assignment Logic

#### Context
- **Requirements:** Satisfies testing requirements for Requirement #2
- **SDR Reference:** Step 4.1 (lines 831-929)
- **Purpose:** Ensure code coverage ≥75% and validate line numbering logic

#### Exact Changes

**File:** `force-app/main/default/classes/TRM_MedicalBillingServiceTest.cls`
**Change Type:** MODIFY - Add new test methods

**Test Methods to Add:**

1. `testDuplicateBillLineItems_LineNumbering` - Tests sequential line number assignment
2. `testDuplicateBillLineItems_MultipleOriginals` - Tests multiple duplications in one call

**Code to Add:**

Insert after existing test methods (find a good location, typically at end of class before closing brace):

```apex
/**
 * MVADM-188: Test line number assignment for duplicated Bill Line Items
 * Verifies that duplicates receive sequential line numbers
 */
@isTest
static void testDuplicateBillLineItems_LineNumbering() {
    // Setup: Create Bill with 3 line items (line numbers 1, 2, 3)
    // NOTE: Adjust TestDataFactory calls based on your actual test data factory
    Bill__c testBill = TestDataFactory.createBill();
    insert testBill;

    List<Bill_Line_Item__c> originalItems = new List<Bill_Line_Item__c>();
    for (Integer i = 1; i <= 3; i++) {
        Bill_Line_Item__c item = new Bill_Line_Item__c(
            Bill__c = testBill.Id,
            Bill_Line_Item_Number__c = i,
            CPT_HCPCS_NDC__c = 'TEST' + i,
            Charge__c = 100.00
        );
        originalItems.add(item);
    }
    insert originalItems;

    // Verify setup
    System.assertEquals(3, [SELECT COUNT() FROM Bill_Line_Item__c WHERE Bill__c = :testBill.Id],
                       'Should have 3 original line items');

    // Test: Duplicate the first item 2 times
    List<Map<String, Object>> requests = new List<Map<String, Object>>{
        new Map<String, Object>{
            'originalItemId' => originalItems[0].Id,
            'count' => 2
        }
    };

    Test.startTest();
    List<Bill_Line_Item__c> duplicates = TRM_MedicalBillingService.createDuplicateBillLineItems(requests);
    Test.stopTest();

    // Verify: 2 duplicates created
    System.assertEquals(2, duplicates.size(), 'Should create 2 duplicates');

    // Verify: Line numbers are sequential (4, 5)
    System.assertEquals(4, duplicates[0].Bill_Line_Item_Number__c,
                       'First duplicate should be line 4');
    System.assertEquals(5, duplicates[1].Bill_Line_Item_Number__c,
                       'Second duplicate should be line 5');

    // Verify: Total count is now 5
    System.assertEquals(5, [SELECT COUNT() FROM Bill_Line_Item__c WHERE Bill__c = :testBill.Id],
                       'Should have 5 total line items after duplication');

    // Verify: All line numbers are unique
    List<Bill_Line_Item__c> allItems = [
        SELECT Bill_Line_Item_Number__c
        FROM Bill_Line_Item__c
        WHERE Bill__c = :testBill.Id
    ];
    Set<Decimal> lineNumbers = new Set<Decimal>();
    for (Bill_Line_Item__c item : allItems) {
        System.assertNotEquals(null, item.Bill_Line_Item_Number__c,
                              'Line number should not be null');
        lineNumbers.add(item.Bill_Line_Item_Number__c);
    }
    System.assertEquals(5, lineNumbers.size(), 'All line numbers should be unique');
}

/**
 * MVADM-188: Test duplicating multiple original items in one call
 * Verifies that all duplicates receive unique sequential line numbers
 */
@isTest
static void testDuplicateBillLineItems_MultipleOriginals() {
    // Setup: Create Bill with 2 line items
    Bill__c testBill = TestDataFactory.createBill();
    insert testBill;

    List<Bill_Line_Item__c> originalItems = new List<Bill_Line_Item__c>();
    for (Integer i = 1; i <= 2; i++) {
        Bill_Line_Item__c item = new Bill_Line_Item__c(
            Bill__c = testBill.Id,
            Bill_Line_Item_Number__c = i,
            CPT_HCPCS_NDC__c = 'TEST' + i,
            Charge__c = 100.00
        );
        originalItems.add(item);
    }
    insert originalItems;

    // Test: Duplicate both items (1 copy each)
    List<Map<String, Object>> requests = new List<Map<String, Object>>{
        new Map<String, Object>{'originalItemId' => originalItems[0].Id, 'count' => 1},
        new Map<String, Object>{'originalItemId' => originalItems[1].Id, 'count' => 1}
    };

    Test.startTest();
    List<Bill_Line_Item__c> duplicates = TRM_MedicalBillingService.createDuplicateBillLineItems(requests);
    Test.stopTest();

    // Verify: 2 duplicates created with sequential line numbers (3, 4)
    System.assertEquals(2, duplicates.size(), 'Should create 2 duplicates');

    Set<Decimal> lineNumbers = new Set<Decimal>();
    for (Bill_Line_Item__c dup : duplicates) {
        System.assertNotEquals(null, dup.Bill_Line_Item_Number__c,
                              'Duplicate line number should not be null');
        lineNumbers.add(dup.Bill_Line_Item_Number__c);
    }

    System.assert(lineNumbers.contains(3), 'Should have line number 3');
    System.assert(lineNumbers.contains(4), 'Should have line number 4');

    // Verify: Total count is now 4
    System.assertEquals(4, [SELECT COUNT() FROM Bill_Line_Item__c WHERE Bill__c = :testBill.Id],
                       'Should have 4 total line items');
}
```

**NOTE:** You may need to adjust `TestDataFactory.createBill()` based on your actual test data factory implementation. If no factory exists, create Bill directly:

```apex
Bill__c testBill = new Bill__c(
    Name = 'Test Bill',
    // Add required fields
);
```

#### Implementation Instructions

**Step-by-Step:**

1. Open test class in VS Code:
   ```bash
   code force-app/main/default/classes/TRM_MedicalBillingServiceTest.cls
   ```

2. Scroll to end of class (before final closing brace)

3. Add the two test methods

4. Adjust TestDataFactory calls if needed based on your codebase

5. Save file (Ctrl+S)

6. Run tests locally:
   ```bash
   sf apex run test --class-names TRM_MedicalBillingServiceTest --target-org medivest-eobbcnb --result-format human --code-coverage
   ```

7. Verify all tests pass

8. Check code coverage for `createDuplicateBillLineItems` method

9. Commit changes:
   ```bash
   git add force-app/main/default/classes/TRM_MedicalBillingServiceTest.cls
   git commit -m "test(MVADM-188): Add tests for Bill Line Item duplication line numbering

- Added testDuplicateBillLineItems_LineNumbering test
- Added testDuplicateBillLineItems_MultipleOriginals test
- Verifies sequential line number assignment
- Verifies uniqueness of line numbers
- Ensures code coverage ≥75% for modified methods"
   ```

#### Validation

**PASS Criteria:**
- ✅ All new test methods pass
- ✅ All existing test methods still pass (no regression)
- ✅ Code coverage for `createDuplicateBillLineItems` is ≥75%
- ✅ No test failures or errors

**Validation Commands:**
```bash
# Run specific test class
sf apex run test --class-names TRM_MedicalBillingServiceTest --target-org medivest-eobbcnb --result-format human --code-coverage

# Run all tests (regression check)
sf apex run test --target-org medivest-eobbcnb --result-format human --code-coverage --wait 10
```

**Expected Output:**
```
=== Test Results
Passing: X (including 2 new tests)
Failing: 0
Skipped: 0

=== Code Coverage
TRM_MedicalBillingService: XX% (≥75%)
```

**What Counts as PASS:**
- Test command exits with code 0
- "Failing: 0" in output
- Code coverage ≥75% for TRM_MedicalBillingService

#### Rollback Plan

**If tests fail:**

1. **Analyze failure:**
   - Review test failure message
   - Check which assertion failed
   - Review test data setup

2. **Common issues and fixes:**

   **Issue: "TestDataFactory.createBill() does not exist"**
   - Fix: Replace with direct Bill creation (see NOTE in code section)
   - Retry test

   **Issue: "Required field missing"**
   - Fix: Add required fields to Bill or Bill_Line_Item__c creation
   - Retry test

   **Issue: "Expected 4, got 5"**
   - Root cause: Apex logic error
   - Fix: Return to Task 2.1, review line number calculation
   - Re-deploy Apex
   - Retry test

3. **Rollback test changes:**
   ```bash
   git checkout -- force-app/main/default/classes/TRM_MedicalBillingServiceTest.cls
   ```
   - Fix issues
   - Re-add test methods
   - Retry

#### Dependencies

**Prerequisites:**
- ✅ Task 2.1 complete (Apex code modified)
- ✅ Task 2.2 complete (Apex deployed to sandbox)

**Org Dependencies:**
- medivest-eobbcnb sandbox accessible
- Bill__c and Bill_Line_Item__c objects exist
- User has permission to run tests

**Can Run in Parallel With:**
- Task 3.1, 3.2, 3.3, 3.4 (LWC changes are independent)

**Blocks:**
- None (tests are independent, but good practice to have before UAT)

---

### Task 4.2: End-to-End Integration Test

**ID:** MVADM-188-T4.2
**Title:** Test Complete Workflow from Draft Creation to Duplication

#### Context
- **Requirements:** Satisfies all requirements from `requirements_MVADM-188.md`
- **SDR Reference:** Step 4.2 (lines 933-1001)
- **Purpose:** Verify Apex + LWC + Triggers + Flows work together correctly

#### Exact Changes

**No code changes** - This is a comprehensive testing task

**Test Scope:**
- LWC: customBillLineItemGrid
- Apex: TRM_MedicalBillingService
- Triggers: BillLineItemDuplicateDetection, dlrs_Bill_Line_ItemTrigger
- Flows: Bill_Line_Item_Generate_Filemaker_Id, Bill_Line_Item_Create_Update_Filemaker_Sync_Event

#### Implementation Instructions

**Step-by-Step:**

1. Log into medivest-eobbcnb sandbox

2. Navigate to a Bill record (BCN Case 00375197 or create new test Bill)

3. Enable Salesforce Debug Logs:
   - Setup → Debug Logs
   - Click "New"
   - Select your user
   - Set all log levels to "FINEST"
   - Save

4. Open Bill Line Items grid

5. **Test Step A: Create new draft line item**
   - Enter data in draft row:
     - Service Start Date: 01/01/2024
     - Service End Date: 01/31/2024
     - Revenue Code: 01
     - POS: 11
     - CPT: 99213
     - Charge: 100.00
   - Press Tab to save
   - **Verify:**
     - ✅ Line number assigned (e.g., 1)
     - ✅ Row moves from draft to permanent
     - ✅ New empty draft row appears
   - Take screenshot

6. **Test Step B: Create another draft line item**
   - Enter data in draft row:
     - Service Start Date: 02/01/2024
     - Service End Date: 02/28/2024
     - Revenue Code: 02
     - POS: 12
     - CPT: 99214
     - Charge: 150.00
   - Press Tab to save
   - **Verify:**
     - ✅ Line number assigned (e.g., 2)
     - ✅ Sequential from previous line
   - Take screenshot

7. **Test Step C: Duplicate first line item**
   - Select row with line number 1
   - Click "Duplicate" button
   - Enter count: 2
   - Click "Create Duplicates"
   - **Verify:**
     - ✅ Two new rows with line numbers 3 and 4
     - ✅ Service dates copied: 01/01/2024, 01/31/2024
     - ✅ Revenue Code copied: 01
     - ✅ POS copied: 11
     - ✅ CPT copied: 99213
     - ✅ Charge copied: $100.00
     - ✅ No "undefined" in any column
   - Take screenshot

8. **Test Step D: Verify triggers and flows executed**
   - Download debug logs:
     - Setup → Debug Logs
     - Click "View" on most recent log
     - Search for "BillLineItemDuplicateDetection"
     - Search for "Bill_Line_Item_Generate_Filemaker_Id"
   - **Verify:**
     - ✅ Duplicate detection trigger executed
     - ✅ FileMaker ID flow executed
     - ✅ No errors in debug log

9. **Test Step E: Verify data integrity**
   - Query database:
     ```bash
     sf data query --query "SELECT Id, Bill_Line_Item_Number__c, Service_Start_Date__c, Service_End_Date__c, Revenue_Code__c, Place_of_Service__c, CPT_HCPCS_NDC__c, Charge__c, External_Id__c, Duplicate_Status__c FROM Bill_Line_Item__c WHERE Bill__c = '<BILL_ID>' ORDER BY Bill_Line_Item_Number__c" --target-org medivest-eobbcnb
     ```
   - **Verify:**
     - ✅ 4 line items total (2 drafts + 2 duplicates)
     - ✅ Line numbers: 1, 2, 3, 4 (sequential, no gaps)
     - ✅ All line numbers are unique
     - ✅ No null line numbers
     - ✅ All required fields populated
     - ✅ External_Id__c populated (FileMaker integration)
     - ✅ Duplicate_Status__c populated (duplicate detection)

10. Document results in Jira ticket

#### Validation

**PASS Criteria:**
- ✅ Draft rows receive sequential line numbers
- ✅ Duplicated rows receive sequential line numbers
- ✅ No "undefined" appears in UI
- ✅ All field values copied correctly (dates, codes, amounts)
- ✅ Triggers execute successfully (no errors in debug logs)
- ✅ Flows execute successfully (External_Id__c populated)
- ✅ Duplicate detection runs (Duplicate_Status__c updated)
- ✅ All line numbers are unique within the Bill
- ✅ No null line numbers in database

**Validation Method:**
- Manual UI testing
- Debug log analysis
- Database query verification
- Screenshots for documentation

**What Counts as PASS:**
- All 5 test steps (A, B, C, D, E) pass
- No errors in debug logs
- Database query shows correct data

#### Rollback Plan

**If test fails:**

1. **Identify which step failed:**
   - Step A or B (draft creation): Likely existing issue, not related to MVADM-188
   - Step C (duplication): Related to our changes
   - Step D or E (triggers/flows): May be existing issue or data integrity problem

2. **If Step C fails:**
   - Check which specific verification failed
   - If "undefined" appears: LWC issue, return to Task 3.2
   - If line numbers wrong: Apex issue, return to Task 2.1
   - If fields not copied: Check both Apex and LWC

3. **If triggers/flows fail:**
   - Review debug logs for specific error
   - Determine if error is related to our changes
   - If unrelated: Document as separate issue
   - If related: Analyze impact and fix

4. **Rollback if needed:**
   ```bash
   # Rollback Apex
   sf project retrieve start --metadata ApexClass:TRM_MedicalBillingService --target-org medivest-eobbcnb
   sf project deploy start --source-dir force-app/main/default/classes/TRM_MedicalBillingService.cls --target-org medivest-eobbcnb

   # Rollback LWC
   sf project retrieve start --metadata LightningComponentBundle:customBillLineItemGrid --target-org medivest-eobbcnb
   sf project deploy start --source-dir force-app/main/default/lwc/customBillLineItemGrid --target-org medivest-eobbcnb
   ```

5. **Clean up test data:**
   - Delete test line items created during testing
   - Use UI or Data Loader

#### Dependencies

**Prerequisites:**
- ✅ Task 2.3 complete (Apex validated)
- ✅ Task 3.4 complete (LWC validated)
- ✅ Task 4.1 complete (tests passing)

**Org Dependencies:**
- medivest-eobbcnb sandbox accessible
- All triggers and flows are active
- Test Bill exists or can be created
- User has full permissions

**Blocks:**
- Task 5.1 (UAT prep requires integration test pass)

---

## PHASE 5: USER ACCEPTANCE TESTING (UAT)

### Task 5.1: Prepare UAT Environment

**ID:** MVADM-188-T5.1
**Title:** Set Up Sandbox for Chris Caines UAT Testing

#### Context
- **Requirements:** Satisfies UAT requirements from `requirements_MVADM-188.md`
- **SDR Reference:** Step 5.1 (lines 1007-1048)
- **Purpose:** Ensure sandbox is ready for stakeholder testing

#### Exact Changes

**No code changes** - This is a setup task

**Setup Scope:**
- Create test data in medivest-eobbcnb
- Document test scenarios
- Grant access to Chris Caines

#### Implementation Instructions

**Step-by-Step:**

1. **Create UAT test data:**

   a. Bill with 0 line items (for testing draft creation):
   ```bash
   sf data create record --sobject Bill__c --values "Name='UAT Test Bill 1 - Empty'" --target-org medivest-eobbcnb --json
   ```
   Note the returned ID

   b. Bill with 5 line items (for testing duplication):
   - Use existing BCN Case 00375197 OR
   - Create new Bill and add 5 line items via UI

   c. Bill with line items that have null dates:
   - Create Bill
   - Add line items with CPT codes but no Service dates

   d. Bill with line items that have null Code__c:
   - Create Bill
   - Add line items with dates but no CPT codes

2. **Document test data in Jira ticket:**

   Add comment to MVADM-188:
   ```
   UAT Test Data Prepared:

   1. **Bill for Draft Testing:**
      - Bill ID: <ID_FROM_STEP_1a>
      - Name: UAT Test Bill 1 - Empty
      - Line Items: 0
      - Purpose: Test draft line item creation and auto-numbering

   2. **Bill for Duplication Testing:**
      - Bill ID: <BCN_CASE_00375197_ID>
      - Name: BCN Case 00375197
      - Line Items: 4 (with populated dates and codes)
      - Purpose: Test duplication with all fields populated

   3. **Bill for Null Date Testing:**
      - Bill ID: <ID>
      - Name: UAT Test Bill 2 - Null Dates
      - Line Items: 2 (with codes but no dates)
      - Purpose: Test duplication with null dates

   4. **Bill for Null Code Testing:**
      - Bill ID: <ID>
      - Name: UAT Test Bill 3 - Null Codes
      - Line Items: 2 (with dates but no codes)
      - Purpose: Test duplication with null codes

   **Expected Results:**
   - Draft creation: Sequential line numbers (1, 2, 3...)
   - Duplication with data: All fields copied, no "undefined"
   - Duplication with nulls: Empty fields (not "undefined")
   - All scenarios: Sequential line numbers assigned
   ```

3. **Verify Chris Caines has sandbox access:**
   - Setup → Users
   - Search for Chris Caines
   - Verify user is active
   - Verify user has appropriate permissions
   - If not: Grant access or request admin to grant access

4. **Send UAT instructions to Chris Caines:**

   Email template:
   ```
   Subject: MVADM-188 Ready for UAT - Bill Line Item Duplication Fixes

   Hi Chris,

   The fixes for MVADM-188 (Bill Review UAT Bugs) are ready for your testing in the medivest-eobbcnb sandbox.

   **What was fixed:**
   1. Bug #1: Duplicated rows now receive sequential line numbers (no more blank Line #)
   2. Bug #2: All fields are now copied correctly (no more "undefined" in dates and codes)

   **Test Data:**
   I've prepared 4 test Bills for you:
   1. UAT Test Bill 1 - Empty (for draft creation testing)
   2. BCN Case 00375197 (for duplication testing - this is the case you originally reported)
   3. UAT Test Bill 2 - Null Dates (edge case testing)
   4. UAT Test Bill 3 - Null Codes (edge case testing)

   **Test Scenarios:**
   Please test the following:
   1. Create new draft line items → Verify sequential line numbers
   2. Duplicate existing line items → Verify no "undefined" appears
   3. Duplicate items with null dates → Verify empty (not "undefined")
   4. Duplicate items with null codes → Verify placeholders (not "undefined")

   **Expected Results:**
   - All duplicated rows should have sequential line numbers
   - All field values should be copied correctly
   - No "undefined" should appear anywhere in the grid

   **How to Test:**
   1. Log into medivest-eobbcnb sandbox
   2. Navigate to one of the test Bills
   3. Open Bill Line Items grid
   4. Follow the test scenarios above
   5. Let me know if you see any issues

   **Timeline:**
   Please complete testing by [DATE]. Let me know if you need more time.

   **Questions:**
   If you have any questions or find any issues, please reply to this email or add a comment to the Jira ticket.

   Thanks!
   [Your Name]
   ```

#### Validation

**PASS Criteria:**
- ✅ Test data created successfully (4 Bills with various configurations)
- ✅ Test data documented in Jira ticket
- ✅ Chris Caines has sandbox access
- ✅ UAT instructions sent to Chris Caines
- ✅ Email confirmation received (or meeting scheduled)

**Validation Method:**
- Manual verification
- Email confirmation
- Jira ticket updated

**What Counts as PASS:**
- All 4 test Bills exist in sandbox
- Jira comment added with test data details
- Email sent to Chris Caines

#### Rollback Plan

**No rollback needed** - This is a setup task with no code changes

**If issues arise:**
- Test data can be deleted and recreated
- Email can be resent with corrections
- Access issues can be resolved with admin

#### Dependencies

**Prerequisites:**
- ✅ Task 4.2 complete (integration test passed)
- ✅ All code changes deployed to sandbox
- ✅ Sandbox is stable and accessible

**Org Dependencies:**
- medivest-eobbcnb sandbox accessible
- User has permission to create Bills and Line Items
- Chris Caines user exists in sandbox

**Blocks:**
- Task 5.2 (UAT cannot start without test data and instructions)

---

### Task 5.2: Conduct UAT with Chris Caines 🔴 HUMAN REQUIRED

**ID:** MVADM-188-T5.2
**Title:** Stakeholder Testing Session with Chris Caines

#### Context
- **Requirements:** Satisfies Success Criteria from `requirements_MVADM-188.md`
- **SDR Reference:** Step 5.2 (lines 1052-1092)
- **Purpose:** Obtain stakeholder validation that bugs are fixed

#### Exact Changes

**No code changes** - This is a human-driven testing task

**Test Scope:**
- Stakeholder: Chris Caines
- Environment: medivest-eobbcnb sandbox
- Duration: 30-60 minutes

#### Implementation Instructions

**Step-by-Step:**

1. **Schedule UAT session:**
   - Send calendar invite to Chris Caines
   - Duration: 60 minutes (30 min testing + 30 min buffer)
   - Include Zoom/Teams link if remote
   - Include link to Jira ticket in meeting notes

2. **Prepare for session:**
   - Have test data IDs ready
   - Have browser open to sandbox
   - Have screen sharing ready
   - Have Jira ticket open for notes

3. **During UAT session:**

   a. **Introduction (5 min):**
      - Explain what was fixed
      - Show test data prepared
      - Explain test scenarios

   b. **Test Scenario 1: Original Bug Reproduction (10 min):**
      - Navigate to BCN Case 00375197
      - Ask Chris to perform original reproduction steps
      - Observe: No "undefined" appears
      - Observe: Line numbers are assigned
      - Ask: "Is this what you expected?"

   c. **Test Scenario 2: Draft Creation (5 min):**
      - Navigate to empty test Bill
      - Ask Chris to create 2-3 draft line items
      - Observe: Sequential line numbers assigned
      - Ask: "Do the line numbers look correct?"

   d. **Test Scenario 3: Edge Cases (10 min):**
      - Test duplication with null dates
      - Test duplication with null codes
      - Observe: No "undefined" appears
      - Ask: "Does this behavior make sense?"

   e. **Free Testing (15 min):**
      - Ask Chris to test any other scenarios
      - Observe and take notes
      - Document any issues found

   f. **Wrap-up (5 min):**
      - Ask: "Are the original bugs fixed?"
      - Ask: "Do you see any new issues?"
      - Ask: "Is this ready for production?"

4. **Take notes during session:**
   - Document all feedback
   - Screenshot any issues
   - Note any new bugs discovered

5. **After session:**
   - Thank Chris for testing
   - Summarize findings in email
   - Update Jira ticket with results

#### Validation

**PASS Criteria:**
- ✅ Chris Caines confirms Bug #1 is fixed (line numbers assigned)
- ✅ Chris Caines confirms Bug #2 is fixed (no "undefined" values)
- ✅ No new critical bugs introduced
- ✅ Chris Caines approves the fix for production deployment

**Validation Method:**
- Manual UAT session
- Stakeholder verbal or written approval

**What Counts as PASS:**
- Chris Caines says: "The bugs are fixed, this is ready for production"
- OR Chris Caines provides written approval in Jira ticket
- AND no new critical bugs found

**What Counts as FAIL:**
- Original bugs still present
- New critical bugs introduced
- Chris Caines does not approve for production

#### Rollback Plan

**If UAT fails:**

1. **Document issues found:**
   - Add detailed notes to Jira ticket
   - Include screenshots
   - Categorize: Critical, High, Medium, Low

2. **Assess scope:**
   - Are issues related to MVADM-188 changes?
   - Are issues new bugs (out of scope)?
   - Are issues existing bugs (not introduced by us)?

3. **Decision tree:**

   **If original bugs still present:**
   - Return to root cause analysis
   - Review code changes
   - Fix issues
   - Re-deploy
   - Schedule new UAT session

   **If new critical bugs introduced:**
   - Rollback changes immediately
   - Analyze what went wrong
   - Fix issues
   - Re-test internally (Task 4.2)
   - Schedule new UAT session

   **If new minor bugs found:**
   - Document as separate tickets
   - Discuss with Chris: Deploy now or fix first?
   - If deploy now: Proceed to Task 5.3
   - If fix first: Create new tickets and fix

   **If existing bugs found (not related to our changes):**
   - Document as separate tickets
   - Proceed to Task 5.3 (not blocking)

#### Dependencies

**Prerequisites:**
- ✅ Task 5.1 complete (UAT environment prepared)
- ✅ Chris Caines available for testing
- ✅ Sandbox is stable

**Org Dependencies:**
- medivest-eobbcnb sandbox accessible
- Test data exists and is valid
- No other deployments in progress

**Blocks:**
- Task 5.3 (cannot get sign-off without UAT)
- All Phase 6 tasks (cannot deploy without UAT approval)

---

### Task 5.3: Obtain UAT Sign-Off 🔴 HUMAN REQUIRED

**ID:** MVADM-188-T5.3
**Title:** Get Formal Approval from Chris Caines for Production Deployment

#### Context
- **Requirements:** Satisfies approval requirements from `requirements_MVADM-188.md`
- **SDR Reference:** Step 5.3 (lines 1096-1131)
- **Purpose:** Obtain formal stakeholder approval before production deployment

#### Exact Changes

**No code changes** - This is an approval task

**Approval Scope:**
- Stakeholder: Chris Caines
- Approval Type: Written approval in Jira ticket

#### Implementation Instructions

**Step-by-Step:**

1. **Request formal approval:**

   Add comment to Jira ticket MVADM-188:
   ```
   @Chris Caines

   UAT Session Summary:
   - Date: [DATE]
   - Duration: [DURATION]
   - Test Scenarios: [LIST]
   - Results: [SUMMARY]

   **Bugs Fixed:**
   ✅ Bug #1: Duplicated rows now have sequential line numbers
   ✅ Bug #2: All fields copied correctly, no "undefined" values

   **Issues Found:**
   [LIST ANY ISSUES, OR "None"]

   **Request for Approval:**
   Please confirm that this fix is ready for production deployment by:
   1. Adding a comment: "UAT passed, approved for production"
   2. Moving this ticket to "Ready for Deployment" status

   If you have any concerns or need additional testing, please let me know.

   Thanks!
   ```

2. **Wait for approval:**
   - Monitor Jira ticket for response
   - Follow up if no response within 24 hours
   - Be available to answer questions

3. **If Chris requests changes:**
   - Document requested changes in ticket
   - Assess if changes are in scope for MVADM-188
   - If in scope: Implement changes, re-test, repeat UAT
   - If out of scope: Create new ticket, proceed with current fix

4. **Once approval received:**
   - Update ticket status to "Ready for Deployment"
   - Add comment with approval date
   - Proceed to Phase 6

#### Validation

**PASS Criteria:**
- ✅ Jira ticket has approval comment from Chris Caines
- ✅ Ticket status is "Ready for Deployment" or equivalent
- ✅ Approval is explicit and unambiguous

**Validation Method:**
- Manual verification in Jira

**What Counts as PASS:**
- Comment from Chris Caines containing: "approved for production" or "ready for production" or similar
- Ticket status changed to deployment-ready state

**What Counts as FAIL:**
- No response from Chris Caines
- Chris Caines requests changes
- Chris Caines does not approve

#### Rollback Plan

**If approval not received:**

1. **Follow up:**
   - Send reminder email after 24 hours
   - Escalate to manager if no response after 48 hours

2. **If changes requested:**
   - Return to appropriate task based on change type
   - Implement changes
   - Re-test
   - Schedule new UAT
   - Request approval again

3. **If approval denied:**
   - Understand reasons
   - Document in ticket
   - Assess next steps with team
   - May need to rollback changes

#### Dependencies

**Prerequisites:**
- ✅ Task 5.2 complete (UAT conducted)
- ✅ UAT passed successfully
- ✅ No critical bugs found

**Org Dependencies:**
- None (approval is external to org)

**Blocks:**
- All Phase 6 tasks (cannot deploy without approval)

---

## PHASE 6: PRODUCTION DEPLOYMENT 🔴 REQUIRES EXPLICIT PERMISSION

⚠️ **CRITICAL WARNING:** Do NOT execute any Phase 6 tasks without explicit permission from stakeholders and management.

### Task 6.1: Create Deployment Package

**ID:** MVADM-188-T6.1
**Title:** Prepare and Validate Production Deployment Package

#### Context
- **Requirements:** Satisfies deployment requirements
- **SDR Reference:** Step 6.1 (lines 1139-1200)
- **Purpose:** Create validated deployment package for production

#### Exact Changes

**No org changes** - This is a packaging task

**Package Contents:**
- `TRM_MedicalBillingService.cls`
- `TRM_MedicalBillingServiceTest.cls`
- `customBillLineItemGrid` (LWC bundle)

#### Implementation Instructions

**Step-by-Step:**

1. **Create deployment branch:**
   ```bash
   git checkout -b deploy/MVADM-188-production
   ```

2. **Merge feature branch:**
   ```bash
   git merge fix/MVADM-188-bill-line-item-bugs
   ```

3. **Create deployment manifest (package.xml):**

   Create file: `manifest/package.xml`
   ```xml
   <?xml version="1.0" encoding="UTF-8"?>
   <Package xmlns="http://soap.sforce.com/2006/04/metadata">
       <types>
           <members>TRM_MedicalBillingService</members>
           <members>TRM_MedicalBillingServiceTest</members>
           <name>ApexClass</name>
       </types>
       <types>
           <members>customBillLineItemGrid</members>
           <name>LightningComponentBundle</name>
       </types>
       <version>62.0</version>
   </Package>
   ```

4. **Validate deployment (does NOT deploy):**
   ```bash
   sf project deploy validate --manifest manifest/package.xml --target-org <PRODUCTION_ORG_ALIAS> --test-level RunLocalTests --wait 30
   ```

   **IMPORTANT:** Replace `<PRODUCTION_ORG_ALIAS>` with actual production org alias

5. **Monitor validation:**
   - Command will run tests
   - Wait for completion (may take 10-30 minutes)
   - Review results

6. **Save validation ID:**
   - Copy the Job ID from validation output
   - Save it for Task 6.2 (quick deployment)

7. **Review validation results:**
   - Check test results
   - Check code coverage
   - Check for any warnings

8. **Commit deployment manifest:**
   ```bash
   git add manifest/package.xml
   git commit -m "deploy(MVADM-188): Add production deployment manifest

- Includes TRM_MedicalBillingService and test class
- Includes customBillLineItemGrid LWC
- Validated against production org
- Validation ID: [PASTE_VALIDATION_ID]"
   ```

#### Validation

**PASS Criteria:**
- ✅ Validation status: "Succeeded"
- ✅ All tests pass in production
- ✅ Code coverage ≥75%
- ✅ No deployment errors or warnings
- ✅ Validation ID saved

**Validation Commands:**
```bash
# Check validation status
sf project deploy report --job-id <VALIDATION_JOB_ID> --target-org <PRODUCTION_ORG_ALIAS>

# Verify validation succeeded
echo $?  # Should be 0
```

**Expected Output:**
```
=== Deploy Status
Status: Succeeded
Test Run Status: Completed
Tests Passed: X
Tests Failed: 0
Code Coverage: XX% (≥75%)
```

**What Counts as PASS:**
- Validation command exits with code 0
- "Status: Succeeded"
- "Tests Failed: 0"
- Code coverage ≥75%

#### Rollback Plan

**If validation fails:**

1. **Analyze failure:**
   - Review validation output
   - Check which tests failed
   - Check code coverage

2. **Common issues and fixes:**

   **Issue: "Tests failed in production"**
   - Root cause: Production data different from sandbox
   - Fix: Review test failures, update tests if needed
   - Re-validate

   **Issue: "Code coverage below 75%"**
   - Root cause: Not enough test coverage
   - Fix: Add more tests (return to Task 4.1)
   - Re-validate

   **Issue: "Deployment error: Missing dependency"**
   - Root cause: Production org missing required metadata
   - Fix: Deploy dependencies first, then re-validate

3. **Do NOT proceed to Task 6.2 if validation fails**

#### Dependencies

**Prerequisites:**
- ✅ Task 5.3 complete (UAT sign-off received)
- ✅ All code changes committed
- ✅ Production org alias configured in Salesforce CLI

**Org Dependencies:**
- Production org accessible
- User has deployment permissions
- Production org has all required dependencies

**Blocks:**
- Task 6.2 (cannot deploy without successful validation)

---

### Task 6.2: Deploy to Production 🔴 HUMAN APPROVAL REQUIRED

**ID:** MVADM-188-T6.2
**Title:** Execute Production Deployment

#### Context
- **Requirements:** Satisfies production deployment requirements
- **SDR Reference:** Step 6.2 (lines 1204-1248)
- **Purpose:** Deploy validated changes to production org

⚠️ **CRITICAL:** This task deploys to production. Requires explicit approval.

#### Exact Changes

**Target Org:** Production
**Components to Deploy:**
- `TRM_MedicalBillingService.cls`
- `TRM_MedicalBillingServiceTest.cls`
- `customBillLineItemGrid` (LWC bundle)

#### Implementation Instructions

**Step-by-Step:**

1. **⚠️ STOP - Confirm Permission:**
   - [ ] UAT sign-off received (Task 5.3 complete)
   - [ ] Validation passed (Task 6.1 complete)
   - [ ] Stakeholders notified of deployment
   - [ ] Deployment window scheduled (if required)
   - [ ] Explicit permission to deploy received

   **DO NOT PROCEED WITHOUT ALL CHECKBOXES CHECKED**

2. **Notify stakeholders:**
   - Send email to Chris Caines, team, and management
   - Subject: "MVADM-188 Production Deployment Starting"
   - Include: Deployment time, expected duration, components

3. **Deploy using validated deployment ID:**
   ```bash
   sf project deploy quick --job-id <VALIDATION_JOB_ID_FROM_TASK_6.1> --target-org <PRODUCTION_ORG_ALIAS>
   ```

   **Benefits of quick deployment:**
   - Uses validation results (no tests re-run)
   - Faster deployment (typically 1-2 minutes)
   - Same results as validation

4. **Monitor deployment:**
   - Watch command output
   - Do NOT interrupt deployment
   - Wait for completion

5. **Verify deployment success:**
   - Check command exit code
   - Review deployment output
   - Verify status: "Succeeded"

6. **Notify stakeholders of completion:**
   - Send email: "MVADM-188 Production Deployment Complete"
   - Include: Deployment time, status, next steps

7. **Update Jira ticket:**
   - Add comment with deployment details
   - Move ticket to "Deployed to Production" status

#### Validation

**PASS Criteria:**
- ✅ Deployment status: "Succeeded"
- ✅ No errors in deployment log
- ✅ Components deployed: 3 (2 Apex classes + 1 LWC)
- ✅ Stakeholders notified

**Validation Commands:**
```bash
# Check deployment status
sf project deploy report --job-id <DEPLOYMENT_JOB_ID> --target-org <PRODUCTION_ORG_ALIAS>

# Verify components deployed
sf data query --query "SELECT Id, Name FROM ApexClass WHERE Name IN ('TRM_MedicalBillingService', 'TRM_MedicalBillingServiceTest')" --target-org <PRODUCTION_ORG_ALIAS>

sf data query --query "SELECT Id, DeveloperName FROM LightningComponentBundle WHERE DeveloperName = 'customBillLineItemGrid'" --target-org <PRODUCTION_ORG_ALIAS>
```

**Expected Output:**
```
=== Deploy Status
Status: Succeeded
Components Deployed: 3
```

**What Counts as PASS:**
- Deployment command exits with code 0
- "Status: Succeeded"
- All components present in production

#### Rollback Plan

**If deployment fails:**

1. **IMMEDIATE ACTION:**
   - Do NOT retry deployment
   - Notify stakeholders immediately
   - Assess impact

2. **Analyze failure:**
   - Review deployment error messages
   - Check production debug logs
   - Determine if partial deployment occurred

3. **Rollback options:**

   **Option A: Quick rollback (if previous version available):**
   ```bash
   # Retrieve previous version from production
   sf project retrieve start --metadata ApexClass:TRM_MedicalBillingService,ApexClass:TRM_MedicalBillingServiceTest,LightningComponentBundle:customBillLineItemGrid --target-org <PRODUCTION_ORG_ALIAS>

   # Deploy previous version
   sf project deploy start --source-dir force-app --target-org <PRODUCTION_ORG_ALIAS> --test-level RunLocalTests
   ```

   **Option B: Manual rollback via UI:**
   - Setup → Deployment Status
   - Find failed deployment
   - Click "Rollback" (if available)

4. **Post-rollback:**
   - Verify production is stable
   - Notify stakeholders
   - Update Jira ticket
   - Schedule post-mortem

**If deployment succeeds but issues found:**
- Proceed to Task 6.3 (smoke test)
- If smoke test fails, execute rollback

#### Dependencies

**Prerequisites:**
- ✅ Task 6.1 complete (validation passed)
- ✅ Explicit permission to deploy received
- ✅ Stakeholders notified

**Org Dependencies:**
- Production org accessible
- No other deployments in progress
- Production org is stable

**Blocks:**
- Task 6.3 (smoke test requires deployment)
- Task 6.4 (ticket closure requires deployment)

---

### Task 6.3: Production Smoke Test

**ID:** MVADM-188-T6.3
**Title:** Verify Fixes Work in Production Environment

#### Context
- **Requirements:** Satisfies production validation requirements
- **SDR Reference:** Step 6.3 (lines 1253-1300)
- **Purpose:** Confirm deployment was successful and bugs are fixed in production

#### Exact Changes

**No code changes** - This is a testing task

**Test Scope:**
- Production org
- Real production data
- Quick validation (15-20 minutes)

#### Implementation Instructions

**Step-by-Step:**

1. **Log into production org**

2. **Navigate to a low-risk test Bill:**
   - Use a test Bill if available
   - OR use a Bill that is not actively being worked on
   - Avoid Bills that are in critical workflows

3. **Test Scenario 1: Create draft line item**
   - Enter minimal data in draft row:
     - Service Start Date: Today's date
     - CPT: 99213
     - Charge: 1.00
   - Press Tab to save
   - **Verify:**
     - ✅ Line number assigned correctly
     - ✅ No errors in UI
   - Take screenshot

4. **Test Scenario 2: Duplicate existing line item**
   - Select the row just created
   - Click "Duplicate"
   - Enter count: 1
   - Click "Create Duplicates"
   - **Verify:**
     - ✅ No "undefined" appears
     - ✅ Service date copied correctly
     - ✅ CPT code copied correctly
     - ✅ Line number assigned correctly
   - Take screenshot

5. **Check for errors:**
   - Open browser console (F12)
   - Look for JavaScript errors (red)
   - Check Salesforce debug logs
   - Look for Apex errors

6. **Clean up test data:**
   - Delete the 2 test line items created
   - Verify deletion successful

7. **Document results:**
   - Add comment to Jira ticket with screenshots
   - Note any issues found

#### Validation

**PASS Criteria:**
- ✅ Draft line items receive correct line numbers
- ✅ Duplicated line items receive correct line numbers
- ✅ No "undefined" appears in UI
- ✅ All fields copied correctly
- ✅ No JavaScript errors
- ✅ No Apex errors

**Validation Method:**
- Manual testing in production
- Browser console inspection
- Debug log review

**What Counts as PASS:**
- Both test scenarios pass
- No errors in console or logs
- Bugs are fixed in production

**What Counts as FAIL:**
- Original bugs still present
- New errors introduced
- Any critical issues found

#### Rollback Plan

**If smoke test fails:**

1. **IMMEDIATE ACTION:**
   - Stop testing
   - Notify stakeholders immediately
   - Assess severity

2. **Decision tree:**

   **If original bugs still present:**
   - CRITICAL: Rollback immediately
   - Execute rollback from Task 6.2
   - Notify stakeholders
   - Schedule post-mortem

   **If new errors introduced:**
   - Assess severity:
     - Critical: Rollback immediately
     - High: Rollback within 1 hour
     - Medium: Create hotfix ticket
     - Low: Create bug ticket

3. **Rollback execution:**
   ```bash
   # Retrieve previous version
   sf project retrieve start --metadata ApexClass:TRM_MedicalBillingService,ApexClass:TRM_MedicalBillingServiceTest,LightningComponentBundle:customBillLineItemGrid --target-org <PRODUCTION_ORG_ALIAS>

   # Deploy previous version
   sf project deploy start --source-dir force-app --target-org <PRODUCTION_ORG_ALIAS> --test-level RunLocalTests
   ```

4. **Post-rollback:**
   - Verify production is stable
   - Notify stakeholders
   - Update Jira ticket
   - Root cause analysis

#### Dependencies

**Prerequisites:**
- ✅ Task 6.2 complete (deployed to production)
- ✅ Production org accessible

**Org Dependencies:**
- Production org is stable
- Test Bill available (or can create one)

**Blocks:**
- Task 6.4 (cannot close ticket without smoke test pass)

---

### Task 6.4: Close Ticket and Notify Stakeholders

**ID:** MVADM-188-T6.4
**Title:** Complete Ticket Closure and Stakeholder Notification

#### Context
- **Requirements:** Satisfies all requirements from `requirements_MVADM-188.md`
- **SDR Reference:** Implied in Phase 6 completion
- **Purpose:** Formally close ticket and notify stakeholders of completion

#### Exact Changes

**No code changes** - This is an administrative task

**Closure Scope:**
- Update Jira ticket
- Notify stakeholders
- Document lessons learned

#### Implementation Instructions

**Step-by-Step:**

1. **Update Jira ticket:**

   Add final comment:
   ```
   MVADM-188 - COMPLETE

   **Deployment Summary:**
   - Deployed to Production: [DATE/TIME]
   - Deployment Status: Success
   - Smoke Test: Passed

   **Bugs Fixed:**
   ✅ Bug #1: Duplicated Bill Line Items now receive sequential line numbers
   ✅ Bug #2: All fields (dates, codes) are copied correctly, no "undefined" values

   **Components Modified:**
   - TRM_MedicalBillingService.cls (Apex)
   - TRM_MedicalBillingServiceTest.cls (Apex Test)
   - customBillLineItemGrid.js (LWC)

   **Test Results:**
   - Sandbox Testing: Passed
   - UAT (Chris Caines): Approved
   - Production Smoke Test: Passed

   **Code Coverage:**
   - TRM_MedicalBillingService: XX%

   **Next Steps:**
   - Monitor production for 7 days
   - Address any user feedback
   - Close ticket

   **Lessons Learned:**
   [Add any lessons learned during implementation]
   ```

2. **Move ticket to "Done" status:**
   - Click "Transition" → "Done"
   - Add resolution: "Fixed"

3. **Notify stakeholders:**

   Send email:
   ```
   Subject: MVADM-188 Complete - Bill Line Item Duplication Bugs Fixed

   Hi Team,

   I'm happy to report that MVADM-188 has been successfully deployed to production.

   **What was fixed:**
   1. Duplicated Bill Line Items now receive sequential line numbers (no more blank Line #)
   2. All fields are copied correctly when duplicating (no more "undefined" in dates and codes)

   **Deployment Details:**
   - Deployed: [DATE/TIME]
   - UAT Approval: Chris Caines
   - Production Smoke Test: Passed

   **User Impact:**
   - Users can now duplicate Bill Line Items without seeing "undefined" values
   - All duplicated rows will have proper sequential line numbers
   - No changes to existing workflows

   **Monitoring:**
   - I'll monitor production for the next 7 days
   - Please report any issues to me immediately

   **Questions:**
   - If you have any questions or concerns, please let me know

   Thanks to Chris Caines for thorough UAT testing!

   [Your Name]
   ```

4. **Document in SDR:**
   - Update SDR with actual results vs. estimates
   - Note any deviations from plan
   - Save for future reference

5. **Clean up:**
   - Merge deployment branch to main:
     ```bash
     git checkout main
     git merge deploy/MVADM-188-production
     git push origin main
     ```
   - Delete feature branches (optional):
     ```bash
     git branch -d fix/MVADM-188-bill-line-item-bugs
     git branch -d deploy/MVADM-188-production
     ```

#### Validation

**PASS Criteria:**
- ✅ Jira ticket status: "Done"
- ✅ Final comment added to ticket
- ✅ Stakeholders notified via email
- ✅ Code merged to main branch

**Validation Method:**
- Manual verification

**What Counts as PASS:**
- Ticket is closed
- Email sent
- No outstanding tasks

#### Rollback Plan

**No rollback needed** - This is an administrative task

**If issues arise after closure:**
- Reopen ticket
- Create new ticket for follow-up work
- Address issues as needed

#### Dependencies

**Prerequisites:**
- ✅ Task 6.3 complete (smoke test passed)
- ✅ No critical issues found in production

**Org Dependencies:**
- None

**Blocks:**
- None (this is the final task)

---

## SUMMARY AND EXECUTION NOTES

### Task Sequence Overview

**Total Tasks:** 14 (excluding Phase 1 which is complete)

**Estimated Timeline:**
- Phase 2 (Apex): 1 hour
- Phase 3 (LWC): 1.5 hours
- Phase 4 (Testing): 3 hours
- Phase 5 (UAT): 2-3 hours (+ waiting time)
- Phase 6 (Production): 2 hours
- **Total Active Development:** 9.5-10.5 hours (1.5 days)

### Critical Human Review Points 🔴

The following tasks require explicit human approval before execution:

1. **Task 5.2** - Conduct UAT with Chris Caines
   - **Why:** Stakeholder validation required
   - **Action:** Schedule meeting, conduct testing, obtain feedback

2. **Task 5.3** - Obtain UAT Sign-Off
   - **Why:** Formal approval required before production deployment
   - **Action:** Wait for written approval in Jira

3. **Task 6.2** - Deploy to Production
   - **Why:** Production deployment is irreversible and high-risk
   - **Action:** Confirm all prerequisites, obtain explicit permission, notify stakeholders

### Parallelizable Tasks

The following tasks can be executed in parallel to save time:

- **Tasks 2.1, 2.2, 2.3** (Apex) can run parallel to **Tasks 3.1, 3.2** (LWC)
- **Task 4.1** (Apex Tests) can run parallel to **Task 3.4** (LWC Validation)

### High-Risk Tasks Requiring Extra Attention

1. **Task 2.1** - Modify Apex Class
   - **Risk:** Incorrect line number calculation could cause data integrity issues
   - **Mitigation:** Carefully review code changes, test thoroughly

2. **Task 3.2** - Fix Field Mapping
   - **Risk:** Missing field mappings could cause "undefined" to persist
   - **Mitigation:** Compare with processLineItems pattern, verify all fields

3. **Task 6.2** - Deploy to Production
   - **Risk:** Production deployment failure could impact users
   - **Mitigation:** Validate first, use quick deployment, have rollback plan ready

### Recommended Execution Strategy

**Option 1: Sequential (Safest)**
- Execute tasks in exact order
- Validate each task before proceeding
- Estimated time: 10-12 hours

**Option 2: Parallel (Faster)**
- Execute Apex and LWC changes in parallel
- Merge at Phase 4 (Testing)
- Estimated time: 8-10 hours

**Option 3: Phased (Recommended)**
- Phase 2 & 3 together (2.5 hours)
- Phase 4 (3 hours)
- Phase 5 (schedule UAT, wait for approval)
- Phase 6 (2 hours after approval)
- Estimated time: 7.5 hours active + waiting time

### Success Metrics

**Technical Success:**
- ✅ All tests pass
- ✅ Code coverage ≥75%
- ✅ No "undefined" in UI
- ✅ Sequential line numbers assigned

**Business Success:**
- ✅ UAT approval from Chris Caines
- ✅ Production deployment successful
- ✅ No rollbacks required
- ✅ No user-reported issues in first 7 days

### Emergency Contacts

If issues arise during execution:
- **Stakeholder:** Chris Caines (UAT approval, business questions)
- **Technical Lead:** [Name] (code review, architecture questions)
- **Salesforce Admin:** [Name] (org access, permissions)
- **Manager:** [Name] (escalation, approval)

---

**END OF TASK LIST**

**Document Status:** ✅ READY FOR EXECUTION
**Generated:** 2026-01-05
**Version:** 1.0
**Based on:** SDR_MVADM-188.md v1.1, requirements_MVADM-188.md v1.0


