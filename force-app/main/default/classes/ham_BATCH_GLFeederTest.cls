@isTest
public with sharing class ham_BATCH_GLFeederTest {

    @TestSetup
    public static void setupData(){
        ucinn_ascendv2.ascend_UTIL_TDTMTrigger.toggleTDTMTrigger(new Account().getSObjectType().getDescribe().getName(), false);
        ucinn_ascendv2.ascend_UTIL_TDTMTrigger.toggleTDTMTrigger(new Contact().getSObjectType().getDescribe().getName(), false);
        ucinn_ascendv2.ascend_UTIL_TDTMTrigger.toggleTDTMTrigger(new Campaign().getSObjectType().getDescribe().getName(), false);
        ucinn_ascendv2.ascend_UTIL_TDTMTrigger.toggleTDTMTrigger(new ucinn_ascendv2__Designation__c().getSObjectType().getDescribe().getName(), false);

        List<Account> testAccounts = new List<Account> { 
            new Account(
                Name = 'Household Acc', 
                ucinn_ascendv2__Donor_Id__c = '1000002',
                ucinn_ascendv2__Business_Email__c = 'hhAcc@gmail.com'
            )
        };
        insert testAccounts;
        
        List<ucinn_ascendv2__Designation__c> newDesignations = new List<ucinn_ascendv2__Designation__c> {
            new ucinn_ascendv2__Designation__c(
                Name = '0000',
                ucinn_ascendv2__Designation_Name__c = 'Test Designation 00',
                ucinn_ascendv2__External_System_Id__c = '0000',
                ucinn_ascendv2__G_L_Effective_Date__c = System.today().addDays(-1)
            )
        };
        insert newDesignations;

        Id devRecordTypeId = Schema.SObjectType.Campaign.getRecordTypeInfosByName().get('Appeal').getRecordTypeId();
        List<Campaign> newCampaigns = new List<Campaign> {
            new Campaign(
                Name = 'Test Appeal 00',
                RecordTypeId = devRecordTypeId,
                HAM_Fiscal_Year__c = '2020'
            )
        };
        insert newCampaigns;

        List<Contact> contactsList =  new List<Contact> {
            new Contact(
                FirstName = 'Test Constituent',
                LastName = 'Test_000',
                ucinn_ascendv2__Contact_Type__c = 'Friend',
                ucinn_ascendv2__Donor_Id__c = '01000200001',
                ucinn_ascendv2__Personal_Email__c = 'myEmail@personal.com',
                AccountId = testAccounts[0].Id
            )
        };

        insert contactsList;
    }

    @IsTest 
    public static void outrightGiftTest() {
        
        ucinn_ascendv2.ascend_UTIL_TDTMTrigger.toggleTDTMTrigger(new ucinn_ascendv2__Session__c().getSObjectType().getDescribe().getName(), false);
        ucinn_ascendv2.ascend_UTIL_TDTMTrigger.toggleTDTMTrigger(new ucinn_ascendv2__Designation_Detail__c().getSObjectType().getDescribe().getName(), false);
        ucinn_ascendv2.ascend_UTIL_TDTMTrigger.toggleTDTMTrigger(new ucinn_ascendv2__Payment__c().getSObjectType().getDescribe().getName(), false);
        ucinn_ascendv2.ascend_UTIL_TDTMTrigger.toggleTDTMTrigger(new Opportunity().getSObjectType().getDescribe().getName(), false);
                
        Contact myContact = [SELECT Id, FirstName, LastName FROM Contact ORDER BY LastName ASC LIMIT 1];
        Account myAccount = [SELECT Id, Name FROM Account LIMIT 1];
        ucinn_ascendv2__Designation__c testDesignation = [SELECT Id FROM ucinn_ascendv2__Designation__c LIMIT 1];
        Campaign testCampaign = [SELECT Id FROM Campaign LIMIT 1];
        
        ucinn_ascendv2__Session__c newSession = new ucinn_ascendv2__Session__c(
            ucinn_ascendv2__Session_Date__c = System.Today(),
            Name = 'OutrightGiftTest',
            ucinn_ascendv2__Is_Ready_for_G_L__c = true,
            ucinn_ascendv2__Session_Totals_Approved__c = System.now(),
            ucinn_ascendv2__Is_Sent_to_G_L__c = false,
            HAM_Is_Sent_to_GL_Feeder__c = false
        );
        insert newSession;

        Opportunity outrightGift = new Opportunity(
            Name = 'New Outright Gift',
            StageName = 'Paid',
            CloseDate = System.Today(),
            ucinn_ascendv2__Credit_Date__c = System.Today(),
            RecordTypeId = Schema.SObjectType.Opportunity.getRecordTypeInfosByDeveloperName().get('Gift').getRecordTypeId(),
            ucinn_ascendv2__Contact__c = myContact.Id,
            Amount = 2000.00,
            ucinn_ascendv2__Start_Date__c = System.Today(),
            ucinn_ascendv2__Session__c = newSession.Id,
            ucinn_ascendv2__Designation__c = testDesignation.Id,
            CampaignId = testCampaign.id,
            Type = 'Outright Gift'
        );
        insert outrightGift;

        ucinn_ascendv2__Designation_Detail__c newDesDetail = new ucinn_ascendv2__Designation_Detail__c(
            ucinn_ascendv2__Contact__c = myContact.Id,
            ucinn_ascendv2__Opportunity__c = outrightGift.Id,
            ucinn_ascendv2__Session__c = newSession.Id, 
            ucinn_ascendv2__Designation__c = testDesignation.Id,
            ucinn_ascendv2__Amount__c = 2000,
            ucinn_ascendv2__Campaign__c = testCampaign.Id
        );
        insert newDesDetail;

        List<ucinn_ascendv2__Payment__c> newPaymentsList = new List<ucinn_ascendv2__Payment__c> {
            new ucinn_ascendv2__Payment__c(
                ucinn_ascendv2__Contact__c = myContact.Id,
                ucinn_ascendv2__Payment_Amount__c = 1000,
                ucinn_ascendv2__Credit_Date__c = System.Today(),
                ucinn_ascendv2__Session__c = newSession.Id,
                ucinn_ascendv2__Opportunity__c = outrightGift.Id,
                ucinn_ascendv2__Designation__c = testDesignation.Id,
                ucinn_ascendv2__Designation_Detail__c = newDesDetail.Id,
                ucinn_ascendv2__Transaction_Type__c = 'Outright Gift',
                ucinn_ascendv2__Tender_Type_for_Gifts__c = 'Cash',
                ucinn_ascendv2__Payment_Group_Id__c = '00001',
                ucinn_ascendv2__Send_to_G_L__c = true
            ),
            new ucinn_ascendv2__Payment__c(
                ucinn_ascendv2__Contact__c = myContact.Id,
                ucinn_ascendv2__Payment_Amount__c = 1000,
                ucinn_ascendv2__Credit_Date__c = System.Today(),
                ucinn_ascendv2__Session__c = newSession.Id,
                ucinn_ascendv2__Opportunity__c = outrightGift.Id,
                ucinn_ascendv2__Designation__c = testDesignation.Id,
                ucinn_ascendv2__Designation_Detail__c = newDesDetail.Id,
                ucinn_ascendv2__Transaction_Type__c = 'Outright Gift',
                ucinn_ascendv2__Tender_Type_for_Gifts__c = 'Cash',
                ucinn_ascendv2__Payment_Group_Id__c = '00001',
                ucinn_ascendv2__Send_to_G_L__c = true
            ),
            new ucinn_ascendv2__Payment__c(
                ucinn_ascendv2__Account__c = myAccount.Id,
                ucinn_ascendv2__Payment_Amount__c = 1000,
                ucinn_ascendv2__Credit_Date__c = System.Today(),
                ucinn_ascendv2__Session__c = newSession.Id,
                ucinn_ascendv2__Opportunity__c = outrightGift.Id,
                ucinn_ascendv2__Designation__c = testDesignation.Id,
                ucinn_ascendv2__Designation_Detail__c = newDesDetail.Id,
                ucinn_ascendv2__Transaction_Type__c = 'Outright Gift',
                ucinn_ascendv2__Tender_Type_for_Gifts__c = 'Cash',
                ucinn_ascendv2__Payment_Group_Id__c = '00001',
                ucinn_ascendv2__Send_to_G_L__c = true
            )
        };
            
        insert newPaymentsList;
      
        Test.startTest();
        ham_BATCH_GLFeeder bankFeed = new ham_BATCH_GLFeeder();
        Database.executeBatch(bankFeed);
        Test.stopTest();

        List<GL_Feeder__c> feeders = [SELECT id FROM GL_Feeder__c];
        System.assertEquals(3, feeders.size());
    }
    
    

    @IsTest 
    public static void adjustmentTest() {
        
        ucinn_ascendv2.ascend_UTIL_TDTMTrigger.toggleTDTMTrigger(new ucinn_ascendv2__Session__c().getSObjectType().getDescribe().getName(), false);
        ucinn_ascendv2.ascend_UTIL_TDTMTrigger.toggleTDTMTrigger(new ucinn_ascendv2__Designation_Detail__c().getSObjectType().getDescribe().getName(), false);
        ucinn_ascendv2.ascend_UTIL_TDTMTrigger.toggleTDTMTrigger(new ucinn_ascendv2__Payment__c().getSObjectType().getDescribe().getName(), false);
        ucinn_ascendv2.ascend_UTIL_TDTMTrigger.toggleTDTMTrigger(new Opportunity().getSObjectType().getDescribe().getName(), false);
                
        Contact myContact = [SELECT Id, FirstName, LastName FROM Contact ORDER BY LastName ASC LIMIT 1];
        Account myAccount = [SELECT Id, Name FROM Account LIMIT 1];
        ucinn_ascendv2__Designation__c testDesignation = [SELECT Id FROM ucinn_ascendv2__Designation__c LIMIT 1];
        Campaign testCampaign = [SELECT Id FROM Campaign LIMIT 1];
        
        ucinn_ascendv2__Session__c oldSession = new ucinn_ascendv2__Session__c(
            ucinn_ascendv2__Session_Date__c = System.Today(),
            Name = 'oldSession',
            ucinn_ascendv2__Is_Ready_for_G_L__c = false,
            ucinn_ascendv2__Session_Totals_Approved__c = System.now(),
            ucinn_ascendv2__Is_Sent_to_G_L__c = true,
            HAM_Is_Sent_to_GL_Feeder__c = true
        );
        insert oldSession;
        
        ucinn_ascendv2__Session__c newSession = new ucinn_ascendv2__Session__c(
            ucinn_ascendv2__Session_Date__c = System.Today(),
            Name = 'OutrightGiftTest',
            ucinn_ascendv2__Is_Ready_for_G_L__c = true,
            ucinn_ascendv2__Session_Totals_Approved__c = System.now(),
            ucinn_ascendv2__Is_Sent_to_G_L__c = false,
            HAM_Is_Sent_to_GL_Feeder__c = false
        );
        insert newSession;

        Opportunity adjustedGift = new Opportunity(
            Name = 'Adjusted Gift',
            StageName = 'Paid',
            CloseDate = System.Today(),
            ucinn_ascendv2__Credit_Date__c = System.Today(),
            RecordTypeId = Schema.SObjectType.Opportunity.getRecordTypeInfosByDeveloperName().get('Gift').getRecordTypeId(),
            ucinn_ascendv2__Contact__c = myContact.Id,
            Amount = 2000.00,
            ucinn_ascendv2__Start_Date__c = System.Today(),
            ucinn_ascendv2__Session__c = newSession.Id,
            ucinn_ascendv2__Designation__c = testDesignation.Id,
            CampaignId = testCampaign.id,
            Type = 'Outright Gift'
        );
        insert adjustedGift;

        Opportunity outrightGift = new Opportunity(
            Name = 'New Outright Gift',
            StageName = 'Paid',
            CloseDate = System.Today(),
            ucinn_ascendv2__Credit_Date__c = System.Today(),
            RecordTypeId = Schema.SObjectType.Opportunity.getRecordTypeInfosByDeveloperName().get('Gift').getRecordTypeId(),
            ucinn_ascendv2__Contact__c = myContact.Id,
            Amount = 2000.00,
            ucinn_ascendv2__Start_Date__c = System.Today(),
            ucinn_ascendv2__Session__c = newSession.Id,
            ucinn_ascendv2__Designation__c = testDesignation.Id,
            CampaignId = testCampaign.id,
            Type = 'Outright Gift'
        );
        insert outrightGift;

        ucinn_ascendv2__Designation_Detail__c newDesDetail = new ucinn_ascendv2__Designation_Detail__c(
            ucinn_ascendv2__Contact__c = myContact.Id,
            ucinn_ascendv2__Opportunity__c = outrightGift.Id,
            ucinn_ascendv2__Session__c = newSession.Id, 
            ucinn_ascendv2__Designation__c = testDesignation.Id,
            ucinn_ascendv2__Amount__c = 2000,
            ucinn_ascendv2__Campaign__c = testCampaign.Id
        );
        insert newDesDetail;

        List<ucinn_ascendv2__Payment__c> newPaymentsList = new List<ucinn_ascendv2__Payment__c> {
            new ucinn_ascendv2__Payment__c(
                ucinn_ascendv2__Contact__c = myContact.Id,
                ucinn_ascendv2__Payment_Amount__c = 1000,
                ucinn_ascendv2__Credit_Date__c = System.Today(),
                ucinn_ascendv2__Session__c = oldSession.Id,
                ucinn_ascendv2__Opportunity__c = adjustedGift.Id,
                ucinn_ascendv2__Designation__c = testDesignation.Id,
                ucinn_ascendv2__Designation_Detail__c = newDesDetail.Id,
                ucinn_ascendv2__Transaction_Type__c = 'Outright Gift',
                ucinn_ascendv2__Tender_Type_for_Gifts__c = 'Cash',
                ucinn_ascendv2__Payment_Group_Id__c = '00001',
                ucinn_ascendv2__Send_to_G_L__c = true
            ),
            new ucinn_ascendv2__Payment__c(
                ucinn_ascendv2__Contact__c = myContact.Id,
                ucinn_ascendv2__Payment_Amount__c = 1000,
                ucinn_ascendv2__Credit_Date__c = System.Today(),
                ucinn_ascendv2__Session__c = oldSession.Id,
                ucinn_ascendv2__Opportunity__c = adjustedGift.Id,
                ucinn_ascendv2__Designation__c = testDesignation.Id,
                ucinn_ascendv2__Designation_Detail__c = newDesDetail.Id,
                ucinn_ascendv2__Transaction_Type__c = 'Outright Gift',
                ucinn_ascendv2__Tender_Type_for_Gifts__c = 'Cash',
                ucinn_ascendv2__Payment_Group_Id__c = '00001',
                ucinn_ascendv2__Send_to_G_L__c = true
            ),
            new ucinn_ascendv2__Payment__c(
                ucinn_ascendv2__Account__c = myAccount.Id,
                ucinn_ascendv2__Payment_Amount__c = 1000,
                ucinn_ascendv2__Credit_Date__c = System.Today(),
                ucinn_ascendv2__Session__c = oldSession.Id,
                ucinn_ascendv2__Opportunity__c = adjustedGift.Id,
                ucinn_ascendv2__Designation__c = testDesignation.Id,
                ucinn_ascendv2__Designation_Detail__c = newDesDetail.Id,
                ucinn_ascendv2__Transaction_Type__c = 'Outright Gift',
                ucinn_ascendv2__Tender_Type_for_Gifts__c = 'Cash',
                ucinn_ascendv2__Payment_Group_Id__c = '00001',
                ucinn_ascendv2__Send_to_G_L__c = true
            ),
                
            new ucinn_ascendv2__Payment__c(
                ucinn_ascendv2__Contact__c = myContact.Id,
                ucinn_ascendv2__Payment_Amount__c = 1000,
                ucinn_ascendv2__Credit_Date__c = System.Today(),
                ucinn_ascendv2__Session__c = newSession.Id,
                ucinn_ascendv2__Adjusted_Gift__c = adjustedGift.id,
                ucinn_ascendv2__Opportunity__c = outrightGift.Id,
                ucinn_ascendv2__Designation__c = testDesignation.Id,
                ucinn_ascendv2__Designation_Detail__c = newDesDetail.Id,
                ucinn_ascendv2__Transaction_Type__c = 'Outright Gift',
                ucinn_ascendv2__Tender_Type_for_Gifts__c = 'Cash',
                ucinn_ascendv2__Payment_Group_Id__c = '00001',
                ucinn_ascendv2__Send_to_G_L__c = true
            ),
            new ucinn_ascendv2__Payment__c(
                ucinn_ascendv2__Contact__c = myContact.Id,
                ucinn_ascendv2__Payment_Amount__c = 1000,
                ucinn_ascendv2__Credit_Date__c = System.Today(),
                ucinn_ascendv2__Session__c = newSession.Id,
                ucinn_ascendv2__Adjusted_Gift__c = adjustedGift.id,
                ucinn_ascendv2__Opportunity__c = outrightGift.Id,
                ucinn_ascendv2__Designation__c = testDesignation.Id,
                ucinn_ascendv2__Designation_Detail__c = newDesDetail.Id,
                ucinn_ascendv2__Transaction_Type__c = 'Outright Gift',
                ucinn_ascendv2__Tender_Type_for_Gifts__c = 'Cash',
                ucinn_ascendv2__Payment_Group_Id__c = '00001',
                ucinn_ascendv2__Send_to_G_L__c = true
            ),
            new ucinn_ascendv2__Payment__c(
                ucinn_ascendv2__Account__c = myAccount.Id,
                ucinn_ascendv2__Payment_Amount__c = 1000,
                ucinn_ascendv2__Credit_Date__c = System.Today(),
                ucinn_ascendv2__Session__c = newSession.Id,
                ucinn_ascendv2__Adjusted_Gift__c = adjustedGift.id,
                ucinn_ascendv2__Opportunity__c = outrightGift.Id,
                ucinn_ascendv2__Designation__c = testDesignation.Id,
                ucinn_ascendv2__Designation_Detail__c = newDesDetail.Id,
                ucinn_ascendv2__Transaction_Type__c = 'Outright Gift',
                ucinn_ascendv2__Tender_Type_for_Gifts__c = 'Cash',
                ucinn_ascendv2__Payment_Group_Id__c = '00001',
                ucinn_ascendv2__Send_to_G_L__c = true
            )
        };
            
        insert newPaymentsList;
      
        Test.startTest();
        ham_BATCH_GLFeeder bankFeed = new ham_BATCH_GLFeeder();
        Database.executeBatch(bankFeed);
        String cronExp = '0 0 0 * * ?'; 
        System.schedule('Test Batch', cronExp, new ham_SCHED_GLFeeder());
        Test.stopTest();

        List<GL_Feeder__c> feeders = [SELECT id FROM GL_Feeder__c];
        System.assertEquals(6, feeders.size());
    }
}