public class BillLineItemDuplicateHandler {

    // Prevent recursive trigger execution
    private static Boolean isProcessing = false;

    // Debug logging toggle - set to true to enable detailed logging
    private static Boolean DEBUG_LOGGING = true;

    public static void detectDuplicates(List<Bill_Line_Item__c> newRecords) {
        // Prevent recursive execution
        if (isProcessing) {
            if (DEBUG_LOGGING) System.debug('BillLineItemDuplicateHandler: Skipping recursive execution');
            return;
        }
        isProcessing = true;

        if (DEBUG_LOGGING) {
            System.debug('BillLineItemDuplicateHandler: Starting duplicate detection for ' + newRecords.size() + ' records');
        }
        // Step 1: Get the IDs of records to process
        Set<Id> recordIds = new Set<Id>();
        for (Bill_Line_Item__c record : newRecords) {
            if (record.CPT_HCPCS_NDC__c != null && record.Charge__c != null) {
                recordIds.add(record.Id);
                if (DEBUG_LOGGING) {
                    System.debug('BillLineItemDuplicateHandler: Processing record ' + record.Id +
                               ' - CPT: ' + record.CPT_HCPCS_NDC__c + ', Charge: ' + record.Charge__c);
                }
            } else {
                if (DEBUG_LOGGING) {
                    System.debug('BillLineItemDuplicateHandler: Skipping record ' + record.Id +
                               ' - Missing CPT (' + record.CPT_HCPCS_NDC__c + ') or Charge (' + record.Charge__c + ')');
                }
            }
        }

        if (recordIds.isEmpty()) {
            if (DEBUG_LOGGING) System.debug('BillLineItemDuplicateHandler: No valid records to process');
            return;
        }

        if (DEBUG_LOGGING) {
            System.debug('BillLineItemDuplicateHandler: Found ' + recordIds.size() + ' valid records to process');
        }

        // Step 2: Query records WITH related Bill information
        List<Bill_Line_Item__c> recordsWithBillInfo = [
            SELECT Id, CPT_HCPCS_NDC__c, Charge__c, Service_Start_Date__c, Service_End_Date__c,
                   Bill__r.Patient_Id__c, Bill__r.External_Id__c
            FROM Bill_Line_Item__c
            WHERE Id IN :recordIds
        ];

        if (DEBUG_LOGGING) {
            System.debug('BillLineItemDuplicateHandler: Queried ' + recordsWithBillInfo.size() + ' records with Bill data');
            for (Bill_Line_Item__c record : recordsWithBillInfo) {
                System.debug('BillLineItemDuplicateHandler: Record ' + record.Id +
                           ' - Patient: ' + record.Bill__r.Patient_Id__c +
                           ', CPT: ' + record.CPT_HCPCS_NDC__c +
                           ', Charge: ' + record.Charge__c +
                           ', Service Start: ' + record.Service_Start_Date__c +
                           ', Service End: ' + record.Service_End_Date__c);
            }
        }

        // Step 3: Process with populated Bill information
        List<Bill_Line_Item__c> recordsToUpdate = new List<Bill_Line_Item__c>();

        for (Bill_Line_Item__c record : recordsWithBillInfo) {
            if (DEBUG_LOGGING) {
                System.debug('BillLineItemDuplicateHandler: Processing record ' + record.Id + ' for duplicate detection');
            }

            List<Bill_Line_Item__c> exactMatches = findExactMatches(record);
            List<Bill_Line_Item__c> partialMatches = findPartialMatches(record);

            if (DEBUG_LOGGING) {
                System.debug('BillLineItemDuplicateHandler: Record ' + record.Id +
                           ' - Found ' + exactMatches.size() + ' exact matches, ' +
                           partialMatches.size() + ' partial matches');
            }

            if (!exactMatches.isEmpty()) {
                record.Duplicate_Status__c = 'Exact';
                record.Matching_Records__c = JSON.serialize(getMatchingIds(exactMatches));
                if (DEBUG_LOGGING) {
                    System.debug('BillLineItemDuplicateHandler: Record ' + record.Id + ' set to EXACT duplicate status');
                }
            } else if (!partialMatches.isEmpty()) {
                record.Duplicate_Status__c = 'Potential';
                record.Matching_Records__c = JSON.serialize(getMatchingIds(partialMatches));
                if (DEBUG_LOGGING) {
                    System.debug('BillLineItemDuplicateHandler: Record ' + record.Id + ' set to POTENTIAL duplicate status');
                }
            } else {
                record.Duplicate_Status__c = 'None';
                record.Matching_Records__c = null;
                if (DEBUG_LOGGING) {
                    System.debug('BillLineItemDuplicateHandler: Record ' + record.Id + ' set to NONE duplicate status');
                }
            }

            record.Last_Duplicate_Check__c = System.now();
            recordsToUpdate.add(record);
        }

        if (!recordsToUpdate.isEmpty()) {
            if (DEBUG_LOGGING) {
                System.debug('BillLineItemDuplicateHandler: Updating ' + recordsToUpdate.size() + ' records with duplicate status');
            }
            update recordsToUpdate;
            if (DEBUG_LOGGING) {
                System.debug('BillLineItemDuplicateHandler: Successfully updated records');
            }
        } else {
            if (DEBUG_LOGGING) {
                System.debug('BillLineItemDuplicateHandler: No records to update');
            }
        }

        // Reset the flag after processing
        isProcessing = false;

        if (DEBUG_LOGGING) {
            System.debug('BillLineItemDuplicateHandler: Duplicate detection completed');
        }
    }

