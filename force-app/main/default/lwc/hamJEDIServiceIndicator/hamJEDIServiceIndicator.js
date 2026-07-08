import { LightningElement, api, track, wire } from 'lwc';
import getServiceIndicators from '@salesforce/apex/HAMJediServiceIndicatorController.getServiceIndicators';
import { CurrentPageReference, NavigationMixin } from 'lightning/navigation';

export default class HamJEDIServiceIndicator extends NavigationMixin(LightningElement) {
    @api recordId;
    @track loading = false;
    @track activeIndicators = [];
    @track inactiveIndicators = [];
    @track sortedBy;
    @track sortedDirection = 'asc';
    @track activeSortField = 'ucinn_ascendv2__Start_Date__c';
    @track activePortalFilter = '';
    @track inactivePortalFilter = '';
    @track activeSectionName = 'Alumni Service Indicators';
    @track currentPage = 1;
    @track isMobile = false;
    _expandedRowIds = new Set();
    pageSize = 5;

    // Color palette for random assignment (matching Figma design)
    colorPalette = [
        { border: '#fe9339', background: '#fef8f2', badge: '#fe9339' }, // Orange
        { border: '#0176d3', background: '#f3f9fc', badge: '#0176d3' }, // Blue
        { border: '#2e844a', background: '#f3f8f4', badge: '#2e844a' }, // Green
        { border: '#8b5cf6', background: '#f9f6fd', badge: '#8b5cf6' }  // Purple
    ];

    // Portal filter options (shared for active and inactive)
    portalFilterOptions = [
        { label: 'All', value: '' },
        { label: 'Portal Visible', value: 'true' },
        { label: 'Not Portal Visible', value: 'false' }
    ];

    // Sort options for active indicators
    activeSortOptions = [
        { label: 'Start Date (Newest)', value: 'ucinn_ascendv2__Start_Date__c' },
        { label: 'Service Indicator Name', value: 'serviceIndicatorName' },
        { label: 'Code', value: 'code' }
    ];

    // DataTable columns for inactive indicators
    inactiveColumns = [
        {
            label: 'Service Indicator',
            fieldName: 'serviceIndicatorName',
            type: 'button',
            typeAttributes: {
                label: { fieldName: 'serviceIndicatorName' },
                name: 'view_indicator',
                variant: 'base',
                class: 'slds-text-link'
            },
            sortable: true
        },
        {
            label: 'Code',
            fieldName: 'code',
            type: 'text',
            sortable: true
        },
        {
            label: 'Start Date',
            fieldName: 'ucinn_ascendv2__Start_Date__c',
            type: 'date',
            sortable: true,
            typeAttributes: {
                year: 'numeric',
                month: 'short',
                day: '2-digit',
                timeZone: 'UTC'
            }
        },
        {
            label: 'End Date',
            fieldName: 'ucinn_ascendv2__End_Date__c',
            type: 'date',
            sortable: true,
            typeAttributes: {
                year: 'numeric',
                month: 'short',
                day: '2-digit',
                timeZone: 'UTC'
            }
        }
    ];

    // Read recordId from URL and load data
    @wire(CurrentPageReference)
    getStateParameters(currentPageReference) {
        if (currentPageReference?.state?.c__recordId) {
            this.recordId = currentPageReference.state.c__recordId;
            this.loading = true;

            getServiceIndicators({ contactId: this.recordId })
                .then(result => {
                    this.processIndicators(result || []);
                })
                .catch(error => {
                    console.error('Error fetching Service Indicators:', error);
                    this.activeIndicators = [];
                    this.inactiveIndicators = [];
                })
                .finally(() => {
                    this.loading = false;
                    // Restore scroll position after data loads
                    this.restoreScrollPosition();
                });
        }
    }

    /**
     * Save scroll position before navigating away
     */
    saveScrollPosition() {
        const scrollY = window.scrollY || window.pageYOffset;
        sessionStorage.setItem('serviceIndicatorScrollPos', scrollY.toString());
    }

