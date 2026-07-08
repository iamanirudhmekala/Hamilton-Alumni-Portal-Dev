// Salesforce LWC imports
import { LightningElement, api, track, wire } from 'lwc';

// Apex controller methods
import getOpportunities from '@salesforce/apex/HAM_VolunteerOpportunityController.getOpportunities';
import setInterested from '@salesforce/apex/HAM_VolunteerOpportunityController.setInterested';
import withdrawInterest from '@salesforce/apex/HAM_VolunteerOpportunityController.withdrawInterest';
import getMyVolunteerActivities from '@salesforce/apex/HAM_VolunteerOpportunityController.getMyVolunteerActivities';
import getPastVolunteerActivities from '@salesforce/apex/HAM_VolunteerOpportunityController.getPastVolunteerActivities';
import getOpportunitiesCount from '@salesforce/apex/HAM_VolunteerOpportunityController.getOpportunitiesCount';
import getPastActivityCount from '@salesforce/apex/HAM_VolunteerOpportunityController.getPastActivityCount';
import getCommitteeActivities from '@salesforce/apex/HAM_VolunteerOpportunityController.getCommitteeActivities';
import getCommitteesCount from '@salesforce/apex/HAM_VolunteerOpportunityController.getCommitteesCount';


// Lightning Message Service for cross-component communication
import { publish, subscribe, unsubscribe, MessageContext } from 'lightning/messageService';
import VOLUNTEER_SYNC_CHANNEL from '@salesforce/messageChannel/VolunteerOpportunitySync__c';

// Static resources
import siteDefaultImageResource from '@salesforce/resourceUrl/HAM_SiteFallbackImage';
import siteDefaultImageResourceKirkland from '@salesforce/resourceUrl/HAM_SiteFallbackImage_Kirkland';

const DEFAULT_IMAGE_URL = siteDefaultImageResource;
const DEFAULT_IMAGE_URL_Kirkland = siteDefaultImageResourceKirkland;


// Importing static resources
import HAM_ICONS from '@salesforce/resourceUrl/HAM_Icons';

// Custom labels
import VolunteerCurrent from '@salesforce/label/c.ham_VolunteerOpp_Current';
import VolunteerUpcoming from '@salesforce/label/c.ham_VolunteerOpp_Upcoming';
import VolunteerInfoText from '@salesforce/label/c.HAM_volOppInfoText';
import VolunteerCommittees from '@salesforce/label/c.ham_VolunteerOpp_Committees';
import VolunteerPast from '@salesforce/label/c.ham_pastActivities';
import VolunteerInfoTextEmail from '@salesforce/label/c.HAM_volOppInfoText_Email';


export default class Ham_VolunteerOppCmp extends LightningElement {

    // Public properties from parent
    //_userContactId;
    @api label = {};
    @api images = {};
    @api mainResource = {};
    @api isMobile;
    @api isDesktop;
    @api isVolunteerTab;
    @api recievedVolOpp;
    @api isOverride = false;


    // LMS context and subscription
    @wire(MessageContext)
    messageContext;
    subscription = null;
    
    // Tracks which record is currently processing
    processingInterestId = null;

    // Opportunities data
    @track opportunities;
    wiredResult;

    // Pagination state
    @track paginatedPastActivities = [];
    @track currentPage = 1;
    @track pageSize = 8;
    @track totalRecords = 0;
    @track startCount = 0;
    @track endCount = 0;
    @track isLoading = false;
    @track screenWidth = window.innerWidth;

     // Pagination properties
    @track currentPageVolActivity = 1;
    @track totalRecordsForChild = 0;
    @track volActrecordsToSkip = 0;

    //Volunteer Opp Pagination State
    @track volCurrentPage = 1;
    @track volTotalRecords = 0;
    @track volRecordsToSkip = 0;
    // @track imagesLocal = {};
    
    // Pagination button CSS classes
    @track firstPageClass = 'page-btn disabled';
    @track lastPageClass = 'page-btn';

    // My Activities data
    @track myCurrentActivities = [];
    @track myUpcomingActivities = [];
    wiredMyActivitiesResult;

    // Filter state
    @track filterFromDate = null;
    @track filterToDate = null;
    @track isFilterOpen = false;
    @track filterLabel = 'All Time';

    // Modal state
    @track showInterestedModal = false;
    @track showWithdrawModal = false;
    @track selectedOpportunityName = '';
    @track selectedValueId = null;
    @track selectedInterestId = null;

    // Accordion toggle states (mobile)
    @track showCurrentNews = true;
    @track showUpcomingActivity = false;
    @track showPastActivity = false;
    @track showCommitteesActivity = false;

