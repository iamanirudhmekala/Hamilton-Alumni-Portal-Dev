import { LightningElement, api } from 'lwc';
//Import Apex controller
import handleConnectionRequest from '@salesforce/apex/HAM_AlumniConnectionService.handleConnectionRequest';
import checkUserStatus from '@salesforce/apex/HAM_AlumniConnectionService.checkUserStatus';

//Import Icons static resource
import HAM_ICONS from '@salesforce/resourceUrl/HAM_Icons';

//Import custom labels
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
import ActionRBMSecondaryBtn from '@salesforce/label/c.HAM_Secondry_Button';
import ActionRCHeader from '@salesforce/label/c.HAM_Remove_Conn';
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


// Constants for actions (these don't need labels)
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

// Modal configurations using imported labels directly
const MODAL_CONFIG = {
    [ACTIONS.SEND_REQUEST]: {
        header: ActionSRHeader,
        primaryButton: ActionSRPrimaryBtn,
        secondaryButton: ActionSRSecondaryBtn,
        isRequestModal: true,
        showPrimaryButton: true
    },
    [ACTIONS.REMOVE_BOOKMARK]: {
        header: ActionRBMHeader,
        primaryButton: ActionRBMPrimaryBtn,
        secondaryButton: ActionRBMSecondaryBtn,
        isRequestModal: false,
        showPrimaryButton: true
    },
    [ACTIONS.REMOVE_CONNECTION]: {
        header: ActionRCHeader,
        primaryButton: RemoveCoonection,
        secondaryButton: ActionRBMSecondaryBtn,
        isRequestModal: false,
        showPrimaryButton: true
    },
    [ACTIONS.UNBLOCK_PROFILE]: {
        header: unblockProfileHeader,
        primaryButton: unblockProfileButton,
        secondaryButton: ActionRBMSecondaryBtn,
        isRequestModal: false,
        showPrimaryButton: true
    }
};

export default class Ham_alumniGridDisplayCmp extends LightningElement {


    @api initialDirectoryFilters;
    @api userHasModifiedFilters;
    @api isParentLoading = false;

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
        actionRBMSecondaryBtn: ActionRBMSecondaryBtn,
        actionRCHeader: ActionRCHeader,
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

    isLoading = true;
    showRequestModal = false;
    isRequestModal = false;
    showPrimaryButton = false;
    personalizedMessage = '';
    modalSecondaryButton = '';
    modalPrimaryButton = '';
    modalHeader = '';
    showCustomToast = false;
    primaryButtonClass = 'primary-button';
    secondaryButtonClass = 'secondary-button';
    isInactiveUser = false;

    _tab;
    _userContactId;
    _alumniList = [];
    alumniUiList = [];
    clickedFunctiontype = null;
    clickedUser = null;

    screenWidth = window.innerWidth;
    @api view;

    _isOverride = false;

    _isLoginedPortalConPrivacyOpen = false;

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

