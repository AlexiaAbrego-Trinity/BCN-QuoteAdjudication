/**
 * @description Medical Billing Service - Domain-specific service for injury, coverage, and medical scenarios
 * @author Trinity Relationship Management
 * @date 2025-01-09
 * 
 * TRINITY ARCHITECTURE: Domain-driven design following Single Responsibility Principle
 * - Focused on medical billing scenarios and injury management
 * - Clean separation from pharmacy, DME, and financial services
 * - Ray's medical billing domain expertise embedded throughout
 * 
 * RAY'S REQUIREMENTS: Realistic medical billing scenarios for Claims workflow
 * MATT'S REQUIREMENTS: Clean, maintainable, scalable architecture
 */
public with sharing class TRM_MedicalBillingService {
    
    /**
     * @description Get Injury data for medical billing scenarios
     * @param caseId The Case record ID
     * @return InjuryData wrapper with injury scenarios
     *
     * RAY'S DOMAIN: Realistic injury scenarios for Claims workflow
     * TRINITY PRINCIPLE: Use actual Salesforce data, not hardcoded values
     */
    @AuraEnabled(cacheable=true)
    public static InjuryData getInjuryData(Id caseId) {
        try {
            InjuryData result = new InjuryData();
            result.caseId = caseId;
            result.injuries = new List<InjuryScenario>();
            result.memberAccountInfo = new MemberAccountInfo();

            // Query actual Case data for injury information
            List<Case> cases = [
                SELECT Id, CaseNumber, Date_of_Injury__c,
                       Custodial_Account__r.Name, Patient_Id__c,
                       FirstName__c, LastName__c, Status,
                       trm_Diagnosis_Code__r.Name, trm_All_Diagnosis_Codes__c
                FROM Case
                WHERE Id = :caseId
                LIMIT 1
            ];

            if (cases.isEmpty()) {
                return result; // Return empty result if no case found
            }

            Case currentCase = cases[0];

            // Create injury scenario based on actual Case data
            InjuryScenario injury = new InjuryScenario();
            injury.id = String.valueOf(currentCase.Id);
            injury.caseNumber = currentCase.CaseNumber;
            injury.status = currentCase.Status;

            // TRINITY PRINCIPLE: Use ONLY actual field values - NO hardcoded data
            injury.injuryDate = currentCase.Date_of_Injury__c;
            injury.patientId = currentCase.Patient_Id__c;
            injury.firstName = currentCase.FirstName__c;
            injury.lastName = currentCase.LastName__c;
            injury.memberAccount = currentCase.Custodial_Account__r?.Name;
            injury.diagnosisCode = currentCase.trm_Diagnosis_Code__r?.Name;
            injury.allDiagnosisCodes = currentCase.trm_All_Diagnosis_Codes__c;

            // TRINITY PRINCIPLE: NO HARDCODED INJURY DATA
            // Body part, injury type, and treatment category should come from Case fields in production
            injury.bodyPart = null; // Should come from Case.Body_Part__c field
            injury.injuryType = null; // Should come from Case.Injury_Type__c field
            injury.treatmentCategory = null; // Should come from Case.Treatment_Category__c field

            // Additional fields required by LWC template - all from real Case fields or graceful nulls
            injury.dateOfInjury = currentCase.Date_of_Injury__c; // LWC expects dateOfInjury, not injuryDate
            injury.coverageStatus = null; // Should come from Case.Coverage_Status__c field
            injury.authorizationRequired = null; // Should come from Case.Authorization_Required__c field
            injury.description = null; // Should come from Case.Injury_Description__c field
            injury.coverageNotes = null; // Should come from Case.Coverage_Notes__c field
            injury.statusClass = getInjuryStatusClass(currentCase.Status); // Calculate CSS class from status

            result.injuries.add(injury);

            // Set member account info for display
            result.memberAccountInfo.accountName = currentCase.Custodial_Account__r?.Name;
            if (String.isBlank(result.memberAccountInfo.accountName)) {
                result.memberAccountInfo.accountName = 'Member Account'; // Graceful fallback for display
            }

            return result;

        } catch (Exception e) {
            throw new AuraHandledException('Error retrieving Injury data: ' + e.getMessage());
        }
    }

    /**
     * @description Get CSS class for injury status display
     * @param status The Case status value
     * @return String CSS class name for styling
     *
     * TRINITY PRINCIPLE: Dynamic styling based on real data, no hardcoded classes
     */
    private static String getInjuryStatusClass(String status) {
        if (String.isBlank(status)) {
            return 'status-unknown';
        }

        // Map Case status to CSS classes - based on real status values
        switch on status.toLowerCase() {
            when 'active', 'open', 'in progress' {
                return 'status-active';
            }
            when 'closed', 'resolved', 'completed' {
                return 'status-inactive';
            }
            when 'pending', 'keying', 'review' {
                return 'status-pending';
            }
            when else {
                return 'status-unknown';
            }
        }
    }
    
    /**
     * @description Get Restrictions data for treatment limitations
     * @param caseId The Case record ID
     * @return RestrictionsData wrapper with treatment restrictions
     *
     * RAY'S DOMAIN: Treatment restrictions critical for Claims adjudication
     * TRINITY PRINCIPLE: Generate realistic restrictions based on actual Case data
     */
    @AuraEnabled(cacheable=true)
    public static RestrictionsData getRestrictionsData(Id caseId) {
        try {
            RestrictionsData result = new RestrictionsData();
            result.caseId = caseId;
            result.restrictions = new List<RestrictionInfo>();

            // Query Case data to determine appropriate restrictions
            List<Case> cases = [
                SELECT Id, CaseNumber, Status, Custodial_Account__r.Name,
                       Date_of_Injury__c, CreatedDate
                FROM Case
                WHERE Id = :caseId
                LIMIT 1
            ];

            if (cases.isEmpty()) {
                return result; // Return empty if no case found
            }

            Case currentCase = cases[0];
            String memberAccountName = currentCase.Custodial_Account__r?.Name;

            // TRINITY PRINCIPLE: NO HARDCODED RESTRICTION DATA
            // Restrictions should come from related Restriction__c records or Case custom fields in production
            System.debug('TRINITY: Restriction data should come from Restriction__c related records for Case ' + currentCase.Id);
            // result.restrictions remains empty - indicates missing production restriction setup

            return result;

        } catch (Exception e) {
            throw new AuraHandledException('Error retrieving Restrictions data: ' + e.getMessage());
        }
    }

    /**
     * Get prescription/Rx data for the case
     * RAY'S DOMAIN: Prescription coverage using REAL SALESFORCE FIELDS ONLY
     */
    @AuraEnabled(cacheable=true)
    public static RxData getRxData(Id caseId) {
        try {
            // Get case with REAL prescription-related fields ONLY
            Case currentCase = [
                SELECT Id, CaseNumber,
                       TRM_PBM_Invoice_Member_ID__c, TRM_PBM_Invoice_Number__c,
                       Pharmacy_Reprocess__c, RXCategory__c, RXDescription__c, RX_Description__c,
                       Calculation_Method_RX__c,
                       Custodial_Account__r.Name,
                       Custodial_Account__r.Account_Expiration_Date__c,
                       Custodial_Account__r.MemAccount_SAK_Status__c
                FROM Case
                WHERE Id = :caseId
                LIMIT 1
            ];

            RxData result = new RxData();
            result.caseId = currentCase.Id;
            result.caseNumber = currentCase.CaseNumber;

            // TRINITY PRINCIPLE: Use ONLY actual field values - NO hardcoded data
            result.pbmInvoiceMemberId = currentCase.TRM_PBM_Invoice_Member_ID__c;
            result.pbmInvoiceNumber = currentCase.TRM_PBM_Invoice_Number__c;
            result.pharmacyReprocess = currentCase.Pharmacy_Reprocess__c;
            result.rxCategory = currentCase.RXCategory__c;
            result.rxDescription = currentCase.RXDescription__c;
            result.rxDescription2 = currentCase.RX_Description__c;
            result.calculationMethodRx = currentCase.Calculation_Method_RX__c;
            result.memberAccountName = currentCase.Custodial_Account__r.Name;
            result.sakStatus = currentCase.Custodial_Account__r.MemAccount_SAK_Status__c;
            result.accountExpirationDate = currentCase.Custodial_Account__r.Account_Expiration_Date__c;

            return result;

        } catch (Exception e) {
            throw new AuraHandledException('Error retrieving Rx data: ' + e.getMessage());
        }
    }

    /**
     * Get DME (Durable Medical Equipment) data for the case
     * RAY'S DOMAIN: DME equipment scenarios using REAL SALESFORCE FIELDS ONLY
     */
    @AuraEnabled(cacheable=true)
    public static DMEData getDMEData(Id caseId) {
        try {
            // Get case with REAL DME-related fields ONLY
            Case currentCase = [
                SELECT Id, CaseNumber,
                       MCA_Total__c, MCA_Total_Medicals__c, MCA_Total_Prescriptions__c,
                       Cost__c, Cost_Driver_Item__c, Facilities__c,
                       Diagnostic_Medical_or_Remedial_Care__c,
                       Custodial_Account__r.Name,
                       Custodial_Account__r.Account_Expiration_Date__c,
                       Custodial_Account__r.MemAccount_SAK_Status__c
                FROM Case
                WHERE Id = :caseId
                LIMIT 1
            ];

            DMEData result = new DMEData();
            result.caseId = currentCase.Id;
            result.caseNumber = currentCase.CaseNumber;

            // Use ONLY actual field values - NO hardcoded demo data
            result.mcaTotal = currentCase.MCA_Total__c;
            result.mcaTotalMedicals = currentCase.MCA_Total_Medicals__c;
            result.mcaTotalPrescriptions = currentCase.MCA_Total_Prescriptions__c;
            result.cost = currentCase.Cost__c;
            result.costDriverItem = currentCase.Cost_Driver_Item__c;
            result.facilities = currentCase.Facilities__c;
            result.diagnosticMedicalCare = currentCase.Diagnostic_Medical_or_Remedial_Care__c;
            result.memberAccountName = currentCase.Custodial_Account__r.Name;
            result.sakStatus = currentCase.Custodial_Account__r.MemAccount_SAK_Status__c;
            result.accountExpirationDate = currentCase.Custodial_Account__r.Account_Expiration_Date__c;

            return result;

        } catch (Exception e) {
            throw new AuraHandledException('Error retrieving DME data: ' + e.getMessage());
        }
    }

    /**
     * Get EOB (Explanation of Benefits) data for the case
     * RAY'S DOMAIN: EOB processing using REAL SALESFORCE FIELDS ONLY
     */
    @AuraEnabled(cacheable=true)
    public static EOBData getEOBData(Id caseId) {
        try {
            // Get case with REAL EOB-related fields ONLY
            Case currentCase = [
                SELECT Id, CaseNumber,
                       EOB_Note__c, Case_BCN_Payment__c, LR_Payment_Amount__c,
                       LR_Payment_Date__c, Case_Payment_Details__c, LR_Payment_Submitted__c,
                       BCN_Number__c, BCN_Name__c, Denial__c, Denial_Reason__c,
                       Custodial_Account__r.Name,
                       Custodial_Account__r.Account_Expiration_Date__c,
                       Custodial_Account__r.MemAccount_SAK_Status__c
                FROM Case
                WHERE Id = :caseId
                LIMIT 1
            ];

            EOBData result = new EOBData();
            result.caseId = currentCase.Id;
            result.caseNumber = currentCase.CaseNumber;
            result.eobNote = currentCase.EOB_Note__c;
            result.bcnPayment = currentCase.Case_BCN_Payment__c;
            result.paymentAmount = currentCase.LR_Payment_Amount__c;
            result.paymentDate = currentCase.LR_Payment_Date__c;
            result.paymentDetails = currentCase.Case_Payment_Details__c;
            result.paymentSubmitted = currentCase.LR_Payment_Submitted__c;
            result.bcnNumber = currentCase.BCN_Number__c;
            result.bcnName = currentCase.BCN_Name__c;
            result.denial = currentCase.Denial__c;
            result.denialReason = currentCase.Denial_Reason__c;
            result.memberAccountName = currentCase.Custodial_Account__r.Name;
            result.sakStatus = currentCase.Custodial_Account__r.MemAccount_SAK_Status__c;
            result.accountExpirationDate = currentCase.Custodial_Account__r.Account_Expiration_Date__c;

            return result;

        } catch (Exception e) {
            throw new AuraHandledException('Error retrieving EOB data: ' + e.getMessage());
        }
    }

    /**
     * Get Document Management data for the case
     * RAY'S CRITICAL NEED: Document attachment, viewing, and management using REAL SALESFORCE FIELDS
     * TRINITY ENHANCEMENT: Complete metadata mapping with ContentVersion support for proper preview
     */
    @AuraEnabled(cacheable=true)
    public static DocumentData getDocumentData(Id caseId) {
        try {
            // Get case with REAL document-related fields ONLY
            // TRINITY FIX: Query Address compound field components separately
            Case currentCase = [
                SELECT Id, CaseNumber,
                       Case_Number_of_Pages__c, Document_Attention__c,
                       Case_Document_Address__Street__s, Case_Document_Address__City__s,
                       Case_Document_Address__StateCode__s, Case_Document_Address__PostalCode__s,
                       Case_Document_Address__CountryCode__s,
                       trm_Documentation_List__c,
                       Custodial_Account__r.Name,
                       Custodial_Account__r.Account_Expiration_Date__c,
                       Custodial_Account__r.MemAccount_SAK_Status__c
                FROM Case
                WHERE Id = :caseId
                LIMIT 1
            ];

            // TRINITY ENHANCEMENT: Get attached documents with complete metadata including ContentVersion for preview
            List<ContentDocumentLink> attachedDocs = [
                SELECT ContentDocumentId,
                       ContentDocument.Title,
                       ContentDocument.FileType,
                       ContentDocument.ContentSize,
                       ContentDocument.CreatedDate,
                       ContentDocument.LastModifiedDate,
                       ContentDocument.Owner.Name,
                       ContentDocument.FileExtension
                FROM ContentDocumentLink
                WHERE LinkedEntityId = :caseId
                ORDER BY ContentDocument.CreatedDate DESC
            ];

            // TRINITY ENHANCEMENT: Get ContentVersion records for proper preview URLs
            Set<Id> contentDocumentIds = new Set<Id>();
            for (ContentDocumentLink docLink : attachedDocs) {
                contentDocumentIds.add(docLink.ContentDocumentId);
            }

            Map<Id, ContentVersion> contentVersionMap = new Map<Id, ContentVersion>();
            if (!contentDocumentIds.isEmpty()) {
                List<ContentVersion> contentVersions = [
                    SELECT Id, ContentDocumentId, VersionData
                    FROM ContentVersion
                    WHERE ContentDocumentId IN :contentDocumentIds
                    AND IsLatest = true
                ];

                for (ContentVersion cv : contentVersions) {
                    contentVersionMap.put(cv.ContentDocumentId, cv);
                }
            }

            DocumentData result = new DocumentData();
            result.caseId = currentCase.Id;
            result.caseNumber = currentCase.CaseNumber;
            result.numberOfPages = currentCase.Case_Number_of_Pages__c;
            result.documentAttention = currentCase.Document_Attention__c;
            // TRINITY FIX: Build formatted address from compound field components
            List<String> addressParts = new List<String>();
            if (String.isNotBlank(currentCase.Case_Document_Address__Street__s)) {
                addressParts.add(currentCase.Case_Document_Address__Street__s);
            }
            if (String.isNotBlank(currentCase.Case_Document_Address__City__s)) {
                addressParts.add(currentCase.Case_Document_Address__City__s);
            }
            if (String.isNotBlank(currentCase.Case_Document_Address__StateCode__s)) {
                addressParts.add(currentCase.Case_Document_Address__StateCode__s);
            }
            if (String.isNotBlank(currentCase.Case_Document_Address__PostalCode__s)) {
                addressParts.add(currentCase.Case_Document_Address__PostalCode__s);
            }
            if (String.isNotBlank(currentCase.Case_Document_Address__CountryCode__s)) {
                addressParts.add(currentCase.Case_Document_Address__CountryCode__s);
            }
            result.documentAddress = addressParts.isEmpty() ? null : String.join(addressParts, ', ');
            result.documentationList = currentCase.trm_Documentation_List__c;
            result.memberAccountName = currentCase.Custodial_Account__r.Name;
            result.sakStatus = currentCase.Custodial_Account__r.MemAccount_SAK_Status__c;
            result.accountExpirationDate = currentCase.Custodial_Account__r.Account_Expiration_Date__c;

            // TRINITY ENHANCEMENT: Process attached documents with complete metadata and categorization
            result.attachedDocuments = new List<AttachedDocument>();
            Integer totalSize = 0;
            Map<String, Integer> categoryCount = new Map<String, Integer>{
                'EOB Document' => 0,
                'Bill Scan' => 0,
                'Supporting Records' => 0,
                'EDI Import' => 0,
                'Appeal Documentation' => 0,
                'Other' => 0
            };

            for (ContentDocumentLink docLink : attachedDocs) {
                AttachedDocument doc = new AttachedDocument();
                doc.documentId = docLink.ContentDocumentId;
                doc.title = docLink.ContentDocument.Title;
                doc.fileType = docLink.ContentDocument.FileType;
                doc.contentSize = docLink.ContentDocument.ContentSize;
                doc.createdDate = docLink.ContentDocument.CreatedDate;

                // TRINITY ENHANCEMENT: Add missing metadata fields
                doc.lastModifiedDate = docLink.ContentDocument.LastModifiedDate;
                doc.ownerName = docLink.ContentDocument.Owner.Name;
                doc.fileExtension = docLink.ContentDocument.FileExtension;
                doc.formattedSize = formatFileSize(docLink.ContentDocument.ContentSize);

                // TRINITY ENHANCEMENT: Add ContentVersion ID for proper preview
                ContentVersion cv = contentVersionMap.get(docLink.ContentDocumentId);
                if (cv != null) {
                    doc.contentVersionId = cv.Id;
                    // TRINITY PRINCIPLE: Use Salesforce standard URL generation, no hardcoded paths
                    doc.previewUrl = null; // Should use ConnectApi.Files.getFilePreview() in production
                    doc.downloadUrl = null; // Should use ConnectApi.Files.getFileDownloadUrl() in production
                }

                // TRINITY ENHANCEMENT: Document categorization based on Ray's requirements
                doc.documentCategory = categorizeDocument(docLink.ContentDocument.Title, docLink.ContentDocument.FileType);
                categoryCount.put(doc.documentCategory, categoryCount.get(doc.documentCategory) + 1);

                // TRINITY PRINCIPLE: Use dynamic file type checking, no hardcoded comparisons
                String fileType = docLink.ContentDocument.FileType?.toLowerCase();
                doc.isPdf = fileType == 'pdf';
                doc.isOfficeDoc = fileType != null && (fileType.contains('doc') || fileType.contains('xls'));

                if (docLink.ContentDocument.ContentSize != null) {
                    totalSize += docLink.ContentDocument.ContentSize;
                }

                result.attachedDocuments.add(doc);
            }

            // TRINITY ENHANCEMENT: Add summary statistics for Ray's dashboard
            result.totalDocumentSize = totalSize;
            result.formattedTotalSize = formatFileSize(totalSize);
            result.documentCategoryBreakdown = categoryCount;

            result.documentCount = attachedDocs.size();

            return result;

        } catch (Exception e) {
            throw new AuraHandledException('Error retrieving Document data: ' + e.getMessage());
        }
    }

    /**
     * TRINITY ENHANCEMENT: Categorize documents based on Ray's medical billing requirements
     * Categories: EOB Document, Bill Scan, Supporting Records, EDI Import, Appeal Documentation, Other
     */
    private static String categorizeDocument(String title, String fileType) {
        if (String.isBlank(title)) {
            return 'Other';
        }

        String lowerTitle = title.toLowerCase();

        // EOB Documents - Ray's primary document type
        if (lowerTitle.contains('eob') || lowerTitle.contains('explanation of benefits')) {
            return 'EOB Document';
        }

        // Bill Scans - Physical bill documents
        if (lowerTitle.contains('bill') || lowerTitle.contains('invoice') || lowerTitle.contains('statement')) {
            return 'Bill Scan';
        }

        // Supporting Records - Medical records and documentation
        if (lowerTitle.contains('record') || lowerTitle.contains('medical') || lowerTitle.contains('report') ||
            lowerTitle.contains('chart') || lowerTitle.contains('note')) {
            return 'Supporting Records';
        }

        // EDI Import - Electronic data interchange
        if (lowerTitle.contains('edi') || lowerTitle.contains('electronic') || lowerTitle.contains('837') ||
            lowerTitle.contains('835') || lowerTitle.contains('import')) {
            return 'EDI Import';
        }

        // Appeal Documentation - Appeals and disputes
        if (lowerTitle.contains('appeal') || lowerTitle.contains('dispute') || lowerTitle.contains('denial') ||
            lowerTitle.contains('reconsideration')) {
            return 'Appeal Documentation';
        }

        return 'Other';
    }

    /**
     * TRINITY ENHANCEMENT: Format file size for human-readable display
     * Converts bytes to KB, MB, GB with proper formatting
     */
    private static String formatFileSize(Integer sizeInBytes) {
        if (sizeInBytes == null || sizeInBytes == 0) {
            return '0 B';
        }

        if (sizeInBytes < 1024) {
            return sizeInBytes + ' B';
        } else if (sizeInBytes < 1024 * 1024) {
            return String.valueOf(Math.round((Decimal)sizeInBytes / 1024 * 100) / 100) + ' KB';
        } else if (sizeInBytes < 1024 * 1024 * 1024) {
            return String.valueOf(Math.round((Decimal)sizeInBytes / (1024 * 1024) * 100) / 100) + ' MB';
        } else {
            return String.valueOf(Math.round((Decimal)sizeInBytes / (1024 * 1024 * 1024) * 100) / 100) + ' GB';
        }
    }

    /**
     * Get Follow-Up Management data for the case
     * RAY'S CRITICAL WORKFLOW: BCN follow-ups (days to month) and Refund follow-ups (month to year)
     */
    @AuraEnabled(cacheable=true)
    public static FollowUpData getFollowUpData(Id caseId) {
        try {
            // Get case with REAL follow-up related fields ONLY
            Case currentCase = [
                SELECT Id, CaseNumber,
                       X3_Month_Follow_up__c, X3_Month_Follow_up_Date__c,
                       X6_Month_Follow_up__c, X6_Month_Follow_up_Date__c,
                       Internal_Due_Date__c, Due_Date__c,
                       Internal_Note__c, LR_Case_Notes__c, Comments,
                       CaseRefund_Reason_for_Refund_Request__c,
                       Custodial_Account__r.Name,
                       Custodial_Account__r.Account_Expiration_Date__c,
                       Custodial_Account__r.MemAccount_SAK_Status__c
                FROM Case
                WHERE Id = :caseId
                LIMIT 1
            ];

            FollowUpData result = new FollowUpData();
            result.caseId = currentCase.Id;
            result.caseNumber = currentCase.CaseNumber;

            // Use ONLY actual field values - NO hardcoded demo data
            // BCN Follow-up data (days to month timeframe)
            result.bcnFollowUp = new BCNFollowUpInfo();
            result.bcnFollowUp.threeMonthFollowUp = currentCase.X3_Month_Follow_up__c;
            result.bcnFollowUp.threeMonthFollowUpDate = currentCase.X3_Month_Follow_up_Date__c;
            result.bcnFollowUp.sixMonthFollowUp = currentCase.X6_Month_Follow_up__c;
            result.bcnFollowUp.sixMonthFollowUpDate = currentCase.X6_Month_Follow_up_Date__c;
            result.bcnFollowUp.internalDueDate = currentCase.Internal_Due_Date__c;
            result.bcnFollowUp.externalDueDate = currentCase.Due_Date__c;
            result.bcnFollowUp.internalNote = currentCase.Internal_Note__c;
            result.bcnFollowUp.caseNotes = currentCase.LR_Case_Notes__c;
            result.bcnFollowUp.comments = currentCase.Comments;

            // Refund Follow-up data (month to year timeframe)
            result.refundFollowUp = new RefundFollowUpInfo();
            result.refundFollowUp.refundReason = currentCase.CaseRefund_Reason_for_Refund_Request__c;
            result.refundFollowUp.hasRefundRequest = String.isNotBlank(currentCase.CaseRefund_Reason_for_Refund_Request__c);

            // Account information
            result.memberAccountName = currentCase.Custodial_Account__r.Name;
            result.sakStatus = currentCase.Custodial_Account__r.MemAccount_SAK_Status__c;
            result.accountExpirationDate = currentCase.Custodial_Account__r.Account_Expiration_Date__c;

            return result;

        } catch (Exception e) {
            throw new AuraHandledException('Error retrieving Follow-Up data: ' + e.getMessage());
        }
    }

    /**
     * Get Adjudication Control data for the case
     * RAY'S TOGGLES: Apply Bill Fee, Apply Savings Fee, WAM Vendor Exception
     */
    @AuraEnabled(cacheable=true)
    public static AdjudicationControlData getAdjudicationControlData(Id caseId) {
        try {
            // Get case with REAL adjudication control fields ONLY
            Case currentCase = [
                SELECT Id, CaseNumber,
                       Apply_Bill_Fee__c, Apply_Savings_Fee__c, WAM_Vendor_Exception__c,
                       Cost__c, MSA_Funds_Payment__c, Non_MSA_Funds_Payment__c,
                       Case_BCN_Payment__c, LR_Payment_Amount__c
                FROM Case
                WHERE Id = :caseId
                LIMIT 1
            ];

            AdjudicationControlData result = new AdjudicationControlData();
            result.caseId = currentCase.Id;
            result.caseNumber = currentCase.CaseNumber;

            // Fee control toggles - REAL SALESFORCE DATA
            result.applyBillFee = currentCase.Apply_Bill_Fee__c != null ? currentCase.Apply_Bill_Fee__c : true;
            result.applySavingsFee = currentCase.Apply_Savings_Fee__c != null ? currentCase.Apply_Savings_Fee__c : true;
            result.wamVendorException = currentCase.WAM_Vendor_Exception__c != null ? currentCase.WAM_Vendor_Exception__c : false;

            // Financial data - REAL SALESFORCE DATA
            result.totalCost = currentCase.Cost__c != null ? currentCase.Cost__c : 0;
            result.currentPayment = currentCase.Case_BCN_Payment__c != null ? currentCase.Case_BCN_Payment__c :
                                  (currentCase.LR_Payment_Amount__c != null ? currentCase.LR_Payment_Amount__c : 0);
            result.msaFundsPayment = currentCase.MSA_Funds_Payment__c != null ? currentCase.MSA_Funds_Payment__c : 0;
            result.nonMsaFundsPayment = currentCase.Non_MSA_Funds_Payment__c != null ? currentCase.Non_MSA_Funds_Payment__c : 0;

            return result;

        } catch (Exception e) {
            System.debug('Error in getAdjudicationControlData: ' + e.getMessage());
            throw new AuraHandledException('Error loading adjudication control data: ' + e.getMessage());
        }
    }

    /**
     * Get Bill Line Items for the custom grid
     * RAY'S DOMAIN EXPERTISE: Complete line item data with all adjudication fields
     */
    @AuraEnabled(cacheable=true)
    public static List<Bill_Line_Item__c> getBillLineItems(Id caseId) {
        try {
            // TRINITY ENHANCEMENT: Added duplicate detection fields for Ray's triangle indicators
            // TRINITY PHASE 1: Added Bill_Line_Item_Number__c for line number display (meeting req line 172)
            // TRINITY TOOLTIP ENHANCEMENT: Added Code__r.Description__c for tooltip display
            // TRINITY FIX: ORDER BY Bill_Line_Item_Number__c ASC for proper line number sorting
            // TRINITY PHASE 3: Fixed Account field - pull from Bill__r.Member_Account__r.Name instead of Account__r.Name
            // TRINITY FIX: Added Account__c field for validation service (MVADM-92)
            String query = 'SELECT Id, Bill_Line_Item_Number__c, Service_Start_Date__c, Service_End_Date__c, Revenue_Code__c, Place_of_Service__c, ' +
                          'CPT_HCPCS_NDC__c, Modifier__c, Quantity__c, Charge__c, Other_Ins_Allowed__c, Other_Ins_Paid__c, ' +
                          'Approved_Amount__c, Patient_Responsibility__c, X3rd_Party__c, X3rd_Party_Curr__c, Adjustment_Amount__c, Savings_Fee__c, ' +
                          'Description__c, Code__c, Code__r.Name, Code__r.Description__c, Code__r.Medicare_Covered__c, ' +
                          'Bill__c, Bill__r.Member_Account__c, Bill__r.Member_Account__r.Name, Bill__r.BCN_Custom_Status__c, Account__c, ' +
                          'Remark_Code_1__c, Remark_Code_2__c, Remark_Code_3__c, Remark_Code_4__c, ' +
                          'Duplicate_Status__c, Matching_Records__c, Last_Duplicate_Check__c, TRM_BCN_Custom_Status__c FROM Bill_Line_Item__c ' +
                          'WHERE Bill__c IN (SELECT BCN__c FROM Case WHERE Case.Id = :caseId) ' +
                          'ORDER BY Bill_Line_Item_Number__c ASC NULLS LAST, Service_Start_Date__c ASC, CPT_HCPCS_NDC__c ASC';

            List<Bill_Line_Item__c> items = Database.query(query);

            // TRINITY DEFENSIVE CODING: Apply defaults on LOAD only (not on updates)
            // Ray's requirement: Paid field is required (even if $0.00)
            // This ensures null values display as $0.00 in the grid without breaking partial updates
            for (Bill_Line_Item__c item : items) {
                if (item.Approved_Amount__c == null) {
                    item.Approved_Amount__c = 0.00;
                }
            }

            return items;

        } catch (Exception e) {
            System.debug('Error in getBillLineItems: ' + e.getMessage());
            throw new AuraHandledException('Error loading Bill Line Items: ' + e.getMessage());
        }
    }

    /**
     * TRINITY v2.7.1: Get Bill ID from Case for draft row creation
     * Used when Case has Bill but no line items yet (empty Bill scenario)
     * @param caseId The Case ID to query
     * @return Bill ID from Case.BCN__c, or null if no Bill exists
     */
    @AuraEnabled(cacheable=true)
    public static Id getBillIdFromCase(Id caseId) {
        try {
            Case currentCase = [SELECT BCN__c FROM Case WHERE Id = :caseId LIMIT 1];
            return currentCase.BCN__c;
        } catch (Exception e) {
            System.debug('Error in getBillIdFromCase: ' + e.getMessage());
            throw new AuraHandledException('Error querying Bill ID from Case: ' + e.getMessage());
        }
    }

    /**
     * TRINITY v2.5.1: Get Case BCN Number for validation
     * CRITICAL BLOCKER FIX: Prevents grid from opening without valid Bill header
     * @param caseId The Case ID
     * @return String BCN_Number__c value (null if case not found or BCN not set)
     */
    @AuraEnabled(cacheable=true)
    public static String getCaseBCNNumber(Id caseId) {
        try {
            Case c = [SELECT BCN_Number__c FROM Case WHERE Id = :caseId LIMIT 1];
            return c.BCN_Number__c;
        } catch (Exception e) {
            System.debug('Error in getCaseBCNNumber: ' + e.getMessage());
            return null;
        }
    }

    /**
     * TRINITY ENHANCEMENT: Create duplicate Bill Line Items
     * @param originalItemIds List of Bill Line Item IDs to duplicate
     * @param duplicateCount Number of duplicates to create for each item
     * @return List of newly created Bill Line Items
     */
    @AuraEnabled
    public static List<Bill_Line_Item__c> createDuplicateBillLineItems(List<Id> originalItemIds, Integer duplicateCount) {
        try {
            // Get the original items with all fields
            List<Bill_Line_Item__c> originalItems = [
                SELECT Service_Start_Date__c, Service_End_Date__c, Revenue_Code__c, Place_of_Service__c,
                       CPT_HCPCS_NDC__c, Modifier__c, Quantity__c, Charge__c, Other_Ins_Allowed__c, Other_Ins_Paid__c,
                       Approved_Amount__c, Patient_Responsibility__c, X3rd_Party__c, X3rd_Party_Curr__c, Adjustment_Amount__c, Savings_Fee__c,
                       Description__c, Code__c, Account__c, Remark_Code_1__c, Remark_Code_2__c, Remark_Code_3__c,
                       Remark_Code_4__c, Bill__c, TRM_BCN_Custom_Status__c
                FROM Bill_Line_Item__c
                WHERE Id IN :originalItemIds
            ];

            List<Bill_Line_Item__c> newItems = new List<Bill_Line_Item__c>();

            // MVADM-188: Map to cache max line number per Bill (prevents redundant queries)
            Map<Id, Decimal> billToMaxLineNumber = new Map<Id, Decimal>();

            // MVADM-188: Get unique Bill IDs from original items
            Set<Id> billIds = new Set<Id>();
            for (Bill_Line_Item__c item : originalItems) {
                billIds.add(item.Bill__c);
            }

            // MVADM-188: Query max line number for each Bill
            for (Id billId : billIds) {
                List<AggregateResult> results = [
                    SELECT MAX(Bill_Line_Item_Number__c) maxNum
                    FROM Bill_Line_Item__c
                    WHERE Bill__c = :billId
                ];
                Decimal maxNum = (Decimal)results[0].get('maxNum');
                billToMaxLineNumber.put(billId, maxNum != null ? maxNum : 0);
            }

            // Create duplicates - TRINITY: Explicit field copying to ensure date accuracy
            for (Bill_Line_Item__c original : originalItems) {
                // TRINITY: Debug logging for date values
                System.debug('Original Start Date: ' + original.Service_Start_Date__c);
                System.debug('Original End Date: ' + original.Service_End_Date__c);

                for (Integer i = 0; i < duplicateCount; i++) {
                    Bill_Line_Item__c duplicate = new Bill_Line_Item__c();

                    // TRINITY: Explicit date field copying to prevent Start/End date confusion
                    duplicate.Service_Start_Date__c = original.Service_Start_Date__c;
                    duplicate.Service_End_Date__c = original.Service_End_Date__c;

                    // TRINITY: Debug logging for duplicate values
                    System.debug('Duplicate Start Date: ' + duplicate.Service_Start_Date__c);
                    System.debug('Duplicate End Date: ' + duplicate.Service_End_Date__c);

                    // Copy all other fields
                    duplicate.Revenue_Code__c = original.Revenue_Code__c;
                    duplicate.Place_of_Service__c = original.Place_of_Service__c;
                    duplicate.CPT_HCPCS_NDC__c = original.CPT_HCPCS_NDC__c;
                    duplicate.Modifier__c = original.Modifier__c;
                    duplicate.Quantity__c = original.Quantity__c;
                    duplicate.Charge__c = original.Charge__c;
                    duplicate.Other_Ins_Allowed__c = original.Other_Ins_Allowed__c;
                    duplicate.Other_Ins_Paid__c = original.Other_Ins_Paid__c;
                    duplicate.Approved_Amount__c = original.Approved_Amount__c;
                    duplicate.Patient_Responsibility__c = original.Patient_Responsibility__c;
                    duplicate.X3rd_Party__c = original.X3rd_Party__c;
                    duplicate.X3rd_Party_Curr__c = original.X3rd_Party_Curr__c; // TRINITY: Currency field
                    duplicate.Adjustment_Amount__c = original.Adjustment_Amount__c;
                    duplicate.Savings_Fee__c = original.Savings_Fee__c;
                    duplicate.Description__c = original.Description__c;
                    duplicate.Code__c = original.Code__c;
                    duplicate.Account__c = original.Account__c;
                    duplicate.Remark_Code_1__c = original.Remark_Code_1__c;
                    duplicate.Remark_Code_2__c = original.Remark_Code_2__c;
                    duplicate.Remark_Code_3__c = original.Remark_Code_3__c;
                    duplicate.Remark_Code_4__c = original.Remark_Code_4__c;
                    duplicate.Bill__c = original.Bill__c;
                    duplicate.TRM_BCN_Custom_Status__c = original.TRM_BCN_Custom_Status__c;

                    // MVADM-188: Assign next sequential line number
                    Decimal nextNumber = billToMaxLineNumber.get(original.Bill__c) + 1;
                    duplicate.Bill_Line_Item_Number__c = nextNumber;
                    billToMaxLineNumber.put(original.Bill__c, nextNumber); // Increment for next duplicate

                    newItems.add(duplicate);
                }
            }

            // Insert the new items
            if (!newItems.isEmpty()) {
                insert newItems;

                // TRINITY: Re-query with all related fields to match grid expectations
                List<Id> newItemIds = new List<Id>();
                for (Bill_Line_Item__c item : newItems) {
                    newItemIds.add(item.Id);
                }

                // Query with same fields as getBillLineItems to ensure grid compatibility
                // TRINITY PHASE 1: Added Bill_Line_Item_Number__c for consistency with getBillLineItems
                // TRINITY TOOLTIP ENHANCEMENT: Added Code__r.Description__c for tooltip display
                // TRINITY PHASE 3: Fixed Account field - pull from Bill__r.Member_Account__r.Name
                return [
                    SELECT Id, Bill_Line_Item_Number__c, Service_Start_Date__c, Service_End_Date__c, Revenue_Code__c, Place_of_Service__c,
                           CPT_HCPCS_NDC__c, Modifier__c, Quantity__c, Charge__c, Other_Ins_Allowed__c, Other_Ins_Paid__c,
                           Approved_Amount__c, Patient_Responsibility__c, X3rd_Party__c, X3rd_Party_Curr__c, Adjustment_Amount__c, Savings_Fee__c,
                           Description__c, Code__c, Code__r.Name, Code__r.Description__c, Code__r.Medicare_Covered__c,
                           Bill__c, Bill__r.Member_Account__c, Bill__r.Member_Account__r.Name, Bill__r.BCN_Custom_Status__c,
                           Remark_Code_1__c, Remark_Code_2__c, Remark_Code_3__c, Remark_Code_4__c,
                           Duplicate_Status__c, Matching_Records__c, Last_Duplicate_Check__c, TRM_BCN_Custom_Status__c
                    FROM Bill_Line_Item__c
                    WHERE Id IN :newItemIds
                    ORDER BY Bill_Line_Item_Number__c ASC NULLS LAST, CreatedDate DESC
                ];
            }

            return newItems;

        } catch (Exception e) {
            System.debug('Error in createDuplicateBillLineItems: ' + e.getMessage());
            throw new AuraHandledException('Error creating duplicate Bill Line Items: ' + e.getMessage());
        }
    }

    /**
     * TRINITY ENHANCEMENT: Delete Bill Line Items
     * @param itemIds List of Bill Line Item IDs to delete
     * @return Success message
     */
    @AuraEnabled
    public static String deleteBillLineItems(List<Id> itemIds) {
        try {
            List<Bill_Line_Item__c> itemsToDelete = [SELECT Id FROM Bill_Line_Item__c WHERE Id IN :itemIds];

            if (!itemsToDelete.isEmpty()) {
                delete itemsToDelete;
            }

            return 'Successfully deleted ' + itemsToDelete.size() + ' Bill Line Item(s)';

        } catch (Exception e) {
            System.debug('Error in deleteBillLineItems: ' + e.getMessage());
            throw new AuraHandledException('Error deleting Bill Line Items: ' + e.getMessage());
        }
    }

    /**
     * Update Bill Line Items from the custom grid
     * RAY'S DOMAIN EXPERTISE: Bulk update functionality for adjudication fields
     */
    @AuraEnabled
    public static void updateBillLineItems(List<Bill_Line_Item__c> lineItems) {
        try {
            if (lineItems == null || lineItems.isEmpty()) {
                throw new AuraHandledException('No line items provided for update');
            }

            System.debug('=== TRINITY: updateBillLineItems START ===');
            System.debug('TRINITY: Received ' + lineItems.size() + ' line items for update');

            // TRINITY: Log update details for debugging
            for (Bill_Line_Item__c item : lineItems) {
                System.debug('TRINITY: Updating item ID: ' + item.Id);
                Map<String, Object> populatedFields = item.getPopulatedFieldsAsMap();
                System.debug('TRINITY: Populated fields: ' + populatedFields.keySet());
            }

            // TRINITY CRITICAL FIX: NO defensive null-to-default conversions on updates
            // Defensive coding moved to getBillLineItems() to prevent partial update bugs
            // This allows bulk operations to update single fields without zeroing other fields

            System.debug('=== TRINITY: Calling DML update ===');
            update lineItems;
            System.debug('=== TRINITY: DML update successful ===');
            System.debug('TRINITY: Successfully updated ' + lineItems.size() + ' line items');

        } catch (Exception e) {
            System.debug('Error in updateBillLineItems: ' + e.getMessage());
            throw new AuraHandledException('Error updating Bill Line Items: ' + e.getMessage());
        }
    }

    /**
     * @description Mark all Bill Line Items as Processed after adjudication validation passes
     * @param caseId The Case ID
     *
     * RAY'S WORKFLOW: Update line item status after successful validation
     * TRINITY PRINCIPLE: Centralize Bill Line Item operations in MedicalBillingService
     */
    @AuraEnabled
    public static void markLineItemsAsProcessed(Id caseId) {
        try {
            if (caseId == null) {
                throw new IllegalArgumentException('Case ID is required');
            }

            // Get all Bill Line Items for this Case
            // TRINITY: Use getBillLineItems to get line items (follows existing pattern)
            List<Bill_Line_Item__c> lineItems = getBillLineItems(caseId);

            if (lineItems.isEmpty()) {
                System.debug('No line items found for Case: ' + caseId);
                return;
            }

            // Get the Bill ID from the first line item
            Id billId = lineItems[0].Bill__c;

            // Update Line Items status to 'Processed'
            for (Bill_Line_Item__c item : lineItems) {
                item.TRM_BCN_Custom_Status__c = 'Processed';
            }

            update lineItems;

            // ALSO update Bill status to 'Processed'
            Bill__c billToUpdate = new Bill__c(
                Id = billId,
                BCN_Custom_Status__c = 'Processed'
            );

            update billToUpdate;

            System.debug('TRINITY: Marked ' + lineItems.size() + ' line items as Processed for Case: ' + caseId);
            System.debug('TRINITY: Marked Bill as Processed - Bill ID: ' + billId);

        } catch (Exception e) {
            System.debug('Error marking line items as processed: ' + e.getMessage());
            throw new AuraHandledException('Error marking line items as processed: ' + e.getMessage());
        }
    }

    /**
     * MVADM-155: Create new Bill Line Item for manual entry
     * TRINITY: Implements persistent blank row pattern for continuous data entry
     *
     * @param billId The Bill__c (BCN) ID to associate the new line item with
     * @param draftItem The draft Bill_Line_Item__c with initial field values from user entry
     * @return Bill_Line_Item__c The newly created line item with all fields populated (matches getBillLineItems structure)
     *
     * CRITICAL: Re-queries with EXACT same field list as getBillLineItems() to ensure grid compatibility
     * DEFENSIVE: Initializes all adjudication fields to defaults to prevent validation errors
     */
    @AuraEnabled
    public static Bill_Line_Item__c createBillLineItem(Id billId, Bill_Line_Item__c draftItem) {
        try {
            System.debug('TRINITY DEBUG: Creating new line item for Bill: ' + billId);
            System.debug('TRINITY DEBUG: Draft item fields: ' + JSON.serialize(draftItem));

            // MVADM-155: Calculate next line number by finding max existing line number
            List<Bill_Line_Item__c> existingItems = [
                SELECT Bill_Line_Item_Number__c
                FROM Bill_Line_Item__c
                WHERE Bill__c = :billId
                ORDER BY Bill_Line_Item_Number__c DESC NULLS LAST
                LIMIT 1
            ];

            Decimal nextLineNumber = 1;
            if (!existingItems.isEmpty() && existingItems[0].Bill_Line_Item_Number__c != null) {
                nextLineNumber = existingItems[0].Bill_Line_Item_Number__c + 1;
            }
            System.debug('TRINITY DEBUG: Next line number: ' + nextLineNumber);

            // TRINITY: Create new Bill_Line_Item__c record
            Bill_Line_Item__c newItem = new Bill_Line_Item__c();

            // CRITICAL: Set Bill__c lookup (required field)
            newItem.Bill__c = billId;

            // MVADM-155: Set line number to next sequential number
            newItem.Bill_Line_Item_Number__c = nextLineNumber;

            // TRINITY: Copy data entry fields from draft item (handle nulls gracefully)
            newItem.Service_Start_Date__c = draftItem.Service_Start_Date__c;
            newItem.Service_End_Date__c = draftItem.Service_End_Date__c;
            newItem.Revenue_Code__c = draftItem.Revenue_Code__c;
            newItem.Place_of_Service__c = draftItem.Place_of_Service__c;
            newItem.CPT_HCPCS_NDC__c = draftItem.CPT_HCPCS_NDC__c;
            newItem.Modifier__c = draftItem.Modifier__c;
            newItem.Quantity__c = draftItem.Quantity__c;
            newItem.TRM_BCN_Custom_Status__c = draftItem.TRM_BCN_Custom_Status__c;
            newItem.Charge__c = draftItem.Charge__c;
            newItem.Description__c = draftItem.Description__c;
            newItem.Code__c = draftItem.Code__c;
            newItem.Account__c = draftItem.Account__c;
            newItem.Remark_Code_1__c = draftItem.Remark_Code_1__c;
            newItem.Remark_Code_2__c = draftItem.Remark_Code_2__c;
            newItem.Remark_Code_3__c = draftItem.Remark_Code_3__c;
            newItem.Remark_Code_4__c = draftItem.Remark_Code_4__c;

            // TRINITY: Initialize adjudication fields to defaults (Ray's requirement: Paid field required even if $0.00)
            newItem.Approved_Amount__c = 0.00;
            newItem.Patient_Responsibility__c = 0.00;
            newItem.X3rd_Party__c = '0.00'; // LEGACY: TEXT field (keeping for backward compatibility)
            newItem.X3rd_Party_Curr__c = 0.00; // TRINITY: Currency field (new standard)
            newItem.Other_Ins_Allowed__c = 0.00;
            newItem.Other_Ins_Paid__c = 0.00;
            newItem.Adjustment_Amount__c = 0.00;
            newItem.Savings_Fee__c = 0.00;

            // TRINITY: Insert the new record
            insert newItem;
            System.debug('TRINITY DEBUG: Successfully inserted line item with Id: ' + newItem.Id);

            // CRITICAL: Re-query with EXACT same field list as getBillLineItems() (lines 625-631)
            // This ensures the returned record has the same structure as existing line items in the grid
            // MVADM-155 CRITICAL FIX: Use direct SOQL with bind variable, not Database.query() with string
            Bill_Line_Item__c queriedItem = [
                SELECT Id, Bill_Line_Item_Number__c, Service_Start_Date__c, Service_End_Date__c, Revenue_Code__c, Place_of_Service__c,
                       CPT_HCPCS_NDC__c, Modifier__c, Quantity__c, Charge__c, Other_Ins_Allowed__c, Other_Ins_Paid__c,
                       Approved_Amount__c, Patient_Responsibility__c, X3rd_Party__c, X3rd_Party_Curr__c, Adjustment_Amount__c, Savings_Fee__c,
                       Description__c, Code__c, Code__r.Name, Code__r.Description__c, Code__r.Medicare_Covered__c,
                       Bill__c, Bill__r.Member_Account__c, Bill__r.Member_Account__r.Name, Bill__r.BCN_Custom_Status__c, Account__c,
                       Remark_Code_1__c, Remark_Code_2__c, Remark_Code_3__c, Remark_Code_4__c,
                       Duplicate_Status__c, Matching_Records__c, Last_Duplicate_Check__c, TRM_BCN_Custom_Status__c 
                FROM Bill_Line_Item__c
                WHERE Id = :newItem.Id
                LIMIT 1
            ];
            System.debug('TRINITY DEBUG: Successfully created line item: ' + queriedItem.Id);

            return queriedItem;

        } catch (Exception e) {
            System.debug('TRINITY ERROR: Failed to create line item: ' + e.getMessage());
            System.debug('TRINITY ERROR: Stack trace: ' + e.getStackTraceString());
            throw new AuraHandledException('Error creating Bill Line Item: ' + e.getMessage());
        }
    }

    /**
     * Query Case data for Bill creation modal pre-fill
     * @param caseId The Case ID to query
     * @return Case record with Patient_Id__c, Custodial_Account__c, Date_of_Injury__c
     */
    @AuraEnabled(cacheable=true)
    public static Case getCaseDataForBillCreation(Id caseId) {
        try {
            // Query Case with fields needed for Bill creation
            return [
                SELECT Id, CaseNumber, Patient_Id__c,
                       Custodial_Account__c, Custodial_Account__r.Name,
                       Date_of_Injury__c
                FROM Case
                WHERE Id = :caseId
                LIMIT 1
            ];
        } catch (Exception e) {
            throw new AuraHandledException('Error querying Case data: ' + e.getMessage());
        }
    }

    /**
     * TRINITY HEADER ENHANCEMENT: Query Bill header data for display in BCN/Quote Adjudication header
     * Returns Bill__c fields: BCN_Number__c, Invoice_Id__c, Payee_Name__r.Name
     * @param caseId The Case ID to query Bill for
     * @return Bill__c record with header fields, or null if no Bill exists
     */
    @AuraEnabled(cacheable=true)
    public static Bill__c getBillHeaderData(Id caseId) {
        try {
            // Query Bill linked to Case via BCN__c field
            List<Bill__c> bills = [
                SELECT Id, Name, BCN_Number__c, Invoice_Id__c,
                       Payee_Name__c, Payee_Name__r.Name, Payee_Name_Label__c
                FROM Bill__c
                WHERE Id IN (SELECT BCN__c FROM Case WHERE Id = :caseId)
                LIMIT 1
            ];

            return bills.isEmpty() ? null : bills[0];
        } catch (Exception e) {
            System.debug('Error in getBillHeaderData: ' + e.getMessage());
            throw new AuraHandledException('Error loading Bill header data: ' + e.getMessage());
        }
    }

    /**
     * Create a new Bill__c record for a Case and link them together
     * @param caseId The Case ID to create Bill for
     * @param patientId Patient ID to populate on Bill (optional)
     * @param memberAccountId Member Account ID to populate on Bill (optional)
     * @param dateOfServiceFrom Service start date (optional)
     * @param dateOfServiceTo Service end date (optional)
     * @return Id of newly created Bill__c record
     */
    @AuraEnabled
    public static Id createBillForCase(
        Id caseId,
        String patientId,
        Id memberAccountId,
        Date dateOfServiceFrom,
        Date dateOfServiceTo
    ) {
        // Validate Case exists
        List<Case> cases = [SELECT Id FROM Case WHERE Id = :caseId LIMIT 1];
        if (cases.isEmpty()) {
            throw new AuraHandledException('Case not found: ' + caseId);
        }

        Savepoint sp = Database.setSavepoint();

        try {
            // Create Bill__c record
            // NOTE: All fields are nullable per schema verification
            Bill__c newBill = new Bill__c(
                Bill_Case_Data__c = caseId,
                Patient_Id__c = patientId,
                Member_Account__c = memberAccountId,
                DateOfServiceFrom__c = dateOfServiceFrom,
                DateOfServiceTo__c = dateOfServiceTo
            );

            insert newBill;

            // Update Case to link to new Bill
            Case caseToUpdate = new Case(
                Id = caseId,
                BCN__c = newBill.Id
            );

            update caseToUpdate;

            return newBill.Id;

        } catch (Exception e) {
            Database.rollback(sp);
            throw new AuraHandledException('Error creating Bill: ' + e.getMessage());
        }
    }

    /**
     * Get Remark Codes for the grid lookups
     * RAY'S DOMAIN EXPERTISE: RC1-RC4 remark codes for adjudication decisions
     */
    @AuraEnabled(cacheable=true)
    public static List<Code__c> getRemarkCodes() {
        try {
            return [
                SELECT Id, Name, Description__c
                FROM Code__c
                ORDER BY Name
                LIMIT 1000
            ];
        } catch (Exception e) {
            System.debug('Error in getRemarkCodes: ' + e.getMessage());
            throw new AuraHandledException('Error loading Remark Codes: ' + e.getMessage());
        }
    }

    /**
     * Get Member Accounts for the grid lookups
     * TRINITY ENHANCEMENT v2.5.2: Filter by Case.Administration__c relationship
     * RAY'S DOMAIN EXPERTISE: Account assignment per line item (MSA, PCA, SAK, MCA)
     * RELATIONSHIP PATH: Case → Administration__c → Member_Account__c.Administration_Record__c
     * BUSINESS RULE: Only show accounts that belong to the same Administration as the Case
     * CLI DISCOVERY: Identified via BCN_Quote_Case_Record_Page.flexipage-meta.xml
     *                 "Related Member Accounts" uses Financial_Accounts__r relationship
     */
    @AuraEnabled(cacheable=true)
    public static List<Member_Account__c> getMemberAccounts(Id caseId) {
        try {
            // Query Case to get Administration__c
            List<Case> cases = [
                SELECT Id, Administration__c
                FROM Case
                WHERE Id = :caseId
                LIMIT 1
            ];

            if (cases.isEmpty()) {
                throw new AuraHandledException('Case not found: ' + caseId);
            }

            Case currentCase = cases[0];

            // If no Administration, return empty list (no accounts available)
            if (currentCase.Administration__c == null) {
                System.debug('TRINITY: Case ' + caseId + ' has no Administration__c - returning empty account list');
                return new List<Member_Account__c>();
            }

            // Query Member Accounts that belong to the same Administration
            // TRINITY: Only show accounts related through Administration__c.Financial_Accounts__r
            return [
                SELECT Id, Name, Type__c, Status__c, BalanceAccrued__c
                FROM Member_Account__c
                WHERE Administration_Record__c = :currentCase.Administration__c
                AND Status__c = 'Active'
                ORDER BY Type__c, Name
                LIMIT 100
            ];

        } catch (QueryException qe) {
            System.debug('TRINITY ERROR: Query failed in getMemberAccounts: ' + qe.getMessage());
            throw new AuraHandledException('Error querying Member Accounts: ' + qe.getMessage());
        } catch (Exception e) {
            System.debug('TRINITY ERROR: Unexpected error in getMemberAccounts: ' + e.getMessage());
            throw new AuraHandledException('Error loading Member Accounts: ' + e.getMessage());
        }
    }

    /**
     * TRINITY: Get code description by code name for auto-population
     * MEETING REQUIREMENT: "We pulled the description from the codes and then added it to a editable field"
     */
    @AuraEnabled
    public static String getCodeDescription(String codeName) {
        try {
            if (String.isBlank(codeName)) {
                return null;
            }

            List<Code__c> codes = [
                SELECT Description__c
                FROM Code__c
                WHERE Name = :codeName
                LIMIT 1
            ];

            return codes.isEmpty() ? null : codes[0].Description__c;

        } catch (Exception e) {
            System.debug('Error in getCodeDescription: ' + e.getMessage());
            throw new AuraHandledException('Error retrieving code description: ' + e.getMessage());
        }
    }

    /**
     * TRINITY: Enhanced code search with type filtering and performance optimization
     * RAY'S REQUIREMENT: Search-as-you-type functionality for all code fields
     */
    @AuraEnabled(cacheable=true)
    public static List<CodeLookupResult> searchCodes(String searchTerm, List<String> codeTypes, Integer limitCount) {
        try {
            if (String.isBlank(searchTerm) || searchTerm.length() < 2) {
                return new List<CodeLookupResult>();
            }

            if (limitCount == null || limitCount <= 0) {
                limitCount = 10;
            }

            // TRINITY: Use SOSL for efficient search across Name and Description fields
            String searchQuery = 'FIND \'' + String.escapeSingleQuotes(searchTerm) + '*\' IN ALL FIELDS ' +
                               'RETURNING Code__c(Id, Name, Description__c, DescShort__c, Type__c ' +
                               'WHERE Type__c IN :codeTypes ' +
                               'ORDER BY Name ASC ' +
                               'LIMIT ' + limitCount + ')';

            List<List<SObject>> searchResults = Search.query(searchQuery);
            List<Code__c> foundCodes = (List<Code__c>)searchResults[0];

            List<CodeLookupResult> results = new List<CodeLookupResult>();
            for (Code__c code : foundCodes) {
                CodeLookupResult result = new CodeLookupResult();
                result.codeId = code.Id;
                result.codeName = code.Name;
                result.description = code.Description__c;
                result.shortDescription = code.DescShort__c;
                result.codeType = code.Type__c;
                result.displayLabel = code.Name + (String.isNotBlank(code.Description__c) ? ' - ' + code.Description__c : '');
                results.add(result);
            }

            return results;

        } catch (Exception e) {
            System.debug('Error in searchCodes: ' + e.getMessage());
            throw new AuraHandledException('Error searching codes: ' + e.getMessage());
        }
    }

    /**
     * TRINITY: Get specific code details by name with type validation
     * MEETING REQUIREMENT: Validate codes exist and populate descriptions
     */
    @AuraEnabled
    public static CodeLookupResult getCodeDetails(String codeName, List<String> codeTypes) {
        try {
            if (String.isBlank(codeName)) {
                return null;
            }

            List<Code__c> codes = [
                SELECT Id, Name, Description__c, DescShort__c, Type__c
                FROM Code__c
                WHERE Name = :codeName
                AND Type__c IN :codeTypes
                LIMIT 1
            ];

            if (codes.isEmpty()) {
                return null;
            }

            Code__c code = codes[0];
            CodeLookupResult result = new CodeLookupResult();
            result.codeId = code.Id;
            result.codeName = code.Name;
            result.description = code.Description__c;
            result.shortDescription = code.DescShort__c;
            result.codeType = code.Type__c;
            result.displayLabel = code.Name + (String.isNotBlank(code.Description__c) ? ' - ' + code.Description__c : '');

            return result;

        } catch (Exception e) {
            System.debug('Error in getCodeDetails: ' + e.getMessage());
            throw new AuraHandledException('Error retrieving code details: ' + e.getMessage());
        }
    }

    /**
     * TRINITY TOOLTIP ENHANCEMENT: Batch fetch code descriptions for multiple codes
     * PURPOSE: Efficient lookup of descriptions for Revenue, POS, CPT, Modifier codes
     * ANTI-OVERENGINEERING: Simple Map-based batch query, no complex caching
     */
    @AuraEnabled
    public static Map<String, String> getCodeDescriptionsBatch(List<String> codeNames, List<String> codeTypes) {
        Map<String, String> codeDescriptionMap = new Map<String, String>();

        try {
            if (codeNames == null || codeNames.isEmpty()) {
                return codeDescriptionMap;
            }

            // Remove nulls and blanks
            Set<String> validCodeNames = new Set<String>();
            for (String codeName : codeNames) {
                if (String.isNotBlank(codeName)) {
                    validCodeNames.add(codeName);
                }
            }

            if (validCodeNames.isEmpty()) {
                return codeDescriptionMap;
            }

            // Build query with type filter if provided
            String queryStr = 'SELECT Name, Description__c FROM Code__c WHERE Name IN :validCodeNames';
            if (codeTypes != null && !codeTypes.isEmpty()) {
                queryStr += ' AND Type__c IN :codeTypes';
            }
            queryStr += ' LIMIT 200'; // Safety limit for batch operations

            List<Code__c> codes = Database.query(queryStr);

            // Build map of code name to description
            for (Code__c code : codes) {
                if (String.isNotBlank(code.Description__c)) {
                    codeDescriptionMap.put(code.Name, code.Description__c);
                }
            }

            return codeDescriptionMap;

        } catch (Exception e) {
            System.debug('Error in getCodeDescriptionsBatch: ' + e.getMessage());
            // Return empty map on error - graceful degradation
            return codeDescriptionMap;
        }
    }

    /**
     * TRINITY: Wrapper class for structured code lookup data
     * RAY'S DOMAIN: Provides all necessary code information for grid display
     */
    public class CodeLookupResult {
        @AuraEnabled public String codeId { get; set; }
        @AuraEnabled public String codeName { get; set; }
        @AuraEnabled public String description { get; set; }
        @AuraEnabled public String shortDescription { get; set; }
        @AuraEnabled public String codeType { get; set; }
        @AuraEnabled public String displayLabel { get; set; }

        public CodeLookupResult() {
            this.codeId = '';
            this.codeName = '';
            this.description = '';
            this.shortDescription = '';
            this.codeType = '';
            this.displayLabel = '';
        }
    }

    /**
     * Get Member Account data for the case
     * RAY'S DOMAIN EXPERTISE: Show Member Account details, fund balances, effective dates, account status
     * RENAMED to avoid conflict with TRM_BCNAdjudicationService.getMemberAccountData
     */
    @AuraEnabled(cacheable=true)
    public static MemberAccountData getMemberAccountFinancialData(Id caseId) {
        try {
            // Get case with BCN and Member Account information
            Case currentCase = [
                SELECT Id, CaseNumber, BCN__c, BCN__r.Member_Account__c, BCN__r.Member_Account__r.Name,
                       BCN__r.Member_Account__r.Type__c, BCN__r.Member_Account__r.Status__c,
                       BCN__r.Member_Account__r.BalanceAccrued__c, BCN__r.Member_Account__r.Account_Expiration_Date__c,
                       BCN__r.Member_Account__r.MemAccount_SAK_Status__c
                FROM Case
                WHERE Id = :caseId
                LIMIT 1
            ];

            MemberAccountData result = new MemberAccountData();
            result.caseId = currentCase.Id;
            result.caseNumber = currentCase.CaseNumber;

            // Check if we have a Member Account through the BCN
            if (currentCase.BCN__r?.Member_Account__c != null) {
                Member_Account__c memberAccount = currentCase.BCN__r.Member_Account__r;

                // Primary Account (MSA - Medicare Set-Aside)
                result.primaryAccount = new AccountInfo();
                result.primaryAccount.id = memberAccount.Id;
                result.primaryAccount.name = memberAccount.Name;
                result.primaryAccount.accountType = memberAccount.Type__c;
                result.primaryAccount.status = memberAccount.Status__c;

                // Use REAL Salesforce data - BalancePosted__c is the actual balance field with data
                result.primaryAccount.availableBalance = memberAccount.BalancePosted__c;

                // Calculate derived values from real balance data only
                if (memberAccount.BalancePosted__c != null && memberAccount.BalancePosted__c > 0) {
                    // TRINITY PRINCIPLE: NO HARDCODED PERCENTAGES
                    // Allocation percentages should come from Member_Account__c.Allocation_Percentage__c field
                    result.primaryAccount.allocatedFunds = null; // Should be calculated from custom field
                    result.primaryAccount.reservedFunds = null; // Should be calculated from custom field
                } else {
                    result.primaryAccount.allocatedFunds = null;
                    result.primaryAccount.reservedFunds = null;
                }

                result.primaryAccount.effectiveDate = null; // No real field available
                result.primaryAccount.expirationDate = memberAccount.Account_Expiration_Date__c;
                result.primaryAccount.lastActivity = null; // No real field available

                // Related Accounts - Query for additional accounts with REAL data
                List<Member_Account__c> relatedAccounts = [
                    SELECT Id, Name, Type__c, Status__c, BalanceAccrued__c, BalancePosted__c, Account_Expiration_Date__c
                    FROM Member_Account__c
                    WHERE Id != :memberAccount.Id
                    AND (Type__c = 'PCA' OR Type__c = 'SAK' OR Type__c = 'MCA' OR Type__c != null)
                    LIMIT 5
                ];

                result.relatedAccounts = new List<AccountInfo>();
                for (Member_Account__c relatedAccount : relatedAccounts) {
                    AccountInfo accountInfo = new AccountInfo();
                    accountInfo.id = relatedAccount.Id;
                    accountInfo.name = relatedAccount.Name;
                    accountInfo.accountType = relatedAccount.Type__c;
                    accountInfo.status = relatedAccount.Status__c;

                    // Use REAL balance data - BalancePosted__c has actual values
                    accountInfo.availableBalance = relatedAccount.BalancePosted__c;

                    // TRINITY PRINCIPLE: NO HARDCODED PERCENTAGE CALCULATIONS
                    if (relatedAccount.BalancePosted__c != null && relatedAccount.BalancePosted__c > 0) {
                        accountInfo.allocatedFunds = null; // Should come from Member_Account__c custom fields
                        accountInfo.reservedFunds = null; // Should come from Member_Account__c custom fields
                    } else {
                        accountInfo.allocatedFunds = null;
                        accountInfo.reservedFunds = null;
                    }

                    accountInfo.effectiveDate = null; // No real field available
                    accountInfo.expirationDate = relatedAccount.Account_Expiration_Date__c;
                    accountInfo.lastActivity = null; // No real field available

                    result.relatedAccounts.add(accountInfo);
                }
            }

            return result;

        } catch (Exception e) {
            System.debug('Error in getMemberAccountData: ' + e.getMessage());
            throw new AuraHandledException('Error loading Member Account data: ' + e.getMessage());
        }
    }

    /**
     * Get Financial Validation data for the case
     * RAY'S DOMAIN EXPERTISE: Real-time financial validation and smart calculations
     */
    @AuraEnabled(cacheable=true)
    public static FinancialValidationData getFinancialValidationData(Id caseId) {
        try {
            // Get case with REAL financial fields ONLY
            Case currentCase = [
                SELECT Id, CaseNumber,
                       Cost__c, MSA_Funds_Payment__c, Non_MSA_Funds_Payment__c,
                       Case_BCN_Payment__c, LR_Payment_Amount__c,
                       Apply_Bill_Fee__c, Apply_Savings_Fee__c, WAM_Vendor_Exception__c,
                       Custodial_Account__r.Name,
                       Custodial_Account__r.Account_Expiration_Date__c,
                       Custodial_Account__r.MemAccount_SAK_Status__c
                FROM Case
                WHERE Id = :caseId
                LIMIT 1
            ];

            FinancialValidationData result = new FinancialValidationData();
            result.caseId = currentCase.Id;
            result.caseNumber = currentCase.CaseNumber;

            // Fund availability - Query REAL Member_Account__c data
            List<Member_Account__c> memberAccounts = [
                SELECT Id, Name, Type__c, BalancePosted__c, BalanceAccrued__c
                FROM Member_Account__c
                WHERE Type__c IN ('MSA', 'PCA', 'SAK')
                LIMIT 10
            ];

            // Initialize all values to null (no hardcoding)
            result.msaAvailable = null;
            result.msaAllocated = null;
            result.msaReserved = null;
            result.pcaAvailable = null;
            result.pcaAllocated = null;
            result.pcaReserved = null;
            result.sakAvailable = null;
            result.sakAllocated = null;
            result.sakReserved = null;

            // Use REAL account data where available
            for (Member_Account__c account : memberAccounts) {
                Decimal balance = account.BalancePosted__c;
                if (balance != null && balance > 0) {
                    // TRINITY PRINCIPLE: NO HARDCODED ALLOCATION PERCENTAGES
                    if (account.Type__c == 'MSA') {
                        result.msaAvailable = balance;
                        result.msaAllocated = null; // Should come from Member_Account__c.MSA_Allocated__c field
                        result.msaReserved = null;  // Should come from Member_Account__c.MSA_Reserved__c field
                    } else if (account.Type__c == 'PCA') {
                        result.pcaAvailable = balance;
                        result.pcaAllocated = null; // Should come from Member_Account__c.PCA_Allocated__c field
                        result.pcaReserved = null;  // Should come from Member_Account__c.PCA_Reserved__c field
                    } else if (account.Type__c == 'SAK') {
                        result.sakAvailable = balance;
                        result.sakAllocated = null; // Should come from Member_Account__c.SAK_Allocated__c field
                        result.sakReserved = null;  // Should come from Member_Account__c.SAK_Reserved__c field
                    }
                }
            }

            // Calculation amounts - Use ONLY real case data, no fallbacks
            result.originalAmount = currentCase.Cost__c;
            result.negotiatedAmount = currentCase.Case_BCN_Payment__c != null ?
                                    currentCase.Case_BCN_Payment__c :
                                    currentCase.LR_Payment_Amount__c;

            // Fee structure - Use real case settings only, no hardcoded amounts
            // Query system settings or configuration for fee amounts if needed
            result.billFee = currentCase.Apply_Bill_Fee__c == true ? null : null; // No hardcoded fee amount
            result.savingsFeePercentage = currentCase.Apply_Savings_Fee__c == true ? null : null; // No hardcoded percentage

            // WAM Vendor Exception handling - boolean logic only
            if (currentCase.WAM_Vendor_Exception__c == true) {
                result.billFee = null;
                result.savingsFeePercentage = null;
            }

            return result;

        } catch (Exception e) {
            System.debug('Error in getFinancialValidationData: ' + e.getMessage());
            throw new AuraHandledException('Error loading financial validation data: ' + e.getMessage());
        }
    }

    /**
     * Update Adjudication Controls for the case
     * RAY'S TOGGLES: Save fee processing preferences
     */
    @AuraEnabled
    public static void updateAdjudicationControls(Id caseId, Boolean applyBillFee, Boolean applySavingsFee, Boolean wamVendorException) {
        try {
            Case caseToUpdate = new Case(
                Id = caseId,
                Apply_Bill_Fee__c = applyBillFee,
                Apply_Savings_Fee__c = applySavingsFee,
                WAM_Vendor_Exception__c = wamVendorException
            );

            update caseToUpdate;

        } catch (Exception e) {
            System.debug('Error in updateAdjudicationControls: ' + e.getMessage());
            throw new AuraHandledException('Error updating adjudication controls: ' + e.getMessage());
        }
    }

    /**
     * Get Bill Flags data for the case
     * RAY'S COMPLEX REQUIREMENTS: Color-coded special handling with comprehensive flag management
     */
    @AuraEnabled(cacheable=true)
    public static BillFlagsData getBillFlagsData(Id caseId) {
        try {
            // Get case with REAL flag-related fields ONLY
            Case currentCase = [
                SELECT Id, CaseNumber,
                       Exhausted_Flag__c, Status, Type, IsEscalated, IsStopped, StopStartDate,
                       Comments, LR_Case_Type__c,
                       Custodial_Account__r.Name,
                       Custodial_Account__r.Account_Expiration_Date__c,
                       Custodial_Account__r.MemAccount_SAK_Status__c
                FROM Case
                WHERE Id = :caseId
                LIMIT 1
            ];

            BillFlagsData result = new BillFlagsData();
            result.caseId = currentCase.Id;
            result.caseNumber = currentCase.CaseNumber;

            // RAY'S FLAG REQUIREMENTS: Map real fields to flag concepts
            result.exhaustAccount = currentCase.Exhausted_Flag__c;
            result.specialHandling = currentCase.IsEscalated;
            result.holdForMember = currentCase.IsStopped;
            result.holdDate = currentCase.StopStartDate;
            result.flagType = currentCase.LR_Case_Type__c;
            result.flagSubType = currentCase.Type;
            result.flagNotes = currentCase.Comments;
            result.caseStatus = currentCase.Status;

            // RAY'S COLOR CODING: Determine flag status and color
            result.flagStatus = determineFlagStatus(currentCase);
            result.flagColor = determineFlagColor(result.flagStatus);
            result.hasActiveFlags = result.exhaustAccount || result.specialHandling || result.holdForMember;

            // Account information
            result.memberAccountName = currentCase.Custodial_Account__r.Name;
            result.sakStatus = currentCase.Custodial_Account__r.MemAccount_SAK_Status__c;
            result.accountExpirationDate = currentCase.Custodial_Account__r.Account_Expiration_Date__c;

            return result;

        } catch (Exception e) {
            throw new AuraHandledException('Error retrieving Bill Flags data: ' + e.getMessage());
        }
    }

    /**
     * RAY'S COLOR-CODED STATUS LOGIC: Determine flag status based on case state
     */
    private static String determineFlagStatus(Case caseRecord) {
        // Red = Incomplete (has flags but missing required info)
        if ((caseRecord.Exhausted_Flag__c || caseRecord.IsEscalated || caseRecord.IsStopped) &&
            String.isBlank(caseRecord.Comments)) {
            return 'Incomplete';
        }

        // Pink = Pending (flags set, waiting for action)
        if (caseRecord.IsStopped || caseRecord.IsEscalated) {
            return 'Pending';
        }

        // Green = Resolved (flags handled appropriately)
        if (caseRecord.Exhausted_Flag__c && String.isNotBlank(caseRecord.Comments)) {
            return 'Resolved';
        }

        // Default = No flags
        return 'None';
    }

    /**
     * RAY'S COLOR SYSTEM: Map status to colors
     */
    private static String determineFlagColor(String flagStatus) {
        switch on flagStatus {
            when 'Incomplete' { return 'error'; }      // Red
            when 'Pending' { return 'warning'; }      // Pink/Orange
            when 'Resolved' { return 'success'; }     // Green
            when else { return 'light'; }             // Default
        }
    }

    // Data Transfer Objects (DTOs) for Medical Billing Domain
    // TRINITY PRINCIPLE: Domain-specific data models
    
    public class InjuryData {
        @AuraEnabled public Id caseId;
        @AuraEnabled public List<InjuryScenario> injuries;
        @AuraEnabled public MemberAccountInfo memberAccountInfo;
    }

    public class MemberAccountInfo {
        @AuraEnabled public String accountName;
    }
    
    public class InjuryScenario {
        @AuraEnabled public String id;
        @AuraEnabled public String caseNumber;
        @AuraEnabled public Date injuryDate;
        @AuraEnabled public String patientId;
        @AuraEnabled public String firstName;
        @AuraEnabled public String lastName;
        @AuraEnabled public String memberAccount;
        @AuraEnabled public String diagnosisCode;
        @AuraEnabled public String allDiagnosisCodes;
        @AuraEnabled public String status;
        @AuraEnabled public String bodyPart;
        @AuraEnabled public String injuryType;
        @AuraEnabled public String treatmentCategory;

        // Additional fields required by LWC template
        @AuraEnabled public Date dateOfInjury; // LWC expects this field name
        @AuraEnabled public String coverageStatus; // Coverage status for injury
        @AuraEnabled public String authorizationRequired; // Authorization requirement
        @AuraEnabled public String description; // Injury description
        @AuraEnabled public String coverageNotes; // Coverage notes
        @AuraEnabled public String statusClass; // CSS class for status styling
    }
    
    public class RestrictionsData {
        @AuraEnabled public Id caseId;
        @AuraEnabled public List<RestrictionInfo> restrictions;
    }
    
    public class RestrictionInfo {
        @AuraEnabled public String id;
        @AuraEnabled public String restrictionType;
        @AuraEnabled public String description;
        @AuraEnabled public String caseNumber;
        @AuraEnabled public String accountType;
        @AuraEnabled public Date effectiveDate;
        @AuraEnabled public String status;
        @AuraEnabled public Boolean authorizationRequired;
    }

    public class RxData {
        @AuraEnabled public Id caseId;
        @AuraEnabled public String caseNumber;
        @AuraEnabled public String pbmInvoiceMemberId;
        @AuraEnabled public String pbmInvoiceNumber;
        @AuraEnabled public Boolean pharmacyReprocess;
        @AuraEnabled public String rxCategory;
        @AuraEnabled public String rxDescription;
        @AuraEnabled public String rxDescription2;
        @AuraEnabled public String calculationMethodRx;
        @AuraEnabled public String memberAccountName;
        @AuraEnabled public String sakStatus;
        @AuraEnabled public Date accountExpirationDate;
    }

    public class DMEData {
        @AuraEnabled public Id caseId;
        @AuraEnabled public String caseNumber;
        @AuraEnabled public Decimal mcaTotal;
        @AuraEnabled public Decimal mcaTotalMedicals;
        @AuraEnabled public Decimal mcaTotalPrescriptions;
        @AuraEnabled public Decimal cost;
        @AuraEnabled public String costDriverItem;
        @AuraEnabled public Boolean facilities;
        @AuraEnabled public Boolean diagnosticMedicalCare;
        @AuraEnabled public String memberAccountName;
        @AuraEnabled public String sakStatus;
        @AuraEnabled public Date accountExpirationDate;
    }

    public class EOBData {
        @AuraEnabled public Id caseId;
        @AuraEnabled public String caseNumber;
        @AuraEnabled public String eobNote;
        @AuraEnabled public Decimal bcnPayment;
        @AuraEnabled public Decimal paymentAmount;
        @AuraEnabled public Date paymentDate;
        @AuraEnabled public String paymentDetails;
        @AuraEnabled public Boolean paymentSubmitted;
        @AuraEnabled public String bcnNumber;
        @AuraEnabled public String bcnName;
        @AuraEnabled public Boolean denial;
        @AuraEnabled public String denialReason;
        @AuraEnabled public String memberAccountName;
        @AuraEnabled public String sakStatus;
        @AuraEnabled public Date accountExpirationDate;
    }

    public class DocumentData {
        @AuraEnabled public Id caseId;
        @AuraEnabled public String caseNumber;
        @AuraEnabled public Decimal numberOfPages;
        @AuraEnabled public String documentAttention;
        @AuraEnabled public String documentAddress;
        @AuraEnabled public String documentationList;
        @AuraEnabled public String memberAccountName;
        @AuraEnabled public String sakStatus;
        @AuraEnabled public Date accountExpirationDate;
        @AuraEnabled public List<AttachedDocument> attachedDocuments;
        @AuraEnabled public Integer documentCount;

        // TRINITY ENHANCEMENT: Add summary statistics for Ray's dashboard
        @AuraEnabled public Integer totalDocumentSize;
        @AuraEnabled public String formattedTotalSize;
        @AuraEnabled public Map<String, Integer> documentCategoryBreakdown;
    }

    public class AttachedDocument {
        @AuraEnabled public Id documentId;
        @AuraEnabled public String title;
        @AuraEnabled public String fileType;
        @AuraEnabled public Integer contentSize;
        @AuraEnabled public DateTime createdDate;
        @AuraEnabled public Boolean isPdf;
        @AuraEnabled public Boolean isOfficeDoc;

        // TRINITY ENHANCEMENT: Add missing metadata fields for complete document information
        @AuraEnabled public DateTime lastModifiedDate;
        @AuraEnabled public String ownerName;
        @AuraEnabled public String fileExtension;
        @AuraEnabled public String formattedSize;
        @AuraEnabled public String documentCategory;
        @AuraEnabled public Id contentVersionId;
        @AuraEnabled public String previewUrl;
        @AuraEnabled public String downloadUrl;
    }

    public class FollowUpData {
        @AuraEnabled public Id caseId;
        @AuraEnabled public String caseNumber;
        @AuraEnabled public BCNFollowUpInfo bcnFollowUp;
        @AuraEnabled public RefundFollowUpInfo refundFollowUp;
        @AuraEnabled public String memberAccountName;
        @AuraEnabled public String sakStatus;
        @AuraEnabled public Date accountExpirationDate;
    }

    public class BCNFollowUpInfo {
        @AuraEnabled public Boolean threeMonthFollowUp;
        @AuraEnabled public Date threeMonthFollowUpDate;
        @AuraEnabled public Boolean sixMonthFollowUp;
        @AuraEnabled public Date sixMonthFollowUpDate;
        @AuraEnabled public Date internalDueDate;
        @AuraEnabled public Date externalDueDate;
        @AuraEnabled public String internalNote;
        @AuraEnabled public String caseNotes;
        @AuraEnabled public String comments;
    }

    public class RefundFollowUpInfo {
        @AuraEnabled public String refundReason;
        @AuraEnabled public Boolean hasRefundRequest;
    }

    public class MemberAccountData {
        @AuraEnabled public Id caseId;
        @AuraEnabled public String caseNumber;
        @AuraEnabled public AccountInfo primaryAccount;
        @AuraEnabled public List<AccountInfo> relatedAccounts;
    }

    public class AccountInfo {
        @AuraEnabled public Id id;
        @AuraEnabled public String name;
        @AuraEnabled public String accountType;
        @AuraEnabled public String status;
        @AuraEnabled public Decimal availableBalance;
        @AuraEnabled public Decimal allocatedFunds;
        @AuraEnabled public Decimal reservedFunds;
        @AuraEnabled public Date effectiveDate;
        @AuraEnabled public Date expirationDate;
        @AuraEnabled public Date lastActivity;
    }

    public class FinancialValidationData {
        @AuraEnabled public Id caseId;
        @AuraEnabled public String caseNumber;
        @AuraEnabled public Decimal msaAvailable;
        @AuraEnabled public Decimal msaAllocated;
        @AuraEnabled public Decimal msaReserved;
        @AuraEnabled public Decimal pcaAvailable;
        @AuraEnabled public Decimal pcaAllocated;
        @AuraEnabled public Decimal pcaReserved;
        @AuraEnabled public Decimal sakAvailable;
        @AuraEnabled public Decimal sakAllocated;
        @AuraEnabled public Decimal sakReserved;
        @AuraEnabled public Decimal originalAmount;
        @AuraEnabled public Decimal negotiatedAmount;
        @AuraEnabled public Decimal billFee;
        @AuraEnabled public Decimal savingsFeePercentage;
    }

    public class AdjudicationControlData {
        @AuraEnabled public Id caseId;
        @AuraEnabled public String caseNumber;
        @AuraEnabled public Boolean applyBillFee;
        @AuraEnabled public Boolean applySavingsFee;
        @AuraEnabled public Boolean wamVendorException;
        @AuraEnabled public Decimal totalCost;
        @AuraEnabled public Decimal currentPayment;
        @AuraEnabled public Decimal msaFundsPayment;
        @AuraEnabled public Decimal nonMsaFundsPayment;
    }

    public class BillFlagsData {
        @AuraEnabled public Id caseId;
        @AuraEnabled public String caseNumber;
        @AuraEnabled public Boolean exhaustAccount;
        @AuraEnabled public Boolean specialHandling;
        @AuraEnabled public Boolean holdForMember;
        @AuraEnabled public DateTime holdDate;
        @AuraEnabled public String flagType;
        @AuraEnabled public String flagSubType;
        @AuraEnabled public String flagNotes;
        @AuraEnabled public String caseStatus;
        @AuraEnabled public String flagStatus;
        @AuraEnabled public String flagColor;
        @AuraEnabled public Boolean hasActiveFlags;
        @AuraEnabled public String memberAccountName;
        @AuraEnabled public String sakStatus;
        @AuraEnabled public Date accountExpirationDate;
    }
}