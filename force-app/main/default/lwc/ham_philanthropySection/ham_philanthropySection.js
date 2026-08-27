import { LightningElement, track, api, wire } from 'lwc';
import { publish, MessageContext } from 'lightning/messageService';
import MY_IMPACT_CHANNEL from '@salesforce/messageChannel/myImpactChannel__c';
import getDescribeMyImpact from '@salesforce/apex/HAM_MyImpactController.getDescribeMyImpact';
import saveDescribeMyImpact from '@salesforce/apex/HAM_MyImpactController.saveDescribeMyImpact';

/**
 * @description A component to display an overview of a user's philanthropy highlights.
 * It uses Lightning Message Service to communicate with other components and handles button clicks to trigger actions.
 */
export default class Ham_philanthropySection extends LightningElement {
    @api hcBadges = [];
    @api philanthropySections = [];
    @api label = {};
    @api mainResource;
    @api images = {};
    @api pageflag=false;
    @api contactId;
    @track screenWidth = window.innerWidth;
    _isOverride = false;

    // -------- Describe My Impact modal state --------
    @track isDescribeModalOpen = false;
    @track describeMyImpactValue = '';
    @track isDescribeLoading = false;
    @track isDescribeSaving = false;
    @track describeErrorMessage = '';

    @api
    get isOverride() {
        return this._isOverride;
    }

    set isOverride(value) {
        this._isOverride = value;
    }

    /**
     * @description Lifecycle hook that runs when the component is inserted into the DOM.
     * It initializes the image paths.
     */
    connectedCallback() {
        this.images = {
            makeaGiftImage: this.mainResource + '/gift-outline.png',
            logoutImage: this.mainResource + '/exit-outline.png',
            widgetRedirect: this.mainResource + '/widget-redirect.png',
            widgetRedirectGreen: this.mainResource + '/widget-redirect-green.png'
        };
        
        window.addEventListener('resize', this.handleResize.bind(this));
    }


    /**
     * @description Lifecycle hook that runs when the component is removed from the DOM.
     */
    disconnectedCallback() {
     
        // Remove event listener when component is removed from DOM
        window.removeEventListener('resize', this.handleResize.bind(this));
    }

    /**
     * @description Updates the screen width property on window resize.
     */
    handleResize() {
        this.screenWidth = window.innerWidth;
    }

    // Getter to return dynmic badges based on screen width, for mobile view only 2 badges needs to be shown.
    get dynamicBadges(){
        return this.screenWidth >= 1024 ? this.hcBadges : this.pageflag ? this.hcBadges.slice(0, 5) : this.hcBadges;
    }

    // Getter to return the badges style for mobile and home view.
    get mobileIconContainerStyle(){
        return this.pageflag && this.screenWidth <1024 
        ? `flex-basis: 30%;display: flex;justify-content:flex-start;align-items: left;`
        :'';
    }   

    get infoSectionClass(){
        return this.pageflag && this.screenWidth >= 1024 ? 'info-section info-section-home' : 'info-section';
    }


    // Getter to return the dynamic philanthropy data based on screen width, for mobile only Lifetime Impact section is needed.
    get dynamicPhilanthropyData(){
        if (this.screenWidth >= 1024) {
            return this.philanthropySections;
        }
        else{
            const lifetimeImpact = this.philanthropySections?.find(section => section.name === 'Lifetime Impact');
            return this.pageflag ? lifetimeImpact ? [lifetimeImpact] : [] :this.philanthropySections; 
        }
        
    }

    // Getter to return true flag when screen width is of desktop resolution
    get isDesktopView() {
        // Define desktop breakpoint (e.g., 769px or more)
        return this.screenWidth >= 1024;
    }

    // Getter to return true flag when screen width is of mobile resolution
    get isMobileView() {
        return this.screenWidth <1024;
    }

    get wrapperClass() {
        return this.isOverride ? 'right-panel kirkland-override' : 'right-panel';
    }

