import { LightningElement, api, track, wire } from 'lwc';
import getVolunteerConfig from '@salesforce/apex/HAM_HomePageController.getVolunteerConfig';
import setInterested from '@salesforce/apex/HAM_VolunteerOpportunityController.setInterested';
import withdrawInterest from '@salesforce/apex/HAM_VolunteerOpportunityController.withdrawInterest';
import siteDefaultImageResource from '@salesforce/resourceUrl/HAM_SiteFallbackImage';
import { publish, subscribe, unsubscribe, MessageContext } from 'lightning/messageService';
import VOLUNTEER_SYNC_CHANNEL from '@salesforce/messageChannel/VolunteerOpportunitySync__c';
import AUTO_SLIDE_DELAY from '@salesforce/label/c.ham_gallerySlideDelay';
import siteDefaultImageResourceKirkland from '@salesforce/resourceUrl/HAM_SiteFallbackImage_Kirkland';


// Importing static resources
import HAM_ICONS from '@salesforce/resourceUrl/HAM_Icons';

// Default fallback image for opportunities without images
const DEFAULT_IMAGE_URL = siteDefaultImageResource;
const DEFAULT_IMAGE_URL_Kirkland = siteDefaultImageResourceKirkland;


export default class Ham_VolunteerOpportunities extends LightningElement { 

    // Component configuration keys
    VOLUNTEER_KEY = 'VolunterOppLWC';
    slideDelay = Number(AUTO_SLIDE_DELAY);

    // Public properties from parent component
    @api componentKey;
    @api componentTitle = 'Volunteering Opportunities';
    @api userContactId;
    @api label = {};
    @api images = {};
    @api isOverride = false;

    // Component state
    @track isLoading = true;
    @track configData;
    @track error;
    @track screenWidth = window.innerWidth;
    @track currentSlideIndex = 0;
    @track volunteerOpportunityList = [];
    
    // Tracks which record is currently processing (showing spinner)
    processingInterestId = null;
    
    // Field configuration and mapping
    rawDisplayFields = [];
    fieldMap = {};
    componentType;
    placeholders = [1, 2, 3];
    interestIdMap = {};

    // Lightning Message Service for cross-component sync
    @wire(MessageContext)
    messageContext;
    subscription = null;

    // Modal state variables
    @track showInterestedModal = false;
    @track selectedOpportunityName = '';
    @track selectedValueId = null;
    @track isWithdrawAction = false;
    @track selectedActiveInterestId = null;

    // Carousel and touch interaction state
    autoSlideInterval;
    touchStartX = 0;
    touchEndX = 0;
    swipeDisabled = false;
    touchMoved = false;

      hamIcons = HAM_ICONS;

    icons = {
        arrowRightGreen: this.hamIcons + '/arrow-right-green.png',
        arrowLeftGreen: this.hamIcons + '/arro-left-green.png',
    }

    /**
     * Component initialization - setup event listeners and load data
     */
    connectedCallback() {
        window.addEventListener('resize', this.handleResize.bind(this));
        this.loadVolunteerConfig();
        this.subscribeToMessageChannel();
        this.startAutoSlide();
    }

    /**
     * Cleanup - remove event listeners and subscriptions
     */
    disconnectedCallback() {
        window.removeEventListener('resize', this.handleResize.bind(this));
        this.unsubscribeFromMessageChannel();
        this.stopAutoSlide();
    }

    /**
     * Subscribe to volunteer sync channel for cross-component updates
     */
    subscribeToMessageChannel() {
        this.subscription = subscribe(
            this.messageContext,
            VOLUNTEER_SYNC_CHANNEL,
            (message) => this.handleVolunteerSync(message)
        );
    }

    /**
     * Unsubscribe from message channel
     */
    unsubscribeFromMessageChannel() {
        if (this.subscription) {
            unsubscribe(this.subscription);
            this.subscription = null;
        }
    }

