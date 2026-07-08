/**
 * @description Frontend JS controller managing UI transformations, state logic,
 * and background Apex communication loops.
 * Features strict client-side regex syntax validation and a 120-second request cooldown clock.
 */
import { LightningElement, track, api } from 'lwc';
import initiateLogin from '@salesforce/apex/Ham_SecurePasswordlessLoginController.initiateLogin';
import verifyPasswordlessLogin from '@salesforce/apex/Ham_SecurePasswordlessLoginController.verifyPasswordlessLogin';

// Import View Labels
import altLoginTitle from '@salesforce/label/c.Ham_AltLoginTitle';
import altLoginDesc from '@salesforce/label/c.Ham_AltLoginDesc';
import emailInputLabel from '@salesforce/label/c.Ham_EmailInputLabel';
import emailPlaceholder from '@salesforce/label/c.Ham_EmailPlaceholder';
import captchaLabel from '@salesforce/label/c.Ham_CaptchaLabel';
import captchaInputLabel from '@salesforce/label/c.Ham_CaptchaInputLabel';
import captchaPlaceholder from '@salesforce/label/c.Ham_CaptchaPlaceholder';
import requestBtnLabel from '@salesforce/label/c.Ham_RequestBtnLabel';
import otpTitle from '@salesforce/label/c.Ham_OtpTitle';
import otpDesc from '@salesforce/label/c.Ham_OtpDesc';
import otpInputLabel from '@salesforce/label/c.Ham_OtpInputLabel';
import otpPlaceholder from '@salesforce/label/c.Ham_OtpPlaceholder';
import resendLockText from '@salesforce/label/c.Ham_ResendLockText';
import resendBtnLabel from '@salesforce/label/c.Ham_ResendBtnLabel';
import verifyBtnLabel from '@salesforce/label/c.Ham_VerifyBtnLabel';
import backBtnLabel from '@salesforce/label/c.Ham_BackBtnLabel';

// Import Error Labels
import errEmailRequired from '@salesforce/label/c.Ham_ErrEmailRequired';
import errInvalidEmailFormat from '@salesforce/label/c.Ham_ErrInvalidEmailFormat';
import errCaptchaMismatch from '@salesforce/label/c.Ham_ErrCaptchaMismatch';
import errUnexpectedState from '@salesforce/label/c.Ham_ErrUnexpectedState';

export default class Ham_PasswordlessLoginLwc extends LightningElement {
    @track emailAddress = '';
    @track otpCode = '';
    @track errorMessage = '';
    @track infoMessage = '';
    @track showEmailPage = true;
    @track showOtpPage = false;
    @track isProcessing = false;
    @track isAccordionOpen = false;

    // Captcha properties
    @track generatedCaptchaCode = '';
    @track userCaptchaInput = '';

    // Pacing handles
    @track resendCountdown = 120;
    @track isResendDisabled = true;

    countdownInterval;
    storedToken = '';
    storedUserId = '';

    @api startUrl = '';

    // Bundle custom labels inside a scannable structural property object
    label = {
        altLoginTitle,
        altLoginDesc,
        emailInputLabel,
        emailPlaceholder,
        captchaLabel,
        captchaInputLabel,
        captchaPlaceholder,
        requestBtnLabel,
        otpTitle,
        otpDesc,
        otpInputLabel,
        otpPlaceholder,
        resendBtnLabel,
        verifyBtnLabel,
        backBtnLabel
    };

    connectedCallback() {
        this.generateNativeCaptcha();
    }

    /**
     * @description Dynamic replacement utility mimicking String.format in LWC.
     * Merges current timer properties with the custom label text block dynamically.
     */
    get computedResendLockText() {
        return resendLockText ? resendLockText.replace('{0}', this.resendCountdown) : '';
    }

    get isRequestDisabled() {
        return this.isProcessing || !this.emailAddress || !this.userCaptchaInput;
    }

    get isVerifyDisabled() {
        return this.isProcessing || !this.otpCode || this.otpCode.length !== 6;
    }

    get accordionContainerClass() {
        return this.isAccordionOpen ? 'accordion-container is-open' : 'accordion-container';
    }

