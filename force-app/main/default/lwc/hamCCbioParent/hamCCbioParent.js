import { LightningElement, wire, track } from 'lwc';
import { CurrentPageReference } from 'lightning/navigation';

export default class hamCCbioParent extends LightningElement {
    // Reactive properties to hold state
    @track isAlumni = false;
    @track recordId;

    @wire(CurrentPageReference)
    getStateParameters(currentPageReference) {
        if (currentPageReference && currentPageReference.state) {
            
            // 1. Get Alumni Status (Handle both string 'true' and boolean true)
            const rawIsAlumni = currentPageReference.state.c__isAlumni;
            this.isAlumni = (rawIsAlumni === 'true' || rawIsAlumni === true);

            // 2. Get Record ID to pass to child components
            this.recordId = currentPageReference.state.c__recordId;
        }
    }
}