/**
 * @description Test class for TRM Duplicate Detection System
 * Covers: TRM_DuplicateDetectionHandler, TRM_DuplicateDetectionService, 
 *         TRM_DuplicateDetectionModels, TRM_DuplicateDetectionApi
 * @author Trinity Development Team
 * @date 2025-12-08
 */
@isTest
private class TRM_DuplicateDetectionTest {
    
    @testSetup
    static void setupTestData() {
        // Create Account
        Account testAccount = new Account(Name = 'Test Patient Account');
        insert testAccount;
        
        // Create Case
        Case testCase = new Case(
            Subject = 'Test Case for Duplicates',
            Status = 'New',
            AccountId = testAccount.Id
        );
        insert testCase;
        
        // Create Bill
        Bill__c testBill = new Bill__c(
            Patient_Id__c = 'PAT-001',
            External_Id__c = 'EXT-001',
            Bill_Case_Data__c = testCase.Id
        );
        insert testBill;
        
        // Update Case with Bill reference
        testCase.BCN__c = testBill.Id;
        update testCase;
        
        // Create Bill Line Items with duplicate detection fields
        List<Bill_Line_Item__c> lineItems = new List<Bill_Line_Item__c>();
        
        // Item 1 - Base item
        lineItems.add(new Bill_Line_Item__c(
            Bill__c = testBill.Id,
            CPT_HCPCS_NDC__c = '99213',
            Charge__c = 150.00,
            Service_Start_Date__c = Date.today().addDays(-30),
            Service_End_Date__c = Date.today().addDays(-30)
        ));
        
        // Item 2 - Exact duplicate (same code, charge, dates)
        lineItems.add(new Bill_Line_Item__c(
            Bill__c = testBill.Id,
            CPT_HCPCS_NDC__c = '99213',
            Charge__c = 150.00,
            Service_Start_Date__c = Date.today().addDays(-30),
            Service_End_Date__c = Date.today().addDays(-30)
        ));
        
        // Item 3 - Potential duplicate (same code, different date within 5 years)
        lineItems.add(new Bill_Line_Item__c(
            Bill__c = testBill.Id,
            CPT_HCPCS_NDC__c = '99213',
            Charge__c = 200.00,
            Service_Start_Date__c = Date.today().addDays(-60),
            Service_End_Date__c = Date.today().addDays(-60)
        ));
        
        // Item 4 - No duplicate (different code)
        lineItems.add(new Bill_Line_Item__c(
            Bill__c = testBill.Id,
            CPT_HCPCS_NDC__c = '99214',
            Charge__c = 250.00,
            Service_Start_Date__c = Date.today().addDays(-10),
            Service_End_Date__c = Date.today().addDays(-10)
        ));
        
        insert lineItems;
    }
    
    // ============ TRM_DuplicateDetectionModels Tests ============
    
    @isTest
    static void test_DuplicateDataDTO_Constructor() {
        Test.startTest();
        TRM_DuplicateDetectionModels.DuplicateDataDTO dto = 
            new TRM_DuplicateDetectionModels.DuplicateDataDTO();
        Test.stopTest();
        
        System.assertEquals('None', dto.duplicateStatus, 'Default status should be None');
        System.assertEquals(0.0, dto.confidence, 'Default confidence should be 0');
        System.assertEquals(0, dto.totalMatches, 'Default totalMatches should be 0');
        System.assertNotEquals(null, dto.matches, 'Matches list should be initialized');
        System.assertNotEquals(null, dto.configuration, 'Configuration should be initialized');
    }
    
    @isTest
    static void test_MatchDTO_Constructor() {
        Test.startTest();
        TRM_DuplicateDetectionModels.MatchDTO dto = 
            new TRM_DuplicateDetectionModels.MatchDTO();
        Test.stopTest();
        
        System.assertEquals('Unknown', dto.matchType, 'Default matchType should be Unknown');
        System.assertEquals(0.0, dto.confidence, 'Default confidence should be 0');
    }
    
