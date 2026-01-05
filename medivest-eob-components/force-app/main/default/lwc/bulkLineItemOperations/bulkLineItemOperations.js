import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class BulkLineItemOperations extends LightningElement {
    @api lineItems = []; // Array of line items to operate on
    @api recordId; // Case ID for context
    
    // Selection tracking
    @track selectedItems = new Set();
    @track lastSelectedIndex = -1;
    
    // Panel visibility
    @track showAdvancedPanel = false;
    @track showRCCodePanel = false;
    @track showOIPanel = false;
    @track showAccountPanel = false;
    
    // Bulk operation values
    @track bulkRC1 = '';
    @track bulkRC2 = '';
    @track bulkRC3 = '';
    @track bulkRC4 = '';
    @track oiAllowPercentage = 0;
    @track oiPaidPercentage = 0;
    @track patientRespPercentage = 0;
    @track selectedAccountId = '';
    @track selectedAccountInfo = null;
    
    // Processing state
    @track isProcessing = false;
    @track processingMessage = '';
    @track showResults = false;
    @track resultsMessage = '';
    
    // Options for dropdowns
    @track rcCodeOptions = [
        { label: 'RC001 - Duplicate Claim', value: 'RC001' },
        { label: 'RC002 - Missing Information', value: 'RC002' },
        { label: 'RC003 - Invalid Code', value: 'RC003' },
        { label: 'RC004 - Authorization Required', value: 'RC004' },
        { label: 'RC005 - Benefit Exhausted', value: 'RC005' },
        { label: 'RC006 - Not Covered', value: 'RC006' },
        { label: 'RC007 - Coordination of Benefits', value: 'RC007' },
        { label: 'RC008 - Timely Filing', value: 'RC008' }
    ];
    
    @track accountOptions = []; // Will be populated from real data

    // Computed properties
    get selectedCount() {
        return this.selectedItems.size;
    }
    
    get totalCount() {
        return this.lineItems ? this.lineItems.length : 0;
    }
    
    get disableBulkActions() {
        return this.selectedItems.size === 0 || this.isProcessing;
    }

    // Initialize component
    connectedCallback() {
        this.loadAccountOptions();
        this.setupKeyboardListeners();
    }

    disconnectedCallback() {
        this.removeKeyboardListeners();
    }

    // Setup keyboard event listeners for Alt+Click functionality
    setupKeyboardListeners() {
        this.handleKeyDown = this.handleKeyDown.bind(this);
        this.handleKeyUp = this.handleKeyUp.bind(this);
        document.addEventListener('keydown', this.handleKeyDown);
        document.addEventListener('keyup', this.handleKeyUp);
    }

    removeKeyboardListeners() {
        document.removeEventListener('keydown', this.handleKeyDown);
        document.removeEventListener('keyup', this.handleKeyUp);
    }

    // Handle keyboard events for modifier keys
    handleKeyDown(event) {
        if (event.altKey) {
            this.altKeyPressed = true;
        }
        if (event.shiftKey) {
            this.shiftKeyPressed = true;
        }
    }

    handleKeyUp(event) {
        if (!event.altKey) {
            this.altKeyPressed = false;
        }
        if (!event.shiftKey) {
            this.shiftKeyPressed = false;
        }
    }

    // Handle line item selection with Alt+Click and Shift+Click support
    @api
    handleLineItemClick(event, itemIndex) {
        const itemId = this.lineItems[itemIndex].Id;
        
        if (this.altKeyPressed) {
            // Alt+Click: Toggle selection
            if (this.selectedItems.has(itemId)) {
                this.selectedItems.delete(itemId);
            } else {
                this.selectedItems.add(itemId);
            }
            this.lastSelectedIndex = itemIndex;
        } else if (this.shiftKeyPressed && this.lastSelectedIndex !== -1) {
            // Shift+Click: Range selection
            const start = Math.min(this.lastSelectedIndex, itemIndex);
            const end = Math.max(this.lastSelectedIndex, itemIndex);
            
            for (let i = start; i <= end; i++) {
                this.selectedItems.add(this.lineItems[i].Id);
            }
        } else {
            // Regular click: Single selection
            this.selectedItems.clear();
            this.selectedItems.add(itemId);
            this.lastSelectedIndex = itemIndex;
        }
        
        // Force reactivity update
        this.selectedItems = new Set(this.selectedItems);
        
        // Dispatch selection change event
        this.dispatchEvent(new CustomEvent('selectionchange', {
            detail: {
                selectedItems: Array.from(this.selectedItems),
                selectedCount: this.selectedItems.size
            }
        }));
    }

    // Selection actions
    handleSelectAll() {
        this.selectedItems.clear();
        this.lineItems.forEach(item => {
            this.selectedItems.add(item.Id);
        });
        this.selectedItems = new Set(this.selectedItems);
        this.showToast('Success', `Selected all ${this.totalCount} items`, 'success');
    }

    handleClearSelection() {
        this.selectedItems.clear();
        this.selectedItems = new Set(this.selectedItems);
        this.lastSelectedIndex = -1;
        this.showToast('Info', 'Selection cleared', 'info');
    }

    // Bulk operation handlers
    handleBulkRCCode() {
        this.showAdvancedPanel = true;
        this.showRCCodePanel = true;
        this.showOIPanel = false;
        this.showAccountPanel = false;
    }

    handleBulkOICalculation() {
        this.showAdvancedPanel = true;
        this.showRCCodePanel = false;
        this.showOIPanel = true;
        this.showAccountPanel = false;
    }

    handleBulkAccountSelection() {
        this.showAdvancedPanel = true;
        this.showRCCodePanel = false;
        this.showOIPanel = false;
        this.showAccountPanel = true;
    }

    // RC Code handlers
    handleRC1Change(event) { this.bulkRC1 = event.detail.value; }
    handleRC2Change(event) { this.bulkRC2 = event.detail.value; }
    handleRC3Change(event) { this.bulkRC3 = event.detail.value; }
    handleRC4Change(event) { this.bulkRC4 = event.detail.value; }

    // OI Percentage handlers
    handleOIAllowPercentageChange(event) { this.oiAllowPercentage = event.detail.value; }
    handleOIPaidPercentageChange(event) { this.oiPaidPercentage = event.detail.value; }
    handlePatientRespPercentageChange(event) { this.patientRespPercentage = event.detail.value; }

    // Account selection handler
    handleAccountChange(event) {
        this.selectedAccountId = event.detail.value;
        // Load account info
        this.loadAccountInfo(this.selectedAccountId);
    }

    // Apply bulk operations
    async handleApplyRCCodes() {
        this.isProcessing = true;
        this.processingMessage = 'Applying RC codes to selected items...';
        
        try {
            const selectedItemIds = Array.from(this.selectedItems);
            const rcCodes = {
                RC1: this.bulkRC1,
                RC2: this.bulkRC2,
                RC3: this.bulkRC3,
                RC4: this.bulkRC4
            };
            
            // Call Apex method to apply RC codes
            // await applyBulkRCCodes({ itemIds: selectedItemIds, rcCodes: rcCodes });
            
            // Simulate processing for demo
            await this.simulateProcessing(2000);
            
            this.resultsMessage = `Successfully applied RC codes to ${selectedItemIds.length} line items.`;
            this.showResults = true;
            this.showToast('Success', this.resultsMessage, 'success');
            
        } catch (error) {
            this.showToast('Error', 'Failed to apply RC codes: ' + error.message, 'error');
        } finally {
            this.isProcessing = false;
            this.showAdvancedPanel = false;
        }
    }

    async handleApplyOICalculations() {
        this.isProcessing = true;
        this.processingMessage = 'Calculating OI percentages for selected items...';
        
        try {
            const selectedItemIds = Array.from(this.selectedItems);
            const percentages = {
                oiAllow: this.oiAllowPercentage,
                oiPaid: this.oiPaidPercentage,
                patientResp: this.patientRespPercentage
            };
            
            // Call Apex method to calculate percentages
            // await applyBulkOICalculations({ itemIds: selectedItemIds, percentages: percentages });
            
            // Simulate processing for demo
            await this.simulateProcessing(2500);
            
            this.resultsMessage = `Successfully calculated and applied OI percentages to ${selectedItemIds.length} line items.`;
            this.showResults = true;
            this.showToast('Success', this.resultsMessage, 'success');
            
        } catch (error) {
            this.showToast('Error', 'Failed to apply OI calculations: ' + error.message, 'error');
        } finally {
            this.isProcessing = false;
            this.showAdvancedPanel = false;
        }
    }

    async handleApplyAccountAssignment() {
        this.isProcessing = true;
        this.processingMessage = 'Assigning account to selected items...';
        
        try {
            const selectedItemIds = Array.from(this.selectedItems);
            
            // Call Apex method to assign account
            // await applyBulkAccountAssignment({ itemIds: selectedItemIds, accountId: this.selectedAccountId });
            
            // Simulate processing for demo
            await this.simulateProcessing(1500);
            
            this.resultsMessage = `Successfully assigned account to ${selectedItemIds.length} line items.`;
            this.showResults = true;
            this.showToast('Success', this.resultsMessage, 'success');
            
        } catch (error) {
            this.showToast('Error', 'Failed to assign account: ' + error.message, 'error');
        } finally {
            this.isProcessing = false;
            this.showAdvancedPanel = false;
        }
    }

    // Utility methods
    async loadAccountOptions() {
        // Load real account options from Apex
        // For now, using demo data
        this.accountOptions = [
            { label: 'Primary Account - Active', value: 'acc001' },
            { label: 'Secondary Account - Active', value: 'acc002' },
            { label: 'HSA Account - Active', value: 'acc003' },
            { label: 'FSA Account - Active', value: 'acc004' }
        ];
    }

    async loadAccountInfo(accountId) {
        // Load real account info from Apex
        // For now, using demo data
        this.selectedAccountInfo = {
            name: 'Primary Account - Active',
            status: 'Active',
            balance: 2500.00
        };
    }

    async simulateProcessing(delay) {
        return new Promise(resolve => setTimeout(resolve, delay));
    }

    showToast(title, message, variant) {
        const event = new ShowToastEvent({
            title: title,
            message: message,
            variant: variant
        });
        this.dispatchEvent(event);
    }
}