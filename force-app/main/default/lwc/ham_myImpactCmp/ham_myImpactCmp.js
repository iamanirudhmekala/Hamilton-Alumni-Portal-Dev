import { LightningElement, track, api, wire} from 'lwc';
import { refreshApex } from '@salesforce/apex';

// Importing static resources
import HAM_BADGES from '@salesforce/resourceUrl/HAM_Badges';
import HAM_KIRKLANDBADGES from '@salesforce/resourceUrl/HAM_KirklandBadges';


// Importing Apex methods
import getContactAndPhilanthropyData from '@salesforce/apex/HAM_MyImpactController.getContactAndPhilanthropyData'; 
import getMyServiceAffinitiesData from '@salesforce/apex/HAM_MyImpactController.getMyServiceAffinitiesData';
import getPhilanthropyDetails from '@salesforce/apex/HAM_MyImpactController.getPhilanthropyDetails';

// Importing custom labels
import MyConnections from '@salesforce/label/c.ham_MyConnection';
import MakeAGift from '@salesforce/label/c.ham_MakeAGift';  
import MakeAGiftLink from '@salesforce/label/c.ham_MakeAGiftLink';
import Facebook from '@salesforce/label/c.ham_Facebook';
import Major from '@salesforce/label/c.ham_Major';
import Minor from '@salesforce/label/c.ham_Minor';
import NumberOfYearsGiving from '@salesforce/label/c.ham_NumberOfYearsGiving';
import MyHamiltonDegree from '@salesforce/label/c.ham_MyHamiltonDegree';
import CurrentFiscalYearGiving from '@salesforce/label/c.ham_CurrentFiscalYearGiving';
import LifetimeImpact from '@salesforce/label/c.ham_LifetimeImpact';
import BecauseHamiltonFund from '@salesforce/label/c.ham_BecauseHamiltonFund';
import DeeperDiveIntoMyPhilanthrophy from '@salesforce/label/c.ham_DeeperDiveIntoMyPhilanthrophy';
import MyService from '@salesforce/label/c.ham_myService';
import MyAffinities from '@salesforce/label/c.ham_myAffinities';
import MyContactToVolunteer from '@salesforce/label/c.ham_myContactToVolunteer';
import MyCapusContact from '@salesforce/label/c.ham_myCampusContact';
import MyCampusContactDefaultPhone from '@salesforce/label/c.ham_myCampusContactDefaultPhone';
import MyCampusContactDefaultEmail from '@salesforce/label/c.ham_myCampusContactDefaultEmail';
import MyPhilanthrophyHighlights from '@salesforce/label/c.ham_myPhilanthropyHighlights';
import MyPhilanthropy from '@salesforce/label/c.ham_myPhilanthropy';
import TaxReceiptContent from '@salesforce/label/c.ham_taxReceiptContent';
import DonationHistoryContent from '@salesforce/label/c.ham_donationHistoryContent';
import TaxReceipt from '@salesforce/label/c.ham_taxReceipt';
import DonationHistory from '@salesforce/label/c.ham_donationHistory';
import MyLinkedinProfile from '@salesforce/label/c.ham_MyLinkedinProfile';
import BoardOfTrusteeLable from '@salesforce/label/c.ham_boardOfTrusteeLabel';
import BoardOfTrusteeLink from '@salesforce/label/c.ham_boardOfTrusteeLink';
import VolunteerOpportunity from '@salesforce/label/c.ham_volunteerOpportunity';
import MyImpact from '@salesforce/label/c.ham_MyImpact';
import VolOppTab from '@salesforce/label/c.ham_volunteerOppTab';
import VolActTab from '@salesforce/label/c.ham_myVolunteerActivityTab';
import VolImInterested from '@salesforce/label/c.ham_ImInterested';
import VolWithdraw from '@salesforce/label/c.ham_withdrawButton';
import VolCurrentTab from '@salesforce/label/c.ham_currentActivity';
import VolUpcomingTab from '@salesforce/label/c.ham_upcomingActivity';
import VolPastTab from '@salesforce/label/c.ham_pastActivities';
import VolOppInterestTitle from '@salesforce/label/c.ham_volOppInterestTitle';
import VolOppInterestDesc from '@salesforce/label/c.ham_volOppInterestDesc';
import VolOppWithdrawTitle from '@salesforce/label/c.ham_volOppWithdrawTitle';
import VolOppWithdrawDesc from '@salesforce/label/c.ham_volOppWithdrawDesc';
import AffinityTeamsIPlayed from '@salesforce/label/c.ham_myAffinity_TeamsIPlayed';
import AffinityUnderGradOrg from '@salesforce/label/c.ham_myAffinity_UnderGradOrg';
import AffinityTeamsIFollow from '@salesforce/label/c.ham_myAffinity_TeamsIFollow';
import AffinityButtonPlayedTeam from '@salesforce/label/c.ham_myAffinity_ButtonPlayedTeam';
import AffinityButtonTeamIFollow from '@salesforce/label/c.ham_myAffinity_ButtonTeamIFollow';
import AffinityButtonUnderGOrg from '@salesforce/label/c.ham_myAffinity_ButtonUnderGOrg';
import MyimpactText from '@salesforce/label/c.ham_Myimpact_Menu';
import MyaffinitySectin1 from '@salesforce/label/c.Ham_Myaffinity_Section1';
import MyaffinitySectin2 from '@salesforce/label/c.Ham_Myaffinity_Section2';
import MyaffinitySectin3 from '@salesforce/label/c.Ham_Myaffinity_Section3';
import MyaffinitySectinTitle from '@salesforce/label/c.Ham_Myaffinity_Section_Title';


