import { LightningElement, wire, track, api } from 'lwc';
import { refreshApex } from '@salesforce/apex';

import { subscribe, unsubscribe, MessageContext } from 'lightning/messageService';
import NOTIFICATION_CHANNEL from '@salesforce/messageChannel/ham_notificationChannel__c';

import getDirectoryTabset from '@salesforce/apex/HAM_AlumniDirectoryController.getDirectoryTabset';
import getFilters from '@salesforce/apex/HAM_AlumniDirectoryController.getFilterMetadataAndValues';
import getSavedUserPreferences from '@salesforce/apex/HAM_AlumniDirectoryController.getSavedUserPreferences';
import getContactDefaultFilterData from '@salesforce/apex/HAM_AlumniDirectoryController.getContactDefaultFilterData';
import getDirectoryData from '@salesforce/apex/HAM_AlumniDirectoryController.getDirectoryData';
import getDirectoryDataCount from '@salesforce/apex/HAM_AlumniDirectoryController.getDirectoryDataCount';


//custom labels
import BuildAlumniCommunity from '@salesforce/label/c.ham_BuildAlumniCommunity';
import blockedProfiles from '@salesforce/label/c.HAM_Blocked_Profiles';
import menuText from '@salesforce/label/c.ham_Directory_Menu';
import facultyStaffDirectoryLabel from '@salesforce/label/c.HAM_FacultyStaffDirectory';
import publicDirectorySearch from '@salesforce/label/c.Ham_Public_Directory_Search';

// Importing static resources
import HAM_ICONS from '@salesforce/resourceUrl/HAM_Icons';

export default class Ham_alumniDisplayCmp extends LightningElement {

    tabs = [];
    filters = [];
    @track filterTrack = [];

    @track alumniData = [];
    @track connectionsData = [];
    @track filteredData = [];
    wiredAlumniResult;
    @track connectionsRecordCount;
    @track screenWidth = window.innerWidth;
    @track isMobileFilterOpen = false;
    @track isMenuOpen = false;  // Hamberger menu flag
    
    _protalLogedUserPrivacy = false;

    @api label;
    @api contactId;
    @api contactClassYear;
    _activeTabName;

    @api isOverride = false;

    get mobileWrapperClass() {
        return this.isOverride ? 'mobile-content-wrapper kirkland-override' : 'mobile-content-wrapper';
    }

    get desktopWrapperClass() {
        return this.isOverride ? 'full-width-wrapper kirkland-override' : 'full-width-wrapper';
    }

    get saveBtnClass() {
        return this.isOverride ? 'kirkland-override save-bookmark-btn' : 'save-bookmark-btn';
    }

    get cancelBtnClass() {
        return this.isOverride ? 'kirkland-override cancel-bokmarksave-btn' : 'cancel-bokmarksave-btn';
    }

    get malFabBtnClass() {
        return this.isOverride ? 'kirkland-override mal-fab' : 'mal-fab';
    }
    get bookmarkBtnClass() {
        return 'bookmark-btn';
    }
    get currentDesktopBookmarkIcon() {
        return this.icons.whiteBookmark;
    }

    view = 'list';
    selectedProfile;

    pageSizeForChild = 9;
    currentPage = 1;
    recordsToSkip = 0;
    searchRecordsToSkip = 0;
    loadRecordsToSkip = 0;
    totalRecordsForChild = null;
    wiredAlumniCount;
    wiredUserPreference;
    alumnCommOrder = 0;
    myConnecOrder = 0;
    bookmarkOrder = 0;
    manageInvitkOrder = 0;
    blockProfOrder = 0;



    @track searchKey = null;
    savedFilters = null;
    searchKeyToApex = '';
    isSearchAction = false;
    @track isRestoringFilters = false;

    // Default filter state — null means "not yet resolved"
    _hasSavedPreferences = null;
    _defaultFiltersData = null;
    _applyingDefaults = false;

    /**
     * Tracks whether the user has intentionally modified any filter (add or remove)
     * in this session across any tab. When true, preset default filters will NOT be
     * re-applied on return to the Search Directory tab.
     * Reset only on full component re-init (page reload).
     */
    _userHasModifiedFilters = false;

    /**
     * Stores a snapshot of whatever filters were first applied on the Search Directory
     * tab (either saved user preferences or computed defaults). Used to restore filters
     * when the user returns to Search Directory without having modified any filter.
     */
    _initialDirectoryFilters = null;

    @track preferencesFound = false;
    isLoading = false;
    allowBookmark = false;
    showCustomToast = false;
    tabInitialized = false;
    primarykeyset = '';
    secondarykeyset = '';

    toastTitle;
    toastVariant;
    toastDuration;
    toastMessage;
    searchPlaceHolder;
    clearSearch = false;

    @track isFavIconActive = false;
    @track isBookmarkActive = false;
    @track showViewToggle = true;

    // [v1.4 - Anirudh] Tracks the active Manage Invitations sub-tab ('Received' or 'Sent').
    // Reactive — changing this value triggers both wire calls to re-fetch with the new sub-tab.
    @track invitationSubTab = 'Received';

    // [v1.4 - Anirudh] Stores the last known total count for the Received sub-tab.
    // Kept separate so the Received pill badge still shows its count while the user is on Sent.
    @track receivedCount = 0;

    BuildAlumniCommunity = BuildAlumniCommunity;
    blockedProfiles = blockedProfiles;
    menuText = menuText;
    facultyStaffDirectory = facultyStaffDirectoryLabel;
    publicDirectorySearch = publicDirectorySearch;

    hamIcons = HAM_ICONS;

    icons = {
        favIconEnabled: this.hamIcons + '/fav-fill.png',
        favIconDisabled: this.hamIcons + '/fav-outline.png',
        favIconEnabledGreen: this.hamIcons + '/fav-fill-green.png',
        favIconDisabledGreen: this.hamIcons + '/fav-outline-green.png',
        bookIconEnabled: this.hamIcons + '/bookmark-fill.png',
        bookIconDisabled: this.hamIcons + '/bookmark-outline.png',
        bookIconEnabledGreen: this.hamIcons + '/bookmark-fill-green.png',
        bookIconDisabledGreen: this.hamIcons + '/bookmark-outline-green.png',
        whiteBookmark: this.hamIcons + '/white-bookmark-fill.png',
        listViewIcon: this.hamIcons + '/list-view.png',
        // gridViewIcon: this.hamIcons + '/grid-view.png',
        gridViewIcon: this.hamIcons + '/grid-dark.png',
        viewCheckIcon: this.hamIcons + '/view-check.png',
        searchMobile: this.hamIcons + '/search-dir.png',
        clearSearchResult: this.hamIcons + '/resetFilter.png',
        filter: this.hamIcons + '/filter.png',
        hamburgerMobile: this.hamIcons + '/mobile-hamburger-outline.png',
        hamburgerMobileGreen: this.hamIcons + '/mobile-hamburger-outline-green.png',
        resetIcon: this.hamIcons + '/Reset-Filter.png',
    }

    @wire(MessageContext)
    messageContext;

