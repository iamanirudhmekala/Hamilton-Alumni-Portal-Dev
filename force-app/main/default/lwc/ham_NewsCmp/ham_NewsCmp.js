import { LightningElement, api, track, wire } from 'lwc';
import getNewsConfig from '@salesforce/apex/HAM_NewsModuleController.getNewsConfig';
import getNewsRecordCount from '@salesforce/apex/HAM_NewsModuleController.getNewsRecordCount';
import getPicklistValues from '@salesforce/apex/HAM_NewsModuleController.getPicklistValues';
import LISTING_OBJECT from '@salesforce/schema/HAM_Listing__c';
import TOPICS_FIELD from '@salesforce/schema/HAM_Listing__c.HAM_News_Category__c';
import HAM_ICONS from '@salesforce/resourceUrl/HAM_Icons';
import siteDefaultImageResource from '@salesforce/resourceUrl/HAM_SiteFallbackImage';
import siteDefaultImageResourceKirkland from '@salesforce/resourceUrl/HAM_SiteFallbackImage_Kirkland';


import AllTime from '@salesforce/label/c.ham_AllTime';
import CustomRange from '@salesforce/label/c.ham_CustomRange';
import OlderNews from '@salesforce/label/c.ham_OlderNews';
import CurrentNews from '@salesforce/label/c.ham_CurrentNews';
import NoCurrentNews from '@salesforce/label/c.ham_noCurrentNews';
import ReadMore from '@salesforce/label/c.ham_ReadMore';
import TRENDINGNEWS from '@salesforce/label/c.ham_trending_news';
import NO_OLDER_NEWS_AVAILABLE from '@salesforce/label/c.ham_no_news_available';

const DEFAULT_IMAGE_URL = siteDefaultImageResource;
const DEFAULT_IMAGE_URL_Kirkland = siteDefaultImageResourceKirkland;


