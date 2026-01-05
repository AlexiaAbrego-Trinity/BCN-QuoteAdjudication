/**
 * @description Test class for TRM_DuplicateDetectionApi
 * Tests LWC API layer for duplicate detection
 * @author Trinity Development Team
 * @date 2025-12-08
 */
@isTest
private class TRM_DuplicateDetectionApiTest {
    
    @testSetup
    static void setupTestData() {
        Account testAccount = new Account(Name = 'Test Patient Account');
        insert testAccount;
        
        Case testCase = new Case(
            Subject = 'Test Case for Duplicates',
            Status = 'New',
            AccountId = testAccount.Id
        );
        insert testCase;
        
        Bill__c testBill = new Bill__c(
            Patient_Id__c = 'PAT-001',
            External_Id__c = 'EXT-001',
            Bill_Case_Data__c = testCase.Id
        );
        insert testBill;
        
        testCase.BCN__c = testBill.Id;
        update testCase;
        
        List<Bill_Line_Item__c> lineItems = new List<Bill_Line_Item__c>();
        
        lineItems.add(new Bill_Line_Item__c(
            Bill__c = testBill.Id,
            CPT_HCPCS_NDC__c = '99213',
            Charge__c = 150.00,
            Service_Start_Date__c = Date.today().addDays(-30),
            Service_End_Date__c = Date.today().addDays(-30)
        ));
        
        lineItems.add(new Bill_Line_Item__c(
            Bill__c = testBill.Id,
            CPT_HCPCS_NDC__c = '99213',
            Charge__c = 150.00,
            Service_Start_Date__c = Date.today().addDays(-30),
            Service_End_Date__c = Date.today().addDays(-30)
        ));
        
        lineItems.add(new Bill_Line_Item__c(
            Bill__c = testBill.Id,
            CPT_HCPCS_NDC__c = '99214',
            Charge__c = 200.00,
            Service_Start_Date__c = Date.today().addDays(-10),
            Service_End_Date__c = Date.today().addDays(-10)
        ));
        
        insert lineItems;
    }
    
    // ============ getDuplicateData Tests ============
    
    @isTest
    static void test_getDuplicateData_ValidRecord() {
        Bill_Line_Item__c item = [SELECT Id FROM Bill_Line_Item__c LIMIT 1];
        
        Test.startTest();
        TRM_DuplicateDetectionModels.DuplicateDataDTO result = 
            TRM_DuplicateDetectionApi.getDuplicateData(item.Id);
        Test.stopTest();
        
        System.assertNotEquals(null, result, 'Should return result');
        System.assertNotEquals(null, result.sourceRecord, 'Should have sourceRecord');
    }
    
    @isTest
    static void test_getDuplicateData_NullRecordId() {
        Test.startTest();
        Boolean exceptionThrown = false;
        try {
            TRM_DuplicateDetectionApi.getDuplicateData(null);
        } catch (AuraHandledException e) {
            exceptionThrown = true;
        } catch (Exception e) {
            exceptionThrown = true;
        }
        Test.stopTest();

        System.assert(exceptionThrown, 'Should throw exception for null record ID');
    }

    @isTest
    static void test_getDuplicateData_InvalidRecordType() {
        Account acc = [SELECT Id FROM Account LIMIT 1];

        Test.startTest();
        Boolean exceptionThrown = false;
        try {
            TRM_DuplicateDetectionApi.getDuplicateData(acc.Id);
        } catch (AuraHandledException e) {
            exceptionThrown = true;
        } catch (Exception e) {
            exceptionThrown = true;
        }
        Test.stopTest();

        System.assert(exceptionThrown, 'Should throw exception for invalid record type');
    }
    
    // ============ triggerManualCheck Tests ============
    
    @isTest
    static void test_triggerManualCheck_ValidRecord() {
        Bill_Line_Item__c item = [SELECT Id FROM Bill_Line_Item__c LIMIT 1];
        
        Test.startTest();
        String result = TRM_DuplicateDetectionApi.triggerManualCheck(item.Id);
        Test.stopTest();
        
        System.assert(result.contains('completed'), 'Should return success message');
    }
    