    /**
     * @description Lifecycle hook invoked when the component is inserted into the DOM.
     * Initialises tabs, filters, message channel subscription, and global event listeners.
     */
    connectedCallback() {

        // If we're returning from Profile Overview, block the wires from applying
        // saved/default filters before retriggerDirectoryCountAndDataWires runs.
        // connectedCallback fires BEFORE wires, so this guard is timing-safe.
        if (sessionStorage.getItem('ham_returningFromProfile') === 'true') {
            this.isRestoringFilters = true;
            sessionStorage.removeItem('ham_returningFromProfile');
        }


        this.loadTabs();
        this.loadFilters();

        this.isLoading = true;

        // subscribing the message channel
        this.subscribeToMessageChannel();

        // event listener for window resize
        window.addEventListener('resize', this.handleResize.bind(this));

        // event listener for outside click
        document.addEventListener('click', this.handleOutsideClick, true);

        // Ensure state and UI are clean and aligned with the starting active tab name
        if (this._activeTabName) {
            this.resetTabState(this._activeTabName);
            
        }

    }

    /**
     * @description Lifecycle hook that runs when the component is removed from the DOM.
     * It removes event listeners to prevent memory leaks.
     */
    disconnectedCallback() {

        // Remove event listener when component is removed from DOM
        window.removeEventListener('resize', this.handleResize.bind(this));

        //Unsubscribes from the message channel when component is destroyed.
        this.unsubscribeToMessageChannel();

        //  remove event listener for outside click
        document.removeEventListener('click', this.handleOutsideClick, true);


        // Ensure scroll is restored
        document.body.style.overflow = '';
        document.documentElement.style.overflow = '';

    }

    /**
     * @description Arrow-function handler attached to the document click event.
     * Closes the mobile hamburger menu when the user clicks outside the menu wrapper
     * and restores body scroll.
     * @param {Event} event - The native click event.
     */
    handleOutsideClick = (event) => {
        if (!this.isMenuOpen) {
            return;
        }
        const wrapper = this.template.querySelector('.hamtab-wrapper');

        if (wrapper && !wrapper.contains(event.target)) {
            this.isMenuOpen = false;
            // Restore scroll when menu closes
            document.body.style.overflow = '';
            document.documentElement.style.overflow = '';
        }
    }

    handleMenuClick(event) {
        // Close menu on selection (mobile)
        this.isMenuOpen = false;
    }

    /**
     * @description Unsubscribes from the message channel when component is destroyed.
     * This prevents memory leaks and ensures proper cleanup.
     */
    unsubscribeToMessageChannel() {
        if (this.subscription) {
            unsubscribe(this.subscription);
            this.subscription = null;
        }
    }

    /**
    * @description Updates the screen width property on window resize.
    */
    handleResize() {
        this.screenWidth = window.innerWidth;
    }

    /**
     * @description Public getter for the currently active tab name.
     * @returns {string} The label of the active directory tab.
     */
    @api
    get activeTabName() {
        return this._activeTabName;
    }

    /**
     * @description Public setter for the active tab name. Triggers a tab reload
     * so that CSS classes and ordering stay in sync when the parent changes the tab.
     * @param {string} value - The new active tab label.
     */
    set activeTabName(value) {
        if (value && this._activeTabName !== value) {
            // [v1.4 - Anirudh] Reset Manage Invitations sub-tab to Received whenever the user
            // navigates away, so the tab always opens on Received the next time it is visited.
            if (this._activeTabName === this.label?.manageInvitation) {
                this.invitationSubTab = 'Received';
            }

            this._activeTabName = value;
            this.loadTabs();
            this.resetTabState(value);

            // Programmatically trigger wire refresh on programmatic tab changes
            this.isLoading = true;
            setTimeout(() => {
                Promise.all([
                    refreshApex(this.wiredAlumniCount),
                    refreshApex(this.wiredAlumniResult)
                ])
                    .then(() => {
                        this.applyTabFilter();
                    })
                    .catch(error => {
                        console.error('Error refreshing data on programmatic tab change:', error);
                    })
                    .finally(() => {
                        this.isLoading = false;
                    });
            }, 0);
        }
    }

    /**
     * @description Helper to reset filters, pagination, and data arrays when a tab switches
     * programmatically or manually.
     * @param {string} newTab - The tab name being navigated to.
     */
    resetTabState(newTab) {
        this.totalRecordsForChild = 0;

        // CLEAR SEARCH & FILTERS ON TAB SWITCH
        this.searchKey = '';
        this.searchKeyToApex = '';
        this.savedFilters = [];
        this.filterTrack = [];
        const filterCmp = this.template.querySelector('c-ham_alumni-search-filter-cmp');
        if (filterCmp) {
            filterCmp.clearAllFiltersOnTabSwitch();
        }

        // Non-directory tabs should never show auto-restored filters
        if (this.label && newTab !== this.label.buildCommunity) {
            this.savedFilters = [];
            this.filterTrack = [];
        }
        // Returning to Search Directory restores initial filters
        // ONLY if user never manually modified filters
        else if (
            !this._userHasModifiedFilters &&
            this._initialDirectoryFilters &&
            this._initialDirectoryFilters.length > 0
        ) {
            this.savedFilters = [...this._initialDirectoryFilters];
            this.filterTrack = [...this._initialDirectoryFilters];
        }

        // Wipe existing data immediately to avoid "ghost data"
        this.alumniData = [];
        this.filteredData = [];

        // Reset Pagination
        this.currentPage = 1;
        this.recordsToSkip = 0;

        // Update UI helpers
        if (this.label) {
            this.showViewToggle = newTab !== this.label.manageInvitation;

            if (newTab === this.label.buildCommunity) {
                this.searchPlaceHolder = 'Search Alumni...';
            } else if (newTab === this.label.myConnection) {
                this.searchPlaceHolder = 'Search My Connections...';
            } else if (newTab === this.label.bookmarkedProfiles) {
                this.searchPlaceHolder = 'Search Bookmarks...';
            } else if (newTab === this.label.manageInvitation) {
                this.searchPlaceHolder = 'Find Invitations...';
            } else {
                this.searchPlaceHolder = 'Search Blocked Profiles...';
            }
        }

        this.updateTabClasses();
    }

    /**
     * @description Whether the current viewport width qualifies as mobile (< 1024 px).
     * @returns {boolean}
     */
    get isMobileView() {
        return this.screenWidth < 1024;
    }

    /**
     * @description Whether the current viewport width qualifies as desktop (>= 1024 px).
     * @returns {boolean}
     */
    get isDesktopView() {
        return this.screenWidth >= 1024;
    }

    /**
     * @description CSS class that toggles the mobile filter overlay visibility.
     * @returns {string} 'mobile-filter-visible' or 'mobile-filter-hidden'.
     */
    get mobileFilterContainerClass() {
        return this.isMobileFilterOpen ? 'mobile-filter-visible' : 'mobile-filter-hidden';
    }
    /**
     * @description Subscribes to the MyImpact message channel to receive tab change events.
     * Prevents duplicate subscriptions by checking if one already exists.
     */
    subscribeToMessageChannel() {
        if (!this.subscription) {
            this.subscription = subscribe(
                this.messageContext,
                NOTIFICATION_CHANNEL,
                (message) => this.handleMessage(message)
            );
        }
    }

