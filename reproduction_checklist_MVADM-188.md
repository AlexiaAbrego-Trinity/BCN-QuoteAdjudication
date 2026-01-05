# MVADM-188 - Bug Reproduction Checklist

**Purpose:** Use this checklist when Chris Caines provides clarification to systematically reproduce and fix the bugs.

**Date Created:** 2026-01-05  
**Last Updated:** 2026-01-05  

---

## Phase 1: Receive and Validate Clarification

### ✅ Checklist: Information Received from Chris

- [ ] **Q1: Exact reproduction steps for cloning bug**
  - [ ] Which specific fields show "undefined"?
  - [ ] When does "undefined" appear (immediately, after refresh, after save)?
  - [ ] Does it happen with all rows or specific data patterns?
  - [ ] Specific BCN number and line item number provided
  - [ ] Screenshot attached showing "undefined" values

- [ ] **Q2: Exact symptom of auto-numbering bug**
  - [ ] Symptom identified: Blank / Duplicate / Out of Sequence / Other
  - [ ] Happens when: New draft / Duplication / Both
  - [ ] Specific BCN number provided
  - [ ] Example of incorrect line numbers provided

- [ ] **Q3: Test data for reproduction**
  - [ ] Specific BCN number(s) provided
  - [ ] Specific Bill Line Item numbers provided
  - [ ] Environment identified (sandbox/production)
  - [ ] Approximate date/time of occurrence provided
  - [ ] Data characteristics described (fully populated vs. partial)

### ✅ Validation: Information is Sufficient

- [ ] I can access the provided BCN number in the sandbox
- [ ] I can see the Bill Line Items mentioned
- [ ] I understand the exact steps to reproduce
- [ ] I have all necessary permissions to test in the environment
- [ ] Debug logs are enabled for my user

---

## Phase 2: Reproduce Bug #1 (Cloning Shows "undefined")

### ✅ Setup

- [ ] Log into medivest-eobbcnb sandbox (or specified environment)
- [ ] Navigate to the Bill record: BCN = `_______________` (from Chris)
- [ ] Open Bill Line Items grid
- [ ] Enable browser Developer Console (F12)
- [ ] Enable Salesforce Debug Logs for my user

### ✅ Reproduction Steps (Based on Chris's Response)

**Step 1: Identify Original Row**
- [ ] Locate Bill Line Item # `_______________` (from Chris)
- [ ] Verify it has the data characteristics Chris described
- [ ] Take screenshot of original row (BEFORE duplication)

**Step 2: Perform Duplication**
- [ ] Select the row by clicking checkbox
- [ ] Set duplicate count to: `_______________` (from Chris, or default to 1)
- [ ] Click "Create Duplicates" button
- [ ] Observe UI immediately (before any refresh)

**Step 3: Observe Results**
- [ ] Check if "undefined" appears in any column
- [ ] Document which columns show "undefined": `_______________`
- [ ] Take screenshot of duplicated row (AFTER duplication)
- [ ] Check browser console for JavaScript errors
- [ ] Check Salesforce debug logs for Apex errors

**Step 4: Additional Tests**
- [ ] Refresh the page (Ctrl+R)
- [ ] Check if "undefined" still appears or changes
- [ ] Try duplicating a different row (one with all fields populated)
- [ ] Check if "undefined" appears for that row too

### ✅ Data Collection

- [ ] Screenshot: Original row before duplication
- [ ] Screenshot: Duplicated row showing "undefined"
- [ ] Browser console log (copy/paste errors)
- [ ] Salesforce debug log (download and save)
- [ ] Record exact fields showing "undefined": `_______________`

### ✅ Root Cause Confirmation

**Hypothesis 1: Null Code Relationship**
- [ ] Check if original row has Code__c populated: Yes / No
- [ ] If No, this confirms hypothesis (null Code__r causes "undefined")
- [ ] If Yes, hypothesis is wrong - investigate further

**Hypothesis 2: Date Formatting Issue**
- [ ] Check if original row has Service_Start_Date__c populated: Yes / No
- [ ] Check if original row has Service_End_Date__c populated: Yes / No
- [ ] If dates are null and showing "undefined", confirms hypothesis

**Hypothesis 3: JavaScript Error**
- [ ] Check browser console for errors during duplication
- [ ] Look for: `Cannot read property 'Description__c' of null`
- [ ] If found, confirms null safety issue

### ✅ Document Findings

