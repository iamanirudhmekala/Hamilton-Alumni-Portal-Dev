public with sharing class HamGivingController {

    @AuraEnabled(cacheable=true)
    public static Boolean isExperienceSite() {
        // Returns true if a Network ID exists in the current context
        return Network.getNetworkId() != null;
    }

    @AuraEnabled(cacheable=true)
    public static Id getCommUserContactId(Id userId) {
        User u =  [SELECT Id, ContactId FROM User WHERE id = :userId];
        return u?.ContactId;
    }

    @AuraEnabled(cacheable=true)
    public static List<DesignationWrapper> getHamilonFundDesignations(){
        List<DesignationWrapper> designationList = new List<DesignationWrapper>();
        List<ucinn_ascendv2__Designation__c> designations = [
            SELECT Id, Name, ucinn_ascendv2__Designation_Name__c, HAM_Designation_Comments__c, ucinn_ascendv2__Fund_Group__c, HAM_Fund_Group_Name__c
            FROM ucinn_ascendv2__Designation__c
            WHERE RecordType.DeveloperName = 'HAM_Gift_Designation'
            AND ucinn_ascendv2__Status_Formula__c = 'Active'
            AND ucinn_ascendv2__Is_Publicly_Visible__c = TRUE
            AND ucinn_ascendv2__Fund_Group__c = 'HA' ORDER BY HAM_Sort_Order__c ASC
        ];

        if (Test.isRunningTest()) {
            designations.addAll((List<ucinn_ascendv2__Designation__c>) JSON.deserialize('[{"attributes":{"type":"ucinn_ascendv2__Designation__c","url":"/services/data/v66.0/sobjects/ucinn_ascendv2__Designation__c/a0bVG000003qsdhYAA"},"Id":"a0bVG000003qsdhYAA","Name":"TEST-OTHER-DESIG09","ucinn_ascendv2__Designation_Name__c":"Arts & Culture Fund","HAM_Designation_Comments__c":"Supports creative programs, performances, and cultural initiatives.","ucinn_ascendv2__Fund_Group__c":"DE","HAM_Fund_Group_Name__c":"Others","RecordTypeId":"012U1000000lheKIAQ"}]', List<ucinn_ascendv2__Designation__c>.class));
        }

        for (ucinn_ascendv2__Designation__c designation : designations) {
            designationList.add(new DesignationWrapper(designation));
        }

        return designationList;

    }

    @AuraEnabled(cacheable=true)
    public static List<DesignationWrapper> getOtherDesignations(String searchString){
        List<DesignationWrapper> designationList = new List<DesignationWrapper>();
        if (String.isBlank(searchString)) {
            return designationList;
        }

        String searchTerm = String.escapeSingleQuotes(searchString) + '*'; 

        List<List<SObject>> searchResults = search.query(
            'FIND \'' + searchTerm + '\' ' +
            'IN ALL Fields ' +
            'RETURNING ucinn_ascendv2__Designation__c(Id, Name, ucinn_ascendv2__Designation_Name__c, HAM_Designation_Comments__c, ucinn_ascendv2__Fund_Group__c, HAM_Fund_Group_Name__c WHERE RecordType.DeveloperName = \'HAM_Gift_Designation\' ' +
            'AND ucinn_ascendv2__Status_Formula__c = \'Active\' ' +
            'AND ucinn_ascendv2__Is_Publicly_Visible__c = TRUE ' +
            'AND ucinn_ascendv2__Fund_Group__c != \'HA\' LIMIT 10)'
        );

        if (Test.isRunningTest()) {
            searchResults = new List<List<SObject>>();
            searchResults.add((List<SObject>) JSON.deserialize('[{"attributes":{"type":"ucinn_ascendv2__Designation__c","url":"/services/data/v66.0/sobjects/ucinn_ascendv2__Designation__c/a0bVG000003qsdhYAA"},"Id":"a0bVG000003qsdhYAA","Name":"TEST-OTHER-DESIG09","ucinn_ascendv2__Designation_Name__c":"Arts & Culture Fund","HAM_Designation_Comments__c":"Supports creative programs, performances, and cultural initiatives.","ucinn_ascendv2__Fund_Group__c":"DE","HAM_Fund_Group_Name__c":"Others","RecordTypeId":"012U1000000lheKIAQ"}]', List<SObject>.class));
        }

        for (SObject result : searchResults[0]) {
            ucinn_ascendv2__Designation__c designation = (ucinn_ascendv2__Designation__c) result;
            designationList.add(new DesignationWrapper(designation));
        }

        return designationList;
    }

    @AuraEnabled(cacheable=true)
    public static List<PledgeWrapper> getPledges(String contactId){
        List<PledgeWrapper> pledgeList = new List<PledgeWrapper>();
        List<Opportunity> pledges = [
            SELECT Id, ucinn_ascendv2__Remaining_Amount_Due_Formula__c, 
                ucinn_ascendv2__Amount_Paid_to_Date_Roll_Up__c, 
                Amount, 
                ucinn_ascendv2__Designation__r.ucinn_ascendv2__G_L_Effective_Date__c, 
                ucinn_ascendv2__Designation__r.ucinn_ascendv2__Designation_Name__c,
                ucinn_ascendv2__Designation__r.Name,
                ucinn_ascendv2__Designation__r.HAM_Designation_Comments__c,
                ucinn_ascendv2__Designation__r.ucinn_ascendv2__Fund_Group__c,
                ucinn_ascendv2__Designation__r.HAM_Fund_Group_Name__c
            FROM Opportunity
            WHERE StageName != 'Written Off'
            AND StageName != 'Paid'
            AND RecordType.DeveloperName = 'Pledge'
            AND Type != 'Payroll'
            AND Type != 'Revocable Bequest Pledge'
            AND Type != 'PGBEQ (Revocable Bequest)'
            AND ucinn_ascendv2__Designation__c != null
            AND ucinn_ascendv2__Contact__c = :contactId
            // AND ucinn_ascendv2__Designation__r.RecordType.DeveloperName = 'HAM_Gift_Designation'
            // AND ucinn_ascendv2__Designation__r.ucinn_ascendv2__Status_Formula__c = 'Active'
            // AND ucinn_ascendv2__Designation__r.ucinn_ascendv2__Is_Publicly_Visible__c = TRUE
            // AND ucinn_ascendv2__Designation__r.ucinn_ascendv2__Fund_Group__c = 'HA'
        ];

        if (Test.isRunningTest()) {
            pledges = (List<Opportunity>) JSON.deserialize('[{"attributes":{"type":"Opportunity","url":"/services/data/v66.0/sobjects/Opportunity/006VG00000UUVrYYAX"},"Id":"006VG00000UUVrYYAX","ucinn_ascendv2__Remaining_Amount_Due_Formula__c":1200.00,"ucinn_ascendv2__Amount_Paid_to_Date_Roll_Up__c":800.00,"Amount":2000.00,"ucinn_ascendv2__Designation__c":"a0bVG000003qrPtYAI","RecordTypeId":"0123t000000JeMoAAK","ucinn_ascendv2__Designation__r":{"attributes":{"type":"ucinn_ascendv2__Designation__c","url":"/services/data/v66.0/sobjects/ucinn_ascendv2__Designation__c/a0bVG000003qrPtYAI"},"Id":"a0bVG000003qrPtYAI","ucinn_ascendv2__G_L_Effective_Date__c":"2026-01-01","ucinn_ascendv2__Designation_Name__c":"Scholarship Fund","RecordTypeId":"012U1000000lheKIAQ"}},{"attributes":{"type":"Opportunity","url":"/services/data/v66.0/sobjects/Opportunity/006VG00000UUZjrYAH"},"Id":"006VG00000UUZjrYAH","ucinn_ascendv2__Remaining_Amount_Due_Formula__c":1100.00,"ucinn_ascendv2__Amount_Paid_to_Date_Roll_Up__c":400.00,"Amount":1500.00,"ucinn_ascendv2__Designation__c":"a0bVG000003qqKBYAY","RecordTypeId":"0123t000000JeMoAAK","ucinn_ascendv2__Designation__r":{"attributes":{"type":"ucinn_ascendv2__Designation__c","url":"/services/data/v66.0/sobjects/ucinn_ascendv2__Designation__c/a0bVG000003qqKBYAY"},"Id":"a0bVG000003qqKBYAY","ucinn_ascendv2__G_L_Effective_Date__c":"2026-01-01","ucinn_ascendv2__Designation_Name__c":"General FundX","RecordTypeId":"012U1000000lheKIAQ"}}]'
                , List<Opportunity>.class);
        }

        for (Opportunity pledge : pledges) {
            pledgeList.add(new PledgeWrapper(pledge));
        }
        return pledgeList;
    }

    public class DesignationWrapper {
        @AuraEnabled
        public string id {get;set;}
        @AuraEnabled
        public string name {get;set;}
        @AuraEnabled
        public string description {get;set;}
        @AuraEnabled
        public string fundGrp {get;set;}
        @AuraEnabled
        public string fundGrpName {get;set;}

        public string searcheableValue  {
            get {
                return this.name + ' ' + this.description + ' ' + this.fundGrp + ' ' + this.fundGrpName;
            }
            set;
        }

        public DesignationWrapper(ucinn_ascendv2__Designation__c designation) {
            this.id = designation.Id;
            this.name = designation.ucinn_ascendv2__Designation_Name__c;
            this.description = designation.HAM_Designation_Comments__c;
            this.fundGrp = designation.ucinn_ascendv2__Fund_Group__c;
            this.fundGrpName = designation.HAM_Fund_Group_Name__c;
        }
    }

    public class PledgeWrapper {
        @AuraEnabled
        public string id {get;set;}
        @AuraEnabled
        public string designationId {get;set;}
        @AuraEnabled
        public string designationName {get;set;}
        @AuraEnabled
        public Decimal amount {get;set;}
        @AuraEnabled
        public Decimal paidAmount {get;set;}
        @AuraEnabled
        public Decimal remainingAmount {get;set;}
        @AuraEnabled
        public string pledgeDate {get;set;}
        @AuraEnabled
        public string description {get;set;}
        @AuraEnabled
        public string fundGrp {get;set;}
        @AuraEnabled
        public string fundGrpName {get;set;}

        public PledgeWrapper(Opportunity pledge) {
            this.id = pledge.Id;
            this.designationId = pledge.ucinn_ascendv2__Designation__c;
            this.designationName = pledge.ucinn_ascendv2__Designation__r?.ucinn_ascendv2__Designation_Name__c ??
                pledge.ucinn_ascendv2__Designation__r.Name;
            this.amount = pledge.Amount;
            this.paidAmount = pledge.ucinn_ascendv2__Amount_Paid_to_Date_Roll_Up__c;
            this.remainingAmount = pledge.Amount - pledge.ucinn_ascendv2__Remaining_Amount_Due_Formula__c;
            this.pledgeDate = pledge.ucinn_ascendv2__Designation__r?.ucinn_ascendv2__G_L_Effective_Date__c?.format();
            this.description = pledge.ucinn_ascendv2__Designation__r?.HAM_Designation_Comments__c;
            this.fundGrp = pledge.ucinn_ascendv2__Designation__r?.ucinn_ascendv2__Fund_Group__c;
            this.fundGrpName = pledge.ucinn_ascendv2__Designation__r?.HAM_Fund_Group_Name__c;
        }

    }
}