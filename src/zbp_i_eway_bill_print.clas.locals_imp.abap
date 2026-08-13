CLASS lhc_ewaybill DEFINITION
  INHERITING FROM cl_abap_behavior_handler.

  PRIVATE SECTION.

    METHODS get_global_authorizations
      FOR GLOBAL AUTHORIZATION
      IMPORTING
        REQUEST requested_authorizations
        FOR ewaybill
      RESULT result.

    METHODS read
      FOR READ
      IMPORTING
        keys
        FOR READ ewaybill
      RESULT result.

    METHODS lock
      FOR LOCK
      IMPORTING
        keys
        FOR LOCK ewaybill.

    METHODS printewaybill
      FOR MODIFY
      IMPORTING
        keys
        FOR ACTION ewaybill~printewaybill
      RESULT result.

ENDCLASS.


CLASS lhc_ewaybill IMPLEMENTATION.

  METHOD get_global_authorizations.

    IF requested_authorizations-%action-PrintEwayBill =
       if_abap_behv=>mk-on.

      result-%action-PrintEwayBill =
        if_abap_behv=>auth-allowed.

    ENDIF.

  ENDMETHOD.


  METHOD read.

    IF keys IS INITIAL.
      RETURN.
    ENDIF.

    SELECT FROM zi_eway_bill_print
      FIELDS
        CompanyCode,
        FiscalYear,
        DocumentNumber,
        DocumentType,
        EInvoiceNumber,
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
      FOR ALL ENTRIES IN @keys
      WHERE CompanyCode     = @keys-CompanyCode
        AND FiscalYear      = @keys-FiscalYear
        AND DocumentNumber  = @keys-DocumentNumber
        AND DocumentType    = @keys-DocumentType
        AND EInvoiceNumber  = @keys-EInvoiceNumber
      INTO CORRESPONDING FIELDS OF TABLE @result.

  ENDMETHOD.


  METHOD lock.

    "The business object is read-only.
    "The action only calls the external API and returns the PDF.
    "No database locking is currently required.

  ENDMETHOD.


