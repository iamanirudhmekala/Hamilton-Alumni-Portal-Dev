@isTest
private class HamGivingPagePaymentTabControllerTest {

    @IsTest
    static void testGetPersonDetails_contactUserAndEmpty() {
        // Create a Contact to test contact path
        Contact c = new Contact(FirstName = 'John', LastName = 'Doe', Email = 'john.doe@example.com');
        insert c;

        // Create a User to test user path. Use current profile to avoid dependency on specific profile names.
        Profile p = [SELECT Id FROM Profile WHERE Id = :UserInfo.getProfileId() LIMIT 1];
        String unique = String.valueOf(DateTime.now().getTime());
        User u = new User(
            Username = 'testuser' + unique + '@example.com',
            Email = 'test.user+' + unique + '@example.com',
            FirstName = 'Test',
            LastName = 'Tester',
            Alias = 'tuser',
            TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            ProfileId = p.Id,
            LanguageLocaleKey = 'en_US'
        );
        insert u;

        Test.startTest();
        // Verify contact path
        HamGivingPagePaymentTabController.Person contactPerson = HamGivingPagePaymentTabController.getPersonDetails(null, c.Id);
        System.assertEquals(c.Email, contactPerson.email, 'Contact email should be returned');
        System.assertEquals(c.FirstName + ' ' + c.LastName, contactPerson.fullName, 'Contact name should be returned');

        // Verify user path
        HamGivingPagePaymentTabController.Person userPerson = HamGivingPagePaymentTabController.getPersonDetails(u.Id, null);
        System.assertEquals(u.Email, userPerson.email, 'User email should be returned');
        System.assertEquals(u.FirstName + ' ' + u.LastName, userPerson.fullName, 'User name should be returned');

        // Verify empty inputs return empty Person
        HamGivingPagePaymentTabController.Person emptyPerson = HamGivingPagePaymentTabController.getPersonDetails('', '');
        System.assertEquals(null, emptyPerson.email, 'Empty input should return no email');
        System.assertEquals(null, emptyPerson.fullName, 'Empty input should return no name');
        Test.stopTest();
    }

    @isTest
    private static void testSaveReviewTransactionV2_basic() {
        // Create a Contact so controller can populate name and contact lookup
        Contact c = new Contact(FirstName = 'Donor', LastName = 'Test', Email = 'donor@example.com');
        insert c;

        HamGivingPagePaymentTabController.FormData fd = new HamGivingPagePaymentTabController.FormData();
        fd.paymentType = 'monthly';
        fd.paymentMethod = 'Credit Card';
        fd.personEmail = 'donor@example.com';
        fd.inMemoryOf = 'John Smith';
        fd.inHonorOf = null;
        fd.contactId = c.Id;
        fd.transactionDate = Datetime.now();
        fd.transactionId = 'T123';
        fd.personAddressLineOne = '123 Main St';
        fd.personAddressLineTwo = 'Suite 1';
        fd.selectedDesignations = null;

        Test.startTest();
        HamGivingPagePaymentTabController.saveReviewTransactionV2(fd);
        Test.stopTest();

        // Verify the review transaction was created and fields were populated
        ucinn_ascendv2__Review_Transaction_v2__c[] results = [
            SELECT Id,
                   ucinn_ascendv2__External_System_ID__c,
                   ucinn_ascendv2__First_Name__c,
                   ucinn_ascendv2__Last_Name__c,
                   ucinn_ascendv2__Contact__c,
                   HAM_Is_Recurring_Gift__c,
                   ucinn_ascendv2__In_Memory_Honor_First_Name_1__c,
                   ucinn_ascendv2__In_Memory_Honor_Last_Name_1__c,
                   ucinn_ascendv2__Email_1__c,
                   ucinn_ascendv2__Address_1_Line_1__c,
                   ucinn_ascendv2__Address_1_Line_2__c
            FROM ucinn_ascendv2__Review_Transaction_v2__c
            WHERE ucinn_ascendv2__External_System_ID__c = :('MGFT-' + fd.transactionId)
            LIMIT 1
        ];

        System.assertEquals(1, results.size(), 'Review transaction should be inserted');
        ucinn_ascendv2__Review_Transaction_v2__c rt = results[0];
        System.assertEquals('MGFT-T123', rt.ucinn_ascendv2__External_System_ID__c);
        System.assertEquals(c.FirstName, rt.ucinn_ascendv2__First_Name__c);
        System.assertEquals(c.LastName, rt.ucinn_ascendv2__Last_Name__c);
        System.assertEquals(c.Id, rt.ucinn_ascendv2__Contact__c);
        System.assertEquals(true, rt.HAM_Is_Recurring_Gift__c);
        System.assertEquals('John', rt.ucinn_ascendv2__In_Memory_Honor_First_Name_1__c);
        System.assertEquals('Smith', rt.ucinn_ascendv2__In_Memory_Honor_Last_Name_1__c);
        System.assertEquals('donor@example.com', rt.ucinn_ascendv2__Email_1__c);
		System.assertEquals(null, rt.ucinn_ascendv2__Address_1_Line_1__c);
		System.assertEquals(null, rt.ucinn_ascendv2__Address_1_Line_2__c);
    }

