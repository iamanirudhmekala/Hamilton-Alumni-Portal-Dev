// 03/16/2026 NVV: ASC-12644-Mobile view: Cards implementation
import { LightningElement, api, track, wire } from 'lwc';
import { CurrentPageReference } from 'lightning/navigation';
import getCampaignDetail from '@salesforce/apex/HAMJEDIPledgeBalanceController.getCampaignDetail';
import getEndowdedFundsDetail from '@salesforce/apex/HAMJEDIPledgeBalanceController.getEndowdedFundsDetail';
import getLast5YearsDetail from '@salesforce/apex/HAMJEDIPledgeBalanceController.getLast5YearsDetail';
import getLast5YearsCYDetail from '@salesforce/apex/HAMJEDIPledgeBalanceController.getLast5YearsCYDetail';
import getGivingByPurposeDetail from '@salesforce/apex/HAMJEDIPledgeBalanceController.getGivingByPurposeDetail';
import getOpenPledgeDetail from '@salesforce/apex/HAMJEDIPledgeBalanceController.getOpenPledgeDetail';

export default class HAMJediPledgeBalanceConfigTable extends LightningElement {
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
        this.isMobile = window.innerWidth <= 768;
    }

    // =========================================
    // Core Properties
    // =========================================
    @api tableName; // Parameter to find the table
    @api recordId;
    @track loading = false; // Spinner control
    
    // =========================================
    // Data model
    // =========================================
    _allBalanceDetails = [];           // unfiltered full dataset (for year filter)
    @track balanceDetails = [];        // filtered dataset (or same as _all when no filter)
    @track pageBalance = [];           // current page rows bound to the datatable
    @track displayColumns = [];

    // =========================================
    // Mobile Year Filter (Last 5 Year tables only)
    // =========================================
    _yearField = '';                   // field name that holds the year value (e.g. HAM_Fiscal_Year__c)
    @track _selectedYear = '';
    
    // =========================================
    // UI Properties
    // =========================================
    @track accordianName = '';
    @track fundDate = '';
    @track activeBalanceSection = 'Campaign';
   
    // =========================================
    // Card layout bucket
    // =========================================
    // compact  = all rows side-by-side (Campaign, Open Pledge, Giving By Purpose, Endowed Funds)
    // expanded = text fields stacked for readability (Last 5 Year Giving, Last 5 Year Giving CY)
    _compactCard = true;

    // Show More/Less for stacked text fields
    _expandedFields = new Set();

    // =========================================
    // Sorting state
    // =========================================
    @track sortedBy = 'Name';
    @track sortedDirection = 'asc';

    // =========================================
    // Pagination (following your standards)
    // =========================================
    @track pageSize = 10;     // rows per page
    @track pageNumber = 1;    // 1-based index
    @track totalRecords = 0;  // derived from balanceDetails.length

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
        return this.totalRecords > this.pageSize;
    }

    // Compute current page slice from balanceDetails → pageBalance
    derivePage() {
        const start = (this.pageNumber - 1) * this.pageSize;
        const end = start + this.pageSize;
        this.pageBalance = this.balanceDetails.slice(start, end);
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
    // Data Loading and Setup
    // =========================================
    @wire(CurrentPageReference)
    getStateParameters(currentPageReference) {
        if (currentPageReference?.state?.c__recordId) {
            this.recordId = currentPageReference.state.c__recordId;
           
            if(this.tableName){
                 this.accordianName = this.tableName;
            } else {
                this.accordianName = 'Campaign';
            }
           
            this.loading = true; // Start spinner
            
            if(this.tableName == 'Endowed Funds'){
                this.loadEndowedFunds();
            } else if(this.tableName == 'Campaign'){
                this.loadCampaign();
            } else if(this.tableName == 'Giving By Purpose'){
                this.loadGivingByPurpose();
            } else if(this.tableName == 'Last 5 year Giving'){
                this.pageSize = 5;
                this._compactCard = false;
                this._yearField = 'HAM_Fiscal_Year__c';
                this.loadLast5Years();
            } else if(this.tableName == 'Last 5 year Giving CY'){
                this.pageSize = 5;
                this._compactCard = false;
                this._yearField = 'HAM_Fiscal_Year__c';
                this.loadLast5YearsCY();
            } else {
                // open Pledge (default)
                this.loadOpenPledge();
            }
        }
    }

    // =========================================
    // Data Loading Methods
    // =========================================
    loadEndowedFunds() {
        getEndowdedFundsDetail({ contactId: this.recordId })
            .then(result => {
                this.balanceDetails = result || [];
                this.displayColumns = [
                    {
                        label: 'Name',
                        fieldName: 'HAM_Designation__c',
                        type: 'text',
                        sortable: true
                    },
                    {
                        label: 'Book Value',
                        fieldName: 'HAM_Pledged__c',
                        type: 'currency',
                        typeAttributes: {
                            currencyCode: 'USD',
                            minimumFractionDigits: 2
                        },
                        sortable: true
                    },
                    {
                        label: 'Market Value',
                        fieldName: 'HAM_Paid__c',
                        type: 'currency',
                        typeAttributes: {
                            currencyCode: 'USD',
                            minimumFractionDigits: 2
                        },
                        sortable: true
                    },
                    {
                        label: 'As Of',
                        fieldName: 'HAM_Endowed_Fund_Date__c',
                        type: 'date',
                        typeAttributes: {
                            year: 'numeric',
                            month: 'short',
                            day: '2-digit',
                            hour: '2-digit',
                            minute: '2-digit'
                        },
                        sortable: true
                    }
                ];
                
                //Sorting Table
                this.sortedBy = 'HAM_Paid__c';
                this.sortedDirection = 'desc';

                this.finalizeDataSetup();
            })
            .catch(error => {
                console.error('Error fetching Endowed Funds:', error);
                this.handleError();
            })
            .finally(() => {
                this.loading = false;
            });
    }

    loadCampaign() {
        getCampaignDetail({ contactId: this.recordId })
            .then(result => {
                this.balanceDetails = result || [];
                
                this.displayColumns = [
                    {
                        label: 'Purpose',
                        fieldName: 'HAM_Designation__c',
                        type: 'text',
                        sortable: true
                    },
                    {
                        label: 'Committed',
                        fieldName: 'HAM_Pledged__c',
                        type: 'currency',
                        typeAttributes: {
                            currencyCode: 'USD',
                            minimumFractionDigits: 2
                        },
                        sortable: true
                    },
                    {
                       label: 'Paid',
                        fieldName: 'HAM_Paid__c',
                        type: 'currency',
                        typeAttributes: {
                            currencyCode: 'USD',
                            minimumFractionDigits: 2
                        },
                        sortable: true
                    }
                ];
                
                this.finalizeDataSetup();
            })
            .catch(error => {
                console.error('Error fetching Campaign:', error);
                this.handleError();
            })
            .finally(() => {
                this.loading = false;
            });
    }

    loadGivingByPurpose() {
        getGivingByPurposeDetail({ contactId: this.recordId })
            .then(result => {
                this.balanceDetails = result || [];
                
                this.displayColumns = [
                    {
                        label: 'Purpose',
                        fieldName: 'HAM_Designation__c',
                        type: 'text',
                        sortable: true
                    },
                    {
                        label: 'Committed',
                        fieldName: 'HAM_Pledged__c',
                        type: 'currency',
                        typeAttributes: {
                            currencyCode: 'USD',
                            minimumFractionDigits: 2
                        },
                        sortable: true
                    },
                    {
                        label: 'Paid',
                        fieldName: 'HAM_Paid__c',
                        type: 'currency',
                        typeAttributes: {
                            currencyCode: 'USD',
                            minimumFractionDigits: 2
                        },
                        sortable: true
                    }
                ];
                
                this.finalizeDataSetup();
            })
            .catch(error => {
                console.error('Error fetching Giving by Purpose:', error);
                this.handleError();
            })
            .finally(() => {
                this.loading = false;
            });
    }

    loadLast5Years() {
        getLast5YearsDetail({ contactId: this.recordId })
            .then(result => {
                this.balanceDetails = result || [];

                this.displayColumns = [
                    {
                        label: 'Fiscal Year',
                        fieldName: 'HAM_Fiscal_Year__c',
                        type: 'text',
                        sortable: true
                    },
                    {
                        label: 'Purpose',
                        fieldName: 'HAM_Designation__c',
                        type: 'text',
                        sortable: true
                    },
                    {
                        label: 'Committed',
                        fieldName: 'HAM_Pledged__c',
                        type: 'currency',
                        typeAttributes: {
                            currencyCode: 'USD',
                            minimumFractionDigits: 2
                        },
                        sortable: true
                    },
                    {
                        label: 'Paid',
                        fieldName: 'HAM_Paid__c',
                        type: 'currency',
                        typeAttributes: {
                            currencyCode: 'USD',
                            minimumFractionDigits: 2
                        },
                        sortable: true
                    }
                ];
                //Sorting Table
                this.sortedBy = 'HAM_Fiscal_Year__c';
                this.sortedDirection = 'desc';

                this.finalizeDataSetup();
            })
            .catch(error => {
                console.error('Error fetching Last 5 Years:', error);
                this.handleError();
            })
            .finally(() => {
                this.loading = false;
            });
    }

    loadLast5YearsCY() {
        getLast5YearsCYDetail({ contactId: this.recordId })
            .then(result => {
                this.balanceDetails = result || [];

                this.displayColumns = [
                    {
                        label: 'Calendar Year',
                        fieldName: 'HAM_Fiscal_Year__c',
                        type: 'text',
                        sortable: true
                    },
                    {
                        label: 'Purpose',
                        fieldName: 'HAM_Designation__c',
                        type: 'text',
                        sortable: true
                    },
                    {
                        label: 'Committed',
                        fieldName: 'HAM_Pledged__c',
                        type: 'currency',
                        typeAttributes: {
                            currencyCode: 'USD',
                            minimumFractionDigits: 2
                        },
                        sortable: true
                    },
                    {
                        label: 'Paid',
                        fieldName: 'HAM_Paid__c',
                        type: 'currency',
                        typeAttributes: {
                            currencyCode: 'USD',
                            minimumFractionDigits: 2
                        },
                        sortable: true
                    }
                ];
                //Sorting Table
                this.sortedBy = 'HAM_Fiscal_Year__c';
                this.sortedDirection = 'desc';

                this.finalizeDataSetup();
            })
            .catch(error => {
                console.error('Error fetching Last 5 Years CY:', error);
                this.handleError();
            })
            .finally(() => {
                this.loading = false;
            });
    }

    loadOpenPledge() {
        getOpenPledgeDetail({ contactId: this.recordId })
            .then(result => {
                this.balanceDetails = result || [];
                
                this.displayColumns = [
                    {
                        label: 'Purpose',
                        fieldName: 'HAM_Designation__c',
                        type: 'text',
                        sortable: true
                    },
                    {
                        label: 'Committed',
                        fieldName: 'HAM_Pledged__c',
                        type: 'currency',
                        typeAttributes: {
                            currencyCode: 'USD',
                            minimumFractionDigits: 2
                        },
                        sortable: true
                    },
                    {
                        label: 'Paid',
                        fieldName: 'HAM_Paid__c',
                        type: 'currency',
                        typeAttributes: {
                            currencyCode: 'USD',
                            minimumFractionDigits: 2
                        },
                        sortable: true
                    },
                    {
                        label: 'Balance',
                        fieldName: 'HAM_Pledge_Balance__c',
                        type: 'currency',
                        typeAttributes: {
                            currencyCode: 'USD',
                            minimumFractionDigits: 2
                        },
                        sortable: true
                    }
                ];
                
                this.finalizeDataSetup();
            })
            .catch(error => {
                console.error('Error fetching Open Pledge:', error);
                this.handleError();
            })
            .finally(() => {
                this.loading = false;
            });
    }

    // =========================================
    // Mobile Sort
    // =========================================
    get mobileSortOptions() {
        return this.displayColumns.map(col => ({
            label: col.label,
            value: col.fieldName
        }));
    }

    get mobileSortDirectionIcon() {
        return this.sortedDirection === 'asc' ? 'utility:arrowup' : 'utility:arrowdown';
    }

    get mobileSortDirectionLabel() {
        return this.sortedDirection === 'asc' ? 'Ascending' : 'Descending';
    }

    handleMobileSortChange(event) {
        this.sortedBy = event.detail.value;
        // Auto-desc for currency fields, auto-asc for text
        const col = this.displayColumns.find(c => c.fieldName === this.sortedBy);
        this.sortedDirection = col && col.type === 'currency' ? 'desc' : 'asc';
        this.sortEventData(this.sortedBy, this.sortedDirection);
        this.pageNumber = 1;
        this.derivePage();
    }

    toggleMobileSortDirection() {
        this.sortedDirection = this.sortedDirection === 'asc' ? 'desc' : 'asc';
        this.sortEventData(this.sortedBy, this.sortedDirection);
        this.pageNumber = 1;
        this.derivePage();
    }

    // =========================================
    // Mobile Year Filter (Last 5 Year tables)
    // =========================================
    get showYearFilter() {
        return this._yearField !== '';
    }

    get mobileYearOptions() {
        if (!this._yearField || !this._allBalanceDetails.length) return [];
        const years = [...new Set(this._allBalanceDetails.map(r => r[this._yearField]).filter(Boolean))];
        years.sort((a, b) => b.localeCompare(a)); // desc: newest first
        return [
            { label: 'All Years', value: '' },
            ...years.map(y => ({ label: y, value: y }))
        ];
    }

    handleYearFilterChange(event) {
        this._selectedYear = event.detail.value;
        this.applyYearFilter();
    }

    clearYearFilter() {
        this._selectedYear = '';
        this.applyYearFilter();
    }

    applyYearFilter() {
        if (this._selectedYear) {
            this.balanceDetails = this._allBalanceDetails.filter(
                r => r[this._yearField] === this._selectedYear
            );
        } else {
            this.balanceDetails = [...this._allBalanceDetails];
        }
        this.totalRecords = this.balanceDetails.length;
        this.sortEventData(this.sortedBy, this.sortedDirection);
        this.pageNumber = 1;
        this.derivePage();
    }

    // =========================================
    // Mobile Card Getter (dynamic from displayColumns)
    // =========================================
    toggleShowMore(event) {
        const fieldKey = event.currentTarget.dataset.fieldkey;
        if (this._expandedFields.has(fieldKey)) {
            this._expandedFields.delete(fieldKey);
        } else {
            this._expandedFields.add(fieldKey);
        }
        this.derivePage(); // re-derive to trigger getter recalculation
    }

    get mobileCards() {
        if (!this.pageBalance || !this.displayColumns.length) return [];
        const [headerCol, ...bodyColumns] = this.displayColumns;
        const compact = this._compactCard;
        const maxLen = 100;
        return this.pageBalance.map(row => ({
            Id: row.Id,
            headerValue: row[headerCol.fieldName] || '',
            fields: bodyColumns.map((col, idx) => {
                const isStacked = !compact && col.type === 'text';
                const rawValue = this.formatCardValue(row[col.fieldName], col.type, col.typeAttributes);
                const fieldKey = `${row.Id}-${idx}`;
                const isExpanded = this._expandedFields.has(fieldKey);
                const needsTruncation = isStacked && rawValue.length > maxLen;
                return {
                    key: fieldKey,
                    label: col.label,
                    value: needsTruncation && !isExpanded ? rawValue.substring(0, maxLen) + '...' : rawValue,
                    isStacked,
                    needsTruncation,
                    showMoreLabel: isExpanded ? 'Show Less' : 'Show More'
                };
            })
        }));
    }

    formatCardValue(val, colType, typeAttributes) {
        if (val == null) return '';
        if (colType === 'currency') {
            const code = typeAttributes?.currencyCode || 'USD';
            const minDigits = typeAttributes?.minimumFractionDigits ?? 2;
            return Number(val).toLocaleString('en-US', { style: 'currency', currency: code, minimumFractionDigits: minDigits });
        }
        if (colType === 'date') {
            const opts = typeAttributes || { year: 'numeric', month: 'short', day: '2-digit' };
            return new Date(val).toLocaleDateString('en-US', opts);
        }
        return String(val);
    }

    // =========================================
    // Helper Methods
    // =========================================
    finalizeDataSetup() {
        // Store unfiltered copy for year filter & reset filter state
        this._allBalanceDetails = [...this.balanceDetails];
        this._selectedYear = '';
        this.totalRecords = this.balanceDetails.length;

        // Apply default sort
        this.sortEventData(this.sortedBy, this.sortedDirection);

        // Reset to first page and compute slice
        this.pageNumber = 1;
        this.derivePage();

        // Set active section only if there are records
        this.activeBalanceSection = this.totalRecords > 0 ? this.tableName : '';
    }

    handleError() {
        this._allBalanceDetails = [];
        this.balanceDetails = [];
        this.pageBalance = [];
        this.totalRecords = 0;
        this.pageNumber = 1;
        this._selectedYear = '';
        this.activeBalanceSection = '';
    }

    // =========================================
    // Event Handlers
    // =========================================
    handleBalanceSectionToggle(event) {
        const openedSections = event.detail.openSections;
        
        if (Array.isArray(openedSections)) {
            this.activeBalanceSection = openedSections.includes(this.tableName) ? this.tableName : '';
        } else {
            this.activeBalanceSection = openedSections === this.tableName ? this.tableName : '';
        }
    }

    // =========================================
    // Datatable sort handler
    // =========================================
    handleEventSort(event) {
        const { fieldName: sortedBy, sortDirection } = event.detail;
        this.sortedBy = sortedBy;
        this.sortedDirection = sortDirection;

        this.sortEventData(sortedBy, sortDirection);

        // Reset to first page after sorting and compute slice
        this.pageNumber = 1;
        this.derivePage();
    }

    // Core sort routine. We always sort balanceDetails so pagination stays consistent.
    sortEventData(field, direction) {
        const key = field === 'recordLink' ? 'Name' : field;
        const dir = direction === 'desc' ? -1 : 1;

        this.balanceDetails = [...this.balanceDetails].sort((a, b) => {
            let va = a[key] ?? '';
            let vb = b[key] ?? '';
            
            // Handle currency fields specially
            if (field === 'HAM_Pledged__c' || field === 'HAM_Paid__c' || field === 'HAM_Pledge_Balance__c') {
                va = parseFloat(va) || 0;
                vb = parseFloat(vb) || 0;
            } else {
                va = va.toString().toLowerCase();
                vb = vb.toString().toLowerCase();
            }
            
            if (va === vb) return 0;
            return va > vb ? dir : -dir;
        });
    }
}