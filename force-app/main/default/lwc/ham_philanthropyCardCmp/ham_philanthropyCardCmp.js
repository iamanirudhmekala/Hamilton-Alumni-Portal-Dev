import { LightningElement, api, track } from 'lwc';
import getReceiptFileUrl from '@salesforce/apex/HAM_MyImpactController.getReceiptFileUrl';
import noRecordsMsg from '@salesforce/label/c.ham_NoRecordsMsg';
import loadMoreMobile from '@salesforce/label/c.ham_LoadMoreMobile';
import receiptFooter from '@salesforce/label/c.ham_Receipt_Footer_Message';

/**
 * @description A component to display philanthropy data in a card-based layout.
 * It dynamically processes and formats data received from a parent component.
 */
export default class Ham_philanthropyCardCmp extends LightningElement {
    /**
     * @description Public API property to receive data for the cards.
     * The data is expected to be an object with properties like `columnLabels`,
     * `columnApiNames`, `columnFieldTypes`, and `displayRecords`.
     * @type {object}
     */
    @api tableData; 
    @api isOverride = false;

    @track isFilterExpanded = true;

    /**
     * @description property to store custom labels for the cards.
     */
    label = {
        noRecordsMsg: noRecordsMsg,
        loadMoreMobile: loadMoreMobile,
        receiptFooter: receiptFooter
    }

    /**
     * @description Getter to check if the current data represents the Receipts table.
     */
    get isReceiptsTable() {
        return this.tableData && this.tableData.tableName === 'Receipts';
    }

    /**
     * @description Getter to check if this table has fixed action buttons configured via metadata.
     */
    get hasActionButtons() {
        return !!(this.tableData && (this.tableData.button1Url || this.tableData.button2Url));
    }

    /**
     * @description Getter to check if this table has footnote text configured via metadata.
     */
    get hasFootnote() {
        return !!(this.tableData && this.tableData.footnote);
    }

    get wrapperClass() {
        return this.isOverride ? 'card-list-container kirkland-override' : 'card-list-container';
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
        // If your Apex returns a totalRecordCount, it uses it here. Otherwise, defaults to showingCount.
        return this.tableData && this.tableData.totalRecordCount ? this.tableData.totalRecordCount : this.showingCount;
    }

    /**
     * @description Toggles the visibility of the date filter inputs.
     */
    toggleFilter() {
        this.isFilterExpanded = !this.isFilterExpanded;
    }

    /**
     * @description Returns the appropriate chevron icon based on expansion state.
     */
    get filterIcon() {
        return this.isFilterExpanded ? 'utility:chevrondown' : 'utility:chevronright';
    }

    /**
     * @description Pluralizes and lowercases the table name for the "Showing..." text (e.g., "receipts")
     */
    get tableNameLower() {
        return this.tableData && this.tableData.tableName ? this.tableData.tableName.toLowerCase() : 'records';
    }

    /**
     * @description A getter that transforms the `tableData` into a structured format suitable for
     * card display in the component's template. It creates an array of card objects, each containing
     * a title and a list of fields with formatted labels and values.
     * @returns {Array<Object>} An array of objects, where each object represents a single card.
     */
    get cardRecords() {
        if (!this.tableData || !this.tableData.columnLabels || !this.tableData.columnApiNames || !this.tableData.columnFieldTypes) {
            return [];
        }

        let columnInfoMap = new Map();
        this.tableData.columnApiNames.forEach((apiName, index) => {
            columnInfoMap.set(apiName, {
                label: this.tableData.columnLabels[index],
                fieldType: this.tableData.columnFieldTypes[index] || 'text'
            });
        });

        let defaultTitlePrefix = this.tableData.tableName || 'Record';
        if (defaultTitlePrefix.endsWith('s')) {
            defaultTitlePrefix = defaultTitlePrefix.slice(0, -1);
        }

        // Dynamically find the first actual column to use as the title.
        // It skips 'Id' and any hidden URL fields injected by Apex Controller.
        let titleFieldApiName = this.tableData.columnApiNames.find(apiName => 
            apiName !== 'Id' && !apiName.toLowerCase().endsWith('url')
        ) || this.tableData.columnApiNames;

        return this.tableData.displayRecords.map((record, index) => {
            let fields = [];
            
            // Grab the value dynamically using the Magic Finder
            let rawTitleValue = record[titleFieldApiName];
            
            let cardTitle = rawTitleValue 
                ? this.formattedFieldValue(rawTitleValue, columnInfoMap.get(titleFieldApiName).fieldType) 
                : `${defaultTitlePrefix} Details`;

            this.tableData.columnApiNames.forEach(apiName => {
                // Skip 'Id' and our dynamically chosen Title field so they don't duplicate in the body
                if (apiName !== 'Id' && apiName !== titleFieldApiName) {
                    let value = record[apiName];
                    let colInfo = columnInfoMap.get(apiName);

                    if (colInfo) { 
                        let isFileAction = colInfo.fieldType && colInfo.fieldType.toLowerCase() === 'file_action';
                        
                        fields.push({
                            label: colInfo.label || apiName, 
                            value: this.formattedFieldValue(value, colInfo.fieldType),
                            key: record.Id + apiName,
                            isFileAction: isFileAction,
                            isProcessed: isFileAction ? !!value : false 
                        });
                    }
                }
            });

            return {
                Id: record.Id || `card-${index}`, 
                title: cardTitle,
                fields: fields
            };
        });
    }

