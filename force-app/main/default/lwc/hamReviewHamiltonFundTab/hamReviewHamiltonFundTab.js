import { LightningElement, api, track } from 'lwc';

export default class HamReviewHamiltonFundTab extends LightningElement {
    _designations = [];
    _selectedDesignations = [];
    _isMaxReached = false;

    @api
    get designations() { return this._designations; }
    set designations(value) {
        this._designations = value || [];
        this._enrich();
    }

    @api
    get selectedDesignations() { return this._selectedDesignations; }
    set selectedDesignations(value) {
        this._selectedDesignations = value || [];
        this._enrich();
    }

    // NEW: re-enrich when the cap state changes so buttons update reactively
    @api
    get isMaxReached() { return this._isMaxReached; }
    set isMaxReached(value) {
        this._isMaxReached = value;
        this._enrich();
    }

    @track enrichedDesignations = [];

    get hasDesignations() {
        return this.enrichedDesignations && this.enrichedDesignations.length > 0;
    }

    _enrich() {
        this.enrichedDesignations = this._designations.map(d => {
            const sel = this._selectedDesignations.find(s => s.id === d.id);
            const isSelected = !!sel;

            // Disable the Add button when max is reached and this fund isn't already chosen
            const isAddDisabled = !isSelected && this._isMaxReached;

            return {
                ...d,
                isSelected,
                selectedAmount: sel ? sel.amount : '0.00',
                isAddDisabled,
                buttonClass: isSelected
                    ? 'ham-card-button ham-card-button-added'
                    : isAddDisabled
                        ? 'ham-card-button ham-card-button-add ham-card-button-disabled'
                        : 'ham-card-button ham-card-button-add',
                buttonLabel: isSelected ? '✓ Added' : '+ Add'
            };
        });
    }

    handleDesignationClick(event) {
       const designationId = event.currentTarget.dataset.id;
       const enriched = this.enrichedDesignations.find(d => d.id === designationId);

        if (!enriched || enriched.isAddDisabled) return;

        const isCurrentlySelected = this._selectedDesignations.some(s => s.id === designationId);

        // Match the shape grandparent's handleDesignationSelect expects: { designation, isAdding }
        this.dispatchEvent(new CustomEvent('designationselect', {
            detail: {
                designation: { id: enriched.id, name: enriched.name },
                isAdding: !isCurrentlySelected
            }
        }));
    }

    handleAmountInput(event) {
        const designationId = event.currentTarget.dataset.id;
        const amount = event.target.value;
        this.dispatchEvent(new CustomEvent('amountchange', {
            detail: { designationId, amount }
        }));
    }
}