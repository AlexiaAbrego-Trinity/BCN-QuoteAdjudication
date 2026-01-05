/**
 * @description API layer for Medivest Duplicate Detection System
 * @author Trinity Development Team
 * @date 2025-08-30
 * @version 2.0.0
 * 
 * This class follows Trinity design principles:
 * - Handle LWC interactions and validation
 * - @AuraEnabled methods with proper exception handling
 * - Input validation and sanitization
 * - Delegation to service layer for business logic
 * - Consistent error messaging for UI consumption
 */
public with sharing class TRM_DuplicateDetectionApi {
    
    /**
     * @description Get comprehensive duplicate data for a Bill Line Item record
     * @param recordId The Bill Line Item record ID
     * @return TRM_DuplicateDetectionModels.DuplicateDataDTO Complete duplicate information
     */
    @AuraEnabled(cacheable=true)
    public static TRM_DuplicateDetectionModels.DuplicateDataDTO getDuplicateData(Id recordId) {
        try {
            // Input validation
            if (recordId == null) {
                throw new AuraHandledException('Record ID is required');
            }
            
            // Validate record ID is for Bill_Line_Item__c
            String objectType = recordId.getSObjectType().getDescribe().getName();
            if (objectType != 'Bill_Line_Item__c') {
                throw new AuraHandledException('Invalid record type. Expected Bill Line Item.');
            }
            
            // Delegate to service layer
            return TRM_DuplicateDetectionService.getDuplicateData(recordId);
            
        } catch (AuraHandledException e) {
            // Re-throw AuraHandledException as-is
            throw e;
        } catch (Exception e) {
            // Wrap other exceptions for LWC consumption
            System.debug('TRM_DuplicateDetectionApi.getDuplicateData error: ' + e.getMessage());
            throw new AuraHandledException('Error retrieving duplicate data: ' + e.getMessage());
        }
    }
    
    /**
     * @description Trigger manual duplicate check for a specific record
     * @param recordId The Bill Line Item record ID to check
     * @return String Success message
     */
    @AuraEnabled
    public static String triggerManualCheck(Id recordId) {
        try {
            // Input validation
            if (recordId == null) {
                throw new AuraHandledException('Record ID is required');
            }
            
            // Validate record ID is for Bill_Line_Item__c
            String objectType = recordId.getSObjectType().getDescribe().getName();
            if (objectType != 'Bill_Line_Item__c') {
                throw new AuraHandledException('Invalid record type. Expected Bill Line Item.');
            }
            
            // Query the record with required fields
            List<Bill_Line_Item__c> records = [
                SELECT Id, CPT_HCPCS_NDC__c, Charge__c, Service_Start_Date__c,
                       Service_End_Date__c, Bill__r.Patient_Id__c
                FROM Bill_Line_Item__c
                WHERE Id = :recordId
                WITH SECURITY_ENFORCED
                LIMIT 1
            ];
            
            if (records.isEmpty()) {
                throw new AuraHandledException('Record not found');
            }
            
            // Trigger duplicate detection via service layer
            TRM_DuplicateDetectionModels.BulkProcessingResultDTO result = 
                TRM_DuplicateDetectionService.detectDuplicates(records);
            
            // Check for errors
            if (result.errors > 0) {
                String errorMessage = 'Duplicate check completed with errors: ' + 
                    String.join(result.errorMessages, '; ');
                throw new AuraHandledException(errorMessage);
            }
            
            return 'Duplicate check completed successfully. Processing time: ' + 
                result.processingTimeMs + 'ms';
            
        } catch (AuraHandledException e) {
            // Re-throw AuraHandledException as-is
            throw e;
        } catch (Exception e) {
            // Wrap other exceptions for LWC consumption
            System.debug('TRM_DuplicateDetectionApi.triggerManualCheck error: ' + e.getMessage());
            throw new AuraHandledException('Error triggering duplicate check: ' + e.getMessage());
        }
    }
    
    /**
     * @description Get bulk duplicate status for multiple records
     * @param recordIds List of Bill Line Item record IDs
     * @return List<TRM_DuplicateDetectionModels.DuplicateDataDTO> Duplicate data for each record
     */
    @AuraEnabled(cacheable=true)
    public static List<TRM_DuplicateDetectionModels.DuplicateDataDTO> getBulkDuplicateStatus(
        List<Id> recordIds
    ) {
        List<TRM_DuplicateDetectionModels.DuplicateDataDTO> results = 
            new List<TRM_DuplicateDetectionModels.DuplicateDataDTO>();
        
        try {
            // Input validation
            if (recordIds == null || recordIds.isEmpty()) {
                throw new AuraHandledException('Record IDs are required');
            }
            
            if (recordIds.size() > 100) {
                throw new AuraHandledException('Maximum 100 records allowed per request');
            }
            
            // Process each record individually to handle partial failures gracefully
            for (Id recordId : recordIds) {
                try {
                    TRM_DuplicateDetectionModels.DuplicateDataDTO result = 
                        TRM_DuplicateDetectionService.getDuplicateData(recordId);
                    results.add(result);
                } catch (Exception e) {
                    // Create error result for this record
                    TRM_DuplicateDetectionModels.DuplicateDataDTO errorResult = 
                        new TRM_DuplicateDetectionModels.DuplicateDataDTO();
                    errorResult.sourceRecord = new TRM_DuplicateDetectionModels.BillLineItemDTO();
                    errorResult.sourceRecord.recordId = recordId;
                    errorResult.duplicateStatus = 'Error';
                    results.add(errorResult);
                    
                    System.debug('TRM_DuplicateDetectionApi.getBulkDuplicateStatus error for ' + 
                               recordId + ': ' + e.getMessage());
                }
            }
            
            return results;
            
        } catch (AuraHandledException e) {
            // Re-throw AuraHandledException as-is
            throw e;
        } catch (Exception e) {
            // Wrap other exceptions for LWC consumption
            System.debug('TRM_DuplicateDetectionApi.getBulkDuplicateStatus error: ' + e.getMessage());
            throw new AuraHandledException('Error retrieving bulk duplicate status: ' + e.getMessage());
        }
    }
    
    /**
     * @description Get system configuration for duplicate detection
     * @return TRM_DuplicateDetectionModels.ConfigurationDTO Current configuration settings
     */
    @AuraEnabled(cacheable=true)
    public static TRM_DuplicateDetectionModels.ConfigurationDTO getConfiguration() {
        try {
            // For now, return default configuration
            // This can be enhanced to read from Custom Settings or Custom Metadata Types
            return new TRM_DuplicateDetectionModels.ConfigurationDTO();
            
        } catch (Exception e) {
            System.debug('TRM_DuplicateDetectionApi.getConfiguration error: ' + e.getMessage());
            throw new AuraHandledException('Error retrieving configuration: ' + e.getMessage());
        }
    }
    
    /**
     * @description Trigger bulk duplicate check for multiple records
     * @param recordIds List of Bill Line Item record IDs to check
     * @return TRM_DuplicateDetectionModels.BulkProcessingResultDTO Processing results
     */
    @AuraEnabled
    public static TRM_DuplicateDetectionModels.BulkProcessingResultDTO triggerBulkCheck(
        List<Id> recordIds
    ) {
        try {
            // Input validation
            if (recordIds == null || recordIds.isEmpty()) {
                throw new AuraHandledException('Record IDs are required');
            }
            
            if (recordIds.size() > 200) {
                throw new AuraHandledException('Maximum 200 records allowed per bulk operation');
            }
            
            // Query records with required fields
            List<Bill_Line_Item__c> records = [
                SELECT Id, CPT_HCPCS_NDC__c, Charge__c, Service_Start_Date__c,
                       Service_End_Date__c, Bill__r.Patient_Id__c
                FROM Bill_Line_Item__c
                WHERE Id IN :recordIds
                WITH SECURITY_ENFORCED
            ];
            
            if (records.isEmpty()) {
                throw new AuraHandledException('No valid records found');
            }
            
            // Trigger bulk duplicate detection via service layer
            return TRM_DuplicateDetectionService.detectDuplicates(records);
            
        } catch (AuraHandledException e) {
            // Re-throw AuraHandledException as-is
            throw e;
        } catch (Exception e) {
            // Wrap other exceptions for LWC consumption
            System.debug('TRM_DuplicateDetectionApi.triggerBulkCheck error: ' + e.getMessage());
            throw new AuraHandledException('Error triggering bulk duplicate check: ' + e.getMessage());
        }
    }
    
    /**
     * @description Get matching records details for comparison
     * @param sourceRecordId The source Bill Line Item record ID
     * @param matchingRecordIds List of matching record IDs to retrieve details for
     * @return List<TRM_DuplicateDetectionModels.BillLineItemDTO> Detailed matching record information
     */
    @AuraEnabled(cacheable=true)
    public static List<TRM_DuplicateDetectionModels.BillLineItemDTO> getMatchingRecordsDetails(
        Id sourceRecordId,
        List<Id> matchingRecordIds
    ) {
        List<TRM_DuplicateDetectionModels.BillLineItemDTO> results = 
            new List<TRM_DuplicateDetectionModels.BillLineItemDTO>();
        
        try {
            // Input validation
            if (sourceRecordId == null) {
                throw new AuraHandledException('Source record ID is required');
            }
            
            if (matchingRecordIds == null || matchingRecordIds.isEmpty()) {
                throw new AuraHandledException('Matching record IDs are required');
            }
            
            if (matchingRecordIds.size() > 50) {
                throw new AuraHandledException('Maximum 50 matching records allowed per request');
            }
            
            // Query matching records with detailed information
            List<Bill_Line_Item__c> matchingRecords = [
                SELECT Id, Name, CPT_HCPCS_NDC__c, Charge__c, Service_Start_Date__c,
                       Service_End_Date__c, Duplicate_Status__c, Last_Duplicate_Check__c,
                       Duplicate_Confidence__c, Bill__r.External_Id__c, Bill__r.Patient_Id__c,
                       CreatedDate, CreatedBy.Name, LastModifiedDate, LastModifiedBy.Name
                FROM Bill_Line_Item__c
                WHERE Id IN :matchingRecordIds
                WITH SECURITY_ENFORCED
                ORDER BY CreatedDate DESC
            ];
            
            // Convert to DTOs
            for (Bill_Line_Item__c record : matchingRecords) {
                results.add(new TRM_DuplicateDetectionModels.BillLineItemDTO(record));
            }
            
            return results;
            
        } catch (AuraHandledException e) {
            // Re-throw AuraHandledException as-is
            throw e;
        } catch (Exception e) {
            // Wrap other exceptions for LWC consumption
            System.debug('TRM_DuplicateDetectionApi.getMatchingRecordsDetails error: ' + e.getMessage());
            throw new AuraHandledException('Error retrieving matching records details: ' + e.getMessage());
        }
    }

    /**
     * @description Get Bill-level duplicate summary for Bill record page component
     * @param billId The Bill record ID
     * @return TRM_DuplicateDetectionModels.BillDuplicateSummaryDTO Bill duplicate summary
     * ADDED: New API method for Bill summary component
     */
    @AuraEnabled(cacheable=true)
    public static TRM_DuplicateDetectionModels.BillDuplicateSummaryDTO getBillDuplicateSummary(Id billId) {
        try {
            // Input validation
            if (billId == null) {
                throw new AuraHandledException('Bill ID is required');
            }

            // Validate record ID is for Bill__c
            String objectType = billId.getSObjectType().getDescribe().getName();
            if (objectType != 'Bill__c') {
                throw new AuraHandledException('Invalid record type. Expected Bill.');
            }

            // Query all line items for this Bill
            List<Bill_Line_Item__c> lineItems = [
                SELECT Id, Duplicate_Status__c, Last_Duplicate_Check__c
                FROM Bill_Line_Item__c
                WHERE Bill__c = :billId
                WITH SECURITY_ENFORCED
                ORDER BY CreatedDate DESC
            ];

            // Build summary DTO
            TRM_DuplicateDetectionModels.BillDuplicateSummaryDTO summary =
                new TRM_DuplicateDetectionModels.BillDuplicateSummaryDTO();
            summary.billId = billId;
            summary.totalLineItems = lineItems.size();

            // Count duplicates by type
            for (Bill_Line_Item__c item : lineItems) {
                if (item.Duplicate_Status__c == 'Exact') {
                    summary.exactMatches++;
                } else if (item.Duplicate_Status__c == 'Potential') {
                    summary.potentialMatches++;
                }

                // Track most recent check date
                if (item.Last_Duplicate_Check__c != null &&
                    (summary.lastCheckDate == null || item.Last_Duplicate_Check__c > summary.lastCheckDate)) {
                    summary.lastCheckDate = item.Last_Duplicate_Check__c;
                }
            }

            // Calculate derived values and summary message
            summary.calculateDerivedValues();

            return summary;

        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            System.debug('TRM_DuplicateDetectionApi.getBillDuplicateSummary error: ' + e.getMessage());
            throw new AuraHandledException('Error retrieving bill duplicate summary: ' + e.getMessage());
        }
    }

    /**
     * @description Trigger manual duplicate check for all line items in a Bill
     * @param billId The Bill record ID to check
     * @return String Success message with check results
     * ADDED: New API method for Bill-level duplicate checking
     */
    @AuraEnabled
    public static String triggerBillDuplicateCheck(Id billId) {
        try {
            // Input validation
            if (billId == null) {
                throw new AuraHandledException('Bill ID is required');
            }

            // Validate record ID is for Bill__c
            String objectType = billId.getSObjectType().getDescribe().getName();
            if (objectType != 'Bill__c') {
                throw new AuraHandledException('Invalid record type. Expected Bill.');
            }

            // Get all line items for this Bill with required fields for duplicate detection
            List<Bill_Line_Item__c> lineItems = [
                SELECT Id, CPT_HCPCS_NDC__c, Charge__c, Service_Start_Date__c,
                       Service_End_Date__c, Bill__r.Patient_Id__c
                FROM Bill_Line_Item__c
                WHERE Bill__c = :billId
                WITH SECURITY_ENFORCED
            ];

            if (lineItems.isEmpty()) {
                return 'No line items found for this Bill.';
            }

            // Trigger duplicate detection for all line items
            TRM_DuplicateDetectionHandler.detectDuplicates(lineItems);

            return String.format('Duplicate check completed for {0} line item{1}.',
                new List<Object>{ lineItems.size(), lineItems.size() > 1 ? 's' : '' });

        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            System.debug('TRM_DuplicateDetectionApi.triggerBillDuplicateCheck error: ' + e.getMessage());
            throw new AuraHandledException('Error triggering bill duplicate check: ' + e.getMessage());
        }
    }

    /**
     * @description Get Case-level duplicate detection summary
     * ADDED: For Case-level duplicate detection enhancement
     * @param caseId The Case record ID
     * @return TRM_DuplicateDetectionModels.CaseDuplicateSummaryDTO Case duplicate summary
     */
    @AuraEnabled(cacheable=true)
    public static TRM_DuplicateDetectionModels.CaseDuplicateSummaryDTO getCaseDuplicateSummary(Id caseId) {
        try {
            // Input validation
            if (caseId == null) {
                throw new AuraHandledException('Case ID is required');
            }

            // Validate record ID is for Case
            String objectType = caseId.getSObjectType().getDescribe().getName();
            if (objectType != 'Case') {
                throw new AuraHandledException('Invalid record type. Expected Case, got: ' + objectType);
            }

            // Query Case with Bill relationship
            List<Case> cases = [
                SELECT Id, CaseNumber, BCN__c
                FROM Case
                WHERE Id = :caseId
                WITH SECURITY_ENFORCED
                LIMIT 1
            ];

            if (cases.isEmpty()) {
                throw new AuraHandledException('Case not found or access denied');
            }

            Case caseRecord = cases[0];
            TRM_DuplicateDetectionModels.CaseDuplicateSummaryDTO summary =
                new TRM_DuplicateDetectionModels.CaseDuplicateSummaryDTO();

            summary.caseId = caseRecord.Id;
            summary.caseNumber = caseRecord.CaseNumber;

            // If no Bill associated, return empty summary
            if (caseRecord.BCN__c == null) {
                summary.summaryMessage = 'No Bill associated with this Case';
                return summary;
            }

            // Query Bill with Line Items and duplicate status
            List<Bill__c> bills = [
                SELECT Id, Name,
                    (SELECT Id, Name, Duplicate_Status__c, Matching_Records__c
                     FROM Bill_Line_Items__r
                     LIMIT 200)
                FROM Bill__c
                WHERE Id = :caseRecord.BCN__c
                WITH SECURITY_ENFORCED
                LIMIT 1
            ];

            if (bills.isEmpty()) {
                summary.summaryMessage = 'Associated Bill not found or access denied';
                return summary;
            }

            // Process Bill Line Items for duplicate counts
            Bill__c bill = bills[0];
            summary.totalBills = 1;
            summary.totalLineItems = bill.Bill_Line_Items__r.size();

            for (Bill_Line_Item__c lineItem : bill.Bill_Line_Items__r) {
                if (lineItem.Duplicate_Status__c == 'Exact') {
                    summary.exactMatches++;
                } else if (lineItem.Duplicate_Status__c == 'Potential') {
                    summary.potentialMatches++;
                }
            }

            // Calculate derived values
            summary.calculateDerivedValues();

            return summary;

        } catch (Exception e) {
            System.debug('TRM_DuplicateDetectionApi.getCaseDuplicateSummary error: ' + e.getMessage());
            throw new AuraHandledException('Error retrieving Case duplicate summary: ' + e.getMessage());
        }
    }

    /**
     * @description Get all duplicate matches for a Case with comprehensive details
     * ADDED: For comprehensive Case-level duplicate modal
     * @param caseId The Case record ID
     * @return List<TRM_DuplicateDetectionModels.CaseMatchDTO> All duplicate matches with Case navigation
     */
    @AuraEnabled(cacheable=true)
    public static List<TRM_DuplicateDetectionModels.CaseMatchDTO> getCaseAllDuplicateMatches(Id caseId) {
        try {
            // Input validation
            if (caseId == null) {
                throw new AuraHandledException('Case ID is required');
            }

            // Validate record ID is for Case
            String objectType = caseId.getSObjectType().getDescribe().getName();
            if (objectType != 'Case') {
                throw new AuraHandledException('Invalid record type. Expected Case, got: ' + objectType);
            }

            List<TRM_DuplicateDetectionModels.CaseMatchDTO> allMatches =
                new List<TRM_DuplicateDetectionModels.CaseMatchDTO>();

            // Query Case with Bill relationship
            List<Case> cases = [
                SELECT Id, CaseNumber, BCN__c
                FROM Case
                WHERE Id = :caseId
                WITH SECURITY_ENFORCED
                LIMIT 1
            ];

            if (cases.isEmpty()) {
                throw new AuraHandledException('Case not found or access denied');
            }

            Case caseRecord = cases[0];

            // If no Bill associated, return empty list
            if (caseRecord.BCN__c == null) {
                return allMatches;
            }

            // Query Bill Line Items with duplicate status (cannot filter on Long Text Area field)
            List<Bill_Line_Item__c> lineItems = [
                SELECT Id, Name, Duplicate_Status__c, Matching_Records__c,
                       Charge__c, Service_Start_Date__c, Service_End_Date__c,
                       CPT_HCPCS_NDC__c, CreatedDate, CreatedBy.Name,
                       Bill__r.Id, Bill__r.External_Id__c, Bill__r.Patient_Id__c,
                       Bill__r.Bill_Case_Data__r.Id, Bill__r.Bill_Case_Data__r.CaseNumber
                FROM Bill_Line_Item__c
                WHERE Bill__c = :caseRecord.BCN__c
                AND Duplicate_Status__c IN ('Exact', 'Potential')
                WITH SECURITY_ENFORCED
                LIMIT 200
            ];

            // Process each line item's matching records (filter in Apex for Long Text Area field)
            for (Bill_Line_Item__c lineItem : lineItems) {
                // Skip line items without matching records (Apex-level filter)
                if (String.isBlank(lineItem.Matching_Records__c)) {
                    continue;
                }

                try {
                    // Parse JSON matching records
                    List<TRM_DuplicateDetectionModels.MatchDTO> matches =
                        (List<TRM_DuplicateDetectionModels.MatchDTO>)
                        JSON.deserialize(lineItem.Matching_Records__c,
                            List<TRM_DuplicateDetectionModels.MatchDTO>.class);

                    // Convert each match to CaseMatchDTO with enhanced properties
                    for (TRM_DuplicateDetectionModels.MatchDTO match : matches) {
                        TRM_DuplicateDetectionModels.CaseMatchDTO caseMatch =
                            new TRM_DuplicateDetectionModels.CaseMatchDTO();

                        // Copy base properties
                        caseMatch.recordId = match.recordId;
                        caseMatch.recordName = match.recordName;
                        caseMatch.matchType = match.matchType;
                        caseMatch.confidence = match.confidence;
                        caseMatch.billExternalId = match.billExternalId;
                        caseMatch.chargeAmount = match.chargeAmount;
                        caseMatch.serviceStartDate = match.serviceStartDate;
                        caseMatch.serviceEndDate = match.serviceEndDate;
                        caseMatch.procedureCode = match.procedureCode;
                        caseMatch.patientId = match.patientId;
                        caseMatch.createdDate = match.createdDate;
                        caseMatch.createdBy = match.createdBy;

                        // Set Case information for navigation
                        caseMatch.caseId = caseRecord.Id;
                        caseMatch.caseNumber = caseRecord.CaseNumber;

                        // Calculate derived display properties
                        caseMatch.calculateDerivedValues();

                        allMatches.add(caseMatch);
                    }

                } catch (JSONException jsonEx) {
                    System.debug('TRM_DuplicateDetectionApi: JSON parsing error for line item ' +
                               lineItem.Id + ': ' + jsonEx.getMessage());
                    // Continue processing other line items
                }
            }

            return allMatches;

        } catch (Exception e) {
            System.debug('TRM_DuplicateDetectionApi.getCaseAllDuplicateMatches error: ' + e.getMessage());
            throw new AuraHandledException('Error retrieving Case duplicate matches: ' + e.getMessage());
        }
    }

    /**
     * @description Get Bill Line Items with matching records for modal display
     * ADDED: For Bill-level duplicate details modal
     * @param billId The Bill record ID
     * @return List<Bill_Line_Item__c> Line items that have matching records
     */
    @AuraEnabled(cacheable=true)
    public static List<Bill_Line_Item__c> getBillLineItemsWithMatches(Id billId) {
        try {
            // Input validation
            if (billId == null) {
                throw new AuraHandledException('Bill ID is required');
            }

            // Validate record ID is for Bill
            String objectType = billId.getSObjectType().getDescribe().getName();
            if (objectType != 'Bill__c') {
                throw new AuraHandledException('Invalid record type. Expected Bill__c, got: ' + objectType);
            }

            // Query Bill Line Items that have matching records
            // Note: Cannot filter on Matching_Records__c (Long Text Area) in SOQL, so filter in Apex
            List<Bill_Line_Item__c> allLineItems = [
                SELECT Id, Name, Duplicate_Status__c, Matching_Records__c,
                       CPT_HCPCS_NDC__c, Charge__c, Service_Start_Date__c, Service_End_Date__c
                FROM Bill_Line_Item__c
                WHERE Bill__c = :billId
                  AND Duplicate_Status__c IN ('Exact', 'Potential')
                WITH SECURITY_ENFORCED
                ORDER BY Duplicate_Status__c, Name
            ];

            // Filter to only items that have matching records (cannot do in SOQL for Long Text Area)
            List<Bill_Line_Item__c> lineItemsWithMatches = new List<Bill_Line_Item__c>();
            for (Bill_Line_Item__c item : allLineItems) {
                if (String.isNotBlank(item.Matching_Records__c)) {
                    lineItemsWithMatches.add(item);
                }
            }

            return lineItemsWithMatches;

        } catch (Exception e) {
            System.debug('TRM_DuplicateDetectionApi.getBillLineItemsWithMatches error: ' + e.getMessage());
            throw new AuraHandledException('Error retrieving Bill line items with matches: ' + e.getMessage());
        }
    }
}