import { LightningElement, api, track, wire } from 'lwc';
import { publish, subscribe, unsubscribe, MessageContext } from 'lightning/messageService';
import NAVIGATION_CHANNEL from '@salesforce/messageChannel/ham_HomeNavigationChannel__c';
import HEADER_CHANNEL from '@salesforce/messageChannel/ham_HeaderMessageChannel__c';

// Importing custom labels 
import FeedbackLink from '@salesforce/label/c.HAM_FeedbackLink';

// Importing static resources 
import HAM_ICONS from '@salesforce/resourceUrl/HAM_Icons';

export default class Ham_HeaderCmp extends LightningElement {
    @api userProfileUrl;
    @api images;
    @api label;
    @api isStudent = false;
    @api isOverride = false;
    @track isSettingsOpen = false;
    @track activeTab;
    @track screenWidth = window.innerWidth;
    @track logo;
    @track makeagift;

    mainResource = {
            hamIcons: HAM_ICONS
    };

    icons = {
        feedbackIcon: this.mainResource.hamIcons + '/list-view.png',
        hamquadlogo: this.mainResource.hamIcons + '/hamiltonquad-primary-dark-background.png',	
    }

    connectedCallback() {
        this._handleOutsideClick = this.handleOutsideClick.bind(this);
        document.addEventListener('click', this._handleOutsideClick);
        window.addEventListener('resize', this.handleResize.bind(this));

        // Read sessionStorage directly so the active tab highlight survives a hard refresh.
        // In DEV, the header is gated by if:false={isLoading} and mounts AFTER the
        // NAVIGATION_CHANNEL publish fires — so it never receives that message.
        // Reading sessionStorage here bypasses the channel dependency entirely.
        // An empty string means an overlay (Edit Profile / Preferences) was active —
        // fall through to hometitle so no stale tab stays highlighted.
        const storedTab = sessionStorage.getItem('ham_activeTab');
        // null  → key never written (first visit) → default to hometitle
        // ''    → overlay was active (Edit Profile / Preferences) → no tab highlighted
        // value → restore that tab
        this.activeTab = storedTab !== null ? storedTab : (this.label?.hometitle || 'Home');
        this.logo = this.icons?.hamquadlogo || '#';
        this.makeagift = this.label?.makeagiftlink || '#';
        
        this.subscribeToMessageChannel();
    }

    get headerClass() {
        return this.isOverride ? 'hamilton-header kirkland-override' : 'hamilton-header';
    }

    get feedbackLabel(){
        return this.label.feedback;
    }

    get isTestEnvironment() {
        return IsTest == 'TRUE';
    }

    get feedbackIconStyle() {
        return `
            -webkit-mask-image: url(${this.icons.feedbackIcon});
            mask-image: url(${this.icons.feedbackIcon});
        `;
    }


    handleFeedbackClick() {
        window.open(FeedbackLink, '_blank');
        this.isSettingsOpen = false;
    }

    handleResize() {
        this.screenWidth = window.innerWidth;
    }

    @wire(MessageContext)
    messageContext;

    handleNavLinkClick(event) {
        const name = event.target.dataset.name;
        if (name) {
            this.activeTab = name;
            const message = {
                buttonLabel: name
            };
            publish(this.messageContext, HEADER_CHANNEL, message);
        }
    }

    subscribeToMessageChannel() {
        if (!this.subscription) {
            this.subscription = subscribe(
                this.messageContext,
                NAVIGATION_CHANNEL,
                (message) => this.handleMessage(message)
            );
        }
    }

    handleMessage(message) {
        window.scrollTo({ top: 0, behavior: 'instant' });
        if (message && message.selectedItem) {
            this.activeTab = message.selectedItem;
        }
    }

    disconnectedCallback() {
        document.removeEventListener('click', this._handleOutsideClick);
        this.unsubscribeToMessageChannel();
        window.removeEventListener('resize', this.handleResize.bind(this));
    }

    unsubscribeToMessageChannel() {
        if (this.subscription) {
            unsubscribe(this.subscription);
            this.subscription = null;
        }
    }

    get isDesktopView(){
        return this.screenWidth >= 1024;
    }

    // All Getters now use safe navigation ?.
    get computeHomeStyle(){
        return (this.label?.hometitle && this.activeTab === this.label.hometitle) ? `background-color:rgba(255, 255, 255, 0.2);` : '';
    }

    get computeMyImpactStyle(){
        return (this.label?.myimpact && this.activeTab === this.label.myimpact) ? `background-color:rgba(255, 255, 255, 0.2);` : '';
    }

    get computealumnidirectory(){
        return (this.label?.alumnidirectory && this.activeTab === this.label.alumnidirectory) ? `background-color:rgba(255, 255, 255, 0.2);` : '';
    }

    get computeNewsStyle(){
        return (this.label?.news && this.activeTab === this.label.news) ? `background-color:rgba(255, 255, 255, 0.2);` : '';
    }

    get computeVolunteerOppStyle(){
        return (this.label?.volunteerOpportunity && this.activeTab === this.label.volunteerOpportunity) ? `background-color:rgba(255, 255, 255, 0.2);` : '';
    }

    get computeEventsStyle(){
        return (this.label?.events && this.activeTab === this.label.events) ? `background-color:rgba(255, 255, 255, 0.2);` : '';
    }

    get computeGroupsStyle(){
        return (this.label?.groups && this.activeTab === this.label.groups) ? `background-color:rgba(255, 255, 255, 0.2);` : '';
    }

    get computeCommunityStyle(){
        return (this.label?.community && this.activeTab === this.label.community) ? `background-color:rgba(255, 255, 255, 0.2);` : '';
    }

    toggleSettings(event) {
        event.stopPropagation();
        this.isSettingsOpen = !this.isSettingsOpen;
    }

    handleOutsideClick(event) {
        const clickedInside = this.template.contains(event.target);
        if (!clickedInside) {
            this.isSettingsOpen = false;
        }
    }

    handlePreferencesClick() {
        this.isSettingsOpen = false;
        this.dispatchEvent(new CustomEvent('preferences'));
    }

    handleEditProfile() {
        this.isSettingsOpen = false;
        this.dispatchEvent(new CustomEvent('editprofile'));
    }

    handleMakeGiftClick() {
        this.dispatchEvent(new CustomEvent('makegift'));
    }

    handleLogout() {
        this.isSettingsOpen = false;
        this.dispatchEvent(new CustomEvent('logout'));
    }
}