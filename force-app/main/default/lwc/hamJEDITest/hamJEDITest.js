// 02/26/2026 NVV: ASC-11208-Advance search Contact Report Body text
import { LightningElement, api, track, wire } from 'lwc';
import getContactReportDetail from '@salesforce/apex/HAMJediContactReportController.getContactReportDetail';
import { CurrentPageReference } from 'lightning/navigation';

export default class hamJEDITest extends LightningElement {

    // =========================================
    // Responsive flag
    // =========================================
    @track isMobile = false;

    connectedCallback() {
        this.checkScreen();
        window.addEventListener('resize', this.checkScreen.bind(this));
    }

    checkScreen() {
        this.isMobile = window.innerWidth <= 768;
    }

    // =========================================
    // Accordion / Context
    // =========================================
    @track activeReportSection = 'Contact Reports';
    @api recordId;
    @track loading = false;

    // =========================================
    // Data model
    // =========================================
    @track rawContactReports = [];
    @track allContactReports = [];
    @track pageReports = [];

    // =========================================
    // Sorting
    // =========================================
    @track sortedBy = 'ucinn_ascendv2__Date__c';
    @track sortedDirection = 'desc';

    // =========================================
    // Pagination
    // =========================================
    @track pageSize = 10;
    @track pageNumber = 1;
    @track totalRecords = 0;

    get totalPages() {
        return Math.max(1, Math.ceil(this.totalRecords / this.pageSize));
    }

    get isFirstPage() {
        return this.pageNumber <= 1;
    }

    get isLastPage() {
        return this.pageNumber >= this.totalPages || this.totalRecords === 0;
    }

    derivePage() {
        const start = (this.pageNumber - 1) * this.pageSize;
        const end = start + this.pageSize;
        this.pageReports = this.allContactReports.slice(start, end);
    }

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
    // Modal / Flow
    // =========================================
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

    get publishToListservOptions() {
        return [
            { label: '--None--', value: '' },
            { label: 'Yes', value: 'Yes' },
            { label: 'No', value: 'No' }
        ];
    }

    get advanceFiltersButtonLabel() {
        return this.showAdvanceFilters ? 'Hide Advance Filters' : 'Show Advance Filters';
    }

    // =========================================
    // Datatable columns
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
        { label: 'Contact Method', fieldName: 'ucinn_ascendv2__Contact_Method__c', type: 'text', sortable: true },
        { label: 'Substantive Contact', fieldName: 'ucinn_ascendv2__Substantive_Contact__c', type: 'text', sortable: true },
        { label: 'Description', fieldName: 'ucinn_ascendv2__Description__c', type: 'text', sortable: true },
        { label: 'Contact Report Body', fieldName: 'cleanContactReportBody', type: 'text', sortable: true },
        {
            label: 'Date',
            fieldName: 'ucinn_ascendv2__Date__c',
            type: 'date',
            typeAttributes: { timeZone: 'UTC' },
            sortable: true
        },
        { label: 'PRM at Time of Meeting', fieldName: 'HAM_PRM_at_Time_of_Meeting__c', type: 'text', sortable: true },
        { label: 'Submitted By', fieldName: 'LastModifiedByName', type: 'text', sortable: true }
    ];

    // =========================================
    // URL recordId
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

                const processedRows = (result || []).map(r => ({
                    ...r,
                    recordLink: `/lightning/r/${r.Id}/view`,
                    LastModifiedByName: r.LastModifiedBy?.Name || '',
                    cleanContactReportBody: this.stripHTML(r.ucinn_ascendv2__Contact_Report_Body__c)
                }));

                this.rawContactReports = [...processedRows];
                this.allContactReports = [...processedRows];
                this.totalRecords = this.allContactReports.length;

                this.sortContactReportData(this.sortedBy, this.sortedDirection);

                this.pageNumber = 1;
                this.derivePage();

                this.activeReportSection = this.totalRecords > 0 ? 'Contact Reports' : '';
            })
            .catch(error => {
                console.error('Error fetching Contact Reports:', error);
            })
            .finally(() => {
                this.loading = false;
            });
    }

    // =========================================
    // Sorting
    // =========================================
    handleReportSort(event) {

        const { fieldName: sortedBy, sortDirection } = event.detail;

        this.sortedBy = sortedBy;
        this.sortedDirection = sortDirection;

        this.sortContactReportData(sortedBy, sortDirection);

        this.pageNumber = 1;
        this.derivePage();
    }

    sortContactReportData(field, direction) {

        const key = field === 'recordLink' ? 'Name' : field;
        const dir = direction === 'desc' ? -1 : 1;

        this.allContactReports = [...this.allContactReports].sort((a, b) => {

            const va = (a[key] ?? '').toString().toLowerCase();
            const vb = (b[key] ?? '').toString().toLowerCase();

            if (va === vb) return 0;

            return va > vb ? dir : -dir;
        });
    }

    // =========================================
    // Filters
    // =========================================
    toggleAdvanceFilters() {
        this.showAdvanceFilters = !this.showAdvanceFilters;
    }

    handleSearchTextChange(event) {
        this.filterSearchText = event.target.value;
    }

    handleSearchFilters() {

        let filteredReports = [...this.rawContactReports];

        if (this.filterSearchText) {

            const keyword = this.filterSearchText.toLowerCase();

            filteredReports = filteredReports.filter(report => {

                const body = (report.cleanContactReportBody || '').toLowerCase();
                const description = (report.ucinn_ascendv2__Description__c || '').toLowerCase();

                return body.includes(keyword) || description.includes(keyword);
            });
        }

        this.allContactReports = [...filteredReports];
        this.totalRecords = this.allContactReports.length;

        this.sortContactReportData(this.sortedBy, this.sortedDirection);

        this.pageNumber = 1;
        this.derivePage();
    }

    handleClearFilters() {

        this.filterSearchText = '';

        this.allContactReports = [...this.rawContactReports];
        this.totalRecords = this.allContactReports.length;

        this.sortContactReportData(this.sortedBy, this.sortedDirection);

        this.pageNumber = 1;
        this.derivePage();
    }

    stripHTML(html) {

        if (!html) return '';

        const div = document.createElement('div');

        div.innerHTML = html;

        return div.textContent || div.innerText || '';
    }
}