import { LightningElement, api, track, wire } from 'lwc';
import getPreferences from '@salesforce/apex/Ham_PreferenceController.getPreferences';
import savePreferences from '@salesforce/apex/Ham_PreferenceController.savePreferences';
import { refreshApex } from '@salesforce/apex';

import ComPrefTitle from '@salesforce/label/c.ham_comPrefTitle';
import ComPrefHelpText from '@salesforce/label/c.ham_comPrefHelpText';
import MarPrefTitle from '@salesforce/label/c.ham_marPrefTitle';
import MarPrefHelpText from '@salesforce/label/c.ham_marPrefHelpText';
import MarPrefSubHeader from '@salesforce/label/c.ham_marPrefSubHeader';
import EmailPrefTitle from '@salesforce/label/c.ham_emailPrefTitle';
import EmailPrefHelpText from '@salesforce/label/c.ham_emailPrefHelpText';
import EmailPrefSubheader from '@salesforce/label/c.ham_emailPrefSubheader';
import MarPrefSupportText from '@salesforce/label/c.ham_marPrefSupportText';
import ContactOptOutMsg from '@salesforce/label/c.ham_contactOptOutMsg';
import PrefOptOut from '@salesforce/label/c.ham_prefOptOut';
import VolunteerInfoTextEmail from '@salesforce/label/c.HAM_volOppInfoText_Email';


export default class Ham_PreferenceCenter extends LightningElement {

    @api contactId;
    @api isStudent = false;
    @api isOverride = false;

    get wrapperClass() {
        return this.isOverride ? 'ham-pref-page kirkland-override' : 'ham-pref-page';
    }
    get savePrefBtnClass() {
        return this.isOverride ? 'save-pref-btn kirkland-save' : 'save-pref-btn';
    }

    @track privacyConfigs = [];
    @track accordions = [];
    @track showOptOutModal = false;
    @track modalMessage = '';
    @track showDependencyModal = false;
    @track dependencyMessage = '';

    wiredPreferencesResult;
    stateMap = new Map();
    initialStateMap = new Map();
    childToParentMap = new Map();
    hiddenParentActiveSet = new Set();
    isSaving = false;
    pendingToggleRevert = null;

    label ={
        comPrefTitle : ComPrefTitle,
        comPrefHelpText : ComPrefHelpText,
        marPrefTitle : MarPrefTitle,
        marPrefHelpText : MarPrefHelpText,
        marPrefSubHeader : MarPrefSubHeader,
        emailPrefTitle : EmailPrefTitle,
        emailPrefHelpText : EmailPrefHelpText,
        emailPrefSubheader : EmailPrefSubheader,
        marPrefSupportText : MarPrefSupportText,
        prefOptOut : PrefOptOut,
        contactOptOutMsg : ContactOptOutMsg,
        volunteerInfoTextEmail :VolunteerInfoTextEmail
    }

    categoryMap = {
        'Communication Preferences': {
            label: this.label.comPrefTitle,
            helpText: this.label.comPrefHelpText
        },
        'Marketing Preferences': {
            label: this.label.marPrefTitle,
            helpText: this.label.marPrefHelpText,
            subHeader: this.label.marPrefSubHeader
        },
        'Email Preferences': {
            label: this.label.emailPrefTitle,
            helpText: this.label.emailPrefHelpText,
            subHeader: this.label.emailPrefSubheader
        }
    };

    @wire(getPreferences, { contactId: '$contactId' })
    wiredPreferences(result) {
        this.wiredPreferencesResult = result;
        const { data, error } = result;

        if (data) {
            this.buildUI(data);
        } else if (error) {
            console.error('Error fetching preferences:', error);
        }
    }