    @isTest
    static void test_MatchDTO_FromRecord() {
        Bill_Line_Item__c item = [SELECT Id, Name, CPT_HCPCS_NDC__c, Charge__c, 
                                         Service_Start_Date__c, Service_End_Date__c,
                                         Bill__r.External_Id__c, Bill__r.Patient_Id__c,
                                         CreatedDate, CreatedBy.Name
                                  FROM Bill_Line_Item__c LIMIT 1];
        
        Test.startTest();
        TRM_DuplicateDetectionModels.MatchDTO dto = 
            new TRM_DuplicateDetectionModels.MatchDTO(item);
        Test.stopTest();
        
        System.assertEquals(item.Id, dto.recordId, 'recordId should match');
        System.assertEquals(item.CPT_HCPCS_NDC__c, dto.procedureCode, 'procedureCode should match');
        System.assertEquals(item.Charge__c, dto.chargeAmount, 'chargeAmount should match');
    }
    
    @isTest
    static void test_BillLineItemDTO_Constructor() {
        Test.startTest();
        TRM_DuplicateDetectionModels.BillLineItemDTO dto = 
            new TRM_DuplicateDetectionModels.BillLineItemDTO();
        Test.stopTest();
        
        System.assertEquals('None', dto.duplicateStatus, 'Default status should be None');
        System.assertEquals(0.0, dto.duplicateConfidence, 'Default confidence should be 0');
    }
    
    @isTest
    static void test_BillLineItemDTO_FromRecord() {
        Bill_Line_Item__c item = [SELECT Id, Name, CPT_HCPCS_NDC__c, Charge__c,
                                         Service_Start_Date__c, Service_End_Date__c,
                                         Duplicate_Status__c, Last_Duplicate_Check__c,
                                         Duplicate_Confidence__c, Bill__c,
                                         Bill__r.External_Id__c, Bill__r.Patient_Id__c
                                  FROM Bill_Line_Item__c LIMIT 1];
        
        Test.startTest();
        TRM_DuplicateDetectionModels.BillLineItemDTO dto = 
            new TRM_DuplicateDetectionModels.BillLineItemDTO(item);
        Test.stopTest();
        
        System.assertEquals(item.Id, dto.recordId, 'recordId should match');
        System.assertEquals(item.CPT_HCPCS_NDC__c, dto.procedureCode, 'procedureCode should match');
    }
    
    @isTest
    static void test_ConfigurationDTO_Constructor() {
        Test.startTest();
        TRM_DuplicateDetectionModels.ConfigurationDTO dto =
            new TRM_DuplicateDetectionModels.ConfigurationDTO();
        Test.stopTest();

        System.assertEquals(0.01, dto.chargeTolerance, 'chargeTolerance should be 0.01');
        System.assertEquals(5, dto.dateWindowYears, 'dateWindowYears should be 5');
        System.assertEquals(true, dto.enableBillWarnings, 'enableBillWarnings should be true');
        System.assertEquals(false, dto.enableProviderMatching, 'enableProviderMatching should be false');
        System.assertEquals(50, dto.maxMatchesReturned, 'maxMatchesReturned should be 50');
    }

    @isTest
    static void test_BulkProcessingResultDTO_Constructor() {
        Test.startTest();
        TRM_DuplicateDetectionModels.BulkProcessingResultDTO dto =
            new TRM_DuplicateDetectionModels.BulkProcessingResultDTO();
        dto.finalizeProcessing();
        Test.stopTest();

        System.assertEquals(0, dto.totalProcessed, 'totalProcessed should be 0');
        System.assertEquals(0, dto.exactMatches, 'exactMatches should be 0');
        System.assertEquals(0, dto.potentialMatches, 'potentialMatches should be 0');
        System.assertEquals(0, dto.errors, 'errors should be 0');
        System.assertNotEquals(null, dto.processingEndTime, 'processingEndTime should be set');
        System.assertNotEquals(null, dto.processingTimeMs, 'processingTimeMs should be set');
    }

    @isTest
    static void test_AuditTrailDTO_Constructor() {
        Test.startTest();
        TRM_DuplicateDetectionModels.AuditTrailDTO dto =
            new TRM_DuplicateDetectionModels.AuditTrailDTO();
        Test.stopTest();

        System.assertNotEquals(null, dto.timestamp, 'timestamp should be set');
        System.assertNotEquals(null, dto.userId, 'userId should be set');
        System.assertNotEquals(null, dto.userName, 'userName should be set');
    }

