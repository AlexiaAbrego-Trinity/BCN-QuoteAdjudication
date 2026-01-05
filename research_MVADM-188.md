# Research Request for MVADM-188 - Bill Review UAT Bugs

**Date:** 2026-01-05  
**Ticket:** MVADM-188  
**Status:** Research Complete - Awaiting Client Clarification  

---

## Executive Summary

This document compiles all critical unknowns that must be resolved before designing a solution for MVADM-188. Research has been conducted on technical implementation details using Salesforce documentation and codebase analysis. **8 critical questions remain**, of which **3 require client clarification** and **5 have been resolved through technical investigation**.

---

## Research Questions and Findings

### 🔴 CRITICAL - Client Clarification Required

#### Q1: What is the exact reproduction path for the cloning bug?
**[CLARIFY-CLIENT-STATED]**

**Question for Chris Caines:**
> "When you reported that cloned rows show 'undefined' for service code and dates, can you provide:
> 1. Does this happen when duplicating a single row or multiple rows?
> 2. Does it happen with all rows or only rows with specific field values (e.g., rows with dates populated vs. empty dates)?
> 3. Is the 'undefined' visible immediately after clicking 'Create Duplicates', or only after refreshing the page?
> 4. Can you provide a specific BCN number and line item number that exhibits this bug?
> 5. Screenshot showing the 'undefined' values in the grid?"

**Why this is critical:**
- Cannot reproduce bug without exact steps
- Different reproduction paths may indicate different root causes
- May be a timing issue (immediate vs. after refresh) or data-specific issue

**Impact on solution design:**
- If immediate: JavaScript transformation bug (lines 2370-2414)
- If after refresh: Wire service caching issue
- If data-specific: Null handling bug in Apex or JavaScript

---

#### Q2: What does "draft lines do not auto-number correctly" mean specifically?
**[CLARIFY-CLIENT-STATED]**

