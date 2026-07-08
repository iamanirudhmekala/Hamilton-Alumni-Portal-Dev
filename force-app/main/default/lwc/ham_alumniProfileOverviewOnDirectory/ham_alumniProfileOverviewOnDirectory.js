import { LightningElement, api } from 'lwc';
export default class Ham_alumniProfileOverviewOnDirectory extends LightningElement {
    
    @api profile;

    handleBack() {
        this.dispatchEvent(new CustomEvent('back'));
    }
}