    /**
     * Restore scroll position after returning to the page
     */
    restoreScrollPosition() {
        // Use setTimeout to ensure DOM is fully rendered
        setTimeout(() => {
            const savedScrollPos = sessionStorage.getItem('serviceIndicatorScrollPos');
            if (savedScrollPos !== null) {
                window.scrollTo(0, parseInt(savedScrollPos, 10));
                sessionStorage.removeItem('serviceIndicatorScrollPos');
            }
        }, 100);
    }

    /**
     * Process and separate indicators into active and inactive lists
     */
    processIndicators(data) {
        const active = [];
        const inactive = [];

        const filteredData = data.filter(indicator => (indicator.ucinn_ascendv2__Code_Formula__c || '') !== 'NCWH');

        filteredData.forEach((indicator, index) => {
            // Build full description: Description + Comments
            let fullDescription = indicator.ucinn_ascendv2__Service_Indicator_Description_Formula__c || '';
            if (indicator.ucinn_ascendv2__Comments__c) {
                fullDescription = fullDescription
                    ? `${fullDescription}\n${indicator.ucinn_ascendv2__Comments__c}`
                    : indicator.ucinn_ascendv2__Comments__c;
            }

            // Assign random color from palette
            const colorIndex = index % this.colorPalette.length;

            const processedIndicator = {
                ...indicator,
                serviceIndicatorName: indicator.ucinn_ascendv2__Service_Indicator_Value__r?.Name || '',
                code: indicator.ucinn_ascendv2__Code_Formula__c || '',
                fullDescription: fullDescription,
                formattedStartDate: this.formatDate(indicator.ucinn_ascendv2__Start_Date__c),
                colorClass: `color-${colorIndex}`
            };

            if (indicator.ucinn_ascendv2__Is_Active__c) {
                active.push(processedIndicator);
            } else {
                inactive.push(processedIndicator);
            }
        });

        this.activeIndicators = active;
        this.inactiveIndicators = inactive;

        // Apply default sort to active indicators
        this.sortActiveData(this.activeSortField);
    }

