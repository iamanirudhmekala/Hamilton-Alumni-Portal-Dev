import { LightningElement, api, track,wire } from 'lwc';
import handleConnectionRequest from '@salesforce/apex/HAM_AlumniConnectionService.handleConnectionRequest';
import checkUserStatus from '@salesforce/apex/HAM_AlumniConnectionService.checkUserStatus';
import HAM_ICONS from '@salesforce/resourceUrl/HAM_Icons';

// Import custom labels
import MyConnection from '@salesforce/label/c.HAM_My_Connections';
import BookmarkedProfile from '@salesforce/label/c.HAM_Bookmarked_Profiles';
import BuildCommunity from '@salesforce/label/c.HAM_Build_Community';
import SendRequest from '@salesforce/label/c.HAM_Send_Request';
import RemoveBookmark from '@salesforce/label/c.HAM_Remove_Bookmark';
import RemoveCoonection from '@salesforce/label/c.HAM_Remove_Connection';
import CancelRequest from '@salesforce/label/c.HAM_Cancel_Request';
import ActionSRHeader from '@salesforce/label/c.HAM_Personal_Mess';
import ActionSRPrimaryBtn from '@salesforce/label/c.HAM_Primary_Btn';
import ActionSRSecondaryBtn from '@salesforce/label/c.HAM_Secondary_Button';
import ActionRBMHeader from '@salesforce/label/c.HAM_Remove_Bookmark_Header';
import ActionRBMPrimaryBtn from '@salesforce/label/c.HAM_Primary_Button_RBM';
import ActionRCHeader from '@salesforce/label/c.HAM_Remove_Conn';
import ActionRCSecondaryBtn from '@salesforce/label/c.HAM_Secondry_Button';
import ConnectionTabMessage from '@salesforce/label/c.HAM_Conn_Msg';
import BookmarkedTabMessage from '@salesforce/label/c.HAM_Bookmark_Msg';
import BuildCommTabMessage from '@salesforce/label/c.HAM_Build_Comm_Msg';
import ManageInvitation from '@salesforce/label/c.HAM_Manage_Invitations';
import NoInvitationPending from '@salesforce/label/c.HAM_Inn_Pending_ALDC';
import NoSentRequests from '@salesforce/label/c.HAM_No_Sent_Requests';
import NoSearchResults from '@salesforce/label/c.HAM_No_Search_Results';
import ViewProfile from '@salesforce/label/c.ham_viewProfile';
import InvitationExist from '@salesforce/label/c.ham_InvitationExist';
import BlockProfile from '@salesforce/label/c.ham_blockProfile';
import unBlockProfile from '@salesforce/label/c.HAM_Unblock_Profile';
import blockedProfiles from '@salesforce/label/c.HAM_Blocked_Profiles';
import noBlockedProfiles from '@salesforce/label/c.HAM_No_Blocked_Profiles';
import unblockProfileHeader from '@salesforce/label/c.HAM_Unblock_Profile_Header';
import unblockProfileButton from '@salesforce/label/c.HAM_Unblock_Profile_Button';
import InActiveUserMessage from '@salesforce/label/c.ham_inactiveUserMessage';
import BookmarkHoverText from '@salesforce/label/c.HAM_bookmarkHoverText';
import FavoriteHoverText from '@salesforce/label/c.HAM_favoriteHoverText';
import SendRequestHoverText from '@salesforce/label/c.HAM_sendRequestHoverText';
import CancelRequestHoverText from '@salesforce/label/c.HAM_cancelRequestHoverText';
import RemoveConnectionHoverText from '@salesforce/label/c.HAM_removeConnectionHoverText';
import AcceptHoverText from '@salesforce/label/c.HAM_acceptHoverText';
import RejectHoverText from '@salesforce/label/c.HAM_rejectHoverText';
import BlockHoverText from '@salesforce/label/c.ham_blockHoverText';
import RemoveBookmarkHoverText from '@salesforce/label/c.ham_removeBookmarkHoverText';
import RemoveFavoriteHoverText from '@salesforce/label/c.HAM_removeFavoriteHoverText';
import UnBlockHoverText from '@salesforce/label/c.HAM_unblockHoverText';
import ViewProfileHoverText from '@salesforce/label/c.HAM_viewProfileHoverText';
import ToastMessageReqSend from '@salesforce/label/c.ham_ToastMessage_ReqSend';
import ToastMessageCancelReq from '@salesforce/label/c.ham_ToastMessage_CancelReq';
import ToastMessageBookmarked from '@salesforce/label/c.ham_ToastMessage_Bookmarked';
import ToastMessageRemoveBookmarked from '@salesforce/label/c.ham_ToastMessage_Removed_Bookmarked';
import ToastMessageFavorite from '@salesforce/label/c.ham_ToastMessage_Favorite';
import ToastMessageRemoveFavorite from '@salesforce/label/c.ham_ToastMessage_RemoveFavorite';
import ToastMessageBlock from '@salesforce/label/c.ham_ToastMessage_Block';
import ToastMessageUnblock from '@salesforce/label/c.ham_ToastMessage_Unblock';
import NecrologyTitle from '@salesforce/label/c.ham_necrologyTitle';
import NecrologyHelpText from '@salesforce/label/c.ham_necrologyHelpText';
import NecrologyLink from '@salesforce/label/c.ham_necrologyLink';



