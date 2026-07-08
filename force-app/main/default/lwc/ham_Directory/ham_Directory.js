import { LightningElement, wire } from 'lwc';

// UI API to get logged in user's contactId
import { getRecord } from 'lightning/uiRecordApi';
import USER_ID from '@salesforce/user/Id';
const USER_FIELDS = ['User.ContactId'];

// importing apex methods
import getDirectoryTabset from '@salesforce/apex/HAM_AlumniDirectoryController.getDirectoryTabset';
import getDirectoryDataOnPage from '@salesforce/apex/HAM_AlumniDirectoryController.getDirectoryDataOnPage';
import getFilters from '@salesforce/apex/HAM_AlumniDirectoryController.getFilterMetadataAndValues';

// importing custom labels
import BuildAlumniCommunity from '@salesforce/label/c.ham_BuildAlumniCommunity';

export default class Ham_Directory extends LightningElement {

    tabs = [];
    directoryData = [];
    contactId;
    activeTabName = 'Build Your Alumni Community';
    filters = [];
    BuildAlumniCommunity = BuildAlumniCommunity;

    connectedCallback() {
        this.getTabset();
        this.getFilters();
    }

    // Get logged-in user's ContactId
    @wire(getRecord, { recordId: USER_ID, fields: USER_FIELDS })
    wiredUser({ data, error }) {
        if (data) {
            this.contactId = data.fields.ContactId.value;
            if (this.contactId) {
                this.getDirectoryData(this.contactId);
            }
        } else if (error) {
            console.error('Error getting contactId:', error);
        }
    }

    getTabset() {
        getDirectoryTabset()
            .then(result => {
                this.tabs = result.map((tab) => ({
                    ...tab,
                    className: tab.Label === this.activeTabName ? 'main-tab-active' : 'main-tab-inactive'
                }));
            })
            .catch(error => {
                console.error(error);
            });
    }

    getFilters() {
        getFilters()
            .then(result => {
                this.filters = result;
            })
            .catch(error => {
                console.error('Error getting filters:', error);
            });
    }

    getDirectoryData(contactId) {
        getDirectoryDataOnPage({ portalConstituentId: contactId })
            .then(result => {
                //console.log('Directory Data:', JSON.stringify(result, null, 2));
                this.directoryData = result.alumniList ? result.alumniList : [];
            })
            .catch(error => {
                console.error('Error getting directory data:', error);
            });
    }

    handleTabClick(event) {
        const clickedTabName = event.currentTarget.dataset.tabname;
        console.log('clickedTabName: ',clickedTabName);
        this.tabs = this.tabs.map(tab => {
            return {
                ...tab,
                className: tab.Label === clickedTabName ? 'main-tab-active' : 'main-tab-inactive'
            };
        });

        this.activeTabName = clickedTabName;
    }

    get BuildYourCommunityTab(){
        return this.activeTabName === 'Build Your Alumni Community';
    }

    get MyConnectionsTab(){
        return this.activeTabName === 'My Connections';
    }

     get BookmarkedProfilesTab(){
        return this.activeTabName === 'Bookmarked Profiles';
    }

     get ManageInvitationsTab(){
        return this.activeTabName === 'Manage Invitations';
    }
}