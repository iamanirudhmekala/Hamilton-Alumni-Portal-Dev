import { LightningElement, track, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { refreshApex } from '@salesforce/apex';

// Importing custom labels
import MyImpact from '@salesforce/label/c.ham_MyImpact';
import alumniDirectory from '@salesforce/label/c.ham_AlumniDirectory';
import makeAGift from '@salesforce/label/c.ham_MakeAGift';
import makeAGiftLink from '@salesforce/label/c.ham_MakeAGiftLink';
import logout from '@salesforce/label/c.ham_LogoutLabel';
import logoutLink from '@salesforce/label/c.ham_LogoutLink';
import editProfile from '@salesforce/label/c.ham_EditProfile';
import manageSubscription from '@salesforce/label/c.ham_ManageSubscription';
import manageSubscriptionLink from '@salesforce/label/c.ham_ManageSubscriptionLink';
import feedback from '@salesforce/label/c.HAM_Feedback';
import feedbackLink from '@salesforce/label/c.HAM_FeedbackLink';
import CurrentFiscalYearGiving from '@salesforce/label/c.ham_CurrentFiscalYearGiving';
import LifetimeImpact from '@salesforce/label/c.ham_LifetimeImpact';
import BecauseHamiltonFund from '@salesforce/label/c.ham_BecauseHamiltonFund';
import Events from '@salesforce/label/c.ham_Events';
import News from '@salesforce/label/c.ham_News';
import VolunteerOpportunity from '@salesforce/label/c.ham_volunteerOpportunity';
import EventsMobile from '@salesforce/label/c.ham_Events_Mobile';
import NewsMobile from '@salesforce/label/c.ham_News_Mobile';
import EventsDescMobile from '@salesforce/label/c.ham_EventsDesc_Mobile';
import NewsDescMobile from '@salesforce/label/c.ham_NewsDesc_Mobile';
import EventsTitle from '@salesforce/label/c.ham_Events_Title';
import NewsTitle from '@salesforce/label/c.ham_News_Title';
import Groups from '@salesforce/label/c.ham_Groups';
import HomeTitle from '@salesforce/label/c.ham_Home';
import MobileImpact from '@salesforce/label/c.ham_MobileImpact';
import WelcomeBack from '@salesforce/label/c.HAM_Welcome_Back';
import HappyBirthday from '@salesforce/label/c.HAM_Happy_Birthday';
import VolOppTab from '@salesforce/label/c.ham_volunteerOppTab';
import VolActTab from '@salesforce/label/c.ham_myVolunteerActivityTab';
import VolImInterested from '@salesforce/label/c.ham_ImInterested';
import VolWithdraw from '@salesforce/label/c.ham_withdrawButton';
import VolCurrentTab from '@salesforce/label/c.ham_currentActivity';
import VolUpcomingTab from '@salesforce/label/c.ham_upcomingActivity';
import VolPastTab from '@salesforce/label/c.ham_pastActivities';
import VolOppInterestTitle from '@salesforce/label/c.ham_volOppInterestTitle';
import VolOppInterestDesc from '@salesforce/label/c.ham_volOppInterestDesc';
import VolOppWithdrawTitle from '@salesforce/label/c.ham_volOppWithdrawTitle';
import VolOppWithdrawDesc from '@salesforce/label/c.ham_volOppWithdrawDesc';
import DirectoryWidget from '@salesforce/label/c.ham_directoryWidget';
import DirectoryWidgetCon from '@salesforce/label/c.ham_directoryWidget_Con';
import DirectoryWidgetClass from '@salesforce/label/c.ham_directoryWidget_Class';
import DirectoryWidgetBook from '@salesforce/label/c.ham_directoryWidget_Book';
import PersonalInfo from '@salesforce/label/c.HAM_ProfileOverview_PerInfo';
import AddressDetails from '@salesforce/label/c.HAM_ProfileOverview_AddDetail';
import CampusLife from '@salesforce/label/c.HAM_ProfileOverview_CamLife';
import MyConnection from '@salesforce/label/c.HAM_My_Connections';
import BookmarkedProfile from '@salesforce/label/c.HAM_Bookmarked_Profiles';
import BuildCommunity from '@salesforce/label/c.HAM_Build_Community';
import ManageInvitation from '@salesforce/label/c.HAM_Manage_Invitations';
import BuildAlumniCommunity from '@salesforce/label/c.ham_BuildAlumniCommunity';
import FavoriteConnections from '@salesforce/label/c.ham_favoriteConnections';
import BookmarkedConnection from '@salesforce/label/c.ham_bookmarkedConnections';
import ClearSearchResult from '@salesforce/label/c.ham_clearSearchResult';
import SaveAppliedFilter from '@salesforce/label/c.ham_saveAppliedFilters';
import SeeAllConnections from '@salesforce/label/c.ham_seeAllConnections';
import FindConnections from '@salesforce/label/c.ham_findConnections';
import SearchAndMakeConnections from '@salesforce/label/c.ham_searchAndMakeConnections';
import editProfTitle from '@salesforce/label/c.ham_editprofile_title';
import editProfPicture from '@salesforce/label/c.ham_editprofile_picture';
import editProfCancel from '@salesforce/label/c.ham_editprofile_cancel';
import editProfButton1 from '@salesforce/label/c.ham_editprofile_button1';
import editProfButton2 from '@salesforce/label/c.ham_editprofile_button2';
import editProfInfo from '@salesforce/label/c.ham_editprofile_info';
import editProfdirecPS from '@salesforce/label/c.ham_editprofile_directoryPS';
import editProfVisibiltyDesc from '@salesforce/label/c.ham_editprofile_visibility_desc';
import editProfPrivacyBanner from '@salesforce/label/c.ham_editprofile_privacy_banner';
import editProfPrivacyDesc from '@salesforce/label/c.ham_editprofile_privacy_desc';
import profileoverEduhistory from '@salesforce/label/c.ham_educationhistory';
import requestNewGroupBtn from '@salesforce/label/c.ham_requestNewGroupBtn';
import groupsDiscModal from '@salesforce/label/c.ham_groupsDiscModal';
import groupsDiscModalEmail from '@salesforce/label/c.ham_groupsDiscModalEmail';



// Importing static resources
import HAM_ICONS from '@salesforce/resourceUrl/HAM_Icons';
import HAM_MALLORY from '@salesforce/resourceUrl/HAM_Mallory';
import HAM_MILLER from '@salesforce/resourceUrl/HAM_Miller';

//Import Ligtning Message service and channel
import { subscribe, unsubscribe, MessageContext, publish } from 'lightning/messageService';
import HEADER_CHANNEL from '@salesforce/messageChannel/ham_HeaderMessageChannel__c';
import NAVIGATION_CHANNEL from '@salesforce/messageChannel/ham_HomeNavigationChannel__c';

// Importing Apex methods
import getMyLinksMetaData from '@salesforce/apex/HAM_MainController.getMyLinksMetaData';
import fetchLoggedInUserInfo from '@salesforce/apex/HAM_MainController.fetchLoggedInUserInfo';
import getGivingAppStatus from '@salesforce/apex/HAM_MainController.getGivingAppStatus';
import getRegisteredUsersCount from '@salesforce/apex/HAM_MainController.getRegisteredUsersCount';

/**
 * @description A main component that serves as the top-level container for a community page.
 * It handles navigation, user settings, profile management, and responsive design.
 * @extends {NavigationMixin(LightningElement)}
 */
export default class Ham_MainCmp extends NavigationMixin(LightningElement) {
    @track myLinks = [];
    @track isPreferencesOpen = false;
    @track isSettingsOpen = false; // to be removed later
    @track isLinksOpen = false;     // for My Links dropdown
    @track isMobileMenuOpen = false;
    @track isEditProfile = false;
    @track isGivingPageActive = false;
    @track isProfileOverview = false;
    @track currentUserContactId;
    @track userProfileUrl;
    @track userName;
    @track userFirstName;
    @track userBirthday;
    @track contactClassYear;
    @track volTabSelected;
    @track selectedCardId;
    lastActiveTab;
    @track isKirklandAlumnae = false;
    @track isOverride = false;
    @track isStudent = false;
    @track isLoading = true;
    @track isGivingAppLive = true; // Defaults to true
    @track savedFilters;
    @track searchKeyToApex;
    @track primarykeyset;
    @track secondarykeyset;
    @track recordsToSkip;
    @track directoryView;
    /** Relayed from ham_alumniDisplayCmp so retrigger can honour points 1-4 vs point 5. */
    userHasModifiedFilters = false;
    /** Snapshot of _initialDirectoryFilters at View Profile time; survives the re-mount. */
    initialDirectoryFilters = null;
    wiredResult;
    isProfileUpdated = false;
    profileUpdatedToken;
    parentBadgesArray = [];
    @track registeredUsersCount;

    @track selectedGroupId;
    @track groupSubview;
    @track communitySubTab = News;

    /**
     * @description Custom labels used in the component.
     */
    label = {
        myimpact: MyImpact,
        alumnidirectory: alumniDirectory,
        makeagift: makeAGift,
        makeagiftlink: makeAGiftLink,
        logout: logout,
        logoutlink: logoutLink,
        managesubscription: manageSubscription,
        managesubscriptionlink: manageSubscriptionLink,
        editprofile: editProfile,
        feedback: feedback,
        feedbacklink: feedbackLink,
        currentfiscalyeargiving: CurrentFiscalYearGiving,
        lifetimeimpact: LifetimeImpact,
        becausehamiltonfund: BecauseHamiltonFund,
        events: Events,
        news: News,
        volunteerOpportunity: VolunteerOpportunity,
        protopia: 'Protopia',
        eventmobile: EventsMobile,
        newsmobile: NewsMobile,
        eventsdescmobile: EventsDescMobile,
        newdescmobile: NewsDescMobile,
        eventstitle: EventsTitle,
        newstitle: NewsTitle,
        groups: Groups,
        hometitle: HomeTitle,
        mobileImpact: MobileImpact,
        welcomeBack: WelcomeBack,
        happyBirthday: HappyBirthday,
        volImInterested: VolImInterested,
        volActTab: VolActTab,
        volOppTab: VolOppTab,
        volUpcomingTab: VolUpcomingTab,
        volCurrentTab: VolCurrentTab,
        volWithdraw: VolWithdraw,
        volOppInterestDesc: VolOppInterestDesc,
        volOppInterestTitle: VolOppInterestTitle,
        volPastTab: VolPastTab,
        volOppWithdrawDesc: VolOppWithdrawDesc,
        volOppWithdrawTitle: VolOppWithdrawTitle,
        directoryWidget: DirectoryWidget,
        directoryWidgetCon: DirectoryWidgetCon,
        directoryWidgetClass: DirectoryWidgetClass,
        directoryWidgetBook: DirectoryWidgetBook,
        personalinfo: PersonalInfo,
        addressdetails: AddressDetails,
        campuslife: CampusLife,
        myConnection: MyConnection,
        bookmarkedProfiles: BookmarkedProfile,
        buildCommunity: BuildCommunity,
        manageInvitation: ManageInvitation,
        alumniDirectory: BuildAlumniCommunity,
        favoriteConnections: FavoriteConnections,
        bookmarkedConnections: BookmarkedConnection,
        clearSearchResult: ClearSearchResult,
        saveAppliedFilter: SaveAppliedFilter,
        seeAllConnections: SeeAllConnections,
        findConnection: FindConnections,
        searchAndMakeConnections: SearchAndMakeConnections,
        editProfTitle: editProfTitle,
        editProfPicture: editProfPicture,
        editProfCancel: editProfCancel,
        editProfButton1: editProfButton1,
        editProfButton2: editProfButton2,
        editProfInfo: editProfInfo,
        editProfdirecPS: editProfdirecPS,
        editProfVisibiltyDesc: editProfVisibiltyDesc,
        editProfPrivacyBanner: editProfPrivacyBanner,
        editProfPrivacyDesc: editProfPrivacyDesc,
        profileoverEduhistory: profileoverEduhistory,
        requestNewGroupBtn: requestNewGroupBtn,
        groupsDiscModal: groupsDiscModal,
        groupsDiscModalEmail: groupsDiscModalEmail,
        community: 'Community'
    };

    /**
     * @description Static resource object for image URLs.
     */
    mainResource = {
        hamIcons: HAM_ICONS,
        hamMallory: HAM_MALLORY,
        hamMiller: HAM_MILLER
    };

    @track activeTab = this.label.hometitle; // Default active tab
    @track screenWidth = window.innerWidth;

    @track alumniDirectoryDefaultTab;
    @track opportunityActiveTab;

    /**
     * @description Object holding image paths for the component's UI.
     */
    images = {
        /* Commented out until hamilton team decides, whether to use hamlink or not */
        // logo: this.mainResource.hamIcons + '/logo.png',
        logo: this.mainResource.hamIcons + '/footerLogo.png',
        makeaGiftImage: this.mainResource.hamIcons + '/gift-outline.png',
        makeaGiftImageMobile: this.mainResource.hamIcons + '/mobile-gift-outline-only-box.png',
        makeaGiftBoxImageMobile: this.mainResource.hamIcons + '/mobile-gift-outline-only-box.png',
        hamburgerMobile: this.mainResource.hamIcons + '/mobile-hamburger-outline.png',
        editProfileImage: this.mainResource.hamIcons + '/create-outline-1.png',
        editProfileImageGreen: this.mainResource.hamIcons + '/create-outline-1-green.png',
        editProfileImageMobile: this.mainResource.hamIcons + '/mobile-settings.png',
        logoutImage: this.mainResource.hamIcons + '/exit-outline.png',
        logoutImageGreen: this.mainResource.hamIcons + '/exit-outline-green.png',
        logoutImageMobile: this.mainResource.hamIcons + '/mobile-logout.png',
        manageSubscriptionImage: this.mainResource.hamIcons + '/mail-unread-outline.png',
        manageSubscriptionImageGreen: this.mainResource.hamIcons + '/mail-unread-outline-green.png',
        settingsImage: this.mainResource.hamIcons + '/Frame-42.png',
        manageSubscriptionImageMobile: this.mainResource.hamIcons + '/mail-unread-outline-mobile.png',
        personImage: this.mainResource.hamIcons + '/person.png',
        inpersonImage: this.mainResource.hamIcons + '/inperson.png',
        inpersonActiveImage: this.mainResource.hamIcons + '/inperson-active.png',
        inPersonGreen: this.mainResource.hamIcons + '/inperson-green.png',
        virtualImage: this.mainResource.hamIcons + '/virtual.png',
        virtualGreen: this.mainResource.hamIcons + '/virtual-green.png',
        virtualActiveImage: this.mainResource.hamIcons + '/virtual-active.png',
        mobileGridOutlineOnly: this.mainResource.hamIcons + '/mobile-gift-outline-only-box.png',
        givingDayClose: this.mainResource.hamIcons + '/giving-day-close.png',
        mobileArrow: this.mainResource.hamIcons + '/mobile-arrow.png',
        mobileArrowGreen: this.mainResource.hamIcons + '/mobile-arrow_green.png',
        widgetRedirect: this.mainResource.hamIcons + '/widget-redirect.png',
        widgetRedirectGreen: this.mainResource.hamIcons + '/widget-redirect-green.png',
        mobileHomeOn: this.mainResource.hamIcons + '/mobile-home-on.png',
        mobileEventsOn: this.mainResource.hamIcons + '/mobile-events-on.png',
        mobileNewsOn: this.mainResource.hamIcons + '/mobile-news-on.png',
        mobileDirectoryOn: this.mainResource.hamIcons + '/mobile-directory-on.png',
        mobileImpactOn: this.mainResource.hamIcons + '/mobile-impact-on.png',
        mobileHomeOff: this.mainResource.hamIcons + '/mobile-home-off.png',
        mobileEventsOff: this.mainResource.hamIcons + '/mobile-events-off.png',
        mobileNewsOff: this.mainResource.hamIcons + '/mobile-news-off.png',
        mobileDirectoryOff: this.mainResource.hamIcons + '/mobile-directory-off.png',
        mobileImpactOff: this.mainResource.hamIcons + '/mobile-impact-off.png',
        arrowLeft: this.mainResource.hamIcons + '/arro-left.png',
        arrowRight: this.mainResource.hamIcons + '/arrow-right.png',
        volPopupIcon: this.mainResource.hamIcons + '/vol-popup-icon.png',
        volOpen: this.mainResource.hamIcons + '/vol-open.png',
        volClose: this.mainResource.hamIcons + '/vol-close.png',
        calendarImage: this.mainResource.hamIcons + '/calendar.png',
        dropdownImage: this.mainResource.hamIcons + '/dropdown.png',
        linkedIcon: this.mainResource.hamIcons + '/linkedin_POV.png',
        lnstaIcon: this.mainResource.hamIcons + '/instagram_POV.png',
        faceIcon: this.mainResource.hamIcons + '/facebook_POV.png',
        twitterIcon: this.mainResource.hamIcons + '/twitter_POV.png',
        linkedinIcon: this.mainResource.hamIcons + '/linkedIn_POV.png',
        kirklandAlumnaeIcon: this.mainResource.hamIcons + '/kirkland-icon.png',
        mobileCommunityOn: this.mainResource.hamIcons + '/mobile-community-on.png',
        mobileCommunityOff: this.mainResource.hamIcons + '/mobile-community-off.png',
        chapelBellBanner: this.mainResource.hamIcons + '/chapel-bell-aerial.png',
        chapelBellBannerLarge: this.mainResource.hamIcons + '/chapel-bell-banner-large.png',
        //chapelBellCupola: this.mainResource.hamIcons + '/chapel-bell-banner-cupola.jpg',
        //chapelBellBanner2: this.mainResource.hamIcons + '/chapel-bell-banner-2.jpg',
        notificationBell: this.mainResource.hamIcons + '/notification-bell.png',
        notifcationBellBlue: this.mainResource.hamIcons +'/notification-bell-blue.png',
        notifcationBellGreen: this.mainResource.hamIcons + '/notification-bell-green.png',
        requestNewGroupMob: this.mainResource.hamIcons + '/mobile-groupsadd.png',
        groupFilter: this.mainResource.hamIcons + '/group_filter.png',
        groupMembers: this.mainResource.hamIcons + '/members.png',

    };

    @wire(MessageContext)
    messageContext;


    /**
     * @description Lifecycle hook that runs when the component is inserted into the DOM.
     * It sets up event listeners for window resize and outside clicks.
     */
    connectedCallback() {

        if (window.location.href.includes('builder')) {
            this.isLoading = false;
        }

        // Fallback: if the wire never resolves (e.g. no member session in Experience Builder),
        // unblock the UI after 8 seconds so the spinner doesn't hang forever.
        this._spinnerTimeout = setTimeout(() => {
            if (this.isLoading) {
                this.isLoading = false;
            }
        }, 8000);

        //  event listener for window resize
        window.addEventListener('resize', this.handleResize.bind(this));

        //  subscribing the message channel to receive data from header
        this.subscribeToMessageChannel();

        // Add event listener for clicks outside the component
        this._handleOutsideClick = this.handleOutsideClick.bind(this);
        document.addEventListener('click', this._handleOutsideClick);

        // Bind the popstate listener to handle Browser Back/Forward buttons
        this._handlePopState = this.handlePopState.bind(this);
        window.addEventListener('popstate', this._handlePopState);

        // Use safe navigation for initialization
        this.alumniDirectoryDefaultTab = this.label?.buildCommunity || 'Search Directory';
        this.opportunityActiveTab = this.activeTab == this.label?.volunteerOpportunity ? this.label.volunteerOpportunity : 'Volunteer';

        // Use Promise to defer deep-link check until after initial render.
        // NOTE: restoreStateFromLocalStorage() is intentionally NOT called here.
        // In DEV the header is gated by isLoading, so it hasn't mounted yet and
        // isn't subscribed to NAVIGATION_CHANNEL — any publish here would be lost.
        // Instead, restoration runs after isLoading = false (see wiredLoggedInUserInfo).
        Promise.resolve().then(() => {
            // Check URL first (for email links). Store result for the wire handler.
            this._isDeepLinked = this.checkUrlForDeepLink();
            if (!this._isDeepLinked) {
                setTimeout(() => {
                    this.syncInitialUrl();
                }, 100);
            }
        });
    }

    /**
     * Helper to map our component states to clean URL words
     */
    get tabToUrlMap() {
        return {
            [this.label.hometitle]: 'home',
            [this.label.alumnidirectory]: 'directory',
            [this.label.myimpact]: 'impact',
            [this.label.events]: 'events',
            [this.label.community]: 'community',
            [this.label.news]: 'news',
            [this.label.volunteerOpportunity]: 'volunteer',
            [this.label.groups]: 'groups'
        };
    }

    /**
     * @description Silently updates the browser URL without reloading the page
     * so users can copy/paste or email the link.
     */
    updateBrowserUrl(viewName, cardId = null) {
        const url = new URL(window.location.href);
        url.searchParams.set('view', viewName);

        // Clear community/group-specific params when leaving the community/directory view
        if (viewName !== 'community' && viewName !== 'directory') {
            url.searchParams.delete('groupId');
            url.searchParams.delete('subview');
            url.searchParams.delete('tab');
        }

        // Notification deep-link params are one-shot (consumed by ham_groupFeed and
        // ham_groupResources on the initial load) — clear them on every subsequent
        // navigation so they don't re-trigger scroll-to-target on a later re-mount.
        url.searchParams.delete('postId');
        url.searchParams.delete('commentId');
        url.searchParams.delete('resourceId');
        url.searchParams.delete('mode');

        if (viewName === 'profileoverview') {
            const idToSet = cardId || this.selectedCardId;
            if (idToSet) url.searchParams.set('cardId', idToSet);
        } else {
            url.searchParams.delete('cardId');
        }

        window.history.pushState({}, '', url.toString());
    }

    /**
     * @description Syncs the URL on the very first load to match the default or restored state.
     */
    syncInitialUrl() {
        let viewToSet = 'home'; // Default fallback
        let cardIdToSet = null;

        // Check which view was restored from LocalStorage or defaults
        if (this.isGivingPageActive) {
            viewToSet = 'gift';
        } else if (this.isPreferencesOpen) {
            viewToSet = 'preferences';
        } else if (this.isEditProfile) {
            viewToSet = 'editprofile';
        } else if (this.isProfileOverview) {
            viewToSet = 'profileoverview';
            cardIdToSet = this.selectedCardId;
        } else if (this.activeTab) {
            viewToSet = this.tabToUrlMap[this.activeTab] || 'home';
        }

        const url = new URL(window.location.href);
        let urlUpdated = false;

        // Update view if not matching
        if (url.searchParams.get('view') !== viewToSet) {
            url.searchParams.set('view', viewToSet);
            urlUpdated = true;
        }

        // Update cardId correctly based on the view
        if (viewToSet === 'profileoverview' && cardIdToSet && url.searchParams.get('cardId') !== cardIdToSet) {
            url.searchParams.set('cardId', cardIdToSet);
            urlUpdated = true;
        } else if (viewToSet !== 'profileoverview' && url.searchParams.has('cardId')) {
            url.searchParams.delete('cardId');
            urlUpdated = true;
        }

        // Clean up group parameters when not in community view
        if (viewToSet !== 'community') {
            if (url.searchParams.has('groupId')) {
                url.searchParams.delete('groupId');
                urlUpdated = true;
            }
            if (url.searchParams.has('subview')) {
                url.searchParams.delete('subview');
                urlUpdated = true;
            }
        }
        // Clean up stale community subtab parameter when switching to directory
        if (viewToSet === 'directory') {
            const currentTab = url.searchParams.get('tab');
            if (currentTab && ['groups', 'news', 'resources'].includes(currentTab.toLowerCase())) {
                url.searchParams.delete('tab');
                urlUpdated = true;
            }
        }

        if (urlUpdated) {
            window.history.replaceState({}, '', url.toString());
        }
    }

    /**
     * @description Checks if the user clicked a link from an email (e.g., ?view=gift)
     * Returns true if a deep link was found and applied.
     */
    checkUrlForDeepLink() {
        const urlParams = new URLSearchParams(window.location.search);
        const view = urlParams.get('view');

        if (!view) return false; // No URL parameter found, use normal logic

        // Reset all overlay flags first
        this.isEditProfile = false;
        this.isPreferencesOpen = false;
        this.isGivingPageActive = false;
        this.isProfileOverview = false;

        // If there's no view param (e.g. user clicked Back to the base URL)
        if (!view) {
            this.activeTab = this.label.hometitle; // Default to Home
            this.notifyHeaderOfTabChange();
            return false;
        }

        // Apply the correct view based on the URL parameter
        switch (view.toLowerCase()) {
            case 'gift':
                this.isGivingPageActive = true;
                this.activeTab = '';
                break;
            case 'preferences':
                this.isPreferencesOpen = true;
                this.activeTab = '';
                break;
            case 'editprofile':
                this.isEditProfile = true;
                this.activeTab = '';
                break;
            case 'profileoverview':
                this.isProfileOverview = true;
                this.activeTab = '';
                const cardId = urlParams.get('cardId');
                if (cardId) {
                    this.selectedCardId = cardId;
                }
                break;
            case 'directory':
                this.activeTab = this.label.alumnidirectory;
                const dirTab = urlParams.get('tab');
                if (dirTab) {
                    const lowerTab = dirTab.toLowerCase();
                    if (lowerTab === 'manageinvitations' || lowerTab === 'manage invitations' || lowerTab === 'manage%20invitations') {
                        this.alumniDirectoryDefaultTab = this.label.manageInvitation;
                    } else if (lowerTab === 'myconnections' || lowerTab === 'my connections') {
                        this.alumniDirectoryDefaultTab = this.label.myConnection;
                    } else if (lowerTab === 'bookmarkedprofiles' || lowerTab === 'bookmarked profiles') {
                        this.alumniDirectoryDefaultTab = this.label.bookmarkedProfiles;
                    } else if (lowerTab === 'buildcommunity' || lowerTab === 'search directory') {
                        this.alumniDirectoryDefaultTab = this.label.buildCommunity;
                    } else {
                        this.alumniDirectoryDefaultTab = dirTab;
                    }
                }
                break;
            case 'impact':
                this.activeTab = this.label.myimpact;
                break;
            case 'events':
                this.activeTab = this.label.events;
                break;
            case 'news':
                this.activeTab = this.label.news;
                break;
            case 'community':
                this.activeTab = this.label.community;
                // Extract community sub-params if they exist
                this.communitySubTab = urlParams.get('tab') || 'News';
                this.selectedGroupId = urlParams.get('groupId');
                this.groupSubview = urlParams.get('subview');
                break;
            case 'volunteer':
                this.activeTab = this.label.volunteerOpportunity;
                break;
            case 'groups':
                // Group notification deep links (?view=groups&groupId=...): the
                // standalone student-only Groups tab is currently disabled, so
                // route into the Community tab's Groups subtab, which threads
                // groupId/subview down to the Groups orchestrator.
                this.activeTab = this.label.community;
                this.communitySubTab = 'Groups';
                this.selectedGroupId = urlParams.get('groupId');
                this.groupSubview = urlParams.get('subview');
                break;
            case 'home':
            default:
                this.activeTab = this.label.hometitle;
                break;
        }

        // Inform the header/navigation to update its highlighted tab
        if (this.messageContext) {
            const message = { selectedItem: this.activeTab === '' ? 'none' : this.activeTab };
            publish(this.messageContext, NAVIGATION_CHANNEL, message);
        }

        return true; // successfully routed via URL
    }

    /**
    * @description Restores component state from localStorage
    */
    restoreStateFromLocalStorage() {
        // Get all stored states
        const storedActiveTab = sessionStorage.getItem('ham_activeTab');
        const storedLastActiveTab = sessionStorage.getItem('ham_lastActiveTab');
        const storedEditProfile = sessionStorage.getItem('ham_isEditProfile');
        const storedPreferences = sessionStorage.getItem('ham_isPreferencesOpen');
        const storedGivingPage = sessionStorage.getItem('ham_isGivingPageActive');
        const storedProfileOverview = sessionStorage.getItem('ham_isProfileOverview');
        const storedDirectoryTab = sessionStorage.getItem('ham_alumniDirectoryDefaultTab');
        const storedCardId = sessionStorage.getItem('ham_selectedCardId');

        // Restore boolean states
        if (storedEditProfile === 'true') {
            this.isEditProfile = true;
        }

        if (storedPreferences === 'true') {
            // Force a re-render by triggering change detection
            this.isPreferencesOpen = true;
        }

        if (storedGivingPage === 'true') {
            this.isGivingPageActive = true;
        }

        if (storedProfileOverview === 'true') {
            this.isProfileOverview = true;
        }

        if (storedDirectoryTab) {
            this.alumniDirectoryDefaultTab = storedDirectoryTab;
        }

        if (storedCardId) {
            this.selectedCardId = storedCardId;
        }

        if (storedLastActiveTab) {
            this.lastActiveTab = storedLastActiveTab;
        }

        // Determine activeTab based on which view is active
        if (this.isEditProfile || this.isPreferencesOpen || this.isGivingPageActive) {
            // If any of these modal/overlay views are active, set activeTab to empty
            this.activeTab = '';

            // Publish 'none' message
            if (this.messageContext) {
                const message = { selectedItem: 'none' };
                publish(this.messageContext, NAVIGATION_CHANNEL, message);
            }
        } else if (this.isProfileOverview) {
            // If profile overview is active, restore the last active tab
            this.activeTab = '';
            if (storedLastActiveTab) {
                this.lastActiveTab = storedLastActiveTab;
            }

            // Publish 'none' message since we're in profile view
            if (this.messageContext) {
                const message = { selectedItem: 'none' };
                publish(this.messageContext, NAVIGATION_CHANNEL, message);
            }
        } else {
            // None of the overlay views are active, restore normal tab
            if (storedActiveTab) {
                this.activeTab = storedActiveTab;

                // Publish navigation message with active tab
                if (this.messageContext) {
                    const message = { selectedItem: storedActiveTab };
                    publish(this.messageContext, NAVIGATION_CHANNEL, message);
                }
            }
        }
    }

    /**
     * @description Saves the current component state to localStorage
     */
    saveStateToLocalStorage() {
        sessionStorage.setItem('ham_activeTab', this.activeTab);
        sessionStorage.setItem('ham_lastActiveTab', this.lastActiveTab);
        sessionStorage.setItem('ham_isEditProfile', this.isEditProfile.toString());
        sessionStorage.setItem('ham_isPreferencesOpen', this.isPreferencesOpen.toString());
        sessionStorage.setItem('ham_isGivingPageActive', this.isGivingPageActive.toString());
        sessionStorage.setItem('ham_isProfileOverview', this.isProfileOverview.toString());
        sessionStorage.setItem('ham_alumniDirectoryDefaultTab', this.alumniDirectoryDefaultTab);
        // Store selectedCardId (handle null/undefined values)
        if (this.selectedCardId) {
            sessionStorage.setItem('ham_selectedCardId', this.selectedCardId);
        } else {
            sessionStorage.removeItem('ham_selectedCardId'); // Clear if no card selected
        }
    }

    /**
     * @description Saves the current component state to localStorage
     */
    resetLocalStorage() {

        sessionStorage.clear();
        // sessionStorage.setItem('ham_activeTab', this.label.hometitle);
        // sessionStorage.setItem('ham_lastActiveTab', '');
        // sessionStorage.setItem('ham_isEditProfile', '');
        // sessionStorage.setItem('ham_isPreferencesOpen', '');
        // sessionStorage.setItem('ham_isGivingPageActive', '');
        // sessionStorage.setItem('ham_isProfileOverview', '');
        // sessionStorage.setItem('ham_alumniDirectoryDefaultTab', '');
        // sessionStorage.setItem('ham_selectedCardId', '');
    }



    /**
     * @description Subscribes to the MyImpact message channel to receive tab change events.
     * Prevents duplicate subscriptions by checking if one already exists.
     */
    subscribeToMessageChannel() {
        if (!this.subscription) {
            this.subscription = subscribe(
                this.messageContext,
                HEADER_CHANNEL,
                (message) => this.handleMessage(message)
            );
        }
    }

    /**
     * @description Method to process the subscribed data and set the active tab
     * message : contains the active tab value
     */
    handleMessage(message) {
        window.scrollTo({ top: 0, behavior: 'instant' });

        this.activeTab = message.buttonLabel;
        this.opportunityActiveTab = this.activeTab == this.label.volunteerOpportunity ? this.label.volunteerOpportunity : '';



        // update the URL based on the tab clicked
        const urlViewString = this.tabToUrlMap[this.activeTab] || 'home';
        this.updateBrowserUrl(urlViewString);

        if (this.activeTab == this.label.alumnidirectory) {
            this.alumniDirectoryDefaultTab = this.label?.buildCommunity || 'Search Directory';
        }
        this.isEditProfile = false;
        this.isGivingPageActive = false;
        this.isPreferencesOpen = false;
        this.isProfileOverview = false;

        // Clear selectedCardId when navigating away
        this.selectedCardId = null;

        // --- Broadcast the active tab back to the Header so it updates its highlight ---
        if (this.messageContext) {
            const navMessage = { selectedItem: this.activeTab };
            publish(this.messageContext, NAVIGATION_CHANNEL, navMessage);
        }

        // Save state after changes
        this.saveStateToLocalStorage();
    }

    /**
   * @description Handles custom event from child component and publishes the selected 
   * item to other components via Lightning Message Service.
   * * @param {Object} event - Custom event from child component containing selected item
   */
    handleNavigateVolunteerService(event) {
        window.scrollTo({ top: 0, behavior: 'instant' });
        this.activeTab = event.detail.currentTab;

        this.opportunityActiveTab = this.activeTab == this.label?.volunteerOpportunity ? event.detail.volActiveTab : 'Volunteer Service';

        // update the URL
        const urlViewString = this.tabToUrlMap[this.activeTab] || 'home';
        this.updateBrowserUrl(urlViewString);

        this.isEditProfile = false;
        const message = {
            selectedItem: event.detail.currentTab
        }
        publish(this.messageContext, NAVIGATION_CHANNEL, message);
        this.alumniDirectoryDefaultTab = this.label.buildCommunity
        // Save state after changes
        this.saveStateToLocalStorage();
    }


    /**
    * @description Handles custom event from child component and publishes the selected 
    * item to other components via Lightning Message Service.
    * * @param {Object} event - Custom event from child component containing selected item
    */
    navigateMyImpact(event) {
        window.scrollTo({ top: 0, behavior: 'instant' });
        this.activeTab = event.detail;
        // ─── Intercept: News widget on Home → Community tab > News sub-tab ───
        if (this.activeTab === this.label.news) {
            this.activeTab = this.label.community;
            this.communitySubTab = this.label.news;   // primed BEFORE isCommunityActive flips true

            this.isEditProfile = false;
            this.isGivingPageActive = false;
            this.isPreferencesOpen = false;
            this.isProfileOverview = false;

            // Build URL: ?view=community&tab=<newsLabelValue>
            const url = new URL(window.location.href);
            url.searchParams.set('view', 'community');
            url.searchParams.set('tab', this.communitySubTab);
            url.searchParams.delete('groupId');
            url.searchParams.delete('subview');
            url.searchParams.delete('cardId');
            // One-shot notification deep-link params — clear on navigation
            url.searchParams.delete('postId');
            url.searchParams.delete('commentId');
            url.searchParams.delete('resourceId');
            url.searchParams.delete('mode');
            window.history.pushState({}, '', url.toString());

            publish(this.messageContext, NAVIGATION_CHANNEL, { selectedItem: this.label.community });
            this.saveStateToLocalStorage();
            return;   // ← skip the original routing below
        }

        this.opportunityActiveTab = this.activeTab == this.label?.volunteerOpportunity ? event.detail : 'Volunteer';

        // update the URL
        const urlViewString = this.tabToUrlMap[this.activeTab] || 'home';
        this.updateBrowserUrl(urlViewString);

        this.isEditProfile = false;
        const message = {
            selectedItem: event.detail
        }
        publish(this.messageContext, NAVIGATION_CHANNEL, message);
        this.alumniDirectoryDefaultTab = this.label.buildCommunity
        // Save state after changes
        this.saveStateToLocalStorage();
    }


    /**
     * @description Lifecycle hook that runs when the component is removed from the DOM.
     * It removes event listeners to prevent memory leaks.
     */
    disconnectedCallback() {
        clearTimeout(this._spinnerTimeout);

        // Remove event listener when component is removed from DOM
        window.removeEventListener('resize', this.handleResize.bind(this));

        // remove event listener for clicks outside the component
        document.removeEventListener('click', this._handleOutsideClick);

        window.removeEventListener('popstate', this._handlePopState);

        //Unsubscribes from the message channel when component is destroyed.
        this.unsubscribeToMessageChannel();
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
     * @description Fires when the user clicks the Browser's Back or Forward arrow
     */
    handlePopState() {
        // Re-run URL checker to update the screen to match the previous URL
        this.checkUrlForDeepLink();
        this.saveStateToLocalStorage();
    }

    /**
     * @description Wire method to fetch 'My Links' from Custom Metadata.
     * It maps the data into a more usable format for the template.
     * @param {Object} wiredMyLinks The wired result object.
     */
    @wire(getMyLinksMetaData)
    wiredMyLinks({ error, data }) {
        if (data) {
            this.myLinks = data.map(item => ({
                id: item.id,
                label: item.HAM_Display_Label__c,
                value: item.HAM_Redirect_Link__c
            }));
        } else if (error) {
            console.error('Error fetching My Links metadata:', error);
        }
    }

    /**
     * @description Wire method to fetch the logged-in user's Contact ID.
     * @param {Object} wiredLoggedInUserInfo The wired result object.
     */
    /*@wire(fetchLoggedInUserInfo)
    wiredLoggedInUserInfo({ error, data }) {
        if (data) {
            this.currentUserContactId = data;
        } else if (error) {
            console.error('<<fetchLoggedInUserInfo Error>>', data);
        }
    }*/


    /**
     * @description Wire method to fetch the logged-in user's Contact Record directly from Apex.
     * This replaces getRecord to bypass managed package UI API errors.
     */
    @wire(fetchLoggedInUserInfo)
    wiredLoggedInUserInfo(result) {
        this.wiredResult = result; // Keep this so refreshApex still works
        const { error, data } = result;

        if (data) {
            // Data is now the full Contact object
            this.currentUserContactId = data.Id;
            this.userName = data.Name;
            this.userFirstName = data.FirstName;
            this.userProfileUrl = data.HAM_Profile_Picture_URL__c;
            this.userBirthday = data.Birthdate;
            this.contactClassYear = data.HAM_Reunion_Year__c;

            // Determine if the logged-in user is a student
            const primaryContactType = data.ucinn_ascendv2__Primary_Contact_Type__c || '';
            this.isStudent = primaryContactType === 'Student';

            // Safely parse the Ascend picklist field
            const contactTypeValue = data.ucinn_ascendv2__Contact_Type__c || '';
            this.isKirklandAlumnae = contactTypeValue.split(';').includes('Kirkland Alumnae');

            this.isOverride = !this.isStudent && data.Hamilton_Portal_Override__c === true;

            this.isLoading = false;
            // Header is now mounted and subscribed — safe to restore navigation state
            if (!this._isDeepLinked) {
                this.restoreStateFromLocalStorage();
            }
        } else if (error) {
            console.error('<<fetchLoggedInUserInfo Error>>', error);
            this.isLoading = false; // Unblock UI even on error
        }
    }

    /**
     * @description Wire service to fetch the contact's profile picture URL, name, and birthday.
     */
    /*@wire(getRecord, { recordId: '$currentUserContactId', fields: [PROFILE_PIC_FIELD, NAME_FIELD, BIRTHDAY_FIELD, CLASS_YEAR,CONTACT_TYPE_FIELD] })
    wiredContactRecord(result) {
        this.wiredResult = result;
        const { error, data } = result;

        if (data) {
            this.userProfileUrl = getFieldValue(data, PROFILE_PIC_FIELD);
            this.userName = getFieldValue(data, NAME_FIELD);
            this.userBirthday = getFieldValue(data, BIRTHDAY_FIELD);
            this.contactClassYear = getFieldValue(data,CLASS_YEAR);
            const contactTypeValue = getFieldValue(data, CONTACT_TYPE_FIELD) || '';
            this.isKirklandAlumnae = (contactTypeValue || '').split(';').includes('Kirkland Alumnae');
        } else if (error) {
            console.error('Error fetching contact record:', error);
        }
    }*/


    /**
     * @description wire service to toggle the givingapp component and redirect to make a gift link website
     */
    @wire(getGivingAppStatus)
    wiredGivingAppStatus({ error, data }) {
        if (data !== undefined) {
            this.isGivingAppLive = data;

            // Safety Check: If a user copied/pasted a deep link (?view=gift) 
            // but the app is currently down, redirect them and reset the view to Home.
            if (!this.isGivingAppLive && this.isGivingPageActive) {
                this.isGivingPageActive = false;
                this.activeTab = this.label.hometitle;
                window.open(this.label.makeagiftlink, '_blank');
            }
        } else if (error) {
            console.error('Error fetching Giving App Status:', error);
        }
    }

    @wire(getRegisteredUsersCount)
    wiredRegisteredUsersCount({ error, data }) {
        if (data !== undefined) {
            this.registeredUsersCount = data;
        } else if (error) {
            console.error('Error fetching registered users count:', error);
        }
    }

    /**
     * @description Computed property to apply an 'active' class to the 'Home' tab.
     * @returns {string} The CSS class string.
     */
    get computeHomeStyle() {
        return this.activeTab == this.label.hometitle ? this.images.mobileHomeOn : this.images.mobileHomeOff;
    }

    /**
     * @description Computed property to apply an 'active' class to the 'My Impact' tab.
     * @returns {string} The CSS class string.
     */
    get computeMyImpactStyle() {
        return this.activeTab == this.label.myimpact ? this.images.mobileImpactOn : this.images.mobileImpactOff;
    }

    /**
     * @description Computed property to apply an 'active' class to the 'Directory' tab.
     * @returns {string} The CSS class string.
     */
    get computealumnidirectory() {
        return this.activeTab == this.label.alumnidirectory ? this.images.mobileDirectoryOn : this.images.mobileDirectoryOff;
    }

    /**
     * @description Computed property to apply an 'active' class to the 'News' tab.
     * @returns {string} The CSS class string.
     */
    get computeNewsStyle() {
        return this.activeTab == this.label.news ? this.images.mobileNewsOn : this.images.mobileNewsOff;
    }

    /**
     * @description Computed property to apply an 'active' class/image to the 'Community' tab.
     * @returns {string} The image URL string.
     */
    get computeCommunityStyle() {
        // return this.activeTab == this.label.community ? this.images.mobileCommunityOn : this.images.mobileCommunityOff;
        return this.activeTab == this.label.community ? this.images.mobileNewsOn : this.images.mobileNewsOff;
    }


    /**
     * @description Computed property to apply an 'active' class to the 'Events' tab.
     * @returns {string} The CSS class string.
     */
    get computeEventsStyle() {
        return this.activeTab == this.label.events ? this.images.mobileEventsOn : this.images.mobileEventsOff;
    }

    /**
     * @description Computed property for the student-only 'Groups' mobile tab active state.
     * @returns {string} CSS class string.
     */
    get isGroupsTabActive() {
        return this.activeTab === this.label.groups ? 'footer-nav-groups-active' : '';
    }

    get isCommunityActive() {
        return this.activeTab === this.label.community && !this.isEditProfile && !this.isPreferencesOpen && !this.isGivingPageActive && !this.isProfileOverview;
    }


    /**
     * @description Handles clicks on the main navigation links, updating the active tab.
     * @param {Event} event The click event.
     */
    handleNavLinkClick(event) {
        event.preventDefault(); // Prevent default link behavior (page reload)
        const clickedTabName = event.target.dataset.name;
        if (clickedTabName) {
            this.activeTab = clickedTabName; // Set the clicked tab as active
            this.isEditProfile = false;
            this.isPreferencesOpen = false;

            // Save state after changes
            this.saveStateToLocalStorage();
        }
    }


    // Getters for conditional rendering of my impact component visibility flag
    get isHomeView() {
        return this.activeTab === this.label.hometitle && !this.isEditProfile && !this.isPreferencesOpen && !this.isGivingPageActive && !this.isProfileOverview;
    }

    // Getters for conditional rendering of my impact component visibility flag
    get isMyImpactActive() {
        return this.activeTab === this.label.myimpact && !this.isEditProfile && !this.isPreferencesOpen && !this.isGivingPageActive && !this.isProfileOverview;;
    }

    // Getters for conditional rendering of events component visibility flag
    get isEventsActive() {
        return this.activeTab === this.label.events && !this.isEditProfile && !this.isPreferencesOpen && !this.isGivingPageActive && !this.isProfileOverview;;
    }

    // Getters for conditional rendering of news component visibility flag
    get isNewsActive() {
        return this.activeTab === this.label.news && !this.isEditProfile && !this.isPreferencesOpen && !this.isGivingPageActive && !this.isProfileOverview;;
    }


    // Getters for conditional rendering of Alumni Directory component visibility flag
    get isAlumniDirectoryActive() {
        return this.activeTab === this.label.alumnidirectory && !this.isEditProfile && !this.isPreferencesOpen && !this.isGivingPageActive && !this.isProfileOverview;;
    }

    // Getters for conditional rendering of profileOverview component visibility flag
    // get isProfileOverviewActive() {
    //     return this.activeTab === this.label.hometitle && this.isProfileOverview && !this.isEditProfile && !this.isPreferencesOpen && !this.isGivingPageActive;
    // }


    navigateDirectory(event) {
        this.alumniDirectoryDefaultTab = event.detail;
        // Save state after changes
        this.saveStateToLocalStorage();
    }

    // Getters for conditional rendering of volunteer opportunity component visibility flag
    get isVolunteerOppActive() {
        return this.activeTab === this.label.volunteerOpportunity && !this.isEditProfile && !this.isPreferencesOpen && !this.isGivingPageActive && !this.isProfileOverview;;
    }

    // Getter for conditional rendering of groups component (student-only nav tab)
    get isGroupsActive() {
        return this.activeTab === this.label.groups && !this.isEditProfile && !this.isPreferencesOpen && !this.isGivingPageActive && !this.isProfileOverview;
    }

    // Getters for conditional rendering of desktop screen flag
    get mainWrapperClass() {
        return this.isOverride ? 'main-component-parent-class kirkland-override' : 'main-component-parent-class';
    }

    get isDesktopView() {
        // Define desktop breakpoint (e.g., 769px or more)
        return this.screenWidth >= 1024;
    }

    // Getters for conditional rendering of mobile screen flag
    get isMobileView() {
        return this.screenWidth < 1024;
    }
    get isMobileViewForBottomNav() {
        return this.screenWidth < 1024;
    }

    /**
     * to be removed later on confirmation
    * @description Handles clicks on the settings icon, toggling the dropdown menu.
    * It also ensures the other dropdown is closed.
    * @param {Event} event The click event.
    */
    handleSettingsClick(event) {

        event.stopPropagation();
        this.isSettingsOpen = !this.isSettingsOpen;
        this.isLinksOpen = false; // Close links dropdown if open
    }

    handleCommunityTabChange(event) {
        this.communitySubTab = event.detail.tab;
        // Silently update URL to show the subtab
        const url = new URL(window.location.href);
        url.searchParams.set('tab', this.communitySubTab);
        // One-shot notification deep-link params — clear on navigation
        url.searchParams.delete('postId');
        url.searchParams.delete('commentId');
        url.searchParams.delete('resourceId');
        url.searchParams.delete('mode');

        // Navigating away from Groups (e.g. to Directory or Events) cleans up group URL params
        if (this.communitySubTab !== 'groups') {
            url.searchParams.delete('groupId');
            url.searchParams.delete('subview');
            this.selectedGroupId = null;
        }

        window.history.replaceState({}, '', url.toString());
    }

    handleGroupUrlNav(event) {
        const prevGroupId = this.selectedGroupId;
        this.selectedGroupId = event.detail.groupId;
        this.groupSubview = event.detail.subview || 'dashboard';

        // Update URL params for Groups deep links
        const url = new URL(window.location.href);
        // Drop one-shot notification deep-link params on any user navigation: they are
        // only meant for the initial page load (ham_groupFeed reads them once to
        // scroll/highlight). Leaving them in the URL re-triggered the auto-scroll
        // every time a group feed re-mounted.
        url.searchParams.delete('postId');
        url.searchParams.delete('commentId');
        url.searchParams.delete('resourceId');
        url.searchParams.delete('mode');
        if (this.selectedGroupId) {
            url.searchParams.set('groupId', this.selectedGroupId);
            url.searchParams.set('subview', this.groupSubview);
        } else {
            url.searchParams.delete('groupId');
            url.searchParams.delete('subview');
        }

        if (prevGroupId && this.selectedGroupId && prevGroupId === this.selectedGroupId) {
            window.history.replaceState({}, '', url.toString());
        } else {
            window.history.pushState({}, '', url.toString());
        }
    }

    /**
     * @description Handles clicks on items within the settings dropdown menu.
     * It redirects the user or opens the edit profile modal based on the clicked item.
     * @param {Event} event The click event on a menu item.
     */
    handleSettingsMenuClick(event) {
        let eventFrom = event.currentTarget.dataset.name;
        this.isSettingsOpen = false;
        // Conditionally do the redirection using Nav Mixin
        if (eventFrom == 'managesub') {
            this.handleManageSubscriptionClick();
        }
        else if (eventFrom == 'editprof') {
            // Render ham_editProfileCmp component
            this.isEditProfile = true;
        }
        else if (eventFrom == 'logout') {
            window.open(this.label.logoutlink, '_self');
        }
    }

    /**
     * @description Handles clicks on the 'My Links' dropdown header, toggling the menu.
     * It also ensures the settings dropdown is closed.
     * @param {Event} event The click event.
     */
    handleLinksClick(event) {
        event.stopPropagation();
        this.isLinksOpen = !this.isLinksOpen;
    }

    /**
     * @description Prevents the click event from propagating to the document,
     * which would otherwise close the dropdown.
     * @param {Event} event The click event.
     */
    handleDropdownClick(event) {
        this.isLinksOpen = false;
        event.stopPropagation();
    }

    /**
     * @description Global event handler to close dropdowns when a user clicks outside the component.
     * @param {Event} event The document click event.
     */
    handleOutsideClick(event) {
        const clickedInside = this.template.contains(event.target);

        if (!clickedInside) {
            this.isLinksOpen = false;
        }

    }

    handleMakeGiftEvent() {
        // Check if the Custom Metadata "Kill Switch" says the app is live
        if (this.isGivingAppLive) {
            // -- APP IS LIVE:
            //update the URL for the gift page
            this.updateBrowserUrl('gift');
            this.isEditProfile = false;
            this.isProfileOverview = false;
            this.isPreferencesOpen = false;
            this.isGivingPageActive = true;

            this.activeTab = '';
            const message = {
                selectedItem: 'none'
            }
            publish(this.messageContext, NAVIGATION_CHANNEL, message);
            // Save state after changes
            this.saveStateToLocalStorage();
        } else {
            // -- APP IS DOWN: Redirect to external URL in a new tab --
            // We use window.open with '_blank' to open in a new tab
            window.open(this.label.makeagiftlink, '_blank');
        }
    }

    // Handle Profile Overview Cmp
    handleProfileOverview(event) {

        this.isPreferencesOpen = false;
        this.isEditProfile = false;
        this.isGivingPageActive = false;
        this.isProfileOverview = true;
        this.selectedCardId = event.detail.selectedContactId;
        this.alumniDirectoryDefaultTab = event.detail.directoryPreviousTab;
        this.searchKeyToApex = event.detail.searchKeyToApex;
        this.savedFilters = event.detail.savedFilters;
        this.primarykeyset = event.detail.primarykeyset;
        this.secondarykeyset = event.detail.secondarykeyset;
        this.recordsToSkip = event.detail.recordsToSkip;
        this.directoryView = event.detail.view;
        // Relay whether the user had modified filters so retrigger can honour points 1-4 vs 5.
        this.userHasModifiedFilters = event.detail.userHasModifiedFilters === true;
        // Preserve the Search Directory initial-filters snapshot across the re-mount.
        this.initialDirectoryFilters = event.detail.initialDirectoryFilters
            ? [...event.detail.initialDirectoryFilters]
            : null;
        this.lastActiveTab = this.activeTab;
        this.activeTab = '';

        // Push URL with both parameters
        this.updateBrowserUrl('profileoverview', this.selectedCardId);

        const message = {
            selectedItem: 'none'
        }
        publish(this.messageContext, NAVIGATION_CHANNEL, message);
        // Save state after changes
        this.saveStateToLocalStorage();
    }
    /**
    * @description Closes the alumni profile overview modal.
    */
    handleProfileClose() {

        // Set the flag BEFORE making alumniDisplayCmp visible. The child reads this
        // in connectedCallback (which runs before wires) to block the wires from
        // applying saved/default filters to the wrong tab.
        sessionStorage.setItem('ham_returningFromProfile', 'true');

        this.isProfileOverview = false; // Close profile overview — component re-mounts
        this.selectedCardId = null;

        if (this.lastActiveTab == this.label.hometitle && this.screenWidth < 1024) {
            this.alumniDirectoryDefaultTab = this.label?.buildCommunity || 'Search Directory';
        }

        this.activeTab = sessionStorage.getItem('ham_lastActiveTab') || this.label.hometitle;

        // ALWAYS call retrigger on Back — even when no search/filters/view were active.
        // Without this, isRestoringFilters is never set and the wires run unguarded on
        // the freshly re-mounted alumniDisplayCmp, applying saved/default filters to
        // whichever tab the user was on (e.g. My Connections), which is wrong.
        // setTimeout (macrotask) is used instead of Promise.resolve().then() (microtask)
        // because the microtask fires before LWC has finished mounting ham_alumniDisplayCmp,
        // causing querySelector to return null and retrigger to silently no-op,
        // which leaves _initialDirectoryFilters unset and filters unrestored on tab return.
        setTimeout(() => {
            this.retriggerAlumniDisplayCmpWires();
        }, 0);

        // Restore the URL for the previous tab
        const urlViewString = this.tabToUrlMap[this.activeTab] || 'home';
        this.updateBrowserUrl(urlViewString);

        const message = {
            selectedItem: this.activeTab
        }
        publish(this.messageContext, NAVIGATION_CHANNEL, message);

        // Save state after clearing selectedCardId
        this.lastActiveTab = '';
        this.saveStateToLocalStorage();
    }

    /**
     * @description If searchKeytoApex or savedFilters exist, re-trigger wires on alumniDisplayCmp
     */
    retriggerAlumniDisplayCmpWires() {

        const alumniDisplayCmp = this.template.querySelector('c-ham_alumni-display-cmp');

        if (alumniDisplayCmp) {
            alumniDisplayCmp.retriggerDirectoryCountAndDataWires(
                this.searchKeyToApex,
                this.savedFilters,
                this.primarykeyset,
                this.secondarykeyset,
                this.recordsToSkip,
                this.directoryView,
                this.userHasModifiedFilters,   // 7th: was filter changed before profile nav?
                this.initialDirectoryFilters   // 8th: Search Directory snapshot to restore
            );
        }
    }

    /**
     * @description Handles the Preferences click event.
     */
    handlePreferencesClick() {
        // update the URL for preferences
        this.updateBrowserUrl('preferences');

        // Close other views
        this.isEditProfile = false;
        this.isProfileOverview = false;
        this.isGivingPageActive = false;
        // Open Preferences
        this.isPreferencesOpen = true;
        this.activeTab = '';
        const message = {
            selectedItem: 'none'
        }
        publish(this.messageContext, NAVIGATION_CHANNEL, message);
        // Scroll to top
        window.scrollTo({ top: 0, behavior: 'instant' });

        // Save state after changes
        this.saveStateToLocalStorage();
    }

    handleEditProfile() {
        // update the URL for edit profile
        this.updateBrowserUrl('editprofile');
        this.isEditProfile = true;
        this.isPreferencesOpen = false;
        this.isProfileOverview = false;
        this.isGivingPageActive = false;
        this.activeTab = '';
        const message = {
            selectedItem: 'none'
        }
        publish(this.messageContext, NAVIGATION_CHANNEL, message);
        // Save state after changes
        this.saveStateToLocalStorage();
    }

    handleLogout() {
        // this.resetLocalStorage();
        // window.open(this.label.logoutlink, '_self');

        this.resetLocalStorage();

        const url = new URL(window.location.href);
        url.search = '';
        window.history.replaceState({}, '', url.toString());

        if (this.screenWidth >= 1024) {
            window.open(this.label.logoutlink, '_self');
        }
        if (this.screenWidth < 1024) {
            window.location.replace(this.label.logoutlink);
        }
    }

    /**
     * @description Handles the event to close the edit profile modal.
     * It also restores body scrolling.
     */
    handleEditProfileClose() {
        this.isEditProfile = false;
    }

    /**
     * @description Toggles the visibility of the mobile menu.
     */
    toggleMobileMenu() {
        this.isMobileMenuOpen = !this.isMobileMenuOpen;
    }

    /**
     * @description Handles clicks on items within the mobile menu.
     * It directs the user to different sections or external links.
     * @param {Event} event The click event.
     */
    handleMobileMenuItemClick(event) {
        const clickedItemName = event.currentTarget.dataset.name;
        if (clickedItemName === this.label.hometitle ||
            clickedItemName === this.label.myimpact ||
            clickedItemName === this.label.alumnidirectory ||
            clickedItemName === this.label.news ||
            clickedItemName === this.label.events ||
            clickedItemName === this.label.groups ||
            clickedItemName === this.label.community) {

            if (clickedItemName === this.label.alumnidirectory && this.screenWidth < 1024) {
                this.alumniDirectoryDefaultTab = this.label?.buildCommunity || 'Search Directory';
            }
            // Reset group state when navigating to the Groups tab so it always opens to discovery
            if (clickedItemName === this.label.groups) {
                this.selectedGroupId = null;
                this.groupSubview = null;
            }
            this.activeTab = clickedItemName; // Update active tab for content display
            const urlViewString = this.tabToUrlMap[this.activeTab] || 'home';
            this.updateBrowserUrl(urlViewString);
            this.isEditProfile = false;
            this.isPreferencesOpen = false;
            this.isGivingPageActive = false;
            this.isProfileOverview = false;
            const message = {
                selectedItem: clickedItemName
            }
            publish(this.messageContext, NAVIGATION_CHANNEL, message);
            this.saveStateToLocalStorage();
        } else if (clickedItemName === this.label.editprofile) {
            this.isEditProfile = true;
        } else if (clickedItemName === this.label.logout) {
            window.open(this.label.logoutlink, '_self');
        } else if (clickedItemName === this.label.managesubscription) {
            this.handlePreferencesClick();
        } else {
            const myLinkItem = this.myLinks.find(link => link.value === clickedItemName);
            if (myLinkItem && myLinkItem.value) {
            }
        }
        this.isMobileMenuOpen = false; // Close the menu after any item click
    }

    /**
     * @description Handles navigation events from child widgets.
     * @param {Event} event The custom navigate event.
     */
    handleWidgetNavigation(event) {
        const target = event.detail;
        this.isEditProfile = false;
        this.isPreferencesOpen = false;
        if (target === 'my_impact') {
            this.activeTab = this.label.myimpact;
            this.updateBrowserUrl('impact');
        } else if (target === 'directory') {
            this.activeTab = this.label.alumnidirectory;
            this.updateBrowserUrl('directory');
        }
    }

    /**
     * @description Handles navigation from the Groups widget on the homepage.
     * @param {Event} event Event containing groupId and optional searchTerm.
     */
    handleWidgetViewGroup(event) {
        window.scrollTo({ top: 0, behavior: 'instant' });
        this.activeTab = this.label.community;
        this.communitySubTab = 'Groups';
        this.selectedGroupId = event.detail.groupId;
        this.groupSubview = this.selectedGroupId ? 'dashboard' : null;

        // Reset overlay states
        this.isEditProfile = false;
        this.isGivingPageActive = false;
        this.isPreferencesOpen = false;
        this.isProfileOverview = false;
        this.selectedCardId = null;

        // Update URL params
        const url = new URL(window.location.href);
        url.searchParams.set('view', 'community');
        url.searchParams.set('tab', 'Groups');
        // One-shot notification deep-link params — clear on navigation
        url.searchParams.delete('postId');
        url.searchParams.delete('commentId');
        url.searchParams.delete('resourceId');
        url.searchParams.delete('mode');

        if (this.selectedGroupId) {
            url.searchParams.set('groupId', this.selectedGroupId);
            url.searchParams.set('subview', this.groupSubview);
            url.searchParams.delete('gSearch');
        } else {
            url.searchParams.delete('groupId');
            url.searchParams.delete('subview');
            if (event.detail.searchTerm) {
                url.searchParams.set('gSearch', event.detail.searchTerm);
            } else {
                url.searchParams.delete('gSearch');
            }
        }
        window.history.pushState({}, '', url.toString());

        // Publish event to navigation channel
        if (this.messageContext) {
            publish(this.messageContext, NAVIGATION_CHANNEL, { selectedItem: this.label.community });
        }

        this.saveStateToLocalStorage();
    }

    /**
     * @description Handles navigation events from home to volunteer tab.
     * @param {Event} event The custom navigate event.
     */

    handleNavigateVolunteer(event) {
        this.activeTab = this.label.myimpact;
        this.isEditProfile = false;
        this.isPreferencesOpen = false;
        this.isGivingPageActive = false;
        window.scrollTo({ top: 0, behavior: 'instant' });
        Promise.resolve().then(() => {
            const childComponent = this.refs.myImpactComponent;
            if (childComponent) {
                childComponent.handleVolunteerHomeClick(event.detail);
            }
        });
    }

    /**
     * @description Handles profileupdated events from edit profile to other components.
     * @param {Event} event The custom  event.
     */
    handleProfileUpdated(event) {
        const isUpdated = event.detail.isprofileupdated;

        // Example: refresh wire
        if (isUpdated && this.wiredResult) {
            refreshApex(this.wiredResult);
        }

        if (event.detail.isprofileupdated) {
            this.profileUpdatedToken = Date.now();
        }

        this.profileUpdatedToken = Date.now();


    }

    handleResetFlag() {
        this.isProfileUpdated = false;
        this.profileUpdatedToken = '';
    }

    // Capture the data sent from the child component
    handleBadgesLoaded(event) {
        this.parentBadgesArray = event.detail;
    }

    handleScrollToSection(event) {
        const sectionId = event.detail;
        const target = this.template.querySelector(`[data-section-id="${sectionId}"]`);
        if (target) {
            target.scrollIntoView({ behavior: 'smooth', block: 'start' });
        }
    }
}