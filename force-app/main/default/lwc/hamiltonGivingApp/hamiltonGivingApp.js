import { api, LightningElement, track, wire } from 'lwc';
import isExperienceSite from '@salesforce/apex/HamGivingController.isExperienceSite';

export default class HamiltonGivingApp extends LightningElement {
    @api isSalesforceSite = false;

    @wire(isExperienceSite)
    communityId;

    isLoading = false;

    @track showThankYou = false;
    @track donationData = {
        isLoggedIn: false, // Toggle this to true to simulate logged-in state
        name: '',
        classYear: '',
        email: '',
        affiliation: '',
        lastGiftAmount: 250, // For demo when logged in
        constituentType: 'alumni', // For demo
        paymentType: 'one-time',
        designations: [],
        inMemoryOf: '',
        honoreeRelationship: '',
        amount: 0,
        paymentMethod: '',
        is1812: false
    };

    get userDisplayName() {
        return this.donationData.name || 'Donor';
    }

    handleComplete(event) {
        this.donationData = { ...event.detail };
        this.showThankYou = true;
    }

    handleReset() {
        const preservedData = {
            isLoggedIn: this.donationData.isLoggedIn,
            lastGiftAmount: this.donationData.lastGiftAmount,
            constituentType: this.donationData.constituentType
        };
        
        this.showThankYou = false;
        this.donationData = {
            ...preservedData,
            name: '',
            classYear: '',
            email: '',
            affiliation: '',
            paymentType: 'one-time',
            designations: [],
            inMemoryOf: '',
            honoreeRelationship: '',
            amount: 0,
            paymentMethod: '',
            is1812: false
        };
    }
    
    handleLoading(event) {
        this.isLoading = event.detail;
    }

    get isSfSite() {
        return this.isSalesforceSite || this.communityId.data;
    }

    get isCommunity() {
        return this.communityId.data
    }
}