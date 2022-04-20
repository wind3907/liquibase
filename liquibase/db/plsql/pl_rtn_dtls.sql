/******************************************************************************
@(#) pl_rtn_dtls.sql
@(#) src/schema/plsql/pl_rtn_dtls.sql, swms, swms.9, 11.1 9/25/09 1.16
*******************************************************************************/
/******************************************************************************
Modification History
Date      User   Defect  Comment
02/20/02  prplhj 10772   Initial creation
05/24/02  prphqb         Fix so OVR, OVI creates putaway record with
mispick = Y
06/23/03  prplhj 11280   Weight and temperature collection changes. Existing
pickup return changes. Validate invoice # and
invalid character input in temperature.
07/10/03  prplhj 11312   Fix out-of-range temperature validation for RF
comming in the 1st time and subsequent times.
08/29/03  prplhj 11355   Fixed pickup return update problem.
04/09/04  acphxs 11573   LPN18 changes.
10/01/04  prplhj 11741   Added T-batch processing and convert some codes
originally done in Pro*C to PL/SQL.
04/05/05  prplhj 11898   Still create return even if the CTE_RTN_BTCH_FLG_OFF
flag is off.
09/09/05  prplhj 11996   Added codes to handle new returned code 352 and
change EXIT statement to RETURN statement for
procedure return.
10/07/05  prplhj 12012   When sending back string for o_add_msg variable, the
2nd field need to use PALLET_ID_LEN instead of 10.
Handle no T-batch creation for damage returns.
02/09/06  prphqb WAI     Add rule=3 to find returns slot.
04/10/06  prplhj WAI     D#12080 Don't check on rtn qty vs. ship qty if
reason is mispicked.
04/12/06  prphqb         Need to write exp_date=01/01/01 in INV record for ML
10/25/06  prpakp         Corrected the inv_uom for floating items to
returned_uom.
09/14/08  prplhj 12521   Get internal and external upc from PM_UPC instead of
PM.
07/07/11  prplhj PBI3112 Changed the way the code searches for internal/
external UPC that is no in the 14 0s/Xs/9s values.
10/24/11  jluo5859  SAPCR6711/CR29831 - Not allow over returned qty for
pickup for SAP company for all reason codes. Fixed
the weight collection problem during return creation.
11/14/12  bgul2852       CRQ35354- Changed c_get_mf_info to handle the
shipped_split_cd for case uom of zero.
10/03/14  ayad5195 SYMB  Modified function p_get_location to return matrix
induction location if item is assigned to matrix
10/25/2017 in p_create_rtn_info POD_Flag is checked in manifest_stops; 
if 'Y' then drivers are returning at Truck so do not allow return functionality
to eliminate double credit to customer;
12/20/2017 new procedure added P_Dlt_Damaged_Putaway_ERMD to be called when manifest
is closed.(Jira 182)

04/24/2018  mpha8134  Jira408  Fix issue where user gets 'User not found' error when adding returns. 

******************************************************************************/
CREATE OR REPLACE PACKAGE swms.pl_rtn_dtls
AS
  -- This package specification is used to do returns detail processing.
  -- Mainly use by RF.
  /*****************
  Public Constants
  *****************/
  ct_sql_success       NUMBER(1)   := 0;
  ct_sql_no_data_found NUMBER(4)   := 1403;
  ct_mf_process_failed NUMBER(1)   := 1;
  FIELD_LEN            NUMBER(2)   := 50;
  ct_process_error_id  VARCHAR2(9) := 'RTNDTL_LM';
  -- Existing error codes from tm_define.h
  ct_inv_prod_id         NUMBER(2) := 37;
  ct_manifest_close      NUMBER(4) := 1002;
  ct_weight_out_of_limit NUMBER(2) := 85;
  ct_put_done            NUMBER(2) := 94;
  ct_no_lm_batch_found   NUMBER(3) := 146;
  -- New constants for returns on PL/SQL side
  ct_inv_item_required   NUMBER(3) := 238;
  ct_inv_no_required     NUMBER(3) := 239;
  ct_invalid_disp        NUMBER(3) := 240;
  ct_invalid_mf          NUMBER(3) := 241;
  ct_invalid_mspk        NUMBER(3) := 242;
  ct_invalid_rsn         NUMBER(3) := 243;
  ct_invalid_upc         NUMBER(3) := 244;
  ct_itm_not_split       NUMBER(3) := 245;
  ct_manifest_pad        NUMBER(3) := 246;
  ct_mf_add_msg          NUMBER(3) := 247;
  ct_mf_required         NUMBER(3) := 248;
  ct_mspk_required       NUMBER(3) := 249;
  ct_multi_items         NUMBER(3) := 250;
  ct_no_loc_found        NUMBER(3) := 252;
  ct_no_mf_info          NUMBER(3) := 253;
  ct_no_order_found      NUMBER(3) := 254;
  ct_not_pkup_inv        NUMBER(3) := 255;
  ct_qty_required        NUMBER(3) := 256;
  ct_rsn_required        NUMBER(3) := 257;
  ct_rtn_qtysum_gt_ship  NUMBER(3) := 258;
  ct_ship_diff_uom       NUMBER(3) := 259;
  ct_temp_existed        NUMBER(3) := 260;
  ct_temp_no_range       NUMBER(3) := 261;
  ct_temp_out_of_limit   NUMBER(3) := 262;
  ct_temp_required       NUMBER(3) := 263;
  ct_weight_desired      NUMBER(3) := 264;
  ct_weight_existed      NUMBER(3) := 265;
  ct_weight_out_of_range NUMBER(3) := 266;
  ct_whole_number_only   NUMBER(3) := 267;
  ct_invalid_invoice_no  NUMBER(3) := 295;
  ct_temp_invalid        NUMBER(3) := 296;
  ct_mf_has_closed       NUMBER(3) := 352;
  ct_mf_is_POD           NUMBER(3) := 343;
  /*****************
  Public Definitions
  *****************/
TYPE trecRtn
IS
  RECORD
  (
    szField1  VARCHAR2(50),
    szField2  VARCHAR2(50),
    szField3  VARCHAR2(50),
    szField4  VARCHAR2(50),
    szField5  VARCHAR2(50),
    szField6  VARCHAR2(50),
    szField7  VARCHAR2(50),
    szField8  VARCHAR2(50),
    szField9  VARCHAR2(50),
    szField10 VARCHAR2(50),
    szField11 VARCHAR2(50),
    szField12 VARCHAR2(50),
    szField13 VARCHAR2(50),
    szField14 VARCHAR2(50),
    szField15 VARCHAR2(50),
    szField16 VARCHAR2(50),
    szField17 VARCHAR2(50),
    szField18 VARCHAR2(50),
    szField19 VARCHAR2(50),
    szField20 VARCHAR2(50),
    szField21 VARCHAR2(50),
    szField22 VARCHAR2(50) );
TYPE ttabRtns
IS
  TABLE OF trecRtn INDEX BY BINARY_INTEGER;
