import { LightningElement, api, track } from 'lwc';

/**
 * TRINITY: Lightweight Hover Tooltip Component
 * PURPOSE: Reusable tooltip for collapsed columns with smart positioning
 * ANTI-OVERENGINEERING: Simple hover mechanics, no complex animations
 */
export default class HoverTooltip extends LightningElement {
    // Public API properties
    @api content = ''; // HTML content to display in tooltip
    @api position = 'top'; // Preferred position: top, bottom, left, right
    @api maxWidth = '350px'; // Maximum width of tooltip
    @api delay = 200; // Delay before showing tooltip (ms)

    // Internal state
    @track showTooltip = false;
    @track calculatedPosition = 'top';
    
    showTimeout;
    hideTimeout;

    /**
     * Handle mouse enter - show tooltip after delay
     */
    handleMouseEnter() {
        // Clear any pending hide timeout
        if (this.hideTimeout) {
            clearTimeout(this.hideTimeout);
            this.hideTimeout = null;
        }

        // Set show timeout for smooth UX
        this.showTimeout = setTimeout(() => {
            this.showTooltip = true;
            this.calculatePosition();
            this.injectContent();
        }, this.delay);
    }

    /**
     * TRINITY: Inject HTML content into tooltip using lwc:dom="manual"
     * SECURITY: Content should be sanitized by parent component
     */
    injectContent() {
        try {
            const tooltipInner = this.template.querySelector('.tooltip-inner');
            if (tooltipInner && this.content) {
                tooltipInner.innerHTML = this.content;
            }
        } catch (error) {
            console.error('Error injecting tooltip content:', error);
        }
    }

    /**
     * Handle mouse leave - hide tooltip after brief delay
     */
    handleMouseLeave() {
        // Clear any pending show timeout
        if (this.showTimeout) {
            clearTimeout(this.showTimeout);
            this.showTimeout = null;
        }

        // Brief delay before hiding to prevent flicker
        this.hideTimeout = setTimeout(() => {
            this.showTooltip = false;
        }, 100);
    }

    /**
     * TRINITY: Smart positioning - adjust based on viewport constraints
     * ANTI-OVERENGINEERING: Simple edge detection, no complex collision algorithms
     */
    calculatePosition() {
        try {
            const tooltipElement = this.template.querySelector('.tooltip');
            const triggerElement = this.template.querySelector('.tooltip-trigger');
            
            if (!tooltipElement || !triggerElement) return;

            const triggerRect = triggerElement.getBoundingClientRect();
            const tooltipRect = tooltipElement.getBoundingClientRect();
            const viewportWidth = window.innerWidth;
            const viewportHeight = window.innerHeight;

            let finalPosition = this.position;

            // Check if tooltip would overflow viewport and adjust position
            if (this.position === 'top' && triggerRect.top < tooltipRect.height + 10) {
                finalPosition = 'bottom';
            } else if (this.position === 'bottom' && triggerRect.bottom + tooltipRect.height + 10 > viewportHeight) {
                finalPosition = 'top';
            } else if (this.position === 'left' && triggerRect.left < tooltipRect.width + 10) {
                finalPosition = 'right';
            } else if (this.position === 'right' && triggerRect.right + tooltipRect.width + 10 > viewportWidth) {
                finalPosition = 'left';
            }

            this.calculatedPosition = finalPosition;
        } catch (error) {
            console.error('Error calculating tooltip position:', error);
            this.calculatedPosition = this.position;
        }
    }

    /**
     * Computed CSS class for tooltip positioning
     */
    get tooltipClass() {
        return `tooltip tooltip-${this.calculatedPosition} ${this.showTooltip ? 'show' : ''}`;
    }

    /**
     * Computed style for tooltip max-width
     */
    get tooltipStyle() {
        return `max-width: ${this.maxWidth};`;
    }

    /**
     * Check if content is available
     */
    get hasContent() {
        return this.content && this.content.trim().length > 0;
    }

    /**
     * Cleanup on disconnect
     */
    disconnectedCallback() {
        if (this.showTimeout) {
            clearTimeout(this.showTimeout);
        }
        if (this.hideTimeout) {
            clearTimeout(this.hideTimeout);
        }
    }
}