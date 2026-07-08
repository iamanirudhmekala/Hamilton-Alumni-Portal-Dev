import { LightningElement, api, track } from 'lwc';

// IMPORT APEX METHODS
import saveUserPreferences from '@salesforce/apex/HAM_AlumniDirectoryController.saveUserPreferences';
import searchFilterOptions from '@salesforce/apex/HAM_AlumniDirectoryController.searchFilterOptions';

// IMPORT STATIC RESOURCES
import HAM_ICONS from '@salesforce/resourceUrl/HAM_Icons';

// IMPORT Custom Label
import ClearFilter from '@salesforce/label/c.ham_clearFilter';
import Apply from '@salesforce/label/c.ham_Apply';

export default class Ham_alumniSearchFilterCmp extends LightningElement {

    @api searchStr;
    @api contactId;
    @api isOverride = false;

    get wrapperClass() {
        return this.isOverride ? 'filter-root kirkland-override' : 'filter-root';
    }

    @track filterOptions = [];
    @track isMoreFiltersOpen = false;
    @track selectedFiltersPayload = [];
    @track screenWidth = window.innerWidth;

    // Mobile View State
    @track selectedMobileFilterOrder = null;
    @track isMobileFilterLoading = false;
    @track searchInput = false;

    label = {
        clearFilter: ClearFilter,
        apply: Apply
    };

    // NEW: Tracked property for mobile filter values (fixes checkbox reactivity)
    @track mobileFilterValues = [];

    // Internal State
    originalValueset = {};
    _filters;
    _savedFilters;
    @track areFiltersChanged = false;

    // Debounce timer for Type-Ahead
    searchTimeout;

    hamIcons = HAM_ICONS;
    icons = {
        moreFiltersIcon: this.hamIcons + '/more-filters.png',
        dropDownOuter: this.hamIcons + '/drop-down-outer.png',
        dropDownInner: this.hamIcons + '/drop-down-inner.png',
    }

    // ------------------------------------------------------------------------
    // GETTERS & SETTERS
    // ------------------------------------------------------------------------

    /**
     * @description Setter to receive and apply user-saved filters from parent component.
     *              Stores filters locally and attempts to populate them into the UI.
     * @param {Array} value - Array of saved filter configurations.
     */
    @api
    set savedFilters(value) {
        if (!value || !Array.isArray(value)) {
            return;
        }
        this._savedFilters = value;
        this.tryPopulateSavedFilters();
    }

    /**
     * @description Getter to return locally stored saved filters.
     * @return {Array} List of saved filters.
     */
    get savedFilters() {
        return this._savedFilters;
    }

    /**
      * @description Getter to return filter metadata provided from Apex (Top 500 options).
      * @return {Array} List of available filters.
      */
    @api
    get filters() {
        return this._filters;
    }

    /**
     * @description Setter to initialize filter metadata, build master value sets,
     *              prepare UI filter options, and apply mobile and saved filter states.
     * @param {Array} value - Array of filter metadata objects from Apex.
     */
    set filters(value) {
        if (!Array.isArray(value)) {
            this._filters = [];
            this.filterOptions = [];
            return;
        }

        this._filters = value;

        // Build Master List (Top 500 from Apex)
        this.originalValueset = value.reduce((acc, f) => {
            acc[String(f.order)] = Array.isArray(f.values) ? [...f.values] : [];
            return acc;
        }, {});

        // Initialize UI Options
        this.filterOptions = value.map(f => ({
            ...f,
            // Sort values appropriately based on filter type
            values: this.sortFilterValues(f.placeholder, f.values || [])
                .map(v => ({ label: v, checked: false })),
            selectedValues: [],
            searchKey: '',
            displayValue: f.placeholder,
            hoverText: f.placeholder,
            isOpen: false,
            isMoreFilters: f.placeholder === 'More Filters'
        }));

        // Initialize mobile filter selection AFTER filterOptions are set
        this.initializeMobileFilterSelection();

        // Update mobile filter values
        this.updateMobileFilterValues();

        this.tryPopulateSavedFilters();
    }