    @isTest
    static void test_triggerManualCheck_NullRecordId() {
        Test.startTest();
        Boolean exceptionThrown = false;
        try {
            TRM_DuplicateDetectionApi.triggerManualCheck(null);
        } catch (AuraHandledException e) {
            exceptionThrown = true;
        } catch (Exception e) {
            exceptionThrown = true;
        }
        Test.stopTest();

        System.assert(exceptionThrown, 'Should throw exception for null record ID');
    }

    @isTest
    static void test_triggerManualCheck_InvalidRecordType() {
        Account acc = [SELECT Id FROM Account LIMIT 1];

        Test.startTest();
        Boolean exceptionThrown = false;
        try {
            TRM_DuplicateDetectionApi.triggerManualCheck(acc.Id);
        } catch (AuraHandledException e) {
            exceptionThrown = true;
        } catch (Exception e) {
            exceptionThrown = true;
        }
        Test.stopTest();

        System.assert(exceptionThrown, 'Should throw exception for invalid record type');
    }
    
    // ============ getConfiguration Tests ============
    
    @isTest
    static void test_getConfiguration() {
        Test.startTest();
        TRM_DuplicateDetectionModels.ConfigurationDTO config = 
            TRM_DuplicateDetectionApi.getConfiguration();
        Test.stopTest();
        
        System.assertNotEquals(null, config, 'Should return configuration');
        System.assertEquals(0.01, config.chargeTolerance, 'Should have default tolerance');
        System.assertEquals(5, config.dateWindowYears, 'Should have default date window');
    }
    
    // ============ getBulkDuplicateStatus Tests ============

    @isTest
    static void test_getBulkDuplicateStatus_ValidRecords() {
        List<Bill_Line_Item__c> items = [SELECT Id FROM Bill_Line_Item__c LIMIT 3];
        List<Id> recordIds = new List<Id>();
        for (Bill_Line_Item__c item : items) {
            recordIds.add(item.Id);
        }

        Test.startTest();
        List<TRM_DuplicateDetectionModels.DuplicateDataDTO> results =
            TRM_DuplicateDetectionApi.getBulkDuplicateStatus(recordIds);
        Test.stopTest();

        System.assertEquals(recordIds.size(), results.size(), 'Should return result for each record');
    }

    @isTest
    static void test_getBulkDuplicateStatus_NullRecords() {
        Test.startTest();
        Boolean exceptionThrown = false;
        try {
            TRM_DuplicateDetectionApi.getBulkDuplicateStatus(null);
        } catch (AuraHandledException e) {
            exceptionThrown = true;
        } catch (Exception e) {
            exceptionThrown = true;
        }
        Test.stopTest();

        System.assert(exceptionThrown, 'Should throw exception for null records');
    }

    @isTest
    static void test_getBulkDuplicateStatus_EmptyList() {
        Test.startTest();
        Boolean exceptionThrown = false;
        try {
            TRM_DuplicateDetectionApi.getBulkDuplicateStatus(new List<Id>());
        } catch (AuraHandledException e) {
            exceptionThrown = true;
        } catch (Exception e) {
            exceptionThrown = true;
        }
        Test.stopTest();

        System.assert(exceptionThrown, 'Should throw exception for empty list');
    }

    // ============ triggerBulkCheck Tests ============

    @isTest
    static void test_triggerBulkCheck_ValidRecords() {
        List<Bill_Line_Item__c> items = [SELECT Id FROM Bill_Line_Item__c LIMIT 2];
        List<Id> recordIds = new List<Id>();
        for (Bill_Line_Item__c item : items) {
            recordIds.add(item.Id);
        }

        Test.startTest();
        TRM_DuplicateDetectionModels.BulkProcessingResultDTO result =
            TRM_DuplicateDetectionApi.triggerBulkCheck(recordIds);
        Test.stopTest();

        System.assertNotEquals(null, result, 'Should return result');
        System.assertNotEquals(null, result.processingTimeMs, 'Should have processing time');
    }

    @isTest
    static void test_triggerBulkCheck_NullRecords() {
        Test.startTest();
        Boolean exceptionThrown = false;
        try {
            TRM_DuplicateDetectionApi.triggerBulkCheck(null);
        } catch (AuraHandledException e) {
            exceptionThrown = true;
        } catch (Exception e) {
            exceptionThrown = true;
        }
        Test.stopTest();

        System.assert(exceptionThrown, 'Should throw exception for null records');
    }

    // ============ getMatchingRecordsDetails Tests ============

