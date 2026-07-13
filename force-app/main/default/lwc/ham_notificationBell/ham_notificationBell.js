import { LightningElement, wire, track, api } from 'lwc';
import { subscribe, unsubscribe, MessageContext, publish } from 'lightning/messageService';
import NOTIFICATION_CHANNEL from '@salesforce/messageChannel/ham_notificationChannel__c';

import { refreshApex } from '@salesforce/apex';
import getCurrentUserContactId from '@salesforce/apex/HAM_NotificationController.getCurrentUserContactId';
import getUnreadCount from '@salesforce/apex/HAM_NotificationController.getUnreadCount';
import getNotifications from '@salesforce/apex/HAM_NotificationController.getNotifications';
import markAllAsRead from '@salesforce/apex/HAM_NotificationController.markAllAsRead';
import approveRejectConnection from '@salesforce/apex/HAM_NotificationController.approveRejectConnection';
import getPollingInterval from '@salesforce/apex/HAM_NotificationController.getPollingInterval';
import notificationSound from '@salesforce/resourceUrl/HAM_Notify_Sound';


// Importing custom labels
import CONNECTION from '@salesforce/label/c.HAM_Connection';
import ACTIONED from '@salesforce/label/c.HAM_Actioned';
import TITLE from '@salesforce/label/c.HAM_Title_Notification';
import SENDER_NAME from '@salesforce/label/c.HAM_Sender_Name';
import CONNECTED from '@salesforce/label/c.HAM_Connected';
import REJECTED from '@salesforce/label/c.HAM_Rejected';

export default class Ham_notificationBell extends LightningElement {
    @track unreadCount = 0;
    @track notifications;
    @track isDropdownOpen = false;
    @api selectedTab;
    @api isOverride = false;
    @api images;

    get wrapperClass() {
        const override = this.isOverride === true || this.isOverride === 'true';
        return override ? 'notification-container kirkland-override' : 'notification-container';
    }

    currentUserContactId;
    pollingInterval = 15000;
    pollingTimer;

    wiredCountResult;
    wiredNotifsResult;

    audioObj = new Audio(notificationSound);
    audioUnlocked = false;

    // NEW: Flag to track if the initial baseline has been set
    isInitialized = false;

    labels = {
        connection: CONNECTION,
        actioned: ACTIONED,
        title: TITLE,
        sender_name: SENDER_NAME,
        connected: CONNECTED,
        rejected: REJECTED
    };

    @wire(MessageContext)
    messageContext;

    connectedCallback() {
        // Added 'touchstart' to ensure quick audio unlock on mobile
        window.addEventListener('click', this.unlockAudio);
        window.addEventListener('keydown', this.unlockAudio);
        window.addEventListener('touchstart', this.unlockAudio);
    }

    unlockAudio = () => {
        if (this.audioUnlocked) return;

        // Mute it for the warm-up
        this.audioObj.muted = true;

        this.audioObj.play()
            .then(() => {
                this.audioObj.pause();
                this.audioObj.currentTime = 0;

                this.audioUnlocked = true;

                window.removeEventListener('click', this.unlockAudio);
                window.removeEventListener('keydown', this.unlockAudio);
                window.removeEventListener('touchstart', this.unlockAudio);
            })
            .catch(err => {
                console.warn('Audio unlock failed:', err);
            });
    }

    @wire(getCurrentUserContactId)
    wiredContact({ error, data }) {
        if (data) {
            this.currentUserContactId = data;
            this.initPolling();
        } else if (error) {
            console.error('Error fetching contact context:', error);
        }
    }

    @wire(getUnreadCount, { contactId: '$currentUserContactId' })
    wiredCount(result) {
        this.wiredCountResult = result;
        if (result.data !== undefined) {
            this.unreadCount = result.data;
            // Capture baseline if the wire finishes before the first poll
            this.isInitialized = true;
        }
    }