    @isTest
    private static void testSaveReviewTransactionV2_basic_2() {
        // Create a Contact so controller can populate name and contact lookup
        Contact c = new Contact(FirstName = 'Donor', LastName = 'Test', Email = 'donor@example.com');
        insert c;

        HamGivingPagePaymentTabController.FormData fd = new HamGivingPagePaymentTabController.FormData();
        fd.paymentType = 'monthly';
        fd.paymentMethod = 'Credit Card';
        fd.personEmail = 'donor@example.com';
        fd.inMemoryOf = null;
        fd.inHonorOf = 'John Smith';
        fd.contactId = c.Id;
        fd.transactionDate = Datetime.now();
        fd.transactionId = 'T123';
        fd.personAddressLineOne = '123 Main St';
        fd.personAddressLineTwo = 'Suite 1';
        fd.selectedDesignations = null;

        Test.startTest();
        HamGivingPagePaymentTabController.saveReviewTransactionV2(fd);
        Test.stopTest();

        // Verify the review transaction was created and fields were populated
        ucinn_ascendv2__Review_Transaction_v2__c[] results = [
            SELECT Id,
                   ucinn_ascendv2__External_System_ID__c,
                   ucinn_ascendv2__First_Name__c,
                   ucinn_ascendv2__Last_Name__c,
                   ucinn_ascendv2__Contact__c,
                   HAM_Is_Recurring_Gift__c,
                   ucinn_ascendv2__In_Memory_Honor_First_Name_1__c,
                   ucinn_ascendv2__In_Memory_Honor_Last_Name_1__c,
                   ucinn_ascendv2__Email_1__c,
                   ucinn_ascendv2__Address_1_Line_1__c,
                   ucinn_ascendv2__Address_1_Line_2__c
            FROM ucinn_ascendv2__Review_Transaction_v2__c
            WHERE ucinn_ascendv2__External_System_ID__c = :('MGFT-' + fd.transactionId)
            LIMIT 1
        ];

        System.assertEquals(1, results.size(), 'Review transaction should be inserted');
        ucinn_ascendv2__Review_Transaction_v2__c rt = results[0];
        System.assertEquals('MGFT-T123', rt.ucinn_ascendv2__External_System_ID__c);
        System.assertEquals(c.FirstName, rt.ucinn_ascendv2__First_Name__c);
        System.assertEquals(c.LastName, rt.ucinn_ascendv2__Last_Name__c);
        System.assertEquals(c.Id, rt.ucinn_ascendv2__Contact__c);
        System.assertEquals(true, rt.HAM_Is_Recurring_Gift__c);
        System.assertEquals('John', rt.ucinn_ascendv2__In_Memory_Honor_First_Name_1__c);
        System.assertEquals('Smith', rt.ucinn_ascendv2__In_Memory_Honor_Last_Name_1__c);
        System.assertEquals('donor@example.com', rt.ucinn_ascendv2__Email_1__c);
        System.assertEquals(null, rt.ucinn_ascendv2__Address_1_Line_1__c);
        System.assertEquals(null, rt.ucinn_ascendv2__Address_1_Line_2__c);
    }

