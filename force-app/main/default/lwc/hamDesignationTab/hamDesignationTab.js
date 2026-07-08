import { LightningElement, track, api, wire } from 'lwc';

import { updateBtnState, MIN_DESIGNATION_AMOUNT } from 'c/hamGivingUtility';
import { showErrorToast, showInfoToast } from 'c/hamGivingToastUtil';
import getOtherDesignations from '@salesforce/apex/HamGivingController.getOtherDesignations';

function updateBtnStates() {
    const mainTabs = this.template.querySelectorAll('.designation-tab__button');
    mainTabs.forEach(btn => {
        updateBtnState(btn, 'btn', this.tab, 'designation-tab__button--active', 'designation-tab__button--inactive');
    })
}

function dispatchSelectedDesignationChange() {
    this.dispatchEvent(new CustomEvent('designationselect', {
        detail: { 
            selectedDesignations:  [ ...this._selectedDesignations.filter(d => d.amt >= MIN_DESIGNATION_AMOUNT),  ], 
            amount: this.totalAmount
        }
    }));
}

function distributeAmounts() {
    let distributedAmt;
    if (this._selectedDesignations && this._selectedDesignations.length > 0) {
        distributedAmt = this.totalAmount / this._selectedDesignations.length;
    }

    try {
        this._selectedDesignations = this._selectedDesignations.map(d => {
            return {
                ...d,
                amt: Number(distributedAmt.toFixed(2))
            }
        });

    } catch (error) {
        console.log('error 1', JSON.stringify(error));
    }
    this._dispatchSelectedDesignationChange();
}

function updateSelectedDesignations(designationId, action, isHamiltonFund) {
    if (action === 'remove') {
        this._selectedDesignations.splice(this._selectedDesignations.findIndex(d => d.id === designationId), 1);
    } else {
        if (isHamiltonFund) {
            this._selectedDesignations.push({ ...this._hamiltonFunds.find(d => d.id === designationId), paymentType: this.formData.paymentType });
        } else {
            this._selectedDesignations.push({ ...this._otherDesignations.find(d => d.id === designationId), paymentType: this.formData.paymentType });

        }
    }

    this._distributeAmounts();

}

function btnReset(designationId) {
    this.template.querySelectorAll('c-ham-designation-item').forEach(option => {
        if (option.designation.id === designationId) {
            option.isSelected = false;
        }
    });
}

export default class HamDesignationTab extends LightningElement {
    @api isSalesforceSite;

    _updateBtnStates = updateBtnStates.bind(this);
    _btnReset = btnReset.bind(this);
    _updateSelectedDesignations = updateSelectedDesignations.bind(this);
    _showErrorToast = showErrorToast.bind(this);
    _showInfoToast = showInfoToast.bind(this);
    _distributeAmounts = distributeAmounts.bind(this);
    _dispatchSelectedDesignationChange = dispatchSelectedDesignationChange.bind(this);

    tab = 'fund';

    _hamiltonFunds = [];
    
    @track
    _selectedDesignations = [];
    @track
    _otherDesignations = [];

    @api formData;

    totalAmount;

    searchString = '';

    selectedItemCmpUpdated = false;
    isRendered = false;

    displayToast = false;
    toastTitle = '';
    toastMessage = '';

    connectedCallback() {
        if (this.formData.paymentType === 'pledge') {
            this._selectedDesignations = this.formData.selectedPledges.map(pledge => {
                return { id: pledge.designationId, name: pledge.designationName, amt: pledge.amt, paymentType: this.formData.paymentType, description: pledge.designationDescription, fundGrp: pledge.fundGrp, fundGrpName: pledge.fundGrpName }
            });

            this.totalAmount = this._selectedDesignations.reduce((total, d) => total + Number(d.amt), 0);
            this._dispatchSelectedDesignationChange();
            
        } else {

            if (this.formData?.selectedDesignations) {
                this._selectedDesignations = [...this.formData.selectedDesignations];
            } 
        }

        if (this.formData?.amount) {
            this.totalAmount = this.formData.amount;
        }


    }

    renderedCallback() {
        if (!this.isRendered) {
            
            if (this._selectedDesignations.length > 0 && this.formData.paymentType !== 'pledge') {
                const tempTotal = this._selectedDesignations.reduce((total, d) => total + Number(d.amt), 0);
                
                if (tempTotal !== this.totalAmount) {
                    this._distributeAmounts();
                }
            }


            this.isRendered = true;
        }
    }

