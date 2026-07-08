import { LightningElement, api, track, wire } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import { updateRecord } from 'lightning/uiRecordApi';
import getGroupDetail from '@salesforce/apex/Ham_GroupsController.getGroupDetail';
import joinGroup      from '@salesforce/apex/Ham_GroupsController.joinGroup';
import leaveGroup     from '@salesforce/apex/Ham_GroupsController.leaveGroup';

export default class Ham_groupDashboard extends LightningElement {
    @api groupId;
    @api subview;
    @api userContactId;

    _isOverride = false;
    @api
    get isOverride() {
        return this._isOverride;
    }
    set isOverride(value) {
        this._isOverride = (value === true || value === 'true');
    }

    @track group                    = null;
    @track activeTab                = 'dashboard'; // Default landing view
    @track isLoading                = true;
    @track hasError                 = false;
    @track isMembershipLoading      = false;
    @track isNotificationDropdownOpen = false;

    // Leave-group exit survey state
    @track showLeaveModal = false;
    @track otherReasonText = '';
    @track leaveReasonOptions = [];

    // Join-request modal state
    @track showJoinModal = false;
    @track joinMessageText = '';
    @track showJoinConfirmation = false;

    // Picklist API values on HAM_Group_Member__c.Leave_Reason__c — keep in sync
    LEAVE_REASONS = [
        { value: 'Irrelevant content',  label: 'Irrelevant content' },
        { value: 'Low value',           label: 'Low value' },
        { value: 'Inactive group',      label: 'Inactive group' },
        { value: 'Negative experience', label: 'Negative experience' },
        { value: 'Other',               label: 'Other (Please specify)' }
    ];

    _wiredGroupDetail;

    @wire(getGroupDetail, { groupId: '$groupId', contactId: '$userContactId' })
    wiredGroupDetail(result) {
        this._wiredGroupDetail = result;
        this.isLoading = false;
        if (result.data) {
            this.group    = result.data;
            this.hasError = false;
            // If a specific subview was passed in (e.g. from deep links), respect it
            if (this.subview && this.subview !== 'dashboard' && this.subview !== 'default') {
                this.activeTab = this.subview;
            }
        } else if (result.error) {
            this.hasError = true;
        }
    }

    // ── Tab & Layout Getters ──────────────────────────────────────────────────

    get dashboardRootClass() {
        return `dashboard-root ${this.isOverride ? 'kirkland-override' : ''}`;
    }

    get isDashboardTab()  { return this.activeTab === 'dashboard'; }
    get isDiscussionTab()  { return this.activeTab === 'discussion'; }
    get isMembersTab()     { return this.activeTab === 'members'; }
    get isResourcesTab()   { return this.activeTab === 'resources'; }
    get isAdminTab()       { return this.activeTab === 'admin'; }
    get isAdmin()          { return this.group && this.group.userRole === 'Admin'; }
    get isMember()         { return this.group && this.group.userMembershipStatus === 'Active'; }
    get isBlockedFromGroup() { return this.group && this.group.userMembershipStatus === 'Blocked'; }

    get mainColumnClass() {
        return this.isDashboardTab
            ? 'slds-col slds-size_1-of-1 slds-medium-size_8-of-12 group-main'
            : 'slds-col slds-size_1-of-1 slds-medium-size_12-of-12 group-main';
    }

    // ── Notification Preferences Getters ──────────────────────────────────────

    get receiveNotifications() {
        return this.group ? !!this.group.receiveNotifications : false;
    }

    get notifyOnTagged() {
        return this.group ? !!this.group.notifyOnTagged : false;
    }

    get notifyOnAmplified() {
        return this.group ? !!this.group.notifyOnAmplified : false;
    }

    get isReceiveNotificationsDisabled() {
        return !this.receiveNotifications;
    }

    // ── Membership Button Getters ─────────────────────────────────────────────

