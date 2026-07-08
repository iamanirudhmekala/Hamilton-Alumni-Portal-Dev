// 03/16/2026 NVV: ASC-12644-Mobile view: Cards implementation
import { LightningElement, api, track, wire } from 'lwc';
import getJediAsks from '@salesforce/apex/HAMJediAsksController.getJediAsks';
import { CurrentPageReference } from 'lightning/navigation';

export default class HamJEDIAsks extends LightningElement {
    // =========================================
    // Accordion / Context
    // =========================================
    @api recordId;
    @track loading = false;
    @track dataLoaded = false;
    @track activeAsksSectionName = '';

    // =========================================
    // Responsive
    // =========================================
    @track isMobile = false;

    // =========================================
    // Mobile stage filter
    // =========================================
    @track _selectedStage = '';
    _allAsksUnfiltered = [];

    // =========================================
    // Data model
    // =========================================
    @track allAsks = [];
    @track pageAsks = [];

    // =========================================
    // Sorting state
    // =========================================
    @track sortedBy = 'ucinn_ascendv2__Submitted_Date__c';
    @track sortedDirection = 'desc';

    // =========================================
    // Pagination
    // =========================================
    @track pageSize = 10;
    @track pageNumber = 1;
    @track totalRecords = 0;

    // =========================================
    // Datatable columns
    // =========================================
    @track askColumns = [
        {
            label: 'Opportunity Name',
            fieldName: 'opportunityLink',
            type: 'url',
            typeAttributes: {
                label: { fieldName: 'Name' },
                target: '_blank'
            },
            sortable: true
        },
        {
            label: 'Stage',
            fieldName: 'StageName',
            type: 'text',
            sortable: true
        },
        {
            label: 'Ask Amount',
            fieldName: 'ucinn_ascendv2__Submitted_Amount__c',
            type: 'currency',
            typeAttributes: {
                currencyCode: 'USD'
            },
            sortable: true
        },
        {
            label: 'Expected Amount',
            fieldName: 'HAM_Expected_Amount__c',
            type: 'currency',
            typeAttributes: {
                currencyCode: 'USD'
            },
            sortable: true
        },
        {
            label: 'Ask Date',
            fieldName: 'ucinn_ascendv2__Submitted_Date__c',
            type: 'date',
            typeAttributes: {
                year: 'numeric',
                month: '2-digit',
                day: '2-digit',
                timeZone: 'UTC'
            },
            sortable: true
        },
        {
            label: 'Close Date',
            fieldName: 'CloseDate',
            type: 'date',
            typeAttributes: {
                year: 'numeric',
                month: '2-digit',
                day: '2-digit',
                timeZone: 'UTC'
            },
            sortable: true
        }
    ];

    // =========================================
    // Derived helpers for UI controls
    // =========================================
    get totalPages() {
        return Math.max(1, Math.ceil(this.totalRecords / this.pageSize));
    }

    get isFirstPage() {
        return this.pageNumber <= 1;
    }

    get isLastPage() {
        return this.pageNumber >= this.totalPages || this.totalRecords === 0;
    }

    get hasAsks() {
        return this.allAsks && this.allAsks.length > 0;
    }

    get showPagination() {
        return this.totalRecords > 10;
    }

    // =========================================
    // Read recordId from URL and load data
    // =========================================
    @wire(CurrentPageReference)
    getStateParameters(currentPageReference) {
        if (currentPageReference?.state?.c__recordId) {
            this.recordId = currentPageReference.state.c__recordId;
            this.loadAsks();
        }
    }

    // Fetch all asks from the Apex controller
    loadAsks() {
        this.loading = true;
        this.dataLoaded = false;

        getJediAsks({ contactId: this.recordId })
            .then(result => {
                const rows = result || [];

                this.allAsks = rows.map(row => ({
                    ...row,
                    opportunityLink: '/' + row.Id
                }));

                this._allAsksUnfiltered = [...this.allAsks];
                this._selectedStage = '';
                this.totalRecords = this.allAsks.length;

                // Apply default sort
                this.sortAskData(this.sortedBy, this.sortedDirection);

                // Reset pagination
                this.pageNumber = 1;
                this.derivePage();

                // Open section only if there are asks, otherwise keep it collapsed
                this.activeAsksSectionName = this.totalRecords > 0 ? 'Asks' : '';
                this.dataLoaded = true;
            })
            .catch(error => {
                console.error('Error fetching JEDI Asks:', error);
                this.allAsks = [];
                this.pageAsks = [];
                this.totalRecords = 0;
                this.pageNumber = 1;
                this.activeAsksSectionName = '';
                this.dataLoaded = true;
            })
            .finally(() => {
                this.loading = false;
            });
    }

    // Compute the current page slice from the full allAsks array based on pageNumber and pageSize
    derivePage() {
        const start = (this.pageNumber - 1) * this.pageSize;
        const end = start + this.pageSize;
        this.pageAsks = this.allAsks.slice(start, end);
    }

    // Navigate to the next page if not already on the last page
    nextPage() {
        if (!this.isLastPage) {
            this.pageNumber += 1;
            this.derivePage();
        }
    }

    // Navigate to the previous page if not already on the first page
    prevPage() {
        if (!this.isFirstPage) {
            this.pageNumber -= 1;
            this.derivePage();
        }
    }

    // Handle accordion section toggle to track which sections are open
    handleAsksSectionToggle(event) {
        const openedSections = event.detail.openSections;

        if (Array.isArray(openedSections)) {
            this.activeAsksSectionName = openedSections.includes('Asks') ? 'Asks' : '';
        } else {
            this.activeAsksSectionName = openedSections === 'Asks' ? 'Asks' : '';
        }
    }

