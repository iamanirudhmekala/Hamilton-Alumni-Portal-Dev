import { LightningElement, api, track, wire } from 'lwc';
import { CurrentPageReference } from 'lightning/navigation';
import getSocietyMemberships from '@salesforce/apex/HAMJEDIGivingSocietyCtrl.getSocietyMemberships';

export default class HamJEDIGivingSociety extends LightningElement {
    // =========================================
    // Design Properties (Configurable in App Builder)
    // =========================================
    @api tableTitle;  // Table header title (no default)

    // =========================================
    // Core Properties
    // =========================================
    @track loading = false;

    // =========================================
    // Data model
    // =========================================
    @track rawMemberships = [];     // original unfiltered dataset from server
    @track membershipDetails = [];  // full, sorted dataset; pagination slices from here
    @track pageMemberships = [];    // current page rows
    @track displayColumns = [];

    // =========================================
    // UI Properties
    // =========================================
    @track activeSection = '';

    // =========================================
    // Advance Filters
    // =========================================
    @track showAdvanceFilters = false;
    @track filterGivingSociety = [];  // Array for multi-select
    @track filterMembershipStatus = '';
    @track filterMemberSinceStart = '';
    @track filterMemberSinceEnd = '';
    @track givingSocietyOptions = [];
    @track membershipStatusOptions = [];

    // =========================================
    // Sorting state
    // =========================================
    @track sortedBy = 'ucinn_ascendv2__Membership_Status__c';
    @track sortedDirection = 'asc';

    // =========================================
    // Pagination
    // =========================================
    @track pageSize = 10;
    @track pageNumber = 1;
    @track totalRecords = 0;

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

    // Compute current page slice
    derivePage() {
        const start = (this.pageNumber - 1) * this.pageSize;
        const end = start + this.pageSize;
        this.pageMemberships = this.membershipDetails.slice(start, end);
    }

    // Pagination handlers
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
    // Data Loading
    // =========================================
    @wire(CurrentPageReference)
    getStateParameters(currentPageReference) {
        if (currentPageReference?.state?.c__recordId) {
            this.recordId = currentPageReference.state.c__recordId;
        }
    }

    // Load data when recordId changes
    connectedCallback() {
        if (this.recordId) {
            this.loadMemberships();
        }
    }

    // Watch for recordId changes from parent
    @api
    get recordId() {
        return this._recordId;
    }
    set recordId(value) {
        this._recordId = value;
        if (value) {
            this.loadMemberships();
        }
    }
    _recordId;

