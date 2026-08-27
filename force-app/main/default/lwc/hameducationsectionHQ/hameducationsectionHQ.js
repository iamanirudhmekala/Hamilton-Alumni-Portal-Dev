import { LightningElement, track } from 'lwc';
import getEducationData from '@salesforce/apex/HAMEducationSectionController.getEducationData';
import searchPostCodes from '@salesforce/apex/HAMEducationSectionController.searchPostCodes';
import searchMinorCodes from '@salesforce/apex/HAMEducationSectionController.searchMinorCodes';
import searchDegreeCodes from '@salesforce/apex/HAMEducationSectionController.searchDegreeCodes';
import searchInstitutions from '@salesforce/apex/HAMEducationSectionController.searchInstitutions';
import saveHamiltonDegree from '@salesforce/apex/HAMEducationSectionController.saveHamiltonDegree';
import saveGradDegree from '@salesforce/apex/HAMEducationSectionController.saveGradDegree';
import deleteGradDegree from '@salesforce/apex/HAMEducationSectionController.deleteGradDegree';

const MAX_SELECTIONS = 3;
const SEARCH_DEBOUNCE_MS = 300;

export default class HameducationsectionHQ extends LightningElement {
    @track isLoading = true;
    @track errorMessage;

    // ----- Hamilton College Degree state -----
    @track majors = [];   // [{id, label}]
    @track minors = [];   // [{id, label}]
    majorSearchTerm = '';
    minorSearchTerm = '';
    @track majorResults = [];
    @track minorResults = [];
    showMajorDropdown = false;
    showMinorDropdown = false;
    isSavingHamilton = false;

    // ----- Graduate School state -----
    @track gradDegrees = [];
    @track showGradModal = false;
    isSavingGrad = false;
    isDeletingGrad = false;

    // Modal form fields
    editingRecordId = null;
    @track institutionLabel = '';
    institutionId = null;
    @track institutionResults = [];
    showInstitutionDropdown = false;

    @track degreeCodeLabel = '';
    degreeCodeId = null;
    @track degreeCodeResults = [];
    showDegreeCodeDropdown = false;

    @track concentrationLabel = '';
    concentrationId = null;
    @track concentrationResults = [];
    showConcentrationDropdown = false;

    @track minorFieldLabel = '';
    minorFieldId = null;
    @track minorFieldResults = [];
    showMinorFieldDropdown = false;

    @track degreeYear = '';

    searchTimeout;

    connectedCallback() {
        this.loadData();
    }

    async loadData() {
        this.isLoading = true;
        this.errorMessage = undefined;
        try {
            const data = await getEducationData();
            this.majors = (data.hamiltonDegree && data.hamiltonDegree.majors) || [];
            this.minors = (data.hamiltonDegree && data.hamiltonDegree.minors) || [];
            this.gradDegrees = (data.gradDegrees || []).map((row) => ({
                ...row,
                degreeCodeDisplay: row.degreeCodeName || '—',
                concentrationDisplay: row.postCodeName || '—',
                minorDisplay: row.minorCodeName || '—'
            }));
        } catch (err) {
            this.errorMessage = this.reduceError(err);
        } finally {
            this.isLoading = false;
        }
    }

    reduceError(err) {
        return (err && err.body && err.body.message) || (err && err.message) || 'Something went wrong. Please try again.';
    }

    get hasNoGradDegrees() {
        return !this.isLoading && this.gradDegrees.length === 0;
    }

    // =====================================================================
    // Hamilton College Degree - Major chips
    // =====================================================================

    get majorLimitReached() {
        return this.majors.length >= MAX_SELECTIONS;
    }

    get minorLimitReached() {
        return this.minors.length >= MAX_SELECTIONS;
    }

    handleMajorInput(event) {
        this.majorSearchTerm = event.target.value;
        this.debounceSearch(() => this.runMajorSearch());
    }

    handleMajorFocus() {
        if (this.majorSearchTerm) {
            this.showMajorDropdown = true;
        }
    }