    @track myCommitteeActivities = [];
    @track commCurrentPage = 1;
    @track commTotalRecords = 0;
    @track commRecordsToSkip = 0;

    _activeMainTab;
    _activeSubTab;

    @api
    get activeMainTab() {
        return this._activeMainTab ?? this.label?.volunteerOpportunity;
    }
    set activeMainTab(value) {
        this._activeMainTab = value;
    }

    view = 'grid';

    /**
     * Custom labels used in the component
     */
    labels = {
        volunteerOppCurr : VolunteerCurrent,
        volunteerOppUp : VolunteerUpcoming,
        volunteerInfoText : VolunteerInfoText,
        volunteerCommittees : VolunteerCommittees,
        volunteerPast : VolunteerPast,
        volunteerInfoTextEmail : VolunteerInfoTextEmail
    }
    
    get emailHref() {
      
        const email = this.labels.volunteerInfoTextEmail;

        return email ? `mailto:${email}` : '';
    }

    get activeSubTab() {
        // console.log('_activeSubTab:', this._activeSubTab);
        // console.log('labels.volunteerOppCurr:', this.labels?.volunteerOppCurr);
        return this._activeSubTab || this.labels?.volunteerOppCurr || 'Current';
    }
    set activeSubTab(value) {
        this._activeSubTab = value;
    }

     // Returns the Kirkland fallback image when in override mode, otherwise the standard one.
    get defaultImage() {
        return this.isOverride ? DEFAULT_IMAGE_URL_Kirkland : DEFAULT_IMAGE_URL;
    }


    hamIcons =HAM_ICONS;

    icons = {
        listViewIcon : this.hamIcons + '/list-view.png',
        gridViewIcon: this.hamIcons + '/grid-dark.png',
        viewCheckIcon : this.hamIcons + '/view-check.png',
    }

    /**
     * Handles main tab click events to switch between Opportunities and Activities tabs
     * @param {Event} event - Click event containing the tab name in dataset
     */
    handleMainTabClick(event){
        this._activeMainTab = event.currentTarget.dataset.name;
    }

    /**
     * Handles sub-tab click events to switch between Current, Upcoming, and Past views
     * @param {Event} event - Click event containing the sub-tab name in dataset
     */
    handleSubTabClick(event){
        this._activeSubTab = event.currentTarget.dataset.name;
        if(this._activeSubTab === this.labels.volunteerCommittees) {
            this.loadCommitteeActivities();
        }
    }

    /**
     * Computed property to check if Opportunities tab is currently active
     * @returns {Boolean} True if Opportunities tab is active
     */
    get opportunitiesActive(){
        return this._activeMainTab === this.label.volunteerOpportunity;
    }

    /**
     * Computed property to check if Activities tab is currently active
     * @returns {Boolean} True if Activities tab is active
     */
    get activitiesActive(){
        return this._activeMainTab === this.label.volActTab;
    }

    /**
     * Computed property for CSS class of Opportunities tab
     * @returns {String} CSS class name for active or inactive state
     */
    get opportunitiesClass(){
        return this._activeMainTab === this.label.volunteerOpportunity ? 'main-tab-active' : 'main-tab-inactive';
    }

    /**
     * Computed property for CSS class of Activities tab
     * @returns {String} CSS class name for active or inactive state
     */
    get activitiesClass(){
        return this._activeMainTab === this.label.volActTab ? 'main-tab-active' : 'main-tab-inactive';
    }

    /**
     * Computed property to check if Current sub-tab is active
     * @returns {Boolean} True if Current sub-tab is active
     */
    get currentActive(){
        return this._activeSubTab === this.labels.volunteerOppCurr;
    }

    /**
     * Computed property to check if Upcoming sub-tab is active
     * @returns {Boolean} True if Upcoming sub-tab is active
     */
    get upcomingActive(){
        return this._activeSubTab === this.labels.volunteerOppUp;
    }

    /**
     * Computed property to check if Past sub-tab is active
     * @returns {Boolean} True if Past sub-tab is active
     */
    get pastActive(){
        return this._activeSubTab === this.labels.volunteerPast;
    }

    get committeesActive(){
        return this._activeSubTab === this.labels.volunteerCommittees;
    }

    get committeesClass(){
        return this._activeSubTab === this.labels.volunteerCommittees ? 'sub-tab-active' : 'sub-tab-inactive';
    }

    /**
     * Computed property for CSS class of Current sub-tab
     * @returns {String} CSS class name for active or inactive state
     */
    get currentClass(){
        return this._activeSubTab === this.labels.volunteerOppCurr ? 'sub-tab-active' : 'sub-tab-inactive';
    }

