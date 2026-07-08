import { LightningElement, api, track } from 'lwc';

export default class HamReviewDesignationStep extends LightningElement {
    _hamiltonDesignations = [];
    _otherDesignations = [];
    _selectedDesignations = [];
    _amount = '';

    @api
    get hamiltonDesignations() { return this._hamiltonDesignations; }
    set hamiltonDesignations(value) { this._hamiltonDesignations = value || []; }

    @api
    get otherDesignations() { return this._otherDesignations; }
    set otherDesignations(value) { this._otherDesignations = value || []; }

    @api
    get selectedDesignations() { return this._selectedDesignations; }
    set selectedDesignations(value) { this._selectedDesignations = value || []; }

    @api
    get amount() { return this._amount; }
    set amount(value) { this._amount = value || ''; }

    @track activeTab = 'hamilton';

    get isHamiltonTab() { return this.activeTab === 'hamilton'; }
    get isOtherTab() { return this.activeTab === 'other'; }

    get hamiltonTabClass() {
        return this.activeTab === 'hamilton' ? 'ham-tab ham-tab-active' : 'ham-tab';
    }

    get otherTabClass() {
        return this.activeTab === 'other' ? 'ham-tab ham-tab-active' : 'ham-tab';
    }

    get hasSelectedDesignations() {
        return this._selectedDesignations && this._selectedDesignations.length > 0;
    }

    get isMaxReached() {
        return this._selectedDesignations.length >= 5;
    }

    get continueDisabled() {
        return !this.hasSelectedDesignations;
    }

    get formattedTotal() {
        const v = parseFloat(this._amount);
        return isNaN(v) || v <= 0 ? '0.00' : v.toFixed(2);
    }

    handleTabClick(event) {
        this.activeTab = event.currentTarget.dataset.tab;
    }

    handleBack() {
        this.dispatchEvent(new CustomEvent('back'));
    }

    handleDesignationSelect(event) {
        // Pass { designation, isAdding } straight up — grandparent owns the state
        this.dispatchEvent(new CustomEvent('designationselect', { detail: event.detail }));
    }

    handleAmountChange(event) {
        this.dispatchEvent(new CustomEvent('amountadjust', { detail: event.detail }));
    }

    handleContinue() {
        if (this.continueDisabled) return;
        this.dispatchEvent(new CustomEvent('continuerequested'));
    }
}