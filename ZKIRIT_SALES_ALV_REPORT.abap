*&---------------------------------------------------------------------*
*& Program     : ZKIRIT_SALES_ALV_REPORT
*& Description : Custom ALV Report - Sales Order Analysis
*& Author      : [Your Name] | Roll No: [Your Roll Number]
*& Batch/Program: [Your Batch/Program]
*& Created On  : April 2026
*& Version     : 1.0
*&---------------------------------------------------------------------*
*& DESCRIPTION:
*& This program generates a custom ALV Grid report for Sales Order
*& analysis. It fetches data from VBAK (Sales Order Header) and VBAP
*& (Sales Order Items), and presents a formatted, interactive ALV
*& report with totals, sorting, and filtering capabilities.
*&---------------------------------------------------------------------*

REPORT zkirit_sales_alv_report
  NO STANDARD PAGE HEADING
  LINE-SIZE 255
  MESSAGE-ID zmsales.

*----------------------------------------------------------------------*
* TYPE DECLARATIONS
*----------------------------------------------------------------------*
TYPES: BEGIN OF ty_sales_order,
         vbeln TYPE vbak-vbeln,       " Sales Order Number
         audat TYPE vbak-audat,       " Order Date
         kunnr TYPE vbak-kunnr,       " Sold-to Party (Customer)
         name1 TYPE kna1-name1,       " Customer Name
         bukrs TYPE vbak-bukrs,       " Company Code (from Header Condition)
         vkorg TYPE vbak-vkorg,       " Sales Organization
         vtweg TYPE vbak-vtweg,       " Distribution Channel
         spart TYPE vbak-spart,       " Division
         posnr TYPE vbap-posnr,       " Item Number
         matnr TYPE vbap-matnr,       " Material Number
         arktx TYPE vbap-arktx,       " Short Description of Item
         kwmeng TYPE vbap-kwmeng,     " Order Quantity
         vrkme TYPE vbap-vrkme,       " Sales Unit
         netwr TYPE vbap-netwr,       " Net Value
         waerk TYPE vbap-waerk,       " Currency
         erdat TYPE vbap-erdat,       " Item Creation Date
         lfsta TYPE vbup-lfsta,       " Delivery Status
         fksta TYPE vbup-fksta,       " Billing Status
         gbsta TYPE vbup-gbsta,       " Overall Status
       END OF ty_sales_order.

*----------------------------------------------------------------------*
* INTERNAL TABLES & WORK AREAS
*----------------------------------------------------------------------*
DATA: gt_sales_order  TYPE STANDARD TABLE OF ty_sales_order,
      gs_sales_order  TYPE ty_sales_order,
      gt_fieldcat     TYPE slis_t_fieldcat_alv,
      gs_fieldcat     TYPE slis_fieldcat_alv,
      gs_layout       TYPE slis_layout_alv,
      gs_sort         TYPE slis_sortinfo_alv,
      gt_sort         TYPE slis_t_sortinfo_alv,
      gt_events       TYPE slis_t_event,
      gs_event        TYPE slis_alv_event,
      gs_variant      TYPE disvariant,
      gt_subtot       TYPE slis_t_sp_group_alv.

* Auxiliary tables for join
DATA: lt_vbak  TYPE STANDARD TABLE OF vbak,
      ls_vbak  TYPE vbak,
      lt_vbap  TYPE STANDARD TABLE OF vbap,
      ls_vbap  TYPE vbap,
      lt_vbup  TYPE STANDARD TABLE OF vbup,
      ls_vbup  TYPE vbup,
      lt_kna1  TYPE STANDARD TABLE OF kna1,
      ls_kna1  TYPE kna1.

*----------------------------------------------------------------------*
* SELECTION SCREEN
*----------------------------------------------------------------------*
SELECTION-SCREEN BEGIN OF BLOCK b1 WITH FRAME TITLE TEXT-001.

  SELECT-OPTIONS:
    s_vbeln FOR vbak-vbeln MATCHCODE OBJECT vmva,  " Sales Order No
    s_audat FOR vbak-audat,                         " Order Date
    s_kunnr FOR vbak-kunnr MATCHCODE OBJECT debr,  " Customer
    s_vkorg FOR vbak-vkorg,                         " Sales Org
    s_matnr FOR vbap-matnr MATCHCODE OBJECT mat1.  " Material