// Action types used for buttons and requests
const ACTIONS = {
    SEND_REQUEST: SendRequest,
    REMOVE_BOOKMARK: RemoveBookmark,
    BOOKMARK_PROFILE: 'Bookmark',
    REMOVE_CONNECTION: RemoveCoonection,
    CANCEL_REQUEST: CancelRequest,
    FAVORITE: 'Favorite',
    REMOVE_FAVORITE: 'Remove Favorite',
    UNBLOCK_PROFILE: unBlockProfile,
    BLOCK_PROFILE: 'Block'
};

// Possible results from server/API calls
const RESULTS = {
    SUCCESS: 'Success',
    INVITATION_EXIST: 'Invitation Exist'
};

export default class Ham_alumniListDisplayCmp extends LightningElement {

    @api initialDirectoryFilters;
    @api userHasModifiedFilters;
    @api isParentLoading = false;
   

    isLoading = false;

    // Private properties
    _userContactId;
    _tab;
    _alumniList = [];
    alumniUiList = [];
    _isLoginedPortalConPrivacyOpen = false;

    // Modal & toast states
    showRequestModal = false;
    showCustomToast = false;

    // Selected action/user for modal
    clickedUser = null;
    clickedFunctiontype = null;
    personalizedMessage = '';

    // Modal button & header labels
    modalSecondaryButton = '';
    modalPrimaryButton = '';
    modalHeader = '';
    isRequestModal = false;
    showPrimaryButton = false;
    primaryButtonClass = 'primary-button';
    secondaryButtonClass = 'secondary-button';
    isInactiveUser = false;

    hamIcons = HAM_ICONS;
    @api view;

    _isOverride = false;

    @api
    get isOverride() {
        return this._isOverride;
    }
    set isOverride(value) {
        this._isOverride = value === true;
        if (this._alumniList && this._alumniList.length > 0) {
            this.processAlumniList();
        }
    }

  

    @api
    get isLoginedPortalConPrivacyOpen() {
        return this._isLoginedPortalConPrivacyOpen;
    }
    set isLoginedPortalConPrivacyOpen(value) {
        this._isLoginedPortalConPrivacyOpen = value === true;
        if (this._alumniList && this._alumniList.length > 0) {
            this.processAlumniList();
        }
    }

