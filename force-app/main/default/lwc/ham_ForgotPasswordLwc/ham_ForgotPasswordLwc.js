/**
 * @description Frontend JS controller managing user input state, CAPTCHA challenges,
 * and background Apex password reset verification.
 */
import { LightningElement, track, api } from 'lwc';
import initiateReset from '@salesforce/apex/Ham_ForgotPasswordController.initiateReset';

// Import Custom Labels
import forgotPasswordTitle from '@salesforce/label/c.Ham_ForgotPasswordTitle';
import forgotPasswordDesc from '@salesforce/label/c.Ham_ForgotPasswordDesc';
import forgotPasswordSuccessMsg from '@salesforce/label/c.Ham_ForgotPasswordSuccessMsg';
import forgotPasswordBtnLabel from '@salesforce/label/c.Ham_ForgotPasswordBtnLabel';
import forgotPasswordBackToLogin from '@salesforce/label/c.Ham_ForgotPasswordBackToLogin';
import emailInputLabel from '@salesforce/label/c.Ham_EmailInputLabel';
import emailPlaceholder from '@salesforce/label/c.Ham_EmailPlaceholder';
import captchaLabel from '@salesforce/label/c.Ham_CaptchaLabel';
import captchaInputLabel from '@salesforce/label/c.Ham_CaptchaInputLabel';
import captchaPlaceholder from '@salesforce/label/c.Ham_CaptchaPlaceholder';

// Import Error Labels
import errEmailRequired from '@salesforce/label/c.Ham_ErrEmailRequired';
import errInvalidEmailFormat from '@salesforce/label/c.Ham_ErrInvalidEmailFormat';
import errCaptchaMismatch from '@salesforce/label/c.Ham_ErrCaptchaMismatch';
import errUnexpectedState from '@salesforce/label/c.Ham_ErrUnexpectedState';
import errEmailUnverified from '@salesforce/label/c.Ham_ErrEmailUnverified';
import loginUrl from '@salesforce/label/c.ham_LoginLink';

export default class Ham_ForgotPasswordLwc extends LightningElement {
    @track emailAddress = '';
    @track userCaptchaInput = '';
    @track generatedCaptchaCode = '';
    @track errorMessage = '';
    @track showForm = true;
    @track isProcessing = false;
    @track isUnverified = false;
    @track unverifiedMessage = '';

    @api loginUrl;

    // Bundle labels inside a structural properties map
    label = {
        forgotPasswordTitle,
        forgotPasswordDesc,
        forgotPasswordSuccessMsg,
        forgotPasswordBtnLabel,
        forgotPasswordBackToLogin,
        emailInputLabel,
        emailPlaceholder,
        captchaLabel,
        captchaInputLabel,
        captchaPlaceholder,
        errEmailUnverified,
        loginUrl
    };

    connectedCallback() {
        this.generateNativeCaptcha();
    }

    get isResetDisabled() {
        return this.isProcessing || !this.emailAddress || !this.userCaptchaInput;
    }

    handleEmailChange(event) {
        this.emailAddress = event.target.value;
        this.errorMessage = '';
    }

    handleCaptchaInputChange(event) {
        this.userCaptchaInput = event.target.value;
        this.errorMessage = '';
    }

    refreshCaptchaCode() {
        this.generateNativeCaptcha();
        this.userCaptchaInput = '';
    }

    generateNativeCaptcha() {
        const allowedCharacters = 'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnpqrstuvwxyz23456789';
        let resultToken = '';
        for (let i = 0; i < 5; i++) {
            const randomIndex = Math.floor(Math.random() * allowedCharacters.length);
            resultToken += allowedCharacters.charAt(randomIndex);
        }
        this.generatedCaptchaCode = resultToken;
    }

    async handleResetPassword() {
        if (this.isResetDisabled) return;

        if (!this.emailAddress) {
            this.errorMessage = errEmailRequired;
            return;
        }

        const emailPatternRegex = /^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$/;
        if (!emailPatternRegex.test(this.emailAddress.trim())) {
            this.errorMessage = errInvalidEmailFormat;
            return;
        }

        // Exact case-sensitive CAPTCHA comparison check
        if (this.userCaptchaInput.trim() !== this.generatedCaptchaCode) {
            this.errorMessage = errCaptchaMismatch;
            this.generateNativeCaptcha();
            this.userCaptchaInput = '';
            return;
        }

        this.isProcessing = true;
        this.errorMessage = '';

        try {
            const response = await initiateReset({
                emailInput: this.emailAddress,
                captchaToken: 'CLIENT_VERIFIED_HUMAN_PASS',
                cacheBuster: String(Date.now())
            });

            if (response && response.status === 'SUCCESS') {
                this.showForm = false;
                this.isUnverified = false;
            } else if (response && response.status === 'VERIFICATION_SENT') {
                this.showForm = false;
                this.isUnverified = true;
                this.unverifiedMessage = response.message || this.label.errEmailUnverified;
            } else if (response && response.status === 'ERROR') {
                this.errorMessage = response.message;
                this.refreshCaptchaCode();
            }
        } catch (error) {
            this.errorMessage = errUnexpectedState;
            this.refreshCaptchaCode();
            console.error('Exception caught inside initiatePasswordReset: ', error);
        } finally {
            this.isProcessing = false;
        }
    }

    handleBackToLogin() {
        window.location.href = this.loginUrl || this.label.loginUrl;
    }
}