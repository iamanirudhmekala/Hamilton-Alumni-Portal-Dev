import { LightningElement, api, track, wire } from 'lwc';
import getGroups from '@salesforce/apex/Ham_GroupsController.getGroups';

export default class Ham_groupsCmp extends LightningElement {
    @api userContactId;

    @track searchValue = '';
    @track groups = [];
    @track isLoading = true;

    @wire(getGroups, { 
        contactId: '$userContactId', 
        tabMode: 'MyGroups', 
        searchTerm: '', 
        categoryFilter: '', 
        limitSize: 10, 
        offsetValue: 0 
    })
    wiredGroups({ error, data }) {
        this.isLoading = false;
        if (data) {
            this.groups = data.records || [];
        } else if (error) {
            console.error('Error fetching widget groups:', error);
            this.groups = [];
        }
    }

    get displayGroups() {
        return this.groups;
    }

    get hasGroups() {
        return this.groups && this.groups.length > 0;
    }

    handleInputChange(event) {
        this.searchValue = event.target.value;
    }

    handleKeyDown(event) {
        if (event.key === 'Enter') {
            this.handleSearchClick();
        }
    }

    handleSearchClick() {
        this.dispatchEvent(new CustomEvent('viewgroup', {
            detail: {
                groupId: null,
                searchTerm: this.searchValue
            }
        }));
    }

    handleDiscoverClick() {
        this.dispatchEvent(new CustomEvent('viewgroup', {
            detail: {
                groupId: null,
                searchTerm: ''
            }
        }));
    }

    handleGroupClick(event) {
        event.preventDefault();
        event.stopPropagation();
        const groupId = event.currentTarget.dataset.id;
        if (groupId) {
            this.dispatchEvent(new CustomEvent('viewgroup', {
                detail: {
                    groupId: groupId
                }
            }));
        }
    }
}