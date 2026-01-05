import { LightningElement, api, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';
import getFinancialValidationData from '@salesforce/apex/TRM_MedicalBillingService.getFinancialValidationData';

export default class FinancialValidationPanel extends LightningElement {
    @api recordId; // Case ID from record page
    
    @track isLoading = true;
    @track error = null;
    
    // Fund availability data
    @track msaAvailable = 0;
    @track msaAllocated = 0;
    @track msaReserved = 0;
    @track pcaAvailable = 0;
    @track pcaAllocated = 0;
    @track pcaReserved = 0;
    @track sakAvailable = 0;
    @track sakAllocated = 0;
    @track sakReserved = 0;
    
    // Calculation data
    @track originalAmount = 0;
    @track negotiatedAmount = 0;
    @track billFee = 0;
    @track savingsFeePercentage = 15;
    @track savingsFee = 0;
    
    // Validation alerts
    @track validationAlerts = [];
    @track hasBlockingAlerts = false;

    // Wire to get financial validation data
    @wire(getFinancialValidationData, { caseId: '$recordId' })
    wiredFinancialData(result) {
        this.wiredResult = result;
        if (result.data) {
            this.processFinancialData(result.data);
            this.error = null;
            this.isLoading = false;
        } else if (result.error) {
            this.error = result.error.body?.message || 'Unknown error occurred';
            this.isLoading = false;
            console.error('Error loading financial validation data:', result.error);
        }
    }

    // Process financial data and perform calculations
    processFinancialData(data) {
        // Fund availability
        this.msaAvailable = data.msaAvailable || 0;
        this.msaAllocated = data.msaAllocated || 0;
        this.msaReserved = data.msaReserved || 0;
        this.pcaAvailable = data.pcaAvailable || 0;
        this.pcaAllocated = data.pcaAllocated || 0;
        this.pcaReserved = data.pcaReserved || 0;
        this.sakAvailable = data.sakAvailable || 0;
        this.sakAllocated = data.sakAllocated || 0;
        this.sakReserved = data.sakReserved || 0;
        
        // Calculation amounts
        this.originalAmount = data.originalAmount || 0;
        this.negotiatedAmount = data.negotiatedAmount || 0;
        this.billFee = data.billFee || 25.00; // Standard bill fee
        
        // Perform smart calculations
        this.performSmartCalculations();
        
        // Generate validation alerts
        this.generateValidationAlerts();
    }

    // Perform smart financial calculations
    performSmartCalculations() {
        // Calculate savings
        this.totalSavings = Math.max(0, this.originalAmount - this.negotiatedAmount);
        this.savingsPercentage = this.originalAmount > 0 ? 
            Math.round((this.totalSavings / this.originalAmount) * 100) : 0;
        
        // Calculate fees
        this.savingsFee = (this.totalSavings * this.savingsFeePercentage) / 100;
        this.totalFees = this.billFee + this.savingsFee;
        
        // Calculate net savings
        this.netSavings = this.totalSavings - this.totalFees;
    }

    // Generate validation alerts based on financial analysis
    generateValidationAlerts() {
        const alerts = [];
        
        // Fund availability alerts
        if (this.negotiatedAmount > this.msaAvailable) {
            alerts.push({
                id: 'msa-insufficient',
                type: 'error',
                alertClass: 'validation-alert alert-error',
                icon: 'utility:error',
                title: 'Insufficient MSA Funds',
                message: `Negotiated amount ($${this.negotiatedAmount.toFixed(2)}) exceeds available MSA funds ($${this.msaAvailable.toFixed(2)}).`,
                action: true,
                actionLabel: 'Check Alternative Funds',
                actionVariant: 'neutral',
                actionHandler: this.handleCheckAlternativeFunds
            });
        }
        
        // Savings validation
        if (this.savingsPercentage < 10) {
            alerts.push({
                id: 'low-savings',
                type: 'warning',
                alertClass: 'validation-alert alert-warning',
                icon: 'utility:warning',
                title: 'Low Savings Percentage',
                message: `Savings percentage (${this.savingsPercentage}%) is below recommended threshold of 10%.`,
                action: true,
                actionLabel: 'Renegotiate Amount',
                actionVariant: 'neutral',
                actionHandler: this.handleRenegotiate
            });
        }
        
        // Fee validation
        if (this.totalFees > this.totalSavings) {
            alerts.push({
                id: 'fees-exceed-savings',
                type: 'error',
                alertClass: 'validation-alert alert-error',
                icon: 'utility:error',
                title: 'Fees Exceed Savings',
                message: `Total fees ($${this.totalFees.toFixed(2)}) exceed total savings ($${this.totalSavings.toFixed(2)}).`,
                action: true,
                actionLabel: 'Review Fee Structure',
                actionVariant: 'destructive',
                actionHandler: this.handleReviewFees
            });
        }
        
        // Net savings validation
        if (this.netSavings > 0 && this.netSavings < 100) {
            alerts.push({
                id: 'minimal-net-savings',
                type: 'info',
                alertClass: 'validation-alert alert-info',
                icon: 'utility:info',
                title: 'Minimal Net Savings',
                message: `Net savings ($${this.netSavings.toFixed(2)}) is minimal. Consider if adjudication is cost-effective.`,
                action: false
            });
        }
        
        // Success validation
        if (this.netSavings > 500 && this.savingsPercentage > 20) {
            alerts.push({
                id: 'excellent-savings',
                type: 'success',
                alertClass: 'validation-alert alert-success',
                icon: 'utility:success',
                title: 'Excellent Savings Achieved',
                message: `Outstanding results: ${this.savingsPercentage}% savings with $${this.netSavings.toFixed(2)} net benefit.`,
                action: false
            });
        }
        
        this.validationAlerts = alerts;
        this.hasBlockingAlerts = alerts.some(alert => alert.type === 'error');
    }

    // Computed properties for status indicators
    get validationStatusClass() {
        if (this.hasBlockingAlerts) return 'status-indicator status-error';
        if (this.validationAlerts.some(alert => alert.type === 'warning')) return 'status-indicator status-pending';
        return 'status-indicator status-active';
    }

    get validationStatusIcon() {
        if (this.hasBlockingAlerts) return 'utility:error';
        if (this.validationAlerts.some(alert => alert.type === 'warning')) return 'utility:warning';
        return 'utility:success';
    }

    get validationStatusText() {
        if (this.hasBlockingAlerts) return 'Validation Failed';
        if (this.validationAlerts.some(alert => alert.type === 'warning')) return 'Warnings Present';
        return 'Validation Passed';
    }

    // Fund status computed properties
    get msaStatusClass() {
        return this.negotiatedAmount <= this.msaAvailable ? 'fund-status-good' : 'fund-status-insufficient';
    }

    get msaStatusText() {
        return this.negotiatedAmount <= this.msaAvailable ? 'Sufficient' : 'Insufficient';
    }

    get pcaStatusClass() {
        return this.pcaAvailable > 1000 ? 'fund-status-good' : 'fund-status-low';
    }

    get pcaStatusText() {
        return this.pcaAvailable > 1000 ? 'Available' : 'Low Balance';
    }

    get sakStatusClass() {
        return this.sakAvailable > 500 ? 'fund-status-good' : 'fund-status-low';
    }

    get sakStatusText() {
        return this.sakAvailable > 500 ? 'Available' : 'Low Balance';
    }

    // Action handlers
    handleApproveAdjudication() {
        if (this.hasBlockingAlerts) {
            this.showToast('Error', 'Cannot approve adjudication with blocking validation errors', 'error');
            return;
        }
        
        this.showToast('Success', 'Adjudication approved successfully', 'success');
        // Implement actual approval logic
    }

    handleRequestReview() {
        this.showToast('Info', 'Additional review requested', 'info');
        // Implement review request logic
    }

    handleDenyClaim() {
        this.showToast('Info', 'Claim denial initiated', 'info');
        // Implement claim denial logic
    }

    // Alert action handlers
    handleCheckAlternativeFunds = () => {
        this.showToast('Info', 'Checking alternative funding sources...', 'info');
        // Implement alternative funds check
    }

    handleRenegotiate = () => {
        this.showToast('Info', 'Initiating renegotiation process...', 'info');
        // Implement renegotiation logic
    }

    handleReviewFees = () => {
        this.showToast('Info', 'Opening fee structure review...', 'info');
        // Implement fee review logic
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

    // Refresh financial data
    async refreshFinancialData() {
        this.isLoading = true;
        try {
            await refreshApex(this.wiredResult);
        } catch (error) {
            this.error = error.message;
            this.isLoading = false;
        }
    }
}