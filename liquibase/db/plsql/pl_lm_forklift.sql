create or replace PACKAGE pl_lm_forklift IS
/*******************************************************************************
** Package:
**        pl_lm_forklift. Migrated from lm_forklift.pc
**
** Description:
		  Forklift functions for labor management.
**
** Called by:
		This is a Common package called from many programs.
** Modification history                                               
** Author      Date        Ver    Description                         
** ----------- ----------  ----  -----------------------------------------    
** KSAR9933	   12/18/2019   1.0    Initial Version  
*******************************************************************************/
    FUNCTION lmf_insert_haul_trans (
        i_batch_no   IN           batch.batch_no%TYPE
    ) RETURN rf.status;

    FUNCTION lmf_create_haul_forklift_batch (
        i_batch_no       IN               batch.batch_no%TYPE,
        i_put_batch_no   IN               batch.batch_no%TYPE,
        i_pallet_id      IN               batch.ref_no%TYPE
    ) RETURN rf.status;

    FUNCTION lmf_forklift_active RETURN rf.status;

    FUNCTION lmf_update_put_trans (
        i_batch_no   IN           batch.batch_no%TYPE
    ) RETURN rf.status;

    FUNCTION lm_attch_to_fklft_xfr_batch (
        i_vc_user_id_ptr          IN                        batch.user_id%TYPE,
        i_vc_equip_id_ptr         IN                        equip.equip_id%TYPE,
        i_trans_id                IN                        trans.trans_id%TYPE,
        i_suspend_flag            IN                        VARCHAR2,
        i_merge_flag              IN                        VARCHAR2,
        i_labor_mgmt_batch_type   IN                        VARCHAR2
    ) RETURN rf.status;

    FUNCTION lmf_reset_forklift_xfr_batch (
        i_user_id                 IN                        batch.user_id%TYPE,
        i_equip_id                IN                        equip.equip_id%TYPE,
        i_labor_mgmt_batch_type   IN                        batch.batch_no%TYPE,
        i_delete_batch_flag       IN                        VARCHAR2,
        i_drop_point              IN                        VARCHAR2,
        i_trans_id_char           IN                        VARCHAR2
    ) RETURN rf.status;

    FUNCTION lmf_insert_pph_transaction (
        i_how_hst_initiated   IN                    VARCHAR2,
        i_vc_src_loc_ptr      IN                    loc.logi_loc%TYPE,
        i_vc_pallet_id_ptr    IN                    putawaylst.pallet_id%TYPE,
        i_qty                 IN                    NUMBER,
        o_trans_id_ptr        OUT                   trans.trans_id%TYPE
    ) RETURN rf.status;

    FUNCTION lm_reset_current_fklft_batch (
        i_type_flag       IN                VARCHAR2,
        i_user_id         IN                batch.user_id%TYPE,
        i_drop_location   IN                VARCHAR2,
        i_equip_id        IN                equip.equip_id%TYPE
    ) RETURN rf.status;

    FUNCTION lmf_create_batch (
        i_batch_type   IN             VARCHAR2,
        i_key_val      IN             VARCHAR2
    ) RETURN rf.status;

    FUNCTION lmf_create_haul_batch_id (
        o_haul_batch_no   OUT               batch.batch_no%TYPE
    ) RETURN rf.status;

    FUNCTION lmf_make_batch_parent (
        i_batch_no   IN           batch.batch_no%TYPE
    ) RETURN rf.status;

    FUNCTION lmf_remove_except_time_spent (
        i_batch_no   IN           batch.batch_no%TYPE
    ) RETURN rf.status;

    FUNCTION lmf_reset_batch (
        i_batch_no   IN           batch.batch_no%TYPE
    ) RETURN rf.status;

    FUNCTION lmf_reset_haul_batch (
        i_batch_to_reset   IN                 batch.batch_no%TYPE,
        i_drop_point       IN                 batch.kvi_from_loc%TYPE
    ) RETURN rf.status;

    FUNCTION lm_signoff_from_forklift_batch (
        i_batch_no    IN            batch.batch_no%TYPE,
        i_equip_id    IN            equip.equip_id%TYPE,
        i_user_id     IN            batch.user_id%TYPE,
        i_is_parent   IN            VARCHAR2
    ) RETURN rf.status;

    FUNCTION lmf_convert_norm_put_to_haul (
        i_batch_no        IN                batch.batch_no%TYPE,
        i_drop_location   IN                batch.kvi_to_loc%TYPE,
        i_equip_id        IN                equip.equip_id%TYPE,
        i_user_id         IN                batch.user_id%TYPE
    ) RETURN rf.status;

    FUNCTION lmf_signon_to_forklift_batch (
        i_cmd               IN                  VARCHAR,
        i_batch_no          IN                  batch.batch_no%TYPE,
        i_parent_batch_no   IN                  batch.parent_batch_no%TYPE,
        i_user_id           IN                  batch.user_id%TYPE,
        i_supervisor        IN                  batch.user_supervsr_id%TYPE,
        i_equip_id          IN                  equip.equip_id%TYPE
    ) RETURN rf.status;

    FUNCTION lmf_break_away (
        i_type_flag       IN                VARCHAR2,
        i_user_id         IN                VARCHAR2,
        i_drop_location   IN                batch.kvi_to_loc%TYPE,
        i_equip_id        IN                equip.equip_id%TYPE
    ) RETURN rf.status;

    FUNCTION lmf_is_valid_point (
        i_point IN VARCHAR2
    ) RETURN rf.status;

    FUNCTION lmf_merge_msku_batches (
        i_psz_batch_no batch.batch_no%TYPE
    ) RETURN rf.status;

    FUNCTION lmf_cvt_mrgd_msku_put_to_haul (
        i_batch_no        IN                batch.batch_no%TYPE,
        i_drop_location   IN                batch.kvi_to_loc%TYPE,
        i_equip_id        IN                equip.equip_id%TYPE
    ) RETURN rf.status;

    FUNCTION lmf_reset_msku_letdown_batch (
        i_psz_batch_no   IN               batch.batch_no%TYPE,
        i_psz_equip_id   IN               equip.equip_id%TYPE,
        i_psz_user_id    IN               batch.user_id%TYPE
    ) RETURN rf.status;

    FUNCTION lm_brk_away_rst_parent_batch (
        i_type_flag   IN            VARCHAR2,
        i_batch_no    IN            batch.batch_no%TYPE,
        i_location    IN            VARCHAR2,
        i_equip_id    IN            equip.equip_id%TYPE,
        i_user_id     IN            batch.user_id%TYPE
    ) RETURN rf.status;

    FUNCTION lm_brk_away_convert_mrg_to_hl (
        i_batch_no        IN                batch.batch_no%TYPE,
        i_drop_location   IN                batch.kvi_to_loc%TYPE,
        i_equip_id        IN                equip.equip_id%TYPE
    ) RETURN rf.status;

    FUNCTION lmf_suspend_current_batch (
        i_user_id IN VARCHAR2
    ) RETURN rf.status;

    FUNCTION lmf_find_suspended_batch (
        i_user_id    IN           VARCHAR2,
        o_batch_no   OUT          batch.batch_no%TYPE
    ) RETURN rf.status;

    FUNCTION lmf_activate_suspended_batch (
        i_batch_no   IN           batch.batch_no%TYPE
    ) RETURN rf.status;

    FUNCTION lmf_create_dflt_fk_ind_batch (
        i_batch_no     IN             batch.batch_no%TYPE,
        i_user_id      IN             batch.user_id%TYPE,
        i_ref_no       IN             batch.ref_no%TYPE,
        i_start_time   IN             batch.actl_start_time%TYPE
    ) RETURN rf.status;

    FUNCTION lmf_convert_merged_put_to_haul (
        i_batch_no        IN                batch.batch_no%TYPE,
        i_drop_location   IN                VARCHAR2,
        i_equip_id        IN                equip.equip_id%TYPE
    ) RETURN rf.status;

    FUNCTION lmf_reset_parent_batch (
        i_type_flag   IN            VARCHAR2,
        i_batch_no    IN            batch.batch_no%TYPE,
        i_location    IN            VARCHAR2,
        i_equip_id    IN            equip.equip_id%TYPE,
        i_user_id     IN            VARCHAR2
    ) RETURN rf.status;

    FUNCTION lm_determine_blk_pull_door_no (
        i_float_no         IN                 floats.float_no%TYPE,
        o_vc_door_no_ptr   OUT                VARCHAR2
    ) RETURN rf.status;

    FUNCTION lmf_update_batch_kvi (
        i_batch_no    IN            batch.batch_no%TYPE,
        i_no_cases    IN            NUMBER,
        i_no_splits   IN            NUMBER
    ) RETURN rf.status;

    FUNCTION lmf_what_putaway_is_this (
        i_pallet_id                IN                         putawaylst.pallet_id%TYPE,
        o_pallet_putaway           OUT                        NUMBER,
        o_num_putaways_completed   OUT                        NUMBER,
        o_num_pending_putaways     OUT                        NUMBER
    ) RETURN rf.status;

    FUNCTION lmf_bulk_pull_w_drop_to_home (
        i_batch_no   IN           batch.batch_no%TYPE
    ) RETURN NUMBER;

    FUNCTION lm_sel_split_rpl_crdt_syspar (
        o_apply_credit_at_case_level OUT NUMBER
    ) RETURN rf.status;

    FUNCTION lmf_update_forklift_xfr_batch (
        i_trans_id                IN                        trans.trans_id%TYPE,
        i_vc_to_slot_ptr          IN                        batch.kvi_to_loc%TYPE,
        i_labor_mgmt_batch_type   IN                        VARCHAR2
    ) RETURN rf.status;

    FUNCTION lmf_reactivate_suspended_batch (
        i_user_id                 IN                        batch.user_id%TYPE,
        i_equip_id                IN                        equip.equip_id%TYPE,
        i_labor_mgmt_batch_type   IN                        VARCHAR2
    ) RETURN rf.status;

    FUNCTION lmf_get_dflt_fk_ind_start_time (
        i_psz_user_id           IN                      VARCHAR2,
        i_psz_active_batch_no   IN                      VARCHAR2,
        o_psz_start_time        OUT                     VARCHAR2
    ) RETURN rf.status;

    FUNCTION lm_break_away_cte_hl_btc_id (
        o_haul_batch_no OUT VARCHAR2
    ) RETURN rf.status;

    FUNCTION reset_swap_batch (
        i_user_id    IN  batch.user_id%TYPE,
        i_equip_id   IN  batch.equip_id%TYPE
    ) RETURN rf.status;

END pl_lm_forklift;
/

create or replace PACKAGE BODY pl_lm_forklift IS
------------------------------------------------------------------------------
/*                      GLOBAL DECLARATIONS                                */
------------------------------------------------------------------------------

    g_forklift_audit         NUMBER := 1;
------------------------------------------------------------------------------
/*       CONSTANT VARIABLES FOR LABOR MANAGEMENT FUNCTIONS                  */
------------------------------------------------------------------------------ 
    only_putaway_to_slot     CONSTANT NUMBER := 1;
    first_putaway_to_slot    CONSTANT NUMBER := 2;
    last_putaway_to_slot     CONSTANT NUMBER := 3;
    middle_putaway_to_slot   CONSTANT NUMBER := 4;
    non_putaway              CONSTANT NUMBER := 5;
    lm_last_is_istop         CONSTANT NUMBER := 9999;
    PACKAGE_NAME             CONSTANT swms_log.program_name%TYPE := 'PL_LM_FORKLIFT';
-------------------------------------------------------------------------------
/**                     PUBLIC MODULES                                      **/
-------------------------------------------------------------------------------

/*****************************************************************************
**  FUNCTION:
**      lmf_insert_haul_trans()
**  DESCRIPTION:
**      This function inserts a haul transaction based on a haul labor batch.
**
**      For a MSKU pallet a haul will be created for each child LP not
**      confirmed putaway.  Even though there is only one labor batch for
**      a haul of a MSKU we want to keep transactions at the pallet level.
**
**  PARAMETERS:
**      i_batch_no char     - Haul batch to reference.
**
**  RETURN VALUES:
**      SWMS_NORMAL  --  Okay.
**      TRANS_INSERT_FAILED  --  Unable to insert transaction.
*********************************************************************************/

    FUNCTION lmf_insert_haul_trans (
        i_batch_no   IN           batch.batch_no%TYPE
    ) RETURN rf.status IS

        l_function       VARCHAR2(50) := 'pl_lm_forklift.lmf_insert_haul_trans';
        rc               NUMBER;
        l_rec_id         putawaylst.rec_id%TYPE;
        l_crossdock      VARCHAR2(5);
        l_ret_val        NUMBER := 0;
        l_trans_id_seq   NUMBER(10);
    BEGIN
        pl_text_log.ins_msg_async('INFO', l_function, 'Starting lmf_insert_haul_trans... Batch No = ' || i_batch_no, sqlcode, sqlerrm);
        SELECT
            p.rec_id
        INTO l_rec_id
        FROM
            putawaylst   p,
            batch        b
        WHERE
            ( p.pallet_id = b.ref_no
              OR p.parent_pallet_id = b.ref_no )
            AND b.batch_no = i_batch_no
            AND nvl(p.putaway_put, 'N') = 'N'
            AND ROWNUM = 1;

        l_crossdock := pl_rcv_cross_dock.f_is_crossdock_pallet(l_rec_id, 'E');
        pl_text_log.ins_msg_async('INFO', l_function, 'status-crossdock pallet = ' || l_crossdock, sqlcode, sqlerrm);
        SELECT
            trans_id_seq.NEXTVAL
        INTO l_trans_id_seq
        FROM
            dual;

        BEGIN
            IF l_crossdock = 'Y' THEN
                INSERT INTO trans (
                    trans_id,
                    trans_type,
                    trans_date,
                    prod_id,
                    pallet_id,
                    dest_loc,
                    src_loc,
                    rec_id,
                    user_id,
                    weight,
                    qty,
                    uom,
                    exp_date,
                    cmt,
                    parent_pallet_id,
                    labor_batch_no
                )
                    SELECT
                        l_trans_id_seq,
                        'HAL',
                        SYSDATE,
                        '*MULTI*',
                        p.pallet_id,
                        b.kvi_to_loc,
                        b.kvi_from_loc,
                        p.rec_id,
                        user,
                        b.kvi_wt,
                        p.qty,
                        p.uom,
                        p.exp_date,
                        i_batch_no,
                        p.parent_pallet_id,
                        b.batch_no
                    FROM
                        putawaylst   p,
                        batch        b
                    WHERE
                        ( p.pallet_id = b.ref_no
                          OR p.parent_pallet_id = b.ref_no )
                        AND b.batch_no = i_batch_no
                        AND nvl(p.putaway_put, 'N') = 'N'
                        AND ROWNUM = 1;

            ELSE
                INSERT INTO trans (
                    trans_id,
                    trans_type,
                    trans_date,
                    prod_id,
                    pallet_id,
                    dest_loc,
                    src_loc,
                    rec_id,
                    user_id,
                    weight,
                    qty,
                    uom,
                    exp_date,
                    cmt,
                    parent_pallet_id,
                    labor_batch_no
                )
                    SELECT
                        l_trans_id_seq,
                        'HAL',
                        SYSDATE,
                        p.prod_id,
                        p.pallet_id,
                        b.kvi_to_loc,
                        b.kvi_from_loc,
                        p.rec_id,
                        user,
                        b.kvi_wt,
                        p.qty,
                        p.uom,
                        p.exp_date,
                        i_batch_no,
                        p.parent_pallet_id,
                        b.batch_no
                    FROM
                        putawaylst   p,
                        batch        b
                    WHERE
                        ( p.pallet_id = b.ref_no
                          OR p.parent_pallet_id = b.ref_no )
                        AND b.batch_no = i_batch_no
                        AND nvl(p.putaway_put, 'N') = 'N';

            END IF;
        EXCEPTION
            WHEN OTHERS THEN
                pl_text_log.ins_msg_async('WARN', l_function, 'LMF ORACLE unable to create haul transaction.Insert-trans failed. trans_id_seq '
                || l_trans_id_seq, sqlcode, sqlerrm);
                l_ret_val := rf.status_trans_insert_failed;
        END;

        RETURN l_ret_val;
    EXCEPTION
        WHEN OTHERS THEN
            pl_text_log.ins_msg_async('WARN', l_function, 'Select from putaway failed ', sqlcode, sqlerrm);
            l_ret_val := rf.status_trans_insert_failed;
            RETURN l_ret_val;
    END lmf_insert_haul_trans;
	
/*****************************************************************************
**  FUNCTION:
**      lmf_forklift_active()
**  DESCRIPTION:
**      This functions gives a result stating whether or not forklift labor
**      batches are active or not.
**  PARAMETERS:
**      None
**  RETURN VALUES:
**      SWMS_NORMAL            --  Forklift Labor is active.
**      STATUS_LM_FORKLIFT_NOT_ACTIVE --  Forklift Labor is NOT active.
**      lm_forklift_not_found  --  Forklift Labor Function not found.
*****************************************************************************/

    FUNCTION lmf_forklift_active RETURN rf.status IS

        l_function          VARCHAR2(50) := 'pl_lm_forklift.lmf_forklift_active';
        l_ret_val           NUMBER := 0;
        l_forklift_active   VARCHAR2(1);
    BEGIN
        l_ret_val := pl_rf_lm_common.lmc_labor_mgmt_active();
        IF l_ret_val = 0 THEN
            BEGIN
                SELECT
                    create_batch_flag
                INTO l_forklift_active
                FROM
                    lbr_func
                WHERE
                    lfun_lbr_func = 'FL';

                IF l_forklift_active = 'N' THEN
                    pl_text_log.ins_msg_async('INFO', l_function, 'LMF ORACLE create forklift lbr mgmt flag is off ' || l_forklift_active, sqlcode
                    , sqlerrm);
                    l_ret_val := rf.status_lm_forklift_not_active;
                ELSE
                    pl_text_log.ins_msg_async('INFO', l_function, 'LMF ORACLE Forklift is active ' || l_forklift_active, sqlcode, sqlerrm);
                END IF;

            EXCEPTION
                WHEN OTHERS THEN
                    pl_text_log.ins_msg_async('WARN', l_function, 'LMF ORACLE Unable to select forklift lbr mgmt flag-select  from lbr_func
															Failed'
                    , sqlcode, sqlerrm);
                    l_ret_val := rf.status_lm_forklift_not_found;
            END;

        END IF;

        RETURN l_ret_val;
    END lmf_forklift_active;
/*****************************************************************************
**  Function:
**     lmf_update_put_trans()
**
**  Description:
**
**     This function updates the trans PUT record src_loc to handle the
**     situation where the PO was closed before the pallet was putaway
**     (thus creating a PUT transaction) and then the pallet was hauled
**     or a func1 make during putaway.
**     The transaction PUT record src_loc needs to be updated to the
**     location the pallet was hauled to or the func1 drop point.
**     If the PO is not closed then there will be no record to update.
**
**  Parameters:
**     i_batch_no - Batch to reference to get the location the pallet
**                   was hauled to.  This should be a haul batch #.
**
**  Return Values:
**     SWMS_NORMAL    -  Okay.
**     TRN_UPD_FAILED -  Oracle error occurred when updating the
**                        PUT transaction record.
*****************************************************************************/

    FUNCTION lmf_update_put_trans (
        i_batch_no   IN           batch.batch_no%TYPE
    ) RETURN rf.status IS
        l_func_name   VARCHAR2(50) := 'pl_lm_forklift.lmf_update_put_trans';
        l_ret_val     NUMBER := rf.status_normal;
    BEGIN
        pl_text_log.ins_msg_async('INFO', l_func_name, 'BEGIN lmf_update_put_trans. batch no = ' || i_batch_no, sqlcode, sqlerrm);
        BEGIN
            UPDATE trans
            SET
                src_loc = (
                    SELECT
                        kvi_to_loc
                    FROM
                        batch
                    WHERE
                        batch_no = i_batch_no
                )
            WHERE
                trans_type IN (
                    'PUT',
                    'TRP'
                )
                AND ( pallet_id,
                      rec_id ) IN (
                    SELECT
                        p.pallet_id,
                        p.rec_id
                    FROM
                        putawaylst   p,
                        batch        b
                    WHERE
                        ( p.pallet_id = b.ref_no
                          OR p.parent_pallet_id = b.ref_no )
                        AND b.batch_no = i_batch_no
                );

            IF SQL%rowcount = 0 THEN
                pl_text_log.ins_msg_async('WARN', l_func_name, ' Unable to update src_loc of trans PUT record with the drop point.' || i_batch_no
                , sqlcode, sqlerrm);
            END IF;/*END OF IF SQL%ROWCOUNT*/

        EXCEPTION
            WHEN OTHERS THEN
                pl_text_log.ins_msg_async('WARN', l_func_name, ' Unable to update src_loc of trans PUT record with the drop point.' || i_batch_no
                , sqlcode, sqlerrm);
                l_ret_val := rf.status_trn_update_fail;
        END;

        RETURN l_ret_val;
    END lmf_update_put_trans;
	
/*******************************<+>*********************************************
**  Function:                                                                 **
**     lm_attch_to_fklft_xfr_batch                                       **
**                                                                            **
**  Description:                                                              **
**     This function creates then attaches the user to a forklift             **
**     labor management transfer or home slot labor mgmt batch.               **
**     These type are batches are created when the user first starts          **
**     the operation.                                                         **
**                                                                            **
**     For transfers and home slots transfers transactions are created        **
**     when the pallet is scanned at the source location.  The transaction    **
**     is needed to store information that is used to create the batch        **
**     and for completing the batch.  The trans id is used to build           **
**     a unique labor mgmt batch number.                                      **
**                                                                            **
**  Parameters:                                                               **
**     i_vc_user_id_ptr   - User performing operation.  VARCHAR pointer.      **
**     i_vc_equip_id_ptr  - Equipment being used.  VARCHAR pointer.           **
**     i_trans_id         - Trans id of the transaction record created        **
**                          when the pallet is scanned at the source location.**
**                          It is used to build a unique labor mgmt batch     **
**                          number which has format                           **
**                             <labor mgmt batch identifier>{trans id}        **
**                          Some possible labor mgmt batch numbers are:       **
**                             FX<trans id>   Transfer                        **
**                             FH<trans id>   Home slot transfer              **
**                          Some possible values for the trans type of the    **
**                          trans record are:                                 **
**                             - PPT for a transfer batch.                    **
**                             - PPH for a home slot transfer batch.          **
**     i_suspend_flag - Haul flag.                                            **
**     i_merge_flag   - Merge flag.                                           **
**     i_labor_mgmt_batch_type  - Labor mgmt batch type.  Such as             **
**                                transfer or home slot transfer.  The        **
**                                different batch types are defined           **
**                                in lmf.h.                                   **
**                                                                            **
**  Return Values:                                                            **
**     STATUS_NORMAL  - Successfully attached user to the batch.              **
**     Anything else denotes a failure.                                       **
********************************<->********************************************/

    FUNCTION lm_attch_to_fklft_xfr_batch (
        i_vc_user_id_ptr          IN                        batch.user_id%TYPE,
        i_vc_equip_id_ptr         IN                        equip.equip_id%TYPE,
        i_trans_id                IN                        trans.trans_id%TYPE,
        i_suspend_flag            IN                        VARCHAR2,
        i_merge_flag              IN                        VARCHAR2,
        i_labor_mgmt_batch_type   IN                        VARCHAR2
    ) RETURN rf.status AS

        l_func_name         VARCHAR2(50) := 'pl_lm_forklift.lm_attch_to_fklft_xfr_batch';
        l_status            rf.status := rf.status_normal;
        l_batch_no          batch.batch_no%TYPE;
        l_parent_batch_no   batch.batch_no%TYPE;
        l_prev_batch_no     batch.batch_no%TYPE;
        l_signon_type       VARCHAR2(1);
        l_supervisor_id     batch.user_supervsr_id%TYPE;
        l_trans_id_char     VARCHAR2(20);
    BEGIN
		/*
		** lmc_batch_istart will populate l_supervisor_id and if an ISTART
		** is created will populate l_prev_batch_no with the ISTART batch number.
		** Initialize to spaces so oracle can determine the buffer size.
		*/
        l_trans_id_char := i_trans_id;

		/*
		** Build the labor mgmt batch number.  It will always be a forklift batch
		** as designated by the first character.
		** Some examples are:
		**    FX2342483
		**    FH5245211
		*/
        l_batch_no := lmf.forklift_batch_id
                      || i_labor_mgmt_batch_type
                      || i_trans_id;

		/*
		** Determine the signon type.
		*/
        IF ( i_suspend_flag = 'Y' ) THEN
            l_signon_type := lmf.lmf_suspend_batch;
        ELSIF ( i_merge_flag = 'Y' ) THEN
            l_signon_type := lmf.lmf_merge_batch;
        ELSE
            l_signon_type := lmf.lmf_signon_batch;
        END IF;

		/*
		** Create ISTART if the user does not have one.  If no ISTART then user
		** should be signing onto the first batch of the day.
		*/

        l_status := pl_rf_lm_common.lmc_batch_istart(i_vc_user_id_ptr, l_prev_batch_no, l_supervisor_id);
        IF ( l_status = rf.status_normal ) THEN
		  /*
		  ** Create the transfer batch.
		  */
            l_status := lmf_create_batch(i_labor_mgmt_batch_type, l_trans_id_char);
        END IF;

        IF ( l_status = rf.status_normal ) THEN
		  /*
		  ** Sign onto the labor mgmt  batch.
		  */
            l_status := lmf_signon_to_forklift_batch(l_signon_type, l_batch_no, l_parent_batch_no, i_vc_user_id_ptr, l_supervisor_id
            , i_vc_equip_id_ptr);
        END IF;

        RETURN l_status;
    END lm_attch_to_fklft_xfr_batch;
	
  /*******************************<+>****************************************** **
**  Function:                                                                  **
**     lmf_reset_forklift_xfr_batch                                            **
**                                                                             **
**  Description:                                                               **
**     This function resets a labor mgmt batch when the user func1's           **
**     out of a transfer operation.  The transfer can be a reserve to reserve  **
**     or a home slot transfer.                                                **
**                                                                             **
**     The batch is reset which puts the user on the default forklift labor    **
**     mgmt job and changes the batch to future.  If i_delete_batch_flag       **
**     is 'Y' then the batch is then deleted.                                  **
**                                                                             **
**  Parameters:                                                                **
**     i_user_id        - User performing operation.                           **
**     i_equip_id       - Equipment being used.                                **
**     i_labor_mgmt_batch_type  - Labor mgmt batch type.  Such as              **
**                                transfer or home slot transfer.              **
**     i_delete_batch_flag - Designates if to delete the labor mgmt batch.     **
**     i_drop_point     - The point where the pallets were dropped.            **
**                                   nly applicable for putaway batches as     **
**                        func1 during putaway prompts for a drop point        **
**                        to dropping the pallets.  For any other operation    **
**                        the pallets are put back in their source location.   **
**     i_trans_id_char  - Transaction id of the transaction record             **
**                        associated with the labor mgmt batch.  Its coming    **
**                        form the RF gun so it is a char value.  If the       **
**                        trans id is not known then this must be set to a     **
**                        null                                                 **
**                                                                             **
**  Return Values:                                                             **
**     STATUS_NORMAL- Successfully reset the batch.                            **
**     Anything else donotes a failure.                                        **
********************************<->*********************************************/

    FUNCTION lmf_reset_forklift_xfr_batch (
        i_user_id                 batch.user_id%TYPE,
        i_equip_id                equip.equip_id%TYPE,
        i_labor_mgmt_batch_type   batch.batch_no%TYPE,
        i_delete_batch_flag       VARCHAR2,
        i_drop_point              VARCHAR2,
        i_trans_id_char           VARCHAR2
    ) RETURN rf.status AS

        l_func_name      VARCHAR2(50) := 'pl_lm_forklift.lmf_reset_forklift_xfr_batch';
        l_status         rf.status := rf.status_normal;
        l_message        VARCHAR2(1024);
        l_save_message   VARCHAR2(1024);
        l_batch_no       batch.batch_no%TYPE;
        l_is_parent      VARCHAR2(1) := ' ';
    BEGIN
        l_message := 'INFO = '
                     || l_func_name
                     || ' i_user_id = '
                     || i_user_id
                     || 'i_equip_id = '
                     || i_equip_id
                     || 'i_labor_mgmt_batch_type = '
                     || i_labor_mgmt_batch_type
                     || 'i_delete_batch_flag = '
                     || i_delete_batch_flag
                     || 'i_drop_point = '
                     || i_drop_point
                     || 'i_trans_id_char = '
                     || i_trans_id_char;

        pl_text_log.ins_msg_async('INFO', l_func_name, l_message, NULL, NULL);
        l_save_message := l_message;

		/* Save message for possible use if
		an error occurs. */
        pl_text_log.ins_msg_async('INFO', l_func_name, l_message, NULL, NULL);

		/*
		** Build the labor mgmt batch number if the trans is known otherwise get
		** the users active batch.
		**
		** When building the batch number always be a forklift batch as designated
		** by the first character.
		** Some examples are:
		**    FX2342483  (XFR)
		**    FH5245211  (HST)
		**    FE8232581  (DHT)
		*/
        IF ( i_trans_id_char > 0 ) THEN
		  /*
		  ** The trans id of the transfer transaction is known.  Use this
		  ** to build the labor mgmt batch which should be the users active
		  ** batch.
		  */
            l_batch_no := lmf.forklift_batch_id
                          || i_labor_mgmt_batch_type
                          || i_trans_id_char;
        ELSE
		  /*
		  ** Do not have know the trans id.  Get the users active batch.
		  */
            l_status := pl_rf_lm_common.lmc_find_active_batch(i_user_id, l_batch_no, l_is_parent);
            IF ( l_status = 0 ) THEN
				/*
				** Check that the users active batch is the designated batch type.
				** If not then this indicates something is out of sync.
				*/
                IF ( substr(l_batch_no, 2, 1) <> i_labor_mgmt_batch_type ) THEN
				  /*
				  ** The user active batch does not batch the designated batch
				  ** type.  Ideally this situation should not occur.
				  */
                    l_status := rf.status_lm_batch_upd_fail;
                    pl_text_log.ins_msg_async('WARN', l_func_name, 'The batch type of the users active batch '
                                                        || l_batch_no
                                                        || ' does not batch the desigated batch type '
                                                        || i_labor_mgmt_batch_type, NULL, NULL);

                END IF;

            END IF;

        END IF;

		/*
		** Reset the labor mgmt batch which puts the user on the default forklift
		** labor mgmt job and changes the batch to future.
		*/

        IF ( l_status = 0 ) THEN
            pl_text_log.ins_msg_async('INFO', l_func_name, 'Reset user '
                                                || i_user_id
                                                || ' current forklift labor mgmt batch '
                                                || l_batch_no, NULL, NULL);

            l_status := lm_reset_current_fklft_batch(i_labor_mgmt_batch_type, i_user_id, i_drop_point, i_equip_id);
        END IF;

        IF ( l_status = 0 ) THEN
            IF ( i_delete_batch_flag = 'Y' ) THEN
				/*
				** Delete the labor mgmt batch.  It will be a future batch
				** at this point.
				*/
                BEGIN
              
                    DELETE FROM batch
                    WHERE
                        batch_no = l_batch_no
                        AND status = 'F';

                EXCEPTION
                    WHEN OTHERS THEN
                        l_status := rf.status_lm_batch_upd_fail;
                        pl_text_log.ins_msg_async('WARN', l_func_name, 'Failed to delete the batch '
                                                            || l_batch_no
                                                            || '.  It should exist and be in F status ', sqlcode, sqlerrm);

                END;

            END IF;
        ELSE
            pl_text_log.ins_msg_async('WARN', l_func_name, l_save_message || ' Reset of current labor batch failed.', NULL, NULL);
        END IF;

        return(l_status);
    EXCEPTION
        WHEN OTHERS THEN
            pl_text_log.ins_msg_async('WARN', l_func_name, 'Error in lmf_reset_forklift_xfr_batch.', sqlcode, sqlerrm);
    END lmf_reset_forklift_xfr_batch;
	