    get membershipBtnLabel() {
        if (!this.group) return '';
        const status = this.group.userMembershipStatus;
        if (status === 'Active')  return 'Leave Group';
        if (status === 'Pending') return 'Cancel Request';
        return this.group.visibility === 'Private' ? 'Request to Join' : 'Join Group';
    }

    get membershipBtnClass() {
        const status = this.group && this.group.userMembershipStatus;
        return (status === 'Active' || status === 'Pending')
            ? 'btn-membership btn-membership-leave'
            : 'btn-membership btn-membership-join';
    }

    get adminJobTitle() {
        if (!this.group || !this.group.admin) return '';
        const { jobTitle, employer } = this.group.admin;
        if (jobTitle && employer) return `${jobTitle} at ${employer}`;
        return jobTitle || employer || '';
    }

    // ── Notification Dropdown Actions ─────────────────────────────────────────

    toggleNotificationDropdown(event) {
        event.stopPropagation();
        this.isNotificationDropdownOpen = !this.isNotificationDropdownOpen;
    }

    handleNotificationToggle(event) {
        const fieldApiName = event.currentTarget.dataset.field;
        const checkedValue = event.target.checked;

        if (!this.group || !this.group.userMembershipId) return;

        // Optimistically update local track state
        const updatedGroup = { ...this.group };
        if (fieldApiName === 'Receive_Notifications__c') {
            updatedGroup.receiveNotifications = checkedValue;
        } else if (fieldApiName === 'Notify_on_Tagged__c') {
            updatedGroup.notifyOnTagged = checkedValue;
        } else if (fieldApiName === 'Notify_on_Amplified__c') {
            updatedGroup.notifyOnAmplified = checkedValue;
        }
        this.group = updatedGroup;

        // Perform standard LDS update
        const fields = {};
        fields['Id'] = this.group.userMembershipId;
        fields[fieldApiName] = checkedValue;

        const recordInput = { fields };

        updateRecord(recordInput)
            .then(() => {
                // Success - refresh in background to align details
                refreshApex(this._wiredGroupDetail);
            })
            .catch(error => {
                console.error('Error updating notification preference', error);
                // Rollback optimistic state
                refreshApex(this._wiredGroupDetail);
            });
    }

    // ── Subview Routing Actions ───────────────────────────────────────────────

    handleGoToDiscussion() {
        this.activeTab = 'discussion';
        this.dispatchEvent(new CustomEvent('navigategroup', { 
            detail: { groupId: this.groupId, subview: 'discussion' } 
        }));
    }

    handleGoToResources() {
        this.activeTab = 'resources';
        this.dispatchEvent(new CustomEvent('navigategroup', { 
            detail: { groupId: this.groupId, subview: 'resources' } 
        }));
    }

    handleSeeMoreMembers() {
        this.activeTab = 'members';
        this.dispatchEvent(new CustomEvent('navigategroup', { 
            detail: { groupId: this.groupId, subview: 'members' } 
        }));
    }

    handleGoToAdmin() {
        this.activeTab = 'admin';
        this.dispatchEvent(new CustomEvent('navigategroup', { 
            detail: { groupId: this.groupId, subview: 'admin' } 
        }));
    }

    handleBackAction() {
        this.isNotificationDropdownOpen = false;
        if (this.activeTab !== 'dashboard') {
            this.activeTab = 'dashboard';
            this.dispatchEvent(new CustomEvent('navigategroup', { 
                detail: { groupId: this.groupId, subview: 'dashboard' } 
            }));
        } else {
            this.handleBackToDiscovery();
        }
    }

    handleBackToDiscovery() {
        this.dispatchEvent(new CustomEvent('backtodiscovery'));
    }

    handlePostCreated() {
        // Refresh feed components if they exist
        const feed = this.template.querySelector('[data-id="groupFeed"]');
        const feedFull = this.template.querySelector('[data-id="groupFeedFull"]');
        if (feed) feed.refresh();
        if (feedFull) feedFull.refresh();
    }

