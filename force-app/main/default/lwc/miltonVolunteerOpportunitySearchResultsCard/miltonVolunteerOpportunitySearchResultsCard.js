import { LightningElement, api } from 'lwc';
import setInterested from '@salesforce/apex/miltonVolunteerOpportunityInterestAction.setInterested';
import getActiveInterestValueIds from '@salesforce/apex/miltonVolunteerOpportunityInterestAction.getActiveInterestValueIds';

const STORAGE_KEY_PREFIX = 'miltonVolunteerOpportunityRaised_';

export default class MiltonVolunteerOpportunitySearchResultsCard extends LightningElement {

    _value;
    opportunityData = [];
    currentIndex = 0;

    @api
    get value() {
        console.log('[MiltonVolunteerOpportunitySearchResultsCard] get value', this._value);
        return this._value;
    }

    set value(val) {
        console.log('[MiltonVolunteerOpportunitySearchResultsCard] set value', JSON.stringify(val));
        this._value = val;
        this.processRecords();
        this.reconcileRaisedIds();
    }

    get isFirstCard() {
        return this.currentIndex === 0;
    }

    get isLastCard() {
        return this.currentIndex >= this.opportunityData.length - 1;
    }

    processRecords() {
        const records = this._value?.opportunities || [];
        const raisedIds = this.getRaisedIds();

        this.opportunityData = records.map((opportunity) => {
            const isProcessing = raisedIds.has(opportunity.recordId);
            return {
                ...opportunity,
                isProcessing,
                buttonLabel: isProcessing ? 'Raised' : 'Raise Hand'
            };
        });
        this.currentIndex = 0;
    }

    getStorageKey() {
        const contactId = this._value?.contactId;
        return contactId ? `${STORAGE_KEY_PREFIX}${contactId}` : null;
    }

    getRaisedIds() {
        const storageKey = this.getStorageKey();
        if (!storageKey) {
            return new Set();
        }
        try {
            const stored = window.localStorage.getItem(storageKey);
            return new Set(stored ? JSON.parse(stored) : []);
        } catch (error) {
            console.error('[MiltonVolunteerOpportunitySearchResultsCard] Error reading raised opportunities:', error);
            return new Set();
        }
    }

    markRaised(recordId) {
        const storageKey = this.getStorageKey();
        if (!storageKey) {
            return;
        }
        try {
            const raisedIds = this.getRaisedIds();
            raisedIds.add(recordId);
            window.localStorage.setItem(storageKey, JSON.stringify([...raisedIds]));
        } catch (error) {
            console.error('[MiltonVolunteerOpportunitySearchResultsCard] Error persisting raised opportunity:', error);
        }
    }

    pruneRaisedIds(idsToRemove) {
        const storageKey = this.getStorageKey();
        if (!storageKey || !idsToRemove.length) {
            return;
        }
        try {
            const raisedIds = this.getRaisedIds();
            idsToRemove.forEach((id) => raisedIds.delete(id));
            window.localStorage.setItem(storageKey, JSON.stringify([...raisedIds]));
        } catch (error) {
            console.error('[MiltonVolunteerOpportunitySearchResultsCard] Error pruning raised opportunities:', error);
        }
    }

    // A locally-flagged "raised" id can go stale once the underlying Funding Interest
    // is withdrawn/deleted server-side. Verify each currently-flagged id against
    // Salesforce and clear/re-enable the ones that are no longer actually active.
    async reconcileRaisedIds() {
        const contactId = this._value?.contactId;
        const raisedIds = this.getRaisedIds();
        if (!contactId || raisedIds.size === 0) {
            return;
        }

        const idsToCheck = this.opportunityData
            .filter((opportunity) => raisedIds.has(opportunity.recordId))
            .map((opportunity) => opportunity.recordId);
        if (!idsToCheck.length) {
            return;
        }

        try {
            const activeIds = await getActiveInterestValueIds({ contactId, interestValueIds: idsToCheck });
            const activeIdSet = new Set(activeIds);
            const staleIds = idsToCheck.filter((id) => !activeIdSet.has(id));
            if (!staleIds.length) {
                return;
            }

            this.pruneRaisedIds(staleIds);
            const staleIdSet = new Set(staleIds);
            this.opportunityData = this.opportunityData.map((opportunity) =>
                staleIdSet.has(opportunity.recordId)
                    ? { ...opportunity, isProcessing: false, buttonLabel: 'Raise Hand' }
                    : opportunity
            );
        } catch (error) {
            console.error('[MiltonVolunteerOpportunitySearchResultsCard] Error reconciling raised opportunities:', error);
        }
    }

    handlePrev() {
        this.scrollToIndex(this.currentIndex - 1);
    }

    handleNext() {
        this.scrollToIndex(this.currentIndex + 1);
    }

    scrollToIndex(index) {
        const container = this.template.querySelector('.opportunity-list-container');
        if (!container) {
            return;
        }
        const clampedIndex = Math.max(0, Math.min(index, this.opportunityData.length - 1));
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

    async handleRaiseHand(event) {
        const recordId = event.target.dataset.recordId ?? null;
        const contactId = this._value?.contactId ?? null;

        this.setProcessing(recordId, true);
        
        try {
            await setInterested({ interestValueId: recordId, currentUserContactId: contactId });
            this.markRaised(recordId);
            this.opportunityData = this.opportunityData.map((opportunity) =>
                opportunity.recordId === recordId
                    ? { ...opportunity, isProcessing: true, buttonLabel: 'Raised' }
                    : opportunity
            );
        } catch (error) {
            console.error('[MiltonVolunteerOpportunitySearchResultsCard] Error setting interest:', error);
            this.setProcessing(recordId, false);
        } 
    }

    setProcessing(recordId, isProcessing) {
        this.opportunityData = this.opportunityData.map((opportunity) =>
            opportunity.recordId === recordId
                ? { ...opportunity, isProcessing, buttonLabel: isProcessing ? 'Processing...' : 'Raise Hand' }
                : opportunity
        );
    }
}