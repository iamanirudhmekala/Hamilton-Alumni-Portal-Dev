import { LightningElement, api } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export function showErrorToast() {
    showToast('error', this);
}

export function showInfoToast() {
   showToast('info', this);
}

function showToast(variant, that) {
    if (that.isSalesforceSite) {
        that.displayToast = true;
        that.toastVariant = variant;

        setTimeout(() => {
            that.displayToast = false;
        }, 5000);
    } else {
        that.dispatchEvent(new ShowToastEvent({
            title: that.toastTitle,
            message: that.toastMessage,
            variant: variant
        }));
    }
}

export default class HamGivingToastUtil extends LightningElement {
    @api toastTitle;
    @api toastMessage;
    @api toastVariant = 'error';

    handleClose() {
        this.dispatchEvent(new CustomEvent('close'));
    }

    get isError() {
        return this.toastVariant === 'error';
    }   

    get isInfo() {
        return this.toastVariant === 'info';
    }
}