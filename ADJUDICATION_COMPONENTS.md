# Componentes de Adjudicación y Bill Review - MVADM-188

Este documento lista todos los componentes incluidos en el repositorio Git para el trabajo de adjudicación y bill review.

---

## Clases Apex - Bill Review y Medical Billing

### Servicio Principal
- `TRM_MedicalBillingService.cls` - Servicio principal de facturación médica (1,834 líneas)
- `TRM_MedicalBillingService.cls-meta.xml`
- `TRM_MedicalBillingServiceTest.cls` - Tests (969 líneas, 52 tests)
- `TRM_MedicalBillingServiceTest.cls-meta.xml`

### Validación
- `TRM_ValidationService.cls` - Servicio de validación para adjudicación
- `TRM_ValidationService.cls-meta.xml`
- `TRM_ValidationServiceTest.cls` - Tests (579 líneas, 26 tests)
- `TRM_ValidationServiceTest.cls-meta.xml`

### Adjudicación BCN
- `TRM_BCNAdjudicationApi.cls` - API para adjudicación de BCN
- `TRM_BCNAdjudicationApi.cls-meta.xml`
- `TRM_BCNAdjudicationService.cls` - Servicio de adjudicación
- `TRM_BCNAdjudicationService.cls-meta.xml`

---

## Clases Apex - Detección de Duplicados

### Modelos
- `TRM_DuplicateDetectionModels.cls` - DTOs y modelos de datos
- `TRM_DuplicateDetectionModels.cls-meta.xml`
- `TRM_DuplicateDetectionModelsTest.cls` - Tests (330 líneas, 17 tests)
- `TRM_DuplicateDetectionModelsTest.cls-meta.xml`

### Servicio
- `TRM_DuplicateDetectionService.cls` - Lógica de detección de duplicados
- `TRM_DuplicateDetectionService.cls-meta.xml`
- `TRM_DuplicateDetectionServiceTest.cls` - Tests (539 líneas, 28 tests)
- `TRM_DuplicateDetectionServiceTest.cls-meta.xml`

### Handler
- `TRM_DuplicateDetectionHandler.cls` - Handler para triggers
- `TRM_DuplicateDetectionHandler.cls-meta.xml`
- `TRM_DuplicateDetectionHandlerTest.cls` - Tests (400 líneas, 21 tests)
- `TRM_DuplicateDetectionHandlerTest.cls-meta.xml`

### API
- `TRM_DuplicateDetectionApi.cls` - API expuesta a LWC
- `TRM_DuplicateDetectionApi.cls-meta.xml`
- `TRM_DuplicateDetectionApiTest.cls` - Tests (814 líneas, 45 tests)
- `TRM_DuplicateDetectionApiTest.cls-meta.xml`

### Legacy Handler
- `BillLineItemDuplicateHandler.cls` - Handler legacy (puede ser deprecado)
- `BillLineItemDuplicateHandler.cls-meta.xml`
- `BillLineItemDuplicateHandlerTest.cls` - Tests legacy
- `BillLineItemDuplicateHandlerTest.cls-meta.xml`

### Test Consolidado
- `TRM_DuplicateDetectionTest.cls` - Tests consolidados
- `TRM_DuplicateDetectionTest.cls-meta.xml`

---

## Triggers

### Bill Line Item Triggers
- `BillLineItemDuplicateDetection.trigger` - Trigger de detección de duplicados
- `BillLineItemDuplicateDetection.trigger-meta.xml`
- `dlrs_Bill_Line_ItemTrigger.trigger` - Trigger de rollup summaries (Declarative Lookup Rollup Summaries)
- `dlrs_Bill_Line_ItemTrigger.trigger-meta.xml`
- `dlrs_Bill_Line_ItemTest.cls` - Tests para DLRS trigger
- `dlrs_Bill_Line_ItemTest.cls-meta.xml`

---

## Componentes LWC - Bill Review

### Grid Principal
- `customBillLineItemGrid/` - Componente principal de grid de bill line items
  - `customBillLineItemGrid.html`
  - `customBillLineItemGrid.js` (2,700+ líneas)
  - `customBillLineItemGrid.css`
  - `customBillLineItemGrid.js-meta.xml`

### Componentes de Adjudicación
- `adjudicationControlPanel/` - Panel de controles de adjudicación
  - `adjudicationControlPanel.html`
  - `adjudicationControlPanel.js`
  - `adjudicationControlPanel.css`
  - `adjudicationControlPanel.js-meta.xml`

- `validationReportModal/` - Modal de reporte de validación
  - `validationReportModal.html`
  - `validationReportModal.js`
  - `validationReportModal.css`
  - `validationReportModal.js-meta.xml`

- `financialValidationPanel/` - Panel de validación financiera
  - `financialValidationPanel.html`
  - `financialValidationPanel.js`
  - `financialValidationPanel.css`
  - `financialValidationPanel.js-meta.xml`