TYPE ttabValues
IS
  TABLE OF VARCHAR2(1000) INDEX BY BINARY_INTEGER;
  /*****************
  Public Variables
  *****************/
  gRcTypSyspar pl_dci.recTypSyspar;
  /********************************
  Public Functions and Procedures
  ********************************/
  -- Save the changed pallet type (if any) to a temporary table so a host program
  -- can retrieve the information created from this package and write the
  -- information to the LM apcom queue.
  -- The host program should delete the saved LM information record each time
  -- after the PROCESS_ERROR table is referenced so new information can be
  -- created. Refer to p_delete_apcom_lm for more information. Return sqlcode.
  -- The i_proc_err should have the following fields/values:
  --   process_id:    "RTNDTL_LM"
  --   value_1:       Manifest #
  --   value_2:       Updated pallet type
  --   error_msg      Item # + cust_pref_vendor
  FUNCTION f_save_apcom_lm(
      i_proc_err IN process_error%ROWTYPE)
    RETURN NUMBER;
  -- Delete the matched process error record for LM apcom queue record. This
  -- should be done after the host program finish refering the LM record. Return
  -- sqlcode.
  -- The i_proc_err should have the following fields/values:
  --   process_id:    "RTNDTL_LM"
  --   value_1:       Manifest #
  --   value_2:       Updated pallet type
  --   error_msg      Item # + cust_pref_vendor
  FUNCTION f_delete_apcom_lm(
      i_proc_err IN process_error%ROWTYPE)
    RETURN NUMBER;
  -- Get quantity information for nonoverage returns according to the manifest #
  -- (i_mf_no), invoice # (i_inv_no), item # (i_prod_id and i_cpv) and current
  -- unit of measure (i_uom.)
  -- I_cur_qty_in_case has a value for current returned quantity. Specify 0 if
  -- no current returned quantity.
  -- O_db_ship_qty and o_db_ship_uom return the originally shipped information as
  -- the value in database.
  -- O_total_rtn_in_case and o_ship_in_case return the values in cases.
  -- O_qty_exceed returns 1 if total current returned quantity (including
  -- i_cur_qty_in_case) is > originally shipped quantity; otherwise return 0.
  -- O_status has sqlcode or ct_no_mf_info.
  PROCEDURE p_get_nonoverage_qty_info(
      i_mf_no           IN manifest_dtls.manifest_no%TYPE,
      i_inv_no          IN manifest_dtls.obligation_no%TYPE,
      i_prod_id         IN manifest_dtls.prod_id%TYPE,
      i_cpv             IN manifest_dtls.cust_pref_vendor%TYPE,
      i_uom             IN returns.returned_split_cd%TYPE,
      i_cur_qty_in_case IN NUMBER,
      o_db_ship_qty OUT manifest_dtls.shipped_qty%TYPE,
      o_db_ship_uom OUT manifest_dtls.shipped_split_cd%TYPE,
      o_total_rtn_in_case OUT NUMBER,
      o_ship_in_case OUT NUMBER,
      o_qty_exceed OUT NUMBER,
      o_status OUT NUMBER);
  -- Create return information according to the input information.
  -- I_rf_option: Input RF number option to denote that the procedure is called
  --   at the 1st time (1) or from the 2nd time on the same session (>1).
  -- I_which_group has one the following values:
  --   'A' - Check all reason codes in "RTN" type.
  --   'I' - Check all reason codes is in "RTN" type other than overage codes.
  --   'V' - Check if reason code is invoice return reason code.
  --   'O' - Check if reason code is overage reason code.
  --   'M' - Check if reason code is mispick reason code.
  --   'W' - Check if reason code is OVI group reason code.
  --   'S' - Check if reason code is STM or MPK group reason code.
  --   'P' - Check if reason code is in the group that can create inv. planned.
  -- I_mispick_upc has the UPC # for scanned mispicked item (length of UPC).
  -- I_rtn_row has the return information that user wants to create or update.
  -- O_add_msgs contains additional messages sent back to the caller in addition
  --   to the o_status code. The value is enclosed with two '|'s, one at the
  --   beginning of the string and one at the end of the string if the value is
  --   not null. The maximum size for this string is 92 bytes (6 10-byte,
  --   1 30-byte and 2 bytes for '|'s. Each string section pads blanks in the
  --   right side. From byte 12 to 91, the value is optional depending on
  --   o_status. If no value, the 2nd '|' is always that last character for the
  --   string. It has the following values:
  --   NULL - Nothing to send back to caller or
  --   Byte 1: '|'
  --   Byte 2-11: miminum temperature (if o_status is TEMP_REQUIRED or
  --              TEMP_OUT_OF_RANGE), existed temperature (if o_status is
  --              TEMP_EXISTED), existed weight (if o_status is WEIGHT_EXISTED),
  --              location (if o_status is 0.)
  --   Byte 12-21:maximum temperature (if o_status is TEMP_REQUIRED or
  --              TEMP_OUT_OF_RANGE), license plate (if o_status is 0.)
  --   Byte 22-31:mispicked item # (if o_status is 0.)
  --   Byte 32-41:ti (if o_status is 0.)
  --   Byte 42-51:hi (if o_status is 0.)
  --   Byte 52-61:pallet type (if o_status is 0.)
  --   Byte 62-91:returned item description (if o_status is 0.)
  --   Byte 92-104  :invoice# (pickup or regular)
  --   Byte 105: '|'
  -- O_status has sqlcode or one of the following:
  --   ct_inv_prodid - if invoice item # is invalid.
  --   ct_invalid_disp - if disposition code is invalid.
  --   ct_invalid_invoice_no - if input invoice # not in alpha-numeric characters
  --   ct_invalid_mf - if manifest # is invalid or has been closed.
  --   ct_invalid_mspk - if mispicked item is invalid.
  --   ct_invalid_rsn - if reason code is invalid (from input i_which_group.)
  --   ct_mf_required - if no manifest # is entered.
  --   ct_mspk_required - if no mispicked item is entered.
  --   ct_no_mf_info - Manifest # is invalid or already closed.
  --   ct_not_splitable - Returned item is not splitable but return splits.
  --   ct_qty_required - Must have nonzero quantity
  --   ct_rsn_required - if no reason code is entered.
  --   ct_rtn_qtysum_gt_ship - if total returned quantity > shipped quantity.
  --   ct_ship_diff_uom - Returned uom is different from the shipped uom.
  --   ct_temp_existed - Temperature collected before for the item.
  --   ct_temp_invalid - if input temperature is not in alpha-numeric characters
  --   ct_temp_no_range - No min. and/or max. temperature is set.
  --   ct_temp_out_of_limit - Temperature is out of limit.
  --   ct_temp_required - Temperature is required for temperature tracked item.
  --   ct_weight_desired - Weight tracked item.
  --   ct_weight_existed - Weight has been entered previously.
  --   ct_weight_out_of_range - Weight is out of limit for weight tracked item.
  PROCEDURE p_create_rtn_info(
      i_rf_option   IN VARCHAR2,
      i_which_group IN VARCHAR2,
      i_mispick_upc IN pm.external_upc%TYPE,
      i_rtn_row     IN returns%ROWTYPE,
      PALLET_ID_LEN IN NUMBER,
      o_add_msgs OUT VARCHAR2,
      o_status OUT NUMBER);
  ------------------------------------------------------------------------
  -- Function:
  --    p_client_get_reasons
  --
  -- Description:
  --    Retrieve return related reason code information such as what group the
  --    reason code belongs to, the reason code and its descriptions. The function
  --    calls p_get_reasons() to do the actual processing. This function is mainly
  --    used by any caller that cannot handle PL/SQL table type.
  --
  -- Parameters:
  --    piCurPg (input)
  --      Current page # on client.
  --    piNumsPerPg (input)
  --      Number of lines per page can be displayed by the client. If the value
  --      is 0, it indicates that the function should retrieve all availble
  --      values that match the input criteria.
  --    poiNumRsns (output)
  --      The # of found reason codes; >= 0.
  --    poiNumFetchRows (output)
  --      The # of actually fetched records according to the input page index. The
  --      value should match the total count of the poszValues.
  --    poszValues (output)
  --      An array of reason code information to be returned. Each record includes
  --      type of reason(1) + reason code(REASON_CODE_LEN) + reason description
  --      (DESCRIP_LEN / 2).
  --    poszErrMsg (output)
  --      Error message if error occurred during reason code retrieval processing.
  --    poiStatus (output)
  --      0: The retrieval operation is ok.
  --      <> 0: Error happens during processing. poszErrMsg is set.
  --
  ------------------------------------------------------------------------
  PROCEDURE p_client_get_reasons(
      piCurPg     IN NUMBER,
      piNumsPerPg IN NUMBER,
      poiNumAllRsns OUT NUMBER,
      poiNumFetchRows OUT NUMBER,
      poszValues OUT ttabValues,
      poszErrMsg OUT VARCHAR2,
      poiStatus OUT NUMBER);
  ------------------------------------------------------------------------
  -- Function:
  --    p_get_reasons
  --
  -- Description:
  --    Retrieve return related reason code information such as what group the
  --    reason code belongs to, the reason code and its descriptions.
  --
  -- Parameters:
  --    poiNumRsns (output)
  --      The # of found reason codes; >= 0.
  --    poszValues (output)
  --      A table consists of related reason code information.
  --    poszErrMsg (output)
  --      Error message if error occurred during reason code retrieval processing.
  --    poiStatus (output)
  --      0: The retrieval operation is ok.
  --      <> 0: Error happens during processing. poszErrMsg is set.
  --
  ------------------------------------------------------------------------
  PROCEDURE p_get_reasons(
      poiNumRsns OUT NUMBER,
      poszRsns OUT ttabRtns,
      poszErrMsg OUT VARCHAR2,
      poiStatus OUT NUMBER);
  ------------------------------------------------------------------------
  -- Function:
  --    p_client_get_multi_items
  --
  -- Description:
  --    Retrieve item information such as item #, cust_pref_vendor and description
  --    for the input external UPC #. A valid UPC # can have 1 or more item #s
  --    in the Item Master. The function calls p_get_multi_items() to do the
  --    actual processing. This function is mainly used by any caller that cannot
  --    handle PL/SQL table type.
  --
  -- Parameters:
  --    pszMfNo (input)
  --      Manifest # used to do search
  --    pszUpc (input)
  --      UPC # used to do search
  --    piCurPg (input)
  --      Current page # on client.
  --    piNumsPerPg (input)
  --      Number of lines per page can be displayed by the client. If the value
  --      is 0, it indicates that the function should retrieve all availble
  --      values that match the input criteria.
  --    poiNumAllItems (output)
  --      The # of found all items according to the input UPC; >= 0.
  --    poiNumFetchRows (output)
  --      The # of actually fetched records according to the input page index. The
  --      value should match the total count of the poszValues.
  --    poszValues (output)
  --      An array of item information to be returned. Item info includes page
  --      line #, item #, cust_pref_vendor and abbrievated item description.
  --    poszErrMsg (output)
  --      Error message if error occurred during item retrieval processing.
  --    poiStatus (output)
  --      0: The retrieval operation is ok.
  --      ct_sql_no_data_found: UPC doesn't exists in database at all.
  --      ct_invalid_upc: UPC with 1 item # exists in database but no OPN
  --                      manifest has an item related to the UPC.
  --      <> 0: Error happens during processing. poszErrMsg is set.
  --
  ------------------------------------------------------------------------
  PROCEDURE p_client_get_multi_items(
      pszMfNo     IN VARCHAR2,
      pszUpc      IN pm.external_upc%TYPE,
      piCurPg     IN NUMBER,
      piNumsPerPg IN NUMBER,
      poiNumAllItems OUT NUMBER,
      poiNumFetchRows OUT NUMBER,
      poszValues OUT ttabValues,
      poszErrMsg OUT VARCHAR2,
      poiStatus OUT NUMBER);
  ------------------------------------------------------------------------
  -- Function:
  --    p_get_multi_items
  --
  -- Description:
  --    Retrieve item information such as item #, cust_pref_vendor and description
  --    for the input external UPC #. A valid UPC # can have 1 or more item #s
  --    in the Item Master.
  --
  -- Parameters:
  --    pszMfNo (input)
  --      Manifest # used to do search
  --    pszUpc (input)
  --      UPC # used to do search
  --    poiNumItems (output)
  --      The # of found items; >= 0.
  --    poszItems (output)
  --      A table consists of found item information.
  --    poszErrMsg (output)
  --      Error message if error occurred during item info retrieval processing.
  --    poiStatus (output)
  --      0: The retrieval operation is ok.
  --      ct_sql_no_data_found: UPC doesn't exists in database at all.
  --      ct_invalid_upc: UPC exists in database but no OPN manifest has an item
  --                      related to the UPC.
  --      <> 0: Error happens during processing. poszErrMsg is set.
  --
  ------------------------------------------------------------------------
  PROCEDURE p_get_multi_items(
      pszMfNo IN VARCHAR2,
      pszUpc  IN pm.external_upc%TYPE,
      poiNumItems OUT NUMBER,
      poszItems OUT ttabRtns,
      poszErrMsg OUT VARCHAR2,
      poiStatus OUT NUMBER);
  ------------------------------------------------------------------------
  -- Function:
  --    p_client_get_invs_list
  --
  -- Description:
  --    Retrieve invoice information such as invoice # and shipped uom for the
  --    input manifest # and item #/cust_pref_vendor. The function calls
  --    p_get_invs_list() to do the actual processing. This function is mainly
  --    used by any caller that cannot handle PL/SQL table type.
  --
  -- Parameters:
  --    pszMfNo (input)
  --      Manifest # used to do search
  --    pszItem (input)
  --      Item # used to do search
  --    pszCpv (input)
  --      Cust_pref_vendor used to do search
  --    piCurPg (input)
  --      Current page # on client.
  --    piNumsPerPg (input)
  --      Number of lines per page can be displayed by the client. If the value
  --      is 0, it indicates that the function should retrieve all availble
  --      values that match the input criteria.
  --    poiNumAllInvs (output)
  --      The # of found all invoices according to the input manifest #, item
  --      info; >= 0.
  --    poiNumFetchRows (output)
  --      The # of actually fetched records according to the input page index. The
  --      value should match the total count of the poszValues.
  --    poszValues (output)
  --      An array of invoice information to be returned. Invoide info includes
  --      page line #, invoice #, and shipped uom.
  --    poszErrMsg (output)
  --      Error message if error occurred during invoice info retrieval.
  --    poiStatus (output)
  --      0: The retrieval operation is ok.
  --      ct_invalid_upc: There is no invoice info matching the search criteria.
  --      ct_invalid_mf: Specified manifest # is not in the system.
  --      ct_mf_required: No manifest # is input.
  --      <> 0: Error happens during processing. poszErrMsg is set.
  --
  ------------------------------------------------------------------------
  PROCEDURE p_client_get_invs_list(
      pszMfNo     IN VARCHAR2,
      pszItem     IN pm.prod_id%TYPE,
      pszCpv      IN pm.cust_pref_vendor%TYPE,
      piCurPg     IN NUMBER,
      piNumsPerPg IN NUMBER,
      poiNumAllInvs OUT NUMBER,
      poiNumFetchRows OUT NUMBER,
      poszValues OUT ttabValues,
      poszErrMsg OUT VARCHAR2,
      poiStatus OUT NUMBER);
  ------------------------------------------------------------------------
  -- Function:
  --    p_get_invs_list
  --
  -- Description:
  --    Retrieve invoice information such as invoice # and shipped uom for the
  --    input manifest # and item #/cust_pref_vendor.
  --
  -- Parameters:
  --    pszMfNo (input)
  --      Manifest # used to do search
  --    pszItem (input)
  --      Item # used to do search
  --    pszCpv (input)
  --      Cust_pref_vendor used to do search
  --    poiNumInvs (output)
  --      The # of found invoices; >= 0.
  --    poszInvs (output)
  --      A table consists of found invoice information.
  --    poszErrMsg (output)
  --      Error message if error occurred during item info retrieval processing.
  --    poiStatus (output)
  --      0: The retrieval operation is ok.
  --      ct_invalid_upc: There is no invoice info matching the search criteria.
  --      ct_invalid_mf: Specified manifest # is not in the system.
  --      ct_mf_required: No manifest # is input.
  --      <> 0: Error happens during processing. poszErrMsg is set.
  --
  ------------------------------------------------------------------------
  PROCEDURE p_get_invs_list(
      pszMfNo IN VARCHAR2,
      pszItem IN pm.prod_id%TYPE,
      pszCpv  IN pm.cust_pref_vendor%TYPE,
      poiNumInvs OUT NUMBER,
      poszInvs OUT ttabRtns,
      poszErrMsg OUT VARCHAR2,
      poiStatus OUT NUMBER);
  ------------------------------------------------------------------------
  -- Function:
  --    p_get_mf_info
  --
  -- Description:
  --    Retrieve manifest header and detail information according to the inputs.
  --
  -- Parameters:
  --    pszRoute (input)
  --      Route # used to do search; can be empty
  --    piStop (input)
  --      Stop # used to do search; can be empty
  --    pszInvNo (input)
  --      Invoice # used to do search
  --    pszItem (input)
  --      Item # used to do search
  --    pszCpv (input)
  --      Cust_pref_vendor used to do search
  --    pszUom (input)
  --      Uom used to do search, either 0 or 1.
  --    poiMfNo (output)
  --      Manifest # to be returned if search criteria is met.
  --    pszRecType (output)
  --      Record type to be returned if search criteria is met; either I, O, P or
  --      D.
  --    poszErrMsg (output)
  --      Error message if error occurred during item info retrieval processing.
  --    poiStatus (output)
  --      0: The retrieval operation is ok.
  --      ct_no_mf_info: There is no manifest info matching the search criteria.
  --      ct_mf_has_closed: Found manifest has been closed.
  --      ct_manifest_pad: Found manifest is an order delete manifest.
  --      ct_rtn_qtysum_gt_ship: Found manifest info has returned qty >= shipped
  --        qty already.
  --      <> 0: Error happens during processing. poszErrMsg is set.
  --
  ------------------------------------------------------------------------
  PROCEDURE p_get_mf_info(
      pszRoute IN route.route_no%TYPE,
      piStop   IN manifest_dtls.stop_no%TYPE,
      pszInvNo IN manifest_dtls.obligation_no%TYPE,
      pszItem  IN pm.prod_id%TYPE,
      pszCpv   IN pm.cust_pref_vendor%TYPE,
      pszUom   IN manifest_dtls.shipped_split_cd%TYPE,
      poiMfNo OUT manifests.manifest_no%TYPE,
      poszRecType OUT manifest_dtls.rec_type%TYPE,
      poszErrMsg OUT VARCHAR2,
      poiStatus OUT NUMBER);
  ------------------------------------------------------------------------
  -- Function:
  --    p_client_get_rtn_info
  --
  -- Description:
  --    Retrieve return information such as invoice # and returned qty/uom for the
  --    input criteria. The function calls p_get_rtn_info() to do the actual
  --    processing. This function is mainly used by any caller that cannot handle
  --    PL/SQL table type.
  --
  -- Parameters:
  --    piMfNo (input)
  --      Manifest # used to do search
  --    pszInvNo (input)
  --      Invoice # used to do search
  --    pszRecType (input)
  --      Record type used to do search
  --    pszItem (input)
  --      Item # used to do search
  --    pszCpv (input)
  --      Cust_pref_vendor used to do search
  --    piLPLen(input)
  --      Pallet ID length, it can be either 10 or 18.
  --    piNumFixedLines (input)
  --      Number of fixed lines the client want to use on the 1st page of the
  --      display. For example, the client might want to display the 1st line
  --      as <1. New rtn>. So the line # from the database data should start at
  --      line #2 then.
  --    piCurPg (input)
  --      Current page # on client.
  --    piNumsPerPg (input)
  --      Number of lines per page can be displayed by the client. If the value
  --      is 0, it indicates that the function should retrieve all availble
  --      values that match the input criteria.
  --    poiNumAllRtns (output)
  --      The # of found all returns according to the input manifest #, invoice #,
  --  record_type, item info; >= 0.
  --    poiNumFetchRows (output)
  --      The # of actually fetched records according to the input page index. The
  --      value should match the total count of the poszValues.
  --    poszValues (output)
  --      An array of return information to be returned. Return info includes
  --      page line #, record type, invoice #, reason code, returned qty and uom,
  --  catchweight, temperature, disposition code, returned item, returned
  --  location/LP, item description, ti, hi, pallet_type, whether returned
  --  label has been printed, and pallet batch #.
  --    poszErrMsg (output)
  --      Error message if error occurred during invoice info retrieval.
  --    poiStatus (output)
  --      0: The retrieval operation is ok.
  --      ct_invalid_mf: Specified manifest # is not in the system.
  --      ct_no_mf_info: No manifest information is found.
  --      <> 0: Error happens during processing. poszErrMsg is set.
  --
  ------------------------------------------------------------------------
  PROCEDURE p_client_get_rtn_info(
      piMfNo          IN manifests.manifest_no%TYPE,
      pszInvNo        IN manifest_dtls.obligation_no%TYPE,
      pszRecType      IN manifest_dtls.rec_type%TYPE,
      pszItem         IN pm.prod_id%TYPE,
      pszCpv          IN pm.cust_pref_vendor%TYPE,
      piLPLen         IN NUMBER,
      piNumFixedLines IN NUMBER,
      piCurPg         IN NUMBER,
      piNumsPerPg     IN NUMBER,
      poiNumAllRtns OUT NUMBER,
      poiNumFetchRows OUT NUMBER,
      poszValues OUT ttabValues,
      poszErrMsg OUT VARCHAR2,
      poiStatus OUT NUMBER);
  ------------------------------------------------------------------------
  -- Function:
  --    p_get_rtn_info
  --
  -- Description:
  --    Retrieve return information such as invoice # and shipped qty/uom for the
  --    input criteria.
  --
  -- Parameters:
  --    piMfNo (input)
  --      Manifest # used to do search
  --    pszInvNo (input)
  --      Invoice # used to do search
  --    pszRecType (input)
  --      Record type used to do search
  --    pszItem (input)
  --      Item # used to do search
  --    pszCpv (input)
  --      Cust_pref_vendor used to do search
  --    poiNumAllRtns (output)
  --      The # of found returns; >= 0.
  --    poszRtns (output)
  --      A table consists of found return information.
  --    poszErrMsg (output)
  --      Error message if error occurred during item info retrieval processing.
  --    poiStatus (output)
  --      0: The retrieval operation is ok.
  --      ct_invalid_mf: Specified manifest # is not in the system.
  --      ct_no_mf_info: No manifest information is found.
  --      <> 0: Error happens during processing. poszErrMsg is set.
  --
  ------------------------------------------------------------------------
  PROCEDURE p_get_rtn_info(
      piMfNo     IN manifests.manifest_no%TYPE,
      pszInvNo   IN manifest_dtls.obligation_no%TYPE,
      pszRecType IN manifest_dtls.rec_type%TYPE,
      pszItem    IN pm.prod_id%TYPE,
      pszCpv     IN pm.cust_pref_vendor%TYPE,
      poiNumAllRtns OUT NUMBER,
      poszRtns OUT ttabRtns,
      poszErrMsg OUT VARCHAR2,
      poiStatus OUT NUMBER);
  ------------------------------------------------------------------------
  -- Function:
  --    p_get_order_seq_info
  --
  -- Description:
  --    Retrieve order sequence information such as route #, stop #, invoice #,
  --    item info and shipped uom for the input criteria.
  --
  -- Parameters:
  --    pszSeqNum (input)
  --      Order sequence # used to do search
  --    poszSeqInfo(output)
  --      An output string consists of route #, stop #, invoice #, item info and
  --      shipped uom concatining together in system-defined length.
  --    poszErrMsg (output)
  --      Error message if error occurred during item info retrieval processing.
  --    poiStatus (output)
  --      0: The retrieval operation is ok.
  --      ct_invalid_mf: Specified manifest # is not in the system.
  --      ct_no_mf_info: No manifest information is found.
  --      <> 0: Error happens during processing. poszErrMsg is set.
  --
  ------------------------------------------------------------------------
  PROCEDURE p_get_order_seq_info(
      pszSeqNum IN VARCHAR2,
      poszSeqInfo OUT VARCHAR2,
      poszErrMsg OUT VARCHAR2,
      poiStatus OUT NUMBER);
  ------------------------------------------------------------------------
  -- Function:
  --    p_client_get_ovr_info
  --
  -- Description:
  --    Retrieve overage return information such as manifest #, invoice # and
  --    returned qty/uom for the input criteria. The function calls
  --    p_get_ovr_rtn_info() to do the actual processing. This function is mainly
  --     used by any caller that cannot handle PL/SQL table type.
  --
  -- Parameters:
  --    piMfNo (input)
  --      Manifest # used to do search
  --    pszItem (input)
  --      Item # used to do search
  --    pszCpv (input)
  --      Cust_pref_vendor used to do search
  --    piLPLen(input)
  --      Pallet ID length, it can be either 10 or 18.
  --    piNumFixedLines (input)
  --      Number of fixed lines the client want to use on the 1st page of the
  --      display. For example, the client might want to display the 1st line
  --      as <1. New ovr>. So the line # from the database data should start at
  --      line #2 then.
  --    piCurPg (input)
  --      Current page # on client.
  --    piNumsPerPg (input)
  --      Number of lines per page can be displayed by the client. If the value
  --      is 0, it indicates that the function should retrieve all availble
  --      values that match the input criteria.
  --    poiNumAllOvrs (output)
  --      The # of found all returns according to the input manifest # and item
  --  info; >= 0.
  --    poiNumFetchRows (output)
  --      The # of actually fetched records according to the input page index. The
  --      value should match the total count of the poszValues.
  --    poszValues (output)
  --      An array of return information to be returned. Return info includes
  --      page line #, record type, invoice #, reason code, returned qty and uom,
  --  catchweight, temperature, disposition code, returned item, returned
  --  location/LP, item description, ti, hi, pallet_type, whether returned
  --  label has been printed, and pallet batch #.
  --    poszErrMsg (output)
  --      Error message if error occurred during invoice info retrieval.
  --    poiStatus (output)
  --      0: The retrieval operation is ok.
  --      ct_invalid_mf: Specified manifest # is not in the system.
  --      <> 0: Error happens during processing. poszErrMsg is set.
  --
  ------------------------------------------------------------------------
  PROCEDURE p_client_get_ovr_info(
      piMfNo          IN manifests.manifest_no%TYPE,
      pszItem         IN pm.prod_id%TYPE,
      pszCpv          IN pm.cust_pref_vendor%TYPE,
      piLPLen         IN NUMBER,
      piNumFixedLines IN NUMBER,
      piCurPg         IN NUMBER,
      piNumsPerPg     IN NUMBER,
      poiNumAllOvrs OUT NUMBER,
      poiNumFetchRows OUT NUMBER,
      poszValues OUT ttabValues,
      poszErrMsg OUT VARCHAR2,
      poiStatus OUT NUMBER);
  ------------------------------------------------------------------------
  -- Function:
  --    p_get_ovr_rtn_info
  --
  -- Description:
  --    Retrieve overage return information such as manifest #, item info,
  --    returned qty, reason code, and invoice # for the input criteria.
  --
  -- Parameters:
  --    piMfNo (input)
  --      Manifest # used to do search
  --    pszItem (input)
  --      Item # used to do search
  --    pszCpv (input)
  --      Cust_pref_vendor used to do search
  --    poiNumAllOvrs (output)
  --      The # of found overage returns; >= 0.
  --    poszOvrs (output)
  --      A table consists of found overage return information.
  --    poszErrMsg (output)
  --      Error message if error occurred during item info retrieval processing.
  --    poiStatus (output)
  --      0: The retrieval operation is ok.
  --      ct_invalid_mf: Specified manifest # is not in the system.
  --      <> 0: Error happens during processing. poszErrMsg is set.
  --
  ------------------------------------------------------------------------
  PROCEDURE p_get_ovr_rtn_info(
      piMfNo  IN manifests.manifest_no%TYPE,
      pszItem IN pm.prod_id%TYPE,
      pszCpv  IN pm.cust_pref_vendor%TYPE,
      poiNumAllOvrs OUT NUMBER,
      poszOvrs OUT ttabRtns,
      poszErrMsg OUT VARCHAR2,
      poiStatus OUT NUMBER);
  ------------------------------------------------------------------------
  -- Function:
  --    p_client_get_mspk_info
  --
  -- Description:
  --    Retrieve mispick return information such as manifest #, invoice # and
  --    returned qty/uom for the input criteria. The function calls
  --    p_get_mspk_info() to do the actual processing. This function is mainly
  --     used by any caller that cannot handle PL/SQL table type.
  --
  -- Parameters:
  --    piMfNo (input)
  --      Manifest # used to do search
  --    pszInvNo (input)
  --      Invoice # used to do search
  --    pszItem (input)
  --      Item # used to do search
  --    pszCpv (input)
  --      Cust_pref_vendor used to do search
  --    piLPLen(input)
  --      Pallet ID length, it can be either 10 or 18.
  --    piNumFixedLines (input)
  --      Number of fixed lines the client want to use on the 1st page of the
  --      display. For example, the client might want to display the 1st line
  --      as <1. New ovr>. So the line # from the database data should start at
  --      line #2 then.
  --    piCurPg (input)
  --      Current page # on client.
  --    piNumsPerPg (input)
  --      Number of lines per page can be displayed by the client. If the value
  --      is 0, it indicates that the function should retrieve all availble
  --      values that match the input criteria.
  --    poiNumAllMspks (output)
  --      The # of found all returns according to the input manifest # and item
  --  info; >= 0.
  --    poiNumFetchRows (output)
  --      The # of actually fetched records according to the input page index. The
  --      value should match the total count of the poszValues.
  --    poszValues (output)
  --      An array of return information to be returned. Return info includes
  --      page line #, record type, invoice #, reason code, returned qty and uom,
  --  catchweight, temperature, disposition code, returned item, returned
  --  location/LP, item description, ti, hi, pallet_type, whether returned
  --  label has been printed, and pallet batch #.
  --    poszErrMsg (output)
  --      Error message if error occurred during invoice info retrieval.
  --    poiStatus (output)
  --      0: The retrieval operation is ok.
  --      ct_invalid_mf: Specified manifest # is not in the system.
  --      <> 0: Error happens during processing. poszErrMsg is set.
  --
  ------------------------------------------------------------------------
  PROCEDURE p_client_get_mspk_info(
      piMfNo          IN manifests.manifest_no%TYPE,
      pszInvNo        IN manifest_dtls.obligation_no%TYPE,
      pszItem         IN pm.prod_id%TYPE,
      pszCpv          IN pm.cust_pref_vendor%TYPE,
      piLPLen         IN NUMBER,
      piNumFixedLines IN NUMBER,
      piCurPg         IN NUMBER,
      piNumsPerPg     IN NUMBER,
      poiNumAllMspks OUT NUMBER,
      poiNumFetchRows OUT NUMBER,
      poszValues OUT ttabValues,
      poszErrMsg OUT VARCHAR2,
      poiStatus OUT NUMBER);
  ------------------------------------------------------------------------
  -- Function:
  --    p_get_mspk_info
  --
  -- Description:
  --    Retrieve mispick return information such as manifest #, item info,
  --    returned qty, reason code, and invoice # for the input criteria.
  --
  -- Parameters:
  --    piMfNo (input)
  --      Manifest # used to do search
  --    pszInvNo (input)
  --      Invoice # used to do search
  --    pszItem (input)
  --      Item # used to do search
  --    pszCpv (input)
  --      Cust_pref_vendor used to do search
  --    poiNumAllMspks (output)
  --      The # of found mispick returns; >= 0.
  --    poszMspks (output)
  --      A table consists of found mispick return information.
  --    poszErrMsg (output)
  --      Error message if error occurred during item info retrieval processing.
  --    poiStatus (output)
  --      0: The retrieval operation is ok.
  --      ct_invalid_mf: Specified manifest # is not in the system.
  --      <> 0: Error happens during processing. poszErrMsg is set.
  --
  ------------------------------------------------------------------------
  PROCEDURE p_get_mspk_info(
      piMfNo   IN manifests.manifest_no%TYPE,
      pszInvNo IN manifest_dtls.obligation_no%TYPE,
      pszItem  IN pm.prod_id%TYPE,
      pszCpv   IN pm.cust_pref_vendor%TYPE,
      poiNumAllMspks OUT NUMBER,
      poszMspks OUT ttabRtns,
      poszErrMsg OUT VARCHAR2,
      poiStatus OUT NUMBER);
  ---------------------------------------------------------------------------
  -- Function:
  --    p_Dlt_Damaged_Putaway_ERMD
  --
  -- Description:
  --    Delete putaway, erd, erm data for Damaged Items(Dest_LOc = 'DDDDDDD'
  --    This process is called when manifest is closed
  --
  -- Parameters:
  --    p_mnfst_id (input)
  --      Manifest # used to do do the deltetes in the 3 tables mentioned above
  --
  ------------------------------------------------------------------------------
  PROCEDURE P_Dlt_Damaged_Putaway_ERMD(
      p_mnfst_id IN manifests.manifest_no%TYPE) ;
END pl_rtn_dtls;
/
CREATE OR REPLACE PACKAGE BODY swms.pl_rtn_dtls
AS
  -- This package body is used to do returns detail processing. Mainly use by RF.
  /*********************************
  Private Variables
  *********************************/
  ct_temp_existed_no_msg NUMBER(6)   := -20001;
  MAX_KIND               NUMBER(3)   := 999;
  CPV_LEN                NUMBER(3)   := 10;
  DESCRIP_LEN            NUMBER(3)   := 30;
  INV_NO_LEN             NUMBER(3)   := 14;
  LINE_ID_LEN            NUMBER(1)   := 4;
  LINE_NO_LEN            NUMBER(3)   := 3;
  LOC_LEN                NUMBER(2)   := 10;
  MF_NO_LEN              NUMBER(1)   := 7;
  ONE_LEN                NUMBER(1)   := 1;
  PAL_TYPE_LEN           NUMBER(1)   := 2;
  PALLET_ID_LEN          NUMBER(2)   := 18;
  PROD_ID_LEN            NUMBER(3)   := 9;
  QTY_LEN                NUMBER(1)   := 4;
  REC_TYPE_LEN           NUMBER(1)   := 1;
  REASON_CODE_LEN        NUMBER(3)   := 3;
  ROUTE_NO_LEN           NUMBER(2)   := 10;
  STOP_NO_LEN            NUMBER(1)   := 7;
  TBATCH_LEN             NUMBER(2)   := 13;
  TEMP_LEN               NUMBER(1)   := 5;
  TIHI_LEN               NUMBER(1)   := 4;
  UOM_LEN                NUMBER(1)   := 1;
  UPC_LEN                NUMBER(2)   := 14;
  WEIGHT_LEN             NUMBER(1)   := 9;
  DFT_CPV                VARCHAR2(1) := '-';
  /*********************************
  Private Functions and Procedures
  *********************************/
  -- Check if the input manifest # is in one of the specified status code or not.
  -- Valid piStatusType is 0 for manifest exists (default), 1 for OPN, 2 for PAD
  -- or 2 for CLS.
  -- Return 0 if the checking matches the criteria or ct_invalid_mf otherwise.
  FUNCTION check_mf_no(
      pszMfNo      IN VARCHAR2,
      piStatusType IN NUMBER DEFAULT 0)
    RETURN NUMBER
  IS
    iStatus NUMBER := ct_sql_success;
    iExists NUMBER := 0;
  BEGIN
    -- Check if input manifest # is valid
    SELECT 1
    INTO iExists
    FROM manifests
    WHERE manifest_no    = TO_NUMBER(pszMfNo)
    AND ((piStatusType   = 0)
    OR ((piStatusType    = 1)
    AND (manifest_status = 'OPN'))
    OR ((piStatusType    = 2)
    AND (manifest_status = 'PAD'))
    OR ((piStatusType    = 3)
    AND (manifest_status = 'CLS')));
    RETURN ct_sql_success;
  EXCEPTION
  WHEN OTHERS THEN
    RETURN ct_invalid_mf;
  END;
-- Check if the input reason code (i_reason_code) is valid or not according to
-- the input return type (i_return_type.)
-- I_return_type has one of the following values:
--   'A' - Check all reason codes in "RTN" type.
--   'I' - Check all reason codes is in "RTN" type other than overage codes.
--   'V' - Check if reason code is invoice return reason code.
--   'O' - Check if reason code is overage reason code.
--   'M' - Check if reason code is mispick reason code.
--   'W' - Check if reason code is OVI group reason code.
--   'S' - Check if reason code is STM or MPK group reason code.
--   'P' - Check if reason code is in the group that can create inv. planned.
-- O_misc has the misc value returned if the reason code is valid.
-- O_valid has one of the following values:
--   0 - not valid
--   1 - valid
-- O_status has sqlcode.
  PROCEDURE p_check_valid_reason(
      i_return_type IN VARCHAR2,
      i_reason_code IN reason_cds.reason_cd%TYPE,
      o_misc OUT reason_cds.misc%TYPE,
      o_reason_group OUT reason_cds.reason_group%TYPE,
      o_valid OUT NUMBER,
      o_status OUT NUMBER)
  IS
    l_return_type VARCHAR2(1)               := UPPER(i_return_type);
    l_reason_code reason_cds.reason_cd%TYPE := UPPER(i_reason_code);
    l_reason_type reason_cds.reason_cd_type%TYPE;
    CURSOR c_get_reasons (cp_type VARCHAR2, cp_cd_type VARCHAR2, cp_reason VARCHAR2)
    IS
      SELECT misc,
        reason_group
      FROM reason_cds
      WHERE reason_cd_type = cp_cd_type
      AND reason_cd        = cp_reason
      AND (((cp_type       = 'D')
      AND (reason_group    = 'DIS'))
      OR (cp_type          = 'A')
      OR ((cp_type         = 'I')
      AND (reason_group   <> 'OVR'))
      OR ((cp_type         = 'V')
      AND (reason_group    = 'WIN'))
      OR ((cp_type         = 'O')
      AND (reason_group    = 'OVR'))
      OR ((cp_type         = 'M')
      AND (reason_group   IN ('MPR', 'MPK')))
      OR ((cp_type         = 'W')
      AND (reason_group    = 'OVI'))
      OR ((cp_type         = 'S')
      AND (reason_group   IN ('STM', 'MPK')))
      OR ((cp_type         = 'P')
      AND (reason_group   IN ('NOR', 'WIN'))));
  BEGIN
    dbms_output.put_line('Enter 1p_check_valid_reason[' || l_return_type || ']');
    o_misc         := NULL;
    o_reason_group := 'XXX';
    o_valid        := 1;
    o_status       := ct_sql_success;
    dbms_output.put_line('Enter p_check_valid_reason[' || l_return_type || ']');
    IF l_return_type = 'D' THEN
      l_reason_type := 'DIS';
    ELSE
      l_reason_type := 'RTN';
    END IF;
    dbms_output.put_line('Ready to get reason info typ[' || i_return_type || '] code[' || l_reason_code || ']');
    OPEN c_get_reasons(i_return_type, l_reason_type, l_reason_code);
    FETCH c_get_reasons INTO o_misc, o_reason_group;
    IF c_get_reasons%NOTFOUND THEN
      dbms_output.put_line('Not found reason');
      o_misc         := NULL;
      o_reason_group := 'XXX';
      o_valid        := 0;
      o_status       := ct_sql_no_data_found;
    END IF;
    CLOSE c_get_reasons;
  END;
-- Convert input quantity to split quantity for input item.
-- O_status has sqlcode.
  PROCEDURE p_convert_qty_to_splits(
      i_prod_id  IN pm.prod_id%TYPE,
      i_cpv      IN pm.cust_pref_vendor%TYPE,
      i_orig_qty IN NUMBER,
      i_uom      IN returns.returned_split_cd%TYPE,
      o_new_split_qty OUT NUMBER,
      o_status OUT NUMBER)
  IS
    l_spc pm.spc%TYPE;
  BEGIN
    o_status        := ct_sql_success;
    o_new_split_qty := NVL(i_orig_qty, 0);
    IF i_uom        <> '1' THEN
      BEGIN
        SELECT NVL(spc, 0)
        INTO l_spc
        FROM pm
        WHERE prod_id        = i_prod_id
        AND cust_pref_vendor = i_cpv;
        o_new_split_qty     := NVL(i_orig_qty, 0) * l_spc;
      EXCEPTION
      WHEN OTHERS THEN
        o_new_split_qty := 0;
        o_status        := SQLCODE;
      END;
    END IF;
  END;
-- procedure p_get_location
-- change history
-- Date     By      Desc
-- 8/16/06  hqb     Reset o_status after checking for mini-load bound so others
--                  don't use the wrong status
  PROCEDURE p_get_location(
      i_mf_no   IN returns.manifest_no%TYPE,
      i_prod_id IN returns.prod_id%TYPE,
      i_cpv     IN returns.cust_pref_vendor%TYPE,
      i_uom     IN returns.returned_split_cd%TYPE,
      o_loc OUT putawaylst.dest_loc%TYPE,
      o_is_float OUT NUMBER,
      o_abc OUT pm.abc%TYPE,
      o_case_cube OUT pm.case_cube%TYPE,
      o_skid_cube OUT pallet_type.skid_cube%TYPE,
      o_status OUT NUMBER)
  IS
    iUOM loc.uom%TYPE                       := TO_NUMBER(i_uom);
    l_uom loc.uom%TYPE                      := TO_NUMBER(i_uom);
    l_loc putawaylst.dest_loc%TYPE          := NULL;
    l_pallet putawaylst.pallet_id%TYPE      := NULL;
    l_abc pm.abc%TYPE                       := NULL;
    l_case_cube pm.case_cube%TYPE           := NULL;
    l_existed NUMBER(1)                     := 0;
    l_zone_id pm.zone_id%TYPE               := NULL;
    l_paltype pm.pallet_type%TYPE           := NULL;
    l_last_ship_slot pm.last_ship_slot%TYPE := NULL;
    l_skid_cube pallet_type.skid_cube%TYPE  := NULL;
    l_old_paltype pm.pallet_type%TYPE       := NULL;
    l_trans_rec trans%ROWTYPE               := NULL;
    l_pik_path loc.pik_path%TYPE            := NULL;
    l_near_pik_path loc.pik_path%TYPE       := NULL;
    l_process_err_row process_error%ROWTYPE := NULL;
    l_status            NUMBER(4)                      := ct_sql_success;
    e_no_location_found EXCEPTION;
    --New Cursor for Matrix location
    CURSOR c_mx_loc
    IS
      SELECT p.abc,
        p.case_cube
      FROM pm p
      WHERE p.prod_id        = i_prod_id
      AND p.cust_pref_vendor = i_cpv;
    CURSOR c_get_home_loc(cp_uom NUMBER)
    IS
      SELECT logi_loc
      FROM loc
      WHERE prod_id        = i_prod_id
      AND cust_pref_vendor = i_cpv
      AND NVL(uom, 0)     IN (0, 2 - cp_uom)
      AND perm             = 'Y'
      AND rank             = 1;
    CURSOR c_get_inv_locs
    IS
      SELECT NVL(i.plogi_loc, 'FFFFFF'),
        p.abc,
        p.case_cube
      FROM zone z,
        inv i,
        pm p
      WHERE i.prod_id        = i_prod_id
      AND i.cust_pref_vendor = i_cpv
      AND i.prod_id          = p.prod_id
      AND i.status           = 'AVL'
      AND i.cust_pref_vendor = p.cust_pref_vendor
      AND NOT EXISTS
        (SELECT 'x' FROM loc WHERE prod_id = i_prod_id AND cust_pref_vendor = i_cpv
        )
    AND z.zone_id             = p.zone_id
    AND z.zone_type           = 'PUT'
    AND z.rule_id             = 1
    AND i.qoh + i.qty_planned > 0
    ORDER BY i.exp_date,
      i.qoh,
      i.logi_loc;
    CURSOR c_has_diff_item (cp_loc VARCHAR2, cp_prod_id VARCHAR2, cp_cpv VARCHAR2)
    IS
      SELECT 1
      FROM inv
      WHERE plogi_loc      = cp_loc
      AND cust_pref_vendor = cp_cpv
      AND status           = 'AVL'
      AND prod_id         <> cp_prod_id;
    CURSOR c_get_put_zone
    IS
      SELECT p.zone_id,
        p.pallet_type,
        NVL(p.last_ship_slot, 'FFFFFF'),
        p.abc,
        p.case_cube,
        pa.skid_cube
      FROM pallet_type pa,
        zone z,
        pm p
      WHERE p.prod_id        = i_prod_id
      AND p.cust_pref_vendor = i_cpv
      AND p.zone_id          = z.zone_id
      AND z.zone_type        = 'PUT'
      AND z.rule_id         IN (1,3) -- hqb must allow mini loader zone
      AND p.pallet_type      = pa.pallet_type;
    CURSOR c_get_empty_float_same_paltype (cp_zone_id VARCHAR2, cp_paltype VARCHAR2)
    IS
      SELECT l.logi_loc
      FROM loc l,
        lzone lz
      WHERE lz.zone_id  = cp_zone_id
      AND lz.logi_loc   = l.logi_loc
      AND l.status      = 'AVL'
      AND l.pallet_type = cp_paltype
      AND NOT EXISTS
        (SELECT NULL FROM inv WHERE plogi_loc = l.logi_loc
        );
    CURSOR c_get_empty_float_diff_paltype (cp_zone_id VARCHAR2)
    IS
      SELECT l.logi_loc,
        l.pallet_type
      FROM loc l,
        lzone lz
      WHERE lz.zone_id = cp_zone_id
      AND lz.logi_loc  = l.logi_loc
      AND l.status     = 'AVL'
      AND NOT EXISTS
        (SELECT NULL FROM inv WHERE plogi_loc = l.logi_loc
        );
    CURSOR c_get_pik_path (cp_slot VARCHAR2)
    IS
      SELECT NVL(pik_path, 9999999999)
      FROM loc
      WHERE logi_loc = cp_slot
      AND status     = 'AVL'
      AND prod_id   IS NULL
      AND NOT EXISTS
        (SELECT 'x' FROM inv WHERE plogi_loc = cp_slot AND prod_id <> i_prod_id
        );
    CURSOR c_get_float_ecube_same_paltyp (cp_zone_id VARCHAR2, cp_paltype VARCHAR2, cp_slot VARCHAR2, cp_pik_path NUMBER)
    IS
      SELECT l.logi_loc,
        l.pik_path - cp_pik_path
      FROM loc l,
        lzone lz
      WHERE lz.zone_id  = cp_zone_id
      AND lz.logi_loc   = l.logi_loc
      AND l.status      = 'AVL'
      AND l.pallet_type = cp_paltype
      AND l.cube       >=
        (SELECT NVL(cube, 0) FROM loc WHERE logi_loc = cp_slot
        )
    AND NOT EXISTS
      (SELECT NULL FROM inv WHERE plogi_loc = l.logi_loc
      )
    ORDER BY 2;
    CURSOR c_get_empty_float_enough_cube (cp_zone_id VARCHAR2, cp_slot VARCHAR2, cp_pik_path NUMBER)
    IS
      SELECT l.logi_loc,
        l.pallet_type,
        l.pik_path - cp_pik_path
      FROM loc l,
        lzone lz
      WHERE lz.zone_id = cp_zone_id
      AND lz.logi_loc  = l.logi_loc
      AND l.status     = 'AVL'
      AND l.cube      >=
        (SELECT NVL(cube, 0) FROM loc WHERE logi_loc = cp_slot
        )
    AND NOT EXISTS
      (SELECT NULL FROM inv WHERE plogi_loc = l.logi_loc
      )
    ORDER BY 3;
  BEGIN
    o_status    := ct_sql_success;
    o_loc       := NULL;
    o_abc       := NULL;
    o_case_cube := NULL;
    o_skid_cube := NULL;
    o_is_float  := 0;
    -- First check if item is induction location bound
    IF (iUOM != 1) THEN
      iUOM   := 2;
    END IF;
    ---Matrix Change Start---
    IF pl_matrix_common.chk_matrix_enable               = TRUE AND iUOM = 2 THEN
      IF pl_matrix_common.chk_prod_mx_assign(i_prod_id) = TRUE AND pl_matrix_common.chk_prod_mx_eligible(i_prod_id) = TRUE THEN
        OPEN c_mx_loc;
        FETCH c_mx_loc INTO l_abc, l_case_cube;
        IF c_mx_loc%FOUND THEN
          o_is_float  := 1;
          o_abc       := l_abc;
          o_case_cube := l_case_cube;
          o_loc       := NVL(pl_matrix_common.f_get_mx_dest_loc(i_prod_id), '*');
          CLOSE c_mx_loc;
          RETURN;
        END IF;
      END IF;
    END IF;
    ---Matrix Change End---
    pl_ml_common.get_induction_loc( i_prod_id, i_cpv, iUOM, o_status, o_loc);
    IF (o_status   = ct_sql_success) THEN
      o_is_float  := 1;
      o_abc       := 'A';
      o_case_cube := 1;
      o_skid_cube := 1;
      RETURN;
    ELSIF (o_status = ct_sql_no_data_found) THEN
      o_status     := ct_sql_success;
    ELSE
      RETURN;
    END IF;
    -- Search from home slot.
    OPEN c_get_home_loc(l_uom);
    FETCH c_get_home_loc INTO l_loc;
    IF c_get_home_loc%FOUND THEN
      o_loc := l_loc;
      CLOSE c_get_home_loc;
      RETURN;
    END IF;
    CLOSE c_get_home_loc;
    -- Home slot is not found. Search from existing floating slot inventory that
    -- will expire first and has least qoh.
    OPEN c_get_inv_locs;
    FETCH c_get_inv_locs INTO l_loc, l_abc, l_case_cube;
    IF c_get_inv_locs%FOUND THEN
      o_is_float := 1;
      OPEN c_has_diff_item(l_loc, i_prod_id, i_cpv);
      FETCH c_has_diff_item INTO l_existed;
      IF c_has_diff_item%NOTFOUND THEN
        -- Existing same-item floating slot inventory is found
        o_abc       := l_abc;
        o_case_cube := l_case_cube;
        o_loc       := l_loc;
        CLOSE c_has_diff_item;
        CLOSE c_get_inv_locs;
        RETURN;
      END IF;
      CLOSE c_has_diff_item;
    END IF;
    CLOSE c_get_inv_locs;
    -- No home slot and no existing floating slot inventory or the existing
    -- floating slot has different item.
    -- Search from item's floating put zone.
    OPEN c_get_put_zone;
    FETCH c_get_put_zone
    INTO l_zone_id,
      l_paltype,
      l_last_ship_slot,
      l_abc,
      l_case_cube,
      l_skid_cube;
    IF c_get_put_zone%NOTFOUND THEN
      -- No previous float zone is found. '*' out the location.
      CLOSE c_get_put_zone;
      o_status := ct_sql_no_data_found;
      RAISE e_no_location_found;
    END IF;
    CLOSE c_get_put_zone;
    -- Previous float zone is found and there is a last ship slot.
    -- Check if the last ship slot already had different item occupied.
    o_is_float          := 1;
    IF l_last_ship_slot <> 'FFFFFF' THEN
      OPEN c_has_diff_item(l_last_ship_slot, i_prod_id, i_cpv);
      FETCH c_has_diff_item INTO l_existed;
      IF c_has_diff_item%FOUND THEN
        -- Different item is in the last ship slot. Need to find a new slot.
        l_last_ship_slot := 'FFFFFF';
      END IF;
      CLOSE c_has_diff_item;
    END IF;
    -- Save the found pallet type to be used to find another floating slot.
    l_old_paltype := l_paltype;
    -- Float zone is found but there is no last ship slot.
    IF l_last_ship_slot = 'FFFFFF' THEN
      OPEN c_get_empty_float_same_paltype(l_zone_id, l_paltype);
      FETCH c_get_empty_float_same_paltype INTO l_loc;
      IF c_get_empty_float_same_paltype%FOUND THEN
        -- Found an open slot in the same zone with the same pallet type. Update
        -- with the latest found floating slot.
        BEGIN
          UPDATE pm
          SET last_ship_slot   = l_loc
          WHERE prod_id        = i_prod_id
          AND cust_pref_vendor = i_cpv;
        EXCEPTION
        WHEN NO_DATA_FOUND THEN
          NULL;
        WHEN OTHERS THEN
          o_status := SQLCODE;
          RAISE e_no_location_found;
        END;
        CLOSE c_get_empty_float_same_paltype;
        o_loc       := l_loc;
        o_abc       := l_abc;
        o_case_cube := l_case_cube;
        o_skid_cube := l_skid_cube;
        RETURN;
      END IF;
      CLOSE c_get_empty_float_same_paltype;
      -- No open floating slot with same pallet type is found. Check open slot
      -- of same zone but different pallet type.
      OPEN c_get_empty_float_diff_paltype(l_zone_id);
      FETCH c_get_empty_float_diff_paltype INTO l_loc, l_paltype;
      IF c_get_empty_float_diff_paltype%NOTFOUND THEN
        -- No open slot of the same zone but different pallet type is found.
        -- '*' out the location.
        CLOSE c_get_empty_float_diff_paltype;
        o_status := ct_sql_no_data_found;
        RAISE e_no_location_found;
      END IF;
      CLOSE c_get_empty_float_diff_paltype;
      -- Get the skid cube for the new palle type.
      IF NVL(l_old_paltype, ' ') <> NVL(l_paltype, ' ') THEN
        BEGIN
          SELECT skid_cube
          INTO l_skid_cube
          FROM pallet_type
          WHERE pallet_type = l_paltype;
        EXCEPTION
        WHEN NO_DATA_FOUND THEN
          l_skid_cube := 0;
        WHEN OTHERS THEN
          o_status := SQLCODE;
          RAISE e_no_location_found;
        END;
      END IF;
      -- Found an open floating slot of the same zone but different pallet type.
      -- Update with the latest found floating slot and pallet type.
      BEGIN
        UPDATE pm
        SET last_ship_slot   = l_loc,
          pallet_type        = l_paltype
        WHERE prod_id        = i_prod_id
        AND cust_pref_vendor = i_cpv;
      EXCEPTION
      WHEN NO_DATA_FOUND THEN
        NULL;
      WHEN OTHERS THEN
        o_status := SQLCODE;
        RAISE e_no_location_found;
      END;
      -- Insert transaction record for last ship date or pallet type changes.
      l_trans_rec                                    := NULL;
      IF NVL(gRcTypSyspar.upd_item_ptype_return, 'N') = 'Y' AND NVL(l_old_paltype, ' ') <> NVL(l_paltype, ' ') THEN
        l_trans_rec.trans_type                       := 'IMT';
        l_trans_rec.rec_id                           := TO_CHAR(i_mf_no);
        l_trans_rec.user_id                          := USER;
        l_trans_rec.prod_id                          := i_prod_id;
        l_trans_rec.cust_pref_vendor                 := i_cpv;
        l_trans_rec.upload_time                      := NULL;
        l_trans_rec.dest_loc                         := l_loc;
        l_trans_rec.cmt                              := 'RTNSDTL: Old pallet type: ' || l_old_paltype || ', New pallet type: ' || l_paltype;
        l_status                                     := pl_common.f_create_trans(l_trans_rec, 'na');
        IF l_status                                  <> ct_sql_success THEN
          o_status                                   := l_status;
          RAISE e_no_location_found;
        END IF;
      END IF;
      -- Send LM apcom for pallet type change
      l_process_err_row.value_1   := TO_CHAR(i_mf_no);
      l_process_err_row.value_2   := l_paltype;
      l_process_err_row.error_msg := RPAD(i_prod_id, 9) || i_cpv;
      l_status                    := f_save_apcom_lm (l_process_err_row);
      IF l_status                 <> ct_sql_success THEN
        o_status                  := l_status;
        RAISE e_no_location_found;
      END IF;
      o_loc       := l_loc;
      o_abc       := l_abc;
      o_case_cube := l_case_cube;
      o_skid_cube := l_skid_cube;
      RETURN;
    END IF;
    -- Found float zone and last ship slot on 1st try.
    -- Get last ship slot pik path.
    OPEN c_get_pik_path(l_last_ship_slot);
    FETCH c_get_pik_path INTO l_pik_path;
    IF c_get_pik_path%FOUND THEN
      -- Last ship slot pik path is found. Check if the last ship slot already
      -- had different item occupied.
      BEGIN
        SELECT 1
        INTO l_existed
        FROM inv
        WHERE plogi_loc = l_last_ship_slot
        AND prod_id    <> i_prod_id;
        -- Last ship slot has only 1 and different item occupied.
        -- Need to find another empty slot.
      EXCEPTION
      WHEN NO_DATA_FOUND THEN
        -- Either last ship slot has no inventory or the same item is in
        -- the slot. Use the slot.
        CLOSE c_get_pik_path;
        o_loc       := l_last_ship_slot;
        o_abc       := l_abc;
        o_case_cube := l_case_cube;
        o_skid_cube := l_skid_cube;
        RETURN;
      WHEN TOO_MANY_ROWS THEN
        -- More than 1 different items found in the last ship slot. Need to
        -- find another empty slot.
        NULL;
      WHEN OTHERS THEN
        o_status := SQLCODE;
        CLOSE c_get_pik_path;
        RAISE e_no_location_found;
      END;
    END IF;
    CLOSE c_get_pik_path;
    -- Last ship slot has different item occupied. Need to find another open
    -- slot which is closest to the last ship slot and with the same zone and
    -- same pallet type.
    OPEN c_get_float_ecube_same_paltyp(l_zone_id, l_paltype, l_last_ship_slot, l_pik_path);
    FETCH c_get_float_ecube_same_paltyp INTO l_loc, l_near_pik_path;
    -- Get the skid cube for the new palle type.
    IF NVL(l_old_paltype, ' ') <> NVL(l_paltype, ' ') THEN
      BEGIN
        SELECT skid_cube
        INTO l_skid_cube
        FROM pallet_type
        WHERE pallet_type = l_paltype;
      EXCEPTION
      WHEN NO_DATA_FOUND THEN
        l_skid_cube := 0;
      WHEN OTHERS THEN
        o_status := SQLCODE;
        RAISE e_no_location_found;
      END;
    END IF;
    IF c_get_float_ecube_same_paltyp%FOUND THEN
      -- Found the slot.
      CLOSE c_get_float_ecube_same_paltyp;
      o_loc       := l_loc;
      o_abc       := l_abc;
      o_case_cube := l_case_cube;
      o_skid_cube := l_skid_cube;
      RETURN;
    END IF;
    CLOSE c_get_float_ecube_same_paltyp;
    -- Still cannot find an open slot that has the same zone and pallet type
    -- and user doesn't want to update the pallet type. '*' out the location.
    IF NVL(gRcTypSyspar.upd_item_ptype_return, 'N') <> 'Y' THEN
      o_status                                      := ct_sql_no_data_found;
      RAISE e_no_location_found;
    END IF;
    -- User wants to continue. Search for an open floating slot that has
    -- enough cube.
    OPEN c_get_empty_float_enough_cube(l_zone_id, l_last_ship_slot, l_pik_path);
    FETCH c_get_empty_float_enough_cube INTO l_loc, l_paltype, l_near_pik_path;
    IF c_get_empty_float_enough_cube%NOTFOUND THEN
      -- Not found any. '*' out the location.
      CLOSE c_get_empty_float_enough_cube;
      o_status := ct_sql_no_data_found;
      RAISE e_no_location_found;
    END IF;
    CLOSE c_get_empty_float_enough_cube;
    -- Found an open slot that has enough cube. Update latest info
    BEGIN
      UPDATE pm
      SET last_ship_slot   = l_loc,
        pallet_type        = l_paltype
      WHERE prod_id        = i_prod_id
      AND cust_pref_vendor = i_cpv;
    EXCEPTION
    WHEN NO_DATA_FOUND THEN
      NULL;
    WHEN OTHERS THEN
      o_status := SQLCODE;
      RAISE e_no_location_found;
    END;
    -- Add a transaction record for slot and pallet type changes.
    l_trans_rec                                    := NULL;
    IF NVL(gRcTypSyspar.upd_item_ptype_return, 'N') = 'Y' AND NVL(l_old_paltype, ' ') <> NVL(l_paltype, ' ') THEN
      l_trans_rec.trans_type                       := 'IMT';
      l_trans_rec.rec_id                           := TO_CHAR(i_mf_no);
      l_trans_rec.user_id                          := USER;
      l_trans_rec.prod_id                          := i_prod_id;
      l_trans_rec.cust_pref_vendor                 := i_cpv;
      l_trans_rec.upload_time                      := NULL;
      l_trans_rec.dest_loc                         := l_loc;
      l_trans_rec.pallet_id                        := l_loc;
      l_trans_rec.cmt                              := 'RTNSDTL: Old pallet type: ' || l_old_paltype || ', New pallet type: ' || l_paltype;
      l_status                                     := pl_common.f_create_trans(l_trans_rec, 'na');
      IF l_status                                  <> ct_sql_success THEN
        o_status                                   := l_status;
        RAISE e_no_location_found;
      END IF;
      -- Send LM apcom for pallet type
      l_process_err_row           := NULL;
      l_process_err_row.value_1   := TO_CHAR(i_mf_no);
      l_process_err_row.value_2   := l_paltype;
      l_process_err_row.error_msg := RPAD(i_prod_id, 9) || i_cpv;
      l_status                    := f_save_apcom_lm (l_process_err_row);
      IF l_status                 <> ct_sql_success THEN
        o_status                  := l_status;
        RAISE e_no_location_found;
      END IF;
    END IF;
    o_loc       := l_loc;
    o_abc       := l_abc;
    o_case_cube := l_case_cube;
    o_skid_cube := l_skid_cube;
  EXCEPTION
  WHEN e_no_location_found THEN
    o_loc      := '*';
    o_is_float := 0;
  WHEN OTHERS THEN
    o_status   := SQLCODE;
    o_loc      := '*';
    o_is_float := 0;
  END;
-- Get the next available erm_line_id from RETURNS for the input manifest #.
-- O_next_line_id has the next erm_line_id.
-- O_status has sqlcode.
  PROCEDURE p_get_next_line_id(
      i_mf_no IN returns.manifest_no%TYPE,
      o_next_line_id OUT returns.erm_line_id%TYPE,
      o_status OUT NUMBER)
  IS
    l_existed NUMBER(1) := 0;
    l_next_line_id returns.erm_line_id%TYPE;
    l_status NUMBER(5) := ct_sql_success;
  BEGIN
    o_next_line_id := -1;
    o_status       := ct_sql_success;
    BEGIN
      SELECT 1 INTO l_existed FROM manifests WHERE manifest_no = i_mf_no;
    EXCEPTION
    WHEN NO_DATA_FOUND THEN
      l_status := ct_sql_no_data_found;
    WHEN OTHERS THEN
      l_status := SQLCODE;
    END;
    IF l_status <> ct_sql_success THEN
      o_status  := l_status;
      RETURN;
    END IF;
    BEGIN
      SELECT NVL(MAX(erm_line_id), 0) + 1
      INTO o_next_line_id
      FROM returns
      WHERE manifest_no = i_mf_no;
    EXCEPTION
    WHEN OTHERS THEN
      o_status := SQLCODE;
    END;
  END;
  FUNCTION f_update_weights(
      i_weight_flag   IN VARCHAR2,
      i_rtn_row       IN returns%ROWTYPE,
      i_coll_splits   IN NUMBER,
      i_coll_weight   IN NUMBER,
      i_update_weight IN tmp_rtn_weights.total_weight%TYPE)
    RETURN NUMBER
  IS
    l_rtn_split_qty NUMBER(10) := 0;
    l_status        NUMBER(5)  := ct_sql_success;
  BEGIN
    -- Delete the weight record
    IF i_weight_flag = 'D' THEN
      BEGIN
        DELETE tmp_rtn_weights
        WHERE manifest_no    = i_rtn_row.manifest_no
        AND obligation_no    = i_rtn_row.obligation_no
        AND prod_id          = i_rtn_row.returned_prod_id
        AND cust_pref_vendor = i_rtn_row.cust_pref_vendor;
      EXCEPTION
      WHEN NO_DATA_FOUND THEN
        NULL;
      WHEN OTHERS THEN
        RETURN SQLCODE;
      END;
      RETURN ct_sql_success;
    END IF;
    -- Convert returned quantity to splits
    p_convert_qty_to_splits(i_rtn_row.returned_prod_id, i_rtn_row.cust_pref_vendor, i_rtn_row.returned_qty, i_rtn_row.returned_split_cd, l_rtn_split_qty, l_status);
    IF l_status <> ct_sql_success THEN
      RETURN l_status;
    END IF;
    BEGIN
      UPDATE returns r
      SET catchweight           = i_rtn_row.catchweight,
        upd_source              = 'RF'
      WHERE manifest_no         = i_rtn_row.manifest_no
      AND obligation_no         = i_rtn_row.obligation_no
      AND returned_prod_id      = i_rtn_row.returned_prod_id
      AND cust_pref_vendor      = i_rtn_row.cust_pref_vendor
      AND returned_qty         IS NOT NULL
      AND erm_line_id           = i_rtn_row.erm_line_id
      AND return_reason_cd NOT IN
        (SELECT reason_cd
        FROM reason_cds
        WHERE reason_cd_type = 'RTN'
        AND reason_group    IN ('DMG', 'STM', 'OVR', 'MPR', 'MPK')
        );
    EXCEPTION
    WHEN NO_DATA_FOUND THEN
      NULL;
    WHEN OTHERS THEN
      RETURN SQLCODE;
    END;
    BEGIN
      UPDATE erd d
      SET weight   = i_rtn_row.catchweight
      WHERE erm_id = 'S'
        || TO_CHAR(i_rtn_row.manifest_no)
      AND order_id         = i_rtn_row.obligation_no
      AND prod_id          = i_rtn_row.returned_prod_id
      AND cust_pref_vendor = i_rtn_row.cust_pref_vendor
      AND erm_line_id      = i_rtn_row.erm_line_id
      AND reason_code NOT IN
        (SELECT reason_cd
        FROM reason_cds
        WHERE reason_cd_type = 'RTN'
        AND reason_group    IN ('DMG', 'STM', 'OVR', 'MPR', 'MPK')
        );
    EXCEPTION
    WHEN NO_DATA_FOUND THEN
      NULL;
    WHEN OTHERS THEN
      RETURN SQLCODE;
    END;
    BEGIN
      UPDATE putawaylst pt
      SET weight   = i_rtn_row.catchweight,
        catch_wt   = DECODE(i_update_weight, NULL, 'N', i_weight_flag)
      WHERE rec_id = 'S'
        || TO_CHAR(i_rtn_row.manifest_no)
      AND prod_id          = i_rtn_row.returned_prod_id
      AND cust_pref_vendor = i_rtn_row.cust_pref_vendor
      AND erm_line_id      = i_rtn_row.erm_line_id
      AND reason_code NOT IN
        (SELECT reason_cd
        FROM reason_cds
        WHERE reason_cd_type = 'RTN'
        AND reason_group    IN ('DMG', 'STM', 'OVR', 'MPR', 'MPK')
        );
    EXCEPTION
    WHEN NO_DATA_FOUND THEN
      NULL;
    WHEN OTHERS THEN
      RETURN SQLCODE;
    END;
    RETURN ct_sql_success;
  END;
  FUNCTION f_update_temperature(
      i_temp_flag   IN VARCHAR2,
      i_mf_no       IN tmp_rtn_temps.manifest_no%TYPE,
      i_ob_no       IN tmp_rtn_temps.obligation_no%TYPE,
      i_prod_id     IN tmp_rtn_temps.prod_id%TYPE,
      i_cpv         IN tmp_rtn_temps.cust_pref_vendor%TYPE,
      i_rtn_prod_id IN returns.returned_prod_id%TYPE,
      i_temp        IN tmp_rtn_temps.temperature%TYPE)
    RETURN NUMBER
  IS
  BEGIN
    BEGIN
      UPDATE returns
      SET temperature             = i_temp,
        upd_source                = 'RF'
      WHERE manifest_no           = i_mf_no
      AND NVL(obligation_no, ' ') = NVL(i_ob_no, ' ')
      AND prod_id                 = i_prod_id
      AND cust_pref_vendor        = i_cpv
      AND returned_prod_id        = i_rtn_prod_id
      AND returned_qty           IS NOT NULL
      AND return_reason_cd NOT   IN
        (SELECT reason_cd
        FROM reason_cds
        WHERE reason_cd_type = 'RTN'
        AND reason_group    IN ('DMG', 'MPK', 'STM')
        );
    EXCEPTION
    WHEN NO_DATA_FOUND THEN
      NULL;
    WHEN OTHERS THEN
      RETURN SQLCODE;
    END;
    BEGIN
      UPDATE erd
      SET temp     = i_temp
      WHERE erm_id = 'S'
        || TO_CHAR(i_mf_no)
      AND NVL(order_id, ' ') = NVL(i_ob_no, ' ')
      AND prod_id            = i_rtn_prod_id
      AND cust_pref_vendor   = i_cpv
      AND reason_code NOT   IN
        (SELECT reason_cd
        FROM reason_cds
        WHERE reason_cd_type = 'RTN'
        AND reason_group    IN ('DMG', 'MPK', 'STM')
        );
    EXCEPTION
    WHEN NO_DATA_FOUND THEN
      NULL;
    WHEN OTHERS THEN
      RETURN SQLCODE;
    END;
    BEGIN
      UPDATE putawaylst
      SET temp     = i_temp,
        temp_trk   = i_temp_flag
      WHERE rec_id = 'S'
        || TO_CHAR(i_mf_no)
      AND NVL(lot_id, ' ') = NVL(i_ob_no, ' ')
      AND prod_id          = i_rtn_prod_id
      AND cust_pref_vendor = i_cpv
      AND reason_code NOT IN
        (SELECT reason_cd
        FROM reason_cds
        WHERE reason_cd_type = 'RTN'
        AND reason_group    IN ('DMG', 'MPK', 'STM')
        );
    EXCEPTION
    WHEN NO_DATA_FOUND THEN
      NULL;
    WHEN OTHERS THEN
      RETURN SQLCODE;
    END;
    RETURN ct_sql_success;
  END;
  PROCEDURE p_create_return_po(
      i_rtn_row IN returns%ROWTYPE,
      o_status OUT NUMBER)
  IS
    l_misc reason_cds.misc%TYPE;
    l_reason_group reason_cds.reason_group%TYPE;
    l_valid  NUMBER(1) := 0;
    l_status NUMBER(5) := ct_sql_success;
    l_erm_id erm.erm_id%TYPE;
    l_existed NUMBER(1)          := 0;
    l_saleable erd.saleable%TYPE := 'Y';
    l_mispick erd.mispick%TYPE   := 'N';
    l_prod_id erd.prod_id%TYPE   := i_rtn_row.prod_id;
    l_qty_splits erd.qty%TYPE    := 0;
  BEGIN
    o_status := ct_sql_success;
    -- Only create return PO when has quantity
    IF NVL(i_rtn_row.returned_qty, 0) = 0 THEN
      RETURN;
    END IF;
    -- Create return PO only for valid reason code or for certain reason groups
    p_check_valid_reason('A', i_rtn_row.return_reason_cd, l_misc, l_reason_group, l_valid, l_status);
    IF l_status <> ct_sql_success OR l_valid = 0 OR l_reason_group IN ('STM', 'STR', 'MPK') THEN
      o_status  := ct_invalid_rsn;
      IF l_reason_group IN ('STM', 'STR', 'MPK') THEN
        o_status := ct_sql_success;
      END IF;
      RETURN;
    END IF;
    IF l_reason_group = 'DMG' THEN
      l_erm_id       := 'D' || TO_CHAR(i_rtn_row.manifest_no);
      l_saleable     := 'N';
    ELSE
      l_erm_id := 'S' || TO_CHAR(i_rtn_row.manifest_no);
      IF l_reason_group IN ('MPR', 'MPK', 'OVR', 'OVI') THEN
        l_mispick := 'Y';
      END IF;
      IF l_reason_group IN ('MPR', 'MPK') THEN
        l_prod_id := i_rtn_row.returned_prod_id;
      END IF;
    END IF;
    BEGIN
      SELECT 1 INTO l_existed FROM erm WHERE erm_id = l_erm_id;
    EXCEPTION
    WHEN NO_DATA_FOUND THEN
      l_existed := 0;
    WHEN OTHERS THEN
      o_status := SQLCODE;
      RETURN;
    END;
    -- Create ERM only if not existed
    IF l_existed = 0 THEN
      BEGIN
        INSERT
        INTO erm
          (
            erm_id,
            erm_type,
            sched_date,
            exp_arriv_date,
            rec_date,
            status
          )
          VALUES
          (
            l_erm_id,
            'CM',
            SYSDATE,
            SYSDATE,
            SYSDATE,
            'OPN'
          );
      EXCEPTION
      WHEN OTHERS THEN
        o_status := SQLCODE;
        RETURN;
      END;
    END IF;
    -- Convert quantity to all splits
    p_convert_qty_to_splits (l_prod_id, i_rtn_row.cust_pref_vendor, i_rtn_row.returned_qty, i_rtn_row.returned_split_cd, l_qty_splits, l_status);
    IF l_status <> ct_sql_success THEN
      o_status  := l_status;
      RETURN;
    END IF;
    -- Create ERD only if not existed
    BEGIN
      INSERT
      INTO erd
        (
          erm_id,
          erm_line_id,
          saleable,
          mispick,
          prod_id,
          weight,
          temp,
          qty,
          uom,
          qty_rec,
          uom_rec,
          order_id,
          cust_pref_vendor,
          status,
          reason_code
        )
        VALUES
        (
          l_erm_id,
          i_rtn_row.erm_line_id,
          l_saleable,
          l_mispick,
          l_prod_id,
          i_rtn_row.catchweight,
          i_rtn_row.temperature,
          l_qty_splits,
          TO_NUMBER(i_rtn_row.returned_split_cd),
          l_qty_splits,
          TO_NUMBER(i_rtn_row.returned_split_cd),
          i_rtn_row.obligation_no,
          i_rtn_row.cust_pref_vendor,
          'OPN',
          i_rtn_row.return_reason_cd
        );
    EXCEPTION
    WHEN DUP_VAL_ON_INDEX THEN
      BEGIN
        UPDATE erd
        SET qty              = NVL(qty, 0) + l_qty_splits,
          weight             = i_rtn_row.catchweight,
          temp               = i_rtn_row.temperature
        WHERE erm_id         = l_erm_id
        AND erm_line_id      = i_rtn_row.erm_line_id
        AND prod_id          = l_prod_id
        AND cust_pref_vendor = i_rtn_row.cust_pref_vendor;
      EXCEPTION
      WHEN NO_DATA_FOUND THEN
        NULL;
      WHEN OTHERS THEN
        o_status := SQLCODE;
      END;
    WHEN OTHERS THEN
      o_status := SQLCODE;
    END;
  END;
  PROCEDURE p_create_putaway_n_inv(
      i_rtn_row IN returns%ROWTYPE,
      o_dest_loc OUT putawaylst.dest_loc%TYPE,
      o_pallet_id OUT putawaylst.pallet_id%TYPE,
      o_status OUT NUMBER)
  IS
    l_misc reason_cds.misc%TYPE;
    l_reason_group reason_cds.reason_group%TYPE;
    l_valid  NUMBER(1) := 0;
    l_status NUMBER(5) := ct_sql_success;
    l_erm_id erm.erm_id%TYPE;
    l_existed NUMBER(1)        := 0;
    l_mispick erd.mispick%TYPE := 'N';
    l_prod_id erd.prod_id%TYPE := i_rtn_row.prod_id;
    l_loc putawaylst.dest_loc%TYPE;
    l_licPlate putawaylst.pallet_id%TYPE;
    l_is_float NUMBER(1) := 0;
    l_abc pm.abc%TYPE;
    l_case_cube pm.case_cube%TYPE;
    l_skid_cube pallet_type.skid_cube%TYPE;
    l_qty_splits putawaylst.qty%TYPE;
    l_put_status putawaylst.status%TYPE         := ' ';
    l_put_inv_status putawaylst.inv_status%TYPE := ' ';
    l_orig_invoice returns.obligation_no%TYPE;
    l_rtn_date DATE;
    CURSOR c_get_orig_invoice
    IS
      SELECT DECODE(orig_invoice, NULL, NULL, DECODE(INSTR(orig_invoice, 'L'), 0, orig_invoice, SUBSTR(orig_invoice, 1, INSTR(orig_invoice, 'L') - 1)))
      FROM manifest_dtls
      WHERE manifest_no    = i_rtn_row.manifest_no
      AND obligation_no    = i_rtn_row.obligation_no
      AND prod_id          = i_rtn_row.prod_id
      AND cust_pref_vendor = i_rtn_row.cust_pref_vendor;
  BEGIN
    o_dest_loc                       := NULL;
    o_pallet_id                      := NULL;
    o_status                         := ct_sql_success;
    IF NVL(i_rtn_row.returned_qty, 0) = 0 THEN
      RETURN;
    END IF;
    p_check_valid_reason('A', i_rtn_row.return_reason_cd, l_misc, l_reason_group, l_valid, l_status);
    IF l_status <> ct_sql_success OR l_valid = 0 OR l_reason_group IN ('STM', 'STR', 'MPK') THEN
      o_status  := l_status;
      IF l_reason_group IN ('STM', 'STR', 'MPK') THEN
        o_status := ct_sql_success;
      ELSE
        o_status := ct_invalid_rsn;
      END IF;
      RETURN;
    END IF;
    IF l_reason_group = 'DMG' THEN
      l_erm_id       := 'D' || TO_CHAR(i_rtn_row.manifest_no);
    ELSE
      l_erm_id         := 'S' || TO_CHAR(i_rtn_row.manifest_no);
      l_put_status     := 'NEW';
      l_put_inv_status := 'AVL';
      IF l_reason_group IN ('MPR', 'MPK', 'OVR', 'OVI') THEN
        l_mispick := 'Y';
      END IF;
      IF l_reason_group IN ('MPR', 'MPK') THEN
        l_prod_id := i_rtn_row.returned_prod_id;
      END IF;
    END IF;
    IF l_reason_group NOT IN ('XXX', 'DMG') THEN
      p_get_location(i_rtn_row.manifest_no, l_prod_id, i_rtn_row.cust_pref_vendor, i_rtn_row.returned_split_cd, l_loc, l_is_float, l_abc, l_case_cube, l_skid_cube, l_status);
      IF l_status <> ct_sql_success OR l_loc = '*' OR l_loc IS NULL THEN
        o_status  := ct_no_loc_found;
        RETURN;
      END IF;
    ELSE
      l_loc := 'DDDDDD';
    END IF;
    pl_common.p_get_unique_lp (l_licPlate, l_status);
    IF l_status <> ct_sql_success THEN
      o_status  := l_status;
      RETURN;
    END IF;
    p_convert_qty_to_splits (l_prod_id, i_rtn_row.cust_pref_vendor, i_rtn_row.returned_qty, i_rtn_row.returned_split_cd, l_qty_splits, l_status);
    IF l_status <> ct_sql_success THEN
      o_status  := l_status;
      RETURN;
    END IF;
    l_orig_invoice := NULL;
    IF i_rtn_row.rec_type IN ('P', 'D') THEN
      OPEN c_get_orig_invoice;
      FETCH c_get_orig_invoice INTO l_orig_invoice;
      IF c_get_orig_invoice%NOTFOUND THEN
        l_orig_invoice := NULL;
      END IF;
      CLOSE c_get_orig_invoice;
    END IF;
    IF pl_ml_common.f_is_induction_loc(l_loc) = 'Y' THEN
      l_rtn_date                             := '01-JAN-2001';
    ELSE
      l_rtn_date := SYSDATE;
    END IF;
    BEGIN
      INSERT
      INTO putawaylst
        (
          pallet_id,
          rec_id,
          prod_id,
          cust_pref_vendor,
          dest_loc,
          qty,
          uom,
          status,
          inv_status,
          equip_id,
          rec_lane_id,
          lot_id,
          weight,
          temp,
          qty_expected,
          qty_received,
          catch_wt,
          temp_trk,
          putaway_put,
          seq_no,
          mispick,
          erm_line_id,
          reason_code,
          orig_invoice,
          exp_date
        )
        VALUES
        (
          l_licPlate,
          l_erm_id,
          l_prod_id,
          i_rtn_row.cust_pref_vendor,
          l_loc,
          l_qty_splits,
          TO_NUMBER(i_rtn_row.returned_split_cd),
          l_put_status,
          l_put_inv_status,
          ' ',
          ' ',
          i_rtn_row.obligation_no,
          NULL,
          NULL,
          l_qty_splits,
          l_qty_splits,
          'N',
          'N',
          'N',
          i_rtn_row.erm_line_id,
          l_mispick,
          i_rtn_row.erm_line_id,
          i_rtn_row.return_reason_cd,
          l_orig_invoice,
          l_rtn_date
        );
    EXCEPTION
    WHEN DUP_VAL_ON_INDEX THEN
      RETURN;
      NULL;
    WHEN OTHERS THEN
      o_status := SQLCODE;
      RETURN;
    END;
    IF l_reason_group IN ('NOR', 'WIN') THEN
      IF l_is_float = 1 THEN
        BEGIN
          INSERT
          INTO inv
            (
              prod_id,
              rec_id,
              rec_date,
              exp_date,
              inv_date,
              logi_loc,
              plogi_loc,
              qoh,
              qty_alloc,
              qty_planned,
              min_qty,
              cube,
              lst_cycle_date,
              abc,
              abc_gen_date,
              status,
              cust_pref_vendor,
              inv_uom
            )
            VALUES
            (
              l_prod_id,
              l_erm_id,
              SYSDATE,
              l_rtn_date,
              l_rtn_date,
              l_licPlate,
              l_loc,
              0,
              0,
              l_qty_splits,
              0,
              NVL(l_case_cube, 0) + NVL(l_skid_cube, 0),
              SYSDATE,
              l_abc,
              SYSDATE,
              'AVL',
              i_rtn_row.cust_pref_vendor,
              TO_NUMBER(i_rtn_row.returned_split_cd)
            );
        EXCEPTION
        WHEN DUP_VAL_ON_INDEX THEN
          o_status := ct_sql_no_data_found;
          RETURN;
        WHEN OTHERS THEN
          o_status := SQLCODE;
          pl_log.ins_msg('F', 'pl_rtn_dtls', 'Failed Inv insert item: '||l_prod_id||'='||l_erm_id||'='||l_licPlate|| '='||l_loc||'='||TO_CHAR(l_qty_splits)||'='||TO_CHAR(l_case_cube)||'=' ||TO_CHAR(l_skid_cube)||'='||l_abc||'='||i_rtn_row.cust_pref_vendor|| '='||TO_CHAR(2 - TO_NUMBER(i_rtn_row.returned_split_cd)), 0,0);
          RETURN;
        END;
      ELSE
        BEGIN
          UPDATE inv
          SET qty_planned = qty_planned + l_qty_splits
          WHERE plogi_loc = l_loc
          AND logi_loc    = plogi_loc;
        EXCEPTION
        WHEN NO_DATA_FOUND THEN
          NULL;
        WHEN OTHERS THEN
          o_status := SQLCODE;
          RETURN;
        END;
      END IF;
    END IF;
    o_dest_loc  := l_loc;
    o_pallet_id := l_licPlate;
  END;
  FUNCTION f_do_tmp_rtn_weights(
      i_process_flag IN VARCHAR2,
      i_mf_no        IN tmp_rtn_weights.manifest_no%TYPE,
      i_ob_no        IN tmp_rtn_weights.obligation_no%TYPE,
      i_prod_id      IN tmp_rtn_weights.prod_id%TYPE,
      i_cpv          IN tmp_rtn_weights.cust_pref_vendor%TYPE,
      i_qty          IN NUMBER,
      i_uom          IN returns.returned_split_cd%TYPE,
      i_weight       IN tmp_rtn_weights.total_weight%TYPE)
    RETURN NUMBER
  IS
    l_status NUMBER := ct_sql_success;
  BEGIN
    IF i_process_flag = 'I' THEN
      BEGIN
        INSERT
        INTO tmp_rtn_weights
          (
            manifest_no,
            obligation_no,
            prod_id,
            cust_pref_vendor,
            total_cases,
            total_splits,
            total_weight
          )
          VALUES
          (
            i_mf_no,
            i_ob_no,
            i_prod_id,
            i_cpv,
            DECODE(i_uom, '1', NULL, i_qty),
            DECODE(i_uom, '1', i_qty, NULL),
            i_weight
          );
      EXCEPTION
      WHEN OTHERS THEN
        l_status := SQLCODE;
      END;
    ELSE
      BEGIN
        UPDATE tmp_rtn_weights
        SET total_weight     = NVL(total_weight, 0) + NVL(i_weight, 0),
          total_cases        = NVL(total_cases, 0)  + DECODE(i_uom, '1', 0, i_qty),
          total_splits       = NVL(total_splits, 0) + DECODE(i_uom, '1', i_qty, 0)
        WHERE manifest_no    = i_mf_no
        AND obligation_no    = i_ob_no
        AND prod_id          = i_prod_id
        AND cust_pref_vendor = i_cpv;
      EXCEPTION
      WHEN NO_DATA_FOUND THEN
        NULL;
      WHEN OTHERS THEN
        l_status := SQLCODE;
      END;
    END IF;
    RETURN l_status;
  END;
-- Do weight collection checking
  PROCEDURE p_weight_collection(
      i_rf_option IN VARCHAR2,
      i_mf_no     IN tmp_rtn_weights.manifest_no%TYPE,
      i_ob_no     IN tmp_rtn_weights.obligation_no%TYPE,
      i_prod_id   IN tmp_rtn_weights.prod_id%TYPE,
      i_cpv       IN tmp_rtn_weights.cust_pref_vendor%TYPE,
      i_qty       IN NUMBER,
      i_uom       IN returns.returned_split_cd%TYPE,
      i_weight    IN tmp_rtn_weights.total_weight%TYPE,
      o_add_msg OUT VARCHAR2,
      o_weight_flag OUT VARCHAR2,
      o_coll_splits OUT NUMBER,
      o_coll_weight OUT NUMBER,
      o_status OUT NUMBER)
  IS
    l_coll_splits NUMBER                            := 0;
    l_coll_weight tmp_rtn_weights.total_weight%TYPE := NULL;
    l_pm_weight pm.avg_wt%TYPE                      := NULL;
    l_spc pm.spc%TYPE                               := NULL;
    l_min_weight pm.avg_wt%TYPE                     := NULL;
    l_max_weight pm.avg_wt%TYPE                     := NULL;
    l_weight_notfound BOOLEAN;
    l_pct_tolerance sys_config.config_flag_val%TYPE;
    l_cur_splits NUMBER         := 0;
    l_cur_weight pm.avg_wt%TYPE := NULL;
    l_status NUMBER             := 0;
    CURSOR c_get_weight_info(c_spc NUMBER)
    IS
      SELECT total_weight,
        NVL(total_cases, 0) * NVL(c_spc, 0) + NVL(total_splits, 0)
      FROM tmp_rtn_weights t,
        pm p
      WHERE manifest_no      = i_mf_no
      AND obligation_no      = i_ob_no
      AND t.prod_id          = i_prod_id
      AND t.cust_pref_vendor = i_cpv;
    CURSOR c_get_pm_weight_info
    IS
      SELECT NVL(avg_wt, 0),
        NVL(spc, 0)
      FROM pm
      WHERE prod_id        = i_prod_id
      AND cust_pref_vendor = i_cpv;
  BEGIN
    o_status      := ct_sql_success;
    o_weight_flag := 'N';
    o_add_msg     := NULL;
    o_coll_splits := NULL;
    o_coll_weight := NULL;
    -- Get weight tolerance, system average weight and saved weight and quantity
    OPEN c_get_pm_weight_info;
    FETCH c_get_pm_weight_info INTO l_pm_weight, l_spc;
    CLOSE c_get_pm_weight_info;
    l_weight_notfound := FALSE;
    OPEN c_get_weight_info(l_spc);
    FETCH c_get_weight_info INTO l_coll_weight, l_coll_splits;
    IF c_get_weight_info%NOTFOUND THEN
      l_weight_notfound := TRUE;
    END IF;
    CLOSE c_get_weight_info;
    o_coll_splits := l_coll_splits;
    o_coll_weight := l_coll_weight;
    BEGIN
      l_pct_tolerance := pl_common.f_get_syspar('PCT_TOLERANCE', '100');
    EXCEPTION
    WHEN OTHERS THEN
      l_pct_tolerance := '100';
    END;
    -- Convert returned quantity to splits
    p_convert_qty_to_splits(i_prod_id, i_cpv, i_qty, i_uom, l_cur_splits, l_status);
    IF l_status <> ct_sql_success THEN
      o_status  := l_status;
      RETURN;
    END IF;
    -- Calculate average weight, minimum and maximum for current return
    l_cur_weight                                   := (NVL(l_coll_weight, 0) + NVL(i_weight, 0)) / (NVL(l_coll_splits, 0) + l_cur_splits);
    l_min_weight                                   := l_pm_weight            * (1 - TO_NUMBER(l_pct_tolerance) / 100);
    l_max_weight                                   := l_pm_weight            * (1 + TO_NUMBER(l_pct_tolerance) / 100);
    IF i_weight                                    IS NULL THEN
      IF l_weight_notfound OR NVL(l_coll_weight, 0) = 0 THEN
        IF i_rf_option                              = '1' THEN
          -- 1st time come in. No weight collected before and no current weight.
          -- Notify user that weight is desired
          o_status  := ct_weight_desired;
          o_add_msg := '|' || RPAD(TO_CHAR(l_min_weight * l_cur_splits), 10) || RPAD(TO_CHAR(l_max_weight * l_cur_splits), PALLET_ID_LEN) || '|';
        ELSE
          IF l_weight_notfound THEN
            -- Come in from 2nd time. No weight collected before and no current
            -- weight. Accept current no-value weight anyway. User can collect
            -- the weight later in CRT if needed.
            o_status := f_do_tmp_rtn_weights('I', i_mf_no, i_ob_no, i_prod_id, i_cpv, i_qty, i_uom, i_weight);
          END IF;
          o_weight_flag := 'Y';
        END IF;
      ELSE -- l_coll_weight is not null
        IF i_rf_option = '1' THEN
          -- 1st time come in. Weight collected before and no current weight
          -- entered. Warn user that weight is desired
          o_status  := ct_weight_desired;
          o_add_msg := '|' || RPAD(TO_CHAR(l_min_weight * l_cur_splits), 10) || RPAD(TO_CHAR(l_max_weight * l_cur_splits), PALLET_ID_LEN) || '|';
        ELSE
          -- Come in from 2nd time. Weight collected before and no current weight.
          -- Accumulate the total returned quantity so far for the weighted item.
          o_status      := f_do_tmp_rtn_weights('U', i_mf_no, i_ob_no, i_prod_id, i_cpv, i_qty, i_uom, i_weight);
          o_weight_flag := 'Y';
        END IF;
      END IF;
    END IF; -- i_weight is null
    IF i_weight                                    IS NOT NULL THEN
      IF l_weight_notfound OR NVL(l_coll_weight, 0) = 0 THEN
        IF i_rf_option                              = '1' THEN
          IF i_weight                               < (l_min_weight * l_cur_splits) OR i_weight > (l_max_weight * l_cur_splits) THEN
            -- 1st time come in. No weight collected before and has current weight
            -- and weight isn't within limit. Notify user
            o_status  := ct_weight_out_of_range;
            o_add_msg := '|' || RPAD(TO_CHAR(l_min_weight * l_cur_splits), 10) || RPAD(TO_CHAR(l_max_weight * l_cur_splits), PALLET_ID_LEN) || '|';
          END IF;
        END IF;
        IF i_weight >= (l_min_weight * l_cur_splits) AND i_weight <= (l_max_weight * l_cur_splits) THEN
          IF l_weight_notfound THEN
            -- No weight collected before and has current weight which is within
            -- limit. Insert weight record
            o_status := f_do_tmp_rtn_weights('I', i_mf_no, i_ob_no, i_prod_id, i_cpv, i_qty, i_uom, i_weight);
          ELSE
            -- Weight record existed but no weight collected before and has
            -- current weight which is within limit. Update weight record
            o_status := f_do_tmp_rtn_weights('U', i_mf_no, i_ob_no, i_prod_id, i_cpv, i_qty, i_uom, i_weight);
          END IF;
          -- Note weight has been collected
          o_weight_flag := 'C';
        END IF;
      ELSE -- l_coll_weight is not null
        IF i_rf_option = '1' THEN
          IF i_weight  < (l_min_weight * l_cur_splits) OR i_weight > (l_max_weight * l_cur_splits) THEN
            -- 1st time come in. Weight record existed and collected before and
            -- has current weight which isn't within limit. Notify user
            o_status  := ct_weight_out_of_range;
            o_add_msg := '|' || RPAD(TO_CHAR(l_min_weight * l_cur_splits), 10) || RPAD(TO_CHAR(l_max_weight * l_cur_splits), PALLET_ID_LEN) || '|';
          END IF;
          IF i_weight >= (l_min_weight * l_cur_splits) AND i_weight <= (l_max_weight * l_cur_splits) THEN
            -- Weight record existed and collected before and
            -- has current weight which is within limit. Update weight record
            -- with new combined returned quantity and weight.
            o_status := f_do_tmp_rtn_weights('U', i_mf_no, i_ob_no, i_prod_id, i_cpv, i_qty, i_uom, i_weight);
            -- Note weight has been collected
            o_weight_flag := 'C';
          END IF;
        ELSE
          -- Come in from 2nd time. Weight record existed and collected before
          -- and has current weight. Update weight record with new combined
          -- returned quantity and weight regardless that the current weight
          -- might not within the limit.
          o_status := f_do_tmp_rtn_weights('U', i_mf_no, i_ob_no, i_prod_id, i_cpv, i_qty, i_uom, i_weight);
          -- Note weight has been collected
          o_weight_flag := 'C';
        END IF;
      END IF;
    END IF; -- i_weight is not null
  END;
  FUNCTION f_do_tmp_rtn_temps(
      i_process_flag IN VARCHAR2,
      i_mf_no        IN tmp_rtn_temps.manifest_no%TYPE,
      i_ob_no        IN tmp_rtn_temps.obligation_no%TYPE,
      i_prod_id      IN tmp_rtn_temps.prod_id%TYPE,
      i_cpv          IN tmp_rtn_temps.cust_pref_vendor%TYPE,
      i_temp         IN tmp_rtn_temps.temperature%TYPE)
    RETURN NUMBER
  IS
    l_status NUMBER := ct_sql_success;
  BEGIN
    IF i_process_flag = 'I' THEN
      BEGIN
        INSERT
        INTO tmp_rtn_temps
          (
            manifest_no,
            obligation_no,
            prod_id,
            cust_pref_vendor,
            temperature
          )
          VALUES
          (
            i_mf_no,
            i_ob_no,
            i_prod_id,
            i_cpv,
            i_temp
          );
      EXCEPTION
      WHEN OTHERS THEN
        l_status := SQLCODE;
      END;
    ELSE
      BEGIN
        UPDATE tmp_rtn_temps
        SET temperature             = i_temp
        WHERE manifest_no           = i_mf_no
        AND NVL(obligation_no, ' ') = NVL(i_ob_no, ' ')
        AND prod_id                 = i_prod_id
        AND cust_pref_vendor        = i_cpv;
      EXCEPTION
      WHEN NO_DATA_FOUND THEN
        NULL;
      WHEN OTHERS THEN
        l_status := SQLCODE;
      END;
    END IF;
    RETURN l_status;
  END;
  PROCEDURE p_temp_collection(
      i_rf_option IN VARCHAR2,
      i_mf_no     IN tmp_rtn_temps.manifest_no%TYPE,
      i_ob_no     IN tmp_rtn_temps.obligation_no%TYPE,
      i_prod_id   IN tmp_rtn_temps.prod_id%TYPE,
      i_cpv       IN tmp_rtn_temps.cust_pref_vendor%TYPE,
      i_temp      IN tmp_rtn_temps.temperature%TYPE,
      o_add_msg OUT VARCHAR2,
      o_temp_flag OUT VARCHAR2,
      o_status OUT NUMBER)
  IS
    l_coll_temp tmp_rtn_temps.temperature%TYPE := NULL;
    l_min_temp pm.min_temp%TYPE                := NULL;
    l_max_temp pm.max_temp%TYPE                := NULL;
    l_temp_notfound BOOLEAN;
    CURSOR c_get_tmp_rtn_temps
    IS
      SELECT temperature
      FROM tmp_rtn_temps
      WHERE manifest_no           = i_mf_no
      AND NVL(obligation_no, ' ') = NVL(i_ob_no, ' ')
      AND prod_id                 = i_prod_id
      AND cust_pref_vendor        = i_cpv;
    CURSOR c_get_pm_temp_range
    IS
      SELECT min_temp,
        max_temp
      FROM pm
      WHERE prod_id        = i_prod_id
      AND cust_pref_vendor = i_cpv;
  BEGIN
    o_status    := ct_sql_success;
    o_temp_flag := 'N';
    o_add_msg   := NULL;
    -- Get temperature range
    OPEN c_get_pm_temp_range;
    FETCH c_get_pm_temp_range INTO l_min_temp, l_max_temp;
    IF c_get_pm_temp_range%NOTFOUND OR l_min_temp IS NULL OR l_max_temp IS NULL OR ((l_min_temp = l_max_temp) AND (l_min_temp = 0)) THEN
      CLOSE c_get_pm_temp_range;
      o_status := ct_temp_no_range;
      RETURN;
    END IF;
    CLOSE c_get_pm_temp_range;
    -- Get existed temperature if any
    l_temp_notfound := FALSE;
    OPEN c_get_tmp_rtn_temps;
    FETCH c_get_tmp_rtn_temps INTO l_coll_temp;
    IF c_get_tmp_rtn_temps%NOTFOUND THEN
      l_temp_notfound := TRUE;
    END IF;
    CLOSE c_get_tmp_rtn_temps;
    IF i_temp                           IS NULL THEN
      IF l_temp_notfound OR l_coll_temp IS NULL THEN
        IF i_rf_option                   = '1' THEN
          -- 1st time come in. No temp collected before and no current temp.
          -- Notify user that temp is required
          o_status  := ct_temp_required;
          o_add_msg := '|' || RPAD(TO_CHAR(l_min_temp), 10) || RPAD(TO_CHAR(l_max_temp), PALLET_ID_LEN) || '|';
        ELSE
          IF l_temp_notfound THEN
            -- Come in from 2nd time. No temp collected before and no current
            -- temp. Accept current no-value temp anyway
            o_status := f_do_tmp_rtn_temps('I', i_mf_no, i_ob_no, i_prod_id, i_cpv, i_temp);
          END IF;
          o_temp_flag := 'Y';
        END IF;
      ELSE
        -- Temp collected before and no current temp. Use collected temp as
        -- current temp
        o_status    := ct_temp_existed_no_msg;
        o_add_msg   := TO_CHAR(l_coll_temp);
        o_temp_flag := 'C';
      END IF;
    END IF; -- i_temp is null
    IF i_temp                           IS NOT NULL THEN
      IF l_temp_notfound OR l_coll_temp IS NULL THEN
        IF i_temp                        < l_min_temp OR i_temp > l_max_temp THEN
          -- No temp collected before and has current temp and
          -- temp isn't within limit.
          IF i_rf_option = '1' THEN
            -- 1st time come in. Notify user.
            o_status  := ct_temp_out_of_limit;
            o_add_msg := '|' || RPAD(TO_CHAR(l_min_temp), 10) || RPAD(TO_CHAR(l_max_temp), PALLET_ID_LEN) || '|';
          ELSE
            -- 2nd and more time come in.
            IF l_temp_notfound THEN
              -- No temp collected before and has current temp which is not within
              -- limit. Accept anyway and insert the record.
              o_status := f_do_tmp_rtn_temps('I', i_mf_no, i_ob_no, i_prod_id, i_cpv, i_temp);
            ELSE
              -- Temp record existed but no temp collected before and has current
              -- temp which is not within limit. Update temp record
              o_status := f_do_tmp_rtn_temps('U', i_mf_no, i_ob_no, i_prod_id, i_cpv, i_temp);
            END IF;
            -- Note temp has been collected
            o_temp_flag := 'C';
          END IF;
        END IF;
        IF i_temp >= l_min_temp AND i_temp <= l_max_temp THEN
          IF l_temp_notfound THEN
            -- No temp collected before and has current temp which is within
            -- limit. Insert temp record
            o_status := f_do_tmp_rtn_temps('I', i_mf_no, i_ob_no, i_prod_id, i_cpv, i_temp);
          ELSE
            -- Temp record existed but no temp collected before and has current
            -- temp which is within limit. Update temp record
            o_status := f_do_tmp_rtn_temps('U', i_mf_no, i_ob_no, i_prod_id, i_cpv, i_temp);
          END IF;
          -- Note temp has been collected
          o_temp_flag := 'C';
        END IF;
      ELSE -- l_coll_temp is not null
        IF i_temp       <> l_coll_temp THEN
          IF i_rf_option = '1' THEN
            -- 1st time come in. Temp has been collected before and has current
            -- temp but it's different from the collected one. Notify user
            o_status  := ct_temp_existed;
            o_add_msg := '|' || RPAD(TO_CHAR(l_coll_temp), 10) || '|';
          ELSE
            -- Come in from 2nd time. Temp has been collected before and has
            -- current temp but it's different from the collected one. Use current
            o_status := f_do_tmp_rtn_temps('U', i_mf_no, i_ob_no, i_prod_id, i_cpv, i_temp);
          END IF;
        END IF;
        -- Note temp has been collected
        o_temp_flag := 'C';
      END IF;
    END IF; -- i_temp is not null
  END;
/********************************
Public Functions and Procedures
********************************/
-- Save the changed pallet type (if any) to a temporary table so a host program
-- can retrieve the information created from this package and write the
-- information to the LM apcom queue.
-- The host program should delete the saved LM information record each time
-- after the PROCESS_ERROR table is referenced so new information can be
-- created. Refer to p_delete_apcom_lm for more information. Return sqlcode.
-- The i_proc_err should have the following fields/values:
--   process_id:    "RTNDTL_LM"
--   value_1:       Manifest #
--   value_2:       Updated pallet type
--   error_msg      Item # + cust_pref_vendor
  FUNCTION f_save_apcom_lm(
      i_proc_err IN process_error%ROWTYPE)
    RETURN NUMBER
  IS
    l_existed NUMBER(1) := 0;
  BEGIN
    BEGIN
      SELECT 1
      INTO l_existed
      FROM process_error
      WHERE process_id = ct_process_error_id
      AND value_1      = i_proc_err.value_1
      AND value_2      = i_proc_err.value_2
      AND error_msg    = i_proc_err.error_msg;
    EXCEPTION
    WHEN NO_DATA_FOUND THEN
      l_existed := 0;
    WHEN OTHERS THEN
      l_existed := 1;
      RETURN SQLCODE;
    END;
    IF l_existed = 0 THEN
      BEGIN
        INSERT
        INTO process_error
          (
            process_id,
            user_id,
            value_1,
            value_2,
            error_msg,
            process_date
          )
          VALUES
          (
            ct_process_error_id,
            USER,
            i_proc_err.value_1,
            i_proc_err.value_2,
            i_proc_err.error_msg,
            SYSDATE
          );
      EXCEPTION
      WHEN OTHERS THEN
        RETURN SQLCODE;
      END;
    END IF;
    RETURN ct_sql_success;
  END;
-- Delete the matched process error record for LM apcom queue record. This
-- should be done after the host program finish refering the LM record. Return
-- sqlcode.
-- The i_proc_err should have the following fields/values:
--   process_id:    "RTNDTL_LM"
--   value_1:       Manifest #
--   value_2:       Updated pallet type
--   error_msg      Item # + cust_pref_vendor
  FUNCTION f_delete_apcom_lm
    (
      i_proc_err IN process_error%ROWTYPE
    )
    RETURN NUMBER
  IS
  BEGIN
    DELETE process_error
    WHERE process_id = ct_process_error_id
    AND value_1      = i_proc_err.value_1
    AND value_2      = i_proc_err.value_2
    AND error_msg    = i_proc_err.error_msg;
    RETURN ct_sql_success;
  EXCEPTION
  WHEN NO_DATA_FOUND THEN
    NULL;
  WHEN OTHERS THEN
    RETURN SQLCODE;
  END;
-- Get quantity information for nonoverage returns according to the manifest #
-- (i_mf_no), invoice # (i_inv_no), item # (i_prod_id and i_cpv) and current
-- unit of measure (i_uom.)
-- I_cur_qty_in_case has a value for current returned quantity. Specify 0 if
-- no current returned quantity.
-- O_db_ship_qty and o_db_ship_uom return the originally shipped information as
-- the value in database.
-- O_qty_exceed returns 1 if total current returned quantity (including
-- i_cur_qty_in_case) is > originally shipped quantity; otherwise return 0.
-- O_status has sqlcode or ct_no_mf_info.
  PROCEDURE p_get_nonoverage_qty_info(
      i_mf_no           IN manifest_dtls.manifest_no%TYPE,
      i_inv_no          IN manifest_dtls.obligation_no%TYPE,
      i_prod_id         IN manifest_dtls.prod_id%TYPE,
      i_cpv             IN manifest_dtls.cust_pref_vendor%TYPE,
      i_uom             IN returns.returned_split_cd%TYPE,
      i_cur_qty_in_case IN NUMBER,
      o_db_ship_qty OUT manifest_dtls.shipped_qty%TYPE,
      o_db_ship_uom OUT manifest_dtls.shipped_split_cd%TYPE,
      o_total_rtn_in_case OUT NUMBER,
      o_ship_in_case OUT NUMBER,
      o_qty_exceed OUT NUMBER,
      o_status OUT NUMBER)
  IS
    l_rec_type manifest_dtls.rec_type%TYPE;
    l_found             BOOLEAN;
    l_ship_in_case      NUMBER(10, 3) := 0;
    l_total_rtn_in_case NUMBER(10, 3) := 0;
    CURSOR c_get_ship_info (cp_rtn_uom VARCHAR2)
    IS
      SELECT d.rec_type,
        d.shipped_qty,
        d.shipped_split_cd,
        DECODE(NVL(d.shipped_split_cd, '1'), '0', NVL(d.shipped_qty, 0), NVL(d.shipped_qty, 0) / DECODE(p.spc, NULL, 1, 0, 1, p.spc))
      FROM manifests m,
        manifest_dtls d,
        pm p
      WHERE m.manifest_no    = i_mf_no
      AND m.manifest_no      = d.manifest_no
      AND d.obligation_no    = i_inv_no
      AND d.prod_id          = i_prod_id
      AND d.cust_pref_vendor = i_cpv
      AND p.prod_id          = d.prod_id
      AND p.cust_pref_vendor = d.cust_pref_vendor
      AND ((cp_rtn_uom      IS NULL)
      OR ((cp_rtn_uom       IS NOT NULL)
      AND (cp_rtn_uom        = d.shipped_split_cd)));
    CURSOR c_get_total_nonoverage_rtn_qty (cp_rtn_uom VARCHAR2, cp_rec_type VARCHAR2)
    IS
      SELECT NVL(SUM(DECODE(NVL(r.returned_split_cd, '1'), '0', NVL(r.returned_qty, 0), NVL(r.returned_qty, 0) / DECODE(p.spc, NULL, 1, 0, 1, p.spc))), 0)
      FROM returns r,
        pm p,
        reason_cds rc
      WHERE r.manifest_no      = i_mf_no
      AND r.obligation_no      = i_inv_no
      AND r.rec_type           = cp_rec_type
      AND r.rec_type          <> 'O'
      AND r.return_reason_cd   = rc.reason_cd
      AND r.cust_pref_vendor   = p.cust_pref_vendor
      AND rc.reason_cd_type    = 'RTN'
      AND p.prod_id            = DECODE(rc.reason_group, 'MPR', r.returned_prod_id, 'MPK', r.returned_prod_id, r.prod_id)
      AND r.prod_id            = i_prod_id
      AND r.cust_pref_vendor   = i_cpv
      AND ((cp_rtn_uom        IS NULL)
      OR ((cp_rtn_uom         IS NOT NULL)
      AND (r.returned_split_cd = cp_rtn_uom)));
  BEGIN
    o_db_ship_qty       := NULL;
    o_db_ship_uom       := NULL;
    o_total_rtn_in_case := NULL;
    o_ship_in_case      := NULL;
    o_qty_exceed        := 0;
    o_status            := ct_sql_success;
    -- Get shipped information for manifest#/ob#/item#/uom combination
    l_found := TRUE;
    OPEN c_get_ship_info(i_uom);
    FETCH c_get_ship_info
    INTO l_rec_type,
      o_db_ship_qty,
      o_db_ship_uom,
      l_ship_in_case;
    IF c_get_ship_info%NOTFOUND THEN
      l_found := FALSE;
    END IF;
    CLOSE c_get_ship_info;
    o_ship_in_case := l_ship_in_case;
    -- Do it again in case the returned uom is different from the shipped uom
    IF NOT l_found THEN
      l_found := TRUE;
      OPEN c_get_ship_info(NULL);
      FETCH c_get_ship_info
      INTO l_rec_type,
        o_db_ship_qty,
        o_db_ship_uom,
        l_ship_in_case;
      IF c_get_ship_info%NOTFOUND THEN
        l_found := FALSE;
      END IF;
      CLOSE c_get_ship_info;
      IF NOT l_found THEN
        o_status := ct_no_mf_info;
        RETURN;
      END IF;
    END IF;
    o_ship_in_case := l_ship_in_case;
    DBMS_OUTPUT.PUT_LINE('OvrQChk Ob/Item/u: ' || i_inv_no || '/' || i_prod_id || i_uom || ', curq_cs: ' || TO_CHAR(i_cur_qty_in_case) || ', shpq_cs: ' || TO_CHAR(l_ship_in_case));
    -- Get total nonoverage returned quantity for query combination
    l_total_rtn_in_case := 0;
    OPEN c_get_total_nonoverage_rtn_qty(i_uom, l_rec_type);
    FETCH c_get_total_nonoverage_rtn_qty INTO l_total_rtn_in_case;
    CLOSE c_get_total_nonoverage_rtn_qty;
    IF l_total_rtn_in_case = 0 THEN
      OPEN c_get_total_nonoverage_rtn_qty(NULL, l_rec_type);
      FETCH c_get_total_nonoverage_rtn_qty INTO l_total_rtn_in_case;
      CLOSE c_get_total_nonoverage_rtn_qty;
    END IF;
    o_total_rtn_in_case := l_total_rtn_in_case;
    DBMS_OUTPUT.PUT_LINE('OvrQChk Ttl rtn_cs: ' || TO_CHAR(l_total_rtn_in_case));
    -- For pickup return, user can enter more than originally shipped regardless
    -- of the reason code if it's not a SAP company.
    IF ((l_rec_type <> 'P') OR ((l_rec_type = 'P') AND (gRcTypSyspar.host_type = 'SAP'))) AND NVL(l_total_rtn_in_case, 0) + NVL(i_cur_qty_in_case, 0) > NVL(l_ship_in_case, 0) THEN
      o_qty_exceed  := 1;
    END IF;
  END;
  PROCEDURE p_create_rtn_info(
      i_rf_option   IN VARCHAR2,
      i_which_group IN VARCHAR2,
      i_mispick_upc IN pm.external_upc%TYPE,
      i_rtn_row     IN returns%ROWTYPE,
      PALLET_ID_LEN IN NUMBER,
      o_add_msgs OUT VARCHAR2,
      o_status OUT NUMBER)
  IS
    l_status NUMBER(5)        := ct_sql_success;
    l_rtn_row returns%ROWTYPE := i_rtn_row;
    l_ob_no manifest_dtls.obligation_no%TYPE;
    l_misc reason_cds.misc%TYPE;
    l_reason_group reason_cds.reason_group%TYPE;
    l_valid NUMBER(1) := 0;
    l_misc_disp reason_cds.misc%TYPE;
    l_reason_group_disp reason_cds.reason_group%TYPE;
    l_misp_prod_id pm.prod_id%TYPE;
    l_item_count NUMBER := 0;
    l_split_flag pm.split_trk%TYPE;
    l_spc pm.spc%TYPE;
    l_temp_trk pm.temp_trk%TYPE;
    l_wt_trk pm.catch_wt_trk%TYPE;
    l_ship_qty manifest_dtls.shipped_qty%TYPE;
    l_ship_uom manifest_dtls.shipped_split_cd%TYPE;
    l_cur_rtn_qty       NUMBER(10, 3) := 0;
    l_total_rtn_in_case NUMBER;
    l_ship_in_case      NUMBER;
    l_qty_exceed        NUMBER(1);
    l_add_msg           VARCHAR2(50);
    l_coll_splits       NUMBER;
    l_coll_weight       NUMBER;
    l_putwt_trk pm.catch_wt_trk%TYPE := 'N';
    l_puttemp_trk pm.temp_trk%TYPE   := 'N';
    l_route_no manifests.route_no%TYPE;
    l_stop_no manifest_dtls.stop_no%TYPE;
    l_next_line_id returns.erm_line_id%TYPE;
    l_dest_loc putawaylst.dest_loc%TYPE;
    l_pallet_id putawaylst.pallet_id%TYPE;
    l_descrip pm.descrip%TYPE;
    l_ti pm.ti%TYPE;
    l_hi pm.hi%TYPE;
    l_paltype pm.pallet_type%TYPE;
    l_add_msgs       VARCHAR2(150)                     := NULL;
    l_existed_pickup BOOLEAN                           := FALSE;
    l_pickup_line_id returns.erm_line_id%TYPE          := NULL;
    l_pickup_type returns.rec_type%TYPE                := NULL;
    l_pickup_rtn_qty returns.returned_qty%TYPE         := NULL;
    l_pickup_reason returns.return_reason_cd%TYPE      := NULL;
    l_pickup_reason_group reason_cds.reason_group%TYPE := NULL;
    l_pickup_rtn_prod_id returns.returned_prod_id%TYPE := NULL;
    l_index        NUMBER                                     := 0;
    l_num_tbatches NUMBER                                     := 0;
    l_batch_no batch.batch_no%TYPE                            := NULL;
    l_tbatches pl_rtn_lm.ttabBatches;
    l_message  VARCHAR2(2000) := NULL;
    l_pod_flag VARCHAR2(2);
    CURSOR c_check_open_mf_no(cp_mf_no NUMBER)
    IS
      SELECT 1
      FROM manifests
      WHERE manifest_no    = cp_mf_no
      AND manifest_status <> 'CLS';
    CURSOR c_check_mf_dtl(cp_mf_no NUMBER, cp_ob_no VARCHAR2, cp_prod_id VARCHAR2, cp_cpv VARCHAR2)
    IS
      SELECT obligation_no
      FROM manifest_dtls
      WHERE manifest_no    = cp_mf_no
      AND (obligation_no   = cp_ob_no
      OR orig_invoice      = cp_ob_no)
      AND prod_id          = cp_prod_id
      AND cust_pref_vendor = cp_cpv;
    CURSOR c_get_item_from_extupc(cp_upc VARCHAR2)
    IS
      SELECT DISTINCT prod_id
      FROM pm_upc
      WHERE (external_upc    = cp_upc
      OR internal_upc        = cp_upc)
      AND (external_upc NOT IN ('00000000000000', '99999999999999', 'XXXXXXXXXXXXXX')
      OR internal_upc NOT   IN ('00000000000000', '99999999999999', 'XXXXXXXXXXXXXX'));
    CURSOR c_get_pm_info (cp_prod_id VARCHAR2)
    IS
      SELECT NVL(split_trk, 'N'),
        DECODE(spc, NULL, 1, 0, 1, spc),
        NVL(temp_trk, 'N'),
        NVL(catch_wt_trk, 'N'),
        descrip,
        ti,
        hi,
        pallet_type
      FROM pm
      WHERE prod_id = cp_prod_id;
    CURSOR c_get_route_stop (cp_mf_no NUMBER, cp_ob_no VARCHAR2, cp_prod_id VARCHAR2, cp_cpv VARCHAR2)
    IS
      SELECT m.route_no,
        d.stop_no
      FROM manifests m,
        manifest_dtls d
      WHERE m.manifest_no    = d.manifest_no
      AND d.obligation_no    = cp_ob_no
      AND m.manifest_no      = cp_mf_no
      AND d.prod_id          = cp_prod_id
      AND d.cust_pref_vendor = cp_cpv;
    CURSOR c_get_pickup_info (cp_mf_no NUMBER, cp_ob_no VARCHAR2, cp_prod_id VARCHAR2, cp_cpv VARCHAR2, cp_uom VARCHAR2)
    IS
      SELECT r.erm_line_id,
        r.rec_type,
        r.returned_qty,
        r.return_reason_cd,
        r.returned_prod_id
      FROM returns r
      WHERE r.manifest_no      = cp_mf_no
      AND r.obligation_no      = cp_ob_no
      AND r.prod_id            = cp_prod_id
      AND r.cust_pref_vendor   = cp_cpv
      AND (r.returned_split_cd = cp_uom
      OR r.returned_split_cd  IS NULL);
    CURSOR c_get_notrip_info (cp_mf_no NUMBER, cp_ob_no VARCHAR2, cp_rec_type VARCHAR2, cp_prod_id VARCHAR2, cp_cpv VARCHAR2)
    IS
      SELECT r.erm_line_id,
        r.rec_type,
        r.prod_id,
        r.cust_pref_vendor,
        r.return_reason_cd,
        NVL(r.returned_qty, 0) returned_qty,
        NVL(r.returned_split_cd, r.shipped_split_cd) uom,
        r.disposition
      FROM returns r,
        reason_cds c,
        pm p
      WHERE r.manifest_no           = cp_mf_no
      AND NVL(r.obligation_no, ' ') = NVL(cp_ob_no, ' ')
      AND r.rec_type                = cp_rec_type
      AND c.reason_cd               = r.return_reason_cd
      AND c.reason_cd_type          = 'RTN'
      AND r.prod_id                 = cp_prod_id
      AND r.cust_pref_vendor        = NVL(cp_cpv, DFT_CPV)
      AND r.prod_id                 = p.prod_id
      AND r.cust_pref_vendor        = p.cust_pref_vendor
      AND (r.returned_prod_id      IS NULL
      OR NVL(r.returned_qty, 0)     = 0);
  BEGIN
    o_add_msgs := NULL;
    o_status   := ct_sql_success;
    -- See if manifest # is valid
    IF l_rtn_row.manifest_no IS NULL THEN
      o_status               := ct_mf_required;
      RETURN;
    END IF;
    OPEN c_check_open_mf_no(l_rtn_row.manifest_no);
    FETCH c_check_open_mf_no INTO l_valid;
    IF c_check_open_mf_no%NOTFOUND THEN
      o_status := ct_invalid_mf;
      CLOSE c_check_open_mf_no;
      RETURN;
    END IF;
    CLOSE c_check_open_mf_no;
    dbms_output.put_line('mf[' || TO_CHAR(l_rtn_row.manifest_no) || ']');
    -- See if reason code is valid
    dbms_output.put_line('reason[' || l_rtn_row.return_reason_cd || '] g[' || i_which_group || ']');
    IF l_rtn_row.return_reason_cd IS NULL THEN
      o_status                    := ct_rsn_required;
      RETURN;
    END IF;
    dbms_output.put_line('Ready to check valid reason g[' || i_which_group || '] code[' || l_rtn_row.return_reason_cd || '] m[' || l_misc || '] rg[' || l_reason_group || '] valid[' || TO_CHAR(l_valid) || ']');
    p_check_valid_reason(i_which_group, l_rtn_row.return_reason_cd, l_misc, l_reason_group, l_valid, l_status);
    dbms_output.put_line('reason[' || l_rtn_row.return_reason_cd || '] grp[' || l_reason_group || '] status[' || TO_CHAR(l_status) || ']');
    l_status    := 0;
    l_valid     := 1;
    IF l_status <> ct_sql_success OR l_valid = 0 THEN
      o_status  := ct_invalid_rsn;
      RETURN;
    END IF;
    l_status := ct_sql_success;
    l_valid  := 0;
    l_ob_no  := l_rtn_row.obligation_no;
    dbms_output.put_line('Ob: ' || l_ob_no);
    IF l_reason_group            <> 'OVR' THEN
      IF l_rtn_row.obligation_no IS NULL THEN
        o_status                 := ct_inv_no_required;
        RETURN;
      END IF;
      l_ob_no := NULL;
      OPEN c_check_mf_dtl(l_rtn_row.manifest_no, l_rtn_row.obligation_no, l_rtn_row.prod_id, l_rtn_row.cust_pref_vendor);
      FETCH c_check_mf_dtl INTO l_ob_no;
      IF c_check_mf_dtl%NOTFOUND THEN
        l_valid := 1;
      END IF;
      CLOSE c_check_mf_dtl;
      IF l_valid  = 1 THEN
        o_status := ct_no_mf_info;
        RETURN;
      END IF;
      /* start check pod flag */
      BEGIN
        SELECT NVL(a.POD_Flag,'N')
        INTO l_pod_flag
        FROM manifest_stops a
        WHERE obligation_no    = l_rtn_row.obligation_no
        AND manifest_no        = l_rtn_row.manifest_no;
        IF NVL(l_pod_flag,'N') = 'Y' THEN
          o_status            := ct_mf_is_POD; --ct_no_mf_info;
          pl_log.ins_msg('INFO' , 'p_create_rtn_info', 'pod_flag = ' || l_pod_flag ||', o_status = ' || o_status || 'pod_flag = Y, Stopping the return', SQLCODE, SQLERRM, 'DRIVER CHECK IN', 'pl_rtn_dtls', 'N');
          RETURN;
        END IF;

        pl_log.ins_msg('INFO' , 'p_create_rtn_info', 'pod_flag = ' || l_pod_flag ||', o_status = ' || o_status || 'pod_flag != Y, did not stop the return', SQLCODE, SQLERRM, 'DRIVER CHECK IN', 'pl_rtn_dtls', 'N');

      EXCEPTION
      WHEN OTHERS THEN
        l_pod_flag := 'N';
        pl_log.ins_msg('INFO' , 'p_create_rtn_info', 'In exception POD flag selection, l_pod_flag = ' || l_pod_flag, SQLCODE, SQLERRM, 'DRIVER CHECK IN', 'pl_rtn_dtls', 'N');
      END;
      /* start check pod flag */
      dbms_output.put_line('Ob: ' || l_ob_no || ' input ob: ' || l_rtn_row.obligation_no || ' ty: ' || l_rtn_row.rec_type);
      IF l_ob_no <> l_rtn_row.obligation_no AND l_rtn_row.rec_type = 'P' THEN
        -- User has entered an original invoice# in lieu of pickup invoice#.
        -- Substitute to use pickup invoice# to create new return.
        l_rtn_row.obligation_no := l_ob_no;
      END IF;
    END IF;
    -- Returned quantity is required
    IF NVL(l_rtn_row.returned_qty, 0) = 0 THEN
      o_status                       := ct_qty_required;
      RETURN;
    END IF;
    -- See if disposition code is valid
    IF l_rtn_row.disposition IS NOT NULL THEN
      p_check_valid_reason('D', l_rtn_row.disposition, l_misc_disp, l_reason_group_disp, l_valid, l_status);
      IF l_status <> ct_sql_success OR l_valid = 0 THEN
        o_status  := ct_invalid_disp;
        RETURN;
      END IF;
    END IF;
    dbms_output.put_line('Inv[' || l_rtn_row.obligation_no || '] typ[' || l_rtn_row.rec_type || ']');
    -- Invoice # input should only content alpha-numeric characters
    l_status                   := ct_sql_success;
    IF l_rtn_row.obligation_no IS NOT NULL AND l_rtn_row.rec_type = 'O' THEN
      FOR l_index IN 1..LENGTH(l_rtn_row.obligation_no)
      LOOP
        IF ASCII(SUBSTR(l_rtn_row.obligation_no, l_index, 1)) NOT BETWEEN 48 AND 57 AND ASCII(SUBSTR(l_rtn_row.obligation_no, l_index, 1)) NOT BETWEEN 65 AND 90 AND ASCII(SUBSTR(l_rtn_row.obligation_no, l_index, 1)) NOT BETWEEN 97 AND 122 THEN
          o_status := ct_invalid_invoice_no;
          l_status := ct_invalid_invoice_no;
        END IF;
      END LOOP;
      IF l_status <> ct_sql_success THEN
        RETURN;
      END IF;
    END IF;
    IF l_reason_group IN ('MPR', 'MPK') AND (l_rtn_row.returned_prod_id IS NULL AND i_mispick_upc IS NULL) THEN
      o_status                                                          := ct_mspk_required;
      RETURN;
    END IF;
    -- User enters the mispick item as UPC code. Check if it's valid
    l_status         := ct_sql_success;
    l_misp_prod_id   := l_rtn_row.returned_prod_id;
    IF i_mispick_upc IS NOT NULL THEN
      BEGIN
        SELECT COUNT(DISTINCT prod_id
          || cust_pref_vendor)
        INTO l_item_count
        FROM pm_upc
        WHERE (external_upc    = i_mispick_upc
        OR internal_upc        = i_mispick_upc)
        AND (external_upc NOT IN ('00000000000000', '99999999999999', 'XXXXXXXXXXXXXX')
        OR internal_upc NOT   IN ('00000000000000', '99999999999999', 'XXXXXXXXXXXXXX'));
      EXCEPTION
      WHEN OTHERS THEN
        l_status := ct_invalid_mspk;
      END;
      IF l_item_count    = 0 THEN
        l_status        := ct_invalid_mspk;
      ELSIF l_item_count > 1 THEN
        l_status        := ct_invalid_mspk;
      END IF;
      IF l_status <> ct_sql_success THEN
        o_status  := l_status;
        RETURN;
      END IF;
      IF l_item_count = 1 THEN
        OPEN c_get_item_from_extupc(i_mispick_upc);
        FETCH c_get_item_from_extupc INTO l_misp_prod_id;
        IF c_get_item_from_extupc%NOTFOUND THEN
          l_status := ct_invalid_mspk;
        END IF;
        CLOSE c_get_item_from_extupc;
      END IF;
    END IF;
    IF l_status <> ct_sql_success THEN
      o_status  := l_status;
      RETURN;
    ELSE
      l_rtn_row.returned_prod_id := l_misp_prod_id;
    END IF;
    IF l_reason_group NOT IN ('MPR', 'MPK') THEN
      l_rtn_row.returned_prod_id := l_rtn_row.prod_id;
    END IF;
    dbms_output.put_line('Rtn item[' || l_rtn_row.returned_prod_id || ']');
    -- Retrieve Item Master tracked flags
    OPEN c_get_pm_info(l_rtn_row.returned_prod_id);
    FETCH c_get_pm_info
    INTO l_split_flag,
      l_spc,
      l_temp_trk,
      l_wt_trk,
      l_descrip,
      l_ti,
      l_hi,
      l_paltype;
    IF c_get_pm_info%NOTFOUND THEN
      CLOSE c_get_pm_info;
      o_status := ct_inv_prod_id;
      RETURN;
    END IF;
    CLOSE c_get_pm_info;
    -- Cannot return splits for nonsplitable item if not damage reason
    IF l_split_flag = 'N' AND l_rtn_row.returned_split_cd = '1' AND l_reason_group <> 'DMG' THEN
      o_status     := ct_itm_not_split;
      RETURN;
    END IF;
    l_rtn_row.shipped_qty      := NULL;
    l_rtn_row.shipped_split_cd := l_rtn_row.returned_split_cd;
    IF l_reason_group          <> 'OVR' THEN
      -- Convert current returned qty to case
      l_cur_rtn_qty := l_rtn_row.returned_qty;
      DBMS_OUTPUT.PUT_LINE('Inv Item: ' || l_rtn_row.prod_id || ', Mis Item: ' || l_rtn_row.returned_prod_id || ', spc: ' || TO_CHAR(l_spc) || ', q/u: ' || TO_CHAR(l_rtn_row.returned_qty) || '/' || l_rtn_row.returned_split_cd || ', curq: ' || TO_CHAR(l_cur_rtn_qty));
      IF l_rtn_row.returned_split_cd = '1' THEN
        l_cur_rtn_qty               := l_cur_rtn_qty / l_spc;
      END IF;
      -- Check if return qty > ship qty
      p_get_nonoverage_qty_info (l_rtn_row.manifest_no, l_rtn_row.obligation_no, l_rtn_row.prod_id, l_rtn_row.cust_pref_vendor, l_rtn_row.returned_split_cd, l_cur_rtn_qty, l_ship_qty, l_ship_uom, l_total_rtn_in_case, l_ship_in_case, l_qty_exceed, l_status);
      DBMS_OUTPUT.PUT_LINE('OvrQ Ttl rtnq_cs: ' || TO_CHAR(l_total_rtn_in_case) || ', Shpq_cs: ' || TO_CHAR(l_ship_in_case) || ', status: ' || TO_CHAR(l_status) || ', exceed: ' || TO_CHAR(l_qty_exceed));
      IF l_status <> ct_sql_success THEN
        o_status  := ct_no_mf_info;
        RETURN;
      END IF;
      IF l_qty_exceed             = 1 THEN
        IF gRcTypSyspar.host_type = 'SAP' OR l_reason_group NOT IN ('OVI', 'OVR', 'MPR', 'MPK') THEN
          o_status               := ct_rtn_qtysum_gt_ship;
          RETURN;
        END IF;
      END IF;
      -- If return and shipped are in different uom, warn the user the 1st
      -- time; otherwise, accept whatever the uom is entered.
      IF i_rf_option                    = '1' THEN
        IF (l_rtn_row.returned_split_cd = '1' AND l_ship_uom <> '1') OR (l_rtn_row.returned_split_cd = '0' AND l_ship_uom <> '0') THEN
          o_status                     := ct_ship_diff_uom;
          RETURN;
        END IF;
      END IF;
      l_rtn_row.shipped_qty      := NVL(l_ship_qty, 0);
      l_rtn_row.shipped_split_cd := NVL(l_ship_uom, l_rtn_row.returned_split_cd);
    END IF;
    -- Validate catchweight for returned weight tracked item for specific
    -- reason groups and the RTN_DATA_COLLECTION must be on and total returned
    -- qty (+ current qty) is still less than the ship qty
    l_status   := ct_sql_success;
    IF l_wt_trk = 'Y' AND gRcTypSyspar.rtn_data_collection = 'Y' AND NVL(l_total_rtn_in_case, 0) + NVL(l_cur_rtn_qty, 0) < NVL(l_ship_in_case, 0) AND l_reason_group NOT IN ('DMG', 'STM', 'OVR', 'MPR', 'MPK') THEN
      p_weight_collection(i_rf_option, l_rtn_row.manifest_no, l_rtn_row.obligation_no, l_rtn_row.returned_prod_id, l_rtn_row.cust_pref_vendor, l_rtn_row.returned_qty, l_rtn_row.returned_split_cd, l_rtn_row.catchweight, l_add_msg, l_putwt_trk, l_coll_splits, l_coll_weight, l_status);
      o_add_msgs := l_add_msg;
    END IF;
    IF l_status <> ct_sql_success THEN
      o_status  := l_status;
      RETURN;
    END IF;
    -- Validate temperature for returned temperature tracked item for specific
    -- reason groups
    l_status     := ct_sql_success;
    IF l_temp_trk = 'Y' AND l_reason_group NOT IN ('DMG', 'STM', 'MPK') THEN
      -- Validate temperature which must be a number or include '.'
      IF l_rtn_row.temperature IS NOT NULL THEN
        BEGIN
          SELECT TO_NUMBER(TO_CHAR(l_rtn_row.temperature)) INTO l_index FROM DUAL;
        EXCEPTION
        WHEN OTHERS THEN
          o_status := ct_temp_invalid;
          RETURN;
        END;
      END IF;
      p_temp_collection(i_rf_option, l_rtn_row.manifest_no, l_rtn_row.obligation_no, l_rtn_row.returned_prod_id, l_rtn_row.cust_pref_vendor, l_rtn_row.temperature, l_add_msg, l_puttemp_trk, l_status);
      IF l_status = ct_temp_existed_no_msg THEN
        -- Use existed temperature and not need to notify user
        l_rtn_row.temperature := TO_NUMBER(l_add_msg);
      ELSIF l_status          <> ct_sql_success THEN
        o_status              := l_status;
        o_add_msgs            := l_add_msg;
        RETURN;
      END IF;
    END IF;
    OPEN c_get_pickup_info(l_rtn_row.manifest_no, l_rtn_row.obligation_no, l_rtn_row.prod_id, l_rtn_row.cust_pref_vendor, l_rtn_row.returned_split_cd);
    FETCH c_get_pickup_info
    INTO l_pickup_line_id,
      l_pickup_type,
      l_pickup_rtn_qty,
      l_pickup_reason,
      l_pickup_rtn_prod_id;
    IF c_get_pickup_info%FOUND AND l_pickup_type = 'P' THEN
      IF NVL(l_pickup_rtn_qty, 0)                = 0 THEN
        IF l_rtn_row.returned_qty                = 0 THEN
          -- Existed pickup return has no returned qty and user also enter
          -- 0 qty. Treat it as an error
          o_status := ct_qty_required;
          RETURN;
        END IF;
        -- Otherwise, use the existing line ID
        l_rtn_row.erm_line_id := l_pickup_line_id;
      ELSE
        -- Existed the same pickup with nonzero quantity.
        p_check_valid_reason('A', l_pickup_reason, l_misc, l_pickup_reason_group, l_valid, l_status);
        l_index := 0;
        IF l_pickup_reason_group NOT IN ('STM', 'MPK', 'XXX') THEN
          -- Check if there exists a putaway task which has been putawayed for
          -- the old reason code
          BEGIN
            SELECT 1
            INTO l_index
            FROM putawaylst
            WHERE SUBSTR(rec_id, 2)       = TO_CHAR(l_rtn_row.manifest_no)
            AND lot_id                    = l_rtn_row.obligation_no
            AND (((l_pickup_reason_group <> 'MPR')
            AND (prod_id                  = l_rtn_row.prod_id))
            OR ((l_pickup_reason_group    = 'MPR')
            AND (prod_id                  = l_pickup_rtn_prod_id)))
            AND cust_pref_vendor          = l_rtn_row.cust_pref_vendor
            AND reason_code               = l_pickup_reason
            AND NVL(putaway_put, 'N')     = 'Y'
            AND erm_line_id               = l_pickup_line_id
            AND uom                       = TO_NUMBER(l_rtn_row.returned_split_cd);
          EXCEPTION
          WHEN TOO_MANY_ROWS THEN
            l_index := 1;
          WHEN OTHERS THEN
            l_index := 0;
          END;
        END IF;
        IF l_index = 1 THEN
          -- Existed putaway task has been putawayed on the old reason code
          IF l_rtn_row.returned_qty = 0 THEN
            -- User enters 0 to try to delete the return. Not allow.
            o_status := ct_put_done;
            RETURN;
          END IF;
          -- Otherwise, treat the pickup as another new return
          l_rtn_row.erm_line_id := -1;
        ELSE
          -- Existed pickup return and the pickup hasn't been putawayed yet
          -- or the pickup doesn't need any putaway task
          IF l_pickup_reason_group NOT IN ('STM', 'MPK', 'XXX') OR l_rtn_row.returned_qty = 0 THEN
            IF l_rtn_row.returned_qty                                                     = 0 THEN
              -- User wants to delete this pickup
              l_rtn_row.erm_line_id := l_pickup_line_id;
              BEGIN
                DELETE erd
                WHERE SUBSTR(erm_id, 2)       = TO_CHAR(l_rtn_row.manifest_no)
                AND order_id                  = l_rtn_row.obligation_no
                AND (((l_pickup_reason_group <> 'MPR')
                AND (prod_id                  = l_rtn_row.prod_id))
                OR ((l_pickup_reason_group    = 'MPR')
                AND (prod_id                  = l_pickup_rtn_prod_id)))
                AND cust_pref_vendor          = l_rtn_row.cust_pref_vendor
                AND reason_code               = l_pickup_reason
                AND erm_line_id               = l_pickup_line_id
                AND uom                       = TO_NUMBER(l_rtn_row.returned_split_cd);
              EXCEPTION
              WHEN OTHERS THEN
                NULL;
              END;
              BEGIN
                DELETE putawaylst
                WHERE SUBSTR(rec_id, 2)       = TO_CHAR(l_rtn_row.manifest_no)
                AND lot_id                    = l_rtn_row.obligation_no
                AND (((l_pickup_reason_group <> 'MPR')
                AND (prod_id                  = l_rtn_row.prod_id))
                OR ((l_pickup_reason_group    = 'MPR')
                AND (prod_id                  = l_pickup_rtn_prod_id)))
                AND cust_pref_vendor          = l_rtn_row.cust_pref_vendor
                AND reason_code               = l_pickup_reason
                AND erm_line_id               = l_pickup_line_id
                AND uom                       = TO_NUMBER(l_rtn_row.returned_split_cd);
              EXCEPTION
              WHEN OTHERS THEN
                NULL;
              END;
            ELSE
              -- Existed pickup return and the pickup hasn't been putawayed yet
              -- and user wants to return more qty. Treat it as a new return
              l_rtn_row.erm_line_id := -1;
            END IF;
          END IF;
        END IF;
      END IF;
    END IF;
    CLOSE c_get_pickup_info;
    IF NOT l_existed_pickup THEN
      -- Pickup doesn't exist. This might be a regular return that already
      -- entered from OSD or STS but no tripmaster is done yet.
      FOR cgni IN c_get_notrip_info(l_rtn_row.manifest_no, l_rtn_row.obligation_no, l_rtn_row.rec_type, l_rtn_row.prod_id, l_rtn_row.cust_pref_vendor)
      LOOP
        l_rtn_row.erm_line_id := cgni.erm_line_id;
        l_existed_pickup      := TRUE;
      END LOOP;
    END IF;
    IF l_rtn_row.erm_line_id = -1 THEN
      p_get_next_line_id(l_rtn_row.manifest_no, l_next_line_id, l_status);
      IF l_status <> ct_sql_success THEN
        o_status  := l_status;
        RETURN;
      END IF;
      l_rtn_row.erm_line_id := l_next_line_id;
    ELSE
      l_existed_pickup := TRUE;
    END IF;
    dbms_output.put_line('Ln[' || TO_CHAR(l_rtn_row.erm_line_id) || ']');
    -- Get route and stop #
    OPEN c_get_route_stop(l_rtn_row.manifest_no, l_rtn_row.obligation_no, l_rtn_row.prod_id, l_rtn_row.cust_pref_vendor);
    FETCH c_get_route_stop INTO l_rtn_row.route_no, l_rtn_row.stop_no;
    CLOSE c_get_route_stop;
    -- Update the return info if it existed; otherwise create new one.
    IF l_existed_pickup THEN
      BEGIN
        UPDATE returns
        SET returned_qty     = l_rtn_row.returned_qty,
          returned_split_cd  = l_rtn_row.returned_split_cd,
          returned_prod_id   = l_rtn_row.returned_prod_id,
          return_reason_cd   = l_rtn_row.return_reason_cd,
          shipped_qty        = l_rtn_row.shipped_qty,
          shipped_split_cd   = l_rtn_row.shipped_split_cd,
          catchweight        = l_rtn_row.catchweight,
          disposition        = l_rtn_row.disposition,
          temperature        = l_rtn_row.temperature,
          upd_source         = 'RF'
        WHERE manifest_no    = l_rtn_row.manifest_no
        AND obligation_no    = l_rtn_row.obligation_no
        AND prod_id          = l_rtn_row.prod_id
        AND cust_pref_vendor = l_rtn_row.cust_pref_vendor
        AND erm_line_id      = l_rtn_row.erm_line_id
        AND rec_type         = l_pickup_type;
      EXCEPTION
      WHEN NO_DATA_FOUND THEN
        NULL;
      WHEN OTHERS THEN
        o_status := SQLCODE;
        RETURN;
      END;
    ELSE
      dbms_output.put_line('Ins return route[' || l_rtn_row.route_no || '] stop[' || TO_CHAR(l_rtn_row.stop_no) || ']');
      BEGIN
        INSERT
        INTO returns
          (
            manifest_no,
            route_no,
            stop_no,
            rec_type,
            obligation_no,
            prod_id,
            cust_pref_vendor,
            return_reason_cd,
            returned_qty,
            returned_split_cd,
            catchweight,
            disposition,
            returned_prod_id,
            erm_line_id,
            shipped_qty,
            shipped_split_cd,
            cust_id,
            temperature,
            add_source
          )
          VALUES
          (
            l_rtn_row.manifest_no,
            l_rtn_row.route_no,
            l_rtn_row.stop_no,
            l_rtn_row.rec_type,
            l_rtn_row.obligation_no,
            l_rtn_row.prod_id,
            l_rtn_row.cust_pref_vendor,
            l_rtn_row.return_reason_cd,
            l_rtn_row.returned_qty,
            l_rtn_row.returned_split_cd,
            l_rtn_row.catchweight,
            l_rtn_row.disposition,
            l_rtn_row.returned_prod_id,
            l_rtn_row.erm_line_id,
            l_rtn_row.shipped_qty,
            l_rtn_row.shipped_split_cd,
            l_rtn_row.cust_id,
            l_rtn_row.temperature,
            'RF'
          );
      EXCEPTION
      WHEN DUP_VAL_ON_INDEX THEN
        NULL;
      WHEN OTHERS THEN
        o_status := SQLCODE;
        RETURN;
      END;
    END IF;
    dbms_output.put_line('Before creating ERM ...');
    p_create_return_po (l_rtn_row, l_status);
    IF l_status <> ct_sql_success THEN
      o_status  := l_status;
      RETURN;
    END IF;
    dbms_output.put_line('Before creating PUTAWAY...');
    p_create_putaway_n_inv (l_rtn_row, l_dest_loc, l_pallet_id, l_status);
    IF l_status <> ct_sql_success THEN
      o_status  := ct_no_loc_found;
      RETURN;
    END IF;
    dbms_output.put_line('loc[' || l_dest_loc || '/' || l_pallet_id || ']');
    -- Update the catchweight if needed
    IF l_wt_trk                                                                                                   = 'Y' AND gRcTypSyspar.rtn_data_collection = 'Y' AND l_reason_group NOT IN ('DMG', 'STM', 'OVR', 'MPR', 'MPK') THEN
      IF NVL(l_total_rtn_in_case, 0)                                                     + NVL(l_cur_rtn_qty, 0) >= NVL(l_ship_in_case, 0) THEN
        -- Saved weight qty + current weight qty is >= ship qty. Clear out
        -- the original weight if any
        l_status := f_update_weights('D', l_rtn_row, l_coll_splits, l_coll_weight, NULL);
        l_status := f_update_weights('N', l_rtn_row, l_coll_splits, l_coll_weight, NULL);
      ELSE
        -- Saved weight qty + current weight qty is < ship qty. Weight still
        -- need to be collected
        l_status := f_update_weights(l_putwt_trk, l_rtn_row, l_coll_splits, l_coll_weight, '1');
      END IF;
      IF l_status <> ct_sql_success THEN
        o_status  := l_status;
        RETURN;
      END IF;
    END IF;
    -- Update the temperatures if needed
    IF l_temp_trk  = 'Y' AND l_reason_group NOT IN ('DMG', 'STM', 'MPK') THEN
      l_status    := f_update_temperature (l_puttemp_trk, l_rtn_row.manifest_no, l_rtn_row.obligation_no, l_rtn_row.prod_id, l_rtn_row.cust_pref_vendor, l_rtn_row.returned_prod_id, l_rtn_row.temperature);
      IF l_status <> ct_sql_success THEN
        o_status  := l_status;
        RETURN;
      END IF;
    END IF;
    dbms_output.put_line('Before updating manifest_dtls ...');
    -- Set manifest detail status because the return has been done
    BEGIN
      UPDATE manifest_dtls
      SET manifest_dtl_status = 'RTN'
      WHERE manifest_no       = l_rtn_row.manifest_no
      AND obligation_no       = l_rtn_row.obligation_no
      AND rec_type            = l_rtn_row.rec_type
      AND prod_id             = l_rtn_row.prod_id
      AND cust_pref_vendor    = l_rtn_row.cust_pref_vendor;
    EXCEPTION
    WHEN NO_DATA_FOUND THEN
      NULL;
    WHEN OTHERS THEN
      o_status := SQLCODE;
      RETURN;
    END;
    DBMS_OUTPUT.PUT_LINE('Before creating batch p: ' || l_rtn_row.prod_id || ', rp: ' || l_rtn_row.returned_prod_id || ', loc: ' || l_dest_loc || '/' || l_pallet_id);
    l_batch_no := NULL;
    IF l_reason_group NOT IN ('STM', 'MPK', 'DMG') THEN
      -- Create the T-batch for the new return if syspar flag is set
      pl_rtn_lm.create_rtn_lm_batches(l_pallet_id, l_num_tbatches, l_tbatches, l_message, l_status);
      IF l_status <> ct_sql_success AND l_status <> pl_rtn_lm.CTE_RTN_BTCH_FLG_OFF THEN
        DBMS_OUTPUT.PUT_LINE('After creating batch status: ' || TO_CHAR(l_status));
        IF l_status < 0 THEN
          -- Database error
          o_status := ct_no_lm_batch_found;
        ELSE
          o_status := l_status;
        END IF;
        DBMS_OUTPUT.PUT_LINE('Before returning to caller batch status: ' || TO_CHAR(l_status));
        RETURN;
      END IF;
      IF l_status   = ct_sql_success AND l_tbatches.EXISTS(1) THEN
        l_batch_no := l_tbatches(1).batchNo;
      END IF;
      -- Get the batch # that's newly created or existing one that's not full yet
      IF l_status = ct_sql_success THEN
        FOR l_index IN REVERSE 2 .. l_num_tbatches
        LOOP
          IF l_tbatches(l_index).newBatch = 'Y' THEN
            l_batch_no                   := l_tbatches(l_index).batchNo;
            EXIT
          WHEN l_tbatches(l_index).newBatch = 'Y';
          END IF;
        END LOOP;
        DBMS_OUTPUT.PUT_LINE('Count: ' || TO_CHAR(l_tbatches.COUNT) || ', (1): ' || l_tbatches(1).batchNo);
      END IF;
    END IF;
    -- Everything is ok. Sent back some important information
    --11573   LPN18 changes.
    IF l_reason_group                             IN ('STM', 'MPK') THEN
      l_add_msgs := '|' || RPAD(' ', PALLET_ID_LEN + 10);
      dbms_output.put_line('1st[' || l_add_msgs || '][' || TO_CHAR(LENGTH(l_add_msgs)) || ']');
    ELSE
      l_add_msgs := '|' || RPAD(l_dest_loc, 10) || RPAD(l_pallet_id, PALLET_ID_LEN);
      dbms_output.put_line('2nd[' || l_add_msgs || '][' || TO_CHAR(LENGTH(l_add_msgs)) || ']');
    END IF;
    --END 11573   LPN18 changes.
    o_add_msgs := l_add_msgs || RPAD(l_rtn_row.returned_prod_id, 10) || RPAD(TO_CHAR(l_ti), 10) || RPAD(TO_CHAR(l_hi), 10) || RPAD(l_paltype, 10) || RPAD(l_descrip, 30) || RPAD(l_ob_no, 14) || RPAD(NVL(l_batch_no, ' '), 13) || '|';
    o_status   := ct_sql_success;
  END;
  PROCEDURE p_get_reasons(
      poiNumRsns OUT NUMBER,
      poszRsns OUT ttabRtns,
      poszErrMsg OUT VARCHAR2,
      poiStatus OUT NUMBER)
  IS
    iStatus  NUMBER := ct_sql_success;
    iNumRsns NUMBER := 0;
    szRsns ttabRtns;
    CURSOR c_get_reasons
    IS
      SELECT reason_cd,
        reason_group,
        SUBSTR(reason_desc, 1, 15) reason_desc,
        DECODE(reason_cd, 'R60', 1, 'R30', 2, 'R20', 3, 'W10', 4, 'D20', 5, 'W45', 6, 'T01', 7, 'T30', 8, 'D70', 9, 'R85', 10, 'N01', 11, 12) ord
      FROM reason_cds
      WHERE reason_cd_type IN ('RTN','DIS')
      ORDER BY 4,
        reason_cd;
  BEGIN
    poiNumRsns := 0;
    poszErrMsg := NULL;
    poiStatus  := ct_sql_success;
    FOR cRsn IN c_get_reasons
    LOOP
      BEGIN
        SELECT DECODE(cRsn.reason_group, 'WIN', 'V', 'MPR', 'M', 'MPK', 'M', 'DIS', 'D', 'OVR', 'O', 'I')
        INTO szRsns(iNumRsns + 1).szField1
        FROM DUAL;
      EXCEPTION
      WHEN OTHERS THEN
        iStatus    := ct_mf_process_failed;
        poszErrMsg := 'Error (' || TO_CHAR(SQLCODE) || ') getting return ' || 'reason codes';
        EXIT
      WHEN iStatus <> ct_sql_success;
      END;
      szRsns(iNumRsns                           + 1).szField2 := cRsn.reason_cd;
      szRsns(iNumRsns                           + 1).szField3 := cRsn.reason_desc;
      iNumRsns                      := iNumRsns + 1;
    END LOOP;
    IF iStatus   <> ct_sql_success THEN
      poiNumRsns := 0;
      poiStatus  := iStatus;
    ELSE
      poiNumRsns := iNumRsns;
      poszRsns   := szRsns;
    END IF;
  EXCEPTION
  WHEN OTHERS THEN
    poszErrMsg := 'Error loading reason info ' || '(code ' || TO_CHAR(SQLCODE) || ')';
    poiStatus  := SQLCODE;
  END;
  PROCEDURE p_client_get_reasons2(
      poiNumAllRsns OUT NUMBER,
      poiNumFetchRows OUT NUMBER,
      poszValues OUT VARCHAR2,
      poszErrMsg OUT VARCHAR2,
      poiStatus OUT NUMBER)
  IS
    iStatus  NUMBER := ct_sql_success;
    iNumRsns NUMBER := 0;
    szRsns ttabRtns;
    iIndex     NUMBER;
    szValues   VARCHAR2(1000) := NULL;
    iSkipIndex NUMBER         := 0;
    iGetIndex  NUMBER         := 0;
  BEGIN
    poiNumAllRsns   := 0;
    poiNumFetchRows := 0;
    poszErrMsg      := NULL;
    poiStatus       := ct_sql_success;
    p_get_reasons(iNumRsns, szRsns, poszErrMsg, iStatus);
    IF iStatus    = ct_sql_success THEN
      IF iNumRsns > MAX_KIND THEN
        iNumRsns := MAX_KIND;
      END IF;
      FOR iIndex IN 1 .. iNumRsns
      LOOP
        szValues := szValues || RPAD(szRsns(iIndex).szField1, 1, ' ') || RPAD(szRsns(iIndex).szField2, REASON_CODE_LEN, ' ') || RPAD(szRsns(iIndex).szField3, DESCRIP_LEN / 2, ' ');
      END LOOP;
    END IF;
    poiNumAllRsns   := iNumRsns;
    poiNumFetchRows := iNumRsns;
    poszValues      := szValues;
    poiStatus       := iStatus;
  EXCEPTION
  WHEN OTHERS THEN
    poszErrMsg := 'Error loading reason info for client ' || '(code ' || TO_CHAR(SQLCODE) || ')';
    poiStatus  := SQLCODE;
  END;
  PROCEDURE p_client_get_reasons(
      piCurPg     IN NUMBER,
      piNumsPerPg IN NUMBER,
      poiNumAllRsns OUT NUMBER,
      poiNumFetchRows OUT NUMBER,
      poszValues OUT ttabValues,
      poszErrMsg OUT VARCHAR2,
      poiStatus OUT NUMBER)
  IS
    iStatus  NUMBER := ct_sql_success;
    iNumRsns NUMBER := 0;
    szRsns ttabRtns;
    iIndex NUMBER;
    szValues ttabValues;
    iSkipIndex NUMBER := 0;
    iGetIndex  NUMBER := 0;
  BEGIN
    poiNumAllRsns   := 0;
    poiNumFetchRows := 0;
    poszErrMsg      := NULL;
    poiStatus       := ct_sql_success;
    p_get_reasons(iNumRsns, szRsns, poszErrMsg, iStatus);
    IF iStatus    = ct_sql_success THEN
      IF iNumRsns > MAX_KIND THEN
        iNumRsns := MAX_KIND;
      END IF;
      FOR iIndex IN 1 .. iNumRsns
      LOOP
        IF (iSkipIndex < piCurPg - piNumsPerPg) AND (piCurPg <> piNumsPerPg) THEN
          -- Skip all previously retrieved values until the current client page
          -- is reached
          iSkipIndex    := iSkipIndex + 1;
        ELSIF (iGetIndex < piNumsPerPg) OR (piNumsPerPg = 0) THEN
          -- Retrieve all values pertaining to the current client page or all
          -- values regardless if piNumsPerPg is 0 (means unlimited.)
          iGetIndex           := iGetIndex                                                                                                                                 + 1;
          szValues(iGetIndex) := RPAD(szRsns(iIndex).szField1, 1, ' ') || RPAD(szRsns(iIndex).szField2, REASON_CODE_LEN, ' ') || RPAD(szRsns(iIndex).szField3, DESCRIP_LEN / 2, ' ');
        ELSE
          RETURN;
        END IF;
      END LOOP;
    END IF;
    poiNumAllRsns   := iNumRsns;
    poiNumFetchRows := iGetIndex;
    poszValues      := szValues;
    poiStatus       := iStatus;
  EXCEPTION
  WHEN OTHERS THEN
    poszErrMsg := 'Error loading reason info for client ' || '(code ' || TO_CHAR(SQLCODE) || ')';
    poiStatus  := SQLCODE;
  END;
  PROCEDURE p_get_multi_items(
      pszMfNo IN VARCHAR2,
      pszUpc  IN pm.external_upc%TYPE,
      poiNumItems OUT NUMBER,
      poszItems OUT ttabRtns,
      poszErrMsg OUT VARCHAR2,
      poiStatus OUT NUMBER)
  IS
    iNumItems NUMBER := 0;
    szItems ttabRtns;
    iStatus     NUMBER := ct_sql_success;
    iNumPmItems NUMBER;
    CURSOR c_get_items(cpszUpc pm.external_upc%TYPE)
    IS
      SELECT DISTINCT p.prod_id pm_prod,
        p.cust_pref_vendor,
        p.descrip,
        d.prod_id dtl_prod
      FROM manifests m,
        manifest_dtls d,
        pm_upc u,
        pm p
      WHERE m.manifest_no (+)    = d.manifest_no
      AND m.manifest_status (+) <> 'CLS'
      AND d.prod_id (+)          = u.prod_id
      AND d.cust_pref_vendor (+) = u.cust_pref_vendor
      AND (u.external_upc        = cpszUpc
      OR u.internal_upc          = cpszUpc)
      AND (u.external_upc NOT   IN ('00000000000000', '99999999999999', 'XXXXXXXXXXXXXX')
      OR u.internal_upc NOT     IN ('00000000000000', '99999999999999', 'XXXXXXXXXXXXXX'))
      AND p.prod_id              = u.prod_id
      AND p.cust_pref_vendor     = u.cust_pref_vendor
      ORDER BY p.prod_id;
  BEGIN
    poiNumItems                := 0;
    poszErrMsg                 := NULL;
    poiStatus                  := ct_sql_success;
    IF check_mf_no(pszMfNo, 1) <> ct_sql_success AND check_mf_no(pszMfNo, 2) <> ct_sql_success THEN
      poiStatus                := ct_invalid_mf;
      poszErrMsg               := 'Manifest ' || pszMfNo || ' is not available for UPC ' || 'query (code ' || TO_CHAR(SQLCODE) || ')';
      RETURN;
    END IF;
    iNumPmItems := 0;
    iNumItems   := 0;
    FOR cItems IN c_get_items(pszUpc)
    LOOP
      iNumItems          := iNumItems + 1;
      IF cItems.dtl_prod IS NULL THEN
        iNumPmItems      := iNumPmItems + 1;
      END IF;
    END LOOP;
    IF iNumItems = 1 AND iNumPmItems = 1 THEN
      -- Only one item related to the input UPC and the item is not in any
      -- OPN manifest detail. Send the PM item back to caller and notify it that
      -- maybe overage or mispick processing is needed.
      iStatus := ct_invalid_upc;
    END IF;
    -- Save the item information to output arrays of records
    iNumItems := 0;
    FOR cItems IN c_get_items(pszUpc)
    LOOP
      iNumItems                   := iNumItems + 1;
      szItems(iNumItems).szField1 := cItems.pm_prod;
      szItems(iNumItems).szField2 := cItems.cust_pref_vendor;
      szItems(iNumItems).szField3 := cItems.descrip;
    END LOOP;
    -- If nothing is found
    IF iStatus    = ct_sql_success AND iNumItems = 0 THEN
      poszErrMsg := 'Cannot find any item related to UPC ' || pszUpc;
      iStatus    := ct_sql_no_data_found;
    END IF;
    poiNumItems := iNumItems;
    poszItems   := szItems;
    poiStatus   := iStatus;
  EXCEPTION
  WHEN OTHERS THEN
    poiStatus  := ct_sql_no_data_found;
    poszErrMsg := 'Cannot find any item related to UPC ' || pszUpc || ' for client (code: ' || TO_CHAR(SQLCODE) || ')';
  END;
  PROCEDURE p_client_get_multi_items(
      pszMfNo     IN VARCHAR2,
      pszUpc      IN pm.external_upc%TYPE,
      piCurPg     IN NUMBER,
      piNumsPerPg IN NUMBER,
      poiNumAllItems OUT NUMBER,
      poiNumFetchRows OUT NUMBER,
      poszValues OUT ttabValues,
      poszErrMsg OUT VARCHAR2,
      poiStatus OUT NUMBER)
  IS
    iNumItems NUMBER := 0;
    szItems ttabRtns;
    szValues ttabValues;
    iStatus    NUMBER := ct_sql_success;
    iIndex     NUMBER;
    iSkipIndex NUMBER := 0;
    iGetIndex  NUMBER := 0;
  BEGIN
    poiNumAllItems  := 0;
    poiNumFetchRows := 0;
    poszErrMsg      := NULL;
    poiStatus       := ct_sql_success;
    p_get_multi_items(pszMfNo, pszUpc, iNumItems, szItems, poszErrMsg, iStatus);
    IF iStatus IN (ct_sql_success, ct_invalid_upc) THEN
      IF iNumItems > MAX_KIND THEN
        iNumItems := MAX_KIND;
      END IF;
      FOR iIndex IN 1 .. iNumItems
      LOOP
        IF (iSkipIndex < piCurPg - piNumsPerPg) AND (piCurPg <> piNumsPerPg) THEN
          -- Skip all previously retrieved values until the current client page
          -- is reached
          iSkipIndex    := iSkipIndex + 1;
        ELSIF (iGetIndex < piNumsPerPg) OR (piNumsPerPg = 0) THEN
          -- Retrieve all values pertaining to the current client page or all
          -- values regardless if piNumsPerPg is 0 (means unlimited.)
          iGetIndex           := iGetIndex            + 1;
          szValues(iGetIndex) := RPAD(TO_CHAR(piCurPg - piNumsPerPg + iGetIndex), LINE_NO_LEN, ' ') || RPAD(szItems(iIndex).szField1, PROD_ID_LEN, ' ') || RPAD(szItems(iIndex).szField2, CPV_LEN, ' ') || RPAD(szItems(iIndex).szField3, DESCRIP_LEN / 2 + 5, ' ');
        ELSE
          RETURN;
        END IF;
      END LOOP;
    END IF;
    poiNumAllItems  := iNumItems;
    poiNumFetchRows := iGetIndex;
    poszValues      := szValues;
    poiStatus       := iStatus;
  EXCEPTION
  WHEN OTHERS THEN
    poszErrMsg := 'Cannot find any item related to UPC ' || pszUpc || ', (code: ' || TO_CHAR(SQLCODE) || ')';
    poiStatus  := SQLCODE;
  END;
  PROCEDURE p_get_invs_list(
      pszMfNo IN VARCHAR2,
      pszItem IN pm.prod_id%TYPE,
      pszCpv  IN pm.cust_pref_vendor%TYPE,
      poiNumInvs OUT NUMBER,
      poszInvs OUT ttabRtns,
      poszErrMsg OUT VARCHAR2,
      poiStatus OUT NUMBER)
  IS
    szCpv pm.cust_pref_vendor%TYPE := pszCpv;
    iNumInvs NUMBER                := 0;
    szInvs ttabRtns;
    CURSOR c_get_upc_invs
    IS
      SELECT DISTINCT d.obligation_no,
        d.shipped_split_cd
      FROM manifests m,
        manifest_dtls d
      WHERE m.manifest_no    = d.manifest_no
      AND m.manifest_status  = 'OPN'
      AND d.prod_id          = pszItem
      AND d.cust_pref_vendor = pszCpv
      AND m.manifest_no      = TO_NUMBER(pszMfNo)
      ORDER BY d.obligation_no DESC,
        d.shipped_split_cd ASC;
  BEGIN
    poiNumInvs              := 0;
    poszErrMsg              := NULL;
    poiStatus               := ct_sql_success;
    IF LTRIM(RTRIM(pszCpv)) IS NULL THEN
      szCpv                 := DFT_CPV;
    END IF;
    IF LTRIM(RTRIM(pszMfNo))   IS NULL OR check_mf_no(pszMfNo) <> ct_sql_success THEN
      IF LTRIM(RTRIM(pszMfNo)) IS NULL THEN
        poszErrMsg             := 'Manifest # input is required';
        poiStatus              := ct_mf_required;
      ELSE
        poszErrMsg := 'Manifest # is invalid';
        poiStatus  := ct_invalid_mf;
      END IF;
      RETURN;
    END IF;
    iNumInvs := 0;
    FOR cUpcInv IN c_get_upc_invs
    LOOP
      iNumInvs                  := iNumInvs + 1;
      szInvs(iNumInvs).szField1 := cUpcInv.obligation_no;
      szInvs(iNumInvs).szField2 := cUpcInv.shipped_split_cd;
    END LOOP;
    poiNumInvs  := iNumInvs;
    poszInvs    := szInvs;
    IF iNumInvs  = 0 THEN
      poiStatus := ct_invalid_upc;
    ELSE
      poiStatus := ct_sql_success;
    END IF;
  END;
  PROCEDURE p_client_get_invs_list(
      pszMfNo     IN VARCHAR2,
      pszItem     IN pm.prod_id%TYPE,
      pszCpv      IN pm.cust_pref_vendor%TYPE,
      piCurPg     IN NUMBER,
      piNumsPerPg IN NUMBER,
      poiNumAllInvs OUT NUMBER,
      poiNumFetchRows OUT NUMBER,
      poszValues OUT ttabValues,
      poszErrMsg OUT VARCHAR2,
      poiStatus OUT NUMBER)
  IS
    iNumInvs NUMBER := 0;
    szInvs ttabRtns;
    szValues ttabValues;
    iStatus    NUMBER := ct_sql_success;
    iIndex     NUMBER;
    iSkipIndex NUMBER := 0;
    iGetIndex  NUMBER := 0;
  BEGIN
    poiNumAllInvs   := 0;
    poiNumFetchRows := 0;
    poszErrMsg      := NULL;
    poiStatus       := ct_sql_success;
    p_get_invs_list(pszMfNo, pszItem, pszCpv, iNumInvs, szInvs, poszErrMsg, iStatus);
    IF iStatus    = ct_sql_success THEN
      IF iNumInvs > MAX_KIND THEN
        iNumInvs := MAX_KIND;
      END IF;
      FOR iIndex IN 1 .. iNumInvs
      LOOP
        IF (iSkipIndex < piCurPg - piNumsPerPg) AND (piCurPg <> piNumsPerPg) THEN
          -- Skip all previously retrieved values until the current client page
          -- is reached
          iSkipIndex    := iSkipIndex + 1;
        ELSIF (iGetIndex < piNumsPerPg) OR (piNumsPerPg = 0) THEN
          -- Retrieve all values pertaining to the current client page or all
          -- values regardless if piNumsPerPg is 0 (means unlimited.)
          iGetIndex           := iGetIndex            + 1;
          szValues(iGetIndex) := RPAD(TO_CHAR(piCurPg - piNumsPerPg + iGetIndex), LINE_NO_LEN, ' ') || RPAD(szInvs(iIndex).szField1, INV_NO_LEN, ' ') || RPAD(szInvs(iIndex).szField2, UOM_LEN, ' ');
        ELSE
          RETURN;
        END IF;
      END LOOP;
    END IF;
    poiNumAllInvs   := iNumInvs;
    poiNumFetchRows := iGetIndex;
    poszValues      := szValues;
    poiStatus       := iStatus;
  EXCEPTION
  WHEN OTHERS THEN
    poszErrMsg := 'Cannot find any invoice related to manifest ' || pszMfNo || ', item: ' || pszItem || '/' || pszCpv || ', (code: ' || TO_CHAR(SQLCODE) || ')';
    poiStatus  := SQLCODE;
  END;
  PROCEDURE p_get_mf_info(
      pszRoute IN route.route_no%TYPE,
      piStop   IN manifest_dtls.stop_no%TYPE,
      pszInvNo IN manifest_dtls.obligation_no%TYPE,
      pszItem  IN pm.prod_id%TYPE,
      pszCpv   IN pm.cust_pref_vendor%TYPE,
      pszUom   IN manifest_dtls.shipped_split_cd%TYPE,
      poiMfNo OUT manifests.manifest_no%TYPE,
      poszRecType OUT manifest_dtls.rec_type%TYPE,
      poszErrMsg OUT VARCHAR2,
      poiStatus OUT NUMBER)
  IS
    iMfNo manifests.manifest_no%TYPE;
    iExists  BOOLEAN;
    iShipQty NUMBER                               := 0;
    szShipUom manifest_dtls.shipped_split_cd%TYPE := NULL;
    iDummyQty  NUMBER                              := 0;
    iExceedQty NUMBER                              := 0;
    iStatus    NUMBER                              := ct_sql_success;
    CURSOR c_get_mf_info(cpRoute route.route_no%TYPE, cpStop manifest_dtls.stop_no%TYPE)
    IS
      SELECT m.manifest_no,
        m.manifest_status,
        d.manifest_dtl_status,
        d.obligation_no,
        d.orig_invoice,
        d.rec_type
      FROM manifests m,
        manifest_dtls d
      WHERE m.manifest_no    = d.manifest_no
      AND (d.obligation_no   = pszInvNo
      OR d.orig_invoice      = pszInvNo)
      AND d.prod_id          = pszItem
      AND d.cust_pref_vendor = pszCpv
        /* CRQ35354 bgul2852 */
        -- AND   d.shipped_split_cd = pszUom
      AND (d.shipped_split_cd = pszUom
      OR d.shipped_split_cd   ='0')
      AND ((cpRoute          IS NULL)
      OR ((cpRoute           IS NOT NULL)
      AND (m.route_no         = cpRoute)
      AND (d.stop_no          = cpStop)));
  BEGIN
    poiMfNo     := NULL;
    poszRecType := NULL;
    poszErrMsg  := NULL;
    poiStatus   := ct_sql_success;
    iExists     := FALSE;
    FOR cMfInfo IN c_get_mf_info(LTRIM(RTRIM(pszRoute)), piStop)
    LOOP
      iExists := TRUE;
      iStatus := ct_sql_success;
      IF cMfInfo.manifest_status IN ('CLS', 'PAD') THEN
        IF cMfInfo.manifest_status = 'CLS' THEN
          poiStatus               := ct_mf_has_closed;
        ELSE
          poiStatus := ct_manifest_pad;
        END IF;
        RETURN;
      END IF;
      -- Don't need total return in case and ship in case (iDummyQty)
      p_get_nonoverage_qty_info(cMfInfo.manifest_no, cMfInfo.obligation_no, pszItem, pszCpv, pszUom, 0, iShipQty, szShipUom, iDummyQty, iDummyQty, iExceedQty, iStatus);
      IF iStatus  <> ct_sql_success THEN
        poiStatus := iStatus;
        RETURN;
      END IF;
      poiMfNo      := cMfInfo.manifest_no;
      poszRecType  := cMfInfo.rec_type;
      IF iExceedQty = 1 THEN
        poiStatus  := ct_rtn_qtysum_gt_ship;
        RETURN;
      END IF;
    END LOOP;
    IF NOT iExists AND iStatus = ct_sql_success THEN
      poiStatus               := ct_no_mf_info;
      RETURN;
    ELSE
      poiStatus := iStatus;
    END IF;
  EXCEPTION
  WHEN OTHERS THEN
    poszErrMsg := 'Cannot get mf info related to invoice ' || pszInvNo || ', item: ' || pszItem || '/' || pszCpv || ', (code: ' || TO_CHAR(SQLCODE) || ')';
    poiStatus  := SQLCODE;
  END;
  PROCEDURE p_get_rtn_info(
      piMfNo     IN manifests.manifest_no%TYPE,
      pszInvNo   IN manifest_dtls.obligation_no%TYPE,
      pszRecType IN manifest_dtls.rec_type%TYPE,
      pszItem    IN pm.prod_id%TYPE,
      pszCpv     IN pm.cust_pref_vendor%TYPE,
      poiNumAllRtns OUT NUMBER,
      poszRtns OUT ttabRtns,
      poszErrMsg OUT VARCHAR2,
      poiStatus OUT NUMBER)
  IS
    szInvNo manifest_dtls.obligation_no%TYPE := pszInvNo;
    iNumRtns NUMBER;
    szRtns ttabRtns;
    CURSOR c_get_rtns (cpInvNo manifest_dtls.obligation_no%TYPE)
    IS
      /* All returns with invoices which have putaway tasks */
      SELECT r.rec_type,
        r.obligation_no,
        r.return_reason_cd,
        NVL(r.returned_qty, 0) returned_qty,
        r.returned_split_cd uom,
        r.catchweight,
        r.disposition,
        NVL(r.returned_prod_id, r.prod_id) returned_prod_id,
        r.erm_line_id,
        r.temperature,
        pt.dest_loc dest_loc,
        pt.pallet_id pallet_id,
        p.descrip,
        p.ti,
        p.hi,
        p.pallet_type,
        DECODE(pt.rtn_label_printed, NULL, 'N', ' ', 'N', pt.rtn_label_printed) rtn_label_printed,
        SUBSTR(pt.parent_pallet_id, 1, TBATCH_LEN) parent_pallet_id
      FROM returns r,
        putawaylst pt,
        reason_cds rc,
        pm p
      WHERE r.manifest_no      = piMfNo
      AND r.obligation_no      = cpInvNo
      AND r.rec_type           = NVL(pszRecType, r.rec_type)
      AND r.prod_id            = pszItem
      AND r.cust_pref_vendor   = pszCpv
      AND rc.reason_cd_type    = 'RTN'
      AND rc.reason_cd         = r.return_reason_cd
      AND SUBSTR(pt.rec_id, 2) = TO_CHAR(piMfNo)
      AND pt.lot_id            = r.obligation_no
      AND pt.reason_code       = r.return_reason_cd
      AND pt.prod_id           = DECODE(rc.reason_group, 'MPR', r.returned_prod_id, 'MPK', r.returned_prod_id, r.prod_id)
      AND pt.cust_pref_vendor  = DECODE(rc.reason_group, 'MPR', pt.cust_pref_vendor, 'MPK', pt.cust_pref_vendor, r.cust_pref_vendor)
      AND pt.erm_line_id       = r.erm_line_id
      AND p.prod_id            = DECODE(rc.reason_group, 'MPR', r.returned_prod_id, 'MPK', r.returned_prod_id, r.prod_id)
      AND p.cust_pref_vendor   = DECODE(rc.reason_group, 'MPR', pt.cust_pref_vendor, 'MPK', pt.cust_pref_vendor, r.cust_pref_vendor)
    UNION ALL

    /* All returns with invoices which have no putaway tasks */
    /* For those returns that have no quantity or have quantity but */
    /* don't need putaway tasks, print flags are set to '_'s. */
    /* Otherwise, set print flags to 'T's to denote tripmaster is needed */
    SELECT r.rec_type,
      r.obligation_no,
      r.return_reason_cd,
      NVL(r.returned_qty, 0) returned_qty,
      r.returned_split_cd uom,
      r.catchweight,
      r.disposition,
      NVL(r.returned_prod_id, r.prod_id) returned_prod_id,
      r.erm_line_id,
      r.temperature,
      ' ' dest_loc,
      ' ' pallet_id,
      p.descrip,
      p.ti,
      p.hi,
      p.pallet_type,
      DECODE(rc.reason_group, 'MPK', '_', 'STM', '_', 'T') rtn_label_printed,
      ' ' parent_pallet_id
    FROM returns r,
      reason_cds rc,
      pm p
    WHERE r.manifest_no         = piMfNo
    AND r.obligation_no         = cpInvNo
    AND r.rec_type              = NVL(pszRecType, r.rec_type)
    AND r.prod_id               = pszItem
    AND r.cust_pref_vendor      = pszCpv
    AND NVL(r.returned_qty, 0) <> 0
    AND rc.reason_cd_type       = 'RTN'
    AND rc.reason_cd            = r.return_reason_cd
    AND p.prod_id               = DECODE(rc.reason_group, 'MPR', r.returned_prod_id, 'MPK', r.returned_prod_id, r.prod_id)
    AND p.cust_pref_vendor      = r.cust_pref_vendor
    AND NOT EXISTS
      (SELECT NULL
      FROM putawaylst pt
      WHERE SUBSTR(pt.rec_id, 2) = TO_CHAR(piMfNo)
      AND pt.lot_id              = r.obligation_no
      AND pt.reason_code         = r.return_reason_cd
      AND pt.prod_id             = DECODE(rc.reason_group, 'MPR', r.returned_prod_id, 'MPK', r.returned_prod_id, r.prod_id)
      AND pt.cust_pref_vendor    = DECODE(rc.reason_group, 'MPR', pt.cust_pref_vendor, 'MPK', pt.cust_pref_vendor, r.cust_pref_vendor)
      AND pt.erm_line_id         = r.erm_line_id
      )
    UNION ALL
    SELECT r.rec_type,
      r.obligation_no,
      r.return_reason_cd,
      NVL(r.returned_qty, 0) returned_qty,
      r.returned_split_cd uom,
      r.catchweight,
      r.disposition,
      NVL(r.returned_prod_id, r.prod_id) returned_prod_id,
      r.erm_line_id,
      r.temperature,
      ' ' dest_loc,
      ' ' pallet_id,
      ' ' descrip,
      0 ti,
      0 hi,
      ' ' pallet_type,
      '_' rtn_label_printed,
      ' ' parent_pallet_id
    FROM returns r,
      reason_cds rc
    WHERE r.manifest_no        = piMfNo
    AND r.obligation_no        = cpInvNo
    AND r.rec_type             = NVL(pszRecType, r.rec_type)
    AND r.prod_id              = pszItem
    AND r.cust_pref_vendor     = pszCpv
    AND NVL(r.returned_qty, 0) = 0
    AND rc.reason_cd_type      = 'RTN'
    AND rc.reason_cd           = r.return_reason_cd
    AND NOT EXISTS
      (SELECT NULL
      FROM putawaylst pt
      WHERE SUBSTR(pt.rec_id, 2) = TO_CHAR(piMfNo)
      AND pt.lot_id              = r.obligation_no
      AND pt.reason_code         = r.return_reason_cd
      AND pt.prod_id             = DECODE(rc.reason_group, 'MPR', r.returned_prod_id, 'MPK', r.returned_prod_id, r.prod_id)
      AND pt.cust_pref_vendor    = DECODE(rc.reason_group, 'MPR', pt.cust_pref_vendor, 'MPK', pt.cust_pref_vendor, r.cust_pref_vendor)
      AND pt.erm_line_id         = r.erm_line_id
      )
    ORDER BY 17,
      9;
  BEGIN
    poiNumAllRtns := 0;
    poszErrMsg    := NULL;
    poiStatus     := ct_sql_success;
    -- Check if input manifest is valid
    IF check_mf_no(TO_CHAR(piMfNo)) <> ct_sql_success THEN
      poiStatus                     := ct_invalid_mf;
      poszErrMsg                    := 'Invalid input manifest #: ' || TO_CHAR(piMfNo);
      RETURN;
    END IF;
    -- Get the real invoice # since the input invoice # might be the real invoice
    -- # or the original invoice #
    -- 12/19/05 - prphqb - avoid two many rows return from 2 records in manifest_dtls
    BEGIN
      SELECT DISTINCT obligation_no
      INTO szInvNo
      FROM manifest_dtls
      WHERE manifest_no    = piMfNo
      AND (obligation_no   = pszInvNo
      OR orig_invoice      = pszInvNo)
      AND prod_id          = pszItem
      AND cust_pref_vendor = pszCpv;
    EXCEPTION
    WHEN OTHERS THEN
      poiStatus  := ct_no_mf_info;
      poszErrMsg := 'No info found for manifest #: ' || TO_CHAR(piMfNo) || ', item: ' || pszItem || '/' || pszCpv;
      RETURN;
    END;
    iNumRtns := 0;
    FOR cRtn IN c_get_rtns(szInvNo)
    LOOP
      iNumRtns                   := iNumRtns + 1;
      szRtns(iNumRtns).szField1  := cRtn.rec_type;
      szRtns(iNumRtns).szField2  := cRtn.obligation_no;
      szRtns(iNumRtns).szField3  := cRtn.return_reason_cd;
      szRtns(iNumRtns).szField4  := TO_CHAR(cRtn.returned_qty);
      szRtns(iNumRtns).szField5  := cRtn.uom;
      szRtns(iNumRtns).szField6  := TO_CHAR(cRtn.catchweight);
      szRtns(iNumRtns).szField7  := cRtn.disposition;
      szRtns(iNumRtns).szField8  := cRtn.returned_prod_id;
      szRtns(iNumRtns).szField9  := TO_CHAR(cRtn.erm_line_id);
      szRtns(iNumRtns).szField10 := TO_CHAR(cRtn.temperature);
      szRtns(iNumRtns).szField11 := cRtn.dest_loc;
      szRtns(iNumRtns).szField12 := cRtn.pallet_id;
      szRtns(iNumRtns).szField13 := cRtn.descrip;
      szRtns(iNumRtns).szField14 := TO_CHAR(cRtn.ti);
      szRtns(iNumRtns).szField15 := TO_CHAR(cRtn.hi);
      szRtns(iNumRtns).szField16 := cRtn.pallet_type;
      szRtns(iNumRtns).szField17 := cRtn.rtn_label_printed;
      szRtns(iNumRtns).szField18 := cRtn.parent_pallet_id;
    END LOOP;
    poiNumAllRtns := iNumRtns;
    poszRtns      := szRtns;
    poiStatus     := ct_sql_success;
  EXCEPTION
  WHEN OTHERS THEN
    poszErrMsg := 'Cannot get rtn info related to mf ' || TO_CHAR(piMfNo) || ', invoice ' || pszInvNo || ', item: ' || pszItem || '/' || pszCpv || ', (code: ' || TO_CHAR(SQLCODE) || ')';
    poiStatus  := SQLCODE;
  END;
  PROCEDURE p_client_get_rtn_info(
      piMfNo          IN manifests.manifest_no%TYPE,
      pszInvNo        IN manifest_dtls.obligation_no%TYPE,
      pszRecType      IN manifest_dtls.rec_type%TYPE,
      pszItem         IN pm.prod_id%TYPE,
      pszCpv          IN pm.cust_pref_vendor%TYPE,
      piLPLen         IN NUMBER,
      piNumFixedLines IN NUMBER,
      piCurPg         IN NUMBER,
      piNumsPerPg     IN NUMBER,
      poiNumAllRtns OUT NUMBER,
      poiNumFetchRows OUT NUMBER,
      poszValues OUT ttabValues,
      poszErrMsg OUT VARCHAR2,
      poiStatus OUT NUMBER)
  IS
    iLine      NUMBER := 0;
    iIndex     NUMBER;
    iSkipIndex NUMBER := 0;
    iGetIndex  NUMBER := 0;
    iNumRtns   NUMBER := 0;
    szRtns ttabRtns;
    szValues ttabValues;
    iStatus        NUMBER := ct_sql_success;
    iMaxPg         NUMBER;
    iNumFixedLines NUMBER := piNumFixedLines;
  BEGIN
    poiNumAllRtns   := 0;
    poiNumFetchRows := 0;
    poszErrMsg      := NULL;
    poiStatus       := ct_sql_success;
    p_get_rtn_info(piMfNo, pszInvNo, pszRecType, pszItem, pszCpv, iNumRtns, szRtns, poszErrMsg, iStatus);
    IF iStatus    = ct_sql_success THEN
      IF iNumRtns > MAX_KIND THEN
        iNumRtns := MAX_KIND;
      END IF;
      IF iNumFixedLines   IS NULL OR iNumFixedLines < 0 THEN
        iNumFixedLines    := 0;
      ELSIF iNumFixedLines > piNumsPerPg THEN
        iNumFixedLines    := piNumsPerPg;
      END IF;
      iGetIndex  := 1;
      iMaxPg     := piNumsPerPg;
      IF piCurPg <> piNumsPerPg THEN
        -- Since the client screen might have some number of fixed lines that
        -- will display fixed set of values (like 1. New rtn), we will set the
        -- the number of database lines to skip if it's not in the 1st page.
        iSkipIndex := iNumFixedLines;
        iMaxPg     := iMaxPg + 1;
      END IF;
      FOR iIndex IN 1 .. iNumRtns
      LOOP
        IF (iSkipIndex < piCurPg - piNumsPerPg) AND (piCurPg <> piNumsPerPg) THEN
          -- Skip all previously retrieved values until the current client page
          -- is reached
          iSkipIndex    := iSkipIndex + 1;
        ELSIF (iGetIndex < iMaxPg) OR (piNumsPerPg = 0) THEN
          -- Retrieve all values pertaining to the current client page or all
          -- values regardless if piNumsPerPg is 0 (means unlimited.)
          iLine               := piCurPg - piNumsPerPg + iGetIndex + 1;
          szValues(iGetIndex) := RPAD(TO_CHAR(iLine), LINE_NO_LEN, ' ') || RPAD(szRtns(iIndex).szField1, REC_TYPE_LEN, ' ') || RPAD(szRtns(iIndex).szField2, INV_NO_LEN, ' ') || RPAD(szRtns(iIndex).szField3, REASON_CODE_LEN, ' ') || RPAD(NVL(szRtns(iIndex).szField4, ' '), QTY_LEN, ' ') || RPAD(NVL(szRtns(iIndex).szField5, ' '), UOM_LEN, ' ') || RPAD(NVL(szRtns(iIndex).szField6, ' '), WEIGHT_LEN,' ') || RPAD(NVL(szRtns(iIndex).szField7, ' '), REASON_CODE_LEN, ' ') || RPAD(NVL(szRtns(iIndex).szField8, ' '), UPC_LEN, ' ') || RPAD(NVL(szRtns(iIndex).szField9, ' '), LINE_ID_LEN, ' ') || RPAD(NVL(szRtns(iIndex).szField10, ' '), TEMP_LEN, ' ') || RPAD(NVL(szRtns(iIndex).szField11, ' '), LOC_LEN, ' ') || RPAD(NVL(szRtns(iIndex).szField12, ' '), piLPLen, ' ') || RPAD(NVL(szRtns(iIndex).szField13, ' '), DESCRIP_LEN, ' ') || RPAD(NVL(szRtns(iIndex).szField14, ' '), TIHI_LEN, ' ') || RPAD(NVL(szRtns(iIndex).szField15, ' '), TIHI_LEN, ' ') || RPAD(NVL(szRtns(iIndex).szField16, ' '), PAL_TYPE_LEN,
          ' ') || RPAD(NVL(szRtns(iIndex).szField17, ' '), ONE_LEN, ' ') || RPAD(NVL(szRtns(iIndex).szField18, ' '), TBATCH_LEN, ' ');
          iGetIndex := iGetIndex + 1;
        ELSE
          RETURN;
        END IF;
      END LOOP;
    END IF;
    IF iGetIndex                  - 1 >= 0 THEN
      iGetIndex      := iGetIndex - 1;
    END IF;
    poiNumAllRtns   := iNumRtns;
    poiNumFetchRows := iGetIndex;
    poszValues      := szValues;
    poiStatus       := iStatus;
  EXCEPTION
  WHEN OTHERS THEN
    poszErrMsg := 'Cannot get client rtn info related to mf ' || TO_CHAR(piMfNo) || ', invoice ' || pszInvNo || ', item: ' || pszItem || '/' || pszCpv || ', (code: ' || TO_CHAR(SQLCODE) || ')';
    poiStatus  := SQLCODE;
  END;
  PROCEDURE p_get_order_seq_info(
      pszSeqNum IN VARCHAR2,
      poszSeqInfo OUT VARCHAR2,
      poszErrMsg OUT VARCHAR2,
      poiStatus OUT NUMBER)
  IS
    iSeqNum NUMBER;
    iExists BOOLEAN;
    CURSOR c_get_seq_info(cpSeqNum ordd.seq%TYPE)
    IS
      /* Retrieve data from previously saved orders */
      /* Ordd_for_rtn won't get populated until the order is purged */
      SELECT route_no,
        stop_no,
        order_id,
        prod_id,
        cust_pref_vendor,
        TO_CHAR(uom) uom
      FROM ordd_for_rtn
      WHERE ordd_seq = cpSeqNum
    UNION ALL

    /* Or retrieve data from current orders (for will call/same day) */
    SELECT route_no,
      stop_no,
      order_id,
      prod_id,
      cust_pref_vendor,
      TO_CHAR(uom) uom
    FROM ordd d
    WHERE seq = cpSeqNum
    AND EXISTS
      (SELECT NULL FROM route WHERE route_no = d.route_no AND status = 'CLS'
      );
  BEGIN
    poszSeqInfo := NULL;
    poszErrMsg  := NULL;
    poiStatus   := ct_sql_success;
    iSeqNum     := 0;
    BEGIN
      SELECT TO_NUMBER(pszSeqNum) INTO iSeqNum FROM DUAL;
    EXCEPTION
    WHEN OTHERS THEN
      poszErrMsg := 'Order sequence # ' || pszSeqNum || ' should content all integers only';
      poiStatus  := ct_no_order_found;
      RETURN;
    END;
    iExists := FALSE;
    FOR cSeq IN c_get_seq_info(iSeqNum)
    LOOP
      iExists     := TRUE;
      poszSeqInfo := RPAD(NVL(cSeq.route_no, ' '), ROUTE_NO_LEN, ' ') || RPAD(NVL(TO_CHAR(cSeq.stop_no), ' '), STOP_NO_LEN, ' ') || RPAD(NVL(cSeq.order_id, ' '), INV_NO_LEN, ' ') || RPAD(NVL(cSeq.prod_id, ' '), PROD_ID_LEN, ' ') || RPAD(NVL(cSeq.cust_pref_vendor, ' '), CPV_LEN, ' ') || RPAD(NVL(cSeq.uom, ' '), UOM_LEN, ' ');
    END LOOP;
    IF NOT iExists THEN
      poszErrMsg := 'Order sequence # ' || pszSeqNum || ' not found';
      poiStatus  := ct_no_order_found;
    END IF;
  END;
  PROCEDURE p_get_ovr_rtn_info(
      piMfNo  IN manifests.manifest_no%TYPE,
      pszItem IN pm.prod_id%TYPE,
      pszCpv  IN pm.cust_pref_vendor%TYPE,
      poiNumAllOvrs OUT NUMBER,
      poszOvrs OUT ttabRtns,
      poszErrMsg OUT VARCHAR2,
      poiStatus OUT NUMBER)
  IS
    iNumOvrs NUMBER := 0;
    szOvrs ttabRtns;
    iStatus NUMBER := ct_sql_success;
    CURSOR c_get_ovrs
    IS
      /* Overage returns which have putaway tasks */
      SELECT r.manifest_no,
        r.rec_type,
        r.obligation_no,
        r.return_reason_cd,
        NVL(r.returned_qty, 0) returned_qty,
        r.returned_split_cd,
        r.catchweight,
        r.disposition,
        NVL(r.returned_prod_id, r.prod_id) returned_prod_id,
        r.erm_line_id,
        r.temperature,
        pt.dest_loc,
        pt.pallet_id,
        p.descrip,
        p.ti,
        p.hi,
        p.pallet_type,
        DECODE(pt.rtn_label_printed, NULL, 'N', ' ', 'N', pt.rtn_label_printed) rtn_label_printed,
        SUBSTR(pt.parent_pallet_id, 1, TBATCH_LEN) parent_pallet_id
      FROM returns r,
        pm p,
        putawaylst pt
      WHERE r.prod_id        = pszItem
      AND r.cust_pref_vendor = pszCpv
      AND r.manifest_no      = piMfNo
      AND r.rec_type         = 'O'
      AND EXISTS
        (SELECT NULL
        FROM manifests m
        WHERE manifest_no        = r.manifest_no
        AND manifest_status NOT IN ('CLS', 'PAD')
        )
    AND pt.rec_id = 'S'
      || TO_CHAR(r.manifest_no)
    AND pt.prod_id          = r.prod_id
    AND pt.cust_pref_vendor = r.cust_pref_vendor
    AND pt.reason_code      = r.return_reason_cd
    AND pt.erm_line_id      = r.erm_line_id
    AND p.prod_id           = r.prod_id
    AND p.cust_pref_vendor  = r.cust_pref_vendor
    UNION ALL

    /* Overage returns which have no putaway tasks. Might need to */
    /* do tripmaster in CRT first */
    SELECT r.manifest_no,
      r.rec_type,
      r.obligation_no,
      r.return_reason_cd,
      NVL(r.returned_qty, 0) returned_qty,
      r.returned_split_cd,
      r.catchweight,
      r.disposition,
      NVL(r.returned_prod_id, r.prod_id) returned_prod_id,
      r.erm_line_id,
      r.temperature,
      ' ' dest_loc,
      ' ' pallet_id,
      p.descrip,
      p.ti,
      p.hi,
      p.pallet_type,
      'T' rtn_label_printed,
      ' ' parent_pallet_id
    FROM returns r,
      pm p
    WHERE r.prod_id        = pszItem
    AND r.cust_pref_vendor = pszCpv
    AND r.manifest_no      = piMfNo
    AND r.rec_type         = 'O'
    AND EXISTS
      (SELECT NULL
      FROM manifests m
      WHERE manifest_no        = r.manifest_no
      AND manifest_status NOT IN ('CLS', 'PAD')
      )
    AND NOT EXISTS
      (SELECT NULL
      FROM putawaylst pt
      WHERE pt.rec_id = 'S'
        || TO_CHAR(r.manifest_no)
      AND pt.prod_id          = r.prod_id
      AND pt.cust_pref_vendor = r.cust_pref_vendor
      AND pt.reason_code      = r.return_reason_cd
      AND pt.erm_line_id      = r.erm_line_id
      )
    AND p.prod_id          = r.prod_id
    AND p.cust_pref_vendor = r.cust_pref_vendor
    ORDER BY 18,
      1 DESC,
      10;
  BEGIN
    poiNumAllOvrs                   := 0;
    poszErrMsg                      := NULL;
    poiStatus                       := ct_sql_success;
    IF check_mf_no(TO_CHAR(piMfNo)) <> ct_sql_success THEN
      poiStatus                     := ct_invalid_mf;
      poszErrMsg                    := 'Manifest ' || TO_CHAR(piMfNo) || ' is invalid ' || '(code ' || TO_CHAR(SQLCODE) || ')';
      RETURN;
    END IF;
    FOR cOvr IN c_get_ovrs
    LOOP
      iNumOvrs                   := iNumOvrs + 1;
      szOvrs(iNumOvrs).szField1  := TO_CHAR(cOvr.manifest_no);
      szOvrs(iNumOvrs).szField2  := cOvr.rec_type;
      szOvrs(iNumOvrs).szField3  := cOvr.obligation_no;
      szOvrs(iNumOvrs).szField4  := cOvr.return_reason_cd;
      szOvrs(iNumOvrs).szField5  := TO_CHAR(cOvr.returned_qty);
      szOvrs(iNumOvrs).szField5  := cOvr.returned_split_cd;
      szOvrs(iNumOvrs).szField7  := TO_CHAR(cOvr.catchweight);
      szOvrs(iNumOvrs).szField8  := cOvr.disposition;
      szOvrs(iNumOvrs).szField9  := cOvr.returned_prod_id;
      szOvrs(iNumOvrs).szField10 := TO_CHAR(cOvr.erm_line_id);
      szOvrs(iNumOvrs).szField11 := TO_CHAR(cOvr.temperature);
      szOvrs(iNumOvrs).szField12 := cOvr.dest_loc;
      szOvrs(iNumOvrs).szField13 := cOvr.pallet_id;
      szOvrs(iNumOvrs).szField14 := cOvr.descrip;
      szOvrs(iNumOvrs).szField15 := TO_CHAR(cOvr.ti);
      szOvrs(iNumOvrs).szField16 := TO_CHAR(cOvr.hi);
      szOvrs(iNumOvrs).szField17 := cOvr.pallet_type;
      szOvrs(iNumOvrs).szField18 := cOvr.rtn_label_printed;
      szOvrs(iNumOvrs).szField19 := cOvr.parent_pallet_id;
    END LOOP;
    poiNumAllOvrs := iNumOvrs;
    poszOvrs      := szOvrs;
    poiStatus     := ct_sql_success;
  EXCEPTION
  WHEN OTHERS THEN
    poszErrMsg := 'Cannot get overage rtn info related to mf ' || TO_CHAR(piMfNo) || ', item: ' || pszItem || '/' || pszCpv || ', (code: ' || TO_CHAR(SQLCODE) || ')';
    poiStatus  := SQLCODE;
  END;
  PROCEDURE p_client_get_ovr_info(
      piMfNo          IN manifests.manifest_no%TYPE,
      pszItem         IN pm.prod_id%TYPE,
      pszCpv          IN pm.cust_pref_vendor%TYPE,
      piLPLen         IN NUMBER,
      piNumFixedLines IN NUMBER,
      piCurPg         IN NUMBER,
      piNumsPerPg     IN NUMBER,
      poiNumAllOvrs OUT NUMBER,
      poiNumFetchRows OUT NUMBER,
      poszValues OUT ttabValues,
      poszErrMsg OUT VARCHAR2,
      poiStatus OUT NUMBER)
  IS
    iLine      NUMBER := 0;
    iIndex     NUMBER;
    iSkipIndex NUMBER := 0;
    iGetIndex  NUMBER := 0;
    iNumOvrs   NUMBER := 0;
    szOvrs ttabRtns;
    szValues ttabValues;
    iStatus        NUMBER := ct_sql_success;
    iMaxPg         NUMBER;
    iNumFixedLines NUMBER := piNumFixedLines;
  BEGIN
    poiNumAllOvrs   := 0;
    poiNumFetchRows := 0;
    poszErrMsg      := NULL;
    poiStatus       := ct_sql_success;
    p_get_ovr_rtn_info(piMfNo, pszItem, pszCpv, iNumOvrs, szOvrs, poszErrMsg, iStatus);
    IF iStatus    = ct_sql_success THEN
      IF iNumOvrs > MAX_KIND THEN
        iNumOvrs := MAX_KIND;
      END IF;
      IF iNumFixedLines   IS NULL OR iNumFixedLines < 0 THEN
        iNumFixedLines    := 0;
      ELSIF iNumFixedLines > piNumsPerPg THEN
        iNumFixedLines    := piNumsPerPg;
      END IF;
      iGetIndex  := 1;
      iMaxPg     := piNumsPerPg;
      IF piCurPg <> piNumsPerPg THEN
        -- Since the client screen might have some number of fixed lines that
        -- will display fixed set of values (like 1. New ovr), we will set the
        -- the number of database lines to skip if it's not in the 1st page.
        iSkipIndex := iNumFixedLines;
        iMaxPg     := iMaxPg + 1;
      END IF;
      FOR iIndex IN 1 .. iNumOvrs
      LOOP
        IF (iSkipIndex < piCurPg - piNumsPerPg) AND (piCurPg <> piNumsPerPg) THEN
          -- Skip all previously retrieved values until the current client page
          -- is reached
          iSkipIndex    := iSkipIndex + 1;
        ELSIF (iGetIndex < iMaxPg) OR (piNumsPerPg = 0) THEN
          -- Retrieve all values pertaining to the current client page or all
          -- values regardless if piNumsPerPg is 0 (means unlimited.)
          iLine               := piCurPg - piNumsPerPg + iGetIndex + 1;
          szValues(iGetIndex) := RPAD(TO_CHAR(iLine), LINE_NO_LEN, ' ') || RPAD(szOvrs(iIndex).szField1, MF_NO_LEN, ' ') || RPAD(NVL(szOvrs(iIndex).szField2, ' '), REC_TYPE_LEN, ' ') || RPAD(NVL(szOvrs(iIndex).szField3, ' '), INV_NO_LEN, ' ') || RPAD(NVL(szOvrs(iIndex).szField4, ' '), REASON_CODE_LEN, ' ') || RPAD(NVL(szOvrs(iIndex).szField5, ' '), QTY_LEN, ' ') || RPAD(NVL(szOvrs(iIndex).szField6, ' '), UOM_LEN, ' ') || RPAD(NVL(szOvrs(iIndex).szField7, ' '), WEIGHT_LEN,' ') || RPAD(NVL(szOvrs(iIndex).szField8, ' '), REASON_CODE_LEN, ' ') || RPAD(NVL(szOvrs(iIndex).szField9, ' '), UPC_LEN, ' ') || RPAD(NVL(szOvrs(iIndex).szField10, ' '), LINE_ID_LEN, ' ') || RPAD(NVL(szOvrs(iIndex).szField11, ' '), TEMP_LEN, ' ') || RPAD(NVL(szOvrs(iIndex).szField12, ' '), LOC_LEN, ' ') || RPAD(NVL(szOvrs(iIndex).szField13, ' '), piLPLen, ' ') || RPAD(NVL(szOvrs(iIndex).szField14, ' '), DESCRIP_LEN, ' ') || RPAD(NVL(szOvrs(iIndex).szField15, ' '), TIHI_LEN, ' ') || RPAD(NVL(szOvrs(iIndex).szField16,
          ' '), TIHI_LEN, ' ') || RPAD(NVL(szOvrs(iIndex).szField17, ' '), PAL_TYPE_LEN, ' ') || RPAD(NVL(szOvrs(iIndex).szField18, ' '), ONE_LEN, ' ') || RPAD(NVL(szOvrs(iIndex).szField19, ' '), TBATCH_LEN, ' ');
          iGetIndex := iGetIndex + 1;
        ELSE
          RETURN;
        END IF;
      END LOOP;
    END IF;
    IF iGetIndex                  - 1 >= 0 THEN
      iGetIndex      := iGetIndex - 1;
    END IF;
    poiNumAllOvrs   := iNumOvrs;
    poiNumFetchRows := iGetIndex;
    poszValues      := szValues;
    poiStatus       := iStatus;
  EXCEPTION
  WHEN OTHERS THEN
    poszErrMsg := 'Cannot get client rtn ovr info related to mf ' || TO_CHAR(piMfNo) || ', item: ' || pszItem || '/' || pszCpv || ', (code: ' || TO_CHAR(SQLCODE) || ')';
    poiStatus  := SQLCODE;
  END;
  PROCEDURE p_get_mspk_info(
      piMfNo   IN manifests.manifest_no%TYPE,
      pszInvNo IN manifest_dtls.obligation_no%TYPE,
      pszItem  IN pm.prod_id%TYPE,
      pszCpv   IN pm.cust_pref_vendor%TYPE,
      poiNumAllMspks OUT NUMBER,
      poszMspks OUT ttabRtns,
      poszErrMsg OUT VARCHAR2,
      poiStatus OUT NUMBER)
  IS
    iNumMspks NUMBER := 0;
    szMspks ttabRtns;
    iStatus NUMBER := ct_sql_success;
    CURSOR c_get_mspks
    IS
      /* Mispick returns which have no putaway tasks (with or without invoice) */
      SELECT r.manifest_no,
        r.rec_type,
        r.obligation_no,
        r.prod_id,
        r.cust_pref_vendor,
        r.return_reason_cd,
        NVL(r.returned_qty, 0) returned_qty,
        r.returned_split_cd,
        r.catchweight,
        r.disposition,
        r.erm_line_id,
        r.temperature,
        DECODE(rc.reason_group, 'MPK', '_', 'T') rtn_label_printed,
        ' ' dest_loc,
        ' ' pallet_id,
        p.descrip,
        p.ti,
        p.hi,
        p.pallet_type,
        ' ' parent_pallet_id
      FROM returns r,
        reason_cds rc,
        pm p
      WHERE rc.reason_cd_type       = 'RTN'
      AND rc.reason_group          IN ('MPR', 'MPK')
      AND rc.reason_cd              = r.return_reason_cd
      AND r.returned_prod_id        = pszItem
      AND r.cust_pref_vendor        = pszCpv
      AND p.prod_id                 = pszItem
      AND p.cust_pref_vendor        = pszCpv
      AND r.manifest_no             = piMfNo
      AND ((LTRIM(RTRIM(pszInvNo)) IS NULL)
      OR ((r.obligation_no          = pszInvNo)
      OR EXISTS
        (SELECT NULL
        FROM manifest_dtls
        WHERE manifest_no    = r.manifest_no
        AND prod_id          = r.prod_id
        AND cust_pref_vendor = r.cust_pref_vendor
        AND orig_invoice     = pszInvNo
        )))
      AND NOT EXISTS
        (SELECT NULL
        FROM manifests m
        WHERE m.manifest_no    = r.manifest_no
        AND m.manifest_status IN ('PAD', 'CLS')
        )
      AND NOT EXISTS
        (SELECT NULL
        FROM putawaylst pt
        WHERE rec_id = 'S'
          || TO_CHAR(r.manifest_no)
        AND pt.lot_id           = r.obligation_no
        AND pt.reason_code      = r.return_reason_cd
        AND pt.prod_id          = r.returned_prod_id
        AND pt.cust_pref_vendor = r.cust_pref_vendor
        AND pt.erm_line_id      = r.erm_line_id
        )
      UNION ALL

      /* Mispick returns which have putaway tasks with or without invoice */
      SELECT r.manifest_no,
        r.rec_type,
        r.obligation_no,
        r.prod_id,
        r.cust_pref_vendor,
        r.return_reason_cd,
        NVL(r.returned_qty, 0) returned_qty,
        r.returned_split_cd,
        r.catchweight,
        r.disposition,
        r.erm_line_id,
        r.temperature,
        DECODE(pt.rtn_label_printed, NULL, 'N', ' ', 'N', pt.rtn_label_printed) rtn_label_printed,
        pt.dest_loc,
        pt.pallet_id,
        p.descrip,
        p.ti,
        p.hi,
        p.pallet_type,
        SUBSTR(pt.parent_pallet_id, 1, TBATCH_LEN) parent_pallet_id
      FROM returns r,
        reason_cds rc,
        putawaylst pt,
        pm p
      WHERE rc.reason_cd_type       = 'RTN'
      AND rc.reason_group          IN ('MPR', 'MPK')
      AND rc.reason_cd              = r.return_reason_cd
      AND r.returned_prod_id        = pszItem
      AND r.cust_pref_vendor        = pszCpv
      AND r.manifest_no             = piMfNo
      AND ((LTRIM(RTRIM(pszInvNo)) IS NULL)
      OR ((r.obligation_no          = pszInvNo)
      OR EXISTS
        (SELECT NULL
        FROM manifest_dtls
        WHERE manifest_no    = r.manifest_no
        AND prod_id          = r.prod_id
        AND cust_pref_vendor = r.cust_pref_vendor
        AND orig_invoice     = pszInvNo
        )))
      AND NOT EXISTS
        (SELECT NULL
        FROM manifests m
        WHERE m.manifest_no    = r.manifest_no
        AND m.manifest_status IN ('PAD', 'CLS')
        )
      AND rec_id = 'S'
        || TO_CHAR(r.manifest_no)
      AND pt.lot_id           = r.obligation_no
      AND pt.reason_code      = r.return_reason_cd
      AND pt.prod_id          = r.returned_prod_id
      AND pt.cust_pref_vendor = r.cust_pref_vendor
      AND pt.erm_line_id      = r.erm_line_id
      AND p.prod_id           = pt.prod_id
      AND p.cust_pref_vendor  = pt.cust_pref_vendor
      UNION ALL

      /* Mispick returns which have no putaway tasks with invoice */
      /* and no mispick item */
      SELECT r.manifest_no,
        r.rec_type,
        r.obligation_no,
        r.prod_id,
        r.cust_pref_vendor,
        r.return_reason_cd,
        NVL(r.returned_qty, 0) returned_qty,
        NVL(r.returned_split_cd, ' ') returned_split_cd,
        r.catchweight,
        r.disposition,
        r.erm_line_id,
        r.temperature,
        '_' rtn_label_printed,
        ' ' dest_loc,
        ' ' pallet_id,
        ' ' descrip,
        0 ti,
        0 hi,
        ' ' pallet_type,
        ' ' parent_pallet_id
      FROM returns r,
        reason_cds rc
      WHERE rc.reason_cd_type       = 'RTN'
      AND rc.reason_group          IN ('MPR', 'MPK')
      AND rc.reason_cd              = r.return_reason_cd
      AND r.returned_prod_id       IS NULL
      AND r.cust_pref_vendor        = pszCpv
      AND r.manifest_no             = piMfNo
      AND ((LTRIM(RTRIM(pszInvNo)) IS NULL)
      OR ((r.obligation_no          = pszInvNo)
      OR EXISTS
        (SELECT NULL
        FROM manifest_dtls
        WHERE manifest_no    = r.manifest_no
        AND prod_id          = r.prod_id
        AND cust_pref_vendor = r.cust_pref_vendor
        AND orig_invoice     = pszInvNo
        )))
      AND NOT EXISTS
        (SELECT NULL
        FROM manifests m
        WHERE m.manifest_no    = r.manifest_no
        AND m.manifest_status IN ('PAD', 'CLS')
        )
      ORDER BY 13 ASC,
        3 DESC,
        1 DESC,
        11,
        4;
    BEGIN
      poiNumAllMspks                  := 0;
      poszErrMsg                      := NULL;
      poiStatus                       := ct_sql_success;
      IF check_mf_no(TO_CHAR(piMfNo)) <> ct_sql_success THEN
        poiStatus                     := ct_invalid_mf;
        poszErrMsg                    := 'Manifest ' || TO_CHAR(piMfNo) || ' is invalid ' || '(code ' || TO_CHAR(SQLCODE) || ')';
        RETURN;
      END IF;
      FOR cMspk IN c_get_mspks
      LOOP
        iNumMspks                    := iNumMspks + 1;
        szMspks(iNumMspks).szField1  := TO_CHAR(cMspk.manifest_no);
        szMspks(iNumMspks).szField2  := cMspk.rec_type;
        szMspks(iNumMspks).szField3  := cMspk.obligation_no;
        szMspks(iNumMspks).szField4  := cMspk.prod_id;
        szMspks(iNumMspks).szField5  := cMspk.cust_pref_vendor;
        szMspks(iNumMspks).szField6  := cMspk.return_reason_cd;
        szMspks(iNumMspks).szField7  := TO_CHAR(cMspk.returned_qty);
        szMspks(iNumMspks).szField8  := cMspk.returned_split_cd;
        szMspks(iNumMspks).szField9  := TO_CHAR(cMspk.catchweight);
        szMspks(iNumMspks).szField10 := cMspk.disposition;
        szMspks(iNumMspks).szField11 := TO_CHAR(cMspk.erm_line_id);
        szMspks(iNumMspks).szField12 := TO_CHAR(cMspk.temperature);
        szMspks(iNumMspks).szField13 := cMspk.rtn_label_printed;
        szMspks(iNumMspks).szField14 := cMspk.dest_loc;
        szMspks(iNumMspks).szField15 := cMspk.pallet_id;
        szMspks(iNumMspks).szField16 := cMspk.descrip;
        szMspks(iNumMspks).szField17 := TO_CHAR(cMspk.ti);
        szMspks(iNumMspks).szField18 := TO_CHAR(cMspk.hi);
        szMspks(iNumMspks).szField19 := cMspk.pallet_type;
        szMspks(iNumMspks).szField20 := cMspk.parent_pallet_id;
      END LOOP;
      poiNumAllMspks := iNumMspks;
      poszMspks      := szMspks;
      poiStatus      := ct_sql_success;
    EXCEPTION
    WHEN OTHERS THEN
      poszErrMsg := 'Cannot get rtn mispick info related to mf ' || TO_CHAR(piMfNo) || ', invoice' || pszInvNo || ', item: ' || pszItem || '/' || pszCpv || ', (code: ' || TO_CHAR(SQLCODE) || ')';
      poiStatus  := SQLCODE;
    END;
    
    PROCEDURE P_Dlt_Damaged_Putaway_ERMD (
        p_mnfst_id IN manifests.manifest_no%TYPE)
    IS
      l_mnfst_id      VARCHAR2(10) := 'D'||p_mnfst_id;
      l_Delete_status VARCHAR2(50);
    BEGIN
      l_Delete_status := 'Putaway Delete';
      DELETE
      FROM putawaylst a
      WHERE pallet_id IN
        (SELECT pallet_id
        FROM putawaylst b
        WHERE b.rec_id LIKE l_mnfst_id
        AND b.DEST_LOC = 'DDDDDD'
        );
      l_Delete_status := 'ERD Delete';
      DELETE
      FROM erd
      WHERE erm_id LIKE l_mnfst_id
      AND erm_line_id IN
        (SELECT erm_line_id
        FROM erd
        WHERE 1    =1
        AND erm_id = l_mnfst_id
        AND NOT EXISTS
          (SELECT * FROM putawaylst WHERE rec_id LIKE l_mnfst_id AND DEST_LOC = 'DDDDDD'
          )
        );
      l_Delete_status := 'ERM Delete';
      DELETE
      FROM erm
      WHERE erm_id LIKE l_mnfst_id
      AND erm_type     = 'CM'
      AND erm_id       = l_mnfst_id ;
      l_Delete_status := 'All Deletes Done';
      pl_log.ins_msg('INFO' , 'P_Dlt_Damaged_Putaway_ERMD', l_Delete_status||'-Sucessful', '100', '100', 'DriverCheckin', 'p_delete_damage_putaways', 'N');
      COMMIT;
    EXCEPTION
    WHEN OTHERS THEN
      -- o_status := ct_mf_is_POD;
      ROLLBACK;
      pl_log.ins_msg('INFO' , 'p_delete_damage_putaways', 'Exception', '100', '100', l_Delete_status, 'p_delete_damage_putaways', 'N');
      RETURN;
    END;
  PROCEDURE p_client_get_mspk_info(
      piMfNo          IN manifests.manifest_no%TYPE,
      pszInvNo        IN manifest_dtls.obligation_no%TYPE,
      pszItem         IN pm.prod_id%TYPE,
      pszCpv          IN pm.cust_pref_vendor%TYPE,
      piLPLen         IN NUMBER,
      piNumFixedLines IN NUMBER,
      piCurPg         IN NUMBER,
      piNumsPerPg     IN NUMBER,
      poiNumAllMspks OUT NUMBER,
      poiNumFetchRows OUT NUMBER,
      poszValues OUT ttabValues,
      poszErrMsg OUT VARCHAR2,
      poiStatus OUT NUMBER)
  IS
    iLine      NUMBER := 0;
    iIndex     NUMBER;
    iSkipIndex NUMBER := 0;
    iGetIndex  NUMBER := 0;
    iNumMspks  NUMBER := 0;
    szMspks ttabRtns;
    szValues ttabValues;
    iStatus        NUMBER := ct_sql_success;
    iMaxPg         NUMBER;
    iNumFixedLines NUMBER := piNumFixedLines;
  BEGIN
    poiNumAllMspks  := 0;
    poiNumFetchRows := 0;
    poszErrMsg      := NULL;
    poiStatus       := ct_sql_success;
    p_get_mspk_info(piMfNo, pszInvNo, pszItem, pszCpv, iNumMspks, szMspks, poszErrMsg, iStatus);
    IF iStatus     = ct_sql_success THEN
      IF iNumMspks > MAX_KIND THEN
        iNumMspks := MAX_KIND;
      END IF;
      IF iNumFixedLines   IS NULL OR iNumFixedLines < 0 THEN
        iNumFixedLines    := 0;
      ELSIF iNumFixedLines > piNumsPerPg THEN
        iNumFixedLines    := piNumsPerPg;
      END IF;
      iGetIndex  := 1;
      iMaxPg     := piNumsPerPg;
      IF piCurPg <> piNumsPerPg THEN
        -- Since the client screen might have some number of fixed lines that
        -- will display fixed set of values (like 1. New ovr), we will set the
        -- the number of database lines to skip if it's not in the 1st page.
        iSkipIndex := iNumFixedLines;
        iMaxPg     := iMaxPg + 1;
      END IF;
      FOR iIndex IN 1 .. iNumMspks
      LOOP
        IF (iSkipIndex < piCurPg - piNumsPerPg) AND (piCurPg <> piNumsPerPg) THEN
          -- Skip all previously retrieved values until the current client page
          -- is reached
          iSkipIndex    := iSkipIndex + 1;
        ELSIF (iGetIndex < iMaxPg) OR (piNumsPerPg = 0) THEN
          -- Retrieve all values pertaining to the current client page or all
          -- values regardless if piNumsPerPg is 0 (means unlimited.)
          iLine               := piCurPg - piNumsPerPg + iGetIndex + 1;
          szValues(iGetIndex) := RPAD(TO_CHAR(iLine), LINE_NO_LEN, ' ') || RPAD(szMspks(iIndex).szField1, MF_NO_LEN, ' ') || RPAD(NVL(szMspks(iIndex).szField2, ' '), REC_TYPE_LEN, ' ') || RPAD(NVL(szMspks(iIndex).szField3, ' '), INV_NO_LEN, ' ') || RPAD(NVL(szMspks(iIndex).szField4, ' '), PROD_ID_LEN, ' ') || RPAD(NVL(szMspks(iIndex).szField5, ' '), CPV_LEN, ' ') || RPAD(NVL(szMspks(iIndex).szField6, ' '), REASON_CODE_LEN, ' ') || RPAD(NVL(szMspks(iIndex).szField7, ' '), QTY_LEN, ' ') || RPAD(NVL(szMspks(iIndex).szField8, ' '), UOM_LEN, ' ') || RPAD(NVL(szMspks(iIndex).szField9, ' '), WEIGHT_LEN,' ') || RPAD(NVL(szMspks(iIndex).szField10, ' '), REASON_CODE_LEN, ' ') || RPAD(NVL(szMspks(iIndex).szField11, ' '), LINE_ID_LEN, ' ') || RPAD(NVL(szMspks(iIndex).szField12, ' '), TEMP_LEN, ' ') || RPAD(NVL(szMspks(iIndex).szField13, ' '), ONE_LEN, ' ') || RPAD(NVL(szMspks(iIndex).szField14, ' '), LOC_LEN, ' ') || RPAD(NVL(szMspks(iIndex).szField15, ' '), piLPLen, ' ') || RPAD(NVL(szMspks(
          iIndex).szField16, ' '), DESCRIP_LEN, ' ') || RPAD(NVL(szMspks(iIndex).szField17, ' '), TIHI_LEN, ' ') || RPAD(NVL(szMspks(iIndex).szField18, ' '), TIHI_LEN, ' ') || RPAD(NVL(szMspks(iIndex).szField19, ' '), PAL_TYPE_LEN, ' ') || RPAD(NVL(szMspks(iIndex).szField20, ' '), TBATCH_LEN, ' ');
          iGetIndex := iGetIndex + 1;
        ELSE
          RETURN;
        END IF;
      END LOOP;
    END IF;
    IF iGetIndex                  - 1 >= 0 THEN
      iGetIndex      := iGetIndex - 1;
    END IF;
    poiNumAllMspks  := iNumMspks;
    poiNumFetchRows := iGetIndex;
    poszValues      := szValues;
    poiStatus       := iStatus;
  EXCEPTION
  WHEN OTHERS THEN
    poszErrMsg := 'Cannot get client rtn mispick info related to mf ' || TO_CHAR(piMfNo) || ', invoice: ' || pszInvNo || ', item: ' || pszItem || '/' || pszCpv || ', (code: ' || TO_CHAR(SQLCODE) || ')';
    poiStatus  := SQLCODE;
  END;
-- ********************** <Package Initialization> *****************************
BEGIN
  gRcTypSyspar := pl_dci.get_syspars;
END pl_rtn_dtls;
/
SHOW ERRORS
