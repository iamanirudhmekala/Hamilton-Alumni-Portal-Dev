import { LightningElement, track, api, wire } from 'lwc';
import { publish, MessageContext } from 'lightning/messageService';
import MY_IMPACT_CHANNEL from '@salesforce/messageChannel/myImpactChannel__c';

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
    @track screenWidth = window.innerWidth;
    _isOverride = false;

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

    // Getter to return the my impact widget style for desktop home view.
   /* get computeFieldLabelStyle(){
        return this.screenWidth >= 1024 && this.pageflag ? `margin-bottom:0rem;` : this.screenWidth < 1024 && !this.pageflag ? `margin-bottom:1rem;` : '';
    }*/

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
}