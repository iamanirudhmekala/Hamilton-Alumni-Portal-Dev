import { LightningElement, api, track } from 'lwc';

export default class HamReviewAmountStep extends LightningElement {
    _frequency = 'once';
    _amount = '';

    @api
    get frequency() { return this._frequency; }
    set frequency(value) { this._frequency = value || 'once'; }

    @api
    get amount() { return this._amount; }
    set amount(value) { this._amount = value || ''; }

    @track isAnonymous = false;
    @track tributeExpanded = false;
    @track tributeType = 'honor';
    @track tributeName = '';
    @track tributeNotifyEmail = '';
    @track tributeMessage = '';

    get onceClass() {
        return this._frequency === 'once' ? 'ham-freq-btn ham-freq-btn-active' : 'ham-freq-btn';
    }

    get monthlyClass() {
        return this._frequency === 'monthly' ? 'ham-freq-btn ham-freq-btn-active' : 'ham-freq-btn';
    }

    get amountLabel() {
        return this._frequency === 'monthly' ? 'Your monthly gift amount' : 'Your one-time gift amount';
    }

    get formattedTotal() {
        const v = parseFloat(this._amount);
        return isNaN(v) || v <= 0 ? '0.00' : v.toFixed(2);
    }

    get tributeToggleLabel() {
        return this.tributeExpanded
            ? '▼  Make this gift in honor or memory of someone'
            : '▶  Make this gift in honor or memory of someone';
    }

    get isHonorType() { return this.tributeType === 'honor'; }

    get honorBtnClass() {
        return this.tributeType === 'honor' ? 'ham-tribute-type-btn ham-tribute-type-active' : 'ham-tribute-type-btn';
    }

    get memoryBtnClass() {
        return this.tributeType === 'memory' ? 'ham-tribute-type-btn ham-tribute-type-active' : 'ham-tribute-type-btn';
    }

    handleFrequencyClick(event) {
        this._frequency = event.currentTarget.dataset.freq;
        this.dispatchEvent(new CustomEvent('frequencychange', { detail: { frequency: this._frequency } }));
    }

    handleAmountInput(event) {
        this._amount = event.target.value;
        this.dispatchEvent(new CustomEvent('amountchange', { detail: { amount: this._amount } }));
    }

    handleSuggestedAmount(event) {
        this._amount = event.currentTarget.dataset.amount;
        this.dispatchEvent(new CustomEvent('amountchange', { detail: { amount: this._amount } }));
    }

    handleAnonymousChange(event) {
        this.isAnonymous = event.target.checked;
    }

    handleTributeToggle() {
        this.tributeExpanded = !this.tributeExpanded;
    }

    handleTributeTypeClick(event) {
        this.tributeType = event.currentTarget.dataset.type;
    }

    handleTributeNameInput(event) { this.tributeName = event.target.value; }
    handleTributeEmailInput(event) { this.tributeNotifyEmail = event.target.value; }
    handleTributeMessageInput(event) { this.tributeMessage = event.target.value; }

    handleContinue() {
        const amt = parseFloat(this._amount);
        if (!this._amount || isNaN(amt) || amt <= 0) {
            const input = this.template.querySelector('.ham-amount-input');
            if (input) {
                input.setCustomValidity('Please enter a valid amount greater than $0.');
                input.reportValidity();
            }
            return;
        }

        const tribute = (this.tributeExpanded && this.tributeName.trim())
            ? { type: this.tributeType, name: this.tributeName.trim(), notifyEmail: this.tributeNotifyEmail.trim(), message: this.tributeMessage.trim() }
            : null;

        this.dispatchEvent(new CustomEvent('continuerequested', {
            detail: { frequency: this._frequency, amount: this._amount, isAnonymous: this.isAnonymous, tribute }
        }));
    }
}