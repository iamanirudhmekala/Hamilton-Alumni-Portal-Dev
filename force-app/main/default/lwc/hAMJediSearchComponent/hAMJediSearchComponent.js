// 05/06/2026 NVV: ASC-13502 Mobile: hide Donor ID search input; results show Name column only
import { LightningElement, track } from 'lwc';
import searchContact from '@salesforce/apex/HAMJediSearchController.searchContact';
import getClassYearOptions from '@salesforce/apex/HAMJediSearchController.getClassYearOptions';
import getSportsAssociationOptions from '@salesforce/apex/HAMJediSearchController.getSportsAssociationOptions';
import getStudentOrganizationsOptions from '@salesforce/apex/HAMJediSearchController.getStudentOrganizationsOptions';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';

export default class hAMJediSearchComponent extends NavigationMixin(LightningElement) {
    // =========================================
    // Responsive flag
    // =========================================
    @track isMobile = false;

    // =========================================
    // Search inputs
    // =========================================
    @track nameSearchString = '';
    @track donorIdStr = '';
    @track loading = false;
    @track selectedContactId = null;

    // =========================================
    // Data model
    // =========================================
    @track allConstituents = [];      // full, sorted dataset; pagination slices from here
    @track pageConstituents = [];     // current page rows bound to the datatable

    // =========================================
    // Sorting state
    // =========================================
    @track sortBy;
    @track sortDirection;

    // =========================================
    // Picklist options - Options arrays from Apex
    // =========================================
    @track classYearOptions = [];          // Class Year values from HAM_Reunion_Year__c
    @track sportsAssociationOptions = [];  // Sports Association from Involvement_Value__c (NCAA Athletics)
    @track studentOrganizationOptions = []; // Student Organizations from Involvement_Value__c (Clubs & Societies)

    // =========================================
    // Picklist selected values
    // =========================================
    @track selectedClassYear = '';         // Selected Class Year value
    @track selectedSportsAssociation = ''; // Selected Sports Association value
    @track selectedStudentOrganization = ''; // Selected Student Organization value

    // =========================================
    // Pagination (grouped here intentionally)
    // =========================================
    @track pageSize = 10;     // rows per page
    @track pageNumber = 1;    // 1-based index
    @track totalRecords = 0;  // derived from allConstituents.length

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

    // Compute current page slice from allConstituents → pageConstituents
    derivePage() {
        const start = (this.pageNumber - 1) * this.pageSize;
        const end = start + this.pageSize;
        this.pageConstituents = this.allConstituents.slice(start, end);
    }

    // Handlers for footer buttons
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

    // =========================================
    // Error handling
    // =========================================
    @track errorStr;
    @track error;

    // =========================================
    // Record Picker Configuration
    // =========================================
    contactDisplayInfo = {
        primaryField: 'HAM_Name_w_Suffix__c',
        additionalFields: ['ucinn_ascendv2__Donor_ID__c']
    };

    contactMatchingInfo = {
        primaryField: { fieldPath: 'HAM_Name_w_Suffix__c' },
        additionalFields: [{ fieldPath: 'ucinn_ascendv2__Donor_ID__c' }]
    };

