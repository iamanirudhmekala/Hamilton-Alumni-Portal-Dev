import { LightningElement, api, wire, track } from 'lwc';
import getconnectionrecords from '@salesforce/apex/HAM_AlumniDirectoryController.getDirectoryDataOnWidget';
import { refreshApex } from '@salesforce/apex';

import HAM_ICONS from '@salesforce/resourceUrl/HAM_Icons';
// Importing custom labels
import DirectoryMsg from '@salesforce/label/c.ham_directoryWidgetMessage';

// Display labels used by Apex metadata for the class-year field
// Note: metadata uses "Graduation Year:" (with colon) as the HAM_Display_Label__c value
const CLASS_YEAR_LABELS = ['Graduation Year:', 'Graduation Year', 'Class Year', 'Reunion Year'];

// Cards shown per page on the desktop 2-col grid
const PAGE_SIZE = 2;

// Max cards shown across both pages (4 total)
const MAX_CARDS = 4;

export default class Ham_DirectoryWidget extends LightningElement {

    @api label = {};
    @api images = {};
    @api mainResource;
    @api usercontactId;
    @api isOverride = false;

    @track isProfileOverViewOpen = false;
    @track screenWidth = window.innerWidth;
    @track currentPage = 0;
    @track classmateCurrentPage = 0; // classmates

    selectedContactId;
    wiredConnectionData;
    connectsData = [];
    alumniList = [];

    hamIcons = HAM_ICONS;
     labels = {
         directiryMsg : DirectoryMsg
     }

    imageToUse = {
        avatar:       this.hamIcons + '/profile_big.png',
        avatarNew:    this.hamIcons + '/profile_icon.png',
        kirklandLogo: this.hamIcons + '/kirkland-icon.png',
        arrowLeft:    this.hamIcons + '/arro-left.png',
        arrowLeftGreen:    this.hamIcons + '/arro-left-green.png',
        arrowRight:   this.hamIcons + '/arrow-right.png',
        arrowRightGreen:   this.hamIcons + '/arrow-right-green.png',
    };

    get widgetClass() {
        return this.isOverride ? 'left-panel kirkland-override' : 'left-panel';
    }

    connectedCallback() {
        window.addEventListener('resize', this.handleResize.bind(this));
    }

    disconnectedCallback() {
        window.removeEventListener('resize', this.handleResize.bind(this));
    }

    handleResize() {
        this.screenWidth = window.innerWidth;
    }

    get isDesktopView() {
        return this.screenWidth >= 1024;
    }

    get isMobileView() {
        return this.screenWidth < 1024;
    }

    renderedCallback() {
        refreshApex(this.wiredConnectionData);
    }

    @wire(getconnectionrecords, { portalConstituentId: '$usercontactId' })
    wiredConnectionRecords(result) {
        this.wiredConnectionData = result;
        //console.log('Wired connection data result:', result);
        const { data, error } = result;
        if (data) {
            this.connectsData = data;
            this.currentPage = 0; // reset pagination when data refreshes
        }
        if (error) {
            console.log('Error getting connection data in widgets:', error);
        }
    }

    get connectioncount() {
        return this.connectsData?.connectionCount;
    }

    get isConnectionsData() {
       
        return (this.connectsData.connectionList && this.connectsData.connectionList.length > 0);
    }

    get isConnections() {
        const list = this.connectsData?.connectionList;
        return list?.length ? list.some(item => item.flags?.isConnected === true) : false;
    }

    get isClassmates() {
        return (this.connectsData.alumniList && this.connectsData.alumniList.length > 0);
    }

    get isBookmarks() {
        const list = this.connectsData?.connectionList;
        return list?.length ? list.every(
            item =>
                item.flags?.isBookmarked === true &&
                item.flags?.isConnected === false
        ) : false;
    }

    get isNeither() {
        return !this.isClassmates && !this.isBookmarks;
    }

    get orderedConnectionList() {
        const list = this.connectsData?.connectionList;

        if (!Array.isArray(list) || list.length === 0) {
            return [];
        }

        const allBookmarkedAndNotConnected = list.every(
            item =>
                item.flags?.isBookmarked === true &&
                item.flags?.isConnected === false
        );

        if (!allBookmarkedAndNotConnected) {
            return list;
        }

        return [...list].sort((a, b) => {
            const nameA = a.header?.name?.toLowerCase() || '';
            const nameB = b.header?.name?.toLowerCase() || '';
            return nameA.localeCompare(nameB);
        });
    }

    get orderedClassmatesList() {
        const list = this.connectsData?.alumniList;

        if (!Array.isArray(list) || list.length === 0) {
            return [];
        }

        return [...list].sort((a, b) => {
            const nameA = a.header?.name?.toLowerCase() || '';
            const nameB = b.header?.name?.toLowerCase() || '';
            return nameA.localeCompare(nameB);
        });
    }

    // ── New desktop card-grid getters ────────────────────────────────────────

    // Take at most 4 connections, enrich each with displayName + displayFields
    get enrichedList() {
        return this.orderedConnectionList.slice(0, MAX_CARDS).map(alumni => {
            const fields  = Array.isArray(alumni.fields) ? alumni.fields : [];
            const yearField = fields.find(f =>
                CLASS_YEAR_LABELS.some(l => l.toLowerCase() === (f.label || '').toLowerCase())
            );

            // Format year as 'YY if we found it and it looks like a 4-digit year
            let classYearSuffix = '';
            if (yearField?.value) {
                const yr = String(yearField.value).replace(/\D/g, '');
                classYearSuffix = yr.length >= 4 ? " '" + yr.slice(-2) : yr.length > 0 ? " '" + yr : '';
            }

            // Show Degree and Industry on the card (skip the class-year field)
            const displayFields = fields.filter(f =>
                !CLASS_YEAR_LABELS.some(l => l.toLowerCase() === (f.label || '').toLowerCase())
            );

            return {
                ...alumni,
                displayName:   (alumni.header?.name || '') + classYearSuffix,
                displayFields,
            };
        });
    }