    /**
     * Computed property for CSS class of Upcoming sub-tab
     * @returns {String} CSS class name for active or inactive state
     */
    get upcomingClass(){
        return this._activeSubTab === this.labels.volunteerOppUp ? 'sub-tab-active' : 'sub-tab-inactive';
    }

    /**
     * Computed property for CSS class of Past sub-tab
     * @returns {String} CSS class name for active or inactive state
     */
    get pastClass(){
        return this._activeSubTab === this.labels.volunteerPast ? 'sub-tab-active' : 'sub-tab-inactive';
    }


    /**
     * Determines record limit based on viewport context
     * Returns 3 records for mobile view, 9 for desktop
     * @returns {Number} Number of records to display
     */
    get resolvedRecordLimit() {
        // if (this.isVolunteerTab === undefined) {
        //     return null;
        // }
        return this.isMobile ? 5 : 8;
    }

    /**
     * Returns the appropriate chevron icon for current activities accordion
     * @returns {String} URL of the chevron icon (open/close state)
     */
    get currentNewsIcon() {
        return this.showCurrentNews ? this.images.volClose : this.images.volOpen;
    }

    /**
     * Returns the appropriate chevron icon for upcoming activities accordion
     * @returns {String} URL of the chevron icon (open/close state)
     */
    get upcomingActivityIcon() {
        return this.showUpcomingActivity ? this.images.volClose : this.images.volOpen;
    }

    /**
     * Returns the appropriate chevron icon for past activities accordion
     * @returns {String} URL of the chevron icon (open/close state)
     */
    get pastActivityIcon() {
        return this.showPastActivity ?  this.images.volClose : this.images.volOpen;
    }

    get committeesActivityIcon() {
        return this.showCommitteesActivity ? this.images.volClose : this.images.volOpen;
    }

    get isListView() {
        return this.view === 'list';
    }

    get isGridView() {
        return this.view === 'grid';
    }

    get listViewClass() {
        return this.isListView ? 'active' : '';
    }

    get gridViewClass() {
        return this.isGridView ? 'active' : '';
    }

    handleViewToggle(event) {
        const viewType = event.currentTarget.dataset.view;
        this.view = viewType;

        // Re-process the existing opportunities to update trimmedDescription lengths
        if (this.opportunities) {
            this.prepareOpportunities(this.opportunities);
        }
    }

    /**
     * Toggles the visibility of current activities section in mobile accordion view
     */
    handleCurrentNewsToggle() {
        this.showCurrentNews = !this.showCurrentNews;
    }

    /**
     * Toggles the visibility of upcoming activities section in mobile accordion view
     */
    handleupcomingActivityToggle() {
        this.showUpcomingActivity = !this.showUpcomingActivity;
    }

    /**
     * Toggles the visibility of past activities section in mobile accordion view
     */
    handlePastActivityToggle() {
        this.showPastActivity = !this.showPastActivity;
    }

    handleCommitteesToggle() {
        this.showCommitteesActivity = !this.showCommitteesActivity;
    }

    /**
     * Component lifecycle hook - called when component is inserted into DOM
     * Initializes data loading and subscribes to Lightning Message Service channel
     */
    connectedCallback() {
        window.addEventListener('resize', this.handleResize.bind(this));   
        if (!this._activeSubTab) {
            this._activeSubTab = this.labels.volunteerOppCurr; 
        }
        // REMOVE OR COMMENT OUT THESE 3 LINES:
        // this.loadOpportunities();
        // this.loadOpportunitiesCount();
        // this.loadMyActivities();
        this.subscribeToMessageChannel();
    }

    // Replace: @api userContactId;
    // With:
    _userContactId;
    
    @api 
    get userContactId() {
        return this._userContactId;
    }
    
    set userContactId(value) {
        this._userContactId = value;
        // As soon as the parent passes the contact ID, fetch the data!
        if (value) {
            this.loadOpportunities();
            this.loadOpportunitiesCount();
            this.loadMyActivities();
            this.loadCommitteesCount();
            this.loadCommitteeActivities();
        }
    }

    /**
     * Handles window resize events to update screen width for responsive layout
     * Updates trimmed description lengths based on new screen dimensions
     */
    handleResize() {
        this.screenWidth = window.innerWidth;
    }

    /**
     * Component lifecycle hook - called when component is removed from DOM
     * Performs cleanup by unsubscribing from Lightning Message Service
     */
    disconnectedCallback() {
        this.unsubscribeFromMessageChannel();
    }