    // =========================================
    // Datatable columns (sorting supported)
    // =========================================
    columns = [
        {
            label: 'Name',
            fieldName: 'recordLink',
            type: 'url',
            sortable: true,
            wrapText: true,
            typeAttributes: {
                label: { fieldName: 'displayName' },
                target: '_blank'
            }
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

    // =========================================
    // Active columns — Name only on mobile, full set on desktop
    // =========================================
    get activeColumns() {
        return this.isMobile ? [this.columns[0]] : this.columns;
    }

    // =========================================
    // Component initialization
    // =========================================
    connectedCallback() {
        this.checkScreen();
        this._resizeHandler = this.checkScreen.bind(this);
        window.addEventListener('resize', this._resizeHandler);
        this.loadClassYearOptions();
        this.loadSportsAssociationOptions();
        this.loadStudentOrganizationsOptions();
    }

    disconnectedCallback() {
        window.removeEventListener('resize', this._resizeHandler);
    }

    checkScreen() {
        this.isMobile = window.innerWidth <= 768;
    }

    // Fetch Class Year options from Apex
    loadClassYearOptions() {
        getClassYearOptions()
            .then((data) => {
                // Convert string array to combobox format
                this.classYearOptions = [
                    { label: 'Select Class Year', value: '' },
                    ...data.map(year => ({
                        label: year,
                        value: year
                    }))
                ];
                console.log('Class Year options loaded:', this.classYearOptions);
            })
            .catch((error) => {
                console.error('Error loading class years:', error);
                this.showErrorToast('Error loading class year options');
            });
    }

    // Fetch Sports Association options from Apex
    loadSportsAssociationOptions() {
        getSportsAssociationOptions()
            .then((data) => {
                // Convert string array to combobox format
                this.sportsAssociationOptions = [
                    { label: 'Select Sports Association', value: '' },
                    ...data.map(sport => ({
                        label: sport,
                        value: sport
                    }))
                ];
                console.log('Sports Association options loaded:', this.sportsAssociationOptions);
            })
            .catch((error) => {
                console.error('Error loading sports associations:', error);
                this.showErrorToast('Error loading sports association options');
            });
    }

    // Fetch Student Organizations options from Apex
    loadStudentOrganizationsOptions() {
        getStudentOrganizationsOptions()
            .then((data) => {
                // Convert string array to combobox format
                this.studentOrganizationOptions = [
                    { label: 'Select Student Organization', value: '' },
                    ...data.map(org => ({
                        label: org,
                        value: org
                    }))
                ];
                console.log('Student Organizations options loaded:', this.studentOrganizationOptions);
            })
            .catch((error) => {
                console.error('Error loading student organizations:', error);
                this.showErrorToast('Error loading student organizations options');
            });
    }

    // =========================================
    // Input handlers
    // =========================================
    handleInputChange(event) {
        const field = event.target.name;
        if (field === 'nameSearch') {
            this.nameSearchString = event.target.value;
        } else if (field === 'donorId') {
            this.donorIdStr = event.target.value;
        }
    }

    handlePicklistChange(event) {
        const field = event.target.name;
        const value = event.detail.value;

        if (field === 'Picklist1') {
            this.selectedClassYear = value;
        } else if (field === 'Picklist2') {
            this.selectedSportsAssociation = value;
        } else if (field === 'Picklist3') {
            this.selectedStudentOrganization = value;
        }
    }

    handleKeyUp(event) {
        // Check if Enter key was pressed (key code 13 or key 'Enter')
        if (event.keyCode === 13 || event.key === 'Enter') {
            this.searchConstituents();
        }
    }

    // =========================================
    // Record Picker Handler
    // =========================================
    handleRecordPickerChange(event) {
        this.selectedContactId = event.detail.recordId;

        // Navigate directly to JEDI Overview when a contact is selected
        if (this.selectedContactId) {
            this.navigateToJEDI(this.selectedContactId);
            // Clear the selection after navigation
            this.selectedContactId = null;
        }
    }

    // Navigate directly to JEDI Overview page
    navigateToJEDI(recordId) {
        const navConfig = {
            type: 'standard__navItemPage',
            attributes: {
                apiName: 'JEDI_Overview'
            },
            state: {
                c__recordId: recordId
            }
        };

        // Check if running in Salesforce mobile app
        if (this.isInMobileApp()) {
            // Mobile: navigate in same context (fixes production mobile issue)
            this[NavigationMixin.Navigate](navConfig).catch(error => {
                console.error('Navigation error:', error);
            });
        } else {
            // Desktop: open in new tab (preserves existing behavior)
            this[NavigationMixin.GenerateUrl](navConfig)
                .then(url => {
                    window.open(url, '_blank', 'noopener,noreferrer');
                })
                .catch(error => {
                    console.error('Navigation error:', error);
                });
        }
    }

    // Helper method to detect Salesforce mobile app
    isInMobileApp() {
        return /SalesforceMobileSDK/.test(navigator.userAgent);
    }

    // =========================================
    // Search functionality
    // =========================================
    searchConstituents(event) {
        if (this.nameSearchString != '' || this.donorIdStr != '' || this.selectedClassYear != '' || this.selectedSportsAssociation != '' || this.selectedStudentOrganization != '' || this.selectedContactId != null) {
            this.loading = true;
            searchContact({
                searchStr: this.nameSearchString,
                donorId: this.donorIdStr,
                classYear: this.selectedClassYear,
                sportsAssociation: this.selectedSportsAssociation,
                studentOrganization: this.selectedStudentOrganization,
                contactId: this.selectedContactId
            })
                .then((data) => {
                    const rows = Array.isArray(data) ? data : [];

                    // Add recordLink and displayName (with deceased/HW badges) for datatable
                    this.allConstituents = rows.map(row => {
                        const badges = [];
                        if (row.ucinn_ascendv2__Is_Deceased__c) badges.push('(D)');
                        if (row.ucinn_ascendv2__Primary_Contact_Type__c === 'Hamilton Withdrawn') badges.push('(HW)');
                        const displayName = badges.length
                            ? `${row.HAM_Name_w_Suffix__c} ${badges.join(' ')}`
                            : row.HAM_Name_w_Suffix__c;
                        return {
                            ...row,
                            displayName,
                            recordLink: `/lightning/n/JEDI_Overview?c__recordId=${row.Id}`
                        };
                    });

                    this.totalRecords = this.allConstituents.length;

                    // Reset to first page and compute slice
                    this.pageNumber = 1;
                    this.derivePage();

                    if (this.totalRecords === 0) {
                        this.showNoDataToast();
                    }
                    this.error = undefined;

                    if (this.isMobile && this.totalRecords > 0) {
                        // eslint-disable-next-line @lwc/lwc/no-async-operation
                        setTimeout(() => {
                            const table = this.template.querySelector('lightning-datatable');
                            if (table) table.scrollIntoView({ behavior: 'smooth', block: 'center' });
                        }, 100);
                    }
                })
                .catch((error) => {
                    this.errorStr = 'Error: ' + JSON.stringify(error);
                    this.allConstituents = [];
                    this.pageConstituents = [];
                    this.totalRecords = 0;
                    this.pageNumber = 1;
                })
                .finally(() => {
                    this.loading = false;
                });
        }
    }

    clearData(event) {
        this.nameSearchString = '';
        this.donorIdStr = '';
        this.selectedClassYear = '';
        this.selectedSportsAssociation = '';
        this.selectedStudentOrganization = '';
        this.selectedContactId = null;

        // Reset all data and pagination
        this.allConstituents = [];
        this.pageConstituents = [];
        this.totalRecords = 0;
        this.pageNumber = 1;
    }

    // =========================================
    // Datatable sort handler
    // =========================================
    doSorting(event) {
        this.loading = true;
        this.sortBy = event.detail.fieldName;
        this.sortDirection = event.detail.sortDirection;
        
        // Sort the full dataset, then re-slice current page
        this.sortData(this.sortBy, this.sortDirection);
        
        // Reset to first page after sorting and compute slice
        this.pageNumber = 1;
        this.derivePage();
        
        this.loading = false;
    }

    sortData(fieldname, direction) {
        // Map URL field to its display value for proper sorting
        const key = fieldname === 'recordLink' ? 'HAM_Name_w_Suffix__c' : fieldname;
        const dir = direction === 'desc' ? -1 : 1;

        this.allConstituents = [...this.allConstituents].sort((a, b) => {
            const va = (a[key] ?? '').toString().toLowerCase();
            const vb = (b[key] ?? '').toString().toLowerCase();
            if (va === vb) return 0;
            return va > vb ? dir : -dir;
        });
    }

    // =========================================
    // Toast and navigation
    // =========================================
    showNoDataToast() {
        const event = new ShowToastEvent({
            title: 'No Records Found',
            message: 'No constituent records were found.',
            variant: 'info'
        });
        this.dispatchEvent(event);
    }

    showErrorToast(message) {
        const event = new ShowToastEvent({
            title: 'Error',
            message: message,
            variant: 'error'
        });
        this.dispatchEvent(event);
    }
}