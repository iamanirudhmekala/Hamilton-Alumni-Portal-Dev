import { LightningElement, api } from 'lwc';

//import static resources
import MoreFiltersIcon from '@salesforce/resourceUrl/ham_MoreFiltersIcon';
import DropDownOuter from '@salesforce/resourceUrl/ham_DropDownOuter';
import DropDownInner from '@salesforce/resourceUrl/ham_DropDownInner';

export default class HamDirectoryFilters extends LightningElement {

    MoreFiltersIcon = MoreFiltersIcon;
    DropDownOuter = DropDownOuter;
    DropDownInner = DropDownInner;

    filtersData = [];
    _filters;

    @api
    get filters() {
        return this._filters;
    }

    set filters(value) {
        if (!Array.isArray(value)) {
            this._filters = [];
            this.filtersData = [];
            return;
        }

        //console.log('Filters received in child:',JSON.stringify(value, null, 2));

        this._filters = value;

        this.filtersData = value.map(f => ({
            ...f,
            isOpen: false,
            isMoreFilters: f.placeholder === "More Filters" ? true : false
        }));
    }

    toggleDropdown(event) {
        const order = Number(event.currentTarget.dataset.order);
        console.log('order======',order);

        this.filtersData = this.filtersData.map(f => ({
            ...f,
            isOpen: f.order === order ? !f.isOpen : false
        }));
    }

    handleSelect(event) {
        const { order, value } = event.currentTarget.dataset;

        //console.log('Selected:', order, value);

        this.filtersData = this.filtersData.map(f =>
            f.order === Number(order)
                ? { ...f, isOpen: false }
                : f
        );

        /*this.dispatchEvent(
            new CustomEvent('filterchange', {
                detail: { order: Number(order), value }
            })
        );*/
    }
}