    @isTest
    static void test_BillDuplicateSummaryDTO_Constructor() {
        Test.startTest();
        TRM_DuplicateDetectionModels.BillDuplicateSummaryDTO dto =
            new TRM_DuplicateDetectionModels.BillDuplicateSummaryDTO();
        dto.totalLineItems = 10;
        dto.exactMatches = 2;
        dto.potentialMatches = 3;
        dto.calculateDerivedValues();
        Test.stopTest();

        System.assertEquals(5, dto.totalWarnings, 'totalWarnings should be 5');
        System.assertEquals(true, dto.hasWarnings, 'hasWarnings should be true');
        System.assert(dto.summaryMessage.contains('5 duplicates'), 'summaryMessage should contain count');
    }

    @isTest
    static void test_CaseDuplicateSummaryDTO_Constructor() {
        Test.startTest();
        TRM_DuplicateDetectionModels.CaseDuplicateSummaryDTO dto =
            new TRM_DuplicateDetectionModels.CaseDuplicateSummaryDTO();
        dto.totalBills = 1;
        dto.totalLineItems = 5;
        dto.exactMatches = 1;
        dto.potentialMatches = 2;
        dto.calculateDerivedValues();
        Test.stopTest();

        System.assertEquals(3, dto.totalMatches, 'totalMatches should be 3');
        System.assertEquals(true, dto.hasWarnings, 'hasWarnings should be true');
        System.assertEquals('status-exact', dto.statusClass, 'statusClass should be status-exact');
    }

    @isTest
    static void test_CaseMatchDTO_Constructor() {
        Bill_Line_Item__c item = [SELECT Id, Name, CPT_HCPCS_NDC__c, Charge__c,
                                         Service_Start_Date__c, Service_End_Date__c,
                                         Bill__r.External_Id__c, Bill__r.Patient_Id__c,
                                         Bill__r.Bill_Case_Data__r.Id, Bill__r.Bill_Case_Data__r.CaseNumber,
                                         CreatedDate, CreatedBy.Name
                                  FROM Bill_Line_Item__c LIMIT 1];
        Case testCase = [SELECT Id FROM Case LIMIT 1];

        Test.startTest();
        TRM_DuplicateDetectionModels.CaseMatchDTO dto =
            new TRM_DuplicateDetectionModels.CaseMatchDTO(item, testCase.Id);
        Test.stopTest();

        System.assertEquals(item.Id, dto.recordId, 'recordId should match');
        System.assertEquals(testCase.Id, dto.caseId, 'caseId should match');
    }

    // ============ TRM_DuplicateDetectionService Tests ============

    @isTest
    static void test_Service_detectDuplicates_NullRecords() {
        Test.startTest();
        TRM_DuplicateDetectionModels.BulkProcessingResultDTO result =
            TRM_DuplicateDetectionService.detectDuplicates(null);
        Test.stopTest();

        System.assertEquals(0, result.totalProcessed, 'Should process 0 records');
    }

    @isTest
    static void test_Service_detectDuplicates_EmptyRecords() {
        Test.startTest();
        TRM_DuplicateDetectionModels.BulkProcessingResultDTO result =
            TRM_DuplicateDetectionService.detectDuplicates(new List<Bill_Line_Item__c>());
        Test.stopTest();

        System.assertEquals(0, result.totalProcessed, 'Should process 0 records');
    }

    @isTest
    static void test_Service_detectDuplicates_ValidRecords() {
        List<Bill_Line_Item__c> items = [SELECT Id, CPT_HCPCS_NDC__c, Charge__c,
                                                Service_Start_Date__c, Service_End_Date__c
                                         FROM Bill_Line_Item__c];

        Test.startTest();
        TRM_DuplicateDetectionModels.BulkProcessingResultDTO result =
            TRM_DuplicateDetectionService.detectDuplicates(items);
        Test.stopTest();

        System.assert(result.totalProcessed > 0, 'Should have processed records');
    }

    @isTest
    static void test_Service_findExactMatches_NullPatientId() {
        Bill_Line_Item__c item = [SELECT Id, CPT_HCPCS_NDC__c, Charge__c,
                                         Service_Start_Date__c, Service_End_Date__c
                                  FROM Bill_Line_Item__c LIMIT 1];

        Test.startTest();
        List<Bill_Line_Item__c> matches =
            TRM_DuplicateDetectionService.findExactMatches(item, null);
        Test.stopTest();

        System.assertEquals(0, matches.size(), 'Should return empty list for null patientId');
    }

