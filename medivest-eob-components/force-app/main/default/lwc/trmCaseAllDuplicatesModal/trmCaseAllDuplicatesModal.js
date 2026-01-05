/**
 * @description Comprehensive modal showing ALL duplicate matches across entire Case
 * ADDED: For Case-level duplicate detection enhancement
 * Provides advanced filtering, grouping, and navigation capabilities
 * 
 * @author Trinity CRM
 * @date 2025-09-01
 * @version 1.0
 */
import { LightningElement, api, track, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getCaseAllDuplicateMatches from '@salesforce/apex/TRM_DuplicateDetectionApi.getCaseAllDuplicateMatches';

export default class TrmCaseAllDuplicatesModal extends NavigationMixin(LightningElement) {
    @api isOpen = false;
    @api caseId;
    @api caseSummary;
    
    // Component state
    @track allMatches = [];
    @track filteredMatches = [];
    @track isLoading = false;
    @track error = null;
    
    // Filtering and sorting state
    @track selectedMatchType = 'All';
    @track searchTerm = '';
    @track sortField = 'confidence';
    @track sortDirection = 'desc';
    @track groupByMatchType = true;
    
    // Modal state
    @track showFilters = false;
    
    /**
     * @description Wire all duplicate matches for the Case
     */
    @wire(getCaseAllDuplicateMatches, { caseId: '$caseId' })
    wiredMatches({ error, data }) {
        this.isLoading = true;
        
        if (data) {
            this.allMatches = data;
            this.error = null;
            this.applyFiltersAndSort();
        } else if (error) {
            this.error = error;
            this.allMatches = [];
            this.filteredMatches = [];
            console.error('TrmCaseAllDuplicatesModal: Error loading matches', error);
        }
        
        this.isLoading = false;
    }
    
    /**
     * @description Check if modal should be visible
     * GETTER: Prevents LWC1060 template expression error
     */
    get showModal() {
        return this.isOpen && this.caseId;
    }
    
    /**
     * @description Check if matches data is available
     * GETTER: Prevents LWC1060 template expression error
     */
    get hasMatches() {
        return this.filteredMatches && this.filteredMatches.length > 0;
    }
    
    /**
     * @description Get modal title with match count
     * GETTER: Prevents LWC1060 template expression error
     */
    get modalTitle() {
        const totalCount = this.allMatches.length;
        const filteredCount = this.filteredMatches.length;
        
        if (totalCount === 0) {
            return 'All Duplicate Matches';
        }
        
        if (filteredCount === totalCount) {
            return `All Duplicate Matches (${totalCount})`;
        }
        
        return `Duplicate Matches (${filteredCount} of ${totalCount})`;
    }
    
    /**
     * @description Get match type filter options
     * GETTER: Prevents LWC1060 template expression error
     */
    get matchTypeOptions() {
        return [
            { label: 'All Types', value: 'All' },
            { label: 'Exact Matches', value: 'Exact' },
            { label: 'Potential Matches', value: 'Potential' }
        ];
    }
    
    /**
     * @description Get sort field options
     * GETTER: Prevents LWC1060 template expression error
     */
    get sortFieldOptions() {
        return [
            { label: 'Confidence', value: 'confidence' },
            { label: 'Charge Amount', value: 'chargeAmount' },
            { label: 'Service Date', value: 'serviceStartDate' },
            { label: 'Match Type', value: 'matchType' },
            { label: 'Bill External ID', value: 'billExternalId' }
        ];
    }
    
    /**
     * @description Get grouped matches for display
     * GETTER: Prevents LWC1060 template expression error
     */
    get groupedMatches() {
        if (!this.groupByMatchType) {
            return [{ 
                groupTitle: null, 
                matches: this.filteredMatches,
                groupClass: 'ungrouped-matches'
            }];
        }
        
        const exactMatches = this.filteredMatches.filter(match => match.matchType === 'Exact');
        const potentialMatches = this.filteredMatches.filter(match => match.matchType === 'Potential');
        
        const groups = [];
        
        if (exactMatches.length > 0) {
            groups.push({
                groupTitle: `Exact Matches (${exactMatches.length})`,
                matches: exactMatches,
                groupClass: 'exact-matches-group'
            });
        }
        
        if (potentialMatches.length > 0) {
            groups.push({
                groupTitle: `Potential Matches (${potentialMatches.length})`,
                matches: potentialMatches,
                groupClass: 'potential-matches-group'
            });
        }
        
        return groups;
    }
    
    /**
     * @description Get filters toggle button label
     * GETTER: Prevents LWC1060 template expression error
     */
    get filtersToggleLabel() {
        return this.showFilters ? 'Hide Filters' : 'Show Filters';
    }
    
    /**
     * @description Get filters toggle icon
     * GETTER: Prevents LWC1060 template expression error
     */
    get filtersToggleIcon() {
        return this.showFilters ? 'utility:chevronup' : 'utility:chevrondown';
    }
    
    /**
     * @description Handle modal close
     */
    handleClose() {
        this.isOpen = false;
        
        // Dispatch close event
        const closeEvent = new CustomEvent('modalclose', {
            bubbles: true,
            composed: true
        });
        this.dispatchEvent(closeEvent);
    }
    
    /**
     * @description Handle match type filter change
     */
    handleMatchTypeChange(event) {
        this.selectedMatchType = event.detail.value;
        this.applyFiltersAndSort();
    }
    
    /**
     * @description Handle search input change
     */
    handleSearchChange(event) {
        this.searchTerm = event.target.value;
        this.applyFiltersAndSort();
    }
    
    /**
     * @description Handle sort field change
     */
    handleSortFieldChange(event) {
        this.sortField = event.detail.value;
        this.applyFiltersAndSort();
    }
    
    /**
     * @description Handle sort direction toggle
     */
    handleSortDirectionToggle() {
        this.sortDirection = this.sortDirection === 'asc' ? 'desc' : 'asc';
        this.applyFiltersAndSort();
    }
    
    /**
     * @description Handle group by toggle
     */
    handleGroupByToggle(event) {
        this.groupByMatchType = event.target.checked;
    }
    
    /**
     * @description Handle filters toggle
     */
    handleFiltersToggle() {
        this.showFilters = !this.showFilters;
    }
    
    /**
     * @description Handle navigate to Case
     */
    handleNavigateToCase(event) {
        const caseId = event.currentTarget.dataset.caseId;
        
        if (caseId) {
            this[NavigationMixin.Navigate]({
                type: 'standard__recordPage',
                attributes: {
                    recordId: caseId,
                    objectApiName: 'Case',
                    actionName: 'view'
                }
            });
        }
    }
    
    /**
     * @description Handle navigate to Bill Line Item
     */
    handleNavigateToLineItem(event) {
        const recordId = event.currentTarget.dataset.recordId;
        
        if (recordId) {
            this[NavigationMixin.Navigate]({
                type: 'standard__recordPage',
                attributes: {
                    recordId: recordId,
                    objectApiName: 'Bill_Line_Item__c',
                    actionName: 'view'
                }
            });
        }
    }

    /**
     * @description Apply filters and sorting to matches
     */
    applyFiltersAndSort() {
        let filtered = [...this.allMatches];

        // Apply match type filter
        if (this.selectedMatchType !== 'All') {
            filtered = filtered.filter(match => match.matchType === this.selectedMatchType);
        }

        // Apply search filter
        if (this.searchTerm) {
            const searchLower = this.searchTerm.toLowerCase();
            filtered = filtered.filter(match =>
                (match.recordName && match.recordName.toLowerCase().includes(searchLower)) ||
                (match.billExternalId && match.billExternalId.toLowerCase().includes(searchLower)) ||
                (match.procedureCode && match.procedureCode.toLowerCase().includes(searchLower)) ||
                (match.patientId && match.patientId.toLowerCase().includes(searchLower))
            );
        }

        // Apply sorting
        filtered.sort((a, b) => {
            let aValue = a[this.sortField];
            let bValue = b[this.sortField];

            // Handle null/undefined values
            if (aValue == null && bValue == null) return 0;
            if (aValue == null) return this.sortDirection === 'asc' ? -1 : 1;
            if (bValue == null) return this.sortDirection === 'asc' ? 1 : -1;

            // Handle different data types
            if (typeof aValue === 'string') {
                aValue = aValue.toLowerCase();
                bValue = bValue.toLowerCase();
            }

            let comparison = 0;
            if (aValue < bValue) {
                comparison = -1;
            } else if (aValue > bValue) {
                comparison = 1;
            }

            return this.sortDirection === 'asc' ? comparison : -comparison;
        });

        this.filteredMatches = filtered;
    }

    /**
     * @description Handle clear all filters
     */
    handleClearFilters() {
        this.selectedMatchType = 'All';
        this.searchTerm = '';
        this.sortField = 'confidence';
        this.sortDirection = 'desc';
        this.applyFiltersAndSort();

        // Clear search input
        const searchInput = this.template.querySelector('lightning-input[data-id="search"]');
        if (searchInput) {
            searchInput.value = '';
        }
    }

    /**
     * @description Handle export to CSV
     */
    handleExportCSV() {
        if (!this.hasMatches) {
            this.dispatchEvent(new ShowToastEvent({
                title: 'No Data',
                message: 'No duplicate matches to export',
                variant: 'warning'
            }));
            return;
        }

        try {
            // Create CSV content
            const headers = [
                'Record Name', 'Match Type', 'Confidence', 'Charge Amount',
                'Service Start Date', 'Service End Date', 'Procedure Code',
                'Patient ID', 'Bill External ID', 'Created Date', 'Created By'
            ];

            const csvRows = [headers.join(',')];

            this.filteredMatches.forEach(match => {
                const row = [
                    this.escapeCsvValue(match.recordName),
                    this.escapeCsvValue(match.matchTypeLabel),
                    this.escapeCsvValue(match.confidenceLabel),
                    this.escapeCsvValue(match.formattedChargeAmount),
                    this.escapeCsvValue(match.formattedServiceDates),
                    this.escapeCsvValue(match.serviceEndDate ? match.serviceEndDate.toISOString().split('T')[0] : ''),
                    this.escapeCsvValue(match.procedureCode),
                    this.escapeCsvValue(match.patientId),
                    this.escapeCsvValue(match.billExternalId),
                    this.escapeCsvValue(match.createdDate ? match.createdDate.toISOString() : ''),
                    this.escapeCsvValue(match.createdBy)
                ];
                csvRows.push(row.join(','));
            });

            // Create and download file
            const csvContent = csvRows.join('\n');
            const blob = new Blob([csvContent], { type: 'text/csv' });
            const url = window.URL.createObjectURL(blob);

            const link = document.createElement('a');
            link.href = url;
            link.download = `case-duplicates-${this.caseId}-${new Date().toISOString().split('T')[0]}.csv`;
            link.click();

            window.URL.revokeObjectURL(url);

            this.dispatchEvent(new ShowToastEvent({
                title: 'Success',
                message: 'Duplicate matches exported successfully',
                variant: 'success'
            }));

        } catch (error) {
            console.error('TrmCaseAllDuplicatesModal: Export error', error);
            this.dispatchEvent(new ShowToastEvent({
                title: 'Error',
                message: 'Failed to export duplicate matches: ' + error.message,
                variant: 'error'
            }));
        }
    }

    /**
     * @description Escape CSV values to handle commas and quotes
     */
    escapeCsvValue(value) {
        if (value == null) return '';

        const stringValue = String(value);
        if (stringValue.includes(',') || stringValue.includes('"') || stringValue.includes('\n')) {
            return '"' + stringValue.replace(/"/g, '""') + '"';
        }
        return stringValue;
    }
}