    // Labels object
    label = {
        myconnection: MyConnection,
        bookmarProfile: BookmarkedProfile,
        buildCommunity: BuildCommunity,
        sendRequest: SendRequest,
        removeBookmark: RemoveBookmark,
        removeConnection: RemoveCoonection,
        cancelRequest: CancelRequest,
        actionSRHeader: ActionSRHeader,
        actionSRPrimaryBtn: ActionSRPrimaryBtn,
        actionSRSecondaryBtn: ActionSRSecondaryBtn,
        actionRBMHeader: ActionRBMHeader,
        actionRBMPrimaryBtn: ActionRBMPrimaryBtn,
        actionRCHeader: ActionRCHeader,
        actionRCSecondaryBtn: ActionRCSecondaryBtn,
        connectionTabMessage: ConnectionTabMessage,
        bookmarkedTabMessage: BookmarkedTabMessage,
        buildCommTabMessage: BuildCommTabMessage,
        manageInvitation: ManageInvitation,
        noInvitationPending: NoInvitationPending,
        // [v1.4 - Anirudh] Empty-state label for the Sent sub-tab
        noSentRequests: NoSentRequests,
        noSearchResults: NoSearchResults,
        viewProfile: ViewProfile,
        invitationExist: InvitationExist,
        blockProfile: BlockProfile,
        blockedProfiles: blockedProfiles,
        noBlockedProfiles: noBlockedProfiles,
        unblockProfileHeader: unblockProfileHeader,
        unblockProfileButton: unblockProfileButton,
        inActiveUserMessage: InActiveUserMessage,
        bookmarkHoverText: BookmarkHoverText,
        favoriteHoverText: FavoriteHoverText,
        sendRequestHoverText: SendRequestHoverText,
        cancelRequestHoverText: CancelRequestHoverText,
        acceptHoverText: AcceptHoverText,
        rejectHoverText: RejectHoverText,
        blockHoverText: BlockHoverText,
        removeConnectionHoverText: RemoveConnectionHoverText,
        removeBookmarkHoverText: RemoveBookmarkHoverText,
        removeFavoriteHoverText: RemoveFavoriteHoverText,
        unBlockHoverText: UnBlockHoverText,
        viewProfileHoverText: ViewProfileHoverText,
        toastMessageReqSend: ToastMessageReqSend,
        toastMessageCancelReq: ToastMessageCancelReq,
        toastMessageBookmarked: ToastMessageBookmarked,
        toastMesgRemBookmarked: ToastMessageRemoveBookmarked,
        toastMessageFavorite: ToastMessageFavorite,
        toastMessageRemoveFavorite: ToastMessageRemoveFavorite,
        toastMessageBlock: ToastMessageBlock,
        toastMessageUnblock: ToastMessageUnblock,
        necrologyLink: NecrologyLink,
        necrologyHelpText: NecrologyHelpText,
        necrologyTitle: NecrologyTitle

    };

    images = {
        favIconEnabled: `${HAM_ICONS}/fav-fill.png`,
        favIconDisabled: `${HAM_ICONS}/fav-outline.png`,
        bookIconEnabled: `${HAM_ICONS}/bookmark-fill.png`,
        bookIconDisabled: `${HAM_ICONS}/bookmark-outline.png`,
        threeDots: `${HAM_ICONS}/dots.png`,
        threeDotsGreen: `${HAM_ICONS}/dots-green.png`,
        kirklandLogo: `${HAM_ICONS}/kirkland-icon.png`,
        person: `${HAM_ICONS}/person.png`,
        close: `${HAM_ICONS}/cross_black.png`,
        info: `${HAM_ICONS}/yellow_info.png`
    };

    get effectiveImages() {
        if (!this._isOverride) return this.images;
        return {
            ...this.images,
            favIconEnabled: `${HAM_ICONS}/fav-fill-green.png`,
            favIconDisabled: `${HAM_ICONS}/fav-outline-green.png`,
            bookIconEnabled: `${HAM_ICONS}/bookmark-fill-green.png`,
            bookIconDisabled: `${HAM_ICONS}/bookmark-outline-green.png`,
        };
    }

    get containerClass() {
        return this._isOverride ? 'directory-list kirkland-override' : 'directory-list';
    }

    get modalClass() {
        return this._isOverride ? 'modal-container kirkland-override' : 'modal-container';
    }

    // Tabs getter using labels
    get TABS() {
        return {
            CONNECTIONS: this.label.myconnection,
            BOOKMARKS: this.label.bookmarProfile,
            BUILD_COMMUNITY: this.label.buildCommunity,
            MANAGE_INVITATION: this.label.manageInvitation,
            BLOCKED_PROFILES: this.label.blockedProfiles
        };
    }

