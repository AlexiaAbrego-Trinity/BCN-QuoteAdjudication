import { LightningElement, track, wire } from 'lwc';
import { CloseActionScreenEvent } from 'lightning/actions';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';
import { NavigationMixin } from 'lightning/navigation';
import getEligibleBills from '@salesforce/apex/TRM_EOBBatchBuilderController.getEligibleBills';
import getSummary from '@salesforce/apex/TRM_EOBBatchBuilderController.getSummary';
import createEOBBatch from '@salesforce/apex/TRM_EOBBatchBuilderController.createEOBBatch';
import getOnDemandBills from '@salesforce/apex/TRM_EOBBatchBuilderController.getOnDemandBills';
import getRecentBatches from '@salesforce/apex/TRM_EOBBatchManagerController.getRecentBatches';
import getAllReadyGenerations from '@salesforce/apex/TRM_EOBBatchManagerController.getAllReadyGenerations';
import generateEOBsForGroups from '@salesforce/apex/TRM_EOBGenerationApi.generateEOBsForGroups';

export default class EobBatchBuilderQuickAction extends NavigationMixin(LightningElement) {
  _activeTab = 'create'; // Default tab

  get activeTab() {
    return this._activeTab;
  }

  set activeTab(value) {
    console.log('🚨🚨🚨 activeTab SETTER CALLED 🚨🚨🚨');
    console.log('Old value:', this._activeTab);
    console.log('New value:', value);

    const oldValue = this._activeTab;
    this._activeTab = value;

    // If switching TO the generate tab, load data
    if (value === 'generate' && oldValue !== 'generate') {
      console.log('✅ Switched TO generate tab - loading data');
      this.loadReadyGenerations();
    }
  }

  // Tab 1: Create Batch
  mode = 'PAID';
  fromDate = null;
  toDate = null;
  isLoading = false;

  @track allBills = [];
  @track selectedBillIds = [];

  billsFound = 0;
  billsSelected = 0;
  groupsCount = 0;
  totalAmount = 0;

  @track rows = [];

  // Tab 2: Batch History
  @track batches = [];
  batchesWiredResult;

  // Tab 3: Generate EOBs
  @track generateBatchType = 'PAID'; // 'PAID' or 'ZERO'
  @track eobGenerations = [];
  _providerGroups = [];
  @track selectedGroupIds = new Set();
  @track searchTerm = '';
  isGenerating = false;
  hasRendered = false; // Track if component has rendered

  // Tab 4: On-Demand EOBs
  @track onDemandFromDate = null;
  @track onDemandToDate = null;
  @track onDemandAllBills = [];
  @track onDemandSelectedBillIds = [];
  onDemandBillsFound = 0;
  onDemandBillsSelected = 0;
  onDemandGroupsCount = 0;
  @track onDemandRows = [];

  get providerGroups() {
    return this._providerGroups;
  }

  set providerGroups(value) {
    console.log('🔧 providerGroups setter called with:', value);
    console.log('🔧 Value length:', value ? value.length : 0);
    this._providerGroups = value;
  }

  // Lifecycle hook - load data when component first renders
  async renderedCallback() {
    if (!this.hasRendered) {
      this.hasRendered = true;
      console.log('═══════════════════════════════════════════════════');
      console.log('🎬 COMPONENT RENDERED FOR FIRST TIME');
      console.log('🎬 Active tab:', this.activeTab);
      console.log('🎬 generateBatchType:', this.generateBatchType);
      console.log('🎬 providerGroups length:', this.providerGroups.length);
      console.log('🎬 isLoading:', this.isLoading);
      console.log('═══════════════════════════════════════════════════');

      // If we're on the Generate EOBs tab, load the data
      if (this.activeTab === 'generate') {
        console.log('🎬 Loading ready generations on first render');
        await this.loadReadyGenerations();
      }
    }
  }

