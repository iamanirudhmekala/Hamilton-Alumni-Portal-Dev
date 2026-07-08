import { api, LightningElement, track } from 'lwc';

import { loadStyle } from 'lightning/platformResourceLoader';
import GIVING_STYLE from '@salesforce/resourceUrl/hamGiving';

import { validateTotalAmount, MINIMUM_TOTAL_AMT, MAXIMUM_TOTAL_AMT } from 'c/hamGivingUtility';

import monthly from './monthly.html';
import giveOnce from './giveOnce.html';

export default class HamGivingAmount extends LightningElement {

    @api isGiveOnce;
    @api amount;
    @api formData;

    connectedCallback(){
        Promise.all([
            loadStyle(this, GIVING_STYLE)
        ]).then(() => {
            console.log('Styles loaded successfully');
        }).catch(error => {
            console.log('error', error);
        });

        if(this.formData?.amount && this.formData.paymentType != 'pledge' && (this.formData.paymentType == 'once' && this.isGiveOnce == 'true' || this.formData.paymentType == 'monthly' && this.isGiveOnce == 'false')){
            this.amount = this.formData.amount;
        }
        
    }

    handleAmountChange(event) {
        const inputField = event.target;
        const tempAmt = inputField.value;

        let preventInput = false;
        if (tempAmt > MAXIMUM_TOTAL_AMT) {
            inputField.setCustomValidity(`Amount must be less than or equal to $${MAXIMUM_TOTAL_AMT}.`);
            inputField.value = this.amount;
            preventInput = true;
        } else if (tempAmt < MINIMUM_TOTAL_AMT) {
            inputField.setCustomValidity(`Amount must be more than or equal to $${MINIMUM_TOTAL_AMT}.`);
        } else {
            inputField.setCustomValidity('');
        }

        inputField.reportValidity();

        if(preventInput){
            return;
        }

        this.amount = inputField.value;
            
        this.dispatchEvent(new CustomEvent('amountchange', {
            detail: { 
                amount: this.amount, 
                paymentType: this.isGiveOnce == 'true' ? 'once' : 'monthly', 
                isAmountValid: validateTotalAmount(this.amount) 
            },
            bubbles: true,
            composed: true
        }));
    }

    render() {
        return this.isGiveOnce == 'true' ? giveOnce : monthly ;
    }

    get formattedAmount() {
        return this.amount ? this.amount.toLocaleString() : '0';
    }

    get amountValue() {
        return this.amount;
    }

}