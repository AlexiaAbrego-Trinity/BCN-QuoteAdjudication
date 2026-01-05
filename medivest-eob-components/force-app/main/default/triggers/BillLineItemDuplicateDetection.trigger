/**
 * @description Trigger for Bill Line Item duplicate detection
 * @author Trinity Development Team
 * @date 2025-08-30
 * @version 2.0.0
 * 
 * This trigger follows Trinity design principles:
 * - Minimal logic in trigger, delegation to handler class
 * - Support for both insert and update operations
 * - Clean separation between trigger events and business logic
 */
trigger BillLineItemDuplicateDetection on Bill_Line_Item__c (after insert, after update) {
    
    if (Trigger.isAfter) {
        if (Trigger.isInsert) {
            // Handle new records that need duplicate detection
            TRM_DuplicateDetectionHandler.handleAfterInsert(Trigger.new);
        }
        
        if (Trigger.isUpdate) {
            // Handle updated records that may need re-evaluation
            TRM_DuplicateDetectionHandler.handleAfterUpdate(Trigger.new, Trigger.oldMap);
        }
    }
}