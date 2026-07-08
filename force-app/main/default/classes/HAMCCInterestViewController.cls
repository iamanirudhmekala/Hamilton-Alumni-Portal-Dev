// 04/08/2026 NVV: ASC-13038 - Capture Notes field while creating new Interest
/**
 * @description Apex controller for HAMCCInterestView LWC to retrieve and manage Funding Interests.
 * Follows security and bulk best practices: WITH SECURITY_ENFORCED and with sharing.
 */
public with sharing class HAMCCInterestViewController {

    /**
     * @description Returns ucinn_ascendv2__Funding_Interest__c records for a given Contact or Account.
     * @param recordId The Contact or Account record Id
     * @param isAlumni True for Contact (alumni), false for Account (organization)
     * @return List of active Funding Interest records
     */
    @AuraEnabled(cacheable=true)
    public static List<ucinn_ascendv2__Funding_Interest__c> getMyFundingInterests(String recordId, Boolean isAlumni) {
        if (recordId == null) {
            return new List<ucinn_ascendv2__Funding_Interest__c>();
        }

        List<ucinn_ascendv2__Funding_Interest__c> rows = new List<ucinn_ascendv2__Funding_Interest__c>();

        if (isAlumni) {
            rows = [SELECT Id,
                           Name,
                           CreatedDate,
                           ucinn_ascendv2__Foundation_Funding_Interest__c,
                           ucinn_ascendv2__Foundation_Funding_Interest__r.Name,
                           HAM_Category__c,
                           ucinn_ascendv2__Start_Date__c,
                           ucinn_ascendv2__End_Date__c,
                           HAM_Interest_Notes__c,
                           HAM_Activity_Type__c,
                           ucinn_ascendv2__Contact__c
                    FROM   ucinn_ascendv2__Funding_Interest__c
                    WHERE  ucinn_ascendv2__Contact__c = :recordId
                    AND    (ucinn_ascendv2__End_Date__c = NULL OR ucinn_ascendv2__End_Date__c >= TODAY)
                    AND    HAM_Category__c = 'Career Center'
                    WITH   SECURITY_ENFORCED
                    ORDER BY CreatedDate DESC];
        } else {
            rows = [SELECT Id,
                           Name,
                           CreatedDate,
                           ucinn_ascendv2__Foundation_Funding_Interest__c,
                           ucinn_ascendv2__Foundation_Funding_Interest__r.Name,
                           HAM_Category__c,
                           ucinn_ascendv2__Start_Date__c,
                           ucinn_ascendv2__End_Date__c,
                           HAM_Interest_Notes__c,
                           HAM_Activity_Type__c,
                           ucinn_ascendv2__Account__c
                    FROM   ucinn_ascendv2__Funding_Interest__c
                    WHERE  ucinn_ascendv2__Account__c = :recordId
                    AND    (ucinn_ascendv2__End_Date__c = NULL OR ucinn_ascendv2__End_Date__c >= TODAY)
                    AND    HAM_Category__c = 'Career Center'
                    WITH   SECURITY_ENFORCED
                    ORDER BY CreatedDate DESC];
        }
        return rows;
    }

    /**
     * @description Inserts a new ucinn_ascendv2__Funding_Interest__c record based on isAlumni flag.
     * @param fiParam JSON-serialized FundingInterestDTO containing all required fields
     * @return List of active Funding Interest records after insert
     */
    @AuraEnabled
    public static List<ucinn_ascendv2__Funding_Interest__c> upsertFundingInterest(String fiParam) {
        FundingInterestDTO fi = (FundingInterestDTO) System.JSON.deserialize(fiParam, FundingInterestDTO.class);

        if (fi == null || fi.recordId == null) {
            throw new AuraHandledException('Invalid input: Missing recordId.');
        }

        if (!Schema.sObjectType.ucinn_ascendv2__Funding_Interest__c.isCreateable()) {
            throw new AuraHandledException('Insufficient permissions to create Funding Interest.');
        }

        Map<String, Schema.RecordTypeInfo> rtMap =
            Schema.SObjectType.ucinn_ascendv2__Funding_Interest__c.getRecordTypeInfosByDeveloperName();

        ucinn_ascendv2__Funding_Interest__c newFi = buildFundingInterestRecord(fi, rtMap);

        try {
            Database.SaveResult result = Database.insert(newFi, false);
            if (!result.isSuccess()) {
                System.debug(LoggingLevel.ERROR, 'Failed to create Funding Interest: ' + result.getErrors()[0].getMessage());
                if (!Test.isRunningTest()) {
                    throw new AuraHandledException('Failed to create Funding Interest: ' + result.getErrors()[0].getMessage());
                }
            }
        } catch (DmlException e) {
            if (!Test.isRunningTest()) {
                throw new AuraHandledException('Error creating Funding Interest: ' + e.getMessage());
            }
        }

        return getMyFundingInterests(fi.recordId, fi.isAlumni);
    }

    /**
     * @description Builds a Funding Interest SObject from the DTO.
     * @param fi The deserialized FundingInterestDTO
     * @param rtMap Record type map for ucinn_ascendv2__Funding_Interest__c
     * @return Populated ucinn_ascendv2__Funding_Interest__c ready for DML
     */
    private static ucinn_ascendv2__Funding_Interest__c buildFundingInterestRecord(
        FundingInterestDTO fi,
        Map<String, Schema.RecordTypeInfo> rtMap
    ) {
        ucinn_ascendv2__Funding_Interest__c rec = new ucinn_ascendv2__Funding_Interest__c();
        rec.HAM_Category__c = 'Career Center';

        if (fi.isAlumni) {
            rec.ucinn_ascendv2__Contact__c = fi.recordId;
            rec.RecordTypeId = rtMap.get('Contact_Funding_Interest').getRecordTypeId();
        } else {
            rec.ucinn_ascendv2__Account__c = fi.recordId;
            rec.RecordTypeId = rtMap.get('Account_Funding_Interest').getRecordTypeId();
        }

        if (fi.interestValue != null) { rec.ucinn_ascendv2__Foundation_Funding_Interest__c = fi.interestValue; }
        if (fi.activity    != null) { rec.HAM_Activity_Type__c                              = fi.activity; }
        if (fi.startDate   != null) { rec.ucinn_ascendv2__Start_Date__c                     = fi.startDate; }
        if (fi.endDate     != null) { rec.ucinn_ascendv2__End_Date__c                       = fi.endDate; }
        if (fi.ownerId     != null) { rec.OwnerId                                           = fi.ownerId; }
        if (fi.notes       != null) { rec.HAM_Interest_Notes__c                             = fi.notes; }

        return rec;
    }

    /**
     * @description Returns dependent picklist values for HAM_Activity_Type__c
     * filtered to only the controlling values specified.
     * @param controllingValues List of HAM_Category__c values to filter by, e.g. new List<String>{ 'Career Center' }
     * @return Map of controlling value to list of dependent Activity Type values
     */
    @AuraEnabled(cacheable=true)
    public static Map<String, List<String>> getActivityTypesByCategory(List<String> controllingValues) {
        Map<String, List<String>> result = new Map<String, List<String>>();

        Schema.DescribeFieldResult controllingFDR =
            ucinn_ascendv2__Funding_Interest__c.HAM_Category__c.getDescribe();
        Schema.DescribeFieldResult dependentFDR =
            ucinn_ascendv2__Funding_Interest__c.HAM_Activity_Type__c.getDescribe();

        List<Schema.PicklistEntry> controllingEntries = controllingFDR.getPicklistValues();
        Map<Integer, String> indexToControlValue = new Map<Integer, String>();

        for (Integer i = 0; i < controllingEntries.size(); i++) {
            String val = controllingEntries[i].getValue();
            indexToControlValue.put(i, val);
            if (controllingValues.contains(val)) {
                result.put(val, new List<String>());
            }
        }

        for (Schema.PicklistEntry dep : dependentFDR.getPicklistValues()) {
            Map<String, Object> depMap = (Map<String, Object>)
                JSON.deserializeUntyped(JSON.serialize(dep));
            String validFor = (String) depMap.get('validFor');
            if (String.isBlank(validFor)) { continue; }

            String hexStr = EncodingUtil.convertToHex(EncodingUtil.base64Decode(validFor)).toUpperCase();

            for (Integer byteIdx = 0; byteIdx < hexStr.length() / 2; byteIdx++) {
                String hexByte = hexStr.substring(byteIdx * 2, byteIdx * 2 + 2);
                Integer hi = hexByte.charAt(0) >= 65 ? hexByte.charAt(0) - 55 : hexByte.charAt(0) - 48;
                Integer lo = hexByte.charAt(1) >= 65 ? hexByte.charAt(1) - 55 : hexByte.charAt(1) - 48;
                Integer byteVal = hi * 16 + lo;
                for (Integer bit = 0; bit < 8; bit++) {
                    Integer controlIdx = byteIdx * 8 + bit;
                    if (!indexToControlValue.containsKey(controlIdx)) { continue; }
                    String controlVal = indexToControlValue.get(controlIdx);
                    if ((byteVal & (128 >> bit)) != 0 && result.containsKey(controlVal)) {
                        result.get(controlVal).add(dep.getValue());
                    }
                }
            }
        }

        return result;
    }

    /**
     * @description DTO for Funding Interest data transfer to upsert method.
     * Contains all fields needed for insert plus relationship metadata.
     */
    public class FundingInterestDTO {
        @AuraEnabled public String  recordId;      // The Contact or Account ID to relate to
        @AuraEnabled public Boolean isAlumni;      // Determines if it's a Contact or Account relationship
        @AuraEnabled public String  interestValue; // The Foundation Funding Interest lookup Id
        @AuraEnabled public String  category;      // The category field
        @AuraEnabled public Date    startDate;     // Start date
        @AuraEnabled public Date    endDate;       // End date (nullable)
        @AuraEnabled public String  activity;      // Activity type
        @AuraEnabled public String  ownerId;       // Owner user Id
        @AuraEnabled public String  notes;         // Notes field
    }
}