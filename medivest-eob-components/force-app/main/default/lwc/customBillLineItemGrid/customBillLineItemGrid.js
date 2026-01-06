/**
 * Custom Bill Line Item Grid - v2.7.3-simple-date-inputs
 * TRINITY v2.7.3: Simple text inputs for date fields (no modal picker)
 *   - Changed Service Start/End Date from lightning-input type="date" to simple text inputs
 *   - CLIENT REQUIREMENT: Modal date picker slows down data entry workflow
 *   - Users can now type dates directly without modal interruption
 * TRINITY v2.7.2: CRITICAL FIX - Race condition in empty Bill scenario
 *   - Fixed: Removed synchronous billId check that fired before async query completed
 *   - Error handling now occurs inside queryBillIdFromCase() after query completes
 *   - Prevents "No Bill found" error when Bill exists but has no line items
 * TRINITY v2.7.1: Empty Bill Support - Handles Bills with no line items
 *   - Queries Case.BCN__c directly when no line items exist (getBillIdFromCase)
 *   - Enables draft row creation for first line item in new Bills
 * CLIENT REQUIREMENT v2.7.0: Component must error and not load if Case has no Bill (BCN__c)
 * REMOVED: Auto-create Bill functionality (handleMissingBill method)
 * ADDED: Error state when Bill is missing (handleMissingBillError method)
 * UAT: POS field converted to code lookup (matches Revenue/CPT/Remark pattern)
 * MVADM-170: Display BCN_Custom_Status__c as read-only badge in header
 * TRINITY v2.6.1: CRITICAL FIX - Added selectedStage getter to enable Bill Review column resizing
 * TRINITY v2.6.0: Excel-perfect column resizing with <colgroup> (fixes header/body misalignment)
 *   - <colgroup> with <col> elements for synchronized column widths across headers and cells
 *   - Resizer positioned EXACTLY at border (right: -5px) with no intrusion into header content
 *   - Column-specific minimum widths for professional UX (60px-150px based on content type)
 *   - Live resize preview with instant visual feedback (Excel-like behavior)
 *   - Persistent column width tracking via @track columnWidths object
 * TRINITY v2.5.1: BCN Number validation (CRITICAL BLOCKER FIX - prevents grid crash without valid Bill)
 * TRINITY v2.5.0: Quote View stage for simplified quote display (6 columns, no expandables)
 * TRINITY v2.4.2: Modal refresh on reopen + footer scrollbar clearance
 * TRINITY v2.4.1: Footer totals implementation (V1 REQUIREMENT - CRITICAL FOR EOB GENERATION)
 * MVADM-XXX: Account field converted to editable dropdown (saves to Bill_Line_Item__c.Account__c)
 * MVADM-155: Manual line item entry with persistent blank row, Tab/Enter navigation, auto-save
 * AUTO-REGENERATING DRAFT: New draft row created immediately when current draft is saved
 * QC FIXES: enrichCodeDescriptions draft row filter, single item enrichment, allSelected getter
 * CRITICAL DRAFT ROW FIXES (MALFORMED_ID prevention):
 *   - handleFieldBlur: Skip auto-save for draft row
 *   - handleCodeSelected: Skip auto-save for draft row, UPDATE draftRow object
 *   - applyPaymentBulkOperation: Filter out draft row before bulk updates
 *   - applyAltClickBulkAssignment: Filter out draft row before bulk updates
 * DRAFT SAVE TRIGGER FIX: hasAnyData checks ALL fields, handleCodeSelected updates draftRow
 * DRAFT DISPLAY SYNC FIX: handleDraftFieldChange updates BOTH draftRow AND lineItems array
 * ACCOUNT DROPDOWN: Account field now editable dropdown populated from Member_Account__c (MSA/PCA/SAK/MCA)
 * OTHER FIXES: Apex SOQL bind variable, code-only display (client requirement 10/29)
 * TRINITY DEPLOYMENT ARCHITECT: Professional credibility protection, zero breakage commitment
 */