  // Datatable columns for provider groups
  groupColumns = [
    {
      label: '',
      fieldName: 'selected',
      type: 'boolean',
      cellAttributes: { iconName: { fieldName: 'selectedIcon' } },
      initialWidth: 50
    },
    {
      label: 'Provider Name',
      fieldName: 'providerName',
      type: 'text',
      sortable: true
    },
    {
      label: 'Provider Address',
      fieldName: 'addressName',
      type: 'text',
      sortable: true
    },
    {
      label: 'Bills',
      fieldName: 'billCount',
      type: 'number',
      initialWidth: 100
    },
    {
      label: 'Planned Filename',
      fieldName: 'plannedFilename',
      type: 'text',
      wrapText: true
    },
    {
      type: 'action',
      typeAttributes: {
        rowActions: [
          { label: 'Toggle Selection', name: 'toggle_selection' }
        ]
      },
      initialWidth: 80
    }
  ];

  columns = [
    { label: 'Bill', fieldName: 'name', type: 'text' },
    { label: 'Provider', fieldName: 'providerName', type: 'text' },
    { label: 'Address', fieldName: 'providerAddressName', type: 'text' },
    { label: 'Total Charge', fieldName: 'totalPaid', type: 'currency' }
  ];

  onDemandColumns = [
    { label: 'Bill', fieldName: 'name', type: 'text' },
    { label: 'Provider', fieldName: 'providerName', type: 'text' },
    { label: 'Address', fieldName: 'providerAddressName', type: 'text' },
    { label: 'Payment Status', fieldName: 'paymentLifecycle', type: 'text' },
    { label: 'Total Charge', fieldName: 'totalPaid', type: 'currency' }
  ];

  batchColumns = [
    { label: 'Batch Name', fieldName: 'batchUrl', type: 'url', typeAttributes: { label: { fieldName: 'name' }, target: '_blank' } },
    { label: 'Date', fieldName: 'batchDate', type: 'date-local', typeAttributes: { year: 'numeric', month: '2-digit', day: '2-digit', hour: '2-digit', minute: '2-digit' } },
    { label: 'Type', fieldName: 'batchType', type: 'text' },
    { label: 'Status', fieldName: 'status', type: 'text' },
    { label: 'Bills', fieldName: 'totalBills', type: 'number' },
    { label: 'Providers', fieldName: 'totalProviders', type: 'number' },
    {
      type: 'action',
      typeAttributes: {
        rowActions: [
          { label: 'View', name: 'view' },
          { label: 'Refresh', name: 'refresh' }
        ]
      }
    }
  ];

  get modeOptions() {
    return [
      { label: 'Paid (Non-Zero) → NetSuite', value: 'PAID' },
      { label: 'Zero-Dollar → Salesforce Only', value: 'ZERO' }
    ];
  }

  get isPaidMode() {
    return this.mode === 'PAID';
  }

  get isZeroMode() {
    return this.mode === 'ZERO';
  }

  get isCreateTab() {
    return this.activeTab === 'create';
  }

  get isHistoryTab() {
    return this.activeTab === 'history';
  }

  get isGenerateTab() {
    return this.activeTab === 'generate';
  }

  // Tab 3: Generate EOBs - Batch Type
  get generateBatchTypeOptions() {
    return [
      { label: 'Paid (NetSuite)', value: 'PAID' },
      { label: 'Zero-Dollar (Salesforce Only)', value: 'ZERO' }
    ];
  }

  get isGeneratePaidMode() {
    return this.generateBatchType === 'PAID';
  }

  get isGenerateZeroMode() {
    return this.generateBatchType === 'ZERO';
  }

  // Tab 3: Generate EOBs getters
  get groupCount() {
    return this.providerGroups.length;
  }

  get hasProviderGroups() {
    const result = this.providerGroups && this.providerGroups.length > 0;
    console.log('🔍 hasProviderGroups getter called:', result, 'providerGroups:', this.providerGroups);
    return result;
  }

  get filteredProviderGroups() {
    if (!this.searchTerm) {
      return this.selectableGroups;
    }

    const searchLower = this.searchTerm.toLowerCase();
    return this.selectableGroups.filter(group =>
      group.providerName.toLowerCase().includes(searchLower) ||
      group.addressName.toLowerCase().includes(searchLower) ||
      group.plannedFilename.toLowerCase().includes(searchLower)
    );
  }

  get totalBillsInGroups() {
    return this.providerGroups.reduce((sum, group) => sum + group.billCount, 0);
  }

