import { LightningElement, track, wire, api } from 'lwc';
import getProfileData from '@salesforce/apex/HAM_EditProfileController.getProfileData';
import saveProfile from '@salesforce/apex/HAM_EditProfileController.saveProfile';
import deleteProfilePic from '@salesforce/apex/HAM_EditProfileController.deleteProfilePic';
import { refreshApex } from '@salesforce/apex';
import HAM_Icons from '@salesforce/resourceUrl/HAM_Icons';

import phoneErrorLabel from '@salesforce/label/c.ham_EditProfPhoneErrorLabel';
import emailErrorLabel from '@salesforce/label/c.ham_EditProfEmailErrorLabel';
import phoneTooltip from '@salesforce/label/c.ham_EditProfPhoneTooltip';
import emailTooltip from '@salesforce/label/c.ham_EditProfEmailTooltip';
import eyeShowTooltip from '@salesforce/label/c.ham_EditProfEyeShowTooltip';
import eyeHideTooltip from '@salesforce/label/c.ham_EditProfEyeHideTooltip';
import editProfTitle from '@salesforce/label/c.ham_editprofile_title';
import editProfPicture from '@salesforce/label/c.ham_editprofile_picture';
import editProfCancel from '@salesforce/label/c.ham_editprofile_cancel';
import editProfButton1 from '@salesforce/label/c.ham_editprofile_button1';
import editProfButton2 from '@salesforce/label/c.ham_editprofile_button2';
import editProfInfo from '@salesforce/label/c.ham_editprofile_info';
import editProfdirecPS from '@salesforce/label/c.ham_editprofile_directoryPS';
import editProfVisibiltyDesc from '@salesforce/label/c.ham_editprofile_visibility_desc';
import directoryVisibilityToggle from '@salesforce/label/c.ham_directoryVisibilityToggle';
import employerHelpText from '@salesforce/label/c.ham_EmployerUpdateHelpText';
//import subAddressFieldsLabel from '@salesforce/label/c.ham_SubAddressFieldsLabel';

import alumniPrivacyPortalId from '@salesforce/label/c.HAM_AlumniPrivacyPortalId';
import profilePicPrivacyPortalId from '@salesforce/label/c.HAM_ProfilePicPrivacyPortalId';

export default class Ham_editProfileCmp extends LightningElement {
    @api userContactId;
    @api isOverride = false;

    get wrapperClass() {
        return this.isOverride ? 'profile-page-container kirkland-override' : 'profile-page-container';
    }
    
    @track sections = [];
    @track visibilityGroups = [];
    @track privacyState = {}; 
    @track formValues = {};
    @track uploadedFileName = '';   
    @track masterPrivacyLabel = '';
    @track masterPrivacyDescription = '';
    @track isMasterSivVisible = false;

    // Map to hold the dynamic relationship from Apex
    @track parentToChildMap = {};
    @track hiddenParentToChildMap = {};
    @track visibleParentHiddenChildMap = {};
    lockedByHiddenParentIds = new Set();
    visiblePortalIdSet = new Set();

    pendingToggleValue = false;
    showWithdrawModal = false;
    
    originalValues = {};
    originalPrivacyState = {};

    isEmployee = false;
    @track isStudent = false;
    @track isKirklandAlumnae = false;
    @track showClassOf = false; 
    @track currentChapters;
    isLoading = true;
    showPreview = false;
    @track showFileUpload = false; 
    contactName = '';
    graduationYear = '';
    profilePicUrl = '';
    activeSectionNames = [];
    uploadedContentDocId = null;
    wiredResult;

    eyeIconOpenUrl = HAM_Icons+'/eye-icon-open.png';
    eyeIconHideUrl = HAM_Icons+'/eye-icon-hide.png';
    avatarNew = HAM_Icons + '/profile_icon.png';
    kirklandAlumnaeIcon = HAM_Icons + '/kirkland-icon.png';

    label = {
        phoneErrorLabel, emailErrorLabel, phoneTooltip, emailTooltip,
        eyeShowTooltip, eyeHideTooltip, editProfTitle, editProfPicture,
        editProfCancel, editProfButton1, editProfButton2, editProfInfo,
        editProfdirecPS, editProfVisibiltyDesc, directoryVisibilityToggle,
        employerHelpText//,subAddressFieldsLabel
    };

    @track showCustomToast = false;
    @track toastConfig = { title: '', message: '', variant: '', duration: 5000 };
    
