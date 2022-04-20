CREATE OR REPLACE PACKAGE pl_rf_dci_pod AS

    ----------------------
    -- Package constants
    ----------------------

    PACKAGE_NAME          CONSTANT   swms_log.program_name%TYPE     := 'PL_RF_DCI_POD';
    APPLICATION_FUNC      CONSTANT   swms_log.application_func%TYPE := 'DRIVER CHECKIN';
    VAL_TRIPMASTER_FAIL   CONSTANT   NUMBER                         := -1;
    NULL_VAL_INDICATOR    CONSTANT   NUMBER                         := -999; 

    ---------------------------------
    -- function/procedure signatures 
    ---------------------------------

    FUNCTION validate_sts (
        i_manifest_no IN manifests.manifest_no%TYPE
    ) return rf.status;

    FUNCTION get_upc_list_for_item (
        i_prod_id  IN  pm.prod_id%TYPE,
        i_cpv      IN  pm.cust_pref_vendor%TYPE
    ) return rtn_upc_table;

    FUNCTION get_manifest_returns (
        i_manifest_no           IN  manifests.manifest_no%TYPE,
        i_pct_tolerance         IN  NUMBER,
        i_max_food_safety_temp  IN  NUMBER
    ) return rtn_item_table;

    FUNCTION validate_manifest_returns (
        i_rf_log_init_rec       IN  rf_log_init_record,
        i_manifest_sos_label    IN  NUMBER,
        i_dci_ready_override    IN  VARCHAR2,
        o_returned_items_list   OUT rtn_validation_obj,
        o_printer_name          OUT VARCHAR2            --OPCOF-3226 - POD-Label Print
    ) return rf.status;

     FUNCTION validate_mf_rtn (
        i_manifest_no           IN  manifests.manifest_no%TYPE,
        i_dci_ready_override    IN  VARCHAR2,
        o_returned_items_list   OUT rtn_validation_obj
    ) return rf.status;

    FUNCTION get_order_seq_no (
        i_route_no           IN  route.route_no%TYPE,
        i_stop_no            IN  returns.stop_no%TYPE,
        i_order_id           IN  returns.obligation_no%TYPE,
        i_prod_id            IN  returns.prod_id%TYPE,
        i_cpv                IN  returns.cust_pref_vendor%TYPE,
        i_returned_split_cd  IN  returns.returned_split_cd%TYPE
    ) return rtn_order_seq_table;

    FUNCTION delete_return (
        i_rf_log_init_rec       IN  rf_log_init_record,
        i_manifest_no           IN  returns.manifest_no%TYPE,
        i_stop_no               IN  returns.stop_no%TYPE,
        i_obligation_no         IN  returns.obligation_no%TYPE,
        i_prod_id               IN  returns.prod_id%TYPE,
        i_cpv                   IN  returns.cust_pref_vendor%TYPE,
        i_return_reason_cd      IN  returns.return_reason_cd%TYPE,
        i_returned_split_cd     IN  returns.returned_split_cd%TYPE
    ) return rf.status;

    FUNCTION delete_rtn (
        i_manifest_no           IN  returns.manifest_no%TYPE,
        i_stop_no               IN  returns.stop_no%TYPE,
        i_obligation_no         IN  returns.obligation_no%TYPE,
        i_prod_id               IN  returns.prod_id%TYPE,
        i_cpv                   IN  returns.cust_pref_vendor%TYPE,
        i_return_reason_cd      IN  returns.return_reason_cd%TYPE,
        i_returned_split_cd     IN  returns.returned_split_cd%TYPE
    ) return rf.status;

    FUNCTION invoice_return (
        i_rf_log_init_rec       IN  rf_log_init_record,
        i_action                IN  VARCHAR2,
        i_manifest_no           IN  manifests.manifest_no%TYPE,
        i_obligation_no         IN  returns.obligation_no%TYPE,
        i_return_reason_cd      IN  returns.return_reason_cd%TYPE,
        o_returned_items_list   OUT rtn_validation_obj
    ) return rf.status;

    FUNCTION add_invoice_rtn (
        i_manifest_no           IN  manifests.manifest_no%TYPE,
        i_obligation_no         IN  returns.obligation_no%TYPE,
        i_return_reason_cd      IN  returns.return_reason_cd%TYPE
    ) return rf.status;

    FUNCTION delete_invoice_rtn (
        i_manifest_no           IN  manifests.manifest_no%TYPE,
        i_obligation_no         IN  returns.obligation_no%TYPE
    ) return rf.status;

    FUNCTION verify_mf_is_opn (
        i_manifest_no           IN  manifests.manifest_no%TYPE,
        o_mf_status             OUT manifests.manifest_status%TYPE,
        o_route_no              OUT manifests.route_no%TYPE,
        o_dci_ready             OUT manifests.sts_completed_ind%TYPE
    ) return rf.status;

    FUNCTION verify_mf_is_opn (
        i_manifest_no           IN  manifests.manifest_no%TYPE
    ) return rf.status;

    FUNCTION delete_rtn_pending_puts (
        i_manifest_no           IN  manifests.manifest_no%TYPE,
        i_erm_line_id           IN  returns.erm_line_id%TYPE
    ) return rf.status;

    FUNCTION verify_mf_is_not_cls (
        i_manifest_no           IN  manifests.manifest_no%TYPE,
        o_mf_status             OUT manifests.manifest_status%TYPE,
        o_route_no              OUT manifests.route_no%TYPE
    ) return rf.status;

    FUNCTION delete_mf_collected_data (
        i_manifest_no           IN  manifests.manifest_no%TYPE
    ) return rf.status;

    FUNCTION insert_float_hist (
        i_manifest_no   IN  manifests.manifest_no%TYPE
    ) return rf.status;

    FUNCTION manifest_close (
        i_rf_log_init_rec       IN  rf_log_init_record,
        i_manifest_no           IN  manifests.manifest_no%TYPE,
        i_accessory_override    IN  VARCHAR2
    ) return rf.status;

    FUNCTION mf_close (
        i_manifest_no           IN  manifests.manifest_no%TYPE,
        i_accessory_override    IN  VARCHAR2
    ) return rf.status;

    FUNCTION create_stc_for_pod (
        i_manifest_no           IN  manifests.manifest_no%TYPE
    ) return rf.status;

    FUNCTION insert_cc_tasks (
        rtn_prod_id         returns.prod_id%TYPE,
        rtn_cpv             returns.cust_pref_vendor%TYPE,
        rtn_reason_grp      reason_cds.reason_group%TYPE,
        rtn_reason          returns.return_reason_cd%TYPE,
        rtn_uom             NUMBER,
        rtn_qty             returns.returned_qty%TYPE,
        i_reason            reason_cds.reason_cd%TYPE
    ) return rf.status;

    PROCEDURE get_cc_reason (
        rtn_reason_cd in  VARCHAR2, 
        v_ccr         out VARCHAR2);

    FUNCTION get_put_loc (
        p_rec_id   IN VARCHAR2,
        p_prod_id  IN VARCHAR2,
        p_cpv      IN VARCHAR2,
        p_rsn_grp  IN VARCHAR2,
        p_reason   IN VARCHAR2,
        p_line     IN NUMBER
    ) RETURN VARCHAR2;

    FUNCTION f_get_order_line_id(
        i_prod_id IN VARCHAR2,
        i_cpv     IN VARCHAR2,
        i_obligation_no IN VARCHAR2,
        i_orig_invoice IN VARCHAR2,
        i_return_split_cd IN VARCHAR2
    ) RETURN NUMBER;

    FUNCTION mf_cls_process_returns (
        i_manifest_no   IN  manifests.manifest_no%TYPE,
        i_pod_enable    IN  VARCHAR2,
        i_mf_status     IN  manifests.manifest_status%TYPE
    ) return rf.status;

 --   ======================================= Ben Changes ======================================================
    -- 06-NOV-2020  ECLA1411      OPCOF-3226 - POD Returns - Print Process For RF Host
    -- prints labels for records in the manifest that
    -- (a) not already printed, and
    -- (b) other filters provided by Kiet
    FUNCTION print_return (
        i_rf_log_init_rec IN rf_log_init_record,
        i_manifest_no IN returns.manifest_no%TYPE,
        i_wherePrinted IN varchar2 -- M = Mobile, S = Server
    ) return rf.status;
--   ======================================= End Ben Changes ===================================================

 --  ======================================= Add RTN sepcs======================================================
   FUNCTION add_rtn_qry(
      i_manifest_no   IN manifests.manifest_no%TYPE,
      i_Reason_cd     IN Returns.return_reason_cd%type,
      i_obligation_no IN Returns.obligation_no%type,
      i_prod_id       IN PM.prod_id%type,
      i_upc           IN pm.external_upc%type,
      i_sos           IN  Varchar2,
      o_returned_items_list OUT rtn_item_table) RETURN rf.status;

   FUNCTION get_add_rtn_rf(
      i_rf_log_init_rec IN  rf_log_init_record,
      i_manifest_no     IN manifests.manifest_no%TYPE,
      i_reason_cd       IN returns.return_reason_cd%TYPE,
      i_obligation_no   IN returns.obligation_no%TYPE,
      i_prod_id         IN pm.prod_id%TYPE,
      i_upc             IN pm.external_upc%TYPE,
      i_sos             IN  Varchar2,
      o_returned_items_list   OUT rtn_validation_obj)  return rf.status;

   --==================================== Create Puts specs===================================================
    FUNCTION createputs_main(p_Manifest_No number) return rf.status;

    FUNCTION CreatePuts_for_returns (
        i_rf_log_init_rec       IN  rf_log_init_record,
        i_manifest_no           IN  manifests.manifest_no%TYPE,
        o_returned_items_list   OUT rtn_validation_obj) return rf.status;

  ---=============================================Save RTN specs===================================================
  FUNCTION save_rtn(
    i_action            IN VARCHAR2 := 'A', --A,U,R,C (possible values)
    i_manifest_no       IN returns.manifest_no%TYPE,
    i_route_no          IN returns.route_no%TYPE,
    i_orig_rtn_item_rec IN rtn_item_rec,
    i_new_rtn_item_rec  IN rtn_item_rec)
  RETURN rf.status;

  FUNCTION save_rtn_rf(
    i_rf_log_init_rec   IN  rf_log_init_record,
    i_action            IN VARCHAR2 := 'A', --A,U,R,C (possible values)
    i_manifest_no       IN returns.manifest_no%TYPE,
    i_orig_rtn_item_rec IN rtn_item_rec,
    i_new_rtn_item_rec  IN rtn_item_rec,
    o_returned_items_list       OUT rtn_validation_obj)
    RETURN rf.status ;


--   ====================================end specs==========================================================

END pl_rf_dci_pod;
/

create or replace PACKAGE BODY pl_rf_dci_pod AS

/************************************************************************
    -- check_weight_tolerance
    --
    -- Description:  Internal process to check weight tolerance during create puts.
    --      
    -- Return/output: gives Min and max weight tolerence, anf if temp passed is good or bad.
    --
    -- Modification log:
    --
    -- Date         Developer     Change
    -- ------------------------------------------------------------------
    -- 15-OCT-2020  vkal9662      Initial version.
    --
    *************************************************************************/

PROCEDURE check_weight_tolerance (i_prod_id   IN  returns.prod_id%TYPE,
                                  i_cpv       IN  returns.cust_pref_vendor%TYPE,
                                  i_weight    IN  returns.catchweight%TYPE,
                                  i_pct_tol   IN number,
                                  i_split_qty IN  NUMBER,
                                  o_bad_wt    OUT BOOLEAN,
                                  o_min_wt    OUT returns.catchweight%TYPE,
                                  o_max_wt    OUT returns.catchweight%TYPE) IS
   l_avg_wt pm.avg_wt%TYPE := 0;
   CURSOR c_get_pm_info IS
      SELECT avg_wt
      FROM pm
      WHERE prod_id = i_prod_id
      AND   cust_pref_vendor = i_cpv;
BEGIN
   o_bad_wt := FALSE;
   o_min_wt := 0;
   o_max_wt := 0;


   OPEN c_get_pm_info;
   FETCH c_get_pm_info INTO l_avg_wt;
   CLOSE c_get_pm_info;
   o_min_wt := l_avg_wt * i_split_qty *
               (1 - NVL(i_pct_tol, 0) / 100);
   o_max_wt := l_avg_wt * i_split_qty *
               (1 + NVL(i_pct_tol, 0) / 100);
   IF (NVL(i_weight, 0) < o_min_wt) OR (NVL(i_weight, 0) > o_max_wt) THEN
      o_bad_wt := TRUE;
   END IF;

END;


  /************************************************************************
    -- check_temp_tolerance 
    --
    -- Description:  Internal process to checktemprature tolerance during create puts.
    --      
    -- Return/output: gives Min and max temprature tolerence, anf if temp passed is good or bad.
    --
    -- Modification log:
    --
    -- Date         Developer     Change
    -- ------------------------------------------------------------------
    -- 15-OCT-2020  vkal9662      Initial version.
    --
    *************************************************************************/
PROCEDURE check_temp_tolerance (i_prod_id  IN  returns.prod_id%TYPE,
                                i_cpv      IN  returns.cust_pref_vendor%TYPE,
                                i_temp     IN  returns.temperature%TYPE,
                                o_bad_temp OUT BOOLEAN,
                                o_min_temp OUT pm.min_temp%TYPE,
                                o_max_temp OUT pm.max_temp%TYPE) IS
   CURSOR c_get_temp_limit IS
      SELECT NVL(min_temp, 0), NVL(max_temp, 0)
      FROM pm
      WHERE prod_id = i_prod_id
      AND   cust_pref_vendor = i_cpv;
BEGIN
   o_bad_temp := FALSE;
   o_min_temp := 0;
   o_max_temp := 0;
   OPEN c_get_temp_limit;
   FETCH c_get_temp_limit INTO o_min_temp, o_max_temp;
   CLOSE c_get_temp_limit;
   IF NVL(i_temp, 0) < o_min_temp OR NVL(i_temp, 0) > o_max_temp THEN
      o_bad_temp := TRUE;
   END IF;
END;

    /********************************************************************
    --
    -- get_upc_list_for_item()
    --
    -- Description: collects internal and external UPC for a given item
    --              from pm_upc table and stores them in a table type
    --              collection.
    --
    -- Parameters:     i_prod_id: prod_id
    --                 i_cpv    : cust pref vendor
    --
    -- Return/output:  the list of UPCs for the the given item.
    --
    -- Modification log:
    --
    -- Date         Developer     Change
    -- ------------------------------------------------------------------
    -- 24-SEP-2020  pkab6563      Initial version.
    *********************************************************************/
    FUNCTION get_upc_list_for_item (
        i_prod_id  IN  pm.prod_id%TYPE,
        i_cpv      IN  pm.cust_pref_vendor%TYPE
    ) return rtn_upc_table IS

        l_func_name   CONSTANT  swms_log.procedure_name%TYPE := 'get_upc_list_for_item';
        l_msg                   swms_log.msg_text%TYPE;
        upc_list                rtn_upc_table := rtn_upc_table();

    BEGIN
        SELECT rtn_upc_rec(upc_type, upc_code)
        BULK COLLECT INTO upc_list
        FROM (SELECT DISTINCT 'E' upc_type, external_upc upc_code
              FROM pm_upc
              WHERE prod_id = i_prod_id
                AND cust_pref_vendor = i_cpv
                AND external_upc IS NOT NULL
                AND external_upc NOT IN ('00000000000000', 'XXXXXXXXXXXXXX')
              UNION
              SELECT DISTINCT 'I' upc_type, internal_upc upc_code
              FROM pm_upc
              WHERE prod_id = i_prod_id
                AND cust_pref_vendor = i_cpv
                AND internal_upc IS NOT NULL
                AND internal_upc NOT IN ('00000000000000', 'XXXXXXXXXXXXXX')
             );

        return upc_list;

    EXCEPTION
        WHEN OTHERS THEN
            l_msg := 'ERROR during BULK COLLECT of UPC list for item ['
                  || i_prod_id
                  || '] cpv['
                  || i_cpv
                  || ']';
            pl_log.ins_msg('FATAL', l_func_name, l_msg, SQLCODE, SUBSTR(SQLERRM, 1, 500), APPLICATION_FUNC, PACKAGE_NAME);
            RAISE;

    END get_upc_list_for_item;

    /****************************************************************************
    --
    -- get_manifest_returns()
    --
    -- Description:      Collects the required info for the returns for the
    --                   given manifest.
    --
    -- Parameters:       i_manifest_no: manifest#
    --
    -- Return/output:    rtn_item_table type collection containing the returns
    --                   info for the given manifest. Some data such as the
    --                   UPC list for the item, order_seq list for item, and food safety info
    --                   are populated outside of this function.
    --
    -- Modification log:
    --
    -- Date         Developer     Change
    -- ------------------------------------------------------------------
    -- 24-SEP-2020  pkab6563      Initial version.
	-- 16-NOV-2020  ECLA1411	  OPCOF-3226 - POD Returns - Print Process For RF Host
	--                            Added TI, HI And Pallet_Type to l_item_list population
    --
    *****************************************************************************/
    FUNCTION get_manifest_returns (
        i_manifest_no           IN  manifests.manifest_no%TYPE,
        i_pct_tolerance         IN  NUMBER,
        i_max_food_safety_temp  IN  NUMBER
    ) return rtn_item_table IS

        l_func_name    CONSTANT  swms_log.procedure_name%TYPE := 'get_manifest_returns';
        l_msg                    swms_log.msg_text%TYPE;
        l_item_list              rtn_item_table := rtn_item_table();

    BEGIN
        SELECT rtn_item_rec(stop_no,
                            rec_type,
                            obligation_no,
                            prod_id,
                            cust_pref_vendor,
                            prod_desc,
                            return_reason_cd,
                            returned_qty,
                            returned_split_cd,
                            catchweight,
                            disposition,
                            returned_prod_id,
                            returned_prod_cpv,
                            returned_prod_desc,
                            erm_line_id,
                            shipped_qty,
                            shipped_split_cd,
                            cust_id,
                            temperature,
                            add_source,
                            status,
                            err_comment,
                            rtn_sent_ind,
                            pod_rtn_ind,
                            lock_chg,
                            order_seq_list,
                            spc,
                            split_trk,
                            temp_trk,
                            catch_wt_trk,
                            food_safety_trk,
                            food_safety_temp,
                            min_temp,
                            max_temp,
                            min_weight,
                            max_weight,
                            max_food_safety_temp,
                            -- ECLA1411 - OPCOF-3226 - POD Returns - Print Process For RF Host
							null,	-- rtn_label_printed
							null,	-- pallet_id
							null,	-- dest_loc
							ti,
							hi,
							pallet_type,
							-- END ECLA1411 - OPCOF-3226 - POD Returns - Print Process For RF Host
                            rtn_upc_table())
        BULK COLLECT INTO l_item_list
        FROM (SELECT nvl(rtn.stop_no, NULL_VAL_INDICATOR)                            stop_no,
                     nvl(rtn.rec_type, ' ')                                          rec_type,
                     nvl(rtn.obligation_no, ' ')                                     obligation_no,
                     nvl(rtn.prod_id, ' ')                                           prod_id,
                     nvl(rtn.cust_pref_vendor, ' ')                                  cust_pref_vendor,
                     nvl(pm1.descrip, ' ')                                           prod_desc,
                     nvl(rtn.return_reason_cd, ' ')                                  return_reason_cd,
                     nvl(rtn.returned_qty, 0)                                        returned_qty,
                     nvl(rtn.returned_split_cd, ' ')                                 returned_split_cd,
                     nvl(rtn.catchweight, NULL_VAL_INDICATOR)                        catchweight,
                     nvl(rtn.disposition, ' ')                                       disposition,
                     nvl(rtn.returned_prod_id, ' ')                                  returned_prod_id,
                     nvl(rtn.cust_pref_vendor, ' ')                                  returned_prod_cpv,
                     nvl(pm2.descrip, ' ')                                           returned_prod_desc,
                     nvl(rtn.erm_line_id, 0)                                         erm_line_id,
                     nvl(rtn.shipped_qty, 0)                                         shipped_qty,
                     nvl(rtn.shipped_split_cd, ' ')                                  shipped_split_cd,
                     nvl(rtn.cust_id, ' ')                                           cust_id,
                     nvl(rtn.temperature, NULL_VAL_INDICATOR)                        temperature,
                     nvl(rtn.add_source, ' ')                                        add_source,
                     nvl(rtn.status, ' ')                                            status,
                     nvl(rtn.err_comment, ' ')                                       err_comment,
                     nvl(rtn.rtn_sent_ind, ' ')                                      rtn_sent_ind,
                     nvl(rtn.pod_rtn_ind, ' ')                                       pod_rtn_ind,
                     nvl(rtn.lock_chg, ' ')                                          lock_chg,
                     rtn_order_seq_table()                                           order_seq_list,
                     nvl(pm2.spc, 0)                                                 spc,
                     nvl(pm2.split_trk, 'N')                                         split_trk,
                     nvl(pm2.temp_trk, 'N')                                          temp_trk,
                     nvl(pm2.catch_wt_trk, 'N')                                      catch_wt_trk,
                     'N'                                                             food_safety_trk,
                     NULL_VAL_INDICATOR                                              food_safety_temp,
                     nvl(pm2.min_temp, NULL_VAL_INDICATOR)                           min_temp,
                     nvl(pm2.max_temp, NULL_VAL_INDICATOR)                           max_temp,
                     nvl((1 - nvl(i_pct_tolerance, 0)/100) * nvl(pm2.avg_wt, NULL_VAL_INDICATOR), NULL_VAL_INDICATOR)  min_weight,
                     nvl((1 + nvl(i_pct_tolerance, 0)/100) * nvl(pm2.avg_wt, NULL_VAL_INDICATOR), NULL_VAL_INDICATOR)  max_weight,
                     nvl(i_max_food_safety_temp, NULL_VAL_INDICATOR)                 max_food_safety_temp,
                     -- ECLA1411 - OPCOF-3226 - POD Returns - Print Process For RF Host
					 nvl(pm2.ti, 0)													 ti,
					 nvl(pm2.hi, 0)													 hi,
					 nvl(pm2.pallet_type, ' ')										 pallet_type
					 -- END ECLA1411 - OPCOF-3226 - POD Returns - Print Process For RF Host
              FROM returns rtn, pm pm1, pm pm2
              WHERE rtn.manifest_no          = i_manifest_no
                AND pm1.prod_id (+)          = rtn.prod_id
                AND pm1.cust_pref_vendor (+) = rtn.cust_pref_vendor
                AND pm2.prod_id (+)          = nvl(rtn.returned_prod_id, rtn.prod_id)
                AND pm2.cust_pref_vendor (+) = rtn.cust_pref_vendor
                order by decode(status, 'CLS', 'z'||status,'CMP', 'x'||status,'ERR', 'a'||status, 'VAL', 'b'||status, 'SLT', 'c'||status, 'COL', 'd'||status, 'PUT', 'e'||status, status)
             );

        return l_item_list;

    EXCEPTION
        WHEN OTHERS THEN
            l_msg := 'ERROR during BULK COLLECT of returns for manifest# ['
                  || i_manifest_no
                  || ']';
            pl_log.ins_msg('FATAL', l_func_name, l_msg, SQLCODE, SUBSTR(SQLERRM, 1, 500), APPLICATION_FUNC, PACKAGE_NAME);
            RAISE;

    END get_manifest_returns;

    /************************************************************************
    --
    -- validate_manifest_returns()
    --
    -- Description:        This function is called from the RF to validate
    --                     the returns for a given manifest and collect
    --                     info for the related returns. The collected
    --                     info is sent to the RF for the user to review
    --                     and process the returns.
    --
    --                     Calls validate_mf_rtn() for the business logic.
    --
    -- Parameters:         i_rf_log_init_rec: RF-related data. Not
    --                     related to business logic.
    --
    --                     i_manifest_sos_label: manifest# or SOS pick label barcode
    --
    --                     i_dci_ready_override:
    --                         RF client will send a Y for this parameter
    --                         if "dci ready" is N and needs to be changed
    --                         to Y.
    --
    --                     o_returned_items_list:
    --                         object containing collected data to be
    --                         sent to the RF. This data includes the list
    --                         of returned items for the given manifest.
    --
    --
    -- Return/output:      see above output parameter.
    --
    -- Modification log:
    --
    -- Date         Developer     Change
    -- ------------------------------------------------------------------
    -- 24-SEP-2020  pkab6563      Initial version.
    -- 27-OCT-2020  ecla1411      Add additional return parameter for POD Invoice Print
    --                            OPCOF-3226 - POD-Label Print
    -- 11-NOV-2021  sban3548      OPCOF-3777 - Accept SOS pick label barcode scan from RF Returns
    --
    *************************************************************************/
    FUNCTION validate_manifest_returns (
        i_rf_log_init_rec       IN  rf_log_init_record,
        i_manifest_sos_label    IN  NUMBER,
        i_dci_ready_override    IN  VARCHAR2,
        o_returned_items_list   OUT rtn_validation_obj,
        o_printer_name          OUT VARCHAR2
    ) return rf.status IS

        l_func_name  CONSTANT  swms_log.procedure_name%TYPE := 'validate_manifest_returns';
        l_status               rf.status := rf.status_normal;
        l_msg                  swms_log.msg_text%TYPE;
        l_xdock_count PLS_INTEGER;
		l_manifest_no		   manifests.manifest_no%TYPE;

    BEGIN

         -- Call rf.initialize(). cannot procede if return status is not successful.
        l_status := rf.initialize(i_rf_log_init_rec);

		-- BEGIN: OPCOF-3777- SOS pick label scan
		-- Check if input parameter i_manifest_sos_label is a manifest or if SOS pick label scanned
		-- Manifest# length is 7 or less
		IF LENGTH(i_manifest_sos_label) < 8 THEN
			l_manifest_no := i_manifest_sos_label;

		-- If SOS label barcode scanned, then get Manifest#
		ELSIF LENGTH(i_manifest_sos_label) < 12 THEN
			BEGIN
				SELECT DISTINCT manifest_no
				INTO l_manifest_no
				FROM returns_barcode
				WHERE SUBSTR(barcode,1,8) = SUBSTR(i_manifest_sos_label,1,8);

				l_msg := 'Manifest# ['
						  || l_manifest_no
						  || '] found for given SOS pick label barcode# ['
						  || i_manifest_sos_label
						  || ']';
				pl_log.ins_msg('WARN', l_func_name, l_msg, null, null, APPLICATION_FUNC, PACKAGE_NAME);

			EXCEPTION
            WHEN NO_DATA_FOUND THEN
                l_status := rf.status_man_not_found;
                l_msg := 'MANIFEST NOT FOUND; For SOS pick label barcode# ['
                      || i_manifest_sos_label
                      || ']';
                pl_log.ins_msg('WARN', l_func_name, l_msg, SQLCODE, SUBSTR(SQLERRM, 1, 500), APPLICATION_FUNC, PACKAGE_NAME);
            WHEN OTHERS THEN
                l_status := rf.status_data_error;
                l_msg := 'ERROR while getting Manifest# from RETURNS_BARCODE table using SOS pick label barcode# ['
                      || i_manifest_sos_label
                      || ']';
                pl_log.ins_msg('FATAL', l_func_name, l_msg, SQLCODE, SUBSTR(SQLERRM, 1, 500), APPLICATION_FUNC, PACKAGE_NAME);
	            rf.logexception();
				RAISE;
			END;
		ELSE
                l_status := rf.status_inv_manifest;
                l_msg := 'INVALID manifest# or SOS pick label barcode# ['
                      || i_manifest_sos_label
                      || ']';
                pl_log.ins_msg('WARN', l_func_name, l_msg, null, null, APPLICATION_FUNC, PACKAGE_NAME);
		END IF;

        IF l_status != rf.status_normal THEN
			rf.complete(l_status);
			return l_status;
		END IF;
		-- END: OPCOF-3777- SOS pick label scan

       -- Initialize the out parameters
        o_returned_items_list := rtn_validation_obj(l_manifest_no, 'N', ' ', rtn_item_table());
        o_printer_name := ' ';

        -- Log the input received from the RF client
        l_msg := 'Starting '
              || l_func_name
              || '. Received manifest# from RF client: ['
              || l_manifest_no
              || '] i_dci_ready_override is ['
              || i_dci_ready_override
              || ']';
        pl_log.ins_msg('INFO', l_func_name, l_msg, null, null, APPLICATION_FUNC, PACKAGE_NAME);

        -- OPCOF-3389 - START: reject all returns for XDOCK orders
        SELECT COUNT(0)
        INTO l_xdock_count
        FROM manifest_dtls
        WHERE manifest_no = l_manifest_no
        AND xdock_ind IS NOT NULL;

        IF l_xdock_count > 0 THEN
          pl_log.ins_msg('WARN', l_func_name, 'Order is a cross dock order. Returns not allowed.', sqlcode, sqlerrm, APPLICATION_FUNC, PACKAGE_NAME);
          RETURN RF.STATUS_INV_MANIFEST;
        END IF;

        -- OPCOF-3389 - END: reject all returns for XDOCK orders

            -- OPCOF-3226 - POD-Invoice Print
            BEGIN
            SELECT queue
             INTO o_printer_name
             FROM print_report_queues prq
            WHERE UPPER(USER_ID) = REPLACE(USER,'OPS$',NULL) AND EXISTS (SELECT 1
                                                                 FROM print_reports pr
                                                                WHERE pr.report = 'rp1ri' AND
                                                                      pr.queue_type = prq.queue_type);
            EXCEPTION
                        WHEN NO_DATA_FOUND THEN
                            l_status := rf.STATUS_NO_PRINTER_DEFINED;
                        WHEN OTHERS THEN
                            l_status := rf.status_data_error;
                            l_msg := 'Get Printer For User FAILED for manifest# ['
                                  || l_manifest_no
                                  || '] stop# [';
                            pl_log.ins_msg('FATAL', l_func_name, l_msg, SQLCODE, SUBSTR(SQLERRM, 1, 500), APPLICATION_FUNC, PACKAGE_NAME);
            END; -- OPCOF-3226 - POD-Invoice Print

        -- perform the business logic by calling the business logic function
        IF l_status = rf.status_normal THEN
            l_status := validate_mf_rtn(l_manifest_no, i_dci_ready_override, o_returned_items_list);
        END IF;

        l_msg := 'l_status at the end of validate_manifest_returns() is ['
              || l_status
              || ']';
        pl_log.ins_msg('INFO', l_func_name, l_msg, null, null, APPLICATION_FUNC, PACKAGE_NAME);

        rf.complete(l_status);
        return l_status;

    EXCEPTION
        WHEN OTHERS THEN
            l_msg := 'ERROR in validate_manifest_returns() for manifest# ['
                  || l_manifest_no
                  || ']';
            pl_log.ins_msg('FATAL', l_func_name, l_msg, SQLCODE, SUBSTR(SQLERRM, 1, 500), APPLICATION_FUNC, PACKAGE_NAME);
            rf.logexception();
            RAISE;

    END validate_manifest_returns;

    /************************************************************************
    --
    -- validate_sts()
    --
    -- Description:      Copied from form rtnsdtl.fmb and adapted to the
    --                   package. Updates returns status based on certain
    --                   conditions.
    --
    -- Parameters:       i_manifest_no: manifest#
    --
    --
    -- Return/output:    Status of the DMLs done or tried.
    --
    -- Modification log:
    --
    -- Date         Developer     Change
    -- ------------------------------------------------------------------
    -- 24-SEP-2020  pkab6563      Copied from form rtnsdtl.fmb and made
    --                            minor modifications.
    -- 15-DEC-2020  pkab6563      Made changes to allow data collection to
    --                            occur before create puts. In other words,
    --                            added status COL logic for the returns that
    --                            need temp and weight collection.
    --
    *************************************************************************/
    FUNCTION validate_sts (
        i_manifest_no IN manifests.manifest_no%TYPE
    ) return rf.status IS

        l_func_name  CONSTANT       swms_log.procedure_name%TYPE := 'validate_sts';
        rtn_exists                  VARCHAR2(1);
        v_erm_id                    VARCHAR2(12);
        v_prod_id                   VARCHAR2(9);
        v_cpv                       VARCHAR2(10);
        v_qty                       NUMBER := 0;
        v_saleable                  VARCHAR2(1);
        v_mispick                   VARCHAR2(1);
        valid_erd                   NUMBER(1); 		
        l_status                    VARCHAR2(10);     
        l_msg                       swms_log.msg_text%TYPE;
        l_ret_code                  rf.status := rf.status_normal;
        l_food_safety_dci           VARCHAR2(1);  -- syspar
        l_manifest_dtl_status       manifest_dtls.manifest_dtl_status%TYPE := '***';
        l_cnt_missing_food_safety   PLS_INTEGER := 0;
   
        CURSOR  rtn_curs(mans_no NUMBER) IS
        select r.MANIFEST_NO,
               r.REC_TYPE,
               r.OBLIGATION_NO,
               r.PROD_ID,
               r.cust_id,
               r.CUST_PREF_VENDOR,
               r.RETURNED_PROD_ID,
               r.RETURNED_QTY,
               r.RETURNED_SPLIT_CD,
               r.CATCHWEIGHT,
               r.ERM_LINE_ID,
               r.RETURN_REASON_CD,
               rs.REASON_GROUP,
               r.stop_no,
               r.shipped_split_cd,
               r.temperature,
               p.catch_wt_trk,
               DECODE(rs.reason_group,
                      'DMG', 'N',
                      'STM', 'N',
                      p.temp_trk) temp_trk,
               pod_rtn_ind,
               rtn_sent_ind,
               r.status
        from   REASON_CDS rs, RETURNS r, pm p
        where  rs.REASON_CD  = r.RETURN_REASON_CD
          and  r.MANIFEST_NO = mans_no
          and  rs.REASON_GROUP IN
             ('NOR','DMG','OVR','MPR','OVI','WIN', 'STM', 'MPK')
          and  nvl(r.RETURNED_QTY,0) IS NOT NULL
          AND  p.prod_id = DECODE(rs.reason_group, 'MPR', r.returned_prod_id,
                                  r.prod_id)
          AND  p.cust_pref_vendor = r.cust_pref_vendor;
         

    BEGIN    -- function validate_sts

        -- commented out below call from forms
        -- display_tm_queue_process_error(i_manifest_no);

        -- commented out below call from forms 
        --display_tm_queue_process_error(i_manifest_no);
   
        -- Get FOOD_SAFETY_DCI syspar
        l_food_safety_dci := pl_common.f_get_syspar('FOOD_SAFETY_DCI', 'N');

        FOR rtn_rec IN rtn_curs(i_manifest_no) LOOP
   	    --knha8378 add status check for CMP
            IF nvl(rtn_rec.status, 'X') != 'CMP' THEN
                If rtn_rec.reason_group = 'STM' then
                    l_status := 'CMP';
                elsif rtn_rec.pod_rtn_ind = 'D' and rtn_rec.rtn_sent_ind  = 'Y' then  
                    l_status := 'CMP';
                elsif rtn_rec.rec_type = 'P' and nvl(rtn_rec.returned_qty, 0) = 0 then 
                    l_status := 'CMP';   
                else
                    -- pkab6563: check for manifest dtl status before updating 
                    BEGIN
                        SELECT manifest_dtl_status
                        INTO   l_manifest_dtl_status
                        FROM   manifest_dtls
                        WHERE  manifest_no      = rtn_rec.manifest_no
                          AND  (stop_no         = rtn_rec.stop_no
                               OR stop_no IS NULL)              
                          AND  prod_id          = rtn_rec.prod_id
                          AND  cust_pref_vendor = rtn_rec.cust_pref_vendor
                          AND  obligation_no    = rtn_rec.obligation_no
                          AND  shipped_split_cd = rtn_rec.shipped_split_cd;

                    EXCEPTION
                        WHEN OTHERS THEN
                            l_status := 'PUT';
                            
                    END;    -- checking for manifest dtl status
                   
                    IF l_manifest_dtl_status = 'RTN' THEN
                        IF rtn_rec.status = 'VAL' THEN
                            l_status := 'PUT';
                        ELSE
                            l_status := rtn_rec.status;  
                        END IF;
                    ELSE
                        l_status := 'PUT';
                    END IF;
                End If;	
            ELSE
                l_status := rtn_rec.status;  -- set to CMP or else the update is null
            END IF;

            -- Insert food safety row
            IF nvl(l_food_safety_dci, 'N') = 'Y' AND nvl(rtn_rec.returned_qty, 0) != 0 
  	    and nvl(rtn_rec.pod_rtn_ind, 'A') != 'D' AND rtn_rec.reason_group in ('NOR', 'MPR', 'WIN', 'OVR', 'OVI') 
  	    and nvl(rtn_rec.status, 'VAL') != 'ERR' THEN 

                pl_dci.dci_food_safety('I',
                                       rtn_rec.manifest_no,
                                       to_char(rtn_rec.stop_no),
                                       nvl(rtn_rec.returned_prod_id, rtn_rec.prod_id),
                                       rtn_rec.obligation_no,
                                       rtn_rec.cust_id,
                                       rtn_rec.temperature,
                                       'RF',
                                       sysdate,
                                       rtn_rec.return_reason_cd,
                                       rtn_rec.reason_group,
                                       l_msg);  
			         
                IF l_msg is not null THEN
                    pl_log.ins_msg('WARN', l_func_name, l_msg, null, null, APPLICATION_FUNC, PACKAGE_NAME);
                END IF;	
        	                            
            END IF;  -- end insert food safety row

            -- check for data collection and change status to COL if applicable
            IF l_status = 'PUT' THEN
                -- food safety
                SELECT COUNT(*) 
                  INTO l_cnt_missing_food_safety
                FROM   food_safety_outbound
                WHERE  manifest_no = rtn_rec.manifest_no
                  AND  prod_id = nvl(rtn_rec.returned_prod_id, rtn_rec.prod_id)
                  AND  obligation_no = rtn_rec.obligation_no
                  AND  stop_no = rtn_rec.stop_no
                  AND  temp_collected IS NULL;

                IF nvl(rtn_rec.temp_trk, 'N') = 'Y' AND rtn_rec.temperature IS NULL 
                AND rtn_rec.reason_group != 'DMG' THEN
                    l_status := 'COL';
                ELSIF nvl(rtn_rec.catch_wt_trk, 'N') = 'Y' AND rtn_rec.catchweight IS NULL THEN
                    l_status := 'COL';
                ELSIF l_cnt_missing_food_safety > 0 AND rtn_rec.reason_group != 'DMG' THEN
                    l_status := 'COL';
                END IF;
            END IF;   -- check for data collection

            BEGIN  -- update returns record
                UPDATE returns
                SET returned_prod_id = DECODE(rtn_rec.reason_group,
                                       'DMG', rtn_rec.prod_id,
                                       'NOR', rtn_rec.prod_id,
                                       'WIN', rtn_rec.prod_id, 
                                       'STM', rtn_rec.prod_id,
                                       'OVR', rtn_rec.prod_id,
                                       'OVI', rtn_rec.prod_id,
                                       rtn_rec.returned_prod_id),
	            upd_source = 'RF',
	            status = l_status,
	            err_comment = NULL
                WHERE manifest_no = i_manifest_no
                  AND prod_id = rtn_rec.prod_id
                  AND cust_pref_vendor = rtn_rec.cust_pref_vendor
                  AND return_reason_cd = rtn_rec.return_reason_cd
                  AND (obligation_no = rtn_rec.obligation_no
                       OR obligation_no IS NULL)
                  AND erm_line_id = rtn_rec.erm_line_id;
            EXCEPTION
                WHEN OTHERS THEN
                    ROLLBACK;
                    l_msg := 'ERROR: Update of manifest returns FAILED for manifest#[' 
                          || i_manifest_no
                          || '], stop#['
                          || rtn_rec.stop_no
                          || '], obligation#['
                          || rtn_rec.obligation_no
                          || '], prod_id['
                          || rtn_rec.prod_id
                          || '], erm_line_id['
                          || rtn_rec.erm_line_id
                          || ']';
                 
                    pl_log.ins_msg('FATAL', l_func_name, l_msg, SQLCODE, SUBSTR(SQLERRM, 1, 500), APPLICATION_FUNC, PACKAGE_NAME);
                    l_ret_code := rf.status_update_fail;
                    exit;  -- exit the loop
	     
            END; -- update returns record

        END LOOP;  -- rtn_curs

        IF l_ret_code = rf.status_normal THEN
            BEGIN  -- delete some returns
                DELETE 
                FROM  returns r
                WHERE r.manifest_no = i_manifest_no
                  AND r.rec_type = 'P'
                  AND r.returned_qty IS NULL
                  AND EXISTS (SELECT NULL
                              FROM returns r1
                              WHERE r1.manifest_no = r.manifest_no
                                AND r1.rec_type = r.rec_type
                                AND r1.obligation_no = r.obligation_no
                                AND r1.prod_id = r.prod_id
                                AND r1.cust_pref_vendor = r.cust_pref_vendor
                                AND r1.returned_qty IS NOT NULL);
            EXCEPTION
                WHEN NO_DATA_FOUND THEN
                    NULL;
                WHEN OTHERS THEN
                    l_msg := 'Warning: Deletion of pickups from returns table FAILED for manifest#[' 
                          || i_manifest_no
                          || ']';
                    pl_log.ins_msg('WARN', l_func_name, l_msg, SQLCODE, SUBSTR(SQLERRM, 1, 500), APPLICATION_FUNC, PACKAGE_NAME);
            END; -- delete some returns
        END IF;

        IF l_ret_code = rf.status_normal THEN  
            BEGIN  -- update of manifest_dtls
                update MANIFEST_DTLS m
                set    MANIFEST_DTL_STATUS = 'RTN'
                where  MANIFEST_NO = i_manifest_no
                  and  exists
                         (select NULL
                          from   RETURNS r
                          where  r.MANIFEST_NO      = m.MANIFEST_NO
                            and  r.STOP_NO          = m.STOP_NO
                            and  r.OBLIGATION_NO    = m.OBLIGATION_NO
                            and  r.REC_TYPE         = m.REC_TYPE
                            and  r.PROD_ID          = m.PROD_ID
                            and  r.CUST_PREF_VENDOR = m.CUST_PREF_VENDOR
                            and (r.SHIPPED_SPLIT_CD IS NULL
                                 or  r.SHIPPED_SPLIT_CD = m.SHIPPED_SPLIT_CD)
                            and  r.RETURNED_QTY IS NOT NULL )
                  and  m.MANIFEST_DTL_STATUS not in ('RTI', 'RTN'); -- pkab6563: don't update if it's already RTN/RTI

            EXCEPTION
                WHEN NO_DATA_FOUND THEN
                    NULL;
                WHEN OTHERS THEN
                    ROLLBACK;
                    l_msg := 'ERROR: Update of MANIFEST_DTLS FAILED for manifest#[' 
                          || i_manifest_no
                          || ']';
                    pl_log.ins_msg('FATAL', l_func_name, l_msg, SQLCODE, SUBSTR(SQLERRM, 1, 500), APPLICATION_FUNC, PACKAGE_NAME);
                    l_ret_code := rf.status_update_fail;
	    END;  -- update of manifest_dtls
        END IF;   -- l_ret_code = rf.status_normal

        IF l_ret_code = rf.status_normal THEN
            COMMIT;
        END IF;

        return l_ret_code;

    EXCEPTION   
        WHEN OTHERS THEN
            ROLLBACK;
	    l_msg := 'ERROR: '
                  || l_func_name 
                  || ' FAILED for manifest#[' 
                  || i_manifest_no
                  || ']';
            pl_log.ins_msg('FATAL', l_func_name, l_msg, SQLCODE, SUBSTR(SQLERRM, 1, 500), APPLICATION_FUNC, PACKAGE_NAME);
            return rf.status_update_fail;

    END validate_sts;

    /************************************************************************
    --
    -- validate_mf_rtn()
    --
    -- Description:        Contains the business logic for
    --                     validate_manifest_returns(). Validates the
    --                     returns for the given manifest and collects info
    --                     for the related returns to be sent to the RF for
    --                     the user to review and process the returns.
    --
    -- Parameters:         i_manifest_no: manifest#
    --
    --                     i_dci_ready_override: will be Y if "dci ready"
    --                         is N and needs to be changed to Y.
    --
    -- Return/output:      Object containing data to be sent
    --                     to the RF.
    --
    -- Modification log:
    --
    -- Date         Developer     Change
    -- ------------------------------------------------------------------
    -- 24-SEP-2020  pkab6563      Initial version.
    -- 09-NOV-2020  ECLA1411      OPCOF-3226 - POD Returns - Print Process For RF Host
    --                            Added default values for rtn_validation_obj
    --
    *************************************************************************/
    FUNCTION validate_mf_rtn (
        i_manifest_no           IN  manifests.manifest_no%TYPE,
        i_dci_ready_override    IN  VARCHAR2,
        o_returned_items_list   OUT rtn_validation_obj
    ) return rf.status IS

        l_func_name      CONSTANT  swms_log.procedure_name%TYPE := 'validate_mf_rtn';
        l_status                   rf.status := rf.status_normal;
        l_msg                      swms_log.msg_text%TYPE;
        l_mf_status                manifests.manifest_status%TYPE;
        l_dci_ready                manifests.sts_completed_ind%TYPE;
        l_err_cnt                  NUMBER;
        l_rtn_cnt                  NUMBER;
        l_route_no                 route.route_no%TYPE;
        l_item_list                rtn_item_table := rtn_item_table();
        l_dci_ready_override       VARCHAR2(1);
        l_food_safety_trk          VARCHAR2(1);
        l_food_safety_temp         NUMBER;
        l_food_safety_dci          VARCHAR2(1);  -- syspar
        l_pct_tolerance            NUMBER;       -- syspar
        l_max_food_safety_temp     NUMBER;       -- syspar

    BEGIN

        -- Initialize out parameter
        o_returned_items_list := rtn_validation_obj(i_manifest_no, 'N', ' ', rtn_item_table());

        l_dci_ready_override := nvl(i_dci_ready_override, 'N');

        BEGIN      -- get manifest info

            -- get manifest status and ensure it's not CLS

            SELECT manifest_status, nvl(sts_completed_ind, 'N'), route_no
            INTO   l_mf_status, l_dci_ready, l_route_no
            FROM   manifests
            WHERE  manifest_no = i_manifest_no;

            IF l_mf_status = 'CLS' THEN
                l_status := rf.status_manifest_was_closed;
                o_returned_items_list.dci_ready := l_dci_ready;
                l_msg := 'INVALID STATUS: manifest already CLOSED; manifest# ['
                      || i_manifest_no
                      || ']';
                pl_log.ins_msg('WARN', l_func_name, l_msg, null, null, APPLICATION_FUNC, PACKAGE_NAME);
            END IF;

        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                l_status := rf.status_man_not_found;
                l_msg := 'MANIFEST NOT FOUND; manifest# ['
                      || i_manifest_no
                      || ']';
                pl_log.ins_msg('WARN', l_func_name, l_msg, SQLCODE, SUBSTR(SQLERRM, 1, 500), APPLICATION_FUNC, PACKAGE_NAME);
            WHEN OTHERS THEN
                l_status := rf.status_data_error;
                l_msg := 'ERROR during query of manifests table for manifest# ['
                      || i_manifest_no
                      || ']';
                pl_log.ins_msg('FATAL', l_func_name, l_msg, SQLCODE, SUBSTR(SQLERRM, 1, 500), APPLICATION_FUNC, PACKAGE_NAME);
        END;       -- get manifest info

        IF l_status = rf.status_normal AND l_dci_ready != 'Y'
        AND (l_dci_ready_override = 'Y' OR l_dci_ready_override = 'y') THEN
            BEGIN    -- update dci ready
                l_dci_ready := 'Y';
                l_msg := 'Changing sts_completed_ind to Y for manifest# ['
                      || i_manifest_no
                      || ']';
                pl_log.ins_msg('WARN', l_func_name, l_msg, null, null, APPLICATION_FUNC, PACKAGE_NAME);
                UPDATE manifests
                SET    sts_completed_ind = 'Y'
                WHERE  manifest_no = i_manifest_no;
                COMMIT;

            EXCEPTION
                WHEN OTHERS THEN
                    l_msg := 'ERROR: attempt to update sts_completed_ind to Y FAILED for manifest# ['
                          || i_manifest_no
                          || ']';
                    pl_log.ins_msg('WARN', l_func_name, l_msg, SQLCODE, SUBSTR(SQLERRM, 1, 500), APPLICATION_FUNC, PACKAGE_NAME);

            END;     -- update dci ready
        END IF;

        IF l_status = rf.status_normal AND l_dci_ready != 'Y' THEN
            l_status := rf.status_manifest_not_dci_ready;
            l_msg := 'NOT DCI READY. Manifest# ['
                  || i_manifest_no
                  || ']'
                  || ' l_dci_ready is ['
                  || l_dci_ready
                  || ']';
            pl_log.ins_msg('WARN', l_func_name, l_msg, null, null, APPLICATION_FUNC, PACKAGE_NAME);
        END IF;

        -- if no errors so far and dci_ready is Y (returns are ready to be processed for the route),
        -- call validate_tripmaster.
        IF l_status = rf.status_normal THEN
            BEGIN     -- validate_tripmaster
                pl_dci.validate_tripmaster(i_manifest_no, l_msg, l_err_cnt);
                IF l_err_cnt = VAL_TRIPMASTER_FAIL THEN
                    l_status := rf.status_data_error;
                    l_msg := l_msg || ' ***** PL_DCI.VALIDATE_TRIPMASTER FAILED for manifest# ['
                          || i_manifest_no
                          || ']';
                    pl_log.ins_msg('FATAL', l_func_name, l_msg, SQLCODE, SUBSTR(SQLERRM, 1, 500), APPLICATION_FUNC, PACKAGE_NAME);
                    ROLLBACK;
                END IF;

            EXCEPTION
                WHEN OTHERS THEN
                    l_status := rf.status_data_error;
                    l_msg := l_msg || ' ***** PL_DCI.VALIDATE_TRIPMASTER FAILED for manifest# ['
                          || i_manifest_no
                          || ']';
                    pl_log.ins_msg('FATAL', l_func_name, l_msg, SQLCODE, SUBSTR(SQLERRM, 1, 500), APPLICATION_FUNC, PACKAGE_NAME);
                    ROLLBACK;
            END;      -- validate_tripmaster
        END IF;

        IF l_status = rf.status_normal THEN
            SELECT COUNT(*)
            INTO   l_rtn_cnt
            FROM   returns
            WHERE  manifest_no = i_manifest_no;
        END IF;

        -- we call validate_sts() only if the manifest has no errors
        -- and there are returns to process and dci_ready is Y.
        IF l_status = rf.status_normal AND l_err_cnt = 0
        AND l_rtn_cnt > 0 THEN
            l_status := validate_sts(i_manifest_no);
        END IF;

        -- get percent tolerance and max food safety temp syspars
        IF l_status = rf.status_normal THEN
            BEGIN
                SELECT NVL(MAX(DECODE(config_flag_name, 'FOOD_SAFETY_TEMP_LIMIT', config_flag_val, NULL_VAL_INDICATOR)), NULL_VAL_INDICATOR),
                       NVL(MAX(DECODE(config_flag_name, 'PCT_TOLERANCE', config_flag_val, NULL_VAL_INDICATOR)), NULL_VAL_INDICATOR)
                  INTO l_max_food_safety_temp,
                       l_pct_tolerance
                FROM   sys_config;

            IF (l_max_food_safety_temp = NULL_VAL_INDICATOR) OR (l_pct_tolerance = NULL_VAL_INDICATOR) THEN
                l_status := rf.status_data_error;
                l_msg := 'ERROR: CHECK syspars FOOD_SAFETY_TEMP_LIMIT and PCT_TOLERANCE';
                pl_log.ins_msg('WARN', l_func_name, l_msg, null, null, APPLICATION_FUNC, PACKAGE_NAME);
            END IF;

            EXCEPTION
                WHEN OTHERS THEN
                    l_status := rf.status_data_error;
                    l_msg := 'Unexpected ERROR while trying to get FOOD_SAFETY_TEMP_LIMIT and PCT_TOLERANCE syspars';
                    pl_log.ins_msg('FATAL', l_func_name, l_msg, SQLCODE, SUBSTR(SQLERRM, 1, 500), APPLICATION_FUNC, PACKAGE_NAME);

            END;
        END IF; -- get syspars

        -- collect all the return data to be sent to the RF.
        -- returns will be sent regardless of their status.
        -- no returns will be sent if l_status is not normal.

        IF l_status = rf.status_normal THEN
            l_item_list       := get_manifest_returns(i_manifest_no, l_pct_tolerance, l_max_food_safety_temp);
            l_food_safety_dci := pl_common.f_get_syspar('FOOD_SAFETY_DCI', 'N');

            -- iterate through the list of returns and set missing data.
            FOR item IN NVL(l_item_list.first, 0)..NVL(l_item_list.last, -1) LOOP
                l_item_list(item).upc_list  := get_upc_list_for_item(l_item_list(item).prod_id, l_item_list(item).cust_pref_vendor);
                l_item_list(item).order_seq_list := get_order_seq_no(l_route_no,
                                                                l_item_list(item).stop_no,
                                                                l_item_list(item).obligation_no,
                                                                l_item_list(item).prod_id,
                                                                l_item_list(item).cust_pref_vendor,
                                                                l_item_list(item).returned_split_cd);

                -- ECLA1411 - BEGIN CHANGES
                -- OPCOF-3226 - POD Returns - Print Process For RF Host
                -- last line in the below query (erm_line_id check)is to handle same item in the manifest multiple times - Vkal9662
				BEGIN
					SELECT NVL(RTN_LABEL_PRINTED, 'N'),
						   NVL(DEST_LOC, ' '),
						   NVL(PALLET_ID, ' ')
					  INTO l_item_list(item).rtn_label_printed,
						   l_item_list(item).dest_loc,
						   l_item_list(item).pallet_id
					  FROM PUTAWAYLST
					 WHERE SUBSTR(rec_id, 2) = TO_CHAR(i_manifest_no) AND -- R44-POD Returns - Changed i_manifest_no to TO_CHAR(i_manifest_no) - In validate_mf_rtn - Line 1159
						   SUBSTR(rec_id, 1, 1) IN ('D', 'S') AND
						   prod_id = nvl(l_item_list(item).returned_prod_id,l_item_list(item).prod_id) AND
						  -- NVL(RTN_LABEL_PRINTED, 'N') = 'N' AND      
               ERM_LINE_ID = l_item_list(item).erm_line_id;
					
					EXCEPTION
						WHEN NO_DATA_FOUND THEN
							l_status := rf.STATUS_NORMAL;
							l_item_list(item).pallet_id := NVL(l_item_list(item).pallet_id, ' ');
							l_item_list(item).dest_loc := NVL(l_item_list(item).dest_loc, ' ');
							l_item_list(item).rtn_label_printed := NVL(l_item_list(item).rtn_label_printed, 'N');
							l_msg := 'No Data Found while looking for PutAwayLst Values - Manifest No: ' || i_manifest_no ||
									 ' Prod ID: ' || NVL(l_item_list(item).prod_id, 'NULL') ;
							pl_log.ins_msg('WARN', l_func_name, l_msg, SQLCODE, SUBSTR(SQLERRM, 1, 500), APPLICATION_FUNC, PACKAGE_NAME);
						WHEN OTHERS THEN
							l_status := rf.STATUS_DATA_ERROR;
							l_item_list(item).pallet_id := NVL(l_item_list(item).pallet_id, ' ');
							l_item_list(item).dest_loc := NVL(l_item_list(item).dest_loc, ' ');
							l_item_list(item).rtn_label_printed := NVL(l_item_list(item).rtn_label_printed, 'N');
							l_msg := 'Unexpected ERROR while looking for PutAwayLst Values - Manifest No: ' || i_manifest_no ||
									 ' Prod ID: ' || NVL(l_item_list(item).prod_id, 'NULL') ;
							pl_log.ins_msg('FATAL', l_func_name, l_msg, SQLCODE, SUBSTR(SQLERRM, 1, 500), APPLICATION_FUNC, PACKAGE_NAME);
				END;
                -- ECLA1411 - END CHANGES

                IF l_food_safety_dci = 'Y' THEN
                    BEGIN       -- get food safety info
                        SELECT 'Y', nvl(temp_collected, NULL_VAL_INDICATOR)
                        INTO   l_food_safety_trk, l_food_safety_temp
                        FROM   food_safety_outbound
                        WHERE  manifest_no   = i_manifest_no
                          AND  stop_no       = l_item_list(item).stop_no
                          AND  obligation_no = l_item_list(item).obligation_no
                          AND  prod_id       = nvl(l_item_list(item).returned_prod_id, l_item_list(item).prod_id);

                        l_item_list(item).food_safety_trk  := l_food_safety_trk;
                        l_item_list(item).food_safety_temp := l_food_safety_temp;

                    EXCEPTION
                        WHEN NO_DATA_FOUND THEN
                            l_item_list(item).food_safety_trk  := 'N';
                            l_item_list(item).food_safety_temp := NULL_VAL_INDICATOR;
                        WHEN OTHERS THEN
                            l_status := rf.status_data_error;
                            l_msg := 'Query of FOOD_SAFETY_OUTBOUND FAILED for manifest# ['
                                  || i_manifest_no
                                  || '] stop# ['
                                  || l_item_list(item).stop_no
                                  || '] obligation# ['
                                  || l_item_list(item).obligation_no
                                  || '] prod_id ['
                                  || nvl(l_item_list(item).returned_prod_id, l_item_list(item).prod_id)
                                  || ']';
                            pl_log.ins_msg('FATAL', l_func_name, l_msg, SQLCODE, SUBSTR(SQLERRM, 1, 500), APPLICATION_FUNC, PACKAGE_NAME);
                            l_item_list(item).food_safety_trk  := 'N';
                            l_item_list(item).food_safety_temp := NULL_VAL_INDICATOR;
                    END;        -- get food safety info
                END IF;   -- if l_food_safety_dci is 'Y'

            END LOOP;    -- looping tru the list of returns to set missing data

            o_returned_items_list.manifest_no := i_manifest_no;
            o_returned_items_list.dci_ready   := l_dci_ready;
            o_returned_items_list.route_no    := l_route_no;
            o_returned_items_list.item_list   := l_item_list;

        END IF;

        return l_status;

    EXCEPTION
        WHEN OTHERS THEN
            l_status := rf.status_data_error;
            l_msg := l_func_name
                  || ' FAILED for manifest# ['
                  || i_manifest_no
                  || ']';
            pl_log.ins_msg('FATAL', l_func_name, l_msg, SQLCODE, SUBSTR(SQLERRM, 1, 500), APPLICATION_FUNC, PACKAGE_NAME);
            ROLLBACK;
            RAISE;

    END validate_mf_rtn;


    /************************************************************************
    --
    -- get_order_seq_no()
    --
    -- Description:      Gets the order seq# for a given return. Gets it
    --                   from either ordd_for_rtn or ordd.
    --
    -- Parameters:       i_route_no:           route#
    --                   i_stop_no:            stop#
    --                   i_order_id:           order#
    --                   i_prod_id:            item#
    --                   i_cpv:                cust pref vendor
    --                   i_returned_split_cd:  uom
    --
    --
    -- Return/output:    The order seq in a list.
    --
    -- Modification log:
    --
    -- Date         Developer     Change
    -- ------------------------------------------------------------------
    -- 24-SEP-2020  pkab6563      Initial version.
    -- 02-DEC-2021  sban3548      Modified to return multiple order_seq values
    --
    *************************************************************************/
    FUNCTION get_order_seq_no (
        i_route_no           IN  route.route_no%TYPE,
        i_stop_no            IN  returns.stop_no%TYPE,
        i_order_id           IN  returns.obligation_no%TYPE,
        i_prod_id            IN  returns.prod_id%TYPE,
        i_cpv                IN  returns.cust_pref_vendor%TYPE,
        i_returned_split_cd  IN  returns.returned_split_cd%TYPE
    ) return rtn_order_seq_table IS

        l_func_name   CONSTANT  swms_log.procedure_name%TYPE := 'get_order_seq_no';
		l_order_seq_list        rtn_order_seq_table := rtn_order_seq_table();
        l_msg                   swms_log.msg_text%TYPE;
        l_uom                   ordd.uom%TYPE;

    BEGIN
		
        BEGIN
            l_uom := NVL(TO_NUMBER(i_returned_split_cd), 0);

        EXCEPTION
            WHEN OTHERS THEN
                l_uom := 0;
        END; -- l_uom

        BEGIN
            SELECT rtn_order_seq_rec(order_seq)
            BULK COLLECT INTO l_order_seq_list
            FROM ( SELECT DISTINCT ordd_seq order_seq
					 FROM ordd_for_rtn
					WHERE  order_id         = i_order_id
					  AND  prod_id          = i_prod_id
					  AND  cust_pref_vendor = i_cpv
					  AND  route_no         = i_route_no
					  AND  stop_no          = i_stop_no
					  AND  uom              = l_uom
				  );

        EXCEPTION
      		WHEN OTHERS THEN
			l_msg := 'ERROR while BULK COLLECT of order seq from ORDD_FOR_RTN for route# ['
			  || i_route_no
			  || '] stop# ['
			  || i_stop_no
			  || '] order# ['
			  || i_order_id
			  || '] prod_id ['
			  || i_prod_id
			  || '] cpv ['
			  || i_cpv
			  || '] rtn split cd ['
			  || i_returned_split_cd
			  || ']';
			pl_log.ins_msg('FATAL', l_func_name, l_msg, SQLCODE, SUBSTR(SQLERRM, 1, 500), APPLICATION_FUNC, PACKAGE_NAME);
			RAISE;
		END; -- End of ordd_for_rtn 
		
		IF l_order_seq_list.FIRST IS NULL THEN
		BEGIN
			pl_log.ins_msg('WARN', l_func_name, 'NO_DATA_FOUND in ordd_for_rtn', SQLCODE, SUBSTR(SQLERRM, 1, 500), APPLICATION_FUNC, PACKAGE_NAME);
				
			SELECT rtn_order_seq_rec(order_seq)
			BULK COLLECT INTO l_order_seq_list
			FROM  (SELECT DISTINCT seq order_seq 
					FROM ordd
					WHERE  route_no         = i_route_no
					  AND  stop_no          = i_stop_no
					  AND  order_id         = i_order_id
					  AND  prod_id          = i_prod_id
					  AND  cust_pref_vendor = i_cpv
					  AND  uom              = DECODE(l_uom, 0, 2, l_uom)
				 );
			
			l_msg := 'Retrieved order seq for route# ['
				  || i_route_no
				  || '] stop# ['
				  || i_stop_no
				  || '] order# ['
				  || i_order_id
				  || '] prod_id ['
				  || i_prod_id
				  || '] cpv ['
				  || i_cpv
				  || '] l_uom ['
				  || l_uom
				  || ']';
			pl_log.ins_msg('FATAL', l_func_name, l_msg, SQLCODE, SUBSTR(SQLERRM, 1, 500), APPLICATION_FUNC, PACKAGE_NAME);

		EXCEPTION
			WHEN OTHERS THEN
				l_msg := 'ERROR while BULK COLLECT of order seq from ORDD for route# ['
				  || i_route_no
				  || '] stop# ['
				  || i_stop_no
				  || '] order# ['
				  || i_order_id
				  || '] prod_id ['
				  || i_prod_id
				  || '] cpv ['
				  || i_cpv
				  || '] rtn split cd ['
				  || i_returned_split_cd
				  || ']';
				pl_log.ins_msg('FATAL', l_func_name, l_msg, SQLCODE, SUBSTR(SQLERRM, 1, 500), APPLICATION_FUNC, PACKAGE_NAME);
				RAISE;
		END;  -- End of ordd select
		END IF;
		RETURN l_order_seq_list;
	END get_order_seq_no;


    /************************************************************************
    --
    -- delete_return()
    --
    -- Description:      Deletes a record from the returns table. the info
    --                   for the return to delete is passed in.
    --
    --                   Calls the related business logic function
    --                   delete_rtn() to handle the deletion.
    --
    -- Parameters:
    --                   i_rf_log_init_rec:    RF client related record.
    --                   i_manifest_no:        manifest#
    --                   i_stop_no:            stop#
    --                   i_obligation_no:      obligation#
    --                   i_prod_id:            prod_id
    --                   i_cpv:                cust pref vendor
    --                   i_return_reason_cd:   reason code
    --                   i_returned_split_cd:  uom
    --
    -- Return/output:    status code indicaing if the deletion was successful
    --                   or if there was an error.
    --
    -- Modification log:
    --
    -- Date         Developer     Change
    -- ------------------------------------------------------------------
    -- 14-OCT-2020  pkab6563      Initial version.
    --
    *************************************************************************/
    FUNCTION delete_return (
        i_rf_log_init_rec       IN  rf_log_init_record,
        i_manifest_no           IN  returns.manifest_no%TYPE,
        i_stop_no               IN  returns.stop_no%TYPE,
        i_obligation_no         IN  returns.obligation_no%TYPE,
        i_prod_id               IN  returns.prod_id%TYPE,
        i_cpv                   IN  returns.cust_pref_vendor%TYPE,
        i_return_reason_cd      IN  returns.return_reason_cd%TYPE,
        i_returned_split_cd     IN  returns.returned_split_cd%TYPE
    ) return rf.status IS

        l_func_name   CONSTANT  swms_log.procedure_name%TYPE := 'delete_return';
        l_status                rf.status := rf.status_normal;
        l_msg                   swms_log.msg_text%TYPE;

    BEGIN

         -- Call rf.initialize(). cannot procede if return status is not successful.
        l_status := rf.initialize(i_rf_log_init_rec);

        -- Log the input received from the RF client
        l_msg := 'Starting '
              || l_func_name
              || '. Received manifest# from RF client: ['
              || i_manifest_no
              || '] i_stop_no is ['
              || i_stop_no
              || '] i_obligation_no is ['
              || i_obligation_no
              || '] i_prod_id is ['
              || i_prod_id
              || '] i_cpv is ['
              || i_cpv
              || '] i_return_reason_cd is ['
              || i_return_reason_cd
              || '] i_returned_split_cd is ['
              || i_returned_split_cd
              || ']';
        pl_log.ins_msg('INFO', l_func_name, l_msg, null, null, APPLICATION_FUNC, PACKAGE_NAME);

        -- perform the business logic of the function by calling
        -- the business logic function
        IF l_status = rf.status_normal THEN
            l_status := delete_rtn(i_manifest_no,
                                   i_stop_no,
                                   i_obligation_no,
                                   i_prod_id,
                                   i_cpv,
                                   i_return_reason_cd,
                                   i_returned_split_cd);
        END IF; -- performing business logic if l_status is normal

        -- commit if delete was successful
        IF l_status = rf.status_normal THEN
            COMMIT;
            l_msg := 'Deletion successful. manifest# [' 
                  || i_manifest_no
                  || '] i_stop_no is ['
                  || i_stop_no
                  || '] i_obligation_no is ['
                  || i_obligation_no
                  || '] i_prod_id is ['
                  || i_prod_id
                  || '] i_cpv is ['
                  || i_cpv
                  || '] i_return_reason_cd is ['
                  || i_return_reason_cd
                  || '] i_returned_split_cd is ['
                  || i_returned_split_cd
                  || ']';
            pl_log.ins_msg('INFO', l_func_name, l_msg, null, null, APPLICATION_FUNC, PACKAGE_NAME);
        ELSE
            ROLLBACK;
            l_msg := 'Deletion FAILED. manifest# [' 
                  || i_manifest_no
                  || '] i_stop_no is ['
                  || i_stop_no
                  || '] i_obligation_no is ['
                  || i_obligation_no
                  || '] i_prod_id is ['
                  || i_prod_id
                  || '] i_cpv is ['
                  || i_cpv
                  || '] i_return_reason_cd is ['
                  || i_return_reason_cd
                  || '] i_returned_split_cd is ['
                  || i_returned_split_cd
                  || ']';
            pl_log.ins_msg('WARN', l_func_name, l_msg, null, null, APPLICATION_FUNC, PACKAGE_NAME);
        END IF;

        rf.complete(l_status);
        return l_status;

    EXCEPTION
        WHEN OTHERS THEN
            l_msg := 'ERROR in delete_return() for manifest# ['
                  || i_manifest_no
                  || '] i_stop_no is ['
                  || i_stop_no
                  || '] i_obligation_no is ['
                  || i_obligation_no
                  || '] i_prod_id is ['
                  || i_prod_id
                  || '] i_cpv is ['
                  || i_cpv
                  || '] i_return_reason_cd is ['
                  || i_return_reason_cd
                  || '] i_returned_split_cd is ['
                  || i_returned_split_cd
                  || ']';
            pl_log.ins_msg('FATAL', l_func_name, l_msg, SQLCODE, SUBSTR(SQLERRM, 1, 500), APPLICATION_FUNC, PACKAGE_NAME);
            rf.logexception();
            RAISE;

    END delete_return;

    /************************************************************************
    --
    -- delete_rtn()
    --
    -- Description:      Business logic for delete_return(). 
    --                   Deletes a record from the returns table. the info
    --                   for the return to delete is passed in.
    --
    -- SPECIAL NOTE:     The caller will need to COMMIT if the return status
    --                   is rf.status_normal. ROLLBACK otherwise.
    --
    -- Parameters:       
    --                   i_manifest_no:        manifest#
    --                   i_stop_no:            stop#
    --                   i_obligation_no:      obligation#     
    --                   i_prod_id:            prod_id
    --                   i_cpv:                cust pref vendor
    --                   i_return_reason_cd:   reason code
    --                   i_returned_split_cd:  uom
    --
    -- Return/output:    status code indicaing if the deletion was successful
    --                   or if there was an error.
    --
    -- Modification log:
    --
    -- Date         Developer     Change
    -- ------------------------------------------------------------------
    -- 14-OCT-2020  pkab6563      Initial version.
    -- 16-APR-2021  vkal9662      added logic to check if there a putawayput existing -then cannot delete
    *************************************************************************/
    FUNCTION delete_rtn ( 
        i_manifest_no           IN  returns.manifest_no%TYPE,
        i_stop_no               IN  returns.stop_no%TYPE,
        i_obligation_no         IN  returns.obligation_no%TYPE,
        i_prod_id               IN  returns.prod_id%TYPE,
        i_cpv                   IN  returns.cust_pref_vendor%TYPE,
        i_return_reason_cd      IN  returns.return_reason_cd%TYPE,
        i_returned_split_cd     IN  returns.returned_split_cd%TYPE
    ) return rf.status IS

        l_func_name      CONSTANT  swms_log.procedure_name%TYPE := 'delete_rtn';
        l_msg                      swms_log.msg_text%TYPE;
        l_status                   rf.status := rf.status_normal;
        l_rtn_sent_ind             returns.rtn_sent_ind%TYPE;
        l_shipped_split_cd         returns.shipped_split_cd%TYPE;
        l_rec_type                 returns.rec_type%TYPE;
        l_stop_no                  returns.stop_no%TYPE;
        l_erm_line_id              returns.erm_line_id%TYPE;
        l_mf_status                manifests.manifest_status%TYPE;
        l_route_no                 manifests.route_no%TYPE;
        l_reason_group             reason_cds.reason_group%TYPE;
        is_putaway                 putawaylst.putaway_put%TYPE;
        l_dmg_erm_id           erm.erm_id%TYPE := 'D' || TO_CHAR(i_manifest_no);
        l_sal_erm_id           erm.erm_id%TYPE := 'S' || TO_CHAR(i_manifest_no);

    BEGIN

        -- ensure manifest is not already closed
        l_status := verify_mf_is_not_cls(i_manifest_no, l_mf_status, l_route_no);

        IF i_stop_no = NULL_VAL_INDICATOR THEN
            l_stop_no := null;
        ELSE
            l_stop_no := i_stop_no;
        END IF;

        -- check rtn_sent_ind and rec_type
        IF l_status = rf.status_normal THEN
            BEGIN
                SELECT nvl(rtn_sent_ind, 'N'), 
                       nvl(shipped_split_cd, '*'),
                       nvl(rec_type, '*'),
                       erm_line_id
                INTO   l_rtn_sent_ind, 
                       l_shipped_split_cd, 
                       l_rec_type,
                       l_erm_line_id
                FROM   returns
                WHERE  manifest_no       = i_manifest_no
                  AND  (stop_no          = l_stop_no
                        OR stop_no IS NULL)
                  AND  (obligation_no    = i_obligation_no
                        OR obligation_no IS NULL)
                  AND  prod_id           = i_prod_id
                  AND  cust_pref_vendor  = i_cpv
                  AND  return_reason_cd  = i_return_reason_cd
                  AND  returned_split_cd = i_returned_split_cd;
                  
              
            Begin  
               SELECT upper(NVL(p.putaway_put, 'N')) 
               INTO   is_putaway
               FROM   putawaylst p
               WHERE 1=1
               AND p.rec_id IN (l_dmg_erm_id, l_sal_erm_id)
               AND  prod_id      = i_prod_id
               AND p.erm_line_id = l_erm_line_id;
            Exception when others then
            
              is_putaway := 'N';
            
            End ;
             

                IF l_rtn_sent_ind IN ('Y', 'y') 
                OR l_rec_type = 'P' OR is_putaway = 'Y' THEN
                    l_status := rf.status_delete_not_allowed;
                    l_msg := 'Cannot delete return due to one of the following: '
                          || 'rtn_sent_ind is ['
                          || l_rtn_sent_ind
                          || '] rec_type is ['
                          || l_rec_type
                          || ']'||' or Item is Putaway';
                    pl_log.ins_msg('WARN', l_func_name, l_msg, null, null, APPLICATION_FUNC, PACKAGE_NAME);
                END IF; -- checking rtn_sent_ind 

            EXCEPTION
                WHEN OTHERS THEN
                    l_status := rf.status_data_error;
                    l_msg := 'ERROR in delete_rtn() while querying returns table for manifest# ['
                          || i_manifest_no
                          || '] i_stop_no ['
                          || i_stop_no
                          || '] i_obligation_no ['
                          || i_obligation_no
                          || '] i_prod_id ['
                          || i_prod_id
                          || '] i_cpv ['
                          || i_cpv
                          || '] i_return_reason_cd ['
                          || i_return_reason_cd
                          || '] i_returned_split_cd ['
                          || i_returned_split_cd
                          || ']';
                    pl_log.ins_msg('FATAL', l_func_name, l_msg, SQLCODE, SUBSTR(SQLERRM, 1, 500), APPLICATION_FUNC, PACKAGE_NAME); 

            END;  -- selecting from returns to check rtn_sent_ind and rec_type
        END IF;  -- selecting from returns if status is normal 

        -- check reason group: cannot be invoice return (WIN).
        -- if deleting an invoice return, all other returns for the same invoice
        -- must be deleted. therefore delete_invoice_rtn() should be used instead
        -- of delete_rtn().
        IF l_status = rf.status_normal THEN
            BEGIN
                SELECT reason_group
                  INTO l_reason_group
                FROM   reason_cds
                WHERE  reason_cd_type = 'RTN'
                  AND  reason_cd      = i_return_reason_cd;

                IF l_reason_group = 'WIN' THEN
                    l_status := rf.status_invalid_rsn; 
                    l_msg := 'INVALID reason code for single return deletion. i_return_reason_cd ['
                          || i_return_reason_cd
                          || ']. Reason code is for invoice return. single return deletion '
                          || 'cannot be used for invoice return deletion.';
                    pl_log.ins_msg('WARN', l_func_name, l_msg, null, null, APPLICATION_FUNC, PACKAGE_NAME); 
                END IF;

            EXCEPTION
                WHEN OTHERS THEN
                    null;

            END;   -- check reason group
        END IF;   -- check reason group

        IF l_status = rf.status_normal THEN
            BEGIN
                DELETE 
                FROM returns
                WHERE  manifest_no       = i_manifest_no
                  AND  (stop_no          = l_stop_no
                        OR stop_no IS NULL)
                  AND  (obligation_no    = i_obligation_no
                        OR obligation_no IS NULL)
                  AND  prod_id           = i_prod_id
                  AND  cust_pref_vendor  = i_cpv
                  AND  return_reason_cd  = i_return_reason_cd
                  AND  returned_split_cd = i_returned_split_cd;

                IF sql%rowcount != 1 THEN
                    l_status := rf.status_data_error;
                    l_msg := 'ERROR. Attempted to delete ['
                          || sql%rowcount 
                          || '] records from returns';
                    pl_log.ins_msg('WARN', l_func_name, l_msg, null, null, APPLICATION_FUNC, PACKAGE_NAME); 
                END IF;

            EXCEPTION
                WHEN OTHERS THEN
                    l_status := rf.status_data_error;
                    l_msg := 'ERROR in delete_rtn() while attempting to delete return for manifest# ['
                          || i_manifest_no
                          || '] i_stop_no ['
                          || i_stop_no
                          || '] i_obligation_no ['
                          || i_obligation_no
                          || '] i_prod_id ['
                          || i_prod_id
                          || '] i_cpv ['
                          || i_cpv
                          || '] i_return_reason_cd ['
                          || i_return_reason_cd
                          || '] i_returned_split_cd ['
                          || i_returned_split_cd
                          || ']';
                    pl_log.ins_msg('FATAL', l_func_name, l_msg, SQLCODE, SUBSTR(SQLERRM, 1, 500), APPLICATION_FUNC, PACKAGE_NAME); 
            END; -- deleting the return
        END IF;  -- deleting return if l_status is normal

        IF l_status = rf.status_normal THEN
            UPDATE manifest_dtls
            SET    manifest_dtl_status = 'OPN'
            WHERE  manifest_no         = i_manifest_no
              AND  (stop_no            = l_stop_no
                    OR stop_no IS NULL)
              AND  prod_id             = i_prod_id
              AND  cust_pref_vendor    = i_cpv
              AND  obligation_no       = i_obligation_no
              AND  shipped_split_cd    = l_shipped_split_cd
              AND  NOT EXISTS
                   (SELECT 1 
                    FROM   returns
                    WHERE  manifest_no = i_manifest_no
                      AND  (stop_no    = l_stop_no
                            OR stop_no IS NULL)
                      AND  prod_id             = i_prod_id
                      AND  cust_pref_vendor    = i_cpv
                      AND  obligation_no       = i_obligation_no
                      AND  shipped_split_cd    = l_shipped_split_cd
                   );

            IF sql%rowcount > 1 THEN
                l_status := rf.status_data_error;
                l_msg := 'ERROR. Attempted to update ['
                      || sql%rowcount 
                      || '] records in manifest_dtls during deletion of return. Deletion DENIED';
                pl_log.ins_msg('WARN', l_func_name, l_msg, null, null, APPLICATION_FUNC, PACKAGE_NAME); 
            END IF;
        END IF;  -- updating manifest_dtls

        -- delete from food_safety_outbound 
        IF l_status = rf.status_normal THEN
            DELETE
            FROM   food_safety_outbound
            WHERE  manifest_no   = i_manifest_no
              AND  obligation_no = i_obligation_no
              AND  prod_id       = i_prod_id
              AND  NOT EXISTS
                   (SELECT 1
                    FROM   returns
                    WHERE  manifest_no = i_manifest_no
                      AND  (stop_no    = l_stop_no
                            OR stop_no IS NULL)
                      AND  prod_id             = i_prod_id
                      AND  cust_pref_vendor    = i_cpv
                      AND  obligation_no       = i_obligation_no
                   );
        END IF;   -- delete from food_safety_outbound

        -- delete potential pending puts
        IF l_status = rf.status_normal THEN
            l_status := delete_rtn_pending_puts(i_manifest_no, l_erm_line_id);
        END IF;   -- delete potential pending puts

        return l_status;

    EXCEPTION
        WHEN OTHERS THEN
            l_status := rf.status_data_error;
            l_msg := 'ERROR in delete_rtn() for manifest# ['
                  || i_manifest_no
                  || '] i_stop_no ['
                  || i_stop_no
                  || '] i_obligation_no ['
                  || i_obligation_no
                  || '] i_prod_id ['
                  || i_prod_id
                  || '] i_cpv ['
                  || i_cpv
                  || '] i_return_reason_cd ['
                  || i_return_reason_cd
                  || '] i_returned_split_cd ['
                  || i_returned_split_cd
                  || ']';
            pl_log.ins_msg('FATAL', l_func_name, l_msg, SQLCODE, SUBSTR(SQLERRM, 1, 500), APPLICATION_FUNC, PACKAGE_NAME); 
            ROLLBACK;
            return l_status;

    END delete_rtn;

    /************************************************************************
    --
    -- invoice_return()
    --
    -- Description:      Inserts or deletes returns for an invoice.
    --      
    --                   Calls add_invoice_rtn() if i_action is 'A'.
    --                   Calls delete_invoice_rtn() if i_action is 'D'.
    --
    -- Parameters:       
    --                   i_rf_log_init_rec:     RF client related record.     
    --                   i_action:              action code: 'A' = add
    --                                                       'D' = delete 
    --                   i_manifest_no:         manifest#
    --                   i_obligation_no:       obligation# (i.e. invoice#)     
    --                   i_return_reason_cd:    reason code
    --                   o_returned_items_list: list of returns after
    --                                          insert/delete of returns
    --                                          for given invoice.
    --
    -- Return/output:    status code indicaing success or error.
    --
    -- Modification log:
    --
    -- Date         Developer     Change
    -- ------------------------------------------------------------------
    -- 27-OCT-2020  pkab6563      Initial version.
    --
    *************************************************************************/
    FUNCTION invoice_return (
        i_rf_log_init_rec       IN  rf_log_init_record,
        i_action                IN  VARCHAR2,
        i_manifest_no           IN  manifests.manifest_no%TYPE,
        i_obligation_no         IN  returns.obligation_no%TYPE,
        i_return_reason_cd      IN  returns.return_reason_cd%TYPE,
        o_returned_items_list   OUT rtn_validation_obj
    ) return rf.status IS

        l_func_name  CONSTANT  swms_log.procedure_name%TYPE := 'invoice_return';
        l_status               rf.status := rf.status_normal;
        l_msg                  swms_log.msg_text%TYPE;

    BEGIN

        -- Initialize the out parameter
        o_returned_items_list := rtn_validation_obj(i_manifest_no, 'N', ' ', rtn_item_table());

        -- Call rf.initialize(). cannot procede if return status is not successful.
        l_status := rf.initialize(i_rf_log_init_rec);

        -- Log the input received from the RF client
        l_msg := 'Starting '
              || l_func_name
              || '. Received from RF client: manifest# is ['
              || i_manifest_no
              || '] i_obligation_no is ['
              || i_obligation_no
              || '] i_return_reason_cd is ['
              || i_return_reason_cd
              || ']';
        pl_log.ins_msg('INFO', l_func_name, l_msg, null, null, APPLICATION_FUNC, PACKAGE_NAME);

        -- check the action code and perform related logic
        IF l_status = rf.status_normal THEN
            IF i_action = 'A' THEN
                l_status := add_invoice_rtn(i_manifest_no, i_obligation_no, i_return_reason_cd);
            ELSIF i_action = 'D' THEN
                l_status := delete_invoice_rtn(i_manifest_no, i_obligation_no);
            ELSE
                l_status := rf.status_inv_code;
            END IF;
        END IF;  -- if normal status, perform business logic based on i_action code

        -- after adding or deleting the returns, validate manifest returns.
        IF l_status = rf.status_normal THEN
            l_status := validate_mf_rtn(i_manifest_no, 'N', o_returned_items_list);
        END IF;

        l_msg := 'l_status at the end of invoice_return() is ['
              || l_status
              || ']';
        pl_log.ins_msg('INFO', l_func_name, l_msg, null, null, APPLICATION_FUNC, PACKAGE_NAME);

        rf.complete(l_status);
        return l_status;

    EXCEPTION
        WHEN OTHERS THEN
            l_msg := 'Unexpected ERROR in invoice_return() for manifest# ['
                  || i_manifest_no
                  || '] i_obligation_no ['
                  || i_obligation_no
                  || '] i_return_reason_cd ['
                  || i_return_reason_cd
                  || ']';
            pl_log.ins_msg('FATAL', l_func_name, l_msg, SQLCODE, SUBSTR(SQLERRM, 1, 500), APPLICATION_FUNC, PACKAGE_NAME);
            rf.logexception();
            RAISE;

    END invoice_return;

    /************************************************************************
    --
    -- add_invoice_rtn()
    --
    -- Description:      Inserts returns for an invoice.
    --                   Logic based on procedure invoice_return in
    --                   form rtnsdtl.fmb.
    --      
    -- Parameters:       
    --                   i_manifest_no:       manifest#
    --                   i_obligation_no:     obligation# (i.e. invoice#)     
    --                   i_return_reason_cd:  reason code
    --
    -- Return/output:    status code indicating success or error.
    --
    -- Modification log:
    --
    -- Date         Developer     Change
    -- ------------------------------------------------------------------
    -- 27-OCT-2020  pkab6563      Initial version.
    --
    *************************************************************************/
    FUNCTION add_invoice_rtn (
        i_manifest_no           IN  manifests.manifest_no%TYPE,
        i_obligation_no         IN  returns.obligation_no%TYPE,
        i_return_reason_cd      IN  returns.return_reason_cd%TYPE
    ) return rf.status IS

        l_func_name  CONSTANT  swms_log.procedure_name%TYPE := 'add_invoice_rtn';
        l_status               rf.status := rf.status_normal;
        l_msg                  swms_log.msg_text%TYPE;
        l_mf_status            manifests.manifest_status%TYPE;
        l_dci_ready            manifests.sts_completed_ind%TYPE;
        l_reason_cd            returns.return_reason_cd%TYPE;
        l_reason_group         reason_cds.reason_group%TYPE;
        l_reason_cd_type       reason_cds.reason_cd_type%TYPE;
        l_cnt                  PLS_INTEGER := 0;
        l_mf_no                manifests.manifest_no%TYPE;          
        l_rtn_cnt              PLS_INTEGER := 0;
        l_rti_cnt              PLS_INTEGER := 0;
        l_cls_cnt              PLS_INTEGER := 0;
        l_max_line_id          PLS_INTEGER := 0;
        l_rec_type             manifest_dtls.rec_type%TYPE;
        l_stop_no              manifest_dtls.stop_no%TYPE;

        l_cust_id              food_safety_outbound.customer_id%TYPE;
        l_user                 food_safety_outbound.add_user%TYPE := REPLACE(USER, 'OPS$', NULL);
        l_invoice_return_limit NUMBER := 3;
        l_food_safety_dci      VARCHAR2(1);  -- syspar
   
        CURSOR get_cust_id (i_stop_no manifest_dtls.stop_no%TYPE) IS
        select customer_id
        from manifest_stops
        where manifest_no = i_manifest_no
        and   stop_no = i_stop_no
        and   obligation_no = i_obligation_no;

    BEGIN

        l_msg := 'Starting add_invoice_rtn(). manifest# ['
                  || i_manifest_no
                  || '] i_obligation_no ['
                  || i_obligation_no
                  || '] i_return_reason_cd ['
                  || i_return_reason_cd
                  || ']';
        pl_log.ins_msg('INFO', l_func_name, l_msg, null, null, APPLICATION_FUNC, PACKAGE_NAME);

        l_invoice_return_limit := pl_common.f_get_syspar('FOOD_SAFETY_INVOICE_COLLECT', 3);
        l_food_safety_dci      := pl_common.f_get_syspar('FOOD_SAFETY_DCI', 'N');

        -- check manifest status; it must be OPN for invoice returns
        IF l_status = rf.status_normal THEN
            l_status := verify_mf_is_opn(i_manifest_no);
        END IF;
    
        -- check the reason code and its group.
        IF l_status = rf.status_normal THEN
            BEGIN
                SELECT reason_group
                  INTO l_reason_group
                FROM   reason_cds
                WHERE  reason_cd_type = 'RTN'
                  AND  reason_cd      = i_return_reason_cd;

                IF l_reason_group != 'WIN' THEN
                    l_status := rf.status_invalid_rsn;
                    l_msg := 'INVALID reason code for invoice return. Manifest# ['
                          || i_manifest_no
                          || '] obligation# ['
                          || i_obligation_no
                          || '] reason code ['
                          || i_return_reason_cd
                          || ']';
                    pl_log.ins_msg('WARN', l_func_name, l_msg, null, null, APPLICATION_FUNC, PACKAGE_NAME);
                END IF;

            EXCEPTION
                WHEN OTHERS THEN
                    l_status := rf.status_data_error;
                    l_msg := 'Unexpected ERROR during query of reason_cds table for reason code ['
                          || i_return_reason_cd
                          || '] and reason code type RTN';
                    pl_log.ins_msg('FATAL', l_func_name, l_msg, SQLCODE, SUBSTR(SQLERRM, 1, 500), APPLICATION_FUNC, PACKAGE_NAME);

            END;   -- checking reason code and group
        END IF;

        -- validate invoice; get rec_type, stop_no.
        IF l_status = rf.status_normal THEN
            BEGIN
                SELECT rec_type, stop_no
                  INTO l_rec_type, l_stop_no
                FROM   manifest_dtls
                WHERE  manifest_no   = i_manifest_no
                  AND  obligation_no = i_obligation_no
                  AND  rownum = 1;

            EXCEPTION
                WHEN NO_DATA_FOUND THEN
                    l_status := rf.status_data_error;
                    l_msg := 'Invoice# was NOT FOUND in manifest_dtls for manifest# ['
                          || i_manifest_no
                          || '] invoice# ['
                          || i_obligation_no
                          || ']';
                    pl_log.ins_msg('WARN', l_func_name, l_msg, null, null, APPLICATION_FUNC, PACKAGE_NAME);

                WHEN OTHERS THEN
                    l_status := rf.status_data_error;
                    l_msg := 'Unexpected ERROR while querying manifest_dtls table for manifest# ['
                          || i_manifest_no
                          || '] obligation# ['
                          || i_obligation_no
                          || ']';
                    pl_log.ins_msg('FATAL', l_func_name, l_msg, SQLCODE, SUBSTR(SQLERRM, 1, 500), APPLICATION_FUNC, PACKAGE_NAME);
                
            END;
        END IF;  -- validate invoice; get rec_type.

        IF l_status = rf.status_normal THEN
            -- more invoice validation
            BEGIN
                SELECT SUM(DECODE(manifest_dtl_status, 'RTI', 1, 0)),
                       SUM(DECODE(manifest_dtl_status, 'RTN', 1, 0)),
                       SUM(DECODE(manifest_dtl_status, 'CLS', 1, 0))
                  INTO l_rti_cnt,
                       l_rtn_cnt,
                       l_cls_cnt
                FROM   manifest_dtls
                WHERE  manifest_no   = i_manifest_no
                  AND  obligation_no = i_obligation_no;

                IF l_cls_cnt > 0 THEN
                    l_status := rf.status_invoice_returned;
                    l_msg := 'Invoice was ALREADY RETURNED; manifest# ['
                          || i_manifest_no
                          || '] invoice# ['
                          || i_obligation_no
                          || ']';
                    pl_log.ins_msg('WARN', l_func_name, l_msg, null, null, APPLICATION_FUNC, PACKAGE_NAME);
                ELSIF (l_rti_cnt > 0) OR (l_rtn_cnt > 0) THEN
                    l_status := rf.status_inv_return_existed;
                    l_msg := 'Invoice has at least one return; manifest# ['
                          || i_manifest_no
                          || '] invoice# ['
                          || i_obligation_no
                          || ']';
                    pl_log.ins_msg('WARN', l_func_name, l_msg, null, null, APPLICATION_FUNC, PACKAGE_NAME);
                END IF;  -- checking counts

            EXCEPTION
                WHEN OTHERS THEN
                    l_status := rf.status_data_error;
                    l_msg := 'Unexpected ERROR while querying manifest_dtls table for count of records for manifest# ['
                          || i_manifest_no
                          || '] obligation# ['
                          || i_obligation_no
                          || ']';
                    pl_log.ins_msg('FATAL', l_func_name, l_msg, SQLCODE, SUBSTR(SQLERRM, 1, 500), APPLICATION_FUNC, PACKAGE_NAME);

            END;
        END IF;  -- more invoice validation

        -- lock the manifest
        IF l_status = rf.status_normal THEN
            BEGIN
                SELECT manifest_no
                  INTO l_mf_no
                FROM   manifests
                WHERE  manifest_no = i_manifest_no
                FOR UPDATE NOWAIT;
          
            EXCEPTION
                WHEN OTHERS THEN
                    l_status := rf.status_rec_lock_by_other;
                    l_msg := 'ERROR while trying to lock manifest record for manifest# ['
                          || i_manifest_no
                          || ']';
                    pl_log.ins_msg('FATAL', l_func_name, l_msg, SQLCODE, SUBSTR(SQLERRM, 1, 500), APPLICATION_FUNC, PACKAGE_NAME);
                    
            END; 
        END IF;  -- lock manifest 

        -- get current max erm_line_id for manifest
        IF l_status = rf.status_normal THEN
            BEGIN
                SELECT nvl(MAX(nvl(erm_line_id, 0)), 0)
                  INTO l_max_line_id
                FROM   returns
                WHERE  manifest_no = i_manifest_no;

            EXCEPTION
                WHEN OTHERS THEN
                    l_status := rf.status_data_error;
                    l_msg := 'Unexpected ERROR while querying returns table for max erm_line_id for manifest# ['
                          || i_manifest_no
                          || ']';
                    pl_log.ins_msg('FATAL', l_func_name, l_msg, SQLCODE, SUBSTR(SQLERRM, 1, 500), APPLICATION_FUNC, PACKAGE_NAME);
            END;
        END IF;  -- get current max erm_line_id for manifest

        IF l_status = rf.status_normal THEN
            -- logic from forms
            -- if rec_type is P, update returns; otherwise insert.

            BEGIN
                IF l_rec_type = 'P' THEN
                    UPDATE returns r
                    SET   (returned_qty,
                           returned_split_cd,
                           shipped_qty,
                           shipped_split_cd,
	                         upd_source,
	                         status) =
                          (SELECT shipped_qty,
                                  shipped_split_cd,
                                  shipped_qty,
                                  shipped_split_cd,
		                              'RF',
                                  'PUT'
                           FROM  manifest_dtls md
                           WHERE md.manifest_no      = r.manifest_no
                             AND md.stop_no          = r.stop_no
                             AND md.obligation_no    = r.obligation_no
                             AND md.rec_type         = r.rec_type
                             AND md.prod_id          = r.prod_id
                             AND md.cust_pref_vendor = r.cust_pref_vendor
                             AND md.shipped_split_cd = r.shipped_split_cd  )
                    WHERE r.obligation_no = i_obligation_no
                      AND r.manifest_no   = i_manifest_no
                      AND r.rec_type      = 'P';
                ELSE  -- insert
                    INSERT INTO returns
                          (manifest_no,      
                           route_no,          
                           stop_no,
                           rec_type,         
                           obligation_no,
                           prod_id,          
                           cust_pref_vendor,
                           returned_prod_id,
                           return_reason_cd, 
                           returned_qty,
                           returned_split_cd,
                           shipped_split_cd,
                           shipped_qty,
                           erm_line_id,
	                   add_source, 
                           status)
                    SELECT i_manifest_no, 
                           m.route_no,     
                           md.stop_no,
                           md.rec_type,         
                           i_obligation_no,
                           md.prod_id,          
                           md.cust_pref_vendor,
                           md.prod_id,
                           i_return_reason_cd,  
                           md.shipped_qty,
                           md.shipped_split_cd, 
                           md.shipped_split_cd,
                           md.shipped_qty,
                           l_max_line_id + rownum,
	                   'RF', 
                           'PUT'
                    FROM   manifests m, manifest_dtls md
                    WHERE  md.manifest_no = m.manifest_no
                      AND  nvl(md.manifest_dtl_status, ' ') NOT IN ('RTI', 'RTN')
                      AND  md.obligation_no = i_obligation_no
                      AND  md.manifest_no   = i_manifest_no
                      AND  md.shipped_qty  != 0;
                END IF;  -- if rec_type is P, update returns; otherwise insert.

                UPDATE manifest_dtls
                SET    manifest_dtl_status = 'RTI'
                WHERE  manifest_no   = i_manifest_no
                  AND  obligation_no = i_obligation_no
                  AND  shipped_qty  != 0;

            EXCEPTION
                WHEN OTHERS THEN
                    l_status := rf.status_data_error;
                    l_msg := 'Unexpected ERROR during insert/update of returns for manifest# ['
                          || i_manifest_no
                          || '] obligation# ['
                          || i_obligation_no
                          || ']';
                    pl_log.ins_msg('FATAL', l_func_name, l_msg, SQLCODE, SUBSTR(SQLERRM, 1, 500), APPLICATION_FUNC, PACKAGE_NAME);
            END;
        END IF;  -- insert or update returns if normal status

        -- insert food safety records
        OPEN get_cust_id(l_stop_no);
        FETCH get_cust_id into l_cust_id;
        IF get_cust_id%NOTFOUND THEN
   	    l_cust_id := 'XXXXX';
        END IF;
        CLOSE get_cust_id;

        IF nvl(l_food_safety_dci, 'N') = 'Y' THEN
            INSERT INTO FOOD_SAFETY_OUTBOUND
                (manifest_no, stop_no, prod_id, obligation_no, customer_id,
                 temp_collected, add_source, time_collected, add_date, add_user,
                 reason_cd, reason_group)
            SELECT m.manifest_no, m.stop_no, m.prod_id, m.obligation_no, l_cust_id,
                 NULL, 'RF',  SYSDATE,  SYSDATE,  l_user,
                 i_return_reason_cd, 'WIN'
            FROM MANIFEST_DTLS m, PM p, HACCP_CODES h
            WHERE m.manifest_no = i_manifest_no
            AND   m.obligation_no = i_obligation_no
            AND   nvl(m.shipped_qty, 0) > 0
            AND   m.prod_id = p.prod_id
            AND   m.cust_pref_vendor = p.cust_pref_vendor
            AND   p.hazardous = h.haccp_code
            AND   nvl(h.food_safety_trk, 'N') = 'Y'
            AND   ROWNUM <= nvl(l_invoice_return_limit, 3)
            AND   not exists (select 1 from food_safety_outbound f2 
                        where f2.manifest_no = m.manifest_no
                        and   f2.obligation_no = m.obligation_no
                        and   f2.prod_id = m.prod_id);
        END IF;    -- checking l_food_safety_dci

        -- commit if success
        IF l_status = rf.status_normal THEN
            COMMIT;
        ELSE
            ROLLBACK;
        END IF; 

        l_msg := 'l_status at the end of add_invoice_rtn() is ['
              || l_status
              || ']';
        pl_log.ins_msg('INFO', l_func_name, l_msg, null, null, APPLICATION_FUNC, PACKAGE_NAME);

        return l_status;

    EXCEPTION
        WHEN OTHERS THEN
            l_status := rf.status_data_error;
            l_msg := 'Unexpected ERROR in add_invoice_rtn() for manifest# ['
                  || i_manifest_no
                  || '] i_obligation_no ['
                  || i_obligation_no
                  || '] i_return_reason_cd ['
                  || i_return_reason_cd
                  || ']';
            pl_log.ins_msg('FATAL', l_func_name, l_msg, SQLCODE, SUBSTR(SQLERRM, 1, 500), APPLICATION_FUNC, PACKAGE_NAME);
            ROLLBACK;
            return l_status;

    END add_invoice_rtn;

    /************************************************************************
    --
    -- delete_invoice_rtn()
    --
    -- Description:      Deletes returns for an invoice.
    --      
    -- Parameters:       
    --                   i_manifest_no:     manifest#
    --                   i_obligation_no:   obligation# (i.e. invoice#)     
    --
    -- Return/output:    status code indicating success or error.
    --
    -- Modification log:
    --
    -- Date         Developer     Change
    -- ------------------------------------------------------------------
    -- 27-OCT-2020  pkab6563      Initial version.
    --
    *************************************************************************/
    FUNCTION delete_invoice_rtn (
        i_manifest_no           IN  manifests.manifest_no%TYPE,
        i_obligation_no         IN  returns.obligation_no%TYPE
    ) return rf.status IS

        l_func_name      CONSTANT  swms_log.procedure_name%TYPE := 'delete_invoice_rtn';
        l_msg                      swms_log.msg_text%TYPE;
        l_status                   rf.status := rf.status_normal;
        l_p_cnt                    PLS_INTEGER := 0;
        l_sent_cnt                 PLS_INTEGER := 0;
        l_mf_no                    manifests.manifest_no%TYPE;          
        l_reason_group             reason_cds.reason_group%TYPE;
        l_count                    PLS_INTEGER := 0;

        CURSOR c_get_erm_line_id IS
        SELECT erm_line_id
        FROM   returns
        WHERE  manifest_no   = i_manifest_no
          AND  obligation_no = i_obligation_no;

        CURSOR c_get_reason_code IS
        SELECT DISTINCT return_reason_cd
        FROM   returns
        WHERE  manifest_no   = i_manifest_no
          AND  obligation_no = i_obligation_no;

    BEGIN

        l_msg := 'Starting delete_invoice_rtn(). manifest# ['
                  || i_manifest_no
                  || '] i_obligation_no ['
                  || i_obligation_no                  
                  || ']';
        pl_log.ins_msg('INFO', l_func_name, l_msg, null, null, APPLICATION_FUNC, PACKAGE_NAME);

        -- check manifest status; it must be OPN for invoice returns
        IF l_status = rf.status_normal THEN
            l_status := verify_mf_is_opn(i_manifest_no);
        END IF;

        -- verify existence of related returns
        IF l_status = rf.status_normal THEN
            SELECT COUNT(*)
              INTO l_count
            FROM   returns
            WHERE  manifest_no   = i_manifest_no
              AND  obligation_no = i_obligation_no;

            IF l_count = 0 THEN
                l_status := rf.status_data_error;
                l_msg := 'NO DATA FOUND in returns table for manifest# ['
                      || i_manifest_no
                      || '] and invoice# ['
                      || i_obligation_no
                      || ']';
                pl_log.ins_msg('WARN', l_func_name, l_msg, null, null, APPLICATION_FUNC, PACKAGE_NAME);
            END IF;
        END IF;   -- verify existence of related returns

        -- check return reason group; it must be for invoice return (WIN) 
        IF l_status = rf.status_normal THEN
            BEGIN
                FOR r_row IN c_get_reason_code LOOP
                    SELECT reason_group
                      INTO l_reason_group
                    FROM   reason_cds
                    WHERE  reason_cd_type = 'RTN'
                      AND  reason_cd      = r_row.return_reason_cd;

                    IF l_reason_group != 'WIN' THEN
                        l_status := rf.status_invalid_rsn;
                        l_msg := 'Reason code NOT for invoice return. reason code: ['
                              || r_row.return_reason_cd
                              || ']';
                        pl_log.ins_msg('WARN', l_func_name, l_msg, null, null, APPLICATION_FUNC, PACKAGE_NAME);
                        exit;
                    END IF;
                END LOOP;

            EXCEPTION
                WHEN OTHERS THEN
                    l_status := rf.status_data_error;
                    l_msg := 'ERROR during query of reason_cds table in delete_invoice_rtn() for manifest# ['
                          || i_manifest_no
                          || '] invoice# ['
                          || i_obligation_no
                          || ']';
                    pl_log.ins_msg('FATAL', l_func_name, l_msg, SQLCODE, SUBSTR(SQLERRM, 1, 500), APPLICATION_FUNC, PACKAGE_NAME);

            END;

        END IF;   -- check return reason group; it must be for invoice return (WIN)
    
        -- check rec_type and rtn_sent_ind
        IF l_status = rf.status_normal THEN
            SELECT SUM(DECODE(rec_type, 'P', 1, 0)),
                   SUM(DECODE(rtn_sent_ind, 'Y', 1, 0))
              INTO l_p_cnt,
                   l_sent_cnt
            FROM   returns
            WHERE  manifest_no   = i_manifest_no
              AND  obligation_no = i_obligation_no;

            IF (l_p_cnt > 0) OR (l_sent_cnt > 0) THEN
                l_status := rf.status_delete_not_allowed;
                l_msg := 'At least one return for this manifest ['
                      || i_manifest_no
                      || '] and invoice# ['
                      || i_obligation_no 
                      || '] has rtn_sent_ind = Y or rec_type = P. Delete is not allowed.';
                pl_log.ins_msg('WARN', l_func_name, l_msg, null, null, APPLICATION_FUNC, PACKAGE_NAME);
            END IF;
        END IF;  -- check rec_type and rtn_sent_ind

        -- lock the manifest
        IF l_status = rf.status_normal THEN
            BEGIN
                SELECT manifest_no
                  INTO l_mf_no
                FROM   manifests
                WHERE  manifest_no = i_manifest_no
                FOR UPDATE NOWAIT;
          
            EXCEPTION
                WHEN OTHERS THEN
                    l_status := rf.status_rec_lock_by_other;
                    l_msg := 'ERROR while trying to lock manifest record for manifest# ['
                          || i_manifest_no
                          || ']';
                    pl_log.ins_msg('FATAL', l_func_name, l_msg, SQLCODE, SUBSTR(SQLERRM, 1, 500), APPLICATION_FUNC, PACKAGE_NAME);
                    
            END; 
        END IF;  -- lock manifest 

        -- delete potential pending puts for these returns
        IF l_status = rf.status_normal THEN
            FOR r_rec IN c_get_erm_line_id LOOP
                l_status := delete_rtn_pending_puts(i_manifest_no, r_rec.erm_line_id);
                IF l_status != rf.status_normal THEN
                    exit;
                END IF;
            END LOOP;
        END IF;   -- delete potential pending puts for these returns

        -- delete the returns for the invoice
        IF l_status = rf.status_normal THEN
            BEGIN
                DELETE 
                FROM  returns
                WHERE manifest_no   = i_manifest_no
                  AND obligation_no = i_obligation_no; 

                UPDATE manifest_dtls
                SET    manifest_dtl_status = 'OPN'
                WHERE  manifest_no   = i_manifest_no
                  AND  obligation_no = i_obligation_no; 

                DELETE 
                FROM   food_safety_outbound
                WHERE  manifest_no   = i_manifest_no
                  AND  obligation_no = i_obligation_no;

            EXCEPTION
                WHEN OTHERS THEN
                    l_status := rf.status_data_error;
                    l_msg := 'Unexpected ERROR during deletion of returns for manifest# ['
                          || i_manifest_no
                          || '] obligation# ['
                          || i_obligation_no
                          || ']';
                    pl_log.ins_msg('FATAL', l_func_name, l_msg, SQLCODE, SUBSTR(SQLERRM, 1, 500), APPLICATION_FUNC, PACKAGE_NAME);
            
            END; 
        END IF;  -- delete the returns for the invoice if normal status

        -- commit if success
        IF l_status = rf.status_normal THEN
            COMMIT;
        ELSE
            ROLLBACK;
        END IF; 

        l_msg := 'l_status at the end of delete_invoice_rtn() is ['
              || l_status
              || ']';
        pl_log.ins_msg('INFO', l_func_name, l_msg, null, null, APPLICATION_FUNC, PACKAGE_NAME);

        return l_status;

    EXCEPTION
        WHEN OTHERS THEN
            l_status := rf.status_data_error;
            l_msg := 'Unexpected ERROR during deletion of returns for manifest# ['
                  || i_manifest_no
                  || '] obligation# ['
                  || i_obligation_no
                  || ']';
            pl_log.ins_msg('FATAL', l_func_name, l_msg, SQLCODE, SUBSTR(SQLERRM, 1, 500), APPLICATION_FUNC, PACKAGE_NAME);
            ROLLBACK;
            return l_status;

    END delete_invoice_rtn;


    /************************************************************************
    --
    -- verify_mf_is_opn() - overloaded - another version with different
    --                      signature exists.
    --
    -- Description:      Verifies that the manifest status is OPN. Also
    --                   gets the manifest status, route#, and dci_ready
    --                   flag for the manifest.
    --
    -- Parameters:
    --                   i_manifest_no:     manifest#
    --                   o_mf_status:       manifest status (output)
    --                   o_route_no:        route# (output)
    --                   o_dci_ready:       "dci ready" (output)
    --
    -- Return/output:    status code indicating success or error.
    --
    -- Modification log:
    --
    -- Date         Developer     Change
    -- ------------------------------------------------------------------
    -- 27-OCT-2020  pkab6563      Initial version.
    --
    *************************************************************************/
    FUNCTION verify_mf_is_opn (
        i_manifest_no           IN  manifests.manifest_no%TYPE,
        o_mf_status             OUT manifests.manifest_status%TYPE,
        o_route_no              OUT manifests.route_no%TYPE,
        o_dci_ready             OUT manifests.sts_completed_ind%TYPE
    ) return rf.status IS

        l_func_name  CONSTANT  swms_log.procedure_name%TYPE := 'verify_mf_is_opn';
        l_status               rf.status := rf.status_normal;
        l_msg                  swms_log.msg_text%TYPE;

    BEGIN
        -- initialize the out parameters
        o_route_no  := ' ';
        o_dci_ready := 'N';
        o_mf_status := '***';

        BEGIN  -- query
            SELECT manifest_status, nvl(sts_completed_ind, 'N'), route_no
            INTO   o_mf_status, o_dci_ready, o_route_no
            FROM   manifests
            WHERE  manifest_no = i_manifest_no;

            IF o_mf_status = 'CLS' THEN
                l_status := rf.status_manifest_was_closed;
                l_msg := 'INVALID STATUS: manifest already CLOSED; manifest# ['
                      || i_manifest_no
                      || ']';
                pl_log.ins_msg('WARN', l_func_name, l_msg, null, null, APPLICATION_FUNC, PACKAGE_NAME);
            ELSIF o_mf_status = 'PAD' THEN
                l_status := rf.status_manifest_pad;
                l_msg := 'INVALID manifest STATUS: PAD; manifest# ['
                      || i_manifest_no
                      || ']';
                pl_log.ins_msg('WARN', l_func_name, l_msg, null, null, APPLICATION_FUNC, PACKAGE_NAME);
            ELSIF o_mf_status != 'OPN' THEN
                l_status := rf.status_inv_manifest;
                l_msg := 'INVALID manifest STATUS; manifest# ['
                      || i_manifest_no
                      || ']';
                pl_log.ins_msg('WARN', l_func_name, l_msg, null, null, APPLICATION_FUNC, PACKAGE_NAME);
            END IF;

        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                l_status := rf.status_man_not_found;
                l_msg := 'MANIFEST NOT FOUND; manifest# ['
                      || i_manifest_no
                      || ']';
                pl_log.ins_msg('WARN', l_func_name, l_msg, SQLCODE, SUBSTR(SQLERRM, 1, 500), APPLICATION_FUNC, PACKAGE_NAME);

            WHEN OTHERS THEN
                l_status := rf.status_data_error;
                l_msg := 'ERROR during query of manifests table for manifest# ['
                      || i_manifest_no
                      || ']';
                pl_log.ins_msg('FATAL', l_func_name, l_msg, SQLCODE, SUBSTR(SQLERRM, 1, 500), APPLICATION_FUNC, PACKAGE_NAME);
        END;  -- query

        return l_status;

    EXCEPTION
        WHEN OTHERS THEN
            l_status := rf.status_data_error;
            l_msg := 'Unexpected ERROR in verify_mf_is_opn() for manifest# ['
                  || i_manifest_no
                  || ']';
            pl_log.ins_msg('FATAL', l_func_name, l_msg, SQLCODE, SUBSTR(SQLERRM, 1, 500), APPLICATION_FUNC, PACKAGE_NAME);
            return l_status;

    END verify_mf_is_opn;

    /************************************************************************
    --
    -- verify_mf_is_opn() - overloaded - another version with different
    --                      signature exists.
    --
    -- Description:      Verifies that the manifest status is OPN.
    --
    -- Parameters:
    --                   i_manifest_no:     manifest#
    --
    -- Return/output:    status code indicating success or error.
    --
    -- Modification log:
    --
    -- Date         Developer     Change
    -- ------------------------------------------------------------------
    -- 27-OCT-2020  pkab6563      Initial version.
    --
    *************************************************************************/
    FUNCTION verify_mf_is_opn (
        i_manifest_no           IN  manifests.manifest_no%TYPE
    ) return rf.status IS

        l_func_name  CONSTANT  swms_log.procedure_name%TYPE := 'verify_mf_is_opn';
        l_status               rf.status := rf.status_normal;
        l_msg                  swms_log.msg_text%TYPE;
        l_mf_status            manifests.manifest_status%TYPE;

    BEGIN

        BEGIN  -- query
            SELECT manifest_status
            INTO   l_mf_status
            FROM   manifests
            WHERE  manifest_no = i_manifest_no;

            IF l_mf_status = 'CLS' THEN
                l_status := rf.status_manifest_was_closed;
                l_msg := 'INVALID STATUS: manifest already CLOSED; manifest# ['
                      || i_manifest_no
                      || ']';
                pl_log.ins_msg('WARN', l_func_name, l_msg, null, null, APPLICATION_FUNC, PACKAGE_NAME);
            ELSIF l_mf_status = 'PAD' THEN
                l_status := rf.status_manifest_pad;
                l_msg := 'INVALID manifest STATUS: PAD; manifest# ['
                      || i_manifest_no
                      || ']';
                pl_log.ins_msg('WARN', l_func_name, l_msg, null, null, APPLICATION_FUNC, PACKAGE_NAME);
            ELSIF l_mf_status != 'OPN' THEN
                l_status := rf.status_inv_manifest;
                l_msg := 'INVALID manifest STATUS; manifest# ['
                      || i_manifest_no
                      || ']';
                pl_log.ins_msg('WARN', l_func_name, l_msg, null, null, APPLICATION_FUNC, PACKAGE_NAME);
            END IF;

        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                l_status := rf.status_man_not_found;
                l_msg := 'MANIFEST NOT FOUND; manifest# ['
                      || i_manifest_no
                      || ']';
                pl_log.ins_msg('WARN', l_func_name, l_msg, SQLCODE, SUBSTR(SQLERRM, 1, 500), APPLICATION_FUNC, PACKAGE_NAME);

            WHEN OTHERS THEN
                l_status := rf.status_data_error;
                l_msg := 'ERROR during query of manifests table for manifest# ['
                      || i_manifest_no
                      || ']';
                pl_log.ins_msg('FATAL', l_func_name, l_msg, SQLCODE, SUBSTR(SQLERRM, 1, 500), APPLICATION_FUNC, PACKAGE_NAME);
        END;  -- query

        return l_status;

    EXCEPTION
        WHEN OTHERS THEN
            l_status := rf.status_data_error;
            l_msg := 'Unexpected ERROR in verify_mf_is_opn() for manifest# ['
                  || i_manifest_no
                  || ']';
            pl_log.ins_msg('FATAL', l_func_name, l_msg, SQLCODE, SUBSTR(SQLERRM, 1, 500), APPLICATION_FUNC, PACKAGE_NAME);
            return l_status;

    END verify_mf_is_opn;

    /**************************************************************************
    --
    -- delete_rtn_pending_puts()
    --
    -- Description:      Deletes pending puts for a given return. Logic taken
    --                   from procedure reverse_return in form rtnsdtl.fmb
    --      
    -- Parameters:       
    --                   i_manifest_no:     manifest#
    --                   i_erm_line_id:     erm_line_id for return record
    --
    -- Return/output:    status code indicating success or error.
    --
    -- Modification log:
    --
    -- Date         Developer     Change
    -- ------------------------------------------------------------------
    -- 06-NOV-2020  pkab6563      Initial version.
    -- 16-APR-2021  vkal9662      Icluded the deletion of ERD,ERM,putaways 
    --                            in l_pending_put_cnt check and the loop
    ***************************************************************************/
    FUNCTION delete_rtn_pending_puts (
        i_manifest_no           IN  manifests.manifest_no%TYPE,
        i_erm_line_id           IN  returns.erm_line_id%TYPE
    ) return rf.status IS

        l_func_name  CONSTANT  swms_log.procedure_name%TYPE := 'delete_rtn_pending_puts';
        l_status               rf.status := rf.status_normal;
        l_msg                  swms_log.msg_text%TYPE;
        l_dmg_erm_id           erm.erm_id%TYPE := 'D' || TO_CHAR(i_manifest_no);
        l_sal_erm_id           erm.erm_id%TYPE := 'S' || TO_CHAR(i_manifest_no);
        l_rtn_lm_syspars       pl_rtn_lm.trecRtnLmFlags := NULL;
        l_pending_put_cnt      PLS_INTEGER := 0;
        l_lm_status            NUMBER := 0;

        CURSOR c_get_prev_rtn_info IS
        SELECT p.rec_id, 
               NVL(l.perm, 'N') perm,
               p.pallet_id, 
               p.dest_loc, 
               p.prod_id, 
               p.cust_pref_vendor,
               p.qty, 
               p.uom, 
               p.weight
        FROM  loc l, putawaylst p
        WHERE l.logi_loc = p.dest_loc
          AND p.rec_id IN (l_dmg_erm_id, l_sal_erm_id)
          AND p.erm_line_id = i_erm_line_id
          AND NVL(p.putaway_put, 'N') = 'N';

        CURSOR c_lock_put IS
        SELECT pallet_id
        FROM   putawaylst
        WHERE  rec_id IN (l_dmg_erm_id, l_sal_erm_id)
          AND  erm_line_id = i_erm_line_id
          AND  NVL(putaway_put, 'N') = 'N'
        FOR UPDATE NOWAIT;

    BEGIN

        -- lock the pending put record
        BEGIN
            FOR locked_rec IN c_lock_put LOOP
                l_pending_put_cnt := l_pending_put_cnt + 1;
            END LOOP;
      
            l_msg := 'FOUND ['
                  || l_pending_put_cnt 
                  || '] pending puts for return. manifest# ['
                  || i_manifest_no
                  || '] i_erm_line_id ['
                  || i_erm_line_id
                  || ']';
            pl_log.ins_msg('INFO', l_func_name, l_msg, null, null, APPLICATION_FUNC, PACKAGE_NAME);

        EXCEPTION
            WHEN OTHERS THEN
                l_status := rf.status_rec_lock_by_other;
                l_msg := 'ERROR while trying to lock putawaylst record for manifest# ['
                      || i_manifest_no
                      || '] i_erm_line_id ['
                      || i_erm_line_id
                      || ']';
                pl_log.ins_msg('FATAL', l_func_name, l_msg, SQLCODE, SUBSTR(SQLERRM, 1, 500), APPLICATION_FUNC, PACKAGE_NAME);

        END;   -- lock the pending put record

        IF l_status = rf.status_normal AND l_pending_put_cnt > 0 THEN

            -- get the needed syspars
            l_rtn_lm_syspars := pl_rtn_lm.check_rtn_lm_syspars;

            FOR prev_rtn IN c_get_prev_rtn_info LOOP
                BEGIN   -- update inv
                    UPDATE inv
                    SET    qty_planned = qty_planned - prev_rtn.qty
                    WHERE  plogi_loc = prev_rtn.dest_loc
                      AND  ((prev_rtn.perm = 'Y' AND logi_loc = plogi_loc) OR
                           (prev_rtn.perm <> 'Y' AND logi_loc = prev_rtn.pallet_id))
                      AND  qty_planned - prev_rtn.qty >= 0;

                EXCEPTION
                    WHEN OTHERS THEN
                        l_status := rf.status_data_error;
                        l_msg := 'Unexpected ERROR during update of inv for return. Manifest# ['
                              || i_manifest_no
                              || '] i_erm_line_id ['
                              || i_erm_line_id
                              || '] dest_loc ['
                              || prev_rtn.dest_loc
                              || '] pallet_id ['
                              || prev_rtn.pallet_id
                              || ']';
                        pl_log.ins_msg('FATAL', l_func_name, l_msg, SQLCODE, SUBSTR(SQLERRM, 1, 500), APPLICATION_FUNC, PACKAGE_NAME);
                        exit;

                END;   -- update inv

                BEGIN   -- delete some inv recs
                    DELETE 
                    FROM   inv
                    WHERE  plogi_loc = prev_rtn.dest_loc
                      AND  plogi_loc <> logi_loc
                      AND  qoh = 0
                      AND  qty_planned = 0
                      AND  qty_alloc = 0;

                EXCEPTION
                    WHEN OTHERS THEN
                        l_status := rf.status_data_error;
                        l_msg := 'Unexpected ERROR while trying to delete zero qty in row for dest_loc. Manifest# ['
                              || i_manifest_no
                              || '] i_erm_line_id ['
                              || i_erm_line_id
                              || '] dest_loc ['
                              || prev_rtn.dest_loc
                              || ']';
                        pl_log.ins_msg('FATAL', l_func_name, l_msg, SQLCODE, SUBSTR(SQLERRM, 1, 500), APPLICATION_FUNC, PACKAGE_NAME);
                        exit;
                END;   -- delete some inv recs

                -- Get rid of LM batch if LM is used and batch is empty
                IF SUBSTR(prev_rtn.rec_id, 1, 1) = 'S' THEN
                    IF l_rtn_lm_syspars.szLbrMgmtFlag = 'Y' AND l_rtn_lm_syspars.szCrtBatchFlag = 'Y' THEN
                        pl_rtn_lm.unload_pallet_batch(prev_rtn.pallet_id, 1, l_msg, l_lm_status);
                        IF l_lm_status = 0 THEN
                            l_lm_status := pl_rtn_lm.delete_pallet_batch(prev_rtn.pallet_id, 1);
                            IF l_lm_status NOT IN (1403, 100, 0) THEN
                                l_status := rf.status_data_error;
                                l_msg := 'ERROR during deletion of LM batch for return. Manifest# ['
                                      || i_manifest_no
                                      || '] i_erm_line_id ['
                                      || i_erm_line_id
                                      || '] dest_loc ['
                                      || prev_rtn.dest_loc
                                      || '] pallet_id ['
                                      || prev_rtn.pallet_id
                                      || ']';
                                pl_log.ins_msg('FATAL', l_func_name, l_msg, SQLCODE, SUBSTR(SQLERRM, 1, 500), APPLICATION_FUNC, PACKAGE_NAME);
                                exit;
                            END IF;   -- l_lm_status NOT IN (1403, 100, 0)
                        ELSIF l_lm_status NOT IN (1403, 100) THEN
                            l_status := rf.status_data_error;
                            l_msg := 'ERROR during unloading of LM batch for return. Manifest# ['
                                  || i_manifest_no
                                  || '] i_erm_line_id ['
                                  || i_erm_line_id
                                  || '] dest_loc ['
                                  || prev_rtn.dest_loc
                                  || '] pallet_id ['
                                  || prev_rtn.pallet_id
                                  || ']';
                            pl_log.ins_msg('FATAL', l_func_name, l_msg, SQLCODE, SUBSTR(SQLERRM, 1, 500), APPLICATION_FUNC, PACKAGE_NAME);
                            exit;
                        END IF;   -- check for l_lm_status = 0 
                    END IF;   -- checking the syspars
                END IF;   -- checking for salable return
     
        IF l_status = rf.status_normal THEN
            -- delete erd rec
            BEGIN
                DELETE 
                FROM   erd
                WHERE  erm_id IN (l_dmg_erm_id, l_sal_erm_id)
                  AND  erm_line_id = i_erm_line_id;

            EXCEPTION
                WHEN OTHERS THEN
                    l_status := rf.status_data_error;
                    l_msg := 'Unexpected ERROR during deletion of erd for return. Manifest# ['
                          || i_manifest_no
                          || '] i_erm_line_id ['
                          || i_erm_line_id
                          || ']';
                    pl_log.ins_msg('FATAL', l_func_name, l_msg, SQLCODE, SUBSTR(SQLERRM, 1, 500), APPLICATION_FUNC, PACKAGE_NAME);
            END;   -- delete erd rec
        END IF;   -- if l_status is normal

        IF l_status = rf.status_normal THEN
            -- delete erm rec if applicable
            BEGIN
                DELETE 
                FROM   erm m
                WHERE  m.erm_id = l_sal_erm_id
                  AND  NOT EXISTS (SELECT 1
                                   FROM   erd
                                   WHERE  erm_id = l_sal_erm_id);

                DELETE 
                FROM   erm m
                WHERE  m.erm_id = l_dmg_erm_id
                  AND  NOT EXISTS (SELECT 1
                                   FROM   erd
                                   WHERE  erm_id = l_dmg_erm_id);
            EXCEPTION
                WHEN OTHERS THEN
                    l_status := rf.status_data_error;
                    l_msg := 'Unexpected ERROR during deletion of erm for return. Manifest# ['
                          || i_manifest_no
                          || ']';
                    pl_log.ins_msg('FATAL', l_func_name, l_msg, SQLCODE, SUBSTR(SQLERRM, 1, 500), APPLICATION_FUNC, PACKAGE_NAME);
            END;   -- delete erm rec if applicable
        END IF;   -- if l_status is normal

        IF l_status = rf.status_normal THEN
            -- delete put rec  	   
            BEGIN
                DELETE 
                FROM   putawaylst
                WHERE  rec_id IN (l_dmg_erm_id, l_sal_erm_id)
                  AND  erm_line_id = i_erm_line_id;

            EXCEPTION
                WHEN OTHERS THEN
                    l_status := rf.status_data_error;
                    l_msg := 'Unexpected ERROR during deletion of pending puts for return. Manifest# ['
                          || i_manifest_no
                          || '] i_erm_line_id ['
                          || i_erm_line_id
                          || ']';
                    pl_log.ins_msg('FATAL', l_func_name, l_msg, SQLCODE, SUBSTR(SQLERRM, 1, 500), APPLICATION_FUNC, PACKAGE_NAME);
            END;   -- delete put rec
        END IF;   -- l_status = rf.status_normal 
        
        END LOOP;
     END IF;   -- l_status = rf.status_normal AND l_pending_put_cnt > 0


        return l_status;

    EXCEPTION
        WHEN OTHERS THEN
            l_status := rf.status_data_error;
            l_msg := 'Unexpected ERROR in delete_rtn_pending_puts(). Manifest# ['
                  || i_manifest_no
                  || '] i_erm_line_id ['
                  || i_erm_line_id
                  || ']';
            pl_log.ins_msg('FATAL', l_func_name, l_msg, SQLCODE, SUBSTR(SQLERRM, 1, 500), APPLICATION_FUNC, PACKAGE_NAME);
            ROLLBACK;
            return l_status;

    END delete_rtn_pending_puts;

    /************************************************************************
    --
    -- verify_mf_is_not_cls() 
    --                      
    --
    -- Description:      Verifies that the manifest status is not CLS.
    --
    -- Parameters:       i_manifest_no:     manifest#
    --                   o_mf_status:       manifest status (out)
    --                   o_route_no:        route# (out)
    --
    -- Return/output:    status code indicating success or error.
    --
    -- Modification log:
    --
    -- Date         Developer     Change
    -- ------------------------------------------------------------------
    -- 13-NOV-2020  pkab6563      Initial version.
    --
    *************************************************************************/
    FUNCTION verify_mf_is_not_cls (
        i_manifest_no           IN  manifests.manifest_no%TYPE,
        o_mf_status             OUT manifests.manifest_status%TYPE,
        o_route_no              OUT manifests.route_no%TYPE
    ) return rf.status IS

        l_func_name  CONSTANT  swms_log.procedure_name%TYPE := 'verify_mf_is_not_cls';
        l_status               rf.status := rf.status_normal;
        l_msg                  swms_log.msg_text%TYPE;

    BEGIN

        -- initialize the out parameters
        o_mf_status := '***';
        o_route_no  := ' ';

        BEGIN  -- query
            SELECT manifest_status,
                   route_no
            INTO   o_mf_status,
                   o_route_no
            FROM   manifests
            WHERE  manifest_no = i_manifest_no;

            IF o_mf_status = 'CLS' THEN
                l_status := rf.status_manifest_was_closed;
                l_msg := 'INVALID STATUS: manifest already CLOSED; manifest# ['
                      || i_manifest_no
                      || ']';
                pl_log.ins_msg('WARN', l_func_name, l_msg, null, null, APPLICATION_FUNC, PACKAGE_NAME);
            END IF;

        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                l_status := rf.status_man_not_found;
                l_msg := 'MANIFEST NOT FOUND; manifest# ['
                      || i_manifest_no
                      || ']';
                pl_log.ins_msg('WARN', l_func_name, l_msg, SQLCODE, SUBSTR(SQLERRM, 1, 500), APPLICATION_FUNC, PACKAGE_NAME);

            WHEN OTHERS THEN
                l_status := rf.status_data_error;
                l_msg := 'ERROR during query of manifests table for manifest# ['
                      || i_manifest_no
                      || ']';
                pl_log.ins_msg('FATAL', l_func_name, l_msg, SQLCODE, SUBSTR(SQLERRM, 1, 500), APPLICATION_FUNC, PACKAGE_NAME);
        END;  -- query

        return l_status;

    EXCEPTION
        WHEN OTHERS THEN
            l_status := rf.status_data_error;
            l_msg := 'Unexpected ERROR in verify_mf_is_not_cls() for manifest# ['
                  || i_manifest_no
                  || ']';
            pl_log.ins_msg('FATAL', l_func_name, l_msg, SQLCODE, SUBSTR(SQLERRM, 1, 500), APPLICATION_FUNC, PACKAGE_NAME);
            return l_status;

    END verify_mf_is_not_cls;

    /**************************************************************************
    --
    -- delete_mf_collected_data()
    --
    -- Description:      Deletes the collected weights and temps for the
    --                   manifest returns.
    --                   logic taken from procedure delete_data_collections
    --                   in rtnscls.fmb.
    --                   
    --      
    -- SPECIAL NOTE:     There is no COMMIT in this function. The caller
    --                   must COMMIT if the return code is success (normal).
    --
    -- Parameters:       
    --                   i_manifest_no:     manifest#
    --
    -- Return/output:    status code indicating success or error.
    --
    -- Modification log:
    --
    -- Date         Developer     Change
    -- ------------------------------------------------------------------
    -- 11-NOV-2020  pkab6563      Initial version.
    --
    ***************************************************************************/
    FUNCTION delete_mf_collected_data (
        i_manifest_no           IN  manifests.manifest_no%TYPE
    ) return rf.status IS

        l_func_name  CONSTANT  swms_log.procedure_name%TYPE := 'delete_mf_collected_data';
        l_status               rf.status := rf.status_normal;
        l_msg                  swms_log.msg_text%TYPE;

    BEGIN
        DELETE
        FROM   tmp_rtn_weights
        WHERE  manifest_no = i_manifest_no;

        DELETE
        FROM   tmp_rtn_temps
        WHERE  manifest_no = i_manifest_no;

        return l_status;

    EXCEPTION
        WHEN OTHERS THEN
            l_status := rf.status_data_error;
            l_msg := 'Unexpected ERROR in delete_mf_collected_data(). Manifest# ['
                  || i_manifest_no
                  || ']';
            pl_log.ins_msg('FATAL', l_func_name, l_msg, SQLCODE, SUBSTR(SQLERRM, 1, 500), APPLICATION_FUNC, PACKAGE_NAME);
            ROLLBACK;
            return l_status;

    END delete_mf_collected_data;

    /**************************************************************************
    --
    -- insert_float_hist()
    --
    -- Description:      Inserts rows into float_hist for manifest returns
    --                   where the reason code is T30 or W45.
    --                   logic taken from procedure insert_into_float_hist
    --                   in rtnscls.fmb.
    --      
    -- Parameters:       
    --                   i_manifest_no:     manifest#
    --
    -- Return/output:    status code indicating success or error.
    --
    -- Modification log:
    --
    -- Date         Developer     Change
    -- ------------------------------------------------------------------
    -- 11-NOV-2020  pkab6563      Initial version.
    --
    ***************************************************************************/

    FUNCTION insert_float_hist (
        i_manifest_no  IN  manifests.manifest_no%TYPE
    ) return rf.status IS

        l_func_name  CONSTANT  swms_log.procedure_name%TYPE := 'insert_float_hist';
        l_status               rf.status := rf.status_normal;
        l_msg                  swms_log.msg_text%TYPE;
        l_order_line_id        PLS_INTEGER;

        CURSOR c_rtn_info IS
        SELECT rtn.prod_id, 
               rtn.cust_pref_vendor,
               rtn.obligation_no,
               rtn.returned_qty,
               rtn.returned_split_cd,
               rtn.route_no,
               mf.route_no mf_route_no
        FROM   returns rtn,
               manifests mf
        WHERE  rtn.manifest_no = i_manifest_no 
          AND  rtn.return_reason_cd IN ('T30', 'W45')
          AND  mf.manifest_no = rtn.manifest_no;

    BEGIN

        l_order_line_id := 900;  -- initial value
        FOR r_rtn IN c_rtn_info LOOP
            IF r_rtn.obligation_no IS NOT NULL THEN
                BEGIN
                    INSERT INTO float_hist
                                  (prod_id, 
                                   cust_pref_vendor,
                                   order_id, 
                                   order_line_id,
                                   qty_alloc, 
                                   route_no, 
                                   uom,
                                   add_date, 
                                   add_user)
                           VALUES
                                  (r_rtn.prod_id,
                                   r_rtn.cust_pref_vendor,
                                   nvl(r_rtn.obligation_no, '0000'),
                                   l_order_line_id,
                                   nvl(r_rtn.returned_qty, 0),
                                   nvl(r_rtn.route_no, r_rtn.mf_route_no),
                                   to_number(nvl(r_rtn.returned_split_cd, '0')),
                                   sysdate,
                                   replace(user, 'OPS$'));
             
                EXCEPTION
                    WHEN DUP_VAL_ON_INDEX THEN
                        NULL;
                    WHEN OTHERS THEN
                        l_msg := 'Unexpected ERROR in insert_float_hist() during insertion attempt. Manifest# ['
                              || i_manifest_no
                              || '] prod_id ['
                              || r_rtn.prod_id
                              || '] cpv ['
                              || r_rtn.cust_pref_vendor
                              || '] obligation# ['
                              || r_rtn.obligation_no
                              || '] l_order_line_id ['
                              || l_order_line_id
                              || '] qty ['
                              || r_rtn.returned_qty
                              || '] route# ['
                              || r_rtn.route_no
                              || '] mf_route_no ['
                              || r_rtn.mf_route_no
                              || '] split cd ['
                              || r_rtn.returned_split_cd
                              || ']'; 
                        pl_log.ins_msg('WARN', l_func_name, l_msg, SQLCODE, SUBSTR(SQLERRM, 1, 500), APPLICATION_FUNC, PACKAGE_NAME);
                END;   -- insert into float_hist

                l_order_line_id := l_order_line_id + 1;
            END IF;   -- if obligation# is not null 

            IF l_order_line_id > 999 THEN
                l_msg := 'l_order_line_id is ['
                      || l_order_line_id
                      || ']. It is > 999; exiting float_hist insert loop';
                pl_log.ins_msg('WARN', l_func_name, l_msg, null, null, APPLICATION_FUNC, PACKAGE_NAME);
                exit;
            END IF;
        END LOOP;

        return l_status; -- should be rf.status_normal

    EXCEPTION
        WHEN OTHERS THEN
            l_msg := 'Unexpected ERROR in insert_float_hist(). Manifest# ['
                  || i_manifest_no
                  || ']';
            pl_log.ins_msg('FATAL', l_func_name, l_msg, SQLCODE, SUBSTR(SQLERRM, 1, 500), APPLICATION_FUNC, PACKAGE_NAME);
            return l_status;

    END insert_float_hist;

    /************************************************************************
    --
    -- manifest_close()
    --
    -- Description:        Called by the RF client to close a manifest.
    --
    --                     Calls mf_close() for the business logic.
    --
    -- Parameters:         i_rf_log_init_rec: RF-related data. Not
    --                     related to business logic.
    --
    --                     i_manifest_no: manifest#
    --
    --                     i_accessory_override: Y/N
    --                         N: inbound accessory tracking will be
    --                            performed in the business logic
    --                            if applicable.
    --                         Y: bypass inbound accessory tracking.
    --                       
    --
    -- Return/output:      status code indicating success or error.
    --
    -- Modification log:
    --
    -- Date         Developer     Change
    -- ------------------------------------------------------------------
    -- 18-NOV-2020  pkab6563      Initial version.
    --
    *************************************************************************/
    FUNCTION manifest_close (
        i_rf_log_init_rec       IN  rf_log_init_record,
        i_manifest_no           IN  manifests.manifest_no%TYPE,
        i_accessory_override    IN  VARCHAR2
    ) return rf.status IS

        l_func_name  CONSTANT  swms_log.procedure_name%TYPE := 'manifest_close';
        l_status               rf.status := rf.status_normal;
        l_msg                  swms_log.msg_text%TYPE;

    BEGIN

        -- Call rf.initialize(). cannot procede if return status is not successful.
        l_status := rf.initialize(i_rf_log_init_rec);

        -- Log the input received from the RF client
        l_msg := 'Starting '
              || l_func_name
              || '. manifest# ['
              || i_manifest_no
              || '] i_accessory_override is ['
              || i_accessory_override
              || ']';
        pl_log.ins_msg('INFO', l_func_name, l_msg, null, null, APPLICATION_FUNC, PACKAGE_NAME);

        -- perform the business logic
        IF l_status = rf.status_normal THEN
            l_status := mf_close(i_manifest_no, i_accessory_override);
        END IF;

        l_msg := 'l_status at the end of manifest_close() is ['
              || l_status
              || ']';
        pl_log.ins_msg('INFO', l_func_name, l_msg, null, null, APPLICATION_FUNC, PACKAGE_NAME);

        rf.complete(l_status);
        return l_status;

    EXCEPTION
        WHEN OTHERS THEN
            l_msg := 'ERROR in manifest_close() for manifest# ['
                  || i_manifest_no
                  || ']';
            pl_log.ins_msg('FATAL', l_func_name, l_msg, SQLCODE, SUBSTR(SQLERRM, 1, 500), APPLICATION_FUNC, PACKAGE_NAME);
            rf.logexception();
            RAISE;

    END manifest_close;

    /**************************************************************************
    --
    -- mf_close()
    --
    -- Description:      Closes the passed in manifest.
    --                   Logic taken from procedure manifest_close in 
    --                   form rtnscls.fmb.
    --      
    -- Parameters:       i_manifest_no:         manifest#
    --                   i_accessory_override:  Y/N - for accessory 
    --                         tracking override.
    --                         Y = bypass tracking
    --                         N = do not bypass tracking
    --
    -- Return/output:    status code indicating success or error.
    --
    -- Modification log:
    --
    -- Date         Developer     Change
    -- ------------------------------------------------------------------
    -- 12-NOV-2020  pkab6563      Initial version.
    --
    ***************************************************************************/
    FUNCTION mf_close (
        i_manifest_no           IN  manifests.manifest_no%TYPE,
        i_accessory_override    IN  VARCHAR2
    ) return rf.status IS

        l_func_name  CONSTANT  swms_log.procedure_name%TYPE := 'mf_close';
        l_status               rf.status := rf.status_normal;
        l_msg                  swms_log.msg_text%TYPE;
        l_mf_no                manifests.manifest_no%TYPE;
        l_mf_status            manifests.manifest_status%TYPE;
        l_route_no             manifests.route_no%TYPE;
        l_row_locked           EXCEPTION;
        l_accessory_override   VARCHAR2(1);
        PRAGMA EXCEPTION_INIT (l_row_locked, -54);
        l_pod_enable           VARCHAR2(1);
        
        l_sal_rec_id	       putawaylst.rec_id%TYPE := 'S' || TO_CHAR(i_manifest_no);
        l_xdock_rec_id	       putawaylst.rec_id%TYPE := 'X' || TO_CHAR(i_manifest_no);
        l_count_return         PLS_INTEGER := 0;
        l_continue_mfc         BOOLEAN;
        l_return_exist	       BOOLEAN;
        l_enable_acc_trk       VARCHAR2(1);
        l_count_outbound       PLS_INTEGER := 0;
        l_count_inbound        PLS_INTEGER := 0;
        l_confirm              VARCHAR2(1);
        l_count_rtn_credit     PLS_INTEGER := 0;
        l_count_rtn_reverse    PLS_INTEGER := 0;
        l_count_put            PLS_INTEGER := 0;
        l_count_erd            PLS_INTEGER := 0;
        l_mfc_cmt              TRANS.CMT%TYPE;
        l_upload_time          DATE;
        l_count_food_safety    PLS_INTEGER := 0;

        CURSOR c_mf_rtn IS
        SELECT status
        FROM   returns
        WHERE  manifest_no = i_manifest_no
        FOR UPDATE NOWAIT;

    BEGIN

        -- ensure manifest is not already closed
        l_status := verify_mf_is_not_cls(i_manifest_no, l_mf_status, l_route_no);

        -- lock the manifest
        IF l_status = rf.status_normal THEN
            BEGIN
                SELECT manifest_no
                  INTO l_mf_no
                FROM   manifests
                WHERE  manifest_no = i_manifest_no
                FOR UPDATE NOWAIT;

            EXCEPTION
                WHEN OTHERS THEN
                    l_status := rf.status_rec_lock_by_other;
                    l_msg := 'ERROR while trying to lock manifest record for manifest# ['
                          || i_manifest_no
                          || ']';
                    pl_log.ins_msg('FATAL', l_func_name, l_msg, SQLCODE, SUBSTR(SQLERRM, 1, 500), APPLICATION_FUNC, PACKAGE_NAME);

            END;
        END IF;   -- lock the manifest

        l_pod_enable := pl_common.f_get_syspar('POD_ENABLE', 'N');

        -- ensure food safety data has been collected if applicable
        IF l_status = rf.status_normal THEN
            SELECT count(*) 
            INTO   l_count_food_safety
            FROM   food_safety_outbound 
            WHERE  manifest_no = i_manifest_no
              AND  (temp_collected IS NULL OR time_collected IS NULL);

            IF l_count_food_safety > 0 THEN
                l_status := rf.status_need_food_safety_temps;
                l_msg := 'FOOD SAFETY data collection needed for manifest# ['
                      || i_manifest_no
                      || ']';
                pl_log.ins_msg('WARN', l_func_name, l_msg, null, null, APPLICATION_FUNC, PACKAGE_NAME);
            END IF;
        END IF;   -- food safety

        -- ensure the status is CMP for all returns for this manifest
        IF l_status = rf.status_normal THEN
            SELECT count(*) 
            INTO   l_count_return
	    FROM   returns 
	    WHERE  manifest_no = i_manifest_no
	      AND  nvl(status, 'X') != 'CMP';

            IF l_count_return > 0 THEN
                l_status := rf.status_rtn_not_cmp;
                l_msg := 'Manifest has some returns with status not CMP. Cannot close manifest. Manifest# ['
                      || i_manifest_no
                      || ']';
                pl_log.ins_msg('WARN', l_func_name, l_msg, null, null, APPLICATION_FUNC, PACKAGE_NAME);
            END IF;
        END IF; -- returns status must be CMP

        -- accessory tracking
        l_accessory_override := upper(nvl(i_accessory_override, 'N'));
        IF l_status = rf.status_normal AND l_accessory_override != 'Y' THEN
            l_enable_acc_trk := pl_common.f_get_syspar('ENABLE_TRK_ACCESSORY_TRACK', 'N');

            IF l_enable_acc_trk = 'Y' THEN
                BEGIN
                    SELECT NVL(sum(NVL(inbound_count, 0)), 0) 
                    INTO   l_count_inbound
                    FROM   v_truck_accessory 
                    WHERE  manifest_no = i_manifest_no;

                    SELECT NVL(sum(NVL(loader_count, 0)), 0) 
                    INTO   l_count_outbound
                    FROM   v_truck_accessory
                    WHERE  manifest_no = i_manifest_no;

                -- If there was some outbound tracking done, then inbound tracking is needed.
                IF (l_count_outbound != 0) AND (l_count_inbound = 0) THEN
                    l_status := rf.status_track_truck_accessory;
                    l_msg := 'Inbound accessory tracking not done for manifest# ['
                          || i_manifest_no
                          || ']';
                    pl_log.ins_msg('WARN', l_func_name, l_msg, null, null, APPLICATION_FUNC, PACKAGE_NAME);
                END IF;

                EXCEPTION
                    WHEN NO_DATA_FOUND THEN
                        null;

                    WHEN OTHERS THEN
                        l_status := rf.status_data_error;
                        l_msg := 'Unexpected ERROR during accessory tracking query for manifest# ['
                              || i_manifest_no
                              || ']';
                        pl_log.ins_msg('FATAL', l_func_name, l_msg, SQLCODE, SUBSTR(SQLERRM, 1, 500), APPLICATION_FUNC, PACKAGE_NAME);
                END;
            END IF;   -- checking l_enable_acc_trk flag

        END IF;   -- accessory tracking

        -- update manifest returns status
        IF l_status = rf.status_normal THEN
            l_count_return := 0;
            SELECT COUNT(*)
            INTO   l_count_return
            FROM   returns
            WHERE  manifest_no = i_manifest_no;

            IF l_count_return > 0 THEN
                BEGIN
                    FOR r_rtn IN c_mf_rtn LOOP
                        UPDATE returns
                        SET    status = 'CLS'
                        WHERE CURRENT OF c_mf_rtn;
                    END LOOP;

                EXCEPTION
                    WHEN l_row_locked THEN
                        l_status := rf.status_rec_lock_by_other;
                        l_msg := 'ERROR while trying to lock manifest returns for update of status; manifest# ['
                              || i_manifest_no
                              || ']';
                        pl_log.ins_msg('FATAL', l_func_name, l_msg, SQLCODE, SUBSTR(SQLERRM, 1, 500), APPLICATION_FUNC, PACKAGE_NAME);
                        ROLLBACK;

                    WHEN OTHERS THEN
                        l_status := rf.status_data_error;
                        l_msg := 'Unexpected ERROR while trying to update returns status for manifest# ['
                              || i_manifest_no
                              || ']';
                        pl_log.ins_msg('FATAL', l_func_name, l_msg, SQLCODE, SUBSTR(SQLERRM, 1, 500), APPLICATION_FUNC, PACKAGE_NAME);
                        ROLLBACK;
                END;   

                IF l_status = rf.status_normal THEN
                    BEGIN

                        -- Count for MFC comment
		         
                        select count(*) 
                        into l_count_rtn_credit
                        from returns r, reason_cds c
                        where c.reason_cd_type = 'RTN'
                        and   c.reason_cd = r.return_reason_cd
                        and   nvl(r.pod_rtn_ind, 'A') not in ('U', 'D')
                        and   c.reason_group not in ('OVR', 'OVI')
                        and   r.manifest_no = i_manifest_no;

                        select count(*) 
                        into l_count_rtn_reverse
                        from returns r, reason_cds c
                        where c.reason_cd_type = 'RTN'
                        and   c.reason_cd = r.return_reason_cd
                        and   nvl(r.pod_rtn_ind, 'A') IN ('U', 'D')
                        and   c.reason_group not in ('OVR', 'OVI')
                        and   r.manifest_no = i_manifest_no;   

                        select count(*)
                        into l_count_put
                        from putawaylst
                        where substr(rec_id, 1, 1) in ('D','S')
                        and   substr(rec_id, 2) = to_char(i_manifest_no);
     
                        select count(*)
                        into l_count_erd
                        from erd
                        where substr(erm_id,1,1) in ('D','S')
                        and   substr(erm_id,2) = to_char(i_manifest_no);
            
                        l_mfc_cmt := 'Credits:' || to_char(l_count_rtn_credit) || ' Reverse Credit:' || to_char(l_count_rtn_reverse) ||
                                     ' PUTTasks:' || to_char(l_count_put) || ' POLineDtl:' || to_char(l_count_erd);

                        -- delete collected data
                        l_status := delete_mf_collected_data(i_manifest_no);

                        -- delete confirmed puts
                        IF l_status = rf.status_normal THEN
                            BEGIN
                                DELETE
                                FROM   putawaylst
                                WHERE  rec_id in (l_xdock_rec_id, l_sal_rec_id) -- jira 3400 xdock returns process
                                  AND  putaway_put = 'Y';

                            EXCEPTION
                            WHEN OTHERS THEN
                                l_status := rf.status_data_error;
                                l_msg := 'Unexpected ERROR during deletion of confirmed puts for manifest# ['
                                      || i_manifest_no
                                      || ']';
                                pl_log.ins_msg('FATAL', l_func_name, l_msg, SQLCODE, SUBSTR(SQLERRM, 1, 500), APPLICATION_FUNC, PACKAGE_NAME);
                                ROLLBACK;

                            END;  
                        END IF;   -- delete confirmed puts if status is normal

                        IF l_status = rf.status_normal THEN
                            l_status := insert_float_hist(i_manifest_no);
                            pl_rtn_dtls.P_Dlt_Damaged_Putaway_ERMD(i_manifest_no);
                        END IF;


                        l_status := mf_cls_process_returns(i_manifest_no, l_pod_enable, l_mf_status);


                    EXCEPTION
                        WHEN OTHERS THEN
                            l_status := rf.status_data_error;
                            l_msg := 'Unexpected ERROR while processing returns for manifest# ['
                                  || i_manifest_no
                                  || ']';
                            pl_log.ins_msg('FATAL', l_func_name, l_msg, SQLCODE, SUBSTR(SQLERRM, 1, 500), APPLICATION_FUNC, PACKAGE_NAME);

                    END;
                END IF;   -- if l_status = rf.status_normal after updating returns status to CLS
            ELSE
                l_mfc_cmt := 'No Returns';             
            END IF;   -- checking l_count_return > 0
        END IF;   -- l_status = rf.status_normal


        IF l_status = rf.status_normal THEN
            IF l_mf_status = 'PAD' THEN -- SWMS created this manifest number so do not send RTN to ERP
                l_upload_time := null;
            ELSE
                l_upload_time := TO_DATE('01-JAN-1980','DD-MON-YYYY');
            END IF;   -- checking manifest status

            -- changes as per Jira 3323 if pod enabled create stc even if there are no returns for the manifest
            
              
              IF nvl(l_mf_status,'X') <> 'PAD' THEN
              pl_log.ins_msg('INFO', l_func_name, 'before create_stc_for_pod call', SQLCODE, SUBSTR(SQLERRM, 1, 500), APPLICATION_FUNC, PACKAGE_NAME);
              
                   l_status := create_stc_for_pod(i_manifest_no);
              END IF;
       
           dbms_output.put_line('create_stc_for_pod status'||l_status);

            IF l_status = rf.status_normal THEN
                BEGIN
                    -- insert MFC
                    INSERT INTO TRANS
                        (TRANS_ID, TRANS_TYPE, TRANS_DATE, batch_no, ORDER_ID,
                         REC_ID, USER_ID, CMT, UPLOAD_TIME, ROUTE_NO)
                    VALUES
                        (TRANS_ID_SEQ.NEXTVAL, 'MFC', SYSDATE, 99, to_char(i_manifest_no),
                         to_char(i_manifest_no),   USER,   l_mfc_cmt,  l_upload_time, l_route_no);

                    -- update manifest status
                    UPDATE manifests
                    set manifest_status = 'CLS'
                    WHERE manifest_no = i_manifest_no;

                EXCEPTION
                    WHEN OTHERS THEN
                        l_status := rf.status_data_error;
                        l_msg := 'Unexpected ERROR while inserting MFC transaction for manifest# ['
                              || i_manifest_no
                              || ']';
                        pl_log.ins_msg('FATAL', l_func_name, l_msg, SQLCODE, SUBSTR(SQLERRM, 1, 500), APPLICATION_FUNC, PACKAGE_NAME);
                        ROLLBACK;

                END;   -- insert MFC and update manifest status
            END IF;   -- if l_status = rf.status_normal
        END IF;   -- if l_status = rf.status_normal

        IF l_status = rf.status_normal THEN
            COMMIT;
            l_msg := 'Manifest close successful for manifest# ['
                  || i_manifest_no
                  || ']';
            pl_log.ins_msg('INFO', l_func_name, l_msg, null, null, APPLICATION_FUNC, PACKAGE_NAME);


            begin
               pl_rtn_xdock_interface.Populate_mfc_rtns_out(i_manifest_no);
            end;

        ELSE
            ROLLBACK;
            l_msg := 'Manifest close FAILED for manifest# ['
                  || i_manifest_no
                  || ']';
            pl_log.ins_msg('WARN', l_func_name, l_msg, null, null, APPLICATION_FUNC, PACKAGE_NAME);
        END IF;

        return l_status;

    EXCEPTION
        WHEN OTHERS THEN
            l_status := rf.status_data_error;
            l_msg := 'Unexpected ERROR in mf_close() for manifest# ['
                  || i_manifest_no
                  || ']';
            pl_log.ins_msg('FATAL', l_func_name, l_msg, SQLCODE, SUBSTR(SQLERRM, 1, 500), APPLICATION_FUNC, PACKAGE_NAME);
            ROLLBACK;
            return l_status;

    END mf_close;

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
    -- 13-NOV-2020  pkab6563      Initial version.
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
        l_xdock_cnt            NUMBER:= 0;



        CURSOR c_stop_records IS
        select distinct a.manifest_no,a.stop_no,a.customer_id cust_id,nvl(a.pod_flag,'N') pod_flag, b.route_no
        from manifest_stops a ,  manifests b
        where a.manifest_no = i_manifest_no
        and a.manifest_no   = b.manifest_no
        order by a.manifest_no,a.stop_no,a.customer_id;

    BEGIN
    
       pl_log.ins_msg('INFO', l_func_name, 'Step 1', SQLCODE, SUBSTR(SQLERRM, 1, 500), APPLICATION_FUNC, PACKAGE_NAME);
       
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

                 	SELECT count(*)
		            	INTO l_xdock_cnt
                  FROM Returns
                  WHERE stop_no = r_available.stop_no
			            AND xdock_ind ='X';

                IF  l_count_stc > 0 or l_xdock_cnt>0 THEN
                    NULL;
                ELSE 
                
                  pl_log.ins_msg('INFO', l_func_name, 'before trans insertion', SQLCODE, SUBSTR(SQLERRM, 1, 500), APPLICATION_FUNC, PACKAGE_NAME);

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
                               '99',
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
                        pl_log.ins_msg('INFO', l_func_name, l_msg, null, null, APPLICATION_FUNC, PACKAGE_NAME);

                    EXCEPTION
                        WHEN OTHERS THEN
                            l_status := rf.status_data_error;
                            l_msg := 'Insert STC into Trans Failed for manifest# ['
                                  || i_manifest_no
                                  || ']';
                            pl_log.ins_msg('FATAL', l_func_name, l_msg, SQLCODE, SUBSTR(SQLERRM, 1, 500), APPLICATION_FUNC, PACKAGE_NAME);
					 
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
            pl_log.ins_msg('FATAL', l_func_name, l_msg, SQLCODE, SUBSTR(SQLERRM, 1, 500), APPLICATION_FUNC, PACKAGE_NAME);
            return l_status;

    END create_stc_for_pod;

    /**************************************************************************
    --
    -- insert_cc_tasks()
    --
    -- Description:      Inserts CC tasks for given return.
    --                   Logic taken from procedure insert_cc_tasks in 
    --                   form rtnscls.fmb.
    --      
    -- Parameters:       
    --
    -- Return/output:    status code indicating success or error.
    --
    -- Modification log:
    --
    -- Date         Developer     Change
    -- ------------------------------------------------------------------
    -- 16-NOV-2020  pkab6563      Initial version.
    --
    ***************************************************************************/
    FUNCTION insert_cc_tasks (
        rtn_prod_id         returns.prod_id%TYPE,
        rtn_cpv             returns.cust_pref_vendor%TYPE,
        rtn_reason_grp      reason_cds.reason_group%TYPE,
        rtn_reason          returns.return_reason_cd%TYPE,
        rtn_uom             NUMBER,
        rtn_qty             returns.returned_qty%TYPE,
        i_reason            reason_cds.reason_cd%TYPE
    ) return rf.status IS

        l_func_name  CONSTANT     swms_log.procedure_name%TYPE := 'insert_cc_tasks';
        l_status                  rf.status := rf.status_normal;
        l_msg                     swms_log.msg_text%TYPE;
        cc_gen_exc_reserve_flag   VARCHAR2(1);
        gen_cc                    VARCHAR2(1);
        l_pallet_id               putawaylst.pallet_id%TYPE := null;
        l_prod_id                 returns.prod_id%TYPE;
        l_reason                  reason_cds.reason_cd%TYPE;


  v_reason_code		VARCHAR2(3);
  v_home_slot		VARCHAR2(10);
  v_batch_no		NUMBER(10);
  has_home		VARCHAR2(1) := 'N';
  v_last_ship_slot	VARCHAR2(10) := NULL;
  v_inv_exist		VARCHAR2(1) := 'N';
  v_pallet_id		cc.logi_loc%type := NULL;  --DN#11231 LPN-18 changes acpppp
  v_pallet_exist	VARCHAR2(10) := 'N';
  v_rc			VARCHAR2(3);
  v_cc_reason		VARCHAR2(3);
  v_zone_id		VARCHAR2(5) := NULL;	-- DN#10190 prplhj
  v_pallet_type		VARCHAR2(3) := NULL;    -- DN#10269 prplhj
  iStatus		NUMBER := 0;
  sIndLoc		loc.logi_loc%TYPE := NULL;
  -- D#10448 prplhj: Added CC for rank > 1 slot also
  CURSOR cc_tasks(r_prod_id VARCHAR2, r_cpv VARCHAR2,r_home_slot VARCHAR2) IS
    SELECT i.logi_loc, i.plogi_loc
      FROM  inv i
      WHERE i.prod_id = r_prod_id
      AND   i.plogi_loc NOT IN (SELECT z.induction_loc		-- WAI change
                                FROM zone z, lzone lz
                                WHERE z.zone_id = lz.zone_id
                                AND   z.zone_type = 'PUT'
                                AND   z.rule_id = 3)
      AND   i.cust_pref_vendor = r_cpv
      AND   ((i.plogi_loc = r_home_slot OR
              i.plogi_loc IN (SELECT logi_loc
                              FROM loc
                              WHERE prod_id = i.prod_id
                              AND   perm = 'Y'
                              AND   rank > 1)) OR
             r_home_slot = 'ALL' );
             
  CURSOR get_home_slot(p_prodid VARCHAR2,p_cpv VARCHAR2,p_uom NUMBER,p_qty NUMBER) IS
    SELECT l.logi_loc
      FROM  loc l, inv i
      WHERE l.logi_loc = i.plogi_loc
      AND   i.plogi_loc = i.logi_loc
      AND   l.perm = 'Y'
      AND   ((p_uom = 0 AND l.uom IN (0,2)) OR (p_uom = 1 AND l.uom IN (0,1)))
      AND   i.prod_id  = p_prodid
      AND   i.cust_pref_vendor = p_cpv
      AND   l.rank = 1;
  CURSOR get_existed_inv_float(p_prodid VARCHAR2, p_cpv VARCHAR2) IS
    SELECT i.plogi_loc
       FROM inv i, zone z, lzone lz
       WHERE i.status = 'AVL'
       AND   i.prod_id = p_prodid
       AND   i.cust_pref_vendor = p_cpv
       AND   z.zone_id = lz.zone_id
       AND   lz.logi_loc = i.plogi_loc
       AND   z.zone_type = 'PUT'
       AND   lz.logi_loc != NVL(z.induction_loc,' ') 	-- WAI change
       AND   z.rule_id in (1,3);    			-- WAI change
  CURSOR get_last_ship_slot(i_prod_id VARCHAR2,l_cpv VARCHAR2) IS
    SELECT RTRIM(last_ship_slot), pallet_type /* DN#10190 prplhj: add rtrim */
      FROM  pm
      WHERE prod_id = i_prod_id
      AND   cust_pref_vendor = l_cpv;
  -- DN#10190: prplhj: Changed to get the license plate from 'Y'
  CURSOR chk_last_ship_slot_inv(i_prod_id VARCHAR2,i_cpv VARCHAR2,i_last_ship_slot VARCHAR2) IS
    SELECT i.logi_loc
      FROM  pm p, inv i
      WHERE p.prod_id = i.prod_id
      AND   p.prod_id = i_prod_id
      AND   i.plogi_loc = i_last_ship_slot
      AND   p.cust_pref_vendor = i_cpv;
  CURSOR new_pallet_exist(n_pallet_id VARCHAR2) IS
    SELECT 'Y'
      FROM  inv
      WHERE logi_loc = n_pallet_id;
  CURSOR cc_reason(n_reason VARCHAR2) IS
    SELECT cc_reason_code
      FROM  reason_cds
      WHERE reason_cd = rtn_reason;
  -- DN#10190 prplhj: Get zone_id for the returned item
  CURSOR get_pm_zone(c_prod_id VARCHAR2,c_cpv VARCHAR2) IS
    SELECT RTRIM(zone_id)
      FROM  pm
      WHERE prod_id = c_prod_id
      AND   cust_pref_vendor = c_cpv;
  -- DN#10190 prplhj: Get the 1st available location of the same zone
  CURSOR get_loc_of_same_zone(c_zone_id VARCHAR2, c_pallet_type VARCHAR2) IS
    SELECT lz.logi_loc
      FROM  lzone lz, zone z, loc l, pallet_type pt
      WHERE z.zone_id = lz.zone_id
      AND   lz.logi_loc = l.logi_loc
      AND   l.status = 'AVL'
      AND   lz.zone_id = c_zone_id
      AND   z.zone_type = 'PUT'
      AND   z.rule_id in (1,3)   			-- WAI change
      AND   lz.logi_loc != NVL(z.induction_loc,' ')	-- WAI change
      AND   l.pallet_type = c_pallet_type
      AND   l.pallet_type = pt.pallet_type
      AND   NOT EXISTS (SELECT NULL
                        FROM  inv i
                        WHERE i.plogi_loc = lz.logi_loc)
      ORDER BY l.logi_loc ASC;
  -- DN#10269 prplhj: Check if slot already occuppied by another item
  CURSOR has_other_item(c_prod_id VARCHAR2,c_cpv VARCHAR2,c_loc VARCHAR2) IS
     SELECT 'Y'
        FROM inv
        WHERE plogi_loc = c_loc
        AND   cust_pref_vendor = c_cpv
        AND   status = 'AVL'
        AND   prod_id <> c_prod_id;


    BEGIN   -- insert_cc_tasks

        cc_gen_exc_reserve_flag := pl_common.f_get_syspar('CC_GEN_EXC_RESERVE','Y');
        gen_cc := cc_gen_exc_reserve_flag;

        l_reason := i_reason;

  -- DN#5080:acpjjs:Insert CC should be based on SYSCONFIG flag.
  -- IF CC_GEN_EXC_RESERVE_FLAG != 'N' THEN
  -- Generate cycle tasks for both home slots and all reserve slots
  -- ELSIF (home slot found in inv) THEN
  -- Generate cycle tasks for home slots only
  -- ELSE Item has no home slot, so generate CC for all reserve slots

  --
  -- Does this item has a home slot ?
  --
  BEGIN


    OPEN get_home_slot(rtn_prod_id, rtn_cpv,rtn_uom,rtn_qty);
    FETCH get_home_slot INTO v_home_slot;
    IF get_home_slot%NOTFOUND THEN
      v_home_slot := 'ALL';
      has_home := 'N';
    ELSE
      has_home := 'Y';
    END IF;
    CLOSE get_home_slot;

    EXCEPTION
      WHEN OTHERS THEN
        v_home_slot := 'ALL';
        IF get_home_slot%ISOPEN THEN CLOSE get_home_slot; END IF;
  END; -- Does this item has a home slot?

  IF (cc_gen_exc_reserve_flag != 'N') THEN
    v_home_slot := 'ALL';
  END IF; -- cc_gen_exc_reserve_flag 

  SELECT cc_batch_no_seq.NEXTVAL INTO v_batch_no FROM DUAL;
  IF v_reason_code IS NULL THEN
    v_reason_code := 'SE';
  END IF;



  FOR cc_inv IN cc_tasks(rtn_prod_id, rtn_cpv, v_home_slot) LOOP
    BEGIN
      v_rc := rtn_reason;
      SELECT cc_reason_code INTO v_reason_code
        FROM  reason_cds
        WHERE reason_cd = v_rc;
 
      EXCEPTION
        WHEN NO_DATA_FOUND THEN
          v_reason_code := 'SE';
        WHEN OTHERS THEN
          v_reason_code := 'SE';
    END; -- select cc_reason_code
    IF l_reason = 'CC' THEN
      v_reason_code := 'CC';
    END IF;
    -- D#10448 prplhj: Change to CC for W10 returned prod_id
    IF rtn_reason_grp = 'x=x' THEN
      v_reason_code := 'CC';
    END IF;



    BEGIN
      INSERT INTO cc
        (type, batch_no,
         logi_loc, phys_loc,
         prod_id, cust_pref_vendor,
         status, user_id,
         cc_gen_date, cc_reason_code)
        VALUES (
          'PROD', v_batch_no,
          cc_inv.logi_loc, cc_inv.plogi_loc,
          rtn_prod_id, rtn_cpv,
          'NEW', NULL,
          SYSDATE, NVL(v_reason_code,'SE'));

      IF cc_inv.logi_loc = cc_inv.plogi_loc THEN
        l_pallet_id := cc_inv.logi_loc;
        l_prod_id := rtn_prod_id;
        l_reason := v_reason_code;
      END IF;

      EXCEPTION
        WHEN DUP_VAL_ON_INDEX THEN
          UPDATE cc c
            SET type = 'PROD',
                batch_no = v_batch_no,
                status = 'NEW',
                cc_gen_date = SYSDATE,
                cc_reason_code = NVL(v_reason_code,'SE')
            WHERE prod_id = rtn_prod_id
            AND   cust_pref_vendor = rtn_cpv
            AND   logi_loc = cc_inv.logi_loc
            AND   phys_loc = cc_inv.plogi_loc
            AND   EXISTS (SELECT 'LOWER PRIORITY'
                          FROM  cc_reason rc, cc_reason ra
                          WHERE ra.cc_reason_code = v_reason_code
                          AND   rc.cc_reason_code = c.cc_reason_code
                          AND   rc.cc_priority >= ra.cc_priority);

          IF cc_inv.logi_loc = cc_inv.plogi_loc THEN 
            l_pallet_id := cc_inv.logi_loc;
            l_prod_id := rtn_prod_id;
            l_reason := v_reason_code;
          END IF;

        WHEN OTHERS THEN
            l_status := rf.status_data_error;
            l_msg := 'Unexpected ERROR during insert into cc in insert_cc_tasks';
            pl_log.ins_msg('FATAL', l_func_name, l_msg, SQLCODE, SUBSTR(SQLERRM, 1, 500), APPLICATION_FUNC, PACKAGE_NAME);
            raise;
    END; -- insert into cc

    IF v_reason_code <> 'CC' THEN
      BEGIN
        INSERT INTO cc_exception_list
          (logi_loc, phys_loc,
           prod_id, cust_pref_vendor,
           cc_except_date, cc_except_code,
           qty, uom)
          VALUES (
            cc_inv.logi_loc, cc_inv.plogi_loc,
            rtn_prod_id, rtn_cpv,
            sysdate, NVL(v_reason_code,'SE'),
            NVL(rtn_qty,0), rtn_uom);

        EXCEPTION
          WHEN DUP_VAL_ON_INDEX THEN
            UPDATE cc_exception_list
              SET qty = NVL(qty,0) + NVL(rtn_qty,0)
              WHERE logi_loc = cc_inv.logi_loc
              AND   phys_loc = cc_inv.plogi_loc
              AND   cc_except_code = NVL(v_reason_code,'SE')
              AND   prod_id = rtn_prod_id;

          WHEN OTHERS THEN
            l_status := rf.status_data_error;
            l_msg := 'Unexpected ERROR during insert into cc_exception_list in insert_cc_tasks';
            pl_log.ins_msg('FATAL', l_func_name, l_msg, SQLCODE, SUBSTR(SQLERRM, 1, 500), APPLICATION_FUNC, PACKAGE_NAME);
            raise;
      END; -- insert into cc_exception_list
    END IF; -- if v_reason_code <> 'CC'
  END LOOP; -- for cc_inv in

  /*
  **  No location related to home slot is found. Check on float location
  */
  IF NVL(has_home,' ') != 'Y' THEN
    BEGIN
      v_inv_exist := 'N';
      -- Check if inventory existed for the item as floating slot
      OPEN get_existed_inv_float(rtn_prod_id, rtn_cpv);
      FETCH get_existed_inv_float INTO v_last_ship_slot;
      IF get_existed_inv_float%FOUND THEN
         -- Found floating slot inventory. Check if the current slot also
         -- has occupied by another item
         OPEN has_other_item(rtn_prod_id, rtn_cpv, v_last_ship_slot);
         FETCH has_other_item INTO v_inv_exist;
         IF has_other_item%FOUND THEN
            -- The inventory slot has another item. Need to find a new slot
            v_last_ship_slot := NULL;
         END IF;
         CLOSE has_other_item;
      ELSE
         -- No inventory is found for the item
         v_last_ship_slot := NULL;
      END IF;
      CLOSE get_existed_inv_float;
      IF v_last_ship_slot IS NULL THEN
         OPEN get_last_ship_slot(rtn_prod_id, rtn_cpv);
         FETCH get_last_ship_slot INTO v_last_ship_slot, v_pallet_type;
         IF get_last_ship_slot%FOUND AND v_last_ship_slot IS NOT NULL THEN
           -- DN#10269 prplhj: Last ship slot is found. Check if the
           --    slot already was occuppied by another item
           OPEN has_other_item(rtn_prod_id, rtn_cpv, v_last_ship_slot);
           v_inv_exist := 'N';
           FETCH has_other_item INTO v_inv_exist;
           IF has_other_item%FOUND THEN   -- D#12213 Fix TD6737.
              -- Another item is already in the last ship slot. Need to
              -- find a new open location
              --v_last_ship_slot := NULL;
	      NULL;
           ELSE
             pl_ml_common.get_induction_loc(rtn_prod_id, rtn_cpv, rtn_uom,
                                            iStatus, sIndLoc);
             IF iStatus = 0 AND sIndLoc = v_last_ship_slot THEN
               v_last_ship_slot := NULL;
             END IF;
           END IF;
           CLOSE has_other_item;
         ELSE
           -- No last_ship_slot is found
           v_last_ship_slot := NULL;
         END IF;
         CLOSE get_last_ship_slot;
      END IF;
      IF v_last_ship_slot IS NULL THEN
         /*
         ** DN#10190 prplhj
         **   last_ship_slot is not found. Look for an open location (i.e.,
         **   no inventory) in the same zone for the item
         */
         OPEN get_pm_zone(rtn_prod_id, rtn_cpv);
         FETCH get_pm_zone INTO v_zone_id;
         IF get_pm_zone%NOTFOUND OR v_zone_id IS NULL THEN
            /*
            ** No default zone is found.
            */
            v_last_ship_slot := NULL;
         ELSE -- if get_pm_zone%found
            /*
            ** Has zone. Look for an open location from this zone
            */
            OPEN get_loc_of_same_zone(v_zone_id, v_pallet_type);
            FETCH get_loc_of_same_zone INTO v_last_ship_slot;
            IF get_loc_of_same_zone%NOTFOUND OR v_last_ship_slot IS NULL THEN
               /*
               ** No open location in the same zone
               */
               v_last_ship_slot := NULL;
            ELSE
               BEGIN
                  UPDATE pm
                     SET last_ship_slot = v_last_ship_slot
                     WHERE prod_id = rtn_prod_id
                     AND   cust_pref_vendor = rtn_cpv;

                  EXCEPTION
                     WHEN OTHERS THEN
                         l_status := rf.status_data_error;
                         l_msg := 'Unexpected ERROR during update of pm in insert_cc_tasks';
                         pl_log.ins_msg('FATAL', l_func_name, l_msg, SQLCODE, SUBSTR(SQLERRM, 1, 500), APPLICATION_FUNC, PACKAGE_NAME);
                         raise;
               END;
            END IF; -- if get_loc_of_same_zone%notfound
            CLOSE get_loc_of_same_zone;
          END IF; -- if get_pm_zone%notfound
          CLOSE get_pm_zone;
      END IF; -- if v_last_ship_slot is null

      IF v_last_ship_slot IS NULL THEN
         v_last_ship_slot := '*';
      END IF;

      /*
      ** At this point: The last_ship_slot will either have a valid
      ** location (last_ship_slot is found on the 1st shot or an open
      ** location in the same zone is found) or a '*' in the location
      */

      IF v_pallet_id IS NULL THEN
         OPEN chk_last_ship_slot_inv(rtn_prod_id, rtn_cpv,v_last_ship_slot);
         FETCH chk_last_ship_slot_inv INTO v_pallet_id;
         IF chk_last_ship_slot_inv%NOTFOUND THEN
            v_pallet_id := NULL;
         END IF;
         CLOSE chk_last_ship_slot_inv;
      END IF;
      IF v_pallet_id IS NULL THEN
        /*
        ** No inventory found for the last ship slot. Create a new
        ** license plate for the slot
        */
        BEGIN
          SELECT pallet_id_seq.NEXTVAL INTO v_pallet_id FROM DUAL;

          EXCEPTION
            WHEN OTHERS THEN
              -- MESSAGE( STRING_TRANSLATION.GET_STRING(6042));
              v_pallet_id := '1';
        END; -- select pallet_id_seq
        /*
        ** Check if this new pallet_id already existed. If it existed,
        ** the DBA probably will need to reset the sequence. If it's new,
        ** ok
        */
        OPEN new_pallet_exist(v_pallet_id);
        FETCH new_pallet_exist INTO v_pallet_exist;
        IF new_pallet_exist%FOUND THEN
          --MESSAGE( STRING_TRANSLATION.GET_STRING(6372));
          v_pallet_id := '1';
        END IF; -- if new_pallet_exist%found
        CLOSE new_pallet_exist;
      END IF; -- if v_pallet_id is null

      /*
      ** An existing pallet_id is found or a new pallet_id is created
      ** to add the returned item
      */
      get_cc_reason(rtn_reason,v_reason_code);
      -- D#10448 prplhj: Use CC
      IF rtn_reason_grp = 'x=x' THEN
         v_reason_code := 'CC';
      END IF;
      l_pallet_id := v_pallet_id;
      l_prod_id := rtn_prod_id;
      l_reason := nvl(v_reason_code,'SE');

      /*
      ** Create the CC and CC_EXCEPTION_LIST records using last_ship_slot
      ** and pallet_id. Note that last_ship_slot will have either a valid
      ** location or a '*' (nothing is found) and pallet_id will have
      ** either an existing license plate (w/ last_ship_slot) or a new one
      */

      /* 12/21/05 - prphqb - WAI project requirement: do not write CC with '*' */

      BEGIN
        IF (v_last_ship_slot != '*') THEN
           INSERT INTO cc
             (type, batch_no,
              logi_loc, phys_loc,
              prod_id, cust_pref_vendor,
              status, user_id,
              cc_gen_date, cc_reason_code)
           VALUES (
              'PROD', v_batch_no,
              v_pallet_id, v_last_ship_slot,
              rtn_prod_id, rtn_cpv,
              'NEW', NULL,
              SYSDATE, NVL(v_reason_code,'SE'));
	END IF;
        EXCEPTION
          WHEN DUP_VAL_ON_INDEX THEN
            UPDATE cc c
              SET type = 'PROD',
                  batch_no = v_batch_no,
                  status = 'NEW',
                  cc_gen_date = SYSDATE,
                  cc_reason_code = NVL(v_reason_code,'SE')
              WHERE prod_id = rtn_prod_id
              AND   cust_pref_vendor = rtn_cpv
              AND   logi_loc = v_pallet_id
              AND   phys_loc = v_last_ship_slot
              AND   EXISTS (SELECT 'LOWER PRIORITY'
                            FROM  cc_reason rc, cc_reason ra
                            WHERE ra.cc_reason_code = v_reason_code
                            AND   rc.cc_reason_code = c.cc_reason_code
                            AND   rc.cc_priority >= ra.cc_priority);

          WHEN OTHERS THEN
              l_status := rf.status_data_error;
              l_msg := 'Unexpected ERROR during insert into cc #2 in insert_cc_tasks';
              pl_log.ins_msg('FATAL', l_func_name, l_msg, SQLCODE, SUBSTR(SQLERRM, 1, 500), APPLICATION_FUNC, PACKAGE_NAME);
              raise;
      END; -- insert into cc

      IF (v_reason_code <> 'CC' AND v_last_ship_slot != '*') THEN
        BEGIN
          INSERT INTO cc_exception_list
            (logi_loc, phys_loc,
             prod_id, cust_pref_vendor,
             cc_except_date, cc_except_code,
             qty, uom)
            VALUES (
             v_pallet_id, v_last_ship_slot,
             rtn_prod_id, rtn_cpv,
             sysdate, NVL(v_reason_code,'SE'),
             NVL(rtn_qty,0), rtn_uom);

          EXCEPTION
            WHEN DUP_VAL_ON_INDEX THEN
              UPDATE cc_exception_list
                SET qty = NVL(qty,0) + NVL(rtn_qty,0)
                WHERE logi_loc = v_pallet_id
                AND   phys_loc = v_last_ship_slot
                AND   cc_except_code = NVL(v_reason_code,'SE')
                AND   prod_id = rtn_prod_id;

            WHEN OTHERS THEN
              l_status := rf.status_data_error;
              l_msg := 'Unexpected ERROR during insert into cc_exception_list #2 in insert_cc_tasks';
              pl_log.ins_msg('FATAL', l_func_name, l_msg, SQLCODE, SUBSTR(SQLERRM, 1, 500), APPLICATION_FUNC, PACKAGE_NAME);
              raise;
        END; -- insert into cc_exception_list
      END IF; -- if v_reason_code <> 'CC

      IF v_last_ship_slot = '*' THEN
          -- Cannot find a valid location. Notify user
          l_msg := 'Unable to find any valid zone/location for item ['
                || rtn_prod_id
                || ']';
          pl_log.ins_msg('WARN', l_func_name, l_msg, null, null, APPLICATION_FUNC, PACKAGE_NAME);
      END IF; -- if v_last_ship_slot = '*'
    END; -- if has_home <> 'Y'
  END IF; -- if has_home <> 'Y'

  -- D#10448 prplhj: Don't insert exceptions for reserved slots which will
  -- be updated to 'CC' reason codes anyway after this block
  BEGIN
     DELETE cc_exception_list
        WHERE prod_id = l_prod_id
        AND   phys_loc <> logi_loc
        AND   logi_loc <> l_pallet_id
        AND   cc_except_code = v_reason_code;

     EXCEPTION
        WHEN NO_DATA_FOUND THEN
           NULL;
        WHEN OTHERS THEN
              l_status := rf.status_data_error;
              l_msg := 'Unexpected ERROR during deletion of cc_exception_list in insert_cc_tasks';
              pl_log.ins_msg('FATAL', l_func_name, l_msg, SQLCODE, SUBSTR(SQLERRM, 1, 500), APPLICATION_FUNC, PACKAGE_NAME);
              raise;
  END;

  IF gen_cc = 'Y' THEN
    BEGIN
      -- D#10448 prplhj: For pick slots with ranks > 1, use the returned
      -- reason code
      BEGIN
         UPDATE cc
            SET cc_reason_code = 'CC'
            WHERE logi_loc <> l_pallet_id
            AND   prod_id = l_prod_id
            AND   phys_loc <> logi_loc;

         EXCEPTION
            WHEN NO_DATA_FOUND THEN
               NULL;
            WHEN OTHERS THEN
              l_status := rf.status_data_error;
              l_msg := 'Unexpected ERROR during update of cc in insert_cc_tasks';
              pl_log.ins_msg('FATAL', l_func_name, l_msg, SQLCODE, SUBSTR(SQLERRM, 1, 500), APPLICATION_FUNC, PACKAGE_NAME);
              raise;
      END;

      BEGIN
         UPDATE cc_exception_list
            SET cc_except_code = 'CC'
            WHERE logi_loc <> l_pallet_id
            AND   prod_id = l_prod_id
            AND   cc_except_code = l_reason
            AND   phys_loc <> logi_loc;

         EXCEPTION
            WHEN NO_DATA_FOUND THEN
               NULL;
            WHEN OTHERS THEN
              l_status := rf.status_data_error;
              l_msg := 'Unexpected ERROR during update of cc_exception_list in insert_cc_tasks';
              pl_log.ins_msg('FATAL', l_func_name, l_msg, SQLCODE, SUBSTR(SQLERRM, 1, 500), APPLICATION_FUNC, PACKAGE_NAME);
              raise;
      END;
    END; -- if gen_cc = 'Y'
  END IF; -- if gen_cc = 'Y'

        return l_status;

    EXCEPTION
        WHEN OTHERS THEN
            l_status := rf.status_data_error;
            l_msg := 'Unexpected ERROR in insert_cc_tasks';
            pl_log.ins_msg('FATAL', l_func_name, l_msg, SQLCODE, SUBSTR(SQLERRM, 1, 500), APPLICATION_FUNC, PACKAGE_NAME);
            return l_status;

    END insert_cc_tasks;

    /****************************************************************************
    --
    -- get_cc_reason()
    --
    -- Description:     Returns the CC reason code for the passed in return
    --                  reason code. Copied from procedure get_cc_reason()
    --                  in form rtnscls.fmb. 
    --
    -- Modification log:
    --
    -- Date         Developer     Change
    -- ------------------------------------------------------------------
    -- 17-NOV-2020  pkab6563      Initial version.
    --
    *****************************************************************************/
    PROCEDURE get_cc_reason (rtn_reason_cd in VARCHAR2,v_ccr out VARCHAR2) IS
        v_cc_reason VARCHAR2(3);
    begin
        v_ccr:='SE';
        begin
            select cc_reason_code into v_cc_reason
            from reason_cds
            where reason_cd=rtn_reason_cd;
        exception when no_data_found then
            v_cc_reason:='SE';
        end;

        v_ccr:= v_cc_reason;
    end get_cc_reason;

    /****************************************************************************
    --
    -- get_put_loc()
    --
    -- Description:     Returns the destination location for the put task or
    --                  the location where the return was put.
    --                  Copied from function get_put_loc() in form rtnsdtls.fmb.
    --
    -- Modification log:
    --
    -- Date         Developer     Change
    -- ------------------------------------------------------------------
    -- 18-NOV-2020  pkab6563      Initial version.
    --
    *****************************************************************************/
    FUNCTION get_put_loc (
        p_rec_id   IN VARCHAR2,
        p_prod_id  IN VARCHAR2,
        p_cpv      IN VARCHAR2,
        p_rsn_grp  IN VARCHAR2,
        p_reason   IN VARCHAR2,
        p_line     IN NUMBER
    ) RETURN VARCHAR2 IS

       v_dest_loc	VARCHAR2(10) := NULL;

       CURSOR get_putawaylst_loc IS
           SELECT dest_loc
           FROM putawaylst
           WHERE SUBSTR(rec_id, 2) = p_rec_id
           AND   prod_id = p_prod_id
           AND   cust_pref_vendor = p_cpv
           AND   reason_code = p_reason
           AND   erm_line_id = p_line;

       CURSOR get_trans_loc IS
           SELECT dest_loc
           FROM trans
           WHERE trans_type IN ('MIS', 'PUT')
           AND   SUBSTR(rec_id, 2) = p_rec_id
           AND   prod_id = p_prod_id
           AND   cust_pref_vendor = p_cpv
           AND   reason_code = p_reason
           AND   order_line_id = p_line;

    BEGIN
        IF p_rsn_grp IN ('STM', 'MPK') THEN
            RETURN v_dest_loc;
        END IF;

        OPEN get_putawaylst_loc;
        FETCH get_putawaylst_loc INTO v_dest_loc;
        IF get_putawaylst_loc%NOTFOUND THEN
            OPEN get_trans_loc;
            FETCH get_trans_loc INTO v_dest_loc;
            CLOSE get_trans_loc;
        END IF;

        CLOSE get_putawaylst_loc;

        RETURN v_dest_loc;
    END get_put_loc;

    /****************************************************************************
    --
    -- f_get_order_line_id()
    --
    --    Copied from function f_get_order_line_id() in form rtnscls.fmb.
    --
    -- Modification log:
    --
    -- Date         Developer     Change
    -- ------------------------------------------------------------------
    -- 18-NOV-2020  pkab6563      Initial version.
    --
    *****************************************************************************/
    FUNCTION f_get_order_line_id
        (i_prod_id IN VARCHAR2,
         i_cpv     IN VARCHAR2,
         i_obligation_no IN VARCHAR2,
         i_orig_invoice IN VARCHAR2,
         i_return_split_cd IN VARCHAR2) RETURN NUMBER IS
 
        l_order_line_id      ordd.order_line_id%TYPE;
 
        CURSOR get_ordd_line(c_prod_id	         pm.prod_id%TYPE,
                             c_cpv               pm.cust_pref_vendor%TYPE,
                             c_obligation_no     returns.obligation_no%TYPE,
                             c_orig_invoice      returns.obligation_no%TYPE,
                             c_return_split_cd   returns.returned_split_cd%TYPE) IS
        SELECT d.order_line_id
        FROM   ordd d
        WHERE  d.prod_id = c_prod_id
        AND    d.cust_pref_vendor = c_cpv
        AND    d.order_id IN (c_obligation_no, c_orig_invoice)
        AND    d.uom = TO_NUMBER(c_return_split_cd)
        ORDER BY d.order_line_id;
            
        CURSOR get_ordd_for_rtn_line (c_prod_id           pm.prod_id%TYPE,
                                      c_cpv               pm.cust_pref_vendor%TYPE,
                                      c_obligation_no     returns.obligation_no%TYPE,
                                      c_orig_invoice      returns.obligation_no%TYPE,
                                      c_return_split_cd   returns.returned_split_cd%TYPE) IS
        SELECT d.order_line_id
        FROM   ordd_for_rtn d
        WHERE  d.prod_id = c_prod_id
        AND    d.cust_pref_vendor = c_cpv
        AND    d.order_id IN (c_obligation_no, c_orig_invoice)
        AND    ((c_return_split_cd IS NULL) OR
               ((c_return_split_cd IS NOT NULL) AND (d.uom = TO_NUMBER(c_return_split_cd))))
        ORDER BY d.order_line_id;   

BEGIN
    OPEN get_ordd_line(i_prod_id, i_cpv,i_obligation_no,i_orig_invoice,i_return_split_cd);
    FETCH get_ordd_line INTO l_order_line_id;
    IF get_ordd_line%NOTFOUND THEN
       OPEN get_ordd_for_rtn_line(i_prod_id, i_cpv,i_obligation_no,i_orig_invoice,i_return_split_cd);
       FETCH get_ordd_for_rtn_line INTO l_order_line_id;
       IF get_ordd_for_rtn_line%NOTFOUND THEN
         CLOSE get_ordd_for_rtn_line;
         CLOSE get_ordd_line;
         OPEN get_ordd_line(i_prod_id, i_cpv,i_obligation_no,i_orig_invoice, NULL);
         FETCH get_ordd_line INTO l_order_line_id;
         IF get_ordd_line%NOTFOUND THEN
           CLOSE get_ordd_line;
           OPEN get_ordd_for_rtn_line(i_prod_id, i_cpv,i_obligation_no,i_orig_invoice,NULL);
           FETCH get_ordd_for_rtn_line INTO l_order_line_id;
           IF get_ordd_for_rtn_line%NOTFOUND THEN
             l_order_line_id := NULL;
           END IF;
         END IF;
       END IF;
       IF get_ordd_for_rtn_line%ISOPEN THEN
         CLOSE get_ordd_for_rtn_line;              
       END IF;
    END IF;
    IF get_ordd_line%ISOPEN THEN
      CLOSE get_ordd_line;              
    END IF;
 RETURN l_order_line_id;
END f_get_order_line_id;


    /**************************************************************************
    --
    -- mf_cls_process_returns()
    --
    -- Description:      
    --                   Logic taken from data block detail trigger
    --                   POST-UPDATE in form rtnscls.fmb.
    --      
    -- Parameters:       
    --
    -- Return/output:    status code indicating success or error.
    --
    -- Modification log:
    --
    -- Date         Developer     Change
    -- ------------------------------------------------------------------
    -- 16-NOV-2020  pkab6563      Initial version.
    -- 28-07-2021   vkal9662      Jira 3400 xdock logic for Manifest close
    ***************************************************************************/
    FUNCTION mf_cls_process_returns (
        i_manifest_no   IN  manifests.manifest_no%TYPE,
        i_pod_enable    IN  VARCHAR2,
        i_mf_status     IN  manifests.manifest_status%TYPE
    ) return rf.status IS

        l_func_name  CONSTANT     swms_log.procedure_name%TYPE := 'mf_cls_process_returns';
        l_status                  rf.status := rf.status_normal;
        l_msg                     swms_log.msg_text%TYPE;
        l_insert                  BOOLEAN;
        l_reason_group            reason_cds.reason_group%TYPE := null;

        l_upload_time             DATE;
        l_orig_invoice            MANIFEST_DTLS.ORIG_INVOICE%TYPE;
        l_cmt                     trans.cmt%TYPE;
        l_adj_flag                trans.adj_flag%TYPE;
        l_return_count            number;
        l_trans_count             number;
        l_prod_id                 returns.prod_id%TYPE;
        l_cpv                     returns.cust_pref_vendor%TYPE;
        l_dest_loc                putawaylst.dest_loc%TYPE;
        l_revise_obligation       returns.obligation_no%TYPE;
        l_order_line_id           ordd.order_line_id%TYPE;
        l_fh_line_id              FLOAT_HIST.order_line_id%TYPE;
        l_alert_id                number;

        CURSOR c_rtn IS
        SELECT manifest_no,
               route_no,
               stop_no,
               rec_type,
               obligation_no,
               prod_id,
               cust_pref_vendor,
               returned_qty,
               return_reason_cd,
               returned_split_cd,
               returned_prod_id,
               erm_line_id,
               rtn_sent_ind,
               pod_rtn_ind,
               catchweight,
               temperature,
               xdock_ind
        FROM   returns
        WHERE  manifest_no = i_manifest_no;
               	

    BEGIN
        IF i_mf_status = 'PAD' THEN     -- SWMS created this manifest number so do not send RTN to ERP
            l_upload_time := null;
        ELSE
            l_upload_time := TO_DATE('01-JAN-1980', 'DD-MON-YYYY');
        END IF;


        FOR r_rtn in c_rtn LOOP
            l_orig_invoice := null;
            l_adj_flag := null;
            l_insert   := FALSE;

            IF r_rtn.rec_type IN ('P', 'D') THEN
                BEGIN 
                    select DECODE(INSTR(orig_invoice, 'L'),
                                  0, orig_invoice,
                                  SUBSTR(orig_invoice, 1, INSTR(orig_invoice, 'L') - 1))
                    into l_orig_invoice
                    from manifest_dtls 
                    where  manifest_no = i_manifest_no 
                    and    prod_id     = r_rtn.prod_id 
                    and    rec_type IN ('P', 'D') 
                    and    obligation_no = r_rtn.obligation_no;

                EXCEPTION
                    when no_data_found then
                        null;
                    when too_many_rows then
                        null;
                END;
            END IF; -- rec_type either P or D

            IF nvl(r_rtn.rtn_sent_ind, 'N') = 'Y' and nvl(r_rtn.pod_rtn_ind, 'A') = 'D' THEN --Reverse credit
                l_cmt := 'Reverse credit made by STS stop close.';
                l_adj_flag := 'U';
                l_insert   := TRUE;
            ELSIF nvl(r_rtn.rtn_sent_ind,'N') = 'Y' and nvl(r_rtn.pod_rtn_ind,'A') != 'D' THEN --Credit already sent
                null;
            ELSIF r_rtn.pod_rtn_ind is null THEN --This return is not POD; l_adj_flag := null
                l_cmt := 'Non-POD Return.';
                l_insert   := TRUE;
            ELSE
                l_cmt := 'POD Return added from SWMS';
                l_insert   := TRUE;
                l_adj_flag := 'A';
            END IF; 

            -- insert RTN transaction
            IF l_insert THEN
                INSERT INTO TRANS
                     ( TRANS_ID, TRANS_TYPE, TRANS_DATE, batch_no, ROUTE_NO,
                       STOP_NO, ORDER_ID, PROD_ID, CUST_PREF_VENDOR,  REC_ID, WEIGHT, 
                       temp, QTY, UOM, REASON_CODE,
                       lot_id, ORDER_TYPE, order_line_id,  RETURNED_PROD_ID,
                       UPLOAD_TIME, cmt, ADJ_FLAG,   USER_ID)
                VALUES
                     ( TRANS_ID_SEQ.NEXTVAL, decode(r_rtn.xdock_ind, 'X', 'RTX','RTN'), SYSDATE, '99', r_rtn.route_no, --Jira 3400 insert RTX trans for xdock
                       r_rtn.STOP_NO, 
                       DECODE(INSTR(r_rtn.obligation_no, 'L'),
                              0, r_rtn.obligation_no,
                              SUBSTR(r_rtn.OBLIGATION_NO, 1,
                              INSTR(r_rtn.obligation_no, 'L') - 1)),
                       r_rtn.PROD_ID,  r_rtn.CUST_PREF_VENDOR,  r_rtn.MANIFEST_NO,  r_rtn.CATCHWEIGHT,
                       r_rtn.temperature,  r_rtn.returned_qty, r_rtn.RETURNED_SPLIT_CD, r_rtn.return_reason_cd,
                       l_orig_invoice,  r_rtn.REC_TYPE,  r_rtn.erm_line_id,  r_rtn.RETURNED_PROD_ID,
                       decode(r_rtn.xdock_ind,'X', null,l_upload_time),  ----Jira 3400 insert RTX trans for xdock
                       l_cmt || DECODE(r_rtn.return_reason_cd, 'W10',
                                            ' Returned item #' || r_rtn.returned_prod_id,
                                            NULL),  l_adj_flag,   USER);

                     l_status := rf.status_normal;
            END IF;   -- insert RTN transaction

            SELECT count(*) 
            into   l_return_count
            FROM   returns
            where  manifest_no = r_rtn.manifest_no 
            and    stop_no = r_rtn.stop_no;
  
            SELECT count(*) 
            into   l_trans_count
	          FROM   trans
	          where  rec_id = r_rtn.manifest_no
            and    stop_no = r_rtn.stop_no 
            and    trans_type in ('RTX', 'RTN');  --Jira3400 xdoc logic

            IF i_pod_enable = 'Y' and l_return_count = l_trans_count THEN
                --CRQ34059--IF RTN TRANSACTION IN TRANS TABLE IS EQUAL TO THE TOTAL NUMBER OF
                --RETURNS PRESENT FOR THAT MANIFEST, THEN UPDATE POD_STATUS_FLAG FROM 'F' to 'M',
                -- 	IF SYSPAR POD_ENABLE IS ON.

                UPDATE MANIFEST_STOPS 
                SET    POD_STATUS_FLAG = 'M' 
                WHERE  MANIFEST_NO = i_manifest_no 
                AND POD_STATUS_FLAG = 'F'
                AND STOP_NO = r_rtn.stop_no;
            END IF; /* pod_enable=Y and return count=trans count */

            -- get reason group
            BEGIN
                SELECT reason_group
                INTO   l_reason_group
                FROM   reason_cds
                WHERE  reason_cd = r_rtn.return_reason_cd
                  AND  reason_cd_type = 'RTN';

            EXCEPTION
                WHEN NO_DATA_FOUND THEN
                    null;
    
                WHEN OTHERS THEN
                    raise;

            END;   -- get reason group

            --Knha8378 5/22/2020 if the returns is deliver or not return or undo by user then do not create cc */
            IF  nvl(r_rtn.pod_rtn_ind,'A') != 'D' then
                --nvl(:detail.rtn_sent_ind,'N') = 'N' and (remove this logic by knha8378 b/c CC is needed regardless send or not
                -- Generate a cycle count request for the product if
                -- one of the reasons is in the if statement
                -- DN#4121:acpjjs:ON dup-cc-recs PRIORITY is updated.
                -- DN#4145:acpjjs:CC needed for returned prodid for MISPICKS.
                l_prod_id := r_rtn.prod_id;
                l_cpv := r_rtn.cust_pref_vendor;
                IF l_reason_group IN ('STM','STR','MPR','MPK','OVR','OVI') THEN
                    IF l_reason_group = 'OVR' THEN
                        l_prod_id := r_rtn.RETURNED_PROD_ID;
                        l_cpv := '-';
                    ELSE
                        l_prod_id := r_rtn.PROD_ID;
                        l_cpv := r_rtn.cust_pref_vendor;
                    END IF;
         
                    IF nvl(r_rtn.returned_qty, 0) <> 0 and nvl(r_rtn.xdock_ind, 'N') <> 'X'  THEN
                        l_status:= insert_cc_tasks(l_prod_id, l_cpv, l_reason_group, r_rtn.return_reason_cd,
                               r_rtn.returned_split_cd, r_rtn.returned_qty, null);
                    END IF;
           
                    IF l_status = rf.status_normal THEN
                        IF l_reason_group IN ('MPR','MPK') AND r_rtn.RETURNED_PROD_ID IS NOT NULL THEN
                            l_prod_id := r_rtn.RETURNED_PROD_ID;
                            l_cpv    := '-';
                            -- DN#10357 prplhj: Change from 'CC' to ...
              
                            -- D#10448 prplhj: Use CC for returned prod_id, arbitrary group
                            IF NVL(r_rtn.returned_qty, 0) <> 0 and nvl(r_rtn.xdock_ind, 'N') <> 'X' THEN
                                l_status := insert_cc_tasks(l_prod_id, l_cpv, 'x=x','CC', r_rtn.returned_split_cd,
                                       r_rtn.returned_qty, r_rtn.return_reason_cd );
                            END IF;
                       END IF;
                   END IF;   -- is status is normal
                END IF; --tmp_reason_group in ......

                IF l_status = rf.status_normal and  nvl(r_rtn.xdock_ind, 'N') <> 'X' THEN
                    l_dest_loc := get_put_loc(TO_CHAR(r_rtn.manifest_no),
                                l_prod_id, l_cpv,
                                 l_reason_group, r_rtn.return_reason_cd,
                                 r_rtn.erm_line_id);
                    SELECT DECODE(INSTR(r_rtn.obligation_no, 'L'),
                                         0, r_rtn.obligation_no,
                                         SUBSTR(r_rtn.obligation_no, 1 ,INSTR(r_rtn.obligation_no, 'L') - 1))
                    INTO l_revise_obligation
                    FROM DUAL;

                    -- 11/1/05 
                    -- now we need to get order_line_id from ordd or ordd_for_rtn table
                    -- We need to assume that the same selector/user (hence same selection
                    -- batch) will pick the items with same invoices # and uoms but in
                    -- different order line IDs/order sequence #s.
                    l_order_line_id := null;	-- =0 is really bad
                    l_order_line_id := f_get_order_line_id(r_rtn.prod_id, r_rtn.cust_pref_vendor, l_revise_obligation,
                                              l_orig_invoice, r_rtn.returned_split_cd);   
				
                    if (l_order_line_id is null or l_order_line_id <> 0) and nvl(r_rtn.xdock_ind, 'N') <> 'X' then
                        BEGIN
                            INSERT into float_hist_errors 
                                     (prod_id, cust_pref_vendor, order_id,
                                      reason_code, 	ret_qty,	ret_uom,	err_date,
                                      returned_prod_id, 	returned_loc, 	orig_invoice,	order_line_id)
                            VALUES (r_rtn.prod_id,
                                    r_rtn.cust_pref_vendor,
                                    nvl(l_revise_obligation,'0000'),
                                    r_rtn.return_reason_cd,
                                    nvl(r_rtn.returned_qty,0),
                                    nvl(r_rtn.returned_split_cd,0),
                                    sysdate,
                                    DECODE(r_rtn.return_reason_cd, 'W10', r_rtn.returned_prod_id,NULL),
                                    l_dest_loc,
                                    DECODE(r_rtn.rec_type,'P', l_orig_invoice,'D', l_orig_invoice,NULL),
                                    l_order_line_id);

                        EXCEPTION
                            WHEN DUP_VAL_ON_INDEX THEN


                                update float_hist_errors
                                set    ret_qty = ret_qty + nvl(r_rtn.returned_qty,0)
                                where  prod_id = r_rtn.prod_id 
                                and    order_id = l_revise_obligation
                                and    reason_code = r_rtn.return_reason_cd;

                            WHEN OTHERS THEN
                                raise;
                        END;
	    	    end if; --order_line_id not zero                     
                END IF;   -- if status is normal
            END IF;   --nvl(r_rtn.pod_rtn_ind,'A') != 'D'


        END LOOP;    

        return l_status;

    EXCEPTION
        WHEN OTHERS THEN 
            l_status := rf.status_data_error;
            l_msg := 'Unexpected ERROR in mf_cls_process_returns';
            pl_log.ins_msg('FATAL', l_func_name, l_msg, SQLCODE, SUBSTR(SQLERRM, 1, 500), APPLICATION_FUNC, PACKAGE_NAME);
            return l_status;

    END mf_cls_process_returns;

 --   ======================================= Ben Changes ======================================================
    /****************************************************************************************
    --
    -- print_return()
    --
    -- Description:      Builds the data necessary to print Returns Labels
    --                   If i_wherePrinted contains 'M', this function will:
    --                   1. Set the PutAwayList print flag
    --                   2. Return Status Code
    --                   If i_wherePrinted contains 'S', this function will:
    --                   1. collect the neccessary data for the label
    --                   2. call the print label routines, passing in the collected data
    --                   3. Set the PutAwayList print flags
    --                   4. Return Status Code
    --
    -- Parameters:       i_rf_log_init_rec:    route#
    --                   i_manifest_no:        Manifest Number (Required)
    --                   i_wherePrinted:       Print Location
    --                                         Valid Values are 'M' for Mobile Printer and 'S' for Server
    --
    --
    -- Return/output:    Status indicating if Label was printed
    --
    -- Modification log:
    --
    -- Date         Developer     Change
    -- ----------------------------------------------------------------------------------
    -- 06-NOV-2020  ECLA1411      Initial version.
    --                            OPCOF-3226 - POD Returns - Print Process For RF Host
    --
    *****************************************************************************************/
    FUNCTION print_return (
        i_rf_log_init_rec   IN rf_log_init_record,
        i_manifest_no       IN returns.manifest_no%TYPE,
        i_wherePrinted      IN varchar2 -- M = Mobile, S = Server
    ) return rf.status IS
        l_func_name CONSTANT  swms_log.procedure_name%TYPE := 'print_return';
        l_status              rf.status := rf.STATUS_NORMAL;
        l_msg                 swms_log.msg_text%TYPE;
        o_printer_name        VARCHAR2(7);
		l_command             VARCHAR2(256);
		l_print_condition     VARCHAR2(200);
		l_rc                  VARCHAR2(500);
		l_query_seq           NUMBER;
    BEGIN
        -- Call rf.initialize(). Cannot procede if return status is not successful.
        l_status := rf.initialize(i_rf_log_init_rec);

        IF l_status = rf.STATUS_NORMAL THEN
            -- Log the input received from the RF client
            l_msg := 'Starting ' || l_func_name || '. Received manifest# from RF client: [' || i_manifest_no || '] i_wherePrinted is [' || i_wherePrinted || ']';
            pl_log.ins_msg('INFO', l_func_name, l_msg, null, null, APPLICATION_FUNC, PACKAGE_NAME);

            -- Did they forget to tell us where to print
            IF i_wherePrinted IS NULL THEN
                l_status := rf.status_data_error;
                l_msg := 'i_wherePrinted cannot be null for Print_Return using manifest# [' || i_manifest_no || ']';
                pl_log.ins_msg('WARN', l_func_name, l_msg, null, null, APPLICATION_FUNC, PACKAGE_NAME);
            END IF;

            IF l_status = rf.STATUS_NORMAL THEN
            BEGIN
                -- Did they print the label on the Mobile Printer
                IF i_wherePrinted = 'M' THEN
                BEGIN
					l_msg := 'Print Return (Mobile) for manifest# [' || i_manifest_no || '] i_wherePrinted is [' || i_wherePrinted || ']';
					pl_log.ins_msg('INFO', l_func_name, l_msg, NULL, NULL, APPLICATION_FUNC, PACKAGE_NAME);

                    -- We only need to update the flags in PutAwayLst
                    UPDATE PUTAWAYLST
                       SET rtn_label_printed = 'Y'
                     WHERE SUBSTR(rec_id,2) = to_char(i_manifest_no) AND SUBSTR(rec_id,1,1) IN ('D','S') AND
                           NVL(RTN_LABEL_PRINTED,'N') = 'N';

                    EXCEPTION
                        WHEN NO_DATA_FOUND THEN
                            l_status := rf.STATUS_MAN_NOT_FOUND;
                            l_msg := 'PutAwayLst Records Not Found for manifest# [' || i_manifest_no || '] i_wherePrinted is [' || i_wherePrinted || ']';
                            pl_log.ins_msg('FATAL', l_func_name, l_msg, SQLCODE, SUBSTR(SQLERRM, 1, 500), APPLICATION_FUNC, PACKAGE_NAME);
                        WHEN OTHERS THEN
                            l_status := rf.STATUS_DATA_ERROR;
                            l_msg := 'Update Of PutAwayLst FAILED for manifest# [' || i_manifest_no || '] i_wherePrinted is [' || i_wherePrinted || ']';
                            pl_log.ins_msg('FATAL', l_func_name, l_msg, SQLCODE, SUBSTR(SQLERRM, 1, 500), APPLICATION_FUNC, PACKAGE_NAME);
                END;	-- End Mobile Print
                ELSIF i_wherePrinted = 'S' THEN -- Did they want the server to print the lables
                BEGIN
					l_msg := 'Print Return (Server) for manifest# [' || i_manifest_no || '] i_wherePrinted is [' || i_wherePrinted || ']';
					pl_log.ins_msg('INFO', l_func_name, l_msg, NULL, NULL, APPLICATION_FUNC, PACKAGE_NAME);

					BEGIN
						-- Find the printer for the user in User Configuration
						SELECT queue
						 INTO o_printer_name
						 FROM print_report_queues prq
						WHERE UPPER(USER_ID) = REPLACE(USER,'OPS$',NULL) AND
							  EXISTS (SELECT 1
									    FROM print_reports pr
									   WHERE pr.report = 'rp1ri' AND
											 pr.queue_type = prq.queue_type);

						EXCEPTION
							WHEN NO_DATA_FOUND THEN
								l_status := rf.STATUS_NO_PRINTER_DEFINED;
								l_msg := 'Printer Not Defined For User ' || USER || '. for manifest# [' || i_manifest_no || '] i_wherePrinted is [' || i_wherePrinted || ']';
								pl_log.ins_msg('FATAL', l_func_name, l_msg, SQLCODE, SUBSTR(SQLERRM, 1, 500), APPLICATION_FUNC, PACKAGE_NAME);
							WHEN OTHERS THEN
								l_status := rf.STATUS_DATA_ERROR;
								l_msg := 'Get Printer For User FAILED for manifest# [' || i_manifest_no || '] i_wherePrinted is [' || i_wherePrinted || ']';
								pl_log.ins_msg('FATAL', l_func_name, l_msg, SQLCODE, SUBSTR(SQLERRM, 1, 500), APPLICATION_FUNC, PACKAGE_NAME);
					END;

					-- If we have a Printer
					IF (l_status = rf.STATUS_NORMAL) THEN
					BEGIN
						l_msg := 'Printer Located For User ' || USER || '. Printer: [' || o_printer_name || ']';
						pl_log.ins_msg('INFO', l_func_name, l_msg, NULL, NULL, APPLICATION_FUNC, PACKAGE_NAME);

						-- Get the next available Print Sequence
						SELECT print_query_seq.nextval
						  INTO l_query_seq
						  FROM DUAL;
						EXCEPTION
							WHEN OTHERS THEN
								l_status := rf.STATUS_DATA_ERROR;
								pl_log.ins_msg('WARN', l_func_name, 'Unable to select print query sequence', sqlcode, sqlerrm);
						END;
					END IF;

					-- If we have a Printer AND a Sequence Number
					IF (l_status = rf.STATUS_NORMAL) THEN
						-- Create the Print Command
						l_command := 'swmsprtrpt -c '|| to_char(l_query_seq) || ' -P '|| o_printer_name ||' -Y N -N 1 -w rp1ri'; 

						l_msg := 'Print Command - Command: [' || l_command || ']';
						pl_log.ins_msg('INFO', l_func_name, l_msg, NULL, NULL, APPLICATION_FUNC, PACKAGE_NAME);

						l_print_condition := ' EXISTS (SELECT 1 FROM putawaylst p WHERE p.rec_id = erm_id AND SUBSTR(rec_id,2) = ''' || i_manifest_no || ''' AND SUBSTR(rec_id,1,1) IN (''D'',''S'') AND NVL(RTN_LABEL_PRINTED,''N'') = ''N'')';

						l_msg := 'Print Condition: [' || l_print_condition || ']';
						pl_log.ins_msg('INFO', l_func_name, l_msg, NULL, NULL, APPLICATION_FUNC, PACKAGE_NAME);

                        BEGIN
							INSERT INTO print_query (
								print_query_seq,
								condition)
							VALUES (
								l_query_seq,
								l_print_condition);
							COMMIT;

							EXCEPTION
								WHEN DUP_VAL_ON_INDEX THEN
									UPDATE print_query
									  SET condition = l_print_condition
									WHERE print_query_seq = l_query_seq;
									COMMIT;
								WHEN OTHERS THEN
									l_status := rf.STATUS_DATA_ERROR;
									pl_log.ins_msg('WARN', l_func_name, 'Error on print_query insert', sqlcode, sqlerrm);
                        END;

						IF (l_status = rf.STATUS_NORMAL) THEN
							BEGIN
								l_msg := 'Executing the Report Print Command [' || l_command || ' For User ' || LOWER(REPLACE(USER, 'OPS$', NULL)) || ']';
								pl_log.ins_msg('INFO', l_func_name, l_msg, NULL, NULL, APPLICATION_FUNC, PACKAGE_NAME);
								l_rc := DBMS_HOST_COMMAND_FUNC(LOWER(REPLACE(USER, 'OPS$', NULL)), l_command);

								l_msg := 'Report Print Command Executed. Return Code - [' || l_rc || ']';
								pl_log.ins_msg('INFO', l_func_name, l_msg, NULL, NULL, APPLICATION_FUNC, PACKAGE_NAME);
							EXCEPTION
								WHEN OTHERS THEN
									l_status := rf.STATUS_PRINTING_ERROR;
									l_msg := 'Error encountered while trying to print. Command: ' || l_command || ' SQLERRM: ' || SUBSTR(SQLERRM, 1, 500);
									pl_log.ins_msg('FATAL', l_func_name, l_msg, SQLCODE, SUBSTR(SQLERRM, 1, 500), APPLICATION_FUNC, PACKAGE_NAME);
							END;
						END IF;

						-- Update the PutAwayLst
						IF (l_status = rf.STATUS_NORMAL) THEN
							BEGIN
								-- Update the flags in PutAwayLst
								UPDATE PUTAWAYLST
								   SET rtn_label_printed = 'Y'
								 WHERE SUBSTR(rec_id,2) = to_char(i_manifest_no) AND SUBSTR(rec_id,1,1) IN ('D','S') AND
									   NVL(RTN_LABEL_PRINTED,'N') = 'N';

								l_msg := 'PutAwayLst Table Updated For Manifest: [' || i_manifest_no || ']';
								pl_log.ins_msg('INFO', l_func_name, l_msg, NULL, NULL, APPLICATION_FUNC, PACKAGE_NAME);

								COMMIT;

								EXCEPTION
									WHEN NO_DATA_FOUND THEN
										l_status := rf.STATUS_MAN_NOT_FOUND;
										l_msg := 'PutAwayLst Records Not Found for manifest# [' || i_manifest_no || '] i_wherePrinted is [' || i_wherePrinted || ']';
										pl_log.ins_msg('FATAL', l_func_name, l_msg, SQLCODE, SUBSTR(SQLERRM, 1, 500), APPLICATION_FUNC, PACKAGE_NAME);
									WHEN OTHERS THEN
										l_status := rf.STATUS_DATA_ERROR;
										l_msg := 'Update Of PutAwayLst FAILED for manifest# [' || i_manifest_no || '] i_wherePrinted is [' || i_wherePrinted || ']';
										pl_log.ins_msg('FATAL', l_func_name, l_msg, SQLCODE, SUBSTR(SQLERRM, 1, 500), APPLICATION_FUNC, PACKAGE_NAME);
							END;
						END IF;
					END IF;	-- End Print Query And Command
                END;	-- End Server Printing
                ELSE -- If the flag is NOT and 'M' or 'S'
                BEGIN
                    l_status := rf.status_data_error;
                    l_msg := 'i_wherePrinted is invalid for Print_Return using manifest# [' || i_manifest_no || '] i_wherePrinted is [' || i_wherePrinted || ']';
                    pl_log.ins_msg('WARN', l_func_name, l_msg, null, null, APPLICATION_FUNC, PACKAGE_NAME);
                END;	-- End Invalid Print Location
                END IF;
            END;
            END IF;
        END IF;

        rf.complete(l_status);

        RETURN l_status;
        EXCEPTION
            WHEN OTHERS THEN
                RF.LogException();
            RAISE;
    END print_return;
--   ======================================= End Ben Changes ===================================================

--  ============================================== functions for add=======================================================
/************************************************************************
    --
    -- add_rtn_qry
    --
    -- Description:      Queries Records for given criteria to Add new Returns .
    --      
    -- Parameters:       
    --  i_prod_id       
    --  i_manifest_no   
    --  i_Reason_cd     
    --  i_obligation_no 
    --  i_upc          
    --  i_sos 
    --  o_returned_items_list OUT 
    --
    -- Return/output:    status code indicating success or error.
    --
    -- Modification log:
    --
    -- Date         Developer     Change
    -- ------------------------------------------------------------------
    -- 27-OCT-2020  vkal9662      Initial version.
    -- 01-DEC-2020  vkal9662      changes for NULL_VAL_INDICATOR usage
	  -- 19-Jan-2021    vkal9662    for non overage add qry rtn qty and rtn splitcd 
	  --                            are same as ship qty and ship split code
    -- 08/feb/2021    vkal9662    for reson group STM to send data collection flag as N
    *************************************************************************/
  FUNCTION add_rtn_qry(
      i_manifest_no   IN manifests.manifest_no%TYPE,
      i_Reason_cd     IN Returns.return_reason_cd%type,
      i_obligation_no IN Returns.obligation_no%type,
      i_prod_id       IN PM.prod_id%type,
      i_upc           IN pm.external_upc%type,
      i_sos           IN Varchar2,
      o_returned_items_list OUT rtn_item_table)
    RETURN rf.status
  IS
    l_group reason_cds.reason_group%TYPE;
    l_prod_id returns.prod_id%TYPE ;
    l_category pm.category%TYPE;
    l_wt_trk pm.catch_wt_trk%TYPE := 'N';
    l_temp_trk pm.temp_trk%TYPE   := 'N';
    l_spc pm.spc%TYPE;
    l_split_trk pm.split_trk%TYPE;
    l_descrip pm.descrip%TYPE;
    l_item_list rtn_item_table := rtn_item_table() ;
    l_route_no returns.route_no%type;
    l_msg swms_log.msg_text%TYPE;
    l_status rf.status                                := rf.status_normal;
    l_func_name            CONSTANT swms_log.procedure_name%TYPE := 'add_rtn_qry';
    l_pct_tolerance        NUMBER; -- syspar
    l_max_food_safety_temp NUMBER; -- syspar
    l_obl_cnt number := 0;
    l_erm_line_id number ;
    l_foodsfty_flg varchar2(2);
    l_group2 reason_cds.reason_group%TYPE;
  BEGIN
    BEGIN
      SELECT NVL(MAX(DECODE(config_flag_name, 'FOOD_SAFETY_TEMP_LIMIT', config_flag_val, NULL_VAL_INDICATOR)), NULL_VAL_INDICATOR),
        NVL(MAX(DECODE(config_flag_name, 'PCT_TOLERANCE', config_flag_val,               NULL_VAL_INDICATOR)), NULL_VAL_INDICATOR)
      INTO l_max_food_safety_temp,
        l_pct_tolerance
      FROM sys_config;
      IF (l_max_food_safety_temp = NULL_VAL_INDICATOR) OR (l_pct_tolerance = NULL_VAL_INDICATOR) THEN
        l_status                := rf.status_data_error;
        l_msg                   := 'ERROR: CHECK syspars FOOD_SAFETY_TEMP_LIMIT and PCT_TOLERANCE';
        pl_log.ins_msg('WARN', l_func_name, l_msg, NULL, NULL, APPLICATION_FUNC, PACKAGE_NAME);
      END IF;
    EXCEPTION
    WHEN OTHERS THEN
      l_status := rf.status_data_error;
      l_msg    := 'Unexpected ERROR while trying to get FOOD_SAFETY_TEMP_LIMIT and PCT_TOLERANCE syspars';
      pl_log.ins_msg('FATAL', l_func_name, l_msg, SQLCODE, SUBSTR(SQLERRM, 1, 500), APPLICATION_FUNC, PACKAGE_NAME);
    END; -- datacollect Syspars
    
    
    --- add check if the manifest is of type PAD. if it is then we do not allow add for Overage
    BEGIN
      SELECT reason_group
      INTO l_group
      FROM reason_cds
      WHERE reason_cd_type = 'RTN'
      AND reason_cd        = i_Reason_cd;
    EXCEPTION
    WHEN NO_DATA_FOUND THEN
      return RF.STATUS_INVALID_RSN;
    END;
    
    l_group2 := l_group;
    
    BEGIN
      SELECT route_no
      INTO l_route_no
      FROM manifests
      WHERE manifest_no = i_manifest_no;
    EXCEPTION
    WHEN NO_DATA_FOUND THEN
      dbms_output.put_line('Error retrieving route for manifest:'||i_manifest_no);
    END;
    -- write logic to derive ord_seq
    --write logic to throw error when l_group = 'OVR'and i_prod_id, i_upc are null
    IF l_group = 'OVR'AND i_prod_id IS NULL AND i_upc IS NULL THEN
      RETURN RF.STATUS_INV_NO_REQUIRED;
    END IF;
    IF i_prod_id IS NOT NULL THEN
    
      BEGIN
        SELECT prod_id
        INTO l_prod_id
        FROM pm
        WHERE prod_id =i_prod_id;
      EXCEPTION
      WHEN OTHERS THEN
        RETURN RF.STATUS_INV_PRODID;
      END;
     
    elsif i_upc  IS NOT NULL AND i_prod_id IS NULL THEN
      BEGIN
        SELECT distinct prod_id
        INTO l_prod_id
        FROM pm_upc
        WHERE (external_upc = i_upc
        OR internal_upc     =i_upc);
      EXCEPTION
      WHEN OTHERS THEN
       dbms_output.put_line('Error in upc'|| sqlerrm);
        RETURN RF.STATUS_INVALID_UPC;
      END;
    elsif i_sos IS NOT NULL AND i_prod_id IS NULL THEN
      BEGIN
        SELECT o.prod_id
        INTO l_prod_id
        FROM ordd_for_rtn o,
          manifest_dtls d
        WHERE 1                =1
        AND o.ordd_seq         = i_sos
        AND o.order_id         = DECODE(INSTR(d.obligation_no, 'L'), 0, d.obligation_no, SUBSTR(d.obligation_no, 1, INSTR(d.obligation_no, 'L') - 1))
        AND d.manifest_no      = i_manifest_no
        AND d.prod_id          = o.prod_id
        AND d.cust_pref_vendor = o.cust_pref_vendor;
      EXCEPTION
      WHEN OTHERS THEN
        RETURN RF.STATUS_INV_ITEM_REQUIRED;
      END;
    END IF;
    
    IF i_obligation_no is not Null then 
    
        SELECT count(*) INTO l_obl_cnt
        FROM   manifest_dtls d
        WHERE  d.obligation_no = i_obligation_no
        and manifest_no = i_manifest_no ;
        
        If l_obl_cnt = 0 then
           RETURN RF.STATUS_INV_INVOICE_NO;           
        End If;   
        
        if l_group in ('MPR', 'MPK') then  --- to handle mispic return record update of the mispick item so it can pick up from PM table
              l_group := 'OVR';
        end if;
    END IF;    
    --logic to verify sos lable info use ordd_for_rtn.ordd_seq
    select max(erm_line_id)+1 
    into l_erm_line_id
    from Returns
    where manifest_no = i_manifest_no;
    
    Begin
      SELECT nvl(hc.FOOD_SAFETY_TRK,'N') 
      INTO l_foodsfty_flg
      FROM PM p,HACCP_CODES hc
      WHERE nvl(p.HAZARDOUS,'X') = hc.HACCP_CODE
      AND p.prod_id         = l_prod_id;
    Exception when others then
      l_foodsfty_flg :='N';
    End;
    
    IF l_group in ( 'OVR',  'OVI') THEN  ---- for overage the Items are picked from PM not from the Manifest (--'MPR', 'MPK' these 2 mispick codes removed),
      BEGIN
        SELECT rtn_item_rec(stop_no, rec_type, obligation_no, prod_id, cust_pref_vendor, prod_desc, return_reason_cd, returned_qty, returned_split_cd, 
        catchweight, disposition, returned_prod_id, returned_prod_cpv, returned_prod_desc, erm_line_id, shipped_qty, shipped_split_cd, cust_id, 
        temperature, add_source, status, err_comment, rtn_sent_ind, pod_rtn_ind, lock_chg, order_seq_list, spc, split_trk, temp_trk, catch_wt_trk, food_safety_trk, 
        food_safety_temp, min_temp, max_temp,min_weight,max_weight,max_food_safety_temp, rtn_upc_table()) BULK COLLECT
        INTO l_item_list
        FROM
          (SELECT NULL_VAL_INDICATOR stop_no,
            decode(l_group2, 'OVR','O', 'OVI','O','I') rec_type,
            ' ' obligation_no,
            NVL(p.prod_id, ' ') prod_id,
            '-' cust_pref_vendor,
            NVL(p.descrip, ' ') prod_desc,
            NVL(i_reason_cd, ' ') return_reason_cd,
            0 returned_qty,
            0 returned_split_cd,
            NULL_VAL_INDICATOR catchweight,
            ' ' disposition,
            NVL(p.prod_id, ' ') returned_prod_id,
            NVL(p.cust_pref_vendor, ' ') returned_prod_cpv,
            NVL(p.descrip, ' ') returned_prod_desc,
            l_erm_line_id erm_line_id,
            0 shipped_qty,
            ' ' shipped_split_cd,
            0 cust_id,
            NULL_VAL_INDICATOR temperature,
            'RF' add_source,
            'VAL' status,
            ' ' err_comment,
            ' ' rtn_sent_ind,
            ' ' pod_rtn_ind,
            ' ' lock_chg,
			rtn_order_seq_table() order_seq_list,
            NVL(p.spc, 0) spc,
            NVL(p.split_trk, 'N') split_trk,
            decode(l_group, 'STM', 'N', 'DMG', 'N',NVL(p.temp_trk, 'N')) temp_trk,
            decode(l_group, 'STM', 'N', NVL(p.catch_wt_trk, 'N')) catch_wt_trk,
             decode(l_group, 'STM', 'N', 'DMG', 'N',nvl(l_foodsfty_flg,'N')) food_safety_trk,
            NULL_VAL_INDICATOR food_safety_temp,
            NVL(p.min_temp, NULL_VAL_INDICATOR) min_temp,
            NVL(p.max_temp, NULL_VAL_INDICATOR) max_temp,
            NVL((1 - NVL(l_pct_tolerance, 0)/100) * NVL(p.avg_wt, NULL_VAL_INDICATOR), NULL_VAL_INDICATOR) min_weight,
            NVL((1 + NVL(l_pct_tolerance, 0)/100) * NVL(p.avg_wt, NULL_VAL_INDICATOR), NULL_VAL_INDICATOR) max_weight,
            NVL(l_max_food_safety_temp, NULL_VAL_INDICATOR) max_food_safety_temp
          FROM pm p
          WHERE 1       =1
          AND p.prod_id = l_prod_id );
          
          IF l_item_list.count = 0 THEN 
            pl_log.ins_msg('INFO', l_func_name, 'NO_DATA_FOUND for Manifest, Item: '||i_manifest_no||', '||l_prod_id , SQLCODE, SUBSTR(SQLERRM, 1, 500), APPLICATION_FUNC, PACKAGE_NAME);
            RETURN RF.STATUS_INV_PRODID;
          END IF; 
          
        o_returned_items_list := l_item_list;
      EXCEPTION
     
      WHEN OTHERS THEN
        l_msg := 'ERROR during BULK COLLECT of returns for manifest# [' || i_manifest_no || ']';
        pl_log.ins_msg('FATAL', l_func_name, l_msg, SQLCODE, SUBSTR(SQLERRM, 1, 500), APPLICATION_FUNC, PACKAGE_NAME);
        rf.logexception();
        RAISE;
      END;
    ELSE --l_group  <> 'OVR'
      BEGIN
        SELECT rtn_item_rec(stop_no, rec_type, obligation_no, prod_id, cust_pref_vendor, prod_desc,return_reason_cd, returned_qty, 
               returned_split_cd, catchweight, disposition, returned_prod_id, returned_prod_cpv, returned_prod_desc, erm_line_id, 
               shipped_qty, shipped_split_cd, cust_id, temperature, add_source, status, err_comment, rtn_sent_ind, pod_rtn_ind, lock_chg, 
               order_seq_list, spc, split_trk, temp_trk, catch_wt_trk, food_safety_trk, food_safety_temp,
               min_temp,max_temp, min_weight,max_weight,max_food_safety_temp, rtn_upc_table()) BULK COLLECT
        INTO l_item_list
        FROM
          (SELECT NVL(d.stop_no, NULL_VAL_INDICATOR) stop_no,
            NVL(d.rec_type, 'I') rec_type,
            NVL(d.obligation_no, ' ') obligation_no,
            NVL(d.prod_id, ' ') prod_id,
            NVL(d.cust_pref_vendor, ' ') cust_pref_vendor,
            NVL(p.descrip, ' ') prod_desc,
            NVL(i_reason_cd, ' ') return_reason_cd,
            NVL(d.shipped_qty, 0) returned_qty,
            NVL(d.shipped_split_cd, ' ') returned_split_cd,
            NULL_VAL_INDICATOR catchweight,
            ' ' disposition,
            NVL(d.prod_id, ' ') returned_prod_id,
            NVL(d.cust_pref_vendor, ' ') returned_prod_cpv,
            NVL(p.descrip, ' ') returned_prod_desc,
            l_erm_line_id erm_line_id,
            NVL(d.shipped_qty, 0) shipped_qty,
            NVL(d.shipped_split_cd, ' ') shipped_split_cd,
            0 cust_id,
            NULL_VAL_INDICATOR temperature,
            'RF' add_source,
            'VAL' status,
            ' ' err_comment,
            ' ' rtn_sent_ind,
            ' ' pod_rtn_ind,
            ' ' lock_chg,
            rtn_order_seq_table() order_seq_list,
            NVL(p.spc, 0) spc,
            NVL(p.split_trk, 'N') split_trk,
            decode(l_group, 'STM', 'N','DMG', 'N', NVL(p.temp_trk, 'N')) temp_trk,
            decode(l_group, 'STM', 'N', NVL(p.catch_wt_trk, 'N')) catch_wt_trk,
            decode(l_group, 'STM', 'N','DMG', 'N', nvl(l_foodsfty_flg,'N')) food_safety_trk,
            NULL_VAL_INDICATOR food_safety_temp,
            NVL(p.min_temp, NULL_VAL_INDICATOR) min_temp,
            NVL(p.max_temp, NULL_VAL_INDICATOR) max_temp,
            NVL((1 - NVL(l_pct_tolerance, 0)/100) * NVL(p.avg_wt, NULL_VAL_INDICATOR), NULL_VAL_INDICATOR) min_weight,
            NVL((1 + NVL(l_pct_tolerance, 0)/100) * NVL(p.avg_wt, NULL_VAL_INDICATOR), NULL_VAL_INDICATOR) max_weight,
            NVL(l_max_food_safety_temp, NULL_VAL_INDICATOR) max_food_safety_temp
          FROM manifest_dtls d, pm p
          WHERE d.manifest_no    = i_manifest_no
          AND d.prod_id          = l_prod_id
          AND p.prod_id          = d.prod_id
          AND p.cust_pref_vendor = d.cust_pref_vendor
          AND NVL(d.rec_type, 'I') <>'P'
          AND NVL(d.shipped_qty,0) <> 0
          AND d.obligation_no    = NVL(i_obligation_no, d.obligation_no)
          AND NOT EXISTS (SELECT 'X'   -- do notpick this item if it is part of an invoice return
                          FROM returns r,  reason_cds g
                          WHERE r.return_reason_cd    = g.reason_cd
                          AND g.reason_cd_type = 'RTN'
                          AND g.reason_group   = 'WIN'
                          AND r.manifest_no    = d.manifest_no
                          AND r.obligation_no  = d.obligation_no
                          AND r.prod_id        = d.prod_id )  );
          
          IF l_item_list.count = 0 THEN 
            pl_log.ins_msg('INFO', l_func_name, 'NO_DATA_FOUND for Manifest, Item: '||i_manifest_no||', '||l_prod_id , SQLCODE, SUBSTR(SQLERRM, 1, 500), APPLICATION_FUNC, PACKAGE_NAME);
            RETURN RF.STATUS_INV_PRODID;
          END IF; 
        
        o_returned_items_list := l_item_list;
      EXCEPTION
      
      WHEN OTHERS THEN
        l_msg := 'ERROR during BULK COLLECT of returns for manifest# [' || i_manifest_no || ']';
        pl_log.ins_msg('FATAL', l_func_name, l_msg, SQLCODE, SUBSTR(SQLERRM, 1, 500), APPLICATION_FUNC, PACKAGE_NAME);
        rf.logexception();
        RAISE;
      END;
    END IF; -- l_group  = 'OVR'
    RETURN rf.status_normal;
  END add_rtn_qry;

--  ------------------------------------------------------------------------
/************************************************************************
    --
    -- get_add_rtn_rf
    --
    -- Description:      Queries Records for given criteria to Add new Returns from RF.
    --      
    -- Parameters:       
    --  i_prod_id       
    --  i_manifest_no   
    --  i_Reason_cd     
    --  i_obligation_no 
    --  i_upc          
    --  i_sos 
    --  o_returned_items_list OUT 
    --
    -- Return/output:    status code indicating success or error.
    --
    -- Modification log:
    --
    -- Date         Developer     Change
    -- ------------------------------------------------------------------
    -- 27-OCT-2020  vkal9662      Initial version.
    --
    *************************************************************************/
  FUNCTION get_add_rtn_rf(
      i_rf_log_init_rec IN rf_log_init_record,
      i_manifest_no     IN manifests.manifest_no%TYPE,
      i_Reason_cd       IN Returns.return_reason_cd%type,
      i_obligation_no   IN Returns.obligation_no%type,
      i_prod_id         IN pm.prod_id%type,
      i_upc             IN pm.external_upc%type,
      i_sos             IN  Varchar2,
      o_returned_items_list   OUT rtn_validation_obj)
      RETURN rf.status  IS

    l_status rf.status        := rf.status_normal;
    l_addrtn_status rf.status := rf.status_normal;
    l_msg swms_log.msg_text%TYPE;
    l_func_name CONSTANT swms_log.procedure_name%TYPE := 'Get_Add_rtn_rf';
    l_item_list rtn_item_table                        := rtn_item_table() ;
    l_route_no VARCHAR2(10);
  BEGIN

    o_returned_items_list := rtn_validation_obj(i_manifest_no, 'N', ' ', rtn_item_table());
    -- Call rf.initialize(). cannot procede if return status is not successful.
    l_status := rf.initialize(i_rf_log_init_rec);
    -- Log the input received from the RF client
    l_msg := 'Starting ' || l_func_name|| '. Received manifest# from RF client: ['|| i_manifest_no|| ']';
    pl_log.ins_msg('INFO', l_func_name, l_msg, NULL, NULL, APPLICATION_FUNC, PACKAGE_NAME);
    -- perform the business logic of the function by calling the business logic function
    IF l_status          = rf.status_normal THEN
      l_status    := add_rtn_qry(i_manifest_no, i_Reason_cd,i_obligation_no, i_prod_id,i_upc, i_sos, l_item_list);
      IF l_status = rf.status_normal THEN
          o_returned_items_list.item_list  := l_item_list;
      END IF;
    END IF;
    rf.complete(l_status);
    RETURN l_status  ;
  EXCEPTION
  WHEN OTHERS THEN
    l_msg := 'ERROR in Get_Add_rtn_rf() for manifest# ['|| i_manifest_no|| ']';
    pl_log.ins_msg('FATAL', l_func_name, l_msg, SQLCODE, SUBSTR(SQLERRM, 1, 500), APPLICATION_FUNC, PACKAGE_NAME);
    rf.logexception();
    RAISE;
  END get_add_rtn_rf;

  --===================================================== createputs functions=======================================
  /************************************************************************
    --
    -- update_mf_pallet_type
    --
    -- Description:      Internal process to update mf_pallet.
    --      
    -- Return/output:    p_message indicating success or error.
    --
    -- Modification log:
    --
    -- Date         Developer     Change
    -- ------------------------------------------------------------------
    -- 15-OCT-2020  vkal9662      Initial version.
    --
    *************************************************************************/
  PROCEDURE update_mf_pallet_type
(  prod_id          in VARCHAR2,
   cust_pref_vendor in VARCHAR2,
   pallet_type      in VARCHAR2,
   p_message        out VARCHAR2)  IS

   cpv                 VARCHAR2(10);
   data_str            VARCHAR2(22);
   data_str_len        NUMBER := 22;
   l_hstcl_rc VARCHAR2(500); --return code for Host_Command Call
BEGIN

--
   IF cust_pref_vendor = '-' THEN
      cpv := ' ';
   ELSE
      cpv := cust_pref_vendor;
   END IF;
   data_str := 'P' ||LPAD(prod_id, 9, ' ')
                   ||LPAD(cpv, 10, ' ')
                   ||LPAD(pallet_type, 2, ' ')   ;


    IF pl_common.f_get_syspar('HOST_COMM', 'APCOM') != 'STAGING TABLES' THEN
      Begin
            l_hstcl_rc :=DBMS_HOST_COMMAND_FUNC('swms', 'write_apcom_queue '||'PL_DCI_POD'
            ||' LM "'||data_str||'" '||TO_CHAR(data_str_len)||' 10 ');
        Exception when Others then
         p_message := STRING_TRANSLATION.GET_STRING(4353);
      End;
  END IF;

END;

 /************************************************************************
    --
    -- create_trans_rec
    --
    -- Description:      Internal process to create transrecords.
    --      
    -- Return/output:    p_message indicating success or error.
    --
    -- Modification log:
    --
    -- Date         Developer     Change
    -- ------------------------------------------------------------------
    -- 15-OCT-2020  vkal9662      Initial version.
    --
    *************************************************************************/
procedure create_trans_rec (p_prod_id in VARCHAR2,p_cpv in VARCHAR2,
                            p_dest_loc in VARCHAR2,p_pallet_id in VARCHAR2,
                            p_new_pallet in VARCHAR2,
                            p_message out VARCHAR2) is
begin



  declare
  p_old_pallet pm.pallet_type%type;
   cursor trans_cur is
   select pallet_type
   from pm
   where prod_id = p_prod_id
   and cust_pref_vendor = p_cpv;
begin
  open trans_cur;
  fetch trans_cur into p_old_pallet ;
  if trans_cur%notfound then
    p_message := STRING_TRANSLATION.GET_STRING(6498);

  end if;
  if    (nvl(p_old_pallet,'*') != nvl(p_new_pallet,'*')) then
   insert into trans
     (trans_id,trans_type,trans_date,user_id,
      prod_id,upload_time,cust_pref_vendor, dest_loc, pallet_id,cmt)
   select trans_id_seq.nextval,'IMT',sysdate,USER, p_prod_id,
       sysdate, p_cpv, p_dest_loc, p_pallet_id,
      STRING_TRANSLATION.GET_STRING(11553) || p_old_pallet ||
      STRING_TRANSLATION.GET_STRING(8876) || p_new_pallet
   from dual ;
  end if;
end;
end;

  /************************************************************************
    -- get_dest_loc 
    --
    -- Description:      Internal process to get destination location during create puts.
    --      
    -- Return/output:    o_rtn_err: status code indicating success or error.
    --
    -- Modification log:
    --
    -- Date         Developer     Change
    -- ------------------------------------------------------------------
    -- 15-OCT-2020  vkal9662      Initial version.
    --
    *************************************************************************/
PROCEDURE get_dest_loc (i_prod_id   IN  putawaylst.prod_id%TYPE,
                        i_cpv       IN  putawaylst.cust_pref_vendor%TYPE,
                        i_uom       IN  returns.returned_split_cd%TYPE,
                        o_dest_loc  OUT putawaylst.dest_loc%TYPE,
                        o_logi_loc  OUT putawaylst.pallet_id%TYPE,
                        o_found_float   OUT BOOLEAN,
                        o_rtn_err OUT returns.err_comment%TYPE) IS
   l_zone_id        zone.zone_id%TYPE;
   l_pallet_type    pallet_type.pallet_type%TYPE;
   l_last_ship_slot pm.last_ship_slot%TYPE;
   l_last_pik_path  loc.pik_path%TYPE;
   l_near_path      loc.pik_path%TYPE;
   l_new_paltype    pallet_type.pallet_type%TYPE;
   l_existed        VARCHAR2(1);
   liStatus     NUMBER;
   l_message   VARCHAR2(250);

   CURSOR c_put_home(cp_prod_id VARCHAR2, cp_cpv VARCHAR2, cp_uom VARCHAR2) IS
      SELECT logi_loc
      FROM loc
      WHERE prod_id = cp_prod_id
      AND   cust_pref_vendor = cp_cpv
      AND   NVL(uom, 0) IN (0, 2 - TO_NUMBER(cp_uom))
      AND   status = 'AVL'
      AND   perm = 'Y'
      AND   rank = 1;
   CURSOR c_inv_loc_curs(cp_prod_id VARCHAR2, cp_cpv VARCHAR2) is
      SELECT NVL(i.plogi_loc, 'FFFFFF'), NVL(i.logi_loc, 'FFFFFF')
      FROM zone z, inv i, pm p, lzone lz
      WHERE i.prod_id = cp_prod_id
      AND   i.cust_pref_vendor = cp_cpv
      AND   i.prod_id = p.prod_id
      AND   i.status = 'AVL'
      AND   i.cust_pref_vendor = p.cust_pref_vendor
      AND   NOT EXISTS (SELECT 'x'
                        FROM loc
                        WHERE prod_id = cp_prod_id
                        AND   cust_pref_vendor = cp_cpv)
      AND   z.zone_id = p.zone_id
      AND   z.zone_type = 'PUT'
      AND   z.rule_id = 1
      AND   z.zone_id = lz.zone_id
      AND   lz.logi_loc = i.plogi_loc
      AND   i.qoh + i.qty_planned > 0
      ORDER BY i.exp_date, i.qoh, i.logi_loc;
   CURSOR c_put_zone(cp_prod_id VARCHAR2, cp_cpv VARCHAR2) IS
      SELECT p.zone_id, p.pallet_type, NVL(p.last_ship_slot, 'FFFFFF')
      FROM pallet_type pa, zone z, pm p
      WHERE p.prod_id = cp_prod_id
      AND   p.cust_pref_vendor = cp_cpv
      AND   p.zone_id = z.zone_id
      AND   z.zone_type = 'PUT'
      AND   z.rule_id = 1
      AND   p.pallet_type = pa.pallet_type;
   CURSOR c_put_float_open(cp_zone_id VARCHAR2, cp_paltype VARCHAR2) IS
      SELECT l.logi_loc, l.logi_loc
      FROM loc l, lzone lz
      WHERE  lz.zone_id  = cp_zone_id
      AND    lz.logi_loc = l.logi_loc
      AND    l.status = 'AVL'
      AND    l.pallet_type = cp_paltype
      AND    NOT EXISTS (SELECT NULL FROM inv WHERE inv.plogi_loc = l.logi_loc);
   CURSOR c_put_float_new(cp_zone_id VARCHAR2) IS
      SELECT l.logi_loc, l.logi_loc, l.pallet_type
      FROM   loc l, lzone lz
      WHERE  lz.zone_id  = cp_zone_id
      AND    lz.logi_loc = l.logi_loc
      AND    l.STATUS = 'AVL'
      AND    NOT EXISTS (SELECT 'X' FROM inv WHERE inv.plogi_loc = l.logi_loc);
   CURSOR c_last_pik_path(cp_prod_id VARCHAR2, cp_last_ship VARCHAR2) IS
      SELECT NVL(PIK_PATH, 9999999999)
      FROM   loc
      WHERE  logi_loc = cp_last_ship
      AND    status = 'AVL'
      AND    prod_id IS NULL
      AND    NOT EXISTS (SELECT 'x' FROM inv
                         WHERE plogi_loc = cp_last_ship
                         AND   prod_id <> cp_prod_id);
   CURSOR c_put_float
          (cp_zone_id VARCHAR2, cp_paltype VARCHAR2,
           cp_lastship VARCHAR2, cp_last_path NUMBER) IS
      SELECT l.logi_loc, l.logi_loc,
             l.pik_path - cp_last_path
      FROM   loc l, lzone lz
      WHERE  lz.zone_id  = cp_zone_id
      AND    lz.logi_loc = l.logi_loc
      AND    l.status = 'AVL'
      AND    l.pallet_type = cp_paltype
      AND    l.CUBE >= (SELECT NVL(CUBE, 0)
                        FROM loc
                        WHERE loc.logi_loc = cp_lastship)
      AND    NOT EXISTS (SELECT NULL FROM inv WHERE inv.plogi_loc = l.logi_loc)
      ORDER BY 3;
   CURSOR c_put_float_diff_type
         (cp_zone_id VARCHAR2, cp_lastship VARCHAR2, cp_last_path NUMBER) IS
      SELECT l.logi_loc, l.logi_loc, l.pallet_type,
             l.pik_path - cp_last_path
      FROM   loc l, lzone lz
      WHERE  lz.zone_id = cp_zone_id
      AND    lz.logi_loc = l.logi_loc
      AND    l.status = 'AVL'
      AND    l.cube >= (SELECT NVL(CUBE, 0)
                        FROM loc
                        WHERE loc.logi_loc = cp_lastship)
      AND     NOT EXISTS (SELECT NULL FROM inv WHERE inv.plogi_loc = l.logi_loc)
      ORDER BY 4;

  CURSOR c_has_other_item(cp_loc VARCHAR2, cp_prod_id VARCHAR2, cp_cpv VARCHAR2) IS
     SELECT 'Y'
        FROM inv
        WHERE plogi_loc = cp_loc
        AND   cust_pref_vendor = cp_cpv
        AND   status = 'AVL'
        AND   prod_id <> cp_prod_id;
  v_avl char(1);




  l_mf_message varchar2(250);
BEGIN
   o_dest_loc    := NULL;
   o_logi_loc    := NULL;
   o_found_float := FALSE;


   if pl_matrix_common.chk_matrix_enable = TRUE and i_uom != 1 then
       if pl_matrix_common.chk_prod_mx_assign(i_prod_id) = TRUE and pl_matrix_common.chk_prod_mx_eligible(i_prod_id) = TRUE then
            o_found_float := TRUE;
          o_dest_loc := nvl(pl_matrix_common.f_get_mx_dest_loc(i_prod_id), '*');
          o_logi_loc := o_dest_loc;
          return;
       end if;
   end if;

   -- Is this a mini load?
   pl_ml_common.get_induction_loc(i_prod_id, i_cpv, TO_NUMBER(i_uom),
                                  liStatus, o_dest_loc);
   if (liStatus = 0) then
  dbms_output.put_line( STRING_TRANSLATION.GET_STRING(6530)||i_prod_id||i_uom||o_dest_loc);
        o_logi_loc := o_dest_loc;
        o_found_float := TRUE;
        return;
   end if;
   --
   -- Look for a home slot for the item
   --
   OPEN  c_put_home(i_prod_id, i_cpv, i_uom);
   FETCH c_put_home INTO o_dest_loc;
   IF c_put_home%FOUND THEN
      CLOSE c_put_home;
      o_logi_loc := o_dest_loc;

  --     dbms_output.put_line('Home slot found'||i_prod_id||i_uom||o_dest_loc);

      o_found_float := FALSE;
      RETURN;
   END IF;
   CLOSE c_put_home;

   --
   -- no home slot, look for a FLOAT location with the item in it,
   -- having oldest expiration date  least QOH
   --
   OPEN  c_inv_loc_curs(i_prod_id, i_cpv);
   FETCH c_inv_loc_curs into o_dest_loc, o_logi_loc;
   IF c_inv_loc_curs%FOUND THEN
      CLOSE c_inv_loc_curs;
      o_found_float:= TRUE;
      --    Inventory for the item is found in a floating
      --    slot. Compared with a home slot that can only have one and only
      --    one item in it, a floating slot can hold different items normally.
      --    But during returns processing, we want to put only 1 item in a
      --    floating slot. If the floating slot also contains another item
      --    by the time the return is being processed, we need to search
      --    for a new floating slot to hold this returned item

      l_existed := NULL;
      OPEN c_has_other_item(o_dest_loc, i_prod_id, i_cpv);
      FETCH c_has_other_item INTO l_existed;
      IF c_has_other_item%NOTFOUND THEN
         -- The floating slot only has this item
         CLOSE c_has_other_item;
         RETURN;
      END IF;
      CLOSE c_has_other_item;
   END IF;
   IF c_inv_loc_curs%ISOPEN THEN
      CLOSE c_inv_loc_curs;
   END IF;

   --
   -- since no home slot was found and no inventory record
   -- exists, check the item's put zone, if it is a floatingzone
   -- we MIGHT NOT NEED PALLET_TYPE BELOW IF NO PALLET-TYPECHECK

   -- Added check on cube >= last_ship_slot_cube for floating loc.
   -- If none of the locations can be located, return failure.
   --
   OPEN  c_put_zone(i_prod_id, i_cpv);
   FETCH c_put_zone INTO  l_zone_id, l_pallet_type, l_last_ship_slot;
   IF c_put_zone%NOTFOUND THEN
      CLOSE c_put_zone;

      o_rtn_err :=STRING_TRANSLATION.GET_STRING(6531 ,i_prod_id ,i_cpv);

      RAISE no_data_found;
   END IF;
   CLOSE c_put_zone;

   o_found_float := TRUE;   --  found a floating slot

   -- If last_ship_slot is found, check if a different
   --    item was already occupied it
   IF l_last_ship_slot <> 'FFFFFF' THEN
      l_existed := NULL;
      OPEN c_has_other_item(l_last_ship_slot, i_prod_id, i_cpv);
      FETCH c_has_other_item INTO l_existed;
      IF c_has_other_item%FOUND THEN
         -- A different item is in the last_ship_slot currently. We need to
         -- find a new floating slot to hold the item
         l_last_ship_slot := 'FFFFFF';
      END IF;
      CLOSE c_has_other_item;
   END IF;

   --
   -- Below this any time DESTLOC found then returns SUCCESS.
   -- Else returns FAILURE and p-foundfloat set FALSE.
   --
   IF l_last_ship_slot = 'FFFFFF' THEN
   --
   -- Item does not have a last_ship_slot in the item master
   -- Need to find the first open slot with same
   -- pallet_type in the floating zone OR different pallet type.
   --
      OPEN  c_put_float_open(l_zone_id, l_pallet_type);
      FETCH c_put_float_open INTO o_dest_loc, o_logi_loc;
      IF c_put_float_open%FOUND THEN
         CLOSE c_put_float_open;
         --
         -- update the last ship slot with the new
         -- slot found for the product
         --
         BEGIN
            UPDATE pm
               SET last_ship_slot = o_dest_loc
               WHERE prod_id = i_prod_id
               AND   cust_pref_vendor = i_cpv;

            RETURN;

            EXCEPTION
               WHEN NO_DATA_FOUND THEN
                  NULL;
               WHEN OTHERS THEN
                 o_rtn_err := STRING_TRANSLATION.GET_STRING(6532 ,i_prod_id);
                 o_found_float := FALSE;

         END;
      END IF;
      CLOSE c_put_float_open;

    /*  IF (NVL(:master.upd_item_pt_return, ' ') != 'Y') THEN

         o_rtn_err := STRING_TRANSLATION.GET_STRING(6533 ,i_prod_id);
         RAISE no_data_found;
      END IF;*/ -- review this code

      OPEN  c_put_float_new(l_zone_id);
      FETCH c_put_float_new INTO o_dest_loc, o_logi_loc, l_new_paltype;
      IF c_put_float_new%NOTFOUND THEN
         CLOSE c_put_float_new;

         o_rtn_err := STRING_TRANSLATION.GET_STRING(6534 ,i_prod_id);
         RAISE no_data_found;
      END IF;
      CLOSE c_put_float_new;

      -- Create trans IMT when pallet type change in PM
      create_trans_rec(i_prod_id, i_cpv, o_dest_loc, o_logi_loc, l_new_paltype,l_message);

      BEGIN
         UPDATE pm
            SET last_ship_slot = o_dest_loc, pallet_type = l_new_paltype
            WHERE prod_id = i_prod_id
            AND   cust_pref_vendor = i_cpv;

         EXCEPTION
            WHEN NO_DATA_FOUND THEN
               NULL;
            WHEN OTHERS THEN

                 o_rtn_err := STRING_TRANSLATION.GET_STRING(6535 ,i_prod_id);
                 o_found_float := FALSE;

      END;

      update_mf_pallet_type(i_prod_id, i_cpv, l_new_paltype, l_mf_message);

      RETURN;
   END IF;   -- last-ship=FFFFFF

   --
   -- Since last ship slot exists, get the pik_path for the location.
   -- Try to put product back in that slot, if it is open
   -- or put in FIRST location (in floating zone) closest to
   -- last ship slot of same pallet type OR different pallet type.
   --
   l_existed := 'N';
   OPEN  c_last_pik_path(i_prod_id, l_last_ship_slot);
   FETCH c_last_pik_path INTO l_last_pik_path;
   IF c_last_pik_path%FOUND THEN
      BEGIN
         SELECT 'Y' INTO l_existed
            FROM inv
            WHERE plogi_loc = l_last_ship_slot
            AND   prod_id <> i_prod_id;

         EXCEPTION
            WHEN NO_DATA_FOUND THEN
               o_dest_loc := l_last_ship_slot;
            WHEN TOO_MANY_ROWS THEN
               l_existed := 'Y';
      END;
      IF l_existed <> 'Y' THEN
         o_dest_loc := l_last_ship_slot;
      END IF;
      RETURN;
   END IF;
   CLOSE c_last_pik_path;

   OPEN c_put_float
        (l_zone_id, l_pallet_type, l_last_ship_slot, l_last_pik_path);
   FETCH c_put_float INTO o_dest_loc, o_logi_loc, l_near_path;
   IF c_put_float%FOUND THEN
      CLOSE c_put_float;
      RETURN;
   END IF;
   CLOSE c_put_float;
 /*  IF (NVL(:master.upd_item_pt_return, ' ') != 'Y') THEN

       o_rtn_err := STRING_TRANSLATION.GET_STRING(6536 ,i_prod_id);
       o_found_float := FALSE;
      RAISE no_data_found;
   END IF;*/  --review this code

   OPEN  c_put_float_diff_type
         (l_zone_id, l_last_ship_slot, l_last_pik_path);
   FETCH c_put_float_diff_type
      INTO  o_dest_loc, o_logi_loc, l_new_paltype, l_near_path;
   IF c_put_float_diff_type%NOTFOUND THEN
      CLOSE c_put_float_diff_type;

       o_rtn_err := STRING_TRANSLATION.GET_STRING(6537 ,i_prod_id);
       o_found_float := FALSE;
      RAISE no_data_found;
   END IF;
   CLOSE c_put_float_diff_type;

   -- Create trans IMT when pallet type change in PM
   create_trans_rec(i_prod_id, i_cpv, o_dest_loc, o_logi_loc, l_new_paltype,l_message);


   BEGIN
      UPDATE pm
         SET last_ship_slot = o_dest_loc,
             pallet_type = l_new_paltype
         WHERE prod_id = i_prod_id
         AND   cust_pref_vendor = i_cpv;

      EXCEPTION
         WHEN NO_DATA_FOUND THEN
            NULL;
         WHEN OTHERS THEN

             o_rtn_err := STRING_TRANSLATION.GET_STRING(6535 ,i_prod_id);
             o_found_float := FALSE;

     END;

   update_mf_pallet_type(i_prod_id, i_cpv, l_new_paltype, l_mf_message);

   EXCEPTION
      WHEN NO_DATA_FOUND THEN
      --
      -- No floating PUT zone found for the item AND
      -- No OPEN slot found in the FLOATING zone for the item

         o_dest_loc := '*';
         o_logi_loc := NULL;
         o_found_float := FALSE;

         if  o_rtn_err is null then
           o_rtn_err := 'error in get_des_loc';
         end if;

       --  o_rtn_err :=STRING_TRANSLATION.GET_STRING(6538 ,i_prod_id);

        return;
         /*
         ** Don't raise failure here
         ** because the item can then still be putawayed with the destinaton
         ** location of '*' that the user needs to put in a location on the
         ** check-in screen*/

      WHEN OTHERS THEN
         IF c_put_home%ISOPEN       THEN CLOSE c_put_home; END IF;
         IF c_inv_loc_curs%ISOPEN   THEN CLOSE c_inv_loc_curs; END IF;
         IF c_put_zone%ISOPEN       THEN CLOSE c_put_zone; END IF;
         IF c_put_float_open%ISOPEN THEN CLOSE c_put_float_open; END IF;
         IF c_put_float_new%ISOPEN  THEN CLOSE c_put_float_new; END IF;
         IF c_last_pik_path%ISOPEN  THEN CLOSE c_last_pik_path; END IF;
         IF c_put_float%ISOPEN      THEN CLOSE c_put_float; END IF;
         IF c_put_float_diff_type%ISOPEN THEN CLOSE c_put_float_diff_type; END IF;
         o_rtn_err := STRING_TRANSLATION.GET_STRING(6539,i_prod_id);


END;

  

 /************************************************************************
    -- insrt_putaway
    --
    -- Description:  Internal process to insrt putaway record during create puts.
    --      
    -- Return/output: o_rtn_err indicating error comment.
    --
    -- Modification log:
    --
    -- Date         Developer     Change
    -- ------------------------------------------------------------------
    -- 15-OCT-2020  vkal9662      Initial version.
    -- 10-07-2021   vkal9662      Jira 3506 xdock logic added for putawy staging loc
    *************************************************************************/
PROCEDURE insrt_putaway (p_manifest_no number,
                   i_stop_no     IN returns.stop_no%TYPE,
                   i_rec_type    IN returns.rec_type%TYPE,
                   i_ob_no       IN returns.obligation_no%TYPE,
                   i_prod_id     IN returns.prod_id%TYPE,
                   i_cpv         IN returns.cust_pref_vendor%TYPE,
                   i_reason      IN returns.return_reason_cd%TYPE,
                   i_rtn_qty     IN returns.returned_qty%TYPE,
                   i_rtn_uom     IN returns.returned_split_cd%TYPE,
                   i_wt_trk  IN pm.catch_wt_trk%TYPE,
                   i_weight  IN returns.catchweight%TYPE,
                   i_rtn_prod_id IN returns.returned_prod_id%TYPE,
                   i_erm_line_id IN returns.erm_line_id%TYPE,
                   i_temp_trk    IN pm.temp_trk%TYPE,
                   i_temperature IN returns.temperature%TYPE,
                   i_xdock_ind   IN returns.xdock_ind%TYPE,
                   i_site_from   IN returns.site_from%TYPE,
                   o_rtn_err out returns.err_comment%TYPE ) IS
   l_group      reason_cds.reason_group%TYPE;
   l_prod_id        returns.prod_id%TYPE := i_prod_id;
   l_cpv        returns.cust_pref_vendor%TYPE := i_cpv;
   l_cpv_out        returns.cust_pref_vendor%TYPE;
   l_category       pm.category%TYPE;
   l_wt_trk     pm.catch_wt_trk%TYPE := 'N';
   l_temp_trk       pm.temp_trk%TYPE := 'N';
   l_spc        pm.spc%TYPE;
   l_split_trk      pm.split_trk%TYPE;
   l_descrip        pm.descrip%TYPE;
   l_not_found      BOOLEAN;
   l_mispick        putawaylst.mispick%TYPE := 'N';
   l_rec_id     putawaylst.rec_id%TYPE := 'S' || TO_CHAR(p_manifest_no);
   l_dest_loc       putawaylst.dest_loc%TYPE := NULL;
   l_logi_loc       putawaylst.pallet_id%TYPE := NULL;
   l_found_float    BOOLEAN := FALSE;
   l_orig_invoice   manifest_dtls.orig_invoice%TYPE;
   l_existed        VARCHAR2(1);
   l_chk_trans      BOOLEAN;
   l_erm_id     erm.erm_id%TYPE;
   l_pallet_id      putawaylst.pallet_id%TYPE;
   l_chk_pallet     BOOLEAN;
   l_rtn_qty        inv.qty_planned%TYPE := 0;
   l_case_cube      pm.case_cube%TYPE := 0;
   l_abc        pm.abc%TYPE := 'A';
   l_pallet_type    pm.pallet_type%TYPE := NULL;
   l_skid_cube      pallet_type.skid_cube%TYPE := 0;
   l_putaway_status putawaylst.status%TYPE := 'NEW';
   l_putaway_inv_status putawaylst.inv_status%TYPE := 'AVL';
   l_uom        manifest_dtls.shipped_split_cd%TYPE;
   l_num_tbatches   NUMBER := 0;
   l_rtn_lm_syspars pl_rtn_lm.trecRtnLmFlags := NULL;
   l_tbatches       pl_rtn_lm.ttabBatches;
   l_status     NUMBER := 0;
   l_message        VARCHAR2(4000) := NULL;
   l_rtn_date           DATE;
   l_rtn_err returns.err_comment%TYPE;
   l_pallet_id2 varchar2(25);
    cp_flag VARCHAR2(1);
    l_func_name CONSTANT swms_log.procedure_name%TYPE := 'insrt_putaway';

   CURSOR c_get_case_cube (cp_prod_id VARCHAR2, cp_cpv VARCHAR2) IS
      SELECT case_cube, pallet_type, abc
         FROM pm
         WHERE prod_id = cp_prod_id
         AND   cust_pref_vendor = cp_cpv;
   CURSOR c_get_skid_cube_w_pallet_type (cp_pallet_type VARCHAR2) IS
      SELECT  skid_cube
         FROM pallet_type
         WHERE pallet_type = cp_pallet_type;
   CURSOR c_get_skid_cube_wo_pallet_type (cp_logi_loc VARCHAR2) IS
      SELECT  pa.skid_cube
         FROM loc l, pallet_type pa
         WHERE l.logi_loc = cp_logi_loc
         AND   l.pallet_type = pa.pallet_type;
   CURSOR c_get_orig_invoice (cp_uom VARCHAR2) IS
      SELECT DECODE(rec_type,
                    'D', SUBSTR(orig_invoice, 1, INSTR(orig_invoice, 'L') - 1),
                    orig_invoice)
      FROM manifest_dtls
      WHERE manifest_no = p_manifest_no
      AND   obligation_no = i_ob_no
      AND   prod_id = i_prod_id
      AND   cust_pref_vendor = i_cpv
      AND   (cp_uom IS NULL OR shipped_split_cd = cp_uom);
BEGIN

--l_group := get_rtn_reason_group(i_reason);



  BEGIN
      SELECT reason_group INTO l_group
      FROM reason_cds
      WHERE reason_cd_type = 'RTN'
      AND   reason_cd = i_reason;
  EXCEPTION
      WHEN NO_DATA_FOUND THEN
        l_group := 'XXX';
  END;

   IF l_group  IN ('STM', 'MPK') THEN
      -- No putaway task for the specified reason groups
      RETURN;
   END IF;

   IF NVL(i_rtn_qty, 0) = 0 THEN
      -- No putaway task for 0 return, including pickups
      RETURN;
   END IF;

   IF l_group = 'MPR' THEN
      l_prod_id := i_rtn_prod_id;
   END IF;
   IF l_group IN ('MPR', 'OVI', 'OVR') THEN
      l_mispick := 'Y';
   END IF;

 Begin
 

  If i_cpv is null then
    cp_flag := 'N';
   else
    cp_flag := 'Y';
   end If;

 SELECT cust_pref_vendor, descrip, spc,category, catch_wt_trk, temp_trk, split_trk
   into    l_cpv_out,l_descrip,l_spc,l_category, l_wt_trk,l_temp_trk, l_split_trk
      FROM pm
      WHERE prod_id = l_prod_id
      AND   ((cp_flag = 'N') OR
             ((cp_flag = 'Y') AND (cust_pref_vendor = l_cpv)));

 Exception when others then
    dbms_output.put_line('Error retrieving PM Info:'||i_prod_id);
 End;


   IF l_group IN ('MPR', 'MPK') THEN
      l_cpv := l_cpv_out;
   END IF;

   IF l_group = 'DMG' THEN
      l_erm_id := 'D' || TO_CHAR(p_manifest_no);
      l_dest_loc := 'DDDDDD';
      l_putaway_status := ' ';
      l_putaway_inv_status := ' ';
      l_mispick := NULL;
   ELSE
      l_erm_id := 'S' || TO_CHAR(p_manifest_no);

-- add logic to check if the return is an xdock returns or regular return jira 3506
   IF i_xdock_ind = 'X' then
     pl_rtn_xdock_interface.get_xdock_dest_loc(i_site_from,l_prod_id, l_dest_loc, l_rtn_err);
     l_found_float := FALSE;
   Else
     get_dest_loc(l_prod_id, l_cpv,
                   i_rtn_uom,
                   l_dest_loc, l_logi_loc, l_found_float, l_rtn_err);
   END IF;

       if  l_rtn_err is not null then
        o_rtn_err := l_rtn_err;
    --    dbms_output.put_line( 'destination location not found :' ||l_dest_loc);
         Return;
       end if;
   END IF;
   -- Default to manifest detail invoice #. It can be a pickup or regular
   -- invoice#.
   l_orig_invoice := i_ob_no;
   OPEN c_get_orig_invoice(i_rtn_uom);
   FETCH c_get_orig_invoice INTO l_orig_invoice;
   IF c_get_orig_invoice%NOTFOUND THEN
      -- The current returned uom is not found. Try again to use the
      -- opposite uom.
      IF i_rtn_uom = '0' THEN
         l_uom := '1';
      ELSE
         l_uom := '0';
      END IF;
      CLOSE c_get_orig_invoice;
      OPEN c_get_orig_invoice(l_uom);
      FETCH c_get_orig_invoice INTO l_orig_invoice;
      IF c_get_orig_invoice%NOTFOUND THEN
         IF i_rec_type <> 'P' THEN
            l_orig_invoice := i_ob_no;
         ELSE
            l_orig_invoice := NULL;
         END IF;
      ELSE
         IF l_orig_invoice IS NULL THEN
            IF i_rec_type <> 'P' THEN
               l_orig_invoice := i_ob_no;
            END IF;
         END IF;
      END IF;
   ELSE
      IF l_orig_invoice IS NULL THEN
         IF i_rec_type <> 'P' THEN
            -- If no orig_invoice on pickup, don't put it
            l_orig_invoice := i_ob_no;
         END IF;
      END IF;
   END IF;
   CLOSE c_get_orig_invoice;


   -- Don't create putaway task if the item has been putawayed or is there
   l_existed := 'N';
   l_chk_trans := FALSE;
   BEGIN
      SELECT putaway_put, pallet_id INTO l_existed, l_pallet_id2--:work.l_pallet_id
         FROM putawaylst
         WHERE rec_id = l_erm_id
         AND   prod_id = l_prod_id
         AND   cust_pref_vendor = l_cpv
         AND   erm_line_id = i_erm_line_id
         AND   ROWNUM = 1;

       --  dbms_output.put_line('Found putaway:'||l_prod_id);
         Return;

      EXCEPTION
         WHEN NO_DATA_FOUND THEN
            -- Since manifest can be tripped multiple times. We need to
            --    consider the possibility of the item has been putawayed
            --    so the putaway task no longer existed. Check TRANS then
            l_chk_trans := TRUE;
          --  dbms_output.put_line('putaway not found:'||l_prod_id);
         WHEN OTHERS THEN

          o_rtn_err := STRING_TRANSLATION.GET_STRING(6521 ,SUBSTR(SQLERRM, 1, 70));
          Return;
   END;
   IF l_group = 'DMG' THEN
      -- User should not be able to putaway any damaged item
      l_chk_trans := FALSE;
  --    Return;  find out abt this review form code
   END IF;

   -- Check TRANS if needed
   -- DN#10360 prplhj: Added MIS transaction type for checking
   -- DN#10370 prplhj: Comment out some checkings. Order_line_id for the
   --    transaction should be unique
   IF l_chk_trans = TRUE THEN
      l_existed := 'N';
      BEGIN
         SELECT 'Y' INTO l_existed
            FROM trans
            WHERE trans_type IN ('PUT', 'MIS')
            AND   rec_id = l_erm_id
            AND   prod_id = l_prod_id
            AND   cust_pref_vendor = l_cpv
            AND   NVL(reason_code, i_reason) = i_reason
            AND   order_line_id = i_erm_line_id
            AND   ROWNUM = 1;

      --    dbms_output.put_line('Found Trans:'||l_prod_id);

         -- Found the TRANS record - item has been putawayed. No need to
         --    generate a putaway task
         RETURN;

         EXCEPTION
            WHEN NO_DATA_FOUND THEN
               -- No TRANS record found. Go ahead to create putaway task
        --        dbms_output.put_line('no Trans Found:'||l_prod_id);
               NULL;
            WHEN OTHERS THEN
             o_rtn_err := STRING_TRANSLATION.GET_STRING(6522 ,l_prod_id ,l_cpv ,i_reason ,i_ob_no);

      END;
   END IF;

   l_chk_pallet := FALSE;
   WHILE NOT l_chk_pallet LOOP
      l_pallet_id := '1';
      BEGIN
         SELECT TO_CHAR(pallet_id_seq.NEXTVAL) INTO l_pallet_id
            FROM DUAL;

         EXCEPTION
            WHEN NO_DATA_FOUND THEN
               NULL;
            WHEN OTHERS THEN
               o_rtn_err :=  STRING_TRANSLATION.GET_STRING(6523);

      END;
      BEGIN
         l_existed := 'N';
         SELECT 'Y' INTO l_existed
             FROM inv
             WHERE prod_id = l_prod_id
             AND   cust_pref_vendor = l_cpv
             AND   logi_loc = l_pallet_id;

         EXCEPTION
            WHEN NO_DATA_FOUND THEN
               l_chk_pallet := TRUE;
            WHEN TOO_MANY_ROWS THEN
               NULL;
            WHEN OTHERS THEN
               l_chk_pallet := TRUE;

               o_rtn_err := STRING_TRANSLATION.GET_STRING(6524 ,l_pallet_id ,SUBSTR(SQLERRM, 1, 70));


      END;
  END LOOP;

 -- l_rtn_qty := convert_splits_on_uom(l_prod_id, l_cpv, i_rtn_uom, i_rtn_qty);


      IF i_rtn_uom = '0' THEN  -- Splits only
          l_rtn_qty:= i_rtn_qty * l_spc;
      ELSE
         l_rtn_qty := i_rtn_qty;
      END IF;

  IF pl_ml_common.f_is_induction_loc(l_dest_loc) = 'Y' OR pl_matrix_common.f_is_induction_loc_yn(l_dest_loc) = 'Y' THEN
    l_rtn_date := '01-JAN-2001';
  ELSE
      l_rtn_date := SYSDATE;
  END IF;

  IF l_group IN ('NOR', 'WIN') THEN
     -- Create inventory planned only for these reason groups
     OPEN c_get_case_cube(l_prod_id, l_cpv);
     FETCH c_get_case_cube INTO l_case_cube, l_pallet_type, l_abc;
     CLOSE c_get_case_cube;
     IF l_pallet_type IS NULL THEN
        OPEN c_get_skid_cube_wo_pallet_type(l_dest_loc);
        FETCH c_get_skid_cube_wo_pallet_type INTO l_skid_cube;
        CLOSE c_get_skid_cube_wo_pallet_type;
     ELSE
        OPEN c_get_skid_cube_w_pallet_type(l_pallet_type);
        FETCH c_get_skid_cube_w_pallet_type INTO l_skid_cube;
        CLOSE c_get_skid_cube_w_pallet_type;
     END IF;

     IF NVL(i_xdock_ind,'N') <> 'X' then --jira 3506

     IF l_found_float = TRUE THEN

        -- insert inventory record for the floating slot with 0 qoh, returned qty= qty_planned, 0 qty_alloc
       -- DN#10411 prplhj: Added lst_cycle_date to INV

        BEGIN


           INSERT INTO inv (
              prod_id, cust_pref_vendor, rec_id,
                inv_date,
                exp_date,
              rec_date,
                lst_cycle_date,
                abc_gen_date,
              plogi_loc, logi_loc,
              qoh, qty_alloc, qty_planned, min_qty,
              cube,
              abc, status,
              weight, temperature, inv_uom)
              VALUES (l_prod_id, l_cpv, l_erm_id,
                      l_rtn_date,
                          l_rtn_date,
                        SYSDATE,
                      SYSDATE,
                      SYSDATE,
                      l_dest_loc, l_pallet_id,
                      0, 0, l_rtn_qty, 0,
                      (l_rtn_qty / l_spc) * l_case_cube + l_skid_cube,
                      l_abc, 'AVL',
                      i_weight, i_temperature, TO_NUMBER(i_rtn_uom));

                 --        dbms_output.put_line('After INV insert:'|| l_prod_id);

           EXCEPTION    WHEN DUP_VAL_ON_INDEX THEN
             o_rtn_err :=  STRING_TRANSLATION.GET_STRING(6525 ,l_pallet_id);

             dbms_output.put_line('error INV insert:'|| l_prod_id);
             Return;

            WHEN OTHERS THEN

       --      dbms_output.put_line('error INV insert:'|| l_prod_id);

               o_rtn_err :=  STRING_TRANSLATION.GET_STRING(6526 ,l_prod_id ,SUBSTR(SQLERRM, 1, 70));
                Return;
        END;
     ELSE
        BEGIN
           UPDATE inv
              SET qty_planned = qty_planned + l_rtn_qty
              WHERE plogi_loc = l_dest_loc
              AND   logi_loc = l_logi_loc;

           EXCEPTION
              WHEN NO_DATA_FOUND THEN
                 NULL;
              WHEN OTHERS THEN

               o_rtn_err :=   STRING_TRANSLATION.GET_STRING(6527 ,l_prod_id ,SUBSTR(SQLERRM, 1, 70));
        --       dbms_output.put_line('error INV update:'|| l_prod_id);
               Return;

        END;
     END IF; -- FOUND FLOAT
     END IF; --xdock
  END IF;

  BEGIN

 --    dbms_output.put_line('before putawaylst insert:'|| l_prod_id);

     INSERT INTO putawaylst (
        rec_id, dest_loc, pallet_id,
        prod_id, cust_pref_vendor,
        qty, uom, qty_expected, qty_received,
        status, inv_status,
        equip_id, rec_lane_id,
        exp_date,
        weight, temp, catch_wt, temp_trk,
        putaway_put, seq_no, mispick, erm_line_id, print_status,
        reason_code,
        lot_id, orig_invoice)
        VALUES (l_erm_id, l_dest_loc, l_pallet_id,
                l_prod_id, l_cpv,
                l_rtn_qty, TO_NUMBER(i_rtn_uom), l_rtn_qty, l_rtn_qty,
                NVL(l_putaway_status, ' '), NVL(l_putaway_inv_status, ' '),
                ' ', ' ', l_rtn_date,
                i_weight, i_temperature, i_wt_trk, i_temp_trk,
                'N', i_erm_line_id, l_mispick, i_erm_line_id, NULL,
                i_reason,
                DECODE(INSTR(i_ob_no, 'L'),
                       0, i_ob_no,
                       SUBSTR(i_ob_no, 1, INSTR(i_ob_no, 'L') - 1)),
                DECODE(INSTR(l_orig_invoice, 'L'),
                       0, l_orig_invoice,
                       SUBSTR(l_orig_invoice, 1, INSTR(l_orig_invoice, 'L') - 1)));
 IF SUBSTR(l_erm_id, 1,1) = 'S' THEN
    DECLARE
    -- call to create Labor batch for each salable putaway
      l_no_rec_processed PLS_INTEGER;
      l_batches_crtd PLS_INTEGER;
      l_no_batches_exist PLS_INTEGER;
      l_no_error PLS_INTEGER;
   BEGIN
  
        pl_lmf.create_dci_batches (i_create_for_what => 'LP',
                               i_key_value => l_pallet_id, -- pallet_id
                               i_dest_loc => l_dest_loc, -- destination location
                               o_no_records_processed => l_no_rec_processed, 
                               o_no_batches_created => l_batches_crtd, 
                               o_no_batches_existing => l_no_batches_exist, 
                               o_no_not_created_due_to_error => l_no_error);
                               
        IF l_no_error = 0 AND NVL(l_batches_crtd,0) <> 0 THEN
           pl_log.ins_msg('INFO', l_func_name, 'LM batch created', SQLCODE, SUBSTR(SQLERRM, 1, 500), APPLICATION_FUNC, PACKAGE_NAME);
        ELSE
           pl_log.ins_msg('FATAL', l_func_name, 'LM batch not created:'||l_no_error, SQLCODE, SUBSTR(SQLERRM, 1, 500), APPLICATION_FUNC, PACKAGE_NAME);
        END IF;
    
     EXCEPTION
       WHEN OTHERS THEN
         NULL; --- issues are handled in the LM batch creation process
      END;
  END IF;   

     EXCEPTION
        WHEN DUP_VAL_ON_INDEX THEN
           o_rtn_err := STRING_TRANSLATION.GET_STRING(6528 ,l_prod_id ,l_pallet_id);

       --    dbms_output.put_line('error 1 putawaylst insert:'|| l_prod_id);
           Return;
        WHEN OTHERS THEN
           o_rtn_err := STRING_TRANSLATION.GET_STRING(6529 ,l_prod_id ,l_pallet_id ,sqlerrm);
       --     dbms_output.put_line('error 2 putawaylst insert:'|| sqlerrm);
           Return;
  END;
   -- the below code has been now removed to call the new LM batch creation process)
   -- D#11741 Create T-batch for the pallet if LM flag is on
  /*  l_rtn_lm_syspars := pl_rtn_lm.check_rtn_lm_syspars;


  IF l_rtn_lm_syspars.szCrtBatchFlag = 'Y' THEN
    BEGIN
      pl_rtn_lm.create_rtn_lm_batches(l_pallet_id,
                                      l_num_tbatches, l_tbatches,
                                      l_message, l_status);
      IF l_status <> 0 Then
      --AND l_status <> :work.cte_rtn_btch_flag_off THEN review this line of code

         o_rtn_err := l_message;
         Return;

      END IF;
    END;
    
  END IF; */
  null;
END; --insrt_putaway

 /************************************************************************
    -- createputs_main
    --
    -- Description:  createputs_main procedures that call all the 
    -- internal processed  for create puts.
    --      
    -- Return/output: rf.status.
    --
    -- Modification log:
    --
    -- Date         Developer     Change
    -- ------------------------------------------------------------------
    -- 15-OCT-2020  vkal9662      Initial version.
    -- 15-Dec-2020  vkal9662      Data collotion check and status change 
                                  to COL has been moved to Validate STS
    *************************************************************************/
function createputs_main(p_Manifest_No number)return rf.status is

-- can be called many times; if puts are created already they will not be created again

--For returns with below criteria
   CURSOR  rtn_curs(mans_no NUMBER) IS
      select distinct r.REC_TYPE,
             r.OBLIGATION_NO,
             r.PROD_ID,
             r.CUST_PREF_VENDOR,
             r.RETURNED_PROD_ID,
             r.RETURNED_QTY,
             r.SHIPPED_QTY,
             r.RETURNED_SPLIT_CD,
             r.CATCHWEIGHT,
             r.ERM_LINE_ID,
             r.CUST_ID,
             r.RETURN_REASON_CD,
             rs.REASON_GROUP,
             r.STOP_NO,
             r.shipped_split_cd,
             r.temperature,
             p.catch_wt_trk,
             r.xdock_ind,
             r.site_from,
             DECODE(rs.reason_group,
                    'DMG', 'N',
                    'STM', 'N',
                    p.temp_trk) temp_trk,
             r.RTN_SENT_IND
      from   REASON_CDS rs, RETURNS r, pm p
      where  rs.reason_cd  = r.return_reason_cd
        and  r.manifest_no = mans_no
        and  rs.reason_cd_type ='RTN'
        and  rs.reason_group IN
             ('NOR','DMG','OVR','MPR','OVI','WIN', 'MPK')
        and  r.returned_qty IS NOT NULL
        AND  p.prod_id = DECODE(rs.reason_group, 'MPR', r.returned_prod_id, 'MPK', r.returned_prod_id,
                                r.prod_id)
        AND  nvl(r.pod_rtn_ind, 'X') <>'D'
        AND  p.cust_pref_vendor = r.cust_pref_vendor  
        AND  r.status = 'PUT';

   CURSOR erm_exists(ermid VARCHAR2) IS
   select 'X'
   from   ERM
   where  ERM_ID = ermid   ;



   rtn_Derm_id      VARCHAR2(20);
   rtn_Serm_id      VARCHAR2(20);
   rtn_exists       VARCHAR2(1);
   v_erm_id         VARCHAR2(12);
   v_prod_id        VARCHAR2(9);
   v_cpv            VARCHAR2(10);
   v_qty            number  := 0;
   v_saleable       VARCHAR2(1);
   v_mispick        VARCHAR2(1);
   cnt_dmg          number  := 0;
   cnt_not_dmg      number  := 0;
   valid_erd        NUMBER(1);      -- D#10392 prplhj Added
   l_rtn_err   returns.err_comment%TYPE ;
   l_status    VARCHAR2(12);
   l_rec_cnt number := 0;
   l_put_cnt number := 0;
   l_mfst_status MANIFESTS.MANIFEST_STATUS%TYPE;
   l_mfst_cnt number := 0;
   l_dmg_rtn number := 0;
   l_sal_rtn number := 0;
   l_message    VARCHAR2(4000);
   l_dmgexists  VARCHAR2(12);
   l_salexists  VARCHAR2(12);
   cp_flag  VARCHAR2(1);

   l_prod_id        returns.prod_id%TYPE ;
   l_cpv        returns.cust_pref_vendor%TYPE ;
   l_category       pm.category%TYPE;
   l_wt_trk     pm.catch_wt_trk%TYPE := 'N';
   l_temp_trk       pm.temp_trk%TYPE := 'N';
   l_spc        pm.spc%TYPE;
   l_split_trk      pm.split_trk%TYPE;
   l_descrip        pm.descrip%TYPE;

   l_bad_temp  BOOLEAN;
   l_min_temp  pm.min_temp%TYPE;
   l_max_temp  pm.max_temp%TYPE;
   l_pct_tol  number; -- rview the use of this vkal9662

   l_bad_wt    BOOLEAN;
   l_min_wt    returns.catchweight%TYPE;
   l_max_wt    returns.catchweight%TYPE;

   l_ttl_rtnsplt_qty number;
   l_ship_split_qty number;
   l_ttl_wt number;
   l_test varchar2(10);
   l_food_sfty varchar2(5);
   l_slt_cnt number:=0;


   l_func_name varchar2(50) := 'createputs_main';

BEGIN
 -- rf.status := rf.status_normal;
---Check if Manifest Exists

   select count(*)
   into l_mfst_cnt
   from MANIFESTS
   where MANIFEST_NO = P_MANIFEST_NO;

If l_mfst_cnt = 0 then

   pl_log.ins_msg('FATAL', l_func_name, 'No Manifest Found', APPLICATION_FUNC, PACKAGE_NAME);

    return rf.status_data_error;


End If;

    --- count DMG and non-DMG     returns

      select nvl(sum(decode(rs.REASON_GROUP, 'DMG',1, 0)), 0),
             nvl(sum(decode(rs.REASON_GROUP, 'DMG',0, 1)), 0)
      into l_dmg_rtn, l_sal_rtn
    from   REASON_CDS rs, RETURNS r
    where  rs.REASON_CD  = r.RETURN_REASON_CD
    and  r.MANIFEST_NO = P_MANIFEST_NO
    and  rs.REASON_GROUP IN ('NOR','DMG','OVR','MPR','OVI','WIN', 'MPK')
    and  (r.RETURNED_QTY IS NOT NULL AND r.returned_qty <> 0);

            -- prepare erm_ids for damaged and salebale erms

          rtn_Derm_id := 'D' || to_char(P_MANIFEST_NO);
      rtn_Serm_id := 'S' || to_char(P_MANIFEST_NO);


  -- create ERM for damage returns as needed

  If l_dmg_rtn >0 then

   OPEN  erm_exists(rtn_Derm_id);
   FETCH erm_exists INTO l_dmgexists;
   IF erm_exists%NOTFOUND THEN
      insert into ERM
      (      ERM_ID,      ERM_TYPE,
             SCHED_DATE,  EXP_ARRIV_DATE,
             REC_DATE,    STATUS         )
      values
      (      rtn_Derm_id,  'CM',
             sysdate,     sysdate,
             sysdate,     'OPN'    );
   END IF;
   CLOSE erm_exists;
 End If;

 -- Create ERM for Salable returns as needed
 If l_sal_rtn >0 then

   OPEN  erm_exists(rtn_Serm_id);
   FETCH erm_exists INTO l_salexists;
   IF erm_exists%NOTFOUND THEN
      insert into ERM
      (      ERM_ID,      ERM_TYPE,
             SCHED_DATE,  EXP_ARRIV_DATE,
             REC_DATE,    STATUS         )
      values
      (      rtn_Serm_id,  'CM',
             sysdate,     sysdate,
             sysdate,     'OPN'    );
   END IF;
   CLOSE erm_exists;
 End If;


 /*
** For every return records, create an ERD
**  a putawaylst and update INV if it is appropriate.
*/

   l_rec_cnt  := 0;
   l_put_cnt  := 0;


FOR rtn_rec IN rtn_curs(P_MANIFEST_NO)
LOOP
   IF rtn_rec.REASON_GROUP = 'DMG' THEN
      v_erm_id := rtn_Derm_id;
      v_saleable := 'N';
   ELSE
      v_erm_id := rtn_Serm_id;
      v_saleable := 'Y';
   END IF;
   --
   IF rtn_rec.REASON_GROUP IN ('MPR', 'MPK', 'OVR')
      AND rtn_rec.RETURNED_PROD_ID IS NOT NULL   THEN
      v_prod_id := rtn_rec.RETURNED_PROD_ID;
      v_cpv     := '-';
   ELSE
      v_prod_id := rtn_rec.PROD_ID;
      v_cpv     := rtn_rec.CUST_PREF_VENDOR;
   END IF;
   --
   IF rtn_rec.REASON_GROUP IN ('MPR', 'MPK', 'OVR', 'OVI') THEN
      v_mispick := 'Y';
   ELSE
      v_mispick := 'N';
   END IF;
   --
   If v_cpv is null then
    cp_flag := 'N';
   else
    cp_flag := 'Y';
   end If;

    Begin
      SELECT cust_pref_vendor, descrip, spc,category, catch_wt_trk, temp_trk, split_trk
      into    l_cpv,l_descrip,l_spc,l_category, l_wt_trk,l_temp_trk, l_split_trk
      FROM pm
      WHERE prod_id = v_prod_id
      AND   ((cp_flag = 'N') OR
             ((cp_flag = 'Y') AND (cust_pref_vendor = v_cpv)));

    Exception when others then
    dbms_output.put_line('Error retrieving PM Info:'||v_prod_id);
  End;

   /*  IF rtn_rec.RETURNED_SPLIT_CD = '0' THEN  -- Splits only
          v_qty := rtn_rec.returned_qty * l_spc;
      ELSE*/
          v_qty := rtn_rec.returned_qty;
  --    END IF;



   IF NVL(v_qty, 0) <> 0 THEN

     IF (rtn_rec.reason_group NOT IN ('MPR', 'MPK')) OR
        (rtn_rec.reason_group IN ('MPR', 'MPK') AND
         rtn_rec.returned_prod_id IS NOT NULL) THEN


      BEGIN
         insert into ERD
         (      ERM_ID,    ERM_LINE_ID,
                SALEABLE,  MISPICK,
                PROD_ID,   CUST_PREF_VENDOR,
                WEIGHT,    REASON_CODE,
                QTY,       UOM,
                QTY_REC,   UOM_REC,
                ORDER_ID,  STATUS           )
         values
         (      v_erm_id,              rtn_rec.ERM_LINE_ID,
                v_saleable,            v_mispick,
                v_prod_id,             v_cpv,
                rtn_rec.CATCHWEIGHT,   rtn_rec.RETURN_REASON_CD,
                v_qty,                 rtn_rec.RETURNED_SPLIT_CD,
                v_qty,                 rtn_rec.RETURNED_SPLIT_CD,
                rtn_rec.OBLIGATION_NO, 'OPN'   );
       EXCEPTION
         WHEN DUP_VAL_ON_INDEX THEN
              NULL;
         WHEN OTHERS THEN
           pl_log.ins_msg('FATAL', l_func_name, STRING_TRANSLATION.GET_STRING(5210), SQLCODE, SUBSTR(SQLERRM, 1, 500), APPLICATION_FUNC, PACKAGE_NAME);
           ROLLBACK;
        --   DBMS_OUTPUT.PUT_LINE( STRING_TRANSLATION.GET_STRING(5210 ,TO_CHAR(SQLCODE) ,SQLERRM));

      END;
      l_rtn_err := null;


      insrt_putaway(p_manifest_no,
                rtn_rec.stop_no,
                rtn_rec.rec_type,
                rtn_rec.obligation_no,
                rtn_rec.prod_id,
                rtn_rec.cust_pref_vendor,
                rtn_rec.return_reason_cd,
                v_qty,
                rtn_rec.returned_split_cd,
                'N',
                rtn_rec.catchweight,
                rtn_rec.returned_prod_id,
                rtn_rec.erm_line_id,
                rtn_rec.temp_trk,
                rtn_rec.temperature,
                rtn_rec.xdock_ind, --jira 3506
                rtn_rec.site_from,
                l_rtn_err );



   /* The check for data collection is being moved to Validation process   */
   

    
         If     l_rtn_err is not null then

             l_status := 'SLT';

             l_slt_cnt  := l_slt_cnt+1;

         elsif l_mfst_status = 'PAD' Then

             l_status := 'CMP';
         Else
               l_status := 'CMP';
         end If;
         
         
        dbms_output.put_line('put status:'||  l_status);


    BEGIN
       UPDATE returns
       SET returned_prod_id = DECODE(rtn_rec.reason_group,
                                       'DMG', rtn_rec.prod_id,
                                       'NOR', rtn_rec.prod_id,
                                       'WIN', rtn_rec.prod_id,
                                       'OVR', rtn_rec.prod_id,
                                       'OVI', rtn_rec.prod_id,
                                       rtn_rec.returned_prod_id),
         upd_source = 'RF',
         status = l_status,
         err_comment = l_rtn_err
         WHERE manifest_no = p_manifest_no
       AND   prod_id = rtn_rec.prod_id
       AND   cust_pref_vendor = rtn_rec.cust_pref_vendor
       AND   return_reason_cd = rtn_rec.return_reason_cd
       AND   nvl(obligation_no,0) = nvl(rtn_rec.obligation_no,0)
       AND   erm_line_id = rtn_rec.erm_line_id;

  

      l_rec_cnt :=  l_rec_cnt+1;

       if l_rtn_err is null then
        l_put_cnt :=  l_put_cnt +1;
       End if;

     EXCEPTION WHEN NO_DATA_FOUND THEN
         NULL;
       WHEN OTHERS THEN
        return rf.status_data_error;

       pl_log.ins_msg('FATAL', l_func_name, STRING_TRANSLATION.GET_STRING(6514), SQLCODE, SUBSTR(SQLERRM, 1, 500), APPLICATION_FUNC, PACKAGE_NAME);
       ROLLBACK;
        --  return STRING_TRANSLATION.GET_STRING(6514)||TO_CHAR(p_manifest_no) ||rtn_rec.prod_id||TO_CHAR(rtn_rec.erm_line_id);

    END;


     END IF;
   END IF;

END LOOP;

BEGIN

   DELETE returns r
      WHERE r.manifest_no = p_manifest_no
      AND   r.rec_type = 'P'
      AND   r.returned_qty IS NULL
      AND   EXISTS (SELECT NULL
                    FROM returns r1
                    WHERE r1.manifest_no = r.manifest_no
                    AND   r1.rec_type = r.rec_type
                    AND   r1.obligation_no = r.obligation_no
                    AND   r1.prod_id = r.prod_id
                    AND   r1.cust_pref_vendor = r.cust_pref_vendor
                    AND   r1.returned_qty IS NOT NULL);

 --- return message here

EXCEPTION
   WHEN NO_DATA_FOUND THEN
      NULL;
   WHEN OTHERS THEN
      return rf.status_data_error;

      pl_log.ins_msg('FATAL', l_func_name, 'Error Deleting Returns with rec type=P', SQLCODE, SUBSTR(SQLERRM, 1, 500), APPLICATION_FUNC, PACKAGE_NAME);
      ROLLBACK;
 End;
 l_message := nvl(l_put_cnt,0)||' Putaways Created';
 if l_slt_cnt >0 then
  l_message := l_message||';'||l_slt_cnt||' Items needs slotting';
 end if;

 Commit;
 pl_log.ins_msg('INFO', l_func_name, l_message, null, null, APPLICATION_FUNC, PACKAGE_NAME);
 return rf.status_normal;

Exception When Others  then
pl_log.ins_msg('FATAL', l_func_name, 'Error in Creatputs_retrun', SQLCODE, SUBSTR(SQLERRM, 1, 500), APPLICATION_FUNC, PACKAGE_NAME);
ROLLBACK;
return rf.status_update_fail;
END;
/************************************************************************
    -- CreatePuts_for_returns
    --
    -- Description:  createputs RF procedures that call all the 
    -- main processes for create puts.
    --      
    -- Return/output: rf.status.
    --
    -- Modification log:
    --
    -- Date         Developer     Change
    -- ------------------------------------------------------------------
    -- 15-OCT-2020  vkal9662      Initial version.
    --
    *************************************************************************/

    FUNCTION CreatePuts_for_returns (
        i_rf_log_init_rec       IN  rf_log_init_record,
        i_manifest_no           IN  manifests.manifest_no%TYPE,
        o_returned_items_list   OUT rtn_validation_obj
    ) return rf.status IS

        l_status      rf.status := rf.status_normal;
        l_crtput_status   rf.status := rf.status_normal;
        l_msg         swms_log.msg_text%TYPE;
        l_func_name   CONSTANT  swms_log.procedure_name%TYPE := 'CreatePuts_for_returns';
        l_item_list           rtn_item_table := rtn_item_table();
        l_route_no     varchar2(10);
    BEGIN

        -- Initialize the out parameter

     o_returned_items_list := rtn_validation_obj(i_manifest_no, 'N', ' ', rtn_item_table());

        -- Call rf.initialize(). cannot procede if return status is not successful.
        l_status := rf.initialize(i_rf_log_init_rec);

        -- Log the input received from the RF client
        l_msg := 'Starting '
              || l_func_name
              || '. Received manifest# from RF client: ['
              || i_manifest_no
              || ']';
        pl_log.ins_msg('INFO', l_func_name, l_msg, null, null, APPLICATION_FUNC, PACKAGE_NAME);

        -- perform the business logic of the function by calling the business logic function
        IF l_status = rf.status_normal THEN

            l_crtput_status := createputs_main(i_manifest_no);

           IF  l_crtput_status = rf.status_normal THEN

            --call below process to get the returns object--

             l_item_list := get_manifest_returns(i_manifest_no, 20, 40);
         
        

            SELECT route_no
            INTO   l_route_no
            FROM   manifests
            WHERE  manifest_no = i_manifest_no;

            -- iterate through the list of returns and get missing data.
            FOR item IN NVL(l_item_list.first, 0)..NVL(l_item_list.last, -1) LOOP
                l_item_list(item).upc_list  := get_upc_list_for_item(l_item_list(item).prod_id, l_item_list(item).cust_pref_vendor);
                l_item_list(item).order_seq_list := get_order_seq_no(l_route_no,
                                                                l_item_list(item).stop_no,
                                                                l_item_list(item).obligation_no,
                                                                l_item_list(item).prod_id,
                                                                l_item_list(item).cust_pref_vendor,
                                                                l_item_list(item).returned_split_cd);
                                                                
                                                                
           ---to gather destination location and Print related status for the returns after create put
           
              BEGIN
				       SELECT NVL(RTN_LABEL_PRINTED, 'N'),
						          NVL(DEST_LOC, ' '),
						          NVL(PALLET_ID, ' ')
					     INTO l_item_list(item).rtn_label_printed,
						        l_item_list(item).dest_loc,
						        l_item_list(item).pallet_id
					     FROM PUTAWAYLST
					    WHERE SUBSTR(rec_id, 2) = TO_CHAR(i_manifest_no) AND -- R44-POD Returns - Changed i_manifest_no to TO_CHAR(i_manifest_no) - In validate_mf_rtn - Line 1159
						   SUBSTR(rec_id, 1, 1) IN ('D', 'S') AND
						   prod_id = nvl(l_item_list(item).returned_prod_id,l_item_list(item).prod_id) AND
						  -- NVL(RTN_LABEL_PRINTED, 'N') = 'N' AND      
               ERM_LINE_ID = l_item_list(item).erm_line_id;
					
					  EXCEPTION
						  WHEN NO_DATA_FOUND THEN
							l_status := rf.STATUS_NORMAL;
							l_item_list(item).pallet_id := NVL(l_item_list(item).pallet_id, ' ');
							l_item_list(item).dest_loc := NVL(l_item_list(item).dest_loc, ' ');
							l_item_list(item).rtn_label_printed := NVL(l_item_list(item).rtn_label_printed, 'N');
							l_msg := 'No Data Found while looking for PutAwayLst Values - Manifest No: ' || i_manifest_no ||
									 ' Prod ID: ' || NVL(l_item_list(item).prod_id, 'NULL') ;
							pl_log.ins_msg('WARN', l_func_name, l_msg, SQLCODE, SUBSTR(SQLERRM, 1, 500), APPLICATION_FUNC, PACKAGE_NAME);
						  WHEN OTHERS THEN
							l_status := rf.STATUS_DATA_ERROR;
							l_item_list(item).pallet_id := NVL(l_item_list(item).pallet_id, ' ');
							l_item_list(item).dest_loc := NVL(l_item_list(item).dest_loc, ' ');
							l_item_list(item).rtn_label_printed := NVL(l_item_list(item).rtn_label_printed, 'N');
							l_msg := 'Unexpected ERROR while looking for PutAwayLst Values - Manifest No: ' || i_manifest_no ||
									 ' Prod ID: ' || NVL(l_item_list(item).prod_id, 'NULL') ;
							pl_log.ins_msg('FATAL', l_func_name, l_msg, SQLCODE, SUBSTR(SQLERRM, 1, 500), APPLICATION_FUNC, PACKAGE_NAME);
			   	END;
                                                              
                                                                
        END LOOP;

            o_returned_items_list.manifest_no := i_manifest_no;
            o_returned_items_list.dci_ready   := 'Y';
            o_returned_items_list.item_list   := l_item_list;


           End If;
        END IF;

        rf.complete(l_status);
        return rf.status_normal;

    EXCEPTION
        WHEN OTHERS THEN
            l_msg := 'ERROR in CreatePuts_for_returns() for manifest# ['
                  || i_manifest_no
                  || ']';
            pl_log.ins_msg('FATAL', l_func_name, l_msg, SQLCODE, SUBSTR(SQLERRM, 1, 500), APPLICATION_FUNC, PACKAGE_NAME);
            rf.logexception();
            RAISE;

    END CreatePuts_for_returns;

  --==========================================createputs functions end===================================================================

  --===========================================functions for Save RTN====================================================================
  /************************************************************************
    -- check_rtn_qty
    --
    -- Description:  check_rtn_qty checks if the RTN quantity passed is correct.
    --      
    -- Return/output: rf.status.
    --
    -- Modification log:
    --
    -- Date         Developer     Change
    -- ------------------------------------------------------------------
    -- 17-Nov-2020  vkal9662      Initial version.
    -- 17-May-2021  pkab6563      Jira 3423 - Added additional parameter
    --                            i_returned_split_cd to use in logic
    --                            to avoid "qty too large" message when
    --                            adding returns in splits for an item
    --                            shipped in cases.
    *************************************************************************/

   FUNCTION check_rtn_qty(
      i_manifest_no        IN manifests.manifest_no%TYPE,
      i_returned_items_rec IN rtn_item_rec,
      i_Qty                IN NUMBER DEFAULT 0,
      i_ermid              IN NUMBER DEFAULT 0,
      i_returned_split_cd  IN returns.returned_split_cd%TYPE DEFAULT '0')
    RETURN NUMBER
  IS
  
    l_msg swms_log.msg_text%TYPE;
    l_func_name   VARCHAR2(250) := 'check_rtn_qty';
    l_tbl_rsn_cd pl_dci.tabTypReasons;
    l_MF_rec manifests%ROWTYPE         := NULL;
    l_MfDtls_rec manifest_dtls%ROWTYPE := NULL;
    l_ShipQty     NUMBER                   := 0;
    l_CurRtnQty   NUMBER                   := 0;
    l_spc         NUMBER                   := 0;
    l_totl_RtnQty NUMBER                   := 0;
    l_Pm_rec pm%ROWTYPE                    := NULL;
    l_SkidCube       NUMBER                      := 0;
    l_Status         NUMBER                      := rf.status_normal;
    l_MfDtlCnt       NUMBER                      := 0;
    l_ChkSameUom     NUMBER                      := 0;
    C_INV_RSN        CONSTANT NUMBER             := 243; -- Invalid reason code
    C_NO_MF_INFO     CONSTANT NUMBER             := 253; -- No manifest info
    C_INV_PRODID     CONSTANT NUMBER             := 37;  -- Invalid item
    C_QTY_RTN_GT_SHP CONSTANT NUMBER             := 258; -- Qty rtn > shipped

    CURSOR c_get_rtn_qty (cs_reason_group reason_cds.reason_group%TYPE)
    IS
      SELECT NVL(SUM(NVL(r.returned_qty, 0) / DECODE(r.returned_split_cd, '1', p.spc, 1)), 0)
      FROM returns r, pm p, reason_cds c
      WHERE r.manifest_no                                                                                                      = i_manifest_no
      AND DECODE(INSTR(r.obligation_no, 'L'), 0, r.obligation_no, SUBSTR(r.obligation_no, 1, INSTR(r.obligation_no, 'L') - 1)) = i_returned_items_rec.obligation_no
      AND r.rec_type                                                                                                           = i_returned_items_rec.rec_type
      AND NVL(r.returned_prod_id, r.prod_id)                                                                                   = DECODE(cs_reason_group, 'MPR', i_returned_items_rec.returned_prod_id, 'MPK', i_returned_items_rec.returned_prod_id, i_returned_items_rec.prod_id)
      AND r.cust_pref_vendor                                                                                                   = i_returned_items_rec.cust_pref_vendor
      AND r.prod_id                                                                                                            = p.prod_id
      AND r.cust_pref_vendor                                                                                                   = p.cust_pref_vendor
      AND c.reason_cd_type                                                                                                     = 'RTN'
      AND r.pod_rtn_ind                                                                                                        <> 'D' 
      AND c.reason_cd                                                                                                          = r.return_reason_cd
      AND c.reason_group NOT                                                                                                  IN ('OVR', 'OVI')
      AND ((i_ermid                                                                                                            = 0)
      OR ((i_ermid                                                                                                            <> 0)
      AND (r.erm_line_id                                                                                                      <> i_ermid)))
      AND ((l_ChkSameUom                                                                                                       = 0)
      OR ((l_ChkSameUom                                                                                                       <> 0)
      AND (r.returned_split_cd                                                                                                 = i_returned_items_rec.returned_split_cd)));
  BEGIN
  
    l_ShipQty :=i_returned_items_rec.shipped_qty;
  
    -- Don't need verfication is no qty or pickup or overage or OVI
    IF NVL(i_returned_items_rec.returned_qty, 0) = 0 OR i_returned_items_rec.rec_type = 'O' OR ( i_returned_items_rec.rec_type = 'P') THEN
      RETURN rf.status_normal;
    END IF;
    l_tbl_rsn_cd         := pl_dci.get_reason_info('ALL', 'ALL', i_returned_items_rec.return_reason_cd);
    IF l_tbl_rsn_cd.COUNT = 0 THEN  
      RETURN pl_dci.C_INV_RSN;
    END IF;
    IF l_tbl_rsn_cd(1).reason_group IN ('OVR', 'OVI') THEN
      RETURN rf.status_normal;
    END IF;
    -- Convert current returned qty to cases if flag is not set
    IF i_Qty                                    = 0 THEN
      l_CurRtnQty                              := NVL(i_returned_items_rec.returned_qty, 0);
      IF i_returned_items_rec.returned_split_cd = '1' THEN
        BEGIN
          SELECT p.spc INTO l_spc FROM PM p WHERE prod_id =i_returned_items_rec.prod_id;
        EXCEPTION
        WHEN OTHERS THEN
          RETURN pl_dci.C_INV_PRODID;
        END;
        l_CurRtnQty := l_CurRtnQty / NVL(l_Pm_rec.spc, 1);
      END IF;
    ELSE
      l_CurRtnQty := i_Qty ;
    END IF;
    DBMS_OUTPUT.PUT_LINE('UseCurQty: ' || TO_CHAR(i_Qty) || ', curQ: ' || TO_CHAR(i_returned_items_rec.returned_qty) || '/' || 
                         TO_CHAR(l_CurRtnQty) || ', curUom: ' || i_returned_items_rec.returned_split_cd || ', shpQ: ' || TO_CHAR(l_ShipQty));
     
     
     l_msg :=   'UseCurQty: ' || TO_CHAR(i_Qty) ||' ,curQ: ' || TO_CHAR(i_returned_items_rec.returned_qty)||', shpQ: ' || TO_CHAR(l_ShipQty) ;     
     
     pl_log.ins_msg('INFO', l_func_name, l_msg, NULL, NULL, APPLICATION_FUNC, PACKAGE_NAME);                     
    BEGIN
      SELECT COUNT(1)
      INTO l_MfDtlCnt
      FROM manifest_dtls
      WHERE manifest_no                                                                                                = i_manifest_no
      AND DECODE(INSTR(obligation_no, 'L'), 0, obligation_no, SUBSTR(obligation_no, 1, INSTR(obligation_no, 'L') - 1)) = i_returned_items_rec.obligation_no
      AND prod_id                                                                                                      = i_returned_items_rec.prod_id
      AND cust_pref_vendor                                                                                             = i_returned_items_rec.cust_pref_vendor
      AND rec_type                                                                                                     = i_returned_items_rec.rec_type;
    EXCEPTION
    WHEN OTHERS THEN
      l_MfDtlCnt := 0;
    END;
    IF l_MfDtlCnt   > 1 THEN
      l_ChkSameUom := 1;
    END IF;
    DBMS_OUTPUT.PUT_LINE('ChkOvrQ #mf_dtls: ' || TO_CHAR(l_MfDtlCnt) || ', ChkSameUom: ' || TO_CHAR(l_ChkSameUom) || ', ExcRtn: ' || TO_CHAR(i_ermid));
    -- Retrieve total returned qty in cases
    OPEN c_get_rtn_qty(l_tbl_rsn_cd(1).reason_group);
    FETCH c_get_rtn_qty INTO l_totl_RtnQty;
    IF c_get_rtn_qty%NOTFOUND THEN
      l_totl_RtnQty := 0;
    END IF;
    CLOSE c_get_rtn_qty;
    DBMS_OUTPUT.PUT_LINE('Total qty before adding curQ: ' || TO_CHAR(l_totl_RtnQty));
    l_totl_RtnQty := l_totl_RtnQty + l_CurRtnQty;
    DBMS_OUTPUT.PUT_LINE('Total qty after adding curQ: ' || TO_CHAR(l_totl_RtnQty));
     pl_log.ins_msg('INFO', l_func_name, 'Total qty after adding curQ: ' || TO_CHAR(l_totl_RtnQty), NULL, NULL, APPLICATION_FUNC, PACKAGE_NAME);           

    -- pkab6563: if returning splits and cases were shipped, convert shipped qty to splits.
    -- this is to fix "qty too large" issue reported in jira card 3423.

    IF i_returned_split_cd = '1' AND i_returned_items_rec.shipped_split_cd = '0' THEN
        l_ShipQty := l_ShipQty * i_returned_items_rec.spc;
    END IF;

    IF l_totl_RtnQty > l_ShipQty THEN
       DBMS_OUTPUT.PUT_LINE('in l_totl_RtnQty > l_ShipQty');
      RETURN C_QTY_RTN_GT_SHP;
    ELSIF l_totl_RtnQty <= l_ShipQty THEN
    DBMS_OUTPUT.PUT_LINE('in l_totl_RtnQty<= l_ShipQty: '|| 'l_totl_RtnQty: '||l_totl_RtnQty);
      RETURN rf.status_normal;
    END IF;
    RETURN rf.status_normal;
  EXCEPTION
  WHEN OTHERS THEN
    RETURN SQLCODE;
  END;
---=========================================================================================
  /************************************************************************
    -- save_rtn
    --
    -- Description:  save_rtn is main process to handle saving for
    -- Add, Update, Reverse and Credit process for a Return.
    --
    -- i_action: Input parameter expects values  A,U,R,C    
    --
    -- Return/output: rf.status.
    --
    -- Modification log:
    --
    -- Date         Developer     Change
    -- ------------------------------------------------------------------
    -- 17-Nov-2020  vkal9662      Initial version.
    -- 01-Dec-2020  vkal9662      NULL_VAL_INDICATOR changes
    -- 17-May-2021  pkab6563      Jira 3423 - added additional argument
    --                            for returned_split_cd to call to function
    --                            check_rtn_qty().
	-- 16-Nov-2021  vkal9662      Jira 3839 - Stop Rtns to be updated
    --                            once they have PPU or PUT trans
	-- 02-Dec-2021  vkal9662      Jira 3854 -RF DCI Food saftey error correction
    *************************************************************************/
FUNCTION save_rtn(
    i_action            IN VARCHAR2 , --A,U,R,C (possible values)
    i_manifest_no       IN returns.manifest_no%TYPE,
    i_route_no          IN returns.route_no%TYPE,
    i_orig_rtn_item_rec IN rtn_item_rec,
    i_new_rtn_item_rec  IN rtn_item_rec)
  RETURN rf.status
IS
  l_msg swms_log.msg_text%TYPE;
  l_func_name   VARCHAR2(250) := 'save_rtn';
  l_Status      NUMBER := rf.status_normal;
  l_add_qty     NUMBER := 0;
  l_del_flag   VARCHAR2(2);
  l_pod_rtn_ind VARCHAR2(2) := 'A';
  l_group reason_cds.reason_group%TYPE;
  l_erm_line_id number;
  l_has_ppu number;
  l_has_put number;

  
  l_del_stop_no returns.stop_no%TYPE;
  l_del_obligation_no returns.obligation_no%TYPE;
  l_del_prod_id returns.prod_id%TYPE;
  l_del_cust_pref_vendor returns.cust_pref_vendor%TYPE;
  l_del_return_reason_cd returns.return_reason_cd%TYPE;
  l_del_returned_split_cd returns.returned_split_cd%TYPE;
  l_temp returns.temperature%TYPE;
  
  l_reason_cd returns.return_reason_cd%TYPE;
    
BEGIN
  l_msg := 'Starting '|| l_func_name|| '.manifest# from RF client: : [' || i_manifest_no || '] for ins_upd_rtn';
  pl_log.ins_msg('INFO', l_func_name, l_msg, NULL, NULL, APPLICATION_FUNC, PACKAGE_NAME);
  
  IF i_action IN ('U', 'A', 'C') THEN
  
    l_reason_cd := i_new_rtn_item_rec.return_reason_cd;
  ELSE 
    l_reason_cd := i_orig_rtn_item_rec.return_reason_cd;
  END IF;  
  
  BEGIN
    SELECT reason_group
    INTO l_group
    FROM reason_cds
    WHERE reason_cd_type = 'RTN'
    AND reason_cd        = l_reason_cd;
  EXCEPTION
  WHEN NO_DATA_FOUND THEN
    l_msg := 'Starting '|| l_func_name|| '.manifest# : [' || i_manifest_no || '] invalid reasoncode:' ||l_reason_cd;
    pl_log.ins_msg('FATAL', l_func_name, l_msg, NULL, NULL, APPLICATION_FUNC, PACKAGE_NAME);
    RETURN RF.STATUS_INVALID_RSN;
  END;
  
   dbms_output.put_line('in save_rtn, i_action='||i_action);
   
   pl_log.ins_msg('INFO', l_func_name, 'i_action ='||i_action, NULL, NULL, APPLICATION_FUNC, PACKAGE_NAME);


    If i_action in ('U', 'C') then  -- Jira 3839

        SELECT count(*) into l_has_put
        FROM putawaylst
        WHERE rec_id like '%'||i_manifest_no
        AND   prod_id = i_orig_rtn_item_rec.prod_id
        AND   cust_pref_vendor = i_orig_rtn_item_rec.cust_pref_vendor
        AND   erm_line_id = i_orig_rtn_item_rec.erm_line_id
        AND   putaway_put ='Y';

        SELECT count(*) into l_has_ppu
        FROM trans t, putawaylst p
        WHERE t.rec_id like '%'||i_manifest_no
        AND   t.rec_id      = p.rec_id
        AND   t.prod_id     = p.prod_id
        AND   t.prod_id     = i_orig_rtn_item_rec.prod_id
        AND   p.erm_line_id = i_orig_rtn_item_rec.erm_line_id
        AND   t.pallet_id   = p.pallet_id
        AND   t.trans_type  = 'PPU';

      If l_has_ppu > 0 or l_has_put >0 then
        RETURN RF.STATUS_PUT_DONE;
      End If;
  End If; -- Jira 3839

IF i_action = 'U'   Then
--and (i_orig_rtn_item_rec.rec_type <> 'P') THEN

  
  --IF l_group <> 'WIN' Then
  
   l_msg        := 'update rtn for action=U';
   pl_log.ins_msg('INFO', l_func_name, l_msg, NULL, NULL, APPLICATION_FUNC, PACKAGE_NAME);  
  
    l_del_flag := 'N';
    l_status    := rf.status_normal;
  
    l_del_stop_no := i_orig_rtn_item_rec.stop_no;
    l_del_obligation_no := i_orig_rtn_item_rec.obligation_no;
    l_del_prod_id :=  i_orig_rtn_item_rec.prod_id;
    l_del_cust_pref_vendor :=  i_orig_rtn_item_rec.cust_pref_vendor;
    l_del_return_reason_cd := i_orig_rtn_item_rec.return_reason_cd;
    l_del_returned_split_cd :=  i_orig_rtn_item_rec.returned_split_cd;
    
 --End If; --WIN
 
ELSIF i_action IN ('A') THEN
  BEGIN
  
   l_msg        := 'update rtn for action=A';
   pl_log.ins_msg('INFO', l_func_name, l_msg, NULL, NULL, APPLICATION_FUNC, PACKAGE_NAME);  
  
    SELECT returned_qty
    INTO l_add_qty
    FROM returns
    WHERE manifest_no      = i_manifest_no
    AND return_reason_cd = i_new_rtn_item_rec.return_reason_cd
    AND (stop_no           = i_new_rtn_item_rec.stop_no
    OR stop_no             IS NULL)
    AND prod_id            = i_new_rtn_item_rec.prod_id
    AND cust_pref_vendor   = i_new_rtn_item_rec.cust_pref_vendor
    AND obligation_no      = i_new_rtn_item_rec.obligation_no
    AND shipped_split_cd   = i_new_rtn_item_rec.shipped_split_cd;
    
  --   dbms_output.put_line('in i_action =A; l_add_qty:'|| l_add_qty);
    
    l_del_flag            := 'Y'; -- there is an existing return for this add to be deleted
    
    l_del_stop_no := i_new_rtn_item_rec.stop_no;
    l_del_obligation_no := i_new_rtn_item_rec.obligation_no;
    l_del_prod_id :=  i_new_rtn_item_rec.prod_id;
    l_del_cust_pref_vendor :=  i_new_rtn_item_rec.cust_pref_vendor;
    l_del_return_reason_cd := i_new_rtn_item_rec.return_reason_cd;
    l_del_returned_split_cd :=  i_new_rtn_item_rec.returned_split_cd;
    
  EXCEPTION
  WHEN NO_DATA_FOUND THEN
  
    l_del_flag := 'N';  -- there is no existing return for this add to be deleted
  WHEN OTHERS THEN
      l_del_flag := 'N';  
      l_status     := rf.status_data_error;
      l_msg        := 'ERROR:Selecting data in Returns during save_rtn -'||sqlerrm;
      pl_log.ins_msg('WARN', l_func_name, l_msg, NULL, NULL, APPLICATION_FUNC, PACKAGE_NAME);  
  END;
ELSE  
  l_del_flag    := 'N';  -- for  i_action IN ('R', 'C') we should not delete the return
  l_status    := rf.status_normal;
END IF; 
  
  IF l_del_flag    = 'Y' THEN
     
      dbms_output.put_line('in before delete rtn' );
      
      l_msg        := 'Before Delete_Return call: '||l_status;
      pl_log.ins_msg('INFO', l_func_name, l_msg, NULL, NULL, APPLICATION_FUNC, PACKAGE_NAME);  
  
     l_status  := pl_rf_dci_pod.delete_rtn( i_manifest_no , l_del_stop_no , 
                                            l_del_obligation_no , l_del_prod_id , 
                                            l_del_cust_pref_vendor , l_del_return_reason_cd , 
                                            l_del_returned_split_cd );
  End If;
  
	IF i_action ='U'  Then
  --and (i_orig_rtn_item_rec.rec_type ='P' or l_group ='WIN') THEN --update the return  for  pickup Items, do not delete.
   
    dbms_output.put_line('in update rtn for rec type P or its invoice return:' );
   
     l_status  := pl_rf_dci_pod.delete_rtn_pending_puts (i_manifest_no ,i_orig_rtn_item_rec.erm_line_id   ) ; 
     
      l_msg        := 'Status after delete_rtn_pending_puts: '||l_status;
      pl_log.ins_msg('INFO', l_func_name, l_msg, NULL, NULL, APPLICATION_FUNC, PACKAGE_NAME);  
     
    IF l_status    = rf.status_normal THEN
    
      l_msg        := 'in update rtn for action =U';
      pl_log.ins_msg('INFO', l_func_name, l_msg, NULL, NULL, APPLICATION_FUNC, PACKAGE_NAME);  
      
      
       -- add check for rtn qty here as well
     
    l_status   := check_rtn_qty(i_manifest_no, i_orig_rtn_item_rec,i_new_rtn_item_rec.returned_qty,
                                i_orig_rtn_item_rec.erm_line_id, i_new_rtn_item_rec.returned_split_cd);
     
  
    IF l_status <> rf.status_normal then
    
      Return l_status ;
    End If;   
      
  
     BEGIN
      UPDATE returns
      SET STATUS ='VAL',
      ERR_COMMENT ='',
      RETURNED_QTY      = i_new_rtn_item_rec.returned_qty,
      RETURN_REASON_CD  =i_new_rtn_item_rec.return_reason_cd,
      RETURNED_SPLIT_CD = i_new_rtn_item_rec.returned_split_cd,
      CATCHWEIGHT       = DECODE(i_new_rtn_item_rec.catchweight,NULL_VAL_INDICATOR, NULL,i_new_rtn_item_rec.catchweight),      
      TEMPERATURE       = DECODE(i_new_rtn_item_rec.temperature,NULL_VAL_INDICATOR, NULL,i_new_rtn_item_rec.temperature),
      RETURNED_PROD_ID  = i_new_rtn_item_rec.returned_prod_id,
      DISPOSITION       = i_new_rtn_item_rec.disposition,
      UPD_USER = replace(user, 'OPS$'),
      UPD_DATE = SYSDATE,
      UPD_SOURCE = 'RF'
      WHERE manifest_no      = i_manifest_no
      AND return_reason_cd   = i_orig_rtn_item_rec.return_reason_cd
      AND (stop_no           = i_orig_rtn_item_rec.stop_no
        OR stop_no           IS NULL)
      AND prod_id            = i_orig_rtn_item_rec.prod_id
      AND cust_pref_vendor   = i_orig_rtn_item_rec.cust_pref_vendor
      AND obligation_no      = i_orig_rtn_item_rec.obligation_no
      AND shipped_split_cd   = i_orig_rtn_item_rec.shipped_split_cd;
    EXCEPTION
    WHEN OTHERS THEN
      l_status     := rf.status_data_error;
      
      l_msg        := 'ERROR. Attempted to update [' || sql%rowcount || '] records in Returns during update return. Action DENIED';
      pl_log.ins_msg('WARN', l_func_name, l_msg, NULL, NULL, APPLICATION_FUNC, PACKAGE_NAME);
    END; -- updating returns
  END IF;
     
  End If;
  																												 
 --  dbms_output.put_line('before iaction R, C' );
  
  IF i_action IN ('R', 'C') THEN 
   ---when user chooses to reverse credit (R/C) updateexisting Return's pod_rtn_ind= 'D'; for the Option C create new Return record with new values sent
  IF l_status    = rf.status_normal THEN
  
  l_msg        := 'in update rtn  to pod_rtn_ind = D for i_action = R, C';
  pl_log.ins_msg('INFO', l_func_name, l_msg, NULL, NULL, APPLICATION_FUNC, PACKAGE_NAME);  
  
 
    BEGIN
      UPDATE returns
      SET pod_rtn_ind = 'D' ,
      STATUS ='CMP',
      UPD_USER = replace(user, 'OPS$'),
      UPD_DATE = SYSDATE
      WHERE manifest_no      = i_manifest_no
      AND return_reason_cd   = i_orig_rtn_item_rec.return_reason_cd
      AND (stop_no           = i_orig_rtn_item_rec.stop_no
        OR stop_no           IS NULL)
      AND prod_id            = i_orig_rtn_item_rec.prod_id
      AND cust_pref_vendor   = i_orig_rtn_item_rec.cust_pref_vendor
      AND obligation_no      = i_orig_rtn_item_rec.obligation_no
      AND shipped_split_cd   = i_orig_rtn_item_rec.shipped_split_cd
      AND rtn_sent_ind       ='Y';
    EXCEPTION
    WHEN OTHERS THEN
      l_status     := rf.status_data_error;
      
      l_msg        := 'ERROR. Attempted to update [' || sql%rowcount || '] records in Returns during add return. ADD DENIED';
      pl_log.ins_msg('WARN', l_func_name, l_msg, NULL, NULL, APPLICATION_FUNC, PACKAGE_NAME);
    END; -- updating returns
  END IF;
  
      
    -- call for delete of food safety data for rever credit 'R', 'C'
     IF l_status = rf.status_normal THEN
    
         pl_dci.dci_food_safety('D',
     	   i_manifest_no,
	       i_orig_rtn_item_rec.stop_no,
	       i_orig_rtn_item_rec.prod_id,
	       i_orig_rtn_item_rec.OBLIGATION_NO,
	       i_orig_rtn_item_rec.cust_id ,
         i_orig_rtn_item_rec.temperature,
          'RF',
         Sysdate,
         i_orig_rtn_item_rec.return_reason_cd,
         l_group,
         l_msg);   
         
         If  l_msg is null then 
            l_status := rf.status_normal;
         else    
               ROLLBACK;
              l_msg := 'Insert of Foodsafety data failed for manifest#[' || i_manifest_no|| ']';
              pl_log.ins_msg('FATAL', l_func_name, l_msg, SQLCODE, SUBSTR(SQLERRM, 1, 500), APPLICATION_FUNC, PACKAGE_NAME);
             l_status := rf.status_update_fail;
         end if;    
         
     End If; 
     
  IF l_status = rf.status_normal AND i_action = 'R' THEN  -- -- when user chooses reverse return (R) corresponding Manifest_dtls record is set to OPN.
    BEGIN
    
     --  dbms_output.put_line('in update manifest' );
    
      UPDATE manifest_dtls
      SET manifest_dtl_status = 'OPN'
      WHERE manifest_no       = i_manifest_no
      AND (stop_no            = i_orig_rtn_item_rec.stop_no
        OR stop_no              IS NULL)
      AND prod_id             = i_orig_rtn_item_rec.prod_id
      AND cust_pref_vendor    = i_orig_rtn_item_rec.cust_pref_vendor
      AND obligation_no       = i_orig_rtn_item_rec.obligation_no
      AND shipped_split_cd    = i_orig_rtn_item_rec.shipped_split_cd
      AND NOT EXISTS (SELECT 'X' from returns
                      WHERE manifest_no       = i_manifest_no
                      AND (stop_no            = i_orig_rtn_item_rec.stop_no
                        OR stop_no              IS NULL)
                      AND prod_id             = i_orig_rtn_item_rec.prod_id
                      AND return_reason_cd    <> i_orig_rtn_item_rec.return_reason_cd
                      AND cust_pref_vendor    = i_orig_rtn_item_rec.cust_pref_vendor
                      AND obligation_no       = i_orig_rtn_item_rec.obligation_no); --clause to check if other RTN records exsist for this manifest dtl 
    EXCEPTION
    WHEN OTHERS THEN
   --   dbms_output.put_line('in manifest update others exception' );
    
      l_status     := rf.status_data_error;
    
      l_msg        := 'ERROR. Attempted to update manifest_dtls to OPN status during deletion of old return for Add. ADD DENIED';
      pl_log.ins_msg('WARN', l_func_name, l_msg, NULL, NULL, APPLICATION_FUNC, PACKAGE_NAME);
    END ; -- updating manifest_dtls
  END IF; 
    
    -- delete potential pending puts when rever credit
    IF l_status = rf.status_normal THEN
    
   --    dbms_output.put_line('before  pl_rf_dci_pod.delete_rtn_pending_puts' );
      
       l_status := pl_rf_dci_pod.delete_rtn_pending_puts(i_manifest_no, i_orig_rtn_item_rec.erm_line_id);
      
   --     dbms_output.put_line('after  pl_rf_dci_pod.delete_rtn_pending_puts' );
    END IF; -- delete potential pending puts
    
  END IF;   --i_action
  
  IF l_status   = rf.status_normal AND i_action in ('A', 'C') THEN  -- a new return is created for 'A',  'C' actions from user
  
    if l_group not in ('OVR', 'OVI', 'WIN') then  -- for overage and invoice updates dont not check
    
     l_status   := check_rtn_qty(i_manifest_no, nvl(i_orig_rtn_item_rec,i_new_rtn_item_rec),i_new_rtn_item_rec.returned_qty +l_add_qty,
                                 i_new_rtn_item_rec.erm_line_id, i_new_rtn_item_rec.returned_split_cd);
     
      dbms_output.put_line('status after check rtn qty :' ||l_status);
    end if;
   
    
    IF l_status <> rf.status_normal then
    
      Return l_status ;
    End If;   
   
     IF l_status = rf.status_normal  and  (i_orig_rtn_item_rec.rec_type <> 'P')  THEN  -- add new return only for non pickup Items.
    
   --   IF  l_group <> 'WIN' Then
       
      BEGIN
      
       BEGIN
       
          SELECT nvl(MAX(nvl(erm_line_id, 0)), 0)
          INTO l_erm_line_id
          FROM   returns
          WHERE  manifest_no = i_manifest_no;

          EXCEPTION
          WHEN OTHERS THEN
             l_erm_line_id := 0;
       END;
      
        INSERT
        INTO Returns
          ( manifest_no,
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
            status,
            rtn_sent_ind,
            pod_rtn_ind,
            lock_chg,
            Add_user,
            add_source,
            Add_date,
            upd_user ,
            upd_source ,
            upd_date )
          VALUES
          ( i_manifest_no,
            i_route_no,
            DECODE(nvl(i_orig_rtn_item_rec.stop_no,i_new_rtn_item_rec.stop_no) ,NULL_VAL_INDICATOR, NULL,nvl(i_orig_rtn_item_rec.stop_no,i_new_rtn_item_rec.stop_no)),
            i_new_rtn_item_rec.rec_type,
            DECODE(nvl(i_orig_rtn_item_rec.obligation_no,i_new_rtn_item_rec.obligation_no) ,NULL_VAL_INDICATOR, NULL,nvl(i_orig_rtn_item_rec.obligation_no,i_new_rtn_item_rec.obligation_no)),
            nvl(i_orig_rtn_item_rec.prod_id, i_new_rtn_item_rec.prod_id) ,
            i_new_rtn_item_rec.cust_pref_vendor,
            i_new_rtn_item_rec.return_reason_cd,
            i_new_rtn_item_rec.returned_qty+l_add_qty,
            i_new_rtn_item_rec.returned_split_cd,
            DECODE(i_new_rtn_item_rec.catchweight,NULL_VAL_INDICATOR, NULL,i_new_rtn_item_rec.catchweight),
            i_new_rtn_item_rec.disposition,
            i_new_rtn_item_rec.returned_prod_id,
            l_erm_line_id+1,
            nvl(i_orig_rtn_item_rec.shipped_qty,i_new_rtn_item_rec.shipped_qty),
            nvl(i_orig_rtn_item_rec.shipped_split_cd,i_new_rtn_item_rec.shipped_split_cd),
            DECODE(nvl(i_orig_rtn_item_rec.cust_id, i_new_rtn_item_rec.cust_id),0,NULL, nvl(i_orig_rtn_item_rec.cust_id, i_new_rtn_item_rec.cust_id)),
            DECODE(i_new_rtn_item_rec.temperature,NULL_VAL_INDICATOR, NULL,i_new_rtn_item_rec.temperature) ,				 
            'VAL',
            NULL,
            'A',
            NULL,
            replace(user, 'OPS$'),
            nvl(i_orig_rtn_item_rec.add_source, 'RF'),
            sysdate,
            replace(user, 'OPS$'),
             'RF',
            SYSDATE);
         --l_group <> 'WIN'    
          --  dbms_output.put_line('after insert:' );
      EXCEPTION
      WHEN OTHERS THEN
        ROLLBACK;
        l_msg := 'Insert of Returns failed for manifest#[' || i_manifest_no|| ']';
        pl_log.ins_msg('FATAL', l_func_name, l_msg, SQLCODE, SUBSTR(SQLERRM, 1, 500), APPLICATION_FUNC, PACKAGE_NAME);
        l_status := rf.status_update_fail;
       
      END;  --Insert in to returns
  --  End If;
    
   END IF; -- end if Insert in to returns
 
    
  END IF;   -- l_del_status = rf.status_normal and i_action 'A', 'C'   
 
    -- call for food safety
   
     IF l_status = rf.status_normal and i_action <>'R' and l_group not in  ('DMG', 'STM', 'MPK')  THEN  --Jira 3854
     
       select  DECODE(i_new_rtn_item_rec.food_safety_temp, NULL_VAL_INDICATOR, NULL,i_new_rtn_item_rec.food_safety_temp) 
       into l_temp from dual;
    
         pl_dci.dci_food_safety('I',
     	   i_manifest_no,
	       nvl(i_orig_rtn_item_rec.stop_no,i_new_rtn_item_rec.stop_no),
	       i_new_rtn_item_rec.prod_id,
	       nvl(nvl(i_orig_rtn_item_rec.obligation_no,i_new_rtn_item_rec.obligation_no), 0),
	       nvl(i_orig_rtn_item_rec.cust_id, i_new_rtn_item_rec.cust_id) ,
         l_temp,
          'RF',
         Sysdate,
         i_new_rtn_item_rec.return_reason_cd,
         l_group,
         l_msg);   
         
         If  l_msg is null then 
            l_status := rf.status_normal;
         else    
               ROLLBACK;
              l_msg := 'Insert of Foodsafety data failed for manifest#[' || i_manifest_no|| ']';
              pl_log.ins_msg('FATAL', l_func_name, l_msg, SQLCODE, SUBSTR(SQLERRM, 1, 500), APPLICATION_FUNC, PACKAGE_NAME);
             l_status := rf.status_update_fail;
         end if;    
         
     End If;    
           
    IF l_status = rf.status_normal THEN
    
    BEGIN
   --     dbms_output.put_line('in update manifestdtl after insert' );
    
      UPDATE manifest_dtls
      SET manifest_dtl_status = 'RTN'
      WHERE manifest_no       = i_manifest_no
      AND (stop_no            = i_new_rtn_item_rec.stop_no
      OR stop_no              IS NULL)
      AND prod_id             = i_new_rtn_item_rec.prod_id
      AND cust_pref_vendor    = i_new_rtn_item_rec.cust_pref_vendor
      AND obligation_no       = i_new_rtn_item_rec.obligation_no
      AND shipped_split_cd    = i_new_rtn_item_rec.shipped_split_cd;
    EXCEPTION
    WHEN OTHERS THEN
      l_status     := rf.status_data_error;
    
      l_msg        := 'ERROR. Attempted to update manifest_dtls to RTN status during Add return. ADD DENIED';
      pl_log.ins_msg('WARN', l_func_name, l_msg, NULL, NULL, APPLICATION_FUNC, PACKAGE_NAME);
    END ; -- updating manifest_dtls
    
    END IF; --   UPDATE manifest_dtls
    

  
  RETURN l_status;
EXCEPTION
WHEN OTHERS THEN
  l_msg := 'ERROR in insert_return() for manifest# ['|| i_manifest_no|| ']';
  pl_log.ins_msg('FATAL', l_func_name, l_msg, SQLCODE, SUBSTR(SQLERRM, 1, 500), APPLICATION_FUNC, PACKAGE_NAME);
  rf.logexception();
  RAISE;
END;
---====================================================================================================
 /************************************************************************
    -- save_rtn_rf
    --
    -- Description:  This is RF function that handles saving for
    -- Add, Update, Reverse and Credit process for a Return.
    --
    -- i_action: Input parameter expects values  A,U,R,C    
    --
    -- Return/output: rtn_validation_obj, rf.status
    --
    -- Modification log:
    --
    -- Date         Developer     Change
    -- ------------------------------------------------------------------
    -- 17-Nov-2020  vkal9662      Initial version.
    --
    *************************************************************************/
   FUNCTION save_rtn_rf(
    i_rf_log_init_rec      IN  rf_log_init_record,
    i_action               IN VARCHAR2 := 'A', --A,U,R,C (possible values)
    i_manifest_no          IN returns.manifest_no%TYPE,
    i_orig_rtn_item_rec    IN rtn_item_rec,
    i_new_rtn_item_rec     IN rtn_item_rec,
    o_returned_items_list  OUT rtn_validation_obj)
    RETURN rf.status 
  IS
    l_status rf.status         := rf.status_normal;
    l_ins_status rf.status     := rf.status_normal;
    l_item_list rtn_item_table := rtn_item_table();
    l_val_status rf.status     := rf.status_normal;
    l_route_no manifests.route_no%TYPE;
    l_msg swms_log.msg_text%TYPE;
    l_func_name CONSTANT swms_log.procedure_name%TYPE := 'save_rtn_rf';
  BEGIN
    -- Initialize the out parameter
    o_returned_items_list := rtn_validation_obj(i_manifest_no, 'N', ' ', rtn_item_table());
    -- Call rf.initialize(). cannot procede if return status is not successful.
    l_status := rf.initialize(i_rf_log_init_rec);
    -- Log the input received from the RF client
    l_msg := 'Starting ' || l_func_name || '. Received data from RF client: [' || i_manifest_no || '] for save_rtn_rf';
    pl_log.ins_msg('INFO', l_func_name, l_msg, NULL, NULL, APPLICATION_FUNC, PACKAGE_NAME);
    BEGIN
      SELECT route_no
      INTO l_route_no
      FROM manifests
      WHERE manifest_no = i_manifest_no;
    EXCEPTION
    WHEN no_data_found THEN
      RETURN RF.STATUS_INVALID_MF;
    END ;
    -- insert in to returns table the return record sent by RF
    l_status := save_rtn(i_action, i_manifest_no,l_route_no, i_orig_rtn_item_rec,i_new_rtn_item_rec);
    --if insert is sucessful return all the returns for the manifest back to RF
    IF l_status = rf.status_normal THEN
      COMMIT;
      l_status := pl_rf_dci_pod.validate_mf_rtn( i_manifest_no, 'Y', o_returned_items_list);
    ELSE
     Rollback;
    END IF; --l_ins_status
    rf.complete(l_status);
    RETURN l_status;
  EXCEPTION
  WHEN OTHERS THEN
    l_msg := 'ERROR in save_rtn_rf process for manifest# [' || i_manifest_no || ']';
    pl_log.ins_msg('FATAL', l_func_name, l_msg, SQLCODE, SUBSTR(SQLERRM, 1, 500), APPLICATION_FUNC, PACKAGE_NAME);
    rf.logexception();
    RAISE;
  END save_rtn_rf;
END pl_rf_dci_pod;
/

ALTER PACKAGE swms.pl_rf_dci_pod COMPILE PLSQL_CODE_TYPE = NATIVE;
GRANT EXECUTE ON swms.pl_rf_dci_pod TO swms_user;
CREATE OR REPLACE PUBLIC SYNONYM pl_rf_dci_pod FOR swms.pl_rf_dci_pod;
