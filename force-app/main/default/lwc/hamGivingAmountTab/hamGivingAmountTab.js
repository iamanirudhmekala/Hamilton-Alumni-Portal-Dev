import { api, LightningElement, track } from 'lwc';

import { updateBtnState } from 'c/hamGivingUtility';

function updateBtnStates() {
    const amountBtns = this.template.querySelectorAll('.amount-tab-item');
    amountBtns.forEach(btn => {
        updateBtnState(btn, 'amountBtn', this.amountBtn, 'amount-tab-item-active', 'amount-tab-item-inactive');
    });

}

export default class HamGivingAmountTab extends LightningElement {
    _updateBtnStates = updateBtnStates.bind(this);

    isAmountTabIncomplete;
    amountBtn;

    @api formData;

    @track _pledges;

    @api get pledges() {
        return this._pledges;
    }

    set pledges(value) {
        this._pledges = value;
    }

    isRendered = false;

    connectedCallback() {
        this.amountBtn = this.formData?.paymentType || 'once';
    }

    renderedCallback() {
        if (!this.isRendered) {
            this.isRendered = true;
            this._updateBtnStates();
        }
    }

    amountButtonClick(event) {
        this.amountBtn = event.target.dataset.amountBtn;
        this._updateBtnStates();

    }

    handleContinueToDesignation() {
        this.dispatchEvent(new CustomEvent('continue', {
            detail: 'designation'
        }));
    }

    get isOneTime() {
        return this.amountBtn === 'once';
    }

    get isRecurring() {
        return this.amountBtn === 'monthly';

    }

    get isPledge() {
        return this.amountBtn === 'pledge';
    }

    get disabledPledgeTab() {
        return false; //!this._pledges || this._pledges.length === 0;
    }
}