    private static List<Bill_Line_Item__c> findExactMatches(Bill_Line_Item__c record) {
        if (DEBUG_LOGGING) {
            System.debug('BillLineItemDuplicateHandler.findExactMatches: Searching for exact matches for record ' + record.Id);
        }

        // Exact = all key non-charge fields match AND charge equals (to cents)
        // NOTE: SOQL doesn't support ABS() function, so we use range-based comparison
        Decimal chargeMin = record.Charge__c - 0.01;
        Decimal chargeMax = record.Charge__c + 0.01;

        // Extract values for bind variables
        String patientId = record.Bill__r.Patient_Id__c;
        String cptCode = record.CPT_HCPCS_NDC__c;
        Date serviceStart = record.Service_Start_Date__c;
        Date serviceEnd = record.Service_End_Date__c;
        Id recordId = record.Id;

        if (DEBUG_LOGGING) {
            System.debug('BillLineItemDuplicateHandler.findExactMatches: Search criteria - ' +
                       'Patient: ' + patientId +
                       ', CPT: ' + cptCode +
                       ', Service Start: ' + serviceStart +
                       ', Service End: ' + serviceEnd +
                       ', Charge Range: ' + chargeMin + ' to ' + chargeMax);
        }

        List<Bill_Line_Item__c> matches = [
            SELECT Id, Name, Bill__r.External_Id__c
            FROM Bill_Line_Item__c
            WHERE Bill__r.Patient_Id__c = :patientId
              AND CPT_HCPCS_NDC__c = :cptCode
              AND Service_Start_Date__c = :serviceStart
              AND Service_End_Date__c = :serviceEnd
              AND Charge__c >= :chargeMin
              AND Charge__c <= :chargeMax
              AND Id != :recordId
            LIMIT 50
        ];

        if (DEBUG_LOGGING) {
            System.debug('BillLineItemDuplicateHandler.findExactMatches: Found ' + matches.size() + ' exact matches');
            for (Bill_Line_Item__c match : matches) {
                System.debug('BillLineItemDuplicateHandler.findExactMatches: Match - ' + match.Id + ' (' + match.Name + ')');
            }
        }

        return matches;
    }