    @isTest
    private static void testSaveReviewTransactionV2_noContact_and_defaults() {
        HamGivingPagePaymentTabController.FormData fd = new HamGivingPagePaymentTabController.FormData();
        fd.paymentType = 'one-time';
        fd.paymentMethod = 'Credit Card';
        fd.personEmail = 'noone@example.com';
        fd.transactionDate = Datetime.now();
        fd.transactionId = 'T456';
        fd.personAddressLineOne = null;
        fd.personAddressLineTwo = null;
        fd.selectedDesignations = null;

        Test.startTest();
        HamGivingPagePaymentTabController.saveReviewTransactionV2(fd);
        Test.stopTest();

        ucinn_ascendv2__Review_Transaction_v2__c[] results = [
            SELECT Id, ucinn_ascendv2__External_System_ID__c, ucinn_ascendv2__Tender_Type_1__c
            FROM ucinn_ascendv2__Review_Transaction_v2__c
            WHERE ucinn_ascendv2__External_System_ID__c = :('MGFT-' + fd.transactionId)
            LIMIT 1
        ];

        System.assertEquals(1, results.size());
        System.assertEquals('MGFT-T456', results[0].ucinn_ascendv2__External_System_ID__c);
    }

    @isTest
    private static void testGetStripeCredentialsAndCallout() {
        Test.setMock(HttpCalloutMock.class, new HamGivingPagePaymentTabControllerMock.SuccessMock());
        // When no Stripe_Credentials__mdt exists the controller should return an empty list
        List<Stripe_Credentials__mdt> creds = HamGivingPagePaymentTabController.getStripeCredentials();

        // createPaymentLink should return error when there are no credentials
        HamGivingPagePaymentTabController.PaymentLink link = HamGivingPagePaymentTabController.createPaymentLink(500, 'Test Donation');
    }

     @isTest
    private static void testGetStripeCredentialsAndCalloutError() {
        Test.setMock(HttpCalloutMock.class, new HamGivingPagePaymentTabControllerMock.ErrorMock());
        // When no Stripe_Credentials__mdt exists the controller should return an empty list
        List<Stripe_Credentials__mdt> creds = HamGivingPagePaymentTabController.getStripeCredentials();

        // createPaymentLink should return error when there are no credentials
        HamGivingPagePaymentTabController.PaymentLink link = HamGivingPagePaymentTabController.createPaymentLink(500, 'Test Donation');
    }

    @isTest
    private static void testSaveReviewTransactionV2_with_One_Designation() {
        Contact c = new Contact(FirstName = 'Des', LastName = 'Gnee', Email = 'des@example.com');
        insert c;

        HamGivingPagePaymentTabController.FormData fd = new HamGivingPagePaymentTabController.FormData();
        fd.paymentType = 'one-time';
        fd.paymentMethod = 'Credit Card';
        fd.personEmail = 'des@example.com';
        fd.contactId = c.Id;
        fd.transactionDate = Datetime.now();
        fd.transactionId = 'TDES';

        // Create real designation records so the controller writes real lookup Ids
        ucinn_ascendv2__Designation__c des1 = new ucinn_ascendv2__Designation__c(Name = 'Design1');
        insert new List<ucinn_ascendv2__Designation__c>{des1};

        HamGivingPagePaymentTabController.Designation d1 = new HamGivingPagePaymentTabController.Designation();
        d1.id = des1.Id;
        d1.name = des1.Name;
        d1.amt = 10;

        fd.selectedDesignations = new List<HamGivingPagePaymentTabController.Designation>{d1};

        Test.startTest();
        HamGivingPagePaymentTabController.saveReviewTransactionV2(fd);
        Test.stopTest();

        ucinn_ascendv2__Review_Transaction_v2__c rt = [
            SELECT ucinn_ascendv2__Designation_1__c, ucinn_ascendv2__Designation_2__c,
                   ucinn_ascendv2__Payment_Amount_1_1__c, ucinn_ascendv2__Payment_Amount_2_1__c,
                   ucinn_ascendv2__Payment_Date_1_1__c, ucinn_ascendv2__Payment_Date_2_1__c,
                   ucinn_ascendv2__Transaction_Date__c
            FROM ucinn_ascendv2__Review_Transaction_v2__c
            WHERE ucinn_ascendv2__External_System_ID__c = :('MGFT-' + fd.transactionId)
            LIMIT 1
        ];

        System.assertEquals(des1.Id, rt.ucinn_ascendv2__Designation_1__c);
        System.assertEquals(10, rt.ucinn_ascendv2__Payment_Amount_1_1__c);
        Date expectedDate = fd.transactionDate.date();
        System.assertEquals(expectedDate, rt.ucinn_ascendv2__Transaction_Date__c);
        System.assertEquals(expectedDate, rt.ucinn_ascendv2__Payment_Date_1_1__c);
    }

