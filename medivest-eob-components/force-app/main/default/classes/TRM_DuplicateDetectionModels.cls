/**
 * @description Data Transfer Objects (DTOs) for Medivest Duplicate Detection System
 * @author Trinity Development Team
 * @date 2025-08-30
 * @version 2.0.0
 * 
 * This class follows Trinity design principles:
 * - Comprehensive @AuraEnabled properties for LWC integration
 * - Proper initialization in constructors with default values
 * - Nested DTO support for complex data structures
 * - Type-safe property definitions
 */
public with sharing class TRM_DuplicateDetectionModels {
    
    /**
     * @description Main data container for duplicate detection results
     * Used by LWC components to display duplicate information
     */
    public class DuplicateDataDTO {
        @AuraEnabled public String duplicateStatus { get; set; }
        @AuraEnabled public List<MatchDTO> matches { get; set; }
        @AuraEnabled public DateTime lastCheck { get; set; }
        @AuraEnabled public Decimal confidence { get; set; }
        @AuraEnabled public Integer totalMatches { get; set; }
        @AuraEnabled public BillLineItemDTO sourceRecord { get; set; }
        @AuraEnabled public ConfigurationDTO configuration { get; set; }
        
        /**
         * @description Constructor with safe defaults
         */
        public DuplicateDataDTO() {
            matches = new List<MatchDTO>();
            duplicateStatus = 'None';
            confidence = 0.0;
            totalMatches = 0;
            configuration = new ConfigurationDTO();
        }
    }
    
    /**
     * @description Individual match information for duplicate records
     * Contains all necessary data for comparison and navigation
     * ENHANCED: Added Case details and styling properties for modal display
     * VIRTUAL: Allows inheritance by CaseMatchDTO
     */
    public virtual class MatchDTO {
        @AuraEnabled public Id recordId { get; set; }
        @AuraEnabled public String recordName { get; set; }
        @AuraEnabled public String matchType { get; set; }
        @AuraEnabled public Decimal confidence { get; set; }
        @AuraEnabled public String billExternalId { get; set; }
        @AuraEnabled public Decimal chargeAmount { get; set; }
        @AuraEnabled public Id billId { get; set; }                    // ADDED: Bill record ID for navigation
        @AuraEnabled public String caseNumber { get; set; }            // ADDED: Case number for display
        @AuraEnabled public String matchTypeClass { get; set; }        // ADDED: CSS class for styling
        @AuraEnabled public Date serviceStartDate { get; set; }
        @AuraEnabled public Date serviceEndDate { get; set; }
        @AuraEnabled public String procedureCode { get; set; }
        @AuraEnabled public String patientId { get; set; }
        @AuraEnabled public DateTime createdDate { get; set; }
        @AuraEnabled public String createdBy { get; set; }
        
        /**
         * @description Constructor with safe defaults
         */
        public MatchDTO() {
            confidence = 0.0;
            matchType = 'Unknown';
        }
        
        /**
         * @description Constructor with Bill Line Item record
         * @param record The Bill Line Item record to convert to DTO
         */
        public MatchDTO(Bill_Line_Item__c record) {
            this();
            if (record != null) {
                this.recordId = record.Id;
                this.recordName = record.Name;
                this.chargeAmount = record.Charge__c;
                this.serviceStartDate = record.Service_Start_Date__c;
                this.serviceEndDate = record.Service_End_Date__c;
                this.procedureCode = record.CPT_HCPCS_NDC__c;
                this.createdDate = record.CreatedDate;

                // Handle related Bill information safely
                if (record.Bill__r != null) {
                    this.billId = record.Bill__r.Id;                    // ENHANCED: Bill ID for navigation
                    this.billExternalId = record.Bill__r.External_Id__c;
                    this.patientId = record.Bill__r.Patient_Id__c;

                    // ENHANCED: Case information for navigation
                    if (record.Bill__r.Bill_Case_Data__r != null) {
                        this.caseNumber = record.Bill__r.Bill_Case_Data__r.CaseNumber;
                    }
                }

                // Handle created by information safely
                if (record.CreatedBy != null) {
                    this.createdBy = record.CreatedBy.Name;
                }

                // ENHANCED: Set CSS class based on match type
                this.matchTypeClass = getMatchTypeClass();
            }
        }

        /**
         * @description Get CSS class for match type styling
         * @return String CSS class name for styling
         */
        private String getMatchTypeClass() {
            if (this.matchType == 'Exact') {
                return 'match-exact';
            } else if (this.matchType == 'Potential') {
                return 'match-potential';
            }
            return 'match-unknown';
        }
    }
    
    /**
     * @description Bill Line Item data structure
     * Represents the source record being checked for duplicates
     */
    public class BillLineItemDTO {
        @AuraEnabled public Id recordId { get; set; }
        @AuraEnabled public String recordName { get; set; }
        @AuraEnabled public String procedureCode { get; set; }
        @AuraEnabled public Decimal chargeAmount { get; set; }
        @AuraEnabled public Date serviceStartDate { get; set; }
        @AuraEnabled public Date serviceEndDate { get; set; }
        @AuraEnabled public String patientId { get; set; }
        @AuraEnabled public String billExternalId { get; set; }
        @AuraEnabled public Id billId { get; set; }                    // ADDED: Bill record ID for modal navigation
        @AuraEnabled public String duplicateStatus { get; set; }
        @AuraEnabled public DateTime lastDuplicateCheck { get; set; }
        @AuraEnabled public Decimal duplicateConfidence { get; set; }
        
        /**
         * @description Constructor with safe defaults
         */
        public BillLineItemDTO() {
            duplicateStatus = 'None';
            duplicateConfidence = 0.0;
        }
        
        /**
         * @description Constructor with Bill Line Item record
         * @param record The Bill Line Item record to convert to DTO
         */
        public BillLineItemDTO(Bill_Line_Item__c record) {
            this();
            if (record != null) {
                this.recordId = record.Id;
                this.recordName = record.Name;
                this.procedureCode = record.CPT_HCPCS_NDC__c;
                this.chargeAmount = record.Charge__c;
                this.serviceStartDate = record.Service_Start_Date__c;
                this.serviceEndDate = record.Service_End_Date__c;
                this.duplicateStatus = record.Duplicate_Status__c;
                this.lastDuplicateCheck = record.Last_Duplicate_Check__c;
                this.duplicateConfidence = record.Duplicate_Confidence__c;
                
                // Handle related Bill information safely
                if (record.Bill__r != null) {
                    this.billId = record.Bill__c;                      // ADDED: Bill record ID
                    this.billExternalId = record.Bill__r.External_Id__c;
                    this.patientId = record.Bill__r.Patient_Id__c;
                }
            }
        }
    }
    
    /**
     * @description System configuration settings for duplicate detection
     * Allows for configurable matching criteria and tolerances
     */
    public class ConfigurationDTO {
        @AuraEnabled public Decimal chargeTolerance { get; set; }
        @AuraEnabled public Integer dateWindowYears { get; set; }
        @AuraEnabled public Boolean enableBillWarnings { get; set; }
        @AuraEnabled public Boolean enableProviderMatching { get; set; }
        @AuraEnabled public Integer maxMatchesReturned { get; set; }
        @AuraEnabled public Boolean enableConfidenceScoring { get; set; }
        
        /**
         * @description Constructor with business-approved defaults
         * Based on Ray's feedback from 2025-08-29
         */
        public ConfigurationDTO() {
            chargeTolerance = 0.01;           // ±$0.01 for exact matches
            dateWindowYears = 5;              // ±5 years for potential matches
            enableBillWarnings = true;        // Bill-level warning counts
            enableProviderMatching = false;   // Removed per Ray's feedback
            maxMatchesReturned = 50;          // Prevent excessive results
            enableConfidenceScoring = true;  // Provide confidence levels
        }
    }
    
    /**
     * @description Bulk processing result container
     * Used for batch duplicate detection operations
     */
    public class BulkProcessingResultDTO {
        @AuraEnabled public Integer totalProcessed { get; set; }
        @AuraEnabled public Integer exactMatches { get; set; }
        @AuraEnabled public Integer potentialMatches { get; set; }
        @AuraEnabled public Integer noMatches { get; set; }
        @AuraEnabled public Integer errors { get; set; }
        @AuraEnabled public List<String> errorMessages { get; set; }
        @AuraEnabled public DateTime processingStartTime { get; set; }
        @AuraEnabled public DateTime processingEndTime { get; set; }
        @AuraEnabled public Long processingTimeMs { get; set; }
        
        /**
         * @description Constructor with safe defaults
         */
        public BulkProcessingResultDTO() {
            totalProcessed = 0;
            exactMatches = 0;
            potentialMatches = 0;
            noMatches = 0;
            errors = 0;
            errorMessages = new List<String>();
            processingStartTime = System.now();
        }
        
        /**
         * @description Finalize processing metrics
         */
        public void finalizeProcessing() {
            processingEndTime = System.now();
            processingTimeMs = processingEndTime.getTime() - processingStartTime.getTime();
        }
    }
    
    /**
     * @description Audit trail entry for duplicate detection operations
     * Tracks all duplicate detection activities for compliance
     */
    public class AuditTrailDTO {
        @AuraEnabled public Id recordId { get; set; }
        @AuraEnabled public String operation { get; set; }
        @AuraEnabled public String oldStatus { get; set; }
        @AuraEnabled public String newStatus { get; set; }
        @AuraEnabled public String userId { get; set; }
        @AuraEnabled public String userName { get; set; }
        @AuraEnabled public DateTime timestamp { get; set; }
        @AuraEnabled public String details { get; set; }
        
        /**
         * @description Constructor with safe defaults
         */
        public AuditTrailDTO() {
            timestamp = System.now();
            userId = UserInfo.getUserId();
            userName = UserInfo.getName();
        }
    }

    /**
     * @description Bill-level duplicate summary for Bill record page component
     * Provides aggregate duplicate information across all line items in a Bill
     * ADDED: New DTO for Bill summary component functionality
     */
    public class BillDuplicateSummaryDTO {
        @AuraEnabled public Id billId { get; set; }
        @AuraEnabled public Integer totalLineItems { get; set; }
        @AuraEnabled public Integer exactMatches { get; set; }
        @AuraEnabled public Integer potentialMatches { get; set; }
        @AuraEnabled public Integer totalWarnings { get; set; }
        @AuraEnabled public Boolean hasWarnings { get; set; }
        @AuraEnabled public DateTime lastCheckDate { get; set; }
        @AuraEnabled public String summaryMessage { get; set; }

        /**
         * @description Constructor with safe defaults
         */
        public BillDuplicateSummaryDTO() {
            this.totalLineItems = 0;
            this.exactMatches = 0;
            this.potentialMatches = 0;
            this.totalWarnings = 0;
            this.hasWarnings = false;
            this.lastCheckDate = System.now();
        }

        /**
         * @description Calculate derived properties after setting base values
         */
        public void calculateDerivedValues() {
            this.totalWarnings = this.exactMatches + this.potentialMatches;
            this.hasWarnings = this.totalWarnings > 0;

            // Generate summary message
            if (this.totalWarnings == 0) {
                this.summaryMessage = String.format('No duplicates found ({0} line items checked)',
                    new List<Object>{ this.totalLineItems });
            } else {
                String message = String.format('{0} duplicate{1} found: ',
                    new List<Object>{ this.totalWarnings, this.totalWarnings > 1 ? 's' : '' });

                if (this.exactMatches > 0) {
                    message += String.format('{0} exact', new List<Object>{ this.exactMatches });
                }
                if (this.potentialMatches > 0) {
                    if (this.exactMatches > 0) message += ', ';
                    message += String.format('{0} potential', new List<Object>{ this.potentialMatches });
                }

                this.summaryMessage = message;
            }
        }
    }

    /**
     * @description Case-level duplicate detection summary DTO
     * ADDED: For Case-level duplicate detection enhancement
     * Used by trmCaseDuplicateSummary component
     */
    public class CaseDuplicateSummaryDTO {
        @AuraEnabled public Id caseId { get; set; }
        @AuraEnabled public String caseNumber { get; set; }
        @AuraEnabled public Integer totalBills { get; set; }
        @AuraEnabled public Integer totalLineItems { get; set; }
        @AuraEnabled public Integer exactMatches { get; set; }
        @AuraEnabled public Integer potentialMatches { get; set; }
        @AuraEnabled public Integer totalMatches { get; set; }
        @AuraEnabled public Boolean hasWarnings { get; set; }
        @AuraEnabled public DateTime lastCheckDate { get; set; }
        @AuraEnabled public String summaryMessage { get; set; }
        @AuraEnabled public String statusClass { get; set; }

        /**
         * @description Constructor with safe defaults
         */
        public CaseDuplicateSummaryDTO() {
            this.totalBills = 0;
            this.totalLineItems = 0;
            this.exactMatches = 0;
            this.potentialMatches = 0;
            this.totalMatches = 0;
            this.hasWarnings = false;
            this.lastCheckDate = System.now();
            this.summaryMessage = 'No duplicate analysis available';
            this.statusClass = 'status-none';
        }

        /**
         * @description Calculate derived properties after setting base values
         */
        public void calculateDerivedValues() {
            this.totalMatches = this.exactMatches + this.potentialMatches;
            this.hasWarnings = this.totalMatches > 0;

            // Generate summary message
            if (this.hasWarnings) {
                this.summaryMessage = 'Found ' + this.totalMatches + ' duplicate match' +
                    (this.totalMatches > 1 ? 'es' : '') + ' across ' + this.totalBills + ' bill' +
                    (this.totalBills > 1 ? 's' : '');
            } else {
                this.summaryMessage = 'No duplicates found across ' + this.totalBills + ' bill' +
                    (this.totalBills > 1 ? 's' : '') + ' (' + this.totalLineItems + ' line items)';
            }

            // Set status class for styling
            if (this.exactMatches > 0) {
                this.statusClass = 'status-exact';
            } else if (this.potentialMatches > 0) {
                this.statusClass = 'status-potential';
            } else {
                this.statusClass = 'status-none';
            }
        }
    }

    /**
     * @description Enhanced match DTO with Case navigation properties
     * ADDED: For comprehensive Case-level duplicate modal
     * Used by trmCaseAllDuplicatesModal component
     */
    public class CaseMatchDTO extends MatchDTO {
        @AuraEnabled public Id caseId { get; set; }
        @AuraEnabled public String relatedCaseUrl { get; set; }
        @AuraEnabled public String matchTypeLabel { get; set; }
        @AuraEnabled public String confidenceLabel { get; set; }
        @AuraEnabled public String formattedChargeAmount { get; set; }
        @AuraEnabled public String formattedServiceDates { get; set; }

        /**
         * @description Constructor with safe defaults
         */
        public CaseMatchDTO() {
            super();
            this.matchTypeLabel = 'Unknown Match';
            this.confidenceLabel = '0%';
            this.formattedChargeAmount = '$0.00';
            this.formattedServiceDates = 'No dates available';
        }

        /**
         * @description Constructor with Bill Line Item record and Case information
         * @param record The Bill Line Item record to convert to DTO
         * @param relatedCaseId The related Case ID for navigation
         */
        public CaseMatchDTO(Bill_Line_Item__c record, Id relatedCaseId) {
            super(record);
            this.caseId = relatedCaseId;
            calculateDerivedValues();
        }

        /**
         * @description Calculate derived display properties
         */
        public void calculateDerivedValues() {
            // Format match type label
            if (this.matchType == 'Exact') {
                this.matchTypeLabel = 'Exact Match';
            } else if (this.matchType == 'Potential') {
                this.matchTypeLabel = 'Potential Match';
            } else {
                this.matchTypeLabel = 'Unknown Match';
            }

            // Format confidence label
            if (this.confidence != null) {
                this.confidenceLabel = String.valueOf(this.confidence.intValue()) + '%';
            }

            // Format charge amount
            if (this.chargeAmount != null) {
                this.formattedChargeAmount = '$' + String.valueOf(this.chargeAmount.setScale(2));
            }

            // Format service dates
            if (this.serviceStartDate != null && this.serviceEndDate != null) {
                if (this.serviceStartDate == this.serviceEndDate) {
                    this.formattedServiceDates = this.serviceStartDate.format();
                } else {
                    this.formattedServiceDates = this.serviceStartDate.format() + ' - ' +
                        this.serviceEndDate.format();
                }
            } else if (this.serviceStartDate != null) {
                this.formattedServiceDates = this.serviceStartDate.format();
            }

            // Generate Case navigation URL
            if (this.caseId != null) {
                this.relatedCaseUrl = '/lightning/r/Case/' + this.caseId + '/view';
            }
        }
    }
}