/*******************************<+>********************************************
**  Function:                                                                **
**     lmf_insert_pph_transaction                                            **
**                                                                           **
**  Description:                                                             **
**     This function inserts the PPH transaction that desigates              **
**     a home slot transfer has been started.  The PPH transaction is        **
**     required for forklift labor mgmt.                                     **
**                                                                           **
**  Parameters:                                                              **
**     i_how_hst_initiated  - How the HST was initiated.                     **
**                            Valid values:                                  **
**                               P  HST initiated during putaway.            **
**                               R  Regular HST.                             **
**     i_vc_src_loc_ptr - The HST source location.                           **
**                        If it is not a perm slot then an error is returned.**
**     i_vc_pallet_id_ptr - Pallet id.                                       **
**     i_qty            - Quantity in cases being transferred.  The qty      **
**                        quantity in the trans record will be splits.       **
**     o_trans_id       - Transaction id of the PPH transaction created.     **
**                        It needs to be sent back to the RF unit because    **
**                        it is needed when completing the HST.              **
**                                                                           **
**  Return Values:                                                           **
**     STATUS_NORMAL- Successfully created the PPH transaction.              **
**     Anything else donotes a failure.                                      **
**                                                                           **
*******************************<+>********************************************/

    FUNCTION lmf_insert_pph_transaction (
        i_how_hst_initiated   IN                    VARCHAR2,
        i_vc_src_loc_ptr      IN                    loc.logi_loc%TYPE,
        i_vc_pallet_id_ptr    IN                    putawaylst.pallet_id%TYPE,
        i_qty                 IN                    NUMBER,
        o_trans_id_ptr        OUT                   trans.trans_id%TYPE
    ) RETURN rf.status AS

        l_func_name   VARCHAR2(50) := 'pl_lm_forklift.lmf_insert_pph_transaction';
        l_status      rf.status := rf.status_normal;
        l_message     VARCHAR2(1024);
        l_trans_id    trans.trans_id%TYPE;
        l_cmt         trans.cmt%TYPE;
        l_home_slot   loc.logi_loc%TYPE;
        l_src_loc     loc.logi_loc%TYPE;
        l_temp_loc    loc.logi_loc%TYPE;
        e_no_record_found EXCEPTION;
    BEGIN
		/*
		** Get the trans id then insert the PPH transaction.
		** The PPH transaction record dest_loc is set to '?' because it is
		** not known at this time.  When the home slot transfer is completed the
		** transaction type is updated to HST and the dest_loc is updated to the
		** location the pallet placed at.
		*/
        BEGIN
        -- Build the value for column trans.cmt.  When the user completes
        -- the home slot transfer the PPH transaction is updated to a
        -- HST transaction and the cmt column is updated to the trans id.
        -- Because of how a forklift LM batch is completed in the
        -- lm_goaltime.pc functions the key value, in this case the trans id,
        -- needs to be in the trans.cmt column after the operation is
        -- completed.
            l_home_slot := i_vc_src_loc_ptr;
            IF ( i_how_hst_initiated = 'R' ) THEN
                l_cmt := 'PALLET PICKED FOR NORMAL HOME SLOT TRANSFER';
            ELSIF ( i_how_hst_initiated = 'P' ) THEN
                l_cmt := 'PALLET PICKED FOR HOME SLOT TRANSFER DURING A DROP';
            ELSE
				-- Got an handled value but do not let it stop processing
                l_cmt := l_func_name
                         || ' Unhandled value['
                         || i_how_hst_initiated
                         || '] for i_how_hst_initiated.';
                pl_text_log.ins_msg_async('WARN', l_func_name, l_cmt, NULL, NULL);
            END IF;

            SELECT
                trans_id_seq.NEXTVAL
            INTO l_trans_id
            FROM
                dual;

			/*
			** Home slot transfer is only for cases so the trans uom is set to 0.
			**
			**
			We always want to use the front location (home slot) for
			** a flow slot.  A union used
			** selecting non flow slot then selecting
			** for a flow slot.  Only one select will return a value.  I had
			** problems getting a record selected for a non flow slot using
			** one select stmt.   An outer join on the loc_reference table
			** was used against the location constant that seemed to not want
			** to return a match for non flow slots.
			**
			**
			**  use the back location for a flow
			** slot as the source location.  Using the front location gives the
			** operator additional travel time because a demand hst after a
			** putaway or NDM repl will have the back location as the source
			** location.
			*/
			/*
			** Make adjustments for flow slots.  The source location passed in
			** should be the home slot but if it is a back location then it will
			** be handled correctly.
			*/

            IF ( pl_common.f_get_syspar('ENABLE_PALLET_FLOW', 'N') = 'Y' ) THEN
                l_temp_loc := pl_pflow.f_get_back_loc(l_home_slot);
                IF ( l_temp_loc = 'NONE' ) THEN
					-- l_home_slot not a home location of a flow slot.  Check
					-- if it is a back location.
                    l_temp_loc := pl_pflow.f_get_pick_loc(l_home_slot);
                    IF ( l_temp_loc = 'NONE' ) THEN
						-- l_home_slot is not a back location. It is a home slot for
						-- a non-flow slot.
                        l_src_loc := l_home_slot;
                    ELSE
						-- l_home_slot is a back location.
                        l_src_loc := l_home_slot;
                        l_home_slot := l_temp_loc;
                    END IF;

                ELSE
					-- l_home_slot is the home location of a flow slot.
                    l_src_loc := l_temp_loc; -- The source loc of the HST
					-- is the back location.
                END IF;

            ELSE
                l_src_loc := l_home_slot;
            END IF;

            BEGIN
                INSERT INTO trans (
                    trans_id,
                    trans_type,
                    trans_date,
                    user_id,
                    prod_id,
                    cust_pref_vendor,
                    src_loc,
                    dest_loc,
                    pallet_id,
                    qty,
                    uom,
                    batch_no,
                    cmt
                )
                    SELECT
                        l_trans_id           trans_id,
                        'PPH' trans_type,
                        SYSDATE              trans_date,
                        user                 user_id,
                        l.prod_id            prod_id,
                        l.cust_pref_vendor   cust_pref_vendor,
                        l_src_loc            src_loc,
                        '?' dest_loc,
                        i_vc_pallet_id_ptr   pallet_id,
                        i_qty * nvl(p.spc, 1) qty,
                        0 uom,
                        99 batch_no,-- Done by forklift
                        l_cmt                cmt
                    FROM
                        pm    p,
                        loc   l
                    WHERE
                        l.logi_loc = l_home_slot
                        AND l.perm = 'Y'
                        AND p.prod_id = l.prod_id
                        AND p.cust_pref_vendor = l.cust_pref_vendor;

            -- It is an error if no record inserted.

                IF ( SQL%rowcount = 0 ) THEN
                    RAISE e_no_record_found;
                END IF;
            EXCEPTION
                WHEN e_no_record_found THEN
                    l_message := l_func_name
                                 || ' TABLE=loc_reference,pm,loc  ACTION=SELECT'
                                 || ' loc[ '
                                 || l_home_slot
                                 || '] Insert into trans to'
                                 || ' create PPH transaction using select from tables returned'
                                 || ' 0 ROWCOUNT';

                    pl_text_log.ins_msg_async('WARN', l_func_name, l_message, sqlcode, sqlerrm);
                WHEN OTHERS THEN
                    pl_text_log.ins_msg_async('WARN', l_func_name, 'Failed to create PPH transaction for location['
                                                        || l_home_slot
                                                        || ']', sqlcode, sqlerrm);

                    RAISE;
            END;

            IF ( l_status = 0 ) THEN
                o_trans_id_ptr := l_trans_id;
            END IF;
        EXCEPTION
            WHEN OTHERS THEN
                pl_text_log.ins_msg_async('WARN', l_func_name, 'LMF ORACLE Unable to create PPH transaction. Verify the location '
                                                    || l_home_slot
                                                    || ' is a perm location', sqlcode, sqlerrm);

                l_status := rf.status_trans_insert_failed;
        END;

        RETURN l_status;
    EXCEPTION
        WHEN OTHERS THEN
            pl_text_log.ins_msg_async('WARN', l_func_name, 'Error in lmf_insert_pph_transaction', sqlcode, sqlerrm);
    END lmf_insert_pph_transaction;
	
/*******************************************************************************
**  Function:                                                                  **
**     lm_reset_current_fklft_batch()                                      **
**                                                                             **
**  Description:                                                               **
**     This function resets a forklift batch.  Used in func1 processing.       **
**     It resets parent batches.                                               **
**     It performs special processing on Putaway batches.                      **
**     It creates a default forklift indirect batch for the user.              **
**                                                                             **
**  Parameters:                                                                **
**     i_type_flag char(1)      - Type of forklift batch.                      **
**     i_user_id char(30)       - User performing operation.                   **
**     i_drop_location char(10) - Location where pallets were dropped off.     **
**     i_equip_id char(10)      - Equipment being used.                        **
**                                                                             **
**  Return Values:                                                             **
**     STATUS_NORMAL -  Okay.                                                  **
**     All others denote errors.                                               **
********************************************************************************/

    FUNCTION lm_reset_current_fklft_batch (
        i_type_flag       IN                VARCHAR2,
        i_user_id         IN                batch.user_id%TYPE,
        i_drop_location   IN                VARCHAR2,
        i_equip_id        IN                equip.equip_id%TYPE
    ) RETURN rf.status AS

        l_ret_val                   rf.status := rf.status_normal;
        l_batch_to_reset            VARCHAR2(14);
        l_num_val               NUMBER;
        l_func_name                 VARCHAR2(50) := 'pl_lm_forklift.lm_reset_current_fklft_batch';
        l_is_parent                 VARCHAR2(1) := ' ';
        l_last_completed_batch_no   batch.batch_no%TYPE := ' ';
        l_sz_start_time             VARCHAR2(30);	/* The start time to use for the default forklift
														indirect batch if the user has a suspended
														batch.  If the user has no suspended batch then
														this will be set to a 0 length string.  The
														format is DDMMYYYYHH24MISS. */
    BEGIN
		/*
		** Validate the drop point if the drop point has a value.
		*/
         pl_text_log.ins_msg_async('INFO', l_func_name, 'starting lm_reset_current_fklft_batch i_drop_location = '||i_drop_location
         ||'i_user_id = '||i_user_id||' i_type_flag = '||i_type_flag||'i_equip_id = '||i_equip_id, sqlcode, sqlerrm);
        IF ( i_drop_location IS NOT NULL ) THEN
            pl_text_log.ins_msg_async('INFO', l_func_name, 'inside first if', sqlcode, sqlerrm);
            l_num_val := lmf_is_valid_point(i_drop_location);
             pl_text_log.ins_msg_async('INFO', l_func_name, 'after lmf_is_valid_point.l_ret_val = '||l_ret_val, sqlcode, sqlerrm);
        END IF;
        pl_text_log.ins_msg_async('INFO', l_func_name, 'after lmf_is_valid_point.l_ret_val = '||l_ret_val, sqlcode, sqlerrm);
        IF ( l_ret_val = rf.status_normal ) THEN
            l_ret_val := pl_rf_lm_common.lmc_find_active_batch(i_user_id, l_batch_to_reset, l_is_parent);
        END IF;
 pl_text_log.ins_msg_async('INFO', l_func_name, 'after lmc_find_active_batch.l_ret_val = '||l_ret_val, sqlcode, sqlerrm);
		/*
		** If the user has a suspended batch then get the start
		** time of the active batch which will be used for the start time of the
		** indirect batch the user will be made active on.
		*/

        IF ( l_ret_val = rf.status_normal ) THEN
            l_ret_val := lmf_get_dflt_fk_ind_start_time(i_user_id, l_batch_to_reset, l_sz_start_time);
        END IF;
pl_text_log.ins_msg_async('INFO', l_func_name, 'after lmf_get_dflt_fk_ind_start_time.l_ret_val = '||l_ret_val, sqlcode, sqlerrm);
        IF ( l_ret_val = rf.status_normal ) THEN
            IF ( l_is_parent = 'Y' ) THEN
                l_ret_val := lmf_reset_parent_batch(i_type_flag, l_batch_to_reset, i_drop_location, i_equip_id, i_user_id);
            pl_text_log.ins_msg_async('INFO', l_func_name, 'after lmf_reset_parent_batch.l_ret_val = '||l_ret_val, sqlcode, sqlerrm);

            ELSIF ( l_batch_to_reset = 'H' ) THEN
                l_ret_val := lmf_reset_haul_batch(l_batch_to_reset, i_drop_location);
                 pl_text_log.ins_msg_async('INFO', l_func_name, 'after lmf_reset_haul_batch.l_ret_val = '||l_ret_val, sqlcode, sqlerrm);

            ELSIF ( i_type_flag = lmf.forklift_putaway ) THEN
                l_ret_val := lmf_convert_norm_put_to_haul(l_batch_to_reset, i_drop_location, i_equip_id, i_user_id);
                 pl_text_log.ins_msg_async('INFO', l_func_name, 'after lmf_convert_norm_put_to_haul.l_ret_val = '||l_ret_val, sqlcode, sqlerrm);

            ELSE
                l_ret_val := lmf_reset_batch(l_batch_to_reset);
                pl_text_log.ins_msg_async('INFO', l_func_name, 'after lmf_reset_batch.l_ret_val = '||l_ret_val, sqlcode, sqlerrm);

            END IF;
        END IF;
pl_text_log.ins_msg_async('INFO', l_func_name, 'after lmf_get_dflt_fk_ind_start_time.l_ret_val = '||l_ret_val, sqlcode, sqlerrm);

        IF ( l_ret_val = rf.status_normal ) THEN
            l_ret_val := pl_rf_lm_common.lmc_get_last_complete_batch(i_user_id, l_last_completed_batch_no);
            IF ( l_ret_val = rf.status_normal ) THEN
                l_ret_val := lmf_create_dflt_fk_ind_batch(l_last_completed_batch_no, i_user_id, l_batch_to_reset, l_sz_start_time
                );
                pl_text_log.ins_msg_async('INFO', l_func_name, 'after lmf_create_dflt_fk_ind_batch.l_ret_val = '||l_ret_val, sqlcode, sqlerrm);

            END IF;

        END IF;
pl_text_log.ins_msg_async('INFO', l_func_name, 'after lmc_get_last_complete_batch.l_ret_val = '||l_ret_val, sqlcode, sqlerrm);

        return(l_ret_val);
    EXCEPTION
        WHEN OTHERS THEN
            pl_text_log.ins_msg_async('WARN', l_func_name, 'Error in lm_reset_current_fklft_batch.l_ret_val = '||l_ret_val, sqlcode, sqlerrm);
            return l_ret_val;
    END lm_reset_current_fklft_batch;
	
/******************************************************************************
**  Function:                                                                **
**     lmf_create_haul_forklift_batch()                                      **
**                                                                           **
**  Description:                                                             **
**     This function creates forklift batch for hauling.  The batch is       **
**     created from the putaway batch for the LP.                            **
**                                                                           **
**  Parameters:                                                              **
**     i_batch_no char    - Haul batch number to use.                        **
**     i_put_batch_no     - Putaway batch number.  For a MSKU pallet it will **
**                          be the batch of the parent LP.                   **
**     i_pallet_id char   - Pallet used to create forklift batch.  For a MSKU**
**                          pallet it will be the parent LP.                 **
**                                                                           **
**  Return Values:                                                           **
**     rf.STATUS_NORMAL      --  Okay.                                       **
**     RF.STATUS_NO_LM_BATCH_FOUND -Could not find a Labor Mgmt Batch        **
*****************************************************************************/

    FUNCTION lmf_create_haul_forklift_batch (
        i_batch_no       IN               batch.batch_no%TYPE,
        i_put_batch_no   IN               batch.batch_no%TYPE,
        i_pallet_id      IN               batch.ref_no%TYPE
    ) RETURN rf.status AS
        l_func_name   VARCHAR2(50) := 'pl_lm_forklift.lmf_create_haul_forklift';
        l_rf_status   rf.status := rf.status_normal;
    BEGIN
        pl_text_log.ins_msg_async('INFO', l_func_name, 'Starting lmf_create_haul_forklift_batch. Batch no '
                                            || i_batch_no
                                            || ' put_batch_no '
                                            || i_put_batch_no
                                            || ' pallet_id '
                                            || i_pallet_id, sqlcode, sqlerrm);

        BEGIN
            INSERT INTO batch (
                batch_no,
                status,
                jbcd_job_code,
                batch_date,
                kvi_from_loc,
                kvi_to_loc,
                kvi_no_case,
                kvi_no_split,
                kvi_no_pallet,
                kvi_no_item,
                kvi_no_po,
                kvi_cube,
                kvi_wt,
                kvi_no_loc,
                total_count,
                total_piece,
                total_pallet,
                ref_no,
                kvi_distance,
                goal_time,
                target_time,
                no_breaks,
                no_lunches,
                kvi_doc_time,
                kvi_no_piece,
                kvi_no_data_capture,
                equip_id,
                msku_batch_flag,
                cmt
            )
                SELECT
                    i_batch_no,
                    'F',
                    substr(b.jbcd_job_code, 1, 3)
                    || 'HAL',
                    trunc(SYSDATE),
                    b.kvi_from_loc,
                    p.dest_loc,
                    0.0,
                    0.0,
                    1.0,
                    1.0,
                    1.0,
                    trunc((p.qty / pm.spc) * pm.case_cube),
                    trunc(p.qty * nvl(pm.g_weight, 0)),
                    1.0,
                    1,
                    0,
                    1,
                    i_pallet_id,
                    0.0,
                    0.0,
                    0.0,
                    0.0,
                    0.0,
                    1.0,
                    0.0,
                    2.0,
                    b.equip_id,
                    b.msku_batch_flag,
                    DECODE(b.msku_batch_flag, 'Y', 'HAUL OF MSKU PALLET.  REF# IS THE PARENT LP.', NULL)
                FROM
                    batch        b,
                    pm,
                    erm          e,
                    putawaylst   p
                WHERE
                    b.batch_no = i_put_batch_no
                    AND pm.prod_id = p.prod_id
                    AND pm.cust_pref_vendor = p.cust_pref_vendor
                    AND e.erm_id = p.rec_id
                    AND p.pallet_batch_no = b.batch_no
                    AND ROWNUM = 1;

            pl_text_log.ins_msg_async('INFO', l_func_name, 'Haul batch created from the putaway batch. For batch no= ' || i_put_batch_no, sqlcode

            , sqlerrm);
        EXCEPTION
            WHEN OTHERS THEN
                pl_text_log.ins_msg_async('WARN', l_func_name, 'LMF Unable to create haul batch for batch no ' || i_put_batch_no, sqlcode, sqlerrm
                );
                l_rf_status := rf.status_no_lm_batch_found;
        END;

        return(l_rf_status);
    EXCEPTION
        WHEN OTHERS THEN
            pl_text_log.ins_msg_async('WARN', l_func_name, 'Error in lmf_create_haul_forklift_batch', sqlcode, sqlerrm);
            return(l_rf_status);
    END lmf_create_haul_forklift_batch;
	
