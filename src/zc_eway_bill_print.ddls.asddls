@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'E-Way Bill Print List'
@Metadata.allowExtensions: true
define root view entity ZC_EWAY_BILL_PRINT as projection on ZI_EWAY_BILL_PRINT
{
    key CompanyCode,
    key FiscalYear,
    key DocumentNumber,
    key DocumentType,
    key EInvoiceNumber,
    GSTIN,
    Plant,
    IRN,
    GeneratedDate,
    BillingDate,
    BillingTime,
    Status,
    IRNStatus,
    Criticality,
    CancellationDate,
    CancellationTime,
    CreatedBy,
    CreatedDate,
    CreatedTime,
    LastChangedBy,
    LastChangedDate
}
