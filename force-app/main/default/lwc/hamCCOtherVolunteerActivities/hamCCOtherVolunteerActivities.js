import { api, LightningElement, wire, track } from 'lwc';
import { CurrentPageReference } from 'lightning/navigation';
import getVolunteerActivities from '@salesforce/apex/HamCCOtherVolunteerActivitiesController.getVolunteerActivities';

export default class HamCCOtherVolunteerActivities extends LightningElement {
    @api recordId;
    @api isAlumni;
    @track isExpanded = false; // Will be set based on data presence

    // Mobile detection
    @track isMobile = false;

    // Pagination and sorting properties
    @track currentPage = 1;
    @track pageSize = 5;
    @track sortedBy = 'startDate';
    @track sortedDirection = 'desc';
    @track allVolunteerActivities = [];
    @track pagedVolunteerActivities = [];
    @track recordsCount = 0;
    @track currentInvolvementsCount = 0;
    @track formerInvolvementsCount = 0;

    // Columns for the table with links
    columns = [
        { 
            label: 'Involvement Code', 
            fieldName: 'involvementCodeLink', 
            type: 'url',
            typeAttributes: {
                label: { fieldName: 'involvementCode' },
                target: '_blank'
            },
            sortable: true
        },
        //{ label: 'Role', fieldName: 'role', type: 'text', sortable: true },
        { label: 'Start Date', fieldName: 'startDate', type: 'date', sortable: true },
        { label: 'End Date', fieldName: 'endDate', type: 'date', sortable: true },
        { label: 'Status', fieldName: 'status', type: 'text', sortable: true },
        { label: 'Category', fieldName: 'category', type: 'text', sortable: true }
    ];

    // Lifecycle methods for mobile detection
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

    // Mobile-specific getters
    get mobileSortOptions() {
        return [
            { label: 'Start Date', value: 'startDate' },
            { label: 'End Date', value: 'endDate' },
            { label: 'Involvement Code', value: 'involvementCodeLink' },
            { label: 'Status', value: 'status' },
            { label: 'Category', value: 'category' }
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
        this.currentPage = 1;
        this.updatePaginationInfo();
    }

    toggleMobileSortDirection() {
        this.sortedDirection = this.sortedDirection === 'asc' ? 'desc' : 'asc';
        this.currentPage = 1;
        this.updatePaginationInfo();
    }

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

    @wire(getVolunteerActivities, { recordId: '$recordId', isAlumni: '$isAlumni' })
    wiredVolunteerActivities({ error, data }) {
        if (data) {
            // Process data to add record links and other fields
            const processedData = data.volunteerActivities.map(activity => {
                return {
                    id: activity.Id,
                    involvementCode: activity.ucinn_ascendv2__Involvement_Code__r?.Name || activity.ucinn_ascendv2__Involvement_Code__c || 'N/A',
                    involvementCodeLink: activity.ucinn_ascendv2__Involvement_Code__c ? '/' + activity.ucinn_ascendv2__Involvement_Code__c : null,
                    role: activity.ucinn_ascendv2__Role__c,
                    startDate: activity.ucinn_ascendv2__Start_Date__c,
                    endDate: activity.ucinn_ascendv2__End_Date__c,
                    status: activity.ucinn_ascendv2__Status__c,
                    category: activity.HAM_Category__c || 'N/A'
                };
            });
            this.allVolunteerActivities = processedData;
            this.recordsCount = this.allVolunteerActivities.length;
            this.currentPage = 1;
            this.updatePaginationInfo();
            // Set expanded state based on data presence
            this.isExpanded = this.recordsCount > 0;
            // Store the counts for potential use elsewhere
            this.currentInvolvementsCount = data.currentInvolvementsCount || 0;
            this.formerInvolvementsCount = data.formerInvolvementsCount || 0;
        } else if (error) {
            console.error('Error loading volunteer activities:', error);
            this.allVolunteerActivities = [];
            this.recordsCount = 0;
            this.pagedVolunteerActivities = [];
        }
    }

    get hasData() {
        return this.recordsCount > 0;
    }

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

    get paginationInfo() {
        const start = (this.currentPage - 1) * this.pageSize;
        const end = start + this.pageSize;
        return {
            startIndex: start + 1,
            endIndex: Math.min(end, this.recordsCount)
        };
    }

    updatePaginationInfo() {
        const start = (this.currentPage - 1) * this.pageSize;
        const end = start + this.pageSize;

        // Sort the data before pagination
        let sortedActivities = [...this.allVolunteerActivities];
        if (this.sortedBy && this.sortedDirection) {
            sortedActivities = sortedActivities.sort((a, b) => {
                let aValue = a[this.sortedBy] ?? '';
                let bValue = b[this.sortedBy] ?? '';

                if (typeof aValue === 'string') {
                    aValue = aValue.toLowerCase();
                    bValue = bValue.toLowerCase();
                }

                return this.sortedDirection === 'asc'
                    ? aValue > bValue ? 1 : -1
                    : aValue < bValue ? 1 : -1;
            });
        }

        this.pagedVolunteerActivities = sortedActivities.slice(start, end);
    }

    sortVolunteerActivities(field, direction) {
        const key = field === 'involvementCodeLink' ? 'involvementCode' : field; // sort by name when link column is clicked
        const dir = direction === 'desc' ? -1 : 1;

        this.allVolunteerActivities = [...this.allVolunteerActivities].sort((a, b) => {
            const va = (a[key] ?? '').toString().toLowerCase();
            const vb = (b[key] ?? '').toString().toLowerCase();
            if (va === vb) return 0;
            return va > vb ? dir : -dir;
        });
    }

    handleSort(event) {
        const { fieldName, sortDirection } = event.detail;

        this.sortedBy = fieldName;
        this.sortedDirection = sortDirection;

        this.currentPage = 1;
        this.updatePaginationInfo();
    }

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

    handleToggleExpand() {
        this.isExpanded = !this.isExpanded;
    }

    get expandIcon() {
        return this.isExpanded ? 'utility:chevronup' : 'utility:chevrondown';
    }

    get expandLabel() {
        return this.isExpanded ? 'Collapse' : 'Expand';
    }
}