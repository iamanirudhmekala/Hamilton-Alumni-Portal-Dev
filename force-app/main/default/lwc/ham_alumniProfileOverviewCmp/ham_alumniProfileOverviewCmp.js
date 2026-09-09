import { LightningElement, api,wire,track } from 'lwc';

//Import Lightning Message Service — tells the home page its Directory thumbnail is stale
import { publish, MessageContext } from 'lightning/messageService';
import THUMBNAIL_REFRESH_CHANNEL from '@salesforce/messageChannel/ham_HomeThumbnailRefresh__c';

//Importing apex methods
import getAlumniOverview from '@salesforce/apex/HAM_AlumniProfileOverviewController.getAlumniOverview'; 
import getConnectionStatus from '@salesforce/apex/HAM_AlumniProfileOverviewController.getConnectionStatus';
import handleConnectionRequest from '@salesforce/apex/HAM_AlumniConnectionService.handleConnectionRequest';
import checkUserStatus from '@salesforce/apex/HAM_AlumniConnectionService.checkUserStatus';

//Importing static resource
import HAM_ICONS from '@salesforce/resourceUrl/HAM_Icons';

import { refreshApex } from '@salesforce/apex';

// Import custom labels
import SendRequest from '@salesforce/label/c.HAM_Send_Request';
import RemoveCoonection from '@salesforce/label/c.HAM_Remove_Connection';
import CancelRequest from '@salesforce/label/c.HAM_Cancel_Request';
import ActionSRHeader from '@salesforce/label/c.HAM_Personal_Mess';
import ActionSRPrimaryBtn from '@salesforce/label/c.HAM_Primary_Btn';
import ActionSRSecondaryBtn from '@salesforce/label/c.HAM_Secondary_Button';
import ActionRCHeader from '@salesforce/label/c.HAM_Remove_Conn';
import ActionRCSecondaryBtn from '@salesforce/label/c.HAM_Secondry_Button';
import InvitationExist from '@salesforce/label/c.ham_InvitationExist';
import unBlockProfile from '@salesforce/label/c.HAM_Unblock_Profile';
import unblockProfileHeader from '@salesforce/label/c.HAM_Unblock_Profile_Header';
import unblockProfileButton from '@salesforce/label/c.HAM_Unblock_Profile_Button';
import InActiveUserMessage from '@salesforce/label/c.ham_inactiveUserMessage';
import SendRequestHoverText from '@salesforce/label/c.HAM_sendRequestHoverText';
import CancelRequestHoverText from '@salesforce/label/c.HAM_cancelRequestHoverText';
import RemoveConnectionHoverText from '@salesforce/label/c.HAM_removeConnectionHoverText';
import UnBlockHoverText from '@salesforce/label/c.HAM_unblockHoverText';
import ToastMessageReqSend from '@salesforce/label/c.ham_ToastMessage_ReqSend';
import ToastMessageCancelReq from '@salesforce/label/c.ham_ToastMessage_CancelReq';
import NecrologyTitle from '@salesforce/label/c.ham_necrologyTitle';
import NecrologyHelpText from '@salesforce/label/c.ham_necrologyHelpText';
import NecrologyLink from '@salesforce/label/c.ham_necrologyLink';
import AcceptHoverText from '@salesforce/label/c.HAM_acceptHoverText';
import RejectHoverText from '@salesforce/label/c.HAM_rejectHoverText';


// Constants for actions (these don't need labels)
const ACTIONS = {
    SEND_REQUEST: SendRequest,
    REMOVE_CONNECTION: RemoveCoonection,
    CANCEL_REQUEST: CancelRequest,
    UNBLOCK_PROFILE:unBlockProfile
};

// Modal configurations using imported labels directly
const MODAL_CONFIG = {
    [ACTIONS.SEND_REQUEST]: {
        header: ActionSRHeader,
        primaryButton: ActionSRPrimaryBtn,
        secondaryButton: ActionSRSecondaryBtn,
        isRequestModal: true,
        showPrimaryButton: true
    },
    [ACTIONS.REMOVE_CONNECTION]: {
        header: ActionRCHeader,
        primaryButton: RemoveCoonection,
        secondaryButton: ActionRCSecondaryBtn,
        isRequestModal: false,
        showPrimaryButton: true
    },
    [ACTIONS.UNBLOCK_PROFILE]: {
        header: unblockProfileHeader,
        primaryButton: unblockProfileButton,
        secondaryButton: ActionRCSecondaryBtn,
        isRequestModal: false,
        showPrimaryButton: true
    }
};
export default class Ham_alumniProfileOverviewCmp extends LightningElement {

