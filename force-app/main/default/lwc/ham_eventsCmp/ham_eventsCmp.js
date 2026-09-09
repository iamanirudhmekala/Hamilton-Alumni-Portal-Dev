import { LightningElement, api, track, wire } from 'lwc';
import { refreshApex } from '@salesforce/apex';
//Import Lightning Message Service — tells the home page its Directory thumbnail is stale
import { publish, MessageContext } from 'lightning/messageService';
import THUMBNAIL_REFRESH_CHANNEL from '@salesforce/messageChannel/ham_HomeThumbnailRefresh__c';

import confirmrequest          from '@salesforce/apex/HAM_EventsController.confirmrequest';
import getEventDetails         from '@salesforce/apex/HAM_EventsController.getEventDetails';
import createTaskForRecording  from '@salesforce/apex/HAM_EventsController.createTaskForRecording';
import getEventAttendees       from '@salesforce/apex/HAM_EventsController.getEventAttendees';
import handleConnectionRequest from '@salesforce/apex/HAM_AlumniConnectionService.handleConnectionRequest';
import checkUserStatus         from '@salesforce/apex/HAM_AlumniConnectionService.checkUserStatus';
import getFilters              from '@salesforce/apex/HAM_EventsController.getFilterMetadataAndValues';

// STATIC RESOURCES
import HAM_ICONS              from '@salesforce/resourceUrl/HAM_Icons';
import siteDefaultImageResource from '@salesforce/resourceUrl/HAM_SiteFallbackImage';
import siteDefaultImageResourceKirkland from '@salesforce/resourceUrl/HAM_SiteFallbackImage_Kirkland';


// CUSTOM LABELS
import EVENTSTABHEADING       from '@salesforce/label/c.ham_EventsTabHeading';
import HOSTEVENTBUTTON        from '@salesforce/label/c.ham_HostEventButton';
import EVENTSMAINTAB1         from '@salesforce/label/c.ham_EventsMainTab1';
import EVENTSMAINTAB2         from '@salesforce/label/c.ham_EventsMainTab2';
import EVENTSMAINTAB1SUBTAB1  from '@salesforce/label/c.ham_EventsMainTab1SubTab1';
import EVENTSMAINTAB1SUBTAB2  from '@salesforce/label/c.ham_EventsMainTab1SubTab2';
import EVENTSMAINTAB2SUBTAB1  from '@salesforce/label/c.ham_EventsMainTab2SubTab1';
import EVENTSMAINTAB2SUBTAB2  from '@salesforce/label/c.ham_EventsMainTab2SubTab2';
import EVENTSHOSTTITLE        from '@salesforce/label/c.ham_EventsHostanEventTitle';
import EVENTSHOSTBTN1         from '@salesforce/label/c.ham_EventsHostBtn1';
import EVENTSHOSTBTN2         from '@salesforce/label/c.ham_EventsHostBtn2';
import MODIFYREGISTRATION     from '@salesforce/label/c.ham_EventsModifyRegistration';
import REGISTEREVENT          from '@salesforce/label/c.ham_EventsRegister';
import REQUESTRECORDING       from '@salesforce/label/c.ham_EventsRequestRecording';
import NOEVENTS               from '@salesforce/label/c.ham_NoEvents';
import CONNECTIONSATTENDING   from '@salesforce/label/c.ham_connectionAttending';
import CONNECTIONSATTENDED    from '@salesforce/label/c.ham_connectionsAttended';
import SHOWALLATTENDEES       from '@salesforce/label/c.ham_showAllAttendees';
import NOEVENTATTENDEES       from '@salesforce/label/c.ham_NoEventAttendees';
import RECORDINGREQUESTSENT   from '@salesforce/label/c.ham_taskRecordingRequestSent';
import RECORDINGREQUESTED     from '@salesforce/label/c.ham_recordingRequested';
import HOSTANEVENTCONFIRMREQ     from '@salesforce/label/c.ham_hostanEventConfirmReq';
import UPCOMINGNOCONNECTIONS     from '@salesforce/label/c.ham_upcoming_noConnections';
import PASTNOCONNECTIONS     from '@salesforce/label/c.ham_past_noConnections';
import PastEventsHelpText from '@salesforce/label/c.ham_pastEvents_helpText';
import VolunteerInfoTextEmail from '@salesforce/label/c.HAM_volOppInfoText_Email';
import NECROLOGYHELPTEXT from '@salesforce/label/c.ham_necrologyHelpText';
import NECROLOGYLINK from '@salesforce/label/c.ham_necrologyLink';
import NECROLOGYTITLE from '@salesforce/label/c.ham_necrologyTitle';

// ─── Confirmation-modal labels ───
import ActionSRHeader           from '@salesforce/label/c.HAM_Personal_Mess';
import ActionSRPrimaryBtn       from '@salesforce/label/c.HAM_Primary_Btn';
import ActionSRSecondaryBtn     from '@salesforce/label/c.HAM_Secondary_Button';
import ActionRBMHeader          from '@salesforce/label/c.HAM_Remove_Bookmark_Header';
import ActionRBMPrimaryBtn      from '@salesforce/label/c.HAM_Primary_Button_RBM';
import ActionRCHeader           from '@salesforce/label/c.HAM_Remove_Conn';
import ActionCRHeader           from '@salesforce/label/c.HAM_Cancel_Request_Header';
import ActionRCSecondaryBtn     from '@salesforce/label/c.HAM_Secondry_Button';
import InActiveUserMessage      from '@salesforce/label/c.ham_inactiveUserMessage';

// ─── Toast labels ───
import ToastMessageReqSend          from '@salesforce/label/c.ham_ToastMessage_ReqSend';
import ToastMessageCancelReq        from '@salesforce/label/c.ham_ToastMessage_CancelReq';
import ToastMessageBookmarked       from '@salesforce/label/c.ham_ToastMessage_Bookmarked';
import ToastMessageRemoveBookmarked from '@salesforce/label/c.ham_ToastMessage_Removed_Bookmarked';
import ToastMessageFavorite         from '@salesforce/label/c.ham_ToastMessage_Favorite';
import ToastMessageRemoveFavorite   from '@salesforce/label/c.ham_ToastMessage_RemoveFavorite';

// ─── Action-types ───
const ACTIONS = {
    SEND_REQUEST      : 'Send Request',
    CANCEL_REQUEST    : 'Cancel Request',
    REMOVE_CONNECTION : 'Remove Connection',
    BOOKMARK          : 'Bookmark',
    REMOVE_BOOKMARK   : 'Remove Bookmark',
    FAVORITE          : 'Favorite',
    REMOVE_FAVORITE   : 'Remove Favorite'
};
import SENDREQUEST from '@salesforce/label/c.HAM_Send_Request';
import REMOVECONNECTION from '@salesforce/label/c.HAM_Remove_Connection';
import CANCELREQUEST from '@salesforce/label/c.HAM_Cancel_Request';
import SENDREQUESTHOVERTEXT from '@salesforce/label/c.HAM_sendRequestHoverText';
import CANCELREQUESTHOVERTEXT from '@salesforce/label/c.HAM_cancelRequestHoverText';
import REMOVECONNECTIONHOVERTEXT from '@salesforce/label/c.HAM_removeConnectionHoverText';
import VIEWPROFILEHOVERTEXT from '@salesforce/label/c.HAM_viewProfileHoverText';

