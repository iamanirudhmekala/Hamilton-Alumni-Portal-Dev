import { LightningElement, api, wire, track } from 'lwc';

import Id from '@salesforce/user/Id';

import { showErrorToast } from 'c/hamGivingToastUtil';
import { updateBtnState, validateTotalAmount, MINIMUM_TOTAL_AMT, MAXIMUM_TOTAL_AMT } from 'c/hamGivingUtility';

import getPledges from '@salesforce/apex/HamGivingController.getPledges';
import getHamilonFundDesignations from '@salesforce/apex/HamGivingController.getHamilonFundDesignations';
import getCommUserContactId from '@salesforce/apex/HamGivingController.getCommUserContactId';

const MAIN_TABS = ['amount', 'designation', 'payment'];

function updateBtnStates() {
    const mainTabs = this.template.querySelectorAll('.gift-tab');
    mainTabs.forEach(btn => {
        updateBtnState(btn, 'tab', this.mainTab, 'active', 'dummy');

    })
}

function validateOnNavigate(dest) {
    if (MAIN_TABS.indexOf(this.mainTab) < MAIN_TABS.indexOf(dest)) {
        if (this.mainTab === 'amount' && (!this.isAmountValid || !this.formData.amount)) {
            this.toastTitle = 'Amount required';
            this.toastMessage = `Please enter a valid ($${MINIMUM_TOTAL_AMT} to $${MAXIMUM_TOTAL_AMT}) amount before continuing.`;
            this._showErrorToast();
            return false;
        } 

        if (this.mainTab === 'designation') {
            if ((!this.formData?.selectedDesignations || this.formData?.selectedDesignations.length <= 0)) {
                this.toastTitle = 'Designation required';
                this.toastMessage = 'Please select a designation before continuing.';
                this._showErrorToast();
                return false;
            } else if (this.formData.amount < MINIMUM_TOTAL_AMT) {
                this.toastTitle = 'Amount invalid';
                this.toastMessage = `Total amount must be more than ($${MINIMUM_TOTAL_AMT}).`;
                this._showErrorToast();
                return false;
            } else if (this.formData.amount > MAXIMUM_TOTAL_AMT) {
                this.toastTitle = 'Amount invalid';
                this.toastMessage = `Total amount must be less than $${MAXIMUM_TOTAL_AMT}.`;
                this._showErrorToast();
                return false;
            }

        }
    }

    return true;
}

export default class HamiltonGivingForm extends LightningElement {

    @api isSalesforceSite;
    @api contactId; // FOR TESTING 003VG00000cIYxOYAW

    @track mainTab = 'amount';
    @track formData = {};
    @track pledges = [];

    _updateBtnStates = updateBtnStates.bind(this);
    _showErrorToast = showErrorToast.bind(this);
    _validateOnNavigate = validateOnNavigate.bind(this);

    displayToast = false;
    toastTitle = '';
    toastMessage = '';
    isAmountValid = true;

    hamiltonFunds;
    userId = Id; // '005VG00000OZWonYAH';// FOR TESTING

    async connectedCallback() {
        this.dispatchEvent(new CustomEvent('loading', { detail: true, bubbles: true, composed: true }));

        const promises = this.userId ? 
            [
                getHamilonFundDesignations(),
                getCommUserContactId({ userId: this.userId }),
            ] 
            : [getHamilonFundDesignations(), null, ];

        try {
            const [ hamiltonFunds, contactId, ] = await Promise.all(promises);

            this.hamiltonFunds = hamiltonFunds;
            this.contactId = contactId;

            if (this.contactId) {
                this.pledges = await getPledges({ contactId: this.contactId });
            }

        } catch (error) {
            console.log('error', error);

        } finally {
            this.dispatchEvent(new CustomEvent('loading', { detail: false, bubbles: true, composed: true }));

        }

    }

    renderedCallback() {
        this._updateBtnStates();
    }

    handleMainTabChange(event) {
        if (!this._validateOnNavigate(event.target.dataset.tab)) {
            return ;
        }

        this.mainTab = event.target.dataset.tab;
        this._updateBtnStates();
    }

    handleBack(event) {
        this.mainTab = event.detail;
        this._updateBtnStates();
    }

    handleContinue(event) {
        if (!this._validateOnNavigate(event.detail)) {
            return ;
        }
        this.mainTab = event.detail;
        this._updateBtnStates();
    }

    handleAmountChange(event) {
        const { amount, paymentType, selectedPledgeIds, selectedPledges, isAmountValid } = event.detail;

        this.isAmountValid = isAmountValid;
        
        if (paymentType !== this.formData.paymentType) {
            this.formData.selectedDesignations = [];
        }

        this.formData.amount = Number(amount);
        this.formData.paymentType = paymentType;
        this.formData.selectedPledgeIds = selectedPledgeIds;
        this.formData.selectedPledges = selectedPledges;
        
        if ('pledge' != paymentType) {
            this.formData.selectedPledgeIds = [];
            this.formData.selectedPledges = [];

            if (this.formData.selectedDesignations && this.formData.selectedDesignations.length > 0) {
                this.formData.selectedDesignations.forEach(d => {
                    d.isDirty = false;
                });
            }
        }

    }

    handleDesignationselect(event) {
        const { selectedDesignations, amount } = event.detail
        this.formData.selectedDesignations = selectedDesignations;

        if (this.formData.paymentType === 'pledge') {
            this.formData.selectedPledges = this.formData.selectedPledges.map(p => {
                return {
                    ...p,
                    amt: selectedDesignations.find(d => d.id === p.designationId)?.amt || 0
                }
            });
        }

        this.formData.amount = amount;
        this.isAmountValid = validateTotalAmount(amount);
    }

    handleMakeThisOf(event) {
        const { inHonorOf, inMemoryOf } = event.detail;

        this.formData.inHonorOf = inHonorOf;
        this.formData.inMemoryOf = inMemoryOf;
    }

    handlePaymentTypeChange(event) {
        this.formData.paymentType = event.detail;
    }

    handlePaymentComplete(event) {
        const handlePaymentComplete = new CustomEvent('complete', {
            detail: { ...event.detail }
        });
        this.dispatchEvent(handlePaymentComplete);
    }

    handleCloseToast(event) {
        this.displayToast = false;
    }

    // Computed properties for tabs
    get isAmountTab() {
        return this.mainTab === 'amount';
    }

    get isDesignationTab() {
        return this.mainTab === 'designation';
    }

    get isPaymentTab() {
        return this.mainTab === 'payment';
    }

}