// Importing static resources
import HAM_ICONS from '@salesforce/resourceUrl/HAM_Icons';


/**
 * @description A comprehensive component to display a user's "My Impact" page.
 * It fetches and processes various data points related to the user's contact information,
 * degrees, philanthropy, service, and affinities.
 */
export default class Ham_myImpactCmp extends LightningElement {
    // Public properties to receive data from a parent component
    @api mainResource;
    @api userContactId;
    @api images={};

    @track contact = {};
    @track majorMinor ={};
    @track facebookUrl;
    @track campusContact = {};
    @track socialMediaLinks = [];
    @track myConnect = [];
    @track personalSection = [];
    @track hcBadges = [];
    @track philanthropySections = [];
    @track philanthropyDetailSections = [];
    @track myServices = [];
    @track myAffinities = [];
    @track philanthropyDataTables = [];
    @track loading = false;
    @track showReceiptsTable = false;
    @track error; // For error handling within this component
    @track isMyImpactActive = true;
    @track isVolunteerActive = false;
    @track isOtherActive = false;
    @track screenWidth = window.innerWidth;
    @api currentVolTab;
    @api isOverride = false;


    wiredServiceAffinitiesResult;  
    tabOrder = 1;  

    showCustomToast = false;   // Added for custom toast toggle
    toastTitle;
    toastVariant;
    toastDuration = 10000;
    toastMessage;

    // Use setter to detect change
    _isProfileUpdated;
    wiredResult;
    wiredPhilanthropyDetailsResult;
    _isProfileUpdatedToken;
    _needsRefresh = false;

