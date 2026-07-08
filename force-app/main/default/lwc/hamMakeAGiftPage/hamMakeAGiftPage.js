import { LightningElement, api, track } from 'lwc';

// Mock data for designations
const MOCK_DESIGNATIONS = [
    { id: '1', name: 'Annual Fund', description: 'Support Hamilton\'s most pressing needs', isPubliclyVisible: true, sortOrder: 1, category: 'general' },
    { id: '2', name: 'Library', description: 'Support academic resources and collections', isPubliclyVisible: true, sortOrder: 2, category: 'Academic Programs' },
    { id: '3', name: 'Archives', description: 'Preserve Hamilton\'s history and heritage', isPubliclyVisible: true, sortOrder: 3, category: 'Academic Programs' },
    { id: '10', name: 'Labs', description: 'Support state-of-the-art laboratory facilities', isPubliclyVisible: true, sortOrder: 10, category: 'Academic Programs' },
    { id: '4', name: 'Student Programs', description: 'Enhance campus life and student engagement', isPubliclyVisible: true, sortOrder: 4, category: 'Student Activities' },
    { id: '5', name: 'Faculty Development', description: 'Invest in teaching excellence', isPubliclyVisible: true, sortOrder: 5, category: 'Student Activities' },
    { id: '6', name: 'Football', description: 'Support Hamilton football program', isPubliclyVisible: true, sortOrder: 6, category: 'Athletics' },
    { id: '7', name: 'Hockey', description: 'Support Hamilton hockey program', isPubliclyVisible: true, sortOrder: 7, category: 'Athletics' },
    { id: '8', name: 'General Endowed Fund', description: 'Support endowed scholarships and programs', isPubliclyVisible: true, sortOrder: 8, category: 'Scholarships and Other Endowments' },
    { id: '9', name: 'Named Endowed Fund', description: 'Create lasting impact through named endowments', isPubliclyVisible: true, sortOrder: 9, category: 'Scholarships and Other Endowments' }
];

// Mock data for pledges
const MOCK_PLEDGES = [
    { id: 'p1', designation: 'Annual Fund', totalAmount: 10000, amountPaid: 5000, amountRemaining: 5000, installmentAmount: 1000, pledgeDate: 'January 15, 2024' },
    { id: 'p2', designation: 'Financial Aid', totalAmount: 25000, amountPaid: 20000, amountRemaining: 5000, installmentAmount: 2500, pledgeDate: 'March 22, 2023' }
];

export default class HamMakeAGiftPage extends LightningElement {
     @api initialData;
    
    @track formData = {};
    @track searchTerm = '';
    @track selectedDesignationId = '';
    @track selectedPledgeIds = [];
    @track customAmount = '';
    @track showDedication = false;
    @track dedicationType = '';
    @track designationTab = 'hamilton';
    @track mainTab = 'amount';
    @track selectedDesignations = [];
    @track cardDetails = {
        name: '',
        number: '',
        expiry: '',
        cvc: ''
    };

    connectedCallback() {
        this.formData = { ...this.initialData };
        // Auto-select Hamilton Fund when on designation tab
        if (this.mainTab === 'designation' && this.designationTab === 'hamilton') {
            this.autoSelectHamiltonFund();
        }
    }

    // Computed properties for tabs
    get isAmountTab() {
        return this.mainTab === 'amount';
    }

    get isDesignationTab() {
        return this.mainTab === 'designation';
    }

    get isPaymentTab() {
        return this.mainTab === 'payment';
    }

    // Tab styling
    get amountTabClass() {
        return this.mainTab === 'amount' ? 'gift-tab arrow-tab active' : 'gift-tab arrow-tab';
    }

    get designationTabClass() {
        return this.mainTab === 'designation' ? 'gift-tab arrow-tab active' : 'gift-tab arrow-tab';
    }

    get paymentTabClass() {
        return this.mainTab === 'payment' ? 'gift-tab arrow-tab active' : 'gift-tab arrow-tab';
    }

    get amountTabVariant() {
        return this.mainTab === 'amount' ? 'brand' : 'neutral';
    }

    get designationTabVariant() {
        return this.mainTab === 'designation' ? 'brand' : 'neutral';
    }

    get paymentTabVariant() {
        return this.mainTab === 'payment' ? 'brand' : 'neutral';
    }

    // Payment type computed properties
    get isOneTime() {
        return this.formData.paymentType === 'one-time';
    }

    get isRecurring() {
        return this.formData.paymentType === 'recurring';
    }

    get isPledge() {
        return this.formData.paymentType === 'pledge';
    }

    get oneTimeClass() {
        return this.formData.paymentType === 'one-time' ? 'gift-tab active' : 'gift-tab';
    }