    /**
     * Subscribes to the volunteer sync Lightning Message Service channel
     * Enables real-time synchronization of volunteer interest updates across component instances
     */
    subscribeToMessageChannel() {
        this.subscription = subscribe(
            this.messageContext,
            VOLUNTEER_SYNC_CHANNEL,
            (message) => this.handleVolunteerSync(message)
        );
    }

    /**
     * Unsubscribes from the Lightning Message Service channel
     * Cleans up subscription to prevent memory leaks
     */
    unsubscribeFromMessageChannel() {
        if (this.subscription) {
            unsubscribe(this.subscription);
            this.subscription = null;
        }
    }

    /**
     * Handles incoming sync messages from Lightning Message Service
     * Updates local opportunity state when other component instances modify volunteer interests
     * @param {Object} message - LMS message containing opportunityId, isInterested, and activeInterestId
     */
    handleVolunteerSync(message) {
        const { opportunityId, isInterested, activeInterestId } = message;
        this.opportunities = this.opportunities.map(item => {
            if (item.opp.Id === opportunityId) {
                return {
                    ...item,
                    isInterested,
                    activeInterestId
                };
            }
            return item;
        });
    }

    /**
     * Fetches volunteer opportunities from the server
     * Applies record limit based on viewport and pagination offset
     * Updates component state with formatted opportunity data
     */
    loadOpportunities() {
        getOpportunities({ recordLimit: this.resolvedRecordLimit, recordToSkip: this.volRecordsToSkip, currentUserContactId: this._userContactId })
            .then(result => {
                this.prepareOpportunities(result);
                this.isLoading = false;
            })
            .catch(error => {
                console.error('Error fetching opportunities:', JSON.stringify(error));
                this.isLoading = true;
            });
    }

    /**
     * Fetches the total count of volunteer opportunities from the server
     * Used for pagination calculations in the opportunities view
     */
    loadOpportunitiesCount() {
        getOpportunitiesCount()
            .then(result => {
                this.volTotalRecords = result;
            })
            .catch(error => {
                console.error('Error fetching opportunities:', JSON.stringify(error));
            });
    }



    /**
     * Fetches the current user's volunteer activities (current and upcoming)
     * Calls processCurrentUpcoming to categorize activities and then loads past activities
     */
    loadMyActivities() {
        getMyVolunteerActivities({ 
            currentUserContactId: this._userContactId, 
            fromDate: null, 
            toDate: null 
        })
        .then(result => {
            this.processCurrentUpcoming(result);
            this.fetchPastActivities();
        })
        .catch(error => {
            console.error('Error fetching my activities:', error);
        });
    }

    /**
     * Separates volunteer activities into current and upcoming categories
     * Formats each activity with date ranges and images before storing in respective arrays
     * @param {Array} data - Array of activity records from server
     */
    processCurrentUpcoming(data) {
        let current = [];
        let upcoming = [];
        
        data.forEach(act => {
            if (act.computedTab === this.labels.volunteerOppCurr) {
                current.push(this.formatActivity(act));
            } else if (act.computedTab === this.labels.volunteerOppUp) {
                upcoming.push(this.formatActivity(act));
            }
        });
        this.myCurrentActivities = current;
        this.myUpcomingActivities = upcoming;
    }

    /**
     * Formats a volunteer activity record with human-readable date ranges and fallback images
     * Handles different date range formats for current vs upcoming activities
     * @param {Object} act - Activity record to format
     * @returns {Object} Formatted activity with dateRange and imageUrl properties
     */
    formatActivity(act) {
         const start = act.startDate ? new Date(act.startDate) : null;
         const end = act.endDate ? new Date(act.endDate) : null;
         const options = { year: 'numeric', month: 'short', day: 'numeric' };
         const startStr = start ? start.toLocaleDateString('en-US', options) : '';
         const endStr = end ? end.toLocaleDateString('en-US', options) : '';
         let maxTitleLength;
         let maxDescriptionLength;

        if (this.screenWidth < 1024) {
            maxTitleLength = 25;
            maxDescriptionLength = 70;
        } else {
            // Desktop: Different lengths for different views
            // List view usually has more horizontal space, allowing more text
            maxTitleLength = (this.view === 'grid') ? 50 : 20; 
            maxDescriptionLength = (this.view === 'grid') ? 170 : 250; 
        }
        
        // Trim description using smartTrim helper method
        const trimmedDescription = act.description 
            ? this.smartTrim(act.description, maxDescriptionLength) 
            : '';
        // Trim description using smartTrim helper method
        const trimmedTitle = act.name 
            ? this.smartTrim(act.name, maxTitleLength) 
            : '';
        
         let dateRange = startStr;
         if (act.computedTab === this.labels.volunteerOppUp) {
             dateRange = startStr;
             if (endStr) dateRange += ` - ${endStr}`;
         } else {
             if (endStr) dateRange += ` - ${endStr}`;
             else if (startStr && act.status === 'Current') dateRange += ` - Present`;
         }

         return {
             ...act,
             dateRange: dateRange,
             trimmedDescription: trimmedDescription,
             trimmedTitle : trimmedTitle,
             imageUrl: act.imageUrl ? act.imageUrl : this.defaultImage
         };
    }