    _boundOutsideClickHandler;

    connectedCallback() {
        this._boundOutsideClickHandler = this.handleOutsideClick.bind(this);
        document.addEventListener('click', this._boundOutsideClickHandler);
    }

    disconnectedCallback() {
        document.removeEventListener('click', this._boundOutsideClickHandler);
    }

    handleOutsideClick() {
        this.sections = this.sections.map(s => ({
            ...s, fields: s.fields.map(f => ({ ...f, isDropdownOpen: false }))
        }));
    }

    @wire(getProfileData, { contactId: '$userContactId' })
    wiredData(result) {
        this.wiredResult = result;
        const { error, data } = result;
        if (data) {
            this.isEmployee = data.isEmployee;
            this.isStudent = data.isStudent || false;
            this.isKirklandAlumnae = data.isKirklandAlumnae;
            this.showClassOf = data.showClassOf;
            this.currentChapters = data.currentChapters
            this.contactName = (data.contactRecord.FirstName || '') + ' ' + (data.contactRecord.LastName || '');
            this.graduationYear = data.contactRecord.HAM_Reunion_Year__c || '';
            this.profilePicUrl = data.contactRecord.HAM_Profile_Picture_URL__c;

            // DYNAMIC MASTER LABELS (Falls back to empty string if missing)
            this.masterPrivacyLabel = data.masterPrivacyLabel || '';
            this.masterPrivacyDescription = data.masterPrivacyDescription || '';
            this.isMasterSivVisible = data.isMasterSivVisible === true;

            // Store the dynamic Parent-Child Map from Apex
            this.parentToChildMap = data.parentToChildMap || {};

            let pState = {};
            pState[alumniPrivacyPortalId] = !data.activePrivacyIds.includes(alumniPrivacyPortalId);
            pState[profilePicPrivacyPortalId] = !data.activePrivacyIds.includes(profilePicPrivacyPortalId);

            data.visibilityGroups.forEach(g => {
                this.activeSectionNames.push(g.name); 
                g.toggles.forEach(t => { pState[t.portalId] = !data.activePrivacyIds.includes(t.portalId); });
            });

            // Dynamically enforce Parent-Child load states based on the DB map
            for (const [parentId, childrenIds] of Object.entries(this.parentToChildMap)) {
                // If Parent is OFF, force children to show OFF on UI
                if (pState[parentId] === false) {
                    childrenIds.forEach(childId => {
                        pState[childId] = false;
                    });
                } else if (childrenIds.length > 0) {
                    // Failsafe: if all children are OFF, Parent should be OFF
                    const allOff = childrenIds.every(childId => pState[childId] === false);
                    if (allOff) {
                        pState[parentId] = false;
                    } else {
                        pState[parentId] = true;
                    }
                }
            }

            this.hiddenParentToChildMap = data.hiddenParentToChildMap || {};
            for (const [parentId, childrenIds] of Object.entries(this.hiddenParentToChildMap)) {
                if (data.activePrivacyIds.includes(parentId)) {
                    pState[parentId] = false;
                    childrenIds.forEach(childId => {
                        pState[childId] = false;
                    });
                }
            }
            this.visibleParentHiddenChildMap = data.visibleParentHiddenChildMap || {};
            for (const [parentId, childrenIds] of Object.entries(this.visibleParentHiddenChildMap)) {
                childrenIds.forEach(childId => {
                    pState[childId] = !data.activePrivacyIds.includes(childId);
                });
                if (pState[parentId] === false) {
                    childrenIds.forEach(childId => {
                        pState[childId] = false;
                    });
                }
            }
            this.lockedByHiddenParentIds = new Set();
            this.visiblePortalIdSet = new Set(data.visiblePortalIds || []);

            this.privacyState = pState;
            this.originalPrivacyState = { ...pState };

            this.visibilityGroups = data.visibilityGroups.map(g => ({
                ...g,
                isOpen: true,
                toggles: g.toggles.map(t => ({
                    ...t,
                    checked: this.privacyState[t.portalId] === true,
                    disabled: this.areTogglesDisabled || this.lockedByHiddenParentIds.has(t.portalId),
                    trackClass: this.privacyState[t.portalId] === true ? 'custom-toggle-track checked' : 'custom-toggle-track',
                    wrapperClass: (this.areTogglesDisabled || this.lockedByHiddenParentIds.has(t.portalId)) ? 'custom-toggle-wrapper disabled' : 'custom-toggle-wrapper'
                }))
            }));

            // Master hidden means pState is false (Hidden)
            const isMasterHidden = pState[alumniPrivacyPortalId] === false;

            this.sections = data.sections.map(sec => ({
                ...sec,
                isPersonalInfo: sec.name === 'Personal Information',
                fields: sec.fields.map(f => {
                    let rawVal = (f.value === undefined || f.value === null || f.value === 'null') ? '' : String(f.value).trim();
                    if (rawVal.endsWith('.0')) { rawVal = rawVal.slice(0, -2); }

                    const safeValue = rawVal;
                    this.originalValues[f.metadataDevName] = safeValue;
                    this.formValues[f.metadataDevName] = safeValue;
                    
                    let opts = [];
                    if(f.displayType === 'Picklist' && data.picklistMap[f.metadataDevName]) {
                        opts = data.picklistMap[f.metadataDevName].map(p => ({
                            ...p, selected: p.value === safeValue
                        }));
                    }

                    const isPhoneField = f.apiName === 'HAM_Formatted_Phone__c';
                    const isEmailField = f.apiName === 'HAM_PreferredEmail__c';
                    let helpText = isPhoneField ? this.label.phoneTooltip : (isEmailField ? this.label.emailTooltip : '');

                    let listOpts = (f.displayType === 'List' && data.listOptionsMap && data.listOptionsMap[f.metadataDevName])
                        ? data.listOptionsMap[f.metadataDevName].map(o => ({...o, visible: true}))
                        : [];

                    if(f.portalId && this.privacyState[f.portalId] === undefined) {
                        const portalVal = !data.activePrivacyIds.includes(f.portalId);
                        this.privacyState[f.portalId] = portalVal;
                        this.originalPrivacyState[f.portalId] = portalVal;
                    }

                    // Force close eye icon visually if Master is hidden
                    const visuallyHidden = isMasterHidden || this.privacyState[f.portalId] === false;

                    const containerClass = sec.name === 'Campus Life' 
                    ? 'field-value-container campus-life' 
                    : 'field-value-container';

                    return {
                        ...f,
                        isReadOnly: f.isReadOnly === true,
                        containerClass: containerClass,
                        value: safeValue,
                        isPicklist: f.displayType === 'Picklist',
                        isList: f.displayType === 'List',
                        isSocialMedia: f.displayType === 'Related Single' && f.relatedObject === 'ucinn_ascendv2__Social_Media__c',
                        isDropdownOpen: false,
                        listOptions: listOpts,
                        isPhone: isPhoneField,
                        isEmail: isEmailField,
                        hasHelpText: !!helpText,
                        helpText: helpText,
                        options: opts,
                        hasPrivacy: !!f.portalId && this.visiblePortalIdSet.has(f.portalId) && !this.lockedByHiddenParentIds.has(f.portalId),
                        eyeIconUrl: visuallyHidden ? this.eyeIconHideUrl : this.eyeIconOpenUrl,
                        eyeTooltip: visuallyHidden ? this.label.eyeHideTooltip : this.label.eyeShowTooltip,
                        fieldError: ''
                    };
                })
            }));
            
            this.syncUI();
            this.isLoading = false;
        } else if (error) {
            this.triggerToast('Error', 'Failed to load profile data', 'error');
            console.error('Error:', error);
            this.isLoading = false;
        }
    }

