import { LightningElement, api, track } from 'lwc';
// import static resource
import siteDefaultImageResource from '@salesforce/resourceUrl/HAM_SiteFallbackImage';
import siteDefaultImageResourceKirkland from '@salesforce/resourceUrl/HAM_SiteFallbackImage_Kirkland';


const DEFAULT_IMAGE_URL = siteDefaultImageResource;
const DEFAULT_IMAGE_URL_Kirkland = siteDefaultImageResourceKirkland;


const stripHtml = (html) => {
    if (!html) return '';
    return html
        .replace(/<[^>]*>/g, ' ')
        .replace(/&nbsp;/gi, ' ')
        .replace(/&amp;/gi,  '&')
        .replace(/&lt;/gi,   '<')
        .replace(/&gt;/gi,   '>')
        .replace(/&quot;/gi, '"')
        .replace(/&#39;/gi,  "'")
        .replace(/\s+/g,     ' ')
        .trim();
};

export default class Ham_DynamicFeed extends LightningElement {
    @api componentKey; // e.g., 'NewsFeedLWC', 'EventsListLWC'
    @api componentTitle = 'Dynamic Content';
    @api label={};
    @api images={};
    _isOverride = false;

    @track allArticles = [];
    @track filteredArticles = [];
    @track isLoading = true;
    @track activeFilter = 'In Person';
    @track isNews;
    @track screenWidth = window.innerWidth;


    fieldMap = {};
    componentType;
    placeholders = [1, 2, 3];

    // Stores the ordered list of metadata fields
    rawDisplayFields = [];

      /**
     * @description Lifecycle hook that runs when the component is inserted into the DOM.
     * It sets up event listeners for window resize .
     */
    connectedCallback() {
            
        //  event listener for window resize
        window.addEventListener('resize', this.handleResize.bind(this));
        
    }

    /**
     * @description Lifecycle hook that runs when the component is removed from the DOM.
     * It removes event listeners to prevent memory leaks.
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

    @api
    set isOverride(value) {
        //this._isOverride = value;
        const changed = this._isOverride !== value;
        this._isOverride = value;
        if (changed) {
            this.refreshFallbackImages();
        }
    }

    get isOverride() {
        return this._isOverride;
    }

    // Re-resolve fallback images for articles that have no image of their own,
    // so toggling override after the records load updates the placeholder.
    refreshFallbackImages() {
        if (!this.allArticles || !this.allArticles.length) return;
        this.allArticles = this.allArticles.map(a =>
            a.hasImage ? a : { ...a, imageUrl: this.defaultImageUrl }
        );
        this.applyFilter();   // rebuild filteredArticles so the template sees new objects
    }

    /**
     * @api Setter: Receives data from the parent wrapper via the @wire service.
     */
    @api
    set componentData(configData) {
        this.isLoading = true;

        if (configData && configData.isActive && configData.records) {
            // Store the ordered metadata list
            this.rawDisplayFields = configData.displayFields;

            this.fieldMap = configData.purposeToApiMap;
            this.componentType = configData.componentType;
            this.processRecords(configData.records);

            // Apply initial filtering
            this.applyFilter();

            this.isLoading = false;
        } else {
            this.allArticles = [];
            this.filteredArticles = [];
            this.isLoading = false;
        }
    }

    // REQUIRED GETTER: Must exist if an @api setter is defined
    get componentData() {
        return { records: this.allArticles };
    }

    get isEventsComponent() {
        return this.componentKey.includes('Events');
    }

    get isNewsComponent() {
        return this.componentKey.includes('News');
    }

    get mobileArrow() {
        return this._isOverride ? this.images.mobileArrowGreen : this.images.mobileArrow;
    }

    // Returns the Kirkland fallback image when in override mode, otherwise the standard one.
    get defaultImageUrl() {
        return this._isOverride ? DEFAULT_IMAGE_URL_Kirkland : DEFAULT_IMAGE_URL;
    }

    // Consolidated button label getter
    get buttonLabel() {
       // return this.isEventsComponent ? 'Register Now' : 'See More';     // need to change once register now field is confirm
        return this.componentKey.includes('News') ? 'Read More' : 'Read More';
    }

    get registerButtonLabel(){
        return 'Learn More/Register';
    }
    
    // toggle custom button with active css class 
    get virtualClass() {
        return this.activeFilter === 'Virtual'? 'custom-btn active' : 'custom-btn';
    }
   
    // toggle custom button with active css class 
    get inPersonClass() {
        return this.activeFilter === 'In Person' ? 'custom-btn active' : 'custom-btn';
    }
    
    get kirklandOverrideClass() {
        return this.isOverride ? 'kirkland-override' : '';
    }
    
    // Get virtual active images
    get virtualimg(){
         return this.activeFilter === 'Virtual'? this.images.virtualActiveImage : this.images.virtualImage;
    }

    // Get inperson active images
    get inpersonimg(){
         return this.activeFilter === 'In Person'? this.images.inpersonActiveImage : this.images.inpersonImage;
    }

    get kirklandinpersonimg(){
        return this.activeFilter === 'In Person'? this.images.inpersonActiveImage : this.images.inPersonGreen;
    }

    get kirklandvirtualimg(){
        return this.activeFilter === 'Virtual'? this.images.virtualActiveImage : this.images.virtualGreen;
     }
 
    get isDesktopView() {
        // Define desktop breakpoint (e.g., 769px or more)
        return this.screenWidth >= 1024;
    }

    get isMobileView() {
        return this.screenWidth < 1024;
    }

    get mobileImageUrl() {
        return this.filteredArticleFirstItem && this.filteredArticleFirstItem.imageUrl 
            ? this.filteredArticleFirstItem.imageUrl 
            : this.defaultImageUrl;
    }

    get mobileImageClass() {
        const hasActualImage = this.filteredArticleFirstItem && this.filteredArticleFirstItem.imageUrl;
        return hasActualImage ? 'img-border' : 'img-border fallback-img-16-9';
    }


    /**
     * Processes the raw SObject records into a structured list.
     */
    // processRecords(records) {
    //     if (!records || records.length === 0) {
    //         this.allArticles = [];
    //         return;
    //     }

    //     const linkApi = this.fieldMap.Link;
    //     const locationTypeApi = this.fieldMap.LocationType;

    //     this.allArticles = records.map(record => {
    //         const actualLink = record[linkApi];

    //         // Handle virtual flag: If field purpose exists, use it; otherwise false
    //         const isVirtual = locationTypeApi ? record[locationTypeApi] : false;
    //         const locationType = isVirtual ? 'Virtual' : 'In Person';

    //         let article = {
    //             id: record.Id,
    //             linkUrl: actualLink,
    //             showLink: !!actualLink,
    //             locationType: locationType,
    //             isVirtual: isVirtual,
    //             displayItems: [] // Array for dynamic rendering
    //         };

    //         // Iterate over the ORDERED metadata list (rawDisplayFields)
    //         for (const fieldMDT of this.rawDisplayFields) {

    //             const fieldPurpose = fieldMDT.fieldPurpose;
    //             const fieldApiName = fieldMDT.fieldApiName;
    //             const fieldValue = record[fieldApiName];

    //             // Exclude fields used for control/filtering/wrapper structure ONLY (LocationType)
    //             // Image and Link are now included in the displayItems list
    //             if (fieldPurpose !== 'LocationType') {
    //                 article.displayItems.push({
    //                     key: fieldApiName,
    //                     order: fieldMDT.displayOrder,
    //                     purpose: fieldPurpose,
    //                     value: fieldPurpose === 'Description' ? this.screenWidth <1024 ? this.smartTrim(fieldValue, 140) : this.smartTrim(fieldValue, 190)   : fieldValue,
    //                     // Flags for HTML iteration (Exact Match)
    //                     isTitle: fieldPurpose === 'Title',
    //                     isDescription: fieldPurpose === 'Description',
    //                     isImage: fieldPurpose === 'Image',
    //                     isLink: fieldPurpose === 'Link',
    //                     isStartDate: fieldPurpose === 'Start Date',
    //                     isEndDate: fieldPurpose === 'End Date',
    //                     isLocation: fieldPurpose === 'Location'
    //                 });
    //             }

    //             // Attach flat properties for easy access if needed (e.g. for fallback image logic)
    //             if (fieldPurpose === 'Image') {
    //                 article.imageUrl = fieldValue || DEFAULT_IMAGE_URL;
    //             }
    //         }

    //         // Ensure image URL is set even if not in metadata or empty
    //         if (!article.imageUrl) {
    //             article.imageUrl = DEFAULT_IMAGE_URL;
    //         }

    //         return article;
    //     });

        
    // }

    processRecords(records) {
        if (!records || records.length === 0) {
            this.allArticles = [];
            return;
        }

        const linkApi = this.fieldMap.Link;
        const locationTypeApi = this.fieldMap.LocationType;

        this.allArticles = records.map(record => {
            const actualLink = record[linkApi];
            const isVirtual = locationTypeApi ? record[locationTypeApi] : false;
            const locationType = isVirtual ? 'Virtual' : 'In Person';

            let article = {
                id: record.Id,
                linkUrl: actualLink,
                showLink: !!actualLink,
                locationType: locationType,
                isVirtual: isVirtual,
                imageUrl: '',      // raw image; fallback resolved after the loop
                hasImage: false,   // did the record supply its own image?
                displayItems: []
            };

            // Temporary variables to hold event parts
            let startDate = '';
            let endDate = '';
            let location = '';

            for (const fieldMDT of this.rawDisplayFields) {
                const fieldPurpose = fieldMDT.fieldPurpose;
                const fieldApiName = fieldMDT.fieldApiName;
                const fieldValue = record[fieldApiName] || '';

                // 1. Capture Image separately
                if (fieldPurpose === 'Image') {
                    article.hasImage = !!fieldValue;
                    article.imageUrl = fieldValue || '';
                }

                // 2. Capture Event Details (don't push to displayItems yet)
                if (fieldPurpose === 'Start Date') startDate = fieldValue;
                if (fieldPurpose === 'End Date') endDate = fieldValue;
                if (fieldPurpose === 'Location') location = fieldValue;

                // 3. Push Title, Description, and Link immediately
                if (['Title', 'Description', 'Link', 'Image'].includes(fieldPurpose)) {
                    article.displayItems.push({
                        key: fieldApiName,
                        order: fieldMDT.displayOrder,
                        purpose: fieldPurpose,
                        fullDescription : fieldValue,
                        value: fieldPurpose === 'Description'
                            ? (this.screenWidth < 1024 ? this.smartTrim(stripHtml(fieldValue), 140) : this.smartTrim(stripHtml(fieldValue), 190))
                            : fieldPurpose === 'Title' ? stripHtml(fieldValue) : fieldValue,
                        isTitle: fieldPurpose === 'Title',
                        isDescription: fieldPurpose === 'Description',
                        isImage: fieldPurpose === 'Image',
                        isLink: fieldPurpose === 'Link'
                    });
                }
            }

            // Resolve fallback against the CURRENT override state
            if (!article.hasImage) {
                article.imageUrl = this.defaultImageUrl;
            }

            if (this.isEventsComponent) {
                // CR: Format raw Salesforce date strings to 'Mar 15, 2025' display format
                const formattedStart = this.formatDate(startDate);
                const formattedEnd = this.formatDate(endDate);

                // Build date line (first line)
                let dateLine = '';
                if (formattedStart) dateLine += formattedStart;
                if (formattedEnd) dateLine += (formattedStart ? ` - ${formattedEnd}` : formattedEnd);
                
                // Location line (second line) - can be empty string
                let locationLine = location || '';

                article.displayItems.push({
                    key: 'combined-event-details',
                    order: 3,
                    purpose: 'EventDetails',
                    dateLine: dateLine,        // Separate date line
                    locationLine: locationLine, // Separate location line
                    isEventDetails: true
                });
            }

            if(this.isNewsComponent){
                // Fallback for News/Standard components: Add a plain posted date line
            const formattedPostedDate = this.formatDate(startDate);
            
            article.displayItems.push({
                key: 'news-posted-date',
                order: 3.5, // Placed dynamically after description but before the link/button
                purpose: 'PostedDate',
                value: `Posted on ${formattedPostedDate}`,
                isPostedDate: true
            });

            }
            



            // Sort items based on the metadata displayOrder
            article.displayItems.sort((a, b) => a.order - b.order);

            return article;
        });
    }

    /**
     * Applies the active filter to the articles array.
     */
    applyFilter() {
        if (!this.isEventsComponent) {
            this.filteredArticles = this.allArticles;
            return;
        }

        this.filteredArticles = this.allArticles.filter(article => {
            if (this.activeFilter === 'In Person') {
                return !article.isVirtual;
            } else if (this.activeFilter === 'Virtual') {
                return article.isVirtual;
            }
            return true;
        });
    }

    handleFilterChange(event) {
        this.activeFilter = event.target.dataset.filter;
        this.applyFilter();
    }

    handleImageError(event) {
        event.target.onerror = null;
        event.target.src = this.defaultImageUrl;
    }

    /**
     * Handles click on the Register/See More button.
     */
    handleSeeMoreClick(event) {
        event.stopPropagation(); // Stop propagation to main card link
        event.preventDefault();
        const url = event.target.dataset.url;
        if (url) {
            window.open(url, '_blank');
        }
    }
 
    // get filteredArticles first Item for Event mobile view
    get filteredArticleFirstItem() {
    return this.filteredArticles && this.filteredArticles.length > 0 ? this.filteredArticles[0] : null;
    }

    // get allArticles first Item for New mobile view
    get allArticlesFirstItem() {
    return this.allArticles && this.allArticles.length > 0 ? this.allArticles[0] : null;
    }

    /**
     * @description Custom event passed to grandparent component (Main) that will redirect to My Impact page.
     * It triggers when redirect icon is clicked
     */
    handleMyImpactNavigation(event){
   
        const activeTab = this.isNewsComponent ? this.label.news : this.label.events;

        this.dispatchEvent(new CustomEvent('navigateevent', {
            detail: activeTab,
            bubbles: true,
            composed: true
        }));
    }

    /**
     * CR: Formats a Salesforce date string (YYYY-MM-DD or ISO DateTime) to 'Mar 15, 2025' format.
     * Appends T00:00:00 for plain date strings to prevent UTC offset from shifting the displayed day.
     */
    formatDate(dateStr) {
        if (!dateStr) return '';
        const date = new Date(dateStr.includes('T') ? dateStr : dateStr + 'T00:00:00');
        return date.toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' });
    }

     smartTrim(text, maxLength = 45) {
        if (!text || text.length <= maxLength) {
            return text;
        }

        let truncated = text.slice(0, maxLength);
        const lastSpace = truncated.lastIndexOf(' ');

        if (lastSpace > -1) {
            truncated = truncated.slice(0, lastSpace);
        }

        return truncated.trim() + '...';
    }

    handleCardClick(event)
    {
        var linkUrl = event.currentTarget.dataset.link;
         // Navigate to the link
        if (linkUrl && linkUrl !== '#') {
            window.open(linkUrl, '_blank');
        }
    }
   
   
}