    get accordionHeaderClass() {
        return 'accordion-header';
    }

    get accordionArrow() {
        return this.isAccordionOpen ? '▲' : '▶';
    }

    toggleAccordion() {
        this.isAccordionOpen = !this.isAccordionOpen;
    }

    handleEmailChange(event) {
        this.emailAddress = event.target.value;
        this.errorMessage = '';
        this.infoMessage = '';
    }

    handleOtpChange(event) {
        this.otpCode = event.target.value;
        this.errorMessage = '';
        this.infoMessage = '';
    }

    handleCaptchaInputChange(event) {
        this.userCaptchaInput = event.target.value;
        this.errorMessage = '';
        this.infoMessage = '';
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

    handleNavigationBack() {
        this.clearCountdownClock();
        this.showOtpPage = false;
        this.showEmailPage = true;
        this.otpCode = '';
        this.errorMessage = '';
        this.infoMessage = '';
        this.userCaptchaInput = '';
        this.generateNativeCaptcha();
    }

    /**
     * @description Evaluates exact case checks and passes data payloads to the server layer.
     */
    async handleSendOtp() {
        if (this.isRequestDisabled) return;

        if (!this.emailAddress) {
            this.errorMessage = errEmailRequired;
            return;
        }

        const emailPatternRegex = /^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$/;
        if (!emailPatternRegex.test(this.emailAddress.trim())) {
            this.errorMessage = errInvalidEmailFormat;
            return;
        }

        // Exact, unmutated case-sensitive primitive check match verification block
        if (this.userCaptchaInput.trim() !== this.generatedCaptchaCode) {
            this.errorMessage = errCaptchaMismatch;
            this.generateNativeCaptcha();
            this.userCaptchaInput = '';
            return;
        }

        this.isProcessing = true;
        this.errorMessage = '';
        this.infoMessage = '';

        try {
            const response = await initiateLogin({
                emailInput: this.emailAddress,
                captchaToken: 'CLIENT_VERIFIED_HUMAN_PASS'
            });

            if (response && response.status === 'SUCCESS') {
                this.storedToken = response.token;
                this.storedUserId = response.userId;
                this.showEmailPage = false;
                this.showOtpPage = true;
                this.initializeResendTimer();
            } else if (response && response.status === 'VERIFICATION_SENT') {
                this.infoMessage = response.message;
                this.refreshCaptchaCode();
            } else if (response && response.status === 'ERROR') {
                // Captures and processes the explicit rate-limiting error label directly on Screen 1
                this.errorMessage = response.message;
                this.refreshCaptchaCode();
            }
        } catch (error) {
            this.errorMessage = errUnexpectedState;
            this.refreshCaptchaCode();
            console.error('Exception caught inside initiateLogin execution thread: ', error);
        } finally {
            this.isProcessing = false;
        }
    }

    async handleVerifyOtp() {
        if (this.isVerifyDisabled) return;

        this.isProcessing = true;
        this.errorMessage = '';

        try {
            const response = await verifyPasswordlessLogin({
                userId: this.storedUserId,
                token: this.storedToken,
                otpCode: this.otpCode,
                startUrl: this.startUrl
            });

            if (response && response.status === 'SUCCESS') {
                this.clearCountdownClock();
                window.location.href = response.loginUrl;
            } else {
                this.errorMessage = response.message || 'Verification rejected.';
                this.otpCode = '';
            }
        } catch (error) {
            this.errorMessage = errUnexpectedState;
            console.error('Exception caught inside verifyPasswordlessLogin execution thread: ', error);
        } finally {
            this.isProcessing = false;
        }
    }

    initializeResendTimer() {
        this.resendCountdown = 120;
        this.isResendDisabled = true;
        this.clearCountdownClock();

        this.countdownInterval = setInterval(() => {
            if (this.resendCountdown > 1) {
                this.resendCountdown--;
            } else {
                this.isResendDisabled = false;
                this.clearCountdownClock();
            }
        }, 1000);
    }

    clearCountdownClock() {
        if (this.countdownInterval) {
            clearInterval(this.countdownInterval);
            this.countdownInterval = null;
        }
    }

    disconnectedCallback() {
        this.clearCountdownClock();
    }
}