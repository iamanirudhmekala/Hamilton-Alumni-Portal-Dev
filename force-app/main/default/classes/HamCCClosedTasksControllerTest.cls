/**
 * @description Unit tests for HamCCClosedTasksController
 */
@isTest
private class HamCCClosedTasksControllerTest {
    @testSetup
    static void setupData() {
        Account testAccount = new Account(Name = 'Test Account');
        insert testAccount;

        Contact testContact = new Contact(
            FirstName = 'Test',
            LastName = 'Contact',
            Email = 'test.contact@example.com'
        );
        insert testContact;

        List<Task> tasks = new List<Task>{
            // Closed tasks for contact
            new Task(
                Subject = 'Contact Task 1',
                WhoId = testContact.Id,
                Status = 'Completed',
                Priority = 'Normal',
                ActivityDate = Date.today()
            ),
            new Task(
                Subject = 'Contact Task 2',
                WhoId = testContact.Id,
                Status = 'Completed',
                Priority = 'Normal',
                ActivityDate = Date.today().addDays(-1)
            ),
            new Task(
                Subject = 'Contact Task 3',
                WhoId = testContact.Id,
                Status = 'Completed',
                Priority = 'Normal',
                ActivityDate = Date.today().addDays(-2)
            ),
            // Open task for contact (should be excluded)
            new Task(
                Subject = 'Contact Task Open',
                WhoId = testContact.Id,
                Status = 'Not Started',
                Priority = 'Normal',
                ActivityDate = Date.today().addDays(-3)
            ),
            // Closed tasks for account
            new Task(
                Subject = 'Account Task 1',
                WhatId = testAccount.Id,
                Status = 'Completed',
                Priority = 'Normal',
                ActivityDate = Date.today()
            ),
            new Task(
                Subject = 'Account Task 2',
                WhatId = testAccount.Id,
                Status = 'Completed',
                Priority = 'Normal',
                ActivityDate = Date.today().addDays(-1)
            )
        };

        insert tasks;
    }

    @isTest
    static void testGetClosedTasksWithContact() {
        Contact testContact = [
            SELECT Id
            FROM Contact
            WHERE Email = 'test.contact@example.com'
            LIMIT 1
        ];

        Test.startTest();
        List<Task> results = HamCCClosedTasksController.getClosedTasks(testContact.Id, true);
        Test.stopTest();

        System.assertEquals(3, results.size(), 'Should return only closed tasks for the contact');
        System.assertEquals('Contact Task 1', results[0].Subject, 'Should be sorted by ActivityDate DESC');
        System.assertEquals('Contact Task 3', results[2].Subject, 'Should be sorted by ActivityDate DESC');
    }

    @isTest
    static void testGetClosedTasksWithAccount() {
        Account testAccount = [
            SELECT Id
            FROM Account
            WHERE Name = 'Test Account'
            LIMIT 1
        ];

        Test.startTest();
        List<Task> results = HamCCClosedTasksController.getClosedTasks(testAccount.Id, false);
        Test.stopTest();

        System.assertEquals(2, results.size(), 'Should return only closed tasks for the account');
        System.assertEquals('Account Task 1', results[0].Subject, 'Should be sorted by ActivityDate DESC');
        System.assertEquals('Account Task 2', results[1].Subject, 'Should be sorted by ActivityDate DESC');
    }

    @isTest
    static void testSaveTask() {
        Contact testContact = [
            SELECT Id
            FROM Contact
            WHERE Email = 'test.contact@example.com'
            LIMIT 1
        ];

        Task taskToSave = new Task(
            Subject = 'New Task',
            WhoId = testContact.Id,
            Status = 'Completed',
            Priority = 'Normal',
            ActivityDate = Date.today()
        );

        Test.startTest();
        Task savedTask = HamCCClosedTasksController.saveTask(taskToSave);
        Test.stopTest();

        System.assertNotEquals(null, savedTask, 'Should return the saved task');
        System.assertNotEquals(null, savedTask.Id, 'Should have an ID after saving');
        System.assertEquals('New Task', savedTask.Subject, 'Should save the correct subject');
    }
}