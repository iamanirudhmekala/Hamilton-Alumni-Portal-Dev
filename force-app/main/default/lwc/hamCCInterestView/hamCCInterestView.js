import { LightningElement, wire, track, api } from 'lwc';
import { CurrentPageReference } from 'lightning/navigation';
import { refreshApex } from '@salesforce/apex';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

import getMyFundingInterests from '@salesforce/apex/HAMCCInterestViewController.getMyFundingInterests';
import upsertFundingInterest from '@salesforce/apex/HAMCCInterestViewController.upsertFundingInterest';

export default class HamCCInterestView extends LightningElement {
    /* -------------------------
        DATA STATE
    -------------------------- */
    @track records = [];          // Full dataset
    @track pagedRecords = [];     // Records shown on current page
    @track recordsCount = 0;
    @api recordId;
    @api isAlumni = false;
    wiredResult;
    @track isSaving = false;

    /* -------------------------
        UI STATE
    -------------------------- */
    showForm = false;
    @track isExpanded = false; // mimic hamCCVolunteerEngagement pattern

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

    get mobileAddIcon() {
        return this.showForm ? 'utility:close' : 'utility:add';
    }

    get mobileAddLabel() {
        return this.showForm ? 'Close' : 'Add Interest';
    }

    get addButtonLabel() {
        return this.showForm ? 'Close' : 'Add Interest';
    }

    // Header expand/collapse icon (mimic hamCCVolunteerEngagement)
    get activeSectionIcon() {
        return this.isExpanded ? 'utility:chevrondown' : 'utility:chevronright';
    }

    // Toggle from header icon button
    handleAccordionToggle = () => {
        this.isExpanded = !this.isExpanded;
    };

    @track draftInterest = {
        // Picker to ucinn_ascendv2__Foundation_Funding_Interest__c
        ucinn_ascendv2__Foundation_Funding_Interests__c: '',
        // Funding Interest fields
        HAM_Category__c: '',
        ucinn_ascendv2__Start_Date__c: '',
        ucinn_ascendv2__End_Date__c: '',
        HAM_Activity__c: '',
        HAM_Interest_Notes__c: '',
        ownerId: ''
    };

    /* -------------------------
        Dropdown CONFIG
    -------------------------- */
    statusOptions = [
        { 
            value: "Conduct practice interviews", 
            label: "Conduct practice interviews", 
            description: "Conduct practice interviews" 
        },
        {
            value: "Host a job shadow or immersion trip",
            label: "Host a job shadow or immersion trip",
            description: "Host a job shadow or immersion trip",
        },
        {
            value: "Host or sponsor an event",
            label: "Host or sponsor an event",
            description: "Host or sponsor an event",
        },
        {
            value: "Recruit / hire Hamilton students / alumni for opportunities at your organization",
            label: "Recruit / hire Hamilton students / alumni for opportunities at your organization",
            description: "Recruit / hire Hamilton students / alumni for opportunities at your organization",
        },
        {
            value: "Speak at off-campus and/or virtual events",
            label: "Speak at off-campus and/or virtual events",
            description: "Speak at off-campus and/or virtual events",
        },
        {
            value: "Speak at on-campus events",
            label: "Speak at on-campus events",
            description: "Speak at on-campus events",
        }
    ];