/*****************************************************************************
**  FUNCTION:
**      lmf_create_batch()
**
**  DESCRIPTION:
**      This function creates forklift batches based on the batch type.
**
**  PARAMETERS:
**      i_batch_type  -  Flag denoting what kind of forklift batch to create.
**      i_key_val     -  Various types of values depending on what type of
**                       batch is being created.
**
**  RETURN VALUES:
**      SWMS_NORMAL           --  Okay.
**      LM_BATCH_INSERT_FAIL  --  Failed to create batch.
**********************************************************************************/

    FUNCTION lmf_create_batch (
        i_batch_type   IN             VARCHAR2,
        i_key_val      IN             VARCHAR2
    ) RETURN rf.status AS

        l_func_name                     VARCHAR2(50) := 'pl_lm_forklift.lmf_create_batch';
        l_ret_val                       rf.status := rf.status_normal;
        l_message                       VARCHAR2(1024);
        l_batch_no                      batch.batch_no%TYPE;
        l_vc_door                       VARCHAR2(5);
        l_trans_id                      NUMBER;
        l_counter                       NUMBER;
        l_count                         NUMBER;
        l_case_cube                     NUMBER;
        l_weight                        NUMBER;
        l_src_loc                       VARCHAR2(11);
        l_no_records_processed          PLS_INTEGER;
        l_no_batches_created            PLS_INTEGER;
        l_no_batches_existing           PLS_INTEGER;
        l_no_not_created_due_to_error   PLS_INTEGER;
        CURSOR c_pallet_pull_cur IS
        SELECT
            'FU' || f.float_no batch_no,
            fk.palpull_jobcode   jbcd_job_code,
            'F' status,
            trunc(SYSDATE) current_date,
            fd.src_loc           src_loc,
            l_vc_door            door_no,
            0.0 kvi_no_case,
            0.0 kvi_no_split,
            1.0 kvi_no_pallet,
            1.0 kvi_n_item,
            0.0 kvi_no_po,
            ( fd.qty_alloc / pm.spc ) * pm.case_cube kvi_cube,
            fd.qty_alloc * nvl(pm.g_weight, 0) kvi_wt,
            1.0 kvi_no_loc,
            1.0 total_count,
            0.0 total_piece,
            1.0 total_pallet,
            f.pallet_id          pallet_id,
            1.0 kvi_distance,
            0.0 goal_time,
            0.0 target_time,
            0.0 no_breaks,
            0.0 no_lunches,
            1.0 kvi_doc_time,
            0.0 kvi_no_piece,
            2.0 kvi_no_data_capture
        FROM
            job_code           j,
            fk_area_jobcodes   fk,
            swms_sub_areas     ssa,
            aisle_info         ai,
            pm,
            float_detail       fd,
            route              r,
            floats             f
        WHERE
            j.jbcd_job_code = fk.palpull_jobcode
            AND fk.sub_area_code = ssa.sub_area_code
            AND ssa.sub_area_code = ai.sub_area_code
            AND ai.name = substr(fd.src_loc, 1, 2)
            AND pm.prod_id = fd.prod_id
            AND pm.cust_pref_vendor = fd.cust_pref_vendor
            AND fd.float_no = f.float_no
            AND r.route_no = f.route_no
            AND f.pallet_pull IN (
                'D',
                'B',
                'Y'
            )
            AND f.float_no = to_number(i_key_val)
        ORDER BY
            fd.seq_no;

    BEGIN
        pl_text_log.ins_msg_async('INFO', l_func_name, 'Starting lmf_create_batch '
                                            || ' batch_type '
                                            || i_batch_type
                                            || ' key_val '
                                            || i_key_val, sqlcode, sqlerrm);

        BEGIN
            IF ( i_batch_type = lmf.forklift_putaway ) THEN
			  /*
				**  Receiving.
				**
				**  i_key_val is the pallet id.
			  */
                BEGIN
                    l_batch_no := i_key_val;
                    INSERT INTO batch (
                        batch_no,
                        jbcd_job_code,
                        status,
                        batch_date,
                        kvi_from_loc,
                        kvi_to_loc,
                        kvi_no_case,
                        kvi_no_split,
                        kvi_no_pallet,
                        kvi_no_item,
                        kvi_no_po,
                        kvi_cube,
                        kvi_wt,
                        kvi_no_loc,
                        total_count,
                        total_piece,
                        total_pallet,
                        ref_no,
                        kvi_distance,
                        goal_time,
                        target_time,
                        no_breaks,
                        no_lunches,
                        kvi_doc_time,
                        kvi_no_piece,
                        kvi_no_data_capture
                    )
                        SELECT
                            l_batch_no,
                            fk.putaway_jobcode,
                            'F',
                            trunc(SYSDATE),
                            e.door_no,
                            p.dest_loc,
                            0.0,
                            0.0,
                            1.0,
                            1.0,
                            1.0,
                            trunc((p.qty / pm.spc) * pm.case_cube),
                            trunc(p.qty * nvl(pm.g_weight, 0)),
                            1.0,
                            1,
                            0,
                            1,
                            i_key_val,
                            0.0,
                            0.0,
                            0.0,
                            0.0,
                            0.0,
                            1.0,
                            0.0,
                            2.0
                        FROM
                            job_code           j,
                            fk_area_jobcodes   fk,
                            swms_sub_areas     ssa,
                            aisle_info         ai,
                            pm,
                            erm                e,
                            putawaylst         p
                        WHERE
                            j.jbcd_job_code = fk.putaway_jobcode
                            AND fk.sub_area_code = ssa.sub_area_code
                            AND ssa.sub_area_code = ai.sub_area_code
                            AND ai.name = substr(p.dest_loc, 1, 2)
                            AND pm.prod_id = p.prod_id
                            AND pm.cust_pref_vendor = p.cust_pref_vendor
                            AND e.erm_id = p.rec_id
                            AND p.pallet_id = i_key_val;

                EXCEPTION
                    WHEN OTHERS THEN
                        l_ret_val := rf.status_lm_batch_upd_fail;
                        pl_text_log.ins_msg_async('WARN', l_func_name, 'Insert of putaway batch failed. For key val= ' || i_key_val, sqlcode
                        , sqlerrm);
                END;

                BEGIN
                    UPDATE putawaylst
                    SET
                        pallet_batch_no = l_batch_no
                    WHERE
                        pallet_id = i_key_val;

                EXCEPTION
                    WHEN OTHERS THEN
                        l_ret_val := rf.status_putawaylst_update_fail;
                        pl_text_log.ins_msg_async('WARN', l_func_name, 'Unable to attach batch to putaway task. For key value= ' || i_key_val
                        , sqlcode, sqlerrm);
                END;

            ELSIF ( i_batch_type = lmf.forklift_drop_to_home ) THEN
			  /*
				**  Bulk pull with a drop to home.
				**
				**  i_key_val is the float number.
				**  Create the FD batch then the FU batch.
			*/
                l_batch_no := 'FD' || i_key_val;
                BEGIN
                    INSERT INTO batch (
                        batch_no,
                        jbcd_job_code,
                        status,
                        batch_date,
                        kvi_from_loc,
                        kvi_to_loc,
                        kvi_no_case,
                        kvi_no_split,
                        kvi_no_pallet,
                        kvi_no_item,
                        kvi_no_po,
                        kvi_cube,
                        kvi_wt,
                        kvi_no_loc,
                        total_count,
                        total_piece,
                        total_pallet,
                        ref_no,
                        kvi_distance,
                        goal_time,
                        target_time,
                        no_breaks,
                        no_lunches,
                        kvi_doc_time,
                        kvi_no_piece,
                        kvi_no_data_capture
                    )
                        SELECT
                            l_batch_no,
                            fk.drophome_jobcode,
                            'F',
                            trunc(SYSDATE),
                            fd.src_loc,
                            f.home_slot,
                            0.0,
                            0.0,
                            1.0,
                            1.0,
                            0.0,
                            ( f.drop_qty / nvl(pm.spc, 1) ) * pm.case_cube,
                            ( f.drop_qty * nvl(pm.g_weight, 0) ),
                            1.0,
                            1.0,
                            ( f.drop_qty / nvl(pm.spc, 1) ),
                            1.0,
                            f.pallet_id,
                            0.0,
                            0.0,
                            0.0,
                            0.0,
                            0.0,
                            1.0,
                            0.0,
                            2.0
                        FROM
                            job_code           j,
                            fk_area_jobcodes   fk,
                            swms_sub_areas     ssa,
                            aisle_info         ai,
                            pm,
                            float_detail       fd,
                            floats             f
                        WHERE
                            j.jbcd_job_code = fk.drophome_jobcode
                            AND fk.sub_area_code = ssa.sub_area_code
                            AND ssa.sub_area_code = ai.sub_area_code
                            AND ai.name = substr(f.home_slot, 1, 2)
                            AND pm.prod_id = fd.prod_id
                            AND pm.cust_pref_vendor = fd.cust_pref_vendor
                            AND fd.float_no = f.float_no
                            AND f.pallet_pull IN (
                                'D',
                                'B'
                            )
                            AND f.float_no = to_number(i_key_val);

                    l_ret_val := lm_determine_blk_pull_door_no(i_key_val, l_vc_door);
                EXCEPTION
                    WHEN OTHERS THEN
                        pl_text_log.ins_msg_async('WARN', l_func_name, 'Insert of  batch failed.For key value= '
                                                            || i_key_val
                                                            || ' and batch no '
                                                            || l_batch_no, sqlcode, sqlerrm);
                END;

                IF ( l_ret_val = rf.status_normal ) THEN
                    l_batch_no := 'FU' || i_key_val;
                    BEGIN
                        INSERT INTO batch (
                            batch_no,
                            jbcd_job_code,
                            status,
                            batch_date,
                            kvi_from_loc,
                            kvi_to_loc,
                            kvi_no_case,
                            kvi_no_split,
                            kvi_no_pallet,
                            kvi_no_item,
                            kvi_no_po,
                            kvi_cube,
                            kvi_wt,
                            kvi_no_loc,
                            total_count,
                            total_piece,
                            total_pallet,
                            ref_no,
                            kvi_distance,
                            goal_time,
                            target_time,
                            no_breaks,
                            no_lunches,
                            kvi_doc_time,
                            kvi_no_piece,
                            kvi_no_data_capture
                        )
                            SELECT
                                l_batch_no,
                                fk.palpull_jobcode,
                                'F',
                                trunc(SYSDATE),
                                f.home_slot,
                                l_vc_door,
                                0.0,
                                0.0,
                                1.0,
                                1.0,
                                0.0,
                                ( fd.qty_alloc / pm.spc ) * pm.case_cube,
                                fd.qty_alloc * nvl(pm.g_weight, 0),
                                1.0,
                                1.0,
                                0.0,
                                1.0,
                                f.pallet_id,
                                0.0,
                                0.0,
                                0.0,
                                0.0,
                                0.0,
                                1.0,
                                0.0,
                                1.0
                            FROM
                                job_code           j,
                                fk_area_jobcodes   fk,
                                swms_sub_areas     ssa,
                                aisle_info         ai,
                                pm,
                                float_detail       fd,
                                route              r,
                                floats             f
                            WHERE
                                j.jbcd_job_code = fk.palpull_jobcode
                                AND fk.sub_area_code = ssa.sub_area_code
                                AND ssa.sub_area_code = ai.sub_area_code
                                AND ai.name = substr(f.home_slot, 1, 2)
                                AND pm.prod_id = fd.prod_id
                                AND pm.cust_pref_vendor = fd.cust_pref_vendor
                                AND fd.float_no = f.float_no
                                AND r.route_no = f.route_no
                                AND f.pallet_pull IN (
                                    'D',
                                    'B'
                                )
                                AND f.float_no = to_number(i_key_val);

                    EXCEPTION
                        WHEN OTHERS THEN
                            pl_text_log.ins_msg_async('WARN', l_func_name, 'Insert of  batch failed.For key value= '
                                                                || i_key_val
                                                                || ' and batch no '
                                                                || l_batch_no, sqlcode, sqlerrm);
                    END;

                END IF;

            ELSIF ( i_batch_type = lmf.forklift_pallet_pull ) THEN
			  /*
				**  Bulk pull with no drop to home.
				**
				**  i_key_val is the float number.
				**  Create the FU batch.
				*/
				/*
				**  Assign value to l_batch_no but don't use it
				**  when creating the batch though it possibly
				**  could be.  
				*/
                l_batch_no := 'FU' || i_key_val;
                l_ret_val := lm_determine_blk_pull_door_no(i_key_val, l_vc_door);
                IF ( l_ret_val = rf.status_normal ) THEN
                    l_counter := 0;
			-- This cursor selects the records used to create the
			-- forklift LM batches.
                    BEGIN
                        FOR pallet_pull_rec IN c_pallet_pull_cur LOOP
                            l_counter := l_counter + 1;
                            INSERT INTO batch (
                                batch_no,
                                jbcd_job_code,
                                status,
                                batch_date,
                                kvi_from_loc,
                                kvi_to_loc,
                                kvi_no_case,
                                kvi_no_split,
                                kvi_no_pallet,
                                kvi_no_item,
                                kvi_no_po,
                                kvi_cube,
                                kvi_wt,
                                kvi_no_loc,
                                total_count,
                                total_piece,
                                total_pallet,
                                ref_no,
                                kvi_distance,
                                goal_time,
                                target_time,
                                no_breaks,
                                no_lunches,
                                kvi_doc_time,
                                kvi_no_piece,
                                kvi_no_data_capture
                            ) VALUES (
                                pallet_pull_rec.batch_no
                                || DECODE(l_counter, 1, NULL, chr(ascii('A') +(l_counter - 2))),
                                pallet_pull_rec.jbcd_job_code,
                                pallet_pull_rec.status,
                                pallet_pull_rec.current_date,
                                pallet_pull_rec.src_loc,
                                pallet_pull_rec.door_no,
                                pallet_pull_rec.kvi_no_case,
                                pallet_pull_rec.kvi_no_split,
                                pallet_pull_rec.kvi_no_pallet,
                                pallet_pull_rec.kvi_n_item,
                                pallet_pull_rec.kvi_no_po,
                                pallet_pull_rec.kvi_cube,
                                pallet_pull_rec.kvi_wt,
                                pallet_pull_rec.kvi_no_loc,
                                pallet_pull_rec.total_count,
                                pallet_pull_rec.total_piece,
                                pallet_pull_rec.total_pallet,
                                pallet_pull_rec.pallet_id,
                                pallet_pull_rec.kvi_distance,
                                pallet_pull_rec.goal_time,
                                pallet_pull_rec.target_time,
                                pallet_pull_rec.no_breaks,
                                pallet_pull_rec.no_lunches,
                                pallet_pull_rec.kvi_doc_time,
                                pallet_pull_rec.kvi_no_piece,
                                pallet_pull_rec.kvi_no_data_capture
                            );

                        END LOOP;

                    EXCEPTION
                        WHEN OTHERS THEN
                            pl_text_log.ins_msg_async('WARN', l_func_name, 'Insert of  batch failed. For key value ' || i_key_val, sqlcode, sqlerrm
                            );
                    END;

                END IF;

            ELSIF ( i_batch_type = lmf.forklift_combine_pull ) THEN
		  /*
			**  Combine pull.
			**
			**  i_key_val is the float number.
			*/
				  /*
			**  Combined pallet pull is separated from pallet pull due to
			**  fact that there are multiple float detail records for the
			**  float.  The quantity allocated must be summed.
			*/
                BEGIN
                    SELECT
                        ( SUM(fd.qty_alloc) / pm.spc ) * pm.case_cube,
                        SUM(fd.qty_alloc) * nvl(pm.g_weight, 0),
                        fd.src_loc,
                        COUNT(fd.float_no)
                    INTO
                        l_case_cube,
                        l_weight,
                        l_src_loc,
                        l_count
                    FROM
                        pm,
                        float_detail   fd,
                        floats         f
                    WHERE
                        pm.prod_id = fd.prod_id
                        AND pm.cust_pref_vendor = fd.cust_pref_vendor
                        AND fd.float_no = f.float_no
                        AND f.float_no = to_number(i_key_val)
                    GROUP BY
                        pm.spc,
                        pm.case_cube,
                        pm.g_weight,
                        fd.src_loc;

                EXCEPTION
                    WHEN OTHERS THEN
                        l_ret_val := rf.status_lm_batch_upd_fail;
                        pl_text_log.ins_msg_async('WARN', l_func_name, 'Unable to calculate qty on float for combine pull.For key value= '|| i_key_val, sqlcode, sqlerrm);
                END;

                IF l_src_loc IS NULL THEN
            /*
            ** The float record has a bad src_loc.  Don't stop processing
            ** but write log message.  The forklift labor mgmt batch
            ** completion process will error out though which will result
            ** in a call to the help desk.
            */
                    pl_text_log.ins_msg_async('WARN', l_func_name, 'The float detail record has a null src_loc.  Will get an error when completing the labor mgmt batch.For key value= '
                    || i_key_val, sqlcode, sqlerrm);
                END IF;
		  /*
			** Create the drop to home batch if there is a drop qty.
		  */

                l_batch_no := 'FD' || i_key_val;
                BEGIN
                    INSERT INTO batch (
                        batch_no,
                        jbcd_job_code,
                        status,
                        batch_date,
                        kvi_from_loc,
                        kvi_to_loc,
                        kvi_no_case,
                        kvi_no_split,
                        kvi_no_pallet,
                        kvi_no_item,
                        kvi_no_po,
                        kvi_cube,
                        kvi_wt,
                        kvi_no_loc,
                        total_count,
                        total_piece,
                        total_pallet,
                        ref_no,
                        kvi_distance,
                        goal_time,
                        target_time,
                        no_breaks,
                        no_lunches,
                        kvi_doc_time,
                        kvi_no_piece,
                        kvi_no_data_capture
                    )
                        SELECT
                            l_batch_no,
                            fk.drophome_jobcode,
                            'F',
                            trunc(SYSDATE),
                            fd.src_loc,
                            f.home_slot,
                            0.0,
                            0.0,
                            1.0,
                            1.0,
                            0.0,
                            ( f.drop_qty / nvl(pm.spc, 1) ) * pm.case_cube,
                            ( f.drop_qty * nvl(pm.g_weight, 0) ),
                            1.0,
                            1.0,
                            ( f.drop_qty / nvl(pm.spc, 1) ),
                            1.0,
                            f.pallet_id,
                            0.0,
                            0.0,
                            0.0,
                            0.0,
                            0.0,
                            1.0,
                            0.0,
                            2.0
                        FROM
                            job_code           j,
                            fk_area_jobcodes   fk,
                            swms_sub_areas     ssa,
                            aisle_info         ai,
                            pm,
                            float_detail       fd,
                            floats             f
                        WHERE
                            j.jbcd_job_code = fk.drophome_jobcode
                            AND fk.sub_area_code = ssa.sub_area_code
                            AND ssa.sub_area_code = ai.sub_area_code
                            AND ai.name = substr(f.home_slot, 1, 2)
                            AND pm.prod_id = fd.prod_id
                            AND pm.cust_pref_vendor = fd.cust_pref_vendor
                            AND fd.float_no = f.float_no
                            AND f.pallet_pull IN (
                                'D',
                                'B',
                                'Y'
                            )
                            AND f.float_no = to_number(i_key_val)
                            AND nvl(f.drop_qty, 0) > 0
                            AND ROWNUM <= 1;
			
			/* Match one float detail */

                EXCEPTION
                    WHEN OTHERS THEN
                        pl_text_log.ins_msg_async('WARN', l_func_name, 'ERROR Inserting Batch.For key value= '
                                                            || i_key_val
                                                            || ' and batch no '
                                                            || l_batch_no, sqlcode, sqlerrm);
                END;

                l_batch_no := 'FU' || i_key_val;
                l_ret_val := lm_determine_blk_pull_door_no(i_key_val, l_vc_door);
                IF ( l_ret_val = rf.status_normal ) THEN
                    BEGIN
                        INSERT INTO batch (
                            batch_no,
                            jbcd_job_code,
                            status,
                            batch_date,
                            kvi_from_loc,
                            kvi_to_loc,
                            kvi_no_case,
                            kvi_no_split,
                            kvi_no_pallet,
                            kvi_no_item,
                            kvi_no_po,
                            kvi_cube,
                            kvi_wt,
                            kvi_no_loc,
                            total_count,
                            total_piece,
                            total_pallet,
                            ref_no,
                            kvi_distance,
                            goal_time,
                            target_time,
                            no_breaks,
                            no_lunches,
                            kvi_doc_time,
                            kvi_no_piece,
                            kvi_no_data_capture
                        )
                            SELECT
                                l_batch_no,
                                fk.palpull_jobcode,
                                'F',
                                trunc(SYSDATE),
                                f.home_slot,
                                l_vc_door,
                                0.0,
                                0.0,
                                1.0,
                                1.0,
                                0.0,
                                l_case_cube,
                                l_weight,
                                1.0,
                                1.0,
                                0.0,
                                1.0,
                                f.pallet_id,
                                1.0,
                                0.0,
                                0.0,
                                0.0,
                                0.0,
                                1.0,
                                0.0,
                                2.0
                            FROM
                                job_code           j,
                                fk_area_jobcodes   fk,
                                swms_sub_areas     ssa,
                                aisle_info         ai,
                                route              r,
                                floats             f
                            WHERE
                                j.jbcd_job_code = fk.palpull_jobcode
                                AND fk.sub_area_code = ssa.sub_area_code
                                AND ssa.sub_area_code = ai.sub_area_code
                                AND ai.name = substr(l_src_loc, 1, 2)
                                AND r.route_no = f.route_no
                                AND f.pallet_pull IN (
                                    'D',
                                    'B',
                                    'Y'
                                )
                                AND f.float_no = to_number(i_key_val);

                    EXCEPTION
                        WHEN OTHERS THEN
                            pl_text_log.ins_msg_async('WARN', l_func_name, 'ERROR Inserting Batch.For key value= '
                                                                || i_key_val
                                                                || ' and batch no '
                                                                || l_batch_no, sqlcode, sqlerrm);
                    END;
                END IF;

            ELSIF ( i_batch_type = lmf.forklift_demand_rpl ) THEN
			  /*
				**  Demand replenishment.
				**
				**  i_key_val is the float number.
			 */
                l_batch_no := 'FR' || i_key_val;
                BEGIN
                    INSERT INTO batch (
                        batch_no,
                        jbcd_job_code,
                        status,
                        batch_date,
                        kvi_from_loc,
                        kvi_to_loc,
                        kvi_no_case,
                        kvi_no_split,
                        kvi_no_pallet,
                        kvi_no_item,
                        kvi_no_po,
                        kvi_cube,
                        kvi_wt,
                        kvi_no_loc,
                        total_count,
                        total_piece,
                        total_pallet,
                        ref_no,
                        kvi_distance,
                        goal_time,
                        target_time,
                        no_breaks,
                        no_lunches,
                        kvi_doc_time,
                        kvi_no_piece,
                        kvi_no_data_capture,
                        msku_batch_flag
                    )
                        SELECT
                            l_batch_no,
                            fk.dmdrpl_jobcode,
                            'F',
                            trunc(SYSDATE),
                            fd.src_loc,
                            f.home_slot,
                            0.0,
                            0.0,
                            1.0,
                            1.0,
                            0.0,
                            ( fd.qty_alloc / pm.spc ) * pm.case_cube,
                            fd.qty_alloc * nvl(pm.g_weight, 0),
                            1.0,
                            1.0,
                            0.0,
                            1.0,
                            f.pallet_id,
                            1.0,
                            0.0,
                            0.0,
                            0.0,
                            0.0,
                            1.0,
                            0.0,
                            2.0,
                            DECODE(f.parent_pallet_id, NULL, NULL, 'Y') mksu_batch_flag
                        FROM
                            job_code           j,
                            fk_area_jobcodes   fk,
                            swms_sub_areas     ssa,
                            aisle_info         ai,
                            pm,
                            float_detail       fd,
                            floats             f
                        WHERE
                            j.jbcd_job_code = fk.dmdrpl_jobcode
                            AND fk.sub_area_code = ssa.sub_area_code
                            AND ssa.sub_area_code = ai.sub_area_code
                            AND ai.name = substr(f.home_slot, 1, 2)
                            AND pm.prod_id = fd.prod_id
                            AND pm.cust_pref_vendor = fd.cust_pref_vendor
                            AND fd.float_no = f.float_no
                            AND f.pallet_pull = 'R'
                            AND f.float_no = to_number(i_key_val);

                EXCEPTION
                    WHEN OTHERS THEN
                        pl_text_log.ins_msg_async('WARN', l_func_name, 'ERROR Inserting Batch.For key value= '
                                                            || i_key_val
                                                            || ' and batch no '
                                                            || l_batch_no, sqlcode, sqlerrm);
                END;
        
		  /*
			**  Inventory Control.
		  */

            ELSIF ( i_batch_type = lmf.forklift_nondemand_rpl ) THEN
			/*
			**  Non-demand replenishment.
			**
			**  i_key_val is the pallet id.
			*/
			/*
			** The batch number is FN || replenst.task_id
			** which is built in the select statement.
			** Set l_batch_no to null.
			*/
                BEGIN
                    INSERT INTO batch (
                        batch_no,
                        jbcd_job_code,
                        status,
                        batch_date,
                        kvi_from_loc,
                        kvi_to_loc,
                        kvi_no_case,
                        kvi_no_split,
                        kvi_no_pallet,
                        kvi_no_item,
                        kvi_no_po,
                        kvi_cube,
                        kvi_wt,
                        kvi_no_loc,
                        total_count,
                        total_piece,
                        total_pallet,
                        ref_no,
                        kvi_distance,
                        goal_time,
                        target_time,
                        no_breaks,
                        no_lunches,
                        kvi_doc_time,
                        kvi_no_piece,
                        kvi_no_data_capture,
                        msku_batch_flag
                    )
                        SELECT
                            'FN' || r.task_id,
                            fk.ndrpl_jobcode,
                            'F',
                            trunc(SYSDATE),
                            r.src_loc,
                            r.dest_loc,
                            0.0,
                            0.0,
                            1.0,
                            1.0,
                            0.0,
                            ( r.qty / pm.spc ) * pm.case_cube,
                            r.qty * nvl(pm.g_weight, 0),
                            1.0,
                            1.0,
                            0.0,
                            1.0,
                            i_key_val,
                            1.0,
                            0.0,
                            0.0,
                            0.0,
                            0.0,
                            1.0,
                            0.0,
                            2.0,
                            DECODE(r.parent_pallet_id, NULL, NULL, 'Y') msku_batch_flag
                        FROM
                            job_code           j,
                            fk_area_jobcodes   fk,
                            swms_sub_areas     ssa,
                            aisle_info         ai,
                            pm,
                            replenlst          r
                        WHERE
                            j.jbcd_job_code = fk.ndrpl_jobcode
                            AND fk.sub_area_code = ssa.sub_area_code
                            AND ssa.sub_area_code = ai.sub_area_code
                            AND ai.name = substr(r.dest_loc, 1, 2)
                            AND pm.prod_id = r.prod_id
                            AND pm.cust_pref_vendor = r.cust_pref_vendor
                            AND r.type = 'NDM'
                            AND r.pallet_id = i_key_val;

                EXCEPTION
                    WHEN OTHERS THEN
                        pl_text_log.ins_msg_async('WARN', l_func_name, 'ERROR Inserting Batch.For key value= '
                                                            || i_key_val
                                                            || ' and batch no '
                                                            || l_batch_no, sqlcode, sqlerrm);
                END;
            ELSIF ( i_batch_type = lmf.forklift_home_slot_xfer ) THEN
		  /*
			** Create home slot batch.   A home slot transfer happens
			** when inventory is being moved from a home slot to a
			** reserve slot.  The logic is very similar to a reserve to
			** reserve transfer.
			**
			** The batch is created using the information in the transaction
			** PPH record which desigates the pallet picked up at the home
			** slot.  The PPH transaction is created prior to creating the
			** labor mgmt batch.  It is the same basic logic as the PPT
			** transaction for a reserve to reserve transfer.
			**
			** The batch kvi_to_loc is set to the source location since the
			** destination location is not known until the pallet is scanned
			** to the destination slot.  The kvi_to_loc will be updated when
			** the pallet is scanned to the destination location.  It is not
			** desirable to leave kvi_to_loc null in the batch table.
			**
			** The PPH transaction has the qty transferred in splits so use
			** it to populate the batch kvi_no_case and kvi_sp_split.
			** The qty should always be an even number of cases so the
			** number of splits ought to be 0.
			**
			** i_key_val is the trans_id of the trans PPH record.
			*/
                l_trans_id := i_key_val;
                BEGIN
                    pl_lmf.create_home_slot_xfer_batch(l_trans_id, l_no_records_processed, l_no_batches_created, l_no_batches_existing
                    , l_no_not_created_due_to_error);
                EXCEPTION
                    WHEN OTHERS THEN
                        pl_text_log.ins_msg_async('WARN', l_func_name, 'ERROR in create_home_slot_xfer_batch. For trans id ' || l_trans_id, sqlcode
                        , sqlerrm);
                END;

            ELSIF ( i_batch_type = lmf.forklift_inv_adj ) THEN
                l_batch_no := 'FI' || i_key_val;
            ELSIF ( i_batch_type = lmf.forklift_swap ) THEN
                l_batch_no := 'FS' || i_key_val;
            ELSIF ( i_batch_type = lmf.forklift_transfer ) THEN
			  /*
				** Create transfer batch.  A pallet is being transferred from
				** a reserve slot to another reserve slot.
				**
				** The batch kvi_to_loc is set to the source location since the
				** destination location is not known until the pallet is scanned
				** to the destination slot.  The kvi_to_loc will be updated when
				** the pallet is scanned to the destination location.  It is not
				** desirable to leave kvi_to_loc null.
				**
				** i_key_val is the trans_id of the trans PPT record.
				*/
                l_trans_id := i_key_val;
                BEGIN
                    pl_lmf.create_transfer_batch(l_trans_id, l_no_records_processed, l_no_batches_created, l_no_batches_existing,
                    l_no_not_created_due_to_error);
                EXCEPTION
                    WHEN OTHERS THEN
                        pl_text_log.ins_msg_async('WARN', l_func_name, 'ERROR in create_transfer_batch.For trans id ' || l_trans_id, sqlcode
                        , sqlerrm);
                END;

            ELSIF ( i_batch_type = lmf.forklift_dmd_rpl_hs_xfer ) THEN
		  /*
			** Create demand replenishment transfer batch.  This happens
			** when the forklift operator has performed a demand replenishment
			** and not all the cases fit in the slot.  Cases are being
			** transferred back to reserve with the transfer qty > qoh in the
			** home slot.  The qty transferred > qoh indicates the
			** replenishment was only partially completed.
			**
			** The batch is created using the information in the transaction
			** PPD record which desigates the operator has started the
			** operation.  The PPD transaction is created prior to creating the
			** labor mgmt batch.  It is the same basic logic as the PPH
			** transaction for a home slot transfer.
			**
			** The batch kvi_to_loc is set to the source location since the
			** destination location is not known until the pallet is scanned
			** to the destination slot.  The kvi_to_loc will be updated when
			** the pallet is scanned to the destination location.  It is not
			** desirable to leave kvi_to_loc null in the batch table.
			**
			** The PPD transaction has the qty transferred in splits so use
			** it to populate the batch kvi_no_case and kvi_sp_split.
			** The qty should always be an even number of cases so the
			** number of splits ought to be 0.
			**
			** i_key_val is the trans_id of the trans PPD record.
			*/
                l_trans_id := i_key_val;
                BEGIN
                    pl_lmf.create_dmd_rpl_hs_xfer_batch(l_trans_id, l_no_records_processed, l_no_batches_created, l_no_batches_existing
                    , l_no_not_created_due_to_error);
                EXCEPTION
                    WHEN OTHERS THEN
                        pl_text_log.ins_msg_async('WARN', l_func_name, 'ERROR in create_dmd_rpl_hs_xfer_batch.For trans id ' || l_trans_id, sqlcode
                        , sqlerrm);
                END;

            ELSIF ( i_batch_type = lmf.forklift_cycle_count ) THEN
                l_batch_no := 'FC' || i_key_val;
            ELSE
                pl_text_log.ins_msg_async('WARN', l_func_name, 'Error in lm_determine_blk_pull_door_no '
                                                    || i_key_val
                                                    || ' batch no '
                                                    || l_batch_no, sqlcode, sqlerrm);

                l_ret_val := rf.status_lm_batch_upd_fail;
            END IF;
		/* end IF (i_batch_type) */

        EXCEPTION
            WHEN OTHERS THEN
                pl_text_log.ins_msg_async('WARN', l_func_name, 'LMF ORACLE unable to create forklift batch for pallet for batch type.  Make sure the job codes are setup.'
                , sqlcode, sqlerrm);
                l_ret_val := rf.status_lm_batch_upd_fail;
        END;

        RETURN l_ret_val;
    EXCEPTION
        WHEN OTHERS THEN
            pl_text_log.ins_msg_async('WARN', l_func_name, 'Error in lmf_create_batch.', sqlcode, sqlerrm);
            return(l_ret_val);
    END lmf_create_batch;
	
/*****************************************************************************
**  FUNCTION:
**      Lmf_Create_Haul_Batch_Id()
**
**  DESCRIPTION:
**      This function creates a batch id for Haul from the specified putaway
**      batch id.
**
**  PARAMETERS:
**      o_haul_batch_no char    -  New batch id.
**
**  RETURN VALUES:
**      rf.STATUS_NORMAL             --  Okay.
**      rf.STATUS_LM_BATCH_UPD_FAIL  --  Failed to modify batch.
*****************************************************************************/

    FUNCTION lmf_create_haul_batch_id (
        o_haul_batch_no   OUT               batch.batch_no%TYPE
    ) RETURN rf.status AS
        l_func_name   VARCHAR2(50) := 'pl_lm_forklift.Lmf_Create_Haul_Batch_Id';
        l_ret_val     rf.status := rf.status_normal;
    BEGIN
        pl_text_log.ins_msg_async('INFO', l_func_name, 'Starting Lmf_Create_Haul_Batch_Id ...', sqlcode, sqlerrm);
        BEGIN
            SELECT
                'HX' || pallet_batch_no_seq.NEXTVAL
            INTO o_haul_batch_no
            FROM
                dual;

        EXCEPTION
            WHEN OTHERS THEN
                pl_text_log.ins_msg_async('WARN', l_func_name, 'LMF ORACLE Unable to create HAUL batch id from pallet_batch_no_seq', sqlcode
                , sqlerrm);
                l_ret_val := rf.status_lm_batch_upd_fail;
        END;

        IF l_ret_val = 0 THEN
            o_haul_batch_no := trim(o_haul_batch_no);
        END IF;
        RETURN l_ret_val;
    END lmf_create_haul_batch_id;
	
