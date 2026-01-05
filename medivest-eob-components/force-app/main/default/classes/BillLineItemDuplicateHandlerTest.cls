@isTest
private class BillLineItemDuplicateHandlerTest {

    @testSetup
    static void setupTestData() {
        // Create test Account (Entity)
        Account testProvider = new Account(Name = 'Test Provider');
        insert testProvider;

        // Create test Member Account
        Member_Account__c testMember = new Member_Account__c(Name = 'Test Member');
        insert testMember;

        // Create test Bill
        Bill__c testBill = new Bill__c(
            Name = 'Test Bill',
            Patient_Id__c = 'PATIENT123',
            Provider__c = testProvider.Id,
            Member_Account__c = testMember.Id,
            DateOfServiceFrom__c = Date.today(),
            DateOfServiceTo__c = Date.today()
        );
        insert testBill;
    }

    @isTest
    static void testExactMatchDetection() {
        Bill__c testBill = [SELECT Id FROM Bill__c LIMIT 1];

        // Create original line item
        Bill_Line_Item__c original = new Bill_Line_Item__c(
            Bill__c = testBill.Id,
            CPT_HCPCS_NDC__c = '99213',
            Charge__c = 150.00,
            Service_Start_Date__c = Date.today()
        );
        insert original;

        // Create exact duplicate
        Bill_Line_Item__c duplicate = new Bill_Line_Item__c(
            Bill__c = testBill.Id,
            CPT_HCPCS_NDC__c = '99213',
            Charge__c = 150.00,
            Service_Start_Date__c = Date.today()
        );

        Test.startTest();
        insert duplicate;
        Test.stopTest();

        // Verify exact match detected
        Bill_Line_Item__c result = [SELECT Duplicate_Status__c FROM Bill_Line_Item__c WHERE Id = :duplicate.Id];
        System.assertEquals('Exact', result.Duplicate_Status__c);
    }

    @isTest
    static void testPartialMatchDetection() {
        Bill__c testBill = [SELECT Id FROM Bill__c LIMIT 1];

        // Create original line item
        Bill_Line_Item__c original = new Bill_Line_Item__c(
            Bill__c = testBill.Id,
            CPT_HCPCS_NDC__c = '99213',
            Charge__c = 150.00,
            Service_Start_Date__c = Date.today()
        );
        insert original;

        // Create partial duplicate (different date, similar charge)
        Bill_Line_Item__c partial = new Bill_Line_Item__c(
            Bill__c = testBill.Id,
            CPT_HCPCS_NDC__c = '99213',
            Charge__c = 155.00, // Within 10% variance
            Service_Start_Date__c = Date.today().addDays(3) // Within 7 days
        );

        Test.startTest();
        insert partial;
        Test.stopTest();

        // Verify partial match detected
        Bill_Line_Item__c result = [SELECT Duplicate_Status__c FROM Bill_Line_Item__c WHERE Id = :partial.Id];
        System.assertEquals('Potential', result.Duplicate_Status__c);
    }

    @isTest
    static void testNoMatchDetection() {
        Bill__c testBill = [SELECT Id FROM Bill__c LIMIT 1];

        // Create line item with no duplicates
        Bill_Line_Item__c unique = new Bill_Line_Item__c(
            Bill__c = testBill.Id,
            CPT_HCPCS_NDC__c = '99214',
            Charge__c = 200.00,
            Service_Start_Date__c = Date.today()
        );

        Test.startTest();
        insert unique;
        Test.stopTest();

        // Verify no match detected
        Bill_Line_Item__c result = [SELECT Duplicate_Status__c FROM Bill_Line_Item__c WHERE Id = :unique.Id];
        System.assertEquals('None', result.Duplicate_Status__c);
    }
}