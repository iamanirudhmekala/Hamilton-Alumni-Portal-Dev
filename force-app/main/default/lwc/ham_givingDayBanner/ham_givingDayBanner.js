import { LightningElement, api, track, wire } from 'lwc';

// Importing Apex methods
import getEventsConfig from '@salesforce/apex/HAM_HomePageController.getEventsConfig';

// Import custom label
import GivingDayPlaceholder from '@salesforce/label/c.ham_GivingDayPlaceholder';

/**
 * @description Giving day banner component that displays Campaign name, expected revenue and amount raised to calculate and show the
 * raised percentage along with that allowing user to go to donation page on button click.
 */
export default class Ham_GivingDayBanner extends LightningElement {
    @api label = {};
    @api images = {};
    @track configData;
    @track record;
    @track fieldMap = {};
    @track isVisible = true;
    @track isButtonHovered = false;
    @track screenWidth = window.innerWidth;
    @track givingDay = GivingDayPlaceholder;
    
    EVENTS_KEY = 'GivingDayComponent';

     /**
     * @description Lifecycle hook that runs when the component is inserted into the DOM.
     */
    connectedCallback() {
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

    //Returns the getter as true if the site is in web view
    get isDesktopView() {
        // Define desktop breakpoint (e.g., 769px or more)
        return this.screenWidth >= 1024;
    }

    //Returns the getter as true if the site is in mobile/tab view
    get isMobileView() {
        return this.screenWidth < 1024;
    }

    /**
    * @description Wire method to fetch events configuration data and map display fields
    */
    @wire(getEventsConfig, { componentKey: '$EVENTS_KEY' })
    wiredgetEventsConfig({ error, data }) {
        if (data) {
            this.configData = data;
            
            if (data.records && data.records.length > 0) {
                this.record = data.records[0];
            }
            else{
                this.isVisible = false;
            }
            
            // Map field purposes to their API names for easy lookup
            if (data.displayFields) {
                // Build field map: Purpose -> API Name
                data.displayFields.forEach(field => {
                    this.fieldMap[field.fieldPurpose] = field.fieldApiName;

                    // Use field label for Link purpose instead of API name because in metadata the link is in field label
                    if(field.fieldPurpose == 'Link'){
                        this.fieldMap[field.fieldPurpose] = field.fieldLabel;
                    }
                });
            }
        } else if (error) {
            console.error('Error fetching data:', error);
            this.configData = null;
        }
    }

    // Get values directly from record using fieldMap
    get titleValue() {
        const apiName = this.fieldMap['Title'];
        const value = this.record ? this.record[apiName] : '';
        return value || '';
    }

    // Get make a gift button link values directly from record using fieldMap
    get linkValue() {
        const apiName = this.fieldMap['Link'];
        const value = apiName;
        return value || '#';
    }

    // Get raised amount value directly from record using fieldMap
    get raisedValue() {
        const apiName = this.fieldMap['Raised'];
        const value = this.record ? this.record[apiName] : 0;
        return Number(value) || 0;
    }

    // Get goal amount values directly from record using fieldMap
    get goalValue() {
        const apiName = this.fieldMap['Goal'];
        const value = this.record ? this.record[apiName] : 0;
        return Number(value) || 0;
    }

    // Get goal flag 
    get goalExist(){
        const apiName = this.fieldMap['Goal'];
        const value = this.record ? this.record[apiName] : 0;
        return Number(value) > 0;
    }

    // Calculate the raised percentage values from raised and goal amount
    get progressPercentage() {
        const raised = this.raisedValue;
        const goal = this.goalValue;
        const percentage = goal > 0 ? Math.round((raised / goal) * 100) : 0;
        return percentage;
    }

    // Return dynamic style based on the raised percentage
    get progressBarStyle() {
        const pct = this.progressPercentage;
        if (pct >= 100) {
            return 'width: 100%; background-color: #2ecc71;';
        }
        return `width: ${pct}%;`;
    }

    // return make a gift button icon on hovering because hover shows a differnt icon.
    get buttonIcon() {
        return this.isButtonHovered ? this.images.makeaGiftImage : this.images.mobileGridOutlineOnly;
    }

    // Format currency for display
    get formattedRaised() {
        return this.formatCurrency(this.raisedValue);
    }

    get formattedGoal() {
        return this.formatCurrency(this.goalValue);
    }

    formatCurrency(amount) {
        const numAmount = Number(amount) || 0;
        return new Intl.NumberFormat('en-US', {
            style: 'decimal',
            minimumFractionDigits: 0,
            maximumFractionDigits: 0
        }).format(numAmount);
    }

    // Handles removal of giving day component when closed
    handleClose() {
        this.isVisible = false;
    }

    // Return mouse hover property when make a gift button is hovered
    handleButtonMouseEnter() {
        this.isButtonHovered = true;
    }

    // Return mouse hover property when make a gift button is not hovered
    handleButtonMouseLeave() {
        this.isButtonHovered = false;
    }

    /**
    * @description Closes settings and dispatches event to navigate to giving page
    */
    handleMakeGiftClick() {
        this.dispatchEvent(new CustomEvent('makegift'));
    }
}