import { LightningElement, api, wire, track } from 'lwc';
import getResources from '@salesforce/apex/HAM_GlobalResourcesController.getResources';
import HAM_DEFAULT_IMAGES from '@salesforce/resourceUrl/HAM_SiteFallbackImage';
import HAM_ICONS from '@salesforce/resourceUrl/HAM_Icons';
import siteDefaultImageResourceKirkland from '@salesforce/resourceUrl/HAM_SiteFallbackImage_Kirkland';

const DEFAULT_IMAGE_URL = HAM_DEFAULT_IMAGES;
const DEFAULT_IMAGE_URL_Kirkland = siteDefaultImageResourceKirkland;

export default class Ham_GlobalResources extends LightningElement {
    @api viewMode;
    @api isOverride = false;

    @track records = []; // Original data from Apex
    @track filteredRecords = []; // Data after search filter
    @track currentPage = 1;
    @track pageSize = 9; // Default desktop
    @track screenWidth = window.innerWidth;

    searchKey = '';
    hamIcons = HAM_ICONS;
    icons = {
        searchMobile: HAM_ICONS + '/search.png'
    };

    get wrapperClass() {
        return this.isOverride ? 'resources-wrapper kirkland-override' : 'resources-wrapper';
    }

    // Returns the Kirkland fallback image when in override mode, otherwise the standard one.
    get defaultImage() {
        return this.isOverride ? DEFAULT_IMAGE_URL_Kirkland : DEFAULT_IMAGE_URL;
    }

    connectedCallback() {
        this.setPageSize();
        window.addEventListener('resize', this.handleResize.bind(this));
    }

    disconnectedCallback() {
        window.removeEventListener('resize', this.handleResize.bind(this));
    }

    handleResize() {
        this.screenWidth = window.innerWidth;
        this.setPageSize();
    }

    setPageSize() {
        const newSize = this.screenWidth < 1024 ? 3 : 9;
        if (this.pageSize !== newSize) {
            this.pageSize = newSize;
            this.currentPage = 1; // Reset to page 1 on resize
        }
    }

    @wire(getResources)
    wiredResources({ error, data }) {
        if (data) {
            this.records = data.map(item => ({
                id: item.id,
                title: item.title,
                description: '',
                date: '',
                linkUrl: item.linkUrl,
                imageUrl: item.imageUrl || ''   // keep raw; fallback resolved at render
            }));
            this.filteredRecords = [...this.records];
        } else if (error) {
            console.error('Error fetching global resources ', error);
        }
    }

    // This getter handles the pagination "slicing" and resolves the fallback image
    // against the CURRENT override state, so it stays correct regardless of wire timing.
    get pagedRecords() {
        const start = (this.currentPage - 1) * this.pageSize;
        const end = this.currentPage * this.pageSize;
        return this.filteredRecords.slice(start, end).map(rec => ({
            ...rec,
            imageUrl: rec.imageUrl || this.defaultImage
        }));
    }

    get totalRecords() {
        return this.filteredRecords.length;
    }

    get hasRecords() {
        return this.pagedRecords.length > 0;
    }

    // Pagination event handler
    handlePageChange(event) {
        this.currentPage = event.detail.currentPage;
        // Scroll to top of results when page changes (optional)
        const container = this.template.querySelector('.resources-wrapper');
        if(container) container.scrollIntoView({behavior: 'smooth'});
    }

    handleSearchInput(event) {
        this.searchKey = event.target.value;
        if(!this.searchKey) {
            this.handleSearch();
        }
    }

    handleSearchKeydown(event) {
        if (event.key === 'Enter') {
            this.handleSearch();
        }
    }

    handleSearch() {
        const keyword = this.searchKey?.trim().toLowerCase();
        this.currentPage = 1; // Reset to page 1 on search

        if (!keyword) {
            this.filteredRecords = [...this.records];
            return;
        }

        this.filteredRecords = this.records.filter(item =>
            item.title?.toLowerCase().includes(keyword)
        );
    }
}