    /**
     * @description Consolidated custom label object for easy access and passing to children.
     */
    label = {
        myconnections: MyConnections,
        myhamiltondegree: MyHamiltonDegree,
        numberofyearsgiving: NumberOfYearsGiving,
        currentfiscalyeargiving: CurrentFiscalYearGiving,
        lifetimeimpact: LifetimeImpact,
        becausehamiltonfund: BecauseHamiltonFund,
        deeperdiveintomyphilanthropy: DeeperDiveIntoMyPhilanthrophy,
        makeagift: MakeAGift,
        makeagiftlink: MakeAGiftLink,
        facebook: Facebook,
        major: Major,
        minor:Minor,
        myService: MyService,
        myAffinities: MyAffinities,
        myContactToVolunteer: MyContactToVolunteer,
        mycampuscontact: MyCapusContact,
        myphilanthropyhiglights: MyPhilanthrophyHighlights,
        myphilanthropy: MyPhilanthropy,
        taxreceiptcontent: TaxReceiptContent,
        donationhistorycontent: DonationHistoryContent,
        taxreceipt: TaxReceipt,
        donationhistory: DonationHistory,
        mylinkedinprofile: MyLinkedinProfile,
        boardOfTruteeLabel: BoardOfTrusteeLable,
        boardOfTruteeLink: BoardOfTrusteeLink,
        myImpact: 'MyImpact',
        volunteerOpportunity : VolunteerOpportunity,
        volImInterested: VolImInterested,
        volActTab: VolActTab,
        volOppTab: VolOppTab,
        volUpcomingTab: VolUpcomingTab,
        volCurrentTab: VolCurrentTab,
        volWithdraw: VolWithdraw,
        volOppInterestDesc: VolOppInterestDesc,
        volOppInterestTitle: VolOppInterestTitle,
        volPastTab: VolPastTab,
        volOppWithdrawDesc: VolOppWithdrawDesc,
        volOppWithdrawTitle: VolOppWithdrawTitle,
        myImpact: MyImpact,
        affinityTeamsIPlayed: AffinityTeamsIPlayed,
        affinityUnderGradOrg: AffinityUnderGradOrg,
        affinityTeamsIFollow: AffinityTeamsIFollow,
        affinityButtonPlayedTeam: AffinityButtonPlayedTeam,
        affinityButtonTeamIFollow: AffinityButtonTeamIFollow,
        affinityButtonUnderGOrg: AffinityButtonUnderGOrg,
        myimpactText: MyimpactText,
        myaffinitySectin1: MyaffinitySectin1,
        myaffinitySectin2: MyaffinitySectin2,
        myaffinitySectin3: MyaffinitySectin3,
        myaffinitySectinTitle: MyaffinitySectinTitle




    }

    
    hamIcons = HAM_ICONS;

    icons = {
        hamburgerMobileGreen: this.hamIcons + '/mobile-hamburger-outline-green.png',
    }

    /**
     * @description Static resources object for image URLs.
     */
    resource = {
        hcbadges: HAM_BADGES,
        hckirklandbadges:HAM_KIRKLANDBADGES
    };

    /**
     * @description Lifecycle hook that runs when the component is inserted into the DOM.
     * Sets up event listeners for outside clicks.
     */
     connectedCallback() {
         //  event listener for window resize
        window.addEventListener('resize', this.handleResize.bind(this));
        
        // event listener for outside click
        document.addEventListener('click', this.handleOutsideClick, true);
     }

     disconnectedCallback() {
        window.removeEventListener('resize', this.handleResize.bind(this));
        document.removeEventListener('click', this.handleOutsideClick, true);
        // Ensure scroll is restored
        document.body.style.overflow = '';
        document.documentElement.style.overflow = '';
    }

    handleOutsideClick = (event) => {

        if (!this.isMenuOpen) {
            return;
        }

        const wrapper = this.template.querySelector('.hamtab-wrapper');

        if (wrapper && !wrapper.contains(event.target)) {
            this.isMenuOpen = false;
             // Restore scroll when menu closes
            document.body.style.overflow = '';
            document.documentElement.style.overflow = '';
        }
    }


    /**
     * @description Updates the screen width property on window resize.
     */
    handleResize() {
        this.screenWidth = window.innerWidth;
    }

    /**
    * @description Updates the mobile view property on window resize.
    */
    get isMobileView(){
        return this.screenWidth < 1024;
    }

    /**
    * @description Updates the desktop view property on window resize.
    */
    get isDesktopView(){
        return this.screenWidth > 1024;
    }

    @track isMenuOpen = false;

    get tabContainerClass() {
        return `hamtab-container mobile ${this.isMenuOpen ? 'open' : ''}`;
    }
    get tabContainerClassParent() {
        return `hamtab-wrapper ${this.isMenuOpen ? 'menu-open' : ''}`;
    }

    get sidebarClass() {
    return `tab-child-container ${this.isMenuOpen ? 'open' : ''}`;
}

    toggleMenu() {
        this.isMenuOpen = !this.isMenuOpen;


    if (this.isMenuOpen) {
        document.body.style.overflow = 'hidden';
        document.documentElement.style.overflow = 'hidden';
    } else {
        document.body.style.overflow = '';
        document.documentElement.style.overflow = '';
    }
    }

    /**
     * @description Setter triggered by parent when the "Edit Profile" saves.
     * Expects a unique timestamp to break optimization and force execution.
     * @param {number} value - A unique timestamp or ID indicating an update.
     */
    @api
    set isProfileUpdated(value) {
        // console.log('Profile update token received:', value);

        if (value && value !== this._isProfileUpdatedToken) {
            this._isProfileUpdatedToken = value;
            this._needsRefresh = true;
            this.checkAndRefreshQueue();
        }
    }