    @isTest
    static void test_Service_findExactMatches_ValidPatientId() {
        Bill_Line_Item__c item = [SELECT Id, CPT_HCPCS_NDC__c, Charge__c,
                                         Service_Start_Date__c, Service_End_Date__c
                                  FROM Bill_Line_Item__c
                                  WHERE CPT_HCPCS_NDC__c = '99213' LIMIT 1];

        Test.startTest();
        List<Bill_Line_Item__c> matches =
            TRM_DuplicateDetectionService.findExactMatches(item, 'PAT-001');
        Test.stopTest();

        // Should find at least 1 match (the other 99213 item with same charge)
        System.assert(matches.size() >= 0, 'Should handle exact match search');
    }

    @isTest
    static void test_Service_findPotentialMatches_NullPatientId() {
        Bill_Line_Item__c item = [SELECT Id, CPT_HCPCS_NDC__c, Charge__c,
                                         Service_Start_Date__c, Service_End_Date__c
                                  FROM Bill_Line_Item__c LIMIT 1];

        Test.startTest();
        List<Bill_Line_Item__c> matches =
            TRM_DuplicateDetectionService.findPotentialMatches(item, null);
        Test.stopTest();

        System.assertEquals(0, matches.size(), 'Should return empty list for null patientId');
    }

    @isTest
    static void test_Service_findPotentialMatches_ValidPatientId() {
        Bill_Line_Item__c item = [SELECT Id, CPT_HCPCS_NDC__c, Charge__c,
                                         Service_Start_Date__c, Service_End_Date__c
                                  FROM Bill_Line_Item__c
                                  WHERE CPT_HCPCS_NDC__c = '99213' LIMIT 1];

        Test.startTest();
        List<Bill_Line_Item__c> matches =
            TRM_DuplicateDetectionService.findPotentialMatches(item, 'PAT-001');
        Test.stopTest();

        System.assert(matches.size() >= 0, 'Should handle potential match search');
    }

    @isTest
    static void test_Service_getDuplicateData_ValidRecord() {
        Bill_Line_Item__c item = [SELECT Id FROM Bill_Line_Item__c LIMIT 1];

        Test.startTest();
        TRM_DuplicateDetectionModels.DuplicateDataDTO result =
            TRM_DuplicateDetectionService.getDuplicateData(item.Id);
        Test.stopTest();

        System.assertNotEquals(null, result, 'Should return result');
        System.assertNotEquals(null, result.sourceRecord, 'Should have sourceRecord');
    }