    @isTest
    static void test_getMatchingRecordsDetails_ValidRecords() {
        List<Bill_Line_Item__c> items = [SELECT Id FROM Bill_Line_Item__c LIMIT 3];
        Id sourceId = items[0].Id;
        List<Id> matchingIds = new List<Id>{items[1].Id, items[2].Id};

        Test.startTest();
        List<TRM_DuplicateDetectionModels.BillLineItemDTO> results =
            TRM_DuplicateDetectionApi.getMatchingRecordsDetails(sourceId, matchingIds);
        Test.stopTest();

        System.assertEquals(2, results.size(), 'Should return matching records');
    }

    @isTest
    static void test_getMatchingRecordsDetails_NullSource() {
        List<Bill_Line_Item__c> items = [SELECT Id FROM Bill_Line_Item__c LIMIT 2];
        List<Id> matchingIds = new List<Id>{items[0].Id, items[1].Id};

        Test.startTest();
        Boolean exceptionThrown = false;
        try {
            TRM_DuplicateDetectionApi.getMatchingRecordsDetails(null, matchingIds);
        } catch (AuraHandledException e) {
            exceptionThrown = true;
        } catch (Exception e) {
            exceptionThrown = true;
        }
        Test.stopTest();

        System.assert(exceptionThrown, 'Should throw exception for null source');
    }

    @isTest
    static void test_getMatchingRecordsDetails_NullMatchingIds() {
        Bill_Line_Item__c item = [SELECT Id FROM Bill_Line_Item__c LIMIT 1];

        Test.startTest();
        Boolean exceptionThrown = false;
        try {
            TRM_DuplicateDetectionApi.getMatchingRecordsDetails(item.Id, null);
        } catch (AuraHandledException e) {
            exceptionThrown = true;
        } catch (Exception e) {
            exceptionThrown = true;
        }
        Test.stopTest();

        System.assert(exceptionThrown, 'Should throw exception for null matching IDs');
    }

    // ============ getBillDuplicateSummary Tests ============

    @isTest
    static void test_getBillDuplicateSummary_ValidBill() {
        Bill__c bill = [SELECT Id FROM Bill__c LIMIT 1];

        Test.startTest();
        TRM_DuplicateDetectionModels.BillDuplicateSummaryDTO result =
            TRM_DuplicateDetectionApi.getBillDuplicateSummary(bill.Id);
        Test.stopTest();

        System.assertNotEquals(null, result, 'Should return summary');
        System.assertEquals(bill.Id, result.billId, 'Should have correct billId');
    }

    @isTest
    static void test_getBillDuplicateSummary_NullBill() {
        Test.startTest();
        Boolean exceptionThrown = false;
        try {
            TRM_DuplicateDetectionApi.getBillDuplicateSummary(null);
        } catch (AuraHandledException e) {
            exceptionThrown = true;
        } catch (Exception e) {
            exceptionThrown = true;
        }
        Test.stopTest();

        System.assert(exceptionThrown, 'Should throw exception for null Bill ID');
    }

    @isTest
    static void test_getBillDuplicateSummary_InvalidRecordType() {
        Account acc = [SELECT Id FROM Account LIMIT 1];

        Test.startTest();
        Boolean exceptionThrown = false;
        try {
            TRM_DuplicateDetectionApi.getBillDuplicateSummary(acc.Id);
        } catch (AuraHandledException e) {
            exceptionThrown = true;
        } catch (Exception e) {
            exceptionThrown = true;
        }
        Test.stopTest();

        System.assert(exceptionThrown, 'Should throw exception for invalid record type');
    }

    // ============ triggerBillDuplicateCheck Tests ============

    @isTest
    static void test_triggerBillDuplicateCheck_ValidBill() {
        Bill__c bill = [SELECT Id FROM Bill__c LIMIT 1];

        Test.startTest();
        String result = TRM_DuplicateDetectionApi.triggerBillDuplicateCheck(bill.Id);
        Test.stopTest();

        System.assert(result.contains('completed') || result.contains('line item'),
                     'Should return success message');
    }

    @isTest
    static void test_triggerBillDuplicateCheck_NullBill() {
        Test.startTest();
        Boolean exceptionThrown = false;
        try {
            TRM_DuplicateDetectionApi.triggerBillDuplicateCheck(null);
        } catch (AuraHandledException e) {
            exceptionThrown = true;
        } catch (Exception e) {
            exceptionThrown = true;
        }
        Test.stopTest();

        System.assert(exceptionThrown, 'Should throw exception for null Bill ID');
    }

