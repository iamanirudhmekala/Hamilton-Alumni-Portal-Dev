import { LightningElement, api, track, wire } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import getGroupMembers            from '@salesforce/apex/Ham_GroupsController.getGroupMembers';
import getFilterMetadataAndValues from '@salesforce/apex/HAM_AlumniDirectoryController.getFilterMetadataAndValues';
import handleConnectionRequest    from '@salesforce/apex/HAM_AlumniConnectionService.handleConnectionRequest';
import checkUserStatus            from '@salesforce/apex/HAM_AlumniConnectionService.checkUserStatus';
import HAM_ICONS                  from '@salesforce/resourceUrl/HAM_Icons';

import SendRequest         from '@salesforce/label/c.HAM_Send_Request';
import RemoveBookmark      from '@salesforce/label/c.HAM_Remove_Bookmark';
import RemoveConnection    from '@salesforce/label/c.HAM_Remove_Connection';
import CancelRequest       from '@salesforce/label/c.HAM_Cancel_Request';
import ActionSRHeader      from '@salesforce/label/c.HAM_Personal_Mess';
import ActionSRPrimaryBtn  from '@salesforce/label/c.HAM_Primary_Btn';
import ActionSRSecondBtn   from '@salesforce/label/c.HAM_Secondary_Button';
import ActionRBMHeader     from '@salesforce/label/c.HAM_Remove_Bookmark_Header';
import ActionRBMPrimaryBtn from '@salesforce/label/c.HAM_Primary_Button_RBM';
import ActionRBMSecondBtn  from '@salesforce/label/c.HAM_Secondry_Button';
import ActionRCHeader      from '@salesforce/label/c.HAM_Remove_Conn';
import ToastReqSend        from '@salesforce/label/c.ham_ToastMessage_ReqSend';
import ToastCancelReq      from '@salesforce/label/c.ham_ToastMessage_CancelReq';
import ToastBookmarked     from '@salesforce/label/c.ham_ToastMessage_Bookmarked';
import ToastRemBookmark    from '@salesforce/label/c.ham_ToastMessage_Removed_Bookmarked';
import ToastBlock          from '@salesforce/label/c.ham_ToastMessage_Block';
import InActiveUserMsg     from '@salesforce/label/c.ham_inactiveUserMessage';
import BlockLabel          from '@salesforce/label/c.ham_blockProfile';
import BookmarkHover       from '@salesforce/label/c.HAM_bookmarkHoverText';
import RemoveBookmarkHover from '@salesforce/label/c.ham_removeBookmarkHoverText';
import SendReqHover        from '@salesforce/label/c.HAM_sendRequestHoverText';
import CancelReqHover      from '@salesforce/label/c.HAM_cancelRequestHoverText';
import RemoveConnHover     from '@salesforce/label/c.HAM_removeConnectionHoverText';
import ViewProfileLabel    from '@salesforce/label/c.ham_viewProfile';
import ViewProfileHover    from '@salesforce/label/c.HAM_viewProfileHoverText';

const PAGE_SIZE = 10;

const ACTIONS = {
    SEND_REQUEST:      SendRequest,
    BOOKMARK:          'Bookmark',
    REMOVE_BOOKMARK:   RemoveBookmark,
    REMOVE_CONNECTION: RemoveConnection,
    CANCEL_REQUEST:    CancelRequest,
    BLOCK:             'Block'
};

const MODAL_CONFIG = {
    [ACTIONS.SEND_REQUEST]: {
        header:            ActionSRHeader,
        primaryButton:     ActionSRPrimaryBtn,
        secondaryButton:   ActionSRSecondBtn,
        isRequestModal:    true,
        showPrimaryButton: true
    },
    [ACTIONS.REMOVE_BOOKMARK]: {
        header:            ActionRBMHeader,
        primaryButton:     ActionRBMPrimaryBtn,
        secondaryButton:   ActionRBMSecondBtn,
        isRequestModal:    false,
        showPrimaryButton: true
    },
    [ACTIONS.REMOVE_CONNECTION]: {
        header:            ActionRCHeader,
        primaryButton:     RemoveConnection,
        secondaryButton:   ActionRBMSecondBtn,
        isRequestModal:    false,
        showPrimaryButton: true
    }
};

export default class Ham_groupMembers extends LightningElement {
    @api groupId;
    @api contactId;

    _isOverride = false;
    @api
    get isOverride() {
        return this._isOverride;
    }
    set isOverride(value) {
        this._isOverride = (value === true || value === 'true');
    }