    // Tab messages getter using labels
    get TAB_EMPTY_MESSAGES() {
        return {
            [this.TABS.CONNECTIONS]: this.label.connectionTabMessage,
            [this.TABS.BOOKMARKS]: this.label.bookmarkedTabMessage,
            [this.TABS.BUILD_COMMUNITY]: this.label.buildCommTabMessage,
            [this.TABS.MANAGE_INVITATION]: this.label.noInvitationPending,
            [this.TABS.BLOCKED_PROFILES]: this.label.noBlockedProfiles
        };
    }

    /**
     * @description Lifecycle hook called when the component is inserted into the DOM.
     *              It binds the document click handler to manage dropdowns and modal behavior.
     */
    connectedCallback() {
        this._boundClick = this.handleDocumentClick.bind(this);
        this.addEventListener('click', this._boundClick);
    }

    /**
     * @description Lifecycle hook called when the component is removed from the DOM.
     *              It removes the bound click handler to prevent memory leaks.
     */
    disconnectedCallback() {
        this.removeEventListener('click', this._boundClick);
    }

    /* ---------------- API PROPS ---------------- */
    //public attributes we receive from ham_alumniDisplayCmp. We use this to dispatch to main. And from main, back to alumniDisplayCmp.
    //The agenda is to preserve the results when 'Back' is pressed from profile overview.
    //Search Key, Filters, Primarykeyset, secondarykeyset, recordsToSkip
    @api searchKeyToApex;
    @api savedFilters;
    @api primarykeyset;
    @api secondarykeyset;
    @api recordsToSkip;

    /**
     * @description Public property to get the current user's Contact Id
     */
    @api
    get userContactId() {
        return this._userContactId;
    }

    /**
     * @description Public property setter for userContactId. Triggers processing of the alumni list when set.
     */
    set userContactId(value) {
        this._userContactId = value;
        this.tryProcessAlumniList();
    }

    /**
      * @description Processes the alumni list if both userContactId and alumniList are available.
      *              Sets isLoading state accordingly.
      */
    tryProcessAlumniList() {
        if (this._userContactId && this._alumniList.length > 0) {
            this.isLoading = true;
            this.processAlumniList();
        } else {
            this.isLoading = false;;
        }
    }

    /**
     * @description Public property to get the currently selected tab
     */
    @api
    get tab() {
        return this._tab;
    }

    /**
     * @description Public property setter for tab. Triggers processing of alumni list when tab changes.
     */
    set tab(value) {
        this.isLoading = true;
        this._tab = value;
        this.processAlumniList();
    }

    /**
     * @description Public property to get the current list of alumni
     */
    @api
    get alumniList() {
        return this._alumniList;
    }

    /**
     * @description Public property setter for alumniList. Ensures value is always an array and triggers processing.
     */
    set alumniList(value) {
        this.isLoading = true;
        this._alumniList = Array.isArray(value) ? value : [];
        this.processAlumniList();
    }

    /* ---------------- LIST PROCESSING ---------------- */