    /**
     * @description A helper method to format field values based on their type.
     * It handles currency, date, and custom file_action types.
     * @param {*} fieldvalue The value to format.
     * @param {string} fieldType The type of the field.
     * @returns {*} The formatted value.
     */
    formattedFieldValue(fieldvalue, fieldType) {
        if (fieldvalue === null || fieldvalue === undefined || fieldvalue === '') {
            return '';
        }
        
        switch (fieldType.toLowerCase()) {
            case 'currency':
                return new Intl.NumberFormat('en-US', {
                    style: 'currency',
                    currency: 'USD',
                    maximumFractionDigits: 2
                }).format(fieldvalue);
                
            case 'date':
                try {
                    // Let standard JavaScript safely parse the string, avoiding split() errors
                    let d = new Date(fieldvalue);
                    if (!isNaN(d.getTime())) {
                        return new Intl.DateTimeFormat('en-US', {
                            timeZone: 'UTC', 
                            month: '2-digit',
                            day: '2-digit',
                            year: 'numeric'
                        }).format(d);
                    }
                } catch(e) {
                    console.error('Error formatting date: ', e);
                }
                return fieldvalue; 
                
            case 'text':
            case 'file_action':
                return fieldvalue;
            default:
                return fieldvalue;
        }
    }

    /**
     * @description Handles the "Load More" action. It dispatches a custom event
     * to the parent component to request more data.
     */
    handleLoadMore() {        
        let loadMoreEvent = new CustomEvent('loadmoreaction', {
            detail: { section: this.tableData.tableName }
        });
        this.dispatchEvent(loadMoreEvent);
    }

    /**
     * @description Dispatches filter changes for start date to the parent.
     */
    handleStartDate(event) {
        // Safely grab the value, or force it to null if the user cleared it
        let dateVal = event.detail.value ? event.detail.value : null;

        this.dispatchEvent(new CustomEvent('filteraction', { 
            detail: { type: 'start', value: dateVal, section: this.tableData.tableName },
            bubbles: true, 
            composed: true 
        }));
    }

    /**
     * @description Dispatches filter changes for end date to the parent.
     */
    handleEndDate(event) {
        // Safely grab the value, or force it to null if the user cleared it
        let dateVal = event.detail.value ? event.detail.value : null;

        this.dispatchEvent(new CustomEvent('filteraction', { 
            detail: { type: 'end', value: dateVal, section: this.tableData.tableName },
            bubbles: true, 
            composed: true 
        }));
    }

    /**
     * @description Fetches a secure Public Link for file preview in LWR.
     * If file is not found, dispatches a toast event to the main parent.
     */
    handleViewFile(event) {
        const receiptId = event.currentTarget.dataset.id;
        
        getReceiptFileUrl({ recordId: receiptId })
            .then(fileUrl => {
                if(fileUrl) {
                    window.open(fileUrl, '_blank');
                } else {
                    // Bubble up the toast event to ham_myImpactCmp
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
            .catch(error => console.error('Error fetching file URL', error));
    }

}