  // Generation mode options
  get generationModeOptions() {
    return [
      { label: 'By Batch (Generate all groups in batch)', value: 'batch' },
      { label: 'By Provider+Address (Generate specific group)', value: 'group' },
      { label: 'By Bill (Generate for individual Bill)', value: 'bill' }
    ];
  }

  // Count of selected groups
  get selectedGroupCount() {
    return this.selectedGroupIds.size;
  }

  // Provider groups with selection state
  get selectableGroups() {
    return this.providerGroups.map(group => {
      const isSelected = this.selectedGroupIds.has(group.key);
      return {
        ...group,
        selected: isSelected,
        selectedIcon: isSelected ? 'utility:check' : ''
      };
    });
  }

  get hasSelectedGroups() {
    return this.selectedGroupIds.size > 0;
  }

  get generateButtonLabel() {
    return `Generate ${this.selectedGroupCount} EOB PDFs`;
  }

  // Tab 4: On-Demand EOBs getters
  get isOnDemandButtonDisabled() {
    return this.onDemandSelectedBillIds.length === 0 || this.isLoading;
  }

  // Wire to get recent batches
  @wire(getRecentBatches)
  wiredBatches(result) {
    this.batchesWiredResult = result;
    if (result.data) {
      this.batches = result.data.map(batch => ({
        id: batch.Id,
        name: batch.Name,
        batchUrl: `/${batch.Id}`,
        batchDate: batch.TRM_Batch_Date__c,
        status: batch.TRM_Status__c,
        totalBills: batch.TRM_Total_Bills__c,
        totalProviders: batch.TRM_Total_Providers__c,
        batchType: batch.TRM_Batch_Type__c
      }));
    } else if (result.error) {
      this.showToast('Error', 'Error loading batches', 'error');
      console.error('Error loading batches:', result.error);
    }
  }

  async handleTabChange(event) {
    this.activeTab = event.target.value;
  }

  // Handler for when Generate EOBs tab becomes active
  async handleGenerateTabActive() {
    console.log('🚨🚨� GENERATE TAB ACTIVATED 🚨🚨🚨');
    await this.loadReadyGenerations();
  }

  handleGoToCreate() {
    this.activeTab = 'create';
  }

  handleModeChange(event) {
    this.mode = event.detail.value;
    this.handleClear();
  }

  async handleGenerateBatchTypeChange(event) {
    this.generateBatchType = event.detail.value;
    // Reset selections when changing batch type
    this.eobGenerations = [];
    this.providerGroups = [];
    this.selectedGroupIds = new Set();

    // Load EOB_Generation records for the selected mode
    await this.loadReadyGenerations();
  }

  async loadReadyGenerations() {
    console.log('═══════════════════════════════════════════════════');
    console.log('📥 LOAD READY GENERATIONS CALLED');
    console.log('═══════════════════════════════════════════════════');

    this.isLoading = true;
    console.log('⏳ isLoading set to TRUE');

    try {
      // Determine status based on mode
      const status = this.isGeneratePaidMode ? 'Ready to Generate' : 'Zero-Dollar Planned';
      console.log('🔍 Current mode:', this.generateBatchType);
      console.log('🔍 isGeneratePaidMode:', this.isGeneratePaidMode);
      console.log('🔍 Status to query:', status);

      // Fetch ALL EOB_Generation records with the correct status
      console.log('📡 Calling Apex: getAllReadyGenerations with status:', status);
      const generations = await getAllReadyGenerations({ status: status });
      console.log('� Apex returned:', generations);
      console.log('� Number of generations:', generations ? generations.length : 0);

      this.eobGenerations = [...generations]; // Force new array
      console.log('✅ eobGenerations assigned');

      // Group by Provider + Address
      console.log('🔄 Calling groupGenerationsByProvider...');
      this.groupGenerationsByProvider(generations);
      console.log('✅ Grouping complete');
      console.log('� Provider groups:', this.providerGroups);
      console.log('� Number of provider groups:', this.providerGroups.length);
      console.log('📊 hasProviderGroups:', this.hasProviderGroups);

      // Select all groups by default - force new Set
      const groupKeys = this.providerGroups.map(g => g.key);
      this.selectedGroupIds = new Set(groupKeys);
      console.log('✅ Selected group IDs:', this.selectedGroupIds);

      console.log('═══════════════════════════════════════════════════');
      console.log(`✅ LOAD COMPLETE: ${generations.length} EOB Generations in ${this.groupCount} groups`);
      console.log('═══════════════════════════════════════════════════');

    } catch (error) {
      console.log('═══════════════════════════════════════════════════');
      console.error('❌ ERROR IN LOAD READY GENERATIONS');
      console.error('❌ Error:', error);
      console.error('❌ Error body:', error.body);
      console.error('❌ Error message:', error.body?.message);
      console.log('═══════════════════════════════════════════════════');
      this.showToast('Error', error.body?.message || 'Error loading EOB Generations', 'error');
    } finally {
      this.isLoading = false;
      console.log('✅ isLoading set to FALSE');
    }
  }

