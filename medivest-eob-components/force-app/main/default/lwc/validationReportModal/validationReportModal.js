/**
 * TRINITY VALIDATION REPORT MODAL - Medivest BCN Quote Adjudication v2.3.0
 * 
 * Professional validation report display for adjudication workflow
 * Shows red line failures and yellow line warnings with clear explanations
 * 
 * DESIGN PRINCIPLES:
 * - Simple, clean, professional (no gradients, minimal whitespace)
 * - Clear pass/fail indicators with color coding
 * - Hover tooltips for rule explanations
 * - Static demo data for client presentation
 * 
 * Trinity Deployment Architect - Anti-Overengineering Applied
 */

import { LightningElement, api, track } from 'lwc';

export default class ValidationReportModal extends LightningElement {
    @api validationResult; // Passed from parent component
    @api isProcessing = false; // TRINITY: Processing state for Proceed button
    @track isValidating = false; // TRINITY FIX: No delay - validation already complete
    @track showPassedRules = false; // TRINITY: Expandable passed rules section

    // Lifecycle hook - no delay needed since validation is done before modal opens
    connectedCallback() {
        // Validation is already complete when modal opens
        // No artificial delay needed
        console.log('ValidationReportModal opened with result:', this.validationResult);
        console.log('TRINITY DEBUG - Passed Rules:', this.validationResult?.passedRules);
        console.log('TRINITY DEBUG - Passed Rules Count:', this.passedRulesCount);
        console.log('TRINITY DEBUG - Has Passed Rules:', this.hasPassedRules);
    }

    // TRINITY: Toggle passed rules section
    togglePassedRules() {
        this.showPassedRules = !this.showPassedRules;
    }

    // Computed properties for UI state
    get hasRedLineFailures() {
        return this.validationResult?.redLineFailures?.length > 0;
    }

    get hasYellowLineWarnings() {
        return this.validationResult?.yellowLineWarnings?.length > 0;
    }

    get canProceed() {
        return this.validationResult?.canProceed === true;
    }

    get validationComplete() {
        return !this.isValidating;
    }

    get statusClass() {
        if (this.isValidating) return 'status-validating';
        if (this.canProceed) return 'status-success';
        return 'status-error';
    }

    get statusIcon() {
        if (this.isValidating) return 'utility:spinner';
        if (this.canProceed) return 'utility:success';
        return 'utility:error';
    }

    get statusText() {
        if (this.isValidating) return 'Validating adjudication rules...';
        if (this.canProceed) return 'Validation Complete - Ready to Adjudicate';
        return 'Validation Failed - Issues Must Be Resolved';
    }

    get caseNumber() {
        return this.validationResult?.caseNumber || 'Unknown';
    }

    get totalLineItems() {
        return this.validationResult?.totalLineItems || 0;
    }

    get totalCharge() {
        return this.formatCurrency(this.validationResult?.totalCharge || 0);
    }

    get totalApproved() {
        return this.formatCurrency(this.validationResult?.totalApproved || 0);
    }

    get redLineFailures() {
        return this.validationResult?.redLineFailures || [];
    }

    get yellowLineWarnings() {
        return this.validationResult?.yellowLineWarnings || [];
    }

    get redLineCount() {
        return this.redLineFailures.length;
    }

    get yellowLineCount() {
        return this.yellowLineWarnings.length;
    }

    // TRINITY PHASE 1.6: Category-specific getters for Ray's 4-section requirement
    // Transform failures to add computed properties for LWC template compatibility
    get bcnLevelFailures() {
        const failures = this.validationResult?.bcnLevelFailures || [];
        return failures.map(f => ({
            ...f,
            isError: f.severity === 'error',
            isWarning: f.severity === 'warning',
            cssClass: f.severity === 'error' ? 'issue-card error-card' : 'issue-card warning-card',
            iconSymbol: f.severity === 'error' ? '✗' : '⚠'
        }));
    }

    get chargeLevelFailures() {
        const failures = this.validationResult?.chargeLevelFailures || [];
        return failures.map(f => ({
            ...f,
            isError: f.severity === 'error',
            isWarning: f.severity === 'warning',
            cssClass: f.severity === 'error' ? 'issue-card error-card' : 'issue-card warning-card',
            iconSymbol: f.severity === 'error' ? '✗' : '⚠'
        }));
    }

