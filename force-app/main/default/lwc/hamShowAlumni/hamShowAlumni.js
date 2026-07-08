import { LightningElement,api,track } from 'lwc';
export default class HamShowAlumni extends LightningElement {
    
    _alumniList = [];

    @track alumniData = [];

    @api
    get alumniList() {
        return this._alumniList;
    }

    set alumniList(value) {
        if (!Array.isArray(value)) {
            this._alumniList = [];
            this.alumniData = [];
            return;
        }

        this._alumniList = value;

        this.alumniData = value.map(item => ({
            ...item,
            degreesText:item.Degrees && item.Degrees.length ? item.Degrees.join(', ') : '—'
        }));

        console.log(
            'Alumni received in child:',
            JSON.stringify(this.alumniData, null, 2)
        );
    }
}