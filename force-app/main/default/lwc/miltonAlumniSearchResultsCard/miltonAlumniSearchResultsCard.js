import { LightningElement, api } from 'lwc';
import updateConnection from '@salesforce/apex/miltonAlumniConnectionAction.updateConnection';
import getConnectionFlags from '@salesforce/apex/miltonAlumniConnectionAction.getConnectionFlags';
import checkUserStatus from '@salesforce/apex/miltonAlumniConnectionAction.checkUserStatus';
import MILTON_NECROLOGY_URL from '@salesforce/label/c.Milton_Necrology';
import MILTON_PROFILE_URL from '@salesforce/label/c.Milton_Profile_URL';

const SEND_REQUEST = 'Send Request';
const CANCEL_REQUEST = 'Cancel Request';
const REMOVE_CONNECTION = 'Remove Connection';
const BOOKMARK = 'Bookmark';
const REMOVE_BOOKMARK = 'Remove Bookmark';

const NOT_ACTIVE_MESSAGE = 'This person is not yet active.';
const INVITATION_EXIST_MESSAGE = 'This alumni already sent you a request.';
const GENERIC_ERROR_MESSAGE = 'Something went wrong. Please try again.';

const STORAGE_KEY_PREFIX = 'miltonAlumniConnectionState_';

export default class MiltonAlumniSearchResultsCard extends LightningElement {

    _value;
    alumniData = [];
    currentIndex = 0;

    @api
    get value() {
        return this._value;
    }

    set value(val) {
        this._value = val;
        this.processRecords();
    }

    get isFirstCard() {
        return this.currentIndex === 0;
    }

    get isLastCard() {
        return this.currentIndex >= this.alumniData.length - 1;
    }

    processRecords() {
        const records = this._value?.alumniRecords || [];
        const storedState = this.getStoredState();

        this.alumniData = records.map((alumni) => {
            const override = storedState[alumni.contactId];
            const merged = override ? { ...alumni, ...override } : alumni;
            return {
                ...merged,
                degreeLabel: merged.majorDegree ? `Degree: ${merged.majorDegree}` : 'Degree: -',
                yearLabel: merged.classOfYear ? `Graduation Year: ${merged.classOfYear}` : 'Graduation Year: -',
                isConnectionProcessing: false,
                isBookmarkProcessing: false,
                errorMessage: '',
                ...this.deriveActionState(merged)
            };
        });
        this.currentIndex = 0;
        this.reconcileConnectionState(storedState);
    }

    deriveActionState(alumni) {
        // Deceased alumni never get a connection action - Necrology is shown instead (see markup).
        // connectionPrivacyEnabled (SIV_VIS_CONNECTION) suppresses it too, with no replacement action.
        const connectionActionType = (alumni.isSelf || alumni.isDeceased || alumni.connectionPrivacyEnabled)
            ? null
            : alumni.isConnected
                ? REMOVE_CONNECTION
                : alumni.isRequestSent
                    ? CANCEL_REQUEST
                    : SEND_REQUEST;
        const isSendDisabled = connectionActionType === SEND_REQUEST && !alumni.isActive;
        const isConnectionProcessing = alumni.isConnectionProcessing || false;

        return {
            connectionActionType,
            isSendDisabled,
            tooltipText: isSendDisabled ? NOT_ACTIVE_MESSAGE : '',
            connectionButtonLabel: isConnectionProcessing ? 'Processing...' : connectionActionType,
            isConnectionButtonDisabled: isConnectionProcessing || isSendDisabled,
            bookmarkIconClass: alumni.isBookmarked ? 'bookmark-icon bookmarked' : 'bookmark-icon'
        };
    }

    // ---------- localStorage persistence (survives a browser refresh replaying
    // the original, now-stale Apex response for this chat message) ----------

    getStorageKey() {
        const contactId = this._value?.contactId;
        return contactId ? `${STORAGE_KEY_PREFIX}${contactId}` : null;
    }

    getStoredState() {
        const storageKey = this.getStorageKey();
        if (!storageKey) {
            return {};
        }
        try {
            const stored = window.localStorage.getItem(storageKey);
            return stored ? JSON.parse(stored) : {};
        } catch (error) {
            console.error('[MiltonAlumniSearchResultsCard] Error reading stored connection state:', error);
            return {};
        }
    }

    setStoredState(contactId, updates) {
        const storageKey = this.getStorageKey();
        if (!storageKey) {
            return;
        }
        try {
            const state = this.getStoredState();
            state[contactId] = { ...(state[contactId] || {}), ...updates };
            window.localStorage.setItem(storageKey, JSON.stringify(state));
        } catch (error) {
            console.error('[MiltonAlumniSearchResultsCard] Error persisting connection state:', error);
        }
    }

