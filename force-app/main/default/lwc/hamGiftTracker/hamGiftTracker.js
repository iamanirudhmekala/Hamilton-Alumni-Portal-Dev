import { LightningElement, track } from 'lwc';
import getTransactions from '@salesforce/apex/HAM_MGFTReviewTxnCtrl.getTransactions';
import getAppealCodeOptions from '@salesforce/apex/HAM_MGFTReviewTxnCtrl.getAppealCodeOptions';
import getFiscalYearOptions from '@salesforce/apex/HAM_MGFTReviewTxnCtrl.getFiscalYearOptions';
import getTodayTotalAmount from '@salesforce/apex/HAM_MGFTReviewTxnCtrl.getTodayTotalAmount';

const COLUMNS = [
    { label: 'Transaction Date', fieldName: 'transactionDate', type: 'date-local', sortable: true },
    { label: 'Name', fieldName: 'donorName', type: 'text', sortable: true },
    { label: 'Amount', fieldName: 'totalAmount', type: 'currency', sortable: true },
    { label: 'Designation', fieldName: 'designations', type: 'text', wrapText: true },
    { label: 'Is Anonymous', fieldName: 'isAnonymous', type: 'boolean' },
    { label: 'PRM', fieldName: 'prmName', type: 'text', sortable: true },
    { label: 'Email', fieldName: 'email', type: 'email' },
    { label: 'Primary Constituent Type', fieldName: 'primaryConstituentType', type: 'text', sortable: true },
    { label: 'Motivation Code', fieldName: 'appealCode', type: 'text', sortable: true },
    { label: 'Transaction Type', fieldName: 'transactionType', type: 'text', sortable: true }
];

const PAGE_SIZE = 25;

export default class HamGiftTracker extends LightningElement {
    columns = COLUMNS;

    @track allRows = [];      // raw rows as returned by Apex (already ORDER BY date DESC)
    @track displayRows = [];  // allRows sorted for display -- recomputed only on fetch or sort change, not on every render

    isLoading = false;
    errorMessage;

    // Sort state defaults to latest transaction first, matching the
    // ORDER BY ucinn_ascendv2__Transaction_Date__c DESC already in
    // HAM_MGFTReviewTxnCtrl.getTransactions. Because of that, the default
    // sort never needs a client-side re-sort -- see applySort() below.
    sortedBy = 'transactionDate';
    sortedDirection = 'desc';

    // pagination state
    currentPage = 1;
    pageSize = PAGE_SIZE;

    // filter form state
    startDate;
    endDate;
    donorName;
    fiscalYear1;
    fiscalYear2;
    appealCampaignId;

    appealCodeOptions = [];
    fiscalYearOptions = [];

    // -------- analytics state --------
    todayTotal = 0;
    analyticsError;

    connectedCallback() {
        this.loadFilterOptions();
        this.loadAnalytics();
        this.runSearch();
    }

    async loadFilterOptions() {
        try {
            const [appealCodes, fiscalYears] = await Promise.all([
                getAppealCodeOptions(),
                getFiscalYearOptions()
            ]);
            this.appealCodeOptions = [{ label: '-- Any Appeal Code --', value: '' }, ...appealCodes];
            this.fiscalYearOptions = [{ label: '-- None --', value: '' }, ...fiscalYears];
        } catch (err) {
            this.errorMessage = this.reduceError(err);
        }
    }

    // -------- analytics: today's total --------
    // Independent of the list view's filters -- always reflects "today"
    // regardless of what the user has searched for.
    async loadAnalytics() {
        try {
            this.todayTotal = (await getTodayTotalAmount()) || 0;
        } catch (err) {
            this.analyticsError = this.reduceError(err);
        }
    }

    get formattedTodayTotal() {
        return this.formatCurrency(this.todayTotal);
    }

    formatCurrency(value) {
        return new Intl.NumberFormat('en-US', { style: 'currency', currency: 'USD' }).format(value || 0);
    }

    // -------- sorting: computed once per fetch/sort-change, not per render --------

