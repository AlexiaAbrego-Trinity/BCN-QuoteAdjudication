/**
 * @description API layer for BCN/Quote Adjudication LWC interactions
 * @author Trinity Deployment Architect
 * @date 2025-01-09
 * 
 * TRINITY ARCHITECTURE: API Layer handles LWC interactions and validation
 * - Input validation and sanitization
 * - Exception handling for UI consumption
 * - Delegation to service layer
 * 
 * MATT'S REQUIREMENTS: Clean separation between UI and business logic
 * RAY'S REQUIREMENTS: Support Claims workflow with reliable data access
 */
public with sharing class TRM_BCNAdjudicationApi {
    
    /**
     * @description Get Member Account data for BCN/Quote Case adjudication
     * @param caseId The Case record ID
     * @return AccountsData wrapper with Member Account information
     * 
     * TRINITY PRINCIPLE: API layer validates input and handles exceptions
     * ANTI-SPIRAL: Simple delegation to service layer, no complex logic here
     */
    @AuraEnabled(cacheable=true)
    public static TRM_BCNAdjudicationService.AccountsData getMemberAccountData(Id caseId) {
        try {
            // Input validation
            if (caseId == null) {
                throw new IllegalArgumentException('Case ID is required');
            }
            
            // Delegate to service layer
            return TRM_BCNAdjudicationService.getMemberAccountData(caseId);
            
        } catch (Exception e) {
            // Convert to AuraHandledException for LWC consumption
            throw new AuraHandledException('Error retrieving Member Account data: ' + e.getMessage());
        }
    }
    
    /**
     * @description Get Coverage information for medical billing scenarios
     * @param caseId The Case record ID
     * @return CoverageData wrapper with coverage scenarios
     * 
     * RAY'S DOMAIN: Medical coverage types for Claims staff review
     */
    @AuraEnabled(cacheable=true)
    public static TRM_BCNAdjudicationService.CoverageData getCoverageData(Id caseId) {
        try {
            // Input validation
            if (caseId == null) {
                throw new IllegalArgumentException('Case ID is required');
            }
            
            // Delegate to service layer
            return TRM_BCNAdjudicationService.getCoverageData(caseId);
            
        } catch (Exception e) {
            throw new AuraHandledException('Error retrieving Coverage data: ' + e.getMessage());
        }
    }
    
    /**
     * @description Get Coordination of Benefits data
     * @param caseId The Case record ID
     * @return COBData wrapper with payer hierarchy
     * 
     * RAY'S CLAIMS WORKFLOW: COB is critical for Claims adjudication
     */
    @AuraEnabled(cacheable=true)
    public static TRM_BCNAdjudicationService.COBData getCOBData(Id caseId) {
        try {
            // Input validation
            if (caseId == null) {
                throw new IllegalArgumentException('Case ID is required');
            }
            
            // Delegate to service layer
            return TRM_BCNAdjudicationService.getCOBData(caseId);
            
        } catch (Exception e) {
            throw new AuraHandledException('Error retrieving COB data: ' + e.getMessage());
        }
    }

    /**
     * @description Get Injury data for medical billing scenarios
     * @param caseId The Case record ID
     * @return InjuryData wrapper with injury information
     *
     * TRINITY PRINCIPLE: Domain-specific API methods for clean architecture
     */
    @AuraEnabled(cacheable=true)
    public static TRM_MedicalBillingService.InjuryData getInjuryData(Id caseId) {
        try {
            if (caseId == null) {
                throw new IllegalArgumentException('Case ID is required');
            }

            return TRM_MedicalBillingService.getInjuryData(caseId);

        } catch (Exception e) {
            throw new AuraHandledException('Error retrieving Injury data: ' + e.getMessage());
        }
    }

    /**
     * @description Get Restrictions data for treatment limitations
     * @param caseId The Case record ID
     * @return RestrictionsData wrapper with restriction information
     *
     * TRINITY PRINCIPLE: Domain-specific API methods for clean architecture
     */
    @AuraEnabled(cacheable=true)
    public static TRM_MedicalBillingService.RestrictionsData getRestrictionsData(Id caseId) {
        try {
            if (caseId == null) {
                throw new IllegalArgumentException('Case ID is required');
            }

            return TRM_MedicalBillingService.getRestrictionsData(caseId);

        } catch (Exception e) {
            throw new AuraHandledException('Error retrieving Restrictions data: ' + e.getMessage());
        }
    }

    /**
     * @description Get Rx/Prescription data for medication coverage scenarios
     * @param caseId The Case record ID
     * @return RxData wrapper with prescription information
     *
     * TRINITY PRINCIPLE: Domain-specific API methods for clean architecture
     */
    @AuraEnabled(cacheable=true)
    public static TRM_MedicalBillingService.RxData getRxData(Id caseId) {
        try {
            if (caseId == null) {
                throw new IllegalArgumentException('Case ID is required');
            }

            return TRM_MedicalBillingService.getRxData(caseId);

        } catch (Exception e) {
            throw new AuraHandledException('Error retrieving Rx data: ' + e.getMessage());
        }
    }

    /**
     * @description Get DME/Equipment data for medical equipment scenarios
     * @param caseId The Case record ID
     * @return DMEData wrapper with equipment information
     *
     * TRINITY PRINCIPLE: Domain-specific API methods for clean architecture
     */
    @AuraEnabled(cacheable=true)
    public static TRM_MedicalBillingService.DMEData getDMEData(Id caseId) {
        try {
            if (caseId == null) {
                throw new IllegalArgumentException('Case ID is required');
            }

            return TRM_MedicalBillingService.getDMEData(caseId);

        } catch (Exception e) {
            throw new AuraHandledException('Error retrieving DME data: ' + e.getMessage());
        }
    }

    /**
     * @description Get EOB/Benefits processing data for explanation of benefits scenarios
     * @param caseId The Case record ID
     * @return EOBData wrapper with benefits processing information
     *
     * TRINITY PRINCIPLE: Domain-specific API methods for clean architecture
     */
    @AuraEnabled(cacheable=true)
    public static TRM_MedicalBillingService.EOBData getEOBData(Id caseId) {
        try {
            if (caseId == null) {
                throw new IllegalArgumentException('Case ID is required');
            }

            return TRM_MedicalBillingService.getEOBData(caseId);

        } catch (Exception e) {
            throw new AuraHandledException('Error retrieving EOB data: ' + e.getMessage());
        }
    }

    /**
     * @description Get Document Management data for document attachment and viewing
     * @param caseId The Case record ID
     * @return DocumentData wrapper with document information
     *
     * TRINITY PRINCIPLE: Domain-specific API methods for clean architecture
     */
    @AuraEnabled(cacheable=true)
    public static TRM_MedicalBillingService.DocumentData getDocumentData(Id caseId) {
        try {
            if (caseId == null) {
                throw new IllegalArgumentException('Case ID is required');
            }

            return TRM_MedicalBillingService.getDocumentData(caseId);

        } catch (Exception e) {
            throw new AuraHandledException('Error retrieving Document data: ' + e.getMessage());
        }
    }

    /**
     * @description Get Follow-Up Management data for BCN and Refund follow-ups
     * @param caseId The Case record ID
     * @return FollowUpData wrapper with follow-up information
     *
     * TRINITY PRINCIPLE: Domain-specific API methods for clean architecture
     */
    @AuraEnabled(cacheable=true)
    public static TRM_MedicalBillingService.FollowUpData getFollowUpData(Id caseId) {
        try {
            if (caseId == null) {
                throw new IllegalArgumentException('Case ID is required');
            }

            return TRM_MedicalBillingService.getFollowUpData(caseId);

        } catch (Exception e) {
            throw new AuraHandledException('Error retrieving Follow-Up data: ' + e.getMessage());
        }
    }

    /**
     * @description Set BCN Follow-Up date and note
     * @param caseId The Case record ID
     * @param followUpDate The follow-up date to set
     * @param followUpNote The follow-up note to set
     * @return Success message
     *
     * RAY'S REQUIREMENT: "BCN follow ups: We can set a date to review the BCN"
     * Examples: "Funds arrive in 5 days", "Missing pages 3 and 4"
     */
    @AuraEnabled
    public static String setBcnFollowUp(Id caseId, Date followUpDate, String followUpNote) {
        try {
            if (caseId == null) {
                throw new IllegalArgumentException('Case ID is required');
            }

            Case caseToUpdate = new Case(
                Id = caseId,
                Internal_Due_Date__c = followUpDate,
                Internal_Note__c = followUpNote
            );

            update caseToUpdate;

            return 'BCN Follow-up successfully set for ' + (followUpDate != null ? followUpDate.format() : 'no date') +
                   (String.isNotBlank(followUpNote) ? ' with note: ' + followUpNote : '');

        } catch (Exception e) {
            throw new AuraHandledException('Error setting BCN Follow-up: ' + e.getMessage());
        }
    }

    /**
     * @description Set Refund Follow-Up date and note
     * @param caseId The Case record ID
     * @param followUpDate The follow-up date to set
     * @param followUpNote The follow-up note to set
     * @return Success message
     *
     * RAY'S REQUIREMENT: Separate refund follow-up system (month to year timeframe)
     */
    @AuraEnabled
    public static String setRefundFollowUp(Id caseId, Date followUpDate, String followUpNote) {
        try {
            if (caseId == null) {
                throw new IllegalArgumentException('Case ID is required');
            }

            Case caseToUpdate = new Case(
                Id = caseId,
                Due_Date__c = followUpDate,
                CaseRefund_Reason_for_Refund_Request__c = followUpNote
            );

            update caseToUpdate;

            return 'Refund Follow-up successfully set for ' + (followUpDate != null ? followUpDate.format() : 'no date') +
                   (String.isNotBlank(followUpNote) ? ' with note: ' + followUpNote : '');

        } catch (Exception e) {
            throw new AuraHandledException('Error setting Refund Follow-up: ' + e.getMessage());
        }
    }

    /**
     * @description Get Bill Flags data for color-coded special handling
     * @param caseId The Case record ID
     * @return BillFlagsData wrapper with flag information
     *
     * TRINITY PRINCIPLE: Domain-specific API methods for clean architecture
     */
    @AuraEnabled(cacheable=true)
    public static TRM_MedicalBillingService.BillFlagsData getBillFlagsData(Id caseId) {
        try {
            if (caseId == null) {
                throw new IllegalArgumentException('Case ID is required');
            }

            return TRM_MedicalBillingService.getBillFlagsData(caseId);

        } catch (Exception e) {
            throw new AuraHandledException('Error retrieving Bill Flags data: ' + e.getMessage());
        }
    }
}