    loadMemberships() {
        if (!this._recordId) {
            console.log('No recordId available');
            return;
        }

        console.log('Loading memberships for contactId:', this._recordId);
        this.loading = true;

        getSocietyMemberships({ contactId: this._recordId })
            .then(result => {
                const rows = result || [];
                console.log('Received rows:', rows.length, rows);

                // Define columns for datatable
                this.displayColumns = [
                    {
                        label: 'Society Membership ID',
                        fieldName: 'recordLink',
                        type: 'url',
                        typeAttributes: {
                            label: { fieldName: 'Name' },
                            target: '_blank'
                        },
                        sortable: true
                    },
                    {
                        label: 'Giving Society',
                        fieldName: 'GivingSocietyName',
                        type: 'text',
                        sortable: true
                    },
                    {
                        label: 'Membership Level',
                        fieldName: 'ucinn_ascendv2__Membership_Level__c',
                        type: 'text',
                        sortable: true
                    },
                    {
                        label: 'Membership Status',
                        fieldName: 'ucinn_ascendv2__Membership_Status__c',
                        type: 'text',
                        sortable: true
                    },
                    {
                        label: 'Member Since',
                        fieldName: 'ucinn_ascendv2__Member_Since__c',
                        type: 'date',
                        typeAttributes: {
                            timeZone: 'UTC'
                        },
                        sortable: true
                    },
                    {
                        label: 'Anniversary Date',
                        fieldName: 'ucinn_ascendv2__Anniversary_Date__c',
                        type: 'date',
                        typeAttributes: {
                            timeZone: 'UTC'
                        },
                        sortable: true
                    },
                    {
                        label: 'Expiration Date',
                        fieldName: 'ucinn_ascendv2__Expiration_Date__c',
                        type: 'date',
                        typeAttributes: {
                            timeZone: 'UTC'
                        },
                        sortable: true
                    },
                    {
                        label: 'Current FY Member',
                        fieldName: 'Current_Fiscal_Year_Member__c',
                        type: 'boolean',
                        sortable: true
                    },
                    {
                        label: 'JBA Anonymous',
                        fieldName: 'HAM_JBA_Anonymous__c',
                        type: 'boolean',
                        sortable: true
                    },
                    {
                        label: 'Will Provision',
                        fieldName: 'HAM_Will_Provision__c',
                        type: 'boolean',
                        sortable: true
                    },
                    {
                        label: 'Planned Gift',
                        fieldName: 'HAM_Planned_Gift__c',
                        type: 'boolean',
                        sortable: true
                    },
                    {
                        label: 'Documented',
                        fieldName: 'HAM_Documented__c',
                        type: 'boolean',
                        sortable: true
                    },
                    {
                        label: 'Unknown',
                        fieldName: 'HAM_Unknown__c',
                        type: 'boolean',
                        sortable: true
                    },
                    {
                        label: 'Comments',
                        fieldName: 'ucinn_ascendv2__Comments__c',
                        type: 'text',
                        sortable: true,
                        wrapText: true
                    }
                ];

                // Add record links for navigation and flatten Giving Society Name
                const processedRows = rows.map(record => {
                    console.log('Processing record:', record);
                    console.log('Giving Society lookup:', record.ucinn_ascendv2__Giving_Society__r);
                    console.log('Giving Society Name:', record.ucinn_ascendv2__Giving_Society__r?.Name);
                    return {
                        ...record,
                        recordLink: `/${record.Id}`,
                        GivingSocietyName: record.ucinn_ascendv2__Giving_Society__r?.Name || ''
                    };
                });

                // Store original unfiltered data
                this.rawMemberships = [...processedRows];
                this.membershipDetails = [...processedRows];

                // Extract unique Giving Societies for filter options (multi-select, no --None--)
                const uniqueSocieties = new Set();
                processedRows.forEach(row => {
                    if (row.GivingSocietyName) {
                        uniqueSocieties.add(row.GivingSocietyName);
                    }
                });
                this.givingSocietyOptions = Array.from(uniqueSocieties).sort().map(society => ({
                    label: society,
                    value: society
                }));
                console.log('Giving Society Options:', this.givingSocietyOptions);

                // Extract unique Membership Statuses for filter options
                const uniqueStatuses = new Set();
                processedRows.forEach(row => {
                    if (row.ucinn_ascendv2__Membership_Status__c) {
                        uniqueStatuses.add(row.ucinn_ascendv2__Membership_Status__c);
                    }
                });
                this.membershipStatusOptions = [
                    { label: '--None--', value: '' },
                    ...Array.from(uniqueStatuses).sort().map(status => ({
                        label: status,
                        value: status
                    }))
                ];

                this.finalizeDataSetup();
            })
            .catch(error => {
                console.error('Error fetching society memberships:', error);
                console.error('Error details:', JSON.stringify(error));
                this.handleError();
            })
            .finally(() => {
                this.loading = false;
            });
    }

    // =========================================
    // Helper Methods
    // =========================================
    finalizeDataSetup() {
        this.totalRecords = this.membershipDetails.length;

        // Apply default sort
        this.sortData(this.sortedBy, this.sortedDirection);

        // Reset to first page and compute slice
        this.pageNumber = 1;
        this.derivePage();

        // Set active section - open if there are records, closed if none
        this.activeSection = this.totalRecords > 0 ? this.tableTitle : '';
    }

    handleError() {
        this.rawMemberships = [];
        this.membershipDetails = [];
        this.pageMemberships = [];
        this.totalRecords = 0;
        this.pageNumber = 1;
    }

    // =========================================
    // Event Handlers
    // =========================================
    handleSectionToggle(event) {
        const openedSections = event.detail.openSections;

        if (Array.isArray(openedSections)) {
            this.activeSection = openedSections.includes(this.tableTitle) ? this.tableTitle : '';
        } else {
            this.activeSection = openedSections === this.tableTitle ? this.tableTitle : '';
        }
    }

    handleSort(event) {
        const { fieldName: sortedBy, sortDirection } = event.detail;
        this.sortedBy = sortedBy;
        this.sortedDirection = sortDirection;

        this.sortData(sortedBy, sortDirection);

        // Reset to first page after sorting
        this.pageNumber = 1;
        this.derivePage();
    }

