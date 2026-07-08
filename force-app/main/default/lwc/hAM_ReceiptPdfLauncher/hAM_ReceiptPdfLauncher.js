import { LightningElement, track } from 'lwc';
import getReceipts from '@salesforce/apex/HAMReceiptPDFLaunchController.getReceipts';
import launchJob from '@salesforce/apex/HAMReceiptPDFLaunchController.launchJob';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class HAM_ReceiptPdfLauncher extends LightningElement {

    @track receipts = [];
    @track allReceipts = [];
    @track pagedReceipts = [];
    @track selectedRowIds = [];
    @track currentPageSelectedIds = [];
    @track isProcessing = false;
    @track filterValue = '';
    @track showFilters = false;

    refreshTimeout;

    pageSize = 10;
    currentPage = 1;
    totalPages = 1;

    // -------------------------
    // Data Table Columns
    // -------------------------
    columns = [
        {
            label: 'Name',
            fieldName: 'recordUrl',
            type: 'url',
            typeAttributes: {
                label: { fieldName: 'Name' },
                target: '_blank'
            }
        },
        { label: 'Receipt Date', fieldName: 'Receipt_Date__c', type: 'date' },
        { label: 'Amount', fieldName: 'HAM_Sum_of_Cash_Amount__c', type: 'currency' },
        { label: 'Type', fieldName: 'HAM_Receipt_Type__c', type: 'text' },
        {
            label: 'Designations',
            fieldName: 'HAM_Designation_Text__c',
            type: 'text',
            wrapText: true,
            cellAttributes: { class: 'slds-cell-wrap' }
        },
        { label: 'Constituent', fieldName: 'ConstituentName', type: 'text' }
    ];

    // -------------------------
    // Getters
    // -------------------------
    get hasReceipts() {
        return this.receipts && this.receipts.length > 0;
    }

    get isPreviousDisabled() {
        return this.currentPage === 1;
    }

    get isNextDisabled() {
        return this.currentPage === this.totalPages;
    }

    get generateDisabled() {
        return this.isProcessing || this.selectedRowIds.length === 0;
    }

    get filtersButtonLabel() {
        return this.showFilters ? 'Hide Filters' : 'Show Filters';
    }

    get typeFilterOptions() {
        return [
            { label: 'All Types', value: '' },
            { label: 'Hard Credit', value: 'Hard Credit' },
            { label: 'Soft Credit', value: 'Soft Credit' },
            { label: 'IRA', value: 'IRA' }
        ];
    }

    // -------------------------
    // Lifecycle
    // -------------------------
    connectedCallback() {
        this.loadReceipts();
    }

    disconnectedCallback() {
        if (this.refreshTimeout) {
            clearTimeout(this.refreshTimeout);
        }
    }

    // -------------------------
    // Load Data
    // -------------------------
    loadReceipts() {
        return getReceipts()
            .then(result => {
                const shaped = result.map(row => ({
                    ...row,
                    recordUrl: '/' + row.Id,
                    ConstituentName: row.HAM_Constituent__r
                        ? row.HAM_Constituent__r.HAM_Name_w_Suffix__c
                        : ''
                }));

                this.allReceipts = shaped;
                this.receipts = shaped;

                this.totalPages = Math.ceil(this.receipts.length / this.pageSize) || 1;
                this.currentPage = 1;

                this.updatePagedReceipts();
                this.showFilters = false;
            })
            .catch(error => {
                this.showToast(
                    'Error',
                    error?.body?.message || error?.message || 'Error fetching receipts',
                    'error'
                );
            });
    }

    updatePagedReceipts() {
        const start = (this.currentPage - 1) * this.pageSize;
        const end = start + this.pageSize;

        this.pagedReceipts = this.receipts.slice(start, end);

        this.currentPageSelectedIds = this.pagedReceipts
            .filter(r => this.selectedRowIds.includes(r.Id))
            .map(r => r.Id);
    }

    // -------------------------
    // Selection Handling
    // -------------------------
    handleRowSelection(event) {
        const selectedIds = event.detail.selectedRows.map(row => row.Id);
        // Remove current page IDs from global selection
        this.pagedReceipts.forEach(r => {
            const index = this.selectedRowIds.indexOf(r.Id);
            if (index > -1) {
                this.selectedRowIds.splice(index, 1);
            }
        });
        this.selectedRowIds = [...this.selectedRowIds, ...selectedIds];
        this.currentPageSelectedIds = selectedIds;
    }

    // -------------------------
    // Pagination
    // -------------------------
    previousPage() {
        if (this.currentPage > 1) {
            this.currentPage--;
            this.updatePagedReceipts();
        }
    }

    nextPage() {
        if (this.currentPage < this.totalPages) {
            this.currentPage++;
            this.updatePagedReceipts();
        }
    }

    // -------------------------
    // Generate Receipts
    // -------------------------
    handleGenerateClick() {
        if (this.selectedRowIds.length === 0) {
            this.showToast('Error', 'Please select at least one receipt.', 'error');
            return;
        }

        this.isProcessing = true;

        // Directly launch async job without update
        launchJob({ recordIds: this.selectedRowIds })
            .then(() => {
                this.showToast(
                    'Success',
                    'Receipts generation process started. Files will be generated shortly.',
                    'success'
                );

                this.selectedRowIds = [];
                this.currentPageSelectedIds = [];

                // Refresh once after 2 minutes
                this.refreshTimeout = setTimeout(() => {
                    this.loadReceipts();
                }, 120000);
            })
            .catch(error => {
                this.showToast(
                    'Error',
                    error?.body?.message || error?.message || 'Error processing receipts',
                    'error'
                );
            })
            .finally(() => {
                this.isProcessing = false;
            });
    }

    handleCancel() {
        window.history.back();
    }

    // -------------------------
    // Filters
    // -------------------------
    toggleFilters() {
        this.showFilters = !this.showFilters;
    }

    handleTypeFilterChange(event) {
        this.filterValue = event.detail.value;
    }

    handleSearchClick() {
        let filteredReceipts = this.allReceipts;

        if (this.filterValue) {
            filteredReceipts = this.allReceipts.filter(
                r => r.HAM_Receipt_Type__c === this.filterValue
            );
        }

        this.receipts = filteredReceipts;
        this.currentPage = 1;

        this.selectedRowIds = this.selectedRowIds.filter(id =>
            this.receipts.some(r => r.Id === id)
        );

        this.totalPages = Math.ceil(this.receipts.length / this.pageSize) || 1;
        this.updatePagedReceipts();
    }

    handleClear() {
        this.filterValue = '';
        this.receipts = this.allReceipts;
        this.currentPage = 1;
        this.selectedRowIds = [];
        this.currentPageSelectedIds = [];
        this.totalPages = Math.ceil(this.receipts.length / this.pageSize) || 1;
        this.updatePagedReceipts();
    }

    // -------------------------
    // Toast Utility
    // -------------------------
    showToast(title, message, variant) {
        this.dispatchEvent(
            new ShowToastEvent({
                title,
                message,
                variant
            })
        );
    }
}