    /**
     * Populates this.displayRows from this.allRows.
     * Apex already returns rows ORDER BY ucinn_ascendv2__Transaction_Date__c DESC,
     * so when the requested sort is still "date descending" we skip the
     * client-side sort entirely and just reuse the server order. We only pay
     * for an Array.sort() when the user picks a different column/direction.
     */
    applySort() {
        const isServerDefaultSort =
            this.sortedBy === 'transactionDate' && this.sortedDirection === 'desc';

        if (isServerDefaultSort) {
            this.displayRows = this.allRows;
            return;
        }

        const dir = this.sortedDirection === 'asc' ? 1 : -1;
        const field = this.sortedBy;
        const rows = [...this.allRows];

        rows.sort((a, b) => {
            let valA = a[field];
            let valB = b[field];

            if (valA === null || valA === undefined) return 1;
            if (valB === null || valB === undefined) return -1;

            if (field === 'transactionDate') {
                valA = new Date(valA).getTime();
                valB = new Date(valB).getTime();
            } else if (typeof valA === 'string') {
                valA = valA.toLowerCase();
                valB = valB.toLowerCase();
            }

            if (valA < valB) return -1 * dir;
            if (valA > valB) return 1 * dir;
            return 0;
        });

        this.displayRows = rows;
    }

    // -------- derived data: paginate only (sorting already done in applySort) --------
    get totalRecords() {
        return this.allRows.length;
    }

    get totalPages() {
        return Math.max(1, Math.ceil(this.totalRecords / this.pageSize));
    }

    get pagedRows() {
        const start = (this.currentPage - 1) * this.pageSize;
        return this.displayRows.slice(start, start + this.pageSize);
    }

    get hasRows() {
        return this.totalRecords > 0;
    }

    get rowCountLabel() {
        if (!this.totalRecords) {
            return '';
        }
        const start = (this.currentPage - 1) * this.pageSize + 1;
        const end = Math.min(this.currentPage * this.pageSize, this.totalRecords);
        return `Showing ${start}-${end} of ${this.totalRecords} transaction${this.totalRecords === 1 ? '' : 's'}`;
    }

    get pageLabel() {
        return `Page ${this.currentPage} of ${this.totalPages}`;
    }

    get disablePrevious() {
        return this.currentPage <= 1;
    }

    get disableNext() {
        return this.currentPage >= this.totalPages;
    }

    // -------- pagination handlers --------
    handlePrevious() {
        if (!this.disablePrevious) {
            this.currentPage -= 1;
        }
    }

    handleNext() {
        if (!this.disableNext) {
            this.currentPage += 1;
        }
    }

    // -------- sort handler (lightning-datatable onsort) --------
    handleSort(event) {
        this.sortedBy = event.detail.fieldName;
        this.sortedDirection = event.detail.sortDirection;
        this.currentPage = 1;
        this.applySort();
    }

    // -------- filter field change handlers --------
    handleStartDateChange(event) {
        this.startDate = event.detail.value || null;
    }
    handleEndDateChange(event) {
        this.endDate = event.detail.value || null;
    }
    handleDonorNameChange(event) {
        this.donorName = event.detail.value;
    }
    handleFiscalYear1Change(event) {
        this.fiscalYear1 = event.detail.value || null;
    }
    handleFiscalYear2Change(event) {
        this.fiscalYear2 = event.detail.value || null;
    }
    handleAppealCodeChange(event) {
        this.appealCampaignId = event.detail.value || null;
    }

    handleSearch() {
        this.currentPage = 1;
        this.runSearch();
    }

    handleClear() {
        this.startDate = null;
        this.endDate = null;
        this.donorName = null;
        this.fiscalYear1 = null;
        this.fiscalYear2 = null;
        this.appealCampaignId = null;
        this.sortedBy = 'transactionDate';
        this.sortedDirection = 'desc';
        this.currentPage = 1;

        this.template.querySelectorAll('lightning-input, lightning-combobox').forEach((el) => {
            el.value = '';
        });

        this.runSearch();
    }

    async runSearch() {
        this.isLoading = true;
        this.errorMessage = undefined;

        const filters = {
            startDate: this.startDate,
            endDate: this.endDate,
            donorName: this.donorName,
            fiscalYear1: this.fiscalYear1,
            fiscalYear2: this.fiscalYear2,
            appealCampaignId: this.appealCampaignId
        };

        try {
            const result = await getTransactions({ filters });
            this.allRows = result;
            this.currentPage = 1;
            this.applySort();
        } catch (err) {
            this.allRows = [];
            this.displayRows = [];
            this.errorMessage = this.reduceError(err);
        } finally {
            this.isLoading = false;
        }
    }

    reduceError(err) {
        if (err && err.body && err.body.message) {
            return err.body.message;
        }
        if (err && err.message) {
            return err.message;
        }
        return 'An unknown error occurred while loading transactions.';
    }
}