    get isProfileUpdated() {
        return this._isProfileUpdatedToken;
    }

    /**
     * @description Centralized Queue Checker to prevent Race Conditions.
     * Waits until ALL THREE wires have provisioned before executing refresh.
     */
    checkAndRefreshQueue() {
        // A wire is only fully provisioned once it contains actual data or an error.
        // If both are undefined, it is the initial empty provision and cannot be refreshed yet.
        const isCoreReady = this.wiredResult && (this.wiredResult.data !== undefined || this.wiredResult.error !== undefined);
        const isDetailsReady = this.wiredPhilanthropyDetailsResult && (this.wiredPhilanthropyDetailsResult.data !== undefined || this.wiredPhilanthropyDetailsResult.error !== undefined);
        const isAffinitiesReady = this.wiredServiceAffinitiesResult && (this.wiredServiceAffinitiesResult.data !== undefined || this.wiredServiceAffinitiesResult.error !== undefined);

        if (this._needsRefresh && isCoreReady && isDetailsReady && isAffinitiesReady) {
            // All wires have returned their initial payload. It is now safe to flush.
            this._needsRefresh = false;
            
            // Queue the refresh slightly to let the LDS cache settle fully before we bust it
            setTimeout(() => {
                this.refreshAllData();
            }, 50);
        }
    }

    /**
     * @description Wire service to fetch core contact and philanthropy highlight data.
     * This method is decorated with `@wire` to automatically call the Apex method and handle
     * the returned data or any errors.
     * @param {Object} wiredContactAndPhilanthropyData The object containing the result from the Apex call.
     */
    @wire(getContactAndPhilanthropyData, { currentUserContactId: '$userContactId' })
    wiredContactAndPhilanthropyData(result) {

        this.wiredResult = result;
        
        const { error, data } = result;
        this.loading = true;
        if (data) {
            // Check for a server-side error message
            if (data.error) {
                this.error = data.error;
                console.error('Apex Error:', this.error);
            
                // The default ShowToastEvent has been replaced with a custom toast component to give us better UI control 
                this.toastTitle = 'Error';
                this.toastMessage = this.error;
                this.toastVariant = 'error';
                this.showCustomToast = true;

                 this.loading = false;
            } else {  
                try {
                    this.loading = true;
                    this.processContactData(data);
                    this.processPhilanthropyData(data, this.philanthropySections);
                    
                    this.error = undefined; 
                    this.loading = false;
                } catch (processingError) {
                    this.loading = true;
                    this.error = 'Error processing data on client-side: ' + processingError.message;
                    console.error('LWC Processing Error:', processingError);
                     this.loading = false;
                  
                    // The default ShowToastEvent has been replaced with a custom toast component to give us better UI control
                    this.toastTitle = 'Error';
                    this.toastMessage = this.error;
                    this.toastVariant = 'error';
                    this.showCustomToast = true;
                }                
            }
        } else if (error) {
            console.error('Error fetching contact data:', error);
          

            // The default ShowToastEvent has been replaced with a custom toast component to give us better UI control
                this.toastTitle = 'Error';
                this.toastMessage = 'An unexpected error occurred while fetching data.';
                this.toastVariant = 'error';
                this.showCustomToast = true;
        }
        this.loading = false;
        
        // Notify the queue that this wire is ready
        this.checkAndRefreshQueue();    
    }

    /**
     * @description Wire service to fetch detailed philanthropy information.
     * This data is typically used for a "Deeper Dive" section.
     * @param {Object} wiredgetPhilanthropyDetails The object containing the result from the Apex call.
     */
    @wire(getPhilanthropyDetails, { currentUserContactId: '$userContactId' })
    wiredgetPhilanthropyDetails(result) {
        this.wiredPhilanthropyDetailsResult = result;
        const { error, data } = result;
        if (data) {
            try {               
                this.processPhilanthropyData(data, this.philanthropyDetailSections);
                this.philanthropyDataTables = data.philanthropyDataTables;
                this.showReceiptsTable = data.showReceiptsTable !== undefined ? data.showReceiptsTable : true;
                this.error = undefined; 
            } catch (processingError) {
                this.error = 'Error processing data on client-side: ' + processingError.message;
                console.error('LWC Processing Error:', processingError);
              

                //The default ShowToastEvent has been replaced with a custom toast component to give us better UI control
                this.toastTitle = 'Error';
                this.toastMessage = this.error;
                this.toastVariant = 'error';
                this.showCustomToast = true;
                
            }            
        }else if (error) {
            console.error('Error fetching philanthropyDetails data:', error);
           

               // The default ShowToastEvent has been replaced with a custom toast component to give us better UI control
                this.toastTitle = 'Error';
                this.toastMessage = 'An unexpected error occurred while fetching data.';
                this.toastVariant = 'error';
                this.showCustomToast = true;
            
        }
        // Notify the queue that this wire is ready
        this.checkAndRefreshQueue();
    }