    /**
     * Handle incoming sync messages from other components
     * Updates local opportunity state to match changes made elsewhere
     */
    handleVolunteerSync(message) {
        const { opportunityId, isInterested, activeInterestId } = message;
        this.volunteerOpportunityList = this.volunteerOpportunityList.map(opp => {
            if (opp.id === opportunityId) {
                return {
                    ...opp,
                    isInterested,
                    activeInterestId,
                    buttonLabel: isInterested ? this.label.volImInterested : this.label.volImInterested,
                    buttonClass: isInterested ? 'read-more-btn withdraw-btn' : 'read-more-btn',
                    disableButton: isInterested,
                    buttonClassMobile: isInterested ? 'read-more-btn-mobile withdraw-btn-mobile' : 'read-more-btn-mobile'
                };
            }
            return opp;
        });
    }

    /**
     * Load volunteer opportunities configuration and data from server
     */
    loadVolunteerConfig() {
        getVolunteerConfig({ componentKey: this.VOLUNTEER_KEY })
            .then(result => {
                this.configData = result;
                this.isLoading = true;
                this.error = undefined; 
                this.handleDataLoaded();
            })
            .catch(error => {
                console.error('Error fetching Volunteer Opp data:', error);
                this.configData = null;
                this.error = error;
                this.isLoading = false;
            });
    }

    /**
     * Refresh volunteer configuration data
     */
    refreshVolunteerConfig() {
        return this.loadVolunteerConfig();
    }

    /**
     * Handle window resize - reset carousel to first slide
     */
    handleResize() {
        this.screenWidth = window.innerWidth;
        this.currentSlideIndex = 0;
    }

    /**
     * Returns opportunity list based on screen size
     * Desktop: 2 items, Mobile: all items
     */
    get dynamicOpportunityList() {
        return this.screenWidth >= 1024 ? this.volunteerOpportunityList.slice(0, 2) : this.volunteerOpportunityList;
    }

    /**
     * Check if current viewport is desktop size
     */
    get isDesktopView() {
        return this.screenWidth >= 1024;
    }

    /**
     * Calculate CSS transform for carousel sliding animation
     */
    get carouselTransform() {
        return `transform: translateX(-${this.currentSlideIndex * 100}%);`;
    }

    // Modal computed properties
    get modalTitle() {
        return this.isWithdrawAction ? this.label.volOppWithdrawTitle : this.label.volOppInterestTitle;
    }

    get modalMessage() {
        if (this.isWithdrawAction) {
            return `${this.label.volOppWithdrawDesc} <strong>${this.selectedOpportunityName}</strong>?`;
        }
        return `${this.label.volOppInterestDesc} <strong>${this.selectedOpportunityName}</strong>?`;
    }

    get modalIcon() {
        return this.isWithdrawAction ? 'utility:warning' : 'utility:check';
    }

    get modalIconAlt() {
        return this.isWithdrawAction ? 'Warning' : 'Confirm';
    }

    get modalIconClass() {
        return this.isWithdrawAction ? 'warning-icon-inner' : 'success-icon-inner';
    }

    get modalIconWrapperClass() {
        return this.isWithdrawAction ? 'warning-icon' : 'checkmark-icon';
    }

    get wrapperClass() {
        return this.isOverride ? 'placeholder-widget kirkland-override' : 'placeholder-widget';
    }

    // Returns the Kirkland fallback image when in override mode, otherwise the standard one.
    get defaultImageUrl() {
        return this.isOverride ? DEFAULT_IMAGE_URL_Kirkland : DEFAULT_IMAGE_URL;
    }
 
    /**
     * Process loaded configuration data and prepare opportunities for display
     */
    handleDataLoaded() {
        this.isLoading = true;
      
        if (this.configData && this.configData.isActive && this.configData.records) {
            this.rawDisplayFields = this.configData.displayFields;
            this.fieldMap = this.configData.purposeToApiMap;
            this.componentType = this.configData.componentType;
            this.interestIdMap = this.configData.interestIdMap || {};
            this.volunteerOpportunityList = this.processRecords(this.configData.records);
            this.isLoading = false;
            this.currentSlideIndex = 0;
            
            // Update dot indicators after render
            setTimeout(() => {
                this.updateDotClasses();
            }, 0);
        }
    }

