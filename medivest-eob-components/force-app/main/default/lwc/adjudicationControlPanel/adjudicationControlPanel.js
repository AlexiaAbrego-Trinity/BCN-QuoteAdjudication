import { LightningElement, api, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';
import getAdjudicationControlData from '@salesforce/apex/TRM_MedicalBillingService.getAdjudicationControlData';
import updateAdjudicationControls from '@salesforce/apex/TRM_MedicalBillingService.updateAdjudicationControls';

export default class AdjudicationControlPanel extends LightningElement {
    @api recordId; // Case ID from record page
    
    @track controlData = {};
    @track isLoading = true;
    @track isSaving = false;
    @track error = null;
    
    // Track changes for save operation
    @track pendingChanges = {};
    @track hasChanges = false;

    // Wire to get adjudication control data
    @wire(getAdjudicationControlData, { caseId: '$recordId' })
    wiredControlData(result) {
        this.wiredResult = result;
        if (result.data) {
            this.controlData = { ...result.data };
            this.pendingChanges = {}; // Reset pending changes
            this.hasChanges = false;
            this.error = null;
            this.isLoading = false;
        } else if (result.error) {
            this.error = result.error.body?.message || 'Unknown error occurred';
            this.isLoading = false;
            console.error('Error loading adjudication control data:', result.error);
        }
    }

    // Handle Apply Bill Fee toggle change
    handleApplyBillFeeChange(event) {
        const newValue = event.target.checked;
        this.controlData = { 
            ...this.controlData, 
            applyBillFee: newValue 
        };
        this.pendingChanges.applyBillFee = newValue;
        this.hasChanges = true;
        
        console.log('Apply Bill Fee changed to:', newValue);
    }

    // Handle Apply Savings Fee toggle change
    handleApplySavingsFeeChange(event) {
        const newValue = event.target.checked;
        this.controlData = { 
            ...this.controlData, 
            applySavingsFee: newValue 
        };
        this.pendingChanges.applySavingsFee = newValue;
        this.hasChanges = true;
        
        console.log('Apply Savings Fee changed to:', newValue);
    }

    // Handle WAM Vendor Exception toggle change
    handleWamVendorExceptionChange(event) {
        const newValue = event.target.checked;
        this.controlData = {
            ...this.controlData,
            wamVendorException: newValue
        };
        this.pendingChanges.wamVendorException = newValue;
        this.hasChanges = true;

        // RAY'S BUSINESS RULE: When WAM exception is enabled, disable fee processing
        if (newValue) {
            this.controlData = {
                ...this.controlData,
                applyBillFee: false,
                applySavingsFee: false
            };
            this.pendingChanges.applyBillFee = false;
            this.pendingChanges.applySavingsFee = false;

            this.showToast('Info', 'WAM Vendor Exception enabled - fee processing disabled per Ray\'s requirements', 'info');
        }

        console.log('WAM Vendor Exception changed to:', newValue);
    }

    // Handle save changes
    async handleSaveChanges() {
        if (!this.hasChanges) {
            this.showToast('Info', 'No changes to save', 'info');
            return;
        }

        this.isSaving = true;
        
        try {
            const updateData = {
                caseId: this.recordId,
                applyBillFee: this.controlData.applyBillFee,
                applySavingsFee: this.controlData.applySavingsFee,
                wamVendorException: this.controlData.wamVendorException
            };

            await updateAdjudicationControls(updateData);
            
            // Refresh the wired data
            await refreshApex(this.wiredResult);
            
            this.pendingChanges = {};
            this.hasChanges = false;
            
            this.showToast('Success', 'Adjudication controls updated successfully', 'success');
            
        } catch (error) {
            console.error('Error saving adjudication controls:', error);
            this.showToast('Error', 'Failed to save changes: ' + (error.body?.message || error.message), 'error');
        } finally {
            this.isSaving = false;
        }
    }

    // Handle reset to defaults
    handleResetDefaults() {
        // Reset to default values (Apply Bill Fee and Apply Savings Fee = true, WAM Vendor Exception = false)
        this.controlData = {
            ...this.controlData,
            applyBillFee: true,
            applySavingsFee: true,
            wamVendorException: false
        };
        
        this.pendingChanges = {
            applyBillFee: true,
            applySavingsFee: true,
            wamVendorException: false
        };
        
        this.hasChanges = true;
        
        this.showToast('Info', 'Controls reset to default values. Click Save Changes to apply.', 'info');
    }

    // Utility method to show toast messages
    showToast(title, message, variant) {
        const event = new ShowToastEvent({
            title: title,
            message: message,
            variant: variant
        });
        this.dispatchEvent(event);
    }

    // Computed properties for display
    get displayCaseNumber() {
        return this.controlData.caseNumber || 'Loading...';
    }

    get displayCurrentPayment() {
        return this.controlData.currentPayment || 0;
    }

    get displayTotalCost() {
        return this.controlData.totalCost || 0;
    }

    get displayMsaFundsPayment() {
        return this.controlData.msaFundsPayment || 0;
    }

    get displayNonMsaFundsPayment() {
        return this.controlData.nonMsaFundsPayment || 0;
    }
}