import { LightningElement, api, track, wire } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import getGroupDetail from '@salesforce/apex/Ham_GroupsController.getGroupDetail';
import joinGroup      from '@salesforce/apex/Ham_GroupsController.joinGroup';
import leaveGroup     from '@salesforce/apex/Ham_GroupsController.leaveGroup';
import updateNotificationPreferences from '@salesforce/apex/Ham_GroupsController.updateNotificationPreferences';

export default class Ham_groupDashboard extends LightningElement {
    @api groupId;
    @api subview;
    @api userContactId;
    @api images = {};

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

    // Notification toggles are staged locally until "Save" is clicked, rather
    // than writing to the server on every tap — lets the user review/undo before
    // committing, and batches multiple changes into a single Apex call.
    @track pendingNotificationChanges = {};
    @track isSavingNotifications = false;

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
    get isMembershipRequestsTab() { return this.activeTab === 'requests'; }
    get isAdmin()          { return this.group && this.group.userRole === 'Admin'; }
    get isMember()         { return this.group && this.group.userMembershipStatus === 'Active'; }
    get isBlockedFromGroup() { return this.group && this.group.userMembershipStatus === 'Blocked'; }

    get mainColumnClass() {
        return this.isDashboardTab
            ? 'slds-col slds-size_1-of-1 slds-medium-size_8-of-12 group-main'
            : 'slds-col slds-size_1-of-1 slds-medium-size_12-of-12 group-main';
    }

    // ── Notification Preferences Getters ──────────────────────────────────────
    // "effective" = last-saved value, unless the user has tapped it since opening
    // the dropdown, in which case the staged (unsaved) value wins.

    get receiveNotifications() {
        return this.group ? !!this.group.receiveNotifications : false;
    }

    get notifyOnTagged() {
        return this.group ? !!this.group.notifyOnTagged : false;
    }

    get notifyOnAmplified() {
        return this.group ? !!this.group.notifyOnAmplified : false;
    }

    get effectiveReceiveNotifications() {
        return 'Receive_Notifications__c' in this.pendingNotificationChanges
            ? this.pendingNotificationChanges.Receive_Notifications__c
            : this.receiveNotifications;
    }

    get effectiveNotifyOnTagged() {
        return 'Notify_on_Tagged__c' in this.pendingNotificationChanges
            ? this.pendingNotificationChanges.Notify_on_Tagged__c
            : this.notifyOnTagged;
    }

    get effectiveNotifyOnAmplified() {
        return 'Notify_on_Amplified__c' in this.pendingNotificationChanges
            ? this.pendingNotificationChanges.Notify_on_Amplified__c
            : this.notifyOnAmplified;
    }

    get isReceiveNotificationsDisabled() {
        return !this.effectiveReceiveNotifications;
    }

    get receiveNotificationsTrackClass() {
        return this.effectiveReceiveNotifications ? 'custom-toggle-track checked' : 'custom-toggle-track';
    }

    get notifyOnTaggedTrackClass() {
        return this.effectiveNotifyOnTagged ? 'custom-toggle-track checked' : 'custom-toggle-track';
    }

    get notifyOnAmplifiedTrackClass() {
        return this.effectiveNotifyOnAmplified ? 'custom-toggle-track checked' : 'custom-toggle-track';
    }

    get subToggleWrapperClass() {
        return this.isReceiveNotificationsDisabled ? 'custom-toggle-wrapper disabled' : 'custom-toggle-wrapper';
    }

    get hasPendingNotificationChanges() {
        return Object.keys(this.pendingNotificationChanges).length > 0;
    }

