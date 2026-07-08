// 02/26/2026 NVV: ASC-11208-Advance search Contact Report Body text
// 03/11/2026 NVV: ASC-12509 Mobile view: card
// 05/06/2026 NVV: ASC-13502 Mobile pagination: 3 cards per page (desktop unchanged at 10)
import { LightningElement, api, track, wire } from 'lwc';
import getContactReportDetail from '@salesforce/apex/HAMJediContactReportController.getContactReportDetail';
import { CurrentPageReference } from 'lightning/navigation';

export default class HamJediContactReports extends LightningElement {
    // =========================================
    // Responsive flag
    // =========================================
    @track isMobile = false;

    connectedCallback() {
        this.checkScreen();
        this._resizeHandler = this.checkScreen.bind(this);
        window.addEventListener('resize', this._resizeHandler);
    }

    disconnectedCallback() {
        window.removeEventListener('resize', this._resizeHandler);
    }

    checkScreen() {
        const wasMobile = this.isMobile;
        this.isMobile = window.innerWidth <= 768;
        if (this.isMobile !== wasMobile) {
            this.pageNumber = 1;
            this.derivePage();
        }
    }

    // =========================================
    // Accordion / Context
    // =========================================
    @track activeReportSection = 'Contact Reports';
    @api recordId;
    @track loading = false; // spinner flag

    // =========================================
    // Data model
    // =========================================
    @track rawContactReports = [];  // original unfiltered dataset from server
    @track allContactReports = [];  // full, sorted dataset; pagination slices from here
    @track pageReports = [];        // current page rows bound to the datatable

    // =========================================
    // Sorting state
    // =========================================
    @track sortedBy = 'ucinn_ascendv2__Date__c';
    @track sortedDirection = 'desc';

    // =========================================
    // Pagination (grouped here intentionally)
    // =========================================
    @track pageSize = 10;         // rows per page (desktop)
    @track mobilePageSize = 3;    // rows per page (mobile)
    @track pageNumber = 1;        // 1-based index
    @track totalRecords = 0;      // derived from allContactReports.length

    get currentPageSize() {
        return this.isMobile ? this.mobilePageSize : this.pageSize;
    }

    // Derived helpers for UI controls
    get totalPages() {
        return Math.max(1, Math.ceil(this.totalRecords / this.currentPageSize));
    }
    get isFirstPage() {
        return this.pageNumber <= 1;
    }
    get isLastPage() {
        return this.pageNumber >= this.totalPages || this.totalRecords === 0;
    }

