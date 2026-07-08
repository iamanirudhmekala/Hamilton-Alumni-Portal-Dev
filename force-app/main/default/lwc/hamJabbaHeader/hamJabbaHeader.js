import { LightningElement, api, wire } from 'lwc';
import { CurrentPageReference } from 'lightning/navigation';

export default class HamJabbaHeader extends LightningElement {
    @api isAlumni = false; // default

    openFeedbackForm() {
        window.open('https://form.asana.com/?k=GUeiDwPKU5LkTTeHDW1niQ&d=940410193405385', '_blank');
    }

    @wire(CurrentPageReference)
    getPageRef(pageRef) {
        if (pageRef && pageRef.state) {
            let param = pageRef.state.c__isAlumni;

            if (param !== undefined) {
                // Convert string → boolean
                this.isAlumni = param === "true" || param === true;
            } else if (this.isAlumni === undefined) {
                this.isAlumni = false; // fallback default
            }

            console.log("URL param:", param);
            console.log("isAlumni (boolean):", this.isAlumni);
        }
    }
}