/*****************************************************************************
**  FUNCTION:
**      Lmf_Make_Batch_Parent()
**  DESCRIPTION:
**      This function changes a normal batch to a parent batch.
**  PARAMETERS:
**      i_batch_no char       - Batch to become a parent batch.
**  RETURN VALUES:
**      STATUS_NORMAL         -  Okay.
**      STATUS_LM_BATCH_UPD_FAIL  -  Unable to update specified batch.
*****************************************************************************/

    FUNCTION lmf_make_batch_parent (
        i_batch_no   IN           batch.batch_no%TYPE
    ) RETURN rf.status AS
        l_func_name   VARCHAR2(50) := 'pl_lm_forklift.Lmf_Make_Batch_Parent';
        l_ret_val     rf.status := rf.status_normal;
    BEGIN
        pl_text_log.ins_msg_async('INFO', l_func_name, 'Starting lmf_make_batch_parent', sqlcode, sqlerrm);
        BEGIN
            UPDATE batch
            SET
                parent_batch_no = i_batch_no,
                parent_batch_date = trunc(SYSDATE)
            WHERE
                batch_no = i_batch_no;

        EXCEPTION
            WHEN OTHERS THEN
                pl_text_log.ins_msg_async('WARN', l_func_name, 'unable to change batch to parent.Batch no ' || i_batch_no, sqlcode, sqlerrm)
                ;
                l_ret_val := rf.status_lm_batch_upd_fail;
        END;

        RETURN l_ret_val;
    END lmf_make_batch_parent;
	
/*****************************************************************************
**  FUNCTION:
**      Lmf_Remove_Except_Time_Spent()
**  DESCRIPTION:
**      This function reduces the time spent for a forklift batch that is being
**      completed by the amount of actual time spent for any batches completed
**      within the start and stop times of the forklift batch being completed.
**  PARAMETERS:
**      i_batch_no     - Batch to be suspended.
**  RETURN VALUES:
**      STATUS_NORMAL         -  Okay.
**      LM_BATCH_UPDATE_FAIL  -  Unable to update specified batch.
*****************************************************************************/

    FUNCTION lmf_remove_except_time_spent (
        i_batch_no   IN           batch.batch_no%TYPE
    ) RETURN rf.status AS
        l_func_name           VARCHAR2(50) := 'pl_lm_forklift.Lmf_Remove_Except_Time_Spent';
        l_ret_val             NUMBER;
        l_except_time_spent   NUMBER;
    BEGIN
        pl_text_log.ins_msg_async('INFO', l_func_name, 'Starting Lmf_Remove_Except_Time_Spent...batch_no ' || i_batch_no, sqlcode, sqlerrm);
        l_except_time_spent := 0;
        l_ret_val := rf.status_normal;
        BEGIN
            SELECT
                SUM(b1.actl_time_spent)
            INTO l_except_time_spent
            FROM
                batch   b1,
                batch   b2
            WHERE
                b2.actl_start_time <= b1.actl_start_time
                AND b2.actl_stop_time >= b1.actl_start_time
                AND b2.batch_no <> b1.batch_no
                AND b2.user_id = b1.user_id
                AND b2.batch_no = i_batch_no;

        EXCEPTION
            WHEN no_data_found THEN
                pl_text_log.ins_msg_async('WARN', l_func_name, 'No records returned from select statement. For batch_no = ' || i_batch_no, sqlcode
                , sqlerrm);
        END;

        IF l_except_time_spent > 0 THEN
            BEGIN
                UPDATE batch
                SET
                    actl_time_spent = actl_time_spent - l_except_time_spent
                WHERE
                    batch_no = rtrim(i_batch_no);

            EXCEPTION
                WHEN OTHERS THEN
                    pl_text_log.ins_msg_async('WARN', l_func_name, 'Unable to set time spent on LM forklift batch. For batch_no = ' || i_batch_no
                    , sqlcode, sqlerrm);
                    l_ret_val := rf.status_lm_batch_upd_fail;
            END;
        END IF;

        RETURN l_ret_val;
    END lmf_remove_except_time_spent;

/*****************************************************************************
**  Function: 
**     lmf_reset_batch()
**
**  Description:
**      This function resets the specified forklift batch.
**
**  Parameters:
**     i_batch_no       -  batch to reset.
**
**  Return Values:  
**     rf.STATUS_NORMAL                --  Okay.
**     rf.STATUSLM_BATCH_UPD_FAIL;     --  Failed to modify batch.
** 	Modification history                                               
**  Author      Date        Ver    Description                         
**  ----------- ----------  ----  -----------------------------------------    
**  KSAR9933	   12/18/2019   1.0    Initial Version                           
*****************************************************************************/

    FUNCTION lmf_reset_batch (
        i_batch_no   IN           batch.batch_no%TYPE
    ) RETURN rf.status AS
        l_func_name   VARCHAR2(30) := 'pl_lm_forklift.lmf_reset_batch';
        l_ret_val     rf.status := rf.status_normal;
    BEGIN
        pl_text_log.ins_msg_async('INFO', l_func_name, 'Starting lmf_reset_batch ......batch_no= ' || i_batch_no, sqlcode, sqlerrm);
        BEGIN
            UPDATE batch
            SET
                user_id = NULL,
                user_supervsr_id = NULL,
                actl_start_time = NULL,
                actl_stop_time = NULL,
                actl_time_spent = NULL,
                parent_batch_no = NULL,
                parent_batch_date = NULL,
                equip_id = NULL,
                status = 'F'
            WHERE
                batch_no = i_batch_no;

        EXCEPTION
            WHEN OTHERS THEN
                l_ret_val := rf.status_lm_batch_upd_fail;
        END;

        RETURN l_ret_val;
    END lmf_reset_batch;

/*****************************************************************************
**  Function: 
**     lmf_reset_haul_batch()
**
**  Description:
**     This function resets a haul batch.  This happens when the operator
**     func1's out of haul.  Though the RF prompts for a drop point the
**     operator gets no credit for the haul when a func1 made during haul.
**     The haul batch will be changed to a future batch and the operator is
**     made active on the default indirect batch designated in the syspar.
**
**     The putaway batch(es) associated with the haul batch will have the
**     kvi_from_loc updated to the drop point.  A check is made to update
**     the putaway batch only if the putaway task indicates the pallet is
**     not confimed putaway.  This is to handle the situation with a MSKU
**     pallet where some of the child LP's were confirmed to the home slot,
**     the operator func'1s out of putaway then starts again with the MSKU.
**
**  Parameters:
**     i_batch_to_reset   - Haul batch to reset.
**     i_drop_point       - Where the pallet was dropped.
**
**  Return Values:  
**     rf.STATUS_NORMAL                --  Okay.
**     rf.STATUS_LM_BATCH_UPD_FAIL;     --  Failed to modify batch.
** 	Modification history                                               
**  Author      Date        Ver    Description                         
**  ----------- ----------  ----  -----------------------------------------    
**  KSAR9933	   12/18/2019   1.0    Initial Version                           
*****************************************************************************/

    FUNCTION lmf_reset_haul_batch (
        i_batch_to_reset   IN                 batch.batch_no%TYPE,
        i_drop_point       IN                 batch.kvi_from_loc%TYPE
    ) RETURN rf.status AS
        l_func_name   VARCHAR2(50) := 'pl_lm_forklift.lmf_reset_haul_batch';
        l_ret_val     rf.status := rf.status_normal;
    BEGIN
        pl_text_log.ins_msg_async('INFO', l_func_name, 'Starting lmf_reset_haul_batch..........batch_to_reset= '
                                            || i_batch_to_reset
                                            || ' drop_point= '
                                            || i_drop_point, sqlcode, sqlerrm);
		/*
		** Update the kvi_from_loc to the drop point for the putaway batches
		** associated with the haul batch being reset that have not been
		** confirmed putaway.
		*/

        pl_text_log.ins_msg_async('INFO', l_func_name, 'Updating the associated putaway batches from location to the drop point.', sqlcode,

        sqlerrm);
        BEGIN
            UPDATE batch
            SET
                kvi_from_loc = i_drop_point
            WHERE
                batch_no IN (
                    SELECT
                        b1.batch_no
                    FROM
                        batch        b1,
                        putawaylst   p,
                        batch        b2
                    WHERE
                        b2.batch_no = i_batch_to_reset
                        AND p.parent_pallet_id = b2.ref_no
                        AND b1.batch_no = p.pallet_batch_no
                        AND nvl(p.putaway_put, 'N') = 'N'
                    UNION
                    SELECT
                        p.pallet_batch_no
                    FROM
                        batch        b2,
                        putawaylst   p
                    WHERE
                        b2.batch_no = i_batch_to_reset
                        AND p.pallet_id = b2.ref_no
                        AND nvl(p.putaway_put, 'N') = 'N'
                );

        EXCEPTION
            WHEN OTHERS THEN
                l_ret_val := rf.status_lm_batch_upd_fail;
        END;

        IF l_ret_val = rf.status_normal THEN
            pl_text_log.ins_msg_async('INFO', l_func_name, 'LMF Updated from location to drop point for the associated putaway batches.'
                                                || i_batch_to_reset
                                                || ' batched updated.', sqlcode, sqlerrm);

            l_ret_val := lmf_reset_batch(i_batch_to_reset);
        END IF;

        RETURN l_ret_val;
    END lmf_reset_haul_batch;

/*****************************************************************************
**  FUNCTION: 
**      lm_signoff_from_forklift_batch()
**  DESCRIPTION:
**      This function completes a forklift batch.
**      1.  Completes the specified batch.
**      2.  Calculates the the goal/target time
**      3.  Removes any time that may be on another batch.
**  PARAMETERS:
**      i_batch_no   - Batch to be signed off.
**      i_equip_id   - Equipment being used.
**      i_user_id    - User performing operation.
**      i_is_parent  - Whether or not the current batch is a parent.
**  RETURN VALUES:  
**      rf.STATUS_NORMAL  -  Okay.
**      All others denote errors.
** 	MODIFICATION HISTORY                                               
**   Author      Date        Ver    Description                         
**  ----------- ----------  ----  -----------------------------------------    
**  KSAR9933	12/18/2019   1.0    Initial Version                              
*****************************************************************************/

    FUNCTION lm_signoff_from_forklift_batch (
        i_batch_no    IN            batch.batch_no%TYPE,
        i_equip_id    IN            equip.equip_id%TYPE,
        i_user_id     IN            batch.user_id%TYPE,
        i_is_parent   IN            VARCHAR2
    ) RETURN rf.status AS
        l_func_name   VARCHAR2(50) := 'pl_lm_forklift.lm_signoff_from_forklift_batch';
        l_ret_val     rf.status := rf.status_normal;
    BEGIN
        pl_text_log.ins_msg_async('INFO', l_func_name, 'Starting lm_signoff_from_forklift_batch........ batch_no= '
                                            || i_batch_no
                                            || ' equip_id= '
                                            || i_equip_id
                                            || ' user_id= '
                                            || i_user_id
                                            || ' is_parent= '
                                            || i_is_parent, sqlcode, sqlerrm);

        l_ret_val := pl_rf_lm_common.lmc_signoff_from_batch(i_batch_no); 
        /* The batch status gets updated to complete */
        IF l_ret_val = rf.status_normal THEN
            l_ret_val := pl_lm_goaltime.lmg_calculate_goaltime(i_batch_no, i_equip_id, i_is_parent);
        END IF;

        IF l_ret_val = rf.status_normal THEN
            l_ret_val := lmf_remove_except_time_spent(i_batch_no);
        END IF;
        RETURN l_ret_val;
    END lm_signoff_from_forklift_batch;

/*****************************************************************************
**  Function: 
**     lmf_convert_norm_put_to_haul()
**
**  Description:
**     This function changes a forklift putaway batch to a haul batch.
**      1.  Create batch id.
**      2.  Create the haul batch.
**      3.  Complete the haul batch.
**      4.  Create the HAL transaction.
**      5.  Update batch to future.
**
**  Parameters:
**     i_batch_no    	  - Current putaway batch number.
**     i_drop_location    - Location where pallet hauled to.
**     i_equip_id         - Equipment being used.
**     i_user_id          - User performing operation.
**
**  Return values:  
**     rf.STATUS_NORMAL                - Okay.
**     rf.STATUS_LM_BATCH_INSERT_FAIL  - Failed to create batch.
**     rf.STATUS_LM_BATCH_SELECT_FAIL  - Failed to select batch.
**     rf.STATUS_LM_BATCH_UPDATE_FAIL  - Failed to modify batch.
**	Modification history                                               
**  Author      Date        Ver    Description                         
** ----------- ----------  ----  -----------------------------------------    
** KSAR9933	   12/18/2019   1.0    Initial Version                              
*****************************************************************************/

    FUNCTION lmf_convert_norm_put_to_haul (
        i_batch_no        IN                batch.batch_no%TYPE,
        i_drop_location   IN                batch.kvi_to_loc%TYPE,
        i_equip_id        IN                equip.equip_id%TYPE,
        i_user_id         IN                batch.user_id%TYPE
    ) RETURN rf.status AS

        l_func_name   VARCHAR2(50) := 'pl_lm_forklift.lmf_convert_norm_put_to_haul';
        l_ret_val     rf.status := rf.status_normal;
        l_hbatch_no   batch.batch_no%TYPE;
    BEGIN
        pl_text_log.ins_msg_async('INFO', l_func_name, 'Staring lmf_convert_norm_put_to_haul.......batch_no= '
                                            || i_batch_no
                                            || ' drop_location= '
                                            || i_drop_location
                                            || ' equip_id= '
                                            || i_equip_id
                                            || ' user_id= '
                                            || i_user_id, sqlcode, sqlerrm);

        l_ret_val := lmf_create_haul_batch_id(l_hbatch_no);
        IF l_ret_val = rf.status_normal THEN
            pl_text_log.ins_msg_async('INFO', l_func_name, 'Haul batch id created using sequence.', sqlcode, sqlerrm);
            l_hbatch_no := trim(l_hbatch_no);
            BEGIN
                INSERT INTO batch (
                    batch_no,
                    batch_date,
                    status,
                    jbcd_job_code,
                    ref_no,
                    kvi_no_piece,
                    kvi_no_pallet,
                    kvi_wt,
                    kvi_cube,
                    kvi_no_item,
                    kvi_no_data_capture,
                    kvi_no_po,
                    kvi_no_loc,
                    kvi_no_case,
                    kvi_no_split,
                    kvi_no_aisle,
                    kvi_no_drop,
                    kvi_from_loc,
                    kvi_to_loc,
                    kvi_distance,
                    goal_time,
                    target_time,
                    user_id,
                    user_supervsr_id,
                    actl_start_time,
                    total_count,
                    total_pallet,
                    total_piece,
                    equip_id,
                    cmt
                )
                    SELECT
                        l_hbatch_no,
                        trunc(SYSDATE),
                        status,
                        substr(substr(jbcd_job_code, 1, 3)
                               || 'HAL', 1, 6),
                        ref_no,
                        kvi_no_piece,
                        kvi_no_pallet,
                        kvi_wt,
                        kvi_cube,
                        kvi_no_item,
                        kvi_no_data_capture,
                        kvi_no_po,
                        kvi_no_loc,
                        kvi_no_case,
                        kvi_no_split,
                        kvi_no_aisle,
                        kvi_no_drop,
                        kvi_from_loc,
                        i_drop_location,
                        kvi_distance,
                        0,
                        0,
                        user_id,
                        user_supervsr_id,
                        actl_start_time,
                        1,
                        1,
                        0,
                        equip_id,
                        DECODE(msku_batch_flag, 'Y', 'HAUL OF MSKU PALLET.  REF# IS THE PARENT LP.', NULL)
                    FROM
                        batch
                    WHERE
                        batch_no = i_batch_no;

            EXCEPTION
                WHEN dup_val_on_index THEN
                    pl_text_log.ins_msg_async('WARN', l_func_name, 'Unable to create HAUL batch for reset.. For batch_no = ' || i_batch_no, sqlcode
                    , sqlerrm);
                    l_ret_val := rf.status_lm_batch_upd_fail;
                WHEN OTHERS THEN
                    l_ret_val := rf.status_lm_batch_upd_fail;
            END;

            l_ret_val := lm_signoff_from_forklift_batch(l_hbatch_no, i_equip_id, i_user_id, 'N');
            IF l_ret_val = rf.status_normal THEN
                l_ret_val := lmf_insert_haul_trans(l_hbatch_no);
            END IF;
			/* Update the PUT transaction if the PO was closed before the pallet was putaway. */
            IF l_ret_val = rf.status_normal THEN
                l_ret_val := lmf_update_put_trans(l_hbatch_no);
            END IF;
            IF l_ret_val = rf.status_normal THEN
                BEGIN
                    UPDATE batch
                    SET
                        status = 'F',
                        actl_time_spent = NULL,
                        actl_start_time = NULL,
                        actl_stop_time = NULL,
                        user_id = NULL,
                        user_supervsr_id = NULL,
                        parent_batch_no = NULL,
                        parent_batch_date = NULL,
                        equip_id = NULL,
                        kvi_from_loc = i_drop_location
                    WHERE
                        batch_no = i_batch_no;

                EXCEPTION
                    WHEN OTHERS THEN
                        pl_text_log.ins_msg_async('WARN', l_func_name, 'Unable to reset batch.. For batch_no = ' || i_batch_no, sqlcode, sqlerrm
                        );
                        l_ret_val := rf.status_lm_batch_upd_fail;
                END;
            END IF;

        END IF;

        RETURN l_ret_val;
    END lmf_convert_norm_put_to_haul;

/*****************************************************************************
Function: 
**      lmf_signon_to_forklift_batch()
**
**  Description:
**      This function attaches a user to a forklift batch.
**      If called from login.
**        1.  Find any suspended forklift batches.
**        2.  Activate the suspended forklift batch for the user.
**      Else if called for merge.
**        1.  Merge the batch with the current parent batch.
**      Else if called during exception processing.
**        1.  Suspend current batch.
**        2.  Signon to specified batch.
**      Else
**        1.  Signon to specified batch.
**
**      When attaching to a MSKU batch the batch to assign to the user
**      (i_batch_no) must be for the batch bringing the MSKU to reserve
**      it it exists.  A MSKU can be going only to home slots in which case
**      i_batch_no can be any one of the batches.  A MSKU going to home slots
**      will have batch for each child LP going to a home slot.
**
**  Parameters:
**      i_cmd                - Command denoting what operation needs to be done
**                             to signon to incoming batch id.
**                             Values are:
**                                - LMF_SUSPEND_BATCH
**                                - LMF_SIGNON_BATCH
**                                - LMF_MERGE_BATCH
**      i_batch_no           - Batch to be assigned to user.
**      i_parent_batch_no    - Parent batch assigned to user.
**      i_user_id            - User being assigned to batch.
**      i_supervisor         - Supervisor for user's supervisor.
**		i_equip_id			 - Equipment being used
**
**  Return Values:  
**      STATUS_NORMAL - Okay.
**      All others denote errors
**	Modification history                                               
**  Author      Date        Ver    Description                         
** ----------- ----------  ----  -----------------------------------------    
** KSAR9933	   12/18/2019   1.0    Initial Version    
*****************************************************************************/

    FUNCTION lmf_signon_to_forklift_batch (
        i_cmd               IN                  VARCHAR,
        i_batch_no          IN                  batch.batch_no%TYPE,
        i_parent_batch_no   IN                  batch.parent_batch_no%TYPE,
        i_user_id           IN                  batch.user_id%TYPE,
        i_supervisor        IN                  batch.user_supervsr_id%TYPE,
        i_equip_id          IN                  equip.equip_id%TYPE
    ) RETURN rf.status AS

        l_func_name                     VARCHAR2(50) := 'pl_lm_forklift.lmf_signon_to_forklift_batch';
        l_cmd                           VARCHAR2(10);
        l_is_parent                     VARCHAR2(2);
        l_batch_status                  batch.status%TYPE;
        l_current_active_batch_no       batch.batch_no%TYPE;
        l_original_active_batch_no      batch.batch_no%TYPE;
        l_temp_suspend_flag             VARCHAR2(1);
        l_user_id                       batch.user_id%TYPE;
        l_new_parent_batch_no           batch.batch_no%TYPE;
        l_vc_last_drop_point            VARCHAR(11);
        l_active_batch_no               arch_batch.batch_no%TYPE := l_current_active_batch_no;
        l_need_new_parent_bln           BOOLEAN;
        l_new_parent_batch              arch_batch.batch_no%TYPE;
        l_new_parent_actl_start_time    DATE;
        l_new_parent_actl_stop_time     DATE;
        l_orig_parent_batch             arch_batch.batch_no%TYPE;
        l_orig_parent_actl_start_time   DATE;
        l_orig_parent_actl_stop_time    DATE;
        l_num_of_tasks_completed        PLS_INTEGER;
        l_num_of_tasks_not_completed    PLS_INTEGER;
        l_r_last_drop_point             pl_lmd_drop_point.t_drop_point_rec;
        l_return_value                  rf.status := rf.status_normal;
        CURSOR c_batch (
            cp_batch_no arch_batch.batch_no%TYPE
        ) IS
        SELECT
            b.batch_no,
            b.parent_batch_no,
            b.status,
            b.actl_start_time,
            b.actl_stop_time
        FROM
            batch b
        WHERE
            b.batch_no = cp_batch_no
            OR b.parent_batch_no = cp_batch_no
        ORDER BY
            b.actl_start_time
        FOR UPDATE;

    BEGIN
        pl_text_log.ins_msg_async('INFO', l_func_name, 'Starting lmf_signon_to_forklift_batch .......i_cmd= '
                                            || i_cmd
                                            || ' batch_no= '
                                            || i_batch_no
                                            || ' parent_batch_no= '
                                            || i_parent_batch_no
                                            || ' user_id= '
                                            || i_user_id
                                            || ' supervisor= '
                                            || i_supervisor
                                            || ' equip_id= '
                                            || i_equip_id, sqlcode, sqlerrm);

        l_cmd := i_cmd;
        l_return_value := pl_rf_lm_common.lmc_batch_is_active_check(i_batch_no);
        IF l_return_value = rf.status_normal THEN
            l_return_value := pl_rf_lm_common.lmc_find_active_batch(i_user_id, l_current_active_batch_no, l_is_parent);
        END IF;

        IF ( l_return_value = rf.status_normal AND l_cmd = lmf.lmf_suspend_batch ) THEN
            l_active_batch_no := l_current_active_batch_no;
            BEGIN
                IF ( pl_lmf.all_tasks_completed(l_active_batch_no) ) THEN
                    l_temp_suspend_flag := 'N';
                ELSE
                    l_temp_suspend_flag := 'Y';
                END IF;
            EXCEPTION
                WHEN OTHERS THEN
                    pl_text_log.ins_msg_async('WARN', l_func_name, 'Error in pl/sql block checking if all tasks completed for the active batch . batch_no= '
                                                        || i_batch_no
                                                        || ' user_id= '
                                                        || i_user_id, sqlcode, sqlerrm);

                    l_return_value := rf.status_data_error;
            END;
            /*
            ** Change from suspend to complete the users active batch if 
            ** all the tasks are completed.
            */

            IF l_temp_suspend_flag = 'N' THEN
                l_cmd := lmf.lmf_signon_batch;
                pl_text_log.ins_msg_async('INFO', l_func_name, 'The command was to suspend the active batch but changed to complete because all the tasks are completed.batch_no= '
                                                    || i_batch_no
                                                    || ' user_id= '
                                                    || i_user_id, sqlcode, sqlerrm);

            END IF;

        END IF;  /* end if (l_return_value = SWMS_NORMAL AND l_cmd = LMF_SUSPEND_BATCH) */

        IF l_cmd = lmf.lmf_signon_batch THEN
            IF l_return_value = rf.status_normal THEN
                l_current_active_batch_no := trim(l_current_active_batch_no);
                BEGIN
                    SELECT
                        status,
                        user_id
                    INTO
                        l_batch_status,
                        l_user_id
                    FROM
                        batch
                    WHERE
                        batch_no = i_batch_no;

                EXCEPTION
                    WHEN OTHERS THEN
                        pl_text_log.ins_msg_async('WARN', l_func_name, 'Unable to set batch identification. For batch_no = ' || i_batch_no, sqlcode
                        , sqlerrm);
                        l_return_value := rf.status_no_lm_batch_found;
                END;
                IF l_return_value != rf.status_no_lm_batch_found THEN
                    l_user_id := trim(LEADING ' ' FROM l_user_id);
                    IF ( substr(l_batch_status, 1, 1) = 'W' ) THEN
                        pl_text_log.ins_msg_async('WARN', l_func_name, 'Batch '
                                                            || i_batch_no
                                                            || ' has status of "W".  Leave as is.  Do not update the status to "N"', sqlcode
                                                            , sqlerrm);
                    ELSE
                        BEGIN
                            UPDATE batch
                            SET
                                status = 'N',
                                user_id = replace(i_user_id,'OPS$',null)
                            WHERE
                                batch_no = i_batch_no;
                        EXCEPTION
                            WHEN OTHERS THEN
                                l_return_value := rf.status_data_error;
                                pl_text_log.ins_msg_async('INFO', l_func_name, 'unable to update batch '
                                                                    || i_batch_no
                                                                    || ' status to "N"', sqlcode, sqlerrm);

                        END;
                        IF l_return_value != rf.status_data_error THEN
                            pl_text_log.ins_msg_async('INFO', l_func_name, 'Updated batch '
                                                                || i_batch_no
                                                                || ' status to "N" . Batch_no = '
                                                                || i_batch_no, sqlcode, sqlerrm);
                        END IF;
                    END IF;
                    
                END IF;
				/*
				**  If needing to signoff of either a forklift or haul batch
				**  then signoff forklift batch.
				**  Else signoff normal labor management batch.
				*/

                pl_text_log.ins_msg_async('INFO', l_func_name, 'l_return_value '
                                                    || l_return_value
                                                    || 'l_current_active_batch_no '
                                                    || l_current_active_batch_no, sqlcode, sqlerrm);

                IF ( l_return_value = rf.status_normal ) THEN
                    IF ( substr(l_current_active_batch_no, 1, 1) = 'F' OR substr(l_current_active_batch_no, 1, 1) = 'H' OR substr
                    (l_current_active_batch_no, 1, 1) = 'T' ) THEN
                        l_return_value := lm_signoff_from_forklift_batch(l_current_active_batch_no, i_equip_id, i_user_id, l_is_parent
                        );
                    ELSE
                        l_return_value := pl_rf_lm_common.lmc_signoff_from_batch(l_current_active_batch_no);
                    END IF;
                END IF;

                IF l_return_value = rf.status_normal THEN
                    BEGIN
                        UPDATE batch
                        SET
                            status = l_batch_status,
                            user_id = l_user_id
                        WHERE
                            batch_no = i_batch_no;

                    EXCEPTION
                        WHEN OTHERS THEN
                            pl_text_log.ins_msg_async('WARN', l_func_name, 'LMF ORACLE unable to reset batch identification.. For batch_no = '
                            || i_batch_no, sqlcode, sqlerrm);
                            l_return_value := rf.status_lm_batch_upd_fail;
                    END;

                    IF l_return_value = rf.status_normal THEN
                        l_return_value := pl_rf_lm_common.lmc_signon_to_batch(i_batch_no, i_user_id, i_supervisor, i_equip_id, l_current_active_batch_no
                        );
                    END IF;

                END IF;

            ELSIF l_return_value = lm_last_is_istop THEN
				/*The users last batch was an ISTOP.*/
                l_return_value := pl_rf_lm_common.lmc_signon_to_batch(i_batch_no, i_user_id, i_supervisor, i_equip_id, l_current_active_batch_no
                );
            END IF;
			/*
			** Merge MSKU batches if required.
			** This merge if MSKU batches only occurs when l_cmd is
			** set to LMF_SIGNON_BATCH because a MSKU batch should never be merged
			** or suspended.
			*/

            IF l_return_value = rf.status_normal THEN
                l_return_value := lmf_merge_msku_batches(i_batch_no);
            END IF;
			/* end  LMF_SIGNON_BATCH */
        ELSIF l_cmd = lmf.lmf_merge_batch THEN
			/*
			** Merge the batch with the users current active batch.
			**
			** When merging a batch the current active batch has to be a
			** forklift batch.
			*/
            IF l_return_value = rf.status_normal THEN
                l_current_active_batch_no := trim(TRAILING ' ' FROM l_current_active_batch_no);
                IF ( substr(l_current_active_batch_no, 1, 1) = 'F' OR substr(l_current_active_batch_no, 1, 1) = 'H' ) THEN
                    IF ( ( l_return_value = rf.status_normal ) AND ( substr(l_is_parent, 1, 1) = 'N' ) ) THEN
                        l_return_value := lmf_make_batch_parent(l_current_active_batch_no);
                    END IF;

                    IF l_return_value = rf.status_normal THEN
                        l_return_value := pl_rf_lm_common.lmc_signon_to_batch(i_batch_no, i_user_id, i_supervisor, i_equip_id, l_current_active_batch_no
                        );
                    END IF;

                    IF ( l_return_value = rf.status_normal ) THEN
                        l_return_value := pl_rf_lm_common.lmc_merge_batch(i_batch_no, l_current_active_batch_no);
                        NULL;
                    END IF;

                ELSE
					/*The current active batch is not a forklift batch.  This is an error. Write aplog message and set return value.
					  Ideally should never encounter this situation.*/
                    pl_text_log.ins_msg_async('WARN', l_func_name, 'ERROR  Attempting to merge batch '
                                                        || i_batch_no
                                                        || ' with current active batch '
                                                        || l_current_active_batch_no
                                                        || ' which is not a forklift batch.', sqlcode, sqlerrm);

                    l_return_value := rf.status_lm_parent_upd_fail;
                END IF;

            END IF;
			/* end  LMF_MERGE_BATCH */
        ELSIF ( l_cmd = lmf.lmf_suspend_batch AND l_return_value = rf.status_normal ) THEN
            pl_text_log.ins_msg_async('INFO', l_func_name, 'l_current_active_batch_no= '
                                                || l_current_active_batch_no
                                                || '  i_batch_no= '
                                                || i_batch_no
                                                || ' l_cmd is LMF_SUSPEND_BATCH', sqlcode, sqlerrm);
            /*
            ** 
            ** Complete batches for tasks performed.  Create haul batches for
            ** the task not yet completed.
            **
            ** Processing taking place in the following PL/SQL block:
            ** If the parent batch task is completed then leave it as the
            ** parent batch.
            ** If the parent batch task is not completed then choose one of
            ** the batches with a completed task as the new parent and update
            ** the parent batch number and switch the actl start time with the
            ** actl start time of the original parent batch.
            */
            l_active_batch_no := l_current_active_batch_no;
            l_original_active_batch_no := l_current_active_batch_no;
            BEGIN
                l_need_new_parent_bln := true;
                l_new_parent_batch := NULL;
                l_orig_parent_batch := NULL;
                IF ( pl_lma.g_audit_bln ) THEN
                    pl_lma.audit_cmt('Break away from current active batch '
                                     || l_active_batch_no
                                     || ' to do other task', pl_lma.ct_na, pl_lma.ct_detail_level_1);
                END IF;
				/* Find the last drop point for the active batch. For the batches where the task is not completed the kvi_from_loc will be updated to this.*/

                pl_lmd_drop_point.get_last_drop_point(l_active_batch_no, l_r_last_drop_point);
                l_vc_last_drop_point := l_r_last_drop_point.drop_point;
				/* If the parent batch task is not completed then find a new parent batch.*/
                FOR r_batch IN c_batch(l_active_batch_no) LOOP
                    pl_text_log.ins_msg_async('INFO', 'plsql block', 'Batch No= '
                                                          || r_batch.batch_no
                                                          || '  Parent Batch No= '
                                                          || r_batch.parent_batch_no
                                                          || '  Status= '
                                                          || r_batch.status, NULL, NULL);

                    IF ( pl_lmf.all_tasks_completed(i_batch_no => r_batch.batch_no, i_check_batch_only_bln => true) ) THEN
						/*Task completed.*/
                        pl_text_log.ins_msg_async('INFO', 'plsql block', 'Batch No '
                                                              || r_batch.batch_no
                                                              || ' task completed', NULL, NULL);

                        l_num_of_tasks_completed := l_num_of_tasks_completed + 1;
						/* If this is the parent batch then a new parent is not needed.*/
                        IF ( r_batch.batch_no = r_batch.parent_batch_no ) THEN
                            l_need_new_parent_bln := false;
                            l_new_parent_batch := NULL;
                        ELSIF ( l_new_parent_batch IS NULL AND l_need_new_parent_bln = true ) THEN
                            l_new_parent_batch := r_batch.batch_no;
                            l_new_parent_actl_start_time := r_batch.actl_start_time;
                            l_new_parent_actl_stop_time := r_batch.actl_stop_time;
                        END IF;
						/*Save the scan order.  This is needed for LXLI.*/

                        UPDATE batch
                        SET
                            initial_pickup_scan_date = actl_start_time
                        WHERE
                            CURRENT OF c_batch;

                    ELSE
						/*Task not completed.*/
                        pl_text_log.ins_msg_async('INFO', 'plsql block', 'Batch No '
                                                              || r_batch.batch_no
                                                              || ' task not completed', NULL, NULL);

                        l_num_of_tasks_not_completed := l_num_of_tasks_not_completed + 1;
						/* A HL haul batch will be created for the LP. Change the from loc of the batch to the drop point.
						  Save the scan order.  This is needed for LXLI.*/
                        UPDATE batch
                        SET -- XXXXX kvi_from_loc = l_r_last_drop_point.drop_point,
                            initial_pickup_scan_date = actl_start_time
                        WHERE
                            CURRENT OF c_batch;
						/*If it is the parent batch not done then save info that will be assigned to the new parent.*/

                        IF ( r_batch.batch_no = r_batch.parent_batch_no ) THEN
                            l_orig_parent_batch := r_batch.batch_no;
                            l_orig_parent_actl_start_time := r_batch.actl_start_time;
                            l_orig_parent_actl_stop_time := r_batch.actl_stop_time;
                        END IF;

                    END IF;

                END LOOP;
				/*
				** If l_new_parent_batch is populated then the task for the original
				** parent batch is not done so a new parent batch is needed.
				** Flip the relevant info for the original parent and the
				** new parent.
				*/

                IF ( l_new_parent_batch IS NOT NULL ) THEN
					/* Update the original parent batch.*/
                    UPDATE batch
                    SET
                        actl_start_time = l_new_parent_actl_start_time,
                        actl_stop_time = l_new_parent_actl_stop_time,
                        status = 'M'
                    WHERE
                        batch_no = l_orig_parent_batch;

               /* Update the new parent batch.*/

                    UPDATE batch
                    SET
                        actl_start_time = l_orig_parent_actl_start_time,
                        actl_stop_time = l_orig_parent_actl_stop_time,
                        status = 'A'
                    WHERE
                        batch_no = l_new_parent_batch;

               /*Make the new parent batch the parent of the other batches.*/

                    UPDATE batch
                    SET
                        parent_batch_no = l_new_parent_batch
                    WHERE
                        parent_batch_no = l_orig_parent_batch;

               /*Write an audit message if auditing.*/

                    IF ( pl_lma.g_audit_bln ) THEN
                        pl_lma.audit_cmt('The task for the original parent batch '
                                         || l_orig_parent_batch
                                         || ' is not done.  Batch '
                                         || l_new_parent_batch
                                         || ' made the parent batch', pl_lma.ct_na, pl_lma.ct_detail_level_1);
                    END IF;

                    l_current_active_batch_no := l_new_parent_batch;
                END IF;

            EXCEPTION
                WHEN OTHERS THEN
                    pl_text_log.ins_msg_async('WARN', l_func_name, 'Error in PL/SQL block checking if task completed', sqlcode, sqlerrm);
                    l_return_value := rf.status_data_error;
            END;
			/*
			** At this point the parent batch was flip flopped, if necessary, to
			** a batch with the task completed.  We always want the parent batch
			** to be for a completed task.
			*/

            IF l_return_value = rf.status_normal THEN
                pl_text_log.ins_msg_async('INFO', l_func_name, 'l_current_active_batch_no= '
                                                    || l_current_active_batch_no
                                                    || ' l_original_active_batch_no= '
                                                    || l_original_active_batch_no, sqlcode, sqlerrm);

                l_current_active_batch_no := trim(l_current_active_batch_no);
                l_new_parent_batch_no := trim(l_new_parent_batch_no);
                SELECT
                    status,
                    user_id
                INTO
                    l_batch_status,
                    l_user_id
                FROM
                    batch
                WHERE
                    batch_no = i_batch_no;

                l_user_id := trim(l_user_id);
				/*
				** Set the status of the batch about to be signed onto to 'N'.
				** The kvi_from_loc of this batch is the ending point of the batch
				** being completed.
				*/
                UPDATE batch
                SET
                    status = 'N',
                    user_id = replace(i_user_id,'OPS$',null)
                WHERE
                    batch_no = i_batch_no;

                l_return_value := lmf_break_away(lmf.forklift_putaway, i_user_id, l_vc_last_drop_point, i_equip_id);
            END IF;

            IF l_return_value = rf.status_normal THEN
				/*
				** i_batch_no is the batch the user is signing onto.  Earlier the
				** status was changed to 'N' before the users active batch
				** was completed.  Now change it back to what it was.
				*/
                UPDATE batch
                SET
                    status = l_batch_status,
                    user_id = i_user_id
                WHERE
                    batch_no = i_batch_no;

                IF ( l_return_value = rf.status_normal ) THEN
                    l_return_value := pl_rf_lm_common.lmc_signon_to_batch(i_batch_no, i_user_id, i_supervisor, i_equip_id, l_current_active_batch_no
                    );
                END IF;

            END IF;

        END IF;  /* end LMF_SUSPEND_BATCH */

        RETURN l_return_value;
    END lmf_signon_to_forklift_batch;