    /**
     * @description Method to process the subscribed data and set the active tab
     * message : contains the active tab value
     */
    handleMessage(message) {
        if (message.currentTab == this.label.alumniDirectory) {
            refreshApex(this.wiredAlumniCount);
            refreshApex(this.wiredAlumniResult);
        }
    }

    /**
     * @description Wire adapter that fetches the user's previously saved filter preferences.
     * When data arrives it either restores those filters or falls through to
     * tryApplyDefaultFilters() when no saved preference exists.
     * Skips processing when isRestoringFilters is true (e.g. returning from profile overview).
     * @param {Object} result - The wire result containing { data, error }.
     */
    @wire(getSavedUserPreferences, { currentContactId: '$contactId' })
    wiredUserPreferences(result) {

        this.wiredUserPreference = result;
        const { data, error } = result;

        // Stops clearing the filters when they arrive from main (after 'Back' is pressed on profile overview)
        if (this.isRestoringFilters) {
            this.isRestoringFilters = false;
            return;
        }

        if (data) {

            // Skip restoring ONLY during profile-state restoration
            // OR when user manually modified filters in current component lifecycle
            if (
                this.isRestoringFilters ||
                this._userHasModifiedFilters
            ) {
                this.isLoading = false;
                return;
            }

            const trimmed = data.trim();

            if (trimmed === '[]' || trimmed === '') {

                // Empty saved preference — treat same as no preference
                this._hasSavedPreferences = false;
                this.tryApplyDefaultFilters();
                this.isLoading = false;

            } else {

                this._hasSavedPreferences = true;

                const parsed = JSON.parse(trimmed);

                // CRITICAL FIX: Only apply saved preferences to search filters if the active tab is Search Directory
                if (this._activeTabName === this.label?.buildCommunity) {
                    this.savedFilters = [...parsed];
                    this.filterTrack = [...parsed];
                } else {
                    this.savedFilters = [];
                    this.filterTrack = [];
                }

                this.preferencesFound =
                    Array.isArray(parsed) && parsed.length > 0;

                // Snapshot for restore
                this._initialDirectoryFilters = [...parsed];

                this.isLoading = false;
            }
        } else if (error) {
            this._hasSavedPreferences = false;
            this.isLoading = false;
            console.log('Error loading saved filters', error);
        } else if (data === null) {
            // Apex returned null — no preference record exists; apply defaults
            this._hasSavedPreferences = false;
            this.tryApplyDefaultFilters();
        }
    }

    /**
     * @description Wire adapter that fetches the contact's default filter data
     * (class year, region, major). Once loaded, it delegates to tryApplyDefaultFilters()
     * which only applies the defaults when no saved preferences exist.
     * @param {Object} result - Destructured wire result { data, error }.
     */
    @wire(getContactDefaultFilterData, { contactId: '$contactId' })
    wiredContactDefault({ data, error }) {
        if (data) {
            this._defaultFiltersData = data;
            this.tryApplyDefaultFilters();
        } else if (error) {
            console.log('Error loading default filter data', error);
            this.isLoading = false;
        }
    }

    /**
     * @description Builds and applies preset default filters (Class Year, Region, Major)
     * derived from the contact's own record data. Only executes when both conditions are met:
     *   1. The saved-preferences wire has resolved and confirmed no saved filters exist.
     *   2. The default-filter-data wire has resolved with valid contact data.
     * Sets the _applyingDefaults guard flag so that handleFilterChange ignores the
     * resulting child filterchange event and does not mark filters as user-modified.
     */
    tryApplyDefaultFilters() {

        // [CLIENT REQUEST - DISABLED] Auto-preset default filters (Class Year, Region, Major) are turned off.
        // Remove the return below to re-enable: directory will auto-apply the logged-in user's own
        // class year, region, and major as pre-selected filters when no saved preferences exist.
        return;

        // Never re-apply defaults once user modified filters
        if (
            this._userHasModifiedFilters ||
            this.isSearchAction ||
            (this._activeTabName && this._activeTabName !== this.label.buildCommunity)
        ) {
            return;
        }

        // Both wires must resolve first
        if (this._hasSavedPreferences !== false) return;
        if (!this._defaultFiltersData) return;

        const defaultFilters = [];

        const {
            classYear,
            currentChapters,
            majorValues
        } = this._defaultFiltersData;

        if (classYear) {
            defaultFilters.push({
                placeholder: 'Class Year',
                values: [classYear]
            });
        }

        if (
            Array.isArray(currentChapters) &&
            currentChapters.length > 0
        ) {
            defaultFilters.push({
                placeholder: 'Region',
                values: currentChapters
            });
        }

        if (
            Array.isArray(majorValues) &&
            majorValues.length > 0
        ) {
            defaultFilters.push({
                placeholder: 'Major',
                values: majorValues
            });
        }

        if (defaultFilters.length > 0) {

            this.savedFilters = defaultFilters;
            this.filterTrack = [...defaultFilters];

            // Snapshot for restore
            this._initialDirectoryFilters = [...defaultFilters];
        }

        this.isLoading = false;
    }


    /**
     * @description Wire adapter that fetches the total record count for the current tab,
     * search key, filters, and invitation sub-tab. Updates totalRecordsForChild which
     * drives the pagination component.
     * @param {Object} result - The wire result containing { data, error }.
     */
    // Returns 'true'/'false' string so the wire reactive parameter changes when the pill is toggled.
    get _bookmarkConnectionsFilterStr() {
        return this.isBookmarkActive ? 'true' : 'false';
    }

    get _favoriteConnectionsFilterStr() {
        return this.isFavIconActive ? 'true' : 'false';
    }

    @wire(getDirectoryDataCount, {
        tab: '$_activeTabName', searchKey: '$searchKeyToApex', selectedFilters: '$savedFilters',
        portalConstituentId: '$contactId', invitationSubTab: '$invitationSubTab',
        bookmarkConnectionsFilter: '$_bookmarkConnectionsFilterStr',
        favoriteConnectionsFilter: '$_favoriteConnectionsFilterStr'
    })
    wiredAlumniCountDetails(result) {
        this.isLoading = true;
        this.wiredAlumniCount = result;
        const { data, error } = result;

        if (data > 0) {
            this.totalRecordsForChild = data;
        }

        if (data == 0) {
            this.totalRecordsForChild = null;
        }

        if (error) {
            console.log('Error ' + error);
        }

        this.isLoading = false;
    }

