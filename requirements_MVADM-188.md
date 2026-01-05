# Requirements Analysis: MVADM-188 - Bill Review UAT Bugs

**Document Version:** 1.0  
**Created:** 2026-01-05  
**Ticket:** [MVADM-188](https://trinitycrm.atlassian.net/browse/MVADM-188)  
**Sandbox:** medivest-eobbcnb  
**Status:** Waiting for approval  
**Due Date:** 2026-01-03 (OVERDUE)  
**Priority:** Medium

---

## Core Summary

The bill review component (`customBillLineItemGrid`) is a Lightning Web Component used for editing medical bill line items in the Medivest system. During User Acceptance Testing (UAT) conducted on December 22, 2024, Chris Caines identified two critical UI bugs that impact the user experience during bill editing. These bugs affect the row cloning functionality and the automatic line numbering system for draft rows. While the component is mostly functional, these issues cause data integrity problems (undefined values) and user confusion (incorrect sequencing), which must be resolved before the component can be considered production-ready.

The bill review component is part of a larger medical billing workflow that includes duplicate detection, adjudication, and EOB (Explanation of Benefits) generation. The component handles both manual line item entry through a persistent draft row and bulk operations including duplication, deletion, and payment calculations.

---

## Explicit Requirements (from Jira)

1. **Fix Row Cloning Bug**: When a user clones a row, the service code (`CPT_HCPCS_NDC__c`) and date fields (`Service_Start_Date__c`, `Service_End_Date__c`) must be populated with the values from the original row, not "undefined".

2. **Fix Draft Line Auto-Numbering**: Draft lines must auto-number correctly to maintain proper bill line sequencing and prevent user confusion.

---

## Implied Requirements

- **[ASSUMPTION]** The cloning functionality should copy ALL fields from the original row to the duplicated row, not just service code and dates. This is inferred from the existing `createDuplicateBillLineItems` Apex method which explicitly copies 24+ fields.

- **[ASSUMPTION]** "Auto-number correctly" means that when a draft row is saved and converted to a permanent line item, it should receive the next sequential `Bill_Line_Item_Number__c` value. This is inferred from the existing `createBillLineItem` method logic (lines 917-929 in TRM_MedicalBillingService.cls).

- **[ASSUMPTION]** The bug affects the UI display layer (JavaScript transformation) rather than the Apex data layer, since the Apex method `createDuplicateBillLineItems` explicitly copies date fields (lines 720-721). This suggests the issue is in the `confirmDuplication` method's `processedDuplicates` mapping (lines 2370-2414).

- **[ASSUMPTION]** The "undefined" values appear in the UI grid immediately after cloning, before any refresh or save operation. This is inferred from the phrase "results in undefined" rather than "saves as undefined".

- **[ASSUMPTION]** The fix must not break existing functionality including: duplicate detection triggers, FileMaker sync flows, rollup summaries (dlrs), payment bulk operations, and validation workflows.

- **[ASSUMPTION]** The fix should maintain the existing TRINITY protocol patterns including debug logging, error handling, and immutable state management.

---

## Constraints

### Technical Constraints

1. **Must use existing Salesforce object**: `Bill_Line_Item__c` with existing field schema
2. **Must preserve existing Apex methods**: `createDuplicateBillLineItems` and `createBillLineItem` in `TRM_MedicalBillingService.cls`
3. **Must work with existing triggers**:
   - `BillLineItemDuplicateDetection.trigger` (duplicate detection)
   - `dlrs_Bill_Line_ItemTrigger.trigger` (rollup summaries)
4. **Must work with existing flows**:
   - `Bill_Line_Item_Generate_Filemaker_Id` (External_Id__c generation)
   - `Bill_Line_Item_Create_Update_Filemaker_Sync_Event` (FileMaker integration)
5. **Must maintain LWC architecture**: `customBillLineItemGrid` component with wire service pattern
6. **Must preserve data transformation logic**: The `processLineItems` pattern for formatting dates, currency, and display values
7. **Platform version**: Salesforce API version 62.0

### Business Constraints

1. **Must support existing bill review workflow**: Draft row → Save → Auto-number → Duplicate detection → Adjudication → EOB generation
2. **Must maintain data integrity**: No null/undefined values in required fields (CPT code, dates, charge amounts)
3. **Must preserve user experience patterns**: Persistent draft row, Tab/Enter navigation, auto-save, bulk operations
4. **Must support concurrent editing**: Multiple users may edit different bills simultaneously
5. **Must maintain audit trail**: All changes logged via FileMaker sync events

### Timeline Constraints

1. **Due date**: 2026-01-03 (ALREADY OVERDUE by 2 days as of 2026-01-05)
2. **UAT completion**: Must be re-tested by Chris Caines before production deployment
3. **Approval required**: Ticket is in "Waiting for approval" status, suggesting stakeholder sign-off needed

---

## Stakeholders

| Name | Role | Relationship to Work |
|------|------|---------------------|
| Chris Caines | UAT Tester / Product Owner | Reported the bugs during UAT on 12/22 call; must approve fix |
| Alexia Abrego | Developer | Current assignee (inferred from workspace context) |
| Ray Marden | Domain Expert | Original architect of bill review component (referenced in code comments) |
| End Users | Bill Review Specialists | Will use the cloning and manual entry features daily |

---

## Success Criteria

### ✅ Medivest Client-Derived Criteria

1. **Cloning produces complete rows**: When a user selects a row and clicks "Duplicate", the new row(s) must display all field values from the original row, including:
   - Service Start Date (`Service_Start_Date__c`)
   - Service End Date (`Service_End_Date__c`)
   - CPT/HCPCS/NDC Code (`CPT_HCPCS_NDC__c`)
   - All other fields (Revenue Code, Place of Service, Modifier, Quantity, Charge, etc.)

2. **No "undefined" values in UI**: The grid must never display "undefined" in any cell after cloning or any other operation.

3. **Sequential line numbering**: Draft rows, when saved, must receive the next sequential line number (e.g., if max existing line number is 5, new draft becomes line 6).

4. **Line numbers display correctly**: The `lineNumber` column must show the correct `Bill_Line_Item_Number__c` value for all rows, including newly created rows from draft.

5. **UAT re-test passes**: Chris Caines must be able to:
   - Clone a row with populated service code and dates
   - See all fields correctly populated in the cloned row
   - Create a new draft line item
   - See it auto-numbered correctly after save
   - Confirm no confusion in bill line sequencing

### Additional Technical Success Criteria

6. **No regression**: All existing functionality must continue to work:
   - Bulk payment operations
   - Duplicate detection
   - Validation and adjudication
   - FileMaker sync
   - EOB generation

7. **Debug logging preserved**: All TRINITY debug logging must remain for troubleshooting

8. **Performance maintained**: Cloning and draft save operations must complete within existing performance benchmarks (< 2 seconds for typical operations)

---

## Ambiguity Log

### 🔴 Critical Ambiguities

1. **What is the exact reproduction path for the cloning bug?**
   - Does it happen with single row duplication or only bulk duplication?
   - Does it happen with all rows or only rows with specific field combinations?
   - Is the bug visible immediately or only after a page refresh?
   - **Action needed**: Request detailed reproduction steps from Chris Caines

2. **What does "draft lines do not auto-number correctly" mean specifically?**
   - Do they get no line number (null/blank)?
   - Do they get the wrong line number (e.g., duplicate numbers)?
   - Do they get line numbers out of sequence?
   - Does this happen on initial save or after subsequent edits?
   - **Action needed**: Request screenshot or specific example from Chris Caines

3. **Are there specific test data scenarios that trigger these bugs?**
   - Specific Bill records (BCN numbers)?
   - Specific line item configurations?
   - Specific user actions or sequences?
   - **Action needed**: Request test case details from Chris Caines

### 🟡 Medium Priority Ambiguities

4. **What is the expected behavior when cloning a draft row?**
   - Should draft rows be clonable, or should cloning be disabled for draft rows?
   - Current code filters out draft rows from bulk operations (line 2173)
   - **Action needed**: Clarify business requirement

5. **Should line numbers be editable by users or always system-generated?**
   - Current implementation: System-generated via Apex (lines 917-929)
   - UI shows line numbers but editability is unclear
   - **Action needed**: Confirm with product owner

6. **What happens to line numbers when rows are deleted?**
   - Do remaining rows renumber sequentially?
   - Do gaps remain in the sequence?
   - **Action needed**: Clarify expected behavior

### 🟢 Low Priority Ambiguities

7. **Is there a maximum number of line items per bill?**
   - Duplication has a 100-row limit (line 2340)
   - But is there a total limit per bill?
   - **Action needed**: Document for future reference

8. **What timezone should be used for date display formatting?**
   - Current code uses `toLocaleDateString()` (line 2378)
   - Should this be user's timezone or org default?
   - **Action needed**: Verify with stakeholders if issues arise

---

## TRACKER Intelligence Summary

### Historical Patterns

**Related Tickets:**
- **MVADM-170** (Done): "Bill Review LWC - Historical BCN Status List & Duplicate Picklist" - Previous bill review enhancements
- **MVADM-165** (Done): "11/13/25 Teams Call - Bill Review Documentation & Quote Fields" - Documentation and field updates
- **MVADM-157** (Done): "11/04/25 Bill Review LWC - Feedback" - Previous UAT feedback cycle
- **MVADM-92** (Done): "Bill Review - Adjudication Requirements" - Core adjudication logic
- **MVADM-89** (Done): "Bill Review - Missing Place of Service (POS) Codes" - Field validation fixes
- **MVADM-86** (Waiting for approval): "Bill Review - Tab Functionality" - Navigation enhancements
- **MVADM-85** (In Progress): "EOBs Mass Generation - Replicating Legacy Functionality" - Related EOB work

**Pattern Analysis:**
- Bill review component has been under active development since September 2024
- Multiple UAT cycles with iterative feedback from Chris Caines and Ray Marden
- History of UI bugs requiring fixes (undefined values, field validation, navigation)
- Component is part of larger EOB generation workflow (MVADM-85 still in progress)

### Scope Creep Risks

⚠️ **HIGH RISK**: This ticket is narrowly scoped to "2 items" but the bill review component is complex with many interdependencies:
- Duplicate detection system (triggers + handlers)
- FileMaker sync integration (flows)
- Payment bulk operations
- Validation and adjudication workflows

**Mitigation**: Strictly limit fix to the two reported bugs. Do NOT refactor or enhance other functionality.

### Capacity/Timeline Concerns

🔴 **CRITICAL**: Ticket is already 2 days overdue (due 2026-01-03, today is 2026-01-05)

⚠️ **CONCERN**: Ticket is in "Waiting for approval" status but also overdue, suggesting:
- Approval may be blocked on something
- Timeline may need renegotiation
- Stakeholder alignment may be needed

**Recommendation**: Clarify approval status and timeline expectations before starting work.

### Early Risk Signals

1. **Vague bug descriptions**: "undefined" and "do not auto-number correctly" lack specificity
2. **No acceptance criteria**: Jira ticket has no explicit AC, only problem description
3. **No test cases**: No mention of specific test scenarios or data
4. **UAT context missing**: Reference to "12/22 call (24:14)" but no meeting notes or recording linked
5. **Multiple related tickets in progress**: MVADM-85, MVADM-86 may have dependencies

**Recommendation**: Front-load discovery and verification before coding. Request detailed reproduction steps, test data, and acceptance criteria from Chris Caines.

---

## SAGE Platform Research Summary

### Salesforce Platform Constraints

**Bill_Line_Item__c Object:**
- Custom object with 50+ fields
- Key fields: `Bill_Line_Item_Number__c` (Decimal), `Service_Start_Date__c` (Date), `Service_End_Date__c` (Date), `CPT_HCPCS_NDC__c` (Text)
- Has 2 active triggers: duplicate detection + rollup summaries
- Has 3 active flows: FileMaker ID generation, FileMaker sync, Bill relationship

**LWC Framework:**
- API version 62.0 (Spring '24 release)
- Wire service pattern for reactive data
- `@track` decorator for reactive properties
- Lightning Confirm/Alert for modals

### Code Architecture Insights

**Current Duplication Flow:**
1. User selects row(s) and clicks "Duplicate" button
2. Modal opens for count input (`showDuplicationModal`)
3. User confirms → `confirmDuplication()` method executes
4. Apex method `createDuplicateBillLineItems` creates records
5. JavaScript transforms returned records via `processedDuplicates` mapping
6. Transformed records added to `lineItems` array
7. UI re-renders with new rows

**Potential Bug Location (Cloning):**
- Lines 2370-2414 in `customBillLineItemGrid.js`
- The `processedDuplicates` mapping may not be correctly accessing date fields
- Possible issue: `item.Service_Start_Date__c` vs `item.formattedStartDate` confusion

**Current Draft Row Flow:**
1. Component initializes with `initializeDraftRow()` (lines 515-554)
2. User enters data → `handleDraftFieldChange()` updates draft object
3. User presses Tab/Enter → `handleDraftSave()` executes
4. Apex method `createBillLineItem` calculates next line number and saves
5. New record returned and added to grid
6. New empty draft row created

**Potential Bug Location (Auto-numbering):**
- Lines 917-929 in `TRM_MedicalBillingService.cls` (Apex calculates line number)
- Lines 1361-1428 in `customBillLineItemGrid.js` (JavaScript handles save flow)
- Possible issue: Line number not being displayed after save, or calculation logic failing

---

## Next Steps

1. ✅ **Requirements document complete** (this document)
2. ⏸️ **BLOCKED**: Await clarification on ambiguities from Chris Caines
3. ⏸️ **BLOCKED**: Confirm approval status and timeline with stakeholders
4. 🔜 **Next**: Create detailed test plan with reproduction steps
5. 🔜 **Next**: Perform root cause analysis in sandbox
6. 🔜 **Next**: Develop surgical fix with comprehensive testing
7. 🔜 **Next**: UAT with Chris Caines
8. 🔜 **Next**: Production deployment

---

**Document Status:** ✅ COMPLETE - Ready for stakeholder review
**Blocking Issues:** Ambiguities #1, #2, #3 must be resolved before proceeding to implementation