    /**
     * @description Processes the alumni list to prepare UI-specific properties like button labels,
     *              icons, CSS classes, and visibility flags for dropdowns.
     */
    processAlumniList() {
        if (!this._alumniList.length) {
            this.alumniUiList = [];
            this.isLoading = false;
            return;
        }
       
        const isBuildTab = this._tab === this.label.buildCommunity;

        this.alumniUiList = this._alumniList.map(a => ({
            ...a,
            fields: a.fields?.map(f => ({
                ...f,
                cssClass: f.label === 'Degree:' ? 'col field-col degree' : f.label === 'Graduation Year:' ? 'col field-col year' : 'col field-col'
            })),
            isNotCurrentUser: !(isBuildTab && a.portalUserId === this._userContactId),
            favoriteIcon: a.isFavorite ? this.effectiveImages.favIconEnabled : this.effectiveImages.favIconDisabled,
            favoriteStatus: a.isFavorite ? ACTIONS.REMOVE_FAVORITE : ACTIONS.FAVORITE,
            favoriteHover: a.isFavorite ? this.label.removeFavoriteHoverText : this.label.favoriteHoverText,
            bookmarkIcon: a.isBookmarked ? this.effectiveImages.bookIconEnabled : this.effectiveImages.bookIconDisabled,
            bookmarkStatus: a.isBookmarked ? ACTIONS.REMOVE_BOOKMARK : 'Bookmark',
            bookmarkHover: a.isBookmarked ? this.label.removeBookmarkHoverText : this.label.bookmarkHoverText,
            buttonLabel: this.getButtonLabel(a.isConnected, a.isRequestSent, a.isBlocked),
            buttonHover: this.getButtonHover(a.isConnected, a.isRequestSent, a.isBlocked),
            buttonClass: (isBuildTab && a.portalUserId === this._userContactId)
            ? 'btn disable'
            : this.getButtonClass(a.isCoolDown, a.isConnected, a.isRequestSent, a.isBlocked),
            disableConnectionButton: (isBuildTab && a.portalUserId === this._userContactId) || a.isCoolDown,
            // Hide the action button only when it's a Send Request AND the logged-in
            // user has connection privacy enabled. Other actions (Remove/Cancel/Unblock) stay.
            showConnectionButton: !(
                this.getButtonLabel(a.isConnected, a.isRequestSent, a.isBlocked) === ACTIONS.SEND_REQUEST &&
                (
                    this._isLoginedPortalConPrivacyOpen === true ||   // logged-in user has privacy on
                    a.header?.connectionPrivacyEnabled === true       // target portal user has privacy on
                )
            ),
            iconsClass: this._tab === this.TABS.CONNECTIONS ? 'col favorite' : 'col bookmark',
            // [v1.4 - Anirudh] Sent sub-tab uses linkedUserId (recipient) so Cancel Request
            // passes the correct linkedConstituentId to the Apex handleCancelRequest method.
            // Bookmarks and Blocked Profiles also use linkedUserId (existing behaviour unchanged).
            constituentId: (this._tab === this.TABS.BOOKMARKS || this._tab === this.TABS.BLOCKED_PROFILES || this.isSentSubTab)
                ? a.linkedUserId
                : a.portalUserId,
            showDropdown: false
        }));
        this.isLoading = false;
        
    }

    /**
     * @description Determines the label for the action button based on connection/request status.
     */
    getButtonLabel(isConnected, isRequestSent, isBlocked) {
        if (isBlocked) return ACTIONS.UNBLOCK_PROFILE;
        if (isConnected) return ACTIONS.REMOVE_CONNECTION;
        if (isRequestSent) return ACTIONS.CANCEL_REQUEST;
        return ACTIONS.SEND_REQUEST;
    }

    /**
     * @description Determines the label for the action button based on connection/request status.
     */
    getButtonHover(isConnected, isRequestSent, isBlocked) {
        if (isBlocked) return this.label.unBlockHoverText;
        if (isConnected) return this.label.removeConnectionHoverText;
        if (isRequestSent) return this.label.cancelRequestHoverText;
        return this.label.sendRequestHoverText;
    }

    /**
     * @description Determines the CSS class for the action button based on cooldown, connection, or request status.
     */
    getButtonClass(isCoolDown, isConnected, isRequestSent, isBlocked) {
        if (isBlocked) return 'btn active';
        if (isCoolDown) return 'btn disable';
        if (isConnected || isRequestSent) return 'btn inactive';
        return 'btn active';
    }

    /**
     * @description Closes all open dropdown menus in the alumni UI list.
     */
    closeAllDropdowns() {
        this.alumniUiList = this.alumniUiList.map(a => ({ ...a, showDropdown: false }));
    }

    /**
     * @description Handles clicks outside the action menu to close any open dropdowns.
     */
    handleDocumentClick(e) {
        if (!e.target.closest('.action-menu-wrapper')) {
            this.closeAllDropdowns();
        }
    }