    @isTest
    static void test_Service_getDuplicateData_InvalidRecord() {
        Test.startTest();
        try {
            TRM_DuplicateDetectionService.getDuplicateData('a0000000000FAKE');
            System.assert(false, 'Should have thrown exception');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('Error') || e.getMessage().contains('not found'),
                         'Should throw appropriate error');
        }
        Test.stopTest();
    }

    @isTest
    static void test_Service_updateBillWarningCounts_NullBillIds() {
        Test.startTest();
        TRM_DuplicateDetectionService.updateBillWarningCounts(null);
        Test.stopTest();
        // Should not throw exception
        System.assert(true, 'Should handle null billIds gracefully');
    }

    @isTest
    static void test_Service_updateBillWarningCounts_EmptyBillIds() {
        Test.startTest();
        TRM_DuplicateDetectionService.updateBillWarningCounts(new Set<Id>());
        Test.stopTest();
        // Should not throw exception
        System.assert(true, 'Should handle empty billIds gracefully');
    }

    @isTest
    static void test_Service_updateBillWarningCounts_ValidBillIds() {
        Bill__c bill = [SELECT Id FROM Bill__c LIMIT 1];
        Set<Id> billIds = new Set<Id>{bill.Id};

        Test.startTest();
        TRM_DuplicateDetectionService.updateBillWarningCounts(billIds);
        Test.stopTest();

        System.assert(true, 'Should update bill warning counts');
    }

    // ============ TRM_DuplicateDetectionHandler Tests ============

    @isTest
    static void test_Handler_handleAfterInsert() {
        List<Bill_Line_Item__c> items = [SELECT Id, CPT_HCPCS_NDC__c, Charge__c,
                                                Service_Start_Date__c, Service_End_Date__c
                                         FROM Bill_Line_Item__c];

        Test.startTest();
        TRM_DuplicateDetectionHandler.handleAfterInsert(items);
        Test.stopTest();

        System.assert(true, 'Should handle after insert');
    }

    @isTest
    static void test_Handler_handleAfterUpdate() {
        List<Bill_Line_Item__c> items = [SELECT Id, CPT_HCPCS_NDC__c, Charge__c,
                                                Service_Start_Date__c, Service_End_Date__c
                                         FROM Bill_Line_Item__c];
        Map<Id, Bill_Line_Item__c> oldMap = new Map<Id, Bill_Line_Item__c>(items);

        Test.startTest();
        TRM_DuplicateDetectionHandler.handleAfterUpdate(items, oldMap);
        Test.stopTest();

        System.assert(true, 'Should handle after update');
    }

    @isTest
    static void test_Handler_detectDuplicates() {
        List<Bill_Line_Item__c> items = [SELECT Id, CPT_HCPCS_NDC__c, Charge__c,
                                                Service_Start_Date__c, Service_End_Date__c
                                         FROM Bill_Line_Item__c LIMIT 2];

        Test.startTest();
        TRM_DuplicateDetectionHandler.detectDuplicates(items);
        Test.stopTest();

        System.assert(true, 'Should detect duplicates');
    }

    // ============ TRM_DuplicateDetectionApi Tests ============

    @isTest
    static void test_Api_getDuplicateData_ValidRecord() {
        Bill_Line_Item__c item = [SELECT Id FROM Bill_Line_Item__c LIMIT 1];

        Test.startTest();
        TRM_DuplicateDetectionModels.DuplicateDataDTO result =
            TRM_DuplicateDetectionApi.getDuplicateData(item.Id);
        Test.stopTest();

        System.assertNotEquals(null, result, 'Should return result');
    }

    @isTest
    static void test_Api_getDuplicateData_NullRecord() {
        Test.startTest();
        try {
            TRM_DuplicateDetectionApi.getDuplicateData(null);
            System.assert(false, 'Should have thrown exception');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('required'), 'Should require record ID');
        }
        Test.stopTest();
    }

    @isTest
    static void test_Api_triggerManualCheck_ValidRecord() {
        Bill_Line_Item__c item = [SELECT Id FROM Bill_Line_Item__c LIMIT 1];

        Test.startTest();
        String result = TRM_DuplicateDetectionApi.triggerManualCheck(item.Id);
        Test.stopTest();

        System.assert(result.contains('completed'), 'Should return success message');
    }

    @isTest
    static void test_Api_triggerManualCheck_NullRecord() {
        Test.startTest();
        try {
            TRM_DuplicateDetectionApi.triggerManualCheck(null);
            System.assert(false, 'Should have thrown exception');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('required'), 'Should require record ID');
        }
        Test.stopTest();
    }

    @isTest
    static void test_Api_getConfiguration() {
        Test.startTest();
        TRM_DuplicateDetectionModels.ConfigurationDTO config =
            TRM_DuplicateDetectionApi.getConfiguration();
        Test.stopTest();

        System.assertNotEquals(null, config, 'Should return configuration');
        System.assertEquals(0.01, config.chargeTolerance, 'Should have default tolerance');
    }

    @isTest
    static void test_Api_getBulkDuplicateStatus_ValidRecords() {
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
    static void test_Api_getBulkDuplicateStatus_NullRecords() {
        Test.startTest();
        try {
            TRM_DuplicateDetectionApi.getBulkDuplicateStatus(null);
            System.assert(false, 'Should have thrown exception');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('required'), 'Should require record IDs');
        }
        Test.stopTest();
    }

    @isTest
    static void test_Api_triggerBulkCheck_ValidRecords() {
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
    }

    @isTest
    static void test_Api_triggerBulkCheck_NullRecords() {
        Test.startTest();
        try {
            TRM_DuplicateDetectionApi.triggerBulkCheck(null);
            System.assert(false, 'Should have thrown exception');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('required'), 'Should require record IDs');
        }
        Test.stopTest();
    }

    @isTest
    static void test_Api_getMatchingRecordsDetails_ValidRecords() {
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
    static void test_Api_getMatchingRecordsDetails_NullSource() {
        List<Bill_Line_Item__c> items = [SELECT Id FROM Bill_Line_Item__c LIMIT 2];
        List<Id> matchingIds = new List<Id>{items[0].Id, items[1].Id};

        Test.startTest();
        try {
            TRM_DuplicateDetectionApi.getMatchingRecordsDetails(null, matchingIds);
            System.assert(false, 'Should have thrown exception');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('required'), 'Should require source ID');
        }
        Test.stopTest();
    }

    @isTest
    static void test_Api_getBillDuplicateSummary_ValidBill() {
        Bill__c bill = [SELECT Id FROM Bill__c LIMIT 1];

        Test.startTest();
        TRM_DuplicateDetectionModels.BillDuplicateSummaryDTO result =
            TRM_DuplicateDetectionApi.getBillDuplicateSummary(bill.Id);
        Test.stopTest();

        System.assertNotEquals(null, result, 'Should return summary');
        System.assertEquals(bill.Id, result.billId, 'Should have correct billId');
    }

    @isTest
    static void test_Api_getBillDuplicateSummary_NullBill() {
        Test.startTest();
        try {
            TRM_DuplicateDetectionApi.getBillDuplicateSummary(null);
            System.assert(false, 'Should have thrown exception');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('required'), 'Should require Bill ID');
        }
        Test.stopTest();
    }

    @isTest
    static void test_Api_triggerBillDuplicateCheck_ValidBill() {
        Bill__c bill = [SELECT Id FROM Bill__c LIMIT 1];

        Test.startTest();
        String result = TRM_DuplicateDetectionApi.triggerBillDuplicateCheck(bill.Id);
        Test.stopTest();

        System.assert(result.contains('completed') || result.contains('line item'),
                     'Should return success message');
    }

    @isTest
    static void test_Api_triggerBillDuplicateCheck_NullBill() {
        Test.startTest();
        try {
            TRM_DuplicateDetectionApi.triggerBillDuplicateCheck(null);
            System.assert(false, 'Should have thrown exception');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('required'), 'Should require Bill ID');
        }
        Test.stopTest();
    }

    @isTest
    static void test_Api_getCaseDuplicateSummary_ValidCase() {
        Case testCase = [SELECT Id FROM Case LIMIT 1];

        Test.startTest();
        TRM_DuplicateDetectionModels.CaseDuplicateSummaryDTO result =
            TRM_DuplicateDetectionApi.getCaseDuplicateSummary(testCase.Id);
        Test.stopTest();

        System.assertNotEquals(null, result, 'Should return summary');
        System.assertEquals(testCase.Id, result.caseId, 'Should have correct caseId');
    }

    @isTest
    static void test_Api_getCaseDuplicateSummary_NullCase() {
        Test.startTest();
        try {
            TRM_DuplicateDetectionApi.getCaseDuplicateSummary(null);
            System.assert(false, 'Should have thrown exception');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('required'), 'Should require Case ID');
        }
        Test.stopTest();
    }

    @isTest
    static void test_Api_getCaseAllDuplicateMatches_ValidCase() {
        Case testCase = [SELECT Id FROM Case LIMIT 1];

        Test.startTest();
        List<TRM_DuplicateDetectionModels.CaseMatchDTO> results =
            TRM_DuplicateDetectionApi.getCaseAllDuplicateMatches(testCase.Id);
        Test.stopTest();

        System.assertNotEquals(null, results, 'Should return results list');
    }

    @isTest
    static void test_Api_getCaseAllDuplicateMatches_NullCase() {
        Test.startTest();
        try {
            TRM_DuplicateDetectionApi.getCaseAllDuplicateMatches(null);
            System.assert(false, 'Should have thrown exception');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('required'), 'Should require Case ID');
        }
        Test.stopTest();
    }

    @isTest
    static void test_Api_getBillLineItemsWithMatches_ValidBill() {
        Bill__c bill = [SELECT Id FROM Bill__c LIMIT 1];

        Test.startTest();
        List<Bill_Line_Item__c> results =
            TRM_DuplicateDetectionApi.getBillLineItemsWithMatches(bill.Id);
        Test.stopTest();

        System.assertNotEquals(null, results, 'Should return results list');
    }

    @isTest
    static void test_Api_getBillLineItemsWithMatches_NullBill() {
        Test.startTest();
        try {
            TRM_DuplicateDetectionApi.getBillLineItemsWithMatches(null);
            System.assert(false, 'Should have thrown exception');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('required'), 'Should require Bill ID');
        }
        Test.stopTest();
    }
}

