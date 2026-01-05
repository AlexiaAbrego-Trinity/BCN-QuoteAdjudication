// MVADM-188: Test line number assignment in duplication
// Adapted for current method signature: createDuplicateBillLineItems(List<Id>, Integer)

// Get a test Bill (BCN Case 00375197 or any test Bill)
List<Bill__c> testBills = [
    SELECT Id, Name
    FROM Bill__c
    WHERE Name LIKE '%00375197%' OR Name LIKE '%Test%'
    LIMIT 1
];

if (testBills.isEmpty()) {
    System.debug('ERROR: No test Bill found. Trying to get ANY Bill...');
    testBills = [SELECT Id, Name FROM Bill__c LIMIT 1];
    if (testBills.isEmpty()) {
        System.debug('FATAL: No Bills exist in org');
        return;
    }
}

Bill__c testBill = testBills[0];
System.debug('Using Bill: ' + testBill.Name + ' (ID: ' + testBill.Id + ')');

// Get existing line items
List<Bill_Line_Item__c> existingItems = [
    SELECT Id, Bill__c, Bill_Line_Item_Number__c,
           Service_Start_Date__c, Service_End_Date__c, CPT_HCPCS_NDC__c
    FROM Bill_Line_Item__c
    WHERE Bill__c = :testBill.Id
    ORDER BY Bill_Line_Item_Number__c ASC NULLS LAST
    LIMIT 5
];

if (existingItems.isEmpty()) {
    System.debug('ERROR: No existing line items found for this Bill');
    return;
}

System.debug('Existing line items: ' + existingItems.size());
for (Bill_Line_Item__c item : existingItems) {
    System.debug('  Line #' + item.Bill_Line_Item_Number__c +
                 ' - CPT: ' + item.CPT_HCPCS_NDC__c);
}

// Get max line number before duplication
Decimal maxBefore = 0;
for (Bill_Line_Item__c item : existingItems) {
    if (item.Bill_Line_Item_Number__c != null &&
        item.Bill_Line_Item_Number__c > maxBefore) {
        maxBefore = item.Bill_Line_Item_Number__c;
    }
}
System.debug('Max line number before duplication: ' + maxBefore);

// ADAPTED: Use current method signature (List<Id>, Integer)
List<Id> originalItemIds = new List<Id>{ existingItems[0].Id };
Integer duplicateCount = 3;

System.debug('--- CALLING createDuplicateBillLineItems ---');
System.debug('Original Item ID: ' + existingItems[0].Id);
System.debug('Duplicate Count: ' + duplicateCount);

// Call duplication method with current signature
List<Bill_Line_Item__c> duplicates =
    TRM_MedicalBillingService.createDuplicateBillLineItems(originalItemIds, duplicateCount);

System.debug('--- DUPLICATION COMPLETE ---');
System.debug('Duplicates created: ' + duplicates.size());

// Verify line numbers
Boolean allHaveLineNumbers = true;
Boolean allSequential = true;
Decimal expectedLineNumber = maxBefore + 1;

for (Bill_Line_Item__c dup : duplicates) {
    System.debug('Duplicate Line #' + dup.Bill_Line_Item_Number__c +
                 ' - CPT: ' + dup.CPT_HCPCS_NDC__c);

    // Check for null
    if (dup.Bill_Line_Item_Number__c == null) {
        System.debug('❌ FAIL: Line number is null');
        allHaveLineNumbers = false;
    }

    // Check for sequential
    if (dup.Bill_Line_Item_Number__c != expectedLineNumber) {
        System.debug('❌ FAIL: Expected line #' + expectedLineNumber +
                     ', got #' + dup.Bill_Line_Item_Number__c);
        allSequential = false;
    }

    expectedLineNumber++;
}

// Final verdict
if (allHaveLineNumbers && allSequential) {
    System.debug('✅ TEST PASSED: All duplicates have sequential line numbers');
} else {
    System.debug('❌ TEST FAILED: Line number assignment has issues');
}

// Query database to verify persistence
List<Bill_Line_Item__c> allItems = [
    SELECT Id, Bill_Line_Item_Number__c
    FROM Bill_Line_Item__c
    WHERE Bill__c = :testBill.Id
    ORDER BY Bill_Line_Item_Number__c ASC NULLS LAST
];

System.debug('Total line items after duplication: ' + allItems.size());
System.debug('Expected: ' + (existingItems.size() + duplicateCount));

if (allItems.size() == existingItems.size() + duplicateCount) {
    System.debug('✅ PERSISTENCE VERIFIED: Correct number of items in database');
} else {
    System.debug('❌ PERSISTENCE FAILED: Item count mismatch');
}

