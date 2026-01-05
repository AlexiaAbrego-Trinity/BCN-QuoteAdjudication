/**
 * @description Trinity-aligned LWC component for duplicate detection triangle indicator
 * @author Trinity Development Team
 * @date 2025-08-30
 * @version 2.0.0
 * 
 * This component follows Trinity design principles:
 * - Default data structures with Object.freeze() for immutability
 * - Comprehensive data normalization methods
 * - Safe getter methods for template access
 * - Loading state management and error handling
 * - Defensive programming patterns throughout
 */
import { LightningElement, api, wire, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getDuplicateData from '@salesforce/apex/TRM_DuplicateDetectionApi.getDuplicateData';
import triggerManualCheck from '@salesforce/apex/TRM_DuplicateDetectionApi.triggerManualCheck';

// Default data structure for template safety (Trinity pattern)
const DUPLICATE_DATA_DEFAULT = Object.freeze({
    duplicateStatus: 'None',
    matches: [],
    lastCheck: null,
    confidence: 0,
    totalMatches: 0,
    sourceRecord: {
        recordId: null,
        recordName: '',
        procedureCode: '',
        chargeAmount: 0,
        serviceStartDate: null,
        serviceEndDate: null,
        patientId: '',
        billExternalId: ''
    },
    configuration: {
        chargeTolerance: 0.01,
        dateWindowYears: 5,
        enableBillWarnings: true,
        enableProviderMatching: false,
        maxMatchesReturned: 50,
        enableConfidenceScoring: true
    }
});

export default class TrmDuplicateTriangle extends NavigationMixin(LightningElement) {
    @api recordId;
    @track duplicateData = { ...DUPLICATE_DATA_DEFAULT };
    @track isLoading = true;
    @track error;
    @track isManualCheckRunning = false;

    // Wire to get duplicate data
    @wire(getDuplicateData, { recordId: '$recordId' })
    wiredDuplicateData({ error, data }) {
        this.isLoading = false;
        if (data) {
            this.duplicateData = this.normalizeDuplicateData(data);
            this.error = undefined;
        } else if (error) {
            this.duplicateData = { ...DUPLICATE_DATA_DEFAULT };
            this.error = error;
            console.error('[TrmDuplicateTriangle] wire error', error);
        }
    }

    /**
     * Trinity pattern: comprehensive data normalization
     * Ensures all data is safe for template consumption
     */
    normalizeDuplicateData(incoming) {
        if (!incoming) {
            return { ...DUPLICATE_DATA_DEFAULT };
        }

        return {
            ...DUPLICATE_DATA_DEFAULT,
            ...incoming,
            matches: Array.isArray(incoming.matches) ? incoming.matches : [],
            sourceRecord: {
                ...DUPLICATE_DATA_DEFAULT.sourceRecord,
                ...(incoming.sourceRecord || {})
            },
            configuration: {
                ...DUPLICATE_DATA_DEFAULT.configuration,
                ...(incoming.configuration || {})
            },
            confidence: incoming.confidence || 0,
            totalMatches: incoming.totalMatches || 0
        };
    }

    // Safe getters for template (Trinity pattern)
    get duplicateStatus() { 
        return this.duplicateData?.duplicateStatus || 'None'; 
    }

    get matches() { 
        return this.duplicateData?.matches || []; 
    }

    get hasMatches() { 
        return this.matches.length > 0; 
    }

    get showTriangle() { 
        return this.duplicateStatus !== 'None' && this.duplicateStatus !== 'Error'; 
    }

    get triangleIcon() { 
        switch (this.duplicateStatus) {
            case 'Exact':
                return 'utility:success';
            case 'Potential':
                return 'utility:warning';
            default:
                return 'utility:info';
        }
    }

    get triangleClass() {
        const baseClass = 'duplicate-triangle';
        const statusClass = this.duplicateStatus === 'Exact' ? 'exact' : 'potential';
        return `${baseClass} ${statusClass}`;
    }

    get triangleVariant() {
        return this.duplicateStatus === 'Exact' ? 'success' : 'warning';
    }

    get hoverText() {
        const status = this.duplicateStatus;
        const count = this.matches.length;
        const lastCheck = this.duplicateData?.lastCheck;
        const confidence = this.duplicateData?.confidence || 0;
        
        if (status === 'None') {
            return 'No duplicates detected';
        }
        
        if (status === 'Error') {
            return 'Error checking for duplicates';
        }

        let text = `${status} duplicate${count > 1 ? 's' : ''} found (${count})`;
        
        if (confidence > 0) {
            text += `\nConfidence: ${confidence.toFixed(1)}%`;
        }
        
        if (lastCheck) {
            const checkDate = new Date(lastCheck);
            text += `\nLast checked: ${checkDate.toLocaleString()}`;
        }
        
        text += '\nClick to view details';
        return text;
    }

    get showManualCheckButton() {
        return !this.isLoading && !this.isManualCheckRunning;
    }

    get manualCheckButtonLabel() {
        return this.isManualCheckRunning ? 'Checking...' : 'Check for Duplicates';
    }

    // Event handlers
    handleTriangleClick() {
        const matches = this.matches;
        
        if (matches.length === 1) {
            // Navigate to single matching record
            this.navigateToRecord(matches[0].recordId);
        } else if (matches.length > 1) {
            // Open comparison modal for multiple matches
            this.openComparisonModal(matches);
        } else {
            // No matches, show info
            this.showToast('Info', 'No matching records to display', 'info');
        }
    }

    handleManualCheck() {
        if (!this.recordId || this.isManualCheckRunning) {
            return;
        }

        this.isManualCheckRunning = true;
        
        triggerManualCheck({ recordId: this.recordId })
            .then(result => {
                this.showToast('Success', result, 'success');
                // Refresh the wire by updating a reactive property
                return this.refreshData();
            })
            .catch(error => {
                console.error('[TrmDuplicateTriangle] Manual check error', error);
                const errorMessage = error.body?.message || error.message || 'Unknown error occurred';
                this.showToast('Error', `Manual check failed: ${errorMessage}`, 'error');
            })
            .finally(() => {
                this.isManualCheckRunning = false;
            });
    }

    // Navigation and utility methods
    navigateToRecord(recordId) {
        if (!recordId) {
            this.showToast('Error', 'Invalid record ID', 'error');
            return;
        }

        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: recordId,
                actionName: 'view'
            }
        });
    }

    openComparisonModal(matches) {
        // ENHANCED: Dispatch event to open proper comparison modal
        // Replaces toast functionality as required by ticket
        const modalData = {
            sourceRecord: {
                recordId: this.recordId,
                recordName: this.duplicateData?.sourceRecord?.recordName || 'Current Record',
                billId: this.duplicateData?.sourceRecord?.billId,
                billExternalId: this.duplicateData?.sourceRecord?.billExternalId,
                patientId: this.duplicateData?.sourceRecord?.patientId,
                procedureCode: this.duplicateData?.sourceRecord?.procedureCode,
                chargeAmount: this.duplicateData?.sourceRecord?.chargeAmount,
                serviceStartDate: this.duplicateData?.sourceRecord?.serviceStartDate
            },
            matches: matches.map(match => ({
                ...match,
                matchTypeClass: this.getMatchTypeClass(match.matchType)
            }))
        };

        // Dispatch event to parent component to open modal
        this.dispatchEvent(new CustomEvent('openduplicatemodal', {
            detail: modalData,
            bubbles: true,
            composed: true
        }));

        console.log('[TrmDuplicateTriangle] Opening comparison modal for', matches.length, 'matches');
    }

    /**
     * @description Get CSS class for match type styling
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

    showToast(title, message, variant) {
        const event = new ShowToastEvent({
            title: title,
            message: message,
            variant: variant,
            mode: variant === 'error' ? 'sticky' : 'dismissable'
        });
        this.dispatchEvent(event);
    }

    async refreshData() {
        // Force refresh of wired data
        // This is a workaround since we can't directly refresh @wire
        try {
            const freshData = await getDuplicateData({ recordId: this.recordId });
            this.duplicateData = this.normalizeDuplicateData(freshData);
            this.error = undefined;
        } catch (error) {
            console.error('[TrmDuplicateTriangle] Refresh error', error);
            this.error = error;
        }
    }

    // Lifecycle hooks
    connectedCallback() {
        // Component initialization if needed
        if (!this.recordId) {
            console.warn('[TrmDuplicateTriangle] No recordId provided');
        }
    }

    disconnectedCallback() {
        // Cleanup if needed
    }

    errorCallback(error, stack) {
        console.error('[TrmDuplicateTriangle] Component error', error, stack);
        this.error = error;
        this.isLoading = false;
    }
}