    /**
     * @description Wire service to fetch service and affinities data.
     * @param {Object} wiredgetMyServiceAffinitiesData The object containing the result from the Apex call.
     */
    @wire(getMyServiceAffinitiesData, { currentUserContactId: '$userContactId' })
    wiredgetMyServiceAffinitiesData(result) {
        this.wiredServiceAffinitiesResult = result;
        const { data, error } = result;
        if (data) {            
            try {
                
                this.myAffinities = [...data.myAffinities];
                this.myAffinities.sort((a, b) => a.order - b.order);
                this.myServices = [...data.myServices];
                this.myServices.sort((a, b) => a.order - b.order);
                this.error = undefined; 
            } catch (processingError) {
                this.error = 'Error processing data on client-side: ' + processingError.message;
                console.error('LWC Processing Error:', processingError);
              

                // The default ShowToastEvent has been replaced with a custom toast component to give us better UI control
                this.toastTitle = 'Error';
                this.toastMessage = this.error;
                this.toastVariant = 'error';
                this.showCustomToast = true;

            }            
        }else if (error) {
            console.error('Error fetching contact data:', error);
         

                // The default ShowToastEvent has been replaced with a custom toast component to give us better UI control
                this.toastTitle = 'Error';
                this.toastMessage = 'An unexpected error occurred while fetching data.';
                this.toastVariant = 'error';
                this.showCustomToast = true;
        }
        // Notify the queue that this wire is ready
        this.checkAndRefreshQueue();
    }

    // refresh my aminities data
    handleRefreshRequest() {
        // This forces the wire to fetch data from the server again
        return refreshApex(this.wiredServiceAffinitiesResult);
    }


