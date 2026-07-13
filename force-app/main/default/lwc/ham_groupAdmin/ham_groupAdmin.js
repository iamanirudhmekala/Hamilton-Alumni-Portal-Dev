import { LightningElement, api, track } from 'lwc';
import getReportedContent from '@salesforce/apex/Ham_GroupsController.getReportedContent';
import resolveReport from '@salesforce/apex/Ham_GroupsController.resolveReport';
import takeReportAction from '@salesforce/apex/Ham_GroupsController.takeReportAction';
import getPendingMembers from '@salesforce/apex/Ham_GroupsController.getPendingMembers';
import approveMember from '@salesforce/apex/Ham_GroupsController.approveMember';
import rejectMember from '@salesforce/apex/Ham_GroupsController.rejectMember';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

const REPORT_ACTIONS = [
    {
        code: 'Warn',
        title: 'Warn the User',
        description: 'Send a warning message to not send such content again.',
        icon: 'utility:warning',
        template: 'You have received a warning for inappropriate content. Please refrain from posting such content in the future to avoid further action.'
    },
    {
        code: 'Delete',
        title: 'Delete the Content',
        description: 'Remove the content from group and send a warning that next time a bigger step will be taken.',
        icon: 'utility:delete',
        template: 'Your recent post was removed because it didn\'t align with our community guidelines. Please consider this a formal warning. Future violations may result in a permanent ban from the group.'
    },
    {
        code: 'Block',
        title: 'Remove Content & Block User',
        description: 'Remove the user and inform them they were removed from the group due to inappropriate behavior that violates policy terms.',
        icon: 'utility:block_visitor',
        template: 'This is to inform you that you have been removed from the group for violating our community guidelines regarding appropriate behavior. Consequently, your previous posts and comments have also been deleted.'
    }
];

export default class Ham_groupAdmin extends LightningElement {
    @api groupId;
    @api contactId;

    _isPreview = false;
    @api
    get isPreview() {
        return this._isPreview;
    }
    set isPreview(value) {
        this._isPreview = (value === true || value === 'true');
    }

    _isOverride = false;
    @api
    get isOverride() {
        return this._isOverride;
    }
    set isOverride(value) {
        this._isOverride = (value === true || value === 'true');
    }

    // Dedicated full-page view (its own dashboard subview) showing only the
    // membership requests queue, full-width — no Reports column alongside it.
    _requestsOnly = false;
    @api
    get requestsOnly() {
        return this._requestsOnly;
    }
    set requestsOnly(value) {
        this._requestsOnly = (value === true || value === 'true');
    }

    get rootClass() {
        return `admin-root ${this.isOverride ? 'kirkland-override' : ''} ${this.isPreview ? 'preview-mode' : ''}`;
    }

    @track reportsDashboard = {
        totalReports: 0,
        resolvedCount: 0,
        pendingCount: 0,
        pendingReports: [],
        resolvedReports: []
    };
    @track pendingMembers = [];
    @track isLoading = false;
    @track activeMobileTab = 'reports'; // 'reports' | 'requests'
    @track isMobileView = false;
    @track activeReportsView = 'pending'; // 'pending' | 'resolved'

    // The Reports/Requests segmented control only makes sense when both columns
    // can appear — hidden on the dedicated requests-only page.
    get showMobileSegmentedControl() {
        return !this.isPreview && !this.requestsOnly && this.isMobileView;
    }

    // Take Action modal (2-step: choose action → review/edit message)
    @track showTakeActionModal = false;
    @track takeActionStep = 1;
    @track selectedActionCode = null;
    @track actionMessage = '';
    @track activeReport = null;
    @track isSubmittingAction = false;

    connectedCallback() {
        this.detectViewport();
        window.addEventListener('resize', this.detectViewport.bind(this));
        this.loadAdminData();
    }

    disconnectedCallback() {
        window.removeEventListener('resize', this.detectViewport.bind(this));
    }

    detectViewport() {
        this.isMobileView = window.innerWidth < 768;
    }

    loadAdminData() {
        this.isLoading = true;
        Promise.all([
            this.loadReports(),
            this.loadPendingMembers()
        ])
        .catch(err => {
            console.error('Error loading admin data:', err);
            this.showToast('Error', 'Could not load administration queues.', 'error');
        })
        .finally(() => {
            this.isLoading = false;
        });
    }

    loadReports() {
        return getReportedContent({ groupId: this.groupId, currentContactId: this.contactId })
            .then(data => {
                if (data) {
                    this.reportsDashboard = {
                        ...data,
                        pendingReports: (data.pendingReports || []).map(rep => this.mapReport(rep)),
                        resolvedReports: (data.resolvedReports || []).map(rep => this.mapReport(rep))
                    };
                }
            });
    }