    get showMainContent() { return !this.isLoading && !this.showPreview; }
    get showMasterToggle() { return this.isMasterSivVisible === true; }
    get isMasterChecked() { return this.privacyState[alumniPrivacyPortalId] === true; }
    get areTogglesDisabled() { return this.privacyState[alumniPrivacyPortalId] === false; }
    get masterTrackClass() {
        return this.isMasterChecked ? 'custom-toggle-track checked' : 'custom-toggle-track';
    } 
    get accordionClass() { return this.areTogglesDisabled ? 'custom-accordion disabled' : 'custom-accordion'; }

    get profilePicEyeIconUrl() { 
        return (this.areTogglesDisabled || this.privacyState[profilePicPrivacyPortalId] === false) ? this.eyeIconHideUrl : this.eyeIconOpenUrl; 
    }
    get profilePicEyeTooltip() { 
        return (this.areTogglesDisabled || this.privacyState[profilePicPrivacyPortalId] === false) ? this.label.eyeHideTooltip : this.label.eyeShowTooltip; 
    }
    get editPicButtonLabel() { return this.showFileUpload ? 'Cancel' : 'Edit Profile Picture'; }

    handleInputChange(event) {
        event.stopPropagation();
        const key = event.target.dataset.key;
        const val = event.target.value;

        if(key === 'EditProfile_FirstName' || key === 'EditProfile_LastName') {
            const finalVal = val.replace(/^./, char => char.toUpperCase());
            this.formValues[key] = finalVal;
            this.sections = this.sections.map(s => ({
                ...s, fields: s.fields.map(f => f.metadataDevName === key ? { ...f, value: finalVal, fieldError: '' } : f)
            }));
        } else {
            this.formValues[key] = val;
            this.sections = this.sections.map(s => ({
                ...s, fields: s.fields.map(f => f.metadataDevName === key ? { ...f, value: val, fieldError: '' } : f)
            }));
        }

    }