    handleSelectDesignation(event) {
        const { designationId, isHamiltonFund, isSelected } = event.detail;

        const selectedSize = this._selectedDesignations.length;

        if (selectedSize === 5) {
            this.toastTitle = 'Maximum Designations Reached';
            this.toastMessage = 'Maximum Designations Reached', 'You can only select up to 5 designations.'
            this._showErrorToast();

            this._btnReset(designationId);

            console.log('Maximum Designations Reached');

        } else {
            this._updateSelectedDesignations(designationId, isSelected ? 'add' : 'remove', isHamiltonFund);
        }
    }

    handleAmtChange(event) {
        const { designationId, amt} = event.detail;

        this._selectedDesignations = this._selectedDesignations.map(sd => {
            if (sd.id === designationId) {
                return {
                    ...sd,
                    amt: Number(amt) || 0
                }
            } else {
                return { ...sd, 
                }
            }

        });

        this.totalAmount = this._selectedDesignations.reduce((total, d) => total + Number(d.amt), 0);
        this._dispatchSelectedDesignationChange();

    }

    removeSelected(event) {
        const designationId = event.detail;
        this._updateSelectedDesignations(designationId, 'remove');
        
        const designationOptions = this.template.querySelectorAll('c-ham-designation-item');
        designationOptions.forEach(option => {
            if (option.designation.id === designationId) {
                option.isSelected = false;
            }
        });
    }

    searchOtherDesignations(event) {
        this.searchString = event.target.value;
        this.dispatchEvent(new CustomEvent('loading', { detail: true, bubbles: true, composed: true }));
        getOtherDesignations({ searchString: this.searchString })
            .then(result => {
                this._otherDesignations = result;
                this.dispatchEvent(new CustomEvent('loading', { detail: false, bubbles: true, composed: true }));
                
            })
            .catch(error => {
                console.log('error', error);
                this.dispatchEvent(new CustomEvent('loading', { detail: false, bubbles: true, composed: true }));

            });
    }

    clearSearchString() {
        this.searchString = '';
    }

    handleBackToAmount() {
        const backToAmountEvent = new CustomEvent('back', {
            detail: 'amount'
        });
        this.dispatchEvent(backToAmountEvent);
    }

    tabClicked(event) {
        this.tab = event.target.dataset.btn;
        this._updateBtnStates();
    }

    handleContinueToPayment() {
        console.log('continue to payment', JSON.stringify(this.formData));
        
        this.dispatchEvent(new CustomEvent('continue', {
            detail: 'payment'
        }));
    }

    handleCloseToast(event) {
        this.displayToast = false;
    }

    get isHamiltonFund() {
        return this.tab === 'fund';
    }

    get hasSelectedDesignations() {
        return this._selectedDesignations.length > 0;
    }

    get selectedDesignations() {
        return this._selectedDesignations;
    }

    get formattedAmount() {
        return this.totalAmount ? this.totalAmount.toLocaleString() : '0';

    }

    get hasSearchResult() {
        return this._otherDesignations.length > 0;
    }

    get isSearching() {
        return this.searchString;
    }

    @api get hamiltonFunds() {
        let tempDesignations;
        if (this.formData.paymentType === 'pledge') {
            tempDesignations = this._selectedDesignations.map(pledge => {
                return { isSelected: true, ...pledge }
            });

            return tempDesignations;
        }

        tempDesignations = this._hamiltonFunds.map(d => {
            return { ...d, isSelected: this._selectedDesignations.findIndex(dd => dd.id === d.id) !== -1 };
        });
        return tempDesignations;
    }

    set hamiltonFunds(value) {
        this._hamiltonFunds = value;
    }

    get otherDesignations() {
        const tempDesignations = this._otherDesignations.map(d => {
            return { ...d, isSelected: this._selectedDesignations.findIndex(dd => dd.id === d.id) !== -1 };
        });
        return tempDesignations;

    }

    get otherDesignationCss() {
        return this.formData.paymentType === 'pledge' ? 'designation-tab__button designation-tab__button--inactive designation-tab__button--disabled' : 'designation-tab__button designation-tab__button--inactive';
    }

    get disabledOtherDesignation() {
        return this.formData.paymentType === 'pledge';
    }
    
}