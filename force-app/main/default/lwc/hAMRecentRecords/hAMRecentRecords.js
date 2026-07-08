import { LightningElement, track, wire } from 'lwc';
import recentRecords from '@salesforce/apex/HAMJediSearchController.searchRecentRecords';
import { refreshApex } from '@salesforce/apex';

export default class HAMRecentRecords extends LightningElement {
    @track allRecords = [];      // full, sorted dataset
    @track error;
    @track activeSection = '';
    @track sortedBy;
    @track sortedDirection;

    wiredResult; // store the wired response for refresh

    columns = [
        {
            label: 'Name',
            fieldName: 'recordLink',
            type: 'url',
            sortable: true,
            typeAttributes: {
                label: { fieldName: 'HAM_Name_w_Suffix__c' },
                target: '_blank'
            }
        },
        { label: 'Donor Id', fieldName: 'ucinn_ascendv2__Donor_ID__c', type: 'text', sortable: true }
    ];

    autoRefreshTimer;

    @wire(recentRecords)
    wiredApexResult(result) {
        this.wiredResult = result; // store for refresh
        const { data, error } = result;
        if (data) {
            // map and enhance data with record link
            const processedRows = data.map(row => ({
                ...row,
                recordLink: `/lightning/n/JEDI_Overview?c__recordId=${row.Id}`
            }));

            this.allRecords = [...processedRows];
            this.error = undefined;

            // Apply sort if there was a previous sort state
            if (this.sortedBy && this.sortedDirection) {
                this.sortRecordData(this.sortedBy, this.sortedDirection);
            }
        } else if (error) {
            this.error = error;
            this.allRecords = [];
        }
    }

    connectedCallback() {
        // Auto-refresh every 5 minutes (300000 ms)
        this.autoRefreshTimer = setInterval(() => {
            refreshApex(this.wiredResult);
        }, 300000);
    }

    disconnectedCallback() {
        // Stop timer when component is destroyed
        clearInterval(this.autoRefreshTimer);
    }

    handleSectionToggle(event) {
        const openedSections = event.detail.openSections;

        if (openedSections.includes('RecentProspects')) {
            this.activeSection = 'RecentProspects'; // open it
        } else {
            this.activeSection = ''; // close it
        }
    }

    doSorting(event) {
        const { fieldName: sortedBy, sortDirection } = event.detail;
        this.sortedBy = sortedBy;
        this.sortedDirection = sortDirection;
        this.sortRecordData(sortedBy, sortDirection);
    }

    sortRecordData(field, direction) {
        // Map URL fields to their display values for proper sorting
        const key = field === 'recordLink' ? 'HAM_Name_w_Suffix__c' : field;

        const dir = direction === 'desc' ? -1 : 1;

        this.allRecords = [...this.allRecords].sort((a, b) => {
            const va = (a[key] ?? '').toString().toLowerCase();
            const vb = (b[key] ?? '').toString().toLowerCase();
            if (va === vb) return 0;
            return va > vb ? dir : -dir;
        });
    }
}