    get rootClass() {
        return `members-root ${this.isOverride ? 'kirkland-override' : ''}`;
    }

    @track allFilters      = [];
    @track activeFilters   = {};
    @track searchKey       = '';
    @track activeSearchKey = '';
    @track currentPage     = 1;
    @track isLoading       = false;

    // Modal state
    showRequestModal     = false;
    isRequestModal       = false;
    showPrimaryButton    = false;
    personalizedMessage  = '';
    modalHeader          = '';
    modalPrimaryButton   = '';
    modalSecondaryButton = '';
    primaryButtonClass   = 'primary-button';
    secondaryButtonClass = 'secondary-button';
    isInactiveUser       = false;
    _clickedUser         = null;
    _clickedFunctiontype = null;

    // Toast state
    showCustomToast = false;
    toastTitle      = '';
    toastMessage    = '';
    toastVariant    = 'success';
    toastDuration   = 5000;

    // Tracks which member's 3-dot dropdown is open
    _dropdownOpenId = null;

    label = {
        inActiveUserMessage: InActiveUserMsg,
        viewProfile:         ViewProfileLabel,
        viewProfileHover:    ViewProfileHover,
        blockProfile:        BlockLabel
    };

    images = {
        bookIconEnabled:  `${HAM_ICONS}/bookmark-fill.png`,
        bookIconDisabled: `${HAM_ICONS}/bookmark-outline.png`,
        close:            `${HAM_ICONS}/cross_black.png`,
        person:           `${HAM_ICONS}/person.png`
    };

    _wiredMembers;
    _boundDocClick = this.handleDocumentClick.bind(this);

    connectedCallback() {
        this.addEventListener('click', this._boundDocClick);
    }

    disconnectedCallback() {
        this.removeEventListener('click', this._boundDocClick);
    }

    // ── Wire: filter definitions ────────────────────────────────────────────

    @wire(getFilterMetadataAndValues)
    wiredFilters({ data, error }) {
        if (data) {
            this.allFilters = data
                .filter(f => f.placeholder !== 'More Filters')
                .map(f => ({
                    fieldApiName:  f.fieldApiName,
                    placeholder:   f.placeholder,
                    selectedValue: '',
                    options: [
                        { label: 'All', value: '' },
                        ...f.values.map(v => ({ label: v, value: v }))
                    ]
                }));
        } else if (error) {
            console.error('Filter metadata error', error);
        }
    }

    // ── Wire: members ───────────────────────────────────────────────────────

    @wire(getGroupMembers, {
        groupId:     '$groupId',
        contactId:   '$contactId',
        pageSize:    PAGE_SIZE,
        pageNumber:  '$currentPage',
        searchKey:   '$activeSearchKey',
        filtersJson: '$activeFiltersJson'
    })
    wiredMembers(result) {
        this._wiredMembers = result;
        this.isLoading = false;
        if (result.error) console.error('Members error', result.error);
    }

    // ── Computed getters ────────────────────────────────────────────────────

    get activeFiltersJson() {
        const sorted = {};
        Object.keys(this.activeFilters).sort()
              .forEach(k => { if (this.activeFilters[k]) sorted[k] = this.activeFilters[k]; });
        return JSON.stringify(sorted);
    }

    get hasFilters() { return this.allFilters.length > 0; }
    get members()    { return this._wiredMembers?.data?.members ?? []; }
    get totalCount() { return this._wiredMembers?.data?.totalCount ?? 0; }
    get hasMembers() { return !this.isLoading && this.members.length > 0; }
    get isEmpty()    { return !this.isLoading && this._wiredMembers?.data != null && this.members.length === 0; }

    get membersWithUI() {
        return this.members.map(m => ({
            ...m,
            photoUrl:       m.photoUrl || null,
            bookmarkIcon:   m.isBookmarked ? this.images.bookIconEnabled : this.images.bookIconDisabled,
            bookmarkStatus: m.isBookmarked ? ACTIONS.REMOVE_BOOKMARK : ACTIONS.BOOKMARK,
            bookmarkHover:  m.isBookmarked ? RemoveBookmarkHover : BookmarkHover,
            buttonLabel:    this._getButtonLabel(m.connectionStatus),
            buttonClass:    this._getButtonClass(m.connectionStatus),
            buttonHover:    this._getButtonHover(m.connectionStatus),
            showDropdown:   m.contactId === this._dropdownOpenId
        }));
    }

    _getButtonLabel(status) {
        if (status === 'Connected')    return ACTIONS.REMOVE_CONNECTION;
        if (status === 'Request Sent') return ACTIONS.CANCEL_REQUEST;
        return ACTIONS.SEND_REQUEST;
    }