    get saveNotificationsLabel() {
        return this.isSavingNotifications ? 'Saving...' : 'Save';
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

    get hasMemberPreviews() {
        return !!(this.group && this.group.memberPreviews && this.group.memberPreviews.length);
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
        const opening = !this.isNotificationDropdownOpen;
        this.isNotificationDropdownOpen = opening;
        // Closing without an explicit Save discards any staged taps
        if (!opening) {
            this.pendingNotificationChanges = {};
        }
    }

    handleNotificationToggle(event) {
        event.stopPropagation();
        const fieldApiName = event.currentTarget.dataset.field;

        if (!this.group || !this.group.userMembershipId) return;
        if (fieldApiName !== 'Receive_Notifications__c' && this.isReceiveNotificationsDisabled) return;

        const updated = { ...this.pendingNotificationChanges };
        const newValue = !this.effectiveValueOf(fieldApiName);
        this.stageChange(updated, fieldApiName, newValue);

        // Switching the master off switches Tagged and Amplified off with it — they're
        // saved as false, not just greyed out, so turning the master back on brings them
        // back off. Apex re-applies the same cascade on save.
        if (fieldApiName === 'Receive_Notifications__c' && newValue === false) {
            ['Notify_on_Tagged__c', 'Notify_on_Amplified__c'].forEach(dependentField => {
                this.stageChange(updated, dependentField, false);
            });
        }

        this.pendingNotificationChanges = updated;
    }

    effectiveValueOf(fieldApiName) {
        if (fieldApiName === 'Receive_Notifications__c') return this.effectiveReceiveNotifications;
        if (fieldApiName === 'Notify_on_Tagged__c')      return this.effectiveNotifyOnTagged;
        if (fieldApiName === 'Notify_on_Amplified__c')   return this.effectiveNotifyOnAmplified;
        return false;
    }

    savedValueOf(fieldApiName) {
        if (fieldApiName === 'Receive_Notifications__c') return this.receiveNotifications;
        if (fieldApiName === 'Notify_on_Tagged__c')      return this.notifyOnTagged;
        if (fieldApiName === 'Notify_on_Amplified__c')   return this.notifyOnAmplified;
        return false;
    }

    // Stages a field onto the pending map, or drops it if the value is already what's
    // saved — so a field the user toggled back and forth doesn't ride along in the Save.
    stageChange(pending, fieldApiName, newValue) {
        if (newValue === this.savedValueOf(fieldApiName)) {
            delete pending[fieldApiName];
        } else {
            pending[fieldApiName] = newValue;
        }
    }

    handleCancelNotifications(event) {
        event.stopPropagation();
        this.pendingNotificationChanges = {};
    }

    // Click-outside-to-close: mirrors toggleNotificationDropdown's close path —
    // shut the dropdown and discard any staged (unsaved) toggle changes.
    closeNotificationDropdown() {
        this.isNotificationDropdownOpen = false;
        this.pendingNotificationChanges = {};
    }

    handleSaveNotifications(event) {
        event.stopPropagation();
        if (!this.hasPendingNotificationChanges || !this.group || !this.group.userMembershipId) return;

        this.isSavingNotifications = true;
        // Routed through Apex (without sharing) rather than lightning/uiRecordApi's
        // updateRecord — HAM_Group_Member__c's sharing model doesn't grant portal
        // users standard edit access to their own row, so a direct LDS write
        // silently fails here the same way it would for any other write in this
        // module if it didn't go through the custom without-sharing controller.
        updateNotificationPreferences({
            membershipId: this.group.userMembershipId,
            currentContactId: this.userContactId,
            changes: this.pendingNotificationChanges
        })
            .then(() => {
                this.pendingNotificationChanges = {};
                return refreshApex(this._wiredGroupDetail);
            })
            .catch(error => {
                console.error('Error saving notification preferences', error);
            })
            .finally(() => {
                this.isSavingNotifications = false;
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

    handleGoToRequests() {
        this.activeTab = 'requests';
        this.dispatchEvent(new CustomEvent('navigategroup', {
            detail: { groupId: this.groupId, subview: 'requests' }
        }));
    }

    handleBackAction() {
        this.isNotificationDropdownOpen = false;
        this.pendingNotificationChanges = {};
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