/*****************************************************************************
**  Function: 
**     lmf_break_away
**
**  Description:
**     This function resets a forklift batch.  Used in func1 processing.
**     It resets parent batches.
**     It performs special processing on Putaway batches.
**     It creates a default forklift indirect batch for the user.
**
**  Parameters:
**     i_type_flag       - Type of forklift batch.
**     i_user_id         - User performing operation.
**     i_drop_location   - Location where pallets were dropped off.
**     i_equip_id        - Equipment being used.
**
**  Return Values:  
**     rf.STATUS_NORMAL  --  Okay.
**     All others denote errors.
**	Modification history                                               
**  Author      Date        Ver    Description                         
** ----------- ----------  ----  -----------------------------------------    
** KSAR9933	   12/18/2019   1.0    Initial Version  
*****************************************************************************/

    FUNCTION lmf_break_away (
        i_type_flag       IN                VARCHAR2,
        i_user_id         IN                VARCHAR2,
        i_drop_location   IN                batch.kvi_to_loc%TYPE,
        i_equip_id        IN                equip.equip_id%TYPE
    ) RETURN rf.status AS

        l_ret_val          rf.status := rf.status_normal;
        l_batch_to_reset   batch.batch_no%type;
        l_func_name        VARCHAR2(30) := 'pl_lm_forklift.lmf_break_away';
        l_is_parent        VARCHAR2(2) := ' ';
    BEGIN
        pl_text_log.ins_msg_async('INFO', l_func_name, 'Starting lmf_break_away ......type_flag= '
                                            || i_type_flag
                                            || ' user_id= '
                                            || i_user_id
                                            || ' drop_location= '
                                            || i_drop_location
                                            || ' equip_id= '
                                            || i_equip_id, sqlcode, sqlerrm);

		/*
		** Validate the drop point if the drop point has a value.
		*/

        IF length(i_drop_location) > 0 THEN
            l_ret_val := lmf_is_valid_point(i_drop_location);
        END IF;

        IF l_ret_val = rf.status_normal THEN
            l_ret_val := pl_rf_lm_common.lmc_find_active_batch(i_user_id, l_batch_to_reset, l_is_parent);
        END IF;

        IF l_ret_val = rf.status_normal THEN
            l_batch_to_reset := trim(l_batch_to_reset);
            IF substr(l_is_parent, 1, 1) = 'Y' THEN
                l_ret_val := lm_brk_away_rst_parent_batch(i_type_flag, l_batch_to_reset, i_drop_location, i_equip_id, i_user_id
                );
            ELSIF substr(l_batch_to_reset, 1, 1) = 'H' THEN
                l_ret_val := lmf_reset_haul_batch(l_batch_to_reset, i_drop_location);
            ELSIF ( i_type_flag = lmf.forklift_putaway ) THEN
                l_ret_val := lmf_convert_norm_put_to_haul(l_batch_to_reset, i_drop_location, i_equip_id, i_user_id);
            ELSE
                l_ret_val := lmf_reset_batch(l_batch_to_reset);
            END IF;

        END IF;

        RETURN l_ret_val;
    END lmf_break_away;

/*****************************************************************************
**  FUNCTION: 
**      lmf_is_valid_point()
**
**  DESCRIPTION:    
**      This function checks if a point is valid.  It calls function
**      "lmd_get_point_type" to do this.  Function "lmd_get_point_type" 
**      returns either SWMS_NORMAL or LM_PT_DIST_BADSETUP_PT.
**
**  PARAMETERS:
**      i_point - The point to validate.
**
**  RETURN VALUES:  
**      rf.STATUS_NORMAL            - The point is valid.
**      rf.STATUS_LM_PT_DIST_BADSETUP_PT - Invalid point type or an oracle error
**                             			   occurred in "lmd_get_point_type".
**	MODIFICATION HISTORY                                               
**  Author      Date        Ver    Description                         
** ----------- ----------  ----  -----------------------------------------    
** KSAR9933	   12/18/2019   1.0    Initial Version  
*****************************************************************************/

    FUNCTION lmf_is_valid_point (
        i_point IN VARCHAR2
    ) RETURN rf.status AS

        l_func_name    VARCHAR2(60) := 'pl_lm_forklift.lmf_is_valid_point';
        l_ret_val      NUMBER:=rf.status_normal;
        l_point_type   VARCHAR2(6) := ' ';
        l_dock_num     VARCHAR2(6) := ' '; /* Required in call to lmd_get_point_type */
    BEGIN
        --l_ret_val := rf.status_normal;
        pl_text_log.ins_msg_async('INFO', l_func_name, 'Starting lmf_is_valid_point .......point= ' || i_point, sqlcode, sqlerrm);
        l_ret_val := pl_lm_distance.lmd_get_point_type(i_point, l_point_type, l_dock_num);
        RETURN l_ret_val;
    END lmf_is_valid_point;

/*******************************<+>******************************************
**  Function:
**     lmf_merge_msku_batches
**
**  Description:
**     This function merges the associated MSKU batches for a MSKU pallet.
**
**     A MSKU pallet can have one or more batches depending on the operation.
**     For example, the putaway of a MSKU pallet will have a separate batch
**     for each child LP going to a home slot and a separate batch for the
**     putaway to reserve/floating.  When the operator scans the MSKU
**     he will be made active on one of the batches.  Which one does not
**     matter.  Function lmf_signon_to_forklift_batch() does this signon
**     process this.  The operator then needs to have the other batches
**     for the MSKU merged.  This is the purpose of this function.
**
**     A package procedure is called to do all the work.  If the batch
**     is not a MSKU batch then no action is taken.
**
**  Parameters:
**     i_psz_batch_no    - Batch number to process.
**
**  Return Values:
**     rf.STATUS_NORMAL       - Successful processing.
**     Anything else donotes a failure.
**
**  Called by:  (list probably not complete)
**     - lmf_signon_to_forklift_batch
**	Modification history                                               
**  Author      Date        Ver    Description                         
** ----------- ----------  ----  -----------------------------------------    
** KSAR9933	   12/18/2019   1.0    Initial Version  
*******************************<+>******************************************/

    FUNCTION lmf_merge_msku_batches (
        i_psz_batch_no batch.batch_no%TYPE
    ) RETURN rf.status AS
        l_func_name   VARCHAR2(50) := 'pl_lm_forklift.lmf_merge_msku_batches';
        l_ret_val     rf.status := rf.status_normal;
    BEGIN
        pl_text_log.ins_msg_async('INFO', l_func_name, 'Starting lmf_merge_msku_batches.........psz_batch_no= ' || i_psz_batch_no, sqlcode, sqlerrm
        );
		/*
		** A package procedure does the work.  If the batch is not for a
		** MSKU pallet then nothing happens.
		*/
        BEGIN
            pl_lm_msku.merge_batches(i_psz_batch_no);
        EXCEPTION
            WHEN OTHERS THEN
                pl_text_log.ins_msg_async('WARN', l_func_name, 'Error in pl_lm_msku.merge_batches for batch ' || i_psz_batch_no, sqlcode, sqlerrm
                );
                l_ret_val := rf.status_data_error;
        END;

        RETURN l_ret_val;
    END lmf_merge_msku_batches;


/*****************************************************************************
**  Function: 
**     lmf_cvt_mrgd_msku_put_to_haul()
**
**  Description:
**     This function creates a single haul batch from the putaway batches for
**     the MSKU that where the putaway was not completd.
**
**     For returns putaway the T batch must be passed to this function.
**
**     Keep in mind if there were putaways completed these completed putaways
**     will become child batches of the haul batch.  The calling function
**     does this processing.
**
**  Parameters:
**     i_batch_no               - Putaway batch.  It can be any putaway batch
**                                for the MSKU that has not been putaway.
**                                For returns it must be the T batch.
**     i_drop_location          - Location where pallet hauled to.
**     i_equip_id               - Equipment being used.
**
**  Return Values:  
**     rf.STATUS_NORMAL                 - Okay.
**     rf.STATUS_LM_BATCH_INSERT_FAIL   - Failed to create batch.
**     rf.STATUS_LM_BATCH_SELECT_FAIL   - Failed to select batch.
**     rf.STATUS_LM_BATCH_UPDATE_FAIL   - Failed to modify batch.
**
**  Called By:
**     lm_reset_current_fklft_batch
**	Modification history                                               
**  Author      Date        Ver    Description                         
** ----------- ----------  ----  -----------------------------------------    
** KSAR9933	   12/18/2019   1.0    Initial Version    
**
*****************************************************************************/

    FUNCTION lmf_cvt_mrgd_msku_put_to_haul (
        i_batch_no        IN                batch.batch_no%TYPE,
        i_drop_location   IN                batch.kvi_to_loc%TYPE,
        i_equip_id        IN                equip.equip_id%TYPE
    ) RETURN rf.status AS

        l_func_name                 VARCHAR2(50) := 'pl_lm_forklift.lmf_cvt_mrgd_msku_put_to_haul';
        l_ret_val                   rf.status := rf.status_normal;
        l_returns_batch_no_prefix   VARCHAR2(1) := lmf.forklift_returns_putaway;
        l_hbatch_no                 batch.batch_no%TYPE := ' ';
    BEGIN
        pl_text_log.ins_msg_async('INFO', l_func_name, 'Startingh lmf_cvt_mrgd_msku_put_to_haul .....batch_no= '
                                            || i_batch_no
                                            || ' drop_location= '
                                            || i_drop_location
                                            || ' equip_id= '
                                            || i_equip_id, sqlcode, sqlerrm);

        l_ret_val := lmf_create_haul_batch_id(l_hbatch_no);
        IF l_ret_val = rf.status_normal THEN
            pl_text_log.ins_msg_async('INFO', l_func_name, 'Haul batch id created for merge batch. For batch ' || l_hbatch_no, sqlcode, sqlerrm
            );
            l_hbatch_no := trim(l_hbatch_no);
            BEGIN
                INSERT INTO batch (
                    batch_no,
                    batch_date,
                    status,
                    jbcd_job_code,
                    ref_no,
                    kvi_no_piece,
                    kvi_no_pallet,
                    kvi_no_item,
                    kvi_no_po,
                    kvi_cube,
                    kvi_wt,
                    kvi_no_data_capture,
                    kvi_no_loc,
                    kvi_no_case,
                    kvi_no_split,
                    kvi_from_loc,
                    kvi_to_loc,
                    kvi_distance,
                    goal_time,
                    target_time,
                    user_id,
                    user_supervsr_id,
                    actl_start_time,
                    actl_stop_time,
                    actl_time_spent,
                    parent_batch_no,
                    parent_batch_date,
                    total_count,
                    total_pallet,
                    total_piece,
                    equip_id,
                    msku_batch_flag,
                    cmt
                )
                    SELECT
                        l_hbatch_no          batch_no,
                        trunc(SYSDATE) batch_date,
                        'A' status,
                        MIN(substr(b.jbcd_job_code, 1, 3))
                        || 'HAL' jbcd_job_code,
                        p.parent_pallet_id   ref_no,
                        0 kvi_no_piece,
                        1 kvi_no_pallet,
                        COUNT(DISTINCT p.prod_id || p.cust_pref_vendor) kvi_no_item,
                        COUNT(DISTINCT p.po_no) kvi_no_po,
                        trunc(SUM((p.qty / pm.spc) * pm.case_cube)) kvi_cube,
                        trunc(SUM(p.qty * nvl(pm.g_weight, 0))) kvi_wt,
                        2 kvi_no_data_capture,
                        1 kvi_no_loc,
                        0 kvi_no_case,
                        0 kvi_no_split,
                        MIN(kvi_from_loc) kvi_from_loc,
                        i_drop_location,
                        SUM(b.kvi_distance) kvi_distance,
                        0 goal_time,
                        0 target_time,
                        MIN(b.user_id) user_id,
                        MIN(b.user_supervsr_id) user_supervsr_id,
                        MIN(b.actl_start_time) actl_start_time,
                        MIN(b.actl_stop_time) actl_stop_time,
                        MIN(b.actl_time_spent) actl_time_spent,
                        MIN(b.parent_batch_no) parent_batch_no,
                        MIN(b.parent_batch_date) parent_batch_date,
                        1 total_count,
                        1 total_pallet,
                        0 total_piece,
                        MIN(b.equip_id) equip_id,
                        MIN(b.msku_batch_flag) msku_batch_flag,
                        DECODE(substr(i_batch_no, 1, 1), l_returns_batch_no_prefix, 'MSKU HAUL FROM RTNS PUT, REF# IS THE T BATCH, '
                                                                                    || COUNT(*)
                                                                                    || ' CHILD LP.', 'MSKU HAUL FROM PUT, REF# IS THE PARENT LP, '
                                                                                                     || COUNT(*)
                                                                                                     || ' CHILD LP.') cmt
                    FROM
                        pm           pm,
                        putawaylst   p,
                        batch        b
                    WHERE
                        p.pallet_batch_no = b.batch_no
                        AND p.putaway_put = 'N'
                        AND pm.prod_id = p.prod_id
                        AND pm.cust_pref_vendor = p.cust_pref_vendor
                        AND b.parent_batch_no IN (
                            SELECT
                                parent_batch_no
                            FROM
                                batch
                            WHERE
                                batch_no = i_batch_no
                        )
                    GROUP BY
                        p.parent_pallet_id,
                        i_drop_location;

            EXCEPTION
                WHEN dup_val_on_index THEN
                    pl_text_log.ins_msg_async('WARN', l_func_name, 'Duplicate value to create HAUL batch for MSKU merged reset.. For batch_no = '
                    || i_batch_no, sqlcode, sqlerrm);
                    l_ret_val := rf.status_lm_batch_upd_fail;
                WHEN OTHERS THEN
                    l_ret_val := rf.status_lm_batch_upd_fail;
            END;

            l_ret_val := lmf_insert_haul_trans(l_hbatch_no);
			/* Update the PUT transaction if the PO was closed before the pallet was putaway. */
            IF l_ret_val = rf.status_normal THEN
                l_ret_val := lmf_update_put_trans(l_hbatch_no);
            END IF;
            IF l_ret_val = rf.status_normal THEN
				/*
				** Now reset the putaway batches where the putaway was not
				** completed.
				**
				** Always reset a returns T batch.
				*/
                BEGIN
                    UPDATE batch
                    SET
                        status = 'F',
                        actl_time_spent = NULL,
                        actl_start_time = NULL,
                        actl_stop_time = NULL,
                        user_id = NULL,
                        user_supervsr_id = NULL,
                        parent_batch_no = NULL,
                        parent_batch_date = NULL,
                        equip_id = NULL,
                        kvi_from_loc = i_drop_location,
                        total_count = 1,
                        total_piece = 0,
                        total_pallet = 1
                    WHERE
                        batch_no IN (
                            SELECT
                                b2.batch_no
                            FROM
                                putawaylst   p,
                                batch        b2
                            WHERE
                                b2.parent_batch_no = i_batch_no
                                AND p.pallet_batch_no = b2.batch_no
                                AND p.putaway_put = 'N'
                        )
                        OR ( substr(i_batch_no, 1, 1) = l_returns_batch_no_prefix
                             AND batch_no = i_batch_no );

                EXCEPTION
                    WHEN OTHERS THEN
                        pl_text_log.ins_msg_async('WARN', l_func_name, 'Unable to reset merged batch.. For batch_no = '
                                                            || i_batch_no
                                                            || '  returns_batch_no_prefix '
                                                            || l_returns_batch_no_prefix, sqlcode, sqlerrm);

                        l_ret_val := rf.status_lm_batch_upd_fail;
                END;
            END IF;

        END IF;

        RETURN l_ret_val;
    END lmf_cvt_mrgd_msku_put_to_haul;


/*****************************************************************************
**  Function: 
**     lmf_reset_msku_letdown_batch()
**
**  Description:
**     This function resets the MSKU batch for a letdown, NDM or DMD, when
**     the operator func1's out of the operation.  A package procedure is
**     called to reset the batch.
**
**     All the parameters need to be null terminated.
**     
**  Parameters:
**     i_psz_batch_no         - Letdown batch to reset.  It will always be
**                              a parent batch.
**     i_psz_equip_id         - Equipment being user.
**     i_psz_user_id          - User performing operation.
**
**  Return Values:  
**     rf.STATUS_NORMAL                 -   Okay.
**     rf.STATUS_LM_BATCH_UPDATE_FAIL   -   Failed to reset the batch.
**
**  Called By:
**     lmf_reset_parent_batch
**	Modification history                                               
**  Author      Date        Ver    Description                         
** ----------- ----------  ----  -----------------------------------------    
** KSAR9933	   12/18/2019   1.0    Initial Version  
*****************************************************************************/

    FUNCTION lmf_reset_msku_letdown_batch (
        i_psz_batch_no   IN               batch.batch_no%TYPE,
        i_psz_equip_id   IN               equip.equip_id%TYPE,
        i_psz_user_id    IN               batch.user_id%TYPE
    ) RETURN rf.status AS

        l_func_name         VARCHAR2(50) := 'pl_lm_forklift.lmf_reset_msku_letdown_batch';
        l_ret_val           rf.status := rf.status_normal;
        l_is_parent_batch   VARCHAR(2);
        l_parent_batch_no   arch_batch.batch_no%TYPE;/* The parent batch # after the MSKU batch is reset.  It will be the i_psz_batch_no if the operation
                                       for this batch was completed otherwise it will be the batch number for one of the
                                       completed operations.  If no operations were completed then it will have NULL*/
    BEGIN
        pl_text_log.ins_msg_async('INFO', l_func_name, 'Starting lmf_reset_msku_letdown_batch....... psz_batch_no= '
                                            || i_psz_batch_no
                                            || ' psz_equip_id= '
                                            || i_psz_equip_id
                                            || ' psz_user_id= '
                                            || i_psz_user_id, sqlcode, sqlerrm);

        l_is_parent_batch := 'Y';  /* A MSKU letdown batch will always be a parent batch */
        BEGIN
			-- This procedure checks what has been completed/not completed and
			-- does the necessary resetting of batches and finding a new parent
			-- batch if necessary.  l_parent_batch_no will be the parent batch 
			-- for the operations completed and is set by the procedure.
			--
			-- If l_parent_batch_no is null then this indicates no operations
			-- were completed.  This can happen when a MSKU is picked up for a
			-- NDM or DMD then the operator enters Func1 before dropping
			-- any child LP's.
            pl_lm_msku.reset_letdown_batch(i_psz_batch_no, l_parent_batch_no);
        EXCEPTION
            WHEN OTHERS THEN
                pl_text_log.ins_msg_async('WARN', l_func_name, 'Error in pl_lm_msku.reset_msku_letdown. For batch ' || i_psz_batch_no, sqlcode
                , sqlerrm);
                l_ret_val := rf.status_lm_batch_upd_fail;
        END;

        IF l_ret_val = rf.status_normal THEN
			/*
			** Now complete the batch(s) for the operations completed if anything
			** was completed.  If vc_parent_batch_no has no value then this
			** indicates no operations were completed.
			*/
            IF l_parent_batch_no IS NULL THEN
                l_ret_val := lm_signoff_from_forklift_batch(l_parent_batch_no, i_psz_equip_id, i_psz_user_id, l_is_parent_batch)
                ;
            END IF;
        END IF;

        RETURN l_ret_val;
    END lmf_reset_msku_letdown_batch;