    @isTest
    private static void testSaveReviewTransactionV2_with_Two_Designations() {
        Contact c = new Contact(FirstName = 'Des', LastName = 'Gnee', Email = 'des@example.com');
        insert c;

        HamGivingPagePaymentTabController.FormData fd = new HamGivingPagePaymentTabController.FormData();
        fd.paymentType = 'one-time';
        fd.paymentMethod = 'Credit Card';
        fd.personEmail = 'des@example.com';
        fd.contactId = c.Id;
        fd.transactionDate = Datetime.now();
        fd.transactionId = 'TDES';

        // Create real designation records so the controller writes real lookup Ids
        ucinn_ascendv2__Designation__c des1 = new ucinn_ascendv2__Designation__c(Name = 'Design1');
        ucinn_ascendv2__Designation__c des2 = new ucinn_ascendv2__Designation__c(Name = 'Design2');
        insert new List<ucinn_ascendv2__Designation__c>{des1, des2};

        HamGivingPagePaymentTabController.Designation d1 = new HamGivingPagePaymentTabController.Designation();
        d1.id = des1.Id;
        d1.name = des1.Name;
        d1.amt = 10;

        HamGivingPagePaymentTabController.Designation d2 = new HamGivingPagePaymentTabController.Designation();
        d2.id = des2.Id;
        d2.name = des2.Name;
        d2.amt = 20;

        fd.selectedDesignations = new List<HamGivingPagePaymentTabController.Designation>{d1, d2};

        Test.startTest();
        HamGivingPagePaymentTabController.saveReviewTransactionV2(fd);
        Test.stopTest();

        ucinn_ascendv2__Review_Transaction_v2__c rt = [
            SELECT ucinn_ascendv2__Designation_1__c, ucinn_ascendv2__Designation_2__c,
                   ucinn_ascendv2__Payment_Amount_1_1__c, ucinn_ascendv2__Payment_Amount_2_1__c,
                   ucinn_ascendv2__Payment_Date_1_1__c, ucinn_ascendv2__Payment_Date_2_1__c,
                   ucinn_ascendv2__Transaction_Date__c
            FROM ucinn_ascendv2__Review_Transaction_v2__c
            WHERE ucinn_ascendv2__External_System_ID__c = :('MGFT-' + fd.transactionId)
            LIMIT 1
        ];

        System.assertEquals(des1.Id, rt.ucinn_ascendv2__Designation_1__c);
        System.assertEquals(des2.Id, rt.ucinn_ascendv2__Designation_2__c);
        System.assertEquals(10, rt.ucinn_ascendv2__Payment_Amount_1_1__c);
        System.assertEquals(20, rt.ucinn_ascendv2__Payment_Amount_2_1__c);
        Date expectedDate = fd.transactionDate.date();
        System.assertEquals(expectedDate, rt.ucinn_ascendv2__Transaction_Date__c);
        System.assertEquals(expectedDate, rt.ucinn_ascendv2__Payment_Date_1_1__c);
        System.assertEquals(expectedDate, rt.ucinn_ascendv2__Payment_Date_2_1__c);
    }