    /**
     * @description Toggles the dropdown menu for the clicked alumni item while closing others.
     */
    handleMoreClick(event) {
        event.stopPropagation();
        const clickedId = event.currentTarget.dataset.id;

        this.alumniUiList = this.alumniUiList.map(a => ({
            ...a,
            showDropdown: a.constituentId === clickedId ? !a.showDropdown : false
        }));
    }

    /* ---------------- UI HELPERS ---------------- */

    /**
     * @description Determines if the current tab is the Connections tab, used to show the favorite icon.
     */
    get showFavorite() {
        return this._tab === this.TABS.CONNECTIONS;
    }

    /**
     * @description Returns the empty state message corresponding to the current tab.
     */
    get tabStateMessage() {
        // [v1.4 - Anirudh] Return sub-tab-specific empty-state message for Manage Invitations
        if (this.isSentSubTab) {
            return this.label.noSentRequests;
        }
        if (this._tab === this.TABS.BUILD_COMMUNITY) {
            const hasSearch = this.searchKeyToApex && this.searchKeyToApex.trim() !== '';
            const hasFilters = Array.isArray(this.savedFilters) && this.savedFilters.length > 0;
            if (hasSearch || hasFilters) {
                return this.label.noSearchResults;
            }
        }
        return this.TAB_EMPTY_MESSAGES[this._tab] || '';
    }

    get showEmptyState() {
        return !this.isParentLoading && !this.isLoading && !this.alumniUiList.length;
    }

    /**
     * @description Checks if the current tab is the Bookmarks tab.
     */
    get isBookMarkTab() {
        return this._tab === this.TABS.BOOKMARKS;
    }

    /**
     * @description Checks if the current tab is the Manage Invitation tab.
     */
    get isManageTab() {
        return this._tab === this.TABS.MANAGE_INVITATION;
    }

    /**
     * @description Returns true if the current tab is NOT Blocked Profiles tab.
     */
    get notBlockedProfilesTab() {
        return this._tab !== this.TABS.BLOCKED_PROFILES;
    }

    get isConnectionsTab() {
        return this._tab === this.TABS.CONNECTIONS;
    }

    handleGoToSearchDirectory() {
        this.dispatchEvent(new CustomEvent('gotodirectorytab', {
            bubbles: true,
            composed: true
        }));
    }

    // [v1.4 - Anirudh] ── Manage Invitations sub-tab API & helpers ──────────────────────────

    _invitationSubTab = 'Received';

    /**
     * @description Receives the active Manage Invitations sub-tab ('Received' or 'Sent')
     * from the parent. Re-processes the alumni list whenever the value changes so that
     * the constituentId mapping and button rendering reflect the correct sub-tab.
     */
    @api
    get invitationSubTab() {
        return this._invitationSubTab;
    }
    set invitationSubTab(value) {
        this._invitationSubTab = value || 'Received';
        // Re-map alumni list so constituentId and button state update for the new sub-tab
        if (this._alumniList && this._alumniList.length > 0) {
            this.processAlumniList();
        }
    }

    /**
     * @description True when the Manage Invitations tab is active AND the Sent sub-tab
     * is selected. Used to show the Cancel Request button and map constituentId correctly.
     */
    get isSentSubTab() {
        return this.isManageTab && this._invitationSubTab === 'Sent';
    }

    /**
     * @description True when the Manage Invitations tab is active AND the Received sub-tab
     * is selected (default). Used to show the Accept / Ignore buttons.
     */
    get isReceivedSubTab() {
        return this.isManageTab && this._invitationSubTab !== 'Sent';
    }

    // ─────────────────────────────────────────────────────────────────────────────

    /* ---------------- EVENTS ---------------- */

    /**
     * @description Dispatches a 'select' event when an alumni profile is selected.
     */
    handleProfileSelect(event) {
        this.dispatchEvent(new CustomEvent('select', {
            detail: event.currentTarget.dataset.id
        }));
    }

