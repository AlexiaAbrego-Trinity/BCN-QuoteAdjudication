/**
 * @description Service layer for Medivest Duplicate Detection System
 * @author Trinity Development Team
 * @date 2025-08-30
 * @version 2.0.0
 * 
 * This class follows Trinity design principles:
 * - Business logic and complex data processing
 * - Optimized SOQL queries with proper joins
 * - Bulk processing patterns for governor limit compliance
 * - Comprehensive error handling and logging
 * 
 * Business Rules (verified 2025-08-29 with Ray):
 * - Date tolerance: Minimum 5 years, configurable, no cutoff
 * - Charge variance: Only for exact matches (±$0.01), ignored for potential
 * - Service date fields: Service_Start_Date__c and Service_End_Date__c
 * - Provider matching: REMOVED - limit to same member/patient only
 * - Bill-level warnings: Count line items with duplicate status != 'None'
 */
public with sharing class TRM_DuplicateDetectionService {
    
    // Configuration constants (make configurable via Custom Settings later)
    private static final Decimal CHARGE_TOLERANCE = 0.01;
    private static final Integer DEFAULT_DATE_WINDOW_YEARS = 5;
    private static final Integer MAX_MATCHES_RETURNED = 50;
    private static final Boolean DEBUG_LOGGING = true;
    
    /**
     * @description Main entry point for duplicate detection processing
     * @param newRecords List of Bill Line Item records to process
     * @return TRM_DuplicateDetectionModels.BulkProcessingResultDTO Processing results
     */
    public static TRM_DuplicateDetectionModels.BulkProcessingResultDTO detectDuplicates(
        List<Bill_Line_Item__c> newRecords
    ) {
        TRM_DuplicateDetectionModels.BulkProcessingResultDTO result = 
            new TRM_DuplicateDetectionModels.BulkProcessingResultDTO();
        
        if (newRecords == null || newRecords.isEmpty()) {
            if (DEBUG_LOGGING) {
                System.debug('TRM_DuplicateDetectionService: No records to process');
            }
            result.finalizeProcessing();
            return result;
        }
        
        try {
            // Step 1: Filter records that have required fields
            List<Bill_Line_Item__c> validRecords = filterValidRecords(newRecords);
            result.totalProcessed = validRecords.size();
            
            if (validRecords.isEmpty()) {
                if (DEBUG_LOGGING) {
                    System.debug('TRM_DuplicateDetectionService: No valid records to process');
                }
                result.finalizeProcessing();
                return result;
            }
            
            // Step 2: Query records with Bill relationship for Patient_Id__c
            Map<Id, Bill_Line_Item__c> recordsWithBillInfo = queryRecordsWithBillInfo(validRecords);
            
            // Step 3: Process each record for duplicates
            List<Bill_Line_Item__c> recordsToUpdate = new List<Bill_Line_Item__c>();
            Set<Id> billIdsToUpdate = new Set<Id>();
            
            for (Bill_Line_Item__c record : recordsWithBillInfo.values()) {
                try {
                    processRecordForDuplicates(record, result);
                    recordsToUpdate.add(record);
                    
                    // Track bills that need warning count updates
                    if (record.Bill__c != null) {
                        billIdsToUpdate.add(record.Bill__c);
                    }
                    
                } catch (Exception e) {
                    result.errors++;
                    result.errorMessages.add('Record ' + record.Id + ': ' + e.getMessage());
                    if (DEBUG_LOGGING) {
                        System.debug('TRM_DuplicateDetectionService: Error processing record ' + 
                                   record.Id + ': ' + e.getMessage());
                    }
                }
            }
            
            // Step 4: Update records with duplicate status
            if (!recordsToUpdate.isEmpty()) {
                update recordsToUpdate;
            }
            
            // Step 5: Update Bill-level warning counts
            if (!billIdsToUpdate.isEmpty()) {
                updateBillWarningCounts(billIdsToUpdate);
            }
            
        } catch (Exception e) {
            result.errors++;
            result.errorMessages.add('Bulk processing error: ' + e.getMessage());
            if (DEBUG_LOGGING) {
                System.debug('TRM_DuplicateDetectionService: Bulk processing error: ' + e.getMessage());
            }
        }
        
        result.finalizeProcessing();
        return result;
    }
    
    /**
     * @description Get comprehensive duplicate data for a specific record
     * @param recordId The Bill Line Item record ID
     * @return TRM_DuplicateDetectionModels.DuplicateDataDTO Complete duplicate information
     */
    public static TRM_DuplicateDetectionModels.DuplicateDataDTO getDuplicateData(Id recordId) {
        TRM_DuplicateDetectionModels.DuplicateDataDTO result = 
            new TRM_DuplicateDetectionModels.DuplicateDataDTO();
        
        try {
            // Query the record with all duplicate-related fields
            List<Bill_Line_Item__c> records = [
                SELECT Id, Name, CPT_HCPCS_NDC__c, Charge__c, Service_Start_Date__c,
                       Service_End_Date__c, Duplicate_Status__c, Matching_Records__c,
                       Last_Duplicate_Check__c, Duplicate_Confidence__c,
                       Bill__c, Bill__r.External_Id__c, Bill__r.Patient_Id__c,
                       CreatedDate, CreatedBy.Name
                FROM Bill_Line_Item__c
                WHERE Id = :recordId
                WITH SECURITY_ENFORCED
                LIMIT 1
            ];
            
            if (records.isEmpty()) {
                throw new AuraHandledException('Record not found: ' + recordId);
            }
            
            Bill_Line_Item__c record = records[0];
            
            // Populate source record information
            result.sourceRecord = new TRM_DuplicateDetectionModels.BillLineItemDTO(record);
            result.duplicateStatus = record.Duplicate_Status__c != null ? 
                record.Duplicate_Status__c : 'None';
            result.lastCheck = record.Last_Duplicate_Check__c;
            result.confidence = record.Duplicate_Confidence__c != null ? 
                record.Duplicate_Confidence__c : 0.0;
            
            // Parse and populate matching records
            if (String.isNotBlank(record.Matching_Records__c)) {
                result.matches = parseMatchingRecords(record.Matching_Records__c);
                result.totalMatches = result.matches.size();
            }
            
        } catch (Exception e) {
            if (DEBUG_LOGGING) {
                System.debug('TRM_DuplicateDetectionService: Error getting duplicate data for ' + 
                           recordId + ': ' + e.getMessage());
            }
            throw new AuraHandledException('Error retrieving duplicate data: ' + e.getMessage());
        }
        
        return result;
    }
    
    /**
     * @description Find exact matches for a Bill Line Item record
     * @param record The record to find matches for
     * @param patientId The patient ID to scope matches to
     * @return List<Bill_Line_Item__c> List of exact matching records
     */
    public static List<Bill_Line_Item__c> findExactMatches(
        Bill_Line_Item__c record, 
        String patientId
    ) {
        if (String.isBlank(patientId) || record.CPT_HCPCS_NDC__c == null || 
            record.Charge__c == null || record.Service_Start_Date__c == null) {
            return new List<Bill_Line_Item__c>();
        }
        
        try {
            // Calculate charge range for SOQL compatibility (ABS not supported in WHERE clause)
            Decimal minCharge = record.Charge__c - CHARGE_TOLERANCE;
            Decimal maxCharge = record.Charge__c + CHARGE_TOLERANCE;

            return [
                SELECT Id, Name, CPT_HCPCS_NDC__c, Charge__c, Service_Start_Date__c,
                       Service_End_Date__c, Bill__r.External_Id__c, Bill__r.Patient_Id__c,
                       CreatedDate, CreatedBy.Name
                FROM Bill_Line_Item__c
                WHERE Bill__r.Patient_Id__c = :patientId
                  AND CPT_HCPCS_NDC__c = :record.CPT_HCPCS_NDC__c
                  AND Service_Start_Date__c = :record.Service_Start_Date__c
                  AND Service_End_Date__c = :record.Service_End_Date__c
                  AND Charge__c >= :minCharge
                  AND Charge__c <= :maxCharge
                  AND Id != :record.Id
                WITH SECURITY_ENFORCED
                ORDER BY CreatedDate DESC
                LIMIT :MAX_MATCHES_RETURNED
            ];
        } catch (Exception e) {
            if (DEBUG_LOGGING) {
                System.debug('TRM_DuplicateDetectionService: Error finding exact matches: ' + e.getMessage());
            }
            return new List<Bill_Line_Item__c>();
        }
    }
    
    /**
     * @description Find potential matches for a Bill Line Item record
     * @param record The record to find matches for
     * @param patientId The patient ID to scope matches to
     * @return List<Bill_Line_Item__c> List of potentially matching records
     */
    public static List<Bill_Line_Item__c> findPotentialMatches(
        Bill_Line_Item__c record, 
        String patientId
    ) {
        if (String.isBlank(patientId) || record.CPT_HCPCS_NDC__c == null || 
            record.Service_Start_Date__c == null) {
            return new List<Bill_Line_Item__c>();
        }
        
        try {
            // Calculate date range (±5 years, configurable)
            Date startRange = record.Service_Start_Date__c.addYears(-DEFAULT_DATE_WINDOW_YEARS);
            Date endRange = record.Service_Start_Date__c.addYears(DEFAULT_DATE_WINDOW_YEARS);
            
            return [
                SELECT Id, Name, CPT_HCPCS_NDC__c, Charge__c, Service_Start_Date__c,
                       Service_End_Date__c, Bill__r.External_Id__c, Bill__r.Patient_Id__c,
                       CreatedDate, CreatedBy.Name
                FROM Bill_Line_Item__c
                WHERE Bill__r.Patient_Id__c = :patientId
                  AND CPT_HCPCS_NDC__c = :record.CPT_HCPCS_NDC__c
                  AND Service_Start_Date__c >= :startRange
                  AND Service_Start_Date__c <= :endRange
                  AND Id != :record.Id
                WITH SECURITY_ENFORCED
                ORDER BY Service_Start_Date__c DESC, CreatedDate DESC
                LIMIT :MAX_MATCHES_RETURNED
            ];
        } catch (Exception e) {
            if (DEBUG_LOGGING) {
                System.debug('TRM_DuplicateDetectionService: Error finding potential matches: ' + e.getMessage());
            }
            return new List<Bill_Line_Item__c>();
        }
    }
    
    /**
     * @description Update Bill-level warning counts for duplicate line items
     * @param billIds Set of Bill IDs to update warning counts for
     */
    public static void updateBillWarningCounts(Set<Id> billIds) {
        if (billIds == null || billIds.isEmpty()) {
            return;
        }
        
        try {
            // Query aggregated duplicate counts by Bill
            List<AggregateResult> duplicateCounts = [
                SELECT Bill__c, COUNT(Id) duplicateCount
                FROM Bill_Line_Item__c
                WHERE Bill__c IN :billIds
                  AND Duplicate_Status__c != 'None'
                  AND Duplicate_Status__c != null
                WITH SECURITY_ENFORCED
                GROUP BY Bill__c
            ];
            
            // Build map of Bill ID to duplicate count
            Map<Id, Integer> billToDuplicateCount = new Map<Id, Integer>();
            for (AggregateResult ar : duplicateCounts) {
                billToDuplicateCount.put(
                    (Id)ar.get('Bill__c'), 
                    (Integer)ar.get('duplicateCount')
                );
            }
            
            // Query Bills to update
            List<Bill__c> billsToUpdate = [
                SELECT Id, Duplicate_Warning_Count__c
                FROM Bill__c
                WHERE Id IN :billIds
                WITH SECURITY_ENFORCED
            ];
            
            // Update warning counts
            for (Bill__c bill : billsToUpdate) {
                Integer duplicateCount = billToDuplicateCount.get(bill.Id);
                bill.Duplicate_Warning_Count__c = duplicateCount != null ? duplicateCount : 0;
            }
            
            if (!billsToUpdate.isEmpty()) {
                update billsToUpdate;
            }
            
        } catch (Exception e) {
            if (DEBUG_LOGGING) {
                System.debug('TRM_DuplicateDetectionService: Error updating bill warning counts: ' + 
                           e.getMessage());
            }
            // Don't throw exception here to avoid breaking main duplicate detection flow
        }
    }
    
    /**
     * @description Filter records that have required fields for duplicate detection
     * @param records List of records to filter
     * @return List<Bill_Line_Item__c> Filtered list of valid records
     */
    private static List<Bill_Line_Item__c> filterValidRecords(List<Bill_Line_Item__c> records) {
        List<Bill_Line_Item__c> validRecords = new List<Bill_Line_Item__c>();

        for (Bill_Line_Item__c record : records) {
            if (record.CPT_HCPCS_NDC__c != null &&
                record.Charge__c != null &&
                record.Service_Start_Date__c != null) {
                validRecords.add(record);
            } else if (DEBUG_LOGGING) {
                System.debug('TRM_DuplicateDetectionService: Skipping record ' + record.Id +
                           ' - Missing required fields');
            }
        }

        return validRecords;
    }

    /**
     * @description Query records with Bill relationship information
     * @param records List of records to query
     * @return Map<Id, Bill_Line_Item__c> Map of record ID to record with Bill info
     */
    private static Map<Id, Bill_Line_Item__c> queryRecordsWithBillInfo(
        List<Bill_Line_Item__c> records
    ) {
        Set<Id> recordIds = new Set<Id>();
        for (Bill_Line_Item__c record : records) {
            recordIds.add(record.Id);
        }

        List<Bill_Line_Item__c> queriedRecords = [
            SELECT Id, Name, CPT_HCPCS_NDC__c, Charge__c, Service_Start_Date__c,
                   Service_End_Date__c, Bill__c, Bill__r.Patient_Id__c, Bill__r.External_Id__c
            FROM Bill_Line_Item__c
            WHERE Id IN :recordIds
            WITH SECURITY_ENFORCED
        ];

        Map<Id, Bill_Line_Item__c> recordMap = new Map<Id, Bill_Line_Item__c>();
        for (Bill_Line_Item__c record : queriedRecords) {
            recordMap.put(record.Id, record);
        }

        return recordMap;
    }

    /**
     * @description Process individual record for duplicate detection
     * @param record The record to process
     * @param result The bulk processing result to update
     */
    private static void processRecordForDuplicates(
        Bill_Line_Item__c record,
        TRM_DuplicateDetectionModels.BulkProcessingResultDTO result
    ) {
        String patientId = record.Bill__r?.Patient_Id__c;

        if (String.isBlank(patientId)) {
            if (DEBUG_LOGGING) {
                System.debug('TRM_DuplicateDetectionService: No patient ID for record ' + record.Id);
            }
            record.Duplicate_Status__c = 'None';
            record.Matching_Records__c = null;
            record.Last_Duplicate_Check__c = System.now();
            result.noMatches++;
            return;
        }

        // Find exact matches first
        List<Bill_Line_Item__c> exactMatches = findExactMatches(record, patientId);

        if (!exactMatches.isEmpty()) {
            record.Duplicate_Status__c = 'Exact';
            record.Matching_Records__c = serializeMatches(exactMatches, 'Exact');
            record.Duplicate_Confidence__c = 100.0;
            result.exactMatches++;
        } else {
            // Find potential matches if no exact matches
            List<Bill_Line_Item__c> potentialMatches = findPotentialMatches(record, patientId);

            if (!potentialMatches.isEmpty()) {
                record.Duplicate_Status__c = 'Potential';
                record.Matching_Records__c = serializeMatches(potentialMatches, 'Potential');
                record.Duplicate_Confidence__c = calculateConfidence(record, potentialMatches);
                result.potentialMatches++;
            } else {
                record.Duplicate_Status__c = 'None';
                record.Matching_Records__c = null;
                record.Duplicate_Confidence__c = 0.0;
                result.noMatches++;
            }
        }

        record.Last_Duplicate_Check__c = System.now();
    }

    /**
     * @description Serialize matching records to JSON for storage
     * @param matches List of matching records
     * @param matchType Type of match (Exact or Potential)
     * @return String JSON representation of matches
     */
    private static String serializeMatches(List<Bill_Line_Item__c> matches, String matchType) {
        List<TRM_DuplicateDetectionModels.MatchDTO> matchDTOs =
            new List<TRM_DuplicateDetectionModels.MatchDTO>();

        for (Bill_Line_Item__c match : matches) {
            TRM_DuplicateDetectionModels.MatchDTO matchDTO =
                new TRM_DuplicateDetectionModels.MatchDTO(match);
            matchDTO.matchType = matchType;
            matchDTO.confidence = matchType == 'Exact' ? 100.0 :
                calculateIndividualMatchConfidence(match);
            matchDTOs.add(matchDTO);
        }

        return JSON.serialize(matchDTOs);
    }

    /**
     * @description Parse matching records from JSON storage
     * @param matchingRecordsJson JSON string of matching records
     * @return List<TRM_DuplicateDetectionModels.MatchDTO> Parsed match DTOs
     */
    private static List<TRM_DuplicateDetectionModels.MatchDTO> parseMatchingRecords(
        String matchingRecordsJson
    ) {
        try {
            return (List<TRM_DuplicateDetectionModels.MatchDTO>)
                JSON.deserialize(matchingRecordsJson,
                    List<TRM_DuplicateDetectionModels.MatchDTO>.class);
        } catch (Exception e) {
            if (DEBUG_LOGGING) {
                System.debug('TRM_DuplicateDetectionService: Error parsing matching records: ' +
                           e.getMessage());
            }
            return new List<TRM_DuplicateDetectionModels.MatchDTO>();
        }
    }

    /**
     * @description Calculate confidence score for potential matches
     * @param sourceRecord The source record
     * @param matches List of potential matching records
     * @return Decimal Confidence score (0-100)
     */
    private static Decimal calculateConfidence(
        Bill_Line_Item__c sourceRecord,
        List<Bill_Line_Item__c> matches
    ) {
        if (matches.isEmpty()) {
            return 0.0;
        }

        // Simple confidence calculation based on date proximity and charge similarity
        Decimal totalConfidence = 0.0;

        for (Bill_Line_Item__c match : matches) {
            Decimal matchConfidence = calculateIndividualMatchConfidence(match);
            totalConfidence += matchConfidence;
        }

        return totalConfidence / matches.size();
    }

    /**
     * @description Calculate confidence for individual match
     * @param match The matching record
     * @return Decimal Individual match confidence (0-100)
     */
    private static Decimal calculateIndividualMatchConfidence(Bill_Line_Item__c match) {
        // For now, return a base confidence for potential matches
        // This can be enhanced with more sophisticated scoring later
        return 75.0;
    }
}