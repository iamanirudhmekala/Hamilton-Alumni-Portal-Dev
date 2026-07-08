import { LightningElement, track } from 'lwc';

/**
 * @description A component to embed Protopia applications (Main App and Webform) via iframes.
 * It handles responsive layout switching between a Tabset (Mobile) and Side-by-Side (Desktop) view.
 */
export default class HamProtopiaViewer extends LightningElement {
    // URLs for the external applications
    mainAppUrl = 'https://une.protopia.co/';
    webformUrl = 'https://hermes-demo.protopia.co/community-request/68b9f0bec7047f00123621c4';

    @track screenWidth = window.innerWidth;
    @track isMainAppLoading = true;
    @track isWebformLoading = true;

    /**
     * @description Lifecycle hook that runs when the component is inserted into the DOM.
     * Sets up the window resize event listener.
     */
    connectedCallback() {
        window.addEventListener('resize', this.handleResize.bind(this));
    }

    /**
     * @description Lifecycle hook that runs when the component is removed from the DOM.
     * Removes the window resize event listener to prevent memory leaks.
     */
    disconnectedCallback() {
        window.removeEventListener('resize', this.handleResize.bind(this));
    }

    /**
     * @description Updates the screenWidth property when the window is resized.
     */
    handleResize() {
        this.screenWidth = window.innerWidth;
    }

    /**
     * @description Handler for the Main App iframe onload event.
     * Hides the loading spinner for the Main App.
     */
    handleMainAppLoad() {
        this.isMainAppLoading = false;
    }

    /**
     * @description Handler for the Webform iframe onload event.
     * Hides the loading spinner for the Webform.
     */
    handleWebformLoad() {
        this.isWebformLoading = false;
    }

    /**
     * @description Computed property to determine if the view should be mobile (Tabset) or desktop (Side-by-Side).
     * Uses 950px as the breakpoint to match the main container's logic.
     * @returns {boolean} True if screen width is less than 950px.
     */
    get isMobile() {
        return this.screenWidth < 950;
    }
}