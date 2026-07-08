import { LightningElement, api, wire, track } from 'lwc';
import { CurrentPageReference } from 'lightning/navigation';
import { refreshApex } from '@salesforce/apex';
import getEmployeeData from '@salesforce/apex/hamCCAlumniProfileController.getEmployeeData';

export default class hamCCEmployerBio extends LightningElement {

    @api recordId;

    @track accountData = {};
    @track relationshipData = [];
    @track taskData = [];
    @track careerBadges = [];
    @track error;
    @track isFlowOpen = false;

    wiredEmployeeResult;

    // Client-side pagination state for Open Tasks
    @track tasksAll = [];
    @track tasksPage = [];
    @track tasksPageIndex = 0;
    pageSourceSize = 10;
    renderSize = 5;

    isLoading = true;

    /* ---------------------------------
       Capture RecordId from URL (fallback when not passed via @api)
    -----------------------------------*/
    @wire(CurrentPageReference)
    getStateParameters(currentPageReference) {
        if (currentPageReference?.state?.c__recordId && !this.recordId) {
            this.recordId = currentPageReference.state.c__recordId;
        }
    }

    /* ---------------------------------
       Fetch Data
    -----------------------------------*/
    @wire(getEmployeeData, { recordId: '$recordId' })
    wiredEmployeeData(result) {
        this.wiredEmployeeResult = result;
        this.isLoading = false;
        const { error, data } = result;
        if (data) {
            this.processResult(data);
            this.error = undefined;
        } else if (error) {
            this.error = error;
            this.accountData = undefined;
        }
    }

    /* ---------------------------------
       Process Apex Result
    -----------------------------------*/
    processResult(result) {

        /* 1. Account Data */
        this.accountData = result.objOrgData;

        /* 2. Relationships */
        this.relationshipData = (result.orgRelations || []).map(rel => ({
            ...rel,
            recordUrl: `/lightning/r/Contact/${rel.id}/view`
        }));

        /* 3. Tasks */
        this.taskData = (result.openTasks || []).map(task => {
            console.log('Task===>', task);
            let badgeClass = '';

            switch (task.Priority) {
                case 'High':
                    badgeClass = 'slds-badge slds-theme_warning';
                    break;

                case 'Normal':
                    badgeClass = 'slds-badge slds-theme_info';
                    break;

                case 'Low':
                    badgeClass = 'slds-badge slds-theme_success';
                    break;

                default:
                    badgeClass = 'slds-badge';
            }

            return {
                ...task,
                badgeClass,
                recordUrl: `/lightning/r/Task/${task.Id}/view`
            };
        });

        // Initialize client-side pagination for tasks
        this.tasksAll = [...this.taskData];
        this.tasksPageIndex = 0;
        this.refreshTasksWindow();

        /* 4. Badges */
        this.careerBadges = (result.badges || []).map((badgeLabel, index) => {
            let badgeClass = '';

            switch (badgeLabel) {
                case 'Prospect':
                    badgeClass = 'slds-badge prospectBadge';
                    break;

                case 'Engaged':
                    badgeClass = 'slds-badge slds-theme_success engageBadge';
                    break;

                case 'Career Center Volunteer':
                    badgeClass = 'slds-badge slds-theme_warning ccVolunteerBadge';
                    break;

                case 'Impact Volunteer':
                    badgeClass = 'slds-badge slds-theme_info impactBadge';
                    break;

                default:
                    badgeClass = 'slds-badge';
            }

            return {
                id: `${index + 1}`,
                label: badgeLabel,
                badgeClass
            };
        });
    }

    /* ---------------------------------
       Flow Handlers
    -----------------------------------*/
    handleAddTask() {
        this.isFlowOpen = true;
    }

    handleFlowClose() {
        this.isFlowOpen = false;
    }

    handleFlowStatusChange(event) {
        const status = event.detail.status;
        if (status === 'FINISHED' || status === 'FINISHED_SCREEN') {
            this.isFlowOpen = false;
            refreshApex(this.wiredEmployeeResult);
        }
    }

    /* ---------------------------------
       Navigate to Contact Record
    -----------------------------------*/
    handleContactClick(event) {
        const contactId = event.currentTarget.dataset.contactId;
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: contactId,
                actionName: 'view'
            }
        });
    }

    // Client-side pagination for tasks helpers
    refreshTasksWindow() {
        const start = this.tasksPageIndex * this.pageSourceSize;
        const end = start + this.pageSourceSize;
        const windowSlice = this.tasksAll.slice(start, end);
        this.tasksPage = windowSlice.slice(0, this.renderSize);
    }
    
    get disablePrevTasks() {
        return this.tasksPageIndex === 0;
    }
    
    get disableNextTasks() {
        const nextStart = (this.tasksPageIndex + 1) * this.pageSourceSize;
        return nextStart >= this.tasksAll.length;
    }
    
    handlePrevTasks() {
        if (this.tasksPageIndex > 0) {
            this.tasksPageIndex -= 1;
            this.refreshTasksWindow();
        }
    }
    
    handleNextTasks() {
        const nextStart = (this.tasksPageIndex + 1) * this.pageSourceSize;
        if (nextStart < this.tasksAll.length) {
            this.tasksPageIndex += 1;
            this.refreshTasksWindow();
        }
    }
}