    /**
     * @description Sort filter values based on filter type
     * Class Year: Descending numeric order
     * Others: Alphabetical ascending order
     */
    sortFilterValues(placeholder, values) {
        const valuesCopy = values.slice();

        if (placeholder === 'Class Year') {
            // Sort years in DESCENDING order (newest first)
            return valuesCopy.sort((a, b) => {
                const yearA = parseInt(a, 10) || 0;
                const yearB = parseInt(b, 10) || 0;
                return yearB - yearA; // Descending
            });
        }

        // Default: alphabetical ascending
        return valuesCopy.sort((a, b) => a.localeCompare(b));
    }

    /**
     * @description Ensures both saved filters and filter metadata are available
     *              before applying saved values to the UI.
     *              Prevents premature mapping during initialization.
     */
    tryPopulateSavedFilters() {
        if (!Array.isArray(this.filterOptions) || !this.filterOptions.length) {
            return;
        }

        if (Array.isArray(this._savedFilters)) {
            if (this._savedFilters.length > 0) {
                this.populateSavedFilters();
            } else {
                // If an empty array is explicitly passed (e.g., restoring a cleared session),
                // we safely reset all checkbox selections without closing open dropdowns or modals.
                this.filterOptions = this.filterOptions.map(f => {
                    return {
                        ...f,
                        values: f.values.map(v => ({ ...v, checked: false })),
                        selectedValues: [],
                        displayValue: f.placeholder,
                        hoverText: f.placeholder
                    };
                });
                this.updateMobileFilterValues();
                this.selectedFiltersPayload = [];
            }
        }
    }

    /**
     * @description LWC lifecycle hook executed when component is inserted into DOM.
     *              Registers global click and resize listeners and initializes
     *              mobile filter loading state.
     */
    connectedCallback() {
        window.addEventListener('click', this.closeAll.bind(this));
        // Event listener for window resize
        window.addEventListener('resize', this.handleResize.bind(this));

        // Remove loading delay - show content immediately
        this.isMobileFilterLoading = false;
    }



    /**
     * @description LWC lifecycle hook executed when component is removed from DOM.
     *              Cleans up global event listeners to prevent memory leaks.
     */
    disconnectedCallback() {
        window.removeEventListener('click', this.closeAll.bind(this));
        window.removeEventListener('resize', this.handleResize.bind(this));
    }

    /**
     * @description Updates the screen width property on window resize.
     */
    handleResize() {
        this.screenWidth = window.innerWidth;
    }

    /**
     * @description Determines whether the current viewport is mobile.
     * @returns {Boolean} True if screen width is less than 1024px.
     */
    get isMobileView() {
        return this.screenWidth < 1024;
    }

    /**
     * @description Determines whether the current viewport is desktop.
     * @returns {Boolean} True if screen width is 1024px or greater.
     */
    get isDesktopView() {
        return this.screenWidth >= 1024;
    }

    // ------------------------------------------------------------------------
    // MOBILE VIEW GETTERS & HANDLERS
    // ------------------------------------------------------------------------

    /**
     * @description Returns all filters for mobile sidebar (excludes "More Filters" pill)
     */
    
    get allFilters() {
        return this.filterOptions
            .filter(f => !f.isMoreFilters)
            .sort((a, b) => a.order - b.order)
            .map(filter => {
                const selectedCount = filter.selectedValues ? filter.selectedValues.length : 0;
                return {
                    ...filter,
                    mobileSidebarClass: this.getMobileSidebarClass(filter.order),
                    selectedCount,
                    hasSelectedValues: selectedCount > 0
                };
            });
    }

    /**
     * @description Returns CSS class for mobile sidebar items based on selection state
     */
    getMobileSidebarClass(order) {
        const baseClass = 'sidebar-filter-item';
        const effectiveOrder = this.getEffectiveMobileFilterOrder();

        if (effectiveOrder === order) {
            return `${baseClass} active`;
        }
        return baseClass;
    }

