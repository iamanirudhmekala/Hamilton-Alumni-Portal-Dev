/**
 * Script to check available fields on Address object
 * Run this in Execute Anonymous Window
 */

System.debug('=== CHECKING ucinn_ascendv2__Address__c FIELDS ===\n');

// Get all fields on Address object
Map<String, Schema.SObjectField> fieldMap = Schema.SObjectType.ucinn_ascendv2__Address__c.fields.getMap();

System.debug('Total fields: ' + fieldMap.size());
System.debug('\nAddress-related fields:\n');

List<String> addressFields = new List<String>();
for (String fieldName : fieldMap.keySet()) {
    String lowerFieldName = fieldName.toLowerCase();
    if (lowerFieldName.contains('address') ||
        lowerFieldName.contains('street') ||
        lowerFieldName.contains('city') ||
        lowerFieldName.contains('state') ||
        lowerFieldName.contains('country') ||
        lowerFieldName.contains('postal')) {

        Schema.DescribeFieldResult fieldDescribe = fieldMap.get(fieldName).getDescribe();
        addressFields.add(fieldDescribe.getName() + ' (' + fieldDescribe.getLabel() + ') - ' + fieldDescribe.getType());
    }
}

addressFields.sort();
for (String field : addressFields) {
    System.debug('  ' + field);
}

System.debug('\n=== RECOMMENDED FIELD API NAMES ===\n');
System.debug('Based on the fields found, update your metadata with these API names:');
System.debug('  Street: ucinn_ascendv2__Address_Line_1__c');
System.debug('  City: ucinn_ascendv2__City__c');
System.debug('  State: ucinn_ascendv2__State__c');
System.debug('  Country: ucinn_ascendv2__Country__c');
System.debug('  Postal Code: ucinn_ascendv2__Postal_Code__c');