  handleFromDateChange(event) {
    this.fromDate = event.detail.value;
  }

  handleToDateChange(event) {
    this.toDate = event.detail.value;
  }

  async handleSearch() {
    this.isLoading = true;
    
    try {
      const bills = await getEligibleBills({
        dateFrom: this.fromDate,
        dateTo: this.toDate
      });
      
      this.allBills = bills.filter(bill => {
        if (this.mode === 'PAID') {
          return bill.isPaid;
        } else {
          return bill.isZeroDollar;
        }
      });
      
      this.rows = this.allBills.map(bill => ({
        id: bill.id,
        name: bill.name,
        providerName: bill.providerName,
        providerAddressName: bill.providerAddressName,
        totalPaid: bill.totalPaid
      }));

      this.billsFound = this.allBills.length;
      this.billsSelected = 0;
      this.selectedBillIds = [];
      this.totalAmount = 0;

      // Calculate unique Provider+Address groups
      const uniqueGroups = new Set();
      this.allBills.forEach(bill => {
        const groupKey = `${bill.providerName}|${bill.providerAddressName}`;
        uniqueGroups.add(groupKey);
      });
      this.groupsCount = uniqueGroups.size;

      this.showToast('Success', `Found ${this.billsFound} Bills in ${this.groupsCount} Provider+Address groups`, 'success');
      
    } catch (error) {
      this.showToast('Error', error.body?.message || 'Error searching Bills', 'error');
      console.error('Error in handleSearch:', error);
    } finally {
      this.isLoading = false;
    }
  }

  handleRowSelection(event) {
    this.selectedBillIds = event.detail.selectedRows.map(row => row.id);
    this.billsSelected = this.selectedBillIds.length;
    
    if (this.selectedBillIds.length > 0) {
      this.updateSummary();
    } else {
      this.groupsCount = 0;
      this.totalAmount = 0;
    }
  }

  async updateSummary() {
    try {
      const summary = await getSummary({ billIds: this.selectedBillIds });
      this.groupsCount = summary.totalGroups;
      this.totalAmount = summary.totalAmount;
    } catch (error) {
      console.error('Error updating summary:', error);
    }
  }

  handleClear() {
    this.fromDate = null;
    this.toDate = null;
    this.billsFound = 0;
    this.billsSelected = 0;
    this.groupsCount = 0;
    this.totalAmount = 0;
    this.rows = [];
    this.allBills = [];
    this.selectedBillIds = [];
  }

  async handleCreateBatch() {
    if (this.selectedBillIds.length === 0) {
      this.showToast('Warning', 'Please select at least one Bill', 'warning');
      return;
    }

    this.isLoading = true;

    try {
      // Determine batch type based on mode
      const batchType = this.mode === 'ZERO' ? 'Zero-Dollar' : 'Paid';

      await createEOBBatch({
        billIds: this.selectedBillIds,
        batchType: batchType
      });

      this.showToast('Success', `${batchType} EOB Batch created successfully!`, 'success');

      // Clear the form
      this.handleClear();

      // Refresh batches list
      await refreshApex(this.batchesWiredResult);

      // Switch to History tab to see the new batch
      this.activeTab = 'history';

    } catch (error) {
      this.showToast('Error', error.body?.message || 'Error creating EOB Batch', 'error');
      console.error('Error in handleCreateBatch:', error);
    } finally {
      this.isLoading = false;
    }
  }