const stripHtml = (html) => {
    if (!html) return '';
    return html
        .replace(/<[^>]*>/g, ' ')   // remove all tags
        .replace(/&nbsp;/gi, ' ')   // decode common HTML entities
        .replace(/&amp;/gi,  '&')
        .replace(/&lt;/gi,   '<')
        .replace(/&gt;/gi,   '>')
        .replace(/&quot;/gi, '"')
        .replace(/&#39;/gi,  "'")
        .replace(/\s+/g,     ' ')   // collapse multiple spaces
        .trim();
};

export default class Ham_eventsCmp extends LightningElement {

    @wire(MessageContext) messageContext;

    @api userContactId;
    @api label       = {};
    @api mainResource = {};
    @api isOverride = false;
    isShowSuccessMsg = false;

    // ── Tab state ────────────────────────────────────────────────────────────
    activeMainTab = EVENTSMAINTAB1;
    activeSubTab  = EVENTSMAINTAB1SUBTAB1;

    // ── Search / filter ──────────────────────────────────────────────────────
    searchKey             = '';
    searchKeyToApex       = '';
    @track filters        = [];
    originalValueset      = {};
    selectedFiltersPayload = [];

    // ── Events data ──────────────────────────────────────────────────────────
    wiredEventDetails;
    isLoading = false;
    @track events = [];
    totalRecordsForChild = null;

    // ── Pagination (OFFSET-based — next, prev, direct jump) ─────────
    // recordsToSkip = (currentPage - 1) * pageSize, computed by ham_PaginationUtil
    // and delivered via the pagechange event.
    @track pageSizeForChild;
    currentPage   = 1;
    recordsToSkip = 0;

    // ── Modal / toast state ──────────────────────────────────────────────────
    isHostanEvent       = false;
    @track showCustomToast    = false;
    toastTitle;
    toastVariant;
    toastDuration;
    toastMessage;
    @track showAttendeesModal = false;
    @track selectedAttendees  = [];
    @track selectedEventName  = '';
    modalType             = '';
    showTaskConfirmation  = false;
    localAttendeeState = {};
    showProfileOverview        = false;
    selectedAttendeeContactId  = null;

    // ── Attendee action confirmation modal ───────────────────────────────────
    showAttendeeActionModal  = false;
    pendingAttendeeId        = null;
    pendingActionType        = null;
    attendeeModalHeader      = '';
    attendeeModalPrimary     = '';
    attendeeModalSecondary   = 'Cancel';
    isAttendeeModalRequest   = false;   // true only for Send Request (shows textarea)
    attendeePersonalizedMsg  = '';
    isAttendeeModalInactive  = false;   // true when the linked user's SF User is inactive

    // ── Attendee modal — server-side pagination + search ─────────────────────
    // Context remembered so loadAttendeesPage() can re-call Apex on page turn / search.
    attendeeEventId      = null;   // eventId passed to getEventAttendees
    attendeeObjectApi    = null;   // objectApi passed to getEventAttendees
    attendeeCurrentPage  = 1;
    attendeePageSize     = 6;      // fixed at 6 on both desktop and mobile
    attendeeTotalRecords = 0;
    attendeeSearchKey    = '';
    loggedInUserHasConnectionPrivacy = false;

    // ── Responsive ───────────────────────────────────────────────────────────
    @track screenWidth = window.innerWidth;

    // ── Icons ────────────────────────────────────────────────────────────────
    hamIcons           = HAM_ICONS;
    defaultFallbackImage = siteDefaultImageResource;
    defaultFallbackImageKirkland = siteDefaultImageResourceKirkland;

    icons = {
        moreFiltersIcon       : this.hamIcons + '/more-filters.png',
        bookmarkfill          : this.hamIcons + '/bookmark-fill.png',
        bookmarkoutline       : this.hamIcons + '/bookmark-outline.png',
        bookmarkfillGreen     : this.hamIcons + '/bookmark-fill-green.png',
        bookmarkoutlineGreen  : this.hamIcons + '/bookmark-outline-green.png',
        dropDownOuter         : this.hamIcons + '/drop-down-outer.png',
        dropDownInner         : this.hamIcons + '/drop-down-inner.png',
        favIconEnabled        : this.hamIcons + '/fav-fill.png',
        favIconDisabled       : this.hamIcons + '/fav-outline.png',
        favIconEnabledGreen   : this.hamIcons + '/fav-fill-green.png',
        favIconDisabledGreen  : this.hamIcons + '/fav-outline-green.png',
        confirmedIcon   : this.hamIcons + '/vol-popup-icon.png',
        fallbackAvatar  : this.hamIcons + '/profile_big.png',
        location  : this.hamIcons + '/location.png',
        clock  : this.hamIcons + '/clock.png',
        cross  : this.hamIcons + '/cross-circle.png',
        tick  : this.hamIcons + '/tick-circle.png',
        tickGreen  : this.hamIcons + '/tick-circle-green.png',
        circle  : this.hamIcons + '/only-circle.png',
    };

    // Social media icons passed to the profile overview component
    profileImages = {
        linkedinIcon : HAM_ICONS + '/linkedIn_POV.png',
        lnstaIcon    : HAM_ICONS + '/instagram_POV.png',
        faceIcon     : HAM_ICONS + '/facebook_POV.png',
        twitterIcon  : HAM_ICONS + '/twitter_POV.png',
    };

    labels = {
        tabHeading           : EVENTSTABHEADING,
        hostEventButton      : HOSTEVENTBUTTON,
        upcomingEvents       : EVENTSMAINTAB1,
        pastEvents           : EVENTSMAINTAB2,
        myUpcomingEvents     : EVENTSMAINTAB1SUBTAB1,
        otherUpcomingEvents  : EVENTSMAINTAB1SUBTAB2,
        registeredPastEvents : EVENTSMAINTAB2SUBTAB1,
        nonRegisteredPastEvents : EVENTSMAINTAB2SUBTAB2,
        hostEventTitle       : EVENTSHOSTTITLE,
        hostEventBtn1        : EVENTSHOSTBTN1,
        hostEventBtn2        : EVENTSHOSTBTN2,
        modifyRegistration   : MODIFYREGISTRATION,
        registerEvent        : REGISTEREVENT,
        requestRecording     : REQUESTRECORDING,
        noEvents             : NOEVENTS,
        connectionsAttending : CONNECTIONSATTENDING,
        connectionsAttended  : CONNECTIONSATTENDED,
        showAllAttendees     : SHOWALLATTENDEES,
        noEventAttendees     : NOEVENTATTENDEES,
        recordingRequestSent : RECORDINGREQUESTSENT,
        recordingRequested   : RECORDINGREQUESTED,
        hostanEventConfirmReq : HOSTANEVENTCONFIRMREQ,
        upcomingNoConnections : UPCOMINGNOCONNECTIONS,
        pastNoConnections : PASTNOCONNECTIONS,
        sendRequest : SENDREQUEST,
        cancelRequest : CANCELREQUEST,
        removeConnection : REMOVECONNECTION,
        sendRequestHoverText : SENDREQUESTHOVERTEXT,
        cancelRequestHoverText : CANCELREQUESTHOVERTEXT,
        removeConnectionHoverText : REMOVECONNECTIONHOVERTEXT,
        viewProfileHoverText : VIEWPROFILEHOVERTEXT,

        // Confirmation-modal labels
        actionSRHeader       : ActionSRHeader,
        actionSRPrimaryBtn   : ActionSRPrimaryBtn,
        actionSRSecondaryBtn : ActionSRSecondaryBtn,
        actionRBMHeader      : ActionRBMHeader,
        actionRBMPrimaryBtn  : ActionRBMPrimaryBtn,
        actionRCHeader       : ActionRCHeader,
        actionCRHeader       : ActionCRHeader,
        actionRCSecondaryBtn : ActionRCSecondaryBtn,
        inActiveUserMessage  : InActiveUserMessage,

        // Toast labels
        toastMessageReqSend         : ToastMessageReqSend,
        toastMessageCancelReq       : ToastMessageCancelReq,
        toastMessageBookmarked      : ToastMessageBookmarked,
        toastMesgRemBookmarked      : ToastMessageRemoveBookmarked,
        toastMessageFavorite        : ToastMessageFavorite,
        toastMessageRemoveFavorite  : ToastMessageRemoveFavorite,

        //Labels for Help text on past events
        pastEventsHelpText : PastEventsHelpText,
        volunteerInfoTextEmail : VolunteerInfoTextEmail,

        //Necrology labels
        necrologyHelpText : NECROLOGYHELPTEXT,
        necrologyLink : NECROLOGYLINK,
        necrologyTitle : NECROLOGYTITLE
    };

    // ─────────────────────────────────────────────────────────────────────────
    // LIFECYCLE
    // ─────────────────────────────────────────────────────────────────────────

    connectedCallback() {
        this.pageSizeForChild = this.isMobileView ? 3 : 6;
        this.loadFilters();

        this.handleOutsideClick = this.handleOutsideClick.bind(this);
        document.addEventListener('click', this.handleOutsideClick);

        this.handleResize = this.handleResize.bind(this);
        window.addEventListener('resize', this.handleResize);
    }

    disconnectedCallback() {
        document.removeEventListener('click', this.handleOutsideClick);
        window.removeEventListener('resize', this.handleResize);
    }

    // ─────────────────────────────────────────────────────────────────────────
    // RESPONSIVE
    // ─────────────────────────────────────────────────────────────────────────

    get isMobileView()  { return this.screenWidth <= 1024; }
    get isDesktopView() { return this.screenWidth > 1024; }

    get wrapperClass() {
        return this.isOverride ? 'event-content kirkland-override' : 'event-content';
    }

    handleResize() {
        this.screenWidth  = window.innerWidth;
        this.pageSizeForChild = this.isMobileView ? 3 : 6;
    }

    // Returns the Kirkland fallback image when in override mode, otherwise the standard one.
    get defaultImageUrl() {
        return this.isOverride ? this.defaultFallbackImageKirkland : this.defaultFallbackImage;
    }

    // ─────────────────────────────────────────────────────────────────────────
    // WIRE — getEventDetails
    // No cursor params — OFFSET-based pagination handles all navigation.
    // ─────────────────────────────────────────────────────────────────────────

    @wire(getEventDetails, {
        constituentId : '$userContactId',
        mainTab       : '$activeMainTab',
        subTab        : '$activeSubTab',
        searchKey     : '$searchKeyToApex',
        pageSize      : '$pageSizeForChild',
        recordsToSkip : '$recordsToSkip',
        filters       : '$selectedFiltersPayload'
    })
    wiredEvents(result) {
        
        this.isLoading        = true;
        this.wiredEventDetails = result;
        const { data, error } = result;

        if (data) {
            this.totalRecordsForChild = data.totalEventsCount || null;

            this.events = (data.events || []).map(event => {

                // Apex already sends sorted attendees by preference at a max of 3 records.
                // So here we are just building a dynamic style for the profile pic stack.

                const previewList = event.attendees || [];
                const avatarWidth = 28; 
                const overlap     = 14;
                // total width = first image width + (remaining images × overlap amount)
                const avatarsWidth = previewList.length > 0
                    ? avatarWidth + (previewList.length - 1) * overlap
                    : 0;

                const attendeesPreview = previewList.map((att, index) => ({
                    ...att,
                    style: `left:${index * 14}px; z-index:${10 - index};`
                }));

                // Button label
                let buttonLabel = null;
                if (event.allowModifyEvent) {
                    buttonLabel = this.labels.modifyRegistration;
                } else if (event.allowRegisterEvent) {
                    buttonLabel = this.labels.registerEvent;
                } else if (event.showRequestRecording && event.isVirtual) {
                    buttonLabel = event.disableRecordingRequest
                        ? this.labels.recordingRequested
                        : this.labels.requestRecording;
                }

                // Button CSS class
                const buttonClass = event.disableRecordingRequest
                    ? 'event-action-btn disabled-btn'
                    : 'event-action-btn';

                const totalConnectionCount = parseInt(event.totalConnectionCount || 0, 10);
                let attendeeText = '';
                if (totalConnectionCount === 0) {
                    attendeeText = this.activeMainTab === this.labels.upcomingEvents
                        ? this.labels.upcomingNoConnections
                        : this.labels.pastNoConnections;
                } else if (totalConnectionCount > 0 && totalConnectionCount <= 3) {
                    attendeeText = event.isPastEvent ? this.labels.connectionsAttended : this.labels.connectionsAttending;
                } else {
                    attendeeText = event.isPastEvent ? `+${totalConnectionCount - 3} ${this.labels.connectionsAttended}` :
                                                       `+${totalConnectionCount - 3} ${this.labels.connectionsAttending}`;
                }

                return {
                    ...event,
                    name            : stripHtml(event.name),
                    description     : stripHtml(event.description),
                    attendees       : event.attendees || [],
                    attendeesPreview,
                    avatarsContainerStyle: `width:${avatarsWidth}px;`,
                    buttonLabel,
                    buttonClass,
                    attendeeText
                };
            });

            //console.log('Events@ ', JSON.stringify(this.events, null, 2));
            this.isLoading = false;

        } else if (error) {
            console.log('Error in events wire:', error);
            this.isLoading = false;
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // PAGINATION
    // ham_PaginationUtil fires pagechange with { currentPage, recordsToSkip, pageSize }
    // recordsToSkip = (currentPage - 1) * pageSize — used directly as SOQL OFFSET.
    // ─────────────────────────────────────────────────────────────────────────

    handlePageChange(event) {
        this.isLoading    = true;
        this.currentPage  = event.detail.currentPage;
        this.recordsToSkip = event.detail.recordsToSkip;
    }

    // ─────────────────────────────────────────────────────────────────────────
    // TAB HANDLERS — reset pagination on tab change
    // ─────────────────────────────────────────────────────────────────────────

    handleMainTabClick(event) {
        this.isLoading     = true;
        const tab          = event.currentTarget.dataset.tab;
        this.activeMainTab = tab;
        this.currentPage   = 1;
        this.recordsToSkip = 0;
        this.searchKey = '';
        this.searchKeyToApex = '';
        this.resetFilters();

        if (this.activeMainTab === this.labels.upcomingEvents) {
            this.activeSubTab = this.labels.myUpcomingEvents;
        } else {
            this.activeSubTab = this.labels.registeredPastEvents;
        }
    }

    handleSubTabClick(event) {
        this.isLoading     = true;
        const subTab       = event.currentTarget.dataset.subtab;
        this.activeSubTab  = subTab;
        this.currentPage   = 1;
        this.recordsToSkip = 0;
        this.searchKey = '';
        this.searchKeyToApex = '';
        this.resetFilters();
    }

    // ─────────────────────────────────────────────────────────────────────────
    // TAB CLASS GETTERS
    // ─────────────────────────────────────────────────────────────────────────

    get tabStateMessage() {
        if (this.events && this.events.length > 0) return null;

        if (this.activeMainTab === this.labels.upcomingEvents) {
            if (this.activeSubTab === this.labels.myUpcomingEvents)    return 'No Registered Upcoming Events';
            if (this.activeSubTab === this.labels.otherUpcomingEvents) return 'No Non Registered Upcoming Events';
        } else if (this.activeMainTab === this.labels.pastEvents) {
            if (this.activeSubTab === this.labels.registeredPastEvents)    return 'No Registered Past Events';
            if (this.activeSubTab === this.labels.nonRegisteredPastEvents) return 'No Non Registered Past Events';
        }
        return 'No Events';
    }

    get subtabsClass(){ 
        return (this.activeMainTab === this.labels.pastEvents && this.isMobileView) ? 'subtabs subtabs-stacked' : 'subtabs'; 
    }

    get isUpcomingTab(){ 
        return this.activeMainTab === this.labels.upcomingEvents; 
    }

    get isPastTab(){ 
        return this.activeMainTab === this.labels.pastEvents; 
    }
    
    get upcomingTabClass(){ 
        return this.activeMainTab === this.labels.upcomingEvents ? 'tab active-tab' : 'tab inactive-tab'; 
    }

    get pastTabClass(){ 
        return this.activeMainTab === this.labels.pastEvents     ? 'tab active-tab' : 'tab inactive-tab'; 
    }

    get myUpcomingClass(){ 
        return this.activeSubTab === this.labels.myUpcomingEvents     ? 'pill active-pill' : 'pill inactive-pill'; 
    }

    get otherUpcomingClass(){ 
        return this.activeSubTab === this.labels.otherUpcomingEvents  ? 'pill active-pill' : 'pill inactive-pill'; 
    }

    get registeredPastClass(){ 
        return this.activeSubTab === this.labels.registeredPastEvents ? 'pill active-pill' : 'pill inactive-pill'; 
    }

    get nonRegisteredPastClass(){ 
        return this.activeSubTab === this.labels.nonRegisteredPastEvents ? 'pill active-pill' : 'pill inactive-pill'; 
    }

    get myUpcomingIcon() { 
        return this.activeSubTab === this.labels.myUpcomingEvents && this.isOverride ? this.icons.tickGreen : this.activeSubTab === this.labels.myUpcomingEvents ? this.icons.tick : this.icons.circle; 
    }

    get otherUpcomingIcon(){ 
        return this.activeSubTab === this.labels.otherUpcomingEvents && this.isOverride ? this.icons.tickGreen :this.activeSubTab === this.labels.otherUpcomingEvents ? this.icons.tick : this.icons.circle; 
    }

    get registeredPastIcon(){ 
        return this.activeSubTab === this.labels.registeredPastEvents && this.isOverride ? this.icons.tickGreen : this.activeSubTab === this.labels.registeredPastEvents ? this.icons.tick : this.icons.circle; 
    }

    get nonRegisteredPastIcon(){ 
        return this.activeSubTab === this.labels.nonRegisteredPastEvents && this.isOverride ? this.icons.tickGreen : this.activeSubTab === this.labels.nonRegisteredPastEvents ? this.icons.tick : this.icons.circle; 
    }

    get eventsExist(){ 
        return this.events && this.events.length > 0; 
    }

    get eventsDoesntExist(){ 
        return !this.eventsExist; 
    }

    get emailHref() {
        return 'mailto:' + (this.labels.volunteerInfoTextEmail || '');
    }

    // ─────────────────────────────────────────────────────────────────────────
    // PLACEHOLDER VALUES ON SEARCH
    // ─────────────────────────────────────────────────────────────────────────

    get searchPlaceHolder() {
        if (this.activeSubTab === this.labels.myUpcomingEvents){
            return 'Search Upcoming Registered Events...';
        }

        if (this.activeSubTab === this.labels.otherUpcomingEvents){     
            return 'Search Upcoming Non Registered Events...';
        }

        if (this.activeSubTab === this.labels.registeredPastEvents){
            return 'Search Registered Past Events...';
        }

        if (this.activeSubTab === this.labels.nonRegisteredPastEvents){
            return 'Search Non Registered Past Events...';
        }

        return 'Search Events...';
    }

    // ─────────────────────────────────────────────────────────────────────────
    // SEARCH
    // ─────────────────────────────────────────────────────────────────────────

    handleSearchInput(event)   { 
        this.searchKey = event.target.value;
        if (!this.searchKey.trim()) {
            this.currentPage   = 1;
            this.recordsToSkip = 0;
            this.searchKeyToApex = '';
        }
    }
    handleSearchKeydown(event) { 
        if (event.key === 'Enter') this.handleSearchClick(); 
    }

    handleSearchClick(){ 
        this.currentPage   = 1;
        this.recordsToSkip = 0;
        this.searchKeyToApex = this.searchKey || ''; 
    }

    // ─────────────────────────────────────────────────────────────────────────
    // FILTERS
    // ─────────────────────────────────────────────────────────────────────────

    handleOutsideClick(event) {
        const isInside = this.template.contains(event.target);
        if (!isInside) {
            this.filters = this.filters.map(f => ({ ...f, isOpen: false }));
        }
    }

    loadFilters() {
        getFilters()
            .then(result => {
                this.originalValueset = result.reduce((acc, f) => {
                    acc[String(f.order)] = Array.isArray(f.values) ? [...f.values] : [];
                    return acc;
                }, {});

                this.filters = result.map(f => ({
                    ...f,
                    values        : this.sortFilterValues(f.placeholder, f.values || []).map(v => ({ label: v, checked: false })),
                    selectedValues: [],
                    hasSelectedValues: false,
                    searchKey     : '',
                    displayValue  : f.placeholder,
                    hoverText     : f.placeholder,
                    isOpen        : false
                }));
            })
            .catch(error => { console.log('Load Filters error: ', error); });
    }

    sortFilterValues(placeholder, values) {
        return values.slice().sort((a, b) => a.localeCompare(b));
    }

    toggleDropdown(event) {
        event.stopPropagation();
        const order = event.currentTarget.dataset.order;

        this.filters = this.filters.map(f => {
            const isSame = String(f.order) === String(order);
            if (isSame && !f.isOpen) {
                const sorted = this.sortFilterValues(f.placeholder, this.originalValueset[String(f.order)] || []);
                return { ...f, isOpen: true, searchKey: '', values: sorted.map(v => ({ label: v, checked: f.selectedValues.includes(v) })) };
            }
            return { ...f, isOpen: false, searchKey: '' };
        });

        //This piece of code ensure the scrolability on filters is fixed under the filters and doesn't let to overlap on site's header or footer
        requestAnimationFrame(() => {
            const pill     = this.template.querySelector(`[data-order="${order}"] .pill-input`);
            const dropdown = this.template.querySelector(`[data-droporder="${order}"]`);
            if (pill && dropdown) {
                const rect = pill.getBoundingClientRect();
                dropdown.style.top   = (rect.bottom + 6) + 'px';
                dropdown.style.left  = rect.left + 'px';
                dropdown.style.width = rect.width + 'px';
            }
        });
    }

    handleClearFilter(event) {
        event.stopPropagation();
        const order = event.target.dataset.order;
        this.filters = this.filters.map(f => {
            if (order && String(f.order) !== String(order)) return f;
            const sorted = this.sortFilterValues(f.placeholder, this.originalValueset[String(f.order)] || []);
            return { ...f, values: sorted.map(
                v => ({ label: v, checked: false })), 
                selectedValues: [], 
                hasSelectedValues: false, 
                searchKey: '', 
                displayValue: f.placeholder, 
                hoverText: f.placeholder, 
                isOpen: false };
        });
        this.updateSelectedFiltersPayload();
    }

    resetFilters() {
        this.filters = this.filters.map(f => {
            const sorted = this.sortFilterValues(f.placeholder, this.originalValueset[String(f.order)] || []);
            return {
                ...f,
                values           : sorted.map(v => ({ label: v, checked: false })),
                selectedValues   : [],
                hasSelectedValues: false,
                searchKey        : '',
                displayValue     : f.placeholder,
                hoverText        : f.placeholder,
                isOpen           : false
            };
        });
        this.selectedFiltersPayload = [];
    }

    handleDropdownSearch(event) {
        event.stopPropagation();
        const order      = event.target.dataset.order;
        const searchTerm = event.target.value;
        const lowerTerm  = searchTerm.toLowerCase();

        this.filters = this.filters.map(f => {
            if (String(f.order) !== String(order)) return f;
            const original = this.originalValueset[String(order)] || [];
            const filtered = searchTerm ? original.filter(v => v.toLowerCase().includes(lowerTerm)) : original;
            const sorted   = this.sortFilterValues(f.placeholder, filtered);
            return { 
                ...f, 
                searchKey: searchTerm, 
                values: sorted.map(v => 
                    ({ label: v, checked: f.selectedValues.includes(v) })
                ) 
            };
        });
    }

    stopPropagation(event) { 
        event.stopPropagation(); 
    }

    handleCheckboxToggle(event) {
        event.stopPropagation();
        const order   = event.target.dataset.order;
        const label   = event.target.dataset.value;
        const checked = event.target.checked;

        this.filters = this.filters.map(f => {
            if (String(f.order) !== String(order)) return f;
            let selectedValues = [...(f.selectedValues || [])];
            if (checked) { if (!selectedValues.includes(label)) selectedValues.push(label); }
            else         { selectedValues = selectedValues.filter(v => v !== label); }
            return {
                ...f,
                values          : f.values.map(v => ({ ...v, checked: selectedValues.includes(v.label) })),
                selectedValues,
                hasSelectedValues: selectedValues.length > 0,
                hoverText       : selectedValues.join(', '),
                displayValue    : selectedValues.length ? `${f.placeholder} (${selectedValues.length})` : f.placeholder,
                isOpen          : true
            };
        });
        this.updateSelectedFiltersPayload();
    }

    updateSelectedFiltersPayload() {
        this.selectedFiltersPayload = this.filters
            .filter(f => f.selectedValues.length)
            .map(f => ({ 
                fieldApiName: f.fieldApiName, 
                placeholder: f.placeholder, 
                values: f.selectedValues 
            }));
    }

    // ─────────────────────────────────────────────────────────────────────────
    // HOST AN EVENT
    // ─────────────────────────────────────────────────────────────────────────

    handleHostanEvent() { this.isHostanEvent = true; }
    handleCloseModal()  { 
        this.isHostanEvent = false; 
       
    }

    handleConfRequest() {
        confirmrequest({ contactId: this.userContactId })
            .then(result  => { 
                this.isHostanEvent = false;
                this.isShowSuccessMsg = true;
                
                })
            .catch(error  => { console.error('FULL ERROR:', JSON.stringify(error)); });
    }

    // ─────────────────────────────────────────────────────────────────────────
    // EVENT ACTION (register / modify / request recording)
    // ─────────────────────────────────────────────────────────────────────────

    handleEventAction(event) {
        const url         = event.currentTarget.dataset.url;
        const buttonLabel = event.currentTarget.dataset.label;
        const evtId       = event.currentTarget.dataset.eventid;
        const evtObjectApi = event.currentTarget.dataset.eventobjectapi;

        if (buttonLabel === this.labels.modifyRegistration || buttonLabel === this.labels.registerEvent) {
            if (url) window.open(url, '_blank');
        } else if (buttonLabel === this.labels.requestRecording) {
            this.createTask(evtId, evtObjectApi);
        }
    }

    createTask(evtId, evtObjectApi) {
        this.isLoading = true;
        createTaskForRecording({ eventId: evtId, constituentId: this.userContactId, objectApi: evtObjectApi })
            .then(result => {
                if (result.includes('Success')) {
                    refreshApex(this.wiredEventDetails);
                    this.showTaskConfirmation = true;
                } else if (result.includes('Error')) {
                    this.showToast(5000, 'Error', 'Unexpected error occurred. Please contact admin.', 'error');
                    console.log('Error creating task - ', result);
                }
            })
            .catch(error => {
                this.showToast(5000, 'Error', 'Unexpected error occurred. Please contact admin.', 'error');
                console.log('Error creating task:', JSON.stringify(error));
            })
            .finally(() => { this.isLoading = false; });
    }

    handleCloseTaskConfirmation() { 
        this.showTaskConfirmation = false; 
    }

    handleCloseHostanEvntConfirmation() { 
        this.isShowSuccessMsg = false; 
    }
    // ─────────────────────────────────────────────────────────────────────────
    // ATTENDEES MODAL
    // Two entry points:
    //   1) Profile pic stack  → handleAttendeesClick → shows connections only
    //   2) Show All Attendees → handleShowAllAttendees → imperative Apex call, all attendees, sorted server-side
    // ─────────────────────────────────────────────────────────────────────────

    /**
     * Profile pic stack click — connections-only modal.
     * Sets context and delegates to the shared loader.
     */
    handleAttendeesClick(event) {
        const evtId        = event.currentTarget.dataset.eventid;
        const selectedEvent = this.events.find(evt => evt.eventId === evtId);
        const evtObjectApi  = selectedEvent ? selectedEvent.eventObjectAPI : null;

        if (!evtObjectApi) return;

        this.modalType         = 'connections';
        this.selectedEventName = selectedEvent.name;
        this.attendeeEventId   = evtId;
        this.attendeeObjectApi = evtObjectApi;
        this.attendeeCurrentPage  = 1;
        this.attendeeSearchKey    = '';
        this.loadAttendeesPage();
    }

    /**
     * "Show All Attendees" button — all-attendees modal.
     * Sets context and delegates to the shared loader.
     */
    handleShowAllAttendees(event) {
        const evtId       = event.currentTarget.dataset.eventid;
        const evtObjectApi = event.currentTarget.dataset.eventobjectapi;

        this.modalType         = 'all';
        this.attendeeEventId   = evtId;
        this.attendeeObjectApi = evtObjectApi;
        this.attendeeCurrentPage  = 1;
        this.attendeeSearchKey    = '';
        this.loadAttendeesPage();
    }

    /**
     * Single Apex call for both modal types, all page turns, and all searches.
     * Called by: handleAttendeesClick, handleShowAllAttendees,
     *            handleAttendeePageChange, handleAttendeeSearch.
     */
    loadAttendeesPage() {
        this.isLoading = true;

        getEventAttendees({
            eventId        : this.attendeeEventId,
            ConstituentId  : this.userContactId,
            objectApi      : this.attendeeObjectApi,
            connectionsOnly: this.modalType === 'connections',
            searchKey      : this.attendeeSearchKey,
            pageSize       : this.attendeePageSize,
            recordsToSkip  : (this.attendeeCurrentPage - 1) * this.attendeePageSize
        })
        .then(result => {
            this.loggedInUserHasConnectionPrivacy = result.loggedInUserHasConnectionPrivacy || false;

            // Map raw Apex records to attendee objects
            const attendees = (result.eventAttendees || []).map(att => {
                const localOverride = this.localAttendeeState[att.attendeeId];
                const isBookmarked  = localOverride?.isBookmarked ?? att.isBookmarked;
                const isFavorite    = localOverride?.isFavorite   ?? att.isFavorite;
                const isSelf        = att.attendeeId === this.userContactId;

                return {
                    ...att,
                    isBookmarked,
                    isFavorite,
                    isSelf,
                    attendeeRowClass : isSelf ? 'attendee-row attendee-row--self' : 'attendee-row',
                    profileRowTitle  : isSelf ? '' : this.labels.viewProfileHoverText,
                    bookmarkIcon     : isBookmarked
                                    ? (this.isOverride ? this.icons.bookmarkfillGreen    : this.icons.bookmarkfill)
                                    : (this.isOverride ? this.icons.bookmarkoutlineGreen : this.icons.bookmarkoutline),
                    bookmarkTitle    : `Bookmark ${att.name}`,
                    favoriteIcon     : att.isConnected && isFavorite
                                    ? (this.isOverride ? this.icons.favIconEnabledGreen  : this.icons.favIconEnabled)
                                    : (this.isOverride ? this.icons.favIconDisabledGreen : this.icons.favIconDisabled),
                    favoriteIconTitle: `Favourite ${att.name}`,
                    ...this.getConnectionButtonProps(att)
                };
            });

            // Exclude the logged-in user from the attendee list. we already exclude this in apex, but this is just for safety.
            const visibleAttendees = attendees.filter(att => !att.isSelf);

            this.attendeeTotalRecords = result.totalAttendeeCount || 0;
            this.selectedAttendees    = visibleAttendees;
            this.showAttendeesModal   = true;
        })
        .catch(error => {
            const msg = this.modalType === 'connections'
                ? 'Failed to load connections.'
                : 'Failed to load attendees.';
            this.showToast(5000, 'Error', msg, 'error');
            console.error('loadAttendeesPage error:', JSON.stringify(error));
        })
        .finally(() => { this.isLoading = false; });
    }

    closeAttendeesModal() {
        this.showAttendeesModal   = false;
        this.attendeeCurrentPage  = 1;
        this.attendeeSearchKey    = '';
        this.attendeeTotalRecords = 0;
    }

    get modalHeading() { 
        return this.modalType === 'all' ? 'Attendees' : 'Connections Attending'; 
    }

    // ── Attendee modal search ─────────────────────────────────────────────────

    get attendeeSearchPlaceholder() {
        if( this.modalType === 'connections' && this.activeMainTab === this.labels.pastEvents){
            return 'Search your connections who attended this event...';
        }else if(this.modalType === 'connections' && this.activeMainTab !== this.labels.pastEvents){
            return 'Search your connections who are attending this event...';
        }else{
            return 'Search attendees...';
        }
    }

    handleAttendeeSearchInput(event) {
        this.attendeeSearchKey = event.target.value;
        if (!this.attendeeSearchKey.trim()) {
            this.handleAttendeeSearch();
        }
    }

    handleAttendeeSearchKeydown(event) {
        if (event.key === 'Enter') this.handleAttendeeSearch();
    }

    /** Fires the Apex call: resets to page 1 so the count/results stay consistent. */
    handleAttendeeSearch() {
        this.attendeeCurrentPage = 1;
        this.loadAttendeesPage();
    }

    // ── Attendee modal pagination ─────────────────────────────────────────────

    /** Fired by ham_PaginationUtil onpagechange — re-calls Apex for the new page. */
    handleAttendeePageChange(event) {
        this.attendeeCurrentPage = event.detail.currentPage;
        this.loadAttendeesPage();
    }

    handleViewProfile(event) {
        const attendeeId = event.currentTarget.dataset.id;

        if (attendeeId === this.userContactId){
            return;
        }

        this.selectedAttendeeContactId = attendeeId;
        this.showProfileOverview = true;
    }

    handleProfileOverviewBack() {
        this.showProfileOverview = false;
        this.selectedAttendeeContactId = null;
    }

    // ─────────────────────────────────────────────────────────────────────────
    // CONNECTION BUTTON HELPER
    // Derives label, CSS class, and disabled state from attendee data.
    //
    //  Send Request (active)   — isConnected=false, isRejected=false,
    //                            status not "Disconnect"/"Rejected"
    //  Cancel Request          — isConnected=false, status="Request sent"
    //  Remove Connection       — isConnected=true
    //  Send Request (disabled) — isRejected=true
    // ─────────────────────────────────────────────────────────────────────────
    getConnectionButtonProps(att) {
        // Deceased alumni: connection actions are replaced by a Necrology button.
        if (att.isDeceased) {
            return {
                connectionBtnLabel    : this.labels.necrologyTitle,
                connectionBtnClass    : 'send-request-btn',
                connectionBtnDisabled : false,
                connectionBtnHover    : this.labels.necrologyHelpText,
                isNecrology           : true,
                showConnectionBtn     : true
            };
        }
        // SIV_VIS_CONNECTION: attendee has opted out of new connection requests.
        // Hide the button entirely — do not show a disabled Send Request.
        if (att.hideConnectionRequest && !att.isConnected) {
            return {
                connectionBtnLabel    : this.labels.sendRequest,
                connectionBtnClass    : 'send-request-btn send-request-btn--disabled',
                connectionBtnDisabled : true,
                connectionBtnHover    : this.labels.sendRequestHoverText,
                showConnectionBtn     : false
            };
        }
        if (att.isRejected) {
            return {
                connectionBtnLabel    : this.labels.sendRequest,
                connectionBtnClass    : 'send-request-btn send-request-btn--disabled',
                connectionBtnDisabled : true,
                connectionBtnHover    : this.labels.sendRequestHoverText,
                showConnectionBtn     : !this.loggedInUserHasConnectionPrivacy
            };
        }
        if (att.isConnected) {
            return {
                connectionBtnLabel    : this.labels.removeConnection,
                connectionBtnClass    : 'remove-connection-btn',
                connectionBtnDisabled : false,
                connectionBtnHover    : this.labels.removeConnectionHoverText,
                showConnectionBtn     : true
            };
        }
        if (att.connectionStatus === 'Request Sent') {
            return {
                connectionBtnLabel    : this.labels.cancelRequest,
                connectionBtnClass    : 'cancel-request-btn',
                connectionBtnDisabled : false,
                connectionBtnHover    : this.labels.cancelRequestHoverText,
                showConnectionBtn     : true
            };
        }
        // Default: send request enabled
        return {
            connectionBtnLabel    : this.labels.sendRequest,
            connectionBtnClass    : 'send-request-btn',
            connectionBtnDisabled : false,
            connectionBtnHover    : this.labels.sendRequestHoverText,
            showConnectionBtn     : !this.loggedInUserHasConnectionPrivacy
        };
    }

    // ─────────────────────────────────────────────────────────────────────────
    // UNIVERSAL ACTIONS HANDLER
    // Single entry point for: Send Request, Cancel Request, Remove Connection,
    // Bookmark (add/remove), Favorite (add/remove).
    //
    // Routes directly to the service for silent actions (Bookmark add, Fav toggle),
    // or opens a confirmation modal for actions that need user confirmation:
    //   Send Request, Cancel Request, Remove Connection, Remove Bookmark.
    // ─────────────────────────────────────────────────────────────────────────

    async handleAttendeeAction(event) {
        event.stopPropagation();   // prevent bubbling to the attendee-row onclick (handleViewProfile)

        // Necrology button: open the necrology link in a new tab — no connection service call
        if (event.currentTarget.dataset.isnecrology === 'true') {
            window.open(this.labels.necrologyLink, '_blank');
            return;
        }

        const attendeeId = event.currentTarget.dataset.id;
        const actiontype = event.currentTarget.dataset.actiontype; // 'bookmark' | 'favorite' | undefined
        const dataAction = event.currentTarget.dataset.action;     // set on the connection button


        let actionType;

        if (actiontype === 'bookmark') {
            const currentState = event.currentTarget.dataset.state === 'true';
            actionType = currentState ? ACTIONS.REMOVE_BOOKMARK : ACTIONS.BOOKMARK;
        } else if (actiontype === 'favorite') {
            const currentState = event.currentTarget.dataset.state === 'true';
            actionType = currentState ? ACTIONS.REMOVE_FAVORITE : ACTIONS.FAVORITE;
        } else {
            // Connection button — connectionBtnLabel already IS the correct action string
            actionType = dataAction;
        }

        // Actions that require user confirmation before executing
        const MODAL_ACTIONS = [
            ACTIONS.SEND_REQUEST,
            ACTIONS.CANCEL_REQUEST,
            ACTIONS.REMOVE_CONNECTION,
            ACTIONS.REMOVE_BOOKMARK
        ];


        if (MODAL_ACTIONS.includes(actionType)) {
            this.pendingAttendeeId = attendeeId;
            this.pendingActionType = actionType;

            // Check linked user's active status before opening modal (Essentially we disable only for Send Request only)
            let userStatus;
            if (actionType === ACTIONS.SEND_REQUEST) {
                this.isLoading = true;
                userStatus = await checkUserStatus({ linkedConstituentId: attendeeId });
                this.isLoading = false;
            }

            this.openAttendeeActionModal(actionType, userStatus);
        } else {
            // Silent actions: Bookmark (add), Favorite add/remove — go direct
            this.callConnectionService(attendeeId, actionType, '');
        }
    }

    /**
     * Populates and opens the confirmation modal for the given action.
     * If userStatus is 'Inactive User' (Send Request only), buttons are disabled
     * and an info banner is shown — matching alumni component behaviour.
     */
    openAttendeeActionModal(actionType, userStatus) {
        this.isAttendeeModalInactive = (userStatus === 'Inactive User');

        const modalConfig = {
            [ACTIONS.SEND_REQUEST]: {
                header   : this.labels.actionSRHeader,
                primary  : this.labels.actionSRPrimaryBtn,
                secondary: this.labels.actionSRSecondaryBtn,
                request  : true     // shows personalised message textarea
            },
            [ACTIONS.CANCEL_REQUEST]: {
                header   : this.labels.actionCRHeader,
                primary  : this.labels.cancelRequest,
                secondary: this.labels.actionRCSecondaryBtn,
                request  : false
            },
            [ACTIONS.REMOVE_CONNECTION]: {
                header   : this.labels.actionRCHeader,
                primary  : this.labels.removeConnection,
                secondary: this.labels.actionRCSecondaryBtn,
                request  : false
            },
            [ACTIONS.REMOVE_BOOKMARK]: {
                header   : this.labels.actionRBMHeader,
                primary  : this.labels.actionRBMPrimaryBtn,
                secondary: this.labels.actionRCSecondaryBtn,
                request  : false
            }
        };

        const config = modalConfig[actionType];
        if (!config) return;

        this.attendeeModalHeader     = config.header;
        this.attendeeModalPrimary    = config.primary;
        this.attendeeModalSecondary  = config.secondary;
        this.isAttendeeModalRequest  = config.request;
        this.showAttendeeActionModal = true;
    }

    /** Bound to the textarea inside the Send Request modal. */
    handleAttendeeMessageChange(event) {
        this.attendeePersonalizedMsg = event.target.value;
    }

    /** Primary button click inside the confirmation modal. */
    handleAttendeeModalConfirm(event) {

        if (event?.currentTarget?.dataset?.name === ACTIONS.SEND_REQUEST) {
            const textarea = this.template.querySelector('.attendee-modal-textarea');
            if (textarea && (!textarea.value || textarea.value.trim() === '')) {
                textarea.setCustomValidity('Please enter a personalized message.');
                textarea.reportValidity();
                return;
            }
            if (textarea) textarea.setCustomValidity('');
        }
        this.showAttendeeActionModal = false;
        this.callConnectionService(this.pendingAttendeeId, this.pendingActionType, this.attendeePersonalizedMsg);
    }

    /** Closes and resets the confirmation modal without performing any action. */
    closeAttendeeActionModal(event) {

        if (event?.currentTarget?.dataset?.name === this.labels.actionSRSecondaryBtn) {
            this.callConnectionService(this.pendingAttendeeId, this.pendingActionType, '');
        }else{
            this.showAttendeeActionModal = false;
            this.isAttendeeModalInactive = false;
            this.pendingAttendeeId       = null;
            this.pendingActionType       = null;
            this.attendeePersonalizedMsg = '';
            this.attendeeModalHeader     = '';
            this.attendeeModalPrimary    = '';
            this.attendeeModalSecondary  = 'Cancel';
            this.isAttendeeModalRequest  = false;
        }
    }

    /* ---------------- HAM_AlumniConnectionService CALL ---------------- */

    /**
     * Calls HAM_AlumniConnectionService.handleConnectionRequest.
     * On success: updates local attendee state
     * and syncs back to this.events where needed.
     */
    callConnectionService(attendeeId, actionType, message) {

        this.isLoading = true;
        handleConnectionRequest({
            portalId            : this.userContactId,
            linkedConstituentId : attendeeId,
            requestMessage      : message || '',
            functionType        : actionType
        })
        .then(result => {
            if (result === 'Success') {
                // The home page Directory card shows the latest connection's photo
                publish(this.messageContext, THUMBNAIL_REFRESH_CHANNEL, { source: 'connection' });

                this.updateAttendeeLocalState(attendeeId, actionType);
                this.showToast(5000, 'Success', this.getAttendeeToastMessage(actionType), 'success');
            } else {
                this.showToast(5000, 'Error', 'An error occurred. Please try again.', 'error');
                console.error('Connection service error:', result);
            }
        })
        .catch(error => {
            this.showToast(5000, 'Error', 'An error occurred. Please try again.', 'error');
            console.error('Connection service exception:', JSON.stringify(error));
        })
        .finally(() => {
            this.isLoading = false;
            this.closeAttendeeActionModal();
        });
    }

    /**
     * Returns the success toast message for each action type using custom labels.
     */
    getAttendeeToastMessage(actionType) {
        const messages = {
            [ACTIONS.SEND_REQUEST]      : this.labels.toastMessageReqSend,
            [ACTIONS.CANCEL_REQUEST]    : this.labels.toastMessageCancelReq,
            [ACTIONS.REMOVE_CONNECTION] : this.labels.removeConnection,
            [ACTIONS.BOOKMARK]          : this.labels.toastMessageBookmarked,
            [ACTIONS.REMOVE_BOOKMARK]   : this.labels.toastMesgRemBookmarked,
            [ACTIONS.FAVORITE]          : this.labels.toastMessageFavorite,
            [ACTIONS.REMOVE_FAVORITE]   : this.labels.toastMessageRemoveFavorite
        };
        return messages[actionType] || 'Action completed successfully.';
    }

    /**
     * updates selectedAttendees after a successful service call.
     * Recalculates connection button props for connection-state changes.
     * Syncs bookmark / favourite / connection changes back into this.events.
     */
    updateAttendeeLocalState(attendeeId, actionType) {
        this.selectedAttendees = this.selectedAttendees.map(att => {
            if (att.attendeeId !== attendeeId) return att;
            let updated = { ...att };

            if (actionType === ACTIONS.SEND_REQUEST) {
                updated.connectionStatus = 'Request Sent';
                updated.isConnected      = false;
                updated.isRejected       = false;
            } else if (actionType === ACTIONS.CANCEL_REQUEST) {
                updated.connectionStatus = '-';
                updated.isConnected      = false;
            } else if (actionType === ACTIONS.REMOVE_CONNECTION) {
                updated.isConnected      = false;
                updated.isFavorite       = false;
                updated.connectionStatus = '-';
                updated.favoriteIcon     = this.isOverride ? this.icons.favIconDisabledGreen : this.icons.favIconDisabled;
                this.localAttendeeState[attendeeId] = { ...(this.localAttendeeState[attendeeId] || {}), isFavorite: false };
            } else if (actionType === ACTIONS.BOOKMARK) {
                updated.isBookmarked = true;
                updated.bookmarkIcon = this.isOverride ? this.icons.bookmarkfillGreen : this.icons.bookmarkfill;
                this.localAttendeeState[attendeeId] = { ...(this.localAttendeeState[attendeeId] || {}), isBookmarked: true };
            } else if (actionType === ACTIONS.REMOVE_BOOKMARK) {
                updated.isBookmarked = false;
                updated.bookmarkIcon = this.isOverride ? this.icons.bookmarkoutlineGreen : this.icons.bookmarkoutline;
                this.localAttendeeState[attendeeId] = { ...(this.localAttendeeState[attendeeId] || {}), isBookmarked: false };
            } else if (actionType === ACTIONS.FAVORITE) {
                updated.isFavorite   = true;
                updated.favoriteIcon = this.isOverride ? this.icons.favIconEnabledGreen : this.icons.favIconEnabled;
                this.localAttendeeState[attendeeId] = { ...(this.localAttendeeState[attendeeId] || {}), isFavorite: true };
            } else if (actionType === ACTIONS.REMOVE_FAVORITE) {
                updated.isFavorite   = false;
                updated.favoriteIcon = this.isOverride ? this.icons.favIconDisabledGreen : this.icons.favIconDisabled;
                this.localAttendeeState[attendeeId] = { ...(this.localAttendeeState[attendeeId] || {}), isFavorite: false };
            }

            // Recalculate the dynamic connection button for any connection-state change
            if ([ACTIONS.SEND_REQUEST, ACTIONS.CANCEL_REQUEST, ACTIONS.REMOVE_CONNECTION].includes(actionType)) {
                Object.assign(updated, this.getConnectionButtonProps(updated));
            }

            return updated;
        });

        if (actionType === ACTIONS.REMOVE_CONNECTION && this.modalType === 'connections') {
            this.selectedAttendees    = this.selectedAttendees.filter(a => a.attendeeId !== attendeeId);
            this.attendeeTotalRecords = Math.max(0, this.attendeeTotalRecords - 1);
        }

        // Sync bookmark / favourite / isConnected changes back to this.events (preview stack source of truth)
        const needsEventsSync = [
            ACTIONS.BOOKMARK, ACTIONS.REMOVE_BOOKMARK,
            ACTIONS.FAVORITE, ACTIONS.REMOVE_FAVORITE,
            ACTIONS.REMOVE_CONNECTION
        ].includes(actionType);

        if (needsEventsSync) {
            this.events = this.events.map(evt => {
                const hasAttendee = (evt.attendees || []).some(a => a.attendeeId === attendeeId);
                if (!hasAttendee) return evt;

                // Update the attendee in the event's attendee list
                let updatedAttendees = (evt.attendees || []).map(a => {
                    if (a.attendeeId !== attendeeId) return a;
                    const r = { ...a };
                    if (actionType === ACTIONS.BOOKMARK)          r.isBookmarked = true;
                    if (actionType === ACTIONS.REMOVE_BOOKMARK)   r.isBookmarked = false;
                    if (actionType === ACTIONS.FAVORITE)          r.isFavorite   = true;
                    if (actionType === ACTIONS.REMOVE_FAVORITE)   r.isFavorite   = false;
                    if (actionType === ACTIONS.REMOVE_CONNECTION) { r.isConnected = false; r.isFavorite = false; }
                    return r;
                });

                // ──Recalculate event card for REMOVE_CONNECTION ─────────────────
                if (actionType === ACTIONS.REMOVE_CONNECTION) {
                    // Remove the disconnected attendee from the preview stack
                    updatedAttendees = updatedAttendees.filter(a => a.attendeeId !== attendeeId);

                    const newCount = Math.max(0, (evt.totalConnectionCount || 0) - 1);

                    // Rebuild attendeeText (same logic as wiredEvents)
                    let attendeeText = '';
                    if (newCount === 0) {
                        attendeeText = this.activeMainTab === this.labels.upcomingEvents
                            ? this.labels.upcomingNoConnections
                            : this.labels.pastNoConnections;
                    } else if (newCount <= 3) {
                        attendeeText = this.labels.connectionsAttending;
                    } else {
                        attendeeText = `+${newCount - 3} ${this.labels.connectionsAttending}`;
                    }

                    // Rebuild attendeesPreview with recalculated positions
                    const avatarWidth = 28;
                    const overlap = 14;
                    const avatarsWidth = updatedAttendees.length > 0
                        ? avatarWidth + (updatedAttendees.length - 1) * overlap
                        : 0;
                    const attendeesPreview = updatedAttendees.map((att, index) => ({
                        ...att,
                        style: `left:${index * 14}px; z-index:${10 - index};`
                    }));

                    return {
                        ...evt,
                        attendees            : updatedAttendees,
                        attendeesPreview,
                        totalConnectionCount : newCount,
                        attendeeText,
                        avatarsContainerStyle: `width:${avatarsWidth}px;`
                    };
                }
                // ─────────────────────────────────────────────────────────────────────

                return { ...evt, attendees: updatedAttendees };
            });
        }

        // Re-sort after state change to maintain preference order
        this.selectedAttendees = this.sortAttendees(this.selectedAttendees);
    }

    sortAttendees(list) {
        if (!list || !list.length) return [];

        const getPriority = (att) => {
            if (att.isConnected && att.isFavorite)   return 1;
            if (att.isConnected && att.isBookmarked) return 2;
            if (att.isConnected)                     return 3;
            if (att.isBookmarked)                    return 4;
            return 5;
        };

        return [...list].sort((a, b) => {
            const pA = getPriority(a);
            const pB = getPriority(b);
            if (pA !== pB) return pA - pB;
            return (a.lastName || '').toLowerCase().localeCompare((b.lastName || '').toLowerCase());
        });
    }

    // ─────────────────────────────────────────────────────────────────────────
    // MODAL BUTTON CLASS GETTERS
    // ─────────────────────────────────────────────────────────────────────────

    /** Primary button: greyed-out when the linked user is inactive. */
    get attendeeModalPrimaryClass() {
        return this.isAttendeeModalInactive
            ? 'attendee-action-primary-btn attendee-action-btn--disabled'
            : 'attendee-action-primary-btn';
    }

    /** Secondary button: greyed-out when the linked user is inactive. */
    get attendeeModalSecondaryClass() {
        return this.isAttendeeModalInactive
            ? 'attendee-action-secondary-btn attendee-action-btn--disabled'
            : 'attendee-action-secondary-btn';
    }

    // ─────────────────────────────────────────────────────────────────────────
    // TOAST
    // ─────────────────────────────────────────────────────────────────────────

    showToast(toastDuration, toastTitle, toastMessage, toastVariant) {
        this.toastDuration = toastDuration;
        this.toastTitle    = toastTitle;
        this.toastMessage  = toastMessage;
        this.toastVariant  = toastVariant;
        this.showCustomToast = true;
    }

    handleToastClose() { this.showCustomToast = false; }
}