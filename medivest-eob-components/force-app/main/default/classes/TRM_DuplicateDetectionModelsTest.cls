/**
 * @description Test class for TRM_DuplicateDetectionModels
 * Tests all DTOs and their constructors/methods
 * @author Trinity Development Team
 * @date 2025-12-08
 */
@isTest
private class TRM_DuplicateDetectionModelsTest {
    
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
        
        Bill_Line_Item__c lineItem = new Bill_Line_Item__c(
            Bill__c = testBill.Id,
            CPT_HCPCS_NDC__c = '99213',
            Charge__c = 150.00,
            Service_Start_Date__c = Date.today().addDays(-30),
            Service_End_Date__c = Date.today().addDays(-30)
        );
        insert lineItem;
    }
    
    @isTest
    static void test_DuplicateDataDTO_DefaultConstructor() {
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
    static void test_MatchDTO_DefaultConstructor() {
        Test.startTest();
        TRM_DuplicateDetectionModels.MatchDTO dto = 
            new TRM_DuplicateDetectionModels.MatchDTO();
        Test.stopTest();
        
        System.assertEquals('Unknown', dto.matchType, 'Default matchType should be Unknown');
        System.assertEquals(0.0, dto.confidence, 'Default confidence should be 0');
    }
    
    @isTest
    static void test_MatchDTO_FromBillLineItem() {
        Bill_Line_Item__c item = [SELECT Id, Name, CPT_HCPCS_NDC__c, Charge__c,
                                         Service_Start_Date__c, Service_End_Date__c,
                                         Bill__r.Id, Bill__r.External_Id__c, Bill__r.Patient_Id__c,
                                         Bill__r.Bill_Case_Data__r.CaseNumber,
                                         CreatedDate, CreatedBy.Name
                                  FROM Bill_Line_Item__c LIMIT 1];

        Test.startTest();
        TRM_DuplicateDetectionModels.MatchDTO dto =
            new TRM_DuplicateDetectionModels.MatchDTO(item);
        Test.stopTest();

        System.assertEquals(item.Id, dto.recordId, 'recordId should match');
        System.assertEquals(item.Name, dto.recordName, 'recordName should match');
        System.assertEquals(item.CPT_HCPCS_NDC__c, dto.procedureCode, 'procedureCode should match');
        System.assertEquals(item.Charge__c, dto.chargeAmount, 'chargeAmount should match');
        System.assertEquals(item.Service_Start_Date__c, dto.serviceStartDate, 'serviceStartDate should match');
    }
    
    @isTest
    static void test_MatchDTO_FromNullRecord() {
        Test.startTest();
        TRM_DuplicateDetectionModels.MatchDTO dto = 
            new TRM_DuplicateDetectionModels.MatchDTO(null);
        Test.stopTest();
        
        System.assertEquals(null, dto.recordId, 'recordId should be null');
        System.assertEquals('Unknown', dto.matchType, 'matchType should be Unknown');
    }
    
    @isTest
    static void test_BillLineItemDTO_DefaultConstructor() {
        Test.startTest();
        TRM_DuplicateDetectionModels.BillLineItemDTO dto = 
            new TRM_DuplicateDetectionModels.BillLineItemDTO();
        Test.stopTest();
        
        System.assertEquals('None', dto.duplicateStatus, 'Default status should be None');
        System.assertEquals(0.0, dto.duplicateConfidence, 'Default confidence should be 0');
    }
    
    @isTest
    static void test_BillLineItemDTO_FromBillLineItem() {
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
        System.assertEquals(item.Name, dto.recordName, 'recordName should match');
        System.assertEquals(item.CPT_HCPCS_NDC__c, dto.procedureCode, 'procedureCode should match');
    }
    
    @isTest
    static void test_BillLineItemDTO_FromNullRecord() {
        Test.startTest();
        TRM_DuplicateDetectionModels.BillLineItemDTO dto = 
            new TRM_DuplicateDetectionModels.BillLineItemDTO(null);
        Test.stopTest();
        
        System.assertEquals(null, dto.recordId, 'recordId should be null');
        System.assertEquals('None', dto.duplicateStatus, 'duplicateStatus should be None');
    }
    
    @isTest
    static void test_ConfigurationDTO_DefaultValues() {
        Test.startTest();
        TRM_DuplicateDetectionModels.ConfigurationDTO dto =
            new TRM_DuplicateDetectionModels.ConfigurationDTO();
        Test.stopTest();

        System.assertEquals(0.01, dto.chargeTolerance, 'chargeTolerance should be 0.01');
        System.assertEquals(5, dto.dateWindowYears, 'dateWindowYears should be 5');
        System.assertEquals(true, dto.enableBillWarnings, 'enableBillWarnings should be true');
        System.assertEquals(false, dto.enableProviderMatching, 'enableProviderMatching should be false');
        System.assertEquals(50, dto.maxMatchesReturned, 'maxMatchesReturned should be 50');
        System.assertEquals(true, dto.enableConfidenceScoring, 'enableConfidenceScoring should be true');
    }

    @isTest
    static void test_BulkProcessingResultDTO_Constructor() {
        Test.startTest();
        TRM_DuplicateDetectionModels.BulkProcessingResultDTO dto =
            new TRM_DuplicateDetectionModels.BulkProcessingResultDTO();
        Test.stopTest();

        System.assertEquals(0, dto.totalProcessed, 'totalProcessed should be 0');
        System.assertEquals(0, dto.exactMatches, 'exactMatches should be 0');
        System.assertEquals(0, dto.potentialMatches, 'potentialMatches should be 0');
        System.assertEquals(0, dto.noMatches, 'noMatches should be 0');
        System.assertEquals(0, dto.errors, 'errors should be 0');
        System.assertNotEquals(null, dto.errorMessages, 'errorMessages should be initialized');
        System.assertNotEquals(null, dto.processingStartTime, 'processingStartTime should be set');
    }

    @isTest
    static void test_BulkProcessingResultDTO_FinalizeProcessing() {
        Test.startTest();
        TRM_DuplicateDetectionModels.BulkProcessingResultDTO dto =
            new TRM_DuplicateDetectionModels.BulkProcessingResultDTO();
        dto.finalizeProcessing();
        Test.stopTest();

        System.assertNotEquals(null, dto.processingEndTime, 'processingEndTime should be set');
        System.assertNotEquals(null, dto.processingTimeMs, 'processingTimeMs should be set');
        System.assert(dto.processingTimeMs >= 0, 'processingTimeMs should be non-negative');
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
        System.assertEquals(UserInfo.getUserId(), dto.userId, 'userId should match current user');
    }

    @isTest
    static void test_BillDuplicateSummaryDTO_Constructor() {
        Test.startTest();
        TRM_DuplicateDetectionModels.BillDuplicateSummaryDTO dto =
            new TRM_DuplicateDetectionModels.BillDuplicateSummaryDTO();
        Test.stopTest();

        System.assertEquals(0, dto.totalLineItems, 'totalLineItems should be 0');
        System.assertEquals(0, dto.exactMatches, 'exactMatches should be 0');
        System.assertEquals(0, dto.potentialMatches, 'potentialMatches should be 0');
        System.assertEquals(0, dto.totalWarnings, 'totalWarnings should be 0');
        System.assertEquals(false, dto.hasWarnings, 'hasWarnings should be false');
    }

    @isTest
    static void test_BillDuplicateSummaryDTO_CalculateDerivedValues_WithWarnings() {
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
        System.assert(dto.summaryMessage.contains('5'), 'summaryMessage should contain count');
    }

    @isTest
    static void test_BillDuplicateSummaryDTO_CalculateDerivedValues_NoWarnings() {
        Test.startTest();
        TRM_DuplicateDetectionModels.BillDuplicateSummaryDTO dto =
            new TRM_DuplicateDetectionModels.BillDuplicateSummaryDTO();
        dto.totalLineItems = 10;
        dto.exactMatches = 0;
        dto.potentialMatches = 0;
        dto.calculateDerivedValues();
        Test.stopTest();

        System.assertEquals(0, dto.totalWarnings, 'totalWarnings should be 0');
        System.assertEquals(false, dto.hasWarnings, 'hasWarnings should be false');
        System.assert(dto.summaryMessage.contains('No duplicates'), 'summaryMessage should indicate no duplicates');
    }

    @isTest
    static void test_CaseDuplicateSummaryDTO_Constructor() {
        Test.startTest();
        TRM_DuplicateDetectionModels.CaseDuplicateSummaryDTO dto =
            new TRM_DuplicateDetectionModels.CaseDuplicateSummaryDTO();
        Test.stopTest();

        System.assertEquals(0, dto.totalBills, 'totalBills should be 0');
        System.assertEquals(0, dto.totalLineItems, 'totalLineItems should be 0');
        System.assertEquals(0, dto.exactMatches, 'exactMatches should be 0');
        System.assertEquals(0, dto.potentialMatches, 'potentialMatches should be 0');
        System.assertEquals(0, dto.totalMatches, 'totalMatches should be 0');
        System.assertEquals(false, dto.hasWarnings, 'hasWarnings should be false');
        System.assertEquals('status-none', dto.statusClass, 'statusClass should be status-none');
    }

    @isTest
    static void test_CaseDuplicateSummaryDTO_CalculateDerivedValues_ExactMatches() {
        Test.startTest();
        TRM_DuplicateDetectionModels.CaseDuplicateSummaryDTO dto =
            new TRM_DuplicateDetectionModels.CaseDuplicateSummaryDTO();
        dto.totalBills = 1;
        dto.totalLineItems = 5;
        dto.exactMatches = 2;
        dto.potentialMatches = 0;
        dto.calculateDerivedValues();
        Test.stopTest();

        System.assertEquals(2, dto.totalMatches, 'totalMatches should be 2');
        System.assertEquals(true, dto.hasWarnings, 'hasWarnings should be true');
        System.assertEquals('status-exact', dto.statusClass, 'statusClass should be status-exact');
    }

    @isTest
    static void test_CaseDuplicateSummaryDTO_CalculateDerivedValues_PotentialOnly() {
        Test.startTest();
        TRM_DuplicateDetectionModels.CaseDuplicateSummaryDTO dto =
            new TRM_DuplicateDetectionModels.CaseDuplicateSummaryDTO();
        dto.totalBills = 1;
        dto.totalLineItems = 5;
        dto.exactMatches = 0;
        dto.potentialMatches = 3;
        dto.calculateDerivedValues();
        Test.stopTest();

        System.assertEquals(3, dto.totalMatches, 'totalMatches should be 3');
        System.assertEquals(true, dto.hasWarnings, 'hasWarnings should be true');
        System.assertEquals('status-potential', dto.statusClass, 'statusClass should be status-potential');
    }

    @isTest
    static void test_CaseMatchDTO_DefaultConstructor() {
        Test.startTest();
        TRM_DuplicateDetectionModels.CaseMatchDTO dto =
            new TRM_DuplicateDetectionModels.CaseMatchDTO();
        Test.stopTest();

        System.assertEquals('Unknown Match', dto.matchTypeLabel, 'matchTypeLabel should be Unknown Match');
        System.assertEquals('0%', dto.confidenceLabel, 'confidenceLabel should be 0%');
        System.assertEquals('$0.00', dto.formattedChargeAmount, 'formattedChargeAmount should be $0.00');
    }

    @isTest
    static void test_CaseMatchDTO_FromBillLineItem() {
        Bill_Line_Item__c item = [SELECT Id, Name, CPT_HCPCS_NDC__c, Charge__c,
                                         Service_Start_Date__c, Service_End_Date__c,
                                         Bill__r.Id, Bill__r.External_Id__c, Bill__r.Patient_Id__c,
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
        System.assertNotEquals(null, dto.formattedChargeAmount, 'formattedChargeAmount should be set');
    }

    @isTest
    static void test_CaseMatchDTO_CalculateDerivedValues_ExactMatch() {
        Test.startTest();
        TRM_DuplicateDetectionModels.CaseMatchDTO dto =
            new TRM_DuplicateDetectionModels.CaseMatchDTO();
        dto.matchType = 'Exact';
        dto.confidence = 100.0;
        dto.chargeAmount = 150.00;
        dto.serviceStartDate = Date.today();
        dto.serviceEndDate = Date.today();
        dto.caseId = [SELECT Id FROM Case LIMIT 1].Id;
        dto.calculateDerivedValues();
        Test.stopTest();

        System.assertEquals('Exact Match', dto.matchTypeLabel, 'matchTypeLabel should be Exact Match');
        System.assertEquals('100%', dto.confidenceLabel, 'confidenceLabel should be 100%');
        System.assertNotEquals(null, dto.relatedCaseUrl, 'relatedCaseUrl should be set');
    }

    @isTest
    static void test_CaseMatchDTO_CalculateDerivedValues_DateRange() {
        Test.startTest();
        TRM_DuplicateDetectionModels.CaseMatchDTO dto =
            new TRM_DuplicateDetectionModels.CaseMatchDTO();
        dto.matchType = 'Potential';
        dto.confidence = 75.0;
        dto.chargeAmount = 200.00;
        dto.serviceStartDate = Date.today().addDays(-5);
        dto.serviceEndDate = Date.today();
        dto.calculateDerivedValues();
        Test.stopTest();

        System.assertEquals('Potential Match', dto.matchTypeLabel, 'matchTypeLabel should be Potential Match');
        System.assert(dto.formattedServiceDates.contains(' - '), 'formattedServiceDates should show range');
    }
}