  // Tab 2: Batch History methods
  handleBatchAction(event) {
    const actionName = event.detail.action.name;
    const row = event.detail.row;

    switch (actionName) {
      case 'view':
        this.navigateToBatch(row.id);
        break;
      case 'refresh':
        this.refreshBatches();
        break;
      default:
        break;
    }
  }

  navigateToBatch(batchId) {
    this[NavigationMixin.Navigate]({
      type: 'standard__recordPage',
      attributes: {
        recordId: batchId,
        objectApiName: 'TRM_EOB_Batch__c',
        actionName: 'view'
      }
    });
  }

  async refreshBatches() {
    this.isLoading = true;
    try {
      await refreshApex(this.batchesWiredResult);
      this.showToast('Success', 'Batches refreshed', 'success');
    } catch (error) {
      this.showToast('Error', 'Error refreshing batches', 'error');
      console.error('Error refreshing batches:', error);
    } finally {
      this.isLoading = false;
    }
  }

  // Tab 3: Generate EOBs methods

  groupGenerationsByProvider(generations) {
    // Group by TRM_Provider_Group_Key__c
    const groupMap = new Map();

    generations.forEach(gen => {
      const key = gen.TRM_Provider_Group_Key__c;

      if (!groupMap.has(key)) {
        groupMap.set(key, {
          key: key,
          providerName: gen.TRM_Provider__r?.Name || 'Unknown Provider',
          addressName: gen.TRM_Provider_Address__r?.Name || 'Unknown Address',
          plannedFilename: gen.TRM_EOB_Group_Planned_File_Name__c,
          bills: [],
          billCount: 0,
          totalAmount: 0
        });
      }

      const group = groupMap.get(key);
      group.bills.push(gen);
      group.billCount++;
      group.totalAmount += (gen.TRM_Payment_Amount__c || 0);
    });

    // Force reactivity by creating a new array
    this.providerGroups = [...Array.from(groupMap.values())];
    console.log('🔍 providerGroups assigned:', this.providerGroups);
  }

  handleSearchChange(event) {
    this.searchTerm = event.target.value;
  }

  handleSelectAll() {
    this.selectedGroupIds = new Set(this.providerGroups.map(g => g.key));
  }

  handleDeselectAll() {
    this.selectedGroupIds = new Set();
  }

  handleRowAction(event) {
    const action = event.detail.action;
    const row = event.detail.row;

    if (action.name === 'toggle_selection') {
      this.toggleGroupSelection(row.key);
    }
  }

  handleGroupSelection(event) {
    const groupKey = event.currentTarget.dataset.groupKey;
    this.toggleGroupSelection(groupKey);
  }

  toggleGroupSelection(groupKey) {
    if (this.selectedGroupIds.has(groupKey)) {
      this.selectedGroupIds.delete(groupKey);
    } else {
      this.selectedGroupIds.add(groupKey);
    }

    // Force re-render
    this.selectedGroupIds = new Set(this.selectedGroupIds);
  }

  async handleGenerate() {
    // Validation
    if (this.selectedGroupIds.size === 0) {
      this.showToast('Warning', 'Please select at least one provider group to generate', 'warning');
      return;
    }

    this.isGenerating = true;

    try {
      // Generate PDFs for selected groups
      const groupKeys = Array.from(this.selectedGroupIds);

      console.log('TRINITY: Generating PDFs for', groupKeys.length, 'groups:', groupKeys);

      const result = await generateEOBsForGroups({
        batchId: null, // Not filtering by batch anymore
        groupKeys: groupKeys
      });

      console.log('TRINITY: Generation result:', result);

      // Show detailed results
      if (result.failureCount > 0) {
        this.showToast(
          'Partial Success',
          `Generated ${result.successCount} of ${result.totalGroups} groups. ${result.failureCount} failed.`,
          'warning'
        );
      } else {
        this.showToast('Success', `Generated ${result.successCount} EOB PDFs successfully!`, 'success');
      }

      // Refresh the list
      await this.loadReadyGenerations();

    } catch (error) {
      this.showToast('Error', error.body?.message || 'Error generating EOBs', 'error');
      console.error('Error in handleGenerate:', error);
    } finally {
      this.isGenerating = false;
    }
  }

  // ========== TAB 4: ON-DEMAND EOBs HANDLERS ==========

