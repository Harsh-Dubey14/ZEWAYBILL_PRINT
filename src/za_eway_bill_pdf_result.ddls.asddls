@EndUserText.label: 'E-Way Bill PDF Result'
define abstract entity ZA_EWAY_BILL_PDF_RESULT
{
  FileName   : abap.char(255);
  MimeType   : abap.char(100);
  Base64Data : abap.string(0);
  Message    : abap.string(0);
  Success    : abap_boolean;
}