SELECTION-SCREEN END OF BLOCK b1.

SELECTION-SCREEN BEGIN OF BLOCK b2 WITH FRAME TITLE TEXT-002.
  PARAMETERS:
    p_alv   RADIOBUTTON GROUP r1 DEFAULT 'X',  " ALV Grid
    p_list  RADIOBUTTON GROUP r1.              " ALV List
SELECTION-SCREEN END OF BLOCK b2.

*----------------------------------------------------------------------*
* INITIALIZATION
*----------------------------------------------------------------------*
INITIALIZATION.
  " Set default date range: last 90 days
  s_audat-sign   = 'I'.
  s_audat-option = 'BT'.
  s_audat-low    = sy-datum - 90.
  s_audat-high   = sy-datum.
  APPEND s_audat.

*----------------------------------------------------------------------*
* AT SELECTION-SCREEN VALIDATION
*----------------------------------------------------------------------*
AT SELECTION-SCREEN.
  IF s_audat-low IS NOT INITIAL AND s_audat-high IS NOT INITIAL.
    IF s_audat-low > s_audat-high.
      MESSAGE e001(zmsales) WITH 'From Date cannot be greater than To Date'.
    ENDIF.
  ENDIF.

*----------------------------------------------------------------------*
* START-OF-SELECTION
*----------------------------------------------------------------------*
START-OF-SELECTION.

  PERFORM fetch_data.

  IF gt_sales_order IS INITIAL.
    MESSAGE s000(zmsales) WITH 'No records found for the given selection criteria'.
    RETURN.
  ENDIF.

  PERFORM build_fieldcat.
  PERFORM build_layout.
  PERFORM build_sort.
  PERFORM build_events.
  PERFORM display_alv.

