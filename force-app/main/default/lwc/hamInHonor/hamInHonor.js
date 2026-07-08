import { LightningElement, api } from 'lwc';

import { updateBtnState } from 'c/hamGivingUtility';

function updateBtnStates() {
    const mainTabs = this.template.querySelectorAll('button');
    mainTabs.forEach(btn => {
        updateBtnState(btn, 'textContent', this.selectedOption, 'options__btn--active', 'options__btn--inactive');

    })
}

function publishMakeThisGiftChange(params) {
    this.dispatchEvent(new CustomEvent('makethisgift', {
        detail: { 
            inHonorOf: this.selectedOption ? (this.selectedOption.includes('In Honor') ? this.inHonorOrMemoryOf : null): '',
            inMemoryOf: this.selectedOption ? (this.selectedOption.includes('In Memory') ? this.inHonorOrMemoryOf : null) : ''
        },
        bubbles: true,
        composed: true
    }));
}

export default class HamInHonor extends LightningElement {

    _updateBtnStates = updateBtnStates.bind(this);
    _publishMakeThisGiftChange = publishMakeThisGiftChange.bind(this);

    selectedOption;
    showGiftInHonorForm = false;
    inHonorOrMemoryOf;
    isRendered = false;

    @api formData;

    connectedCallback() {
        this.selectedOption = this.formData?.inHonorOf ? 'In Honor Of *' : this.formData?.inMemoryOf ? 'In Memory Of *' : null;

        this.inHonorOrMemoryOf = this.formData?.inHonorOf || this.formData?.inMemoryOf || '';
        if (this.inHonorOrMemoryOf) {
            this.showGiftInHonorForm = true;
        }
    }

    renderedCallback() {
        if (!this.isRendered) {
            this.isRendered = true;
            this._updateBtnStates();
        }
    }
    
    optionSelect(event) {
        this.selectedOption = event.target.textContent;

        this._updateBtnStates();
        this._publishMakeThisGiftChange();

    }

    handleCheck(event) {
        this.showGiftInHonorForm = event.target.checked;
        
        if (!this.showGiftInHonorForm) {
            this.inHonorOrMemoryOf = '';
            this.selectedOption = null;
            this._publishMakeThisGiftChange();
        }

    }

    handleNameChange(event) {
        this.inHonorOrMemoryOf = event.target.value;
        this._publishMakeThisGiftChange();
    }
}