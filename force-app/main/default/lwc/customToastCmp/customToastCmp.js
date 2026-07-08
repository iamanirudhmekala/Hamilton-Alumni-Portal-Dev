import { LightningElement,api } from 'lwc';

export default class CustomToastCmp extends LightningElement {

    @api title = 'Success';
    @api message = '';
    @api variant = 'success'; // success | error | warning | info
    @api duration = 10000;

    visible = false;
    isMobile = false;
    timeoutId;

    connectedCallback() {
        this.isMobile = window.innerWidth <= 768;
    }

    // Public method for parent component
    @api showToast(msg, type ) {
        this.message = msg;
        this.variant = type;
        this.visible = true;

        clearTimeout(this.timeoutId);
        this.timeoutId = setTimeout(() => {
            this.closeToast();
        }, this.duration);
    }

    closeToast() {
        this.visible = false;
        this.dispatchEvent(new CustomEvent('close'));
    }

    get toastClass() {
        return `toast ${this.variant} ${this.isMobile ? 'mobile' : 'desktop'}`;
    }

    get icon() {
        switch (this.variant) {
            case 'success': return '✅';
            case 'error': return '❌';
            case 'warning': return '⚠️';
            case 'info': return 'ℹ️';
            default: return '';
        }
    }
}