    // Handle datatable column sorting by updating sort state and re-sorting the data
    handleAskSort(event) {
        const { fieldName: sortedBy, sortDirection } = event.detail;
        this.sortedBy = sortedBy;
        this.sortedDirection = sortDirection;

        this.sortAskData(sortedBy, sortDirection);

        this.pageNumber = 1;
        this.derivePage();
    }

    // =========================================
    // Lifecycle – responsive listener
    // =========================================
    connectedCallback() {
        this._resizeHandler = () => this.checkScreen();
        window.addEventListener('resize', this._resizeHandler);
        this.checkScreen();
    }

    disconnectedCallback() {
        window.removeEventListener('resize', this._resizeHandler);
    }

    checkScreen() {
        this.isMobile = window.innerWidth <= 768;
    }

    // =========================================
    // Mobile sort bar
    // =========================================
    get mobileSortOptions() {
        return this.askColumns
            .filter(c => c.sortable && c.type !== 'url')
            .map(c => ({ label: c.label, value: c.fieldName }));
    }

    get sortDirectionIcon() {
        return this.sortedDirection === 'asc' ? 'utility:arrowup' : 'utility:arrowdown';
    }

    get sortDirectionLabel() {
        return this.sortedDirection === 'asc' ? 'Ascending' : 'Descending';
    }

    handleMobileSortChange(event) {
        this.sortedBy = event.detail.value;
        const col = this.askColumns.find(c => c.fieldName === this.sortedBy);
        this.sortedDirection = (col && (col.type === 'currency' || col.type === 'date')) ? 'desc' : 'asc';
        this.sortAskData(this.sortedBy, this.sortedDirection);
        this.pageNumber = 1;
        this.derivePage();
    }

    toggleSortDirection() {
        this.sortedDirection = this.sortedDirection === 'asc' ? 'desc' : 'asc';
        this.sortAskData(this.sortedBy, this.sortedDirection);
        this.pageNumber = 1;
        this.derivePage();
    }

    // =========================================
    // Mobile cards
    // =========================================
    get mobileStageOptions() {
        const stages = [...new Set(this._allAsksUnfiltered.map(r => r.StageName).filter(Boolean))].sort();
        return [{ label: 'All Stages', value: '' }, ...stages.map(s => ({ label: s, value: s }))];
    }

    handleStageFilterChange(event) {
        this._selectedStage = event.detail.value;
        this.applyStageFilter();
    }

    clearStageFilter() {
        this._selectedStage = '';
        this.applyStageFilter();
    }

    applyStageFilter() {
        this.allAsks = this._selectedStage
            ? this._allAsksUnfiltered.filter(r => r.StageName === this._selectedStage)
            : [...this._allAsksUnfiltered];
        this.totalRecords = this.allAsks.length;
        this.sortAskData(this.sortedBy, this.sortedDirection);
        this.pageNumber = 1;
        this.derivePage();
    }

    stageAccentColor(stage) {
        if (!stage) return '#2d73c3';
        switch (stage.toLowerCase()) {
            case 'accepted':  return '#1a7a4a';
            case 'declined':
            case 'cancelled': return '#c23934';
            default:          return '#2d73c3';
        }
    }

    get mobileCards() {
        return this.pageAsks.map(row => {
            const stage = row.StageName || '';
            const accentColor = this.stageAccentColor(stage);
            const bodyFields = [
                { label: 'Stage',           value: stage },
                { label: 'Ask Amount',      value: this.formatCurrency(row.ucinn_ascendv2__Submitted_Amount__c) },
                { label: 'Expected Amount', value: this.formatCurrency(row.HAM_Expected_Amount__c) },
                { label: 'Ask Date',        value: this.formatDate(row.ucinn_ascendv2__Submitted_Date__c) },
                { label: 'Close Date',      value: this.formatDate(row.CloseDate) }
            ];
            return {
                id: row.Id,
                headerValue: row.Name,
                headerLink: row.opportunityLink,
                cardStyle: `border:1px solid #e0e5ee;border-left:4px solid ${accentColor};border-radius:6px;background:#fff;margin-bottom:0.75rem;overflow:hidden;`,
                bodyFields
            };
        });
    }

    formatCurrency(val) {
        if (val == null) return '';
        return Number(val).toLocaleString('en-US', { style: 'currency', currency: 'USD', minimumFractionDigits: 2 });
    }

    formatDate(val) {
        if (!val) return '';
        return new Date(val).toLocaleDateString('en-US', { year: 'numeric', month: '2-digit', day: '2-digit', timeZone: 'UTC' });
    }

    // Sort the allAsks array by the specified field and direction, handling dates, numbers, and currencies correctly
    sortAskData(field, direction) {
        const dir = direction === 'desc' ? -1 : 1;

        this.allAsks = [...this.allAsks].sort((a, b) => {
            let va = a[field] ?? '';
            let vb = b[field] ?? '';

            // Handle date fields
            if (field === 'ucinn_ascendv2__Submitted_Date__c' || field === 'CloseDate') {
                va = va ? new Date(va) : new Date(0);
                vb = vb ? new Date(vb) : new Date(0);
            }
            // Handle currency/number fields
            else if (field === 'ucinn_ascendv2__Submitted_Amount__c' ||
                     field === 'HAM_Expected_Amount__c') {
                va = va || 0;
                vb = vb || 0;
            }
            // Handle text fields
            else {
                va = va.toString().toLowerCase();
                vb = vb.toString().toLowerCase();
            }

            if (va === vb) return 0;
            return va > vb ? dir : -dir;
        });
    }
}