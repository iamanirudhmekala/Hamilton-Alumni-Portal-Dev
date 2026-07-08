import { LightningElement, track } from 'lwc';
import { subscribe, getPreference, setPreference } from 'c/hamViewportService';

const COMPONENT_KEY = 'hamJediMobileHideDemo';

export default class HamJediMobileHideDemo extends LightningElement {
    @track isMobile = false;
    @track width = 0;
    @track preference = 'show';
    @track activeSection = 'Mobile Hide Demo';

    @track sampleRows = [
        { Id: '001', Name: 'Alpha Record',   Type: 'Donation', Date: '2026-01-15', Amount: 1500 },
        { Id: '002', Name: 'Bravo Record',   Type: 'Pledge',   Date: '2026-02-03', Amount: 2750 },
        { Id: '003', Name: 'Charlie Record', Type: 'Donation', Date: '2026-02-22', Amount: 500 },
        { Id: '004', Name: 'Delta Record',   Type: 'Grant',    Date: '2026-03-10', Amount: 10000 },
        { Id: '005', Name: 'Echo Record',    Type: 'Donation', Date: '2026-03-28', Amount: 1200 }
    ];

    columns = [
        { label: 'Id',     fieldName: 'Id',     type: 'text' },
        { label: 'Name',   fieldName: 'Name',   type: 'text' },
        { label: 'Type',   fieldName: 'Type',   type: 'text' },
        { label: 'Date',   fieldName: 'Date',   type: 'date', typeAttributes: { timeZone: 'UTC' } },
        { label: 'Amount', fieldName: 'Amount', type: 'currency' }
    ];

    preferenceOptions = [
        { label: 'Always Show (Table)', value: 'show' },
        { label: 'Card View on Mobile', value: 'card' },
        { label: 'Hide on Mobile',      value: 'hide' }
    ];

    connectedCallback() {
        this.preference = getPreference(COMPONENT_KEY);
        this._unsub = subscribe(v => {
            this.isMobile = v.isMobile;
            this.width = v.width;
            // Re-read in case another tab/window updated the pref
            this.preference = getPreference(COMPONENT_KEY);
        });
    }

    disconnectedCallback() {
        if (this._unsub) this._unsub();
    }

    handlePreferenceChange(event) {
        const value = event.detail.value;
        setPreference(COMPONENT_KEY, value);
        this.preference = value;
    }

    handleSectionToggle(event) {
        const opened = event.detail.openSections;
        if (Array.isArray(opened)) {
            this.activeSection = opened.includes('Mobile Hide Demo') ? 'Mobile Hide Demo' : '';
        } else {
            this.activeSection = opened === 'Mobile Hide Demo' ? 'Mobile Hide Demo' : '';
        }
    }

    get viewportLabel() {
        return this.isMobile ? 'Mobile' : 'Desktop';
    }

    // On desktop always show table. On mobile, show table only if pref='show'.
    get showTable() {
        return !this.isMobile || this.preference === 'show';
    }

    // Cards only when mobile + pref='card'
    get showCards() {
        return this.isMobile && this.preference === 'card';
    }

    // Hide entire data area only when mobile + pref='hide'
    get showHiddenMessage() {
        return this.isMobile && this.preference === 'hide';
    }

    get mobileCards() {
        return this.sampleRows.map(r => ({
            ...r,
            displayAmount: `$${r.Amount.toLocaleString()}`
        }));
    }
}