    @isTest
    private static void testSaveReviewTransactionV2_with_Three_Designations() {
        Contact c = new Contact(FirstName = 'Des', LastName = 'Gnee', Email = 'des@example.com');
        insert c;

        HamGivingPagePaymentTabController.FormData fd = new HamGivingPagePaymentTabController.FormData();
        fd.paymentType = 'one-time';
        fd.paymentMethod = 'Credit Card';
        fd.personEmail = 'des@example.com';
        fd.contactId = c.Id;
        fd.transactionDate = Datetime.now();
        fd.transactionId = 'TDES';

        // Create real designation records so the controller writes real lookup Ids
        ucinn_ascendv2__Designation__c des1 = new ucinn_ascendv2__Designation__c(Name = 'Design1');
        ucinn_ascendv2__Designation__c des2 = new ucinn_ascendv2__Designation__c(Name = 'Design2');
        ucinn_ascendv2__Designation__c des3 = new ucinn_ascendv2__Designation__c(Name = 'Design3');
        insert new List<ucinn_ascendv2__Designation__c>{des1, des2, des3};

        HamGivingPagePaymentTabController.Designation d1 = new HamGivingPagePaymentTabController.Designation();
        d1.id = des1.Id;
        d1.name = des1.Name;
        d1.amt = 10;

        HamGivingPagePaymentTabController.Designation d2 = new HamGivingPagePaymentTabController.Designation();
        d2.id = des2.Id;
        d2.name = des2.Name;
        d2.amt = 20;

        HamGivingPagePaymentTabController.Designation d3 = new HamGivingPagePaymentTabController.Designation();
        d3.id = des3.Id;
        d3.name = des3.Name;
        d3.amt = 30;

        fd.selectedDesignations = new List<HamGivingPagePaymentTabController.Designation>{d1, d2, d3};

        Test.startTest();
        HamGivingPagePaymentTabController.saveReviewTransactionV2(fd);
        Test.stopTest();

        ucinn_ascendv2__Review_Transaction_v2__c rt = [
            SELECT ucinn_ascendv2__Designation_1__c, ucinn_ascendv2__Designation_2__c,
                   ucinn_ascendv2__Payment_Amount_1_1__c, ucinn_ascendv2__Payment_Amount_2_1__c,
                   ucinn_ascendv2__Payment_Date_1_1__c, ucinn_ascendv2__Payment_Date_2_1__c,
                   ucinn_ascendv2__Transaction_Date__c, ucinn_ascendv2__Designation_3__c,
                   ucinn_ascendv2__Payment_Amount_3_1__c, ucinn_ascendv2__Payment_Date_3_1__c
            FROM ucinn_ascendv2__Review_Transaction_v2__c
            WHERE ucinn_ascendv2__External_System_ID__c = :('MGFT-' + fd.transactionId)
            LIMIT 1
        ];

        System.assertEquals(des1.Id, rt.ucinn_ascendv2__Designation_1__c);
        System.assertEquals(des2.Id, rt.ucinn_ascendv2__Designation_2__c);
        System.assertEquals(des3.Id, rt.ucinn_ascendv2__Designation_3__c);
        System.assertEquals(10, rt.ucinn_ascendv2__Payment_Amount_1_1__c);
        System.assertEquals(20, rt.ucinn_ascendv2__Payment_Amount_2_1__c);
        System.assertEquals(30, rt.ucinn_ascendv2__Payment_Amount_3_1__c);
        Date expectedDate = fd.transactionDate.date();
        System.assertEquals(expectedDate, rt.ucinn_ascendv2__Transaction_Date__c);
        System.assertEquals(expectedDate, rt.ucinn_ascendv2__Payment_Date_1_1__c);
        System.assertEquals(expectedDate, rt.ucinn_ascendv2__Payment_Date_2_1__c);
        System.assertEquals(expectedDate, rt.ucinn_ascendv2__Payment_Date_3_1__c);
    }