    /**
     * @description Processes contact-related data received from Apex and populates component properties.
     * @param {Object} data - The raw data object from the Apex call.
     */
    processContactData(data) {
        if (data.contact) {
            const {name, year} = this.splitNameAndYear(data.contact.name);
            this.contact = {
                id: data.contact.Id,
                name: name,
                year: year,
                userPic: data.contact.userPic,
                linkedin: data.contact.linkedIn,
                isKirklandAlumnae:data.contact.isKirklandAlumnae
            };
        }

        if (data.degree && Array.isArray(data.degree)) {
            if(data.degree.length){
            const majorsArray = data.degree[0].majors ? data.degree[0].majors : '-'
            const minorsArray = data.degree[0].minors ? data.degree[0].minors : '-'

            let majors = majorsArray.filter(major => major !== null && major !== undefined && major.trim() != '');
            let minors = minorsArray.filter(minor => minor !== null && minor !== undefined && minor.trim() != '');
                
                this.majorMinor = {
                    majors: Array.isArray(majors) && majors.length ? majors.join('; ') : '-',
                    minors: Array.isArray(minors) && minors.length ? minors.join('; ') : '-'
                };
            }else{
                this.majorMinor = {
                    majors: '-',
                    minors: '-'
                };
            }
        }

        if (data.otherInfo && data.otherInfo.facebook) {
            this.facebookUrl = data.otherInfo.facebook;
            if (this.facebookUrl && !this.facebookUrl.startsWith('http://') && !this.facebookUrl.startsWith('https://')){
                this.facebookUrl = 'https://' + this.facebookUrl;
            }
        }

        // Build socialMediaLinks: always include all 4 platforms so disabled icons show when empty,
        // mirroring ham_previewProfileCmp behaviour. LinkedIn uses full URL from Contact field;
        // Facebook/Instagram/Twitter use handles from Social_Media__c records.
        const socialMap = {};
        if (data.contact && data.contact.linkedIn) {
            socialMap['LinkedIn'] = data.contact.linkedIn;
        }
        if (data.otherInfo && Array.isArray(data.otherInfo.socialMedia)) {
            data.otherInfo.socialMedia.forEach(item => {
                if (item.platform) {
                    socialMap[item.platform] = item.handle || '';
                }
            });
        }
        this.socialMediaLinks = ['LinkedIn', 'Facebook', 'Instagram', 'Twitter'].map(platform => ({
            platform,
            handle: socialMap[platform] || ''
        }));

        if (data.campusContact) {
            const phone = data.campusContact.phone || MyCampusContactDefaultPhone;
            const email = data.campusContact.email || MyCampusContactDefaultEmail;
            this.campusContact = {
                name: data.campusContact.name,
                phone: `tel:${phone}`,
                phoneLabel: phone,
                email: `mailto:${email}`,
                emailLabel: email
            }
        }

        if (data.myConnect && Array.isArray(data.myConnect)) {
            this.myConnect = data.myConnect;
        }

        if (data.bioData && Array.isArray(data.bioData)) {
            this.personalSection = data.bioData.map(item => {
                const displayLabel = item.displayLabel;
                const displayValue = item.displayValue;
                let href = '';
                let isLink = false;
                let target = '_self';

                if (displayValue) {
                    if (displayLabel === 'Phone Number') {
                        href = `tel:${displayValue.replace(/\s+/g, '')}`;
                        isLink = true;
                    } else if (displayLabel === 'Email Address') {
                        href = `mailto:${displayValue}`;
                        isLink = true;
                    } else if (displayLabel === 'Linkedin') {
                        href = displayValue.startsWith('http') ? displayValue : `https://${displayValue}`;
                        isLink = true;
                        target = '_self'; 
                    }
                }
                return {
                    displayLabel: displayLabel,
                    displayOrder: item.displayOrder,
                    displayValue: displayValue,
                    isLink: isLink,
                    href: href,
                    target: target
                };
            }).sort((a, b) => a.displayOrder - b.displayOrder); // Sort by displayOrder
        }
    }

    /**
     * @description Processes philanthropy-related data received from Apex and organizes it into sections.
     * @param {Object} data - The raw data object from the Apex call.
     * @param {Array} targetArray - The tracked array to which the processed data will be added.
     */
    processPhilanthropyData(data, targetArray) {
        if (data.hcBadges && Array.isArray(data.hcBadges)) {
            // Map: Transform the array and add the imageUrl property
            if(this.isOverride){

                this.hcBadges = data.hcBadges.map(badge => ({
                    ...badge,
                    imageUrl: this.resource.hckirklandbadges + '/' + badge.imageUrl
                }))
                // Sort: Sort the transformed array, placing null/empty values at the end
                .sort((a, b) => {
                    // Use Infinity (or Number.MAX_SAFE_INTEGER) to treat missing values as the highest number.
                    const orderA = a.order || Number.MAX_SAFE_INTEGER;
                    const orderB = b.order || Number.MAX_SAFE_INTEGER;

                    return orderA - orderB;
                });

                this.dispatchEvent(new CustomEvent('badgesloaded', { detail: this.hcBadges }));

            }else{

                this.hcBadges = data.hcBadges.map(badge => ({
                    ...badge,
                    imageUrl: this.resource.hcbadges + '/' + badge.imageUrl
                }))
                // Sort: Sort the transformed array, placing null/empty values at the end
                .sort((a, b) => {
                    // Use Infinity (or Number.MAX_SAFE_INTEGER) to treat missing values as the highest number.
                    const orderA = a.order || Number.MAX_SAFE_INTEGER;
                    const orderB = b.order || Number.MAX_SAFE_INTEGER;

                    return orderA - orderB;
                });

                this.dispatchEvent(new CustomEvent('badgesloaded', { detail: this.hcBadges }));

            }
        }

        if (data.philanthropyField && Array.isArray(data.philanthropyField)) {
            const groupedSections = {};
            data.philanthropyField.forEach(field => {
                const sectionName = field.sectionLabel;
                if (!groupedSections[sectionName]) {
                    // Converting section name to a label key format (e.g., "Current Fiscal Year Giving" -> "currentfiscalyeargiving")
                    let labelKey = sectionName.toLowerCase().replace(/[^a-zA-Z0-9]/g, '');
                    let displayTitle = this.label[labelKey] || sectionName; // Use custom label if available, else use original name

                    groupedSections[sectionName] = {
                        name: sectionName,
                        label: displayTitle,
                        fields: [],
                        order: field.order, // This 'order' is for individual fields, not sections
                        sectionOrder: field.sectionOrder, // this is for section sorting
                        isCurrentFiscalYearGiving: (sectionName === 'Current Fiscal Year Giving'),
                        isShowGift: (sectionName === 'Current Fiscal Year Giving' && data.otherInfo?.isGift)
                    };
                }
                groupedSections[sectionName].fields.push({
                    ...field, 
                    value: this.formattedFieldValue(field.value, field.type),
                    fieldLabelCss: field.label === 'Purpose' ? 'field-label full-width' : 'field-label',
                    fieldValueCss: field.label === 'Purpose' ? 'auto-height prupose-input-container' : 'field-value-box'
                });
            });

            targetArray.splice(0, targetArray.length, ...Object.values(groupedSections).map(section => {
                section.fields.sort((a, b) => a.order - b.order); // Sort fields within each section
                return section;
            }).sort((a, b) => {
                return a.sectionOrder - b.sectionOrder; // Sort sections by their order
            }));
        }
    }

