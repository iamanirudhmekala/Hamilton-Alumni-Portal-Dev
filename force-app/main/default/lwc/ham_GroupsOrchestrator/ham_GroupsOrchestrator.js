import { LightningElement, api } from 'lwc';

export default class Ham_GroupsOrchestrator extends LightningElement {
    @api groupId;
    @api subview;
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

    get isDiscoveryMode() {
        return !this.groupId;
    }

    // Handlers for child navigation events to pass up to the main router
    handleViewGroup(event) {
        this.dispatchEvent(new CustomEvent('navigategroup', { detail: event.detail }));
    }

    handleBackToDiscovery() {
        this.dispatchEvent(new CustomEvent('navigategroup', { detail: { groupId: null } }));
    }
}