    /**
     * @description Wire adapter that fetches the paginated directory data for the current
     * tab, search key, filters, and invitation sub-tab. Stores the raw result for
     * refreshApex and delegates to applyTabFilter() to transform data per tab.
     * @param {Object} result - The wire result containing { data, error }.
     */
    @wire(getDirectoryData, {
        tab: '$_activeTabName', pageSize: '$pageSizeForChild', recordsToSkip: '$recordsToSkip',
        searchKey: '$searchKeyToApex', selectedFilters: '$savedFilters', portalConstituentId: '$contactId',
        invitationSubTab: '$invitationSubTab',
        bookmarkConnectionsFilter: '$_bookmarkConnectionsFilterStr',
        favoriteConnectionsFilter: '$_favoriteConnectionsFilterStr'
    })
    wiredAlumni(result) {
        this.isLoading = true;
        this.wiredAlumniResult = result;
        const { data, error } = result;

        if (data) {
            this.alumniData = data || [];
             // Capture logged-in user's connection-privacy flag from the Apex response
            this._protalLogedUserPrivacy = data.protalLogedUserPrivacy === true;
            //console.log('Directory Data: ',JSON.stringify(this.alumniData,null,2));

            this.applyTabFilter();
            this.isLoading = false;
        }
        else if (error) {
            this.isLoading = false;
             // Reset on error so a stale "true" doesn't keep buttons hidden
            this._protalLogedUserPrivacy = false;
            console.error('Load Alumni error: ', error);
        }
    }

    /**
     * @description Lifecycle hook invoked after every render cycle. Reserved for
     * DOM-dependent post-render work; currently a no-op placeholder.
     */
    renderedCallback() {
        //console.log('Rendered:');
    }

    /**
     * @description Opens the mobile filter overlay by setting the visibility flag.
     */
    handleFilterClick() {
        this.isMobileFilterOpen = true;
    }

    /**
     * @description Handles the closemobilefilters event from the child filter component.
     * Hides the mobile filter overlay.
     */
    handleCloseMobileFilters() {
        this.isMobileFilterOpen = false;
    }

    /**
     * @description Imperatively fetches the directory tab metadata from Apex,
     * initialises each tab with an inactive CSS class, then updates
     * active-tab highlighting and mobile tab order numbers.
     */
    loadTabs() {
        getDirectoryTabset()
            .then(result => {
                this.tabs = result.map(tab => ({
                    ...tab,
                    className: 'main-tab-inactive'
                }));
                // Update tab classes after tabs are loaded
                this.updateTabClasses();
                this.updateTabOrders();
            })
            .catch(error => {
                console.log('Load Tabs: ', error);
            });
    }

    /**
     * @description Imperatively fetches the filter metadata and picklist values
     * from Apex and stores them for the child filter component.
     */
    loadFilters() {
        getFilters()
            .then(result => {
                this.filters = result;
            })
            .catch(error => {
                console.log('Load Filters error: ', error);
            });
    }


    /**
     * @description Returns the correct favourite icon URL based on the active state
     * and whether the Kirkland override theme is enabled.
     * @returns {string} Static resource path to the appropriate icon image.
     */
    get currentFavIcon() {
        if (this.isOverride) {
            return this.isFavIconActive ? this.icons.favIconEnabledGreen : this.icons.favIconDisabledGreen;
        }
        return this.isFavIconActive ? this.icons.favIconEnabled : this.icons.favIconDisabled;
    }

    // [v1.4 - Anirudh] ── Manage Invitations sub-tab pill helpers ──────────────────────────

    /**
     * CSS class for the Received pill button.
     * Active (dark filled) when Received sub-tab is selected.
     */
    get receivedSubTabClass() {
        return this.invitationSubTab === 'Received' ? 'tab-toggle-btn active' : 'tab-toggle-btn';
    }

    /**
     * CSS class for the Sent pill button.
     * Active (dark filled) when Sent sub-tab is selected.
     */
    get sentSubTabClass() {
        return this.invitationSubTab === 'Sent' ? 'tab-toggle-btn active' : 'tab-toggle-btn';
    }

    /**
     * Handles Received / Sent pill button clicks on the Manage Invitations tab.
     * Resets pagination to page 1 and lets the reactive wire re-fetch for the new sub-tab.
     */
    handleInvitationSubTabToggle(event) {
        const selected = event.currentTarget.dataset.subtab;
        if (selected === this.invitationSubTab) return; // no-op if already active

        this.invitationSubTab = selected;
        // Reset pagination so the new sub-tab always starts from page 1
        this.currentPage = 1;
        this.recordsToSkip = 0;
        this.totalRecordsForChild = null;

        // Wait for LWC to provision the new sub-tab parameter before refreshing
        setTimeout(() => {
            Promise.all([
                refreshApex(this.wiredAlumniCount),
                refreshApex(this.wiredAlumniResult)
            ]);
        }, 0);
    }

    // ─────────────────────────────────────────────────────────────────────────────

    get favButtonClass() {
        return this.isFavIconActive ? 'tab-toggle-btn active' : 'tab-toggle-btn';
    }

    /**
     * @description Toggles the "Favorite Connections" pill on the My Connections tab.
     * Triggers a re-application of the My Connections filter to ensure data remains
     * reactive without requiring a page refresh.
     */
    handleFavIconToggle() {
        this.isFavIconActive = !this.isFavIconActive;
        this.currentPage = 1;
        this.recordsToSkip = 0;
        this.totalRecordsForChild = null;
        // Wire re-fires reactively via _favoriteConnectionsFilterStr getter
    }


    /**
     * @description Core filtering logic for the "My Connections" tab.
     * Matches secondary connections against primary connections to determine status.
     * If the "Favorite Connections" pill is active, it dynamically refilters the array client-side 
     * and strictly updates the `totalRecordsForChild` count so pagination displays correctly.
     */
    applyMyConnectionsFilter() {
        const primaryConns = this.alumniData?.connectionsData?.primaryConnections || [];
        const secondaryConns = this.alumniData?.connectionsData?.secondaryConnections || [];
        // Create a map of primary connections by linkedUserId for quick lookup
        const primaryConnMap = new Map();
        primaryConns.forEach(conn => {
            primaryConnMap.set(conn.linkedUserId, conn);
        });

        // Filter secondary connections based on criteria and transform
        this.filteredData = secondaryConns
            .filter(secConn => {
                const matchingPrimary = primaryConnMap.get(secConn.portalUserId);

                if (!matchingPrimary) return false;

                return secConn.linkedUserId === matchingPrimary.portalUserId &&
                    matchingPrimary.flags?.isConnected === true;
            })
            .map(secConn => {
                const matchingPrimary = primaryConnMap.get(secConn.portalUserId);

                return {
                    ...secConn,
                    isConnected: true,
                    isBookmarked: matchingPrimary?.flags?.isBookmarked === true,
                    isFavorite: matchingPrimary?.flags?.isFavorite === true
                };
            });

        this.totalRecordsForChild = this.wiredAlumniCount?.data > 0 ? this.wiredAlumniCount.data : null;
    }

