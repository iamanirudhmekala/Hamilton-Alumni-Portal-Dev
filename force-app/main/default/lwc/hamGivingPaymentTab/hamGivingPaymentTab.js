import { LightningElement, api } from 'lwc';
import { updateBtnState } from 'c/hamGivingUtility';
import FORM_FACTOR from '@salesforce/client/formFactor';

import ApplePayLogo from '@salesforce/resourceUrl/ApplePayLogo';
import GPayLogo from '@salesforce/resourceUrl/GPayLogo';
import PayPalLogo from '@salesforce/resourceUrl/PayPalLogo';
import StripeLinkLogo from '@salesforce/resourceUrl/StripeLinkLogo';

import getStripeCredentials from '@salesforce/apex/HamGivingPagePaymentTabController.getStripeCredentials';
import createPaymentLink from '@salesforce/apex/HamGivingPagePaymentTabController.createPaymentLink';
import saveReviewTransactionV2 from '@salesforce/apex/HamGivingPagePaymentTabController.saveReviewTransactionV2';
import getStripeSuccessfulPaymentEvent from '@salesforce/apex/HamGivingPagePaymentTabController.getStripeSuccessfulPaymentEvent';
// import confirmPayment from '@salesforce/apex/HamGivingPagePaymentTabController.confirmPayment';
import getPersonDetails from '@salesforce/apex/HamGivingPagePaymentTabController.getPersonDetails';
import savePaymentTransaction from '@salesforce/apex/HamGivingPagePaymentTabController.savePaymentTransaction';


import { subscribe, unsubscribe, onError } from "lightning/empApi";

import { showInfoToast, showErrorToast } from 'c/hamGivingToastUtil';

// const STRIPE_JS = 'https://js.stripe.com/clover/stripe.js';
// import StripeJS from "@salesforce/resourceUrl/StripeJS";
// import { loadScript } from 'lightning/platformResourceLoader';


function updateBtnStates() {
    const mainTabs = this.template.querySelectorAll('.payment-tab__button');
    const mainTabIcons = this.template.querySelectorAll('.payment-button-icon');
    mainTabs.forEach(btn => {
        updateBtnState(btn, 'btn', this.tab, 'payment-tab__button--active', 'payment-tab__button--inactive');
    });
    mainTabIcons.forEach(btn => {
        updateBtnState(btn, 'btn', this.tab, 'payment-tab__button-icon--active', 'payment-tab__button-icon--inactive');
    });
}

function updatePaymentMethodStates() {
    const walletButtons = this.template.querySelectorAll('.wallet-btn');
    walletButtons.forEach(btn => {
        updateBtnState(btn, 'btn', this.paymentMethod, 'wallet-btn-selected', 'wallet-btn-not-selected');
    });
}

export default class HamGivingPaymentTab extends LightningElement {
    @api
    formData;

    @api contactId;
    @api userId;

    @api isSalesforceSite;

    toastTitle = '';
    toastMessage = '';
    toastVariant = 'error';
    displayToast = false;

    subscription = {};
    // channelName = '/event/Stripe_Event__e';

    // poller for a successful transaction 
    pollerId;
    // 10 minutes
    maxPollingTime = 600000; 
    timePassed = 0;
    // 3 sec
    timeInterval = 3000;

    paymentCompleted = false;
    transactionDate;
    transactionId;
    stripePaymentMethod = '';

    selectAffiliation;

    _updateBtnStates = updateBtnStates.bind(this);
    _updatePaymentMethodStates = updatePaymentMethodStates.bind(this);
    _showInfoToast = showInfoToast.bind(this);
    _showErrorToast = showErrorToast.bind(this);

    tab = 'card';

    isDigitalWallet = false;
    isCard = true;
    isACHWire = false;
    isDAF = false;
    isStock = false;

    applePayImage = ApplePayLogo;
    gPayImage = GPayLogo;
    payPalImage = PayPalLogo;
    stripeLinkImage = StripeLinkLogo;

    affilicationSelection = ''; 


    requireAlumniRegistration = true;
    displayAlumniRegistrationBox = false;

    stripe;
    stripeCredentials;
    isStripeLoaded = false;

    paymentInProgress = false;
    showSpinner = true;
    paymentErrorProcessed = false;

