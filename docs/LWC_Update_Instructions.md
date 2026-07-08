# LWC Update Instructions for ham_editProfileCmp

## Overview
The new dynamic method `getEditProfileDynamicData()` returns structured data grouped by sections. The LWC needs to be updated to render this data dynamically instead of using hardcoded fields.

---

## Data Structure Returned

```javascript
{
  sections: [
    {
      sectionName: "Personal Information",
      sectionOrder: 1,
      fields: [
        {
          label: "Phone Number",
          displayType: "Contact Field",
          order: 3,
          fieldApiName: "HAM_Formatted_Phone__c",
          displayValue: "+1 234 567 8900",
          displayValueList: null
        },
        {
          label: "Job Title",
          displayType: "Contact Field",
          order: 5,
          fieldApiName: "Job_Title__c",
          displayValue: "Lead AI Architect",
          displayValueList: null
        },
        // ... more fields
      ]
    },
    {
      sectionName: "Campus Life",
      sectionOrder: 4,
      fields: [
        {
          label: "Residence Halls",
          displayType: "List",
          order: 1,
          fieldApiName: "ucinn_ascendv2__Involvement_Code_Description_Formula__c",
          displayValue: null,
          displayValueList: ["Light A", "Light B", "Light C", "Light D"]
        },
        // ... more fields
      ]
    }
  ],
  error: null
}
```

---

## Required Changes in JavaScript (ham_editProfileCmp.js)

### 1. Import the New Method

```javascript
import getEditProfileDynamicData from '@salesforce/apex/HAM_EditProfileController.getEditProfileDynamicData';
```

### 2. Add New Properties

```javascript
export default class Ham_editProfileCmp extends LightningElement {
    // ... existing properties ...

    // NEW PROPERTIES
    @track dynamicSections = [];
    hasError = false;
    errorMessage = '';

    // ... rest of existing code ...
}
```

### 3. Add Wire for Dynamic Data

```javascript
// Wire for new dynamic data
@wire(getEditProfileDynamicData, { currentUserContactId: '$userContactId' })
wiredDynamicData({ data, error }) {
    if (data) {
        if (data.error) {
            this.hasError = true;
            this.errorMessage = data.error;
        } else {
            this.dynamicSections = data.sections;
            this.hasError = false;
        }
        this.isLoading = false;
    } else if (error) {
        console.error('Error fetching dynamic data:', error);
        this.hasError = true;
        this.errorMessage = 'Failed to load profile data';
        this.isLoading = false;
    }
}
```

### 4. Add Getters for Specific Sections

```javascript
// Get specific sections for rendering
get personalInformationFields() {
    return this.getFieldsForSection('Personal Information');
}

get socialMediaFields() {
    return this.getFieldsForSection('Social Media');
}

get addressDetailsFields() {
    return this.getFieldsForSection('Address Details');
}

get campusLifeFields() {
    return this.getFieldsForSection('Campus Life');
}

// Helper method to get fields by section name
getFieldsForSection(sectionName) {
    if (!this.dynamicSections) return [];
    const section = this.dynamicSections.find(s => s.sectionName === sectionName);
    return section ? section.fields : [];
}

// Check if a field is a list type
isListField(field) {
    return field.displayType === 'List' && field.displayValueList && field.displayValueList.length > 0;
}

// Check if a field has a value
hasValue(field) {
    if (field.displayType === 'List') {
        return field.displayValueList && field.displayValueList.length > 0;
    }
    return field.displayValue != null && field.displayValue !== '';
}
```

---

## Required Changes in HTML (ham_editProfileCmp.html)

### Current Hardcoded Structure
```html
<lightning-input
    label="Phone Number"
    value={personalInfo.phoneNo}
    data-name="phoneNo"
    onchange={handleChange}>
</lightning-input>
```

### New Dynamic Structure

Replace hardcoded sections with dynamic iteration:

```html
<!-- Personal Information Section -->
<div class="section-container">
    <h3 class="section-title">Personal Information</h3>

    <template for:each={personalInformationFields} for:item="field">
        <div key={field.label} class="field-container">

            <!-- For Contact Field, Address, Lookup types -->
            <template if:false={isListField}>
                <lightning-input
                    label={field.label}
                    value={field.displayValue}
                    data-fieldapi={field.fieldApiName}
                    data-section="Personal Information"
                    onchange={handleDynamicFieldChange}>
                </lightning-input>
            </template>

            <!-- For List type (multiple values) -->
            <template if:true={isListField}>
                <div class="list-field">
                    <label class="field-label">{field.label}</label>
                    <div class="value-list">
                        <template for:each={field.displayValueList} for:item="value">
                            <span key={value} class="value-pill">{value}</span>
                        </template>
                    </div>
                </div>
            </template>

        </div>
    </template>
</div>

<!-- Campus Life Section -->
<div class="section-container">
    <h3 class="section-title">Campus Life</h3>

    <template for:each={campusLifeFields} for:item="field">
        <div key={field.label} class="field-container">

            <!-- List display (read-only for now) -->
            <template if:true={isListField}>
                <div class="list-field">
                    <label class="field-label">{field.label}</label>
                    <div class="value-list">
                        <template for:each={field.displayValueList} for:item="value">
                            <span key={value} class="value-pill">{value}</span>
                        </template>
                    </div>
                </div>
            </template>

            <!-- Single value display -->
            <template if:false={isListField}>
                <lightning-input
                    label={field.label}
                    value={field.displayValue}
                    data-fieldapi={field.fieldApiName}
                    readonly>
                </lightning-input>
            </template>

        </div>
    </template>
</div>
```

