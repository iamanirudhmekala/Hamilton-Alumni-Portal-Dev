import { LightningElement,api,track,wire } from 'lwc';
import getGroups from '@salesforce/apex/Ham_GroupsController.getGroups';
import getPicklistValues from '@salesforce/apex/Ham_GroupsController.getPicklistValues';
import siteDefaultImageResource from '@salesforce/resourceUrl/HAM_SiteFallbackImage';
import siteDefaultImageResourceKirkland from '@salesforce/resourceUrl/HAM_SiteFallbackImage_Kirkland';

// Importing static resources
import HAM_ICONS from '@salesforce/resourceUrl/HAM_Icons';

export default class Ham_groupsDiscovery extends LightningElement {
    @api userContactId;
    @api viewtoggle;
    @api label={};
    @api images = {};
    _isOverride = false;
    @api
    get isOverride() {
        return this._isOverride;
    }
    set isOverride(value) {
        this._isOverride = (value === true || value === 'true');
    }
    
    @track tabMode = 'MyGroups'; // Default tab
    @track searchValue = ''; // NEW: Controls the text inside the input box
    @track searchTerm = '';  // Existing: Triggers the Apex @wire call
    @track categoryFilter = '';
    @track groups = [];
    @track hasMoreData = false;
    @track isOpen = false;
    @track showModal = false;
    @track showModalMob = false;
    @track screenWidth = window.innerWidth;

    // Pagination (Reactive)
    @track offsetValue = 0;
    fetchLimit = 10; // We fetch 10 to check if there is a next page, but only display 9
    @track currentPage   = 1;
    @track groupSkip = 0;
    @track totalGroups = 0;

    // Page size — set in connectedCallback based on screen width, reactive so wires re-fire
    @track pageSize = 9;
   


    options = [];
    @track selectedValue;

    view = 'grid';

    defaultFallbackImage = siteDefaultImageResource;
    DEFAULT_IMAGE_URL_Kirkland = siteDefaultImageResourceKirkland;

    hamIcons =HAM_ICONS;

    icons = {
        listViewIcon : this.hamIcons + '/list-view.png',
        gridViewIcon: this.hamIcons + '/grid-dark.png',
        viewCheckIcon : this.hamIcons + '/view-check.png',
    }

    connectedCallback() {
        document.addEventListener('click', this.handleOutsideClick);

        this.pageSize = window.innerWidth < 1024 ? 3 : 9;
        this._resizeHandler = this.handleResize.bind(this);
        window.addEventListener('resize', this._resizeHandler);

        // Read URL parameters to check if there is a search query passed from the homepage widget redirect
        try {
            const urlParams = new URLSearchParams(window.location.search);
            const searchParam = urlParams.get('gSearch');
            if (searchParam) {
                this.searchValue = searchParam;
                this.searchTerm = searchParam;
                this.tabMode = 'AllGroups';
            }
        } catch (e) {
            console.error('Error reading URL parameter gSearch:', e);
        }
    }

    disconnectedCallback() {
        document.removeEventListener('click', this.handleOutsideClick);
         window.removeEventListener('resize', this._resizeHandler);
    }

    handleResize() {
        this.screenWidth = window.innerWidth;
        const newPageSize = this.screenWidth < 1024 ? 3 : 9;
        if (newPageSize !== this.pageSize) {
            this.pageSize = newPageSize;
            // Reset both tabs to page 1 — wires re-fire automatically via reactive pageSize
            this.currentPage = 1;
            this.groupSkip = 0;
           
        }
    }

    get isMobileView()  { return this.screenWidth <= 1024; }
    get isDesktopView() { return this.screenWidth > 1024; }

     // Returns the Kirkland fallback image when in override mode, otherwise the standard one.
    get defaultImageUrl() {
        return this._isOverride ? this.DEFAULT_IMAGE_URL_Kirkland : this.defaultFallbackImage;
    }

    @wire(getPicklistValues, {
        objectApiName: 'HAM_Group__c',
        fieldApiName: 'Category__c'
    })
    wiredPicklist({ data, error }) {
        if (data) {
            this.options = [
                { label: 'All', value: '' }, 
                ...data.map(item => ({
                    label: item,
                    value: item
                }))
            ]
        } else if (error) {
            console.error(error);
        }
    }
    
    
    // Dynamic classes for styling active/inactive tabs
    get myGroupsClass() {
        return this.tabMode === 'MyGroups' ? 'activetab-btn' : 'nonactivetab-btn';
    }
    get allGroupsClass() {
        return this.tabMode === 'AllGroups' ? 'activetab-btn' : 'nonactivetab-btn';
    }
    get showEmptyState() {
        return this.groups && this.groups.length === 0;
    }