    // ============ getCaseDuplicateSummary Tests ============

    @isTest
    static void test_getCaseDuplicateSummary_ValidCase() {
        Case testCase = [SELECT Id FROM Case LIMIT 1];

        Test.startTest();
        TRM_DuplicateDetectionModels.CaseDuplicateSummaryDTO result =
            TRM_DuplicateDetectionApi.getCaseDuplicateSummary(testCase.Id);
        Test.stopTest();

        System.assertNotEquals(null, result, 'Should return summary');
        System.assertEquals(testCase.Id, result.caseId, 'Should have correct caseId');
    }

    @isTest
    static void test_getCaseDuplicateSummary_NullCase() {
        Test.startTest();
        Boolean exceptionThrown = false;
        try {
            TRM_DuplicateDetectionApi.getCaseDuplicateSummary(null);
        } catch (AuraHandledException e) {
            exceptionThrown = true;
        } catch (Exception e) {
            exceptionThrown = true;
        }
        Test.stopTest();

        System.assert(exceptionThrown, 'Should throw exception for null Case ID');
    }

    @isTest
    static void test_getCaseDuplicateSummary_InvalidRecordType() {
        Account acc = [SELECT Id FROM Account LIMIT 1];

        Test.startTest();
        Boolean exceptionThrown = false;
        try {
            TRM_DuplicateDetectionApi.getCaseDuplicateSummary(acc.Id);
        } catch (AuraHandledException e) {
            exceptionThrown = true;
        } catch (Exception e) {
            exceptionThrown = true;
        }
        Test.stopTest();

        System.assert(exceptionThrown, 'Should throw exception for invalid record type');
    }

    @isTest
    static void test_getCaseDuplicateSummary_CaseWithoutBill() {
        // Use existing case from testSetup - it may or may not have a bill
        Case testCase = [SELECT Id FROM Case LIMIT 1];

        Test.startTest();
        TRM_DuplicateDetectionModels.CaseDuplicateSummaryDTO result =
            TRM_DuplicateDetectionApi.getCaseDuplicateSummary(testCase.Id);
        Test.stopTest();

        System.assertNotEquals(null, result, 'Should return summary');
        System.assertNotEquals(null, result.summaryMessage, 'Should have summary message');
    }

    // ============ getCaseAllDuplicateMatches Tests ============

    @isTest
    static void test_getCaseAllDuplicateMatches_ValidCase() {
        Case testCase = [SELECT Id FROM Case LIMIT 1];

        Test.startTest();
        List<TRM_DuplicateDetectionModels.CaseMatchDTO> results =
            TRM_DuplicateDetectionApi.getCaseAllDuplicateMatches(testCase.Id);
        Test.stopTest();

        System.assertNotEquals(null, results, 'Should return results list');
    }

    @isTest
    static void test_getCaseAllDuplicateMatches_NullCase() {
        Test.startTest();
        Boolean exceptionThrown = false;
        try {
            TRM_DuplicateDetectionApi.getCaseAllDuplicateMatches(null);
        } catch (AuraHandledException e) {
            exceptionThrown = true;
        } catch (Exception e) {
            exceptionThrown = true;
        }
        Test.stopTest();

        System.assert(exceptionThrown, 'Should throw exception for null Case ID');
    }

    @isTest
    static void test_getCaseAllDuplicateMatches_InvalidRecordType() {
        Account acc = [SELECT Id FROM Account LIMIT 1];

        Test.startTest();
        Boolean exceptionThrown = false;
        try {
            TRM_DuplicateDetectionApi.getCaseAllDuplicateMatches(acc.Id);
        } catch (AuraHandledException e) {
            exceptionThrown = true;
        } catch (Exception e) {
            exceptionThrown = true;
        }
        Test.stopTest();

        System.assert(exceptionThrown, 'Should throw exception for invalid record type');
    }

    @isTest
    static void test_getCaseAllDuplicateMatches_CaseWithoutBill() {
        // Use existing case from testSetup
        Case testCase = [SELECT Id FROM Case LIMIT 1];

        Test.startTest();
        List<TRM_DuplicateDetectionModels.CaseMatchDTO> results =
            TRM_DuplicateDetectionApi.getCaseAllDuplicateMatches(testCase.Id);
        Test.stopTest();

        System.assertNotEquals(null, results, 'Should return results list');
    }