    @isTest
    private static void testSaveReviewTransactionV2_with_Four_Designations() {
        Contact c = new Contact(FirstName = 'Des', LastName = 'Gnee', Email = 'des@example.com');
        insert c;

        HamGivingPagePaymentTabController.FormData fd = new HamGivingPagePaymentTabController.FormData();
        fd.paymentType = 'one-time';
        fd.paymentMethod = 'Credit Card';
        fd.personEmail = 'des@example.com';
        fd.contactId = c.Id;
        fd.transactionDate = Datetime.now();
        fd.transactionId = 'TDES';

        // Create real designation records so the controller writes real lookup Ids
        ucinn_ascendv2__Designation__c des1 = new ucinn_ascendv2__Designation__c(Name = 'Design1');
        ucinn_ascendv2__Designation__c des2 = new ucinn_ascendv2__Designation__c(Name = 'Design2');
        ucinn_ascendv2__Designation__c des3 = new ucinn_ascendv2__Designation__c(Name = 'Design3');
        ucinn_ascendv2__Designation__c des4 = new ucinn_ascendv2__Designation__c(Name = 'Design4');
        insert new List<ucinn_ascendv2__Designation__c>{des1, des2, des3, des4};

        HamGivingPagePaymentTabController.Designation d1 = new HamGivingPagePaymentTabController.Designation();
        d1.id = des1.Id;
        d1.name = des1.Name;
        d1.amt = 10;

        HamGivingPagePaymentTabController.Designation d2 = new HamGivingPagePaymentTabController.Designation();
        d2.id = des2.Id;
        d2.name = des2.Name;
        d2.amt = 20;

        HamGivingPagePaymentTabController.Designation d3 = new HamGivingPagePaymentTabController.Designation();
        d3.id = des3.Id;
        d3.name = des3.Name;
        d3.amt = 30;

        HamGivingPagePaymentTabController.Designation d4 = new HamGivingPagePaymentTabController.Designation();
        d4.id = des4.Id;
        d4.name = des4.Name;
        d4.amt = 40;

        fd.selectedDesignations = new List<HamGivingPagePaymentTabController.Designation>{d1, d2, d3, d4};

        Test.startTest();
        HamGivingPagePaymentTabController.saveReviewTransactionV2(fd);
        Test.stopTest();

        ucinn_ascendv2__Review_Transaction_v2__c rt = [
            SELECT ucinn_ascendv2__Designation_1__c, ucinn_ascendv2__Designation_2__c,
                   ucinn_ascendv2__Payment_Amount_1_1__c, ucinn_ascendv2__Payment_Amount_2_1__c,
                   ucinn_ascendv2__Payment_Date_1_1__c, ucinn_ascendv2__Payment_Date_2_1__c,
                   ucinn_ascendv2__Transaction_Date__c, ucinn_ascendv2__Designation_3__c,
                   ucinn_ascendv2__Payment_Amount_3_1__c, ucinn_ascendv2__Payment_Date_3_1__c,
                   ucinn_ascendv2__Designation_4__c,
                   ucinn_ascendv2__Payment_Amount_4_1__c, ucinn_ascendv2__Payment_Date_4_1__c
            FROM ucinn_ascendv2__Review_Transaction_v2__c
            WHERE ucinn_ascendv2__External_System_ID__c = :('MGFT-' + fd.transactionId)
            LIMIT 1
        ];

        System.assertEquals(des1.Id, rt.ucinn_ascendv2__Designation_1__c);
        System.assertEquals(des2.Id, rt.ucinn_ascendv2__Designation_2__c);
        System.assertEquals(des3.Id, rt.ucinn_ascendv2__Designation_3__c);
        System.assertEquals(des4.Id, rt.ucinn_ascendv2__Designation_4__c);
        System.assertEquals(10, rt.ucinn_ascendv2__Payment_Amount_1_1__c);
        System.assertEquals(20, rt.ucinn_ascendv2__Payment_Amount_2_1__c);
        System.assertEquals(30, rt.ucinn_ascendv2__Payment_Amount_3_1__c);
        System.assertEquals(40, rt.ucinn_ascendv2__Payment_Amount_4_1__c);
        Date expectedDate = fd.transactionDate.date();
        System.assertEquals(expectedDate, rt.ucinn_ascendv2__Transaction_Date__c);
        System.assertEquals(expectedDate, rt.ucinn_ascendv2__Payment_Date_1_1__c);
        System.assertEquals(expectedDate, rt.ucinn_ascendv2__Payment_Date_2_1__c);
        System.assertEquals(expectedDate, rt.ucinn_ascendv2__Payment_Date_3_1__c);
        System.assertEquals(expectedDate, rt.ucinn_ascendv2__Payment_Date_4_1__c);
    }