    /**
     * @description Get effective mobile filter order without modifying state
     */
    getEffectiveMobileFilterOrder() {
        if (this.selectedMobileFilterOrder !== null) {
            return this.selectedMobileFilterOrder;
        }
        const firstFilter = this.filterOptions.find(f => !f.isMoreFilters);
        return firstFilter ? firstFilter.order : null;
    }

    /**
     * @description Initialize mobile filter selection when filters are loaded
     */
    initializeMobileFilterSelection() {
        if (this.selectedMobileFilterOrder === null && this.filterOptions.length > 0) {
            const firstFilter = this.filterOptions.find(f => !f.isMoreFilters);
            if (firstFilter) {
                this.selectedMobileFilterOrder = firstFilter.order;
            }
        }
    }

    /**
     * @description Update the tracked mobileFilterValues array for reactivity
     */
    updateMobileFilterValues() {
        const effectiveOrder = this.getEffectiveMobileFilterOrder();
        if (effectiveOrder === null) {
            this.mobileFilterValues = [];
            return;
        }

        const filter = this.filterOptions.find(f => f.order === effectiveOrder);
        if (!filter) {
            this.mobileFilterValues = [];
            return;
        }

        // Create a new array with all necessary properties for the template
        if (filter.placeholder === 'Class Year') {
            this.mobileFilterValues = filter.values.map(v => ({
                ...v,
                chipClass: v.checked ? 'year-chip year-chip-selected' : 'year-chip'
            }));
        } else {
            this.mobileFilterValues = filter.values.map(v => ({
                ...v
            }));
        }
    }

    /**
     * @description Returns the currently selected filter for mobile view (metadata only)
     */
    get selectedMobileFilter() {
        const availableFilters = this.filterOptions.filter(f => !f.isMoreFilters);

        if (availableFilters.length === 0) {
            return null;
        }

        const effectiveOrder = this.getEffectiveMobileFilterOrder();
        let selected = null;

        if (effectiveOrder !== null) {
            selected = availableFilters.find(f => f.order === effectiveOrder);
        }

        if (!selected) {
            selected = availableFilters[0];
        }

        return selected;
    }

    /**
     * @description Check if selected filter is Class Year
     */
    get isClassYearFilter() {
        const selected = this.selectedMobileFilter;
        return selected && selected.placeholder === 'Class Year';
    }

    /**
     * @description Check if there are filter values to display
     */
    get hasMobileFilterValues() {
        return this.mobileFilterValues && this.mobileFilterValues.length > 0;
    }

    /**
     * @description Handle mobile checkbox click (use click instead of change for better control)
     */
    handleMobileCheckboxClick(event) {
        event.stopPropagation();

        const order = event.currentTarget.dataset.order;
        const label = event.currentTarget.dataset.value;

        // Find current checked state and toggle it
        const currentFilter = this.filterOptions.find(f => String(f.order) === String(order));
        if (!currentFilter) return;

        const isCurrentlyChecked = currentFilter.selectedValues.includes(label);
        const newCheckedState = !isCurrentlyChecked;

        this.filterOptions = this.filterOptions.map(f => {
            if (String(f.order) !== String(order)) return f;

            let selectedValues = [...(f.selectedValues || [])];

            if (newCheckedState) {
                if (!selectedValues.includes(label)) {
                    selectedValues.push(label);
                }
            } else {
                selectedValues = selectedValues.filter(v => v !== label);
            }

            const updatedValues = f.values.map(v => ({
                ...v,
                checked: selectedValues.includes(v.label)
            }));

            return {
                ...f,
                values: updatedValues,
                selectedValues,
                hoverText: selectedValues.join(', '),
                displayValue: selectedValues.length
                    ? `${f.placeholder} (${selectedValues.length})`
                    : f.placeholder
            };
        });

        // Update mobile filter values for reactivity
        this.updateMobileFilterValues();

        // Notify Parent of Change
        this.areFiltersChanged = true;
        this.dispatchFilterUpdate();
    }

