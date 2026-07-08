import { LightningElement, api, wire, track } from 'lwc';
import { CurrentPageReference } from 'lightning/navigation';
import getLast5YearsDetail from '@salesforce/apex/HAMJEDIPledgeBalanceController.getLast5YearsDetail';
import getLineItemsByGivingSummary from '@salesforce/apex/HAMJEDIPledgeBalanceController.getLineItemsByGivingSummary';

export default class HamJediLast5YrGiving extends LightningElement {
    @api recordId;
    @track isMobile = false;
    @track splitOpen = false;
    @track selectedRow = null;
    @track lineItems = [];
    @track lineItemsLoading = false;
    @track filterYear = '';
    @track sortedBy = 'HAM_Fiscal_Year__c';
    @track sortedDirection = 'desc';
    @track loading = false;
    @track pageNumber = 1;
    @track pageSize = 5;
    @track mobilePageNumber = 1;
    @track mobilePageSize = 5;
    @track activeBalanceSection = '';

    _allRows = [];
    @track summaryRows = [];

    // =========================================
    // Page reference (App Page pattern)
    // =========================================
    @wire(CurrentPageReference)
    getStateParameters(currentPageReference) {
        if (currentPageReference?.state?.c__recordId) {
            this.recordId = currentPageReference.state.c__recordId;
        }
    }

    // =========================================
    // Wire: summary rows
    // =========================================
    @wire(getLast5YearsDetail, { contactId: '$recordId' })
    wiredSummary({ data, error }) {
        if (data) {
            this._allRows = [...data];
            this.applyFilterAndSort();
            this.activeBalanceSection = data.length > 0 ? 'Last5YrGiving' : '';
        } else if (error) {
            console.error('Error fetching Last 5 Year Giving:', error);
            this._allRows = [];
            this.summaryRows = [];
        }
        this.loading = false;
    }

    // =========================================
    // Mobile lifecycle
    // =========================================
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

    // =========================================
    // Columns
    // =========================================
    get columns() {
        return [
            {
                label: 'Fiscal Year',
                fieldName: 'HAM_Fiscal_Year__c',
                type: 'button',
                sortable: true,
                typeAttributes: {
                    label: { fieldName: 'HAM_Fiscal_Year__c' },
                    variant: 'base',
                    name: 'open_detail'
                },
                cellAttributes: { class: 'fy-link' }
            },
            {
                label: 'Purpose',
                fieldName: 'HAM_Designation__c',
                type: 'text',
                wrapText: false,
                cellAttributes: { class: 'slds-truncate' }
            },
            {
                label: 'Committed',
                fieldName: 'HAM_Pledged__c',
                type: 'currency',
                sortable: true,
                typeAttributes: { minimumFractionDigits: 2, maximumFractionDigits: 2 },
                cellAttributes: { alignment: 'right' }
            },
            {
                label: 'Paid',
                fieldName: 'HAM_Paid__c',
                type: 'currency',
                sortable: true,
                typeAttributes: { minimumFractionDigits: 2, maximumFractionDigits: 2 },
                cellAttributes: { alignment: 'right' }
            },
            {
                label: '',
                fieldName: 'Id',
                type: 'button',
                fixedWidth: 90,
                typeAttributes: {
                    label: 'Details ›',
                    variant: 'base',
                    name: 'open_detail'
                },
                cellAttributes: { alignment: 'right', class: 'details-btn' }
            }
        ];
    }

    // =========================================
    // Filter / sort / pagination
    // =========================================
    get yearOptions() {
        const years = [...new Set(this._allRows.map(r => r.HAM_Fiscal_Year__c).filter(Boolean))];
        years.sort((a, b) => b.localeCompare(a));
        return [
            { label: 'All Years', value: '' },
            ...years.map(y => ({ label: y, value: y }))
        ];
    }

    applyFilterAndSort() {
        let rows = this.filterYear
            ? this._allRows.filter(r => r.HAM_Fiscal_Year__c === this.filterYear)
            : [...this._allRows];

        const dir = this.sortedDirection === 'desc' ? -1 : 1;
        const field = this.sortedBy;
        rows = rows.sort((a, b) => {
            let va = a[field] ?? '';
            let vb = b[field] ?? '';
            if (field === 'HAM_Pledged__c' || field === 'HAM_Paid__c') {
                va = parseFloat(va) || 0;
                vb = parseFloat(vb) || 0;
            } else {
                va = va.toString().toLowerCase();
                vb = vb.toString().toLowerCase();
            }
            if (va === vb) return 0;
            return va > vb ? dir : -dir;
        });

        this.summaryRows = rows;
        this.pageNumber = 1;
        this.mobilePageNumber = 1;
    }

    get filteredRows() {
        const start = (this.pageNumber - 1) * this.pageSize;
        return this.summaryRows.slice(start, start + this.pageSize);
    }

    get totalRecords() { return this.summaryRows.length; }
    get totalPages() { return Math.max(1, Math.ceil(this.totalRecords / this.pageSize)); }
    get isFirstPage() { return this.pageNumber <= 1; }
    get isLastPage() { return this.pageNumber >= this.totalPages; }
    get showPagination() { return this.totalRecords > this.pageSize; }

