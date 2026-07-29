import { LightningElement, api, wire, track } from 'lwc';
import getContactAndPhilanthropyData from '@salesforce/apex/HAM_HomePageController.getContactAndPhilanthropyDataForHome';
import getVolunteerActivitiesForWidget from '@salesforce/apex/HAM_HomePageController.getVolunteerActivitiesForWidget';
import HAM_BADGES from '@salesforce/resourceUrl/HAM_Badges';
import HAM_KIRKLANDBADGES from '@salesforce/resourceUrl/HAM_KirklandBadges';
import NonVolunteerMsg from '@salesforce/label/c.ham_nonVolunteerMsg';
import VolunteerLeadershipTitle from '@salesforce/label/c.ham_volunteerLeadershipTitle';
import VolunteerThankYouMsg from '@salesforce/label/c.ham_volunteerThankYouMsg';
import ViewMyVolunteerRoles from '@salesforce/label/c.ham_viewMyVolunteerRoles';


const SEC_CURRENT_FY = 'Current Fiscal Year Giving';
const SEC_LIFETIME   = 'Lifetime Impact';
const SEC_GIVING_FY   = 'Current FY Paid';

export default class Ham_MyImpactWidget extends LightningElement {
    @api userContactId;
    @api mainResource;
    @api label = {};
    @api images = {};
    @api isOverride = false;

    @track philanthropySections = [];
    @track otherInfo = {};
    @track hcBadges = [];
    @track volunteerCards = [];

    resource = { hcbadges: HAM_BADGES,  hckirklandbadges:HAM_KIRKLANDBADGES };

    @wire(getVolunteerActivitiesForWidget, { contactId: '$userContactId' })
    wiredVolunteer({ data, error }) {
        if (data) {

            this.volunteerCards = data.map(a => ({
                id: a.Id,
                name: a.ucinn_ascendv2__Involvement_Code__r?.Name || a.Name,
            }));
        } else if (error) {
            console.error('Volunteer wire error:', error);
        }
    }

    @wire(getContactAndPhilanthropyData, { currentUserContactId: '$userContactId' })
    wiredData({ error, data }) {
        if (data) {
            if (data.error) {
                console.error('Apex error:', data.error);
                return;
            }
            try {
                console.log('Data--->',data.otherInfo);
                console.log('philanthropyField--->',data.philanthropyField)
                this._buildSections(data.philanthropyField || []);
                console.log('philanthropySections--->',this.philanthropySections);
                this.otherInfo = data.otherInfo || {};
                if (Array.isArray(data.hcBadges)) {
                    if(this.isOverride){
                         this.hcBadges = data.hcBadges
                        .map(b => ({ ...b, imageUrl: this.resource.hckirklandbadges + '/' + b.imageUrl }))
                        .sort((a, b) => (a.order || 0) - (b.order || 0));
                    this.dispatchEvent(new CustomEvent('badgesloaded', { detail: this.hcBadges }));

                    }else{
                    this.hcBadges = data.hcBadges
                        .map(b => ({ ...b, imageUrl: this.resource.hcbadges + '/' + b.imageUrl }))
                        .sort((a, b) => (a.order || 0) - (b.order || 0));
                    this.dispatchEvent(new CustomEvent('badgesloaded', { detail: this.hcBadges }));
                    }
                }
            } catch (e) {
                console.error('Processing error:', e);
            }
        } else if (error) {
            console.error('Wire error:', error);
        }
    }

    _buildSections(fields) {
        const grouped = {};
        fields.forEach(f => {
            const sec = f.sectionLabel;
            if (!grouped[sec]) {
                grouped[sec] = { name: sec, fields: [], sectionOrder: f.sectionOrder };
            }
            grouped[sec].fields.push({
                ...f,
                value:    this._fmt(f.value, f.type),
                rawValue: parseFloat(f.value) || 0,
            });
        });
        this.philanthropySections.splice(
            0,
            this.philanthropySections.length,
            ...Object.values(grouped)
                .sort((a, b) => a.sectionOrder - b.sectionOrder)
                .map(s => { s.fields.sort((a, b) => a.order - b.order); return s; })
        );
    }

    _fmt(value, type) {
        if (value == null || value === '') return '';
        if (type === 'currency') {
            const num = parseFloat(value);
            return new Intl.NumberFormat('en-US', {
                style: 'currency', currency: 'USD', maximumFractionDigits: 2,
            }).format(isNaN(num) ? 0 : num);
        }
        return value;
    }