    // Verify every locally-overridden record against current backend truth —
    // a local override can go stale (e.g. the other person accepted/cancelled
    // elsewhere, or an admin changed the record) the same way a locally
    // "raised" flag can in the Volunteer card.
    async reconcileConnectionState(storedState) {
        const viewerContactId = this._value?.contactId;
        const idsToCheck = this.alumniData
            .filter((alumni) => storedState[alumni.contactId])
            .map((alumni) => alumni.contactId);

        if (!viewerContactId || !idsToCheck.length) {
            return;
        }

        try {
            const flagsByContactId = await getConnectionFlags({ viewerContactId, alumniContactIds: idsToCheck });
            idsToCheck.forEach((contactId) => {
                const flags = flagsByContactId[contactId];
                if (!flags) {
                    return;
                }
                // isActive isn't part of getConnectionFlags (it comes from the
                // Contact record on the original search, not reconciled here) —
                // leave whatever value is already on the record untouched.
                const updates = {
                    isConnected: flags.isConnected,
                    isBookmarked: flags.isBookmarked,
                    isRequestSent: flags.isRequestSent
                };
                this.setStoredState(contactId, updates);
                this.setAlumniState(contactId, updates);
            });
        } catch (error) {
            console.error('[MiltonAlumniSearchResultsCard] Error reconciling connection state:', error);
        }
    }

    handlePrev() {
        this.scrollToIndex(this.currentIndex - 1);
    }

    handleNext() {
        this.scrollToIndex(this.currentIndex + 1);
    }

    scrollToIndex(index) {
        const container = this.template.querySelector('.alumni-list-container');
        if (!container) {
            return;
        }
        const clampedIndex = Math.max(0, Math.min(index, this.alumniData.length - 1));
        container.scrollTo({ left: clampedIndex * container.clientWidth, behavior: 'smooth' });
        this.currentIndex = clampedIndex;
    }

    handleScroll(event) {
        const container = event.target;
        if (!container.clientWidth) {
            return;
        }
        this.currentIndex = Math.round(container.scrollLeft / container.clientWidth);
    }

    handleViewDetails(event) {
        const contactId = event.currentTarget.dataset.contactId;
        const url = `${MILTON_PROFILE_URL}${contactId}`;
        window.open(url, '_blank');
    }

    handleNecrologyClick() {
        window.open(MILTON_NECROLOGY_URL, '_blank');
    }

    async handleConnectionAction(event) {
        const contactId = event.currentTarget.dataset.contactId;
        const actionType = event.currentTarget.dataset.actionType;
        await this.runConnectionUpdate(contactId, actionType, 'isConnectionProcessing');
    }

    async handleBookmarkToggle(event) {
        const contactId = event.currentTarget.dataset.contactId;
        const alumni = this.alumniData.find((a) => a.contactId === contactId);
        if (!alumni) {
            return;
        }
        const actionType = alumni.isBookmarked ? REMOVE_BOOKMARK : BOOKMARK;
        await this.runConnectionUpdate(contactId, actionType, 'isBookmarkProcessing');
    }

    async runConnectionUpdate(contactId, actionType, processingField) {
        const portalId = this._value?.contactId;
        this.setAlumniState(contactId, { [processingField]: true, errorMessage: '' });

        try {
            // Same pre-check ham_alumniListDisplayCmp/ham_alumniGridDisplayCmp run
            // before a Send Request click — HAM_AlumniConnectionService.handleSendRequest
            // has an unguarded constituentUser[0] on an empty list, so we must never
            // call updateConnection for Send Request without checking first.
            if (actionType === SEND_REQUEST) {
                const status = await checkUserStatus({ linkedConstituentId: contactId });
                if (status === 'Inactive User') {
                    this.setStoredState(contactId, { isActive: false });
                    this.setAlumniState(contactId, { isActive: false, errorMessage: NOT_ACTIVE_MESSAGE });
                    return;
                }
            }

            const result = await updateConnection({ portalId, linkedConstituentId: contactId, functionType: actionType });
            this.applyUpdateResult(contactId, actionType, result);
        } catch (error) {
            console.error('[MiltonAlumniSearchResultsCard] Error updating connection:', error);
            this.setAlumniState(contactId, { errorMessage: GENERIC_ERROR_MESSAGE });
        } finally {
            this.setAlumniState(contactId, { [processingField]: false });
        }
    }

    applyUpdateResult(contactId, actionType, result) {
        if (result === 'Success') {
            const updates = {};
            if (actionType === SEND_REQUEST) {
                updates.isRequestSent = true;
            } else if (actionType === CANCEL_REQUEST) {
                updates.isRequestSent = false;
            } else if (actionType === REMOVE_CONNECTION) {
                updates.isConnected = false;
            } else if (actionType === BOOKMARK) {
                updates.isBookmarked = true;
            } else if (actionType === REMOVE_BOOKMARK) {
                updates.isBookmarked = false;
            }
            this.setStoredState(contactId, updates);
            this.setAlumniState(contactId, updates);
            return;
        }

        if (result === 'Invitation Exist') {
            this.setAlumniState(contactId, { errorMessage: INVITATION_EXIST_MESSAGE });
        } else if (result === 'Inactive User') {
            this.setStoredState(contactId, { isActive: false });
            this.setAlumniState(contactId, { errorMessage: NOT_ACTIVE_MESSAGE, isActive: false });
        } else {
            console.error('[MiltonAlumniSearchResultsCard] updateConnection returned non-success result:', actionType, result);
            this.setAlumniState(contactId, { errorMessage: GENERIC_ERROR_MESSAGE });
        }
    }

    setAlumniState(contactId, updates) {
        this.alumniData = this.alumniData.map((alumni) => {
            if (alumni.contactId !== contactId) {
                return alumni;
            }
            const merged = { ...alumni, ...updates };
            return { ...merged, ...this.deriveActionState(merged) };
        });
    }
}