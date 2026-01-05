/**
 * @description Handler class for Bill Line Item duplicate detection triggers
 * @author Trinity Development Team
 * @date 2025-08-30
 * @version 2.0.0
 * 
 * This class follows Trinity design principles:
 * - Trigger handler pattern with clear separation from business logic
 * - Recursive execution prevention
 * - Comprehensive error handling and logging
 * - Delegation to service layer for processing
 * - Bulk processing support for governor limit compliance
 */
public with sharing class TRM_DuplicateDetectionHandler {
    
    // Prevent recursive trigger execution
    private static Boolean isProcessing = false;
    
    // Debug logging toggle - can be controlled via Custom Settings later
    private static Boolean DEBUG_LOGGING = true;
    
    /**
     * @description Main entry point for duplicate detection from triggers
     * @param newRecords List of new or updated Bill Line Item records
     */
    public static void detectDuplicates(List<Bill_Line_Item__c> newRecords) {
        // Prevent recursive execution
        if (isProcessing) {
            if (DEBUG_LOGGING) {
                System.debug('TRM_DuplicateDetectionHandler: Skipping recursive execution');
            }
            return;
        }
        
        // Validate input
        if (newRecords == null || newRecords.isEmpty()) {
            if (DEBUG_LOGGING) {
                System.debug('TRM_DuplicateDetectionHandler: No records to process');
            }
            return;
        }
        
        try {
            // Set processing flag to prevent recursion
            isProcessing = true;
            
            if (DEBUG_LOGGING) {
                System.debug('TRM_DuplicateDetectionHandler: Starting duplicate detection for ' + 
                           newRecords.size() + ' records');
            }
            
            // Delegate to service layer for business logic
            TRM_DuplicateDetectionModels.BulkProcessingResultDTO result = 
                TRM_DuplicateDetectionService.detectDuplicates(newRecords);
            
            // Log processing results
            if (DEBUG_LOGGING) {
                System.debug('TRM_DuplicateDetectionHandler: Processing completed. ' +
                           'Total: ' + result.totalProcessed + 
                           ', Exact: ' + result.exactMatches + 
                           ', Potential: ' + result.potentialMatches + 
                           ', None: ' + result.noMatches + 
                           ', Errors: ' + result.errors + 
                           ', Time: ' + result.processingTimeMs + 'ms');
            }
            
            // Log any errors that occurred during processing
            if (result.errors > 0) {
                System.debug('TRM_DuplicateDetectionHandler: Errors occurred during processing:');
                for (String errorMessage : result.errorMessages) {
                    System.debug('  - ' + errorMessage);
                }
            }
            
        } catch (Exception e) {
            // Log the error but don't throw to avoid breaking the transaction
            System.debug('TRM_DuplicateDetectionHandler: Unexpected error during duplicate detection: ' + 
                       e.getMessage());
            System.debug('Stack trace: ' + e.getStackTraceString());
            
            // In production, you might want to create a custom error log record
            // or send an alert to administrators
            
        } finally {
            // Always reset the processing flag
            isProcessing = false;
        }
    }
    
    /**
     * @description Handle after insert trigger events
     * @param newRecords List of newly inserted Bill Line Item records
     */
    public static void handleAfterInsert(List<Bill_Line_Item__c> newRecords) {
        if (DEBUG_LOGGING) {
            System.debug('TRM_DuplicateDetectionHandler: Handling after insert for ' + 
                       newRecords.size() + ' records');
        }
        
        detectDuplicates(newRecords);
    }
    
    /**
     * @description Handle after update trigger events
     * @param newRecords List of updated Bill Line Item records
     * @param oldRecords Map of old Bill Line Item records
     */
    public static void handleAfterUpdate(
        List<Bill_Line_Item__c> newRecords, 
        Map<Id, Bill_Line_Item__c> oldRecords
    ) {
        if (DEBUG_LOGGING) {
            System.debug('TRM_DuplicateDetectionHandler: Handling after update for ' + 
                       newRecords.size() + ' records');
        }
        
        // Filter records that have changes in fields relevant to duplicate detection
        List<Bill_Line_Item__c> recordsToProcess = new List<Bill_Line_Item__c>();
        
        for (Bill_Line_Item__c newRecord : newRecords) {
            Bill_Line_Item__c oldRecord = oldRecords.get(newRecord.Id);
            
            if (oldRecord != null && hasRelevantChanges(newRecord, oldRecord)) {
                recordsToProcess.add(newRecord);
            }
        }
        
        if (!recordsToProcess.isEmpty()) {
            if (DEBUG_LOGGING) {
                System.debug('TRM_DuplicateDetectionHandler: Processing ' + recordsToProcess.size() + 
                           ' records with relevant changes');
            }
            detectDuplicates(recordsToProcess);
        } else if (DEBUG_LOGGING) {
            System.debug('TRM_DuplicateDetectionHandler: No records with relevant changes to process');
        }
    }
    
    /**
     * @description Check if a record has changes relevant to duplicate detection
     * @param newRecord The updated record
     * @param oldRecord The previous version of the record
     * @return Boolean True if relevant changes are detected
     */
    private static Boolean hasRelevantChanges(
        Bill_Line_Item__c newRecord, 
        Bill_Line_Item__c oldRecord
    ) {
        // Check for changes in fields used for duplicate detection
        return (
            newRecord.CPT_HCPCS_NDC__c != oldRecord.CPT_HCPCS_NDC__c ||
            newRecord.Charge__c != oldRecord.Charge__c ||
            newRecord.Service_Start_Date__c != oldRecord.Service_Start_Date__c ||
            newRecord.Service_End_Date__c != oldRecord.Service_End_Date__c ||
            newRecord.Bill__c != oldRecord.Bill__c
        );
    }
    
    /**
     * @description Get current processing status (for testing and monitoring)
     * @return Boolean True if duplicate detection is currently processing
     */
    @TestVisible
    private static Boolean getProcessingStatus() {
        return isProcessing;
    }
    
    /**
     * @description Reset processing status (for testing purposes)
     */
    @TestVisible
    private static void resetProcessingStatus() {
        isProcessing = false;
    }
    
    /**
     * @description Enable or disable debug logging (for testing purposes)
     * @param enabled True to enable debug logging, false to disable
     */
    @TestVisible
    private static void setDebugLogging(Boolean enabled) {
        DEBUG_LOGGING = enabled;
    }
}