    /**
     * @description Core filtering logic for the "Bookmarked Profiles" tab.
     * Processes primary and secondary connections, calculates cooldown periods, and flags statuses.
     * If the "Bookmarked Connections" pill is active, it dynamically refilters the array client-side 
     * and strictly updates the `totalRecordsForChild` count so pagination displays correctly.
     */
    applyBookmarksFilter() {
        const primaryConns = this.alumniData?.connectionsData?.primaryConnections || [];
        const secondaryConns = this.alumniData?.connectionsData?.secondaryConnections || [];

        // Create a map of secondary connections by portalUserId for quick lookup
        const secondaryConnMap = new Map();
        secondaryConns.forEach(conn => {
            if (!secondaryConnMap.has(conn.portalUserId)) {
                secondaryConnMap.set(conn.portalUserId, []);
            }
            secondaryConnMap.get(conn.portalUserId).push(conn);
        });

        // Filter primary connections where isBookmarked is true and transform
        this.filteredData = primaryConns
            .filter(primaryConn => primaryConn.flags?.isBookmarked === true)
            .map(primaryConn => {
                // Get related secondary connections for this primary connection's linkedUserId
                const relatedSecondaryConns = secondaryConnMap.get(primaryConn.linkedUserId) || [];


                // isCoolDown: Check if any secondary connection has linkedUserId === this.userContactId 
                // AND (status === 'Disconnect' OR status === 'Rejected') AND rejectedDate within 30 days
                const isCoolDown = relatedSecondaryConns.some(secConn =>
                    secConn.linkedUserId === this.contactId &&
                    (secConn.status === 'Disconnect' || secConn.status === 'Rejected') &&
                    this._isWithinCooldownPeriod(secConn.rejectedDate)
                );

                return {
                    ...primaryConn,
                    isConnected: primaryConn.flags?.isConnected === true,
                    isBookmarked: primaryConn.flags?.isBookmarked === true,
                    isFavorite: primaryConn.flags?.isFavorite === true,
                    isRequestSent: primaryConn.status == 'Request Sent',
                    isCoolDown
                };
            });

        this.totalRecordsForChild = this.wiredAlumniCount?.data > 0 ? this.wiredAlumniCount.data : null;
    }

    get isBuildAlumniCommunity() {
        return this._activeTabName == this.label.buildCommunity
    }
    get isMyConnectionsTab() {
        return this._activeTabName == this.label.myConnection;
    }

    get isBookmarksTab() {
        return this._activeTabName == this.label.bookmarkedProfiles;
    }

    get isManageInvitationTab() {
        return this._activeTabName == this.label.manageInvitation;
    }

    get isBlockprofileTab() {
        return this._activeTabName == this.blockedProfiles;
    }

    get currentBoomarkIcon() {
        if (this.isOverride) {
            return this.isBookmarkActive ? this.icons.bookIconEnabledGreen : this.icons.bookIconDisabledGreen;
        }
        return this.isBookmarkActive ? this.icons.bookIconEnabled : this.icons.bookIconDisabled;
    }

    get currentMobileBookmarkIcon() {
        return this.isOverride ? this.icons.bookIconDisabledGreen : this.icons.bookIconDisabled;
    }

    get bookmarkButtonClass() {
        return this.isBookmarkActive ? 'tab-toggle-btn active' : 'tab-toggle-btn';
    }


    /**
     * @description Toggles the "Bookmarked Connections" pill on the Bookmarked Profiles tab.
     * Triggers a re-application of the Bookmarks filter to ensure data remains
     * reactive without requiring a page refresh.
     */
    handleBookmarkIconToggle() {
        this.isBookmarkActive = !this.isBookmarkActive;
        this.currentPage = 1;
        this.recordsToSkip = 0;
        this.totalRecordsForChild = null;
        // Wire re-fires reactively via _bookmarkConnectionsFilterStr getter
    }

    applyTabFilter() {

        switch (this.activeTabName) {
            case this.label.myConnection: {
                this.searchPlaceHolder = 'Search My Connections...';
                this.applyMyConnectionsFilter();
                break;
            }

            case this.label.bookmarkedProfiles: {
                this.searchPlaceHolder = 'Search Bookmarks...';
                this.applyBookmarksFilter();
                break;
            }

            case this.label.buildCommunity: {
                this.searchPlaceHolder = 'Search Alumni...'
                const primaryConnections = this.alumniData?.connectionsData?.primaryConnections || [];
                const secondaryConnections = this.alumniData?.connectionsData?.secondaryConnections || [];
                const constituents = this.alumniData?.constituentsData || [];

                // Create a map for primary connections by linkedUserId for faster lookup
                const primaryConnectionMap = new Map();
                primaryConnections.forEach(conn => {
                    primaryConnectionMap.set(conn.linkedUserId, conn);
                });

                // Create a map for secondary connections by portalUserId
                const secondaryConnectionMap = new Map();
                secondaryConnections.forEach(conn => {
                    if (!secondaryConnectionMap.has(conn.portalUserId)) {
                        secondaryConnectionMap.set(conn.portalUserId, []);
                    }
                    secondaryConnectionMap.get(conn.portalUserId).push(conn);
                });

                // Process each constituent and add the required variables
                this.filteredData = constituents.map(constituent => {
                    // Find matching primary connection
                    const primaryConn = primaryConnectionMap.get(constituent.id);

                    // Find matching secondary connections
                    const secondaryConns = secondaryConnectionMap.get(constituent.id) || [];

                    // isBookmarked: primary connection exists and isBookmarked flag is true
                    const isBookmarked = primaryConn?.flags?.isBookmarked === true;

                    // isConnected: primary connection exists and isConnected flag is true
                    const isConnected = primaryConn?.flags?.isConnected === true;

                    // isRequestSent: primary connection exists and status = 'Request Sent'
                    const isRequestSent = primaryConn?.status === 'Request Sent';

                    // isCoolDown: secondary connection with Disconnect/Rejected within 30 days
                    let isCoolDown = false;
                    for (const secConn of secondaryConns) {
                        if (secConn.linkedUserId === this.contactId &&
                            (secConn.status === 'Disconnect' || secConn.status === 'Rejected') &&
                            this._isWithinCooldownPeriod(secConn.rejectedDate)) {
                            isCoolDown = true;
                            break;
                        }
                    }

                    return {
                        ...constituent,
                        portalUserId: constituent.id,
                        isBookmarked,
                        isConnected,
                        isRequestSent,
                        isCoolDown
                    };
                });
                break;

            }

            case this.label.manageInvitation: {
                this.searchPlaceHolder = 'Find Invitations...'

                // [v1.4 - Anirudh] Branch on invitationSubTab to show Received or Sent records.
                if (this.invitationSubTab === 'Sent') {
                    // SENT SUB-TAB: use sentRequests returned directly by Apex for this sub-tab.
                    // constituentId mapping in child components uses linkedUserId for Sent
                    // so Cancel Request passes the correct recipient ID to Apex.
                    this.filteredData = this.alumniData?.sentRequests || [];
                } else {
                    // RECEIVED SUB-TAB (default): existing logic unchanged.
                    const primaryConns = this.alumniData?.connectionsData?.primaryConnections || [];
                    const secondaryConns = this.alumniData?.connectionsData?.secondaryConnections || [];

                    // Build a map of primary connections keyed by linkedUserId for bookmark lookup
                    const primaryConnMap = new Map();
                    primaryConns.forEach(conn => {
                        primaryConnMap.set(conn.linkedUserId, conn);
                    });

                    // Filter secondary connections where status = 'Request Sent'
                    this.filteredData = secondaryConns
                        .filter(secConn => secConn.status === 'Request Sent')
                        .map(secConn => {
                            const matchingPrimary = primaryConnMap.get(secConn.portalUserId);

                            // Cross-reference primary connection to check bookmark status
                            let isBookmarked = false;
                            if (matchingPrimary && secConn.linkedUserId === matchingPrimary.portalUserId) {
                                isBookmarked = matchingPrimary.flags?.isBookmarked === true;
                            }

                            return {
                                ...secConn,
                                isBookmarked
                            };
                        });
                }
                break;
            }

            case blockedProfiles: {
                this.searchPlaceHolder = 'Search Blocked Profiles...';

                const primaryConns = this.alumniData?.connectionsData?.primaryConnections || [];

                this.filteredData = primaryConns
                    .filter(conn => conn.flags?.isBlocked === true)
                    .map(conn => {
                        return {
                            ...conn,
                            isBlocked: conn.flags?.isBlocked === true,
                            isConnected: conn.flags?.isConnected === true,
                            isBookmarked: conn.flags?.isBookmarked === true,
                            isFavorite: conn.flags?.isFavorite === true
                        };
                    });

                break;
            }

            default:
                this.filteredData = [];
        }
        this.updateTabClasses();
    }

