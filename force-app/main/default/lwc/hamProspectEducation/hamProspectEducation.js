// ASC-XXXX Mobile: card view for Awards and Other Degrees
import { LightningElement, api, track, wire } from 'lwc';
import searchProspectEducation from '@salesforce/apex/HAMProspectOverviewApexController.searchProspectEducation';
import { CurrentPageReference } from 'lightning/navigation';

export default class HamProspectEducation extends LightningElement {
     @api contactEducationWrapper = {};
     @api recordId;
     @track loading = false;
     @track educationDetails = {};
     @track awards;
     @track activeStudentSectionBio = ['Student Summary'];
     @track otherDegrees = [];
     @track sortedBy;
     @track sortedDirection = 'asc';
     _openOtherDegrees = false;

     // =========================================
     // Responsive flag
     // =========================================
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

     otherDegreeColumns = [
        {
            label: 'Degree Institution',
            fieldName: 'institutionLink',
            type: 'url',
            sortable: true,
            typeAttributes: { label: { fieldName: 'institutionName' }, target: '_blank' }
        },
        {
            label: 'Degree Year',
            fieldName: 'ucinn_ascendv2__Conferred_Degree_Year__c',
            type: 'text',
            sortable: true
        },
        {
            label: 'Degree Code',
            fieldName: 'degreeCodeLink',
            type: 'url',
            sortable: true,
            typeAttributes: { label: { fieldName: 'degreeCodeDesc' }, target: '_blank' }
        },
        {
            label: 'First Major',
            fieldName: 'HAM_First_Major__c',
            type: 'text',
            sortable: true
        },
        {
            label: 'First Minor',
            fieldName: 'HAM_First_Minor__c',
            type: 'text',
            sortable: true
        },
        {
            label: 'Degree ID',
            fieldName: 'degreeLink',
            type: 'url',
            sortable: true,
            typeAttributes: { label: { fieldName: 'Name' }, target: '_blank' }
        }
    ];

    // url columns sort by their display label, not the url value
    _sortKeyMap = {
        institutionLink: 'institutionName',
        degreeCodeLink: 'degreeCodeDesc',
        degreeLink: 'Name'
    };

    get hasOtherDegrees() {
        return this.otherDegrees && this.otherDegrees.length > 0;
    }

    get otherDegreeLabel() {
        return 'Other Degrees (' + (this.otherDegrees ? this.otherDegrees.length : 0) + ')';
    }

    handleOtherDegreeSort(event) {
        const { fieldName, sortDirection } = event.detail;
        this.sortedBy = fieldName;
        this.sortedDirection = sortDirection;
        const sortKey = this._sortKeyMap[fieldName] || fieldName;
        this.otherDegrees = [...this.otherDegrees].sort((a, b) => {
            const valA = (a[sortKey] || '').toString().toLowerCase();
            const valB = (b[sortKey] || '').toString().toLowerCase();
            return sortDirection === 'asc' ? valA.localeCompare(valB) : valB.localeCompare(valA);
        });
    }

    @track awardColumns = [
        {
            label: 'Name',
            fieldName: 'nameLink',
            type: 'url',
            typeAttributes: {
                label: { fieldName: 'Name' },
                target: '_blank'
            }
        },
        {
            label: 'Designation Name',
            fieldName: 'designationLink',
            type: 'url',
            typeAttributes: {
                label: { fieldName: 'designationName' }, 
                target: '_blank'
            }
        },
        {
            label: 'Type',
            fieldName: 'ucinn_ascendv2__Type__c',
            type: 'text'
        },
        {
            label: 'Fiscal Year',
            fieldName: 'ucinn_ascendv2__Fiscal_Year__c',
            type: 'text'
        }
    ];

    @wire(CurrentPageReference)
        getStateParameters(currentPageReference) {
            
            if (currentPageReference?.state?.c__recordId) {
                this.recordId = currentPageReference.state.c__recordId;
                
    
                this.loading = true; // Start spinner
                searchProspectEducation({ contactId: this.recordId })
                    .then(result => {
                        if (!result) {
                            return;
                        }
                        this.contactEducationWrapper = result;
                        this.educationDetails = result.hamiltonDegree || {};
                        this.awards = result.awards;

                        if (result.otherDegrees && result.otherDegrees.length > 0) {
                            this.otherDegrees = result.otherDegrees.map(deg => ({
                                ...deg,
                                degreeLink: '/' + deg.Id,
                                institutionLink: deg.ucinn_ascendv2__Degree_Institution__c ? '/' + deg.ucinn_ascendv2__Degree_Institution__c : null,
                                institutionName: deg.ucinn_ascendv2__Degree_Institution__r?.Name || '',
                                degreeCodeLink: deg.ucinn_ascendv2__Degree_Code__c ? '/' + deg.ucinn_ascendv2__Degree_Code__c : null,
                                degreeCodeDesc: deg.ucinn_ascendv2__Degree_Code__r?.ucinn_ascendv2__Description__c || ''
                            }));
                            this._openOtherDegrees = true;
                        }

                        if (this.awards) {
                            this.awards = this.awards.map(row => {
                                let mapped = {
                                    ...row,
                                    nameLink: '/' + row.Id
                                };
                                if (row.ucinn_ascendv2__Designation__c) {
                                    mapped.designationLink = '/' + row.ucinn_ascendv2__Designation__c;
                                    mapped.designationName = row.ucinn_ascendv2__Designation__r?.ucinn_ascendv2__Designation_Name__c
                                        || row.ucinn_ascendv2__Designation__r?.ucinn_ascendv2__Fund_Name__c
                                        || '';
                                }
                                return mapped;
                            });
                        }
                    })
                    .catch(error => {
                        console.error('Error fetching Prospect:', error);
                    })
                    .finally(() => {
                        this.loading = false; // Stop spinner
                    });
            }
        }
        
        renderedCallback() {
        if (this._openOtherDegrees) {
            this._openOtherDegrees = false;
            this.activeStudentSectionBio = ['Student Summary', 'Other Degrees'];
        }
    }

        handleStudentSectionToggle(event) {
        this.activeStudentSectionBio = event.detail.openSections;
    }
}