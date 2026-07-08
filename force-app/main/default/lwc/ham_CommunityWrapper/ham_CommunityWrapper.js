import { LightningElement, api, track } from 'lwc';

// Importing static resources
import HAM_ICONS from '@salesforce/resourceUrl/HAM_Icons';

export default class Ham_CommunityWrapper extends LightningElement {
    @api userContactId;
    @api initialTab = 'News'; // Defaults to News as requested
    @api groupId;
    @api subview;
    @api isOverride = false;
    @api label={};
    @api images = {};

    @track activeSubTab;
    @track view = 'grid';

    hamIcons = HAM_ICONS;

    icons = {
        listViewIcon : this.hamIcons + '/list-view.png',
        gridViewIcon : this.hamIcons + '/grid-dark.png',
        viewCheckIcon: this.hamIcons + '/view-check.png',
    }

    connectedCallback() {
        this.activeSubTab = this.initialTab;
    }

    // CSS styling getters for the active tab state
    get newsTabClass()      { return this.activeSubTab === 'News'      ? 'main-tab-active' : 'main-tab-inactive'; }
    get groupsTabClass()    { return this.activeSubTab === 'Groups'    ? 'main-tab-active' : 'main-tab-inactive'; }
    get resourcesTabClass() { return this.activeSubTab === 'Resources' ? 'main-tab-active resources-class' : 'main-tab-inactive resources-class'; }

    // Logic getters for lwc:if
    get isNewsActive() { return this.activeSubTab === 'News'; }
    get isGroupsActive() { return this.activeSubTab === 'Groups'; }
    get isResourcesActive() { return this.activeSubTab === 'Resources'; }

    handleTabClick(event) {
        this.activeSubTab = event.currentTarget.dataset.tab;
        
        // Notify parent router so URL updates correctly
        this.dispatchEvent(new CustomEvent('communitytabchange', { 
            detail: { tab: this.activeSubTab } 
        }));
    }

    // Pass the group deep-link event up to the main router
    handleGroupNav(event) {
        this.dispatchEvent(new CustomEvent('navigategroup', { detail: event.detail }));
    }

    get isListView() {
        return this.view === 'list';
    }

    get isGridView() {
        return this.view === 'grid';
    }

    get listViewClass() {
        return this.isListView ? 'active' : '';
    }

    get gridViewClass() {
        return this.isGridView ? 'active' : '';
    }

    get wrapperClass() {
        return this.isOverride ? 'community-wrapper kirkland-override' : 'community-wrapper';
    }

    handleViewToggle(event) {
        const viewType = event.currentTarget.dataset.view;
        this.view = viewType;

        //console.log('viewType -'+viewType);

    }

}