- `billFlagsManager/` - Gestor de flags de bill
  - `billFlagsManager.html`
  - `billFlagsManager.js`
  - `billFlagsManager.css`
  - `billFlagsManager.js-meta.xml`

### Componentes de Duplicados
- `trmBillDuplicateSummary/` - Resumen de duplicados a nivel de Bill
  - `trmBillDuplicateSummary.html`
  - `trmBillDuplicateSummary.js`
  - `trmBillDuplicateSummary.css`
  - `trmBillDuplicateSummary.js-meta.xml`

- `trmCaseDuplicateSummary/` - Resumen de duplicados a nivel de Case
  - `trmCaseDuplicateSummary.html`
  - `trmCaseDuplicateSummary.js`
  - `trmCaseDuplicateSummary.css`
  - `trmCaseDuplicateSummary.js-meta.xml`

- `trmCaseDuplicateContainer/` - Contenedor de duplicados de Case
  - `trmCaseDuplicateContainer.html`
  - `trmCaseDuplicateContainer.js`
  - `trmCaseDuplicateContainer.css`
  - `trmCaseDuplicateContainer.js-meta.xml`

- `trmCaseAllDuplicatesModal/` - Modal de todos los duplicados
  - `trmCaseAllDuplicatesModal.html`
  - `trmCaseAllDuplicatesModal.js`
  - `trmCaseAllDuplicatesModal.css`
  - `trmCaseAllDuplicatesModal.js-meta.xml`

- `trmDuplicateComparisonModal/` - Modal de comparación de duplicados
  - `trmDuplicateComparisonModal.html`
  - `trmDuplicateComparisonModal.js`
  - `trmDuplicateComparisonModal.css`
  - `trmDuplicateComparisonModal.js-meta.xml`

- `trmDuplicateTriangle/` - Indicador visual de duplicados (triángulo)
  - `trmDuplicateTriangle.html`
  - `trmDuplicateTriangle.js`
  - `trmDuplicateTriangle.css`
  - `trmDuplicateTriangle.js-meta.xml`

- `duplicateTriangle/` - Indicador legacy de duplicados
  - `duplicateTriangle.html`
  - `duplicateTriangle.js`
  - `duplicateTriangle.css`
  - `duplicateTriangle.js-meta.xml`

### Componentes de Utilidad
- `codeLookupField/` - Campo de búsqueda de códigos CPT/HCPCS/NDC
  - `codeLookupField.html`
  - `codeLookupField.js`
  - `codeLookupField.css`
  - `codeLookupField.js-meta.xml`

- `bulkLineItemOperations/` - Operaciones bulk en line items
  - `bulkLineItemOperations.html`
  - `bulkLineItemOperations.js`
  - `bulkLineItemOperations.css`
  - `bulkLineItemOperations.js-meta.xml`

- `hoverTooltip/` - Tooltip reutilizable
  - `hoverTooltip.html`
  - `hoverTooltip.js`
  - `hoverTooltip.css`
  - `hoverTooltip.js-meta.xml`

---

## Objetos y Metadata

### Bill Line Item Object
- `objects/Bill_Line_Item__c/` - Definición del objeto Bill_Line_Item__c
  - `fields/` - Todos los campos custom
  - `listViews/` - Vistas de lista
  - `validationRules/` - Reglas de validación
  - `Bill_Line_Item__c.object-meta.xml`

### Bill Object
- `objects/Bill__c/` - Definición del objeto Bill__c (relacionado)
  - Campos relevantes para bill review
  - `Bill__c.object-meta.xml`

---

## Flows

### Bill Line Item Flows
- `flows/Bill_Line_Item_Generate_Filemaker_Id.flow-meta.xml` - Generación de External_Id__c
- `flows/Bill_Line_Item_Create_Update_Filemaker_Sync_Event.flow-meta.xml` - Sincronización con FileMaker
- `flows/Bill_Line_Item_Set_Bill_Relationship.flow-meta.xml` - Relación con Bill (si existe)

---

## Archivos de Configuración

### Salesforce DX
- `sfdx-project.json` - Configuración del proyecto
- `package.json` - Dependencias npm (si existen)
- `.forceignore` - Archivos ignorados en deploy

### LWC Config
- `lwc/jsconfig.json` - Configuración de JavaScript para LWC

---

**Total de Componentes:**
- **Clases Apex:** 24 archivos (12 clases + 12 meta.xml)
- **Triggers:** 6 archivos (3 triggers + 3 meta.xml/test)
- **LWC:** ~15 componentes (60+ archivos)
- **Objects:** 2 objetos principales
- **Flows:** 3+ flows relacionados

**Cobertura de Tests:**
- Total: 189 tests
- Total líneas de test: 3,631 líneas