    /**
     * Fetches past volunteer activities with pagination and date filtering
     * First retrieves total count, then fetches paginated records
     * Updates pagination controls and record count displays
     */
    fetchPastActivities() {
        if(!this._userContactId) return;

        //this.isLoading = true;
        //this.firstPageClass = this.currentPage === 1 ? 'page-btn disabled' : 'page-btn';
        
        //const recordsToSkip = (this.currentPage - 1) * this.pageSizeForChild;

        // Fetch total count first
        getPastActivityCount({ 
            currentUserContactId: this._userContactId, 
            fromDate: this.filterFromDate, 
            toDate: this.filterToDate 
        })
        .then(count => {
            //this.totalRecords = count;
            this.totalRecordsForChild = count;
            //this.lastPageClass = this.currentPage === this.totalPages ? 'page-btn disabled' : 'page-btn';

            // Fetch paginated data if records exist
            if (this.totalRecordsForChild > 0) {
                return getPastVolunteerActivities({
                    pageSize: this.resolvedRecordLimit,
                    recordsToSkip: this.volActrecordsToSkip,
                    currentUserContactId: this._userContactId,
                    fromDate: this.filterFromDate,
                    toDate: this.filterToDate
                });
            } else {
                return [];
            }
        })
        .then(data => {
            if (Array.isArray(data)) {
                this.paginatedPastActivities = data.map(act => this.formatActivity(act));
                
                //this.startCount = this.totalRecords === 0 ? 0 : recordsToSkip + 1;
                //this.endCount = Math.min(recordsToSkip + this.pageSize, this.totalRecords);
            } else {
                this.paginatedPastActivities = [];
                //this.startCount = 0;
                //this.endCount = 0;
            }
            this.isLoading = false;
        })
        .catch(error => {
            console.error('Error fetching past activities', JSON.stringify(error));
            this.isLoading = false;
            this.paginatedPastActivities = [];
        });
    }

    /**
     * Handles pagination page number button clicks for past activities
     * Updates current page and refreshes data if page has changed
     * @param {Event} event - Click event containing page number in dataset
     */
    handlePageChange(event) {
        const selectedPage = Number(event.target.dataset.page);
        if (selectedPage !== this.currentPage) {
            this.currentPage = selectedPage;
            this.fetchPastActivities();
        }
    }

    /**
     * Navigates to the previous page in past activities pagination
     * Only executes if not already on the first page
     */
    goToPreviousPage() {
        if (this.currentPage > 1) {
            this.currentPage--;
            this.fetchPastActivities();
        }
    }

    /**
     * Navigates to the next page in past activities pagination
     * Only executes if not already on the last page
     */
    goToNextPage() {
        if (this.currentPage < this.totalPages) {
            this.currentPage++;
            this.fetchPastActivities();
        }
    }

    /**
     * Handles date filter changes for past activities
     * Updates filter values, resets pagination to first page, and refreshes data
     * @param {Event} event - Change event from date input containing field name and value
     */
    handleDateChange(event) {
        const field = event.target.name;
        if (field === 'fromDate') this.filterFromDate = event.target.value || null;
        else if (field === 'toDate') this.filterToDate = event.target.value || null;
        
        this.filterLabel = (this.filterFromDate || this.filterToDate) ? 'Custom Range' : 'All Time';
        
        this.currentPage = 1;
        this.fetchPastActivities();
    }

    get allTimeClass() {
        return this.filterLabel === 'All Time' ? 'slds-dropdown__item is-selected' : 'slds-dropdown__item';
    }

    get last30Class() {
        return this.filterLabel === 'Last 30 Days' ? 'slds-dropdown__item is-selected' : 'slds-dropdown__item';
    }

    get last6MonthsClass() {
        return this.filterLabel === 'Last 6 Months' ? 'slds-dropdown__item is-selected' : 'slds-dropdown__item';
    }

    get lastYearClass() {
        return this.filterLabel === 'Last Year' ? 'slds-dropdown__item is-selected' : 'slds-dropdown__item';
    }
    