    /**
     * Transform raw records into display-ready opportunity objects
     * Maps fields, handles interest state, and formats data
     */
    processRecords(records) {
        let processedOps = [];
        if (!records || records.length === 0) {
            return processedOps;
        }

        processedOps = records.map((record) => {
            const recordId = record.Id;
            const interestConfig = this.interestIdMap[recordId] || { isInterested: false, activeInterestId: null };
            const isInterested = interestConfig.isInterested || false;
            const activeInterestId = interestConfig.activeInterestId || null;

            const oppItem = {
                id: recordId,
                displayItems: [],
                imageUrl: null,
                title: null,
                isProcessing: this.processingInterestId === recordId,
                isInterested: isInterested,
                activeInterestId: activeInterestId,
                buttonLabel: isInterested ? this.label.volImInterested : this.label.volImInterested,
                buttonClass: isInterested ? 'read-more-btn withdraw-btn' : 'read-more-btn',
                disableButton: isInterested,
                buttonClassMobile: isInterested ? 'read-more-btn-mobile withdraw-btn-mobile' : 'read-more-btn-mobile'
            };

            // Map each field from configuration to display item
            for (const fieldMDT of this.rawDisplayFields) {
                const fieldPurpose = fieldMDT.fieldPurpose;
                const fieldApiName = fieldMDT.fieldApiName;
                const fieldValue = record[fieldApiName];

                oppItem.displayItems.push({
                    key: `${recordId}-${fieldApiName}`,
                    order: fieldMDT.displayOrder,
                    purpose: fieldPurpose,
                    apiName: fieldApiName,
                    titleValue: fieldValue,
                    value: this.formatFieldValue(fieldValue, fieldPurpose, fieldMDT.fieldType),
                    isImage: fieldPurpose === 'Image',
                    isTitle: fieldPurpose === 'Title',
                    isDescription: fieldPurpose === 'Description',
                    isLink: fieldPurpose === 'Link'
                });

                // Set quick-access properties
                if (fieldPurpose === 'Image') {
                    oppItem.imageUrl = fieldValue || this.defaultImageUrl;
                }
                if (fieldPurpose === 'Title') {
                    oppItem.title = fieldValue || '';
                }
            }

            // Ensure every opportunity has an image
            if (!oppItem.imageUrl) {
                oppItem.imageUrl = this.defaultImageUrl;
            }
            
            return oppItem;
        });
        return processedOps;
    }

    /**
     * Update processing state for all opportunities
     * Shows spinner on the opportunity currently being updated
     */
    updateOpportunitiesProcessingState() {
        this.volunteerOpportunityList = this.volunteerOpportunityList.map(opp => ({
            ...opp,
            isProcessing: this.processingInterestId === opp.id
        }));
    }

    /**
     * Format field value based on type and purpose
     * Handles text truncation for descriptions and image defaults
     */
    formatFieldValue(value, purpose, fieldType) {
        if (!value) {
            if (fieldType === 'image' && purpose === 'Image') {
                return this.defaultImageUrl;
            }
            return '';
        }

        switch (fieldType) {
            case 'text':
                if (purpose === 'Description') {
                    return this.screenWidth >= 1024 ? this.smartTrim(value, 110) : this.screenWidth <= 500 ? this.smartTrim(value, 80) : this.smartTrim(value, 100);
                }
                return value;
            case 'image':
                return value || this.defaultImageUrl;
            default:
                return value;
        }
    }

    /**
     * Trim text to specified length at word boundary
     * Adds ellipsis if text is truncated
     */
    smartTrim(text, maxLength) {
        if (!text || text.length <= maxLength) return text;
        
        const trimmed = text.substr(0, maxLength);
        const lastSpace = trimmed.lastIndexOf(' ');
        
        return lastSpace > 0 
            ? trimmed.substr(0, lastSpace) + '...' 
            : trimmed + '...';
    }