    paymentMethod;

    paymentLinkId;

    personName = '';
    personEmail = '';
    personAddressLineOne = '';
    personAddressLineTwo= '';
    personZipCode = '';
    personCountry = '';

    affiliationOptions = [
        {
            label: 'Select',
            value: '',
        },
        {
            label: 'Alumni',
            value: 'alumni',
        },
        {
            label: 'Parent',
            value: 'parent',
        },
        {
            label: 'Friend',
            value: 'friend',
        },
        {
            label: 'Faculty',
            value: 'faculty',
        },
        {
            label: 'Staff',
            value: 'staff',
        },
        {
            label: 'Student',
            value: 'student',
        },
    ];

    isSmallScreen = false;

    connectedCallback() {
        getPersonDetails({userId: this.userId, contactId: this.contactId}).then(result => {
            if (result) {
                if (result.email) {
                    this.personEmail = result.email;
                }
                if (result.fullName) {
                    this.personName = result.fullName;
                }
            }
        });

        // Initialize responsive flag and listen for window resizes
        this.isSmallScreen = (FORM_FACTOR === 'Small') || window.innerWidth < 768;;
        window.addEventListener('resize', () => {
            this.isSmallScreen = window.innerWidth < 768;
        });
    }

    // connectedCallback() {
    //     // Subscribe to the channel
    //     subscribe(this.channelName, -1, (response) => {
    //         console.log('Event received: ', JSON.stringify(response));

    //         if (response?.data?.payload?.Payload__c) {
    //             let payload = JSON.parse(response.data.payload.Payload__c);
    //             this.transactionDate = response.data.payload?.CreatedDate;
    //             this.transactionId = payload.id;

    //             if (
    //                 this.personEmail === payload?.data?.object?.customer_details?.email
    //                 &&
    //                 (this.paymentAmount * 100) === payload?.data?.object?.amount_total
    //             ) {
    //                 this.paymentCompleted = true;
    //                 this.paymentInProgress = false;
    //                 this.showSpinner = false;
    //                 console.log('payment completed');

    //                 let payment_method_options = payload?.data?.object?.payment_method_options;
    //                 if (payment_method_options.card) {
    //                     this.stripePaymentMethod = 'Credit Card';
    //                 }

    //                 if (payment_method_options.us_bank_account) {
    //                     this.stripePaymentMethod = 'US Bank Account';
    //                 }

    //                 let address = payload?.data?.object?.customer_details?.address;
    //                 if (address) {
    //                     let addressesList = [];
    //                     if (address.line1) {
    //                         addressesList.push(address.line1);
    //                     }
    //                     if (address.city) {
    //                         addressesList.push(address.city);
    //                     }
    //                     if (address.state) {
    //                         addressesList.push(address.state);
    //                     }
    //                     if (address.country) {
    //                         addressesList.push(address.country);
    //                     }
    //                     if (address.postal_code) {
    //                         addressesList.push(address.postal_code);
    //                     }

    //                     let addressStringConcat = addressesList.join(', ');
    //                     if (addressStringConcat && addressStringConcat.length < 255) {
    //                         this.personAddressLineOne = addressStringConcat;
    //                     } else if (addressStringConcat) {
    //                         this.personAddressLineOne = addressStringConcat.substring(0, 255);
    //                         const restOfAddress = addressStringConcat.substring(255);
    //                         if (restOfAddress.length < 255) {
    //                             this.personAddressLineTwo = restOfAddress;
    //                         } else {
    //                             this.personAddressLineTwo = restOfAddress.substring(0, 255);
    //                         }
    //                     }
    //                 }

    //                 saveReviewTransactionV2({ formDataJSON : this.updatedFormData });
    //                 this.handlePaymentComplete();
    //             }
    //         }
    //     }).then(response => {
    //         this.subscription = response;
    //     });

    //     // Register error listener
    //     onError(error => {
    //         console.error('EMP API error: ', error);
    //     });
    // }

    disconnectedCallback() {
        // unsubscribe(this.subscription, () => {
        //     console.log('Unsubscribed');
        // });
        clearInterval(this.pollerId); 
    }