*----------------------------------------------------------------------*
* FORM: FETCH_DATA
*----------------------------------------------------------------------*
FORM fetch_data.

  " Step 1: Select from VBAK (Sales Order Header)
  SELECT vbeln audat kunnr vkorg vtweg spart
    INTO CORRESPONDING FIELDS OF TABLE lt_vbak
    FROM vbak
    WHERE vbeln IN s_vbeln
      AND audat IN s_audat
      AND kunnr IN s_kunnr
      AND vkorg IN s_vkorg
      AND vbtyp = 'C'.                  " Standard Orders only

  IF lt_vbak IS INITIAL.
    RETURN.
  ENDIF.

  " Collect all order numbers
  DATA: lt_vbeln TYPE RANGE OF vbak-vbeln,
        ls_vbeln LIKE LINE OF lt_vbeln.

  LOOP AT lt_vbak INTO ls_vbak.
    ls_vbeln-sign   = 'I'.
    ls_vbeln-option = 'EQ'.
    ls_vbeln-low    = ls_vbak-vbeln.
    APPEND ls_vbeln TO lt_vbeln.
  ENDLOOP.

  " Step 2: Select from VBAP (Sales Order Items)
  SELECT vbeln posnr matnr arktx kwmeng vrkme netwr waerk erdat
    INTO CORRESPONDING FIELDS OF TABLE lt_vbap
    FROM vbap
    WHERE vbeln IN lt_vbeln
      AND matnr IN s_matnr
      AND abgru = ' '.                  " No rejection reason

  " Step 3: Select from VBUP (Item Status)
  SELECT vbeln posnr lfsta fksta gbsta
    INTO CORRESPONDING FIELDS OF TABLE lt_vbup
    FROM vbup
    WHERE vbeln IN lt_vbeln.

  " Step 4: Get Customer Names from KNA1
  DATA: lt_kunnr TYPE RANGE OF kna1-kunnr,
        ls_kunnr LIKE LINE OF lt_kunnr.

  LOOP AT lt_vbak INTO ls_vbak.
    READ TABLE lt_kunnr WITH KEY low = ls_vbak-kunnr TRANSPORTING NO FIELDS.
    IF sy-subrc <> 0.
      ls_kunnr-sign   = 'I'.
      ls_kunnr-option = 'EQ'.
      ls_kunnr-low    = ls_vbak-kunnr.
      APPEND ls_kunnr TO lt_kunnr.
    ENDIF.
  ENDLOOP.

  SELECT kunnr name1
    INTO CORRESPONDING FIELDS OF TABLE lt_kna1
    FROM kna1
    WHERE kunnr IN lt_kunnr.

  " Step 5: Assemble final internal table
  LOOP AT lt_vbap INTO ls_vbap.

    READ TABLE lt_vbak INTO ls_vbak
      WITH KEY vbeln = ls_vbap-vbeln.
    IF sy-subrc <> 0. CONTINUE. ENDIF.

    READ TABLE lt_kna1 INTO ls_kna1
      WITH KEY kunnr = ls_vbak-kunnr.

    READ TABLE lt_vbup INTO ls_vbup
      WITH KEY vbeln = ls_vbap-vbeln
               posnr = ls_vbap-posnr.

    " Populate output structure
    gs_sales_order-vbeln  = ls_vbap-vbeln.
    gs_sales_order-audat  = ls_vbak-audat.
    gs_sales_order-kunnr  = ls_vbak-kunnr.
    gs_sales_order-name1  = ls_kna1-name1.
    gs_sales_order-vkorg  = ls_vbak-vkorg.
    gs_sales_order-vtweg  = ls_vbak-vtweg.
    gs_sales_order-spart  = ls_vbak-spart.
    gs_sales_order-posnr  = ls_vbap-posnr.
    gs_sales_order-matnr  = ls_vbap-matnr.
    gs_sales_order-arktx  = ls_vbap-arktx.
    gs_sales_order-kwmeng = ls_vbap-kwmeng.
    gs_sales_order-vrkme  = ls_vbap-vrkme.
    gs_sales_order-netwr  = ls_vbap-netwr.
    gs_sales_order-waerk  = ls_vbap-waerk.
    gs_sales_order-erdat  = ls_vbap-erdat.
    gs_sales_order-lfsta  = ls_vbup-lfsta.
    gs_sales_order-fksta  = ls_vbup-fksta.
    gs_sales_order-gbsta  = ls_vbup-gbsta.

    APPEND gs_sales_order TO gt_sales_order.
    CLEAR gs_sales_order.

  ENDLOOP.

ENDFORM.

*----------------------------------------------------------------------*
* FORM: BUILD_FIELDCAT
*----------------------------------------------------------------------*
FORM build_fieldcat.

  DEFINE add_field.
    CLEAR gs_fieldcat.
    gs_fieldcat-fieldname    = &1.
    gs_fieldcat-tabname      = 'GT_SALES_ORDER'.
    gs_fieldcat-seltext_l    = &2.
    gs_fieldcat-seltext_m    = &3.
    gs_fieldcat-seltext_s    = &4.
    gs_fieldcat-outputlen    = &5.
    gs_fieldcat-col_pos      = &6.
    IF &7 = 'X'. gs_fieldcat-do_sum = 'X'. ENDIF.
    IF &8 = 'X'. gs_fieldcat-no_zero = 'X'. ENDIF.
    APPEND gs_fieldcat TO gt_fieldcat.
  END-OF-DEFINITION.

  "          Field       Long Text              Medium        Short  Len  Pos  Sum  NoZero
  add_field 'VBELN'    'Sales Order'          'Order'       'SO'   10   1   ' ' ' '.
  add_field 'AUDAT'    'Order Date'           'Ord.Date'    'Date'  10   2   ' ' ' '.
  add_field 'KUNNR'    'Customer No.'         'Customer'    'Cust'  10   3   ' ' ' '.
  add_field 'NAME1'    'Customer Name'        'Name'        'Name'  30   4   ' ' ' '.
  add_field 'VKORG'    'Sales Org.'           'Sales Org'   'SOrg'   4   5   ' ' ' '.
  add_field 'VTWEG'    'Distribution Channel' 'Dist.Ch'     'DCh'    2   6   ' ' ' '.
  add_field 'SPART'    'Division'             'Div.'        'Div'    2   7   ' ' ' '.
  add_field 'POSNR'    'Item'                 'Item'        'Itm'    6   8   ' ' ' '.
  add_field 'MATNR'    'Material Number'      'Material'    'Mat'   18   9   ' ' ' '.
  add_field 'ARKTX'    'Material Description' 'Description' 'Desc'  30  10   ' ' ' '.
  add_field 'KWMENG'   'Order Quantity'       'Quantity'    'Qty'   13  11   'X' 'X'.
  add_field 'VRKME'    'Sales Unit'           'Unit'        'UoM'    3  12   ' ' ' '.
  add_field 'NETWR'    'Net Value'            'Net Value'   'NetV'  15  13   'X' 'X'.
  add_field 'WAERK'    'Currency'             'Curr.'       'Curr'   5  14   ' ' ' '.
  add_field 'LFSTA'    'Delivery Status'      'Dlv.Status'  'DS'     1  15   ' ' ' '.
  add_field 'FKSTA'    'Billing Status'       'Bill.Status' 'BS'     1  16   ' ' ' '.
  add_field 'GBSTA'    'Overall Status'       'Ovr.Status'  'OS'     1  17   ' ' ' '.