    async handleMembershipAction() {
        if (!this.group || this.isMembershipLoading) return;
        this.isNotificationDropdownOpen = false;

        const status = this.group.userMembershipStatus;

        // Active members get the confirmation dialog with the exit survey.
        if (status === 'Active') {
            this.openLeaveModal();
            return;
        }

        // Pending requests are just cancelled, no survey needed.
        if (status === 'Pending') {
            this.isMembershipLoading = true;
            try {
                await leaveGroup({
                    groupId: this.groupId,
                    contactId: this.userContactId,
                    leaveReasons: [],
                    otherReason: null
                });
                await refreshApex(this._wiredGroupDetail);
            } catch (error) {
                console.error('Membership action error', error);
            } finally {
                this.isMembershipLoading = false;
            }
            return;
        }

        // Not a member yet: collect an optional message before submitting the request.
        this.openJoinModal();
    }

    // ── Join Group Request ────────────────────────────────────────────────────

    openJoinModal() {
        this.joinMessageText = '';
        this.showJoinModal = true;
    }

    closeJoinModal() {
        this.showJoinModal = false;
    }

    handleJoinMessageChange(event) {
        this.joinMessageText = event.target.value;
    }

    closeJoinConfirmation() {
        this.showJoinConfirmation = false;
    }

    async confirmJoinRequest() {
        if (this.isMembershipLoading) return;
        this.isMembershipLoading = true;
        try {
            await joinGroup({
                groupId: this.groupId,
                contactId: this.userContactId,
                message: this.joinMessageText.trim() ? this.joinMessageText.trim() : null
            });
            this.showJoinModal = false;
            this.showJoinConfirmation = true;
            await refreshApex(this._wiredGroupDetail);
        } catch (error) {
            console.error('Join request error', error);
        } finally {
            this.isMembershipLoading = false;
        }
    }

    // ── Leave Group Confirmation ──────────────────────────────────────────────

    openLeaveModal() {
        // Fresh checkboxes each time the dialog opens
        this.leaveReasonOptions = this.LEAVE_REASONS.map(r => ({ ...r, checked: false }));
        this.otherReasonText = '';
        this.showLeaveModal = true;
    }

    closeLeaveModal() {
        this.showLeaveModal = false;
    }

    handleLeaveReasonChange(event) {
        const reasonValue = event.target.dataset.value;
        const isChecked = event.target.checked;
        this.leaveReasonOptions = this.leaveReasonOptions.map(r =>
            r.value === reasonValue ? { ...r, checked: isChecked } : r
        );
        if (reasonValue === 'Other' && !isChecked) {
            this.otherReasonText = '';
        }
    }

    handleOtherReasonChange(event) {
        this.otherReasonText = event.target.value;
    }

    get selectedLeaveReasons() {
        return this.leaveReasonOptions.filter(r => r.checked).map(r => r.value);
    }

    get isOtherReasonSelected() {
        return this.leaveReasonOptions.some(r => r.value === 'Other' && r.checked);
    }

    // At least one reason is mandatory; "Other" additionally needs the free text
    get isLeaveConfirmDisabled() {
        if (this.isMembershipLoading) return true;
        const selected = this.selectedLeaveReasons;
        if (selected.length === 0) return true;
        if (this.isOtherReasonSelected && !this.otherReasonText.trim()) return true;
        return false;
    }

    async confirmLeaveGroup() {
        if (this.isLeaveConfirmDisabled) return;
        this.isMembershipLoading = true;
        try {
            await leaveGroup({
                groupId: this.groupId,
                contactId: this.userContactId,
                leaveReasons: this.selectedLeaveReasons,
                otherReason: this.isOtherReasonSelected ? this.otherReasonText.trim() : null
            });
            this.showLeaveModal = false;
            await refreshApex(this._wiredGroupDetail);
        } catch (error) {
            console.error('Leave group error', error);
        } finally {
            this.isMembershipLoading = false;
        }
    }
}