const stripHtml = (html) => {
    if (!html) return '';
    return html
        .replace(/<[^>]*>/g, ' ')
        .replace(/&nbsp;/gi, ' ')
        .replace(/&amp;/gi,  '&')
        .replace(/&lt;/gi,   '<')
        .replace(/&gt;/gi,   '>')
        .replace(/&quot;/gi, '"')
        .replace(/&#39;/gi,  "'")
        .replace(/\s+/g,     ' ')
        .trim();
};

export default class Ham_NewsCmp extends LightningElement {
    @api userContactId;
    @api view = 'grid'; // passed down from ham_CommunityWrapper
    @api isOverride = false;

    get wrapperClass() {
        return this.isOverride ? 'news-module kirkland-override' : 'news-module';
    }

    // Active pill tab
    @track activeNewsTab = 'trending';

    // Page size — set in connectedCallback based on screen width, reactive so wires re-fire
    @track pageSize = 9;

    // Trending News state
    @track trendingPage = 1;
    @track trendingSkip = 0;
    @track trendingTotal = 0;
    @track processedCurrentNews = [];

    // Older News state
    @track olderPage = 1;
    @track olderSkip = 0;
    @track olderTotal = 0;
    @track processedOlderNews = [];

    @track screenWidth = window.innerWidth;

    rawDisplayFields = [];
    fieldMap = {};

    // Trending category filter
    @track filterCurrCategoryValue = 'all';
    @track selectedCurrLabel = 'All Topics';
    @track isCurrOpen = false;

    // Older News category filter
    @track filterCategoryValue = 'all';
    @track selectedLabel = 'All Topics';
    @track isOpen = false;

    // Older News date filter
    @track filterFromDate = null;
    @track filterToDate = null;
    @track filterFromDateValue = null;
    @track filterToDateValue = null;
    @track isFilterOpen = false;
    @track filterLabel = 'All Time';

    options = [];

    dropdownIcon = HAM_ICONS + '/dropdown.png';

    trendingNews = TRENDINGNEWS;
    noOlderNewsAvailable = NO_OLDER_NEWS_AVAILABLE;

    localLabel = {
        allTime: AllTime,
        customRange: CustomRange,
        currentNews: CurrentNews,
        olderNews: OlderNews,
        noCurrentNews: NoCurrentNews,
        readMore: ReadMore
    };

    connectedCallback() {
        this.pageSize = window.innerWidth < 1024 ? 3 : 9;
        this._resizeHandler = this.handleResize.bind(this);
        this._outsideClickHandler = this.handleOutsideClick.bind(this);
        window.addEventListener('resize', this._resizeHandler);
        document.addEventListener('click', this._outsideClickHandler);
    }

    disconnectedCallback() {
        window.removeEventListener('resize', this._resizeHandler);
        document.removeEventListener('click', this._outsideClickHandler);
    }

    handleResize() {
        this.screenWidth = window.innerWidth;
        const newPageSize = this.screenWidth < 1024 ? 3 : 9;
        if (newPageSize !== this.pageSize) {
            this.pageSize = newPageSize;
            // Reset both tabs to page 1 — wires re-fire automatically via reactive pageSize
            this.trendingPage = 1;
            this.trendingSkip = 0;
            this.olderPage = 1;
            this.olderSkip = 0;
        }
    }

    get isMobileView() {
        return this.screenWidth < 1024;
    }

    // On mobile always grid; on desktop respect parent toggle
    get effectiveViewMode() {
        return this.isMobileView ? 'grid' : this.view;
    }

    // Returns the Kirkland fallback image when in override mode, otherwise the standard one.
    get defaultImageUrl() {
        return this.isOverride ? DEFAULT_IMAGE_URL_Kirkland : DEFAULT_IMAGE_URL;
    }

    // ==========================================================================
    // Picklist wire
    // ==========================================================================

    @wire(getPicklistValues, {
        objectName: LISTING_OBJECT.objectApiName,
        fieldName: TOPICS_FIELD.fieldApiName
    })
    wiredPicklist({ data, error }) {
        if (data) {
            this.options = [{ label: 'All Topics', value: 'all' }, ...data];
        } else if (error) {
            console.error('Picklist error:', error);
        }
    }

    // ==========================================================================
    // Trending News wires
    // ==========================================================================

    @wire(getNewsConfig, {
        componentKey: 'NewsModuleLWC',
        recordsToSkip: '$trendingSkip',
        fromDate: null,
        toDate: null,
        category: '$filterCurrCategoryValue',
        pageSize: '$pageSize'
    })
    wiredCurrentNewsData({ error, data }) {
        if (data) {
            if (data.isActive && data.records) {
                this.rawDisplayFields = data.displayFields;
                this.fieldMap = data.purposeToApiMap;
                this.processedCurrentNews = this.processRecords(data.records, true);
            }
        } else if (error) {
            console.error('Trending News error:', JSON.stringify(error));
        }
    }

    @wire(getNewsRecordCount, {
        componentKey: 'NewsModuleLWC',
        fromDate: null,
        toDate: null,
        category: '$filterCurrCategoryValue'
    })
    wiredTrendingCount({ data, error }) {
        if (data != null) {
            this.trendingTotal = data;
        } else if (error) {
            console.error('Trending count error:', error);
        }
    }

    // ==========================================================================
    // Older News wires
    // ==========================================================================

    @wire(getNewsConfig, {
        componentKey: 'NewsModuleOldLWC',
        recordsToSkip: '$olderSkip',
        fromDate: '$filterFromDate',
        toDate: '$filterToDate',
        category: '$filterCategoryValue',
        pageSize: '$pageSize'
    })
    wiredOlderNewsData({ error, data }) {
        if (data) {
            if (data.isActive && data.records) {
                this.rawDisplayFields = data.displayFields;
                this.fieldMap = data.purposeToApiMap;
                this.processedOlderNews = this.processRecords(data.records, false);
            }
        } else if (error) {
            console.error('Older News error:', JSON.stringify(error));
        }
    }

    @wire(getNewsRecordCount, {
        componentKey: 'NewsModuleOldLWC',
        fromDate: '$filterFromDate',
        toDate: '$filterToDate',
        category: '$filterCategoryValue'
    })
    wiredOlderCount({ data, error }) {
        if (data != null) {
            this.olderTotal = data;
        } else if (error) {
            console.error('Older count error:', error);
        }
    }

    // ==========================================================================
    // Tab switching
    // ==========================================================================

    handleTabSwitch(event) {
        this.activeNewsTab = event.currentTarget.dataset.tab;
    }

    get isTrendingActive() { return this.activeNewsTab === 'trending'; }
    get isOlderActive()    { return this.activeNewsTab === 'older'; }

    get trendingTabClass() {
        return this.activeNewsTab === 'trending' ? 'pill active-pill' : 'pill inactive-pill';
    }
    get olderTabClass() {
        return this.activeNewsTab === 'older' ? 'pill active-pill' : 'pill inactive-pill';
    }

    // ==========================================================================
    // Featured card + renderer records
    // ==========================================================================

    get trendingRendererRecords() {
        if (!this.processedCurrentNews || this.processedCurrentNews.length === 0) return [];
        return this.processedCurrentNews.map(item => this.flattenItem(item));
    }

    get olderRendererRecords() {
        if (!this.processedOlderNews || this.processedOlderNews.length === 0) return [];
        return this.processedOlderNews.map(item => this.flattenItem(item));
    }

    flattenItem(newsItem) {
        let title = '';
        let description = '';
        let date = '';
        for (const di of newsItem.displayItems) {
            if (di.isTitle)       title       = di.value || '';
            if (di.isDescription) description = di.value || '';
            if (di.isDate)        date        = di.value || '';
        }
        return { id: newsItem.id, imageUrl: newsItem.imageUrl, linkUrl: newsItem.linkUrl, title, description, date };
    }

    get hasTrendingNews() { return this.processedCurrentNews && this.processedCurrentNews.length > 0; }
    get hasOlderNews()    { return this.processedOlderNews   && this.processedOlderNews.length   > 0; }

    // ==========================================================================
    // Pagination handlers
    // ==========================================================================

    handleTrendingPageChange(event) {
        this.trendingPage = event.detail.currentPage;
        this.trendingSkip = event.detail.recordsToSkip;
    }

    handleOlderPageChange(event) {
        this.olderPage = event.detail.currentPage;
        this.olderSkip = event.detail.recordsToSkip;
    }

    // ==========================================================================
    // Category filter handlers
    // ==========================================================================

    toggleCurrDropdown(event) {
        event.stopPropagation();
        this.isCurrOpen = !this.isCurrOpen;
    }

    toggleDropdown(event) {
        event.stopPropagation();
        this.isOpen = !this.isOpen;
    }

    handleOutsideClick(event) {
        if (!this.template.contains(event.target)) {
            this.isOpen = false;
            this.isCurrOpen = false;
        }
    }

    handleCurrSelect(event) {
        const value = event.currentTarget.dataset.value;
        const selected = this.options.find(opt => opt.value === value);
        this.selectedCurrLabel = selected ? selected.label : 'All Topics';
        this.filterCurrCategoryValue = value;
        this.isCurrOpen = false;
        this.trendingPage = 1;
        this.trendingSkip = 0;
    }

    handleSelect(event) {
        const value = event.currentTarget.dataset.value;
        const selected = this.options.find(opt => opt.value === value);
        this.selectedLabel = selected ? selected.label : 'All Topics';
        this.filterCategoryValue = value;
        this.isOpen = false;
        this.olderPage = 1;
        this.olderSkip = 0;
    }

    // ==========================================================================
    // Date filter handlers (Older News only)
    // ==========================================================================

    toggleFilterDropdown() {
        this.isFilterOpen = !this.isFilterOpen;
    }

    handleDateChange(event) {
        const field = event.target.name;
        const dateValue = event.target.value;
        if (field === 'fromDate') {
            this.filterFromDateValue = dateValue;
            this.filterFromDate = dateValue ? `${dateValue} 00:00:00` : null;
        } else if (field === 'toDate') {
            this.filterToDateValue = dateValue;
            this.filterToDate = dateValue ? `${dateValue} 23:59:59` : null;
        }
        this.filterLabel = (this.filterFromDate || this.filterToDate)
            ? this.localLabel.customRange
            : this.localLabel.allTime;
        this.olderPage = 1;
        this.olderSkip = 0;
    }

    handleAllTimeClick(event) {
        event.preventDefault();
        const range = event.currentTarget.dataset.range;
        const today = new Date();
        this.filterToDate = null;
        this.isFilterOpen = false;
        let fromDate = '';
        switch (range) {
            case '30':
                fromDate = this.calculateDate(today, 30);
                this.filterFromDate = fromDate ? `${fromDate} 00:00:00` : null;
                this.filterLabel = 'Last 30 Days';
                break;
            case '180':
                fromDate = this.calculateDate(today, 180);
                this.filterFromDate = fromDate ? `${fromDate} 00:00:00` : null;
                this.filterLabel = 'Last 6 Months';
                break;
            case '365':
                fromDate = this.calculateDate(today, 365);
                this.filterFromDate = fromDate ? `${fromDate} 00:00:00` : null;
                this.filterLabel = 'Last Year';
                break;
            default:
                this.filterFromDate = null;
                this.filterLabel = 'All Time';
                break;
        }
        this.olderPage = 1;
        this.olderSkip = 0;
    }

    calculateDate(baseDate, daysToSubtract) {
        const d = new Date(baseDate);
        d.setDate(d.getDate() - daysToSubtract);
        return d.toISOString().split('T')[0];
    }

    get allTimeClass()     { return this.filterLabel === 'All Time'      ? 'slds-dropdown__item is-selected' : 'slds-dropdown__item'; }
    get last30Class()      { return this.filterLabel === 'Last 30 Days'  ? 'slds-dropdown__item is-selected' : 'slds-dropdown__item'; }
    get last6MonthsClass() { return this.filterLabel === 'Last 6 Months' ? 'slds-dropdown__item is-selected' : 'slds-dropdown__item'; }
    get lastYearClass()    { return this.filterLabel === 'Last Year'      ? 'slds-dropdown__item is-selected' : 'slds-dropdown__item'; }

    // ==========================================================================
    // Record processing (kept from original, with bug fixes)
    // ==========================================================================

    processRecords(records, isCurrentNews) {
        if (!records || records.length === 0) return []; // fix: was bare `return;`
        return records.map((record, index) => {
            const newsItem = { id: record.Id, displayItems: [], imageUrl: null, linkUrl: null };
            for (const fieldMDT of this.rawDisplayFields) {
                const fieldPurpose = fieldMDT.fieldPurpose;
                const fieldApiName = fieldMDT.fieldApiName;
                const fieldValue   = record[fieldApiName];
                newsItem.displayItems.push({
                    key:             `${record.Id}-${fieldApiName}`,
                    order:           fieldMDT.displayOrder,
                    purpose:         fieldPurpose,
                    apiName:         fieldApiName,
                    value:           this.formatFieldValue(fieldValue, fieldPurpose, fieldMDT.fieldType, index, isCurrentNews),
                    fullDescription: fieldPurpose === 'Description' ? fieldValue : null,
                    fullTitle:       fieldPurpose === 'Title'       ? fieldValue : null,
                    isImage:         fieldPurpose === 'Image',
                    isTitle:         fieldPurpose === 'Title',
                    isDescription:   fieldPurpose === 'Description',
                    isDate:          fieldPurpose === 'Start Date',
                    isLink:          fieldPurpose === 'Link'
                });
                if (fieldPurpose === 'Image') newsItem.imageUrl = fieldValue || this.defaultImageUrl;
                if (fieldPurpose === 'Link')  newsItem.linkUrl  = fieldValue || '#';
            }
            if (!newsItem.imageUrl) newsItem.imageUrl = this.defaultImageUrl;
            if (!newsItem.linkUrl)  newsItem.linkUrl  = '#';
            return newsItem;
        });
    }

    formatFieldValue(value, purpose, fieldType, recordIndex, isCurrentNews) {
        if (!value) {
            if (fieldType === 'image' && purpose === 'Image') return this.defaultImageUrl;
            return '';
        }

        // Strip HTML from any text-bearing field regardless of its configured fieldType,
        // because rich-text and long-text-area fields can contain HTML markup.
        if (purpose === 'Description') {
            const clean = stripHtml(value);
            return recordIndex === 0 && isCurrentNews && this.screenWidth >= 1024
                ? this.smartTrim(clean, 400)
                : this.screenWidth >= 1024 ? this.smartTrim(clean, 170) : this.smartTrim(clean, 70);
        }
        if (purpose === 'Title') {
            const clean = stripHtml(value);
            return recordIndex === 0 && isCurrentNews && this.screenWidth >= 1024
                ? this.smartTrim(clean, 200)
                : this.screenWidth >= 1024 ? this.smartTrim(clean, 50) : this.smartTrim(clean, 25);
        }

        switch (fieldType) {
            case 'date':  return this.formatDate(value);
            case 'image': return value || this.defaultImageUrl;
            case 'url':   return value;
            default:      return value;
        }
    }

    formatDate(dateString) {
        if (!dateString) return '';
        return new Date(dateString).toLocaleDateString('en-US', { year: 'numeric', month: 'short', day: 'numeric' });
    }

    smartTrim(text, maxLength) {
        if (!text || text.length <= maxLength) return text;
        const trimmed = text.slice(0, maxLength);
        const lastSpace = trimmed.lastIndexOf(' ');
        return lastSpace > 0 ? trimmed.slice(0, lastSpace) + '...' : trimmed + '...';
    }
}