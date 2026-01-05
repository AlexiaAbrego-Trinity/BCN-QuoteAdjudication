import { LightningElement, api, track } from 'lwc';
import searchCodes from '@salesforce/apex/TRM_MedicalBillingService.searchCodes';
import getCodeDetails from '@salesforce/apex/TRM_MedicalBillingService.getCodeDetails';

/**
 * TRINITY: Enhanced Code Lookup Field with Code-Only Display
 * RAY'S REQUIREMENT: Type to search, show dropdown, store code + description
 * CLIENT REQUIREMENT (10/29 meeting): Display ONLY code value, NOT description
 * TOOLTIP ENHANCEMENT: Hover tooltip shows description (future enhancement)
 * ANTI-OVERENGINEERING: Simple input + dropdown, no complex SLDS patterns
 * v2.7.2: Tab-out auto-save - validate and save on blur without requiring selection
 */
export default class CodeLookupField extends LightningElement {
    // Public API properties
    @api fieldName;
    @api currentValue = ''; // The CODE value (e.g., "0450")
    @api currentDescription = ''; // The DESCRIPTION value for display
    @api codeTypes = [];
    @api placeholder = 'Search codes...';
    @api allowCustomEntry = false;

    // Internal state
    @track searchTerm = '';
    @track searchResults = [];
    @track showDropdown = false;
    @track isSearching = false;
    @track validationError = ''; // v2.7.2: Show validation error if code invalid

    searchTimeout;
    storedCode = ''; // Store the actual code value
    storedDescription = ''; // Store the description for display

    /**
     * CLIENT REQUIREMENT (10/29 meeting): Display ONLY code value
     * Chris: "Just the codes in those two fields" (line 242)
     * Nathan: "Yeah, it'll just be the codes in those two fields" (line 244)
     * NEVER show description in the input field - only code value
     */
    get displayValue() {
        // Priority: currentValue (code) > storedCode
        // NEVER return description - client wants code-only display
        return this.currentValue || this.storedCode || '';
    }

    /**
     * v2.7.2: Input class with error state
     */
    get inputClass() {
        return this.validationError ? 'lookup-input error' : 'lookup-input';
    }

    /**
     * Initialize - set up display value based on current code
     * CLIENT REQUIREMENT: Show code only, NOT description
     */
    async connectedCallback() {
        if (this.currentValue) {
            this.storedCode = this.currentValue;
            this.searchTerm = this.currentValue; // Show code, not description
        }

        // Store description for future tooltip enhancement, but don't display it
        if (this.currentDescription) {
            this.storedDescription = this.currentDescription;
        } else if (this.currentValue) {
            // Fetch the description for future tooltip use (not for display)
            await this.fetchCodeDescription(this.currentValue);
        }
    }

    /**
     * Fetch description for a code value (for future tooltip use)
     * CLIENT REQUIREMENT: Store description but NEVER display it in input field
     */
    async fetchCodeDescription(codeValue) {
        try {
            const codeDetails = await getCodeDetails({
                codeName: codeValue,
                codeTypes: this.codeTypes
            });

            if (codeDetails && codeDetails.description) {
                this.storedDescription = codeDetails.description;
                // CLIENT REQUIREMENT: Show code only, not description
                this.searchTerm = codeValue;
            } else {
                // No description found, show the code itself
                this.searchTerm = codeValue;
            }
        } catch (error) {
            console.error('Error fetching code description:', error);
            // Fallback to showing the code
            this.searchTerm = codeValue;
        }
    }

    /**
     * Handle input - debounced search
     */
    handleInput(event) {
        this.searchTerm = event.target.value;

        // v2.7.2: Clear validation error when user starts typing
        this.validationError = '';

        // Clear previous timeout
        if (this.searchTimeout) {
            clearTimeout(this.searchTimeout);
        }

        // Debounce search
        this.searchTimeout = setTimeout(() => {
            this.performSearch();
        }, 300);
    }