ENDFORM.

*----------------------------------------------------------------------*
* FORM: BUILD_LAYOUT
*----------------------------------------------------------------------*
FORM build_layout.

  gs_layout-zebra           = 'X'.    " Alternating row colors
  gs_layout-colwidth_optimize = 'X'.  " Optimize column widths
  gs_layout-detail_popup    = 'X'.    " Popup for detail view
  gs_layout-totals_text     = 'Totals'(tot).
  gs_layout-subtotals_text  = 'Sub-Totals'(sub).
  gs_layout-cell_merge      = 'X'.    " Merge cells for same values

  " Variant for saving display layout
  gs_variant-report         = sy-repid.

ENDFORM.

*----------------------------------------------------------------------*
* FORM: BUILD_SORT
*----------------------------------------------------------------------*
FORM build_sort.

  CLEAR gs_sort.
  gs_sort-fieldname  = 'VBELN'.
  gs_sort-tabname    = 'GT_SALES_ORDER'.
  gs_sort-up         = 'X'.
  gs_sort-subtot     = 'X'.             " Subtotals per Sales Order
  APPEND gs_sort TO gt_sort.

  CLEAR gs_sort.
  gs_sort-fieldname  = 'KUNNR'.
  gs_sort-tabname    = 'GT_SALES_ORDER'.
  gs_sort-up         = 'X'.
  APPEND gs_sort TO gt_sort.

ENDFORM.

*----------------------------------------------------------------------*
* FORM: BUILD_EVENTS
*----------------------------------------------------------------------*
FORM build_events.

  " TOP-OF-PAGE event for report header
  CLEAR gs_event.
  gs_event-name     = slis_ev_top_of_page.
  gs_event-form     = 'TOP_OF_PAGE'.
  APPEND gs_event TO gt_events.

  " END-OF-PAGE event for report footer
  CLEAR gs_event.
  gs_event-name     = slis_ev_end_of_page.
  gs_event-form     = 'END_OF_PAGE'.
  APPEND gs_event TO gt_events.

  " User command — handle button clicks
  CLEAR gs_event.
  gs_event-name     = slis_ev_user_command.
  gs_event-form     = 'USER_COMMAND'.
  APPEND gs_event TO gt_events.

ENDFORM.