    _getButtonClass(status) {
        return (status === 'Connected' || status === 'Request Sent') ? 'btn inactive' : 'btn active';
    }

    _getButtonHover(status) {
        if (status === 'Connected')    return RemoveConnHover;
        if (status === 'Request Sent') return CancelReqHover;
        return SendReqHover;
    }

    // ── Pagination getters ──────────────────────────────────────────────────

    get totalPages()  { return Math.max(1, Math.ceil(this.totalCount / PAGE_SIZE)); }
    get isFirstPage() { return this.currentPage <= 1; }
    get isLastPage()  { return this.currentPage >= this.totalPages; }
    get resultsFrom() { return Math.min((this.currentPage - 1) * PAGE_SIZE + 1, this.totalCount); }
    get resultsTo()   { return Math.min(this.currentPage * PAGE_SIZE, this.totalCount); }

    get pageNumbers() {
        const total = this.totalPages, cur = this.currentPage, pages = [];
        const add  = n => pages.push({ key: `pg-${n}`, num: n, label: String(n),
            btnClass: n === cur ? 'page-btn page-btn-active' : 'page-btn' });
        const dots = k => pages.push({ key: k, num: -1, label: '...', btnClass: 'page-btn page-btn-ellipsis' });
        if (total <= 7) {
            for (let i = 1; i <= total; i++) add(i);
        } else {
            add(1);
            if (cur > 3) dots('el-left');
            for (let i = Math.max(2, cur - 1); i <= Math.min(total - 1, cur + 1); i++) add(i);
            if (cur < total - 2) dots('el-right');
            add(total);
        }
        return pages;
    }

    // ── Search ──────────────────────────────────────────────────────────────

    handleSearchInput(event)   { this.searchKey = event.target.value; }
    handleSearchKeydown(event) { if (event.key === 'Enter') this.handleSearch(); }
    handleSearch() { this.activeSearchKey = this.searchKey; this.currentPage = 1; }

    // ── Filters ─────────────────────────────────────────────────────────────

    handleFilterChange(event) {
        const fieldApiName = event.target.dataset.field;
        const value        = event.detail.value;
        this.allFilters    = this.allFilters.map(f =>
            f.fieldApiName === fieldApiName ? { ...f, selectedValue: value } : f);
        this.activeFilters = { ...this.activeFilters, [fieldApiName]: value };
        this.currentPage   = 1;
    }

    handleClearFilters() {
        this.allFilters      = this.allFilters.map(f => ({ ...f, selectedValue: '' }));
        this.activeFilters   = {};
        this.searchKey       = '';
        this.activeSearchKey = '';
        this.currentPage     = 1;
    }

    // ── Pagination ───────────────────────────────────────────────────────────

    handlePrevPage() { if (!this.isFirstPage) this.currentPage -= 1; }
    handleNextPage() { if (!this.isLastPage)  this.currentPage += 1; }
    handlePageClick(event) {
        const page = parseInt(event.currentTarget.dataset.page, 10);
        if (page > 0) this.currentPage = page;
    }

    // ── 3-dot dropdown ───────────────────────────────────────────────────────

    handleDocumentClick(event) {
        if (!event.target.closest('.action-menu-wrapper')) this._dropdownOpenId = null;
    }

    handleMoreClick(event) {
        event.stopPropagation();
        const id = event.currentTarget.dataset.id;
        this._dropdownOpenId = (this._dropdownOpenId === id) ? null : id;
    }

    // ── Action button (Send Request / Cancel Request / Remove Connection) ────

    async handleButtonClick(event) {
        const { contact, name } = event.currentTarget.dataset;
        this._clickedUser         = contact;
        this._clickedFunctiontype = name;

        if (name === ACTIONS.SEND_REQUEST) {
            this.isLoading = true;
            const status = await checkUserStatus({ linkedConstituentId: contact });
            this.isLoading = false;
            const config = MODAL_CONFIG[name];
            if (status === 'Inactive User') {
                Object.assign(this, {
                    modalHeader: config.header, modalPrimaryButton: config.primaryButton,
                    modalSecondaryButton: config.secondaryButton, isRequestModal: config.isRequestModal,
                    showPrimaryButton: config.showPrimaryButton, showRequestModal: true,
                    isInactiveUser: true, primaryButtonClass: 'primary-button disable',
                    secondaryButtonClass: 'secondary-button disable'
                });
                return;
            }
        }

        const config = MODAL_CONFIG[name];
        if (config) {
            Object.assign(this, {
                modalHeader: config.header, modalPrimaryButton: config.primaryButton,
                modalSecondaryButton: config.secondaryButton, isRequestModal: config.isRequestModal,
                showPrimaryButton: config.showPrimaryButton, showRequestModal: true,
                isInactiveUser: false, primaryButtonClass: 'primary-button active',
                secondaryButtonClass: 'secondary-button secondary-active'
            });
        } else {
            // Cancel Request — no modal, direct action
            this._callApex();
        }
        this._dropdownOpenId = null;
    }

