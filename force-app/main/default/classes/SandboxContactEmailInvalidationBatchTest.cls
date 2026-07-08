@isTest
public class SandboxContactEmailInvalidationBatchTest {
    @TestSetup
    static void makeData(){
        Contact con1 = new Contact(
            LastName = 'Test1',
            Email = 'con1@test.com',
            ucinn_ascendv2__Contact_Type__c = 'Friend',
            ucinn_ascendv2__Data_Source__c = 'SIS'
        );

        Contact con2 = new Contact(
            LastName = 'Test2',
            Email = 'con2@test.com',
            ucinn_ascendv2__Contact_Type__c = 'Friend',
            ucinn_ascendv2__Data_Source__c = 'SIS'
        );

        Contact con3 = new Contact(
            LastName = 'Test3',
            Email = 'con3@test.com',
            ucinn_ascendv2__Contact_Type__c = 'Friend',
            ucinn_ascendv2__Data_Source__c = 'SIS'
        );
        insert new List<Contact>{con1, con2, con3};
    }

    @isTest
    public static void runBatchClassSandboxEnv(){
        Test.startTest();

        SandboxContactEmailInvalidationBatch batch = new SandboxContactEmailInvalidationBatch();
        batch.isSandbox = true;

        Id batchJobId = Database.executeBatch(batch, 200);

        Test.stopTest();

        for(Contact con : [SELECT Id, Email FROM Contact]){
            Assert.areEqual('.invalid', con.Email.right(8));
        }
    }

    @isTest
    public static void runBatchClassProdEnv(){
        Test.startTest();

        SandboxContactEmailInvalidationBatch batch = new SandboxContactEmailInvalidationBatch();
        batch.isSandbox = false;

        Id batchJobId = Database.executeBatch(batch, 200);

        Test.stopTest();

        for(Contact con : [SELECT Id, Email FROM Contact]){
            Assert.areEqual('test.com', con.Email.right(8));
        }
    }
}