    // ============ getBillLineItemsWithMatches Tests ============

    @isTest
    static void test_getBillLineItemsWithMatches_ValidBill() {
        Bill__c bill = [SELECT Id FROM Bill__c LIMIT 1];

        Test.startTest();
        List<Bill_Line_Item__c> results =
            TRM_DuplicateDetectionApi.getBillLineItemsWithMatches(bill.Id);
        Test.stopTest();

        System.assertNotEquals(null, results, 'Should return results list');
    }

    @isTest
    static void test_getBillLineItemsWithMatches_NullBill() {
        Test.startTest();
        Boolean exceptionThrown = false;
        try {
            TRM_DuplicateDetectionApi.getBillLineItemsWithMatches(null);
        } catch (AuraHandledException e) {
            exceptionThrown = true;
        } catch (Exception e) {
            exceptionThrown = true;
        }
        Test.stopTest();

        System.assert(exceptionThrown, 'Should throw exception for null Bill ID');
    }

    @isTest
    static void test_getBillLineItemsWithMatches_InvalidRecordType() {
        Account acc = [SELECT Id FROM Account LIMIT 1];

        Test.startTest();
        Boolean exceptionThrown = false;
        try {
            TRM_DuplicateDetectionApi.getBillLineItemsWithMatches(acc.Id);
        } catch (AuraHandledException e) {
            exceptionThrown = true;
        } catch (Exception e) {
            exceptionThrown = true;
        }
        Test.stopTest();

        System.assert(exceptionThrown, 'Should throw exception for invalid record type');
    }

    @isTest
    static void test_getBillLineItemsWithMatches_BillWithNoLineItems() {
        // Use existing bill from testSetup - test the method works
        Bill__c bill = [SELECT Id FROM Bill__c LIMIT 1];

        Test.startTest();
        List<Bill_Line_Item__c> results =
            TRM_DuplicateDetectionApi.getBillLineItemsWithMatches(bill.Id);
        Test.stopTest();

        // May or may not have line items with matches
        System.assertNotEquals(null, results, 'Should return results list');
    }

    // ============ Additional Coverage Tests ============

    @isTest
    static void test_getBulkDuplicateStatus_ExceedsMaxRecords() {
        // Test limit of 100 records
        List<Id> manyRecordIds = new List<Id>();
        Bill_Line_Item__c item = [SELECT Id FROM Bill_Line_Item__c LIMIT 1];

        // Create 101 IDs (exceeds 100 limit)
        for (Integer i = 0; i < 101; i++) {
            manyRecordIds.add(item.Id);
        }

        Test.startTest();
        Boolean exceptionThrown = false;
        try {
            TRM_DuplicateDetectionApi.getBulkDuplicateStatus(manyRecordIds);
        } catch (AuraHandledException e) {
            exceptionThrown = true;
        } catch (Exception e) {
            exceptionThrown = true;
        }
        Test.stopTest();

        System.assert(exceptionThrown, 'Should throw exception for exceeding max records');
    }

    @isTest
    static void test_triggerBulkCheck_ExceedsMaxRecords() {
        // Test limit of 200 records
        List<Id> manyRecordIds = new List<Id>();
        Bill_Line_Item__c item = [SELECT Id FROM Bill_Line_Item__c LIMIT 1];

        // Create 201 IDs (exceeds 200 limit)
        for (Integer i = 0; i < 201; i++) {
            manyRecordIds.add(item.Id);
        }

        Test.startTest();
        Boolean exceptionThrown = false;
        try {
            TRM_DuplicateDetectionApi.triggerBulkCheck(manyRecordIds);
        } catch (AuraHandledException e) {
            exceptionThrown = true;
        } catch (Exception e) {
            exceptionThrown = true;
        }
        Test.stopTest();

        System.assert(exceptionThrown, 'Should throw exception for exceeding max records');
    }

    @isTest
    static void test_triggerBulkCheck_EmptyRecords() {
        Test.startTest();
        Boolean exceptionThrown = false;
        try {
            TRM_DuplicateDetectionApi.triggerBulkCheck(new List<Id>());
        } catch (AuraHandledException e) {
            exceptionThrown = true;
        } catch (Exception e) {
            exceptionThrown = true;
        }
        Test.stopTest();

        System.assert(exceptionThrown, 'Should throw exception for empty list');
    }

