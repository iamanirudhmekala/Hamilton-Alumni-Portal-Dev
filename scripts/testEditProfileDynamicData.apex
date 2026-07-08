/**
 * TEST SCRIPT: Edit Profile Dynamic Data Retrieval
 * Execute in Developer Console > Execute Anonymous Window
 *
 * This script tests the new getEditProfileDynamicData() method
 */

// ============================================================
// CONFIGURATION - REPLACE WITH YOUR CONTACT ID
// ============================================================
String contactId = '003VG00000c20MPYAY'; // <-- PUT YOUR CONTACT ID HERE

System.debug('============================================================');
System.debug('TESTING EDIT PROFILE DYNAMIC DATA');
System.debug('Contact ID: ' + contactId);
System.debug('============================================================\n');

// ============================================================
// TEST 1: Call the new dynamic method
// ============================================================
System.debug('--- TEST 1: Calling getEditProfileDynamicData() ---');

HAM_EditProfileController.EditProfileDataWrapper result;
try {
    result = HAM_EditProfileController.getEditProfileDynamicData(contactId);

    if (result.error != null) {
        System.debug('ERROR: ' + result.error);
    } else {
        System.debug('SUCCESS: Data retrieved successfully');
        System.debug('Number of sections: ' + result.sections.size());
    }
} catch (Exception e) {
    System.debug('EXCEPTION: ' + e.getMessage() + ' at line ' + e.getLineNumber());
}

System.debug('\n');

// ============================================================
// TEST 2: Display sections and fields
// ============================================================
if (result != null && result.sections != null) {
    System.debug('--- TEST 2: Displaying All Sections and Fields ---\n');

    for (HAM_EditProfileController.EditProfileSection section : result.sections) {
        System.debug('========================================');
        System.debug('SECTION: ' + section.sectionName);
        System.debug('Section Order: ' + section.sectionOrder);
        System.debug('Number of Fields: ' + section.fields.size());
        System.debug('========================================');

        for (HAM_EditProfileController.EditProfileField field : section.fields) {
            System.debug('');
            System.debug('  Field Label: ' + field.label);
            System.debug('  Display Type: ' + field.displayType);
            System.debug('  Order: ' + field.order);

            if (field.displayType == 'List' && field.displayValueList != null) {
                System.debug('  Values (List): ');
                for (String val : field.displayValueList) {
                    System.debug('    - ' + val);
                }
                System.debug('  Total Items: ' + field.displayValueList.size());
            } else {
                System.debug('  Value: ' + field.displayValue);
            }
        }
        System.debug('\n');
    }
}

// ============================================================
// TEST 3: Display as JSON for LWC preview
// ============================================================
System.debug('\n--- TEST 3: JSON Output (LWC will receive this) ---');
if (result != null) {
    System.debug(JSON.serializePretty(result));
}

// ============================================================
// TEST 4: Verify each section exists
// ============================================================
System.debug('\n--- TEST 4: Section Verification ---');
if (result != null && result.sections != null) {
    Set<String> expectedSections = new Set<String>{
        'Personal Information',
        'Social Media',
        'Address Details',
        'Campus Life'
    };

    Set<String> actualSections = new Set<String>();
    for (HAM_EditProfileController.EditProfileSection section : result.sections) {
        actualSections.add(section.sectionName);
    }

    System.debug('Expected Sections: ' + expectedSections);
    System.debug('Actual Sections: ' + actualSections);

    for (String expected : expectedSections) {
        if (actualSections.contains(expected)) {
            System.debug('✓ ' + expected + ' - FOUND');
        } else {
            System.debug('✗ ' + expected + ' - MISSING');
        }
    }
}

// ============================================================
// TEST 5: Count field types
// ============================================================
System.debug('\n--- TEST 5: Field Type Distribution ---');
if (result != null && result.sections != null) {
    Map<String, Integer> typeCount = new Map<String, Integer>();

    for (HAM_EditProfileController.EditProfileSection section : result.sections) {
        for (HAM_EditProfileController.EditProfileField field : section.fields) {
            String type = field.displayType;
            if (!typeCount.containsKey(type)) {
                typeCount.put(type, 0);
            }
            typeCount.put(type, typeCount.get(type) + 1);
        }
    }

    System.debug('Field Type Counts:');
    for (String type : typeCount.keySet()) {
        System.debug('  ' + type + ': ' + typeCount.get(type));
    }
}

// ============================================================
// TEST 6: Verify specific field values
// ============================================================
System.debug('\n--- TEST 6: Spot Check Field Values ---');
if (result != null && result.sections != null) {
    // Find Personal Information section
    for (HAM_EditProfileController.EditProfileSection section : result.sections) {
        if (section.sectionName == 'Personal Information') {
            System.debug('Personal Information Fields:');
            for (HAM_EditProfileController.EditProfileField field : section.fields) {
                if (field.label == 'Phone Number' || field.label == 'Job Title' || field.label == 'Employer') {
                    System.debug('  ' + field.label + ': ' + field.displayValue);
                }
            }
        }

        if (section.sectionName == 'Campus Life') {
            System.debug('\nCampus Life Fields:');
            for (HAM_EditProfileController.EditProfileField field : section.fields) {
                System.debug('  ' + field.label + ':');
                if (field.displayValueList != null && !field.displayValueList.isEmpty()) {
                    System.debug('    Values: ' + String.join(field.displayValueList, ', '));
                } else {
                    System.debug('    Value: ' + field.displayValue);
                }
            }
        }
    }
}

System.debug('\n============================================================');
System.debug('TEST COMPLETE');
System.debug('============================================================');