    updateTabClasses() {
        this.tabs = this.tabs.map(tab => ({
            ...tab,
            // className:tab.Label === this._activeTabName ? 'main-tab-active' : 'main-tab-inactive'
            className: tab.Label === this._activeTabName
                ? (this.isOverride ? 'main-tab-active kirkland-override' : 'main-tab-active')
                : (this.isOverride ? 'main-tab-inactive kirkland-override' : 'main-tab-inactive')
        }));
    }

    updateTabOrders() {
        this.tabs.forEach(tab => {
            if (tab.Label === this.label.buildCommunity) {
                this.alumnCommOrder = tab.Tab_Order__c;
            }
            else if (tab.Label === this.label.myConnection) {
                this.myConnecOrder = tab.Tab_Order__c;
            }
            else if (tab.Label === this.label.bookmarkedProfiles) {
                this.bookmarkOrder = tab.Tab_Order__c;
            }
            else if (tab.Label === this.label.manageInvitation) {
                this.manageInvitkOrder = tab.Tab_Order__c;
            }
            else if (tab.Label === 'Blocked Profiles') {
                this.blockProfOrder = tab.Tab_Order__c;
            }
        });
    }

    handleTabClick(event) {
        const newTab = event.currentTarget.dataset.tabname;
        this.isMenuOpen = false;  // close hamberger menu
        document.body.style.overflow = '';

        // Prevent clicking the same tab twice (optional optimization)
        if (this._activeTabName === newTab) return;

        // Update URL with selected subtab
        const url = new URL(window.location.href);
        url.searchParams.set('tab', newTab);
        window.history.pushState({}, '', url.toString());

        // [v1.4 - Anirudh] Reset Manage Invitations sub-tab to Received whenever the user
        // navigates away, so the tab always opens on Received the next time it is visited.
        if (this._activeTabName === this.label?.manageInvitation) {
            this.invitationSubTab = 'Received';
        }

        this.isLoading = true;
        this._activeTabName = newTab;
        
        this.resetTabState(newTab);

        // Wait for the next event loop tick so LWC has time to push the new reactive
        // parameters to the @wire before we call refreshApex.
        setTimeout(() => {
            Promise.all([
                refreshApex(this.wiredAlumniCount),
                refreshApex(this.wiredAlumniResult)
            ])
                .then(() => {
                    this.applyTabFilter();
                })
                .catch(error => {
                    console.error('Error refreshing data:', error);
                })
                .finally(() => {
                    this.isLoading = false;
                });
        }, 0);
    }


    handleViewToggle(event) {
        const viewType = event.currentTarget.dataset.view;
        this.view = viewType;
    }

    handleProfileSelect(event) {
        event.stopPropagation();

        const currentView = this.view;

        this.view = 'profileView';
        this.selectedContactId = event.detail?.selectedContactId ?? event.detail;

        this.dispatchEvent(
            new CustomEvent('profileoverview', {
                detail: {
                    selectedContactId: this.selectedContactId,
                    directoryPreviousTab: this._activeTabName,
                    searchKeyToApex: this.searchKeyToApex,
                    savedFilters: this.savedFilters,
                    primarykeyset: this.primarykeyset,
                    secondarykeyset: this.secondarykeyset,
                    recordsToSkip: this.recordsToSkip,
                    view: currentView,
                    // Carry the filter-modification flag so the parent can relay it back on "Back".
                    userHasModifiedFilters: this._userHasModifiedFilters,
                    // Carry the Search Directory initial-filters snapshot so it survives
                    // the component re-mount that happens while profile overview is shown.
                    // Without this, returning from a no-filter tab (e.g. My Connections)
                    // would leave _initialDirectoryFilters as null and Search Directory
                    // would show no filters even though nothing was ever changed.
                    initialDirectoryFilters: this._initialDirectoryFilters
                        ? [...this._initialDirectoryFilters]
                        : null
                },
                bubbles: true,
                composed: true
            })
        );
    }