    @wire(getNotifications, { contactId: '$currentUserContactId' })
    wiredNotifs(result) {
        this.wiredNotifsResult = result;
        if (result.data) {
            this.notifications = result.data.map(notif => {
                const sender = notif.HAM_Sender_Contact__r;
                return {
                    ...notif,
                    senderName: sender ? sender.Name : this.labels.sender_name,
                    senderPhoto: sender && sender.HAM_Profile_Picture_URL__c ? sender.HAM_Profile_Picture_URL__c : null,
                    isConnectionRequest: (notif.HAM_Source_Type__c === this.labels.connection && notif.HAM_Status__c !== this.labels.actioned && notif.HAM_Title__c === this.labels.title),
                    iconName: notif.HAM_Source_Type__c === this.labels.connection ? 'standard:user' : 'standard:announcement',
                    // Rows with a stored action URL navigate on click; others render as before
                    rowClass: notif.HAM_Action_URL__c ? 'notification-item clickable' : 'notification-item'
                };
            });
        }
    }

    initPolling() {
        getPollingInterval()
            .then(intervalSec => {
                this.pollingInterval = intervalSec * 1000;
                this.startPolling();
            })
            .catch(err => {
                console.error('Error fetching polling interval:', err);
                this.startPolling();
            });
    }

    startPolling() {
        this.pollingTimer = setInterval(() => {
            const oldCount = this.unreadCount;

            // Pass 'false' so we only do a lightweight refresh (count only) during polling
            this.refreshData(false).then(() => {
                // Guardrail: Do not play sound if this is the very first time data is settling
                if (!this.isInitialized) {
                    this.isInitialized = true;
                    return;
                }

                // Only play sound if the baseline is established AND the count goes up
                if (this.unreadCount > oldCount) {
                    this.playSound();
                }
            });
        }, this.pollingInterval);
    }

    disconnectedCallback() {
        if (this.pollingTimer) clearInterval(this.pollingTimer);
    }

    playSound() {
        if (this.audioUnlocked) {
            // Unmute the audio ONLY when a real notification arrives
            this.audioObj.muted = false;

            this.audioObj.currentTime = 0;
            this.audioObj.play().catch(err => console.warn('Audio play error', err));
        } else {
            console.warn('Notification received, but audio blocked until user interacts with page.');
        }
    }

    // NEW OPTIMIZATION: Allows forcing a full refresh of both wires, 
    // or just a lightweight count check for the background interval.
    refreshData(forceFullRefresh = true) {
        if (forceFullRefresh) {
            // User interacted (marked read, approved/rejected) -> Force refresh everything
            return Promise.all([
                refreshApex(this.wiredCountResult),
                refreshApex(this.wiredNotifsResult)
            ]);
        } else {
            // Background polling -> Check count first. Only fetch the heavy list if count changes.
            const oldCount = this.unreadCount;
            return refreshApex(this.wiredCountResult).then(() => {
                if (this.unreadCount !== oldCount) {
                    return refreshApex(this.wiredNotifsResult);
                }
            });
        }
    }

    toggleDropdown() {
        this.isDropdownOpen = !this.isDropdownOpen;
    }

    handleMarkAllRead() {
        markAllAsRead({ contactId: this.currentUserContactId })
            .then(() => {
                this.refreshData(true); // Force full refresh
            })
            .catch(error => {
                console.error('Error marking read', error);
            });
    }

    // Navigates via the stored action URL (relative '?view=...' form). A full
    // page load re-enters the SPA through ham_MainCmp's deep-link parser — the
    // same path a push-notification tap takes, on desktop and mobile alike.
    handleNotificationClick(event) {
        const actionUrl = event.currentTarget.dataset.url;
        if (!actionUrl) return;
        window.location.href = actionUrl;
    }

    handleApprove(event) {
        event.stopPropagation(); // Keep the row's navigation click from firing
        const connectionId = event.target.dataset.id;
        this.processAction(connectionId, this.labels.connected);
    }

    handleReject(event) {
        event.stopPropagation(); // Keep the row's navigation click from firing
        const connectionId = event.target.dataset.id;
        this.processAction(connectionId, this.labels.rejected);
    }

    processAction(id, status) {
        approveRejectConnection({ connectionId: id, action: status })
            .then(() => {
                const message = { currentTab: this.selectedTab };
                publish(this.messageContext, NOTIFICATION_CHANNEL, message);
                this.refreshData(true); // Force full refresh
            })
            .catch(error => {
                console.error('Error process action', error);
            });
    }

    get hasUnread() {
        return this.unreadCount > 0;
    }

    get hasNotifications() {
        return this.notifications && this.notifications.length > 0;
    }
}