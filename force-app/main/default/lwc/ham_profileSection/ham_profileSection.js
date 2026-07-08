import { LightningElement, api, track, wire } from 'lwc';

//import apex methods
import getPrimaryContactType from '@salesforce/apex/HAM_MainController.getPrimaryContactType';

//importing static resources
import HAM_ICONS from '@salesforce/resourceUrl/HAM_Icons';

/**
 * @description A component that displays a user's personal profile information. 
 * It handles the display of various details, including contact information, degrees, and social media links.
 * It also includes a pop-up feature for a campus contact.
 */
export default class Ham_profileSection extends LightningElement {
    @api contact = {};
    @api majorMinor = {};
    @api facebookUrl;
    @api campusContact = {};
    @api myConnect = [];
    @api personalSection = [];
    @api label = {};
    @api mainResource;
    @api userContactId;
    @api socialMediaLinks = [];
    @api isOverride = false;

    get wrapperClass() {
        return this.isOverride ? 'left-panel kirkland-override' : 'left-panel';
    }
    @track isPopupVisible = false;
    @track screenWidth = window.innerWidth;
    @track images = {};
    @track isPrimaryConstituentTypeTrustee;

    hamicons = {
            kirklandLogo: `${HAM_ICONS}/kirkland-icon.png`,
            callImageGreen: `${HAM_ICONS}/call_green.png`,
            mailImageGreen: `${HAM_ICONS}/kirkland-icon.png`,

        };

    /**
     * @description Lifecycle hook that runs when the component is inserted into the DOM.
     * It sets up an event listener for window resizing and initializes image paths.
     */
    connectedCallback() {
        window.addEventListener('resize', this.handleResize.bind(this));
        this.images = {
            faceBookImage: this.mainResource + '/facebook.png',
            linkedInImage: this.mainResource + '/linkedin.png',
            mailImage: this.mainResource + '/mail.png',
            mailImageGreen: this.mainResource + '/mail_green.png',
            callImage: this.mainResource + '/call.png',
            callImageGreen: this.mainResource + '/call_green.png',
        };
    }

    /**
     * @description Lifecycle hook that runs when the component is removed from the DOM.
     * It removes the event listener to prevent memory leaks.
     */
    disconnectedCallback() {
        window.removeEventListener('resize', this.handleResize.bind(this));
    }

    /**
     * @description Updates the screenWidth tracked property on window resize.
     */
    handleResize() {
        this.screenWidth = window.innerWidth;
    }

    /**
     * @description Toggles the visibility of the campus contact pop-up.
     * It includes logic to prevent the pop-up from closing if the user clicks inside it.
     * @param {Event} event The click event object.
     */
    openConnectionPopUp(event) {
        const clickedInside = event.target.dataset.name;
        if (this.isPopupVisible && clickedInside === 'CampusContact') {
            this.isPopupVisible = false;
            return;
        } else {
            this.isPopupVisible = true;
        }
    }
    
    /**
     * @description Wire method to call the Apex method with the contactId.
     * It reactively calls the method whenever 'userContactId' is updated.
     * @param {Object} wiredContactData The wired result object containing the Contact record or null.
     */
    @wire(getPrimaryContactType, { contactId: '$userContactId' })
    wiredContactData({ error, data }) {
        if (data) {
            if (data.ucinn_ascendv2__Primary_Contact_Type__c) {
                let primaryContactType = data.ucinn_ascendv2__Primary_Contact_Type__c;
                this.isPrimaryConstituentTypeTrustee = primaryContactType === 'Trustee';
            } 

        } else if (error) {
            // Handle any error from the Apex method call
            
            console.error('<<getContactWithPrimaryType Error>>', error);
        }
    }

    /**
     * @description Closes the campus contact pop-up.
     */
    closeConnectionPopUp() {
        this.isPopupVisible = false;
    }

    /**
     * @description Builds icon metadata for each social media platform in socialMediaLinks.
     * Mirrors the pattern used in ham_previewProfileCmp.
     * @returns {Array} Array of objects with iconUrl, platform, handle, hasLink, linkClass.
     */
    get socialMediaIcons() {
        if (!this.socialMediaLinks || !this.socialMediaLinks.length) return [];
        return this.socialMediaLinks.map(item => {
            const platform = (item.platform || '').toLowerCase();
            let iconUrl = `${HAM_ICONS}/world.png`;
            if (platform.includes('linkedin'))       iconUrl = `${HAM_ICONS}/linkedin.png`;
            else if (platform.includes('facebook'))  iconUrl = `${HAM_ICONS}/facebook.png`;
            else if (platform.includes('instagram')) iconUrl = `${HAM_ICONS}/instagram.png`;
            else if (platform.includes('twitter'))   iconUrl = `${HAM_ICONS}/twitter.png`;
            const hasLink = !!item.handle;
            return {
                platform: item.platform,
                iconUrl,
                handle: item.handle || '',
                hasLink,
                linkClass: hasLink && this.isOverride ? 'social-link iskirkland-icon' : hasLink ? 'social-link' : this.isOverride ? 'social-link iskirkland-icon disabled' : 'social-link normal-theme disabled'
            };
        });
    }

    /**
     * @description Handles click on a social media icon, constructing the full URL
     * and opening it in a new tab. LinkedIn stores the full URL; others use handle + base path.
     * @param {Event} event The click event.
     */
    handleSocialClick(event) {
        event.preventDefault();
        const handle = event.currentTarget.dataset.handle;
        const platform = event.currentTarget.dataset.platform;
        if (!handle) return;
        let finalUrl = '';
        if (platform === 'LinkedIn') {
            // LinkedIn is stored as a full URL from HAM_LiveAlumni_LinkedIn_URL__c
            finalUrl = handle.startsWith('http') ? handle : 'https://www.linkedin.com/in/' + handle;
        } else if (platform === 'Facebook') {
            finalUrl = 'https://www.facebook.com/' + handle;
        } else if (platform === 'Instagram') {
            finalUrl = 'https://www.instagram.com/' + handle;
        } else if (platform === 'Twitter') {
            finalUrl = 'https://x.com/' + handle;
        }
        if (finalUrl) window.open(finalUrl, '_blank');
    }

    /**
     * @description Getter to determine if the current view is a desktop view.
     * @returns {boolean} True if the screen width is 1025px or more.
     */
    get isDesktopView() {
        return this.screenWidth >= 1025;
    }

    /**
     * @description Getter to determine if the current view is a mobile view.
     * @returns {boolean} True if the screen width is less than 1025px.
     */
    get isMobileView() {
        return this.screenWidth < 1025;
    }

    /**
     * @description Provides a safe URL for the LinkedIn button's href attribute.
     * It returns the linkedIn URL if it's a non-empty string, otherwise it returns null to prevent
     * the browser from creating a malformed link that points to the current page.
     * @returns {string | null} The valid LinkedIn URL string or null.
     */
    get linkedInLink() {
        return this.contact.linkedin ? this.contact.linkedin : null;
    }

    /**
     * @description Computes the CSS class for the LinkedIn button based on the presence of a URL.
     * It checks if the `contact.linkedin` property has a non-empty, non-whitespace value.
     * This getter ensures the button is visually enabled or disabled and has the correct styling.
     * @returns {string} The CSS class string to apply to the LinkedIn button element.
     */
    get linkedInClass() {
        return this.contact.linkedin ? "linkedin-button slds-button" : "linkedin-button-disabled slds-button";
    }
}