    // Compute current page slice from allContactReports → pageReports
    derivePage() {
        const start = (this.pageNumber - 1) * this.currentPageSize;
        const end = start + this.currentPageSize;
        this.pageReports = this.allContactReports.slice(start, end);
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

    // Modal and Flow
    @track isFlowModalOpen = false;
    @track flowInputVariables = [];
    createReportButtonRef = null;

    // =========================================
    // Advance Filters
    // =========================================
    @track showAdvanceFilters = false;
    @track filterStartDate = '';
    @track filterEndDate = '';
    @track filterPublishToListserv = '';
    @track filterSearchText = '';

    // Picklist options for Publish to Listserv
    get publishToListservOptions() {
        return [
            { label: '--None--', value: '' },
            { label: 'Yes', value: 'Yes' },
            { label: 'No', value: 'No' }
        ];
    }

    // Dynamic button label for Advance Filters
    get advanceFiltersButtonLabel() {
        return this.showAdvanceFilters ? 'Hide Advance Filters' : 'Show Advance Filters';
    }

    // =========================================
    // Datatable columns (sorting supported)
    // =========================================
    @track contactReportColumns = [
        {
            label: 'Name',
            fieldName: 'recordLink',
            type: 'url',
            typeAttributes: {
                label: { fieldName: 'Name' },
                target: '_blank'
            },
            sortable: true
        },
        {
            label: 'Contact Method',
            fieldName: 'ucinn_ascendv2__Contact_Method__c',
            type: 'text',
            sortable: true
        },
        {
            label: 'Substantive Contact',
            fieldName: 'ucinn_ascendv2__Substantive_Contact__c',
            type: 'text',
            sortable: true
        },
        {
            label: 'Description',
            fieldName: 'ucinn_ascendv2__Description__c',
            type: 'text',
            sortable: true
        },
        {
            label: 'Contact Report Body',
            fieldName: 'cleanContactReportBody',
            type: 'text',
            sortable: true
        },
        {
            label: 'Date',
            fieldName: 'ucinn_ascendv2__Date__c',
            type: 'date',
            typeAttributes: {
                timeZone: 'UTC'
            },
            sortable: true
        },
        {
            label: 'PRM at Time of Meeting',
            fieldName: 'HAM_PRM_at_Time_of_Meeting__c',
            type: 'text',
            sortable: true
        },
        {
            label: 'Submitted By',
            fieldName: 'LastModifiedByName',
            type: 'text',
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
            this.fetchContactReports();
        }
    }

    fetchContactReports() {
        this.loading = true;

        getContactReportDetail({ contactId: this.recordId })
            .then(result => {
                const rows = result || [];

                // Add recordLink for the Name URL column and flatten LastModifiedBy.Name
                const processedRows = rows.map(r => ({
                    ...r,
                    recordLink: `/lightning/r/${r.Id}/view`,
                    LastModifiedByName: r.LastModifiedBy?.Name || '',
                    cleanContactReportBody: this.stripHTML(r.ucinn_ascendv2__Contact_Report_Body__c)
                }));

                // Store original unfiltered data
                this.rawContactReports = [...processedRows];
                this.allContactReports = [...processedRows];

                this.totalRecords = this.allContactReports.length;

                // Apply default sort once (sortedBy/sortedDirection)
                this.sortContactReportData(this.sortedBy, this.sortedDirection);

                // [pagination] reset to first page and compute slice
                this.pageNumber = 1;
                this.derivePage();

                // Open accordion if records exist, close if no records
                this.activeReportSection = this.totalRecords > 0 ? 'Contact Reports' : '';
            })
            .catch(error => {
                console.error('Error fetching Contact Reports:', error);
                this.rawContactReports = [];
                this.allContactReports = [];
                this.pageReports = [];
                this.totalRecords = 0;

                // [pagination] reset page state on error
                this.pageNumber = 1;
            })
            .finally(() => {
                this.loading = false; // stop spinner either way
            });
    }

    // =========================================
    // Accordion toggle handler
    // =========================================
    handleReportSectionToggle(event) {
        const openedSections = event.detail.openSections;
        if (Array.isArray(openedSections)) {
            this.activeReportSection = openedSections.includes('Contact Reports') ? 'Contact Reports' : '';
        } else {
            this.activeReportSection = openedSections === 'Contact Reports' ? 'Contact Reports' : '';
        }
    }

    // =========================================
    // Datatable sort handler
    // =========================================
    handleReportSort(event) {
        const { fieldName: sortedBy, sortDirection } = event.detail;
        this.sortedBy = sortedBy;
        this.sortedDirection = sortDirection;

        this.sortContactReportData(sortedBy, sortDirection);

        // [pagination] after sorting full dataset, show first page of new order
        this.pageNumber = 1;
        this.derivePage();
    }

    // Core sort routine. We always sort allContactReports so pagination stays consistent.
    sortContactReportData(field, direction) {
        const key = field === 'recordLink' ? 'Name' : field; // sort by Name when link column is clicked
        const dir = direction === 'desc' ? -1 : 1;

        this.allContactReports = [...this.allContactReports].sort((a, b) => {
            const va = (a[key] ?? '').toString().toLowerCase();
            const vb = (b[key] ?? '').toString().toLowerCase();
            if (va === vb) return 0;
            return va > vb ? dir : -dir;
        });
    }

    // =========================================
    // Modal Flow Methods
    // =========================================
    openFlowModal(event) {
        // Save reference to the button for scrolling back after modal closes
        this.createReportButtonRef = event.target;

        this.flowInputVariables = [
            {
                name: 'contactId',
                type: 'String',
                value: this.recordId
            }
        ];
        console.log('Flow Variable-------', this.flowInputVariables);
        this.isFlowModalOpen = true;
    }

    closeFlowModal() {
        this.isFlowModalOpen = false;

        // Scroll back to the button that opened the modal
        if (this.createReportButtonRef) {
            // eslint-disable-next-line @lwc/lwc/no-async-operation
            setTimeout(() => {
                this.createReportButtonRef.scrollIntoView({ behavior: 'smooth', block: 'center' });
            }, 100);
        }
    }

    handleFlowStatusChange(event) {
        const status = event.detail.status;

        // Scroll modal into view when flow starts
        if (status === 'STARTED' || status === 'PAUSED') {
            const modal = this.template.querySelector('[data-id="contactReportModal"]');
            if (modal) {
                modal.scrollIntoView({ behavior: 'smooth', block: 'start' });
            }
        }

        if (status === 'FINISHED' || status === 'FINISHED_SCREEN') {
            this.closeFlowModal();
            this.fetchContactReports(); // refresh after flow
        }
    }

    // =========================================
    // Advance Filter Methods
    // =========================================
    toggleAdvanceFilters() {
        this.showAdvanceFilters = !this.showAdvanceFilters;
        if (this.showAdvanceFilters) {
            this.activeReportSection = 'Contact Reports';
        }
    }

    handleStartDateChange(event) {
        this.filterStartDate = event.target.value;
    }

    handleEndDateChange(event) {
        this.filterEndDate = event.target.value;
    }

    handlePublishToListservChange(event) {
        this.filterPublishToListserv = event.detail.value;
    }

    handleSearchTextChange(event) {
        this.filterSearchText = event.target.value;
    }

    handleSearchKeyDown(event) {
        if (event.key === 'Enter') {
            this.handleSearchFilters();
        }
    }

    handleSearchFilters() {
        // Start with original unfiltered data
        let filteredReports = [...this.rawContactReports];

        // Apply Date Filters
        if (this.filterStartDate || this.filterEndDate) {
            filteredReports = filteredReports.filter(report => {
                const reportDate = report.ucinn_ascendv2__Date__c;
                if (!reportDate) return false;

                // Scenario 1: Only Start Date → from start date onwards (no upper limit)
                if (this.filterStartDate && !this.filterEndDate) {
                    return reportDate >= this.filterStartDate;
                }

                // Scenario 2: Only End Date → from beginning to end date (inclusive)
                if (!this.filterStartDate && this.filterEndDate) {
                    return reportDate <= this.filterEndDate;
                }

                // Scenario 3: Both Start and End Date → specific range (both inclusive)
                if (this.filterStartDate && this.filterEndDate) {
                    return reportDate >= this.filterStartDate && reportDate <= this.filterEndDate;
                }

                return true;
            });
        }

        // Apply Search Text Filter (Contact Report Body + Description)
        if (this.filterSearchText) {
            const keyword = this.filterSearchText.toLowerCase();
            filteredReports = filteredReports.filter(report => {
                const body = (report.cleanContactReportBody || '').toLowerCase();
                const description = (report.ucinn_ascendv2__Description__c || '').toLowerCase();
                return body.includes(keyword) || description.includes(keyword);
            });
        }

        // Apply Publish to Listserv Filter
        if (this.filterPublishToListserv) {
            filteredReports = filteredReports.filter(report => {
                return report.HAM_Publish_to_Listserv__c === this.filterPublishToListserv;
            });
        }

        // Update allContactReports with filtered data
        this.allContactReports = [...filteredReports];
        this.totalRecords = this.allContactReports.length;

        // Re-apply current sort
        this.sortContactReportData(this.sortedBy, this.sortedDirection);

        // Reset to page 1 and update display
        this.pageNumber = 1;
        this.derivePage();
    }

    handleClearFilters() {
        // Clear filter values
        this.filterStartDate = '';
        this.filterEndDate = '';
        this.filterPublishToListserv = '';
        this.filterSearchText = '';

        // Reset to original unfiltered data
        this.allContactReports = [...this.rawContactReports];
        this.totalRecords = this.allContactReports.length;

        // Re-apply current sort
        this.sortContactReportData(this.sortedBy, this.sortedDirection);

        // Reset to page 1 and update display
        this.pageNumber = 1;
        this.derivePage();

        // Open accordion if records exist after clearing filters
        if (this.totalRecords > 0) {
            this.activeReportSection = 'Contact Reports';
        }
    }

    // =========================================
    // Helper Methods
    // =========================================
    stripHTML(html) {
        if (!html) return '';
        const div = document.createElement('div');
        div.innerHTML = html;
        return div.textContent || div.innerText || '';
    }

    // =========================================
    // Mobile Sort
    // =========================================
    get mobileSortOptions() {
        return [
            { label: 'Date', value: 'ucinn_ascendv2__Date__c' },
            { label: 'Name', value: 'Name' },
            { label: 'Contact Method', value: 'ucinn_ascendv2__Contact_Method__c' },
            { label: 'Submitted By', value: 'LastModifiedByName' }
        ];
    }

    get mobileSortDirectionIcon() {
        return this.sortedDirection === 'asc' ? 'utility:arrowup' : 'utility:arrowdown';
    }

    get mobileSortDirectionLabel() {
        return this.sortedDirection === 'asc' ? 'Ascending' : 'Descending';
    }

    handleMobileSortChange(event) {
        this.sortedBy = event.detail.value;
        this.sortContactReportData(this.sortedBy, this.sortedDirection);
        this.pageNumber = 1;
        this.derivePage();
    }

    toggleMobileSortDirection() {
        this.sortedDirection = this.sortedDirection === 'asc' ? 'desc' : 'asc';
        this.sortContactReportData(this.sortedBy, this.sortedDirection);
        this.pageNumber = 1;
        this.derivePage();
    }

    // =========================================
    // Show More / Less for mobile cards
    // =========================================
    _expandedIds = new Set();

    toggleShowMore(event) {
        const reportId = event.currentTarget.dataset.id;
        if (this._expandedIds.has(reportId)) {
            this._expandedIds.delete(reportId);
        } else {
            this._expandedIds.add(reportId);
        }
        this.derivePage();
    }

    get mobilePageReports() {
        const maxLen = 100;
        return this.pageReports.map(r => {
            const body = r.cleanContactReportBody || '';
            const isExpanded = this._expandedIds.has(r.Id);
            const needsTruncation = body.length > maxLen;
            const rawDate = r.ucinn_ascendv2__Date__c;
            let formattedDate = rawDate || '';
            if (rawDate) {
                const d = new Date(rawDate + 'T00:00:00');
                formattedDate = d.toLocaleDateString('en-US', { year: 'numeric', month: 'short', day: 'numeric' });
            }
            return {
                ...r,
                displayBody: isExpanded || !needsTruncation ? body : body.substring(0, maxLen) + '...',
                showMoreLabel: isExpanded ? 'Show Less' : 'Show More',
                needsTruncation,
                formattedDate
            };
        });
    }
}