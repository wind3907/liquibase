CREATE OR REPLACE PACKAGE swms.Pl_Rcv_Po_Close
IS
   -- sccs_id=%Z% %W% %G% %I%
   -----------------------------------------------------------------------------
   -- Package Name:
   --   PO_CLOSE
   --
   -- Description:
   --    This package will perform the functions necessary to successfully
   --    close a Purchase Order.  Any problems will be sent back to the RF
   --    terminal as a status code and will be logged to the SWMS_LOG table.
   --
   -- Modification History:
   --    Date     Designer Comments
   --    -------- -------- -----------------------------------------------------
   --    01/20/02 prpswp   Created.
   --    07/18/02 prpbcb   rs239a DN 10919  rs239b DN 10920  Ticket 329125
   --                      Changed some of the swms.log messages to show the
   --                      PO number.
   --    07/14/03 acppzp   DN 11349 Changes made for OSD ,SN Receipt
   --    11/08/03 prpbcb   Oracle 7 rs239a DN none.  Not dual maintained
   --                      Oracle 8 rs239b dvlp8 DN none.  Not dual maintained
   --                      Oracle 8 rs239b dvlp9 DN 11416
   --                      MSKU changes for forklift labor mgmt.
   --                      Populate the trans.labor_batch_no column when
   --                      creating PUT transactions for pallets not putaway.
   --    01/29/04 prpakp   Added the check for tti_trk in data collection
   --                      before closing the PO.
   --    12/13/04 prphqb   Check for MSKU count > 60 then issue error message
   --    01/11/04 prpakp   Corrected the check_msku_too_large procedure to
   --                      track when no_data_found and set the error message
   --                      as null. This will allow all PO's and SN's with no
   --                      msku to be closed.
   --    02/10/05 prphqb   Cannot close PO with uncollected COOL data
   --	 22/01/06 acpvxg   Added the procedure p_send_er.This will send the 
   --	 		   expected receipt message to miniloader.
   --	 03/02/06 acpvxg   Modified cursor put_cur in procedure upd_inv. Added 
   --	 		   parent_pallet_id to the select list of cursor.
   --			   Modified the insert into trans table queries, added 
   --			   parent_pallet_id to the insert list.  
   --    08/21/06 prpbcb   DN 12133
   --                      Ticket: 229523
   --                      Project: Expected receipt not sent to miniload
   --                      No expected receipt transaction was sent to the
   --                      miniloader when a miniload item was on an extended
   --                      PO and was not confirmed putaway before the main
   --                      PO was closed (which closes the extended PO's).
   --                      Changed cursor c_pallets_for_putaway in procedure
   --                      p_send_er() from
   --     CURSOR c_pallets_for_putaway (v_rec_id IN putawaylst.rec_id%TYPE)
   --         IS
   --     SELECT pallet_id, prod_id, cust_pref_vendor, dest_loc, qty, uom
   --      FROM putawaylst
   --     WHERE rec_id = v_rec_id AND putaway_put = 'N';
   --                      to
   --    CURSOR c_pallets_for_putaway (cp_rec_id IN putawaylst.rec_id%TYPE)
   --    IS
   --       SELECT p.pallet_id,
   --              p.prod_id,
   --              p.cust_pref_vendor,
   --              p.dest_loc,
   --              p.qty,
   --              p.uom
   --         FROM erm,
   --              putawaylst p
   --        WHERE erm.po      = cp_rec_id
   --          AND p.rec_id    = erm.erm_id
   --          AND putaway_put = 'N';
   --                      to select the putaway tasks on extended PO's.
   --   10/27/06 Infosys  When a PO is closed the MSKU flag in inv table should
   -- 			  be cleared. This change has been incorporated into
   --			  update_inv procedure 
   --    01/31/07 prpbcb   DN 12214
   --                      Ticket: 326211
   --                      Project: 326211-Miniload Induction Qty Incorrect
   --
   --                      The wrong qty was sent to the miniloader in the
   --                      expected receipt message.  putawaylst.qty was used
   --                      when it should have been putawaylst.qty_received.
   --                      Modified procedure p_send_er() to fix this.
   --    09/02/08 prppxx   DN 12410 TK 669612
   --                      p_send_er() sends SYSDATE as l_er_info.v_inv_date(exp_date).
   --                      Change to populate it with putawaylst.exp_date.
   --                   					
   --	 11/05/09 ctvgg000 ASN to all OPCOs project
   --			   Update RDC_PO table for VN PO's, For RDC PO's, the 
   --			   PO status is sent down from SUS. But for VN PO's SWMS 
   --			   to update the Status in RDC_PO table. 
   --
   --	 12/17/09 prpbcb   DN 12533
   --                      Removed AUTHID CURRENT_USER.  We found a problem in
   --                      pl_rcv_open_po_cursors.f_get_inv_qty when using it.
   --
   --    01/22/10 sgan0455 DN12554 - 212 Enh - SCE012
   --                      Track Trailer Temperature
   --                      Written a new procedure to check if temperature 
   --                      is present and throw error message if not
   --
   --   02/03/10 ykri0358 DN#12529 Modified the update_inv procedure to send 
   --                              all PUT transactions with qty > 0 to SAP 
   --                               for SCI003-C interface.
   --   27/03/12 pshr2440 CRQ39421 Added insert statement to insert the data in trans table 
   --                                even if received quantity is zero for host_type SAP.
   
   --   03/04/13 pshr2440 CRQ45458 inserting maint_flag value as 'Y' for SAP
   --   08/06/15 Infosys  Made changes for accomodating bahamas weight unit handling.
   --                     Need to send the prod_id back instead of NULL to calling program
   --                     changes done on get_case_split_pallet_counts and handle_splecial_pallets  
   --  30-MAY-14  ajai9091  - Charm#600000054
   -- European Imports Cross dock pallet receiving changes
   --
   --    Date     Designer Comments
   --    -------- -------- -----------------------------------------------------
   --    01/31/07 bben0556 Brian Bent
   --                      Project:
   --  R30.6--WIE#669--CRQ000000008118_Live_receiving_story_1228_bug_fix_able_to_close_po_with_LR_locations
   --
   --                      In places checking for '*' dest_loc also check for
   --                      'LR' dest loc.
   --                      Approximate line numbers: 1040, 1514, 1606, 2238, 2330.
   --
   --                     Tried using "pl_rcv_open_po_lr.ct_lr_dest_loc" instead of
   --                     hardcoding 'LR' but got compile error.  So hardcoded 'LR'.
   --                     Example:
   --                     This was an error
   --                         AND y.dest_loc NOT IN ('*', '**', pl_rcv_open_po_lr.ct_lr_dest_loc);
   --                     This was OK
   --                         AND y.dest_loc NOT IN ('*', '**', 'LR');
   --
   --    07/24/18 xzhe5043 Added auto_close_po procedure to allow internal production PO can be auto closed
   --                      shell script auto_close_po.sh will call this procedure
   --    12/05/18 mpha8134 Modify auto_close_po procedure to close Finish Good POs coming from SUS Prime
   --	 04/05/19 sban3548 Modified close_po program to insert vendor_id, vendor_name, load_no, rec_date
   -- 			   into sp_pallet table for Blue-Chep pallet tracking 	
   --
   --    09/18/19 pkab6563 Jira# OPCOF-2558: do not clear the parent_pallet_id in inv for cross dock.
   --	 07/30/20 sban3548 Jira# OPCOF-3144: Modified Update erd received quantities correctly for SAP opco
   --						if the PO line item has 2 different lines for each UOM.
   --
   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   -- Global variables
   -----------------------------------------------------------------------------
   e_po_locked EXCEPTION;
   e_premature_termination EXCEPTION;
   PRAGMA EXCEPTION_INIT(e_po_locked,-54);
   g_rf_flag CHAR(1);
   g_err_msg VARCHAR2(255);
   g_exit_msg VARCHAR2(255);
   g_sqlcode NUMBER;
   g_row_count NUMBER;
   g_rf_confirm_flag sys_config.config_flag_val%TYPE;
   g_putaway_confirm_flag sys_config.config_flag_val%TYPE;
   g_erm_rec erm%ROWTYPE;
   g_pm_rec pm%ROWTYPE;
   g_tmp_weight_rec tmp_weight%ROWTYPE;
   gv_osd_sys_flag  sys_config.config_flag_val%TYPE :='';
   g_ei_pallet CHAR(1);

   TYPE t_ClientRecType IS RECORD (
      flag CHAR(1),
      sp_flag CHAR(1),
      user_id VARCHAR2(30),
      sp_supplier_name VARCHAR(500),
      sp_supplier_qty VARCHAR(100));
   g_client t_ClientRecType;
   TYPE t_ServerRecType IS RECORD (
      sp_current_total NUMBER,
      sp_supplier_count NUMBER,
      erm_id erm.erm_id%TYPE,
      prod_id pm.prod_id%TYPE,
      cust_pref_vendor pm.cust_pref_vendor%TYPE,
      exp_splits NUMBER,
      exp_qty NUMBER,
      rec_splits NUMBER,
      rec_qty NUMBER,
      hld_cases NUMBER,
      hld_splits NUMBER,
      hld_pallet NUMBER,
      total_pallet NUMBER,
      num_pallet NUMBER,
      status NUMBER);
   g_server t_ServerRecType;
   CURSOR c_po_lock (cp_rec_id VARCHAR2) IS
   SELECT erm_id
     FROM erm
    WHERE po = cp_rec_id
   FOR UPDATE OF status, close_date, maint_flag NOWAIT;

   --acppzp DO-105 Changes for OSD design
   CURSOR c_po_puts (cp_rec_id VARCHAR2) IS
     SELECT pallet_id,status
     FROM putawaylst
     WHERE rec_id = cp_rec_id
     AND putaway_put = 'N';

   --acppzp DO-105 Changes for OSD design
   -----------------------------------------------------------------------------
   -- Public Constants
   -----------------------------------------------------------------------------
   ct_BLD_REC NUMBER := 30;
   ct_CLO_PO NUMBER := 91;
   ct_DATA_ERROR NUMBER := 80;
   ct_ERM_UPDATE_FAIL NUMBER := 119;
   ct_EXTEND_PO NUMBER := 104;
   ct_INSERT_FAIL NUMBER := 12;
   ct_INV_OPT NUMBER := 29;
   ct_INV_PO NUMBER := 90;
   ct_INV_PRODID NUMBER := 37;
   ct_INV_DEST_LOC NUMBER := 73;
   ct_LOCKED_PO NUMBER := 112;
   ct_MORE_REC_DATA NUMBER := 92;
   ct_PM_UPDATE_FAIL NUMBER := 121;
   ct_SEL_SYSCFG_FAIL NUMBER := 124;
   ct_QTY_NOT_MATCH NUMBER := 65;
   ct_TRANS_INSERT_FAILED NUMBER := 163;
   ct_PROGRAM_CODE VARCHAR2(5) := 'RE03';
   ct_SELECT_ERROR NUMBER := 400;
   ct_SN_HEADER_UPDATE_FAIL NUMBER := 401;
   ct_NUM_PALLETS_MSKU NUMBER := 60;
   ct_MSKU_LP_LIMIT_ERROR NUMBER := 338;
   ct_MSKU_LP_LIMIT_MSG VARCHAR2(60):='MSKU pallet should be sub-divided before continuing.';
   -----------------------------------------------------------------------------
   -- Procedures
   -----------------------------------------------------------------------------
   PROCEDURE mainproc(i_rec_id IN CHAR, o_exit_msg OUT VARCHAR2);
   PROCEDURE mainproc_rf(i_rec_id IN CHAR, i_flag IN CHAR, i_sp_flag IN CHAR, i_user_id IN CHAR,
      i_sp_supplier_name IN VARCHAR2, i_sp_supplier_qty IN VARCHAR2,
      o_sp_current_total OUT NUMBER, o_sp_supplier_count OUT NUMBER, o_erm_id OUT CHAR,
      o_prod_id OUT CHAR, o_cust_pref_vendor OUT CHAR, o_exp_splits OUT NUMBER,
      o_exp_qty OUT NUMBER, o_rec_splits OUT NUMBER, o_rec_qty OUT NUMBER,
      o_hld_cases OUT NUMBER, o_hld_splits OUT NUMBER, o_hld_pallet OUT NUMBER,
      o_total_pallet OUT NUMBER, o_num_pallet OUT NUMBER,
      o_status OUT NUMBER, ot_sp_suppliers IN OUT VARCHAR2);
   PROCEDURE lock_po(i_rec_id IN VARCHAR2);
   PROCEDURE verify_po_info(i_rec_id IN VARCHAR2);
   PROCEDURE check_for_putaway_tasks;
   PROCEDURE check_for_data_collection(i_rec_id IN VARCHAR2);
   PROCEDURE check_for_matching_quantities(i_rec_id IN VARCHAR2);
   PROCEDURE request_catch_weight(i_rec_id IN VARCHAR2);
   PROCEDURE check_catch_weight(i_rec_id IN VARCHAR2);
   PROCEDURE get_confirmation_requirements;
   PROCEDURE get_case_split_pallet_counts(i_rec_id IN VARCHAR2);
   PROCEDURE handle_special_pallets(i_rec_id IN VARCHAR2, ot_sp_suppliers IN OUT VARCHAR2);
   PROCEDURE update_lm_batch_lite(i_rec_id IN VARCHAR2);
   PROCEDURE update_lm_batch(i_rec_id IN VARCHAR2);
   PROCEDURE update_erd(i_rec_id IN VARCHAR2);
   PROCEDURE update_inv(i_rec_id IN VARCHAR2);
   PROCEDURE close_po(i_rec_id IN VARCHAR2);
   PROCEDURE sync_tmp_weight_internal_po(i_rec_id IN VARCHAR2);
   PROCEDURE auto_close_po;
   PROCEDURE check_msku_too_large(i_rec_id IN CHAR);
   FUNCTION f_get_haul_location(p_pallet_id IN VARCHAR2) RETURN VARCHAR2;
   FUNCTION check_finish_good_PO(i_erm_id IN VARCHAR2) RETURN CHAR;
   --acpvxg beg add 22-jan-06  
   PROCEDURE p_send_er (i_rec_id IN putawaylst.rec_id%TYPE);
   --acpvxg end add 22-jan-06 
 
   /* 01/22/10 - 12554 - sgan0455 - Added for 212 Enh - SCE012 - Begin */
   PROCEDURE verify_temp_track_ind(i_rec_id IN VARCHAR2); 
   /* 01/22/10 - 12554 - sgan0455 - Added for 212 Enh - SCE012 - End */
   PROCEDURE update_ei_inv(i_rec_id IN VARCHAR2);
   /* Created for EI po close */ 
   /* Created for EI po close */

    PROCEDURE p_execute_frm (
        i_userid          IN  VARCHAR2,
        i_func_parameters   IN  VARCHAR2,
        o_status   OUT VARCHAR2
    );
END;
/


CREATE OR REPLACE PACKAGE BODY swms.Pl_Rcv_Po_Close IS


  /*************************************************************************
  ** p_execute_frm
  **  Description: Main Program to be called from the PL/SQL wrapper/Forms
  **  Called By : DBMS_HOST_COMMAND_FUNC
  **  PARAMETERS:
  **      i_userid - User ID passed from Frontend as Input
  **      i_func_parameters - Function parameters passed from Frontend as Input
  **      o_out_status   - Output parameter returned to front end
  **  RETURN VALUES:
  **      Success or Failure message will be sent
  **
  ****************************************************************/

    PROCEDURE p_execute_frm (
        i_userid          IN  VARCHAR2,
        i_func_parameters   IN  VARCHAR2,
        o_status          OUT VARCHAR2
    ) IS
        l_func_name   VARCHAR2(50) := 'pl_rcv_po_close.p_execute_frm';
        v_count       NUMBER := 0;
        l_err_msg     VARCHAR2(4000);
        l_erm_id      VARCHAR2(12);
        l_employee_id VARCHAR2(9); /* Parameter 2 Employee ID is not used - 08/10/2020 */
        v_prams_list  c_prams_list;
    BEGIN
        v_prams_list := F_SPLIT_PRAMS(i_func_parameters);
        v_count := v_prams_list.count;
        pl_text_log.ins_msg('INFO', l_func_name, 'F_SPLIT_PRAMS invoked...', sqlcode, sqlerrm);
        pl_text_log.ins_msg('INFO', l_func_name, 'F_SPLIT_PRAMS size:' || v_count, sqlcode, sqlerrm);

        IF v_count = 1 OR v_count = 2 THEN
            pl_text_log.ins_msg('INFO', l_func_name, 'Param List : [' || i_func_parameters || ']', sqlcode, sqlerrm);
            l_erm_id := v_prams_list(1);

            pl_text_log.ins_msg('INFO', l_func_name, 'Executing Main Procedure', NULL, NULL);
            mainproc(l_erm_id, l_err_msg);
        ELSE
            pl_text_log.ins_msg('INFO', l_func_name, 'Invalid number of arguments', sqlcode, sqlerrm);
            l_err_msg := 'FAILURE - Invalid number of arguments';
        END IF;

        o_status := l_err_msg;
    EXCEPTION WHEN OTHERS THEN
        pl_text_log.ins_msg('WARN', l_func_name, 'Exception Raised at ' || l_func_name || 'for params ' || i_func_parameters, sqlcode, sqlerrm);
        o_status := 'FAILURE - Exception Raised while the Execution';
    END p_execute_frm;

   -----------------------------------------------------------------------------
   -- Procedure main - Close from CRT screen
   -----------------------------------------------------------------------------
   PROCEDURE mainproc(i_rec_id IN CHAR, o_exit_msg OUT VARCHAR2) IS
      l_rec_id erm.erm_id%TYPE;
      l_object_name   VARCHAR2 (30 CHAR) := 'mainproc';
      l_erm_type      erm.erm_type%TYPE;
      l_message       VARCHAR2(200);
      l_code          NUMBER;
	  
   BEGIN
      g_exit_msg := 'SN/PO Close completed.';
      g_rf_flag := 'N';
      l_rec_id := RTRIM(i_rec_id);
	  g_ei_pallet := pl_rcv_cross_dock.f_is_crossdock_pallet (l_rec_id, 'E');
      Pl_Text_Log.ins_msg('DEBUG',ct_PROGRAM_CODE,'Close SN/PO '||l_rec_id,SQLCODE,SQLERRM);

      /* Retrieve the erm type for the given erm id */
      BEGIN
         SELECT erm_type
         INTO l_erm_type
         FROM erm
         WHERE erm_id = l_rec_id;

      EXCEPTION
         WHEN OTHERS THEN
            pl_text_log.ins_msg('INFO',ct_PROGRAM_CODE, SQLERRM, SQLCODE,'Error fetching erm_type. [ERM_ID]: ' || l_rec_id);
      END;

   /* restrict calling below procedures for EI po as EI package will handle this separately */
   IF g_ei_pallet = 'Y'
   THEN
      pl_text_log.ins_msg ('DEBUG',
                           ct_program_code,
                           'Calling EI Close',
                           SQLCODE,
                           SQLERRM
                          );
      pl_rcv_cross_dock.close_po (l_rec_id);
      pl_text_log.ins_msg ('DEBUG',
                           ct_program_code,
                           'Finished performing EI Close',
                           SQLCODE,
                           SQLERRM
                          );
   ELSIF l_erm_type = 'XN'
   THEN
      pl_text_log.ins_msg('INFO',ct_PROGRAM_CODE, SQLERRM, SQLCODE,'Starting pl_xdock_receiving.p_close_xsn. [ERM_ID]: ' || l_rec_id);

      /* Call pl_xdock_receiving.p_close_xsn to Close XSN (erm_type='XN') */
      pl_xdock_receiving.p_close_xsn(l_rec_id, l_message, l_code);
      IF (l_message <> 'SUCCESS') THEN
         g_err_msg := l_message;
         g_sqlcode := l_code;
         RAISE e_premature_termination;
      END IF;
      pl_text_log.ins_msg('INFO',ct_PROGRAM_CODE, SQLERRM, SQLCODE,'pl_xdock_receiving.p_close_xsn complete for [ERM_ID]: ' || l_rec_id);
   ELSE  
      check_msku_too_large(l_rec_id);
      lock_po(l_rec_id);
      verify_po_info(l_rec_id);
    	check_for_putaway_tasks;
    	check_for_data_collection(l_rec_id);
    	check_for_matching_quantities(l_rec_id);
    	get_confirmation_requirements;
    	get_case_split_pallet_counts(l_rec_id);
		/***BEG ADD ACPVXG 22 JAN 06 *****/
		P_Send_Er(l_rec_id);
		/***END ADD ACPVXG 22 JAN 06 *****/
    	update_erd(l_rec_id);
    	update_inv(l_rec_id);
    	close_po(l_rec_id);
    	IF c_po_lock%ISOPEN THEN
         CLOSE c_po_lock;
    	END IF;
	   END IF;
    	COMMIT;
      o_exit_msg := g_exit_msg;
   EXCEPTION
      WHEN OTHERS THEN
         IF c_po_lock%ISOPEN THEN
            CLOSE c_po_lock;
         END IF;
         ROLLBACK;
         o_exit_msg := g_err_msg;
         Pl_Text_Log.ins_msg('FATAL',ct_PROGRAM_CODE,g_err_msg,g_sqlcode,'Fatal error during CRT SN/PO close.');
         COMMIT;
   END mainproc;
   -----------------------------------------------------------------------------
   -- Procedure main - Close from RF
   -----------------------------------------------------------------------------
   PROCEDURE mainproc_rf(i_rec_id IN CHAR, i_flag IN CHAR, i_sp_flag IN CHAR, i_user_id IN CHAR,
      i_sp_supplier_name IN VARCHAR2, i_sp_supplier_qty IN VARCHAR2,
      o_sp_current_total OUT NUMBER, o_sp_supplier_count OUT NUMBER, o_erm_id OUT CHAR,
      o_prod_id OUT CHAR, o_cust_pref_vendor OUT CHAR, o_exp_splits OUT NUMBER,
      o_exp_qty OUT NUMBER, o_rec_splits OUT NUMBER, o_rec_qty OUT NUMBER,
      o_hld_cases OUT NUMBER, o_hld_splits OUT NUMBER, o_hld_pallet OUT NUMBER,
      o_total_pallet OUT NUMBER, o_num_pallet OUT NUMBER,
      o_status OUT NUMBER, ot_sp_suppliers IN OUT VARCHAR2) IS
      l_rec_id erm.erm_id%TYPE;
      l_erm_type      erm.erm_type%TYPE;
      l_message       VARCHAR2(200);
      l_code          NUMBER;
   BEGIN
      g_rf_flag := 'Y';
      g_server.status := NULL;
      l_rec_id := RTRIM(i_rec_id);
      g_client.flag := i_flag;
      g_client.sp_flag := i_sp_flag;
      g_client.user_id := i_user_id;
      g_client.sp_supplier_name := i_sp_supplier_name;
      g_client.sp_supplier_qty := i_sp_supplier_qty;
      Pl_Text_Log.ins_msg('DEBUG',ct_PROGRAM_CODE,'Close SN/PO rec_id=['||l_rec_id||'] flag=['||i_flag||'] sp_flag=['||i_sp_flag||
        '] user_id=['||i_user_id||'] sp_supplier_name=['||i_sp_supplier_name||'] sp_supplier_qty=['||i_sp_supplier_qty||']',
        SQLCODE,SQLERRM);
        -- avij3336 - EI - call f_is_ei_pallet function to determine EI po or not.

      g_ei_pallet := pl_rcv_cross_dock.f_is_crossdock_pallet(l_rec_id,'E');
      Pl_Text_Log.ins_msg('DEBUG',ct_PROGRAM_CODE,'IS EI PO OR NOT '||g_ei_pallet,SQLCODE,SQLERRM);

      /* Retrieve the erm type for the given erm id */
      BEGIN
         SELECT erm_type
         INTO l_erm_type
         FROM erm
         WHERE erm_id = l_rec_id;

      EXCEPTION
         WHEN OTHERS THEN
            pl_text_log.ins_msg('INFO',ct_PROGRAM_CODE, SQLERRM, SQLCODE,'Error fetching erm_type. [ERM_ID]: ' || l_rec_id);
      END;
      
      IF g_ei_pallet = 'Y'
      THEN
      pl_text_log.ins_msg ('DEBUG',
                           ct_program_code,
                           'Calling EI Close',
                           SQLCODE,
                           SQLERRM
                          );
      pl_rcv_cross_dock.close_po (l_rec_id);
      pl_text_log.ins_msg ('DEBUG',
                           ct_program_code,
                           'Finished performing EI Close',
                           SQLCODE,
                           SQLERRM
                          );
      ELSIF l_erm_type = 'XN'
      THEN
      /* Call pl_xdock_receiving.p_close_xsn_rf to Close XSN RF (erm_type='XN') */
         pl_text_log.ins_msg('INFO',ct_PROGRAM_CODE, SQLERRM, SQLCODE,'Starting pl_xdock_receiving.p_close_xsn_rf. [ERM_ID]: ' || l_rec_id);
         pl_xdock_receiving.p_close_xsn_rf(
            l_rec_id,
            g_client.flag,
            g_client.sp_flag,
            l_message,
            l_code,
            g_server.sp_current_total,
            g_server.sp_supplier_count,
            g_server.erm_id,
            g_server.prod_id,
            g_server.cust_pref_vendor,
            g_server.exp_splits,
            g_server.exp_qty,
            g_server.rec_splits,
            g_server.rec_qty,
            g_server.hld_cases,
            g_server.hld_splits,
            g_server.hld_pallet,
            g_server.total_pallet,
            g_server.num_pallet,
            g_server.status,
            ot_sp_suppliers
            );
         IF (l_message <> 'SUCCESS') THEN
            g_err_msg := l_message;
            g_sqlcode := l_code;
            RAISE e_premature_termination;
         END IF;
            pl_text_log.ins_msg('INFO',ct_PROGRAM_CODE, SQLERRM, SQLCODE,'pl_xdock_receiving.p_close_xsn_rf complete for [ERM_ID]: ' || l_rec_id);
      ELSE		
      check_msku_too_large(l_rec_id);
      lock_po(l_rec_id);
      verify_po_info(l_rec_id);
      
      /* 01/22/10 - 12554 - sgan0455 - Added for 212 Enh - SCE012 - Begin */
      /* Call verify_temp_track_ind to check if temperature is collected */
      verify_temp_track_ind(l_rec_id);  
      /* 01/22/10 - 12554 - sgan0455 - Added for 212 Enh - SCE012 - End */
      
      check_for_putaway_tasks;
      check_for_data_collection(l_rec_id);
      check_for_matching_quantities(l_rec_id);
      Pl_Text_Log.ins_msg('DEBUG',ct_PROGRAM_CODE,'mainproc_rf af chk_match_qty g_server.prod[' || g_server.prod_id || ']',
	SQLCODE,SQLERRM);                                                                                                           
      get_confirmation_requirements;
      get_case_split_pallet_counts(l_rec_id);
      handle_special_pallets(l_rec_id, ot_sp_suppliers);
      IF  NVL(g_client.flag,'Y') <> 'N' THEN
	  	 /*******************BEG ADD ACPVXG 22 JAN 06 *********************/
         p_send_er(l_rec_id);
		 /*******************BEG ADD ACPVXG 22 JAN 06 *********************/
         update_lm_batch_lite(l_rec_id);
         update_erd(l_rec_id);
         update_inv(l_rec_id);
         close_po(l_rec_id);
      END IF;
      IF c_po_lock%ISOPEN THEN
          CLOSE c_po_lock;
      END IF;
    END IF;
	  
      COMMIT;
      o_sp_current_total := g_server.sp_current_total;
      o_sp_supplier_count := g_server.sp_supplier_count;
      o_erm_id := g_server.erm_id;
      o_prod_id := g_server.prod_id;
      o_cust_pref_vendor := g_server.cust_pref_vendor;
      o_exp_splits := g_server.exp_splits;
      o_exp_qty := g_server.exp_qty;
      o_rec_splits := g_server.rec_splits;
      o_rec_qty := g_server.rec_qty;
      o_hld_cases := g_server.hld_cases;
      o_hld_splits := g_server.hld_splits;
      o_hld_pallet := g_server.hld_pallet;
      o_total_pallet := g_server.total_pallet;
      o_num_pallet := g_server.num_pallet;
      o_status := g_server.status;
   EXCEPTION
      WHEN OTHERS THEN
         o_sp_current_total := g_server.sp_current_total;
         o_sp_supplier_count := g_server.sp_supplier_count;
         o_erm_id := g_server.erm_id;
         o_prod_id := g_server.prod_id;
         o_cust_pref_vendor := g_server.cust_pref_vendor;
         o_exp_splits := g_server.exp_splits;
         o_exp_qty := g_server.exp_qty;
         o_rec_splits := g_server.rec_splits;
         o_rec_qty := g_server.rec_qty;
         o_hld_cases := g_server.hld_cases;
         o_hld_splits := g_server.hld_splits;
         o_hld_pallet := g_server.hld_pallet;
         o_total_pallet := g_server.total_pallet;
         o_num_pallet := g_server.num_pallet;
         o_status := g_server.status;
         IF c_po_lock%ISOPEN THEN
            CLOSE c_po_lock;
         END IF;
         ROLLBACK;
         Pl_Text_Log.ins_msg('FATAL',ct_PROGRAM_CODE,g_err_msg,g_sqlcode,'Fatal error during RF SN/PO close.');
         COMMIT;
   END mainproc_rf;
   -----------------------------------------------------------------------------
   -- Procedure lock_po
   --   Lock all of the Master PO records (main and extended) for this PO until
   --   we are done processing the close request.
   -----------------------------------------------------------------------------
   PROCEDURE lock_po(i_rec_id IN VARCHAR2) IS
   BEGIN
        IF NOT c_po_lock%ISOPEN THEN
         OPEN c_po_lock (i_rec_id);
      END IF;
      BEGIN
            SELECT CONFIG_FLAG_VAL
            INTO gv_osd_sys_flag
            FROM SYS_CONFIG
            WHERE CONFIG_FLAG_NAME = 'OSD_REASON_CODE';
       EXCEPTION
            WHEN OTHERS THEN
                     g_sqlcode := SQLCODE;
                     g_err_msg := 'ORACLE Unable to get OSD reason code syspar from sys_config.';
                     Pl_Text_Log.ins_msg('WARN',ct_PROGRAM_CODE,g_err_msg,SQLCODE,SQLERRM);
                     g_server.status := ct_SELECT_ERROR;
                     RAISE e_premature_termination;
       END;

   EXCEPTION
      WHEN e_po_locked THEN
         g_sqlcode := -54;
         g_err_msg := 'ORACLE SN/PO ' || i_rec_id || ' locked by another user.';
         Pl_Text_Log.ins_msg('WARN',ct_PROGRAM_CODE,g_err_msg,-54,SQLERRM);
         g_server.status := ct_LOCKED_PO;
         RAISE e_premature_termination;
      WHEN OTHERS THEN
         g_sqlcode := SQLCODE;
         g_err_msg := 'ORACLE Unable to lock SN/PO ' || i_rec_id || '.';
         Pl_Text_Log.ins_msg('WARN',ct_PROGRAM_CODE,g_err_msg,SQLCODE,SQLERRM);
         g_server.status := ct_INV_PO;
         RAISE e_premature_termination;
   END lock_po;
   -----------------------------------------------------------------------------
   -- Procedure verify_po_info
   --   Get information from the Master PO for this PO.
   --   PO must be the right type and have the right status to continue.
   -----------------------------------------------------------------------------
   PROCEDURE verify_po_info(i_rec_id IN VARCHAR2) IS
      not_open_cnt NUMBER;
   BEGIN
      SELECT status, po, erm_type, door_no, NVL(warehouse_id,'000'), NVL(to_warehouse_id,'000')
        INTO g_erm_rec.status, g_erm_rec.po, g_erm_rec.erm_type, g_erm_rec.door_no,
             g_erm_rec.warehouse_id, g_erm_rec.to_warehouse_id
        FROM erm
       WHERE erm_id = i_rec_id;
      IF g_erm_rec.status = 'CLO' OR g_erm_rec.status = 'VCH' THEN
         g_err_msg := 'Cannot close SN/PO ' || i_rec_id || '.' ||
                      '  SN/PO is already closed.';
         Pl_Text_Log.ins_msg('WARN',ct_PROGRAM_CODE,g_err_msg,SQLCODE,SQLERRM);
         g_server.status := ct_CLO_PO;
         RAISE e_premature_termination;
      ELSIF g_erm_rec.status = 'NEW' OR g_erm_rec.status = 'SCH' THEN
         g_err_msg := 'Cannot close SN/PO ' || i_rec_id ||'.' ||
                      '  SN/PO has status of SCH or NEW.';
         Pl_Text_Log.ins_msg('WARN',ct_PROGRAM_CODE,g_err_msg,SQLCODE,SQLERRM);
         g_server.status := ct_INV_OPT;
         RAISE e_premature_termination;
      ELSIF g_erm_rec.erm_type = 'CM' THEN
         g_err_msg := 'Cannot close SN/PO ' || i_rec_id || '.' ||
                      '  CM (Credit Memo) cannot be closed.';
         Pl_Text_Log.ins_msg('WARN',ct_PROGRAM_CODE,g_err_msg,SQLCODE,SQLERRM);
         g_server.status := ct_BLD_REC;
         RAISE e_premature_termination;
      ELSIF i_rec_id <> g_erm_rec.po THEN
         g_err_msg := 'Cannot close SN/PO ' || i_rec_id ||'.' ||
                      '  SN/PO is an extended SN/PO.';
         Pl_Text_Log.ins_msg('WARN',ct_PROGRAM_CODE,g_err_msg,SQLCODE,SQLERRM);
         g_server.status := ct_EXTEND_PO;
         RAISE e_premature_termination;
      ELSE
      	 SELECT COUNT(*)
      	   INTO not_open_cnt
      	   FROM erm
      	  WHERE po = g_erm_rec.po
      	    AND status IN ('NEW','SCH');
      	 IF not_open_cnt > 0 THEN
            g_err_msg := 'Cannot close SN/PO ' || i_rec_id ||'.' ||
                         '  SN/PO has an extended PO with status of SCH or NEW.';
            Pl_Text_Log.ins_msg('WARN',ct_PROGRAM_CODE,g_err_msg,SQLCODE,SQLERRM);
            g_server.status := ct_INV_OPT;
            RAISE e_premature_termination;
      	 END IF;
      END IF;
      Pl_Text_Log.ins_msg('DEBUG',ct_PROGRAM_CODE,'SN/PO validated.',SQLCODE,SQLERRM);
   EXCEPTION
      WHEN OTHERS THEN
         g_sqlcode := SQLCODE;
         g_err_msg := 'ORACLE Cannot get status of SN/PO ' || i_rec_id || '.';
         Pl_Text_Log.ins_msg('WARN',ct_PROGRAM_CODE,'ORACLE Cannot get status' ||
                        ' of SN/PO ' || i_rec_id || '.' ||
                        TO_CHAR(SQLCODE),SQLCODE,SQLERRM);
         g_server.status := ct_INV_PO;
         RAISE e_premature_termination;
   END verify_po_info;
   -----------------------------------------------------------------------------
   -- Procedure check_for_putaway_tasks
   --   PO must have at least one putaway task to continue.
   -----------------------------------------------------------------------------
   PROCEDURE check_for_putaway_tasks IS
   BEGIN
      SELECT COUNT(*)
        INTO g_row_count
        FROM putawaylst
       WHERE rec_id LIKE g_erm_rec.po || '%';
      IF g_row_count = 0 THEN
         g_err_msg := 'ORACLE Cannot find any putaway records on SN/PO ' ||
                      g_erm_rec.po || '%(wildcard).';
         g_server.status := ct_INV_PO;
         RAISE e_premature_termination;
      END IF;
   EXCEPTION
      WHEN OTHERS THEN
         g_sqlcode := SQLCODE;
         g_err_msg := 'ORACLE Cannot find any putaway records on SN/PO ' ||
                      g_erm_rec.po || '%(wildcard).';
         Pl_Text_Log.ins_msg('WARN',ct_PROGRAM_CODE,g_err_msg,SQLCODE,SQLERRM);
         RAISE e_premature_termination;
   END check_for_putaway_tasks;
   -----------------------------------------------------------------------------
   -- Procedure check_for_data_collection
   --   Data must have been collected for all Expected Receipts masters making
   --   up PO to continue.
   -----------------------------------------------------------------------------
   PROCEDURE check_for_data_collection(i_rec_id IN VARCHAR2) IS
      l_po_found_bln BOOLEAN := FALSE;
      CURSOR c_po (cp_rec_id VARCHAR2) IS
      SELECT erm_id
        FROM erm
       WHERE po = cp_rec_id;
   BEGIN
      FOR r_po IN c_po (i_rec_id) LOOP
         l_po_found_bln := TRUE;
         BEGIN
            SELECT COUNT(*)
              INTO g_row_count
              FROM putawaylst
             WHERE rec_id = r_po.erm_id
               AND ((lot_trk = 'Y' AND qty_received <> 0)
                OR (exp_date_trk = 'Y' AND qty_received <> 0)
                OR (clam_bed_trk = 'Y' AND qty_received <> 0)
                OR (date_code = 'Y' AND qty_received <> 0)
                OR (temp_trk = 'Y' AND qty_received <> 0)
                OR (cool_trk = 'Y' AND qty_received <> 0)
                OR (tti_trk = 'Y' AND qty_received <> 0));
            IF g_row_count > 0 THEN
               g_err_msg := 'Data not collected for SN/PO or extended SN/PO ' ||
                            r_po.erm_id || '.';
               Pl_Text_Log.ins_msg('WARN',ct_PROGRAM_CODE,g_err_msg,SQLCODE,SQLERRM);
               g_server.status := ct_MORE_REC_DATA;
               RAISE e_premature_termination;
            END IF;
         EXCEPTION
 	    WHEN e_premature_termination THEN
               RAISE;
            WHEN OTHERS THEN
               g_sqlcode := SQLCODE;
               g_err_msg := 'Error checking for data collection on SN/PO ' ||
                            r_po.erm_id || '.';
               Pl_Text_Log.ins_msg('WARN',ct_PROGRAM_CODE,g_err_msg,SQLCODE,SQLERRM);
               RAISE e_premature_termination;
         END;
      END LOOP;
   EXCEPTION
        WHEN e_premature_termination THEN
           RAISE;
      WHEN OTHERS THEN
         g_sqlcode := SQLCODE;
         IF l_po_found_bln THEN
            g_err_msg :=  'ORACLE Failed to get next SN/PO for data collection checking.  i_rec_id='|| i_rec_id || '.';
            Pl_Text_Log.ins_msg('WARN',ct_PROGRAM_CODE,g_err_msg,SQLCODE,SQLERRM);
         ELSE
            g_err_msg := 'ORACLE Did not find any SN/POs for data collection checking.  i_rec_id='|| i_rec_id || '.';
            Pl_Text_Log.ins_msg('WARN',ct_PROGRAM_CODE,g_err_msg,SQLCODE,SQLERRM);
         END IF;
   END check_for_data_collection;
   -----------------------------------------------------------------------------
   -- Procedure check_for_matching_quantities
   -----------------------------------------------------------------------------
   PROCEDURE check_for_matching_quantities(i_rec_id IN VARCHAR2) IS
      l_task_found_bln BOOLEAN;
      l_qty_received NUMBER;
      l_total_qty NUMBER;
      l_total_weight NUMBER;
	  
      CURSOR c_po (cp_rec_id VARCHAR2) IS
      SELECT erm_id
        FROM erm
       WHERE po = cp_rec_id;
      CURSOR c_putawaylst (cp_po VARCHAR2) IS
      SELECT DISTINCT prod_id, cust_pref_vendor
        FROM putawaylst
       WHERE rec_id = cp_po;
   BEGIN
      FOR r_po IN c_po (i_rec_id) LOOP
         l_task_found_bln := FALSE;
         FOR r_putawaylst IN c_putawaylst (r_po.erm_id) LOOP
            l_task_found_bln := TRUE;
	    Pl_Text_Log.ins_msg('DEBUG',ct_PROGRAM_CODE,'check_for_matching_quantities po[' || i_rec_id ||
		'] r_putawaylst.prod[' || r_putawaylst.prod_id || '] g_server.prod [' || g_server.prod_id || ']',
		SQLCODE,SQLERRM);
            BEGIN
               SELECT prod_id, cust_pref_vendor, catch_wt_trk, spc
                 INTO g_pm_rec.prod_id, g_pm_rec.cust_pref_vendor, g_pm_rec.catch_wt_trk, g_pm_rec.spc
                 FROM pm
                WHERE prod_id = r_putawaylst.prod_id
                  AND cust_pref_vendor = r_putawaylst.cust_pref_vendor;
		g_server.prod_id := g_pm_rec.prod_id;
		g_server.cust_pref_vendor := g_pm_rec.cust_pref_vendor;
		pl_Text_Log.ins_msg('DEBUG',ct_PROGRAM_CODE,
			'check_for_matching_quantities 1 po[' || i_rec_id || '] g_pm_rec.prod[' ||
			g_pm_rec.prod_id || '] g_server.prod[' || g_server.prod_id ||'] wt_trk[' || g_pm_rec.catch_wt_trk || ']',
			SQLCODE,SQLERRM);
            EXCEPTION
               WHEN OTHERS THEN
                  g_sqlcode := SQLCODE;
                  g_err_msg := 'ORACLE Cannot get catchweight for item.';
                  Pl_Text_Log.ins_msg('WARN',ct_PROGRAM_CODE,g_err_msg,SQLCODE,SQLERRM);
                  g_server.status := ct_INV_PRODID;
                  RAISE e_premature_termination;
            END;
            IF g_pm_rec.catch_wt_trk = 'Y' AND
               g_erm_rec.warehouse_id = '000' AND
               g_erm_rec.to_warehouse_id = '000' THEN
               BEGIN
                  SELECT SUM(NVL(qty_received,0))
                    INTO l_qty_received
                    FROM putawaylst
                   WHERE prod_id = r_putawaylst.prod_id
                     AND cust_pref_vendor = r_putawaylst.cust_pref_vendor
                     AND rec_id = r_po.erm_id;
               EXCEPTION
                  WHEN OTHERS THEN
                     g_sqlcode := SQLCODE;
                     g_err_msg := 'ORACLE Unable to sum qty_received for item on SN/PO.';
                     Pl_Text_Log.ins_msg('WARN',ct_PROGRAM_CODE,g_err_msg,SQLCODE,SQLERRM);
                     g_server.status := ct_INV_PO;
                     RAISE e_premature_termination;
               END;
               BEGIN
               -- avij3336 - European Imports - added the below if else block to calculate average weight for EI pallet
                    IF g_ei_pallet ='Y' THEN
                        SELECT SUM(qty)
                          INTO l_total_qty
                        FROM cross_dock_data_collect cd
                        WHERE cd.rec_type ='D'
                        AND cd.prod_id=r_putawaylst.prod_id
                        and erm_id = r_po.erm_id;
                        
                        SELECT SUM(catch_wt)
                           INTO l_total_weight
                        FROM cross_dock_data_collect cd
                          WHERE cd.rec_type ='C'
                        AND cd.prod_id=r_putawaylst.prod_id
                        and erm_id = r_po.erm_id;

                    g_pm_rec.avg_wt := l_total_weight/l_total_qty;
                    
                      g_err_msg := 'g_ei_pallet['||g_ei_pallet||'] l_total_qty [' ||l_total_qty 
                      || '] l_total_weight [';
                    Pl_Text_Log.ins_msg('WARN',ct_PROGRAM_CODE,g_err_msg,SQLCODE,SQLERRM);

                    ELSE
					
                  SELECT NVL(total_cases,0), NVL(total_splits,0),
                         NVL(total_weight,0)
                    INTO g_tmp_weight_rec.total_cases, g_tmp_weight_rec.total_splits,
                         g_tmp_weight_rec.total_weight
                    FROM tmp_weight
                   WHERE prod_id = r_putawaylst.prod_id
                     AND cust_pref_vendor = r_putawaylst.cust_pref_vendor
                     AND erm_id = r_po.erm_id;
                  l_total_qty := g_tmp_weight_rec.total_cases + g_tmp_weight_rec.total_splits;
                    --/* avij3336 - EI - calculating average weight here instead of doing it before UPDATE pm statement */
                    g_pm_rec.avg_wt := g_tmp_weight_rec.total_weight / l_total_qty;
                    END IF;			  
               EXCEPTION
                  WHEN OTHERS THEN
                     l_total_qty := -1;
                     g_err_msg := 'ORACLE Total qty not found in tmp_weight; setting to -1.';
                     Pl_Text_Log.ins_msg('WARN',ct_PROGRAM_CODE,g_err_msg,SQLCODE,SQLERRM);
               END;
		pl_Text_Log.ins_msg('DEBUG',ct_PROGRAM_CODE,
			'check_for_matching_quantities 2 po[' || i_rec_id || '] tot_cs[' ||
			to_char(g_tmp_weight_rec.total_cases) ||'] tot_wt[' || to_char(g_tmp_weight_rec.total_weight) ||
			'] qty_rec[' || to_char(l_qty_received) || '] tot_qty[' || to_char(l_total_qty) ||
			'] r_put.prod[' || r_putawaylst.prod_id || '] g_server.prod[' || g_server.prod_id ||
			'] rf_flag[' || g_rf_flag || ']',
			SQLCODE,SQLERRM);
               IF l_qty_received <> 0 THEN
                  IF l_total_qty <> l_qty_received THEN
                     IF g_rf_flag = 'Y' THEN
                        request_catch_weight(r_po.erm_id);
                     END IF;
                      g_err_msg := 'Catch weight not collected for item ' || r_putawaylst.prod_id;
                     Pl_Text_Log.ins_msg('WARN',ct_PROGRAM_CODE,g_err_msg,SQLCODE,SQLERRM);
                     RAISE e_premature_termination;
                  ELSE
                     BEGIN
                        g_pm_rec.avg_wt := g_tmp_weight_rec.total_weight / l_total_qty;
                        -- avij3336 - European Imports - commenting avg wt calculation as it is done already
                        --g_pm_rec.avg_wt := g_tmp_weight_rec.total_weight / l_total_qty;						
                        UPDATE pm
                           SET avg_wt = g_pm_rec.avg_wt
                         WHERE prod_id = r_putawaylst.prod_id
                           AND cust_pref_vendor = r_putawaylst.cust_pref_vendor;
                     EXCEPTION                                                                         
                        WHEN OTHERS THEN                                                               
                           g_sqlcode := SQLCODE;                                                       
                           g_err_msg := 'ORACLE Unable to update average weight for item.';            
                           g_server.status := ct_PM_UPDATE_FAIL;                                       
                           Pl_Text_Log.ins_msg('WARN',ct_PROGRAM_CODE,g_err_msg,SQLCODE,SQLERRM);      
                           RAISE e_premature_termination;                                              
                     END;
                  END IF;
                  IF g_rf_flag = 'Y' AND g_ei_pallet <> 'Y'THEN
                     check_catch_weight(i_rec_id);
                  END IF;
               END IF;
            END IF;
         END LOOP;
      END LOOP;
   END check_for_matching_quantities;
   -----------------------------------------------------------------------------
   -- Procedure request_catch_weight
   -----------------------------------------------------------------------------
   PROCEDURE request_catch_weight(i_rec_id IN VARCHAR2) IS
      l_qty_cases NUMBER;
      l_qty_splits NUMBER;
      l_object_name     VARCHAR2 (30 CHAR)              := 'request_catch_weight';
      l_message       VARCHAR2 (256);	  
   BEGIN
      SELECT NVL(SUM(DECODE(uom,0,qty_received,0)),0),
             NVL(SUM(DECODE(uom,1,qty_received,0)),0)
        INTO l_qty_cases, l_qty_splits
        FROM putawaylst
       WHERE prod_id = g_pm_rec.prod_id
         AND cust_pref_vendor = g_pm_rec.cust_pref_vendor
         AND rec_id = i_rec_id;
      g_server.erm_id := i_rec_id;
      g_server.prod_id := g_pm_rec.prod_id;
      g_server.cust_pref_vendor := g_pm_rec.cust_pref_vendor;
	Pl_Text_Log.ins_msg('DEBUG',ct_PROGRAM_CODE,
		'request_catch_weight 2 po[' || i_rec_id || '] g_pm_rec.prod[' || g_pm_rec.prod_id ||
		'] g_server.prod[' || g_server.prod_id || ']',
		SQLCODE,SQLERRM);                                                                             
      g_server.rec_splits := l_qty_splits;
      g_server.rec_qty := l_qty_cases / g_pm_rec.spc;
      g_server.exp_splits := 0;
      g_server.exp_qty := 0;
      g_server.hld_cases := 0;
      g_server.hld_splits := 0;
      g_server.hld_pallet := 0;
      g_server.total_pallet := 0;
      g_server.num_pallet := 0;
      g_server.status := ct_QTY_NOT_MATCH;
      g_sqlcode := SQLCODE;
      g_err_msg := 'Quantity mismatch during catch weight request on SN/PO' ||
                   '[' || i_rec_id || ']';
      Pl_Text_Log.ins_msg('WARN',ct_PROGRAM_CODE,g_err_msg,SQLCODE,SQLERRM);
      RAISE e_premature_termination;
   END request_catch_weight;
   -----------------------------------------------------------------------------
   -- Procedure check_catch_weight
   -----------------------------------------------------------------------------
   PROCEDURE check_catch_weight(i_rec_id IN VARCHAR2) IS
      CURSOR c_po (cp_rec_id VARCHAR2) IS
      SELECT erm_id
        FROM erm
       WHERE po = cp_rec_id;
   BEGIN
      FOR r_po IN c_po (i_rec_id) LOOP
         BEGIN
            SELECT COUNT(*)
              INTO g_row_count
              FROM putawaylst
             WHERE qty_received <> 0
               AND catch_wt = 'Y'
               AND cust_pref_vendor = g_pm_rec.cust_pref_vendor
               AND prod_id = g_pm_rec.prod_id
               AND rec_id = r_po.erm_id;
         EXCEPTION
            WHEN OTHERS THEN
               g_row_count := 0;
         END;
         IF g_row_count > 0 THEN
            g_sqlcode := SQLCODE;
            g_err_msg := 'ORACLE Catchweight not collected for item on SN/PO' ||
                         '[' || r_po.erm_id || '].';
            Pl_Text_Log.ins_msg('WARN',ct_PROGRAM_CODE,g_err_msg,SQLCODE,SQLERRM);
            request_catch_weight(r_po.erm_id);
            RAISE e_premature_termination;
         END IF;
      END LOOP;
   END check_catch_weight;
   -----------------------------------------------------------------------------
   -- Procedure get_confirmation_requirements
   -----------------------------------------------------------------------------
   PROCEDURE get_confirmation_requirements IS
   BEGIN
      g_rf_confirm_flag := Pl_Common.f_get_syspar('GLOBAL_RF_CONF','N');
      Pl_Text_Log.ins_msg('DEBUG',ct_PROGRAM_CODE,'RF Confimation flag=[' || g_rf_confirm_flag || ']',
         SQLCODE,SQLERRM);
      g_putaway_confirm_flag := Pl_Common.f_get_syspar('PUTAWAY_RF_CONF','N');
      Pl_Text_Log.ins_msg('DEBUG',ct_PROGRAM_CODE,'RF Putaway Confimation flag=[' ||
         g_putaway_confirm_flag || ']',SQLCODE,SQLERRM);
   END get_confirmation_requirements;
   -----------------------------------------------------------------------------
   -- Procedure get_case_split_pallet_counts
   -----------------------------------------------------------------------------
   PROCEDURE get_case_split_pallet_counts(i_rec_id IN VARCHAR2) IS
      l_total_qty_expected NUMBER;
      l_total_qty_received NUMBER;
   BEGIN
      SELECT NVL(SUM(l.qty_expected),0),
             NVL(SUM(DECODE(l.uom,0,l.qty_expected/NVL(p.spc,1),0)),0),
             NVL(SUM(DECODE(l.uom,1,l.qty_expected,0)),0),
             COUNT(DISTINCT NVL(l.parent_pallet_id,l.pallet_id)),
             NVL(SUM(l.qty_received),0),
             NVL(SUM(DECODE(l.uom,0,l.qty_received/NVL(p.spc,1),0)),0),
             NVL(SUM(DECODE(l.uom,1,l.qty_received,0)),0),
             COUNT(DISTINCT DECODE(l.qty_received,0,NULL,NVL(l.parent_pallet_id,l.pallet_id)))
        INTO l_total_qty_expected,
             g_server.exp_qty,
             g_server.exp_splits,
             g_server.num_pallet,
             l_total_qty_received,
             g_server.rec_qty,
             g_server.rec_splits,
             g_server.total_pallet
        FROM pm p, putawaylst l, erm e
       WHERE p.prod_id = l.prod_id
         AND p.cust_pref_vendor = l.cust_pref_vendor
         AND l.rec_id = e.erm_id
         AND e.po = i_rec_id;
      Pl_Text_Log.ins_msg('DEBUG',ct_PROGRAM_CODE,'qty_expected=[' || TO_CHAR(l_total_qty_expected) ||
         '], qty_received=[' || TO_CHAR(l_total_qty_received) || ']',SQLCODE,SQLERRM);
      Pl_Text_Log.ins_msg('DEBUG',ct_PROGRAM_CODE,'cases_expected=[' || TO_CHAR(g_server.exp_qty) ||
         '], cases_received=[' || TO_CHAR(g_server.rec_qty) || ']',SQLCODE,SQLERRM);
      Pl_Text_Log.ins_msg('DEBUG',ct_PROGRAM_CODE,'splits_expected=[' ||
         TO_CHAR(g_server.exp_splits) || '], splits_received=[' ||
         TO_CHAR(g_server.rec_splits) || ']',SQLCODE,SQLERRM);
      Pl_Text_Log.ins_msg('DEBUG',ct_PROGRAM_CODE,'pallets_expected=[' ||
         TO_CHAR(g_server.num_pallet) || '], pallets_received=[' ||
         TO_CHAR(g_server.total_pallet) || ']',SQLCODE,SQLERRM);
      SELECT NVL(SUM(DECODE(l.uom,0,l.qty_received/NVL(p.spc,1),0)),0),
             NVL(SUM(DECODE(l.uom,1,l.qty_received,0)),0),
             COUNT(*)
        INTO g_server.hld_cases,
             g_server.hld_splits,
             g_server.hld_pallet
        FROM pm p, putawaylst l, erm e
       WHERE p.prod_id = l.prod_id
         AND p.cust_pref_vendor = l.cust_pref_vendor
         AND l.rec_id = e.erm_id
         AND l.inv_status = 'HLD'
         AND e.po = i_rec_id;
      g_server.erm_id := i_rec_id;
/*      g_server.prod_id := NULL;
      g_server.cust_pref_vendor := NULL; */
      Pl_Text_Log.ins_msg('DEBUG',ct_PROGRAM_CODE,'cases_on_hold=[' || TO_CHAR(g_server.hld_cases) ||
         '], splits_on_hold=[' || TO_CHAR(g_server.hld_splits) || '], pallets_on_hold=[' ||
         TO_CHAR(g_server.hld_pallet),SQLCODE,SQLERRM);
   EXCEPTION
      WHEN OTHERS THEN
         g_err_msg := 'ORACLE Unable to get counts. ' || TO_CHAR(SQLCODE);
         g_sqlcode := SQLCODE;
         Pl_Text_Log.ins_msg('WARN',ct_PROGRAM_CODE,g_err_msg,SQLCODE,SQLERRM);
   END get_case_split_pallet_counts;
   -----------------------------------------------------------------------------
   -- Procedure handle_special_pallets
   -----------------------------------------------------------------------------
   PROCEDURE handle_special_pallets(i_rec_id IN VARCHAR2, ot_sp_suppliers IN OUT VARCHAR2) IS
      l_sp_supplier VARCHAR2(1000);
      CURSOR c_pallet_supplier IS
      SELECT ps.supplier
        FROM pallet_supplier ps
       WHERE NOT EXISTS (SELECT 1
                           FROM sp_pallet sp
                          WHERE sp.erm_id = i_rec_id
                            AND sp.supplier = ps.supplier)
       ORDER BY 1;
   BEGIN
      IF g_client.sp_flag <> 'Y' THEN
         g_server.sp_current_total := 0;
         g_server.sp_supplier_count := 0;
      ELSE
         SELECT NVL(SUM(pallet_qty),0)
           INTO g_server.sp_current_total
           FROM sp_pallet
          WHERE erm_id = i_rec_id;
          g_server.sp_supplier_count := 0;
          ot_sp_suppliers := NULL;
          FOR r_pallet_supplier IN c_pallet_supplier LOOP
             g_server.sp_supplier_count := g_server.sp_supplier_count + 1;
             IF ot_sp_suppliers IS NULL THEN
                ot_sp_suppliers := r_pallet_supplier.supplier;
             ELSE
                ot_sp_suppliers := ot_sp_suppliers || '~' || r_pallet_supplier.supplier;
             END IF;
          END LOOP;
      END IF;
      g_server.erm_id := i_rec_id;
/*      g_server.prod_id := NULL;
      g_server.cust_pref_vendor := NULL;*/
   END handle_special_pallets;
   -----------------------------------------------------------------------------
   -- Procedure update_lm_batch_lite
   -----------------------------------------------------------------------------
   PROCEDURE update_lm_batch_lite(i_rec_id IN VARCHAR2) IS
      l_lbr_mgmt_flag sys_config.config_flag_val%TYPE;
      l_create_rc_batch_flag lbr_func.create_batch_flag%TYPE;
      l_batch_rec batch%ROWTYPE;
      CURSOR c_po IS
      SELECT erm_id
        FROM erm
       WHERE po = i_rec_id;
   BEGIN
      l_lbr_mgmt_flag := Pl_Common.f_get_syspar('LBR_MGMT_FLAG','N');
      Pl_Text_Log.ins_msg('DEBUG',ct_PROGRAM_CODE,'Labor Management flag=[' || l_lbr_mgmt_flag || ']',
         SQLCODE,SQLERRM);
      IF l_lbr_mgmt_flag = 'Y' THEN
         SELECT create_batch_flag
           INTO l_create_rc_batch_flag
           FROM lbr_func
          WHERE lfun_lbr_func = 'RC';
         IF l_create_rc_batch_flag = 'Y' THEN
            SAVEPOINT update_lm_batch;
            FOR r_po IN c_po LOOP
               l_batch_rec.batch_no := 'SN/PO' || r_po.erm_id;
               UPDATE batch
                  SET actl_stop_time = SYSDATE
                WHERE batch_no = l_batch_rec.batch_no
                  AND status = 'M'
                  AND SUBSTR(jbcd_job_code,4,3) = 'LOT';
               Pl_Text_Log.ins_msg('WARN',ct_PROGRAM_CODE,TO_CHAR(SQL%ROWCOUNT)||
                 ' LM batch record(s) updated for batch '||l_batch_rec.batch_no||'.',SQLCODE,SQLERRM);
            END LOOP;
         END IF;
      END IF;
   EXCEPTION
      WHEN OTHERS THEN
         g_sqlcode := SQLCODE;
         ROLLBACK TO SAVEPOINT update_lm_batch;
         g_err_msg := 'ORACLE Unable to update receiving batch.';
         Pl_Text_Log.ins_msg('WARN',ct_PROGRAM_CODE,g_err_msg,g_sqlcode,
           'Non-fatal error updating batch while closing SN/PO.');
   END update_lm_batch_lite;
   -----------------------------------------------------------------------------
   -- Procedure update_lm_batch
   -----------------------------------------------------------------------------
   PROCEDURE update_lm_batch(i_rec_id IN VARCHAR2) IS
      l_lbr_mgmt_flag sys_config.config_flag_val%TYPE;
      l_create_rc_batch_flag lbr_func.create_batch_flag%TYPE;
      l_batch_rec batch%ROWTYPE;
      l_job_code_rec job_code%ROWTYPE;
      num_splits NUMBER;
      num_cases NUMBER;
      num_pallets NUMBER;
      num_items NUMBER;
      num_pieces NUMBER;
      num_data_captures NUMBER;
      num_dc_lot_trk NUMBER;
      num_dc_exp_date NUMBER;
      num_dc_mfr_date NUMBER;
      num_dc_catch_wt NUMBER;
      num_dc_temp NUMBER;
      num_dc_tti NUMBER;
      std NUMBER;
      CURSOR c_po (cp_rec_id VARCHAR2) IS
      SELECT erm_id
        FROM erm
       WHERE po = cp_rec_id;
   BEGIN
      l_batch_rec.batch_no := 'SN/PO' || i_rec_id;
      l_lbr_mgmt_flag := Pl_Common.f_get_syspar('LBR_MGMT_FLAG','N');
      Pl_Text_Log.ins_msg('DEBUG',ct_PROGRAM_CODE,'Labor Management flag=[' || l_lbr_mgmt_flag || ']',
         SQLCODE,SQLERRM);
      IF l_lbr_mgmt_flag = 'Y' THEN
         BEGIN
            SELECT create_batch_flag
              INTO l_create_rc_batch_flag
              FROM lbr_func
             WHERE lfun_lbr_func = 'RC';
            IF l_create_rc_batch_flag = 'Y' THEN
               BEGIN
                  SAVEPOINT update_lm_batch;
                  SELECT COUNT(*)
                    INTO g_row_count
                    FROM erm
                   WHERE po = i_rec_id
                     AND erm_id = i_rec_id;
                  IF g_row_count > 0 THEN
                     FOR r_po IN c_po (i_rec_id) LOOP
                        l_batch_rec.kvi_no_piece := 0;
                        l_batch_rec.kvi_no_case := 0;
                        l_batch_rec.kvi_no_item := 0;
                        l_batch_rec.kvi_no_pallet := 0;
                        l_batch_rec.kvi_no_data_capture := 0;
                        BEGIN
                           SELECT SUM(DECODE(y.uom,1,y.qty_received,0)),
                                  SUM(DECODE(y.uom,0,y.qty_received/p.spc,0)),
                                  COUNT(DISTINCT y.pallet_id),
                                  COUNT(DISTINCT y.prod_id || y.cust_pref_vendor),
                                  SUM(DECODE(p.lot_trk,'Y',1,0)),
                                  SUM(DECODE(p.exp_date_trk,'Y',1,0)),
                                  SUM(DECODE(p.mfg_date_trk,'Y',1,0)),
                                  COUNT(DISTINCT DECODE(p.catch_wt_trk,'Y',y.prod_id ||
                                  y.cust_pref_vendor,0)) -
                                  LEAST(1,SUM(DECODE(p.catch_wt_trk,'Y',0,1))),
                                  COUNT(DISTINCT DECODE(p.temp_trk,'Y',y.prod_id ||
                                  y.cust_pref_vendor)) - LEAST(1,SUM(DECODE(p.temp_trk,'Y',0,1))),
				  COUNT(DISTINCT DECODE(y.tti_trk,'Y',y.prod_id || y.cust_pref_vendor,
                                                                  'C',y.prod_id || y.cust_pref_vendor)) -
                                        LEAST(1,SUM(DECODE(y.tti_trk,'Y',0,'C',0,1)))
                             INTO num_splits, num_cases, num_pallets, num_items, num_dc_lot_trk,
                                  num_dc_exp_date, num_dc_mfr_date, num_dc_catch_wt, num_dc_temp,
                                  num_dc_tti
                             FROM pm p, putawaylst y
                            WHERE p.prod_id = y.prod_id
                              AND p.cust_pref_vendor = y.cust_pref_vendor
                              AND y.rec_id = r_po.erm_id
                              AND y.dest_loc NOT IN ('*', '**', 'LR');  -- 03/13/2017 Brian Bent-Live Receiving-Added 'LR'

                           num_pieces := num_cases + num_splits;
                           num_data_captures := num_dc_lot_trk + num_dc_exp_date +
                              num_dc_mfr_date + num_dc_catch_wt + num_dc_temp + num_dc_tti;
                           l_batch_rec.kvi_no_piece := l_batch_rec.kvi_no_piece + num_pieces;
                           l_batch_rec.kvi_no_case := l_batch_rec.kvi_no_case + num_cases;
                           l_batch_rec.kvi_no_item := l_batch_rec.kvi_no_item + num_items;
                           l_batch_rec.kvi_no_pallet := l_batch_rec.kvi_no_pallet + num_pallets;
                           l_batch_rec.kvi_no_data_capture := l_batch_rec.kvi_no_data_capture +
                              num_data_captures;
                        EXCEPTION
                           WHEN OTHERS THEN
                              g_err_msg := 'ORACLE Unable to get the actual KVIs for receiving lm batch.';
                              Pl_Text_Log.ins_msg('WARN',ct_PROGRAM_CODE,g_err_msg,SQLCODE,SQLERRM);
                        END;
                     END LOOP;
                     BEGIN
                        UPDATE batch
                           SET kvi_no_piece = l_batch_rec.kvi_no_piece,
                               kvi_no_case = l_batch_rec.kvi_no_case,
                               kvi_no_item = l_batch_rec.kvi_no_item,
                               kvi_no_pallet = l_batch_rec.kvi_no_pallet,
                               kvi_no_data_capture = l_batch_rec.kvi_no_data_capture
                         WHERE batch_no = l_batch_rec.batch_no;
                        SELECT jbcd_job_code, status, NVL(kvi_doc_time,0), NVL(kvi_cube,0),
                               NVL(kvi_wt,0), NVL(kvi_no_po,0), NVL(kvi_no_stop,0),
                               NVL(kvi_no_zone,0), NVL(kvi_no_loc,0), NVL(kvi_no_split,0),
                               NVL(kvi_no_merge,0), NVL(kvi_no_aisle,0), NVL(kvi_no_drop,0),
                               NVL(kvi_order_time,0), NVL(kvi_distance,0), actl_start_time,
                               actl_stop_time, actl_time_spent
                          INTO l_batch_rec.jbcd_job_code, l_batch_rec.status, l_batch_rec.kvi_doc_time,
                               l_batch_rec.kvi_cube, l_batch_rec.kvi_wt, l_batch_rec.kvi_no_po,
                               l_batch_rec.kvi_no_stop, l_batch_rec.kvi_no_zone, l_batch_rec.kvi_no_loc,
                               l_batch_rec.kvi_no_split, l_batch_rec.kvi_no_merge,
                               l_batch_rec.kvi_no_aisle, l_batch_rec.kvi_no_drop,
                               l_batch_rec.kvi_order_time, l_batch_rec.kvi_distance,
                               l_batch_rec.actl_start_time, l_batch_rec.actl_stop_time,
                               l_batch_rec.actl_time_spent
                          FROM batch
                         WHERE batch_no = l_batch_rec.batch_no;
                        SELECT jbcd_job_code, engr_std_flag, NVL(tmu_doc_time,0), NVL(tmu_cube,0),
                               NVL(tmu_wt,0), NVL(tmu_no_piece,0), NVL(tmu_no_pallet,0),
                               NVL(tmu_no_item,0), NVL(tmu_no_data_capture,0), NVL(tmu_no_po,0),
                               NVL(tmu_no_stop,0), NVL(tmu_no_zone,0), NVL(tmu_no_loc,0),
                               NVL(tmu_no_case,0), NVL(tmu_no_split,0), NVL(tmu_no_merge,0),
                               NVL(tmu_no_aisle,0), NVL(tmu_no_drop,0), NVL(tmu_order_time,0)
                          INTO l_job_code_rec.jbcd_job_code, l_job_code_rec.engr_std_flag,
                               l_job_code_rec.tmu_doc_time, l_job_code_rec.tmu_cube,
                               l_job_code_rec.tmu_wt, l_job_code_rec.tmu_no_piece,
                               l_job_code_rec.tmu_no_pallet, l_job_code_rec.tmu_no_item,
                               l_job_code_rec.tmu_no_data_capture, l_job_code_rec.tmu_no_po,
                               l_job_code_rec.tmu_no_stop, l_job_code_rec.tmu_no_zone,
                               l_job_code_rec.tmu_no_loc, l_job_code_rec.tmu_no_case,
                               l_job_code_rec.tmu_no_split, l_job_code_rec.tmu_no_merge,
                               l_job_code_rec.tmu_no_aisle, l_job_code_rec.tmu_no_drop,
                               l_job_code_rec.tmu_order_time
                          FROM job_code
                         WHERE jbcd_job_code = l_batch_rec.jbcd_job_code;
                        std := l_job_code_rec.tmu_doc_time +
                               (l_job_code_rec.tmu_cube * l_batch_rec.kvi_cube) +
                               (l_job_code_rec.tmu_wt * l_batch_rec.kvi_wt) +
                               (l_job_code_rec.tmu_no_piece * l_batch_rec.kvi_no_piece) +
                               (l_job_code_rec.tmu_no_pallet * l_batch_rec.kvi_no_pallet) +
                               (l_job_code_rec.tmu_no_item * l_batch_rec.kvi_no_item) +
                               (l_job_code_rec.tmu_no_data_capture * l_batch_rec.kvi_no_data_capture) +
                               (l_job_code_rec.tmu_no_po * l_batch_rec.kvi_no_po) +
                               (l_job_code_rec.tmu_no_stop * l_batch_rec.kvi_no_stop) +
                               (l_job_code_rec.tmu_no_zone * l_batch_rec.kvi_no_zone) +
                               (l_job_code_rec.tmu_no_loc * l_batch_rec.kvi_no_loc) +
                               (l_job_code_rec.tmu_no_case * l_batch_rec.kvi_no_case) +
                               (l_job_code_rec.tmu_no_split * l_batch_rec.kvi_no_split) +
                               (l_job_code_rec.tmu_no_merge * l_batch_rec.kvi_no_merge) +
                               (l_job_code_rec.tmu_no_aisle * l_batch_rec.kvi_no_aisle) +
                               (l_job_code_rec.tmu_no_drop * l_batch_rec.kvi_no_drop) +
                               l_job_code_rec.tmu_order_time;
                        std := std * 0.0006;
                        IF l_job_code_rec.engr_std_flag = 'Y' THEN
                           l_batch_rec.goal_time := std;
                           l_batch_rec.target_time := NULL;
                        ELSE
                           l_batch_rec.target_time := std;
                           l_batch_rec.goal_time := NULL;
                        END IF;
                        IF l_batch_rec.status IN ('A','F','M') THEN
                           UPDATE batch
                              SET kvi_cube = l_batch_rec.kvi_cube,
                                  kvi_wt = l_batch_rec.kvi_wt,
                                  kvi_no_piece = l_batch_rec.kvi_no_piece,
                                  kvi_no_pallet = l_batch_rec.kvi_no_pallet,
                                  kvi_no_item = l_batch_rec.kvi_no_pallet,
                                  kvi_no_data_capture = l_batch_rec.kvi_no_data_capture,
                                  kvi_no_po = l_batch_rec.kvi_no_po,
                                  kvi_no_stop = l_batch_rec.kvi_no_stop,
                                  kvi_no_zone = l_batch_rec.kvi_no_zone,
                                  kvi_no_loc = l_batch_rec.kvi_no_loc,
                                  kvi_no_case = l_batch_rec.kvi_no_case,
                                  kvi_no_split = l_batch_rec.kvi_no_split,
                                  kvi_no_merge = l_batch_rec.kvi_no_merge,
                                  kvi_no_aisle = l_batch_rec.kvi_no_aisle,
                                  kvi_no_drop = l_batch_rec.kvi_no_drop,
                                  status = DECODE(l_batch_rec.status,'F','C',status),
                                  goal_time = l_batch_rec.goal_time,
                                  target_time = l_batch_rec.target_time,
                                  actl_stop_time = SYSDATE,
                                  actl_start_time = DECODE(l_batch_rec.status,'F',SYSDATE,
                                  NVL(actl_start_time,SYSDATE)),
                                  actl_time_spent = DECODE(l_batch_rec.status,'F',0,
                                  (SYSDATE-NVL(l_batch_rec.actl_start_time,SYSDATE))*24*60),
                                  user_id = DECODE(l_batch_rec.status,'F',g_client.user_id,user_id)
                            WHERE batch_no = l_batch_rec.batch_no;
                           IF l_batch_rec.status <> 'M' THEN
                              l_batch_rec.status := 'C';
                           END IF;
                           IF l_batch_rec.status = 'F' THEN
                              SELECT COUNT(*)
                                INTO g_row_count
                                FROM batch
                               WHERE status = 'A'
                                 AND user_id = g_client.user_id;
                              IF g_row_count > 1 THEN
                                  g_err_msg := 'Found more than 1 active batch for user ' || g_client.user_id;
                                 Pl_Text_Log.ins_msg('WARN',ct_PROGRAM_CODE,g_err_msg,SQLCODE,SQLERRM);
                              ELSIF g_row_count = 1 THEN
                                 SELECT actl_start_time
                                   INTO l_batch_rec.actl_start_time
                                   FROM batch
                                  WHERE status = 'A'
                                    AND user_id = g_client.user_id;
                                 UPDATE batch
                                    SET status = 'C',
                                        actl_time_spent = (actl_stop_time - actl_start_time)*24*60
                                  WHERE status = 'A'
                                    AND user_id = g_client.user_id;
                              END IF;
                           END IF;
                        END IF;
                     EXCEPTION
                        WHEN OTHERS THEN
                            g_err_msg := 'ORACLE Unable to update receiving batch.';
                           Pl_Text_Log.ins_msg('WARN',ct_PROGRAM_CODE,g_err_msg,SQLCODE,SQLERRM);
                     END;
                  END IF;
               EXCEPTION
                  WHEN OTHERS THEN
                     NULL;
               END;
            END IF;
         EXCEPTION
            WHEN OTHERS THEN
               ROLLBACK TO SAVEPOINT update_lm_batch;
                      g_err_msg := 'ORACLE Unable to get labor mgmt receiving batch flag.';
               Pl_Text_Log.ins_msg('WARN',ct_PROGRAM_CODE,g_err_msg,SQLCODE,SQLERRM);
         END;
      END IF;
   END update_lm_batch;
   -----------------------------------------------------------------------------
   -- Procedure update_erd
   -----------------------------------------------------------------------------
   PROCEDURE update_erd(i_rec_id IN VARCHAR2) IS
      l_qty_unassigned NUMBER;
      l_catchweight NUMBER;
      l_avg_weight NUMBER;
      l_total_qty NUMBER;
	  l_syspar_hosttype sys_config.config_flag_val%TYPE;
	  l_uom_count	NUMBER := 0;
      
      CURSOR c_po (cp_rec_id VARCHAR2) IS
      SELECT erm_id
        FROM erm
       WHERE po = cp_rec_id;
    -- 1/22/12 sray0453 - CRQ30627 - VSN Item recon issue fix
    --         The licenseplate should be exactly matched with ERD for processing
    
      CURSOR po_dtl_cur (p_po VARCHAR2) IS
      SELECT d.prod_id, d.cust_pref_vendor, el.po_no, COUNT(*) line_cnt
        FROM erd_lpn el, erd d
       WHERE el.sn_no(+) = d.erm_id
         AND el.erm_line_id(+) = d.erm_line_id
         AND el.prod_id(+) = d.prod_id  
         AND d.erm_id = p_po
       GROUP BY d.prod_id, d.cust_pref_vendor, el.po_no;

	  CURSOR prod_cur (p_erm_id VARCHAR2, p_prod_id VARCHAR2, p_cust_pref_vendor VARCHAR2, p_po VARCHAR2) IS
      SELECT d.erm_line_id, d.qty, el.po_no
        FROM erd_lpn el, erd d
       WHERE el.sn_no(+) = d.erm_id
         AND el.erm_line_id(+) = d.erm_line_id
         AND el.po_no(+) = p_po
         AND d.erm_id = p_erm_id
         AND d.prod_id = p_prod_id
         AND d.cust_pref_vendor = p_cust_pref_vendor
       ORDER BY d.uom
      FOR UPDATE OF d.qty_rec, d.weight;
   BEGIN
      Pl_Text_Log.ins_msg('DEBUG',ct_PROGRAM_CODE,'Starting update ERD for SN/PO='||i_rec_id,SQLCODE,
         SQLERRM);
	  l_syspar_hosttype := pl_common.f_get_syspar('HOST_TYPE', 'N');
	  
      FOR r_po IN c_po (i_rec_id) LOOP
         BEGIN
            FOR po_dtl_rec IN po_dtl_cur (r_po.erm_id) LOOP
               Pl_Text_Log.ins_msg('DEBUG',ct_PROGRAM_CODE,'Processing item=['||po_dtl_rec.prod_id||']',
                  SQLCODE,SQLERRM);
               UPDATE pm
                  SET last_rec_date = SYSDATE
                WHERE prod_id = po_dtl_rec.prod_id
                  AND cust_pref_vendor = po_dtl_rec.cust_pref_vendor;
               UPDATE pm_upc
                  SET last_rec_date = SYSDATE
                WHERE prod_id = po_dtl_rec.prod_id
                  AND cust_pref_vendor = po_dtl_rec.cust_pref_vendor
                  AND vendor_id = (SELECT source_id FROM erm
                                    WHERE erm_id = i_rec_id);					
			   
				   SELECT NVL(SUM(qty_received),0)
					 INTO l_qty_unassigned
					 FROM putawaylst
					WHERE rec_id = r_po.erm_id
					  AND po_no = NVL(po_dtl_rec.po_no,po_no)
					  AND prod_id = po_dtl_rec.prod_id
					  AND cust_pref_vendor = po_dtl_rec.cust_pref_vendor;	 

			   IF l_syspar_hosttype = 'SAP' THEN						
					SELECT DISTINCT COUNT(UOM) 
					 INTO l_uom_count
					 FROM putawaylst
					WHERE rec_id = r_po.erm_id
					  AND po_no = NVL(po_dtl_rec.po_no,po_no)
					  AND prod_id = po_dtl_rec.prod_id
					  AND cust_pref_vendor = po_dtl_rec.cust_pref_vendor;	 
			   END IF;
			   
               SELECT NVL(SUM(qty_received),0)
                 INTO l_total_qty
                 FROM putawaylst
                WHERE rec_id = r_po.erm_id
                  AND prod_id = po_dtl_rec.prod_id
                  AND cust_pref_vendor = po_dtl_rec.cust_pref_vendor;
              BEGIN
                  SELECT total_weight
                    INTO l_catchweight
                    FROM tmp_weight
                   WHERE erm_id = r_po.erm_id
                     AND prod_id = po_dtl_rec.prod_id
                     AND cust_pref_vendor = po_dtl_rec.cust_pref_vendor;
                  IF l_total_qty = 0 THEN
                     l_avg_weight := 0;
                  ELSE
                     l_avg_weight := l_catchweight / l_total_qty;
                  END IF;
               EXCEPTION
                  WHEN NO_DATA_FOUND THEN
                     l_catchweight := 0;
                     l_avg_weight := 0;
                  WHEN OTHERS THEN
                     l_catchweight := 0;
                     l_avg_weight := 0;
                     g_err_msg := 'Error getting total weight from TMP_WEIGHT for item ' || po_dtl_rec.prod_id;
                     Pl_Text_Log.ins_msg('WARN',ct_PROGRAM_CODE,g_err_msg,SQLCODE,SQLERRM);
               END;
               g_err_msg := 'ITEM '||po_dtl_rec.prod_id||':qty
                  received=['||TO_CHAR(l_qty_unassigned)||'],weight=['||
                  TO_CHAR(l_catchweight)||']';
               Pl_Text_Log.ins_msg('WARN',ct_PROGRAM_CODE,g_err_msg,SQLCODE,SQLERRM);
               BEGIN
                  FOR prod_rec IN prod_cur
                     (r_po.erm_id, po_dtl_rec.prod_id, po_dtl_rec.cust_pref_vendor, po_dtl_rec.po_no) LOOP
					 
					IF l_syspar_hosttype = 'SAP' AND l_uom_count>1 THEN
					   SELECT NVL(SUM(qty_received),0)
						 INTO l_qty_unassigned
						 FROM putawaylst
						WHERE rec_id = r_po.erm_id
						  AND po_no = NVL(po_dtl_rec.po_no,po_no)
						  AND erm_line_id = prod_rec.erm_line_id 
						  AND prod_id = po_dtl_rec.prod_id
						  AND cust_pref_vendor = po_dtl_rec.cust_pref_vendor;	  			
					END IF;
    
                     IF NVL(prod_rec.po_no,'NULL') = NVL(po_dtl_rec.po_no,'NULL') THEN
                        IF l_qty_unassigned <= 0 THEN
                           UPDATE erd
                              SET qty_rec = 0,
                                   weight = 0
                            WHERE CURRENT OF prod_cur;
                        ELSIF po_dtl_rec.line_cnt > 1 AND l_qty_unassigned > prod_rec.qty THEN
                           po_dtl_rec.line_cnt := po_dtl_rec.line_cnt - 1;
                           UPDATE erd
                              SET qty_rec = prod_rec.qty,
                                   weight = prod_rec.qty * l_avg_weight
                            WHERE CURRENT OF prod_cur;
                        ELSE
                           po_dtl_rec.line_cnt := po_dtl_rec.line_cnt - 1;
                           UPDATE erd
                              SET qty_rec = l_qty_unassigned,
                                   weight = l_qty_unassigned * l_avg_weight
                            WHERE CURRENT OF prod_cur;
                        END IF;
                        IF l_qty_unassigned > prod_rec.qty THEN
                           l_qty_unassigned := l_qty_unassigned - prod_rec.qty;
                        ELSE
                           l_qty_unassigned := 0;
                        END IF;
                     END IF;
                  END LOOP;
               EXCEPTION
                  WHEN OTHERS THEN
                     g_sqlcode := SQLCODE;
                     g_err_msg := 'ORACLE Unable to update ERD for SN/PO='||r_po.erm_id||' PROD_ID='||po_dtl_rec.prod_id;
                     Pl_Text_Log.ins_msg('FATAL',ct_PROGRAM_CODE,g_err_msg,SQLCODE,SQLERRM);
                     RAISE e_premature_termination;
               END;
            END LOOP;
         EXCEPTION
            WHEN e_premature_termination THEN
               RAISE;
            WHEN OTHERS THEN
               g_sqlcode := SQLCODE;
               g_err_msg := 'ORACLE Unable to update ERD for SN/PO '||r_po.erm_id||'.';
               Pl_Text_Log.ins_msg('WARN',ct_PROGRAM_CODE,g_err_msg,SQLCODE,SQLERRM);
               RAISE e_premature_termination;
         END;
      END LOOP;
   END update_erd;
  -----------------------------------------------------------------------------
   -- Procedure update_inv
   --   Should be able to get rid of this routine when CRT data collection
   --   starts doing its whole job.
   -----------------------------------------------------------------------------
   PROCEDURE update_inv(i_rec_id IN VARCHAR2) IS
      inv_rec inv%ROWTYPE;
      source_loc putawaylst.dest_loc%TYPE;
      front_loc putawaylst.dest_loc%TYPE;
      home_slot_flag BOOLEAN;
      float_item_flag BOOLEAN := FALSE;
      update_flag BOOLEAN;
      home_slot_count NUMBER;
      inv_count NUMBER;
      shelf_life NUMBER;
      in_aging CHAR(1);
      -- SCI003 -C starts - host_type variable 
      
      host_type varchar2(6);
      
      -- SCI003-C ends
      
      inv_Osdcount NUMBER :=0;
      inv_OsdreasonCnt NUMBER :=0;

      is_cross_dock  VARCHAR2(1);
      cross_dock_cnt NUMBER;

      CURSOR c_po (cp_rec_id VARCHAR2) IS
      SELECT erm_id
        FROM erm
       WHERE po = cp_rec_id;
	   -- acpvxg 03 FEB 06   
	   --  parent_pallet_id added to the cursor.  
      CURSOR put_cur (p_po VARCHAR2) IS
      SELECT pallet_id, qty_received, dest_loc, pt.prod_id, pt.cust_pref_vendor, pt.uom,
             putaway_put, mfg_date, date_code, lot_id, lot_trk, exp_date, exp_date_trk, temp,
             temp_trk, clam_bed_trk, inv_status, qty_expected, pt.weight, rec_id,
             TO_CHAR(out_inv_date,'DD-MON-YYYY') out_inv_date,
             DECODE(inv_status,'HLD','01-JAN-1980',
             TO_CHAR(SYSDATE,'DD-MON-YYYY')) upload_date,
             l.perm, pt.status STATUS,
             pt.pallet_batch_no,
			 parent_pallet_id
        FROM loc l, putawaylst pt
       WHERE pt.rec_id = p_po
         AND l.logi_loc(+) = pt.dest_loc;

      CURSOR trans_cur (p_pallet_id VARCHAR2) IS
      SELECT dest_loc
        FROM trans
       WHERE pallet_id = p_pallet_id
         AND trans_type IN ('SWP','XFR','HST','RPL','DLD','PUT','IND','DFK');
   BEGIN

      FOR r_po IN c_po (i_rec_id) LOOP
         BEGIN
            cross_dock_cnt := 0;
            SELECT count(*)
              INTO cross_dock_cnt
              FROM erm
             WHERE erm_id = r_po.erm_id
               AND cross_dock_type IS NOT NULL;

            IF cross_dock_cnt > 0 THEN
                is_cross_dock := 'Y';
            ELSE
                is_cross_dock := 'N';
            END IF;

            FOR put_rec IN put_cur (r_po.erm_id) LOOP
               update_flag := TRUE;
               inv_count := NULL;

               IF put_rec.temp_trk = 'C' THEN
                  inv_rec.temperature := put_rec.temp;
               END IF;

               IF put_rec.lot_trk = 'C' THEN
                  inv_rec.lot_id := put_rec.lot_id;
               END IF;

               IF put_rec.date_code = 'C' THEN
                  inv_rec.mfg_date := put_rec.mfg_date;
               END IF;

               IF put_rec.exp_date_trk = 'C' THEN
                  inv_rec.exp_date := put_rec.exp_date;
               END IF;

               BEGIN
                  SELECT plogi_loc
                    INTO front_loc
                    FROM loc_reference
                   WHERE bck_logi_loc = put_rec.dest_loc;
                  Pl_Text_Log.ins_msg('DEBUG',ct_PROGRAM_CODE,'DEST_LOC='||put_rec.dest_loc||
                     '  FRONT_LOC='||front_loc,SQLCODE,SQLERRM);
                  put_rec.dest_loc := front_loc;
               EXCEPTION
                  WHEN OTHERS THEN
                     Pl_Text_Log.ins_msg('DEBUG',ct_PROGRAM_CODE,
                        'ORACLE No front side location exists for this location.',
                        SQLCODE,SQLERRM);
               END;
               BEGIN
                  SELECT COUNT(*)
                    INTO home_slot_count
                    FROM loc
                   WHERE rank = 1
                     AND perm = 'Y'
                     AND ((put_rec.uom = 1 AND uom IN (0,1))
                      OR (uom IN (0,2)))
                     AND prod_id = put_rec.prod_id
                     AND cust_pref_vendor = put_rec.cust_pref_vendor
                     AND logi_loc = put_rec.dest_loc;
               EXCEPTION
                    WHEN OTHERS THEN
                     g_sqlcode := SQLCODE;
                     g_err_msg := 'Oracle error checking for home slot.';
                     Pl_Text_Log.ins_msg('WARN',ct_PROGRAM_CODE,g_err_msg,SQLCODE,SQLERRM);
                     RAISE e_premature_termination;
               END;
               IF home_slot_count = 0 THEN
                  home_slot_flag := FALSE;
                  g_err_msg := '  Not a home slot: ' || put_rec.dest_loc;
                  Pl_Text_Log.ins_msg('DEBUG',ct_PROGRAM_CODE,g_err_msg,SQLCODE,SQLERRM);
               ELSE
                  home_slot_flag := TRUE;
                  g_err_msg := '  Home slot: ' || put_rec.dest_loc;
                  Pl_Text_Log.ins_msg('DEBUG',ct_PROGRAM_CODE,g_err_msg,SQLCODE,SQLERRM);
               END IF;
               BEGIN
                  SELECT NVL(case_cube,1.0), NVL(spc,1), NVL(sysco_shelf_life,0),
                         NVL(cust_shelf_life,0), NVL(mfr_shelf_life,0)
                    INTO g_pm_rec.case_cube, g_pm_rec.spc, g_pm_rec.sysco_shelf_life,
                         g_pm_rec.cust_shelf_life, g_pm_rec.mfr_shelf_life
                    FROM pm
                   WHERE prod_id = put_rec.prod_id
                     AND cust_pref_vendor = put_rec.cust_pref_vendor;
               EXCEPTION
                  WHEN OTHERS THEN
                     g_sqlcode := SQLCODE;
                     g_err_msg := 'ORACLE Unable to get item information.';
                     Pl_Text_Log.ins_msg('WARN',ct_PROGRAM_CODE,g_err_msg,SQLCODE,SQLERRM);
                     g_server.status := ct_INV_PRODID;
                     RAISE e_premature_termination;
               END;
                      inv_rec := NULL;
               IF put_rec.qty_received > 0 THEN
                  IF NOT home_slot_flag THEN
                     IF put_rec.putaway_put = 'Y' THEN
                        IF g_erm_rec.erm_type = 'TR' THEN
                           inv_rec.inv_date := TO_DATE(put_rec.out_inv_date,'DD-MON-YYYY');
                           inv_rec.rec_date := TO_DATE(put_rec.out_inv_date,'DD-MON-YYYY');
                        END IF;
                        SELECT COUNT(*)
                          INTO inv_count
                          FROM inv
                         WHERE logi_loc = put_rec.pallet_id
                           AND prod_id = put_rec.prod_id;
                        IF inv_count = 0 THEN
                          BEGIN
/*
                              SELECT plogi_loc
                                INTO put_rec.dest_loc
                                FROM inv
                               WHERE prod_id = put_rec.prod_id
                                 AND plogi_loc = logi_loc
                                 AND EXISTS (SELECT '1'
                                               FROM loc
                                              WHERE loc.logi_loc = inv.plogi_loc
                                                AND loc.uom IN (0,2))
                                 AND ROWNUM < 2;
*/
                              SELECT dest_loc
                                INTO put_rec.dest_loc
                                FROM trans
                               WHERE trans_date = (SELECT MAX(trans_date) FROM trans
                                                    WHERE pallet_id = put_rec.pallet_id
                                                      AND trans_type IN ('SWP','XFR','HST','RPL','DLD','PUT','IND','DFK')
                                                      AND dest_loc IS NOT NULL
                                                      AND user_id <> 'ORDER')
                                 AND pallet_id = put_rec.pallet_id
                                 AND trans_type IN ('SWP','XFR','HST','RPL','DLD','PUT','IND','DFK')
                                 AND user_id <> 'ORDER'
                                 AND ROWNUM = 1;

                            EXCEPTION
                               WHEN NO_DATA_FOUND THEN
                                  g_err_msg := 'ORACLE Error finding inventory record for putaway task. Pallet='||
                                       put_rec.pallet_id;
                                 Pl_Text_Log.ins_msg('WARN',ct_PROGRAM_CODE,g_err_msg,SQLCODE,SQLERRM);
                                 update_flag := FALSE;
                                 float_item_flag := TRUE;
                           END;
                        END IF;
                     ELSE /* put_rec.putaway_put = 'N' */
                        --
                        -- 03/14/2017  Brian Bent
                        -- Live Receiving
                        -- Change
                        --    IF put_rec.dest_loc = '*' THEN
                        -- to
                        --    IF (put_rec.dest_loc IN ('*', 'LR')) THEN
                        --
                        IF (put_rec.dest_loc IN ('*', 'LR')) THEN
                          g_err_msg := 'Item ' || put_rec.prod_id || ' pallet ' || put_rec.pallet_id ||
                                           ' not assigned a slot. Destination location is ' || put_rec.dest_loc || '.';
                          Pl_Text_Log.ins_msg('WARN',ct_PROGRAM_CODE,g_err_msg,0,'');
                          g_server.status := ct_INV_DEST_LOC;
                          RAISE e_premature_termination;
                        END IF;
                        inv_rec.qoh := put_rec.qty_received;
                        inv_rec.qty_planned := put_rec.qty_expected;
                        IF g_erm_rec.erm_type = 'TR' THEN
                           inv_rec.inv_date := TO_DATE(put_rec.out_inv_date,'DD-MON-YYYY');
                           inv_rec.rec_date := TO_DATE(put_rec.out_inv_date,'DD-MON-YYYY');
                        ELSE
                           inv_rec.inv_date := SYSDATE;
                           inv_rec.rec_date := SYSDATE;
                        END IF;
                        inv_rec.weight := put_rec.weight;
                        inv_rec.rec_id := r_po.erm_id;
                        inv_rec.status := put_rec.inv_status;
                        inv_rec.CUBE := ((put_rec.qty_received - put_rec.qty_expected) /
                           g_pm_rec.spc) * g_pm_rec.case_cube;
                        inv_rec.exp_date := put_rec.exp_date;
                        inv_rec.lot_id := put_rec.lot_id;
                        inv_rec.temperature := put_rec.temp;
                     END IF; /* put_rec.putaway_put = Y|N */
                     IF NOT float_item_flag THEN
                        IF put_rec.temp_trk = 'C' THEN
                           inv_rec.temperature := put_rec.temp;
                        END IF;
                        IF put_rec.lot_trk = 'C' THEN
                           inv_rec.lot_id := put_rec.lot_id;
                        END IF;
                        inv_rec.exp_ind := 'Y';
                        IF put_rec.date_code = 'C' THEN
                           inv_rec.mfg_date := put_rec.mfg_date;
                           inv_rec.exp_date := put_rec.exp_date;
                        ELSIF put_rec.exp_date_trk = 'C' THEN
                           inv_rec.exp_date := put_rec.exp_date;
                        ELSE
                           IF g_pm_rec.sysco_shelf_life <> 0 AND g_pm_rec.cust_shelf_life <> 0 THEN
                              shelf_life := g_pm_rec.sysco_shelf_life + g_pm_rec.cust_shelf_life;
                           ELSIF g_pm_rec.mfr_shelf_life <> 0 THEN
                              shelf_life := g_pm_rec.mfr_shelf_life;
                           ELSE
                              shelf_life := 0;
                           END IF;
                           inv_rec.exp_date := SYSDATE + shelf_life;
                        END IF;
                        inv_rec.exp_ind := 'N';
                     END IF; /* Not float item */
                  ELSE /* Float item */
                     IF put_rec.putaway_put <> 'Y' THEN
                        inv_rec.qoh := put_rec.qty_received;
                        inv_rec.qty_planned := put_rec.qty_expected;
                        IF g_erm_rec.erm_type = 'TR' THEN
                           inv_rec.inv_date := TO_DATE(put_rec.out_inv_date,'DD-MON-YYYY');
                           inv_rec.rec_date := TO_DATE(put_rec.out_inv_date,'DD-MON-YYYY');
                        ELSE
                           inv_rec.inv_date := SYSDATE;
                           inv_rec.rec_date := SYSDATE;
                        END IF;
                        inv_rec.rec_id := r_po.erm_id;
                        inv_rec.status := put_rec.inv_status;
                        inv_rec.CUBE := ((put_rec.qty_received - put_rec.qty_expected) /
                           g_pm_rec.spc) * g_pm_rec.case_cube;
                     END IF;
                     IF put_rec.temp_trk = 'C' THEN
                        inv_rec.temperature := put_rec.temp;
                     END IF;
                     IF put_rec.lot_trk = 'C' THEN
                        inv_rec.lot_id := put_rec.lot_id;
                     END IF;
                     inv_rec.exp_ind := 'Y';
                     IF put_rec.date_code = 'C' THEN
                        inv_rec.mfg_date := put_rec.mfg_date;
                        inv_rec.exp_date := put_rec.exp_date;
                     ELSIF put_rec.exp_date_trk = 'C' THEN
                        inv_rec.exp_date := put_rec.exp_date;
                     ELSE
                        IF g_pm_rec.sysco_shelf_life <> 0 AND g_pm_rec.cust_shelf_life <> 0 THEN
                           shelf_life := g_pm_rec.sysco_shelf_life + g_pm_rec.cust_shelf_life;
                        ELSIF g_pm_rec.mfr_shelf_life <> 0 THEN
                           shelf_life := g_pm_rec.mfr_shelf_life;
                        ELSE
                           shelf_life := 0;
                        END IF;
                        inv_rec.exp_date := SYSDATE + shelf_life;
                     END IF;
                  END IF;
                  inv_rec.exp_ind := 'N';
               ELSIF put_rec.qty_received = 0 THEN
                  IF put_rec.putaway_put <> 'Y' THEN

                     --
                     -- 03/14/2017  Brian Bent
                     -- Live Receiving
                     -- Change
                     --    IF put_rec.dest_loc <> '*' THEN
                     -- to
                     --    IF (put_rec.dest_loc NOT IN ('*', 'LR')) THEN
                     --
                     IF (put_rec.dest_loc NOT IN ('*', 'LR')) THEN
                        IF NOT home_slot_flag THEN
                           update_flag := FALSE;
                           BEGIN
                              DELETE FROM inv
                               WHERE logi_loc = put_rec.pallet_id
                                 AND plogi_loc = put_rec.dest_loc;
                           EXCEPTION
                              WHEN OTHERS THEN
                                 g_sqlcode := SQLCODE;
                                 g_err_msg := 'Oracle error deleting from inventory.';
                                 Pl_Text_Log.ins_msg('WARN',ct_PROGRAM_CODE,g_err_msg,SQLCODE,SQLERRM);
                                 RAISE e_premature_termination;
                           END;
                        ELSE
                           inv_rec.qoh := put_rec.qty_received;
                           inv_rec.qty_planned := put_rec.qty_expected;
                           inv_rec.CUBE := (put_rec.qty_expected / g_pm_rec.spc) * g_pm_rec.case_cube;
                        END IF;
                     END IF;
                  END IF;
               END IF;
               IF update_flag THEN
                    BEGIN
                
                     IF put_rec.putaway_put = 'N' THEN
                        UPDATE inv
                           SET inv_date = NVL(inv_rec.inv_date,inv_date),
                               rec_date = NVL(inv_rec.inv_date,inv_date),
                               exp_date = NVL(inv_rec.exp_date,exp_date),
                               mfg_date = NVL(inv_rec.mfg_date,mfg_date),
                               qoh = qoh + DECODE(put_rec.putaway_put, 'Y', 0, NVL(inv_rec.qoh,0)),
                                  qty_planned = DECODE(inv_rec.qty_planned,NULL,qty_planned,
                                  DECODE(SIGN(qty_planned-inv_rec.qty_planned),1,
                                  qty_planned-inv_rec.qty_planned,-1,0,0)),
                               weight = NVL(inv_rec.weight,weight),
                               rec_id = NVL(inv_rec.rec_id,rec_id),
                               status = NVL(inv_rec.status,status),
                               lot_id = NVL(inv_rec.lot_id,lot_id),
 			       /* 10/27/06 BEG INS Infosys - Inserted to clear MSKU flag */
                               /* Jira 2558: do not clear the parent_pallet_id if cross dock */
      			       parent_pallet_id = DECODE(is_cross_dock, 'Y', parent_pallet_id, null),
          		       /* 10/27/06 END INS Infosys */    	
                               temperature = NVL(inv_rec.temperature,temperature),
                               CUBE = CUBE + NVL(inv_rec.CUBE,0)
                         WHERE plogi_loc = put_rec.dest_loc
                           AND prod_id = put_rec.prod_id
                           AND (logi_loc = plogi_loc OR logi_loc = put_rec.pallet_id);
                        g_err_msg := 'Dest Loc INV Update #1 - Key=[' || put_rec.dest_loc || '] : ' ||
                           TO_CHAR(SQL%ROWCOUNT) || ' record(s) updated';
                        Pl_Text_Log.ins_msg('WARN',ct_PROGRAM_CODE,g_err_msg,SQLCODE,SQLERRM);
                     ELSIF NVL(inv_count,0) > 0 THEN
                        UPDATE inv
                           SET inv_date = NVL(inv_rec.inv_date,inv_date),
                               rec_date = NVL(inv_rec.inv_date,inv_date),
                               exp_date = NVL(inv_rec.exp_date,exp_date),
                               mfg_date = NVL(inv_rec.mfg_date,mfg_date),
                               weight = NVL(inv_rec.weight,weight),
                               rec_id = NVL(inv_rec.rec_id,rec_id),
                               status = NVL(inv_rec.status,status),
                               lot_id = NVL(inv_rec.lot_id,lot_id),
                               temperature = NVL(inv_rec.temperature,temperature),
 			       /* 01/18/07 BEG INS acpmxp - Inserted to clear MSKU flag */
                               /* Jira 2558: do not clear the parent_pallet_id if cross dock */
                               parent_pallet_id = DECODE(is_cross_dock, 'Y', parent_pallet_id, null),
 			       /* 01/18/07 END INS acpmxp - Inserted to clear MSKU flag */
                               CUBE = CUBE + NVL(inv_rec.CUBE,0)
                         WHERE logi_loc = put_rec.pallet_id;
                        g_err_msg := 'Pallet ID INV Update #2 - Key=[' || put_rec.pallet_id || '] : ' ||
                          TO_CHAR(SQL%ROWCOUNT) || ' record(s) updated';
                        Pl_Text_Log.ins_msg('WARN',ct_PROGRAM_CODE,g_err_msg,SQLCODE,SQLERRM);
                     ELSE
                        UPDATE inv
                           SET inv_date = NVL(inv_rec.inv_date,inv_date),
                               rec_date = NVL(inv_rec.inv_date,inv_date),
                               exp_date = NVL(inv_rec.exp_date,exp_date),
                               mfg_date = NVL(inv_rec.mfg_date,mfg_date),
                               weight = NVL(inv_rec.weight,weight),
                               rec_id = NVL(inv_rec.rec_id,rec_id),
                               status = NVL(inv_rec.status,status),
                               lot_id = NVL(inv_rec.lot_id,lot_id),
                               temperature = NVL(inv_rec.temperature,temperature),
 			       /* 01/18/07 BEG INS acpmxp - Inserted to clear MSKU flag */
                               /* Jira 2558: do not clear the parent_pallet_id if cross dock */
                               parent_pallet_id = DECODE(is_cross_dock, 'Y', parent_pallet_id, null),
 			       /* 01/18/07 END INS acpmxp - Inserted to clear MSKU flag */
                               CUBE = CUBE + NVL(inv_rec.CUBE,0)
                         WHERE prod_id = put_rec.prod_id
                            AND plogi_loc = logi_loc
                            AND EXISTS (SELECT '1' FROM loc
                                         WHERE loc.logi_loc = inv.plogi_loc
                                           AND loc.uom IN (0,2));
                        g_err_msg := 'Home Slot INV Update #3 - Key=[' || put_rec.prod_id || '] : ' ||
                          TO_CHAR(SQL%ROWCOUNT) || ' record(s) updated';
                        Pl_Text_Log.ins_msg('WARN',ct_PROGRAM_CODE,g_err_msg,SQLCODE,SQLERRM);
                     END IF;

                    FOR trans_rec IN trans_cur (put_rec.pallet_id) LOOP
                       UPDATE inv
                          SET exp_date = inv_rec.exp_date,
                              mfg_date = inv_rec.mfg_date
                        WHERE logi_loc = put_rec.pallet_id
                           OR (prod_id = put_rec.prod_id
                          AND  plogi_loc = trans_rec.dest_loc
                          AND  plogi_loc = logi_loc);
                    END LOOP;

                    EXCEPTION
                     WHEN OTHERS THEN
                        g_sqlcode := SQLCODE;
                        g_err_msg := 'Oracle error updating inventory. ' || TO_CHAR(SQLCODE);
                        Pl_Text_Log.ins_msg('WARN',ct_PROGRAM_CODE,g_err_msg,SQLCODE,SQLERRM);
                        RAISE e_premature_termination;
                    END;
               END IF;
               IF put_rec.putaway_put <> 'Y' THEN
                  BEGIN
                     IF NOT home_slot_flag THEN
                        SELECT mfg_date, exp_date
                          INTO inv_rec.mfg_date, inv_rec.exp_date
                          FROM inv
                         WHERE plogi_loc = put_rec.dest_loc
                           AND logi_loc = put_rec.pallet_id;
                     ELSE
                        SELECT mfg_date, exp_date
                          INTO inv_rec.mfg_date, inv_rec.exp_date
                          FROM inv
                         WHERE plogi_loc = put_rec.dest_loc
                           AND logi_loc = put_rec.dest_loc;
                     END IF;
                  EXCEPTION
                     WHEN OTHERS THEN
                        g_err_msg := 'Error finding inventory for [' ||put_rec.pallet_id || '].';
                        Pl_Text_Log.ins_msg('WARN',ct_PROGRAM_CODE,g_err_msg,SQLCODE,SQLERRM);
                  END;
                  source_loc := f_get_haul_location(put_rec.pallet_id);
                  in_aging := 'N';
                  IF source_loc IS NULL THEN
                     source_loc := g_erm_rec.door_no;
                  END IF;
                  IF g_erm_rec.warehouse_id <> '000' OR g_erm_rec.to_warehouse_id <> '000' THEN
                     put_rec.upload_date := '01-JAN-1980';
                  END IF;
                  IF put_rec.inv_status = 'HLD' THEN
                     BEGIN
                        SELECT 'Y'
                          INTO in_aging
                          FROM aging_items
                         WHERE prod_id = put_rec.prod_id
                           AND cust_pref_vendor = put_rec.cust_pref_vendor;
                        put_rec.inv_status := 'AVL';
                     EXCEPTION
                        WHEN NO_DATA_FOUND THEN
                           in_aging := 'N';
                     END;
                  END IF;
                  --acppzp OSD changes begin
                  --check if any damaged pallet exists for SN/PO
                  inv_Osdcount :=0;
                  IF gv_osd_sys_flag  = 'Y' THEN
                     BEGIN

                        SELECT  COUNT(*)
                        INTO  inv_Osdcount
                        FROM OSD o,putawaylst p
                        WHERE   p.rec_id = g_erm_rec.erm_id
                        AND o.orig_pallet_id = p.pallet_id;

                      EXCEPTION
                        WHEN OTHERS THEN
                           g_sqlcode := SQLCODE;
                           g_err_msg := 'ORACLE unable to select OSD information for SN/PO.'||g_erm_rec.erm_id;
                           Pl_Text_Log.ins_msg('WARN',ct_PROGRAM_CODE,g_err_msg,SQLCODE,SQLERRM);
                           g_server.status := ct_SELECT_ERROR;
                           RAISE e_premature_termination;
                      END;
                   END IF;
                   --SCI003-C starts
                              -- retreive host_type value from sys_config table 
                              
                                BEGIN
                                    select config_flag_val 
                                    INTO host_type 
                                    FROM sys_config
                                    WHERE config_flag_name='HOST_TYPE'; 
                                                             
                                END;
                    --- SCI003-C ends
                   IF inv_Osdcount > 0 THEN
               --check if any pallet exists for
               --SN/PO for which reason code has not
               --been updated
                        BEGIN

                              SELECT   COUNT(*)
                              INTO  inv_OsdreasonCnt
                              FROM OSD o,putawaylst p
                              WHERE   p.rec_id = g_erm_rec.erm_id
                              AND o.orig_pallet_id =  p.pallet_id
                              AND  o.reason_code IN ('SSS','OOO','DDD');




                             IF inv_OsdreasonCnt >0 THEN
        --if reason codes for all OSD pallets for SN/PO not updated then
        --all PUTs to be sent to SUS hence insertion with SYSDATE
                              BEGIN
							  -- acpvxg 03 FEB 06 
							  -- included parent_pallet_id to following insert into trans. 
                              
                                 INSERT INTO trans (src_loc, dest_loc, trans_id, trans_type, rec_id, exp_date,
                                           mfg_date, trans_date, user_id, prod_id, cust_pref_vendor,
                                           pallet_id, new_status, uom, qty, weight, upload_time, batch_no,
                                           cmt, warehouse_id,
                                           labor_batch_no,parent_pallet_id)
                                 VALUES (source_loc, put_rec.dest_loc, trans_id_seq.NEXTVAL,
                                         DECODE(g_erm_rec.erm_type,'TR','TRP','PUT'), r_po.erm_id,
                                         inv_rec.exp_date, inv_rec.mfg_date, SYSDATE, USER,
                                         put_rec.prod_id, put_rec.cust_pref_vendor, put_rec.pallet_id,
                                         DECODE(g_ei_pallet,'Y','AVL',DECODE(put_rec.status,'DMG','DMG',put_rec.inv_status)),
                                         put_rec.uom, put_rec.qty_received, put_rec.weight,
                                         TO_DATE('01-JAN-1980'),
                                         TO_NUMBER(DECODE(g_rf_flag,'Y','99','88')), put_rec.pallet_id,
                                         DECODE(g_erm_rec.erm_type,'TR',g_erm_rec.to_warehouse_id,g_erm_rec.warehouse_id),
                                         put_rec.pallet_batch_no,put_rec.parent_pallet_id);
                              EXCEPTION
                                 WHEN OTHERS THEN
                                    g_sqlcode := SQLCODE;
                                    g_err_msg := 'Oracle error inserting into transaction table.';
                                    Pl_Text_Log.ins_msg('WARN',ct_PROGRAM_CODE,g_err_msg,SQLCODE,SQLERRM);
                                    RAISE e_premature_termination;
                              END;
                            ELSE
                                 -- for all PROPER reason codes
				 --in place for SN/PO
                                 --if the inv_status for the pallet is
				 --DMG in putawaylst ie damaged pallet
                                 --then PUT needs to be sent to SUS
				 --hence inserted with SYSDATE
                                 --if pallet is not damaged PUT
				 --not to be sent to SUS hence inserted
                                 --with the old date
                               BEGIN
							   -- acpvxg 03 FEB 06 
							   -- included parent_pallet_id to following insert into trans.
 --SCI003-C starts
                          -- if no OSD pallets for SN/PO exists send the data to SAP
                          
                                  IF host_type = 'SAP' THEN
                                                                       
                                    IF put_rec.qty_received >= 0 THEN
                                        INSERT INTO trans (src_loc, dest_loc, trans_id, trans_type, rec_id, exp_date,
                                               mfg_date, trans_date, user_id, prod_id, cust_pref_vendor,
                                               pallet_id, new_status, uom, qty, weight, upload_time, batch_no,
                                               cmt, warehouse_id, labor_batch_no,parent_pallet_id)
                                        VALUES (source_loc, put_rec.dest_loc, trans_id_seq.NEXTVAL,
                                             DECODE(g_erm_rec.erm_type,'TR','TRP','PUT'), r_po.erm_id,
                                             inv_rec.exp_date, inv_rec.mfg_date, SYSDATE, USER,
                                             put_rec.prod_id, put_rec.cust_pref_vendor, put_rec.pallet_id,
                                             DECODE(g_ei_pallet,'Y','AVL',DECODE(put_rec.status,'DMG','DMG',put_rec.inv_status)),
                                             put_rec.uom, put_rec.qty_received, put_rec.weight,
											 
											 /* CRQ39421  Values should be inserted into trans table even if quantity received is zero for host type SAP*/
                                             /*TO_DATE('01-JAN-1980')*/
											 
											 DECODE(put_rec.qty_received,0,SYSDATE,TO_DATE('01-JAN-1980')),
                                             TO_NUMBER(DECODE(g_rf_flag,'Y','99','88')), put_rec.pallet_id,
                                             DECODE(g_erm_rec.erm_type,'TR',g_erm_rec.to_warehouse_id,g_erm_rec.warehouse_id),
                                             put_rec.pallet_batch_no,put_rec.parent_pallet_id);
											 
									END IF; 
										
                                  ELSE
                                  
                    -- SCI003- C ends                              
                                    INSERT INTO trans (src_loc, dest_loc, trans_id, trans_type, rec_id, exp_date,
                                           mfg_date, trans_date, user_id, prod_id, cust_pref_vendor,
                                           pallet_id, new_status, uom, qty, weight, upload_time, batch_no,
                                           cmt, warehouse_id, labor_batch_no,parent_pallet_id)
                                    VALUES (source_loc, put_rec.dest_loc, trans_id_seq.NEXTVAL,
                                         DECODE(g_erm_rec.erm_type,'TR','TRP','PUT'), r_po.erm_id,
                                         inv_rec.exp_date, inv_rec.mfg_date, SYSDATE, USER,
                                         put_rec.prod_id, put_rec.cust_pref_vendor, put_rec.pallet_id,
										 DECODE(g_ei_pallet,'Y','AVL',DECODE(put_rec.status,'DMG','DMG',put_rec.inv_status)),
                                         put_rec.uom, put_rec.qty_received, put_rec.weight,
                                         DECODE(put_rec.status,'DMG',TO_DATE('01-JAN-1980'),SYSDATE),
                                         TO_NUMBER(DECODE(g_rf_flag,'Y','99','88')), put_rec.pallet_id,
                                         DECODE(g_erm_rec.erm_type,'TR',g_erm_rec.to_warehouse_id,g_erm_rec.warehouse_id),
                                         put_rec.pallet_batch_no,put_rec.parent_pallet_id);
                                  END IF;
                                  
                                 EXCEPTION
                                    WHEN OTHERS THEN
                                       g_sqlcode := SQLCODE;
                                       g_err_msg := 'Oracle error inserting into transaction table.';
                                       Pl_Text_Log.ins_msg('WARN',ct_PROGRAM_CODE,g_err_msg,SQLCODE,SQLERRM);
                                       RAISE e_premature_termination;
                                 END;
                            END IF;
                        EXCEPTION

                           WHEN OTHERS THEN
                              g_sqlcode := SQLCODE;
                              g_err_msg := 'ORACLE Unable to select OSD information for SN/PO.'||g_erm_rec.erm_id;
                              Pl_Text_Log.ins_msg('WARN',ct_PROGRAM_CODE,g_err_msg,SQLCODE,SQLERRM);
                              g_server.status := ct_SELECT_ERROR;
                              RAISE e_premature_termination;
                        END;
                    ELSE
                        --acppzp OSD changes end
                        --if no OSD  pallets for SN/PO then
			--existing process is followed

                        BEGIN
						  -- acpvxg 03 FEB 06 
						  -- included parent_pallet_id to following insert into trans.
              ----SCI003-C starts 
                           
                        IF host_type = 'SAP' THEN
                            IF put_rec.qty_received >= 0 THEN
                                INSERT INTO trans (src_loc, dest_loc, trans_id, trans_type, rec_id, exp_date,
                                            mfg_date, trans_date, user_id, prod_id, cust_pref_vendor,
                                            pallet_id, new_status, uom, qty, weight, upload_time, batch_no,
                                            cmt, warehouse_id, labor_batch_no,parent_pallet_id)
                                VALUES (source_loc, put_rec.dest_loc, trans_id_seq.NEXTVAL,
                                          DECODE(g_erm_rec.erm_type,'TR','TRP','PUT'), r_po.erm_id,
                                          inv_rec.exp_date, inv_rec.mfg_date, SYSDATE, USER,
                                          put_rec.prod_id, put_rec.cust_pref_vendor, put_rec.pallet_id,
                                          DECODE(g_ei_pallet,'Y','AVL',put_rec.inv_status), put_rec.uom, put_rec.qty_received, put_rec.weight,
										  
										  /* CRQ39421  Values should be inserted into trans table even if quantity received is zero for host type SAP*/
                                          /*TO_DATE('01-JAN-1980'),*/
										  
										  DECODE(put_rec.qty_received,0,SYSDATE,TO_DATE('01-JAN-1980')),
                                          TO_NUMBER(DECODE(g_rf_flag,'Y','99','88')), put_rec.pallet_id,
                                          DECODE(g_erm_rec.erm_type,'TR',g_erm_rec.to_warehouse_id,g_erm_rec.warehouse_id),
                                          put_rec.pallet_batch_no,put_rec.parent_pallet_id);
							
                     
                            END IF;
                                                      
                        ELSE
                          
                          ----SCI003-C ends             
                           INSERT INTO trans (src_loc, dest_loc, trans_id, trans_type, rec_id, exp_date,
                                        mfg_date, trans_date, user_id, prod_id, cust_pref_vendor,
                                        pallet_id, new_status, uom, qty, weight, upload_time, batch_no,
                                        cmt, warehouse_id, labor_batch_no,parent_pallet_id)
                           VALUES (source_loc, put_rec.dest_loc, trans_id_seq.NEXTVAL,
                                      DECODE(g_erm_rec.erm_type,'TR','TRP','PUT'), r_po.erm_id,
                                      inv_rec.exp_date, inv_rec.mfg_date, SYSDATE, USER,
                                      put_rec.prod_id, put_rec.cust_pref_vendor, put_rec.pallet_id,
                                      DECODE(g_ei_pallet,'Y','AVL',put_rec.inv_status), put_rec.uom, put_rec.qty_received, put_rec.weight,
                                      TO_DATE(put_rec.upload_date,'DD-MON-YYYY'),
                                      TO_NUMBER(DECODE(g_rf_flag,'Y','99','88')), put_rec.pallet_id,
                                      DECODE(g_erm_rec.erm_type,'TR',g_erm_rec.to_warehouse_id,g_erm_rec.warehouse_id),
                                      put_rec.pallet_batch_no,put_rec.parent_pallet_id);
                        END IF;
                        EXCEPTION
                           WHEN OTHERS THEN
                                 g_sqlcode := SQLCODE;
                                 g_err_msg := 'Oracle error inserting into transaction table.';
                                 Pl_Text_Log.ins_msg('WARN',ct_PROGRAM_CODE,g_err_msg,SQLCODE,SQLERRM);
                                 RAISE e_premature_termination;
                        END;
                    END IF;

                  --acppzp OSD changes begin
                  -- IF ITS A DMG pallet a STA transaction is created
		  		  --with upload time as sysdate and OSD reason
                  BEGIN
                    IF put_rec.status ='DMG' THEN
						-- acpvxg 03 FEB 06 
					    -- included parent_pallet_id to following insert into trans.
                        INSERT INTO trans (trans_id, trans_type, user_id, trans_date, prod_id,
                                           cust_pref_vendor, rec_id, reason_code, src_loc, pallet_id,
                                           old_status, new_status, upload_time, qty, cmt, batch_no, uom,
										   parent_pallet_id)
                        VALUES (trans_id_seq.NEXTVAL, 'STA', USER, SYSDATE, put_rec.prod_id,
                                put_rec.cust_pref_vendor, r_po.erm_id,'OSD', put_rec.dest_loc,
                                put_rec.pallet_id, 'AVL', 'HLD',SYSDATE,
                                put_rec.qty_received, 'STA trans for DMG',
                                TO_NUMBER(DECODE(g_rf_flag,'Y','99','88')), put_rec.uom,
								put_rec.parent_pallet_id);
                    END IF;
                  EXCEPTION
                     WHEN OTHERS THEN
                        g_sqlcode := SQLCODE;
                        g_err_msg := 'Oracle error inserting into transaction table.';
                        Pl_Text_Log.ins_msg('WARN',ct_PROGRAM_CODE,g_err_msg,SQLCODE,SQLERRM);
                        RAISE e_premature_termination;
                  END;
                  --acppzp OSD changes end
                  BEGIN
                     IF in_aging = 'Y' AND put_rec.inv_status = 'AVL' THEN
                        put_rec.inv_status := 'HLD';
                     END IF;
                     IF in_aging = 'Y' AND put_rec.inv_status = 'HLD' THEN
                        INSERT INTO trans (trans_id, trans_type, user_id, trans_date, prod_id,
                                           cust_pref_vendor, rec_id, reason_code, src_loc, pallet_id,
                                           old_status, new_status, upload_time, qty, cmt, batch_no, uom)
                        VALUES (trans_id_seq.NEXTVAL, 'STA', USER, SYSDATE, put_rec.prod_id,
                                put_rec.cust_pref_vendor, r_po.erm_id, 'CC', put_rec.dest_loc,
                                put_rec.pallet_id, 'AVL', 'HLD', TO_DATE(put_rec.upload_date,'DD-MON-YYYY'),
                                put_rec.qty_received, 'Aging item status changed to HLD',
                                TO_NUMBER(DECODE(g_rf_flag,'Y','99','88')), put_rec.uom);
                     END IF;
                  EXCEPTION
                     WHEN OTHERS THEN
                        g_sqlcode := SQLCODE;
                        g_err_msg := 'Oracle error inserting into transaction table.';
                        Pl_Text_Log.ins_msg('WARN',ct_PROGRAM_CODE,g_err_msg,SQLCODE,SQLERRM);
                        RAISE e_premature_termination;
                  END;
               END IF;
               Pl_Text_Log.ins_msg('DEBUG',ct_PROGRAM_CODE,'Deciding putaway task fate (' || put_rec.pallet_id || ').',
                  SQLCODE,SQLERRM);
               IF g_putaway_confirm_flag = 'N' OR g_rf_confirm_flag = 'N' OR
                  put_rec.putaway_put = 'Y' OR g_erm_rec.warehouse_id <> '000' OR
                  g_erm_rec.to_warehouse_id <> '000' OR
                  (put_rec.qty_received = 0 AND put_rec.putaway_put <> 'Y') THEN
                  BEGIN
                     -- Delete putawaylst if it is NOT an internal PO
                     --knha8378 remove on OCT 30,2019 because we are not auto close anymore; treat internal PO normal
                     --IF pl_common.f_is_internal_production_po(r_po.erm_id) = FALSE THEN
                        DELETE FROM putawaylst
                        WHERE pallet_id = put_rec.pallet_id;
                     --END IF;
                  EXCEPTION
                     WHEN OTHERS THEN
                        g_sqlcode := SQLCODE;
                        g_err_msg := 'Error deleting putaway tasks for pallet [' || put_rec.pallet_id || '].';
                        Pl_Text_Log.ins_msg('WARN',ct_PROGRAM_CODE,g_err_msg,SQLCODE,SQLERRM);
                        RAISE e_premature_termination;
                  END;
                  float_item_flag := FALSE;
                  Pl_Text_Log.ins_msg('DEBUG',ct_PROGRAM_CODE,'Putaway task=[' || put_rec.pallet_id ||
                     '] deleted.',SQLCODE,SQLERRM);
               END IF;
            END LOOP;
         EXCEPTION
            WHEN e_premature_termination THEN
               RAISE e_premature_termination;
            WHEN OTHERS THEN
               g_sqlcode := SQLCODE;
               g_err_msg := 'ORACLE Error finding putaway tasks for SN/PO.';
               Pl_Text_Log.ins_msg('WARN',ct_PROGRAM_CODE,g_err_msg,SQLCODE,SQLERRM);
               RAISE e_premature_termination;
         END;
      END LOOP;
   EXCEPTION
      WHEN e_premature_termination THEN
         RAISE e_premature_termination;
      WHEN OTHERS THEN
         g_sqlcode := SQLCODE;
         g_err_msg := 'ORACLE Error finding SN/POs to process inventory.';
         Pl_Text_Log.ins_msg('WARN',ct_PROGRAM_CODE,g_err_msg,SQLCODE,SQLERRM);
   END update_inv;
   
    -----------------------------------------------------------------------------
   -- Procedure update_ei_inv
   --   Created for EI PO 
     -----------------------------------------------------------------------------
   
     PROCEDURE update_ei_inv(i_rec_id IN VARCHAR2) IS
      inv_rec inv%ROWTYPE;
      source_loc putawaylst.dest_loc%TYPE;
      front_loc putawaylst.dest_loc%TYPE;
      home_slot_flag BOOLEAN;
      float_item_flag BOOLEAN := FALSE;
      update_flag BOOLEAN;
      home_slot_count NUMBER;
      inv_count NUMBER;
      shelf_life NUMBER;
      in_aging CHAR(1);
      -- SCI003 -C starts - host_type variable

      host_type varchar2(6);

      -- SCI003-C ends

      inv_Osdcount NUMBER :=0;
      inv_OsdreasonCnt NUMBER :=0;

      CURSOR c_po (cp_rec_id VARCHAR2) IS
      SELECT erm_id
        FROM erm
       WHERE po = cp_rec_id;
       -- acpvxg 03 FEB 06
       --  parent_pallet_id added to the cursor.
      CURSOR put_cur (p_po VARCHAR2) IS
      SELECT pallet_id, qty_received, dest_loc, pt.prod_id, pt.cust_pref_vendor, pt.uom,
             putaway_put, mfg_date, date_code, lot_id, lot_trk, exp_date, exp_date_trk, temp,
             temp_trk, clam_bed_trk, inv_status, qty_expected, pt.weight, rec_id,
             TO_CHAR(out_inv_date,'DD-MON-YYYY') out_inv_date,
             DECODE(inv_status,'HLD','01-JAN-1980',
             TO_CHAR(SYSDATE,'DD-MON-YYYY')) upload_date,
             l.perm, pt.status STATUS,
             pt.pallet_batch_no,
             parent_pallet_id
        FROM loc l, putawaylst pt
       WHERE pt.rec_id = p_po
         AND l.logi_loc(+) = pt.dest_loc;

      CURSOR trans_cur (p_pallet_id VARCHAR2) IS
      SELECT dest_loc
        FROM trans
       WHERE pallet_id = p_pallet_id
         AND trans_type IN ('SWP','XFR','HST','RPL','DLD','PUT','IND','DFK');
   BEGIN
      FOR r_po IN c_po (i_rec_id) LOOP
         BEGIN
            FOR put_rec IN put_cur (r_po.erm_id) LOOP
               update_flag := TRUE;
               inv_count := NULL;

               IF put_rec.temp_trk = 'C' THEN
                  inv_rec.temperature := put_rec.temp;
               END IF;

               IF put_rec.lot_trk = 'C' THEN
                  inv_rec.lot_id := put_rec.lot_id;
               END IF;

               IF put_rec.date_code = 'C' THEN
                  inv_rec.mfg_date := put_rec.mfg_date;
               END IF;

               IF put_rec.exp_date_trk = 'C' THEN
                  inv_rec.exp_date := put_rec.exp_date;
               END IF;

               BEGIN
                  SELECT plogi_loc
                    INTO front_loc
                    FROM loc_reference
                   WHERE bck_logi_loc = put_rec.dest_loc;
                  Pl_Text_Log.ins_msg('DEBUG',ct_PROGRAM_CODE,'DEST_LOC='||put_rec.dest_loc||
                     '  FRONT_LOC='||front_loc,SQLCODE,SQLERRM);
                  put_rec.dest_loc := front_loc;
               EXCEPTION
                  WHEN OTHERS THEN
                     Pl_Text_Log.ins_msg('DEBUG',ct_PROGRAM_CODE,
                        'ORACLE No front side location exists for this location.',
                        SQLCODE,SQLERRM);
               END;
               BEGIN
                  SELECT COUNT(*)
                    INTO home_slot_count
                    FROM loc
                   WHERE rank = 1
                     AND perm = 'Y'
                     AND ((put_rec.uom = 1 AND uom IN (0,1))
                      OR (uom IN (0,2)))
                     AND prod_id = put_rec.prod_id
                     AND cust_pref_vendor = put_rec.cust_pref_vendor
                     AND logi_loc = put_rec.dest_loc;
               EXCEPTION
                    WHEN OTHERS THEN
                     g_sqlcode := SQLCODE;
                     g_err_msg := 'Oracle error checking for home slot.';
                     Pl_Text_Log.ins_msg('WARN',ct_PROGRAM_CODE,g_err_msg,SQLCODE,SQLERRM);
                     RAISE e_premature_termination;
               END;
               IF home_slot_count = 0 THEN
                  home_slot_flag := FALSE;
                  g_err_msg := '  Not a home slot: ' || put_rec.dest_loc;
                  Pl_Text_Log.ins_msg('DEBUG',ct_PROGRAM_CODE,g_err_msg,SQLCODE,SQLERRM);
               ELSE
                  home_slot_flag := TRUE;
                  g_err_msg := '  Home slot: ' || put_rec.dest_loc;
                  Pl_Text_Log.ins_msg('DEBUG',ct_PROGRAM_CODE,g_err_msg,SQLCODE,SQLERRM);
               END IF;
               BEGIN
                  SELECT NVL(case_cube,1.0), NVL(spc,1), NVL(sysco_shelf_life,0),
                         NVL(cust_shelf_life,0), NVL(mfr_shelf_life,0)
                    INTO g_pm_rec.case_cube, g_pm_rec.spc, g_pm_rec.sysco_shelf_life,
                         g_pm_rec.cust_shelf_life, g_pm_rec.mfr_shelf_life
                    FROM pm
                   WHERE prod_id = put_rec.prod_id
                     AND cust_pref_vendor = put_rec.cust_pref_vendor;
               EXCEPTION
                  WHEN OTHERS THEN
                     g_sqlcode := SQLCODE;
                     g_err_msg := 'ORACLE Unable to get item information.';
                     Pl_Text_Log.ins_msg('WARN',ct_PROGRAM_CODE,g_err_msg,SQLCODE,SQLERRM);
                     g_server.status := ct_INV_PRODID;
                     RAISE e_premature_termination;
               END;
                      inv_rec := NULL;
               IF put_rec.qty_received > 0 THEN
                  IF NOT home_slot_flag THEN
                     IF put_rec.putaway_put = 'Y' THEN
                        IF g_erm_rec.erm_type = 'TR' THEN
                           inv_rec.inv_date := TO_DATE(put_rec.out_inv_date,'DD-MON-YYYY');
                           inv_rec.rec_date := TO_DATE(put_rec.out_inv_date,'DD-MON-YYYY');
                        END IF;
                        SELECT COUNT(*)
                          INTO inv_count
                          FROM inv
                         WHERE logi_loc = put_rec.pallet_id
                           AND prod_id = put_rec.prod_id;
                        IF inv_count = 0 THEN
                          BEGIN
/*
                              SELECT plogi_loc
                                INTO put_rec.dest_loc
                                FROM inv
                               WHERE prod_id = put_rec.prod_id
                                 AND plogi_loc = logi_loc
                                 AND EXISTS (SELECT '1'
                                               FROM loc
                                              WHERE loc.logi_loc = inv.plogi_loc
                                                AND loc.uom IN (0,2))
                                 AND ROWNUM < 2;
*/
                              SELECT dest_loc
                                INTO put_rec.dest_loc
                                FROM trans
                               WHERE trans_date = (SELECT MAX(trans_date) FROM trans
                                                    WHERE pallet_id = put_rec.pallet_id
                                                      AND trans_type IN ('SWP','XFR','HST','RPL','DLD','PUT','IND','DFK')
                                                      AND dest_loc IS NOT NULL
                                                      AND user_id <> 'ORDER')
                                 AND pallet_id = put_rec.pallet_id
                                 AND trans_type IN ('SWP','XFR','HST','RPL','DLD','PUT','IND','DFK')
                                 AND user_id <> 'ORDER'
                                 AND ROWNUM = 1;

                            EXCEPTION
                               WHEN NO_DATA_FOUND THEN
                                  g_err_msg := 'ORACLE Error finding inventory record for putaway task. Pallet='||
                                       put_rec.pallet_id;
                                 Pl_Text_Log.ins_msg('WARN',ct_PROGRAM_CODE,g_err_msg,SQLCODE,SQLERRM);
                                 update_flag := FALSE;
                                 float_item_flag := TRUE;
                           END;
                        END IF;
                     ELSE /* put_rec.putaway_put = 'N' */
                        --
                        -- 03/14/2017  Brian Bent
                        -- Live Receiving
                        -- Change
                        --    IF put_rec.dest_loc = '*' THEN
                        -- to
                        --    IF (put_rec.dest_loc IN ('*', 'LR')) THEN
                        --
                        IF (put_rec.dest_loc IN ('*', 'LR')) THEN
                          g_err_msg := 'Item ' || put_rec.prod_id || ' pallet ' || put_rec.pallet_id ||
                                           ' not assigned a slot. Destination location is ' || put_rec.dest_loc || '.';
                          Pl_Text_Log.ins_msg('WARN',ct_PROGRAM_CODE,g_err_msg,0,'');
                          g_server.status := ct_INV_DEST_LOC;
                          RAISE e_premature_termination;
                        END IF;
                        inv_rec.qoh := put_rec.qty_received;
                        inv_rec.qty_planned := put_rec.qty_expected;
                        IF g_erm_rec.erm_type = 'TR' THEN
                           inv_rec.inv_date := TO_DATE(put_rec.out_inv_date,'DD-MON-YYYY');
                           inv_rec.rec_date := TO_DATE(put_rec.out_inv_date,'DD-MON-YYYY');
                        ELSE
                           inv_rec.inv_date := SYSDATE;
                           inv_rec.rec_date := SYSDATE;
                        END IF;
                        inv_rec.weight := put_rec.weight;
                        inv_rec.rec_id := r_po.erm_id;
                        inv_rec.status := put_rec.inv_status;
                        inv_rec.CUBE := ((put_rec.qty_received - put_rec.qty_expected) /
                           g_pm_rec.spc) * g_pm_rec.case_cube;
                        inv_rec.exp_date := put_rec.exp_date;
                        inv_rec.lot_id := put_rec.lot_id;
                        inv_rec.temperature := put_rec.temp;
                     END IF; /* put_rec.putaway_put = Y|N */
                     IF NOT float_item_flag THEN
                        IF put_rec.temp_trk = 'C' THEN
                           inv_rec.temperature := put_rec.temp;
                        END IF;
                        IF put_rec.lot_trk = 'C' THEN
                           inv_rec.lot_id := put_rec.lot_id;
                        END IF;
                        inv_rec.exp_ind := 'Y';
                        IF put_rec.date_code = 'C' THEN
                           inv_rec.mfg_date := put_rec.mfg_date;
                           inv_rec.exp_date := put_rec.exp_date;
                        ELSIF put_rec.exp_date_trk = 'C' THEN
                           inv_rec.exp_date := put_rec.exp_date;
                        ELSE
                           IF g_pm_rec.sysco_shelf_life <> 0 AND g_pm_rec.cust_shelf_life <> 0 THEN
                              shelf_life := g_pm_rec.sysco_shelf_life + g_pm_rec.cust_shelf_life;
                           ELSIF g_pm_rec.mfr_shelf_life <> 0 THEN
                              shelf_life := g_pm_rec.mfr_shelf_life;
                           ELSE
                              shelf_life := 0;
                           END IF;
                           inv_rec.exp_date := SYSDATE + shelf_life;
                        END IF;
                        inv_rec.exp_ind := 'N';
                     END IF; /* Not float item */
                  ELSE /* Float item */
                     IF put_rec.putaway_put <> 'Y' THEN
                        inv_rec.qoh := put_rec.qty_received;
                        inv_rec.qty_planned := put_rec.qty_expected;
                        IF g_erm_rec.erm_type = 'TR' THEN
                           inv_rec.inv_date := TO_DATE(put_rec.out_inv_date,'DD-MON-YYYY');
                           inv_rec.rec_date := TO_DATE(put_rec.out_inv_date,'DD-MON-YYYY');
                        ELSE
                           inv_rec.inv_date := SYSDATE;
                           inv_rec.rec_date := SYSDATE;
                        END IF;
                        inv_rec.rec_id := r_po.erm_id;
                        inv_rec.status := put_rec.inv_status;
                        inv_rec.CUBE := ((put_rec.qty_received - put_rec.qty_expected) /
                           g_pm_rec.spc) * g_pm_rec.case_cube;
                     END IF;

                     IF put_rec.temp_trk = 'C' THEN
                        inv_rec.temperature := put_rec.temp;
                     END IF;

                     IF put_rec.lot_trk = 'C' THEN
                        inv_rec.lot_id := put_rec.lot_id;
                     END IF;

                     inv_rec.exp_ind := 'Y';

                     IF put_rec.date_code = 'C' THEN
                        inv_rec.mfg_date := put_rec.mfg_date;
                        inv_rec.exp_date := put_rec.exp_date;
                     ELSIF put_rec.exp_date_trk = 'C' THEN
                        inv_rec.exp_date := put_rec.exp_date;
                     ELSE
                        IF g_pm_rec.sysco_shelf_life <> 0 AND g_pm_rec.cust_shelf_life <> 0 THEN
                           shelf_life := g_pm_rec.sysco_shelf_life + g_pm_rec.cust_shelf_life;
                        ELSIF g_pm_rec.mfr_shelf_life <> 0 THEN
                           shelf_life := g_pm_rec.mfr_shelf_life;
                        ELSE
                           shelf_life := 0;
                        END IF;
                        inv_rec.exp_date := SYSDATE + shelf_life;
                     END IF;
                  END IF;
                  inv_rec.exp_ind := 'N';
               ELSIF put_rec.qty_received = 0 THEN
                  IF put_rec.putaway_put <> 'Y' THEN
                     --
                     -- 03/14/2017  Brian Bent
                     -- Live Receiving
                     -- Change
                     --    IF put_rec.dest_loc <> '*' THEN
                     -- to
                     --    IF put_rec.dest_loc NOT IN ('*', 'LR')
                     --
                     IF put_rec.dest_loc NOT IN ('*', 'LR') THEN
                        IF NOT home_slot_flag THEN
                           update_flag := FALSE;
                           BEGIN
                              DELETE FROM inv
                               WHERE logi_loc = put_rec.pallet_id
                                 AND plogi_loc = put_rec.dest_loc;
                           EXCEPTION
                              WHEN OTHERS THEN
                                 g_sqlcode := SQLCODE;
                                 g_err_msg := 'Oracle error deleting from inventory.';
                                 Pl_Text_Log.ins_msg('WARN',ct_PROGRAM_CODE,g_err_msg,SQLCODE,SQLERRM);
                                 RAISE e_premature_termination;
                           END;
                        ELSE
                           inv_rec.qoh := put_rec.qty_received;
                           inv_rec.qty_planned := put_rec.qty_expected;
                           inv_rec.CUBE := (put_rec.qty_expected / g_pm_rec.spc) * g_pm_rec.case_cube;
                        END IF;
                     END IF;
                  END IF;
               END IF;
               IF update_flag THEN
                    BEGIN
                     IF put_rec.putaway_put = 'N' THEN
                        UPDATE inv
                           SET inv_date = NVL(inv_rec.inv_date,inv_date),
                               rec_date = NVL(inv_rec.inv_date,inv_date),
                               exp_date = NVL(inv_rec.exp_date,exp_date),
                               mfg_date = NVL(inv_rec.mfg_date,mfg_date),
                               qoh = qoh + DECODE(put_rec.putaway_put, 'Y', 0, NVL(inv_rec.qoh,0)),
                                  qty_planned = DECODE(inv_rec.qty_planned,NULL,qty_planned,
                                  DECODE(SIGN(qty_planned-inv_rec.qty_planned),1,
                                  qty_planned-inv_rec.qty_planned,-1,0,0)),
                               weight = NVL(inv_rec.weight,weight),
                               rec_id = NVL(inv_rec.rec_id,rec_id),
                               status = NVL(inv_rec.status,status),
                               lot_id = NVL(inv_rec.lot_id,lot_id),
                               temperature = NVL(inv_rec.temperature,temperature),
                               CUBE = CUBE + NVL(inv_rec.CUBE,0)
                         WHERE plogi_loc = put_rec.dest_loc
                           AND prod_id = put_rec.prod_id
                           AND (logi_loc = plogi_loc OR logi_loc = put_rec.pallet_id);
                        g_err_msg := 'Dest Loc INV Update #1 - Key=[' || put_rec.dest_loc || '] : ' ||
                           TO_CHAR(SQL%ROWCOUNT) || ' record(s) updated';
                        Pl_Text_Log.ins_msg('WARN',ct_PROGRAM_CODE,g_err_msg,SQLCODE,SQLERRM);
                     ELSIF NVL(inv_count,0) > 0 THEN
                        UPDATE inv
                           SET inv_date = NVL(inv_rec.inv_date,inv_date),
                               rec_date = NVL(inv_rec.inv_date,inv_date),
                               exp_date = NVL(inv_rec.exp_date,exp_date),
                               mfg_date = NVL(inv_rec.mfg_date,mfg_date),
                               weight = NVL(inv_rec.weight,weight),
                               rec_id = NVL(inv_rec.rec_id,rec_id),
                               status = NVL(inv_rec.status,status),
                               lot_id = NVL(inv_rec.lot_id,lot_id),
                               temperature = NVL(inv_rec.temperature,temperature),
                               CUBE = CUBE + NVL(inv_rec.CUBE,0)
                         WHERE logi_loc = put_rec.pallet_id;
                        g_err_msg := 'Pallet ID INV Update #2 - Key=[' || put_rec.pallet_id || '] : ' ||
                          TO_CHAR(SQL%ROWCOUNT) || ' record(s) updated';
                        Pl_Text_Log.ins_msg('WARN',ct_PROGRAM_CODE,g_err_msg,SQLCODE,SQLERRM);
                     ELSE
                        UPDATE inv
                           SET inv_date = NVL(inv_rec.inv_date,inv_date),
                               rec_date = NVL(inv_rec.inv_date,inv_date),
                               exp_date = NVL(inv_rec.exp_date,exp_date),
                               mfg_date = NVL(inv_rec.mfg_date,mfg_date),
                               weight = NVL(inv_rec.weight,weight),
                               rec_id = NVL(inv_rec.rec_id,rec_id),
                               status = NVL(inv_rec.status,status),
                               lot_id = NVL(inv_rec.lot_id,lot_id),
                               temperature = NVL(inv_rec.temperature,temperature),
                               CUBE = CUBE + NVL(inv_rec.CUBE,0)
                         WHERE prod_id = put_rec.prod_id
                            AND plogi_loc = logi_loc
                            AND EXISTS (SELECT '1' FROM loc
                                         WHERE loc.logi_loc = inv.plogi_loc
                                           AND loc.uom IN (0,2));
                        g_err_msg := 'Home Slot INV Update #3 - Key=[' || put_rec.prod_id || '] : ' ||
                          TO_CHAR(SQL%ROWCOUNT) || ' record(s) updated';
                        Pl_Text_Log.ins_msg('WARN',ct_PROGRAM_CODE,g_err_msg,SQLCODE,SQLERRM);
                     END IF;

                    FOR trans_rec IN trans_cur (put_rec.pallet_id) LOOP
                       UPDATE inv
                          SET exp_date = inv_rec.exp_date,
                              mfg_date = inv_rec.mfg_date
                        WHERE logi_loc = put_rec.pallet_id
                           OR (prod_id = put_rec.prod_id
                          AND  plogi_loc = trans_rec.dest_loc
                          AND  plogi_loc = logi_loc);
                    END LOOP;

                    EXCEPTION
                     WHEN OTHERS THEN
                        g_sqlcode := SQLCODE;
                        g_err_msg := 'Oracle error updating inventory. ' || TO_CHAR(SQLCODE);
                        Pl_Text_Log.ins_msg('WARN',ct_PROGRAM_CODE,g_err_msg,SQLCODE,SQLERRM);
                        RAISE e_premature_termination;
                    END;
               END IF;
               IF put_rec.putaway_put <> 'Y' THEN
                  BEGIN
                     IF NOT home_slot_flag THEN
                        SELECT mfg_date, exp_date
                          INTO inv_rec.mfg_date, inv_rec.exp_date
                          FROM inv
                         WHERE plogi_loc = put_rec.dest_loc
                           AND logi_loc = put_rec.pallet_id;
                     ELSE
                        SELECT mfg_date, exp_date
                          INTO inv_rec.mfg_date, inv_rec.exp_date
                          FROM inv
                         WHERE plogi_loc = put_rec.dest_loc
                           AND logi_loc = put_rec.dest_loc;
                     END IF;
                  EXCEPTION
                     WHEN OTHERS THEN
                        g_err_msg := 'Error finding inventory for [' ||put_rec.pallet_id || '].';
                        Pl_Text_Log.ins_msg('WARN',ct_PROGRAM_CODE,g_err_msg,SQLCODE,SQLERRM);
                  END;
                  source_loc := f_get_haul_location(put_rec.pallet_id);
                  in_aging := 'N';
                  IF source_loc IS NULL THEN
                     source_loc := g_erm_rec.door_no;
                  END IF;
                  IF g_erm_rec.warehouse_id <> '000' OR g_erm_rec.to_warehouse_id <> '000' THEN
                     put_rec.upload_date := '01-JAN-1980';
                  END IF;
                  IF put_rec.inv_status = 'HLD' THEN
                     BEGIN
                        SELECT 'Y'
                          INTO in_aging
                          FROM aging_items
                         WHERE prod_id = put_rec.prod_id
                           AND cust_pref_vendor = put_rec.cust_pref_vendor;
                        put_rec.inv_status := 'AVL';
                     EXCEPTION
                        WHEN NO_DATA_FOUND THEN
                           in_aging := 'N';
                     END;
                  END IF;
                  --acppzp OSD changes begin
                  --check if any damaged pallet exists for SN/PO
                  inv_Osdcount :=0;
                  IF gv_osd_sys_flag  = 'Y' THEN
                     BEGIN

                        SELECT  COUNT(*)
                        INTO  inv_Osdcount
                        FROM OSD o,putawaylst p
                        WHERE   p.rec_id = g_erm_rec.erm_id
                        AND o.orig_pallet_id = p.pallet_id;

                      EXCEPTION
                        WHEN OTHERS THEN
                           g_sqlcode := SQLCODE;
                           g_err_msg := 'ORACLE unable to select OSD information for SN/PO.'||g_erm_rec.erm_id;
                           Pl_Text_Log.ins_msg('WARN',ct_PROGRAM_CODE,g_err_msg,SQLCODE,SQLERRM);
                           g_server.status := ct_SELECT_ERROR;
                           RAISE e_premature_termination;
                      END;
                   END IF;
                   --SCI003-C starts
                              -- retreive host_type value from sys_config table

                                BEGIN
                                    select config_flag_val
                                    INTO host_type
                                    FROM sys_config
                                    WHERE config_flag_name='HOST_TYPE';

                                END;
                    --- SCI003-C ends
                   IF inv_Osdcount > 0 THEN
               --check if any pallet exists for
               --SN/PO for which reason code has not
               --been updated
                        BEGIN

                              SELECT   COUNT(*)
                              INTO  inv_OsdreasonCnt
                              FROM OSD o,putawaylst p
                              WHERE   p.rec_id = g_erm_rec.erm_id
                              AND o.orig_pallet_id =  p.pallet_id
                              AND  o.reason_code IN ('SSS','OOO','DDD');




                             IF inv_OsdreasonCnt >0 THEN
        --if reason codes for all OSD pallets for SN/PO not updated then
        --all PUTs to be sent to SUS hence insertion with SYSDATE
                              BEGIN
                              -- acpvxg 03 FEB 06
                              -- included parent_pallet_id to following insert into trans.

                                 INSERT INTO trans (src_loc, dest_loc, trans_id, trans_type, rec_id, exp_date,
                                           mfg_date, trans_date, user_id, prod_id, cust_pref_vendor,
                                           pallet_id, new_status, uom, qty, weight, upload_time, batch_no,
                                           cmt, warehouse_id,
                                           labor_batch_no,parent_pallet_id)
                                 VALUES (source_loc, put_rec.dest_loc, trans_id_seq.NEXTVAL,
                                         DECODE(g_erm_rec.erm_type,'TR','TRP','PUT'), r_po.erm_id,
                                         inv_rec.exp_date, inv_rec.mfg_date, SYSDATE, USER,
                                         put_rec.prod_id, put_rec.cust_pref_vendor, put_rec.pallet_id,
                                         DECODE(g_ei_pallet,'Y','AVL',DECODE(put_rec.status,'DMG','DMG',put_rec.inv_status)),
                                         put_rec.uom, put_rec.qty_received, put_rec.weight,
                                         TO_DATE('01-JAN-1980'),
                                         TO_NUMBER(DECODE(g_rf_flag,'Y','99','88')), put_rec.pallet_id,
                                         DECODE(g_erm_rec.erm_type,'TR',g_erm_rec.to_warehouse_id,g_erm_rec.warehouse_id),
                                         put_rec.pallet_batch_no,put_rec.parent_pallet_id);
                              EXCEPTION
                                 WHEN OTHERS THEN
                                    g_sqlcode := SQLCODE;
                                    g_err_msg := 'Oracle error inserting into transaction table.';
                                    Pl_Text_Log.ins_msg('WARN',ct_PROGRAM_CODE,g_err_msg,SQLCODE,SQLERRM);
                                    RAISE e_premature_termination;
                              END;
                            ELSE
                                 -- for all PROPER reason codes
                 --in place for SN/PO
                                 --if the inv_status for the pallet is
                 --DMG in putawaylst ie damaged pallet
                                 --then PUT needs to be sent to SUS
                 --hence inserted with SYSDATE
                                 --if pallet is not damaged PUT
                 --not to be sent to SUS hence inserted
                                 --with the old date
                               BEGIN
                               -- acpvxg 03 FEB 06
                               -- included parent_pallet_id to following insert into trans.
 --SCI003-C starts
                          -- if no OSD pallets for SN/PO exists send the data to SAP

                                  IF host_type = 'SAP' THEN

                                    IF put_rec.qty_received >= 0 THEN
                                        INSERT INTO trans (src_loc, dest_loc, trans_id, trans_type, rec_id, exp_date,
                                               mfg_date, trans_date, user_id, prod_id, cust_pref_vendor,
                                               pallet_id, new_status, uom, qty, weight, upload_time, batch_no,
                                               cmt, warehouse_id, labor_batch_no,parent_pallet_id)
                                        VALUES (source_loc, put_rec.dest_loc, trans_id_seq.NEXTVAL,
                                             DECODE(g_erm_rec.erm_type,'TR','TRP','PUT'), r_po.erm_id,
                                             inv_rec.exp_date, inv_rec.mfg_date, SYSDATE, USER,
                                             put_rec.prod_id, put_rec.cust_pref_vendor, put_rec.pallet_id,
                                             DECODE(g_ei_pallet,'Y','AVL',DECODE(put_rec.status,'DMG','DMG',put_rec.inv_status)),
                                             put_rec.uom, put_rec.qty_received, put_rec.weight,

                                             /* CRQ39421  Values should be inserted into trans table even if quantity received is zero for host type SAP*/
                                             /*TO_DATE('01-JAN-1980')*/

                                             DECODE(put_rec.qty_received,0,SYSDATE,TO_DATE('01-JAN-1980')),
                                             TO_NUMBER(DECODE(g_rf_flag,'Y','99','88')), put_rec.pallet_id,
                                             DECODE(g_erm_rec.erm_type,'TR',g_erm_rec.to_warehouse_id,g_erm_rec.warehouse_id),
                                             put_rec.pallet_batch_no,put_rec.parent_pallet_id);

                                    END IF;

                                  ELSE

                    -- SCI003- C ends
                                    INSERT INTO trans (src_loc, dest_loc, trans_id, trans_type, rec_id, exp_date,
                                           mfg_date, trans_date, user_id, prod_id, cust_pref_vendor,
                                           pallet_id, new_status, uom, qty, weight, upload_time, batch_no,
                                           cmt, warehouse_id, labor_batch_no,parent_pallet_id)
                                    VALUES (source_loc, put_rec.dest_loc, trans_id_seq.NEXTVAL,
                                         DECODE(g_erm_rec.erm_type,'TR','TRP','PUT'), r_po.erm_id,
                                         inv_rec.exp_date, inv_rec.mfg_date, SYSDATE, USER,
                                         put_rec.prod_id, put_rec.cust_pref_vendor, put_rec.pallet_id,
                                         DECODE(g_ei_pallet,'Y','AVL',DECODE(put_rec.status,'DMG','DMG',put_rec.inv_status)),
                                         put_rec.uom, put_rec.qty_received, put_rec.weight,
                                         DECODE(put_rec.status,'DMG',TO_DATE('01-JAN-1980'),SYSDATE),
                                         TO_NUMBER(DECODE(g_rf_flag,'Y','99','88')), put_rec.pallet_id,
                                         DECODE(g_erm_rec.erm_type,'TR',g_erm_rec.to_warehouse_id,g_erm_rec.warehouse_id),
                                         put_rec.pallet_batch_no,put_rec.parent_pallet_id);
                                  END IF;

                                 EXCEPTION
                                    WHEN OTHERS THEN
                                       g_sqlcode := SQLCODE;
                                       g_err_msg := 'Oracle error inserting into transaction table.';
                                       Pl_Text_Log.ins_msg('WARN',ct_PROGRAM_CODE,g_err_msg,SQLCODE,SQLERRM);
                                       RAISE e_premature_termination;
                                 END;
                            END IF;
                        EXCEPTION

                           WHEN OTHERS THEN
                              g_sqlcode := SQLCODE;
                              g_err_msg := 'ORACLE Unable to select OSD information for SN/PO.'||g_erm_rec.erm_id;
                              Pl_Text_Log.ins_msg('WARN',ct_PROGRAM_CODE,g_err_msg,SQLCODE,SQLERRM);
                              g_server.status := ct_SELECT_ERROR;
                              RAISE e_premature_termination;
                        END;
                    ELSE
                        --acppzp OSD changes end
                        --if no OSD  pallets for SN/PO then
            --existing process is followed

                        BEGIN
                          -- acpvxg 03 FEB 06
                          -- included parent_pallet_id to following insert into trans.
              ----SCI003-C starts

                        IF host_type = 'SAP' THEN
                            IF put_rec.qty_received >= 0 THEN
                                INSERT INTO trans (src_loc, dest_loc, trans_id, trans_type, rec_id, exp_date,
                                            mfg_date, trans_date, user_id, prod_id, cust_pref_vendor,
                                            pallet_id, new_status, uom, qty, weight, upload_time, batch_no,
                                            cmt, warehouse_id, labor_batch_no,parent_pallet_id)
                                VALUES (source_loc, put_rec.dest_loc, trans_id_seq.NEXTVAL,
                                          DECODE(g_erm_rec.erm_type,'TR','TRP','PUT'), r_po.erm_id,
                                          inv_rec.exp_date, inv_rec.mfg_date, SYSDATE, USER,
                                          put_rec.prod_id, put_rec.cust_pref_vendor, put_rec.pallet_id,
                                          DECODE(g_ei_pallet,'Y','AVL',put_rec.inv_status), put_rec.uom, put_rec.qty_received, put_rec.weight,

                                          /* CRQ39421  Values should be inserted into trans table even if quantity received is zero for host type SAP*/
                                          /*TO_DATE('01-JAN-1980'),*/

                                          DECODE(put_rec.qty_received,0,SYSDATE,TO_DATE('01-JAN-1980')),
                                          TO_NUMBER(DECODE(g_rf_flag,'Y','99','88')), put_rec.pallet_id,
                                          DECODE(g_erm_rec.erm_type,'TR',g_erm_rec.to_warehouse_id,g_erm_rec.warehouse_id),
                                          put_rec.pallet_batch_no,put_rec.parent_pallet_id);


                            END IF;

                        ELSE

                          ----SCI003-C ends
                           INSERT INTO trans (src_loc, dest_loc, trans_id, trans_type, rec_id, exp_date,
                                        mfg_date, trans_date, user_id, prod_id, cust_pref_vendor,
                                        pallet_id, new_status, uom, qty, weight, upload_time, batch_no,
                                        cmt, warehouse_id, labor_batch_no,parent_pallet_id)
                           VALUES (source_loc, put_rec.dest_loc, trans_id_seq.NEXTVAL,
                                      DECODE(g_erm_rec.erm_type,'TR','TRP','PUT'), r_po.erm_id,
                                      inv_rec.exp_date, inv_rec.mfg_date, SYSDATE, USER,
                                      put_rec.prod_id, put_rec.cust_pref_vendor, put_rec.pallet_id,
                                      DECODE(g_ei_pallet,'Y','AVL',put_rec.inv_status), put_rec.uom, put_rec.qty_received, put_rec.weight,
                                      TO_DATE(put_rec.upload_date,'DD-MON-YYYY'),
                                      TO_NUMBER(DECODE(g_rf_flag,'Y','99','88')), put_rec.pallet_id,
                                      DECODE(g_erm_rec.erm_type,'TR',g_erm_rec.to_warehouse_id,g_erm_rec.warehouse_id),
                                      put_rec.pallet_batch_no,put_rec.parent_pallet_id);
                        END IF;
                        EXCEPTION
                           WHEN OTHERS THEN
                                 g_sqlcode := SQLCODE;
                                 g_err_msg := 'Oracle error inserting into transaction table.';
                                 Pl_Text_Log.ins_msg('WARN',ct_PROGRAM_CODE,g_err_msg,SQLCODE,SQLERRM);
                                 RAISE e_premature_termination;
                        END;
                    END IF;

                  --acppzp OSD changes begin
                  -- IF ITS A DMG pallet a STA transaction is created
                    --with upload time as sysdate and OSD reason
                  BEGIN
                    IF put_rec.status ='DMG' THEN
                        -- acpvxg 03 FEB 06
                        -- included parent_pallet_id to following insert into trans.
                        INSERT INTO trans (trans_id, trans_type, user_id, trans_date, prod_id,
                                           cust_pref_vendor, rec_id, reason_code, src_loc, pallet_id,
                                           old_status, new_status, upload_time, qty, cmt, batch_no, uom,
                                           parent_pallet_id)
                        VALUES (trans_id_seq.NEXTVAL, 'STA', USER, SYSDATE, put_rec.prod_id,
                                put_rec.cust_pref_vendor, r_po.erm_id,'OSD', put_rec.dest_loc,
                                put_rec.pallet_id, 'AVL', 'HLD',SYSDATE,
                                put_rec.qty_received, 'STA trans for DMG',
                                TO_NUMBER(DECODE(g_rf_flag,'Y','99','88')), put_rec.uom,
                                put_rec.parent_pallet_id);
                    END IF;
                  EXCEPTION
                     WHEN OTHERS THEN
                        g_sqlcode := SQLCODE;
                        g_err_msg := 'Oracle error inserting into transaction table.';
                        Pl_Text_Log.ins_msg('WARN',ct_PROGRAM_CODE,g_err_msg,SQLCODE,SQLERRM);
                        RAISE e_premature_termination;
                  END;
                  --acppzp OSD changes end
                  BEGIN
                     IF in_aging = 'Y' AND put_rec.inv_status = 'AVL' THEN
                        put_rec.inv_status := 'HLD';
                     END IF;
                     IF in_aging = 'Y' AND put_rec.inv_status = 'HLD' THEN
                        INSERT INTO trans (trans_id, trans_type, user_id, trans_date, prod_id,
                                           cust_pref_vendor, rec_id, reason_code, src_loc, pallet_id,
                                           old_status, new_status, upload_time, qty, cmt, batch_no, uom)
                        VALUES (trans_id_seq.NEXTVAL, 'STA', USER, SYSDATE, put_rec.prod_id,
                                put_rec.cust_pref_vendor, r_po.erm_id, 'CC', put_rec.dest_loc,
                                put_rec.pallet_id, 'AVL', 'HLD', TO_DATE(put_rec.upload_date,'DD-MON-YYYY'),
                                put_rec.qty_received, 'Aging item status changed to HLD',
                                TO_NUMBER(DECODE(g_rf_flag,'Y','99','88')), put_rec.uom);
                     END IF;
                  EXCEPTION
                     WHEN OTHERS THEN
                        g_sqlcode := SQLCODE;
                        g_err_msg := 'Oracle error inserting into transaction table.';
                        Pl_Text_Log.ins_msg('WARN',ct_PROGRAM_CODE,g_err_msg,SQLCODE,SQLERRM);
                        RAISE e_premature_termination;
                  END;
               END IF;
               Pl_Text_Log.ins_msg('DEBUG',ct_PROGRAM_CODE,'Deciding putaway task fate (' || put_rec.pallet_id || ').',
                  SQLCODE,SQLERRM);
               IF g_putaway_confirm_flag = 'N' OR g_rf_confirm_flag = 'N' OR
                  put_rec.putaway_put = 'Y' OR g_erm_rec.warehouse_id <> '000' OR
                  g_erm_rec.to_warehouse_id <> '000' OR
                  (put_rec.qty_received = 0 AND put_rec.putaway_put <> 'Y') THEN
                  BEGIN
                     DELETE FROM putawaylst
                      WHERE pallet_id = put_rec.pallet_id;
                  EXCEPTION
                     WHEN OTHERS THEN
                        g_sqlcode := SQLCODE;
                        g_err_msg := 'Error deleting putaway tasks for pallet [' || put_rec.pallet_id || '].';
                        Pl_Text_Log.ins_msg('WARN',ct_PROGRAM_CODE,g_err_msg,SQLCODE,SQLERRM);
                        RAISE e_premature_termination;
                  END;
                  float_item_flag := FALSE;
                  Pl_Text_Log.ins_msg('DEBUG',ct_PROGRAM_CODE,'Putaway task=[' || put_rec.pallet_id ||
                     '] deleted.',SQLCODE,SQLERRM);
               END IF;
            END LOOP;
         EXCEPTION
            WHEN e_premature_termination THEN
               RAISE e_premature_termination;
            WHEN OTHERS THEN
               g_sqlcode := SQLCODE;
               g_err_msg := 'ORACLE Error finding putaway tasks for SN/PO.';
               Pl_Text_Log.ins_msg('WARN',ct_PROGRAM_CODE,g_err_msg,SQLCODE,SQLERRM);
               RAISE e_premature_termination;
         END;
      END LOOP;
   EXCEPTION
      WHEN e_premature_termination THEN
         RAISE e_premature_termination;
      WHEN OTHERS THEN
         g_sqlcode := SQLCODE;
         g_err_msg := 'ORACLE Error finding SN/POs to process inventory.';
         Pl_Text_Log.ins_msg('WARN',ct_PROGRAM_CODE,g_err_msg,SQLCODE,SQLERRM);
   END update_ei_inv;
   
   -----------------------------------------------------------------------------
   -- Procedure close_po
   --   Update PO to Closed and record event in transaction table.
   -----------------------------------------------------------------------------
   PROCEDURE close_po(i_rec_id IN VARCHAR2) IS
      l_name_start NUMBER := 1;
      l_name_end NUMBER;
      l_qty_start NUMBER := 1;
      l_qty_end NUMBER;
      l_count NUMBER := 1;
      l_supplier_name VARCHAR2(50) := null;
      l_supplier_qty NUMBER;
      l_dummy   VARCHAR2(1);
      inv_OSDcntNo NUMBER;
      l_erm_status VARCHAR2(3);
	  host_type1 varchar2(6); /*CRQ45458 inserting maint_flag value as 'Y' for SAP*/
	  -- Added for Special Pallet BLUE-CHEP tracking
	  l_vendor_id            VARCHAR2(10); 
	  l_vendor_name          VARCHAR2(30);     
	  l_load_no              VARCHAR2(12);
	  l_rec_date			 DATE;
     l_enable_finish_goods sys_config.config_flag_val%TYPE;
     l_internal_po_YN           VARCHAR2(1);
     l_count_inv_delete		NUMBER := 0;
   BEGIN
      LOOP
         FETCH c_po_lock INTO g_erm_rec.erm_id;
         EXIT WHEN c_po_lock%NOTFOUND;

  --acppzp  DO105 Changes for OSD check if any osd record without proper
  -- reason code exist and check if the  osd reason flag is set
            BEGIN
               inv_OSDcntNo :=0;
               IF gv_osd_sys_flag  = 'Y' THEN
                 BEGIN
                    SELECT    COUNT(*)
                    INTO   inv_OSDcntNo
                     FROM OSD o,putawaylst p
                     WHERE   p.rec_id = g_erm_rec.erm_id
                     AND o.orig_pallet_id =  p.pallet_id
                     AND  o.reason_code IN ('SSS','OOO','DDD');

                 EXCEPTION
                    WHEN NO_DATA_FOUND THEN
                       inv_OSDcntNo :=0;
                    WHEN OTHERS THEN
                       g_sqlcode := SQLCODE;
                       g_err_msg := 'ORACLE Unable to select OSD information for SN/PO.'||g_erm_rec.erm_id;
                       Pl_Text_Log.ins_msg('WARN',ct_PROGRAM_CODE,g_err_msg,SQLCODE,SQLERRM);
                       g_server.status := ct_SELECT_ERROR;
                       RAISE e_premature_termination;
                   END;
               END IF;

   --acppzp  if reason codes not there for SN/PO then
   --PO/SN is put in pending state
               IF inv_OSDcntNo > 0 THEN
                  BEGIN
                     UPDATE erm
                     SET status = 'PND',
                     close_date = SYSDATE
                     WHERE CURRENT OF c_po_lock;
                     g_exit_msg := 'OSD reason codes are not finalized. SN/PO can only be in pending status, not close status';
                     
                     BEGIN
                       INSERT INTO trans (trans_id, trans_type, rec_id, trans_date, user_id, upload_time,
                                         batch_no, warehouse_id)
                       VALUES (trans_id_seq.NEXTVAL, 'PND', i_rec_id,
                              SYSDATE, USER, TO_DATE('01-JAN-1980','FXDD-MON-YYYY'),
                              TO_NUMBER(DECODE(g_rf_flag,'Y','99','88')),
                              DECODE(g_erm_rec.erm_type,'TR',g_erm_rec.to_warehouse_id,g_erm_rec.warehouse_id));
                       Pl_Text_Log.ins_msg('WARN',ct_PROGRAM_CODE,'PND transaction created for SN '||i_rec_id||'.',SQLCODE,SQLERRM);
                     EXCEPTION
                       WHEN OTHERS THEN
                          g_sqlcode := SQLCODE;
                          g_err_msg := 'ORACLE Unable to create PND transaction.';
                          Pl_Text_Log.ins_msg('WARN',ct_PROGRAM_CODE,g_err_msg,SQLCODE,SQLERRM);
                          g_server.status := ct_TRANS_INSERT_FAILED;
                          RAISE e_premature_termination;
                     END;                     
                  EXCEPTION
                     WHEN OTHERS THEN
                        g_sqlcode := SQLCODE;
                        g_err_msg := 'ORACLE update of erm.status to PND failed for SN/PO '||g_erm_rec.erm_id;
                        Pl_Text_Log.ins_msg('WARN',ct_PROGRAM_CODE,g_err_msg,SQLCODE,SQLERRM);
                        g_server.status := ct_ERM_UPDATE_FAIL;
                        RAISE e_premature_termination;
                  END;
               ELSE 
			BEGIN
			  IF g_erm_rec.erm_type <> 'SN' THEN
				UPDATE erm
				SET status = 'CLO',
				    close_date = SYSDATE,
				    maint_flag = 'Y'
				WHERE CURRENT OF c_po_lock ;

				/* knha8378 10-31-2019 delete inv and putawaylst and create trans */
				l_enable_finish_goods := pl_common.f_get_syspar ('ENABLE_FINISH_GOODS', 'N');
				l_internal_po_YN := check_finish_good_PO(g_erm_rec.erm_id);
				IF l_internal_po_YN = 'Y' and l_enable_finish_goods = 'Y' THEN
				   l_count_inv_delete := pl_meat_rcv.f_del_inv_put(g_erm_rec.erm_id);
                                    g_sqlcode := SQLCODE;
                                    g_err_msg := 'FYI PROCESS MEAT INTERAL PO DELETE INV-PUTAWAYLST FOR PO#: ' || g_erm_rec.erm_id
						 || '  INV DELETE COUNT IS ' || to_char(l_count_inv_delete);
                                    Pl_Text_Log.ins_msg('INFO',ct_PROGRAM_CODE,g_err_msg,SQLCODE,SQLERRM);
				END IF;
			  ELSE
				select config_flag_val 
                                  INTO host_type1 
                                FROM sys_config
                                WHERE config_flag_name='HOST_TYPE'; /*CRQ45458 inserting maint_flag value as 'Y' for SAP*/
									
				UPDATE erm
				SET status = 'CLO',
				    close_date = SYSDATE,
					--maint_flag = 'N'
					maint_flag = DECODE(host_type1,'SAP','Y','N') /*CRQ45458 inserting maint_flag value as 'Y' for SAP*/
				WHERE CURRENT OF c_po_lock ;
			  END IF; --g_erm_rec.erm_type <> SN
			  EXCEPTION WHEN OTHERS THEN
                            g_sqlcode := SQLCODE;
                            g_err_msg := 'ORACLE Unable to update to CLO status in erm.';
                            Pl_Text_Log.ins_msg('WARN',ct_PROGRAM_CODE,g_err_msg,SQLCODE,SQLERRM);
                            g_server.status := ct_ERM_UPDATE_FAIL;
                            RAISE e_premature_termination;
			END;
                  
			BEGIN
				UPDATE sn_header
				SET status = 'CLO'
				WHERE sn_no=g_erm_rec.erm_id;												
		               EXCEPTION   WHEN OTHERS THEN                         
                                 g_sqlcode := SQLCODE;
                                 g_err_msg := 'ORACLE Unable to update to CLO status in sn_header.';
                                 Pl_Text_Log.ins_msg('WARN',ct_PROGRAM_CODE,g_err_msg,SQLCODE,SQLERRM);
                                 g_server.status := ct_SN_HEADER_UPDATE_FAIL;
                                 RAISE e_premature_termination;
			END;

					/*
					** 11/05/2009 ctvgg000 ASN to all OPCOs project
					** Update RDC_PO table for VN PO's, For RDC PO's, the 
					** PO status is sent down from SUS. But for VN PO's SWMS 
					** has to update the Status in RDC_PO table. 
					**
					** Note : There is no reason for us to have the VN PO's in
					** RDC_PO table, but for the  foreign key constraint on the 
					** SN_HEADER table. Without populating the RDC_PO, we 
					** cannot populate SN_HEADER table. In future if the 
					** constraint on the SN_HEADER is removed we can stop 
					** populating RDC_PO table for VSN's.
					*/
					BEGIN						
						IF g_erm_rec.erm_type = 'VN' 
						THEN					
							UPDATE rdc_po
							SET po_status = 'CLO'
							where po_no	= g_erm_rec.erm_id;						
						END IF;
					EXCEPTION											
						WHEN OTHERS THEN                         
                         g_sqlcode := SQLCODE;
                         g_err_msg := 'ORACLE Unable to update to CLO status in rdc_po for VSN PO';
                         Pl_Text_Log.ins_msg('WARN',ct_PROGRAM_CODE,g_err_msg,SQLCODE,SQLERRM);                         
                         RAISE e_premature_termination;
					END;						
					
               END IF;
                              
            EXCEPTION
               WHEN OTHERS THEN
                  RAISE e_premature_termination;
            END;

  --acppzp  DO105 Changes for OSD creating CSN transaction for SN

            BEGIN
               SELECT NVL(status,NULL)
               INTO l_erm_status
               FROM erm
               WHERE erm_id = g_erm_rec.erm_id;
               IF l_erm_status IS NULL THEN
                  g_sqlcode := SQLCODE;
                  g_err_msg := 'ORACLE Unable to select status for SN/PO.'||g_erm_rec.erm_id;
                  Pl_Text_Log.ins_msg('WARN',ct_PROGRAM_CODE,g_err_msg,SQLCODE,SQLERRM);
                  g_server.status := ct_DATA_ERROR;
                  RAISE e_premature_termination;
               END IF;
            EXCEPTION
                  WHEN OTHERS THEN
                     g_sqlcode := SQLCODE;
                     g_err_msg := 'ORACLE Unable to select status for SN/PO.'||g_erm_rec.erm_id;
                     Pl_Text_Log.ins_msg('WARN',ct_PROGRAM_CODE,g_err_msg,SQLCODE,SQLERRM);
                     g_server.status := ct_SELECT_ERROR;
                     RAISE e_premature_termination;
            END;

         IF g_erm_rec.erm_id = i_rec_id THEN
           --acppzp  DO105 Changes for OSD
           IF l_erm_status <> 'PND' THEN
              IF g_erm_rec.erm_type = 'SN' THEN
                BEGIN

                  INSERT INTO trans (trans_id, trans_type, rec_id, trans_date, user_id, upload_time,
                                     batch_no, warehouse_id)
                  VALUES (trans_id_seq.NEXTVAL, 'CSN', i_rec_id,
                          SYSDATE, USER, TO_DATE('01-JAN-1980','FXDD-MON-YYYY'),
                          TO_NUMBER(DECODE(g_rf_flag,'Y','99','88')),
                          DECODE(g_erm_rec.erm_type,'TR',g_erm_rec.to_warehouse_id,g_erm_rec.warehouse_id));
                  Pl_Text_Log.ins_msg('WARN',ct_PROGRAM_CODE,'CLO transaction created for SN '||i_rec_id||'.',SQLCODE,SQLERRM);
                EXCEPTION
                  WHEN OTHERS THEN
                     g_sqlcode := SQLCODE;
                     g_err_msg := 'ORACLE Unable to create CSN transaction.';
                     Pl_Text_Log.ins_msg('WARN',ct_PROGRAM_CODE,g_err_msg,SQLCODE,SQLERRM);
                     g_server.status := ct_TRANS_INSERT_FAILED;
                     RAISE e_premature_termination;
                END;
              ELSE
               --acppzp  DO105 Changes for OSD
                BEGIN
                  INSERT INTO trans (trans_id, trans_type, rec_id, trans_date, user_id, upload_time,
                                     batch_no, warehouse_id)
                  VALUES (trans_id_seq.NEXTVAL, DECODE(g_erm_rec.erm_type,'TR','TRC','CLO'), i_rec_id,
                          SYSDATE, USER, TO_DATE('01-JAN-1980','FXDD-MON-YYYY'),
                          TO_NUMBER(DECODE(g_rf_flag,'Y','99','88')),
                          DECODE(g_erm_rec.erm_type,'TR',g_erm_rec.to_warehouse_id,g_erm_rec.warehouse_id));
                  Pl_Text_Log.ins_msg('WARN',ct_PROGRAM_CODE,'CLO transaction created for PO '||i_rec_id||'.',SQLCODE,SQLERRM);
                EXCEPTION
                  WHEN OTHERS THEN
                     g_sqlcode := SQLCODE;
                     g_err_msg := 'ORACLE Unable to create CLO/TRC transaction.';
                     Pl_Text_Log.ins_msg('WARN',ct_PROGRAM_CODE,g_err_msg,SQLCODE,SQLERRM);
                     g_server.status := ct_TRANS_INSERT_FAILED;
                     RAISE e_premature_termination;
                END;
              END IF;
           END IF;
         ELSE
            BEGIN
               INSERT INTO trans (trans_id, trans_type, rec_id, trans_date, user_id, batch_no)
               VALUES (trans_id_seq.NEXTVAL, 'ECL', g_erm_rec.erm_id, SYSDATE, USER,
               TO_NUMBER(DECODE(g_rf_flag,'Y','99','88')));
               Pl_Text_Log.ins_msg('DEBUG',ct_PROGRAM_CODE,'ECL transaction created.',SQLCODE,SQLERRM);
            EXCEPTION
               WHEN OTHERS THEN
                  g_sqlcode := SQLCODE;
                  g_err_msg := 'ORACLE Unable to create ECL transaction.';
                  Pl_Text_Log.ins_msg('WARN',ct_PROGRAM_CODE,g_err_msg,SQLCODE,SQLERRM);
                  g_server.status := ct_TRANS_INSERT_FAILED;
                  RAISE e_premature_termination;
            END;
         END IF;

      END LOOP;
      Pl_Text_Log.ins_msg('DEBUG',ct_PROGRAM_CODE,'Close transaction created.',SQLCODE,SQLERRM);
      IF c_po_lock%ISOPEN THEN
          CLOSE c_po_lock;
      END IF;
      BEGIN
         DELETE FROM tmp_weight
          WHERE erm_id like i_rec_id || '%';
      EXCEPTION
         WHEN OTHERS THEN
            g_sqlcode := SQLCODE;
            g_err_msg := 'ORACLE Deletion of temporary weight values failed.';
            Pl_Text_Log.ins_msg('WARN',ct_PROGRAM_CODE,g_err_msg,SQLCODE,SQLERRM);
            g_server.status := ct_ERM_UPDATE_FAIL;
            RAISE e_premature_termination;
      END;
      IF g_client.sp_flag = 'C' THEN
		BEGIN
               SELECT source_id, load_no, ship_addr1, NVL(rec_date, sysdate) 
               INTO l_vendor_id, l_load_no, l_vendor_name, l_rec_date 
               FROM erm
               WHERE erm_id = i_rec_id;
          EXCEPTION
            WHEN OTHERS THEN
               g_sqlcode := SQLCODE;
               g_err_msg := 'ORACLE Unable to select vendor, load info for SN/PO.'||i_rec_id;
               Pl_Text_Log.ins_msg('WARN',ct_PROGRAM_CODE,g_err_msg,SQLCODE,SQLERRM);
               g_server.status := ct_SELECT_ERROR;
               RAISE e_premature_termination;
		END;
          LOOP
            l_name_end := INSTR(g_client.sp_supplier_name,'~',l_name_start);
            l_qty_end := INSTR(g_client.sp_supplier_qty,'~',l_qty_start);
            IF l_name_end = 0 THEN
               l_supplier_name := SUBSTR(g_client.sp_supplier_name,l_name_start);
               l_supplier_qty := TO_NUMBER(SUBSTR(g_client.sp_supplier_qty,l_qty_start));
            ELSE
               l_supplier_name := SUBSTR(g_client.sp_supplier_name,l_name_start,l_name_end-l_name_start);
               l_supplier_qty := TO_NUMBER(SUBSTR(g_client.sp_supplier_qty,l_qty_start,l_qty_end-l_qty_start));
               l_name_start := l_name_end + 1;
               l_qty_start := l_qty_end + 1;
               l_count := l_count + 1;
            END IF;
            BEGIN
               /* START: Jira OPCOF-708: added additional fields for Blue-Chep pallet tracking */
               g_err_msg := 'l_supplier_name, qty ['||l_supplier_name||','||TO_CHAR(l_supplier_qty)
                        ||'] g_client.sp_supplier_name ['||g_client.sp_supplier_name||'], l_name_end ['||l_name_end||']' ;
               Pl_Text_Log.ins_msg('DEBUG',ct_PROGRAM_CODE,g_err_msg,SQLCODE,SQLERRM);

               IF l_supplier_qty >= 0 THEN
				   INSERT INTO sp_pallet (erm_id, supplier, pallet_qty, vendor_id, load_no, vendor_name, rec_date) 
						VALUES (i_rec_id, l_supplier_name, l_supplier_qty, l_vendor_id, l_load_no, l_vendor_name, l_rec_date);
				   g_err_msg := 'sp_pallet record ['||l_supplier_name||','||TO_CHAR(l_supplier_qty)||'] created.';
				   Pl_Text_Log.ins_msg('WARN',ct_PROGRAM_CODE,g_err_msg,SQLCODE,SQLERRM);
                ELSE
				   g_err_msg := 'sp_pallet record NOT created for PO# ' ||i_rec_id;
				   Pl_Text_Log.ins_msg('WARN',ct_PROGRAM_CODE,g_err_msg,SQLCODE,SQLERRM);
                   exit; --exit the loop
                END IF;
               /* END: Jira OPCOF-708: added additional fields for Blue-Chep pallet tracking */
	
            EXCEPTION       
               WHEN OTHERS THEN
                  g_sqlcode := SQLCODE;
                  g_err_msg := 'ORACLE Unable to create sp_pallet record ['||l_supplier_name||','||l_supplier_qty||'].';
                  Pl_Text_Log.ins_msg('WARN',ct_PROGRAM_CODE,g_err_msg,SQLCODE,SQLERRM);
                  g_server.status := ct_INSERT_FAIL;
                  RAISE e_premature_termination;
            END;
            IF l_name_end = 0 THEN EXIT; END IF;
          END LOOP;
      END IF;
    EXCEPTION
       WHEN e_premature_termination THEN
          RAISE;
       WHEN OTHERS THEN
          g_sqlcode := SQLCODE;
          g_err_msg := 'ORACLE Error closing PO.';
          Pl_Text_Log.ins_msg('WARN',ct_PROGRAM_CODE,g_err_msg,SQLCODE,SQLERRM);
          g_server.status := ct_ERM_UPDATE_FAIL;
          RAISE e_premature_termination;
    END close_po;


-----------------------------------------------------------------------------
-- Procedure sync_tmp_weight_internal_po
-- This will Sync tmp_weight to match with PUTWAYLST qty_received
-----------------------------------------------------------------------------
PROCEDURE sync_tmp_weight_internal_po(i_rec_id IN VARCHAR2) IS

   l_object_name VARCHAR2 (30) := 'SYNC_TMP_WEIGHT_INTERNAL_PO';
   gl_pkg_name   VARCHAR2 (30) := 'PL_RCV_PO_CLOSE';
   l_put_qty   number;
   l_status    erm.status%type;
   l_ship_date date;
   l_erm_id	erm.erm_id%type;
   l_prod_id   pm.prod_id%type;
   l_message   varchar2(1000);
   l_status_result  erm.status%type;
   l_erm_id_opn   erm.erm_id%type;

   cursor get_tmp_weight is
   select erm_id,prod_id,total_cases,total_splits,total_weight
   from tmp_weight t
   where t.erm_id = i_rec_id;

   cursor get_erm_put (c_erm_id IN erm.erm_id%type,
		       c_prod_id IN pm.prod_id%type) is
   select e.erm_id,e.status,e.ship_date,p.prod_id,sum(nvl(qty_received,0)) put_qty
   from   erm e,putawaylst p
   where e.erm_id = p.rec_id
   and   e.erm_id = c_erm_id
   and   p.prod_id = c_prod_id
   group by e.erm_id,e.status,e.ship_date,p.prod_id
   order by e.erm_id,p.prod_id;

BEGIN

   FOR i_rec in get_tmp_weight LOOP
       open get_erm_put (i_rec.erm_id,i_rec.prod_id);
       fetch get_erm_put into l_erm_id,l_status,l_ship_date,l_prod_id,l_put_qty;
       if get_erm_put%FOUND then
	  pl_log.ins_msg (pl_lmc.ct_fatal_msg, l_object_name, 'PO#: ' || l_erm_id || ' ship date: ' || l_ship_date || ' Status:' || l_status ||
		      '  Item#: ' || i_rec.prod_id || '  tmp_wt cases: ' || to_char(i_rec.total_cases) || '  tmp_wt weight: ' || 
		      to_char(i_rec.total_weight) || '  PUT Qty: ' || to_char(l_put_qty), NULL,null,'RECEIVING',gl_pkg_name); 
	  if nvl(l_put_qty,0) <> nvl(i_rec.total_cases,0) then
	     update tmp_weight
	       set total_cases = l_put_qty,
                   total_splits=null
	       where erm_id = i_rec.erm_id
	       and   prod_id = i_rec.prod_id;
	      pl_log.ins_msg (pl_lmc.ct_debug_msg, l_object_name, 'Old cases: ' || to_char(i_rec.total_cases) || '  Update to: ' || to_char(l_put_qty),
			       NULL, NULL, 'RECEIVING', gl_pkg_name);
             commit;
	  end if;
       else
	   pl_log.ins_msg (pl_lmc.ct_fatal_msg, l_object_name, 'NOT FOUND PO#: ' || i_rec.erm_id || '  Item#: ' || i_rec.prod_id,
			  NULL, NULL,'RECEIVING',gl_pkg_name);
       end if;  
       close get_erm_put;
   END LOOP;

END sync_tmp_weight_internal_po;
-----------------------------------------------------------------------------
-- Procedure auto_close_po
-- Auto close internal production PO
-----------------------------------------------------------------------------
PROCEDURE auto_close_po
IS
   CURSOR c_finish_goods_po(cp_fg_flag in varchar2, cp_foodpro_flag in varchar2)
   IS
      SELECT distinct po
      FROM erm
      WHERE status in ('OPN', 'PND', 'OUT')
      AND cp_fg_flag = 'Y' -- ENABLE_FINISH_GOODS syspar must be Y
      AND 
      (  
         -- FoodPro meat companies will close internal FG POs based on erm.ship_date
         (cp_foodpro_flag = 'Y' AND trunc(sysdate)  > trunc(ship_date))
         OR
         -- SUS Prime meat companies will close internal FG POs based on erm.last_fg_po 
         (cp_foodpro_flag = 'N' AND last_fg_po = 'Y')
      )
      AND check_finish_good_PO(erm_id) = 'Y'
      AND 1=2 /* disable auto close by knha8378 on Oct 30, 2019 per opco request */
      AND not exists (select 1 from putawaylst p where p.rec_id = erm.erm_id and nvl(p.putaway_put,'N') = 'N');

   --CLOSING MAIN PO ON THE SCREEN CLOSES THE EXTENDED AS WELL
   l_enable_foodpro sys_config.config_flag_val%TYPE;
   l_enable_finish_goods sys_config.config_flag_val%TYPE;
   l_error_msg varchar2(100);

BEGIN
   l_enable_foodpro := pl_common.f_get_syspar('ENABLE_FOODPRO', 'N');
   l_enable_finish_goods := pl_common.f_get_syspar('ENABLE_FINISH_GOODS', 'N');

   pl_text_log.ins_msg ('INFO', ct_program_code, 'Calling Auto PO Close. ENABLE_FINISH_GOODS:' || l_enable_finish_goods, SQLCODE, SQLERRM );

   IF (l_enable_finish_goods = 'Y') THEN
      FOR r_po IN c_finish_goods_po(l_enable_finish_goods, l_enable_foodpro) LOOP
	 pl_rcv_po_close.sync_tmp_weight_internal_po(r_po.po);
         pl_rcv_po_close.mainproc(r_po.po, l_error_msg);
      END LOOP;
   END IF;
END auto_close_po;


FUNCTION check_finish_good_PO(i_erm_id IN VARCHAR2) 
RETURN CHAR 
IS
BEGIN
   IF pl_common.f_is_internal_production_po(i_erm_id) THEN
      return 'Y';
   ELSE
      return 'N';
   END IF;
END check_finish_good_PO;

   -----------------------------------------------------------------------------
   -- Procedure check_msku_too_large - make sure msku not > 60
   -----------------------------------------------------------------------------
   PROCEDURE check_msku_too_large(i_rec_id IN CHAR) IS
      l_count_lp	NUMBER;
   BEGIN
      SELECT MAX(COUNT(*))
				INTO l_count_lp
        FROM putawaylst
       WHERE rec_id = i_rec_id
         AND parent_pallet_id IS NOT NULL
       GROUP BY parent_pallet_id;
      Pl_Text_Log.ins_msg('INFO',ct_PROGRAM_CODE,TO_CHAR(l_count_lp)||' LPs found',
                     SQLCODE,SQLERRM);
      IF (l_count_lp > ct_NUM_PALLETS_MSKU) THEN
         g_err_msg := ct_MSKU_LP_LIMIT_MSG;
         Pl_Text_Log.ins_msg('ERROR',ct_PROGRAM_CODE,g_err_msg,SQLCODE,SQLERRM);
				 g_server.status := ct_MSKU_LP_LIMIT_ERROR;
         RAISE e_premature_termination;
      END IF;
   EXCEPTION
      WHEN NO_DATA_FOUND THEN
         NULL;
      WHEN OTHERS THEN
         g_err_msg := 'Error in reading PUTAWAYLST';
         Pl_Text_Log.ins_msg('ERROR',ct_PROGRAM_CODE,g_err_msg,SQLCODE,SQLERRM);
         g_server.status := ct_MSKU_LP_LIMIT_ERROR;
         RAISE e_premature_termination;
   END check_msku_too_large;
    --------------------------------------------------------------------------------
   -- Procedure get_haul_location
   --   Find the last location to which the specified pallet was hauled.
   --------------------------------------------------------------------------------
   FUNCTION f_get_haul_location(p_pallet_id IN VARCHAR2) RETURN VARCHAR2 IS
      l_dest_loc putawaylst.dest_loc%TYPE;
   BEGIN
      SELECT dest_loc
        INTO l_dest_loc
        FROM trans t1
       WHERE pallet_id = p_pallet_id
         AND trans_type = 'HAL'
         AND ROWNUM < 2
         AND trans_date = (SELECT MAX(trans_date)
                             FROM trans t2
                            WHERE t2.pallet_id = t1.pallet_id
                              AND t2.trans_type = 'HAL');
      Pl_Text_Log.ins_msg('DEBUG',ct_PROGRAM_CODE,'Pallet '||p_pallet_id||' was hauled to '||
         l_dest_loc||'.',SQLCODE,SQLERRM);
      RETURN l_dest_loc;
   EXCEPTION
      WHEN NO_DATA_FOUND THEN
         Pl_Text_Log.ins_msg('DEBUG',ct_PROGRAM_CODE,'Pallet '||p_pallet_id||' was never hauled.',
            SQLCODE,SQLERRM);
         RETURN NULL;
      WHEN OTHERS THEN
         g_sqlcode := SQLCODE;
         g_err_msg := 'ORACLE Error selecting pallet '||p_pallet_id||' haul location.';
         Pl_Text_Log.ins_msg('WARN',ct_PROGRAM_CODE,g_err_msg,SQLCODE,SQLERRM);
         g_server.status := ct_DATA_ERROR;
         RAISE e_premature_termination;
   END f_get_haul_location;


/********** BEG ADD ACPVXG 22-Jan-06 ******************************************/   
   PROCEDURE p_send_er (i_rec_id IN putawaylst.rec_id%TYPE)
   IS
      CURSOR c_pallets_for_putaway (cp_rec_id IN putawaylst.rec_id%TYPE)
      IS
         SELECT p.pallet_id,
                p.prod_id,
                p.cust_pref_vendor,
                p.dest_loc,
                p.qty_received,
                p.exp_date,
                p.uom
           FROM erm,
                putawaylst p
          WHERE erm.po      = cp_rec_id
            AND p.rec_id    = erm.erm_id
            AND putaway_put = 'N';

      r_pallet_rec      c_pallets_for_putaway%ROWTYPE;
      lv_miniload_ind   VARCHAR2 (1);
      l_er_info         Pl_Miniload_Processing.t_exp_receipt_info DEFAULT NULL;
      lv_fname          VARCHAR2 (50)                         := 'P_SEND_ER';
      lv_msg_text       VARCHAR2 (256);
      ln_status         VARCHAR2 (1);
      BEGIN
      Pl_Text_Log.g_program_name := 'PL_RCV_CLOSE';
   
      IF NOT c_pallets_for_putaway%ISOPEN
      THEN
         OPEN c_pallets_for_putaway (i_rec_id);
      END IF;
   
      LOOP
         FETCH c_pallets_for_putaway
          INTO r_pallet_rec;
   
         EXIT WHEN c_pallets_for_putaway%NOTFOUND
               OR c_pallets_for_putaway%NOTFOUND IS NULL;
         lv_miniload_ind :=
            Pl_Miniload_Processing.F_Check_Miniload_Loc
                                               (r_pallet_rec.dest_loc,
                                                r_pallet_rec.prod_id,
                                                r_pallet_rec.cust_pref_vendor,
                                                r_pallet_rec.uom);

         l_er_info.v_expected_receipt_id := r_pallet_rec.pallet_id;
         l_er_info.v_prod_id             := r_pallet_rec.prod_id;
         l_er_info.v_cust_pref_vendor    := r_pallet_rec.cust_pref_vendor;
         l_er_info.n_uom                 := r_pallet_rec.uom;
         l_er_info.n_qty_expected        := r_pallet_rec.qty_received;
         l_er_info.v_inv_date            := r_pallet_rec.exp_date;
   
         IF lv_miniload_ind = 'Y'
         THEN
            Pl_Miniload_Processing.p_send_exp_receipt (l_er_info, ln_status);
   
            IF ln_status = 0
            THEN
               lv_msg_text :=
                     ' Expected Receipt Message for pallet :'
                  || l_er_info.v_expected_receipt_id
                  || ' sent';
               Pl_Text_Log.ins_msg ('INFO', lv_fname, lv_msg_text, NULL, NULL);
            ELSE
               lv_msg_text :=
                     ' Sending expected receipt message for pallet :'
                  || l_er_info.v_expected_receipt_id
                  || ' failed';
               Pl_Text_Log.ins_msg ('FATAL', lv_fname, lv_msg_text, NULL, NULL);
            END IF;
         END IF;
      END LOOP;
   
      CLOSE c_pallets_for_putaway;
   EXCEPTION
      WHEN OTHERS
      THEN
         IF c_pallets_for_putaway%ISOPEN
         THEN
            CLOSE c_pallets_for_putaway;
         END IF;
   
         lv_msg_text :=
                      'Error Sending expected receipt message for PO' || i_rec_id;
         Pl_Text_Log.ins_msg ('FATAL', lv_fname, lv_msg_text, SQLCODE, SQLERRM);   	  
   END;
   /********** END ADD ACPVXG 22-Jan-06 ******************************************/
   
   /* 01/22/10 - 12554 - sgan0455 - Added for 212 Enh - SCE012 - Begin */
   /* New program to verify if temperature is collected or not */
   -----------------------------------------------------------------------------
   -- Procedure verify_temp_track_ind
   --   Check if temperature has been collected and generate appropriate 
   --   error message else raise an exception.
   --   Return exception with status 92.
   -----------------------------------------------------------------------------
   PROCEDURE verify_temp_track_ind(i_rec_id IN VARCHAR2) 
   IS
      l_cooler_trk VARCHAR2(1);
      l_freezer_trk VARCHAR2(1);      
      BEGIN      
            SELECT cooler_trailer_trk, freezer_trailer_trk
            	INTO l_cooler_trk, l_freezer_trk
            FROM erm
            WHERE erm_id = i_rec_id;
            
            -- Check if the cooler/freeser track are set to 'Y'
            IF (l_cooler_trk = 'Y' OR l_freezer_trk = 'Y') THEN  

                 g_err_msg := 'Data not collected for SN or PO OR extended SN or PO ';
                 Pl_Text_Log.ins_msg('WARN',ct_PROGRAM_CODE,g_err_msg,SQLCODE,SQLERRM);
                 g_server.status := ct_MORE_REC_DATA;
                 RAISE e_premature_termination;   
                 
            END IF;
            
            EXCEPTION
       	    	WHEN e_premature_termination THEN
                     RAISE;
            	WHEN OTHERS THEN
                     g_sqlcode := SQLCODE;
                     g_err_msg := 'Error checking for data collection on SN or PO ' || i_rec_id || '.';
                     Pl_Text_Log.ins_msg('WARN',ct_PROGRAM_CODE,g_err_msg,SQLCODE,SQLERRM);
                     RAISE e_premature_termination;  
      END;
      /* 01/22/10 - 12554 - sgan0455 - Added for 212 Enh - SCE012 - End */
 
END Pl_Rcv_Po_Close;
/
