import { LightningElement, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';
import { refreshApex } from '@salesforce/apex';

// ==============================
// Apex Imports
// ==============================
import searchContact from '@salesforce/apex/HAMJediSearchController.searchContact';
import getClassYearOptions from '@salesforce/apex/HAMJediSearchController.getClassYearOptions';
import getSportsAssociationOptions from '@salesforce/apex/HAMJediSearchController.getSportsAssociationOptions';
import getStudentOrganizationsOptions from '@salesforce/apex/HAMJediSearchController.getStudentOrganizationsOptions';
import getRecentRecords from '@salesforce/apex/HAMJediSearchController.searchRecentRecords';
import getMyProspects from '@salesforce/apex/HamMyProspectController.searchMyProspects';
import getEmployerEngagementData from '@salesforce/apex/HamCCEmployeerPipelineReviewCtr.getEmployerEngagementData';
import getAssignedRecords from '@salesforce/apex/HAMJediSearchController.getAssignedRecords';

export default class hamCCSearch extends NavigationMixin(LightningElement) {

    // =========================================
    // Feedback Form
    // =========================================
    openFeedbackForm() {
        window.open('https://form.asana.com/?k=GUeiDwPKU5LkTTeHDW1niQ&d=940410193405385', '_blank');
    }

    // =========================================
    // Core UI State
    // =========================================
    @track activeTab = 'search';
    @track loading = false;
    @track error;
    autoRefreshTimer;

    // ── NEW: tracks whether the dashboard child component should mount ──────
    // Uses a flag instead of relying solely on activeTab so the component
    // is only created on first visit and stays alive on subsequent tab switches,
    // avoiding unnecessary re-queries and chart re-renders.
    @track isDashboardTabActive = false;

    // ── UPDATED: tab change handler (was handleTabSelect in sandbox) ─────────
    // lightning-tabset fires onselect; event.detail.value carries the tab value.
    handleTabChange(event) {
        this.activeTab = event.detail.value;
        if (this.activeTab === 'volunteerDashboard') {
            this.isDashboardTabActive = true;
        }
    }

    // =========================================
    // Quick Search (Record Picker)
    // =========================================
    @track selectedContactId = null;

    contactDisplayInfo = {
        primaryField: 'HAM_Name_w_Suffix__c',
        additionalFields: ['ucinn_ascendv2__Donor_ID__c']
    };

    contactMatchingInfo = {
        primaryField: { fieldPath: 'HAM_Name_w_Suffix__c' },
        additionalFields: [{ fieldPath: 'ucinn_ascendv2__Donor_ID__c' }]
    };

    handleContactRecordPickerChange(event) {
        this.selectedContactId = event.detail.recordId;
        if (this.selectedContactId) {
            this[NavigationMixin.GenerateUrl]({
                type: 'standard__navItemPage',
                attributes: { apiName: 'JABBA_Profile' },
                state: { c__recordId: this.selectedContactId, c__isAlumni: true }
            }).then(url => window.open(url, '_blank')).catch(error => {
                console.error('Navigation error:', error);
            });
            this.selectedContactId = null;
        }
    }

    // =========================================
    // Search Form Fields
    // =========================================
    @track constituentName = '';
    @track donorId = '';
    @track classYear = '';
    @track sportsAssociation = '';
    @track primaryOrganization = '';

    @track classYearOptions = [];
    @track sportsAssociationOptions = [];
    @track primaryOrganizationOptions = [];

    // =========================================
    // Search Results
    // =========================================
    @track allConstituents = [];
    @track pageConstituents = [];
    @track sortBy;
    @track sortDirection;

    searchColumns = [
        {
            label: 'Name',
            fieldName: 'HAM_Name_w_Suffix__c',
            type: 'button',
            typeAttributes: {
                label: { fieldName: 'HAM_Name_w_Suffix__c' },
                name: 'view_prospect',
                variant: 'base'
            },
            sortable: true,
            cellAttributes: { class: { fieldName: 'primaryTextClass' } }
        },
        { label: 'Donor Id', fieldName: 'ucinn_ascendv2__Donor_ID__c', type: 'text', sortable: true },
        { label: 'Primary Contact Type', fieldName: 'ucinn_ascendv2__Primary_Contact_Type__c', type: 'text', sortable: true }
    ];

    @track pageSize = 10;
    @track pageNumber = 1;
    @track totalRecords = 0;

    get totalPages() { return Math.max(1, Math.ceil(this.totalRecords / this.pageSize)); }
    get isFirstPage() { return this.pageNumber <= 1; }
    get isLastPage() { return this.pageNumber >= this.totalPages || this.totalRecords === 0; }

    // =========================================
    // Recent Constituents
    // =========================================
    @track recentProspectsRecords = [];
    recentProspectsWiredResult;
    @track recentProspectsError;
    @track recentSortBy;
    @track recentSortDirection;

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
        console.log('Recent Contact ------', result);
        if (data) {
            this.recentProspectsRecords = data.map(r => ({
                ...r,
                recordLink: `/lightning/n/JABBA_Profile?c__recordId=${r.Id}&c__isAlumni=true`,
                primaryTextClass: 'primary-text'
            }));
        } else if (error) {
            this.recentProspectsError = error;
            this.recentProspectsRecords = [];
        }
    }

    // =========================================
    // My Prospects
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
    // Lifecycle
    // =========================================
    connectedCallback() {
        this.loadClassYearOptions();
        this.loadSportsAssociationOptions();
        this.loadPrimaryOrganizationOptions();

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
    // Picklist Loaders
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
    // Input Event Handlers
    // =========================================
    handleChange(event) {
        const field = event.target.name;
        this[field] = event.target.value;
        console.log('Field: ' + field + ', Value: ' + this[field]);
        console.log('this.constituentName = ' + this.constituentName);
        console.log('this.donorId = ' + this.donorId);
        console.log('this.classYear = ' + this.classYear);
        console.log('this.sportsAssociation = ' + this.sportsAssociation);
        console.log('this.primaryOrganization = ' + this.primaryOrganization);
    }

    handleKeyUp(event) {
        if (event.keyCode === 13 || event.key === 'Enter') {
            this.searchConstituents();
        }
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
    // Search Logic
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
                console.log('Records------' + this.allConstituents);
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
    // Pagination Logic
    // =========================================
    derivePage() {
        const start = (this.pageNumber - 1) * this.pageSize;
        this.pageConstituents = this.allConstituents.slice(start, start + this.pageSize);
        console.log('Records------' + this.pageConstituents);
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
    // Sorting
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
    // Row Action
    // =========================================
    handleRowAction(event) {
        const actionName = event.detail.action.name;
        const row = event.detail.row;
        if (actionName === 'view_prospect' && row?.Id) {
            this[NavigationMixin.GenerateUrl]({
                type: 'standard__navItemPage',
                attributes: { apiName: 'JABBA_Profile' },
                state: { c__recordId: row.Id, c__isAlumni: true }
            }).then(url => window.open(url, '_blank'));
        }
    }

    // =========================================
    // Employer Impact Chart + Table
    // =========================================
    @track showEmployersTable = false;
    @track selectedCategory = '';
    @track selectedAccountId = null;

    @track employersPageData = [];
    @track employerPageNumber = 1;
    @track employerPageSize = 10;
    @track employerTotalRecords = 0;
    @track employerFilterText = '';
    @track employerSortBy = '';
    @track employerSortDirection = 'asc';

    allEmployersInCategory = [];

    chartData = [];
    employersByCategory = {};

    accountDisplayInfo = { primaryField: 'Name' };
    accountMatchingInfo = { primaryField: { fieldPath: 'Name' } };
    accountFilter = {
        criteria: [
            { fieldPath: 'HAM_Is_Career_Center_Org__c', operator: 'eq', value: true }
        ]
    };

    employersColumns = [
        {
            label: 'Name',
            fieldName: 'accountUrl',
            type: 'url',
            sortable: true,
            typeAttributes: { label: { fieldName: 'Name' }, target: '_blank' }
        },
        { label: 'Donor ID', fieldName: 'ucinn_ascendv2__Donor_ID__c', type: 'text', sortable: true },
        { label: 'Primary Contact', fieldName: 'primaryContactName', type: 'text', sortable: true },
        { label: 'Account Number', fieldName: 'AccountNumber', type: 'text', sortable: true },
        { label: 'Type', fieldName: 'Type', type: 'text', sortable: true },
        { label: 'Industry', fieldName: 'Industry', type: 'text', sortable: true }
    ];

    employerData = {};

    @wire(getEmployerEngagementData)
    wiredEmployerRecords({ data, error }) {
        this.employerData = data;
        console.log('Employeer Data----', data);
        if (data) {
            console.log('Employeer Data--Assigned--', this.employerData);
            this.chartData = this.employerData.chartData;
            const transformedMap = {};
            const categoryMap = this.employerData.barData;
            for (const category in categoryMap) {
                transformedMap[category] = categoryMap[category].map(acc => ({
                    ...acc,
                    primaryContactName: acc.ucinn_ascendv2__Primary_Contact__r?.Name || '',
                    primaryContactUrl: acc.ucinn_ascendv2__Primary_Contact__c
                        ? '/lightning/r/' + acc.ucinn_ascendv2__Primary_Contact__c + '/view'
                        : '',
                    accountUrl: '/lightning/n/JABBA_Profile?c__recordId=' + acc.Id + '&c__isAlumni=FALSE'
                }));
            }
            this.employersByCategory = transformedMap;
        } else if (error) {
            this.recentProspectsError = error;
            return this.showErrorToast(error?.body?.message || 'Employer Data Capture failed.');
        }
    }

    get filteredEmployers() {
        const term = this.employerFilterText.toLowerCase().trim();
        let list = term
            ? this.allEmployersInCategory.filter(e =>
                (e.Name || '').toLowerCase().includes(term) ||
                (e.ucinn_ascendv2__Donor_ID__c || '').toLowerCase().includes(term) ||
                (e.primaryContactName || '').toLowerCase().includes(term)
              )
            : [...this.allEmployersInCategory];
        if (this.employerSortBy) {
            const dir = this.employerSortDirection === 'desc' ? -1 : 1;
            const field = this.employerSortBy;
            list = list.sort((a, b) => {
                const valA = (a[field] || '').toString().toLowerCase();
                const valB = (b[field] || '').toString().toLowerCase();
                return valA > valB ? dir : valA < valB ? -dir : 0;
            });
        }
        return list;
    }

    get employerTotalPages() { return Math.max(1, Math.ceil(this.employerTotalRecords / this.employerPageSize)); }
    get isFirstEmployerPage() { return this.employerPageNumber <= 1; }
    get isLastEmployerPage() { return this.employerPageNumber >= this.employerTotalPages; }

    deriveEmployerPage() {
        const filtered = this.filteredEmployers;
        this.employerTotalRecords = filtered.length;
        const start = (this.employerPageNumber - 1) * this.employerPageSize;
        this.employersPageData = filtered.slice(start, start + this.employerPageSize);
    }

    handleEmployerFilter(event) {
        this.employerFilterText = event.target.value;
        this.employerPageNumber = 1;
        this.deriveEmployerPage();
    }

    handleEmployerSort(event) {
        const { fieldName, sortDirection } = event.detail;
        this.employerSortBy = fieldName;
        this.employerSortDirection = sortDirection;
        this.employerPageNumber = 1;
        this.deriveEmployerPage();
    }

    nextEmployerPage() {
        if (!this.isLastEmployerPage) { this.employerPageNumber++; this.deriveEmployerPage(); }
    }

    prevEmployerPage() {
        if (!this.isFirstEmployerPage) { this.employerPageNumber--; this.deriveEmployerPage(); }
    }

    handleAccountRecordPickerChange(event) {
        this.selectedAccountId = event.detail.recordId;
        if (this.selectedAccountId) {
            this.navigateToEmployerProfile(this.selectedAccountId);
            this.selectedAccountId = null;
        }
    }

    navigateToEmployerProfile(accountId) {
        this[NavigationMixin.GenerateUrl]({
            type: 'standard__navItemPage',
            attributes: { apiName: 'JABBA_Profile' },
            state: { c__recordId: accountId, c__isAlumni: 'FALSE' }
        }).then(url => { window.open(url, '_blank'); }).catch(error => { console.error('Navigation error:', error); });
    }

    handleBarClick(event) {
        const category = event.currentTarget.dataset.category;
        this.selectedCategory = category;
        this.allEmployersInCategory = this.employersByCategory[category] || [];
        this.employerFilterText = '';
        this.employerSortBy = '';
        this.employerSortDirection = 'asc';
        this.employerPageNumber = 1;
        this.loading = true;
        this.deriveEmployerPage();
        this.showEmployersTable = true;
        this.loading = false;
    }

    handleCloseTable() {
        this.showEmployersTable = false;
        this.selectedCategory = '';
        this.allEmployersInCategory = [];
        this.employersPageData = [];
        this.employerTotalRecords = 0;
        this.employerPageNumber = 1;
        this.employerFilterText = '';
        this.employerSortBy = '';
        this.employerSortDirection = 'asc';
    }

    handleEmployerClick(event) {
        const row = event.detail.row;
        console.log('Row Data------' + row);
        const accountId = row?.Id || row?.accountId;
        if (!accountId) return;
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: { recordId: accountId, objectApiName: 'Account', actionName: 'view' }
        });
    }

    // =========================================
    // Toast Helpers
    // =========================================
    showErrorToast(message) {
        this.dispatchEvent(new ShowToastEvent({ title: 'Error', message, variant: 'error' }));
    }

    showInfoToast(message) {
        this.dispatchEvent(new ShowToastEvent({ title: 'Info', message, variant: 'info' }));
    }

    // =========================================
    // Recent Constituents Sorting
    // =========================================
    handleRecentSort(event) {
        const { fieldName, sortDirection } = event.detail;
        this.recentSortBy = fieldName;
        this.recentSortDirection = sortDirection;
        const dir = sortDirection === 'desc' ? -1 : 1;
        this.recentProspectsRecords = [...this.recentProspectsRecords].sort((a, b) => {
            let valA = (a[fieldName] || '').toString().toLowerCase();
            let valB = (b[fieldName] || '').toString().toLowerCase();
            if (fieldName === 'recordLink') {
                valA = (a.HAM_Name_w_Suffix__c || '').toString().toLowerCase();
                valB = (b.HAM_Name_w_Suffix__c || '').toString().toLowerCase();
            }
            return valA > valB ? dir : valA < valB ? -dir : 0;
        });
    }

    // =========================================
    // Assigned Constituents & Organizations
    // =========================================
    @track assignedConstituents = [];
    @track assignedOrganizations = [];
    @track assignedError;

    @track assignedConstituentsSortBy = 'recordLink';
    @track assignedConstituentsSortDirection = 'asc';
    @track assignedOrganizationsSortBy = 'recordLink';
    @track assignedOrganizationsSortDirection = 'asc';

    @track constituentsPageNumber = 1;
    constituentsPageSize = 10;
    @track organizationsPageNumber = 1;
    organizationsPageSize = 10;

    @track isConstituentsExpanded = true;
    @track isOrganizationsExpanded = true;

    assignedConstituentsColumns = [
        {
            label: 'Name',
            fieldName: 'recordLink',
            type: 'url',
            sortable: true,
            typeAttributes: { label: { fieldName: 'assignmentName' }, target: '_blank' }
        },
        { label: 'Reunion Year', fieldName: 'reunionYear', type: 'text', sortable: true }
    ];

    assignedOrganizationsColumns = [
        {
            label: 'Name',
            fieldName: 'recordLink',
            type: 'url',
            sortable: true,
            typeAttributes: { label: { fieldName: 'assignmentName' }, target: '_blank' }
        },
        { label: 'Engagement Level', fieldName: 'EngagementLevel', type: 'text', sortable: true }
    ];

    @wire(getAssignedRecords)
    wiredAssignedRecords({ data, error }) {
        if (data) {
            const constituents = [];
            const organizations = [];
            data.forEach(assignment => {
                let displayName = '';
                if (assignment.ContactId) {
                    displayName = assignment.ContactNameWithSuffix || assignment.ContactName;
                    constituents.push({
                        ...assignment,
                        assignmentName: displayName,
                        recordLink: `/lightning/n/JABBA_Profile?c__recordId=${assignment.ContactId}&c__isAlumni=true`,
                        reunionYear: assignment.ContactReunionYear || ''
                    });
                } else if (assignment.AccountId) {
                    displayName = assignment.AccountName;
                    organizations.push({
                        ...assignment,
                        assignmentName: displayName,
                        recordLink: `/lightning/n/JABBA_Profile?c__recordId=${assignment.AccountId}&c__isAlumni=FALSE`,
                        EngagementLevel: assignment.EngagementLevel || 'Prospect'
                    });
                }
            });
            constituents.sort((a, b) => {
                const nameA = (a.assignmentName || '').toLowerCase();
                const nameB = (b.assignmentName || '').toLowerCase();
                return nameA > nameB ? 1 : nameA < nameB ? -1 : 0;
            });
            organizations.sort((a, b) => {
                const nameA = (a.assignmentName || '').toLowerCase();
                const nameB = (b.assignmentName || '').toLowerCase();
                return nameA > nameB ? 1 : nameA < nameB ? -1 : 0;
            });
            this.assignedConstituents = constituents;
            this.assignedOrganizations = organizations;
            console.log('Assigned Constituents:', this.assignedConstituents);
            console.log('Assigned Organizations:', this.assignedOrganizations);
        } else if (error) {
            this.assignedError = error;
            console.error('Error fetching assigned records:', error);
        }
    }

    handleAssignedConstituentsSort(event) {
        const { fieldName, sortDirection } = event.detail;
        this.assignedConstituentsSortBy = fieldName;
        this.assignedConstituentsSortDirection = sortDirection;
        const sortField = fieldName === 'recordLink' ? 'assignmentName' : fieldName;
        this.assignedConstituents = [...this.assignedConstituents].sort((a, b) => {
            const dir = sortDirection === 'asc' ? 1 : -1;
            let valA = a[sortField] == null ? '' : a[sortField];
            let valB = b[sortField] == null ? '' : b[sortField];
            if (typeof valA === 'string') valA = valA.toLowerCase();
            if (typeof valB === 'string') valB = valB.toLowerCase();
            return valA > valB ? dir : valA < valB ? -dir : 0;
        });
    }

    handleAssignedOrganizationsSort(event) {
        const { fieldName, sortDirection } = event.detail;
        this.assignedOrganizationsSortBy = fieldName;
        this.assignedOrganizationsSortDirection = sortDirection;
        const sortField = fieldName === 'recordLink' ? 'assignmentName' : fieldName;
        this.assignedOrganizations = [...this.assignedOrganizations].sort((a, b) => {
            const dir = sortDirection === 'asc' ? 1 : -1;
            let valA = a[sortField] == null ? '' : a[sortField];
            let valB = b[sortField] == null ? '' : b[sortField];
            if (typeof valA === 'string') valA = valA.toLowerCase();
            if (typeof valB === 'string') valB = valB.toLowerCase();
            return valA > valB ? dir : valA < valB ? -dir : 0;
        });
    }

    // Pagination: Assigned Constituents
    get constituentsTotalRecords() { return this.assignedConstituents ? this.assignedConstituents.length : 0; }
    get constituentsTotalPages() { return Math.ceil(this.constituentsTotalRecords / this.constituentsPageSize); }
    get constituentsPageData() {
        if (!this.assignedConstituents || this.assignedConstituents.length === 0) return [];
        const start = (this.constituentsPageNumber - 1) * this.constituentsPageSize;
        return this.assignedConstituents.slice(start, start + this.constituentsPageSize);
    }
    get isFirstConstituentsPage() { return this.constituentsPageNumber === 1; }
    get isLastConstituentsPage() { return this.constituentsPageNumber >= this.constituentsTotalPages; }
    get showConstituentsPagination() { return this.constituentsTotalRecords > 10; }
    get constituentsRecordLabel() { return this.constituentsTotalRecords === 1 ? 'record' : 'records'; }
    get constituentsPaginationClass() {
        return this.showConstituentsPagination ? 'slds-text-align_center slds-m-top_x-small' : 'slds-text-align_center';
    }
    prevConstituentsPage() { if (this.constituentsPageNumber > 1) this.constituentsPageNumber--; }
    nextConstituentsPage() { if (this.constituentsPageNumber < this.constituentsTotalPages) this.constituentsPageNumber++; }

    // Pagination: Assigned Organizations
    get organizationsTotalRecords() { return this.assignedOrganizations ? this.assignedOrganizations.length : 0; }
    get organizationsTotalPages() { return Math.ceil(this.organizationsTotalRecords / this.organizationsPageSize); }
    get organizationsPageData() {
        if (!this.assignedOrganizations || this.assignedOrganizations.length === 0) return [];
        const start = (this.organizationsPageNumber - 1) * this.organizationsPageSize;
        return this.assignedOrganizations.slice(start, start + this.organizationsPageSize);
    }
    get isFirstOrganizationsPage() { return this.organizationsPageNumber === 1; }
    get isLastOrganizationsPage() { return this.organizationsPageNumber >= this.organizationsTotalPages; }
    get showOrganizationsPagination() { return this.organizationsTotalRecords > 10; }
    get organizationsRecordLabel() { return this.organizationsTotalRecords === 1 ? 'record' : 'records'; }
    get organizationsPaginationClass() {
        return this.showOrganizationsPagination ? 'slds-text-align_center slds-m-top_x-small' : 'slds-text-align_center';
    }
    prevOrganizationsPage() { if (this.organizationsPageNumber > 1) this.organizationsPageNumber--; }
    nextOrganizationsPage() { if (this.organizationsPageNumber < this.organizationsTotalPages) this.organizationsPageNumber++; }

    // Expand/Collapse
    get constituentsExpandIcon() { return this.isConstituentsExpanded ? 'utility:chevronup' : 'utility:chevrondown'; }
    get constituentsExpandLabel() { return this.isConstituentsExpanded ? 'Collapse' : 'Expand'; }
    get organizationsExpandIcon() { return this.isOrganizationsExpanded ? 'utility:chevronup' : 'utility:chevrondown'; }
    get organizationsExpandLabel() { return this.isOrganizationsExpanded ? 'Collapse' : 'Expand'; }
    handleToggleConstituents() { this.isConstituentsExpanded = !this.isConstituentsExpanded; }
    handleToggleOrganizations() { this.isOrganizationsExpanded = !this.isOrganizationsExpanded; }
}