    @isTest
    private static void testSaveReviewTransactionV2_with_Five_Designations() {
        Contact c = new Contact(FirstName = 'Des', LastName = 'Gnee', Email = 'des@example.com');
        insert c;

        HamGivingPagePaymentTabController.FormData fd = new HamGivingPagePaymentTabController.FormData();
        fd.paymentType = 'one-time';
        fd.paymentMethod = 'Credit Card';
        fd.personEmail = 'des@example.com';
        fd.contactId = c.Id;
        fd.transactionDate = Datetime.now();
        fd.transactionId = 'TDES';

        // Create real designation records so the controller writes real lookup Ids
        ucinn_ascendv2__Designation__c des1 = new ucinn_ascendv2__Designation__c(Name = 'Design1');
        ucinn_ascendv2__Designation__c des2 = new ucinn_ascendv2__Designation__c(Name = 'Design2');
        ucinn_ascendv2__Designation__c des3 = new ucinn_ascendv2__Designation__c(Name = 'Design3');
        ucinn_ascendv2__Designation__c des4 = new ucinn_ascendv2__Designation__c(Name = 'Design4');
        ucinn_ascendv2__Designation__c des5 = new ucinn_ascendv2__Designation__c(Name = 'Design5');
        insert new List<ucinn_ascendv2__Designation__c>{des1, des2, des3, des4, des5};

        HamGivingPagePaymentTabController.Designation d1 = new HamGivingPagePaymentTabController.Designation();
        d1.id = des1.Id;
        d1.name = des1.Name;
        d1.amt = 10;

        HamGivingPagePaymentTabController.Designation d2 = new HamGivingPagePaymentTabController.Designation();
        d2.id = des2.Id;
        d2.name = des2.Name;
        d2.amt = 20;

        HamGivingPagePaymentTabController.Designation d3 = new HamGivingPagePaymentTabController.Designation();
        d3.id = des3.Id;
        d3.name = des3.Name;
        d3.amt = 30;

        HamGivingPagePaymentTabController.Designation d4 = new HamGivingPagePaymentTabController.Designation();
        d4.id = des4.Id;
        d4.name = des4.Name;
        d4.amt = 40;

        HamGivingPagePaymentTabController.Designation d5 = new HamGivingPagePaymentTabController.Designation();
        d5.id = des5.Id;
        d5.name = des4.Name;
        d5.amt = 50;

        fd.selectedDesignations = new List<HamGivingPagePaymentTabController.Designation>{d1, d2, d3, d4, d5};

        Test.startTest();
        HamGivingPagePaymentTabController.saveReviewTransactionV2(fd);
        Test.stopTest();

        ucinn_ascendv2__Review_Transaction_v2__c rt = [
            SELECT ucinn_ascendv2__Designation_1__c, ucinn_ascendv2__Designation_2__c,
                   ucinn_ascendv2__Payment_Amount_1_1__c, ucinn_ascendv2__Payment_Amount_2_1__c,
                   ucinn_ascendv2__Payment_Date_1_1__c, ucinn_ascendv2__Payment_Date_2_1__c,
                   ucinn_ascendv2__Transaction_Date__c, ucinn_ascendv2__Designation_3__c,
                   ucinn_ascendv2__Payment_Amount_3_1__c, ucinn_ascendv2__Payment_Date_3_1__c,
                   ucinn_ascendv2__Designation_4__c,
                   ucinn_ascendv2__Payment_Amount_4_1__c, ucinn_ascendv2__Payment_Date_4_1__c,
                   ucinn_ascendv2__Designation_5__c,
                   ucinn_ascendv2__Payment_Amount_5_1__c, ucinn_ascendv2__Payment_Date_5_1__c
            FROM ucinn_ascendv2__Review_Transaction_v2__c
            WHERE ucinn_ascendv2__External_System_ID__c = :('MGFT-' + fd.transactionId)
            LIMIT 1
        ];

        System.assertEquals(des1.Id, rt.ucinn_ascendv2__Designation_1__c);
        System.assertEquals(des2.Id, rt.ucinn_ascendv2__Designation_2__c);
        System.assertEquals(des3.Id, rt.ucinn_ascendv2__Designation_3__c);
        System.assertEquals(des4.Id, rt.ucinn_ascendv2__Designation_4__c);
        System.assertEquals(des5.Id, rt.ucinn_ascendv2__Designation_5__c);
        System.assertEquals(10, rt.ucinn_ascendv2__Payment_Amount_1_1__c);
        System.assertEquals(20, rt.ucinn_ascendv2__Payment_Amount_2_1__c);
        System.assertEquals(30, rt.ucinn_ascendv2__Payment_Amount_3_1__c);
        System.assertEquals(40, rt.ucinn_ascendv2__Payment_Amount_4_1__c);
        System.assertEquals(50, rt.ucinn_ascendv2__Payment_Amount_5_1__c);
        Date expectedDate = fd.transactionDate.date();
        System.assertEquals(expectedDate, rt.ucinn_ascendv2__Transaction_Date__c);
        System.assertEquals(expectedDate, rt.ucinn_ascendv2__Payment_Date_1_1__c);
        System.assertEquals(expectedDate, rt.ucinn_ascendv2__Payment_Date_2_1__c);
        System.assertEquals(expectedDate, rt.ucinn_ascendv2__Payment_Date_3_1__c);
        System.assertEquals(expectedDate, rt.ucinn_ascendv2__Payment_Date_4_1__c);
        System.assertEquals(expectedDate, rt.ucinn_ascendv2__Payment_Date_5_1__c);
    }
    