    /**
     * Clears all date filters and displays all past activities
     * Resets to first page and updates filter label
     * @param {Event} event - Click event (optional, prevented if present)
     */
    handleAllTimeClick(event) {
        event.preventDefault();
        const range = event.currentTarget.dataset.range;
        const today = new Date();
        
        // Reset defaults
        this.filterToDate = null; 
        this.currentPage = 1;
        this.isFilterOpen = false;

        switch (range) {
            case '30':
                this.filterFromDate = this.calculateDate(today, 30);
                this.filterLabel = 'Last 30 Days';
                break;
            case '180':
                this.filterFromDate = this.calculateDate(today, 180);
                this.filterLabel = 'Last 6 Months';
                break;
            case '365':
                this.filterFromDate = this.calculateDate(today, 365);
                this.filterLabel = 'Last Year';
                break;
            case 'all':
            default:
                this.filterFromDate = null;
                this.filterLabel = 'All Time';
                break;
        }
        this.fetchPastActivities();
    }

    /**
     * Helper to subtract days and format as YYYY-MM-DD for Salesforce
     */
    calculateDate(baseDate, daysToSubtract) {
        const d = new Date(baseDate);
        d.setDate(d.getDate() - daysToSubtract);
        return d.toISOString().split('T')[0]; // Returns "YYYY-MM-DD"
    }

    /**
     * Computed property calculating total number of pages for pagination
     * @returns {Number} Total pages based on total records and page size
     */
    get totalPages() { 
        return Math.ceil(this.totalRecords / this.pageSize);
    }

    /**
     * Computed property checking if currently on first page
     * @returns {Boolean} True if on first page
     */
    get isFirstPage() { 
        return this.currentPage === 1; 
    }

    /**
     * Computed property checking if currently on last page
     * @returns {Boolean} True if on last page
     */
    get isLastPage() { 
        return this.currentPage === this.totalPages; 
    }

    /**
     * Computed property determining if pagination controls should be displayed
     * @returns {Boolean} True if there are records to paginate
     */
    get showPageNation() { 
        return this.totalRecords > 0; 
    }

    /**
     * Computed property determining if volunteer opportunities section should be visible
     * Compares received tab value against expected volunteer opportunity tab label
     * @returns {Boolean} True if volunteer opportunity view should be shown
     */
    get volunteerOpportunityVisible(){
        return this.recievedVolOpp == this.label.volunteerOpportunity;
    }
    
    /**
     * Generates array of page numbers for pagination controls with ellipsis for large page counts
     * Displays up to 4 visible page numbers with ellipsis when total pages exceed visible range
     * @returns {Array} Array of page objects with number, active state, and CSS classes
     */
    get pages() {
        let pages = [];
        if (this.totalPages > 0) {
            let visiblePages = 4;
            let startPage = Math.max(1, this.currentPage - Math.floor(visiblePages / 2));
            let endPage = Math.min(this.totalPages, startPage + visiblePages - 1);
            
            // Add first page and ellipsis if needed
            if (startPage > 1) {
                pages.push({ number: 1, isCurrent: false, class: 'page-btn' });
                if (startPage > 2) pages.push({ number: '...', isCurrent: false, isEllipsis: true, key: 'ell-1' });
            }
            
            // Add visible page range
            for (let i = startPage; i <= endPage; i++) {
                pages.push({ 
                    number: i, 
                    isCurrent: i === this.currentPage, 
                    class: (i === this.currentPage) ? 'page-btn active' : 'page-btn', 
                    key: i 
                });
            }
            
            // Add ellipsis and last page if needed
            if (endPage < this.totalPages) {
                if (endPage < this.totalPages - 1) pages.push({ number: '...', isCurrent: false, isEllipsis: true, key: 'ell-2' });
                pages.push({ number: this.totalPages, isCurrent: false, class: 'page-btn' });
            }
        }
        return pages;
    }

    /**
     * Toggles the visibility of the date filter dropdown
     * Used in the past activities filter interface
     */
    toggleFilterDropdown() {
        this.isFilterOpen = !this.isFilterOpen;
    }

    /**
     * Refreshes the volunteer opportunities list
     * Wrapper method to reload opportunities data
     * @returns {Promise} Promise returned from loadOpportunities
     */
    refreshOpportunities() {
        return this.loadOpportunities();
    }

