import { LightningElement, api, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { CurrentPageReference } from 'lightning/navigation';
import getUserPreferences from '@salesforce/apex/HAMJediDashboardController.getUserPreferences';
import saveUserPreferences from '@salesforce/apex/HAMJediDashboardController.saveUserPreferences';

const WIDGET_REGISTRY = [
    { id: 'bioData',          label: 'Demographics',              icon: 'standard:contact',             size: 'full', collapsed: false },
    { id: 'givingOverview',   label: 'Giving Summary',            icon: 'standard:opportunity',         size: 'full', collapsed: false },
    { id: 'education',        label: 'Student Summary',           icon: 'standard:education',           size: 'full', collapsed: false },
    { id: 'serviceIndicator', label: 'Alumni Service Indicators', icon: 'standard:service_appointment', size: 'full', collapsed: false },
    { id: 'pledgeBalance',    label: 'Open Pledge',               icon: 'standard:payment_gateway',     size: 'full', collapsed: false }
];

const SIZE_PCT = { quarter: 25, half: 50, 'three-qtr': 75, full: 100 };

const DEFAULT_WIDGETS = () => WIDGET_REGISTRY.map((w, i) => ({ ...w, visible: true, order: i }));

export default class HamJEDIDashboard extends LightningElement {
    @api recordId;

    @track _widgets = [];
    @track isEditMode = false;

    _savedWidgets = [];
    _dragSourceId = null;
    _dragOverId = null;

    @wire(CurrentPageReference)
    wiredPageRef(pageRef) {
        if (pageRef?.state?.c__recordId) {
            this.recordId = pageRef.state.c__recordId;
        }
    }

    connectedCallback() {
        getUserPreferences()
            .then(result => {
                this._widgets = result
                    ? this._mergeWithRegistry(JSON.parse(result))
                    : DEFAULT_WIDGETS();
            })
            .catch(() => {
                this._widgets = DEFAULT_WIDGETS();
            });
    }

    _mergeWithRegistry(saved) {
        const savedMap = new Map(saved.map(s => [s.id, s]));
        const merged = WIDGET_REGISTRY.map(reg => {
            const s = savedMap.get(reg.id);
            return s
                ? { ...reg, visible: s.visible, order: s.order, size: s.size || 'full', collapsed: s.collapsed || false }
                : { ...reg, visible: true, order: 999 };
        });
        return merged.sort((a, b) => a.order - b.order).map((w, i) => ({ ...w, order: i }));
    }

    // ─── Getters ────────────────────────────────────────────

    get visibleWidgets() {
        const sorted = this._widgets
            .filter(w => w.visible)
            .sort((a, b) => a.order - b.order);

        return sorted.map((w, idx) => ({
            ...w,
            isBioData:           w.id === 'bioData',
            isGivingOverview:    w.id === 'givingOverview',
            isEducation:         w.id === 'education',
            isServiceIndicator:  w.id === 'serviceIndicator',
            isPledgeBalance:     w.id === 'pledgeBalance',
            isExpanded:          !w.collapsed,
            orderNum:            idx + 1,
            cardClass:           this._buildCardClass(w.id, w.size || 'full'),
            headerClass:         this.isEditMode ? 'widget-header widget-header-edit' : 'widget-header',
            sizeQuarterClass:    this._sizeBtnClass(w.size, 'quarter'),
            sizeHalfClass:       this._sizeBtnClass(w.size, 'half'),
            sizeThreeQtrClass:   this._sizeBtnClass(w.size, 'three-qtr'),
            sizeFullClass:       this._sizeBtnClass(w.size, 'full')
        }));
    }

    get hiddenWidgets() {
        return this._widgets.filter(w => !w.visible);
    }

    get hasHiddenWidgets() {
        return this.hiddenWidgets.length > 0;
    }

    get draggableStr() {
        return this.isEditMode ? 'true' : 'false';
    }

    get dashboardContainerClass() {
        return this.isEditMode ? 'dashboard-container edit-mode' : 'dashboard-container';
    }

    _buildCardClass(id, size) {
        let cls = `widget-col-${size} widget-card`;
        if (this.isEditMode)           cls += ' widget-card-editable';
        if (this._dragOverId === id)   cls += ' drag-over';
        if (this._dragSourceId === id) cls += ' dragging';
        return cls;
    }

    _sizeBtnClass(current, btn) {
        return current === btn ? 'size-btn size-btn-active' : 'size-btn';
    }

    // ─── Edit mode ──────────────────────────────────────────

    handleCustomize() {
        this._savedWidgets = JSON.parse(JSON.stringify(this._widgets));
        this.isEditMode = true;
    }

    handleCancel() {
        this._widgets = JSON.parse(JSON.stringify(this._savedWidgets));
        this.isEditMode = false;
    }

    handleSave() {
        const prefs = this._widgets.map(w => ({
            id: w.id, visible: w.visible, order: w.order, size: w.size, collapsed: w.collapsed || false
        }));
        saveUserPreferences({ prefsJson: JSON.stringify(prefs) })
            .then(() => {
                this.isEditMode = false;
                this.dispatchEvent(new ShowToastEvent({ title: 'Saved', message: 'Dashboard preferences saved.', variant: 'success' }));
            })
            .catch(err => {
                this.dispatchEvent(new ShowToastEvent({ title: 'Error', message: err?.body?.message || 'Save failed.', variant: 'error' }));
            });
    }

    handleResetDefault() {
        this._widgets = DEFAULT_WIDGETS();
    }

    handleRemove(event) {
        const id = event.currentTarget.dataset.id;
        this._widgets = this._widgets.map(w => w.id === id ? { ...w, visible: false } : w);
    }

    handleAdd(event) {
        const id = event.currentTarget.dataset.id;
        const maxOrder = this._widgets.filter(w => w.visible).reduce((max, w) => Math.max(max, w.order), -1);
        this._widgets = this._widgets.map(w => w.id === id ? { ...w, visible: true, order: maxOrder + 1 } : w);
    }

    handleResize(event) {
        const id = event.currentTarget.dataset.id;
        const size = event.currentTarget.dataset.size;
        this._widgets = this._widgets.map(w => w.id === id ? { ...w, size } : w);
    }

    handleToggleCollapse(event) {
        const id = event.currentTarget.dataset.id;
        const isCollapsed = event.target.checked;
        this._widgets = this._widgets.map(w => w.id === id ? { ...w, collapsed: isCollapsed } : w);
    }

    // ─── Drag and drop ──────────────────────────────────────

    handleDragStart(event) {
        this._dragSourceId = event.currentTarget.dataset.id;
        event.dataTransfer.effectAllowed = 'move';
    }

    handleDragOver(event) {
        event.preventDefault();
        event.dataTransfer.dropEffect = 'move';
        const targetId = event.currentTarget.dataset.id;
        if (targetId !== this._dragSourceId && targetId !== this._dragOverId) {
            this._dragOverId = targetId;
            this._widgets = [...this._widgets];
        }
    }

    handleDragLeave(event) {
        if (event.currentTarget.dataset.id === this._dragOverId) {
            this._dragOverId = null;
            this._widgets = [...this._widgets];
        }
    }

    handleDrop(event) {
        event.preventDefault();
        const targetId = event.currentTarget.dataset.id;
        if (!this._dragSourceId || this._dragSourceId === targetId) return;

        const widgets = [...this._widgets];
        const srcIdx = widgets.findIndex(w => w.id === this._dragSourceId);
        const tgtIdx = widgets.findIndex(w => w.id === targetId);

        const [moved] = widgets.splice(srcIdx, 1);
        widgets.splice(tgtIdx, 0, moved);

        const reordered = widgets.map((w, i) => ({ ...w, order: i }));
        this._widgets = this._autoResizeDropped(reordered, this._dragSourceId);
        this._dragSourceId = null;
        this._dragOverId = null;
    }

    handleDragEnd() {
        this._dragSourceId = null;
        this._dragOverId = null;
        this._widgets = [...this._widgets];
    }

    // ─── Auto-resize on drop ────────────────────────────────

    _autoResizeDropped(widgets, droppedId) {
        const visible = widgets.filter(w => w.visible).sort((a, b) => a.order - b.order);
        let rowPct = 0;
        let newSize = null;

        for (const w of visible) {
            const pct = SIZE_PCT[w.size] || 100;

            if (w.id === droppedId) {
                const remaining = 100 - rowPct;
                if (pct > remaining && remaining > 0) {
                    // find largest size that fits remaining space
                    if (remaining >= 75)      newSize = 'three-qtr';
                    else if (remaining >= 50) newSize = 'half';
                    else if (remaining >= 25) newSize = 'quarter';
                    else { rowPct = 0; newSize = 'full'; } // nothing fits, start new row
                }
                const finalPct = SIZE_PCT[newSize || w.size] || 100;
                rowPct = (rowPct + finalPct >= 100) ? 0 : rowPct + finalPct;
            } else {
                if (rowPct + pct > 100) rowPct = pct;
                else { rowPct += pct; if (rowPct >= 100) rowPct = 0; }
            }
        }

        if (!newSize) return widgets;
        return widgets.map(w => w.id === droppedId ? { ...w, size: newSize } : w);
    }
}