  handleOnDemandFromDateChange(event) {
    this.onDemandFromDate = event.target.value;
    console.log('TRINITY: On-Demand From Date changed to:', this.onDemandFromDate);
  }

  handleOnDemandToDateChange(event) {
    this.onDemandToDate = event.target.value;
    console.log('TRINITY: On-Demand To Date changed to:', this.onDemandToDate);
  }

  async handleOnDemandSearch() {
    console.log('TRINITY: On-Demand Search clicked');
    console.log('TRINITY: From Date:', this.onDemandFromDate);
    console.log('TRINITY: To Date:', this.onDemandToDate);

    this.isLoading = true;

    try {
      // Call new getOnDemandBills method (no Payment_Lifecycle filter)
      const result = await getOnDemandBills({
        fromDate: this.onDemandFromDate,
        toDate: this.onDemandToDate
      });

      console.log('TRINITY: On-Demand Search result:', result);

      this.onDemandAllBills = result.bills || [];
      this.onDemandBillsFound = this.onDemandAllBills.length;
      this.onDemandGroupsCount = result.summary?.uniqueProviderGroups || 0;

      // Transform bills to rows
      this.onDemandRows = this.onDemandAllBills.map(bill => ({
        id: bill.Id,
        name: bill.Name,
        providerName: bill.Provider__r?.Name || '',
        providerAddressName: bill.TRM_Provider_Address__r?.Name || '',
        paymentLifecycle: bill.TRM_Payment_Lifecycle__c || '',
        totalPaid: bill.TotalPaidStored__c || 0
      }));

      console.log('TRINITY: On-Demand Rows:', this.onDemandRows);

      if (this.onDemandBillsFound === 0) {
        this.showToast('Info', 'No bills found matching the criteria', 'info');
      } else {
        this.showToast('Success', `Found ${this.onDemandBillsFound} bills`, 'success');
      }

    } catch (error) {
      console.error('TRINITY: Error searching On-Demand bills:', error);
      this.showToast('Error', error.body?.message || 'Error searching bills', 'error');
    } finally {
      this.isLoading = false;
    }
  }

  handleOnDemandClear() {
    console.log('TRINITY: On-Demand Clear clicked');
    this.onDemandFromDate = null;
    this.onDemandToDate = null;
    this.onDemandAllBills = [];
    this.onDemandSelectedBillIds = [];
    this.onDemandRows = [];
    this.onDemandBillsFound = 0;
    this.onDemandBillsSelected = 0;
    this.onDemandGroupsCount = 0;
  }

  handleOnDemandRowSelection(event) {
    const selectedRows = event.detail.selectedRows;
    this.onDemandSelectedBillIds = selectedRows.map(row => row.id);
    this.onDemandBillsSelected = this.onDemandSelectedBillIds.length;

    console.log('TRINITY: On-Demand Bills selected:', this.onDemandBillsSelected);
    console.log('TRINITY: Selected Bill IDs:', this.onDemandSelectedBillIds);
  }

  async handleCreateOnDemandBatch() {
    if (this.onDemandSelectedBillIds.length === 0) {
      this.showToast('Warning', 'Please select at least one Bill', 'warning');
      return;
    }

    console.log('TRINITY: Creating On-Demand Batch');
    console.log('TRINITY: Use Case:', this.onDemandUseCase);
    console.log('TRINITY: Selected Bills:', this.onDemandSelectedBillIds);

    this.isLoading = true;

    try {
      // TODO: Call new Apex method to create On-Demand batch
      // For now, we'll show a placeholder message

      this.showToast(
        'Info',
        `On-Demand Batch creation coming soon! Use Case: ${this.onDemandUseCase}, Bills: ${this.onDemandBillsSelected}`,
        'info'
      );

      // Clear the form
      this.handleOnDemandClear();

    } catch (error) {
      console.error('TRINITY: Error creating On-Demand batch:', error);
      this.showToast('Error', error.body?.message || 'Error creating On-Demand batch', 'error');
    } finally {
      this.isLoading = false;
    }
  }

  handleCancel() {
    this.dispatchEvent(new CloseActionScreenEvent());
  }

  showToast(title, message, variant) {
    this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
  }
}

