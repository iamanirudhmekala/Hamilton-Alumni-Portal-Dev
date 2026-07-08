public with sharing class HamReviewTransactionController {

    @AuraEnabled
    public static Map<String, Object> initFormData(String giftFrequency) {
        Map<String, Object> result = new Map<String, Object>();
        try {
            ContactWrapper contact = getCurrentUserContact();
            result.put('contact', contact);
            result.put('hamiltonDesignations', getHamiltonFundDesignations());

            List<PledgeWrapper> pledges = new List<PledgeWrapper>();
            if (contact != null && String.isNotBlank(contact.id)) {
                pledges = getUserPledges(contact.id);
            }
            result.put('pledges', pledges);

            Map<String, Object> rtv2Init = new Map<String, Object>();
            rtv2Init.put('ucinn_ascendv2__Transaction_Type__c', 'monthly'.equalsIgnoreCase(giftFrequency) ? 'Gift' : 'Gift');
            rtv2Init.put('ucinn_ascendv2__Tender_Type_1__c', 'Stripe');
            if (contact != null && String.isNotBlank(contact.id)) {
                rtv2Init.put('ucinn_ascendv2__Source_Contact__c', contact.id);
                rtv2Init.put('ucinn_ascendv2__External_System_ID__c', 'MGFT-' + Date.today().format() + '-' + contact.id);
            }
            result.put('rtv2Init', rtv2Init);
        } catch (Exception e) {
            throw new AuraHandledException('Error initializing form data: ' + e.getMessage());
        }
        return result;
    }

    @AuraEnabled(cacheable=true)
    public static List<DesignationWrapper> getHamiltonFundDesignations() {
        List<DesignationWrapper> designationList = new List<DesignationWrapper>();
        try {
            List<ucinn_ascendv2__Designation__c> designations = [
                SELECT Id, Name, ucinn_ascendv2__Designation_Name__c,
                       HAM_Designation_Comments__c, ucinn_ascendv2__Fund_Group__c,
                       HAM_Fund_Group_Name__c
                FROM ucinn_ascendv2__Designation__c
                WHERE RecordType.DeveloperName = 'HAM_Gift_Designation'
                AND ucinn_ascendv2__Status_Formula__c = 'Active'
                AND ucinn_ascendv2__Is_Publicly_Visible__c = TRUE
                AND ucinn_ascendv2__Fund_Group__c = 'Ha'
                ORDER BY HAM_Sort_Order__c ASC NULLS LAST, Name ASC
            ];
            for (ucinn_ascendv2__Designation__c d : designations) {
                designationList.add(new DesignationWrapper(d));
            }
        } catch (Exception e) {
            throw new AuraHandledException('Error fetching Hamilton Fund designations: ' + e.getMessage());
        }
        return designationList;
    }

    @AuraEnabled(cacheable=true)
    public static List<DesignationWrapper> searchOtherDesignations(String searchString) {
        List<DesignationWrapper> designationList = new List<DesignationWrapper>();
        try {
            if (String.isBlank(searchString) || searchString.trim().length() < 2) {
                return designationList;
            }
            String searchTerm = String.escapeSingleQuotes(searchString.trim()) + '*';
            List<List<SObject>> searchResults = Search.query(
                'FIND \'' + searchTerm + '\' ' +
                'IN ALL FIELDS ' +
                'RETURNING ucinn_ascendv2__Designation__c(' +
                    'Id, Name, ucinn_ascendv2__Designation_Name__c, ' +
                    'HAM_Designation_Comments__c, ucinn_ascendv2__Fund_Group__c, ' +
                    'HAM_Fund_Group_Name__c ' +
                    'WHERE RecordType.DeveloperName = \'HAM_Gift_Designation\' ' +
                    'AND ucinn_ascendv2__Status_Formula__c = \'Active\' ' +
                    'AND ucinn_ascendv2__Is_Publicly_Visible__c = TRUE ' +
                    'AND ucinn_ascendv2__Fund_Group__c != \'Ha\' ' +
                ')'
            );
            if (!searchResults.isEmpty() && !searchResults[0].isEmpty()) {
                for (SObject result : searchResults[0]) {
                    designationList.add(new DesignationWrapper((ucinn_ascendv2__Designation__c) result));
                }
            }
        } catch (Exception e) {
            throw new AuraHandledException('Error searching designations: ' + e.getMessage());
        }
        return designationList;
    }

    @AuraEnabled(cacheable=true)
    public static List<PledgeWrapper> getUserPledges(String contactId) {
        List<PledgeWrapper> pledgeList = new List<PledgeWrapper>();
        try {
            if (String.isBlank(contactId)) return pledgeList;
            List<Opportunity> pledges = [
                SELECT Id, Name, Amount,
                       ucinn_ascendv2__Remaining_Amount_Due_Formula__c,
                       ucinn_ascendv2__Amount_Paid_to_Date_Roll_Up__c,
                       CloseDate, StageName,
                       ucinn_ascendv2__Designation__c,
                       ucinn_ascendv2__Designation__r.Name,
                       ucinn_ascendv2__Designation__r.ucinn_ascendv2__Designation_Name__c,
                       ucinn_ascendv2__Designation__r.HAM_Designation_Comments__c
                FROM Opportunity
                WHERE RecordType.DeveloperName = 'Pledge'
                AND StageName = 'Active'
                AND ucinn_ascendv2__Remaining_Amount_Due_Formula__c > 0
                AND ucinn_ascendv2__Contact__c = :contactId
                ORDER BY CloseDate ASC
            ];
            for (Opportunity p : pledges) {
                pledgeList.add(new PledgeWrapper(p));
            }
        } catch (Exception e) {
            throw new AuraHandledException('Error fetching pledges: ' + e.getMessage());
        }
        return pledgeList;
    }

    @AuraEnabled(cacheable=true)
    public static ContactWrapper getCurrentUserContact() {
        try {
            Id userId = UserInfo.getUserId();
            User currentUser = [
                SELECT Id, ContactId, Contact.Name, Contact.Email,
                       Contact.Phone, Contact.MailingStreet,
                       Contact.MailingCity, Contact.MailingState,
                       Contact.MailingPostalCode, Contact.MailingCountry
                FROM User
                WHERE Id = :userId
                LIMIT 1
            ];
            if (currentUser.ContactId != null) {
                return new ContactWrapper(currentUser.Contact, currentUser.ContactId);
            }
            return null;
        } catch (Exception e) {
            throw new AuraHandledException('Error fetching user contact: ' + e.getMessage());
        }
    }

    @AuraEnabled
    public static String saveReviewTransaction(String transactionDataJSON) {
        try {
            Map<String, Object> dataMap = (Map<String, Object>) JSON.deserializeUntyped(transactionDataJSON);

            Id stpeRtId = Schema.SObjectType.ucinn_ascendv2__Review_Transaction_v2__c
                .getRecordTypeInfosByDeveloperName()
                .get('STPE')
                .getRecordTypeId();

            ucinn_ascendv2__Review_Transaction_v2__c rtv2 = new ucinn_ascendv2__Review_Transaction_v2__c();
            rtv2.RecordTypeId = stpeRtId;

            String giftPath = String.valueOf(dataMap.get('giftPath'));
            rtv2.ucinn_ascendv2__Transaction_Type__c = 'pledge'.equalsIgnoreCase(giftPath) ? 'Pledge Payment' : 'Gift';
            rtv2.ucinn_ascendv2__Tender_Type_1__c = 'Stripe';

            if (dataMap.containsKey('contactId') && dataMap.get('contactId') != null) {
                String contactId = String.valueOf(dataMap.get('contactId'));
                rtv2.ucinn_ascendv2__Source_Contact__c = contactId;
                rtv2.ucinn_ascendv2__Contact__c = contactId;
            }

            if (dataMap.containsKey('transactionId') && dataMap.get('transactionId') != null) {
                rtv2.ucinn_ascendv2__External_System_ID__c = 'MGFT-' + Date.today().format() + '-' + String.valueOf(dataMap.get('transactionId'));
                rtv2.Name = rtv2.ucinn_ascendv2__External_System_ID__c;
            }

            if (dataMap.containsKey('email') && dataMap.get('email') != null) {
                rtv2.ucinn_ascendv2__Email_1__c = String.valueOf(dataMap.get('email'));
            }

            if (dataMap.containsKey('amount') && dataMap.get('amount') != null) {
                rtv2.ucinn_ascendv2__Payment_Amount_1_1__c = Decimal.valueOf(String.valueOf(dataMap.get('amount')));
            }

            if (dataMap.containsKey('designationId') && dataMap.get('designationId') != null) {
                rtv2.ucinn_ascendv2__Designation_1__c = String.valueOf(dataMap.get('designationId'));
            }

            insert rtv2;
            return rtv2.Id;
        } catch (Exception e) {
            throw new AuraHandledException('Error saving review transaction: ' + e.getMessage());
        }
    }

    public class DesignationWrapper {
        @AuraEnabled public String id { get; set; }
        @AuraEnabled public String name { get; set; }
        @AuraEnabled public String description { get; set; }
        @AuraEnabled public String fundGroup { get; set; }
        @AuraEnabled public String fundGroupName { get; set; }

        public DesignationWrapper(ucinn_ascendv2__Designation__c d) {
            this.id = d.Id;
            this.name = d.ucinn_ascendv2__Designation_Name__c != null ? d.ucinn_ascendv2__Designation_Name__c : d.Name;
            this.description = d.HAM_Designation_Comments__c;
            this.fundGroup = d.ucinn_ascendv2__Fund_Group__c;
            this.fundGroupName = d.HAM_Fund_Group_Name__c;
        }
    }

    public class PledgeWrapper {
        @AuraEnabled public String id { get; set; }
        @AuraEnabled public String name { get; set; }
        @AuraEnabled public Decimal amount { get; set; }
        @AuraEnabled public Decimal paidAmount { get; set; }
        @AuraEnabled public Decimal remainingAmount { get; set; }
        @AuraEnabled public String designationId { get; set; }
        @AuraEnabled public String designationName { get; set; }
        @AuraEnabled public String description { get; set; }
        @AuraEnabled public Date closeDate { get; set; }
        @AuraEnabled public String stageName { get; set; }

        public PledgeWrapper(Opportunity p) {
            this.id = p.Id;
            this.name = p.Name;
            this.amount = p.Amount;
            this.paidAmount = p.ucinn_ascendv2__Amount_Paid_to_Date_Roll_Up__c != null ?
                             p.ucinn_ascendv2__Amount_Paid_to_Date_Roll_Up__c : 0;
            this.remainingAmount = p.ucinn_ascendv2__Remaining_Amount_Due_Formula__c;
            this.designationId = p.ucinn_ascendv2__Designation__c;
            this.designationName = p.ucinn_ascendv2__Designation__r?.ucinn_ascendv2__Designation_Name__c != null ?
                                  p.ucinn_ascendv2__Designation__r.ucinn_ascendv2__Designation_Name__c :
                                  p.ucinn_ascendv2__Designation__r?.Name;
            this.description = p.ucinn_ascendv2__Designation__r?.HAM_Designation_Comments__c;
            this.closeDate = p.CloseDate;
            this.stageName = p.StageName;
        }
    }

    public class ContactWrapper {
        @AuraEnabled public String id { get; set; }
        @AuraEnabled public String name { get; set; }
        @AuraEnabled public String email { get; set; }
        @AuraEnabled public String phone { get; set; }
        @AuraEnabled public String street { get; set; }
        @AuraEnabled public String city { get; set; }
        @AuraEnabled public String state { get; set; }
        @AuraEnabled public String postalCode { get; set; }
        @AuraEnabled public String country { get; set; }

        public ContactWrapper(Contact c, String contactId) {
            this.id = contactId;
            this.name = c.Name;
            this.email = c.Email;
            this.phone = c.Phone;
            this.street = c.MailingStreet;
            this.city = c.MailingCity;
            this.state = c.MailingState;
            this.postalCode = c.MailingPostalCode;
            this.country = c.MailingCountry;
        }
    }
}