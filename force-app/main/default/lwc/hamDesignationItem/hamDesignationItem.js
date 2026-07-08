import { LightningElement, api } from 'lwc';

export default class HamDesignationItem extends LightningElement {

    @api isSelected = false;

    @api designation;

    connectedCallback() {
        if (this.designation && this.designation.isSelected) {
            this.isSelected = true;
        }
    }

    handleDesignationSelection(event) {
        this.isSelected = !this.isSelected;
     
        this.dispatchEvent(new CustomEvent('select', {
            detail: { designationId: this.designation.id, isHamiltonFund: this.designation.fundGrp === 'HA', isSelected: this.isSelected },
        }));
    }

    get name() {
        return this.designation.name;
    }

    get desc() {
        return this.designation.description;
    }
}