    /**
      * @description Dispatches a 'profileoverview' event with the selected contact ID.
      */
    handleViewProfile(event) {
        const selectedContactId = event.currentTarget.dataset.id;
        this.dispatchEvent(
            new CustomEvent('profileoverview', {
                detail: {
                    selectedContactId: selectedContactId,
                    directoryPreviousTab: this._tab,
                    searchKeyToApex: this.searchKeyToApex,
                    savedFilters: this.savedFilters,
                    primarykeyset: this.primarykeyset,
                    secondarykeyset: this.secondarykeyset,
                    recordsToSkip: this.recordsToSkip,
                    view: this.view,
                    userHasModifiedFilters: this.userHasModifiedFilters === true,
                    initialDirectoryFilters: this.initialDirectoryFilters
                        ? [...this.initialDirectoryFilters]
                        : null
                },
                bubbles: true,
                composed: true
            })
        );
    }


    /**
     * @description Handles action button clicks for sending requests, unblock profiles, removing bookmarks or connections.
     * Sets modal configuration based on the action and opens the modal if applicable.
     */
    async handleButtonClick(event) {
        this.clickedUser = event.target.dataset.contact;
        this.clickedFunctiontype = event.target.dataset.name;

        let userStatus;
        if (this.clickedFunctiontype == ACTIONS.SEND_REQUEST) {
            this.isLoading = true;
            userStatus = await checkUserStatus({ linkedConstituentId: this.clickedUser });
            this.isLoading = false;


        }
        // Using imported custom labels
        const modalMap = {
            [ACTIONS.SEND_REQUEST]: {
                header: this.label.actionSRHeader,
                primary: this.label.actionSRPrimaryBtn,
                secondary: this.label.actionSRSecondaryBtn,
                request: true
            },
            [ACTIONS.REMOVE_BOOKMARK]: {
                header: this.label.actionRBMHeader,
                primary: this.label.actionRBMPrimaryBtn,
                secondary: this.label.actionRCSecondaryBtn,
                request: false
            },
            [ACTIONS.REMOVE_CONNECTION]: {
                header: this.label.actionRCHeader,
                primary: this.label.removeConnection,
                secondary: this.label.actionRCSecondaryBtn,
                request: false
            },
            [ACTIONS.UNBLOCK_PROFILE]: {
                header: this.label.unblockProfileHeader,
                primary: this.label.unblockProfileButton,
                secondary: this.label.actionRCSecondaryBtn,
                request: false
            }
        };

        const config = modalMap[this.clickedFunctiontype];
        if (userStatus == 'Inactive User') {
            this.isInactiveUser = true;
            Object.assign(this, {
                modalHeader: config.header,
                modalPrimaryButton: config.primary,
                modalSecondaryButton: config.secondary,
                isRequestModal: config.request || false,
                showPrimaryButton: true,
                showRequestModal: true,
                primaryButtonClass: 'primary-button disable',
                secondaryButtonClass: 'secondary-button disable'
            });
        }
        else {

            this.isInactiveUser = false;
            if (config) {
                Object.assign(this, {
                    modalHeader: config.header,
                    modalPrimaryButton: config.primary,
                    modalSecondaryButton: config.secondary,
                    isRequestModal: config.request || false,
                    showPrimaryButton: true,
                    showRequestModal: true,
                    primaryButtonClass: 'primary-button active',
                    secondaryButtonClass: 'secondary-button secondary-active'
                });
            } else {
                this.handleConnection();
            }

            this.closeAllDropdowns();

        }

    }

    /**
     * @description Updates the personalized message bound to the modal input.
     */
    handleMessageChange(e) {
        this.personalizedMessage = e.target.value;
    }

    /* ---------------- SERVER CALL ---------------- */

    /**
     * @description Handles connection requests (send, cancel, remove) based on the clicked action.
     * Calls Apex method and shows toast messages or updates modal based on the result.
     */
    handleRequest(event) {
        if (event?.currentTarget?.dataset?.name === 'Cancel') {
            this.showRequestModal = false;
            return;
        }

        // Validate textarea for Send Request action
        if (event?.currentTarget?.dataset?.name === 'Send Request') {
            const textarea = this.template.querySelector('.message-textarea');
            if (!textarea.value || textarea.value.trim() === '') {
                textarea.setCustomValidity('Please enter a personalized message.');
                textarea.reportValidity();
                return; // Stop execution if validation fails
            } else {
                textarea.setCustomValidity(''); // Clear any previous custom validity
            }
        }

        this.showRequestModal = false;
        this.handleConnection();
    }