    /**
     * @description Handle year chip click (toggle selection)
     */
    handleYearChipClick(event) {
        event.stopPropagation();

        const order = event.currentTarget.dataset.order;
        const label = event.currentTarget.dataset.value;

        this.filterOptions = this.filterOptions.map(f => {
            if (String(f.order) !== String(order)) return f;

            let selectedValues = [...(f.selectedValues || [])];
            const isCurrentlySelected = selectedValues.includes(label);

            if (isCurrentlySelected) {
                selectedValues = selectedValues.filter(v => v !== label);
            } else {
                selectedValues.push(label);
            }

            const updatedValues = f.values.map(v => ({
                ...v,
                checked: selectedValues.includes(v.label),
                chipClass: selectedValues.includes(v.label) ? 'year-chip year-chip-selected' : 'year-chip'
            }));

            return {
                ...f,
                values: updatedValues,
                selectedValues,
                hoverText: selectedValues.join(', '),
                displayValue: selectedValues.length
                    ? `${f.placeholder} (${selectedValues.length})`
                    : f.placeholder
            };
        });

        // Update mobile filter values for reactivity
        this.updateMobileFilterValues();

        // Notify Parent of Change
        this.areFiltersChanged = true;
        this.dispatchFilterUpdate();
    }

    /**
     * @description Handles clicking on a filter category in mobile sidebar
     */
    handleMobileFilterSelect(event) {
        event.stopPropagation();
        const order = event.currentTarget.dataset.order;
        this.selectedMobileFilterOrder = parseInt(order, 10);

        // Update mobile filter values for the newly selected filter
        this.updateMobileFilterValues();

        // Close any open dropdowns when switching filters
        this.filterOptions = this.filterOptions.map(f => ({
            ...f,
            isOpen: false
        }));
    }

    /**
     * @description Clears all applied filters temporarily and resets UI state to defaults.
     * Also updates mobile values, resets payload, marks filters as changed,
     * and notifies parent with empty filter selection.
     * @returns {void}
     */
    @api
    clearAllFiltersTemporarily() {
        // Clear all filter selections
        this.filterOptions = this.filterOptions.map(f => {
            const originalValues = this.originalValueset[String(f.order)] || [];
            const sortedValues = this.sortFilterValues(f.placeholder, originalValues);

            return {
                ...f,
                values: sortedValues.map(v => ({ label: v, checked: false })),
                selectedValues: [],
                searchKey: '',
                displayValue: f.placeholder,
                hoverText: f.placeholder,
                isOpen: false
            };
        });

        // Update mobile filter values for reactivity
        this.updateMobileFilterValues();

        // Clear the payload
        this.selectedFiltersPayload = [];

        // Mark filters as changed
        this.areFiltersChanged = true;

        // Notify parent with empty filters
        this.dispatchEvent(new CustomEvent('filterchange', {
            detail: {
                filters: [],
                areFiltersChanged: true
            }
        }));
    }

    /**
    * @description Clears all applied filters and resets UI state
    * Also updates mobile values
    * This method is called on tab switch. Parent already clears the reactive savedFilters. So we are just clearing UI state.
    * No event dispatch is done here
    */
    @api
    clearAllFiltersOnTabSwitch() {
        this.filterOptions = this.filterOptions.map(f => {
            const originalValues = this.originalValueset[String(f.order)] || [];
            const sortedValues = this.sortFilterValues(f.placeholder, originalValues);
            return {
                ...f,
                values: sortedValues.map(v => ({ label: v, checked: false })),
                selectedValues: [],
                searchKey: '',
                displayValue: f.placeholder,
                hoverText: f.placeholder,
                isOpen: false
            };
        });
        this.updateMobileFilterValues();
        this.selectedFiltersPayload = [];
        this.areFiltersChanged = false;
        this.isMoreFiltersOpen = false;
    }

    /**
     * @description Closes mobile filters view
     */
    closeMobileFilters(event) {
        if (event) event.stopPropagation();

        // Dispatch event to parent to close mobile view if needed
        this.dispatchEvent(new CustomEvent('closemobilefilters'));
    }