    handleProfileClose() {
        this.view = 'list';
        this.selectedProfile = null;
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

    get isProfileOverView() {
        return this.view === 'profileView';
    }

    get initialDirectoryFilters() {
        return this._initialDirectoryFilters;
    }

    get userHasModifiedFilters() {
        return this._userHasModifiedFilters;
    }

    handleRefreshData() {
        this.isLoading = true;

        // Clear search key
        this.searchKey = '';
        this.searchKeyToApex = '';
        this._userHasModifiedFilters = true;

        // Safely clear all filters in any child component found in the DOM
        const filterCmps = this.template.querySelectorAll('c-ham_alumni-search-filter-cmp');
        filterCmps.forEach(cmp => {
            cmp.clearAllFiltersTemporarily();
        });

        // Reset pagination
        this.currentPage = 1;
        this.recordsToSkip = 0; // Simplified since both if/else did the same thing

        // Close the confirmation modal
        this.clearSearch = false;

        // Update bookmark icon to show unsaved state
        this.preferencesFound = false;

        // Ensure we clear out the local tracking array so UI pills/badges disappear
        this.savedFilters = [];
        this.filterTrack = [];

        // Flag that the user has actively modified (cleared) filters so defaults aren't reapplied
        this._userHasModifiedFilters = true;

        // Wait for the new parameters to provision before refreshing
        setTimeout(() => {
            Promise.all([
                refreshApex(this.wiredAlumniCount),
                refreshApex(this.wiredAlumniResult)
            ])
                .then(() => {
                    this.applyTabFilter();
                })
                .catch(error => {
                    console.error('Error refreshing data:', error);
                })
                .finally(() => {
                    this.isLoading = false;
                });
        }, 0);
    }

    get bookmarkIconClass() {
        return this.preferencesFound ? 'bookmark-icon saved' : 'bookmark-icon unsaved';
    }

    toggleBookmark() {
        this.allowBookmark = true;
    }

    handleCancelBokmarksave(event) {
        event?.stopPropagation();
        this.allowBookmark = false;
    }

    handleFilterChange(event) {

        const {
            filters = [],
            areFiltersChanged = false
        } = event.detail || {};

        // User intentionally modified filters
        // INCLUDING clear filters
        this._userHasModifiedFilters = true;

        this.isLoading = true;
        this.currentPage = 1;
        this.recordsToSkip = 0;

        this.filterTrack = [...filters];
        this.savedFilters = [...filters];

        if (event.detail.clearSearchKey) {
            this.searchKey = '';
            this.searchKeyToApex = '';
        }

        if (this.savedFilters && this.isSearchAction !== true) {
            this.preferencesFound = !areFiltersChanged;
        }

        // Force refresh
        setTimeout(() => {
            Promise.all([
                refreshApex(this.wiredAlumniCount),
                refreshApex(this.wiredAlumniResult)
            ])
                .catch(e => console.error(e))
                .finally(() => {
                    this.isLoading = false;
                });
        }, 0);
    }


    handleSaveBookmark(event) {
        event.stopPropagation();
        this.isLoading = true;

        const filterCmp = this.isMobileView
            ? this.template.querySelector('.mobile-filter-overlay c-ham_alumni-search-filter-cmp')
            : this.template.querySelector('.filters-row c-ham_alumni-search-filter-cmp');

        if (!filterCmp) {

            this.isLoading = false;
            this.allowBookmark = false;
            return;
        }

        filterCmp.saveSelectedFilters()
            .then(() => {
                this.toastTitle = 'Success';
                this.toastMessage = 'Filters Saved!';
                this.toastVariant = 'success';
                this.toastDuration = 5000;
                this.showCustomToast = true;

                this.preferencesFound = true;
                this.allowBookmark = false;

            })
            // .then(() => {
            //     return refreshApex(this.wiredUserPreference);
            // })
            .catch(err => {
                console.log('Error saving filters', err);
                this.toastTitle = 'Error';
                this.toastMessage = 'Unable to save filters';
                this.toastVariant = 'error';
                this.toastDuration = 5000;
                this.showCustomToast = true;
            })
            .finally(() => {
                this.isLoading = false;
                this.isSearchAction = false;
            });
    }


    handleToastClose() {
        this.showCustomToast = false;
    }

    stopPropagation(event) {
        event.stopPropagation();
    }

    handleSearchInput(event) {
        this.searchKey = event.target.value;
        // Only clear the apex search key when the input is emptied;
        // actual search execution happens on Enter or the search-button click.
        if (!this.searchKey || !this.searchKey.trim()) {
            this.searchKeyToApex = '';
        }
    }

    handleSearchKeydown(event) {
        if (event.key === 'Enter') {
            this._executeSearch();
        }
    }

    handleSearchClick() {
        this._executeSearch();
    }

    /**
     * @description Central search execution method shared by the search button click and
     * Enter keydown. Guards against two cases where the @wire reactive parameters would NOT
     * change — meaning the wire would not re-fire, leaving isLoading permanently true:
     *
     * 1. Empty search key when searchKeyToApex is already '' → no-op, return early.
     * 2. Duplicate search (same key submitted twice) → force refreshApex so the spinner resolves.
     *
     * @returns {void}
     */
    _executeSearch() {
        const newSearchKey = (this.searchKey || '').trim();

        // Always use filterTrack as the source of truth for current UI filters.
        // Fallback to empty array if undefined.
        const newSavedFilters = this.filterTrack ? [...this.filterTrack] : [];

        const searchKeyUnchanged = newSearchKey === (this.searchKeyToApex || '');
        const filtersUnchanged = JSON.stringify(newSavedFilters) === JSON.stringify(this.savedFilters);

        // Case 1: Empty search with no previous search active — nothing to do.
        if (newSearchKey === '' && searchKeyUnchanged) {
            return;
        }

        // Case 2: Both key and filters are identical to current state — the @wire will NOT
        // re-fire. Force a manual refreshApex so the spinner always resolves.
        if (searchKeyUnchanged && filtersUnchanged) {
            this.isLoading = true;
            Promise.all([
                refreshApex(this.wiredAlumniCount),
                refreshApex(this.wiredAlumniResult)
            ])
                .catch(error => console.error('Search refresh error:', error))
                .finally(() => { this.isLoading = false; });
            return;
        }

        // Normal path: at least one reactive parameter changed → wire will re-fire and
        // set isLoading = false itself inside wiredAlumni / wiredAlumniCountDetails.
        this.isLoading = true;
        this.currentPage = 1;
        this.isSearchAction = true;
        this.searchKeyToApex = newSearchKey;
        this.recordsToSkip = 0;
        this.savedFilters = newSavedFilters;

        // Wait for the new parameters to provision, then force refresh to bypass stale search cache
        setTimeout(() => {
            Promise.all([
                refreshApex(this.wiredAlumniCount),
                refreshApex(this.wiredAlumniResult)
            ]).catch(error => console.error('Search refresh error:', error));
        }, 0);
    }


    handlePageChange(event) {
        this.isLoading = true;

        this.currentPage = event.detail.currentPage;

        if (this.searchKey != null && this.searchKey != '') {
            this.recordsToSkip = event.detail.recordsToSkip;
        } else {
            this.recordsToSkip = event.detail.recordsToSkip;
        }

        // Update keysets for caching (Keep your existing logic)
        // Make sure these exist in alumniData before accessing
        /*if (this.alumniData?.connectionsData) {
            this.primarykeyset = this.alumniData.connectionsData.primaryConnections?.map(conn => conn.header.name).join(',') || '';
            this.secondarykeyset = this.alumniData.connectionsData.secondaryConnections?.map(conn => conn.header.name).join(',') || '';
        }*/

    }

    handleClearSearchResults() {
        this.clearSearch = true;

    }

    handleCloseClearSearch() {
        this.clearSearch = false;
    }

    clearSearchResultData() {
        this.handleRefreshData();
    }

    handleGoToDirectoryTab() {
        const buildTab = this.label.buildCommunity;
        if (this._activeTabName === buildTab) return;
        this.isLoading = true;
        this._activeTabName = buildTab;
        this.totalRecordsForChild = 0;
        this.alumniData = [];
        this.filteredData = [];
        this.currentPage = 1;
        this.recordsToSkip = 0;
        this.searchPlaceHolder = 'Search Alumni...';
        this.showViewToggle = true;

        // Refresh data using refreshApex
        Promise.all([
            refreshApex(this.wiredAlumniCount),
            refreshApex(this.wiredAlumniResult)
        ])
            .then(() => {
                this.applyTabFilter();
            })
            .catch(error => {
                console.error('Error refreshing data:', error);
            })
            .finally(() => {
                this.isLoading = false;
            });

        //this.isLoading = false;
        this.updateTabClasses();
    }

    handleChildRefresh() {

        // Refresh data using refreshApex
        Promise.all([
            refreshApex(this.wiredAlumniCount),
            refreshApex(this.wiredAlumniResult)
        ])
            .then(() => {
                this.applyTabFilter();
            })
            .catch(error => {
                console.error('Error refreshing data:', error);
            })
            .finally(() => {
                this.isLoading = false;
            });
    }


    // getter for hamberger menu css
    get tabContainerClass() {
        return `hamtab-container mobile ${this.isMenuOpen ? 'open' : ''}`;
    }

    get tabContainerClassParent() {
        const base = this.isOverride ? 'hamtab-wrapper kirkland-override' : 'hamtab-wrapper';
        return this.isMenuOpen ? `${base} menu-open` : base;
    }

    get sidebarClass() {
        return `tab-child-container ${this.isMenuOpen ? 'open' : ''}`;
    }

    toggleMenu() {
        this.isMenuOpen = !this.isMenuOpen;


        if (this.isMenuOpen) {
            document.body.style.overflow = 'hidden';
            document.documentElement.style.overflow = 'hidden';
        } else {
            document.body.style.overflow = '';
            document.documentElement.style.overflow = '';
        }

    }

    @api
    retriggerDirectoryCountAndDataWires(searchKeyToApex, savedFilters, primarykeyset, secondarykeyset, recordsToSkip, directoryView, userHasModifiedFilters, initialDirectoryFilters) {

        // Declare parsedFilters FIRST (before any use) to avoid TDZ issues.
        const parsedFilters = savedFilters ? JSON.parse(JSON.stringify(savedFilters)) : [];

        // Set isRestoringFilters immediately (synchronously) so any resolving wires are
        // blocked from overwriting the restored state with defaults.
        this.isRestoringFilters = true;

        // Only mark filters as user-modified when they actually were. If the user never
        // touched filters before clicking "View Profile", keeping this false ensures that
        // points 1-4 continue to work (e.g. returning to tab 1 still shows initial filters).
        if (userHasModifiedFilters === true) {
            this._userHasModifiedFilters = true;
        }

        this.searchKey = searchKeyToApex;
        this.searchKeyToApex = searchKeyToApex;
        this.primarykeyset = primarykeyset || '';
        this.secondarykeyset = secondarykeyset || '';
        this.recordsToSkip = recordsToSkip || 0;
        this.view = directoryView;

        // Apply the restored filters (may be empty if user had cleared them before navigating).
        this.savedFilters = parsedFilters;
        this.filterTrack = [...parsedFilters];

        if (userHasModifiedFilters === true) {
            // Point 5 scenario: user changed filters then navigated to profile.
            // _userHasModifiedFilters stays true (already set above).
            // _initialDirectoryFilters is intentionally left unchanged — handleTabClick
            // already ignores it when _userHasModifiedFilters is true.
        } else {
            // Point 1-4 scenario: user did NOT change filters.
            // Restore the Search Directory snapshot that was snapshotted at View Profile time.
            // This is critical when the user was on a non-Search-Directory tab (e.g. My
            // Connections) where savedFilters = [] — without the snapshot, _initialDirectoryFilters
            // would be overwritten with null and Search Directory would lose its filters.
            this._initialDirectoryFilters = (initialDirectoryFilters && initialDirectoryFilters.length > 0)
                ? [...initialDirectoryFilters]
                : null;
        }

        // Use setTimeout to guarantee the DOM (both Mobile and Desktop templates)
        // is fully rendered before trying to pass data to the child components.
        setTimeout(() => {
            const filterCmps = this.template.querySelectorAll('c-ham_alumni-search-filter-cmp');

            filterCmps.forEach(cmp => {
                if (parsedFilters && parsedFilters.length > 0) {
                    cmp.savedFilters = [...parsedFilters];
                } else {
                    if (typeof cmp.clearAllFiltersOnTabSwitch === 'function') {
                        cmp.clearAllFiltersOnTabSwitch();
                    }
                }
            });
        }, 0);
    }

    // Computes active filter badges for the desktop filter row
    get desktopFilterBadges() {
        if (!this.filterTrack || !this.filterTrack.length) return [];
        return this.filterTrack
            .filter(f => f.values && f.values.length > 0)
            .map((f, index) => ({
                uniqueId: `desktop-badge-${index}-${f.placeholder}`,
                category: f.placeholder,
                value: f.values.join(', ')
            }));
    }

    // Add this getter to compute the UI pills for mobile
    get activeFilterPills() {
        let pills = [];
        // this.filterTrack is updated automatically inside handleFilterChange
        if (this.filterTrack && this.filterTrack.length > 0) {
            this.filterTrack.forEach((filter, index) => {
                if (filter.values && filter.values.length > 0) {
                    pills.push({
                        id: `pill-${index}-${filter.placeholder}`,
                        category: filter.placeholder,
                        value: filter.values.join(', ') // Joins multiple selections with a comma
                    });
                }
            });
        }
        return pills;
    }

    /**
     * @description Helper function to check if a provided date string falls within the last 30 days.
     * Used for determining the "cooldown" status of rejected or disconnected invitations.
     * Prefixing with an underscore denotes this as a private utility method within the component.
     * 
     * @param {string} dateString - The date string to check.
     * @returns {boolean} True if the date is within the last 30 days, false otherwise.
     */
    _isWithinCooldownPeriod(dateString) {
        if (!dateString) return false;
        const date = new Date(dateString);
        const now = new Date();
        const thirtyDaysAgo = new Date(now.getTime() - (30 * 24 * 60 * 60 * 1000));
        return date >= thirtyDaysAgo && date <= now;
    }


    /**
 * Removes a single filter category when its badge "✕" is clicked,
 * syncs the child filter component, and re-fires the wires.
 */
    handleRemoveFilterPill(event) {
        event.stopPropagation();

        const placeholderToRemove = event.currentTarget.dataset.placeholder;
        if (!placeholderToRemove) return;

        // Drop the whole category from the tracked filters
        const updatedFilters = (this.filterTrack || [])
            .filter(f => f.placeholder !== placeholderToRemove);

        // User intentionally modified filters -> defaults won't reapply
        this._userHasModifiedFilters = true;

        this.isLoading = true;
        this.currentPage = 1;
        this.recordsToSkip = 0;

        this.filterTrack = [...updatedFilters];
        this.savedFilters = [...updatedFilters];

        // Filters changed -> bookmark goes back to unsaved state
        this.preferencesFound = false;

        // Sync child filter component(s) so the top pills/checkboxes update too
        const filterCmps = this.template.querySelectorAll('c-ham_alumni-search-filter-cmp');
        filterCmps.forEach(cmp => {
            if (updatedFilters.length > 0) {
                cmp.savedFilters = [...updatedFilters];
            } else if (typeof cmp.clearAllFiltersOnTabSwitch === 'function') {
                cmp.clearAllFiltersOnTabSwitch();
            }
        });

        // Let the new reactive params provision, then refresh
        setTimeout(() => {
            Promise.all([
                refreshApex(this.wiredAlumniCount),
                refreshApex(this.wiredAlumniResult)
            ])
                .then(() => this.applyTabFilter())
                .catch(error => console.error('Error removing filter pill:', error))
                .finally(() => { this.isLoading = false; });
        }, 0);
    }

  

}