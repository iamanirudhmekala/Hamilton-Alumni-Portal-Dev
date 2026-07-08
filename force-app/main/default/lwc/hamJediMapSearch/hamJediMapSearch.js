import { LightningElement, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

const PROSPECTS = [
    {
        id: '1', name: 'Aaron Strong', constituentId: '00172531',
        city: 'San Francisco', state: 'CA', lat: '37.7749', lng: '-122.4194',
        email: 'aaron.strong@example.com', phone: '(555) 234-5678',
        giving: 450000, type: 'Alumni', badge: 'Principal', classYear: '2005',
        addressType: 'Home'
    },
    {
        id: '2', name: 'Allison Allen', constituentId: '00164455',
        city: 'New York', state: 'NY', lat: '40.7128', lng: '-74.0060',
        email: 'allison.allen@example.com', phone: '(555) 123-4567',
        giving: 125000, type: 'Employee', badge: 'Major', classYear: '1976',
        addressType: 'Home'
    },
    {
        id: '3', name: 'Ameya Vivale', constituentId: '00057622',
        city: 'Austin', state: 'TX', lat: '30.2672', lng: '-97.7431',
        email: 'ameya.vivale@example.com', phone: '(555) 234-8901',
        giving: 155000, type: 'Friend', badge: 'Major', classYear: '2010',
        addressType: 'Business'
    },
    {
        id: '4', name: 'Brian Chen', constituentId: '00198734',
        city: 'Chicago', state: 'IL', lat: '41.8781', lng: '-87.6298',
        email: 'brian.chen@example.com', phone: '(555) 345-6789',
        giving: 320000, type: 'Alumni', badge: 'Major', classYear: '1998',
        addressType: 'Home'
    },
    {
        id: '5', name: 'Catherine Lewis', constituentId: '00145678',
        city: 'Boston', state: 'MA', lat: '42.3601', lng: '-71.0589',
        email: 'catherine.lewis@example.com', phone: '(555) 456-7890',
        giving: 78000, type: 'Alumni', badge: 'Leadership', classYear: '2015',
        addressType: 'Home'
    },
    {
        id: '6', name: 'David Martinez', constituentId: '00134521',
        city: 'Los Angeles', state: 'CA', lat: '34.0522', lng: '-118.2437',
        email: 'david.martinez@example.com', phone: '(555) 567-8901',
        giving: 210000, type: 'Friend', badge: 'Major', classYear: '2001',
        addressType: 'Business'
    },
    {
        id: '7', name: 'Elena Rodriguez', constituentId: '00187654',
        city: 'Miami', state: 'FL', lat: '25.7617', lng: '-80.1918',
        email: 'elena.rodriguez@example.com', phone: '(555) 678-9012',
        giving: 95000, type: 'Alumni', badge: 'Leadership', classYear: '2012',
        addressType: 'Home'
    },
    {
        id: '8', name: 'Frank Wu', constituentId: '00176543',
        city: 'Seattle', state: 'WA', lat: '47.6062', lng: '-122.3321',
        email: 'frank.wu@example.com', phone: '(555) 789-0123',
        giving: 540000, type: 'Alumni', badge: 'Principal', classYear: '1990',
        addressType: 'Home'
    },
    {
        id: '9', name: 'Grace Kim', constituentId: '00165432',
        city: 'Denver', state: 'CO', lat: '39.7392', lng: '-104.9903',
        email: 'grace.kim@example.com', phone: '(555) 890-1234',
        giving: 67000, type: 'Employee', badge: 'Leadership', classYear: '2018',
        addressType: 'Business'
    },
    {
        id: '10', name: 'Henry Patel', constituentId: '00154321',
        city: 'Atlanta', state: 'GA', lat: '33.7490', lng: '-84.3880',
        email: 'henry.patel@example.com', phone: '(555) 901-2345',
        giving: 185000, type: 'Alumni', badge: 'Major', classYear: '2003',
        addressType: 'Home'
    },
    {
        id: '11', name: 'Irene Novak', constituentId: '00143210',
        city: 'Philadelphia', state: 'PA', lat: '39.9526', lng: '-75.1652',
        email: 'irene.novak@example.com', phone: '(555) 012-3456',
        giving: 42000, type: 'Friend', badge: 'Leadership', classYear: '2020',
        addressType: 'Home'
    },
    {
        id: '12', name: 'James Okonkwo', constituentId: '00132109',
        city: 'Houston', state: 'TX', lat: '29.7604', lng: '-95.3698',
        email: 'james.okonkwo@example.com', phone: '(555) 123-4560',
        giving: 290000, type: 'Alumni', badge: 'Major', classYear: '1995',
        addressType: 'Business'
    }
];

const CLASS_YEAR_OPTIONS = [
    { label: '--None--', value: '' },
    { label: '2020', value: '2020' },
    { label: '2018', value: '2018' },
    { label: '2015', value: '2015' },
    { label: '2012', value: '2012' },
    { label: '2010', value: '2010' },
    { label: '2005', value: '2005' },
    { label: '2003', value: '2003' },
    { label: '2001', value: '2001' },
    { label: '1998', value: '1998' },
    { label: '1995', value: '1995' },
    { label: '1990', value: '1990' },
    { label: '1976', value: '1976' }
];

const CONSTITUENT_TYPE_OPTIONS = [
    { label: '--None--', value: '' },
    { label: 'Alumni', value: 'Alumni' },
    { label: 'Employee', value: 'Employee' },
    { label: 'Friend', value: 'Friend' }
];

const ADDRESS_TYPE_OPTIONS = [
    { label: 'All', value: 'All' },
    { label: 'Home', value: 'Home' },
    { label: 'Business', value: 'Business' }
];

const GIFT_RATING_OPTIONS = [
    { label: '--None--', value: '' },
    { label: 'Principal', value: 'Principal' },
    { label: 'Major', value: 'Major' },
    { label: 'Leadership', value: 'Leadership' }
];

const LIFETIME_OPERATOR_OPTIONS = [
    { label: 'Equal', value: 'Equal' },
    { label: 'Greater Than', value: 'GreaterThan' },
    { label: 'Less Than', value: 'LessThan' }
];

export default class HamJediMapSearch extends LightningElement {
    @track isMobile = false;
    @track citySearch = '';
    @track searchRadius = 25;
    @track hasSearched = false;

    // Filter state
    @track showFilters = false;
    @track filterClassYear = '';
    @track filterConstituentType = '';
    @track filterAddressType = 'All';
    @track filterGiftRating = '';
    @track filterLifetimeOp = 'Equal';
    @track filterLifetimeAmt = '';
    @track filterConsYearsOp = 'Equal';
    @track filterConsYears = '';
    @track filterMyProspectsOnly = false;

    // Results state
    @track viewMode = 'cards'; // 'cards' or 'list'
    @track selectedIds = new Set();
    @track selectAll = false;
    @track filteredProspects = [];
    @track selectedMarker = null;

    // Picklist options
    classYearOptions = CLASS_YEAR_OPTIONS;
    constituentTypeOptions = CONSTITUENT_TYPE_OPTIONS;
    addressTypeOptions = ADDRESS_TYPE_OPTIONS;
    giftRatingOptions = GIFT_RATING_OPTIONS;
    lifetimeOperatorOptions = LIFETIME_OPERATOR_OPTIONS;

    _resizeHandler;

    connectedCallback() {
        this.checkScreen();
        this._resizeHandler = this.checkScreen.bind(this);
        window.addEventListener('resize', this._resizeHandler);
    }

    disconnectedCallback() {
        window.removeEventListener('resize', this._resizeHandler);
    }

    checkScreen() {
        this.isMobile = window.innerWidth <= 768;
    }

    // --- Computed ---

    get isSearchDisabled() {
        return !this.citySearch;
    }

    get radiusLabel() {
        return `${this.searchRadius} miles`;
    }

    get mapMarkers() {
        return this.filteredProspects.map(p => ({
            location: { Latitude: p.lat, Longitude: p.lng },
            title: p.name,
            description: `<strong>${p.city}, ${p.state}</strong><br/>${p.type} &bull; ${p.badge}`,
            value: p.id,
            icon: 'standard:contact'
        }));
    }

    get hasResults() {
        return this.filteredProspects.length > 0;
    }

    get noResults() {
        return this.hasSearched && this.filteredProspects.length === 0;
    }

    get prospectCount() {
        return this.filteredProspects.length;
    }

    get prospectCountLabel() {
        return `My Prospects (${this.prospectCount})`;
    }

    get isCardsView() {
        return this.viewMode === 'cards';
    }

    get isListView() {
        return this.viewMode === 'list';
    }

    get cardsVariant() {
        return this.viewMode === 'cards' ? 'brand' : 'neutral';
    }

    get listVariant() {
        return this.viewMode === 'list' ? 'brand' : 'neutral';
    }

    get selectAllLabel() {
        return `Select All (${this.prospectCount})`;
    }

    get selectedCount() {
        return this.selectedIds.size;
    }

    get exportLabel() {
        return `Export Selected (${this.selectedCount})`;
    }

    get isExportDisabled() {
        return this.selectedCount === 0;
    }

    get displayProspects() {
        return this.filteredProspects.map(p => ({
            ...p,
            locationLabel: `${p.city}, ${p.state}`,
            givingFormatted: this.formatCurrency(p.giving),
            isSelected: this.selectedIds.has(p.id),
            badgeClass: `badge badge-${p.badge.toLowerCase()}`
        }));
    }

    get filterIconName() {
        return this.showFilters ? 'utility:chevronup' : 'utility:chevrondown';
    }

    // --- Handlers: Search ---

    handleCityChange(event) {
        this.citySearch = event.target.value;
    }

    handleRadiusChange(event) {
        this.searchRadius = event.target.value;
    }

    handleSearch() {
        if (!this.citySearch) return;

        const query = this.citySearch.toLowerCase();
        let results = PROSPECTS.filter(p =>
            p.city.toLowerCase().includes(query) ||
            p.state.toLowerCase().includes(query)
        );

        results = this.applyFilters(results);
        this.filteredProspects = results;
        this.hasSearched = true;
        this.selectedIds = new Set();
        this.selectAll = false;
        this.selectedMarker = null;
    }

    handleSearchKeyUp(event) {
        if (event.key === 'Enter') {
            this.handleSearch();
        }
    }

    // --- Handlers: Filters ---

    toggleFilters() {
        this.showFilters = !this.showFilters;
    }

    handleFilterChange(event) {
        const field = event.target.dataset.field;
        const value = event.target.type === 'toggle' ? event.target.checked : event.detail.value;

        switch (field) {
            case 'classYear': this.filterClassYear = value; break;
            case 'constituentType': this.filterConstituentType = value; break;
            case 'addressType': this.filterAddressType = value; break;
            case 'giftRating': this.filterGiftRating = value; break;
            case 'lifetimeOp': this.filterLifetimeOp = value; break;
            case 'lifetimeAmt': this.filterLifetimeAmt = value; break;
            case 'consYearsOp': this.filterConsYearsOp = value; break;
            case 'consYears': this.filterConsYears = value; break;
            case 'myProspectsOnly': this.filterMyProspectsOnly = value; break;
            default: break;
        }

        if (this.hasSearched) {
            this.handleSearch();
        }
    }

    handleClearFilters() {
        this.filterClassYear = '';
        this.filterConstituentType = '';
        this.filterAddressType = 'All';
        this.filterGiftRating = '';
        this.filterLifetimeOp = 'Equal';
        this.filterLifetimeAmt = '';
        this.filterConsYearsOp = 'Equal';
        this.filterConsYears = '';
        this.filterMyProspectsOnly = false;

        if (this.hasSearched) {
            this.handleSearch();
        }
    }

    applyFilters(data) {
        let results = [...data];

        if (this.filterClassYear) {
            results = results.filter(p => p.classYear === this.filterClassYear);
        }
        if (this.filterConstituentType) {
            results = results.filter(p => p.type === this.filterConstituentType);
        }
        if (this.filterAddressType && this.filterAddressType !== 'All') {
            results = results.filter(p => p.addressType === this.filterAddressType);
        }
        if (this.filterGiftRating) {
            results = results.filter(p => p.badge === this.filterGiftRating);
        }
        if (this.filterLifetimeAmt) {
            const amt = parseFloat(this.filterLifetimeAmt);
            if (!isNaN(amt)) {
                if (this.filterLifetimeOp === 'Equal') {
                    results = results.filter(p => p.giving === amt);
                } else if (this.filterLifetimeOp === 'GreaterThan') {
                    results = results.filter(p => p.giving > amt);
                } else if (this.filterLifetimeOp === 'LessThan') {
                    results = results.filter(p => p.giving < amt);
                }
            }
        }

        return results;
    }

    // --- Handlers: View Toggle & Selection ---

    handleCardsView() {
        this.viewMode = 'cards';
    }

    handleListView() {
        this.viewMode = 'list';
    }

    handleSelectAll(event) {
        this.selectAll = event.target.checked;
        if (this.selectAll) {
            this.selectedIds = new Set(this.filteredProspects.map(p => p.id));
        } else {
            this.selectedIds = new Set();
        }
    }

    handleCardSelect(event) {
        const id = event.currentTarget.dataset.id;
        const updated = new Set(this.selectedIds);
        if (updated.has(id)) {
            updated.delete(id);
        } else {
            updated.add(id);
        }
        this.selectedIds = updated;
        this.selectAll = updated.size === this.filteredProspects.length;
    }

    handleExport() {
        this.dispatchEvent(new ShowToastEvent({
            title: 'Export',
            message: `Exporting ${this.selectedCount} prospect(s)...`,
            variant: 'info'
        }));
    }

    handleViewAuditTrail() {
        this.dispatchEvent(new ShowToastEvent({
            title: 'Audit Trail',
            message: 'Opening audit trail...',
            variant: 'info'
        }));
    }

    // --- Handlers: Map ---

    handleMarkerSelect(event) {
        const selectedValue = event.detail.selectedMarkerValue;
        this.selectedMarker = this.filteredProspects.find(p => p.id === selectedValue) || null;
    }

    // --- Helpers ---

    formatCurrency(value) {
        return new Intl.NumberFormat('en-US', {
            style: 'currency',
            currency: 'USD',
            minimumFractionDigits: 0,
            maximumFractionDigits: 0
        }).format(value);
    }
}