    buildUI(data) {
        this.privacyConfigs = [];
        let accordionGroups = {};
        this.stateMap.clear();
        this.initialStateMap.clear();
        this.childToParentMap.clear();
        this.hiddenParentActiveSet = new Set();

        const activeSet = new Set(data.activeIndicatorIds || []);
        const knownItemIds = new Set(data.items.map(i => i.id));
        const allItems = [];

        // Pass 1: build maps and stateMap
        data.items.forEach(item => {
            const isChecked = !activeSet.has(item.id);
            this.stateMap.set(item.id, isChecked);
            this.initialStateMap.set(item.id, isChecked);
            if (item.parentId) {
                this.childToParentMap.set(item.id, item.parentId);
            }
            allItems.push(item);
        });

        // Detect hidden parents: parentIds that are not in data.items but have active SIs.
        // Cascade their opted-out state to children and add them to stateMap for diff tracking.
        for (let [childId, parentId] of this.childToParentMap.entries()) {
            if (!knownItemIds.has(parentId) && activeSet.has(parentId)) {
                this.hiddenParentActiveSet.add(parentId);
                if (!this.stateMap.has(parentId)) {
                    this.stateMap.set(parentId, false);
                    this.initialStateMap.set(parentId, false);
                }
                this.stateMap.set(childId, false);
                this.initialStateMap.set(childId, false);
            }
        }

        // Pass 2: build UI items using corrected stateMap
        allItems.forEach(item => {
            const uiItem = { ...item, checked: this.stateMap.get(item.id) };

            if (item.category === 'Privacy Controls') {
                this.privacyConfigs.push(uiItem);
            } else {
                const uiCategory = this.categoryMap[item.category] ? item.category : 'Other';
                if (!accordionGroups[uiCategory]) {
                    accordionGroups[uiCategory] = [];
                }
                accordionGroups[uiCategory].push(uiItem);
            }
        });

        this.accordions = Object.keys(accordionGroups).map((categoryKey, index) => {
            const mappedData = this.categoryMap[categoryKey] || { label: categoryKey };
            const configs = accordionGroups[categoryKey];

            // Mark the last item in the config list
            if (configs.length > 0) {
                configs[configs.length - 1].isLast = true;
            }
            return {
                name: categoryKey,
                label: mappedData.label,
                helpText: mappedData.helpText,
                subHeader: mappedData.subHeader,
                configs: accordionGroups[categoryKey],
                isOpen: index === 0, 
                isMarketing: categoryKey === 'Marketing Preferences',
                get iconClass() {
                    return this.isOpen ? 'ham-accordion-icon open' : 'ham-accordion-icon';
                }
            };
        });
    }

     get emailHref() {
      
        const email = this.label.volunteerInfoTextEmail;

        return email ? `mailto:${email}` : '';
    }


    get isSaveDisabled() {
        if (this.isSaving) return true;
        for (let [key, value] of this.stateMap.entries()) {
            if (value !== this.initialStateMap.get(key)) {
                return false;
            }
        }
        return true;
    }

    get saveButtonLabel() {
        return this.isSaving ? 'Saving...' : 'Save Preferences';
    }

    handleAccordionClick(event) {
        const accName = event.currentTarget.dataset.name;
        this.accordions = this.accordions.map(acc => {
            if (acc.name === accName) {
                acc.isOpen = !acc.isOpen;
            }
            return acc;
        });
    }

    handleToggleChange(event) {
        event.stopPropagation();
        // Use ID instead of name
        const key = event.target.dataset.id;
        const isChecked = event.target.checked;

        if (!isChecked) {
            const isParent = Array.from(this.childToParentMap.values()).includes(key);
            
            if (isParent) {
                let activeChildren = [];
                
                for (let [childKey, parentKey] of this.childToParentMap.entries()) {
                    if (parentKey === key && this.stateMap.get(childKey) === true) {
                        activeChildren.push(childKey);
                    }
                }

                if (activeChildren.length > 0) {
                    let sectionName = 'related preferences';
                    for (const acc of this.accordions) {
                        // Check against config.id
                        if (acc.configs.some(c => c.id === activeChildren[0])) {
                            sectionName = acc.label; 
                            break;
                        }
                    }

                    event.target.checked = true;
                    this.updateToggleState(key, true);

                    this.dependencyMessage = `The related section '${sectionName}' has records turned on. Please first turn off all ${sectionName} records, then this can be turned off.`;
                    this.showDependencyModal = true;
                    
                    return; 
                }
            }
        }

        this.updateToggleState(key, isChecked);

        if (isChecked) {
            this.enforceParentLogic(key);
        } else {
            this.enforceChildOptOutLogic(key);
            this.checkAndTriggerModal(key);
        }
    }