    mapReport(rep) {
        return {
            ...rep,
            reportTypeLabel: rep.isUserReport ? 'User Report' : 'Message Report',
            reportTypeClass: rep.isUserReport ? 'badge-report-type badge-user-report' : 'badge-report-type badge-message-report',
            timeAgo: this.formatTimeAgo(rep.createdDate)
        };
    }

    formatTimeAgo(dateVal) {
        if (!dateVal) return '';
        const date = new Date(dateVal);
        const seconds = Math.floor((new Date() - date) / 1000);
        if (seconds < 60) return 'Just now';
        const minutes = Math.floor(seconds / 60);
        if (minutes < 60) return `${minutes}m ago`;
        const hours = Math.floor(minutes / 60);
        if (hours < 24) return `${hours}h ago`;
        const days = Math.floor(hours / 24);
        return `${days}d ago`;
    }

    loadPendingMembers() {
        return getPendingMembers({ groupId: this.groupId, currentContactId: this.contactId })
            .then(data => {
                if (data) {
                    this.pendingMembers = data;
                }
            });
    }

    // ─── Moderation Action Handlers ──────────────────────────────────────────

    handleResolveReport(event) {
        const reportId = event.currentTarget.dataset.reportId;
        const actionType = event.currentTarget.dataset.action; // 'Dismiss'

        this.isLoading = true;
        resolveReport({ reportId, actionType, currentContactId: this.contactId })
            .then(() => {
                this.showToast('Success', 'Report dismissed successfully.', 'success');
                return this.loadReports();
            })
            .catch(err => {
                console.error('Error resolving report:', err);
                this.showToast('Error', err.body?.message || 'Could not resolve report.', 'error');
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    handleReopenReport(event) {
        const reportId = event.currentTarget.dataset.reportId;

        this.isLoading = true;
        resolveReport({ reportId, actionType: 'Reopen', currentContactId: this.contactId })
            .then(() => {
                this.showToast('Success', 'Report reopened and moved back to Pending.', 'success');
                return this.loadReports();
            })
            .catch(err => {
                console.error('Error reopening report:', err);
                this.showToast('Error', err.body?.message || 'Could not reopen report.', 'error');
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    handleReportsViewChange(event) {
        this.activeReportsView = event.currentTarget.dataset.view;
    }

    get isPendingReportsView() {
        return this.activeReportsView === 'pending';
    }

    get isResolvedReportsView() {
        return this.activeReportsView === 'resolved';
    }

    get visiblePendingReports() {
        return this.isPreview
            ? this.reportsDashboard.pendingReports.slice(0, 2)
            : this.reportsDashboard.pendingReports;
    }

    // Two-cards-per-row only applies to the full moderation page — the
    // dashboard's Content Moderation preview widget stays single-column.
    get reportsListClass() {
        return this.isPreview ? 'reports-list' : 'reports-list reports-list-grid';
    }

    handleSeeMore(event) {
        event.stopPropagation();
        this.dispatchEvent(new CustomEvent('seemore'));
    }

    get pendingViewTabClass() {
        return `report-view-tab ${this.isPendingReportsView ? 'active' : ''}`;
    }

    get resolvedViewTabClass() {
        return `report-view-tab ${this.isResolvedReportsView ? 'active' : ''}`;
    }

    // ─── Take Action Modal (Warn / Delete / Block) ───────────────────────────

    openTakeActionModal(event) {
        const reportId = event.currentTarget.dataset.reportId;
        const userName = event.currentTarget.dataset.user;
        this.activeReport = { reportId, userName };
        this.selectedActionCode = null;
        this.actionMessage = '';
        this.takeActionStep = 1;
        this.showTakeActionModal = true;
    }

    closeTakeActionModal() {
        this.showTakeActionModal = false;
        this.activeReport = null;
    }

    selectAction(event) {
        this.selectedActionCode = event.currentTarget.dataset.code;
    }

    handleContinueToMessage() {
        if (!this.selectedActionCode) return;
        this.actionMessage = this.selectedAction.template;
        this.takeActionStep = 2;
    }

    handleBackToOptions() {
        this.takeActionStep = 1;
    }

    handleActionMessageChange(event) {
        this.actionMessage = event.target.value;
    }

    confirmTakeAction() {
        if (!this.activeReport || this.isSubmittingAction) return;
        this.isSubmittingAction = true;

        takeReportAction({
            reportId: this.activeReport.reportId,
            actionType: this.selectedActionCode,
            message: this.actionMessage,
            currentContactId: this.contactId
        })
            .then(() => {
                this.showToast('Success', 'Action has been taken and the member has been notified by email.', 'success');
                this.closeTakeActionModal();
                return this.loadReports();
            })
            .catch(err => {
                console.error('Error taking action on report:', err);
                this.showToast('Error', err.body?.message || 'Could not complete this action.', 'error');
            })
            .finally(() => {
                this.isSubmittingAction = false;
            });
    }

    get takeActionOptions() {
        return REPORT_ACTIONS.map(a => ({
            ...a,
            cardClass: a.code === this.selectedActionCode ? 'action-option selected' : 'action-option'
        }));
    }

    get selectedAction() {
        return REPORT_ACTIONS.find(a => a.code === this.selectedActionCode) || null;
    }

    get isTakeActionStepOne() {
        return this.takeActionStep === 1;
    }

    get isTakeActionStepTwo() {
        return this.takeActionStep === 2;
    }

    get isContinueDisabled() {
        return !this.selectedActionCode;
    }

    get continueBtnClass() {
        return this.isContinueDisabled ? 'btn-modal-primary disabled' : 'btn-modal-primary';
    }

    // ─── Membership Request Handlers ─────────────────────────────────────────

    handleApproveMember(event) {
        const memberId = event.currentTarget.dataset.memberId;
        
        this.isLoading = true;
        approveMember({ memberId, currentContactId: this.contactId })
            .then(() => {
                this.showToast('Approved', 'Member request accepted.', 'success');
                return this.loadPendingMembers();
            })
            .catch(err => {
                console.error('Error approving member:', err);
                this.showToast('Error', err.body?.message || 'Could not approve membership.', 'error');
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    handleRejectMember(event) {
        const memberId = event.currentTarget.dataset.memberId;
        
        this.isLoading = true;
        rejectMember({ memberId, currentContactId: this.contactId })
            .then(() => {
                this.showToast('Ignored', 'Member request has been ignored.', 'success');
                return this.loadPendingMembers();
            })
            .catch(err => {
                console.error('Error rejecting member:', err);
                this.showToast('Error', err.body?.message || 'Could not reject membership.', 'error');
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    // ─── Content Routing Helper ──────────────────────────────────────────────

    handleViewContent(event) {
        const postId = event.currentTarget.dataset.postId;
        const commentId = event.currentTarget.dataset.commentId;

        // Groups only render under the Community tab's Groups sub-tab (view=groups
        // is a dead/commented-out route in ham_MainCmp) — see ham_MainCmp.js
        // handleWidgetViewGroup for the same URL scheme.
        let targetSearch = `?view=community&tab=Groups&groupId=${this.groupId}&subview=discussion&postId=${postId}`;
        if (commentId) {
            targetSearch += `&commentId=${commentId}`;
        }
        targetSearch += '&mode=moderator';

        // Redirect via LWR URL search query params
        window.location.search = targetSearch;
    }

    // ─── Mobile Segmented Control ────────────────────────────────────────────

    handleMobileTabChange(event) {
        this.activeMobileTab = event.currentTarget.dataset.tab;
    }

    // Getters for display states
    get isReportsTab() {
        if (this.requestsOnly) {
            return false;
        }
        return !this.isMobileView || this.activeMobileTab === 'reports';
    }

    get isRequestsTab() {
        if (this.requestsOnly) {
            return true;
        }
        if (this.isPreview) {
            return false;
        }
        return !this.isMobileView || this.activeMobileTab === 'requests';
    }

    get reportsColumnClass() {
        return this.isPreview
            ? 'slds-col slds-size_1-of-1 admin-col'
            : 'slds-col slds-size_1-of-1 slds-medium-size_7-of-12 admin-col';
    }

    get requestsColumnClass() {
        return this.requestsOnly
            ? 'slds-col slds-size_1-of-1 admin-col'
            : 'slds-col slds-size_1-of-1 slds-medium-size_5-of-12 admin-col';
    }

    // Requests column is capped on the combined Admin page (matches the Reports
    // preview pattern) — the dedicated requests-only page shows the full list.
    get visiblePendingMembers() {
        return this.requestsOnly
            ? this.pendingMembers
            : this.pendingMembers.slice(0, 4);
    }

    // Always shown on the combined Admin page (not just when there's overflow past
    // 4 rows) — mirrors the Reports preview's unconditional "See more" affordance.
    get showRequestsSeeMore() {
        return !this.requestsOnly;
    }

    handleGoToRequestsPage(event) {
        if (event) event.stopPropagation();
        this.dispatchEvent(new CustomEvent('seerequests'));
    }

    get mobileReportsClass() {
        return `segmented-btn ${this.activeMobileTab === 'reports' ? 'active' : ''}`;
    }

    get mobileRequestsClass() {
        return `segmented-btn ${this.activeMobileTab === 'requests' ? 'active' : ''}`;
    }

    showToast(title, message, variant) {
        this.dispatchEvent(
            new ShowToastEvent({ title, message, variant })
        );
    }
}