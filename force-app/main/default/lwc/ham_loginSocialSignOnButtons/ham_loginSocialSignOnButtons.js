import { LightningElement,track } from 'lwc';
// import FORM_FACTOR from '@salesforce/client/formFactor';

import HAM_ICONS from '@salesforce/resourceUrl/HAM_Icons';
import BaseUrl from '@salesforce/label/c.ham_socialSignOnUrl';
import AndroidAppUrl from '@salesforce/label/c.ham_androidAppUrl';
import AppleAppUrl from '@salesforce/label/c.ham_appleAppUrl';

import { NavigationMixin } from 'lightning/navigation';

export default class Ham_loginSocialSignOnButtons extends  NavigationMixin(LightningElement) {

   @track showModal = false;

    mainResource = {
        hamIcons: HAM_ICONS
    };

    label = {
        baseUrl: BaseUrl,
        androidAppUrl: AndroidAppUrl,
        appleAppUrl: AppleAppUrl
    }

    images = {
        linkedIcon: this.mainResource.hamIcons + '/linkedin_POV.png',
        lnstaIcon: this.mainResource.hamIcons + '/instagram_POV.png',
        faceIcon: this.mainResource.hamIcons + '/facebook_POV.png',
        twitterIcon: this.mainResource.hamIcons + '/twitter_POV.png',
        linkedinIcon: this.mainResource.hamIcons + '/linkedIn_POV.png',
        googleIcon: this.mainResource.hamIcons + '/google.png',
        appleIcon: this.mainResource.hamIcons + '/apple_POV.png',
        googlePlayBadge: this.mainResource.hamIcons + '/google_play_badge.png',
        appStoreBadge: this.mainResource.hamIcons + '/app_store_badge.png'
    };

    get isMobileApp() {
        return navigator.userAgent.includes('SalesforceMobileSDK');
    }

    get hasAppleUrl() {
        return this.label.appleAppUrl && this.label.appleAppUrl.trim() !== '';
    }

    handleGoogleLogin() {
        window.location.href = this.label.baseUrl + 'Google_Social_Sign_On';
    }

    handleLinkedInLogin() {
        window.location.href = this.label.baseUrl + 'Log_in_with_LinkedIn';
    }

    handleFacebookLogin() {
        window.location.href = this.label.baseUrl + 'Log_in_with_Facebook';
    }
    handleAppleLogin() {
        window.location.href = this.label.baseUrl + 'Login_with_Apple';
    }

        openPrivacyPolicy() {
        this.showModal = true;
    }

    closeModal() {
        this.showModal = false;
    }
    
}