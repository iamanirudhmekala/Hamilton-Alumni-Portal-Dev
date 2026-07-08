import { LightningElement, api } from 'lwc';

import { MIN_DESIGNATION_AMOUNT, MAXIMUM_TOTAL_AMT } from 'c/hamGivingUtility';

export default class HamSelectedDesignation extends LightningElement {
    @api designation;

    isAmtValid = true;

    handleRemoveDesignation(event) {
        this.dispatchEvent(new CustomEvent('remove', {
            detail: this.designation.id
        }));
    }

    handleAmtChange(event) {
        const inputField = event.target;
        const amt = inputField.value;

        if (parseFloat(amt) < 0) {
            inputField.setCustomValidity('Amount must be a non-negative value.');
            this.isAmtValid = false;
        } else if (parseFloat(amt) < MIN_DESIGNATION_AMOUNT) {
            inputField.setCustomValidity(`Amount must be at least $${MIN_DESIGNATION_AMOUNT}.`);
            this.isAmtValid = false;
        } else if (parseFloat(amt) > MAXIMUM_TOTAL_AMT) {
            inputField.setCustomValidity(`Amount must be less than $${MAXIMUM_TOTAL_AMT}.`);
            this.isAmtValid = false;
        } else {
            inputField.setCustomValidity('');
        }
        
        inputField.reportValidity();

        this.dispatchEvent(new CustomEvent('amtchange', {
            detail: { designationId: this.designation.id, amt: amt }
        }));
    }

    get name() {
        return this.designation.name;
    }

    get amt() {
        return this.designation.amt || 0;
    }

    get isDisabled() {
        return false;//this.designation.paymentType === 'pledge';
    }
}