/*****************************************************************************
**  Function: 
**     lm_brk_away_rst_parent_batch()
**
**  Description:
**     This function resets the specified forklift parent batch.
**     This is done when the operator func1's out in the middle
**     of the operation.
**
**     It must determine whether or not the parent operation has been
**       performed.
**     If the parent batch's operation is complete.
**       Deattach each child batch with incomplete operation.
**       If no children, change batch to normal batch and complete batch.
**       Else Complete parent batch.
**     Else the parent batch's operation is not complete.
**       Deattach child batches from parent.
**       If more than two child batches have operations performed,
**       Then designate the child batch with the lowest pick path as the
**            parent.  Update parent batch in child batches with operations
**            performed to be new parent.  Complete parent batch.
**       Else complete the batch performed as normal batch.
**
**  Parameters:
**     i_type_flag        - Type of forklift batch.
**     i_batch_no         - Batch to be reset.
**     i_location         - Drop location of pallets.
**     i_equip_id         - Equipment being used.
**     i_user_id          - User performing operation.
**  Return Values:  
**     SWMS_NORMAL  --  Okay.
**     LM_BATCH_UPDATE_FAIL  --  Unable to modify specified batch.
**	Modification history                                               
**  Author      Date        Ver    Description                         
** ----------- ----------  ----  -----------------------------------------    
** 	KSAR9933   12/18/2019   1.0    Initial Version   
**
*****************************************************************************/

    FUNCTION lm_brk_away_rst_parent_batch (
        i_type_flag   IN            VARCHAR2,
        i_batch_no    IN            batch.batch_no%TYPE,
        i_location    IN            VARCHAR2,
        i_equip_id    IN            equip.equip_id%TYPE,
        i_user_id     IN            batch.user_id%TYPE
    ) RETURN rf.status AS

        l_ret_val                   rf.status := rf.status_normal;
        l_func_name                 VARCHAR2(50) := 'pl_lm_forklift.lm_brk_away_rst_parent_batch';
        l_msku_batch_flag           VARCHAR2(1); 	/* batch.msku_batch_flag */
        l_temp                      NUMBER;  		 /* Work area */
        l_reset_batch_no            batch.batch_no%TYPE;    /* The batch to reset */
        l_parent_batch_flag         VARCHAR2(2);     /* Designates if the batch to signoff is a parent batch or not.*/
        l_new_parent                VARCHAR2(14);
        l_new_parent_ind            NUMBER;
        l_returns_batch_no_prefix   VARCHAR2(1) := lmf.forklift_returns_putaway;/* Returns batch prefix */
        CURSOR c_break_parent_cur IS
        SELECT
            b.batch_no,
            nvl(b.msku_batch_flag, 'N') msku_batch_flag
        FROM
            batch b
        WHERE
            ( pl_lmf.task_completed_for_batch(b.batch_no) = 'N'
              OR ( b.parent_batch_no LIKE l_returns_batch_no_prefix || '%' ) )
            AND b.parent_batch_no = i_batch_no
        ORDER BY
            DECODE(substr(b.batch_no, 1, 1), l_returns_batch_no_prefix, '0', '1');

        CURSOR c_break_non_put_parent_cur IS
        SELECT
            batch_no,
            nvl(msku_batch_flag, 'N') msku_batch_flag
        FROM
            batch
        WHERE
            parent_batch_no = i_batch_no;

    BEGIN
        pl_text_log.ins_msg_async('INFO', l_func_name, 'Starting lm_brk_away_rst_parent_batch .......type_flag=	 '
                                            || i_type_flag
                                            || ' batch_no= '
                                            || i_batch_no
                                            || ' location= '
                                            || i_location
                                            || ' equip_id= '
                                            || i_equip_id
                                            || ' user_id= '
                                            || i_user_id, sqlcode, sqlerrm);

        l_parent_batch_flag := 'Y';
        IF ( i_type_flag = lmf.forklift_putaway OR i_type_flag = lmf.forklift_nondemand_rpl OR i_type_flag = lmf.forklift_demand_rpl
        ) THEN
			/*
			** Processing a putaway, non-demand repl or demand repl batch which
			** is handled differently from other batch types in that a HL haul
			** batch will be created for the pallets not putaway or replenished.
			**
			** NOTE: The parent should batch always need to be done except for
			**       a returns T batch.
			** prpbcb
			** Special processing for a returns T batch.
			** This point will be reached for a returns T batch because it will
			** never be a pallet_batch_no in the putawaylst table.
			** A returns T batch will never be a task that is done so it needs
			** to be flagged as not done.  The T batch will always be the
			** parent batch of the returns FP batch(s).
			*/
            IF substr(i_batch_no, 1, 1) = lmf.forklift_returns_putaway THEN
                l_parent_batch_flag := 'N';
            ELSE
                l_parent_batch_flag := 'Y';
            END IF;

            IF l_ret_val = rf.status_normal THEN
                OPEN c_break_parent_cur;
                FETCH c_break_parent_cur INTO
                    l_reset_batch_no,
                    l_msku_batch_flag;
                IF c_break_parent_cur%found THEN
                    l_reset_batch_no := trim(l_reset_batch_no);
                ELSE
                    pl_text_log.ins_msg_async('WARN', l_func_name, 'Failed to find PUT parent batch for reset.For batch ' || i_batch_no, sqlcode
                    , sqlerrm);
                    l_ret_val := rf.status_no_lm_parent_found;
                END IF;

                IF l_msku_batch_flag = 'N' THEN
					/*
					** Not a MSKU pallet.
					** For the putaway tasks not done create a haul batch for
					** the pallet.
					*/
                    WHILE l_ret_val = rf.status_normal LOOP
                        l_ret_val := lm_brk_away_convert_mrg_to_hl(l_reset_batch_no, i_location, i_equip_id);
                        IF l_ret_val = rf.status_normal THEN
                            BEGIN
                                FETCH c_break_parent_cur INTO
                                    l_reset_batch_no,
                                    l_msku_batch_flag;
                                IF c_break_parent_cur%found  OR c_break_parent_cur%NOTFOUND THEN
                                    l_reset_batch_no := trim(l_reset_batch_no);
                                    if c_break_parent_cur%NOTFOUND  then
                                        EXIT;
                                    end if;
                                ELSE
                                    pl_text_log.ins_msg_async('WARN', l_func_name, 'Failed looking for PUT child batches for reset.For batch '
                                    || i_batch_no, sqlcode, sqlerrm);
                                    l_ret_val := rf.STATUS_NO_LM_BATCH_FOUND;
                                END IF;

                            END;

                        END IF;

                    END LOOP;  /* end FETCH while */
					/*
					** At this point the batches for the tasks not completed
					** all have a status of W.  Pick the min batch no as the
					** parent leaving it with status W and set the child batch
					** (there may be no child batches) status to M.
					*/

                    IF l_ret_val = rf.status_normal THEN
                        BEGIN
                            UPDATE batch b
                            SET
                                ( parent_batch_no,
                                  status ) = (
                                    SELECT
                                        DECODE(COUNT(*), 1, NULL, MIN(b2.batch_no)),
                                        DECODE(MIN(b2.batch_no), b.batch_no, 'W', 'M')
                                    FROM
                                        batch b2
                                    WHERE
                                        b2.status = 'W'
                                        AND b2.user_id = REPLACE(i_user_id, 'OPS$')
                                    GROUP BY
                                        b2.user_id
                                )
                            WHERE
                                status = 'W'
                                AND user_id = REPLACE(i_user_id, 'OPS$');

                        EXCEPTION
                            WHEN OTHERS THEN
                                pl_text_log.ins_msg_async('INFO', l_func_name, 'Unable to update parent batch number.For user ' || i_user_id
                                , sqlcode, sqlerrm);
                        END;

                    END IF;

                ELSE
					/*
					** Call function with i_batch_no and not
					** l_reset_batch_no even though i_batch_no may be for a
					** completed operation.  The called function will handle things
					** correctly.
					*/
                    l_ret_val := lmf_cvt_mrgd_msku_put_to_haul(i_batch_no, i_location, i_equip_id);
                END IF;

                CLOSE c_break_parent_cur;
            END IF;
			/*
			**  Attach the child batches to new parent name, if new parent.
			*/

            IF l_ret_val = rf.status_normal THEN
                IF substr(l_parent_batch_flag, 1, 1) = 'N' THEN
					/*
					**  Select first batch as new parent.
					*/
                    BEGIN
                        SELECT
                            batch_no
                        INTO l_new_parent
                        FROM
                            batch
                        WHERE
                            status = 'A'
                            AND parent_batch_no = i_batch_no;

                    EXCEPTION
                        WHEN no_data_found THEN
                            pl_text_log.ins_msg_async('WARN', l_func_name, 'LMF ORACLE failed to find new parent batch id after reset. For batch '
                            || i_batch_no, sqlcode, sqlerrm);
                            l_ret_val := rf.status_no_lm_batch_found;
                    END;

                    IF l_ret_val = rf.status_normal THEN
                        l_new_parent := trim(l_new_parent);
						/*Only update the exception batches.*/
                        BEGIN
                            UPDATE batch
                            SET
                                status = 'A'
                            WHERE
                                batch_no = l_new_parent;

                        EXCEPTION
                            WHEN OTHERS THEN
                                pl_text_log.ins_msg_async('WARN', l_func_name, 'Failed to update status for the new parent batch. For batch '
                                || l_new_parent, sqlcode, sqlerrm);
                                l_ret_val := rf.status_lm_parent_upd_fail;
                        END;

                    END IF;

                    IF l_ret_val = rf.status_normal THEN
						/*
						** At this point the putaway batches where the putaway
						** operation was completed still have the original
						** parent batch number (i_batch_no) which is a FP batch
						** for regular putaway or the T batch for a returns
						** putaway.  The haul batch(s) still have the parent batch
						** number (i_batch_no) of the putaway batches they were
						** created from.  The batches where the putaway operation
						** was not completed have been reset.  The returns T batch
						** is always reset.
						** 
						** Now what needs to happen is to update the parent batch
						** number of the completed putaways and the parent batch
						** number of the created haul batches to the haul batch
						** number.
						**
						** For returns putaway it is possible the haul batch will
						** not have any child batches so the haul batch parent
						** pallet id needs to be cleared out.  Remember that the
						** returns T batch will always be a parent batch so this
						** lmg_reset_parent_batch function is called even if there
						** is only one LP on the return.  Also if there were
						** multiple LP's on the T batch and a func1 made before
						** putting anything away there will be only the single haul
						** batch for it.  The same applies for a regular MSKU.
						**
						** NOTE:  A regular MSKU and a returns T batch are both
						**        flagged as MSKU batches.
						**
						*/
                        IF l_msku_batch_flag = 'N' THEN
                            l_new_parent_ind := 0;  /* We want the value */
                        ELSE
							/*
							** A little different processing for a MSKU batch.
							**
							** See how many batches are still tied to the original
							** parent batch (i_batch_no).  If there is only one
							** then the parent batch number needs to be cleared out
							** otherwise the parent batch number needs to be set to
							** the new parent batch which will be the haul batch.
							*/
                            BEGIN
                                SELECT
                                    COUNT(*)
                                INTO l_temp
                                FROM
                                    batch
                                WHERE
                                    parent_batch_no = i_batch_no;

                            EXCEPTION
                                WHEN OTHERS THEN
                                    pl_text_log.ins_msg_async('WARN', l_func_name, 'Failed to find count of batches with parent batch# = '|| i_batch_no, sqlcode, sqlerrm);
                                    l_ret_val := rf.status_no_lm_batch_found;
                            END;

                            IF l_ret_val = rf.status_normal THEN
                                IF l_temp <= 1 THEN		/* Ideally value should be >= 1 */
									/*
									** Parent batch flag was initialized to Y.
									** Now set it to N because we have only a
									** single batch.
									*/
                                    l_parent_batch_flag := 'N';
                                    l_new_parent_ind := -1;
                                ELSE
                                    l_new_parent_ind := 0;
                                END IF;

                            END IF;

                        END IF;

                        IF l_ret_val = rf.status_normal THEN
                            IF l_new_parent_ind = 0 THEN
                                BEGIN
                                    UPDATE batch
                                    SET
                                        parent_batch_no = l_new_parent
                                    WHERE
                                        parent_batch_no = i_batch_no;

                                EXCEPTION
                                    WHEN OTHERS THEN
                                        pl_text_log.ins_msg_async('WARN', l_func_name, 'Failed to attach to new parent batch after reset.For batch '
                                        || i_batch_no, sqlcode, sqlerrm);
                                        l_ret_val := rf.status_lm_parent_upd_fail;
                                END;
                            ELSIF l_new_parent_ind = -1 THEN
                                BEGIN
                                    UPDATE batch
                                    SET
                                        parent_batch_no = NULL
                                    WHERE
                                        parent_batch_no = i_batch_no;

                                EXCEPTION
                                    WHEN OTHERS THEN
                                        pl_text_log.ins_msg_async('WARN', l_func_name, 'LMF ORACLE failed to attach to new parent batch after reset.For batch '
                                        || i_batch_no, sqlcode, sqlerrm);
                                        l_ret_val := rf.status_lm_parent_upd_fail;
                                END;
                            END IF;

                            IF l_ret_val = rf.status_normal THEN
                                l_ret_val := lm_signoff_from_forklift_batch(l_new_parent, i_equip_id, i_user_id, l_parent_batch_flag
                                );
                            END IF;

                        END IF;

                    END IF;

                ELSIF ( substr(l_parent_batch_flag, 1, 1) = 'Y' ) THEN
                    l_ret_val := lm_signoff_from_forklift_batch(i_batch_no, i_equip_id, i_user_id, l_parent_batch_flag);
                END IF;
            END IF;

        ELSE
			/*
			** Batch to reset is not a putaway batch
			*/
            OPEN c_break_non_put_parent_cur;
            FETCH c_break_non_put_parent_cur INTO
                l_reset_batch_no,
                l_msku_batch_flag;
            IF c_break_non_put_parent_cur%found THEN
                l_reset_batch_no := trim(l_reset_batch_no);
            ELSE
                pl_text_log.ins_msg_async('WARN', l_func_name, 'Failed to find non-PUT parent batch for reset.', sqlcode, sqlerrm);
                l_ret_val := rf.status_no_lm_parent_found;
            END IF;
			/*
			** Special processing if a NDM or DMD for a MSKU pallet.
			*/

            IF ( l_ret_val = rf.status_normal AND l_msku_batch_flag = 'Y' AND ( i_type_flag = lmf.forklift_nondemand_rpl OR i_type_flag

            = lmf.forklift_demand_rpl ) ) THEN
                CLOSE c_break_non_put_parent_cur;
                l_ret_val := lmf_reset_msku_letdown_batch(i_batch_no, i_equip_id, i_user_id);
            ELSE
                WHILE l_ret_val = rf.status_normal LOOP
                    IF substr(l_reset_batch_no, 1, 1) = 'H' THEN
                        l_ret_val := lmf_reset_haul_batch(l_reset_batch_no, i_location);
                    ELSE
                        l_ret_val := lmf_reset_batch(l_reset_batch_no);
                    END IF;

                    IF l_ret_val = rf.status_normal THEN
                        FETCH c_break_non_put_parent_cur INTO
                            l_reset_batch_no,
                            l_msku_batch_flag;
                        IF c_break_non_put_parent_cur%found THEN
                            l_reset_batch_no := trim(l_reset_batch_no);
                        ELSE
                            pl_text_log.ins_msg_async('WARN', l_func_name, 'LMF ORACLE failed looking for non-PUT child batches for reset.',
                            sqlcode, sqlerrm);
                            l_ret_val := rf.status_no_lm_batch_found;
                        END IF;

                    END IF;

                END LOOP;  /* end while */

                CLOSE c_break_non_put_parent_cur;
            END IF;

        END IF;

        RETURN l_ret_val;
    END lm_brk_away_rst_parent_batch;


/*****************************************************************************
**  FUNCTION: 
**     lm_brk_away_convert_mrg_to_hl()
**
**  DESCRIPTION:
**     This function looks up children batches that need to be converted
**     to haul batches.  These batches will be based on the completeness of
**     the putaway task.  If the number of pallets is greater than 1, then
**     a haul parent must be created.
**
**     The end result is putaway batches can be the child batch of a
**     haul batch.
**
**  PARAMETERS:
**     i_batch_no               - Putaway batch
**     i_drop_location          - Location where pallet hauled to.
**     i_equip_id               - Equipment being used.
**
**  RETURN VALUES:  
**     SWMS_NORMAL          - Okay.
**     LM_BATCH_INSERT_FAIL - Failed to create batch.
**     LM_BATCH_SELECT_FAIL - Failed to select batch.
**     LM_BATCH_UPDATE_FAIL - Failed to modify batch.
**	MODIFICATION HISTORY                                               
**  Author      Date        Ver    Description                         
** ----------- ----------  ----  -----------------------------------------    
** KSAR9933	   12/18/2019   1.0    Initial Version   
**
*****************************************************************************/

    FUNCTION lm_brk_away_convert_mrg_to_hl (
        i_batch_no        IN                batch.batch_no%TYPE,
        i_drop_location   IN                batch.kvi_to_loc%TYPE,
        i_equip_id        IN                equip.equip_id%TYPE
    ) RETURN rf.status AS

        l_func_name   VARCHAR2(60) := 'pl_lm_forklift.lm_brk_away_convert_mrg_to_hl';
        l_ret_val     rf.status := rf.status_normal;
        l_hbatch_no   batch.batch_no%TYPE;
    BEGIN
        pl_text_log.ins_msg_async('INFO', l_func_name, 'Starting  lm_brk_away_convert_mrg_to_hl batch_no= '
                                            || i_batch_no
                                            || ' drop_location= '
                                            || i_drop_location
                                            || ' equip_id= '
                                            || i_equip_id, sqlcode, sqlerrm);

        l_ret_val := lm_break_away_cte_hl_btc_id(l_hbatch_no);
        IF l_ret_val = rf.status_normal THEN
            pl_text_log.ins_msg_async('INFO', l_func_name, ' LMF Haul batch id created for merge batch.', sqlcode, sqlerrm);
            l_hbatch_no := trim(l_hbatch_no);
            BEGIN
                INSERT INTO batch (
                    batch_no,
                    batch_date,
                    status,
                    jbcd_job_code,
                    ref_no,
                    kvi_no_piece,
                    kvi_no_pallet,
                    kvi_wt,
                    kvi_cube,
                    kvi_no_item,
                    kvi_no_data_capture,
                    kvi_no_po,
                    kvi_no_loc,
                    kvi_no_case,
                    kvi_no_split,
                    kvi_no_aisle,
                    kvi_no_drop,
                    kvi_from_loc,
                    kvi_to_loc,
                    kvi_distance,
                    goal_time,
                    target_time,
                    user_id,
                    user_supervsr_id,
                    actl_start_time,
                    actl_stop_time,
                    actl_time_spent,
                    parent_batch_no,
                    parent_batch_date,
                    total_count,
                    total_pallet,
                    total_piece,
                    equip_id,
                    msku_batch_flag,
                    ref_batch_no,
                    initial_pickup_scan_date,
                    cmt
                )
                    SELECT
                        l_hbatch_no       batch_no,
                        trunc(SYSDATE) batch_date,
                        status,
                        substr(jbcd_job_code, 1, 3)
                        || 'HAL' jbcd_job_code,
                        ref_no,
                        kvi_no_piece,
                        kvi_no_pallet,
                        kvi_wt,
                        kvi_cube,
                        kvi_no_item,
                        kvi_no_data_capture,
                        kvi_no_po,
                        kvi_no_loc,
                        kvi_no_case,
                        kvi_no_split,
                        kvi_no_aisle,
                        kvi_no_drop,
                        kvi_from_loc,
                        i_drop_location   kvi_to_loc,
                        kvi_distance,
                        0 goal_time,
                        0 target_time,
                        user_id,
                        user_supervsr_id,
                        actl_start_time,
                        actl_stop_time,
                        actl_time_spent,
                        parent_batch_no,
                        parent_batch_date,
                        total_count,
                        total_pallet,
                        total_piece,
                        equip_id,
                        msku_batch_flag,
                        i_batch_no        ref_batch_no,
                        initial_pickup_scan_date,
                        'HAUL CREATED FROM BATCH ' || i_batch_no cmt
                    FROM
                        batch
                    WHERE
                        batch_no = i_batch_no;
						
			 /*
            ** For tracking purposes save the haul batch number in the
            ** batch we created the haul for.
            */

                UPDATE batch
                SET
                    ref_batch_no = l_hbatch_no
                WHERE
                    batch_no = i_batch_no;

                l_ret_val := lmf_insert_haul_trans(l_hbatch_no);
            EXCEPTION
                WHEN dup_val_on_index THEN
                    pl_text_log.ins_msg_async('WARN', l_func_name, 'Duplicate value to create HAUL batch for merged reset.For batch ' || i_batch_no
                    , sqlcode, sqlerrm);
                    l_ret_val := rf.status_lm_batch_upd_fail;
                WHEN OTHERS THEN
                    l_ret_val := rf.status_lm_batch_upd_fail;
            END;
           
			/* Update the PUT transaction if the PO was closed before the pallet was putaway. */

            IF l_ret_val = rf.status_normal THEN
                l_ret_val := lmf_update_put_trans(l_hbatch_no);
            END IF;
            IF l_ret_val = rf.status_normal THEN
            /*
            ** The parent_batch_no is cleared for now.
            ** lm_brk_away_rst_parent_batch() will assign a new one if
            ** necessary.
            */
                BEGIN
                    UPDATE batch
                    SET
                        status = 'W',
                        batch_suspend_date = SYSDATE,
                        actl_start_time = SYSDATE,
                        actl_stop_time = NULL,
                        parent_batch_no = NULL,
                        kvi_from_loc = i_drop_location,
                        dropped_for_a_break_away_flag = 'Y',
                        cmt = 'USER BROKE AWAY TO ANOTHER TASK'
                    WHERE
                        batch_no = i_batch_no;

                EXCEPTION
                    WHEN OTHERS THEN
                        pl_text_log.ins_msg_async('WARN', l_func_name, 'Unable to reset merged batch.For batch ' || i_batch_no, sqlcode, sqlerrm
                        );
                        l_ret_val := rf.status_lm_batch_upd_fail;
                END;
            END IF;

        END IF;
		/*
		** Write audit comment.
		*/

        pl_lm_goaltime.lmg_sel_forklift_audit_syspar(g_forklift_audit);
        IF ( l_ret_val = rf.status_normal AND ( g_forklift_audit != 0 ) ) THEN
            pl_lm_goaltime.lmg_audit_cmt(i_batch_no, 'Task for batch '
                                                     || i_batch_no
                                                     || ' not completed.  Haul batch '
                                                     || l_hbatch_no
                                                     || ' created for the LP', -1);
        END IF;

        RETURN l_ret_val;
    END lm_brk_away_convert_mrg_to_hl;	
    
/*****************************************************************************
**  FUNCTION:
**      lmf_suspend_current_batch()
**  DESCRIPTION:
**      This function suspends the specified forklift batch.
**  PARAMETERS:
**      i_user_id      - Batch to be suspended.
**  RETURN VALUES:
**      SWMS_NORMAL           -  Okay.
**      LM_BATCH_UPDATE_FAIL  -  Unable to update specified batch.
*****************************************************************************/

    FUNCTION lmf_suspend_current_batch (
        i_user_id IN VARCHAR2
    ) RETURN rf.status AS
        l_func_name   VARCHAR2(50) := 'pl_lm_forklift.lmf_suspend_current_batch';
        l_ret_val     rf.status := rf.status_normal;
    BEGIN
        pl_text_log.ins_msg_async('INFO', l_func_name, 'Changing status of active batch for user from A to W, for user = ' || i_user_id, sqlcode
        , sqlerrm);
        BEGIN
            UPDATE batch
            SET
                status = 'W',
                batch_suspend_date = SYSDATE
            WHERE
                user_id = REPLACE(i_user_id, 'OPS$')
                AND status = 'A';

        EXCEPTION
            WHEN OTHERS THEN
                pl_text_log.ins_msg_async('WARN', l_func_name, 'LMF ORACLE unable to suspend current forklift batch for user = ' || i_user_id
                , sqlcode, sqlerrm);
                l_ret_val := rf.status_lm_batch_upd_fail;
        END;

        RETURN l_ret_val;
    END lmf_suspend_current_batch;
	
/*****************************************************************************
**  Function:
**      lmf_find_suspended_batch()
**
**  Description:
**      This function finds the last suspended forklift batch for the user.
**      5/2/03 At this time a user should have only one suspended batch.
**
**  Parameters:
**      i_user_id            - User attached to batch.
**      o_batch_no           - Batch returned to call function.
**
**  Return Values:
**      SWMS_NORMAL          - Okay.
**      LM_BATCH_UPD_FAIL    - Denotes a database error while looking for
**                             for suspended batch.
**      NO_LM_BATCH_FOUND    - Denotes that there are no suspended batches
**                             for the specified user which is OK.
******************************************************************************/

    FUNCTION lmf_find_suspended_batch (
        i_user_id    IN           VARCHAR2,
        o_batch_no   OUT          batch.batch_no%TYPE
    ) RETURN rf.status AS

        l_func_name        VARCHAR2(50) := 'pl_lm_forklift.lmf_find_suspended_batch';
        l_ret_val          rf.status := rf.status_normal;
        l_s_batch_no_ind   NUMBER;
        CURSOR c_batch IS
        SELECT
            batch_no
        FROM
            batch
        WHERE
            status = 'W'
            AND user_id = REPLACE(i_user_id, 'OPS$')
        ORDER BY
            actl_start_time DESC;

    BEGIN
        pl_text_log.ins_msg_async('INFO', l_func_name, 'Starting lmf_find_suspended_batch for user ' || i_user_id, sqlcode, sqlerrm);
		  /*
		** Look for last suspended batch first.
		**  At this time there should be only one suspended batch
		** for the user.
		**  There can be more than one suspended batch for a user.
		** See the file modification history for more info.
		*/
        BEGIN
            OPEN c_batch;
            FETCH c_batch INTO o_batch_no;
            IF o_batch_no IS NULL THEN
                pl_text_log.ins_msg_async('INFO', l_func_name, 'LMF ORACLE No suspended batches found for user ' || i_user_id, sqlcode, sqlerrm
                );
                l_ret_val := rf.status_no_lm_batch_found;
            ELSE
                pl_text_log.ins_msg_async('INFO', l_func_name, 'Found suspended batch for the user ' || i_user_id, sqlcode, sqlerrm);
            END IF;

            CLOSE c_batch;
        EXCEPTION
            WHEN OTHERS THEN
                pl_text_log.ins_msg_async('INFO', l_func_name, 'Error fetching data for suspended batch for the user.', sqlcode, sqlerrm);
                CLOSE c_batch;
                l_ret_val := rf.status_lm_batch_upd_fail;
        END;

        RETURN l_ret_val;
    EXCEPTION
        WHEN OTHERS THEN
            l_ret_val := rf.status_data_error;
            pl_text_log.ins_msg_async('FATAL', l_func_name, 'Error in lmf_find_suspended_batch.', sqlcode, sqlerrm);
            RETURN l_ret_val;
    END lmf_find_suspended_batch;
	
/*****************************************************************************
**  FUNCTION:
**      lmf_activate_suspended_batch()
**  DESCRIPTION:
**      This function finds any suspended batch for the user.
**      User was already assigned to this batch once before.
**  PARAMETERS:
**      i_batch_no char     - Batch returned to call function.
**  RETURN VALUES:
**      SWMS_NORMAL          - Okay.
**      LM_BATCH_UPDATE_FAIL - Denotes a Database error while updating
**                             the specified batch.
*****************************************************************************/

    FUNCTION lmf_activate_suspended_batch (
        i_batch_no   IN           batch.batch_no%TYPE
    ) RETURN rf.status AS
        l_func_name   VARCHAR2(50) := 'pl_lm_forklift.lmf_activate_suspended_batch';
        l_ret_val     rf.status := rf.status_normal;
    BEGIN
        pl_text_log.ins_msg_async('INFO', l_func_name, 'Starting lmf_activate_suspended_batch for batch# ' || i_batch_no, sqlcode, sqlerrm);
        UPDATE batch
        SET
            status = 'A'
        WHERE
            status = 'W'
            AND batch_no = i_batch_no;

        l_ret_val := rf.status_lm_susp_batch_actv;
        pl_text_log.ins_msg_async('INFO', l_func_name, 'Ending lmf_activate_suspended_batch', sqlcode, sqlerrm);
        RETURN l_ret_val;
    EXCEPTION
        WHEN OTHERS THEN
            pl_text_log.ins_msg_async('WARN', l_func_name, 'LMF ORACLE unable to activate suspended forklift batch for batch# ' || i_batch_no
            , sqlcode, sqlerrm);
            l_ret_val := rf.status_lm_batch_upd_fail;
            RETURN l_ret_val;
    END lmf_activate_suspended_batch;
	
