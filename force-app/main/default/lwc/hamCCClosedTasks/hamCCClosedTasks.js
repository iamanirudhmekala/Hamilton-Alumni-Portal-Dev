import { api, LightningElement, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { CurrentPageReference } from 'lightning/navigation';
import getClosedTasks from '@salesforce/apex/HamCCClosedTasksController.getClosedTasks';

export default class HamCCClosedTasks extends LightningElement {
    @api recordId;
    @api isAlumni;

    // Accordion state
    isExpanded = true;

    // Filter state
    showFilters = false;
    filterStartDate = '';
    filterEndDate = '';
    filterPriority = '';
    priorityOptions = [
        { label: 'All', value: '' },
        { label: 'High', value: 'High' },
        { label: 'Normal', value: 'Normal' },
        { label: 'Low', value: 'Low' }
    ];

    // Icon getter for header toggle
    get accordionIconName() {
        return this.isExpanded ? 'utility:chevrondown' : 'utility:chevronright';
    }

    // Summary stats
    @api totalClosedTasks = 0;
    @api closedTasksLastMonth = 0;

    // Track all data and paginated data
    @api allTasks = [];
    @api filteredTasks = []; // Tasks after filtering
    @api pagedTasks = [];
    @api recordsCount = 0;
    @api currentPage = 1;
    pageSize = 10;
    @api sortedBy = 'activityDate';
    @api sortedDirection = 'desc';

columns = [
        { 
            label: 'Subject', 
            fieldName: 'subjectUrl', 
            type: 'url',
            typeAttributes: {
                label: { fieldName: 'subject' },
                target: '_blank'
            },
            sortable: true
        },
        { label: 'Comments', fieldName: 'description', type: 'text', sortable: true },
        { label: 'Status', fieldName: 'status', type: 'text', sortable: true },
        { label: 'Priority', fieldName: 'priority', type: 'text', sortable: true },
        { label: 'Activity Date', fieldName: 'activityDate', type: 'date', typeAttributes: { timeZone: 'UTC' }, sortable: true }
    ];

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

@wire(getClosedTasks, { recordId: '$recordId', isAlumni: '$isAlumni' })
    wiredClosedTasks(result) {
        const { data, error } = result;
        console.log('Results---Task--', result);
        if (data) {
            console.log('Data---Task--', data);
            this.allTasks = data.map(task => {
                
                // Create URL for subject to navigate to task record
                const subjectUrl = task.Id ? `/lightning/r/Task/${task.Id}/view` : null;
                
                return {
                    id: task.Id,
                    subject: task.Subject,
                    subjectUrl: subjectUrl,
                    status: task.Status,
                    activityDate: task.ActivityDate,
                    description: task.Description,
                    priority: task.Priority
                };
            });
            this.totalClosedTasks = this.allTasks.length;
            this.calculateClosedTasksLastMonth();
            this.filteredTasks = [...this.allTasks]; // Initially show all tasks
            this.recordsCount = this.filteredTasks.length;
            this.currentPage = 1;
            this.updatePaginationInfo();
        } else if (error) {
            console.error('Error loading tasks', error);
            this.allTasks = [];
            this.totalClosedTasks = 0;
            this.closedTasksLastMonth = 0;
            this.filteredTasks = [];
            this.recordsCount = 0;
            this.pagedTasks = [];
        }
    }

    get closedTasksData() {
        return this.pagedTasks;
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

    // Calculate tasks closed in the last month
    calculateClosedTasksLastMonth() {
        const today = new Date();
        const oneMonthAgo = new Date();
        oneMonthAgo.setMonth(oneMonthAgo.getMonth() - 1);
        
        this.closedTasksLastMonth = this.allTasks.filter(task => {
            if (!task.activityDate) return false;
            const taskDate = new Date(task.activityDate);
            return taskDate >= oneMonthAgo && taskDate <= today;
        }).length;
    }

    handleRefresh() {
        // Refresh logic would go here - the wire adapter will automatically refresh when recordId or isAlumni changes
    }

    handleRowSelection(event) {
        const selectedRows = event.detail.selectedRows;
        if (selectedRows && selectedRows.length > 0) {
            const selectedTaskId = selectedRows[0].id;
            this[NavigationMixin.Navigate]({
                type: 'standard__recordPage',
                attributes: {
                    recordId: selectedTaskId,
                    actionName: 'view'
                }
            });
        }
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

    updatePaginationInfo() {
        const start = (this.currentPage - 1) * this.pageSize;
        const end = start + this.pageSize;

        // Sort the data before pagination
        let sortedTasks = [...this.filteredTasks];
        if (this.sortedBy && this.sortedDirection) {
            sortedTasks = sortedTasks.sort((a, b) => {
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

        this.pagedTasks = sortedTasks.slice(start, end);
    }

    handleSort(event) {
        const { fieldName, sortDirection } = event.detail;

        this.sortedBy = fieldName;
        this.sortedDirection = sortDirection;

        this.currentPage = 1;
        this.updatePaginationInfo();
    }

    // Accordion toggle handler (matches HAMCCInterestView pattern)
    handleAccordionToggle() {
        this.isExpanded = !this.isExpanded;
    }

    // Filter handlers
    handleFiltersToggle() {
        this.showFilters = !this.showFilters;
    }

    handleStartDateChange(event) {
        this.filterStartDate = event.detail.value;
    }

    handleEndDateChange(event) {
        this.filterEndDate = event.detail.value;
    }

    handlePriorityChange(event) {
        this.filterPriority = event.detail.value;
    }

    handleSearchFilters() {
        // Apply filters to the data
        this.filteredTasks = this.allTasks.filter(task => {
            // Date filtering logic
            let dateMatch = true;
            if (this.filterStartDate || this.filterEndDate) {
                const taskDate = new Date(task.activityDate);
                if (this.filterStartDate && taskDate < new Date(this.filterStartDate)) {
                    dateMatch = false;
                }
                if (this.filterEndDate && taskDate > new Date(this.filterEndDate)) {
                    dateMatch = false;
                }
            }
            
            // Priority filtering logic
            let priorityMatch = true;
            if (this.filterPriority && task.priority !== this.filterPriority) {
                priorityMatch = false;
            }
            
            return dateMatch && priorityMatch;
        });
        
        this.recordsCount = this.filteredTasks.length;
        this.currentPage = 1;
        this.updatePaginationInfo();
    }

    handleClearFilters() {
        this.filterStartDate = '';
        this.filterEndDate = '';
        this.filterPriority = '';
        this.filteredTasks = [...this.allTasks];
        this.recordsCount = this.filteredTasks.length;
        this.currentPage = 1;
        this.updatePaginationInfo();
    }
}