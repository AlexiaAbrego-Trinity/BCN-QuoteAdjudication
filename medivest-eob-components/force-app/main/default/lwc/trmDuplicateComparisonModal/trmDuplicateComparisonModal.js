/**
 * @description Duplicate comparison modal component
 * @author Trinity Development Team
 * @date 2025-09-01
 * @version 2.0.0
 * 
 * This modal component replaces the toast functionality for multiple matches,
 * providing a proper side-by-side comparison interface with navigation capabilities.
 * 
 * Features:
 * - Side-by-side record comparison
 * - Direct navigation to Bill and Line Item records
 * - Mark as reviewed functionality
 * - Responsive design for different screen sizes
 * - Case and Bill Line Item details display
 */
import { LightningElement, api, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class TrmDuplicateComparisonModal extends NavigationMixin(LightningElement) {
    @api isOpen = false;
    @api sourceRecord;
    @api matches = [];
    
    @track isMarkingReviewed = false;
    
    /**
     * @description Get formatted source record for display
     */
    get formattedSourceRecord() {
        if (!this.sourceRecord) return {};

        return {
            ...this.sourceRecord,
            formattedCharge: this.formatCurrency(this.sourceRecord.chargeAmount),
            formattedServiceDate: this.formatDate(this.sourceRecord.serviceStartDate),
            billUrl: `/lightning/r/Bill__c/${this.sourceRecord.billId}/view`,
            lineItemUrl: `/lightning/r/Bill_Line_Item__c/${this.sourceRecord.recordId}/view`,
            patientId: this.sourceRecord.patientId || 'N/A',
            procedureCode: this.sourceRecord.procedureCode || 'N/A',
            billExternalId: this.sourceRecord.billExternalId || 'N/A'
        };
    }
    
    /**
     * @description Get formatted matches for display
     */
    get formattedMatches() {
        if (!this.matches || !Array.isArray(this.matches)) return [];
        
        return this.matches.map(match => ({
            ...match,
            formattedCharge: this.formatCurrency(match.chargeAmount),
            formattedServiceDate: this.formatDate(match.serviceStartDate),
            billUrl: `/lightning/r/Bill__c/${match.billId}/view`,
            lineItemUrl: `/lightning/r/Bill_Line_Item__c/${match.recordId}/view`,
            matchTypeClass: this.getMatchTypeClass(match.matchType),
            matchTypeLabel: this.getMatchTypeLabel(match.matchType)
        }));
    }
    
    /**
     * @description Get match count for display
     */
    get matchCount() {
        return this.matches ? this.matches.length : 0;
    }
    
    /**
     * @description Check if modal should be visible
     */
    get showModal() {
        return this.isOpen && this.sourceRecord && this.matchCount > 0;
    }

    /**
     * @description Get mark reviewed button label
     * ADDED: Fix for LWC1060 - Template expressions don't allow ConditionalExpression
     */
    get markReviewedButtonLabel() {
        return this.isMarkingReviewed ? 'Marking Reviewed...' : 'Mark as Reviewed';
    }
    
    /**
     * @description Format currency amount
     */
    formatCurrency(amount) {
        if (amount === null || amount === undefined) return 'N/A';
        return new Intl.NumberFormat('en-US', {
            style: 'currency',
            currency: 'USD'
        }).format(amount);
    }
    
    /**
     * @description Format date for display
     */
    formatDate(dateString) {
        if (!dateString) return 'N/A';
        try {
            return new Date(dateString).toLocaleDateString('en-US', {
                year: 'numeric',
                month: 'short',
                day: '2-digit'
            });
        } catch (error) {
            return 'Invalid Date';
        }
    }
    
    /**
     * @description Get CSS class for match type
     */
    getMatchTypeClass(matchType) {
        switch (matchType?.toLowerCase()) {
            case 'exact':
                return 'match-type exact-match';
            case 'potential':
                return 'match-type potential-match';
            default:
                return 'match-type unknown-match';
        }
    }
    
    /**
     * @description Get display label for match type
     */
    getMatchTypeLabel(matchType) {
        switch (matchType?.toLowerCase()) {
            case 'exact':
                return 'Exact Match';
            case 'potential':
                return 'Potential Match';
            default:
                return 'Unknown Match';
        }
    }
    
    /**
     * @description Handle modal close
     */
    handleClose() {
        this.isOpen = false;
        this.dispatchEvent(new CustomEvent('modalclose'));
    }
    
    /**
     * @description Handle view Bill record
     */
    handleViewBill(event) {
        const billId = event.target.dataset.billId;
        if (!billId) return;
        
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: billId,
                objectApiName: 'Bill__c',
                actionName: 'view'
            }
        });
    }
    
    /**
     * @description Handle view Line Item record
     */
    handleViewLineItem(event) {
        const recordId = event.target.dataset.recordId;
        if (!recordId) return;
        
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: recordId,
                objectApiName: 'Bill_Line_Item__c',
                actionName: 'view'
            }
        });
    }
    
    /**
     * @description Handle view source Bill record
     */
    handleViewSourceBill() {
        if (!this.sourceRecord?.billId) return;
        
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: this.sourceRecord.billId,
                objectApiName: 'Bill__c',
                actionName: 'view'
            }
        });
    }
    
    /**
     * @description Handle view source Line Item record
     */
    handleViewSourceLineItem() {
        if (!this.sourceRecord?.recordId) return;
        
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: this.sourceRecord.recordId,
                objectApiName: 'Bill_Line_Item__c',
                actionName: 'view'
            }
        });
    }
    
    /**
     * @description Handle mark as reviewed
     */
    async handleMarkReviewed() {
        this.isMarkingReviewed = true;
        
        try {
            // Dispatch event to parent component to handle the review marking
            this.dispatchEvent(new CustomEvent('markreviewed', {
                detail: {
                    sourceRecordId: this.sourceRecord?.recordId,
                    matchIds: this.matches.map(match => match.recordId)
                }
            }));
            
            this.showToast('Success', 'Records marked as reviewed', 'success');
            this.handleClose();
            
        } catch (error) {
            console.error('[TrmDuplicateComparisonModal] Mark reviewed error:', error);
            this.showToast('Error', 'Failed to mark records as reviewed', 'error');
        } finally {
            this.isMarkingReviewed = false;
        }
    }
    
    /**
     * @description Show toast message
     */
    showToast(title, message, variant) {
        const event = new ShowToastEvent({
            title: title,
            message: message,
            variant: variant,
            mode: variant === 'error' ? 'sticky' : 'dismissable'
        });
        this.dispatchEvent(event);
    }
    
    /**
     * @description Handle keyboard events for accessibility
     */
    handleKeyDown(event) {
        if (event.key === 'Escape') {
            this.handleClose();
        }
    }
    
    /**
     * @description Component lifecycle - connected callback
     */
    connectedCallback() {
        // Add keyboard event listener for accessibility
        document.addEventListener('keydown', this.handleKeyDown.bind(this));
    }
    
    /**
     * @description Component lifecycle - disconnected callback
     */
    disconnectedCallback() {
        // Remove keyboard event listener
        document.removeEventListener('keydown', this.handleKeyDown.bind(this));
    }
}