/*****************************************************************************
**  Function:
**     lmf_create_dflt_fk_ind_batch()
**
**  Description:
**     This function creates a default indirect batch when a user chooses to
**     cancel the forklift operation.
**
**     All the parameters need to be null terminated.
**
**  Parameters:
**     i_batch_no     - The users last completed batch.  It is used in
**                      creating the default indirect batch.
**     i_user_id      - User performing operation.
**     i_ref_no       - Reference # for the default indirect batch.
**     i_start_time   - The start time to use for the default indirect
**                      batch if it has a value (not a 0 length string).
**                      The format is DDMMYYYYHH24MISS.  If the user has a
**                      suspended batch then the start time of the default
**                      indirect batch will be the start time of the batch
**                      being reset which will be in this parameter.  This
**                      determination has already taken place.  If i_start_time
**                      has no value then the start time of the default
**                      indirect batch is the stop time of the last completed
**                      batch for the user.
**
**  Return Values:
**     SWMS_NORMAL  --  Okay.
**     LM_INS_FL_DFLT_FAIL  --  Failed to insert forklift indirect default
**                               batch.
**
**  Called By:
**     - lm_reset_current_fklft_batch
************************************************************************************/

    FUNCTION lmf_create_dflt_fk_ind_batch (
        i_batch_no     IN             batch.batch_no%TYPE,
        i_user_id      IN             batch.user_id%TYPE,
        i_ref_no       IN             batch.ref_no%TYPE,
        i_start_time   IN             batch.actl_start_time%TYPE
    ) RETURN rf.status AS

        l_func_name     VARCHAR2(50) := 'pl_lm_forklift.lmf_create_dflt_fk_ind_batch';
        l_ret_val       rf.status := rf.status_normal;
        l_batch_no      batch.batch_no%TYPE;
        l_ref_no        VARCHAR(41);
        vc_start_time   VARCHAR(30);
    BEGIN
        pl_text_log.ins_msg_async('INFO', l_func_name, 'Starting lmf_create_dflt_fk_ind_batch. Batch='
                                            || i_batch_no
                                            || ' user_id '
                                            || i_user_id
                                            || ' ref_no '
                                            || i_ref_no
                                            || ' start_time '
                                            || i_start_time, sqlcode, sqlerrm);

        l_ref_no := i_ref_no;
        vc_start_time := i_start_time;
        BEGIN
            SELECT
                'I' || TO_CHAR(seq1.NEXTVAL)
            INTO l_batch_no
            FROM
                dual;

            pl_text_log.ins_msg_async('INFO', l_func_name, 'Default indirect batch=' || l_batch_no, sqlcode, sqlerrm);
            INSERT INTO batch (
                batch_no,
                jbcd_job_code,
                status,
                actl_start_time,
                user_id,
                user_supervsr_id,
                ref_no,
                batch_date
            )
                SELECT
                    l_batch_no,
                    sc.config_flag_val,
                    'A',
                    DECODE(vc_start_time, NULL, b.actl_stop_time, TO_DATE(vc_start_time, 'FXDDMMYYYYHH24MISS')),
                    b.user_id,
                    b.user_supervsr_id,
                    l_ref_no,
                    trunc(SYSDATE)
                FROM
                    sys_config   sc,
                    batch        b
                WHERE
                    sc.config_flag_name = 'LM_FK_DFLT_IND_JOBCODE'
                    AND b.user_id = REPLACE(i_user_id, 'OPS$')
                    AND b.status = 'C'
                    AND b.batch_no = i_batch_no;

            pl_text_log.ins_msg_async('WARN', l_func_name, 'LMF ORACLE created default indirect forklift batch for user '
                                                || i_user_id
                                                || ' batch= '
                                                || i_batch_no, sqlcode, sqlerrm);

        EXCEPTION
            WHEN OTHERS THEN
                pl_text_log.ins_msg_async('WARN', l_func_name, 'unable to create default indirect forklift for batch= ' || i_batch_no, sqlcode
                , sqlerrm);
                l_ret_val := rf.status_lm_ins_fl_dflt_fail;
                RETURN l_ret_val;
        END;

        RETURN l_ret_val;
    END lmf_create_dflt_fk_ind_batch;
    
/*****************************************************************************
**  FUNCTION:
**     lmf_convert_merged_put_to_haul()
**
**  DESCRIPTION:
**     This function looks up children batches that need to be converted
**     to haul batches.  These batches will be based on the completeness of
**     the putaway task.  If the number of pallets is greater than 1, then
**     a haul parent must be created.
**
**     The end result is putaway batches can be the child batch of a
**     haul batch.
**
**  PARAMETERS:
**     i_batch_no               - Putaway batch
**     i_drop_location          - Location where pallet hauled to.
**     i_equip_id               - Equipment being used.
**
**  RETURN VALUES:
**     SWMS_NORMAL          - Okay.
**     LM_BATCH_INSERT_FAIL - Failed to create batch.
**     LM_BATCH_SELECT_FAIL - Failed to select batch.
**     LM_BATCH_UPDATE_FAIL - Failed to modify batch.
****************************************************************************/

    FUNCTION lmf_convert_merged_put_to_haul (
        i_batch_no        IN                batch.batch_no%TYPE,
        i_drop_location   IN                VARCHAR2,
        i_equip_id        IN                equip.equip_id%TYPE
    ) RETURN rf.status AS

        l_func_name         VARCHAR2(50) := 'pl_lm_forklift.lmf_convert_merged_put_to_haul';
        l_ret_val           rf.status := rf.status_normal;
        l_hbatch_no         batch.batch_no%TYPE;
        l_parent_batch_no   batch.batch_no%TYPE;
    BEGIN
        pl_text_log.ins_msg_async('INFO', l_func_name, 'Starting lmf_convert_merged_put_to_haul. Batch='
                                            || i_batch_no
                                            || ' drop_location '
                                            || i_drop_location
                                            || ' equip_id '
                                            || i_equip_id, sqlcode, sqlerrm);

        l_ret_val := lmf_create_haul_batch_id(l_hbatch_no);
        IF ( l_ret_val = rf.status_normal ) THEN
            pl_text_log.ins_msg_async('INFO', l_func_name, 'LMF ORACLE Haul batch id created for merge batch.', sqlcode, sqlerrm);
            BEGIN
                INSERT INTO batch (
                    batch_no,
                    batch_date,
                    status,
                    jbcd_job_code,
                    ref_no,
                    kvi_no_piece,
                    kvi_no_pallet,
                    kvi_wt,
                    kvi_cube,
                    kvi_no_item,
                    kvi_no_data_capture,
                    kvi_no_po,
                    kvi_no_loc,
                    kvi_no_case,
                    kvi_no_split,
                    kvi_no_aisle,
                    kvi_no_drop,
                    kvi_from_loc,
                    kvi_to_loc,
                    kvi_distance,
                    goal_time,
                    target_time,
                    user_id,
                    user_supervsr_id,
                    actl_start_time,
                    actl_stop_time,
                    actl_time_spent,
                    parent_batch_no,
                    parent_batch_date,
                    total_count,
                    total_pallet,
                    total_piece,
                    equip_id,
                    msku_batch_flag,
                    cmt
                )
                    SELECT
                        l_hbatch_no,
                        trunc(SYSDATE),
                        status,
                        substr(jbcd_job_code, 1, 3)
                        || 'HAL',
                        ref_no,
                        kvi_no_piece,
                        kvi_no_pallet,
                        kvi_wt,
                        kvi_cube,
                        kvi_no_item,
                        kvi_no_data_capture,
                        kvi_no_po,
                        kvi_no_loc,
                        kvi_no_case,
                        kvi_no_split,
                        kvi_no_aisle,
                        kvi_no_drop,
                        kvi_from_loc,
                        i_drop_location,
                        kvi_distance,
                        0,
                        0,
                        user_id,
                        user_supervsr_id,
                        actl_start_time,
                        actl_stop_time,
                        actl_time_spent,
                        parent_batch_no,
                        parent_batch_date,
                        total_count,
                        total_pallet,
                        total_piece,
                        equip_id,
                        msku_batch_flag,
                        cmt
                    FROM
                        batch
                    WHERE
                        batch_no = i_batch_no;

                l_ret_val := lmf_insert_haul_trans(l_hbatch_no);
                IF ( l_ret_val = rf.status_normal ) THEN
                    BEGIN
                        UPDATE batch
                        SET
                            status = 'F',
                            actl_time_spent = NULL,
                            actl_start_time = NULL,
                            actl_stop_time = NULL,
                            user_id = NULL,
                            user_supervsr_id = NULL,
                            parent_batch_no = NULL,
                            parent_batch_date = NULL,
                            equip_id = NULL,
                            kvi_from_loc = i_drop_location,
                            total_count = 1,
                            total_piece = 0,
                            total_pallet = 1
                        WHERE
                            batch_no = i_batch_no;

                    EXCEPTION
                        WHEN OTHERS THEN
                            pl_text_log.ins_msg_async('WARN', l_func_name, 'LMF ORACLE Unable to reset merged for batch= ' || i_batch_no, sqlcode
                            , sqlerrm);
                            l_ret_val := rf.status_lm_batch_upd_fail;
                    END;
                END IF;

            EXCEPTION
                WHEN OTHERS THEN
                    pl_text_log.ins_msg_async('WARN', l_func_name, 'Unable to create HAUL batch for merged reset.For batch= ' || i_batch_no,
                    sqlcode, sqlerrm);
                    l_ret_val := rf.status_lm_batch_upd_fail;
            END;

        END IF;

        pl_text_log.ins_msg_async('INFO', l_func_name, 'Ending lmf_convert_merged_put_to_haul', sqlcode, sqlerrm);
        return(l_ret_val);
    END lmf_convert_merged_put_to_haul;
	
/*****************************************************************************
**  Function:
**     lmf_reset_parent_batch()
**
**  Description:
**     This function resets the specified forklift parent batch.
**     This is done when the operator func1's out in the middle
**     of the operation.
**
**     It must determine whether or not the parent operation has been
**       performed.
**     If the parent batch's operation is complete.
**       Deattach each child batch with incomplete operation.
**       If no children, change batch to normal batch and complete batch.
**       Else Complete parent batch.
**     Else the parent batch's operation is not complete.
**       Deattach child batches from parent.
**       If more than two child batches have operations performed,
**       Then designate the child batch with the lowest pick path as the
**            parent.  Update parent batch in child batches with operations
**            performed to be new parent.  Complete parent batch.
**       Else complete the batch performed as normal batch.
**
**  Parameters:
**     i_type_flag        - Type of forklift batch.
**     i_batch_no         - Batch to be reset.
**     i_location         - Drop location of pallets.
**     i_equip_id         - Equipment being used.
**     i_user_id          - User performing operation.
**  Return Values:
**     SWMS_NORMAL  --  Okay.
**     LM_BATCH_UPDATE_FAIL  --  Unable to modify specified batch.
*********************************************************************************/

    FUNCTION lmf_reset_parent_batch (
        i_type_flag   IN            VARCHAR2,
        i_batch_no    IN            batch.batch_no%TYPE,
        i_location    IN            VARCHAR2,
        i_equip_id    IN            equip.equip_id%TYPE,
        i_user_id     IN            VARCHAR2
    ) RETURN rf.status AS

        l_func_name                   VARCHAR2(50) := 'pl_lm_forklift.lmf_reset_parent_batch';
        l_ret_val                     rf.status := rf.status_normal;
        l_message                     VARCHAR2(1024);
        l_msku_batch_flag             VARCHAR(2);
        l_temp                        NUMBER;
        l_reset_batch_no              batch.batch_no%TYPE;
        l_parent_putaway_done         VARCHAR2(2);
        l_new_parent                  batch.batch_no%TYPE;
        l_new_parent_ind              NUMBER;
        l_t_returns_batch_no_prefix   VARCHAR2(1) := lmf.forklift_returns_putaway;
        l_sz_parent_batch_flag        VARCHAR2(2);
        CURSOR c_put_parent_cur IS
        SELECT
            b.batch_no,
            nvl(b.msku_batch_flag, 'N') msku_batch_flag
        FROM
            batch b
        WHERE
            ( EXISTS (
                SELECT
                    'x'
                FROM
                    putawaylst p
                WHERE
                    p.putaway_put = 'N'
                    AND p.pallet_batch_no = b.batch_no
            )
              OR ( b.parent_batch_no LIKE l_t_returns_batch_no_prefix || '%' ) )
            AND b.parent_batch_no = i_batch_no
        ORDER BY
            DECODE(substr(b.batch_no, 1, 1), l_t_returns_batch_no_prefix, '0', '1');

        CURSOR c_non_put_parent_cur IS
        SELECT
            batch_no,
            nvl(msku_batch_flag, 'N') msku_batch_flag
        FROM
            batch
        WHERE
            parent_batch_no = i_batch_no;

    BEGIN
        pl_text_log.ins_msg_async('INFO', l_func_name, 'Starting lmf_reset_parent_batch. Type_flag='
                                            || i_type_flag
                                            || ' batch_no '
                                            || i_batch_no
                                            || ' location '
                                            || i_location
                                            || ' equip_id '
                                            || i_equip_id
                                            || ' user_id '
                                            || i_user_id, sqlcode, sqlerrm);

        l_sz_parent_batch_flag := 'Y';
        IF ( i_type_flag = lmf.forklift_putaway ) THEN
			/*
			  **  Processing a putaway batch which is handled differently from
			  **  other batch types in that a haul batch will be created for the
			  **  pallets not putaway.
			  **
			  **  Find out if parent is done.
			  */
            BEGIN
                SELECT
                    p.putaway_put
                INTO l_parent_putaway_done
                FROM
                    putawaylst p
                WHERE
                    p.pallet_batch_no = i_batch_no;

            EXCEPTION
                WHEN no_data_found THEN
				  /*
					  ** Did not find the putaway task for the LP of the parent batch.
					  ** This means the LP has been putaway and the PO is closed.
					  ** When a PO is closed the completed putaway tasks are deleted.
					  ** Or it is a returns T batch.
					  */
				  /*
						*
						** Special processing for a returns T batch.
						** This point will be reached for a returns T batch because it will
						** never be a pallet_batch_no in the putawaylst table.
						** A returns T batch will never be a task that is done so it needs
						** to be flagged as not done.  The T batch will always be the
						** parent batch of the returns FP batch(s).
						*/
                    IF ( i_batch_no = lmf.forklift_returns_putaway ) THEN
                        l_parent_putaway_done := 'N';
                    ELSE
                        l_parent_putaway_done := 'Y';
                    END IF;
                WHEN OTHERS THEN
						/*
						** Got an oracle error when selecting from putawaylst.
						*/
                    l_ret_val := rf.status_inv_putlst;
            END;

            IF ( l_ret_val = rf.status_normal ) THEN
				  /*
				** Always select the returns T batch and always select it first.
				** The returns T batch is considered a MSKU so the msku_batch_flag
				** will be Y.
				*/
                BEGIN
                    OPEN c_put_parent_cur;
                    FETCH c_put_parent_cur INTO
                        l_reset_batch_no,
                        l_msku_batch_flag;
                EXCEPTION
                    WHEN OTHERS THEN
                        pl_text_log.ins_msg_async('WARN', l_func_name, 'LMF ORACLE failed to find PUT parent batch for reset. Batch no ' || i_batch_no
                        , sqlcode, sqlerrm);
                        l_ret_val := rf.status_no_lm_parent_found;
                END;

                IF ( l_msku_batch_flag = 'N' ) THEN
                    WHILE ( l_ret_val = rf.status_normal ) LOOP
                        l_ret_val := lmf_convert_merged_put_to_haul(l_reset_batch_no, i_location, i_equip_id);
                        IF ( l_ret_val = rf.status_normal ) THEN
                            BEGIN
                                FETCH c_put_parent_cur INTO
                                    l_reset_batch_no,
                                    l_msku_batch_flag;
                                EXIT WHEN c_put_parent_cur%NOTFOUND;
                            EXCEPTION
                                WHEN OTHERS THEN
                                    pl_text_log.ins_msg_async('WARN', l_func_name, 'LMF ORACLE failed looking for PUT child batches for reset.'
                                    , sqlcode, sqlerrm);
                                    l_ret_val := rf.status_no_lm_batch_found;
                            END;

                        END IF;

                    END LOOP;

                ELSE
					/*
					** Processing a MSKU pallet.
					** Only one pallet needs to be processed.  The called function
					** handles the MSKU.
					**
					** 03/16/05  prpbcb Call function with i_batch_no and not
					** l_reset_batch_no even though i_batch_no may be for a
					** completed operation.  The called function will handle things
					** correctly.
					*/
                    l_ret_val := lmf_cvt_mrgd_msku_put_to_haul(i_batch_no, i_location, i_equip_id);
                END IF;

                CLOSE c_put_parent_cur;
            END IF;
				/*
				**  Attach the child batches to new parent name, if new parent.
				*/

            IF ( l_ret_val = rf.status_normal ) THEN
                IF ( l_parent_putaway_done = 'N' ) THEN
					/*
						**  Select first batch as new parent.
					*/
                    BEGIN
                        SELECT
                            batch_no
                        INTO l_new_parent
                        FROM
                            batch
                        WHERE
                            status = 'A'
                            AND parent_batch_no = i_batch_no;
          
					/* debug stuff */

                    EXCEPTION
                        WHEN OTHERS THEN
                            pl_text_log.ins_msg_async('WARN', l_func_name, 'LMF ORACLE failed to find new parent batch id after reset.For batch= '
                            || i_batch_no, sqlcode, sqlerrm);
                            l_ret_val := rf.status_no_lm_batch_found;
                    END;

                    IF ( l_ret_val = rf.status_normal ) THEN
						/*
							** Only update the exception batches.
						*/
                        BEGIN
                            UPDATE batch
                            SET
                                status = 'A'
                            WHERE
                                batch_no = l_new_parent;

                        EXCEPTION
                            WHEN OTHERS THEN
                                pl_text_log.ins_msg_async('WARN', l_func_name, 'LMF ORACLE failed to attach to new parent batch after reset.For parent batch= '
                                || l_new_parent, sqlcode, sqlerrm);
                                l_ret_val := rf.status_lm_parent_upd_fail;
                        END;

                    END IF;

                    IF ( l_ret_val = rf.status_normal ) THEN
						  /*
							** At this point the putaway batches where the putaway
							** operation was completed still have the original
							** parent batch number (i_batch_no) which is a FP batch
							** for regular putaway or the T batch for a returns
							** putaway.  The haul batch(s) still have the parent batch
							** number (i_batch_no) of the putaway batches they were
							** created from.  The batches where the putaway operation
							** was not completed have been reset.  The returns T batch
							** is always reset.
							**
							** Now what needs to happen is to update the parent batch
							** number of the completed putaways and the parent batch
							** number of the created haul batches to the haul batch
							** number.
							**
							** For returns putaway it is possible the haul batch will
							** not have any child batches so the haul batch parent
							** pallet id needs to be cleared out.  Remember that the
							** returns T batch will always be a parent batch so this
							** lmg_reset_parent_batch function is called even if there
							** is only one LP on the return.  Also if there were
							** multiple LP's on the T batch and a func1 made before
							** putting anything away there will be only the single haul
							** batch for it.  The same applies for a regular MSKU.
							**
							** NOTE:  A regular MSKU and a returns T batch are both
							**        flagged as MSKU batches.
							**
							*/
                        IF ( l_msku_batch_flag = 'N' ) THEN
                            l_new_parent_ind := 0;
							/* We want the value */
                        ELSE
							/*
								** A little different processing for a MSKU batch.
								**
								** See how many batches are still tied to the original
								** parent batch (i_batch_no).  If there is only one
								** then the parent batch number needs to be cleared out
								** otherwise the parent batch number needs to be set to
								** the new parent batch which will be the haul batch.
							*/
                            BEGIN
                                SELECT
                                    COUNT(*)
                                INTO l_temp
                                FROM
                                    batch
                                WHERE
                                    parent_batch_no = i_batch_no;

                            EXCEPTION
                                WHEN OTHERS THEN
                                    pl_text_log.ins_msg_async('WARN', l_func_name, 'LMF ORACLE failed to find count of batches with parent batch#. For batch= '
                                    || i_batch_no, sqlcode, sqlerrm);
                                    l_ret_val := rf.status_no_lm_batch_found;
                            END;

                            IF ( l_ret_val = rf.status_normal ) THEN
                                IF ( l_temp <= 1 ) THEN
									/* Ideally value should be >= 1 */ 
									/*
									** Parent batch flag was initialized to Y.
									** Now set it to N because we have only a
									** single batch.
									*/
                                    l_sz_parent_batch_flag := 'N';
                                    l_new_parent_ind := -1;
                                ELSE
                                    l_new_parent_ind := 0;
                                END IF;

                            END IF;

                        END IF;

                        IF ( l_ret_val = rf.status_normal ) THEN
                            BEGIN
                                UPDATE batch
                                SET
                                    parent_batch_no = DECODE(l_new_parent_ind, -1, NULL, l_new_parent)
                                WHERE
                                    parent_batch_no = i_batch_no;

                                l_ret_val := lm_signoff_from_forklift_batch(l_new_parent, i_equip_id, i_user_id, l_sz_parent_batch_flag

                                );
                            EXCEPTION
                                WHEN OTHERS THEN
                                    pl_text_log.ins_msg_async('WARN', l_func_name, 'LMF ORACLE failed to attach to new parent batch after reset. For batch= '
                                    || i_batch_no, sqlcode, sqlerrm);
                                    l_ret_val := rf.status_lm_parent_upd_fail;
                            END;

                        END IF;

                    END IF;

                ELSIF ( l_parent_putaway_done = 'Y' ) THEN
                    l_ret_val := lm_signoff_from_forklift_batch(i_batch_no, i_equip_id, i_user_id, l_sz_parent_batch_flag);
                END IF;
            END IF;

        ELSE
		/*
                  ** Batch to reset is not a putaway batch
         */
            BEGIN
                OPEN c_non_put_parent_cur;
                FETCH c_non_put_parent_cur INTO
                    l_reset_batch_no,
                    l_msku_batch_flag;
            EXCEPTION
                WHEN OTHERS THEN
                    pl_text_log.ins_msg_async('WARN', l_func_name, 'LMF ORACLE failed to find non-PUT parent batch for reset.', sqlcode, sqlerrm
                    );
                    l_ret_val := rf.status_no_lm_parent_found;
            END;
            /*
             ** Special processing if a NDM or DMD for a MSKU pallet.
             */

            IF ( l_ret_val = rf.status_normal AND l_msku_batch_flag = 'Y' AND ( i_type_flag = lmf.forklift_nondemand_rpl OR i_type_flag

            = lmf.forklift_demand_rpl ) ) THEN
                CLOSE c_non_put_parent_cur;
                l_ret_val := lmf_reset_msku_letdown_batch(i_batch_no, i_equip_id, i_user_id);
            ELSE
                WHILE ( l_ret_val = rf.status_normal ) LOOP
                    IF ( SUBSTR(l_reset_batch_no,1,1) = 'H' ) THEN
                        l_ret_val := lmf_reset_haul_batch(l_reset_batch_no, i_location);
                    ELSE
                        l_ret_val := lmf_reset_batch(l_reset_batch_no);
                    END IF;

                    IF ( l_ret_val = rf.status_normal ) THEN
                        BEGIN
                            FETCH c_non_put_parent_cur INTO
                                l_reset_batch_no,
                                l_msku_batch_flag;
                            EXIT WHEN c_non_put_parent_cur%NOTFOUND;
                        EXCEPTION
                            WHEN OTHERS THEN
                                pl_text_log.ins_msg_async('WARN', l_func_name, 'LMF ORACLE failed looking for non-PUT child batches for reset.'
                                , sqlcode, sqlerrm);
                                l_ret_val := rf.status_no_lm_batch_found;
                        END;

                    END IF;

                END LOOP;
                CLOSE c_non_put_parent_cur;
            END IF;

        END IF;

        pl_text_log.ins_msg_async('INFO', l_func_name, 'Ending lmf_reset_parent_batch', sqlcode, sqlerrm);
        RETURN l_ret_val;
    END lmf_reset_parent_batch;
	
/*****************************************************************************
**  FUNCTION:
**      lm_determine_blk_pull_door_no()
**
**  DESCRIPTION:
**      This function determines the door number for bulk pulls
**      based on the route door area.  This door# is used in the BATCH record.
**      The door# is first built in the format:
**            floats.door_area||'1'||
**               DECODE(float.door_area, 'D', LTRIM(TO_CHAR(r.d_door, '09')),
**                                       'C', LTRIM(TO_CHAR(r.c_door, '09')),
**                                       'F', LTRIM(TO_CHAR(r.f_door, '09')))
**
**      If this is not a valid door number in the POINT_DISTANCE table
**      then the route door number is searched for in positions 3 and 4 in
**      column point_a in the POINT_DISTANCE table.
**
**  PARAMETERS:
**      i_float_no      - Float number.
**      o_door_no       - Door number determined by this function.
**
**  RETURN VALUES:
**      SWMS_NORMAL - Okay.
**      All others denote errors.
**                        PUT transaction record.
************************************************************************************/

    FUNCTION lm_determine_blk_pull_door_no (
        i_float_no         IN                 floats.float_no%TYPE,
        o_vc_door_no_ptr   OUT                VARCHAR2
    ) RETURN rf.status AS

        l_func_name       VARCHAR2(60) := 'pl_lm_forklift.lm_determine_blk_pull_door_no';
        l_ret_val         rf.status := rf.status_normal;
        l_dummy           NUMBER;
        l_door_no         VARCHAR(20);
        l_route_door_no   VARCHAR(5);
        CURSOR c_door_no_cur IS
        SELECT
            point_a
        FROM
            point_distance
        WHERE
            point_type = 'DA'
            AND point_a LIKE '__' || l_route_door_no;

    BEGIN
        pl_text_log.ins_msg_async('INFO', l_func_name, 'Starting lm_determine_blk_pull_door_no. Float no ' || i_float_no, sqlcode, sqlerrm
        );
        BEGIN
            SELECT
                f.door_area
                || '1'
                || DECODE(f.door_area, 'D', ltrim(TO_CHAR(r.d_door, '09')), 'C', ltrim(TO_CHAR(r.c_door, '09')), 'F', ltrim(TO_CHAR
                (r.f_door, '09'))),
                DECODE(f.door_area, 'D', ltrim(TO_CHAR(r.d_door, '09')), 'C', ltrim(TO_CHAR(r.c_door, '09')), 'F', ltrim(TO_CHAR(
                r.f_door, '09')))
            INTO
                l_door_no,
                l_route_door_no
            FROM
                route    r,
                floats   f
            WHERE
                r.route_no = f.route_no
                AND f.float_no = to_number(i_float_no);
    
		/* Built the door number successfully using the route information.
			Check that it is a valid door# in the point distance table.
			If it is not then check for the route door number in postions
			3 and 4 in the point_a column in POINT_DISTANCE table
			where point_type = 'DA'. */

            BEGIN
                SELECT
                    COUNT(1)
                INTO l_dummy
                FROM
                    point_distance
                WHERE
                    point_type = 'DA'
                    AND point_a = l_door_no
                    AND ROWNUM <= 1;

                IF ( l_dummy > 0 ) THEN
					/* Found the built door# in POINT_DISTANCE table. */
                    o_vc_door_no_ptr := l_door_no;
                ELSE
					/* The built door# not found in POINT_DISTANCE table.  Look
						  for the route door# in positions 3 and 4 in column point_a. */
                    OPEN c_door_no_cur;
                    FETCH c_door_no_cur INTO l_door_no;
                    IF SQL%rowcount = 0 THEN
                        pl_text_log.ins_msg_async('INFO', l_func_name, 'LMF ORACLE unable to select the route door# when building the lm door'
                        , sqlcode, sqlerrm);
                        l_ret_val := rf.status_lm_batch_upd_fail;
                    END IF;

                    o_vc_door_no_ptr := l_door_no;
                    pl_text_log.ins_msg_async('INFO', l_func_name, 'Found door# '
                                                        || l_door_no
                                                        || ' in POINT_DISTANCE table wildcarding with leading', sqlcode, sqlerrm)
                                                        ;

                    CLOSE c_door_no_cur;
                END IF;

            END;

        EXCEPTION
            WHEN no_data_found THEN
                pl_text_log.ins_msg_async('INFO', l_func_name, 'LMF ORACLE did not find route door# in POINT_DISTANCE for point type DA . For float '
                                                    || i_float_no
                                                    || ' door no '
                                                    || l_door_no, sqlcode, sqlerrm);

                l_ret_val := rf.status_lm_batch_upd_fail;
            WHEN OTHERS THEN
                pl_text_log.ins_msg_async('INFO', l_func_name, 'Error selecting the route door# when building the lm door no ' || l_door_no,
                sqlcode, sqlerrm);
        END;

        pl_text_log.ins_msg_async('INFO', l_func_name, 'Ending lm_determine_blk_pull_door_no', sqlcode, sqlerrm);
        RETURN l_ret_val;
    END lm_determine_blk_pull_door_no;
	
/*****************************************************************************
**  FUNCTION:
**      lmf_update_batch_kvi
**
**  DESCRIPTION:
**      This function updates the kvi_no_case, kvi_no_splits and kvi_no_piece.
**      for a batch.  These will be cases and/or splits that were handstacked.
**      The actual values are not known until the drop or the pickup of the
**      pallet is made.
**
**  PARAMETERS:
**      i_batch_no   - The batch to update.
**      i_no_cases   - Number of cases.
**      i_no_splis t - Number of splits.
**
**  RETURN VALUES:
**      SWMS_NORMAL       - Update successful.
**      LM_BATCH_UPD_FAIL - Unable to update the batch.
*********************************************************************************/

    FUNCTION lmf_update_batch_kvi (
        i_batch_no    IN            batch.batch_no%TYPE,
        i_no_cases    IN            NUMBER,
        i_no_splits   IN            NUMBER
    ) RETURN rf.status AS

        l_func_name   VARCHAR2(50) := 'pl_lm_forklift.lmf_update_batch_kvi';
        l_ret_val     rf.status := rf.status_normal;
        l_batch_no    batch.batch_no%TYPE;
    BEGIN
        pl_text_log.ins_msg_async('INFO', l_func_name, 'Starting lmf_update_batch_kvi', sqlcode, sqlerrm);
        l_batch_no := i_batch_no;
        BEGIN
            UPDATE batch
            SET
                kvi_no_case = nvl(kvi_no_case, 0) + i_no_cases,
                kvi_no_split = nvl(kvi_no_split, 0) + i_no_splits,
                kvi_no_piece = nvl(kvi_no_piece, 0) + i_no_cases + i_no_splits
            WHERE
                batch_no = l_batch_no;

        EXCEPTION
            WHEN OTHERS THEN
                pl_text_log.ins_msg_async('WARN', l_func_name, 'LMG ORACLE Update of kvi case, split and piece counts for batch failed. For batch# '
                || l_batch_no, sqlcode, sqlerrm);
                l_ret_val := rf.status_lm_batch_upd_fail;
        END;

        pl_text_log.ins_msg_async('INFO', l_func_name, 'Ending lmf_update_batch_kvi', sqlcode, sqlerrm);
        RETURN l_ret_val;
    END lmf_update_batch_kvi;
	