    @wire(MessageContext) messageContext;

    @api profile;
    @api contactId;
    @api mainResource;
    @api currentUserContactId;
    @api isOverride = false;

    get wrapperClass() {
        return this.isOverride ? 'alumni-overview-wrapper kirkland-override' : 'alumni-overview-wrapper';
    }

    get isNotCurrentUser() {
        return this.contactId !== this.currentUserContactId;
    }
    wiredConnectionsResult;
    @api images = {};
    @api label = {};
    @api isStudent;
    buttonState;
    isSendIcon;
    isDisabled;
    buttonClass;
    isLoggedUserPrivacyOn = false;   // logged-in user's connection privacy
    profileOverviewData;
    showCustomToast = false;
    buttonHover = '';
    //hasLinkedIn = false;
    @track screenWidth = window.innerWidth;

    wiredOverviewResult;   // holds the provisioned wire result for refreshApex
    _overviewRefreshed = false;
    _lastRefreshedContactId;     // overview: refresh once per contactId
    _lastConnContactId;          // connection status: refresh once per contactId
    
    // Selected action/user for modal
    showRequestModal = false;
    clickedFunctiontype = null;
    personalizedMessage = '';

    // Modal button & header labels
    modalSecondaryButton = '';
    modalPrimaryButton = '';
    modalHeader = '';
    isRequestModal = false;
    showPrimaryButton = false;
    primaryButtonClass= 'primary-button';
    secondaryButtonClass = 'secondary-button';
    isInactiveUser = false;
    isIncomingRequest = false;

    // Labels object
    localLabel = {
        sendRequest: SendRequest,
        removeConnection: RemoveCoonection,
        cancelRequest: CancelRequest,
        actionSRHeader: ActionSRHeader,
        actionSRPrimaryBtn: ActionSRPrimaryBtn,
        actionSRSecondaryBtn: ActionSRSecondaryBtn,
        actionRCHeader: ActionRCHeader,
        actionRCSecondaryBtn: ActionRCSecondaryBtn,
        invitationExist: InvitationExist,
        inActiveUserMessage : InActiveUserMessage,
        sendRequestHoverText : SendRequestHoverText,
        cancelRequestHoverText : CancelRequestHoverText,
        removeConnectionHoverText : RemoveConnectionHoverText,
        unBlockHoverText : UnBlockHoverText,
        toastMessageReqSend : ToastMessageReqSend,
        toastMessageCancelReq : ToastMessageCancelReq,
        necrologyLink : NecrologyLink,
        necrologyHelpText : NecrologyHelpText,
        necrologyTitle : NecrologyTitle,
        rejectHoverText : RejectHoverText,
        acceptHoverText : AcceptHoverText
    };

    hamicons = {
       kirklandLogo: `${HAM_ICONS}/kirkland-icon.png`,
       profileIcon: `${HAM_ICONS}/profile_icon.png`,
       person: `${HAM_ICONS}/person.png`,
       chat: `${HAM_ICONS}/chat.png`,
       close: `${HAM_ICONS}/cross_black.png`,
        profile: `${HAM_ICONS}/profile_icon.png`,
        facebook: `${HAM_ICONS}/facebook.png`,
        instagram: `${HAM_ICONS}/instagram.png`,
        twitter: `${HAM_ICONS}/twitter.png`,
        linkedin: `${HAM_ICONS}/linkedin.png`
    }
    

    /**
     * @description - Fires a custom 'back' event to notify parent component for navigation.
     *
     * @returns {void}
     */
    handleBack() {
        this.dispatchEvent(new CustomEvent('back'));
    }

   

    /**
     * @description Lifecycle hook that runs when the component is inserted into the DOM.
     * It sets up event listeners for window resize .
     */
    connectedCallback() {
        //  event listener for window resize
        window.addEventListener('resize', this.handleResize.bind(this));

       
        
    }

    /**
     * @description Lifecycle hook that runs when the component is removed from the DOM.
     * It removes event listeners to prevent memory leaks.
     */
    disconnectedCallback() {
     
        // Remove event listener when component is removed from DOM
        window.removeEventListener('resize', this.handleResize.bind(this));

    }

    

    renderedCallback() {
       
        // your existing connection-status refresh
        if (this.wiredConnectionsResult) {
            refreshApex(this.wiredConnectionsResult);
        }
    }

    /**
     * @description Updates the screen width property on window resize.
     */
    handleResize() {
        this.screenWidth = window.innerWidth;
    }

