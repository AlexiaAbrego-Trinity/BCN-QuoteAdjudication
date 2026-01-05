import { LightningElement, api, wire, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';
import getBillFlagsData from '@salesforce/apex/TRM_MedicalBillingService.getBillFlagsData';

/**
 * @description Bill Flags Manager - Ray's Color-Coded Flag System
 * @author Trinity Deployment Architect
 * @date 2025-01-09
 * 
 * RAY'S REQUIREMENTS: Complex flagging with color-coded visual indicators
 * TRINITY PRINCIPLE: Never hardcode data - always use real Salesforce fields
 * MVADM-77 COMPLIANT: Complete bill flags management system
 */
export default class BillFlagsManager extends LightningElement {
    @api recordId; // Case ID from record page context
    
    @track flagsData = {};
    @track isLoading = true;
    @track error = null;
    @track isExpanded = false;
    @track isSaving = false;
    
    // Flag type options based on Ray's requirements
    flagTypeOptions = [
        { label: 'Special Handling', value: 'Special Handling' },
        { label: 'Exhaustion', value: 'Exhaustion' },
        { label: 'Future Review', value: 'Future Review' },
        { label: 'Forced Closure', value: 'Forced Closure' }
    ];
    
    // Special Handling sub-types from Ray's detailed requirements
    specialHandlingSubTypes = [
        { label: 'Activity Report - Post-Check Run', value: 'Activity Report - Post-Check Run' },
        { label: 'E-mail Tracking', value: 'E-mail Tracking' },
        { label: 'Payment - Wire Transfer', value: 'Payment - Wire Transfer' },
        { label: 'Payment - Direct Deposit', value: 'Payment - Direct Deposit' },
        { label: 'Separate Check Printing', value: 'Separate Check Printing' },
        { label: 'Shipping - Adult Signature Required', value: 'Shipping - Adult Signature Required' },
        { label: 'Shipping - Direct Signature Required', value: 'Shipping - Direct Signature Required' },
        { label: 'Shipping - Express Saver (FedEx)', value: 'Shipping - Express Saver (FedEx)' },
        { label: 'Shipping - International Shipment', value: 'Shipping - International Shipment' },
        { label: 'Shipping - Overnight Shipment', value: 'Shipping - Overnight Shipment' },
        { label: 'Overnight/Separate Check Print', value: 'Overnight/Separate Check Print' },
        { label: 'Shipping - Overnight to CA Office', value: 'Shipping - Overnight to CA Office' },
        { label: 'Shipping - Two Day FedEx', value: 'Shipping - Two Day FedEx' },
        { label: 'Shipping - FedEx "Saturday" delivery', value: 'Shipping - FedEx "Saturday" delivery' },
        { label: 'Special - See Note', value: 'Special - See Note' }
    ];

    // Wire to get bill flags data - NEVER HARDCODE, ALWAYS USE REAL FIELDS
    @wire(getBillFlagsData, { caseId: '$recordId' })
    wiredFlagsData(result) {
        this.wiredResult = result;
        if (result.data) {
            this.flagsData = { ...result.data };
            this.error = null;
            this.isLoading = false;
        } else if (result.error) {
            this.error = result.error.body?.message || 'Error loading bill flags data';
            this.isLoading = false;
            console.error('Error loading bill flags data:', result.error);
        }
    }

    // Computed properties for UI state
    get hasActiveFlags() {
        return this.flagsData.hasActiveFlags || false;
    }

    get flagStatus() {
        return this.flagsData.flagStatus || 'None';
    }

    get flagColor() {
        return this.flagsData.flagColor || 'light';
    }

    get activeFlagCount() {
        let count = 0;
        if (this.flagsData.exhaustAccount) count++;
        if (this.flagsData.specialHandling) count++;
        if (this.flagsData.holdForMember) count++;
        return count;
    }

    get flagTriangleClass() {
        const baseClass = 'flag-triangle';
        const statusClass = this.flagStatus.toLowerCase();
        return `${baseClass} ${statusClass}`;
    }

    get containerClass() {
        return this.isExpanded ? 'flags-container expanded' : 'flags-container collapsed';
    }

    get toggleButtonLabel() {
        return this.isExpanded ? 'Collapse Flags' : 'Expand Flags';
    }

    get toggleButtonIcon() {
        return this.isExpanded ? 'utility:chevronup' : 'utility:chevrondown';
    }

    get showFlagDetails() {
        return this.isExpanded && this.hasActiveFlags;
    }

    get exhaustAccountLabel() {
        return this.flagsData.exhaustAccount ? 'Account Exhausted' : 'Account Active';
    }

    get specialHandlingLabel() {
        return this.flagsData.specialHandling ? 'Special Handling Required' : 'Standard Processing';
    }

    get holdForMemberLabel() {
        return this.flagsData.holdForMember ? 'Hold for Member' : 'No Hold';
    }

    get flagStatusBadgeClass() {
        const baseClass = 'flag-status-badge';
        switch (this.flagStatus) {
            case 'Incomplete': return `${baseClass} incomplete`;
            case 'Pending': return `${baseClass} pending`;
            case 'Resolved': return `${baseClass} resolved`;
            default: return `${baseClass} none`;
        }
    }

    get memberAccountInfo() {
        if (!this.flagsData.memberAccountName) return 'No account information';
        return `${this.flagsData.memberAccountName} (${this.flagsData.sakStatus || 'Unknown Status'})`;
    }

    get formattedHoldDate() {
        if (!this.flagsData.holdDate) return 'No hold date';
        return new Date(this.flagsData.holdDate).toLocaleDateString();
    }

    // Event handlers
    handleToggle() {
        this.isExpanded = !this.isExpanded;
    }

    handleRefresh() {
        this.isLoading = true;
        return refreshApex(this.wiredResult);
    }

    // Error handling
    showErrorToast(title, message) {
        this.dispatchEvent(new ShowToastEvent({
            title: title,
            message: message,
            variant: 'error',
            mode: 'sticky'
        }));
    }

    showSuccessToast(title, message) {
        this.dispatchEvent(new ShowToastEvent({
            title: title,
            message: message,
            variant: 'success'
        }));
    }

    connectedCallback() {
        console.log('Bill Flags Manager loaded for Case:', this.recordId);
    }
}