import { LightningElement, api, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';
import LightningConfirm from 'lightning/confirm';

// Apex methods - TRINITY: Use correct service class
import getBillLineItems from '@salesforce/apex/TRM_MedicalBillingService.getBillLineItems';
import updateBillLineItems from '@salesforce/apex/TRM_MedicalBillingService.updateBillLineItems';
import getRemarkCodes from '@salesforce/apex/TRM_MedicalBillingService.getRemarkCodes';
import getMemberAccounts from '@salesforce/apex/TRM_MedicalBillingService.getMemberAccounts';
import createDuplicateBillLineItems from '@salesforce/apex/TRM_MedicalBillingService.createDuplicateBillLineItems';
import deleteBillLineItems from '@salesforce/apex/TRM_MedicalBillingService.deleteBillLineItems';
import getCodeDescription from '@salesforce/apex/TRM_MedicalBillingService.getCodeDescription';
import searchCodes from '@salesforce/apex/TRM_MedicalBillingService.searchCodes';
import getCodeDetails from '@salesforce/apex/TRM_MedicalBillingService.getCodeDetails';
import getCodeDescriptionsBatch from '@salesforce/apex/TRM_MedicalBillingService.getCodeDescriptionsBatch';
import createBillLineItem from '@salesforce/apex/TRM_MedicalBillingService.createBillLineItem'; // MVADM-155: Manual entry
import getCaseBCNNumber from '@salesforce/apex/TRM_MedicalBillingService.getCaseBCNNumber'; // TRINITY v2.5.1: BCN validation
import getBillIdFromCase from '@salesforce/apex/TRM_MedicalBillingService.getBillIdFromCase'; // TRINITY v2.7.1: Empty Bill support

// TRINITY VALIDATION: Comprehensive validation service
import validateBCNQuoteForAdjudication from '@salesforce/apex/TRM_ValidationService.validateBCNQuoteForAdjudication';

// TRINITY ADJUDICATION: Mark line items as processed after validation
import markLineItemsAsProcessed from '@salesforce/apex/TRM_MedicalBillingService.markLineItemsAsProcessed';

import { getObjectInfo, getPicklistValues } from "lightning/uiObjectInfoApi";

import BILL_LINE_ITEM_OBJECT from "@salesforce/schema/Bill_Line_Item__c";

//import CUSTOM_STATUS_FIELD from "@salesforce/schema/Bill_Line_Item__c.TRM_BCN_Custom_Status__c";


export default class CustomBillLineItemGrid extends LightningElement {
    // TRINITY: Simple, direct properties - NO over-engineering
    @api recordId; // Case ID
    
    // Data properties
    @track lineItems = [];
    @track remarkCodeOptions = [];
    @track accountOptions = [];
    @track isLoading = true;
    @track error = null;
    
    // Simple state management - NO Maps, NO complex objects
    @track selectedIds = new Set();
    @track currentStage = 'keying'; // 'keying' or 'billReview'
    @track editingField = null;
    @track editingRowId = null;

    // MVADM-155: Draft row for manual entry
    @track draftRow = null; // Persistent blank row at bottom of grid
    @track billId = null; // BCN ID extracted from line items for createBillLineItem()
    @track billCustomStatus = null; // MVADM-170: BCN_Custom_Status__c from Bill__c for display

    // TRINITY v2.5.1: BCN Number validation (CRITICAL BLOCKER FIX)
    @track bcnNumber = null;
    @track bcnValidationError = null;

    // TRINITY: Duplication modal state
    @track showDuplicationModal = false;
    @track duplicateCount = 1;

    // TRINITY v2.3.0: Validation modal state
    @track showValidationModal = false;
    @track validationResult = null;
    @track isProcessingAdjudication = false; // TRINITY: Processing state for adjudication

    // Expandable column states - SIMPLE booleans
    @track serviceDatesExpanded = false;
    @track codesExpanded = false;
    @track remarkCodesExpanded = false;

    // TRINITY PHASE 2: Right-click context menu state
    @track showContextMenu = false;
    @track contextMenuX = 0;
    @track contextMenuY = 0;
    @track contextMenuField = '';
    @track contextMenuValue = '';
    @track contextMenuRowId = '';
    @track contextMenuApplyTo = 'all'; // 'all', 'blank', or 'following'
    @track followingRowsCount = 1;
    @track contextMenuType = 'simple'; // 'simple' | 'payment'

    // TRINITY PHASE 3: Payment context menu properties
    @track selectedPaymentOperation = 'percentage'; // 'percentage' | 'fixedAmount'
    @track paymentPercentage = 80; // Default 80%
    @track paymentFixedAmount = 0;
    @track paymentApplyTo = 'allRows'; // 'allRows' | 'blankRows' | 'followingRows'

    // TRINITY v2.6.0: Excel-perfect column resizing with <colgroup>
    @track isResizing = false;
    @track resizingColumn = null;

    //@track customStatusOptions = [];

    // TRINITY: Store bound event handlers for proper cleanup
    boundHandleResizeMove = null;
    boundHandleResizeEnd = null;
    boundHandleWindowClick = null; // TRINITY PHASE 2: For context menu click-outside-to-close

    // TRINITY v2.6.0: Column width tracking (pixels) - Excel-perfect resizing
    @track columnWidths = {
        // Keying/Bill Review columns
        lineNumber: 60,
        serviceDates: 130,
        endDate: 130,
        codes: 140,
        pos: 60,
        cpt: 150,
        modifier: 80,
        quantity: 80,
        //customStatus: 120,
        description: 200,
        charge: 120,
        remarkCodes: 140,
        rc2: 100,
        rc3: 100,
        rc4: 100,
        oiAllow: 120,
        oiPaid: 120,
        paid: 120,
        thirdParty: 120,
        patResp: 120,
        account: 150,
        medicare: 120,
        // Quote View columns
        code: 150,
        price: 120,
        approvedAmount: 120
    };

    // TRINITY UX: Drag state for context menu
    isDragging = false;
    dragStartX = 0;
    dragStartY = 0;
    dragOffsetX = 0;
    dragOffsetY = 0;

    // TRINITY TOOLTIP ENHANCEMENT: Performance optimization cache
    codeDescriptionCache = new Map(); // Cache for code descriptions to avoid redundant API calls

    // Wire result storage
    wiredLineItemsResult;

    // TRINITY: Lookup field configuration for enhanced code fields
    // CORRECTED: Removed descriptionField - Description field is discrete and separate
    LOOKUP_FIELD_CONFIG = {
        'Revenue_Code__c': {
            codeTypes: ['RevenueCodes'],
            placeholder: 'Search revenue codes...',
            allowCustomEntry: false
        },
        'Place_of_Service__c': {
            codeTypes: ['POS'],
            placeholder: 'Search POS codes...',
            allowCustomEntry: false
        },
        'CPT_HCPCS_NDC__c': {
            codeTypes: ['HCPCS', 'NDC Products', 'CPT RVU'],
            placeholder: 'Search CPT/HCPCS/NDC codes...',
            allowCustomEntry: true
        },
        'Remark_Code_1__c': {
            codeTypes: ['BillRemarkCodes'],
            placeholder: 'Search remark codes...',
            allowCustomEntry: false
        },
        'Remark_Code_2__c': {
            codeTypes: ['BillRemarkCodes'],
            placeholder: 'Search remark codes...',
            allowCustomEntry: false
        },
        'Remark_Code_3__c': {
            codeTypes: ['BillRemarkCodes'],
            placeholder: 'Search remark codes...',
            allowCustomEntry: false
        },
        'Remark_Code_4__c': {
            codeTypes: ['BillRemarkCodes'],
            placeholder: 'Search remark codes...',
            allowCustomEntry: false
        }
    };

    // Stage selector options
    get stageOptions() {
        return [
            { label: 'Keying Stage', value: 'keying' },
            { label: 'Bill Review Stage', value: 'billReview' },
            { label: 'Quote View', value: 'quote' }
        ];
    }

    // Computed properties
    get showAdjudicationColumns() {
        return this.currentStage === 'billReview';
    }

    // TRINITY v2.5.0: Quote view visibility
    get showQuoteView() {
        return this.currentStage === 'quote';
    }

    // TRINITY v2.6.1: Expose currentStage for data-stage attribute (CRITICAL FIX - enables Bill Review CSS)
    get selectedStage() {
        return this.currentStage;
    }

    // TRINITY v2.5.1: BCN validation visibility controls (CRITICAL BLOCKER FIX)
    get showGrid() {
        if (this.bcnValidationError) return false;
        if (!this.bcnNumber) return false;
        const bcnNumeric = parseFloat(this.bcnNumber);
        return !isNaN(bcnNumeric) && bcnNumeric > 0;
    }

    get showValidationError() {
        return this.bcnValidationError !== null;
    }

    get selectedCount() {
        return this.selectedIds.size;
    }

    get hasSelectedItems() {
        return this.selectedIds.size > 0;
    }

    // TRINITY v2.6.0: Column width computed properties for <colgroup>
    get lineNumberColWidth() { return `width: ${this.columnWidths.lineNumber}px;`; }
    get serviceDatesColWidth() { return `width: ${this.columnWidths.serviceDates}px;`; }
    get endDateColWidth() { return `width: ${this.columnWidths.endDate}px;`; }
    get codesColWidth() { return `width: ${this.columnWidths.codes}px;`; }
    get posColWidth() { return `width: ${this.columnWidths.pos}px;`; }
    get cptColWidth() { return `width: ${this.columnWidths.cpt}px;`; }
    get modifierColWidth() { return `width: ${this.columnWidths.modifier}px;`; }
    get quantityColWidth() { return `width: ${this.columnWidths.quantity}px;`; }
    //get customStatusColWidth() { return `width: ${this.columnWidths.customStatus}px;`; }
    get descriptionColWidth() { return `width: ${this.columnWidths.description}px;`; }
    get chargeColWidth() { return `width: ${this.columnWidths.charge}px;`; }
    get remarkCodesColWidth() { return `width: ${this.columnWidths.remarkCodes}px;`; }
    get rc2ColWidth() { return `width: ${this.columnWidths.rc2}px;`; }
    get rc3ColWidth() { return `width: ${this.columnWidths.rc3}px;`; }
    get rc4ColWidth() { return `width: ${this.columnWidths.rc4}px;`; }
    get oiAllowColWidth() { return `width: ${this.columnWidths.oiAllow}px;`; }
    get oiPaidColWidth() { return `width: ${this.columnWidths.oiPaid}px;`; }
    get paidColWidth() { return `width: ${this.columnWidths.paid}px;`; }
    get thirdPartyColWidth() { return `width: ${this.columnWidths.thirdParty}px;`; }
    get patRespColWidth() { return `width: ${this.columnWidths.patResp}px;`; }
    get accountColWidth() { return `width: ${this.columnWidths.account}px;`; }
    get medicareColWidth() { return `width: ${this.columnWidths.medicare}px;`; }
    get codeColWidth() { return `width: ${this.columnWidths.code}px;`; }
    get priceColWidth() { return `width: ${this.columnWidths.price}px;`; }
    get approvedAmountColWidth() { return `width: ${this.columnWidths.approvedAmount}px;`; }

    // TRINITY v2.3.0: Show Adjudicate button only in Bill Review stage
    get showAdjudicateButton() {
        return this.currentStage === 'billReview';
    }

    // TRINITY PHASE 1.6: Show View Report button after validation has been run (CHRIS'S #1 PRIORITY)
    get showViewReportButton() {
        return this.validationResult !== null && this.currentStage === 'billReview';
    }

    // TRINITY PHASE 2: Context menu positioning
    get contextMenuStyle() {
        return `position: fixed; left: ${this.contextMenuX}px; top: ${this.contextMenuY}px; z-index: 9999;`;
    }

    // TRINITY PHASE 3: Payment context menu getters
    get isPaymentContextMenu() {
        return this.showContextMenu && this.contextMenuType === 'payment';
    }

    get isSimpleContextMenu() {
        return this.showContextMenu && this.contextMenuType === 'simple';
    }

    get paymentOperationOptions() {
        return [
            { label: 'Percentage of Charge', value: 'percentage' },
            { label: 'Fixed Dollar Amount', value: 'fixedAmount' }
        ];
    }

    get isPercentageOperation() {
        return this.selectedPaymentOperation === 'percentage';
    }

    get isFixedAmountOperation() {
        return this.selectedPaymentOperation === 'fixedAmount';
    }

    get paymentApplyToOptions() {
        return [
            { label: 'All Rows', value: 'allRows' },
            { label: 'Blank Rows Only', value: 'blankRows' },
            { label: 'Following Rows', value: 'followingRows' }
        ];
    }

    get showFollowingRowsInput() {
        return this.paymentApplyTo === 'followingRows';
    }

    get isApplyDisabled() {
        if (this.selectedPaymentOperation === 'percentage') {
            return !this.paymentPercentage || this.paymentPercentage < 0 || this.paymentPercentage > 100;
        } else {
            return !this.paymentFixedAmount || this.paymentFixedAmount < 0;
        }
    }
    
    // Utility methods
    formatCurrency(value) {
        if (!value) return '$0.00';
        return new Intl.NumberFormat('en-US', {
            style: 'currency',
            currency: 'USD'
        }).format(value);
    }

    getDuplicateStatusLabel(status) {
        switch(status) {
            case 'Potential':
                return 'Potential Duplicate';
            case 'Exact':
                return 'Exact Duplicate';
            default:
                return '';
        }
    }

    formatDate(dateValue) {
        if (!dateValue) return '';

        // TRINITY v2.7.3: Treat dates as simple text strings - NO timezone conversion
        // Salesforce Date fields come as "YYYY-MM-DD" or user enters "MM/DD/YYYY"
        // Just parse and format without timezone shifts

        // If already in MM/DD/YYYY format, return as-is
        if (dateValue.includes('/')) {
            return dateValue;
        }

        // If in YYYY-MM-DD format (from Salesforce), convert to MM/DD/YYYY
        // Parse manually to avoid timezone issues
        const parts = dateValue.split('-');
        if (parts.length === 3) {
            const year = parts[0];
            const month = parts[1];
            const day = parts[2];
            return `${month}/${day}/${year}`;
        }

        // Fallback: return as-is
        return dateValue;
    }
    
    showToast(title, message, variant = 'info') {
        this.dispatchEvent(new ShowToastEvent({
            title,
            message,
            variant
        }));
    }

    // ========================================
    // TRINITY v2.4.1: FOOTER TOTALS (V1 REQUIREMENT - CRITICAL FOR EOB GENERATION)
    // ========================================

    /**
     * TRINITY: Footer totals computed property
     * Calculates real-time totals for all currency fields
     * CRITICAL: Filters out draft row to avoid MALFORMED_ID errors
     */
    get footerTotals() {
        // TRINITY DEFENSIVE: Filter out draft row (ID: 'draft-row-temp')
        const realItems = this.lineItems.filter(item => !item.isDraft && item.Id !== 'draft-row-temp');

        const totalCharge = this.calculateSum(realItems, 'Charge__c');
        const totalPaid = this.calculateSum(realItems, 'Approved_Amount__c');

        return {
            totalCharge: totalCharge,
            totalPaid: totalPaid,
            totalAdjustments: totalCharge - totalPaid,
            thirdPartyResp: this.calculateSum(realItems, 'X3rd_Party_Curr__c'),
            patientResp: this.calculateSum(realItems, 'Patient_Responsibility__c')
        };
    }

    /**
     * TRINITY: Formatted footer values for display
     * Uses consistent currency formatting with explicit decimal places
     */
    get formattedTotalCharge() {
        return this.formatFooterCurrency(this.footerTotals.totalCharge);
    }

    get formattedTotalPaid() {
        return this.formatFooterCurrency(this.footerTotals.totalPaid);
    }

    get formattedTotalAdjustments() {
        return this.formatFooterCurrency(this.footerTotals.totalAdjustments);
    }

    get formattedThirdPartyResp() {
        return this.formatFooterCurrency(this.footerTotals.thirdPartyResp);
    }

    get formattedPatientResp() {
        return this.formatFooterCurrency(this.footerTotals.patientResp);
    }

    /**
     * TRINITY: Defensive programming helper for sum calculation
     * Cascading type checks for deployment robustness
     * Handles: null, undefined, text strings, numeric values, abnormal formats
     */
    calculateSum(items, fieldName) {
        // TRINITY DEFENSIVE: Validate inputs
        if (!items || !Array.isArray(items)) return 0;
        if (!fieldName || typeof fieldName !== 'string') return 0;

        return items.reduce((sum, item) => {
            if (!item) return sum;

            const rawValue = item[fieldName];
            if (rawValue === null || rawValue === undefined) return sum;

            // Handle text values (e.g., "0.00" strings from X3rd_Party__c history)
            if (typeof rawValue === 'string') {
                const parsed = parseFloat(rawValue);
                return sum + (isNaN(parsed) ? 0 : parsed);
            }

            // Handle numeric values
            if (typeof rawValue === 'number') {
                return sum + (isNaN(rawValue) ? 0 : rawValue);
            }

            // Abnormal formats - default to 0
            return sum;
        }, 0);
    }

    /**
     * TRINITY: Consistent currency formatting for footer
     * Explicit decimal places for professional display
     */
    formatFooterCurrency(value) {
        if (value === null || value === undefined || isNaN(value)) return '$0.00';
        return new Intl.NumberFormat('en-US', {
            style: 'currency',
            currency: 'USD',
            minimumFractionDigits: 2,
            maximumFractionDigits: 2
        }).format(value);
    }

    // ========================================
    // END TRINITY v2.4.1: FOOTER TOTALS
    // ========================================

    // MVADM-155: Initialize draft row for manual entry
    // TRINITY: Match EXACT structure of real rows from processLineItems (lines 306-378)
    initializeDraftRow() {
        this.draftRow = {
            Id: 'draft-row-temp', // CRITICAL: Unique temp ID to avoid conflicts with 18-char Salesforce IDs
            isDraft: true, // Flag to identify draft row
            selected: false,

            // Line number - blank for draft row
            lineNumber: '',

            // Account name - will be set when Account__c is selected
            accountName: '',

            // Data entry fields - initialize to null/empty
            Service_Start_Date__c: null,
            Service_End_Date__c: null,
            Revenue_Code__c: '',
            Place_of_Service__c: '',
            CPT_HCPCS_NDC__c: '',
            Modifier__c: '',
            Quantity__c: null,
            Charge__c: null,
            //TRM_BCN_Custom_Status__c: '',
            Description__c: '',
            Code__c: null,
            Account__c: null,

            // Adjudication fields - initialize to defaults
            Approved_Amount__c: 0.00,
            Patient_Responsibility__c: 0.00,
            X3rd_Party_Curr__c: 0.00, // TRINITY: Currency field
            Other_Ins_Allowed__c: 0.00,
            Other_Ins_Paid__c: 0.00,
            Adjustment_Amount__c: 0.00,
            Savings_Fee__c: 0.00,

            // Remark codes
            Remark_Code_1__c: '',
            Remark_Code_2__c: '',
            Remark_Code_3__c: '',
            Remark_Code_4__c: '',

            // Formatted values for display
            formattedStartDate: '',
            formattedEndDate: '',
            formattedCharge: '$0.00',
            formattedOIAllow: '$0.00',
            formattedOIPaid: '$0.00',
            formattedPaid: '$0.00',
            formattedThirdParty: '$0.00',
            formattedPatResp: '$0.00',

            // Medicare status
            medicareStatus: 'TBD',
            medicareStatusValue: 'TBD',
            medicareStatusYes: false,
            medicareStatusNo: false,
            medicareStatusReview: false,
            medicareStatusTBD: true,
            medicareStatusDiscretion: false,
            medicareStatusTooltip: 'Medicare coverage status to be determined',

            // Duplicate detection
            isDuplicate: false,
            duplicateStatus: 'None',
            duplicateStatusLabel: '',

            // Code descriptions for tooltips
            revenueCode: '',
            revenueCodeDescription: '',
            revenueCodeDisplay: '',
            posCode: '',
            posCodeDescription: '',
            posDisplay: '',
            cptCode: '',
            cptCodeDescription: '',
            cptDisplay: '',
            modifierCode: '',
            modifierCodeDescription: '',
            modifierDisplay: '',
            remarkCode1Display: '',
            remarkCode2Display: '',
            remarkCode3Display: '',
            remarkCode4Display: '',
            codesDescriptionTooltip: '',

            // Validation
            validationStatus: 'valid',
            validationErrors: [],
            validationWarnings: [],
            rowClass: 'grid-row draft-row' // MVADM-155: Draft row styling
        };

        console.log('TRINITY DEBUG: Initialized draft row');
    }

    // TRINITY v2.5.1: Wire BCN Number for validation (CRITICAL BLOCKER FIX)
    @wire(getCaseBCNNumber, { caseId: '$recordId' })
    wiredBCNNumber({ error, data }) {
        if (data !== undefined) {
            this.bcnNumber = data;
            console.log('TRINITY BCN VALIDATION: BCN Number =', this.bcnNumber);

            // Validate BCN Number (String field, check if null/empty or numeric value <= 0)
            const bcnNumeric = this.bcnNumber ? parseFloat(this.bcnNumber) : 0;
            if (!this.bcnNumber || bcnNumeric <= 0 || isNaN(bcnNumeric)) {
                this.bcnValidationError = 'Cannot open Bill Line Items. BCN Number is missing. Please ensure the case is in Keying stage and has a valid Bill record.';
                this.isLoading = false;
                console.log('TRINITY BCN VALIDATION: FAILED - Invalid BCN Number');
            } else {
                this.bcnValidationError = null;
                console.log('TRINITY BCN VALIDATION: PASSED - Valid BCN Number');
            }
        } else if (error) {
            console.error('TRINITY BCN VALIDATION: Error loading BCN Number', error);
            this.bcnValidationError = 'Error loading BCN Number';
            this.isLoading = false;
        }
    }

    // TRINITY: Wire Apex data services - simple and direct
    @wire(getBillLineItems, { caseId: '$recordId' })
    wiredLineItems(result) {
        this.wiredLineItemsResult = result;
        if (result.data) {
            this.processLineItems(result.data);

            // TRINITY v2.7.1: REMOVED synchronous billId check - moved to queryBillIdFromCase()
            // The async query handles error state internally after completion
            // This prevents race condition where error fires before async query completes

            this.error = null;
        } else if (result.error) {
            this.error = result.error.body?.message || 'Error loading line items';
            this.lineItems = [];
        }
        this.isLoading = false;
    }

    /**
     * TRINITY v2.4.2: Public method to refresh data when modal reopens
     * Fixes issue where changes don't appear until page reload
     * Called by bcnQuoteQuickAction component when modal opens
     */
    @api
    async refreshData() {
        console.log('TRINITY: Refreshing grid data from Apex');
        this.isLoading = true;
        try {
            await refreshApex(this.wiredLineItemsResult);
            console.log('TRINITY: Grid data refreshed successfully');
        } catch (error) {
            console.error('TRINITY: Error refreshing grid data:', error);
            this.showToast('Refresh Error', 'Failed to refresh data', 'error');
        } finally {
            this.isLoading = false;
        }
    }

    /**
     * TRINITY v2.7.0: CLIENT REQUIREMENT - Error when Bill is missing (no auto-creation)
     * Sets error state to prevent component from loading without a Bill
     * Called when wire adapter returns empty result (no Bill associated with Case)
     */
    handleMissingBillError() {
        console.error('TRINITY: Component cannot load - Case has no Bill (BCN__c)');

        // Set error state
        this.error = 'No Bill found for this Case. Please create a Bill record and associate it with this Case (BCN__c field) before using the Quote Adjudication tool.';
        this.isLoading = false;
        this.lineItems = [];

        // Clear any existing data
        this.billId = null;
        this.draftRow = null;

        console.log('TRINITY: Error state set - component will not load');
    }

    @wire(getRemarkCodes)
    wiredRemarkCodes(result) {
        if (result.data) {
            this.remarkCodeOptions = result.data.map(code => ({
                label: `${code.Name || 'Unknown'} - ${code.Description__c || ''}`,
                value: code.Id
            }));
        } else if (result.error) {
            console.error('Error loading remark codes:', result.error);
        }
    }

    @wire(getMemberAccounts, { caseId: '$recordId' })
    wiredAccounts(result) {
        if (result.data) {
            this.accountOptions = result.data.map(account => ({
                label: `${account.Name || 'Unknown Account'} (${account.Type__c || 'Unknown'})`,
                value: account.Id
            }));
        } else if (result.error) {
            console.error('Error loading accounts:', result.error);
        }
    }
    
    @wire(getObjectInfo, { objectApiName: BILL_LINE_ITEM_OBJECT })
    objectInfo;

    /*@wire(getPicklistValues, { recordTypeId: '$objectInfo.data.defaultRecordTypeId', fieldApiName: CUSTOM_STATUS_FIELD })
    wiredCustomStatusValues({ error, data }) {
        if (data) {
            this.customStatusOptions = data.values;
        } else if (error) {
            console.error('Error loading custom status picklist values', error);

        }
    }*/

    // TRINITY: Medicare status options - MATCHES Code__c.Medicare_Covered__c picklist values (MVADM-76)
    // BEST PRACTICE: UI matches data model, NOT the other way around
    get medicareStatusOptions() {
        return [
            { label: 'Discretion', value: 'Discretion' },
            { label: 'No', value: 'No' },
            { label: 'Review', value: 'Review' },
            { label: 'TBD', value: 'TBD' },
            { label: 'Yes', value: 'Yes' }
        ];
    }

    // TRINITY: Icon getters removed - now using CSS-styled expand icons in template

    // TRINITY: Computed property for duplication modal
    get totalDuplicateRows() {
        return this.selectedIds.size * this.duplicateCount;
    }

    // Selection state
    get allSelected() {
        // MVADM-155 QC FIX: Exclude draft row from selection count
        const selectableItems = this.lineItems.filter(item => item.Id !== 'draft-row-temp');
        return selectableItems.length > 0 && this.selectedIds.size === selectableItems.length;
    }

    // TRINITY: Process line items data - enhanced with code descriptions for tooltips
    processLineItems(data) {
        // [TRINITY DEBUG] Track Approved_Amount__c in INPUT data
        console.log('[TRINITY DEBUG] processLineItems - Input data Approved_Amount__c:',
            data.map(i => ({id: i.Id, name: i.Name, paid: i.Approved_Amount__c})));

        // MVADM-155: Extract Bill__c ID from first line item for createBillLineItem()
        if (data.length > 0 && data[0].Bill__c) {
            this.billId = data[0].Bill__c;
            console.log('TRINITY DEBUG: Extracted Bill ID from line items:', this.billId);

            // MVADM-170: Extract BCN_Custom_Status__c for display in header
            if (data[0].Bill__r?.BCN_Custom_Status__c) {
                this.billCustomStatus = data[0].Bill__r.BCN_Custom_Status__c;
                console.log('MVADM-170: Extracted BCN Custom Status:', this.billCustomStatus);
            }
        } else if (this.recordId) {
            // TRINITY v2.7.1: NO LINE ITEMS - Query Case.BCN__c for draft row creation
            // This handles the "empty Bill" scenario where Bill exists but has no line items yet
            console.log('TRINITY v2.7.1: No line items found, querying Case.BCN__c for Bill ID');
            this.queryBillIdFromCase();
        }

        this.lineItems = data.map(item => ({
            ...item,
            // Selection state
            selected: this.selectedIds.has(item.Id),

            // TRINITY PHASE 1: Line number from Bill_Line_Item_Number__c field (meeting req line 172)
            lineNumber: item.Bill_Line_Item_Number__c || '',

            // TRINITY PHASE 3: Account name from Bill relationship (Bill__r.Member_Account__r.Name)
            accountName: item.Bill__r?.Member_Account__r?.Name || '',

            // Formatted dates
            formattedStartDate: this.formatDate(item.Service_Start_Date__c),
            formattedEndDate: this.formatDate(item.Service_End_Date__c),

            // Formatted currency values
            formattedCharge: this.formatCurrency(item.Charge__c),
            formattedOIAllow: this.formatCurrency(item.Other_Ins_Allowed__c),
            formattedOIPaid: this.formatCurrency(item.Other_Ins_Paid__c),
            formattedPaid: this.formatCurrency(item.Approved_Amount__c),
            formattedThirdParty: this.formatCurrency(item.X3rd_Party_Curr__c),
            formattedPatResp: this.formatCurrency(item.Patient_Responsibility__c),

            // Medicare Covered Display - MVADM-76 (READ-ONLY per requirements)
            // BEST PRACTICE: Use actual picklist values from Code__r.Medicare_Covered__c
            // Values: Discretion, No, Review, TBD, Yes (or null)
            medicareStatus: item.Code__r?.Medicare_Covered__c || 'TBD', // Default to TBD if null
            medicareStatusValue: item.Code__r?.Medicare_Covered__c || 'TBD',
            medicareStatusYes: item.Code__r?.Medicare_Covered__c === 'Yes',
            medicareStatusNo: item.Code__r?.Medicare_Covered__c === 'No',
            medicareStatusReview: item.Code__r?.Medicare_Covered__c === 'Review',
            medicareStatusTBD: item.Code__r?.Medicare_Covered__c === 'TBD' || !item.Code__r?.Medicare_Covered__c,
            medicareStatusDiscretion: item.Code__r?.Medicare_Covered__c === 'Discretion',
            medicareStatusTooltip: this.getMedicareTooltip(item.Code__r?.Medicare_Covered__c),

            // Duplicate detection flag
            isDuplicate: item.Duplicate_Status__c && item.Duplicate_Status__c !== 'None',
            duplicateStatus: item.Duplicate_Status__c,
            duplicateStatusLabel: this.getDuplicateStatusLabel(item.Duplicate_Status__c),

            // TRINITY TOOLTIP ENHANCEMENT: Code values and descriptions
            // Collapsed view shows codes, expanded view shows descriptions
            revenueCode: item.Revenue_Code__c || '',
            revenueCodeDescription: '', // Will be populated via batch lookup
            revenueCodeDisplay: item.Revenue_Code__c || '',

            posCode: item.Place_of_Service__c || '',
            posCodeDescription: '', // Will be populated via batch lookup
            posDisplay: item.Place_of_Service__c || '',

            cptCode: item.CPT_HCPCS_NDC__c || '',
            cptCodeDescription: item.Code__r?.Description__c || '', // From Code__r relationship
            cptDisplay: item.CPT_HCPCS_NDC__c || '',

            modifierCode: item.Modifier__c || '',
            modifierCodeDescription: '', // Will be populated via batch lookup
            modifierDisplay: item.Modifier__c || '',

            // Remark codes display - TRINITY: Use actual field values
            remarkCode1Display: item.Remark_Code_1__c || '',
            remarkCode2Display: item.Remark_Code_2__c || '',
            remarkCode3Display: item.Remark_Code_3__c || '',
            remarkCode4Display: item.Remark_Code_4__c || '',

            // TRINITY TOOLTIP: Placeholder for tooltip content (will be generated after description lookup)
            codesDescriptionTooltip: '',

            // TRINITY PHASE 1.6: Conditional row formatting (CHRIS'S #1 PRIORITY)
            validationStatus: 'valid',  // 'valid' | 'warning' | 'error'
            validationErrors: [],       // Array of error objects: [{rule, message, severity}]
            validationWarnings: [],     // Array of warning objects: [{rule, message, severity}]
            rowClass: 'grid-row row-valid'  // CSS class for row styling
        }));

        // [TRINITY DEBUG] Track Approved_Amount__c in PROCESSED items
        console.log('[TRINITY DEBUG] processLineItems - Processed items Approved_Amount__c:',
            this.lineItems.map(i => ({id: i.Id, name: i.Name, paid: i.Approved_Amount__c})));

        // MVADM-155: Append draft row at bottom of grid for manual entry
        if (!this.draftRow) {
            this.initializeDraftRow();
        }
        this.lineItems = [...this.lineItems, this.draftRow];
        console.log('TRINITY DEBUG: Added draft row, total items:', this.lineItems.length);

        // TRINITY: Batch fetch code descriptions for tooltip display
        this.enrichCodeDescriptions();
    }

    /**
     * TRINITY v2.7.1: Query Bill ID from Case.BCN__c for empty Bill scenario
     * Called when no line items exist but Bill may still be associated with Case
     * Enables draft row creation for first line item in new Bills
     */
    async queryBillIdFromCase() {
        try {
            this.billId = await getBillIdFromCase({ caseId: this.recordId });
            console.log('TRINITY v2.7.1: Queried Bill ID from Case.BCN__c:', this.billId);

            // Check if Bill exists after query
            if (!this.billId) {
                console.log('TRINITY v2.7.1: No Bill found on Case - showing error');
                this.handleMissingBillError();
            } else {
                console.log('TRINITY v2.7.1: Bill found - draft row can be created');
            }
        } catch (error) {
            console.error('TRINITY v2.7.1: Error querying Bill ID from Case:', error);
            this.handleMissingBillError();
        }
    }

    // TRINITY TOOLTIP ENHANCEMENT: Fetch code descriptions using same method as codeLookupField
    async enrichCodeDescriptions() {
        try {
            console.log('TRINITY: Starting enrichCodeDescriptions for', this.lineItems.length, 'items');

            // MVADM-155 QC FIX: Filter out draft row before enrichment (avoid unnecessary API calls)
            const realItems = this.lineItems.filter(item => item.Id !== 'draft-row-temp');
            console.log('TRINITY: Enriching', realItems.length, 'real items (excluding draft row)');

            // Use Promise.all to fetch all descriptions in parallel (same as codeLookupField pattern)
            const enrichedItems = await Promise.all(
                realItems.map(async (item) => {
                    const enriched = { ...item };

                    // Fetch Revenue Code description
                    if (item.Revenue_Code__c && !this.codeDescriptionCache.has(item.Revenue_Code__c)) {
                        try {
                            const details = await getCodeDetails({
                                codeName: item.Revenue_Code__c,
                                codeTypes: ['RevenueCodes']
                            });
                            if (details?.description) {
                                this.codeDescriptionCache.set(item.Revenue_Code__c, details.description);
                            }
                        } catch (error) {
                            console.error('Error fetching revenue code description:', error);
                        }
                    }
                    enriched.revenueCodeDescription = this.codeDescriptionCache.get(item.Revenue_Code__c) || '';

                    // Fetch POS description
                    if (item.Place_of_Service__c && !this.codeDescriptionCache.has(item.Place_of_Service__c)) {
                        try {
                            const details = await getCodeDetails({
                                codeName: item.Place_of_Service__c,
                                codeTypes: ['PlaceOfService']
                            });
                            if (details?.description) {
                                this.codeDescriptionCache.set(item.Place_of_Service__c, details.description);
                            }
                        } catch (error) {
                            console.error('Error fetching POS description:', error);
                        }
                    }
                    enriched.posCodeDescription = this.codeDescriptionCache.get(item.Place_of_Service__c) || '';

                    // Fetch CPT/HCPCS/NDC description
                    if (item.CPT_HCPCS_NDC__c && !this.codeDescriptionCache.has(item.CPT_HCPCS_NDC__c)) {
                        try {
                            const details = await getCodeDetails({
                                codeName: item.CPT_HCPCS_NDC__c,
                                codeTypes: ['HCPCS', 'CPT RVU', 'NDC Products']
                            });
                            if (details?.description) {
                                this.codeDescriptionCache.set(item.CPT_HCPCS_NDC__c, details.description);
                            }
                        } catch (error) {
                            console.error('Error fetching CPT description:', error);
                        }
                    }
                    enriched.cptCodeDescription = this.codeDescriptionCache.get(item.CPT_HCPCS_NDC__c) || '';

                    // Fetch Modifier description
                    if (item.Modifier__c && !this.codeDescriptionCache.has(item.Modifier__c)) {
                        try {
                            const details = await getCodeDetails({
                                codeName: item.Modifier__c,
                                codeTypes: ['Modifiers']
                            });
                            if (details?.description) {
                                this.codeDescriptionCache.set(item.Modifier__c, details.description);
                            }
                        } catch (error) {
                            console.error('Error fetching modifier description:', error);
                        }
                    }
                    enriched.modifierCodeDescription = this.codeDescriptionCache.get(item.Modifier__c) || '';

                    return enriched;
                })
            );

            // MVADM-155 QC FIX: Merge enriched real items with draft row
            const draftRow = this.lineItems.find(item => item.Id === 'draft-row-temp');
            this.lineItems = draftRow ? [...enrichedItems, draftRow] : enrichedItems;

            console.log('TRINITY: Enriched first item:', {
                revenueCode: this.lineItems[0]?.Revenue_Code__c,
                revenueDesc: this.lineItems[0]?.revenueCodeDescription,
                cptCode: this.lineItems[0]?.CPT_HCPCS_NDC__c,
                cptDesc: this.lineItems[0]?.cptCodeDescription
            });

            // Generate tooltip content with enriched descriptions
            this.generateTooltipContent();

        } catch (error) {
            console.error('TRINITY ERROR: enriching code descriptions:', error);
            // Graceful degradation - generate tooltips without descriptions
            this.generateTooltipContent();
        }
    }

    // TRINITY TOOLTIP ENHANCEMENT: Generate formatted tooltip content for collapsed columns
    generateTooltipContent() {
        console.log('TRINITY: Generating tooltip content for', this.lineItems.length, 'items');

        this.lineItems = this.lineItems.map(item => {
            const tooltipContent = this.formatCodesDescriptionTooltip({
                revenue: { code: item.Revenue_Code__c, desc: item.revenueCodeDescription },
                pos: { code: item.Place_of_Service__c, desc: item.posCodeDescription },
                cpt: { code: item.CPT_HCPCS_NDC__c, desc: item.cptCodeDescription },
                modifier: { code: item.Modifier__c, desc: item.modifierCodeDescription }
            });

            console.log('TRINITY: Tooltip for item', item.Id, ':', tooltipContent.substring(0, 100));

            return {
                ...item,
                codesDescriptionTooltip: tooltipContent
            };
        });
    }

    // TRINITY TOOLTIP ENHANCEMENT: Professional tooltip content formatter
    formatCodesDescriptionTooltip(codes) {
        console.log('TRINITY: Formatting tooltip with codes:', codes);

        const rows = [];

        if (codes.revenue.code) {
            rows.push(`
                <div class="tooltip-row">
                    <strong>Revenue Code:</strong> ${codes.revenue.code}<br>
                    <span class="tooltip-desc">${codes.revenue.desc || 'No description available'}</span>
                </div>
            `);
        }

        if (codes.pos.code) {
            rows.push(`
                <div class="tooltip-row">
                    <strong>Place of Service:</strong> ${codes.pos.code}<br>
                    <span class="tooltip-desc">${codes.pos.desc || 'No description available'}</span>
                </div>
            `);
        }

        if (codes.cpt.code) {
            rows.push(`
                <div class="tooltip-row">
                    <strong>CPT/HCPCS/NDC:</strong> ${codes.cpt.code}<br>
                    <span class="tooltip-desc">${codes.cpt.desc || 'No description available'}</span>
                </div>
            `);
        }

        if (codes.modifier.code) {
            rows.push(`
                <div class="tooltip-row">
                    <strong>Modifier:</strong> ${codes.modifier.code}<br>
                    <span class="tooltip-desc">${codes.modifier.desc || 'No description available'}</span>
                </div>
            `);
        }

        if (rows.length === 0) {
            console.log('TRINITY: No rows generated - returning empty message');
            return '<div class="tooltip-content">No code information available</div>';
        }

        const result = `<div class="tooltip-content">${rows.join('')}</div>`;
        console.log('TRINITY: Generated tooltip HTML length:', result.length);
        return result;
    }

    // MVADM-155 QC FIX: Enrich code descriptions for a single newly created item
    // TRINITY: Reusable method to avoid code duplication
    async enrichSingleItemDescriptions(item) {
        try {
            console.log('TRINITY: Enriching single item descriptions for:', item.Id);

            // Fetch Revenue Code description
            if (item.Revenue_Code__c && !this.codeDescriptionCache.has(item.Revenue_Code__c)) {
                try {
                    const details = await getCodeDetails({
                        codeName: item.Revenue_Code__c,
                        codeTypes: ['RevenueCodes']
                    });
                    if (details?.description) {
                        this.codeDescriptionCache.set(item.Revenue_Code__c, details.description);
                    }
                } catch (error) {
                    console.error('Error fetching revenue code description:', error);
                }
            }

            // Fetch POS description
            if (item.Place_of_Service__c && !this.codeDescriptionCache.has(item.Place_of_Service__c)) {
                try {
                    const details = await getCodeDetails({
                        codeName: item.Place_of_Service__c,
                        codeTypes: ['PlaceOfService']
                    });
                    if (details?.description) {
                        this.codeDescriptionCache.set(item.Place_of_Service__c, details.description);
                    }
                } catch (error) {
                    console.error('Error fetching POS description:', error);
                }
            }

            // Fetch Modifier description
            if (item.Modifier__c && !this.codeDescriptionCache.has(item.Modifier__c)) {
                try {
                    const details = await getCodeDetails({
                        codeName: item.Modifier__c,
                        codeTypes: ['Modifiers']
                    });
                    if (details?.description) {
                        this.codeDescriptionCache.set(item.Modifier__c, details.description);
                    }
                } catch (error) {
                    console.error('Error fetching modifier description:', error);
                }
            }

            // Update item in lineItems array with enriched descriptions
            this.lineItems = this.lineItems.map(i => {
                if (i.Id === item.Id) {
                    const revenueDesc = this.codeDescriptionCache.get(item.Revenue_Code__c) || '';
                    const posDesc = this.codeDescriptionCache.get(item.Place_of_Service__c) || '';
                    const modifierDesc = this.codeDescriptionCache.get(item.Modifier__c) || '';

                    return {
                        ...i,
                        revenueCodeDescription: revenueDesc,
                        posCodeDescription: posDesc,
                        modifierCodeDescription: modifierDesc,
                        codesDescriptionTooltip: this.formatCodesDescriptionTooltip({
                            revenue: { code: i.Revenue_Code__c, desc: revenueDesc },
                            pos: { code: i.Place_of_Service__c, desc: posDesc },
                            cpt: { code: i.CPT_HCPCS_NDC__c, desc: i.cptCodeDescription },
                            modifier: { code: i.Modifier__c, desc: modifierDesc }
                        })
                    };
                }
                return i;
            });

            console.log('TRINITY: Successfully enriched single item:', item.Id);

        } catch (error) {
            console.error('TRINITY ERROR: enriching single item descriptions:', error);
            // Graceful degradation - item will have empty descriptions
        }
    }

    // TRINITY: Event handlers - simple and direct
    handleStageChange(event) {
        this.currentStage = event.detail.value;
    }

    handleSelectAll(event) {
        const isChecked = event.target.checked;
        if (isChecked) {
            this.selectedIds = new Set(this.lineItems.map(item => item.Id));
        } else {
            this.selectedIds = new Set();
        }
        // Update selection state in line items
        this.lineItems = this.lineItems.map(item => ({
            ...item,
            selected: isChecked
        }));
    }

    handleRowSelect(event) {
        const rowId = event.target.dataset.rowId;
        const isChecked = event.target.checked;

        // TRINITY PHASE 2: Immutable Set pattern for LWC reactivity
        if (isChecked) {
            this.selectedIds = new Set([...this.selectedIds, rowId]);
        } else {
            const newSet = new Set(this.selectedIds);
            newSet.delete(rowId);
            this.selectedIds = newSet;
        }

        // Update selection state in line items
        this.lineItems = this.lineItems.map(item => ({
            ...item,
            selected: item.Id === rowId ? isChecked : item.selected
        }));
    }

    // Expandable column toggles - SIMPLE boolean flips
    toggleServiceDates() {
        this.serviceDatesExpanded = !this.serviceDatesExpanded;
    }

    toggleCodes() {
        this.codesExpanded = !this.codesExpanded;
    }

    toggleRemarkCodes() {
        this.remarkCodesExpanded = !this.remarkCodesExpanded;
    }

    // TRINITY: Field editing handlers - simple and direct
    async handleFieldChange(event) {
        const fieldName = event.target.dataset.field;
        const rowId = event.target.dataset.rowId;
        let newValue = event.target.value;

        // MVADM-155: Delegate to draft row handler if this is the draft row
        if (rowId === 'draft-row-temp') {
            await this.handleDraftFieldChange(event);
            return;
        }

        // TRINITY: X3rd_Party_Curr__c is Currency field, no conversion needed

        // Update line items data
        this.lineItems = this.lineItems.map(item => {
            if (item.Id === rowId) {
                const updatedItem = { ...item, [fieldName]: newValue };

                // TRINITY v2.7.3: Update formatted dates when date fields change
                if (fieldName === 'Service_Start_Date__c') {
                    updatedItem.formattedStartDate = newValue; // User entered value (already formatted)
                } else if (fieldName === 'Service_End_Date__c') {
                    updatedItem.formattedEndDate = newValue; // User entered value (already formatted)
                }

                return updatedItem;
            }
            return item;
        });

        // TRINITY: Auto-save the field change immediately
        await this.autoSaveField(rowId, fieldName, newValue);

        // TRINITY: Auto-populate description when code fields change
        if (this.isCodeField(fieldName) && newValue) {
            await this.updateDescriptionFromCode(rowId, newValue);
        }
    }

    // TRINITY: Auto-save helper method - reusable for all field changes
    async autoSaveField(rowId, fieldName, newValue) {
        try {
            // SAGE RESEARCH: Debug logging to verify actual data being sent
            const fullLineItem = this.lineItems.find(item => item.Id === rowId);
            console.log('=== SAGE DEBUG: autoSaveField START ===');
            console.log('Field being updated:', fieldName);
            console.log('New value:', newValue);
            console.log('Row ID:', rowId);
            console.log('Full lineItem data from this.lineItems:', JSON.stringify(fullLineItem, null, 2));
            console.log('Approved_Amount__c in full data:', fullLineItem?.Approved_Amount__c);

            // Create update record with only the changed field
            const updateRecord = {
                Id: rowId,
                [fieldName]: newValue
            };

            console.log('Update record being sent to Apex:', JSON.stringify(updateRecord, null, 2));
            console.log('=== SAGE DEBUG: Calling Apex updateBillLineItems ===');

            // TRINITY: Call Apex with correct parameter structure for @AuraEnabled method
            await updateBillLineItems({ lineItems: [updateRecord] });

            console.log('=== SAGE DEBUG: Apex call successful ===');
            console.log('Successfully auto-saved:', fieldName, 'for row:', rowId);

        } catch (error) {
            console.error('Error auto-saving field:', error);

            // Show error toast for failed saves
            this.dispatchEvent(new ShowToastEvent({
                title: 'Save Error',
                message: `Failed to save ${fieldName}: ${error.body?.message || error.message}`,
                variant: 'error'
            }));

            // Revert the field value in the UI
            const originalItem = this.lineItems.find(item => item.Id === rowId);
            if (originalItem) {
                this.lineItems = this.lineItems.map(item => {
                    if (item.Id === rowId) {
                        return { ...item, [fieldName]: originalItem[fieldName] };
                    }
                    return item;
                });
            }
        }
    }

    // MVADM-155: Handle field changes in draft row (manual entry)
    // TRINITY AUTO-REGEN: Create new draft row immediately when current draft is saved
    async handleDraftFieldChange(event) {
        const fieldName = event.target.dataset.field;
        let newValue = event.target.value;

        console.log('TRINITY DEBUG: Draft field changed:', fieldName, '=', newValue);

        // TRINITY: X3rd_Party_Curr__c is Currency field, no conversion needed

        // CRITICAL: Update BOTH draftRow object AND lineItems array for display
        this.draftRow = { ...this.draftRow, [fieldName]: newValue };

        // TRINITY v2.7.3: Update formatted dates when date fields change in draft row
        if (fieldName === 'Service_Start_Date__c') {
            this.draftRow.formattedStartDate = newValue;
        } else if (fieldName === 'Service_End_Date__c') {
            this.draftRow.formattedEndDate = newValue;
        }

        // Update draft row in lineItems array so UI reflects changes
        this.lineItems = this.lineItems.map(item => {
            if (item.Id === 'draft-row-temp') {
                const updatedItem = { ...item, [fieldName]: newValue };

                // TRINITY v2.7.3: Update formatted dates in lineItems array too
                if (fieldName === 'Service_Start_Date__c') {
                    updatedItem.formattedStartDate = newValue;
                } else if (fieldName === 'Service_End_Date__c') {
                    updatedItem.formattedEndDate = newValue;
                }

                return updatedItem;
            }
            return item;
        });

        // MVADM-155: Check if ANY meaningful field has data (trigger save on first entry)
        // CRITICAL: Check ALL fields to ensure code selections trigger save
        // TRINITY v3.1.0: Added Account__c to trigger save when account is selected
        const hasAnyData = this.draftRow.Service_Start_Date__c ||
                          this.draftRow.Service_End_Date__c ||
                          this.draftRow.Revenue_Code__c ||
                          this.draftRow.CPT_HCPCS_NDC__c ||
                          this.draftRow.Place_of_Service__c ||
                          this.draftRow.Modifier__c ||
                          this.draftRow.Charge__c ||
                          this.draftRow.Quantity__c ||
                          this.draftRow.Description__c ||
                          this.draftRow.Account__c ||
                          this.draftRow.Remark_Code_1__c ||
                          this.draftRow.Remark_Code_2__c ||
                          this.draftRow.Remark_Code_3__c ||
                          this.draftRow.Remark_Code_4__c ||
                          this.draftRow.Approved_Amount__c ||
                          this.draftRow.Paid_Amount__c ||
                          this.draftRow.X3rd_Party_Curr__c ||
                          this.draftRow.Deductible__c ||
                          this.draftRow.Copay__c ||
                          this.draftRow.Coinsurance__c;

        // TRINITY AUTO-REGEN: If draft has data and is still a draft, save it and create new draft immediately
        if (hasAnyData && this.draftRow.isDraft) {
            console.log('TRINITY DEBUG: Draft row has data, creating new line item...');

            // CRITICAL: Ensure we have Bill__c ID
            if (!this.billId) {
                this.showToast('Error', 'Bill ID not available. Cannot create line item.', 'error');
                return;
            }

            // STEP 1: Capture current draft data for save (BEFORE creating new draft)
            const savingRowData = { ...this.draftRow };
            console.log('TRINITY DEBUG: Captured draft data:', JSON.stringify(savingRowData, null, 2));

            // STEP 2: Create new EMPTY draft row IMMEDIATELY (user can start typing right away)
            this.initializeDraftRow();

            // STEP 3: Remove old draft from lineItems, add "saving" placeholder, append new EMPTY draft
            this.lineItems = this.lineItems.filter(item => item.Id !== 'draft-row-temp');

            // Add "saving" placeholder with captured data
            this.lineItems = [...this.lineItems, {
                ...savingRowData,
                Id: 'saving-row-temp',
                isDraft: false,
                lineNumber: '' // Will be populated when save completes
            }];

            // STEP 3.5: CRITICAL - Clear the input field value and remove focus
            // Clear value to prevent duplication in new draft row
            // Remove focus to prevent browser from jumping to new draft row during re-render
            if (event.target) {
                event.target.value = '';
                event.target.blur(); // Remove focus before re-render
            }

            // Append new EMPTY draft row (this.draftRow is now empty from initializeDraftRow)
            this.lineItems = [...this.lineItems, this.draftRow];
            console.log('TRINITY DEBUG: Created new EMPTY draft row, total items:', this.lineItems.length);

            // STEP 4: Save in background (async - user can continue typing)
            try {
                const newItem = await createBillLineItem({
                    billId: this.billId,
                    draftItem: savingRowData
                });

                console.log('TRINITY DEBUG: Successfully created line item:', newItem.Id);
                console.log('TRINITY DEBUG: Line number assigned:', newItem.Bill_Line_Item_Number__c);

                // STEP 5: Process new item with line number from Apex
                const processedItem = {
                    ...newItem,
                    selected: false,
                    lineNumber: newItem.Bill_Line_Item_Number__c || '',
                    accountName: newItem.Bill__r?.Member_Account__r?.Name || '',
                    formattedStartDate: this.formatDate(newItem.Service_Start_Date__c),
                    formattedEndDate: this.formatDate(newItem.Service_End_Date__c),
                    formattedCharge: this.formatCurrency(newItem.Charge__c),
                    formattedOIAllow: this.formatCurrency(newItem.Other_Ins_Allowed__c),
                    formattedOIPaid: this.formatCurrency(newItem.Other_Ins_Paid__c),
                    formattedPaid: this.formatCurrency(newItem.Approved_Amount__c),
                    formattedThirdParty: this.formatCurrency(newItem.X3rd_Party_Curr__c),
                    formattedPatResp: this.formatCurrency(newItem.Patient_Responsibility__c),
                    medicareStatus: newItem.Code__r?.Medicare_Covered__c || 'TBD',
                    medicareStatusValue: newItem.Code__r?.Medicare_Covered__c || 'TBD',
                    medicareStatusYes: newItem.Code__r?.Medicare_Covered__c === 'Yes',
                    medicareStatusNo: newItem.Code__r?.Medicare_Covered__c === 'No',
                    medicareStatusReview: newItem.Code__r?.Medicare_Covered__c === 'Review',
                    medicareStatusTBD: newItem.Code__r?.Medicare_Covered__c === 'TBD' || !newItem.Code__r?.Medicare_Covered__c,
                    medicareStatusDiscretion: newItem.Code__r?.Medicare_Covered__c === 'Discretion',
                    medicareStatusTooltip: this.getMedicareTooltip(newItem.Code__r?.Medicare_Covered__c),
                    isDuplicate: newItem.Duplicate_Status__c && newItem.Duplicate_Status__c !== 'None',
                    duplicateStatus: newItem.Duplicate_Status__c,
                    duplicateStatusLabel: this.getDuplicateStatusLabel(newItem.Duplicate_Status__c),
                    revenueCode: newItem.Revenue_Code__c || '',
                    revenueCodeDescription: '',
                    revenueCodeDisplay: newItem.Revenue_Code__c || '',
                    posCode: newItem.Place_of_Service__c || '',
                    posCodeDescription: '',
                    posDisplay: newItem.Place_of_Service__c || '',
                    cptCode: newItem.CPT_HCPCS_NDC__c || '',
                    cptCodeDescription: newItem.Code__r?.Description__c || '',
                    cptDisplay: newItem.CPT_HCPCS_NDC__c || '',
                    modifierCode: newItem.Modifier__c || '',
                    modifierCodeDescription: '',
                    modifierDisplay: newItem.Modifier__c || '',
                    remarkCode1Display: newItem.Remark_Code_1__c || '',
                    remarkCode2Display: newItem.Remark_Code_2__c || '',
                    remarkCode3Display: newItem.Remark_Code_3__c || '',
                    remarkCode4Display: newItem.Remark_Code_4__c || '',
                    codesDescriptionTooltip: '',
                    validationStatus: 'valid',
                    validationErrors: [],
                    validationWarnings: [],
                    rowClass: 'grid-row row-valid'
                };

                // STEP 6: Replace "saving-row-temp" with real row (line number now visible!)
                this.lineItems = this.lineItems.map(item => {
                    if (item.Id === 'saving-row-temp') {
                        return processedItem;
                    }
                    return item;
                });

                console.log('TRINITY DEBUG: Replaced saving row with real row. Line number:', processedItem.lineNumber);

                // STEP 7: Enrich code descriptions for newly created item
                await this.enrichSingleItemDescriptions(processedItem);

                // Show success toast with line number
                this.showToast('Success', `Line item ${processedItem.lineNumber} created`, 'success');

            } catch (error) {
                console.error('TRINITY ERROR: Failed to create line item:', error);

                // ROLLBACK: Remove new draft, restore saving row as draft
                this.lineItems = this.lineItems.filter(item => item.Id !== 'draft-row-temp');
                this.draftRow = {
                    ...savingRowData,
                    Id: 'draft-row-temp',
                    isDraft: true
                };
                this.lineItems = [...this.lineItems, this.draftRow];

                this.showToast('Error', 'Failed to create line item: ' + (error.body?.message || error.message), 'error');
            }
        }
    }

    // MVADM-155: Handle Enter key for vertical navigation (Tab is browser default for horizontal)
    handleKeyDown(event) {
        if (event.key === 'Enter') {
            event.preventDefault(); // Prevent form submission

            const currentField = event.target;
            const fieldName = currentField.dataset.field;

            // Find all fields with the same field name (same column)
            const allFields = this.template.querySelectorAll(`[data-field="${fieldName}"]`);
            const currentIndex = Array.from(allFields).indexOf(currentField);

            console.log('TRINITY DEBUG: Enter pressed on field:', fieldName, 'Moving from row', currentIndex, 'to row', currentIndex + 1);

            // Move to same field in next row
            if (currentIndex < allFields.length - 1) {
                allFields[currentIndex + 1].focus();
            } else {
                // On last row (draft row), stay on draft row field
                console.log('TRINITY DEBUG: Already on last row (draft row), staying in place');
            }
        }
    }

    // TRINITY: Check if field is a code field that should trigger description lookup
    isCodeField(fieldName) {
        return ['Revenue_Code__c', 'Place_of_Service__c', 'CPT_HCPCS_NDC__c', 'Remark_Code_1__c', 'Remark_Code_2__c', 'Remark_Code_3__c', 'Remark_Code_4__c'].includes(fieldName);
    }

    // TRINITY PHASE 3: Prevent default context menu on entire grid
    // This ensures ONLY our custom context menus appear, no browser defaults
    preventDefaultContextMenu(event) {
        // Only prevent default if we're NOT on a field with our custom handler
        // (our custom handlers will call preventDefault themselves)
        const hasCustomHandler = event.target.closest('[data-field-name]');
        if (!hasCustomHandler) {
            event.preventDefault();
            console.log('🚫 Default context menu prevented on grid container');
        }
    }

    // TRINITY PHASE 2: Right-click context menu for bulk operations
    // Handles right-click on RC1-4 fields to show bulk assignment menu
    handleRightClick(event) {
        event.preventDefault(); // Prevent browser context menu
        event.stopPropagation(); // Stop event from bubbling to container

        const fieldName = event.currentTarget.dataset.fieldName;
        const rowId = event.currentTarget.dataset.rowId;

        // Close existing menu if clicking on different cell
        if (this.showContextMenu &&
            (this.contextMenuField !== fieldName || this.contextMenuRowId !== rowId)) {
            this.showContextMenu = false;
        }

        // Get current value from the row
        const currentItem = this.lineItems.find(item => item.Id === rowId);
        const currentValue = currentItem ? currentItem[fieldName] : '';

        // TRINITY UX: Calculate smart positioning to keep menu in viewport
        const menuWidth = 320;
        const menuHeight = this.isPaymentField(fieldName) ? 450 : 200;

        let x = event.clientX;
        let y = event.clientY;

        // Adjust X position if menu would overflow right edge
        if (x + menuWidth > window.innerWidth) {
            x = window.innerWidth - menuWidth - 10;
        }

        // Adjust Y position if menu would overflow bottom edge
        if (y + menuHeight > window.innerHeight) {
            y = window.innerHeight - menuHeight - 10;
        }

        // Ensure menu doesn't go off left or top edges
        x = Math.max(10, x);
        y = Math.max(10, y);

        console.log('🖱️ Right-click detected:', {
            fieldName,
            rowId,
            currentValue,
            originalX: event.clientX,
            originalY: event.clientY,
            adjustedX: x,
            adjustedY: y
        });

        // Show context menu at adjusted position
        this.showBulkOperationsMenu(fieldName, rowId, currentValue, x, y);
    }

    // TRINITY PHASE 3: Check if field is a payment field
    isPaymentField(fieldName) {
        return ['Approved_Amount__c', 'X3rd_Party_Curr__c', 'Patient_Responsibility__c'].includes(fieldName);
    }

    // TRINITY DEFENSIVE: Safe conversion for X3rd_Party__c (TEXT field)
    safeConvertToDecimalString(value) {
        if (value === null || value === undefined || value === '') {
            return '0.00';
        }
        // Remove non-numeric characters except decimal point and minus sign
        const cleaned = String(value).replace(/[^0-9.-]/g, '');
        const decimal = parseFloat(cleaned);
        if (isNaN(decimal)) {
            return '0.00';
        }
        return decimal.toFixed(2);
    }

    // TRINITY DEFENSIVE: Safe blank checking for mixed types
    isFieldBlank(value) {
        if (value === null || value === undefined) {
            return true;
        }
        // Handle string values
        if (typeof value === 'string') {
            return value.trim() === '';
        }
        // Handle number values (0 is NOT blank for our purposes)
        if (typeof value === 'number') {
            return false;
        }
        return true;
    }

    // TRINITY PHASE 2: Show bulk operations context menu
    showBulkOperationsMenu(fieldName, rowId, currentValue, x, y) {
        this.contextMenuField = fieldName;
        this.contextMenuRowId = rowId;
        this.contextMenuValue = currentValue;
        this.contextMenuX = x;
        this.contextMenuY = y;

        // TRINITY PHASE 3: Determine context menu type based on field
        if (this.isPaymentField(fieldName)) {
            this.contextMenuType = 'payment';
            this.paymentApplyTo = 'allRows'; // Default for payment menu
            this.selectedPaymentOperation = 'percentage'; // Default to percentage
            this.paymentPercentage = 80; // Default 80%
        } else {
            this.contextMenuType = 'simple';
            this.contextMenuApplyTo = 'all'; // Default for simple menu
            this.followingRowsCount = 1; // Default to 1
        }

        this.showContextMenu = true;

        console.log('✅ Context menu shown at', x, y, 'Type:', this.contextMenuType);
    }

    // TRINITY PHASE 2: Close context menu
    closeContextMenu() {
        this.showContextMenu = false;
        this.contextMenuField = null;
        this.contextMenuRowId = null;
        this.contextMenuValue = null;
        this.contextMenuX = 0;
        this.contextMenuY = 0;
        console.log('❌ Context menu closed');
    }

    // TRINITY UX: Prevent context menu from closing on internal clicks
    handleContextMenuClick(event) {
        event.stopPropagation();
    }

    // TRINITY UX: Close menu when clicking outside
    handleDocumentClick(event) {
        const menu = this.template.querySelector('.context-menu');
        if (menu && !menu.contains(event.target)) {
            this.closeContextMenu();
        }
    }

    // TRINITY PHASE 2: Stop event propagation for context menu clicks
    stopPropagation(event) {
        event.stopPropagation();
    }

    // TRINITY UX: Handle drag start for context menu
    handleDragStart(event) {
        event.preventDefault();
        event.stopPropagation();

        this.isDragging = true;
        this.dragStartX = event.clientX;
        this.dragStartY = event.clientY;
        this.dragOffsetX = this.contextMenuX;
        this.dragOffsetY = this.contextMenuY;

        // Add document-level event listeners for drag
        document.addEventListener('mousemove', this.handleDragMove.bind(this));
        document.addEventListener('mouseup', this.handleDragEnd.bind(this));

        console.log('🖱️ Drag started at:', { x: event.clientX, y: event.clientY });
    }

    // TRINITY UX: Handle drag move for context menu
    handleDragMove(event) {
        if (!this.isDragging) return;

        event.preventDefault();

        // Calculate new position
        const deltaX = event.clientX - this.dragStartX;
        const deltaY = event.clientY - this.dragStartY;

        let newX = this.dragOffsetX + deltaX;
        let newY = this.dragOffsetY + deltaY;

        // Get viewport dimensions
        const viewportWidth = window.innerWidth;
        const viewportHeight = window.innerHeight;

        // Get menu dimensions (estimate based on type)
        const menuWidth = this.contextMenuType === 'payment' ? 450 : 320;
        const menuHeight = this.contextMenuType === 'payment' ? 400 : 250;

        // Constrain to viewport bounds
        newX = Math.max(0, Math.min(newX, viewportWidth - menuWidth));
        newY = Math.max(0, Math.min(newY, viewportHeight - menuHeight));

        // Update position
        this.contextMenuX = newX;
        this.contextMenuY = newY;

        console.log('🖱️ Dragging to:', { x: newX, y: newY });
    }

    // TRINITY UX: Handle drag end for context menu
    handleDragEnd(event) {
        if (!this.isDragging) return;

        event.preventDefault();
        this.isDragging = false;

        // Remove document-level event listeners
        document.removeEventListener('mousemove', this.handleDragMove.bind(this));
        document.removeEventListener('mouseup', this.handleDragEnd.bind(this));

        console.log('🖱️ Drag ended at:', { x: this.contextMenuX, y: this.contextMenuY });
    }

    // TRINITY PHASE 2: Handle "Apply to all rows" option
    handleApplyToAll() {
        console.log('📋 Apply to all rows selected');
        this.applyBulkOperation('all', null);
        this.closeContextMenu();
    }

    // TRINITY PHASE 2: Handle "Apply to blank rows only" option
    handleApplyToBlank() {
        console.log('📋 Apply to blank rows only selected');
        this.applyBulkOperation('blank', null);
        this.closeContextMenu();
    }

    // TRINITY PHASE 2: Handle "Apply to following rows" option
    async handleApplyToFollowing() {
        console.log('📋 Apply to following rows selected');

        // Prompt user for number of rows
        const count = await this.promptForRowCount();
        if (count) {
            this.applyBulkOperation('following', count);
        }
        this.closeContextMenu();
    }

    // TRINITY PHASE 2: Prompt for row count (simple implementation)
    async promptForRowCount() {
        // For now, use a simple prompt. Can be replaced with a modal later.
        const input = prompt('How many rows (including current)?', '1');
        if (input === null) return null; // User cancelled

        const count = parseInt(input, 10);
        if (isNaN(count) || count < 1) {
            alert('Please enter a valid number greater than 0');
            return null;
        }
        if (count > 100) {
            alert('Maximum 100 rows allowed');
            return null;
        }
        return count;
    }

    // TRINITY PHASE 2: Apply bulk operation to rows
    async applyBulkOperation(scope, count) {
        const fieldName = this.contextMenuField;
        const value = this.contextMenuValue;
        const currentRowId = this.contextMenuRowId;

        console.log('🚀 Applying bulk operation:', { scope, count, fieldName, value, currentRowId });

        let rowsToUpdate = [];

        if (scope === 'all') {
            // Apply to ALL rows (override existing values)
            rowsToUpdate = this.lineItems.map(item => item.Id);
            console.log(`✅ Applying to ALL ${rowsToUpdate.length} rows`);

        } else if (scope === 'blank') {
            // Apply to BLANK rows only (skip populated rows)
            rowsToUpdate = this.lineItems
                .filter(item => this.isFieldBlank(item[fieldName]))
                .map(item => item.Id);
            console.log(`✅ Applying to ${rowsToUpdate.length} BLANK rows`);

        } else if (scope === 'following') {
            // Apply to FOLLOWING X rows (including current)
            const currentIndex = this.lineItems.findIndex(item => item.Id === currentRowId);
            if (currentIndex !== -1) {
                rowsToUpdate = this.lineItems
                    .slice(currentIndex, currentIndex + count)
                    .map(item => item.Id);
                console.log(`✅ Applying to ${rowsToUpdate.length} FOLLOWING rows (starting from row ${currentIndex + 1})`);
            }
        }

        if (rowsToUpdate.length === 0) {
            alert('No rows to update');
            return;
        }

        // TRINITY: Convert value to proper type for field
        let valueToSave = value;

        // Convert payment fields to proper format (all Currency fields now)
        if (this.isPaymentField(fieldName)) {
            // All payment fields are Currency, save as numbers
            valueToSave = parseFloat(value) || 0.0;
        }

        // Save to database FIRST
        try {
            // TRINITY FIX MVADM-107: Send FULL records with ALL fields to prevent zeroing out other fields
            // BUG: Sending partial records ({Id, fieldName}) causes Salesforce to NULL all other fields
            // FIX: Find the full record and update only the specified field using spread operator
            const recordsToUpdate = rowsToUpdate.map(rowId => {
                const fullRecord = this.lineItems.find(item => item.Id === rowId);
                if (!fullRecord) {
                    console.error('TRINITY ERROR: Could not find record with Id:', rowId);
                    return { Id: rowId, [fieldName]: valueToSave };
                }

                // Return full record with updated field value
                return {
                    Id: fullRecord.Id,
                    Service_Start_Date__c: fullRecord.Service_Start_Date__c,
                    Service_End_Date__c: fullRecord.Service_End_Date__c,
                    Revenue_Code__c: fullRecord.Revenue_Code__c,
                    Place_of_Service__c: fullRecord.Place_of_Service__c,
                    CPT_HCPCS_NDC__c: fullRecord.CPT_HCPCS_NDC__c,
                    Modifier__c: fullRecord.Modifier__c,
                    Quantity__c: fullRecord.Quantity__c,
                    Charge__c: fullRecord.Charge__c,
                    Other_Ins_Allowed__c: fullRecord.Other_Ins_Allowed__c,
                    Other_Ins_Paid__c: fullRecord.Other_Ins_Paid__c,
                    Approved_Amount__c: fullRecord.Approved_Amount__c,
                    Patient_Responsibility__c: fullRecord.Patient_Responsibility__c,
                    X3rd_Party_Curr__c: fullRecord.X3rd_Party_Curr__c,
                    Adjustment_Amount__c: fullRecord.Adjustment_Amount__c,
                    Savings_Fee__c: fullRecord.Savings_Fee__c,
                    Description__c: fullRecord.Description__c,
                    Code__c: fullRecord.Code__c,
                    Account__c: fullRecord.Account__c,
                    Remark_Code_1__c: fullRecord.Remark_Code_1__c,
                    Remark_Code_2__c: fullRecord.Remark_Code_2__c,
                    Remark_Code_3__c: fullRecord.Remark_Code_3__c,
                    Remark_Code_4__c: fullRecord.Remark_Code_4__c,
                    Bill__c: fullRecord.Bill__c,
                    // Override the specific field being updated
                    [fieldName]: valueToSave
                };
            });

            console.log('💾 Saving to database:', recordsToUpdate);
            await updateBillLineItems({ lineItems: recordsToUpdate });

            console.log('🔄 Refreshing grid data from server...');

            // Refresh data from server
            await refreshApex(this.wiredLineItemsResult);

            // Force re-process of line items to ensure UI updates
            if (this.wiredLineItemsResult.data) {
                console.log('🔄 Re-processing line items to force UI update...');
                this.processLineItems(this.wiredLineItemsResult.data);
            }

            this.showToast('Success', `Updated ${rowsToUpdate.length} row(s)`, 'success');
            console.log(`✅ Successfully updated ${rowsToUpdate.length} rows and refreshed grid`);

        } catch (error) {
            console.error('❌ Error updating rows:', error);
            this.showToast('Error', 'Failed to update rows: ' + error.body.message, 'error');
        }
    }

    // TRINITY PHASE 3: Payment context menu handlers
    handlePaymentOperationChange(event) {
        this.selectedPaymentOperation = event.detail.value;
        console.log('💰 Payment operation changed to:', this.selectedPaymentOperation);
    }

    handlePaymentPercentageChange(event) {
        this.paymentPercentage = parseFloat(event.detail.value);
        console.log('💰 Payment percentage changed to:', this.paymentPercentage);
    }

    handlePaymentFixedAmountChange(event) {
        this.paymentFixedAmount = parseFloat(event.detail.value);
        console.log('💰 Payment fixed amount changed to:', this.paymentFixedAmount);
    }

    handlePaymentApplyToChange(event) {
        this.paymentApplyTo = event.detail.value;
        console.log('💰 Payment apply to changed to:', this.paymentApplyTo);
    }

    handleFollowingRowsChange(event) {
        this.followingRowsCount = parseInt(event.detail.value, 10);
        console.log('💰 Following rows count changed to:', this.followingRowsCount);
    }

    // TRINITY PHASE 3: Apply payment bulk operation
    // MVADM-155 CRITICAL FIX: Filter out draft row to prevent MALFORMED_ID errors
    async applyPaymentBulkOperation() {
        try {
            const fieldName = this.contextMenuField;
            const currentRowId = this.contextMenuRowId;

            console.log('🚀 Applying payment bulk operation:', {
                field: fieldName,
                operation: this.selectedPaymentOperation,
                percentage: this.paymentPercentage,
                fixedAmount: this.paymentFixedAmount,
                applyTo: this.paymentApplyTo
            });

            // MVADM-155 CRITICAL FIX: Filter out draft row before bulk operations
            const realItems = this.lineItems.filter(item => item.Id !== 'draft-row-temp');

            // 1. Determine which rows to update
            let rowsToUpdate = [];

            if (this.paymentApplyTo === 'allRows') {
                // Apply to ALL real rows (exclude draft)
                rowsToUpdate = realItems;
                console.log(`✅ Applying to ALL ${rowsToUpdate.length} rows (excluding draft)`);

            } else if (this.paymentApplyTo === 'blankRows') {
                // Apply to BLANK real rows only (no value or zero, exclude draft)
                rowsToUpdate = realItems.filter(item => {
                    const value = parseFloat(item[fieldName]) || 0;
                    return value === 0;
                });
                console.log(`✅ Applying to ${rowsToUpdate.length} BLANK rows (excluding draft)`);

            } else if (this.paymentApplyTo === 'followingRows') {
                // Apply to FOLLOWING X real rows (including current, exclude draft)
                const currentIndex = realItems.findIndex(item => item.Id === currentRowId);
                if (currentIndex !== -1) {
                    rowsToUpdate = realItems.slice(currentIndex, currentIndex + this.followingRowsCount);
                    console.log(`✅ Applying to ${rowsToUpdate.length} FOLLOWING rows (starting from row ${currentIndex + 1}, excluding draft)`);
                }
            }

            if (rowsToUpdate.length === 0) {
                this.showToast('Warning', 'No rows to update', 'warning');
                this.closeContextMenu();
                return;
            }

            // 2. Calculate new values based on operation type
            const recordsToUpdate = rowsToUpdate.map(item => {
                let newValue;

                if (this.selectedPaymentOperation === 'percentage') {
                    // Calculate percentage of Charge amount
                    const chargeAmount = parseFloat(item.Charge__c) || 0;
                    newValue = (chargeAmount * this.paymentPercentage) / 100;
                } else {
                    // Use fixed amount
                    newValue = this.paymentFixedAmount;
                }

                // Round to 2 decimal places
                newValue = Math.round(newValue * 100) / 100;

                return {
                    Id: item.Id,
                    [fieldName]: newValue
                };
            });

            console.log('💾 Saving payment updates to database:', recordsToUpdate);

            // 3. Save to database
            await updateBillLineItems({ lineItems: recordsToUpdate });

            console.log('🔄 Refreshing grid data from server...');

            // 4. Refresh data from server
            await refreshApex(this.wiredLineItemsResult);

            // Force re-process of line items to ensure UI updates
            if (this.wiredLineItemsResult.data) {
                console.log('🔄 Re-processing line items to force UI update...');
                this.processLineItems(this.wiredLineItemsResult.data);
            }

            this.showToast('Success', `Updated ${rowsToUpdate.length} row(s) with ${this.selectedPaymentOperation === 'percentage' ? this.paymentPercentage + '%' : '$' + this.paymentFixedAmount}`, 'success');
            console.log(`✅ Successfully updated ${rowsToUpdate.length} rows and refreshed grid`);

            this.closeContextMenu();

        } catch (error) {
            console.error('❌ Error applying payment bulk operation:', error);
            this.showToast('Error', 'Failed to update rows: ' + (error.body?.message || error.message), 'error');
        }
    }

    // TRINITY TOOLTIP ENHANCEMENT: Enhanced code selection handler with description caching
    // Updates both code value and cached description for tooltip display
    // MVADM-109: Auto-populate Description__c field when CPT/HCPCS/NDC code is selected
    // MVADM-155 CRITICAL FIX: Check for draft row before auto-save (prevent MALFORMED_ID error)
    async handleCodeSelected(event) {
        const { fieldName, codeName, description } = event.detail;
        const rowId = event.target.dataset.rowId;

        // TRINITY: Update code value AND cache description for tooltip
        this.lineItems = this.lineItems.map(item => {
            if (item.Id === rowId) {
                const updates = { [fieldName]: codeName };

                // Cache description based on field type
                if (fieldName === 'Revenue_Code__c') {
                    updates.revenueCode = codeName;
                    updates.revenueCodeDescription = description || '';
                } else if (fieldName === 'Place_of_Service__c') {
                    updates.posCode = codeName;
                    updates.posCodeDescription = description || '';
                } else if (fieldName === 'CPT_HCPCS_NDC__c') {
                    updates.cptCode = codeName;
                    updates.cptCodeDescription = description || '';
                    // MVADM-109: Auto-populate Description__c field from CPT/HCPCS/NDC code
                    if (description) {
                        updates.Description__c = description;
                    }
                } else if (fieldName === 'Place_of_Service__c') {
                    updates.posCode = codeName;
                    updates.posCodeDescription = description || '';
                } else if (fieldName === 'Modifier__c') {
                    updates.modifierCode = codeName;
                    updates.modifierCodeDescription = description || '';
                }

                return { ...item, ...updates };
            }
            return item;
        });

        // Regenerate tooltip content with updated descriptions
        this.generateTooltipContent();

        // MVADM-155 CRITICAL FIX: Skip auto-save for draft row (will be saved on first field entry)
        if (rowId === 'draft-row-temp') {
            console.log('TRINITY DEBUG: Code selected in draft row, updating draftRow object');

            // CRITICAL: Update draftRow object so hasAnyData check works
            this.draftRow = { ...this.draftRow, [fieldName]: codeName };
            if (fieldName === 'CPT_HCPCS_NDC__c' && description) {
                this.draftRow = { ...this.draftRow, Description__c: description };
            }

            // Show success message (no save needed)
            this.dispatchEvent(new ShowToastEvent({
                title: 'Code Selected',
                message: `${fieldName.replace('__c', '').replace('_', ' ')}: ${codeName}${description ? ' - ' + description : ''}`,
                variant: 'success'
            }));
            return;
        }

        // MVADM-109: Save code field AND Description__c field if CPT/HCPCS/NDC code was selected
        if (fieldName === 'CPT_HCPCS_NDC__c' && description) {
            // Save both fields in parallel
            await Promise.all([
                this.autoSaveField(rowId, fieldName, codeName),
                this.autoSaveField(rowId, 'Description__c', description)
            ]);
        } else {
            // Save ONLY the code field to database
            await this.autoSaveField(rowId, fieldName, codeName);
        }

        // Show success message
        this.dispatchEvent(new ShowToastEvent({
            title: 'Code Selected',
            message: `${fieldName.replace('__c', '').replace('_', ' ')}: ${codeName}${description ? ' - ' + description : ''}`,
            variant: 'success'
        }));
    }

    // TRINITY PHASE 2: Show Alt+Click bulk assignment modal
    // Called when user holds Alt and selects a code in RC1-4 or Account field
    showAltClickModal(rowId, fieldName, value, description) {
        this.altClickRowId = rowId;
        this.altClickField = fieldName;
        this.altClickValue = value;
        this.altClickValueDescription = description || '';
        this.altClickApplyTo = 'all'; // Default to 'all rows'
        this.followingRowsCount = 1; // Default to 1 row
        this.showAltClickModal = true;
    }

    // TRINITY PHASE 2: Handle radio group change for apply-to option
    handleAltClickApplyToChange(event) {
        this.altClickApplyTo = event.detail.value;
    }

    // TRINITY PHASE 2: Handle following rows count change
    handleFollowingRowsChange(event) {
        this.followingRowsCount = parseInt(event.detail.value, 10) || 1;
    }

    // TRINITY PHASE 2: Close Alt+Click modal and reset state
    closeAltClickModal() {
        this.showAltClickModal = false;
        this.altClickRowId = '';
        this.altClickField = '';
        this.altClickValue = '';
        this.altClickValueDescription = '';
        this.altClickApplyTo = 'all';
        this.followingRowsCount = 1;
    }

    // TRINITY PHASE 2: Getters for Alt+Click modal display

    // Radio group options for apply-to selection
    get altClickApplyToOptions() {
        return [
            { label: 'All rows (override existing values)', value: 'all' },
            { label: 'Only blank rows', value: 'blank' },
            { label: 'Following X rows (including current)', value: 'following' }
        ];
    }

    // Show/hide the "Number of rows" input based on selected option
    get showFollowingRowsInput() {
        return this.altClickApplyTo === 'following';
    }

    // Convert field API name to user-friendly label
    get altClickFieldLabel() {
        const fieldLabels = {
            'Remark_Code_1__c': 'Remark Code 1',
            'Remark_Code_2__c': 'Remark Code 2',
            'Remark_Code_3__c': 'Remark Code 3',
            'Remark_Code_4__c': 'Remark Code 4',
            'Account__c': 'Account'
        };
        return fieldLabels[this.altClickField] || this.altClickField;
    }

    // Format value with description for display
    get altClickValueLabel() {
        if (this.altClickValueDescription) {
            return `${this.altClickValue} - ${this.altClickValueDescription}`;
        }
        return this.altClickValue;
    }

    // Description text for modal
    get altClickActionDescription() {
        return 'Select how to apply this value to line items:';
    }

    // TRINITY PHASE 2: Apply bulk assignment based on selected option
    // MVADM-155 CRITICAL FIX: Filter out draft row to prevent MALFORMED_ID errors
    async applyAltClickBulkAssignment() {
        try {
            // MVADM-155 CRITICAL FIX: Filter out draft row before bulk operations
            const realItems = this.lineItems.filter(item => item.Id !== 'draft-row-temp');
            let itemsToUpdate = [];

            // STEP 1: Build itemsToUpdate array based on altClickApplyTo option
            if (this.altClickApplyTo === 'all') {
                // Apply to ALL real rows (override existing values, exclude draft)
                itemsToUpdate = realItems.map(item => ({
                    Id: item.Id,
                    [this.altClickField]: this.altClickValue
                }));
            } else if (this.altClickApplyTo === 'blank') {
                // Apply to ONLY blank real rows (preserve existing values, exclude draft)
                itemsToUpdate = realItems
                    .filter(item => !item[this.altClickField])
                    .map(item => ({
                        Id: item.Id,
                        [this.altClickField]: this.altClickValue
                    }));
            } else if (this.altClickApplyTo === 'following') {
                // Apply to current row + following X-1 real rows (exclude draft)
                const currentIndex = realItems.findIndex(item => item.Id === this.altClickRowId);
                if (currentIndex !== -1) {
                    const endIndex = Math.min(currentIndex + this.followingRowsCount, realItems.length);
                    itemsToUpdate = realItems
                        .slice(currentIndex, endIndex)
                        .map(item => ({
                            Id: item.Id,
                            [this.altClickField]: this.altClickValue
                        }));
                }
            }

            // STEP 2: Call Apex to update line items
            if (itemsToUpdate.length > 0) {
                await updateBillLineItems({ lineItems: itemsToUpdate });

                // STEP 3: Refresh grid data
                await refreshApex(this.wiredLineItemsResult);

                // STEP 4: Show success toast
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Bulk Assignment Complete',
                    message: `Applied ${this.altClickFieldLabel} to ${itemsToUpdate.length} row${itemsToUpdate.length !== 1 ? 's' : ''}`,
                    variant: 'success'
                }));
            } else {
                // No rows to update (e.g., all rows already have values when 'blank' selected)
                this.dispatchEvent(new ShowToastEvent({
                    title: 'No Rows Updated',
                    message: 'No blank rows found to update',
                    variant: 'info'
                }));
            }

            // STEP 5: Close modal
            this.closeAltClickModal();

        } catch (error) {
            // STEP 6: Error handling
            console.error('Error applying bulk assignment:', error);
            this.dispatchEvent(new ShowToastEvent({
                title: 'Error Applying Bulk Assignment',
                message: error.body?.message || error.message || 'An error occurred',
                variant: 'error'
            }));
            // Keep modal open on error so user can retry
        }
    }

    // TRINITY: Update description field based on code lookup (legacy method - kept for compatibility)
    async updateDescriptionFromCode(rowId, codeName) {
        try {
            const description = await getCodeDescription({ codeName });

            if (description) {
                // Update the Description__c field for this row
                this.lineItems = this.lineItems.map(item => {
                    if (item.Id === rowId) {
                        return { ...item, Description__c: description };
                    }
                    return item;
                });

                // TRINITY: Auto-save the populated description
                await this.autoSaveField(rowId, 'Description__c', description);

                // Show success message
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Code Found',
                    message: `Description updated: ${description}`,
                    variant: 'success'
                }));
            } else {
                // TRINITY: Meeting requirement - prompt when code not found
                const result = await LightningConfirm.open({
                    message: `Code "${codeName}" not found in database. Would you like to enter a custom description?`,
                    variant: 'default',
                    label: 'Code Not Found'
                });
                if (result) {
                    // Focus on the description field for manual entry
                    const descriptionInput = this.template.querySelector(`lightning-input[data-field="Description__c"][data-row-id="${rowId}"]`);
                    if (descriptionInput) {
                        descriptionInput.focus();
                    }
                }
            }
        } catch (error) {
            console.error('Error looking up code description:', error);
            this.dispatchEvent(new ShowToastEvent({
                title: 'Error',
                message: 'Failed to lookup code description: ' + (error.body?.message || error.message),
                variant: 'error'
            }));
        }
    }

    // TRINITY: Check if field should use lookup component
    isLookupField(fieldName) {
        return Object.keys(this.LOOKUP_FIELD_CONFIG).includes(fieldName);
    }

    // TRINITY: Get lookup configuration for field
    getLookupConfig(fieldName) {
        return this.LOOKUP_FIELD_CONFIG[fieldName] || null;
    }

    async handleFieldBlur(event) {
        // TRINITY: Auto-save on blur - use centralized helper method
        const fieldName = event.target.dataset.field;
        const rowId = event.target.dataset.rowId;
        const newValue = event.target.value;

        console.log('Auto-saving field on blur:', fieldName, 'for row:', rowId, 'value:', newValue);

        // MVADM-155 CRITICAL FIX: Skip auto-save for draft row (handled by handleDraftFieldChange)
        if (rowId === 'draft-row-temp') {
            console.log('TRINITY DEBUG: Skipping blur auto-save for draft row');
            return;
        }

        // Use the centralized auto-save helper
        await this.autoSaveField(rowId, fieldName, newValue);
    }

    // TRINITY: Bulk operations - modal-based duplication with count input
    handleDuplicate() {
        if (this.selectedIds.size === 0) return;

        // Reset modal state and show
        this.duplicateCount = 1;
        this.showDuplicationModal = true;
    }

    handleDuplicateCountChange(event) {
        this.duplicateCount = parseInt(event.target.value) || 1;
    }

    closeDuplicationModal() {
        this.showDuplicationModal = false;
        this.duplicateCount = 1;
    }

    async confirmDuplication() {
        // TRINITY: Implement 100-row limit with confirmation for >5
        const totalNewRows = this.selectedIds.size * this.duplicateCount;

        if (totalNewRows > 100) {
            this.dispatchEvent(new ShowToastEvent({
                title: 'Error',
                message: 'Cannot create more than 100 duplicate rows. Please reduce the count.',
                variant: 'error'
            }));
            return;
        }

        if (totalNewRows > 5) {
            const result = await LightningConfirm.open({
                message: `This will create ${totalNewRows} new rows. Are you sure?`,
                variant: 'default',
                label: 'Confirm Duplication'
            });
            if (!result) {
                return;
            }
        }

        try {
            this.isLoading = true;
            this.showDuplicationModal = false;

            // TRINITY: Call Apex with correct named parameters for @AuraEnabled method
            const duplicatedItems = await createDuplicateBillLineItems({
                originalItemIds: Array.from(this.selectedIds),
                duplicateCount: this.duplicateCount
            });

            // TRINITY: Process duplicated items through same transformation as wire service
            const processedDuplicates = duplicatedItems.map(item => ({
                ...item,
                // Selection state
                selected: false, // New duplicates start unselected

                // MVADM-188: Line number from Bill_Line_Item_Number__c field
                lineNumber: item.Bill_Line_Item_Number__c || '',

                // MVADM-188: Date formatting for display (using formatDate helper for consistency)
                formattedStartDate: this.formatDate(item.Service_Start_Date__c),
                formattedEndDate: this.formatDate(item.Service_End_Date__c),

                // Currency formatting
                chargeFormatted: this.formatCurrency(item.Charge__c),
                otherInsAllowedFormatted: this.formatCurrency(item.Other_Ins_Allowed__c),
                otherInsPaidFormatted: this.formatCurrency(item.Other_Ins_Paid__c),
                approvedAmountFormatted: this.formatCurrency(item.Approved_Amount__c),
                patientResponsibilityFormatted: this.formatCurrency(item.Patient_Responsibility__c),
                x3rdPartyFormatted: this.formatCurrency(item.X3rd_Party_Curr__c),
                adjustmentAmountFormatted: this.formatCurrency(item.Adjustment_Amount__c),
                savingsFeeFormatted: this.formatCurrency(item.Savings_Fee__c),

                // Medicare status display
                medicareStatusDisplay: item.Code__r?.Medicare_Covered__c === true ? 'Yes' :
                                     item.Code__r?.Medicare_Covered__c === false ? 'No' : 'Possible',
                medicareStatusValue: item.Code__r?.Medicare_Covered__c || '',
                medicareStatusYes: item.Code__r?.Medicare_Covered__c === true,
                medicareStatusNo: item.Code__r?.Medicare_Covered__c === false,
                medicareStatusPossible: item.Code__r?.Medicare_Covered__c !== true && item.Code__r?.Medicare_Covered__c !== false,

                // Duplicate detection flag
                isDuplicate: item.Duplicate_Status__c && item.Duplicate_Status__c !== 'None',
                duplicateStatus: item.Duplicate_Status__c,
                duplicateStatusLabel: this.getDuplicateStatusLabel(item.Duplicate_Status__c),

                // MVADM-188: Code values for expanded view (code-lookup-field components)
                revenueCode: item.Revenue_Code__c || '',
                revenueCodeDescription: '', // Will be populated via batch lookup
                revenueCodeDisplay: item.Revenue_Code__c || '',

                posCode: item.Place_of_Service__c || '',
                posCodeDescription: '', // Will be populated via batch lookup
                posDisplay: item.Place_of_Service__c || '',

                cptCode: item.CPT_HCPCS_NDC__c || '',
                cptCodeDescription: item.Code__r?.Description__c || '', // From Code__r relationship
                cptDisplay: item.CPT_HCPCS_NDC__c || '',

                modifierCode: item.Modifier__c || '',
                modifierCodeDescription: '', // Will be populated via batch lookup
                modifierDisplay: item.Modifier__c || '',

                // Other display fields
                quantityDisplay: item.Quantity__c || '',
                descriptionDisplay: item.Description__c || '',
                codeDisplay: item.Code__r?.Name || '',
                accountDisplay: item.Account__r?.Name || '',

                // Remark codes display
                remarkCode1Display: item.Remark_Code_1__c || '',
                remarkCode2Display: item.Remark_Code_2__c || '',
                remarkCode3Display: item.Remark_Code_3__c || '',
                remarkCode4Display: item.Remark_Code_4__c || '',

                // Tooltip placeholder
                codesDescriptionTooltip: '',

                // MVADM-188: Account name from Bill relationship
                accountName: item.Bill__r?.Member_Account__r?.Name || ''
            }));

            // Add processed duplicated items to grid
            this.lineItems = [...this.lineItems, ...processedDuplicates];

            // MVADM-188: Enrich code descriptions for tooltips on duplicated rows
            this.enrichCodeDescriptions();

            // TRINITY PHASE 2: Immutable Set pattern - clear selection
            this.selectedIds = new Set();

            // Show success message
            this.dispatchEvent(new ShowToastEvent({
                title: 'Success',
                message: `${duplicatedItems.length} line items duplicated successfully`,
                variant: 'success'
            }));

        } catch (error) {
            console.error('Error duplicating items:', error);
            this.dispatchEvent(new ShowToastEvent({
                title: 'Error',
                message: 'Failed to duplicate line items: ' + (error.body?.message || error.message),
                variant: 'error'
            }));
        } finally {
            this.isLoading = false;
            this.duplicateCount = 1;
        }
    }

    async handleDelete() {
        if (this.selectedIds.size === 0) return;

        const result = await LightningConfirm.open({
            message: `Delete ${this.selectedIds.size} selected line items? This cannot be undone.`,
            variant: 'destructive',
            label: 'Confirm Deletion'
        });
        if (result) {
            try {
                this.isLoading = true;

                // Call Apex to delete items - TRINITY: Fix parameter name to match Apex method
                await deleteBillLineItems({ itemIds: Array.from(this.selectedIds) });

                // Remove deleted items from grid immediately
                this.lineItems = this.lineItems.filter(item => !this.selectedIds.has(item.Id));

                // TRINITY PHASE 2: Immutable Set pattern - clear selection
                this.selectedIds = new Set();

                // Show success message
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Success',
                    message: `Line items deleted successfully`,
                    variant: 'success'
                }));

            } catch (error) {
                console.error('Error deleting items:', error);
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Error',
                    message: 'Failed to delete line items: ' + error.body?.message || error.message,
                    variant: 'error'
                }));
            } finally {
                this.isLoading = false;
            }
        }
    }

    // TRINITY v2.3.0: Validation and Adjudication handlers
    async handleAdjudicate() {
        this.isLoading = true;
        try {
            // TRINITY VALIDATION: Call comprehensive validation service
            const apexResult = await validateBCNQuoteForAdjudication({ caseId: this.recordId });

            // Transform Apex result to UI format
            this.validationResult = this.transformValidationResult(apexResult);

            // TRINITY PHASE 1.6: Apply validation status to rows (CHRIS'S #1 PRIORITY)
            this.applyValidationToRows(this.validationResult);

            // TRINITY FIX: Don't auto-launch modal - just show success message
            // User must click "View Report" button to see validation details
            const failureCount = (this.validationResult.redLineFailures?.length || 0);
            const warningCount = (this.validationResult.yellowLineWarnings?.length || 0);

            if (failureCount === 0 && warningCount === 0) {
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Validation Complete',
                    message: 'All validation rules passed. Ready to proceed with adjudication.',
                    variant: 'success'
                }));
            } else {
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Validation Complete',
                    message: `Found ${failureCount} error(s) and ${warningCount} warning(s). Click "View Report" to see details.`,
                    variant: failureCount > 0 ? 'error' : 'warning'
                }));
            }

        } catch (error) {
            console.error('Validation error:', error);
            this.dispatchEvent(new ShowToastEvent({
                title: 'Validation Error',
                message: 'Failed to validate BCN Quote: ' + (error.body?.message || error.message),
                variant: 'error'
            }));
        } finally {
            this.isLoading = false;
        }
    }

    // TRINITY VALIDATION: Transform Apex validation result to UI format
    transformValidationResult(apexResult) {
        // Combine all failures into red/yellow line arrays for backward compatibility
        const redLineFailures = [
            ...(apexResult.bcnLevelFailures || []).filter(f => f.severity === 'error'),
            ...(apexResult.chargeLevelFailures || []).filter(f => f.severity === 'error'),
            ...(apexResult.lineItemFailures || []).filter(f => f.severity === 'error'),
            ...(apexResult.relationalIntegrityFailures || []).filter(f => f.severity === 'error')
        ];

        const yellowLineWarnings = [
            ...(apexResult.warnings || []),
            ...(apexResult.bcnLevelFailures || []).filter(f => f.severity === 'warning'),
            ...(apexResult.chargeLevelFailures || []).filter(f => f.severity === 'warning'),
            ...(apexResult.lineItemFailures || []).filter(f => f.severity === 'warning'),
            ...(apexResult.relationalIntegrityFailures || []).filter(f => f.severity === 'warning')
        ];

        return {
            caseNumber: apexResult.caseNumber,
            caseId: apexResult.caseId,
            canProceed: apexResult.canProceed,
            redLineFailures: redLineFailures,
            yellowLineWarnings: yellowLineWarnings,
            // Keep categorized failures for enhanced modal display
            bcnLevelFailures: apexResult.bcnLevelFailures || [],
            chargeLevelFailures: apexResult.chargeLevelFailures || [],
            lineItemFailures: apexResult.lineItemFailures || [],
            relationalIntegrityFailures: apexResult.relationalIntegrityFailures || [],
            warnings: apexResult.warnings || [],
            passedRules: apexResult.passedRules || [], // TRINITY: Pass through passed rules for modal display
            totalLineItems: this.lineItems.length,
            totalCharge: this.lineItems.reduce((sum, item) => sum + (item.Charge__c || 0), 0),
            totalApproved: this.lineItems.reduce((sum, item) => sum + (item.Approved_Amount__c || 0), 0)
        };
    }

    handleCloseValidationModal() {
        this.showValidationModal = false;
        // TRINITY PHASE 1.6: Keep row highlighting after modal close (CHRIS'S #1 PRIORITY)
        // Row colors persist so user can see which rows have issues
    }

    handleFixIssues() {
        // Close modal and let user fix issues in the grid
        this.showValidationModal = false;
        this.dispatchEvent(new ShowToastEvent({
            title: 'Info',
            message: 'Please resolve the validation issues and try again',
            variant: 'info'
        }));
    }

    /*handleProceedWithAdjudication() {
        // Close modal and proceed with adjudication
        this.showValidationModal = false;
        this.dispatchEvent(new ShowToastEvent({
            title: 'Success',
            message: 'Adjudication validation passed - ready to proceed',
            variant: 'success'
        }));
        // Future: Navigate to next stage or trigger adjudication workflow
    }*/
    async handleProceedWithAdjudication() {
        this.isProcessingAdjudication = true;
        try {
            // TRINITY: Mark all Bill Line Items as Processed
            await markLineItemsAsProcessed({ caseId: this.recordId });

            // Refresh the grid to show the updated status
            await refreshApex(this.wiredLineItemsResult);

            // Close modal
            this.showValidationModal = false;

            // Show success message
            this.dispatchEvent(new ShowToastEvent({
                title: 'Success',
                message: 'Adjudication validation passed - ready to proceed',
                variant: 'success'
            }));

        } catch (error) {
            console.error('Error completing adjudication:', error);
            this.dispatchEvent(new ShowToastEvent({
                title: 'Error',
                message: error.body?.message || 'Error completing adjudication',
                variant: 'error'
            }));
        } finally {
            this.isProcessingAdjudication = false;
        }
    }

    // TRINITY PHASE 1.6: View Report button handler (CHRIS'S #1 PRIORITY)
    handleViewReport() {
        // Reopen the validation modal with existing validation result
        this.showValidationModal = true;
    }

    // TRINITY PHASE 1.6: Apply validation results to row formatting (CHRIS'S #1 PRIORITY)
    applyValidationToRows(validationResult) {
        // Build a map of line numbers to their validation status
        const lineValidation = {};

        // Process red line failures (errors)
        if (validationResult.redLineFailures) {
            validationResult.redLineFailures.forEach(failure => {
                const lineNumbers = failure.affectedLineItems.split(',').map(n => n.trim());
                lineNumbers.forEach(lineNum => {
                    if (!lineValidation[lineNum]) {
                        lineValidation[lineNum] = { status: 'error', errors: [], warnings: [] };
                    }
                    lineValidation[lineNum].errors.push({
                        rule: failure.ruleName,
                        message: failure.message,
                        severity: 'error'
                    });
                });
            });
        }

        // Process yellow line warnings
        if (validationResult.yellowLineWarnings) {
            validationResult.yellowLineWarnings.forEach(warning => {
                const lineNumbers = warning.affectedLineItems.split(',').map(n => n.trim());
                lineNumbers.forEach(lineNum => {
                    if (!lineValidation[lineNum]) {
                        lineValidation[lineNum] = { status: 'warning', errors: [], warnings: [] };
                    }
                    // Only set to warning if not already an error
                    if (lineValidation[lineNum].status !== 'error') {
                        lineValidation[lineNum].status = 'warning';
                    }
                    lineValidation[lineNum].warnings.push({
                        rule: warning.ruleName,
                        message: warning.message,
                        severity: 'warning'
                    });
                });
            });
        }

        // Apply validation status to line items
        this.lineItems = this.lineItems.map(item => {
            const lineNum = item.Bill_Line_Item_Number__c?.toString();
            const validation = lineValidation[lineNum];

            if (validation) {
                return {
                    ...item,
                    validationStatus: validation.status,
                    validationErrors: validation.errors,
                    validationWarnings: validation.warnings,
                    rowClass: `grid-row row-${validation.status}`
                };
            } else {
                return {
                    ...item,
                    validationStatus: 'valid',
                    validationErrors: [],
                    validationWarnings: [],
                    rowClass: 'grid-row row-valid'
                };
            }
        });
    }

    // TRINITY v2.3.0: Generate static validation result based on real data
    generateValidationResult() {
        const totalCharge = this.lineItems.reduce((sum, item) => sum + (item.Charge__c || 0), 0);
        const totalApproved = this.lineItems.reduce((sum, item) => sum + (item.Approved_Amount__c || 0), 0);

        const redLineFailures = [];
        const yellowLineWarnings = [];

        // RED LINE: Check for missing accounts
        const missingAccounts = this.lineItems.filter(item => !item.Account__c);
        if (missingAccounts.length > 0) {
            redLineFailures.push({
                ruleId: 'account_required',
                ruleName: 'Account Assignment Required',
                severity: 'error',
                message: `${missingAccounts.length} line item${missingAccounts.length > 1 ? 's are' : ' is'} missing account assignments`,
                affectedLineItems: missingAccounts.map(item => item.Bill_Line_Item_Number__c).join(', '),
                details: 'Each line item must have an account assigned to determine payment source'
            });
        }

        // RED LINE: Check for zero/null approved amounts (in Bill Review stage)
        if (this.currentStage === 'billReview') {
            const missingApprovedAmounts = this.lineItems.filter(item =>
                item.Approved_Amount__c === null || item.Approved_Amount__c === undefined
            );
            if (missingApprovedAmounts.length > 0) {
                redLineFailures.push({
                    ruleId: 'paid_amount_required',
                    ruleName: 'Paid Amount Required',
                    severity: 'error',
                    message: `${missingApprovedAmounts.length} line item${missingApprovedAmounts.length > 1 ? 's have' : ' has'} no approved amount`,
                    affectedLineItems: missingApprovedAmounts.map(item => item.Bill_Line_Item_Number__c).join(', '),
                    details: 'Adjudication requires explicit paid amounts, even if $0.00 is the final decision'
                });
            }
        }

        // YELLOW LINE: Check for high-value line items (>$5,000)
        const highValueItems = this.lineItems.filter(item => item.Charge__c > 5000);
        if (highValueItems.length > 0) {
            highValueItems.forEach(item => {
                yellowLineWarnings.push({
                    ruleId: 'high_value_line_item',
                    ruleName: 'High-Value Line Item',
                    severity: 'warning',
                    message: `Line #${item.Bill_Line_Item_Number__c} has charge of $${item.Charge__c.toLocaleString('en-US', {minimumFractionDigits: 2})}`,
                    affectedLineItems: [item.Bill_Line_Item_Number__c].join(', '),
                    details: `Procedure ${item.CPT_HCPCS_NDC__c || 'N/A'} - Verify charge is accurate for this procedure`
                });
            });
        }

        // YELLOW LINE: Check for potential duplicate procedures
        const procedureCounts = {};
        this.lineItems.forEach(item => {
            const key = `${item.CPT_HCPCS_NDC__c}_${item.Charge__c}`;
            if (!procedureCounts[key]) {
                procedureCounts[key] = [];
            }
            procedureCounts[key].push(item);
        });

        Object.values(procedureCounts).forEach(items => {
            if (items.length > 1) {
                yellowLineWarnings.push({
                    ruleId: 'duplicate_procedures',
                    ruleName: 'Potential Duplicate Procedures',
                    severity: 'warning',
                    message: `Lines ${items.map(i => '#' + i.Bill_Line_Item_Number__c).join(' and ')} both have procedure ${items[0].CPT_HCPCS_NDC__c} with $${items[0].Charge__c} charge`,
                    affectedLineItems: items.map(i => i.Bill_Line_Item_Number__c).join(', '),
                    details: 'May be legitimate multiple administrations or potential duplicate - review for accuracy'
                });
            }
        });

        // YELLOW LINE: Check for large total bill (>$10,000)
        if (totalCharge > 10000) {
            yellowLineWarnings.push({
                ruleId: 'large_total_bill',
                ruleName: 'Large Total Bill Amount',
                severity: 'warning',
                message: `Total bill amount is $${totalCharge.toLocaleString('en-US', {minimumFractionDigits: 2})}`,
                affectedLineItems: '',
                details: 'High-value claim should receive additional review for accuracy and appropriateness'
            });
        }

        return {
            caseNumber: this.caseId || 'Unknown',
            caseId: this.caseId,
            stage: this.currentStage,
            totalLineItems: this.lineItems.length,
            totalCharge: totalCharge,
            totalApproved: totalApproved,
            redLineFailures: redLineFailures,
            yellowLineWarnings: yellowLineWarnings,
            canProceed: redLineFailures.length === 0,
            blockedBy: redLineFailures.map(f => f.ruleId)
        };
    }

    // TRINITY v2.6.0: Column resizing with Excel-perfect behavior
    handleResizeStart(event) {
        event.preventDefault();
        // TRINITY v2.6.0: DON'T stopPropagation - let event bubble naturally

        const columnName = event.target.dataset.column;
        const startX = event.clientX;
        const columnElement = event.target.parentElement;
        const startWidth = columnElement.offsetWidth;

        console.log('Starting resize for column:', columnName, 'startX:', startX, 'startWidth:', startWidth);

        this.isResizing = true;
        this.resizingColumn = columnName;

        // Store initial values
        this.resizeStartX = startX;
        this.resizeStartWidth = startWidth;
        this.resizeColumnElement = columnElement;

        // TRINITY: Create bound handlers for proper cleanup
        this.boundHandleResizeMove = this.handleResizeMove.bind(this);
        this.boundHandleResizeEnd = this.handleResizeEnd.bind(this);

        // TRINITY v2.6.0: Add event listeners to window (not document) for better capture
        window.addEventListener('mousemove', this.boundHandleResizeMove, false);
        window.addEventListener('mouseup', this.boundHandleResizeEnd, false);

        // Change cursor for better UX
        document.body.style.cursor = 'col-resize';

        // TRINITY v2.6.0: Prevent text selection during drag
        document.body.style.userSelect = 'none';

        // TRINITY v2.6.0: Add class to resizer for active state
        event.target.classList.add('resizing');
    }

    handleResizeMove(event) {
        if (!this.isResizing) return;

        const deltaX = event.clientX - this.resizeStartX;
        const columnName = this.resizingColumn;

        // TRINITY v2.6.0: Get column-specific minimum width
        const minWidth = this.getMinWidthForColumn(columnName);
        const newWidth = Math.max(minWidth, this.resizeStartWidth + deltaX);

        // TRINITY v2.6.0: Update tracked width - this triggers reactive re-render of <col> elements
        const updatedWidths = { ...this.columnWidths };
        updatedWidths[columnName] = newWidth;
        this.columnWidths = updatedWidths;

        // TRINITY v2.6.0: Force immediate DOM update for live preview
        // Use requestAnimationFrame to ensure smooth rendering
        requestAnimationFrame(() => {
            // Update ALL <col> elements with this column name
            const colElements = this.template.querySelectorAll(`col[data-column="${columnName}"]`);
            colElements.forEach(col => {
                col.style.width = newWidth + 'px';
            });

            // Also update <th> for immediate visual feedback
            if (this.resizeColumnElement) {
                this.resizeColumnElement.style.width = newWidth + 'px';
            }
        });
    }

    handleResizeEnd(event) {
        if (!this.isResizing) return;

        console.log('Resize ended for column:', this.resizingColumn);

        // TRINITY v2.6.0: Remove resizing class from all resizers
        const resizers = this.template.querySelectorAll('.column-resizer.resizing');
        resizers.forEach(r => r.classList.remove('resizing'));

        // Clean up state
        this.isResizing = false;
        this.resizingColumn = null;
        this.resizeStartX = null;
        this.resizeStartWidth = null;
        this.resizeColumnElement = null;

        // TRINITY v2.6.0: Remove event listeners from window (must match addEventListener)
        if (this.boundHandleResizeMove) {
            window.removeEventListener('mousemove', this.boundHandleResizeMove, false);
            this.boundHandleResizeMove = null;
        }
        if (this.boundHandleResizeEnd) {
            window.removeEventListener('mouseup', this.boundHandleResizeEnd, false);
            this.boundHandleResizeEnd = null;
        }

        // Reset cursor and user-select
        document.body.style.cursor = '';
        document.body.style.userSelect = '';
    }

    // TRINITY v2.6.0: Get column-specific minimum width (Excel-perfect UX)
    getMinWidthForColumn(columnName) {
        const minWidths = {
            // Keying/Bill Review columns
            lineNumber: 60,
            serviceDates: 100,
            endDate: 100,
            codes: 100,
            pos: 60,
            cpt: 120,
            modifier: 70,
            quantity: 70,
            description: 150,
            charge: 100,
            remarkCodes: 100,
            rc2: 80,
            rc3: 80,
            rc4: 80,
            oiAllow: 100,
            oiPaid: 100,
            paid: 100,
            thirdParty: 100,
            patResp: 100,
            account: 120,
            medicare: 100,
            // Quote View columns
            code: 120,
            price: 100,
            approvedAmount: 120
        };
        return minWidths[columnName] || 80; // Default 80px minimum
    }

    // TRINITY: Keyboard navigation - simple tab handling
    handleKeyDown(event) {
        if (event.key === 'Tab') {
            // Let default tab behavior work - LWC handles this well
            return;
        }

        if (event.key === 'Enter') {
            // Move to next row, same column
            event.preventDefault();
            const currentInput = event.target;
            const currentRowId = currentInput.dataset.rowId;
            const fieldName = currentInput.dataset.field;

            // Find next row
            const currentRowIndex = this.lineItems.findIndex(item => item.Id === currentRowId);
            if (currentRowIndex < this.lineItems.length - 1) {
                const nextRowId = this.lineItems[currentRowIndex + 1].Id;

                // Focus next row's same field
                setTimeout(() => {
                    const nextInput = this.template.querySelector(
                        `lightning-input[data-row-id="${nextRowId}"][data-field="${fieldName}"]`
                    );
                    if (nextInput) {
                        nextInput.focus();
                    }
                }, 10);
            }
        }

        if (event.key === 'Escape') {
            // Clear focus and revert changes
            event.target.blur();
        }
    }

    // TRINITY: Medicare status tooltip helper (MVADM-76)
    getMedicareTooltip(status) {
        const tooltips = {
            'Yes': 'Medicare covers this code',
            'No': 'Medicare does not cover this code',
            'Review': 'Code requires additional review for coverage determination',
            'TBD': 'Coverage status to be determined',
            'Discretion': 'Coverage determination requires individual assessment'
        };
        return tooltips[status] || tooltips['TBD'];
    }

    // TRINITY PHASE 2: Setup on component connect
    connectedCallback() {
        // Bind window click handler for closing context menu
        this.boundHandleWindowClick = this.handleWindowClick.bind(this);
        window.addEventListener('click', this.boundHandleWindowClick);
        console.log('✅ Window click listener added for context menu');
    }

    // TRINITY: Cleanup on component disconnect
    disconnectedCallback() {
        // Clean up any active resize operations
        if (this.isResizing) {
            if (this.boundHandleResizeMove) {
                document.removeEventListener('mousemove', this.boundHandleResizeMove);
            }
            if (this.boundHandleResizeEnd) {
                document.removeEventListener('mouseup', this.boundHandleResizeEnd);
            }
            document.body.style.cursor = '';
        }

        // TRINITY PHASE 2: Remove window click listener
        if (this.boundHandleWindowClick) {
            window.removeEventListener('click', this.boundHandleWindowClick);
            console.log('✅ Window click listener removed');
        }
    }

    // TRINITY PHASE 2: Handle window click to close context menu
    handleWindowClick(event) {
        // Close context menu if clicking outside of it
        if (this.showContextMenu) {
            const contextMenu = this.template.querySelector('.context-menu');
            if (contextMenu && !contextMenu.contains(event.target)) {
                this.closeContextMenu();
            }
        }
    }
}