    /**
     * @description Determines whether the current view is desktop based on screen width.
     * @returns {Boolean} True if desktop view (>= 1024px)
     */
    get isDesktopView() {
        // Define desktop breakpoint (e.g., 769px or more)
        return this.screenWidth >= 1024;
    }

    /**
     * @description Determines whether the current view is mobile based on screen width.
     * @returns {Boolean} True if mobile view (< 1024px)
     */
    get isMobileView() {
        return this.screenWidth < 1024;
    }

    /**
     * @description Fetches connection status between current user and selected contact.
     * @param {Object} result - Wired Apex result containing data or error
     */
    @wire(getConnectionStatus, {portalId : '$currentUserContactId', constituentId : '$contactId'})
    wiredConnections(result) {
        this.wiredConnectionsResult = result;
        const { data, error } = result;
        if(data){
            this.isDisabled = data.isDisable;
            this.isSendIcon = data.isSendRequest;
            this.buttonState = data.label;
            this.isIncomingRequest = data.label == 'Accept' ? true : false;
            this.buttonHover = this.getbuttonHover(data.label);
            this.buttonClass = data.cssClass;
            this.isLoggedUserPrivacyOn = data.protalLogedUserPrivacy === true;   // NEW
            

        }else if(error){
            console.log('Error occured '+error);
        }
    }

   /**
     * @description Hide the Send Request button when the target isn't accepting
     * connections (isConnection === false) OR the logged-in user has connection
     * privacy on. All other actions (Cancel/Remove/Unblock/Accept) stay visible.
     */
    get showConnectionButton() {
        const card = this.profileOverviewData?.[0];
        const isConnected = Boolean(card?.isConnection);
        const loggedUserPrivacy = Boolean(card?.protalLogedUserPrivacy);
        return !(this.isSendRequestState && (!isConnected || loggedUserPrivacy));
    }

    getbuttonHover(buttonState){
        if (buttonState == 'Unblock') return this.label.unBlockHoverText;
        if (buttonState == 'Remove Connection') return this.label.removeConnectionHoverText;
        if (buttonState == 'Cancel Request') return this.label.cancelRequestHoverText;
        return this.label.sendRequestHoverText;
    }

    get isSendRequestState() {
        return this.buttonState === ACTIONS.SEND_REQUEST;
    }

   /**
     * @description Targets ONLY the 'Send Request' state. 
     * If it's any other action state, it returns false immediately so they remain enabled.
     */
    get isButtonDisabled() {
        // Guard clause: If it's NOT the Send Request state, do absolutely nothing (keep it enabled)
        if (!this.isSendRequestState) {
            return false;
        }
        
        // If it IS the Send Request state, disable it only if they are not connected
        const isConnected = Boolean(this.profileOverviewData?.[0]?.isConnection);
        return !isConnected;
    }

    /**
     * @description Appends the 'disable' style class ONLY when the button is genuinely disabled.
     */
    get computedButtonClass() {
        // return this.isButtonDisabled ? `${this.buttonClass} -  disable` : this.buttonClass;
        return this.isButtonDisabled ? `${this.buttonClass.replace('active', '')}  disable` : this.buttonClass;
    }
    
    
    /**
     * @description Retrieves alumni profile overview data for selected contact.
     * @param {Object} response - Wired Apex response with data or error
     */
    @wire(getAlumniOverview, { contactId: '$contactId', portalId: '$currentUserContactId'})
        connectiondata(result){
            this.wiredOverviewResult = result;       // store for refresh
             const { data, error } = result;
         if(data){
        //    this.profileOverviewData = data;
            this.profileOverviewData = data.map(alumni => {

                const isDeceased = alumni.isDeseasedAlumnae || (alumni.header && alumni.header.isDeseasedAlumnae);
                let processedPersonalInfo = alumni.personalInfofields || [];
                let processedCampusLife = alumni.campusLifefields || [];

                if (isDeceased) {
                    processedPersonalInfo = processedPersonalInfo.filter(
                        section => section.label === 'Full Name'
                    );
                }

                //  Add UI flag for Personal Info fields
                processedPersonalInfo = processedPersonalInfo.map(section => {

                    const isEmail = section.label && section.label.toLowerCase() === 'email';
                    const isEmployer = section.label && section.label.toLowerCase() === 'employer';
                    const isIndustry = section.label && section.label.toLowerCase() === 'industry';
                    const isJobTitle = section.label && section.label.toLowerCase() === 'job title';

                    return {
                        ...section,
                        isEmail,
                        isEmployer,
                        isIndustry,
                        isJobTitle,
                        showField: !this.isStudent || !(isEmployer || isIndustry || isJobTitle)
                    };
                });

                 //  Add UI flag for Campus Life SECTIONS fields
                processedCampusLife = processedCampusLife.map(section => {

                    const label = section.label ? section.label.toLowerCase() : '';

                    const isResidencehall = label === 'residence halls';

                    return {
                        ...section,
                        isResidencehall,

                        // hide only when student AND residence hall
                        showField: !this.isStudent || !isResidencehall
                    };
                });


                return {
                    ...alumni,
                    personalInfofields: processedPersonalInfo,
                    campusLifefields: processedCampusLife
                };
            });

            // Force a fresh DB read once per contactId — busts the cacheable cache
            // so protalLogedUserPrivacy reflects the latest privacy record.
            if (this._lastRefreshedContactId !== this.contactId) {
                this._lastRefreshedContactId = this.contactId;
                refreshApex(result);
            }

           //console.log('this.profileOverviewData :',JSON.stringify(this.profileOverviewData));

         }
         if(error){
           console.log('Error getting Profile Overview Contact data  :',error);
         }
        }

