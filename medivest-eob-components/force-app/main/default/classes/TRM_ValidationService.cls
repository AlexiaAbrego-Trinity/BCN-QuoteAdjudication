/**
 * @description Comprehensive validation service for BCN Quote Adjudication
 * @author Trinity Deployment Architect
 * @date 2025-01-21
 * 
 * Implements Ray's complete validation rule set:
 * - BCN-Level Validations (7 rules)
 * - Charge-Level Validations (3 rules)
 * - Line Item Validations (7 rules)
 * - Relational Integrity Validations (2 rules)
 */
public with sharing class TRM_ValidationService {
    
    /**
     * @description Main validation orchestrator - validates BCN Quote Case for adjudication
     * @param caseId The Case ID to validate
     * @return ValidationResult containing all validation failures organized by category
     */
    @AuraEnabled
    public static ValidationResult validateBCNQuoteForAdjudication(Id caseId) {
        ValidationResult result = new ValidationResult();
        result.caseId = caseId;
        
        try {
            // Get Case data
            Case bcnCase = getCaseData(caseId);
            result.caseNumber = bcnCase.CaseNumber;
            
            // Get line items
            List<Bill_Line_Item__c> lineItems = TRM_MedicalBillingService.getBillLineItems(caseId);
            
            // Run all validation categories
            result.bcnLevelFailures = validateBCNLevel(bcnCase, lineItems);
            result.chargeLevelFailures = validateCharges(bcnCase, lineItems);
            result.lineItemFailures = validateLineItems(lineItems);
            result.relationalIntegrityFailures = validateRelationalIntegrity(bcnCase, lineItems);

            // Separate warnings from errors
            result.warnings = new List<ValidationFailure>();
            for (ValidationFailure failure : result.chargeLevelFailures) {
                if (failure.severity == 'warning') {
                    result.warnings.add(failure);
                }
            }
            // Remove warnings from charge level failures
            List<ValidationFailure> chargeErrors = new List<ValidationFailure>();
            for (ValidationFailure failure : result.chargeLevelFailures) {
                if (failure.severity == 'error') {
                    chargeErrors.add(failure);
                }
            }
            result.chargeLevelFailures = chargeErrors;

            // TRINITY: Track passed rules for debugging
            result.passedRules = collectPassedRules(bcnCase, lineItems, result);

            // Determine if can proceed (no blocking errors)
            result.canProceed = (
                result.bcnLevelFailures.isEmpty() &&
                result.chargeLevelFailures.isEmpty() &&
                result.lineItemFailures.isEmpty() &&
                result.relationalIntegrityFailures.isEmpty()
            );
            
        } catch (Exception e) {
            System.debug('Validation error: ' + e.getMessage());
            throw new AuraHandledException('Validation failed: ' + e.getMessage());
        }
        
        return result;
    }
    
    /**
     * @description BCN-Level validations (7 rules)
     * @param bcnCase The Case record to validate
     * @return List of BCN-level validation failures
     */
    private static List<ValidationFailure> validateBCNLevel(Case bcnCase, List<Bill_Line_Item__c> lineItems) {
        List<ValidationFailure> failures = new List<ValidationFailure>();
        
        // Rule 1: Status = On Hold
        if (bcnCase.Status == 'On Hold') {
            failures.add(new ValidationFailure(
                'bcn_status_on_hold',
                'BCN Status Check',
                'error',
                'BCN is currently On Hold',
                'Cannot adjudicate while case is On Hold. Change status to proceed.',
                'BCN_LEVEL'
            ));
        }
        
        // Rule 2: Previously Adjudicated
        if (bcnCase.Status == 'Adjudicated' || bcnCase.Status == 'Closed') {
            failures.add(new ValidationFailure(
                'bcn_previously_adjudicated',
                'Adjudication Status Check',
                'error',
                'BCN has already been adjudicated',
                'To edit payments, revert adjudication status first.',
                'BCN_LEVEL'
            ));
        }
        
        // Rule 3: Received Date Required
        if (bcnCase.Date_Received__c == null) {
            failures.add(createRequiredFieldFailure('Received Date', 'Date_Received__c'));
        }
        
        // Rule 4: Member (Entity) Required
        if (bcnCase.BCN__r.Member_Account__c == null) {
            failures.add(createRequiredFieldFailure('Member (Entity)', 'BCN__r.Member_Account__c'));
        }
        
        // Rule 5: Payee (Entity) Required
        if (bcnCase.Payee_Name__c == null) {
            failures.add(createRequiredFieldFailure('Payee (Entity)', 'Payee_Name__c'));
        }
        
        // Rule 6: Payee Address Required
        if (bcnCase.Payee_Address__c == null) {
            failures.add(createRequiredFieldFailure('Payee Address', 'Payee_Address__c'));
        }
        
        // Rule 7: Total Claim Charge Required
        Decimal totalCharge = 0;
        if (bcnCase.Total_Claim_charge__c != null && bcnCase.Total_Claim_charge__c > 0) {
            totalCharge = bcnCase.Total_Claim_charge__c;
        } else {
            for (Bill_Line_Item__c item : lineItems) {
                totalCharge += safeDecimal(item.Charge__c);
            }
        }
        if (totalCharge == 0) {
            failures.add(createRequiredFieldFailure('Total Claim Charge', 'Total_Claim_charge__c'));
        }
        
        return failures;
    }
    
    /**
     * @description Charge-Level validations (3 rules)
     * @param bcnCase The Case record
     * @param lineItems The Bill Line Items to validate
     * @return List of charge-level validation failures
     */
    private static List<ValidationFailure> validateCharges(Case bcnCase, List<Bill_Line_Item__c> lineItems) {
        List<ValidationFailure> failures = new List<ValidationFailure>();

        // TRINITY DEFENSIVE PROGRAMMING: Use safeDecimal() for ALL conversions
        Decimal totalClaimCharge = safeDecimal(bcnCase.Total_Claim_charge__c);
        Decimal cumulativeCharge = 0.0;
        Decimal cumulativePayment = 0.0;
        Map<Id, Decimal> accountPayments = new Map<Id, Decimal>();

        // Calculate cumulative charges and payments
        for (Bill_Line_Item__c item : lineItems) {
            cumulativeCharge += safeDecimal(item.Charge__c);

            Decimal itemPayment = 0.0;
            itemPayment += safeDecimal(item.Approved_Amount__c);
            // TRINITY: X3rd_Party_Curr__c is Currency field, use directly (no parsing needed)
            itemPayment += (item.X3rd_Party_Curr__c != null ? item.X3rd_Party_Curr__c : 0.0);
            itemPayment += safeDecimal(item.Patient_Responsibility__c);
            itemPayment += safeDecimal(item.Other_Ins_Paid__c);
            cumulativePayment += itemPayment;

            // Track payments by account
            if (item.Account__c != null) {
                if (!accountPayments.containsKey(item.Account__c)) {
                    accountPayments.put(item.Account__c, 0.0);
                }
                accountPayments.put(item.Account__c, accountPayments.get(item.Account__c) + itemPayment);
            }
        }

        // TRINITY FIX: If Total_Claim_charge__c is NULL/0, use calculated cumulativeCharge as the reference
        // This handles cases where the Bill record doesn't have Total_Claim_charge__c populated
        if (totalClaimCharge == 0 && cumulativeCharge > 0) {
            totalClaimCharge = cumulativeCharge;
        }

        // Rule 1: Cumulative charges = Total Claim Charge (±$0.01 tolerance)
        // TRINITY: Skip validation if both values are 0 (no data entered yet)
        if (totalClaimCharge > 0 && Math.abs(cumulativeCharge - totalClaimCharge) > 0.01) {
            Decimal difference = cumulativeCharge - totalClaimCharge;
            failures.add(new ValidationFailure(
                'cumulative_charge_mismatch',
                'Cumulative Charges Validation',
                'error',
                String.format('Line item charges (${0}) do not equal Total Claim Charge (${1})', 
                    new List<String>{formatCurrency(cumulativeCharge), formatCurrency(totalClaimCharge)}),
                String.format('Difference: ${0}. Adjust line items or Total Claim Charge.', 
                    new List<String>{formatCurrency(Math.abs(difference))}),
                'CHARGE_LEVEL'
            ));
        }
        
        // Rule 2: Cumulative payments ≤ Total Claim Charge
        // TRINITY: Skip validation if totalClaimCharge is 0 (no data entered yet)
        if (totalClaimCharge > 0 && cumulativePayment > totalClaimCharge) {
            Decimal overpayment = cumulativePayment - totalClaimCharge;
            failures.add(new ValidationFailure(
                'cumulative_payment_exceeds_charge',
                'Payment Validation',
                'error',
                String.format('Total payments (${0}) exceed Total Claim Charge (${1})', 
                    new List<String>{formatCurrency(cumulativePayment), formatCurrency(totalClaimCharge)}),
                String.format('Overpayment: ${0}. Reduce payment amounts.', 
                    new List<String>{formatCurrency(overpayment)}),
                'CHARGE_LEVEL'
            ));
        }
        
        // Rule 3: Account-specific payments ≤ Account accrued balance (WARNING only)
        if (!accountPayments.isEmpty()) {
            Map<Id, Member_Account__c> accounts = new Map<Id, Member_Account__c>([
                SELECT Id, Name, BalanceAccrued__c
                FROM Member_Account__c
                WHERE Id IN :accountPayments.keySet()
            ]);
            
            for (Id accountId : accountPayments.keySet()) {
                Member_Account__c account = accounts.get(accountId);
                if (account != null) {
                    Decimal accountPayment = accountPayments.get(accountId);
                    Decimal accruedBalance = safeDecimal(account.BalanceAccrued__c);
                    
                    if (accountPayment > accruedBalance) {
                        Decimal shortfall = accountPayment - accruedBalance;
                        failures.add(new ValidationFailure(
                            'account_payment_exceeds_balance',
                            'Account Balance Check',
                            'warning', // WARNING, not error
                            String.format('Payments from {0} (${1}) exceed accrued balance (${2})', 
                                new List<String>{account.Name, formatCurrency(accountPayment), formatCurrency(accruedBalance)}),
                            String.format('Shortfall: ${0}. Reallocate payments or verify account balance.', 
                                new List<String>{formatCurrency(shortfall)}),
                            'CHARGE_LEVEL'
                        ));
                    }
                }
            }
        }
        
        return failures;
    }
    
    /**
     * @description Line Item validations (7 rules)
     * @param lineItems The Bill Line Items to validate
     * @return List of line item validation failures
     */
    private static List<ValidationFailure> validateLineItems(List<Bill_Line_Item__c> lineItems) {
        List<ValidationFailure> failures = new List<ValidationFailure>();
        
        List<String> missingDates = new List<String>();
        List<String> missingCodes = new List<String>();
        List<String> missingQuantity = new List<String>();
        List<String> missingCharge = new List<String>();
        List<String> missingPaid = new List<String>();
        List<String> missingRC1 = new List<String>();
        List<String> missingAccount = new List<String>();
        List<String> negativeCharges = new List<String>();
        List<String> paymentExceedsCharge = new List<String>();
        List<String> invalidDateRanges = new List<String>();
        
        for (Bill_Line_Item__c item : lineItems) {
            // TRINITY FIX: Bill_Line_Item_Number__c is Number(18,0) and could be null
            String lineNum = item.Bill_Line_Item_Number__c != null ?
                            String.valueOf(item.Bill_Line_Item_Number__c.intValue()) : 'N/A';
            
            // Rule 1: Start/End dates
            if (item.Service_Start_Date__c == null || item.Service_End_Date__c == null) {
                missingDates.add(lineNum);
            }
            
            // Rule 2: Revenue Code OR CPT/HCPCS/NDC
            if (String.isBlank(item.Revenue_Code__c) && String.isBlank(item.CPT_HCPCS_NDC__c)) {
                missingCodes.add(lineNum);
            }
            
            // Rule 3: Quantity
            if (item.Quantity__c == null) {
                missingQuantity.add(lineNum);
            }
            
            // Rule 4: Charge
            if (item.Charge__c == null) {
                missingCharge.add(lineNum);
            }
            
            // Rule 5: Paid amount (can be $0 or negative, but must have value)
            if (item.Approved_Amount__c == null) {
                missingPaid.add(lineNum);
            }
            
            // Rule 6: RC1
            if (String.isBlank(item.Remark_Code_1__c)) {
                missingRC1.add(lineNum);
            }
            
            // Rule 7: Member Account
            if (item.Account__c == null) {
                missingAccount.add(lineNum);
            }

            // Rule 8: Negative Charge
            if (item.Charge__c != null && item.Charge__c < 0) {
                negativeCharges.add(lineNum);
            }

            // Rule 9: Payment Exceeds Charge
            if (item.Charge__c != null && item.Approved_Amount__c != null &&
                item.Approved_Amount__c > item.Charge__c) {
                paymentExceedsCharge.add(lineNum);
            }

            // Rule 10: Invalid Date Range
            if (item.Service_Start_Date__c != null && item.Service_End_Date__c != null &&
                item.Service_End_Date__c < item.Service_Start_Date__c) {
                invalidDateRanges.add(lineNum);
            }
        }
        
        // Create failures for each rule
        if (!missingDates.isEmpty()) {
            failures.add(createLineItemFailure('line_missing_service_dates', 'Service Dates Required',
                missingDates.size() + ' line item' + (missingDates.size() > 1 ? 's' : '') + ' missing start/end dates',
                missingDates, 'All line items must have service start and end dates'));
        }
        if (!missingCodes.isEmpty()) {
            failures.add(createLineItemFailure('line_missing_cpt_hcpcs_ndc', 'Revenue Code or CPT/HCPCS/NDC Required',
                missingCodes.size() + ' line item' + (missingCodes.size() > 1 ? 's' : '') + ' missing both Revenue Code and CPT/HCPCS/NDC',
                missingCodes, 'At least one code type is required (both can be entered)'));
        }
        if (!missingQuantity.isEmpty()) {
            failures.add(createLineItemFailure('line_missing_quantity', 'Quantity Required',
                missingQuantity.size() + ' line item' + (missingQuantity.size() > 1 ? 's' : '') + ' missing quantity',
                missingQuantity, 'All line items must have a quantity value'));
        }
        if (!missingCharge.isEmpty()) {
            failures.add(createLineItemFailure('line_missing_charge', 'Charge Required',
                missingCharge.size() + ' line item' + (missingCharge.size() > 1 ? 's' : '') + ' missing charge amount',
                missingCharge, 'All line items must have a charge amount'));
        }
        if (!missingPaid.isEmpty()) {
            failures.add(createLineItemFailure('line_missing_paid_amount', 'Paid Amount Required',
                missingPaid.size() + ' line item' + (missingPaid.size() > 1 ? 's' : '') + ' missing paid amount',
                missingPaid, 'Must enter value for all line items, even if $0.00'));
        }
        if (!missingRC1.isEmpty()) {
            failures.add(createLineItemFailure('line_missing_rc1', 'Remark Code 1 (RC1) Required',
                missingRC1.size() + ' line item' + (missingRC1.size() > 1 ? 's' : '') + ' missing RC1',
                missingRC1, 'RC1 is required for all line items during adjudication'));
        }
        if (!missingAccount.isEmpty()) {
            failures.add(createLineItemFailure('line_missing_account', 'Member Account Required',
                missingAccount.size() + ' line item' + (missingAccount.size() > 1 ? 's' : '') + ' missing Member Account',
                missingAccount, 'Required even if no payment - indicates which account was considered'));
        }
        if (!negativeCharges.isEmpty()) {
            failures.add(createLineItemFailure('line_negative_charge', 'Negative Charges Detected',
                negativeCharges.size() + ' line item' + (negativeCharges.size() > 1 ? 's have' : ' has') + ' negative charge amounts',
                negativeCharges, 'All charges must be positive values'));
        }
        if (!paymentExceedsCharge.isEmpty()) {
            failures.add(createLineItemFailure('line_payment_exceeds_charge', 'Payment Exceeds Charge',
                paymentExceedsCharge.size() + ' line item' + (paymentExceedsCharge.size() > 1 ? 's have' : ' has') + ' approved amounts exceeding charges',
                paymentExceedsCharge, 'Approved amount cannot exceed the original charge amount'));
        }
        if (!invalidDateRanges.isEmpty()) {
            failures.add(createLineItemFailure('line_invalid_service_date_range', 'Invalid Service Date Range',
                invalidDateRanges.size() + ' line item' + (invalidDateRanges.size() > 1 ? 's have' : ' has') + ' end dates before start dates',
                invalidDateRanges, 'Service end date must be on or after service start date'));
        }

        return failures;
    }

    /**
     * @description Relational Integrity validations (2 rules)
     * @param bcnCase The Case record
     * @param lineItems The Bill Line Items to validate
     * @return List of relational integrity validation failures
     */
    private static List<ValidationFailure> validateRelationalIntegrity(Case bcnCase, List<Bill_Line_Item__c> lineItems) {
        List<ValidationFailure> failures = new List<ValidationFailure>();

        // Rule 1: Line item accounts must belong to case member
        // Note: Member_Account__c does NOT have Entity__c field
        // Validate that line item Account__c matches the member account associated with the case
        Set<Id> accountIds = new Set<Id>();
        for (Bill_Line_Item__c item : lineItems) {
            if (item.Account__c != null) {
                accountIds.add(item.Account__c);
            }
        }

        if (!accountIds.isEmpty() && bcnCase.Custodial_Account__c != null) {
            // Get the member account from the case
            List<String> mismatchedLines = new List<String>();

            for (Bill_Line_Item__c item : lineItems) {
                if (item.Account__c != null && item.Account__c != bcnCase.Custodial_Account__c) {
                    // TRINITY FIX: Bill_Line_Item_Number__c is Number(18,0) and could be null
                    String lineNum = item.Bill_Line_Item_Number__c != null ?
                                    String.valueOf(item.Bill_Line_Item_Number__c.intValue()) : 'N/A';
                    mismatchedLines.add(lineNum);
                }
            }

            if (!mismatchedLines.isEmpty()) {
                failures.add(new ValidationFailure(
                    'relational_invalid_account_references',
                    'Account-Member Relationship',
                    'error',
                    mismatchedLines.size() + ' line item' + (mismatchedLines.size() > 1 ? 's have' : ' has') + ' accounts not belonging to case member',
                    'Line item accounts must belong to the member set on the BCN Quote Case. This prevents adjudicating with wrong accounts after changing the member.',
                    'RELATIONAL',
                    String.join(mismatchedLines, ', ')
                ));
            }
        }

        // Rule 2: Payee and Payee Address must be related
        if (bcnCase.Payee_Name__c != null && bcnCase.Payee_Address__c != null) {
            // TRINITY FIX: Address__c has Person_Entity__c and Business_Entity__c, NOT Entity__c
            List<Address__c> payeeAddresses = [
                SELECT Id, Person_Entity__c, Business_Entity__c
                FROM Address__c
                WHERE Id = :bcnCase.Payee_Address__c
                LIMIT 1
            ];

            if (!payeeAddresses.isEmpty()) {
                Address__c payeeAddress = payeeAddresses[0];
                // Check if payee matches either person or business entity field
                Boolean isRelated = (payeeAddress.Person_Entity__c == bcnCase.Payee_Name__c) ||
                                   (payeeAddress.Business_Entity__c == bcnCase.Payee_Name__c);

                if (!isRelated) {
                    failures.add(new ValidationFailure(
                        'payee_address_mismatch',
                        'Payee-Address Relationship',
                        'error',
                        'Payee address does not belong to selected payee',
                        'Ensure payee address is associated with the payee entity',
                        'RELATIONAL'
                    ));
                }
            }
        }

        return failures;
    }

    /**
     * @description Get Case data with all required fields for validation
     * @param caseId The Case ID
     * @return Case record with all validation fields
     */
    private static Case getCaseData(Id caseId) {
        return [
            SELECT Id, CaseNumber, Status, Date_Received__c, AccountId,
                   Payee_Name__c, Payee_Address__c, Total_Claim_charge__c,
                   Custodial_Account__c, BCN__c, BCN__r.Member_Account__c, BCN__r.Member_Account__r.Name
            FROM Case
            WHERE Id = :caseId
            LIMIT 1
        ];
    }

    /**
     * @description Helper method to create required field failure
     * @param fieldLabel The user-friendly field label
     * @param fieldName The API field name
     * @return ValidationFailure for missing required field
     */
    private static ValidationFailure createRequiredFieldFailure(String fieldLabel, String fieldName) {
        return new ValidationFailure(
            'bcn_missing_' + fieldName.toLowerCase(),
            fieldLabel + ' Required',
            'error',
            fieldLabel + ' is not listed on the BCN Quote Case',
            'Enter ' + fieldLabel + ' on the Case record to proceed with adjudication',
            'BCN_LEVEL'
        );
    }

    /**
     * @description Helper method to create line item failure
     * @param ruleId The unique rule identifier
     * @param ruleName The user-friendly rule name
     * @param message The error message
     * @param affectedLines List of affected line numbers
     * @param details Additional details
     * @return ValidationFailure for line item validation
     */
    private static ValidationFailure createLineItemFailure(String ruleId, String ruleName,
                                                          String message, List<String> affectedLines, String details) {
        return new ValidationFailure(
            ruleId,
            ruleName,
            'error',
            message,
            details,
            'LINE_ITEM',
            String.join(affectedLines, ', ')
        );
    }

    /**
     * @description Safely convert any value to Decimal with robust type handling
     * @param value The value to convert (can be Decimal, Integer, String, or null)
     * @param defaultValue The default value to return if conversion fails (default: 0.0)
     * @return Decimal value
     *
     * TRINITY DEFENSIVE PROGRAMMING: This method handles ALL edge cases:
     * - Null values → defaultValue
     * - Decimal values → Returned as-is
     * - Integer/Long literals → Converted to Decimal
     * - String values → Parsed to Decimal (handles currency symbols, commas)
     * - Invalid/unparseable values → defaultValue with debug warning
     */
    private static Decimal safeDecimal(Object value, Decimal defaultValue) {
        try {
            // Handle null
            if (value == null) {
                return defaultValue;
            }

            // Convert to Decimal regardless of input type
            if (value instanceof Decimal) {
                return (Decimal) value;
            } else if (value instanceof Integer) {
                return Decimal.valueOf((Integer) value);
            } else if (value instanceof Long) {
                return Decimal.valueOf((Long) value);
            } else if (value instanceof Double) {
                return Decimal.valueOf((Double) value);
            } else if (value instanceof String) {
                String strValue = (String) value;
                if (String.isBlank(strValue)) {
                    return defaultValue;
                }
                // Remove currency symbols, commas, and whitespace
                strValue = strValue.replaceAll('[^0-9.-]', '');
                if (String.isBlank(strValue)) {
                    return defaultValue;
                }
                return Decimal.valueOf(strValue);
            } else {
                // Unknown type - try to convert to string then parse
                String strValue = String.valueOf(value);
                strValue = strValue.replaceAll('[^0-9.-]', '');
                if (String.isBlank(strValue)) {
                    return defaultValue;
                }
                return Decimal.valueOf(strValue);
            }

        } catch (Exception e) {
            // Defensive fallback - log error and return safe default
            System.debug('WARNING: safeDecimal failed for input: ' + value + ' - Error: ' + e.getMessage());
            return defaultValue;
        }
    }

    /**
     * @description Safely convert any value to Decimal (defaults to 0.0)
     * @param value The value to convert
     * @return Decimal value
     */
    private static Decimal safeDecimal(Object value) {
        return safeDecimal(value, 0.0);
    }

    /**
     * @description Format currency for display with robust type handling
     * @param amount The amount to format (can be Decimal, Integer, String, or null)
     * @return Formatted currency string
     *
     * TRINITY DEFENSIVE PROGRAMMING: This method handles ALL edge cases:
     * - Null values → '0.00'
     * - Decimal values → Properly formatted
     * - Integer literals from ternary operators → Converted to Decimal
     * - String values → Parsed to Decimal
     * - Invalid/unparseable values → '0.00' with debug warning
     */
    private static String formatCurrency(Object amount) {
        try {
            // Handle null
            if (amount == null) {
                return '0.00';
            }

            // Convert to Decimal regardless of input type
            Decimal decimalAmount;

            if (amount instanceof Decimal) {
                decimalAmount = (Decimal) amount;
            } else if (amount instanceof Integer) {
                decimalAmount = Decimal.valueOf((Integer) amount);
            } else if (amount instanceof Long) {
                decimalAmount = Decimal.valueOf((Long) amount);
            } else if (amount instanceof Double) {
                decimalAmount = Decimal.valueOf((Double) amount);
            } else if (amount instanceof String) {
                String strAmount = (String) amount;
                if (String.isBlank(strAmount)) {
                    return '0.00';
                }
                // Remove currency symbols and commas
                strAmount = strAmount.replaceAll('[^0-9.-]', '');
                decimalAmount = Decimal.valueOf(strAmount);
            } else {
                // Unknown type - try to convert to string then parse
                String strAmount = String.valueOf(amount);
                strAmount = strAmount.replaceAll('[^0-9.-]', '');
                decimalAmount = Decimal.valueOf(strAmount);
            }

            // Handle null after conversion
            if (decimalAmount == null) {
                return '0.00';
            }

            // Convert to Double for String.format() - this is required by Apex
            return String.format('{0,number,#,##0.00}', new List<Double>{decimalAmount.doubleValue()});

        } catch (Exception e) {
            // Defensive fallback - log error and return safe default
            System.debug('WARNING: formatCurrency failed for input: ' + amount + ' - Error: ' + e.getMessage());
            return '0.00';
        }
    }

    /**
     * @description Collect all passed validation rules for debugging
     * TRINITY: Helps with transparency and debugging validation logic
     * @param bcnCase The Case record
     * @param lineItems The Bill Line Items
     * @param result The validation result with failures
     * @return List of passed rules
     */
    private static List<ValidationPass> collectPassedRules(Case bcnCase, List<Bill_Line_Item__c> lineItems, ValidationResult result) {
        List<ValidationPass> passedRules = new List<ValidationPass>();
        Set<String> failedRuleIds = new Set<String>();

        // Collect all failed rule IDs
        for (ValidationFailure failure : result.bcnLevelFailures) {
            failedRuleIds.add(failure.ruleId);
        }
        for (ValidationFailure failure : result.chargeLevelFailures) {
            failedRuleIds.add(failure.ruleId);
        }
        for (ValidationFailure failure : result.lineItemFailures) {
            failedRuleIds.add(failure.ruleId);
        }
        for (ValidationFailure failure : result.relationalIntegrityFailures) {
            failedRuleIds.add(failure.ruleId);
        }
        for (ValidationFailure warning : result.warnings) {
            failedRuleIds.add(warning.ruleId);
        }

        // TRINITY DEBUG: Log what we're working with
        System.debug('TRINITY: Failed Rule IDs: ' + failedRuleIds);
        System.debug('TRINITY: BCN Level Failures: ' + result.bcnLevelFailures.size());
        System.debug('TRINITY: Charge Level Failures: ' + result.chargeLevelFailures.size());
        System.debug('TRINITY: Line Item Failures: ' + result.lineItemFailures.size());
        System.debug('TRINITY: Relational Failures: ' + result.relationalIntegrityFailures.size());

        // BCN-Level Rules (7 total)
        if (!failedRuleIds.contains('bcn_status_on_hold')) {
            passedRules.add(new ValidationPass('bcn_status_on_hold', 'Status Not On Hold', 'BCN_LEVEL', 'Case status is valid for adjudication'));
        }
        if (!failedRuleIds.contains('bcn_missing_date_received__c')) {
            passedRules.add(new ValidationPass('bcn_missing_date_received__c', 'Date Received Present', 'BCN_LEVEL', 'Date Received is populated'));
        }
        if (!failedRuleIds.contains('bcn_missing_custodial_account__c')) {
            passedRules.add(new ValidationPass('bcn_missing_custodial_account__c', 'Custodial Account Present', 'BCN_LEVEL', 'Custodial Account is populated'));
        }
        if (!failedRuleIds.contains('bcn_missing_bcn__r.member_account__c')) {
            passedRules.add(new ValidationPass('bcn_missing_bcn__r.member_account__c', 'Member (Claimant) Present', 'BCN_LEVEL', 'Member Account is populated'));
        }
        if (!failedRuleIds.contains('bcn_missing_payee_name__c')) {
            passedRules.add(new ValidationPass('bcn_missing_payee_name__c', 'Payee Name Present', 'BCN_LEVEL', 'Payee Name is populated'));
        }
        if (!failedRuleIds.contains('bcn_missing_payee_address__c')) {
            passedRules.add(new ValidationPass('bcn_missing_payee_address__c', 'Payee Address Present', 'BCN_LEVEL', 'Payee Address is populated'));
        }
        if (!failedRuleIds.contains('bcn_missing_total_claim_charge__c')) {
            passedRules.add(new ValidationPass('bcn_missing_total_claim_charge__c', 'Total Claim Charge Present', 'BCN_LEVEL', 'Total Claim Charge has value'));
        }

        // Charge-Level Rules (3 total)
        if (!failedRuleIds.contains('cumulative_charge_mismatch')) {
            passedRules.add(new ValidationPass('cumulative_charge_mismatch', 'Cumulative Charges Match', 'CHARGE_LEVEL', 'Line item charges equal Total Claim Charge'));
        }
        if (!failedRuleIds.contains('cumulative_payment_exceeds_charge')) {
            passedRules.add(new ValidationPass('cumulative_payment_exceeds_charge', 'Payments Within Limits', 'CHARGE_LEVEL', 'Total payments do not exceed Total Claim Charge'));
        }
        if (!failedRuleIds.contains('account_payment_exceeds_balance')) {
            passedRules.add(new ValidationPass('account_payment_exceeds_balance', 'Account Payments Valid', 'CHARGE_LEVEL', 'No account has payments exceeding their charges'));
        }

        // Line Item Rules (7 total) - check if ANY line items failed
        if (!failedRuleIds.contains('line_missing_service_dates')) {
            passedRules.add(new ValidationPass('line_missing_service_dates', 'All Service Dates Present', 'LINE_ITEM', 'All line items have service dates'));
        }
        if (!failedRuleIds.contains('line_missing_cpt_hcpcs_ndc')) {
            passedRules.add(new ValidationPass('line_missing_cpt_hcpcs_ndc', 'All Procedure Codes Present', 'LINE_ITEM', 'All line items have procedure codes'));
        }
        if (!failedRuleIds.contains('line_missing_charge')) {
            passedRules.add(new ValidationPass('line_missing_charge', 'All Charges Present', 'LINE_ITEM', 'All line items have charge amounts'));
        }
        if (!failedRuleIds.contains('line_negative_charge')) {
            passedRules.add(new ValidationPass('line_negative_charge', 'No Negative Charges', 'LINE_ITEM', 'All charges are positive values'));
        }
        if (!failedRuleIds.contains('line_payment_exceeds_charge')) {
            passedRules.add(new ValidationPass('line_payment_exceeds_charge', 'Payments Within Charge', 'LINE_ITEM', 'No line item payments exceed their charges'));
        }
        if (!failedRuleIds.contains('line_missing_account')) {
            passedRules.add(new ValidationPass('line_missing_account', 'All Accounts Present', 'LINE_ITEM', 'All line items have account assignments'));
        }
        if (!failedRuleIds.contains('line_invalid_service_date_range')) {
            passedRules.add(new ValidationPass('line_invalid_service_date_range', 'Valid Date Ranges', 'LINE_ITEM', 'All service end dates are after start dates'));
        }

        // Relational Integrity Rules (2 total)
        if (!failedRuleIds.contains('relational_orphaned_line_items')) {
            passedRules.add(new ValidationPass('relational_orphaned_line_items', 'No Orphaned Line Items', 'RELATIONAL', 'All line items are properly linked to BCN'));
        }
        if (!failedRuleIds.contains('relational_invalid_account_references')) {
            passedRules.add(new ValidationPass('relational_invalid_account_references', 'Valid Account References', 'RELATIONAL', 'All account references are valid'));
        }

        System.debug('TRINITY: Passed Rules Count: ' + passedRules.size());
        return passedRules;
    }

    /**
     * @description Validation result wrapper class
     */
    public class ValidationResult {
        @AuraEnabled public Id caseId;
        @AuraEnabled public String caseNumber;
        @AuraEnabled public Boolean canProceed;
        @AuraEnabled public List<ValidationFailure> bcnLevelFailures;
        @AuraEnabled public List<ValidationFailure> chargeLevelFailures;
        @AuraEnabled public List<ValidationFailure> lineItemFailures;
        @AuraEnabled public List<ValidationFailure> relationalIntegrityFailures;
        @AuraEnabled public List<ValidationFailure> warnings;
        @AuraEnabled public List<ValidationPass> passedRules; // TRINITY: Track passed rules for debugging

        public ValidationResult() {
            this.bcnLevelFailures = new List<ValidationFailure>();
            this.chargeLevelFailures = new List<ValidationFailure>();
            this.lineItemFailures = new List<ValidationFailure>();
            this.relationalIntegrityFailures = new List<ValidationFailure>();
            this.warnings = new List<ValidationFailure>();
            this.passedRules = new List<ValidationPass>();
        }
    }

    /**
     * @description Validation failure wrapper class
     */
    public class ValidationFailure {
        @AuraEnabled public String ruleId;
        @AuraEnabled public String ruleName;
        @AuraEnabled public String severity; // 'error' or 'warning'
        @AuraEnabled public String message;
        @AuraEnabled public String details;
        @AuraEnabled public String category; // 'BCN_LEVEL', 'CHARGE_LEVEL', 'LINE_ITEM', 'RELATIONAL'
        @AuraEnabled public String affectedLineItems; // Comma-separated line numbers

        public ValidationFailure(String ruleId, String ruleName, String severity,
                                String message, String details, String category) {
            this(ruleId, ruleName, severity, message, details, category, '');
        }

        public ValidationFailure(String ruleId, String ruleName, String severity,
                                String message, String details, String category, String affectedLineItems) {
            this.ruleId = ruleId;
            this.ruleName = ruleName;
            this.severity = severity;
            this.message = message;
            this.details = details;
            this.category = category;
            this.affectedLineItems = affectedLineItems;
        }
    }

    /**
     * @description Validation pass wrapper class - tracks rules that passed
     * TRINITY: For debugging and transparency in validation results
     */
    public class ValidationPass {
        @AuraEnabled public String ruleId;
        @AuraEnabled public String ruleName;
        @AuraEnabled public String category; // 'BCN_LEVEL', 'CHARGE_LEVEL', 'LINE_ITEM', 'RELATIONAL'
        @AuraEnabled public String message; // Brief description of what passed

        public ValidationPass(String ruleId, String ruleName, String category, String message) {
            this.ruleId = ruleId;
            this.ruleName = ruleName;
            this.category = category;
            this.message = message;
        }
    }
}