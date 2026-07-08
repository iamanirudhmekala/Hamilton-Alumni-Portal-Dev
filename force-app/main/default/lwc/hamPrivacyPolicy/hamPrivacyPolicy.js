import { LightningElement } from 'lwc';

export default class HamPrivacyPolicy extends LightningElement {

    selectedDocument = 'privacy';

    showPrivacy() {
        this.selectedDocument = 'privacy';
    }

    showAgreement() {
        this.selectedDocument = 'agreement';
    }

    get isPrivacy() {
        return this.selectedDocument === 'privacy';
    }

    get isAgreement() {
        return this.selectedDocument === 'agreement';
    }

    get privacyClass() {
        return this.selectedDocument === 'privacy'
            ? 'menu-item active'
            : 'menu-item';
    }

    get agreementClass() {
        return this.selectedDocument === 'agreement'
            ? 'menu-item active'
            : 'menu-item';
    }
}