### Fully Generic Rendering (All Sections)

For a completely dynamic approach:

```html
<template if:false={hasError}>
    <template for:each={dynamicSections} for:item="section">
        <div key={section.sectionName} class="section-container">
            <h3 class="section-title">{section.sectionName}</h3>

            <template for:each={section.fields} for:item="field">
                <div key={field.label} class="field-container">

                    <!-- List type -->
                    <template if:true={isListField}>
                        <div class="list-field">
                            <label class="field-label">{field.label}</label>
                            <div class="value-list">
                                <template for:each={field.displayValueList} for:item="value">
                                    <span key={value} class="value-pill">{value}</span>
                                </template>
                            </div>
                        </div>
                    </template>

                    <!-- Single value type -->
                    <template if:false={isListField}>
                        <lightning-input
                            label={field.label}
                            value={field.displayValue}
                            data-fieldapi={field.fieldApiName}
                            data-section={section.sectionName}
                            onchange={handleDynamicFieldChange}>
                        </lightning-input>
                    </template>

                </div>
            </template>
        </div>
    </template>
</template>

<template if:true={hasError}>
    <div class="error-message">
        {errorMessage}
    </div>
</template>
```

---

## CSS Updates (ham_editProfileCmp.css)

```css
.section-container {
    margin-bottom: 2rem;
    padding: 1rem;
    border: 1px solid #e0e0e0;
    border-radius: 8px;
}

.section-title {
    font-size: 1.25rem;
    font-weight: 600;
    margin-bottom: 1rem;
    color: #001f5b;
}

.field-container {
    margin-bottom: 1rem;
}

.list-field {
    margin-bottom: 1rem;
}

.field-label {
    display: block;
    font-size: 0.875rem;
    font-weight: 500;
    margin-bottom: 0.5rem;
    color: #3e3e3c;
}

.value-list {
    display: flex;
    flex-wrap: wrap;
    gap: 0.5rem;
}

.value-pill {
    display: inline-block;
    padding: 0.25rem 0.75rem;
    background-color: #f3f3f3;
    border: 1px solid #c9c9c9;
    border-radius: 16px;
    font-size: 0.875rem;
    color: #3e3e3c;
}

.error-message {
    color: #c23934;
    padding: 1rem;
    background-color: #fef7f7;
    border: 1px solid #fecdca;
    border-radius: 4px;
}
```

---

## Updated handleChange for Dynamic Fields

```javascript
handleDynamicFieldChange(event) {
    const fieldApi = event.target.dataset.fieldapi;
    const section = event.target.dataset.section;
    const newValue = event.target.value;

    // Update the dynamic sections data
    this.dynamicSections = this.dynamicSections.map(sec => {
        if (sec.sectionName === section) {
            return {
                ...sec,
                fields: sec.fields.map(field => {
                    if (field.fieldApiName === fieldApi) {
                        return { ...field, displayValue: newValue };
                    }
                    return field;
                })
            };
        }
        return sec;
    });

    // Also update the personalUpdatedInfo for save operation
    // (Keep existing logic for backward compatibility)
    this.personalUpdatedInfo = {
        ...this.personalUpdatedInfo,
        [fieldApi]: newValue
    };
}
```

---

## Migration Strategy

### Option 1: Gradual Migration (Recommended)
1. Keep existing wire `getMyPersonalInformation` for profile header (name, picture, class year)
2. Add new wire `getEditProfileDynamicData` for all sections below header
3. Render header using existing code
4. Render sections using new dynamic code

### Option 2: Complete Replacement
1. Replace all hardcoded fields with dynamic rendering
2. Remove old wire service
3. Update all handlers to work with dynamic data

---

## Testing Checklist

- [ ] Profile header displays correctly (name, picture, class year)
- [ ] Personal Information section renders with all fields
- [ ] Social Media section shows Facebook, Instagram, LinkedIn
- [ ] Address Details section displays address fields
- [ ] Campus Life section shows lists (Residence Halls, Athletics, etc.)
- [ ] Field values populate correctly
- [ ] Empty fields show gracefully
- [ ] List fields display as pills/tags
- [ ] Edit functionality works (if applicable)
- [ ] Save operation works with new structure
- [ ] Error handling works when metadata is missing
- [ ] Loading spinner shows during data fetch

---

## Next Steps

1. Run the test script in `scripts/testEditProfileDynamicData.apex`
2. Verify data structure in debug logs
3. Update LWC JavaScript with new wire and getters
4. Update LWC HTML with dynamic rendering
5. Add CSS for styling
6. Test in browser
7. Iterate based on results
