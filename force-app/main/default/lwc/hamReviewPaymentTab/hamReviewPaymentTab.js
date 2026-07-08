import { LightningElement, api, track } from 'lwc';
import createPaymentLink from '@salesforce/apex/HamGivingPagePaymentTabController.createPaymentLink';
import getStripeSuccessfulPaymentEvent from '@salesforce/apex/HamGivingPagePaymentTabController.getStripeSuccessfulPaymentEvent';
import saveReviewTransactionV2 from '@salesforce/apex/HamGivingPagePaymentTabController.saveReviewTransactionV2';
import savePaymentTransaction from '@salesforce/apex/HamGivingPagePaymentTabController.savePaymentTransaction';

const POLL_INTERVAL = 3000;
const POLL_MAX = 600000;

export default class HamReviewPaymentTab extends LightningElement {
    _formData = {};
    _currentContact = null;
    _giftPath = 'gift';

    @api
    get formData() { return this._formData; }
    set formData(value) { this._formData = value || {}; }

    @api
    get currentContact() { return this._currentContact; }
    set currentContact(value) {
        this._currentContact = value;
        if (value) {
            this.personName = value.name || '';
            this.personEmail = value.email || '';
        }
    }

    @api
    get giftPath() { return this._giftPath; }
    set giftPath(value) { this._giftPath = value || 'gift'; }

    @track personName = '';
    @track personEmail = '';
    @track isLoading = false;
    @track paymentInProgress = false;
    @track paymentCompleted = false;
    @track errorMessage = '';

    personCountry = '';
    personZipCode = '';
    personAddressLineOne = '';
    personAddressLineTwo = '';
    stripePaymentMethod = '';
    transactionDate = null;
    transactionId = null;
    paymentLinkId = null;
    timePassed = 0;
    maxPollingTime = POLL_MAX;
    pollerId = null;
    paymentErrorProcessed = false;

    get isPledgePath() { return this._giftPath === 'pledge'; }

    get paymentAmount() {
        if (this.isPledgePath) {
            const pledges = this._formData.selectedPledges || [];
            return pledges.reduce((sum, p) => sum + (parseFloat(p.amount) || 0), 0);
        }
        return parseFloat(this._formData.amount) || 0;
    }

    get paymentAmountFormatted() {
        return new Intl.NumberFormat('en-US', { style: 'currency', currency: 'USD' }).format(this.paymentAmount);
    }

    get donationToName() {
        if (this.isPledgePath) {
            const pledges = this._formData.selectedPledges || [];
            return pledges.map(p => p.designationName || p.name).join(', ') || 'Hamilton College';
        }
        const designations = this._formData.selectedDesignations || [];
        return designations.map(d => d.name).join(', ') || 'Hamilton College';
    }

    get canPay() {
        return this.personName.trim() && this.personEmail.trim() && !this.paymentInProgress;
    }

    get payBtnDisabled() { return !this.canPay; }

    get updatedFormData() {
        const base = {
            amount: this.paymentAmount,
            paymentType: this._formData.giftFrequency || 'once',
            personName: this.personName,
            personEmail: this.personEmail,
            personCountry: this.personCountry,
            personZipCode: this.personZipCode,
            paymentMethod: this.stripePaymentMethod,
            paymentMethodUI: 'Stripe',
            transactionDate: this.transactionDate,
            transactionId: this.transactionId,
            personAddressLineOne: this.personAddressLineOne,
            personAddressLineTwo: this.personAddressLineTwo,
            contactId: this._currentContact ? this._currentContact.id : null,
            giftPath: this._giftPath
        };

        if (this.isPledgePath) {
            const pledges = this._formData.selectedPledges || [];
            base.selectedDesignations = pledges.map(p => ({
                id: p.designationId,        // Designation__c lookup on RTV2
                name: p.designationName || p.name,
                amt: parseFloat(p.amount) || 0,
                pledgeId: p.id              // Opportunity Id — the pledge being paid against
            }));
        } else {
            const designations = this._formData.selectedDesignations || [];
            base.selectedDesignations = designations.map(d => ({
                id: d.id,
                name: d.name,
                amt: parseFloat(d.amount) || 0
            }));
            const tribute = this._formData.tributeData;
            if (tribute) {
                if (tribute.type === 'memory') {
                    base.inMemoryOf = tribute.name;
                } else {
                    base.inHonorOf = tribute.name;
                }
            }
        }

        return base;
    }