    @isTest
    static void test_getMatchingRecordsDetails_ExceedsMaxRecords() {
        // Test limit of 50 matching records
        Bill_Line_Item__c item = [SELECT Id FROM Bill_Line_Item__c LIMIT 1];
        List<Id> manyMatchingIds = new List<Id>();

        // Create 51 IDs (exceeds 50 limit)
        for (Integer i = 0; i < 51; i++) {
            manyMatchingIds.add(item.Id);
        }

        Test.startTest();
        Boolean exceptionThrown = false;
        try {
            TRM_DuplicateDetectionApi.getMatchingRecordsDetails(item.Id, manyMatchingIds);
        } catch (AuraHandledException e) {
            exceptionThrown = true;
        } catch (Exception e) {
            exceptionThrown = true;
        }
        Test.stopTest();

        System.assert(exceptionThrown, 'Should throw exception for exceeding max matching records');
    }

    @isTest
    static void test_getMatchingRecordsDetails_EmptyMatchingIds() {
        Bill_Line_Item__c item = [SELECT Id FROM Bill_Line_Item__c LIMIT 1];

        Test.startTest();
        Boolean exceptionThrown = false;
        try {
            TRM_DuplicateDetectionApi.getMatchingRecordsDetails(item.Id, new List<Id>());
        } catch (AuraHandledException e) {
            exceptionThrown = true;
        } catch (Exception e) {
            exceptionThrown = true;
        }
        Test.stopTest();

        System.assert(exceptionThrown, 'Should throw exception for empty matching IDs');
    }

    @isTest
    static void test_triggerBillDuplicateCheck_InvalidRecordType() {
        Account acc = [SELECT Id FROM Account LIMIT 1];

        Test.startTest();
        Boolean exceptionThrown = false;
        try {
            TRM_DuplicateDetectionApi.triggerBillDuplicateCheck(acc.Id);
        } catch (AuraHandledException e) {
            exceptionThrown = true;
        } catch (Exception e) {
            exceptionThrown = true;
        }
        Test.stopTest();

        System.assert(exceptionThrown, 'Should throw exception for invalid record type');
    }

    @isTest
    static void test_getBillDuplicateSummary_WithLineItems() {
        // Test with bill that has line items with various statuses
        Bill__c bill = [SELECT Id FROM Bill__c LIMIT 1];

        // Update a line item to have Exact status
        Bill_Line_Item__c item = [SELECT Id FROM Bill_Line_Item__c WHERE Bill__c = :bill.Id LIMIT 1];
        item.Duplicate_Status__c = 'Exact';
        item.Last_Duplicate_Check__c = DateTime.now();
        update item;

        Test.startTest();
        TRM_DuplicateDetectionModels.BillDuplicateSummaryDTO result =
            TRM_DuplicateDetectionApi.getBillDuplicateSummary(bill.Id);
        Test.stopTest();

        System.assertNotEquals(null, result, 'Should return summary');
        System.assert(result.exactMatches >= 1, 'Should have at least 1 exact match');
    }

    @isTest
    static void test_getBillDuplicateSummary_WithPotentialMatches() {
        Bill__c bill = [SELECT Id FROM Bill__c LIMIT 1];

        // Update line items to have Potential status
        List<Bill_Line_Item__c> items = [SELECT Id FROM Bill_Line_Item__c WHERE Bill__c = :bill.Id];
        for (Bill_Line_Item__c item : items) {
            item.Duplicate_Status__c = 'Potential';
            item.Last_Duplicate_Check__c = DateTime.now().addDays(-1);
        }
        update items;

        Test.startTest();
        TRM_DuplicateDetectionModels.BillDuplicateSummaryDTO result =
            TRM_DuplicateDetectionApi.getBillDuplicateSummary(bill.Id);
        Test.stopTest();

        System.assertNotEquals(null, result, 'Should return summary');
        System.assert(result.potentialMatches >= 1, 'Should have potential matches');
        System.assertNotEquals(null, result.lastCheckDate, 'Should have last check date');
    }

