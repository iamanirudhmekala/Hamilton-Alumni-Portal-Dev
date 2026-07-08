import { LightningElement, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';
import { refreshApex } from '@salesforce/apex';

// Imports from hAMJediSearchComponent
import searchContact from '@salesforce/apex/HAMJediSearchController.searchContact';
import getClassYearOptions from '@salesforce/apex/HAMJediSearchController.getClassYearOptions';
import getSportsAssociationOptions from '@salesforce/apex/HAMJediSearchController.getSportsAssociationOptions';
import getStudentOrganizationsOptions from '@salesforce/apex/HAMJediSearchController.getStudentOrganizationsOptions';

// Import from hAMRecentRecords (using HAMJediSearchController)
import getRecentRecords from '@salesforce/apex/HAMJediSearchController.searchRecentRecords';

// Import from hamMyProspects
import getMyProspects from '@salesforce/apex/HamMyProspectController.searchMyProspects';

export default class HamNewJEDISearch extends NavigationMixin(LightningElement) {
    @track activeTab = 'search';
    
    // =========================================
    // General State
    // =========================================
    @track loading = false;
    @track error;
    autoRefreshTimer;
    
    // =========================================
    // Constituent Search (from hAMJediSearchComponent)
    // =========================================
    @track constituentName = '';
    @track donorId = '';
    @track classYear = '';
    @track sportsAssociation = '';
    @track primaryOrganization = '';

    @track classYearOptions = [];
    @track sportsAssociationOptions = [];
    @track primaryOrganizationOptions = []; // Renamed from studentOrganizationOptions

    @track allConstituents = [];    // Full, sorted dataset
    @track pageConstituents = [];   // Current page rows for datatable
    @track sortBy;
    @track sortDirection;

    // Search datatable columns
    columns = [
        {
            label: 'Name',
            type: 'button',
            typeAttributes: {
                label: { fieldName: 'HAM_Name_w_Suffix__c' },
                name: 'view_prospect',
                variant: 'base',
                class: 'primary-text' // Added to match new UI style
            },
            cellAttributes: { class: { fieldName: 'primaryTextClass' } }
        },
        { 
            label: 'Donor Id', 
            fieldName: 'ucinn_ascendv2__Donor_ID__c', 
            type: 'Text', 
            sortable: true 
        },
        { 
            label: 'Primary Contact Type', 
            fieldName: 'ucinn_ascendv2__Primary_Contact_Type__c', 
            type: 'Text', 
            sortable: true 
        },
    ];

    // Pagination
    @track pageSize = 10;
    @track pageNumber = 1;
    @track totalRecords = 0;

    get totalPages() {
        return Math.max(1, Math.ceil(this.totalRecords / this.pageSize));
    }
    get isFirstPage() {
        return this.pageNumber <= 1;
    }
    get isLastPage() {
        return this.pageNumber >= this.totalPages || this.totalRecords === 0;
    }

    // =========================================
    // Recent Prospects (from hAMRecentRecords)
    // =========================================
    @track recentProspectsRecords = [];
    @track recentProspectsError;
    recentProspectsWiredResult;

    recentProspectsColumns = [
        {
            label: 'Name',
            fieldName: 'recordLink',
            type: 'url',
            sortable: true,
            typeAttributes: {
                label: { fieldName: 'HAM_Name_w_Suffix__c' },
                target: '_blank'
            },
            cellAttributes: { class: { fieldName: 'primaryTextClass' } }
        },
        { 
            label: 'Donor Id', 
            fieldName: 'ucinn_ascendv2__Donor_ID__c', 
            type: 'text', 
            sortable: true,
            cellAttributes: { class: 'slds-text-align_right' }
        }
    ];

    @wire(getRecentRecords)
    wiredRecentRecords(result) {
        this.recentProspectsWiredResult = result; // store for refresh
        const { data, error } = result;
        if (data) {
            this.recentProspectsRecords = data.map(row => ({
                ...row,
                recordLink: `/lightning/n/JEDI_Overview?c__recordId=${row.Id}`,
                primaryTextClass: 'primary-text' // Class for styling URL
            }));
            this.recentProspectsError = undefined;
        } else if (error) {
            this.recentProspectsError = error;
            this.recentProspectsRecords = [];
        }
    }

    // =========================================
    // My Prospects (from hamMyProspects)
    // =========================================
    @track myProspectsRecords = [];
    @track myProspectsError;

    myProspectsColumns = [
        {
            label: 'Name',
            fieldName: 'recordLink',
            type: 'url',
            typeAttributes: {
                label: { fieldName: 'HAM_Name_w_Suffix__c' },
                target: '_blank'
            },
            sortable: true,
            cellAttributes: { class: { fieldName: 'primaryTextClass' } }
        },
        {
            label: 'Preferred Chapter',
            fieldName: 'chapterLink',
            type: 'url',
            typeAttributes: {
                label: { fieldName: 'chapterName' },
                target: '_blank'
            },
            sortable: false
        },
        {
            label: 'Current Chapters',
            fieldName: 'HAM_Current_Chapters__c',
            type: 'text',
            sortable: false
        }
    ];

    @wire(getMyProspects)
    wiredMyProspects({ data, error }) {
        if (data) {
            this.myProspectsRecords = data.map(row => ({
                ...row,
                recordLink: `/lightning/n/JEDI_Overview?c__recordId=${row.Id}`,
                chapterLink: row.HAM_Preferred_Chapter_Lookup__c
                    ? `/lightning/r/${row.HAM_Preferred_Chapter_Lookup__c}/view`
                    : null,
                chapterName: row.HAM_Preferred_Chapter_Lookup__r?.Name || '—',
                primaryTextClass: 'primary-text' // Class for styling URL
            }));
            this.myProspectsError = undefined;
        } else if (error) {
            this.myProspectsError = error;
            this.myProspectsRecords = [];
        }
    }
    
    // =========================================
    // Lifecycle Hooks
    // =========================================
    connectedCallback() {
        // Load picklists from hAMJediSearchComponent
        this.loadClassYearOptions();
        this.loadSportsAssociationOptions();
        this.loadPrimaryOrganizationOptions(); // Renamed

        // Auto-refresh from hAMRecentRecords
        this.autoRefreshTimer = setInterval(() => {
            if (this.recentProspectsWiredResult) {
                refreshApex(this.recentProspectsWiredResult);
            }
        }, 1200000); // 20 minutes
    }

    disconnectedCallback() {
        // Stop timer from hAMRecentRecords
        clearInterval(this.autoRefreshTimer);
    }

    // =========================================
    // Picklist Loaders (from hAMJediSearchComponent)
    // =========================================
    loadClassYearOptions() {
        getClassYearOptions()
            .then((data) => {
                this.classYearOptions = [
                    { label: 'Select Class Year', value: '' },
                    ...data.map(year => ({ label: year, value: year }))
                ];
            })
            .catch((error) => this.showErrorToast('Error loading class year options'));
    }

    loadSportsAssociationOptions() {
        getSportsAssociationOptions()
            .then((data) => {
                this.sportsAssociationOptions = [
                    { label: 'Select Sports Association', value: '' },
                    ...data.map(sport => ({ label: sport, value: sport }))
                ];
            })
            .catch((error) => this.showErrorToast('Error loading sports association options'));
    }

    loadPrimaryOrganizationOptions() {
        getStudentOrganizationsOptions() // Using the original Apex method name
            .then((data) => {
                this.primaryOrganizationOptions = [
                    { label: 'Select Primary Organization', value: '' },
                    ...data.map(org => ({ label: org, value: org }))
                ];
            })
            .catch((error) => this.showErrorToast('Error loading primary organizations options'));
    }

    // =========================================
    // Event Handlers
    // =========================================
    handleTabSelect(event) {
        this.activeTab = event.target.value;
    }

    // Generic change handler for all inputs
    handleChange(event) {
        const fieldName = event.target.name;
        this[fieldName] = event.target.value;
    }

    // Clear handler (from hAMJediSearchComponent)
    handleClear() {
        this.constituentName = '';
        this.donorId = '';
        this.classYear = '';
        this.sportsAssociation = '';
        this.primaryOrganization = '';

        // Reset all data and pagination
        this.allConstituents = [];
        this.pageConstituents = [];
        this.totalRecords = 0;
        this.pageNumber = 1;
    }

    // Row action handler (from hAMJediSearchComponent)
    handleRowAction(event) {
        const actionName = event.detail.action.name;
        const row = event.detail.row;
        
        if (!row || !row.Id) return;

        if (actionName === 'view_prospect') {
            const recordId = row.Id;
            // Generate URL for JEDI_Overview
            this[NavigationMixin.GenerateUrl]({
                type: 'standard__navItemPage',
                attributes: { apiName: 'JEDI_Overview' },
                state: { c__recordId: recordId }
            }).then(url => {
                window.open(url, '_blank', 'noopener,noreferrer');
            }).catch(error => {
                console.error('Navigation error:', error);
                this.showErrorToast('Error navigating to prospect overview');
            });
        }
    }

    // =========================================
    // Search Logic (from hAMJediSearchComponent)
    // =========================================
    searchConstituents() {
        if (this.constituentName || this.donorId || this.classYear || this.sportsAssociation || this.primaryOrganization) {
            this.loading = true;
            searchContact({ 
                searchStr: this.constituentName, 
                donorId: this.donorId,
                classYear: this.classYear,
                sportsAssociation: this.sportsAssociation,
                studentOrganization: this.primaryOrganization // Mapping back to Apex param
            })
            .then((data) => {
                const rows = Array.isArray(data) ? data : [];
                
                this.allConstituents = rows.map(row => ({
                    ...row,
                    primaryTextClass: 'primary-text' // Class for styling URL
                }));

                this.totalRecords = this.allConstituents.length;
                this.pageNumber = 1;
                this.derivePage();

                if (this.totalRecords === 0) {
                    this.showNoDataToast();
                }
                this.error = undefined;
            })
            .catch((error) => {
                this.error = error;
                this.showErrorToast('Error during search: ' + error.body?.message || 'Unknown error');
                this.allConstituents = [];
                this.pageConstituents = [];
                this.totalRecords = 0;
                this.pageNumber = 1;
            })
            .finally(() => {
                this.loading = false;
            });
        } else {
            this.showErrorToast('Please enter at least one search criterion.');
        }
    }

    // =========================================
    // Pagination Logic (from hAMJediSearchComponent)
    // =========================================
    derivePage() {
        const start = (this.pageNumber - 1) * this.pageSize;
        const end = start + this.pageSize;
        this.pageConstituents = this.allConstituents.slice(start, end);
    }

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
    // Sort Logic (from hAMJediSearchComponent)
    // =========================================
    doSorting(event) {
        this.loading = true;
        this.sortBy = event.detail.fieldName;
        this.sortDirection = event.detail.sortDirection;
        
        this.sortData(this.sortBy, this.sortDirection);
        
        this.pageNumber = 1;
        this.derivePage();
        
        this.loading = false;
    }

    sortData(fieldname, direction) {
        const dir = direction === 'desc' ? -1 : 1;

        this.allConstituents = [...this.allConstituents].sort((a, b) => {
            const va = (a[fieldname] ?? '').toString().toLowerCase();
            const vb = (b[fieldname] ?? '').toString().toLowerCase();
            if (va === vb) return 0;
            return va > vb ? dir : -dir;
        });
    }

    // =========================================
    // Toast Utilities (from hAMJediSearchComponent)
    // =========================================
    showNoDataToast() {
        this.dispatchEvent(new ShowToastEvent({
            title: 'No Records Found',
            message: 'No constituent records were found for your criteria.',
            variant: 'info'
        }));
    }

    showErrorToast(message) {
        this.dispatchEvent(new ShowToastEvent({
            title: 'Error',
            message: message,
            variant: 'error'
        }));
    }

    handleCreateContactReport() {
        console.log('Create Contact Report');
    }

    handleCreateTask() {
        console.log('Create Task');
    }

    handleLogMeeting() {
        console.log('Log/Create Meeting');
    }

    handleSubmitAIS() {
        console.log('Submit AIS Request');
    }
}