    /**
     * @description Clears all filter selections (for mobile)
     */
    handleClearAllFilters(event) {
        if (event) event.stopPropagation();

        this.filterOptions = this.filterOptions.map(f => {
            const originalValues = this.originalValueset[String(f.order)] || [];
            const sortedValues = this.sortFilterValues(f.placeholder, originalValues);

            return {
                ...f,
                values: sortedValues.map(v => ({ label: v, checked: false })),
                selectedValues: [],
                searchKey: '',
                displayValue: f.placeholder,
                hoverText: f.placeholder,
                isOpen: false
            };
        });

        // Update mobile filter values for reactivity
        this.updateMobileFilterValues();

        // Notify Parent
        this.areFiltersChanged = true;
        this.searchInput = true;
        this.dispatchFilterUpdate();
        if (this.isMobileView) {
            this.closeMobileFilters();
        }
    }

    // ------------------------------------------------------------------------
    // HELPER: BROADCAST TO PARENT (Fixes Search Button Tandem Issue)
    // ------------------------------------------------------------------------
    /**
     * @description Builds the selected filters payload and dispatches a filterchange event
     * to notify the parent component of updated filters and change state.
     * @returns {void}
     */
    dispatchFilterUpdate() {
        this.buildSelectedFiltersPayload();
        this.dispatchEvent(new CustomEvent('filterchange', {
            detail: {
                filters: this.selectedFiltersPayload,
                areFiltersChanged: this.areFiltersChanged,
                clearSearchKey: this.searchInput
            }
        }));
        this.searchInput = false;

    }

    // ------------------------------------------------------------------------
    // SEARCH LOGIC (Type-Ahead: Local First -> Server Second)
    // ------------------------------------------------------------------------

    /**
     * @description Handles dropdown search input by performing instant local filtering
     * and triggering a debounced server-side search for additional options.
     * @param {Event} event - Input change event from the dropdown search field.
     * @returns {void}
     */
    handleDropdownSearch(event) {
        event.stopPropagation();
        const order = event.target.dataset.order;
        const searchTerm = event.target.value;
        const lowerTerm = searchTerm.toLowerCase();

        // 1. LOCAL FILTERING (Instant Feedback)
        this.filterOptions = this.filterOptions.map(f => {
            if (String(f.order) !== String(order)) return f;

            const original = this.originalValueset[String(order)] || [];
            let filtered = original;

            if (searchTerm) {
                filtered = original.filter(v => v.toLowerCase().includes(lowerTerm));
            }

            const sortedFiltered = this.sortFilterValues(f.placeholder, filtered);

            return {
                ...f,
                searchKey: searchTerm,
                values: sortedFiltered.map(v => ({
                    label: v,
                    checked: f.selectedValues.includes(v)
                }))
            };
        });

        // Update mobile filter values for reactivity
        this.updateMobileFilterValues();

        // 2. SERVER SEARCH (Debounced)
        clearTimeout(this.searchTimeout);

        if (searchTerm.length >= 2) {
            this.searchTimeout = setTimeout(() => {
                this.fetchServerOptions(order, searchTerm);
            }, 400);
        }
    }

    /**
     * @description Fetches additional filter options from the server based on the search term
     * and merges them with existing values while preserving selected states.
     * @param {String} order - Filter order identifier.
     * @param {String} searchTerm - User-entered search term.
     * @returns {void}
     */
    fetchServerOptions(order, searchTerm) {
        const filterIndex = this.filterOptions.findIndex(f => String(f.order) === String(order));
        if (filterIndex === -1) return;

        const placeholder = this.filterOptions[filterIndex].placeholder;

        searchFilterOptions({ placeholder: placeholder, searchTerm: searchTerm })
            .then(serverResults => {
                if (!serverResults || serverResults.length === 0) return;

                this.filterOptions = this.filterOptions.map(f => {
                    if (String(f.order) !== String(order)) return f;

                    const currentLabels = new Set(f.values.map(v => v.label));
                    const newValues = [...f.values];

                    serverResults.forEach(val => {
                        if (!currentLabels.has(val)) {
                            newValues.push({
                                label: val,
                                checked: f.selectedValues.includes(val)
                            });
                        }
                    });

                    const labels = newValues.map(v => v.label);
                    const sortedLabels = this.sortFilterValues(f.placeholder, labels);

                    const sortedValues = sortedLabels.map(label => ({
                        label: label,
                        checked: f.selectedValues.includes(label)
                    }));

                    return { ...f, values: sortedValues };
                });

                // Update mobile filter values for reactivity
                this.updateMobileFilterValues();
            })
            .catch(error => {
                console.error('Type-ahead error', error);
            });
    }

