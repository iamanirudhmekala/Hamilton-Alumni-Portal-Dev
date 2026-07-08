import { LightningElement, track, wire } from 'lwc';
import recentRecords from '@salesforce/apex/HamMyProspectController.searchMyProspects';
import { getRecord } from 'lightning/uiRecordApi';
import userId from '@salesforce/user/Id';
import FIRST_NAME_FIELD from '@salesforce/schema/User.FirstName';

export default class HAMMyProspects extends LightningElement {
    @track allProspects = [];      // full, sorted dataset
    @track error;
    @track activeSection = 'My Prospects';  // Open by default
    @track sortedBy = 'recordLink';
    @track sortedDirection = 'asc';
    userFirstName = '';
    userId = userId;


    columns = [
        {
            label: 'Name',
            fieldName: 'recordLink',
            type: 'url',
            typeAttributes: {
                label: { fieldName: 'HAM_Name_w_Suffix__c' },
                target: '_blank'
            },
            sortable: true
        },
        {
            label: 'Preferred Chapter',
            fieldName: 'chapterLink',
            type: 'url',
            typeAttributes: {
                label: { fieldName: 'chapterName' },
                target: '_blank'
            },
            sortable: true
        },
        {
            label: 'Current Chapters',
            fieldName: 'HAM_Current_Chapters__c',
            type: 'text',
            sortable: true
        }
    ];

    @wire(getRecord, { recordId: userId, fields: [FIRST_NAME_FIELD] })
    wiredUser({ data, error }) {
        if (data) {
            this.userFirstName = data.fields.FirstName.value || '';
        } else if (error) {
            console.error('Error fetching user data:', error);
        }
    }

    @wire(recentRecords)
    wiredApexResult({ data, error }) {
        if (data) {
            const processedRows = data.map(row => ({
                ...row,
                recordLink: `/lightning/n/JEDI_Overview?c__recordId=${row.Id}`,
                chapterLink: row.HAM_Preferred_Chapter_Lookup__c
                    ? `/lightning/r/${row.HAM_Preferred_Chapter_Lookup__c}/view`
                    : null,
                chapterName: row.HAM_Preferred_Chapter_Lookup__r?.Name || '—'
            }));

            this.allProspects = [...processedRows];
            this.error = undefined;

            // Apply default or current sort
            this.sortProspectData(this.sortedBy, this.sortedDirection);
        } else if (error) {
            console.error('Error fetching prospects:', error);
            this.error = error;
            this.allProspects = [];
        }
    }

    handleSectionToggle(event) {
        const openedSections = event.detail.openSections;
        if (Array.isArray(openedSections)) {
            this.activeSection = openedSections.includes('My Prospects') ? 'My Prospects' : '';
        } else {
            this.activeSection = openedSections === 'My Prospects' ? 'My Prospects' : '';
        }
    }

    doSorting(event) {
        const { fieldName: sortedBy, sortDirection } = event.detail;
        this.sortedBy = sortedBy;
        this.sortedDirection = sortDirection;
        this.sortProspectData(sortedBy, sortDirection);
    }

    sortProspectData(field, direction) {
        // Map URL fields to their display values for proper sorting
        const key = field === 'recordLink' ? 'HAM_Name_w_Suffix__c'
                  : field === 'chapterLink' ? 'chapterName'
                  : field;

        const dir = direction === 'desc' ? -1 : 1;

        this.allProspects = [...this.allProspects].sort((a, b) => {
            const va = (a[key] ?? '').toString().toLowerCase();
            const vb = (b[key] ?? '').toString().toLowerCase();
            if (va === vb) return 0;
            return va > vb ? dir : -dir;
        });
    }

    get isExportDisabled() {
        return !this.allProspects || this.allProspects.length === 0;
    }

    handleDownloadCsv() {
        try {
            if (!this.allProspects || this.allProspects.length === 0) {
                return;
            }

            // Convert proxy to regular array and define the fields to export
            const prospects = JSON.parse(JSON.stringify(this.allProspects));

            const exportData = prospects.map(row => {
                const chapterName = row.chapterName || '';
                // Replace em dash or corrupted characters with empty string
                const cleanChapterName = (chapterName === '—' || chapterName === 'â€"' || chapterName.trim() === '') ? '' : chapterName;

                return {
                    'Name': row.HAM_Name_w_Suffix__c || '',
                    'Preferred Chapter': cleanChapterName,
                    'Current Chapters': row.HAM_Current_Chapters__c || ''
                };
            });

            const headers = Object.keys(exportData[0]); // Get headers from first record
            const csvRows = exportData.map(row =>
                headers.map(header => {
                    const value = (row[header] || '').toString();
                    // Escape CSV values: wrap in quotes if contains comma, quote, or newline
                    if (value.includes(',') || value.includes('"') || value.includes('\n')) {
                        return `"${value.replace(/"/g, '""')}"`;
                    }
                    return value;
                }).join(',')
            );

            const csvContent = [headers.join(','), ...csvRows].join('\n');

            // Use data URI approach to work with Lightning Web Security
            const encodedUri = 'data:text/csv;charset=utf-8,' + encodeURIComponent(csvContent);
            const link = document.createElement('a');
            link.setAttribute('href', encodedUri);

            // Create filename with user's first name
            const filename = this.userFirstName
                ? `My_Prospects_${this.userFirstName}.csv`
                : 'My_Prospects.csv';
            link.setAttribute('download', filename);

            link.style.display = 'none';
            document.body.appendChild(link);
            link.click();
            document.body.removeChild(link);
        } catch (error) {
            console.error('Error in handleDownloadCsv:', error);
        }
    }

}