    enforceParentLogic(childKey) {
        const parentKey = this.childToParentMap.get(childKey);
        if (!parentKey || this.stateMap.get(parentKey) !== false) return;

        if (this.hiddenParentActiveSet.has(parentKey)) {
            // Hidden parent — no UI toggle, update stateMap only so the diff captures it
            this.stateMap.set(parentKey, true);
        } else {
            this.updateToggleState(parentKey, true);
        }
    }

    enforceChildOptOutLogic(childKey) {
        const parentKey = this.childToParentMap.get(childKey);
        if (!parentKey || !this.hiddenParentActiveSet.has(parentKey)) return;

        const allOff = Array.from(this.childToParentMap.entries())
            .filter(([, pId]) => pId === parentKey)
            .every(([cId]) => this.stateMap.get(cId) === false);

        if (allOff) {
            this.stateMap.set(parentKey, false);
        }
    }

    checkAndTriggerModal(toggledKey) {
        for (const acc of this.accordions) {
            // Check against config.id
            if (acc.configs.some(c => c.id === toggledKey)) {
                
                const isSectionCompletelyOff = acc.configs.every(c => this.stateMap.get(c.id) === false);
                
                if (isSectionCompletelyOff && acc.label !== 'Publications') {
                    this.pendingToggleRevert = toggledKey;
                    
                    if (acc.label === 'Contact Methods') {
                        this.modalMessage = this.label.contactOptOutMsg;
                    } else {
                        this.modalMessage = this.label.prefOptOut+` ${acc.label}?`;
                    }
                    
                    this.showOptOutModal = true;
                }
                break;
            }
        }
    }

    closeDependencyModal() {
        this.showDependencyModal = false;
    }

    updateToggleState(key, isChecked) {
        this.stateMap.set(key, isChecked);

        // Update arrays using ID matching
        const privacyItem = this.privacyConfigs.find(item => item.id === key);
        if (privacyItem) privacyItem.checked = isChecked;

        this.accordions = this.accordions.map(acc => {
            const configItem = acc.configs.find(c => c.id === key);
            if (configItem) configItem.checked = isChecked;
            return acc;
        });
    }

    handleModalConfirm() {
        this.showOptOutModal = false;
        this.pendingToggleRevert = null;
    }

    handleModalCancel() {
        this.showOptOutModal = false;
        if (this.pendingToggleRevert) {
            this.updateToggleState(this.pendingToggleRevert, true);
            this.enforceParentLogic(this.pendingToggleRevert); 
            this.pendingToggleRevert = null;
        }
    }

    handleSave() {
        this.isSaving = true;

        const changes = {};
        this.stateMap.forEach((value, key) => {
            if (value !== this.initialStateMap.get(key)) {
                changes[key] = value;
            }
        });

        // RULE 2: When a hidden parent SI is being ended (false→true), create individual SIs
        // for all children still opted out so they remain suppressed after the parent SI is gone.
        for (let [childId, parentId] of this.childToParentMap.entries()) {
            if (this.hiddenParentActiveSet.has(parentId) && changes[parentId] === true) {
                if (this.stateMap.get(childId) === false) {
                    changes[childId] = false;
                }
            }
        }

        if (Object.keys(changes).length === 0) {
            this.isSaving = false;
            return;
        }

        savePreferences({ changedToggles: changes, contactId: this.contactId })
            .then(() => {
                Object.keys(changes).forEach(key => {
                    this.initialStateMap.set(key, changes[key]);
                });
                return refreshApex(this.wiredPreferencesResult);
            })
            .catch(err => {
                console.error('Save Failed:', err);
                refreshApex(this.wiredPreferencesResult); 
            })
            .finally(() => {
                this.isSaving = false;
            });
    }
}