    /**
     * @description Splits a full name string, which may include a class year, into separate name and year parts.
     * @param {string} fullName - The full name string, e.g., "Aron Ain '13".
     * @returns {Object} An object containing the separated 'name' and 'year' strings.
     */
    splitNameAndYear(fullName) {
        const parts = fullName.split(" '");
        let name = parts[0];
        let year = '';

        if (parts.length > 1) {
            year = "'" + parts.slice(1).join(" '");
        }
        return {
            name: name.trim(),
            year: year.trim()
        };
    }

    /**
     * @description Formats a field value based on its type (e.g., currency).
     * @param {*} fieldvalue - The value to format.
     * @param {string} fieldType - The type of the field (e.g., 'currency', 'text').
     * @returns {string} The formatted value.
     */
    formattedFieldValue(fieldvalue, fieldType) {
        if (fieldvalue === null || fieldvalue === undefined || fieldvalue === '') {
            return '';
        }
        switch (fieldType) {
            case 'currency':
                return new Intl.NumberFormat('en-US', {
                    style: 'currency',
                    currency: 'USD',
                    maximumFractionDigits: 2
                }).format(fieldvalue);
            case 'text':
            default:
                return fieldvalue;
        }
    }
    
    /**
     * @description Scrolls the view to the philanthropy detail section with a smooth animation.
     * This is useful for navigation within a single-page layout.
     */
    handleScrollToPhilanthropy() {
        const philanthropyDetailSection = this.template.querySelector('[data-id="philanthropy-detail-section-id"]');
        if (philanthropyDetailSection) {
            philanthropyDetailSection.scrollIntoView({ behavior: 'smooth', block: 'start' });
        } else {
            console.warn('Target section not found on the page.');
        }
    }

   /**
     * @description Custom toast component variable setup for toggle.
     */
    handleErrorClose(){
        this.showCustomToast = false;
    }

    /**
     * @description Catches custom toast events bubbled up from child components
     */
    handleChildToast(event) {
        this.toastTitle = event.detail.title;
        this.toastMessage = event.detail.message;
        this.toastVariant = event.detail.variant;
        this.showCustomToast = true;
    }

    /**
     * Handles tab click events in the mobile navigation
     * @param {Event} event - Click event from tab button
     * Updates active tab state and sets the current volunteer tab type
     */
    handleTabClick(event) {
        const selectedTab = event.currentTarget.dataset.tab;
        
        this.isMyImpactActive = selectedTab === this.label.myImpact;
        this.isVolunteerActive = selectedTab === this.label.volActTab;
        this.isOtherActive = selectedTab === this.label.volunteerOpportunity;
        this.currentVolTab = selectedTab;
        window.scrollTo({ top: 0, behavior: 'instant' });

        // Close menu on selection (mobile)
        this.isMenuOpen = false;
        document.body.style.overflow = '';

        if(this.isMyImpactActive){
            this.tabOrder = 1 ;
        }
        else if(this.isVolunteerActive){
            this.tabOrder = 2 ;
        }
        else if(this.isOtherActive){
            this.tabOrder = 3 ;
        }
    }