    get hasCards() {
        return this.enrichedList.length > 0;
    }

    // Current page slice (always PAGE_SIZE = 2 items)
    get pagedList() {
        const start = this.currentPage * PAGE_SIZE;
        return this.enrichedList.slice(start, start + PAGE_SIZE);
    }

    get isPrevDisabled() {
        return this.currentPage === 0;
    }

    get isNextDisabled() {
        // Disable right when showing last two cards or fewer than 3 exist
        return this.currentPage >= 1 || this.enrichedList.length <= PAGE_SIZE;
    }

    get prevBtnClass() {
        return `page-arrow-btn${this.isPrevDisabled ? ' page-arrow-disabled' : ''}`;
    }

    get nextBtnClass() {
        return `page-arrow-btn${this.isNextDisabled ? ' page-arrow-disabled' : ''}`;
    }

    handlePrevPage() {
        if (!this.isPrevDisabled) {
            this.currentPage--;
        }
    }

    handleNextPage() {
        if (!this.isNextDisabled) {
            this.currentPage++;
        }
    }

    handleClassmateNextPage() {
        if (!this.isClassmateNextDisabled) {
            this.currentPage++;
        }
    }

    get isClassmateNextDisabled() {
        // Disable right when showing last two cards or fewer than 3 exist
        return this.classmateCurrentPage >= 1 || this.enrichedClassmateList.length <= PAGE_SIZE;
    }
  
    get classmatenextBtnClass() {
        return `page-arrow-btn${this.isClassmateNextDisabled ? ' page-arrow-disabled' : ''}`;
    }

    //
    // Current page slice (always PAGE_SIZE = 2 items)
        get pagedClassmateList() {
            const start = this.classmateCurrentPage * PAGE_SIZE;
            return this.enrichedClassmateList.slice(start, start + PAGE_SIZE);
        }

        get isClassmatePrevDisabled() {
            return this.classmateCurrentPage === 0;
        }

        get isClassmateNextDisabled() {
            return this.classmateCurrentPage >= 1 || this.enrichedClassmateList.length <= PAGE_SIZE;
        }

        get classmateprevBtnClass() {
            return `page-arrow-btn${this.isClassmatePrevDisabled ? ' page-arrow-disabled' : ''}`;
        }

        get classmatenextBtnClass() {
            return `page-arrow-btn${this.isClassmateNextDisabled ? ' page-arrow-disabled' : ''}`;
        }

        handleClassmatePrevPage() {
            if (!this.isClassmatePrevDisabled) {
                this.classmateCurrentPage--;
            }
        }

        handleClassmateNextPage() {
            if (!this.isClassmateNextDisabled) {
                this.classmateCurrentPage++;
            }
        }

    // ── Shared handlers ───────────────────────────────────────────────────────

    handleProfileSelect(event) {
        this.isProfileOverViewOpen = true;
        const selectedContactId = event.currentTarget.dataset.id;
        this.dispatchEvent(
            new CustomEvent('profileoverview', {
                detail: { selectedContactId },
                bubbles: true,
                composed: true
            })
        );
    }

    handleProfileClose() {
        this.isProfileOverViewOpen = false;
        this.selectedContactId = null;
    }

    handleMyImpactNavigation() {
        this.dispatchEvent(new CustomEvent('navigateevent', {
            detail: this.label.alumnidirectory,
            bubbles: true,
            composed: true
        }));
    }

    handleDirectoryNavigation(event) {
        this.handleMyImpactNavigation();
        const navigationCmp = event.currentTarget.dataset.name;
        this.dispatchEvent(new CustomEvent('navigatedirectoryevent', {
            detail: navigationCmp,
            bubbles: true,
            composed: true
        }));
    }


    // classmate logic

     // Take at most 4 connections, enrich each with displayName + displayFields
    get enrichedClassmateList() {
        return this.orderedClassmatesList.slice(0, MAX_CARDS).map(alumni => {
            const fields  = Array.isArray(alumni.fields) ? alumni.fields : [];
            const yearField = fields.find(f =>
                CLASS_YEAR_LABELS.some(l => l.toLowerCase() === (f.label || '').toLowerCase())
            );

            // Format year as 'YY if we found it and it looks like a 4-digit year
            let classYearSuffix = '';
            if (yearField?.value) {
                const yr = String(yearField.value).replace(/\D/g, '');
                classYearSuffix = yr.length >= 4 ? " '" + yr.slice(-2) : yr.length > 0 ? " '" + yr : '';
            }

            // Show Degree and Industry on the card (skip the class-year field)
            const displayFields = fields.filter(f =>
                !CLASS_YEAR_LABELS.some(l => l.toLowerCase() === (f.label || '').toLowerCase())
            );

            return {
                ...alumni,
                displayName:   (alumni.header?.name || '') + classYearSuffix,
                displayFields,
            };
        });
    }

    get hasClassmateCards() {
        return this.enrichedClassmateList.length > 0;
    }


   /*
   get isNextDisabled() {
        // Disable right when showing last two cards or fewer than 3 exist
        return this.currentPage >= 1 || this.enrichedClassmateList.length <= PAGE_SIZE;
    }
   */
}