    /**
     * @description Returns profile overview data with LinkedIn visibility flag.
     * @returns {Array} Processed alumni overview list
     */
    get profileOverviewDataSafe() {
      return (this.profileOverviewData || []).map(alumni => ({
          ...alumni,
          showLinkedIn:
              Array.isArray(alumni.socialMediafields) &&
              alumni.socialMediafields.some(
                  item => item.label === 'LinkedIn Icon' && item.value === true
              )
      }));
    } 
   
   get emailHref() {
        const fields = this.profileOverviewData?.[0]?.personalInfofields || [];

        const emailField = fields.find(f => f.label === 'Email');

        return emailField ? `mailto:${emailField.value}` : '';
    }
   
    /**
     * @description Determines social media link availability of URL.
     * @returns {String} CSS class name
     */
    
    get linkedinClass() {
        if (this.profileOverviewData?.[0].isDeseasedAlumnae) return 'my-social-link my-social-link-disabled';
        const linkedInUrl = this.profileOverviewData?.[0]?.contactlinkedInUrl;
        const hasLinkedIn = !!linkedInUrl?.trim();
        return hasLinkedIn ? 'my-social-link' : 'my-social-link my-social-link-disabled';
    }

    get instaClass() {
        if (this.profileOverviewData?.[0].isDeseasedAlumnae) return 'my-social-link my-social-link-disabled';
        const instaUrl = this.profileOverviewData?.[0]?.instagramUrl;
        const hasInsta = !!instaUrl?.trim();
        return hasInsta ? 'my-social-link' : 'my-social-link my-social-link-disabled';
    }

    get facebookClass() {
        if (this.profileOverviewData?.[0].isDeseasedAlumnae) return 'my-social-link my-social-link-disabled';
        const facebookUrl = this.profileOverviewData?.[0]?.facebookUrl;
        const hasFacebook = !!facebookUrl?.trim();
        return hasFacebook ? 'my-social-link' : 'my-social-link my-social-link-disabled';
    }

    get twitterClass() {
        if (this.profileOverviewData?.[0].isDeseasedAlumnae) return 'my-social-link my-social-link-disabled';
        const twitterUrl = this.profileOverviewData?.[0]?.twitterUrl;
        const hasTwitter = !!twitterUrl?.trim();
        return hasTwitter ? 'my-social-link' : 'my-social-link my-social-link-disabled';
    }

    /**
     * @description Handles action button clicks for sending requests, removing bookmarks or connections.
     * Sets modal configuration based on the action and opens the modal if applicable.
     */
    async handleButtonClick(event) {
        this.clickedFunctiontype = event.currentTarget.dataset.name;
       
        let userStatus;
        if(this.clickedFunctiontype  == ACTIONS.SEND_REQUEST){
            this.isLoading = true;
            userStatus = await checkUserStatus({ linkedConstituentId: this.contactId });
            this.isLoading = false;
            
        }
        const config = MODAL_CONFIG[this.clickedFunctiontype];
        if(userStatus == 'Inactive User'){
            this.isInactiveUser = true;
                Object.assign(this, {
                    modalHeader: config.header,
                    modalPrimaryButton: config.primaryButton,
                    modalSecondaryButton: config.secondaryButton,
                    showPrimaryButton: config.showPrimaryButton,
                    isRequestModal:  config.isRequestModal,
                    showRequestModal: true,
                    primaryButtonClass: 'primary-button disable',
                    secondaryButtonClass: 'secondary-button disable'
                });
        }else{
            
            if (config) {
                this.modalHeader = config.header;
                this.modalPrimaryButton = config.primaryButton;
                this.modalSecondaryButton = config.secondaryButton;
                this.isRequestModal = config.isRequestModal;
                this.showRequestModal = true;
                this.showPrimaryButton = config.showPrimaryButton;
                this.primaryButtonClass = 'primary-button active',
                this.secondaryButtonClass = 'secondary-button secondary-active'
            } else {
                this.handleRequest(null);
            }
        }
       
    }

    
    /* ---------------- SERVER CALL ---------------- */