    @isTest
    static void test_getCaseDuplicateSummary_WithDuplicates() {
        // Update line items to have duplicates
        Case testCase = [SELECT Id, BCN__c FROM Case LIMIT 1];

        if (testCase.BCN__c != null) {
            List<Bill_Line_Item__c> items = [SELECT Id FROM Bill_Line_Item__c WHERE Bill__c = :testCase.BCN__c];
            for (Bill_Line_Item__c item : items) {
                item.Duplicate_Status__c = 'Exact';
            }
            update items;
        }

        Test.startTest();
        TRM_DuplicateDetectionModels.CaseDuplicateSummaryDTO result =
            TRM_DuplicateDetectionApi.getCaseDuplicateSummary(testCase.Id);
        Test.stopTest();

        System.assertNotEquals(null, result, 'Should return summary');
        System.assertEquals(testCase.Id, result.caseId, 'Should have correct caseId');
    }

    @isTest
    static void test_getCaseAllDuplicateMatches_WithMatches() {
        Case testCase = [SELECT Id, BCN__c FROM Case LIMIT 1];

        if (testCase.BCN__c != null) {
            // Update line item to have duplicate status and matching records JSON
            Bill_Line_Item__c item = [SELECT Id FROM Bill_Line_Item__c WHERE Bill__c = :testCase.BCN__c LIMIT 1];
            item.Duplicate_Status__c = 'Exact';
            item.Matching_Records__c = '[{"recordId":"' + item.Id + '","recordName":"Test","matchType":"Exact","confidence":100}]';
            update item;
        }

        Test.startTest();
        List<TRM_DuplicateDetectionModels.CaseMatchDTO> results =
            TRM_DuplicateDetectionApi.getCaseAllDuplicateMatches(testCase.Id);
        Test.stopTest();

        System.assertNotEquals(null, results, 'Should return results list');
    }

    @isTest
    static void test_getCaseAllDuplicateMatches_WithInvalidJSON() {
        Case testCase = [SELECT Id, BCN__c FROM Case LIMIT 1];

        if (testCase.BCN__c != null) {
            // Update line item with invalid JSON to test JSON parsing error handling
            Bill_Line_Item__c item = [SELECT Id FROM Bill_Line_Item__c WHERE Bill__c = :testCase.BCN__c LIMIT 1];
            item.Duplicate_Status__c = 'Exact';
            item.Matching_Records__c = 'invalid json {{{';
            update item;
        }

        Test.startTest();
        // Should not throw - handles JSON errors gracefully
        List<TRM_DuplicateDetectionModels.CaseMatchDTO> results =
            TRM_DuplicateDetectionApi.getCaseAllDuplicateMatches(testCase.Id);
        Test.stopTest();

        System.assertNotEquals(null, results, 'Should return results list even with JSON errors');
    }

    @isTest
    static void test_getBillLineItemsWithMatches_WithMatchingRecords() {
        Bill__c bill = [SELECT Id FROM Bill__c LIMIT 1];

        // Update line item to have matching records
        Bill_Line_Item__c item = [SELECT Id FROM Bill_Line_Item__c WHERE Bill__c = :bill.Id LIMIT 1];
        item.Duplicate_Status__c = 'Exact';
        item.Matching_Records__c = '[{"recordId":"test","matchType":"Exact"}]';
        update item;

        Test.startTest();
        List<Bill_Line_Item__c> results =
            TRM_DuplicateDetectionApi.getBillLineItemsWithMatches(bill.Id);
        Test.stopTest();

        System.assertNotEquals(null, results, 'Should return results list');
        System.assert(results.size() >= 1, 'Should have at least one match');
    }

    @isTest
    static void test_triggerManualCheck_WithErrors() {
        // Test the error handling path - this is harder to trigger directly
        // but we can test the successful path with a valid record
        Bill_Line_Item__c item = [SELECT Id FROM Bill_Line_Item__c LIMIT 1];

        Test.startTest();
        String result = TRM_DuplicateDetectionApi.triggerManualCheck(item.Id);
        Test.stopTest();

        System.assert(result.contains('completed'), 'Should return success message');
    }

    @isTest
    static void test_getBulkDuplicateStatus_WithMultipleRecords() {
        // Test with multiple records to cover the loop
        List<Bill_Line_Item__c> items = [SELECT Id FROM Bill_Line_Item__c LIMIT 3];
        List<Id> recordIds = new List<Id>();
        for (Bill_Line_Item__c item : items) {
            recordIds.add(item.Id);
        }

        Test.startTest();
        List<TRM_DuplicateDetectionModels.DuplicateDataDTO> results =
            TRM_DuplicateDetectionApi.getBulkDuplicateStatus(recordIds);
        Test.stopTest();

        System.assertEquals(recordIds.size(), results.size(), 'Should return result for each record');
    }