    // ------------------------------------------------------------------------
    // UI INTERACTION HANDLERS
    // ------------------------------------------------------------------------

    /**
     * @description Opens the selected filter dropdown, closes all others, and initializes values.
     * Handles "More Filters" separately by opening the modal view.
     * @param {Event} event - Click event from the dropdown trigger.
     * @returns {void}
     */
    toggleDropdown(event) {
        event.stopPropagation();
        const order = event.currentTarget.dataset.order;
        const clickedFilter = this.filterOptions.find(f => String(f.order) === String(order));

        if (clickedFilter?.isMoreFilters) {
            this.filterOptions = this.filterOptions.map(f => ({
                ...f,
                isOpen: false,
                searchKey: ''
            }));
            this.isMoreFiltersOpen = true;
            return;
        }

        this.filterOptions = this.filterOptions.map(f => {
            const isSameFilter = String(f.order) === String(order);

            if (isSameFilter && !f.isOpen) {
                const originalValues = this.originalValueset[String(f.order)] || [];
                const sortedValues = this.sortFilterValues(f.placeholder, originalValues);

                return {
                    ...f,
                    isOpen: true,
                    searchKey: '',
                    values: sortedValues.map(v => ({
                        label: v,
                        checked: f.selectedValues.includes(v)
                    }))
                };
            }

            return {
                ...f,
                isOpen: false,
                searchKey: ''
            };
        });
    }

    /**
     * @description Closes all open filter dropdowns when clicking outside the component,
     * except when the More Filters panel is active.
     * @param {Event} event - Global click event.
     * @returns {void}
     */
    closeAll(event) {
        if (this.isMoreFiltersOpen) return;
        if (!this.template.contains(event.target)) {
            this.filterOptions = this.filterOptions.map(f => ({ ...f, isOpen: false, searchKey: '' }));
        }
    }

    // ------------------------------------------------------------------------
    // SELECTION LOGIC
    // ------------------------------------------------------------------------

    /**
     * @description Handles checkbox selection inside a filter dropdown.
     * Updates selected values, maintains checked states, refreshes display labels,
     * and notifies the parent component of filter changes.
     * @param {Event} event - Change event from the checkbox input.
     * @returns {void}
     */
    handleCheckboxToggle(event) {
        event.stopPropagation();

        const order = event.target.dataset.order;
        const label = event.target.dataset.value;
        const checked = event.target.checked;

        this.filterOptions = this.filterOptions.map(f => {
            if (String(f.order) !== String(order)) return f;

            let selectedValues = [...(f.selectedValues || [])];
            if (checked) {
                if (!selectedValues.includes(label)) {
                    selectedValues.push(label);
                }
            } else {
                selectedValues = selectedValues.filter(v => v !== label);
            }

            const updatedValues = f.values.map(v => ({
                ...v,
                checked: selectedValues.includes(v.label)
            }));

            return {
                ...f,
                values: updatedValues,
                selectedValues,
                hoverText: selectedValues.join(', '),
                displayValue: selectedValues.length
                    ? `${f.placeholder} (${selectedValues.length})`
                    : f.placeholder,
                isOpen: this.isDesktopView ? f.isOpen : false
            };
        });

        // Notify Parent of Change
        this.areFiltersChanged = true;
        this.dispatchFilterUpdate();
    }

