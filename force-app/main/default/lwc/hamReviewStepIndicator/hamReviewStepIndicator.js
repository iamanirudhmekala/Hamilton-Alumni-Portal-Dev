import { LightningElement, api } from 'lwc';

export default class HamReviewStepIndicator extends LightningElement {
    _currentStep = '';
    _completedSteps = [];
    _steps = [];

    @api
    get currentStep() { return this._currentStep; }
    set currentStep(value) {
        this._currentStep = value || '';
    }

    @api
    get completedSteps() { return this._completedSteps; }
    set completedSteps(value) {
        this._completedSteps = value || [];
    }

    @api
    get steps() { return this._steps; }
    set steps(value) {
        this._steps = value || [];
    }

    get enrichedSteps() {
        return this._steps.map(s => ({
            ...s,
            pillClass: this._pillClass(s.key)
        }));
    }

    _pillClass(key) {
        if (key === this._currentStep) return 'step-pill step-pill-active';
        if (this._completedSteps.includes(key)) return 'step-pill step-pill-completed';
        return 'step-pill step-pill-inactive';
    }

    handleStepClick(event) {
        const step = event.currentTarget.dataset.step;
        if (this._completedSteps.includes(step)) {
            this.dispatchEvent(new CustomEvent('stepclick', { detail: { step } }));
        }
    }
}