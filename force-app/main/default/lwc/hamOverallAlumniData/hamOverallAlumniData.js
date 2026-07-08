import { LightningElement,api } from 'lwc';
export default class HamOverallAlumniData extends LightningElement {

    _alumniList = [];
    alumniUiList = [];

    @api
    get alumnilist() {
        return this._alumniList;
    }

    set alumnilist(value) {
        if (!Array.isArray(value)) {
            this._alumniList = [];
            this.alumniUiList = [];
            return;
        }

        this._alumniList = value;

        this.alumniUiList = value.map(alumni => ({
            ...alumni,
            degreeText:
                Array.isArray(alumni.Degrees) && alumni.Degrees.length ? alumni.Degrees.join(', ') : '—'
        }));
    }
}