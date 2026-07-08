import { LightningElement, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import initFormData from '@salesforce/apex/HamReviewTransactionController.initFormData';

const GIFT_STEPS = [
    { key: 'amount', label: '1 Amount' },
    { key: 'designations', label: '2 Designations' },
    { key: 'payment', label: '3 Payment' },
    { key: 'confirm', label: '✓ Confirm' }
];

const PLEDGE_STEPS = [
    { key: 'pledge', label: '1 Select Pledge' },
    { key: 'payment', label: '2 Payment' },
    { key: 'confirm', label: '✓ Confirm' }
];

export default class HamReviewTransactionForm extends LightningElement {
    @track giftPath = null;
    @track currentStep = null;
    @track completedSteps = [];
    @track giftFrequency = 'once';
    @track amount = '';
    @track selectedDesignationsList = [];
    @track tributeData = null;
    @track isAnonymous = false;
    @track selectedPledges = [];
    @track currentContact = null;
    @track hamiltonDesignations = [];
    @track otherDesignations = [];
    @track userPledges = [];
    @track rtv2Init = null;
    @track isLoading = false;

    // ── Routing helpers ─────────────────────────────────────────────────────

    get isLanding() { return this.giftPath === null; }
    get isInFlow() { return this.giftPath !== null; }

    get isAmountStep() { return this.currentStep === 'amount'; }
    get isDesignationStep() { return this.currentStep === 'designations'; }
    get isPledgeStep() { return this.currentStep === 'pledge'; }
    get isPaymentStep() { return this.currentStep === 'payment'; }
    get isConfirmStep() { return this.currentStep === 'confirm'; }

    get activeSteps() {
        return this.giftPath === 'pledge' ? PLEDGE_STEPS : GIFT_STEPS;
    }

    get headerSubtitle() {
        return this.currentContact ? 'Welcome back, ' + this.currentContact.name : '';
    }

    // formData shape passed down to hamReviewPaymentTab
    get formDataForPayment() {
        if (this.giftPath === 'pledge') {
            return {
                amount: this.selectedPledges.reduce((s, p) => s + (parseFloat(p.amount) || 0), 0),
                selectedPledges: this.selectedPledges,
                giftFrequency: 'pledge'
            };
        }
        return {
            amount: parseFloat(this.amount) || 0,
            selectedDesignations: this.selectedDesignationsList,
            giftFrequency: this.giftFrequency,
            tributeData: this.tributeData,
            isAnonymous: this.isAnonymous
        };
    }

    // ── Landing ──────────────────────────────────────────────────────────────

    handleChooseGift() {
        this._startFlow('gift');
    }

    handleChoosePledge() {
        this._startFlow('pledge');
    }

    async _startFlow(path) {
        this.giftPath = path;
        this.isLoading = true;
        try {
            const data = await initFormData({ giftFrequency: this.giftFrequency });
            this.currentContact = data.contact || null;
            this.hamiltonDesignations = data.hamiltonDesignations || [];
            this.userPledges = data.pledges || [];
            this.rtv2Init = data.rtv2Init || null;
        } catch (e) {
            this._toast('Error', this._errorMsg(e), 'error');
        } finally {
            this.isLoading = false;
        }
        this.currentStep = path === 'pledge' ? 'pledge' : 'amount';
    }

    // ── Gift path ────────────────────────────────────────────────────────────

    handleFrequencyChange(event) {
        this.giftFrequency = event.detail.frequency;
    }

    handleAmountChange(event) {
        this.amount = event.detail.amount;
    }

    handleAmountContinue(event) {
        const { frequency, amount, isAnonymous, tribute } = event.detail;
        this.giftFrequency = frequency;
        this.amount = amount;
        this.isAnonymous = isAnonymous;
        this.tributeData = tribute;
        this._goTo('designations', 'amount');
    }

    handleDesignationBack() {
        this._goTo('amount');
    }

    handleDesignationSelect(event) {
        const { designation, isAdding } = event.detail;

        if (isAdding) {
            // Guard at the grandparent level too
            if (this.selectedDesignationsList.length >= 5) {
                this._toast('Maximum Reached', 'You can select up to 5 designations.', 'warning');
                return;
            }
            const total = parseFloat(this.amount) || 0;
            const splitAmt = (total / (this.selectedDesignationsList.length + 1)).toFixed(2);
            this.selectedDesignationsList = [
                ...this.selectedDesignationsList.map(d => ({ ...d, amount: splitAmt })),
                { id: designation.id, name: designation.name, amount: splitAmt }
            ];
        } else {
            const remaining = this.selectedDesignationsList.filter(d => d.id !== designation.id);
            if (remaining.length > 0) {
                const total = parseFloat(this.amount) || 0;
                const splitAmt = (total / remaining.length).toFixed(2);
                this.selectedDesignationsList = remaining.map(d => ({ ...d, amount: splitAmt }));
            } else {
                this.selectedDesignationsList = [];
            }
        }
    }

    handleAmountAdjust(event) {
        const { designationId, amount } = event.detail;
        this.selectedDesignationsList = this.selectedDesignationsList.map(d =>
            d.id === designationId ? { ...d, amount } : d
        );
    }

    handleDesignationContinue() {
        this._goTo('payment', 'designations');
    }

    // ── Pledge path ──────────────────────────────────────────────────────────

    handlePledgeBack() {
        this.giftPath = null;
        this.currentStep = null;
        this.completedSteps = [];
        this.selectedPledges = [];
    }

    handlePledgeContinue(event) {
        const { selectedPledges } = event.detail;
        this.selectedPledges = selectedPledges;
        this._goTo('payment', 'pledge');
    }

    // ── Shared payment / confirm ─────────────────────────────────────────────

    handlePaymentBack() {
        if (this.giftPath === 'pledge') {
            this._goTo('pledge');
        } else {
            this._goTo('designations');
        }
    }

    handlePaymentComplete(event) {
        const pledges = this.giftPath === 'pledge' ? this.selectedPledges : [];
        if (this.giftPath === 'pledge') {
            const total = pledges.reduce((s, p) => s + (parseFloat(p.amount) || 0), 0);
            this.amount = String(total);
        }
        this._goTo('confirm', 'payment');
    }

    handleStartOver() {
        this.giftPath = null;
        this.currentStep = null;
        this.completedSteps = [];
        this.giftFrequency = 'once';
        this.amount = '';
        this.selectedDesignationsList = [];
        this.tributeData = null;
        this.isAnonymous = false;
        this.selectedPledges = [];
    }

    // ── Step indicator ───────────────────────────────────────────────────────

    handleStepClick(event) {
        const { step } = event.detail;
        if (this.completedSteps.includes(step)) {
            this.currentStep = step;
        }
    }

    // ── Helpers ──────────────────────────────────────────────────────────────

    _goTo(nextStep, completedStep) {
        if (completedStep && !this.completedSteps.includes(completedStep)) {
            this.completedSteps = [...this.completedSteps, completedStep];
        }
        this.currentStep = nextStep;
    }

    _toast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    _errorMsg(error) {
        return error?.body?.message || error?.message || 'An unexpected error occurred.';
    }
}