    get lineItemFailures() {
        const failures = this.validationResult?.lineItemFailures || [];
        return failures.map(f => ({
            ...f,
            isError: f.severity === 'error',
            isWarning: f.severity === 'warning',
            cssClass: 'issue-card error-card', // Line items are always errors
            iconSymbol: '✗'
        }));
    }

    get relationalIntegrityFailures() {
        const failures = this.validationResult?.relationalIntegrityFailures || [];
        return failures.map(f => ({
            ...f,
            isError: f.severity === 'error',
            isWarning: f.severity === 'warning',
            cssClass: 'issue-card error-card', // Relational integrity are always errors
            iconSymbol: '✗'
        }));
    }

    // Category visibility getters
    get hasBcnLevelFailures() {
        return this.bcnLevelFailures.length > 0;
    }

    get hasChargeLevelFailures() {
        return this.chargeLevelFailures.length > 0;
    }

    get hasLineItemFailures() {
        return this.lineItemFailures.length > 0;
    }

    get hasRelationalIntegrityFailures() {
        return this.relationalIntegrityFailures.length > 0;
    }

    // Category count getters
    get bcnLevelCount() {
        return this.bcnLevelFailures.length;
    }

    get chargeLevelCount() {
        return this.chargeLevelFailures.length;
    }

    get lineItemCount() {
        return this.lineItemFailures.length;
    }

    get relationalIntegrityCount() {
        return this.relationalIntegrityFailures.length;
    }

    // Category error/warning breakdown
    get bcnLevelErrors() {
        return this.bcnLevelFailures.filter(f => f.severity === 'error').length;
    }

    get bcnLevelWarnings() {
        return this.bcnLevelFailures.filter(f => f.severity === 'warning').length;
    }

    get chargeLevelErrors() {
        return this.chargeLevelFailures.filter(f => f.severity === 'error').length;
    }

    get chargeLevelWarnings() {
        return this.chargeLevelFailures.filter(f => f.severity === 'warning').length;
    }

    get lineItemErrors() {
        return this.lineItemFailures.filter(f => f.severity === 'error').length;
    }

    get lineItemWarnings() {
        return this.lineItemFailures.filter(f => f.severity === 'warning').length;
    }

    get relationalIntegrityErrors() {
        return this.relationalIntegrityFailures.filter(f => f.severity === 'error').length;
    }

    get relationalIntegrityWarnings() {
        return this.relationalIntegrityFailures.filter(f => f.severity === 'warning').length;
    }

    // TRINITY: Passed rules getters
    get passedRules() {
        return this.validationResult?.passedRules || [];
    }

    get hasPassedRules() {
        return this.passedRules.length > 0;
    }

    get passedRulesCount() {
        return this.passedRules.length;
    }

    get passedRulesExpandIcon() {
        return this.showPassedRules ? 'utility:chevrondown' : 'utility:chevronright';
    }

    // TRINITY: Proceed button icon (spinner when processing)
    get proceedButtonIcon() {
        return this.isProcessing ? 'utility:spinner' : null;
    }

    // Utility methods
    formatCurrency(value) {
        if (!value) return '$0.00';
        return new Intl.NumberFormat('en-US', {
            style: 'currency',
            currency: 'USD'
        }).format(value);
    }

    formatLineItems(lineItems) {
        if (!lineItems || lineItems.length === 0) return 'None';
        if (lineItems.length <= 5) return `#${lineItems.join(', #')}`;
        return `#${lineItems.slice(0, 5).join(', #')} and ${lineItems.length - 5} more`;
    }

    // Event handlers
    handleClose() {
        this.dispatchEvent(new CustomEvent('close'));
    }

    handleFixIssues() {
        // Close modal and let parent handle navigation to fix issues
        this.dispatchEvent(new CustomEvent('fixissues'));
    }

    handleProceed() {
        // Dispatch event to proceed with adjudication
        this.dispatchEvent(new CustomEvent('proceed'));
    }
}