    async renderedCallback() {
        this._updateBtnStates();

        if (!this.isLoaded) {
            let stripeCredentialsList = await getStripeCredentials();
            if (stripeCredentialsList && stripeCredentialsList.length > 0) {
                this.stripeCredentials = stripeCredentialsList[0];
                console.log('GOT Stripe Creds');

                // if (this.template.querySelector('.stripe-card-container')) {
                    
                // }
                // this.initializeStripe();
                this.isLoaded = true;
                this.showSpinner = false;
            }
        }  
    }

    // initializeStripe() {
    //     console.log('STRIPE INIT');
    //     // window.document.addEventListener('DOMContentLoaded', () => {
            
    //     // });
    //     console.log('in scriptloading');
    //     const script = document.createElement('script');
    //     script.src = STRIPE_JS;
    //     script.async = true;
    //     script.onload = () => {
    //         console.log('SCRIPT loaded');
    //         this.stripe = Stripe(this.stripeCredentials.Publishable_Key__c);
    //         this.elements = this.stripe.elements();
    //         // this.card = this.elements.create('card');
    //         // this.card.mount(this.template.querySelector('.stripe-card-container'));
    //         console.log('SCRIPT loaded AFTER');
    //         this.showSpinner = false;
    //     };
    //     document.body.appendChild(script);
    // }
    
    handleBackToDesignation() {
        const backToDesignationEvent = new CustomEvent('back', {
            detail: 'designation'
        });
        this.dispatchEvent(backToDesignationEvent);
    }

    tabClicked(event) {
        this.tab = event.target.dataset.btn;
        this._updateBtnStates();

        this.isDigitalWallet = false;
        this.isCard = false;
        this.isACHWire = false;
        this.isDAF = false;
        this.isStock = false;
        // this.paymentMethod = this.tab;
        this.paymentMethod = '';

        
        switch (this.tab) {
            case 'digitalWallet':
                this.isDigitalWallet = true;
                break;
            case 'card':
                this.isCard = true;
                break;
            case 'achWire':
                this.isACHWire = true;
                break;
            case 'daf':
                this.isDAF = true;
                break;
            case 'stock':
                this.isStock = true;
                break;
        }
    }

    get paymentMethodNotAvailable() {
        return this.isDAF || this.isStock;
    }

    get getStaticToastMessage() {
        return this.isDAF || this.isStock ?
            "Under Development for Phase 3" : "";   
    }

    get getDisabledClass() {
        return this.isDAF || this.isStock ? 'section-disabled' : '';
    }

    get getHiddenClass() {
        return this.isDAF || this.isStock ? 'hidden-section' : '';
    }

    get submitBtnClasses() {
        return this.isDAF || this.isStock || this.paymentInProgress ? 'btn submit-btn submit-disabled' : 'btn submit-btn';
    }

    handleAffilicationSelection(event) {
        this.affilicationSelection = event.target.value;
        this.displayAlumniRegistrationBox = this.affilicationSelection === 'alumni' || this.affilicationSelection === 'student';
    }

    get isNameEmailValid() {
        const nameField = this.template.querySelector('.wallet-name');
        const emailField = this.template.querySelector('.wallet-email');
        this.applyFieldValidity(nameField, 'name-error', 'This field is required');
        this.applyFieldValidity(emailField, 'email-error', 'Invalid email address');

        console.log('nameField.checkValidity()   ' + nameField.reportValidity());
        console.log('emailField.checkValidity()   ' + emailField.reportValidity());
        return nameField.reportValidity() && emailField.reportValidity();
    }

    applyFieldValidity(element, errorMessageDataId, errorMessage) {
        const EMAIL_REGEXP = /^(([^<>()[\].,;:\s@"]+(\.[^<>()[\].,;:\s@"]+)*)|(".+"))@(([^<>()[\].,;:\s@"]+\.)+[^<>()[\].,;:\s@"]{2,})$/

        let isValid = element ? 
                        element.type === 'email' ? EMAIL_REGEXP.test(element.value) : element.type === 'text' && element.value && element.value !== ''
                    : false;

        let errorMessageSpan = this.template.querySelector('[data-id="' + errorMessageDataId + '"]');

        if (element && isValid) {
            element.classList.add('input-field-wallet-valid');
            element.classList.remove('input-field-wallet-invalid');
            element.setCustomValidity(''); 
            if (errorMessageSpan) {
                errorMessageSpan.textContent = '';
            }
        } else if (element) {
            element.classList.add('input-field-wallet-invalid');
            element.classList.remove('input-field-wallet-valid');
            element.setCustomValidity(errorMessage); 
            if (errorMessageSpan) {
                errorMessageSpan.textContent = errorMessage;
            }
        }
    }