    /**
     * Prepares and enriches opportunity data with additional display properties
     * Adds fallback images, trimmed descriptions, and processing state to each opportunity
     * @param {Array} data - Raw opportunity data from server
     */
    prepareOpportunities(data) {
            this.opportunities = data.map(item => {
                let maxTitleLength;
            let maxDescriptionLength;

            if (this.screenWidth < 1024) {
                maxTitleLength = 25;
                maxDescriptionLength = 70;
            } else {
                // Desktop: Different lengths for different views
                // List view usually has more horizontal space, allowing more text
                maxTitleLength = 50; 
                // maxTitleLength = (this.view === 'grid') ? 50 : 20; 
                maxDescriptionLength = (this.view === 'grid') ? 170 : 250; 
            }
            
            // Trim description using smartTrim helper method
            const description = item.opp.HAM_Description__c 
                ? this.smartTrim(item.opp.HAM_Description__c, maxDescriptionLength) 
                : '';
            const title = item.opp.Name 
                ? this.smartTrim(item.opp.Name, maxTitleLength) 
                : '';

            return {
                ...item,
                displayImage: item.opp.HAM_Image_URL__c ? item.opp.HAM_Image_URL__c : this.defaultImage,
                trimmedDescription: description,
                trimmedTitle : title,
                isProcessing: this.processingInterestId && (
                                    this.processingInterestId === item.opp.Id ||
                                    this.processingInterestId === item.activeInterestId
                                )
            };
        });
    }

    /**
     * Computed property for dynamic container CSS class based on viewport
     * Returns grid layout classes for desktop, vertical layout for mobile
     * @returns {String} CSS class string for container
     */
    get componentClass() {
        return this.isOverride ? 'kirkland-override' : '';
    }

    get containerClass() {
        return this.isDesktop
            ? 'slds-grid slds-wrap slds-gutters'
            : 'slds-grid slds-grid_vertical my-vertical-tab-container';
    }

    /**
     * Computed property for dynamic item CSS class based on viewport
     * Returns responsive column classes for desktop, basic column for mobile
     * @returns {String} CSS class string for opportunity items
     */
    get itemClass() {
        return this.isDesktop
            ? 'slds-col slds-size_1-of-1 slds-medium-size_1-of-3 slds-p-bottom_medium'
            : 'slds-col slds-p-bottom_medium';
    }

    /**
     * Computed property for dynamic image CSS class based on viewport
     * Returns full width for desktop, one-third width for mobile
     * @returns {String} CSS class string for opportunity images
     */
    get imageClass() {
        return this.isDesktop
            ? 'slds-col slds-size_1-of-1'
            : 'slds-col slds-size_1-of-3';
    }

    // ========== INTERESTED MODAL HANDLERS ==========

    /**
     * Opens the interest confirmation modal for a volunteer opportunity
     * Stores opportunity details for confirmation dialog
     * @param {Event} event - Click event containing opportunity ID and name in dataset
     */
    openInterestedModal(event) {
        this.selectedValueId = event.target.dataset.valueId;
        this.selectedOpportunityName = event.target.dataset.oppName;
        this.showInterestedModal = true;
    }

    /**
     * Closes the interest modal without taking action
     * Resets modal state variables
     */
    closeInterestedModal() {
        this.showInterestedModal = false;
        this.resetModalState();
    }

    /**
     * Confirms user's interest in a volunteer opportunity
     * Calls Apex to create interest record, updates local state, and publishes sync message
     * Shows processing state during server call
     */
    confirmInterested() {
        this.showInterestedModal = false;
        const valId = this.selectedValueId;
        
        this.processingInterestId = valId;
        this.prepareOpportunities(this.opportunities);
        
        
        setInterested({ interestValueId: valId, currentUserContactId: this._userContactId })
            .then((result) => {
                // Update local state
                this.opportunities = this.opportunities.map(item => {
                    if (item.opp.Id === valId) {
                        return {
                            ...item,
                            isInterested: true,
                            activeInterestId: result
                        };
                    }
                    return item;
                });
                
                // Publish sync message to other components
                publish(this.messageContext, VOLUNTEER_SYNC_CHANNEL, {
                    opportunityId: valId,
                    isInterested: true,
                    activeInterestId: result
                });
            })
            .catch(error => {
                console.error('Error setting interest:', JSON.stringify(error));
            })
            .finally(() => {
                this.processingInterestId = null;
                this.isModalProcessing = false;
                this.prepareOpportunities(this.opportunities);
                this.resetModalState();
            });
    }

    // ========== WITHDRAW MODAL HANDLERS ==========

    /**
     * Opens the withdrawal confirmation modal for a volunteer interest
     * Stores interest and opportunity details for confirmation dialog
     * @param {Event} event - Click event containing interest ID, opportunity ID, and name in dataset
     */
    openWithdrawModal(event) {
        this.selectedInterestId = event.target.dataset.interestId;
        this.selectedValueId = event.target.dataset.valueId;
        this.selectedOpportunityName = event.target.dataset.oppName;
        this.showWithdrawModal = true;
    }