    /**
     * @description Handles connection requests (send, cancel, remove) based on the clicked action.
     * Calls Apex method and shows toast messages or updates modal based on the result.
     */
    handleRequest(event) {
        if (event?.currentTarget?.dataset?.name === 'Cancel') {
            this.showRequestModal = false;
            return;
        }
         // Validate textarea for Send Request action
        if (event?.currentTarget?.dataset?.name === 'Send Request') {
            const textarea = this.template.querySelector('.message-textarea');
            
            if (!textarea.value || textarea.value.trim() === '') {
                textarea.setCustomValidity('Please enter a personalized message.');
                textarea.reportValidity();
                return; // Stop execution if validation fails
            } else {
                textarea.setCustomValidity(''); // Clear any previous custom validity
            }
        }
        this.showRequestModal = false;

        handleConnectionRequest({
            portalId: this.currentUserContactId,
            linkedConstituentId: this.contactId,
            requestMessage: this.personalizedMessage,
            functionType: this.clickedFunctiontype
        })
        .then(result => {
            if (result === 'Success') {

                // The home page Directory card shows the latest connection's photo
                publish(this.messageContext, THUMBNAIL_REFRESH_CHANNEL, { source: 'connection' });

                if(this.clickedFunctiontype === ACTIONS.SEND_REQUEST){
                   this.toastMessage = this.localLabel.toastMessageReqSend;
                }else if(this.clickedFunctiontype === ACTIONS.CANCEL_REQUEST){
                   this.toastMessage = this.localLabel.toastMessageCancelReq;
                }else{
                   this.toastMessage = 'Preference updated!';
                }

                this.toastTitle = 'Success';
                this.toastVariant = 'success';
                this.toastDuration = 5000;
                this.showCustomToast = true;
                this.resetVariables();
                refreshApex(this.wiredConnectionsResult);
            }
            else if (result === 'Invitation Exist') {
                Object.assign(this, {
                    modalHeader: this.localLabel.invitationExist,
                    showPrimaryButton: false,
                    modalPrimaryButton: '',
                    modalSecondaryButton: 'Cancel',
                    isRequestModal: false,
                    showRequestModal: true,
                    primaryButtonClass: 'primary-button active',
                    secondaryButtonClass: 'secondary-button secondary-active'
                });
            }
            
        })
        .catch(() => {
            this.toastTitle = 'Error';
            this.toastMessage = 'Error occured on update';
            this.toastVariant = 'error';
            this.toastDuration = 5000;
            this.showCustomToast = true;
        });
    }

    /**
     * @description Resets variables related to modal and button states.
     */
    resetVariables() {
        this.personalizedMessage = '';
        this.modalHeader = '';
        this.modalPrimaryButton = '';
        this.modalSecondaryButton = '';
        this.isRequestModal = false;
        this.showPrimaryButton = false;
        this.isInactiveUser = false
    }

    /**
     * @description Closes custom toast notification.
     */
    handleToastClose() {
        this.showCustomToast = false;
    }

    /**
     * @description Closes the request modal popup.
     * Triggered when user clicks close icon or cancel button.
     */
    closeRequestModal() {
        this.showRequestModal = false;
    }

    /**
     * @description Captures personalized message entered by user in Send Request modal.
     * @param {Event} event - Input change event
     */
    handleMessageChange(event) {
        this.personalizedMessage = event.target.value;
    }

    handleSocialClick(event) {
        event.preventDefault();

        let targetUrl = event.currentTarget.dataset.url;

        if (!targetUrl) {
            return; 
        }

        if (!targetUrl.startsWith('http://') && !targetUrl.startsWith('https://')) {
            targetUrl = 'https://' + targetUrl;
        }
        window.open(targetUrl, '_blank');
    }

      /**
     * @description opens the necrology link on different tab.
     */
    handleNecrologyClick(){
        window.open(this.localLabel.necrologyLink, '_blank');
    }
      
}