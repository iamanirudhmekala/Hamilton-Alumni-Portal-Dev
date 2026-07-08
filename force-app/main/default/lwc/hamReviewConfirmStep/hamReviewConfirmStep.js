import { LightningElement, api } from 'lwc';

export default class HamReviewConfirmStep extends LightningElement {
    _contact = null;
    _selectedDesignations = [];
    _amount = '';
    _giftFrequency = 'once';
    _giftPath = 'gift';

    @api
    get contact() { return this._contact; }
    set contact(value) { this._contact = value; }

    @api
    get selectedDesignations() { return this._selectedDesignations; }
    set selectedDesignations(value) { this._selectedDesignations = value || []; }

    @api
    get amount() { return this._amount; }
    set amount(value) { this._amount = value || ''; }

    @api
    get giftFrequency() { return this._giftFrequency; }
    set giftFrequency(value) { this._giftFrequency = value || 'once'; }

    @api
    get giftPath() { return this._giftPath; }
    set giftPath(value) { this._giftPath = value || 'gift'; }

    get isGiftPath() { return this._giftPath === 'gift'; }
    get isPledgePath() { return this._giftPath === 'pledge'; }
    get isMonthly() { return this._giftFrequency === 'monthly'; }

    get contactName() {
        return this._contact ? this._contact.name : 'Donor';
    }

    get formattedAmount() {
        const v = parseFloat(this._amount);
        if (isNaN(v)) return '$0.00';
        return new Intl.NumberFormat('en-US', { style: 'currency', currency: 'USD' }).format(v);
    }

    get frequencyLabel() {
        return this._giftFrequency === 'monthly' ? 'Monthly Gift' : 'One-Time Gift';
    }

    get hasDesignations() {
        return this._selectedDesignations && this._selectedDesignations.length > 0;
    }

    handleStartOver() {
        this.dispatchEvent(new CustomEvent('startover'));
    }
}