    interestFilter = {
        criteria: [
            {
                fieldPath: 'HAM_Category__c',
                operator: 'eq',
                value: 'Career Center'
            }
        ]
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

    handleChange(event) {
        // Get the string of the "value" attribute on the selected option
        this.draftInterest.HAM_Activity__c = event.detail.value;
    }

    handleAssignmentChange(event) {
        this.draftInterest.ownerId = event.detail.recordId;
    }

    /* -------------------------
        TABLE CONFIG
    -------------------------- */
    columns = [
        {
            label: 'Name',
            fieldName: 'recordUrl',
            type: 'url',
            typeAttributes: {
                label: { fieldName: 'Name' },
                target: '_self'
            },
            sortable: true
        },
        {
            label: 'Foundation Funding Interest',
            fieldName: 'ffiUrl',
            type: 'url',
            typeAttributes: {
                label: { fieldName: 'ffiName' },
                target: '_self'
            },
            sortable: true
        },
        {
            label: 'Category',
            fieldName: 'HAM_Category__c',
            type: 'text',
            sortable: true
        },
        {
            label: 'Start Date (ET)',
            fieldName: 'startDateET',
            type: 'text',
            sortable: true
        },
        {
            label: 'End Date (ET)',
            fieldName: 'endDateET',
            type: 'text',
            sortable: true
        },
        {
            label: 'Activity',
            fieldName: 'HAM_Activity_Type__c',
            type: 'text',
            sortable: true
        },
        {
            label: 'Notes',
            fieldName: 'HAM_Interest_Notes__c',
            type: 'text',
            sortable: false,
            wrapText: true,
            initialWidth: 250
        }
    ];

    /* -------------------------
        PAGINATION STATE
    -------------------------- */
    @track currentPage = 1;
    pageSize = 5;
    @track sortedBy = 'startDateET';
    @track sortedDirection = 'desc';
    @track paginationInfo = {
        startIndex: 0,
        endIndex: 0
    };

    get totalPages() {
        return Math.ceil(this.recordsCount / this.pageSize);
    }

    get showPagination() {
        return this.recordsCount > this.pageSize;
    }

    get previousDisabled() {
        return this.currentPage === 1;
    }

    get nextDisabled() {
        return this.currentPage === this.totalPages;
    }

    get hasRecords() {
        return this.recordsCount > 0;
    }

    /* ---------------------------------
        Capture RecordId from URL
    ----------------------------------- */
    @wire(CurrentPageReference)
    getStateParameters(currentPageReference) {
        this.isAlumni = false;
       
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

    /* ---------------------------------
        Fetch Funding Interests
    ----------------------------------- */
    @wire(getMyFundingInterests, { recordId: '$recordId' , isAlumni :'$isAlumni'})
    wiredInterests(result) {
        this.isSaving = true;
        this.wiredResult = result;

        const { data, error } = result;
        if (data) {
            this.records = data.map(rec => ({
                ...rec,
                recordUrl: `/${rec.Id}`,
                ffiName: rec.ucinn_ascendv2__Foundation_Funding_Interest__r?.Name || '',
                ffiUrl: rec.ucinn_ascendv2__Foundation_Funding_Interest__c
                    ? `/${rec.ucinn_ascendv2__Foundation_Funding_Interest__c}`
                    : null,
                startDateET: this.formatToET(rec.ucinn_ascendv2__Start_Date__c),
                endDateET: this.formatToET(rec.ucinn_ascendv2__End_Date__c)
            }));

            this.recordsCount = this.records.length;
            this.currentPage = 1;

            if (this.recordsCount > 0) {
                this.isExpanded = true;
            } else {
                this.isExpanded = false;
            }

            this.updatePaginationInfo();
            this.isSaving = false;
        } else if (error) {
            this.records = [];
            this.isSaving = false;
            this.pagedRecords = [];
            this.recordsCount = 0;
            this.showToast('Error', 'Failed to load funding interests.', 'error');
        }
    }

    /* -------------------------
        PAGINATION HANDLERS
    -------------------------- */
    handlePrevious() {
        if (this.currentPage > 1) {
            this.currentPage--;
            this.updatePaginationInfo();
        }
    }

    handleNext() {
        if (this.currentPage < this.totalPages) {
            this.currentPage++;
            this.updatePaginationInfo();
        }
    }

    updatePaginationInfo() {
        const start = (this.currentPage - 1) * this.pageSize;
        const end = start + this.pageSize;

        this.pagedRecords = this.records.slice(start, end);

        this.paginationInfo = {
            startIndex: start + 1,
            endIndex: Math.min(end, this.recordsCount)
        };
    }

    /* -------------------------
        SORTING
    -------------------------- */
    handleSort(event) {
        const { fieldName, sortDirection } = event.detail;
        this.sortedBy = fieldName;
        this.sortedDirection = sortDirection;
        this.sortRecords(fieldName, sortDirection);
        this.currentPage = 1;
        this.updatePaginationInfo();
    }

    sortRecords(fieldName, direction) {
        // When sorting the Name URL column, sort by the actual Name value
        const key = fieldName === 'recordUrl' ? 'Name' : fieldName;
        this.records = [...this.records].sort((a, b) => {
            let aValue = a[key] ?? '';
            let bValue = b[key] ?? '';
            if (typeof aValue === 'string') {
                aValue = aValue.toLowerCase();
                bValue = bValue.toLowerCase();
            }
            return direction === 'asc'
                ? aValue > bValue ? 1 : -1
                : aValue < bValue ? 1 : -1;
        });
    }

    /* -------------------------
        MOBILE
    -------------------------- */
    get mobileSortOptions() {
        return [
            { label: 'Start Date', value: 'startDateET' },
            { label: 'End Date', value: 'endDateET' },
            { label: 'Name', value: 'Name' },
            { label: 'Foundation Funding Interest', value: 'ffiName' },
            { label: 'Activity', value: 'HAM_Activity_Type__c' }
        ];
    }

    get mobileSortDirectionIcon() {
        return this.sortedDirection === 'asc' ? 'utility:arrowup' : 'utility:arrowdown';
    }

    get mobileSortDirectionLabel() {
        return this.sortedDirection === 'asc' ? 'Ascending' : 'Descending';
    }

    handleMobileSortChange(event) {
        this.sortedBy = event.detail.value;
        this.sortRecords(this.sortedBy, this.sortedDirection);
        this.currentPage = 1;
        this.updatePaginationInfo();
    }

    toggleMobileSortDirection() {
        this.sortedDirection = this.sortedDirection === 'asc' ? 'desc' : 'asc';
        this.sortRecords(this.sortedBy, this.sortedDirection);
        this.currentPage = 1;
        this.updatePaginationInfo();
    }

    _expandedIds = new Set();

    toggleShowMore(event) {
        const id = event.currentTarget.dataset.id;
        if (this._expandedIds.has(id)) {
            this._expandedIds.delete(id);
        } else {
            this._expandedIds.add(id);
        }
        // Reassign pagedRecords to trigger mobilePageRecords getter recomputation
        this.updatePaginationInfo();
    }

    get mobilePageRecords() {
        const maxLen = 120;
        return this.pagedRecords.map(r => {
            const notes = r.HAM_Interest_Notes__c || '';
            const isExpanded = this._expandedIds.has(r.Id);
            const needsTruncation = notes.length > maxLen;
            return {
                ...r,
                displayNotes: isExpanded || !needsTruncation ? notes : notes.substring(0, maxLen) + '...',
                showMoreLabel: isExpanded ? 'Show Less' : 'Show More',
                needsTruncation
            };
        });
    }

    /* -------------------------
        FORM HANDLERS
    -------------------------- */
    handleAddClick() {
        this.showForm = !this.showForm;
        if (this.showForm) {
            this.isExpanded = true;
        }
    }

    handleCancel() {
        this.showForm = false;
        this.resetDraft();
    }

    async handleSave() {
       this.isSaving = true;
       // Build payload for Apex insert
        const payload = {
            recordId: this.recordId,              // String → DTO.recordId
            isAlumni: this.isAlumni,               // Boolean → DTO.isAlumni

            interestValue:
                this.draftInterest.ucinn_ascendv2__Foundation_Funding_Interests__c || null,

            category:
                this.draftInterest.HAM_Category__c || 'Career Center',

            startDate:
                this.draftInterest.ucinn_ascendv2__Start_Date__c
                    ? this.draftInterest.ucinn_ascendv2__Start_Date__c
                    : null,

            endDate:
                this.draftInterest.ucinn_ascendv2__End_Date__c
                    ? this.draftInterest.ucinn_ascendv2__End_Date__c
                    : null,

            activity:
                this.draftInterest.HAM_Activity__c || null,

            ownerId: this.draftInterest.ownerId || null,

            notes: this.draftInterest.HAM_Interest_Notes__c || null

        };

        try {
            await upsertFundingInterest({ fiParam: JSON.stringify(payload) });
            await refreshApex(this.wiredResult);
            this.showToast('Success', 'Funding interest saved successfully.', 'success');
        } catch (e) {
            this.showToast('Error', e?.body?.message || 'Failed to save funding interest.', 'error');
        } finally {
            this.isSaving = false;
            this.showForm = false;
            this.resetDraft();
        }
    }

    handleInputChange(event) {
        const field = event.target.dataset.field;
        if (!field) return;
        this.draftInterest = { ...this.draftInterest, [field]: event.target.value };
    }

    handleRecordPickerChange(event) {
        const field = event.target.dataset.field;
        if (!field) return;
        this.draftInterest.ucinn_ascendv2__Foundation_Funding_Interests__c = event.detail.recordId;
    }

    // No-op: standard accordion removed; using isExpanded pattern
    handleAccordionChange() {}

    resetDraft() {
        this.draftInterest = {
            ucinn_ascendv2__Foundation_Funding_Interests__c: null,
            HAM_Category__c: '',
            ucinn_ascendv2__Start_Date__c: '',
            ucinn_ascendv2__End_Date__c: '',
            HAM_Activity__c: '',
            HAM_Interest_Notes__c: '',
            ownerId: ''
        };
        this.template.querySelectorAll('lightning-record-picker').forEach(picker => {
            picker.clearSelection();
        });
    }

    /* -------------------------
        UTILS
    -------------------------- */
    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    formatToET(dateVal) {
        if (!dateVal) return '';
        return new Intl.DateTimeFormat('en-US', {
            timeZone: 'UTC',
            year: 'numeric',
            month: '2-digit',
            day: '2-digit'
        }).format(new Date(dateVal + 'T00:00:00Z'));
    }
}