    sortData(field, direction) {
        const key = field === 'recordLink' ? 'Name' : field;
        const dir = direction === 'desc' ? -1 : 1;

        this.membershipDetails = [...this.membershipDetails].sort((a, b) => {
            let va = a[key] ?? '';
            let vb = b[key] ?? '';

            // Handle date fields
            if (field === 'ucinn_ascendv2__Member_Since__c' ||
                field === 'ucinn_ascendv2__Anniversary_Date__c' ||
                field === 'ucinn_ascendv2__Expiration_Date__c') {
                va = va ? new Date(va).getTime() : 0;
                vb = vb ? new Date(vb).getTime() : 0;
            } else if (typeof va === 'boolean' || typeof vb === 'boolean') {
                // Handle boolean fields
                va = va ? 1 : 0;
                vb = vb ? 1 : 0;
            } else {
                va = va.toString().toLowerCase();
                vb = vb.toString().toLowerCase();
            }

            // Primary sort by the selected field
            if (va !== vb) {
                return va > vb ? dir : -dir;
            }

            // Secondary sort: Membership Status ASC
            let statusA = (a.ucinn_ascendv2__Membership_Status__c ?? '').toString().toLowerCase();
            let statusB = (b.ucinn_ascendv2__Membership_Status__c ?? '').toString().toLowerCase();
            if (statusA !== statusB) {
                return statusA > statusB ? 1 : -1;
            }

            // Tertiary sort: Member Since DESC (most recent first)
            let dateA = a.ucinn_ascendv2__Member_Since__c ? new Date(a.ucinn_ascendv2__Member_Since__c).getTime() : 0;
            let dateB = b.ucinn_ascendv2__Member_Since__c ? new Date(b.ucinn_ascendv2__Member_Since__c).getTime() : 0;
            return dateB - dateA;
        });
    }

    // =========================================
    // Advance Filter Methods
    // =========================================
    // Dynamic button label for Advance Filters
    get advanceFiltersButtonLabel() {
        return this.showAdvanceFilters ? 'Hide Advance Filters' : 'Show Advance Filters';
    }

    toggleAdvanceFilters() {
        this.showAdvanceFilters = !this.showAdvanceFilters;

        // Open accordion when showing filters
        if (this.showAdvanceFilters) {
            this.activeSection = this.tableTitle;
        }
    }

    handleGivingSocietyChange(event) {
        this.filterGivingSociety = event.detail.value;
        this.handleSearchFilters();
    }

    handleMembershipStatusChange(event) {
        this.filterMembershipStatus = event.detail.value;
        this.handleSearchFilters();
    }

    handleMemberSinceStartChange(event) {
        this.filterMemberSinceStart = event.target.value;
        this.handleSearchFilters();
    }

    handleMemberSinceEndChange(event) {
        this.filterMemberSinceEnd = event.target.value;
        this.handleSearchFilters();
    }

    handleSearchFilters() {
        // Start with original unfiltered data
        let filteredMemberships = [...this.rawMemberships];

        // Apply Giving Society Filter (multi-select)
        if (this.filterGivingSociety && this.filterGivingSociety.length > 0) {
            filteredMemberships = filteredMemberships.filter(membership => {
                return this.filterGivingSociety.includes(membership.GivingSocietyName);
            });
        }

        // Apply Membership Status Filter
        if (this.filterMembershipStatus) {
            filteredMemberships = filteredMemberships.filter(membership => {
                return membership.ucinn_ascendv2__Membership_Status__c === this.filterMembershipStatus;
            });
        }

        // Apply Member Since Date Filters
        if (this.filterMemberSinceStart || this.filterMemberSinceEnd) {
            filteredMemberships = filteredMemberships.filter(membership => {
                const memberSinceDate = membership.ucinn_ascendv2__Member_Since__c;

                // Skip if no member since date
                if (!memberSinceDate) return false;

                // Scenario 1: Only Filter Start Date → from filter start date onwards
                if (this.filterMemberSinceStart && !this.filterMemberSinceEnd) {
                    return memberSinceDate >= this.filterMemberSinceStart;
                }

                // Scenario 2: Only Filter End Date → from beginning to filter end date
                if (!this.filterMemberSinceStart && this.filterMemberSinceEnd) {
                    return memberSinceDate <= this.filterMemberSinceEnd;
                }

                // Scenario 3: Both Filter Start and End Date → specific range
                if (this.filterMemberSinceStart && this.filterMemberSinceEnd) {
                    return memberSinceDate >= this.filterMemberSinceStart &&
                           memberSinceDate <= this.filterMemberSinceEnd;
                }

                return true;
            });
        }

        // Update membershipDetails with filtered data
        this.membershipDetails = [...filteredMemberships];
        this.totalRecords = this.membershipDetails.length;

        // Re-apply current sort
        this.sortData(this.sortedBy, this.sortedDirection);

        // Reset to page 1 and update display
        this.pageNumber = 1;
        this.derivePage();
    }

    handleClearFilters() {
        // Clear filter values
        this.filterGivingSociety = [];
        this.filterMembershipStatus = '';
        this.filterMemberSinceStart = '';
        this.filterMemberSinceEnd = '';

        // Reset to original unfiltered data
        this.membershipDetails = [...this.rawMemberships];
        this.totalRecords = this.membershipDetails.length;

        // Re-apply current sort
        this.sortData(this.sortedBy, this.sortedDirection);

        // Reset to page 1 and update display
        this.pageNumber = 1;
        this.derivePage();
    }
}