    disconnectedCallback() {
        if (this.pollerId) clearInterval(this.pollerId);
    }

    handleBack() {
        this.dispatchEvent(new CustomEvent('back'));
    }

    handleNameInput(event) { this.personName = event.target.value; }
    handleEmailInput(event) { this.personEmail = event.target.value; }

    async handlePayment() {
        if (!this.canPay) return;
        console.log('handle Payment---->');
        this.errorMessage = '';
        this.paymentErrorProcessed = false;
        this.timePassed = 0;
        this.maxPollingTime = POLL_MAX;
        this.paymentInProgress = true;
        console.log('Before Poller Method---->');
        // Start poller first — same order as hamGivingPaymentTab
        this.pollerId = setInterval(() => { this._pollStripe(); }, POLL_INTERVAL);

        await this._startStripePayment();
    }

    async _startStripePayment() {
        let paymentLinkObject = await createPaymentLink({
            amountCents: this.paymentAmount * 100,
            donationTo: this.donationToName
        });

        this.paymentLinkId = paymentLinkObject ? paymentLinkObject.id : null;

        const newWindow = window.open(
            (paymentLinkObject && paymentLinkObject.url ? paymentLinkObject.url : 'invalidURL') + '?prefilled_email=' + this.personEmail,
            '_blank',
            'height=720,width=500'
        );
        console.log('Payment Link---->',paymentLinkObject.url);
        let that = this;
        if (newWindow) {
            function pollForClose() {
                if (newWindow.closed) {
                    that.timePassed = 0;
                    that.maxPollingTime = 3000;
                } else {
                    requestAnimationFrame(pollForClose);
                }
            }
            requestAnimationFrame(pollForClose);
        }
    }

    _pollStripe() {
        if (this.paymentCompleted) {
            clearInterval(this.pollerId);
            return;
        }

        if (this.timePassed < this.maxPollingTime) {
            getStripeSuccessfulPaymentEvent({ paymentLinkId: this.paymentLinkId })
                .then(result => {
                    if (result && result.length > 0) {
                        clearInterval(this.pollerId);
                        this.transactionDate = result[0].CreatedDate;
                        this.transactionId = result[0].stripeGC__Stripe_Event_Id__c;

                        const payload = JSON.parse(result[0].stripeGC__Request_Body__c || '{}');
                        const methodOptions = payload?.data?.object?.payment_method_options;
                        if (methodOptions?.us_bank_account) {
                            this.stripePaymentMethod = 'ACH (Automated Clearing House)';
                        } else {
                            this.stripePaymentMethod = 'Credit Card';
                        }

                        const address = payload?.data?.object?.customer_details?.address;
                        if (address) {
                            this.personCountry = address.country || '';
                            this.personZipCode = address.postal_code || '';
                            const parts = [address.line1, address.city, address.state, address.country, address.postal_code].filter(Boolean);
                            const addrStr = parts.join(', ');
                            this.personAddressLineOne = addrStr.substring(0, 255);
                            if (addrStr.length > 255) {
                                this.personAddressLineTwo = addrStr.substring(255, 510);
                            }
                        }

                        this.paymentCompleted = true;
                        this.paymentInProgress = false;
                        saveReviewTransactionV2({ formDataJSON: this.updatedFormData });
                        savePaymentTransaction({ formDataJSON: this.updatedFormData, status: 'Success' });
                        this._firePaymentComplete();
                    }
                });
            this.timePassed += POLL_INTERVAL;
        } else {
            clearInterval(this.pollerId);
            this.paymentInProgress = false;
            if (!this.paymentCompleted && !this.paymentErrorProcessed) {
                savePaymentTransaction({ formDataJSON: this.updatedFormData, status: 'Failure' });
                this.errorMessage = 'Payment timed out or was cancelled. Please try again.';
                this.paymentErrorProcessed = true;
            }
        }
    }

    _firePaymentComplete() {
        this.dispatchEvent(new CustomEvent('paymentcomplete', {
            detail: this.updatedFormData
        }));
    }
}