    pollStripePaymentEvent() { 
        if (this.timePassed < this.maxPollingTime) { 
            getStripeSuccessfulPaymentEvent({paymentLinkId: this.paymentLinkId}).then(result => {
                console.log('polling iteration');
                if (result && result.length > 0) {

                    this.transactionDate = result[0].CreatedDate;
                    this.transactionId = result[0].stripeGC__Stripe_Event_Id__c;
                    let stripeSFRecordId = result[0].Id;

                    this.paymentCompleted = true;
                    this.paymentInProgress = false;
                    this.showSpinner = false;
                    console.log('payment completed');

                    let payload = JSON.parse(result[0].stripeGC__Request_Body__c);
                    let payment_method_options = payload?.data?.object?.payment_method_options;
                    if (payment_method_options.card) {
                        this.stripePaymentMethod = 'Credit Card';
                    }

                    if (payment_method_options.us_bank_account) {
                        this.stripePaymentMethod = 'ACH (Automated Clearing House)';
                    }

                    let address = payload?.data?.object?.customer_details?.address;
                    if (address) {
                        let addressesList = [];

                        this.personCountry = address.country;
                        this.personZipCode = address.postal_code;

                        if (address.line1) {
                            addressesList.push(address.line1);
                        }
                        if (address.city) {
                            addressesList.push(address.city);
                        }
                        if (address.state) {
                            addressesList.push(address.state);
                        }
                        if (address.country) {
                            addressesList.push(address.country);
                        }
                        if (address.postal_code) {
                            addressesList.push(address.postal_code);
                        }

                        let addressStringConcat = addressesList.join(', ');
                        if (addressStringConcat && addressStringConcat.length < 255) {
                            this.personAddressLineOne = addressStringConcat;
                        } else if (addressStringConcat) {
                            this.personAddressLineOne = addressStringConcat.substring(0, 255);
                            const restOfAddress = addressStringConcat.substring(255);
                            if (restOfAddress.length < 255) {
                                this.personAddressLineTwo = restOfAddress;
                            } else {
                                this.personAddressLineTwo = restOfAddress.substring(0, 255);
                            }
                        }
                    }

                    saveReviewTransactionV2({ formDataJSON : this.updatedFormData });
                    // confirmPayment({stripeEventId: stripeSFRecordId});
                    savePaymentTransaction({ formDataJSON : this.updatedFormData, status: 'Success' });
                    this.handlePaymentComplete();
                }
		    });
           this.timePassed += this.timeInterval; 
       } else {
            clearInterval(this.pollerId);
            this.paymentInProgress = false;
            this.showSpinner = false;

            if (!this.paymentCompleted && !this.paymentErrorProcessed) {
                savePaymentTransaction({ formDataJSON : this.updatedFormData, status: 'Failure' });
                this.toastTitle = 'Payment failed or canceled';
                this.toastMessage = 'Initiate a new payment to try again.';
                this.toastVariant = 'error';
                this._showErrorToast();
                this.paymentErrorProcessed = true;
            }
       }
   } 

    async handlePayment() {
        this.maxPollingTime = 600000; 
        this.timePassed = 0;
        this.timeInterval = 3000;
        this.pollerId = setInterval(()=> { 
            this.pollStripePaymentEvent();
        }, this.timeInterval);

        if (this.paymentMethod && this.paymentMethod != '' && this.isNameEmailValid) {
            this.paymentInProgress = true;
            this.showSpinner = true;
            this.paymentErrorProcessed = false;

            switch (this.tab) {
                case 'digitalWallet':
                    switch (this.paymentMethod) {
                        case 'stripeLink':
                            await this.startStripePayment();
                            break;
                        case 'googlePay':
                            await this.startStripePayment();
                            break;
                        case 'applePay':
                            await this.startStripePayment();
                            break;
                        case 'payPal':
                            await this.startStripePayment();
                            break;
                    }
                    break;
                case 'card':
                    console.log('CARD payment');
                    await this.startStripePayment();
                    break;
                case 'achWire':
                    await this.startStripePayment();
                    break;
            }
        }
    }