    // Icon paths
    images = {
        favIconEnabled: `${HAM_ICONS}/fav-fill.png`,
        favIconDisabled: `${HAM_ICONS}/fav-outline.png`,
        bookIconEnabled: `${HAM_ICONS}/bookmark-fill.png`,
        bookIconDisabled: `${HAM_ICONS}/bookmark-outline.png`,
        threeDots: `${HAM_ICONS}/dots.png`,
        kirklandLogo: `${HAM_ICONS}/kirkland-icon.png`,
        person: `${HAM_ICONS}/person.png`,
        close: `${HAM_ICONS}/cross_black.png`,
        profile: `${HAM_ICONS}/profile_icon.png`,
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

    get dotsIcon() {
        return this._isOverride ? `${HAM_ICONS}/dots-green.png` : `${HAM_ICONS}/dots.png`;
    }

    get containerClass() {
        return this._isOverride ? 'grid-container kirkland-override' : 'grid-container';
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

    // Bound handler reference for proper cleanup
    boundHandleDocumentClick = this.handleDocumentClick.bind(this);

    connectedCallback() {
        this.addEventListener('click', this.boundHandleDocumentClick);
        //  event listener for window resize
        window.addEventListener('resize', this.handleResize.bind(this));
    }

    disconnectedCallback() {
        this.removeEventListener('click', this.boundHandleDocumentClick);
    }

    /**
     * @description Updates the screen width property on window resize.
     */
    handleResize() {
        this.screenWidth = window.innerWidth;
    }


    /**
     * @description Updates the screen width property on window resize.
     */
    get isMobileView() {
        return this.screenWidth < 1024;
    }

    /**
     * @description Determines whether the current screen size qualifies as desktop view.
     * Used to toggle desktop-specific layouts and UI behavior.
     * @returns {Boolean} True if screen width is 1024px or greater.
     */
    get isDesktopView() {
        return this.screenWidth >= 1024;
    }

    /**
     * @description Checks if the currently selected tab is "Manage Invitation".
     * Used to control visibility of Manage Invitation–specific UI elements.
     * @returns {Boolean} True when active tab is Manage Invitation.
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
     * @description True when Manage Invitations is active AND the Sent sub-tab is selected.
     * Used to render the Cancel Request button and use linkedUserId as constituentId.
     */
    get isSentSubTab() {
        return this.isManageTab && this._invitationSubTab === 'Sent';
    }

    /**
     * @description True when Manage Invitations is active AND the Received sub-tab is selected.
     * Used to render the Accept / Ignore buttons.
     */
    get isReceivedSubTab() {
        return this.isManageTab && this._invitationSubTab !== 'Sent';
    }

    // ─────────────────────────────────────────────────────────────────────────────


    /**
     * @description Handles click events on the document.
     * Closes all open action dropdown menus when the user clicks outside
     * of the action menu wrapper area.
     *
     * @param {Event} event - The click event triggered on the document.
     */
    handleDocumentClick(event) {
        if (!event.target.closest('.action-menu-wrapper')) {
            this.closeAllDropdowns();
        }
    }

    /**
     * @description Closes all open dropdown menus for alumni cards.
     * Iterates through the alumni UI list and sets `showDropdown` to false
     * to ensure only one dropdown can be open at a time (or none).
     */
    closeAllDropdowns() {
        this.alumniUiList = this.alumniUiList.map(alumni => ({ ...alumni, showDropdown: false }));
    }

    /**
     * @description Public getter to expose the current user's Contact Id.
     * This value is used by parent components to identify the logged-in user
     * and control UI behavior such as hiding actions on their own profile.
     * @returns {String} User Contact Id
     */
    @api
    get userContactId() {
        return this._userContactId;
    }

    /**
     * @description Public setter for the current user's Contact Id.
     * Stores the value locally and triggers alumni list processing once the Contact Id becomes available.
     * @param {String} value - User Contact Id passed from parent component
     */
    set userContactId(value) {
        this._userContactId = value;
        this.tryProcessAlumniList();
    }

    /**
     * @description Checks whether both the user Contact Id and alumni list
     * are available before triggering alumni list processing.
     * Prevents premature execution when required data is not yet initialized.
     */
    tryProcessAlumniList() {
        if (this._userContactId && this._alumniList.length > 0) {
            this.processAlumniList();
        }
    }

    /**
     * @description Public getter to retrieve the currently selected tab.
     * Used to control UI rendering and action behavior.
     * @returns {String} Active tab value
     */
    @api
    get tab() {
        return this._tab;
    }

    /**
     * @description Public setter for active tab.
     * Updates local tab value and re-processes alumni list to reflect tab-specific UI states.
     * @param {String} value - Selected tab from parent component
     */
    set tab(value) {
        this._tab = value;
        this.processAlumniList();
    }

    /**
     * @description Public getter to retrieve alumni list passed from parent.
     * @returns {Array} Raw alumni records
     */
    @api
    get alumniList() {
        return this._alumniList;
    }

    /**
     * @description Public setter for alumni list.
     * Ensures value is always an array and triggers alumni list processing for UI preparation.
     * @param {Array} value - Alumni records from parent component
     */
    set alumniList(value) {
        this._alumniList = Array.isArray(value) ? value : [];
        this.processAlumniList();
    }

    //public attributes we receive from ham_alumniDisplayCmp. We use this to dispatch to main. And from main, back to alumniDisplayCmp.
    //The agenda is to preserve the results when 'Back' is pressed from profile overview.
    //Search Key, Filters, Primarykeyset, secondarykeyset, recordsToSkip
    @api searchKeyToApex;
    @api savedFilters;
    @api primarykeyset;
    @api secondarykeyset;
    @api recordsToSkip;

    /**
     * @description Determines whether current tab is Bookmarks.
     * Used to conditionally show bookmark-specific actions.
     * @returns {Boolean}
     */
    get isBookMarkTab() {
        return this._tab === this.TABS.BOOKMARKS;
    }

    /**
     * @description Determines whether Favorite icon should be shown.
     * Only displayed when Connections tab is active.
     * @returns {Boolean}
     */
    get showFavorite() {
        return this._tab === this.TABS.CONNECTIONS;
    }

    /**
     * @description Returns empty-state message based on current tab.
     * Used when no alumni records are available.
     * @returns {String}
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
     * @description Processes alumni data and prepares UI-specific properties
     * such as icons, button labels, CSS classes, and visibility flags based on the currently active tab and alumni status.
     * Also filters current user and handles empty list state.
     */
    processAlumniList() {
        if (!this._alumniList.length) {
            this.alumniUiList = [];
            this.isLoading = false;
            return;
        }

        const isBuildTab = this._tab == this.label.buildCommunity;
        const isConnectionsTab = this._tab == this.TABS.CONNECTIONS;

        this.alumniUiList = this._alumniList.map(alumni => {
            const { isFavorite, isBookmarked, isConnected, isRequestSent, isCoolDown, isBlocked, portalUserId, fields } = alumni;

            return {
                ...alumni,
                fields: fields.map(field => ({
                    ...field,
                    cssClass: `col field-col${field.label === 'Degree:' ? ' degree' : ''}`
                })),
                isNotCurrentUser: !(isBuildTab && alumni.portalUserId === this._userContactId),
                favoriteIcon: this.effectiveImages[isFavorite ? 'favIconEnabled' : 'favIconDisabled'],
                favoriteStatus: isFavorite ? ACTIONS.REMOVE_FAVORITE : ACTIONS.FAVORITE,
                favoriteHover: isFavorite ? this.label.removeFavoriteHoverText : this.label.favoriteHoverText,
                bookmarkIcon: this.effectiveImages[isBookmarked ? 'bookIconEnabled' : 'bookIconDisabled'],
                bookmarkStatus: isBookmarked ? ACTIONS.REMOVE_BOOKMARK : 'Bookmark',
                bookmarkHover: isBookmarked ? this.label.removeBookmarkHoverText : this.label.bookmarkHoverText,
                buttonLabel: this.getButtonLabel(isConnected, isRequestSent, isBlocked),
                buttonHover: this.getButtonHover(isConnected, isRequestSent, isBlocked),
                buttonClass: (
                    (isBuildTab && alumni.portalUserId === this._userContactId) ||
                    (alumni.header?.connectionPrivacyEnabled === true &&
                    this.getButtonLabel(isConnected, isRequestSent, isBlocked) === ACTIONS.SEND_REQUEST)
                )
                    ? 'btn disable'
                    : this.getButtonClass(isCoolDown, isConnected, isRequestSent, isBlocked),
                disableConnectionButton: (isBuildTab && alumni.portalUserId === this._userContactId) || isCoolDown || (
                    alumni.header?.connectionPrivacyEnabled === true &&
                    this.getButtonLabel(isConnected, isRequestSent, isBlocked) === ACTIONS.SEND_REQUEST
                ),
                // Hide the Send Request button when the logged-in user OR the target
                // has connection privacy on. Other actions (Remove/Cancel/Unblock) stay.
                showConnectionButton: !(
                    this.getButtonLabel(isConnected, isRequestSent, isBlocked) === ACTIONS.SEND_REQUEST &&
                    (
                        this._isLoginedPortalConPrivacyOpen === true ||
                        alumni.header?.connectionPrivacyEnabled === true
                    )
                ),
                iconsClass: `col ${isConnectionsTab ? 'favorite' : 'bookmark'}`,
                // [v1.4 - Anirudh] Sent sub-tab uses linkedUserId (recipient) so Cancel Request
                // passes the correct linkedConstituentId to the Apex handleCancelRequest method.
                // Bookmarks and Blocked Profiles also use linkedUserId (existing behaviour unchanged).
                constituentId: (this._tab === this.TABS.BOOKMARKS || this._tab === this.TABS.BLOCKED_PROFILES || this.isSentSubTab)
                    ? alumni.linkedUserId
                    : alumni.portalUserId,
                showDropdown: false
            };
        });
        this.isLoading = false;
    }


    /**
     * @description Determines primary button label based on connection status.
     * @param {Boolean} isConnected - Indicates active connection
     * @param {Boolean} isRequestSent - Indicates pending request
     * @returns {String} Button label
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
     * @description Determines CSS class for action button based on cooldown, connection, or request status.
     * @param {Boolean} isCoolDown - Indicates cooldown state
     * @param {Boolean} isConnected - Indicates active connection
     * @param {Boolean} isRequestSent - Indicates pending request
     * @returns {String} CSS class name
     */
    getButtonClass(isCoolDown, isConnected, isRequestSent, isBlocked) {
        if (isBlocked) return 'btn active';
        if (isCoolDown) return 'btn disable';
        if (isConnected || isRequestSent) return 'btn inactive';
        return 'btn active';
    }

    /**
     * @description Handles click on three-dot menu.
     * Toggles dropdown for selected alumni and closes others.
     * @param {Event} event - Click event
     */
    handleMoreClick(event) {
        event.stopPropagation();
        const connectionId = event.currentTarget.dataset.id;

        this.alumniUiList = this.alumniUiList.map(alumni => ({
            ...alumni,
            showDropdown: alumni.constituentId === connectionId ? !alumni.showDropdown : false
        }));
    }

    /**
     * @description Fires custom event to open selected alumni profile.
     * Sends selected contact Id to parent component.
     * @param {Event} event - Click event
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
     * @description Handles action button click (Send Request / Remove Bookmark / Remove Connection etc).
     * Stores selected user and action type, opens confirmation modal if configured, otherwise directly executes request.
     * @param {Event} event - Click event from action button
     */
    async handleButtonClick(event) {
        const { contact, name } = event.target.dataset;
        this.clickedUser = contact;
        this.clickedFunctiontype = name;

        let userStatus;
        if (this.clickedFunctiontype == ACTIONS.SEND_REQUEST) {
            this.isLoading = true;
            userStatus = await checkUserStatus({ linkedConstituentId: this.clickedUser });
            this.isLoading = false;

        }
        const config = MODAL_CONFIG[name];

        if (userStatus == 'Inactive User') {
            this.isInactiveUser = true;
            Object.assign(this, {
                modalHeader: config.header,
                modalPrimaryButton: config.primaryButton,
                modalSecondaryButton: config.secondaryButton,
                isRequestModal: config.isRequestModal,
                showPrimaryButton: config.showPrimaryButton,
                showRequestModal: true,
                primaryButtonClass: 'primary-button disable',
                secondaryButtonClass: 'secondary-button disable'
            });
        }
        else {



            if (config) {
                this.modalHeader = config.header;
                this.modalPrimaryButton = config.primaryButton;
                this.modalSecondaryButton = config.secondaryButton;
                this.isRequestModal = config.isRequestModal;
                this.showRequestModal = true;
                this.showPrimaryButton = config.showPrimaryButton;
                this.primaryButtonClass = 'primary-button active',
                    this.secondaryButtonClass = 'secondary-button secondary-active'
            } else {
                this.handleRequest(null);
            }

            this.closeAllDropdowns();

        }


    }

    /**
     * @description Captures personalized message entered by user in Send Request modal.
     * @param {Event} event - Input change event
     */
    handleMessageChange(event) {
        this.personalizedMessage = event.target.value;
    }


    /**
     * @description Executes alumni connection-related actions such as
     * Send Request, Cancel Request, Remove Connection, or Bookmark removal.
     * Makes Apex call and handles success/error UI states.
     * @param {Event} event - Button click event from modal
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
        handleConnectionRequest({
            portalId: this._userContactId,
            linkedConstituentId: this.clickedUser,
            requestMessage: this.personalizedMessage,
            functionType: this.clickedFunctiontype
        })
            .then(result => {
                if (result === 'Success') {
                    this.dispatchEvent(new CustomEvent('refreshdata', {
                        detail: 'refresh',
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
                        this.toastMessage = 'Preference updated!';
                    }
                    this.toastTitle = 'Success';
                    this.toastVariant = 'success';
                    this.toastDuration = 5000;
                    this.showCustomToast = true;
                    this.showRequestModal = false;
                    this.resetVariables();

                } else if (result === 'Invitation Exist') {
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
                }
            })
            .catch(() => {
                this.toastTitle = 'Error';
                this.toastMessage = 'Error occured on update';
                this.toastVariant = 'error';
                this.toastDuration = 5000;
                this.showCustomToast = true;
            });
    }

    /**
     * @description Resets modal-related variables and selected alumni data after successful or cancelled action.
     */
    resetVariables() {
        Object.assign(this, {
            clickedUser: null,
            clickedFunctiontype: null,
            personalizedMessage: '',
            modalHeader: '',
            modalPrimaryButton: '',
            modalSecondaryButton: '',
            isRequestModal: false,
            isInactiveUser: false
        });
    }

    /**
     * @description Closes the request modal popup.
     * Triggered when user clicks close icon or cancel button.
     */
    closeRequestModal() {
        this.showRequestModal = false;
    }

    /**
     * @description Handles custom toast close event.
     * Hides toast notification from UI.
     */
    handleToastClose() {
        this.showCustomToast = false;
    }

    /**
     * @description Handles image load error.
     * Replaces broken profile image with default placeholder image.
     * @param {Event} event - Image error event
     */
    handleImageError(event) {
        event.target.src = this.images.profile;
    }

    get imageError() {
        return this.images.profile;
    }

    /**
   * @description opens the necrology link on different tab.
   */
    handleNecrologyClick() {
        window.open(this.label.necrologyLink, '_blank');
    }

}