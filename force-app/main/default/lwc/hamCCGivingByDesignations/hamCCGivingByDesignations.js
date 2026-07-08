import { api, LightningElement, wire } from 'lwc';
import { CurrentPageReference } from 'lightning/navigation';
import getGivingByDesignations from '@salesforce/apex/HamCCGivingByDesignationsController.getGivingByDesignations';

// =====================
// Datatable config
// =====================
const columns = [
    { label: 'Purpose', fieldName: 'HAM_Designation__c', type: 'text', sortable: true },
    {
        label: 'Pledged',
        fieldName: 'HAM_Pledged__c',
        type: 'currency',
        typeAttributes: { currencyCode: 'USD' },
        sortable: true
    },
    {
        label: 'Paid',
        fieldName: 'HAM_Paid__c',
        type: 'currency',
        typeAttributes: { currencyCode: 'USD' },
        sortable: true
    },
    {
        label: 'Created Date',
        fieldName: 'CreatedDate',
        type: 'date',
        typeAttributes: { year: 'numeric', month: '2-digit', day: '2-digit' },
        sortable: true
    }
];

export default class HamCCGivingByDesignations extends LightningElement {
    @api recordId;
    @api isAlumni;

    columns = columns;

    /* =====================
     * Data + Pagination
     * ===================== */
    givingByDesignationsData = [];
    paginatedData = [];

    pageSize = 5;
    currentPage = 1;
    totalPages = 0;

    sortedBy = 'CreatedDate';
    sortedDirection = 'desc';

    /* =====================
     * Summary values
     * ===================== */
    totalPledged = 0;
    totalPaid = 0;

    /* =====================
     * Derived state
     * ===================== */
    get hasData() {
        return this.paginatedData.length > 0;
    }

    get isFirstPage() {
        return this.currentPage === 1;
    }

    get isLastPage() {
        return this.currentPage === this.totalPages || this.totalPages === 0;
    }

    /* =====================
     * Accordion state
     * ===================== */
    isExpanded = true;

    get activeSectionIcon() {
        return this.isExpanded ? 'utility:chevrondown' : 'utility:chevronright';
    }

    handleAccordionToggle = () => {
        this.isExpanded = !this.isExpanded;
    };

    /* =====================
     * Page reference params
     * ===================== */
    @wire(CurrentPageReference)
    getStateParameters(currentPageReference) {
        if (currentPageReference?.state?.c__recordId && !this.recordId) {
            this.recordId = currentPageReference.state.c__recordId;
        }
        if (currentPageReference && currentPageReference.state ) {
            let param = currentPageReference.state.c__isAlumni;
            if (param !== undefined) {
                // Convert string → boolean
                this.isAlumni = param === "true" || param === true;
            } else if (this.isAlumni === undefined) {
                this.isAlumni = true; // fallback default
            }
        }
    }

    /* =====================
     * Giving table data
     * ===================== */
    @wire(getGivingByDesignations, { recordId: '$recordId', isAlumni: '$isAlumni' })
    wiredGivingByDesignations({ data, error }) {
        if (data) {
            this.givingByDesignationsData = data.map(row => ({
                ...row,
                id: row.Id
            }));

            this.currentPage = 1;
            this.sortData(this.sortedBy, this.sortedDirection);
            this.calculateTotals();
            this.calculatePagination();
        } else if (error) {
            console.error('Giving by designations error', error);
            this.givingByDesignationsData = [];
            this.paginatedData = [];
            this.totalPages = 0;
            this.totalPledged = 0;
            this.totalPaid = 0;
        }
    }

    /* =====================
     * Sorting + Pagination
     * ===================== */
    handleSort(event) {
        this.sortedBy = event.detail.fieldName;
        this.sortedDirection = event.detail.sortDirection;
        this.sortData(this.sortedBy, this.sortedDirection);
        this.calculatePagination();
    }

    sortData(field, direction) {
        const data = [...this.givingByDesignationsData];
        data.sort((a, b) => {
            let x = a[field] ?? '';
            let y = b[field] ?? '';

            if (typeof x === 'string') x = x.toLowerCase();
            if (typeof y === 'string') y = y.toLowerCase();

            return direction === 'asc' ? (x > y ? 1 : -1) : (x < y ? 1 : -1);
        });
        this.givingByDesignationsData = data;
    }

    calculatePagination() {
        this.totalPages = Math.ceil(this.givingByDesignationsData.length / this.pageSize);
        this.paginateData();
    }

    paginateData() {
        const start = (this.currentPage - 1) * this.pageSize;
        const end = start + this.pageSize;
        this.paginatedData = this.givingByDesignationsData.slice(start, end);
    }

    handlePrevious() {
        if (!this.isFirstPage) {
            this.currentPage--;
            this.paginateData();
        }
    }

    handleNext() {
        if (!this.isLastPage) {
            this.currentPage++;
            this.paginateData();
        }
    }

    handleFirst() {
        this.currentPage = 1;
        this.paginateData();
    }

    handleLast() {
        this.currentPage = this.totalPages;
        this.paginateData();
    }

    calculateTotals() {
        this.totalPledged = this.givingByDesignationsData.reduce((sum, row) => sum + (row.HAM_Pledged__c || 0), 0);
        this.totalPaid = this.givingByDesignationsData.reduce((sum, row) => sum + (row.HAM_Paid__c || 0), 0);
    }

    handleRefresh() {
        // Wired methods auto-refresh when params change
        this.currentPage = 1;
    }
}