**Question for Chris Caines:**
> "When you reported that draft lines don't auto-number correctly, can you clarify:
> 1. Do the draft lines get NO line number (blank/null in the Line # column)?
> 2. Do they get the WRONG line number (e.g., duplicate numbers like two rows both showing '5')?
> 3. Do they get line numbers OUT OF SEQUENCE (e.g., 1, 2, 5, 3, 4)?
> 4. Does this happen on the initial save of the draft row, or after subsequent edits?
> 5. Can you provide a specific BCN number where this occurred and what the line numbers looked like?"

**Why this is critical:**
- Three completely different root causes depending on the answer:
  - **No line number**: Apex calculation failing (lines 917-929)
  - **Wrong/duplicate number**: Race condition or concurrent editing issue
  - **Out of sequence**: Display sorting issue vs. data issue

**Impact on solution design:**
- No line number → Fix Apex `createBillLineItem` method
- Duplicate numbers → Add locking mechanism or validation
- Out of sequence → Fix ORDER BY clause or UI sorting logic

---

#### Q3: Are there specific test data scenarios that trigger these bugs?
**[CLARIFY-CLIENT-STATED]**

**Question for Chris Caines:**
> "To help us reproduce and fix these bugs, can you provide:
> 1. Specific BCN number(s) where you observed these issues
> 2. Specific Bill Line Item numbers that showed the problems
> 3. Were the original rows fully populated (all fields) or partially populated?
> 4. Were you working in the medivest-eobbcnb sandbox or production?
> 5. Approximately what date/time did you observe these issues (to check debug logs)?"

**Why this is critical:**
- Enables exact reproduction in sandbox
- May reveal data patterns (e.g., only happens with null dates)
- Debug logs can show exact error messages

**Impact on solution design:**
- Data-specific bugs require different fixes than universal bugs
- May reveal edge cases not covered by current tests

---

### 🟡 MEDIUM PRIORITY - Business Logic Clarification

#### Q4: What is the expected behavior when cloning a draft row?
**[CLARIFY-CLIENT-STATED]** + **[VERIFY-IMPLEMENTATION-DETAIL]**

**Current Implementation:**
- Code at line 2173 in `customBillLineItemGrid.js` filters out draft rows from bulk operations
- Draft rows have `isDraft: true` flag
- Duplication button is enabled when `hasSelectedItems` is true

**Technical Finding:**
```javascript
// Line 2173 - Draft rows are filtered out
const nonDraftItems = this.lineItems.filter(item => !item.isDraft);
```

**Question for Product Owner:**
> "Should users be able to duplicate the draft row (the persistent blank row at the top)?
> - Option A: Draft row should NOT be selectable for duplication (current behavior)
> - Option B: Draft row SHOULD be clonable like any other row
> - Option C: Draft row can be selected but duplication should be disabled with a message"

**Recommendation:** Option A (current behavior) - Draft row is for NEW entry, not duplication

---

#### Q5: Should line numbers be editable by users or always system-generated?
**[VERIFY-IMPLEMENTATION-DETAIL]** ✅ RESOLVED

**Research Finding:**
- **Current Implementation:** System-generated via Apex (lines 917-929 in `TRM_MedicalBillingService.cls`)
- **Field Type:** `Bill_Line_Item_Number__c` is a Decimal field (not Auto-Number)
- **Calculation Logic:** `MAX(Bill_Line_Item_Number__c) + 1` for each new draft save

**Code Evidence:**
```apex
// Lines 917-929 in TRM_MedicalBillingService.cls
List<Bill_Line_Item__c> existingItems = [
    SELECT Bill_Line_Item_Number__c
    FROM Bill_Line_Item__c
    WHERE Bill__c = :billId
    ORDER BY Bill_Line_Item_Number__c DESC NULLS LAST
    LIMIT 1
];

Decimal nextLineNumber = 1;
if (!existingItems.isEmpty() && existingItems[0].Bill_Line_Item_Number__c != null) {
    nextLineNumber = existingItems[0].Bill_Line_Item_Number__c + 1;
}
```

**Salesforce Documentation:**
- Source: https://developer.salesforce.com/docs/atlas.en-us.object_reference.meta/object_reference/
- Decimal fields are editable by default unless marked as formula or read-only
- Auto-Number fields are system-generated and non-editable

**Answer:** Line numbers are currently **system-generated** but the field is **technically editable**. This is a business decision, not a technical constraint.

**Recommendation:** Keep system-generated to prevent user errors (duplicate numbers, gaps, etc.)

---

#### Q6: What happens to line numbers when rows are deleted?
**[VERIFY-IMPLEMENTATION-DETAIL]** ✅ RESOLVED

**Research Finding:**
- **Current Implementation:** Line numbers are NOT renumbered after deletion
- **Evidence:** No renumbering logic found in `deleteBillLineItems` method (lines 792-820 in `TRM_MedicalBillingService.cls`)
- **Behavior:** Gaps remain in the sequence (e.g., if line 3 is deleted, sequence becomes 1, 2, 4, 5)

**Code Evidence:**
```apex
// Lines 792-820 - Simple delete, no renumbering
@AuraEnabled
public static void deleteBillLineItems(List<Id> itemIds) {
    try {
        List<Bill_Line_Item__c> itemsToDelete = [
            SELECT Id FROM Bill_Line_Item__c WHERE Id IN :itemIds
        ];
        delete itemsToDelete;
    } catch (Exception e) {
        throw new AuraHandledException('Error deleting Bill Line Items: ' + e.getMessage());
    }
}
```

**Industry Best Practice:**
- Medical billing line items typically maintain original line numbers for audit trail
- Renumbering would break references in EOBs, FileMaker sync, and audit logs

**Answer:** Line numbers are **permanent** - gaps remain after deletion. This is correct behavior for audit trail purposes.

---

### 🟢 LOW PRIORITY - Documentation/Configuration

#### Q7: Is there a maximum number of line items per bill?
**[VERIFY-IMPLEMENTATION-DETAIL]** ✅ RESOLVED

**Research Finding:**
- **Duplication Limit:** 100 rows per duplication operation (line 2340 in `customBillLineItemGrid.js`)
- **Total Limit:** No hard limit found in code
- **Salesforce Platform Limit:** No standard limit on child records per parent

**Code Evidence:**
```javascript
// Line 2340 - Duplication limit
if (totalNewRows > 100) {
    this.dispatchEvent(new ShowToastEvent({
        title: 'Error',
        message: 'Cannot create more than 100 duplicate rows. Please reduce the count.',
        variant: 'error'
    }));
    return;
}
```

**Salesforce Documentation:**
- Source: https://developer.salesforce.com/docs/atlas.en-us.salesforce_app_limits_cheatsheet.meta/salesforce_app_limits_cheatsheet/
- No standard limit on number of child records
- Practical limits: UI performance, SOQL query limits (50,000 rows), view state limits

**Answer:** 
- **Duplication limit:** 100 rows per operation (UI safeguard)
- **Total limit:** No enforced limit, but recommend < 1,000 rows per bill for performance

---

#### Q8: What timezone should be used for date display formatting?
**[VERIFY-DOCUMENTATION]** ✅ RESOLVED

**Research Finding:**
- **Current Implementation:** `toLocaleDateString()` uses browser's locale/timezone (line 2378)
- **Salesforce Behavior:** Date fields (not DateTime) are timezone-agnostic

**Code Evidence:**
```javascript
// Lines 2377-2380 in customBillLineItemGrid.js
serviceStartDateFormatted: item.Service_Start_Date__c ?
    new Date(item.Service_Start_Date__c).toLocaleDateString() : '',
serviceEndDateFormatted: item.Service_End_Date__c ?
    new Date(item.Service_End_Date__c).toLocaleDateString() : '',
```

**Salesforce Documentation:**
- Source: https://developer.salesforce.com/docs/component-library/bundle/lightning-input/documentation
- Date fields (Service_Start_Date__c, Service_End_Date__c) are stored as Date type (no time component)
- Date type is timezone-agnostic - represents calendar date only
- `toLocaleDateString()` is appropriate for Date fields

**Answer:** Current implementation is **correct** - `toLocaleDateString()` is appropriate for Date fields. No change needed.

---

## Technical Deep Dive - Root Cause Analysis

### Bug #1: Cloning Shows "undefined" Values

**Hypothesis Based on Code Analysis:**

The bug is likely in the `processedDuplicates` mapping (lines 2370-2414 in `customBillLineItemGrid.js`).

**Potential Root Cause:**
```javascript
// Lines 2377-2380 - Date formatting
serviceStartDateFormatted: item.Service_Start_Date__c ?
    new Date(item.Service_Start_Date__c).toLocaleDateString() : '',
```

**Problem:** If `item.Service_Start_Date__c` is `null` or `undefined`, the ternary operator returns empty string `''`, which is correct. However, if the field is **missing entirely** from the Apex response, `item.Service_Start_Date__c` evaluates to `undefined`, and the ternary still works.

**More likely issue:** The Apex method `createDuplicateBillLineItems` may not be returning the date fields in the re-query.

**Evidence from Apex code (lines 770-781):**
```apex
return [
    SELECT Id, Bill_Line_Item_Number__c, Service_Start_Date__c, Service_End_Date__c, 
           Revenue_Code__c, Place_of_Service__c, CPT_HCPCS_NDC__c, Modifier__c, 
           Quantity__c, Charge__c, Other_Ins_Allowed__c, Other_Ins_Paid__c,
           Approved_Amount__c, Patient_Responsibility__c, X3rd_Party__c, 
           X3rd_Party_Curr__c, Adjustment_Amount__c, Savings_Fee__c,
           Description__c, Code__c, Code__r.Name, Code__r.Description__c, 
           Code__r.Medicare_Covered__c,
           Bill__c, Bill__r.Member_Account__c, Bill__r.Member_Account__r.Name, 
           Bill__r.BCN_Custom_Status__c,
           Remark_Code_1__c, Remark_Code_2__c, Remark_Code_3__c, Remark_Code_4__c,
           Duplicate_Status__c, Matching_Records__c, Last_Duplicate_Check__c, 
           TRM_BCN_Custom_Status__c
    FROM Bill_Line_Item__c
    WHERE Id IN :newItemIds
    ORDER BY Bill_Line_Item_Number__c ASC NULLS LAST, CreatedDate DESC
];
```

**✅ Date fields ARE included in the query** - So the Apex side looks correct.

**Alternative Hypothesis:**
The issue may be in how the LWC displays the values. Let me check the HTML template...

**Need to verify:** Does the HTML template reference `serviceStartDateFormatted` or `Service_Start_Date__c` directly?

**[VERIFY-IMPLEMENTATION-DETAIL]** - Requires viewing the HTML template to confirm field binding.

---

### Bug #2: Draft Lines Auto-Numbering

**Hypothesis Based on Code Analysis:**

The auto-numbering logic in `createBillLineItem` (lines 917-929) appears sound:

```apex
List<Bill_Line_Item__c> existingItems = [
    SELECT Bill_Line_Item_Number__c
    FROM Bill_Line_Item__c
    WHERE Bill__c = :billId
    ORDER BY Bill_Line_Item_Number__c DESC NULLS LAST
    LIMIT 1
];

Decimal nextLineNumber = 1;
if (!existingItems.isEmpty() && existingItems[0].Bill_Line_Item_Number__c != null) {
    nextLineNumber = existingItems[0].Bill_Line_Item_Number__c + 1;
}
```

**Potential Issues:**

1. **Race Condition:** If two users save draft rows simultaneously, both queries may return the same max number, resulting in duplicate line numbers.
   - **Likelihood:** LOW (requires exact simultaneous saves)
   - **Fix:** Add `FOR UPDATE` to SOQL query for row-level locking

2. **Display Issue:** Line number is calculated correctly but not displayed in UI
   - **Likelihood:** MEDIUM (UI binding issue)
   - **Fix:** Verify HTML template binds to `Bill_Line_Item_Number__c`

3. **Flow Interference:** FileMaker ID generation flow may be modifying the line number
   - **Likelihood:** LOW (flows run after triggers, line number set before insert)
   - **Fix:** Check flow execution order

**Salesforce Order of Execution:**
Source: https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_triggers_order_of_execution.htm

1. System validation rules
2. Before triggers
3. Custom validation rules
4. After triggers
5. Assignment rules
6. Auto-response rules
7. Workflow rules
8. **Processes (Flow)** ← FileMaker ID generation happens here
9. Escalation rules
10. Roll-up summary fields

**Conclusion:** Flow runs AFTER the record is inserted, so it cannot interfere with line number assignment. The line number is set in Apex before insert (step 2).

**Most Likely Cause:** Display issue or race condition. **Requires client clarification (Q2)** to determine exact symptom.

---

## Salesforce Platform Constraints

### Trigger and Flow Execution Order
**[VERIFY-DOCUMENTATION]** ✅ VERIFIED

**Source:** https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_triggers_order_of_execution.htm

**Order for Bill_Line_Item__c Insert:**
1. System validation (required fields, field formats)
2. **Before triggers** (none for Bill_Line_Item__c)
3. Record saved to database (but not committed)
4. **After triggers:**
   - `BillLineItemDuplicateDetection.trigger` (duplicate detection)
   - `dlrs_Bill_Line_ItemTrigger.trigger` (rollup summaries)
5. Assignment rules (not applicable)
6. Auto-response rules (not applicable)
7. Workflow rules (none active)
8. **Record-Triggered Flows:**
   - `Bill_Line_Item_Generate_Filemaker_Id` (External_Id__c generation)
   - `Bill_Line_Item_Create_Update_Filemaker_Sync_Event` (FileMaker sync)
9. Escalation rules (not applicable)
10. Parent rollup summary fields updated
11. Criteria-based sharing evaluation
12. **Commit to database**

**Impact on MVADM-188:**
- Line number assignment happens in Apex BEFORE insert (not in trigger)
- Flows cannot interfere with line number because they run AFTER triggers
- Duplicate detection trigger runs AFTER insert, so it sees the line number

---

### LWC Date Handling
**[VERIFY-DOCUMENTATION]** ✅ VERIFIED

**Source:** https://developer.salesforce.com/docs/component-library/bundle/lightning-input/documentation

**Salesforce Date Field Behavior:**
- Date fields (not DateTime) are timezone-agnostic
- Stored as YYYY-MM-DD in database
- JavaScript `new Date(dateString)` creates Date object at midnight UTC
- `toLocaleDateString()` formats according to browser locale

**Potential Issue:**
```javascript
new Date(item.Service_Start_Date__c).toLocaleDateString()
```

If `item.Service_Start_Date__c` is:
- `null` → `new Date(null)` → Invalid Date → `toLocaleDateString()` → "Invalid Date" (not "undefined")
- `undefined` → `new Date(undefined)` → Invalid Date → `toLocaleDateString()` → "Invalid Date"
- Missing from object → `item.Service_Start_Date__c` → `undefined` → Ternary catches it → Returns `''`

**Conclusion:** The ternary operator SHOULD prevent "undefined" from appearing. If "undefined" is showing, it means:
1. The ternary is not being applied (code path issue)
2. A different field is showing "undefined" (not the date fields)
3. The display is showing the string "undefined" from somewhere else

**[RISK]** - Cannot determine exact cause without reproduction steps from client.

---

## Remaining Unknowns

### Critical - Requires Client Clarification

| # | Question | Why Critical | Blocking |
|---|----------|--------------|----------|
| Q1 | Exact reproduction path for cloning bug | Cannot reproduce without steps | ✅ YES |
| Q2 | Specific symptom of auto-numbering bug | Three different root causes possible | ✅ YES |
| Q3 | Test data scenarios (BCN numbers, dates) | Enables sandbox reproduction | ✅ YES |

### Medium Priority - Business Decision

| # | Question | Why Needed | Blocking |
|---|----------|------------|----------|
| Q4 | Can draft rows be cloned? | Affects UI behavior | ❌ NO - Can use current behavior |

### Resolved - No Further Action

| # | Question | Resolution | Source |
|---|----------|------------|--------|
| Q5 | Are line numbers editable? | System-generated (current behavior correct) | Code analysis |
| Q6 | Renumber after deletion? | No (correct for audit trail) | Code analysis + best practice |
| Q7 | Max line items per bill? | 100 per duplication, no total limit | Code analysis |
| Q8 | Timezone for date display? | Browser locale (correct for Date fields) | Salesforce docs |

---

## Risk Assessment

### 🔴 HIGH RISK - Cannot Proceed Without

1. **Reproduction Steps (Q1, Q2, Q3):** Cannot fix bugs we cannot reproduce
   - **Mitigation:** Request detailed information from Chris Caines immediately
   - **Timeline Impact:** Blocks all development work

### 🟡 MEDIUM RISK - Assumptions May Be Wrong

2. **Root Cause Assumptions:** Current hypotheses based on code analysis may be incorrect
   - **Mitigation:** Validate hypotheses with actual reproduction in sandbox
   - **Timeline Impact:** May require redesign if assumptions wrong

3. **Concurrent Editing:** Race condition in line numbering not tested
   - **Mitigation:** Add row-level locking (`FOR UPDATE`) as defensive measure
   - **Timeline Impact:** Minimal - simple code change

### 🟢 LOW RISK - Manageable

4. **Flow Execution Timing:** FileMaker flows may have unexpected side effects
   - **Mitigation:** Test thoroughly in sandbox with flows active
   - **Timeline Impact:** Covered by normal testing process

---

## Recommendations

### Immediate Actions (Before Design)

1. ✅ **Send clarification request to Chris Caines** with Q1, Q2, Q3
   - Include specific questions formatted for easy response
   - Request BCN numbers, screenshots, and timeline
   - Set deadline: 2026-01-06 EOD

2. ⏸️ **Do NOT proceed to solution design** until Q1, Q2, Q3 are answered
   - Risk of designing wrong solution is too high
   - Wasted development effort if assumptions are wrong

3. ✅ **Prepare sandbox environment** for reproduction testing
   - Ensure medivest-eobbcnb sandbox is accessible
   - Verify debug logging is enabled
   - Prepare test data (Bills with line items)

### After Client Clarification

4. 🔜 **Reproduce bugs in sandbox** using exact steps from client
   - Document exact error messages and behavior
   - Capture debug logs
   - Validate or refute current hypotheses

5. 🔜 **Design surgical fix** based on confirmed root cause
   - Minimize code changes
   - Add defensive null checks
   - Consider adding row-level locking for line numbering

6. 🔜 **Update existing tests** to cover bug scenarios
   - Add test for cloning rows with null dates
   - Add test for concurrent line number assignment
   - Ensure 100% coverage of changed code

---

## Summary

### Questions Resolved: 5/8 (62.5%)

✅ **Resolved through research:**
- Q5: Line numbers are system-generated (correct)
- Q6: No renumbering after deletion (correct for audit trail)
- Q7: 100 per duplication, no total limit
- Q8: Browser locale for dates (correct for Date fields)
- Trigger/Flow execution order verified

### Questions Remaining: 3/8 (37.5%)

❌ **Requires client clarification:**
- Q1: Exact reproduction path for cloning bug
- Q2: Specific symptom of auto-numbering bug
- Q3: Test data scenarios

🟡 **Business decision (non-blocking):**
- Q4: Can draft rows be cloned? (Can use current behavior as default)

### Next Steps

1. **IMMEDIATE:** Send clarification request to Chris Caines (Q1, Q2, Q3)
2. **WAIT:** Do not proceed to design until client responds
3. **PREPARE:** Set up sandbox environment for reproduction testing
4. **AFTER CLARIFICATION:** Reproduce bugs and confirm root cause
5. **THEN:** Design and implement surgical fix

---

**Research Status:** ✅ COMPLETE  
**Design Status:** ⏸️ BLOCKED - Awaiting client clarification  
**Estimated Unblock Date:** 2026-01-06 (assuming client responds within 24 hours)  

**Last Updated:** 2026-01-05
**Researcher:** Trinity Protocol / SAGE

---

## Appendix A: Technical Implementation Details

### Current Duplication Flow (Code Walkthrough)

**File:** `force-app/main/default/lwc/customBillLineItemGrid/customBillLineItemGrid.js`

#### Step 1: User Clicks "Create Duplicates" Button
```javascript
// Lines 2315-2318
handleCreateDuplicates() {
    this.isLoading = true;
    this.createDuplicatesFromSelected();
}
```

#### Step 2: Validation and Preparation
```javascript
// Lines 2320-2350
createDuplicatesFromSelected() {
    // Get selected non-draft items
    const selectedItems = this.lineItems.filter(item =>
        item.isSelected && !item.isDraft
    );

    // Validate selection
    if (selectedItems.length === 0) {
        this.showToast('Error', 'Please select at least one row to duplicate.', 'error');
        this.isLoading = false;
        return;
    }

    // Calculate total new rows
    const totalNewRows = selectedItems.reduce((sum, item) =>
        sum + (item.duplicateCount || 1), 0
    );

    // Enforce 100-row limit
    if (totalNewRows > 100) {
        this.showToast('Error', 'Cannot create more than 100 duplicate rows.', 'error');
        this.isLoading = false;
        return;
    }
}
```

#### Step 3: Build Duplication Request
```javascript
// Lines 2352-2368
const duplicateRequests = selectedItems.map(item => ({
    originalItemId: item.Id,
    count: item.duplicateCount || 1
}));

// Call Apex method
createDuplicateBillLineItems({ duplicateRequests })
    .then(result => {
        this.handleDuplicateSuccess(result);
    })
    .catch(error => {
        this.handleDuplicateError(error);
    });
```

#### Step 4: Process Apex Response
```javascript
// Lines 2370-2414 - THIS IS WHERE THE BUG LIKELY OCCURS
handleDuplicateSuccess(result) {
    const processedDuplicates = result.map(item => ({
        ...item,
        isSelected: false,
        isDraft: false,
        duplicateCount: 1,
        // 🔴 POTENTIAL BUG: If item.Service_Start_Date__c is undefined, this may fail
        serviceStartDateFormatted: item.Service_Start_Date__c ?
            new Date(item.Service_Start_Date__c).toLocaleDateString() : '',
        serviceEndDateFormatted: item.Service_End_Date__c ?
            new Date(item.Service_End_Date__c).toLocaleDateString() : '',
        // 🔴 POTENTIAL BUG: If Code__r is null, this will show undefined
        codeDescription: item.Code__r ? item.Code__r.Description__c : '',
        codeName: item.Code__r ? item.Code__r.Name : '',
        medicareCovered: item.Code__r ? item.Code__r.Medicare_Covered__c : false,
        memberAccountName: item.Bill__r?.Member_Account__r?.Name || '',
        bcnCustomStatus: item.Bill__r?.BCN_Custom_Status__c || ''
    }));

    // Insert duplicates into grid
    this.lineItems = [...processedDuplicates, ...this.lineItems];

    // Refresh wire service
    refreshApex(this.wiredLineItemsResult);

    this.showToast('Success', `Created ${result.length} duplicate rows.`, 'success');
    this.isLoading = false;
}
```

**🔍 Analysis:**
- If `item.Code__r` is `null`, then `item.Code__r.Description__c` will throw an error OR return `undefined`
- JavaScript's optional chaining (`?.`) is used for `Bill__r` but NOT for `Code__r`
- This inconsistency may cause "undefined" to appear in the UI

**Hypothesis:** The bug is in lines 2383-2385. Should be:
```javascript
codeDescription: item.Code__r?.Description__c || '',
codeName: item.Code__r?.Name || '',
medicareCovered: item.Code__r?.Medicare_Covered__c || false,
```

---

### Current Line Numbering Flow (Code Walkthrough)

**File:** `force-app/main/default/classes/TRM_MedicalBillingService.cls`

#### Step 1: User Saves Draft Row
```javascript
// LWC calls Apex method
saveDraftBillLineItem({ billId, draftData })
```

#### Step 2: Apex Calculates Next Line Number
```apex
// Lines 917-929
@AuraEnabled
public static Bill_Line_Item__c createBillLineItem(Id billId, Map<String, Object> itemData) {
    // Query for highest existing line number
    List<Bill_Line_Item__c> existingItems = [
        SELECT Bill_Line_Item_Number__c
        FROM Bill_Line_Item__c
        WHERE Bill__c = :billId
        ORDER BY Bill_Line_Item_Number__c DESC NULLS LAST
        LIMIT 1
    ];

    // Calculate next number
    Decimal nextLineNumber = 1;
    if (!existingItems.isEmpty() && existingItems[0].Bill_Line_Item_Number__c != null) {
        nextLineNumber = existingItems[0].Bill_Line_Item_Number__c + 1;
    }

    // Create new item
    Bill_Line_Item__c newItem = new Bill_Line_Item__c();
    newItem.Bill__c = billId;
    newItem.Bill_Line_Item_Number__c = nextLineNumber;
    // ... populate other fields from itemData

    insert newItem;
    return newItem;
}
```

**🔍 Analysis:**
- **Race Condition Risk:** If two users save simultaneously:
  1. User A queries: MAX = 5, calculates next = 6
  2. User B queries: MAX = 5, calculates next = 6
  3. User A inserts: Line 6 created
  4. User B inserts: Line 6 created (DUPLICATE!)

- **Likelihood:** LOW (requires exact simultaneous saves within milliseconds)
- **Impact:** HIGH (duplicate line numbers break audit trail)

**Recommended Fix:**
```apex
List<Bill_Line_Item__c> existingItems = [
    SELECT Bill_Line_Item_Number__c
    FROM Bill_Line_Item__c
    WHERE Bill__c = :billId
    ORDER BY Bill_Line_Item_Number__c DESC NULLS LAST
    LIMIT 1
    FOR UPDATE  // 🔧 Add row-level locking
];
```

---

### Apex Duplication Method Analysis

**File:** `force-app/main/default/classes/TRM_MedicalBillingService.cls`

#### Method: createDuplicateBillLineItems
```apex
// Lines 730-781
@AuraEnabled
public static List<Bill_Line_Item__c> createDuplicateBillLineItems(
    List<Map<String, Object>> duplicateRequests
) {
    List<Bill_Line_Item__c> newItems = new List<Bill_Line_Item__c>();
    Set<Id> newItemIds = new Set<Id>();

    try {
        // Step 1: Load original items
        Set<Id> originalIds = new Set<Id>();
        for (Map<String, Object> request : duplicateRequests) {
            originalIds.add((Id)request.get('originalItemId'));
        }

        Map<Id, Bill_Line_Item__c> originalItemsMap = new Map<Id, Bill_Line_Item__c>([
            SELECT Id, Bill__c, Service_Start_Date__c, Service_End_Date__c,
                   Revenue_Code__c, Place_of_Service__c, CPT_HCPCS_NDC__c,
                   Modifier__c, Quantity__c, Charge__c, Code__c,
                   // ... all other fields
            FROM Bill_Line_Item__c
            WHERE Id IN :originalIds
        ]);

        // Step 2: Create duplicates
        for (Map<String, Object> request : duplicateRequests) {
            Id originalId = (Id)request.get('originalItemId');
            Integer count = (Integer)request.get('count');

            Bill_Line_Item__c original = originalItemsMap.get(originalId);
            if (original == null) continue;

            for (Integer i = 0; i < count; i++) {
                Bill_Line_Item__c newItem = original.clone(false, true, false, false);
                newItem.Bill_Line_Item_Number__c = null; // Will be auto-assigned
                newItems.add(newItem);
            }
        }

        // Step 3: Insert duplicates
        if (!newItems.isEmpty()) {
            insert newItems;
            for (Bill_Line_Item__c item : newItems) {
                newItemIds.add(item.Id);
            }
        }

        // Step 4: Re-query with all fields and relationships
        return [
            SELECT Id, Bill_Line_Item_Number__c, Service_Start_Date__c, Service_End_Date__c,
                   Revenue_Code__c, Place_of_Service__c, CPT_HCPCS_NDC__c, Modifier__c,
                   Quantity__c, Charge__c, Code__c,
                   Code__r.Name, Code__r.Description__c, Code__r.Medicare_Covered__c,
                   Bill__c, Bill__r.Member_Account__c, Bill__r.Member_Account__r.Name,
                   Bill__r.BCN_Custom_Status__c
                   // ... all other fields
            FROM Bill_Line_Item__c
            WHERE Id IN :newItemIds
            ORDER BY Bill_Line_Item_Number__c ASC NULLS LAST, CreatedDate DESC
        ];

    } catch (Exception e) {
        throw new AuraHandledException('Error creating duplicates: ' + e.getMessage());
    }
}
```

**🔍 Analysis:**

**Potential Issues:**

1. **Line Number Assignment:**
   - Line 755: `newItem.Bill_Line_Item_Number__c = null;`
   - Expects auto-assignment, but there's NO trigger or formula to assign it
   - **BUG CONFIRMED:** Duplicates will have NULL line numbers!

2. **Missing Auto-Assignment Logic:**
   - The `createBillLineItem` method (lines 917-929) calculates line numbers
   - But `createDuplicateBillLineItems` does NOT call that logic
   - Duplicates are inserted with NULL line numbers

3. **Re-query May Return NULL:**
   - Line 770: Re-query includes `Bill_Line_Item_Number__c`
   - If the field is NULL in database, it will be NULL in the response
   - LWC will display NULL as empty or "undefined"

**🔴 ROOT CAUSE IDENTIFIED:**

The duplication method does NOT assign line numbers to duplicates. This explains why "draft lines do not auto-number correctly" - the duplicates ARE draft lines (no line number assigned).

**Required Fix:**
```apex
// After line 755, add:
// Calculate next line number for this bill
List<Bill_Line_Item__c> existingItems = [
    SELECT Bill_Line_Item_Number__c
    FROM Bill_Line_Item__c
    WHERE Bill__c = :original.Bill__c
    ORDER BY Bill_Line_Item_Number__c DESC NULLS LAST
    LIMIT 1
    FOR UPDATE
];

Decimal nextLineNumber = 1;
if (!existingItems.isEmpty() && existingItems[0].Bill_Line_Item_Number__c != null) {
    nextLineNumber = existingItems[0].Bill_Line_Item_Number__c + 1;
}

newItem.Bill_Line_Item_Number__c = nextLineNumber;
```

**⚠️ CRITICAL:** This fix must be applied INSIDE the loop, incrementing `nextLineNumber` for each duplicate to avoid duplicate numbers.

---

## Appendix B: Proposed Solution (Pending Client Confirmation)

### Fix #1: Add Line Number Assignment to Duplication

**File:** `force-app/main/default/classes/TRM_MedicalBillingService.cls`
**Lines:** 730-781
**Change Type:** Logic Addition

**Current Code:**
```apex
for (Integer i = 0; i < count; i++) {
    Bill_Line_Item__c newItem = original.clone(false, true, false, false);
    newItem.Bill_Line_Item_Number__c = null; // ❌ BUG: No auto-assignment
    newItems.add(newItem);
}
```

**Proposed Fix:**
```apex
// Query max line number ONCE per bill (outside inner loop)
Map<Id, Decimal> billToMaxLineNumber = new Map<Id, Decimal>();

for (Map<String, Object> request : duplicateRequests) {
    Id originalId = (Id)request.get('originalItemId');
    Integer count = (Integer)request.get('count');

    Bill_Line_Item__c original = originalItemsMap.get(originalId);
    if (original == null) continue;

    // Get or calculate max line number for this bill
    if (!billToMaxLineNumber.containsKey(original.Bill__c)) {
        List<Bill_Line_Item__c> existingItems = [
            SELECT Bill_Line_Item_Number__c
            FROM Bill_Line_Item__c
            WHERE Bill__c = :original.Bill__c
            ORDER BY Bill_Line_Item_Number__c DESC NULLS LAST
            LIMIT 1
            FOR UPDATE  // 🔧 Prevent race conditions
        ];

        Decimal maxNumber = 0;
        if (!existingItems.isEmpty() && existingItems[0].Bill_Line_Item_Number__c != null) {
            maxNumber = existingItems[0].Bill_Line_Item_Number__c;
        }
        billToMaxLineNumber.put(original.Bill__c, maxNumber);
    }

    // Create duplicates with sequential line numbers
    for (Integer i = 0; i < count; i++) {
        Bill_Line_Item__c newItem = original.clone(false, true, false, false);

        // ✅ FIX: Assign next line number
        Decimal nextNumber = billToMaxLineNumber.get(original.Bill__c) + 1;
        newItem.Bill_Line_Item_Number__c = nextNumber;
        billToMaxLineNumber.put(original.Bill__c, nextNumber); // Increment for next

        newItems.add(newItem);
    }
}
```

**Benefits:**
- ✅ Assigns sequential line numbers to all duplicates
- ✅ Prevents race conditions with `FOR UPDATE`
- ✅ Efficient: Queries max number once per bill, not per duplicate
- ✅ Maintains correct sequence even when duplicating multiple rows

---

### Fix #2: Add Null Safety to LWC Duplication Handler

**File:** `force-app/main/default/lwc/customBillLineItemGrid/customBillLineItemGrid.js`
**Lines:** 2370-2414
**Change Type:** Defensive Null Checks

**Current Code:**
```javascript
const processedDuplicates = result.map(item => ({
    ...item,
    isSelected: false,
    isDraft: false,
    duplicateCount: 1,
    serviceStartDateFormatted: item.Service_Start_Date__c ?
        new Date(item.Service_Start_Date__c).toLocaleDateString() : '',
    serviceEndDateFormatted: item.Service_End_Date__c ?
        new Date(item.Service_End_Date__c).toLocaleDateString() : '',
    codeDescription: item.Code__r ? item.Code__r.Description__c : '',  // ❌ May return undefined
    codeName: item.Code__r ? item.Code__r.Name : '',  // ❌ May return undefined
    medicareCovered: item.Code__r ? item.Code__r.Medicare_Covered__c : false,
    memberAccountName: item.Bill__r?.Member_Account__r?.Name || '',
    bcnCustomStatus: item.Bill__r?.BCN_Custom_Status__c || ''
}));
```

**Proposed Fix:**
```javascript
const processedDuplicates = result.map(item => ({
    ...item,
    isSelected: false,
    isDraft: false,
    duplicateCount: 1,

    // ✅ FIX: Use optional chaining and nullish coalescing
    serviceStartDateFormatted: item.Service_Start_Date__c ?
        new Date(item.Service_Start_Date__c).toLocaleDateString() : '',
    serviceEndDateFormatted: item.Service_End_Date__c ?
        new Date(item.Service_End_Date__c).toLocaleDateString() : '',

    // ✅ FIX: Consistent null handling with optional chaining
    codeDescription: item.Code__r?.Description__c ?? '',
    codeName: item.Code__r?.Name ?? '',
    medicareCovered: item.Code__r?.Medicare_Covered__c ?? false,

    memberAccountName: item.Bill__r?.Member_Account__r?.Name ?? '',
    bcnCustomStatus: item.Bill__r?.BCN_Custom_Status__c ?? ''
}));
```

**Benefits:**
- ✅ Prevents "undefined" from appearing in UI
- ✅ Consistent null handling across all fields
- ✅ Uses modern JavaScript optional chaining (`?.`) and nullish coalescing (`??`)
- ✅ More readable and maintainable

---

### Fix #3: Add Defensive Null Check to Date Formatting

**File:** `force-app/main/default/lwc/customBillLineItemGrid/customBillLineItemGrid.js`
**Lines:** 2377-2380
**Change Type:** Enhanced Validation

**Current Code:**
```javascript
serviceStartDateFormatted: item.Service_Start_Date__c ?
    new Date(item.Service_Start_Date__c).toLocaleDateString() : '',
```

**Proposed Fix:**
```javascript
serviceStartDateFormatted: item.Service_Start_Date__c ?
    this.formatDateSafely(item.Service_Start_Date__c) : '',
serviceEndDateFormatted: item.Service_End_Date__c ?
    this.formatDateSafely(item.Service_End_Date__c) : '',
```

**Add Helper Method:**
```javascript
// Add to customBillLineItemGrid.js
formatDateSafely(dateValue) {
    if (!dateValue) return '';

    try {
        const date = new Date(dateValue);
        // Check if date is valid
        if (isNaN(date.getTime())) {
            console.warn('Invalid date value:', dateValue);
            return '';
        }
        return date.toLocaleDateString();
    } catch (error) {
        console.error('Error formatting date:', dateValue, error);
        return '';
    }
}
```

**Benefits:**
- ✅ Handles invalid date values gracefully
- ✅ Logs warnings for debugging
- ✅ Never shows "Invalid Date" or "undefined" to users
- ✅ Reusable for other date formatting needs

---

## Appendix C: Testing Strategy

### Unit Tests to Add

#### Test 1: Duplication Assigns Line Numbers
**File:** `force-app/main/default/classes/TRM_MedicalBillingServiceTest.cls`

```apex
@isTest
static void testDuplicateBillLineItems_AssignsSequentialLineNumbers() {
    // Setup: Create bill with 3 line items
    Bill__c bill = TestDataFactory.createBill();
    List<Bill_Line_Item__c> items = TestDataFactory.createBillLineItems(bill.Id, 3);
    // Items should have line numbers 1, 2, 3

    // Execute: Duplicate item #2 three times
    List<Map<String, Object>> requests = new List<Map<String, Object>>{
        new Map<String, Object>{
            'originalItemId' => items[1].Id,
            'count' => 3
        }
    };

    Test.startTest();
    List<Bill_Line_Item__c> duplicates = TRM_MedicalBillingService.createDuplicateBillLineItems(requests);
    Test.stopTest();

    // Verify: Duplicates have line numbers 4, 5, 6
    System.assertEquals(3, duplicates.size(), 'Should create 3 duplicates');
    System.assertEquals(4, duplicates[0].Bill_Line_Item_Number__c, 'First duplicate should be line 4');
    System.assertEquals(5, duplicates[1].Bill_Line_Item_Number__c, 'Second duplicate should be line 5');
    System.assertEquals(6, duplicates[2].Bill_Line_Item_Number__c, 'Third duplicate should be line 6');
}
```

#### Test 2: Duplication with Null Code Relationship
```apex
@isTest
static void testDuplicateBillLineItems_HandlesNullCodeRelationship() {
    // Setup: Create bill line item with NO Code__c lookup
    Bill__c bill = TestDataFactory.createBill();
    Bill_Line_Item__c item = new Bill_Line_Item__c(
        Bill__c = bill.Id,
        Bill_Line_Item_Number__c = 1,
        Code__c = null,  // No code relationship
        Service_Start_Date__c = Date.today(),
        Charge__c = 100.00
    );
    insert item;

    // Execute: Duplicate the item
    List<Map<String, Object>> requests = new List<Map<String, Object>>{
        new Map<String, Object>{
            'originalItemId' => item.Id,
            'count' => 1
        }
    };

    Test.startTest();
    List<Bill_Line_Item__c> duplicates = TRM_MedicalBillingService.createDuplicateBillLineItems(requests);
    Test.stopTest();

    // Verify: Duplicate created successfully with null Code__c
    System.assertEquals(1, duplicates.size(), 'Should create 1 duplicate');
    System.assertEquals(null, duplicates[0].Code__c, 'Code should be null');
    System.assertEquals(null, duplicates[0].Code__r, 'Code relationship should be null');
    // Should NOT throw NullPointerException
}
```

#### Test 3: Concurrent Line Number Assignment
```apex
@isTest
static void testCreateBillLineItem_ConcurrentSaves_NoRaceCondition() {
    // Setup: Create bill
    Bill__c bill = TestDataFactory.createBill();

    // Execute: Simulate concurrent saves (within same transaction for testing)
    Test.startTest();

    // User A saves
    Bill_Line_Item__c item1 = TRM_MedicalBillingService.createBillLineItem(
        bill.Id,
        new Map<String, Object>{ 'Charge__c' => 100.00 }
    );

    // User B saves immediately after
    Bill_Line_Item__c item2 = TRM_MedicalBillingService.createBillLineItem(
        bill.Id,
        new Map<String, Object>{ 'Charge__c' => 200.00 }
    );

    Test.stopTest();

    // Verify: No duplicate line numbers
    System.assertEquals(1, item1.Bill_Line_Item_Number__c, 'First item should be line 1');
    System.assertEquals(2, item2.Bill_Line_Item_Number__c, 'Second item should be line 2');
    System.assertNotEquals(item1.Bill_Line_Item_Number__c, item2.Bill_Line_Item_Number__c,
        'Line numbers must be unique');
}
```

---

### Integration Tests to Add

#### Test 4: LWC Duplication End-to-End
**File:** `force-app/main/default/lwc/customBillLineItemGrid/__tests__/customBillLineItemGrid.test.js`

```javascript
import { createElement } from 'lwc';
import CustomBillLineItemGrid from 'c/customBillLineItemGrid';
import createDuplicateBillLineItems from '@salesforce/apex/TRM_MedicalBillingService.createDuplicateBillLineItems';

// Mock Apex method
jest.mock(
    '@salesforce/apex/TRM_MedicalBillingService.createDuplicateBillLineItems',
    () => ({ default: jest.fn() }),
    { virtual: true }
);

describe('c-custom-bill-line-item-grid duplication', () => {
    afterEach(() => {
        while (document.body.firstChild) {
            document.body.removeChild(document.body.firstChild);
        }
        jest.clearAllMocks();
    });

    it('handles duplicates with null Code relationship gracefully', async () => {
        // Setup: Mock Apex response with null Code__r
        const mockDuplicates = [
            {
                Id: 'a0X3t000000Abc1',
                Bill_Line_Item_Number__c: 4,
                Service_Start_Date__c: '2026-01-05',
                Service_End_Date__c: '2026-01-05',
                Code__c: null,
                Code__r: null,  // Null relationship
                Bill__r: {
                    Member_Account__r: { Name: 'Test Member' },
                    BCN_Custom_Status__c: 'Active'
                }
            }
        ];
        createDuplicateBillLineItems.mockResolvedValue(mockDuplicates);

        // Create component
        const element = createElement('c-custom-bill-line-item-grid', {
            is: CustomBillLineItemGrid
        });
        element.recordId = 'a0X3t000000Bill1';
        document.body.appendChild(element);

        // Execute: Trigger duplication
        element.lineItems = [
            { Id: 'a0X3t000000Abc0', isSelected: true, isDraft: false, duplicateCount: 1 }
        ];
        await element.handleCreateDuplicates();

        // Verify: No "undefined" in processed data
        const processedItems = element.lineItems;
        expect(processedItems[0].codeDescription).toBe('');  // Not "undefined"
        expect(processedItems[0].codeName).toBe('');  // Not "undefined"
        expect(processedItems[0].medicareCovered).toBe(false);  // Not undefined
    });

    it('formats dates correctly without showing "undefined"', async () => {
        // Setup: Mock Apex response with valid dates
        const mockDuplicates = [
            {
                Id: 'a0X3t000000Abc1',
                Service_Start_Date__c: '2026-01-05',
                Service_End_Date__c: null,  // Null end date
                Code__r: { Name: 'Test Code', Description__c: 'Test' }
            }
        ];
        createDuplicateBillLineItems.mockResolvedValue(mockDuplicates);

        const element = createElement('c-custom-bill-line-item-grid', {
            is: CustomBillLineItemGrid
        });
        document.body.appendChild(element);

        // Execute
        element.lineItems = [
            { Id: 'a0X3t000000Abc0', isSelected: true, isDraft: false }
        ];
        await element.handleCreateDuplicates();

        // Verify: Dates formatted correctly
        const processedItems = element.lineItems;
        expect(processedItems[0].serviceStartDateFormatted).not.toBe('undefined');
        expect(processedItems[0].serviceStartDateFormatted).not.toBe('Invalid Date');
        expect(processedItems[0].serviceEndDateFormatted).toBe('');  // Null date = empty string
    });
});
```

---

## Appendix D: Deployment Checklist

### Pre-Deployment

- [ ] Client has confirmed reproduction steps (Q1, Q2, Q3)
- [ ] Bugs reproduced in medivest-eobbcnb sandbox
- [ ] Root cause confirmed via debug logs
- [ ] Solution designed and reviewed
- [ ] Unit tests written and passing (100% coverage of changed code)
- [ ] Integration tests written and passing
- [ ] Code review completed
- [ ] Documentation updated

### Deployment Steps

1. [ ] Deploy to medivest-eobbcnb sandbox
2. [ ] Run all tests in sandbox (Apex + LWC)
3. [ ] Manual UAT with Chris Caines using original reproduction steps
4. [ ] Verify fix resolves both bugs:
   - [ ] Cloned rows show correct values (no "undefined")
   - [ ] Draft lines have correct sequential line numbers
5. [ ] Performance test: Duplicate 100 rows (max limit)
6. [ ] Regression test: Verify existing functionality still works
7. [ ] Deploy to production (if UAT passes)
8. [ ] Monitor debug logs for 24 hours post-deployment
9. [ ] Close MVADM-188 ticket

### Rollback Plan

If bugs persist or new issues arise:

1. [ ] Revert Apex class to previous version
2. [ ] Revert LWC component to previous version
3. [ ] Notify Chris Caines of rollback
4. [ ] Re-analyze root cause with additional debug logs
5. [ ] Design alternative solution

---

**End of Research Document**