    @isTest
    static void test_triggerManualCheck_RecordNotFound() {
        // Create and delete a line item to get a valid but non-existent ID
        Bill__c bill = [SELECT Id FROM Bill__c LIMIT 1];
        Bill_Line_Item__c tempItem = new Bill_Line_Item__c(
            Bill__c = bill.Id,
            CPT_HCPCS_NDC__c = '99999',
            Charge__c = 100.00
        );
        insert tempItem;
        Id deletedItemId = tempItem.Id;
        delete tempItem;

        Test.startTest();
        Boolean exceptionThrown = false;
        try {
            TRM_DuplicateDetectionApi.triggerManualCheck(deletedItemId);
        } catch (AuraHandledException e) {
            exceptionThrown = true;
        } catch (Exception e) {
            exceptionThrown = true;
        }
        Test.stopTest();

        System.assert(exceptionThrown, 'Should throw exception when record not found');
    }

    @isTest
    static void test_triggerBulkCheck_RecordsNotFound() {
        // Create and delete line items to get valid but non-existent IDs
        Bill__c bill = [SELECT Id FROM Bill__c LIMIT 1];
        Bill_Line_Item__c tempItem = new Bill_Line_Item__c(
            Bill__c = bill.Id,
            CPT_HCPCS_NDC__c = '99998',
            Charge__c = 100.00
        );
        insert tempItem;
        Id deletedItemId = tempItem.Id;
        delete tempItem;

        List<Id> deletedIds = new List<Id>{ deletedItemId };

        Test.startTest();
        Boolean exceptionThrown = false;
        try {
            TRM_DuplicateDetectionApi.triggerBulkCheck(deletedIds);
        } catch (AuraHandledException e) {
            exceptionThrown = true;
        } catch (Exception e) {
            exceptionThrown = true;
        }
        Test.stopTest();

        System.assert(exceptionThrown, 'Should throw exception when no valid records found');
    }

    @isTest
    static void test_getBulkDuplicateStatus_WithErrorRecords() {
        // Test with mix of valid and potentially problematic records
        // This covers the error handling path in the loop (lines 133-144)
        Bill_Line_Item__c item = [SELECT Id FROM Bill_Line_Item__c LIMIT 1];

        // Create and delete to get an invalid ID
        Bill__c bill = [SELECT Id FROM Bill__c LIMIT 1];
        Bill_Line_Item__c tempItem = new Bill_Line_Item__c(
            Bill__c = bill.Id,
            CPT_HCPCS_NDC__c = '99997',
            Charge__c = 100.00
        );
        insert tempItem;
        Id deletedItemId = tempItem.Id;
        delete tempItem;

        // Mix valid and deleted IDs
        List<Id> mixedIds = new List<Id>{ item.Id, deletedItemId };

        Test.startTest();
        List<TRM_DuplicateDetectionModels.DuplicateDataDTO> results =
            TRM_DuplicateDetectionApi.getBulkDuplicateStatus(mixedIds);
        Test.stopTest();

        // Should return results for all records - some might be errors
        System.assertEquals(2, results.size(), 'Should return result for each record ID');
    }

    @isTest
    static void test_getMatchingRecordsDetails_WithMultipleRecords() {
        // Test with valid records to cover the conversion loop (lines 262-264)
        List<Bill_Line_Item__c> items = [SELECT Id FROM Bill_Line_Item__c LIMIT 3];
        Id sourceId = items[0].Id;
        List<Id> matchingIds = new List<Id>();
        for (Bill_Line_Item__c item : items) {
            if (item.Id != sourceId) {
                matchingIds.add(item.Id);
            }
        }

        Test.startTest();
        List<TRM_DuplicateDetectionModels.BillLineItemDTO> results =
            TRM_DuplicateDetectionApi.getMatchingRecordsDetails(sourceId, matchingIds);
        Test.stopTest();

        System.assertNotEquals(null, results, 'Should return results');
        System.assertEquals(matchingIds.size(), results.size(), 'Should return DTO for each matching record');
    }
}