    async runMajorSearch() {
        if (!this.majorSearchTerm || this.majorLimitReached) {
            this.majorResults = [];
            this.showMajorDropdown = false;
            return;
        }
        try {
            const results = await searchPostCodes({ searchTerm: this.majorSearchTerm });
            const selectedIds = new Set(this.majors.map((m) => m.id));
            this.majorResults = results.filter((r) => !selectedIds.has(r.id));
            this.showMajorDropdown = true;
        } catch (err) {
            this.errorMessage = this.reduceError(err);
        }
    }

    selectMajor(event) {
        const id = event.currentTarget.dataset.id;
        const label = event.currentTarget.dataset.label;
        if (this.majorLimitReached || this.majors.some((m) => m.id === id)) {
            return;
        }
        this.majors = [...this.majors, { id, label }];
        this.majorSearchTerm = '';
        this.majorResults = [];
        this.showMajorDropdown = false;
        this.persistHamiltonDegree();
    }

    removeMajor(event) {
        const id = event.currentTarget.dataset.id;
        this.majors = this.majors.filter((m) => m.id !== id);
        this.persistHamiltonDegree();
    }

    // =====================================================================
    // Hamilton College Degree - Minor chips
    // =====================================================================

    handleMinorInput(event) {
        this.minorSearchTerm = event.target.value;
        this.debounceSearch(() => this.runMinorSearch());
    }

    handleMinorFocus() {
        if (this.minorSearchTerm) {
            this.showMinorDropdown = true;
        }
    }

    async runMinorSearch() {
        if (!this.minorSearchTerm || this.minorLimitReached) {
            this.minorResults = [];
            this.showMinorDropdown = false;
            return;
        }
        try {
            const results = await searchMinorCodes({ searchTerm: this.minorSearchTerm });
            const selectedIds = new Set(this.minors.map((m) => m.id));
            this.minorResults = results.filter((r) => !selectedIds.has(r.id));
            this.showMinorDropdown = true;
        } catch (err) {
            this.errorMessage = this.reduceError(err);
        }
    }

    selectMinor(event) {
        const id = event.currentTarget.dataset.id;
        const label = event.currentTarget.dataset.label;
        if (this.minorLimitReached || this.minors.some((m) => m.id === id)) {
            return;
        }
        this.minors = [...this.minors, { id, label }];
        this.minorSearchTerm = '';
        this.minorResults = [];
        this.showMinorDropdown = false;
        this.persistHamiltonDegree();
    }

    removeMinor(event) {
        const id = event.currentTarget.dataset.id;
        this.minors = this.minors.filter((m) => m.id !== id);
        this.persistHamiltonDegree();
    }

    async persistHamiltonDegree() {
        this.isSavingHamilton = true;
        this.errorMessage = undefined;
        try {
            await saveHamiltonDegree({
                majorIds: this.majors.map((m) => m.id),
                minorIds: this.minors.map((m) => m.id)
            });
        } catch (err) {
            this.errorMessage = this.reduceError(err);
        } finally {
            this.isSavingHamilton = false;
        }
    }

    // =====================================================================
    // Graduate School table + modal
    // =====================================================================

    handleAddNew() {
        this.resetModalForm();
        this.showGradModal = true;
    }

    handleEditRow(event) {
        const id = event.currentTarget.dataset.id;
        const row = this.gradDegrees.find((r) => r.recordId === id);
        if (!row) {
            return;
        }
        this.editingRecordId = row.recordId;
        this.institutionId = row.institutionId;
        this.institutionLabel = row.institutionName || '';
        this.degreeCodeId = row.degreeCodeId;
        this.degreeCodeLabel = row.degreeCodeName || '';
        this.concentrationId = row.postCodeId;
        this.concentrationLabel = row.postCodeName || '';
        this.minorFieldId = row.minorCodeId;
        this.minorFieldLabel = row.minorCodeName || '';
        this.degreeYear = row.degreeYear || '';
        this.showGradModal = true;
    }