    /**
     * Perform search via Apex
     * TRINITY TOOLTIP ENHANCEMENT: Format results to show "Description (Code)" for better UX
     */
    async performSearch() {
        // Minimum 2 characters
        if (!this.searchTerm || this.searchTerm.length < 2) {
            this.searchResults = [];
            this.showDropdown = false;
            return;
        }

        this.isSearching = true;

        try {
            console.log('Searching for:', this.searchTerm, 'Types:', this.codeTypes);

            const results = await searchCodes({
                searchTerm: this.searchTerm,
                codeTypes: this.codeTypes,
                limitCount: 10
            });

            console.log('Search results:', results);

            // TRINITY: Format results to show description prominently with code in parentheses
            this.searchResults = (results || []).map(result => ({
                ...result,
                displayText: result.description
                    ? `(${result.codeName}) ${result.description} `
                    : result.codeName
            }));

            this.showDropdown = this.searchResults.length > 0;

        } catch (error) {
            console.error('Search error:', error);
            this.searchResults = [];
            this.showDropdown = false;
        } finally {
            this.isSearching = false;
        }
    }

    /**
     * Handle code selection
     * CLIENT REQUIREMENT (10/29 meeting): Display CODE ONLY in field, not description
     * Store description for future tooltip enhancement
     */
    handleSelect(event) {
        const codeId = event.currentTarget.dataset.codeId;
        const selected = this.searchResults.find(r => r.codeId === codeId);

        if (selected) {
            // CLIENT REQUIREMENT: Display CODE only in the field, not description
            this.searchTerm = selected.codeName;
            this.storedCode = selected.codeName;
            this.storedDescription = selected.description || '';
            this.showDropdown = false;

            // v2.7.2: Clear validation error on successful selection
            this.validationError = '';

            // Dispatch event with BOTH code and description
            // Parent grid will store code value and cache description for tooltip
            this.dispatchEvent(new CustomEvent('codeselected', {
                detail: {
                    fieldName: this.fieldName,
                    codeName: selected.codeName,
                    description: selected.description || '',
                    codeId: selected.codeId
                }
            }));
        }
    }

    /**
     * Handle Enter key (input field level)
     */
    handleKeyDown(event) {
        if (event.key === 'Enter') {
            if (this.allowCustomEntry) {
                // Allow custom code entry
                this.showDropdown = false;
                this.dispatchEvent(new CustomEvent('codeselected', {
                    detail: {
                        fieldName: this.fieldName,
                        codeName: this.searchTerm,
                        description: ''
                    }
                }));
            }
        } else if (event.key === 'Escape') {
            this.showDropdown = false;
        }
    }

    /**
     * Handle blur - v2.7.2: Validate and auto-save on tab-out
     * CLIENT REQUIREMENT: Allow tab-out without selection if code is valid
     * Show error if code is invalid
     */
    async handleBlur() {
        // Delay to allow dropdown click to register first
        setTimeout(async () => {
            this.showDropdown = false;

            // v2.7.2: Validate entered code on blur
            if (this.searchTerm && this.searchTerm.trim() !== '') {
                await this.validateAndSaveCode();
            }
        }, 200);
    }

    /**
     * v2.7.2: Validate entered code and auto-save if valid
     * Called on blur (tab-out) to allow saving without dropdown selection
     */
    async validateAndSaveCode() {
        const enteredCode = this.searchTerm.trim();

        // Clear previous validation error
        this.validationError = '';

        // If code hasn't changed from stored value, no validation needed
        if (enteredCode === this.storedCode) {
            return;
        }

        try {
            // Fetch code details to validate
            const codeDetails = await getCodeDetails({
                codeName: enteredCode,
                codeTypes: this.codeTypes
            });

            if (codeDetails && codeDetails.codeName) {
                // Valid code found - auto-save it
                this.storedCode = codeDetails.codeName;
                this.storedDescription = codeDetails.description || '';
                this.searchTerm = codeDetails.codeName;

                // Dispatch event to parent for auto-save
                this.dispatchEvent(new CustomEvent('codeselected', {
                    detail: {
                        fieldName: this.fieldName,
                        codeName: codeDetails.codeName,
                        description: codeDetails.description || '',
                        codeId: codeDetails.codeId
                    }
                }));

                console.log('Code validated and saved:', codeDetails.codeName);
            } else {
                // Invalid code - show error
                this.validationError = `Invalid code: "${enteredCode}" not found`;
                console.warn('Invalid code entered:', enteredCode);
            }
        } catch (error) {
            // Error fetching code - show validation error
            this.validationError = `Invalid code: "${enteredCode}" not found`;
            console.error('Error validating code:', error);
        }
    }

    /**
     * Handle focus - show results if available
     */
    handleFocus() {
        if (this.searchResults.length > 0) {
            this.showDropdown = true;
        }
    }
}