    /**
     * Closes the withdrawal modal without taking action
     * Resets modal state variables
     */
    closeWithdrawModal() {
        this.showWithdrawModal = false;
        this.resetModalState();
    }

    /**
     * Confirms withdrawal of interest from a volunteer opportunity
     * Calls Apex to delete interest record, updates local state, and publishes sync message
     * Shows processing state during server call
     */
    confirmWithdraw() {
        this.showWithdrawModal = false;
        const intId = this.selectedInterestId;
        const valId = this.selectedValueId;
        
        this.processingInterestId = intId;
        this.prepareOpportunities(this.opportunities);
        
        withdrawInterest({ interestId: intId })
            .then(() => {
                // Update local state
                this.opportunities = this.opportunities.map(item => {
                    if (item.opp.Id === valId) {
                        return {
                            ...item,
                            isInterested: false,
                            activeInterestId: null
                        };
                    }
                    return item;
                });
                
                // Publish sync message to other components
                publish(this.messageContext, VOLUNTEER_SYNC_CHANNEL, {
                    opportunityId: valId,
                    isInterested: false,
                    activeInterestId: null
                });
            })
            .catch(error => {
                console.error('Error withdrawing interest:', JSON.stringify(error));
            })
            .finally(() => {
                this.processingInterestId = null;
                this.isModalProcessing = false;
                this.prepareOpportunities(this.opportunities);
                this.resetModalState();
            });
    }

    // ========== UTILITY METHODS ==========

    /**
     * Resets modal state variables to their default values
     * Called after modal actions are completed or cancelled
     */
    resetModalState() {
        this.selectedOpportunityName = '';
        this.selectedValueId = null;
        this.selectedInterestId = null;
    }

    /**
     * Intelligently trims text to a maximum length, breaking at word boundaries
     * Adds ellipsis if text is truncated to indicate continuation
     * @param {String} text - Text to trim
     * @param {Number} maxLength - Maximum character length
     * @returns {String} Trimmed text with ellipsis if truncated, or original text if under limit
     */
    smartTrim(text, maxLength) {
        if (!text || text.length <= maxLength) return text;
        
        const trimmed = text.slice(0, maxLength);
        const lastSpace = trimmed.lastIndexOf(' ');
        
        // Break at last space to avoid cutting words
        return lastSpace > 0 
            ? trimmed.slice(0, lastSpace) + '...' 
            : trimmed + '...';
    }

    /**
     * Handles pagination changes for volunteer opportunities list
     * Updates current page and records offset, then reloads opportunities
     * @param {Event} event - Custom event from pagination component containing currentPage and recordsToSkip
     */
    handlePaginationPageChange(event) {
        this.isLoading = true;
        this.volCurrentPage = event.detail.currentPage;
        this.volRecordsToSkip = event.detail.recordsToSkip;
        this.loadOpportunities();
    }

    /**
     * ============================================================================
     * ADDED FOR COMMITTEES SUB-TAB
     * ============================================================================
     */

    loadCommitteesCount() {
        getCommitteesCount({ currentUserContactId: this._userContactId })
            .then(result => {
                this.commTotalRecords = result;
            })
            .catch(error => {
                console.error('Error fetching committees count:', error);
            });
    }

    loadCommitteeActivities() {
        this.isLoading = true;
        getCommitteeActivities({ 
            recordLimit: this.resolvedRecordLimit, 
            recordToSkip: this.commRecordsToSkip, 
            currentUserContactId: this._userContactId 
        })
        .then(result => {
            // Process the result using the existing formatActivity
            this.myCommitteeActivities = result.map(act => {
                let formattedAct = this.formatActivity(act);
                
                // 1. Force image to default fallback
                formattedAct.imageUrl = this.defaultImage;
                
                // 2. Exact space preserver for empty descriptions to keep card heights equal
                if (!formattedAct.trimmedDescription || formattedAct.trimmedDescription.trim() === '') {
                    formattedAct.trimmedDescription = '\u00A0'; // Non-breaking space
                }
                
                return formattedAct;
            });
            this.isLoading = false;
        })
        .catch(error => {
            console.error('Error fetching committee activities:', error);
            this.isLoading = false;
        });
    }

    handleCommPaginationPageChange(event) {
        this.commCurrentPage = event.detail.currentPage;
        this.commRecordsToSkip = event.detail.recordsToSkip;
        this.loadCommitteeActivities();
    }

    handlePageChange(event) {
        this.currentPageVolActivity = event.detail.currentPage;
        this.volActrecordsToSkip = event.detail.recordsToSkip;
        this.fetchPastActivities();
    }
}