*----------------------------------------------------------------------*
* FORM: DISPLAY_ALV
*----------------------------------------------------------------------*
FORM display_alv.

  IF p_alv = 'X'.
    " Display ALV Grid
    CALL FUNCTION 'REUSE_ALV_GRID_DISPLAY'
      EXPORTING
        i_callback_program       = sy-repid
        i_callback_top_of_page   = 'TOP_OF_PAGE'
        i_callback_user_command  = 'USER_COMMAND'
        is_layout                = gs_layout
        it_fieldcat              = gt_fieldcat
        it_sort                  = gt_sort
        i_save                   = 'A'
        is_variant               = gs_variant
      TABLES
        t_outtab                 = gt_sales_order
      EXCEPTIONS
        program_error            = 1
        OTHERS                   = 2.
  ELSE.
    " Display ALV List
    CALL FUNCTION 'REUSE_ALV_LIST_DISPLAY'
      EXPORTING
        i_callback_program      = sy-repid
        i_callback_top_of_page  = 'TOP_OF_PAGE'
        i_callback_user_command = 'USER_COMMAND'
        is_layout               = gs_layout
        it_fieldcat             = gt_fieldcat
        it_sort                 = gt_sort
        i_save                  = 'A'
        is_variant              = gs_variant
      TABLES
        t_outtab                = gt_sales_order
      EXCEPTIONS
        program_error           = 1
        OTHERS                  = 2.
  ENDIF.

  IF sy-subrc <> 0.
    MESSAGE e001(zmsales) WITH 'Error displaying ALV Report'.
  ENDIF.

ENDFORM.

*----------------------------------------------------------------------*
* FORM: TOP_OF_PAGE
*----------------------------------------------------------------------*
FORM top_of_page.

  DATA: lt_header   TYPE slis_t_listheader,
        ls_header   TYPE slis_listheader.

  " Report Title
  CLEAR ls_header.
  ls_header-typ  = 'H'.
  ls_header-info = 'Sales Order ALV Report — ZKIRIT_SALES_ALV_REPORT'.
  APPEND ls_header TO lt_header.

  " Date Range
  CLEAR ls_header.
  ls_header-typ  = 'S'.
  ls_header-key  = 'Date Range : '.
  CONCATENATE s_audat-low '  to  ' s_audat-high INTO ls_header-info SEPARATED BY space.
  APPEND ls_header TO lt_header.

  " Record Count
  CLEAR ls_header.
  ls_header-typ  = 'S'.
  ls_header-key  = 'Total Records : '.
  ls_header-info = lines( gt_sales_order ).
  APPEND ls_header TO lt_header.

  " Print Date
  CLEAR ls_header.
  ls_header-typ  = 'A'.
  CONCATENATE 'Printed by :' sy-uname ' on ' sy-datum INTO ls_header-info SEPARATED BY space.
  APPEND ls_header TO lt_header.

  CALL FUNCTION 'REUSE_ALV_COMMENTARY_WRITE'
    EXPORTING
      it_list_commentary = lt_header.

ENDFORM.

*----------------------------------------------------------------------*
* FORM: END_OF_PAGE
*----------------------------------------------------------------------*
FORM end_of_page.
  WRITE: / 'End of Report — Confidential'.
ENDFORM.

*----------------------------------------------------------------------*
* FORM: USER_COMMAND — Handle toolbar button actions
*----------------------------------------------------------------------*
FORM user_command USING r_ucomm     TYPE sy-ucomm
                        rs_selfield TYPE slis_selfield.

  CASE r_ucomm.

    WHEN '&IC1'.  " Double-click on row — navigate to Sales Order (VA03)
      READ TABLE gt_sales_order INTO gs_sales_order
        INDEX rs_selfield-tabindex.
      IF sy-subrc = 0 AND gs_sales_order-vbeln IS NOT INITIAL.
        SET PARAMETER ID 'AUN' FIELD gs_sales_order-vbeln.
        CALL TRANSACTION 'VA03' AND SKIP FIRST SCREEN.
      ENDIF.

    WHEN 'REFR'.  " Refresh
      CLEAR gt_sales_order.
      PERFORM fetch_data.
      rs_selfield-refresh = 'X'.

  ENDCASE.

ENDFORM.
*&---------------------------------------------------------------------*
*& END OF PROGRAM: ZKIRIT_SALES_ALV_REPORT
*&---------------------------------------------------------------------*
