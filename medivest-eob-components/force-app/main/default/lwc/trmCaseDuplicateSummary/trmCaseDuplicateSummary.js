/**
 * @description Case-level duplicate detection summary component
 * ADDED: For Case-level duplicate detection enhancement
 * Provides immediate visibility of duplicate status on Case record pages
 * 
 * @author Trinity CRM
 * @date 2025-09-01
 * @version 1.0
 */
import { LightningElement, api, wire } from 'lwc';
import { getRecord } from 'lightning/uiRecordApi';
import { refreshApex } from '@salesforce/apex';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getCaseDuplicateSummary from '@salesforce/apex/TRM_DuplicateDetectionApi.getCaseDuplicateSummary';

// Case fields needed for component
const CASE_FIELDS = ['Case.Id', 'Case.CaseNumber', 'Case.BCN__c'];

export default class TrmCaseDuplicateSummary extends LightningElement {
    @api recordId; // Case record ID from record page context
    
    // Component state
    caseSummary = null;
    error = null;
    isLoading = true;
    wiredSummaryResult;
    
    /**
     * @description Wire Case record data
     */
    @wire(getRecord, { recordId: '$recordId', fields: CASE_FIELDS })
    caseRecord;
    
    /**
     * @description Wire Case duplicate summary data
     */
    @wire(getCaseDuplicateSummary, { caseId: '$recordId' })
    wiredCaseSummary(result) {
        this.wiredSummaryResult = result;
        this.isLoading = true;
        
        if (result.data) {
            this.caseSummary = result.data;
            this.error = null;
            this.isLoading = false;
        } else if (result.error) {
            this.error = result.error;
            this.caseSummary = null;
            this.isLoading = false;
            console.error('TrmCaseDuplicateSummary: Error loading summary', result.error);
        }
    }
    
    /**
     * @description Check if component should be visible
     * GETTER: Prevents LWC1060 template expression error
     */
    get showComponent() {
        return this.recordId && !this.isLoading;
    }
    
    /**
     * @description Check if summary data is available
     * GETTER: Prevents LWC1060 template expression error
     */
    get hasSummaryData() {
        return this.caseSummary && !this.error;
    }
    
    /**
     * @description Check if there are any duplicate warnings
     * GETTER: Prevents LWC1060 template expression error
     */
    get hasWarnings() {
        return this.caseSummary && this.caseSummary.hasWarnings;
    }
    
    /**
     * @description Get status icon name based on duplicate status
     * GETTER: Prevents LWC1060 template expression error
     */
    get statusIconName() {
        if (!this.caseSummary) return 'utility:info';
        
        if (this.caseSummary.exactMatches > 0) {
            return 'utility:error';
        } else if (this.caseSummary.potentialMatches > 0) {
            return 'utility:warning';
        }
        return 'utility:success';
    }
    
    /**
     * @description Get status icon variant for styling
     * GETTER: Prevents LWC1060 template expression error
     */
    get statusIconVariant() {
        if (!this.caseSummary) return 'neutral';
        
        if (this.caseSummary.exactMatches > 0) {
            return 'error';
        } else if (this.caseSummary.potentialMatches > 0) {
            return 'warning';
        }
        return 'success';
    }
    
    /**
     * @description Get component CSS classes based on status
     * GETTER: Prevents LWC1060 template expression error
     */
    get componentClasses() {
        let baseClasses = 'case-duplicate-summary slds-card';
        
        if (this.caseSummary && this.caseSummary.statusClass) {
            baseClasses += ' ' + this.caseSummary.statusClass;
        }
        
        return baseClasses;
    }
    
    /**
     * @description Get exact matches label with proper pluralization
     * GETTER: Prevents LWC1060 template expression error
     */
    get exactMatchesLabel() {
        if (!this.caseSummary) return 'Exact Matches';
        const count = this.caseSummary.exactMatches || 0;
        return `Exact Match${count !== 1 ? 'es' : ''}`;
    }
    
    /**
     * @description Get potential matches label with proper pluralization
     * GETTER: Prevents LWC1060 template expression error
     */
    get potentialMatchesLabel() {
        if (!this.caseSummary) return 'Potential Matches';
        const count = this.caseSummary.potentialMatches || 0;
        return `Potential Match${count !== 1 ? 'es' : ''}`;
    }
    
    /**
     * @description Get bills label with proper pluralization
     * GETTER: Prevents LWC1060 template expression error
     */
    get billsLabel() {
        if (!this.caseSummary) return 'Bills';
        const count = this.caseSummary.totalBills || 0;
        return `Bill${count !== 1 ? 's' : ''}`;
    }
    
    /**
     * @description Get line items label with proper pluralization
     * GETTER: Prevents LWC1060 template expression error
     */
    get lineItemsLabel() {
        if (!this.caseSummary) return 'Line Items';
        const count = this.caseSummary.totalLineItems || 0;
        return `Line Item${count !== 1 ? 's' : ''}`;
    }
    
    /**
     * @description Get formatted last check date
     * GETTER: Prevents LWC1060 template expression error
     */
    get formattedLastCheck() {
        if (!this.caseSummary || !this.caseSummary.lastCheckDate) {
            return 'Never checked';
        }
        
        const checkDate = new Date(this.caseSummary.lastCheckDate);
        return checkDate.toLocaleString();
    }
    
    /**
     * @description Handle View All Duplicates button click
     * Opens comprehensive modal with all duplicate matches
     */
    handleViewAllDuplicates() {
        // Dispatch custom event to open comprehensive modal
        const viewAllEvent = new CustomEvent('viewallduplicates', {
            detail: {
                caseId: this.recordId,
                caseSummary: this.caseSummary
            },
            bubbles: true,
            composed: true
        });
        
        this.dispatchEvent(viewAllEvent);
    }
    
    /**
     * @description Handle refresh button click
     * Refreshes the duplicate summary data
     */
    async handleRefresh() {
        this.isLoading = true;
        
        try {
            await refreshApex(this.wiredSummaryResult);
            
            this.dispatchEvent(new ShowToastEvent({
                title: 'Success',
                message: 'Duplicate summary refreshed successfully',
                variant: 'success'
            }));
            
        } catch (error) {
            console.error('TrmCaseDuplicateSummary: Refresh error', error);
            
            this.dispatchEvent(new ShowToastEvent({
                title: 'Error',
                message: 'Failed to refresh duplicate summary: ' + error.body?.message || error.message,
                variant: 'error'
            }));
        }
        
        this.isLoading = false;
    }
}