import { LightningElement, track, api } from 'lwc';

import { showInfoToast } from 'c/hamGivingToastUtil';
import { validateTotalAmount, MIN_PLEDGE_AMOUNT } from 'c/hamGivingUtility';

function publishAmountChange() {
    this.dispatchEvent(new CustomEvent('amountchange', {
        detail: { 
            amount: this.amount, 
            paymentType: this.amount ? 'pledge' : null, 
            selectedPledgeIds: this.selectedPledgeIds, 
            isAmountValid: validateTotalAmount(this.amount),
            selectedPledges: this._pledges.filter(pledge => this.selectedPledgeIds.includes(pledge.id)).map(pledge => {
                const { id, amt, designationId, designationName, fundGrp, fundGrpName} = pledge;
                return { id, amt, designationId, designationName, fundGrp, fundGrpName }
            })
        },
        bubbles: true,
        composed: true
    }));
}

export default class HamPledgeAmount extends LightningElement {
    @api formData;
    @api contactId = '';

    @track _pledges = [];
    @track selectedPledgeIds = [];

    _publishAmountChange = publishAmountChange.bind(this);
    _showInfoToast = showInfoToast.bind(this);

    amount;
    areAmtsValid = true;

    displayToast = false;
    toastTitle = '';
    toastMessage = '';


    connectedCallback() {
        if (this.formData?.amount && this.formData.paymentType == 'pledge') {
            this.amount = this.formData.amount;
            this.selectedPledgeIds = [...this.formData.selectedPledgeIds];
            this._pledges = this._pledges.map(pledge => {
                return { 
                    ...pledge, 
                    selected: !this.selectedPledgeIds || this.selectedPledgeIds.length == 0 ? false : this.selectedPledgeIds.includes(pledge.id),
                    amt: this.formData?.selectedPledges ? this.formData.selectedPledges.find(p => p.id === pledge.id)?.amt : 0
                };
            });
        } 
    }

    handlePledgeSelection(event) {
        event.target.checked = !event.target.checked;
        const pledgeId = event.target.dataset.id;

        if (!event.target.checked) {
            this.toastTitle = 'Select not allowed';
            this.toastMessage = 'Please input a pledge amount to select.';
            this._showInfoToast();
        } else {
            this._pledges = this._pledges.map(pledge => {
                if (pledge.id === pledgeId) {
                    return {
                        ...pledge,
                        selected: false,
                        amt: 0
                    }
                } else {
                    return { ...pledge }
                }
            });
        }

    }

    handlePledgeAmountChange(event) {
        const inputField = event.target;
        const pledgeId = inputField.dataset.id;
        const amt = inputField.value;

        if (parseFloat(amt) < 0) {
            inputField.setCustomValidity('Pledge amount must be a non-negative value.');
            this.areAmtsValid = false;
        } else if (parseFloat(amt) < MIN_PLEDGE_AMOUNT) {
            inputField.setCustomValidity(`Pledge amount must be more than or equal to $${MIN_PLEDGE_AMOUNT}.`);
            this.areAmtsValid = false;
        } else {
            inputField.setCustomValidity('');
        }

        inputField.reportValidity();

        this._pledges = this._pledges.map(pledge => {
            if (pledge.id === pledgeId && !isNaN(amt) && parseFloat(amt) > 0) {
                return {
                    ...pledge,
                    selected: true,
                    amt: parseFloat(amt)
                }
            } else if (pledge.id === pledgeId && (isNaN(amt) || amt <= 0)) {
                return { ...pledge, selected: false, amt: amt }
            } else {
                return { ...pledge }
            }
        });

        this.selectedPledgeIds = this._pledges.filter(pledge => pledge.selected).map(pledge => pledge.id);
        this.amount = this.calculatePledgeTotal();

        this._publishAmountChange();

    }

    calculatePledgeTotal() {
        return this._pledges.filter(pledge => pledge.selected).reduce((total, pledge) => {
            return total + (pledge?.amt || 0);
        }, 0);
    }

    get formattedAmount() {
        return this.amount ? this.amount.toLocaleString() : '0';
    }

    get pledgeCount() {
        return this.selectedPledgeIds.length;
    }

    get hasMultiplePledges() {
        return this.selectedPledgeIds.length > 1;
    }

    get formattedPledgeTotal() {
        return this.calculatePledgeTotal().toLocaleString();
    }

    get hasSelectedPledges() {
        return this.selectedPledgeIds.length > 0;
    }

    get hasPledges() {
        return this._pledges.length > 0;
    }

    @api get pledges() {
        return this._pledges.map(pledge => ({
            ...pledge,
            isSelected: pledge.selected,
            cssClass: pledge.selected ? 'pledge-option selected' : 'pledge-option',
            formattedTotal: pledge.amount.toLocaleString(),
            formattedPaid: pledge.paidAmount.toLocaleString(),
            formattedRemaining: pledge.remainingAmount.toLocaleString(),
        }));
    }

    set pledges(value) {
        this._pledges = value;
    }
}