    get recurringClass() {
        return this.formData.paymentType === 'recurring' ? 'gift-tab active' : 'gift-tab';
    }

    get pledgeClass() {
        return this.formData.paymentType === 'pledge' ? 'gift-tab active' : 'gift-tab';
    }

    get oneTimeVariant() {
        return this.formData.paymentType === 'one-time' ? 'brand' : 'neutral';
    }

    get recurringVariant() {
        return this.formData.paymentType === 'recurring' ? 'brand' : 'neutral';
    }

    get pledgeVariant() {
        return this.formData.paymentType === 'pledge' ? 'brand' : 'neutral';
    }

    // Amount helpers
    get hasAmount() {
        return this.formData.amount > 0;
    }

    get formattedAmount() {
        return this.formData.amount ? this.formData.amount.toLocaleString() : '0';
    }

    get isAmountTabIncomplete() {
        return !(this.formData.amount > 0 && this.formData.paymentType);
    }

    // Pledge helpers
    get mockPledges() {
        return MOCK_PLEDGES.map(pledge => ({
            ...pledge,
            isSelected: this.selectedPledgeIds.includes(pledge.id),
            cssClass: this.selectedPledgeIds.includes(pledge.id) ? 'pledge-option selected' : 'pledge-option',
            formattedTotal: pledge.totalAmount.toLocaleString(),
            formattedPaid: pledge.amountPaid.toLocaleString(),
            formattedRemaining: pledge.amountRemaining.toLocaleString(),
            formattedInstallment: pledge.installmentAmount.toLocaleString()
        }));
    }

    get hasSelectedPledges() {
        return this.selectedPledgeIds.length > 0;
    }

    get hasMultiplePledges() {
        return this.selectedPledgeIds.length > 1;
    }

    get pledgeCount() {
        return this.selectedPledgeIds.length;
    }

    get formattedPledgeTotal() {
        return this.calculatePledgeTotal().toLocaleString();
    }

    get hasCustomPledgeAmount() {
        return this.customAmount && this.formData.amount > 0;
    }

    // Tab navigation handlers
    handleAmountTabClick() {
        this.mainTab = 'amount';
    }

    handleDesignationTabClick() {
        this.mainTab = 'designation';
    }

    handlePaymentTabClick() {
        this.mainTab = 'payment';
    }

    // Payment type handlers
    handleOneTimeClick() {
        this.updateField('paymentType', 'one-time');
    }

    handleRecurringClick() {
        this.updateField('paymentType', 'recurring');
    }

    handlePledgeClick() {
        this.updateField('paymentType', 'pledge');
    }

    // Amount handlers
    handleCustomAmountChange(event) {
        const value = event.target.value;
        this.customAmount = value;
        const numValue = parseFloat(value);
        if (!isNaN(numValue) && numValue > 0) {
            this.updateField('amount', numValue);
            this.updateField('is1812', false);
            
            // Update designation amount if one is selected
            if (this.selectedDesignationId) {
                this.updateSelectedDesignationAmount(numValue);
            }
        }
    }

    handlePledgeSelection(event) {
        const pledgeId = event.target.dataset.id;
        const isChecked = event.target.checked;
        
        let newSelectedPledges;
        if (isChecked) {
            newSelectedPledges = [...this.selectedPledgeIds, pledgeId];
        } else {
            newSelectedPledges = this.selectedPledgeIds.filter(id => id !== pledgeId);
        }
        
        this.selectedPledgeIds = newSelectedPledges;
        
        // Calculate total from all selected pledges
        const total = this.calculatePledgeTotal();
        this.updateField('amount', total);
        this.customAmount = '';
        
        // Auto-select designations for all selected pledges
        if (newSelectedPledges.length > 0) {
            const firstPledge = MOCK_PLEDGES.find(p => p.id === newSelectedPledges[0]);
            const designation = MOCK_DESIGNATIONS.find(d => d.name === firstPledge?.designation);
            if (designation) {
                this.handleDesignationSelect(designation.id);
            }
        }
    }

    calculatePledgeTotal() {
        return this.selectedPledgeIds.reduce((total, pledgeId) => {
            const pledge = MOCK_PLEDGES.find(p => p.id === pledgeId);
            return total + (pledge?.installmentAmount || 0);
        }, 0);
    }

    // Designation handlers
    handleBackFromDesignation() {
        this.mainTab = 'amount';
    }

    handleDesignationTabChange(event) {
        this.designationTab = event.detail;
        if (event.detail === 'hamilton') {
            this.selectedDesignations = [];
            this.autoSelectHamiltonFund();
        } else {
            this.selectedDesignationId = '';
        }
    }

    handleSearchChange(event) {
        this.searchTerm = event.detail;
    }