    resetModalForm() {
        this.editingRecordId = null;
        this.institutionId = null;
        this.institutionLabel = '';
        this.institutionResults = [];
        this.degreeCodeId = null;
        this.degreeCodeLabel = '';
        this.degreeCodeResults = [];
        this.concentrationId = null;
        this.concentrationLabel = '';
        this.concentrationResults = [];
        this.minorFieldId = null;
        this.minorFieldLabel = '';
        this.minorFieldResults = [];
        this.degreeYear = '';
    }

    closeModal() {
        this.showGradModal = false;
        this.resetModalForm();
    }

    // --- School (Account) typeahead ---
    handleInstitutionInput(event) {
        const newValue = event.target.value;
        // Guard against the browser re-firing an input event with the same
        // value (autofill does this) which would otherwise wipe out a
        // just-selected institutionId even though nothing actually changed.
        if (newValue === this.institutionLabel && this.institutionId) {
            return;
        }
        this.institutionLabel = newValue;
        this.institutionId = null;
        this.debounceSearch(() => this.runInstitutionSearch());
    }

    async runInstitutionSearch() {
        if (!this.institutionLabel) {
            this.institutionResults = [];
            this.showInstitutionDropdown = false;
            return;
        }
        try {
            this.institutionResults = await searchInstitutions({ searchTerm: this.institutionLabel });
            this.showInstitutionDropdown = true;
        } catch (err) {
            this.errorMessage = this.reduceError(err);
        }
    }

    selectInstitution(event) {
        this.institutionId = event.currentTarget.dataset.id;
        this.institutionLabel = event.currentTarget.dataset.label;
        this.institutionResults = [];
        this.showInstitutionDropdown = false;
    }

    // No matching school found: keep the typed text, leave institutionId
    // null (it already is, since handleInstitutionInput clears it on every
    // keystroke), and just close the dropdown as an explicit confirmation.
    useTypedInstitution() {
        this.institutionResults = [];
        this.showInstitutionDropdown = false;
    }

    get showInstitutionUseTyped() {
        return this.showInstitutionDropdown && !!this.institutionLabel && !this.institutionId;
    }

    // --- Degree Type typeahead ---
    handleDegreeCodeInput(event) {
        const newValue = event.target.value;
        if (newValue === this.degreeCodeLabel && this.degreeCodeId) {
            return;
        }
        this.degreeCodeLabel = newValue;
        this.degreeCodeId = null;
        this.debounceSearch(() => this.runDegreeCodeSearch());
    }

    async runDegreeCodeSearch() {
        if (!this.degreeCodeLabel) {
            this.degreeCodeResults = [];
            this.showDegreeCodeDropdown = false;
            return;
        }
        try {
            this.degreeCodeResults = await searchDegreeCodes({ searchTerm: this.degreeCodeLabel });
            this.showDegreeCodeDropdown = true;
        } catch (err) {
            this.errorMessage = this.reduceError(err);
        }
    }

    selectDegreeCode(event) {
        this.degreeCodeId = event.currentTarget.dataset.id;
        this.degreeCodeLabel = event.currentTarget.dataset.label;
        this.degreeCodeResults = [];
        this.showDegreeCodeDropdown = false;
    }

    useTypedDegreeCode() {
        this.degreeCodeResults = [];
        this.showDegreeCodeDropdown = false;
    }

    get showDegreeCodeUseTyped() {
        return this.showDegreeCodeDropdown && !!this.degreeCodeLabel && !this.degreeCodeId;
    }

    // --- Concentration typeahead ---
    handleConcentrationInput(event) {
        const newValue = event.target.value;
        if (newValue === this.concentrationLabel && this.concentrationId) {
            return;
        }
        this.concentrationLabel = newValue;
        this.concentrationId = null;
        this.debounceSearch(() => this.runConcentrationSearch());
    }

    async runConcentrationSearch() {
        if (!this.concentrationLabel) {
            this.concentrationResults = [];
            this.showConcentrationDropdown = false;
            return;
        }
        try {
            this.concentrationResults = await searchPostCodes({ searchTerm: this.concentrationLabel });
            this.showConcentrationDropdown = true;
        } catch (err) {
            this.errorMessage = this.reduceError(err);
        }
    }