    handleMenuClick(event){
        // Close menu on selection (mobile)
        this.isMenuOpen = false;
    }

      /**
     * Handles tab click events in the mobile navigation from parent main component
     * @param {selectedTab} event - Click event from Volunteer opportunity widget buttons
     * Updates active tab state and sets the current volunteer tab type
     */
    @api handleVolunteerHomeClick(selectedTab){
        this.isVolunteerActive = selectedTab === this.label.volActTab;
        this.isOtherActive = selectedTab === this.label.volunteerOpportunity;
        this.isMyImpactActive = selectedTab === this.label.myImpact;
        this.currentVolTab = selectedTab;

        if(this.isMyImpactActive){
            this.tabOrder = 1 ;
        }
        else if(this.isVolunteerActive){
            this.tabOrder = 2 ;
        }
        else if(this.isOtherActive){
            this.tabOrder = 3 ;
        }
    }

    /**
     * Getter: Returns CSS classes for My Impact tab button
     * @returns {string} 'nav-tab nav-active' if active, 'nav-tab nav-inactive' if not
     */
    get myImpactClass() {
        return this.isMyImpactActive ? 'nav-tab nav-active' : 'nav-tab nav-inactive';
    }

    /**
     * Getter: Returns CSS classes for My Volunteer Activities tab button
     * @returns {string} 'nav-tab nav-active' if active, 'nav-tab nav-inactive' if not
     */
    get volunteerClass() {
        return this.isVolunteerActive ? 'nav-tab nav-active' : 'nav-tab nav-inactive';
    }

    /**
     * Getter: Returns CSS classes for Volunteer Opportunities tab button
     * @returns {string} 'nav-tab nav-active' if active, 'nav-tab nav-inactive' if not
     */
    get otherClass() {
        return this.isOtherActive ? 'nav-tab nav-active' : 'nav-tab nav-inactive';
    }

    get wrapperClass() {
        return this.isOverride ? 'myimpact-wrapper kirkland-override' : 'myimpact-wrapper';
    }

    /**
     * Getter: Determines if volunteer component should be displayed
     * @returns {boolean} true if either volunteer tab is active, false otherwise
     * Used to conditionally render the volunteer opportunities component
     */
    get showVolunteerComponent() {
        return this.isVolunteerActive || this.isOtherActive;
    }

    /**
     * Handles navigation to volunteer opportunities from other components
     * @param {Event} event - Custom event with detail containing volunteer tab type
     * Programmatically switches to volunteer opportunities view and updates tab type
     */
    handleNavigateToVolunteer(event){
        this.isVolunteerActive = event.detail === this.label.volActTab;
        this.isOtherActive = event.detail === this.label.volunteerOpportunity;
        this.isMyImpactActive = event.detail === this.label.myImpact;
        
        this.currentVolTab = event.detail;

         if(this.isMyImpactActive){
            this.tabOrder = 1 ;
        }
        else if(this.isVolunteerActive){
            this.tabOrder = 2 ;
        }
        else if(this.isOtherActive){
            this.tabOrder = 3 ;
        }
    }

    /**
     * @description Public method exposed to parent to manually force an Apex Cache flush.
     */
    @api 
    handleProfileUpdated() {
        this.refreshAllData();
    }

    /**
     * @description Helper method to safely invoke refreshApex on all tracked Wire Results.
     * Flushes Lightning Data Service cache to reflect DML updates made elsewhere.
     */
    refreshAllData() {
        this.loading = true;
        const promises = [];
        
        // Push all stored wire results to be refreshed simultaneously
        if (this.wiredResult) promises.push(refreshApex(this.wiredResult));
        if (this.wiredPhilanthropyDetailsResult) promises.push(refreshApex(this.wiredPhilanthropyDetailsResult));
        if (this.wiredServiceAffinitiesResult) promises.push(refreshApex(this.wiredServiceAffinitiesResult));

        Promise.all(promises)
            .then(() => {
                // Ensure UI unlocks only after all data has re-fetched
                this.loading = false;
            })
            .catch(err => {
                console.error('Error refreshing My Impact cache:', err);
                this.loading = false;
            });
    }

}