    //Added By Hamilton Team for Production deployment issue:
    @isTest
    private static void testSavePaymentTransaction_withDesignations() {
    
        // Create Contact (Constituent)
        Contact c = new Contact(
            FirstName = 'Payment',
            LastName = 'Donor',
            Email = 'payment@example.com'
        );
        insert c;
    
        // Create sample designation records (lookup targets)
        ucinn_ascendv2__Designation__c des1 = new ucinn_ascendv2__Designation__c(Name='Fund 1');
        ucinn_ascendv2__Designation__c des2 = new ucinn_ascendv2__Designation__c(Name='Fund 2');
        insert new List<ucinn_ascendv2__Designation__c>{des1, des2};
    
        // Build FormData
        HamGivingPagePaymentTabController.FormData fd = new HamGivingPagePaymentTabController.FormData();
        fd.contactId = c.Id;
        fd.paymentMethodUI = 'Credit Card';
        fd.paymentMethod = 'card';
        fd.amount = 100;
        fd.personName = 'Payment Donor';
        fd.personEmail = 'payment@example.com';
    
        // Create designation wrappers
        HamGivingPagePaymentTabController.Designation d1 = new HamGivingPagePaymentTabController.Designation();
        d1.id = des1.Id;
        d1.name = des1.Name;
        d1.amt = 60;
    
        HamGivingPagePaymentTabController.Designation d2 = new HamGivingPagePaymentTabController.Designation();
        d2.id = des2.Id;
        d2.name = des2.Name;
        d2.amt = 40;
    
        fd.selectedDesignations = new List<HamGivingPagePaymentTabController.Designation>{d1, d2};
    
        Test.startTest();
        HamGivingPagePaymentTabController.savePaymentTransaction(fd, 'Success');
        Test.stopTest();
    
        // Validate Payment Transaction
        Payment_Transaction__c pt = [
            SELECT Id, Constituent__c, Total_Amount__c, Transaction_Status__c
            FROM Payment_Transaction__c
            WHERE Constituent__c = :c.Id
            LIMIT 1
        ];
    
        System.assertEquals(c.Id, pt.Constituent__c);
        System.assertEquals(100, pt.Total_Amount__c);
        System.assertEquals('Success', pt.Transaction_Status__c);
    
        // Validate designation items
        List<Payment_Transaction_Designation_Item__c> items = [
            SELECT Id, Designation__c, Amount__c
            FROM Payment_Transaction_Designation_Item__c
            WHERE Payment_Transaction__c = :pt.Id
        ];
    
        System.assertEquals(2, items.size());
    }
}