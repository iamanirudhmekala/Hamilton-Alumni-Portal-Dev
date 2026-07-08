@isTest
public class PrepareSandboxTest {
    @TestSetup
    static void makeData(){
        insert new ucinn_ascendv2__Org_Wide_Configuration__c(Name = 'Default Org Wide Config');
        
        ucinn_ascendv2__Trigger_Handler__c conHandler = new ucinn_ascendv2__Trigger_Handler__c(
          Name = 'ascend_TRIG_ContactHandler',
          ucinn_ascendv2__Class__c = 'ascend_TRIG_ContactHandler',
          ucinn_ascendv2__Is_Active__c = true,
          ucinn_ascendv2__Is_Asynchronous__c = false,
          ucinn_ascendv2__Is_User_Managed__c = true,
          ucinn_ascendv2__Owned_by_Namespace__c = 'ucinn_ascendv2',
          ucinn_ascendv2__Load_Order__c = 1.0,
          ucinn_ascendv2__Object__c = 'Contact',
          ucinn_ascendv2__Trigger_Action__c = 'BeforeInsert;BeforeUpdate;BeforeDelete;AfterInsert;AfterUpdate;AfterDelete;AfterUndelete'
        );

        ucinn_ascendv2__Trigger_Handler__c emailHandler = new ucinn_ascendv2__Trigger_Handler__c(
          Name = 'ascend_TRIG_EmailHandler',
          ucinn_ascendv2__Class__c = 'ascend_TRIG_EmailHandler',
          ucinn_ascendv2__Is_Active__c = true,
          ucinn_ascendv2__Is_Asynchronous__c = false,
          ucinn_ascendv2__Is_User_Managed__c = true,
          ucinn_ascendv2__Owned_by_Namespace__c = 'ucinn_ascendv2',
          ucinn_ascendv2__Load_Order__c = 1.0,
          ucinn_ascendv2__Object__c = 'ucinn_ascendv2__Email__c',
          ucinn_ascendv2__Trigger_Action__c = 'BeforeInsert;BeforeUpdate;BeforeDelete;AfterInsert;AfterUpdate;AfterDelete;AfterUndelete'
        );
        insert new List<ucinn_ascendv2__Trigger_Handler__c>{conHandler, emailHandler};

        Id emailRTId = [SELECT Id FROM RecordType WHERE SobjectType = 'ucinn_ascendv2__Email__c' and DeveloperName = 'Contact_Email'].Id;
        
        Contact con1 = new Contact(
            LastName = 'Test1',
            ucinn_ascendv2__Contact_Type__c = 'Friend',
            ucinn_ascendv2__Data_Source__c = 'SIS'
        );

        Contact con2 = new Contact(
            LastName = 'Test2',
            ucinn_ascendv2__Contact_Type__c = 'Friend',
            ucinn_ascendv2__Data_Source__c = 'SIS'
        );

        Contact con3 = new Contact(
            LastName = 'Test3',
            ucinn_ascendv2__Contact_Type__c = 'Friend',
            ucinn_ascendv2__Data_Source__c = 'SIS'
        );
        insert new List<Contact>{con1, con2, con3};
        
        ucinn_ascendv2__Email__c email1 = new ucinn_ascendv2__Email__c(
            name = 'testEmail1',
            ucinn_ascendv2__Contact__c = con1.Id,
            ucinn_ascendv2__Email_Address__c = 'con1@test.com',
            ucinn_ascendv2__Is_Preferred__c = true,
            ucinn_ascendv2__Type__c = 'Business',
            ucinn_ascendv2__Status__c = 'Current',
            RecordTypeId = emailRTId
        );
        
        ucinn_ascendv2__Email__c email2 = new ucinn_ascendv2__Email__c(
            name = 'testEmail1',
            ucinn_ascendv2__Contact__c = con2.Id,
            ucinn_ascendv2__Email_Address__c = 'con2@test.com',
            ucinn_ascendv2__Is_Preferred__c = true,
            ucinn_ascendv2__Type__c = 'Business',
            ucinn_ascendv2__Status__c = 'Current',
            RecordTypeId = emailRTId
        );
        
        ucinn_ascendv2__Email__c email3 = new ucinn_ascendv2__Email__c(
            name = 'testEmail1',
            ucinn_ascendv2__Contact__c = con3.Id,
            ucinn_ascendv2__Email_Address__c = 'con3@test.com',
            ucinn_ascendv2__Is_Preferred__c = true,
            ucinn_ascendv2__Type__c = 'Business',
            ucinn_ascendv2__Status__c = 'Current',
            RecordTypeId = emailRTId
        );
        insert new List<ucinn_ascendv2__Email__c>{email1, email2, email3};
    }

    @isTest
    public static void testSandboxPrep(){
        Boolean isSandbox = [SELECT Id, IsSandbox FROM Organization].IsSandbox;

        Test.startTest();
        Test.testSandboxPostCopyScript(new PrepareSandbox(), UserInfo.getOrganizationId(), UserInfo.getOrganizationId(), UserInfo.getOrganizationName(), true);
        Test.stopTest();

        if(isSandbox){
            for(Contact con : [SELECT Id, Email FROM Contact]){
                Assert.areEqual('.invalid', con.Email.right(8));
            }
        }else{
            for(Contact con : [SELECT Id, Email FROM Contact]){
                Assert.areEqual('test.com', con.Email.right(8));
            }
        }
    }
}