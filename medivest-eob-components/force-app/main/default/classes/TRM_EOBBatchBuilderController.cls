/**
 * @description Apex Controller for eobBatchBuilder LWC Component
 * 
 * TRINITY + SAGE: Bridge between LWC and EOB Provider Grouping Service
 * 
 * PURPOSE:
 * - Provide @AuraEnabled methods for LWC to call
 * - Transform Service data into LWC-friendly format
 * - Handle user-initiated EOB generation (manual process)
 * 
 * ARCHITECTURE:
 * LWC (eobBatchBuilder) → Controller (this) → Service (TRM_EOBProviderGroupingService)
 * 
 * @author Trinity (Alexia Abrego)
 * @date 2024-12-17
 */
public with sharing class TRM_EOBBatchBuilderController {
    
    /**
     * @description Wrapper class for Bill data (LWC-friendly format)
     */
    public class BillWrapper {
        @AuraEnabled public Id id { get; set; }
        @AuraEnabled public String name { get; set; }
        @AuraEnabled public String providerName { get; set; }
        @AuraEnabled public String providerAddressName { get; set; }
        @AuraEnabled public Decimal totalPaid { get; set; }
        @AuraEnabled public Date adjudicatedDate { get; set; }
        @AuraEnabled public String patientId { get; set; }
        @AuraEnabled public String memberAccountName { get; set; }
        @AuraEnabled public Boolean isPaid { get; set; }
        @AuraEnabled public Boolean isZeroDollar { get; set; }
    }
    
    /**
     * @description Wrapper class for Provider Group data (LWC-friendly format)
     */
    public class ProviderGroupWrapper {
        @AuraEnabled public String groupKey { get; set; }
        @AuraEnabled public String providerName { get; set; }
        @AuraEnabled public String providerAddressName { get; set; }
        @AuraEnabled public Integer billCount { get; set; }
        @AuraEnabled public Decimal totalAmount { get; set; }
        @AuraEnabled public Boolean isPaidBills { get; set; }
        @AuraEnabled public Boolean isZeroDollarBills { get; set; }
    }
    
    /**
     * @description Wrapper class for Summary data (LWC-friendly format)
     */
    public class SummaryWrapper {
        @AuraEnabled public Integer totalBills { get; set; }
        @AuraEnabled public Integer totalGroups { get; set; }
        @AuraEnabled public Decimal totalAmount { get; set; }
        @AuraEnabled public Integer paidGroups { get; set; }
        @AuraEnabled public Integer zeroDollarGroups { get; set; }
        @AuraEnabled public Integer uniqueProviderGroups { get; set; }
    }

    /**
     * @description Wrapper class for Search Result (bills + summary)
     */
    public class SearchResult {
        @AuraEnabled public List<BillWrapper> bills { get; set; }
        @AuraEnabled public SummaryWrapper summary { get; set; }
    }

    /**
     * @description Get eligible Bills for EOB generation
     * 
     * @param dateFrom Optional start date filter
     * @param dateTo Optional end date filter
     * @return List of BillWrapper
     */
    @AuraEnabled(cacheable=true)
    public static List<BillWrapper> getEligibleBills(Date dateFrom, Date dateTo) {
        try {
            // Call Service to get Bills
            List<Bill__c> bills = TRM_EOBProviderGroupingService.getEligibleBills(null, dateFrom, dateTo);
            
            // Transform to LWC-friendly format
            List<BillWrapper> wrappers = new List<BillWrapper>();
            for (Bill__c bill : bills) {
                BillWrapper wrapper = new BillWrapper();
                wrapper.id = bill.Id;
                wrapper.name = bill.Name;
                wrapper.providerName = bill.Provider__r?.Name;
                wrapper.providerAddressName = bill.TRM_Provider_Address__r?.Name;
                wrapper.totalPaid = bill.Total_Charge__c;
                wrapper.adjudicatedDate = bill.BillDateAdjudicated__c;
                wrapper.patientId = bill.Patient_Id__c;
                wrapper.memberAccountName = bill.Member_Account__r?.Name;
                wrapper.isPaid = (bill.Total_Charge__c != null && bill.Total_Charge__c > 0);
                wrapper.isZeroDollar = (bill.Total_Charge__c == null || bill.Total_Charge__c == 0);
                wrappers.add(wrapper);
            }
            
            return wrappers;
            
        } catch (Exception e) {
            throw new AuraHandledException('Error getting eligible Bills: ' + e.getMessage());
        }
    }
    
    /**
     * @description Get Provider Groups for selected Bills
     * 
     * @param billIds List of selected Bill IDs
     * @return List of ProviderGroupWrapper
     */
    @AuraEnabled(cacheable=true)
    public static List<ProviderGroupWrapper> getProviderGroups(List<Id> billIds) {
        try {
            // Call Service to get Bills
            List<Bill__c> bills = TRM_EOBProviderGroupingService.getEligibleBills(billIds, null, null);
            
            // Call Service to group Bills
            Map<String, TRM_EOBProviderGroupingService.ProviderGroup> groups = 
                TRM_EOBProviderGroupingService.groupBillsByProvider(bills);
            
            // Transform to LWC-friendly format
            List<ProviderGroupWrapper> wrappers = new List<ProviderGroupWrapper>();
            for (TRM_EOBProviderGroupingService.ProviderGroup provGroup : groups.values()) {
                ProviderGroupWrapper wrapper = new ProviderGroupWrapper();
                wrapper.groupKey = provGroup.groupKey;
                wrapper.providerName = provGroup.providerName;
                wrapper.providerAddressName = provGroup.providerAddressName;
                wrapper.billCount = provGroup.billCount;
                wrapper.totalAmount = provGroup.totalAmount;
                wrapper.isPaidBills = provGroup.isPaidBills;
                wrapper.isZeroDollarBills = provGroup.isZeroDollarBills;
                wrappers.add(wrapper);
            }
            
            return wrappers;
            
        } catch (Exception e) {
            throw new AuraHandledException('Error getting provider groups: ' + e.getMessage());
        }
    }
    
    /**
     * @description Get summary for selected Bills
     * 
     * @param billIds List of selected Bill IDs
     * @return SummaryWrapper
     */
    @AuraEnabled(cacheable=true)
    public static SummaryWrapper getSummary(List<Id> billIds) {
        try {
            // Call Service to get Bills
            List<Bill__c> bills = TRM_EOBProviderGroupingService.getEligibleBills(billIds, null, null);
            
            // Call Service to group Bills
            Map<String, TRM_EOBProviderGroupingService.ProviderGroup> groups = 
                TRM_EOBProviderGroupingService.groupBillsByProvider(bills);
            
            // Call Service to get summary
            TRM_EOBProviderGroupingService.GroupingSummary summary = 
                TRM_EOBProviderGroupingService.getSummary(groups);
            
            // Transform to LWC-friendly format
            SummaryWrapper wrapper = new SummaryWrapper();
            wrapper.totalBills = summary.totalBills;
            wrapper.totalGroups = summary.totalGroups;
            wrapper.totalAmount = summary.totalAmount;
            wrapper.paidGroups = summary.paidGroups;
            wrapper.zeroDollarGroups = summary.zeroDollarGroups;
            
            return wrapper;
            
        } catch (Exception e) {
            throw new AuraHandledException('Error getting summary: ' + e.getMessage());
        }
    }

    /**
     * @description Create EOB Batch record, create EOB Generation records, and update Bills
     *
     * PHASE 1 - USER-INITIATED PLANNING BATCH (Pre-Payment, Pre-Sync)
     *
     * This method implements the EOB Generation workflow as per the specification:
     * 1. Create TRM_EOB_Batch__c record (Status = 'New' initially, then 'Completed' when done)
     * 2. Group Bills by Provider + Provider Address
     * 3. Generate planned filenames for each group (format: EOB-{ProviderId}-{AddressId}-{YYYYMMDD}.pdf)
     * 4. Create TRM_EOB_Generation__c records (one per Bill)
     * 5. Update Bill__c records with planning data and mark for NetSuite sync (Paid only)
     *
     * WORKFLOW CONTINUES (handled by other processes):
     * PAID BILLS:
     * - NetSuite confirms receipt → Status = 'Waiting for Payment'
     * - Payment received from NetSuite → Status = 'Ready to Generate'
     * - All EOBs generated → Status = 'Completed'
     *
     * ZERO-DOLLAR BILLS:
     * - Immediately ready for generation (no NetSuite sync)
     * - All EOBs generated → Status = 'Completed'
     *
     * @param billIds List of selected Bill IDs
     * @param batchType 'Paid' or 'Zero-Dollar' (defaults to 'Paid' for backward compatibility)
     * @return Id of created TRM_EOB_Batch__c record
     */
    @AuraEnabled
    public static Id createEOBBatch(List<Id> billIds, String batchType) {
        // Default to 'Paid' for backward compatibility
        if (String.isBlank(batchType)) {
            batchType = 'Paid';
        }
        try {
            System.debug('TRINITY: ========== CREATE EOB BATCH ==========');
            System.debug('TRINITY: Received batchType parameter: ' + batchType);
            System.debug('TRINITY: Starting EOB Batch creation for ' + billIds.size() + ' Bills');

            // STEP 1: Query Bills with Provider and Address External IDs
            List<Bill__c> bills = [
                SELECT Id, Provider__c, TRM_Provider_Address__c,
                       TRM_provider_Id__c, TRM_Provider_Address_Id__c
                FROM Bill__c
                WHERE Id IN :billIds
            ];
            System.debug('TRINITY: Queried ' + bills.size() + ' Bills from database');

            // STEP 2: Calculate unique providers (using Set to avoid duplicates)
            // NOTE: Using pipe '|' separator as per specification (not dash '-')
            Set<String> uniqueProviderKeys = new Set<String>();
            for (Bill__c bill : bills) {
                String groupKey = bill.TRM_provider_Id__c + '|' + bill.TRM_Provider_Address_Id__c;
                uniqueProviderKeys.add(groupKey);
            }
            System.debug('TRINITY: Found ' + uniqueProviderKeys.size() + ' unique Provider+Address groups');

            // STEP 3: Create TRM_EOB_Batch__c record with calculated totals
            // Per documentation: Batch starts as 'New' and ends as 'Completed'
            // Batch status does NOT change after creation - tracking is done via EOB_Generation records
            TRM_EOB_Batch__c batch = new TRM_EOB_Batch__c(
                TRM_Batch_Type__c = batchType,
                TRM_Status__c = 'New',
                TRM_Batch_Date__c = DateTime.now(),
                TRM_Total_Bills__c = bills.size(),
                TRM_Total_Providers__c = uniqueProviderKeys.size()
            );
            insert batch;
            System.debug('TRINITY: Created ' + batchType + ' EOB Batch with ID: ' + batch.Id);
            System.debug('TRINITY: Batch Type: ' + batch.TRM_Batch_Type__c);
            System.debug('TRINITY: Batch Status: ' + batch.TRM_Status__c);

            // STEP 4: Get today's date in YYYYMMDD format for filenames
            String dateStr = DateTime.now().format('yyyyMMdd');
            System.debug('TRINITY: Using date string for filenames: ' + dateStr);

            // STEP 5: Create EOB_Generation__c records (one per Bill)
            List<TRM_EOB_Generation__c> eobGensToInsert = new List<TRM_EOB_Generation__c>();
            List<Bill__c> billsToUpdate = new List<Bill__c>();

            // Determine lifecycle values based on batch type
            String generationStatus;
            String eobSyncStatus;
            String paymentLifecycle;
            String netSuiteIntegrationStatus;

            if (batchType == 'Zero-Dollar') {
                generationStatus = 'Zero-Dollar Planned';
                eobSyncStatus = 'Zero-Dollar Planned';
                paymentLifecycle = 'Zero-Dollar Batch Planned';
                netSuiteIntegrationStatus = null; // Zero-Dollar bills don't sync to NetSuite
            } else {
                generationStatus = 'Planned - Waiting for NetSuite';
                eobSyncStatus = 'Planned-Waiting for NetSuite';
                paymentLifecycle = 'Sent to NetSuite';
                netSuiteIntegrationStatus = 'Pending'; // Paid bills start as Pending
            }

            for (Bill__c bill : bills) {
                // Generate group key using pipe '|' separator (as per specification)
                String groupKey = bill.TRM_provider_Id__c + '|' + bill.TRM_Provider_Address_Id__c;

                // Generate planned filename: EOB_{Provider_Id}_{Provider_Address_Id}_{YYYYMMDD}.pdf
                String filename = 'EOB_' + bill.TRM_provider_Id__c + '_' +
                                 bill.TRM_Provider_Address_Id__c + '_' + dateStr + '.pdf';

                // Create EOB_Generation__c record for this Bill
                TRM_EOB_Generation__c eobGen = new TRM_EOB_Generation__c(
                    TRM_Bill__c = bill.Id,
                    TRM_Provider__c = bill.Provider__c,
                    TRM_Provider_Address__c = bill.TRM_Provider_Address__c,
                    TRM_Provider_Id__c = bill.TRM_provider_Id__c,
                    TRM_Provider_Address_Id__c = bill.TRM_Provider_Address_Id__c,
                    // NOTE: TRM_Provider_Group_Key__c is a FORMULA field - auto-calculated
                    TRM_EOB_Group_Planned_File_Name__c = filename,
                    TRM_Generation_Status__c = generationStatus,
                    TRM_EOB_Batch__c = batch.Id
                );
                eobGensToInsert.add(eobGen);

                // Prepare Bill update with planning data
                Bill__c billToUpdate = new Bill__c(
                    Id = bill.Id,
                    TRM_Provider_Group_Key__c = groupKey,
                    TRM_EOB_Group_Planned_File_Name__c = filename,
                    TRM_EOB_Sync_Status__c = eobSyncStatus,
                    Bill_Netsuite_Integration_Status__c = netSuiteIntegrationStatus,
                    TRM_Payment_Lifecycle__c = paymentLifecycle,
                    TRM_EOB_Batch_Planned__c = true
                );
                billsToUpdate.add(billToUpdate);
            }

            // STEP 6: Insert EOB_Generation__c records
            if (!eobGensToInsert.isEmpty()) {
                insert eobGensToInsert;
                System.debug('TRINITY: Created ' + eobGensToInsert.size() + ' EOB Generation records');
            }

            // STEP 7: Update Bills with planning data
            if (!billsToUpdate.isEmpty()) {
                update billsToUpdate;
                System.debug('TRINITY: Updated ' + billsToUpdate.size() + ' Bills with planning data');
            }

            // STEP 7.5: Update Bill Line Items with NetSuite Integration Status
            // Only for PAID batches - set BillLine_NetSuite_Integration_Status__c to 'Pending'
            // TODO: Uncomment when field BillLine_NetSuite_Integration_Status__c is created
            /*
            if (batchType != 'Zero-Dollar' && !billIds.isEmpty()) {
                List<Bill_Line_Item__c> lineItemsToUpdate = [
                    SELECT Id
                    FROM Bill_Line_Item__c
                    WHERE Bill__c IN :billIds
                ];

                if (!lineItemsToUpdate.isEmpty()) {
                    for (Bill_Line_Item__c lineItem : lineItemsToUpdate) {
                        lineItem.BillLine_NetSuite_Integration_Status__c = 'Pending';
                    }
                    update lineItemsToUpdate;
                    System.debug('TRINITY: Updated ' + lineItemsToUpdate.size() + ' Bill Line Items with NetSuite Integration Status = Pending');
                }
            }
            */

            // STEP 8: Update Batch status to 'Completed'
            // Per documentation Phase 1 Section 3.2.5: Finalize Batch with Status = 'Completed'
            batch.TRM_Status__c = 'Completed';
            update batch;
            System.debug('TRINITY: Batch status updated to Completed');

            System.debug('TRINITY: EOB Batch creation completed successfully. Batch ID: ' + batch.Id);
            System.debug('TRINITY: Batch Status: ' + batch.TRM_Status__c);
            return batch.Id;

        } catch (Exception e) {
            System.debug('TRINITY ERROR: Exception in createEOBBatch - ' + e.getMessage());
            System.debug('TRINITY ERROR: Stack trace - ' + e.getStackTraceString());
            throw new AuraHandledException('Error creating EOB Batch: ' + e.getMessage());
        }
    }

    /**
     * @description Get bills for On-Demand EOB generation (no Payment_Lifecycle filter)
     *
     * This method searches for bills without filtering by Payment_Lifecycle__c,
     * allowing users to generate EOBs for any bill (re-send, preview, audit, etc.)
     *
     * @param fromDate Optional start date filter (BillDateAdjudicated__c)
     * @param toDate Optional end date filter (BillDateAdjudicated__c)
     * @return SearchResult containing bills and summary
     */
    @AuraEnabled
    public static SearchResult getOnDemandBills(String fromDate, String toDate) {
        try {
            System.debug('TRINITY: getOnDemandBills called');
            System.debug('TRINITY: fromDate: ' + fromDate);
            System.debug('TRINITY: toDate: ' + toDate);

            // Build dynamic query
            String query = 'SELECT Id, Name, Provider__c, Provider__r.Name, ' +
                          'TRM_Provider_Address__c, TRM_Provider_Address__r.Name, ' +
                          'TRM_provider_Id__c, TRM_Provider_Address_Id__c, ' +
                          'TotalPaidStored__c, Total_Charge__c, BillDateAdjudicated__c, ' +
                          'DateOfServiceFrom__c, DateOfServiceTo__c, ' +
                          'TRM_Payment_Lifecycle__c, ' +
                          'Patient_Id__c, Member_Account__c, Member_Account__r.Name ' +
                          'FROM Bill__c ' +
                          'WHERE Provider__c != null ' +
                          'AND TRM_Provider_Address__c != null ';

            // Add date filters if provided
            if (String.isNotBlank(fromDate)) {
                Date parsedFromDate = Date.valueOf(fromDate);
                query += 'AND BillDateAdjudicated__c >= :parsedFromDate ';
            }

            if (String.isNotBlank(toDate)) {
                Date parsedToDate = Date.valueOf(toDate);
                query += 'AND BillDateAdjudicated__c <= :parsedToDate ';
            }

            query += 'ORDER BY BillDateAdjudicated__c DESC LIMIT 1000';

            System.debug('TRINITY: Query: ' + query);

            // Execute query
            List<Bill__c> bills = Database.query(query);
            System.debug('TRINITY: Found ' + bills.size() + ' bills');

            // Transform to wrappers
            List<BillWrapper> billWrappers = new List<BillWrapper>();
            Set<String> uniqueProviderKeys = new Set<String>();

            for (Bill__c bill : bills) {
                BillWrapper wrapper = new BillWrapper();
                wrapper.id = bill.Id;
                wrapper.name = bill.Name;
                wrapper.providerName = bill.Provider__r?.Name;
                wrapper.providerAddressName = bill.TRM_Provider_Address__r?.Name;
                wrapper.totalPaid = bill.TotalPaidStored__c;
                wrapper.adjudicatedDate = bill.BillDateAdjudicated__c;
                wrapper.patientId = bill.Patient_Id__c;
                wrapper.memberAccountName = bill.Member_Account__r?.Name;
                wrapper.isPaid = (bill.TotalPaidStored__c != null && bill.TotalPaidStored__c > 0);
                wrapper.isZeroDollar = (bill.TotalPaidStored__c == null || bill.TotalPaidStored__c == 0);

                billWrappers.add(wrapper);

                // Track unique provider groups
                String groupKey = bill.TRM_provider_Id__c + '|' + bill.TRM_Provider_Address_Id__c;
                uniqueProviderKeys.add(groupKey);
            }

            // Build summary
            SummaryWrapper summary = new SummaryWrapper();
            summary.totalBills = bills.size();
            summary.uniqueProviderGroups = uniqueProviderKeys.size();
            summary.totalAmount = 0;

            for (Bill__c bill : bills) {
                if (bill.TotalPaidStored__c != null) {
                    summary.totalAmount += bill.TotalPaidStored__c;
                }
            }

            // Build result
            SearchResult result = new SearchResult();
            result.bills = billWrappers;
            result.summary = summary;

            System.debug('TRINITY: Returning ' + billWrappers.size() + ' bills, ' + uniqueProviderKeys.size() + ' groups');

            return result;

        } catch (Exception e) {
            System.debug('TRINITY ERROR: Exception in getOnDemandBills - ' + e.getMessage());
            System.debug('TRINITY ERROR: Stack trace - ' + e.getStackTraceString());
            throw new AuraHandledException('Error searching On-Demand bills: ' + e.getMessage());
        }
    }
}

