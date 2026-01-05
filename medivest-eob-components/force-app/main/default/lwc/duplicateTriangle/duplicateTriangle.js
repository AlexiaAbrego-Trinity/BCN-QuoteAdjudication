import { LightningElement, api, wire, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import getDuplicateData from '@salesforce/apex/BillLineItemDuplicateHandler.getDuplicateData';

// Default data structure for template safety
const DUPLICATE_DATA_DEFAULT = Object.freeze({
    duplicateStatus: 'None',
    matchingRecords: null,
    lastCheck: null
});

export default class DuplicateTriangle extends NavigationMixin(LightningElement) {
    @api recordId; // Explicit @api decorator
    @track duplicateData = { ...DUPLICATE_DATA_DEFAULT }; // Reactive data structure
    @track isLoading = true; // Loading state management
    @track error;

    @wire(getDuplicateData, { recordId: '$recordId' })
    wiredDuplicateData({ error, data }) {
        this.isLoading = false;
        if (data) {
            this.duplicateData = this.normalizeDuplicateData(data);
            this.error = undefined;
        } else if (error) {
            // Keep defaults so template stays safe
            this.duplicateData = { ...DUPLICATE_DATA_DEFAULT };
            this.error = error;
            // Optional console crumb for debugging
            console.error('[DuplicateTriangle] wire error', error);
        }
    }

    normalizeDuplicateData(incoming) {
        return {
            ...DUPLICATE_DATA_DEFAULT,
            ...incoming,
            duplicateStatus: incoming.duplicateStatus || 'None'
        };
    }

    // ---------- SAFE GETTERS FOR TEMPLATE ----------
    get duplicateStatus() {
        return this.duplicateData?.duplicateStatus || 'None';
    }

    get matchingRecords() {
        return this.duplicateData?.matchingRecords;
    }

    get lastCheck() {
        return this.duplicateData?.lastCheck;
    }

    get showTriangle() {
        return this.duplicateStatus && this.duplicateStatus !== 'None';
    }

    get triangleIcon() {
        return this.duplicateStatus === 'Exact' ? 'utility:success' : 'utility:warning';
    }

    get triangleClass() {
        return this.duplicateStatus === 'Exact' ? 'triangle-green' : 'triangle-orange';
    }

    get triangleAltText() {
        return this.duplicateStatus === 'Exact' ? 'Exact Match' : 'Potential Match';
    }

    get hoverText() {
        const matches = this.matchingRecords ? JSON.parse(this.matchingRecords) : [];
        return `${this.duplicateStatus} duplicate found. ${matches.length} matching record(s).`;
    }

    get hasMatches() {
        const matches = this.matchingRecords ? JSON.parse(this.matchingRecords) : [];
        return matches.length > 0;
    }

    handleTriangleClick() {
        const matches = this.matchingRecords ? JSON.parse(this.matchingRecords) : [];

        if (matches.length === 1) {
            // Navigate to single matching record
            this[NavigationMixin.Navigate]({
                type: 'standard__recordPage',
                attributes: {
                    recordId: matches[0],
                    actionName: 'view'
                }
            });
        } else if (matches.length > 1) {
            // Open comparison modal for multiple matches
            this.openComparisonModal(matches);
        }
    }

    openComparisonModal(matches) {
        // TODO: Implement comparison modal for multiple matches
        console.log('Opening comparison modal for matches:', matches);
    }
}