    /**
     * @description Clears all selected values for a specific filter (or all filters if no order is provided),
     * resets the dropdown to its original state, updates mobile values, and dispatches filter change events.
     * @param {Event} event - Click event from the clear filter action.
     * @returns {void}
     */
    handleClearFilter(event) {
        event.stopPropagation();
        const order = event.target.dataset.order;

        this.filterOptions = this.filterOptions.map(f => {
            if (order && String(f.order) !== String(order)) return f;

            const originalValues = this.originalValueset[String(f.order)] || [];
            const sortedValues = this.sortFilterValues(f.placeholder, originalValues);

            return {
                ...f,
                values: sortedValues.map(v => ({ label: v, checked: false })),
                selectedValues: [],
                searchKey: '',
                displayValue: f.placeholder,
                hoverText: f.placeholder,
                isOpen: false
            };
        });

        // Update mobile filter values for reactivity
        this.updateMobileFilterValues();

        // Notify Parent
        this.areFiltersChanged = true;
        this.dispatchFilterUpdate();
        this.isMoreFiltersOpen = false;
    }

    // ------------------------------------------------------------------------
    // INITIALIZATION & SAVING
    // ------------------------------------------------------------------------

    /**
     * @description Applies previously saved filter selections to current filter metadata.
     * Merges saved values with original value sets, restores checked states,
     * updates display labels, refreshes mobile values, and dispatches the initial filter state.
     * @returns {void}
     */
populateSavedFilters() {
    const savedMap = {};
    this._savedFilters.forEach(f => {
        savedMap[f.placeholder] = f.values || [];
    });

    this.filterOptions = this.filterOptions.map(f => {
        const selected = savedMap[f.placeholder] || [];

        // Category NOT in the saved set -> reset it. This is what clears a
        // filter (e.g. Region) removed from a badge so the main pill updates
        // instead of staying on "Region (1)".
        if (!selected.length) {
            return {
                ...f,
                values: f.values.map(v => ({ ...v, checked: false })),
                selectedValues: [],
                searchKey: '',
                displayValue: f.placeholder,
                hoverText: f.placeholder
            };
        }

        const original = this.originalValueset[String(f.order)] || [];
        const mergedValues = new Set([...original, ...selected]);
        const valuesArray = this.sortFilterValues(f.placeholder, Array.from(mergedValues));

        return {
            ...f,
            selectedValues: [...selected],
            values: valuesArray.map(v => ({
                label: v,
                checked: selected.includes(v)
            })),
            hoverText: selected.join(', '),
            displayValue: `${f.placeholder} (${selected.length})`
        };
    });

    // Update mobile filter values for reactivity
    this.updateMobileFilterValues();

    // Notify Parent of Initial State
    this.areFiltersChanged = false;
}
    /**
     * @description Builds the selected filters payload and persists user preferences to the server.
     * Resets the change flag on success and notifies the parent component.
     * @returns {Promise} Resolves when filters are successfully saved.
     */
    @api
    saveSelectedFilters() {
        this.buildSelectedFiltersPayload();
        const payload = JSON.stringify(this.selectedFiltersPayload);

        return saveUserPreferences({ filtersJson: payload, currentContactId: this.contactId })
            .then(() => {
                this.areFiltersChanged = false;
                // this.dispatchEvent(
                //     new CustomEvent('filterchange', {
                //         detail: { areFiltersChanged: false}
                //     })
                // );
            })
            .catch((error) => {
                console.log('Error on filter save', error);
                throw error;
            });
    }

    /**
     * @description Constructs the selected filters payload from current filter options,
     * including only filters with active selections.
     * @returns {void}
     */
    buildSelectedFiltersPayload() {
        this.selectedFiltersPayload = this.filterOptions
            .filter(f => f.selectedValues && f.selectedValues.length)
            .map(f => ({
                placeholder: f.placeholder,
                values: [...f.selectedValues]
            }));
    }

    // ------------------------------------------------------------------------
    // UTILITIES & MODAL LOGIC
    // ------------------------------------------------------------------------

    /**
     * @description Returns the primary filter set (Class Year, Industry, Sports Association, and More Filters),
     * sorted by display order. Used to render the main filter bar.
     * @returns {Array} List of primary filter objects.
     */
    get primaryFilters() {
        return this.filterOptions
            .filter(f => ['Class Year', 'Industry', 'Region', 'More Filters'].includes(f.placeholder))
            .sort((a, b) => a.order - b.order);
    }