    paymentMethodSelected(event) {
        this.paymentMethod = event.target.dataset.btn;
        // TODO: _updatePaymentMethodStates is called twice intentionally (sometimes doesn't work for the first time)
        // TODO: fix later
        this._updatePaymentMethodStates();
        this.paymentMethod = event.target.dataset.btn;
        this._updatePaymentMethodStates();
    }

    personNameChange(event) {
        this.personName = event.target.value;
        this.applyFieldValidity(event.target, 'name-error', 'This field is required');
    }

    personEmailChange(event) {
        this.personEmail = event.target.value;
        this.applyFieldValidity(event.target, 'email-error', 'Invalid email address');
    }

    handleCloseToast(event) {
        this.displayToast = false;
    }

    get donationToName() {
        let namesList = [];
        let selectedDesignations = this.formData?.selectedDesignations;
        selectedDesignations.forEach(function(item, index) {
            namesList.push(item.name);
        });

        return namesList.join(', ');
    }

    get paymentAmount() {
        return this.formData && this.formData?.amount > 0 ? this.formData?.amount : 0;
    }

    get paymentAmountStringFormatted() {
        return this.paymentAmount.toLocaleString();
    }

    async startStripePayment() {
        this.toastTitle = 'Payment in progress';
        this.toastMessage = 'Complete the payment in a new pop-up window: https://buy.stripe.com';
        this.toastVariant = 'info';
        this._showInfoToast();
        let paymentLinkObject = await createPaymentLink({
            amountCents: this.paymentAmount * 100,
            donationTo: this.donationToName
        });

        this.paymentLinkId = paymentLinkObject.id;
        console.log('paymentLink   ', paymentLinkObject);
        const newWindow = window.open(
            (paymentLinkObject.url ? paymentLinkObject.url : 'invalidURL') + '?prefilled_email=' + this.personEmail,
            '_blank',
            'height=720,width=500'
        );
        let that = this;
        if (newWindow) {
            function pollForClose() {
                if (newWindow.closed) {
                    console.log('The Stripe payment window has been closed.');
                    // that.paymentInProgress = false;
                    // that.showSpinner = false;

                    // saveReviewTransactionV2({ formDataJSON : that.updatedFormData });
                    // that.handlePaymentComplete().bind(that);
                    // if (!that.paymentCompleted) {
                    //     that.toastTitle = 'Payment failed or canceled';
                    //     that.toastMessage = 'Initiate a new payment to try again.';
                    //     that._showErrorToast();
                    // }
                    that.timePassed = 0;
                    // wait for 3 sec after payment window is closed
                    that.maxPollingTime = 3000;
                } else {
                    requestAnimationFrame(pollForClose);
                }
            }
            requestAnimationFrame(pollForClose);
        }
    }

    get paymentMethodLabel() {
        const methodMap = {
            'card': 'Credit/Debit Card',
            'googlePay': 'Google Pay',
            'applePay': 'Apple Pay',
            'payPal': 'PayPal',
            'stripeLink': 'Digital Payment',
            'achWire': 'ACH/Wire Transfer',
            'daf': 'Donor Advised Fund',
            'stock': 'Stock Transfer'
        };
        return methodMap[this.paymentMethod] || 'Other';
    }

    get updatedFormData() {
        return {
            ...this.formData,
            personName: this.personName,
            personEmail: this.personEmail,
            personCountry: this.personCountry,
            personZipCode: this.personZipCode,
            paymentMethod: this.stripePaymentMethod,
            paymentMethodUI: this.paymentMethodLabel,
            transactionDate: this.transactionDate,
            transactionId: this.transactionId,
            personAddressLineOne: this.personAddressLineOne,
            personAddressLineTwo: this.personAddressLineTwo,
            contactId: this.contactId
        };
    }

    handlePaymentComplete() {
        console.log('this.personName  ' + this.personName);
        const handlePaymentComplete = new CustomEvent('paymentcomplete', {
            detail:  this.updatedFormData,
            bubbles: true
        });
        this.dispatchEvent(handlePaymentComplete);
    }
}