    /**
     * Navigate to My Impact tab when user wants to see all opportunities
     */
    handleMyImpactNavigation() {
        this.dispatchEvent(new CustomEvent('navigateevent', {
            detail: this.label.volunteerOpportunity,
            bubbles: true,
            composed: true
        }));
    }

    /**
     * Start automatic slide rotation
     * Pauses when modal is open or during swipe interaction
     */
    startAutoSlide() {
        if (this.autoSlideInterval) return;
        this.autoSlideInterval = setInterval(() => {
            if (!this.swipeDisabled && !this.showInterestedModal) {
                this.handleNextSlide();
            }
        }, this.slideDelay);
    }

    /**
     * Stop automatic slide rotation
     */
    stopAutoSlide() {
        clearInterval(this.autoSlideInterval);
        this.autoSlideInterval = null;
    }

    /**
     * Navigate to previous slide (circular)
     */
    handlePrevSlide() {
        if (this.currentSlideIndex > 0) {
            this.currentSlideIndex--;
        } else {
            this.currentSlideIndex = this.dynamicOpportunityList.length - 1;
        }
        this.updateDotClasses();
    }

    /**
     * Navigate to next slide (circular)
     */
    handleNextSlide() {
        if (this.currentSlideIndex < this.dynamicOpportunityList.length - 1) {
            this.currentSlideIndex++;
        } else {
            this.currentSlideIndex = 0;
        }
        this.updateDotClasses();
    }

    /**
     * Navigate to specific slide when dot indicator is clicked
     */
    handleDotClick(event) {
        const index = parseInt(event.target.dataset.index, 10);
        if (!isNaN(index)) {
            this.currentSlideIndex = index;
            this.updateDotClasses();
        }
    }

    /**
     * Update active state of carousel dot indicators
     */
    updateDotClasses() {
        requestAnimationFrame(() => {
            const dots = this.template.querySelectorAll('.carousel-dot');
            dots.forEach((dot, index) => {
                if (index === this.currentSlideIndex) {
                    dot.classList.add('active');
                } else {
                    dot.classList.remove('active');
                }
            });
        });
    }

    /**
     * Capture starting X coordinate for swipe detection
     */
    handleTouchStart(e) {
        if (this.swipeDisabled) return;
        this.touchStartX = e.touches[0].clientX;
        this.touchMoved = false;
    }

    /**
     * Track finger movement during swipe
     */
    handleTouchMove(e) {
        if (this.swipeDisabled) return;
        this.touchEndX = e.touches[0].clientX;

        if (Math.abs(this.touchStartX - this.touchEndX) > 10) {
            this.touchMoved = true;
        }
    }

    /**
     * Determine swipe direction and navigate slides accordingly
     * Requires minimum 50px swipe distance to trigger
     */
    handleTouchEnd() {
        if (this.isDesktopView || this.swipeDisabled) return;  
        if (!this.touchMoved) return;

        const diff = this.touchStartX - this.touchEndX;
        if (Math.abs(diff) < 50) return;

        diff > 0 ? this.handleNextSlide() : this.handlePrevSlide(); 
    }

    // ========== INTERESTED MODAL HANDLERS ==========

    /**
     * Open confirmation modal for interest or withdraw action
     */
    openInterestedModal(event) {
        this.selectedValueId = event.target.dataset.id;
        this.selectedOpportunityName = event.target.dataset.oppName;
        this.isWithdrawAction = event.target.dataset.isInterested === 'true';
        this.selectedActiveInterestId = event.target.dataset.interestId;
        this.showInterestedModal = true;
    }

    /**
     * Close modal and resume auto-slide
     */
    closeInterestedModal() {
        this.showInterestedModal = false;
        this.swipeDisabled = false;
        this.resetModalState();
        this.startAutoSlide();
    }

