import { LightningElement, api, track, wire } from 'lwc';
import getAlumniData from '@salesforce/apex/hamCCAlumniProfileController.getAlumniData';
import { CurrentPageReference } from 'lightning/navigation';
import { NavigationMixin } from 'lightning/navigation';
// FIX 1: Import name corrected to camelCase for clarity; exposed as class property below
import VOLUNTEER_BADGE from '@salesforce/resourceUrl/HAMVolunteerBadge';

export default class HamCCAlumniBio extends NavigationMixin(LightningElement) {
    @api recordId;

    @track name = 'John Anderson';
    @track email = 'john.anderson@alumni.edu';
    @track phone = '(555) 123-4567';
    @track classYear = '2015';
    @track major = 'Computer Science';
    @track companyName = 'Tech Innovations Inc.';
    @track companyLink = '/lightning/r/Account/0011234567890ABC/view';
    @track industry = 'Technology';
    contactData = {};
    prmData = {};
    relationshipData = [];
    taskData = [];
    @track isVolunteer = false;

    // FIX 2: Expose static resource import as a class property so the template can bind to it.
    // The module-level import alone is NOT accessible in the template — it must be assigned here.
    volunteerBadgeUrl = VOLUNTEER_BADGE;

    // Client-side pagination state for Open Tasks
    @track tasksAll = [];
    @track tasksPage = [];
    @track tasksPageIndex = 0;
    pageSourceSize = 10;
    renderSize = 5;

    @track relationships = [
        { id: '1', name: 'Jennifer Williams', type: 'PRM' },
        { id: '2', name: 'Sarah Johnson', type: 'Mentor' },
        { id: '3', name: 'Dr. Michael Chen', type: 'Faculty Advisor' },
        { id: '4', name: 'Alumni Association', type: 'Member' }
    ];

    @track openTasks = [
        {
            id: '1',
            subject: 'Follow up on mentorship program',
            dueDate: '12/15/2024',
            priority: 'High',
            badgeClass: 'slds-badge slds-theme_warning'
        },
        {
            id: '2',
            subject: 'Schedule career workshop',
            dueDate: '12/20/2024',
            priority: 'Normal',
            badgeClass: 'slds-badge'
        },
        {
            id: '3',
            subject: 'Update contact information',
            dueDate: '12/10/2024',
            priority: 'Low',
            badgeClass: 'slds-badge slds-theme_info'
        }
    ];

    @track badges = [];
    @track isFlowOpen = false;

    // ─── Client-side pagination helpers ───────────────────────────────────────

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

    // ─── Task modal handlers ───────────────────────────────────────────────────

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
            this.refreshTasks();
        }
    }

    refreshTasks() {
        if (!this.recordId) return;
        getAlumniData({ recordId: this.recordId })
            .then(result => {
                const mappedTasks = (result.openTasks || []).map(task => {
                    let badgeClass = '';
                    switch (task.Priority) {
                        case 'High':   badgeClass = 'slds-badge slds-theme_warning'; break;
                        case 'Normal': badgeClass = 'slds-badge slds-theme_info';    break;
                        case 'Low':    badgeClass = 'slds-badge slds-theme_success'; break;
                        default:       badgeClass = 'slds-badge';
                    }
                    return { ...task, Id: task.Id, Subject: task.Subject, ActivityDate: task.ActivityDate, badgeClass };
                });
                this.taskData = mappedTasks;
                this.tasksAll = [...mappedTasks];
                this.tasksPageIndex = 0;
                this.refreshTasksWindow();
            })
            .catch(error => {
                console.error('Error refreshing tasks:', error);
            });
    }

    // ─── Navigation handlers ───────────────────────────────────────────────────

    handleRelationshipClick(event) {
        const li = event.currentTarget?.closest('li');
        const recId = li?.getAttribute('key') || li?.dataset?.id || event.currentTarget?.dataset?.id;
        if (recId) {
            this[NavigationMixin.Navigate]({
                type: 'standard__recordPage',
                attributes: { recordId: recId, actionName: 'view' }
            });
        }
    }

    handleTaskClick(event) {
        const recId = event.currentTarget?.dataset?.id;
        if (recId) {
            this[NavigationMixin.Navigate]({
                type: 'standard__recordPage',
                attributes: { recordId: recId, actionName: 'view' }
            });
        }
    }

    // ─── Lifecycle ─────────────────────────────────────────────────────────────

    connectedCallback() {
        if (this.recordId) {
            getAlumniData({ recordId: this.recordId })
                .then(result => {
                    this.contactData = result.objConstituentData;
                    this.major = result.major;
                    this.prmData = result.prmData;
                    this.relationshipData = result.orgRelations;
                    // Force the boolean to be explicitly present
                    this.isVolunteer = result.objConstituentData.Is_Volunteer__c === true;

                    // Map tasks and build badge class
                    const mappedTasks = (result.openTasks || []).map(task => {
                        let badgeClass = '';
                        switch (task.Priority) {
                            case 'High':   badgeClass = 'slds-badge slds-theme_warning'; break;
                            case 'Normal': badgeClass = 'slds-badge slds-theme_info';    break;
                            case 'Low':    badgeClass = 'slds-badge slds-theme_success'; break;
                            default:       badgeClass = 'slds-badge';
                        }
                        return {
                            ...task,
                            Id: task.Id,
                            Subject: task.Subject,
                            ActivityDate: task.ActivityDate,
                            badgeClass
                        };
                    });
                    this.taskData = mappedTasks;

                    // Initialize client-side pagination
                    this.tasksAll = [...mappedTasks];
                    this.tasksPageIndex = 0;
                    this.refreshTasksWindow();

                    // Map engagement badges
                    this.badges = result.badges.map((badgeLabel, index) => {
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
                })
                .catch(error => {
                    console.error('Error fetching Prospect:', error);
                });
        }
    }

    @wire(CurrentPageReference)
    getStateParameters(currentPageReference) {
        if (currentPageReference) {
            this.recordId = currentPageReference.state.c__recordId;
        }
    }
}