    handleYearFilterChange(event) {
        this.filterYear = event.target.value;
        this.applyFilterAndSort();
    }

    handleSort(event) {
        this.sortedBy = event.detail.fieldName;
        this.sortedDirection = event.detail.sortDirection;
        this.applyFilterAndSort();
    }

    nextPage() { if (!this.isLastPage) this.pageNumber += 1; }
    prevPage() { if (!this.isFirstPage) this.pageNumber -= 1; }

    get mobileTotalPages() { return Math.max(1, Math.ceil(this.totalRecords / this.mobilePageSize)); }
    get isMobileFirstPage() { return this.mobilePageNumber <= 1; }
    get isMobileLastPage() { return this.mobilePageNumber >= this.mobileTotalPages; }
    get showMobilePagination() { return this.totalRecords > this.mobilePageSize; }
    mobileNextPage() { if (!this.isMobileLastPage) { this.mobilePageNumber += 1; this.selectedRow = null; this.lineItems = []; } }
    mobilePrevPage() { if (!this.isMobileFirstPage) { this.mobilePageNumber -= 1; this.selectedRow = null; this.lineItems = []; } }

    // =========================================
    // Row selection / detail panel
    // =========================================
    get selectedRowIds() {
        return this.selectedRow ? [this.selectedRow.Id] : [];
    }

    handleFyClick(event) {
        if (event.detail.action.name !== 'open_detail') return;
        const row = event.detail.row;
        this.selectedRow = row;
        this.splitOpen = true;
        this.loadLineItems(row.Id);
    }

    loadLineItems(givingSummaryId) {
        this.lineItemsLoading = true;
        this.lineItems = [];
        getLineItemsByGivingSummary({ givingSummaryId })
            .then(data => { this.lineItems = data || []; })
            .catch(error => { console.error('Error fetching line items:', error); })
            .finally(() => { this.lineItemsLoading = false; });
    }

    handleClosePanel() {
        this.splitOpen = false;
        this.selectedRow = null;
        this.lineItems = [];
    }

    // Mobile: tap toggles inline expand; tap same row again to collapse
    handleMobileRowTap(event) {
        const rowId = event.currentTarget.dataset.id;
        if (this.selectedRow && this.selectedRow.Id === rowId) {
            this.selectedRow = null;
            this.lineItems = [];
            return;
        }
        const row = this._allRows.find(r => r.Id === rowId);
        if (!row) return;
        this.selectedRow = row;
        this.loadLineItems(row.Id);
    }

    handleBalanceSectionToggle(event) {
        const opened = event.detail.openSections;
        this.activeBalanceSection = Array.isArray(opened)
            ? (opened.includes('Last5YrGiving') ? 'Last5YrGiving' : '')
            : (opened === 'Last5YrGiving' ? 'Last5YrGiving' : '');
    }

    handleMobileBack() {
        this.selectedRow = null;
        this.lineItems = [];
    }

    // =========================================
    // Computed getters
    // =========================================
    get leftPaneClass() { return this.splitOpen ? 'left-pane split' : 'left-pane full'; }
    get rightPaneClass() { return this.splitOpen ? 'right-pane open' : 'right-pane'; }

    get lineItemCount() { return this.lineItems ? this.lineItems.length : 0; }

    get totalCommitted() {
        return this.lineItems.reduce((s, r) => s + (r.HAM_Committed__c || 0), 0);
    }

    get totalPaid() {
        return this.lineItems.reduce((s, r) => s + (r.HAM_Paid__c || 0), 0);
    }

    get lineItemsWithPct() {
        if (!this.lineItems) return [];
        return this.lineItems.map(item => ({
            ...item,
            _designationName: item.HAM_Designation__r ? item.HAM_Designation__r.Name : ''
        }));
    }

    // Mobile card list
    get mobileRows() {
        const expandedId = this.selectedRow ? this.selectedRow.Id : null;
        const start = (this.mobilePageNumber - 1) * this.mobilePageSize;
        const paged = this.summaryRows.slice(start, start + this.mobilePageSize);
        return paged.map(r => ({
            ...r,
            _committedFormatted: this._formatCurrency(r.HAM_Pledged__c),
            _paidFormatted: this._formatCurrency(r.HAM_Paid__c),
            _purposeTrunc: r.HAM_Designation__c
                ? (r.HAM_Designation__c.length > 80 ? r.HAM_Designation__c.substring(0, 80) + '…' : r.HAM_Designation__c)
                : '',
            _isExpanded: r.Id === expandedId,
            _chevron: r.Id === expandedId ? '▾' : '▸'
        }));
    }

    _formatCurrency(val) {
        if (val == null) return '$0.00';
        return Number(val).toLocaleString('en-US', { style: 'currency', currency: 'USD', minimumFractionDigits: 2 });
    }

    get selectedRowCommitted() { return this._formatCurrency(this.selectedRow?.HAM_Pledged__c); }
    get selectedRowPaid() { return this._formatCurrency(this.selectedRow?.HAM_Paid__c); }
    get totalCommittedFormatted() { return this._formatCurrency(this.totalCommitted); }
    get totalPaidFormatted() { return this._formatCurrency(this.totalPaid); }

}