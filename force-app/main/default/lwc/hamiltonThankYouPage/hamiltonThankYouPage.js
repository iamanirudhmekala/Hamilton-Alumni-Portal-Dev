import { LightningElement, api } from 'lwc';
import THANK_YOU_LOGO from '@salesforce/resourceUrl/GivingPortalThankYouLogo';


export default class HamiltonThankYouPage extends LightningElement {
    @api data;

    connectedCallback() {
        // Simulate sending confirmation email
    }

    get formattedAmount() {
        return this.paymentAmount ? this.paymentAmount.toLocaleString() : '0';
    }

    get paymentAmount() {
        return this.data && this.data.amount > 0 ? this.data.amount : 0;
    }

    get paymentTypeLabel() {
        if (this.data.paymentType === 'once') {
            return 'One-Time Gift';
        } else if (this.data.paymentType === 'monthly') {
            return 'Recurring Gift';
        } else {
            return 'Pledge Payment';
        }
    }

    get showDonorName() {
        return !this.data.isLoggedIn && this.data.name;
    }

    get personEmail() {
        return this.data && this.data.personEmail ? this.data.personEmail : '';
    }

    // get paymentMethodLabel() {
    //     const methodMap = {
    //         'card': 'Credit/Debit Card',
    //         'googlePay': 'Google Pay',
    //         'applePay': 'Apple Pay',
    //         'payPal': 'PayPal',
    //         'stripeLink': 'Digital Payment',
    //         'achWire': 'ACH/Wire Transfer',
    //         'daf': 'Donor Advised Fund',
    //         'stock': 'Stock Transfer'
    //     };
    //     return methodMap[this.data.paymentMethod] || 'Other';
    // }

    get paymentMethodLabel() {
        return this.data.paymentMethodUI;
    }

    handleReset() {
        this.dispatchEvent(new CustomEvent('reset'));
    }

    handleDownloadReceipt() {
        // In actual Salesforce, this would generate and download a PDF receipt
        console.log('Downloading receipt for donation:', this.data);
        alert('Receipt download functionality would be implemented here with Salesforce PDF generation.');
    }

    get thankYouLogoUrl() {
        return THANK_YOU_LOGO;
    }

    get hasInMemoryInHonor() {
        return this.data?.inMemoryOf || this.data?.inHonorOf;
    }

    get inMemoryInHonorName() {
        return this.data?.inMemoryOf ? this.data.inMemoryOf : this.data?.inHonorOf;
    }

    get designationsList() {
        let designationsList = [];
        if (this.data?.selectedDesignations) {
            designationsList = JSON.parse(JSON.stringify(this.data?.selectedDesignations));;
         
            designationsList.forEach(item => {
                item.amtFormatted = item.amt?.toLocaleString();
            });
        }
        return designationsList;
    }
    get hasDesignations() {
        return this.data?.selectedDesignations && this.data?.selectedDesignations.length > 0;
    }
}