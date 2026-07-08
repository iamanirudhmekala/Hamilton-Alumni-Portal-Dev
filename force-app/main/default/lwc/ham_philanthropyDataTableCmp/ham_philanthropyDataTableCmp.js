import { LightningElement, track, api } from 'lwc';
import getReceiptFileUrl from '@salesforce/apex/HAM_MyImpactController.getReceiptFileUrl';
import noRecordsMsg from '@salesforce/label/c.ham_NoRecordsMsg';
import loadMore from '@salesforce/label/c.ham_LoadMore';
import receiptFooter from '@salesforce/label/c.ham_Receipt_Footer_Message';

/**
 * @description A component that displays philanthropy data in a custom, sortable data table.
 * It receives structured data from a parent component and handles sorting and pagination events.
 */
export default class Ham_philanthropyDataTableCmp extends LightningElement {
    @api tableData  = {};
    @api isOverride = false;

    get wrapperClass() {
        return this.isOverride ? 'data-table-wrapper kirkland-override' : 'data-table-wrapper';
    }

    @track isFilterExpanded = true;

    /**
     * @description property to store custom labels for the cards.
     */
    label = {
        noRecordsMsg: noRecordsMsg,
        loadMore: loadMore,
        receiptFooter: receiptFooter
    }

    /**
     * @description Getter to check if it is receipts table.
     * This is useful for conditional rendering.
     * @returns {boolean}.
     */
    get isReceiptsTable() {
        return this.tableData.tableName === 'Receipts';
    }

    /**
     * @description Getter to check if there are any records to display in the table.
     * This is useful for conditional rendering of the table vs. an empty state message.
     * @returns {boolean} True if `displayRecords` is not null and has a length greater than 0.
     */
    get hasRecords() {
        return this.tableData.displayRecords && this.tableData.displayRecords.length > 0;
    }

    /**
     * @description Getter to determine the icon for the sort direction.
     * @returns {string} The character '▲' for ascending or '▼' for descending.
     */
    get sortDirectionIcon() {
        return this.tableData.sortDirection === 'asc' ? '▲' : '▼';
    }

    /**
     * @description Getter to check if the current data represents the Receipts table.
     */
    get isReceiptsTable() {
        return this.tableData && this.tableData.tableName === 'Receipts';
    }

    /**
     * @description Calculates how many records are currently displayed on the screen.
     */
    get showingCount() {
        return this.tableData && this.tableData.displayRecords ? this.tableData.displayRecords.length : 0;
    }

    /**
     * @description Grabs the total record count if provided by Apex, otherwise falls back to showingCount.
     */
    get totalCount() {
        return this.tableData && this.tableData.totalRecordCount ? this.tableData.totalRecordCount : this.showingCount;
    }

    /**
     * @description Returns the appropriate chevron icon based on expansion state.
     */
    get filterIcon() {
        return this.isFilterExpanded ? 'utility:chevrondown' : 'utility:chevronright';
    }

    /**
     * @description Toggles the visibility of the date filter inputs.
     */
    toggleFilter() {
        this.isFilterExpanded = !this.isFilterExpanded;
    }

    /**
     * @description Pluralizes and lowercases the table name for the "Showing..." text (e.g., "receipts")
     */
    get tableNameLower() {
        return this.tableData && this.tableData.tableName ? this.tableData.tableName.toLowerCase() : 'records';
    }

    /**
     * @description A getter that transforms the raw column metadata into a structured format
     * suitable for iterating in the HTML template's table header.
     * @returns {Array<Object>} An array of column objects with labels, API names, and sort state.
     */
    get columns() {
        // Guard against missing essential data
        if (!this.tableData.columnLabels || !this.tableData.columnApiNames || !this.tableData.columnFieldTypes) {
            return [];
        }
        // Map the column labels to a more usable object format
        return this.tableData.columnLabels.map((label, index) => ({
            label: label,
            apiName: this.tableData.columnApiNames[index],
            fieldType: this.tableData.columnFieldTypes[index],
	        isSortedColumn: this.tableData.sortField === this.tableData.columnApiNames[index] 
        }));
    }

