CREATE OR REPLACE PACKAGE swms.pl_dci AS

-- *********************** <Package Specifications> ****************************

-- ************************* <Prefix Documentations> ***************************

--  This package specification is used to do returns processing.
--  Mainly use by RF that mimics the available functionalities in the CRT.
  
--  sccs_id=@(#) src/schema/plsql/pl_dci.sql, swms, swms.9, 11.2 2/17/10 1.23

--  Modification History
--  Date      User   Defect  Comment
--  08/19/05  prplhj 11920   Initial creation
--  09/09/05  prplhj 11996   Check_basic_rtn_info() and update_return() fixes.
--  09/30/05  prplhj 11997   Undo T-batch for old damage reason during
--                           update_return from damage reason to saleable reason
--                           and undo T-batch for damage return during
--                           delete_return. Use invoice/item/cpv instead of LP
--                           to give the return info back from get_range_returns
--                           if new return has no putaway task during
--                           update_return. Change get_mf_status() to allow
--                           invoice # (old) or LP input (new). Also send the
--                           T-batch info back through PUTAWAYLST during
--                           create_puttask().
--  11/04/05  prplhj 12027   Fixed select statement to retrieve corrected
--                           obligation_no and orig_invoice in get_mf_status()
--                           with pszSearch parameter when pszSearch is in a
--                           PAD manifest. Put column names to the "INSERT INTO
--                           float_hist_errors" statement in close_manifest().
--  11/07/05  prphqb         Add order_line_id to float_hist_errors during ins
--  11/29/05  prphqb         Do not write CC record if location is "*"
--  12/19/05  prphqb         Change get_loc to return induction location and
--               float flag 
--  02/07/06  prphqb         For close manifest, if syspar RTN_PUTAWAY_CONF = N,
--                           during confirming PUT transaction, we need to add
--                           code to write ExpectedReceipt to mini loader
--               - ONLY FOR SALEABLE
--  03/10/06  prplhj         D#12072 Changed create_cyc to handle creation of
--               cycle count tasks and exceptions for Miniload slots
--  04/10/06  prplhj         D#12080 Fixed create_return for creating -1
--               erm_line_id on ERD and PUTAWAYLST. Fixed
--               check_ovr_und_rtn() to not to check rtn qty vs.
--               ship qty for MPR and MPK reason groups.
--  04/12/06  prphqb         Set both inv_date and exp_date = 01-JAN-2001 for ML
--  04/28/06  prplhj         D#12087 Fixed delete_invoice_return/delete_return
--               to handle the update of manifest_dtl_status back
--               to OPN when the original shipped qty is zero.
--               Need to use inv_uom during inv insert.
--               Not done but keep the codes: Create cycle count
--               task only for inventory w/ same uom as returned
--               uom except for mispick invoiced item.
--  08/16/06  prplhj         D#12125 Fixed duplicated CC and CC_EXCEPTION_LIST
--                           record creation problems when the floating-zone
--                           items have valid last ship slot but have no
--                           inventory record during manifest close.
--  10/24/06  prpakp         Corrected the inv_uom when inserting record to
--                           inventory from 2-uom to uom.
--  10/25/06  Infosys        Added condition to handle warning for inbound
--                           accessory tracking.
--  10/24/08  prplhj         D#12430 Changed accessory inbound/outbound checks
--               from LAS_TRUCK_EQUIPMENT to V_TRUCK_ACCESSORY.
--  04/02/09  prplhj    D#10489 Added PUT/NOPUT logic as psType argument to
--          get_range_returns().
--  02/17/10  prplhj    D#12561 Fix get_client_reason_info() so local rows can
--          ben sent back to caller as a long string.
--  03/22/10  ssha0443  DN12554 - 212 Enh - SCE042- Customer Id 
--                      expansion . SWMS changes  
--                      Changed customer id field length  to 10 characters 
--  08/19/11  jluo5859  PBI3313 - Removed previous-generated pending inventory
--          for floating/miniload/reserved slots when the return
--          is an update before creating a new pending inv record.
--          Added the new function f_clear_inv().
--  10/24/11  jluo5859  PBI3315/SAPCR6711/CR29831 - Set to correct original
--          invoice for W10 return in get_orig_inv().
--          Not allow over returned qty for pickup for SAP company
--          for all reason codes.
--  18/10/13 mdev3739 CRQ43501 - validate tripmaster function.
--          The function validates a single manifest passed. If the validation is successful 
--          if no error then return to '0',any error return to '1' and any oracle error then 
--          return to '-1'. Finally the status of the returns
--          in RETURNS table will be updated as CMP or ERR based on the error.
--  11-April-2014 knha8378 charm 6000001076 - Manifest cannot close bc W45 has no stop
--      Removing the validation in validate_tripmaster in the update of return table
--          to not validate stop number anymore.
--  10/13/16 jluo6971 CRQ000000008968 Moved the search of order_line_id to
--           a function called get_order_line for FLOAT_HIST_ERRORS insertion. 
--           The function also add the search from FLOAT_HIST in case the
--           prior search (from ORDD and ORDD_FOR_RTN) fails.
-- 04/27/2018 ezhe5043  JIRA386 Added for POD function
--05/06/2020 vkal9662 POD phase2 Validate trip master looking for status 'VAL' returns
--07/23/2020 vkal9662 removed validating pick up returns'P' in validate returns process
--07/30/2020 vkal9662 new procedure dci_food_safety added
--8/14/2020  knha8378 revise dci_food_safety to determin D=Delete, A=Add or U=Update
-- 05-JAN-2021 pkab6563 - changed the type for cust_id in dci_food_safety() from
--             number to the varchar2 to prevent potential problems in case any
--             customer ID contains alphanumeric values. Issue was discovered
--             during returns on RF project.
--10/03/21 mcha1213 modify auto_close_manifest and add create_stc_for_pod function
-- ******************** <End of Prefix Documentations> *************************

-- ************************* <Constant Definitions> ****************************

C_NORMAL        CONSTANT NUMBER := 0;
C_NOT_FOUND     CONSTANT NUMBER := 1403;
C_ANSI_NOT_FOUND    CONSTANT NUMBER := 100;

C_DFT_CPV       CONSTANT VARCHAR2(1) := '-';

C_PRT_RANGE_MIN     CONSTANT NUMBER := 11;
C_INV_LOC       CONSTANT NUMBER := 31;
C_PRT_RANGE_MAX     CONSTANT NUMBER := 40;
C_RECS_PER_PAGE     CONSTANT NUMBER := 25;

C_ALRDY_EXIST       CONSTANT NUMBER := 26;  -- Already existed
C_INVALID_UOM       CONSTANT NUMBER := 36;  -- Invalid uom
C_INV_PRODID        CONSTANT NUMBER := 37;  -- Invalid item 
C_INV_LABEL     CONSTANT NUMBER := 39;  -- Invalid label
C_PUT_DONE      CONSTANT NUMBER := 94;  -- Pallet has been putawayed
C_CTE_RTN_BTCH_FLG_OFF  CONSTANT NUMBER := 144; -- Return batch flag is off
C_UPD_PUTLST_FAIL   CONSTANT NUMBER := 173; -- Putawaylst update failed
C_INV_DISP      CONSTANT NUMBER := 240; -- Invalid disposition code
C_INV_MF        CONSTANT NUMBER := 241; -- Invalid manifest #
C_INV_RSN       CONSTANT NUMBER := 243; -- Invalid reason code
C_ITM_NOT_SPLIT     CONSTANT NUMBER := 245; -- Item not splitable
C_MSPK_REQUIRED     CONSTANT NUMBER := 249; -- Mispick item is required
C_NO_LOC        CONSTANT NUMBER := 252; -- No location is found
C_NO_MF_INFO        CONSTANT NUMBER := 253; -- No manifest info
C_QTY_REQUIRED      CONSTANT NUMBER := 256; -- > 0 qty is required
C_QTY_RTN_GT_SHP    CONSTANT NUMBER := 258; -- Qty rtn > shipped
C_SHIP_DIFF_UOM     CONSTANT NUMBER := 259; -- Differ ship and rtn uom
C_TEMP_NO_RANGE     CONSTANT NUMBER := 261; -- No temperature range
C_TEMP_OUT_OF_RANGE CONSTANT NUMBER := 262; -- Temperature out of range
C_TEMP_REQUIRED     CONSTANT NUMBER := 263; -- Temperature is required
C_WEIGHT_DESIRED    CONSTANT NUMBER := 264; -- Need weight for the return
C_WEIGHT_OUT_OF_RANGE   CONSTANT NUMBER := 266; -- Weight out of range
C_WHOLE_NUMBER_ONLY CONSTANT NUMBER := 267; -- Whole number only
C_INV_INVNO     CONSTANT NUMBER := 295; -- Invalid invoice #
C_RTN_EXISTS        CONSTANT NUMBER := 343; -- Return already existed
C_INV_RTN       CONSTANT NUMBER := 344; -- Item(s) in invoice returned
C_INV_RTI_CLS       CONSTANT NUMBER := 349; -- Whole invoice has returned
C_UPD_NOT_ALLOWED   CONSTANT NUMBER := 350; -- Cannot update return
C_DEL_NOT_ALLOWED   CONSTANT NUMBER := 351; -- Cannot delete return
C_NO_DFT_PRINTER    CONSTANT NUMBER := 347; -- User default printer na
C_MF_HAS_CLOSED     CONSTANT NUMBER := 352; -- Manifest has been closed
C_TRACK_TRUCK_ACCESSORY CONSTANT NUMBER := 360; -- Inbound Accessory tracking has not been done
C_INCONSISTENT_MF   CONSTANT NUMBER :=268;

C_MF_CLOSE      CONSTANT NUMBER := 1002;-- Manifest has beeen closed

C_BATCH_NO_LEN      CONSTANT NUMBER := 13;
C_CPV_LEN       CONSTANT NUMBER := 10;
-- 03/22/10 - 12554 - ssha0443 - Added for 212 Enh - SCE042 - Begin 
--Changed the length of customer ID from 6 to 10
C_CUST_ID_LEN       CONSTANT NUMBER := 10;
-- 03/22/10 - 12554 - ssha0443 - Added for 212 Enh - SCE042 - End 
C_DESCRIP_LEN       CONSTANT NUMBER := 30;
C_INV_NO_LEN        CONSTANT NUMBER := 14;
C_LINE_ID_LEN       CONSTANT NUMBER := 4;
C_LOC_LEN       CONSTANT NUMBER := 10;
C_LP_LEN        CONSTANT NUMBER := 18;
C_MF_NO_LEN     CONSTANT NUMBER := 7;
C_ONECHAR_LEN       CONSTANT NUMBER := 1;
C_PALLET_TYPE_LEN   CONSTANT NUMBER := 2;
C_PROD_ID_LEN       CONSTANT NUMBER := 9;
C_PALLET_ID_LEN     CONSTANT NUMBER := 18;
C_QTY_LEN       CONSTANT NUMBER := 4;
C_REASON_LEN        CONSTANT NUMBER := 3;
C_REASON_GROUP_LEN  CONSTANT NUMBER := 3;
C_REC_TYP_LEN       CONSTANT NUMBER := 1;
C_ROUTE_NO_LEN      CONSTANT NUMBER := 10;
C_STOP_NO_LEN       CONSTANT NUMBER := 7;
C_TEMP_LEN      CONSTANT NUMBER := 6;
C_TIHI_LEN      CONSTANT NUMBER := 4;
C_UOM_LEN       CONSTANT NUMBER := 1;
C_UPC_LEN       CONSTANT NUMBER := 14;
C_WEIGHT_LEN        CONSTANT NUMBER := 9;

-- *************************** <Type Definitions> *****************************

-- An output record type for Returns table plus some other useful fields
TYPE recTypRtn IS RECORD (
  manifest_no       putawaylst.rec_id%TYPE,     -- Might include 'S','D'
  route_no      returns.route_no%TYPE,
  stop_no       returns.stop_no%TYPE,
  rec_type      returns.rec_type%TYPE,
  obligation_no     returns.obligation_no%TYPE,
  prod_id       pm.external_upc%TYPE,       -- Item #/UPC #
  cust_pref_vendor  returns.cust_pref_vendor%TYPE,
  reason_code       returns.return_reason_cd%TYPE,
  returned_qty      returns.returned_qty%TYPE,
  returned_split_cd returns.returned_split_cd%TYPE,
  weight        returns.catchweight%TYPE,
  disposition       returns.disposition%TYPE,
  returned_prod_id  pm.external_upc%TYPE,       -- Item #/UPC #
  erm_line_id       returns.erm_line_id%TYPE,
  shipped_qty       returns.shipped_qty%TYPE,
  shipped_split_cd  returns.shipped_split_cd%TYPE,
  cust_id       returns.cust_id%TYPE,
  temp          returns.temperature%TYPE,
  catch_wt_trk      pm.catch_wt_trk%TYPE,
  temp_trk      pm.temp_trk%TYPE,
  orig_invoice      returns.obligation_no%TYPE,
  dest_loc      putawaylst.dest_loc%TYPE,
  pallet_id     putawaylst.pallet_id%TYPE,
  rtn_label_printed putawaylst.rtn_label_printed%TYPE,
  pallet_batch_no   putawaylst.pallet_batch_no%TYPE,
  parent_pallet_id  putawaylst.parent_pallet_id%TYPE,
  putaway_put       putawaylst.putaway_put%TYPE,
  pallet_type       pm.pallet_type%TYPE,
  ti            pm.ti%TYPE,
  hi            pm.hi%TYPE,
  min_temp      pm.min_temp%TYPE,
  max_temp      pm.max_temp%TYPE,
  min_weight        pm.avg_wt%TYPE,
  max_weight        pm.avg_wt%TYPE,
  descrip       pm.descrip%TYPE         -- 259 bytes
);

-- A record type for Returns related syspar information
TYPE recTypSyspar IS RECORD (
  rtn_data_collection       sys_config.config_flag_val%TYPE,
  lbr_mgmt_flag         sys_config.config_flag_val%TYPE,
  create_batch_flag     lbr_func.create_batch_flag%TYPE,
  upd_item_ptype_return     sys_config.config_flag_val%TYPE,
  cc_gen_exc_reserve        sys_config.config_flag_val%TYPE,
  rtn_putaway_conf      sys_config.config_flag_val%TYPE,
  pct_tolerance         sys_config.config_flag_val%TYPE,
  rtn_bfr_mfc           sys_config.config_flag_val%TYPE,
  enable_acc_trk_flag       sys_config.config_flag_val%TYPE, -- Inbound Accessory Tracking Changes
  host_type     sys_config.config_flag_val%TYPE
);

-- A table type (array) of reason code information
TYPE tabTypReasons IS TABLE OF reason_cds%ROWTYPE
  INDEX BY BINARY_INTEGER;

-- A table type (array) of returns information
TYPE tabTypReturns IS TABLE OF recTypRtn
  INDEX BY BINARY_INTEGER;

-- ************************* <Variable Definitions> ****************************

gRcTypSyspar        recTypSyspar;

-- =============================================================================
-- Function
--   get_syspars
--
-- Description
--   The function retrieves all available syspars for Returns processing. All
--   syspars except PCT_TOLERANCE are defaulted to 'N' if they are not in the
--   system. The PCT_TOLERANCE will default to 100 if it's not in the system.
--   Currrent support syspars are:
--     RTN_DATA_COLLECTION  UPD_ITEM_PTYP_RETURN        RTN_PUTAWAY_CONF
--     LBR_MGMT_FLAG        CREATE_BATCH_FLAG
--     CC_GEN_EXC_RESERVE   PCT_TOLERANCE           RTN_BFR_MFC
--
-- Parameters
--   None
--
-- Returns
--   rcTypSyspar - A user defined record type to hold all related syspars.
--
-- Modification History
-- Date      User   Defect  Comment
--
FUNCTION get_syspars
RETURN recTypSyspar;

-- =============================================================================
-- Function
--   get_reason_info
--
-- Description
--   Retrieve return related reason code information according to the input
--   criteria.
--
-- Parameters
--   pszWhat (input)
--     Reason code type to be searched. Default to ALL which include RTN and
--     DIS reason code types.
--   pszRsnGroup (input)
--     Reason group to be searched. Default to 'ALL' which means all available
--     reason codes that met pszWhat criteria.
--   pszRsn (input)
--     Reason code to be searched. Default to none which means the function
--     might return more than 1 reason code information that met pszWhat and
--     pszRsnGroup criteria.
--
-- Returns
--   A table of REASON_CDS table type. The table count will be zero if search
--   criteria results in nothing found.
--
-- Modification History
-- Date      User   Defect  Comment
--
FUNCTION get_reason_info (
  pszWhat   IN reason_cds.reason_cd_type%TYPE DEFAULT 'ALL',
  pszRsnGroup   IN reason_cds.reason_group%TYPE DEFAULT 'ALL',
  pszRsn    IN reason_cds.reason_cd%TYPE DEFAULT NULL)
RETURN tabTypReasons;

-- =============================================================================
-- Function
--   get_order_line
--
-- Description
--   Search order_line_id value from ORDD, ORDD_FOR_RTN, and FLOAT_HIST
--   in this order according to the input criteria.
--
-- Parameters
--   ps_prod_id (input)
--     Item #
--   ps_cpv (input)
--     Cust Pref Vendor
--   pi_uom (input)
--     Uom to be searched
--   ps_inv (input)
--     (Regular) Invoice # to be searched
--   ps_org_inv (input)
--     Original invoice # to be searched. This is optional.
FUNCTION get_order_line (                           
  ps_prod_id	IN pm.prod_id%TYPE,                
  ps_cpv	IN pm.cust_pref_vendor%TYPE,       
  pi_uom	IN ordd.uom%TYPE,                  
  ps_inv	IN ordd.order_id%TYPE,             
  ps_org_inv	IN ordd.order_id%TYPE DEFAULT NULL)
RETURN NUMBER;

-- =============================================================================
-- Function
--   get_client_reason_info
--
-- Description
--   Retrieve return related reason code information according to the input
--   criteria. The function is mainly used by a caller that cannot accept PL/SQL
--   table type as return parameter. This function calls get_reason_info() to
--   retrieve all reason code information and convert the data to a long string
--   to be returned to the caller. It's up to the caller to seperate each group
--   of reason code information for usage (see poszRsns paramter for fields).
--
-- Parameters
--   poiNumRsns (output)
--     # of reason code information found and return: >= 0.
--   poszRsns (output)
--     A string of reason code information found or NULL. The caller string size
--     should be declared long enough to hold all current reason code
--     information in the database (currently up to 45 RTN type and up to 3 DIS
--     type reason codes.) Each reason code information include 3-byte reason
--     code, 15-byte reason code description and 3-byte reason group. Hence the
--     declared string size should have a minimum value of (3+15+3)*48 = 1008
--     bytes.
--   pszWhat (input)
--     Reason code type to be searched. Default to ALL which include RTN and
--     DIS reason types.
--   pszRsnGroup (input)
--     Reason group to be searched. Default to 'ALL' which means all available
--     reason codes that met pszWhat criteria.
--   pszRsn (input)
--     Reason code to be searched. Default to none which means the function
--     might return more than 1 reason code information that met pszWhat and
--     pszRsnGroup criteria.
--
-- Returns
--   See output parameters above.
--
-- Modification History
-- Date      User   Defect  Comment
--
PROCEDURE get_client_reason_info (
  poiNumRsns    OUT NUMBER,
  poszRsns      OUT VARCHAR2,
  pszWhat       IN  reason_cds.reason_cd_type%TYPE DEFAULT 'ALL',
  pszRsnGroup   IN  reason_cds.reason_group%TYPE DEFAULT 'ALL',
  pszRsn        IN  reason_cds.reason_cd%TYPE DEFAULT NULL);

-- =============================================================================
-- Function
--   get_mf_status
--
-- Description
--   Retrieve manifest status and route # according to the input manifest # or
--   order seq #. This is an overloaded function.
--
-- Parameters
--   piNum (input)
--     Either a manifest # or an order sequence #
--   poszRoute (output)
--     Route # that corresponding to the found manifest/order sequence or NULL
--   poszStatus (output)
--     A string of 'CLS', 'OPN', or 'PAD' as manifest status or a return code
--     for C_INV_MF (invalid manifest #) or negative database code.
--
-- Returns
--   See output parameters above.
--
PROCEDURE get_mf_status (
  piNum                 IN      NUMBER,
  poszRoute             OUT     manifests.route_no%TYPE,
  poszStatus            OUT     VARCHAR2);

-- =============================================================================
-- Function
--   get_mf_status
--
-- Description
--   Retrieve manifest status, route #, manifest #, (original) invoice # and
--   record type according to the input invoice #. This is an overloaded
--   function.
--
-- Parameters
--   pszSearch (input)
--     Invoice # or license plate to be searched
--   poszOutInv (output)
--     Return regular/pickup invoice # if available
--   poszOutOrigInv (output)
--     Return original invoice # if available 
--   piMfNo (output)
--     Return manifest # that is corresponding to the found invoice.
--   poszRecType (output)
--     Return record type of the invoice
--   poszRoute (output)
--     Route # that corresponding to the found manifest or NULL
--   poszStatus (output)
--     A string of 'CLS', 'OPN', or 'PAD' as manifest status or a return code
--     for C_INV_MF (invalid manifest #) or a return code for C_INV_LABEL
--     (invalid license plate) or negative database code.
--   piAsLP (input)
--     Whether the pszSearch value is a license plate (<> 0) or invoice #
--     (= 0, default)
--
-- Returns
--   See output parameters above.
--
-- Modification History
-- Date      User   Defect  Comment
--
PROCEDURE get_mf_status (
  pszSearch     IN  putawaylst.pallet_id%TYPE,
  poszOutInv        OUT manifest_dtls.obligation_no%TYPE,
  poszOutOrigInv    OUT manifest_dtls.orig_invoice%TYPE,
  piMfNo        OUT manifests.manifest_no%TYPE,
  poszRecType       OUT manifest_dtls.rec_type%TYPE,
  poszRoute     OUT manifests.route_no%TYPE,
  poszStatus        OUT VARCHAR2,
  piAsLP        IN  NUMBER DEFAULT 0);

-- =============================================================================
-- Function
--   get_mf_info
--
-- Description
--   The function retrieves manifest header information according the input
--   manifest #. This is an overloaded procedure.
--
-- Parameters
--   piMfNo (input)
--     Manifest # to be used to retrieve information
--   pRwTypMfHdr (output)
--     MANIFESTS table type for the found manifest #. NULL if the manifest #
--     cannot be found
--
-- Returns
--   See output parameters above
--
-- Modification History
-- Date      User   Defect  Comment
--
PROCEDURE get_mf_info(
  piMfNo      IN  returns.manifest_no%TYPE,
  pRwTypMfHdr OUT manifests%ROWTYPE);

-- =============================================================================
-- Function
--   get_mf_info
--
-- Description
--   The function retrieves manifest header, manifest detail information and
--   ship cases according the input return information. This is an overloaded
--   procedure.
--
-- Parameters
--   pRwTypRtn (input)
--     Return information to be used to retrieve information
--   pRwTypMfHdr (output)
--     MANIFESTS table type for the found return. NULL if no data is found
--   pRwTypMfDtls (output)
--     MANIFEST_DTLS table type for the found return. NULL if no data is found
--   piShipInCases (output)
--     Shipped qty in cases from the invoiced item according to the return
--
-- Returns
--   See output parameters above
--
-- Modification History
-- Date      User   Defect  Comment
--
PROCEDURE get_mf_info(pRwTypRtn     IN  returns%ROWTYPE,
                      pRwTypMfHdr   OUT manifests%ROWTYPE,
                      pRwTypMfDtls  OUT manifest_dtls%ROWTYPE,
                      piShipInCases OUT NUMBER);

-- =============================================================================
-- Function
--   check_putaway
--
-- Description
--   Check if the putaway task exists or not according to the input criteria.
--   Return the found putaway task record to the caller and it's up to the
--   caller to do something about it.
--
-- Parameters
--   pszRsnGroup (input)
--     Reason group to be used to determine what type of putaway task record to
--     be searched (saleable or damage)
--   pRwTypRtn (input)
--     Return information to be searched
--
-- Returns
--   Putawaylst table type
--     If information is found, the non-empty record is returned. The
--     putaway_put and putpath fields will have Y/N and C_NORMAL, respectively.
--     If no information is found, the table type will still be returned but
--     won't have any information except the putaway_put and putpath fields
--     which have the value of 'X' and C_NOT_FOUND, respectively.
--     If database error occurred, the table type will still be returned but
--     won't have any information except the putaway_put and putpath fields
--     which have the value of 'O' and negative error code, respectively.
--
-- Modification History
-- Date      User   Defect  Comment
--
FUNCTION check_putaway (
  pszRsnGroup           IN      reason_cds.reason_group%TYPE,
  pRwTypRtn             IN      returns%ROWTYPE)
RETURN putawaylst%ROWTYPE;

-- =============================================================================
-- Function
--   get_range_returns
--
-- Description
--   The function handles the retrieval of return information plus other
--   relevant information according to the search criteria. 
--
-- Parameters
--   piNextRecSet (input)
--     Indicate the next set of records to be retrieved up to the end of data
--     that met the search criteria or up to C_RECS_PER_PAGE. 3 sets of values:
--       <0  Retrieve all records that met the search criteria pszSearch.
--       =0  Retrieve all records that met the search criteria pszSearch and
--           between piMinLine and piMaxLine and up to C_RECS_PER_PAGE records.
--       >0  Retrieve all records that met the search criteria pszSearch and
--           >= piNextRecSet and up to C_RECS_PER_PAGE records.
--   pszSearch (input)
--     String/value to be searched. Supported value is either manifest #,
--     invoice #, or license plate #.
--   poiNumRtns (output)
--     # of returns back to caller that met the search criteria.
--   poiNumCurRtns (output)
--     # of returns back to caller that met the search criteria and up to
--     C_RECS_PER_PAGE records.
--   poiNumWeightRtns (output)
--     # of returns back to caller that met the search criteria and need weight
--   poiNumTempRtns (output)
--     # of returns back to caller that met the search criteria and need
--     temperature.
--   potabTypRtns (output)
--     Table of return records (recTypRtn) that met the search criteria.
--   piAllRtns (input)
--     Indicate whether to get everything that are currently in the RETURNS
--     table (<>0), regardless if the return reason code is invalid,
--     item has been putawayed, or the returned qty in the returns must be
--     greater than 0 (=0, default).
--   pszValue1 (input)
--     Extra search criteria. Supported value is item #, 'LP' (case not
--     sensitive) or NULL (default). Value 'LP' means that the pszSearch value
--     will be a license plate.
--   pszValue2 (input)
--     Extra search criteria. Supported value is cust_pref_vendor or '-'
--     (default).
--   piValue3 (input)
--     Extra search criteria. Supported value is erm_line_id or NULL (default).
--   piRecTyp (input)
--     It has one of the following valid values:
--       0: Retrieve all matched records (default)
--       1: catchweight-only records
--       2: temperature-only records
--       3: all matched records that need catchweight or temperature collection
--          (i.e., flag = 'Y')
--       4: all matched records that catchweights or temperatures have been
--          collected (i.e., flag = 'C')
--       5: catchweight-only records that need catchweight collection
--       6: temperature-only records that need temperature collection
--       7: catchweight-only records in which the catchweights have been
--          collected
--       8: temperature-only records in which the temperatures have been
--          collected
--     Specifying 0, 1, or 2 will return all matched records that have tracked
--     flags of either 'N', 'Y' or 'C'.
--   pszType (input)
--     Type of returns that will sent back to caller. 'ALL' (default) means all
--     returns. 'SALE' means only saleable returns. 'DMG' means only damage
--     returns. 'PUT' means only returns that have putawayt tasks generated.
--     'NOPUT' means only returns that have NO putaway tasks.
--   piMinLine (input)
--     Minimum erm_line_id of the return information to be retrieved. Default
--     is 1. This parameter is used along with piNextRecSet = 0. Not need if
--     piNextRecSet <> 0.
--   piMaxLine (input)
--     Maximum erm_line_id of the return information to be retrieved. Default
--     is 9999. This parameter is used along with piNextRecSet = 0. Not need
--     if piNextRecSet <> 0.
--
-- Returns
--   See output parameters above.
--
-- Modification History
-- Date      User   Defect  Comment
--
PROCEDURE get_range_returns (
  piNextRecSet      IN  NUMBER,
  pszSearch     IN  putawaylst.pallet_id%TYPE,
  poiNumRtns        OUT NUMBER,
  poiNumCurRtns     OUT NUMBER,
  poiNumWeightRtns  OUT NUMBER,
  poiNumTempRtns    OUT NUMBER,
  potabTypReturns   OUT tabTypReturns,
  piAllRtns     IN  NUMBER DEFAULT 0,
  pszValue1     IN  pm.external_upc%TYPE DEFAULT NULL,
  pszValue2     IN  pm.cust_pref_vendor%TYPE DEFAULT C_DFT_CPV,
  piValue3      IN  returns.erm_line_id%TYPE DEFAULT NULL,
  piRecTyp      IN  NUMBER DEFAULT 0,  
  pszType       IN  VARCHAR2 DEFAULT 'ALL',
  piMinLine     IN  returns.erm_line_id%TYPE DEFAULT 1,
  piMaxLine     IN  returns.erm_line_id%TYPE DEFAULT 9999);

-- =============================================================================
-- Function
--   delete_return
--
-- Description
--   The function delete a specific return (RETURNS table) according to data
--   from the pRwTypRtn structure from the system. It also deletes the
--   corresponding data from ERM, ERD, PUTAWAYLST, TMP_RTN_WEIGHT, and/or
--   TMP_RTN_TEMP tables and undo T-batch if available. This is an overload
--   function.
--
-- Parameters
--   pRwTypRtn (input)
--     Return information to be deleted
--   pszRsnGroup (input)
--     Reason group to be used to determine the action if available. If it's
--     not specified (i.e., NULL), the function will look for it.
--
-- Returns
--   0 - Delete of the specific return information is successful.
--   C_INV_RSN - Invalid reason code is encountered.
--   C_DEL_NOT_ALLOWED - Cannot delete pickup (rec_type = 'P') return.
--   C_PUT_DONE - Putaway for the return has been done. Action is not allowed.
--   < 0 - Database error (including 1403)
--
-- Modification History
-- Date      User   Defect  Comment
--
FUNCTION delete_return (
  pRwTypRtn IN  returns%ROWTYPE,
  pszRsnGroup   IN  reason_cds.reason_group%TYPE DEFAULT NULL)
RETURN NUMBER;

-- =============================================================================
-- Function
--   delete_return
--
-- Description
--   The function delete a specific return (RETURNS table) according to input
--   argument. Current supported argument is license plate. It also deletes the
--   corresponding data from ERM, ERD, PUTAWAYLST, TMP_RTN_WEIGHT, and/or
--   TMP_RTN_TEMP tables and undo T-batch if available. This is an overload
--   function. It actually calls the overloaded delete_return() function with
--   pRwTypRtn as argument after retrieving the data from PUTAWAYLST according
--   to the input license plate #.
--
-- Parameters
--   pszValue (input)
--     License plate to be deleted
--
-- Returns
--   0 - Delete of the specific return information is successful.
--   C_INV_RSN - Invalid reason code is encountered.
--   C_DEL_NOT_ALLOWED - Cannot delete pickup (rec_type = 'P') return.
--   C_PUT_DONE - Putaway for the return has been done. Action is not allowed.
--   < 0 - Database error (including 1403)
--
-- Modification History
-- Date      User   Defect  Comment
--
FUNCTION delete_return (
  pszValue  IN  putawaylst.pallet_id%TYPE)
RETURN NUMBER;

-- =============================================================================
-- Function
--   set_rtn_label_printed
--
-- Description
--   Set the returned label printed flag (on the putaway task) to (Y)es for the
--   input license plate.
--
-- Parameters
--   pszPalletID (input)
--     Pallet ID to be searched
--
-- Returns
--   0 - Update of label printed flag OK.
--   C_UPD_PUTLST_FAIL - Cannot find the license plate or database error
--     occurred
--
-- Modification History
-- Date      User   Defect  Comment
--
FUNCTION set_rtn_label_printed (
  pszPalletID   IN  putawaylst.pallet_id%TYPE)
RETURN NUMBER;

-- =============================================================================
-- Function
--   get_default_printer_info
--
-- Description
--   Retrieve the default Returns printer for current user. Note that the
--   function only retrieves default printer for the rp1ri (Return Rec Labels)
--   report or the rp2ri report (Returns LM Batch Labels) if rp1ri is not
--   available.
--
-- Parameters
--   None
--
-- Returns
--   Print_queues table row type or NULL
--
FUNCTION get_default_printer_info
RETURN print_queues%ROWTYPE;

-- =============================================================================
-- Function
--   close_manifest
--
-- Description
--   The function closes the specified manifest. Delete confirmed putaway tasks
--   and create RTN and MFC transactions. Note that the function doesn't send
--   the return list back. The display of the list should be accomplished by
--   the client_close_manifest() and/or get_range_returns() procedures.
--
-- Parameters
--   piMfNo (input)
--     Manifest to be closed
--   poszLMStr (output)
--     A string contends a list of item/cust_pref_vendor/pallet_type changes
--     for new floating slots that are generated for the cycle count locations.
--     The caller must seperate the string into individual records and send
--     them seperately through the LM APCOM queue to SUS to notify SUS of
--     the pallet type changes. NULL if no pallet type change at all.
--   poszMsg (output)
--     Error message to be returned to the caller. The message will have
--     information such as invoice #, item #. Example messages are:
--       * Invalid reason code is found for a particular returned item
--       * Temperature for a particular return out of tolerance
--       * Need catchweight for a particular return that is weight-tracked and
--         returned qty is less than shipped qty
--   poiStatus (output)
--     Return status is one of the following:
--       0 - The manifest is closed without any problem
--       C_NO_MF_INFO - The total # of returns doesn't match that of returned
--         PO details. Ask caller to do tripmaster on the manifest again.
--       C_INV_MF - The manifest is invalid
--       C_MF_HAS_CLOSED - The manifest has been closed when the function is
--         called
--       C_TEMP_REQUIRED - Temperature is required
--       C_TEMP_OUT_OF_RANGE - Temperature is out of range for a particular
--         return. The poszMsg will specify which return.
--       C_INV_RSN - Invalid reason code encountered in one of the returns
--       C_INV_PRODID - Invalid invoiced/mispicked item
--       C_WEIGHT_DESIRED - Weight needed for less qty
--       C_NO_LOC - At least one cycle count and exception record generation
--         cannot find the location. This returned code is not fatal to the
--         caller. It's just a way to notify caller about the situation and
--         caller can notify user as an warning or informational message.
--       <0 - Database error occurred
--
-- Returns
--   See output parameters above.
--
-- Modification History
-- Date      User   Defect  Comment
--
PROCEDURE close_manifest (
  piMfNo        IN      manifests.manifest_no%TYPE,
  poszLMStr OUT VARCHAR2,
  poszMsg       OUT     VARCHAR2,
  poiStatus     OUT     NUMBER);

-- =============================================================================
-- Function
--   client_close_manifest
--
-- Description
--   The function can perform two tasks:
--     1. Close the specified manifest: delete confirmed putaway tasks and
--        create RTN and MFC transactions by calling close_mainfest() procedure.
--     2. Returns to the caller all returns information related to the specific
--        manifest that caller plans to close. The # of returns information
--        returned depend on the current piNextRecSet value and C_RECS_PER_PAGE
--        value and the # of available database records.
--
-- Parameters
--   pszValue1 (input)
--     One of the search criteria for the action. Acceptable value is either
--     manifest #, invoice #, or license plate.
--   poszLMStr (output)
--     A string contends a list of item/cust_pref_vendor/pallet_type changes
--     for new floating slots that are generated for the cycle count locations.
--     The caller must seperate the string into individual records and send
--     them seperately throught the LM APCOM queue to SUS to notify SUS of
--     the pallet type changes. NULL if no pallet type change at all.
--   poszMsg (output)
--     Error message to be returned to the caller. The message will have
--     information such as invoice #, item #. Example messages are:
--       * Invalid reason code is found for a particular returned item
--       * Temperature for a particular return out of tolerance
--       * Need catchweight for a particular return that is weight-tracked and
--         returned qty is less than shipped qty.
--   poiNumRtns (output)
--     # of returns back to caller that met the search criteria.
--   poiNumCurRtns (output)
--     # of returns back to caller that met the search criteria and up to
--     C_RECS_PER_PAGE records.
--   poiNumWeightRtns (output)
--     # of returns back to caller that met the search criteria and need weight
--   poiNumTempRtns (output)
--     # of returns back to caller that met the search criteria and need
--     temperature.
--   poszRtns (output)
--     String of returns information (recTypRtn) for the caller.
--   poiStatus (output)
--     Return status is one of the following:
--       0 - The manifest is closed without any problem
--       C_NO_MF_INFO - The total # of returns doesn't match that of returned
--         PO details. Ask caller to do tripmaster on the manifest again.
--       C_INV_MF - The manifest is invalid
--       C_MF_HAS_CLOSED - The manifest has been closed when the function is
--         called
--       C_TEMP_REQUIRED - Temperature is required
--       C_TEMP_OUT_OF_RANGE - Temperature is out of range for a particular
--         return. The poszMsg will specify which return.
--       C_INV_RSN - Invalid reason code encountered in one of the returns
--       C_INV_PRODID - Invalid invoiced/mispicked item
--       C_WEIGHT_DESIRED - Weight needed for less qty
--       C_NO_LOC - At least one cycle count and exception record generation
--         cannot find the location. This returned code is not fatal to the
--         caller. It's just a way to notify caller about the situation and
--         caller can notify user as an warning or informational message.
--       <0 - Database error occurred
--   pszValue2 (input)
--     One of the search criteria for the action. Acceptable value is item #.
--     This field needs to work together with pszValue1. Default to NULL.
--   pszValue3 (input)
--     One of the search criteria for the action. Acceptable value is
--     cust_pref_vendor. This field needs to work together with pszValue1
--     and pszValue2. Default to '-'.
--   piNextRecSet (input)
--     If the value is 0, perform the manifest close action. Otherwise, perform
--     the returns information retrieval action.
--   piRecTyp (input)
--     It has one of the following valid values:
--       0: Retrieve all matched records (default)
--       1: catchweight-only records
--       2: temperature-only records
--       3: all matched records that need catchweight or temperature collection
--          (i.e., flag = 'Y')
--       4: all matched records that catchweights or temperatures have been
--          collected (i.e., flag = 'C')
--       5: catchweight-only records that need catchweight collection
--       6: temperature-only records that need temperature collection
--       7: catchweight-only records in which the catchweights have been
--          collected
--       8: temperature-only records in which the temperatures have been
--          collected
--     Specifying 0, 1, or 2 will return all matched records that have tracked
--     flags of either 'N', 'Y' or 'C'.
--
-- Returns
--   See output parameters above.
--
-- Modification History
-- Date      User   Defect  Comment
--
PROCEDURE auto_close_manifest;
---------------------------------------------------------------------------------
   -- Description:
   --  Return process: it will be called by cron job
   --  
   -- Modification History:
   --    Date     Designer        Comments
   --    -------- --------        -----------------------------------------------------
   --    04/18/2018 ezheng      Created.
   --   
   --
   -----------------------------------------------------------------------------
PROCEDURE client_close_manifest (
  pszValue1             IN      inv.logi_loc%TYPE,
  poszLMStr             OUT     VARCHAR2,
  poszMsg               OUT     VARCHAR2,
  poiNumRtns            OUT     NUMBER,
  poiNumCurRtns         OUT     NUMBER,
  poiNumWeightRtns      OUT     NUMBER,
  poiNumTempRtns        OUT     NUMBER,
  poszRtns              OUT     VARCHAR2,
  poiStatus             OUT     NUMBER,
  pszValue2             IN      inv.logi_loc%TYPE DEFAULT NULL,
  pszValue3             IN      inv.logi_loc%TYPE DEFAULT C_DFT_CPV,
  piNextRecSet          IN      NUMBER DEFAULT 0,
  piRecTyp      IN  NUMBER DEFAULT 0);

-- =============================================================================
-- Function
--   invoice_return
--
-- Description
--   The function handles creations of returned PO headers, returned PO details,
--   putaway tasks, and/or LM returned batches for the specified invoice.
--
-- Parameters
--   pszInv (input)
--     Invoice # to do whole invoice return.
--   pszRsn (input)
--     Reason code for the invoice return.
--   poiMinLine (output)
--     The minimum erm_line_id that the returns being created for the invoice.
--   poszMsg (output)
--     Message to be sent back if any. Basic message includes but not limited
--     to one of the followings:
--       * No location is found for item
--       * Duplicate LP exists for putaway task
--   poszLMStr (output)
--     A string contends a list of item/cust_pref_vendor/pallet_type changes
--     for new floating slots that are generated for the cycle count locations.
--     The caller must seperate the string into individual records and send
--     them seperately throught the LM APCOM queue to SUS to notify SUS of
--     the pallet type changes. NULL if no pallet type change at all.
--   poiStatus
--     Processing status code:
--       0 - Invoice return processing is successful. The information list is
--         in potabTypReturns type.
--       C_INV_MF - Corresponding manifest # (from the invoice) is invalid.
--       C_MF_HAS_CLOSED - Corresponding manifest has been closed.
--       C_INV_RTN - The invoice has been returned before.
--       C_INV_RTI_CLS - The invoice return has been done before.
--       C_INV_RSN - Invoice return reason code is invalid or input reason
--         code doesn't match with the pickup reason code.
--       C_NO_LOC - No location is found for an invoiced item (poszMsg will
--         have the detail.)
--       C_TEMP_REQUIRED - Temperature is required for at least one item in
--         the invoice. The information list is in potabTypReturns type
--         catch_wt_trk column.
--       C_NO_DFT_PRINTER - No default user printer is set up. The code will
--         only be returned if total # of returns generated are over
--         C_PRT_RANGE_MIN value AND there is no user default printer.
--       <0 - database error.
--   piUsePrtOpt
--     Flag to indicate if caller wants to print the labels (>0) after the
--     returns creation are done or not (0, default).
--
-- Returns
--   See output parameters above.
--
-- Modification History
-- Date      User   Defect  Comment
--
PROCEDURE invoice_return (
  pszInv        IN      manifest_dtls.obligation_no%TYPE,
  pszRsn        IN      reason_cds.reason_cd%TYPE,
  poiMinLine    OUT returns.erm_line_id%TYPE,
  poszMsg       OUT     VARCHAR2,
  poszLMStr OUT VARCHAR2,
  poiStatus     OUT     NUMBER,
  piUsePrtOpt   IN  NUMBER DEFAULT 0);

-- =============================================================================
-- Function
--   client_invoice_return
--
-- Description
--   The function handles creations of returned PO headers, returned PO details,
--   putaway tasks, and/or LM returned batches for the specified invoice (thru
--   invoice_return procedure.) It can also retrieve the next set of returns
--   for the invoice that are just created. See Parameters below for field
--   input requirements and details.
--   This function is mainly used by caller that cannot handle PL/SQL table
--   type.
--
-- Parameters
--   piNextRecSet (input)
--     The starting record/line # of the returns that caller wants to query the
--     invoice from. The number should be input as 0 if the caller wants to 
--     create returns for the invoice (i.e., the invoice hasn't been returned
--     before.) The number should be < 0 if the caller wants to query all
--     returns related to the invoice. The number should be > 0 if the caller
--     wants to retrieve returns that have a starting erm_line_id greater than
--     or equal to this number. If the number is < 0, the # of records returned
--     thru the output poszRtns string are not limited to the C_RECS_PER_PAGE
--     constant while >0 does.
--   pszInv (input)
--     Invoice # to do whole invoice return or query info for the invoice.
--   pszRsn (input)
--     Reason code for the invoice return. Caller doesn't need to specify a
--     value if the piNextRecSet value > 0. The parameter will not be used if
--     piNextRecSet > 0.
--   poszMsg (output)
--     Message to be sent back if any. Basic message includes but not limited
--     to one of the followings:
--       * No location is found for item
--       * Duplicate LP exists for putaway task.
--     The output will be NULL if piNextRecSet is <= 0.
--   poszLMStr (output)
--     A string contends a list of item/cust_pref_vendor/pallet_type changes
--     for new floating slots that are generated for the cycle count locations.
--     The caller must seperate the string into individual records and send
--     them seperately throught the LM APCOM queue to SUS to notify SUS of
--     the pallet type changes. NULL if no pallet type change at all.
--   poiNumRtns (output)
--     # of returns generated for the to-do/query invoice; >= 0.
--   poiNumCurRtns (output)
--     # of actual returns from the function; <= poiNumRtns/C_RECS_PER_PAGE but
--     >= 0.
--   poiNumTemps (output)
--     # of returns that need temperatures; <= poiNumRtns/C_RECS_PER_PAGE but
--     >= 0.
--   poszRtns (output)
--     A long string that saves return information related to the to-do/query
--     invoice. The string consists limited # of records (up to C_RECS_PER_PAGE)
--     that are generated/queried according to the searched criteria. The length
--     of each record is a fixed number. Each record consists limited # of
--     fields which are also in fixed length. The current fields are:
--   poiStatus
--     Processing status code:
--       0 - Invoice return processing is successful. The information list is
--         in potabTypReturns type.
--       C_INV_MF - Corresponding manifest # (from the invoice) is invalid.
--       C_MF_HAS_CLOSED - Corresponding manifest has been closed.
--       C_INV_RTN - The invoice has been returned before.
--       C_INV_RTI_CLS - The invoice return has been done before.
--       C_INV_RSN - Invoice return reason code is invalid or input reason
--         code doesn't match with the pickup reason code.
--       C_NO_LOC - No location is found for an invoiced item (poszMsg will
--         have the detail.)
--       C_TEMP_REQUIRED - Temperature is required for at least one item in
--         the invoice. The information list is in potabTypReturns type
--         catch_wt_trk column.
--       C_NO_DFT_PRINTER - No default user printer is set up. The code will
--         only be returned if total # of returns generated are over
--         C_PRT_RANGE_MIN value AND there is no user default printer.
--       <0 - database error.
--   piUsePrtOpt
--     Flag to indicate if caller wants to print the labels (>0) after the
--     returns creation are done or not (0, default).
--
-- Returns
--   See output parameters above.
--
-- Modification History
-- Date      User   Defect  Comment
--
PROCEDURE client_invoice_return (
  piNextRecSet  IN      NUMBER,
  pszInv        IN      manifest_dtls.obligation_no%TYPE,
  pszRsn        IN      reason_cds.reason_cd%TYPE,
  poszMsg       OUT     VARCHAR2,
  poszLMStr OUT VARCHAR2,
  poiNumRtns    OUT     NUMBER,
  poiNumCurRtns OUT     NUMBER,
  poiNumTemps   OUT     NUMBER,
  poszRtns      OUT     VARCHAR2,
  poiStatus     OUT     NUMBER,
  piUsePrtOpt   IN      NUMBER DEFAULT 0);

-- =============================================================================
-- Function
--   update_invoice_return
--
-- Description
--   The function handles updates of returned PO headers, returned PO details,
--   putaway tasks, and/or LM returned batches for the specified invoice.
--
-- Parameters
--   pszInv (input)
--     Invoice # to do invoice update action
--   pszRsn (input)
--     Reason code for the invoice return.
--   poiMinLine (output)
--     The minimum erm_line_id that the returns being created for the invoice.
--   poszMsg (output)
--     Message to be sent back if any. Basic message includes but not limited
--     to one of the followings:
--       * No location is found for item
--       * Duplicate LP exists for putaway task
--   poszLMStr (output)
--     A string contends a list of item/cust_pref_vendor/pallet_type changes
--     for new floating slots that are generated for the cycle count locations.
--     The caller must seperate the string into individual records and send
--     them seperately throught the LM APCOM queue to SUS to notify SUS of
--     the pallet type changes. NULL if no pallet type change at all.
--   poiStatus
--     Processing status code:
--       0 - Invoice return processing is successful. The information list is
--         in potabTypReturns type.
--       C_INV_MF - Corresponding manifest # (from the invoice) is invalid.
--       C_MF_HAS_CLOSED - Corresponding manifest has been closed.
--       C_INV_RSN - Invoice return reason code is invalid or input reason
--         code doesn't match with the pickup reason code.
--       C_PUT_DONE - At lease one of the returns in the invoice has been
--         putawayed
--       C_NO_LOC - No location is found for an invoiced item (poszMsg will
--         have the detail.)
--       C_TEMP_REQUIRED - Temperature is required for at least one item in
--         the invoice. The information list is in potabTypReturns type
--         catch_wt_trk column.
--       C_NO_DFT_PRINTER - No default user printer is set up. The code will
--         only be returned if total # of returns generated are over
--         C_PRT_RANGE_MIN value AND there is no user default printer.
--       <0 - database error.
--   piUsePrtOpt
--     Flag to indicate if caller wants to print the labels (>0) after the
--     returns creation are done or not (0, default).
--
-- Returns
--   See output parameters above.
--
-- Modification History
-- Date      User   Defect  Comment
--
PROCEDURE update_invoice_return (
  pszInv    IN  manifest_dtls.obligation_no%TYPE,
  pszRsn    IN  reason_cds.reason_cd%TYPE,
  poiMinLine    OUT returns.erm_line_id%TYPE,
  poszMsg   OUT VARCHAR2,
  poszLMStr OUT VARCHAR2,
  poiStatus OUT NUMBER,
  piUsePrtOpt   IN  NUMBER DEFAULT 0);

-- =============================================================================
-- Function
--   client_update_invoice_return
--
-- Description
--   The function handles updates of returned PO headers, returned PO details,
--   putaway tasks, and/or LM returned batches for the specified invoice. The
--   function is used by caller that cannot handle PL/SQL table record returned
--   type. The function will return a list of updated returns in a long string.
--
-- Parameters
--   piNextRecSet (input)
--     Indicate the next set of records to be retrieved up to the end of data
--     that met the search criteria or up to C_RECS_PER_PAGE. 3 sets of values:
--       =0  Perform update of invoice return action with the specified reason
--           and then send the 1st C_RECS_PER_PAGE or less records back.
--       >0  Retrieve all records that met the search criteria pszInv and
--           >= piNextRecSet and up to C_RECS_PER_PAGE records.
--   pszInv (input)
--     Invoice # to do invoice update action
--   pszRsn (input)
--     Reason code for the invoice return.
--   poiMinLine (output)
--     The minimum erm_line_id that the returns being created for the invoice.
--   poszMsg (output)
--     Message to be sent back if any. Basic message includes but not limited
--     to one of the followings:
--       * No location is found for item
--       * Duplicate LP exists for putaway task
--   poszLMStr (output)
--     A string contends a list of item/cust_pref_vendor/pallet_type changes
--     for new floating slots that are generated for the cycle count locations.
--     The caller must seperate the string into individual records and send
--     them seperately throught the LM APCOM queue to SUS to notify SUS of
--     the pallet type changes. NULL if no pallet type change at all.
--   poiNumRtns (output)
--     # of returns back to caller that met the search criteria.
--   poiNumCurRtns (output)
--     # of returns back to caller that met the search criteria and up to
--     C_RECS_PER_PAGE records.
--   poiNumTemps (output)
--     # of returns back to caller that met the search criteria and need
--     temperature.
--   poszRtns (output)
--     A string of returns record information or NULL
--   poiStatus
--     Processing status code:
--       0 - Invoice return processing is successful. The information list is
--         in potabTypReturns type.
--       C_INV_MF - Corresponding manifest # (from the invoice) is invalid.
--       C_MF_HAS_CLOSED - Corresponding manifest has been closed.
--       C_INV_RSN - Invoice return reason code is invalid or input reason
--         code doesn't match with the pickup reason code.
--       C_PUT_DONE - At lease one of the returns in the invoice has been
--         putawayed
--       C_NO_LOC - No location is found for an invoiced item (poszMsg will
--         have the detail.)
--       C_TEMP_REQUIRED - Temperature is required for at least one item in
--         the invoice. The information list is in potabTypReturns type
--         catch_wt_trk column.
--       C_NO_DFT_PRINTER - No default user printer is set up. The code will
--         only be returned if total # of returns generated are over
--         C_PRT_RANGE_MIN value AND there is no user default printer.
--       <0 - database error.
--   piUsePrtOpt
--     Flag to indicate if caller wants to print the labels (>0) after the
--     returns creation are done or not (0, default).
--
-- Returns
--   See output parameters above.
--
-- Modification History
-- Date      User   Defect  Comment
--
PROCEDURE client_update_invoice_return (
  piNextRecSet  IN      NUMBER,
  pszInv        IN      manifest_dtls.obligation_no%TYPE,
  pszRsn        IN      reason_cds.reason_cd%TYPE,
  poiMinLine    OUT     returns.erm_line_id%TYPE,
  poszMsg       OUT     VARCHAR2,
  poszLMStr     OUT     VARCHAR2,
  poiNumRtns    OUT     NUMBER,
  poiNumCurRtns OUT     NUMBER,
  poiNumTemps   OUT     NUMBER,
  poszRtns      OUT     VARCHAR2,
  poiStatus     OUT     NUMBER,
  piUsePrtOpt   IN      NUMBER DEFAULT 0);

-- =============================================================================
-- Function
--   delete_invoice_return
--
-- Description
--   The function handles the "undo" of the previous processed invoice return.
--   It will clear out the corresponding records in the PUTAWAYLST, ERM, ERD
--   and RETURNS tables.
--
-- Parameters
--   pszInv (input)
--     Invoice # to do invoice delete action
--   pszRsn (input)
--     Reason code for the invoice return. If the caller is to update the
--     information for the invoice (from (client_)update_invoice_return()),
--     the reason code should be included from the update action so it can be
--     used to check whether the invoice with the same reason codes have been
--     returned before. If it's mainly for the delete action, the reason code
--     should be NULL.
--   piActionType (output)
--     Indicate what the caller's intention to use this procedure. Default to
--     0 for invoice delete action or nonzero for invoice update action.
--
-- Returns
--   0 - Invoice return delete processing is successful. 
--   C_INV_MF - Corresponding manifest # (from the invoice) is invalid.
--   C_MF_HAS_CLOSED - Corresponding manifest has been closed.
--   C_INV_INVNO - Invalid invoice # specified
--   C_PUT_DONE - At lease one of the returns in the invoice has been
--     putawayed
--   C_INV_RTN - The reason code with the invoice has been returned before.
--     The error code will be returned only if the piActionType <> 0 (for
--     invoice update action.)
--   C_INV_RSN - Invalid reason code encountered.
--   C_DEL_NOT_ALLOWED - Caller cannot delete the invoice because it's a pickup
--   <0 - database error.
--
-- Modification History
-- Date      User   Defect  Comment
--
FUNCTION delete_invoice_return (
  pszInv        IN      manifest_dtls.obligation_no%TYPE,
  pszRsn    IN  reason_cds.reason_cd%TYPE DEFAULT NULL,
  piActionType  IN      NUMBER DEFAULT 0)
RETURN NUMBER;

-- =============================================================================
-- Function
--   tripmaster
--
-- Description
--   The function handles creations of returned PO headers, returned PO details,
--   putaway tasks, and/or LM returned batches for those returns that have set
--   up (or have downloaded from OSD PC) but haven't committed yet.
--   Note: If at least one of the uncomitted returns has invalid reason code,
--   this function will not catch the error.
--
-- Parameters
--   piMfNo (input)
--     Manifest # to be tripmastered
--   pszInv (input)
--     Invoice # to be tripmastered. Default to NULL. If the value is present,
--     the piMfNo value is ignored or the found manifest # must be equal to
--     piMfNo.
--   poszMsg (output)
--     Message to be sent back if any. Basic message includes but not limited
--     to one of the followings:
--       * No location is found for item
--       * Duplicate LP exists for putaway task
--   poszLMStr (output)
--     A string contends a list of item/cust_pref_vendor/pallet_type changes
--     for new floating slots that are generated for the cycle count locations.
--     The caller must seperate the string into individual records and send
--     them seperately throught the LM APCOM queue to SUS to notify SUS of
--     the pallet type changes. NULL if no pallet type change at all.
--   poiStatus
--     Processing status error code:
--       0 - SWMS Tripmaster function is successful.
--       C_INV_MF - Invalid manifest # is specified.
--       C_MF_HAS_CLOSED - Manifest has been closed. Action is not allowed.
--       C_INV_INVNO - Invalid invoice # is specified.
--       C_NO_LOC - Location is not found for item (poszMsg will have the
--         invoice and item #.) 
--       <0 - database error
--
-- Returns
--   See output parameters above.
--
-- Modification History
-- Date      User   Defect  Comment
--
PROCEDURE tripmaster (
  piMfNo    IN  manifests.manifest_no%TYPE,
  pszInv    IN  manifest_dtls.obligation_no%TYPE DEFAULT NULL,
  poszMsg   OUT VARCHAR2,
  poszLMStr OUT VARCHAR2,
  poiStatus OUT NUMBER);
-- =============================================================================
-- Procedure
--   tripmaster
--
-- Description
--   The function validates a single manifest passed or all the manifests in the  
--   returns table. If the validation is successful then PUTAWAY tasks would be 
--   created along with PO in ERM/ERD table. Finally the status of the returns
--   in MANIFEST_DTLS and RETURNS table will be updated as RTN.
-- Parameters
--   piMfNo (input)
--     Manifest # to be tripmastered
--   pszInv (input)
--     Invoice # to be tripmastered. Default to NULL. If the value is present,
--     the piMfNo value is ignored or the found manifest # must be equal to
--     piMfNo.
--   poszMsg (output)
--     Message to be sent back if any. Basic message includes but not limited
--     to one of the followings:
--       * No location is found for item
--       * Duplicate LP exists for putaway task
--   poszLMStr (output)
--     A string contends a list of item/cust_pref_vendor/pallet_type changes
--     for new floating slots that are generated for the cycle count locations.
--     The caller must seperate the string into individual records and send
--     them seperately throught the LM APCOM queue to SUS to notify SUS of
--     the pallet type changes. NULL if no pallet type change at all.
--   poiStatus
--     Processing status error code:
--       0 - SWMS Tripmaster function is successful.
--       C_INV_MF - Invalid manifest # is specified.
--       C_MF_HAS_CLOSED - Manifest has been closed. Action is not allowed.
--       C_INV_INVNO - Invalid invoice # is specified.
--       C_NO_LOC - Location is not found for item (poszMsg will have the
--         invoice and item #.) 
--       C_INCONSISTENT_MF
--       <0 - database error
--
-- Returns
-- See output parameters above.

PROCEDURE validate_tripmaster (
  i_manifest_no          IN  manifests.manifest_no%TYPE,
  o_exception_error      OUT VARCHAR2,
  o_returns_err_count    OUT NUMBER);

-- =============================================================================
-- Function
--   validate_tripmaster
--
-- Description
--     This routine is to update err_comment in returns table where there
--       are invalid prod_id, invalid reason_cd, return_qty is not positive value,
--       invalid UOM or split code, and invalid stop_no
--
-- Parameters
--   i_manifest_no  (input)
--     Manifest # to be tripmastered
--   o_returns_err_count  (output) returning count of error in status='ERR'

--
PROCEDURE client_tripmaster (
  piMfNo                IN      manifests.manifest_no%TYPE,
  pszInv                IN      manifest_dtls.obligation_no%TYPE DEFAULT NULL,
  poszMsg               OUT     VARCHAR2,
  poszLMStr     OUT     VARCHAR2,
  poiNumRtns            OUT     NUMBER,
  poiNumCurRtns         OUT     NUMBER,
  poiNumTempRtns        OUT     NUMBER,
  poszRtns              OUT     VARCHAR2,
  poiStatus             OUT     NUMBER,
  piNextRecSet          IN      NUMBER DEFAULT 0,
  piRecTyp      IN  NUMBER DEFAULT 0);

-- =============================================================================
-- Function
--   create_return
--
-- Description
--   The function handles the creation of a new return and its returns related
--   information according to the input data.
--
-- Parameters
--   piInvokeTime (input)
--     Indicate the 1st or subsequent time the function is invoked by the caller
--     in the same session. >= 1. The parameter is used to check on data
--     collection requirement and validity of the data such as catchweight,
--     temperature, etc.. Examples: 1) The C_TEMP_OUT_OF_RANGE return code will
--     only be returned when the piInvokeTime is 1. 2) The C_SHIP_DIFF_UOM
--     return code will only be returned when the piInvokeTime is 1.
--   pRwTypRtn (input)
--     The return information that will be created.
--   pRcTypRtn (output)
--     The return information that have been created. In addition to the
--     original information from pRwTypRtn. The parameter also includes
--     information such as put location, license plate, ti, hi, etc..
--   poiStatus (output)
--     0 - The return information has been created successfully.
--     C_INV_MF - Invalid manifest specified.
--     C_MF_HAS_CLOSED - Manifest has been closed. Action is not allowed.
--     C_INV_RSN - Invalid reason code specified.
--     C_INV_PRODID - Either the invoice item # or the mispick item # is invalid
--     C_QTY_REQUIRED - Updated quantity cannot be <= 0 or none.
--     C_INV_DISP - Invalid disposition code (if available.)
--     C_MSPK_REQUIRED - Mispick reason code is used but no mispick item is
--       specified.
--     C_ITM_NO_SPLIT - Returned invoiced/mispicked item is not splitable but
--       split quantity is returned.
--     C_TEMP_REQUIRED - Invoiced/mispicked item needs temperature.
--     C_TEMP_NO_RANGE - Invoiced/mispicked item doesn't have minimum and/or
--       maximum temperature set up and the item is temperature tracked. The
--       poszMsg output parameter should have the minimum temperature and/or
--       maximum temperature (in that order and each right pack with blanks for
--       up to C_WEIGHT_LEN long each).
--     C_TEMP_OUT_OF_RANGE - Specified temperature is out of range. The
--       poszMsg output parameter should have the minimum temperature and/or
--       maximum temperature (in that order and each right pack with blanks for
--       up to C_WEIGHT_LEN long each).
--     C_NO_MF_INFO - Manifest header/detail info cannot be found.
--     C_SHIP_DIFF_UOM - Returned uom is different from the shipped uom.
--     C_QTY_RTN_GT_SHP - Accumulated returned qty (+ current) will be greater
--       than shipped qty.
--     C_PUT_DONE - The return has been putawayed. Update not allowed.
--     C_INVALID_UOM - No returned uom or not 0 or 1 uom is specified.
--     C_RTN_EXISTS - The return is existed. Cannot create new return.
--     C_QTY_RTN_GT_SHP - Accumulated returned qty (+ current) will be greater
--       than shipped qty.
--     C_UPD_PUTLST_FAIL - Cannot get the return that is created.
--     C_WEIGHT_OUT_OF_RANGE - Specified temperature is out of range. The
--       poszMsg output variable should content the minumum and/or maximum
--       weight for the item. Minium catchweight is listed first (C_WEIGHT_LEN
--       characters long and right pad with blanks) and then maximum catchweight
--     < 0 - Database error.
--   poszMsg (output)
--     Extra error message for certain returned code in poiStatus parameter or
--     NULL. Message examples: 1) Problem occurred during undo or update
--     T-Batch for the return. 2) No location is found for the updated
--     invoiced/mispicked item.
--   poszLMStr (output)
--     A string contends a list of item/cust_pref_vendor/pallet_type changes
--     for new floating slots that are generated for the cycle count locations.
--     The caller must seperate the string into individual records and send
--     them seperately throught the LM APCOM queue to SUS to notify SUS of
--     the pallet type changes. NULL if no pallet type change at all.
--
-- Returns
--   See output parameters above.
--
-- Modification History
-- Date      User   Defect  Comment
--
PROCEDURE create_return (
  piInvokeTime      IN      NUMBER,
  pRwTypRtn     IN      returns%ROWTYPE,
  poRcTypRtn        OUT     recTypRtn,
  poiStatus     OUT     NUMBER,
  poszMsg       OUT     VARCHAR2,
  poszLMStr     OUT     VARCHAR2);

-- =============================================================================
-- Function
--   update_return
--
-- Description
--   The function handles partial or full updates of information of particular
--   return. New license plate will be created if it's successful for those
--   returns that have putaway tasks.
--
-- Parameters
--   piInvokeTime (input)
--     Indicate the 1st or subsequent time the function is invoked by the caller
--     in the same session. >= 1. The parameter is used to check on data
--     collection requirement and validity of the data such as catchweight,
--     temperature, etc.. Examples: 1) The C_TEMP_OUT_OF_RANGE return code will
--     only be returned when the piInvokeTime is 1. 2) The C_SHIP_DIFF_UOM
--     return code will only be returned when the piInvokeTime is 1.
--   pRwTypRtn (input)
--     The return information that will be updated.
--   poRcTypRtn (output)
--     The return information that have been updated. In addition to the
--     original information from pRwTypRtn. The parameter also includes
--     information such as put location, license plate, ti, hi, etc..
--   poszMsg (output)
--     Extra error message for certain returned code in poiStatus parameter or
--     NULL. Message examples: 1) Problem occurred during undo or update
--     T-Batch for the return. 2) No location is found for the updated
--     invoiced/mispicked item. 3) Temperature is out of range 4) Temperature
--     desired 5) Weight is out of range
--   poszLMStr (output)
--     A string contends a list of item/cust_pref_vendor/pallet_type changes
--     for new floating slots that are generated for the cycle count locations.
--     The caller must seperate the string into individual records and send
--     them seperately throught the LM APCOM queue to SUS to notify SUS of
--     the pallet type changes. NULL if no pallet type change at all.
--   poiStatus (output)
--     0 - The return information has been updated successfully.
--     C_INV_MF - Invalid manifest specified.
--     C_MF_HAS_CLOSED - Manifest has been closed. Action is not allowed.
--     C_INV_RSN - Invalid reason code specified.
--     C_INV_PRODID - Either the invoice item # or the mispick item # is invalid
--     C_QTY_REQUIRED - Updated quantity cannot be <= 0 or none.
--     C_INV_DISP - Invalid disposition code (if available.)
--     C_MSPK_REQUIRED - Mispick reason code is used but no mispick item is
--       specified.
--     C_ITM_NO_SPLIT - Returned invoiced/mispicked item is not splitable but
--       split quantity is returned.
--     C_TEMP_REQUIRED - Invoiced/mispicked item needs temperature.
--     C_TEMP_NO_RANGE - Invoiced/mispicked item doesn't have minimum and/or
--       maximum temperature set up and the item is temperature tracked. The
--       poszMsg output parameter should have the minimum temperature and/or
--       maximum temperature (in that order and each right pack with blanks for
--       up to C_WEIGHT_LEN long each).
--     C_TEMP_OUT_OF_RANGE - Invoiced/mispicked item temperature is out of
--       range. The poszMsg output parameter should have the minimum
--       temperature and/or maximum temperature (in that order and each right
--       pack with blanks for up to C_WEIGHT_LEN long each).
--     C_UPD_NOT_ALLOWED - Cannot update to zero quantity if it's not a pickup
--       return.
--     C_NO_MF_INFO - Manifest header/detail info cannot be found.
--     C_SHIP_DIFF_UOM - Returned uom is different from the shipped uom.
--     C_QTY_RTN_GT_SHP - Accumulated returned qty (+ current) will be greater
--       than shipped qty.
--     C_PUT_DONE - The return has been putawayed. Update not allowed.
--     C_WEIGHT_OUT_OF_RANGE - Specified temperature is out of range. The
--       poszMsg output variable should content the minumum and/or maximum
--       weight for the item. Minium catchweight is listed first (C_WEIGHT_LEN
--       characters long and right pad with blanks) and then maximum catchweight
--     < 0 - Database error.
--
-- Returns
--   See output parameters above.
--
-- Modification History
-- Date      User   Defect  Comment
--
PROCEDURE update_return (
  piInvokeTime  IN      NUMBER,
  pRwTypRtn     IN      returns%ROWTYPE,
  poRcTypRtn    OUT     recTypRtn,
  poszMsg       OUT     VARCHAR2,
  poszLMStr OUT     VARCHAR2,
  poiStatus     OUT     NUMBER);

-- =============================================================================
-- Function
--   client_update_return
--
-- Description
--   The function handles partial or full updates of information of particular
--   return. New license plate will be created if it's successful for those
--   returns that have putaway tasks. This function is used by a caller which
--   cannot handle PL/SQL record type as returned parameter. Instead, the
--   PL/SQL record type is converted to a string type. It calls the
--   update_return() procedure.
--
-- Parameters
--   piInvokeTime (input)
--     Indicate the 1st or subsequent time the function is invoked by the caller
--     in the same session. >= 1. The parameter is used to check on data
--     collection requirement and validity of the data such as catchweight,
--     temperature, etc.. Examples: 1) The C_TEMP_OUT_OF_RANGE return code will
--     only be returned when the piInvokeTime is 1. 2) The C_SHIP_DIFF_UOM
--     return code will only be returned when the piInvokeTime is 1.
--   pRwTypRtn (input)
--     The return information that will be updated.
--   poszRtn (output)
--     The return information that have been updated. In addition to the
--     original information from pRwTypRtn. The parameter also includes
--     information such as put location, license plate, ti, hi, etc.. This is
--     a string copy of recTypRtn record type.
--   poszMsg (output)
--     Extra error message for certain returned code in poiStatus parameter or
--     NULL. Message examples: 1) Problem occurred during undo or update
--     T-Batch for the return. 2) No location is found for the updated
--     invoiced/mispicked item.
--   poszLMStr (output)
--     A string contends a list of item/cust_pref_vendor/pallet_type changes
--     for new floating slots that are generated for the cycle count locations.
--     The caller must seperate the string into individual records and send
--     them seperately throught the LM APCOM queue to SUS to notify SUS of
--     the pallet type changes. NULL if no pallet type change at all.
--   poiStatus (output)
--     0 - The return information has been updated successfully.
--     C_INV_MF - Invalid manifest specified.
--     C_MF_HAS_CLOSED - Manifest has been closed. Action is not allowed.
--     C_INV_RSN - Invalid reason code specified.
--     C_INV_PRODID - Either the invoice item # or the mispick item # is invalid
--     C_QTY_REQUIRED - Updated quantity cannot be <= 0 or none.
--     C_INV_DISP - Invalid disposition code (if available.)
--     C_MSPK_REQUIRED - Mispick reason code is used but no mispick item is
--       specified.
--     C_ITM_NO_SPLIT - Returned invoiced/mispicked item is not splitable but
--       split quantity is returned.
--     C_TEMP_REQUIRED - Invoiced/mispicked item needs temperature.
--     C_TEMP_NO_RANGE - Invoiced/mispicked item doesn't have minimum and/or
--       maximum temperature set up and the item is temperature tracked. The
--       poszMsg output parameter should have the minimum temperature and/or
--       maximum temperature (in that order and each right pack with blanks for
--       up to C_WEIGHT_LEN long each).
--     C_TEMP_OUT_OF_RANGE - Invoiced/mispicked item temperature is out of
--       range. The poszMsg output parameter should have the minimum
--       temperature and/or maximum temperature (in that order and each right
--       pack with blanks for up to C_WEIGHT_LEN long each).
--     C_UPD_NOT_ALLOWED - Cannot update to zero quantity if it's not a pickup
--       return.
--     C_NO_MF_INFO - Manifest header/detail info cannot be found.
--     C_SHIP_DIFF_UOM - Returned uom is different from the shipped uom.
--     C_QTY_RTN_GT_SHP - Accumulated returned qty (+ current) will be greater
--       than shipped qty.
--     C_PUT_DONE - The return has been putawayed. Update not allowed.
--     C_WEIGHT_OUT_OF_RANGE - Specified temperature is out of range. The
--       poszMsg output variable should content the minumum and/or maximum
--       weight for the item. Minium catchweight is listed first (C_WEIGHT_LEN
--       characters long and right pad with blanks) and then maximum catchweight
--     < 0 - Database error.
--
-- Returns
--   See output parameters above.
--
-- Modification History
-- Date      User   Defect  Comment
--
PROCEDURE client_update_return (
  piInvokeTime  IN      NUMBER,
  pRwTypRtn     IN      returns%ROWTYPE,
  poszRtn       OUT     VARCHAR2,
  poszMsg       OUT     VARCHAR2,
  poszLMStr OUT     VARCHAR2,
  poiStatus     OUT     NUMBER);

-- =============================================================================
-- Function
--   get_return_info
--
-- Description
--   The function handles the retrieval of all returns information that match
--   the search criteria.
--
-- Parameters
--   pszValue1 (input)
--     License plate/Pallet ID/Invoice # to be searched
--   poiNumRtns (output)
--     # of returns generated for the search criteria; >= 0.
--   poiNumWeightRtns (output)
--     # of returns that need catchweights; <= poiNumRtns but >= 0.
--   poiNumTempRtns (output)
--     # of returns that need temperatures; <= poiNumRtns but >= 0.
--   potabTypRtns (output)
--     Table (array) of returns information back to caller. In addition to
--     regular returns information, each array of records also include
--     information such as location, ti, hi, etc..
--   poiStatus
--     Processing status error code:
--       0 - >= 0 returns information are retrieved and sent back to caller
--       <0 - database error
--   pszValue2 (input)
--     Item # to be searched. Default to NULL.
--   piValue3 (input)
--     Return line # (erm_line_id) to be searched. Default to NULL.
--
-- Returns
--   See output parameters above.
--
-- Assumption
--   The function will return all available returns information. It won't
--   depend on the C_RECS_PER_PAGE limit. The caller must declare big enough
--   storage to hold all the returns.
--
-- Modification History
-- Date      User   Defect  Comment
--
PROCEDURE get_return_info (
  pszValue1             IN      inv.logi_loc%TYPE,
  poiNumRtns            OUT     NUMBER,
  poiNumWeightRtns      OUT     NUMBER,
  poiNumTempRtns        OUT     NUMBER,
  potabTypRtns          OUT     tabTypReturns,
  poiStatus             OUT     NUMBER,
  pszValue2             IN      pm.prod_id%TYPE DEFAULT NULL,
  pszValue3             IN      pm.cust_pref_vendor%TYPE DEFAULT C_DFT_CPV);

-- =============================================================================
-- Function
--   get_client_return_info
--
-- Description
--   The function handles the retrieval of all returns information that match
--   the search criteria through the get_return_info() procedure. This function
--   is used for a caller that cannot handle PL/SQL table returned type.
--
-- Parameters
--   pszValue1 (input)
--     License plate/Pallet ID/Invoice # to be searched
--   poiNumRtns (output)
--     # of returns generated for the search criteria; >= 0.
--   poiNumWeightRtns (output)
--     # of returns that need catchweights; <= poiNumRtns but >= 0.
--   poiNumTempRtns (output)
--     # of returns that need temperatures; <= poiNumRtns but >= 0.
--   poszRtns (output)
--     String of returns information back to caller. In addition to
--     regular returns information, each array of records also include
--     information such as location, ti, hi, etc..
--   poiStatus
--     Processing status error code:
--       0 - >= 0 returns information are retrieved and sent back to caller
--       <0 - database error
--   pszValue2 (input)
--     Item # to be searched. Default to NULL.
--   piValue3 (input)
--     Return line # (erm_line_id) to be searched. Default to NULL.
--
-- Returns
--   See output parameters above.
--
-- Assumption
--   The function will return all available returns information. It won't
--   depend on the C_RECS_PER_PAGE limit. The caller must declare big enough
--   storage to hold all the returns.
--
-- Modification History
-- Date      User   Defect  Comment
--
PROCEDURE get_client_return_info (
  pszValue1             IN      inv.logi_loc%TYPE,
  poiNumRtns            OUT     NUMBER,
  poiNumWeightRtns      OUT     NUMBER,
  poiNumTempRtns        OUT     NUMBER,
  poszRtns      OUT     VARCHAR2,
  poiStatus             OUT     NUMBER,
  pszValue2             IN      pm.prod_id%TYPE DEFAULT NULL,
  pszValue3             IN      pm.cust_pref_vendor%TYPE DEFAULT C_DFT_CPV);

-- =============================================================================
-- Function
--   f_get_rtn_date
--
-- Description
--   Set return date (inv_date, exp_date) to SYSDATE or 01-JAN-2001           
--   depending on the whether the location is induction or not.
--
-- Parameters
--   pDestLoc (input)
--
-- Returns
--   Date in dd-MON-yyyy format
-- 
-- History
--   Date       Name    Desc
--   04/12/06   prphqb  Initial version
--
-- =============================================================================
FUNCTION  f_get_rtn_date (pDestLoc IN VARCHAR2)
RETURN DATE;         

-- =============================================================================
-- Function
--   f_clear_inv
--
-- Description
--   Clear inventory qty_planned according to the location type.
--
-- Parameters
--   psReasonGroup (input)
--     Return reason group
--   rwTypPutlst (input)
--     PUTAWAYLST record information
--
-- Returns
--   0 if everything is ok (inventory qty planned is removed or record
--     is deleted)
--   C_INV_LOC if something is wrong
-- 
-- History
--   Date     Name     Desc
--   08/18/11 jluo5859 Added function to fix inventory clear problem for
--                     slot when the return is removed or updated.
--
-- =============================================================================
FUNCTION f_clear_inv (
  psReasonGroup IN      reason_cds.reason_group%TYPE,
  rwTypPutlst   IN      putawaylst%ROWTYPE)
RETURN NUMBER;

-- =============================================================================
--Procedure: dci_food_safety
--Description: 
--Returns: Error Message
--============================================================================
PROCEDURE dci_food_safety
               (i_ins_del_upd in varchar2,
                i_manifest_no in varchar2,
	        i_stop_no in varchar2,
	        i_prod_id in varchar2,
	        i_obligation_no in varchar2,
	        i_cust_id in manifest_stops.customer_id%TYPE,
                i_temp in number,
                i_source in varchar2,
                i_date in date,
		i_reason_cd in varchar2,
		i_reason_group in varchar2,
                o_msg out varchar);

FUNCTION create_stc_for_pod (
  i_manifest_no           IN  manifests.manifest_no%TYPE
) return rf.status;

END pl_dci;

/


CREATE OR REPLACE PACKAGE BODY      pl_dci AS

-- ***************************** <Package Body> ********************************

-- ********************** <Private Variable Definitions> ***********************

C_MF_CLO_STR        CONSTANT manifests.manifest_status%TYPE := 'CLS';


-- ********************** <Function/Procedure Prototypes> **********************

-- ********************** <Private Functions/Procedures> ***********************

-- =============================================================================
-- Function
--   get_master_item
--
-- Description
--   The function retrieves related information from the Item Master (PM table)
--   and any additional information not related to the PM table. Only parts of
--   the PM information that are relevant to returns processing will be
--   returned.
--
-- Parameters
--   pszCode1 (input)
--     Either the item # or the item's (external) UPC code to be searched
--   pszCode2 (input)
--     Either the cust_pref_vendor value to be searched or no value
--   poiSkidCube (output)
--     Skid cube of the item to be returned. Check from the item's pallet type.
--   poRwTypPm (output)
--     Whole Item Master (PM) row related to the found pszCode1/pszCode2 to be
--     returned or null if no search criteria is found
--   poiStatus
--     Processing status error code:
--       0 - success
--       <0 - database error
--
-- Returns
--   See output parameters above.
--
-- Modification History
-- Date      User   Defect  Comment
--
PROCEDURE get_master_item(
  pszCode1  IN  pm.external_upc%TYPE,
  pszCode2  IN  pm.external_upc%TYPE DEFAULT NULL,
  poiSkidCube   OUT pallet_type.skid_cube%TYPE,
  poRwTypPm OUT pm%ROWTYPE,
  poiStatus OUT NUMBER) IS
  rwTypPm   pm%ROWTYPE := NULL;
  iSkidCube pallet_type.skid_cube%TYPE := NULL;
BEGIN
  poRwTypPm := NULL;
  poiSkidCube := 0;
  poiStatus := C_NORMAL;

  SELECT prod_id, cust_pref_vendor, external_upc, spc,
         NVL(split_trk, 'N'), NVL(temp_trk, 'N'), NVL(catch_wt_trk, 'N'),
         pallet_type, ti, hi, descrip, abc, case_cube, last_ship_slot,
         zone_id, min_temp, max_temp, avg_wt
  INTO rwTypPm.prod_id, rwTypPm.cust_pref_vendor, rwTypPm.external_upc,
       rwTypPm.spc, rwTypPm.split_trk, rwTypPm.temp_trk, rwTypPm.catch_wt_trk,
       rwTypPm.pallet_type, rwTypPm.ti, rwTypPm.hi, rwTypPm.descrip,
       rwTypPm.abc, rwTypPm.case_cube, rwTypPm.last_ship_slot,
       rwTypPm.zone_id, rwTypPm.min_temp, rwTypPm.max_temp, rwTypPm.avg_wt
  FROM pm
  WHERE (((LENGTH(pszCode1) <= C_PROD_ID_LEN) AND
          (prod_id = pszCode1) AND (cust_pref_vendor = pszCode2)) OR
         (((LENGTH(pszCode1) > C_PROD_ID_LEN) AND (external_upc = pszCode1))));

  poRwTypPm := rwTypPm;

  IF rwTypPm.pallet_type IS NOT NULL THEN
    BEGIN
      SELECT skid_cube INTO iSkidCube
      FROM pallet_type
      WHERE pallet_type = rwTypPm.pallet_type;
    EXCEPTION
      WHEN OTHERS THEN
        iSkidCube := 0;
    END;
  END IF;
  poiSkidCube := iSkidCube;
EXCEPTION
  WHEN NO_DATA_FOUND THEN
    poiStatus := C_INV_PRODID;
  WHEN OTHERS THEN
    poiStatus := SQLCODE;
END;
-- -----------------------------------------------------------------------------

-- =============================================================================
-- Function
--   get_loc
--
-- Description
--   The function searches for available location for the input item. If a
--   floating slot other than the last ship slot is found, the item pallet type
--   might be changed. Then the client caller need to refer to the poszLMStr
--   to send the information to SUS.
--
-- Parameters
--   piMfNo (input)
--     Manifest #. Mainly used for notification purpose 
--   pszItem (input)
--     Item # to search the location for
--   pszCpv (input)
--     Cust pref vendor to search the location for
--   piUom (input)
--     Uom to search the location for. This is mainly used if the item has both
--     split and case home slots
--   poszLoc (output)
--     Location to be returned according to the search criteria. The value is
--     '*' if no location is available
--   poiFloatSlot (output)
--     Whether the found location is a floating slot (1) or not (0)
--   poszLMStr (output)
--     A string that consists of the following field values and lengths (in
--     that order) to be sent back to the caller to send the pallet type changes
--     to SUS. NULL if not need to send any data to SUS. Fields and lengths:
--       P<item#-9-chars><cust_pref_vendor-10-chars><pallet_type-2-chars>
--     The string will be repeated with different item #s if more than 1
--     returned item changes their pallet types. It's up to the caller to
--     seperate them and send each to SUS through the LM APCOM queue.
--   poiStatus
--     Processing status error code:
--       0 - success
--       negative - database error
--
-- Returns
--   See output parameters above.
--
-- Modification History
-- Date      User   Defect  Comment
-- 12/16/05  prphqb WAI     Call pl_ml_common to check for induction location
-- 03/10/06  prplhj 12072   Include the search of Miniload slots (rule_id=3)
--              but exclude outbound location
--
PROCEDURE get_loc (
  piMfNo    IN  manifests.manifest_no%TYPE,
  pszItem   IN  pm.prod_id%TYPE,
  pszCpv    IN  pm.cust_pref_vendor%TYPE,
  piUom     IN  returns.returned_split_cd%TYPE,
  poszLoc   OUT loc.logi_loc%TYPE,
  poiFloatSlot  OUT NUMBER,
  poszLMStr OUT VARCHAR2,
  poiStatus OUT NUMBER) IS
  iUOM          uom.uom%TYPE;
  szLoc         putawaylst.dest_loc%TYPE := NULL;
  iExists       NUMBER(1) := 0;
  szZoneID      pm.zone_id%TYPE := NULL;
  szPalType     pm.pallet_type%TYPE := NULL;
  szLastShipSlot    pm.last_ship_slot%TYPE := NULL;
  szSyspar      sys_config.config_flag_val%TYPE := NULL;
  szOldPalType      pm.pallet_type%TYPE := NULL;
  rwTypTrans        trans%ROWTYPE := NULL;
  iPikPath      loc.pik_path%TYPE := NULL;
  iNearPikPath      loc.pik_path%TYPE := NULL;
  rwTypProcessErr   process_error%ROWTYPE := NULL;
  iStatus       NUMBER(4) := C_NORMAL;
  excNoLocFound EXCEPTION;
  CURSOR c_get_home_loc(cpiUom loc.uom%TYPE) IS
    SELECT logi_loc
    FROM loc
    WHERE prod_id = pszItem
    AND   cust_pref_vendor = pszCpv
    AND   NVL(uom, 0) IN (0, 2 - cpiUom)
    AND   perm = 'Y'
    AND   rank = 1;
  CURSOR c_get_inv_locs IS
    SELECT NVL(i.plogi_loc, 'FFFFFF')
    FROM zone z, inv i, lzone lz
    WHERE i.prod_id = pszItem
    AND   i.cust_pref_vendor = pszCpv
    AND   i.status = 'AVL'
    AND   NOT EXISTS (SELECT 'x'
                      FROM loc
                      WHERE prod_id = pszItem
                      AND   cust_pref_vendor = pszCpv)
    AND   z.zone_type = 'PUT'
    AND   z.rule_id = 1
    AND   z.zone_id = lz.zone_id
    AND   lz.logi_loc = i.plogi_loc
    AND   i.qoh + i.qty_planned > 0
    ORDER BY i.exp_date, i.qoh, i.logi_loc;
   CURSOR c_has_diff_item(cpszLoc  loc.logi_loc%TYPE,
                          cpszItem pm.prod_id%TYPE,
                          cpszCpv  pm.cust_pref_vendor%TYPE) IS
     SELECT 1
     FROM inv
     WHERE plogi_loc = cpszLoc
     AND   cust_pref_vendor = cpszCpv
     AND   status = 'AVL'
     AND   prod_id <> cpszItem;
  CURSOR c_get_put_zone(cpiUom NUMBER) IS
    SELECT DECODE(z.rule_id, 1, p.zone_id,
                  DECODE(cpiUom, 1, p.split_zone_id, p.zone_id)) zone_id,
           p.pallet_type, NVL(p.last_ship_slot, 'FFFFFF')
    FROM pallet_type pa, zone z, pm p
    WHERE  p.prod_id = pszItem
    AND    p.cust_pref_vendor = pszCpv
    AND    p.zone_id = z.zone_id
    AND    z.zone_type = 'PUT'
    AND    (((p.miniload_storage_ind = 'N') AND (z.rule_id = 1)) OR
            ((p.miniload_storage_ind = 'B') AND (z.rule_id = 3)) OR
            ((p.miniload_storage_ind = 'S') AND
             (((cpiUom IN (0, 2) AND (z.rule_id = 1))) OR
              ((cpiUom = 1) AND (z.rule_id = 3)))))
    AND    p.pallet_type = pa.pallet_type;
  CURSOR c_get_empty_float_same_paltype
    (cpszZoneID zone.zone_id%TYPE, cpszPalType pm.pallet_type%TYPE) IS
    SELECT l.logi_loc
    FROM loc l, lzone lz
    WHERE lz.zone_id  = cpszZoneID
    AND   lz.logi_loc = l.logi_loc
    AND   l.status = 'AVL'
    AND   l.pallet_type = cpszPalType
    AND   NOT EXISTS (SELECT NULL
                      FROM inv
                      WHERE plogi_loc = l.logi_loc);
  CURSOR c_get_empty_float_diff_paltype (cpszZoneID zone.zone_id%TYPE) IS
    SELECT l.logi_loc, l.pallet_type
    FROM loc l, lzone lz
    WHERE lz.zone_id  = cpszZoneID
    AND   lz.logi_loc = l.logi_loc
    AND   l.status = 'AVL'
    AND   NOT EXISTS (SELECT NULL
                      FROM inv
                      WHERE plogi_loc = l.logi_loc);
  CURSOR c_get_pik_path (cpszSlot VARCHAR2) IS
    SELECT NVL(pik_path, 9999999999)
    FROM loc
    WHERE logi_loc = cpszSlot
    AND   status = 'AVL'
    AND   prod_id IS NULL
    AND   NOT EXISTS (SELECT 'x'
                      FROM inv
                      WHERE plogi_loc = cpszSlot
                      AND   prod_id <> pszItem);
  CURSOR c_get_float_ecube_same_paltyp
    (cpszZoneID VARCHAR2, cp_paltype VARCHAR2,
     cpszSlot VARCHAR2, cpiPikPath NUMBER) IS
    SELECT l.logi_loc, l.pik_path - cpiPikPath
    FROM loc l, lzone lz
    WHERE lz.zone_id  = cpszZoneID
    AND   lz.logi_loc = l.logi_loc
    AND   l.status = 'AVL'
    AND   l.pallet_type = cp_paltype
    AND   l.cube >= (SELECT NVL(cube, 0)
                     FROM loc
                     WHERE  logi_loc = cpszSlot)
    AND   NOT EXISTS (SELECT NULL
                      FROM inv
                      WHERE plogi_loc = l.logi_loc)
    ORDER BY 2;
  CURSOR c_get_empty_float_enough_cube(cpszZoneID zone.zone_id%TYPE,
                                       cpszSlot   loc.logi_loc%TYPE,
                                       cpiPikPath loc.pik_path%TYPE) IS
    SELECT l.logi_loc, l.pallet_type, l.pik_path - cpiPikPath
    FROM loc l, lzone lz
    WHERE lz.zone_id  = cpszZoneID
    AND   lz.logi_loc = l.logi_loc
    AND   l.status = 'AVL'
    AND   l.cube >= (SELECT NVL(cube, 0)
                     FROM loc
                     WHERE  logi_loc = cpszSlot)
    AND   NOT EXISTS (SELECT NULL
                      FROM inv
                      WHERE plogi_loc = l.logi_loc)
    ORDER BY 3;
BEGIN
  poiStatus := C_NORMAL;
  poiFloatSlot := 0;
  poszLMStr := NULL;
  poszLoc := NULL;

  DBMS_OUTPUT.PUT_LINE('Ready to search loc. uom: ' || piUom || ' i: ' ||
    pszItem || '/' || pszCpv); 
--pl_log.ins_msg('I', 'pl_dci', 'Ready to search loc. uom: ' || piUom ||
--  ' i: ' || pszItem || '/' || pszCpv, 0, 0);

  -- First check if item is induction location bound
  IF (piUOM = '1') THEN
    iUOM := 1;
  ELSE
    iUOM := 2;
  END IF;

  ---Matrix Change Start--- 
  IF pl_matrix_common.chk_matrix_enable = TRUE AND iUOM = 2 THEN  
    IF pl_matrix_common.chk_prod_mx_assign (pszItem) = TRUE AND pl_matrix_common.chk_prod_mx_eligible (pszItem) = TRUE THEN    
        poiFloatSlot := 1;
        poszLoc := NVL(pl_matrix_common.f_get_mx_dest_loc(pszItem), '*');         
        RETURN;
    END IF;
  END IF;
  ---Matrix Change End--- 

  pl_ml_common.get_induction_loc(pszItem, pszCpv, iUOM,                        
                                 iStatus, poszLoc);
  IF (iStatus = C_NORMAL) THEN
    poiFloatSlot := 1;
    RETURN;
  END IF;

  -- Search from home slot.
  OPEN c_get_home_loc(piUom);
  FETCH c_get_home_loc INTO szLoc;
  IF c_get_home_loc%FOUND THEN
    CLOSE c_get_home_loc;
    poszLoc := szLoc;
    RETURN;
  END IF;
  CLOSE c_get_home_loc;
  DBMS_OUTPUT.PUT_LINE('Not found home loc'); 
--pl_log.ins_msg('I', 'pl_dci', 'Not found home loc', 0, 0);

  -- Home slot is not found. Search from existing floating slot inventory that
  -- will expire first and has least qoh.
  OPEN c_get_inv_locs;
  FETCH c_get_inv_locs INTO szLoc;
  IF c_get_inv_locs%FOUND THEN
    poiFloatSlot := 1;
    OPEN c_has_diff_item(szLoc, pszItem, pszCpv);
    FETCH c_has_diff_item INTO iExists;
    IF c_has_diff_item%NOTFOUND THEN
      -- Existing same-item floating slot inventory is found
      CLOSE c_has_diff_item;
      CLOSE c_get_inv_locs;
      poszLoc := szLoc;
      RETURN;
    END IF;
    CLOSE c_has_diff_item;
  END IF;
  CLOSE c_get_inv_locs;
  DBMS_OUTPUT.PUT_LINE('Check existing float w/ earliest inv: ' || szLoc);

  -- No home slot and no existing floating slot inventory or the existing
  -- floating slot has different item.
  -- Search from item's floating put zone.
  OPEN c_get_put_zone(iUom);
  FETCH c_get_put_zone INTO szZoneID, szPalType, szLastShipSlot;
  IF c_get_put_zone%NOTFOUND THEN
    -- No previous float zone is found. '*' out the location.
    CLOSE c_get_put_zone;
    poiStatus := C_NOT_FOUND;
    RAISE excNoLocFound;
  END IF;
  CLOSE c_get_put_zone;
  DBMS_OUTPUT.PUT_LINE('Zone: ' || szZoneID || ', pal: ' || szPalType ||
    ', lss: ' || szLastShipSlot);

  -- Previous float zone is found and there is a last ship slot.
  -- Check if the last ship slot already had different item occupied.
  poiFloatSlot := 1;
  IF szLastShipSlot <> 'FFFFFF' THEN
    OPEN c_has_diff_item(szLastShipSlot, pszItem, pszCpv);
    FETCH c_has_diff_item INTO iExists;
    IF c_has_diff_item%FOUND THEN
      -- Different item is in the last ship slot. Need to find a new slot.
      szLastShipSlot := 'FFFFFF';
    END IF;
    CLOSE c_has_diff_item;
  END IF;
  DBMS_OUTPUT.PUT_LINE('Lss found and no other item: ' || szLastShipSlot);

  -- Save the found pallet type to be used to find another floating slot.
  szOldPalType := szPalType;

  -- Float zone is found but there is no last ship slot.
  IF szLastShipSlot = 'FFFFFF' THEN
    OPEN c_get_empty_float_same_paltype(szZoneID, szPalType);
    FETCH c_get_empty_float_same_paltype INTO szLoc;
    IF c_get_empty_float_same_paltype%FOUND THEN
      -- Found an open slot in the same zone with the same pallet type. Update
      -- with the latest found floating slot.
      BEGIN
        UPDATE pm
        SET last_ship_slot = szLoc
        WHERE prod_id = pszItem
        AND   cust_pref_vendor = pszCpv;

      EXCEPTION
        WHEN NO_DATA_FOUND THEN
          NULL;
        WHEN OTHERS THEN
          poiStatus := SQLCODE;
          RAISE excNoLocFound;
      END;
      CLOSE c_get_empty_float_same_paltype;
      poszLoc := szLoc;
      RETURN;
    END IF;
    CLOSE c_get_empty_float_same_paltype;
    DBMS_OUTPUT.PUT_LINE('Empty float same pal: ' || szLoc);

    -- No open floating slot with same pallet type is found. Check open slot
    -- of same zone but different pallet type.
    OPEN c_get_empty_float_diff_paltype(szZoneID);
    FETCH c_get_empty_float_diff_paltype INTO szLoc, szPalType;
    IF c_get_empty_float_diff_paltype%NOTFOUND THEN
      -- No open slot of the same zone but different pallet type is found.
      -- '*' out the location.
      CLOSE c_get_empty_float_diff_paltype;
      poiStatus := C_NOT_FOUND;
      RAISE excNoLocFound;
    END IF;
    CLOSE c_get_empty_float_diff_paltype;
    DBMS_OUTPUT.PUT_LINE('Empty float diff pal: ' || szLoc);

    -- Found an open floating slot of the same zone but different pallet type.
    -- Update with the latest found floating slot and pallet type.
    BEGIN
      UPDATE pm
      SET last_ship_slot = szLoc, pallet_type = szPalType
      WHERE prod_id = pszItem
      AND   cust_pref_vendor = pszCpv;

    EXCEPTION
      WHEN NO_DATA_FOUND THEN
        NULL; 
      WHEN OTHERS THEN
        poiStatus := SQLCODE;
        RAISE excNoLocFound;
    END;

    -- Insert transaction record for last ship date or pallet type changes.
    rwTypTrans := NULL;
    IF NVL(gRcTypSyspar.upd_item_ptype_return, 'N') = 'Y' AND
       NVL(szOldPalType, ' ') <> NVL(szPalType, ' ') THEN
      rwTypTrans.trans_type := 'IMT';
      rwTypTrans.rec_id := TO_CHAR(piMfNo);
      rwTypTrans.user_id := USER;
      rwTypTrans.prod_id := pszItem;
      rwTypTrans.cust_pref_vendor := pszCpv;
      rwTypTrans.dest_loc := szLoc;
      rwTypTrans.cmt := 'RTNRF: Old pallet type: ' ||
                        NVL(szOldPalType, 'NULL') ||
                       ', New pallet type: ' || NVL(szPalType, 'NULL');
      iStatus := pl_common.f_create_trans(rwTypTrans, 'na');
      IF iStatus <> C_NORMAL THEN
        poiStatus := iStatus;
        RAISE excNoLocFound;
      END IF;
      -- The caller should reference this string and send them to SUS through
      -- LM APCOM queue
      poszLMStr := 'P' || RPAD(pszItem, C_PROD_ID_LEN) ||
                   RPAD(pszCpv, C_CPV_LEN) ||
                   RPAD(NVL(szPalType, ' '), C_PALLET_TYPE_LEN);
    END IF;
    DBMS_OUTPUT.PUT_LINE('Created IMT for pal change: ' || szLoc ||
      ', old/new: ' || szOldPalType || '/' || szPalType);

    poszLoc := szLoc;
    RETURN;
  END IF;

  -- Found float zone and last ship slot on 1st try.
  -- Get last ship slot pik path.
  OPEN c_get_pik_path(szLastShipSlot);
  FETCH c_get_pik_path INTO iPikPath;
  IF c_get_pik_path%FOUND THEN
    -- Last ship slot pik path is found. Check if the last ship slot already
    -- had different item occupied.
    BEGIN
      SELECT 1 INTO iExists
      FROM inv
      WHERE plogi_loc = szLastShipSlot
      AND   prod_id <> pszItem;

      -- Last ship slot has only 1 and different item occupied.
      -- Need to find another empty slot.

    EXCEPTION
      WHEN NO_DATA_FOUND THEN
        -- Either last ship slot has no inventory or the same item is in
        -- the slot. Use the slot.
        CLOSE c_get_pik_path;        
        poszLoc := szLastShipSlot;
        RETURN;
      WHEN TOO_MANY_ROWS THEN
        -- More than 1 different items found in the last ship slot. Need to
        -- find another empty slot.
        NULL;
      WHEN OTHERS THEN
        poiStatus := SQLCODE;
        CLOSE c_get_pik_path;
        RAISE excNoLocFound;
    END;
  END IF;
  CLOSE c_get_pik_path;
  DBMS_OUTPUT.PUT_LINE('Pikpath: ' || TO_CHAR(iPikPath));

  -- Last ship slot has different item occupied. Need to find another open
  -- slot which is closest to the last ship slot and with the same zone and
  -- same pallet type.
  OPEN c_get_float_ecube_same_paltyp(szZoneID, szPalType,
                                     szLastShipSlot, iPikPath);
  FETCH c_get_float_ecube_same_paltyp INTO szLoc, iNearPikPath;
  IF c_get_float_ecube_same_paltyp%FOUND THEN
    -- Found the slot.
    CLOSE c_get_float_ecube_same_paltyp;
    poszLoc := szLoc;
    RETURN;
  END IF;
  CLOSE c_get_float_ecube_same_paltyp;
  DBMS_OUTPUT.PUT_LINE('Diff float w/ same zone+pal: ' || szLoc || ' path: ' ||
    TO_CHAR(iNearPikPath));

  -- Still cannot find an open slot that has the same zone and pallet type
  -- and user doesn't want to update the pallet type. '*' out the location.
  IF NVL(szSyspar, 'N') <> 'Y' THEN
    poiStatus := C_NOT_FOUND;
    RAISE excNoLocFound;
  END IF;

  -- User wants to continue. Search for an open floating slot that has
  -- enough cube.
  OPEN c_get_empty_float_enough_cube(szZoneID, szLastShipSlot, iPikPath);
  FETCH c_get_empty_float_enough_cube INTO szLoc, szPalType, iNearPikPath;
  IF c_get_empty_float_enough_cube%NOTFOUND THEN
    -- Not found any. '*' out the location.
    CLOSE c_get_empty_float_enough_cube;
    poiStatus := C_NOT_FOUND;
    RAISE excNoLocFound;
  END IF;
  CLOSE c_get_empty_float_enough_cube;
  DBMS_OUTPUT.PUT_LINE('Float w/ fit cube: ' || szLoc || ' pal: ' ||
    szPalType || ' path: ' || TO_CHAR(iNearPikPath));

  -- Found an open slot that has enough cube. Update latest info
  BEGIN
    UPDATE pm
    SET last_ship_slot = szLoc, pallet_type = szPalType
    WHERE prod_id = pszItem
    AND   cust_pref_vendor = pszCpv;

  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      NULL; 
    WHEN OTHERS THEN
      poiStatus := SQLCODE;
      RAISE excNoLocFound;
  END;
  -- Add a transaction record for slot and pallet type changes.
  rwTypTrans := NULL;
  IF NVL(gRcTypSyspar.upd_item_ptype_return, 'N') = 'Y' AND
     NVL(szOldPalType, ' ') <> NVL(szPalType, ' ') THEN
    rwTypTrans.trans_type := 'IMT';
    rwTypTrans.rec_id := TO_CHAR(piMfNo);
    rwTypTrans.user_id := USER;
    rwTypTrans.prod_id := pszItem;
    rwTypTrans.cust_pref_vendor := pszCpv;
    rwTypTrans.dest_loc := szLoc;
    rwTypTrans.cmt := 'RTNRF: Old pallet type: ' ||
                      NVL(szOldPalType, 'NULL') ||
                     ', New pallet type: ' || NVL(szPalType, 'NULL');
    iStatus := pl_common.f_create_trans(rwTypTrans, 'na');
    IF iStatus <> C_NORMAL THEN
      poiStatus := iStatus;
      RAISE excNoLocFound;
    END IF;

    -- The caller should reference this string and send them to SUS through
    -- LM APCOM queue
    poszLMStr := 'P' || RPAD(pszItem, C_PROD_ID_LEN) ||
                 RPAD(pszCpv, C_CPV_LEN) ||
                 RPAD(NVL(szPalType, ' '), C_PALLET_TYPE_LEN);
  END IF;

  poszLoc := szLoc;

EXCEPTION
  WHEN excNoLocFound THEN
    DBMS_OUTPUT.PUT_LINE('Loc need to be * out');
    poszLoc := '*';
    poiFloatSlot := 0;
  WHEN OTHERS THEN
    poiStatus := SQLCODE;
    poszLoc := '*';
    poiFloatSlot := 0;
END;
-- -----------------------------------------------------------------------------

-- =============================================================================
-- Function
--   get_orig_invoice
--
-- Description
--   The function retrieves original invoice # from the search criteria. The
--   found invoice # will be stripped off the 'L' part if the return is an
--   order deleted.
--
-- Parameters
--   pRwTypRtn (input)
--     Return information to be searched
--
-- Returns
--   An original invoice # or NULL
--
-- Modification History
-- Date      User   Defect  Comment
--
FUNCTION get_orig_invoice (
  pRwTypRtn     IN  returns%ROWTYPE)
RETURN VARCHAR2 IS
  szOrigInv     manifest_dtls.orig_invoice%TYPE := NULL;
  szUom         returns.returned_split_cd%TYPE := NULL;
  CURSOR c_get_orig_inv (cpszUom returns.returned_split_cd%TYPE) IS
    SELECT DECODE(rec_type,
                  'D', SUBSTR(orig_invoice, 1, INSTR(orig_invoice, 'L') - 1),
                  orig_invoice)
    FROM manifest_dtls
    WHERE manifest_no = pRwTypRtn.manifest_no
    AND   DECODE(INSTR(obligation_no, 'L'), 0, obligation_no,
                 SUBSTR(obligation_no, 1, INSTR(obligation_no, 'L') - 1)) =
          pRwTypRtn.obligation_no
    AND   prod_id = pRwTypRtn.prod_id
    AND   cust_pref_vendor = pRwTypRtn.cust_pref_vendor
    AND   (cpszUom IS NULL OR shipped_split_cd = cpszUom);
BEGIN
  OPEN c_get_orig_inv(pRwTypRtn.returned_split_cd);
  FETCH c_get_orig_inv INTO szOrigInv;
  IF c_get_orig_inv%NOTFOUND THEN
    -- The current returned uom is not found. Try again to use the
    -- opposite uom.
    IF pRwTypRtn.returned_split_cd = '0' THEN
      szUom := '1';
    ELSE
      szUom := '0';
    END IF;
    CLOSE c_get_orig_inv;
    OPEN c_get_orig_inv(szUom);
    FETCH c_get_orig_inv INTO szOrigInv;
    IF c_get_orig_inv%NOTFOUND THEN
      IF pRwTypRtn.rec_type <> 'P' THEN
         szOrigInv := pRwTypRtn.obligation_no;
      ELSE
         szOrigInv := NULL;
      END IF;
    ELSE
      IF szOrigInv IS NULL THEN
        IF pRwTypRtn.rec_type <> 'P' THEN
          szOrigInv := pRwTypRtn.obligation_no;
        END IF;
      END IF;
    END IF;
  ELSE
    IF szOrigInv IS NULL THEN
      IF pRwTypRtn.rec_type <> 'P' THEN
        -- If no orig_invoice on pickup, don't put it
        szOrigInv := pRwTypRtn.obligation_no;
       END IF;
    END IF;
  END IF;
  CLOSE c_get_orig_inv;

  RETURN szOrigInv;
END;
-- -----------------------------------------------------------------------------

-- =============================================================================
-- Function
--   check_basic_rtn_info
--
-- Description
--   The function does basic checking on the returns information. Checking
--   includes but not limited to: 1) The manifest that corresponding to the
--   return is closed or not. 2) The returned invoiced/mispicked item is valid
--   or not. 3) The returned reason code is valid or not. 4) Retured qty must
--   be provided or cannot be negative. 5) Disposition code, if entered, is
--   valid or not. 6) If it's a mispick reason code, the mispicked item must
--   be provided. 7) Cannot return splits for non-splitable item if the returned
--   reason is not damage. 8) The returned item needs to have a temperature,
--   temperature range is not set for the item, or temperature is out of range
--   for the returned item.
--
-- Parameters
--   pRwTypRtn (input)
--     The return information that will be checked.
--   poiStatus (output)
--     0 - Major checking produces no error
--     C_INV_MF - Invalid manifest specified.
--     C_MF_HAS_CLOSED - Manifest for the return has been closed
--     C_INV_PRODID - Either the invoice item # or the mispick item # is invalid
--     C_INV_RSN - Invalid reason code specified.
--     C_QTY_REQUIRED - Returned qty is required
--     C_INV_DISP - Invalid disposition code (if available.)
--     C_MSPK_REQUIRED - Mispicked item is required
--     C_ITM_NOT_SPLIT - Returned invoiced/mispicked item is not splitable but
--       split quantity is returned.
--     C_TEMP_REQUIRED - Invoiced/mispicked item needs temperature. The
--       poiMinVal and/or poiMaxVal will be set according to the value from PM
--       table.
--     C_TEMP_OUT_OF_RANGE - Specified temperature is out of range. The
--       poiMinVal and/or poiMaxVal will be set according to the value from PM
--       table.
--     C_TEMP_NO_RANGE - Specified temperature is out of range. The
--       poiMinVal and/or poiMaxVal will be set according to the value from PM
--       table.
--     <0 - Database error occurred
--   poiMinVal (output)
--     Minimum temperature/catchweight for the returned item. NULL if item is
--     not temperature/catchweight tracked.
--   poiMaxVal (output)
--     Maximum temperature/catchweight for the returned item. NULL if item is
--     not temperature/catchweight tracked.
--
-- Returns
--   See output parameters above for details.
--
-- Modification History
-- Date      User   Defect  Comment
--
PROCEDURE check_basic_rtn_info (
  pRwTypRtn     IN  returns%ROWTYPE,
  poiStatus     OUT NUMBER,
  poiMinVal     OUT NUMBER,
  poiMaxVal     OUT NUMBER) IS
  szRoute       manifests.route_no%TYPE := NULL;
  szMfStatus        VARCHAR2(10) := NULL;
  iSkidCube     NUMBER := NULL;
  rwTypPm1      pm%ROWTYPE := NULL;
  rwTypPm2      pm%ROWTYPE := NULL;
  iStatus       NUMBER := C_NORMAL;
  tabTypRsn1        tabTypReasons;
  tabTypRsn2        tabTypReasons;
BEGIN
  poiStatus := C_NORMAL;
  poiMinVal := NULL;
  poiMaxVal := NULL;

  -- Check manifest status
  get_mf_status(pRwTypRtn.manifest_no, szRoute, szMfStatus);
  DBMS_OUTPUT.PUT_LINE('Chk basic mf status: ' || szMfStatus);
  IF CHR(ASCII(SUBSTR(szMfStatus,1,1))) NOT BETWEEN 'A' AND 'Z' THEN
    -- It's a positive user error code or Oracle negative error code
    poiStatus := TO_NUMBER(szMfStatus);
    RETURN;
  ELSE
    IF szMfStatus = C_MF_CLO_STR THEN
      poiStatus := C_MF_HAS_CLOSED;
      RETURN;
    END IF;
  END IF;

  -- Check if invoice item is valid
  get_master_item(pRwTypRtn.prod_id, pRwTypRtn.cust_pref_vendor,
                  iSkidCube, rwTypPm1, iStatus);
  DBMS_OUTPUT.PUT_LINE('Chk basic invoice item ' || pRwTypRtn.prod_id ||
    '/' || pRwtypRtn.cust_pref_vendor || ' s: ' || TO_CHAR(iStatus));
  IF iStatus <> C_NORMAL THEN
    poiStatus := iStatus;
    RETURN;
  END IF;

  -- Check if returned reason code is valid
  tabTypRsn1 := get_reason_info('ALL', 'ALL', pRwTypRtn.return_reason_cd);
  DBMS_OUTPUT.PUT_LINE('Chk basic rsn ' || pRwTypRtn.return_reason_cd ||
    ' cnt: ' || TO_CHAR(tabTypRsn1.COUNT) || ' q: ' ||
    TO_CHAR(pRwTypRtn.returned_qty));
  IF tabTypRsn1.COUNT = 0 THEN
    poiStatus := C_INV_RSN;
    RETURN;
  END IF;

  -- Check negative qty
  IF pRwTypRtn.returned_qty IS NULL OR NVL(pRwTypRtn.returned_qty, 0) < 0 THEN
    poiStatus := C_QTY_REQUIRED;
    RETURN;
  END IF;

  -- Check if returned disposition code is valid
  IF pRwTypRtn.disposition IS NOT NULL THEN
    tabTypRsn2 := get_reason_info('DIS', 'ALL', pRwTypRtn.disposition);
    DBMS_OUTPUT.PUT_LINE('Chk basic dis rsn ' || pRwTypRtn.disposition ||
      ' cnt: ' || TO_CHAR(tabTypRsn2.COUNT) || ' mis p: ' ||
      pRwTypRtn.returned_prod_id);
    IF tabTypRsn2.COUNT = 0 THEN
      poiStatus := C_INV_DISP;
      RETURN;
    END IF;
  END IF;

  -- Need mispick item if it's mispick reason
  IF tabTypRsn1(1).reason_group IN ('MPR', 'MPK') AND
     pRwTypRtn.returned_prod_id IS NULL THEN
    poiStatus := C_MSPK_REQUIRED;
    RETURN;
  END IF;

  -- Check if available mispicked item is valid
  IF pRwTypRtn.returned_prod_id IS NOT NULL THEN
    get_master_item(pRwTypRtn.returned_prod_id, pRwTypRtn.cust_pref_vendor,
                    iSkidCube, rwTypPm2, iStatus);
    IF iStatus <> C_NORMAL THEN
      poiStatus := iStatus;
      RETURN;
    END IF;
  ELSE
    rwTypPm2 := rwTypPm1;
  END IF;

  -- Cannot return splits of nonsplitable item unless it's a damage reason
  IF tabTypRsn1(1).reason_group NOT IN ('MPR', 'MPK') THEN
    IF rwTypPm1.split_trk = 'N' AND
       tabTypRsn1(1).reason_group <> 'DMG' AND
       pRwTypRtn.returned_split_cd = '1' THEN
      poiStatus := C_ITM_NOT_SPLIT;
      RETURN;
    END IF;
  ELSE
    IF rwTypPm2.split_trk = 'N' AND
       tabTypRsn1(1).reason_group <> 'DMG' AND
       pRwTypRtn.returned_split_cd = '1' THEN
      poiStatus := C_ITM_NOT_SPLIT;
      RETURN;
    END IF;
  END IF;

  -- Check temperature range if available
  IF NOT (rwTypPm2.prod_id IS NULL) THEN
    IF rwTypPm2.temp_trk = 'Y' THEN
      IF rwTypPm2.min_temp IS NULL OR
         rwTypPm2.max_temp IS NULL OR
         ((NVL(rwTypPm2.min_temp, 0) = 0) AND (NVL(rwTypPm2.max_temp, 0) = 0))
      THEN
        poiStatus := C_TEMP_NO_RANGE;
        poiMinVal := rwTypPm2.min_temp;
        poiMaxVal := rwTypPm2.max_temp;
        RETURN;
      END IF;
      IF pRwTypRtn.temperature IS NOT NULL THEN
        IF pRwTypRtn.temperature < rwTypPm2.min_temp OR
           pRwTypRtn.temperature > rwTypPm2.max_temp THEN
          poiStatus := C_TEMP_OUT_OF_RANGE;
          poiMinVal := rwTypPm2.min_temp;
          poiMaxVal := rwTypPm2.max_temp;
          RETURN;
        END IF;
      ELSE
        poiStatus := C_TEMP_REQUIRED;
        poiMinVal := rwTypPm2.min_temp;
        poiMaxVal := rwTypPm2.max_temp;
        RETURN;
      END IF;
    END IF;
  END IF;
  poiStatus := C_NORMAL;
EXCEPTION
  WHEN OTHERS THEN
    poiStatus := SQLCODE;
END;
-- -----------------------------------------------------------------------------

-- =============================================================================
-- Function
--   create_erm
--
-- Description
--   Create returned PO header (ERM) record for the input return information.
--
-- Parameters
--   piMfNo (input)
--     Manifest # to be used to create the header
--   pszRsnGroup (input)
--     Reason group to be used to create the header
--
-- Returns
--   0 - The creation of the ERM record is successful or no creation is needed
--   <0 - Database error occurred
--
-- Modification History
-- Date      User   Defect  Comment
--
FUNCTION create_erm (
  piMfNo    IN  manifests.manifest_no%TYPE,
  pszRsnGroup   IN  reason_cds.reason_group%TYPE)
RETURN NUMBER IS
  iExists   NUMBER := 0;
BEGIN
  -- Don't need ERM for these reason groups
  IF pszRsnGroup IN ('STM', 'MPK') THEN
    RETURN C_NORMAL;
  END IF;

  -- Don't create again if ERM already existed
  BEGIN
    SELECT 1 INTO iExists
    FROM erm
    WHERE (((pszRsnGroup = 'DMG') AND (erm_id = 'D' || TO_CHAR(piMfNo))) OR
           ((pszRsnGroup <> 'DMG') AND (erm_id = 'S' || TO_CHAR(piMfNo))));

    -- Found the returned PO header. Don't create again
    RETURN C_NORMAL;
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      NULL;
    WHEN OTHERS THEN
      RETURN SQLCODE;
  END;

  INSERT INTO erm (
    erm_id, erm_type,
    sched_date, exp_arriv_date, rec_date, status)
    VALUES (
     DECODE(pszRsnGroup, 'DMG', 'D', 'S') || TO_CHAR(piMfNo), 'CM',
     SYSDATE, SYSDATE, SYSDATE, 'OPN');

  RETURN C_NORMAL;
EXCEPTION
  WHEN OTHERS THEN
    RETURN SQLCODE;
END;
-- -----------------------------------------------------------------------------

-- =============================================================================
-- Function
--   delete_erm
--
-- Description
--   Delete returned PO header (ERM) record for the input return information.
--
-- Parameters
--   piMfNo (input)
--     Manifest # to be used to delete the header
--   pszRsnGroup (input)
--     Reason group to be used to delete the header
--
-- Returns
--   0 - The deletion of the ERM record is successful or no action is needed
--   <0 - Database error occurred
--
-- Modification History
-- Date      User   Defect  Comment
--
FUNCTION delete_erm (
  piMfNo    IN  manifests.manifest_no%TYPE,
  pszRsnGroup   IN  reason_cds.reason_group%TYPE)
RETURN NUMBER IS
BEGIN
  DELETE erm
    WHERE erm_id = DECODE(pszRsnGroup, 'DMG', 'D', 'S') || TO_CHAR(piMfNo)
    AND   NOT EXISTS (SELECT 1
                      FROM erd
                      WHERE erm_id = DECODE(pszRsnGroup, 'DMG', 'D', 'S') ||
                                     TO_CHAR(piMfNo));
  RETURN C_NORMAL;
EXCEPTION
  WHEN NO_DATA_FOUND THEN
    RETURN C_NORMAL;
  WHEN OTHERS THEN
    RETURN SQLCODE;
END;
-- -----------------------------------------------------------------------------

-- =============================================================================
-- Function
--   create_erd
--
-- Description
--   Create returned PO detail (ERD) record for the input return information.
--
-- Parameters
--   pszRsnGroup (input)
--     Reason group to be used to create the detail
--   pRwTypRtn (input)
--     Return information to be used to create the detail
--
-- Returns
--   0 - The creation of the ERD record is successful or no creation is needed
--   C_INV_PRODID - Either the invoice item # or the mispick item # is invalid
--   <0 - Database error occurred
--
-- Modification History
-- Date      User   Defect  Comment
--
FUNCTION create_erd (
  pszRsnGroup       IN  reason_cds.reason_group%TYPE,
  pRwTypRtn     IN  returns%ROWTYPE)
RETURN NUMBER IS
  iExists       NUMBER := 0;
  iSkidCube     NUMBER := NULL;
  rwTypPm       pm%ROWTYPE := NULL;
  iStatus       NUMBER := C_NORMAL;
  iQty          NUMBER := 0;
BEGIN
  -- Don't need ERD for these reason groups or returned qty is 0
  IF pszRsnGroup IN ('STM', 'MPK') OR NVL(pRwTypRtn.returned_qty, 0) = 0 THEN
    RETURN C_NORMAL;
  END IF;

  -- Retrieve item master information
  get_master_item(NVL(pRwTypRtn.returned_prod_id, pRwTypRtn.prod_id),
                  pRwTypRtn.cust_pref_vendor,
                  iSkidCube, rwTypPm, iStatus);
  IF iStatus <> C_NORMAL THEN
    RETURN iStatus;
  END IF;

  -- Calculate returned split qty
  BEGIN
    SELECT DECODE(pRwTypRtn.returned_split_cd, '1', 1, rwTypPm.spc) *
           pRwTypRtn.returned_qty INTO iQty
    FROM DUAL;
  EXCEPTION
    WHEN OTHERS THEN
      RETURN SQLCODE;
  END;

  INSERT INTO erd
    (erm_id, erm_line_id, saleable, mispick, prod_id, cust_pref_vendor,
     qty, qty_rec, uom, uom_rec,
     weight, temp, order_id, status, reason_code)
    VALUES (
     DECODE(pszRsnGroup, 'DMG', 'D', 'S') || TO_CHAR(pRwTypRtn.manifest_no),
     pRwTypRtn.erm_line_id,
     DECODE(pszRsnGroup, 'DMG', 'N', 'Y'), 
     DECODE(pszRsnGroup, 'MPR', 'Y', 'MPK', 'Y', 'N'), 
     NVL(pRwTypRtn.returned_prod_id, pRwTypRtn.prod_id),
     pRwTypRtn.cust_pref_vendor,
     iQty, iQty,
     TO_NUMBER(pRwTypRtn.returned_split_cd),
     TO_NUMBER(pRwTypRtn.returned_split_cd),
     pRwTypRtn.catchweight, pRwTypRtn.temperature,
     pRwTypRtn.obligation_no, 'OPN', pRwTypRtn.return_reason_cd);
  RETURN C_NORMAL;
EXCEPTION
  WHEN DUP_VAL_ON_INDEX THEN
    RETURN C_NORMAL;
  WHEN OTHERS THEN
    RETURN SQLCODE;
END;
-- -----------------------------------------------------------------------------

-- =============================================================================
-- Function
--   delete_erd
--
-- Description
--   Delete returned PO detail (ERD) record for the input return information.
--
-- Parameters
--   piMfNo (input)
--     Manifest # to be used to delete the detail
--   pszRsnGroup (input)
--     Reason group to be used to delete the detail
--   piLine (input)
--     Returned PO detail line # to be deleted
--
-- Returns
--   0 - The deletion of the ERD record is successful or no action is needed
--   <0 - Database error occurred
--
-- Modification History
-- Date      User   Defect  Comment
--
FUNCTION delete_erd (
  piMfNo    IN  manifests.manifest_no%TYPE,
  pszRsnGroup   IN  reason_cds.reason_group%TYPE,
  piLine    IN  erd.erm_line_id%TYPE)
RETURN NUMBER IS
  iExists   NUMBER := 0;
BEGIN
  DELETE erd
    WHERE erm_id = DECODE(pszRsnGroup, 'DMG', 'D', 'S') || TO_CHAR(piMfNo)
    AND   erm_line_id = piLine;
  RETURN C_NORMAL;
EXCEPTION
  WHEN NO_DATA_FOUND THEN
    RETURN C_NORMAL;
  WHEN OTHERS THEN
    RETURN SQLCODE;
END;
-- -----------------------------------------------------------------------------

-- =============================================================================
-- Function
--   create_puttask
--
-- Description
--   Create the putaway task according to input criteria.
--
-- Parameters
--   piMfNo (input)
--     Manifest # to be used to create the putaway task
--   pszRsnGroup (input)
--     Reason group to be used to create the putaway task
--   pRwTypRtn (input)
--     The return information that are used to create the putaway task
--   pRwTypPutlst (output)
--     The PUTAWAYLST table record that has been created
--   poszMsg (output)
--     Message to be returned to caller for certain returned code. Example
--     messages:
--       * No location is found for item
--       * Duplicate LP exists for putaway task
--   poszLMStr (output)
--     A string contains pallet type change information for returned item so
--     caller can send the information to SUS via the LM APCOM queue. NULL if
--     no pallet type has been changed.
--   poiStatus (output)
--     0 - The putaway task has been created successfully.
--     C_ALRDY_EXIST - The putaway task has been created before
--     C_NO_LOC - Cannot find location for item
--     C_INV_PRODID - Returned item is invalid
--     <0 - Database error.
--
-- Returns
--   See output parameters above.
--
-- Modification History
-- Date      User   Defect  Comment
--
PROCEDURE create_puttask (
  piMfNo    IN  manifests.manifest_no%TYPE,
  pszRsnGroup   IN  reason_cds.reason_group%TYPE,
  pRwTypRtn IN  returns%ROWTYPE,
  pRwTypPutlst  OUT putawaylst%ROWTYPE,
  poszMsg   IN OUT  VARCHAR2,
  poszLMStr IN OUT  VARCHAR2,
  poiStatus OUT NUMBER) IS
  szLoc     loc.logi_loc%TYPE := NULL;
  iFloatSlot    NUMBER := 0;
  iStatus   NUMBER := C_NORMAL;
  iSkidCube pallet_type.skid_cube%TYPE := NULL;
  rwTypPm   pm%ROWTYPE := NULL;
  szPalletID    inv.logi_loc%TYPE := NULL;
  iQty      NUMBER := 0;
  szOrigInv manifest_dtls.orig_invoice%TYPE := NULL;
  rwTypPutlst   putawaylst%ROWTYPE := NULL;
  iNumTBatches  NUMBER := 0;
  tbTBatches    pl_rtn_lm.ttabBatches;
  szMsg     VARCHAR2(300) := NULL;
  iTemp     returns.temperature%TYPE := NULL;
BEGIN
  poiStatus := C_NORMAL;
  pRwTypPutlst := NULL;
  poszMsg := NULL;
  poszLMStr := NULL;

  -- Don't need putaway task for these reason groups or no returned qty
  IF pszRsnGroup IN ('MPK', 'STM') OR NVL(pRwTypRtn.returned_qty, 0) <= 0 THEN
    RETURN;
  END IF;

  -- Check if the putaway task exists. If it exists, something is wrong
  rwTypPutlst := check_putaway(pszRsnGroup, pRwTypRtn);
  DBMS_OUTPUT.PUT_LINE('Chk put: ' || rwTypPutlst.putaway_put || ' status ' ||
    TO_CHAR(rwTypPutlst.putpath));
--pl_log.ins_msg('I', 'pl_dci', 'Chk put: ' || rwTypPutlst.putaway_put ||
--  ' status ' || TO_CHAR(rwTypPutlst.putpath), 0, 0);
  IF rwTypPutlst.putaway_put <> 'X' THEN
    poiStatus := C_ALRDY_EXIST;
    RETURN;
  END IF;

  -- Retrieve a valid location
  IF pszRsnGroup = 'DMG' THEN
    szLoc := 'DDDDDD';
  ELSE
    get_loc(pRwTypRtn.manifest_no,
            NVL(pRwTypRtn.returned_prod_id, pRwTypRtn.prod_id),
            pRwTypRtn.cust_pref_vendor,
            pRwTypRtn.returned_split_cd, szLoc, iFloatSlot, poszLMStr, iStatus);
    DBMS_OUTPUT.PUT_LINE('Get loc status ' || TO_CHAR(iStatus) || ' loc ' ||
      szLoc || ' float?' || TO_CHAR(iFloatSlot));
--  pl_log.ins_msg('I', 'pl_dci', 'Get loc status ' || TO_CHAR(iStatus) ||
--    ' loc ' || szLoc || ' float?' || TO_CHAR(iFloatSlot), 0, 0);
    IF iStatus <> C_NORMAL OR szLoc IS NULL OR szLoc = '*' THEN
      poiStatus := C_NO_LOC;
      poszMsg := 'Invoice ' || NVL(pRwTypRtn.obligation_no, '<NULL>') ||
                 ' item ' || pRwTypRtn.returned_prod_id || '/' ||
                 pRwTypRtn.cust_pref_vendor || ' has no location';
      RETURN;
    END IF; 
  END IF;
  DBMS_OUTPUT.PUT_LINE('Get loc: ' || szLoc || ' float? ' ||
    TO_CHAR(iFloatSlot));
--pl_log.ins_msg('I', 'pl_dci', 
--  'Get loc: ' || szLoc || ' float? ' || TO_CHAR(iFloatSlot) , 0, 0);

  -- Get item information
  get_master_item(NVL(pRwTypRtn.returned_prod_id, pRwTypRtn.prod_id),
                  pRwTypRtn.cust_pref_vendor, iSkidCube, rwTypPm, iStatus);
  DBMS_OUTPUT.PUT_LINE('Get item status: ' || TO_CHAR(iStatus) || ' item: ' ||
    pRwTypRtn.prod_id || '/' || pRwTypRtn.returned_prod_id);
--pl_log.ins_msg('I', 'pl_dci', 
--  'Get item status: ' || TO_CHAR(iStatus) || ' item: ' ||
--  pRwTypRtn.prod_id || '/' || pRwTypRtn.returned_prod_id, 0, 0);
  IF iStatus <> C_NORMAL THEN
    poiStatus := iStatus;
    RETURN;
  END IF;

  -- Calculate returned split qty
  BEGIN
    SELECT DECODE(pRwTypRtn.returned_split_cd, '1', 1, rwTypPm.spc) *
           pRwTypRtn.returned_qty
    INTO iQty
    FROM DUAL;
  EXCEPTION
    WHEN OTHERS THEN
      iQty := 0;
  END;
  DBMS_OUTPUT.PUT_LINE('Rtn qty: ' || TO_CHAR(pRwTypRtn.returned_qty) || '/' ||
    pRwTypRtn.returned_split_cd || '/' || TO_CHAR(rwTypPm.spc) ||
    ', q:' || TO_CHAR(iQty));

  -- Retrieve original invoice if available
  szOrigInv := get_orig_invoice(pRwTypRtn);
  DBMS_OUTPUT.PUT_LINE('Orig inv: ' || szOrigInv);

  -- Get next pallet ID
  BEGIN
    SELECT pallet_id_seq.nextval INTO szPalletID FROM DUAL;
  EXCEPTION
    WHEN OTHERS THEN
      poiStatus := iStatus;
      RETURN;
  END;
  DBMS_OUTPUT.PUT_LINE('Next pallet: ' || szPalletID);
  DBMS_OUTPUT.PUT_LINE('Item ' || pRwTypRtn.prod_id || '/' ||
    pRwTypRtn.returned_prod_id || ' rtn weight ' || rwTypPm.catch_wt_trk ||
    '/' || TO_CHAR(pRwTypRtn.catchweight) || ' temp ' || rwTypPm.temp_trk ||
    '/' || TO_CHAR(pRwTypRtn.temperature));

  IF pszRsnGroup IN ('NOR', 'WIN') THEN
    -- Return qty to inventory only for these reason groups
    IF NVL(iSkidCube, 0) = 0 THEN
      -- Try to get skid_cube from location if item doesn't have
      BEGIN
        SELECT pa.skid_cube INTO iSkidCube
        FROM loc l, pallet_type pa
        WHERE l.logi_loc = szLoc
        AND   l.pallet_type = pa.pallet_type;
      EXCEPTION
        WHEN OTHERS THEN
          iSkidCube := 0;
      END;
    END IF;
    IF iFloatSlot = 1 THEN
      -- Found floating slot. Create the inventory 
      BEGIN
        INSERT INTO inv
          (prod_id, cust_pref_vendor,
           rec_id, 
       inv_date, 
       exp_date,
       rec_date, 
       lst_cycle_date, 
       abc_gen_date, 
           plogi_loc, logi_loc,
           qoh, qty_alloc, qty_planned, min_qty,
           cube, abc, status, weight, temperature, inv_uom)
          VALUES (
           pRwTypRtn.returned_prod_id, pRwTypRtn.cust_pref_vendor,
           'S' || TO_CHAR(piMfNo), 
       f_get_rtn_date(szLoc),
       f_get_rtn_date(szLoc),
       SYSDATE, 
       SYSDATE,
           SYSDATE, 
       szLoc, szPalletID,
           0, 0, iQty, 0,
           (iQty / rwTypPm.spc) * rwTypPm.case_cube + iSkidCube,
           rwTypPm.abc, 'AVL', pRwTypRtn.catchweight, pRwTypRtn.temperature,
           TO_NUMBER(pRwTypRtn.returned_split_cd));
        DBMS_OUTPUT.PUT_LINE('Add inv ok: ' || szLoc || '/' || szPalletID);
      EXCEPTION
        WHEN DUP_VAL_ON_INDEX THEN
          poszMsg := 'Invoice ' || NVL(pRwTypRtn.obligation_no, '<NULL>') ||
                     ' item ' || pRwTypRtn.returned_prod_id || '/' ||
                     pRwTypRtn.cust_pref_vendor || ' LP ' ||
                     szPalletID || ' exists on putaway task';
          poiStatus := C_ALRDY_EXIST;
          RETURN;
        WHEN OTHERS THEN
          poiStatus := SQLCODE;
          RETURN;
      END;
    ELSE
      -- Home slot. Update qty expected
      BEGIN
        UPDATE inv
          SET qty_planned = qty_planned + iQty 
          WHERE plogi_loc = szLoc
          AND   logi_loc = szLoc;
        DBMS_OUTPUT.PUT_LINE('Update home inv: ' || szLoc || ' status: ' ||
          TO_CHAR(SQL%ROWCOUNT));
      EXCEPTION
        WHEN NO_DATA_FOUND THEN
          NULL;
        WHEN OTHERS THEN
          poiStatus := SQLCODE;
          RETURN;
      END;
    END IF;
  END IF;
  DBMS_OUTPUT.PUT_LINE('Inv create/update ok');

  -- The putaway task doesn't exist. Create it. The catch_wt flag will be
  -- set to N for now. The temp_trk flag will be set according to the PM flag
  -- and whether the current return already had the temperature
  BEGIN
    INSERT INTO putawaylst
      (rec_id, dest_loc, pallet_id,
       prod_id, cust_pref_vendor,
       qty, qty_expected, qty_received, uom,
       equip_id, rec_lane_id, status, inv_status, exp_date,
       weight, temp, catch_wt, temp_trk,
       putaway_put, seq_no, erm_line_id, mispick, print_status,
       reason_code, lot_id, orig_invoice, rtn_label_printed, po_no)
      VALUES (
       DECODE(pszRsnGroup, 'DMG', 'D', 'S') || TO_CHAR(pRwTypRtn.manifest_no),
       szLoc, szPalletID,
       NVL(pRwTypRtn.returned_prod_id, pRwTypRtn.prod_id),
       pRwTypRtn.cust_pref_vendor,
       iQty, iQty, iQty, TO_NUMBER(pRwTypRtn.returned_split_cd),
       ' ', ' ', DECODE(pszRsnGroup, 'DMG', ' ', 'NEW'),
       DECODE(pszRsnGroup, 'DMG', ' ', 'AVL'), 
       f_get_rtn_date(szLoc),
       pRwTypRtn.catchweight, pRwTypRtn.temperature,
       'N',
       DECODE(pszRsnGroup, 'DMG', 'N',
              DECODE(pRwTypRtn.temperature, NULL, rwTypPm.temp_trk, 'C')),
       'N', pRwTypRtn.erm_line_id, pRwTypRtn.erm_line_id,
       DECODE(pszRsnGroup,
              'MPR', 'Y', 'MPK', 'Y', 'OVR', 'Y', 'OVI', 'Y', 'N'), NULL,
       pRwTypRtn.return_reason_cd,
       DECODE(INSTR(pRwTypRtn.obligation_no, 'L'),
              0, pRwTypRtn.obligation_no,
              SUBSTR(pRwTypRtn.obligation_no,
                     1, INSTR(pRwTypRtn.obligation_no, 'L') - 1)),
       DECODE(INSTR(szOrigInv, 'L'),
              0, szOrigInv,
              SUBSTR(szOrigInv, 1, INSTR(szOrigInv, 'L') - 1)),
       'N',
       DECODE(pszRsnGroup, 'DMG', 'D', 'S') || TO_CHAR(pRwTypRtn.manifest_no));

    DBMS_OUTPUT.PUT_LINE('Add PUTAWAYLST ok: ' || szLoc || '/' || szPalletID);

    -- Create T-batch if needed
    IF gRcTypSyspar.lbr_mgmt_flag = 'Y' AND
       gRcTypSyspar.create_batch_flag = 'Y' THEN
      BEGIN
        pl_rtn_lm.create_rtn_lm_batches(szPalletID,
                                        iNumTBatches, tbTBatches,
                                        szMsg, iStatus);
        IF iStatus <> C_NORMAL AND iStatus <> C_CTE_RTN_BTCH_FLG_OFF THEN
          poszMsg := 'Invoice ' || NVL(pRwTypRtn.obligation_no, '<NULL>') ||
                     ' item ' || pRwTypRtn.returned_prod_id || '/' ||
                     pRwTypRtn.cust_pref_vendor || szMsg;
          poiStatus := iStatus;
          RETURN;
        END IF;
      EXCEPTION
        WHEN OTHERS THEN
          poiStatus := SQLCODE;
          RETURN;
      END;
    END IF;
  EXCEPTION
    WHEN DUP_VAL_ON_INDEX THEN
      poszMsg := 'Invoice ' || NVL(pRwTypRtn.obligation_no, '<NULL>') ||
                 ' item ' || pRwTypRtn.returned_prod_id || '/' ||
                 pRwTypRtn.cust_pref_vendor || ' LP ' ||
                 szPalletID || ' exists on putaway task';
      poiStatus := C_ALRDY_EXIST;
      RETURN;
    WHEN OTHERS THEN
      poiStatus := SQLCODE;
      RETURN;
  END;

  -- Current return doesn't have temperature input but the item is a
  -- temperature tracked item
  IF pRwTypRtn.temperature IS NULL AND rwTypPm.temp_trk = 'Y' THEN
    -- Try to retrieve the latest temperature collected for the invoiced/item
    BEGIN
      SELECT r.temperature INTO iTemp
      FROM returns r, reason_cds d
      WHERE r.manifest_no = pRwTypRtn.manifest_no
      AND   r.erm_line_id <> pRwTypRtn.erm_line_id
      AND   NVL(DECODE(INSTR(r.obligation_no, 'L'),
                       0, r.obligation_no,
                       SUBSTR(r.obligation_no,
                              1, INSTR(r.obligation_no, 'L') - 1)),
                ' ') = NVL(pRwTypRtn.obligation_no, ' ')
      AND   r.prod_id = pRwTypRtn.prod_id
      AND   r.cust_pref_vendor = pRwTypRtn.cust_pref_vendor
      AND   NVL(r.temperature, 0) <> 0
      AND   r.return_reason_cd = d.reason_cd
      AND   d.reason_cd_type = 'RTN'
      AND   d.reason_group NOT IN ('DMG', 'STM', 'MPK')
      AND   r.erm_line_id = (SELECT MAX(erm_line_id)
                             FROM returns r1, reason_cds d1
                             WHERE r1.manifest_no = r.manifest_no
                             AND   r1.erm_line_id <> pRwTypRtn.erm_line_id
                             AND   NVL(DECODE(INSTR(r1.obligation_no, 'L'),
                                              0, r1.obligation_no,
                                              SUBSTR(r1.obligation_no,
                                          1, INSTR(r1.obligation_no, 'L') - 1)),
                                       ' ') = NVL(pRwTypRtn.obligation_no, ' ')
                             AND   r1.prod_id = r.prod_id
                             AND   r1.cust_pref_vendor = r.cust_pref_vendor
                             AND   NVL(r1.temperature, 0) <> 0
                             AND   r1.return_reason_cd = d1.reason_cd
                             AND   d1.reason_cd_type = 'RTN'
                            AND   d1.reason_group NOT IN ('DMG', 'STM', 'MPK'));
    EXCEPTION
      WHEN NO_DATA_FOUND THEN
        -- This is the 1st record created or no temperature ever collected yet
        -- for this invoiced/item
        iTemp := NULL;
      WHEN OTHERS THEN
        poiStatus :=  SQLCODE;
        RETURN;
    END;
    DBMS_OUTPUT.PUT_LINE('Previous collected temp: ' || TO_CHAR(iTemp));
    IF NVL(iTemp, 0) <> 0 THEN 
      -- Since we found the previous (but latest) temperature for the
      -- invoiced/item, we will use it so user doesn't need to collect it again 
      BEGIN
        UPDATE returns
        SET temperature = iTemp,
        upd_source = 'RF'
        WHERE manifest_no = pRwTypRtn.manifest_no
        AND   erm_line_id = pRwTypRtn.erm_line_id;
        DBMS_OUTPUT.PUT_LINE('Update RETURNS temp to ' || TO_CHAR(iTemp) ||
          ' cnt: ' || TO_CHAR(SQL%ROWCOUNT));
      EXCEPTION
        WHEN NO_DATA_FOUND THEN
          NULL;
        WHEN OTHERS THEN
          poiStatus := SQLCODE;
          RETURN;
      END;
      BEGIN
        UPDATE erd
        SET temp = iTemp
        WHERE SUBSTR(erm_id, 2) = TO_CHAR(pRwTypRtn.manifest_no)
        AND   erm_line_id = pRwTypRtn.erm_line_id;
        DBMS_OUTPUT.PUT_LINE('Update ERD temp to ' || TO_CHAR(iTemp) ||
          ' cnt: ' || TO_CHAR(SQL%ROWCOUNT));
      EXCEPTION
        WHEN NO_DATA_FOUND THEN
          NULL;
        WHEN OTHERS THEN
          poiStatus := SQLCODE;
          RETURN;
      END;
      BEGIN
        UPDATE putawaylst pt
        SET temp = iTemp, temp_trk = 'C'
        WHERE pallet_id = szPalletID;
        DBMS_OUTPUT.PUT_LINE('Update PUTAWAYLST temp to ' || TO_CHAR(iTemp) ||
          ' cnt: ' || TO_CHAR(SQL%ROWCOUNT));
      EXCEPTION
        WHEN NO_DATA_FOUND THEN
          NULL;
        WHEN OTHERS THEN
          poiStatus := SQLCODE;
          RETURN;
      END;
    END IF;
  END IF;

  -- The putaway task is created successfully. Return the whole record to caller
  BEGIN
    SELECT prod_id, cust_pref_vendor, qty, uom, exp_date, weight, temp,
           catch_wt, temp_trk, putaway_put, erm_line_id, mispick, print_status,
           reason_code, lot_id, orig_invoice, rtn_label_printed, pallet_id,
           po_no, pallet_batch_no, parent_pallet_id
    INTO rwTypPutlst.prod_id, rwTypPutlst.cust_pref_vendor, rwTypPutlst.qty,
         rwTypPutlst.uom, rwTypPutlst.exp_date, rwTypPutlst.weight,
         rwTypPutlst.temp, rwTypPutlst.catch_wt, rwTypPutlst.temp_trk,
         rwTypPutlst.putaway_put, rwTypPutlst.erm_line_id, rwTypPutlst.mispick,
         rwTypPutlst.print_status, rwTypPutlst.reason_code, rwTypPutlst.lot_id,
         rwTypPutlst.orig_invoice, rwTypPutlst.rtn_label_printed, 
         rwTypPutlst.pallet_id, rwTypPutlst.po_no,
         rwTypPutlst.pallet_batch_no, rwTypPutlst.parent_pallet_id
    FROM putawaylst
    WHERE pallet_id = szPalletID;
    pRwTypPutlst := rwTypPutlst;
  EXCEPTION
    WHEN OTHERS THEN
      pRwTypPutlst := NULL;
      poiStatus := SQLCODE;
      RETURN;
  END;

  poiStatus := C_NORMAL;
EXCEPTION
  WHEN OTHERS THEN
    pRwTypPutlst := NULL;
    poiStatus := SQLCODE;
END;
-- -----------------------------------------------------------------------------

-- =============================================================================
-- Function
--   delete_puttask
--
-- Description
--   The function handles the deletion of the putaway task for the specific
--   return.
--
-- Parameters
--   piMfNo (input)
--     Manifest # to be used to delete the putaway task
--   pszRsnGroup (input)
--     Reason group to be used to delete the putaway task
--   piLine (input)
--     Line # (erm_line_id) to be used to delete the putaway task
--
-- Returns
--   0 - The putaway task has been deleted successfully.
--   <0 - Database error.
--
-- Modification History
-- Date      User   Defect  Comment
--
FUNCTION delete_puttask (
  piMfNo    IN  manifests.manifest_no%TYPE,
  pszRsnGroup   IN  reason_cds.reason_group%TYPE,
  piLine    IN  putawaylst.erm_line_id%TYPE)
RETURN NUMBER IS
BEGIN
  DELETE putawaylst
    WHERE rec_id = DECODE(pszRsnGroup, 'DMG', 'D', 'S') || TO_CHAR(piMfNo)
    AND   erm_line_id = piLine;
  RETURN C_NORMAL;
EXCEPTION
  WHEN NO_DATA_FOUND THEN
    RETURN C_NORMAL;
  WHEN OTHERS THEN
    RETURN SQLCODE;
END;
-- -----------------------------------------------------------------------------

-- =============================================================================
-- Function
--   get_put_loc
--
-- Description
--   The function retrieves the putaway location for the return. It's mainly
--   used to update the returned location in FLOAT_HIST table.
--
-- Parameters
--   pszRsnGroup (input)
--     Reason group to be used to get the location
--   pRwTypRtn (input)
--     The return information that are used to get the location
--
-- Returns
--   The put back location or NULL if no location is found
--
-- Modification History
-- Date      User   Defect  Comment
--
FUNCTION get_put_loc (
  pszRsnGroup IN reason_cds.reason_group%TYPE,
  pRwTypRtn IN returns%ROWTYPE)
RETURN VARCHAR2 IS
  szLoc     loc.logi_loc%TYPE := NULL;
  CURSOR c_get_putawaylst_loc IS
    SELECT dest_loc
    FROM putawaylst
    WHERE SUBSTR(rec_id, 2) = TO_CHAR(pRwTypRtn.manifest_no)
    AND   prod_id = DECODE(pszRsnGroup, 'MPR', pRwTypRtn.returned_prod_id,
                                        'MPK', pRwTypRtn.returned_prod_id,
                                        pRwTypRtn.prod_id)
    AND   cust_pref_vendor = pRwTypRtn.cust_pref_vendor
    AND   reason_code = pRwTypRtn.return_reason_cd
    AND   erm_line_id = pRwTypRtn.erm_line_id;
  CURSOR c_get_trans_loc IS
    SELECT dest_loc
    FROM trans
    WHERE SUBSTR(rec_id, 2) = TO_CHAR(pRwTypRtn.manifest_no)
    AND   trans_type IN ('PUT', 'MIS')
    AND   prod_id = DECODE(pszRsnGroup, 'MPR', pRwTypRtn.returned_prod_id,
                                        'MPK', pRwTypRtn.returned_prod_id,
                                        pRwTypRtn.prod_id)
    AND   cust_pref_vendor = pRwTypRtn.cust_pref_vendor
    AND   reason_code = pRwTypRtn.return_reason_cd
    AND   order_line_id = pRwTypRtn.erm_line_id;
BEGIN
  IF pszRsnGroup IN ('STM', 'MPK') THEN
    RETURN szLoc;
  END IF;

  OPEN c_get_putawaylst_loc;
  FETCH c_get_putawaylst_loc INTO szLoc;
  IF c_get_putawaylst_loc%NOTFOUND THEN
    OPEN c_get_trans_loc;
    FETCH c_get_trans_loc INTO szLoc;
    CLOSE c_get_trans_loc;
  END IF;
  CLOSE c_get_putawaylst_loc;

  RETURN szLoc;
EXCEPTION
  WHEN OTHERS THEN
    RETURN NULL;
END;
-- -----------------------------------------------------------------------------

-- =============================================================================
-- Function
--   add_cc_cel
--
-- Description
--   The function handles the creation or update of new or existing cycle counts
--   (CC table) and cycle count exceptions (CC_EXCEPTION_LIST table) for certain
--   returned reason groups (STM, OVR, MPR, MPK, OVI).
--
-- Parameters
--   piBatch (input)
--     Batch # to be used to create the cycle counts and their exceptions
--   pszItem (input)
--     Item # to be used to create the cycle counts and their exceptions
--   pszCpv (input)
--     Cust_pref_vendor to be used to create the cycle counts and their
--     exceptions
--   pszLoc (input)
--     Location to be used to create the cycle counts and their exceptions. It
--     can be '*'
--   pszPallet (input)
--     License plate to be used to create the cycle counts and their exceptions
--   pszCCRsn (input)
--     Cycle count reason code to be used to create the cycle counts and their
--     exceptions
--   piQty (input)
--     Qty to be used to create the cycle count exceptions
--   pszUom (input)
--     Uom to be used to create the cycle count exceptions
--
-- Returns
--   0 - The cycle counts and/or their exceptions have been created/updated
--     successfully.
--   <0 - Database error.
--
-- Modification History
-- Date      User   Defect  Comment
--
FUNCTION add_cc_cel (
  piBatch   IN cc.batch_no%TYPE,
  pszItem   IN pm.prod_id%TYPE,
  pszCpv    IN pm.cust_pref_vendor%TYPE,
  pszLoc    IN loc.logi_loc%TYPE,
  pszPallet IN loc.logi_loc%TYPE,
  pszCCRsn  IN reason_cds.cc_reason_code%TYPE,
  piQty     IN returns.returned_qty%TYPE,
  pszUom    IN returns.returned_split_cd%TYPE)
RETURN NUMBER IS
BEGIN
  -- Create cycle count record
  BEGIN
    INSERT INTO cc
      (type, batch_no, phys_loc, logi_loc, prod_id, cust_pref_vendor, status,
       cc_gen_date, cc_reason_code)
      VALUES (
       'PROD', piBatch, pszLoc, pszPallet, pszItem, pszCpv, 'NEW', SYSDATE,
       NVL(pszCCRsn, 'SE'));
  EXCEPTION
    WHEN DUP_VAL_ON_INDEX THEN
      BEGIN
        UPDATE cc c
          SET type = 'PROD',
              batch_no = piBatch,
              status = 'NEW',
              cc_gen_date = SYSDATE,
              cc_reason_code = NVL(pszCCRsn, 'SE')
          WHERE prod_id = pszItem
          AND   cust_pref_vendor = pszCpv
          AND   phys_loc = pszLoc
          AND   logi_loc = pszPallet
          AND   EXISTS (SELECT 'LOWER PRIORITY'
                        FROM cc_reason rc, cc_reason ra
                        WHERE ra.cc_reason_code = pszCCRsn
                        AND   rc.cc_reason_code = c.cc_reason_code
                        AND   rc.cc_priority >= ra.cc_priority);
      EXCEPTION
        WHEN OTHERS THEN
          RETURN SQLCODE;
      END;
    WHEN OTHERS THEN
      RETURN SQLCODE;
  END;

  -- Create cycle count exception record for non CC reason code
  IF NVL(pszCCRsn, 'SE') <> 'CC' THEN
    BEGIN
      INSERT INTO cc_exception_list
        (phys_loc, logi_loc, prod_id, cust_pref_vendor, cc_except_date,
         cc_except_code, qty, uom)
        VALUES (
         pszLoc, pszPallet, pszItem, pszCpv, SYSDATE, NVL(pszCCRsn, 'SE'),
         piQty, pszUom);
    EXCEPTION
      WHEN DUP_VAL_ON_INDEX THEN
        BEGIN
          UPDATE cc_exception_list
            SET qty = NVL(qty, 0) + NVL(piQty, 0)
            WHERE phys_loc = pszLoc
            AND   logi_loc = pszPallet
            AND   cc_except_code = NVL(pszCCRsn, 'SE')
            AND   prod_id = pszItem
            AND   cust_pref_vendor = pszCpv;
        EXCEPTION
          WHEN OTHERS THEN
            RETURN SQLCODE;
        END; 
      WHEN OTHERS THEN
        RETURN SQLCODE;
    END;
  END IF;

  RETURN C_NORMAL;
EXCEPTION
  WHEN OTHERS THEN
    RETURN SQLCODE;
END;
-- -----------------------------------------------------------------------------

-- =============================================================================
-- Function
--   create_cyc
--
-- Description
--   The function handles the creation of cycle counts and their exceptions
--   according to the input return information.
--
-- Parameters
--   poszLMStr (output)
--     String contains pallet type change information for floating slot so
--     caller can send the information to SUS via LM APCOM queue
--   poiStatus (output)
--     0 - The cycle count information have been created/updated successfully
--     C_NO_LOC - No location is found for the cycle count
--     <0 - Database error.
--   pRwTypRsn (input)
--     Reason code information to be used to create cycle count information
--   pRwTypRtn (input)
--     Returns information to be used to create cycle count information
--   piCCType (input)
--     Type of cycle count information to be created. Default to 1 for invoiced
--     returned item or 2 for mispicked returned item
--
-- Returns
--   See output parameters above
--
-- Modification History
-- Date      User   Defect  Comment
--
PROCEDURE create_cyc (
  poszLMStr OUT VARCHAR2,
  poiStatus OUT NUMBER,
  pRwTypRsn IN  reason_cds%ROWTYPE,
  pRwTypRtn IN  returns%ROWTYPE,
  piCCType  IN  NUMBER DEFAULT 1) IS
  szItem    pm.prod_id%TYPE := pRwTypRtn.prod_id;
  szLoc     loc.logi_loc%TYPE;
  szPallet  inv.logi_loc%TYPE;
  iFloatSlot    NUMBER := 0;
  iStatus   NUMBER := C_NORMAL;
  iBatch    cc.batch_no%TYPE;
  szRsn     reason_cds.cc_reason_code%TYPE := pRwTypRsn.cc_reason_code;
  szUseRsn  reason_cds.cc_reason_code%TYPE := NULL;
  iInvCnt   NUMBER := 0;
  szIndLoc  loc.logi_loc%TYPE := NULL;
  iNextPalID    inv.logi_loc%TYPE := NULL;
  iExcCCCnt NUMBER := 0;
  iPutAisle NUMBER := 0;
  iPutSlot  NUMBER := 0;
  iPutLevel NUMBER := 0;
  sCCLoc    cc.phys_loc%TYPE := NULL;
  sCCLP     cc.logi_loc%TYPE := NULL;
  iNoCEL    NUMBER := 0;
  iRtnUom   NUMBER := 0;
  blnGenCC  BOOLEAN := TRUE;
  CURSOR c_get_inv_slots(cpszItem pm.prod_id%TYPE,
                         cpszCpv  pm.cust_pref_vendor%TYPE) IS
    SELECT i.plogi_loc, i.logi_loc, l.perm, l.rank, z.rule_id,
           z.induction_loc, z.outbound_loc, i.inv_uom, p.miniload_storage_ind
    FROM  inv i, loc l, zone z, lzone lz, pm p
    WHERE i.prod_id = cpszItem
    AND   i.cust_pref_vendor = cpszCpv
    AND   z.zone_id = lz.zone_id
    AND   z.zone_type = 'PUT'
    AND   i.plogi_loc = l.logi_loc
    AND   i.plogi_loc = lz.logi_loc
    AND   z.warehouse_id = '000'
    AND   i.prod_id = p.prod_id
    AND   i.cust_pref_vendor = p.cust_pref_vendor;
  CURSOR c_get_put_path(cpszLoc loc.logi_loc%TYPE) IS
    SELECT put_aisle, put_slot, put_level
    FROM loc
    WHERE logi_loc = cpszLoc;
  CURSOR c_get_cur_cc_tasks(cpszItem    pm.prod_id%TYPE,
                            cpszCpv pm.cust_pref_vendor%TYPE,
                            cpiBatch    cc.batch_no%TYPE,
                            cpiLSSPAsle loc.put_aisle%TYPE,
                            cpiLSSPSlot loc.put_slot%TYPE,
                            cpiLSSPLvl  loc.put_level%TYPE) IS
    SELECT c.phys_loc, c.logi_loc
    FROM cc c, loc l
    WHERE c.batch_no = cpiBatch
    AND   c.prod_id = cpszItem
    AND   c.cust_pref_vendor = cpszCpv
    AND   c.phys_loc = l.logi_loc
    ORDER BY ABS(cpiLSSPAsle - l.put_aisle), l.put_aisle,
             ABS(cpiLSSPSlot - l.put_slot), l.put_slot,
             ABS(cpiLSSPLvl - l.put_level), l.put_level;
BEGIN
  IF piCCType = 2 THEN
    szItem := pRwTypRtn.returned_prod_id;
    szRsn := 'CC';
  END IF;
  IF szRsn IS NULL THEN
    szRsn := 'SE';
  END IF;

  -- Set the returned uom for use by Mini-load uom checking later
  iRtnUom := 2 - TO_NUMBER(pRwTypRtn.returned_split_cd);

  -- Try to find the location first
  get_loc(pRwTypRtn.manifest_no, szItem, pRwTypRtn.cust_pref_vendor,
          pRwTypRtn.returned_split_cd, szLoc, iFloatSlot, poszLMStr, iStatus);
  DBMS_OUTPUT.PUT_LINE('CreateCYC status: ' || TO_CHAR(iStatus) || 
    ', found loc: ' || szLoc || '/' || TO_CHAR(iFloatSlot) ||
    ', old rsn: ' || szRsn || ', flg: ' || gRcTypSyspar.cc_gen_exc_reserve);
  IF iStatus <> C_NORMAL THEN
    poiStatus := iStatus;
    RETURN;
  END IF;

  -- Generate a unique cycle count sequence
  BEGIN
    SELECT cc_batch_no_seq.nextval INTO iBatch FROM DUAL;
  EXCEPTION
    WHEN OTHERS THEN
      poiStatus := SQLCODE;
      RETURN;
  END;
  DBMS_OUTPUT.PUT_LINE('To-be-used CC batch #: ' || TO_CHAR(iBatch));

  -- As of release level 9.6: not implement yet
  -- Special handling to create cycle count task on the following conditions:
  -- INV: Invoiced item             MIS: Mispicked item
  -- Str Ind: Mini-load storage indicator   Rtn Uom: Returned qty uom
  -- Rtn Grp MPR/K: Returned reason code group is MPR or MPK or other
  -- Loc Typ: Inventory location type h(ome), r(eserved), f(loat),
  --          ml-1(Mini-load-splits), ml-2 (Mini-load cases)
  -- *****INV****    *****MIS****    Rtn
  --      Str Loc         Str Loc    Grp    Rtn    CreateCC    CreateCC
  -- Item Ind Typ    Item Ind Typ    MPR/K? Uom    INV item    MIS item
  --  Y    N  h,r,f                  Y, N   0,1    h,r,f
  --  Y    B  ml-1,2                 N      1      ml-1
  --                                 N      0      ml-2
  --  Y    B  ml-1,2                 Y      0,1    ml-1, ml-2
  --  Y    S  h,r,f,                 N      1      ml-1
  --          ml-1                   N      0      h,r,f
  --  Y    S  h,r,f,                 Y      1      ml-1
  --          ml-1                   Y      0      h,r,f
  --                   Y   N  h,r,f  Y      0,1                h,r,f
  --                   Y   B  ml-1,  Y      1                  ml-1 
  --                          ml-2   Y      0                  ml-2
  --                   Y   S  h,r,f, Y      1                  ml-1
  --                          ml-1   Y      0                  h,r,f
  IF szLoc <> '*' THEN
    -- If location is not found, we will not create any cycle count
    -- If at least one inventory record is found, we will create/update cycle
    -- counts and exceptions depending on certain criteria
    FOR cgis IN c_get_inv_slots(szItem, pRwTypRtn.cust_pref_vendor) LOOP
      iInvCnt := iInvCnt + 1;
      DBMS_OUTPUT.PUT_LINE('Cur inv ' || cgis.plogi_loc || '/' ||
        cgis.logi_loc || '/' || cgis.perm || '/' || TO_CHAR(cgis.rule_id) ||
        '/' || szItem || ' u: ' || TO_CHAR(cgis.inv_uom) || '/' ||
        cgis.miniload_storage_ind);
      blnGenCC := TRUE;
      IF cgis.perm = 'Y' THEN
        -- Currently handling home slot. Create the cycle count task using the
        -- input reason code which should be an exception reason code, include
        -- all ranks of home slots.
--        IF NOT (piCCType = 1 AND
--                cgis.miniload_storage_ind = 'S' AND
--                pRwTypRtn.returned_split_cd = '1') THEN
          iStatus := add_cc_cel(iBatch, szItem, pRwTypRtn.cust_pref_vendor,
                                cgis.plogi_loc, cgis.logi_loc, szRsn,
                                pRwTypRtn.returned_qty,
                                pRwTypRtn.returned_split_cd);
          DBMS_OUTPUT.PUT_LINE('Create CC task for home item: ' || szItem ||
            ' batch: ' || TO_CHAR(iBatch) || ', loc: ' || cgis.plogi_loc ||
            '/' || cgis.logi_loc || ', r: ' || szRsn || ', u: ' ||
            pRwTypRtn.returned_split_cd || ', st: ' || TO_CHAR(iStatus));
--        END IF;
      ELSE
        -- Currently handling either a floating/reserved/Miniload slot.
        IF cgis.rule_id IN (0, 2) THEN
          IF gRcTypSyspar.cc_gen_exc_reserve = 'Y' THEN
            -- Only generate cycle count tasks with CC reason for reserved/
            -- bulkpull slots if the flag is set
--            IF NOT (piCCType = 1 AND
--                    cgis.miniload_storage_ind = 'S' AND
--                    pRwTypRtn.returned_split_cd = '1') THEN
              iStatus := add_cc_cel(iBatch, szItem, pRwTypRtn.cust_pref_vendor,
                                    cgis.plogi_loc, cgis.logi_loc, 'CC',
                                    pRwTypRtn.returned_qty,
                                    pRwTypRtn.returned_split_cd);
              DBMS_OUTPUT.PUT_LINE('Create CC task for resv item: ' || szItem ||
                ' batch: ' || TO_CHAR(iBatch) || ', loc: ' || cgis.plogi_loc ||
                '/' || cgis.logi_loc || ', r: ' || szRsn || ', u: ' ||
                pRwTypRtn.returned_split_cd || ', st: ' || TO_CHAR(iStatus));
--            END IF;
          END IF;
        ELSIF cgis.rule_id IN (1, 3) THEN
          -- Floating/Miniload slot. szLoc should hold the last ship slot value.
          -- Create cycle count tasks with the following conditions:
          --  CreateForReserved LastShipSlot Reason
          --   Y                Y            Exception reason code input
          --   Y                N            CC
          --   N                Y, N         Reason code input, including CC
          --                                 for mispicked item
          szUseRsn := szRsn;
          IF cgis.rule_id = 3 AND cgis.plogi_loc = cgis.induction_loc THEN
            -- Current inventory is in Miniload induction location. Don't
            -- create cycle count task for it
            iInvCnt := iInvCnt - 1;
          ELSE
            IF gRcTypSyspar.cc_gen_exc_reserve = 'Y' THEN
              IF cgis.plogi_loc <> szLoc THEN
                szUseRsn := 'CC';
              END IF;
            END IF;
--            IF cgis.rule_id = 3 THEN
              -- Only generate cycle count task for same uom on Mini-load
              -- except it's an invoiced item from MPR/K w/ miniload_storage_
              -- ind as "B". In this case, all Mini-load slots for the item
              -- should be generated, regardless of the returned uom.
--              IF piCCType = 1 AND
--                 cgis.miniload_storage_ind = 'B' AND
--                 pRwTypRsn.reason_group IN ('MPR', 'MPK') THEN
--                NULL;
--              ELSIF NVL(cgis.inv_uom, 0) <> iRtnUom THEN
--                blnGenCC := FALSE;
--              END IF;
--            ELSIF NVL(cgis.inv_uom, 0) <> iRtnUom AND
--                  cgis.miniload_storage_ind = 'S' THEN
--              blnGenCC := FALSE;
--            END IF;
            IF blnGenCC THEN
              iStatus := add_cc_cel(iBatch, szItem, pRwTypRtn.cust_pref_vendor,
                                    cgis.plogi_loc, cgis.logi_loc, szUseRsn,
                                    pRwTypRtn.returned_qty,
                                    pRwTypRtn.returned_split_cd);
              DBMS_OUTPUT.PUT_LINE('CreateCYC add ' || szItem || '/' ||
                cgis.plogi_loc || '/' || cgis.logi_loc || ', r: ' ||
                szUseRsn || ', q: ' || TO_CHAR(pRwTypRtn.returned_qty) || '/' ||
                pRwTypRtn.returned_split_cd || ', st: ' || TO_CHAR(iStatus));
            END IF;
          END IF;
        END IF;
      END IF;
      EXIT WHEN iStatus <> C_NORMAL;
    END LOOP;
    IF szRsn <> 'CC' THEN
      -- The current item should be an invoiced item
      BEGIN
        SELECT COUNT(1) INTO iExcCCCnt
        FROM cc
        WHERE prod_id = szItem
        AND   cust_pref_vendor = pRwTypRtn.cust_pref_vendor
        AND   batch_no = iBatch
        AND   cc_reason_code = szRsn;
      EXCEPTION
        WHEN OTHERS THEN
          iStatus := SQLCODE;
      END;
      DBMS_OUTPUT.PUT_LINE('# of created CC w/ old rsn: ' ||
        TO_CHAR(iExcCCCnt) || ', status: ' || TO_CHAR(iStatus));
      IF iStatus = C_NORMAL AND iExcCCCnt = 0 THEN
        -- There is no current inventory in the last ship slot now and the
        -- just generated cycle count task(s) all go into CC reasons. We need
        -- to change at least one task to use the exception reason.
        iPutAisle := 0;
        iPutSlot := 0;
        iPutLevel := 0;
        OPEN c_get_put_path(szloc);
        FETCH c_get_put_path INTO iPutAisle, iPutSlot, iPutLevel;
        CLOSE c_get_put_path;
        DBMS_OUTPUT.PUT_LINE('CreateCYC Found slot info: ' || szLoc || '/' ||
          TO_CHAR(iPutAisle) || '/' || TO_CHAR(iPutSlot) || '/' ||
          TO_CHAR(iPutLevel) || ' item: ' || szItem || ', batch: ' ||
          TO_CHAR(iBatch));
        OPEN c_get_cur_cc_tasks(szItem, pRwTypRtn.cust_pref_vendor,
                                iBatch, iPutAisle, iPutSlot, iPutLevel);
        FETCH c_get_cur_cc_tasks INTO sCCLoc, sCCLP;
        DBMS_OUTPUT.PUT_LINE('CreateCYC Found cc: ' || sCCLoc || '/' ||
          sCCLP);
        IF c_get_cur_cc_tasks%FOUND THEN
          BEGIN
            UPDATE cc
            SET cc_reason_code = szRsn,
                upd_date = SYSDATE,
                upd_user = USER
            WHERE prod_id = szItem 
            AND   cust_pref_vendor = pRwTypRtn.cust_pref_vendor
            AND   phys_loc = sCCLoc
            AND   logi_loc = sCCLP;
          EXCEPTION
            WHEN NO_DATA_FOUND THEN
              NULL;
            WHEN OTHERS THEN
              iStatus := SQLCODE;
          END;
          IF iStatus = C_NORMAL THEN
            BEGIN
              UPDATE cc_exception_list
              SET cc_except_code = szRsn
              WHERE prod_id = szItem 
              AND   cust_pref_vendor = pRwTypRtn.cust_pref_vendor
              AND   phys_loc = sCCLoc
              AND   logi_loc = sCCLP;
              IF SQL%ROWCOUNT = 0 THEN
                iNoCEL := 1;
              END IF;
            EXCEPTION
              WHEN NO_DATA_FOUND THEN
                iNoCEL := 1;
              WHEN OTHERS THEN
                iStatus := SQLCODE;
            END;
          END IF;
          IF iStatus = C_NORMAL AND iNoCEL = 1 THEN
            BEGIN
              INSERT INTO cc_exception_list
                (prod_id, cust_pref_vendor, phys_loc, logi_loc,
                 cc_except_code, cc_except_date, qty, uom)
                VALUES (
                 szItem, pRwTypRtn.cust_pref_vendor, sCCLoc, sCCLP,
                 szRsn, SYSDATE, pRwTypRtn.returned_qty,
                 pRwTypRtn.returned_split_cd);
            EXCEPTION
              WHEN OTHERS THEN
                iStatus := SQLCODE;
            END; 
          END IF;
        ELSE
          -- No previously create CC task for some reason. We should still
          -- create one CC task and its exception if any from last ship slot
          DBMS_OUTPUT.PUT_LINE('Cur loc: ' || szLoc);
          IF NVL(szLoc, '*') <> '*' AND
             pl_ml_common.f_is_induction_loc(szLoc) = 'N' THEN
            BEGIN
              SELECT pallet_id_seq.nextval INTO iNextPalID FROM DUAL;
            EXCEPTION
              WHEN OTHERS THEN
                iStatus := SQLCODE;
            END;
            IF iStatus = C_NORMAL THEN
              DBMS_OUTPUT.PUT_LINE('Add CC for no CC created bf: ' ||
                szLoc || '/' || iNextPalID || '/' || szItem || 
                ' bch: ' || TO_CHAR(iBatch) || ' r: ' || szRsn);
              iStatus := add_cc_cel(iBatch, szItem, pRwTypRtn.cust_pref_vendor,
                                    szLoc, iNextPalID, szRsn,
                                    pRwTypRtn.returned_qty,
                                    pRwTypRtn.returned_split_cd);
              IF iStatus = C_NORMAL THEN
                -- This is to prevent the same record get created again on
                -- next check of iInvCnt = 0
                iInvCnt := iInvCnt + 1;
              END IF;
            END IF;
          END IF;
        END IF;
        CLOSE c_get_cur_cc_tasks;
      END IF;
    END IF;
    DBMS_OUTPUT.PUT_LINE('Bf no inv processing status: ' || TO_CHAR(iStatus) ||
      ', cnt: ' || TO_CHAR(iInvCnt) || ', LSS: ' || szLoc);
    IF iStatus = C_NORMAL AND iInvCnt = 0 AND szLoc <> '*' THEN
      IF iFloatSlot = 1 THEN
        pl_ml_common.get_induction_loc(szItem, pRwTypRtn.cust_pref_vendor,
                                       TO_NUMBER(pRwTypRtn.returned_split_cd),
                                       iStatus, szIndLoc);
        IF iStatus = C_NORMAL OR iStatus = C_NOT_FOUND THEN
          -- Item's last ship slot is a floating/Miniload slot and there is
          -- no inventory record or inventory records are all belonged to
          -- induction slots
          iStatus := C_NORMAL;
          IF szLoc <> szIndLoc THEN
            -- We still need to generate at least one cycle count task for
            -- the last ship slot if it's not an induction slot
            BEGIN
              SELECT pallet_id_seq.nextval INTO iNextPalID FROM DUAL;
            EXCEPTION
              WHEN OTHERS THEN
                iStatus := SQLCODE;
            END;
            IF iStatus = C_NORMAL THEN
              iStatus := add_cc_cel(iBatch, szItem, pRwTypRtn.cust_pref_vendor,
                                    szLoc, iNextPalID, szRsn,
                                    pRwTypRtn.returned_qty,
                                    pRwTypRtn.returned_split_cd);
              DBMS_OUTPUT.PUT_LINE('New CC record for ' || szItem || '/' ||
                szLoc || '/' || iNextPalID || '/' || szRsn ||
                ', q: ' || TO_CHAR(pRwTypRtn.returned_qty) || '/' ||
                pRwTypRtn.returned_split_cd);
            END IF;
          ELSE
            iStatus := C_NORMAL;
          END IF;
        END IF;
      END IF;
    END IF;
  END IF;

  poiStatus := iStatus;
EXCEPTION
  WHEN OTHERS THEN
    poiStatus := SQLCODE;
END;
-- -----------------------------------------------------------------------------

-- =============================================================================
-- Function
--   check_ovr_und_rtn
--
-- Description
--   The function checks whether the input returned qty information plus the
--   previous entered returned qty information (if piUseCurQty = 0) or just the
--   previous entered returned qty information for the same invoiced/item have
--   exceeded/under/equal to the manifest detail shipped qty.
--
-- Parameters
--   pRwTypRtn (input)
--     Return information to be checked
--   piUseCurQty (input)
--     Whether to add the current returned qty into the calculation (=0,
--     default) or not (>0).
--   piExclRtn (input)
--     Whether to exclude the counting of a particular return line (>0) or
--     not (=0, default.) If the value is >0, this is normally an existing
--     erm_line_id on the return.
--
-- Returns
--   0 - The previous total returned qty + current returned qty = shipped qty
--     or the current return is an overage or a pickup or in OVI reason group
--   C_INV_RSN - Invalid reason code
--   C_NO_MF_INFO - No manifest information is found for the return
--   C_INV_PRODID - Invalid invoiced item present
--   C_QTY_RTN_GT_SHP - The previous total returned qty + current returned qty
--     will exceed the shipped qty
--   -20001 - The previous total returned qty + current returned qty is less
--     than the shipped qty
--
FUNCTION check_ovr_und_rtn(
  pRwTypRtn IN returns%ROWTYPE,
  piUseCurQty   IN NUMBER DEFAULT 0,
  piExclRtn IN NUMBER DEFAULT 0)
RETURN NUMBER IS
  tabTypRsns        tabTypReasons;
  rwTypMfHdr        manifests%ROWTYPE := NULL;
  rwTypMfDtls       manifest_dtls%ROWTYPE := NULL;
  iShipQty      NUMBER := 0;
  iCurRtnQty        NUMBER := 0;
  iTotRtnQty        NUMBER := 0;
  rwTypPm       pm%ROWTYPE := NULL;
  iSkidCube     NUMBER := 0;
  iStatus       NUMBER := C_NORMAL;
  iMfDtlCnt     NUMBER := 0;
  iChkSameUom       NUMBER := 0;
  CURSOR c_get_rtn_qty (cs_reason_group reason_cds.reason_group%TYPE) IS
    SELECT NVL(SUM(NVL(r.returned_qty, 0) /
                   DECODE(r.returned_split_cd, '1', p.spc, 1)), 0)
    FROM returns r, pm p, reason_cds c
    WHERE r.manifest_no = pRwTypRtn.manifest_no
    AND   DECODE(INSTR(r.obligation_no, 'L'), 0, r.obligation_no,
                 SUBSTR(r.obligation_no, 1, INSTR(r.obligation_no, 'L') - 1)) =
          pRwTypRtn.obligation_no
    AND   r.rec_type = pRwTypRtn.rec_type
    AND   NVL(r.returned_prod_id, r.prod_id) =
            DECODE(cs_reason_group,
                   'MPR', pRwTypRtn.returned_prod_id,
                   'MPK', pRwTypRtn.returned_prod_id,
                   pRwTypRtn.prod_id)
    AND   r.cust_pref_vendor = pRwTypRtn.cust_pref_vendor
    AND   r.prod_id = p.prod_id
    AND   r.cust_pref_vendor = p.cust_pref_vendor
    AND   c.reason_cd_type = 'RTN'
    AND   c.reason_cd = r.return_reason_cd
    AND   c.reason_group NOT IN ('OVR', 'OVI')
    AND   ((piExclRtn = 0) OR
           ((piExclRtn <> 0) AND (r.erm_line_id <> piExclRtn)))
    AND   ((iChkSameUom = 0) OR
           ((iChkSameUom <> 0) AND
            (r.returned_split_cd = pRwTypRtn.returned_split_cd)));
BEGIN
  -- Don't need verfication is no qty or pickup or overage or OVI
  IF NVL(pRwTypRtn.returned_qty, 0) = 0 OR
     pRwTypRtn.rec_type = 'O' OR
     (gRcTypSyspar.host_type = 'AS400' AND pRwTypRtn.rec_type = 'P') THEN
    RETURN C_NORMAL;
  END IF;
  tabTypRsns := get_reason_info('ALL', 'ALL', pRwTypRtn.return_reason_cd);
  IF tabTypRsns.COUNT = 0 THEN
    RETURN C_INV_RSN;
  END IF;
  IF tabTypRsns(1).reason_group IN ('OVR', 'OVI', 'MPR', 'MPK') THEN
    IF gRcTypSyspar.host_type = 'AS400' OR tabTypRsns(1).reason_group IN ('OVR', 'OVI') THEN
      RETURN C_NORMAL;
    END IF;
  END IF;

  -- Retrieve original ship qty in cases for the return
  get_mf_info(pRwTypRtn, rwTypMfHdr, rwTypMfDtls, iShipQty);
  IF rwTypMfDtls.manifest_no IS NULL THEN
    RETURN C_NO_MF_INFO;
  END IF;

  -- Convert current returned qty to cases if flag is not set
  IF piUseCurQty = 0 THEN
    iCurRtnQty := NVL(pRwTypRtn.returned_qty, 0);
    IF pRwTypRtn.returned_split_cd = '1' THEN
      get_master_item(pRwTypRtn.prod_id, pRwTypRtn.cust_pref_vendor,
                      iSkidCube, rwTypPm, iStatus);
      IF iStatus <> C_NORMAL THEN
        RETURN C_INV_PRODID;
      END IF;
      iCurRtnQty := iCurRtnQty / NVL(rwTypPm.spc, 1);
    END IF;
  ELSE
    iCurRtnQty := 0;
  END IF;
  DBMS_OUTPUT.PUT_LINE('UseCurQty: ' || TO_CHAR(piUseCurQty) ||
    ', curQ: ' || TO_CHAR(pRwTypRtn.returned_qty) || '/' ||
    TO_CHAR(iCurRtnQty) || ', curUom: ' || pRwTypRtn.returned_split_cd ||
    ', shpQ: ' || TO_CHAR(iShipQty));

  BEGIN
    SELECT COUNT(1) INTO iMfDtlCnt
    FROM manifest_dtls
    WHERE manifest_no = pRwTypRtn.manifest_no
    AND   DECODE(INSTR(obligation_no, 'L'),
                 0, obligation_no,
                 SUBSTR(obligation_no, 1, INSTR(obligation_no, 'L') - 1)) =
            pRwTypRtn.obligation_no
    AND   prod_id = pRwTypRtn.prod_id
    AND   cust_pref_vendor = pRwTypRtn.cust_pref_vendor
    AND   rec_type = pRwTypRtn.rec_type;
  EXCEPTION
    WHEN OTHERS THEN
      iMfDtlCnt := 0;
  END;
  IF iMfDtlCnt > 1 THEN
    iChkSameUom := 1;
  END IF;
  DBMS_OUTPUT.PUT_LINE('ChkOvrQ #mf_dtls: ' || TO_CHAR(iMfDtlCnt) ||
    ', ChkSameUom: ' || TO_CHAR(iChkSameUom) || ', ExcRtn: ' ||
    TO_CHAR(piExclRtn));

  -- Retrieve total returned qty in cases
  OPEN c_get_rtn_qty(tabTypRsns(1).reason_group);
  FETCH c_get_rtn_qty INTO iTotRtnQty;
  IF c_get_rtn_qty%NOTFOUND THEN
    iTotRtnQty := 0;
  END IF;
  CLOSE c_get_rtn_qty;
  DBMS_OUTPUT.PUT_LINE('Total qty before adding curQ: ' || TO_CHAR(iTotRtnQty));
  iTotRtnQty := iTotRtnQty + iCurRtnQty;
  DBMS_OUTPUT.PUT_LINE('Total qty after adding curQ: ' || TO_CHAR(iTotRtnQty));

  IF iTotRtnQty > iShipQty THEN
    RETURN C_QTY_RTN_GT_SHP;
  ELSIF iTotRtnQty < iShipQty THEN
    RETURN -20001;
  END IF;

  RETURN C_NORMAL;
EXCEPTION
  WHEN OTHERS THEN
    RETURN SQLCODE;
END;
-- -----------------------------------------------------------------------------

-- =============================================================================
-- Function
--   create_rtn_put_conf
--
-- Description
--   The function create PUT transactions and update inventory for those returns
--   that haven't been putawayed when the syspar RTN_PUTAWAY_CONF is set to 'N'
--   during manifest close process.
--
-- Parameters
--   piMfNo (input)
--     Manifest # to be used to create the putaway task
--
-- Returns
--   0 - The 'PUT' transactions have been created and inventory have been
--     updated successfully.
--   <0 - Database error.
--
-- Modification History
-- Date      User   Defect  Comment
--
FUNCTION create_rtn_put_conf (piMfNo IN manifests.manifest_no%TYPE)
RETURN NUMBER IS
  rwTypTrans    trans%ROWTYPE := NULL;
  iStatus       NUMBER := C_NORMAL;
  CURSOR c_get_not_put IS
    SELECT pt.rowid, pt.prod_id, pt.cust_pref_vendor, pt.dest_loc, pt.pallet_id,
           pt.lot_id, pt.weight, pt.exp_date,
           pt.temp, pt.orig_invoice, pt.qty, pt.uom, l.perm
    FROM putawaylst pt, loc l
    WHERE pt.rec_id = 'S' || TO_CHAR(piMfNo)
    AND   pt.putaway_put = 'N'
    AND   pt.reason_code NOT IN (SELECT reason_cd
                                 FROM reason_cds
                                 WHERE reason_cd_type = 'RTN'
                                 AND   reason_group IN ('OVR', 'OVI'))
    AND   pt.dest_loc = l.logi_loc;
BEGIN
  -- Create PUT transactions. Update inventory if available
  FOR cgnp IN c_get_not_put LOOP
    rwTypTrans := NULL;
    rwTypTrans.rec_id := 'S' || TO_CHAR(piMfNo);
    rwTypTrans.prod_id := cgnp.prod_id;
    rwTypTrans.cust_pref_vendor := cgnp.cust_pref_vendor;
    rwTypTrans.dest_loc := cgnp.dest_loc;
    rwTypTrans.pallet_id := cgnp.pallet_id;
    rwTypTrans.weight := cgnp.weight;
    rwTypTrans.temp := cgnp.temp;
    --rwTypTrans.exp_date := cgnp.exp_date;
    rwTypTrans.exp_date := f_get_rtn_date(cgnp.dest_loc);
    rwTypTrans.lot_id := cgnp.orig_invoice;
    rwTypTrans.order_id := cgnp.lot_id;
    rwTypTrans.qty := cgnp.qty;
    rwTypTrans.uom := cgnp.uom;
    rwTypTrans.batch_no := '99';
    iStatus := pl_common.f_create_trans('PUT');
    EXIT WHEN iStatus <> C_NORMAL;
    BEGIN
      UPDATE inv
        SET qoh = qoh + cgnp.qty, qty_planned = qty_planned - cgnp.qty
        WHERE prod_id = cgnp.prod_id
        AND   cust_pref_vendor = cgnp.cust_pref_vendor
        AND   plogi_loc = cgnp.dest_loc
        AND   (((cgnp.perm = 'Y') AND
                (logi_loc = cgnp.dest_loc) AND
                (qoh + cgnp.qty >= 0)) OR
               ((cgnp.perm <> 'Y') AND
                (logi_loc = cgnp.pallet_id) AND
                (qty_planned - cgnp.qty >= 0)));
      BEGIN
        DELETE inv
          WHERE prod_id = cgnp.prod_id
          AND   cust_pref_vendor = cgnp.cust_pref_vendor
          AND   plogi_loc = cgnp.dest_loc
          AND   NVL(cgnp.perm, 'N') = 'N'
          AND   qoh = 0
          AND   qty_planned = 0
          AND   qty_alloc = 0;
      EXCEPTION
        WHEN NO_DATA_FOUND THEN
          NULL;
        WHEN OTHERS THEN
          iStatus := SQLCODE;
          EXIT;
      END;
    EXCEPTION
      WHEN NO_DATA_FOUND THEN
        NULL;
      WHEN OTHERS THEN
        iStatus := SQLCODE;
        EXIT;
    END;
    BEGIN
      UPDATE putawaylst
        SET putaway_put = 'Y'
        WHERE rowid = cgnp.rowid;
    EXCEPTION
      WHEN OTHERS THEN
        iStatus := SQLCODE;
        EXIT;
    END;
    --
    --  02/07/06  prphqb   For close manifest, if syspar RTN_PUTAWAY_CONF = N then   
    --                     during confirming PUT transaction, we need to add code to 
    --                     write ExpectedReceipt to mini loader.
    --
    -- If dest loc is induction, send ExpectedReceipt transaction to mini loader
    --
    DECLARE
        r_exp_rcv pl_miniload_processing.t_exp_receipt_info;
    BEGIN
      IF (iStatus = C_NORMAL AND
          pl_ml_common.f_is_induction_loc(cgnp.dest_loc) = 'Y') THEN
        r_exp_rcv.v_expected_receipt_id := cgnp.pallet_id;
        r_exp_rcv.v_prod_id             := cgnp.prod_id;
        r_exp_rcv.v_cust_pref_vendor    := cgnp.cust_pref_vendor;
        r_exp_rcv.n_uom                 := cgnp.uom;
        IF (cgnp.uom = 0) THEN
            r_exp_rcv.n_uom             := 2;
        END IF;
        r_exp_rcv.n_qty_expected        := cgnp.qty;
        r_exp_rcv.v_inv_date            := '01-JAN-2001';

        pl_log.ins_msg('I', 'pl_dci', 'Create ExpectedReceipt for LP: '||
                       r_exp_rcv.v_expected_receipt_id,0,0);
        pl_miniload_processing.p_send_exp_receipt (r_exp_rcv, iStatus);

        IF (iStatus = pl_miniload_processing.ct_er_duplicate) THEN
            iStatus := pl_miniload_processing.ct_success;
        END IF;
       END IF;
    EXCEPTION
       WHEN OTHERS THEN
            iStatus := SQLCODE;
            EXIT;
    END;

  END LOOP;

  RETURN iStatus;
END;
-- -----------------------------------------------------------------------------

-- =============================================================================
-- Function
--   assign_to_caller
--
-- Description
--   The function assigns each individual fields from the table of returns
--   information (tabTypReturns type) to a character string. If the field is an
--   numeric field, '0's will be filled in the front of the string (except for
--   catchweight and temperature fields which will be treated as strings). If
--   the field is string type, blanks will be padded at the end of the string.
--
-- Parameters
--   ptabTypRtns (input)
--     Table of tabTypReturns (returns information) to be converted to a string.
--   poszRtns (output)
--     String to be output to match table of returns information or NULL.
--
-- Returns
--   See output parameters above
--
-- Modification History
-- Date      User   Defect  Comment
--
PROCEDURE assign_to_caller (
  ptabTypRtns   IN  tabTypReturns,
  poszRtns  OUT VARCHAR2) IS
  iIndex    NUMBER := 0;
BEGIN
  poszRtns := NULL;
  FOR iIndex IN 1 .. ptabTypRtns.COUNT LOOP
    poszRtns := poszRtns ||
                RPAD(ptabTypRtns(iIndex).manifest_no, C_MF_NO_LEN);
    poszRtns := poszRtns ||
                RPAD(NVL(ptabTypRtns(iIndex).route_no, ' '), C_ROUTE_NO_LEN);
    poszRtns := poszRtns ||
                RPAD(NVL(TO_CHAR(ptabTypRtns(iIndex).stop_no), ' '),
                     C_STOP_NO_LEN);
    poszRtns := poszRtns ||
                RPAD(ptabTypRtns(iIndex).obligation_no, C_INV_NO_LEN);
    poszRtns := poszRtns || RPAD(ptabTypRtns(iIndex).prod_id, C_PROD_ID_LEN);
    poszRtns := poszRtns ||
                RPAD(ptabTypRtns(iIndex).cust_pref_vendor, C_CPV_LEN);
    poszRtns := poszRtns ||
                RPAD(ptabTypRtns(iIndex).reason_code, C_REASON_LEN);
    poszRtns := poszRtns ||
                LPAD(NVL(TO_CHAR(ptabTypRtns(iIndex).returned_qty), '0'),
                     C_QTY_LEN, '0');
    poszRtns := poszRtns ||
                RPAD(ptabTypRtns(iIndex).returned_split_cd, C_UOM_LEN);
    poszRtns := poszRtns ||
                LPAD(NVL(TO_CHAR(ptabTypRtns(iIndex).weight), '0'),
                     C_WEIGHT_LEN, '0');
    poszRtns := poszRtns ||
                RPAD(NVL(ptabTypRtns(iIndex).disposition, ' '), C_REASON_LEN);
    poszRtns := poszRtns ||
                RPAD(NVL(ptabTypRtns(iIndex).returned_prod_id, ' '),
                     C_PROD_ID_LEN);
    poszRtns := poszRtns ||
                LPAD(TO_CHAR(ptabTypRtns(iIndex).erm_line_id),
                     C_LINE_ID_LEN, '0');
    poszRtns := poszRtns ||
                LPAD(NVL(TO_CHAR(ptabTypRtns(iIndex).shipped_qty), '0'),
                     C_QTY_LEN, '0');
    poszRtns := poszRtns ||
                RPAD(NVL(ptabTypRtns(iIndex).shipped_split_cd, '0'), C_UOM_LEN);
    poszRtns := poszRtns ||
                RPAD(NVL(ptabTypRtns(iIndex).cust_id, ' '), C_CUST_ID_LEN);
    poszRtns := poszRtns ||
                LPAD(NVL(TO_CHAR(ptabTypRtns(iIndex).temp), '0'),
                     C_TEMP_LEN, '0');
    poszRtns := poszRtns ||
                RPAD(NVL(ptabTypRtns(iIndex).catch_wt_trk, 'N'), C_ONECHAR_LEN);
    poszRtns := poszRtns ||
                RPAD(NVL(ptabTypRtns(iIndex).temp_trk, 'N'), C_ONECHAR_LEN);
    poszRtns := poszRtns ||
                RPAD(NVL(ptabTypRtns(iIndex).orig_invoice, ' '), C_INV_NO_LEN);
    poszRtns := poszRtns ||
                RPAD(NVL(ptabTypRtns(iIndex).dest_loc, ' '), C_LOC_LEN);
    poszRtns := poszRtns ||
                RPAD(NVL(ptabTypRtns(iIndex).pallet_id, ' '), C_PALLET_ID_LEN);
    poszRtns := poszRtns ||
                RPAD(NVL(ptabTypRtns(iIndex).rtn_label_printed, 'N'),
                     C_ONECHAR_LEN);
    poszRtns := poszRtns ||
                RPAD(NVL(ptabTypRtns(iIndex).pallet_batch_no, ' '),
                     C_BATCH_NO_LEN);
    poszRtns := poszRtns ||
                RPAD(NVL(ptabTypRtns(iIndex).parent_pallet_id, ' '),
                     C_PALLET_ID_LEN);
    poszRtns := poszRtns ||
                LPAD(NVL(TO_CHAR(ptabTypRtns(iIndex).ti), '0'),
                     C_TIHI_LEN, '0');
    poszRtns := poszRtns ||
                LPAD(NVL(TO_CHAR(ptabTypRtns(iIndex).hi), '0'),
                     C_TIHI_LEN, '0');
    poszRtns := poszRtns || RPAD(ptabTypRtns(iIndex).descrip, C_DESCRIP_LEN);
  END LOOP;
END;
-- -----------------------------------------------------------------------------

-- *********************** <Public Functions/Procedures> ***********************

FUNCTION get_syspars
RETURN recTypSyspar IS
  rcTypSyspar       recTypSyspar := NULL;
BEGIN
  rcTypSyspar.rtn_data_collection :=
    pl_common.f_get_syspar('RTN_DATA_COLLECTION', 'N');
  rcTypSyspar.lbr_mgmt_flag :=
    pl_common.f_get_syspar('LBR_MGMT_FLAG', 'N');
  rcTypSyspar.upd_item_ptype_return :=
    pl_common.f_get_syspar('UPD_ITEM_PTYPE_RETURN', 'N');
  rcTypSyspar.cc_gen_exc_reserve :=
    pl_common.f_get_syspar('CC_GEN_EXC_RESERVE', 'N');
  rcTypSyspar.rtn_putaway_conf :=
    pl_common.f_get_syspar('RTN_PUTAWAY_CONF', 'N');
  rcTypSyspar.pct_tolerance :=
    pl_common.f_get_syspar('PCT_TOLERANCE', '100');
  rcTypSyspar.rtn_bfr_mfc :=
    pl_common.f_get_syspar('RTN_BFR_MFC', 'N');
  rcTypSyspar.enable_acc_trk_flag :=
    pl_common.f_get_syspar('ENABLE_TRK_ACCESSORY_TRACK', 'N');
  rcTypSyspar.host_type :=
    pl_common.f_get_syspar('HOST_TYPE', 'AS400');

  BEGIN
    SELECT NVL(create_batch_flag, 'N') INTO rcTypSyspar.create_batch_flag
    FROM lbr_func
    WHERE lfun_lbr_func = 'RP';
  EXCEPTION
    WHEN OTHERS THEN
      rcTypSyspar.create_batch_flag := 'N';
  END;
  RETURN rcTypSyspar;
END;
-- -----------------------------------------------------------------------------

FUNCTION get_reason_info (
  pszWhat       IN reason_cds.reason_cd_type%TYPE DEFAULT 'ALL',
  pszRsnGroup   IN reason_cds.reason_group%TYPE DEFAULT 'ALL',
  pszRsn        IN reason_cds.reason_cd%TYPE DEFAULT NULL)
RETURN tabTypReasons IS
  tabTypRsns    tabTypReasons;
  iIndex    NUMBER := 0;
  CURSOR c_get_reason IS
    SELECT reason_group, reason_cd, reason_desc, misc, cc_reason_code
    FROM reason_cds
    WHERE (((pszWhat = 'ALL') AND (reason_cd_type IN ('RTN', 'DIS'))) OR
           (reason_cd_type = pszWhat))
    AND   ((pszRsnGroup = 'ALL') OR
           ((pszRsnGroup <> 'ALL') AND (reason_group = pszRsnGroup)))
    AND   ((pszRsn IS NULL) OR
           ((pszRsn IS NOT NULL) AND (reason_cd = pszRsn)));
BEGIN
--DBMS_OUTPUT.PUT_LINE('What: ' || pszWhat || ', g: ' || pszRsnGroup ||
--  ', r: ' || pszRsn);
  FOR cgr IN c_get_reason LOOP
--  DBMS_OUTPUT.PUT_LINE('g: ' || cgr.reason_group || ', r: ' || cgr.reason_cd);
    iIndex := iIndex + 1;
    tabTypRsns(iIndex).reason_group := cgr.reason_group;
    tabTypRsns(iIndex).reason_cd := cgr.reason_cd;
    tabTypRsns(iIndex).reason_desc := cgr.reason_desc;
    tabTypRsns(iIndex).misc := cgr.misc;
    tabTypRsns(iIndex).cc_reason_code := cgr.cc_reason_code;
  END LOOP;
--DBMS_OUTPUT.PUT_LINE('# of reasons returned: ' || TO_CHAR(tabTypRsns.COUNT));
  RETURN tabTypRsns;
EXCEPTION
  WHEN OTHERS THEN
    DBMS_OUTPUT.PUT_LINE(SQLERRM);
    RAISE_APPLICATION_ERROR(-20001, 'Error getting reason infos');
END;
-- -----------------------------------------------------------------------------

FUNCTION get_order_line (
  ps_prod_id		pm.prod_id%TYPE,
  ps_cpv		pm.cust_pref_vendor%TYPE,
  pi_uom		ordd.uom%TYPE,
  ps_inv		ordd.order_id%TYPE,
  ps_org_inv		ordd.order_id%TYPE DEFAULT NULL)
RETURN NUMBER IS
  iOrderLineID		NUMBER := NULL;
  iOtherUom		NUMBER := NULL;
  CURSOR c_get_ordd_line(
      cpsProd    pm.prod_id%TYPE,
      cpsCpv     pm.cust_pref_vendor%TYPE,
      cpsRtnInv  returns.obligation_no%TYPE,
      cpsOrgInv  returns.obligation_no%TYPE,
      cpsUom     returns.returned_split_cd%TYPE) IS
    SELECT d.order_line_id
    FROM   ordd d
    WHERE  d.prod_id = cpsProd
    AND    d.cust_pref_vendor = cpsCpv
    AND    d.order_id IN (cpsOrgInv, cpsRtnInv)
    AND    DECODE(d.uom, 2, 0, d.uom) = TO_NUMBER(cpsUom)
    ORDER BY d.order_line_id;
  CURSOR c_get_ordd_for_rtn_line(
      cpsProd    pm.prod_id%TYPE,
      cpsCpv     pm.cust_pref_vendor%TYPE,
      cpsRtnInv  returns.obligation_no%TYPE,
      cpsOrgInv  returns.obligation_no%TYPE,
      cpsUom     returns.returned_split_cd%TYPE) IS
    SELECT d.order_line_id
    FROM   ordd_for_rtn d
    WHERE  d.prod_id = cpsProd
    AND    d.cust_pref_vendor = cpsCpv
    AND    d.order_id IN (cpsOrgInv, cpsRtnInv)
    AND    ((cpsUom IS NULL) OR
            ((cpsUom IS NOT NULL) AND (d.uom = TO_NUMBER(cpsUom))))
    ORDER BY d.order_line_id;
  CURSOR c_get_fh_data (
    cp_prod_id pm.prod_id%TYPE,                                       
    cp_cpv pm.cust_pref_vendor%TYPE,                                  
    cp_uom float_hist.uom%TYPE,                                       
    cp_inv float_hist_errors.order_id%TYPE,                           
    cp_orig_inv float_hist_errors.order_id%TYPE) IS                   
  SELECT order_line_id
  FROM float_hist
  WHERE order_id IN (cp_inv, cp_orig_inv)
  AND   prod_id = cp_prod_id
  AND   cust_pref_vendor = cp_cpv
  -- Try only the real line ID
  AND   NVL(order_line_id, 0) < 900
  AND   ((cp_uom IS NULL) OR
         ((cp_uom IS NOT NULL) AND                                    
          (DECODE(uom, 2, 0, uom) = (DECODE(cp_uom, 2, 0, cp_uom)))));
BEGIN
  iOrderLineID := NULL; -- =0 is really bad

  -- Try current order first
  OPEN c_get_ordd_line(ps_prod_id, ps_cpv,
                       ps_inv, ps_org_inv, pi_uom);
  FETCH c_get_ordd_line INTO iOrderLineID;
  IF c_get_ordd_line%NOTFOUND THEN
    -- Try saved order (for return used) next
    OPEN c_get_ordd_for_rtn_line(ps_prod_id, ps_cpv,
                                 ps_inv, ps_org_inv,
                                 pi_uom);
    FETCH c_get_ordd_for_rtn_line INTO iOrderLineID;
    IF c_get_ordd_for_rtn_line%NOTFOUND THEN
      CLOSE c_get_ordd_for_rtn_line;
      CLOSE c_get_ordd_line;
      -- Cannot find any data. Try whatever available uom from current order
      OPEN c_get_ordd_line(ps_prod_id, ps_cpv,
                           ps_inv, ps_org_inv, NULL);
      FETCH c_get_ordd_line INTO iOrderLineID;
      IF c_get_ordd_line%NOTFOUND THEN
        CLOSE c_get_ordd_line;
        -- Still cannot find any data. Try whatever available uom from saved
        -- order (for return)
        OPEN c_get_ordd_for_rtn_line(ps_prod_id, ps_cpv,
                                     ps_inv, ps_org_inv, NULL);
        FETCH c_get_ordd_for_rtn_line INTO iOrderLineID;
        IF c_get_ordd_for_rtn_line%NOTFOUND THEN
          iOrderLineID := NULL;
        END IF;
      END IF;
    END IF;
    IF c_get_ordd_for_rtn_line%ISOPEN THEN
      CLOSE c_get_ordd_for_rtn_line;              
    END IF;
  END IF;
  IF c_get_ordd_line%ISOPEN THEN
    CLOSE c_get_ordd_line;              
  END IF;

  IF iOrderLineID IS NULL THEN
    -- Cannot find in current and saved order. Try if it has done from SOS
    -- picked history
    FOR cgfhd IN c_get_fh_data (ps_prod_id, ps_cpv,
                                pi_uom, ps_inv, ps_org_inv) LOOP
      iOrderLineID := cgfhd.order_line_id;
    END LOOP;
    iOtherUom := NULL;
    IF iOrderLineID IS NULL THEN
      SELECT DECODE(pi_uom, 0, 1, 2, 1, 0) INTO iOtherUom
      FROM DUAL;
      -- Still cannot find from SOS picked history for checked uom. Try
      -- the opposite uom
      FOR cgfhd IN c_get_fh_data (ps_prod_id, ps_cpv,
                                  iOtherUom, ps_inv, ps_org_inv) LOOP
        iOrderLineID := cgfhd.order_line_id;
      END LOOP;
    END IF;
  END IF;

  RETURN iOrderLineID;
END;
-- -----------------------------------------------------------------------------

PROCEDURE get_client_reason_info (
  poiNumRsns    OUT NUMBER,
  poszRsns      OUT VARCHAR2,
  pszWhat       IN  reason_cds.reason_cd_type%TYPE DEFAULT 'ALL',
  pszRsnGroup   IN  reason_cds.reason_group%TYPE DEFAULT 'ALL',
  pszRsn        IN  reason_cds.reason_cd%TYPE DEFAULT NULL) IS
  tabTypRsns        tabTypReasons;
  iIndex        NUMBER;
BEGIN
  poiNumRsns := 0;
  poszRsns := NULL;

  tabTypRsns := get_reason_info(pszWhat, pszRsnGroup, pszRsn);
  IF tabTypRsns.COUNT = 0 THEN
    RETURN;
  END IF;

  poiNumRsns := tabTypRsns.COUNT;
  FOR iIndex IN 1 .. tabTypRsns.COUNT LOOP
    poszRsns := poszRsns ||
                RPAD(tabTypRsns(iIndex).reason_cd, C_REASON_LEN, ' ') ||
                RPAD(SUBSTR(tabTypRsns(iIndex).reason_desc,
                            1, C_DESCRIP_LEN / 2), C_DESCRIP_LEN / 2, ' ') ||
                RPAD(NVL(tabTypRsns(iIndex).reason_group, '|'),
            C_REASON_GROUP_LEN, '|');
  END LOOP;
  poszRsns := REPLACE(poszRsns, '|||', '   ');
EXCEPTION
  WHEN OTHERS THEN
    RAISE_APPLICATION_ERROR(-20001, 'Error getting reason infos for client');
END;
-- -----------------------------------------------------------------------------

PROCEDURE get_mf_status (
  piNum         IN  NUMBER,
  poszRoute     OUT manifests.route_no%TYPE,
  poszStatus        OUT VARCHAR2) IS
  szStatus      manifests.manifest_status%TYPE := NULL;
  szRoute       manifests.route_no%TYPE := NULL;
BEGIN
  poszRoute := NULL;
  poszStatus := NULL;

  -- Treat the input number as manifest # first
  SELECT manifest_status, route_no INTO szStatus, szRoute
  FROM manifests
  WHERE manifest_no = piNum;
  poszRoute := szRoute;
  poszStatus := szStatus;
EXCEPTION
  WHEN NO_DATA_FOUND THEN
    -- Cannot find the manifest. Try the input number as order seq #. Search
    -- the order sequence # either from ORDD_FOR_RTN or ORDD table
    BEGIN
      SELECT m.manifest_status, m.route_no INTO szStatus, szRoute
      FROM manifests m
      WHERE EXISTS (SELECT 1
                    FROM ordd_for_rtn o, manifest_dtls d
                    WHERE ((o.order_id = DECODE(INSTR(d.obligation_no, 'L'),
                                                0, d.obligation_no,
                                                SUBSTR(d.obligation_no, 1,
                                                       INSTR(d.obligation_no,
                                                             'L') - 1))) OR
                           (o.order_id = DECODE(INSTR(d.orig_invoice, 'L'),
                                                0, d.orig_invoice,
                                                SUBSTR(d.orig_invoice, 1,
                                                       INSTR(d.orig_invoice,
                                                             'L') - 1))))
                    AND   d.manifest_no = m.manifest_no
                    AND   d.prod_id = o.prod_id
                    AND   d.cust_pref_vendor = o.cust_pref_vendor
                    AND   o.ordd_seq = piNum)
      OR    EXISTS (SELECT 1
                    FROM ordd o, ordm r, manifest_dtls d
                    WHERE ((o.order_id = DECODE(INSTR(d.obligation_no, 'L'),
                                                0, d.obligation_no,
                                                SUBSTR(d.obligation_no, 1,
                                                       INSTR(d.obligation_no,
                                                             'L') - 1))) OR
                           (o.order_id = DECODE(INSTR(d.orig_invoice, 'L'),
                                                0, d.orig_invoice,
                                                SUBSTR(d.orig_invoice, 1,
                                                       INSTR(d.orig_invoice,
                                                             'L') - 1))))
                    AND   ((r.order_id = o.order_id) OR
                           (r.order_id = o.order_id))
                    AND   o.order_id = r.order_id
                    AND   r.status = 'CLO'
                    AND   d.manifest_no = m.manifest_no
                    AND   d.prod_id = o.prod_id
                    AND   d.cust_pref_vendor = o.cust_pref_vendor
                    AND   o.seq = piNum);
      poszRoute := szRoute;
      poszStatus := szStatus;
    EXCEPTION
      WHEN NO_DATA_FOUND THEN
        poszStatus := TO_CHAR(C_INV_MF);
      WHEN OTHERS THEN
        poszStatus := TO_CHAR(SQLCODE);
    END;
  WHEN OTHERS THEN
    poszStatus := TO_CHAR(SQLCODE);
END;
-- -----------------------------------------------------------------------------

PROCEDURE get_mf_status (
  pszSearch     IN  putawaylst.pallet_id%TYPE,
  poszOutInv        OUT manifest_dtls.obligation_no%TYPE,
  poszOutOrigInv    OUT manifest_dtls.orig_invoice%TYPE,
  piMfNo        OUT manifests.manifest_no%TYPE,
  poszRecType       OUT manifest_dtls.rec_type%TYPE,
  poszRoute     OUT manifests.route_no%TYPE,
  poszStatus        OUT VARCHAR2,
  piAsLP        IN  NUMBER DEFAULT 0) IS
  iMfNo         manifests.manifest_no%TYPE := NULL;
  szStatus      manifests.manifest_status%TYPE := NULL;
  szInv         manifest_dtls.obligation_no%TYPE := NULL;
  szOrigInv     manifest_dtls.orig_invoice%TYPE := NULL;
  szRecType     manifest_dtls.rec_type%TYPE := NULL;
  szRoute       manifests.route_no%TYPE := NULL;
  szSearch      putawaylst.pallet_id%TYPE := pszSearch;
BEGIN
  poszOutInv := NULL;
  poszOutOrigInv := NULL;
  piMfNo := NULL;
  poszRecType := NULL;
  poszRoute := NULL;
  poszStatus := NULL;
  DBMS_OUTPUT.PUT_LINE('Inside Get_Mf_Status. Obligation = ' || pszSearch);

  IF piAsLP <> 0 THEN
    -- The input will be treated as a license plate
    BEGIN
      SELECT lot_id INTO szSearch
      FROM putawaylst
      WHERE pallet_id = pszSearch;
    EXCEPTION
      WHEN NO_DATA_FOUND THEN
        poszStatus := TO_CHAR(C_INV_LABEL);
      WHEN OTHERS THEN
        poszStatus := TO_CHAR(SQLCODE);
    END;
  END IF;
  DBMS_OUTPUT.PUT_LINE('After checking input as LP: ' || szSearch);

  SELECT m.manifest_no, m.manifest_status, m.route_no,
         DECODE(INSTR(d.obligation_no, 'L'), 0, d.obligation_no,
                SUBSTR(d.obligation_no, 1, INSTR(d.obligation_no, 'L') - 1)),
         DECODE(INSTR(d.orig_invoice, 'L'), 0, d.orig_invoice,
                SUBSTR(d.orig_invoice, 1, INSTR(d.orig_invoice, 'L') - 1)),
         d.rec_type
  INTO iMfNo, szStatus, szRoute, szInv, szOrigInv, szRecType
  FROM manifests m, manifest_dtls d
  WHERE m.manifest_no = d.manifest_no
  AND   ((DECODE(INSTR(d.obligation_no, 'L'),
                 0, d.obligation_no,
                 SUBSTR(d.obligation_no, 1, INSTR(d.obligation_no, 'L') - 1)) =
            szSearch) OR
         (DECODE(INSTR(d.orig_invoice, 'L'),
                 0, d.orig_invoice,
                 SUBSTR(d.orig_invoice, 1, INSTR(d.orig_invoice, 'L') - 1)) =
            szSearch)) 
  AND   ROWNUM = 1;
  poszOutInv := szInv;
  poszOutOrigInv := szOrigInv;
  piMfNo := iMfNo;
  poszRecType := szRecType;
  poszRoute := szRoute;
  poszStatus := szStatus;
EXCEPTION
  WHEN NO_DATA_FOUND THEN
    poszStatus := TO_CHAR(C_INV_MF);
  WHEN OTHERS THEN
    poszStatus := TO_CHAR(SQLCODE);
END;
-- -----------------------------------------------------------------------------

PROCEDURE get_mf_info(
  piMfNo        IN  returns.manifest_no%TYPE,
  pRwTypMfHdr       OUT manifests%ROWTYPE) IS
  rwTypMfHdr        manifests%ROWTYPE := NULL;
BEGIN
  pRwTypMfHdr := NULL;

  BEGIN
    SELECT manifest_no, manifest_create_dt, manifest_status, route_no,
           truck_no
    INTO rwTypMfHdr.manifest_no, rwTypMfHdr.manifest_create_dt,
         rwTypMfHdr.manifest_status, rwTypMfHdr.route_no, rwTypMfHdr.truck_no
    FROM manifests
    WHERE manifest_no = piMfNo;
    pRwTypMfHdr := rwTypMfHdr;
  EXCEPTION
    WHEN OTHERS THEN
      pRwTypMfHdr := NULL;
  END;
END;
-- -----------------------------------------------------------------------------

PROCEDURE get_mf_info(
  pRwTypRtn     IN  returns%ROWTYPE,
  pRwTypMfHdr   OUT manifests%ROWTYPE,
  pRwTypMfDtls  OUT manifest_dtls%ROWTYPE,
  piShipInCases OUT NUMBER) IS
  rwTypMfHdr        manifests%ROWTYPE := NULL;
  rwTypMfDtls       manifest_dtls%ROWTYPE := NULL;
  iShipQty      NUMBER := 0;
  CURSOR c_get_mf_dtls(cp_uom returns.returned_split_cd%TYPE) IS
    SELECT d.manifest_no, d.stop_no, d.rec_type,
           DECODE(INSTR(d.obligation_no, 'L'), 0, d.obligation_no,
                  SUBSTR(d.obligation_no,
                         1, INSTR(d.obligation_no, 'L') - 1)) obligation_no,
           d.prod_id, d.cust_pref_vendor,
           d.shipped_qty, d.shipped_split_cd,
           d.manifest_dtl_status, d.orig_invoice,
           d.shipped_qty /
           DECODE(d.shipped_split_cd, '1', p.spc, 1)
    FROM manifest_dtls d, pm p
    WHERE d.manifest_no = pRwTypRtn.manifest_no
    AND   DECODE(INSTR(d.obligation_no, 'L'), 0, d.obligation_no,
                 SUBSTR(d.obligation_no, 1, INSTR(d.obligation_no, 'L') - 1)) =
          pRwTypRtn.obligation_no
    AND   d.rec_type = pRwTypRtn.rec_type
    AND   d.prod_id = pRwTypRtn.prod_id
    AND   d.cust_pref_vendor = pRwTypRtn.cust_pref_vendor
    AND   d.prod_id = p.prod_id
    AND   d.cust_pref_vendor = p.cust_pref_vendor
    AND   ((cp_uom IS NULL) OR
           ((cp_uom IS NOT NULL) AND (d.shipped_split_cd = cp_uom))); 
BEGIN
  pRwTypMfHdr := NULL;
  pRwTypMfDtls := NULL;
  piShipInCases := 0;

  -- Retrieve manifest header info according to the manifest #
  get_mf_info(pRwTypRtn.manifest_no, rwTypMfHdr);

  -- Retrieve manifest detail info according to return information. Search
  -- on the same uom as from returns first and then the opposite uom if it's
  -- not found
  OPEN c_get_mf_dtls(pRwTypRtn.returned_split_cd);
  FETCH c_get_mf_dtls
    INTO rwTypMfDtls.manifest_no, rwTypMfDtls.stop_no, rwTypMfDtls.rec_type,
         rwTypMfDtls.obligation_no, rwTypMfDtls.prod_id,
         rwTypMfDtls.cust_pref_vendor, rwTypMfDtls.shipped_qty,
         rwTypMfDtls.shipped_split_cd, rwTypMfDtls.manifest_dtl_status,
         rwTypMfDtls.orig_invoice, iShipQty;
  IF c_get_mf_dtls%NOTFOUND THEN
    -- Cannot find info. Try not using uom since ship and returned uom might be
    -- different
    CLOSE c_get_mf_dtls;
    OPEN c_get_mf_dtls(NULL);
    FETCH c_get_mf_dtls
      INTO rwTypMfDtls.manifest_no, rwTypMfDtls.stop_no, rwTypMfDtls.rec_type,
           rwTypMfDtls.obligation_no, rwTypMfDtls.prod_id,
           rwTypMfDtls.cust_pref_vendor, rwTypMfDtls.shipped_qty,
           rwTypMfDtls.shipped_split_cd, rwTypMfDtls.manifest_dtl_status,
           rwTypMfDtls.orig_invoice, iShipQty;
    IF c_get_mf_dtls%NOTFOUND THEN
      rwTypMfDtls := NULL;
      iShipQty := 0;
    END IF;
  END IF;
  IF c_get_mf_dtls%ISOPEN THEN
    CLOSE c_get_mf_dtls;
  END IF;

  pRwTypMfHdr := rwTypMfHdr;
  pRwTypMfDtls := rwTypMfDtls;
  piShipInCases := iShipQty;
END;
-- -----------------------------------------------------------------------------

FUNCTION check_putaway (
  pszRsnGroup       IN  reason_cds.reason_group%TYPE,
  pRwTypRtn     IN  returns%ROWTYPE)
RETURN putawaylst%ROWTYPE IS
  rwTypPutlst       putawaylst%ROWTYPE := NULL;
BEGIN
  -- Check if the putaway task exists or has been putawayed or not
  BEGIN
    SELECT pallet_id, rec_id, prod_id, dest_loc, qty, uom, lot_id, weight,
           temp, catch_wt, temp_trk, putaway_put, cust_pref_vendor,
           erm_line_id, reason_code, orig_invoice, pallet_batch_no,
           rtn_label_printed, parent_pallet_id
    INTO rwTypPutlst.pallet_id, rwTypPutlst.rec_id, rwTypPutlst.prod_id,
         rwTypPutlst.dest_loc, rwTypPutlst.qty, rwTypPutlst.uom,
         rwTypPutlst.lot_id, rwTypPutlst.weight, rwTypPutlst.temp,
         rwTypPutlst.catch_wt, rwTypPutlst.temp_trk, rwTypPutlst.putaway_put,
         rwTypPutlst.cust_pref_vendor, rwTypPutlst.erm_line_id,
         rwTypPutlst.reason_code, rwTypPutlst.orig_invoice,
         rwTypPutlst.pallet_batch_no, rwTypPutlst.rtn_label_printed,
         rwTypPutlst.parent_pallet_id
    FROM putawaylst
    WHERE rec_id = DECODE(pszRsnGroup, 'DMG', 'D', 'S') ||
                   TO_CHAR(pRwTypRtn.manifest_no)
    AND   erm_line_id = pRwTypRtn.erm_line_id;
    rwTypPutlst.putpath := C_NORMAL;
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      rwTypPutlst.putaway_put := 'X';
      rwTypPutlst.putpath := SQLCODE;
    WHEN OTHERS THEN
      rwTypPutlst.putaway_put := 'O';
      rwTypPutlst.putpath := SQLCODE;
  END;
  RETURN rwTypPutlst;
END;
-- -----------------------------------------------------------------------------

PROCEDURE get_range_returns (
  piNextRecSet      IN  NUMBER,
  pszSearch     IN  putawaylst.pallet_id%TYPE,
  poiNumRtns        OUT NUMBER,
  poiNumCurRtns     OUT NUMBER,
  poiNumWeightRtns  OUT NUMBER,
  poiNumTempRtns    OUT NUMBER,
  potabTypReturns   OUT tabTypReturns,
  piAllRtns     IN  NUMBER DEFAULT 0,
  pszValue1     IN  pm.external_upc%TYPE DEFAULT NULL,
  pszValue2     IN  pm.cust_pref_vendor%TYPE DEFAULT C_DFT_CPV,
  piValue3      IN  returns.erm_line_id%TYPE DEFAULT NULL,
  piRecTyp      IN  NUMBER DEFAULT 0,
  pszType       IN  VARCHAR2 DEFAULT 'ALL',
  piMinLine     IN  returns.erm_line_id%TYPE DEFAULT 1,
  piMaxLine     IN  returns.erm_line_id%TYPE DEFAULT 9999 ) IS

  szSearch1     putawaylst.pallet_id%TYPE := NULL;
  szSearch2     pm.external_upc%TYPE := NULL;
  szSearch3     pm.cust_pref_vendor%TYPE := NULL;
  iSearch4      returns.erm_line_id%TYPE := NULL;
  szMfNo        putawaylst.rec_id%TYPE := NULL;
  iLine         putawaylst.erm_line_id%TYPE := NULL;
  rwTypPutlst       putawaylst%ROWTYPE := NULL;
  rwTypRtn      returns%ROWTYPE := NULL;
  iIndex        NUMBER := 0;
  iNumRtns      NUMBER := 0;
  iNumCurRtns       NUMBER := 0;
  iNumWeightRtns    NUMBER := 0;
  iNumTempRtns      NUMBER := 0;
  iSkidCube     NUMBER := 0;
  tabTypRtns        tabTypReturns;
  rwTypPm       pm%ROWTYPE := NULL;
  iStatus       NUMBER := C_NORMAL;
  iQty          NUMBER := 0;
  tabTypRsns        tabTypReasons;
  blnSkipLoop       BOOLEAN := FALSE;

  CURSOR c_get_rng_rtn_info (cpszSearch putawaylst.pallet_id%TYPE) IS
    SELECT r.manifest_no,
           DECODE(INSTR(r.obligation_no, 'L'), 0, r.obligation_no,
                 SUBSTR(r.obligation_no, 1,
                        INSTR(r.obligation_no, 'L') - 1)) obligation_no,
           r.prod_id, r.cust_pref_vendor, r.returned_prod_id, r.rec_type,
           r.return_reason_cd, r.returned_qty, r.returned_split_cd,
           r.catchweight, r.temperature, r.erm_line_id,
           r.disposition,
           r.route_no, r.stop_no, r.shipped_qty, r.shipped_split_cd, r.cust_id,
       DECODE(c.reason_group, 'STM', 1, 99) group_sort
    FROM returns r, reason_cds c
    WHERE (r.manifest_no = (SELECT SUBSTR(rec_id,2)  
                            FROM PUTAWAYLST 
                            WHERE pallet_id = cpszSearch) OR
            (r.manifest_no = TO_NUMBER(cpszSearch)) OR
           (DECODE(INSTR(r.obligation_no, 'L'), 0, r.obligation_no,
                   SUBSTR(r.obligation_no, 1,
                          INSTR(r.obligation_no, 'L') - 1)) = cpszSearch))
    AND   (((szSearch2 IS NULL) AND
             ((iSearch4 IS NULL) OR
              ((iSearch4 IS NOT NULL) AND (r.erm_line_id = iSearch4)))) OR
            ((szSearch2 IS NOT NULL) AND
             (r.prod_id = szSearch2) AND
             (r.cust_pref_vendor = szSearch3) AND
             ((iSearch4 IS NULL) OR
              ((iSearch4 IS NOT NULL) AND (r.erm_line_id = iSearch4)))))
    AND   ((pszType <> 'NOPUT') OR
           ((pszType = 'NOPUT') AND
            (r.return_reason_cd IN (
                                  SELECT reason_cd
                                  FROM reason_cds
                                  WHERE reason_group IN ('STM', 'MPK')))))
    AND   ((pszType = 'NOPUT') OR
           ((pszType <> 'NOPUT') AND
            EXISTS (SELECT 1
                    FROM putawaylst
                    WHERE rec_id LIKE '%' || TO_CHAR(r.manifest_no)
                    AND   NVL(lot_id, ' ') = NVL(r.obligation_no, ' ')
                    AND   prod_id = NVL(r.returned_prod_id, r.prod_id)
                    AND   cust_pref_vendor = r.cust_pref_vendor
                    AND   reason_code = r.return_reason_cd
                    AND   erm_line_id = r.erm_line_id
                    AND   NVL(rtn_label_printed, 'N') <> 'Y')))
    AND   c.reason_cd_type = 'RTN'
    AND   r.return_reason_cd (+) = c.reason_cd
    AND   (c.reason_group NOT IN ('MPR') OR
           (c.reason_group IN ('MPR') AND
            (r.returned_prod_id IS NOT NULL) AND
            (NVL(r.returned_qty, 0) > 0)))
    ORDER BY group_sort, r.erm_line_id;

BEGIN

  poiNumRtns := 0;
  poiNumCurRtns := 0;
  poiNumWeightRtns := 0;
  poiNumTempRtns := 0;

  DBMS_OUTPUT.PUT_LINE('Next record set: ' || TO_CHAR(piNextRecSet));
  DBMS_OUTPUT.PUT_LINE('Search str1: ' || pszSearch);
  pl_text_log.ins_msg('WARN', 'GetRangeRtn', 'Search str1: ' || pszSearch,
    NULL, NULL);
  DBMS_OUTPUT.PUT_LINE('Get all returns: ' || TO_CHAR(piAllRtns));
  pl_text_log.ins_msg('WARN', 'GetRangeRtn',
    'Get all returns[' || TO_CHAR(piAllRtns) || '] nextRecSet[' ||
    TO_CHAR(piNextRecSet) || ']',
    NULL, NULL);
  DBMS_OUTPUT.PUT_LINE('Search str2: ' || pszValue1);
  DBMS_OUTPUT.PUT_LINE('Search str3: ' || pszValue2);
  pl_text_log.ins_msg('WARN', 'GetRangeRtn',
    'Search str2[' || pszValue1 || '] 3[' || pszValue2 || ']',
    NULL, NULL);
  DBMS_OUTPUT.PUT_LINE('Input line: ' || TO_CHAR(piValue3));
  DBMS_OUTPUT.PUT_LINE('RecT[' || TO_CHAR(piRecTyp) || '] Type: ' || pszType);
  pl_text_log.ins_msg('WARN', 'GetRangeRtn',
    'Input line[' || TO_CHAR(piValue3) || '] ' || 'Type[' || pszType ||
    '] recT[' || TO_CHAR(piRecTyp) || ']', NULL, NULL);
  DBMS_OUTPUT.PUT_LINE('Min line: ' || TO_CHAR(piMinLine));
  DBMS_OUTPUT.PUT_LINE('Max line: ' || TO_CHAR(piMaxLine));
--  DBMS_OUTPUT.PUT_LINE('WithPutOnly: ' || TO_CHAR(piWithPutOnly));
--  pl_text_log.ins_msg('WARN', 'GetRangeRtn',
--  'Min line[' || TO_CHAR(piMinLine) || '] ' || 'Max[' ||
--  TO_CHAR(piMaxLine) || '] withPutOnly[' || TO_CHAR(piWithPutOnly) || ']',
--  NULL, NULL);
  pl_text_log.ins_msg('WARN', 'GetRangeRtn',
    'Min line[' || TO_CHAR(piMinLine) || '] ' || 'Max[' ||
    TO_CHAR(piMaxLine) || ']', NULL, NULL);

  szSearch1 := pszSearch;
  szSearch2 := pszValue1;
  szSearch3 := pszValue2;
  iSearch4 := piValue3;

  IF UPPER(pszValue1) = 'LP' THEN
    -- Treat pszSearch value as a license plate instead of manifest or invoice #
    BEGIN
      SELECT SUBSTR(rec_id, 2), erm_line_id INTO szMfNo, iLine
      FROM putawaylst
      WHERE pallet_id = szSearch1;
      szSearch1 := szMfNo;
      szSearch2 := NULL;
      szSearch3 := NULL;
      iSearch4 := iLine;
    EXCEPTION
      WHEN OTHERS THEN
        RETURN;
    END;
    DBMS_OUTPUT.PUT_LINE('Search from LP mf: ' || szSearch1 || ' ln: ' ||
      TO_CHAR(iSearch4));
    pl_text_log.ins_msg('WARN', 'GetRangeRtn',
    'Search from LP mf[' || szSearch1 || '] ln[' ||
    TO_CHAR(iSearch4) || ']', NULL, NULL);
  END IF;

  iIndex := 0;
  pl_text_log.ins_msg('WARN', 'GetRangeRtn', 'Before cursor...szSearch2: ' || szSearch2, NULL, NULL);  
  pl_text_log.ins_msg('WARN', 'GetRangeRtn', 'Before cursor...szSearch3: ' || szSearch3, NULL, NULL);

  FOR cgrri IN c_get_rng_rtn_info(szSearch1) LOOP

    -- Retrieve reason code info
    tabTypRsns := get_reason_info('RTN', 'ALL', cgrri.return_reason_cd);

    -- Set search value for other functions called
    rwTypRtn := NULL;
    rwTypRtn.manifest_no := cgrri.manifest_no;
    rwTypRtn.erm_line_id := cgrri.erm_line_id;

    -- Get putaway task info
    rwTypPutlst := NULL;
    IF tabTypRsns.COUNT > 0 THEN
      rwTypPutlst := check_putaway(tabTypRsns(1).reason_group, rwTypRtn);
    END IF;

    DBMS_OUTPUT.PUT_LINE('Loop ' ||
      TO_CHAR(iIndex) || '- mf: ' ||
      TO_CHAR(cgrri.manifest_no) || ' l: ' || TO_CHAR(cgrri.erm_line_id) ||
      ' o: ' || cgrri.obligation_no || ' p: ' || cgrri.prod_id || '/' ||
      cgrri.returned_prod_id || ' r: ' || cgrri.return_reason_cd || ' lo: ' ||
      rwTypPutlst.dest_loc || '/' || rwTypPutlst.pallet_id ||
      ' put[' || rwTypPutlst.putaway_put || '] recT[' || piRecTyp || '] ' ||
      'tempTrk[' || rwTypPutlst.temp_trk || '] wtTrk[' ||
      rwTypPutlst.catch_wt || '] labelPrinted[' ||
      rwTypPutlst.rtn_label_printed || ']');
    pl_text_log.ins_msg('WARN', 'GetRangeRtn', 'Loop ' ||
      TO_CHAR(iIndex) || '- mf: ' ||
      TO_CHAR(cgrri.manifest_no) || ' l: ' || TO_CHAR(cgrri.erm_line_id) ||
      ' o: ' || cgrri.obligation_no || ' p: ' || cgrri.prod_id || '/' ||
      cgrri.returned_prod_id || ' r: ' || cgrri.return_reason_cd || ' lo: ' ||
      rwTypPutlst.dest_loc || '/' || rwTypPutlst.pallet_id ||
      ' put[' || rwTypPutlst.putaway_put || '] recT[' || piRecTyp || '] ' ||
      'tempTrk[' || rwTypPutlst.temp_trk || '] wtTrk[' ||
      rwTypPutlst.catch_wt || '] labelPrinted[' ||
      rwTypPutlst.rtn_label_printed || ']',
      NULL, NULL);

    -- Accumulate total # of returns available for the search criteria,
    -- regardless whether any of the info in the return is valid or not
    blnSkipLoop := TRUE;
    IF (((piAllRtns = 0) AND (NVL(cgrri.returned_qty, 0) > 0)) OR
        (piAllRtns <> 0)) AND
       (((piAllRtns = 0) AND (rwTypPutlst.putaway_put IN ('N', 'X'))) OR
        (piAllRtns <> 0)) AND
       (((piAllRtns = 0) AND (tabTypRsns.COUNT > 0)) OR
        (piAllRtns <> 0)) THEN
      iNumRtns := iNumRtns + 1;
      DBMS_OUTPUT.PUT_LINE('blnSkipLoop is FALSE');
      blnSkipLoop := FALSE;
    END IF;

    IF NOT blnSkipLoop AND
       ((piNextRecSet < 0) OR
        ((piNextRecSet = 0) AND
         (iIndex + 1 <= C_RECS_PER_PAGE) AND
         (cgrri.erm_line_id BETWEEN piMinLine AND piMaxLine)) OR
        (((piNextRecSet > 0) AND
         (iIndex + 1 <= C_RECS_PER_PAGE) AND
         (cgrri.erm_line_id > piNextRecSet))) AND     -- was >= now > 
        ((pszType = 'ALL') OR
         (pszType = 'PUT') OR
         (pszType = 'NOPUT') OR
         ((pszType = 'SALE') AND
          (tabTypRsns.COUNT > 0) AND
          (tabTypRsns(1).reason_group <> 'DMG')) OR
         ((pszType = 'DMG') AND
          (tabTypRsns.COUNT > 0) AND
          (tabTypRsns(1).reason_group = 'DMG')))) THEN
      -- Still within the retrieval limit and search criteria ...

      DBMS_OUTPUT.PUT_LINE('iIndex[' || TO_CHAR(iIndex) || '] ln[' ||
        TO_CHAR(cgrri.erm_line_id) || '] rsnGrp[' ||
        tabTypRsns(1).reason_group || ']');
      IF (piRecTyp = 0) OR
         ((piRecTyp = 1) AND
          (NVL(rwTypPutlst.catch_wt, 'N') IN ('Y', 'C'))) OR
         ((piRecTyp = 2) AND
          (NVL(rwTypPutlst.temp_trk, 'N') IN ('Y', 'C'))) OR
         ((piRecTyp = 3) AND
          ((NVL(rwTypPutlst.catch_wt, 'N') = 'Y') OR
           ((NVL(rwTypPutlst.temp_trk, 'N') = 'Y')))) OR
         ((piRecTyp = 4) AND
          ((NVL(rwTypPutlst.catch_wt, 'N') = 'C') OR
           ((NVL(rwTypPutlst.temp_trk, 'N') = 'C')))) OR
         ((piRecTyp = 5) AND
          (NVL(rwTypPutlst.catch_wt, 'N') = 'Y')) OR
         ((piRecTyp = 6) AND
          (NVL(rwTypPutlst.temp_trk, 'N') = 'Y')) OR
         ((piRecTyp = 7) AND
          (NVL(rwTypPutlst.catch_wt, 'N') = 'C')) OR
         ((piRecTyp = 8) AND
          (NVL(rwTypPutlst.temp_trk, 'N') = 'C')) THEN

        iIndex := iIndex + 1;
        tabTypRtns(iIndex) := NULL;
        tabTypRtns(iIndex).manifest_no := cgrri.manifest_no;
        tabTypRtns(iIndex).route_no := cgrri.route_no;
        tabTypRtns(iIndex).stop_no := cgrri.stop_no;
        tabTypRtns(iIndex).rec_type := cgrri.rec_type;
        tabTypRtns(iIndex).obligation_no := cgrri.obligation_no;
        tabTypRtns(iIndex).prod_id := cgrri.prod_id;
        tabTypRtns(iIndex).cust_pref_vendor := cgrri.cust_pref_vendor;
        tabTypRtns(iIndex).reason_code := cgrri.return_reason_cd;
        tabTypRtns(iIndex).returned_qty := cgrri.returned_qty;
        tabTypRtns(iIndex).returned_split_cd := cgrri.returned_split_cd;
        tabTypRtns(iIndex).weight := cgrri.catchweight;
        tabTypRtns(iIndex).disposition := cgrri.disposition;
        tabTypRtns(iIndex).returned_prod_id := cgrri.returned_prod_id;
        tabTypRtns(iIndex).erm_line_id := cgrri.erm_line_id;
        tabTypRtns(iIndex).shipped_qty := cgrri.shipped_qty;
        tabTypRtns(iIndex).shipped_split_cd := cgrri.shipped_split_cd;
        tabTypRtns(iIndex).cust_id := cgrri.cust_id;
        tabTypRtns(iIndex).temp := cgrri.temperature;
        tabTypRtns(iIndex).catch_wt_trk := NVL(rwTypPutlst.catch_wt, 'N');
        IF NVL(rwTypPutlst.catch_wt, 'N') IN ('Y', 'C') THEN
          iNumWeightRtns := iNumWeightRtns + 1;
        END IF;
        tabTypRtns(iIndex).temp_trk := NVL(rwTypPutlst.temp_trk, 'N');
        IF NVL(rwTypPutlst.temp_trk, 'N') IN ('Y', 'C') THEN
          iNumTempRtns := iNumTempRtns + 1;
        END IF;
        tabTypRtns(iIndex).orig_invoice := SUBSTR(rwTypPutlst.orig_invoice,
          1, C_INV_NO_LEN);
        tabTypRtns(iIndex).dest_loc := rwTypPutlst.dest_loc;
        tabTypRtns(iIndex).pallet_id := rwTypPutlst.pallet_id;
        tabTypRtns(iIndex).rtn_label_printed :=
          NVL (rwTypPutlst.rtn_label_printed, 'N');
        tabTypRtns(iIndex).pallet_batch_no := rwTypPutlst.pallet_batch_no;
        tabTypRtns(iIndex).parent_pallet_id := rwTypPutlst.parent_pallet_id;
        tabTypRtns(iIndex).putaway_put := rwTypPutlst.putaway_put;
        rwTypPm := NULL;
        get_master_item(cgrri.prod_id, cgrri.cust_pref_vendor,
                        iSkidCube, rwTypPm, iStatus);
        IF iStatus = C_NORMAL AND
           tabTypRsns.COUNT > 0 AND
           tabTypRsns(1).reason_group IN ('MPR', 'MPK') THEN
          get_master_item(cgrri.returned_prod_id, cgrri.cust_pref_vendor,
                          iSkidCube, rwTypPm, iStatus);
        END IF;
        IF iStatus = C_NORMAL THEN
          tabTypRtns(iIndex).pallet_type := rwTypPm.pallet_type;
          tabTypRtns(iIndex).ti := rwTypPm.ti;
          tabTypRtns(iIndex).hi := rwTypPm.hi;
          tabTypRtns(iIndex).min_temp := rwTypPm.min_temp;
          tabTypRtns(iIndex).max_temp := rwTypPm.max_temp;
          IF NVL(rwTypPm.catch_wt_trk, 'N') = 'Y' THEN
            iQty := NVL(cgrri.returned_qty, 0);
            IF cgrri.returned_split_cd = '0' THEN
              iQty := iQty * NVL(rwTypPm.spc, 0);
            END IF;
            tabTypRtns(iIndex).min_weight := iQty * rwTypPm.avg_wt *
              (1 - gRcTypSyspar.pct_tolerance / 100);
            tabTypRtns(iIndex).max_weight := iQty * rwTypPm.avg_wt *
              (1 + gRcTypSyspar.pct_tolerance / 100);
          END IF;
          tabTypRtns(iIndex).descrip := rwTypPm.descrip;
        END IF;
      END IF;
    END IF;
    DBMS_OUTPUT.PUT_LINE('2 ' ||
      TO_CHAR(iIndex) || '- mf: ' ||
      TO_CHAR(cgrri.manifest_no) || ' l: ' || TO_CHAR(cgrri.erm_line_id) ||
      ' o: ' || cgrri.obligation_no || ' p: ' || cgrri.prod_id || '/' ||
      cgrri.returned_prod_id || ' r: ' || cgrri.return_reason_cd || ' lo: ' ||
      rwTypPutlst.dest_loc || '/' || rwTypPutlst.pallet_id);
--    pl_text_log.ins_msg('WARN', 'GetRangeRtn', '2 ' ||
--      TO_CHAR(iIndex) || '- mf: ' ||
--      TO_CHAR(cgrri.manifest_no) || ' l: ' || TO_CHAR(cgrri.erm_line_id) ||
--      ' o: ' || cgrri.obligation_no || ' p: ' || cgrri.prod_id || '/' ||
--        cgrri.returned_prod_id || ' r: ' || cgrri.return_reason_cd ||
--        '] tabRtn[' || TO_CHAR(tabTypRtns.COUNT) || ']', NULL, NULL);
  END LOOP;
  poiNumRtns := iNumRtns;
  poiNumCurRtns := iIndex;
  poiNumWeightRtns := iNumWeightRtns;
  poiNumTempRtns := iNumTempRtns;
  potabTypReturns := tabTypRtns;
END;
-- -----------------------------------------------------------------------------

FUNCTION delete_return (
  pRwTypRtn IN  returns%ROWTYPE,
  pszRsnGroup   IN  reason_cds.reason_group%TYPE DEFAULT NULL)
RETURN NUMBER IS
  excDelRtn EXCEPTION;
  tabTypRsns    tabTypReasons;
  szRsnGroup    reason_cds.reason_group%TYPE := NULL;
  rwTypPutlst   putawaylst%ROWTYPE := NULL;
  szPerm    loc.perm%TYPE := NULL;
  szMsg     VARCHAR2(300) := NULL;
  iStatus   NUMBER := C_NORMAL;
  I     NUMBER := 1;
BEGIN
  -- Get reason group for the reason code if it's not provided
  IF pszRsnGroup IS NULL THEN
    tabTypRsns := get_reason_info('ALL', 'ALL', pRwTypRtn.return_reason_cd);
    IF tabTypRsns.COUNT = 0 THEN
      RETURN C_INV_RSN;
    END IF;
    szRsnGroup := tabTypRsns(1).reason_group;
  ELSE
    szRsnGroup := pszRsnGroup;
  END IF;
  DBMS_OUTPUT.PUT_LINE('Rsn Grp: ' || pszRsnGroup || '/' || szRsnGroup);

  -- Cannot delete pickup return
  IF pRwTypRtn.rec_type = 'P' THEN
    RETURN C_DEL_NOT_ALLOWED;
  END IF;

  -- For these groups, we only need to delete the return record itself
  IF szRsnGroup IN ('STM', 'MPK') THEN
    RAISE excDelRtn;
  END IF;

  DBMS_OUTPUT.PUT_LINE('mf ' || TO_CHAR(pRwTypRtn.manifest_no) ||
    ' ob ' || pRwTypRtn.obligation_no || ' p ' || pRwTypRtn.prod_id ||
    ' l ' || TO_CHAR(pRwTypRtn.erm_line_id) || ' r ' ||
    pRwTypRtn.return_reason_cd || ' q ' || TO_CHAR(pRwTypRtn.returned_qty) ||
    '/' || pRwTypRtn.returned_split_cd);

  -- Get putawaylst record if available
  rwTypPutlst := check_putaway(szRsnGroup, pRwTypRtn);
  DBMS_OUTPUT.PUT_LINE('Chk put: ' || rwTypPutlst.putaway_put || '/' ||
    TO_CHAR(rwTypPutlst.putpath) || ' l ' || rwTypPutlst.dest_loc || '/' ||
    rwTypPutlst.pallet_id);
  IF rwTypPutlst.putaway_put= 'Y' THEN
    RETURN C_PUT_DONE;
  ELSIF rwTypPutlst.putaway_put <> 'N' THEN
    RETURN TO_NUMBER(rwTypPutlst.putpath);
  END IF;

  -- Check location is a home or float
  szPerm := 'N';
  IF szRsnGroup <> 'DMG' THEN
    BEGIN
      SELECT perm INTO szPerm
      FROM loc
      WHERE logi_loc = rwTypPutlst.dest_loc;
    EXCEPTION
      WHEN OTHERS THEN
        RETURN SQLCODE;
    END;
    DBMS_OUTPUT.PUT_LINE ('Loc perm: ' || szPerm);
  END IF;

  -- Reduce inventory qty expected only for these reason groups
  IF szRsnGroup IN ('NOR', 'WIN') THEN
    BEGIN
      UPDATE inv
        SET qty_planned = qty_planned - rwTypPutlst.qty
        WHERE prod_id = rwTypPutlst.prod_id
        AND   cust_pref_vendor = rwTypPutlst.cust_pref_vendor
        AND   (((szPerm = 'Y') AND
                (plogi_loc = rwTypPutlst.dest_loc) AND
                (logi_loc = rwTypPutlst.dest_loc)) OR
               ((szPerm <> 'Y') AND
                (plogi_loc = rwTypPutlst.dest_loc) AND
                (logi_loc = rwTypPutlst.pallet_id)))
        AND   qty_planned - rwTypPutlst.qty >= 0;
      DBMS_OUTPUT.PUT_LINE ('Update inv row cnt ' || TO_CHAR(SQL%ROWCOUNT));
    EXCEPTION
      WHEN NO_DATA_FOUND THEN
        NULL; 
      WHEN OTHERS THEN
        RETURN SQLCODE;
    END;
    -- Get rid of the reserved/floating inventory records that are empty
    BEGIN
      DELETE inv
        WHERE prod_id = rwTypPutlst.prod_id
        AND   cust_pref_vendor = rwTypPutlst.cust_pref_vendor
        AND   qoh = 0
        AND   qty_planned = 0
        AND   qty_alloc = 0
        AND   szPerm = 'N'
        AND   plogi_loc = rwTypPutlst.dest_loc
        AND   logi_loc = rwTypPutlst.pallet_id;
      DBMS_OUTPUT.PUT_LINE ('Delete inv row cnt ' || TO_CHAR(SQL%ROWCOUNT));
    EXCEPTION
      WHEN NO_DATA_FOUND THEN
        NULL; 
      WHEN OTHERS THEN
        RETURN SQLCODE;
    END;
  END IF;

  -- Undo T-Batch if needed
  IF gRcTypSyspar.lbr_mgmt_flag = 'Y' AND
     gRcTypSyspar.create_batch_flag = 'Y' THEN
    pl_rtn_lm.unload_pallet_batch(rwTypPutlst.pallet_id, 1, szMsg, iStatus);
    DBMS_OUTPUT.PUT_LINE('Unload T-batch status: ' || TO_CHAR(iStatus) ||
      ' msg ' || szMsg);
    IF iStatus = C_NORMAL THEN
      iStatus := pl_rtn_lm.delete_pallet_batch(rwTypPutlst.pallet_id, 1);
      IF iStatus NOT IN (C_NOT_FOUND, C_ANSI_NOT_FOUND, C_NORMAL) THEN
        RETURN iStatus;
      END IF;
    ELSIF iStatus NOT IN (C_NOT_FOUND, C_ANSI_NOT_FOUND) THEN
      RETURN iStatus;
    END IF;
  END IF;
  DBMS_OUTPUT.PUT_LINE ('Done undo T-Batch');

  -- Delete returned PO detail if available
  iStatus := delete_erd(pRwTypRtn.manifest_no, szRsnGroup,
                        rwtypPutlst.erm_line_id);
  DBMS_OUTPUT.PUT_LINE ('Delete ERD status ' || iStatus);
  IF iStatus <> C_NORMAL THEN
    RETURN iStatus;
  END IF;

  -- Delete returned PO header if available and the return is the last one
  iStatus := delete_erm(pRwTypRtn.manifest_no, szRsnGroup);
  DBMS_OUTPUT.PUT_LINE ('Delete ERM status ' || iStatus);
  IF iStatus <> C_NORMAL THEN
    RETURN iStatus;
  END IF;

  -- Delete putaway task
  BEGIN
    DELETE putawaylst
      WHERE pallet_id = rwTypPutlst.pallet_id;
    DBMS_OUTPUT.PUT_LINE ('Delete PUTAWAYLST status ' || TO_CHAR(SQL%ROWCOUNT));
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      NULL; 
    WHEN OTHERS THEN
      RETURN SQLCODE;
  END;

  -- All returns related tables have been handled. Now try the Returns table
  DBMS_OUTPUT.PUT_LINE('Ready to delete RETURNS');
  RAISE excDelRtn;
EXCEPTION
  WHEN excDelRtn THEN
    -- Delete the return
    BEGIN
      DELETE returns r
        WHERE r.manifest_no = pRwTypRtn.manifest_no
        AND   DECODE(r.obligation_no, NULL, ' ',
                     DECODE(INSTR(r.obligation_no, 'L'), 0, r.obligation_no,
                            SUBSTR(r.obligation_no,
                                   1, INSTR(r.obligation_no, 'L') - 1))) =
              NVL(pRwTypRtn.obligation_no, ' ')
        AND   r.rec_type = pRwTypRtn.rec_type
        AND   r.prod_id = pRwTypRtn.prod_id
        AND   r.cust_pref_vendor = pRwTypRtn.cust_pref_vendor
        AND   r.erm_line_id = pRwTypRtn.erm_line_id;
      DBMS_OUTPUT.PUT_LINE ('Delete RETURNS cnt: ' || TO_CHAR(SQL%ROWCOUNT));
    EXCEPTION
      WHEN NO_DATA_FOUND THEN
        RETURN C_NORMAL;
      WHEN OTHERS THEN
        RETURN SQLCODE;
    END;
    -- Put manifest detail back to OPN for future return. Try to update
    -- detail w/ same uom first
    BEGIN
      UPDATE manifest_dtls d
        SET d.manifest_dtl_status = 'OPN'
        WHERE d.manifest_no = pRwTypRtn.manifest_no
        AND   DECODE(INSTR(d.obligation_no, 'L'), 0, d.obligation_no,
                     SUBSTR(d.obligation_no,
                     1, INSTR(d.obligation_no, 'L') - 1)) =
              pRwTypRtn.obligation_no
        AND   d.rec_type = pRwTypRtn.rec_type
        AND   d.prod_id = pRwTypRtn.prod_id
        AND   d.cust_pref_vendor = pRwTypRtn.cust_pref_vendor
        AND   d.shipped_split_cd = pRwTypRtn.returned_split_cd
        AND   NOT EXISTS (SELECT 1
                          FROM returns
                          WHERE manifest_no = d.manifest_no
                          AND   obligation_no = d.obligation_no
                          AND   rec_type = d.rec_type
                          AND   prod_id = d.prod_id
                          AND   cust_pref_vendor = d.cust_pref_vendor
                          AND   returned_split_cd = d.shipped_split_cd);
      DBMS_OUTPUT.PUT_LINE ('Update MANNIFEST_DTLS status (same uom) cnt: ' ||
        TO_CHAR(SQL%ROWCOUNT));
    EXCEPTION
      WHEN NO_DATA_FOUND THEN
        BEGIN
          -- Cannot find same uom. Try the opposite uom
          UPDATE manifest_dtls d
            SET d.manifest_dtl_status = 'OPN'
            WHERE d.manifest_no = pRwTypRtn.manifest_no
            AND   DECODE(INSTR(d.obligation_no, 'L'), 0, d.obligation_no,
                         SUBSTR(d.obligation_no,
                         1, INSTR(d.obligation_no, 'L') - 1)) =
                  pRwTypRtn.obligation_no
            AND   d.rec_type = pRwTypRtn.rec_type
            AND   d.prod_id = pRwTypRtn.prod_id
            AND   d.cust_pref_vendor = pRwTypRtn.cust_pref_vendor
            AND   d.shipped_split_cd = DECODE(pRwTypRtn.returned_split_cd,
                                              '1', '0', '1')
            AND   NOT EXISTS (SELECT 1
                              FROM returns
                              WHERE manifest_no = d.manifest_no
                              AND   obligation_no = d.obligation_no
                              AND   rec_type = d.rec_type
                              AND   prod_id = d.prod_id
                              AND   cust_pref_vendor = d.cust_pref_vendor
                              AND   d.shipped_split_cd =
                                      DECODE(pRwTypRtn.returned_split_cd,
                                             '1', '0', '1'));
          DBMS_OUTPUT.PUT_LINE ('Update MANNIFEST_DTLS status (diff uom) ' ||
            'cnt: ' || TO_CHAR(SQL%ROWCOUNT));
        EXCEPTION
          WHEN NO_DATA_FOUND THEN
            NULL;
          WHEN OTHERS THEN
            RETURN SQLCODE;
        END; 
      WHEN OTHERS THEN
        RETURN SQLCODE;
    END;
    RETURN C_NORMAL;
  WHEN OTHERS THEN
    RETURN SQLCODE;
END;
-- -----------------------------------------------------------------------------

FUNCTION delete_return (
  pszValue      IN      putawaylst.pallet_id%TYPE)
RETURN NUMBER IS
  rwTypRtn      returns%ROWTYPE := NULL;
BEGIN
  SELECT r.manifest_no, r.rec_type, pt.lot_id,
         r.prod_id, r.cust_pref_vendor, pt.reason_code, r.returned_qty,
         r.returned_split_cd, pt.weight, r.disposition, r.returned_prod_id,
         r.erm_line_id, r.cust_id, pt.temp
  INTO rwTypRtn.manifest_no, rwTypRtn.rec_type, rwTypRtn.obligation_no,
       rwTypRtn.prod_id, rwTypRtn.cust_pref_vendor, rwTypRtn.return_reason_cd,
       rwTypRtn.returned_qty, rwTypRtn.returned_split_cd,
       rwTypRtn.catchweight, rwTypRtn.disposition, rwTypRtn.returned_prod_id,
       rwTypRtn.erm_line_id, rwTypRtn.cust_id, rwTypRtn.temperature
  FROM putawaylst pt, returns r
  WHERE pt.pallet_id = pszValue
  AND   SUBSTR(pt.rec_id, 2) = TO_CHAR(r.manifest_no)
  AND   NVL(DECODE(INSTR(r.obligation_no, 'L'), 0, r.obligation_no,
                   SUBSTR(r.obligation_no,
                          1, INSTR(r.obligation_no, 'L') - 1)), ' ') =
        NVL(pt.lot_id, ' ')
  AND   pt.prod_id = NVL(r.returned_prod_id, r.prod_id)
  AND   pt.cust_pref_vendor = r.cust_pref_vendor
  AND   pt.erm_line_id = r.erm_line_id;

  RETURN delete_return(rwTypRtn, NULL);
EXCEPTION
  WHEN OTHERS THEN
    RETURN C_NOT_FOUND;
END;
-- -----------------------------------------------------------------------------

FUNCTION set_rtn_label_printed (
  pszPalletID   IN  putawaylst.pallet_id%TYPE)
RETURN NUMBER IS
BEGIN
  UPDATE putawaylst
    SET rtn_label_printed = 'Y'
    WHERE pallet_id = pszPalletID;
  RETURN C_NORMAL;
EXCEPTION
  WHEN OTHERS THEN
    RETURN C_UPD_PUTLST_FAIL;
END;
-- -----------------------------------------------------------------------------

FUNCTION get_default_printer_info
RETURN print_queues%ROWTYPE IS
  rwTypQueue        print_queues%ROWTYPE := NULL;
BEGIN
  SELECT q.user_queue, q.system_queue, q.queue_type, q.queue_filter, q.descrip,
         q.command, q.directory
  INTO rwTypQueue.user_queue, rwTypQueue.system_queue, rwTypQueue.queue_type,
       rwTypQueue.queue_filter, rwTypQueue.descrip,
       rwTypQueue.command, rwTypQueue.directory
  FROM print_queues q, print_reports r, print_report_queues rq
  WHERE rq.user_id = REPLACE(USER, 'OPS$', '')
  AND   r.report = 'rp1ri'
  AND   rq.queue_type = r.queue_type
  AND   rq.queue_type = 'RTLB'
  AND   rq.queue = q.system_queue
  AND   rq.queue_type = q.queue_type;
  pl_text_log.ins_msg('WARN', 'get_default_printer_info',
    'queue[' || rwTypQueue.system_queue || '] user[' ||
    REPLACE(USER, 'OPS$', '') || '] looking for rp1ri/RTLB status[' ||
    TO_CHAR(SQLCODE) || ']', NULL, NULL);
  RETURN rwTypQueue;
EXCEPTION
  WHEN NO_DATA_FOUND THEN
    BEGIN
      SELECT q.user_queue, q.system_queue, q.queue_type, q.queue_filter,
             q.descrip, q.command, q.directory
      INTO rwTypQueue.user_queue, rwTypQueue.system_queue,
           rwTypQueue.queue_type, rwTypQueue.queue_filter, rwTypQueue.descrip,
           rwTypQueue.command, rwTypQueue.directory
      FROM print_queues q, print_reports r, print_report_queues rq
      WHERE rq.user_id = REPLACE(USER, 'OPS$', '')
      AND   r.report = 'rp2ri'
      AND   rq.queue_type = r.queue_type
      AND   rq.queue_type = 'RTLB'
      AND   rq.queue = q.system_queue
      AND   rq.queue_type = q.queue_type;
      pl_text_log.ins_msg('WARN', 'get_default_printer_info',
        'queue[' || rwTypQueue.system_queue || '] user[' ||
        REPLACE(USER, 'OPS$', '') || '] looking for rp2ri/RTLB status[' ||
        TO_CHAR(SQLCODE) || ']', NULL, NULL);
      RETURN rwTypQueue;
    EXCEPTION
      WHEN OTHERS THEN
      pl_text_log.ins_msg('WARN', 'get_default_printer_info',
        'User[' || REPLACE(USER, 'OPS$', '') ||
        '] looking for rp2ri/RTLB when others ' ||
        'status[' || TO_CHAR(SQLCODE) || ']', NULL, NULL);
      RETURN rwTypQueue;
        RETURN NULL;
    END;
  WHEN OTHERS THEN
    pl_text_log.ins_msg('WARN', 'get_default_printer_info',
      'User[' || REPLACE(USER, 'OPS$', '') ||
      '] looking for rp1ri/RTLB when others ' ||
      'status[' || TO_CHAR(SQLCODE) || ']', NULL, NULL);
    RETURN NULL;
END;
-- -----------------------------------------------------------------------------

PROCEDURE close_manifest (
  piMfNo    IN  manifests.manifest_no%TYPE,
  poszLMStr OUT VARCHAR2,
  poszMsg   OUT VARCHAR2,
  poiStatus OUT NUMBER) IS

  iOrderLineID  ordd.order_line_Id%TYPE;
  szRoute       manifests.route_no%TYPE := NULL;
  szMfStatus    VARCHAR2(10) := NULL;
  iRtnCnt       NUMBER := 0;
  iErdCnt       NUMBER := 0;
  szSendSUS     VARCHAR2(10) := NULL;
  tabTypRsn     tabTypReasons;
  rwTypRtn      returns%ROWTYPE := NULL;
  rwTypPm       pm%ROWTYPE := NULL;
  iSkidCube     NUMBER := 0;
  szOrigInv     manifest_dtls.orig_invoice%TYPE := NULL;
  rwTypMfHdr    manifests%ROWTYPE := NULL;
  rwTypTrans    trans%ROWTYPE := NULL;
  iStatus       NUMBER := C_NORMAL;
  szLMStr       VARCHAR(100) := NULL;
  szPutLoc      loc.logi_loc%TYPE := NULL;
  blnLocNotFound    BOOLEAN := FALSE;
  -- Inbound Accessory Changes
  blnInbNotDone     BOOLEAN := FALSE;
  szLockMfStatus    manifests.manifest_status%TYPE := NULL;
  -- Inbound Accessory changes
  count_inbound     NUMBER:=0;
  count_outbound    NUMBER:=0;
  iErdExists        NUMBER := 0; 

  l_sitefrom varchar2(10);
  l_siteto varchar2(10);
  l_mf_status	varchar2(15);

  --POD changes
    v_pod_flag VARCHAR2(1);     
    v_trans_count NUMBER(10);
    v_return_count NUMBER(10);

  CURSOR c_get_temp_out_tolerance IS
    SELECT DECODE(INSTR(r.obligation_no, 'L'), 0, r.obligation_no,
                  SUBSTR(r.obligation_no,
                         1, INSTR(r.obligation_no, 'L') - 1)) obligation_no,
           DECODE(d.reason_group, 'MPR', r.returned_prod_id, r.prod_id) prod_id,
           r.temperature, p.min_temp, p.max_temp
    FROM returns r, pm p, reason_cds d
    WHERE r.manifest_no = piMfNo
    AND   r.cust_pref_vendor = p.cust_pref_vendor
    AND   p.prod_id = DECODE(d.reason_group, 'MPR', r.returned_prod_id,
                                             r.prod_id)
    AND   p.temp_trk = 'Y'
    AND   ((r.temperature IS NULL) OR
           (r.temperature NOT BETWEEN NVL(p.min_temp, 0)
                              AND     NVL(p.max_temp, 0)))
    AND   d.reason_cd_type = 'RTN' 
    AND   d.reason_group NOT IN ('DMG', 'STM', 'MPK')
    AND   NVL(r.returned_qty, 0) > 0;
  CURSOR c_get_rtn IS
    SELECT r.route_no, r.stop_no, r.rec_type,
           DECODE(INSTR(r.obligation_no, 'L'), 0, r.obligation_no,
                  SUBSTR(r.obligation_no,
                         1, INSTR(r.obligation_no, 'L') - 1)) obligation_no,
                         r.pod_rtn_ind, r.ORG_RTN_REASON_CD,r.ORG_RTN_QTY, --ez
                         r.ORG_CATCHWEIGHT,r.RTN_SENT_IND, --ez
           r.prod_id, r.cust_pref_vendor,
           NVL(r.returned_prod_id, r.prod_id) returned_prod_id,
           r.return_reason_cd, r.returned_qty, r.returned_split_cd,
           r.catchweight, r.temperature, r.erm_line_id, r.cust_id, r.xdock_ind
    FROM returns r
    WHERE r.manifest_no = piMfNo;
  CURSOR c_get_bad_rtn IS
    SELECT r.route_no, r.stop_no, r.rec_type,
           DECODE(INSTR(r.obligation_no, 'L'), 0, r.obligation_no,
                  SUBSTR(r.obligation_no,
                         1, INSTR(r.obligation_no, 'L') - 1)) obligation_no,
           r.prod_id, r.cust_pref_vendor,
           returned_prod_id,
           r.return_reason_cd, r.returned_qty, r.returned_split_cd,
           r.catchweight, r.temperature, r.erm_line_id, r.cust_id,
           NVL(c.reason_group, 'XXX') reason_group
    FROM returns r, reason_cds c
    WHERE r.manifest_no = piMfNo
    AND   c.reason_cd_type = 'RTN'
    AND   r.return_reason_cd (+) = c.reason_cd
    ORDER BY r.erm_line_id;
BEGIN
  poszLMStr := NULL;
  poszMsg := NULL;
  poiStatus := C_NORMAL;

  -- Check if the specified manifest has been closed. Don't do it again
  get_mf_status(piMfNo, szRoute, szMfStatus);
  DBMS_OUTPUT.PUT_LINE('Mf status: ' || szMfStatus || ' 1: ' ||
    SUBSTR(szMfStatus, 1, 1));
  IF UPPER(SUBSTR(szMfStatus, 1, 1)) NOT BETWEEN 'A' AND 'Z' THEN
    poiStatus := C_INV_MF;
    RETURN;
  ELSIF szMfStatus = C_MF_CLO_STR THEN
    poiStatus := C_MF_HAS_CLOSED;
    RETURN;
  END IF;

 BEGIN --Jira 3050
  SELECT DISTINCT site_from, site_to
  INTO l_sitefrom,l_siteto
  FROM manifest_dtls
  WHERE manifest_no = piMfNo
  AND xdock_ind     ='S';

  IF l_sitefrom    IS NOT NULL THEN
    pl_rtn_xdock_interface.Get_Manifest_status(piMfNo,'FULFIL', l_sitefrom,l_siteto,l_mf_status );
    IF NVL(l_mf_status,'N') <> 'MANIFEST' THEN
      pl_log.ins_msg('INFO', 'CLOSE_MANIFEST', 'Crossdock Manifest cannot be closed until Lastmile Manifest is closed.', SQLCODE, SUBSTR(SQLERRM, 1, 500), 'DRIVER CHECKIN', 'PL_DCI');
      RETURN;
    END IF;
  END IF;
EXCEPTION
WHEN no_data_found THEN
  NULL;
WHEN OTHERS THEN
  pl_log.ins_msg('INFO', 'CLOSE_MANIFEST', 'Exception in Crossdock Manifest close process.', SQLCODE, SUBSTR(SQLERRM, 1, 500), 'DRIVER CHECKIN', 'PL_DCI');
  RETURN;
END; --Jira 3050



  IF szMfStatus = 'PAD' THEN
    -- Don't send anything to SUS if manifest is an order delete
    szSendSUS := 'NA';
  END IF;

  DBMS_OUTPUT.PUT_LINE('Check final counts ...');
  -- Check if # of records not match
  BEGIN
    SELECT COUNT(1) INTO iRtnCnt
    FROM returns r, reason_cds d
    WHERE r.manifest_no = piMfNo
    AND   r.return_reason_cd = d.reason_cd
    AND   d.reason_cd_type = 'RTN'
    AND   d.reason_group NOT IN ('STM', 'MPK')
    AND   NVL(r.returned_qty, 0) > 0;
  EXCEPTION
    WHEN OTHERS THEN
      iRtnCnt := 0;
  END;

-- Inbound Accessory Tracking Changes
-- Check whether inbound accessory tracking needed
 BEGIN
 IF NVL(gRcTypSyspar.enable_acc_trk_flag, 'N') = 'Y' THEN
    SELECT COUNT(*) INTO count_inbound FROM v_truck_accessory
      WHERE manifest_no = piMfNo
        AND NVL(inbound_count,0) > 0;
    SELECT COUNT(*) INTO count_outbound FROM v_truck_accessory
      WHERE manifest_no = piMfNo
        AND NVL(loader_count,0) > 0;
    If count_outbound <>0 AND count_inbound =0 THEN
      blnInbNotDone := blnInbNotDone OR TRUE;
    END IF;
 END IF;
 EXCEPTION
  WHEN OTHERS THEN
     poiStatus := SQLCODE;
     ROLLBACK;
     RETURN;
  END;

  BEGIN
    SELECT COUNT(1) INTO iErdCnt
    FROM erd d
    WHERE SUBSTR(d.erm_id, 2) = TO_CHAR(piMfNo);
  EXCEPTION
    WHEN OTHERS THEN
      iErdCnt := 0;
  END;
  IF iRtnCnt <> iErdCnt THEN
    poiStatus := C_NO_MF_INFO;
    RETURN;
  END IF;
  DBMS_OUTPUT.PUT_LINE('Rtn cnt: ' || TO_CHAR(iRtnCnt) || ' Erd cnt: ' ||
    TO_CHAR(iErdCnt));

  -- Check out of limit or required temperatures
  FOR cgtot IN c_get_temp_out_tolerance LOOP
    poszMsg := 'Invoice/Item/Temp/MinTemp/MaxTemp: ' ||
               cgtot.obligation_no || '/' || cgtot.prod_id || '/' ||
               TO_CHAR(cgtot.temperature) || '/' ||
               TO_CHAR(cgtot.min_temp) || '/' || TO_CHAR(cgtot.max_temp);
    IF cgtot.temperature IS NULL THEN
      poiStatus := C_TEMP_REQUIRED;
    ELSE
      poiStatus := C_TEMP_OUT_OF_RANGE;
    END IF;
    RETURN;
  END LOOP;

  FOR cgbr IN c_get_bad_rtn LOOP
    iErdExists := 0;
    BEGIN
      SELECT 1 INTO iErdExists
      FROM erd
      WHERE erm_id like '%' || TO_CHAR(piMfNo)
      AND   erm_line_id = cgbr.erm_line_id
      AND   reason_code = cgbr.return_reason_cd
      AND   prod_id = NVL(cgbr.returned_prod_id, cgbr.prod_id)
      AND   cust_pref_vendor = cgbr.cust_pref_vendor
      AND   order_id = cgbr.obligation_no;
    EXCEPTION
      WHEN NO_DATA_FOUND THEN
        iErdExists := 0;
      WHEN TOO_MANY_ROWS THEN
        iErdExists := 1;
      WHEN OTHERS THEN
        iErdExists := 0;
    END;
    IF NVL(cgbr.reason_group, 'XXX') = 'XXX' THEN
      poiStatus := C_INV_RSN;
      RETURN;
    END IF;
    IF cgbr.returned_prod_id IS NULL AND
       NVL(cgbr.returned_qty, 0) > 0 AND
       cgbr.reason_group IN ('MPR') THEN
      poiStatus := C_MSPK_REQUIRED;
      RETURN;
    END IF;
    IF cgbr.returned_prod_id IS NOT NULL AND
       NVL(cgbr.returned_qty, 0) = 0 AND
       cgbr.reason_group NOT IN ('STM', 'MPK') AND
       cgbr.rec_type = 'I' THEN
      poiStatus := C_QTY_REQUIRED;
      RETURN;
    END IF;
    IF cgbr.returned_prod_id IS NULL AND
       NVL(cgbr.returned_qty, 0) = 0 AND
       cgbr.reason_group NOT IN ('STM', 'MPK') AND
       iErdExists = 0 AND
       cgbr.rec_type = 'I' THEN
       poiStatus := C_QTY_REQUIRED;
       RETURN;
    END IF;
    IF NVL(cgbr.returned_qty, 0) > 0 AND
       cgbr.rec_type IN ('I', 'O') AND
       iErdExists = 0 AND
       cgbr.reason_group NOT IN ('STM', 'MPK') THEN
      poiStatus := C_RTN_EXISTS;
      RETURN;
    END IF;
  END LOOP;

  -- Lock the manifest so nobody else can close it
  BEGIN
    SELECT manifest_status INTO szLockMfStatus
    FROM manifests
    WHERE manifest_no = piMfNo
    FOR UPDATE OF manifest_status;
    IF szLockMfStatus = C_MF_CLO_STR THEN
      poiStatus := C_MF_HAS_CLOSED;
      ROLLBACK;
      RETURN;
    END IF;
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      poiStatus := C_NO_MF_INFO;
      ROLLBACK;
      RETURN;
    WHEN OTHERS THEN
      poiStatus := SQLCODE;
      ROLLBACK;
      RETURN;
  END;

  -- Create RTN transactions
  FOR cgr IN c_get_rtn LOOP

    DBMS_OUTPUT.PUT_LINE('ob: ' || cgr.obligation_no || ' l: ' ||
      TO_CHAR(cgr.erm_line_id) || ' p: ' || cgr.prod_id ||
      ' rp: ' || cgr.returned_prod_id || ' r: ' || cgr.return_reason_cd ||
      ' q: ' || TO_CHAR(cgr.returned_qty) || '/' || cgr.returned_split_cd);

    -- Check if reason code is still valid
    tabTypRsn := get_reason_info('ALL', 'ALL', cgr.return_reason_cd);
    IF tabTypRsn.COUNT = 0 THEN
      poszMsg := 'Invoice/item ' || cgr.obligation_no || '/' || cgr.prod_id;
      poiStatus := C_INV_RSN;
      ROLLBACK;
      RETURN;
    END IF;

    -- Assign to row to be used by called functions 
    rwTypRtn := NULL;
    rwTypRtn.manifest_no := piMfNo;
    rwTypRtn.route_no := cgr.route_no;
    rwTypRtn.obligation_no := cgr.obligation_no;
    rwTypRtn.rec_type := cgr.rec_type;
    rwTypRtn.prod_id := cgr.prod_id;
    rwTypRtn.returned_prod_id := cgr.returned_prod_id;
    rwTypRtn.cust_pref_vendor := cgr.cust_pref_vendor;
    rwTypRtn.returned_qty := cgr.returned_qty;
    rwTypRtn.returned_split_cd := cgr.returned_split_cd;

    -- Get item info for the returned item
    get_master_item(cgr.returned_prod_id, cgr.cust_pref_vendor, iSkidCube,
                    rwTypPm, iStatus);
    IF iStatus <> C_NORMAL THEN
      poiStatus := C_INV_PRODID;
      ROLLBACK;
      RETURN;
    END IF;

    IF NVL(cgr.catchweight, 0) = 0 AND rwTypPm.catch_wt_trk = 'Y' THEN
      -- Check the total returned qty. Needs to exclude the current return
      -- information (1)
      iStatus := check_ovr_und_rtn(rwTypRtn, 1);
      IF iStatus = -20001 THEN
        -- Total returned qty is less than shipped qty and the item is a
        -- weight tracked item and the return doesn't have a weight
        poszMsg := 'Invoice/item ' || cgr.obligation_no || '/' || cgr.prod_id;
        poiStatus := C_WEIGHT_DESIRED;
        ROLLBACK;
        RETURN;
      ELSIF iStatus NOT IN (C_NORMAL, C_QTY_RTN_GT_SHP) THEN
        -- Error occurred during qty checking
        poiStatus := iStatus;
        ROLLBACK;
        RETURN;
      END IF;
    END IF;

    -- Retrieve original invoice if available
    szOrigInv := get_orig_invoice(rwTypRtn);

    -- Retrieve route # for RTN transaction from header if it's not available
    -- in detail
    IF rwTypRtn.route_no IS NULL THEN
      get_mf_info(piMfNo, rwTypMfHdr);
      IF rwTypMfHdr.manifest_no IS NOT NULL THEN
        rwTypRtn.route_no := rwTypMfHdr.route_no;
      END IF;
    END IF;
    DBMS_OUTPUT.PUT_LINE('Orig inv: ' || szOrigInv || ' Route: ' ||
      rwTypRtn.route_no);

    -- Create RTN transaction
    rwTypTrans := NULL;
  	IF nvl(cgr.xdock_ind, 'N') = 'X' THEN  -- Jira 3400 xdock logic
	    rwTypTrans.trans_type := 'RTX';
      szSendSUS := 'NA';
    ELSE
        rwTypTrans.trans_type := 'RTN';
    End if;

    rwTypTrans.batch_no := '77';
    rwTypTrans.route_no := rwTypRtn.route_no;
    rwTypTrans.stop_no := cgr.stop_no;
    rwTypTrans.order_id := cgr.obligation_no;
    rwTypTrans.prod_id := cgr.prod_id;
    rwTypTrans.cust_pref_vendor := cgr.cust_pref_vendor;
    rwTypTrans.rec_id := TO_CHAR(piMfNo);
    rwTypTrans.weight := cgr.catchweight;
    rwTypTrans.temp := cgr.temperature;
    rwTypTrans.qty := NVL(cgr.returned_qty, 0);
    rwTypTrans.uom := TO_NUMBER(cgr.returned_split_cd);
    rwTypTrans.reason_code := cgr.return_reason_cd;
    rwTypTrans.lot_id := szOrigInv;
    rwTypTrans.order_type := cgr.rec_type;
    rwTypTrans.order_line_id := cgr.erm_line_id;
    rwTypTrans.returned_prod_id := cgr.returned_prod_id;
    rwTypTrans.po_no := TO_CHAR(piMfNo);
    IF tabTypRsn(1).reason_group IN ('MPR', 'MPK') THEN
      rwTypTrans.cmt := cgr.returned_prod_id;
    END IF;
    /*ez POD changes---------------------*/
    IF cgr.pod_rtn_ind = 'U' THEN
       rwTypTrans.adj_flag := 'A';
       iStatus := pl_common.f_create_trans(rwTypTrans, szSendSUS);
       DBMS_OUTPUT.PUT_LINE('Create RTN trans status: ' || TO_CHAR(iStatus));
        IF iStatus <> C_NORMAL THEN
          poiStatus := iStatus;
          ROLLBACK;
          RETURN;
        END IF;


       rwTypTrans.adj_flag := 'U';
       rwTypTrans.qty := NVL(cgr.ORG_RTN_QTY, 0);
       rwTypTrans.weight := cgr.ORG_CATCHWEIGHT;
       rwTypTrans.reason_code := cgr.ORG_RTN_REASON_CD;
       iStatus := pl_common.f_create_trans(rwTypTrans, szSendSUS);
       DBMS_OUTPUT.PUT_LINE('Create RTN trans status: ' || TO_CHAR(iStatus));
        IF iStatus <> C_NORMAL THEN
          poiStatus := iStatus;
          ROLLBACK;
          RETURN;
        END IF;
    END IF;

    IF cgr.pod_rtn_ind = 'A' THEN
       rwTypTrans.adj_flag := 'A';
       iStatus := pl_common.f_create_trans(rwTypTrans, szSendSUS);
      DBMS_OUTPUT.PUT_LINE('Create RTN trans status: ' || TO_CHAR(iStatus));
        IF iStatus <> C_NORMAL THEN
          poiStatus := iStatus;
          ROLLBACK;
          RETURN;
        END IF;
    END IF;


    IF cgr.pod_rtn_ind = 'D' THEN
       rwTypTrans.adj_flag := 'U';
       rwTypTrans.qty := NVL(cgr.ORG_RTN_QTY, 0);
       rwTypTrans.weight := cgr.ORG_CATCHWEIGHT;
       rwTypTrans.reason_code := cgr.ORG_RTN_REASON_CD;
       iStatus := pl_common.f_create_trans(rwTypTrans, szSendSUS);
       DBMS_OUTPUT.PUT_LINE('Create RTN trans status: ' || TO_CHAR(iStatus));
        IF iStatus <> C_NORMAL THEN
          poiStatus := iStatus;
          ROLLBACK;
          RETURN;
        END IF; 
    END IF;

    IF cgr.pod_rtn_ind IS NULL THEN
       rwTypTrans.adj_flag := NULL;
    iStatus := pl_common.f_create_trans(rwTypTrans, szSendSUS);
    DBMS_OUTPUT.PUT_LINE('Create RTN trans status: ' || TO_CHAR(iStatus));
    IF iStatus <> C_NORMAL THEN
      poiStatus := iStatus;
      ROLLBACK;
      RETURN;
    END IF;
    END IF;

   select count(*) 
   into v_return_count
    from returns 
    where manifest_no= piMfNo
    and stop_no= cgr.stop_no;

    select count(*) 
    into v_trans_count
    from trans
    where rec_id= piMfNo
    and stop_no= cgr.stop_no and trans_type='RTN';

            --CRQ34059--IF RTN TRANSACTION IN TRANS TABLE IS EQUAL TO THE TOTAL NUMBER OF
            --RETURNS PRESENT FOR THAT MANIFEST, THEN UPDATE POD_STATUS_FLAG FROM 'F' to 'M',
            --IF SYSPAR POD_ENABLE IS ON.
            IF v_trans_count = v_return_count then
               BEGIN

                      SELECT CONFIG_FLAG_VAL 
                        INTO v_pod_flag 
                        FROM SYS_CONFIG 
                       WHERE CONFIG_FLAG_NAME='POD_ENABLE';

                      IF v_pod_flag= 'Y' THEN

                        UPDATE MANIFEST_STOPS SET POD_STATUS_FLAG='M' 
                        WHERE MANIFEST_NO = piMfNo 
                        AND POD_STATUS_FLAG='F'
                        AND STOP_NO = cgr.stop_no;

                      END IF;

                END;
            END IF;      



    /*ez POD changes----------------------*/


    -- Only create cycle counts and exceptions for the following reason groups
    -- and nonzero returned qty
    IF tabTypRsn(1).reason_group IN ('STM', 'OVR', 'MPR', 'MPK', 'OVI') AND
       NVL(cgr.returned_qty, 0) > 0 and  nvl(cgr.xdock_ind, 'N') <> 'X' THEN --Jira 3400 xdock logic
      -- Create cycle counts and exceptions for invoiced item
      create_cyc(szLMStr, iStatus, tabTypRsn(1), rwTypRtn);
      IF iStatus = C_NORMAL THEN
        poszLMStr := poszLMStr || szLMStr;
        IF szLMStr IS NOT NULL THEN
          poszLMStr := poszLMStr || '|';
        END IF;
        IF tabTypRsn(1).reason_group IN ('MPR', 'MPK') THEN
          -- Create cycle counts and exceptions for mispicked item
          create_cyc(szLMStr, iStatus, tabTypRsn(1), rwTypRtn, 2);
          IF iStatus = C_NORMAL THEN
            poszLMStr := poszLMStr || szLMStr;
            IF szLMStr IS NOT NULL THEN
              poszLMStr := poszLMStr || '|';
            END IF;
          ELSIF iStatus = C_NO_LOC THEN
            blnLocNotFound := blnLocNotFound OR TRUE;
          END IF;
        END IF;
      ELSIF iStatus = C_NO_LOC THEN
        blnLocNotFound := blnLocNotFound OR TRUE;
      END IF;
      IF iStatus NOT IN (C_NORMAL, C_NO_LOC) THEN
        poiStatus := iStatus;
        ROLLBACK;
        RETURN;
      END IF;
    END IF;

    -- Log the returns to order history for Labor Management Returns Error
    -- Tracking use
    IF NVL(cgr.returned_qty, 0) > 0 and nvl(cgr.xdock_ind, 'N') <> 'X' THEN --Jira 3400 xdock logic
      szPutLoc := get_put_loc(tabTypRsn(1).reason_group, rwTypRtn);

      -- Now we need to get order_line_id from ordd or ordd_for_rtn 11/1/05 
      iOrderLineID := get_order_line(cgr.prod_id, cgr.cust_pref_vendor,
		cgr.returned_split_cd, cgr.obligation_no, szOrigInv);

      BEGIN
    IF (iOrderLineID IS NULL OR iOrderLineID <> 0)  and nvl(cgr.xdock_ind, 'N') <> 'X' THEN  --Jira 3400 xdock logic
          INSERT INTO float_hist_errors
            (prod_id, cust_pref_vendor, order_id, reason_code, 
             ret_qty, ret_uom, err_date, returned_prod_id, returned_loc, 
             orig_invoice, order_line_id)
            VALUES (
             cgr.prod_id, cgr.cust_pref_vendor, NVL(cgr.obligation_no, '0000'),
             cgr.return_reason_cd, cgr.returned_qty,
             TO_NUMBER(cgr.returned_split_cd), 
             SYSDATE,
             DECODE(tabTypRsn(1).reason_group, 'MPR', cgr.returned_prod_id,
                                               'MPK', cgr.returned_prod_id,
                                                NULL),
             szPutLoc, szOrigInv, iOrderLineID);
         END IF;
      EXCEPTION
        WHEN DUP_VAL_ON_INDEX THEN
          BEGIN

              UPDATE float_hist_errors
              SET ret_qty = NVL(ret_qty, 0) + NVL(cgr.returned_qty, 0)
              WHERE order_id = cgr.obligation_no
              AND   prod_id = cgr.prod_id
              AND   cust_pref_vendor = cgr.cust_pref_vendor
              AND   reason_code = cgr.return_reason_cd;

	       EXCEPTION
            WHEN OTHERS THEN
              poiStatus := SQLCODE;
              ROLLBACK;
              RETURN;
          END;
        WHEN OTHERS THEN
          poiStatus := SQLCODE;
          ROLLBACK;
          RETURN;
      END;
    END IF;
  END LOOP;

  -- Delete cycle count exceptions that have CC reason. We don't need them for
  -- adjustment later
  BEGIN
    DELETE cc_exception_list
      WHERE cc_except_code = 'CC';
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      NULL;
    WHEN OTHERS THEN
      poiStatus := SQLCODE;
      ROLLBACK;
      RETURN;
  END;

  -- If RTN_PUT_CONF syspar is not set, also send PUT transactions up to SUS
  IF gRcTypSyspar.rtn_putaway_conf = 'N' THEN
    iStatus := create_rtn_put_conf(piMfNo);
    IF iStatus <> C_NORMAL THEN
      poiStatus := iStatus;
      ROLLBACK;
      RETURN;
    END IF;
  END IF;

  -- Delete putaway tasks that have been done
  BEGIN
    DELETE putawaylst
    WHERE rec_id in ( 'S' || TO_CHAR(piMfNo), 'X' || TO_CHAR(piMfNo)) --Jira 3400 xdock logic
    AND   putaway_put = 'Y';
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      NULL;
    WHEN OTHERS THEN
      poiStatus := SQLCODE;
      ROLLBACK;
      RETURN;
  END;

  -- Create MFC transaction
  rwTypTrans := NULL;
  rwTypTrans.trans_type := 'MFC';
  rwTypTrans.batch_no := '77';
  rwTypTrans.route_no := rwTypRtn.route_no;
  rwTypTrans.rec_id := TO_CHAR(piMfNo);
  rwTypTrans.po_no := TO_CHAR(piMfNo);
  iStatus := pl_common.f_create_trans(rwTypTrans, szSendSUS);
  DBMS_OUTPUT.PUT_LINE('Create MFC trans status: ' || TO_CHAR(iStatus));
  IF iStatus <> C_NORMAL THEN
    poiStatus := iStatus;
    ROLLBACK;
    RETURN;
  END IF;

  -- Finally close the manifest
  BEGIN
    UPDATE manifests
      SET manifest_status = 'CLS'
      WHERE manifest_no = piMfNo;
  EXCEPTION
    WHEN OTHERS THEN
      poiStatus := SQLCODE;
      ROLLBACK;
      RETURN;
  END;
            DBMS_OUTPUT.PUT_LINE( 
                'iStatus: ' ||iStatus ||' poiStatus: '||poiStatus);
  IF blnLocNotFound THEN
    poiStatus := C_NO_LOC;
  END IF;

  -- Inbound Accessory Changes
  IF blnInbNotDone THEN
    poiStatus := C_TRACK_TRUCK_ACCESSORY;
  END IF;
            DBMS_OUTPUT.PUT_LINE( 
                'iStatus: ' ||iStatus ||' poiStatus: '||poiStatus);
EXCEPTION
  WHEN OTHERS THEN
    poiStatus := SQLCODE;
    ROLLBACK;
END;
-- -----------------------------------------------------------------------------
PROCEDURE auto_close_manifest IS
    l_days varchar2(20);
    iStatus NUMBER;
    auto_close_flag    BOOLEAN;
    sLMStr1 varchar2(4000)   :=  NULL;
    sMsg1   varchar2(1024)   :=  NULL;
    PROGRAM_CODE varchar2(30):='process_mf';
    C_NORMAL        CONSTANT NUMBER := 0;
    C_TEMP_NO_RANGE     CONSTANT NUMBER := 261; -- No temperature range
    C_TEMP_OUT_OF_RANGE CONSTANT NUMBER := 262; -- Temperature out of range
    C_TEMP_REQUIRED     CONSTANT NUMBER := 263; -- Temperature is required
    C_WEIGHT_DESIRED    CONSTANT NUMBER := 264; -- Need weight for the return
    C_WEIGHT_OUT_OF_RANGE   CONSTANT NUMBER := 266; -- Weight out of range
    C_TRACK_TRUCK_ACCESSORY CONSTANT NUMBER := 360; -- Inbound Accessory tracking has not been done
    C_NO_LOC        CONSTANT NUMBER := 252; -- No location is found

    l_application_func swms_log.application_func%TYPE := 'DRIVER CHECKIN'; --9/28/21
    PACKAGE_NAME        CONSTANT   swms_log.program_name%TYPE := 'PL_DCI'; --9/28/21
    l_func_name  CONSTANT  swms_log.procedure_name%TYPE := 'auto_close_manifest';
    l_status               rf.status := rf.status_normal;
    l_msg                  swms_log.msg_text%TYPE;

 CURSOR OPN_CUR(v_days in varchar2) IS
 SELECT DISTINCT M.MANIFEST_NO 
   FROM MANIFESTS m
  WHERE m.MANIFEST_STATUS = 'OPN'
    --AND MANIFEST_CREATE_DT <= SYSDATE - v_days  -- 9/30/31 replace by next
	AND trunc(MANIFEST_CREATE_DT) <= trunc(SYSDATE - v_days)
    AND ( EXISTS (select 1
                  FROM returns r
                 WHERE R.MANIFEST_NO = M.MANIFEST_NO
                    AND R.STATUS = 'CMP' )
   OR NOT exists (
                select 1
                  FROM returns r
                 WHERE R.MANIFEST_NO = M.MANIFEST_NO) );
 BEGIN
        SELECT pl_common.f_get_syspar ( 'AUTO_MANIFEST_CLOSE', '7') 
          INTO  l_days
          FROM  dual; 
          DBMS_OUTPUT.PUT_LINE( 'AUTO close after #of days: '|| l_days);

        FOR  OPN_REC IN OPN_CUR(l_days) LOOP

           -- 9/28/21 add below block
           begin

               l_Status :=pl_dci.create_stc_for_pod(opn_rec.manifest_no);

               IF l_Status = rf.status_normal THEN
                  l_msg := 'Creation of STC successful for manifest# ['
                       || opn_rec.manifest_no|| ']';
                  pl_log.ins_msg('INFO', l_func_name, l_msg, null, null, l_application_func, PACKAGE_NAME);
               ELSE
                  l_msg := 'Creation of STC FAILED for manifest# ['|| opn_rec.manifest_no|| ']';
                  pl_log.ins_msg('WARN', l_func_name, l_msg, null, null, l_application_func, PACKAGE_NAME);
               END IF;
            exception
                WHEN OTHERS THEN
                    l_Status := rf.status_data_error;
                    l_msg := 'Unexpected ERROR in Creation of STC for manifest# ['
                     || opn_rec.manifest_no|| ']';
                    pl_log.ins_msg('FATAL', l_func_name, l_msg, SQLCODE, SUBSTR(SQLERRM, 1, 500), l_application_func, PACKAGE_NAME);
            end;


           BEGIN
            pl_dci.close_manifest(
            opn_rec.manifest_no   ,
            sLMStr1,
            sMsg1,
            iStatus);


            IF (iStatus = C_NO_LOC ) THEN

            iStatus := C_NORMAL;           /* Need to treat this as warning */

            ELSIF (
                 iStatus != C_TEMP_REQUIRED AND
                 iStatus != C_TEMP_OUT_OF_RANGE AND
            /* Inbound Accessory changes to handle warning */
                 iStatus != C_TRACK_TRUCK_ACCESSORY)  THEN/* error but not TEMP */

                 null; -- add 9/28/21

                --DBMS_OUTPUT.PUT_LINE(
                  --  'DCI Close_Mf has errs. MF:'||
                    --  opn_rec.manifest_no||iStatus);

            END IF;

      /* We use close mf to check for bad data including TEMP check, range ...
     * and if things are OK, we SAVE if the RF sent override_option = 'Y',
     * if not, we get the summary and return after ROLL BACK
     */
            IF  iStatus = 0  THEN

                   COMMIT;

            ELSE

                   ROLLBACK;

            END IF;


            EXCEPTION WHEN OTHERS THEN

            DBMS_OUTPUT.PUT_LINE( 
                'pl_dci.close_manifest stat. MF: ' ||
                opn_rec.manifest_no ||
                sqlcode||
                sqlerrm);
            ROLLBACK;

        END;

            sLMStr1 := null;
            sMsg1   := null;

        END LOOP;




 END;


PROCEDURE client_close_manifest (
  pszValue1     IN  inv.logi_loc%TYPE,
  poszLMStr     OUT VARCHAR2,
  poszMsg       OUT VARCHAR2,
  poiNumRtns        OUT NUMBER,
  poiNumCurRtns     OUT NUMBER,
  poiNumWeightRtns  OUT NUMBER,
  poiNumTempRtns    OUT NUMBER,
  poszRtns      OUT VARCHAR2,
  poiStatus     OUT NUMBER,
  pszValue2     IN  inv.logi_loc%TYPE DEFAULT NULL,
  pszValue3     IN  inv.logi_loc%TYPE DEFAULT C_DFT_CPV,
  piNextRecSet      IN  NUMBER DEFAULT 0,
  piRecTyp      IN  NUMBER DEFAULT 0) IS
  iMfNo         manifests.manifest_no%TYPE := NULL;
  iIndex        NUMBER := 0;
  tabTypRtns        tabTypReturns;
  iNumRtns      NUMBER := 0;
  iNumCurRtns       NUMBER := 0;
  iNumWeightRtns    NUMBER := 0;
  iNumTempRtns      NUMBER := 0;
  rwTypRtn      returns%ROWTYPE := NULL;
  tabTypRsns        tabTypReasons;
  rwTypPutlst       putawaylst%ROWTYPE := NULL;
  CURSOR c_get_becls_rtn_info(cpiMfNo manifests.manifest_no%TYPE) IS
    SELECT manifest_no, route_no, stop_no, rec_type,
           DECODE(INSTR(obligation_no, 'L'), 0, obligation_no,
                  SUBSTR(obligation_no,
                         1, INSTR(obligation_no, 'L') - 1)) obligation_no,
           prod_id, cust_pref_vendor, return_reason_cd, returned_qty,
           returned_split_cd, catchweight, disposition, returned_prod_id,
           erm_line_id, shipped_qty, shipped_split_cd, cust_id, temperature
    FROM returns
    WHERE manifest_no = cpiMfNo;
BEGIN
  poszLMStr := NULL;
  poszMsg := NULL;
  poiNumRtns := 0;
  poiNumCurRtns := 0;
  poiNumWeightRtns := 0;
  poiNumTempRtns := 0;
  poszRtns := NULL;
  poiStatus := C_NORMAL;

  -- See if the input is a license plate
  BEGIN
    SELECT TO_NUMBER(SUBSTR(rec_id, 2)) INTO iMfNo
    FROM putawaylst
    WHERE pallet_id = pszValue1;
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      iMfNo := NULL;
    WHEN OTHERS THEN
      poiStatus := SQLCODE;
      RETURN;
  END;

  -- Check if the inputs are invoice/item/cust_pref_vendor or just manifest #
  IF iMfNo IS NULL THEN
    BEGIN
      SELECT manifest_no INTO iMfNo
      FROM manifest_dtls
      WHERE ((manifest_no = TO_NUMBER(pszValue1)) OR
             ((DECODE(INSTR(obligation_no, 'L'), 0, obligation_no,
                      SUBSTR(obligation_no, 1, INSTR(obligation_no, 'L') - 1)) =
               pszValue1) AND
              (prod_id = pszValue2) AND
              (cust_pref_vendor = pszValue3)))
      AND   ROWNUM = 1;
    EXCEPTION
      WHEN NO_DATA_FOUND THEN
        poiStatus := C_NO_MF_INFO;
        RETURN;
      WHEN OTHERS THEN
        poiStatus := SQLCODE;
        RETURN;
    END;
  END IF;

  IF piNextRecSet = 0 THEN
    -- "Close manifest" action should be performed
    close_manifest(iMfNo, poszLMStr, poszMsg, poiStatus);
  ELSE
    -- Get return information back to caller before "close manifest" action
    -- is performed. Give everything back regardless whether the found return
    -- has an invalid reason code, pickup return has zero returned qty or
    -- returned item has been putawayed
    get_range_returns(piNextRecSet, TO_CHAR(iMfNo),
                      iNumRtns, iNumCurRtns, iNumWeightRtns, iNumTempRtns,
                      tabTypRtns, 1, NULL, NULL, NULL, piRecTyp);
    -- Send the retrieved records back to the caller
    poiNumRtns := iNumRtns;
    poiNumCurRtns := iNumCurRtns;
    poiNumTempRtns := iNumTempRtns;
    poiStatus := C_NORMAL;
  END IF;
EXCEPTION
  WHEN OTHERS THEN
    poiStatus := SQLCODE;
END;
-- -----------------------------------------------------------------------------

PROCEDURE invoice_return (
  pszInv    IN  manifest_dtls.obligation_no%TYPE,
  pszRsn    IN  reason_cds.reason_cd%TYPE,
  poiMinLine    OUT returns.erm_line_id%TYPE,
  poszMsg   OUT VARCHAR2,
  poszLMStr OUT VARCHAR2,
  poiStatus OUT NUMBER,
  piUsePrtOpt   IN  NUMBER DEFAULT 0) IS
  szRoute       manifests.route_no%TYPE := NULL;
  szInv         manifest_dtls.obligation_no%TYPE := NULL;
  szOrigInv     manifest_dtls.orig_invoice%TYPE := NULL;
  szStatusRecType   manifest_dtls.rec_type%TYPE := NULL;
  iMfNo         manifests.manifest_no%TYPE := NULL;
  szMfStatus        VARCHAR2(10) := NULL;
  szInvRtnGroup     reason_cds.reason_group%TYPE := 'WIN';
  iRtnCnt       NUMBER := 0;
  iRtiCnt       NUMBER := 0;
  iClsCnt       NUMBER := 0;
  tabTypRsn     tabTypReasons;
  szRecType     manifest_dtls.rec_type%TYPE := NULL;
  szPkpRsn      reason_cds.reason_cd%TYPE := NULL;
  blnPkupNotFound   BOOLEAN := FALSE;
  iMaxLine      returns.erm_line_id%TYPE := 0;
  rwTypRtn      returns%ROWTYPE := NULL;
  rwTypPutlst       putawaylst%ROWTYPE := NULL;
  iStatus       NUMBER := C_NORMAL;
  iIndex        NUMBER := 0;
  rwTypPrtQueue     print_queues%ROWTYPE := NULL;
  szLMStr       VARCHAR2(4000) := NULL;
  iLockMf       manifests.manifest_no%TYPE := NULL;
  CURSOR c_get_rtn_invoice (cpiMfNo returns.manifest_no%TYPE,
                            cpszInv returns.obligation_no%TYPE) IS
    SELECT DECODE(INSTR(r.obligation_no, 'L'), 0, r.obligation_no,
                 SUBSTR(r.obligation_no, 1,
                        INSTR(r.obligation_no, 'L') - 1)) obligation_no,
           r.prod_id, r.cust_pref_vendor, r.returned_prod_id, r.rec_type,
           r.return_reason_cd, r.returned_qty, r.returned_split_cd,
           r.catchweight, r.temperature, r.erm_line_id,
           r.route_no, r.stop_no, r.shipped_qty, r.shipped_split_cd, r.cust_id,
           d.reason_group, r.disposition
    FROM returns r, reason_cds d, pm p
    WHERE r.manifest_no = cpiMfNo
    AND   NVL(r.returned_qty, 0) <> 0
    AND   r.returned_prod_id IS NOT NULL
    AND   r.return_reason_cd = d.reason_cd
    AND   d.reason_cd_type = 'RTN'
    AND   d.reason_group <> 'DMG'
    AND   DECODE(INSTR(r.obligation_no, 'L'), 0, r.obligation_no,
                 SUBSTR(r.obligation_no, 1,
                        INSTR(r.obligation_no, 'L') - 1)) = cpszInv
    AND   p.prod_id = r.returned_prod_id
    AND   p.cust_pref_vendor = r.cust_pref_vendor
    AND   NOT EXISTS (SELECT 1
                      FROM erd
                      WHERE erm_id = 'S' || TO_CHAR(r.manifest_no)
                      AND   erm_line_id = r.erm_line_id)
    ORDER BY r.erm_line_id;
  CURSOR c_get_lock_rtn(cpiMfNo manifests.manifest_no%TYPE) IS
    SELECT manifest_no
    FROM returns
    WHERE manifest_no = cpiMfNo
    FOR UPDATE NOWAIT;
BEGIN
  poiMinLine := 0;
  poszMsg   := NULL;
  poszLMStr := NULL;
  poiStatus := C_NORMAL;

  -- Don't do anything if the corresponding manifest has been closed or error
  -- occurred or cannot find the invoice at all
  DBMS_OUTPUT.PUT_LINE('Inv = ' || pszInv);
  get_mf_status(pszInv, szInv, szOrigInv, iMfNo, szStatusRecType,
                szRoute, szMfStatus);
  DBMS_OUTPUT.PUT_LINE('After get_mf_status. OutInv = ' || szInv ||
    ', Orig Inv = ' || szOrigInv || ', MF = ' || iMfNo ||
    ', Status = ' || szMfStatus);
  pl_text_log.ins_msg('WARN', 'invoice_return',
    'After get_mf_status. OutInv = ' || szInv ||
    ', Orig Inv = ' || szOrigInv || ', MF = ' || iMfNo ||
    ', Status = ' || szMfStatus, NULL, NULL);

  IF UPPER(SUBSTR(szMfStatus, 1, 1)) NOT BETWEEN 'A' AND 'Z' THEN
    poiStatus := C_INV_MF;
    RETURN;
  ELSIF szMfStatus = C_MF_CLO_STR THEN
    poiStatus := C_MF_HAS_CLOSED;
    RETURN;
  END IF;

  -- Check if invoice has been returned before
  BEGIN
    SELECT SUM(DECODE(manifest_dtl_status, 'RTI', 1, 0)),
           SUM(DECODE(manifest_dtl_status, 'RTN', 1, 0)),
           SUM(DECODE(manifest_dtl_status, 'CLS', 1, 0)),
           MAX(rec_type)
      INTO iRtiCnt, iRtnCnt, iClsCnt, szRecType
      FROM manifest_dtls
      WHERE obligation_no = szInv
      AND   manifest_no = iMfNo;
  EXCEPTION
    WHEN OTHERS THEN
      NULL;
  END;
  IF iRtnCnt <> 0 THEN
    poiStatus := C_INV_RTN;
    RETURN;
  ELSIF iRtiCnt <> 0 OR iClsCnt <> 0 THEN
    poiStatus := C_INV_RTI_CLS;
    RETURN;
  END IF;

  -- Check if the input reason code belongs to invoice return
  tabTypRsn := get_reason_info('ALL', szInvRtnGroup, pszRsn);
  IF tabTypRsn.FIRST IS NULL THEN
    poiStatus := C_INV_RSN;
    RETURN;
  END IF;

  -- The input invoice might belong to a pickup. Special processing for it
  IF szRecType = 'P' THEN
--    BEGIN
--      SELECT return_reason_cd INTO szPkpRsn
--      FROM returns
--      WHERE manifest_no = iMfNo
--      AND   DECODE(INSTR(obligation_no, 'L'), 0, obligation_no,
--                   SUBSTR(obligation_no, 1,
--                          INSTR(obligation_no, 'L') - 1)) = pszInv
--      AND   rec_type = 'P'
--      AND   ROWNUM = 1;
--    EXCEPTION
--      WHEN NO_DATA_FOUND THEN
--        szPkpRsn := pszRsn;
--      WHEN OTHERS THEN
--        poiStatus := SQLCODE;
--        RETURN;
--    END;
--    IF pszRsn <> szPkpRsn THEN
--      -- User provided reason code is not the same as the existing one in
--      -- the pickup invoice. Notify user
--      poiStatus := C_INV_RSN;
--      RETURN;
--    END IF;
    BEGIN
      -- Update the pickup return information according to manifest details
      UPDATE returns r
        SET (returned_prod_id, returned_qty, returned_split_cd,
             shipped_qty, shipped_split_cd, upd_source) =
          (SELECT md.prod_id, shipped_qty, shipped_split_cd,
                  shipped_qty, shipped_split_cd, 'RF'
           FROM manifest_dtls md
           WHERE  md.manifest_no = r.manifest_no
           AND  md.stop_no = r.stop_no
           AND  md.obligation_no = r.obligation_no
           AND  md.rec_type = r.rec_type
           AND  md.prod_id = r.prod_id
           AND  md.cust_pref_vendor = r.cust_pref_vendor
           AND  md.shipped_split_cd = r.shipped_split_cd)
        WHERE DECODE(INSTR(r.obligation_no, 'L'), 0, r.obligation_no,
                   SUBSTR(r.obligation_no, 1,
                          INSTR(r.obligation_no, 'L') - 1)) = pszInv
        AND   r.manifest_no = iMfNo
        AND   r.rec_type = 'P';
      pl_text_log.ins_msg('WARN', 'invoice_return',
        'Inv = ' || szInv ||
        ', Orig Inv = ' || szOrigInv || ', MF = ' || iMfNo ||
        ', #pickupUpd[' || TO_CHAR(SQL%ROWCOUNT) || ']', NULL, NULL);
    EXCEPTION
      WHEN NO_DATA_FOUND THEN
        blnPkupNotFound := TRUE;
      WHEN OTHERS THEN
        poiStatus := SQLCODE;
        RETURN;
    END;
  END IF;

  -- Lock the RETURNS table so next erm_line_id can be generated
  OPEN c_get_lock_rtn(iMfNo);

  -- Insert new returns according to manifest details if invoice record type
  -- is other than 'P' or 'D'. For 'D' the returns should be already there
  IF szRecType <> 'D' AND (szRecType <> 'P' OR blnPkupNotFound) THEN
    BEGIN
      SELECT NVL(MAX(NVL(erm_line_id, 0)), 0) INTO iMaxLine
      FROM returns
      WHERE manifest_no = iMfNo;
    EXCEPTION
      WHEN OTHERS THEN
        iMaxLine := 0;                     
    END;
    poiMinLine := iMaxLine + 1;
    BEGIN
      INSERT INTO returns
        (manifest_no, route_no, stop_no, rec_type, obligation_no,
         prod_id, cust_pref_vendor, returned_prod_id, return_reason_cd,
         returned_qty, returned_split_cd, shipped_split_cd, shipped_qty,
         erm_line_id, add_source)
      SELECT iMfNo, m.route_no, md.stop_no, md.rec_type, pszInv,
             md.prod_id, md.cust_pref_vendor, md.prod_id, pszRsn,
             md.shipped_qty, md.shipped_split_cd, md.shipped_split_cd,
             md.shipped_qty,
             iMaxLine + ROWNUM,
             'RF'
      FROM manifests m, manifest_dtls md
      WHERE md.manifest_no = m.manifest_no
      AND   NVL(md.manifest_dtl_status,' ') NOT IN ('RTI', 'RTN')
      AND   (md.obligation_no = pszInv OR md.orig_invoice = pszInv)
      AND   md.manifest_no = iMfNo
      AND   md.shipped_qty <> 0;
      pl_text_log.ins_msg('WARN', 'invoice_return',
        'Inv = ' || szInv ||
        ', Orig Inv = ' || szOrigInv || ', MF = ' || iMfNo ||
        ', minLine[' || TO_CHAR(iMaxLine + 1) || '] #insRtn[' ||
        TO_CHAR(SQL%ROWCOUNT) || ']', NULL, NULL);
    EXCEPTION
      WHEN OTHERS THEN
        poiStatus := SQLCODE;
        ROLLBACK;
        RETURN;
    END;
  END IF;

  -- If it's invoice delete, update the invoice items to the returned items
  IF szRecType = 'D' THEN
    BEGIN
      UPDATE returns
        SET returned_prod_id = prod_id,
            upd_source = 'RF'
        WHERE manifest_no = iMfNo
        AND   rec_type = 'D'
        AND   DECODE(INSTR(obligation_no, 'L'), 0, obligation_no,
                     SUBSTR(obligation_no, 1,
                            INSTR(obligation_no, 'L') - 1)) = szInv;
      pl_text_log.ins_msg('WARN', 'invoice_return',
        'Inv = ' || szInv ||
        ', Orig Inv = ' || szOrigInv || ', MF = ' || iMfNo ||
        ', recType=D #updRtn[' || TO_CHAR(SQL%ROWCOUNT) || ']', NULL, NULL);
    EXCEPTION
      WHEN NO_DATA_FOUND THEN
        NULL;
      WHEN OTHERS THEN
        poiStatus := SQLCODE;
        ROLLBACK;
        RETURN;
    END;
  END IF;

  -- Create returned PO header for the invoice if not exists
  iStatus := create_erm(iMfNo, szInvRtnGroup);
  pl_text_log.ins_msg('WARN', 'invoice_return',
    'Inv = ' || szInv ||
    ', Orig Inv = ' || szOrigInv || ', MF = ' || iMfNo ||
    ', group[' || szInvRtnGroup || '] ermCreateStatus[' ||
    TO_CHAR(iStatus) || ']', NULL, NULL);
  IF iStatus <> C_NORMAL THEN
    poiStatus := SQLCODE;
    ROLLBACK;
    RETURN;
  END IF;

  -- Create returned PO details and putaway tasks for the invoice
  iStatus := C_NORMAL;
  FOR cgri IN c_get_rtn_invoice(iMfNo, szInv) LOOP
    iIndex := iIndex + 1;
    rwTypRtn := NULL;
    rwTypRtn.manifest_no := iMfNo;
    rwTypRtn.rec_type := cgri.rec_type;
    rwTypRtn.obligation_no := cgri.obligation_no;
    rwTypRtn.prod_id := cgri.prod_id;
    rwTypRtn.cust_pref_vendor := cgri.cust_pref_vendor;
    rwTypRtn.return_reason_cd := cgri.return_reason_cd;
    rwTypRtn.returned_qty := cgri.returned_qty;
    rwTypRtn.returned_split_cd := cgri.returned_split_cd;
    rwTypRtn.catchweight := cgri.catchweight;
    rwTypRtn.returned_prod_id := cgri.returned_prod_id;
    rwTypRtn.erm_line_id := cgri.erm_line_id;
    rwTypRtn.temperature := cgri.temperature;
    iStatus := create_erd(szInvRtnGroup, rwTypRtn);
    IF iStatus = C_NORMAL THEN
      create_puttask(iMfNo, szInvRtnGroup, rwTypRtn,
                     rwTypPutlst, poszMsg, szLMStr, iStatus);
      IF iStatus <> C_NORMAL THEN
        poiStatus := iStatus;
        ROLLBACK;
        RETURN;
      END IF;
      poszLMStr := poszLMStr || szLMStr;
      IF szLMStr IS NOT NULL THEN
        poszLMStr := poszLMStr || '|';
      END IF;
    END IF;
  END LOOP;

  -- Update manifest detail status to indicate invoice is done
  IF iStatus = C_NORMAL THEN
    BEGIN
      UPDATE manifest_dtls d
        SET d.manifest_dtl_status = 'RTI'
        WHERE d.manifest_no = iMfNo
        AND   DECODE(INSTR(d.obligation_no, 'L'), 0, d.obligation_no,
                     SUBSTR(d.obligation_no,
                            1, INSTR(d.obligation_no, 'L') - 1)) = szInv
        AND   d.shipped_qty > 0;
    EXCEPTION
      WHEN NO_DATA_FOUND THEN
        NULL;
      WHEN OTHERS THEN
        poiStatus := SQLCODE;
        ROLLBACK;
        RETURN;
    END;
  END IF;

  -- Unlock the RETURNS table
  IF c_get_lock_rtn%ISOPEN THEN
    CLOSE c_get_lock_rtn;
  END IF;

  -- Creation of returns for the invoice is done without problem. Now check
  -- on the print option. Only check on the print option when it's set.
  pl_text_log.ins_msg('WARN', 'invoice_return',
    'Inv = ' || szInv ||
    ', Orig Inv = ' || szOrigInv || ', MF = ' || iMfNo ||
    ', printOpt[' || TO_CHAR(piUsePrtOpt) || '] idx[' || TO_CHAR(iIndex) ||
    '/' || TO_CHAR(C_PRT_RANGE_MIN) || ']', NULL, NULL);
  IF piUsePrtOpt <> 0 THEN
    IF iIndex > C_PRT_RANGE_MIN THEN
      -- Get user's default printer if # of returns more than set minimum
      rwTypPrtQueue := get_default_printer_info;
      pl_text_log.ins_msg('WARN', 'invoice_return',
        'Inv = ' || szInv ||
        ', Orig Inv = ' || szOrigInv || ', MF = ' || iMfNo ||
        ', printQueue[' || rwTypPrtQueue.system_queue || ']', NULL, NULL);
      IF rwTypPrtQueue.system_queue IS NULL THEN
        poiStatus := C_NO_DFT_PRINTER;
        RETURN;
      END IF;
    END IF;
  END IF;

  poiStatus := C_NORMAL;
END;
-- -----------------------------------------------------------------------------

PROCEDURE client_invoice_return (
  piNextRecSet  IN  NUMBER,
  pszInv    IN  manifest_dtls.obligation_no%TYPE,
  pszRsn    IN  reason_cds.reason_cd%TYPE,
  poszMsg   OUT VARCHAR2,
  poszLMStr OUT VARCHAR2,
  poiNumRtns    OUT NUMBER,
  poiNumCurRtns OUT NUMBER,
  poiNumTemps   OUT NUMBER,
  poszRtns  OUT VARCHAR2,
  poiStatus OUT NUMBER,
  piUsePrtOpt   IN  NUMBER DEFAULT 0) IS
  iMinLine      returns.erm_line_id%TYPE := 0;
  tabTypRtns        tabTypReturns;
  iStatus       NUMBER := C_NORMAL;
  iNumRtns      NUMBER := 0;
  iNumActRtns       NUMBER := 0;
  iNumWeightRtns    NUMBER := 0;
  iNumTempRtns      NUMBER := 0;
BEGIN
  poszMsg := NULL;
  poszLMStr := NULL;
  poiNumRtns := 0;
  poiNumCurRtns := 0;
  poiNumTemps := 0;
  poszRtns := NULL;
  poiStatus := C_NORMAL;

  IF piNextRecSet = 0 THEN
    -- User requests the system to do invoice return
    invoice_return(pszInv, pszRsn, iMinLine, poszMsg, poszLMStr, iStatus,
                   piUsePrtOpt);
    IF iStatus <> C_NORMAL THEN
      -- Error occurred during invoice return generation
      poiStatus := iStatus;
      RETURN;
    ELSE
      -- Creation of returns OK for the invoice. Retrieve them and send them
      -- back to the caller according to the page size and it's up to the
      -- caller to do something about them. Since this is for whole invoice
      -- return, all returns in the invoice are saleable and returns should
      -- have nonzero returned qty and valid reason codes.
      get_range_returns(iMinLine, pszInv, iNumRtns, iNumActRtns,
                        iNumWeightRtns, iNumTempRtns, tabTypRtns, 1,
                        NULL, NULL, NULL, 0, 'SALE');
    END IF;
  ELSE
    -- User requests to get records for the invoice just processed
    get_range_returns(piNextRecSet, pszInv, iNumRtns, iNumActRtns,
                      iNumWeightRtns, iNumTempRtns, tabTypRtns, 1,
                      NULL, NULL, NULL, 0, 'SALE');
  END IF;

  -- Send the retrieved records back to the caller
  assign_to_caller(tabTypRtns, poszRtns);

  poiNumRtns := iNumRtns;
  poiNumCurRtns := iNumActRtns;
  poiNumTemps := iNumTempRtns;
  poiStatus := C_NORMAL;
END;
-- -----------------------------------------------------------------------------

PROCEDURE update_invoice_return (
  pszInv    IN  manifest_dtls.obligation_no%TYPE,
  pszRsn    IN  reason_cds.reason_cd%TYPE,
  poiMinLine    OUT returns.erm_line_id%TYPE,
  poszMsg   OUT VARCHAR2,
  poszLMStr OUT VARCHAR2,
  poiStatus OUT NUMBER,
  piUsePrtOpt   IN  NUMBER DEFAULT 0) IS
  iStatus       NUMBER := C_NORMAL;
BEGIN
  poiMinLine := 0;
  poszMsg := NULL;
  poiStatus := C_NORMAL;

  -- Delete all returns related to the invoice first. Check also whether the
  -- invoice and the to-be-updated reason are already returned or not (1)
  iStatus := delete_invoice_return(pszInv, pszRsn, 1);
  IF iStatus <> C_NORMAL THEN
    poiStatus := iStatus;
    RETURN;
  END IF;

  -- Recreate all returns using the new reason code. New license plates will
  -- be generated
  invoice_return(pszInv, pszRsn, poiMinLine, poszMsg, poszLMStr, poiStatus,
                 piUsePrtOpt);
EXCEPTION
  WHEN OTHERS THEN
    poiStatus := SQLCODE;
END;
-- -----------------------------------------------------------------------------

PROCEDURE client_update_invoice_return (
  piNextRecSet  IN  NUMBER,
  pszInv    IN  manifest_dtls.obligation_no%TYPE,
  pszRsn    IN  reason_cds.reason_cd%TYPE,
  poiMinLine    OUT returns.erm_line_id%TYPE,
  poszMsg   OUT VARCHAR2,
  poszLMStr OUT VARCHAR2,
  poiNumRtns    OUT NUMBER,
  poiNumCurRtns OUT NUMBER,
  poiNumTemps   OUT NUMBER,
  poszRtns  OUT VARCHAR2,
  poiStatus OUT NUMBER,
  piUsePrtOpt   IN  NUMBER DEFAULT 0) IS
  iStatus       NUMBER := C_NORMAL;
  iNumRtns      NUMBER := 0;
  iNumCurRtns       NUMBER := 0;
  iNumWeightRtns    NUMBER := 0;
  iNumTempRtns      NUMBER := 0;
  tabTypRtns        tabTypReturns;
BEGIN
  poiNumRtns := 0;
  poiNumCurRtns := 0;
  poiNumTemps := 0;
  poszRtns := NULL;
  poiStatus := C_NORMAL;

  IF piNextRecSet = 0 THEN
    -- Caller requests to perform invoice update action
    update_invoice_return(pszInv, pszRsn, poiMinLine, poszMsg, poszLMStr,
                          iStatus, piUsePrtOpt);
    IF iStatus <> C_NORMAL THEN
      poiStatus := iStatus;
      RETURN;
    END IF;
    IF poiMinLine = 0 THEN
      poiStatus := C_INV_INVNO;
      RETURN;
    END IF;
    -- Update invoice return ok. Retrieve the returns information up to
    -- C_RECS_PER_PAGE records
    get_range_returns(1, pszInv, iNumRtns, iNumCurRtns, iNumWeightRtns,
                      iNumTempRtns, tabTypRtns, 0, NULL, NULL, NULL, 0, 'SALE');
  ELSE
    -- Caller requests the next set of records that they just finish invoice
    -- return update action
    get_range_returns(piNextRecSet, pszInv, iNumRtns, iNumCurRtns,
                      iNumWeightRtns, iNumTempRtns, tabTypRtns, 0, NULL, NULL,
                      NULL, 0, 'SALE');
  END IF;

  -- Sent the records back to caller
  assign_to_caller(tabTypRtns, poszRtns);
  poiNumRtns := iNumRtns;
  poiNumCurRtns := iNumCurRtns;
  poiNumTemps := iNumTempRtns;
  poiStatus := C_NORMAL;
EXCEPTION
  WHEN OTHERS THEN
    poiStatus := SQLCODE;
END;
-- -----------------------------------------------------------------------------

FUNCTION delete_invoice_return (
  pszInv    IN  manifest_dtls.obligation_no%TYPE,
  pszRsn    IN  reason_cds.reason_cd%TYPE DEFAULT NULL,
  piActionType  IN  NUMBER DEFAULT 0)
RETURN NUMBER IS
  iStatus       NUMBER := C_NORMAL;
  szInv         manifest_dtls.obligation_no%TYPE := NULL;
  szOrigInv     manifest_dtls.orig_invoice%TYPE := NULL;
  iMfNo         manifests.manifest_no%TYPE := NULL;
  szRecType     manifest_dtls.rec_type%TYPE := NULL;
  szRoute       returns.route_no%TYPE := NULL;
  szStatus      VARCHAR2(10) := NULL;   
  iNumRtns      NUMBER := 0;
  iNumCurRtns       NUMBER := 0;
  iNumWeightRtns    NUMBER := 0;
  iNumTempRtns      NUMBER := 0;
  tabTypRtns        tabTypReturns;
  iIndex        NUMBER := 0;
  iRtnCnt       NUMBER := 0;
  rwTypRtn      returns%ROWTYPE := NULL;
  CURSOR c_get_mf_dtls(cpiMfNo  manifests.manifest_no%TYPE,
                       cpszInv  manifest_dtls.obligation_no%TYPE) IS
    SELECT rowid
    FROM manifest_dtls
    WHERE manifest_no = cpiMfNo
    AND   DECODE(INSTR(obligation_no, 'L'),
                 0, obligation_no,
                 SUBSTR(obligation_no, 1, INSTR(obligation_no, 'L') - 1)) =
          cpszInv
    AND   NVL(shipped_qty, 0) = 0;
BEGIN
  -- Check the status of the invoice
  get_mf_status(pszInv, szInv, szOrigInv, iMfNo, szRecType, szRoute, szStatus);
  DBMS_OUTPUT.PUT_LINE('Mf Status: ' || szStatus || ' mf ' || 
    TO_CHAR(iMfNo));
  IF CHR(ASCII(SUBSTR(szStatus,1,1))) NOT BETWEEN 'A' AND 'Z' THEN
    -- It's a positive user error code or Oracle negative error code
    RETURN TO_NUMBER(szStatus);
  ELSE
    IF szStatus = C_MF_CLO_STR THEN
      RETURN C_MF_HAS_CLOSED;
    END IF;
  END IF;

  -- Retrieve all returns related to the invoice (saleable only)
  get_range_returns(-1, pszInv, iNumRtns, iNumCurRtns, iNumWeightRtns,
                    iNumTempRtns, tabTypRtns, 0, NULL, NULL, NULL, 0, 'SALE');
  IF tabTypRtns.COUNT = 0 THEN
    RETURN C_INV_INVNO;
  END IF;
  DBMS_OUTPUT.PUT_LINE ('After Get_Range_Returns: ' || TO_CHAR(iNumRtns));
  FOR iIndex IN 1 .. tabTypRtns.COUNT LOOP
    IF tabTypRtns(iIndex).reason_code = pszRsn THEN
      iRtnCnt := iRtnCnt + 1;
    END IF;
    IF tabTypRtns(iIndex).putaway_put = 'Y' THEN
      -- At least one return in the invoice has been putawayed. No update
      -- should be allowed
      RETURN C_PUT_DONE;
    END IF;
  END LOOP;
  IF (piActionType <> 0) AND (iRtnCnt = tabTypRtns.COUNT) THEN
    -- To-be-updated reason is the same as the current reason in the returns
    -- of the invoice. Nothing needs to be changed. Only check this if the
    -- action is to update the invoice
    RETURN C_INV_RTN;
  END IF;

  -- Delete all returns that related to the invoice, including PUTAWAYLST, ERM
  -- and ERD
  DBMS_OUTPUT.PUT_LINE ('Before FOR Loop. Count = ' || tabTypRtns.COUNT);
  FOR iIndex IN 1 .. tabTypRtns.COUNT LOOP
    rwTypRtn := NULL;
    rwTypRtn.manifest_no := iMfNo;
    rwTypRtn.obligation_no := tabTypRtns(iIndex).obligation_no;
    rwTypRtn.rec_type := tabTypRtns(iIndex).rec_type;
    rwTypRtn.erm_line_id := tabTypRtns(iIndex).erm_line_id;
    rwTypRtn.prod_id := tabTypRtns(iIndex).prod_id;
    rwTypRtn.cust_pref_vendor := tabTypRtns(iIndex).cust_pref_vendor;
    rwTypRtn.returned_prod_id := tabTypRtns(iIndex).returned_prod_id;
    rwTypRtn.return_reason_cd := tabTypRtns(iIndex).reason_code;
    rwTypRtn.returned_qty := tabTypRtns(iIndex).returned_qty;
    rwTypRtn.returned_split_cd := tabTypRtns(iIndex).returned_split_cd;
    DBMS_OUTPUT.PUT_LINE('mf ' || TO_CHAR(iMfNo) || ' ob ' ||
      rwTypRtn.obligation_no || ' p ' || rwTypRtn.prod_id || ' r ' ||
      rwTypRtn.return_reason_cd || ' l ' || TO_CHAR(rwTypRtn.erm_line_id));
    iStatus := delete_return(rwTypRtn);
    IF iStatus <> C_NORMAL THEN
      RETURN iStatus;
    END IF;
  END LOOP;

  FOR cgmd IN c_get_mf_dtls(iMfNo, pszInv) LOOP
    BEGIN
      UPDATE manifest_dtls
      SET manifest_dtl_status = 'OPN'
      WHERE rowid = cgmd.rowid;
    EXCEPTION
      WHEN NO_DATA_FOUND THEN
        NULL;
      WHEN OTHERS THEN
        RETURN SQLCODE;
    END;
  END LOOP;

  RETURN C_NORMAL;
EXCEPTION
  WHEN OTHERS THEN
    RETURN SQLCODE;
END;
-- -----------------------------------------------------------------------------

PROCEDURE tripmaster (
  piMfNo    IN  manifests.manifest_no%TYPE,
  pszInv    IN  manifest_dtls.obligation_no%TYPE DEFAULT NULL,
  poszMsg   OUT VARCHAR2,
  poszLMStr OUT VARCHAR2,
  poiStatus OUT NUMBER) IS
  szRoute       manifests.route_no%TYPE := NULL;
  iMfNo         manifests.manifest_no%TYPE := piMfNo;
  szInv         manifest_dtls.obligation_no%TYPE := NULL;
  szOrigInv     manifest_dtls.orig_invoice%TYPE := NULL;
  szMfStatus        VARCHAR2(10) := NULL;
  iStatus       NUMBER := C_NORMAL;
  rwTypRtn      returns%ROWTYPE := NULL;
  szMsg         VARCHAR2(300) := NULL;
  szRecType     manifest_dtls.rec_type%TYPE := NULL;
  rwTypPutlst       putawaylst%ROWTYPE := NULL;
  szLMStr       VARCHAR2(100) := NULL;
  CURSOR c_get_undone_rtns(cpiMfNo manifests.manifest_no%TYPE,
                           cpszInv manifest_dtls.obligation_no%TYPE) IS
    SELECT r.rowid, r.stop_no, r.rec_type,
           DECODE(INSTR(r.obligation_no, 'L'),
                  0, r.obligation_no,
                  SUBSTR(r.obligation_no,
                         1, INSTR(r.obligation_no, 'L') - 1)) obligation_no,
           r.erm_line_id,
           rc.reason_group, r.return_reason_cd,
           r.prod_id, r.cust_pref_vendor,
           DECODE(r.returned_prod_id,
                  NULL, DECODE(rc.reason_group, 'MPR', NULL, 'MPK', NULL,
                               r.prod_id),
                  r.returned_prod_id) returned_prod_id,
       r.returned_qty, r.returned_split_cd,
           r.catchweight, r.temperature,
       r.shipped_qty, r.shipped_split_cd,
           DECODE(rc.reason_group,
                  'DMG', 'N', 'STM', 'N', p.catch_wt_trk) catch_wt_trk,
           DECODE(rc.reason_group,
                  'DMG', 'N', 'STM', 'N', p.temp_trk) temp_trk
    FROM reason_cds rc, returns r, pm p
    WHERE rc.reason_cd = r.return_reason_cd
    AND   r.manifest_no = cpiMfNo
    AND   ((cpszInv IS NULL) OR 
           ((cpszInv IS NOT NULL) AND
            (DECODE(INSTR(r.obligation_no, 'L'),
                    0, r.obligation_no,
                    SUBSTR(r.obligation_no,
                           1, INSTR(r.obligation_no, 'L') - 1)) = cpszInv)))
    AND   rc.reason_group NOT IN ('STM', 'MPK')
    AND   NVL(r.returned_qty, 0) <> 0
    AND   p.prod_id = DECODE(rc.reason_group,
                             'MPR', r.returned_prod_id,
                             'MPK', r.returned_prod_id,
                             r.prod_id)
    AND   p.cust_pref_vendor = r.cust_pref_vendor
    AND   NOT EXISTS (SELECT 1
                      FROM erd d
                      WHERE SUBSTR(d.erm_id, 2) = TO_CHAR(cpiMfNo)
                      AND   NVL(d.order_id, ' ') =
                              DECODE(r.obligation_no,
                                     NULL, ' ',
                                     DECODE(INSTR(r.obligation_no, 'L'),
                                            0, r.obligation_no,
                                            SUBSTR(r.obligation_no, 1,
                                                   INSTR(r.obligation_no, 'L') -
                                                   1)))
                      AND   d.prod_id = r.returned_prod_id
                      AND   d.cust_pref_vendor = r.cust_pref_vendor
                      AND   d.erm_line_id = r.erm_line_id)
    FOR UPDATE OF r.returned_prod_id;
BEGIN
  poiStatus := C_NORMAL;
  poszMsg := NULL;
  poszLMStr := NULL;

  IF piMfNo IS NULL AND pszInv IS NULL THEN
    RETURN;
  END IF;

  -- Check if manifest has been closed
  IF pszInv IS NOT NULL THEN
    -- Tripmaster by invoice instead of manifest #. Check the status and also
    -- get the manifest #
    get_mf_status(pszInv, szInv, szOrigInv, iMfNo, szRecType,
                  szRoute, szMfStatus);
    IF piMfNo IS NOT NULL AND piMfNo <> iMfNo THEN
      poiStatus := C_INV_INVNO;
      RETURN;
    END IF;
  ELSE
    -- Tripmaster by manifest # instead of invoice #
    get_mf_status(piMfNo, szRoute, szMfStatus);
    szInv := NULL;
    iMfNo := piMfNo;
  END IF;
  IF CHR(ASCII(SUBSTR(szMfStatus,1,1))) NOT BETWEEN 'A' AND 'Z' THEN
    -- It's a positive user error code or Oracle negative error code
    poiStatus := TO_NUMBER(szMfStatus);
    RETURN;
  ELSE
    IF szMfStatus = C_MF_CLO_STR THEN
      poiStatus := C_MF_HAS_CLOSED;
      RETURN;
    END IF;
  END IF;

  iStatus := C_NORMAL;
  FOR cgur IN c_get_undone_rtns(iMfNo, szInv) LOOP
    rwTypRtn := NULL;
    rwTypRtn.manifest_no := iMfNo;
    rwTypRtn.obligation_no := cgur.obligation_no;
    rwTypRtn.rec_type := cgur.rec_type;
    rwTypRtn.prod_id := cgur.prod_id;
    rwTypRtn.cust_pref_vendor := cgur.cust_pref_vendor;
    rwTypRtn.returned_prod_id := cgur.returned_prod_id;
    rwTypRtn.erm_line_id := cgur.erm_line_id;
    rwTypRtn.return_reason_cd := cgur.return_reason_cd;
    rwTypRtn.returned_qty := cgur.returned_qty;
    rwTypRtn.returned_split_cd := cgur.returned_split_cd;
    rwTypRtn.catchweight := cgur.catchweight;
    rwTypRtn.temperature := cgur.temperature;

    -- Update returned_prod_id for non-mispicked return
    BEGIN
      UPDATE returns
        SET returned_prod_id = cgur.prod_id,
            upd_source = 'RF'
        WHERE returned_prod_id IS NULL
        AND   cgur.reason_group NOT IN ('MPR', 'MPK')
        AND   rowid = cgur.rowid;
    EXCEPTION
      WHEN OTHERS THEN
        NULL;
    END;

    -- Created returned PO header
    iStatus := create_erm(iMfNo, cgur.reason_group);
    IF iStatus <> C_NORMAL THEN
      poiStatus := iStatus;
      EXIT;
    END IF;

    -- Created returned PO detail
    iStatus := create_erd(cgur.reason_group, rwTypRtn);
    IF iStatus <> C_NORMAL THEN
      poiStatus := iStatus;
      EXIT;
    END IF;

    -- Create putaway task
    create_puttask(iMfNo, cgur.reason_group, rwTypRtn,
                   rwTypPutlst, szMsg, szLMStr, iStatus);
    IF iStatus <> C_NORMAL THEN
      poiStatus := iStatus;
      EXIT;
    END IF;
    poszLMStr := poszLMStr || szLMStr;
    IF szLMStr IS NOT NULL THEN
      poszLMStr := poszLMStr || '|';
    END IF;
  END LOOP;

  IF iStatus = C_NORMAL THEN
    -- Set manifest detail statuses for those that have been returned
    BEGIN
      UPDATE manifest_dtls m
        SET m.manifest_dtl_status = 'RTN'
        WHERE m.manifest_no = iMfNo
        AND   EXISTS (SELECT 1
                      FROM returns r
                      WHERE r.manifest_no = m.manifest_no
                      AND   r.stop_no = m.stop_no
                      AND   r.obligation_no = m.obligation_no
                      AND   r.rec_type = m.rec_type
                      AND   r.prod_id = m.prod_id
                      AND   r.cust_pref_vendor = m.cust_pref_vendor
                      AND   (r.shipped_split_cd IS NULL OR
                             r.shipped_split_cd = m.shipped_split_cd)
                      AND  r.returned_qty IS NOT NULL)
    AND   m.shipped_qty > 0;
    EXCEPTION
      WHEN NO_DATA_FOUND THEN
        NULL;
      WHEN OTHERS THEN
        poiStatus := SQLCODE;
    END;
  END IF;

  poszMsg := szMsg;
END;
-- -------------------------------------------------------------------------------
PROCEDURE validate_tripmaster (
            i_manifest_no          IN  manifests.manifest_no%TYPE,
            o_exception_error      OUT VARCHAR2,
            o_returns_err_count    OUT NUMBER) IS

   l_object_name VARCHAR2(60) := 'pl_dci.validate_tripmaster';
   l_log_message VARCHAR2(80);
   l_count_bad_returns  number := 0;
   l_count_null_status  number := 0;

   CURSOR c_unprocessed_manifest_rtn(c_manifest_no manifests.manifest_no%TYPE) IS
      SELECT R.ROWID RID
        FROM RETURNS R
        WHERE  nvl(STATUS, 'VAL') ='VAL' 
        AND MANIFEST_NO = c_manifest_no
        AND nvl(LOCK_CHG, 'N') <>'Y';

       --knha8378 need to process all
        --AND rec_type != 'P'; -- uncommented this for pickup request issue found in POD 2 testing;
BEGIN
   pl_log.g_application_func   := 'D';
   pl_log.g_program_name       := 'pl_dci.validate_tripmaster';
 IF i_manifest_no IS NULL THEN
    o_exception_error := 'Manifest is NULL. Need Manifest Number';
    o_returns_err_count := -1;
    raise_application_error(-20999,'Manifest is NULL');
    RETURN;
 END IF;

 select count(*)
 into l_count_null_status
 from returns
 where manifest_no = i_manifest_no
 and   status is null;
 --
 if l_count_null_status > 0 then
    update returns
    set status='VAL'
    where manifest_no = i_manifest_no
    and   status is null;
 end if;
 --
  SELECT count(*)
  INTO  l_count_bad_returns
  FROM returns
  WHERE manifest_no = i_manifest_no
  AND   nvl(rtn_sent_ind,'N') = 'N'
  AND   nvl(lock_chg,'N') = 'Y'
  AND   nvl(pod_rtn_ind,'A') = 'D';

  IF l_count_bad_returns > 0 THEN
     UPDATE returns
       set lock_chg = 'N',
	   pod_rtn_ind = 'A'
     WHERE manifest_no = i_manifest_no
     AND   nvl(rtn_sent_ind,'N') = 'N'
     AND   nvl(lock_chg,'N') = 'Y'
     AND   nvl(pod_rtn_ind,'A') = 'D';
  END IF;


   FOR CRET IN c_unprocessed_manifest_rtn(i_manifest_no)
   LOOP
   BEGIN

      UPDATE returns r
                  SET err_comment = err_comment ||(
            /*  CASE
              WHEN (r.returned_prod_id = r.prod_id AND r.return_reason_cd ='W10') THEN
                     'Mispicked item = invoiced item:' || r.returned_prod_id||';'
              END ||*/
              CASE
                 WHEN NOT EXISTS
                  (SELECT p.prod_id
                   FROM pm p
                   WHERE p.prod_id = 
                    decode(r.return_reason_cd,'W10',nvl(r.returned_prod_id,'X'),'W30',nvl(r.returned_prod_id,'X'),r.prod_id))  
                   THEN
                    'MISPICK ITEM# ' || nvl(r.returned_prod_id,'is blank and') || ' not valid; '
                  END || CASE
                   WHEN NOT EXISTS
                    (SELECT p.prod_id
                     FROM pm p
                     WHERE p.prod_id = r.prod_id)
                    THEN
                    'ORDER ITEM# ' || r.prod_id || ' not valid; '
                  END || CASE
                -- Returned quantity should be greater than zero
                   WHEN nvl(r.returned_qty,0) <= 0 and r.rec_type != 'P' THEN
                    'RETURN QTY not greater than 0; '
                 END || CASE
                   WHEN nvl(r.returned_split_cd,'X') not in ('0','1') and r.rec_type != 'P' THEN
                    'RETURN SPLIT CODE not valid; '
                  END || CASE
                   WHEN NOT EXISTS
                    (SELECT rc.reason_cd
                     FROM reason_cds rc
                     WHERE rc.reason_cd = r.return_reason_cd
                     AND rc.reason_cd_type = 'RTN')
                    THEN
                    'RETURN REASON CODE# ' || r.return_reason_cd || ' not valid; '
                END)
      WHERE r.rowid = cret.rid;

    -- Above change done on March 20, 2014 
    -- knha8378 replacing add_source condition and using rec_type instead 
    -- AND nvl(add_source,'STS') != 'MFR'; 

  -- Update status for all error records             
        UPDATE RETURNS R
         SET R.STATUS = 
               (CASE 
                    WHEN R.ERR_COMMENT IS NULL THEN 'VAL'
                    WHEN R.ERR_COMMENT IS NOT NULL THEN 'ERR'
                END)
        WHERE r.ROWID=cret.RID;

    EXCEPTION
      WHEN NO_DATA_FOUND THEN
        NULL;
      WHEN OTHERS THEN
        o_returns_err_count :=-1;
    o_exception_error := 'Validate processing failed on Returns - Error Code: ' ||SQLERRM;
        pl_text_log.ins_msg('F', '',o_exception_error,'','','DriverCheck-in',l_object_name); 
        raise_application_error(SQLCODE,SQLERRM);
        RETURN;
    END;

  END LOOP;

  Begin

     UPDATE RETURNS R
         SET R.STATUS = 'CMP'
         WHERE  nvl(STATUS, 'VAL') ='VAL' 
        AND MANIFEST_NO = i_manifest_no
        AND nvl(LOCK_CHG, 'N') = 'Y'
	AND RTN_SENT_IND = 'Y';

   EXCEPTION WHEN NO_DATA_FOUND THEN
        NULL;
   WHEN OTHERS THEN
        o_returns_err_count :=-1;
    o_exception_error := 'Validte processing failed on Returns - Error Code: ' ||SQLERRM;
        pl_text_log.ins_msg('F', '',o_exception_error,'','','DriverCheck-in',l_object_name); 
        raise_application_error(SQLCODE,SQLERRM);
        RETURN;       

  End ;      

  COMMIT;

  BEGIN
        o_returns_err_count := 0;

        SELECT COUNT(*) 
        INTO o_returns_err_count
        FROM returns 
        WHERE manifest_no = i_manifest_no
         and status ='ERR';



        -- poiStatus := C_INCONSISTENT_MF; 
        -- Above statement comment out because the program calling this function
        -- need to check if error count is > 0 then return to rf client C_INCONSISTENT_MF
        RETURN;
  END;

EXCEPTION 
    WHEN OTHERS THEN
                o_returns_err_count:=-1;
        o_exception_error := 'EXCEPTION OTHERS On Error Code: ' || SQLERRM;
        pl_text_log.ins_msg('F', '','Tripmaster processing failed on manifest' || i_manifest_no,'','Status:' || SQLCODE ||'-' || SQLERRM,'DriverCheck-in',l_object_name); 
                raise_application_error(SQLCODE,SQLERRM);
                RETURN;
END;
-- -----------------------------------------------------------------------------

PROCEDURE client_tripmaster (
  piMfNo        IN  manifests.manifest_no%TYPE,
  pszInv        IN  manifest_dtls.obligation_no%TYPE DEFAULT NULL,
  poszMsg       OUT VARCHAR2,
  poszLMStr     OUT VARCHAR2,
  poiNumRtns        OUT NUMBER,
  poiNumCurRtns     OUT NUMBER,
  poiNumTempRtns    OUT NUMBER,
  poszRtns      OUT VARCHAR2,
  poiStatus     OUT NUMBER,
  piNextRecSet      IN  NUMBER DEFAULT 0,
  piRecTyp      IN  NUMBER DEFAULT 0) IS
  iStatus       NUMBER := C_NORMAL;
  iNextRecSet       NUMBER := 0;
  szSearch      returns.obligation_no%TYPE := NULL;
  iNumRtns      NUMBER := 0;
  iNumCurRtns       NUMBER := 0;
  iNumWeightRtns    NUMBER := 0;
  iNumTempRtns      NUMBER := 0;
  tabTypRtns        tabTypReturns;
BEGIN
  poszMsg := NULL;
  poszLMStr := NULL;
  poiNumRtns := 0;
  poiNumCurRtns := 0;
  poiNumTempRtns := 0;
  poszRtns := NULL;
  poiStatus := C_NORMAL;

  IF piNextRecSet < 0 THEN
    RETURN;
  END IF;

  IF piNextRecSet = 0 THEN
    -- Caller request to perform tripmaster function
    tripmaster(piMfNo, pszInv, poszMsg, poszLMStr, iStatus);
    IF iStatus <> C_NORMAL THEN
      poiStatus := iStatus;
      RETURN;
    END IF;
    iNextRecSet := 1;
  ELSE
    -- Caller requests to retrieve all or remaning returns related to the
    -- manifest/invoice after tripmaster.
    iNextRecSet := piNextRecSet;
  END IF;

  -- Retrieve the tripmaster return information according to search criteria
  szSearch := TO_CHAR(piMfNo);
  IF pszInv IS NOT NULL THEN
    szSearch := pszInv;
  END IF;
  -- Only retrieve returns that have valid reason codes, nonzero qty, and
  -- haven't been putawayed
  get_range_returns(iNextRecSet, szSearch, iNumRtns, iNumCurRtns,
                    iNumWeightRtns, iNumTempRtns, tabTypRtns, 0,
                    NULL, NULL, NULL, piRecTyp);

  -- Send returns information back to caller
  assign_to_caller(tabTypRtns, poszRtns);

  poiNumRtns := iNumRtns;
  poiNumCurRtns := iNumCurRtns;
  poiNumTempRtns := iNumTempRtns;
END;
-- -----------------------------------------------------------------------------

PROCEDURE create_return (
  piInvokeTime  IN  NUMBER,
  pRwTypRtn IN  returns%ROWTYPE,
  poRcTypRtn    OUT recTypRtn,
  poiStatus OUT NUMBER,
  poszMsg   OUT VARCHAR2,
  poszLMStr OUT VARCHAR2) IS
  iStatus   NUMBER := C_NORMAL;
  iExists   NUMBER := 0;
  rwTypMfHdr    manifests%ROWTYPE := NULL;
  rwTypMfDtls   manifest_dtls%ROWTYPE := NULL;
  rwTypPutlst   putawaylst%ROWTYPE := NULL;
  iShipQty  NUMBER := 0;
  tabTypRsn2    tabTypReasons;
  szMsg     VARCHAR2(4000) := NULL;
  iMaxLine  returns.erm_line_id%TYPE := NULL;
  iNumRtns  NUMBER := 0;
  iNumCurRtns   NUMBER := 0;
  iNumWtRtns    NUMBER := 0;
  iNumTempRtns  NUMBER := 0;
  tabTypRtn tabTypReturns;
  rwTypPm   pm%ROWTYPE := NULL;
  iSkidCube NUMBER := 0;
  iMinTemp  NUMBER := NULL;
  iMaxTemp  NUMBER := NULL;
  iMinWeight    NUMBER := NULL;
  iMaxWeight    NUMBER := NULL;
  rwTypRtn  returns%ROWTYPE := pRwTypRtn;
  CURSOR c_get_crt_mf_dtls(cp_uom returns.returned_split_cd%TYPE) IS
    SELECT d.manifest_no, d.stop_no, d.rec_type,
           DECODE(INSTR(d.obligation_no, 'L'), 0, d.obligation_no,
                  SUBSTR(d.obligation_no,
                         1, INSTR(d.obligation_no, 'L') - 1)) obligation_no,
           d.prod_id, d.cust_pref_vendor,
           d.shipped_qty, d.shipped_split_cd,
           d.manifest_dtl_status, d.orig_invoice,
           d.shipped_qty /
           DECODE(d.shipped_split_cd, '1', p.spc, 1)
    FROM manifest_dtls d, pm p
    WHERE d.manifest_no = rwTypRtn.manifest_no
    AND   DECODE(INSTR(d.obligation_no, 'L'), 0, d.obligation_no,
                 SUBSTR(d.obligation_no, 1, INSTR(d.obligation_no, 'L') - 1)) =
          rwTypRtn.obligation_no
    AND   d.prod_id = pRwTypRtn.prod_id
    AND   d.cust_pref_vendor = rwTypRtn.cust_pref_vendor
    AND   d.prod_id = p.prod_id
    AND   d.cust_pref_vendor = p.cust_pref_vendor
    AND   ((cp_uom IS NULL) OR
           ((cp_uom IS NOT NULL) AND (d.shipped_split_cd = cp_uom))); 
  CURSOR c_get_lock_crt_rtn IS
    SELECT manifest_no
    FROM returns
    WHERE manifest_no = rwTypRtn.manifest_no
    FOR UPDATE NOWAIT;
BEGIN
  poiStatus := C_NORMAL;
  poRcTypRtn := NULL;
  poszMsg := NULL;
  poszLMStr := NULL;

  check_basic_rtn_info(rwTypRtn, iStatus, iMinTemp, iMaxTemp);
  IF iStatus IN (C_TEMP_NO_RANGE, C_TEMP_REQUIRED, C_TEMP_OUT_OF_RANGE) THEN
    IF piInvokeTime <= 1 THEN
      -- 1st time called and temperature has no range/required/out of range.
      -- Send min and/or max temperature back to caller in format of
      -- "<min-temp><max-temp>". Each temperature is right pack with blanks
      -- up to C_WEIGHT_LEN long.
      poiStatus := iStatus;
      poszMsg := RPAD(TO_CHAR(iMinTemp), C_WEIGHT_LEN) ||
                 RPAD(TO_CHAR(iMaxTemp), C_WEIGHT_LEN);
      RETURN;
    END IF;
  ELSIF iStatus <> C_NORMAL THEN
    poiStatus := iStatus;
    RETURN;
  END IF;

  IF rwTypRtn.returned_split_cd IS NULL OR
     rwTypRtn.returned_split_cd NOT IN ('0', '1') THEN
    poiStatus := C_INVALID_UOM;
    RETURN;
  END IF;

  -- This must be a new return to be created
  BEGIN
    SELECT 1 INTO iExists
    FROM returns
    WHERE manifest_no = rwTypRtn.manifest_no
    AND   erm_line_id = rwTypRtn.erm_line_id;
    poiStatus := C_RTN_EXISTS;
    RETURN;
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      NULL;
    WHEN OTHERS THEN
      poiStatus := SQLCODE;
      RETURN;
  END;

  -- Retrieve manifest header info, especially the route #
  get_mf_info(rwTypRtn.manifest_no, rwTypMfHdr);
  IF rwTypMfHdr.manifest_no IS NULL THEN
    poiStatus := C_NO_MF_INFO;
    RETURN;
  END IF;

  -- Retrieve reason info for the new reason code again. We don't need to
  -- check the validity of the new reason since it has been done from basic
  -- returns info checking
  tabTypRsn2 := get_reason_info('ALL', 'ALL', rwTypRtn.return_reason_cd);

  -- Retrieve manifest detail, especially the stop # and rec_type
  OPEN c_get_crt_mf_dtls(rwTypRtn.returned_split_cd);
  FETCH c_get_crt_mf_dtls
    INTO rwTypMfDtls.manifest_no, rwTypMfDtls.stop_no, rwTypMfDtls.rec_type,
         rwTypMfDtls.obligation_no, rwTypMfDtls.prod_id,
         rwTypMfDtls.cust_pref_vendor, rwTypMfDtls.shipped_qty,
         rwTypMfDtls.shipped_split_cd, rwTypMfDtls.manifest_dtl_status,
         rwTypMfDtls.orig_invoice, iShipQty;
  IF c_get_crt_mf_dtls%NOTFOUND THEN
    -- Cannot find info. Try not using uom since ship and returned uom might be
    -- different
    CLOSE c_get_crt_mf_dtls;
    OPEN c_get_crt_mf_dtls(NULL);
    FETCH c_get_crt_mf_dtls
      INTO rwTypMfDtls.manifest_no, rwTypMfDtls.stop_no, rwTypMfDtls.rec_type,
           rwTypMfDtls.obligation_no, rwTypMfDtls.prod_id,
           rwTypMfDtls.cust_pref_vendor, rwTypMfDtls.shipped_qty,
           rwTypMfDtls.shipped_split_cd, rwTypMfDtls.manifest_dtl_status,
           rwTypMfDtls.orig_invoice, iShipQty;
    IF c_get_crt_mf_dtls%NOTFOUND THEN
      rwTypMfDtls := NULL;
      iShipQty := 0;
    END IF;
  END IF;
  IF c_get_crt_mf_dtls%ISOPEN THEN
    CLOSE c_get_crt_mf_dtls;
  END IF;
  IF rwTypMfDtls.manifest_no IS NULL THEN
    -- Cannot find manifest detail. The new return might be an overage
    IF tabTypRsn2(1).reason_group <> 'OVR' THEN
      -- The new return might be an overage but the reason is not overage
      -- reason code
      poiStatus := C_INV_RSN;
      RETURN;
    END IF;
    rwTypMfDtls.manifest_no := rwTypRtn.manifest_no;
    rwTypMfDtls.stop_no := NULL;
    rwTypMfDtls.rec_type := 'O';
    rwTypMfDtls.obligation_no := NULL;
    rwTypMfDtls.prod_id := rwTypRtn.prod_id;
    rwTypMfDtls.cust_pref_vendor := rwTypRtn.cust_pref_vendor;
    rwTypMfDtls.shipped_qty := NULL;
    rwTypMfDtls.shipped_split_cd := rwTypRtn.returned_split_cd;
  END IF;

  IF rwTypMfDtls.rec_type <> 'O' AND tabTypRsn2(1).reason_group = 'OVR' THEN
    -- Return is not overage but provided reason code is overage
    poiStatus := C_INV_RSN;
    RETURN;
  END IF;

  -- Check if creation will cause uom difference. Only check in initial time
  IF rwTypRtn.returned_split_cd <> rwTypMfDtls.shipped_split_cd AND
     piInvokeTime <= 1 THEN
    poiStatus := C_SHIP_DIFF_UOM;
    RETURN;
  END IF;

  -- Check if the to-be-inserted qty plus existing returns are over the shipped
  -- limit and it's a regular return and is not shipped as overage (W40).
  IF NVL(rwTypRtn.returned_qty, 0) <> 0 AND
     tabTypRsn2(1).reason_group NOT IN ('OVI', 'OVR') AND
     rwTypRtn.obligation_no IS NOT NULL THEN
    iStatus := check_ovr_und_rtn(rwTypRtn, 0, 0);
    IF iStatus NOT IN (C_NORMAL, -20001) THEN
      poiStatus := iStatus;
      RETURN;
    END IF;
  END IF;

  -- Check if entered weight is out of range for weight tracked item
  get_master_item(NVL(rwTypRtn.returned_prod_id, rwTypRtn.prod_id),
                  rwTypRtn.cust_pref_vendor,
                  iSkidCube, rwTypPm, iStatus);
  IF rwTypPm.catch_wt_trk = 'Y' THEN
    iMinWeight := rwTypRtn.returned_qty;
    iMaxWeight := rwTypRtn.returned_qty;
    IF rwTypRtn.returned_split_cd = '0' THEN
      iMinWeight := rwTypRtn.returned_qty * rwTypPm.spc;
      iMaxWeight := rwTypRtn.returned_qty * rwTypPm.spc;
    END IF;
    iMinWeight := iMinWeight * rwTypPm.avg_wt *
                  (1 - TO_NUMBER(gRcTypSyspar.pct_tolerance) / 100);
    iMaxWeight := iMaxWeight * rwTypPm.avg_wt *
                  (1 + TO_NUMBER(gRcTypSyspar.pct_tolerance) / 100);
    IF NVL(rwTypRtn.catchweight, 0) <> 0 THEN
      IF piInvokeTime = 1 AND
         rwTypRtn.catchweight < iMinWeight AND
         rwTypRtn.catchweight > iMaxWeight THEN
        poiStatus := C_WEIGHT_OUT_OF_RANGE;
        poszMsg := RPAD(TO_CHAR(iMinWeight), C_WEIGHT_LEN) ||
                   RPAD(TO_CHAR(iMaxWeight), C_WEIGHT_LEN);
        RETURN;
      END IF;
    ELSE
      IF piInvokeTime = 1 THEN
        poiStatus := C_WEIGHT_DESIRED;
        poszMsg := RPAD(TO_CHAR(iMinWeight), C_WEIGHT_LEN) ||
                   RPAD(TO_CHAR(iMaxWeight), C_WEIGHT_LEN);
        RETURN;
      END IF;
    END IF;
  END IF;

  -- Lock the RETURNS table
  OPEN c_get_lock_crt_rtn;

  -- Insert to RETURNS table
  BEGIN
    SELECT NVL(MAX(NVL(ERM_LINE_ID, 0)), 0) INTO iMaxLine
    FROM returns
    WHERE manifest_no = rwTypRtn.manifest_no;
  EXCEPTION
    WHEN OTHERS THEN
      iMaxLine := 0;                     
  END;
  iMaxLine := iMaxLine + 1;
  BEGIN
    INSERT INTO returns
      (manifest_no, route_no, stop_no, rec_type, obligation_no,
       prod_id, cust_pref_vendor, returned_prod_id, return_reason_cd,
       returned_qty, returned_split_cd, catchweight, disposition,
       erm_line_id, shipped_split_cd, shipped_qty, cust_id, temperature,
       add_source)
    VALUES (
      rwTypRtn.manifest_no, rwTypMfHdr.route_no, rwTypMfDtls.stop_no,
      rwTypMfDtls.rec_type, rwTypRtn.obligation_no,
      rwTypRtn.prod_id, rwTypRtn.cust_pref_vendor,
      NVL(rwTypRtn.returned_prod_id, rwTypRtn.prod_id),
      rwTypRtn.return_reason_cd,
      rwTypRtn.returned_qty, rwTypRtn.returned_split_cd,
      rwTypRtn.catchweight, rwTypRtn.disposition,
      iMaxLine, rwTypMfDtls.shipped_split_cd, rwTypMfDtls.shipped_qty,
      rwTypRtn.cust_id, rwTypRtn.temperature, 'RF');
    rwTypRtn.erm_line_id := iMaxLine;
  EXCEPTION
    WHEN OTHERS THEN
      poiStatus := SQLCODE;
      RETURN;
  END;

  -- Create data for all return related tables
  IF NVL(rwTypRtn.returned_qty, 0) <> 0 THEN
    iStatus := create_erm(rwTypRtn.manifest_no, tabTypRsn2(1).reason_group);
    IF iStatus = C_NORMAL THEN
      DBMS_OUTPUT.PUT_LINE('Create ERM ok rsn grp: ' ||
        tabTypRsn2(1).reason_group);
      DBMS_OUTPUT.PUT_LINE('Ln: ' || TO_CHAR(rwTypRtn.erm_line_id));
--    pl_log.ins_msg('I', 'pl_dci', 'Create ERM ok rsn grp: ' ||
--      tabTypRsn2(1).reason_group || ' Ln: ' || TO_CHAR(rwTypRtn.erm_line_id),
--      0, 0);
      iStatus := create_erd(tabTypRsn2(1).reason_group, rwTypRtn);
      IF iStatus = C_NORMAL THEN
        DBMS_OUTPUT.PUT_LINE('Create ERD ok');
--      pl_log.ins_msg('I', 'pl_dci', 'Create ERD ok', 0, 0);
        create_puttask(rwTypRtn.manifest_no, tabTypRsn2(1).reason_group,
                       rwTypRtn, rwTypPutlst, szMsg, poszLMStr, iStatus);
      END IF;
    END IF;
    IF iStatus <> C_NORMAL THEN
      poszMsg := szMsg;
      poiStatus := iStatus;
      RETURN;
    END IF;
    DBMS_OUTPUT.PUT_LINE('Create PUTAWAYLST ok pallet: ' ||
      rwTypPutlst.dest_loc || '/' || rwTypPutlst.pallet_id);
--  pl_log.ins_msg('I', 'pl_dci', 'Create PUTAWAYLST ok pallet: ' ||
--    rwTypPutlst.dest_loc || '/' || rwTypPutlst.pallet_id, 0, 0);
  END IF;

  -- Set the track flags if needed
  BEGIN
    UPDATE putawaylst
    SET temp_trk = DECODE(rwTypRtn.temperature, NULL, temp_trk, 'C'),
        catch_wt = DECODE(rwTypRtn.catchweight, NULL, catch_wt, 'C')
    WHERE pallet_id = rwTypPutlst.pallet_id;
    DBMS_OUTPUT.PUT_LINE('Update PUTAWAYLST temp_trk, catch_wt flag cnt: ' ||
      TO_CHAR(SQL%ROWCOUNT));
  EXCEPTION
    WHEN OTHERS THEN
      poiStatus := SQLCODE;
      RETURN;
  END;

  -- Update manifest detail status to RTN
  BEGIN
    UPDATE manifest_dtls d
      SET d.manifest_dtl_status = 'RTN'
      WHERE d.manifest_no = rwTypRtn.manifest_no
      AND   DECODE(INSTR(d.obligation_no, 'L'), 0, d.obligation_no,
                   SUBSTR(d.obligation_no,
                   1, INSTR(d.obligation_no, 'L') - 1)) =
            rwTypRtn.obligation_no
      AND   d.rec_type = rwTypMfDtls.rec_type
      AND   d.prod_id = rwTypRtn.prod_id
      AND   d.cust_pref_vendor = rwTypRtn.cust_pref_vendor
      AND   d.shipped_split_cd = rwTypRtn.returned_split_cd
      AND   d.shipped_qty > 0;
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      BEGIN
        -- Cannot find same uom. Try the opposite uom
        UPDATE manifest_dtls d
          SET d.manifest_dtl_status = 'RTN'
          WHERE d.manifest_no = rwTypRtn.manifest_no
          AND   DECODE(INSTR(d.obligation_no, 'L'), 0, d.obligation_no,
                       SUBSTR(d.obligation_no,
                       1, INSTR(d.obligation_no, 'L') - 1)) =
                rwTypRtn.obligation_no
          AND   d.rec_type = rwTypMfDtls.rec_type
          AND   d.prod_id = rwTypRtn.prod_id
          AND   d.cust_pref_vendor = rwTypRtn.cust_pref_vendor
          AND   d.shipped_split_cd = DECODE(rwTypRtn.returned_split_cd,
                                            '1', '0', '1');
      EXCEPTION
        WHEN NO_DATA_FOUND THEN
          NULL;
        WHEN OTHERS THEN
          poiStatus := SQLCODE;
          RETURN;
      END; 
    WHEN OTHERS THEN
      poiStatus := SQLCODE;
      RETURN;
  END;

  -- Unlock the RETURNS table
  IF c_get_lock_crt_rtn%ISOPEN THEN
    CLOSE c_get_lock_crt_rtn;
  END IF;

  -- Send update information back to caller
  get_range_returns(0, rwTypPutlst.pallet_id,
                    iNumRtns, iNumCurRtns, iNumWtRtns, iNumTempRtns,
                    tabTypRtn, 0, 'LP', NULL, iMaxLine, 0, 'ALL', 1, 9999);
  IF iNumRtns = 0 THEN
    poiStatus := C_UPD_PUTLST_FAIL;
    RETURN;
  END IF;
  poRcTypRtn.manifest_no := tabTypRtn(1).manifest_no;
  poRcTypRtn.route_no := tabTypRtn(1).route_no;
  poRcTypRtn.stop_no := tabTypRtn(1).stop_no;
  poRcTypRtn.rec_type := tabTypRtn(1).rec_type;
  poRcTypRtn.obligation_no := tabTypRtn(1).obligation_no;
  poRcTypRtn.prod_id := tabTypRtn(1).prod_id;
  poRcTypRtn.cust_pref_vendor := tabTypRtn(1).cust_pref_vendor;
  poRcTypRtn.reason_code := tabTypRtn(1).reason_code;
  poRcTypRtn.returned_qty := tabTypRtn(1).returned_qty;
  poRcTypRtn.returned_split_cd := tabTypRtn(1).returned_split_cd;
  poRcTypRtn.weight := tabTypRtn(1).weight;
  poRcTypRtn.disposition := tabTypRtn(1).disposition;
  poRcTypRtn.returned_prod_id := tabTypRtn(1).returned_prod_id;
  poRcTypRtn.erm_line_id := tabTypRtn(1).erm_line_id;
  poRcTypRtn.shipped_qty := tabTypRtn(1).shipped_qty;
  poRcTypRtn.shipped_split_cd := tabTypRtn(1).shipped_split_cd;
  poRcTypRtn.temp := tabTypRtn(1).temp;
  poRcTypRtn.catch_wt_trk := tabTypRtn(1).catch_wt_trk;
  poRcTypRtn.temp_trk := tabTypRtn(1).temp_trk;
  poRcTypRtn.orig_invoice := tabTypRtn(1).orig_invoice;
  poRcTypRtn.dest_loc := tabTypRtn(1).dest_loc;
  poRcTypRtn.pallet_id := tabTypRtn(1).pallet_id;
  poRcTypRtn.rtn_label_printed := tabTypRtn(1).rtn_label_printed;
  poRcTypRtn.pallet_batch_no := tabTypRtn(1).pallet_batch_no;
  poRcTypRtn.parent_pallet_id := tabTypRtn(1).parent_pallet_id;
  poRcTypRtn.putaway_put := tabTypRtn(1).putaway_put;
  poRcTypRtn.pallet_type := tabTypRtn(1).pallet_type;
  poRcTypRtn.ti := tabTypRtn(1).ti;
  poRcTypRtn.hi := tabTypRtn(1).hi;
  poRcTypRtn.min_temp := tabTypRtn(1).min_temp;
  poRcTypRtn.max_temp := tabTypRtn(1).max_temp;
  poRcTypRtn.min_weight := tabTypRtn(1).min_weight;
  poRcTypRtn.max_weight := tabTypRtn(1).max_weight;
  poRcTypRtn.descrip := tabTypRtn(1).descrip;
END;
-- -----------------------------------------------------------------------------

PROCEDURE update_return (
  piInvokeTime  IN  NUMBER,
  pRwTypRtn IN  returns%ROWTYPE,
  poRcTypRtn    OUT recTypRtn,
  poszMsg   OUT VARCHAR2,
  poszLMStr OUT VARCHAR2,
  poiStatus OUT NUMBER) IS
  szMfStatus        VARCHAR2(10) := NULL;
  szReason      returns.return_reason_cd%TYPE := NULL;
  rwTypPutlst       putawaylst%ROWTYPE := NULL;
  tabTypRsn1        tabTypReasons;
  tabTypRsn2        tabTypReasons;
  tabTypRsn3        tabTypReasons;
  iStatus       NUMBER := C_NORMAL;
  szMsg         VARCHAR2(500) := NULL;
  rwTypMfHdr        manifests%ROWTYPE := NULL;
  rwTypMfDtls       manifest_dtls%ROWTYPE := NULL;
  iShipQty      NUMBER := 0;
  rwTypPm       pm%ROWTYPE := NULL;
  iSkidCube     NUMBER := 0;
  iQty          NUMBER := 0;
  iNumRtns      NUMBER := 0;
  iNumCurRtns       NUMBER := 0;
  iNumWtRtns        NUMBER := 0;
  iNumTempRtns      NUMBER := 0;
  tabTypRtn     tabTypReturns;
  iMinTemp      NUMBER := NULL;
  iMaxTemp      NUMBER := NULL;
  iMinWeight        NUMBER := NULL;
  iMaxWeight        NUMBER := NULL;
BEGIN
  poszMsg := NULL;
  poszLMStr := NULL;
  poiStatus := C_NORMAL;

  -- Do basic return info checking. Only check temperature info when
  -- it's the 1st time the function is invoked
  check_basic_rtn_info(pRwTypRtn, iStatus, iMinTemp, iMaxTemp);
  IF iStatus IN (C_TEMP_NO_RANGE, C_TEMP_REQUIRED, C_TEMP_OUT_OF_RANGE) THEN
    IF piInvokeTime = 1 THEN
      poiStatus := iStatus;
      poszMsg := RPAD(TO_CHAR(iMinTemp), C_WEIGHT_LEN) ||
                 RPAD(TO_CHAR(iMaxTemp), C_WEIGHT_LEN);
      RETURN;
    END IF;
  ELSIF iStatus <> C_NORMAL THEN
    poiStatus := iStatus;
    RETURN;
  END IF;

  -- Only pickup return can be updated to 0 qty
  IF NVL(pRwTypRtn.returned_qty, 0) = 0 AND pRwTypRtn.rec_type <> 'P' THEN
    poiStatus := C_UPD_NOT_ALLOWED;
    RETURN;
  END IF;

  -- Retrieve reason info for the new reason code again. We don't need to
  -- check the validity of the new reason since it has been done from basic
  -- returns info checking
  tabTypRsn2 := get_reason_info('ALL', 'ALL', pRwTypRtn.return_reason_cd);

  -- Check if update will cause uom difference. Only check in initial time
  get_mf_info(pRwTypRtn, rwTypMfHdr, rwTypMfDtls, iShipQty);
  IF rwTypMfDtls.manifest_no IS NULL THEN
    poiStatus := C_NO_MF_INFO;
    RETURN;
  END IF;
  IF pRwTypRtn.returned_split_cd <> rwTypMfDtls.shipped_split_cd AND
     piInvokeTime <= 1 THEN
    poiStatus := C_SHIP_DIFF_UOM;
    RETURN;
  END IF;

  -- Check if the updated qty plus existing returns are over the shipped limit
  -- and it's a regular return and is not shipped as overage (W40). Use the
  -- current returns information but excludes the qty for the same return in
  -- the database
  IF NVL(pRwTypRtn.returned_qty, 0) <> 0 AND
     tabTypRsn2(1).reason_group NOT IN ('OVI', 'OVR') AND
     pRwTypRtn.obligation_no IS NOT NULL THEN
    iStatus := check_ovr_und_rtn(pRwTypRtn, 0, pRwTypRtn.erm_line_id);
    IF iStatus NOT IN (C_NORMAL, -20001) THEN
      poiStatus := iStatus;
      RETURN;
    END IF;
  END IF;

  -- Check if entered weight is out of range for weight tracked item
  get_master_item(NVL(pRwTypRtn.returned_prod_id, pRwTypRtn.prod_id),
                  pRwTypRtn.cust_pref_vendor,
                  iSkidCube, rwTypPm, iStatus);
  IF rwTypPm.catch_wt_trk = 'Y' THEN
    IF NVL(pRwTypRtn.catchweight, 0) <> 0 THEN
      iMinWeight := pRwTypRtn.returned_qty;
      iMaxWeight := pRwTypRtn.returned_qty;
      IF pRwTypRtn.returned_split_cd = '0' THEN
        iMinWeight := pRwTypRtn.returned_qty * rwTypPm.spc;
        iMaxWeight := pRwTypRtn.returned_qty * rwTypPm.spc;
      END IF;
      iMinWeight := iMinWeight * rwTypPm.avg_wt *
                    (1 - TO_NUMBER(gRcTypSyspar.pct_tolerance) / 100);
      iMaxWeight := iMaxWeight * rwTypPm.avg_wt *
                    (1 + TO_NUMBER(gRcTypSyspar.pct_tolerance) / 100);
      IF piInvokeTime = 1 AND
         pRwTypRtn.catchweight < iMinWeight AND
         pRwTypRtn.catchweight > iMaxWeight THEN
        poiStatus := C_WEIGHT_OUT_OF_RANGE;
        poszMsg := RPAD(TO_CHAR(iMinWeight), C_WEIGHT_LEN) ||
                   RPAD(TO_CHAR(iMaxWeight), C_WEIGHT_LEN);
        RETURN;
      END IF;
    END IF;
  END IF;

  -- Retrieve previous reason code info. It will be used to compare whether
  -- the reason group has been changed.
  BEGIN
    SELECT return_reason_cd INTO szReason
    FROM returns
    WHERE manifest_no = pRwTypRtn.manifest_no
    AND   erm_line_id = pRwTypRtn.erm_line_id;
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      NULL;
    WHEN OTHERS THEN
      poiStatus := SQLCODE;
      RETURN;
  END;
  DBMS_OUTPUT.PUT_LINE('Line: ' || TO_CHAR(pRwTypRtn.erm_line_id) ||
    ', old rsn: ' || szReason);
--pl_log.ins_msg('I', 'pl_dci', 'Line: ' || TO_CHAR(pRwTypRtn.erm_line_id) ||
--  ', old rsn: ' || szReason, 0, 0);
  tabTypRsn1 := get_reason_info('ALL', 'ALL', szReason);
  DBMS_OUTPUT.PUT_LINE('Old rsn: ' || TO_CHAR(tabTypRsn1.COUNT) ||
    ' grp: ' || tabTypRsn1(1).reason_group);
  IF tabTypRsn1.COUNT >= 1 THEN
    -- Check if the old putaway task exists or has been putawayed or not
    rwTypPutlst := check_putaway(tabTypRsn1(1).reason_group, pRwTypRtn);
    DBMS_OUTPUT.PUT_LINE('Check put: ' || rwTypPutlst.putaway_put ||
      ' status: ' || TO_CHAR(rwTypPutlst.putpath) || ' pallet: ' ||
      rwTypPutlst.pallet_id);
--  pl_log.ins_msg('I', 'pl_dci', 'Check put: ' || rwTypPutlst.putaway_put ||
--    ' status: ' || TO_CHAR(rwTypPutlst.putpath) || ' pallet: ' ||
--    rwTypPutlst.pallet_id, 0, 0);
    IF rwTypPutlst.putaway_put = 'Y' THEN
      -- The current return exists and has been putawayed
      poiStatus := C_PUT_DONE;
      RETURN;
    ELSIF rwTypPutlst.putaway_put = 'O' THEN
      -- Database error occurred
      poiStatus := rwTypPutlst.putpath;
      RETURN;
    ELSE
      -- The current return hasn't been putawayed or doesn't need a putaway
      -- task on the old reason. Delete all returns related tables and will
      -- create them again if needed
      IF tabTypRsn1(1).reason_group NOT IN ('STM', 'MPK') THEN
        -- Undo T-Batch if needed
        IF gRcTypSyspar.lbr_mgmt_flag = 'Y' AND
           gRcTypSyspar.create_batch_flag = 'Y' THEN
          pl_rtn_lm.unload_pallet_batch(rwTypPutlst.pallet_id, 1, szMsg,
                                        iStatus);
          DBMS_OUTPUT.PUT_LINE('Unload T-batch status: ' || TO_CHAR(iStatus));
--        pl_log.ins_msg('I', 'pl_dci', 'Unload T-batch status: ' ||
--          TO_CHAR(iStatus), 0, 0);
          IF iStatus = C_NORMAL THEN
            iStatus := pl_rtn_lm.delete_pallet_batch(rwTypPutlst.pallet_id,
                                                     1);
            DBMS_OUTPUT.PUT_LINE('Delete T-batch status: ' || TO_CHAR(iStatus));
--          pl_log.ins_msg('I', 'pl_dci', 'Delete T-batch status: ' ||
--            TO_CHAR(iStatus), 0, 0);
            IF iStatus NOT IN (C_NOT_FOUND, C_ANSI_NOT_FOUND, C_NORMAL) THEN
              poiStatus := iStatus;
              RETURN;
            END IF;
          ELSIF iStatus NOT IN (C_NOT_FOUND, C_ANSI_NOT_FOUND) THEN
            poszMsg := szMsg;
            poiStatus := iStatus;
            RETURN;
          END IF;
        END IF;
        DBMS_OUTPUT.PUT_LINE('Delete T-batch ok');
        iStatus := delete_puttask(pRwTypRtn.manifest_no,
                                  tabTypRsn1(1).reason_group,
                                  pRwTypRtn.erm_line_id);
        IF iStatus <> C_NORMAL THEN
          poiStatus := iStatus;
          RETURN;
        END IF;
        DBMS_OUTPUT.PUT_LINE('Delete inv if available');
        iStatus := f_clear_inv(tabTypRsn1(1).reason_group, rwtypPutlst);
        IF iStatus <> C_NORMAL THEN
          poiStatus := iStatus;
          RETURN;
        END IF;
        DBMS_OUTPUT.PUT_LINE('Delete put task ok rsn grp: ' ||
          tabTypRsn1(1).reason_group);
--      pl_log.ins_msg('I', 'pl_dci', 'Delete put task ok rsn grp: ' ||
--        tabTypRsn1(1).reason_group, 0, 0);
        iStatus := delete_erd(pRwTypRtn.manifest_no,
                              tabTypRsn1(1).reason_group,
                              pRwTypRtn.erm_line_id);
        IF iStatus = C_NORMAL THEN
          iStatus := delete_erm(pRwTypRtn.manifest_no,
                                tabTypRsn1(1).reason_group);
        END IF;
        IF iStatus <> C_NORMAL THEN
          poiStatus := iStatus;
          RETURN;
        END IF;
        DBMS_OUTPUT.PUT_LINE('Delete ERM and ERD ok');
--      pl_log.ins_msg('I', 'pl_dci', 'Delete ERM and ERD ok', 0, 0);
      END IF; -- Old reason not in 'STM', 'MPK'
    END IF; -- check_putaway
  END IF; -- Old reason is valid

  -- Recreate data for all return related tables on the new reason if
  -- returned qty is not zero
  IF NVL(pRwTypRtn.returned_qty, 0) <> 0 THEN
    iStatus := create_erm(pRwTypRtn.manifest_no, tabTypRsn2(1).reason_group);
    IF iStatus = C_NORMAL THEN
      DBMS_OUTPUT.PUT_LINE('Create ERM ok rsn grp: ' ||
        tabTypRsn2(1).reason_group);
      DBMS_OUTPUT.PUT_LINE('Ln: ' || TO_CHAR(pRwTypRtn.erm_line_id));
--    pl_log.ins_msg('I', 'pl_dci', 'Create ERM ok rsn grp: ' ||
--      tabTypRsn2(1).reason_group || ' Ln: ' || TO_CHAR(pRwTypRtn.erm_line_id),
--      0, 0);
      iStatus := create_erd(tabTypRsn2(1).reason_group, pRwTypRtn);
      IF iStatus = C_NORMAL THEN
        DBMS_OUTPUT.PUT_LINE('Create ERD ok');
--      pl_log.ins_msg('I', 'pl_dci', 'Create ERD ok', 0, 0);
        create_puttask(pRwTypRtn.manifest_no, tabTypRsn2(1).reason_group,
                       pRwTypRtn, rwTypPutlst, szMsg, poszLMStr, iStatus);
      END IF;
    END IF;
    IF iStatus <> C_NORMAL THEN
      poszMsg := szMsg;
      poiStatus := iStatus;
      RETURN;
    END IF;
    DBMS_OUTPUT.PUT_LINE('Create PUTAWAYLST ok pallet: ' ||
      rwTypPutlst.dest_loc || '/' || rwTypPutlst.pallet_id);
--  pl_log.ins_msg('I', 'pl_dci', 'Create PUTAWAYLST ok pallet: ' ||
--    rwTypPutlst.dest_loc || '/' || rwTypPutlst.pallet_id, 0, 0);
  END IF;

  -- Set the track flags if needed
  BEGIN
    UPDATE putawaylst
    SET temp_trk = DECODE(pRwTypRtn.temperature, NULL, temp_trk, 'C'),
        catch_wt = DECODE(pRwTypRtn.catchweight, NULL, catch_wt, 'C')
    WHERE pallet_id = rwTypPutlst.pallet_id;
    DBMS_OUTPUT.PUT_LINE('Update PUTAWAYLST temp_trk, catch_wt flag cnt: ' ||
      TO_CHAR(SQL%ROWCOUNT));
  EXCEPTION
    WHEN OTHERS THEN
      poiStatus := SQLCODE;
      RETURN;
  END;

  -- Update the returns table now
  BEGIN
    UPDATE returns
      SET obligation_no = DECODE(rec_type, 'D', obligation_no,
                                 pRwTypRtn.obligation_no),
          return_reason_cd = pRwTypRtn.return_reason_cd,
          returned_qty = NVL(pRwTypRtn.returned_qty, 0),
          returned_split_cd = pRwTypRtn.returned_split_cd,
          catchweight = pRwTypRtn.catchweight,
          disposition = pRwTypRtn.disposition,
          returned_prod_id = NVL(pRwTypRtn.returned_prod_id, pRwTypRtn.prod_id),
          cust_id = pRwTypRtn.cust_id,
          temperature = pRwTypRtn.temperature,
          upd_source= 'RF'
      WHERE manifest_no = pRwTypRtn.manifest_no
      AND   erm_line_id = pRwTypRtn.erm_line_id;
    DBMS_OUTPUT.PUT_LINE('Update RETURNS status: ' || TO_CHAR(SQL%ROWCOUNT));
--  pl_log.ins_msg('I', 'pl_dci', 'Update RETURNS status: ' ||
--    TO_CHAR(SQL%ROWCOUNT), 0, 0);
  EXCEPTION
    WHEN OTHERS THEN
      poiStatus := SQLCODE;
      RETURN;
  END;

  -- Update manifest detail status to RTN
  BEGIN
    UPDATE manifest_dtls d
      SET d.manifest_dtl_status = 'RTN'
      WHERE d.manifest_no = pRwTypRtn.manifest_no
      AND   DECODE(INSTR(d.obligation_no, 'L'), 0, d.obligation_no,
                   SUBSTR(d.obligation_no,
                   1, INSTR(d.obligation_no, 'L') - 1)) =
            pRwTypRtn.obligation_no
      AND   d.rec_type = pRwTypRtn.rec_type
      AND   d.prod_id = pRwTypRtn.prod_id
      AND   d.cust_pref_vendor = pRwTypRtn.cust_pref_vendor
      AND   d.shipped_split_cd = pRwTypRtn.returned_split_cd
      AND   d.shipped_qty > 0;
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      BEGIN
        -- Cannot find same uom. Try the opposite uom
        UPDATE manifest_dtls d
          SET d.manifest_dtl_status = 'RTN'
          WHERE d.manifest_no = pRwTypRtn.manifest_no
          AND   DECODE(INSTR(d.obligation_no, 'L'), 0, d.obligation_no,
                       SUBSTR(d.obligation_no,
                       1, INSTR(d.obligation_no, 'L') - 1)) =
                pRwTypRtn.obligation_no
          AND   d.rec_type = pRwTypRtn.rec_type
          AND   d.prod_id = pRwTypRtn.prod_id
          AND   d.cust_pref_vendor = pRwTypRtn.cust_pref_vendor
          AND   d.shipped_split_cd = DECODE(pRwTypRtn.returned_split_cd,
                                            '1', '0', '1')
          AND   d.shipped_qty > 0;
      EXCEPTION
        WHEN NO_DATA_FOUND THEN
          NULL;
        WHEN OTHERS THEN
          poiStatus := SQLCODE;
          RETURN;
      END; 
    WHEN OTHERS THEN
      poiStatus := SQLCODE;
      RETURN;
  END;

  -- Send update information back to caller
  IF tabTypRsn2(1).reason_group NOT IN ('STM', 'MPK') THEN
    get_range_returns(0, rwTypPutlst.pallet_id,
                      iNumRtns, iNumCurRtns, iNumWtRtns, iNumTempRtns,
                      tabTypRtn, 0, 'LP', NULL, pRwTypRtn.erm_line_id, 0, 'ALL',
                      1, 9999);
  ELSE
    get_range_returns(0, pRwTypRtn.obligation_no,
                      iNumRtns, iNumCurRtns, iNumWtRtns, iNumTempRtns,
                      tabTypRtn, 0,
                      NVL(pRwTypRtn.returned_prod_id, pRwTypRtn.prod_id),
                      NVL(pRwTypRtn.cust_pref_vendor, C_DFT_CPV),
                      pRwTypRtn.erm_line_id, 0, 'ALL',
                      1, 9999);
  END IF;
  IF iNumRtns = 0 THEN
    poiStatus := C_UPD_PUTLST_FAIL;
    RETURN;
  END IF;
  DBMS_OUTPUT.PUT_LINE('Sent RETURNS to caller');
--pl_log.ins_msg('I', 'pl_dci', 'Sent RETURNS to caller', 0, 0);
  poRcTypRtn.manifest_no := tabTypRtn(1).manifest_no;
  poRcTypRtn.route_no := tabTypRtn(1).route_no;
  poRcTypRtn.stop_no := tabTypRtn(1).stop_no;
  poRcTypRtn.rec_type := tabTypRtn(1).rec_type;
  poRcTypRtn.obligation_no := tabTypRtn(1).obligation_no;
  poRcTypRtn.prod_id := tabTypRtn(1).prod_id;
  poRcTypRtn.cust_pref_vendor := tabTypRtn(1).cust_pref_vendor;
  poRcTypRtn.reason_code := tabTypRtn(1).reason_code;
  poRcTypRtn.returned_qty := tabTypRtn(1).returned_qty;
  poRcTypRtn.returned_split_cd := tabTypRtn(1).returned_split_cd;
  poRcTypRtn.weight := tabTypRtn(1).weight;
  poRcTypRtn.disposition := tabTypRtn(1).disposition;
  poRcTypRtn.returned_prod_id := tabTypRtn(1).returned_prod_id;
  poRcTypRtn.erm_line_id := tabTypRtn(1).erm_line_id;
  poRcTypRtn.shipped_qty := tabTypRtn(1).shipped_qty;
  poRcTypRtn.shipped_split_cd := tabTypRtn(1).shipped_split_cd;
  poRcTypRtn.temp := tabTypRtn(1).temp;
  poRcTypRtn.catch_wt_trk := tabTypRtn(1).catch_wt_trk;
  poRcTypRtn.temp_trk := tabTypRtn(1).temp_trk;
  poRcTypRtn.orig_invoice := tabTypRtn(1).orig_invoice;
  poRcTypRtn.dest_loc := tabTypRtn(1).dest_loc;
  poRcTypRtn.pallet_id := tabTypRtn(1).pallet_id;
  poRcTypRtn.rtn_label_printed := tabTypRtn(1).rtn_label_printed;
  poRcTypRtn.pallet_batch_no := tabTypRtn(1).pallet_batch_no;
  poRcTypRtn.parent_pallet_id := tabTypRtn(1).parent_pallet_id;
  poRcTypRtn.putaway_put := tabTypRtn(1).putaway_put;
  poRcTypRtn.pallet_type := tabTypRtn(1).pallet_type;
  poRcTypRtn.ti := tabTypRtn(1).ti;
  poRcTypRtn.hi := tabTypRtn(1).hi;
  poRcTypRtn.min_temp := tabTypRtn(1).min_temp;
  poRcTypRtn.max_temp := tabTypRtn(1).max_temp;
  poRcTypRtn.min_weight := tabTypRtn(1).min_weight;
  poRcTypRtn.max_weight := tabTypRtn(1).max_weight;
  poRcTypRtn.descrip := tabTypRtn(1).descrip;

  poiStatus := C_NORMAL;
EXCEPTION
  WHEN OTHERS THEN
    poRcTypRtn := NULL;
    poiStatus := SQLCODE;
END;
-- -----------------------------------------------------------------------------

PROCEDURE client_update_return (
  piInvokeTime  IN  NUMBER,
  pRwTypRtn IN  returns%ROWTYPE,
  poszRtn   OUT VARCHAR2,
  poszMsg   OUT VARCHAR2,
  poszLMStr OUT VARCHAR2,
  poiStatus OUT NUMBER) IS
  rcTypRtn      recTypRtn := NULL;
  iStatus       NUMBER := C_NORMAL;
BEGIN
  poszRtn := NULL;
  poszMsg := NULL;

  update_return(piInvokeTime, pRwTypRtn, rcTypRtn, poszMsg, poszLMStr, iStatus);
  IF iStatus = C_NORMAL THEN
    poszRtn := poszRtn || RPAD(rcTypRtn.manifest_no, C_MF_NO_LEN);
    poszRtn := poszRtn || RPAD(NVL(rcTypRtn.route_no, ' '), C_ROUTE_NO_LEN);
    poszRtn := poszRtn ||
               RPAD(NVL(TO_CHAR(rcTypRtn.stop_no), ' '), C_STOP_NO_LEN);
    poszRtn := poszRtn || RPAD(rcTypRtn.obligation_no, C_INV_NO_LEN);
    poszRtn := poszRtn || RPAD(rcTypRtn.prod_id, C_PROD_ID_LEN);
    poszRtn := poszRtn || RPAD(rcTypRtn.cust_pref_vendor, C_CPV_LEN);
    poszRtn := poszRtn || RPAD(rcTypRtn.reason_code, C_REASON_LEN);
    poszRtn := poszRtn ||
               LPAD(NVL(TO_CHAR(rcTypRtn.returned_qty), '0'), C_QTY_LEN, '0');
    poszRtn := poszRtn || RPAD(rcTypRtn.returned_split_cd, C_UOM_LEN);
    poszRtn := poszRtn ||
               LPAD(NVL(TO_CHAR(rcTypRtn.weight), '0'), C_WEIGHT_LEN, '0');
    poszRtn := poszRtn || RPAD(NVL(rcTypRtn.disposition, ' '), C_REASON_LEN);
    poszRtn := poszRtn ||
               RPAD(NVL(rcTypRtn.returned_prod_id, ' '), C_PROD_ID_LEN);
    poszRtn := poszRtn ||
               LPAD(TO_CHAR(rcTypRtn.erm_line_id), C_LINE_ID_LEN, '0');
    poszRtn := poszRtn ||
               LPAD(NVL(TO_CHAR(rcTypRtn.shipped_qty), '0'), C_QTY_LEN, '0');
    poszRtn := poszRtn || RPAD(NVL(rcTypRtn.shipped_split_cd, '0'), C_UOM_LEN);
    poszRtn := poszRtn || RPAD(NVL(rcTypRtn.cust_id, ' '), C_CUST_ID_LEN);
    poszRtn := poszRtn ||
               LPAD(NVL(TO_CHAR(rcTypRtn.temp), '0'), C_TEMP_LEN, '0');
    poszRtn := poszRtn || RPAD(NVL(rcTypRtn.catch_wt_trk, 'N'), C_ONECHAR_LEN);
    poszRtn := poszRtn || RPAD(NVL(rcTypRtn.temp_trk, 'N'), C_ONECHAR_LEN);
    poszRtn := poszRtn || RPAD(NVL(rcTypRtn.orig_invoice, ' '), C_INV_NO_LEN);
    poszRtn := poszRtn || RPAD(NVL(rcTypRtn.dest_loc, ' '), C_LOC_LEN);
    poszRtn := poszRtn || RPAD(NVL(rcTypRtn.pallet_id, ' '), C_PALLET_ID_LEN);
    poszRtn := poszRtn ||
               RPAD(NVL(rcTypRtn.rtn_label_printed, 'N'), C_ONECHAR_LEN);
    poszRtn := poszRtn ||
               RPAD(NVL(rcTypRtn.pallet_batch_no, ' '), C_BATCH_NO_LEN);
    poszRtn := poszRtn ||
               RPAD(NVL(rcTypRtn.parent_pallet_id, ' '), C_PALLET_ID_LEN);
    poszRtn := poszRtn || LPAD(NVL(TO_CHAR(rcTypRtn.ti), '0'), C_TIHI_LEN, '0');
    poszRtn := poszRtn || LPAD(NVL(TO_CHAR(rcTypRtn.hi), '0'), C_TIHI_LEN, '0');
    poszRtn := poszRtn || RPAD(rcTypRtn.descrip, C_DESCRIP_LEN);
  END IF;

  poiStatus := iStatus;
END;
-- -----------------------------------------------------------------------------

PROCEDURE get_return_info (
  pszValue1     IN  inv.logi_loc%TYPE,
  poiNumRtns        OUT NUMBER,
  poiNumWeightRtns  OUT NUMBER,
  poiNumTempRtns    OUT NUMBER,
  potabTypRtns      OUT tabTypReturns,
  poiStatus     OUT NUMBER,
  pszValue2     IN  pm.prod_id%TYPE DEFAULT NULL,
  pszValue3     IN  pm.cust_pref_vendor%TYPE DEFAULT C_DFT_CPV) IS
  rwTypRtn      returns%ROWTYPE := NULL;
  iNumRtns      NUMBER := 0;
  iNumCurRtns       NUMBER := 0;
  iNumWeightRtns    NUMBER := 0;
  iNumTempRtns      NUMBER := 0;
  tabTypRtns        tabTypReturns;
BEGIN
  poiNumRtns := 0;
  poiNumWeightRtns := 0;
  poiNumTempRtns := 0;
  poiStatus := C_NORMAL;

  -- Search as license plate first
  BEGIN
    SELECT TO_NUMBER(SUBSTR(pt.rec_id, 2)), pt.lot_id,
           pt.prod_id, pt.cust_pref_vendor, pt.erm_line_id
    INTO rwTypRtn.manifest_no, rwTypRtn.obligation_no, rwTypRtn.prod_id,
         rwTypRtn.cust_pref_vendor, rwTypRtn.erm_line_id
    FROM putawaylst pt
    WHERE pallet_id = pszValue1;
    -- License plate is found. Retrieve the real invoiced item according to
    -- line ID
    BEGIN
      SELECT prod_id INTO rwTypRtn.prod_id
      FROM returns
      WHERE manifest_no = rwTypRtn.manifest_no
      AND   DECODE(INSTR(obligation_no, 'L'), 0, obligation_no,
                   SUBSTR(obligation_no, 1, INSTR(obligation_no, 'L') - 1)) =
            rwTypRtn.obligation_no
      AND   erm_line_id = rwTypRtn.erm_line_id;
    EXCEPTION
      WHEN OTHERS THEN
        poiStatus := SQLCODE;
        RETURN;
    END;
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      -- The 1st search criteria is not a license plate. Try to search data
      -- as invoice/item/cust_pref_vendor then
      rwTypRtn.obligation_no := pszValue1;
      rwTypRtn.prod_id := pszValue2;
      rwTypRtn.cust_pref_vendor := pszValue3;
      rwTypRtn.erm_line_id := NULL;
    WHEN OTHERS THEN
      poiStatus := SQLCODE;
      RETURN;
  END;

  -- Retrieve all returns related to the invoice/item/line. Line will be NULL
  -- if the search criteria is invoice/item but not license plate
  get_range_returns(-1, rwTypRtn.obligation_no, iNumRtns, iNumCurRtns, 
                    iNumWeightRtns, iNumTempRtns, tabTypRtns, 0,
                    rwTypRtn.prod_id, rwTypRtn.cust_pref_vendor,
                    rwTypRtn.erm_line_id);
  poiNumRtns := iNumRtns;
  poiNumWeightRtns := iNumWeightRtns;
  poiNumTempRtns := iNumTempRtns;
  potabTypRtns := tabTypRtns;
  poiStatus := C_NORMAL;

EXCEPTION
  WHEN OTHERS THEN
    poiStatus := SQLCODE;
    RETURN;
END;
-- -----------------------------------------------------------------------------

PROCEDURE get_client_return_info (
  pszValue1     IN  inv.logi_loc%TYPE,
  poiNumRtns        OUT NUMBER,
  poiNumWeightRtns  OUT NUMBER,
  poiNumTempRtns    OUT NUMBER,
  poszRtns      OUT VARCHAR2,
  poiStatus     OUT NUMBER,
  pszValue2     IN  pm.prod_id%TYPE DEFAULT NULL,
  pszValue3     IN  pm.cust_pref_vendor%TYPE DEFAULT C_DFT_CPV) IS
  tabTypRtns        tabTypReturns;
  iStatus       NUMBER := C_NORMAL;
BEGIN
  poszRtns := NULL;
  poiStatus := C_NORMAL;

  -- Retrieve information that met the search criteria
  get_return_info(pszValue1, poiNumRtns, poiNumWeightRtns, poiNumTempRtns,
                  tabTypRtns, iStatus, pszValue2, pszValue3);
  IF iStatus <> C_NORMAL THEN
    poiStatus := iStatus;
    RETURN;
  END IF;

  -- Sent back to caller as a long string
  assign_to_caller(tabTypRtns, poszRtns);
EXCEPTION
  WHEN OTHERS THEN
    poszRtns := NULL;
    poiStatus := SQLCODE;
END;
-- -----------------------------------------------------------------------------

FUNCTION  f_get_rtn_date (pDestLoc IN VARCHAR2)
    RETURN DATE IS
BEGIN
    IF pl_ml_common.f_is_induction_loc(pDestLoc) = 'Y' THEN
        RETURN ('01-JAN-2001');
    ELSE
        RETURN (SYSDATE);
    END IF;   
EXCEPTION
    WHEN OTHERS THEN
        RETURN ('01-JAN-2001');
END;
-- -----------------------------------------------------------------------------

FUNCTION f_clear_inv (
  psReasonGroup IN  reason_cds.reason_group%TYPE,
  rwTypPutlst   IN  putawaylst%ROWTYPE)
RETURN NUMBER IS
  iStatus   NUMBER := C_NORMAL;
  iRule     zone.rule_id%TYPE := -1;
  sPerm     loc.perm%TYPE := NULL;
  iQty      inv.qoh%TYPE := NULL;
  CURSOR c_get_loc_type(csLoc IN loc.logi_loc%TYPE) IS
    SELECT z.rule_id, l.perm
    FROM zone z, lzone lz, loc l
    WHERE z.zone_id = lz.zone_id
    AND   z.zone_type = 'PUT'
    AND   lz.logi_loc = csLoc
    AND   lz.logi_loc = l.logi_loc;
  CURSOR c_get_qplan(
           csItem   IN inv.prod_id%TYPE,
           csPerm   IN loc.perm%TYPE,
           csLoc    IN loc.logi_loc%TYPE,
           csPallet IN inv.logi_loc%TYPE) IS
    SELECT NVL(qty_planned, 0)
    FROM inv
    WHERE prod_id = csItem
    AND   plogi_loc =  csLoc
    AND   (((csPerm = 'Y') AND (logi_loc = csLoc)) OR
           ((csPerm = 'N') AND (logi_loc = csPallet)))
    AND   NVL(qty_planned, 0) = 0;
BEGIN
  IF psReasonGroup IN ('NOR') THEN
    OPEN c_get_loc_type(rwTypPutlst.dest_loc);
    FETCH c_get_loc_type INTO iRule, sPerm;
    IF c_get_loc_type%NOTFOUND THEN
      iRule := -1;
      sPerm := 'N';
    END IF;
    CLOSE c_get_loc_type;
    IF iRule = -1 THEN
      -- Cannot find the location type for the location
      iStatus := C_INV_LOC;
    ELSE
      -- Check if we need to remove the current inventory record
      BEGIN
        UPDATE inv
          SET qty_planned = NVL(qty_planned, 0) - NVL(rwTypPutlst.qty, 0)
          WHERE prod_id = rwTypPutlst.prod_id
          AND   plogi_loc = rwTypPutlst.dest_loc
          AND   (((sPerm = 'Y') AND (logi_loc = rwTypPutlst.dest_loc)) OR
                 ((sPerm = 'N') AND (logi_loc = rwTypPutlst.pallet_id)))
          AND   NVL(qty_planned, 0) - NVL(rwTypPutlst.qty, 0) >= 0
          AND   NVL(qty_alloc, 0) = 0;
        IF sql%rowcount > 0 THEN
          OPEN c_get_qplan(rwTypPutlst.prod_id, sPerm, rwTypPutlst.dest_loc,
                           rwTypPutlst.pallet_id);
          FETCH c_get_qplan INTO iQty;
          IF c_get_qplan%FOUND THEN
            IF iQty = 0 AND sPerm = 'N' THEN
              BEGIN
                DELETE inv
                  WHERE prod_id = rwTypPutlst.prod_id
                  AND   plogi_loc = rwTypPutlst.dest_loc
                  AND   logi_loc = rwTypPutlst.pallet_id
                  AND   NVL(qty_planned, 0) = 0
                  AND   NVL(qty_alloc, 0) = 0;
              EXCEPTION
                WHEN OTHERS THEN
                  NULL;          
              END;
            END IF;
          END IF;
          CLOSE c_get_qplan;
        END IF;
      EXCEPTION
         WHEN NO_DATA_FOUND THEN
           NULL;
         WHEN OTHERS THEN
           iStatus := C_INV_LOC;
      END;
    END IF;
  END IF;

  RETURN iStatus;
END;
-- -----------------------------------------------------------------------------

PROCEDURE dci_food_safety
               (i_ins_del_upd in varchar2,
                i_manifest_no in varchar2,
	        i_stop_no in varchar2,
	        i_prod_id in varchar2,
	        i_obligation_no in varchar2,
	        i_cust_id in manifest_stops.customer_id%TYPE,
          	i_temp in number,
       	        i_source in varchar2,
        	 i_date in date,
		 i_reason_cd in varchar2,
		 i_reason_group in varchar2,
         	 o_msg out varchar) IS
         /* i_ins_del_upd valid value is D for Delete, I for Insert and U for Update */ 
          l_food_safety_enable varchar2(1);
          l_exists_fso     number;
          l_food_track varchar2(1);
          is_rtn_pikup varchar2(1);
	  --
	  l_application_func swms_log.application_func%TYPE := 'DRIVER CHECKIN';
	  l_message          swms_log.msg_text%TYPE;
	  l_procedure_name   swms_log.procedure_name%TYPE := 'pl_dci.dci_food_safety';
	  l_get_cust_id      manifest_stops.customer_id%TYPE;
	  l_invoice_return_limit  number := 3;
	  l_proceed_insert_fso  BOOLEAN;
	  l_count_invoice       number := 0;

	  --
	  CURSOR ck_exist_fso IS
	  SELECT 1
	  FROM food_safety_outbound
          where manifest_no   =i_manifest_no
	  and   stop_no       =i_stop_no
	  and   prod_id       =i_prod_id
	  and   obligation_no =i_obligation_no;
	  --
	  CURSOR ck_haccp_codes IS
          SELECT nvl(hc.FOOD_SAFETY_TRK,'N')
          FROM PM p,HACCP_CODES hc
          WHERE nvl(p.HAZARDOUS,'X') = hc.HACCP_CODE
          AND p.prod_id         = i_prod_id;
	  --
	  CURSOR get_cust_id IS
	  select customer_id
	  from manifest_stops
	  where manifest_no = i_manifest_no
	  and   obligation_no = i_obligation_no;
	  --
	  CURSOR ck_invoice_return IS
	  select count(*)
	  from food_safety_outbound
	  where obligation_no = i_obligation_no
	  and   manifest_no = i_manifest_no
	  and   reason_group = i_reason_group;

BEGIN
l_invoice_return_limit := pl_common.f_get_syspar('FOOD_SAFETY_INVOICE_COLLECT',3);	
l_food_safety_enable := pl_common.f_get_syspar('FOOD_SAFETY_DCI', 'N');
o_msg  := null;

IF l_food_safety_enable ='Y' then
   OPEN ck_haccp_codes;
   FETCH ck_haccp_codes into l_food_track;
   IF ck_haccp_codes%NOTFOUND then
          l_food_track := 'N';
   END IF;
   CLOSE ck_haccp_codes;

   IF i_ins_del_upd = 'I' THEN --Insert record
      IF l_food_track = 'Y' THEN
	 IF i_cust_id is null THEN
	    l_get_cust_id := null;
	    OPEN get_cust_id;
	    FETCH get_cust_id into l_get_cust_id;
	    IF get_cust_id%NOTFOUND THEN
	           l_get_cust_id := 'N/A'; 
	    END IF;
	    CLOSE get_cust_id;
         ELSE
	    l_get_cust_id := i_cust_id;
	 END IF;
	 OPEN ck_exist_fso;
	 FETCH ck_exist_fso INTO l_exists_fso;
	 IF ck_exist_fso%NOTFOUND THEN
            l_proceed_insert_fso := TRUE;
           /* if it is invoice return then limit number of collection base on syspar */ 
	    IF i_reason_group = 'WIN' THEN 
	       OPEN ck_invoice_return;
	       FETCH ck_invoice_return into l_count_invoice;
	       IF l_invoice_return_limit > l_count_invoice THEN
		  l_proceed_insert_fso := TRUE;
               ELSE
		  l_proceed_insert_fso := FALSE;
	       END IF;
	       CLOSE ck_invoice_return;
	    END IF;--l_reason_group=WIN

	    IF l_proceed_insert_fso THEN
    	         INSERT INTO food_safety_outbound 
	           (manifest_no, stop_no, prod_id, obligation_no, customer_id,
	            temp_collected, add_source, time_collected, add_date, add_user,
	 	    reason_cd, reason_group)
	         Values 
	           (i_manifest_no, i_stop_no, i_prod_id, i_obligation_no, l_get_cust_id,
	            i_temp, i_source, i_date , i_date, REPLACE(USER,'OPS$',NULL),
		    i_reason_cd, i_reason_group);
	    END IF;
	 ELSE --exist food_safety_outbound record
	    IF i_temp is not null THEN
               UPDATE food_safety_outbound 
                  set temp_collected = i_temp,
	           time_collected = i_date,
	           upd_date = i_date,
	           upd_user = REPLACE(USER,'OPS$',NULL),
	           upd_source =  i_source
                WHERE  manifest_no =i_manifest_no
          	    and   stop_no =i_stop_no
	            and   prod_id =i_prod_id
          	    and   obligation_no =i_obligation_no;
	    END IF;
	 END IF; --ck_exist_fso found or not
	 CLOSE ck_exist_fso; --closing ck_exist_fso
      END IF; --l_food_track is Y
   ELSIF i_ins_del_upd = 'U' THEN
      IF l_food_track = 'Y' THEN
	    IF i_temp is not null THEN
               UPDATE food_safety_outbound 
                  set temp_collected = i_temp,
	           time_collected = i_date,
	           upd_date = i_date,
	           upd_user = REPLACE(USER,'OPS$',NULL),
	           upd_source =  i_source
                WHERE  manifest_no =i_manifest_no
          	    and   stop_no =i_stop_no
	            and   prod_id =i_prod_id
          	    and   obligation_no =i_obligation_no;
	     END IF; 
      END IF; --l_food_track is Y
   ELSIF i_ins_del_upd = 'D' THEN
         OPEN ck_exist_fso;
         FETCH ck_exist_fso INTO l_exists_fso;
         IF ck_exist_fso%FOUND THEN
            DELETE FROM food_safety_outbound 
            WHERE  manifest_no =i_manifest_no
	     and   prod_id =i_prod_id
             and   obligation_no =i_obligation_no;
         END IF;	
         CLOSE ck_exist_fso;
   ELSE
        l_message := 'i_ins_del_upd is not D,U or I value ON manifest#: ' || i_manifest_no ||
		     '  obligation#: ' || i_obligation_no || '  ProdID: ' || i_prod_id;
      pl_log.ins_msg('W',l_procedure_name,l_message,NULL,NULL);
   END IF;--i_ins_del_upd are valid values
END IF; -- l_food_safety_enable is Y

   EXCEPTION when OTHERS then 
        l_message := 'SEE SWMS_LOG FOR EXCEPTION WHEN OTHERS ERROR MESSAGE ON manifest#: ' || i_manifest_no ||
		     '  obligation#: ' || i_obligation_no || '  ProdID: ' || i_prod_id;
	pl_log.ins_msg('F',l_procedure_name,l_message,SQLCODE,SQLERRM);
	o_msg := l_message;

END;

/**************************************************************************
    --
    -- create_stc_for_pod()
    --
    -- Description:      Creates STC transactions for given manifest.
    --                   Logic taken from procedure create_stc_for_pod_td in
    --                   form rtnscls.fmb.
    --
    -- Parameters:       i_manifest_no:         manifest#
    --
    -- Return/output:    status code indicating success or error.
    --
    -- Modification log:
    --
    -- Date         Developer     Change
    -- ------------------------------------------------------------------
    -- 28-SEP-2021   mcha1213     Initial version.
    --
***************************************************************************/
FUNCTION create_stc_for_pod (
        i_manifest_no           IN  manifests.manifest_no%TYPE
) return rf.status IS

    l_func_name  CONSTANT  swms_log.procedure_name%TYPE := 'create_stc_for_pod';
    l_status               rf.status := rf.status_normal;
    l_msg                  swms_log.msg_text%TYPE;

    l_manifest_no          manifest_stops.manifest_no%TYPE;
    l_stop_no              manifest_stops.stop_no%TYPE;
    l_pod_flag             manifest_stops.pod_flag%type;
    l_cnt                  PLS_INTEGER;
	 l_count_stc            PLS_INTEGER;
    l_application_func swms_log.application_func%TYPE := 'DRIVER CHECKIN'; --9/28/21
    PACKAGE_NAME        CONSTANT   swms_log.program_name%TYPE := 'PL_DCI'; --9/28/21


    CURSOR c_stop_records IS
        select distinct a.manifest_no,a.stop_no,a.customer_id cust_id,nvl(a.pod_flag,'N') pod_flag, b.route_no
        from manifest_stops a ,  manifests b
        where a.manifest_no = i_manifest_no
        and a.manifest_no   = b.manifest_no
        order by a.manifest_no,a.stop_no,a.customer_id;

BEGIN

    pl_log.ins_msg('INFO', l_func_name, 'Step 1', SQLCODE, SUBSTR(SQLERRM, 1, 500), l_application_func, PACKAGE_NAME);

    FOR r_available in c_stop_records LOOP

       /*     select distinct pod_flag
            INTO   l_pod_flag
            from   manifest_stops
            where  manifest_no = i_manifest_no
              and  stop_no=floor( to_number(r_available.alt_stop_no))
              and  customer_id = r_available.cust_id;

            select count(*)
            into   l_cnt
            from   sts_route_in
            where  alt_stop_no = floor( to_number(r_available.alt_stop_no) )
              and  manifest_no = i_manifest_no;  */

        IF  r_available.pod_flag = 'Y' then

            l_count_stc :=0;

            SELECT count(*)
                INTO   l_count_stc
                FROM   trans
                WHERE  trans_type = 'STC'
                  AND  stop_no = r_available.stop_no
                  AND  cust_id = r_available.cust_id
                  AND  route_no = r_available.route_no
                  AND  rec_id = i_manifest_no;

            IF  l_count_stc > 0 THEN
                    NULL;
            ELSE

                pl_log.ins_msg('INFO', l_func_name, 'before trans insertion', SQLCODE, SUBSTR(SQLERRM, 1, 500), l_application_func, PACKAGE_NAME);

                    -- insert STC transaction
                BEGIN
                    INSERT INTO TRANS
                        (      TRANS_ID,
                               TRANS_TYPE,
                               TRANS_DATE,
                               batch_no,
                               ROUTE_NO,
                               STOP_NO,
                               REC_ID,
                               UPLOAD_TIME,
                               USER_ID,
                               CUST_ID
                        )
                    VALUES
                        (      TRANS_ID_SEQ.NEXTVAL,
                               'STC',
                               SYSDATE,
                               '77',
                               r_available.route_no,
                               r_available.stop_no,
                               i_manifest_no,
                               to_date('01-JAN-1980','DD-MON-YYYY'),
                               USER, --'SWMS',
                               r_available.cust_id
                        );

                    UPDATE MANIFEST_STOPS
                        SET POD_STATUS_FLAG='S'
                        WHERE stop_no=r_available.stop_no
                        AND  customer_id = r_available.cust_id
                        AND  manifest_no= i_manifest_no;

                    l_msg := 'inserted into trans STC for manifest# ['
                              || i_manifest_no
                              || '] stop# ['
                              || r_available.stop_no
                              || ']';
                        pl_log.ins_msg('INFO', l_func_name, l_msg, null, null, l_application_func, PACKAGE_NAME);

                EXCEPTION
                    WHEN OTHERS THEN
                            l_status := rf.status_data_error;
                            l_msg := 'Insert STC into Trans Failed for manifest# ['
                                  || i_manifest_no
                                  || ']';
                            pl_log.ins_msg('FATAL', l_func_name, l_msg, SQLCODE, SUBSTR(SQLERRM, 1, 500), l_application_func, PACKAGE_NAME);

                END;   -- insert STC transaction
            END IF;   -- checking l_count_stc and l_cnt
        END IF;   -- checking l_pod_flag
    END LOOP;

    return l_status;

EXCEPTION
    WHEN OTHERS THEN
        l_status := rf.status_data_error;
        l_msg := 'Insert STC into Trans Failed for manifest# ['
                  || i_manifest_no
                  || ']';
        pl_log.ins_msg('FATAL', l_func_name, l_msg, SQLCODE, SUBSTR(SQLERRM, 1, 500), l_application_func, PACKAGE_NAME);
        return l_status;

END create_stc_for_pod;


-- -----------------------------------------------------------------------------
END pl_dci;
/
