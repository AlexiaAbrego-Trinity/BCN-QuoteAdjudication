# MVADM-188 Quick Execution Checklist

**Use this checklist to track progress through all tasks.**

---

## Pre-Execution Setup

- [ ] Git repository is clean (`git status`)
- [ ] Salesforce CLI authenticated to `medivest-eobbcnb`
- [ ] VS Code open with workspace loaded
- [ ] Jira ticket MVADM-188 accessible
- [ ] Phase 1 complete (client clarification received)

---

## PHASE 2: APEX IMPLEMENTATION (1 hour)

### Task 2.1: Modify Apex Class
- [ ] Create feature branch: `fix/MVADM-188-bill-line-item-bugs`
- [ ] Open `TRM_MedicalBillingService.cls` in VS Code
- [ ] Navigate to line 746
- [ ] Add `Map<Id, Decimal> billToMaxLineNumber = new Map<Id, Decimal>();`
- [ ] Add query for max line number with `FOR UPDATE`
- [ ] Add line number assignment logic
- [ ] Save file
- [ ] Validate syntax (no red squiggles)
- [ ] Commit changes with message
- [ ] **PASS:** Code compiles without errors

### Task 2.2: Deploy to Sandbox
- [ ] Verify no uncommitted changes
- [ ] Run: `sf project deploy start --source-dir force-app/main/default/classes/TRM_MedicalBillingService.cls --target-org medivest-eobbcnb --test-level NoTestRun`
- [ ] Wait for deployment completion
- [ ] Verify: Status = "Succeeded"
- [ ] **PASS:** Deployment successful

### Task 2.3: Validate with Anonymous Apex
- [ ] Log into medivest-eobbcnb sandbox
- [ ] Open Developer Console
- [ ] Execute Anonymous Apex test script (from task details)
- [ ] Review debug log
- [ ] Verify: "✅ TEST PASSED" in log
- [ ] Query database to verify line numbers
- [ ] **PASS:** All duplicates have sequential line numbers

---

## PHASE 3: LWC IMPLEMENTATION (1.5 hours)

### Task 3.1: Add formatDateSafely Helper
- [ ] Open `customBillLineItemGrid.js` in VS Code
- [ ] Navigate to line 2440 (after `confirmDuplication` method)
- [ ] Add `formatDateSafely()` method
- [ ] Save file
- [ ] Run ESLint: `npx eslint customBillLineItemGrid.js`
- [ ] Commit changes
- [ ] **PASS:** No ESLint errors

### Task 3.2: Fix Field Mapping
- [ ] Open `customBillLineItemGrid.js`
- [ ] Navigate to line 2371 (`processedDuplicates` mapping)
- [ ] Replace date formatting with `formatDateSafely()` calls
- [ ] Add missing field mappings: `revenueCode`, `posCode`, `cptCode`, `modifierCode`
- [ ] Add `*CodeDescription` fields
- [ ] Compare with `processLineItems` method (lines 821-831)
- [ ] Save file
- [ ] Run ESLint
- [ ] Verify all field mappings present
- [ ] Commit changes
- [ ] **PASS:** All fields mapped correctly

### Task 3.3: Deploy LWC to Sandbox
- [ ] Verify no uncommitted changes
- [ ] Run: `sf project deploy start --source-dir force-app/main/default/lwc/customBillLineItemGrid --target-org medivest-eobbcnb`
- [ ] Wait for deployment completion
- [ ] Verify: Status = "Succeeded"
- [ ] **PASS:** LWC deployed successfully

### Task 3.4: Validate UI Changes
- [ ] Log into medivest-eobbcnb sandbox
- [ ] Navigate to BCN Case 00375197
- [ ] Open browser Developer Console (F12)
- [ ] Test Scenario 1: Duplicate row with all fields populated
  - [ ] No "undefined" appears
  - [ ] Dates formatted correctly
  - [ ] Codes show values (not placeholders)
  - [ ] Line numbers sequential
- [ ] Test Scenario 2: Duplicate row with null dates
  - [ ] Date columns empty (not "undefined")
- [ ] Test Scenario 3: Duplicate row with null Code
  - [ ] No "undefined" appears
- [ ] Test Scenario 4: Duplicate multiple rows
  - [ ] All have sequential line numbers
- [ ] Check browser console for errors
- [ ] Take screenshots
- [ ] **PASS:** No "undefined" in UI, all scenarios pass

---

## PHASE 4: TESTING (3 hours)

### Task 4.1: Update Apex Tests
- [ ] Open `TRM_MedicalBillingServiceTest.cls`
- [ ] Add `testDuplicateBillLineItems_LineNumbering` method
- [ ] Add `testDuplicateBillLineItems_MultipleOriginals` method
- [ ] Adjust TestDataFactory calls if needed
- [ ] Save file
- [ ] Run tests: `sf apex run test --class-names TRM_MedicalBillingServiceTest --target-org medivest-eobbcnb --result-format human --code-coverage`
- [ ] Verify all tests pass
- [ ] Verify code coverage ≥75%
- [ ] Commit changes
- [ ] **PASS:** All tests pass, coverage ≥75%