    handleListDisplayClick(event) {
        event.stopPropagation();
        const key = event.currentTarget.dataset.key;
        this.sections = this.sections.map(s => ({
            ...s, fields: s.fields.map(f => ({ ...f, isDropdownOpen: f.metadataDevName === key ? !f.isDropdownOpen : false }))
        }));
    }

    handleDropdownPanelClick(event) { event.stopPropagation(); }

    handleListSearch(event) {
        const key = event.target.dataset.key;
        const searchTerm = event.target.value.toLowerCase();
        
        this.sections = this.sections.map(s => ({
            ...s, fields: s.fields.map(f => {
                if (f.metadataDevName !== key) return f;
                return {
                    ...f,
                    listOptions: f.listOptions.map(opt => ({ ...opt, visible: opt.label.toLowerCase().includes(searchTerm) }))
                };
            })
        }));
    }

    handleListCheckboxChange(event) {
        event.stopPropagation();
        const key = event.target.dataset.key;
        const value = event.target.dataset.value;
        const checked = event.target.checked;

        this.sections = this.sections.map(s => ({
            ...s,
            fields: s.fields.map(f => {
                if (f.metadataDevName !== key) return f;

                const updatedOptions = f.listOptions.map(opt => String(opt.value) === String(value) ? { ...opt, checked } : opt);
                const newValue = updatedOptions.filter(o => o.checked).map(o => o.label).join(', ');
                this.formValues[key] = newValue; 
                return { ...f, listOptions: updatedOptions, value: newValue };
            })
        }));
    }

    // Refactored to use dynamic hierarchy handler
    handleEyeClick(event) {
        event.stopPropagation();
        event.preventDefault();

        // Prevent click if Master is OFF (hidden)
        if(this.areTogglesDisabled) return;

        const portalId = event.currentTarget.dataset.portalId;
        this.processDynamicHierarchyToggle(portalId, !this.privacyState[portalId]);
    }

    handleToggleChange(event) {
        event.stopPropagation();
        if (this.areTogglesDisabled) return;
        const portalId = event.currentTarget.dataset.portalId;
        this.processDynamicHierarchyToggle(portalId, !(this.privacyState[portalId] === true));
    }

    // Helper method to handle any dynamic parent/child relationship
    processDynamicHierarchyToggle(portalId, isChecked) {
        this.privacyState[portalId] = isChecked;

        // 1. Is it a visible Parent?
        if (this.parentToChildMap[portalId] || this.visibleParentHiddenChildMap[portalId]) {
            if (this.parentToChildMap[portalId]) {
                this.parentToChildMap[portalId].forEach(childId => {
                    this.privacyState[childId] = isChecked;
                });
            }
            if (this.visibleParentHiddenChildMap[portalId]) {
                this.visibleParentHiddenChildMap[portalId].forEach(childId => {
                    this.privacyState[childId] = isChecked;
                });
            }
        }
        // 2. Is it a Child? (Find who its parent is)
        else {
            let foundParentId = null;
            for (const [pId, childrenIds] of Object.entries(this.parentToChildMap)) {
                if (childrenIds.includes(portalId)) {
                    foundParentId = pId;
                    break;
                }
            }

            if (foundParentId) {
                // Child of visible parent
                const childrenIds = this.parentToChildMap[foundParentId];
                if (isChecked === true) {
                    this.privacyState[foundParentId] = true;
                } else {
                    const allOff = childrenIds.every(cId => this.privacyState[cId] === false);
                    if (allOff) {
                        this.privacyState[foundParentId] = false;
                    }
                }
            } else {
                // 3. Child of non-portal-visible parent — same cascade logic
                for (const [pId, childrenIds] of Object.entries(this.hiddenParentToChildMap)) {
                    if (childrenIds.includes(portalId)) {
                        if (isChecked === true) {
                            this.privacyState[pId] = true;
                        } else {
                            const allOff = childrenIds.every(cId => this.privacyState[cId] === false);
                            if (allOff) {
                                this.privacyState[pId] = false;
                            }
                        }
                        break;
                    }
                }
            }
        }

        this.syncUI();
    }

