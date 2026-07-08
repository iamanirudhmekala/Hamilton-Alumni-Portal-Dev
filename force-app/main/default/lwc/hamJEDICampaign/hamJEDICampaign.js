import { LightningElement, api, track, wire } from 'lwc';
import getCampaignDetails from '@salesforce/apex/HAMJediCampaignController.getCampaignDetails';
import { CurrentPageReference } from 'lightning/navigation';

export default class HamJEDICampaign extends LightningElement {
    // =========================================
    // Accordion / Context
    // =========================================
    @track activeCampaignSection = ''; // Empty string means closed by default
    @api recordId;
    @track loading = false; // spinner flag

    // =========================================
    // Data model
    // =========================================
    @track allCampaigns = [];       // full, sorted dataset; pagination slices from here
    @track campaignDetails = [];    // current page rows bound to the datatable

    // =========================================
    // Sorting state
    // =========================================
    @track sortedBy = 'StartDate';
    @track sortedDirection = 'desc';

    // =========================================
    // Pagination (grouped here intentionally)
    // =========================================
    @track pageSize = 10;     // rows per page
    @track pageNumber = 1;    // 1-based index
    @track totalRecords = 0;  // derived from allCampaigns.length

    // Derived helpers for UI controls
    get totalPages() {
        return Math.max(1, Math.ceil(this.totalRecords / this.pageSize));
    }
    get isFirstPage() {
        return this.pageNumber <= 1;
    }
    get isLastPage() {
        return this.pageNumber >= this.totalPages || this.totalRecords === 0;
    }
    get showPagination() {
        return this.totalRecords > 10;
    }

    // Compute current page slice from allCampaigns → campaignDetails
    derivePage() {
        const start = (this.pageNumber - 1) * this.pageSize;
        const end = start + this.pageSize;
        this.campaignDetails = this.allCampaigns.slice(start, end);
    }

    // Handlers for footer buttons
    nextPage() {
        if (!this.isLastPage) {
            this.pageNumber += 1;
            this.derivePage();
        }
    }
    prevPage() {
        if (!this.isFirstPage) {
            this.pageNumber -= 1;
            this.derivePage();
        }
    }
    // =========================================

    // =========================================
    // Datatable columns (sorting supported)
    // =========================================
    @track campaignColumns = [
        {
            label: 'Campaign Name',
            fieldName: 'recordLink',
            type: 'url',
            typeAttributes: {
                label: { fieldName: 'Name' },
                target: '_blank'
            },
            sortable: true
        },
        {
            label: 'Fiscal Year',
            fieldName: 'HAM_Fiscal_Year__c',
            type: 'text',
            sortable: true
        },
        {
            label: 'Start Date',
            fieldName: 'StartDate',
            type: 'date',
            typeAttributes: {
                year: 'numeric',
                month: 'short',
                day: '2-digit',
                timeZone: 'UTC'
            },
            sortable: true
        },
        {
            label: 'End Date',
            fieldName: 'EndDate',
            type: 'date',
            typeAttributes: {
                year: 'numeric',
                month: 'short',
                day: '2-digit',
                timeZone: 'UTC'
            },
            sortable: true
        },
        {
            label: 'Parent Campaign',
            fieldName: 'parentLink',
            type: 'url',
            typeAttributes: {
                label: { fieldName: 'ParentName' },
                target: '_blank'
            },
            sortable: true
        },
        {
            label: 'Active',
            fieldName: 'IsActive',
            type: 'boolean',
            sortable: true
        }
    ];

    // =========================================
    // Read recordId from URL and load data
    // =========================================
    @wire(CurrentPageReference)
    getStateParameters(currentPageReference) {
        if (currentPageReference?.state?.c__recordId) {
            this.recordId = currentPageReference.state.c__recordId;
            this.loading = true;

            getCampaignDetails({ contactId: this.recordId })
                .then(result => {
                    const rows = result || [];

                    // Add recordLink and parentLink for URL columns
                    this.allCampaigns = rows.map(r => ({
                        ...r,
                        recordLink: `/lightning/r/Campaign/${r.Id}/view`,
                        parentLink: r.ParentId ? `/lightning/r/Campaign/${r.ParentId}/view` : null,
                        ParentName: r.Parent ? r.Parent.Name : ''
                    }));

                    this.totalRecords = this.allCampaigns.length;

                    // Apply default sort once (sortedBy/sortedDirection)
                    this.sortCampaignData(this.sortedBy, this.sortedDirection);

                    // [pagination] reset to first page and compute slice
                    this.pageNumber = 1;
                    this.derivePage();
                })
                .catch(error => {
                    console.error('Error fetching Campaigns:', error);
                    this.allCampaigns = [];
                    this.campaignDetails = [];
                    this.totalRecords = 0;

                    // [pagination] reset page state on error
                    this.pageNumber = 1;
                })
                .finally(() => {
                    this.loading = false; // stop spinner either way
                });
        }
    }

    // =========================================
    // Accordion toggle handler
    // =========================================
    handleCampaignSectionToggle(event) {
        const openedSections = event.detail.openSections;
        if (Array.isArray(openedSections)) {
            this.activeCampaignSection = openedSections.includes('Campaigns') ? 'Campaigns' : '';
        } else {
            this.activeCampaignSection = openedSections === 'Campaigns' ? 'Campaigns' : '';
        }
    }

    // =========================================
    // Datatable sort handler
    // =========================================
    handleCampaignSort(event) {
        const { fieldName: sortedBy, sortDirection } = event.detail;
        this.sortedBy = sortedBy;
        this.sortedDirection = sortDirection;

        this.sortCampaignData(sortedBy, sortDirection);

        // [pagination] after sorting full dataset, show first page of new order
        this.pageNumber = 1;
        this.derivePage();
    }

    // Core sort routine. We always sort allCampaigns so pagination stays consistent.
    sortCampaignData(field, direction) {
        // Map display field to actual data field
        const key = field === 'recordLink' ? 'Name' : (field === 'parentLink' ? 'ParentName' : field);
        const dir = direction === 'desc' ? -1 : 1;

        this.allCampaigns = [...this.allCampaigns].sort((a, b) => {
            let va = a[key];
            let vb = b[key];

            // Push nulls to end regardless of sort direction (matching NULLS LAST behavior)
            if (va == null && vb == null) return 0;
            if (va == null) return 1;
            if (vb == null) return -1;

            // Convert to lowercase strings for comparison
            va = va.toString().toLowerCase();
            vb = vb.toString().toLowerCase();

            if (va === vb) return 0;
            return va > vb ? dir : -dir;
        });
    }
}