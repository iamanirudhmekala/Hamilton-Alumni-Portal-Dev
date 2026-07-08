import { LightningElement, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';
import { refreshApex } from '@salesforce/apex';

// ==============================
// Apex Imports (Existing Component)
// ==============================
import searchContact from '@salesforce/apex/HAMJediSearchController.searchContact';
import getClassYearOptions from '@salesforce/apex/HAMJediSearchController.getClassYearOptions';
import getSportsAssociationOptions from '@salesforce/apex/HAMJediSearchController.getSportsAssociationOptions';
import getStudentOrganizationsOptions from '@salesforce/apex/HAMJediSearchController.getStudentOrganizationsOptions';
import getRecentRecords from '@salesforce/apex/HAMJediSearchController.searchRecentRecords';
import getMyProspects from '@salesforce/apex/HamMyProspectController.searchMyProspects';
import getEmployerEngagementData from '@salesforce/apex/HamCCEmployeerPipelineReviewCtr.getEmployerEngagementData';

export default class hamCCVolunteerIndicator extends NavigationMixin(LightningElement) {

    // =========================================
    // Core UI State (Merged)
    // =========================================
    @track activeTab = 'search';
    @track loading = false;
    @track error;
    autoRefreshTimer;

    // =========================================
    // Search Form Fields (Matching Fields)
    // =========================================
    @track constituentName = '';
    @track donorId = '';
    @track classYear = '';
    @track sportsAssociation = '';
    @track primaryOrganization = '';

    // Picklist Options (from Apex)
    @track classYearOptions = [];
    @track sportsAssociationOptions = [];
    @track primaryOrganizationOptions = [];

    // =========================================
    // Search Results (Existing Logic)
    // =========================================
    @track allConstituents = [];
    @track pageConstituents = [];
    @track sortBy;
    @track sortDirection;

    searchColumns = [
        {
            label: 'Name',
            type: 'button',
            typeAttributes: {
                label: { fieldName: 'HAM_Name_w_Suffix__c' },
                name: 'view_prospect',
                variant: 'base'
            },
            cellAttributes: { class: { fieldName: 'primaryTextClass' } }
        },
        { label: 'Donor Id', fieldName: 'ucinn_ascendv2__Donor_ID__c', type: 'text', sortable: true },
        { label: 'Primary Contact Type', fieldName: 'ucinn_ascendv2__Primary_Contact_Type__c', type: 'text', sortable: true }
    ];

    // Pagination
    @track pageSize = 10;
    @track pageNumber = 1;
    @track totalRecords = 0;

    get totalPages() { return Math.max(1, Math.ceil(this.totalRecords / this.pageSize)); }
    get isFirstPage() { return this.pageNumber <= 1; }
    get isLastPage() { return this.pageNumber >= this.totalPages || this.totalRecords === 0; }

    // =========================================
    // Recent Constituents (Existing Logic)
    // =========================================
    @track recentProspectsRecords = [];
    recentProspectsWiredResult;
    @track recentProspectsError;

    recentProspectsColumns = [
        {
            label: 'Name',
            fieldName: 'recordLink',
            type: 'url',
            sortable: true,
            typeAttributes: { label: { fieldName: 'HAM_Name_w_Suffix__c' }, target: '_blank' },
            cellAttributes: { class: { fieldName: 'primaryTextClass' } }
        },
        { label: 'Donor Id', fieldName: 'ucinn_ascendv2__Donor_ID__c', type: 'text', sortable: true }
    ];

    @wire(getRecentRecords)
    wiredRecentRecords(result) {
        this.recentProspectsWiredResult = result;
        const { data, error } = result;
        console.log('Recent Contact ------',result);
        if (data) {
            this.recentProspectsRecords = data.map(r => ({
                ...r,
                recordLink: `/lightning/n/JABBA_Profile?c__recordId=${r.Id}`,
                primaryTextClass: 'primary-text'
            }));
        } else if (error) {
            this.recentProspectsError = error;
            this.recentProspectsRecords = [];
        }
    }

    // =========================================
    // My Prospects (Existing Logic)
    // =========================================
    @track myProspectsRecords = [];
    @track myProspectsError;

    myProspectsColumns = [
        {
            label: 'Name',
            fieldName: 'recordLink',
            type: 'url',
            typeAttributes: { label: { fieldName: 'HAM_Name_w_Suffix__c' }, target: '_blank' },
            cellAttributes: { class: { fieldName: 'primaryTextClass' } }
        },
        {
            label: 'Preferred Chapter',
            fieldName: 'chapterLink',
            type: 'url',
            typeAttributes: { label: { fieldName: 'chapterName' }, target: '_blank' }
        },
        { label: 'Current Chapters', fieldName: 'HAM_Current_Chapters__c', type: 'text' }
    ];

    @wire(getMyProspects)
    wiredMyProspects({ data, error }) {
        if (data) {
            this.myProspectsRecords = data.map(r => ({
                ...r,
                recordLink: `/lightning/n/JABBA_Profile?c__recordId=${r.Id}&c__isAlumni=true`,
                chapterLink: r.HAM_Preferred_Chapter_Lookup__c
                    ? `/lightning/r/${r.HAM_Preferred_Chapter_Lookup__c}/view`
                    : null,
                chapterName: r.HAM_Preferred_Chapter_Lookup__r?.Name || '—',
                primaryTextClass: 'primary-text'
            }));
        } else {
            this.myProspectsError = error;
        }
    }

    // =========================================
    // Lifecycle (Existing)
    // =========================================
    connectedCallback() {
        this.loadClassYearOptions();
        this.loadSportsAssociationOptions();
        this.loadPrimaryOrganizationOptions();

        // Auto-refresh recent records every 20 min
        this.autoRefreshTimer = setInterval(() => {
            if (this.recentProspectsWiredResult) {
                refreshApex(this.recentProspectsWiredResult);
            }
        }, 1200000);
    }

    disconnectedCallback() {
        clearInterval(this.autoRefreshTimer);
    }

    // =========================================
    // Picklist Loaders (Existing)
    // =========================================
    loadClassYearOptions() {
        getClassYearOptions().then(data => {
            this.classYearOptions = [
                { label: 'Select Class Year', value: '' },
                ...data.map(v => ({ label: v, value: v }))
            ];
        });
    }

    loadSportsAssociationOptions() {
        getSportsAssociationOptions().then(data => {
            this.sportsAssociationOptions = [
                { label: 'Select Sports Association', value: '' },
                ...data.map(v => ({ label: v, value: v }))
            ];
        });
    }

    loadPrimaryOrganizationOptions() {
        getStudentOrganizationsOptions().then(data => {
            this.primaryOrganizationOptions = [
                { label: 'Select Primary Organization', value: '' },
                ...data.map(v => ({ label: v, value: v }))
            ];
        });
    }

    // =========================================
    // Input Event Handlers (Merged)
    // =========================================
    handleTabSelect(event) {
        this.activeTab = event.target.value;
    }

    handleChange(event) {
        const field = event.target.name;
        this[field] = event.target.value;
        console.log('Field: ' + field + ', Value: ' + this[field] );
        console.log('this.constituentName = ' + this.constituentName);
        console.log('this.donorId = ' + this.donorId);
        console.log('this.classYear = ' + this.classYear);
        console.log('this.sportsAssociation = ' + this.sportsAssociation);
        console.log('this.primaryOrganization = ' + this.primaryOrganization);
    }

    handleClear() {
        this.constituentName = '';
        this.donorId = '';
        this.classYear = '';
        this.sportsAssociation = '';
        this.primaryOrganization = '';
        this.allConstituents = [];
        this.pageConstituents = [];
        this.totalRecords = 0;
    }

    // =========================================
    // Search Logic (Existing)
    // =========================================
    searchConstituents() {
        console.log('this.constituentName = ' + this.constituentName);
        console.log('this.donorId = ' + this.donorId);
        console.log('this.classYear = ' + this.classYear);
        console.log('this.sportsAssociation = ' + this.sportsAssociation);
        console.log('this.primaryOrganization = ' + this.primaryOrganization);
        if (!this.constituentName && !this.donorId && !this.classYear &&
            !this.sportsAssociation && !this.primaryOrganization) {
                console.log('No search criteria provided.');
            return this.showErrorToast('Please enter at least one search criterion.');
        }
        console.log('In Search Method');
        this.loading = true;
        searchContact({
            searchStr: this.constituentName,
            donorId: this.donorId,
            classYear: this.classYear,
            sportsAssociation: this.sportsAssociation,
            studentOrganization: this.primaryOrganization
        })
            .then(rows => {
                console.log('Results fetched:');
                this.allConstituents = (rows || []).map(r => ({
                    ...r,
                    primaryTextClass: 'primary-text'
                }));
                console.log('Records------'+ this.allConstituents);
                this.totalRecords = this.allConstituents.length;
                this.pageNumber = 1;
                this.derivePage();

                if (!this.totalRecords) {
                    this.showInfoToast('No constituent records were found.');
                }
            })
            .catch(error => {
                this.showErrorToast(error?.body?.message || 'Search failed.');
            })
            .finally(() => (this.loading = false));
    }

    // =========================================
    // Pagination Logic (Existing)
    // =========================================
    derivePage() {
        const start = (this.pageNumber - 1) * this.pageSize;
        this.pageConstituents = this.allConstituents.slice(start, start + this.pageSize);
        console.log('Records------'+this.pageConstituents);
        console.log('this.totalRecords = ' + this.totalRecords);
        console.log('this.pageNumber = ' + this.pageNumber);
    }

    nextPage() {
        if (!this.isLastPage) {
            this.pageNumber++;
            this.derivePage();
        }
    }

    prevPage() {
        if (!this.isFirstPage) {
            this.pageNumber--;
            this.derivePage();
        }
    }

    // =========================================
    // Sorting (Existing)
    // =========================================
    doSorting(event) {
        const { fieldName, sortDirection } = event.detail;
        this.sortBy = fieldName;
        this.sortDirection = sortDirection;

        const dir = sortDirection === 'desc' ? -1 : 1;

        this.allConstituents.sort((a, b) => {
            const valA = (a[fieldName] || '').toString().toLowerCase();
            const valB = (b[fieldName] || '').toString().toLowerCase();
            return valA > valB ? dir : valA < valB ? -dir : 0;
        });

        this.pageNumber = 1;
        this.derivePage();
    }

    // =========================================
    // Row Action (Existing)
    // =========================================
    handleRowAction(event) {
        const actionName = event.detail.action.name;
        const row = event.detail.row;

        if (actionName === 'view_prospect' && row?.Id) {
            this[NavigationMixin.GenerateUrl]({
                type: 'standard__navItemPage',
                attributes: { apiName: 'JABBA_Profile' },
                state: { c__recordId: row.Id, c__isAlumni:true }
            }).then(url => window.open(url, '_blank'));
        }
    }

    // =========================================
    // NEW FEATURES (Added but Not Mixed)
    // Employer Impact Chart + Table
    // =========================================
    @track showEmployersTable = false;
    @track selectedCategory = '';
    @track employersData = [];

    // Example placeholders to be wired later
    chartData = [];
    employersByCategory = {};
    employersColumns = [
    {
        label: 'Name',
        fieldName: 'accountUrl',
        type: 'url',
        typeAttributes: {
            label: { fieldName: 'Name' },
            target: '_blank'
        }
    },
    {
        label: 'Donor ID',
        fieldName: 'ucinn_ascendv2__Donor_ID__c',
        type: 'text'
    },
    {
        label: 'Primary Contact',
        fieldName: 'primaryContactName',
        type: 'text'
    },
    {
        label: 'Account Number',
        fieldName: 'AccountNumber',
        type: 'text'
    },
    {
        label: 'Type',
        fieldName: 'Type',
        type: 'text'
    },
    {
        label: 'Industry',
        fieldName: 'Industry',
        type: 'text'
    }
];
    employerData = {};

    @wire(getEmployerEngagementData)
    wiredEmployerRecords({ data, error }) {
        this.employerData = data;
         console.log('Employeer Data----',data);
        if(data){
            console.log('Employeer Data--Assigned--',this.employerData);
            this.chartData = this.employerData.chartData;
            // Transform the map (Prospect, Engaged, etc.)
            const transformedMap = {};

            const categoryMap = this.employerData.barData; // existing backend map

            for (const category in categoryMap) {
                transformedMap[category] = categoryMap[category].map(acc => ({
                    ...acc,
                    primaryContactName: acc.ucinn_ascendv2__Primary_Contact__r?.Name || '',
                    primaryContactUrl: acc.ucinn_ascendv2__Primary_Contact__c
                        ? '/lightning/r/' + acc.ucinn_ascendv2__Primary_Contact__c+'/view'
                        : '',
                    accountUrl: '/lightning/n/JABBA_Profile?c__recordId=' + acc.Id+'&c__isAlumni=FALSE'
                }));
            } 
            this.employersByCategory = transformedMap;
        }else if (error) {
            this.recentProspectsError = error;
            return this.showErrorToast(error?.body?.message || 'Employer Data Capture failed.');
        }
    }

    handleBarClick(event) {
        const category = event.currentTarget.dataset.category;
        this.selectedCategory = category;
        this.employersData = this.employersByCategory[category] || [];
        this.showEmployersTable = true;
    }

    handleCloseTable() {
        this.showEmployersTable = false;
        this.selectedCategory = '';
        this.employersData = [];
    }

    handleEmployerClick(event) {
        const row = event.detail.row;
        console.log('Row Data------'+row);
        const accountId = row?.accountId;
        if (!accountId) return;

        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: accountId,
                objectApiName: 'Account',
                actionName: 'view'
            }
        });
    }

    // =========================================
    // Toast Helpers
    // =========================================
    showErrorToast(message) {
        this.dispatchEvent(
            new ShowToastEvent({ title: 'Error', message, variant: 'error' })
        );
    }

    showInfoToast(message) {
        this.dispatchEvent(
            new ShowToastEvent({ title: 'Info', message, variant: 'info' })
        );
    }

    
}