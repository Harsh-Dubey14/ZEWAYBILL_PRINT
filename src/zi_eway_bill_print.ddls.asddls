@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'E-Way Bill Print List'
@Metadata.ignorePropagatedAnnotations: true
define root view entity ZI_EWAY_BILL_PRINT
  as select from ZI_EWAYBILLPRINT
{
  key Bukrs       as CompanyCode,
  key Gjahr       as FiscalYear,
  key Docno       as DocumentNumber,
  key DocType     as DocumentType,
  key Ebillno     as EInvoiceNumber,
      Gstin       as GSTIN,
      Plant       as Plant,
      Irn         as IRN,
      EgenDat     as GeneratedDate,
      Vdfmdate    as BillingDate,
      Vdfmtime    as BillingTime,
      Status      as Status,
      IrnStatus1  as IRNStatus,
      Criticality as Criticality,
      EcanDat     as CancellationDate,
      EcanTime    as CancellationTime,
      Ernam       as CreatedBy,
      Erdat       as CreatedDate,
      Uzeit       as CreatedTime,
      Aenam       as LastChangedBy,
      Aedat       as LastChangedDate
}