/*****************************************************************************
**  FUNCTION:
**      lmf_what_putaway_is_this
**
**  DESCRIPTION:
**      This function determines if a pallet being putaway to a slot
**      on a PO is:
**         - The only putaway to the slot on the PO    (ONLY_PUTAWAY_TO_SLOT)
**         - The first putaway to the slot on the PO   (FIRST_PUTAWAY_TO_SLOT)
**         - The last putaway to the slot on the PO    (LAST_PUTAWAY_TO_SLOT)
**         - The middle putaway to the slot on the PO  (MIDDLE_PUTAWAY_TO_SLOT)
**           This means there are at least three putaways to the same slot
**           and this pallet is not the first and not the last.
**
**      Also determined is the number of pallets putaway to the same slot
**      and on the same PO as the current pallet but on a different labor
**      mgmt batch and the number of pending putaways to the slot.
**
**      Created for floor slots where the existing inventory is removed
**      from the slot for the first pallet putaway on the PO then is
**      put back after the last pallet on the PO going to the slot is putaway.
**      Inventory is not removed then put back for each pallet going to the
**      slot.
**
**  PARAMETERS:
**      i_pallet_id            - The pallet putaway.
**      o_pallet_putaway       - What putaway is this?
**                               Set to one of the following:
**                                  - ONLY_PUTAWAY_TO_SLOT
**                                  - FIRST_PUTAWAY_TO_SLOT
**                                  - LAST_PUTAWAY_TO_SLOT
**                                  - MIDDLE_PUTAWAY_TO_SLOT
**      o_num_putaways_completed - The number of pallets putaway to the
**                                 same slot and on the same PO as i_pallet_id
**                                 but on a different labor mgmt batch.
**      o_num_pending_putaways - Number of pending putaways to the slot on
**                               the PO.
**
**  RETURN VALUES:
**      SWMS_NORMAL - Successfully determined what pallet this is.
**      DATA_ERROR  - Problem with a select.  o_pallet_putaway will be set to
**                    ONLY_PUTAWAY_TO_SLOT.  o_num_putaways_completed will be
**                    set to 0.  o_num_pending_putaways will be set to 0.
**      Note that the calling function may be ignoring the return value.
************************************************************************************/

    FUNCTION lmf_what_putaway_is_this (
        i_pallet_id                IN                         putawaylst.pallet_id%TYPE,
        o_pallet_putaway           OUT                        NUMBER,
        o_num_putaways_completed   OUT                        NUMBER,
        o_num_pending_putaways     OUT                        NUMBER
    ) RETURN rf.status AS

        l_func_name                VARCHAR2(50) := 'pl_lm_forklift.lmf_what_putaway_is_this';
        l_ret_val                  rf.status := rf.status_normal;
        l_pallet_id                putawaylst.pallet_id%TYPE;
        l_palletid                 putawaylst.pallet_id%TYPE;
        l_num_putaways_completed   PLS_INTEGER := 0;
        l_num_pending_putaways     PLS_INTEGER;
        l_putaway_batch_prefix     VARCHAR2(2) := 'FP';
		  -- This cursor counts the number of pallets on the PO
		  -- that have been putaway to the same slot on other forklift
		  -- labor mgmt batches.
        CURSOR c_count_pallets_put_cur IS
        SELECT
            COUNT(1)
        FROM
            trans   t,
            trans   t2
        WHERE
            t.pallet_id != l_palletid
            AND t.rec_id = t2.rec_id
            AND t.dest_loc = t2.dest_loc
            AND t.trans_type IN (
                'PUT',
                'TRP'
            )
            AND t2.pallet_id = l_palletid
            AND t2.trans_type IN (
                'PUT',
                'TRP'
            )
            AND ( EXISTS (
                SELECT
                    'x'
                FROM
                    putawaylst p
                WHERE
                    p.pallet_id = t.pallet_id
                    AND p.putaway_put = 'Y'
            )
                  OR NOT EXISTS (
                SELECT
                    'x'
                FROM
                    putawaylst p
                WHERE
                    p.pallet_id = t.pallet_id
            ) )
            AND NOT EXISTS (
                SELECT
                    'x'
                FROM
                    batch   b,
                    batch   b2
                WHERE
                    b2.batch_no = l_putaway_batch_prefix || l_palletid
                    AND b.parent_batch_no = b2.parent_batch_no
                    AND b.ref_no = t.pallet_id
            );
                                             
    
		-- This cursor counts the pending putaways to the slot
		-- on the PO.

        CURSOR c_more_putaways_to_slot_cur IS
        SELECT
            COUNT(*)
        FROM
            putawaylst   p,
            putawaylst   p2
        WHERE
            p.putaway_put = 'N'
            AND p.rec_id = p2.rec_id
            AND p.dest_loc = p2.dest_loc
            AND p2.pallet_id = l_palletid
            AND p.pallet_id != l_palletid;

    BEGIN
        pl_text_log.ins_msg_async('INFO', l_func_name, 'Starting lmf_what_putaway_is_this', sqlcode, sqlerrm);
        l_pallet_id := i_pallet_id;
        BEGIN
            l_palletid := l_pallet_id;
            OPEN c_count_pallets_put_cur;
            FETCH c_count_pallets_put_cur INTO l_num_putaways_completed;
            CLOSE c_count_pallets_put_cur;
            OPEN c_more_putaways_to_slot_cur;
            FETCH c_more_putaways_to_slot_cur INTO l_num_pending_putaways;
            CLOSE c_more_putaways_to_slot_cur;
            o_num_putaways_completed := l_num_putaways_completed;
            o_num_pending_putaways := l_num_pending_putaways;
            IF ( l_num_putaways_completed = 0 AND l_num_pending_putaways = 0 ) THEN
                o_pallet_putaway := only_putaway_to_slot;
            ELSIF ( l_num_putaways_completed = 0 AND l_num_pending_putaways > 0 ) THEN
                o_pallet_putaway := first_putaway_to_slot;
            ELSIF ( l_num_putaways_completed > 0 AND l_num_pending_putaways = 0 ) THEN
                o_pallet_putaway := last_putaway_to_slot;
            ELSE
                o_pallet_putaway := middle_putaway_to_slot;
                o_pallet_putaway := 0;
            END IF;

        EXCEPTION
            WHEN OTHERS THEN
                pl_text_log.ins_msg_async('WARN', l_func_name, 'Unable to determine if other pallets have been putaway to the save slot.', sqlcode
                , sqlerrm);
                o_pallet_putaway := only_putaway_to_slot;
                o_num_putaways_completed := 0;
                o_num_pending_putaways := 0;
                l_ret_val := rf.status_data_error;
        END;

        pl_text_log.ins_msg_async('INFO', l_func_name, 'Ending lmf_what_putaway_is_this', sqlcode, sqlerrm);
        RETURN l_ret_val;
    END lmf_what_putaway_is_this;
	
/*****************************************************************************
**  FUNCTION:
**      lmf_bulk_pull_w_drop_to_home
**
**  DESCRIPTION:
**      This function determines if a pallet pull batch has an associated
**      drop to home batch.  This is determined by taking the float number
**      from the pallet pull batch number and seeing if there is a drop to
**      home batch.
**      Format of pallet pull batch no:  FU<float#>
**      Format of drop to home batch no: FD<float#>
**
**  PARAMETERS:
**      i_batch_no  - Pallet pull batch number.
**
**  RETURN VALUES:
**      TRUE       - The pallet pull has a a drop to home.
**      FALSE      - The pallet pull does not have a drop to home
**                   or an error occurred.
***********************************************************************************/

    FUNCTION lmf_bulk_pull_w_drop_to_home (
        i_batch_no   IN           batch.batch_no%TYPE
    ) RETURN NUMBER AS

        l_func_name             VARCHAR2(60) := 'pl_lm_forklift.lmf_bulk_pull_w_drop_to_home';
        l_ret_val               rf.status := rf.status_normal;
        l_batch_no              batch.batch_no%TYPE;
        l_drop_to_home_prefix   VARCHAR2(2) := 'FD';
        l_dummy                 VARCHAR2(1);
        CURSOR c_drop_to_home_cur IS
        SELECT
            'x'
        FROM
            batch
        WHERE
            batch_no = l_drop_to_home_prefix || substr(l_batch_no, 3);

    BEGIN
        pl_text_log.ins_msg_async('INFO', l_func_name, 'Starting lmf_bulk_pull_w_drop_to_home', sqlcode, sqlerrm);
        l_batch_no := i_batch_no;
        BEGIN
            OPEN c_drop_to_home_cur;
            FETCH c_drop_to_home_cur INTO l_dummy;
            IF ( c_drop_to_home_cur%found ) THEN
                l_ret_val := 1;
            ELSE
                l_ret_val := 0;
            END IF;

            CLOSE c_drop_to_home_cur;
        EXCEPTION
            WHEN OTHERS THEN
                l_ret_val := 0;
        END;

        pl_text_log.ins_msg_async('INFO', l_func_name, 'Ending lmf_bulk_pull_w_drop_to_home', sqlcode, sqlerrm);
        RETURN l_ret_val;
    END lmf_bulk_pull_w_drop_to_home;
	
/*****************************************************************************
**  FUNCTION:
**      lm_sel_split_rpl_crdt_syspar
**
**  DESCRIPTION:
**      This function selects syspar SPLIT_RPL_CREDIT_AT_CASE_LEVEL.
**      This syspar designates if credit is given at the case level instead
**      of the split level when replenishing split slots.
**      If the syspar is not found or an oracle error occurs then 'N' will be
**      used as the value.
**
**  PARAMETERS:
**      o_apply_credit_at_case_level - Set to TRUE if syspar is 'Y'
**                                     otherwise FALSE.
**
**  RETURN VALUES:
**      None.
*****************************************************************************/

    FUNCTION lm_sel_split_rpl_crdt_syspar (
        o_apply_credit_at_case_level OUT NUMBER
    ) RETURN rf.status AS

        l_func_name      VARCHAR2(50) := 'pl_lm_forklift.lm_sel_split_rpl_crdt_syspar';
        l_ret_val        rf.status := rf.status_normal;
        l_syspar_value   sys_config.config_flag_val%TYPE;
    BEGIN
        pl_text_log.ins_msg_async('INFO', l_func_name, 'Starting lm_sel_split_rpl_crdt_syspar', sqlcode, sqlerrm);
        l_syspar_value := pl_common.f_get_syspar('SPLIT_RPL_CREDIT_AT_CASE_LEVEL', 'N');
        IF ( l_syspar_value = 'Y' ) THEN
            o_apply_credit_at_case_level := 1;
            l_ret_val := 1;
        ELSE
            o_apply_credit_at_case_level := 0;
            l_ret_val := 0;
        END IF;

        pl_text_log.ins_msg_async('INFO', l_func_name, 'Ending lm_sel_split_rpl_crdt_syspar', sqlcode, sqlerrm);
        RETURN l_ret_val;
    END lm_sel_split_rpl_crdt_syspar;
	
/*******************************<+>******************************************
**  Function:
**     lmf_update_forklift_xfr_batch
**
**  Description:
**     This function updates the labor mgmt batch kvi_to_loc with the
**     destination location that is in the trans record.  This function
**     is called for operations where the destination location is not
**     known when the operation is started such as for transfers and
**     home slot transfers.  The destination location is not known when
**     the batch is first created so the labor mgmt batch needs to be
**     updated when the destination location is scanned.
**
**     For transfers and home slots transfers transactions are created
**     when the pallet is scanned at the source location.  The transaction
**     is needed to store information that is used to create the batch
**     and for completing the batch.
**
**  Parameters:
**     i_trans_id     - Trans id of the transaction record associated
**                      with the labor mgmt batch.  The labor mgmt batch
**                      number is <labor mgmt batch identifier>{trans id}
**                      Some possible labor mgmt batch numbers are:
**                         FX<trans id>   Transfer
**                         FH<trans id>   Home slot transfer
**
**     i_vc_to_slot_ptr         - Destination location.
**     i_labor_mgmt_batch_type  - Labor mgmt batch type.  Such as
**                                transfer or home slot transfer.
**
**  Return Values:
**     NORMAL            - Successfully updated the batch.
**     LM_BATCH_UPD_FAIL - Failed to update the batch.
****************************************************************************/

    FUNCTION lmf_update_forklift_xfr_batch (
        i_trans_id                IN                        trans.trans_id%TYPE,
        i_vc_to_slot_ptr          IN                        batch.kvi_to_loc%TYPE,
        i_labor_mgmt_batch_type   IN                        VARCHAR2
    ) RETURN rf.status AS

        l_func_name   VARCHAR2(50) := 'pl_lm_forklift.lmf_update_forklift_xfr_batch';
        l_status      rf.status := rf.status_normal;
        l_batch_no    batch.batch_no%TYPE;
    BEGIN
        pl_text_log.ins_msg_async('INFO', l_func_name, 'Starting lmf_update_forklift_xfr_batch. Trans_id '
                                            || i_trans_id
                                            || ' Slot '
                                            || i_vc_to_slot_ptr
                                            || ' Batch type '
                                            || i_labor_mgmt_batch_type, sqlcode, sqlerrm);
        
		/*
		** Build the labor mgmt batch number.  It will always be a forklift batch
		** as designated by the first character.
		** Some examples are:
		**    FX2342483
		**    FH5245211
		**    FE123456
		*/

        l_batch_no := lmf.forklift_batch_id
                      || i_labor_mgmt_batch_type
                      || i_trans_id;
        BEGIN
		    /*
			** Update the batch.
			*/
            UPDATE batch
            SET
                kvi_to_loc = i_vc_to_slot_ptr
            WHERE
                batch_no = l_batch_no;

        EXCEPTION
            WHEN OTHERS THEN
                pl_text_log.ins_msg_async('WARN', l_func_name, 'Failed to update the kvi_to_loc. For batch# ' || l_batch_no, sqlcode, sqlerrm
                );
                l_status := rf.status_lm_batch_upd_fail;
        END;

        pl_text_log.ins_msg_async('INFO', l_func_name, 'Ending lmf_update_forklift_xfr_batch', sqlcode, sqlerrm);
        RETURN l_status;
    END lmf_update_forklift_xfr_batch;
	
/*******************************<+>******************************************
**  Function:
**     lmf_reactivate_suspended_batch
**
**  Description:
**     This function checks for a suspended batch and makes it active again.
**     The suspended batch needs to match the specified batch type in order
**     for it to be reactivated.  The reactivation of a batch happens
**     at the time of a drop.  This corresponds to when a batch can be
**     suspended.
**
**     It is based on function check_suspend() in putaway.pc and is
**     meant to replace it.
**
**  Parameters:
**     i_user_id     - User performing operation.  It needs to right padded
**                     with spaces to USER_ID_RF_LEN.
**     i_equip_id    - Equipment being used.  It needs to be right padded
**                     with spaces to EQUIP_ID_LEN.
**     i_labor_mgmt_batch_type  - Batch type the suspended batch has to be
**                                to reactivate it.
**
**  Return Values:
**     NORMAL       - Successful processing.
**     Anything else donotes a failure.
******************************************************************************/

    FUNCTION lmf_reactivate_suspended_batch (
        i_user_id                 IN                        batch.user_id%TYPE,
        i_equip_id                IN                        equip.equip_id%TYPE,
        i_labor_mgmt_batch_type   IN                        VARCHAR2
    ) RETURN rf.status AS

        l_func_name               VARCHAR2(50) := 'pl_lm_forklift.lmf_reactivate_suspended_batch';
        l_ret_val                 rf.status := rf.status_normal;
        l_vc_user_id              VARCHAR(31);
        l_vc_equip_id             equip.equip_id%TYPE;
        l_vc_suspended_batch_no   batch.batch_no%TYPE;
        l_vc_parent_batch_no      batch.batch_no%TYPE := ' ';
        l_vc_prev_batch_no        batch.batch_no%TYPE := ' ';
        l_vc_supervisor_id        VARCHAR(31) := ' ';
    BEGIN
        pl_text_log.ins_msg_async('INFO', l_func_name, 'Starting lmf_reactivate_suspended_batch. User id '
                                            || i_user_id
                                            || ' i_equip_id '
                                            || i_equip_id
                                            || ' batch type '
                                            || i_labor_mgmt_batch_type, sqlcode, sqlerrm);

        l_vc_user_id := i_user_id;
        l_vc_equip_id := i_equip_id;
        l_ret_val := lmf_find_suspended_batch(l_vc_user_id, l_vc_suspended_batch_no);
        IF ( l_ret_val = rf.status_no_lm_batch_found ) THEN 
			  /*
			  ** User has no suspended batch which is OK.
			  */
            l_ret_val := rf.status_normal;
        ELSIF ( l_ret_val = rf.status_normal ) THEN
			  /*
			  ** User has a suspended batch.  Reactivate it if it matches the
			  ** specified type.
			  */
            IF ( l_vc_suspended_batch_no = i_labor_mgmt_batch_type ) THEN
                l_ret_val := pl_rf_lm_common.lmc_batch_istart(l_vc_user_id, l_vc_prev_batch_no, l_vc_supervisor_id);
                IF ( l_ret_val = rf.status_normal ) THEN
                    l_ret_val := lmf_signon_to_forklift_batch(lmf.lmf_signon_batch, l_vc_suspended_batch_no, l_vc_parent_batch_no
                    , l_vc_user_id, l_vc_supervisor_id, l_vc_equip_id);

                END IF;

            ELSE
                pl_text_log.ins_msg_async('WARN', l_func_name, 'Found suspended batch '
                                                    || l_vc_suspended_batch_no
                                                    || ' but the batch type does not match i_labor_mgmt_batch_type '
                                                    || i_labor_mgmt_batch_type
                                                    || ' so it will not be reactivated.', sqlcode, sqlerrm);
            END IF;
        END IF;

        pl_text_log.ins_msg_async('INFO', l_func_name, 'Ending lmf_reactivate_suspended_batch', sqlcode, sqlerrm);
        RETURN l_ret_val;
    END lmf_reactivate_suspended_batch;
	
  /*****************************************************************************
**  Function:
**     lmf_get_dflt_fk_ind_start_time()
**
**  Description:
**     This function determines the start time to use for the default forklift
**     indirect batch if the user has a suspended batch.  If this processing
**     is not done then the start time of the indirect batch will be the start
**     time of the suspended batch which is not the correct processing.  If the
**     user has no suspended batch then the start time will be set to a 0
**     length string which designates to the function that creates the default
**     forklift indirect batch to use the start time of the last completed
**     batch as the start time for the default forklift indirect batch.
**
**     All the parameters need to be null terminated.
**
**  Parameters:
**     i_psz_active_batch_no   - User performing operation.
**     i_psz_active_batch_no   - The active batch for the user.
**     o_start_time            - The start time for the default forklift
**                               indirect batch.  Set if the user has a
**                               suspended batch.
**
**  Return Values:
**     SWMS_NORMAL          - Okay.
**
**  Called By:
**     lm_reset_current_fklft_batch
***********************************************************************************/

    FUNCTION lmf_get_dflt_fk_ind_start_time (
        i_psz_user_id           IN                      VARCHAR2,
        i_psz_active_batch_no   IN                      VARCHAR2,
        o_psz_start_time        OUT                     VARCHAR2
    ) RETURN rf.status AS

        l_func_name           VARCHAR2(50) := 'pl_lm_forklift.lmf_get_dflt_fk_ind_start_time';
        l_ret_val             rf.status := rf.status_normal;
        l_sz_dummy_batch_no   batch.batch_no%TYPE;
    BEGIN
        pl_text_log.ins_msg_async('INFO', l_func_name, 'Starting lmf_get_dflt_fk_ind_start_time', sqlcode, sqlerrm);
		/*
		** See if the user has a suspended batch.
		*/
        l_ret_val := lmf_find_suspended_batch(i_psz_user_id, l_sz_dummy_batch_no);
        IF ( l_ret_val = rf.status_no_lm_batch_found ) THEN
		  /*
		  ** The user does not have a suspended batch.
		  */
            l_ret_val := rf.status_normal;
        ELSIF ( l_ret_val = rf.status_normal ) THEN
			  /*
			  ** The user has a suspended batch.  Get the start time of the users
			  ** active batch which will be used as the start time of the default
			  ** indirect batch that will be created.
			  */
            BEGIN
                SELECT
                    TO_CHAR(actl_start_time, 'DDMMYYYYHH24MISS')
                INTO o_psz_start_time
                FROM
                    batch
                WHERE
                    batch_no = i_psz_active_batch_no;

            EXCEPTION
				/*
				  ** Got an error trying to select the batch or did not find it.
				  */
                WHEN OTHERS THEN
                    pl_text_log.ins_msg_async('WARN', l_func_name, 'LMF ORACLE Failed getting the start time for the batch ' || i_psz_active_batch_no
                    , sqlcode, sqlerrm);
                    l_ret_val := rf.status_no_lm_batch_found;
            END;
        END IF;

        pl_text_log.ins_msg_async('INFO', l_func_name, 'Ending lmf_get_dflt_fk_ind_start_time', sqlcode, sqlerrm);
        RETURN l_ret_val;
    END lmf_get_dflt_fk_ind_start_time;
	
/*****************************************************************************
**  FUNCTION:
**      lmf_braek_away_create_haul_batch_id()
**
**  DESCRIPTION:
**      This function creates a batch id for Haul from the specified putaway
**      batch id.
**
**  PARAMETERS:
**      o_haul_batch_no char    -  New batch id.
**
**  RETURN VALUES:
**      SWMS_NORMAL  --  Okay.
**      LM_BATCH_UPD_FAIL  --  Failed to modify batch.
*****************************************************************************/

    FUNCTION lm_break_away_cte_hl_btc_id (
        o_haul_batch_no OUT VARCHAR2
    ) RETURN rf.status AS
        l_func_name   VARCHAR2(60) := 'pl_lm_forklift.lm_break_away_cte_hl_btc_id';
        l_ret_val     rf.status := rf.status_normal;
    BEGIN
        pl_text_log.ins_msg_async('INFO', l_func_name, 'Starting lm_break_away_cte_hl_btc_id', sqlcode, sqlerrm);
        SELECT
            'HL' || pallet_batch_no_seq.NEXTVAL
        INTO o_haul_batch_no
        FROM
            dual;

        pl_text_log.ins_msg_async('INFO', l_func_name, 'Ending lm_break_away_cte_hl_btc_id', sqlcode, sqlerrm);
        RETURN l_ret_val;
    EXCEPTION
        WHEN OTHERS THEN
            pl_text_log.ins_msg_async('WARN', l_func_name, 'LMF ORACLE Unable to create HAUL batch id.', sqlcode, sqlerrm);
            l_ret_val := rf.status_lm_batch_upd_fail;
    END lm_break_away_cte_hl_btc_id;

    /***************************************************************************
    ** FUNCTION:
    **   reset_swap_batch()
    **
    ** DESCRIPTION:
    **   Resets the active LM SWAP batch for the user. If the batch is the
    **   second leg of the swap, the batch completed in the first leg will
    **   be reset as well. 
    **
    ** PARAMETERS:
    **   i_user_id:  user working on the batch
    **   i_equip_id: user's equipment (forklift) 
    **
    ** RETURN:
    **   success (rf.status_normal, i.e. 0) or error code   
    **
    ** MODIFICATION LOG:
    **
    **  date         developer   comment
    **  ------------------------------------------------------------------------
    **  28-May-2021  pkab6563    Initial version
    **
    ****************************************************************************/
    FUNCTION reset_swap_batch (
        i_user_id    IN  batch.user_id%TYPE,
        i_equip_id   IN  batch.equip_id%TYPE
    ) RETURN rf.status IS

        l_status                       rf.status := rf.status_normal;
        l_func_name          CONSTANT  swms_log.procedure_name%TYPE := 'reset_swap_batch';
        l_app_func           CONSTANT  swms_log.application_func%TYPE := 'LABOR MGT';
        l_swap_batch_prefix  CONSTANT  VARCHAR2(2) := pl_lmc.ct_forklift_swap;
        l_msg                          swms_log.msg_text%TYPE;
        l_active_batch                 batch.batch_no%TYPE; 
        l_last_c_batch                 batch.batch_no%TYPE; -- user's last completed batch
        l_is_parent                    VARCHAR2(1);
        l_active_batch_prefix          VARCHAR2(2);
        l_c_batch_prefix               VARCHAR2(2);
        l_rpl_batch_no_1               replenlst.batch_no%TYPE; 
        l_rpl_batch_no_2               replenlst.batch_no%TYPE; 

    BEGIN
       
        l_msg := 'Starting reset_swap_batch(). i_user_id ['
              || i_user_id
              || '] i_equip_id ['
              || i_equip_id
              || ']';
     
        pl_log.ins_msg('INFO', l_func_name, l_msg, null, null, l_app_func, PACKAGE_NAME);

        -- Get user's active batch
        l_status := pl_rf_lm_common.lmc_find_active_batch(i_user_id, l_active_batch, l_is_parent);

        IF l_status = rf.status_normal THEN
            l_active_batch_prefix := SUBSTR(l_active_batch, 1, 2);
            IF l_active_batch_prefix != l_swap_batch_prefix THEN
                l_status := rf.status_data_error;
                l_msg := 'Batch ['
                      || l_active_batch
                      || '] is NOT a SWAP batch';
                pl_log.ins_msg('INFO', l_func_name, l_msg, null, null, l_app_func, PACKAGE_NAME);
            ELSE
                -- get user's last completed batch
                l_status := pl_rf_lm_common.lmc_get_last_complete_batch(i_user_id, l_last_c_batch);
            END IF; -- confirming that active batch is a swap batch
        END IF; -- if active batch was found

        IF l_status = rf.status_normal THEN
            -- If the last completed batch was the first leg of the user's current
            -- swap batch, it must be reset first.
        
            l_c_batch_prefix := SUBSTR(l_last_c_batch, 1, 2);
            IF l_c_batch_prefix = l_swap_batch_prefix THEN
                BEGIN
                    SELECT batch_no
                    INTO   l_rpl_batch_no_1
                    FROM   replenlst
                    WHERE  task_id = TO_NUMBER(SUBSTR(l_last_c_batch, 3));

                    SELECT batch_no
                    INTO   l_rpl_batch_no_2
                    FROM   replenlst
                    WHERE  task_id = TO_NUMBER(SUBSTR(l_active_batch, 3));
   
                EXCEPTION
                    WHEN OTHERS THEN
                        l_status := rf.status_data_error;
                        l_msg := 'ERROR while querying replenlst table for last completed batch ['
                              || l_last_c_batch
                              || '] and active batch ['
                              || l_active_batch
                              || ']'; 
                        pl_log.ins_msg('FATAL', l_func_name, l_msg, SQLCODE, SUBSTR(SQLERRM, 1, 500), l_app_func, PACKAGE_NAME);

                END; -- querying replenlst   

                IF l_rpl_batch_no_1 = l_rpl_batch_no_2 THEN
                    -- last completed batch was the first leg of current SWAP. Reset it.
                    l_status := lmf_reset_batch(l_last_c_batch);
                END IF;
            END IF;  -- if last completed batch was a swap batches
            
            -- Reset the active batch and create an indirect batch
            l_status := lm_reset_current_fklft_batch(substr(l_active_batch, 2, 1), i_user_id, null, i_equip_id);

        END IF; -- if active batch was found and all normal so far

        return l_status;

    EXCEPTION
        WHEN OTHERS THEN
            l_status := rf.status_lm_batch_upd_fail;
            l_msg := 'Unexpected ERROR in reset_swap_batch() for i_user_id ['
                  || i_user_id
                  || '] i_equip_id ['
                  || i_equip_id
                  || ']';
            pl_log.ins_msg('FATAL', l_func_name, l_msg, SQLCODE, SUBSTR(SQLERRM, 1, 500), l_app_func, PACKAGE_NAME);
            return l_status;

    END reset_swap_batch;

END pl_lm_forklift;
/

GRANT EXECUTE ON pl_lm_forklift TO swms_user;