    private static List<Bill_Line_Item__c> findPartialMatches(Bill_Line_Item__c record) {
        if (DEBUG_LOGGING) {
            System.debug('BillLineItemDuplicateHandler.findPartialMatches: Searching for partial matches for record ' + record.Id);
        }

        // Potential = focus on non-charge fields only; broad date window (>= 5 years)
        Date startRange = record.Service_Start_Date__c != null ? record.Service_Start_Date__c.addYears(-5) : null;
        Date endRange   = record.Service_Start_Date__c != null ? record.Service_Start_Date__c.addYears(5)  : null;

        // Extract values for bind variables
        String patientId = record.Bill__r.Patient_Id__c;
        String cptCode = record.CPT_HCPCS_NDC__c;
        Id recordId = record.Id;

        if (DEBUG_LOGGING) {
            System.debug('BillLineItemDuplicateHandler.findPartialMatches: Search criteria - ' +
                       'Patient: ' + patientId +
                       ', CPT: ' + cptCode +
                       ', Date Range: ' + startRange + ' to ' + endRange);
        }

        List<Bill_Line_Item__c> matches;

        if (startRange != null && endRange != null) {
            if (DEBUG_LOGGING) {
                System.debug('BillLineItemDuplicateHandler.findPartialMatches: Using date range filter');
            }
            matches = [
                SELECT Id, Name, Bill__r.External_Id__c
                FROM Bill_Line_Item__c
                WHERE Bill__r.Patient_Id__c = :patientId
                  AND CPT_HCPCS_NDC__c = :cptCode
                  AND Service_Start_Date__c >= :startRange
                  AND Service_Start_Date__c <= :endRange
                  AND Id != :recordId
                LIMIT 50
            ];
        } else {
            if (DEBUG_LOGGING) {
                System.debug('BillLineItemDuplicateHandler.findPartialMatches: No date range filter (missing service start date)');
            }
            matches = [
                SELECT Id, Name, Bill__r.External_Id__c
                FROM Bill_Line_Item__c
                WHERE Bill__r.Patient_Id__c = :patientId
                  AND CPT_HCPCS_NDC__c = :cptCode
                  AND Id != :recordId
                LIMIT 50
            ];
        }

        if (DEBUG_LOGGING) {
            System.debug('BillLineItemDuplicateHandler.findPartialMatches: Found ' + matches.size() + ' partial matches');
            for (Bill_Line_Item__c match : matches) {
                System.debug('BillLineItemDuplicateHandler.findPartialMatches: Match - ' + match.Id + ' (' + match.Name + ')');
            }
        }

        return matches;
    }

    private static List<String> getMatchingIds(List<Bill_Line_Item__c> matches) {
        List<String> ids = new List<String>();
        for (Bill_Line_Item__c match : matches) {
            ids.add(match.Id);
        }
        return ids;
    }

    // NEW METHOD: For Lightning Web Component data access
    @AuraEnabled(cacheable=true)
    public static DuplicateData getDuplicateData(Id recordId) {
        try {
            // Validate input
            if (recordId == null) {
                throw new AuraHandledException('Record ID is required');
            }

            // Query the Bill Line Item with duplicate fields
            List<Bill_Line_Item__c> records = [
                SELECT Id, Duplicate_Status__c, Matching_Records__c, Last_Duplicate_Check__c
                FROM Bill_Line_Item__c
                WHERE Id = :recordId
                WITH SECURITY_ENFORCED
                LIMIT 1
            ];

            if (records.isEmpty()) {
                throw new AuraHandledException('Record not found');
            }

            Bill_Line_Item__c record = records[0];

            // Return structured data
            return new DuplicateData(
                record.Duplicate_Status__c,
                record.Matching_Records__c,
                record.Last_Duplicate_Check__c
            );

        } catch (Exception e) {
            throw new AuraHandledException('Error retrieving duplicate data: ' + e.getMessage());
        }
    }

    // Wrapper class for Lightning Web Component data
    public class DuplicateData {
        @AuraEnabled public String duplicateStatus { get; set; }
        @AuraEnabled public String matchingRecords { get; set; }
        @AuraEnabled public DateTime lastCheck { get; set; }

        public DuplicateData(String status, String matches, DateTime checkTime) {
            this.duplicateStatus = status != null ? status : 'None';
            this.matchingRecords = matches;
            this.lastCheck = checkTime;
        }
    }
}