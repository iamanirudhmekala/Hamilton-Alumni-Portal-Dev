import { LightningElement, api, track } from 'lwc';

export default class HamReviewPayPledgeTab extends LightningElement {
    _pledges = [];

    @api
    get pledges() { return this._pledges; }
    set pledges(value) {
        this._pledges = value || [];
        this._enrich();
    }

    @track enrichedPledges = [];
    @track selectedPledgeIds = [];
    // map pledgeId => numeric amount entered by user
    _pledgeAmounts = {};

    get hasPledges() {
        return this.enrichedPledges && this.enrichedPledges.length > 0;
    }

    get hasSelection() {
        return this.selectedPledgeIds.length > 0;
    }

    get continueDisabled() {
        return !this.hasSelection;
    }

    get selectedTotal() {
        const selected = this._pledges.filter(p => this.selectedPledgeIds.includes(p.id));
        const total = selected.reduce((sum, p) => {
            const entered = this._pledgeAmounts && this._pledgeAmounts[p.id] != null
                ? parseFloat(this._pledgeAmounts[p.id]) || 0
                : (parseFloat(p.remainingAmount) || 0);
            return sum + entered;
        }, 0);
        return total.toFixed(2);
    }

    _enrich() {
        // Build enriched pledges and include defaultPayAmount and currentPayAmount state
        this.enrichedPledges = this._pledges.map(p => {
            const isSelected = this.selectedPledgeIds.includes(p.id);
            const defaultPay = isSelected ? (parseFloat(p.remainingAmount) || 0) : 0;
            const currentPay = this._pledgeAmounts && this._pledgeAmounts[p.id] != null
                ? this._pledgeAmounts[p.id]
                : defaultPay;
                return {
                    ...p,
                    isSelected,
                    cardClass: isSelected
                        ? 'ham-pledge-card ham-pledge-card-selected'
                        : 'ham-pledge-card',
                    formattedAmount: this._formatCurrency(p.amount),
                    formattedPaid: this._formatCurrency(p.paidAmount),
                    formattedRemaining: this._formatCurrency(p.remainingAmount),
                    progressPct: this._calcProgress(p.paidAmount, p.amount),
                    progressStyle: 'width:' + this._calcProgress(p.paidAmount, p.amount) + '%',
                    defaultPayAmount: currentPay.toFixed(2),
                    ariaLabel: 'Amount to pay for ' + (p.designationName || p.name || '')
                };
        });
    }

    _formatCurrency(value) {
        if (value == null) return '$0.00';
        return new Intl.NumberFormat('en-US', { style: 'currency', currency: 'USD' }).format(value);
    }

    _calcProgress(paid, total) {
        if (!total || total === 0) return 0;
        return Math.min(100, Math.round((paid / total) * 100));
    }

    handlePledgeClick(event) {
        const pledgeId = event.currentTarget.dataset.id;
        if (this.selectedPledgeIds.includes(pledgeId)) {
            this.selectedPledgeIds = this.selectedPledgeIds.filter(id => id !== pledgeId);
            // clear any entered amount for deselected pledge
            if (this._pledgeAmounts && this._pledgeAmounts[pledgeId] != null) {
                delete this._pledgeAmounts[pledgeId];
            }
        } else {
            this.selectedPledgeIds = [...this.selectedPledgeIds, pledgeId];
        }
        this._enrich();
    }

    handleAmountInput(event) {
        const el = event.target;
        const pledgeId = el.dataset.id;
        let val = el.value;
        // sanitize and enforce numeric >= 0
        val = val === '' ? '' : parseFloat(val);
        if (val === '') {
            // treat empty as zero / not set
            delete this._pledgeAmounts[pledgeId];
        } else if (isNaN(val) || val < 0) {
            // reset to 0 if invalid
            val = 0;
            this._pledgeAmounts[pledgeId] = val;
            el.value = val.toFixed(2);
        } else {
            // clamp to remaining amount if provided
            const pledge = this._pledges.find(p => p.id === pledgeId);
            const remaining = pledge ? (parseFloat(pledge.remainingAmount) || 0) : null;
            if (remaining != null && val > remaining) {
                val = remaining;
            }
            this._pledgeAmounts[pledgeId] = val;
            el.value = val.toFixed(2);
        }

        // refresh enriched pledges so UI shows updated defaultPayAmount
        this._enrich();

        // dispatch an event with the new amount
        const pledge = this._pledges.find(p => p.id === pledgeId);
        this.dispatchEvent(new CustomEvent('amountchange', {
            detail: {
                id: pledgeId,
                designationName: pledge ? pledge.designationName : null,
                amount: this._pledgeAmounts[pledgeId] != null ? parseFloat(this._pledgeAmounts[pledgeId]) : 0
            }
        }));
    }

    handleBack() {
        this.dispatchEvent(new CustomEvent('back'));
    }

    handleContinue() {
        // Build selected pledges using entered amounts when available, otherwise fall back to remainingAmount
        const selectedPledges = this._pledges
            .filter(p => this.selectedPledgeIds.includes(p.id))
            .map(p => {
                const entered = this._pledgeAmounts && this._pledgeAmounts[p.id] != null
                    ? parseFloat(this._pledgeAmounts[p.id]) || 0
                    : (parseFloat(p.remainingAmount) || 0);
                return {
                    id: p.id,
                    name: p.name,
                    designationId: p.designationId,
                    designationName: p.designationName,
                    amount: entered
                };
            });
        const total = selectedPledges.reduce((sum, p) => sum + (parseFloat(p.amount) || 0), 0);
        this.dispatchEvent(new CustomEvent('continuerequested', {
            detail: { selectedPledges, total }
        }));
    }
}