    /**
     * @description Returns all non-primary filters sorted by display order.
     * Typically rendered inside the "More Filters" panel.
     * @returns {Array} List of secondary filter objects.
     */
    get secondaryFilters() {
        return this.filterOptions
            .filter(f => !['Class Year', 'Industry', 'Region', 'More Filters'].includes(f.placeholder))
            .sort((a, b) => a.order - b.order);
    }

    /**
     * @description Exposes whether any filter selections have changed and are not yet saved.
     * Used by parent components to detect unsaved filter state.
     * @returns {Boolean} True if filters were modified, otherwise false.
     */
    @api
    get hasUnsavedChanges() {
        return this.areFiltersChanged;
    }

    /**
     * @description Proxy handler for input search events.
     * Delegates processing to handleDropdownSearch for unified search logic.
     * @param {Event} event - Input change event from search field.
     * @returns {void}
     */
    handleInputSearch(event) {
        this.handleDropdownSearch(event);
    }

    /**
     * @description Handles clicks inside the modal container.
     * Closes all open filter dropdowns when clicking outside any filter pill.
     * @param {Event} event - Click event from modal area.
     * @returns {void}
     */
    handleModalClick(event) {
        event.stopPropagation();
        const clickedFilter = event.target.closest('.filter-pill');
        if (!clickedFilter) {
            this.filterOptions = this.filterOptions.map(f => ({
                ...f, isOpen: false, searchKey: ''
            }));
        }
    }

    /**
     * @description Closes the "More Filters" modal and resets all dropdown states.
     * Stops event propagation when triggered from UI controls.
     * @param {Event} event - Optional click event.
     * @returns {void}
     */
    closeMoreFilters(event) {
        if (event) event.stopPropagation();
        this.isMoreFiltersOpen = false;
        this.filterOptions = this.filterOptions.map(f => ({
            ...f, isOpen: false, searchKey: ''
        }));
    }

    /**
     * @description Applies selected filters and closes the appropriate filter UI
     * based on the current viewport (mobile or desktop).
     * @param {Event} event - Click event from the Apply Filters button.
     * @returns {void}
     */
    handleApplyFilters(event) {
        event.stopPropagation();

        if (this.isMobileView) {
            this.closeMobileFilters();
        } else {
            this.closeMoreFilters();
        }
    }

    /**
     * @description Prevents event bubbling to parent handlers.
     * Used to avoid unintended dropdown or modal closures.
     * @param {Event} event - UI event to stop propagation.
     * @returns {void}
     */
    stopPropagation(event) {
        event.stopPropagation();
    }

    // ==========================================
    // ==========================================

    /**
     * GROUPED APPROACH: Creates ONE badge per filter category
     */
    get selectedFilterBadges() {
        let badges = [];
        if (this.filterOptions) {
            this.filterOptions.forEach(filter => {
                if (filter.selectedValues && filter.selectedValues.length > 0) {
                    // Combine all selections into a comma-separated string
                    const combinedValues = filter.selectedValues.join(', ');

                    badges.push({
                        uniqueId: `badge-${filter.order}`, // Only one badge per category
                        order: filter.order,
                        category: filter.placeholder,
                        value: combinedValues
                    });
                }
            });
        }
        return badges;
    }

    /**
     * Removes ALL selected values for that specific filter category when clicked
     */
    handleRemoveBadge(event) {
        event.stopPropagation();
        const order = event.currentTarget.dataset.order;

        this.filterOptions = this.filterOptions.map(f => {
            if (String(f.order) !== String(order)) return f;

            // Uncheck ALL options for this specific filter
            const updatedValues = f.values.map(v => ({
                ...v,
                checked: false
            }));

            return {
                ...f,
                values: updatedValues,
                selectedValues: [], // Empty the selections
                hoverText: f.placeholder,
                displayValue: f.placeholder
            };
        });

        // Keep mobile state in sync and dispatch updates
        this.updateMobileFilterValues();
        this.areFiltersChanged = true;
        this.dispatchFilterUpdate();
    }

}