    // Getter to return dynamic impact label based on screen width.
    get myimpact(){
        return this.screenWidth >= 1024 ? this.label.myimpact : this.label.mobileImpact;
    }

    /**
     * @description Wire service to inject the Lightning Message Service context.
     * This context is required to publish messages to a channel.
     */
    @wire(MessageContext)
    messageContext;

    /**
     * @description Custom event passed to grandparent component (Main) that will redirect to My Impact page.
     * It triggers when redirect icon is clicked
     */
    handleMyImpactNavigation(){
        this.dispatchEvent(new CustomEvent('navigateevent', {
            detail: this.label.myimpact,
            bubbles: true,
            composed: true
        }));
    }

    

     /**
     * @description Handles the click event for the "Deeper Dive" button.
     * It publishes a message to a channel to signal a state change in another component.
     * It also dispatches a custom event to the parent to trigger a scrolling action.
     */
    handleButtonClick() {
        // Create the message payload
        const payload = {
            CalledFrom: 'Deeper Dive' 
        };
        // Publish the message to the message channel
        publish(this.messageContext, MY_IMPACT_CHANNEL, payload);
        this.dispatchEvent(
            new CustomEvent('scrolltophilanthropy', {
                bubbles: true, // Let it bubble up to parent
                composed: true // Allow crossing Shadow DOM boundary
            })
        );
    }

    /**
     * @description getter to check if pageflag value is True of False.
       @param pageflag
     */
    get ispageflagFalse() {
        return this.pageflag === false;
    }

    /**
    * @description Closes settings and dispatches event to navigate to giving page
    */
    handleMakeGiftClick() {
        this.dispatchEvent(new CustomEvent('makegift', {
                bubbles: true, 
                composed: true
            }));
    }

    // ==================== Describe My Impact ====================

    /**
     * @description Opens the "Describe My Impact" modal and loads the existing
     * value from the Contact record so the user can edit it.
     */
    async handleOpenDescribeModal() {
        this.describeErrorMessage = '';
        this.isDescribeModalOpen = true;
        this.isDescribeLoading = true;

        try {
            const result = await getDescribeMyImpact({ currentUserContactId: this.contactId });
            this.describeMyImpactValue = result || '';
        } catch (error) {
            this.describeErrorMessage = this.extractErrorMessage(error);
        } finally {
            this.isDescribeLoading = false;
        }
    }

    /**
     * @description Closes the modal without saving.
     */
    handleCloseDescribeModal() {
        this.isDescribeModalOpen = false;
        this.describeErrorMessage = '';
    }

    /**
     * @description Keeps the tracked value in sync as the user types in the textarea.
     * lightning-textarea emits its value via event.detail.value.
     */
    handleDescribeTextChange(event) {
        this.describeMyImpactValue = event.detail.value;
    }

    /**
     * @description Saves the edited value back to the Contact record and closes the modal.
     */
    async handleSaveDescribeModal() {
        this.isDescribeSaving = true;
        this.describeErrorMessage = '';

        try {
            await saveDescribeMyImpact({
                currentUserContactId: this.contactId,
                describeMyImpact: this.describeMyImpactValue
            });
            this.isDescribeModalOpen = false;
        } catch (error) {
            this.describeErrorMessage = this.extractErrorMessage(error);
        } finally {
            this.isDescribeSaving = false;
        }
    }

    /**
     * @description Prevents clicks inside the modal dialog from bubbling up
     * and closing the modal via the overlay click handler.
     */
    handleModalContentClick(event) {
        event.stopPropagation();
    }

    /**
     * @description Normalizes Apex/AuraHandledException error shapes into a display string.
     */
    extractErrorMessage(error) {
        if (error?.body?.message) {
            return error.body.message;
        }
        if (Array.isArray(error?.body) && error.body.length > 0) {
            return error.body.map((e) => e.message).join(', ');
        }
        return 'Something went wrong. Please try again.';
    }
}