    handleProfilePicEyeClick(event) {
        event.stopPropagation();

        // Prevent click if Master is OFF (hidden)
        if(this.areTogglesDisabled) return;

        this.processDynamicHierarchyToggle(profilePicPrivacyPortalId, !this.privacyState[profilePicPrivacyPortalId]);
    }


    handleMasterToggle(event) {
        if (!this.isMasterSivVisible) return;
        event.stopPropagation();
        const currentState = this.privacyState[alumniPrivacyPortalId] === true;
        const newState = !currentState;

        if (currentState === true && newState === false) {
            this.pendingToggleValue = newState;
            this.showWithdrawModal = true;
            // privacyState unchanged → masterTrackClass stays "checked" → toggle stays ON visually while modal shows
        } else {
            this.processToggleChange(newState);
        }
    }

    confirmWithdraw() {
        this.processToggleChange(this.pendingToggleValue);
        this.showWithdrawModal = false;
    }

    processToggleChange(value) {
        this.privacyState = { 
            ...this.privacyState, 
            [alumniPrivacyPortalId]: value 
        };
        this.syncUI();
    }

    closeWithdrawModal() {
        this.showWithdrawModal = false;
    }

    toggleFileUpload() { 
        this.showFileUpload = !this.showFileUpload;
    }

    handleFileDelete(){
        if (this.uploadedContentDocId) {
            deleteProfilePic({contentDocId : this.uploadedContentDocId})
            .then(result=>{ this.triggerToast('Success', 'Uploaded picture removed', 'success'); this.uploadedContentDocId = null; this.uploadedFileName = ''; })
            .catch(error=>{ this.triggerToast('Error', 'Error on removing picture', 'error'); })
        } else {
            this.uploadedFileName = ''; 
        }
        this.toggleFileUpload();
    }

    handleUploadFinished(event) {
        const uploadedFiles = event.detail.files;
        if(uploadedFiles.length > 0) {
            this.uploadedContentDocId = uploadedFiles[0].documentId;
            this.uploadedFileName = uploadedFiles[0].name;
            this.triggerToast('Success', 'Your picture has been uploaded and is ready for review. Click Save to apply', 'success');
        }
    }

    syncUI() {
        const isMasterHidden = this.areTogglesDisabled; // True if Master is false

        this.sections = this.sections.map(s => ({
            ...s, fields: s.fields.map(f => {
                // If master is hidden OR field is hidden, show closed eye
                const visuallyHidden = isMasterHidden || this.privacyState[f.portalId] === false;
                return {
                    ...f, 
                    eyeIconUrl: visuallyHidden ? this.eyeIconHideUrl : this.eyeIconOpenUrl, 
                    eyeTooltip: visuallyHidden ? this.label.eyeHideTooltip : this.label.eyeShowTooltip
                };
            })
        }));

        this.visibilityGroups = this.visibilityGroups.map(g => ({
            ...g,
            isOpen: true,
            toggles: g.toggles.map(t => ({
                ...t,
                checked: this.privacyState[t.portalId] === true,
                disabled: this.areTogglesDisabled || (this.lockedByHiddenParentIds && this.lockedByHiddenParentIds.has(t.portalId)),
                trackClass: this.privacyState[t.portalId] === true ? 'custom-toggle-track checked' : 'custom-toggle-track',
                wrapperClass: (this.areTogglesDisabled || (this.lockedByHiddenParentIds && this.lockedByHiddenParentIds.has(t.portalId))) ? 'custom-toggle-wrapper disabled' : 'custom-toggle-wrapper'
            }))
        }));
    }

