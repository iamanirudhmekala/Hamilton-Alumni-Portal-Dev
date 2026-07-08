import { LightningElement, api, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { CurrentPageReference } from 'lightning/navigation';
import { refreshApex } from '@salesforce/apex';
import getEngagementData from '@salesforce/apex/hamCCVolunteerEngagementController.getEngagementData';
import insertInvolvement from '@salesforce/apex/hamCCVolunteerEngagementController.insertInvolvement';
import updateInvolvement from '@salesforce/apex/hamCCVolunteerEngagementController.updateInvolvement';
import getQuickSelectCodes from '@salesforce/apex/hamCCVolunteerEngagementController.getQuickSelectCodes';
import getInvolvementDescriptionValues from '@salesforce/apex/hamCCVolunteerEngagementController.getInvolvementDescriptionValues';

export default class HamCCVolunteerEngagement extends LightningElement {
    @api recordId; // Contact record ID
    @api isAlumni;
    wiredResult;
    @track isExpanded = true;
    @track showAddForm = false;
    @track showEditForm = false;
    @track isSaving = false;
    @track editRecordId = null;
    @track currentPage = 1;
    @track sortField = 'startDate';
    @track sortDirection = 'desc';
    @track filterRole = 'all';
    @track currentFiscalYear; 
    @track lastFiscalYear; 
    @track currentFiscalYearScore = 0; 
    @track lastFiscalYearScore = 0;
    @track scoreTrend = 'up';
    @track lastYearTrend = 'down';
    @track involvementData = [];

    // UI state: spinner during filtering
    @track isFiltering = false;

    // Filtering UI state (hidden by default)
    @track showFilters = false;

    // Quick-select chips for Add Activity form
    @track quickTopOptions = [];
    @track quickMoreOptions = [];
    @track selectedQuickPickId = null;
    @track showMoreChips = false;
    @track showInvolvementPicker = true;

    // Involvement Description typeahead
    @track descOptions = [];
    @track filteredDescOptions = [];
    @track showDescDropdown = false;
    @track descSearchTerm = '';
    _descMouseDown = false;

    // Mobile detection
    @track isMobile = false;

    // Raw dataset (unfiltered) and working dataset
    @track rawInvolvementData = [];
    @track filteredInvolvementData = [];

    // Filter fields
    @track filterStartDate = '';
    @track filterEndDate = '';
    @track filterInvolvementCode = ''; // stores Id
    @track filterStatus = ''; // 'Current' | 'Former' | ''
    @track filterMinScore = '';

    // Derived picklist options (built from data)
    @track involvementCodeOptions = []; // [{label, value: Id}]
    @track statusOptions = [
        { label: '--None--', value: '' },
        { label: 'Current', value: 'Current' },
        { label: 'Former', value: 'Former' }
    ];
    @track involvementColumnData = [ 
        {
            label: 'Name',
            fieldName: 'recordUrl',
            type: 'url',
            typeAttributes: {
                label: { fieldName: 'Name' },
                target: '_blank'
            }
        },

        { label: 'Status', fieldName: 'Status__c', type: 'text' },

        // Owner clickable link
        {
            label: 'Owner',
            fieldName: 'ownerLink',
            type: 'url',
            typeAttributes: {
                label: { fieldName: 'ownerName' },
                target: '_blank'
            }
        },

        

        { 
            label: 'Involvement Code Description', 
            fieldName: 'Involvement_Desc__c', 
            type: 'text' 
        },

        { label: 'Start Date', fieldName: 'Start_Date__c', type: 'date', typeAttributes: { timeZone: 'UTC' } },

        { label: 'End Date', fieldName: 'End_Date__c', type: 'date', typeAttributes: { timeZone: 'UTC' }  },

        // Handshake link (URL)
        {
            label: 'Handshake Link',
            fieldName: 'HAM_Handshake_Link__c',
            type: 'url',
            typeAttributes: {
                label: 'Open Handshake',
                target: '_blank'
            }
        },

        // Involvement Code Name clickable link
        {
            label: 'Involvement Code',
            fieldName: 'Involvement_Link__c',
            type: 'url',
            typeAttributes: {
                label: { fieldName: 'Involvement_Name__c' },
                target: '_blank'
            }
        },

        { label: 'CC Score', fieldName: 'HAM_CC_Score__c', type: 'number' },

        // Action column
        {
            type: 'action',
            typeAttributes: {
                rowActions: [
                    { label: 'Edit', name: 'edit' }
                ]
            }
        }
    ];

    
    // Mock data - replace with @wire Apex call
    @track activities = [
        { 
            id: '1', 
            startDate: '03/20/2024', 
            endDate: '03/20/2024', 
            activityCode: 'RES-001', 
            description: 'Resume Review Session',
            handshakeLink: 'https://app.joinhandshake.com/events/123456',
            representative: 'Jennifer Williams',
            representativeId: '0051234567890ABC',
            score: 25
        },
        { 
            id: '2', 
            startDate: '03/15/2024', 
            endDate: '03/15/2024', 
            activityCode: 'CAR-002', 
            description: 'Career Fair - Spring 2024',
            handshakeLink: '',
            representative: 'Michael Brown',
            representativeId: '0051234567890DEF',
            score: 50
        },
        { 
            id: '3', 
            startDate: '06/10/2023', 
            endDate: '06/10/2023', 
            activityCode: 'RES-007', 
            description: 'Resume Review Session',
            handshakeLink: 'https://app.joinhandshake.com/events/234567',
            representative: 'Michael Brown',
            representativeId: '0051234567890DEF',
            score: 25
        }
    ];

    @track formData = {
        involvementId: null,
        assignedUserId: null,
        startDate: null,
        endDate: null,
        handshakeLink: '',
        involvementDescription: ''
    };

    @track formFilters = {
        criteria: [
            {
                fieldPath: 'ucinn_ascendv2__Type__c',
                operator: 'eq',
                value: 'Volunteer Engagement'
            },
            {
                fieldPath: 'HAM_Category__c',
                operator: 'eq',
                value: 'Career Center'
            },
            // Checkbox filter commented out - lightning-record-picker doesn't support boolean field filtering
            // Tried: true, 'true', 1, '1' - none worked
             {
                 fieldPath: 'HAM_Volunteer_Activity__c',
                 operator: 'eq',
                 value: true
             }
        ],
        filterLogic: '1 AND 2 AND 3'
    };

    @track userFilters = {
        criteria: [
            {
                fieldPath: 'IsActive',
                operator: 'eq',
                value: true
            }
        ]
    };

    involvementMatchingInfo = {
        primaryField: { fieldPath: 'Name' }
    };

    userMatchingInfo = {
        primaryField: { fieldPath: 'Name' },
        additionalFields: [{ fieldPath: 'Title' }]
    };


    itemsPerPage = 5;

    // Lifecycle methods for mobile detection
    connectedCallback() {
        this.checkScreen();
        this._resizeHandler = this.checkScreen.bind(this);
        window.addEventListener('resize', this._resizeHandler);

        console.log('Inside the method call -------'+this.recordId);
        const today = new Date().toISOString().split('T')[0];

        this.formData.startDate = today;
        this.formData.endDate = today;
        if (this.recordId) {
            console.log('Record Id ---------'+this.recordId);
            console.log('Is Alumni Id ---------'+this.isAlumni);
            getEngagementData({ recordId: this.recordId, isAlumni: this.isAlumni })
            .catch(error => {
                console.error('Error fetching data:', error);})
            .then(result => {
                this.wiredResult = result;  
                console.log('Record ---------'+result);
                //this.activities = result.ccInvolvments;
                this.currentFiscalYear = result.currentFiscalYear;
                this.lastFiscalYear = result.lastFiscalYear;
                this.currentFiscalYearScore = result.currentYearScore; 
                this.lastFiscalYearScore = result.lastYearScore;
                console.log('Current Year Score----'+result.currentYearScore);
                console.log('last Year Score----'+result.lastYearScore);
                if(result.currentYearTrend){
                    this.scoreTrend = 'up';
                }else{
                    this.scoreTrend = 'down';
                }
                if(result.lastYearTrend){
                    this.lastYearTrend = 'up';
                }else{
                    this.lastYearTrend = 'down';
                }
                    
                this.involvementData = [];
                if (result.ccInvolvments) {
                    this.involvementData = result.ccInvolvments.map(row => ({
                        ...row,

                        // Record URL for Name column
                        recordUrl: row.Id ? '/' + row.Id : null,

                        // Owner link
                        ownerName: row.Owner?.Name,
                        ownerLink: row.OwnerId ? '/' + row.OwnerId : null,

                        // Involvement code link
                        Involvement_Name__c: row.ucinn_ascendv2__Involvement_Code__r?.Name,
                        Involvement_Link__c: row.ucinn_ascendv2__Involvement_Code__c
                            ? '/' + row.ucinn_ascendv2__Involvement_Code__c
                            : null,

                        // Aliased for convenience
                        Account__c: row.ucinn_ascendv2__Account__c,
                        Status__c: row.ucinn_ascendv2__Status__c,
                        Involvement_Desc__c: row.ucinn_ascendv2__Involvement_Code_Description_Formula__c,
                        Start_Date__c: row.ucinn_ascendv2__Start_Date__c,
                        End_Date__c: row.ucinn_ascendv2__End_Date__c
                    }));

                    // Initialize raw/filtered datasets for JS filtering
                    this.rawInvolvementData = [...this.involvementData];
                    this.filteredInvolvementData = [...this.involvementData];

                    // Build unique involvement code picklist options (Name + Id)
                    const seen = new Map();
                    this.rawInvolvementData.forEach(r => {
                        const id = r.ucinn_ascendv2__Involvement_Code__c;
                        const name = r.ucinn_ascendv2__Involvement_Code__r?.Name || '';
                        if (id && !seen.has(id)) {
                            seen.set(id, name);
                        }
                    });
                    this.involvementCodeOptions = [
                        { label: '--None--', value: '' },
                        ...Array.from(seen.entries()).map(([id, name]) => ({
                            label: name,
                            value: id
                        }))
                    ];
                } else if (error) {
                    console.error(error);
                }
                    
            })
        }
    }

    disconnectedCallback() {
        window.removeEventListener('resize', this._resizeHandler);
    }

    checkScreen() {
        this.isMobile = window.innerWidth <= 768;
    }

    // Mobile-specific getters
    get mobileFilterIcon() {
        return this.showFilters ? 'utility:close' : 'utility:filterList';
    }

    get mobileAddIcon() {
        return this.showAddForm ? 'utility:close' : 'utility:add';
    }

    get mobileFilterLabel() {
        return this.showFilters ? 'Close Filters' : 'Filter';
    }

    get mobileAddLabel() {
        return this.showAddForm ? 'Cancel' : 'Add Activity';
    }

    // Computed properties
    // Pagination helpers for filtered dataset
    get totalPages() {
        return Math.ceil(this.filteredInvolvementData.length / this.itemsPerPage);
    }

    get paginatedActivities() {
        const startIndex = (this.currentPage - 1) * this.itemsPerPage;
        const endIndex = startIndex + this.itemsPerPage;
        return this.filteredInvolvementData.slice(startIndex, endIndex).map(activity => ({
            ...activity,
            representativeLink: activity.representativeId
                ? `/lightning/r/User/${activity.representativeId}/view`
                : undefined
        }));
    }

    get currentYear() {
        return new Date().getFullYear();
    }

    get lastYear() {
        return new Date().getFullYear() - 1;
    }

    get twoYearsAgo() {
        return new Date().getFullYear() - 2;
    }

   

    
    get showUpArrowCurrent() {
        return this.scoreTrend === 'up';
    }

    get showDownArrowCurrent() {
        return this.scoreTrend === 'down';
    }

    get showUpArrowLast() {
        return this.lastYearTrend === 'up';
    }

    get showDownArrowLast() {
        return this.lastYearTrend === 'down';
    }

    get quickTopChips() {
        return this.quickTopOptions.map(opt => ({
            ...opt,
            chipClass: opt.id === this.selectedQuickPickId
                ? 'quick-chip quick-chip_selected'
                : 'quick-chip'
        }));
    }

    get quickMoreChips() {
        return this.quickMoreOptions.map(opt => ({
            ...opt,
            chipClass: opt.id === this.selectedQuickPickId
                ? 'quick-chip quick-chip_selected'
                : 'quick-chip'
        }));
    }

    get hasMoreChips() {
        return this.quickMoreOptions.length > 0;
    }

    get showMoreLabel() {
        return this.showMoreChips
            ? 'Show less'
            : `Show more (${this.quickMoreOptions.length})`;
    }

    handleToggleMobileChips() {
        this.showMoreChips = !this.showMoreChips;
    }

    get expandIcon() {
        return this.isExpanded ? 'utility:chevronup' : 'utility:chevrondown';
    }

    get expandLabel() {
        return this.isExpanded ? 'Collapse' : 'Expand';
    }

    get formButtonLabel() {
        return this.showAddForm ? 'Cancel' : 'Add Activity';
    }

    get filtersButtonLabel() {
        return this.showFilters ? 'Close Filters' : 'Filter';
    }

    get isFirstPage() {
        return this.currentPage === 1;
    }

    get isLastPage() {
        return this.currentPage === this.totalPages;
    }

    get paginationInfo() {
        const total = this.filteredInvolvementData.length;
        if (total === 0) return 'Showing 0-0 of 0';
        const startIndex = (this.currentPage - 1) * this.itemsPerPage + 1;
        const endIndex = Math.min(this.currentPage * this.itemsPerPage, total);
        return `Showing ${startIndex}-${endIndex} of ${total}`;
    }

    // Event handlers
    handleToggleExpand() {
        this.isExpanded = !this.isExpanded;
    }

    handleToggleForm() {
        this.showAddForm = !this.showAddForm;
        if (this.showAddForm) {
            this.showEditForm = false;
            this.editRecordId = null;
            this.resetForm();
        }
        if (this.showAddForm && this.quickTopOptions.length === 0) {
            getQuickSelectCodes()
                .then(result => {
                    this.quickTopOptions  = (result.topCodes  || []).map(r => ({ id: r.Id, label: r.Name }));
                    this.quickMoreOptions = (result.moreCodes || []).map(r => ({ id: r.Id, label: r.Name }));
                })
                .catch(() => {});
        }
        if (this.showAddForm && this.descOptions.length === 0) {
            getInvolvementDescriptionValues()
                .then(result => { this.descOptions = result || []; })
                .catch(() => {});
        }
    }

    handleQuickSelect(event) {
        const id = event.currentTarget.dataset.id;
        if (this.selectedQuickPickId === id) {
            this.selectedQuickPickId = null;
            this.formData = { ...this.formData, involvementId: null };
            this.showInvolvementPicker = false;
            // eslint-disable-next-line @lwc/lwc/no-async-operation
            Promise.resolve().then(() => { this.showInvolvementPicker = true; });
        } else {
            this.selectedQuickPickId = id;
            this.formData = { ...this.formData, involvementId: id };
        }
    }

    handleSort(event) {
        const field = event.currentTarget.dataset.field;
        if (this.sortField === field) {
            this.sortDirection = this.sortDirection === 'asc' ? 'desc' : 'asc';
        } else {
            this.sortField = field;
            this.sortDirection = 'asc';
        }
        this.sortActivities();
    }

    sortActivities() {
        this.activities = [...this.activities].sort((a, b) => {
            let aVal = a[this.sortField];
            let bVal = b[this.sortField];
            
            if (this.sortField === 'startDate' || this.sortField === 'endDate') {
                aVal = new Date(aVal);
                bVal = new Date(bVal);
            }
            
            if (aVal < bVal) return this.sortDirection === 'asc' ? -1 : 1;
            if (aVal > bVal) return this.sortDirection === 'asc' ? 1 : -1;
            return 0;
        });
    }

    // Toggle filters section (button label: Filter / Close Filters)
    toggleFilters() {
        this.showFilters = !this.showFilters;
    }

    // Individual filter change handlers
    handleStartDateFilterChange(event) {
        this.filterStartDate = event.target.value;
    }

    handleEndDateFilterChange(event) {
        this.filterEndDate = event.target.value;
    }

    handleInvolvementCodeChange(event) {
        this.filterInvolvementCode = event.detail.value || '';
    }

    handleStatusFilterChange(event) {
        this.filterStatus = event.detail.value || '';
    }

    handleMinScoreChange(event) {
        this.filterMinScore = event.target.value;
    }

   applyFilters() {
        // 1️⃣ Show spinner immediately
        this.isFiltering = true;

        try {
            let rows = [...this.rawInvolvementData];

            const startFilter = this.filterStartDate || null;
            const endFilter = this.filterEndDate || null;
            const minScore = this.filterMinScore !== '' ? Number(this.filterMinScore) : null;

            // 2️⃣ DATE FILTER (dynamic)
            if (startFilter || endFilter) {
                rows = rows.filter(r => {
                    const start = r.Start_Date__c;
                    const end = r.End_Date__c;

                    // choose a date to evaluate
                    const dateToCheck = start || end;
                    if (!dateToCheck) return false;

                    if (startFilter && !endFilter) {
                        return dateToCheck >= startFilter;
                    }

                    if (!startFilter && endFilter) {
                        return dateToCheck <= endFilter;
                    }

                    return dateToCheck >= startFilter && dateToCheck <= endFilter;
                });
            }

            // 3️⃣ INVOLVEMENT CODE
            if (this.filterInvolvementCode) {
                rows = rows.filter(
                    r => r.ucinn_ascendv2__Involvement_Code__c === this.filterInvolvementCode
                );
            }

            // 4️⃣ STATUS
            if (this.filterStatus) {
                rows = rows.filter(
                    r => r.Status__c === this.filterStatus
                );
            }

            // 5️⃣ MINIMUM SCORE (>=)
            if (minScore !== null && !Number.isNaN(minScore)) {
                rows = rows.filter(
                    r => Number(r.HAM_CC_Score__c || 0) >= minScore
                );
            }

            // 6️⃣ Commit filtered data to datatable
            this.involvementData = rows;
            this.filteredInvolvementData = rows;

            // Reset pagination safely
            this.currentPage = 1;

        } finally {
            // 7️⃣ Stop spinner AFTER data mutation
            this.isFiltering = false;
        }
    }


    // Reset filters and show all
    resetFilters() {
        this.filterStartDate = '';
        this.filterEndDate = '';
        this.filterInvolvementCode = '';
        this.filterStatus = '';
        this.filterMinScore = '';

        this.involvementData = [...this.rawInvolvementData];
        this.filteredInvolvementData = [...this.rawInvolvementData];
        this.currentPage = 1;
    }

    handleInputChange(event) {
        const field = event.target.dataset.field;
        this.formData[field] = event.target.value;
    }

    handleAddActivity() {
        if (!this.formData.involvementId) {
            this.dispatchEvent(new ShowToastEvent({
                title: 'Involvement Code required',
                message: 'Please select an Involvement Code before saving.',
                variant: 'error'
            }));
            return;
        }

        this.isSaving = true;

        const newActivity = {
            recordid: this.recordId,
            startDate: this.formData.startDate,
            endDate: this.formData.endDate,
            involvmentCode: this.formData.involvementId,
            handshakeLink: this.formData.handshakeLink,
            representativeId: this.formData.assignedUserId,
            isAlumni: this.isAlumni,
            involvementDescription: this.formData.involvementDescription || ''
        };

        insertInvolvement({ payload: JSON.stringify(newActivity) })
            .then(result => {
                console.log('Involvement inserted successfully', result);
                
                // Update all the data from the response
                this.currentFiscalYear = result.currentFiscalYear;
                this.lastFiscalYear = result.lastFiscalYear;
                this.currentFiscalYearScore = result.currentYearScore;
                this.lastFiscalYearScore = result.lastYearScore;
                
                if (result.currentYearTrend) {
                    this.scoreTrend = 'up';
                } else {
                    this.scoreTrend = 'down';
                }
                
                if (result.lastYearTrend) {
                    this.lastYearTrend = 'up';
                } else {
                    this.lastYearTrend = 'down';
                }

                // Process the updated involvement data
                this.involvementData = [];
                if (result.ccInvolvments) {
                    this.involvementData = result.ccInvolvments.map(row => ({
                        ...row,
                        recordUrl: row.Id ? '/' + row.Id : null,
                        ownerName: row.Owner?.Name,
                        ownerLink: row.OwnerId ? '/' + row.OwnerId : null,
                        Involvement_Name__c: row.ucinn_ascendv2__Involvement_Code__r?.Name,
                        Involvement_Link__c: row.ucinn_ascendv2__Involvement_Code__c
                            ? '/' + row.ucinn_ascendv2__Involvement_Code__c
                            : null,
                        Account__c: row.ucinn_ascendv2__Account__c,
                        Status__c: row.ucinn_ascendv2__Status__c,
                        Involvement_Desc__c: row.ucinn_ascendv2__Involvement_Code_Description_Formula__c,
                        Start_Date__c: row.ucinn_ascendv2__Start_Date__c,
                        End_Date__c: row.ucinn_ascendv2__End_Date__c
                    }));

                    // Sort by Start Date in descending order (most recent first)
                    this.involvementData.sort((a, b) => {
                        const dateA = a.Start_Date__c ? new Date(a.Start_Date__c) : new Date(0);
                        const dateB = b.Start_Date__c ? new Date(b.Start_Date__c) : new Date(0);
                        return dateB - dateA; // Descending order
                    });

                    // Update raw and filtered datasets
                    this.rawInvolvementData = [...this.involvementData];
                    this.filteredInvolvementData = [...this.involvementData];

                    // Reset pagination to page 1
                    this.currentPage = 1;
                }

                this.resetForm();
                this.showAddForm = false;
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Activity saved',
                    message: 'Volunteer activity was created successfully.',
                    variant: 'success'
                }));
            })
            .catch(error => {
                console.error('Error saving involvement:', error);
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Error saving activity',
                    message: error?.body?.message || 'An unexpected error occurred.',
                    variant: 'error'
                }));
            })
            .finally(() => {
                this.isSaving = false;
            });
    }

    resetForm() {
        this.formData = {
            involvementId: null,
            assignedUserId: null,
            startDate: '',
            endDate: '',
            handshakeLink: '',
            involvementDescription: ''
        };
        this.selectedQuickPickId = null;
        this.showMoreChips = false;
        this.showDescDropdown = false;
        this.filteredDescOptions = [];
        this.descSearchTerm = '';
    }

    handlePageChange(event) {
        this.currentPage = parseInt(event.target.dataset.page);
    }

    handlePrevPage() {
        if (this.currentPage > 1) {
            this.currentPage--;
        }
    }

    handleNextPage() {
        if (this.currentPage < this.totalPages) {
            this.currentPage++;
        }
    }

    
    @wire(CurrentPageReference)
    getStateParameters(currentPageReference) {
        console.log('URL parameter----'+currentPageReference);
        this.isAlumni = false;
        if (currentPageReference && currentPageReference.state) {
            let param = currentPageReference.state.c__isAlumni;
            this.recordId = currentPageReference.state.c__recordId;
            console.log('Record ID:', this.recordId);
            if (param !== undefined) {
                // Convert string → boolean
                this.isAlumni = param === "true" || param === true;
            } else if (this.isAlumni === undefined) {
                this.isAlumni = true; // fallback default
            }
        }
    }

    handleInvolvementChange(event) {
        this.formData = { ...this.formData, involvementId: event.detail.recordId };
        this.selectedQuickPickId = null;
    }
    
    handleAssignmentChange(event) {
        this.formData.assignedUserId = event.detail.recordId;
    }

    // Edit functionality handlers
    handleRowAction(event) {
        const actionName = event.detail.action.name;
        const row = event.detail.row;
        
        if (actionName === 'edit') {
            // Store the record ID
            this.editRecordId = row.Id;
            
            // Load desc options if not yet loaded
            if (this.descOptions.length === 0) {
                getInvolvementDescriptionValues()
                    .then(result => { this.descOptions = result || []; })
                    .catch(() => {});
            }

            // Prepopulate form data
            this.formData = {
                involvementId: row.ucinn_ascendv2__Involvement_Code__c || null,
                assignedUserId: row.OwnerId || null,
                startDate: row.ucinn_ascendv2__Start_Date__c || '',
                endDate: row.ucinn_ascendv2__End_Date__c || '',
                handshakeLink: row.HAM_Handshake_Link__c || '',
                involvementDescription: row.ucinn_ascendv2__Involvement_Description__c || ''
            };
            this.descSearchTerm = this.formData.involvementDescription;
            
            // Show edit form, hide add form
            this.showEditForm = true;
            this.showAddForm = false;
        }
    }

    handleEditInputChange(event) {
        const field = event.target.dataset.field;
        this.formData[field] = event.target.value;
    }

    handleEditInvolvementChange(event) {
        this.formData.involvementId = event.detail.recordId;
    }

    handleEditAssignmentChange(event) {
        this.formData.assignedUserId = event.detail.recordId;
    }

    handleUpdateActivity() {
        this.isSaving = true;
        
        const updateData = {
            recordId: this.editRecordId,
            parentRecordId: this.recordId,
            startDate: this.formData.startDate,
            endDate: this.formData.endDate,
            involvmentCode: this.formData.involvementId,
            handshakeLink: this.formData.handshakeLink,
            representativeId: this.formData.assignedUserId,
            isAlumni: this.isAlumni,
            involvementDescription: this.formData.involvementDescription || ''
        };

        updateInvolvement({ payload: JSON.stringify(updateData) })
            .then(result => {
                console.log('Involvement updated successfully', result);
                
                // Update all the data from the response (same as handleAddActivity)
                this.currentFiscalYear = result.currentFiscalYear;
                this.lastFiscalYear = result.lastFiscalYear;
                this.currentFiscalYearScore = result.currentYearScore;
                this.lastFiscalYearScore = result.lastYearScore;
                
                if (result.currentYearTrend) {
                    this.scoreTrend = 'up';
                } else {
                    this.scoreTrend = 'down';
                }
                
                if (result.lastYearTrend) {
                    this.lastYearTrend = 'up';
                } else {
                    this.lastYearTrend = 'down';
                }

                // Process the updated involvement data
                this.involvementData = [];
                if (result.ccInvolvments) {
                    this.involvementData = result.ccInvolvments.map(row => ({
                        ...row,
                        recordUrl: row.Id ? '/' + row.Id : null,
                        ownerName: row.Owner?.Name,
                        ownerLink: row.OwnerId ? '/' + row.OwnerId : null,
                        Involvement_Name__c: row.ucinn_ascendv2__Involvement_Code__r?.Name,
                        Involvement_Link__c: row.ucinn_ascendv2__Involvement_Code__c
                            ? '/' + row.ucinn_ascendv2__Involvement_Code__c
                            : null,
                        Account__c: row.ucinn_ascendv2__Account__c,
                        Status__c: row.ucinn_ascendv2__Status__c,
                        Involvement_Desc__c: row.ucinn_ascendv2__Involvement_Code_Description_Formula__c,
                        Start_Date__c: row.ucinn_ascendv2__Start_Date__c,
                        End_Date__c: row.ucinn_ascendv2__End_Date__c
                    }));

                    // Sort by Start Date in descending order
                    this.involvementData.sort((a, b) => {
                        const dateA = a.Start_Date__c ? new Date(a.Start_Date__c) : new Date(0);
                        const dateB = b.Start_Date__c ? new Date(b.Start_Date__c) : new Date(0);
                        return dateB - dateA;
                    });

                    // Update raw and filtered datasets
                    this.rawInvolvementData = [...this.involvementData];
                    this.filteredInvolvementData = [...this.involvementData];

                    // Reset pagination to page 1
                    this.currentPage = 1;
                }

                this.handleCancelEdit();
            })
            .catch(error => {
                console.error('Error updating involvement:', error);
            })
            .finally(() => {
                this.isSaving = false;
            });
    }

    handleDescFocus() {
        if (this.descOptions.length === 0) return;
        const term = this.descSearchTerm;
        this.filteredDescOptions = term
            ? [...this.descOptions].filter(v => v.toLowerCase().includes(term.toLowerCase())).sort()
            : [...this.descOptions].sort();
        this.showDescDropdown = true;
    }

    handleDescInput(event) {
        this.descSearchTerm = event.target.value;
        this.formData = { ...this.formData, involvementDescription: this.descSearchTerm };
        const lower = this.descSearchTerm.toLowerCase();
        this.filteredDescOptions = this.descSearchTerm
            ? [...this.descOptions].filter(v => v.toLowerCase().includes(lower)).sort()
            : [...this.descOptions].sort();
        this.showDescDropdown = this.filteredDescOptions.length > 0;
    }

    handleDescSelect(event) {
        const val = event.currentTarget.dataset.value;
        this.descSearchTerm = val;
        this.formData = { ...this.formData, involvementDescription: val };
        this.showDescDropdown = false;
        this.filteredDescOptions = [];
    }

    handleDescDropdownMouseDown(event) {
        event.preventDefault();
        this._descMouseDown = true;
    }

    handleDescDropdownMouseUp() {
        this._descMouseDown = false;
    }

    handleDescBlur() {
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        setTimeout(() => {
            if (this._descMouseDown) return;
            this.showDescDropdown = false;
        }, 150);
    }

    handleCancelEdit() {
        this.showEditForm = false;
        this.editRecordId = null;
        this.resetForm();
    }
}