    handleDesignationAdd(event) {
        const designationId = event.detail;
        const designation = MOCK_DESIGNATIONS.find(d => d.id === designationId);
        if (designation && !this.selectedDesignations.find(d => d.id === designationId)) {
            this.selectedDesignations = [...this.selectedDesignations, {
                id: designation.id,
                name: designation.name,
                amount: 0
            }];
            this.updateDesignationsAndTotal();
        }
    }

    handleDesignationRemove(event) {
        const designationId = event.detail;
        this.selectedDesignations = this.selectedDesignations.filter(d => d.id !== designationId);
        this.updateDesignationsAndTotal();
    }

    handleDesignationAmountChange(event) {
        const { id, amount } = event.detail;
        this.selectedDesignations = this.selectedDesignations.map(d =>
            d.id === id ? { ...d, amount } : d
        );
        this.updateDesignationsAndTotal();
    }

    handleDedicationChange(event) {
        const { showDedication, dedicationType, inMemoryOf, honoreeRelationship } = event.detail;
        this.showDedication = showDedication;
        this.dedicationType = dedicationType;
        if (inMemoryOf !== undefined) {
            this.updateField('inMemoryOf', inMemoryOf);
        }
        if (honoreeRelationship !== undefined) {
            this.updateField('honoreeRelationship', honoreeRelationship);
        }
    }

    handleContinueToDesignation() {
        this.mainTab = 'designation';
    }

    handleContinueToPayment() {
        this.mainTab = 'payment';
    }

    // Payment handlers
    handleBackFromPayment() {
        this.mainTab = 'designation';
    }

    handlePaymentMethodChange(event) {
        this.updateField('paymentMethod', event.detail);
    }

    handleCardInputChange(event) {
        this.cardDetails = { ...event.detail };
    }

    handleDonorInfoChange(event) {
        const { field, value } = event.detail;
        this.updateField(field, value);
    }

    handleFormSubmit() {
        // Validation
        if (!this.formData.isLoggedIn) {
            if (!this.formData.name || !this.formData.classYear || !this.formData.email || !this.formData.affiliation) {
                this.showToast('Error', 'Please fill in all donor information fields', 'error');
                return;
            }
        }

        if (!this.selectedDesignationId && this.selectedDesignations.length === 0) {
            this.showToast('Error', 'Please select a designation', 'error');
            return;
        }

        if (!this.formData.amount || this.formData.amount <= 0) {
            this.showToast('Error', 'Please select or enter a donation amount', 'error');
            return;
        }

        if (!this.formData.paymentMethod) {
            this.showToast('Error', 'Please select a payment method', 'error');
            return;
        }

        if (this.formData.paymentMethod === 'card') {
            if (!this.cardDetails.name || !this.cardDetails.number || !this.cardDetails.expiry || !this.cardDetails.cvc) {
                this.showToast('Error', 'Please fill in all card details', 'error');
                return;
            }
        }

        // Dispatch complete event
        this.dispatchEvent(new CustomEvent('complete', {
            detail: this.formData
        }));
    }

    // Helper methods
    autoSelectHamiltonFund() {
        if (!this.formData.designations || this.formData.designations.length === 0) {
            const hamiltonFund = MOCK_DESIGNATIONS.find(d => d.name === 'Annual Fund');
            if (hamiltonFund) {
                this.selectedDesignationId = hamiltonFund.id;
                this.updateField('designations', [{
                    id: hamiltonFund.id,
                    name: hamiltonFund.name,
                    amount: this.formData.amount || 0
                }]);
            }
        }
    }

    handleDesignationSelect(designationId) {
        this.selectedDesignationId = designationId;
        const designation = MOCK_DESIGNATIONS.find(d => d.id === designationId);
        if (designation) {
            this.updateField('designations', [{
                id: designation.id,
                name: designation.name,
                amount: this.formData.amount || 0
            }]);
        }
    }

    updateSelectedDesignationAmount(amount) {
        const designation = MOCK_DESIGNATIONS.find(d => d.id === this.selectedDesignationId);
        if (designation) {
            this.updateField('designations', [{
                id: designation.id,
                name: designation.name,
                amount: amount
            }]);
        }
    }

    updateDesignationsAndTotal() {
        const total = this.selectedDesignations.reduce((sum, d) => sum + d.amount, 0);
        this.updateField('amount', total);
        this.updateField('designations', this.selectedDesignations);
    }

    updateField(field, value) {
        this.formData = { ...this.formData, [field]: value };
    }

    showToast(title, message, variant) {
        // In LWC, you would typically use lightning:platformShowToastEvent
        // For now, we'll use console and could integrate with LMS or events
        console.log(`${variant.toUpperCase()}: ${title} - ${message}`);
        alert(`${title}: ${message}`);
    }
}