### Task 4.2: End-to-End Integration Test
- [ ] Log into medivest-eobbcnb sandbox
- [ ] Enable debug logs (Setup → Debug Logs)
- [ ] Navigate to test Bill
- [ ] Test Step A: Create new draft line item
  - [ ] Line number assigned
  - [ ] Row moves to permanent
- [ ] Test Step B: Create another draft line item
  - [ ] Line number sequential
- [ ] Test Step C: Duplicate first line item
  - [ ] Two new rows with sequential line numbers
  - [ ] All fields copied correctly
  - [ ] No "undefined"
- [ ] Test Step D: Verify triggers and flows
  - [ ] Download debug logs
  - [ ] No errors in logs
- [ ] Test Step E: Verify data integrity
  - [ ] Query database
  - [ ] All line numbers unique and sequential
  - [ ] No null line numbers
- [ ] Document results in Jira
- [ ] **PASS:** All test steps pass, no errors

---

## PHASE 5: UAT (2-3 hours + waiting) 🔴 HUMAN REQUIRED

### Task 5.1: Prepare UAT Environment
- [ ] Create UAT test data (4 Bills with various configurations)
- [ ] Document test data in Jira ticket
- [ ] Verify Chris Caines has sandbox access
- [ ] Send UAT instructions email to Chris Caines
- [ ] **PASS:** Test data created, email sent

### Task 5.2: Conduct UAT 🔴 HUMAN
- [ ] Schedule UAT session with Chris Caines
- [ ] Conduct UAT session (60 minutes)
- [ ] Test original bug reproduction
- [ ] Test draft creation
- [ ] Test edge cases
- [ ] Free testing
- [ ] Take notes and screenshots
- [ ] Update Jira with results
- [ ] **PASS:** Chris confirms bugs are fixed

### Task 5.3: Obtain UAT Sign-Off 🔴 HUMAN
- [ ] Request formal approval in Jira ticket
- [ ] Wait for Chris Caines approval
- [ ] Update ticket status to "Ready for Deployment"
- [ ] **PASS:** Written approval received

---

## PHASE 6: PRODUCTION (2 hours) 🔴 REQUIRES EXPLICIT PERMISSION

### ⚠️ STOP - Confirm Permission Before Proceeding
- [ ] UAT sign-off received
- [ ] Validation passed
- [ ] Stakeholders notified
- [ ] Deployment window scheduled (if required)
- [ ] **EXPLICIT PERMISSION TO DEPLOY RECEIVED**

### Task 6.1: Create Deployment Package
- [ ] Create deployment branch: `deploy/MVADM-188-production`
- [ ] Merge feature branch
- [ ] Create `manifest/package.xml`
- [ ] Validate deployment: `sf project deploy validate --manifest manifest/package.xml --target-org <PRODUCTION> --test-level RunLocalTests --wait 30`
- [ ] Save validation ID
- [ ] Review validation results
- [ ] Commit deployment manifest
- [ ] **PASS:** Validation succeeded, tests passed, coverage ≥75%

### Task 6.2: Deploy to Production 🔴 HUMAN APPROVAL
- [ ] **CONFIRM PERMISSION AGAIN**
- [ ] Notify stakeholders (deployment starting)
- [ ] Deploy: `sf project deploy quick --job-id <VALIDATION_ID> --target-org <PRODUCTION>`
- [ ] Monitor deployment
- [ ] Verify deployment success
- [ ] Notify stakeholders (deployment complete)
- [ ] Update Jira ticket
- [ ] **PASS:** Deployment succeeded

### Task 6.3: Production Smoke Test
- [ ] Log into production org
- [ ] Navigate to low-risk test Bill
- [ ] Test Scenario 1: Create draft line item
  - [ ] Line number assigned
  - [ ] No errors
- [ ] Test Scenario 2: Duplicate line item
  - [ ] No "undefined"
  - [ ] Fields copied correctly
  - [ ] Line number assigned
- [ ] Check browser console and debug logs
- [ ] Clean up test data
- [ ] Document results in Jira
- [ ] **PASS:** Both scenarios pass, no errors

### Task 6.4: Close Ticket
- [ ] Add final comment to Jira ticket
- [ ] Move ticket to "Done" status
- [ ] Send completion email to stakeholders
- [ ] Merge deployment branch to main
- [ ] Delete feature branches (optional)
- [ ] **PASS:** Ticket closed, stakeholders notified

---

## COMPLETION CHECKLIST

- [ ] All 14 tasks completed
- [ ] All tests passing
- [ ] UAT approved
- [ ] Production deployment successful
- [ ] Smoke test passed
- [ ] Ticket closed
- [ ] Stakeholders notified

---

**Status:** Ready for Execution  
**Estimated Time:** 9.5-10.5 hours active + UAT waiting time  
**Success Rate:** 95%+

**Next Step:** Start with Phase 2 or Phase 3 (can run in parallel)