```
BUG #1 REPRODUCTION RESULTS:

BCN Number: _______________
Original Line Item #: _______________
Duplicate Line Item #: _______________

Fields showing "undefined":
- [ ] Service Start Date
- [ ] Service End Date
- [ ] Service Code (Code__c)
- [ ] Code Description
- [ ] Other: _______________

Original row data:
- Code__c: _______________
- Service_Start_Date__c: _______________
- Service_End_Date__c: _______________

Confirmed Root Cause:
- [ ] Null Code__r relationship (Code__c is null)
- [ ] Null date fields
- [ ] JavaScript error in console
- [ ] Other: _______________

Debug Log Errors:
_______________

Browser Console Errors:
_______________
```

---

## Phase 3: Reproduce Bug #2 (Line Numbering)

### ✅ Setup

- [ ] Same sandbox environment as Bug #1
- [ ] Navigate to same Bill record or different one (based on Chris's info)
- [ ] Open Bill Line Items grid
- [ ] Note existing line numbers: `_______________`

### ✅ Reproduction Steps (Based on Chris's Response)

**Scenario A: Duplicating Existing Row**
- [ ] Select an existing row (e.g., Line #3)
- [ ] Set duplicate count to 1
- [ ] Click "Create Duplicates"
- [ ] Observe the line number of the duplicate

**Scenario B: Saving New Draft Row**
- [ ] Enter data in the draft row (top row)
- [ ] Click "Save" or equivalent action
- [ ] Observe the line number assigned to the new row

### ✅ Observe Results

**Check for Symptom A: Blank Line Number**
- [ ] Duplicate row has NO line number (column is empty)
- [ ] If YES, confirms hypothesis (no auto-assignment)

**Check for Symptom B: Duplicate Line Number**
- [ ] Duplicate row has SAME line number as another row
- [ ] If YES, indicates race condition or logic error
- [ ] Document which rows have duplicate numbers: `_______________`

**Check for Symptom C: Out of Sequence**
- [ ] Duplicate row has a line number, but it's not sequential
- [ ] Example: Existing rows are 1, 2, 3, 4, 5 → duplicate shows 8
- [ ] If YES, indicates calculation error

### ✅ Data Collection

- [ ] Screenshot: Grid BEFORE duplication (showing existing line numbers)
- [ ] Screenshot: Grid AFTER duplication (showing duplicate's line number)
- [ ] Query database directly to verify line numbers:
  ```sql
  SELECT Id, Bill_Line_Item_Number__c, CreatedDate
  FROM Bill_Line_Item__c
  WHERE Bill__c = 'a0X...' -- BCN ID
  ORDER BY Bill_Line_Item_Number__c ASC NULLS LAST
  ```
- [ ] Copy query results: `_______________`

### ✅ Root Cause Confirmation

**Hypothesis 1: No Auto-Assignment**
- [ ] Check if duplicates have NULL in Bill_Line_Item_Number__c field
- [ ] Query: `SELECT Bill_Line_Item_Number__c FROM Bill_Line_Item__c WHERE Id = '...'`
- [ ] If NULL, confirms hypothesis (line 755 in Apex sets it to null)

**Hypothesis 2: Race Condition**
- [ ] Try duplicating two rows simultaneously (if possible)
- [ ] Check if both get the same line number
- [ ] If YES, confirms race condition

**Hypothesis 3: Display Issue**
- [ ] Check if line number exists in database but not displayed in UI
- [ ] Compare database query results with UI display
- [ ] If different, indicates UI binding issue

### ✅ Document Findings

```
BUG #2 REPRODUCTION RESULTS:

BCN Number: _______________
Existing Line Numbers: _______________
Action Performed: Duplicated Line # _____ / Saved new draft

Result:
- [ ] Duplicate has NO line number (blank)
- [ ] Duplicate has DUPLICATE line number: _____
- [ ] Duplicate has OUT OF SEQUENCE line number: _____

Database Query Results:
_______________

Confirmed Root Cause:
- [ ] Bill_Line_Item_Number__c is NULL in database
- [ ] Bill_Line_Item_Number__c has value but not displayed
- [ ] Race condition (multiple rows with same number)
- [ ] Other: _______________

Debug Log Errors:
_______________
```

---

## Phase 4: Validate Proposed Solution

### ✅ Before Implementing Fix

- [ ] Both bugs reproduced successfully
- [ ] Root causes confirmed via debug logs and database queries
- [ ] Proposed solution addresses confirmed root causes
- [ ] No alternative explanations for the bugs

### ✅ Solution Validation

**For Bug #1 (undefined values):**
- [ ] Confirmed that adding optional chaining (`?.`) will fix the issue
- [ ] Identified all fields that need the fix
- [ ] No other code paths that could cause "undefined"

**For Bug #2 (line numbering):**
- [ ] Confirmed that adding line number assignment logic will fix the issue
- [ ] Decided on approach: Sequential assignment with FOR UPDATE locking
- [ ] No triggers or flows that could interfere

### ✅ Edge Cases to Test

- [ ] Duplicate row with ALL fields null
- [ ] Duplicate row with ALL fields populated
- [ ] Duplicate row with ONLY dates null
- [ ] Duplicate row with ONLY Code__c null
- [ ] Duplicate 100 rows at once (max limit)
- [ ] Duplicate from a Bill with 0 existing line items
- [ ] Duplicate from a Bill with 100+ existing line items

---

## Phase 5: Implement and Test Fix

### ✅ Implementation

- [ ] Create feature branch: `fix/MVADM-188-bill-line-item-duplication-bugs`
- [ ] Implement Fix #1: Add optional chaining to JavaScript (lines 2383-2385)
- [ ] Implement Fix #2: Add line number assignment to Apex (lines 730-781)
- [ ] Implement Fix #3: Add safe date formatting helper
- [ ] Code review: Self-review changes before committing
- [ ] Commit with descriptive message

### ✅ Unit Testing

- [ ] Write test: `testDuplicateBillLineItems_AssignsSequentialLineNumbers`
- [ ] Write test: `testDuplicateBillLineItems_HandlesNullCodeRelationship`
- [ ] Write test: `testCreateBillLineItem_ConcurrentSaves_NoRaceCondition`
- [ ] Write test: `testDuplicateBillLineItems_HandlesNullDates`
- [ ] Run all tests: `sfdx force:apex:test:run --testlevel RunLocalTests`
- [ ] Verify 100% coverage of changed code
- [ ] All tests pass

### ✅ Integration Testing in Sandbox

- [ ] Deploy to medivest-eobbcnb sandbox
- [ ] Repeat Bug #1 reproduction steps
- [ ] Verify "undefined" no longer appears
- [ ] Repeat Bug #2 reproduction steps
- [ ] Verify line numbers are assigned correctly
- [ ] Test all edge cases from Phase 4
- [ ] No regressions in existing functionality

### ✅ UAT with Chris Caines

- [ ] Send email to Chris: "Fix is ready for UAT in sandbox"
- [ ] Provide testing instructions
- [ ] Schedule screen share session (optional)
- [ ] Chris confirms Bug #1 is fixed
- [ ] Chris confirms Bug #2 is fixed
- [ ] Chris approves for production deployment

---

## Phase 6: Production Deployment

### ✅ Pre-Deployment

- [ ] All tests passing in sandbox
- [ ] UAT approved by Chris Caines
- [ ] Code review completed
- [ ] Deployment plan documented
- [ ] Rollback plan documented
- [ ] Stakeholders notified of deployment window

### ✅ Deployment

- [ ] Create deployment package
- [ ] Deploy to production during approved window
- [ ] Run smoke tests in production
- [ ] Verify fix works in production
- [ ] Monitor debug logs for 1 hour post-deployment

### ✅ Post-Deployment

- [ ] No errors in debug logs
- [ ] No user reports of issues
- [ ] Update MVADM-188 ticket with resolution notes
- [ ] Close ticket
- [ ] Document lessons learned

---

## Appendix: Quick Reference

### Sandbox Access
- **URL:** https://medivest-eobbcnb.sandbox.my.salesforce.com
- **Username:** `_______________`
- **Debug Log Level:** FINEST for Apex, JavaScript

### Key Files to Monitor
- **Apex:** `force-app/main/default/classes/TRM_MedicalBillingService.cls`
- **LWC JS:** `force-app/main/default/lwc/customBillLineItemGrid/customBillLineItemGrid.js`
- **LWC HTML:** `force-app/main/default/lwc/customBillLineItemGrid/customBillLineItemGrid.html`

### Useful SOQL Queries
```sql
-- Get all line items for a Bill
SELECT Id, Bill_Line_Item_Number__c, Code__c, Code__r.Name, 
       Service_Start_Date__c, Service_End_Date__c
FROM Bill_Line_Item__c
WHERE Bill__c = 'a0X...'
ORDER BY Bill_Line_Item_Number__c ASC NULLS LAST

-- Find line items with NULL line numbers
SELECT Id, Bill__c, Bill_Line_Item_Number__c
FROM Bill_Line_Item__c
WHERE Bill__c = 'a0X...' AND Bill_Line_Item_Number__c = NULL

-- Find duplicate line numbers
SELECT Bill__c, Bill_Line_Item_Number__c, COUNT(Id)
FROM Bill_Line_Item__c
WHERE Bill__c = 'a0X...'
GROUP BY Bill__c, Bill_Line_Item_Number__c
HAVING COUNT(Id) > 1
```

---

**Status:** Ready to use once Chris Caines provides clarification  
**Owner:** [Your Name]  
**Last Updated:** 2026-01-05