    handleSave() {
        this.isLoading = true;

        const socialErrors = {};
        this.sections.forEach(s => {
            s.fields.forEach(f => {
                if (f.isSocialMedia) {
                    const current = this.formValues[f.metadataDevName] == null ? '' : String(this.formValues[f.metadataDevName]).trim();
                    const original = this.originalValues[f.metadataDevName] == null ? '' : String(this.originalValues[f.metadataDevName]).trim();
                    if (current === '' && original !== '') {
                        socialErrors[f.metadataDevName] = `${f.label} handle cannot be empty. Please enter a valid handle or revert your changes.`;
                    }
                }
            });
        });
        if (Object.keys(socialErrors).length > 0) {
            this.sections = this.sections.map(s => ({
                ...s, fields: s.fields.map(f => ({ ...f, fieldError: socialErrors[f.metadataDevName] || '' }))
            }));
            this.triggerToast('Validation Error', 'One or more social media handles cannot be empty.', 'error');
            this.isLoading = false;
            return;
        }

        const selections = {};
        const allOptions = {};
        
        this.sections.forEach(s => {
            s.fields.forEach(f => {
                if(f.isList && !f.isReadOnly && this.formValues.hasOwnProperty(f.metadataDevName)) {
                    selections[f.metadataDevName] = f.listOptions.filter(o => o.checked).map(o => String(o.value));
                    allOptions[f.metadataDevName] = f.listOptions.map(o => String(o.value));
                }
            });
        });

        const changedFields = {};
        for (const key in this.formValues) {
            let currentStr = this.formValues[key] == null ? '' : String(this.formValues[key]).trim();
            let originalStr = this.originalValues[key] == null ? '' : String(this.originalValues[key]).trim();

            if (currentStr !== originalStr) {
                changedFields[key] = currentStr;
            }
        }

        const changedPrivacy = {};
        let payloadPrivacyState = { ...this.privacyState };

        // RULE 1: If ANY Parent is OFF, force its children to true in payload
        // so the backend removes their specific SIs and only keeps the Parent SI.
        for (const [parentId, childrenIds] of Object.entries(this.parentToChildMap)) {
            if (payloadPrivacyState[parentId] === false) {
                childrenIds.forEach(childId => {
                    payloadPrivacyState[childId] = true;
                });
            }
        }
        for (const [parentId, childrenIds] of Object.entries(this.hiddenParentToChildMap)) {
            if (payloadPrivacyState[parentId] === false) {
                childrenIds.forEach(childId => {
                    payloadPrivacyState[childId] = true;
                });
            }
        }
        // RULE 1 extension (hidden children of visible parents):
        for (const [parentId, childrenIds] of Object.entries(this.visibleParentHiddenChildMap)) {
            if (payloadPrivacyState[parentId] === false) {
                childrenIds.forEach(childId => {
                    payloadPrivacyState[childId] = true;
                });
            }
        }

        for (const key in payloadPrivacyState) {
            let isChanged = payloadPrivacyState[key] !== this.originalPrivacyState[key];

            // RULE 2: If a Parent transitioned from OFF to ON, explicitly send the
            // OFF state of any remaining children so the backend creates their specific SIs.
            for (const [parentId, childrenIds] of Object.entries(this.parentToChildMap)) {
                if (childrenIds.includes(key)) {
                    if (this.originalPrivacyState[parentId] === false && payloadPrivacyState[parentId] === true) {
                        if (payloadPrivacyState[key] === false) {
                            isChanged = true;
                        }
                    }
                }
            }
            for (const [parentId, childrenIds] of Object.entries(this.hiddenParentToChildMap)) {
                if (childrenIds.includes(key)) {
                    if (this.originalPrivacyState[parentId] === false && payloadPrivacyState[parentId] === true) {
                        if (payloadPrivacyState[key] === false) {
                            isChanged = true;
                        }
                    }
                }
            }
            // RULE 2 extension (hidden children of visible parents):
            for (const [parentId, childrenIds] of Object.entries(this.visibleParentHiddenChildMap)) {
                if (childrenIds.includes(key)) {
                    if (this.originalPrivacyState[parentId] === false && payloadPrivacyState[parentId] === true) {
                        if (payloadPrivacyState[key] === false) {
                            isChanged = true;
                        }
                    }
                }
            }

            if (isChanged) {
                changedPrivacy[key] = payloadPrivacyState[key];
            }
        }
        // -----------------------------------------

        const privacyActuallyChanged = Object.keys(this.privacyState).some(
            k => this.privacyState[k] !== this.originalPrivacyState[k]
        );
        const somethingChanged = Object.keys(changedFields).length > 0
            || privacyActuallyChanged
            || !!this.uploadedContentDocId;

        if (!somethingChanged) {
            this.isLoading = false;
            return;
        }

        const savePayload = {
            dynamicFields: changedFields,
            privacyChanges: changedPrivacy,
            contentDocId: this.uploadedContentDocId || null,
            listSelections: selections,
            allAvailableOptions: allOptions
        };

        saveProfile({ contactId: this.userContactId, payloadJSON: JSON.stringify(savePayload) })
        .then(result => {
            if (result === 'Success') {
                this.triggerToast('Profile Updated Successfully', this.label.employerHelpText, 'success');
                this.uploadedContentDocId = null;
                this.uploadedFileName = '';
                this.showFileUpload = false;
                
                this.originalValues = { ...this.formValues };
                this.originalPrivacyState = { ...this.privacyState };

                this.dispatchEvent(new CustomEvent('profileupdated', { detail: { isprofileupdated: true, message: 'Profile Updated successfully' }}));
                return refreshApex(this.wiredResult);
            } else { this.handleSaveError(result); }
        })
        .catch(error => {
            const msg = error.body ? error.body.message : error.message;
            this.handleSaveError(msg);
        })
        .finally(() => { this.isLoading = false; });
    }