    // ── Bookmark icon ─────────────────────────────────────────────────────────

    handleBookmarkClick(event) {
        const { contact, name } = event.currentTarget.dataset;
        this._clickedUser         = contact;
        this._clickedFunctiontype = name;

        if (name === ACTIONS.REMOVE_BOOKMARK) {
            const config = MODAL_CONFIG[name];
            Object.assign(this, {
                modalHeader: config.header, modalPrimaryButton: config.primaryButton,
                modalSecondaryButton: config.secondaryButton, isRequestModal: false,
                showPrimaryButton: true, showRequestModal: true, isInactiveUser: false,
                primaryButtonClass: 'primary-button active',
                secondaryButtonClass: 'secondary-button secondary-active'
            });
        } else {
            // Bookmark — direct, no modal
            this._callApex();
        }
    }

    // ── Modal handlers ────────────────────────────────────────────────────────

    handleMessageChange(event) { this.personalizedMessage = event.target.value; }

    handleRequest(event) {
        if (event?.currentTarget?.dataset?.name === 'Cancel') {
            this.showRequestModal = false;
            return;
        }
        if (this._clickedFunctiontype === ACTIONS.SEND_REQUEST) {
            const textarea = this.template.querySelector('.message-textarea');
            if (!textarea?.value?.trim()) {
                textarea.setCustomValidity('Please enter a personalized message.');
                textarea.reportValidity();
                return;
            }
            textarea.setCustomValidity('');
        }
        this._callApex();
    }

    closeRequestModal() { this.showRequestModal = false; }

    // ── Apex call + refresh ───────────────────────────────────────────────────

    _callApex() {
        handleConnectionRequest({
            portalId:            this.contactId,
            linkedConstituentId: this._clickedUser,
            requestMessage:      this.personalizedMessage,
            functionType:        this._clickedFunctiontype
        })
        .then(result => {
            if (result === 'Success') {
                this._showToast(this._toastMsg(this._clickedFunctiontype), 'Success', 'success');
                this.showRequestModal = false;
                this._resetModal();
                return refreshApex(this._wiredMembers);
            } else if (result === 'Invitation Exist') {
                Object.assign(this, {
                    modalHeader: 'Invitation already exists', showPrimaryButton: false,
                    modalPrimaryButton: '', modalSecondaryButton: 'Cancel',
                    isRequestModal: false, showRequestModal: true,
                    primaryButtonClass: 'primary-button active',
                    secondaryButtonClass: 'secondary-button secondary-active'
                });
            }
        })
        .catch(() => this._showToast('Error occurred on update', 'Error', 'error'));
    }

    _toastMsg(functionType) {
        const map = {
            [ACTIONS.SEND_REQUEST]:      ToastReqSend,
            [ACTIONS.CANCEL_REQUEST]:    ToastCancelReq,
            [ACTIONS.BOOKMARK]:          ToastBookmarked,
            [ACTIONS.REMOVE_BOOKMARK]:   ToastRemBookmark,
            [ACTIONS.REMOVE_CONNECTION]: 'Connection removed.',
            [ACTIONS.BLOCK]:             ToastBlock
        };
        return map[functionType] || 'Preference updated!';
    }

    _showToast(message, title, variant) {
        Object.assign(this, { toastMessage: message, toastTitle: title,
            toastVariant: variant, toastDuration: 5000, showCustomToast: true });
    }

    _resetModal() {
        Object.assign(this, {
            _clickedUser: null, _clickedFunctiontype: null, personalizedMessage: '',
            modalHeader: '', modalPrimaryButton: '', modalSecondaryButton: '',
            isRequestModal: false, isInactiveUser: false
        });
    }

    handleToastClose() { this.showCustomToast = false; }

    // ── View Profile ──────────────────────────────────────────────────────────

    handleViewProfile(event) {
        const selectedContactId = event.currentTarget.dataset.id;
        this.dispatchEvent(new CustomEvent('profileoverview', {
            detail: { selectedContactId },
            bubbles: true,
            composed: true
        }));
        this._dropdownOpenId = null;
    }
}