METHOD printewaybill.

  CONSTANTS:
    "Kopran Gujarat
    lc_gstin_gj    TYPE string VALUE '27AAACK3198E1ZJ',
    lc_username_gj TYPE string VALUE 'et_kopran_mh_sandbox',
    lc_token_gj    TYPE string VALUE '99df7436c4f73293e20b9252f6c4bec01032c26d',

    "Kopran Maharashtra
    lc_gstin_mh    TYPE string VALUE '27AAACK3198E1ZJ',
    lc_username_mh TYPE string VALUE 'et_kopran_mh_sandbox',
    lc_token_mh    TYPE string VALUE '99df7436c4f73293e20b9252f6c4bec01032c26d'.

  DATA:
    lv_eway_bill_no TYPE string,
    lv_irn          TYPE string,
    lv_gstin        TYPE string,
    lv_username     TYPE string,
    lv_token        TYPE string,
    lv_details_url  TYPE string,
    lv_print_url    TYPE string,
    lv_details_json TYPE string,
    lv_request_json TYPE string,
    lv_response     TYPE string,
    lv_base64       TYPE string,
    lv_filename     TYPE string,
    lv_message      TYPE string.

  IF keys IS INITIAL.
    RETURN.
  ENDIF.

  LOOP AT keys ASSIGNING FIELD-SYMBOL(<ls_key>).

    CLEAR:
      lv_eway_bill_no,
      lv_irn,
      lv_gstin,
      lv_username,
      lv_token,
      lv_details_url,
      lv_print_url,
      lv_details_json,
      lv_request_json,
      lv_response,
      lv_base64,
      lv_filename,
      lv_message.

    "------------------------------------------------------------
    "Read selected E-Way Bill record
    "------------------------------------------------------------
    SELECT SINGLE FROM zi_eway_bill_print
      FIELDS
        EInvoiceNumber,
        IRN,
        GSTIN
      WHERE CompanyCode    = @<ls_key>-CompanyCode
        AND FiscalYear     = @<ls_key>-FiscalYear
        AND DocumentNumber = @<ls_key>-DocumentNumber
        AND DocumentType   = @<ls_key>-DocumentType
        AND EInvoiceNumber = @<ls_key>-EInvoiceNumber
      INTO @DATA(ls_eway_bill).

    IF sy-subrc <> 0.

      APPEND VALUE #(
        %tky = <ls_key>-%tky
        %param = VALUE #(
          Success    = abap_false
          Message    = 'Selected E-Way Bill record was not found'
          FileName   = ''
          MimeType   = ''
          Base64Data = ''
        )
      ) TO result.

      CONTINUE.

    ENDIF.

    lv_eway_bill_no = ls_eway_bill-EInvoiceNumber.
    lv_irn          = ls_eway_bill-IRN.
    lv_gstin        = ls_eway_bill-GSTIN.

    IF lv_eway_bill_no IS INITIAL.

      APPEND VALUE #(
        %tky = <ls_key>-%tky
        %param = VALUE #(
          Success    = abap_false
          Message    = 'E-Way Bill number is empty'
          FileName   = ''
          MimeType   = ''
          Base64Data = ''
        )
      ) TO result.

      CONTINUE.

    ENDIF.

    IF lv_gstin IS INITIAL.

      APPEND VALUE #(
        %tky = <ls_key>-%tky
        %param = VALUE #(
          Success    = abap_false
          Message    = 'GSTIN is empty for the selected record'
          FileName   = ''
          MimeType   = ''
          Base64Data = ''
        )
      ) TO result.

      CONTINUE.

    ENDIF.

    "------------------------------------------------------------
    "Select Kopran credentials according to GSTIN
    "------------------------------------------------------------
    CASE lv_gstin.

      WHEN lc_gstin_gj.

        lv_username = lc_username_gj.
        lv_token    = lc_token_gj.

      WHEN lc_gstin_mh.

        lv_username = lc_username_mh.
        lv_token    = lc_token_mh.

      WHEN OTHERS.

        APPEND VALUE #(
          %tky = <ls_key>-%tky
          %param = VALUE #(
            Success    = abap_false
            Message    = |No API credentials maintained for GSTIN { lv_gstin }|
            FileName   = ''
            MimeType   = ''
            Base64Data = ''
          )
        ) TO result.

        CONTINUE.

    ENDCASE.

    TRY.

        "--------------------------------------------------------
        "1. Get E-Way Bill details
        "--------------------------------------------------------
        lv_details_url =
          |https://einvapi.expoundtax.in:443/api/eway/| &&
          |get-eway-bill-details/?ewbNo={ lv_eway_bill_no }|.

        DATA(lo_details_destination) =
          cl_http_destination_provider=>create_by_url(
            i_url = lv_details_url
          ).

        DATA(lo_details_client) =
          cl_web_http_client_manager=>create_by_http_destination(
            i_destination = lo_details_destination
          ).

        DATA(lo_details_request) =
          lo_details_client->get_http_request( ).

        lo_details_request->set_header_field(
          i_name  = 'Accept'
          i_value = 'application/json'
        ).

        lo_details_request->set_header_field(
          i_name  = 'gstin'
          i_value = lv_gstin
        ).

        lo_details_request->set_header_field(
          i_name  = 'username'
          i_value = lv_username
        ).

        lo_details_request->set_header_field(
          i_name  = 'Authorization'
          i_value = lv_token
        ).

        DATA(lo_details_response) =
          lo_details_client->execute(
            i_method = if_web_http_client=>get
          ).

        DATA(ls_details_status) =
          lo_details_response->get_status( ).

        lv_details_json =
          lo_details_response->get_text( ).

        lo_details_client->close( ).

        IF ls_details_status-code < 200
        OR ls_details_status-code >= 300.

          lv_message =
            |Get E-Way Bill details failed. | &&
            |HTTP { ls_details_status-code }: | &&
            lv_details_json.

          APPEND VALUE #(
            %tky = <ls_key>-%tky
            %param = VALUE #(
              Success    = abap_false
              Message    = lv_message
              FileName   = ''
              MimeType   = ''
              Base64Data = ''
            )
          ) TO result.

          CONTINUE.

        ENDIF.

        IF lv_details_json IS INITIAL.

          APPEND VALUE #(
            %tky = <ls_key>-%tky
            %param = VALUE #(
              Success    = abap_false
              Message    = 'E-Way Bill details API returned an empty response'
              FileName   = ''
              MimeType   = ''
              Base64Data = ''
            )
          ) TO result.

          CONTINUE.

        ENDIF.

        "--------------------------------------------------------
        "2. Build print request JSON
        "--------------------------------------------------------
        lv_request_json =
          `{"eway_bill_details":` &&
          lv_details_json &&
          `,"api_action":"printdetailewb"}`.

        "--------------------------------------------------------
        "3. Call E-Way Bill print API
        "--------------------------------------------------------
        lv_print_url =
          'https://einvapi.expoundtax.in:443/api/eway/print-eway-bill/'.

        DATA(lo_print_destination) =
          cl_http_destination_provider=>create_by_url(
            i_url = lv_print_url
          ).

        DATA(lo_print_client) =
          cl_web_http_client_manager=>create_by_http_destination(
            i_destination = lo_print_destination
          ).

        DATA(lo_print_request) =
          lo_print_client->get_http_request( ).

        lo_print_request->set_header_field(
          i_name  = 'Accept'
          i_value = 'application/json'
        ).

        lo_print_request->set_header_field(
          i_name  = 'Content-Type'
          i_value = 'application/json'
        ).

        lo_print_request->set_header_field(
          i_name  = 'gstin'
          i_value = lv_gstin
        ).

        lo_print_request->set_header_field(
          i_name  = 'username'
          i_value = lv_username
        ).

        lo_print_request->set_header_field(
          i_name  = 'Authorization'
          i_value = lv_token
        ).

        lo_print_request->set_text(
          i_text = lv_request_json
        ).

        DATA(lo_print_response) =
          lo_print_client->execute(
            i_method = if_web_http_client=>post
          ).

        DATA(ls_print_status) =
          lo_print_response->get_status( ).

        lv_response =
          lo_print_response->get_text( ).

        lo_print_client->close( ).

        IF ls_print_status-code < 200
        OR ls_print_status-code >= 300.

          lv_message =
            |Print E-Way Bill API failed. | &&
            |HTTP { ls_print_status-code }: | &&
            lv_response.

          APPEND VALUE #(
            %tky = <ls_key>-%tky
            %param = VALUE #(
              Success    = abap_false
              Message    = lv_message
              FileName   = ''
              MimeType   = ''
              Base64Data = ''
            )
          ) TO result.

          CONTINUE.

        ENDIF.

        "--------------------------------------------------------
        "4. Extract Base64 PDF and filename
        "--------------------------------------------------------
        FIND FIRST OCCURRENCE OF REGEX
          '"base64"[[:space:]]*:[[:space:]]*"([^"]+)"'
          IN lv_response
          SUBMATCHES lv_base64.

        FIND FIRST OCCURRENCE OF REGEX
          '"filename"[[:space:]]*:[[:space:]]*"([^"]+)"'
          IN lv_response
          SUBMATCHES lv_filename.

        "Some APIs may return Base64 directly
        IF lv_base64 IS INITIAL
        AND lv_response CP 'JVBER*'.

          lv_base64 = lv_response.

        ENDIF.

        IF lv_base64 IS INITIAL.

          APPEND VALUE #(
            %tky = <ls_key>-%tky
            %param = VALUE #(
              Success    = abap_false
              Message    =
                |The API succeeded, but no Base64 PDF was found: | &&
                lv_response
              FileName   = ''
              MimeType   = ''
              Base64Data = ''
            )
          ) TO result.

          CONTINUE.

        ENDIF.

        IF lv_filename IS INITIAL.
          lv_filename = |EWayBill_{ lv_eway_bill_no }.pdf|.
        ENDIF.

        APPEND VALUE #(
          %tky = <ls_key>-%tky
          %param = VALUE #(
            Success    = abap_true
            Message    = 'E-Way Bill PDF generated successfully'
            FileName   = lv_filename
            MimeType   = 'application/pdf'
            Base64Data = lv_base64
          )
        ) TO result.

      CATCH cx_http_dest_provider_error INTO DATA(lx_destination).

        APPEND VALUE #(
          %tky = <ls_key>-%tky
          %param = VALUE #(
            Success    = abap_false
            Message    =
              |HTTP destination error: { lx_destination->get_text( ) }|
            FileName   = ''
            MimeType   = ''
            Base64Data = ''
          )
        ) TO result.

      CATCH cx_web_http_client_error INTO DATA(lx_http).

        APPEND VALUE #(
          %tky = <ls_key>-%tky
          %param = VALUE #(
            Success    = abap_false
            Message    =
              |HTTP client error: { lx_http->get_text( ) }|
            FileName   = ''
            MimeType   = ''
            Base64Data = ''
          )
        ) TO result.

      CATCH cx_root INTO DATA(lx_root).

        APPEND VALUE #(
          %tky = <ls_key>-%tky
          %param = VALUE #(
            Success    = abap_false
            Message    =
              |Unexpected error: { lx_root->get_text( ) }|
            FileName   = ''
            MimeType   = ''
            Base64Data = ''
          )
        ) TO result.

    ENDTRY.

  ENDLOOP.

ENDMETHOD.
ENDCLASS.



CLASS lsc_zi_eway_bill_print DEFINITION
  INHERITING FROM cl_abap_behavior_saver.

  PROTECTED SECTION.

    METHODS finalize REDEFINITION.

    METHODS check_before_save REDEFINITION.

    METHODS save REDEFINITION.

    METHODS cleanup REDEFINITION.

    METHODS cleanup_finalize REDEFINITION.

ENDCLASS.


CLASS lsc_zi_eway_bill_print IMPLEMENTATION.

  METHOD finalize.
  ENDMETHOD.

  METHOD check_before_save.
  ENDMETHOD.

  METHOD save.
  ENDMETHOD.

  METHOD cleanup.
  ENDMETHOD.

  METHOD cleanup_finalize.
  ENDMETHOD.

ENDCLASS.
