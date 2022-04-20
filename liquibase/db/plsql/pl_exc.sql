PROMPT Create package specification: pl_exc

/*************************************************************************/
-- Package Specification
/*************************************************************************/
CREATE OR REPLACE PACKAGE swms.pl_exc
AS

   -- sccs_id=@(#) src/schema/plsql/pl_exc.sql, swms, swms.9, 10.1.1 9/7/06 1.4

   ---------------------------------------------------------------------------
   -- Package Name:
   --    pl_exc
   --
   -- Description:
   --    Commmon exceptions and pragmas.  The exception will also
   --    have a corresponding constant defined for it to use as the error
   --    number if raise application error is used instead of raising the
   --    exception. 
   --
   --    The format for the exception name and the associated constant is:
   --       e_<exception name>       Exception
   --       ct_<exception name>      Associated constant
   --
   --    The user defined error number corresponds to that found in
   --    src/pgms/inc/tm_define.h + 20100 * (-1).
   --    Example: error code 173 in tm_define.h is:
   --       (173 + 20100) * (-1)
   --          (20273) * (-1)
   --             -20273
   --       To get the tm_define.h message number from the SQLCODE
   --       take the abs(SQLCODE) minus 20100
   --
   -- Modification History:
   --    Date     Designer Comments
   --    -------- -------- ---------------------------------------------------
   --    09/24/02 prpbcb   rs239a DN _____  rs239b DN _____  Created.  
   --    07/03/03 acpaks   Multi-SKU error messages for plsql programs                           
   ---------------------------------------------------------------------------

   ---------------------------------------------------------------------------
   -- Global Type Declarations
   ---------------------------------------------------------------------------

   ---------------------------------------------------------------------------
   -- Global Variables
   ---------------------------------------------------------------------------

   -- Global exceptions and pragmas.

   -- Database error.
   e_database_error    EXCEPTION;
   PRAGMA EXCEPTION_INIT(e_database_error, -20001); 
   ct_database_error   CONSTANT NUMBER :=  -20001;
   
    -- Data Not foun
   e_data_not_found    EXCEPTION;
   PRAGMA EXCEPTION_INIT(e_data_not_found, -20124); 
   ct_data_not_found   CONSTANT NUMBER :=  -20124;

   -- Invalid product ID.
   e_invalid_prodid    EXCEPTION;
   PRAGMA EXCEPTION_INIT(e_invalid_prodid, -20137); 
   ct_invalid_prodid   CONSTANT NUMBER :=  -20137;


/*acphxs MSKU-Dos compatiability changes*/
   --invalid licence plate
   e_invalid_lp  EXCEPTION;
   PRAGMA EXCEPTION_INIT(e_invalid_lp, -20139);
   ct_invalid_lp CONSTANT NUMBER :=  -20139;
/*End acphxs MSKU-Dos compatiability changes*/


   -- Invalid putaway list
   e_invalid_putlst    EXCEPTION;
   PRAGMA EXCEPTION_INIT(e_invalid_putlst, -20141);
   ct_invalid_putlst   CONSTANT NUMBER :=  -20141;

   -- Invalid aisle.
   -- Could be caused by aisle not in AISLE_INFO table.
   e_invalid_aisle    EXCEPTION;
   PRAGMA EXCEPTION_INIT(e_invalid_aisle, -20157);
   ct_invalid_aisle    CONSTANT NUMBER :=  -20157;

   -- Location error.
   -- Could be caused by invalid location passed.
   e_invalid_loc    EXCEPTION;
   PRAGMA EXCEPTION_INIT(e_invalid_loc, -20201);
   ct_invalid_loc    CONSTANT NUMBER :=  -20201;

   -- Data error in database.
   e_data_error    EXCEPTION;
   PRAGMA EXCEPTION_INIT(e_data_error, -20180); 
   ct_data_error   CONSTANT NUMBER :=  -20180;

   e_wrong_equip    EXCEPTION;
   PRAGMA EXCEPTION_INIT(e_wrong_equip, -20205);
   ct_wrong_equip   CONSTANT NUMBER :=  -20205;

   -- Select from SYS_CONFIG table failed.
   e_sel_syscfg_fail    EXCEPTION;
   PRAGMA EXCEPTION_INIT(e_sel_syscfg_fail, -20224); 
   ct_sel_syscfg_fail   CONSTANT NUMBER :=  -20224;
   
   -- Qty Not enough.
   e_insufficient_qty    EXCEPTION;
   PRAGMA EXCEPTION_INIT(e_invalid_aisle, -20228);
   ct_insufficient_qty  CONSTANT NUMBER :=  -20228;

   -- Update of TRANS table failed.
   e_trn_update_fail    EXCEPTION;
   PRAGMA EXCEPTION_INIT(e_trn_update_fail, -20234); 
   ct_trn_update_fail   CONSTANT NUMBER :=  -20234;

   -- User does not have an active labor mgmt batch.
   e_lm_no_active_batch    EXCEPTION;
   PRAGMA EXCEPTION_INIT(e_lm_no_active_batch, -20243); 
   ct_lm_no_active_batch   CONSTANT NUMBER :=  -20243;

   -- Create return put batch flag off.
   e_cte_rtn_btch_flg_off    EXCEPTION;
   PRAGMA EXCEPTION_INIT(e_cte_rtn_btch_flg_off, -20244); 
   ct_cte_rtn_btch_flg_off   CONSTANT NUMBER :=  -20244;

   -- Could not update labor mgmt batch.
   e_lm_batch_upd_fail    EXCEPTION;
   PRAGMA EXCEPTION_INIT(e_lm_batch_upd_fail, -20245); 
   ct_lm_batch_upd_fail   CONSTANT NUMBER :=  -20245;

   -- Could not find a labor mgmt batch.
   e_no_lm_batch_found    EXCEPTION;
   PRAGMA EXCEPTION_INIT(e_no_lm_batch_found, -20246); 
   ct_no_lm_batch_found   CONSTANT NUMBER :=  -20246;

   -- Unable to find LM jobcode.
   e_lm_jobcode_not_found    EXCEPTION;
   PRAGMA EXCEPTION_INIT(e_lm_jobcode_not_found, -20250);
   ct_lm_jobcode_not_found   CONSTANT NUMBER :=  -20250;

   -- Unable to find LM schedule type.
   e_lm_sched_not_found    EXCEPTION;
   PRAGMA EXCEPTION_INIT(e_lm_sched_not_found, -20251); 
   ct_lm_sched_not_found   CONSTANT NUMBER :=  -20251;

   -- LM batch already completed.
   e_lm_batch_completed    EXCEPTION;
   PRAGMA EXCEPTION_INIT(e_lm_batch_completed, -20252);
   ct_lm_batch_completed   CONSTANT NUMBER :=  -20252;

   -- LM batch already active.
   e_lm_active_batch    EXCEPTION;
   PRAGMA EXCEPTION_INIT(e_lm_active_batch, -20253); 
   ct_lm_active_batch   CONSTANT NUMBER :=  -20253;

   -- Could not find a LM parent batch.
   e_no_lm_parent_found    EXCEPTION;
   PRAGMA EXCEPTION_INIT(e_no_lm_parent_found, -20254); 
   ct_no_lm_parent_found   CONSTANT NUMBER :=  -20254;

   -- Count not update LM parent batch.
   e_lm_parent_upd_fail    EXCEPTION;
   PRAGMA EXCEPTION_INIT(e_lm_parent_upd_fail, -20255); 
   ct_lm_parent_upd_fail   CONSTANT NUMBER :=  -20255;

   -- Either user id or labor group is invalid
   e_lm_bad_user    EXCEPTION;
   PRAGMA EXCEPTION_INIT(e_lm_bad_user, -20256);  
   ct_lm_bad_user    CONSTANT NUMBER := -20256;

   -- Unable to insert ISTART LM batch.
   e_lm_ins_istart_fail    EXCEPTION;
   PRAGMA EXCEPTION_INIT(e_lm_ins_istart_fail, -20257);  
   e_lm_ins_istart_fail   CONSTANT NUMBER :=   -20257;

   -- LM batch already merged.
   e_lm_merge_batch    EXCEPTION;
   PRAGMA EXCEPTION_INIT(e_lm_merge_batch, -20259);
   ct_lm_merge_batch   CONSTANT NUMBER :=  -20259;

   -- Insert into TRANS table failed.
   e_trans_insert_failed    EXCEPTION;
   PRAGMA EXCEPTION_INIT(e_trans_insert_failed, -20263);
   ct_trans_insert_failed   CONSTANT NUMBER :=  -20263;

   -- Update of PUTAWAYLST table failed.
   e_putawaylst_update_fail    EXCEPTION;
   PRAGMA EXCEPTION_INIT(e_putawaylst_update_fail, -20273);
   ct_putawaylst_update_fail    CONSTANT NUMBER := -20273;

   -- Select from INV table failed.
   e_sel_inv_fail    EXCEPTION;
   PRAGMA EXCEPTION_INIT(e_sel_inv_fail, -20277);
   ct_sel_inv_fail   CONSTANT NUMBER :=  -20277;

   -- Select from LOC table failed.
   e_sel_loc_fail    EXCEPTION;
   PRAGMA EXCEPTION_INIT(e_sel_loc_fail, -20278); 
   ct_sel_loc_fail   CONSTANT NUMBER :=  -20278;

   -- LM Bay Distance not setup.
   -- Possible causes:
   --    - dock not in DOCK table.
   e_lm_bay_dist_bad_setup    EXCEPTION;
   PRAGMA EXCEPTION_INIT(e_lm_bay_dist_bad_setup, -20286);
   ct_lm_bay_dist_bad_setup   CONSTANT NUMBER :=  -20286;

   -- Select of cross aisle failed for LM.
   e_cross_aisle_sel_fail    EXCEPTION;
   PRAGMA EXCEPTION_INIT(e_cross_aisle_sel_fail, -20287);
   ct_cross_aisle_sel_fail   CONSTANT NUMBER :=  -20287;

   -- Forklift labor function missing.
   e_lm_forklift_not_found    EXCEPTION;
   PRAGMA EXCEPTION_INIT(e_lm_forklift_not_found, -20288); 
   ct_lm_forklift_not_found   CONSTANT NUMBER :=  -20288;

   -- Forklift labor function not active.
   e_lm_forklift_not_active    EXCEPTION;
   PRAGMA EXCEPTION_INIT(e_lm_forklift_not_active, -20289);
   ct_lm_forklift_not_active    CONSTANT NUMBER := -20289;

   -- Suspended LM batch activated.
   e_lm_susp_batch_actv    EXCEPTION;
   PRAGMA EXCEPTION_INIT(e_lm_susp_batch_actv, -20290); 
   ct_lm_susp_batch_actv   CONSTANT NUMBER :=  -20290;

   -- Inserting forklift indirect batch failed.
   e_lm_ins_fl_dflt_fail    EXCEPTION;
   PRAGMA EXCEPTION_INIT(e_lm_ins_fl_dflt_fail, -20291);
   ct_lm_ins_fl_dflt_fail   CONSTANT NUMBER :=  -20291;

   -- LM warehouse to warehouse (WW) point distance not setup.
   e_lm_pt_dist_badsetup_wtw    EXCEPTION;
   PRAGMA EXCEPTION_INIT(e_lm_pt_dist_badsetup_wtw, -20296); 
   ct_lm_pt_dist_badsetup_wtw   CONSTANT NUMBER :=  -20296;

   -- LM warehouse to first door (WD) point distance not setup.
   e_lm_pt_dist_badsetup_wfd    EXCEPTION;
   PRAGMA EXCEPTION_INIT(e_lm_pt_dist_badsetup_wfd, -20297); 
   ct_lm_pt_dist_badsetup_wfd   CONSTANT NUMBER :=  -20297;

   -- LM Point door to door (DD) point distance not setup.
   e_lm_pt_dist_badsetup_dtd    EXCEPTION;
   PRAGMA EXCEPTION_INIT(e_lm_pt_dist_badsetup_dtd, -20298);
   ct_lm_pt_dist_badsetup_dtd   CONSTANT NUMBER :=  -20298;

   -- LM door to aisle (DA) point distance not setup.
   e_lm_pt_dist_badsetup_dta    EXCEPTION;
   PRAGMA EXCEPTION_INIT(e_lm_pt_dist_badsetup_dta, -20299); 
   ct_lm_pt_dist_badsetup_dta   CONSTANT NUMBER :=  -20299;

   -- LM aisle to aisle (AA) point distance not setup
   -- Possible causes are:
   --    - aisle(s) not in the AISLE_INFO table.
   --    - aisle(s) not setup as AA distances in the POINT_DISTANCE table.
   e_lm_pt_dist_badsetup_ata    EXCEPTION;
   PRAGMA EXCEPTION_INIT(e_lm_pt_dist_badsetup_ata, -20300);
   ct_lm_pt_dist_badsetup_ata   CONSTANT NUMBER :=  -20300;

   -- LM cross aisle distance not setup.
   e_lm_pt_dist_badsetup_aca    EXCEPTION;
   PRAGMA EXCEPTION_INIT(e_lm_pt_dist_badsetup_aca, -20301); 
   ct_lm_pt_dist_badsetup_aca   CONSTANT NUMBER :=  -20301;

   -- LM warehouse to first aisle (WA) point distance not setup
   e_lm_pt_dist_badsetup_wfa    EXCEPTION;
   PRAGMA EXCEPTION_INIT(e_lm_pt_dist_badsetup_wfa, -20303);
   ct_lm_pt_dist_badsetup_wfa   CONSTANT NUMBER :=  -20303;

   -- Point type not setup.
   e_lm_pt_dist_badsetup_pt    EXCEPTION;
   PRAGMA EXCEPTION_INIT(e_lm_pt_dist_badsetup_pt, -20304); 
   ct_lm_pt_dist_badsetup_pt   CONSTANT NUMBER :=  -20304;

   -- Multiple active batches found for user.
   e_lm_multi_active_batch    EXCEPTION;
   PRAGMA EXCEPTION_INIT(e_lm_multi_active_batch, -20318); 
   ct_lm_multi_active_batch   CONSTANT NUMBER :=  -20318;

   -- LM 'N' status batch(es) found for user.
   e_lm_n_status_batch    EXCEPTION;
   PRAGMA EXCEPTION_INIT(e_lm_n_status_batch, -20319);  
   ct_lm_n_status_batch   CONSTANT NUMBER :=  -20319;
   
    -- No available slots.
    -- Used when no slots can be identified.
    e_slots_not_available    EXCEPTION;
    PRAGMA EXCEPTION_INIT(e_slots_not_available, -20322);
    ct_slots_not_available  CONSTANT NUMBER :=  -20322;

   /*****************************************************************/
   /*****************************************************************/
   -- New exceptions added for MSKU.
    
   e_msku_no_msku_deep    EXCEPTION;
      PRAGMA EXCEPTION_INIT(e_msku_no_msku_deep, -20397); 
   ct_msku_no_msku_deep   CONSTANT NUMBER :=  -20397;
      
   e_msku_msku_plt_exists    EXCEPTION;
      PRAGMA EXCEPTION_INIT(e_msku_msku_plt_exists, -20398); 
   ct_msku_msku_plt_exists   CONSTANT NUMBER :=  -20398;
   
   e_msku_msku_plt_qty    EXCEPTION;
      PRAGMA EXCEPTION_INIT(e_msku_msku_plt_qty, -20399); 
   ct_msku_msku_plt_qty   CONSTANT NUMBER :=  -20399;
   
   
   e_msku_msku_rep_pik    EXCEPTION;
      PRAGMA EXCEPTION_INIT(e_msku_msku_rep_pik, -20400); 
   ct_msku_msku_rep_pik   CONSTANT NUMBER :=  -20400;
   
   e_msku_msku_put_pik    EXCEPTION;
      PRAGMA EXCEPTION_INIT(e_msku_msku_put_pik, -20401); 
   ct_msku_msku_put_pik   CONSTANT NUMBER :=  -20401;
   
   e_msku_non_msku_rep_pik    EXCEPTION;
      PRAGMA EXCEPTION_INIT(e_msku_non_msku_rep_pik, -20402); 
   ct_msku_non_msku_rep_pik   CONSTANT NUMBER :=  -20402;
   
   e_msku_non_msku_put_pik    EXCEPTION;
      PRAGMA EXCEPTION_INIT(e_msku_non_msku_put_pik, -20403); 
   ct_msku_non_msku_put_pik   CONSTANT NUMBER :=  -20403;
   
    e_msku_lp_not_found    EXCEPTION;
      PRAGMA EXCEPTION_INIT(e_msku_lp_not_found, -20404); 
   ct_msku_lp_not_found   CONSTANT NUMBER :=  -20404;
   
    e_lm_cannot_divide_msku    EXCEPTION;
      PRAGMA EXCEPTION_INIT(e_lm_cannot_divide_msku, -20405); 
   ct_lm_cannot_divide_msku   CONSTANT NUMBER :=  -20405;
/*acphxs MSKU-Dos compatiability changes*/
   e_msku_lp EXCEPTION;
   PRAGMA EXCEPTION_INIT(e_msku_lp, -20410);
   ct_msku_lp CONSTANT NUMBER :=  -20410;
/*End acphxs MSKU-Dos compatiability changes*/

   /*****************************************************************/
   /*****************************************************************/
   -- New exceptions added that were not in tm_define.h.
   -- LM Dock not found
   -- Possible causes:
   --    - dock not in DOCK table.
   e_lm_dock_not_found    EXCEPTION;
   PRAGMA EXCEPTION_INIT(e_lm_dock_not_found, -20800);
   ct_lm_dock_not_found   CONSTANT NUMBER :=  -20800;

   -- Aisle not found in bay_distance table.
   e_lm_bay_dist_aisle_not_found    EXCEPTION;
   PRAGMA EXCEPTION_INIT(e_lm_bay_dist_aisle_not_found, -20801);  
   ct_lm_bay_dist_aisle_not_found   CONSTANT NUMBER :=  -20801;

   -- LM Point pickup to pickup (PP) point distance not setup.
   e_lm_pt_dist_badsetup_ptp    EXCEPTION;
   PRAGMA EXCEPTION_INIT(e_lm_pt_dist_badsetup_ptp, -20802);
   ct_lm_pt_dist_badsetup_ptp   CONSTANT NUMBER :=  -20802;

   -- LM door to pickup point (DP) point distance not setup.
   e_lm_pt_dist_badsetup_dtp    EXCEPTION;
   PRAGMA EXCEPTION_INIT(e_lm_pt_dist_badsetup_dtp, -20802); 
   ct_lm_pt_dist_badsetup_dtp   CONSTANT NUMBER :=  -20802;

   -- LM pickup point to aisle (PA) point distance not setup.
   e_lm_pt_dist_badsetup_pta    EXCEPTION;
   PRAGMA EXCEPTION_INIT(e_lm_pt_dist_badsetup_pta, -20803); 
   ct_lm_pt_dist_badsetup_pta   CONSTANT NUMBER :=  -20803;

   -- Selection batch was not found in the FLOATS table.
   e_no_selection_batch_found     EXCEPTION;
   PRAGMA EXCEPTION_INIT(e_no_selection_batch_found  , -20804); 
   ct_e_no_selection_batch_found  CONSTANT NUMBER :=  -20804;

   -- LM warehouse to pickup point (WP) point distance not setup.
   e_lm_pt_dist_badsetup_wtp    EXCEPTION;
   PRAGMA EXCEPTION_INIT(e_lm_pt_dist_badsetup_wtp, -20805); 
   ct_lm_pt_dist_badsetup_wtp   CONSTANT NUMBER :=  -20805;

   ---------------------------------------------------------------------------
   -- Public Constants
   ---------------------------------------------------------------------------

   -- The error number constants are defined with the exception.  It made
   -- the most sense to keep the exception and the error number constant
   -- together.

   ---------------------------------------------------------------------------
   -- Public Modules
   ---------------------------------------------------------------------------

   ---------------------------------------------------------------------------
   -- Function:
   --    f_get_rf_errcode
   --
   -- Description:
   --    This function takes an error code designated as an user defined
   --    exception which be in the range from -20000 to 20999 and returns
   --    the corresponding RF error code.  The RF error code will be
   --    what is in tm_define.h.
   --
   --    The user defined exception error number corresponds to that found in
   --    src/pgms/inc/tm_define.h + 20100 * (-1).
   --
   -- Parameters:
   --    i_errCode   -  The error code to convert.
   --
   -- Return Value:
   --    The RF error code if i_errCode is between -20000 and -20999.
   --    999 if i_errCode is null or if an error occurs.
   --    i_errCode if i_errCode is not between -20000 and -20999.
   --
   -- Exceptions raised:
   --    None.  999 is returned if an abnormal condition is encountered.
   --
   -- Modification History:
   --    Date     Designer Comments
   --    -------- -------- ---------------------------------------------------
   --    09/24/02          Created.
   ---------------------------------------------------------------------------
   FUNCTION f_get_rf_errcode(i_errCode IN NUMBER)
   RETURN INT;


END pl_exc;  -- end package specification
/


PROMPT Create package body: pl_exc

/**************************************************************************/
-- Package Body
/**************************************************************************/
CREATE OR REPLACE PACKAGE BODY swms.pl_exc
AS
   ----------------------------------------------------------------------------
   -- Package Name:
   --    pl_exc
   --
   -- Description:
   --    Commmon exceptions and pragmas.
   --
   --    Date     Designer Comments
   --    -------- -------  ----------------------------------------------------
   --    09/24/02 prpbcb   rs239a DN _____  rs239b DN _____  Created.  
   --
   ----------------------------------------------------------------------------

   ---------------------------------------------------------------------------
   -- Private Global Variables
   ---------------------------------------------------------------------------

   ---------------------------------------------------------------------------
   -- Private Constants
   ---------------------------------------------------------------------------

   ---------------------------------------------------------------------------
   -- Private Modules
   ---------------------------------------------------------------------------

   ---------------------------------------------------------------------------
   -- Public Modules
   ---------------------------------------------------------------------------

   ---------------------------------------------------------------------------
   -- Function:
   --    f_get_rf_errcode
   --
   -- Description:
   --    This function takes an error code designated as an user defined
   --    exception which be in the range from -20000 to 20999 and returns
   --    the corresponding RF error code.  The RF error code will be
   --    what is in tm_define.h.
   --
   --    The user defined exception error number corresponds to that found in
   --    src/pgms/inc/tm_define.h + 20100 * (-1).
   --
   -- Parameters:
   --    i_errCode   -  The error code to convert.
   --
   -- Return Value:
   --    The RF error code if i_errCode is between -20000 and -20999.
   --    999 if i_errCode is null or if an error occurs.
   --    i_errCode if i_errCode is not between -20000 and -20999.
   --
   -- Exceptions raised:
   --    None.  999 is returned if an abnormal condition is encountered.
   --
   -- Modification History:
   --    Date     Designer Comments
   --    -------- -------- ---------------------------------------------------
   --    09/24/02          Created.
   ---------------------------------------------------------------------------
   FUNCTION f_get_rf_errcode(i_errCode IN NUMBER)
   RETURN INT IS
      ln_host_code         NUMBER := 0;
   BEGIN
      IF (i_errCode BETWEEN -20999 and -20000) THEN
         ln_host_code := ABS(i_errCode) - 20100;
      ELSIF (i_errCode IS NOT NULL) THEN
         ln_host_code := i_errCode;
      ELSE
         ln_host_code := 999;
      END IF;

      RETURN ln_host_code;
   EXCEPTION
      WHEN OTHERS THEN
         ln_host_code := 999;
         RETURN ln_host_code;
   END f_get_rf_errcode;

END pl_exc;  -- end package body
/