    _fmtAbbrev(amount) {
        if (!amount && amount !== 0) return '';
        if (amount >= 1000000) {
            return '$' + (amount / 1000000).toLocaleString('en-US', { maximumFractionDigits: 2 }) + 'M';
        }
        if (amount >= 1000) {
            return '$' + (amount / 1000).toLocaleString('en-US', { maximumFractionDigits: 1 }) + 'K';
        }
        return '$' + amount.toLocaleString('en-US', { maximumFractionDigits: 0 });
    }

    get wrapperClass() {
        return this.isOverride ? 'impact-wrapper kirkland' : 'impact-wrapper';
    }

    // ── Section 1: This Year's Hamilton Fund ──────────────────────────────
    get _currentFY() {
        return this.philanthropySections.find(s => s.name === SEC_CURRENT_FY);
    }

    get hasCurrentFY() {
        return !!this._currentFY;
    }

    

    get fundPaidValue() {
        const field = this._currentFY?.fields?.find(f => f.label === 'Hamilton Fund Paid');
        return field?.value || '';
    }

    get isFullyPaid() {
        return this.otherInfo?.isGift === false;
    }

    // ── Section 2: Lifetime Impact ────────────────────────────────────────
    get _lifetime() {
        return this.philanthropySections.find(s => s.name === SEC_LIFETIME);
    }

    get hasLifetime() {
        return !!this._lifetime;
    }

    get committedValue() {
        return this._fmtAbbrev(this._lifetime?.fields?.find(f => f.label === 'Committed')?.rawValue || 0);
    }

    get paidValue() {
        return this._fmtAbbrev(this._lifetime?.fields?.find(f => f.label === 'Paid')?.rawValue || 0);
    }

    get yearsOfGivingLabel() {
        const yrs = this.otherInfo?.totalYearsOfGiving;
        return (yrs != null) ? `${yrs} years of giving` : null;
    }

    get percentFulfilled() {
        const committed = this._lifetime?.fields?.find(f => f.label === 'Committed')?.rawValue || 0;
        const paid      = this._lifetime?.fields?.find(f => f.label === 'Paid')?.rawValue || 0;
        if (!committed) return null;
        return Math.round((paid / committed) * 100) + '% fulfilled';
    }

    // ── Section 3: This Fiscal Year's Current Paid  ──────────────────────────────
    get _currentPaidFY() {
        console.log('CurrentPaidFY--->',this.philanthropySections.find(s => s.name === SEC_GIVING_FY));
        return this.philanthropySections.find(s => s.name === SEC_GIVING_FY);
    }

    get hasCurrentPaidFY() {
        return !!this._currentPaidFY;
    }


    get currentFiscalPaidValue() {
        const field = this._currentPaidFY?.fields?.find(f => f.label === 'Current FY Paid');
        console.log('field--->',field);
        console.log('value--->',(field?.value || ''));
        return field?.value || '';
    }

    get currentFiscalYearLabel() {
        const now = new Date();
        const startYear = now.getMonth() >= 6 ? now.getFullYear() : now.getFullYear() - 1; // FY starts July 1
        const endYearShort = String((startYear + 1) % 100).padStart(2, '0');
        return `FY ${startYear}–${endYearShort}`;
    }


    nonVolunteerMsg = NonVolunteerMsg;
    volunteerLeadershipTitle = VolunteerLeadershipTitle;
    volunteerThankYouMsg = VolunteerThankYouMsg;
    viewMyVolunteerRoles = ViewMyVolunteerRoles;

    get isVolunteer() {
        return this.otherInfo?.isVolunteer === true;
    }

    // ── Navigation ────────────────────────────────────────────────────────
    handleMyImpactNavigation() {
        this.dispatchEvent(new CustomEvent('navigateevent', {
            detail: this.label?.myimpact,
            bubbles: true,
            composed: true,
        }));
    }

    handleViewMyVolunteerRoles() {
        this.dispatchEvent(new CustomEvent('navigatevolserviceevent', {
            detail: {
                currentTab: this.label?.volunteerOpportunity,
                volActiveTab: this.label?.volActTab
            },
            bubbles: true,
            composed: true,
        }));
    }
}