    /**
     * Generates a URL for a record page and opens it as a subtab.
     * @param {string} recordId - The ID of the record to navigate to.
     */
    navigateToRecord(recordId) {
        // Save scroll position before navigating
        this.saveScrollPosition();

        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: recordId,
                actionName: 'view'
            }
        });
    }

    /**
     * Handle clicks on active indicator cards.
     */
    handleRecordClick(event) {
        const recordId = event.currentTarget.dataset.id;
        this.navigateToRecord(recordId);
    }

    /**
     * Handle actions from the inactive indicators datatable.
     */
    handleRowAction(event) {
        const action = event.detail.action;
        const row = event.detail.row;

        if (action.name === 'view_indicator') {
            this.navigateToRecord(row.Id);
        }
    }

    /**
     * Format date for display with UTC timezone
     */
    formatDate(dateString) {
        if (!dateString) return '';
        const date = new Date(dateString);
        return date.toLocaleDateString('en-US', {
            year: 'numeric',
            month: 'numeric',
            day: 'numeric',
            timeZone: 'UTC'
        });
    }

    /**
     * Handle sorting in the datatable
     */
    handleSort(event) {
        const { fieldName: sortedBy, sortDirection } = event.detail;
        this.sortedBy = sortedBy;
        this.sortedDirection = sortDirection;
        this.currentPage = 1;
        this.sortData(sortedBy, sortDirection);
    }

    /**
     * Sort the inactive indicators data
     */
    sortData(field, direction) {
        const dir = direction === 'desc' ? -1 : 1;

        this.inactiveIndicators = [...this.inactiveIndicators].sort((a, b) => {
            let aValue = a[field] || '';
            let bValue = b[field] || '';

            // Special handling for the button-link column
            if (field === 'serviceIndicatorName') {
                aValue = a.serviceIndicatorName || '';
                bValue = b.serviceIndicatorName || '';
            }
            
            const va = aValue.toString().toLowerCase();
            const vb = bValue.toString().toLowerCase();
            if (va === vb) return 0;
            return va > vb ? dir : -dir;
        });
    }

    /**
     * Handle active indicator sort change
     */
    handleActiveSortChange(event) {
        this.activeSortField = event.detail.value;
        this.sortActiveData(this.activeSortField);
    }

    /**
     * Sort active indicators
     */
    sortActiveData(field) {
        // Sort by start date descending (newest first) or alphabetically for text fields
        const isDateField = field === 'ucinn_ascendv2__Start_Date__c';
        const dir = isDateField ? -1 : 1;

        this.activeIndicators = [...this.activeIndicators].sort((a, b) => {
            let va = a[field] ?? '';
            let vb = b[field] ?? '';

            if (isDateField) {
                va = va ? new Date(va).getTime() : 0;
                vb = vb ? new Date(vb).getTime() : 0;
            } else {
                va = va.toString().toLowerCase();
                vb = vb.toString().toLowerCase();
            }

            if (va === vb) return 0;
            return va > vb ? dir : -dir;
        });
    }

    /**
     * Portal filter helpers
     */
    _applyPortalFilter(list, filter) {
        if (!filter) return list;
        const visible = filter === 'true';
        return list.filter(i =>
            (i.ucinn_ascendv2__Service_Indicator_Value__r?.HAM_Is_Visible_On_Portal__c === true) === visible
        );
    }

    handleActivePortalFilterChange(event) {
        this.activePortalFilter = event.detail.value;
    }

    handleInactivePortalFilterChange(event) {
        this.inactivePortalFilter = event.detail.value;
        this.currentPage = 1;
    }

    get filteredActiveIndicators() {
        return this._applyPortalFilter(this.activeIndicators, this.activePortalFilter);
    }

    get filteredInactiveIndicators() {
        return this._applyPortalFilter(this.inactiveIndicators, this.inactivePortalFilter);
    }

    /**
     * Computed properties for count badges
     */
    get activeIndicatorsCountLabel() {
        return `${this.filteredActiveIndicators.length} Active`;
    }

    get inactiveIndicatorsCountLabel() {
        return `${this.filteredInactiveIndicators.length} Inactive`;
    }

    get hasActiveIndicators() {
        return this.activeIndicators.length > 0;
    }

    get hasInactiveIndicators() {
        return this.inactiveIndicators.length > 0;
    }

    get hasNoIndicators() {
        return this.activeIndicators.length === 0 && this.inactiveIndicators.length === 0;
    }

    get pagedInactiveIndicators() {
        const start = (this.currentPage - 1) * this.pageSize;
        return this.filteredInactiveIndicators.slice(start, start + this.pageSize);
    }

    get totalPages() {
        return Math.ceil(this.filteredInactiveIndicators.length / this.pageSize);
    }

    get pageInfo() {
        return `Page ${this.currentPage} of ${this.totalPages}`;
    }

    get isFirstPage() {
        return this.currentPage === 1;
    }

    get isLastPage() {
        return this.currentPage === this.totalPages;
    }

    handlePreviousPage() {
        if (!this.isFirstPage) this.currentPage -= 1;
    }

    handleNextPage() {
        if (!this.isLastPage) this.currentPage += 1;
    }

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

    get mobileInactiveIndicators() {
        return this.pagedInactiveIndicators.map(row => {
            const isExpanded = this._expandedRowIds.has(row.Id);
            return {
                ...row,
                formattedStartDate: this.formatDate(row.ucinn_ascendv2__Start_Date__c),
                formattedEndDate: this.formatDate(row.ucinn_ascendv2__End_Date__c),
                isExpanded,
                chevronIcon: isExpanded ? 'utility:chevronup' : 'utility:chevrondown'
            };
        });
    }

    handleRowToggle(event) {
        const rowId = event.currentTarget.dataset.id;
        if (this._expandedRowIds.has(rowId)) {
            this._expandedRowIds.delete(rowId);
        } else {
            this._expandedRowIds.add(rowId);
        }
        this._expandedRowIds = new Set(this._expandedRowIds);
    }

    /**
     * Handle accordion section toggle
     */
    handleSectionToggle(event) {
        const openedSections = event.detail.openSections;

        if (Array.isArray(openedSections)) {
            this.activeSectionName = openedSections.includes('Alumni Service Indicators') ? 'Alumni Service Indicators' : '';
        } else {
            this.activeSectionName = openedSections === 'Alumni Service Indicators' ? 'Alumni Service Indicators' : '';
        }
    }
}