    /**
     * Execute confirmed action (interest or withdraw)
     */
    confirmAction() {
        if (this.isWithdrawAction) {
            this.handleWithdraw();
        } else {
            this.handleSetInterest();
        }
    }

    /**
     * Handle user expressing interest in opportunity
     * Updates UI immediately and publishes sync message
     */
    handleSetInterest() {
        this.showInterestedModal = false;
        const valId = this.selectedValueId;
        
        this.processingInterestId = valId;
        this.updateOpportunitiesProcessingState();
        
        setInterested({ interestValueId: valId, currentUserContactId: this.userContactId })
            .then((result) => {
                // Update local state immediately
                this.volunteerOpportunityList = this.volunteerOpportunityList.map(opp => {
                    if (opp.id === valId) {
                        return {
                            ...opp,
                            isInterested: true,
                            activeInterestId: result,
                            disableButton: true,
                            buttonLabel: this.label.volImInterested,
                            buttonClass: 'read-more-btn withdraw-btn',
                            buttonClassMobile: 'read-more-btn-mobile withdraw-btn-mobile',
                            isProcessing: false
                        };
                    }
                    return opp;
                });
                
                // Publish sync message to other components
                publish(this.messageContext, VOLUNTEER_SYNC_CHANNEL, {
                    opportunityId: valId,
                    isInterested: true,
                    activeInterestId: result
                });
            })
            .catch(error => {
                console.error('Error setting interest:', JSON.stringify(error));
            })
            .finally(() => {
                this.processingInterestId = null;
                this.isModalProcessing = false;
                this.updateOpportunitiesProcessingState();
                this.resetModalState();
            });
    }

    /**
     * Handle user withdrawing interest from opportunity
     * Updates UI immediately and publishes sync message
     */
    handleWithdraw() {
        this.showInterestedModal = false;
        const interestId = this.selectedActiveInterestId;
        const valId = this.selectedValueId;
        
        if (!interestId) {
            console.error('No active interest ID found for withdrawal');
            this.resetModalState();
            return;
        }
        
        this.processingInterestId = valId;
        this.updateOpportunitiesProcessingState();
        
        withdrawInterest({ interestId: interestId })
            .then(() => {
                // Update local state immediately
                this.volunteerOpportunityList = this.volunteerOpportunityList.map(opp => {
                    if (opp.id === valId) {
                        return {
                            ...opp,
                            isInterested: false,
                            activeInterestId: null,
                            buttonLabel: this.label.volImInterested,
                            buttonClass: 'read-more-btn',
                            buttonClassMobile: 'read-more-btn-mobile',
                            isProcessing: false
                        };
                    }
                    return opp;
                });
                
                // Update interest map
                this.interestIdMap[valId] = {
                    isInterested: false,
                    activeInterestId: null
                };
                
                // Publish sync message to other components
                publish(this.messageContext, VOLUNTEER_SYNC_CHANNEL, {
                    opportunityId: valId,
                    isInterested: false,
                    activeInterestId: null
                });
            })
            .catch(error => {
                console.error('Error withdrawing interest:', error);
                console.error('Error message:', error.body?.message || error.message);
                console.error('InterestId:', interestId, 'ValueId:', valId);
            })
            .finally(() => {
                this.processingInterestId = null;
                this.isModalProcessing = false;
                this.updateOpportunitiesProcessingState();
                this.resetModalState();
            });
    }

    /**
     * Reset modal state variables
     */
    resetModalState() {
        this.selectedOpportunityName = '';
        this.selectedValueId = null;
        this.isWithdrawAction = false;
        this.selectedActiveInterestId = null;
    }

    /**
     * Handle user on tab click navigation to event
     */
    handleVolunteerClick(event){
        const tabSelected = event.currentTarget.dataset.name;
        
        this.dispatchEvent(new CustomEvent('navigatevolevent', {
                detail: tabSelected,
                bubbles: true,
                composed: true
            }));
    }
}