    selectConcentration(event) {
        this.concentrationId = event.currentTarget.dataset.id;
        this.concentrationLabel = event.currentTarget.dataset.label;
        this.concentrationResults = [];
        this.showConcentrationDropdown = false;
    }

    useTypedConcentration() {
        this.concentrationResults = [];
        this.showConcentrationDropdown = false;
    }

    get showConcentrationUseTyped() {
        return this.showConcentrationDropdown && !!this.concentrationLabel && !this.concentrationId;
    }

    // --- Minor (grad row) typeahead ---
    handleMinorFieldInput(event) {
        const newValue = event.target.value;
        if (newValue === this.minorFieldLabel && this.minorFieldId) {
            return;
        }
        this.minorFieldLabel = newValue;
        this.minorFieldId = null;
        this.debounceSearch(() => this.runMinorFieldSearch());
    }

    async runMinorFieldSearch() {
        if (!this.minorFieldLabel) {
            this.minorFieldResults = [];
            this.showMinorFieldDropdown = false;
            return;
        }
        try {
            this.minorFieldResults = await searchMinorCodes({ searchTerm: this.minorFieldLabel });
            this.showMinorFieldDropdown = true;
        } catch (err) {
            this.errorMessage = this.reduceError(err);
        }
    }

    selectMinorField(event) {
        this.minorFieldId = event.currentTarget.dataset.id;
        this.minorFieldLabel = event.currentTarget.dataset.label;
        this.minorFieldResults = [];
        this.showMinorFieldDropdown = false;
    }

    useTypedMinorField() {
        this.minorFieldResults = [];
        this.showMinorFieldDropdown = false;
    }

    get showMinorFieldUseTyped() {
        return this.showMinorFieldDropdown && !!this.minorFieldLabel && !this.minorFieldId;
    }

    handleDegreeYearChange(event) {
        this.degreeYear = event.target.value;
    }

    get isSaveDisabled() {
        // School may now be a selected record OR free text ("Other"); either
        // way saving is allowed as long as something was entered.
        return !this.institutionLabel || this.isSavingGrad;
    }

    async handleSaveGradDegree() {
        if (!this.institutionLabel) {
            this.errorMessage = 'Please enter or select a school.';
            return;
        }
        this.isSavingGrad = true;
        this.errorMessage = undefined;
        try {
            const form = {
                recordId: this.editingRecordId,
                institutionId: this.institutionId,
                institutionName: this.institutionLabel,
                degreeCodeId: this.degreeCodeId,
                degreeCodeName: this.degreeCodeLabel,
                postCodeId: this.concentrationId,
                postCodeName: this.concentrationLabel,
                minorCodeId: this.minorFieldId,
                minorCodeName: this.minorFieldLabel,
                degreeYear: this.degreeYear
            };
            const result = await saveGradDegree({ rowJson: JSON.stringify(form) });
            if (!result || !result.success) {
                this.errorMessage = (result && result.message) || 'Something went wrong. Please try again.';
                return;
            }
            this.closeModal();
            await this.loadData();
        } catch (err) {
            this.errorMessage = this.reduceError(err);
        } finally {
            this.isSavingGrad = false;
        }
    }

    async handleDeleteGradDegree() {
        if (!this.editingRecordId) {
            return;
        }
        this.isDeletingGrad = true;
        this.errorMessage = undefined;
        try {
            await deleteGradDegree({ recordId: this.editingRecordId });
            this.closeModal();
            await this.loadData();
        } catch (err) {
            this.errorMessage = this.reduceError(err);
        } finally {
            this.isDeletingGrad = false;
        }
    }

    // =====================================================================
    // Shared helpers
    // =====================================================================

    debounceSearch(fn) {
        window.clearTimeout(this.searchTimeout);
        this.searchTimeout = window.setTimeout(fn, SEARCH_DEBOUNCE_MS);
    }
}