    handleConnection() {
        handleConnectionRequest({
            portalId: this._userContactId,
            linkedConstituentId: this.clickedUser,
            requestMessage: this.personalizedMessage,
            functionType: this.clickedFunctiontype
        })
            .then(result => {
                if (result === RESULTS.SUCCESS) {
                    this.dispatchEvent(new CustomEvent('refreshdata', {
                        detail: this._tab,
                        bubbles: true,
                        composed: true
                    }));

                    if (this.clickedFunctiontype === ACTIONS.SEND_REQUEST) {
                        this.toastMessage = this.label.toastMessageReqSend;
                    } else if (this.clickedFunctiontype === ACTIONS.CANCEL_REQUEST) {
                        this.toastMessage = this.label.toastMessageCancelReq;
                    } else if (this.clickedFunctiontype === ACTIONS.BOOKMARK_PROFILE) {
                        this.toastMessage = this.label.toastMessageBookmarked;
                    } else if (this.clickedFunctiontype === ACTIONS.REMOVE_BOOKMARK) {
                        this.toastMessage = this.label.toastMesgRemBookmarked;
                    } else if (this.clickedFunctiontype === ACTIONS.FAVORITE) {
                        this.toastMessage = this.label.toastMessageFavorite;
                    } else if (this.clickedFunctiontype === ACTIONS.REMOVE_FAVORITE) {
                        this.toastMessage = this.label.toastMessageRemoveFavorite;
                    } else if (this.clickedFunctiontype === ACTIONS.BLOCK_PROFILE) {
                        this.toastMessage = this.label.toastMessageBlock;
                    } else if (this.clickedFunctiontype === ACTIONS.UNBLOCK_PROFILE) {
                        this.toastMessage = this.label.toastMessageUnblock;
                    }
                    else {
                        this.toastMessage = 'Success';
                    }
                    this.toastTitle = 'Success';
                    this.toastVariant = 'success';
                    this.toastDuration = 5000;
                    this.showCustomToast = true;

                    this.resetVariables();
                }
                else if (result === RESULTS.INVITATION_EXIST) {
                    Object.assign(this, {
                        modalHeader: this.label.invitationExist,
                        showPrimaryButton: false,
                        modalPrimaryButton: '',
                        modalSecondaryButton: 'Cancel',
                        isRequestModal: false,
                        showRequestModal: true,
                        primaryButtonClass: 'primary-button active',
                        secondaryButtonClass: 'secondary-button secondary-active'
                    });
                } else {
                    this.toastTitle = 'Error';
                    this.toastMessage = 'Error occured on update ';
                    this.toastVariant = 'error';
                    this.toastDuration = 5000;
                    this.showCustomToast = true;
                    console.log('Error occured ' + result);
                }
            })
            .catch(() => {
                this.toastTitle = 'Error';
                this.toastMessage = 'Error occured on update';
                this.toastVariant = 'error';
                this.toastDuration = 5000;
                this.showCustomToast = true;
                console.log('Error occured ' + result);
            });
    }

     
    /**
     * @description Resets variables related to modal and button states.
     */
    resetVariables() {
        this.clickedUser = null;
        this.clickedFunctiontype = null;
        this.personalizedMessage = '';
        this.modalHeader = '';
        this.modalPrimaryButton = '';
        this.modalSecondaryButton = '';
        this.isRequestModal = false;
        this.showPrimaryButton = false;
        this.isInactiveUser = false;
    }

    /**
     * @description Closes the modal and resets modal-related variables.
     */
    closeRequestModal() {
        this.showRequestModal = false;
        this.resetVariables();
    }

    /**
     * @description Closes the custom toast notification.
     */
    handleToastClose() {
        this.showCustomToast = false;
    }

    /**
    * @description opens the necrology link on different tab.
    */
    handleNecrologyClick() {
        window.open(this.label.necrologyLink, '_blank');
    }
    

    
}