    handleSaveError(response) {
        console.error('Backend Error Details:', response);
        let errorMessage;
        if (response.includes('PHONE_ERROR')) {
            const phoneValue = this.getUpdatedFieldValue('HAM_Formatted_Phone__c');
            errorMessage = phoneValue ? `${phoneValue} ${this.label.phoneErrorLabel}` : this.label.phoneErrorLabel;
        } else if (response.includes('EMAIL_ERROR')) {
            const emailValue = this.getUpdatedFieldValue('HAM_PreferredEmail__c');
            errorMessage = emailValue ? `${emailValue} ${this.label.emailErrorLabel}` : this.label.emailErrorLabel;
        } else {
            let cleanedResponse = response.replace('Error: ', '');            
            if (cleanedResponse.includes('CANNOT_') || cleanedResponse.includes('System.') || cleanedResponse.includes('Exception:') || cleanedResponse.includes('ucinn_ascend')) {
                errorMessage = 'We encountered an unexpected issue while saving your profile. Please try again later or contact support.';
            } else {
                errorMessage = cleanedResponse; 
            }
        }
        this.triggerToast('Error', errorMessage, 'error');
    }

    getUpdatedFieldValue(fieldApiName) {
        for (const section of this.sections) {
            for (const field of section.fields) {
                if (field.apiName === fieldApiName) return this.formValues[field.metadataDevName] || field.value || '';
            }
        }
        return '';
    }

    handlePreview() { this.showPreview = true; window.scrollTo({ top: 0, behavior: 'instant' }); }
    closePreview() { this.showPreview = false; }
    handleSaveFromPreview() { this.showPreview = false; this.handleSave(); }

    get previewData() {
        if(!this.privacyState[alumniPrivacyPortalId]) { return { name: 'Anonymous User', year: '', pic: '', fields: [] }; }
        let flatFields = [];
        this.sections.forEach(s => {
            s.fields.forEach(f => {
                const isHidden = f.portalId
                    ? (this.privacyState[f.portalId] === false || !this.visiblePortalIdSet.has(f.portalId))
                    : false;
                const rawVal = this.formValues.hasOwnProperty(f.metadataDevName) ? this.formValues[f.metadataDevName] : f.value;
                flatFields.push({ label: f.label, value: isHidden ? '-' : rawVal, section: s.name });
            });
        });
        const picToUse = this.privacyState[profilePicPrivacyPortalId] === false ? '' : this.profilePicUrl;
        return { name: this.contactName, year: this.graduationYear, pic: picToUse, fields: flatFields };
    }

    triggerToast(title, message, variant) {
        this.toastConfig = { title, message, variant, duration: 5000 };
        this.showCustomToast = true;
    }
    handleToastClose() { this.showCustomToast = false; }

    toggleAccordion(event) {
        const name = event.currentTarget.dataset.name;
        this.visibilityGroups = this.visibilityGroups.map(group => {
            return { ...group, isOpen: group.name === name ? !group.isOpen : group.isOpen };
        });
    }
}