    /**
     * @description A getter that prepares table rows and cells from the raw record data.
     * It formats field values and creates a structure optimized for the template's loops.
     * @returns {Array<Object>} An array of row objects, where each object contains an ID and an array of cell objects.
     */
    get displayRecords() {
        if (!this.tableData.displayRecords || this.tableData.displayRecords.length === 0) {
            return [];
        }
        return this.tableData.displayRecords.map((record) => {
            let cells = this.columns.map(col => {
                let value = record[col.apiName];
                let isFileAction = col.fieldType.toLowerCase() === 'file_action';
                return {
                    value: this.formattedFieldValue(value, col.fieldType),
                    key: record.Id,
                    isFileAction: isFileAction,
                    isProcessed: isFileAction ? value : false
                };
            });
            return {
                Id: record.Id,
                cells: cells
            };
        });
    }

    /**
     * @description A helper method to format field values based on their type.
     * It currently handles currency and date formatting.
     * @param {*} fieldvalue The value to format.
     * @param {string} fieldType The type of the field (e.g., 'currency', 'date').
     * @returns {*} The formatted value.
     */
    formattedFieldValue(fieldvalue, fieldType) {
        if (fieldvalue === null || fieldvalue === undefined || fieldvalue === '') {
            return '';
        }
        switch (fieldType.toLowerCase()) {
            case 'currency':
                // Use the en-US locale for consistent currency formatting
                return new Intl.NumberFormat('en-US', {
                    style: 'currency',
                    currency: 'USD',
                    maximumFractionDigits: 2
                }).format(fieldvalue);
            case 'date':
            // 1. Split the "yyyy-mm-dd" string into parts
            const parts = fieldvalue.split('-'); 
            
            // 2. Check if the split was successful and has 3 parts
            if (parts.length === 3) {
                // parts[0] is yyyy, parts[1] is mm, parts[2] is dd
                // Reassemble in "mm/dd/yyyy" format
                return `${parts[1]}/${parts[2]}/${parts[0]}`;
            }
            case 'text':
            case 'file_action':
                return fieldvalue;
            default:
                return fieldvalue;
        }
    }

    /**
     * @description Handles a click on a column header to initiate sorting.
     * It dispatches a 'sortaction' event to the parent component with the field and new sort direction.
     * @param {Event} event The click event object.
     */
    handleSort(event) {
        let field = event.currentTarget.dataset.field;
        let currentDirection = this.tableData.sortField === field ? this.tableData.sortDirection : 'asc';
        let newDirection = currentDirection === 'asc' ? 'desc' : 'asc';

        this.dispatchEvent(new CustomEvent('sortaction', {
            detail: {
                payload: { field: field, direction: newDirection }
            }
        }));
    }

    /**
     * @description Handles the "Load More" button click.
     * It dispatches a 'loadmoreaction' event to the parent component to fetch more data.
     */
    handleLoadMore() {
        this.dispatchEvent(new CustomEvent('loadmoreaction', {
            detail: { section: this.tableData.tableName } // Ensure section is passed if relying on event.detail
        }));
    }

    // --- Date Filters ---
    handleStartDate(event) {
        this.dispatchEvent(new CustomEvent('filteraction', { 
            detail: { type: 'start', value: event.target.value, section: this.tableData.tableName },
            bubbles: true, 
            composed: true 
        }));
    }

    handleEndDate(event) {
        this.dispatchEvent(new CustomEvent('filteraction', { 
            detail: { type: 'end', value: event.target.value, section: this.tableData.tableName },
            bubbles: true, 
            composed: true 
        }));
    }

    // --- File Fetching ---
    handleViewFile(event) {
        const receiptId = event.currentTarget.dataset.id;
        
        getReceiptFileUrl({ recordId: receiptId })
            .then(fileUrl => {
                if (fileUrl) {
                    // Opens the secure Public Link (bypasses all community sharing blocks!)
                    window.open(fileUrl, '_blank');
                } else {
                    // Triggers your Custom Toast in the parent component if the file doesn't exist
                    this.dispatchEvent(new CustomEvent('showcustomtoast', {
                        detail: {
                            title: 'File Not Found',
                            message: 'No attached file matching the keyword was found for this receipt.',
                            variant: 'error'
                        },
                        bubbles: true, 
                        composed: true 
                    }));
                }
            })
            .catch(error => {
                console.error('Error fetching file URL', error);
            });
    }

}