    get selectedLabel() {
    const selected = this.options.find(opt => opt.value === this.selectedValue);
    return selected ? selected.label : 'Categories'; // default placeholder
    }


    
    // Wire Apex Method
    @wire(getGroups, { contactId: '$userContactId', tabMode: '$tabMode', searchTerm: '$searchTerm', categoryFilter: '$categoryFilter', limitSize: '$pageSize', offsetValue: '$groupSkip' })
    wiredGroups({ error, data }) {
        if (data) {
           this.groups = data.records.map(record => {
               const desc = record.description || '';
               const isLong = desc.length > 90;
               return {
                   ...record,
                   isLongDescription: isLong,
                   isExpanded: false,
                   descClass: 'card-desc collapsed',
                   listDescClass: 'card-description collapsed'
               };
           });        
           this.totalGroups = data.totalCount; 
        } else if (error) {
            console.error('Error fetching groups', error);
        }
    }  
    
    resetPagination() {
        this.currentPage = 1;
        this.groupSkip = 0;
    }

    handleTabChange(event) {
        this.tabMode = event.target.dataset.tab;
        this.categoryFilter = '';
        this.selectedValue = '';
        
        // Clear search text and search results
        this.searchValue = ''; 
        this.searchTerm = '';
        this.resetPagination();

        try {
            const url = new URL(window.location.href);
            if (url.searchParams.has('gSearch')) {
                url.searchParams.delete('gSearch');
                window.history.replaceState({}, '', url.toString());
            }
        } catch (e) {}
    }

    //  Only updates the text box as the user types
    handleInputChange(event) {
        this.searchValue = event.target.value; 

        if (!this.searchValue.trim()) {
            this.currentPage   = 1;
            this.offsetValue = 0;
            this.searchTerm = '';
            
            try {
                const url = new URL(window.location.href);
                if (url.searchParams.has('gSearch')) {
                    url.searchParams.delete('gSearch');
                    window.history.replaceState({}, '', url.toString());
                }
            } catch (e) {}
        }
    }

   //  Triggers the Apex Query when Button is clicked or Enter is pressed
    handleSearch() {
        this.searchTerm = this.searchValue || ''; // This variable change triggers the @wire
        this.resetPagination();

        try {
            const url = new URL(window.location.href);
            if (this.searchTerm) {
                url.searchParams.set('gSearch', this.searchTerm);
            } else {
                url.searchParams.delete('gSearch');
            }
            window.history.replaceState({}, '', url.toString());
        } catch (e) {}
    }

    //  Enter key support
    handleSearchKeydown(event) { 
        if (event.key === 'Enter') {
            this.handleSearch(); 
        }
    }

    handleCategoryChange(event) {
       // this.categoryFilter = event.detail.value;
        this.categoryFilter = event.currentTarget.dataset.value;
        this.selectedValue = this.categoryFilter; 

        this.resetPagination();

    }

    handleToggleDescription(event) {
        event.stopPropagation();
        event.preventDefault();
        const groupId = event.currentTarget.dataset.id;
        this.groups = this.groups.map(group => {
            if (group.groupId === groupId) {
                const isExpanded = !group.isExpanded;
                return {
                    ...group,
                    isExpanded: isExpanded,
                    descClass: `card-desc ${isExpanded ? 'expanded' : 'collapsed'}`,
                    listDescClass: `card-description ${isExpanded ? 'expanded' : 'collapsed'}`
                };
            }
            return group;
        });
    }

    handleViewGroup(event) {
         event.preventDefault(); //  prevents page navigation / refresh
        const groupId = event.currentTarget.dataset.id;
        //console.log('View group Id', groupId);
        // Dispatch a custom event or navigate as needed
        const viewEvent = new CustomEvent('viewgroup', { detail: { groupId } });
        this.dispatchEvent(viewEvent);
    }


    get isListView() {
        return this.viewtoggle === 'list';
    }

    get isGridView() {
        return !this.viewtoggle || this.viewtoggle === 'grid';
    }

    get containerClass() {
        return `slds-card slds-p-around_medium portal-bg ${this.isOverride ? 'kirkland-override' : ''}`;
    }

    get mobileContainerClass() {
        return `slds-card slds-p-around_small portal-bg mobile-view ${this.isOverride ? 'kirkland-override' : ''}`;
    }

    get listViewClass() {
        return this.isListView ? 'active' : '';
    }

    get gridViewClass() {
        return this.isGridView ? 'active' : '';
    }

    
     toggleDropdown(event) {
        event.stopPropagation();
        this.isOpen = !this.isOpen;
    }

    handleOutsideClick = () => {
        this.isOpen = false;
    }

    // Handle pagination page change logic
    handlePageChange(event) {
        this.currentPage = event.detail.currentPage;
        this.groupSkip = event.detail.recordsToSkip;
    }

    handleOpenModal() {
        this.showModal = true;
    }

    handleCloseModal() {
        this.showModal = false;
    }

    handleOpenModalMob() {
        this.showModalMob = true;
    }

    handleCloseModalMob() {
        this.showModalMob = false;
    }


}