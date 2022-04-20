create or replace PACKAGE pl_lm_goaltime AS 

/*********************************************************************************
** Package Name:
**    pl_lm_goaltime
**
** Files
**    pl_lm_goaltime created from lm_goaltime.pc 
**
** Description:
**    This file contains functions and subroutines necessary to calculate
**      discreet Labor Tracking values.
**
** Package Called from:
** 					This package is called from different programs.  
**
**        DATE         DESIGNER       COMMENTS
**     01/07/2020      Infosys     Initial version0.0
-- Modification History:
--    Date     Designer Comments
--    -------- -------- -----------------------------------------------------
--    10/08/21 bben0556 Brian Bent
--                      R1 cross dock.
--                      Card: R47_0-xdock-OPCOF3715_Site_2_Handle_PUX_transaction
--
--                      Add handling of a Site 2 cross dock pallet putaway.
--                      The transaction type is 'PUX'.  It is still a FP forklift labor batch.
--                      Handled it the same as a TRP transaction.
--
**    06-Jan-2022      pkab6563    Jira 3899 - changes to adjust number of cases
**                                 dropped into home slot when drop is followed
**                                 by a home slot transfer (HST).
**********************************************************************************/
    g_audit_batch_no              batch.batch_no%TYPE;
	TYPE char_arr IS
        TABLE OF VARCHAR2(18);
    TYPE l_drop_arr IS
        TABLE OF batch.kvi_to_loc%TYPE;
    TYPE l_pallet_arr IS
        VARRAY(50) OF batch.ref_no%TYPE;
    TYPE l_put_pkups_arr IS
        TABLE OF putaway_pickup_obj;
    CURSOR c_batch_cur (
        l_lbatch_no batch.batch_no%TYPE
    ) IS
    SELECT
        b.batch_no,
        b.jbcd_job_code     jbcd_job_code,
        nvl(b.kvi_no_piece, 0) kvi_no_piece,
        nvl(j.tmu_no_piece, 0) tmu_no_piece,
        nvl(b.kvi_no_case, 0) kvi_no_case,
        nvl(j.tmu_no_case, 0) tmu_no_case,
        nvl(b.kvi_no_split, 0) kvi_no_split,
        nvl(j.tmu_no_split, 0) tmu_no_split,
        nvl(b.kvi_no_pallet, 0) kvi_no_pallet,
        nvl(j.tmu_no_pallet, 0) tmu_no_pallet,
        nvl(b.kvi_no_item, 0) kvi_no_item,
        nvl(j.tmu_no_item, 0) tmu_no_item,
        nvl(b.kvi_no_po, 0) kvi_no_po,
        nvl(j.tmu_no_po, 0) tmu_no_po,
        nvl(b.kvi_cube, 0) kvi_cube,
        nvl(j.tmu_cube, 0) tmu_cube,
        nvl(b.kvi_wt, 0) kvi_wt,
        nvl(j.tmu_wt, 0) tmu_wt,
        nvl(b.kvi_no_loc, 0) kvi_no_loc,
        nvl(j.tmu_no_loc, 0) tmu_no_loc,
        nvl(b.kvi_doc_time, 0) kvi_doc_time,
        nvl(j.tmu_doc_time, 0) tmu_doc_time,
        nvl(b.kvi_no_data_capture, 0) kvi_no_data_capture,
        nvl(j.tmu_no_data_capture, 0) tmu_no_data_capture,
        nvl(b.kvi_distance, 0) kvi_distance,
        nvl(j.engr_std_flag, 'N') engr_std_flag,
        loc1.pallet_type    from_loc_pallet_type,
        loc2.pallet_type    to_loc_pallet_type,
        b.msku_batch_flag   msku_batch_flag
    FROM
        loc        loc1,  -- To get the pallet type of the "from" location
        loc        loc2,  -- To get the pallet type of the "to" location
        job_code   j,
        batch      b
    WHERE
        j.jbcd_job_code = b.jbcd_job_code
        AND ( batch_no = l_lbatch_no
              OR parent_batch_no = l_lbatch_no )
        AND loc1.logi_loc (+) = b.kvi_from_loc
        AND loc2.logi_loc (+) = b.kvi_to_loc;

    /*TYPE type_lmd_distance_rec IS RECORD (
        accel_distance NUMBER,
        decel_distance NUMBER,
        travel_distance NUMBER,
        total_distance NUMBER,
        tia_time NUMBER,
        distance_rate NUMBER
    );*/
    TYPE lmg_audit_rec IS RECORD (
        batch_no VARCHAR2(13),
        operation VARCHAR2(10),
        tmu NUMBER,
        time NUMBER,
        from_loc VARCHAR2(30),
        to_loc VARCHAR2(30),
        frequency NUMBER,
        pallet_id VARCHAR2(10),
        cmt VARCHAR2(2000),
        user_id VARCHAR2(30),
        equip_id VARCHAR2(10)
    );
    TYPE type_lmg_drop_pallet_rec IS RECORD (
        drop_point VARCHAR2(15),
        pallet_id VARCHAR2(18)
    );
    FUNCTION lmg_load_goaltime (
        i_batch_no    IN batch.batch_no%TYPE,
        i_is_parent   IN VARCHAR2
    ) RETURN NUMBER;

    PROCEDURE calc_time_at_pallet_level (
        i_batch_rec     IN              c_batch_cur%rowtype,
        o_pallet_time   OUT             NUMBER
    );

    FUNCTION lmg_get_equip_values (
        io_e_rec IN OUT pl_lm_goal_pb.type_lmc_equip_rec
    ) RETURN NUMBER;

    PROCEDURE lmg_drop_to_pallet_flow_slot (
        i_pals             IN                 pl_lm_goal_pb.tbl_lmg_pallet_rec,
        i_num_pallets      IN                 NUMBER,
        i_e_rec            IN                 pl_lm_goal_pb.type_lmc_equip_rec,
        i_dest_total_qoh   IN                 NUMBER,
        o_drop             OUT                NUMBER
    );

    PROCEDURE lmg_drop_to_handstack_slot (
        i_pals             IN                 pl_lm_goal_pb.tbl_lmg_pallet_rec,
        i_num_pallets      IN                 NUMBER,
        i_e_rec            IN                 pl_lm_goal_pb.type_lmc_equip_rec,
        i_perm             IN                 VARCHAR2,
        i_dest_total_qoh   IN                 NUMBER,
        io_drop            IN OUT             NUMBER
    );

    PROCEDURE lmg_drop_break_away_haul (
        i_pals          IN              pl_lm_goal_pb.tbl_lmg_pallet_rec,
        i_num_pallets   IN              NUMBER,
        i_e_rec         IN              pl_lm_goal_pb.type_lmc_equip_rec,
        o_drop          OUT             NUMBER
    );

    PROCEDURE lmg_pickup_break_away_haul (
        i_pals          IN              pl_lm_goal_pb.tbl_lmg_pallet_rec,
        i_num_pallets   IN              NUMBER,
        i_e_rec         IN              pl_lm_goal_pb.type_lmc_equip_rec,
        o_pickup        OUT             NUMBER
    );

    PROCEDURE lmg_drop_to_empty_home_slot (
        i_pals             IN                 pl_lm_goal_pb.tbl_lmg_pallet_rec,
        i_num_pallets      IN                 NUMBER,
        i_e_rec            IN                 pl_lm_goal_pb.type_lmc_equip_rec,
        i_dest_total_qoh   IN                 NUMBER,
        o_drop             OUT                NUMBER
    );

    PROCEDURE lmg_audit_cmt (
        i_batch_no   IN           batch.batch_no%TYPE,
        i_comment    IN           VARCHAR2,
        i_distance   IN           NUMBER
    );

    PROCEDURE lmg_audit_movement (
        i_movement        IN                VARCHAR2,
        i_batch_no        IN                batch.batch_no%TYPE,
        i_e_rec           IN                pl_lm_goal_pb.type_lmc_equip_rec,
        i_fork_movement   IN                NUMBER,
        i_cmt             IN                VARCHAR2
    );

    PROCEDURE lmg_pickup_for_next_dst (
        i_pals     IN         pl_lm_goal_pb.tbl_lmg_pallet_rec,
        i_pindex   IN         NUMBER,
        i_e_rec    IN         pl_lm_goal_pb.type_lmc_equip_rec,
        io_drop    IN OUT     NUMBER
    );

    PROCEDURE lmg_drop_rotation (
        i_pal_num_recs            IN                        NUMBER,
        i_pals                    IN                        pl_lm_goal_pb.tbl_lmg_pallet_rec,
        i_num_pallets             IN                        NUMBER,
        i_num_recs                IN                        NUMBER,
        i_inv                     IN                        pl_lm_goal_pb.tbl_lmg_inv_rec,
        o_drop_type               OUT                       NUMBER,
        o_num_drops_completed     OUT                       NUMBER,
        o_num_pending_putaways    OUT                       NUMBER,
        o_pallets_to_move         OUT                       NUMBER,
        o_remove_existing_inv     OUT                       NUMBER,
        o_putback_existing_inv    OUT                       NUMBER,
        o_existing_inv            OUT                       NUMBER,
        o_total_pallets_in_slot   OUT                       NUMBER
    );

    PROCEDURE lmg_drop_to_reserve_audit_msg (
        i_pals                  IN                      pl_lm_goal_pb.tbl_lmg_pallet_rec,
        i_pindex                IN                      NUMBER,
        i_pallets_in_slot       IN                      NUMBER,
        i_num_drops_completed   IN                      NUMBER
    );

    PROCEDURE lmg_sel_forklift_audit_syspar (
        o_forklift_audit_bln OUT NUMBER
    );

    PROCEDURE lmg_drop_to_home_audit_msg (
        i_pals                      IN                          pl_lm_goal_pb.tbl_lmg_pallet_rec,
        i_pindex                    IN                          NUMBER,
        i_pallets_in_slot           IN                          NUMBER,
        i_prev_qoh                  IN                          NUMBER,
        i_slot_type_num_positions   IN                          NUMBER,
        i_adj_num_positions         IN                          NUMBER,
        i_open_positions            IN                          NUMBER,
        i_multi_face_slot_bln       IN                          NUMBER
    );

    PROCEDURE lmg_audit_manual_time (
        i_batch_no   IN           batch.batch_no%TYPE
    );

    FUNCTION lmg_calc_transfer_goaltime (
        i_batch_no    IN            batch.batch_no%TYPE,
        i_e_rec       IN            pl_lm_goal_pb.type_lmc_equip_rec,
        i_is_parent   IN            VARCHAR2
    ) RETURN NUMBER;

    FUNCTION lmg_calc_haul_goaltime (
        i_batch_no    IN            batch.batch_no%TYPE,
        i_e_rec       IN            pl_lm_goal_pb.type_lmc_equip_rec,
        i_is_parent   IN            VARCHAR2
    ) RETURN NUMBER;

    PROCEDURE assign_equip_rates (
        i_e_rec_ptr       IN                pl_lm_goal_pb.type_lmc_equip_rec,
        i_psz_slot_type   IN                VARCHAR2,
        i_c_deep_ind      IN                VARCHAR2,
        o_pd_g_tir        OUT               NUMBER,
        o_pd_g_apir       OUT               NUMBER,
        o_pd_g_mepir      OUT               NUMBER,
        o_pd_g_ppir       OUT               NUMBER,
        o_psz_rack_type   OUT               VARCHAR2
    );

    PROCEDURE lmg_drop_tohandstack_audit_msg (
        i_pals       IN           pl_lm_goal_pb.tbl_lmg_pallet_rec,
        i_pindex     IN           NUMBER,
        i_prev_qoh   IN           NUMBER
    );

    PROCEDURE lmg_drop_qty_adjusted_auditmsg (
        i_pals     IN         pl_lm_goal_pb.tbl_lmg_pallet_rec,
        i_pindex   IN         NUMBER
    );

    PROCEDURE lmg_drp_non_deep_hm_with_qoh (
        i_pals             IN                 pl_lm_goal_pb.tbl_lmg_pallet_rec,
        i_num_pallets      IN                 NUMBER,
        i_e_rec            IN                 pl_lm_goal_pb.type_lmc_equip_rec,
        i_dest_total_qoh   IN                 NUMBER,
        o_drop             OUT                NUMBER
    );

    PROCEDURE lmg_audit_movement_generic (
        i_rack_type   IN            VARCHAR2,
        i_movement    IN            VARCHAR2,
        i_batch_no    IN            batch.batch_no%TYPE,
        i_e_rec       IN            pl_lm_goal_pb.type_lmc_equip_rec,
        i_distance    IN            NUMBER,
        i_cmt         IN            VARCHAR2
    );

    PROCEDURE lmg_drop_to_empty_res_slot (
        i_pals          IN              pl_lm_goal_pb.tbl_lmg_pallet_rec,
        i_num_pallets   IN              NUMBER,
        i_e_rec         IN              pl_lm_goal_pb.type_lmc_equip_rec,
        o_drop          OUT             NUMBER
    );

    PROCEDURE lmg_drp_non_deep_res_with_qoh (
        i_pals           IN               pl_lm_goal_pb.tbl_lmg_pallet_rec,
        i_num_pallets    IN               NUMBER,
        i_e_rec          IN               pl_lm_goal_pb.type_lmc_equip_rec,
        i_inv            IN               pl_lm_goal_pb.tbl_lmg_inv_rec,
        i_is_same_item   IN               VARCHAR2,
        o_drop           OUT              NUMBER
    );

    FUNCTION lmg_get_pkup_door_to_pt_mvmnt (
        i_batch_no   IN           batch.batch_no%TYPE,
        i_e_rec      IN           pl_lm_goal_pb.type_lmc_equip_rec,
        io_pickup    IN OUT       NUMBER
    ) RETURN NUMBER;

    FUNCTION lmg_get_pkup_dr_to_slt_mvmnt (
        i_batch_no   IN           batch.batch_no%TYPE,
        i_e_rec      IN           pl_lm_goal_pb.type_lmc_equip_rec,
        io_pickup    IN OUT       NUMBER
    ) RETURN NUMBER;

    FUNCTION lmg_get_dest_inv (
        i_pals                IN                    pl_lm_goal_pb.tbl_lmg_pallet_rec,
        i_pallet_index        IN                    NUMBER,
        i_num_pals_on_stack   IN                    NUMBER,
        io_i_rec              IN OUT                pl_lm_goal_pb.tbl_lmg_inv_rec,
        io_dest_total_qoh     IN OUT                NUMBER,
        io_is_same_item       IN OUT                VARCHAR2,
        io_is_diff_item       IN OUT                VARCHAR2
    ) RETURN NUMBER;

    FUNCTION apply_freq (
        i_val                       IN                          NUMBER,
        i_give_stack_on_dock_time   IN                          NUMBER
    ) RETURN NUMBER;

    PROCEDURE lmg_sel_stack_on_dock_syspar (
        o_give_stack_on_dock_time OUT NUMBER
    );

    PROCEDURE lmg_3_part_move_audit_message (
        i_psz_loc IN VARCHAR2
    );

    FUNCTION lmg_calculate_goaltime (
        i_batch_no    IN            batch.batch_no%TYPE,
        i_equip_id    IN            batch.equip_id%TYPE,
        i_is_parent   IN            VARCHAR2
    ) RETURN NUMBER;

    PROCEDURE lmg_audit_forklift_movement (
        i_movement     IN             VARCHAR2,
        i_e_rec        IN             pl_lm_goal_pb.type_lmc_equip_rec,
        io_audit_rec   IN OUT         lmg_audit_rec
    );

    PROCEDURE lmg_insert_forklift_audit_rec (
        i_audit_rec IN lmg_audit_rec
    );

    FUNCTION lmg_calc_dmd_hs_xfer_goaltime (
        i_batch_no    IN            batch.batch_no%TYPE,
        i_e_rec       IN            pl_lm_goal_pb.type_lmc_equip_rec,
        i_is_parent   IN            VARCHAR2
    ) RETURN NUMBER;

    FUNCTION lmg_calc_hs_xfer_goaltime (
        i_batch_no    IN            batch.batch_no%TYPE,
        i_e_rec       IN            pl_lm_goal_pb.type_lmc_equip_rec,
        i_is_parent   IN            VARCHAR2
    ) RETURN NUMBER;

    FUNCTION lmg_calc_pallet_pull_goaltime (
        i_batch_no    IN            batch.batch_no%TYPE,
        i_e_rec       IN            pl_lm_goal_pb.type_lmc_equip_rec,
        i_is_parent   IN            VARCHAR2
    ) RETURN NUMBER;

    FUNCTION lmg_calc_demand_rpl_goaltime (
        i_batch_no    IN            batch.batch_no%TYPE,
        i_e_rec       IN            pl_lm_goal_pb.type_lmc_equip_rec,
        i_is_parent   IN            VARCHAR2
    ) RETURN NUMBER;

    FUNCTION lmg_calc_drop_home_goaltime (
        i_batch_no    IN            batch.batch_no%TYPE,
        i_e_rec       IN            pl_lm_goal_pb.type_lmc_equip_rec,
        i_is_parent   IN            VARCHAR2
    ) RETURN NUMBER;

    FUNCTION lmg_calc_ndm_rpl_goaltime (
        i_batch_no    IN            batch.batch_no%TYPE,
        i_e_rec       IN            pl_lm_goal_pb.type_lmc_equip_rec,
        i_is_parent   IN            VARCHAR2
    ) RETURN NUMBER;

    FUNCTION lmg_calc_putaway_goaltime (
        i_batch_no    IN            batch.batch_no%TYPE,
        i_e_rec       IN            pl_lm_goal_pb.type_lmc_equip_rec,
        i_is_parent   IN            VARCHAR2
    ) RETURN NUMBER;

    FUNCTION lmg_get_pkup_frm_slt_mvmnt (
        i_batch_no     IN             batch.batch_no%TYPE,
        i_trans_type   IN             trans.trans_type%TYPE,
        i_e_rec        IN             pl_lm_goal_pb.type_lmc_equip_rec,
        o_pickup       OUT            NUMBER
    ) RETURN NUMBER;

    PROCEDURE lmg_pickup_from_non_deep_res (
        i_pals           IN               pl_lm_goal_pb.tbl_lmg_pallet_rec,
        i_pal_num_recs   IN               NUMBER,
        i_pindex         IN               NUMBER,
        i_e_rec          IN               pl_lm_goal_pb.type_lmc_equip_rec,
        i_inv            IN               pl_lm_goal_pb.tbl_lmg_inv_rec,
        i_is_diff_item   IN               VARCHAR2,
        o_pickup         OUT              NUMBER
    );

    PROCEDURE lmg_pickup_from_home (
        i_pals     IN         pl_lm_goal_pb.tbl_lmg_pallet_rec,
        i_pindex   IN         NUMBER,
        i_e_rec    IN         pl_lm_goal_pb.type_lmc_equip_rec,
        o_pickup   OUT        NUMBER
    );

    FUNCTION lmg_get_drop_to_point_movement (
        i_batch_no   IN           batch.batch_no%TYPE,
        i_e_rec      IN           pl_lm_goal_pb.type_lmc_equip_rec,
        o_drop       IN OUT          NUMBER
    ) RETURN NUMBER;

    FUNCTION lmg_get_drop_to_slot_movement (
        i_batch_no     IN             batch.batch_no%TYPE,
        i_e_rec        IN             pl_lm_goal_pb.type_lmc_equip_rec,
        o_drop         OUT            NUMBER,
        i_trans_type   IN             trans.trans_type%TYPE
    ) RETURN NUMBER;

    PROCEDURE lmg_audit_travel_distance (
        i_batch_no   IN           batch.batch_no%TYPE,
        i_src_loc    IN           VARCHAR2,
        i_dest_loc   IN           VARCHAR2,
        i_distance   IN           lmd_distance_obj
    );

    PROCEDURE lmg_set_generic_rate_values (
        i_e_rec       IN            pl_lm_goal_pb.type_lmc_equip_rec,
        i_slot_type   IN            VARCHAR2,
        i_deep_ind    IN            VARCHAR2,
        o_rack_type   OUT           VARCHAR2,
        o_g_tir       OUT           NUMBER,
        o_g_apir      OUT           NUMBER,
        o_g_mepir     OUT           NUMBER,
        o_g_ppir      OUT           NUMBER
    );

    PROCEDURE lmg_audit_batch_summary (
        i_batch_no   IN           batch.batch_no%TYPE
    );

    PROCEDURE lmg_calc_actual_qty_dropped (
        io_pals    IN OUT     pl_lm_goal_pb.tbl_lmg_pallet_rec,
        i_pindex   IN         NUMBER
    );

    PROCEDURE lmg_msku_drop_to_home_slot (
        i_pals             IN                 pl_lm_goal_pb.tbl_lmg_pallet_rec,
        i_num_pallets      IN                 NUMBER,
        i_e_rec            IN                 pl_lm_goal_pb.type_lmc_equip_rec,
        i_dest_total_qoh   IN                 NUMBER,
        o_drop             OUT                NUMBER
    );

    FUNCTION lmg_calc_hst_handstack_qty (
        i_batch_no   IN           batch.batch_no%TYPE,
        i_hst_qty    IN           NUMBER
    ) RETURN NUMBER;

    PROCEDURE lmg_drop_to_induction_slot (
        i_pals             IN                 pl_lm_goal_pb.tbl_lmg_pallet_rec,
        i_num_pallets      IN                 NUMBER,
        i_e_rec            IN                 pl_lm_goal_pb.type_lmc_equip_rec,
        i_dest_total_qoh   IN                 NUMBER,
        o_drop             OUT                NUMBER
    );

    PROCEDURE lmg_msku_drop_to_res_slot (
        i_pals          IN              pl_lm_goal_pb.tbl_lmg_pallet_rec,
        i_num_pallets   IN              NUMBER,
        i_e_rec         IN              pl_lm_goal_pb.type_lmc_equip_rec,
        o_drop          OUT             NUMBER
    );

    PROCEDURE lmg_msku_pickup_from_reserve (
        i_pals           IN               pl_lm_goal_pb.tbl_lmg_pallet_rec,
        i_pindex         IN               NUMBER,
        i_e_rec          IN               pl_lm_goal_pb.type_lmc_equip_rec,
        i_inv            IN               pl_lm_goal_pb.tbl_lmg_inv_rec,
        i_is_diff_item   IN               VARCHAR2,
        io_pickup        IN OUT           NUMBER
    );

END pl_lm_goaltime;
/

create or replace PACKAGE BODY pl_lm_goaltime AS

/*********************************************************************************
** Package Name:
**    pl_lm_goaltime
**
** Files
**    pl_lm_goaltime created from lm_goaltime.pc 
**
** Description:
**    This file contains functions and subroutines necessary to calculate
**      discreet Labor Tracking values.
**
** Package Called from:
** 					This package is called from different programs.    
**
**        DATE         DESIGNER       COMMENTS
**     01/07/2020      Infosys     Initial version0.0
**********************************************************************************/

    ----------------GLOBAL VARIABLES ---------------------

    g_enable_pallet_flow_syspar   VARCHAR2(10);
    g_e_rec                       pl_lm_goal_pb.type_lmc_equip_rec;
	g_forklift_audit              NUMBER := 0;
    g_user_id                     VARCHAR2(30):=USER;
    g_travel_loaded               VARCHAR2(1);
	
    ----------------CONSTANTS---------------------
    FALSE0                        CONSTANT NUMBER := 0;
    TRUE1                         CONSTANT NUMBER := 1;
    IN_SLOT                       CONSTANT NUMBER := 1;
    NON_PUTAWAY                   CONSTANT NUMBER := 5;
    ONLY_PUTAWAY_TO_SLOT          CONSTANT NUMBER := 1;
    FIRST_PUTAWAY_TO_SLOT         CONSTANT NUMBER := 2;
    IN_AISLE                      CONSTANT NUMBER := 2;
    LAST_PUTAWAY_TO_SLOT          CONSTANT NUMBER := 3;
    STD_PALLET_HEIGHT             CONSTANT NUMBER := 48;
    ORACLE_NOT_FOUND              CONSTANT NUMBER := 1403;
    AUDIT_MSG_DIVIDER             CONSTANT VARCHAR2(100) := '------------------------------------------------------------';
    SWMS_NORMAL                   CONSTANT NUMBER := 0;
/*********************************************************************************
**   FUNCTION:
**    lmg_load_goaltime
**   
**   Description:
**     This function updates the batch with the goaltime.
**
**  PARAMETERS:   
**      i_batch_no  - Batch being processed.
**      i_is_parent - Flag denoting if batch is a parent batch or not. 
**					  Valid values are 'Y' or 'N'.
**
**  RETURN VALUES:
**      None.
**
**        DATE         DESIGNER       COMMENTS
**     01/07/2020      Infosys     Initial version0.0
***********************************************************************************/

    FUNCTION lmg_load_goaltime (
        i_batch_no    IN batch.batch_no%TYPE,
        i_is_parent   IN VARCHAR2
    ) RETURN NUMBER AS

        l_func_name            VARCHAR2(50) := 'pl_lm_goaltime.lmg_load_goaltime';  /* Aplog message buffer. */
        l_ret_val              NUMBER := SWMS_NORMAL;
        l_lbatch_no            batch.batch_no%TYPE;
        l_dummy                VARCHAR2(1);  -- Work area
        l_goal_time            batch.goal_time%TYPE;
        l_kvitmu_distance      batch.kvi_distance%TYPE;
        l_kvitmu_total         NUMBER := 0;
        l_save_engr_std_flag   job_code.engr_std_flag%TYPE;
        l_target_time          NUMBER;
        l_pallet_time          NUMBER;  -- Pallet time
    BEGIN
        pl_text_log.ins_msg_async('INFO', l_func_name, 'START lmg_load_goaltime i_batch_no='
                                            || i_batch_no
                                            || ', i_is_parent='
                                            || i_is_parent, sqlcode, sqlerrm);
	
	    /* Validate i_is_parent. */

        IF ( ( i_is_parent <> 'N' ) AND ( i_is_parent <> 'Y' ) ) THEN
            pl_text_log.ins_msg_async('WARN', l_func_name, 'LMG i_is_parent has invalid value.  Valid values are Y or N', sqlcode, sqlerrm);
            l_ret_val := RF.STATUS_LM_BATCH_UPD_FAIL;
        END IF; /* end of validate i_is_parent */

        IF ( l_ret_val = SWMS_NORMAL ) THEN
            l_lbatch_no := i_batch_no;
            BEGIN
           -- Re-calculate some of the KVI values before doing anything
           -- if the batch is for a MSKU.  An example of when the
           -- KVI values need to be recalculated is if a MSKU putaway
           -- batch had some of the drops to home slots completed then
           -- the operator func1 out.
                BEGIN
                    SELECT
                        'x'
                    INTO l_dummy
                    FROM
                        batch
                    WHERE
                        batch_no = l_lbatch_no
                        AND msku_batch_flag = 'Y';

                    pl_lm_msku.calculate_kvi_values(l_lbatch_no);
                EXCEPTION
                    WHEN no_data_found THEN
                       pl_text_log.ins_msg_async('WARN', l_func_name, 'No data found for batch= '||l_lbatch_no, sqlcode, sqlerrm);
                END;

                FOR batch_rec IN c_batch_cur(l_lbatch_no) LOOP

              -- The values of tmu_no_case and tmu_no_split affect if the
              -- the number of cases and number of splits are used in the
              -- calculation of the goal/target time or if the number of
              -- pieces is used.
              -- The rule is:
              --    If the job code has a non-zero value for tmu_no_case and/or
              --    tmu_no_split then the kvi_no_case and kvi_no_splits will be
              --    used in the calculation of the goal/target time.
              --       (kvi_no_case * tmu_no_case) +
              --       (kvi_no_split * tmu_no_split)
              --
              --    If tmu_no_case and tmu_no_split are both null or 0 then
              --    tmu_no_piece will be used in the the calculation of the
              --    goal/target time.
              --       (kvi_no_piece * tmu_no_piece)
              --
              -- Note:  NVL(___,0) used in the cursor select stmt.
                    IF ( batch_rec.tmu_no_case <> 0 OR batch_rec.tmu_no_split <> 0 ) THEN
                        l_kvitmu_total := l_kvitmu_total + ( batch_rec.tmu_no_case * batch_rec.kvi_no_case ) + ( batch_rec.tmu_no_split
                        * batch_rec.kvi_no_split );
                    ELSE
                        l_kvitmu_total := l_kvitmu_total + ( batch_rec.tmu_no_piece * batch_rec.kvi_no_piece );
                    END IF;

              -- Get the time that can be at the pallet type level.

                    calc_time_at_pallet_level(batch_rec, l_pallet_time);
                    l_kvitmu_total := l_kvitmu_total + l_pallet_time + ( batch_rec.kvi_no_item * batch_rec.tmu_no_item ) + ( batch_rec
                    .kvi_no_po * batch_rec.tmu_no_po ) + ( batch_rec.kvi_cube * batch_rec.tmu_cube ) + ( batch_rec.kvi_wt * batch_rec
                    .tmu_wt ) + ( batch_rec.kvi_no_loc * batch_rec.tmu_no_loc ) + ( batch_rec.kvi_doc_time * batch_rec.tmu_doc_time
                    ) + ( batch_rec.kvi_no_data_capture * batch_rec.tmu_no_data_capture );

              -- Use the engr std flag and kvi distance of the parent batch.
              -- Statement also works for a single batch.  The kvi_distance
              -- has been populated by the time this function was called.

                    IF ( batch_rec.batch_no = l_lbatch_no ) THEN
                        l_save_engr_std_flag := batch_rec.engr_std_flag;
                        l_kvitmu_distance := batch_rec.kvi_distance;
                    END IF;

                END LOOP;

           -- Convert time to minutes.  The distance is already in minutes.

                l_kvitmu_total := ( l_kvitmu_total / 1667 ) + l_kvitmu_distance;
    
           -- Set the goal time and target time as designated by the engineering standard.
                IF ( l_save_engr_std_flag = 'N' ) THEN
                    l_goal_time := 0.0;
                    l_target_time := l_kvitmu_total;
                ELSE
                    l_goal_time := l_kvitmu_total;
                    l_target_time := 0.0;
                END IF;

                UPDATE batch
                SET
                    goal_time = l_goal_time,
                    target_time = l_target_time
                WHERE
                    batch_no = l_lbatch_no;
            EXCEPTION
			WHEN OTHERS THEN
			pl_text_log.ins_msg_async('WARN', l_func_name, 'Error Re-calculating some of the KVI values', sqlcode, sqlerrm);
            END; /* end of Re-calculate some of the KVI values */

        END IF; /* end of Re-calculate KVI values */

        IF ( ( l_ret_val = SWMS_NORMAL ) AND ( sqlcode <> 0 ) ) THEN
		/* Got an error in the PL/SQL block */
            pl_text_log.ins_msg_async('WARN', l_func_name, 'LMG Failed to set the goal/target time for the batch', sqlcode, sqlerrm);
            l_ret_val := RF.STATUS_LM_BATCH_UPD_FAIL;
        END IF; /* end of error block */
	
	/* Write the manual time to the forklift audit table if forklift audit is on. */

        IF ( ( l_ret_val = SWMS_NORMAL ) AND ( g_forklift_audit = TRUE1) ) THEN
            lmg_audit_manual_time(i_batch_no);
        END IF; /* end of write manual time */

        pl_text_log.ins_msg_async('INFO', l_func_name, 'END lmg_load_goaltime i_batch_no='
                                            || i_batch_no
                                            || ', i_is_parent='
                                            || i_is_parent, sqlcode, sqlerrm);

        RETURN l_ret_val;
    END lmg_load_goaltime; /* end of lmg_load_goaltime */
	
/*********************************************************************************
** Function:
**    lmg_get_equip_values
**
** Description:
**      This functions fetches the LM discreet values from the equipment
**      table for the specified equip id found in equipment structure.
**
**  PARAMETERS:   
**      io_e_rec - Pointer to equipment structure to load.
**
**  RETURN VALUES:
**    RF.STATUS_WRONG_EQUIP or SWMS_NORMAL
**
**        DATE         DESIGNER       COMMENTS
**     01/07/2020      Infosys     Initial version0.0
***********************************************************************************/

    FUNCTION lmg_get_equip_values (
        io_e_rec IN OUT pl_lm_goal_pb.type_lmc_equip_rec
    ) RETURN NUMBER AS
        l_func_name   VARCHAR2(50) := 'pl_lm_goaltime.lmg_get_equip_values';
        l_ret_val     NUMBER := SWMS_NORMAL;
    BEGIN
        pl_text_log.ins_msg_async('INFO', l_func_name, 'START lmg_get_equip_values', sqlcode, sqlerrm);
        BEGIN
            SELECT
                nvl(trav_rate_loaded, 0),
                nvl(decel_rate_loaded, 0),
                nvl(accel_rate_loaded, 0),
                nvl(lower_loaded, 0),
                nvl(raise_loaded, 0),
                nvl(trav_rate_empty, 0),
                nvl(decel_rate_empty, 0),
                nvl(accel_rate_empty, 0),
                nvl(lower_empty, 0),
                nvl(raise_empty, 0),
                nvl(drop_skid, 0),
                nvl(approach_on_floor, 0),
                nvl(enter_on_floor, 0),
                nvl(position_on_floor, 0),
                nvl(approach_on_stack, 0),
                nvl(enter_on_stack, 0),
                nvl(position_on_stack, 0),
                nvl(approach_in_rack, 0),
                nvl(enter_in_rack, 0),
                nvl(position_in_rack, 0),
                nvl(backout_turn_90, 0),
                nvl(backout_and_pos, 0),
                nvl(turn_into_door, 0),
                nvl(turn_into_aisle, 0),
                nvl(turn_into_rack, 0),
                nvl(turn_into_drivein, 0),
                nvl(approach_in_drivein, 0),
                nvl(enter_in_drivein, 0),
                nvl(position_in_drivein, 0),
                nvl(approach_in_pushback, 0),
                nvl(enter_in_pushback, 0),
                nvl(position_in_pushback, 0),
                nvl(approach_in_dbl_dp, 0),
                nvl(enter_in_dbl_dp, 0),
                nvl(position_in_dbl_dp, 0)
            INTO
                    io_e_rec
                .trav_rate_loaded,
                io_e_rec.decel_rate_loaded,
                io_e_rec.accel_rate_loaded,
                io_e_rec.ll,
                io_e_rec.rl,
                io_e_rec.trav_rate_empty,
                io_e_rec.decel_rate_empty,
                io_e_rec.accel_rate_empty,
                io_e_rec.le,
                io_e_rec.re,
                io_e_rec.ds,
                io_e_rec.apof,
                io_e_rec.mepof,
                io_e_rec.ppof,
                io_e_rec.apos,
                io_e_rec.mepos,
                io_e_rec.ppos,
                io_e_rec.apir,
                io_e_rec.mepir,
                io_e_rec.ppir,
                io_e_rec.bt90,
                io_e_rec.bp,
                io_e_rec.tid,
                io_e_rec.tia,
                io_e_rec.tir,
                io_e_rec.tidi,
                io_e_rec.apidi,
                io_e_rec.mepidi,
                io_e_rec.ppidi,
                io_e_rec.apipb,
                io_e_rec.mepipb,
                io_e_rec.ppipb,
                io_e_rec.apidd,
                io_e_rec.mepidd,
                io_e_rec.ppidd
            FROM
                equip
            WHERE
                equip_id = io_e_rec.equip_id;

        EXCEPTION
            WHEN no_data_found THEN
                pl_text_log.ins_msg_async('WARN', l_func_name, 'LMG Failed to find equipment', sqlcode, sqlerrm);
                l_ret_val := RF.STATUS_WRONG_EQUIP;
            WHEN OTHERS THEN
                pl_text_log.ins_msg_async('WARN', l_func_name, 'LMG Failed to find equipment', sqlcode, sqlerrm);
                l_ret_val := RF.STATUS_WRONG_EQUIP;
        END;

        pl_text_log.ins_msg_async('INFO', l_func_name, 'END lmg_get_equip_values', sqlcode, sqlerrm);
        RETURN l_ret_val;
    END lmg_get_equip_values; /* end of lmg_get_equip_values */

/*********************************************************************************
** Procedure:
**    lmg_drop_to_handstack_slot
**
** Description:
**      This functions calculates the LM drop discreet value for a pallet
**      going to a handstack slot.  A handstack slot is defined to be
**      a location with a pallet type of HS or a carton flow slot.
**      The item will always be handstacked.
**
**  PARAMETERS:   
**      i_pals             - Pointer to pallet list.
**      i_num_pallets      - Number of pallets in pallet list.
**      i_e_rec            - Pointer to equipment tmu values.
**      i_perm             - 'Y' if perm slot otherwise 'N'.
**      i_dest_total_qoh   - Total qoh in destination.  It does
**                           not include the qty being dropped.
**      io_drop            - Outgoing drop value.
**
**  RETURN VALUES:
**      None.
**
**        DATE         DESIGNER       COMMENTS
**     01/07/2020      Infosys     Initial version0.0
***********************************************************************************/

    PROCEDURE lmg_drop_to_handstack_slot (
        i_pals             IN                 pl_lm_goal_pb.tbl_lmg_pallet_rec,
        i_num_pallets      IN                 NUMBER,
        i_e_rec            IN                 pl_lm_goal_pb.type_lmc_equip_rec,
        i_perm             IN                 VARCHAR2,
        i_dest_total_qoh   IN                 NUMBER,
        io_drop            IN OUT             NUMBER
    ) AS

        l_func_name                    VARCHAR2(50) := 'pl_lm_goaltime.lmg_drop_to_handstack_slot';
        l_message                      VARCHAR2(1024);
        l_apply_credit_at_case_level   NUMBER; /* Designates if to apply credit at
										the case level when uom = 1 and
										dropping to a perm slot. */
        l_pindex                       NUMBER;             /* Index of top pallet on stack */
        l_slot_height                  NUMBER;        /* Height to slot from floor */
        l_pallet_height                NUMBER;      /* Height from floor to top pallet on stack */
        l_prev_qoh                     NUMBER;           /* Quantity in the slot before the drop. */
        l_rack_type                    VARCHAR2(1);          /* Rack type used by the forklift audit to
								determine the actual forklift operation.
								Needed because of the use of the generic
								variables. */
        l_spc                          NUMBER;
        i_index                        NUMBER;
        l_slot_type                    VARCHAR2(4);         /* Type of slot pallet is going to */
        l_handstack_cases              NUMBER := 0;  /* Cases handstacked for the drop. */
        l_handstack_splits             NUMBER := 0; /* Splits handstacked for the drop. */
        l_g_tir                        NUMBER := 0.0;          /* Generic Turn o rack */
        l_g_apir                       NUMBER := 0.0;         /* Generic Approach Pallet in rack */
        l_g_mepir                      NUMBER := 0.0;        /* Generic Manuv. and Enter Pallet in rack */
        l_g_ppir                       NUMBER := 0.0;         /* Generic Position Pallet rack */
        l_rf_ret_val                   rf.status := rf.status_normal;
    BEGIN
        pl_text_log.ins_msg_async('INFO', l_func_name, 'START lmg_drop_to_handstack_slot', sqlcode, sqlerrm);
	
	/* Always removing the top pallet on the stack. */
        l_pindex := i_num_pallets;
        l_slot_height := i_pals(l_pindex).height;
        l_pallet_height := STD_PALLET_HEIGHT * l_pindex;
        l_spc := i_pals(l_pindex).spc;
        l_slot_type := i_pals(l_pindex).slot_type;
	
	/* Assign the equipment rates that depend on the type of slot. */
        assign_equip_rates(i_e_rec, l_slot_type, i_pals(l_pindex).deep_ind, l_g_tir, l_g_apir, l_g_mepir, l_g_ppir, l_rack_type);

        pl_text_log.ins_msg_async('INFO', l_func_name, l_func_name
                                            || '('
                                            || i_pals(l_pindex).pallet_id
                                            || ', '
                                            || i_num_pallets
                                            || ', '
                                            || i_e_rec.equip_id
                                            || ', '
                                            || i_perm
                                            || ', '
                                            || i_dest_total_qoh
                                            || 'o_drop), l_slot_type='
                                            || l_slot_type
                                            || ', slot_height='
                                            || l_slot_height
                                            || ', i_pals.hst_qty='
                                            || i_pals(l_pindex).hst_qty, sqlcode, sqlerrm);
	
	/*
    **  All the pallets being dropped to the same slot are processed
    **  the first time this function is called.
    */

        IF ( i_pals(l_pindex).multi_pallet_drop_to_slot = 'Y' ) THEN
            return;
        END IF; /* end of all pllates being dropped */
	
	/* Initialize. */
        l_prev_qoh := i_dest_total_qoh;
        IF ( g_forklift_audit = TRUE1) THEN
            lmg_drop_tohandstack_audit_msg(i_pals, l_pindex, l_prev_qoh); 

        /*
        ** If there is a following HST thus affecting the qty handstacked
        ** then write an additional audit message.
        */
            IF ( i_pals(l_pindex).hst_qty > 0 ) THEN
                lmg_drop_qty_adjusted_auditmsg(i_pals, l_pindex);
            END IF; /* end of following HST */

        END IF; /* end of forklift audit */
	
	/*
    ** Get syspar that determines if to give credit at the case or
    ** split level when dropping to a split home slot.
    */

        l_rf_ret_val := pl_lm_forklift.lm_sel_split_rpl_crdt_syspar(l_apply_credit_at_case_level);
        IF ( i_num_pallets = 1 ) THEN
	
        /*
        ** One pallet in the stack.
        ** Position the pallet at the slot then handstack.
        */
            io_drop := ( ( l_slot_height / 12.0 ) * i_e_rec.rl ) + ( ( l_slot_height / 12.0 ) * i_e_rec.le ); 

        /*
        ** Give drop skid time only if the pallet was not home slot
        ** transferred after the drop.  Looking at the hst_qty provides
        ** the necessary information.
        */

            IF ( i_pals(l_pindex).hst_qty = 0 ) THEN
                io_drop := io_drop + i_e_rec.ds;
            END IF;

            IF ( i_pals(l_pindex).uom = 1 ) THEN
                IF ( i_perm = 'Y' ) THEN
            
                /*
                ** Dropping to a handstack home slot with uom = 1.
                */
                    IF ( l_apply_credit_at_case_level != 0 ) THEN
                    /*
                    ** Case up splits.
                    */
                        l_handstack_cases := i_pals(l_pindex).actual_qty_dropped / l_spc;
                        l_handstack_splits := MOD(i_pals(l_pindex).actual_qty_dropped, l_spc);
                        IF ( g_forklift_audit = TRUE1) THEN
                            lmg_audit_cmt(g_audit_batch_no, q'(Syspar "Split RPL Credit at Case Level" is set to 'Y' so credit will be applied at the case level.)'
                            , -1);
                        END IF;
                    ELSE
                        l_handstack_cases := 0;
                        l_handstack_splits := i_pals(l_pindex).actual_qty_dropped;
                        IF ( g_forklift_audit = TRUE1) THEN
                            lmg_audit_cmt(g_audit_batch_no, q'(Syspar "Split RPL Credit at Case Level" is set to 'N' so credit will be applied at the split level.)'
                            , -1);
                        END IF;
                    END IF; /* end of lmg audit cmt */

                ELSE
                /*
                ** Going to a handstack reserve slot with uom = 1.  The uom
                ** probably should not be 1 but we will continue.
                ** Case up the splits.
                */
                    l_handstack_cases := i_pals(l_pindex).actual_qty_dropped / l_spc;
                    l_handstack_splits := MOD(i_pals(l_pindex).actual_qty_dropped, l_spc);
                END IF; /* end of case up the splits */
            ELSE
                l_handstack_cases := i_pals(l_pindex).actual_qty_dropped / l_spc;
            END IF; /* end of set l_handstack_cases */

            IF ( g_forklift_audit = TRUE1) THEN
                l_message := 'Position pallet '
                             || i_pals(l_pindex).pallet_id
                             || ' at slot '
                             || i_pals(l_pindex).dest_loc
                             || ' and handstack.';

                lmg_audit_cmt(g_audit_batch_no, l_message, -1);
                lmg_audit_movement('RL', g_audit_batch_no, i_e_rec, l_slot_height, '');
                l_message := 'Handstack '
                             || l_handstack_cases
                             || ' case(s) and '
                             || l_handstack_splits
                             || ' split(s).';
                lmg_audit_cmt(g_audit_batch_no, l_message, -1);
                lmg_audit_movement('LE', g_audit_batch_no, i_e_rec, l_slot_height, '');

            /*
            ** Give drop skid time only if the pallet was not home slot
            ** transferred after the drop.  Looking at the hst_qty provides
            ** the necessary information.
            */
                IF ( i_pals(l_pindex).hst_qty = 0 ) THEN
                    lmg_audit_movement('DS', g_audit_batch_no, i_e_rec, 1, '');
                ELSE
                    lmg_audit_cmt(g_audit_batch_no, q'(No drop skid time given because the pallet was home slot tranferred to reserve so it remains on the forks.)'
                    , -1);
                END IF; /* end of lmg audit */

            END IF; /* end audit */

        ELSE
		/*
		** More than one pallet in the stack.  Remove the top pallet, position
		** at the slot then handstack.
		*/
            io_drop := i_e_rec.ppof + i_e_rec.bp + i_e_rec.apos + ( ( l_pallet_height / 12.0 ) * i_e_rec.re ) + i_e_rec.mepos;

            IF ( g_forklift_audit = TRUE1) THEN
                l_message := 'Remove top pallet '
                             || i_pals(l_pindex).pallet_id
                             || ' from stack.';
                lmg_audit_cmt(g_audit_batch_no, l_message, -1);
                lmg_audit_movement('PPOF', g_audit_batch_no, i_e_rec, 1, '');
                lmg_audit_movement('BP', g_audit_batch_no, i_e_rec, 1, '');
                lmg_audit_movement('APOS', g_audit_batch_no, i_e_rec, 1, '');
                lmg_audit_movement('RE', g_audit_batch_no, i_e_rec, l_pallet_height, '');
                lmg_audit_movement('MEPOS', g_audit_batch_no, i_e_rec, 1, '');
            END IF; /* end audit */

		/* Have top pallet on forks.  Position the pallet at the slot then handstack. */

            IF ( l_slot_height > l_pallet_height ) THEN
			/* Raise pallet to slot and handstack. */
                io_drop := io_drop + ( ( ( l_slot_height - l_pallet_height ) / 12.0 ) * i_e_rec.rl ) + ( ( l_slot_height / 12.0 )
                * i_e_rec.le ) + i_e_rec.ds;
            ELSE
			/* Lower pallet to slot and handstack. */
                io_drop := io_drop + ( ( ( l_pallet_height - l_slot_height ) / 12.0 ) * i_e_rec.ll ) + ( ( l_slot_height / 12.0 )
                * i_e_rec.le );
            
			/*
			** Give drop skid time only IF the pallet was not home slot
			** transferred after the drop.  Looking at the hst_qty provides
			** the necessary information.
			*/

                IF ( i_pals(l_pindex).hst_qty = 0 ) THEN
                    io_drop := io_drop + i_e_rec.ds;
                END IF; /* end of drop if pallet was not home slot */

            END IF; /* end of position pallet */

            IF ( i_pals(l_pindex).uom = 1 ) THEN
			/* Handling splits. */
                IF ( i_perm = 'Y' ) THEN
				/* Dropping to a handstack home slot with uom := 1. */
                    IF ( l_apply_credit_at_case_level != 0 ) THEN
					/* Case up splits. */
                        l_handstack_cases := i_pals(l_pindex).actual_qty_dropped / l_spc;
                        l_handstack_splits := MOD(i_pals(l_pindex).actual_qty_dropped, l_spc);
                        IF ( g_forklift_audit = TRUE1) THEN
                            lmg_audit_cmt(g_audit_batch_no, q'(Syspar "Split RPL Credit at Case Level" is set to 'Y' so credit will be applied at the case level.)'
                            , -1);
                        END IF;
                    ELSE
                        l_handstack_cases := 0;
                        l_handstack_splits := i_pals(l_pindex).actual_qty_dropped;
                        IF ( g_forklift_audit = TRUE1) THEN
                            lmg_audit_cmt(g_audit_batch_no, q'(Syspar "Split RPL Credit at Case Level" is set to 'N' so credit will be applied at the split level.)'
                            , -1);
                        END IF;
                    END IF; /* end of case splits */

                ELSE
				/*
				** Going to a handstack reserve slot with uom := 1.  The uom
				** probably should not be 1 but we will continue.
				** Case up the splits.
				*/
                    l_handstack_cases := i_pals(l_pindex).actual_qty_dropped / l_spc;
                    l_handstack_splits := MOD(i_pals(l_pindex).actual_qty_dropped, l_spc);
                END IF; /* end of Handling splits */
            ELSE
			/* Handling cases. */
                l_handstack_cases := i_pals(l_pindex).actual_qty_dropped / l_spc;
            END IF; /* end of Handling cases.*/

            IF ( g_forklift_audit = TRUE1) THEN
                l_message := 'Position pallet '
                             || i_pals(l_pindex).pallet_id
                             || ' at slot '
                             || i_pals(l_pindex).dest_loc
                             || ' and handstack.';

                lmg_audit_cmt(g_audit_batch_no, l_message, -1);
                IF ( l_slot_height > l_pallet_height ) THEN
                    lmg_audit_movement('RL', g_audit_batch_no, i_e_rec, l_slot_height - l_pallet_height, '');
                ELSE
                    lmg_audit_movement('LL', g_audit_batch_no, i_e_rec, l_pallet_height - l_slot_height, '');
                END IF;

                l_message := 'Handstack '
                             || l_handstack_cases
                             || ' case(s) and '
                             || l_handstack_splits
                             || ' split(s).';
                lmg_audit_cmt(g_audit_batch_no, l_message, -1);
                lmg_audit_movement('LE', g_audit_batch_no, i_e_rec, l_slot_height, '');

			/*
			** Give drop skid time only IF the pallet was not home slot
			** transferred after the drop.  Looking at the hst_qty provides
			** the necessary information.
			*/
                IF ( i_pals(l_pindex).hst_qty = 0 ) THEN
                    lmg_audit_movement('DS', g_audit_batch_no, i_e_rec, 1, '');
                ELSE
                    lmg_audit_cmt(g_audit_batch_no, 'No drop skid time given because the pallet was home slot tranferred to reserve so it remains on the forks.'
                    , -1);
                END IF;

            END IF; /* end audit */

        END IF; /* end of positioning pallets in stock */

        l_rf_ret_val := pl_lm_forklift.lmf_update_batch_kvi(i_pals(l_pindex).batch_no, l_handstack_cases, l_handstack_splits);

    /* Add the quantity dropped to the quantity in the slot. */

        l_prev_qoh := l_prev_qoh + i_pals(l_pindex).actual_qty_dropped;

	/*
    **  Drop the rest of the pallets in the stack going to the same slot.
    **
    **  If there are HL haul batches then do not give time to put the pallet
    **  in the slot.  i_pals.break_away_haul_flag[] is set to Y for HL
    **  haul batches.
    */
        FOR i_index IN REVERSE 2..l_pindex LOOP
        /*
        **  The position of the next pallet has to be one standard height
        **  lower.
        */ IF ( i_pals(i_index - 1).multi_pallet_drop_to_slot = 'Y' ) THEN
            IF ( i_pals(i_index - 1).break_away_haul_flag = 'Y' ) THEN
                l_message := 'LP '
                             || i_pals(i_index - 1).pallet_id
                             || ' on batch '
                             || i_pals(i_index - 1).batch_no
                             || ' is a haul because of a break away.  Leave on the floor';

                lmg_audit_cmt(g_audit_batch_no, l_message, -1);
                CONTINUE;   /* continue the for loop with the next pallet */
            END IF; /* end of break away */

            l_pallet_height := l_pallet_height - STD_PALLET_HEIGHT;
            l_spc := i_pals(i_index - 1).spc;
            l_handstack_cases := 0;
            l_handstack_splits := 0;
            IF ( g_forklift_audit = TRUE1) THEN
                lmg_drop_tohandstack_audit_msg(i_pals, i_index - 1, l_prev_qoh);

                /*
                ** If there is a following HST thus affecting the qty
                ** handstacked then write an additional audit message.
                */
                IF ( i_pals(i_index - 1).hst_qty > 0 ) THEN
                    lmg_drop_qty_adjusted_auditmsg(i_pals, i_index - 1);
                END IF;

            END IF;

            /* Get the next pallet off the stack. */

            IF ( ( i_index - 1 ) = 0 ) THEN
                /* The pallet is the last pallet in the stack. */
                io_drop := io_drop + i_e_rec.apof + i_e_rec.mepof;
                IF ( g_forklift_audit = TRUE1) THEN
                    lmg_audit_movement('APOF', g_audit_batch_no, i_e_rec, 1, '');
                    lmg_audit_movement('MEPOF', g_audit_batch_no, i_e_rec, 1, '');
                END IF;

            ELSE
                /* Not the last pallet in the stack. */
                io_drop := io_drop + i_e_rec.apos + ( ( l_pallet_height / 12.0 ) * i_e_rec.re ) + i_e_rec.mepos;

                IF ( g_forklift_audit = TRUE1) THEN
                    lmg_audit_movement('APOS', g_audit_batch_no, i_e_rec, 1, '');
                    lmg_audit_movement('RE', g_audit_batch_no, i_e_rec, l_pallet_height, '');
                    lmg_audit_movement('MEPOS', g_audit_batch_no, i_e_rec, 1, '');
                END IF;

            END IF;

            /*
            **  Have the pallet on the forks, move up or down
            **  as appropriate and handstack.
            */

            IF ( l_slot_height > l_pallet_height ) THEN
                io_drop := io_drop + ( ( ( l_slot_height - l_pallet_height ) / 12.0 ) * i_e_rec.rl ) + ( ( l_slot_height / 12.0 )
                * i_e_rec.le ) + i_e_rec.ds;
            ELSE
                io_drop := io_drop + ( ( ( l_pallet_height - l_slot_height ) / 12.0 ) * i_e_rec.ll ) + ( ( l_slot_height / 12.0 )
                * i_e_rec.le ); 

                /*
                ** Give drop skid time only if the pallet was not home slot
                ** transferred after the drop.  Looking at the hst_qty provides
                ** the necessary information.
                */

                IF ( i_pals(i_index - 1).hst_qty = 0 ) THEN
                    io_drop := io_drop + i_e_rec.ds;
                END IF;

            END IF;

            IF ( i_pals(i_index - 1).uom = 1 ) THEN
                /*
                ** Handling splits.
                */
                IF ( i_perm = 'Y' ) THEN
                    /*
                    ** Dropping to a handstack home slot with uom = 1.
                    */
                    IF ( l_apply_credit_at_case_level != 0 ) THEN
                        /*
                        ** Case up the splits.
                        */
                        l_handstack_cases := i_pals(i_index - 1).actual_qty_dropped / l_spc;
                        l_handstack_splits := MOD(i_pals(i_index - 1).actual_qty_dropped, l_spc);
                        IF ( g_forklift_audit = TRUE1) THEN
                            lmg_audit_cmt(g_audit_batch_no, q'(Syspar "Split RPL Credit at Case Level" is set to 'Y' so credit will be applied at the case level.)'
                            , -1);
                        END IF;
                    ELSE
                        l_handstack_cases := 0;
                        l_handstack_splits := i_pals(i_index - 1).actual_qty_dropped;
                        IF ( g_forklift_audit = TRUE1) THEN
                            lmg_audit_cmt(g_audit_batch_no, q'(Syspar "Split RPL Credit at Case Level" is set to 'N' so credit will be applied at the split level.)'
                            , -1);
                        END IF;
                    END IF;

                ELSE
                    /*
                    ** Going to a handstack reserve slot with uom = 1.  The uom
                    ** probably should not be 1 but we will continue.
                    ** Case up the splits.
                    */
                    l_handstack_cases := i_pals(i_index - 1).actual_qty_dropped / l_spc;
                    l_handstack_splits := MOD(i_pals(i_index - 1).actual_qty_dropped, l_spc);
                END IF;
            ELSE
                /*
                ** Handling cases.
                */
                l_handstack_cases := i_pals(i_index - 1).actual_qty_dropped / l_spc;
            END IF;

            l_rf_ret_val := pl_lm_forklift.lmf_update_batch_kvi(i_pals(i_index - 1).batch_no, l_handstack_cases, l_handstack_splits

            );

            IF ( g_forklift_audit = TRUE1) THEN
                l_message := 'Position pallet '
                             || i_pals(i_index - 1).pallet_id
                             || ' at slot '
                             || i_pals(i_index - 1).dest_loc
                             || ' and handstack.';

                IF ( l_slot_height > l_pallet_height ) THEN
                    lmg_audit_movement('RL', g_audit_batch_no, i_e_rec, l_slot_height - l_pallet_height, '');
                ELSE
                    lmg_audit_movement('LL', g_audit_batch_no, i_e_rec, l_pallet_height - l_slot_height, '');
                END IF;

                l_message := 'Handstack '
                             || l_handstack_cases
                             || ' case(s) and '
                             || l_handstack_splits
                             || ' split(s).';
                lmg_audit_cmt(g_audit_batch_no, l_message, -1);
                lmg_audit_movement('LE', g_audit_batch_no, i_e_rec, l_slot_height, '');

                /*
                ** Give drop skid time only if the pallet was not home slot
                ** transferred after the drop.  Looking at the hst_qty provides
                ** the necessary information.
                */
                IF ( i_pals(i_index - 1).hst_qty = 0 ) THEN
                    lmg_audit_movement('DS', g_audit_batch_no, i_e_rec, 1, '');
                ELSE
                    lmg_audit_cmt(g_audit_batch_no, q'(No drop skid time given because the pallet was home slot tranferred to reserve so it remains on the forks.)'
                    , -1);
                END IF;

            END IF; /* end audit */

            /*
            **  Add the quanity drop to the quantity in the slot.
            */

            l_prev_qoh := l_prev_qoh + i_pals(i_index - 1).actual_qty_dropped;
        ELSE
            EXIT;   /* No more pallets to drop to the same slot. */
        END IF; /* end of pallets to drop */
        END LOOP; /* end of loop */
	
	/*
    ** Pickup stack if there are pallets left and go to the
    ** next destination but only if the next pallets is on a break haul.
    ** 60/16/2010  Brian Bent Added logic for break away haul.
    */

        IF ( i_index > 0 ) THEN
        /*
        ** There are pallets still in the travel stack.
        ** Pick up stack and go to next destination.
        */
            lmg_pickup_for_next_dst(i_pals, i_index - 1, i_e_rec, io_drop);
        END IF; /* end of Pick up stack and go to next destination */
        pl_text_log.ins_msg_async('INFO', l_func_name, 'prev_qoh= '||l_prev_qoh||' drop= '||io_drop , sqlcode, sqlerrm);
        pl_text_log.ins_msg_async('INFO', l_func_name, 'END lmg_drop_to_handstack_slot', sqlcode, sqlerrm);
    END lmg_drop_to_handstack_slot; /* end of lmg_drop_to_handstack_slot */

/*********************************************************************************
** Procedure:
**    lmg_drop_to_empty_home_slot
**
** Description:
**      This functions calculates the LM drop discreet value for a pallet
**      going to an empty home destination or a pallet going to a
**      pallet flow slot.
**
**      For drop to home batches the drop quantity will always be handstacked.
**      Note that for drop to home batches i_pals->qty_on_pallet[] will be the
**      quantity to drop to the home slot and not the total quantity on the
**      pallet.  When handstacking the top pallet in the stack is lowered to
**      the floor.  The pallets that have been put in the home slot are not
**      touched.  This is different than handstacking for a drop to a
**      non-deep home where the pallet in the home slot is removed.
**
**      This function has duplicate code.  Maybe some day it can be
**      rewritten.
**
**  PARAMETERS:   
**      i_pals             - Pointer to pallet list.
**      i_num_pallets      - Number of pallets in pallet list.
**      i_e_rec            - Pointer to equipment tmu values.
**      i_dest_total_qoh   - Total qoh in destination.  Can be non-zero for
**                           drops to a pallet flow slot.
**      o_drop             - Outgoing drop value.
**
**  RETURN VALUES:
**      None.
**
**        DATE         DESIGNER       COMMENTS
**     01/07/2020      Infosys     Initial version0.0
***********************************************************************************/

    PROCEDURE lmg_drop_to_empty_home_slot (
        i_pals             IN                 pl_lm_goal_pb.tbl_lmg_pallet_rec,
        i_num_pallets      IN                 NUMBER,
        i_e_rec            IN                 pl_lm_goal_pb.type_lmc_equip_rec,
        i_dest_total_qoh   IN                 NUMBER,
        o_drop             OUT                NUMBER
    ) AS

        l_func_name                    VARCHAR2(50) := 'pl_lm_goaltime.lmg_drop_to_empty_home_slot';
        l_pindex                       NUMBER;      /* Index of top pallet on stack */
        l_index                        NUMBER;
        l_message                      VARCHAR2(1024);
        l_apply_credit_at_case_level   NUMBER; /* Designates if to apply credit at the case level when uom = 1 */
        l_handstack_cases              NUMBER := 0; /* Cases handstacked for the drop */
        l_handstack_splits             NUMBER := 0; /* Splits handstacked for the drop */
        l_slot_height                  NUMBER;          /* Height to slot from floor */
        l_pallet_height                NUMBER;        /* Height from floor to top pallet on
								  stack */
        l_pallets_IN_SLOT              NUMBER := 0;  /* Number of pallets currently in the slot.
								  It does not include the pallets in
								  the travel stack that are going to
								  the slot. */
        l_pallet_qty                   NUMBER;           /* Quantity on drop pallet or if the batch is
								  a drop to home then the quantity to drop
								  to the home slot */
        l_slot_type_num_positions      NUMBER := 1;  /* Number of positions in the slot
										  as indicated by the slot type */
        l_adj_num_positions            NUMBER := 0; /* Number of positions in the slot
								   adjusted for the min qty */
        l_multi_face_slot_bln          NUMBER;  /* Multi-face slot designator */
        l_open_positions               NUMBER := 0;   /* Open positions in the slot */
        l_prev_pallet_IN_SLOT          NUMBER := TRUE1; /* Denotes if the previous pallet
										dropped was put in the slot */
        l_prev_qoh                     NUMBER;             /* The quantity on the previous pallet
								  dropped to the home slot.  Used when there
								  is more than one pallet in the stack
								  going to the same empty home slot. */
        l_rack_type                    VARCHAR2(1);            /* Rack type used by the forklift audit to
								  determine the actual forklift operation.
								  Needed because of the use of the generic
								  variables. */
        l_spc                          NUMBER;                /* SPC for the item on the pallet */
        l_slot_type                    VARCHAR2(4);       /* Type of slot pallet is going to */
        l_g_tir                        NUMBER := 0.0;        /* Generic Turn into rack */
        l_g_apir                       NUMBER := 0.0;       /* Generic Approach Pallet in rack */
        l_g_mepir                      NUMBER := 0.0;      /* Generic Manuv. and Enter Pallet in rack */
        l_g_ppir                       NUMBER := 0.0;       /* Generic Position Pallet rack */
        l_rf_ret_val                   rf.status := rf.status_normal;
    BEGIN
        pl_text_log.ins_msg_async('INFO', l_func_name, 'START lmg_drop_to_empty_home_slot('
                                            || i_pals(i_num_pallets).pallet_id
                                            || ', '
                                            || i_num_pallets
                                            || ', '
                                            || i_e_rec.equip_id
                                            || ', o_pickup)', sqlcode, sqlerrm);
		
	/* Always removing the top pallet on the stack. */

        l_pindex := i_num_pallets;
        l_slot_height := i_pals(l_pindex).height;
        l_pallet_height := STD_PALLET_HEIGHT * l_pindex;
        l_spc := i_pals(l_pindex).spc;
        l_slot_type := i_pals(l_pindex).slot_type;
        IF ( i_pals(l_pindex).deep_ind = 'Y' ) THEN
            l_slot_type := l_slot_type_num_positions;
		/* Adjust the number of positions based on the min quantity. */
            l_adj_num_positions := i_pals(l_pindex).min_qty_num_positions + l_slot_type_num_positions;
            IF ( substr(l_slot_type, 1, 1) = 'P' ) THEN
			/* Is pushback rack entry. */
                l_g_tir := i_e_rec.tir;
                l_g_apir := i_e_rec.apipb;
                l_g_mepir := i_e_rec.mepipb;
                l_g_ppir := i_e_rec.ppipb;
                l_rack_type := 'P';
            ELSIF ( ( substr(l_slot_type, 1, 1) = 'D' ) AND ( substr(l_slot_type, 2, 1) = 'I' ) ) THEN
			/* Is drive in rack entry. */
                l_g_tir := i_e_rec.tidi;
                l_g_apir := i_e_rec.apidi;
                l_g_mepir := i_e_rec.mepidi;
                l_g_ppir := i_e_rec.ppidi;
                l_rack_type := 'I';
            ELSIF ( ( substr(l_slot_type, 1, 1) = 'D' ) AND ( substr(l_slot_type, 2, 1) = 'D' ) ) THEN
			/* Is double deep rack entry. */
                l_g_tir := i_e_rec.tir;
                l_g_apir := i_e_rec.apidd;
                l_g_mepir := i_e_rec.mepidd;
                l_g_ppir := i_e_rec.ppidd;
                l_rack_type := 'D';
            ELSE
			/* Uses general rack entries. */
                l_g_tir := i_e_rec.tir;
                l_g_apir := i_e_rec.apir;
                l_g_mepir := i_e_rec.mepir;
                l_g_ppir := i_e_rec.ppir;
                l_rack_type := 'G';
            END IF; /* end of rack entry check */

        ELSE
		/* Uses general rack entries. */

		/* Adjust the number of positions based on the min quantity. */
            l_adj_num_positions := i_pals(l_pindex).min_qty_num_positions + l_slot_type_num_positions;
            l_g_tir := i_e_rec.tir;
            l_g_apir := i_e_rec.apir;
            l_g_mepir := i_e_rec.mepir;
            l_g_ppir := i_e_rec.ppir;
            l_rack_type := 'G';
        END IF; /* end of Adjust positions */

        pl_text_log.ins_msg_async('INFO', l_func_name, l_func_name
                                            || '('
                                            || i_pals(l_pindex).pallet_id
                                            || ','
                                            || i_num_pallets
                                            || ','
                                            || i_e_rec.equip_id
                                            || ','
                                            || l_slot_type
                                            || '), slot_height=,'
                                            || l_slot_height, sqlcode, sqlerrm);
	
	/*
    **  All the pallets that are going to the same slot are processed the first
    **  time this function is called.
    */

        IF ( i_pals(l_pindex).multi_pallet_drop_to_slot = 'Y' ) THEN
            return;
        END IF;
        l_open_positions := l_adj_num_positions;
        l_prev_qoh := i_dest_total_qoh;	
	
	/* Determine if this is a multi-face slot. */
        IF ( i_pals(l_pindex).min_qty_num_positions >= l_slot_type_num_positions ) THEN
            l_multi_face_slot_bln := TRUE1;
        ELSE
            l_multi_face_slot_bln := FALSE0;
        END IF;

        IF ( g_forklift_audit = TRUE1) THEN
            lmg_drop_to_home_audit_msg(i_pals, l_pindex, l_pallets_IN_SLOT, l_prev_qoh, l_slot_type_num_positions, l_adj_num_positions
            , l_open_positions, l_multi_face_slot_bln);
        END IF; /* end audit */
	
	/*
    ** Get syspar that determines if to give credit at the case or
    ** split level when dropping to a split home slot.
    */

        l_rf_ret_val := pl_lm_forklift.lm_sel_split_rpl_crdt_syspar(l_apply_credit_at_case_level);
        IF ( i_num_pallets = 1 ) THEN
		/*
		**  One pallet in stack.
		**  If splits or drop to home batch then put pallet down and handstack.
		*/
            IF ( ( i_pals(l_pindex).uom = 1 ) OR ( ( substr(i_pals(l_pindex).batch_no, 1, 1) = LMF.FORKLIFT_BATCH_ID ) AND ( substr(i_pals
            (l_pindex).batch_no, 2, 1) = LMF.FORKLIFT_DROP_TO_HOME ) ) ) THEN
			/* Handling splits or a drop to home. */
                IF ( ( l_apply_credit_at_case_level != 0 ) OR ( ( substr(i_pals(l_pindex).batch_no, 1, 1) = LMF.FORKLIFT_BATCH_ID ) AND
                ( substr(i_pals(l_pindex).batch_no, 2, 1) = LMF.FORKLIFT_DROP_TO_HOME ) ) ) THEN
				/* Case up the splits. */
                    l_handstack_cases := i_pals(l_pindex).qty_on_pallet / i_pals(l_pindex).spc;
                    l_handstack_splits := MOD(i_pals(l_pindex).qty_on_pallet, i_pals(l_pindex).spc);

                ELSE
                    l_handstack_cases := 0;
                    l_handstack_splits := i_pals(l_pindex).qty_on_pallet;
                END IF; /* end of case up splits */

                o_drop := i_e_rec.ppof + i_e_rec.ds;
                l_rf_ret_val := pl_lm_forklift.lmf_update_batch_kvi(i_pals(l_pindex).batch_no, l_handstack_cases, l_handstack_splits
                );

                IF ( g_forklift_audit = TRUE1) THEN
				/* Leave out audit message if its a drop to home. */
                    IF ( NOT ( ( substr(i_pals(l_pindex).batch_no, 1, 1) = LMF.FORKLIFT_BATCH_ID ) AND ( substr(i_pals(l_pindex).batch_no
                    , 2, 1) = LMF.FORKLIFT_DROP_TO_HOME ) ) ) THEN
                        IF ( l_apply_credit_at_case_level != 0 ) THEN
                            lmg_audit_cmt(g_audit_batch_no, q'(Syspar "Split RPL Credit at Case Level" is set to 'Y' so credit will be applied at the case level.)'
                            , -1);
                        ELSE
                            lmg_audit_cmt(g_audit_batch_no, q'(Syspar "Split RPL Credit at Case Level" is set to 'N' so credit will be applied at the split level.)'
                            , -1);
                        END IF; /* end of audot comment */
                    END IF; /* end of Drop to home */

                    l_message := 'Put pallet '
                                 || i_pals(l_pindex).pallet_id
                                 || ' down and handstack '
                                 || l_handstack_cases
                                 || ' case(s) and '
                                 || l_handstack_splits
                                 || ' split(s).';

                    lmg_audit_movement('PPOF', g_audit_batch_no, i_e_rec, 1, l_message);
                    lmg_audit_movement('DS', g_audit_batch_no, i_e_rec, 1, '');
                END IF; /* end of audit */

            ELSE
			/*
			** Handling cases and its not a drop to home batch.
			** Put pallet in slot.
			*/
                o_drop := l_g_tir + l_g_apir + ( ( l_slot_height / 12.0 ) * i_e_rec.rl ) + l_g_ppir + ( ( l_slot_height / 12.0 ) *
                i_e_rec.le ) + i_e_rec.bt90;

                l_open_positions := l_open_positions - 1;
                IF ( g_forklift_audit = TRUE1) THEN
                    l_message := 'Put pallet in slot '
                                 || i_pals(l_pindex).dest_loc
                                 || '.';
                    lmg_audit_movement_generic(l_rack_type, 'TIR', g_audit_batch_no, i_e_rec, 1, l_message);
                    lmg_audit_movement_generic(l_rack_type, 'APIR', g_audit_batch_no, i_e_rec, 1, '');
                    lmg_audit_movement('RL', g_audit_batch_no, i_e_rec, l_slot_height, '');
                    lmg_audit_movement_generic(l_rack_type, 'PPIR', g_audit_batch_no, i_e_rec, 1, '');
                    lmg_audit_movement('LE', g_audit_batch_no, i_e_rec, l_slot_height, '');
                    lmg_audit_movement('BT90', g_audit_batch_no, i_e_rec, 1, '');
                END IF;

            END IF;
        ELSE	
		/* More than one pallet in the stack.  Remove the top pallet. */
            o_drop := i_e_rec.ppof + i_e_rec.bp + i_e_rec.apos + ( ( l_pallet_height / 12.0 ) * i_e_rec.re ) + i_e_rec.mepos;

            IF ( g_forklift_audit = TRUE1) THEN
                l_message := 'Put stack down and remove top pallet '
                             || i_pals(l_pindex).pallet_id
                             || '.';
                lmg_audit_movement('PPOF', g_audit_batch_no, i_e_rec, 1, l_message);
                lmg_audit_movement('BP', g_audit_batch_no, i_e_rec, 1, '');
                lmg_audit_movement('APOS', g_audit_batch_no, i_e_rec, 1, '');
                lmg_audit_movement('RE', g_audit_batch_no, i_e_rec, l_pallet_height, '');
                lmg_audit_movement('MEPOS', g_audit_batch_no, i_e_rec, 1, '');
            END IF; /* end of audit */

		/*
		**  If splits or drop to home batch then put the pallet down and
		**  handstack otherwise place the pallet in the slot.
		*/

            IF ( ( i_pals(l_pindex).uom = 1 ) OR ( ( substr(i_pals(l_pindex).batch_no, 1, 1) = LMF.FORKLIFT_BATCH_ID ) AND ( substr(

            i_pals(l_pindex).batch_no, 2, 1) = LMF.FORKLIFT_DROP_TO_HOME ) ) ) THEN
		
			/* Handling splits or a drop to home. */
                IF ( ( l_apply_credit_at_case_level != 0 ) OR ( ( substr(i_pals(l_pindex).batch_no, 1, 1) = LMF.FORKLIFT_BATCH_ID ) AND
                ( substr(i_pals(l_pindex).batch_no, 2, 1) = LMF.FORKLIFT_DROP_TO_HOME ) ) ) THEN
				/* Caseup the splits. */
                    l_handstack_cases := i_pals(l_pindex).qty_on_pallet / i_pals(l_pindex).spc;
                    l_handstack_splits := MOD(i_pals(l_pindex).qty_on_pallet, i_pals(l_pindex).spc);

                ELSE
                    l_handstack_cases := 0;
                    l_handstack_splits := i_pals(l_pindex).qty_on_pallet;
                END IF; /* end of drop to home batch check */

                o_drop := o_drop + i_e_rec.ppof + i_e_rec.ds + i_e_rec.bp;
                l_rf_ret_val := pl_lm_forklift.lmf_update_batch_kvi(i_pals(l_pindex).batch_no, l_handstack_cases, l_handstack_splits
                );

                IF ( g_forklift_audit = TRUE1) THEN
				/* Leave out audit message if its a drop to home. */
                    IF ( ( substr(i_pals(l_pindex).batch_no, 1, 1) = LMF.FORKLIFT_BATCH_ID ) AND ( substr(i_pals(l_pindex).batch_no, 2
                    , 1) = LMF.FORKLIFT_DROP_TO_HOME ) ) THEN
                        IF ( l_apply_credit_at_case_level != 0 ) THEN
                            lmg_audit_cmt(g_audit_batch_no, q'(Syspar "Split RPL Credit at Case Level" is set to 'Y' so credit will be applied at the case level.)'
                            , -1);
                        ELSE
                            lmg_audit_cmt(g_audit_batch_no, q'(Syspar "Split RPL Credit at Case Level" is set to 'N' so credit will be applied at the split level.)'
                            , -1);
                        END IF; /* end of audit comment */
                    END IF; /* end of drop to home batch check */

                    l_message := 'Put pallet '
                                 || i_pals(l_pindex).pallet_id
                                 || ' down and handstack '
                                 || l_handstack_cases
                                 || ' case(s) and '
                                 || l_handstack_splits
                                 || ' split(s).';

                    lmg_audit_movement('PPOF', g_audit_batch_no, i_e_rec, 1, l_message);
                    lmg_audit_movement('DS', g_audit_batch_no, i_e_rec, 1, '');
                    lmg_audit_movement('BP', g_audit_batch_no, i_e_rec, 1, '');
                END IF; /* end audit */

            ELSE
			/*
			**  Handling cases and its not a drop to home.
			**  After taking the pallet from the stack put the pallet in the
			**  slot moving the forks up or down as appropriate.
			*/
                IF ( l_slot_height > l_pallet_height ) THEN
                    o_drop := o_drop + i_e_rec.bt90 + l_g_apir + ( ( ( l_slot_height - l_pallet_height ) / 12.0 ) * i_e_rec.rl ) +
                    l_g_ppir + i_e_rec.bt90;
                ELSE
                    o_drop := o_drop + i_e_rec.bt90 + l_g_apir + ( ( ( l_pallet_height - l_slot_height ) / 12.0 ) * i_e_rec.ll ) +
                    l_g_ppir + i_e_rec.bt90;
                END IF;

                IF ( g_forklift_audit = TRUE1) THEN
                    l_message := 'Put pallet '
                                 || i_pals(l_pindex).pallet_id
                                 || ' in slot '
                                 || i_pals(l_pindex).dest_loc
                                 || '.';

                    lmg_audit_movement('BT90', g_audit_batch_no, i_e_rec, 1, l_message);
                    lmg_audit_movement_generic(l_rack_type, 'APIR', g_audit_batch_no, i_e_rec, 1, '');
                    IF ( l_slot_height > l_pallet_height ) THEN
                        lmg_audit_movement('RL', g_audit_batch_no, i_e_rec, l_slot_height - l_pallet_height, '');
                    ELSE
                        lmg_audit_movement('LL', g_audit_batch_no, i_e_rec, l_pallet_height - l_slot_height, '');
                    END IF;

                    lmg_audit_movement_generic(l_rack_type, 'PPIR', g_audit_batch_no, i_e_rec, 1, '');
                    lmg_audit_movement('BT90', g_audit_batch_no, i_e_rec, 1, '');
                END IF; /* end audit */

                l_open_positions := l_open_positions - 1;
            END IF;

		/*
		**  Process drops to same slot now (there are additional pallets in
		**  the stack going to the same slot).
		*/

            FOR l_index IN REVERSE 2..l_pindex LOOP
                l_handstack_cases := 0;
                l_handstack_splits := 0;

			/* The position of the next pallet has to be one standard height lower. */
                IF ( i_pals(l_index - 1).multi_pallet_drop_to_slot = 'Y' ) THEN
                    l_pallet_height := l_pallet_height - STD_PALLET_HEIGHT;
                    l_prev_qoh := l_prev_qoh + i_pals(l_index).qty_on_pallet;
                    l_pallet_qty := i_pals(l_index - 1).qty_on_pallet;
                    IF ( g_forklift_audit = TRUE1) THEN
                        lmg_drop_to_home_audit_msg(i_pals, l_index - 1, l_pallets_IN_SLOT, l_prev_qoh, l_slot_type_num_positions,
                        l_adj_num_positions, l_open_positions, l_multi_face_slot_bln);
                    END IF; /* end audit */

                    IF ( ( ( l_open_positions < 1 ) AND ( substr(i_pals(l_index - 1).flow_slot_type, 1, 1) = 'N' ) ) OR ( ( substr

                    (i_pals(l_index - 1).batch_no, 1, 1) = LMF.FORKLIFT_BATCH_ID ) AND ( substr(i_pals(l_index - 1).batch_no, 2, 1) =

                    LMF.FORKLIFT_DROP_TO_HOME ) ) ) THEN
					/*
					** No open positions in the home slot and its not a
					** flow slot or its a drop to home.
					** Take pallet from top of stack, lower to floor then
					** handstack the appropriate qty.
					*/
                        IF ( ( g_forklift_audit = TRUE1) AND ( NOT ( ( substr(i_pals(l_index - 1).batch_no, 1, 1) = LMF.FORKLIFT_BATCH_ID ) AND (
                        substr(i_pals(l_index - 1).batch_no, 2, 1) = LMF.FORKLIFT_DROP_TO_HOME ) ) ) ) THEN
                            l_message := 'There are no open positions in home slot '
                                         || i_pals(l_index - 1).dest_loc
                                         || '.  Handstack.';
                            lmg_audit_cmt(g_audit_batch_no, l_message, -1);
                        END IF;

					/*
					** Raise or lower the forks to the level of the next pallet
					** on the stack if its not the last pallet on the stack.
					** The forks are at the level of the last pallet put in the
					** slot or at the floor if the previous pallet was a handstack.
					*/

                        IF ( ( l_index - 1 ) != 0 ) THEN
                            IF ( l_prev_pallet_IN_SLOT != TRUE1 ) THEN
							/* The previous pallet was a handstack. */
                                o_drop := o_drop + i_e_rec.bp + ( ( l_pallet_height / 12.0 ) * i_e_rec.re );
                            ELSIF ( l_pallet_height > l_slot_height ) THEN
                                o_drop := o_drop + ( ( ( l_pallet_height - l_slot_height ) / 12.0 ) * i_e_rec.re );
                            ELSE
                                o_drop := o_drop + ( ( ( l_slot_height - l_pallet_height ) / 12.0 ) * i_e_rec.le );
                            END IF;

                            o_drop := o_drop + i_e_rec.apos + i_e_rec.mepos + ( ( l_pallet_height / 12.0 ) * i_e_rec.ll );

                            IF ( g_forklift_audit = TRUE1) THEN
                                l_message := 'Remove pallet '
                                             || i_pals(l_index - 1).pallet_id
                                             || ' from top of stack and lower to the floor.';
                                IF ( l_prev_pallet_IN_SLOT != TRUE1 ) THEN
                                    lmg_audit_movement('BP', g_audit_batch_no, i_e_rec, 1, l_message);
                                    lmg_audit_movement('RE', g_audit_batch_no, i_e_rec, l_pallet_height, '');
                                ELSIF ( l_pallet_height > l_slot_height ) THEN
                                    lmg_audit_movement('RE', g_audit_batch_no, i_e_rec, l_pallet_height - l_slot_height, l_message
                                    );
                                ELSE
                                    lmg_audit_movement('LE', g_audit_batch_no, i_e_rec, l_slot_height - l_pallet_height, l_message
                                    );
                                END IF;

                                lmg_audit_movement('APOS', g_audit_batch_no, i_e_rec, 1, '');
                                lmg_audit_movement('MEPOS', g_audit_batch_no, i_e_rec, 1, '');
                                lmg_audit_movement('LL', g_audit_batch_no, i_e_rec, l_pallet_height, '');
                            END IF; /* end audit */

                        ELSE
                            NULL;   /* Last pallet in the stack. */
                        END IF;

					/*
					** Determine the quantity to handstack.
					*/

                        IF ( ( l_prev_qoh <= l_pallet_qty ) AND ( NOT ( ( substr(i_pals(l_index - 1).batch_no, 1, 1) = LMF.FORKLIFT_BATCH_ID

                        ) AND ( substr(i_pals(l_index - 1).batch_no, 2, 1) = LMF.FORKLIFT_DROP_TO_HOME ) ) ) ) THEN
						/*
						** The quantity on the previous pallet dropped to the
						** home slot is less than or equal to the quantity on
						** the pallet being dropped and its not a drop to home
						** batch.
						*/
                            IF ( i_pals(l_index - 1).uom = 1 ) THEN
							/* Handling splits. */
                                IF ( l_apply_credit_at_case_level = TRUE1 ) THEN
                                    l_handstack_cases := l_prev_qoh / l_spc;
                                    l_handstack_splits := MOD(l_prev_qoh, l_spc);
                                ELSE
                                    l_handstack_cases := 0;
                                    l_handstack_splits := l_prev_qoh;
                                END IF; /* end Handling splits. */

                            ELSE
							/* Handling cases. */
                                l_handstack_cases := l_prev_qoh / l_spc;
                            END IF; /* end Handling splits and cases. */
                        ELSE
						/*
						** The quantity on the previous pallet dropped to the
						** home slot is greater than the quantity on the pallet
						** being dropped or its a drop to home batch.
						*/
                            IF ( ( i_pals(l_index - 1).uom = 1 ) OR ( ( substr(i_pals(l_index - 1).batch_no, 1, 1) = LMF.FORKLIFT_BATCH_ID
                            ) AND ( substr(i_pals(l_index - 1).batch_no, 2, 1) = LMF.FORKLIFT_DROP_TO_HOME ) ) ) THEN
							/* Handling splits or a drop to home. */
                                IF ( ( l_apply_credit_at_case_level != 0 ) OR ( ( substr(i_pals(l_index - 1).batch_no, 1, 1) = LMF.FORKLIFT_BATCH_ID
                                ) AND ( substr(i_pals(l_index - 1).batch_no, 2, 1) = LMF.FORKLIFT_DROP_TO_HOME ) ) ) THEN
                                    l_handstack_cases := l_pallet_qty / l_spc;
                                    l_handstack_splits := MOD(l_pallet_qty, l_spc);
                                ELSE
                                    l_handstack_cases := 0;
                                    l_handstack_splits := l_pallet_qty;
                                END IF; /* end handling splits */

                            ELSE
							/* Handling cases. */
                                l_handstack_cases := l_pallet_qty / l_spc;
                            END IF; /* end handling splits and cases. */
                        END IF; /* End Determine the quantity to handstack */

                        o_drop := o_drop + i_e_rec.ds;
                        l_rf_ret_val := pl_lm_forklift.lmf_update_batch_kvi(i_pals(l_index - 1).batch_no, l_handstack_cases, l_handstack_splits
                        );

                        IF ( g_forklift_audit = TRUE1) THEN
						/*
						** Leave out audit message if its a drop to home.
						*/
                            IF ( ( i_pals(l_index - 1).uom = 1 ) AND ( NOT ( ( substr(i_pals(l_index - 1).batch_no, 1, 1) = LMF.FORKLIFT_BATCH_ID
                            ) AND ( substr(i_pals(l_index - 1).batch_no, 2, 1) = LMF.FORKLIFT_DROP_TO_HOME ) ) ) ) THEN
                                IF ( l_apply_credit_at_case_level = TRUE1 ) THEN
                                    lmg_audit_cmt(g_audit_batch_no, q'(Syspar "Split RPL Credit at Case Level" is set to 'Y' so credit will be applied at the case level.)'
                                    , -1);
                                ELSE
                                    lmg_audit_cmt(g_audit_batch_no, q'(Syspar "Split RPL Credit at Case Level" is set to 'N' so credit will be applied at the split level.)'
                                    , -1);
                                END IF; /* end audit comment */
                            END IF; /* end drop to home check */

                            IF ( ( substr(i_pals(l_index - 1).batch_no, 1, 1) = LMF.FORKLIFT_BATCH_ID ) AND ( substr(i_pals(l_index - 1).batch_no, 2, 1) = LMF.FORKLIFT_DROP_TO_HOME ) ) THEN
                                l_message := 'Handstack '
                                             || l_handstack_cases
                                             || ' case(s) and '
                                             || l_handstack_splits
                                             || ' split(s).';
                         
                            END IF; /* end messsage */

                            lmg_audit_movement('DS', g_audit_batch_no, i_e_rec, 1, l_message);
                        END IF; /* end audit */

                        l_prev_pallet_IN_SLOT := FALSE0;
                    ELSE
					/*
					**  There are open positions in the home slot.  Place the
					**  pallet in the slot.
					**
					**  Raise or lower the forks to the level of the next pallet
					**  on the stack.  The forks are at the level of the last
					**  pallet put in the slot.
					*/
                        IF ( l_pallet_height > l_slot_height ) THEN
                            o_drop := o_drop + ( ( ( l_pallet_height - l_slot_height ) / 12.0 ) * i_e_rec.re );

                            IF ( g_forklift_audit = TRUE1) THEN
                                lmg_audit_movement('RE', g_audit_batch_no, i_e_rec, l_pallet_height - l_slot_height, '');
                            END IF; /* end audit */

                        ELSE
                            o_drop := o_drop + ( ( ( l_slot_height - l_pallet_height ) / 12.0 ) * i_e_rec.le );

                            IF ( g_forklift_audit = TRUE1) THEN
                                lmg_audit_movement('LE', g_audit_batch_no, i_e_rec, l_slot_height - l_pallet_height, '');
                            END IF; /* end audit */

                        END IF; /* end place the pallet in slot */

					/* Get the pallet off the stack. */

                        IF ( ( l_index - 1 ) = 0 ) THEN
						/* This is the last pallet in the stack. */
                            o_drop := o_drop + i_e_rec.apof + i_e_rec.mepof + i_e_rec.bt90;
                            IF ( g_forklift_audit = TRUE1) THEN
                                lmg_audit_movement('APOF', g_audit_batch_no, i_e_rec, 1, '');
                                lmg_audit_movement('MEPOF', g_audit_batch_no, i_e_rec, 1, '');
                                lmg_audit_movement('BT90', g_audit_batch_no, i_e_rec, 1, '');
                            END IF; /* end audit */

                        ELSE
                            o_drop := o_drop + i_e_rec.apos + i_e_rec.mepos + i_e_rec.bt90;
                            IF ( g_forklift_audit = TRUE1) THEN
                                lmg_audit_movement('APOS', g_audit_batch_no, i_e_rec, 1, '');
                                lmg_audit_movement('MEPOS', g_audit_batch_no, i_e_rec, 1, '');
                                lmg_audit_movement('BT90', g_audit_batch_no, i_e_rec, 1, '');
                            END IF; /* end audit */

                        END IF; /* end get the pallet off the stack */

					/*
					** Have the pallet on the forks,  move up or down as
					** appropriate and put the pallet in the slot.
					*/

                        IF ( l_slot_height > l_pallet_height ) THEN
                            o_drop := o_drop + l_g_apir + ( ( ( l_slot_height - l_pallet_height ) / 12.0 ) * i_e_rec.rl ) + l_g_ppir
                            + i_e_rec.bt90;
                        ELSE
                            o_drop := o_drop + l_g_apir + ( ( ( l_pallet_height - l_slot_height ) / 12.0 ) * i_e_rec.ll ) + l_g_ppir
                            + i_e_rec.bt90;
                        END IF; /* end put pallet in the slot */

                        IF ( g_forklift_audit = TRUE1) THEN
                            l_message := 'Put pallet '
                                         || i_pals(l_index - 1).pallet_id
                                         || ' in slot '
                                         || i_pals(l_index - 1).dest_loc
                                         || '.';

                            lmg_audit_movement_generic(l_rack_type, 'APIR', g_audit_batch_no, i_e_rec, 1, l_message);
                            IF ( l_slot_height > l_pallet_height ) THEN
                                lmg_audit_movement('RL', g_audit_batch_no, i_e_rec, l_slot_height - l_pallet_height, '');
                            ELSE
                                lmg_audit_movement('LL', g_audit_batch_no, i_e_rec, l_pallet_height - l_slot_height, '');
                            END IF;

                            lmg_audit_movement_generic(l_rack_type, 'PPIR', g_audit_batch_no, i_e_rec, 1, '');
                            lmg_audit_movement('BT90', g_audit_batch_no, i_e_rec, 1, '');
                        END IF; /* end audit */

                        IF ( l_open_positions > 0 ) THEN
                            l_open_positions := l_open_positions - 1;
                        END IF; /* end open position check */
                    END IF; /* end pallet position */

                ELSE
                    EXIT;  /* No more drops to the same slot. */
                END IF;

            END LOOP; /* end for loop */

		/* Lower forks to floor. */

            o_drop := o_drop + ( ( l_slot_height / 12.0 ) * i_e_rec.le );

            IF ( g_forklift_audit = TRUE1) THEN
                lmg_audit_movement('LE', g_audit_batch_no, i_e_rec, l_slot_height, 'Lower forks to the floor.');
            END IF; /* end audit movement */

		 /*
		 ** Pickup stack if there are pallets left and go to the
		 ** next destination.
		 */

            IF ( l_index > 0 ) THEN
			/*
			** There are pallets still in the travel stack.
			** Pick up stack and go to next destination.
			*/
                lmg_pickup_for_next_dst(i_pals, l_index - 1, i_e_rec, o_drop);
            END IF;

        END IF; /* end of number of pallets check */

        pl_text_log.ins_msg_async('INFO', l_func_name, 'END lmg_drop_to_empty_home_slot', sqlcode, sqlerrm);
    END lmg_drop_to_empty_home_slot; /* end of lmg_drop_to_empty_home_slot */
    
/*********************************************************************************
** Procedure:
**    lmg_drop_to_pallet_flow_slot
**
** Description:
**      This functions calculates the LM drop discreet value for a pallet
**      going to a pallet flow slot.
**
**      Since no rotation takes place for pallet flow slots function
**      lmg_drop_to_pallet_flow_slot() is called to perform the drop.
**      This saves us from having to write another function.
**
**  PARAMETERS:   
**      i_pals             - Pointer to pallet list.
**      i_num_pallets      - Number of pallets in pallet list.
**      i_e_rec            - Pointer to equipment tmu values.
**      i_dest_total_qoh   - Total qoh in destination.  Can be non-zero for
**                           drops to a pallet flow slot.
**      o_drop             - Outgoing drop value.
**
**  RETURN VALUES:
**      None.
**
**        DATE         DESIGNER       COMMENTS
**     01/07/2020      Infosys     Initial version0.0
***********************************************************************************/

    PROCEDURE lmg_drop_to_pallet_flow_slot (
        i_pals             IN                 pl_lm_goal_pb.tbl_lmg_pallet_rec,
        i_num_pallets      IN                 NUMBER,
        i_e_rec            IN                 pl_lm_goal_pb.type_lmc_equip_rec,
        i_dest_total_qoh   IN                 NUMBER,
        o_drop             OUT                NUMBER
    ) AS
        l_func_name VARCHAR2(50) := 'pl_lm_goaltime.lmg_pickup_for_next_dst';
    BEGIN
        pl_text_log.ins_msg_async('INFO', l_func_name, 'START lmg_drop_to_pallet_flow_slot('
                                            || i_pals(i_num_pallets).pallet_id
                                            || ', '
                                            || i_num_pallets
                                            || ', '
                                            || i_e_rec.equip_id
                                            || ', '
                                            || i_dest_total_qoh
                                            || ')', sqlcode, sqlerrm);
	
	/* 
    ** Since no rotation takes place for drops to pallet flow slots
    ** function lmg_drop_to_empty_home_slot() can be called to perform
    ** the drop.
    */

        IF ( i_dest_total_qoh = 0 ) THEN
            lmg_drop_to_empty_home_slot(i_pals, i_num_pallets, i_e_rec, i_dest_total_qoh, o_drop);
        ELSE
            lmg_drp_non_deep_hm_with_qoh(i_pals, i_num_pallets, i_e_rec, i_dest_total_qoh, o_drop);
        END IF;

        pl_text_log.ins_msg_async('INFO', l_func_name, 'END lmg_drop_to_pallet_flow_slot', sqlcode, sqlerrm);
    END lmg_drop_to_pallet_flow_slot; /* end of lmg_drop_to_pallet_flow_slot */
    
/*********************************************************************************
** Procedure:
**    lmg_drop_break_away_haul
**
** Description:
**      This functions calculates the LM drop discreet value for a break away
**      haul pallet.
**
**  PARAMETERS:   
**      i_pals             - Pointer to pallet list.
**      i_num_pallets      - Number of pallets in pallet list.
**      i_e_rec            - Pointer to equipment tmu values.
**      o_drop             - Outgoing drop value.
**                           It will be 0 since the pallets have already been
**                           set on the floor.
**
**  RETURN VALUES:
**      None.
**
**        DATE         DESIGNER       COMMENTS
**     01/07/2020      Infosys     Initial version0.0
***********************************************************************************/

    PROCEDURE lmg_drop_break_away_haul (
        i_pals          IN              pl_lm_goal_pb.tbl_lmg_pallet_rec,
        i_num_pallets   IN              NUMBER,
        i_e_rec         IN              pl_lm_goal_pb.type_lmc_equip_rec,
        o_drop          OUT             NUMBER
    ) AS

        l_func_name   VARCHAR2(50) := 'pl_lm_goaltime.lmg_drop_break_away_haul';
        l_pindex      NUMBER;      /* Index of top pallet on the travel stack */
        l_index       NUMBER;
        l_message     VARCHAR2(1024);
    BEGIN
        pl_text_log.ins_msg_async('INFO', l_func_name, 'START lmg_drop_break_away_haul('
                                            || i_pals(i_num_pallets).pallet_id
                                            || ', '
                                            || i_num_pallets
                                            || ', '
                                            || i_e_rec.equip_id
                                            || ')', sqlcode, sqlerrm);

        l_pindex := i_num_pallets;
        o_drop := 0;
	
	/*
    ** Proceess the break away hauls which will be to do nothing.
    ** If forklift audit is active then an audit message is created
    ** for each haul.  All the remaining pallets in the pallet list should
    ** be break away hauls because the select statement ordered them to
    ** process last.
    */
        FOR l_index IN REVERSE 1..l_pindex LOOP
		IF ( g_forklift_audit = TRUE1) THEN
            l_message := 'LP '
                         || i_pals(l_index).pallet_id
                         || ' on batch '
                         || i_pals(l_index).batch_no
                         || ' is a break away haul.  Leave it on the floor';

            lmg_audit_cmt(g_audit_batch_no, l_message, -1);
        END IF;
        END LOOP;

        pl_text_log.ins_msg_async('INFO', l_func_name, 'END lmg_drop_break_away_haul', sqlcode, sqlerrm);
    END lmg_drop_break_away_haul; /* end of lmg_drop_break_away_haul */
    
 /*********************************************************************************
** Procedure:
**    lmg_pickup_break_away_haul
**
** Description:
**      This functions calculates the LM pickup discreet value for a break away
**      haul.  Time is given to pickup the pallet stack from the floor.
**
**  PARAMETERS:   
**      i_pals             - Pointer to pallet list.
**      i_num_pallets      - Number of pallets in pallet list.
**      i_e_rec            - Pointer to equipment tmu values.
**      o_pickup           - Outgoing pickup value.
**
**  RETURN VALUES:
**      None.
**
**        DATE         DESIGNER       COMMENTS
**     01/07/2020      Infosys     Initial version0.0
***********************************************************************************/

    PROCEDURE lmg_pickup_break_away_haul (
        i_pals          IN              pl_lm_goal_pb.tbl_lmg_pallet_rec,
        i_num_pallets   IN              NUMBER,
        i_e_rec         IN              pl_lm_goal_pb.type_lmc_equip_rec,
        o_pickup        OUT             NUMBER
    ) AS

        l_func_name   VARCHAR2(50) := 'pl_lm_goaltime.lmg_pickup_break_away_haul';
        l_pindex      NUMBER;      /* Index of top pallet on the stack */
        l_index       NUMBER;
        l_message     VARCHAR2(1024);
    BEGIN
        pl_text_log.ins_msg_async('INFO', l_func_name, 'START lmg_pickup_break_away_haul('
                                            || i_pals(i_num_pallets).pallet_id
                                            || ', '
                                            || i_num_pallets
                                            || ', '
                                            || i_e_rec.equip_id
                                            || ', o_pickup)', sqlcode, sqlerrm);

        o_pickup := 0;
	
	/*
    ** Pickup the break away haul stack.
    **
    ** If forklift audit is active then an audit message is created
    ** for each pallet.
    */
        o_pickup := i_e_rec.apof + i_e_rec.mepof;
        IF ( g_forklift_audit = TRUE1) THEN
            IF ( i_num_pallets = 1 ) THEN
                l_message := 'Pickup break away haul stack.  There is '
                             || i_num_pallets
                             || ' pallet in the stack.';
            ELSE
                l_message := 'Pickup break away haul stack.  There are '
                             || i_num_pallets
                             || ' pallets in the stack.';
            END IF;

            lmg_audit_movement('APOF', g_audit_batch_no, i_e_rec, 1, l_message);
            lmg_audit_movement('MEPOF', g_audit_batch_no, i_e_rec, 1, '');
            FOR l_index IN 1..i_num_pallets LOOP
                l_message := 'LP '
                             || i_pals(l_index).pallet_id
                             || ' on batch '
                             || i_pals(l_index).batch_no
                             || ' is a break away haul.  It is picked up in the stack.';

                lmg_audit_cmt(g_audit_batch_no, l_message, -1);
            END LOOP;

        END IF;

        pl_text_log.ins_msg_async('INFO', l_func_name, 'END lmg_pickup_break_away_haul', sqlcode, sqlerrm);
    END lmg_pickup_break_away_haul; /* end of lmg_pickup_break_away_haul */   
    
/*********************************************************************************
** Procedure:
**    lmg_drp_non_deep_hm_with_qoh
**
** Description:
**      This functions calculates the LM drop discreet value for a pallet
**      going to a home slot with existing qoh.  For drop to home batches
**      the drop quantity will always be handstacked.  Note that for drop
**      to home batches i_pals->qty_on_pallet[] will be the quantity to drop
**      to the home slot and not the total quantity on the pallet.
**
**  PARAMETERS:   
**      i_pals             - Pointer to pallet list.
**      i_num_pallets      - Number of pallets in pallet list.
**      i_e_rec            - Pointer to equipment tmu values.
**      i_dest_total_qoh   - Total qoh in destination.
**      o_drop             - Outgoing drop value.
**
**  RETURN VALUES:
**      None.
**
**        DATE         DESIGNER       COMMENTS
**     01/07/2020      Infosys     Initial version0.0
***********************************************************************************/

    PROCEDURE lmg_drp_non_deep_hm_with_qoh (
        i_pals             IN                 pl_lm_goal_pb.tbl_lmg_pallet_rec,
        i_num_pallets      IN                 NUMBER,
        i_e_rec            IN                 pl_lm_goal_pb.type_lmc_equip_rec,
        i_dest_total_qoh   IN                 NUMBER,
        o_drop             OUT                NUMBER
    ) AS

        l_func_name                    VARCHAR2(50) := 'pl_lm_goaltime.lmg_drp_non_deep_hm_with_qoh';
        l_message                      VARCHAR2(1024);
        l_apply_credit_at_case_level   NUMBER; /* Designates if to apply credit at the case level when uom = 1. */
        l_handstack_cases              NUMBER := 0; /* Cases handstacked */
        l_handstack_splits             NUMBER := 0; /* Splits handstacked */
        l_index                        NUMBER;                     /* Index */
        l_last_pal_qty                 NUMBER;        /* Quantity on last pallet in slot */
        l_multi_face_slot_bln          NUMBER; /* Multi-face slot */
        l_adj_num_positions            NUMBER := 0; /* Number of positions in the slot
									 adjusted for the min qty */
        l_slot_type_num_positions      NUMBER := 1;  /* Number of positions in the slot
											as indicated by the slot type.
											Always 1 for non-deep home slots */
        l_open_positions               NUMBER := 0; /* Number of open positions in the slot */
        l_pallet_height                NUMBER;    /* Height from floor to top pallet on stack */
        l_pallet_qty                   NUMBER;       /* Quantity on drop pallet or if the batch is
								a drop to home then the quantity to drop to
								the home slot */
        l_pallets_IN_SLOT              NUMBER;  /* Number of pallets for l_prev_qoh and
								incremented for each new pallet put in the
								slot */
        l_pindex                       NUMBER;            /* Index of top pallet on stack */
        l_prev_qoh                     NUMBER;          /* Approximate quantity in the slot before drop */
        l_slot_height                  NUMBER;       /* Height to slot from floor */
        l_spc                          NUMBER;               /* Splits per case */
        l_splits_per_pallet            NUMBER; /* Number of splits on a pallet */
        l_rf_ret_val                   rf.status := rf.status_normal;
    BEGIN
        pl_text_log.ins_msg_async('INFO', l_func_name, 'START lmg_drp_non_deep_hm_with_qoh', sqlcode, sqlerrm);
		/* Always removing the top pallet on the stack. */
        l_pindex := i_num_pallets;
        l_pallet_qty := i_pals(l_pindex).qty_on_pallet;
        l_prev_qoh := i_dest_total_qoh;
        l_slot_height := i_pals(l_pindex).height;
        l_spc := i_pals(l_pindex).spc;
        l_pallet_height := STD_PALLET_HEIGHT * l_pindex;
        l_splits_per_pallet := i_pals(l_pindex).ti * i_pals(l_pindex).hi * l_spc;

        l_pallets_IN_SLOT := l_prev_qoh / l_splits_per_pallet;
        l_last_pal_qty := MOD(l_prev_qoh, l_splits_per_pallet);
        IF ( l_last_pal_qty > 0 ) THEN   /* A partial pallet counts as a pallet. */
            l_pallets_IN_SLOT := l_pallets_IN_SLOT + 1;
        END IF;
		/*
		** if l_last_pal_qty is 0 then each pallet in the slot is a full pallet so
		** set l_last_pal_qty to a full pallet.
		*/
        IF ( l_last_pal_qty = 0 ) THEN
            l_last_pal_qty := l_splits_per_pallet;
        END IF;
        o_drop := 0;
        pl_text_log.ins_msg_async('INFO', l_func_name, l_func_name
                                            || '('
                                            || i_pals(l_pindex).pallet_id
                                            || ','
                                            || i_num_pallets
                                            || ','
                                            || i_e_rec.equip_id
                                            || ','
                                            || i_dest_total_qoh
                                            || ','
                                            || i_pals(l_pindex).multi_pallet_drop_to_slot
                                            || ')', sqlcode, sqlerrm);
		
		/*
		**  All the pallets being dropped to the same slot are processed
		**  the first time this function is called.
		*/

        IF ( i_pals(l_pindex).multi_pallet_drop_to_slot = 'Y' ) THEN
            return;
        END IF;
		
		/*
		** Adjust the number of positions in the slot based on the min quantity.
		*/
        l_adj_num_positions := i_pals(l_pindex).min_qty_num_positions + l_slot_type_num_positions;
		
		/*
		** Determine if this is a multi-face slot.
		*/
        IF ( i_pals(l_pindex).min_qty_num_positions >= l_slot_type_num_positions ) THEN
            l_multi_face_slot_bln := TRUE1;
        ELSE
            l_multi_face_slot_bln := FALSE0;
        END IF;
		
		/*
		** Get syspar that determines if to give credit at the case or
		** split level when dropping to a split home slot.
		*/

        l_rf_ret_val := pl_lm_forklift.lm_sel_split_rpl_crdt_syspar(l_apply_credit_at_case_level);
		
		/*
		** Process the pallets in the stack going to the same home slot.
		*/
        FOR l_index IN REVERSE 1..l_pindex LOOP
			/*
			**  Get out of the loop if all the drops to the same home slot
			**  have been processed.
			*/
            IF ( ( l_index != l_pindex ) AND i_pals(l_index).multi_pallet_drop_to_slot = 'N' ) THEN
                EXIT;
            END IF;
			/*
			**  Initialize variables. They may have been assigned a value above
			**  this for loop to use in debug and forklift audit messages. 
			*/

            l_pallet_qty := i_pals(l_index).qty_on_pallet;
            l_handstack_splits := 0;
            l_handstack_cases := 0;
            l_open_positions := l_adj_num_positions - l_pallets_in_slot;
			
			 /* 
			**  It is possible there are more pallets in the slot then
			**  there are positions which would make the open positions
			**  a negative value.
			*/
            IF ( l_open_positions < 0 ) THEN
                l_open_positions := 0;
            END IF;
            IF ( g_forklift_audit = TRUE1) THEN
                lmg_drop_to_home_audit_msg(i_pals, l_index, l_pallets_IN_SLOT, l_prev_qoh, l_slot_type_num_positions, l_adj_num_positions
                , l_open_positions, l_multi_face_slot_bln);
            END IF; /* end audit */
			
			/*
			**  If any one of the following are true then put the pallet
			**  in the slot:
			**     - There are open positions in the slot and this is not a
			**       drop to home batch.
			**     - The slot is a flow slot.
			**  otherwise handstack.
			*/

            IF ( ( ( l_pallets_IN_SLOT < l_adj_num_positions ) AND ( NOT ( ( substr(i_pals(l_index).batch_no, 1, 1) = LMF.FORKLIFT_BATCH_ID

            ) AND ( substr(i_pals(l_index).batch_no, 2, 1) = LMF.FORKLIFT_DROP_TO_HOME ) ) ) ) OR ( substr(i_pals(l_index).flow_slot_type

            , 1, 1) != 'N' ) ) THEN
				/*
				**  Put the pallet in the slot.
				*/
                IF ( i_num_pallets = 1 ) THEN
					/*
					**  There is one pallet in the pallet stack.
					**  Put it in the slot.
					*/
                    o_drop := o_drop + i_e_rec.tir + i_e_rec.apir + ( ( l_slot_height / 12.0 ) * i_e_rec.rl ) + i_e_rec.ppir + ( (
                    l_slot_height / 12.0 ) * i_e_rec.le ) + i_e_rec.bt90;

                    IF ( g_forklift_audit = TRUE1) THEN
                        l_message := 'Put pallet '
                                     || i_pals(l_index).pallet_id
                                     || ' in slot '
                                     || i_pals(l_index).dest_loc
                                     || '.';

                        lmg_audit_movement('TIR', g_audit_batch_no, i_e_rec, 1, l_message);
                        lmg_audit_movement('APIR', g_audit_batch_no, i_e_rec, 1, '');
                        lmg_audit_movement('RL', g_audit_batch_no, i_e_rec, l_slot_height, '');
                        lmg_audit_movement('PPIR', g_audit_batch_no, i_e_rec, 1, '');
                        lmg_audit_movement('LE', g_audit_batch_no, i_e_rec, l_slot_height, '');
                        lmg_audit_movement('BT90', g_audit_batch_no, i_e_rec, 1, '');
                    END IF; /* end audit */

                ELSE
					/*
					**  There is more than one pallet in the pallet stack.
					**
					**  Put the stack down (if not already down), take off the
					**  top pallet and put it in the slot.
					*/
                    IF ( g_forklift_audit = TRUE1) THEN
                        l_message := 'Remove pallet '
                                     || i_pals(l_index).pallet_id
                                     || ' from top of stack.';
                        lmg_audit_cmt(g_audit_batch_no, l_message, -1);
                    END IF;

                    IF ( l_index = l_pindex ) THEN
						/*
						**  First pallet being processed.  Put the stack down
						**  and get the top pallet off the stack.
						*/
                        o_drop := o_drop + i_e_rec.ppof + i_e_rec.bp + i_e_rec.apos + ( ( l_pallet_height / 12.0 ) * i_e_rec.re )
                        + i_e_rec.mepos;

                        IF ( g_forklift_audit = TRUE1) THEN
                            lmg_audit_movement('PPOF', g_audit_batch_no, i_e_rec, 1, 'Put the stack down.');
                            lmg_audit_movement('BP', g_audit_batch_no, i_e_rec, 1, '');
                            lmg_audit_movement('APOS', g_audit_batch_no, i_e_rec, 1, '');
                            lmg_audit_movement('RE', g_audit_batch_no, i_e_rec, l_pallet_height, '');
                            lmg_audit_movement('MEPOS', g_audit_batch_no, i_e_rec, 1, '');
                        END IF;

                    ELSE
						/*
						**  The previous pallet has been put in the slot, remove
						**  the top pallet from the stack.  The forks are at the
						**  level of the slot.
						*/
                        IF ( l_slot_height > l_pallet_height ) THEN
                            o_drop := o_drop + ( ( ( l_slot_height - l_pallet_height ) / 12.0 ) * i_e_rec.le );

                            IF ( g_forklift_audit = TRUE1) THEN
                                lmg_audit_movement('LE', g_audit_batch_no, i_e_rec, l_slot_height - l_pallet_height, '');
                            END IF; /* end audit */

                        ELSE
                            o_drop := o_drop + ( ( ( l_pallet_height - l_slot_height ) / 12.0 ) * i_e_rec.re );

                            IF ( g_forklift_audit = TRUE1) THEN
                                lmg_audit_movement('RE', g_audit_batch_no, i_e_rec, l_pallet_height - l_slot_height, '');
                            END IF; /* end audit */

                        END IF;

                        IF ( l_index = 0 ) THEN
							/*
							**  At the last pallet in the stack so it is
							**  on the floor.
							*/
                            o_drop := o_drop + i_e_rec.apof + i_e_rec.mepof;
                            IF ( g_forklift_audit = TRUE1) THEN
                                lmg_audit_movement('APOF', g_audit_batch_no, i_e_rec, 1, '');
                                lmg_audit_movement('MEPOF', g_audit_batch_no, i_e_rec, 1, '');
                            END IF;

                        ELSE
                            o_drop := o_drop + i_e_rec.apos + i_e_rec.mepos;
                            IF ( g_forklift_audit = TRUE1) THEN
                                lmg_audit_movement('APOS', g_audit_batch_no, i_e_rec, 1, '');
                                lmg_audit_movement('MEPOS', g_audit_batch_no, i_e_rec, 1, '');
                            END IF;

                        END IF; /* End of last pallet in the stack IF */

                    END IF; /* End of First pallet being processed IF */
					/*
					**  The pallet is on the forks.  Move the forks up or down as
					**  appropriate and put the pallet in the slot.
					*/

                    IF ( l_slot_height > l_pallet_height ) THEN
                        o_drop := o_drop + i_e_rec.bt90 + i_e_rec.apir + ( ( ( l_slot_height - l_pallet_height ) / 12.0 ) * i_e_rec
                        .rl ) + i_e_rec.ppir + i_e_rec.bt90;
                    ELSE
                        o_drop := o_drop + i_e_rec.bt90 + i_e_rec.apir + ( ( ( l_pallet_height - l_slot_height ) / 12.0 ) * i_e_rec
                        .ll ) + i_e_rec.ppir + i_e_rec.bt90;
                    END IF; /* end put pallet in slot */

                    IF ( g_forklift_audit = TRUE1) THEN
                        l_message := 'Put pallet '
                                     || i_pals(l_index).pallet_id
                                     || ' in slot '
                                     || i_pals(l_index).dest_loc
                                     || '.';

                        IF ( l_slot_height > l_pallet_height ) THEN
                            lmg_audit_movement('BT90', g_audit_batch_no, i_e_rec, 1, l_message);
                            lmg_audit_movement('APIR', g_audit_batch_no, i_e_rec, 1, '');
                            lmg_audit_movement('RL', g_audit_batch_no, i_e_rec, l_slot_height - l_pallet_height, '');
                            lmg_audit_movement('PPIR', g_audit_batch_no, i_e_rec, 1, '');
                            lmg_audit_movement('BT90', g_audit_batch_no, i_e_rec, 1, '');
                        ELSE
                            lmg_audit_movement('BT90', g_audit_batch_no, i_e_rec, 1, l_message);
                            lmg_audit_movement('APIR', g_audit_batch_no, i_e_rec, 1, '');
                            lmg_audit_movement('LL', g_audit_batch_no, i_e_rec, l_pallet_height - l_slot_height, '');
                            lmg_audit_movement('PPIR', g_audit_batch_no, i_e_rec, 1, '');
                            lmg_audit_movement('BT90', g_audit_batch_no, i_e_rec, 1, '');
                        END IF; /* end audit movement */

                    END IF; /* end audit */

                END IF;
				/*
				** If this is the first pallet in the stack going to the slot
				** and the qoh in the slot is less than a full pallet and it is
				** a multi-face slot and it is not a flow slot then give credit
				** to handstack qoh/2 cases.
				*/

                IF ( ( l_index = l_pindex ) AND ( l_prev_qoh < l_splits_per_pallet ) AND ( l_multi_face_slot_bln = TRUE1 ) AND (

                substr(i_pals(l_index).flow_slot_type, 1, 1) = 'N' ) ) THEN
                    l_handstack_cases := ( l_prev_qoh / l_spc ) / 2;
                    l_handstack_splits := 0;
                    l_rf_ret_val := pl_lm_forklift.lmf_update_batch_kvi(i_pals(l_index).batch_no, l_handstack_cases, l_handstack_splits
                    );

                    IF ( g_forklift_audit = TRUE1) THEN
                        l_message := 'Multi-face slot and less than a full pallet in the slot.  Give credit to handstack '
                                     || l_handstack_cases
                                     || ' case(s) which is the qoh / 2.';
                        lmg_audit_cmt(g_audit_batch_no, l_message, -1);
                    END IF;

                END IF; /* End of prev_qoh < splits_per_pallet IF */

                l_pallets_in_slot := l_pallets_in_slot + 1;
            ELSE
				/*
				**  There are no open positions in the slot or this is a
				**  drop to home batch.  Handstack.
				*/
                IF ( l_index = l_pindex ) THEN
					/*
					**  First pallet being processed.  Put the stack down.
					*/
                    o_drop := o_drop + i_e_rec.ppof;
                    IF ( g_forklift_audit = TRUE1) THEN
                        lmg_audit_movement('PPOF', g_audit_batch_no, i_e_rec, 1, 'Put the stack down.');
                    END IF; /* end audit movement */

                END IF; /* end check first pallet */
				
				/*
				**  Remove pallet from the slot.  The forklift operator should
				**  be removing the pallet that has the fewest cases if
				**  there are multiple pallets in the slot.
				*/

                o_drop := o_drop + i_e_rec.bt90 + i_e_rec.apir + ( ( l_slot_height / 12.0 ) * i_e_rec.re ) + i_e_rec.mepir + ( (

                l_slot_height / 12.0 ) * i_e_rec.ll ) + i_e_rec.bt90 + i_e_rec.ppof;

                IF ( g_forklift_audit = TRUE1) THEN
					/*
					** Leave out audit message if drop to home.
					*/
                    IF ( NOT ( ( substr(i_pals(l_index).batch_no, 1, 1) = LMF.FORKLIFT_BATCH_ID ) AND ( substr(i_pals(l_index).batch_no
                    , 2, 1) = LMF.FORKLIFT_DROP_TO_HOME ) ) ) THEN
                        l_message := 'There are no open positions in home slot '
                                     || i_pals(l_index).dest_loc
                                     || '.  Handstack.';
                        lmg_audit_cmt(g_audit_batch_no, l_message, -1);
                    END IF;

                    lmg_audit_movement('BT90', g_audit_batch_no, i_e_rec, 1, 'Pull pallet from home slot.');
                    lmg_audit_movement('APIR', g_audit_batch_no, i_e_rec, 1, '');
                    lmg_audit_movement('RE', g_audit_batch_no, i_e_rec, l_slot_height, '');
                    lmg_audit_movement('MEPIR', g_audit_batch_no, i_e_rec, 1, '');
                    lmg_audit_movement('LL', g_audit_batch_no, i_e_rec, l_slot_height, '');
                    lmg_audit_movement('BT90', g_audit_batch_no, i_e_rec, 1, '');
                    lmg_audit_movement('PPOF', g_audit_batch_no, i_e_rec, 1, '');
                END IF; /* end audit */
				
				/*
				**  If there is more than 1 pallet in the stack then get the top
				**  pallet and lower it to the floor.
				*/

                IF ( l_index > 0 ) THEN
                    o_drop := o_drop + i_e_rec.bp + i_e_rec.apos + ( ( l_pallet_height / 12.0 ) * i_e_rec.re ) + i_e_rec.mepos + (
                    ( l_pallet_height / 12.0 ) * i_e_rec.ll );

                    IF ( g_forklift_audit = TRUE1) THEN
                        l_message := 'Remove pallet '
                                     || i_pals(l_index).pallet_id
                                     || ' from top of stack and lower to the floor.';
                        lmg_audit_movement('BP', g_audit_batch_no, i_e_rec, 1, l_message);
                        lmg_audit_movement('APOS', g_audit_batch_no, i_e_rec, 1, '');
                        lmg_audit_movement('RE', g_audit_batch_no, i_e_rec, l_pallet_height, '');
                        lmg_audit_movement('MEPOS', g_audit_batch_no, i_e_rec, 1, '');
                        lmg_audit_movement('LL', g_audit_batch_no, i_e_rec, l_pallet_height, '');
                    END IF; /* end audit */

                END IF; /* end more than 1 pallet check */
				
				/*
				**  Handstack the appropriate qty.
				*/

                IF ( ( l_last_pal_qty <= l_pallet_qty ) AND ( NOT ( ( substr(i_pals(l_index).batch_no, 1, 1) = LMF.FORKLIFT_BATCH_ID

                ) AND ( substr(i_pals(l_index).batch_no, 2, 1) = LMF.FORKLIFT_DROP_TO_HOME ) ) ) ) THEN
					/*
					**  The number of pieces on the pallet pulled from the
					**  home slot is <= the number of pieces on the new pallet
					**  and this is not a drop to home.
					**  Handstack the pieces on the pallet pulled from the
					**  home slot onto the new pallet.
					**
					**  If this is the last pallet in the stack then the pallet
					**  pulled from the slot is still on the forks.  The pallet
					**  in the stack is the one that will be put in the slot so
					**  position this pallet on the forks.
					*/
                    IF ( l_index = 0 ) THEN
                        o_drop := o_drop + i_e_rec.bp + i_e_rec.apof + i_e_rec.mepof;
                    END IF;

                    IF ( i_pals(l_index).uom = 1 ) THEN
						/*
						** Split home.
						*/
                        IF ( l_apply_credit_at_case_level != 0 ) THEN
							/*
							** Case up splits.
							*/
                            l_handstack_cases := l_last_pal_qty / l_spc;
                            l_handstack_splits := MOD(l_last_pal_qty, l_spc);
                            IF ( g_forklift_audit = TRUE1) THEN
                                lmg_audit_cmt(g_audit_batch_no, q'(Syspar "Split RPL Credit at Case Level" is set to 'Y' so credit will be applied at the case level.)'
                                , -1);
                            END IF; /* end audit comment */
                        ELSE
                            l_handstack_cases := 0;
                            l_handstack_splits := l_last_pal_qty;
                            IF ( g_forklift_audit = TRUE1) THEN
                                lmg_audit_cmt(g_audit_batch_no, q'(Syspar "Split RPL Credit at Case Level" is set to 'N' so credit will be applied at the split level.)'
                                , -1);
                            END IF; /* end audit comment */
                        END IF; /* end case up splits */

                    ELSE
						/*
						** Case home which can have splits.
						*/
                        l_handstack_cases := l_last_pal_qty / l_spc;
                        l_handstack_splits := MOD(l_last_pal_qty, l_spc);
                    END IF; /* end split home */

                    IF ( g_forklift_audit = TRUE1) THEN
                        IF ( l_index = 0 ) THEN
                            lmg_audit_movement('BP', g_audit_batch_no, i_e_rec, 1, 'Position the new pallet on the forks.');
                            lmg_audit_movement('APOF', g_audit_batch_no, i_e_rec, 1, '');
                            lmg_audit_movement('MEPOF', g_audit_batch_no, i_e_rec, 1, '');
                        END IF;

                        l_message := 'Handstack the '
                                     || l_handstack_cases
                                     || ' case(s) and '
                                     || l_handstack_splits
                                     || ' split(s) on the pallet pulled from the slot onto the new pallet.';
                        lmg_audit_cmt(g_audit_batch_no, l_message, -1);
                    END IF; /* end audit */

                ELSE
					/*
					**  The number of pieces on the pallet pulled from the
					**  home slot is > the number of pieces on the new pallet
					**  or this is a drop to home batch.
					**  Handstack the pieces on the new pallet onto the pallet
					**  pulled from the home slot.
					*/
                    IF ( i_pals(l_index).uom = 1 ) THEN
						/*
						** Split home.
						*/
                        IF ( ( l_apply_credit_at_case_level != 0 ) OR ( ( substr(i_pals(l_index).batch_no, 1, 1) = LMF.FORKLIFT_BATCH_ID
                        ) AND ( substr(i_pals(l_index).batch_no, 2, 1) = LMF.FORKLIFT_DROP_TO_HOME ) ) ) THEN
							/*
							** Case up the splits.
							*/
                            l_handstack_cases := l_pallet_qty / l_spc;
                            l_handstack_splits := MOD(l_pallet_qty, l_spc);

							/*
							** Leave out audit message if drop to home.
							*/
                            IF ( ( g_forklift_audit = TRUE1) AND ( NOT ( ( substr(i_pals(l_index).batch_no, 1, 1) = LMF.FORKLIFT_BATCH_ID ) AND
                            ( substr(i_pals(l_index).batch_no, 2, 1) = LMF.FORKLIFT_DROP_TO_HOME ) ) ) ) THEN
                                lmg_audit_cmt(g_audit_batch_no, q'(Syspar "Split RPL Credit at Case Level" is set to 'Y' so credit will be applied at the case level.)'
                                , -1);
                            END IF; /* end audit comment */

                        ELSE
                            l_handstack_cases := 0;
                            l_handstack_splits := l_pallet_qty; 

							/*
							** Leave out audit message if drop to home.
							*/
                            IF ( ( g_forklift_audit = TRUE1) AND ( NOT ( ( substr(i_pals(l_index).batch_no, 1, 1) = LMF.FORKLIFT_BATCH_ID ) AND
                            ( substr(i_pals(l_index).batch_no, 2, 1) = LMF.FORKLIFT_DROP_TO_HOME ) ) ) ) THEN
                                lmg_audit_cmt(g_audit_batch_no, q'(Syspar "Split RPL Credit at Case Level" is set to 'N' so credit will be applied at the split level.)'
                                , -1);
                            END IF; /* end audit comment */

                        END IF; /* end split home */
                    ELSE
						/*
						** Case home which can have splits.
						*/
                        l_handstack_cases := l_pallet_qty / l_spc;
                        l_handstack_splits := MOD(l_pallet_qty, l_spc);
                    END IF; /* end handstack the pieces on the new pallet */

					/* 
					**  If there was more than one pallet in the stack then 
					**  the pallet removed from the top of the stack is on
					**  the forks.  The pallet pulled from the slot is the
					**  pallet to put in the slot so position the forks on
					**  this pallet.
					*/

                    IF ( l_index > 0 ) THEN
                        o_drop := o_drop + i_e_rec.bp + i_e_rec.apof + i_e_rec.mepof;
                    END IF;

                    IF ( g_forklift_audit = TRUE1) THEN
                        IF ( ( substr(i_pals(l_index).batch_no, 1, 1) = LMF.FORKLIFT_BATCH_ID ) AND ( substr(i_pals(l_index).batch_no
                        , 2, 1) = LMF.FORKLIFT_DROP_TO_HOME ) ) THEN
                            l_message := 'Handstack the '
                                         || l_handstack_cases
                                         || ' case(s) and '
                                         || l_handstack_splits
                                         || ' split(s) on the bulk pull pallet onto the pallet pulled from home slot '
                                         || i_pals(l_index).dest_loc
                                         || '.';
                        ELSE
                            l_message := 'Handstack the '
                                         || l_handstack_cases
                                         || ' case(s) and '
                                         || l_handstack_splits
                                         || ' split(s) on the new pallet onto the pallet pulled from home slot '
                                         || i_pals(l_index).dest_loc
                                         || '.';
                        END IF;

                        lmg_audit_cmt(g_audit_batch_no, l_message, -1);
                        IF ( l_index > 0 ) THEN
                            lmg_audit_movement('BP', g_audit_batch_no, i_e_rec, 1, 'Position the pallet pulled from the home slot on the forks.'
                            );
                            lmg_audit_movement('APOF', g_audit_batch_no, i_e_rec, 1, '');
                            lmg_audit_movement('MEPOF', g_audit_batch_no, i_e_rec, 1, '');
                        END IF;

                    END IF; /* end audit */

                END IF; /* end handstack appropriate qty */
				
				/*
				**  Put pallet in slot.  This will be either the pallet pulled from
				**  the home slot or the new pallet.
				*/

                o_drop := o_drop + i_e_rec.ds + i_e_rec.bt90 + i_e_rec.apir + ( ( l_slot_height / 12.0 ) * i_e_rec.rl ) + i_e_rec

                .ppir + ( ( l_slot_height / 12.0 ) * i_e_rec.le ) + i_e_rec.bt90;

                IF ( g_forklift_audit = TRUE1) THEN
                    l_message := 'Put pallet in slot '
                                 || i_pals(l_index).dest_loc
                                 || '.';
                    lmg_audit_movement('DS', g_audit_batch_no, i_e_rec, 1, l_message);
                    lmg_audit_movement('BT90', g_audit_batch_no, i_e_rec, 1, '');
                    lmg_audit_movement('APIR', g_audit_batch_no, i_e_rec, 1, '');
                    lmg_audit_movement('RL', g_audit_batch_no, i_e_rec, l_slot_height, '');
                    lmg_audit_movement('PPIR', g_audit_batch_no, i_e_rec, 1, '');
                    lmg_audit_movement('LE', g_audit_batch_no, i_e_rec, l_slot_height, '');
                    lmg_audit_movement('BT90', g_audit_batch_no, i_e_rec, 1, '');
                END IF; /* end audit */

                l_last_pal_qty := i_pals(l_index).qty_on_pallet;
                l_rf_ret_val := pl_lm_forklift.lmf_update_batch_kvi(i_pals(l_index).batch_no, l_handstack_cases, l_handstack_splits
                );

            END IF; /* end of put pallet in slot or handstack */

            l_pallet_height := l_pallet_height - STD_PALLET_HEIGHT;
            l_prev_qoh := l_prev_qoh + l_pallet_qty;
            pl_text_log.ins_msg_async('INFO', l_func_name, 'o_drop=' || o_drop, sqlcode, sqlerrm);
        END LOOP; /* end of for loop */
		
		/*
		** Pickup stack if there are more pallets to drop at other locations.
		*/

        IF ( l_index >= 0 ) THEN
			/*
			** There are pallets still in the travel stack.
			** Pick up stack and go to next destination.
			*/
            lmg_pickup_for_next_dst(i_pals, l_index, i_e_rec, o_drop);
        END IF;

        pl_text_log.ins_msg_async('INFO', l_func_name, 'END lmg_drp_non_deep_hm_with_qoh', sqlcode, sqlerrm);
    END lmg_drp_non_deep_hm_with_qoh; /* end lmg_drp_non_deep_hm_with_qoh */

/*********************************************************************************
** Procedure:
**    lmg_drop_to_empty_res_slot
**
** Description:
**     This functions calculates the LM drop discreet value for a pallet
**     going to an empty reserve destination.
**
**  PARAMETERS:   
**     i_pals             - Pointer to pallet list.
**     i_num_pallets      - Number of pallets in pallet list.
**     i_e_rec            - Pointer to equipment tmu values.
**     o_drop             - Outgoing drop value.
**
**  RETURN VALUES:
**      None.
**
**        DATE         DESIGNER       COMMENTS
**     01/07/2020      Infosys     Initial version0.0
***********************************************************************************/

    PROCEDURE lmg_drop_to_empty_res_slot (
        i_pals          IN              pl_lm_goal_pb.tbl_lmg_pallet_rec,
        i_num_pallets   IN              NUMBER,
        i_e_rec         IN              pl_lm_goal_pb.type_lmc_equip_rec,
        o_drop          OUT             NUMBER
    ) AS

        l_func_name                  VARCHAR2(50) := 'pl_lm_goaltime.lmg_drop_to_empty_res_slot';
        l_message                    VARCHAR2(1024);
        l_index                      NUMBER;
        l_num_pallets_to_same_slot   NUMBER := 0; /* Number of pallets in the travel
                                              stack going to the same slot. */
        l_pindex                     NUMBER;         /* Index of top pallet on stack */
        l_slot_height                NUMBER;    /* Height to slot from floor */
        l_bottom_pallet_height       NUMBER;  /* Height from floor to first pallet in the
								stack going to the slot.  All pallets going to
								the same slot are placed in the slot in one
								operation. */
        l_slot_type                  VARCHAR2(3);  /* Type of slot pallet is
											   going to. */
        l_g_tir                      NUMBER := 0.0;    /* Generic Turn o rack */
        l_g_apir                     NUMBER := 0.0;   /* Generic Approach Pallet in rack */
        l_g_mepir                    NUMBER := 0.0;  /* Generic Manuv. and Enter Pallet in rack */
        l_g_ppir                     NUMBER := 0.0;   /* Generic Position Pallet rack */
        l_rack_type                  VARCHAR2(1);      /* Rack type used by the forklift audit to
									determine the actual forklift operation.
									Needed because of the use of the generic
									variables. */
    BEGIN
        pl_text_log.ins_msg_async('INFO', l_func_name, 'START lmg_drop_to_empty_res_slot', sqlcode, sqlerrm);
		/*
		** Initialization
		**
		** Always removing the top pallet on the stack.
		*/
        l_pindex := i_num_pallets;
        pl_text_log.ins_msg_async('INFO', l_func_name, l_func_name
                                            || '('
                                            || i_pals(l_pindex).pallet_id
                                            || ','
                                            || i_num_pallets
                                            || ','
                                            || i_e_rec.equip_id
                                            || ')', sqlcode, sqlerrm);
		
		/*
		** All the child LP's dropped to the same slot are processed
		** the first time this function is called.
		*/

        IF ( i_pals(l_pindex).multi_pallet_drop_to_slot = 'Y' ) THEN
            return;
        END IF;
        l_slot_height := i_pals(l_pindex).height;
        l_slot_type := i_pals(l_pindex).slot_type;
        o_drop := 0.0;
		
		/*
		** Count the pallets in the travel stack going to the same slot.
		*/
        l_num_pallets_to_same_slot := 1;  /* There is at least one. */
        FOR l_index IN REVERSE 1..( l_pindex - 1 ) LOOP IF ( i_pals(l_index).multi_pallet_drop_to_slot = 'Y' ) THEN
            l_num_pallets_to_same_slot := l_num_pallets_to_same_slot + 1;
        END IF;	/* end l_num_pallets_to_same_slot count */
        END LOOP; /* end loop */
		
		/*
		** Determine height to the bottom most pallet in the travel stack
		** going to the slot.
		*/

        l_bottom_pallet_height := STD_PALLET_HEIGHT * ( i_num_pallets - l_num_pallets_to_same_slot );
		
		
		/*
		** Assign the equipment rates that depend on the type of slot.
		*/
        assign_equip_rates(i_e_rec, l_slot_type, substr(i_pals(l_pindex).deep_ind, 1, 1), l_g_tir, l_g_apir, l_g_mepir, l_g_ppir,
        l_rack_type);		
		
		/*
		** The two zeroes in the lmg_drop_to_reserve_audit_msg() parameter list
		** are i_pallets_IN_SLOT and i_num_drops_completed.
		*/

        IF ( g_forklift_audit = TRUE1) THEN
            lmg_drop_to_reserve_audit_msg(i_pals, l_pindex, 0, 0);
            IF ( l_num_pallets_to_same_slot > 1 ) THEN
                l_message := l_num_pallets_to_same_slot
                             || ' pallets in the stack are going to '
                             || i_pals(l_pindex).slot_desc
                             || ' slot '
                             || i_pals(l_pindex).dest_loc
                             || '.  They will be placed in the slot in one operation.';

                lmg_audit_cmt(g_audit_batch_no, l_message, -1);
            END IF; /* end l_num_pallets_to_same_slot > 1 */

        END IF; /* end forlift audit */
		
		/*
		** If there is one pallet in the travel stack or all the pallets in
		** the travel stack are going to the same slot then place the travel
		** stack in the slot.
		** If there is more than one pallet in the travel stack and not all the
		** pallets in the travel stack are going to the same slot then put the
		** travel stack down and pickup the stack of pallets going to the same
		** slot and place in the slot.
		*/

        IF ( ( i_num_pallets = 1 ) OR ( l_num_pallets_to_same_slot = i_num_pallets ) ) THEN
			/*
			** There is one pallet in the travel stack or all the pallets in
			** the travel stack are going to the same slot.  Place the travel
			** stack in the slot.
			*/
            o_drop := o_drop + l_g_tir + l_g_apir + ( ( l_slot_height / 12.0 ) * i_e_rec.rl ) + 
                        l_g_ppir + ( ( l_slot_height / 12.0 ) * i_e_rec.le ) + i_e_rec.bt90;

            IF ( g_forklift_audit = TRUE1) THEN
                IF ( l_num_pallets_to_same_slot = 1 ) THEN
                    l_message := 'One pallet in the stack.  Put pallet '
                                 || i_pals(l_pindex).pallet_id
                                 || ' in slot '
                                 || i_pals(l_pindex).dest_loc
                                 || '.';
                ELSE
                    l_message := 'Put the stack of '
                                 || l_num_pallets_to_same_slot
                                 || ' pallets in slot '
                                 || i_pals(l_pindex).dest_loc
                                 || '.';
                END IF; /* end set message */

                lmg_audit_movement_generic(l_rack_type, 'TIR', g_audit_batch_no, i_e_rec, 1, l_message);
                lmg_audit_movement_generic(l_rack_type, 'APIR', g_audit_batch_no, i_e_rec, 1, '');
                lmg_audit_movement('RL', g_audit_batch_no, i_e_rec, l_slot_height, '');
                lmg_audit_movement_generic(l_rack_type, 'PPIR', g_audit_batch_no, i_e_rec, 1, '');
                lmg_audit_movement('LE', g_audit_batch_no, i_e_rec, l_slot_height, '');
                lmg_audit_movement('BT90', g_audit_batch_no, i_e_rec, 1, '');
            END IF; /* end audit */

        ELSE
			/*
			** There is more than one pallet in the travel stack and not all the
			** pallets in the travel stack are going to the same slot.  Put the
			** travel stack down and pickup the stack of pallets going to the same
			** slot and place in the slot.
			*/
            o_drop := i_e_rec.ppof + i_e_rec.bp + i_e_rec.apos + ( ( l_bottom_pallet_height / 12.0 ) * i_e_rec.re ) + i_e_rec.mepos
            ;

            IF ( g_forklift_audit = TRUE1) THEN
                IF ( l_num_pallets_to_same_slot = 1 ) THEN
                    l_message := 'Remove pallet '
                                 || i_pals(l_pindex).pallet_id
                                 || ' from top of stack.  '
                                 || i_num_pallets
                                 || ' pallets in the stack.';
                ELSE
                    l_message := 'Remove the '
                                 || l_num_pallets_to_same_slot
                                 || ' pallets going to slot '
                                 || i_pals(l_pindex).pallet_id
                                 || ' from thhe stack of '
                                 || i_num_pallets
                                 || ' pallets.';
                END IF; /* end set message */

                lmg_audit_movement('PPOF', g_audit_batch_no, i_e_rec, 1, l_message);
                lmg_audit_movement('BP', g_audit_batch_no, i_e_rec, 1, '');
                lmg_audit_movement('APOS', g_audit_batch_no, i_e_rec, 1, '');
                lmg_audit_movement('RE', g_audit_batch_no, i_e_rec, l_bottom_pallet_height, '');
                lmg_audit_movement('MEPOS', g_audit_batch_no, i_e_rec, 1, '');
            END IF; /* end audit */

			/*
			** Have the pallet(s) going to the slot on the forks.  Move up or down
			** and put the pallet(s) in the rack.
			*/

            IF ( l_slot_height > l_bottom_pallet_height ) THEN
                o_drop := o_drop + i_e_rec.bt90 + l_g_apir + ( ( ( l_slot_height - l_bottom_pallet_height ) / 12.0 ) * i_e_rec.rl
                ) + l_g_ppir + ( ( l_slot_height / 12.0 ) * i_e_rec.le ) + i_e_rec.bt90;
            ELSE
                o_drop := o_drop + i_e_rec.bt90 + l_g_apir + ( ( ( l_bottom_pallet_height - l_slot_height ) / 12.0 ) * i_e_rec.ll
                ) + l_g_ppir + ( ( l_slot_height / 12.0 ) * i_e_rec.le ) + i_e_rec.bt90;
            END IF; /* end put the pallets in the rack */

            IF ( g_forklift_audit = TRUE1) THEN
                IF ( l_num_pallets_to_same_slot = 1 ) THEN
                    l_message := 'Put pallet '
                                 || i_pals(l_pindex).pallet_id
                                 || ' in slot '
                                 || i_pals(l_pindex).dest_loc
                                 || '.';
                ELSE
                    l_message := 'Put the stack of '
                                 || l_num_pallets_to_same_slot
                                 || ' pallets in slot '
                                 || i_pals(l_pindex).dest_loc
                                 || '.';
                END IF; /* end set message */

                lmg_audit_movement('BT90', g_audit_batch_no, i_e_rec, 1, l_message);
                lmg_audit_movement_generic(l_rack_type, 'APIR', g_audit_batch_no, i_e_rec, 1, '');
                IF ( l_slot_height > l_bottom_pallet_height ) THEN
                    lmg_audit_movement('RL', g_audit_batch_no, i_e_rec, l_slot_height - l_bottom_pallet_height, '');
                ELSE
                    lmg_audit_movement('LL', g_audit_batch_no, i_e_rec, l_bottom_pallet_height - l_slot_height, '');
                END IF; /* end audit movement based on slot height */

                lmg_audit_movement_generic(l_rack_type, 'PPIR', g_audit_batch_no, i_e_rec, 1, '');
                lmg_audit_movement('LE', g_audit_batch_no, i_e_rec, l_slot_height, '');
                lmg_audit_movement('BT90', g_audit_batch_no, i_e_rec, 1, '');
            END IF; /* end audit */

			/*
			** Pick up the travel stack and go to the next destination.
			*/

            lmg_pickup_for_next_dst(i_pals, l_pindex - l_num_pallets_to_same_slot, i_e_rec, o_drop);
        END IF;

        pl_text_log.ins_msg_async('INFO', l_func_name, l_func_name
                                            || ' calculated o_drop='
                                            || o_drop, sqlcode, sqlerrm);

        pl_text_log.ins_msg_async('INFO', l_func_name, 'END lmg_drop_to_empty_res_slot', sqlcode, sqlerrm);
    END lmg_drop_to_empty_res_slot; /* end lmg_drop_to_empty_res_slot */
    
/*********************************************************************************
**   FUNCTION:
**    lmg_drp_non_deep_res_with_qoh
**   
**   Description:
**     This functions calculates the LM drop discreet value for a pallet
**     going to a destination where inventory already exists.
**
**  PARAMETERS:   
**     i_pals          - Pointer to pallet list.
**     i_num_pallets   - Number of pallets in pallet list.
**     i_e_rec         - Pointer to equipment tmu values.
**     i_inv           - Pointer to pallets already in the destination.
**     i_is_same_item  - Flag denoting if the same item is already in the
**                       destination location.
**     o_drop          - Outgoing drop value.
**
**  RETURN VALUES:
**      None.
**
**        DATE         DESIGNER       COMMENTS
**     01/07/2020      Infosys     Initial version0.0
***********************************************************************************/

    PROCEDURE lmg_drp_non_deep_res_with_qoh (
        i_pals           IN               pl_lm_goal_pb.tbl_lmg_pallet_rec,
        i_num_pallets    IN               NUMBER,
        i_e_rec          IN               pl_lm_goal_pb.type_lmc_equip_rec,
        i_inv            IN               pl_lm_goal_pb.tbl_lmg_inv_rec,
        i_is_same_item   IN               VARCHAR2,
        o_drop           OUT              NUMBER
    ) AS

        l_func_name                  VARCHAR2(50) := 'pl_lm_goaltime.lmg_drp_non_deep_res_with_qoh';
        l_message                    VARCHAR2(1024);
        l_height_diff                NUMBER;    /* Work area */
        l_num_pallets_to_same_slot   NUMBER := 0; /* # of pallets in the travel stack
													going to the same slot. */
        l_pindex                     NUMBER;         /* Index of top pallet on stack */
        l_slot_height                NUMBER;    /* Height to slot from floor */
        l_pallet_height              NUMBER;  /* Height from floor to top pallet on stack */
        l_bottom_pallet_height       NUMBER;  /* Height from floor to first pallet in the
												stack going to the slot.  All pallets going to
												the same slot are placed in the slot in one
												operation. */
        l_pallets_IN_SLOT            NUMBER := 0;   /* Number of pallets currently in the slot.
													 It does not include the pallets in
													 the travel stack that are going to
													 the slot. */
        l_index                      NUMBER;                /* Index */
    BEGIN    
        pl_text_log.ins_msg_async('INFO', l_func_name, 'START lmg_drp_non_deep_res_with_qoh', sqlcode, sqlerrm);
		/*
		** Initialization
		**
		** Always removing the top pallet on the stack.
		*/
        l_pindex := i_num_pallets;
        pl_text_log.ins_msg_async('INFO', l_func_name, l_func_name
                                            || '('
                                            || i_pals(l_pindex).pallet_id
                                            || ','
                                            || i_num_pallets
                                            || ','
                                            || i_e_rec.equip_id
                                            || ','
                                            || i_is_same_item
                                            || ', o_drop)', sqlcode, sqlerrm);
		
		/*
		** All the child LP's dropped to the same slot are processed
		** the first time this function is called.
		*/

        IF ( i_pals(l_pindex).multi_pallet_drop_to_slot = 'Y' ) THEN
            return;
        END IF;
        l_slot_height := i_pals(l_pindex).height;
        l_pallet_height := STD_PALLET_HEIGHT * l_pindex;
        l_pallets_IN_SLOT := i_inv.last;
        o_drop := 0.0;
		
		/*
		** Count the pallets in the travel stack going to the same slot.
		*/
        l_num_pallets_to_same_slot := 1;  /* There is at least one. */
        FOR l_index IN REVERSE 1..( l_pindex - 1 ) LOOP IF ( i_pals(l_index).multi_pallet_drop_to_slot = 'Y' ) THEN
            l_num_pallets_to_same_slot := l_num_pallets_to_same_slot + 1;
        END IF;	/* end l_num_pallets_to_same_slot count */
        END LOOP; /* end loop */
		
		/*
		** Determine height to the bottom most pallet in the travel stack
		** going to the slot.
		*/

        l_bottom_pallet_height := STD_PALLET_HEIGHT * ( i_num_pallets - l_num_pallets_to_same_slot );
		
		/*
		** The zero in the lmg_drop_to_reserve_audit_msg() parameter list
		** is i_num_drops_completed.
		*/
        IF ( g_forklift_audit = TRUE1) THEN
            lmg_drop_to_reserve_audit_msg(i_pals, l_pindex, l_pallets_IN_SLOT, 0);
            IF ( l_num_pallets_to_same_slot > 1 ) THEN
                l_message := l_num_pallets_to_same_slot
                             || ' pallets in the stack are going to '
                             || i_pals(l_pindex).slot_desc
                             || ' slot '
                             || i_pals(l_pindex).dest_loc
                             || '.  They will be placed in the slot in one operation.';

                lmg_audit_cmt(g_audit_batch_no, l_message, -1);
            END IF; /* end audit comment */

        END IF; /* end audit */
		
		/*
		** Put travel stack down if an item going to the slot already exists in
		** the slot or not all the pallets in the travel stack are going to
		** the slot.
		*/

        IF ( ( i_is_same_item = 'Y' ) OR ( ( i_num_pallets - l_num_pallets_to_same_slot ) > 0 ) ) THEN
            o_drop := i_e_rec.ppof + i_e_rec.bt90;
            IF ( g_forklift_audit = TRUE1) THEN
                l_message := 'Put stack down.  '
                             || i_num_pallets
                             || ' pallet(s) in the stack.';
                lmg_audit_movement('PPOF', g_audit_batch_no, i_e_rec, 1, l_message);
                lmg_audit_movement('BT90', g_audit_batch_no, i_e_rec, 1, '');
            END IF; /* end audit movement */

        END IF; /* end put travel stock down */
		
		/*
		** There is different processing if any of the items in the travel stack
		** already exists in the slot or does not exist.
		*/

        IF ( i_is_same_item = 'Y' ) THEN
		
			/*
			** One or more of the items in the travel stack exists in the slot.
			** Put the travel stack down, take the pallets in the slot and place
			** on top of the travel stack then pickup the stack at the bottom
			** most pallet going to the slot and place the stack in the slot.
			*/
            IF ( g_forklift_audit = TRUE1) THEN
                l_message := 'One or more of the items going to the slot exist in the slot.  Put the stack down, take the pallet(s) in the slot and place on the stack then pickup the stack and place in the slot.'
                ;
                lmg_audit_cmt(g_audit_batch_no, l_message, -1);
            END IF; /* end audit */

			/*
			** Take stack of pallet(s) from rack and put on travel stack.
			*/

            o_drop := o_drop + i_e_rec.apir + ( ( l_slot_height / 12.0 ) * i_e_rec.re ) + i_e_rec.mepir;

            IF ( g_forklift_audit = TRUE1) THEN
                l_message := 'Take the '
                             || l_pallets_IN_SLOT
                             || ' pallet(s) from slot '
                             || i_pals(l_pindex).dest_loc
                             || ' and put on stack.';

                lmg_audit_movement('APIR', g_audit_batch_no, i_e_rec, 1, l_message);
                lmg_audit_movement('RE', g_audit_batch_no, i_e_rec, l_slot_height, '');
                lmg_audit_movement('MEPIR', g_audit_batch_no, i_e_rec, 1, '');
            END IF; /* end audit movement */

			/*
			**  If stack is higher then the slot then raise to stack height
			**  else lower to stack height.  Put pallet on stack.
			**
			**  Since l_pallet_height is the height of the actual pallet,
			**  STD_PALLET_HEIGHT is added to it to get the height of the
			**  top cases on the pallet.
			*/

            IF ( ( l_pallet_height + STD_PALLET_HEIGHT ) > l_slot_height ) THEN
                o_drop := o_drop + i_e_rec.bt90 + ( ( ( ( l_pallet_height + STD_PALLET_HEIGHT ) - l_slot_height ) / 12.0 ) * i_e_rec
                .rl ) + i_e_rec.apos + i_e_rec.ppos + i_e_rec.bp;
            ELSE
                o_drop := o_drop + i_e_rec.bt90 + ( ( ( l_slot_height - ( l_pallet_height + STD_PALLET_HEIGHT ) ) / 12.0 ) * i_e_rec
                .ll ) + i_e_rec.apos + i_e_rec.ppos + i_e_rec.bp;
            END IF; /* end put pallet on stack */

            IF ( g_forklift_audit = TRUE1) THEN
                lmg_audit_movement('BT90', g_audit_batch_no, i_e_rec, 1, '');
                IF ( ( l_pallet_height + STD_PALLET_HEIGHT ) > l_slot_height ) THEN
                    lmg_audit_movement('RL', g_audit_batch_no, i_e_rec,(l_pallet_height + STD_PALLET_HEIGHT) - l_slot_height, '')
                    ;

                ELSE
                    lmg_audit_movement('LL', g_audit_batch_no, i_e_rec, l_slot_height -(l_pallet_height + STD_PALLET_HEIGHT), '')
                    ;
                END IF;

                lmg_audit_movement('APOS', g_audit_batch_no, i_e_rec, 1, '');
                lmg_audit_movement('PPOS', g_audit_batch_no, i_e_rec, 1, '');
                lmg_audit_movement('BP', g_audit_batch_no, i_e_rec, 1, '');
            END IF; /* end audit movement */

			/*
			** At this point the pallets in the slot have been placed on top
			** of the travel stack.
			**
			** The forks are at the top of the top pallet in the original travel
			** stack.  Move forks down to the bottom most pallet going to the
			** slot, pick up stack and place in rack.
			*/

            IF ( ( i_num_pallets - l_num_pallets_to_same_slot ) = 0 ) THEN
				/*
				** Either one pallet in the stack or all the pallets in the stack
				** are going to the slot.  Lower forks to floor and pickup stack.
				** The forks are at the top of the top pallet in the
				** original travel stack.  We distinguish between picking up the
				** stack from the floor and pickup up the stack part way up because
				** these are different operations.
				*/
                o_drop := o_drop + ( ( ( l_pallet_height + STD_PALLET_HEIGHT ) / 12.0 ) * i_e_rec.le ) + i_e_rec.apof + i_e_rec.mepof
                + i_e_rec.bt90 + i_e_rec.apir;

                IF ( g_forklift_audit = TRUE1) THEN
                    l_message := 'Lower forks to floor, pickup stack and place in slot '
                                 || i_pals(l_pindex).dest_loc
                                 || '.';
                    lmg_audit_movement('LE', g_audit_batch_no, i_e_rec, l_pallet_height + STD_PALLET_HEIGHT, l_message);
                    lmg_audit_movement('APOF', g_audit_batch_no, i_e_rec, 1, '');
                    lmg_audit_movement('MEPOF', g_audit_batch_no, i_e_rec, 1, '');
                    lmg_audit_movement('BT90', g_audit_batch_no, i_e_rec, 1, '');
                    lmg_audit_movement('APIR', g_audit_batch_no, i_e_rec, 1, '');
                END IF; /* end audit */

            ELSE
				/*
				** Had more than one pallet in the travel stack and not all were
				** going to the slot.  Lower forks to bottom most pallet in the
				** travel stack going to the slot and pickup stack.
				*/
                o_drop := o_drop + ( ( ( STD_PALLET_HEIGHT * l_num_pallets_to_same_slot ) / 12.0 ) * i_e_rec.le ) + i_e_rec.apos +
                i_e_rec.mepos + i_e_rec.bt90 + i_e_rec.apir;

                IF ( g_forklift_audit = TRUE1) THEN
                    l_message := 'Lower forks to bottom most pallet in the stack going to the slot and pickup the stack '
                                 || i_pals(l_pindex).dest_loc
                                 || '.';
                    lmg_audit_movement('LE', g_audit_batch_no, i_e_rec, STD_PALLET_HEIGHT * l_num_pallets_to_same_slot, l_message
                    );
                    lmg_audit_movement('APOS', g_audit_batch_no, i_e_rec, 1, '');
                    lmg_audit_movement('MEPOS', g_audit_batch_no, i_e_rec, 1, '');
                    lmg_audit_movement('BT90', g_audit_batch_no, i_e_rec, 1, '');
                    lmg_audit_movement('APIR', g_audit_batch_no, i_e_rec, 1, '');
                END IF; /* end audit */

            END IF; /* end move forks down */

			/*
			**  Put stack in rack.
			*/

            l_height_diff := l_slot_height - l_bottom_pallet_height;
            IF ( l_height_diff > 0 ) THEN
                o_drop := o_drop + ( ( l_height_diff / 12.0 ) * i_e_rec.rl ) + i_e_rec.ppir + ( ( l_slot_height / 12.0 ) * i_e_rec
                .le ) + i_e_rec.bt90;
            ELSE
                o_drop := o_drop + ( ( abs(l_height_diff) / 12.0 ) * i_e_rec.ll ) + i_e_rec.ppir + ( ( l_slot_height / 12.0 ) * i_e_rec
                .le ) + i_e_rec.bt90;
            END IF; /* end put stack in rack */

            IF ( g_forklift_audit = TRUE1) THEN
                IF ( l_height_diff >= 0 ) THEN
                    lmg_audit_movement('RL', g_audit_batch_no, i_e_rec, l_height_diff, '');
                ELSE
                    lmg_audit_movement('LL', g_audit_batch_no, i_e_rec, abs(l_height_diff), '');
                END IF; /* end height check */

                lmg_audit_movement('PPIR', g_audit_batch_no, i_e_rec, 1, '');
                lmg_audit_movement('LE', g_audit_batch_no, i_e_rec, l_slot_height, '');
                lmg_audit_movement('BT90', g_audit_batch_no, i_e_rec, 1, '');
            END IF; /* end audit */

        ELSE
		
			/*
			** None of the items in the travel stack exists in the slot.  If
			** all the pallets in the travel stack are going to the slot then
			** place the travel stack on top of the pallets in the slot.
			** If there are pallets in the travel stack not going to the slot
			** then put the travel stack down, pickup the stack of pallets going
			** to the slot and place in the slot.
			*/
            IF ( i_num_pallets = l_num_pallets_to_same_slot ) THEN
				/*
				** Non of items in the travel stack exists in the slot and
				** all the pallets in the travel stack are going to the slot.
				** Put the travel stack in the slot on top of the existing
				** pallets in the slot.
				*/

				/*
				** Calculate the height of the top pallet in the slot.
				*/
                l_height_diff := l_slot_height + ( l_pallets_IN_SLOT * STD_PALLET_HEIGHT );

				/*
				** Place the travel stack in the slot.
				*/
                o_drop := o_drop + i_e_rec.tir + i_e_rec.apir + ( ( l_height_diff / 12.0 ) * i_e_rec.rl ) + i_e_rec.ppir + ( ( l_height_diff
                / 12.0 ) * i_e_rec.le ) + i_e_rec.bt90;

                IF ( g_forklift_audit = TRUE1) THEN
                    l_message := 'The item(s) of the pallet(s) going to the slot do not exist in the slot.  Put the pallet(s) going to the slot on top of the existing pallets in the slot.'
                    ;
                    lmg_audit_cmt(g_audit_batch_no, l_message, -1);
                    IF ( l_num_pallets_to_same_slot = 1 ) THEN
                        l_message := 'One pallet in the stack.  Put pallet '
                                     || i_pals(l_pindex).pallet_id
                                     || ' in slot '
                                     || i_pals(l_pindex).dest_loc
                                     || '.';
                    ELSE
                        l_message := 'Put the stack of '
                                     || l_num_pallets_to_same_slot
                                     || ' pallets in slot '
                                     || i_pals(l_pindex).dest_loc
                                     || '.';
                    END IF; /* end set message */

                    lmg_audit_movement('TIR', g_audit_batch_no, i_e_rec, 1, l_message);
                    lmg_audit_movement('APIR', g_audit_batch_no, i_e_rec, 1, '');
                    lmg_audit_movement('RL', g_audit_batch_no, i_e_rec, l_height_diff, '');
                    lmg_audit_movement('PPIR', g_audit_batch_no, i_e_rec, 1, '');
                    lmg_audit_movement('LE', g_audit_batch_no, i_e_rec, l_height_diff, '');
                    lmg_audit_movement('BT90', g_audit_batch_no, i_e_rec, 1, '');
                END IF; /* end audit */

            ELSE
				/*
				** None of the items in the travel stack exists in the slot and
				** not all the pallets in the travel stack are going to the slot.
				** Put the travel stack down, pickup the stack of pallets going
				** to the slot and place in the slot on top of the existing
				** pallets.
				*/
                o_drop := i_e_rec.ppof + i_e_rec.bp + i_e_rec.apos + ( ( l_bottom_pallet_height / 12.0 ) * i_e_rec.re ) + i_e_rec
                .mepos;

                IF ( g_forklift_audit = TRUE1) THEN
                    IF ( l_num_pallets_to_same_slot = 1 ) THEN
                        l_message := 'Remove pallet '
                                     || i_pals(l_pindex).pallet_id
                                     || ' from top of stack.  '
                                     || i_num_pallets
                                     || ' pallets in the stack.';
                    ELSE
                        l_message := 'Remove the '
                                     || l_num_pallets_to_same_slot
                                     || ' pallets going to slot '
                                     || i_pals(l_pindex).dest_loc
                                     || ' from the stack of '
                                     || i_num_pallets
                                     || ' pallets.';
                    END IF; /* end set message */

                    lmg_audit_movement('PPOF', g_audit_batch_no, i_e_rec, 1, l_message);
                    lmg_audit_movement('BP', g_audit_batch_no, i_e_rec, 1, '');
                    lmg_audit_movement('APOS', g_audit_batch_no, i_e_rec, 1, '');
                    lmg_audit_movement('RE', g_audit_batch_no, i_e_rec, l_bottom_pallet_height, '');
                    lmg_audit_movement('MEPOS', g_audit_batch_no, i_e_rec, 1, '');
                END IF; /* end audit */

				/*
				** Have the pallet(s) going to the slot on the forks.  Move up or
				** down and put the pallet(s) in the rack.
				*/

                o_drop := o_drop + i_e_rec.bt90 + i_e_rec.apir;
                l_height_diff := ( l_slot_height + ( l_pallets_IN_SLOT * STD_PALLET_HEIGHT ) ) - l_bottom_pallet_height;
                IF ( l_height_diff >= 0 ) THEN
                    o_drop := o_drop + ( ( l_height_diff / 12.0 ) * i_e_rec.rl );
                ELSE
                    o_drop := o_drop + ( ( ( abs(l_height_diff) ) / 12.0 ) * i_e_rec.ll );
                END IF; /* end height check */

                o_drop := o_drop + i_e_rec.ppir + ( ( ( l_slot_height + ( l_pallets_IN_SLOT * STD_PALLET_HEIGHT ) ) / 12.0 ) * i_e_rec

                .le ) + i_e_rec.bt90;

                IF ( g_forklift_audit = TRUE1) THEN
                    IF ( l_num_pallets_to_same_slot = 1 ) THEN
                        l_message := 'Put pallet '
                                     || i_pals(l_pindex).pallet_id
                                     || ' in slot '
                                     || i_pals(l_pindex).dest_loc
                                     || '.';
                    ELSE
                        l_message := 'Put the stack of '
                                     || l_num_pallets_to_same_slot
                                     || ' pallets in slot '
                                     || i_pals(l_pindex).dest_loc
                                     || '.';
                    END IF; /* end set message */

                    lmg_audit_movement('BT90', g_audit_batch_no, i_e_rec, 1, l_message);
                    lmg_audit_movement('APIR', g_audit_batch_no, i_e_rec, 1, '');
                    IF ( l_height_diff >= 0 ) THEN
                        lmg_audit_movement('RL', g_audit_batch_no, i_e_rec, l_height_diff, '');
                    ELSE
                        lmg_audit_movement('LL', g_audit_batch_no, i_e_rec, abs(l_height_diff), '');
                    END IF; /* end height check */

                    lmg_audit_movement('PPIR', g_audit_batch_no, i_e_rec, 1, '');
                    lmg_audit_movement('LE', g_audit_batch_no, i_e_rec, l_slot_height +(l_pallets_IN_SLOT * STD_PALLET_HEIGHT), ''
                    );

                    lmg_audit_movement('BT90', g_audit_batch_no, i_e_rec, 1, '');
                END IF; /* end audit */

            END IF; /* end None of the items in the travel stack exists in the slot */
        END IF; /* end travel stack item exists in the slot */
		
		/*
		**  If stack remaining, pick it up and go to next destination.
		*/

        IF ( ( i_num_pallets - l_num_pallets_to_same_slot ) > 0 ) THEN
			/*
			** There are pallets still in the travel stack.
			** Pick up stack and go to next destination.
			*/
            lmg_pickup_for_next_dst(i_pals, l_pindex - l_num_pallets_to_same_slot, i_e_rec, o_drop);
        END IF; /* end go not next destination */

        pl_text_log.ins_msg_async('INFO', l_func_name, 'END lmg_drp_non_deep_res_with_qoh', sqlcode, sqlerrm);
    END lmg_drp_non_deep_res_with_qoh; /* end lmg_drp_non_deep_res_with_qoh */

   /*********************************************************************************
**   FUNCTION:
**    lmg_get_pkup_door_to_pt_mvmnt
**   
**   Description:
**      This functions calculates the LM discreet pickup movement for pallets
**      picked up from a door and dropped to drop points.
**
**  PARAMETERS:   
**      i_batch_no - Batch to process.
**      i_e_rec    - Pointer to equipment tmu values.
**      o_pickup   - Pointer to storage to return pickup value.
**
**  RETURN VALUES:
**      None.
**
**        DATE         DESIGNER       COMMENTS
**     01/07/2020      Infosys     Initial version0.0
***********************************************************************************/

    FUNCTION lmg_get_pkup_door_to_pt_mvmnt (
        i_batch_no   IN           batch.batch_no%TYPE,
        i_e_rec      IN           pl_lm_goal_pb.type_lmc_equip_rec,
        io_pickup    IN OUT       NUMBER
    ) RETURN NUMBER AS

        l_func_name      VARCHAR2(60) := 'pl_lm_goaltime.lmg_get_pkup_door_to_pt_mvmnt';
        l_message        VARCHAR2(1024);
        l_ret_val        NUMBER := SWMS_NORMAL;
		/* Pallet ids to
											  use in forklift audit comments. */
        l_drop_pts       l_drop_arr;
        l_drop_sort      l_drop_arr;
        l_pallet_ids     l_pallet_arr;
        l_char_arr       char_arr;
        l_num_pallets    NUMBER;
        l_pallet_count   NUMBER;
        l_temp1          VARCHAR2(30);   /* Used to hold the pallet id or location stripped
							   of trailing spaces for output in forklift
							   audit messages. */
        l_temp2          VARCHAR2(30);   /* Used to hold the pallet id or location stripped
							   of trailing spaces for output in forklift
							   audit messages. */
        l_index          NUMBER;
        l_j_index        NUMBER;
        l_stack1         NUMBER;
        l_stack2         NUMBER;
        CURSOR c_pickup_hauls IS
        SELECT
            b.kvi_to_loc,
            b.ref_no
        FROM
            batch b
        WHERE
            ( ( ( b.parent_batch_no IS NOT NULL )
                AND ( b.parent_batch_no = i_batch_no ) )
              OR ( ( b.parent_batch_no IS NULL )
                   AND ( b.batch_no = i_batch_no ) ) )
        ORDER BY
            b.actl_start_time; /* Note:  Haul batches have the pallet id in the batch.ref_no column. */

    BEGIN
        pl_text_log.ins_msg_async('INFO', l_func_name, 'START lmg_get_pkup_door_to_pt_mvmnt('
                                            || i_batch_no
                                            || ','
                                            || i_e_rec.equip_id
                                            || ')', sqlcode, sqlerrm);

        BEGIN
            OPEN c_pickup_hauls;
        
            FETCH c_pickup_hauls BULK COLLECT INTO
                l_drop_pts,
                l_pallet_ids LIMIT 50;
            IF c_pickup_hauls%rowcount = 0 THEN
                pl_text_log.ins_msg_async('WARN', l_func_name, 'LMG ORACLE No haul batches found for specified haul batch in pickup', sqlcode
                , sqlerrm);
                l_ret_val := RF.STATUS_NO_LM_BATCH_FOUND;
            END IF;

            l_num_pallets := c_pickup_hauls%rowcount;
			CLOSE c_pickup_hauls;
        EXCEPTION
            WHEN OTHERS THEN
                pl_text_log.ins_msg_async('WARN', l_func_name, 'LMG ORACLE Failed to looking for haul batches in pickup', sqlcode, sqlerrm);
                l_ret_val := RF.STATUS_NO_LM_BATCH_FOUND;
				CLOSE c_pickup_hauls;
        END;

        l_pallet_count := 0;
   

        /* Pickup first pallet. */
        io_pickup := io_pickup + i_e_rec.tid + i_e_rec.apof + i_e_rec.mepof + i_e_rec.bt90;

        IF ( g_forklift_audit = TRUE1) THEN
            lmg_audit_cmt(i_batch_no, 'Haul batch.  Pickup pallets and drop at drop points.', -1);
            l_temp1 := l_pallet_ids(1);
            l_message := 'Pickup pallet '
                         || l_temp1
                         || '.';
            lmg_audit_movement('TID', i_batch_no, i_e_rec, 1, l_message);
            lmg_audit_movement('APOF', i_batch_no, i_e_rec, 1, '');
            lmg_audit_movement('MEPOF', i_batch_no, i_e_rec, 1, '');
            lmg_audit_movement('BT90', i_batch_no, i_e_rec, 1, '');
        END IF; /* end audit */

        l_pallet_count := l_pallet_count + 1;
        pl_text_log.ins_msg_async('INFO', l_func_name, 'pickup for haul movement  1st pallet=' || io_pickup, sqlcode, sqlerrm);
        IF ( l_num_pallets >= 2 ) THEN
            /* Add multi pallet pickup */
            /*
            **  Process the 2nd pallet picked up.
            **  If the new path is greater than the old path, then it needs
            **  to be the new bottom pallet.
            **  If the new path equals the old path and the new exp_date is
            **  less than the old exp_date, then it will be the new bottom
            **  pallet.
            */
            IF ( l_drop_pts(2) < l_drop_pts(1) ) THEN
                /*  2nd pallet goes on top of stack */
                io_pickup := io_pickup + i_e_rec.tid + i_e_rec.ppof + i_e_rec.bt90 + i_e_rec.apof + i_e_rec.mepof + i_e_rec.bt90 +
                i_e_rec.apos + ( ( STD_PALLET_HEIGHT / 12.0 ) * i_e_rec.rl ) + i_e_rec.ppos + i_e_rec.bp + ( ( STD_PALLET_HEIGHT /
                12.0 ) * i_e_rec.le ) + i_e_rec.apof + i_e_rec.mepof + i_e_rec.bt90;

                IF ( g_forklift_audit = TRUE1) THEN
                    l_temp1 := l_pallet_ids(2);
                    l_message := 'Pickup second pallet '
                                 || l_temp1
                                 || ', put on top of stack then pickup stack.';
                    lmg_audit_cmt(i_batch_no, l_message, -1);

                    l_temp1 := l_pallet_ids(1);
                    l_message := 'Put pallet '
                                 || l_temp1
                                 || ' down.';
                    lmg_audit_movement('TID', i_batch_no, i_e_rec, 1, l_message);
                    lmg_audit_movement('PPOF', i_batch_no, i_e_rec, 1, '');

                    l_temp1 := l_pallet_ids(2);
                    l_message := 'Pickup pallet '
                                 || l_temp1
                                 || '.';
                    lmg_audit_movement('BT90', i_batch_no, i_e_rec, 1, l_message);
                    lmg_audit_movement('APOF', i_batch_no, i_e_rec, 1, '');
                    lmg_audit_movement('MEPOF', i_batch_no, i_e_rec, 1, '');
                    lmg_audit_movement('BT90', i_batch_no, i_e_rec, 1, '');

                    l_temp1 := l_pallet_ids(1);
                    l_temp2 := l_pallet_ids(2);
                    l_message := 'Put pallet '
                                 || l_temp2
                                 || ' on top of pallet '
                                 || l_temp1
                                 || '';
                    lmg_audit_movement('APOS', i_batch_no, i_e_rec, 1, l_message);
                    lmg_audit_movement('RL', i_batch_no, i_e_rec, STD_PALLET_HEIGHT, '');
                    lmg_audit_movement('PPOS', i_batch_no, i_e_rec, 1, '');
                    lmg_audit_movement('BP', i_batch_no, i_e_rec, 1, '');
                    lmg_audit_movement('LE', i_batch_no, i_e_rec, STD_PALLET_HEIGHT, '');
                    lmg_audit_movement('APOF', i_batch_no, i_e_rec, 1, '');
                    lmg_audit_movement('MEPOF', i_batch_no, i_e_rec, 1, '');
                    lmg_audit_movement('BT90', i_batch_no, i_e_rec, 1, '');
                END IF; /* end audit */

            ELSE
                /* 2nd pallet goes on bottom of stack */
                io_pickup := io_pickup + i_e_rec.tid + i_e_rec.apos + ( ( STD_PALLET_HEIGHT / 12.0 ) * i_e_rec.rl ) + i_e_rec.ppos
                + i_e_rec.bp + ( ( STD_PALLET_HEIGHT / 12.0 ) * i_e_rec.le ) + i_e_rec.apof + i_e_rec.mepof + i_e_rec.bt90;

                IF ( g_forklift_audit = TRUE1) THEN
                    l_temp1 := l_pallet_ids(2);
                    l_message := 'Put second pallet '
                                 || l_temp1
                                 || ' on bottom of stack.';
                    lmg_audit_cmt(i_batch_no, l_message, -1);
                    lmg_audit_movement('TID', i_batch_no, i_e_rec, 1, '');
                    lmg_audit_movement('APOS', i_batch_no, i_e_rec, 1, '');
                    lmg_audit_movement('RL', i_batch_no, i_e_rec, STD_PALLET_HEIGHT, '');
                    lmg_audit_movement('PPOS', i_batch_no, i_e_rec, 1, '');
                    lmg_audit_movement('BP', i_batch_no, i_e_rec, 1, 'Pickup stack');
                    lmg_audit_movement('LE', i_batch_no, i_e_rec, STD_PALLET_HEIGHT, '');
                    lmg_audit_movement('APOF', i_batch_no, i_e_rec, 1, '');
                    lmg_audit_movement('MEPOF', i_batch_no, i_e_rec, 1, '');
                    lmg_audit_movement('BT90', i_batch_no, i_e_rec, 1, '');
                END IF; /* end audit */

            END IF; /* end process the 2nd pallet */

            l_pallet_count := l_pallet_count + 1;
            l_drop_sort := NEW l_drop_arr(NULL);
            IF ( l_drop_pts(1) < l_drop_pts(2) ) THEN
                l_drop_sort(1) := l_drop_pts(1);
                l_drop_pts(1) := l_drop_pts(2);
                l_drop_pts(2) := l_drop_sort(1);
            END IF;
            --qsort(l_drop_pts);

            pl_text_log.ins_msg_async('INFO', l_func_name, 'pickup for haul movement  2nd pallet=' || io_pickup, sqlcode, sqlerrm);

            /*
            ** Process the 3rd pallet onward.
            */
            FOR l_index IN 3..l_pallet_count LOOP
                IF ( l_drop_pts(l_index) > l_drop_pts(1) ) THEN
                    /*
                    ** New pallet goes on bottom of stack
                    ** Add multi pallet pickup
                    */
                    io_pickup := io_pickup + i_e_rec.tid + i_e_rec.apos + ( ( STD_PALLET_HEIGHT / 12.0 ) * i_e_rec.rl ) + i_e_rec
                    .ppos + i_e_rec.bp + ( ( STD_PALLET_HEIGHT / 12.0 ) * i_e_rec.le ) + i_e_rec.apof + i_e_rec.mepof + i_e_rec.bt90
                    ;

                    IF ( g_forklift_audit = TRUE1) THEN
                        l_message := 'Put next pallet '
                                     || l_pallet_ids(l_index)
                                     || ' on bottom of stack.';
                        lmg_audit_cmt(i_batch_no, l_message, -1);
                        l_message := 'Put stack on top of pallet ' || l_pallet_ids(l_index);
                        lmg_audit_movement('TID', i_batch_no, i_e_rec, 1, l_message);
                        lmg_audit_movement('APOS', i_batch_no, i_e_rec, 1, '');
                        lmg_audit_movement('RL', i_batch_no, i_e_rec, STD_PALLET_HEIGHT, '');
                        lmg_audit_movement('PPOS', i_batch_no, i_e_rec, 1, '');
                        lmg_audit_movement('BP', i_batch_no, i_e_rec, 1, '');
                        lmg_audit_movement('LE', i_batch_no, i_e_rec, STD_PALLET_HEIGHT, '');
                        lmg_audit_movement('APOF', i_batch_no, i_e_rec, 1, 'Pickup stack');
                        lmg_audit_movement('MEPOF', i_batch_no, i_e_rec, 1, '');
                        lmg_audit_movement('BT90', i_batch_no, i_e_rec, 1, '');
                    END IF; /* end audit */

                ELSIF ( l_drop_pts(l_index) < l_drop_pts(l_index - 1) ) THEN
                
                    /*
                    ** New pallet goes on top of stack
                    */
                    /* Put stack down for restack and pickup new pallet. */
                    io_pickup := io_pickup + i_e_rec.ppof + i_e_rec.bt90 + i_e_rec.apof + i_e_rec.mepof + i_e_rec.bt90;
                    /*
                    ** Put new pallet on stack and pickup stack.
                    */

                    io_pickup := io_pickup + i_e_rec.tid + i_e_rec.apos + ( ( ( ( l_pallet_count * STD_PALLET_HEIGHT ) ) / 12.0 )

                    * i_e_rec.rl ) + i_e_rec.ppos + i_e_rec.bp + ( ( ( ( l_pallet_count * STD_PALLET_HEIGHT ) ) / 12.0 ) * i_e_rec

                    .le ) + i_e_rec.apof + i_e_rec.mepof + i_e_rec.bt90;

                    IF ( g_forklift_audit = TRUE1) THEN
                        l_message := 'Put next pallet on top of stack.';
                        lmg_audit_cmt(i_batch_no, l_message, -1);
                        l_message := 'Put stack down, pickup new pallet, put on top of stack and pickup stack.';
                        lmg_audit_cmt(i_batch_no, l_message, -1);
                        lmg_audit_movement('PPOF', i_batch_no, i_e_rec, 1, '');
                        lmg_audit_movement('BT90', i_batch_no, i_e_rec, 1, '');
                        lmg_audit_movement('APOF', i_batch_no, i_e_rec, 1, '');
                        lmg_audit_movement('MEPOF', i_batch_no, i_e_rec, 1, '');
                        lmg_audit_movement('BT90', i_batch_no, i_e_rec, 1, '');
                        lmg_audit_movement('TID', i_batch_no, i_e_rec, 1, '');
                        lmg_audit_movement('APOS', i_batch_no, i_e_rec, 1, '');
                        lmg_audit_movement('RL', i_batch_no, i_e_rec, l_pallet_count * STD_PALLET_HEIGHT, '');
                        lmg_audit_movement('PPOS', i_batch_no, i_e_rec, 1, '');
                        lmg_audit_movement('BP', i_batch_no, i_e_rec, 1, '');
                        lmg_audit_movement('LE', i_batch_no, i_e_rec, l_pallet_count * STD_PALLET_HEIGHT, '');
                        lmg_audit_movement('APOF', i_batch_no, i_e_rec, 1, '');
                        lmg_audit_movement('MEPOF', i_batch_no, i_e_rec, 1, '');
                        lmg_audit_movement('BT90', i_batch_no, i_e_rec, 1, '');
                    END IF;

                ELSE
                    /*
                    ** New pallet goes in middle of stack
                    */
                    l_j_index := 0;
                    l_stack1 := 0;
                    l_stack2 := l_pallet_count;
                    FOR l_j_index IN 1..l_index LOOP IF ( l_drop_pts(l_j_index) > l_drop_pts(l_index) ) THEN
                        l_stack1 := l_stack1 + 1;
                        l_stack2 := l_stack2 - 1;
                    ELSE
                        EXIT;
                    END IF;
                    END LOOP;
                    /* Break apart stack */

                    io_pickup := io_pickup + i_e_rec.tid + i_e_rec.ppof + i_e_rec.bp + i_e_rec.apos + ( ( ( ( l_stack1 * STD_PALLET_HEIGHT

                    ) ) / 12.0 ) * i_e_rec.re ) + i_e_rec.mepos + i_e_rec.bp + ( ( ( ( l_stack1 * STD_PALLET_HEIGHT ) ) / 12.0 )

                    * i_e_rec.ll ) + i_e_rec.ppof;

                    IF ( g_forklift_audit = TRUE1) THEN
                        l_message := 'Next pallet goes in middle of stack.  Break apart stack.';
                        lmg_audit_cmt(i_batch_no, l_message, -1);
                        lmg_audit_movement('TID', i_batch_no, i_e_rec, 1, '');
                        lmg_audit_movement('PPOF', i_batch_no, i_e_rec, 1, '');
                        lmg_audit_movement('BP', i_batch_no, i_e_rec, 1, '');
                        lmg_audit_movement('APOS', i_batch_no, i_e_rec, 1, '');
                        lmg_audit_movement('RE', i_batch_no, i_e_rec, l_stack1 * STD_PALLET_HEIGHT, '');
                        lmg_audit_movement('MEPOS', i_batch_no, i_e_rec, 1, '');
                        lmg_audit_movement('BP', i_batch_no, i_e_rec, 1, '');
                        lmg_audit_movement('LL', i_batch_no, i_e_rec, l_stack1 * STD_PALLET_HEIGHT, '');
                        lmg_audit_movement('PPOF', i_batch_no, i_e_rec, 1, '');
                    END IF; /* end audit */

                    /* Pickup new pallet and set on stack one */

                    io_pickup := io_pickup + i_e_rec.bt90 + i_e_rec.apof + i_e_rec.mepof + i_e_rec.bt90 + i_e_rec.apos + ( ( ( (

                    l_stack1 * STD_PALLET_HEIGHT ) ) / 12.0 ) * i_e_rec.rl ) + i_e_rec.ppos + i_e_rec.bp;

                    IF ( g_forklift_audit = TRUE1) THEN
                        l_message := 'Pickup next pallet and set on stack one.';
                        lmg_audit_cmt(i_batch_no, l_message, -1);
                        lmg_audit_movement('BT90', i_batch_no, i_e_rec, 1, '');
                        lmg_audit_movement('APOF', i_batch_no, i_e_rec, 1, '');
                        lmg_audit_movement('MEPOF', i_batch_no, i_e_rec, 1, '');
                        lmg_audit_movement('BT90', i_batch_no, i_e_rec, 1, '');
                        lmg_audit_movement('APOS', i_batch_no, i_e_rec, 1, '');
                        lmg_audit_movement('RL', i_batch_no, i_e_rec, l_stack1 * STD_PALLET_HEIGHT, '');
                        lmg_audit_movement('PPOS', i_batch_no, i_e_rec, 1, '');
                        lmg_audit_movement('BP', i_batch_no, i_e_rec, 1, '');
                    END IF; /* end audit movement */

                    /* Restack */

                    io_pickup := io_pickup + ( ( ( ( l_stack1 * STD_PALLET_HEIGHT ) ) / 12.0 ) * i_e_rec.le ) + i_e_rec.apof + i_e_rec

                    .mepof + i_e_rec.bp + i_e_rec.apos + ( ( ( ( ( l_stack1 + 1 ) * STD_PALLET_HEIGHT ) ) / 12.0 ) * i_e_rec.rl )

                    + i_e_rec.ppos + i_e_rec.bp;

                    IF ( g_forklift_audit = TRUE1) THEN
                        l_message := 'Restack.';
                        lmg_audit_cmt(i_batch_no, l_message, -1);
                        lmg_audit_movement('LE', i_batch_no, i_e_rec, l_stack1 * STD_PALLET_HEIGHT, '');
                        lmg_audit_movement('APOF', i_batch_no, i_e_rec, 1, '');
                        lmg_audit_movement('MEPOF', i_batch_no, i_e_rec, 1, '');
                        lmg_audit_movement('BP', i_batch_no, i_e_rec, 1, '');
                        lmg_audit_movement('APOS', i_batch_no, i_e_rec, 1, '');
                        lmg_audit_movement('RL', i_batch_no, i_e_rec,(l_stack1 + 1) * STD_PALLET_HEIGHT, '');

                        lmg_audit_movement('PPOS', i_batch_no, i_e_rec, 1, '');
                        lmg_audit_movement('BP', i_batch_no, i_e_rec, 1, '');
                    END IF; /* end audit */

                    /* Pickup and stack and leave */

                    io_pickup := io_pickup + ( ( ( ( ( l_stack1 + 1 ) * STD_PALLET_HEIGHT ) ) / 12.0 ) * i_e_rec.le ) + i_e_rec.

                    apof + i_e_rec.mepof + i_e_rec.bt90;

                    IF ( g_forklift_audit = TRUE1) THEN
                        l_message := 'Pickup stack.';
                        lmg_audit_cmt(i_batch_no, l_message, -1);
                        lmg_audit_movement('LE', i_batch_no, i_e_rec,(l_stack1 + 1) * STD_PALLET_HEIGHT, '');

                        lmg_audit_movement('APOF', i_batch_no, i_e_rec, 1, '');
                        lmg_audit_movement('MEPOF', i_batch_no, i_e_rec, 1, '');
                        lmg_audit_movement('BT90', i_batch_no, i_e_rec, 1, '');
                    END IF; /* end audit */

                END IF; /* end process 3rd pallet onward */

                l_pallet_count := l_pallet_count + 1;
                FOR l_sort_index IN 3..l_pallet_count LOOP 
				IF ( l_drop_pts(l_sort_index - 1) < l_drop_pts(l_sort_index) ) THEN
                    l_drop_sort(1) := l_drop_pts(l_sort_index - 1);
                    l_drop_pts(l_sort_index - 1) := l_drop_pts(l_sort_index);
                    l_drop_pts(l_sort_index) := l_drop_sort(1);
                END IF;
                END LOOP;
                --qsort(l_drop_pts);

                pl_text_log.ins_msg_async('INFO', l_func_name, 'pickup for haul movement  next pallet=' || io_pickup, sqlcode, sqlerrm);
            END LOOP;  /* end 3rd pallet onward for loop */

        END IF; /* end add multi pallet pickup */

        pl_text_log.ins_msg_async('INFO', l_func_name, 'END lmg_get_pkup_door_to_pt_mvmnt', sqlcode, sqlerrm);
        RETURN l_ret_val;
    END lmg_get_pkup_door_to_pt_mvmnt; /* end lmg_get_pkup_door_to_pt_mvmnt */

/*********************************************************************************
**   FUNCTION:
**    lmg_get_pkup_dr_to_slt_mvmnt
**   
**   Description:
**      This functions calculates the LM discreet pickup movement for pallets
**      picked up from a door or a drop point and dropped to the destination
**      location.
**
**      The batches type handled are:
**         - FP batches (putaways) and child HL hauls
**         - H batches (HP hauls and HX hauls and HL hauls)
**
**  PARAMETERS:   
**      i_batch_no - Batch to process.
**      i_e_rec    - Pointer to equipment tmu values.
**      io_pickup  - Pointer to storage to return pickup value.
**
**  RETURN VALUES:
**      None.
**
**        DATE         DESIGNER       COMMENTS
**     01/07/2020      Infosys     Initial version0.0
***********************************************************************************/

    FUNCTION lmg_get_pkup_dr_to_slt_mvmnt (
        i_batch_no   IN           batch.batch_no%TYPE,
        i_e_rec      IN           pl_lm_goal_pb.type_lmc_equip_rec,
        io_pickup    IN OUT       NUMBER
    ) RETURN NUMBER AS

        l_func_name                       VARCHAR2(60) := 'pl_lm_goaltime.lmg_get_pkup_dr_to_slt_mvmnt';
        l_message                         VARCHAR2(1024);
        l_ret_val                         NUMBER := SWMS_NORMAL;
        l_give_stack_on_dock_time         NUMBER := TRUE1;
        TYPE l_actl_start_time_arr IS
            VARRAY(50) OF VARCHAR2(25); --2021/01/07 lwee1503 hardcoded lengths to support oracle 11g
        TYPE l_putpaths_arr IS
            VARRAY(50) OF NUMBER; --2021/01/07 lwee1503 hardcoded lengths to support oracle 11g
        TYPE l_expdates_arr IS
            VARRAY(50) OF NUMBER; --2021/01/07 lwee1503 hardcoded lengths to support oracle 11g
        TYPE l_ignore_batch_flag_arr IS
            VARRAY(50) OF VARCHAR2(1); --2021/01/07 lwee1503 hardcoded lengths to support oracle 11g
        TYPE l_palletids_arr IS
            VARRAY(50) OF VARCHAR2(40); --2021/01/07 lwee1503 hardcoded lengths to support oracle 11g
        TYPE l_palletids_sort_arr IS
            VARRAY(50) OF VARCHAR2(40); --2021/01/07 lwee1503 hardcoded lengths to support oracle 11g
        TYPE l_src_locs_arr IS
            VARRAY(50) OF VARCHAR2(10); --2021/01/07 lwee1503 hardcoded lengths to support oracle 11g
        TYPE l_msku_batch_flag_arr IS
            VARRAY(50) OF VARCHAR2(1); --2021/01/07 lwee1503 hardcoded lengths to support oracle 11g
        TYPE l_drop_for_brk_away_flg_arr IS
            VARRAY(50) OF VARCHAR2(1); --2021/01/07 lwee1503 hardcoded lengths to support oracle 11g
        TYPE l_resume_brk_away_flg_arr IS
            VARRAY(50) OF VARCHAR2(1); --2021/01/07 lwee1503 hardcoded lengths to support oracle 11g
        l_actl_start_time                 l_actl_start_time_arr;
        l_putpaths                        l_putpaths_arr;
        l_expdates                        l_expdates_arr;
        l_palletids                       l_palletids_arr;
        l_src_locs                        l_src_locs_arr;
        l_msku_batch_flag                 l_msku_batch_flag_arr;
        l_palletids_sort                  l_palletids_sort_arr;
        l_ignore_batch_flag               l_ignore_batch_flag_arr;
        l_dropped_for_break_away_flg   l_drop_for_brk_away_flg_arr;
        l_resumed_break_away_flg   l_resume_brk_away_flg_arr;
        l_ref_no_len                      NUMBER := 40;
        l_put_pkups                       putaway_pickup_obj:=putaway_pickup_obj(
                                        putaway_pickup_table(putaway_pickup_rec('0', '0', NULL, NULL, ' ', NULL, ' ', ' ', ' ')));
        l_put_pkups_sort                  putaway_pickup_obj:=putaway_pickup_obj(
                                        putaway_pickup_table(putaway_pickup_rec('0', '0', NULL, NULL, ' ', NULL, ' ', ' ', ' ')));
        l_index                           NUMBER;
        l_second_index                    NUMBER;
        l_temp_count                      NUMBER;
        l_pallet_count                    NUMBER;
        l_stack1                          NUMBER;
        l_stack2                          NUMBER;
        l_num_pallets                     NUMBER;
        l_sort_index                      NUMBER;
        CURSOR c_pickup_putaways IS
        SELECT
            TO_CHAR(b.actl_start_time, 'YYYYMMDDHH24MISS'),
            l.put_path put_path,
            to_number(TO_CHAR(nvl(t.exp_date, SYSDATE), 'YYYYMMDD')),
            b.ref_no,
                      -- NVL(t.src_loc, '?'),  07/06/10 Brian Bent
                      --                   We want the batch kvi_from_loc
            nvl(b.kvi_from_loc, '?'),
            nvl(b.msku_batch_flag, 'N') msku_batch_flag,
            lpad(b.ref_no, l_ref_no_len) pallet_id_sort,
            DECODE(substr(b.batch_no, 1, 1), 'T', 'Y', 'N') ignore_batch_flag,
            nvl(b.dropped_for_a_break_away_flag, 'N') dropped_for_a_break_away_flag,
            nvl(b.resumed_after_break_away_flag, 'N') resumed_after_break_away_flag
        FROM
            trans   t,
            loc     l,
            batch   b
        WHERE
            t.trans_type IN ('PUT', 'TRP', 'MIS', 'PUX')
            AND t.pallet_id = b.ref_no
            AND t.labor_batch_no = b.batch_no
            AND ( nvl(b.msku_batch_flag, 'N') != 'Y'
                  OR ( nvl(b.msku_batch_flag, 'N') = 'Y'
                       AND l.perm = 'Y' ) )
            AND l.logi_loc = b.kvi_to_loc
            AND ( substr(i_batch_no, 1, 2) IN (
                'FP'
            )
                  OR substr(i_batch_no, 1, 1) = 'T' )
            AND ( ( ( b.parent_batch_no IS NOT NULL )
                    AND ( b.parent_batch_no = i_batch_no ) )
                  OR ( ( b.parent_batch_no IS NULL )
                       AND ( b.batch_no = i_batch_no ) ) )
        UNION
              --
              -- Haul batches
              -- 02/19/02 prpbcb Added UNION
              --
        SELECT
            TO_CHAR(b.actl_start_time, 'YYYYMMDDHH24MISS'),
            0 put_path,
            to_number(TO_CHAR(SYSDATE, 'YYYYMMDD')),
            b.ref_no,
            nvl(b.kvi_from_loc, '?'),
            nvl(b.msku_batch_flag, 'N') msku_batch_flag,
            lpad(b.ref_no, l_ref_no_len) pallet_id_sort,
            DECODE(substr(b.batch_no, 1, 1), 'T', 'Y', 'N') ignore_batch_flag,
            nvl(b.dropped_for_a_break_away_flag, 'N') dropped_for_a_break_away_flag,
            nvl(b.resumed_after_break_away_flag, 'N') resumed_after_break_away_flag
        FROM
            batch b
        WHERE
            substr(b.batch_no, 1, 1) = 'H'
            AND ( ( ( b.parent_batch_no IS NOT NULL )
                    AND ( b.parent_batch_no = i_batch_no ) )
                  OR ( ( b.parent_batch_no IS NULL )
                       AND ( b.batch_no = i_batch_no ) ) )
        UNION
             --
             -- 11/05/03 prpbcb Added UNION  MSKU changes
             -- Get the MSKU batch going to the
             -- reserve/floating slot.
             --
        SELECT
            TO_CHAR(b.actl_start_time, 'YYYYMMDDHH24MISS'),
            0 put_path,
            to_number(TO_CHAR(SYSDATE, 'YYYYMMDD')),
            b.ref_no,
            nvl(b.kvi_from_loc, '?'),
            b.msku_batch_flag,
            lpad(b.ref_no, l_ref_no_len) pallet_id_sort,
            DECODE(substr(b.batch_no, 1, 1), 'T', 'Y', 'N') ignore_batch_flag,
            nvl(b.dropped_for_a_break_away_flag, 'N') dropped_for_a_break_away_flag,
            nvl(b.resumed_after_break_away_flag, 'N') resumed_after_break_away_flag
        FROM
            loc     l,
            batch   b
        WHERE
            ( substr(i_batch_no, 1, 2) IN (
                'FP'
            )
              OR substr(i_batch_no, 1, 1) = 'T' )
            AND b.msku_batch_flag = 'Y'
            AND l.logi_loc = b.kvi_to_loc
            AND l.perm != 'Y'
            AND ( ( ( b.parent_batch_no IS NOT NULL )
                    AND ( b.parent_batch_no = i_batch_no ) )
                  OR ( ( b.parent_batch_no IS NULL )
                       AND ( b.batch_no = i_batch_no ) ) )
        ORDER BY
            1;

    BEGIN
        pl_text_log.ins_msg_async('INFO', l_func_name, 'START lmg_get_pkup_dr_to_slt_mvmnt('
                                            || i_batch_no
                                            || ','
                                            || i_e_rec.equip_id
                                            || ')', sqlcode, sqlerrm);
	
		/* Determine if stack on dock time is to begin given. */

        lmg_sel_stack_on_dock_syspar(l_give_stack_on_dock_time);
        BEGIN
            OPEN c_pickup_putaways;
      
       
            FETCH c_pickup_putaways BULK COLLECT INTO
                l_actl_start_time,
                l_putpaths,
                l_expdates,
                l_palletids,
                l_src_locs,
                l_msku_batch_flag,
                l_palletids_sort,
                l_ignore_batch_flag,
                l_dropped_for_break_away_flg,
                l_resumed_break_away_flg LIMIT 50;

            IF c_pickup_putaways%notfound AND c_pickup_putaways%rowcount = 0 THEN
                pl_text_log.ins_msg_async('WARN', l_func_name, 'LMG ORACLE No putaway batches or haul batches or PUT trans found for pickup'
                , sqlcode, sqlerrm);
                l_ret_val := RF.STATUS_NO_LM_BATCH_FOUND;
            ELSE

        
        l_pallet_count := 0;
        l_num_pallets := c_pickup_putaways%rowcount;
        
            CLOSE c_pickup_putaways;
     
        pl_text_log.ins_msg_async('INFO', l_func_name, 'l_num_pallets=' || l_num_pallets, sqlcode, sqlerrm);
        BEGIN
            SELECT
                COUNT(*)
            INTO l_temp_count
            FROM
                batch
            WHERE
                parent_batch_no = i_batch_no;

        END;
        pl_text_log.ins_msg_async('INFO', l_func_name, 'l_temp_count=' || l_temp_count, sqlcode, sqlerrm);
        			
		/* Move Oracle information to structure to pass to qsort. */
        --l_put_pkups :=  putaway_pickup_obj('0', '0', NULL, NULL, ' ', NULL, ' ', ' ', ' ');

       -- l_put_pkups_sort :=  putaway_pickup_obj(NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL);

        FOR l_index IN 1..l_num_pallets LOOP
            l_put_pkups.result_table.extend;
            l_put_pkups.result_table(l_index) := putaway_pickup_rec(l_putpaths(l_index), l_expdates(l_index), l_palletids(l_index), l_src_locs
            (l_index), l_msku_batch_flag(l_index), l_palletids_sort(l_index), l_ignore_batch_flag(l_index), l_dropped_for_break_away_flg
            (l_index), l_resumed_break_away_flg(l_index));

        END LOOP; /* end of for loop */

		/*
		** First pallet pickup.
		**
		** If resumed_after_break_away_flag is Y for the first pallet then
		** this is interpreted as the operator resuming the batches after a
		** break away.  Time is given to pickup the travel stack.  No time is
		** given to stack the pallets  (if there are merges) since the pallets
		** should be sitting in a stack on the floor.
		** NOTE:  In a merged batch we should not have the situation where
		**        resumed_after_break_away_flag is Y in the BATCH table for
		**        some batches and N (or null) for others.
		*/

        IF ( l_resumed_break_away_flg(1) = 'N' ) THEN
			
				/*
				** This is not a batch resumed after a break away.
				*/
            IF ( l_give_stack_on_dock_time = TRUE1 ) THEN
                io_pickup := i_e_rec.tid + i_e_rec.apof + i_e_rec.mepof + i_e_rec.bt90;
            END IF; /* end l_give_stack_on_dock_time check */

            IF ( g_forklift_audit = TRUE1) THEN
                IF ( NOT ( l_give_stack_on_dock_time = TRUE1 ) ) THEN
                    lmg_audit_cmt(i_batch_no, q'(Syspar "Give Stack on Dock Time" is set to N so time will not be given to pickup and stack the pallets on the dock.)'
                    , -1);
                END IF; /* end audit comment */

                IF ( l_msku_batch_flag(1) = 'Y' ) THEN
                    l_message := 'Pickup MSKU pallet at '
                                 || l_src_locs(1)
                                 || '.';
                ELSE
                    l_message := 'Pickup pallet '
                                 || l_palletids(1)
                                 || ' at '
                                 || l_src_locs(1)
                                 || '.';
                END IF; /* end message set */

                lmg_audit_movement('TID', i_batch_no, i_e_rec, apply_freq(1, l_give_stack_on_dock_time), l_message);
                lmg_audit_movement('APOF', i_batch_no, i_e_rec, apply_freq(1, l_give_stack_on_dock_time), '');
                lmg_audit_movement('MEPOF', i_batch_no, i_e_rec, apply_freq(1, l_give_stack_on_dock_time), '');
                lmg_audit_movement('BT90', i_batch_no, i_e_rec, apply_freq(1, l_give_stack_on_dock_time), '');
            END IF; /* end audit */

        ELSE
				/*
				** This is a batch resumed after a break away.
				** Give time to pickup the travel stack.
				*/
            io_pickup := i_e_rec.apof + i_e_rec.mepof + i_e_rec.bt90;
            IF ( g_forklift_audit = TRUE1) THEN
                l_message := 'This is a batch started after a break away. Time is given to pickup the stack of '
                             || l_num_pallets
                             || ' pallet(s) that was placed by location '
                             || l_src_locs(1)
                             || ' before the break away.';

                lmg_audit_cmt(i_batch_no, l_message, -1);
                lmg_audit_movement('APOF', i_batch_no, i_e_rec, apply_freq(1, l_give_stack_on_dock_time), '');
                lmg_audit_movement('MEPOF', i_batch_no, i_e_rec, apply_freq(1, l_give_stack_on_dock_time), '');
                lmg_audit_movement('BT90', i_batch_no, i_e_rec, apply_freq(1, l_give_stack_on_dock_time), '');
            END IF; /* end audit */

        END IF; /* end resumed_after_break_away_flag check */

        l_pallet_count := l_pallet_count + 1;   /* One pallet processed */
        pl_text_log.ins_msg_async('INFO', l_func_name, 'pickup_movement 1st pallet=' || io_pickup, sqlcode, sqlerrm);

			/*
			** Process the additional pallets picked up at the door or haul drop
			** point except for the following:
			**    - If it was a MSKU pallet in which case there is only one
			**      physical pallet to pick up.
			**    - If the first pallet picked up was a resume after a break away
			**      in which case the operator was given time to pickup the travel
			**      stack in one operation when the 1st pallet was processed above.
			*/
        IF ( ( l_num_pallets >= 2 ) AND ( l_msku_batch_flag(1) != 'Y' ) AND ( l_resumed_break_away_flg(1) != 'Y' ) ) THEN
				/*
				**  Process the 2nd pallet picked up.
				**  If the new path is greater than the old path, then it needs
				**  to be the new bottom pallet.
				**  If the new path equals the old path and the new exp_date is
				**  less than the old exp_date, then it will be the new bottom
				**  pallet.
				*/
            IF ( ( l_put_pkups.result_table(2).put_path < l_put_pkups.result_table(1).put_path ) OR ( ( l_put_pkups.result_table(2).put_path = l_put_pkups.result_table(1).put_path )
            AND ( l_put_pkups.result_table(2).exp_date > l_put_pkups.result_table(1).exp_date ) ) OR ( ( l_put_pkups.result_table(2).put_path = l_put_pkups.result_table(1).put_path )
            AND ( l_put_pkups.result_table(2).exp_date = l_put_pkups.result_table(1).exp_date ) AND ( l_put_pkups.result_table(2).pallet_id_sort > l_put_pkups.result_table(1).pallet_id_sort
            ) ) ) THEN
					/* 2nd pallet goes on top of stack */
                IF ( l_give_stack_on_dock_time = TRUE1 ) THEN
                    io_pickup := io_pickup + i_e_rec.tid + i_e_rec.ppof + i_e_rec.bt90 + i_e_rec.apof + i_e_rec.mepof + i_e_rec.bt90
                    + i_e_rec.apos + ( ( STD_PALLET_HEIGHT / 12.0 ) * i_e_rec.rl ) + i_e_rec.ppos + i_e_rec.bp + ( ( STD_PALLET_HEIGHT
                    / 12.0 ) * i_e_rec.le ) + i_e_rec.apof + i_e_rec.mepof + i_e_rec.bt90;
                END IF; /* end l_give_stack_on_dock_time check */

                IF ( g_forklift_audit = TRUE1) THEN
                    l_message := 'Pickup pallet '
                                 || l_palletids(2)
                                 || ' at '
                                 || l_src_locs(2)
                                 || ' and put on top of stack.';

                    lmg_audit_movement('TID', i_batch_no, i_e_rec, apply_freq(1, l_give_stack_on_dock_time), l_message);
                    lmg_audit_movement('PPOF', i_batch_no, i_e_rec, apply_freq(1, l_give_stack_on_dock_time), '');
                    lmg_audit_movement('BT90', i_batch_no, i_e_rec, apply_freq(1, l_give_stack_on_dock_time), '');
                    lmg_audit_movement('APOF', i_batch_no, i_e_rec, apply_freq(1, l_give_stack_on_dock_time), '');
                    lmg_audit_movement('MEPOF', i_batch_no, i_e_rec, apply_freq(1, l_give_stack_on_dock_time), '');
                    lmg_audit_movement('BT90', i_batch_no, i_e_rec, apply_freq(1, l_give_stack_on_dock_time), '');
                    lmg_audit_movement('APOS', i_batch_no, i_e_rec, apply_freq(1, l_give_stack_on_dock_time), '');
                    lmg_audit_movement('RL', i_batch_no, i_e_rec, apply_freq(STD_PALLET_HEIGHT, l_give_stack_on_dock_time), '');
                    lmg_audit_movement('PPOS', i_batch_no, i_e_rec, apply_freq(1, l_give_stack_on_dock_time), '');
                    lmg_audit_movement('BP', i_batch_no, i_e_rec, apply_freq(1, l_give_stack_on_dock_time), '');
                    lmg_audit_movement('LE', i_batch_no, i_e_rec, apply_freq(STD_PALLET_HEIGHT, l_give_stack_on_dock_time), '');
                    lmg_audit_movement('APOF', i_batch_no, i_e_rec, apply_freq(1, l_give_stack_on_dock_time), '');
                    lmg_audit_movement('MEPOF', i_batch_no, i_e_rec, apply_freq(1, l_give_stack_on_dock_time), '');
                    lmg_audit_movement('BT90', i_batch_no, i_e_rec, apply_freq(1, l_give_stack_on_dock_time), '');
                END IF; /* end audit */

            ELSE
					/* 2nd pallet goes on bottom of stack */
                IF ( l_give_stack_on_dock_time = TRUE1 ) THEN
                    io_pickup := io_pickup + i_e_rec.tid + i_e_rec.apos + ( ( STD_PALLET_HEIGHT / 12.0 ) * i_e_rec.rl ) + i_e_rec
                    .ppos + i_e_rec.bp + ( ( STD_PALLET_HEIGHT / 12.0 ) * i_e_rec.le ) + i_e_rec.apof + i_e_rec.mepof + i_e_rec.bt90
                    ;
                END IF;

                IF ( g_forklift_audit = TRUE1) THEN
                    l_message := 'Pickup pallet '
                                 || l_palletids(2)
                                 || ' at '
                                 || l_src_locs(2)
                                 || ' and put on bottom of stack.';

                    lmg_audit_movement('TID', i_batch_no, i_e_rec, apply_freq(1, l_give_stack_on_dock_time), l_message);
                    lmg_audit_movement('APOS', i_batch_no, i_e_rec, apply_freq(1, l_give_stack_on_dock_time), '');
                    lmg_audit_movement('RL', i_batch_no, i_e_rec, apply_freq(STD_PALLET_HEIGHT, l_give_stack_on_dock_time), '');
                    lmg_audit_movement('PPOS', i_batch_no, i_e_rec, apply_freq(1, l_give_stack_on_dock_time), '');
                    lmg_audit_movement('BP', i_batch_no, i_e_rec, apply_freq(1, l_give_stack_on_dock_time), '');
                    lmg_audit_movement('LE', i_batch_no, i_e_rec, apply_freq(STD_PALLET_HEIGHT, l_give_stack_on_dock_time), '');
                    lmg_audit_movement('APOF', i_batch_no, i_e_rec, apply_freq(1, l_give_stack_on_dock_time), '');
                    lmg_audit_movement('MEPOF', i_batch_no, i_e_rec, apply_freq(1, l_give_stack_on_dock_time), '');
                    lmg_audit_movement('BT90', i_batch_no, i_e_rec, apply_freq(1, l_give_stack_on_dock_time), '');
                END IF; /* end audit */

            END IF;

            l_pallet_count := l_pallet_count + 1;
            IF ( l_put_pkups.result_table(1).put_path < l_put_pkups.result_table(2).put_path ) THEN
                l_put_pkups_sort.result_table(1) := l_put_pkups.result_table(1);
                l_put_pkups.result_table(1) := l_put_pkups.result_table(2);
                l_put_pkups.result_table(2) := l_put_pkups_sort.result_table(1);
				/* Pallets going to same location. */
            ELSIF ( l_put_pkups.result_table(1).exp_date < l_put_pkups.result_table(2).exp_date ) THEN
                l_put_pkups_sort.result_table(1) := l_put_pkups.result_table(1);
                l_put_pkups.result_table(1) := l_put_pkups.result_table(2);
                l_put_pkups.result_table(2) := l_put_pkups_sort.result_table(1);
				/* Pallets going to same location and have same expiration date. */
            ELSIF ( l_put_pkups.result_table(1).pallet_id_sort < l_put_pkups.result_table(2).pallet_id_sort ) THEN
                l_put_pkups_sort.result_table(1) := l_put_pkups.result_table(1);
                l_put_pkups.result_table(1) := l_put_pkups.result_table(2);
                l_put_pkups.result_table(2) := l_put_pkups_sort.result_table(1);
            END IF;
				
				--qsort(l_put_pkups);

            pl_text_log.ins_msg_async('INFO', l_func_name, 'pickup_movement 2nd pallet=' || io_pickup, sqlcode, sqlerrm);

				/* Process the 3rd pallet onward. */
            FOR l_index IN 3..l_num_pallets LOOP
                IF ( ( l_put_pkups.result_table(l_index).put_path > l_put_pkups.result_table(1).put_path ) OR ( ( l_put_pkups.result_table(l_index).put_path = l_put_pkups
                .result_table(1).put_path ) AND ( l_put_pkups.result_table(l_index).exp_date < l_put_pkups.result_table(1).exp_date ) ) OR ( ( l_put_pkups.result_table(l_index).put_path
                = l_put_pkups.result_table(1).put_path ) AND ( l_put_pkups.result_table(l_index).exp_date = l_put_pkups.result_table(1).exp_date ) AND ( l_put_pkups.result_table(l_index
                ).pallet_id_sort < l_put_pkups.result_table(1).pallet_id_sort ) ) ) THEN
						/*
						** Add multi pallet pickup 
						** 
						** New pallet goes on bottom of stack
						*/
                    IF ( l_give_stack_on_dock_time = TRUE1 ) THEN
                        io_pickup := io_pickup + i_e_rec.tid + i_e_rec.apos + ( ( STD_PALLET_HEIGHT / 12.0 ) * i_e_rec.rl ) + i_e_rec
                        .ppos + i_e_rec.bp + ( ( STD_PALLET_HEIGHT / 12.0 ) * i_e_rec.le ) + i_e_rec.apof + i_e_rec.mepof + i_e_rec
                        .bt90;
                    END IF;

                    IF ( g_forklift_audit = TRUE1) THEN
                        l_message := 'Pickup pallet '
                                     || l_palletids(l_index)
                                     || ' at '
                                     || l_src_locs(l_index)
                                     || ' and put on bottom of stack.';

                        lmg_audit_movement('TID', i_batch_no, i_e_rec, apply_freq(1, l_give_stack_on_dock_time), l_message);
                        lmg_audit_movement('APOS', i_batch_no, i_e_rec, apply_freq(1, l_give_stack_on_dock_time), '');
                        lmg_audit_movement('RL', i_batch_no, i_e_rec, apply_freq(STD_PALLET_HEIGHT, l_give_stack_on_dock_time), ''
                        );
                        lmg_audit_movement('PPOS', i_batch_no, i_e_rec, apply_freq(1, l_give_stack_on_dock_time), '');
                        lmg_audit_movement('BP', i_batch_no, i_e_rec, apply_freq(1, l_give_stack_on_dock_time), '');
                        lmg_audit_movement('LE', i_batch_no, i_e_rec, apply_freq(STD_PALLET_HEIGHT, l_give_stack_on_dock_time), ''
                        );
                        lmg_audit_movement('APOF', i_batch_no, i_e_rec, apply_freq(1, l_give_stack_on_dock_time), '');
                        lmg_audit_movement('MEPOF', i_batch_no, i_e_rec, apply_freq(1, l_give_stack_on_dock_time), '');
                        lmg_audit_movement('BT90', i_batch_no, i_e_rec, apply_freq(1, l_give_stack_on_dock_time), '');
                    END IF; /* end audit */

                ELSIF ( ( l_put_pkups.result_table(l_index).put_path < l_put_pkups.result_table(l_index - 1).put_path ) OR ( ( l_put_pkups.result_table(l_index).put_path

                = l_put_pkups.result_table(l_index - 1).put_path ) AND ( l_put_pkups.result_table(l_index).exp_date > l_put_pkups.result_table(l_index - 1).exp_date ) )

                OR ( ( l_put_pkups.result_table(l_index).put_path = l_put_pkups.result_table(l_index - 1).put_path ) AND ( l_put_pkups.result_table(l_index).exp_date =

                l_put_pkups.result_table(l_index - 1).exp_date ) AND ( l_put_pkups.result_table(l_index).pallet_id_sort > l_put_pkups.result_table(l_index - 1).pallet_id_sort

                ) ) ) THEN
						/*
						** New pallet goes on top of stack
						**
						** Put stack down for restack and pickup new pallet.
						*/
                    IF ( l_give_stack_on_dock_time = TRUE1 ) THEN
                        io_pickup := io_pickup + i_e_rec.ppof + i_e_rec.bt90 + i_e_rec.apof + i_e_rec.mepof + i_e_rec.bt90;

							/*
							** Put new pallet on stack and pickup stack.
							*/

                        io_pickup := io_pickup + i_e_rec.tid + i_e_rec.apos + ( ( ( l_pallet_count * STD_PALLET_HEIGHT ) / 12.0 )

                        * i_e_rec.rl ) + i_e_rec.ppos + i_e_rec.bp + ( ( ( l_pallet_count * STD_PALLET_HEIGHT ) / 12.0 ) * i_e_rec

                        .le ) + i_e_rec.apof + i_e_rec.mepof + i_e_rec.bt90;

                    END IF; /* end l_give_stack_on_dock_time check */

                    IF ( g_forklift_audit = TRUE1) THEN
                        l_message := 'Pickup pallet '
                                     || l_palletids(l_index)
                                     || ' at '
                                     || l_src_locs(l_index)
                                     || ' and put on top of the stack.  Put stack down, pickup new pallet, put on top of stack and pickup stack.'
                                     ;

                        lmg_audit_cmt(g_audit_batch_no, l_message, -1);
                        lmg_audit_movement('PPOF', i_batch_no, i_e_rec, apply_freq(1, l_give_stack_on_dock_time), '');
                        lmg_audit_movement('BT90', i_batch_no, i_e_rec, apply_freq(1, l_give_stack_on_dock_time), '');
                        lmg_audit_movement('APOF', i_batch_no, i_e_rec, apply_freq(1, l_give_stack_on_dock_time), '');
                        lmg_audit_movement('MEPOF', i_batch_no, i_e_rec, apply_freq(1, l_give_stack_on_dock_time), '');
                        lmg_audit_movement('BT90', i_batch_no, i_e_rec, apply_freq(1, l_give_stack_on_dock_time), '');
                        lmg_audit_movement('TID', i_batch_no, i_e_rec, apply_freq(1, l_give_stack_on_dock_time), '');
                        lmg_audit_movement('APOS', i_batch_no, i_e_rec, apply_freq(1, l_give_stack_on_dock_time), '');
                        lmg_audit_movement('RL', i_batch_no, i_e_rec, apply_freq(l_pallet_count * STD_PALLET_HEIGHT, l_give_stack_on_dock_time
                        ), '');

                        lmg_audit_movement('PPOS', i_batch_no, i_e_rec, apply_freq(1, l_give_stack_on_dock_time), '');
                        lmg_audit_movement('BP', i_batch_no, i_e_rec, apply_freq(1, l_give_stack_on_dock_time), '');
                        lmg_audit_movement('LE', i_batch_no, i_e_rec, apply_freq(l_pallet_count * STD_PALLET_HEIGHT, l_give_stack_on_dock_time
                        ), '');

                        lmg_audit_movement('APOF', i_batch_no, i_e_rec, apply_freq(1, l_give_stack_on_dock_time), '');
                        lmg_audit_movement('MEPOF', i_batch_no, i_e_rec, apply_freq(1, l_give_stack_on_dock_time), '');
                        lmg_audit_movement('BT90', i_batch_no, i_e_rec, apply_freq(1, l_give_stack_on_dock_time), '');
                    END IF; /* end audit */

                ELSE
						/*
						** New pallet goes in middle of stack
						*/
                    l_second_index := 0;
                    l_stack1 := 0;
                    l_stack2 := l_pallet_count;
                    FOR l_second_index IN 1..l_index LOOP IF ( ( l_put_pkups.result_table(l_second_index).put_path > l_put_pkups.result_table(l_index).put_path
                    ) OR ( ( l_put_pkups.result_table(l_second_index).put_path = l_put_pkups.result_table(l_index).put_path ) AND ( l_put_pkups.result_table(l_second_index
                    ).exp_date < l_put_pkups.result_table(l_index).exp_date ) ) OR ( ( l_put_pkups.result_table(l_second_index).put_path = l_put_pkups.result_table(l_index
                    ).put_path ) AND ( l_put_pkups.result_table(l_second_index).exp_date = l_put_pkups.result_table(l_index).exp_date ) AND ( l_put_pkups.result_table(l_second_index
                    ).pallet_id_sort < l_put_pkups.result_table(l_index).pallet_id_sort ) ) ) THEN
                        l_stack1 := l_stack1 + 1;
                        l_stack2 := l_stack2 - 1;
                    ELSE
                        EXIT;
                    END IF;
                    END LOOP; /* end second index loop */
						/* Break apart stack */

                    IF ( l_give_stack_on_dock_time = TRUE1 ) THEN
                        io_pickup := io_pickup + i_e_rec.tid + i_e_rec.ppof + i_e_rec.bp + i_e_rec.apos + ( ( ( l_stack1 * STD_PALLET_HEIGHT
                        ) / 12.0 ) * i_e_rec.re ) + i_e_rec.mepos + i_e_rec.bp + ( ( ( l_stack1 * STD_PALLET_HEIGHT ) / 12.0 ) * i_e_rec
                        .ll ) + i_e_rec.ppof;
                    END IF;

                    IF ( g_forklift_audit = TRUE1) THEN
                        l_message := 'Pickup pallet '
                                     || l_palletids(l_index)
                                     || ' at '
                                     || l_src_locs(l_index)
                                     || ' and put in the middle of the stack.  Break apart stack.';

                        lmg_audit_cmt(i_batch_no, l_message, -1);
                        lmg_audit_movement('TID', i_batch_no, i_e_rec, apply_freq(1, l_give_stack_on_dock_time), '');
                        lmg_audit_movement('PPOF', i_batch_no, i_e_rec, apply_freq(1, l_give_stack_on_dock_time), '');
                        lmg_audit_movement('BP', i_batch_no, i_e_rec, apply_freq(1, l_give_stack_on_dock_time), '');
                        lmg_audit_movement('APOS', i_batch_no, i_e_rec, apply_freq(1, l_give_stack_on_dock_time), '');
                        lmg_audit_movement('RE', i_batch_no, i_e_rec, apply_freq(l_stack1 * STD_PALLET_HEIGHT, l_give_stack_on_dock_time
                        ), '');

                        lmg_audit_movement('MEPOS', i_batch_no, i_e_rec, apply_freq(1, l_give_stack_on_dock_time), '');
                        lmg_audit_movement('BP', i_batch_no, i_e_rec, apply_freq(1, l_give_stack_on_dock_time), '');
                        lmg_audit_movement('LL', i_batch_no, i_e_rec, apply_freq(l_stack1 * STD_PALLET_HEIGHT, l_give_stack_on_dock_time
                        ), '');

                        lmg_audit_movement('PPOF', i_batch_no, i_e_rec, apply_freq(1, l_give_stack_on_dock_time), '');
                    END IF; /* end audit */

						/* Pickup new pallet and set on stack one */

                    IF ( l_give_stack_on_dock_time = TRUE1 ) THEN
                        io_pickup := io_pickup + i_e_rec.bt90 + i_e_rec.apof + i_e_rec.mepof + i_e_rec.bt90 + i_e_rec.apos + ( ( (
                        l_stack1 * STD_PALLET_HEIGHT ) / 12.0 ) * i_e_rec.rl ) + i_e_rec.ppos + i_e_rec.bp;
                    END IF;

                    IF ( g_forklift_audit = TRUE1) THEN
                        l_message := 'Pickup pallet '
                                     || l_palletids(l_index)
                                     || ' and set on stack one.';
                        lmg_audit_movement('BT90', i_batch_no, i_e_rec, apply_freq(1, l_give_stack_on_dock_time), l_message);
                        lmg_audit_movement('APOF', i_batch_no, i_e_rec, apply_freq(1, l_give_stack_on_dock_time), '');
                        lmg_audit_movement('MEPOF', i_batch_no, i_e_rec, apply_freq(1, l_give_stack_on_dock_time), '');
                        lmg_audit_movement('BT90', i_batch_no, i_e_rec, apply_freq(1, l_give_stack_on_dock_time), '');
                        lmg_audit_movement('APOS', i_batch_no, i_e_rec, apply_freq(1, l_give_stack_on_dock_time), '');
                        lmg_audit_movement('RL', i_batch_no, i_e_rec, apply_freq(l_stack1 * STD_PALLET_HEIGHT, l_give_stack_on_dock_time
                        ), '');

                        lmg_audit_movement('PPOS', i_batch_no, i_e_rec, apply_freq(1, l_give_stack_on_dock_time), '');
                        lmg_audit_movement('BP', i_batch_no, i_e_rec, apply_freq(1, l_give_stack_on_dock_time), '');
                    END IF; /* end audit */

						/*
						** Restack
						*/

                    IF ( l_give_stack_on_dock_time = TRUE1 ) THEN
                        io_pickup := io_pickup + ( ( ( l_stack1 * STD_PALLET_HEIGHT ) / 12.0 ) * i_e_rec.le ) + i_e_rec.apof + i_e_rec
                        .mepof + i_e_rec.bp + i_e_rec.apos + ( ( ( ( l_stack1 + 1 ) * STD_PALLET_HEIGHT ) / 12.0 ) * i_e_rec.re )
                        + i_e_rec.ppos + i_e_rec.bp;
                    END IF;

                    IF ( g_forklift_audit = TRUE1) THEN
                        lmg_audit_movement('LE', i_batch_no, i_e_rec, apply_freq(l_stack1 * STD_PALLET_HEIGHT, l_give_stack_on_dock_time
                        ), 'Restack.');

                        lmg_audit_movement('APOF', i_batch_no, i_e_rec, apply_freq(1, l_give_stack_on_dock_time), '');
                        lmg_audit_movement('MEPOF', i_batch_no, i_e_rec, apply_freq(1, l_give_stack_on_dock_time), '');
                        lmg_audit_movement('BP', i_batch_no, i_e_rec, apply_freq(1, l_give_stack_on_dock_time), '');
                        lmg_audit_movement('APOS', i_batch_no, i_e_rec, apply_freq(1, l_give_stack_on_dock_time), '');
                        lmg_audit_movement('RL', i_batch_no, i_e_rec, apply_freq((l_stack1 + 1) * STD_PALLET_HEIGHT, l_give_stack_on_dock_time
                        ), '');

                        lmg_audit_movement('PPOS', i_batch_no, i_e_rec, apply_freq(1, l_give_stack_on_dock_time), '');
                        lmg_audit_movement('BP', i_batch_no, i_e_rec, apply_freq(1, l_give_stack_on_dock_time), '');
                    END IF; /* end audit */

						/*
						** Pickup stack and leave
						*/

                    IF ( l_give_stack_on_dock_time = TRUE1 ) THEN
                        io_pickup := io_pickup + ( ( ( ( l_stack1 + 1 ) * STD_PALLET_HEIGHT ) / 12.0 ) * i_e_rec.le ) + i_e_rec.apof
                        + i_e_rec.mepof + i_e_rec.bt90;
                    END IF;

                    IF ( g_forklift_audit = TRUE1) THEN
                        lmg_audit_movement('LE', i_batch_no, i_e_rec, apply_freq((l_stack1 + 1) * STD_PALLET_HEIGHT, l_give_stack_on_dock_time
                        ), 'Pickup stack.');

                        lmg_audit_movement('APOF', i_batch_no, i_e_rec, apply_freq(1, l_give_stack_on_dock_time), '');
                        lmg_audit_movement('MEPOF', i_batch_no, i_e_rec, apply_freq(1, l_give_stack_on_dock_time), '');
                        lmg_audit_movement('BT90', i_batch_no, i_e_rec, apply_freq(1, l_give_stack_on_dock_time), '');
                    END IF;

                END IF;

                l_pallet_count := l_pallet_count + 1;
                FOR l_sort_index IN 3..l_pallet_count LOOP IF ( l_put_pkups.result_table(l_sort_index - 1).put_path < l_put_pkups.result_table(l_sort_index
                ).put_path ) THEN
                    l_put_pkups_sort.result_table(1) := l_put_pkups.result_table(l_sort_index - 1);
                    l_put_pkups.result_table(l_sort_index - 1) := l_put_pkups.result_table(l_sort_index);
                    l_put_pkups.result_table(l_sort_index) := l_put_pkups_sort.result_table(1);
						/* Pallets going to same location. */
                ELSIF ( l_put_pkups.result_table(l_sort_index - 1).exp_date < l_put_pkups.result_table(l_sort_index).exp_date ) THEN
                    l_put_pkups_sort.result_table(1) := l_put_pkups.result_table(l_sort_index - 1);
                    l_put_pkups.result_table(l_sort_index - 1) := l_put_pkups.result_table(l_sort_index);
                    l_put_pkups.result_table(l_sort_index) := l_put_pkups_sort.result_table(1);
						/* Pallets going to same location and have same expiration date. */
                ELSIF ( l_put_pkups.result_table(l_sort_index - 1).pallet_id_sort < l_put_pkups.result_table(l_sort_index).pallet_id_sort ) THEN
                    l_put_pkups_sort.result_table(1) := l_put_pkups.result_table(l_sort_index - 1);
                    l_put_pkups.result_table(l_sort_index - 1) := l_put_pkups.result_table(l_sort_index);
                    l_put_pkups.result_table(l_sort_index) := l_put_pkups_sort.result_table(1);
                END IF;
                END LOOP;
					--qsort(l_put_pkups);

                pl_text_log.ins_msg_async('INFO', l_func_name, 'pickup_movement next pallet=' || io_pickup, sqlcode, sqlerrm);
            END LOOP; /* end 3rd pallet onward for loop */

        END IF;

        pl_text_log.ins_msg_async('INFO', l_func_name, 'END lmg_get_pkup_dr_to_slt_mvmnt', sqlcode, sqlerrm);
        END IF;
        EXCEPTION
            WHEN OTHERS THEN
                pl_text_log.ins_msg_async('WARN', l_func_name, 'LMG ORACLE Failed to find putaway batches or haul batches or PUT trans for pickup'
                , sqlcode, sqlerrm);
                l_ret_val := RF.STATUS_NO_LM_BATCH_FOUND;
        END;

        return(l_ret_val);
    END lmg_get_pkup_dr_to_slt_mvmnt; /* end lmg_get_pkup_dr_to_slt_mvmnt */
    
/*********************************************************************************
**   FUNCTION:
**    lmg_get_dest_inv
**   
**   Description:
**      This functions fetches the inventory in the location a pallet is
**      being pulled from or the inventory in a location a pallet is being
**      dropped to.  The pallets in the labor mgmt batch being processed are
**      excluded from the inventory list if the destination is in reserve.
**      This means if the batch is for two non-demand replenishments from
**      the same slot and these are the only two pallets in the slot then
**      there is no inventory in the slot.
**
**  PARAMETERS:   
**      i_pals              - Pallets on the forklift.
**      i_pallet_index      - Index of pallet being processed.
**      i_num_pals_on_stack - Number of pallets on forklift.
**      io_i_rec            - Pointer to inventory in destination location.
**      io_dest_total_qoh   - Total qoh in the destination location.
**      io_is_same_item     - Y if only same items in slot.  Else 'N'.
**      io_is_diff_item     - Y if only different items in slot.  Else 'N'.
**
**  RETURN VALUES:
**      None.
**
**        DATE         DESIGNER       COMMENTS
**     01/07/2020      Infosys     Initial version0.0
***********************************************************************************/

    FUNCTION lmg_get_dest_inv (
        i_pals                IN                    pl_lm_goal_pb.tbl_lmg_pallet_rec,
        i_pallet_index        IN                    NUMBER,
        i_num_pals_on_stack   IN                    NUMBER,
        io_i_rec              IN OUT                pl_lm_goal_pb.tbl_lmg_inv_rec,
        io_dest_total_qoh     IN OUT                NUMBER,
        io_is_same_item       IN OUT                VARCHAR2,
        io_is_diff_item       IN OUT                VARCHAR2
    ) RETURN NUMBER AS

        l_func_name   VARCHAR2(50) := 'pl_lm_goaltime.lmg_get_dest_inv';
        l_message     VARCHAR2(1024);
        l_ret_val     NUMBER := SWMS_NORMAL;
        l_sqlstmt     VARCHAR2(2000);
        l_index       NUMBER;
        l_dest_loc    loc.LOGI_LOC%type;
        l_inv_loc     loc.LOGI_LOC%type;
        l_pallet_id   trans.PALLET_ID%type;
        l_item        VARCHAR2(9);
        l_cpv         loc.CUST_PREF_VENDOR%type;
        l_perm        loc.PERM%type;
        c_inv_cur     SYS_REFCURSOR;
        l_cur_count   NUMBER := 0;
        l_inv_rec     pl_lm_goal_pb.type_lmg_inv_rec;
    BEGIN
        l_dest_loc := i_pals(i_pallet_index).loc;
        l_inv_loc := i_pals(i_pallet_index).inv_loc;
        l_pallet_id := i_pals(i_pallet_index).pallet_id;
        l_item := i_pals(i_pallet_index).prod_id;
        l_cpv := i_pals(i_pallet_index).cpv;
        l_perm := i_pals(i_pallet_index).perm;
        pl_text_log.ins_msg_async('INFO', l_func_name, 'START lmg_get_dest_inv', sqlcode, sqlerrm);
        l_sqlstmt := q'(SELECT logi_loc, qoh, prod_id, cust_pref_vendor, TO_NUMBER(TO_CHAR(NVL(exp_date,inv_date), 'YYYYMMDD')) exp_date FROM inv WHERE qoh > 0 AND plogi_loc = )'
        ;
        l_sqlstmt := l_sqlstmt
                     || q'(')'
                     || l_inv_loc
                     || q'(')'
                     || ' AND logi_loc NOT IN ('
                     || q'(')'
                     || i_pals(1).pallet_id
                     || q'(')';

        FOR l_index_i IN 1..i_num_pals_on_stack LOOP 
		l_sqlstmt := l_sqlstmt|| q'(, ')'
                              || i_pals(l_index_i).pallet_id
                              || q'(')';
        END LOOP;

        l_sqlstmt := l_sqlstmt || ')';
        BEGIN
            OPEN c_inv_cur FOR l_sqlstmt;

        EXCEPTION
            WHEN OTHERS THEN
                pl_text_log.ins_msg_async('WARN', l_func_name, 'LMG ORACLE OPEN of l_sqlstmt to get next level inv failed. SQL stmt in next message'
                , sqlcode, sqlerrm);
                pl_text_log.ins_msg_async('WARN', l_func_name, l_sqlstmt, sqlcode, sqlerrm);
                RETURN RF.STATUS_SEL_INV_FAIL;
        END;

        BEGIN
            WHILE ( 1 = 1 ) LOOP
                l_cur_count := l_cur_count + 1;
                io_i_rec.extend;
                FETCH c_inv_cur INTO
                        io_i_rec(l_cur_count)
                    .pallet_id,
                    io_i_rec(l_cur_count).qoh,
                    io_i_rec(l_cur_count).prod_id,
                    io_i_rec(l_cur_count).cpv,
                    io_i_rec(l_cur_count).exp_date;

                IF c_inv_cur%notfound THEN
                    io_i_rec.DELETE(l_cur_count);
                    EXIT;
                END IF;
            END LOOP;

            l_cur_count := c_inv_cur%rowcount;
			 CLOSE c_inv_cur;
        EXCEPTION
            WHEN OTHERS THEN
                pl_text_log.ins_msg_async('WARN', l_func_name, 'LMG ORACLE Failed to find inv for drop', sqlcode, sqlerrm);
				 CLOSE c_inv_cur;
                RETURN RF.STATUS_SEL_INV_FAIL;
				
        END;

    
        io_dest_total_qoh := 0;
        FOR l_index IN 1..l_cur_count LOOP            
        /*
        **  Check for same item in slot as on stack.
        */
            IF ( io_is_same_item = 'N' ) THEN
                IF ( ( l_item = io_i_rec(l_index).prod_id ) AND ( l_cpv = io_i_rec(l_index).cpv ) ) THEN
                    io_is_same_item := 'Y';
                END IF;
            END IF;

            io_dest_total_qoh := io_dest_total_qoh + io_i_rec(l_index).qoh;
        END LOOP;

        FOR l_index IN 1..l_cur_count LOOP
        /*
        **  Check for same item in slot as on stack.
        */ IF ( io_is_diff_item = 'N' ) THEN
            IF ( ( l_item != io_i_rec(l_index).prod_id ) OR ( l_cpv != io_i_rec(l_index).cpv ) ) THEN
                io_is_diff_item := 'Y';
            END IF;

        END IF;
        END LOOP;
    /*
    **  If home slot, then remove qoh for all pallets on stack.
    **  If flow slot then remove qoh for all pallets on stack.
    **  Add back any HST qty if flagged to do so.
    */

        IF ( l_perm = 'Y' OR ( i_pals(i_pallet_index).flow_slot_type = 'N' ) ) THEN
            FOR l_index IN 1..i_num_pals_on_stack LOOP
                IF ( i_pals(l_index).loc = l_dest_loc ) THEN
                    io_dest_total_qoh := io_dest_total_qoh - i_pals(l_index).qty_on_pallet;
                    IF ( i_pals(l_index).add_hst_qty_to_dest_inv = 'Y' ) THEN
                        io_dest_total_qoh := io_dest_total_qoh + i_pals(l_index).hst_qty;
                    END IF;

                END IF;
            END LOOP;
        END IF;

        pl_text_log.ins_msg_async('INFO', l_func_name, 'END lmg_get_dest_inv', sqlcode, sqlerrm);
        return(l_ret_val);
    END lmg_get_dest_inv; /* end lmg_get_dest_inv*/

/*********************************************************************************
**   FUNCTION:
**   lmg_get_drop_to_slot_movement()
**   
**   Description:
**      This functions calculates the drop movement for discreet LM
**      drops to destination locations.
**
**      If the drop point is the same for pallets then time is given to
**      drop the pallets as a stack and not unstack the pallets.
**
**   PARAMETERS:
**      i_batch_no    - Batch being processed.
**      i_e_rec       - Pointer to equipment tmus.
**      o_drop        - Discreet LM values for dropping pallets
**                      to destination locs.
**      i_trans_type  - Type of transaction being processed.
**      
**  Return Values:
**      RF.STATUS_NO_LM_BATCH_FOUND - Unable to find batch specified.
**      RF.STATUS_LM_BATCH_UPD_FAIL - Unable to update batch fields.
**
**        DATE         DESIGNER       COMMENTS
**     01/04/2020      ksar9933     Initial version0.0
**    06-Jan-2022      pkab6563     Jira 3899 - changes to adjust number of cases
**                                  dropped into home slot when drop is followed
**                                  by a home slot transfer (HST).
***********************************************************************************/

    FUNCTION lmg_get_drop_to_slot_movement (
        i_batch_no     IN             batch.batch_no%TYPE,
        i_e_rec        IN             pl_lm_goal_pb.type_lmc_equip_rec,
        o_drop         OUT            NUMBER,
        i_trans_type   IN             trans.trans_type%TYPE
    ) RETURN NUMBER AS

        l_func_name                   VARCHAR2(50) := 'pl_lm_goaltime.lmg_get_drop_to_slot_movement';
        l_message                     VARCHAR2(1024);
        l_status                      NUMBER := SWMS_NORMAL;
        l_temp                        NUMBER;
        l_pals                        pl_lm_goal_pb.tbl_lmg_pallet_rec;
        l_inv                         pl_lm_goal_pb.tbl_lmg_inv_rec;
        l_pal_num_recs                NUMBER;
        l_num_recs                    NUMBER;
        l_dest_total_qoh              NUMBER := 0;
        l_dest_empty                  VARCHAR2(1);
        l_pallet_count                NUMBER := 0;
        l_is_same_item                VARCHAR2(1);
        l_is_diff_item                VARCHAR2(1);
        l_drop                        NUMBER := 0;
        l_total_drop_movement         NUMBER := 0;
        l_use_min_qty_to_adjust_pos   VARCHAR2(10); /* Flag to designate to use 
                                                pm.min_qty to adjust the
                                                number of position in a slot. */
        l_prev_item                   VARCHAR2(10);
        l_prev_cpv                    VARCHAR2(11);
        l_prev_dest_loc               VARCHAR2(11);
        l_cur_rec_cnt                 NUMBER := 0;
        l_res                         NUMBER := -1;
           l_batch_no_1                   batch.batch_no%type;  
           l_batch_no_2                   batch.batch_no%type;   

        CURSOR c_drops_to_slots IS
         -- Non-merged batches
        SELECT
            DECODE(substr(b.batch_no, 1, 2), 'HL', 2, 1) haul_sort_order,
            DECODE(b.msku_batch_flag, 'Y', DECODE(l.perm, 'Y', '0' || b.kvi_to_loc, DECODE(ltrim(rtrim(TO_CHAR(z.rule_id))), '1',
            '0' || b.kvi_to_loc, '1' || b.kvi_to_loc)), '0') msku_sort_order,
            b.kvi_to_loc   kvi_to_loc1,
            t.pallet_id,
            t.prod_id,
            t.cust_pref_vendor,
            t.qty          qty_on_pallet,
            nvl(t.uom, 0),
            to_number(TO_CHAR(nvl(t.exp_date, SYSDATE), 'YYYYMMDD')),
            l.perm,
            l.slot_type,
            nvl(l.floor_height, 0),
            s.deep_ind,
            NVL(p.spc, 1),
            nvl(p.g_weight, 0),
            NVL(p.case_cube, 1),
            NVL(p.ti, 1),
            NVL(p.hi, 1),
            b.batch_no,
            b.kvi_to_loc,
            l.pallet_type,
            nvl(p.min_qty, 0),
--          OPCOF-3577 changed to remove divide Zero error.
--            DECODE(l_use_min_qty_to_adjust_pos, 'Y', trunc(nvl(p.min_qty, 0) /(DECODE(p.ti, NULL, 0, 0, 1, p.ti) * DECODE(p.hi, NULL
            DECODE(l_use_min_qty_to_adjust_pos, 'Y', trunc(nvl(p.min_qty, 0) /(DECODE(p.ti, NULL, 1, 0, 1, p.ti) * DECODE(p.hi, NULL
            , 1, 0, 1, p.hi))), 0),
            DECODE(g_enable_pallet_flow_syspar, 'Y', DECODE(lr.bck_logi_loc, NULL, 'N', DECODE(l.pallet_type, 'CF', 'C', 'P')), 'N'
            ) flow_slot_type,
            nvl(lr.plogi_loc, b.kvi_to_loc) inv_loc,
            substr(b.batch_no, 2, 1) batch_type,
            DECODE(sign(instr(pt.putaway_pp_prompt_for_hst_qty
                              || pt.putaway_fp_prompt_for_hst_qty
                              || pt.dmd_repl_prompt_for_hst_qty, 'Y')), 1, 'Y', 'N') demand_hst_active,
            t.qty          actual_qty_dropped,
            t.user_id,
            nvl(b.msku_batch_flag, 'N') msku_batch_flag,
            DECODE(substr(b.batch_no, 1, 1), 'T', 'Y', 'N') ignore_batch_flag,
            DECODE(l.perm, 'Y', 'home', DECODE(ltrim(rtrim(TO_CHAR(z.rule_id))), '1', 'floating', '3', 'induction', 'reserve')) slot_desc
            ,
            DECODE(l.perm, 'Y', 'H', DECODE(ltrim(rtrim(TO_CHAR(z.rule_id))), '1', 'F', '3', 'I', 'R')) slot_kind,
            b.ref_batch_no,
            nvl(b.dropped_for_a_break_away_flag, 'N') dropped_for_a_break_away_flag,
            nvl(b.resumed_after_break_away_flag, 'N') resumed_after_break_away_flag,
            DECODE(substr(b.batch_no, 1, 2), 'HL', 'Y', 'N') break_away_haul_flag
        FROM
            zone            z,
            lzone           lz,
            loc_reference   lr,
            slot_type       s,
            pallet_type     pt,
            pm              p,
            loc             l,
            trans           t,
            batch           b
        WHERE
            -- Story OPCOF-3577 Using outer join to handle MULTI records for XN POs
            p.prod_id(+) = t.prod_id
            AND s.slot_type = l.slot_type
            AND pt.pallet_type = l.pallet_type
            AND l.logi_loc = nvl(lr.plogi_loc, b.kvi_to_loc)
            AND ( t.cmt = substr(b.batch_no, 3)
                  OR t.labor_batch_no = b.batch_no )
            AND t.pallet_id = b.ref_no || ''
            AND (  t.trans_type = i_trans_type
                 OR ( t.trans_type IN ('TRP', 'MIS', 'PUX') AND i_trans_type = 'PUT')
                )
            AND b.parent_batch_no IS NULL
            AND b.batch_no = i_batch_no
            AND lr.bck_logi_loc (+) = b.kvi_to_loc
            AND lz.logi_loc = nvl(lr.plogi_loc, b.kvi_to_loc)
            AND z.zone_id = lz.zone_id
            AND z.zone_type = 'PUT'
           -------------------------------------------------------------------
        UNION                                  -- Merged batches
                -- The msku_sort_order is used to sort the child LP's going to
                -- a home or floating slot first for a MSKU pallet.
                -- 06/05/2010  Brian Bent  Modified to select HAL transaction
                --             as a child batch.                           
        SELECT
            DECODE(substr(b.batch_no, 1, 2), 'HL', 2, 1) haul_sort_order,
            DECODE(b.msku_batch_flag, 'Y', DECODE(l.perm, 'Y', '0' || b.kvi_to_loc, DECODE(ltrim(rtrim(TO_CHAR(z.rule_id))), '1',
            '0' || b.kvi_to_loc, '1' || b.kvi_to_loc)), '0') msku_sort_order,
            b.kvi_to_loc,
            t.pallet_id,
            t.prod_id,
            t.cust_pref_vendor,
            t.qty   qty_on_pallet,
            nvl(t.uom, 0),
            to_number(TO_CHAR(nvl(t.exp_date, SYSDATE), 'YYYYMMDD')),
            l.perm,
            l.slot_type,
            nvl(l.floor_height, 0),
            s.deep_ind,
            p.spc,
            nvl(p.g_weight, 0),
            p.case_cube,
            p.ti,
            p.hi,
            b.batch_no,
            b.kvi_to_loc,
            l.pallet_type,
            nvl(p.min_qty, 0),
            DECODE(l_use_min_qty_to_adjust_pos, 'Y', trunc(nvl(p.min_qty, 0) /(DECODE(p.ti, NULL, 0, 0, 1, p.ti) * DECODE(p.hi, NULL
            , 0, 0, 1, p.hi))), 0),
            DECODE(g_enable_pallet_flow_syspar, 'Y', DECODE(lr.bck_logi_loc, NULL, 'N', DECODE(l.pallet_type, 'CF', 'C', 'P')), 'N'
            ) flow_slot_type,
            nvl(lr.plogi_loc, b.kvi_to_loc) inv_loc,
            substr(b.batch_no, 2, 1) batch_type,
            DECODE(sign(instr(pt.putaway_pp_prompt_for_hst_qty
                              || pt.putaway_fp_prompt_for_hst_qty
                              || pt.dmd_repl_prompt_for_hst_qty, 'Y')), 1, 'Y', 'N') demand_hst_active,
            t.qty   actual_qty_dropped,
            t.user_id,
            nvl(b.msku_batch_flag, 'N') msku_batch_flag,
            DECODE(substr(b.batch_no, 1, 1), 'T', 'Y', 'N') ignore_batch_flag,
            DECODE(l.perm, 'Y', 'home', DECODE(ltrim(rtrim(TO_CHAR(z.rule_id))), '1', 'floating', '3', 'induction', 'reserve')) slot_desc
            ,
            DECODE(l.perm, 'Y', 'H', DECODE(ltrim(rtrim(TO_CHAR(z.rule_id))), '1', 'F', '3', 'I', 'R')) slot_kind,
            b.ref_batch_no,
            nvl(b.dropped_for_a_break_away_flag, 'N') dropped_for_a_break_away_flag,
            nvl(b.resumed_after_break_away_flag, 'N') resumed_after_break_away_flag,
            DECODE(substr(b.batch_no, 1, 2), 'HL', 'Y', 'N') break_away_haul_flag
        FROM
            zone            z,
            lzone           lz,
            loc_reference   lr,
            slot_type       s,
            pallet_type     pt,
            pm              p,
            loc             l,
            trans           t,
            batch           b
        WHERE
            p.prod_id = t.prod_id
            AND s.slot_type = l.slot_type
            AND pt.pallet_type = l.pallet_type
            AND l.logi_loc = nvl(lr.plogi_loc, b.kvi_to_loc)
            AND ( t.cmt = substr(b.batch_no, 3)
                  OR t.labor_batch_no = b.batch_no )
            AND t.pallet_id = b.ref_no || ''
            AND (   t.trans_type = i_trans_type
                 OR t.trans_type = 'HAL'     -- 06/06/2010 Brian Bent Added
                 OR ( t.trans_type IN ('TRP', 'MIS', 'PUX') AND i_trans_type = 'PUT')
                )
            AND b.parent_batch_no = i_batch_no
            AND lr.bck_logi_loc (+) = b.kvi_to_loc
            AND lz.logi_loc = nvl(lr.plogi_loc, b.kvi_to_loc)
            AND z.zone_id = lz.zone_id
            AND z.zone_type = 'PUT'
           -------------------------------------------------------------------
        UNION                          -- MSKU to reserve  11/08/03
                        -- Put in a join from the trans.dest_loc to
                        -- the batch.kvi_to_loc so an index will be used
                        -- on the trans table.  This done because the
                        -- pallet id in the trans table cannot be matched
                        -- to the batch ref# because the batch ref# is the
                        -- parent LP for a MSKU going to reserve/floating.
                        -- The trans.parent_pallet_id is joined to the batch
                        -- ref# instead but the trans.parent_pallet_id does
                        -- not have an index.
        SELECT
            DECODE(substr(b.batch_no, 1, 2), 'HL', 2, 1) haul_sort_order,
            DECODE(b.msku_batch_flag, 'Y', DECODE(l.perm, 'Y', '0' || b.kvi_to_loc, DECODE(ltrim(rtrim(TO_CHAR(z.rule_id))), '1',
            '0' || b.kvi_to_loc, '1' || b.kvi_to_loc)), '0') msku_sort_order,
            b.kvi_to_loc,
            t.pallet_id,
            t.prod_id,
            t.cust_pref_vendor,
            t.qty   qty_on_pallet,
            nvl(t.uom, 0),
            to_number(TO_CHAR(nvl(t.exp_date, SYSDATE), 'YYYYMMDD')),
            l.perm,
            l.slot_type,
            nvl(l.floor_height, 0),
            s.deep_ind,
            p.spc,
            nvl(p.g_weight, 0),
            p.case_cube,
            p.ti,
            p.hi,
            b.batch_no,
            b.kvi_to_loc,
            l.pallet_type,
            nvl(p.min_qty, 0),
            DECODE(l_use_min_qty_to_adjust_pos, 'Y', trunc(nvl(p.min_qty, 0) /(DECODE(p.ti, NULL, 0, 0, 1, p.ti) * DECODE(p.hi, NULL
            , 0, 0, 1, p.hi))), 0),
            DECODE(g_enable_pallet_flow_syspar, 'Y', DECODE(lr.bck_logi_loc, NULL, 'N', DECODE(l.pallet_type, 'CF', 'C', 'P')), 'N'
            ) flow_slot_type,
            nvl(lr.plogi_loc, b.kvi_to_loc) inv_loc,
            substr(b.batch_no, 2, 1) batch_type,
            DECODE(sign(instr(pt.putaway_pp_prompt_for_hst_qty
                              || pt.putaway_fp_prompt_for_hst_qty
                              || pt.dmd_repl_prompt_for_hst_qty, 'Y')), 1, 'Y', 'N') demand_hst_active,
            t.qty   actual_qty_dropped,
            t.user_id,
            nvl(b.msku_batch_flag, 'N') msku_batch_flag,
            DECODE(substr(b.batch_no, 1, 1), 'T', 'Y', 'N') ignore_batch_flag,
            DECODE(l.perm, 'Y', 'home', DECODE(ltrim(rtrim(TO_CHAR(z.rule_id))), '1', 'floating', '3', 'induction', 'reserve')) slot_desc
            ,
            DECODE(l.perm, 'Y', 'H', DECODE(ltrim(rtrim(TO_CHAR(z.rule_id))), '1', 'F', '3', 'I', 'R')) slot_kind,
            b.ref_batch_no,
            nvl(b.dropped_for_a_break_away_flag, 'N') dropped_for_a_break_away_flag,
            nvl(b.resumed_after_break_away_flag, 'N') resumed_after_break_away_flag,
            DECODE(substr(b.batch_no, 1, 2), 'HL', 'Y', 'N') break_away_haul_flag
        FROM
            zone            z,
            lzone           lz,
            loc_reference   lr,
            slot_type       s,
            pallet_type     pt,
            pm              p,
            loc             l,
            trans           t,
            batch           b
        WHERE
            p.prod_id = t.prod_id
            AND s.slot_type = l.slot_type
            AND pt.pallet_type = l.pallet_type
            AND l.logi_loc = nvl(lr.plogi_loc, b.kvi_to_loc)
     --      AND t.dest_loc   = NVL(lr.plogi_loc, b.kvi_to_loc) --To use index
     --      AND (   t.cmt = SUBSTR(b.batch_no, 3)
     --           OR t.labor_batch_no = b.batch_no)
            AND t.labor_batch_no = b.batch_no
     --   AND t.pallet_id   = b.ref_no || '' -- This won't match for parent LP
            AND t.parent_pallet_id = b.ref_no || ''
            AND (   t.trans_type = i_trans_type
                 OR (t.trans_type IN ('TRP', 'MIS', 'PUX') AND i_trans_type = 'PUT')
                )
            AND b.batch_no = i_batch_no
            AND lr.bck_logi_loc (+) = b.kvi_to_loc
            AND ROWNUM = 1    -- This needed.  Only want one record.
            AND lz.logi_loc = nvl(lr.plogi_loc, b.kvi_to_loc)
            AND z.zone_id = lz.zone_id
            AND z.zone_type = 'PUT';
       -- ORDER BY
        --   1 DESC,   /* HL haul sort order, DESC because the pallets are processed last to first after the fetch */
         --   2 DESC,   /* msku_sort_order */
         --   3 DESC,   /* kvi_to_loc */
          --  9 DESC;   /* exp date */
			
    BEGIN
        pl_text_log.ins_msg_async('INFO', l_func_name, 'START lmg_get_drop_to_slot_movement(i_batch_no='
                                            || i_batch_no
                                            || ', i_e_rec.equip_id='
                                            || i_e_rec.equip_id
                                            || ', o_drop, i_trans_type='
                                            || i_trans_type, sqlcode, sqlerrm);

        l_use_min_qty_to_adjust_pos := 'Y';
        l_pals := NEW pl_lm_goal_pb.tbl_lmg_pallet_rec();
        BEGIN
            OPEN c_drops_to_slots;
            
            l_pallet_count := c_drops_to_slots%rowcount;
         
        EXCEPTION
            WHEN OTHERS THEN
                pl_text_log.ins_msg_async('WARN', l_func_name, 'LMG ORACLE OPEN c_drops_to_slots failed', sqlcode, sqlerrm);
                l_status := RF.STATUS_NO_LM_BATCH_FOUND;
                RETURN l_status;
        END;

        BEGIN
            WHILE ( 1 = 1 ) LOOP
              
                l_cur_rec_cnt := l_cur_rec_cnt + 1;
                l_pals.extend;
                FETCH c_drops_to_slots INTO
                        l_pals(l_cur_rec_cnt)
                    .haul_sort_order,   /* Used for sorting */
                    l_pals(l_cur_rec_cnt).msku_sort_order,   /* Used for sorting */
                    l_pals(l_cur_rec_cnt).loc,
                    l_pals(l_cur_rec_cnt).pallet_id,
                    l_pals(l_cur_rec_cnt).prod_id,
                    l_pals(l_cur_rec_cnt).cpv,
                    l_pals(l_cur_rec_cnt).qty_on_pallet,
                    l_pals(l_cur_rec_cnt).uom,
                    l_pals(l_cur_rec_cnt).exp_date,
                    l_pals(l_cur_rec_cnt).perm,
                    l_pals(l_cur_rec_cnt).slot_type,
                    l_pals(l_cur_rec_cnt).height,
                    l_pals(l_cur_rec_cnt).deep_ind,
                    l_pals(l_cur_rec_cnt).spc,
                    l_pals(l_cur_rec_cnt).case_weight,
                    l_pals(l_cur_rec_cnt).case_cube,
                    l_pals(l_cur_rec_cnt).ti,
                    l_pals(l_cur_rec_cnt).hi,
                    l_pals(l_cur_rec_cnt).batch_no,
                    l_pals(l_cur_rec_cnt).dest_loc,
                    l_pals(l_cur_rec_cnt).pallet_type,
                    l_pals(l_cur_rec_cnt).min_qty,
                    l_pals(l_cur_rec_cnt).min_qty_num_positions,
                    l_pals(l_cur_rec_cnt).flow_slot_type,
                    l_pals(l_cur_rec_cnt).inv_loc,
                    l_pals(l_cur_rec_cnt).batch_type,
                    l_pals(l_cur_rec_cnt).demand_hst_active,
                    l_pals(l_cur_rec_cnt).actual_qty_dropped,
                    l_pals(l_cur_rec_cnt).user_id,
                    l_pals(l_cur_rec_cnt).msku_batch_flag,
                    l_pals(l_cur_rec_cnt).ignore_batch_flag,
                    l_pals(l_cur_rec_cnt).slot_desc,
                    l_pals(l_cur_rec_cnt).slot_kind,
                    l_pals(l_cur_rec_cnt).ref_batch_no,
                    l_pals(l_cur_rec_cnt).dropped_for_a_break_away_flag,
                    l_pals(l_cur_rec_cnt).resumed_after_break_away_flag,
                    l_pals(l_cur_rec_cnt).break_away_haul_flag;
        
                IF c_drops_to_slots%notfound THEN
                  
                    l_pals.DELETE(l_cur_rec_cnt);
                    EXIT;
                END IF;
            END LOOP;
			
        EXCEPTION
            WHEN OTHERS THEN
                pl_text_log.ins_msg_async('WARN', l_func_name, 'LMG ORACLE Failed to find forklift batches for drop', sqlcode, sqlerrm);
                l_status := RF.STATUS_NO_LM_BATCH_FOUND;
                  
                CLOSE c_drops_to_slots;
                RETURN l_status;
        END;

        l_pallet_count := c_drops_to_slots%rowcount;
         
        IF ( c_drops_to_slots%rowcount = 0 ) THEN
            pl_text_log.ins_msg_async('WARN', l_func_name, 'LMG ORACLE No drops found.  Could be the transaction does not exist.', sqlcode, sqlerrm
            );
            l_status := RF.STATUS_NO_LM_BATCH_FOUND;
            CLOSE c_drops_to_slots;
           
        ELSE
            CLOSE c_drops_to_slots;
            FOR l_count IN REVERSE 1..l_pallet_count LOOP
    
		
	/*
            ** Set flag if the pallet is for the same item and going to the
            ** same location as the previous pallet.
           
            */
                IF ( l_prev_item = l_pals(l_count).prod_id AND l_prev_cpv = l_pals(l_count).cpv
                        AND l_prev_dest_loc = l_pals(l_count).loc AND ( l_pals(l_count).break_away_haul_flag = 'N' ) ) THEN
                    l_pals(l_count).multi_pallet_drop_to_slot := 'Y';
                ELSE
                    l_prev_item := l_pals(l_count).prod_id;
                    l_prev_cpv := l_pals(l_count).cpv;
                    l_prev_dest_loc := l_pals(l_count).loc;
                END IF;
		
		
		/*
            ** If the pallet was dropped to a perm (home) slot
            ** and demand HST is active for the pallet type
            ** then check if a HST follows and if so adjust
            ** demand HST follows the drop and populate the actual
            ** qty dropped.  A function will check for a HST and perform
            ** the required processing.
            **
            **  At this time demand HST needs to be active
            ** for the pallet type before checking if the drop qty needs to
            ** be adjusted.  In the future when labor mgmt for a regular HST
            ** is implemented we may or may not need make adjustments for a
            ** regular HST.
            **
            ** 
            */

                IF ( ( l_pals(l_count).perm = 'Y' ) AND ( l_pals(l_count).demand_hst_active = 'Y' )
                         AND ( l_pals(l_count).break_away_haul_flag = 'N' ) ) THEN
                    lmg_calc_actual_qty_dropped(l_pals, l_count);
                END IF;

            END LOOP;/*ROWCOUNT CHECKLOOP*/
		
		
		
		/*
        ** Process the labor mgmt batch.  If a merged batch then there will
        ** be more than one pallet.
        */

            FOR l_count IN REVERSE 1..l_pallet_count LOOP
                l_drop := 0;
                l_is_same_item := 'N';
                l_is_diff_item := 'N';
           

            /*
            ** Get the inventory in the destination slot if this is the
            ** first drop to the slot.  It is possible more than one pallet
            ** is going to the same slot.
            **
            ** For a break away haul do not worry
            ** about the inventory in the destination slot.
            **
            */
                IF ( ( l_pals(l_count).multi_pallet_drop_to_slot = 'N' ) AND ( l_pals(l_count).break_away_haul_flag <> 'Y'
                ) ) THEN
                    l_dest_total_qoh := 0;
                    l_is_same_item := 'N';
                    l_status := lmg_get_dest_inv(l_pals, l_count, l_pallet_count, l_inv, l_dest_total_qoh, l_is_same_item, l_is_diff_item
                    );

                END IF;

            /*
            **  If home slot and qoh found in slot
            **  then destination location is not empty.
            **  If reserve slot and any qoh
            **  then destination location is not empty.
            */

                IF ( l_dest_total_qoh > 0 ) THEN
                    l_dest_empty := 'N';
                ELSE
                    l_dest_empty := 'Y';
                END IF;

                IF ( l_status <> 0 ) THEN
                    EXIT;
                ELSE
                    IF ( l_pals(l_count).break_away_haul_flag = 'Y' ) THEN
                    /*
                    ** Break away haul.
                    */
--                        lmg_drop_break_away_haul(l_pals, l_count, i_e_rec, l_drop);
                    /*
                    ** The break away hauls will always be processed last.
                    ** Function lmg_drop_break_away_haul() processes all of
                    ** them so get out of the loop.
                    */
                        EXIT;
                
                /* 
                ** A MSKU going to a flow slot is handled by the MSKU
                ** processing further below.
                */
                    ELSIF ( ( substr(l_pals(l_count).flow_slot_type, 1, 1) != 'N' ) AND ( l_pals(l_count).msku_batch_flag
                    <> 'Y' ) ) THEN                       
                
                    /*
                    ** Pallet going to a flow slot--pallet flow or carton
                    ** flow.
                    */
                        IF ( l_pals(l_count).flow_slot_type = 'C' ) THEN
                        /*
                        ** Pallet going to a carton flow slot.  Always
                        ** handstack carton flow slots.
                        */
                            lmg_drop_to_handstack_slot(l_pals, l_count, i_e_rec, 'Y', l_dest_total_qoh, l_drop);
                        ELSE
                        /*
                        ** Pallet going to a pallet flow slot.  Treat
                        ** like a drop to an empty home slot.
                        */
                            lmg_drop_to_pallet_flow_slot(l_pals, l_count, i_e_rec, l_dest_total_qoh, l_drop);
                        END IF;
                    ELSIF ( l_pals(l_count).perm = 'Y' ) THEN
                
                    /*
                    ** Pallet going to a home slot.
                    ** The order of the comparisons is significant.
                    */
                        IF ( l_pals(l_count).msku_batch_flag = 'Y' ) THEN
                        /*
                        ** MSKU pallet going to a home slot.
                        */
                            lmg_msku_drop_to_home_slot(l_pals, l_count, i_e_rec, l_dest_total_qoh, l_drop);
                        ELSIF ( ( l_pals(l_count).pallet_type = 'HS' ) OR ( l_pals(l_count).pallet_type = 'CF' ) ) THEN
                    
                        /*
                        ** Non-MSKU pallet going to a handstack slot or to a
                        ** carton flow slot and the enable pallet flow syspar
                        ** is off.
                        ** 'Y' in parameter list designates its a drop to a
                        ** home slot.
                        */
                            lmg_drop_to_handstack_slot(l_pals, l_count, i_e_rec, 'Y', l_dest_total_qoh, l_drop);
                        ELSIF ( ( l_dest_empty = 'Y' ) AND NOT ( ( l_pals(l_count).deep_ind = 'Y' ) AND ( SUBSTR(l_pals(l_count).slot_type,1,4) = 'F' ) ) ) THEN
                            lmg_drop_to_empty_home_slot(l_pals, l_count, i_e_rec, l_dest_total_qoh, l_drop);
                        ELSIF ( ( l_pals(l_count).deep_ind = 'Y' ) AND ( SUBSTR(l_pals(l_count).slot_type,1,4) = 'P' ) ) THEN
                            pl_lm_goal_pb.lmpb_drp_to_pshbk_hm_with_qoh(l_pals, l_pals.LAST, l_count, i_e_rec, l_dest_total_qoh, l_drop);
                        ELSIF ( ( l_pals(l_count).deep_ind = 'Y' ) AND ( SUBSTR(l_pals(l_count).slot_type,1,4) = 'D' ) ) AND ( SUBSTR(l_pals(l_count).slot_type,5,4) = 'D' ) THEN                         
                            pl_lm_goal_dd.lmgdd_dro_dbl_deep_hm_qoh(l_pals,l_temp, i_e_rec, l_dest_total_qoh, l_drop); 
                        ELSIF ( ( l_pals(l_count).deep_ind = 'Y' ) AND ( SUBSTR(l_pals(l_count).slot_type,1,4) = 'D' ) AND ( SUBSTR(l_pals(l_count).slot_type,5,4) = 'I' ) ) THEN
                            l_status := pl_lm_goal_di.lmgdi_drp_drvin_hm_with_qoh(l_pals, l_count, i_e_rec, l_inv, l_dest_total_qoh, l_drop);
                        ELSIF ( ( l_pals(l_count).deep_ind = 'Y' ) AND ( SUBSTR(l_pals(l_count).slot_type,1,4) = 'F' ) ) THEN
                            l_status := pl_lm_goal_fl.lmgfl_drp_to_flr_hm_with_qoh(l_pals, l_count, i_e_rec, l_dest_total_qoh, l_drop); 
                        ELSE
                            lmg_drp_non_deep_hm_with_qoh(l_pals, l_count, i_e_rec, l_dest_total_qoh, l_drop);
                        END IF;
                    ELSIF ( ( l_pals(l_count).perm = 'N' ) AND ( l_pals(l_count).slot_kind = 'F' ) AND ( l_pals(l_count)
                    .msku_batch_flag = 'Y' ) ) THEN
                
                    /*
                    ** MSKU pallet going to a floating slot.
                    ** Treat it like it is going to a home slot.
                    */
                        lmg_msku_drop_to_home_slot(l_pals, l_count, i_e_rec, l_dest_total_qoh, l_drop);
                    ELSIF ( l_pals(l_count).slot_kind = 'I' ) THEN
                
                    /*
                    ** Pallet going to miniloader induction location.
                    **
                    ** Different processing if the pallet is a MSKU or
                    ** not a MSKU.
                    */
                        IF ( l_pals(l_count).msku_batch_flag = 'Y' ) THEN
                        /*
                        ** MSKU pallet going to a miniload induction location.
                        ** Treat it like it is going to a home slot.
                        */
                            lmg_msku_drop_to_home_slot(l_pals, l_count, i_e_rec, l_dest_total_qoh, l_drop);
                        ELSE
                        /*
                        ** Non-MSKU pallet going to a miniload induction
                        ** location.
                        */
                            lmg_drop_to_induction_slot(l_pals, l_count, i_e_rec, l_dest_total_qoh, l_drop);
                        END IF;
                    ELSE
                
                    /*
                    ** Pallet going to a reserve or floating slot.
                    ** The order of the comparisons is significant.
                    **
                    ** 11/20/03 prpbcb  Added check for MSKU.
                    */
                        IF ( l_pals(l_count).pallet_type = 'HS' ) THEN
                    
                        /*
                        ** Pallet going to a handstack slot.
                        ** 'N' in parameter list designates its not a drop to a
                        ** home slot.
                        */
                            lmg_drop_to_handstack_slot(l_pals, l_count, i_e_rec, 'N', l_dest_total_qoh, l_drop);
                        ELSIF ( l_pals(l_count).msku_batch_flag = 'Y' ) THEN
                    
                        /*
                        ** Processing a MSKU pallet.
                        ** A MSKU going to reserve is expected
                        ** to be going to a non-deep reserve slot.
                        */
                            lmg_msku_drop_to_res_slot(l_pals, l_count, i_e_rec, l_drop);
                        ELSIF ( ( l_dest_empty = 'Y' ) AND NOT ( ( l_pals(l_count).deep_ind = 'Y' ) AND ( SUBSTR(l_pals(l_count).slot_type,1,4) = 'F' ) ) AND NOT ( ( l_pals(l_count).deep_ind = 'Y' ) AND ( SUBSTR(l_pals(l_count).slot_type,1,4)
                        = 'P' ) ) AND NOT ( ( l_pals(l_count).deep_ind = 'Y' ) AND ( SUBSTR(l_pals(l_count).slot_type,1,4) = 'D' ) AND
                        ( SUBSTR(l_pals(l_count).slot_type,1,4) = 'I' ) ) ) THEN
                            lmg_drop_to_empty_res_slot(l_pals, l_count, i_e_rec, l_drop);
                        ELSIF ( ( l_pals(l_count).deep_ind = 'Y' ) AND ( SUBSTR(l_pals(l_count).slot_type,1,4)  = 'P' )) THEN
                            pl_lm_goal_pb.lmgpb_drp_pshbk_res_with_qoh(l_pals, l_pals.LAST, l_count, i_e_rec, l_inv.LAST, l_inv, l_is_same_item, l_drop); 
                        ELSIF ( ( l_pals(l_count).deep_ind = 'Y' ) AND ( SUBSTR(l_pals(l_count).slot_type,1,4) = 'D' ) AND ( SUBSTR(l_pals(l_count).slot_type,5,4) = 'D' )) THEN
                           pl_lm_goal_dd.lmgdd_drp_dbl_deep_res_qoh(l_pals, l_count, i_e_rec,l_num_recs,l_inv, l_is_same_item, l_drop); 
                          
                        ELSIF ( ( l_pals(l_count).deep_ind = 'Y' ) AND ( SUBSTR(l_pals(l_count).slot_type,1,4) = 'D' ) AND ( SUBSTR(l_pals(l_count).slot_type,5,4) = 'I' ) ) THEN
                            l_status := pl_lm_goal_di.lmgdi_drp_drvin_res_with_qoh(l_pals, l_count, i_e_rec, l_inv, l_inv.LAST, l_is_same_item
                            , l_drop); 
                        ELSIF ( ( l_pals(l_count).deep_ind = 'Y' ) AND ( SUBSTR(l_pals(l_count).slot_type,1,4) = 'F' ) ) THEN
                            l_status := pl_lm_goal_fl.lmgfl_drp_flr_res_with_qoh(l_pals, l_count, i_e_rec, l_inv, l_inv.LAST, l_is_same_item, l_drop); 
                        ELSE
                            lmg_drp_non_deep_res_with_qoh(l_pals, l_count, i_e_rec, l_inv, l_is_same_item, l_drop);
                        END IF;
                    END IF;

                    IF ( l_status <> SWMS_NORMAL ) THEN
                        EXIT;
                    END IF;
                    l_total_drop_movement := l_total_drop_movement + l_drop;
                END IF; /* ROWCOUNT CHECK IF*/

            END LOOP;/*end for loop for batch */
		
		
		
		/*
        ** Update the total_piece for the batch.  For merged batches
        ** the total_count and total_pallet were updated when the batches
        ** were merged so only the total_piece needs updating.
        */

            BEGIN
                UPDATE batch b1
                SET
                    b1.total_piece = (
                        SELECT
                            SUM(b2.kvi_no_piece)
                        FROM
                            batch b2
                        WHERE
                            b2.parent_batch_no = b1.batch_no
                            OR b2.batch_no = b1.batch_no
                    )
                WHERE
                    b1.batch_no = i_batch_no;

            EXCEPTION
                WHEN OTHERS THEN
                    pl_text_log.ins_msg_async('WARN', l_func_name, 'LMG ORACLE Failed to update total_piece for the batch.', sqlcode, sqlerrm
                    );
                    l_status := RF.STATUS_LM_BATCH_UPD_FAIL;
            END;

        END IF;

        o_drop := l_total_drop_movement;
        pl_text_log.ins_msg_async('INFO', l_func_name, 'END lmg_get_drop_to_slot_movement(i_batch_no='
                                            || i_batch_no
                                            || ', i_e_rec.equip_id='
                                            || i_e_rec.equip_id
                                            || ', o_drop='
                                            || o_drop
                                            || ', i_trans_type='
                                            || i_trans_type, sqlcode, sqlerrm);

        RETURN l_status;
    END lmg_get_drop_to_slot_movement;

/*********************************************************************************
**   FUNCTION:
**   lmg_get_drop_to_point_movement()
**   
**   Description:
**      This functions calculates the drop movement for discreet LM 
**      drops to drop points.  The drop point can be the destination location
**      for a pallet pull which should be a door number or the drop point
**      can be the point a haul is being dropped at which can be a door,
**      aisle or bay.
**
**      If the drop point is the same for pallets then time is given to
**      drop the pallets as a stack and not unstack the pallets.
**
**   PARAMETERS:
**     i_batch_no - Batch being processed.
**     i_e_rec    - Pointer to equipment tmus.
**     o_drop     - Discreet LM values for dropping pallets to destination
**                   locations.
**      
**  Return Values:
**      RF.STATUS_NO_LM_BATCH_FOUND -- Unable to find batch specified.
**      RF.STATUS_LM_BATCH_UPD_FAIL -- Unable to update batch fields.
**
**        DATE         DESIGNER       COMMENTS
**     01/04/2020      ksar9933     Initial version0.0
***********************************************************************************/

    FUNCTION lmg_get_drop_to_point_movement (
        i_batch_no   IN           batch.batch_no%TYPE,
        i_e_rec      IN           pl_lm_goal_pb.type_lmc_equip_rec,
        o_drop       IN OUT          NUMBER
    ) RETURN NUMBER AS

        l_func_name                 VARCHAR2(50) := 'pl_lm_goaltime.lmg_get_drop_to_point_movement';
        l_message                   VARCHAR2(1024);
        l_status                    NUMBER := SWMS_NORMAL;
        l_fork_travel               NUMBER;
        l_num_pallets               NUMBER := 0;
        l_pallets_in_travel_stack   NUMBER;
        l_previous_drop_point       VARCHAR2(15);
        l_same_point_count          NUMBER := 0;
        l_pals_to_drop              type_lmg_drop_pallet_rec;
        CURSOR c_drops IS
        SELECT
            b.kvi_to_loc,
            b.ref_no
        FROM
            batch b
        WHERE
            ( ( ( b.parent_batch_no IS NOT NULL )
                AND ( b.parent_batch_no = i_batch_no ) )
              OR ( ( b.parent_batch_no IS NULL )
                   AND ( b.batch_no = i_batch_no ) ) )
        ORDER BY
            b.kvi_to_loc DESC;

    BEGIN
        pl_text_log.ins_msg_async('INFO', l_func_name, 'START lmg_get_drop_to_point_movement (i_batch_no='
                                            || i_batch_no
                                            || ', i_e_rec.equip_id='
                                            || i_e_rec.equip_id
                                            || ',o_drop)', sqlcode, sqlerrm);

        OPEN c_drops;
        FETCH c_drops INTO l_pals_to_drop;
        IF ( c_drops%rowcount = 0 ) THEN
            pl_text_log.ins_msg_async('WARN', l_func_name, 'LMG ORACLE Unable to find haul batch drop points', sqlcode, sqlerrm);
            l_status := RF.STATUS_NO_LM_BATCH_FOUND;
        ELSE
            l_pallets_in_travel_stack := c_drops%rowcount;
            /* The number of pallets to drop */
        END IF;

        CLOSE c_drops;
        FOR rec IN c_drops LOOP
            /*
            ** If not processing the first pallet and the drop points have
            ** changed then drop the pallets on the top of the travel
            ** stack going to the same drop point then pickup the remaining
            ** pallets in the travel stack to prepare for travel to the next
            ** drop point.
            */
            IF ( rec.kvi_to_loc <> l_previous_drop_point ) THEN
                l_fork_travel := STD_PALLET_HEIGHT * ( l_pallets_in_travel_stack - l_same_point_count );
                o_drop := o_drop + i_e_rec.ppof + i_e_rec.bp + i_e_rec.apos + ( ( ( l_fork_travel ) / 12.0 ) * ( i_e_rec.re ) ) +
                i_e_rec.mepos + ( ( ( l_fork_travel ) / 12.0 ) * ( i_e_rec.ll ) ) + i_e_rec.ppof + i_e_rec.bp + i_e_rec.apof + i_e_rec
                .mepof;

                IF ( g_forklift_audit = TRUE1) THEN
                    l_message := l_same_point_count
                                 || ' pallet(s) going to point '
                                 || l_previous_drop_point
                                 || '.  Put the stack down then remove the pallet(s) from the top of the stack and place on the floor.'
                                 ;
                    lmg_audit_cmt(i_batch_no, l_message, -1);
                    lmg_audit_movement('PPOF', i_batch_no, i_e_rec, 1, 'Put stack down.');
                    lmg_audit_movement('BP', i_batch_no, i_e_rec, 1, '');
                    lmg_audit_movement('APOS', i_batch_no, i_e_rec, 1, '');
                    lmg_audit_movement('RE', i_batch_no, i_e_rec, l_fork_travel, '');
                    lmg_audit_movement('MEPOS', i_batch_no, i_e_rec, 1, '');
                    lmg_audit_movement('LL', i_batch_no, i_e_rec, l_fork_travel, '');
                    lmg_audit_movement('PPOF', i_batch_no, i_e_rec, 1, '');
                    l_message := 'Pickup stack and go to next destination ' || rec.kvi_to_loc;
                    lmg_audit_movement('BP', i_batch_no, i_e_rec, 1, l_message);
                    lmg_audit_movement('APOF', i_batch_no, i_e_rec, 1, '');
                    lmg_audit_movement('MEPOF', i_batch_no, i_e_rec, 1, '');
                END IF;  /* end audit */

                /* Need to reset variables */

                l_same_point_count := 1;
                l_pallets_in_travel_stack := l_pallets_in_travel_stack - 1;
            ELSE
                l_same_point_count := l_same_point_count + l_same_point_count;
            END IF;

            IF ( g_forklift_audit = TRUE1) THEN
                l_message := 'Drop pallet '
                             || rec.ref_no
                             || ' at '
                             || rec.kvi_to_loc
                             || '.  '
                             || l_pallets_in_travel_stack
                             || ' pallet(s) in the stack.';

                lmg_audit_cmt(i_batch_no, l_message, -1);
            END IF; /* end audit */

            /*
            ** If at the last
            ** pallet in the stack then drop the stack to the floor.
            */

            IF ( l_pallets_in_travel_stack = 0 ) THEN
                o_drop := o_drop + i_e_rec.ppof + i_e_rec.bt90;
                IF ( g_forklift_audit = TRUE1) THEN
                    l_message := 'Drop stack of '
                                 || l_pallets_in_travel_stack
                                 || ' pallet(s) at point '
                                 || rec.kvi_to_loc
                                 || '.';

                    lmg_audit_movement('PPOF', i_batch_no, i_e_rec, 1, l_message);
                    lmg_audit_movement('BT90', i_batch_no, i_e_rec, 1, '');
                END IF; /* end audit */

            ELSE
                l_previous_drop_point := rec.kvi_to_loc;
            END IF;

        END LOOP;

        pl_text_log.ins_msg_async('INFO', l_func_name, 'END lmg_get_drop_to_point_movement (i_batch_no='
                                            || i_batch_no
                                            || ', i_e_rec.equip_id='
                                            || i_e_rec.equip_id
                                            || ',o_drop='
                                            || o_drop
                                            || ')', sqlcode, sqlerrm);

        RETURN l_status;
    END lmg_get_drop_to_point_movement;
    
/*********************************************************************************
**   PROCEDURE:
**   lmg_pickup_from_home()
**   
**   Description:
**      This function calculates the LM drop discreet value for a pallet
**      picked from a home location.  The operation taking place should
**      be one of the following:
**         - Pallet pull (bulk pull) with a drop to home.
**         - Pallet pull from the home slot.
**         - Replenishing case home from the split home.  The replenishment
**           quantity is cased up and credit given to handle the cases/splits.
**         - Home slot transfer.
**         - Demand replenishment home slot transfer.
**
**      If the batch is a pallet pull which was from a reserve
**      slot with a drop to home then time is given to pickup the pallet.
**      The drop to home batch will give credit to do the handstacking.
**
**      If the batch is a pallet pull which is directly from the
**      home slot then time is given to pickup the pallet from the slot and put
**      back into the slot the number of cases on the pallet that is greater
**      than the bulk pull quantity.
**
**      If the batch is a demand HST and the users last action was a drop
**      of the pallet id to the same slot then no credit is given for
**      handstacking and no credit is given for dropping the skid .  A demand
**      HST will use the same pallet id as the pallet dropped.
**
**   PARAMETERS:
**     i_pals         - Pointer to pallet list.
**     i_pindex       - Index of pallet being processed.
**     i_e_rec        - Pointer to equipment tmu values.
**     o_pickup       - Outgoing pickup value.
**      
**  Return Values:
**      NONE
**  NOTES:
**      This function handles any kind of racking.  Since there are different
**      rate values for different kinds of racking, generic variables for rack
**      entry are set in the beginning of the function and the generic
**      variables are used in the rate calculations.
**
**        DATE         DESIGNER       COMMENTS
**     01/04/2020      ksar9933     Initial version0.0
***********************************************************************************/

    PROCEDURE lmg_pickup_from_home (
        i_pals     IN         pl_lm_goal_pb.tbl_lmg_pallet_rec,
        i_pindex   IN         NUMBER,
        i_e_rec    IN         pl_lm_goal_pb.type_lmc_equip_rec,
        o_pickup   OUT        NUMBER
    ) AS

        l_func_name              VARCHAR2(50) := 'pl_lm_goaltime.lmg_pickup_from_home';
        l_message                VARCHAR2(1024);
        l_handstack_cases        NUMBER := 0;
        l_handstack_splits       NUMBER := 0;
        l_home_slot_qoh          NUMBER := 0;
        l_bulk_pull_pallet_qty   NUMBER;
        l_pallet_qty             NUMBER := 0;
        l_rack_type              VARCHAR2(10);
        l_slot_height            NUMBER;
        l_spc                    NUMBER;
        l_splits_per_pallet      NUMBER;
        l_g_tir                  NUMBER := 0;
        l_g_apir                 NUMBER := 0;
        l_g_mepir                NUMBER := 0;
        l_g_ppir                 NUMBER := 0;
        l_flowmsg                VARCHAR2(20);
        l_rf_ret_val             rf.status := rf.status_normal;
        CURSOR c_home_slot_qoh_cur IS
        SELECT
            SUM(nvl(i.qoh, 0))
        FROM
            inv i
        WHERE
            plogi_loc = i_pals(i_pindex).loc;

    BEGIN
        pl_text_log.ins_msg_async('INFO', l_func_name, 'START lmg_pickup_from_home (batch_no='
                                            || i_pals(i_pindex).batch_no
                                            || ', i_pindex='
                                            || i_pindex
                                            || ', i_e_rec.equip_id='
                                            || i_e_rec.equip_id
                                            || ',o_pickup='
                                            || o_pickup
                                            || ')', sqlcode, sqlerrm);

        l_slot_height := i_pals(i_pindex).height;
        l_spc := i_pals(i_pindex).spc;
        l_splits_per_pallet := i_pals(i_pindex).ti * i_pals(i_pindex).hi * i_pals(i_pindex).spc;

        o_pickup := 0;

    /*
    ** Assign the equipment rates that depend on the type of slot.
    */
        assign_equip_rates(i_e_rec, i_pals(i_pindex).slot_type, i_pals(i_pindex).deep_ind, l_g_tir, l_g_apir, l_g_mepir, l_g_ppir
        , l_rack_type);

        IF ( g_forklift_audit = TRUE1) THEN
            l_message := 'Pickup pallet '
                         || i_pals(i_pindex).pallet_id
                         || ' from '
                         || i_pals(i_pindex).slot_type
                         || ' '
                         || i_pals(i_pindex).pallet_type
                         || ' home slot '
                         || i_pals(i_pindex).loc;

            lmg_audit_cmt(g_audit_batch_no, l_message, -1);

        /*
        ** Flow slots get additional information on the forklift audit report.
        */
            CASE ( substr(i_pals(i_pindex).flow_slot_type, 1, 1) )
                WHEN 'N' THEN
                    l_flowmsg := '';
                WHEN 'P' THEN
                    l_flowmsg := 'pallet flow';
                WHEN 'C' THEN
                    l_flowmsg := 'carton flow';
                ELSE
                    l_flowmsg := 'unhandled flow_slot_type[('
                                 || i_pals(i_pindex).flow_slot_type
                                 || ')]';
            END CASE;

            IF ( i_pals(i_pindex).flow_slot_type != 'N' ) THEN
                l_message := 'Slot '
                             || i_pals(i_pindex).loc
                             || ' is a '
                             || l_flowmsg
                             || ' back slot.  The pick location is '
                             || i_pals(i_pindex).inv_loc
                             || '.';

                lmg_audit_cmt(g_audit_batch_no, l_message, -1);
            END IF;

        END IF;

        IF ( ( substr(i_pals(i_pindex).batch_no, 1, 1) = LMF.FORKLIFT_BATCH_ID ) AND ( substr(i_pals(i_pindex).batch_no, 2, 1) = LMF.FORKLIFT_DROP_TO_HOME

        ) ) THEN  
        /*
        ** Pallet pull.
        */
            IF ( pl_lm_forklift.lmf_bulk_pull_w_drop_to_home(i_pals(i_pindex).batch_no) != 0 ) THEN       
            /*
            ** Bulk pull which has an associated drop to home.  The pallet
            ** is at the home slot.  Pickup the pallet.
            */
                o_pickup := o_pickup + i_e_rec.apof + i_e_rec.mepof;
                IF ( g_forklift_audit = TRUE1) THEN
                    lmg_audit_movement('APOF', g_audit_batch_no, i_e_rec, 1, 'This is a bulk pull that had a drop to home.  Pickup the pallet.'
                    );
                    lmg_audit_movement('MEPOF', g_audit_batch_no, i_e_rec, 1, '');
                END IF;

            ELSE
        
            /*
            ** Pallet pull directly for the home slot.
            **
            ** Get the qoh in the home slot.  It used to determine if there
            ** was sufficient quantity in the home slot for the bulk pull.
            **
            ** 01/12/01 prpbcb  I do not remember why I checked the home
            ** slot qoh.  If a bulk pull was created then it should have
            ** sufficient qty in the home slot.
            */
                BEGIN
                    OPEN c_home_slot_qoh_cur;
                    FETCH c_home_slot_qoh_cur INTO l_home_slot_qoh;
                    CLOSE c_home_slot_qoh_cur;
                EXCEPTION
                    WHEN OTHERS THEN		   /*
                ** Write message to aplog.
                ** At this time processing continues.  l_home_slot_qoh is set
                ** to 0.
                */
                        pl_text_log.ins_msg_async('WARN', l_func_name, 'LMG ORACLE Failed to select qoh in home slot '||l_home_slot_qoh, sqlcode, sqlerrm);
                        l_home_slot_qoh := 0;
						 CLOSE c_home_slot_qoh_cur;
                END;

                o_pickup := l_g_tir + l_g_apir + ( ( ( l_slot_height ) / 12.0 ) * ( i_e_rec.re ) ) + l_g_mepir + ( ( ( l_slot_height

                ) / 12.0 ) * ( i_e_rec.ll ) ) + i_e_rec.bt90;

                IF ( g_forklift_audit = TRUE1) THEN
                    lmg_audit_movement_generic(l_rack_type, 'TIR', g_audit_batch_no, i_e_rec, 1, 'Pull pallet from home slot.');
                    lmg_audit_movement_generic(l_rack_type, 'APIR', g_audit_batch_no, i_e_rec, 1, '');
                    lmg_audit_movement('RE', g_audit_batch_no, i_e_rec, l_slot_height, '');
                    lmg_audit_movement_generic(l_rack_type, 'MEPIR', g_audit_batch_no, i_e_rec, 1, '');
                    lmg_audit_movement('LL', g_audit_batch_no, i_e_rec, l_slot_height, '');
                    lmg_audit_movement('BT90', g_audit_batch_no, i_e_rec, 1, '');
                END IF; /* end audit */
       
            /*
            ** If the bulk pull quantity is less than a full pallet and there
            ** was sufficient qoh in the home slot then give time to put the
            ** extra quantity back into the slot.
            ** This extra quantity will be be the
            ** min of(qoh, full pallet quantity - bulk pull quantity)
            ** Bulk pulls should only be dealing with cases.
            */

                l_bulk_pull_pallet_qty := i_pals(i_pindex).qty_on_pallet;
                IF ( l_home_slot_qoh > 0 AND l_bulk_pull_pallet_qty < l_splits_per_pallet ) THEN
                    l_handstack_cases := least(l_home_slot_qoh,(l_splits_per_pallet - l_bulk_pull_pallet_qty)) / ( l_spc );
                    IF ( g_forklift_audit = TRUE1) THEN
                        l_message := 'Bulk pull quantity of '
                                     || l_bulk_pull_pallet_qty / l_spc
                                     || ' cases less than a full pallet.  Time given to handstack '
                                     || l_handstack_cases
                                     || ' case(s) back into the slot.';

                        lmg_audit_cmt(g_audit_batch_no, l_message, -1);
                    END IF;

                END IF;

            END IF;
        ELSE					   
				 /*
        ** The operation should be a pull from the case home to replenish the
        ** split home or a home slot transfer.
        ** Time will be given to handstack.
        ** Splits will be cased up.
        */

        /*
        ** If it is a home slot transfer and demand HST is active for the
        ** pallet then adjust the HST quantity based on the users last drop.
        */
            IF ( ( substr(i_pals(i_pindex).batch_no, 1, 1) = LMF.FORKLIFT_BATCH_ID ) AND ( substr(i_pals(i_pindex).batch_no, 2, 1) = LMF.FORKLIFT_HOME_SLOT_XFER
            ) ) THEN
                l_pallet_qty := lmg_calc_hst_handstack_qty(i_pals(i_pindex).batch_no, i_pals(i_pindex).qty_on_pallet); 

            /*
            ** Give skid time only when the qty to transfer is > 0.  If the
            ** qty to transfer is 0 then the operator is performing a home slot
            ** transfer after a drop for the same pallet.  This can heppen
            ** for carton flow and handstack slots when all the qty dropped
            ** will not fit in the slot so the operator transfers what will
            ** not fit back to reserve.  The pallets stays on the fork so
            ** drop skid time should not be given.  The skid time is the time
            ** for the operator to get an empty pallet on the forks and is
            ** also the time to take an empty pallet off the forks.
            */

                IF ( l_pallet_qty > 0 ) THEN
                    o_pickup := o_pickup + i_e_rec.ds;
                    IF ( g_forklift_audit = TRUE1) THEN
                        lmg_audit_movement('DS', g_audit_batch_no, i_e_rec, 1, l_message);
                    END IF;

                ELSE
                    IF ( g_forklift_audit = TRUE1) THEN
                        lmg_audit_cmt(g_audit_batch_no, 'No drop skid time given because the pallet is still on the forks after the drop.'
                        , -1);
                    END IF;
                END IF;

            ELSE
                l_pallet_qty := i_pals(i_pindex).qty_on_pallet;
                o_pickup := o_pickup + i_e_rec.ds;
                IF ( g_forklift_audit = TRUE1) THEN
                    lmg_audit_movement('DS', g_audit_batch_no, i_e_rec, 1, l_message);
                END IF;

            END IF;

            IF ( i_pals(i_pindex).uom = 1 ) THEN
                l_handstack_cases := l_pallet_qty / l_spc;
                l_handstack_splits := MOD(l_pallet_qty, l_spc);
            ELSE
                l_handstack_cases := l_pallet_qty / l_spc;
                l_handstack_splits := 0;
            END IF;

            IF ( g_forklift_audit = TRUE1) THEN
                l_message := 'Time given to pickup '
                             || l_handstack_cases
                             || ' case(s) and '
                             || l_handstack_splits
                             || ' split(s).';
                lmg_audit_cmt(g_audit_batch_no, l_message, -1);
            END IF;

        END IF;

        l_rf_ret_val := pl_lm_forklift.lmf_update_batch_kvi(i_pals(i_pindex).batch_no, l_handstack_cases, l_handstack_splits);

        pl_text_log.ins_msg_async('INFO', l_func_name, 'END lmg_pickup_from_home (batch_no='
                                            || i_pals(i_pindex).batch_no
                                            || ', i_pindex='
                                            || i_pindex
                                            || ', i_e_rec.equip_id='
                                            || i_e_rec.equip_id
                                            || ',o_pickup='
                                            || o_pickup
                                            || ')', sqlcode, sqlerrm);

    END lmg_pickup_from_home;

/*********************************************************************************
**   PROCEDURE:
**   lmg_pickup_from_non_deep_res()
**   
**   Description:
**      This PROCEDURE calculates the LM drop discreet value for a pallet
**     picked from a reserve non-deep location.
**
**   PARAMETERS:
**     i_pals         - Pointer to pallet list.
**	   i_pal_num_recs - Number of records in pallet list.
**     i_pindex       - Index of pallet being processed.
**     i_e_rec        - Pointer to equipment tmu values.
**     i_inv          - Pointer to pallets already in the slot.
**     i_is_diff_item - Flag denoting if there are different items
**                      in the reserve slot.
**     o_pickup       - Outgoing pickup value.
**      
**  Return Values:
**      NONE
**
**        DATE         DESIGNER       COMMENTS
**     01/04/2020      ksar9933     Initial version0.0
***********************************************************************************/

    PROCEDURE lmg_pickup_from_non_deep_res (
        i_pals           IN               pl_lm_goal_pb.tbl_lmg_pallet_rec,
        i_pal_num_recs   IN               NUMBER,
        i_pindex         IN               NUMBER,
        i_e_rec          IN               pl_lm_goal_pb.type_lmc_equip_rec,
        i_inv            IN               pl_lm_goal_pb.tbl_lmg_inv_rec,
        i_is_diff_item   IN               VARCHAR2,
        o_pickup         OUT              NUMBER
    ) AS

        l_func_name                       VARCHAR2(50) := 'pl_lm_goaltime.lmg_pickup_from_non_deep_res';
        l_height_diff                     NUMBER;
        l_is_diff_item                    VARCHAR2(1);
        l_num_pallets_already_pkd_up   NUMBER;
        l_num_pallets_to_pickup           NUMBER := 0; /* Number of pallets in be picked from
                                         the slot. */
        l_num_pallets_IN_SLOT             NUMBER;
        l_slot_height                     NUMBER := 0;
        l_temp                            NUMBER;
        l_message                         VARCHAR2(1024);
    BEGIN
        pl_text_log.ins_msg_async('INFO', l_func_name, 'START lmg_pickup_from_non_deep_res (batch_no='
                                            || i_pals(i_pindex).batch_no
                                            || ',i_pal_num_recs='
                                            || i_pal_num_recs
                                            || ', i_pindex='
                                            || i_pindex
                                            || ', i_e_rec.equip_id='
                                            || i_e_rec.equip_id
                                            || ', '
                                            || i_pals(i_pindex).multi_pallet_drop_to_slot
                                            || '(multi_pallet_drop_to_slot))', sqlcode, sqlerrm);
	/*
    ** All the LP's picked up from the same slot are processed
    ** the first time this PROCEDURE is called.
    */

        IF ( i_pindex > 1 AND ( i_pals(i_pindex).loc = i_pals(i_pindex - 1).loc ) ) THEN
            return;
        END IF;

        l_slot_height := i_pals(i_pindex).height;
        l_num_pallets_already_pkd_up := i_pindex;
        l_is_diff_item := i_is_diff_item;
        o_pickup := 0;
	
	    /*
    ** Count the pallets to be picked from the slot.
    */
        l_num_pallets_to_pickup := 1;  /* There is at least one. */
        l_temp := ( i_pindex + 1 );
        WHILE ( l_temp < i_pal_num_recs AND ( i_pals(l_temp).loc = i_pals(l_temp - 1).loc ) ) LOOP
            l_num_pallets_to_pickup := l_num_pallets_to_pickup + 1;

        /*
        ** Determine if different items are in the slot.  Different items for
        ** the pallets to pick up means the slot has different items.
        */
            IF ( ( i_pals(l_temp).prod_id <> i_pals(l_temp - 1).prod_id ) OR ( i_pals(l_temp).cpv <> i_pals(l_temp - 1).cpv ) AND
            l_is_diff_item <> 'Y' ) THEN
                l_is_diff_item := 'Y';
            END IF;
          l_temp := l_temp + 1;
        END LOOP;
	
	
	/*
    ** Determine the number of pallets in the slot.
    ** The inv num_recs has the number of pallets in the slot excluding
    ** those to be picked up.
    */

        l_num_pallets_IN_SLOT := i_inv.last + l_num_pallets_to_pickup;
        IF ( g_forklift_audit = TRUE1) THEN
            l_message := 'Pickup pallet '
                         || i_pals(i_pindex).pallet_id
                         || ' containing '
                         || i_pals(i_pindex).qty_on_pallet / i_pals(i_pindex).spc
                         || ' cases from non-deep'
                         || i_pals(i_pindex).slot_type
                         || ' '
                         || i_pals(i_pindex).pallet_type
                         || ' '
                         || i_pals(i_pindex).slot_desc
                         || ' slot '
                         || i_pals(i_pindex).loc
                         || ' containing '
                         || l_num_pallets_IN_SLOT
                         || ' pallet(s).  There is a total of '
                         || l_num_pallets_to_pickup
                         || ' pallet(s) to pickup from this slot.';

            lmg_audit_cmt(g_audit_batch_no, l_message, -1);
        END IF;
	/*
    ** If pallets have been picked up from other slots then put the
    ** stack down.
    */

        IF ( l_num_pallets_already_pkd_up > 0 ) THEN
            o_pickup := o_pickup + i_e_rec.ppof + i_e_rec.bt90;
            IF ( g_forklift_audit = TRUE1) THEN
                l_message := 'Put stack down. '
                             || l_num_pallets_already_pkd_up
                             || ' pallet(s) in the stack.';
                lmg_audit_movement('PPOF', g_audit_batch_no, i_e_rec, 1, l_message);
                lmg_audit_movement('BT90', g_audit_batch_no, i_e_rec, 1, '');
            END IF;

        END IF;
	
	
	/*
    ** Process all the pallets being picked from the slot.
    ** If more than one pallet is being picked then they will all be picked
    ** in one operation.
    */

        IF ( ( l_num_pallets_IN_SLOT = l_num_pallets_to_pickup ) OR l_is_diff_item = 'N' ) THEN
        /*
        ** All the pallets in the slot are needed or all the pallets in 
        ** the slot are the same item.  Pickup all the needed pallets in
        ** the slot in one operation assuming the needed pallets are on top.
        **
        ** At this point if there are pallets picked up from other slots
        ** then do not give TIR time because a PPOF and BT90 have been done.
        */
            IF ( g_forklift_audit = TRUE1) THEN
                IF ( l_num_pallets_IN_SLOT = l_num_pallets_to_pickup ) THEN
                    IF ( l_num_pallets_to_pickup >= 1 ) THEN
                        l_message := 'All the pallets in slot '
                                     || i_pals(i_pindex).loc
                                     || ' are being picked up.  Remove them in one operation.';
                        lmg_audit_cmt(g_audit_batch_no, l_message, -1);
                    END IF;

                ELSE
                    IF ( l_num_pallets_to_pickup = 1 ) THEN
                        l_message := 'All the pallets in slot '
                                     || i_pals(i_pindex).loc
                                     || ' are for the same item.  The needed pallet should be on top.';
                    ELSE
                        l_message := 'All the pallets in slot '
                                     || i_pals(i_pindex).loc
                                     || ' are for the same item.  The needed pallets should be on top.  Remove in one operation.'
                                     ;
                    END IF;

                    lmg_audit_cmt(g_audit_batch_no, l_message, -1);
                END IF;
            END IF; /* end audit */

            IF ( l_num_pallets_already_pkd_up = 0 ) THEN
                o_pickup := o_pickup + i_e_rec.tir;
                IF ( g_forklift_audit = TRUE1) THEN
                    lmg_audit_movement('TIR', g_audit_batch_no, i_e_rec, 1, '');
                END IF;

            END IF;

            o_pickup := o_pickup + i_e_rec.apir;

        /*
        ** Raise to height of bottom most needed pallet(s) in the slot.
        */
            l_height_diff := l_slot_height + ( ( l_num_pallets_IN_SLOT - l_num_pallets_to_pickup ) * STD_PALLET_HEIGHT );
            o_pickup := o_pickup + ( ( ( l_height_diff ) / 12.0 ) * ( i_e_rec.re ) ) + i_e_rec.mepir;

            IF ( g_forklift_audit = TRUE1) THEN
                lmg_audit_movement('APIR', g_audit_batch_no, i_e_rec, 1, '');
                lmg_audit_movement('RE', g_audit_batch_no, i_e_rec, l_height_diff, '');
                lmg_audit_movement('MEPIR', g_audit_batch_no, i_e_rec, 1, '');
            END IF;

        /*
        ** Lower the pallets which will be to the floor if no other pallets
        ** were picked up from slots or to the top of the travel stack.
        */

            l_height_diff := l_height_diff - ( l_num_pallets_already_pkd_up * STD_PALLET_HEIGHT );
            IF ( l_height_diff >= 0 ) THEN
                o_pickup := o_pickup + ( ( ( l_height_diff ) / 12.0 ) * ( i_e_rec.ll ) );
            ELSE
                o_pickup := o_pickup + ( ( abs(l_height_diff) / 12.0 ) * ( i_e_rec.rl ) );
            END IF;

            o_pickup := o_pickup + i_e_rec.bt90;
            IF ( g_forklift_audit = TRUE1) THEN
                IF ( l_height_diff >= 0 ) THEN
                    lmg_audit_movement('LL', g_audit_batch_no, i_e_rec, l_height_diff, '');
                ELSE
                    lmg_audit_movement('RL', g_audit_batch_no, i_e_rec, abs(l_height_diff), '');
                END IF;

                lmg_audit_movement('BT90', g_audit_batch_no, i_e_rec, 1, '');
            END IF;

        /*
        ** If there were pallets picked up from other slots place the 
        ** pallets just picked up from the slot on top of the travel stack
        ** and pickup the travel stack.
        */

            IF ( l_num_pallets_already_pkd_up > 0 ) THEN
            /*
            ** Pallets were picked up from other slots.  Place the slot stack
            ** on the travel stack.
            ** At this point the forks are at the top pallet of the travel
            ** stack.
            */
                l_height_diff := l_num_pallets_already_pkd_up * STD_PALLET_HEIGHT;
                o_pickup := o_pickup + i_e_rec.apos + i_e_rec.ppos + i_e_rec.bp + ( ( ( l_height_diff ) / 12.0 ) * ( i_e_rec.le )
                ) + i_e_rec.apof + i_e_rec.mepof;

                IF ( g_forklift_audit = TRUE1) THEN
                    lmg_audit_movement('APOS', g_audit_batch_no, i_e_rec, 1, '');
                    lmg_audit_movement('PPOS', g_audit_batch_no, i_e_rec, 1, '');
                    lmg_audit_movement('BP', g_audit_batch_no, i_e_rec, 1, '');
                    lmg_audit_movement('LE', g_audit_batch_no, i_e_rec, l_height_diff, '');
                    l_message := 'Pickup stack and go to next location.';
                    lmg_audit_movement('APOF', g_audit_batch_no, i_e_rec, 1, l_message);
                    lmg_audit_movement('MEPOF', g_audit_batch_no, i_e_rec, 1, '');
                END IF; /* end audit */

            END IF;

        ELSE 
	
	/*
        ** There are different items in the slot and not all the pallets
        ** in the slot are being picked up.  Assume the needed pallet(s)
        ** are at the bottom of the stack in the slot.  Take the stack from the
        ** slot, place it on the floor if no other pallets have been picked
        ** up fom other slots otherwise place it on top of the travel stack,
        ** pickup off the floor or travel stack the not needed pallets and
        ** put them back in slot.
        **
        ** At this point if there are pallets picked up from other slots
        ** then do not give TIR time because a PPOF and BT90 have been done.
        */
            IF ( g_forklift_audit = TRUE1) THEN
                l_message := 'There are different items in slot '
                             || i_pals(i_pindex).loc
                             || ' and not all the pallets in the slot are being picked up.  Assume the needed pallet(S) is/are at the bottom of the stack in the slot.'
                             ;
                lmg_audit_cmt(g_audit_batch_no, l_message, -1);
            END IF;

            IF ( l_num_pallets_already_pkd_up = 0 ) THEN
                o_pickup := o_pickup + i_e_rec.tir;
                IF ( g_forklift_audit = TRUE1) THEN
                    l_message := 'Remove the pallets in the slot and place on the floor in one operation.';
                    lmg_audit_cmt(g_audit_batch_no, l_message, -1);
                    lmg_audit_movement('TIR', g_audit_batch_no, i_e_rec, 1, '');
                END IF;

            ELSIF ( g_forklift_audit = TRUE1) THEN
                l_message := 'Remove the pallets in the slot and place on the stack.';
                lmg_audit_cmt(g_audit_batch_no, l_message, -1);
            END IF;

            o_pickup := o_pickup + i_e_rec.apir + ( ( ( l_slot_height ) / 12.0 ) * ( i_e_rec.re ) ) + i_e_rec.mepir;

            IF ( g_forklift_audit = TRUE1) THEN
                lmg_audit_movement('APIR', g_audit_batch_no, i_e_rec, 1, '');
                lmg_audit_movement('RE', g_audit_batch_no, i_e_rec, l_slot_height, '');
                lmg_audit_movement('MEPIR', g_audit_batch_no, i_e_rec, 1, '');
            END IF;

        /*
        ** At this point the pallets in the slot are on the forks (referred to
        ** as the slot stack).
        ** Lower the slot stack to the floor if no other pallets were picked up
        ** up from other slots otherwise lower/raise to the top of the travel
        ** stack.
        */

            l_height_diff := l_slot_height - ( l_num_pallets_already_pkd_up * STD_PALLET_HEIGHT );
            IF ( l_height_diff >= 0 ) THEN
                o_pickup := o_pickup + ( ( ( l_height_diff ) / 12.0 ) * ( i_e_rec.ll ) );
            ELSE
                o_pickup := o_pickup + ( ( abs(l_height_diff) / 12.0 ) * ( i_e_rec.rl ) );
            END IF;

            o_pickup := o_pickup + i_e_rec.bt90;
            IF ( g_forklift_audit = TRUE1) THEN
                IF ( l_height_diff >= 0 ) THEN
                    lmg_audit_movement('LL', g_audit_batch_no, i_e_rec, l_height_diff, '');
                ELSE
                    lmg_audit_movement('RL', g_audit_batch_no, i_e_rec, abs(l_height_diff), '');
                END IF;

                lmg_audit_movement('BT90', g_audit_batch_no, i_e_rec, 1, '');
            END IF;

        /*
        ** Place the slot stack on the floor if no other pallets were picked up
        ** from other slots or place on top of the travel stack.
        */

            IF ( l_num_pallets_already_pkd_up = 0 ) THEN
            /*
            ** No pallets have been picked up from other slots.  Place the slot
            ** stack on the floor.
            */
                o_pickup := o_pickup + i_e_rec.ppof;
                IF ( g_forklift_audit = TRUE1) THEN
                    lmg_audit_movement('PPOF', g_audit_batch_no, i_e_rec, 1, '');
                END IF;

            ELSE
            /*
            ** Pallets have been picked up from other slots.  Place the slot 
            ** stack on the travel stack.
            */
                o_pickup := o_pickup + i_e_rec.apos + i_e_rec.ppos;
                IF ( g_forklift_audit = TRUE1) THEN
                    lmg_audit_movement('APOS', g_audit_batch_no, i_e_rec, 1, '');
                    lmg_audit_movement('PPOS', g_audit_batch_no, i_e_rec, 1, '');
                END IF;

            END IF;

        /*
        ** At this point the slot stack has been placed on the travel stack.
        ** The travel stack now has was was picked up at other slot(s), the
        ** needed pallets from the slot which were assumed to be at the
        ** bottom of the slot stack and the unneeded pallets.
        ** Pickup the stack of pallets from the travel stack at the bottom
        ** most not needed pallets and put back in the slot.
        */

            o_pickup := o_pickup + i_e_rec.bp + i_e_rec.apos;
 
        /*
        ** Determine the fork travel to the bottom most not needed pallet.
        */
            l_height_diff := ( l_num_pallets_already_pkd_up * STD_PALLET_HEIGHT ) + ( l_num_pallets_to_pickup * STD_PALLET_HEIGHT
            );
            o_pickup := o_pickup + ( ( ( l_height_diff ) / 12.0 ) * ( i_e_rec.re ) ) + i_e_rec.mepos + i_e_rec.bt90 + i_e_rec.apir
            ;

            IF ( g_forklift_audit = TRUE1) THEN
                l_message := 'Take from the stack the not needed pallets and place them back in the slot.  '
                             || l_num_pallets_IN_SLOT - l_num_pallets_to_pickup
                             || ' pallet(s) to put back.';
                lmg_audit_movement('BP', g_audit_batch_no, i_e_rec, 1, l_message);
                lmg_audit_movement('APOS', g_audit_batch_no, i_e_rec, 1, '');
                lmg_audit_movement('RE', g_audit_batch_no, i_e_rec, l_height_diff, '');
                lmg_audit_movement('MEPOS', g_audit_batch_no, i_e_rec, 1, '');
                lmg_audit_movement('BT90', g_audit_batch_no, i_e_rec, 1, '');
                lmg_audit_movement('APIR', g_audit_batch_no, i_e_rec, 1, '');
            END IF; /* end audit */

        /*
        ** Determine the fork travel from the bottom most not needed pallet
        ** to the slot.
        */

            l_height_diff := l_slot_height - l_height_diff;
            IF ( l_height_diff >= 0 ) THEN
                o_pickup := o_pickup + ( ( abs(l_height_diff) / 12.0 ) * ( i_e_rec.rl ) );
            ELSE
                o_pickup := o_pickup + ( ( abs(l_height_diff) / 12.0 ) * ( i_e_rec.ll ) );
            END IF;

            o_pickup := o_pickup + i_e_rec.mepir + ( ( ( l_slot_height ) / 12.0 ) * ( i_e_rec.le ) ) + i_e_rec.bt90 + i_e_rec.apof

            + i_e_rec.mepof;

            IF ( g_forklift_audit = TRUE1) THEN
                IF ( l_height_diff >= 0 ) THEN
                    lmg_audit_movement('RL', g_audit_batch_no, i_e_rec, l_height_diff, '');
                ELSE
                    lmg_audit_movement('LL', g_audit_batch_no, i_e_rec, abs(l_height_diff), '');
                END IF;

                lmg_audit_movement('MEPIR', g_audit_batch_no, i_e_rec, 1, '');
                lmg_audit_movement('LE', g_audit_batch_no, i_e_rec, l_slot_height, '');
                lmg_audit_movement('BT90', g_audit_batch_no, i_e_rec, 1, '');
                l_message := 'Pickup stack and go to next location.';
                lmg_audit_movement('APOF', g_audit_batch_no, i_e_rec, 1, l_message);
                lmg_audit_movement('MEPOF', g_audit_batch_no, i_e_rec, 1, '');
            END IF; /* end audit */

        END IF;

        pl_text_log.ins_msg_async('INFO', l_func_name, 'END lmg_pickup_from_non_deep_res', sqlcode, sqlerrm);
    END lmg_pickup_from_non_deep_res;
    
/*********************************************************************************
**   FUNCTION:
**   lmg_get_pkup_frm_slt_mvmnt()
**   
**   Description:
**      This functions calculates the pickup movement for discreet LM pickups
**      done from slots.
**   PARAMETERS:
**      i_batch_no  - Batch being processed.
**      i_trans_type  - Type of transaction being processed.
**      i_e_rec     - Pointer to equipment tmus.
**      o_pickup      - Discreet LM values for pickin up pallets from
**                      source locations.
**      
**  Return Values:
**     RF.STATUS_NO_LM_BATCH_FOUND - Unable to find batch specified.
**      RF.STATUS_LM_BATCH_UPD_FAIL - Unable to update batch fields.
**
**
**        DATE         DESIGNER       COMMENTS
**     01/04/2020      ksar9933     Initial version0.0
***********************************************************************************/

    FUNCTION lmg_get_pkup_frm_slt_mvmnt (
        i_batch_no     IN             batch.batch_no%TYPE,
        i_trans_type   IN             trans.trans_type%TYPE,
        i_e_rec        IN             pl_lm_goal_pb.type_lmc_equip_rec,
        o_pickup       OUT            NUMBER
    ) RETURN NUMBER AS

        l_func_name                   VARCHAR2(50) := 'pl_lm_goaltime.lmg_get_pkup_frm_slt_mvmnt';
        l_status                      NUMBER := SWMS_NORMAL;
        l_pals                        pl_lm_goal_pb.tbl_lmg_pallet_rec := pl_lm_goal_pb.tbl_lmg_pallet_rec();
        l_pals_rec                    pl_lm_goal_pb.type_lmg_pallet_rec;
        l_inv                         pl_lm_goal_pb.tbl_lmg_inv_rec := pl_lm_goal_pb.tbl_lmg_inv_rec();
		l_pal_num_recs                NUMBER;
		l_num_recs                    NUMBER;
        l_dest_total_qoh              NUMBER := 0;
        l_pallet_count                NUMBER := 0;
        l_handstack_cases             batch.kvi_no_case%TYPE := 0;
        l_handstack_splits            batch.kvi_no_split%TYPE := 0;
        l_is_same_item                VARCHAR2(1);
        l_is_diff_item                VARCHAR2(1);
        l_pickup                      NUMBER := 0;
        l_total_pickup_movement       NUMBER := 0;
        l_use_min_qty_to_adjust_pos   VARCHAR2(10);
        l_prev_item                   loc.PROD_ID%type;
        l_prev_cpv                    loc.CUST_PREF_VENDOR%type;
        l_prev_dest_loc               loc.LOGI_LOC%type;
        l_temp                        NUMBER;
        l_cur_count                   NUMBER := 0;
        CURSOR c_pickup_from_slot IS
        SELECT
            b.kvi_from_loc,     -- Non-merged batches
            t.pallet_id,
            t.prod_id,
            t.cust_pref_vendor,
            t.qty,
            nvl(t.uom, 0),
            to_number(TO_CHAR(nvl(t.exp_date, SYSDATE), 'YYYYMMDD')),
            l.perm,
            l.slot_type,
            nvl(l.floor_height, 0),
            s.deep_ind,
            p.spc,
            nvl(p.g_weight, 0),
            p.case_cube,
            p.ti,
            p.hi,
            b.batch_no,
            b.kvi_to_loc,
            l.pallet_type,
            nvl(p.min_qty, 0),
            DECODE(l_use_min_qty_to_adjust_pos, 'Y', trunc(nvl(p.min_qty, 0) /(DECODE(p.ti, NULL, 1, 0, 1, p.ti) * DECODE(p.hi, NULL
            , 1, 0, 1, p.hi))), 0) min_qty_num_positions,
            DECODE(g_enable_pallet_flow_syspar, 'Y', DECODE(lr.bck_logi_loc, NULL, 'N', DECODE(l.pallet_type, 'CF', 'C', 'P')), 'N'
            ) flow_slot_type,
            nvl(lr.plogi_loc, b.kvi_from_loc) inv_loc,
            DECODE(sign(instr(pt.putaway_pp_prompt_for_hst_qty
                              || pt.putaway_fp_prompt_for_hst_qty
                              || pt.dmd_repl_prompt_for_hst_qty, 'Y')), 1, 'Y', 'N') demand_hst_active,
            t.qty actual_qty_dropped,
            t.user_id,
            nvl(b.msku_batch_flag, 'N') msku_batch_flag,
            DECODE(substr(b.batch_no, 1, 1), 'T', 'Y', 'N') ignore_batch_flag,
            DECODE(l.perm, 'Y', 'home', DECODE(ltrim(rtrim(TO_CHAR(z.rule_id))), '1', 'floating', 'reserve')) slot_desc,
            DECODE(l.perm, 'Y', 'H', DECODE(ltrim(rtrim(TO_CHAR(z.rule_id))), '1', 'F', 'R')) slot_kind,
            nvl(b.dropped_for_a_break_away_flag, 'N') dropped_for_a_break_away_flag,
            nvl(b.resumed_after_break_away_flag, 'N') resumed_after_break_away_flag
        FROM
            zone            z,
            lzone           lz,
            loc_reference   lr,
            slot_type       s,
            pallet_type     pt,
            pm              p,
            loc             l,
            trans           t,
            batch           b
        WHERE
            p.prod_id = t.prod_id
            AND p.cust_pref_vendor = t.cust_pref_vendor
            AND s.slot_type = l.slot_type
            AND pt.pallet_type = l.pallet_type
            AND l.logi_loc = nvl(lr.plogi_loc, b.kvi_from_loc)
            AND ( t.cmt = substr(b.batch_no, 3)
                  OR t.labor_batch_no = b.batch_no )
            AND t.pallet_id = b.ref_no || ''
            AND ( ( t.trans_type = i_trans_type )
                  OR ( ( i_trans_type = 'PFK' )
                       AND ( l.perm = 'Y' )
                       AND ( t.trans_type = 'PHM' ) ) )
            AND b.parent_batch_no IS NULL
            AND b.batch_no = i_batch_no
            AND lr.bck_logi_loc (+) = b.kvi_from_loc
            AND lz.logi_loc = nvl(lr.plogi_loc, b.kvi_from_loc)
            AND z.zone_id = lz.zone_id
            AND z.zone_type = 'PUT'
           -------------------------------------------------------------------
        UNION
        SELECT
            b.kvi_from_loc,
            t.pallet_id,
            t.prod_id,
            t.cust_pref_vendor,
            t.qty,
            nvl(t.uom, 0),
            to_number(TO_CHAR(nvl(t.exp_date, SYSDATE), 'YYYYMMDD')),
            l.perm,
            l.slot_type,
            nvl(l.floor_height, 0),
            s.deep_ind,
            p.spc,
            nvl(p.g_weight, 0),
            p.case_cube,
            p.ti,
            p.hi,
            b.batch_no,
            b.kvi_to_loc,
            l.pallet_type,
            nvl(p.min_qty, 0),
            DECODE(l_use_min_qty_to_adjust_pos, 'Y', trunc(nvl(p.min_qty, 0) /(DECODE(p.ti, NULL, 1, 0, 1, p.ti) * DECODE(p.hi, NULL
            , 1, 0, 1, p.hi))), 0) min_qty_num_positions,
            DECODE(g_enable_pallet_flow_syspar, 'Y', DECODE(lr.bck_logi_loc, NULL, 'N', DECODE(l.pallet_type, 'CF', 'C', 'P')), 'N'
            ) flow_slot_type,
            nvl(lr.plogi_loc, b.kvi_from_loc) inv_loc,
            DECODE(sign(instr(pt.putaway_pp_prompt_for_hst_qty
                              || pt.putaway_fp_prompt_for_hst_qty
                              || pt.dmd_repl_prompt_for_hst_qty, 'Y')), 1, 'Y', 'N') demand_hst_active,
            t.qty actual_qty_dropped,
            t.user_id,
            nvl(b.msku_batch_flag, 'N') msku_batch_flag,
            DECODE(substr(b.batch_no, 1, 1), 'T', 'Y', 'N') ignore_batch_flag,
            DECODE(l.perm, 'Y', 'home', DECODE(ltrim(rtrim(TO_CHAR(z.rule_id))), '1', 'floating', 'reserve')) slot_desc,
            DECODE(l.perm, 'Y', 'H', DECODE(ltrim(rtrim(TO_CHAR(z.rule_id))), '1', 'F', 'R')) slot_kind,
            nvl(b.dropped_for_a_break_away_flag, 'N') dropped_for_a_break_away_flag,
            nvl(b.resumed_after_break_away_flag, 'N') resumed_after_break_away_flag
        FROM
            zone            z,
            lzone           lz,
            loc_reference   lr,
            slot_type       s,
            pallet_type     pt,
            pm              p,
            loc             l,
            trans           t,
            batch           b
        WHERE
            p.prod_id = t.prod_id
            AND p.cust_pref_vendor = t.cust_pref_vendor
            AND s.slot_type = l.slot_type
            AND pt.pallet_type = l.pallet_type
            AND l.logi_loc = nvl(lr.plogi_loc, b.kvi_from_loc)
            AND ( t.cmt = substr(b.batch_no, 3)
                  OR t.labor_batch_no = b.batch_no )
            AND t.pallet_id = b.ref_no || ''
            AND ( ( t.trans_type = i_trans_type )
                  OR ( ( i_trans_type = 'PFK' )
                       AND ( l.perm = 'Y' )
                       AND ( t.trans_type = 'PHM' ) ) )
            AND b.parent_batch_no IS NOT NULL
            AND b.parent_batch_no = i_batch_no
            AND lr.bck_logi_loc (+) = b.kvi_from_loc
            AND lz.logi_loc = nvl(lr.plogi_loc, b.kvi_from_loc)
            AND z.zone_id = lz.zone_id
            AND z.zone_type = 'PUT'
           -------------------------------------------------------------------
        UNION                     -- MSKU pickup with the batch ref# the
                                -- parent pallet id.  This will happen for
                                -- a transfer.
                        -- Put in a join from the trans.src_loc to
                        -- the batch.kvi_to_loc so an index will be used
                        -- on the trans table.  This done because the
                        -- pallet id in the trans table cannot be matched
                        -- to the batch ref# because the batch ref# is the
                        -- parent LP.
                        -- The trans.parent_pallet_id is joined to the batch
                        -- ref# instead but the trans.parent_pallet_id does
                        -- not have an index.
        SELECT
            b.kvi_from_loc,     -- MSKU batch for a parent pallet id
            t.pallet_id,
            t.prod_id,
            t.cust_pref_vendor,
            t.qty,
            nvl(t.uom, 0),
            to_number(TO_CHAR(nvl(t.exp_date, SYSDATE), 'YYYYMMDD')),
            l.perm,
            l.slot_type,
            nvl(l.floor_height, 0),
            s.deep_ind,
            p.spc,
            nvl(p.g_weight, 0),
            p.case_cube,
            p.ti,
            p.hi,
            b.batch_no,
            b.kvi_to_loc,
            l.pallet_type,
            nvl(p.min_qty, 0),
            DECODE(l_use_min_qty_to_adjust_pos, 'Y', trunc(nvl(p.min_qty, 0) /(DECODE(p.ti, NULL, 1, 0, 1, p.ti) * DECODE(p.hi, NULL
            , 1, 0, 1, p.hi))), 0) min_qty_num_positions,
            DECODE(g_enable_pallet_flow_syspar, 'Y', DECODE(lr.bck_logi_loc, NULL, 'N', DECODE(l.pallet_type, 'CF', 'C', 'P')), 'N'
            ) flow_slot_type,
            nvl(lr.plogi_loc, b.kvi_from_loc) inv_loc,
            DECODE(sign(instr(pt.putaway_pp_prompt_for_hst_qty
                              || pt.putaway_fp_prompt_for_hst_qty
                              || pt.dmd_repl_prompt_for_hst_qty, 'Y')), 1, 'Y', 'N') demand_hst_active,
            t.qty actual_qty_dropped,
            t.user_id,
            nvl(b.msku_batch_flag, 'N') msku_batch_flag,
            DECODE(substr(b.batch_no, 1, 1), 'T', 'Y', 'N') ignore_batch_flag,
            DECODE(l.perm, 'Y', 'home', DECODE(ltrim(rtrim(TO_CHAR(z.rule_id))), '1', 'floating', 'reserve')) slot_desc,
            DECODE(l.perm, 'Y', 'H', DECODE(ltrim(rtrim(TO_CHAR(z.rule_id))), '1', 'F', 'R')) slot_kind,
            nvl(b.dropped_for_a_break_away_flag, 'N') dropped_for_a_break_away_flag,
            nvl(b.resumed_after_break_away_flag, 'N') resumed_after_break_away_flag
        FROM
            zone            z,
            lzone           lz,
            loc_reference   lr,
            slot_type       s,
            pallet_type     pt,
            pm              p,
            loc             l,
            trans           t,
            batch           b
        WHERE
            p.prod_id = t.prod_id
            AND p.cust_pref_vendor = t.cust_pref_vendor
            AND s.slot_type = l.slot_type
            AND pt.pallet_type = l.pallet_type
            AND l.logi_loc = nvl(lr.plogi_loc, b.kvi_from_loc)
   --        AND t.src_loc      = b.kvi_from_loc  -- To get index used
   --        AND (   t.cmt = SUBSTR(b.batch_no, 3)
   --             OR t.labor_batch_no = b.batch_no)
            AND t.labor_batch_no = b.batch_no
   --    AND t.pallet_id    = b.ref_no || '' -- This won't match for parent LP
            AND ( ( t.trans_type = i_trans_type )
                  OR ( ( i_trans_type = 'PFK' )
                       AND ( l.perm = 'Y' )
                       AND ( t.trans_type = 'PHM' ) ) )
            AND b.batch_no = i_batch_no
            AND lr.bck_logi_loc (+) = b.kvi_from_loc
            AND ROWNUM = 1    -- This needed.  Only want one record.
            AND lz.logi_loc = nvl(lr.plogi_loc, b.kvi_from_loc)
            AND z.zone_id = lz.zone_id
            AND z.zone_type = 'PUT'
        UNION
        SELECT
            b.kvi_from_loc,     -- MSKU pallet for cross dock
            t.pallet_id,
            t.prod_id,
            t.cust_pref_vendor,
            t.qty,
            nvl(t.uom, 0),
            to_number(TO_CHAR(nvl(t.exp_date, SYSDATE), 'YYYYMMDD')),
            l.perm,
            l.slot_type,
            nvl(l.floor_height, 0),
            s.deep_ind,
            p.spc,
            nvl(p.g_weight, 0),
            p.case_cube,
            p.ti,
            p.hi,
            b.batch_no,
            b.kvi_to_loc,
            l.pallet_type,
            nvl(p.min_qty, 0),
            DECODE(l_use_min_qty_to_adjust_pos, 'Y', trunc(nvl(p.min_qty, 0) /(DECODE(p.ti, NULL, 1, 0, 1, p.ti) * DECODE(p.hi, NULL
            , 1, 0, 1, p.hi))), 0) min_qty_num_positions,
            DECODE(g_enable_pallet_flow_syspar, 'Y', DECODE(lr.bck_logi_loc, NULL, 'N', DECODE(l.pallet_type, 'CF', 'C', 'P')), 'N'
            ) flow_slot_type,
            nvl(lr.plogi_loc, b.kvi_from_loc) inv_loc,
            DECODE(sign(instr(pt.putaway_pp_prompt_for_hst_qty
                              || pt.putaway_fp_prompt_for_hst_qty
                              || pt.dmd_repl_prompt_for_hst_qty, 'Y')), 1, 'Y', 'N') demand_hst_active,
            t.qty actual_qty_dropped,
            t.user_id,
            nvl(b.msku_batch_flag, 'N') msku_batch_flag,
            DECODE(substr(b.batch_no, 1, 1), 'T', 'Y', 'N') ignore_batch_flag,
            DECODE(l.perm, 'Y', 'home', DECODE(ltrim(rtrim(TO_CHAR(z.rule_id))), '1', 'floating', 'reserve')) slot_desc,
            DECODE(l.perm, 'Y', 'H', DECODE(ltrim(rtrim(TO_CHAR(z.rule_id))), '1', 'F', 'R')) slot_kind,
            nvl(b.dropped_for_a_break_away_flag, 'N') dropped_for_a_break_away_flag,
            nvl(b.resumed_after_break_away_flag, 'N') resumed_after_break_away_flag
        FROM
            zone            z,
            lzone           lz,
            loc_reference   lr,
            slot_type       s,
            pallet_type     pt,
            pm              p,
            loc             l,
            trans           t,
            batch           b,
            floats          f,
            float_detail    fd
        WHERE
            f.pallet_id = t.pallet_id
            AND fd.float_no = f.float_no
            AND p.prod_id = fd.prod_id
            AND p.cust_pref_vendor = fd.cust_pref_vendor
            AND s.slot_type = l.slot_type
            AND pt.pallet_type = l.pallet_type
            AND l.logi_loc = nvl(lr.plogi_loc, b.kvi_from_loc)
            AND t.labor_batch_no = b.batch_no
            AND t.trans_type = 'PFK'
            AND b.batch_no = i_batch_no
            AND lr.bck_logi_loc (+) = b.kvi_from_loc
            AND ROWNUM = 1
            AND lz.logi_loc = nvl(lr.plogi_loc, b.kvi_from_loc)
            AND z.zone_id = lz.zone_id
            AND z.zone_type = 'PUT'
            AND z.rule_id = 4;
       -- ORDER BY
        --    18 DESC,
        --    7 DESC;

    BEGIN
        pl_text_log.ins_msg_async('INFO', l_func_name, 'START lmg_get_pkup_frm_slt_mvmnt (i_batch_no='
                                            || i_batch_no
                                            || ', i_trans_type='
                                            || i_trans_type
                                            || ', i_e_rec.equip_id'
                                            || i_e_rec.equip_id
                                            || ', o_drop)', sqlcode, sqlerrm);

        l_use_min_qty_to_adjust_pos := 'Y';
/*
    ** Build the select statement.
    ** There can be more than one pallet under a batch if the batch
    ** is a parent batch.  '' contatenated to batch.ref_no to prevent
    ** an index on that column from being used.
    **
    ** The PFK transaction can be PHM if the slot is a home slot.
    **
    **  Modifications for carton/pallet flow slots:
    ** Added determining the flow slot type (pallet or carton or neither) if
    ** pallet flow is turned on.  This is used to determine the time given
    ** for drops to pallet and carton flow slots.
    ** Added the selecting of the inventory location since the source location
    ** of the pallet can be a back location.  This location is used later to
    ** get the inventory currently in the slot.
    **
    ** In order for oracle to use the proper indexes a union was required.
    ** The first select gets the information for a non-merged batch.  The
    ** second select gets the information for a merged batch.
    **
    ** Added a third select to user for MSKU pallets where the batch ref# is
    ** the parent pallet id.
    ** There are batches such as a transfer where one
    ** batch is created for the MSKU that will have the parent pallet id
    ** as the batch ref# which will not join with the transaction ref#.
    ** There will be a separate transactions for each child LP but we want
    ** only one record so ROWNUM=1 is used.
    **
    **
    */
	    BEGIN
            OPEN c_pickup_from_slot;
        
            WHILE ( 1 = 1 ) LOOP
                l_cur_count := l_cur_count + 1;
                l_pals.extend;
                --l_pals(l_cur_count) := l_pals_rec;
                FETCH c_pickup_from_slot INTO
                        l_pals(l_cur_count)
                    .loc,
                    l_pals(l_cur_count).pallet_id,
                    l_pals(l_cur_count).prod_id,
                    l_pals(l_cur_count).cpv,
                    l_pals(l_cur_count).qty_on_pallet,
                    l_pals(l_cur_count).uom,
                    l_pals(l_cur_count).exp_date,
                    l_pals(l_cur_count).perm,
                    l_pals(l_cur_count).slot_type,
                    l_pals(l_cur_count).height,
                    l_pals(l_cur_count).deep_ind,
                    l_pals(l_cur_count).spc,
                    l_pals(l_cur_count).case_weight,
                    l_pals(l_cur_count).case_cube,
                    l_pals(l_cur_count).ti,
                    l_pals(l_cur_count).hi,
                    l_pals(l_cur_count).batch_no,
                    l_pals(l_cur_count).dest_loc,
                    l_pals(l_cur_count).pallet_type,
                    l_pals(l_cur_count).min_qty,
                    l_pals(l_cur_count).min_qty_num_positions,
                    l_pals(l_cur_count).flow_slot_type,
                    l_pals(l_cur_count).inv_loc,
                    l_pals(l_cur_count).demand_hst_active,
                    l_pals(l_cur_count).actual_qty_dropped,
                    l_pals(l_cur_count).user_id,
                    l_pals(l_cur_count).msku_batch_flag,
                    l_pals(l_cur_count).ignore_batch_flag,
                    l_pals(l_cur_count).slot_desc,
                    l_pals(l_cur_count).slot_kind,
                    l_pals(l_cur_count).dropped_for_a_break_away_flag,
                    l_pals(l_cur_count).resumed_after_break_away_flag;

                IF c_pickup_from_slot%notfound THEN
                    l_pals.DELETE(l_cur_count);
                    EXIT;
                END IF;
                IF ( c_pickup_from_slot%rowcount < 1 ) THEN
                    pl_text_log.ins_msg_async('WARN', l_func_name, 'LMG ORACLE No pickup batches from slots found', NULL, NULL);
                    l_status := RF.STATUS_NO_LM_BATCH_FOUND;
					CLOSE c_pickup_from_slot;
                    RETURN l_status;
                END IF;

            END LOOP;
            l_pallet_count := c_pickup_from_slot%rowcount;
			CLOSE c_pickup_from_slot;
        EXCEPTION
            WHEN OTHERS THEN
                pl_text_log.ins_msg_async('WARN', l_func_name, 'LMG ORACLE Failed to find pickup batches from slots', sqlcode, sqlerrm);
                l_status := RF.STATUS_NO_LM_BATCH_FOUND; 
				l_pallet_count := c_pickup_from_slot%rowcount;
                CLOSE c_pickup_from_slot;
		        RETURN l_status;
        END;
/*
        **  Drop trailing spaces.
        **  Mark the second pallet going to the same slot as a multiple drop
        **  to same slot so only the actual putaway into the slot will be
        **  added for the second pallet and no rotation is necessary because
        **  the stack is already in order for putaway.
        */
        l_temp := 1;
        WHILE ( l_temp <= l_pallet_count ) LOOP
            IF ( l_prev_item = l_pals(l_temp).prod_id AND l_prev_cpv = l_pals(l_temp).cpv AND l_prev_dest_loc = l_pals(l_temp).loc
            ) THEN
                l_pals(l_temp).multi_pallet_drop_to_slot := 'Y';
            ELSE
                l_prev_item := l_pals(l_temp).prod_id;
                l_prev_cpv := l_pals(l_temp).cpv;
                l_prev_dest_loc := l_pals(l_temp).loc;
            END IF;

            l_temp := l_temp + 1;
        END LOOP;

        l_temp := 1;
        WHILE ( l_temp <= l_pallet_count ) LOOP
            l_is_same_item := 'N';
            l_is_diff_item := 'N';
            l_dest_total_qoh := 0;
            pl_text_log.ins_msg_async('WARN', l_func_name, 'resumed_after_break_away_flag = ' || l_pals(l_temp).resumed_after_break_away_flag
            , NULL, NULL);

            IF ( l_temp = 1 AND l_pals(l_temp).resumed_after_break_away_flag = 'Y' ) THEN
				 
    
                /*
                ** First batch processed is a break away haul.  Give time
                ** to pickup the pallet stack from the floor.
                */
                lmg_pickup_break_away_haul(l_pals, l_pallet_count, i_e_rec, l_pickup); 
										 /*
                ** Function lmg_pickup_break_away_haul() processed all of
                ** the pallets so get out of the loop.
                */
                EXIT;
            END IF;

            l_status := lmg_get_dest_inv(l_pals, l_temp, l_pallet_count, l_inv, l_dest_total_qoh, l_is_same_item, l_is_diff_item

            );

            l_handstack_cases := 0;
            l_handstack_splits := 0;
            l_pickup := 0;
            IF ( l_pals(l_temp).perm = 'Y' ) THEN
                lmg_pickup_from_home(l_pals, l_temp, i_e_rec, l_pickup);
            ELSIF ( l_pals(l_temp).msku_batch_flag = 'Y' ) THEN
                lmg_msku_pickup_from_reserve(l_pals, l_temp, i_e_rec, l_inv, l_is_diff_item, l_pickup);
            ELSE
                IF ( ( l_pals(l_temp).deep_ind = 'Y' ) AND ( SUBSTR(l_pals(l_temp).slot_type,1,4) = 'P' ) ) THEN
                    pl_lm_goal_pb.lmgpb_pickup_from_pushback_res(l_pals, l_pals.LAST, l_temp, i_e_rec, l_inv.LAST, l_inv, l_is_diff_item, l_pickup); 
                ELSIF ( ( l_pals(l_temp).deep_ind = 'Y' ) AND ( SUBSTR(l_pals(l_temp).slot_type,1,4) =
                'D' ) AND ( SUBSTR(l_pals(l_temp).slot_type,5,4) = 'D' ) ) THEN
                    pl_lm_goal_dd.lmgdd_pkup_dbl_deep_res(l_pals,l_pal_num_recs, l_temp, i_e_rec,l_num_recs, l_inv, l_is_diff_item, l_pickup); 
                
                ELSIF ( ( l_pals(l_temp).deep_ind = 'Y' ) AND ( SUBSTR(l_pals(l_temp).slot_type,1,4) = 'D' ) AND ( SUBSTR(l_pals(l_temp).slot_type,5,4) = 'I' ) ) THEN
                    l_status := pl_lm_goal_di.lmgdi_pickup_from_drivein_res(l_pals, l_temp, i_e_rec, l_inv, l_is_diff_item, l_inv.LAST, l_pickup); 
                ELSIF ( ( l_pals(l_temp).deep_ind = 'Y' ) AND ( SUBSTR(l_pals(l_temp).slot_type,1,4) = 'F' ) ) THEN
                    l_status := pl_lm_goal_fl.lmgfl_pickup_from_floor_res(l_pals, l_temp, i_e_rec, l_inv, l_is_diff_item, l_inv.LAST, l_pickup); 
                ELSE
                    lmg_pickup_from_non_deep_res(l_pals, l_pals.last, l_temp, i_e_rec, l_inv, l_is_diff_item, l_pickup);
                END IF;
            END IF;

            IF ( l_status <> SWMS_NORMAL ) THEN
                EXIT;
            END IF;
            l_total_pickup_movement := l_total_pickup_movement + l_pickup;
            BEGIN
                UPDATE batch
                SET
                    kvi_no_case = kvi_no_case + l_handstack_cases,
                    kvi_no_split = kvi_no_split + l_handstack_splits,
                    kvi_no_piece = kvi_no_piece + l_handstack_cases + l_handstack_splits,
                    total_piece = kvi_no_piece + l_handstack_cases + l_handstack_splits
                WHERE
                    batch_no = l_pals(l_temp).batch_no;

            EXCEPTION
                WHEN OTHERS THEN
                    pl_text_log.ins_msg_async('WARN', l_func_name, 'LMG ORACLE Failed to update cases and splits handstacked from slot', sqlcode
                    , sqlerrm);
                    l_status := RF.STATUS_LM_BATCH_UPD_FAIL;
					EXIT;
            END;

            l_temp := l_temp + 1;
        END LOOP;

        /*
        ** Add the total_piece of the child batches to the parent batch if
        ** the batch is a parent batch.
        */

        BEGIN
            UPDATE batch b1
            SET
                b1.total_piece = (
                    SELECT
                        SUM(b2.total_piece)
                    FROM
                        batch b2
                    WHERE
                        b2.parent_batch_no = b1.batch_no
                )
            WHERE
                b1.batch_no = i_batch_no
                AND b1.parent_batch_no = b1.batch_no;

            IF SQL%rowcount = 0 THEN
                pl_text_log.ins_msg_async('WARN', l_func_name, 'LMG ORACLE  Did not update total_piece with the values from the child batches because it is not a parent batch'
                , sqlcode, sqlerrm);
            END IF;

        EXCEPTION
            WHEN OTHERS THEN
                pl_text_log.ins_msg_async('WARN', l_func_name, 'LMG ORACLE Failed to update total_piece with the values from the child batches'
                , sqlcode, sqlerrm);
                l_status := RF.STATUS_LM_BATCH_UPD_FAIL;
        END;

        o_pickup := l_total_pickup_movement;
        pl_text_log.ins_msg_async('INFO', l_func_name, 'END lmg_get_pkup_frm_slt_mvmnt', sqlcode, sqlerrm);
        RETURN l_status;
    END lmg_get_pkup_frm_slt_mvmnt;
    
/*********************************************************************************
**   FUNCTION:
**   lmg_calc_putaway_goaltime()
**   
**   Description:
**      This functions calculates the discreet LM putaway values.
**      The resultant value is loaded into kvi_distance of the batch.
**   PARAMETERS:
**      i_batch_no  - Batch being processed.
**      i_e_rec     - Pointer to equipment tmus.
**      i_is_parent - Flag denoting if batch is parent or not.
**      
**  Return Values:
**     RF.STATUS_LM_BATCH_UPD_FAIL -- If unable to update labor batch.
**
**        DATE         DESIGNER       COMMENTS
**     01/04/2020      ksar9933     Initial version0.0
***********************************************************************************/

    FUNCTION lmg_calc_putaway_goaltime (
        i_batch_no    IN            batch.batch_no%TYPE,
        i_e_rec       IN            pl_lm_goal_pb.type_lmc_equip_rec,
        i_is_parent   IN            VARCHAR2
    ) RETURN NUMBER AS

        l_func_name    VARCHAR2(50) := 'pl_lm_goaltime.lmg_calc_putaway_goaltime';
        l_status       NUMBER := SWMS_NORMAL;
        l_distance     NUMBER := 0;
        l_l_dist       lmd_distance_obj := lmd_distance_obj(0,0,0,0,0,0);
        l_e_dist       lmd_distance_obj := lmd_distance_obj(0,0,0,0,0,0);
        l_last_point   VARCHAR2(11);
        l_pickup       NUMBER := 0;
        l_drop         NUMBER := 0;
    BEGIN
        pl_text_log.ins_msg_async('INFO', l_func_name, 'START lmg_calc_putaway_goaltime(i_batch_no='
                                            || i_batch_no
                                            || ', i_e_rec.equip_id'
                                            || i_e_rec.equip_id
                                            || ', i_is_parent='
                                            || i_is_parent
                                            || ')', sqlcode, sqlerrm);
       
        g_travel_loaded := 'Y';

/*
    **  FALSE in call to lmd_get_batch_dist indicates not a 3 part move.
    */
        l_status := pl_lm_distance.lmd_get_batch_dist(i_batch_no, i_is_parent, i_e_rec, 1, l_last_point, l_l_dist); 
        IF ( l_status = SWMS_NORMAL ) THEN
            l_l_dist.distance_rate := ( l_l_dist.accel_distance * i_e_rec.accel_rate_loaded ) + ( l_l_dist.decel_distance * i_e_rec
            .decel_rate_loaded ) + ( l_l_dist.travel_distance * i_e_rec.trav_rate_loaded );
/*
        ** If the user is signing onto an indirect batch then
        ** there will be no "from" location for the indirect batch.
        ** The distance for the forklift batch being signed off of will
        ** be from the "from" location to the "to" location of the
        ** forklift batch.
        ** Function "lmd_get_next_point_dist" will return RF.STATUS_NO_LM_BATCH_FOUND
        ** when the user is signing onto an indirect batch.
        */

            g_travel_loaded := 'N';	
								 
	/*
        ** FALSE in call to lmd_get_batch_dist indicates not a 3 part move.
        */
            l_status := pl_lm_distance.lmd_get_next_point_dist(i_batch_no,  g_user_id, l_last_point, i_e_rec, 1, l_e_dist); 
            IF ( l_status = RF.STATUS_NO_LM_BATCH_FOUND ) THEN
                l_distance := l_l_dist.distance_rate;
                l_status := SWMS_NORMAL;
            ELSIF ( l_status = SWMS_NORMAL ) THEN
                l_e_dist.distance_rate := ( l_e_dist.accel_distance * i_e_rec.accel_rate_empty ) + ( l_e_dist.decel_distance * i_e_rec
                .decel_rate_empty ) + ( l_e_dist.travel_distance * i_e_rec.trav_rate_empty );

                l_distance := l_l_dist.distance_rate + l_e_dist.distance_rate;
            END IF;

        END IF;

        IF ( l_status = SWMS_NORMAL ) THEN
            l_status := lmg_get_pkup_dr_to_slt_mvmnt(i_batch_no, i_e_rec, l_pickup);
        END IF;

        IF ( l_status = SWMS_NORMAL ) THEN
            l_status := lmg_get_drop_to_slot_movement(i_batch_no, i_e_rec, l_drop, 'PUT');
        END IF;

        IF ( l_status = SWMS_NORMAL ) THEN
            BEGIN
                UPDATE batch
                SET
                    kvi_distance = l_distance + l_pickup + l_drop + l_l_dist.tia_time + l_e_dist.tia_time,
                    abc_distance = l_l_dist.total_distance + l_e_dist.total_distance
                WHERE
                    batch_no = i_batch_no;

            EXCEPTION
                WHEN OTHERS THEN
                    pl_text_log.ins_msg_async('WARN', l_func_name, 'LMG ORACLE Update of distance for batch failed. Distance= '||l_distance||' pickup= '||l_pickup||' Drop= '||l_drop, sqlcode, sqlerrm);
                    l_status := RF.STATUS_LM_BATCH_UPD_FAIL;
            END;

            l_status := lmg_load_goaltime(i_batch_no, i_is_parent);
        END IF;

        pl_text_log.ins_msg_async('INFO', l_func_name, 'END lmg_calc_putaway_goaltime', sqlcode, sqlerrm);
        RETURN l_status;
    END lmg_calc_putaway_goaltime;
    
/*********************************************************************************
**   FUNCTION:
**   lmg_calc_ndm_rpl_goaltime()
**   
**   Description:
**      This functions calculates the discreet LM nondemand rpl. values.
**      The resultant value is loaded into kvi_distance of the batch.
**
**   PARAMETERS:
**      i_batch_no  - Batch being processed.
**      i_e_rec     - Pointer to equipment tmus.
**      i_is_parent - Flag denoting if batch is parent or not.
**      
**  Return Values:
**     RF.STATUS_LM_BATCH_UPD_FAIL -- If unable to update labor batch.
**
**        DATE         DESIGNER       COMMENTS
**     01/04/2020      ksar9933     Initial version0.0
***********************************************************************************/

    FUNCTION lmg_calc_ndm_rpl_goaltime (
        i_batch_no    IN            batch.batch_no%TYPE,
        i_e_rec       IN            pl_lm_goal_pb.type_lmc_equip_rec,
        i_is_parent   IN            VARCHAR2
    ) RETURN NUMBER AS

        l_func_name    VARCHAR2(50) := 'pl_lm_goaltime.lmg_calc_ndm_rpl_goaltime';
        l_status       NUMBER := SWMS_NORMAL;
        l_distance     NUMBER := 0;
        l_l_dist       lmd_distance_obj := lmd_distance_obj(0,0,0,0,0,0);
        l_e_dist       lmd_distance_obj := lmd_distance_obj(0,0,0,0,0,0);
        l_last_point   VARCHAR2(11);
        l_pickup       NUMBER := 0;
        l_drop         NUMBER := 0;
    BEGIN
        pl_text_log.ins_msg_async('INFO', l_func_name, 'START lmg_calc_ndm_rpl_goaltime(i_batch_no='
                                            || i_batch_no
                                            || ', i_e_rec.equip_id'
                                            || i_e_rec.equip_id
                                            || ', i_is_parent='
                                            || i_is_parent
                                            || ')', sqlcode, sqlerrm);
        g_travel_loaded := 'Y';

/*
    **  FALSE in call to lmd_get_batch_dist indicates not a 3 part move.
    */
        l_status := pl_lm_distance.lmd_get_batch_dist(i_batch_no, i_is_parent, i_e_rec, 1, l_last_point, l_l_dist); 
        IF ( l_status = SWMS_NORMAL ) THEN
            l_l_dist.distance_rate := ( l_l_dist.accel_distance * i_e_rec.accel_rate_loaded ) + ( l_l_dist.decel_distance * i_e_rec
            .decel_rate_loaded ) + ( l_l_dist.travel_distance * i_e_rec.trav_rate_loaded );
/*
        ** If the user is signing onto an indirect batch then
        ** there will be no "from" location for the indirect batch.
        ** The distance for the forklift batch being signed off of will
        ** be from the "from" location to the "to" location of the
        ** forklift batch.
        ** Function "lmd_get_next_point_dist" will return RF.STATUS_NO_LM_BATCH_FOUND
        ** when the user is signing onto an indirect batch.
        */

            g_travel_loaded := 'N';	
								 
	/*
        ** FALSE in call to lmd_get_batch_dist indicates not a 3 part move.
        */
            l_status := pl_lm_distance.lmd_get_next_point_dist(i_batch_no,  g_user_id, l_last_point, i_e_rec, 1, l_e_dist); 
            IF ( l_status = RF.STATUS_NO_LM_BATCH_FOUND ) THEN
                l_distance := l_l_dist.distance_rate;
                l_status := SWMS_NORMAL;
            ELSIF ( l_status = SWMS_NORMAL ) THEN
                l_e_dist.distance_rate := ( l_e_dist.accel_distance * i_e_rec.accel_rate_empty ) + ( l_e_dist.decel_distance * i_e_rec
                .decel_rate_empty ) + ( l_e_dist.travel_distance * i_e_rec.trav_rate_empty );

                l_distance := l_l_dist.distance_rate + l_e_dist.distance_rate;
            END IF;

        END IF;

        IF ( l_status = SWMS_NORMAL ) THEN
            l_status := lmg_get_pkup_frm_slt_mvmnt(i_batch_no, 'RPL', i_e_rec, l_pickup);
        END IF;

        IF ( l_status = SWMS_NORMAL ) THEN
            l_status := lmg_get_drop_to_slot_movement(i_batch_no, i_e_rec, l_drop, 'RPL');
        END IF;

        IF ( l_status = SWMS_NORMAL ) THEN
            BEGIN
                UPDATE batch
                SET
                    kvi_distance = l_distance + l_pickup + l_drop + l_l_dist.tia_time + l_e_dist.tia_time,
                    abc_distance = l_l_dist.total_distance + l_e_dist.total_distance
                WHERE
                    batch_no = i_batch_no;

            EXCEPTION
                WHEN OTHERS THEN
                    pl_text_log.ins_msg_async('WARN', l_func_name, 'LMG ORACLE Update of distance for NDR batch failed. Distance= '||l_distance||' pickup= '||l_pickup||' Drop= '||l_drop, sqlcode, sqlerrm);
                    l_status := RF.STATUS_LM_BATCH_UPD_FAIL;
            END;

            l_status := lmg_load_goaltime(i_batch_no, i_is_parent);
        END IF;

        pl_text_log.ins_msg_async('INFO', l_func_name, 'END lmg_calc_ndm_rpl_goaltime', sqlcode, sqlerrm);
        RETURN l_status;
    END lmg_calc_ndm_rpl_goaltime;

/*********************************************************************************
**   FUNCTION:
**   lmg_calc_drop_home_goaltime()
**   
**   Description:
**      This functions calculates the discreet LM drop to home rpl. values.
**      The resultant value is loaded into kvi_distance of the batch.
**
**   PARAMETERS:
**      i_batch_no  - Batch being processed.
**      i_e_rec     - Pointer to equipment tmus.
**      i_is_parent - Flag denoting if batch is parent or not.
**      
**  Return Values:
**      RF.STATUS_LM_BATCH_UPD_FAIL -- If unable to update labor batch.
**
**        DATE         DESIGNER       COMMENTS
**     01/04/2020      ksar9933     Initial version0.0
***********************************************************************************/

    FUNCTION lmg_calc_drop_home_goaltime (
        i_batch_no    IN            batch.batch_no%TYPE,
        i_e_rec       IN            pl_lm_goal_pb.type_lmc_equip_rec,
        i_is_parent   IN            VARCHAR2
    ) RETURN NUMBER AS

        l_func_name    VARCHAR2(50) := 'pl_lm_goaltime.lmg_calc_drop_home_goaltime';
        l_status       NUMBER := SWMS_NORMAL;
        l_distance     NUMBER := 0;
        l_l_dist       lmd_distance_obj := lmd_distance_obj(0,0,0,0,0,0);
        l_e_dist       lmd_distance_obj := lmd_distance_obj(0,0,0,0,0,0);
        l_last_point   VARCHAR2(11);
        l_pickup       NUMBER := 0;
        l_drop         NUMBER := 0;
    BEGIN    
        pl_text_log.ins_msg_async('INFO', l_func_name, 'START lmg_calc_drop_home_goaltime(i_batch_no='
                                            || i_batch_no
                                            || ', i_e_rec.equip_id'
                                            || i_e_rec.equip_id
                                            || ', i_is_parent='
                                            || i_is_parent
                                            || ')', sqlcode, sqlerrm);

        
        g_travel_loaded := 'Y';

/*
    **  FALSE in call to lmd_get_batch_dist indicates not a 3 part move.
    */
        l_status := pl_lm_distance.lmd_get_batch_dist(i_batch_no, i_is_parent, i_e_rec, 1, l_last_point, l_l_dist); 
        IF ( l_status = SWMS_NORMAL ) THEN
            l_l_dist.distance_rate := ( l_l_dist.accel_distance * i_e_rec.accel_rate_loaded ) + ( l_l_dist.decel_distance * i_e_rec
            .decel_rate_loaded ) + ( l_l_dist.travel_distance * i_e_rec.trav_rate_loaded );
/*
        ** If the user is signing onto an indirect batch then
        ** there will be no "from" location for the indirect batch.
        ** The distance for the forklift batch being signed off of will
        ** be from the "from" location to the "to" location of the
        ** forklift batch.
        ** Function "lmd_get_next_point_dist" will return RF.STATUS_NO_LM_BATCH_FOUND
        ** when the user is signing onto an indirect batch.
        */

            g_travel_loaded := 'N';	
								 
	/*
        ** FALSE in call to lmd_get_batch_dist indicates not a 3 part move.
        */
            l_status := pl_lm_distance.lmd_get_next_point_dist(i_batch_no,  g_user_id, l_last_point, i_e_rec, 1, l_e_dist); 
            IF ( l_status = RF.STATUS_NO_LM_BATCH_FOUND ) THEN
                l_distance := l_l_dist.distance_rate;
                l_status := SWMS_NORMAL;
            ELSIF ( l_status = SWMS_NORMAL ) THEN
                l_e_dist.distance_rate := ( l_e_dist.accel_distance * i_e_rec.accel_rate_empty ) + ( l_e_dist.decel_distance * i_e_rec
                .decel_rate_empty ) + ( l_e_dist.travel_distance * i_e_rec.trav_rate_empty );

                l_distance := l_l_dist.distance_rate + l_e_dist.distance_rate;
            END IF;

        END IF;

        IF ( l_status = SWMS_NORMAL ) THEN
            l_status := lmg_get_pkup_frm_slt_mvmnt(i_batch_no, 'PFK', i_e_rec, l_pickup);
        END IF;

        IF ( l_status = SWMS_NORMAL ) THEN
            l_status := lmg_get_drop_to_slot_movement(i_batch_no, i_e_rec, l_drop, 'DHM');
        END IF;

        IF ( l_status = SWMS_NORMAL ) THEN
            BEGIN
                UPDATE batch
                SET
                    kvi_distance = l_distance + l_pickup + l_drop + l_l_dist.tia_time + l_e_dist.tia_time,
                    abc_distance = l_l_dist.total_distance + l_e_dist.total_distance
                WHERE
                    batch_no = i_batch_no;

            EXCEPTION
                WHEN OTHERS THEN
                    pl_text_log.ins_msg_async('WARN', l_func_name, 'LMG ORACLE Update of distance for Drop home batch failed.Distance= '||l_distance||' pickup= '||l_pickup||' Drop= '||l_drop, sqlcode, sqlerrm
                    );
                    l_status := RF.STATUS_LM_BATCH_UPD_FAIL;
            END;

            l_status := lmg_load_goaltime(i_batch_no, i_is_parent);
        END IF;

        pl_text_log.ins_msg_async('INFO', l_func_name, 'END lmg_calc_drop_home_goaltime', sqlcode, sqlerrm);
        RETURN l_status;
    END lmg_calc_drop_home_goaltime;

/*********************************************************************************
**   FUNCTION:
**   lmg_calc_demand_rpl_goaltime()
**   
**   Description:
**      This functions calculates the discreet LM demand replenishment values.
**     The resultant value is loaded into kvi_distance of the batch.
**
**   PARAMETERS:
**      i_batch_no  - Batch being processed.
**      i_e_rec     - Pointer to equipment tmus.
**      i_is_parent - Flag denoting if batch is parent or not.
**      
**  Return Values:
**      RF.STATUS_LM_BATCH_UPD_FAIL -- If unable to update labor batch.
**
**        DATE         DESIGNER       COMMENTS
**     01/04/2020      ksar9933     Initial version0.0
***********************************************************************************/

    FUNCTION lmg_calc_demand_rpl_goaltime (
        i_batch_no    IN            batch.batch_no%TYPE,
        i_e_rec       IN            pl_lm_goal_pb.type_lmc_equip_rec,
        i_is_parent   IN            VARCHAR2
    ) RETURN NUMBER AS

        l_func_name         VARCHAR2(50) := 'pl_lm_goaltime.lmg_calc_demand_rpl_goaltime';
        l_status            NUMBER := SWMS_NORMAL;
        l_3_part_move_bln   NUMBER := FALSE0;
        l_distance          NUMBER := 0;
        l_l_dist            lmd_distance_obj := lmd_distance_obj(0,0,0,0,0,0);
        l_e_dist            lmd_distance_obj := lmd_distance_obj(0,0,0,0,0,0);
        l_last_point        VARCHAR2(11);
        l_pickup            NUMBER := 0;
        l_drop              NUMBER := 0;
    BEGIN
        pl_text_log.ins_msg_async('INFO', l_func_name, 'START lmg_calc_demand_rpl_goaltime(i_batch_no='
                                            || i_batch_no
                                            || ', i_e_rec.equip_id'
                                            || i_e_rec.equip_id
                                            || ', i_is_parent='
                                            || i_is_parent
                                            || ')', sqlcode, sqlerrm);
        
/*
    ** Get 3 part move syspar.
    */
        g_travel_loaded := 'Y';

        l_status := pl_lm_distance.lmd_get_batch_dist(i_batch_no, i_is_parent, i_e_rec, l_3_part_move_bln, l_last_point, l_l_dist); 
        IF ( l_status = SWMS_NORMAL ) THEN
            l_l_dist.distance_rate := ( l_l_dist.accel_distance * i_e_rec.accel_rate_loaded ) + ( l_l_dist.decel_distance * i_e_rec
            .decel_rate_loaded ) + ( l_l_dist.travel_distance * i_e_rec.trav_rate_loaded );
/*
        ** If the user is signing onto an indirect batch then
        ** there will be no "from" location for the indirect batch.
        ** The distance for the forklift batch being signed off of will
        ** be from the "from" location to the "to" location of the
        ** forklift batch.
        ** Function "lmd_get_next_point_dist" will return RF.STATUS_NO_LM_BATCH_FOUND
        ** when the user is signing onto an indirect batch.
        */

            g_travel_loaded := 'N';	
								 
            l_status := pl_lm_distance.lmd_get_next_point_dist(i_batch_no, g_user_id, l_last_point, i_e_rec, l_3_part_move_bln, l_e_dist); 
            IF ( l_status = RF.STATUS_NO_LM_BATCH_FOUND ) THEN
                l_distance := l_l_dist.distance_rate;
                l_status := SWMS_NORMAL;
            ELSIF ( l_status = SWMS_NORMAL ) THEN
                l_e_dist.distance_rate := ( l_e_dist.accel_distance * i_e_rec.accel_rate_empty ) + ( l_e_dist.decel_distance * i_e_rec
                .decel_rate_empty ) + ( l_e_dist.travel_distance * i_e_rec.trav_rate_empty );

                l_distance := l_l_dist.distance_rate + l_e_dist.distance_rate;
            END IF;

        END IF;

        IF ( l_status = SWMS_NORMAL ) THEN
            l_status := lmg_get_pkup_frm_slt_mvmnt(i_batch_no, 'PFK', i_e_rec, l_pickup);
        END IF;

        IF ( l_status = SWMS_NORMAL ) THEN
            l_status := lmg_get_drop_to_slot_movement(i_batch_no, i_e_rec, l_drop, 'DFK');
        END IF;

        IF ( l_status = SWMS_NORMAL ) THEN
            BEGIN
                UPDATE batch
                SET
                    kvi_distance = l_distance + l_pickup + l_drop + l_l_dist.tia_time + l_e_dist.tia_time,
                    abc_distance = l_l_dist.total_distance + l_e_dist.total_distance
                WHERE
                    batch_no = i_batch_no;

            EXCEPTION
                WHEN OTHERS THEN
                    pl_text_log.ins_msg_async('WARN', l_func_name, 'LMG ORACLE Update of distance for Pallet pull batch failed. Distance= '||l_distance||' pickup= '||l_pickup||' Drop= '||l_drop, sqlcode, sqlerrm
                    );
                    l_status := RF.STATUS_LM_BATCH_UPD_FAIL;
            END;

            l_status := lmg_load_goaltime(i_batch_no, i_is_parent);
        END IF;

        pl_text_log.ins_msg_async('INFO', l_func_name, 'END lmg_calc_demand_rpl_goaltime', sqlcode, sqlerrm);
        RETURN l_status;
    END lmg_calc_demand_rpl_goaltime;
	
/*********************************************************************************
**   FUNCTION:
**   lmg_calc_pallet_pull_goaltime()
**   
**   Description:
**      This functions calculates the discreet LM pallet pulls values.
**      The resultant value is loaded into kvi_distance of the batch.
**
**   PARAMETERS:
**      i_batch_no  - Batch being processed.
**      i_e_rec     - Pointer to equipment tmus.
**      i_is_parent - Flag denoting if batch is parent or not.
**      
**  Return Values:
**      RF.STATUS_LM_BATCH_UPD_FAIL -- If unable to update labor batch.
**
**        DATE         DESIGNER       COMMENTS
**     01/04/2020      ksar9933     Initial version0.0
***********************************************************************************/

    FUNCTION lmg_calc_pallet_pull_goaltime (
        i_batch_no    IN            batch.batch_no%TYPE,
        i_e_rec       IN            pl_lm_goal_pb.type_lmc_equip_rec,
        i_is_parent   IN            VARCHAR2
    ) RETURN NUMBER AS

        l_func_name    VARCHAR2(50) := 'pl_lm_goaltime.lmg_calc_pallet_pull_goaltime';
        l_status       NUMBER := SWMS_NORMAL;
        l_distance     NUMBER := 0;
        l_l_dist       lmd_distance_obj := lmd_distance_obj(0,0,0,0,0,0);
        l_e_dist       lmd_distance_obj := lmd_distance_obj(0,0,0,0,0,0);
        l_last_point   VARCHAR2(11);
        l_pickup       NUMBER := 0;
        l_drop         NUMBER := 0;
    BEGIN
        pl_text_log.ins_msg_async('INFO', l_func_name, 'START lmg_calc_pallet_pull_goaltime(i_batch_no='
                                            || i_batch_no
                                            || ', i_e_rec.equip_id'
                                            || i_e_rec.equip_id
                                            || ', i_is_parent='
                                            || i_is_parent
                                            || ')', sqlcode, sqlerrm);
        
        g_travel_loaded := 'Y';

/*
    **  FALSE in call to lmd_get_batch_dist indicates not a 3 part move.
    */
        l_status := pl_lm_distance.lmd_get_batch_dist(i_batch_no, i_is_parent, i_e_rec, 1, l_last_point, l_l_dist); 
        IF ( l_status = SWMS_NORMAL ) THEN
            l_l_dist.distance_rate := ( l_l_dist.accel_distance * i_e_rec.accel_rate_loaded ) + ( l_l_dist.decel_distance * i_e_rec
            .decel_rate_loaded ) + ( l_l_dist.travel_distance * i_e_rec.trav_rate_loaded );
/*
        ** If the user is signing onto an indirect batch then
        ** there will be no "from" location for the indirect batch.
        ** The distance for the forklift batch being signed off of will
        ** be from the "from" location to the "to" location of the
        ** forklift batch.
        ** Function "lmd_get_next_point_dist" will return RF.STATUS_NO_LM_BATCH_FOUND
        ** when the user is signing onto an indirect batch.
        */

            g_travel_loaded := 'N';	
								 
	/*
        ** FALSE in call to lmd_get_batch_dist indicates not a 3 part move.
        */
            l_status := pl_lm_distance.lmd_get_next_point_dist(i_batch_no,  g_user_id, l_last_point, i_e_rec, 1, l_e_dist); 
            IF ( l_status = RF.STATUS_NO_LM_BATCH_FOUND ) THEN
                l_distance := l_l_dist.distance_rate;
                l_status := SWMS_NORMAL;
            ELSIF ( l_status = SWMS_NORMAL ) THEN
                l_e_dist.distance_rate := ( l_e_dist.accel_distance * i_e_rec.accel_rate_empty ) + ( l_e_dist.decel_distance * i_e_rec
                .decel_rate_empty ) + ( l_e_dist.travel_distance * i_e_rec.trav_rate_empty );

                l_distance := l_l_dist.distance_rate + l_e_dist.distance_rate;
            END IF;

        END IF;

        IF ( l_status = SWMS_NORMAL ) THEN
            l_status := lmg_get_pkup_frm_slt_mvmnt(i_batch_no, 'PFK', i_e_rec, l_pickup);
        END IF;

        IF ( l_status = SWMS_NORMAL ) THEN
            l_status := lmg_get_drop_to_point_movement(i_batch_no, i_e_rec, l_drop);
        END IF;

        IF ( l_status = SWMS_NORMAL ) THEN
            BEGIN
                UPDATE batch
                SET
                    kvi_distance = l_distance + l_pickup + l_drop + l_l_dist.tia_time + l_e_dist.tia_time,
                    abc_distance = l_l_dist.total_distance + l_e_dist.total_distance
                WHERE
                    batch_no = i_batch_no;

            EXCEPTION
                WHEN OTHERS THEN
                    pl_text_log.ins_msg_async('WARN', l_func_name, 'LMG ORACLE Update of distance for Pallet pull batch failed. Distance= '||l_distance||' pickup= '||l_pickup||' Drop= '||l_drop, sqlcode, sqlerrm
                    );
                    l_status := RF.STATUS_LM_BATCH_UPD_FAIL;
            END;

            l_status := lmg_load_goaltime(i_batch_no, i_is_parent);
        END IF;

        pl_text_log.ins_msg_async('INFO', l_func_name, 'END lmg_calc_pallet_pull_goaltime', sqlcode, sqlerrm);
        RETURN l_status;
    END lmg_calc_pallet_pull_goaltime;

/*********************************************************************************
**   FUNCTION:
**   lmg_calc_hs_xfer_goaltime()
**   
**   Description:
**      This functions calculates the discreet LM goaltime for a
**      home slot transfer batch.  The resultant value is loaded into
**      kvi_distance of the batch.  A home slot transfer is the transfer
**      of inventory from the home slot to a reserve slot.
**      The pickup of the pallets is handled the same way
**      as ????? and the drop to the destination slot
**      is handled the same way as a putaway.
**
**   PARAMETERS:
**      i_batch_no  - Batch being processed.
**      i_e_rec     - Pointer to equipment tmus.
**      i_is_parent - Flag denoting if batch is parent or not.
**      
**  Return Values:
**      RF.STATUS_LM_BATCH_UPD_FAIL -- If unable to update the labor batch.
**
**        DATE         DESIGNER       COMMENTS
**     01/04/2020      ksar9933     Initial version0.0
***********************************************************************************/

    FUNCTION lmg_calc_hs_xfer_goaltime (
        i_batch_no    IN            batch.batch_no%TYPE,
        i_e_rec       IN            pl_lm_goal_pb.type_lmc_equip_rec,
        i_is_parent   IN            VARCHAR2
    ) RETURN NUMBER AS

        l_func_name    VARCHAR2(50) := 'pl_lm_goaltime.lmg_calc_hs_xfer_goaltime';
        l_status       NUMBER := SWMS_NORMAL;
        l_distance     NUMBER := 0;
        l_l_dist       lmd_distance_obj := lmd_distance_obj(0,0,0,0,0,0);
        l_e_dist       lmd_distance_obj := lmd_distance_obj(0,0,0,0,0,0);
        l_last_point   VARCHAR2(11);
        l_pickup       NUMBER := 0;
        l_drop         NUMBER := 0;
    BEGIN
        pl_text_log.ins_msg_async('INFO', l_func_name, 'START lmg_calc_hs_xfer_goaltime(i_batch_no='
                                            || i_batch_no
                                            || ', i_e_rec.equip_id'
                                            || i_e_rec.equip_id
                                            || ', i_is_parent='
                                            || i_is_parent
                                            || ')', sqlcode, sqlerrm);
        
        g_travel_loaded := 'Y';

/*
    **  FALSE in call to lmd_get_batch_dist indicates not a 3 part move.
    */
        l_status := pl_lm_distance.lmd_get_batch_dist(i_batch_no, i_is_parent, i_e_rec, 1, l_last_point, l_l_dist); 
        IF ( l_status = SWMS_NORMAL ) THEN
            l_l_dist.distance_rate := ( l_l_dist.accel_distance * i_e_rec.accel_rate_loaded ) + ( l_l_dist.decel_distance * i_e_rec
            .decel_rate_loaded ) + ( l_l_dist.travel_distance * i_e_rec.trav_rate_loaded );
/*
        ** If the user is signing onto an indirect batch then
        ** there will be no "from" location for the indirect batch.
        ** The distance for the forklift batch being signed off of will
        ** be from the "from" location to the "to" location of the
        ** forklift batch.
        ** Function "lmd_get_next_point_dist" will return RF.STATUS_NO_LM_BATCH_FOUND
        ** when the user is signing onto an indirect batch.
        */

            g_travel_loaded := 'N';	
								 
	/*
        ** FALSE in call to lmd_get_batch_dist indicates not a 3 part move.
        */
            l_status := pl_lm_distance.lmd_get_next_point_dist(i_batch_no,  g_user_id, l_last_point, i_e_rec, 1, l_e_dist); 
            IF ( l_status = RF.STATUS_NO_LM_BATCH_FOUND ) THEN
                l_distance := l_l_dist.distance_rate;
                l_status := SWMS_NORMAL;
            ELSIF ( l_status = SWMS_NORMAL ) THEN
                l_e_dist.distance_rate := ( l_e_dist.accel_distance * i_e_rec.accel_rate_empty ) + ( l_e_dist.decel_distance * i_e_rec
                .decel_rate_empty ) + ( l_e_dist.travel_distance * i_e_rec.trav_rate_empty );

                l_distance := l_l_dist.distance_rate + l_e_dist.distance_rate;
            END IF;

        END IF;

        IF ( l_status = SWMS_NORMAL ) THEN
            l_status := lmg_get_pkup_frm_slt_mvmnt(i_batch_no, 'HST', i_e_rec, l_pickup);
        END IF;

        IF ( l_status = SWMS_NORMAL ) THEN
            l_status := lmg_get_drop_to_slot_movement(i_batch_no, i_e_rec, l_drop, 'HST');
        END IF;

        IF ( l_status = SWMS_NORMAL ) THEN
            BEGIN
                UPDATE batch
                SET
                    kvi_distance = l_distance + l_pickup + l_drop + l_l_dist.tia_time + l_e_dist.tia_time,
                    abc_distance = l_l_dist.total_distance + l_e_dist.total_distance
                WHERE
                    batch_no = i_batch_no;

            EXCEPTION
                WHEN OTHERS THEN
                    pl_text_log.ins_msg_async('WARN', l_func_name, 'LMG ORACLE Update of kvi_distance for XFR batch failed. Distance= '||l_distance||' pickup= '||l_pickup||' Drop= '||l_drop, sqlcode, sqlerrm
                    );
                    l_status := RF.STATUS_LM_BATCH_UPD_FAIL;
            END;

            l_status := lmg_load_goaltime(i_batch_no, i_is_parent);
        END IF;

        pl_text_log.ins_msg_async('INFO', l_func_name, 'END lmg_calc_hs_xfer_goaltime', sqlcode, sqlerrm);
        RETURN l_status;
    END lmg_calc_hs_xfer_goaltime;

/*********************************************************************************
**   FUNCTION:
**   lmg_calc_dmd_hs_xfer_goaltime()
**   
**   Description:
**      This functions calculates the discreet LM goaltime for a
**      demand replenisment home slot transfer batch.  The resultant value is
**      loaded into the kvi_distance of the batch. 
**
**      A demand replenisment home slot transfer batch is the return to
**      reserve of a partially completed demand replenishment.
**
**   PARAMETERS:
**      i_batch_no  - Batch being processed.
**      i_e_rec     - Pointer to equipment tmus.
**      i_is_parent - Flag denoting if batch is parent or not.
**      
**  Return Values:
**      RF.STATUS_LM_BATCH_UPD_FAIL -- If unable to update the labor batch.
**
**        DATE         DESIGNER       COMMENTS
**     01/04/2020      ksar9933     Initial version0.0
***********************************************************************************/

    FUNCTION lmg_calc_dmd_hs_xfer_goaltime (
        i_batch_no    IN            batch.batch_no%TYPE,
        i_e_rec       IN            pl_lm_goal_pb.type_lmc_equip_rec,
        i_is_parent   IN            VARCHAR2
    ) RETURN NUMBER AS

        l_func_name    VARCHAR2(50) := 'pl_lm_goaltime.lmg_calc_dmd_hs_xfer_goaltime';
        l_status       NUMBER := SWMS_NORMAL;
        l_distance     NUMBER := 0;
        l_l_dist       lmd_distance_obj := lmd_distance_obj(0,0,0,0,0,0);
        l_e_dist       lmd_distance_obj := lmd_distance_obj(0,0,0,0,0,0);
        l_last_point   VARCHAR2(11);
        l_pickup       NUMBER := 0;
        l_drop         NUMBER := 0;
    BEGIN
        pl_text_log.ins_msg_async('INFO', l_func_name, 'START lmg_calc_dmd_hs_xfer_goaltime(i_batch_no='
                                            || i_batch_no
                                            || ', i_e_rec.equip_id'
                                            || i_e_rec.equip_id
                                            || ', i_is_parent='
                                            || i_is_parent
                                            || ')', sqlcode, sqlerrm);
        
        g_travel_loaded := 'Y';

    /*
    **  FALSE in call to lmd_get_batch_dist indicates not a 3 part move.
    */
        l_status := pl_lm_distance.lmd_get_batch_dist(i_batch_no, i_is_parent, i_e_rec, 1,l_last_point, l_l_dist); 
        IF ( l_status = SWMS_NORMAL ) THEN
            l_l_dist.distance_rate := ( l_l_dist.accel_distance * i_e_rec.accel_rate_loaded ) + ( l_l_dist.decel_distance * i_e_rec
            .decel_rate_loaded ) + ( l_l_dist.travel_distance * i_e_rec.trav_rate_loaded );
        /*
        ** If the user is signing onto an indirect batch then
        ** there will be no "from" location for the indirect batch.
        ** The distance for the forklift batch being signed off of will
        ** be from the "from" location to the "to" location of the
        ** forklift batch.
        ** Function "lmd_get_next_point_dist" will return RF.STATUS_NO_LM_BATCH_FOUND
        ** when the user is signing onto an indirect batch.
        */

            g_travel_loaded := 'N';

        /*
        ** FALSE in call to lmd_get_batch_dist indicates not a 3 part move.
        */
            l_status := pl_lm_distance.lmd_get_next_point_dist(i_batch_no,  g_user_id, l_last_point, i_e_rec, 1, l_e_dist); 
            IF ( l_status = RF.STATUS_NO_LM_BATCH_FOUND ) THEN
                l_distance := l_l_dist.distance_rate;
                l_status := SWMS_NORMAL;
            ELSIF ( l_status = SWMS_NORMAL ) THEN
                l_e_dist.distance_rate := ( l_e_dist.accel_distance * i_e_rec.accel_rate_empty ) + ( l_e_dist.decel_distance * i_e_rec
                .decel_rate_empty ) + ( l_e_dist.travel_distance * i_e_rec.trav_rate_empty );

                l_distance := l_l_dist.distance_rate + l_e_dist.distance_rate;
            END IF;

        END IF;

        IF ( l_status = SWMS_NORMAL ) THEN
            l_status := lmg_get_pkup_frm_slt_mvmnt(i_batch_no, 'DHT', i_e_rec, l_pickup);
        END IF;

        IF ( l_status = SWMS_NORMAL ) THEN
            l_status := lmg_get_drop_to_slot_movement(i_batch_no, i_e_rec, l_drop, 'DHT');
        END IF;

        IF ( l_status = SWMS_NORMAL ) THEN
            BEGIN
                UPDATE batch
                SET
                    kvi_distance = l_distance + l_pickup + l_drop + l_l_dist.tia_time + l_e_dist.tia_time,
                    abc_distance = l_l_dist.total_distance + l_e_dist.total_distance
                WHERE
                    batch_no = i_batch_no;

            EXCEPTION
                WHEN OTHERS THEN
                    pl_text_log.ins_msg_async('WARN', l_func_name, 'LMG ORACLE Update of kvi_distance for XFR batch failed. Distance= '||l_distance||' pickup= '||l_pickup||' Drop= '||l_drop, sqlcode, sqlerrm
                    );
                    l_status := RF.STATUS_LM_BATCH_UPD_FAIL;
            END;

            l_status := lmg_load_goaltime(i_batch_no, i_is_parent);
        END IF;

        pl_text_log.ins_msg_async('INFO', l_func_name, 'END lmg_calc_dmd_hs_xfer_goaltime', sqlcode, sqlerrm);
        RETURN l_status;
    END lmg_calc_dmd_hs_xfer_goaltime;	

/*********************************************************************************
**   FUNCTION:
**    lmg_calc_transfer_goaltime()
**   
**   Description:
**      This functions calculates the discreet LM goaltime for a
**      transfer batch.  The resultant value is loaded into kvi_distance
**      of the batch.  The transfer batch is from a reserve slot to a
**      reserve slot.  The pickup of the pallets is handled the same way
**      as a non-demand replenishment and the drop to the destination slot
**      is handled the same way as a putaway.
**
**   PARAMETERS:
**      i_batch_no  - Batch being processed.
**      i_e_rec     - Pointer to equipment tmus.
**      i_is_parent - Flag denoting if batch is parent or not.
**      
**      RETURN VALUES:
**      RF.STATUS_LM_BATCH_UPD_FAIL -- If unable to update labor batch.
**
**        DATE         DESIGNER       COMMENTS
**     01/04/2020      ksar9933     Initial version0.0
***********************************************************************************/

    FUNCTION lmg_calc_transfer_goaltime (
        i_batch_no    IN            batch.batch_no%TYPE,
        i_e_rec       IN            pl_lm_goal_pb.type_lmc_equip_rec,
        i_is_parent   IN            VARCHAR2
    ) RETURN NUMBER AS

        l_func_name    VARCHAR2(50) := 'pl_lm_goaltime.lmg_calc_transfer_goaltime';
        l_status       NUMBER := SWMS_NORMAL;
        l_distance     NUMBER := 0;
        l_l_dist       lmd_distance_obj := lmd_distance_obj(0,0,0,0,0,0);
        l_e_dist       lmd_distance_obj := lmd_distance_obj(0,0,0,0,0,0);
        l_last_point   VARCHAR2(11);
        l_pickup       NUMBER := 0;
        l_drop         NUMBER := 0;
        l_batch_no_1              batch.batch_no%TYPE ;
        l_batch_no_2              batch.batch_no%TYPE ;
    BEGIN
        pl_text_log.ins_msg_async('INFO', l_func_name, 'START lmg_calc_transfer_goaltime(i_batch_no='
                                            || i_batch_no
                                            || ', i_e_rec.equip_id'
                                            || i_e_rec.equip_id
                                            || ', i_is_parent='
                                            || i_is_parent
                                            || ')', sqlcode, sqlerrm);

        g_travel_loaded := 'Y';

/*
    **  FALSE in call to lmd_get_batch_dist indicates not a 3 part move.
    */
        l_status := pl_lm_distance.lmd_get_batch_dist(i_batch_no, i_is_parent, i_e_rec, 1, l_last_point, l_l_dist); 
        IF ( l_status = SWMS_NORMAL ) THEN
            l_l_dist.distance_rate := ( l_l_dist.accel_distance * i_e_rec.accel_rate_loaded ) + ( l_l_dist.decel_distance * i_e_rec
            .decel_rate_loaded ) + ( l_l_dist.travel_distance * i_e_rec.trav_rate_loaded );
/*
        ** If the user is signing onto an indirect batch then
        ** there will be no "from" location for the indirect batch.
        ** The distance for the forklift batch being signed off of will
        ** be from the "from" location to the "to" location of the
        ** forklift batch.
        ** Function "lmd_get_next_point_dist" will return RF.STATUS_NO_LM_BATCH_FOUND
        ** when the user is signing onto an indirect batch.
        */

            g_travel_loaded := 'N';	
								 
	/*
        ** FALSE in call to lmd_get_batch_dist indicates not a 3 part move.
        */
            l_status := pl_lm_distance.lmd_get_next_point_dist( i_batch_no,  g_user_id, l_last_point, i_e_rec, 1, l_e_dist); 
            IF ( l_status = RF.STATUS_NO_LM_BATCH_FOUND ) THEN
                l_distance := l_l_dist.distance_rate;
                l_status := SWMS_NORMAL;
            ELSIF ( l_status = SWMS_NORMAL ) THEN
                l_e_dist.distance_rate := ( l_e_dist.accel_distance * i_e_rec.accel_rate_empty ) + ( l_e_dist.decel_distance * i_e_rec
                .decel_rate_empty ) + ( l_e_dist.travel_distance * i_e_rec.trav_rate_empty );

                l_distance := l_l_dist.distance_rate + l_e_dist.distance_rate;
            END IF;

        END IF;

        IF ( l_status = SWMS_NORMAL ) THEN
            l_status := lmg_get_pkup_frm_slt_mvmnt(i_batch_no, 'XFR', i_e_rec, l_pickup);
        END IF;

        IF ( l_status = SWMS_NORMAL ) THEN
      
            l_status := lmg_get_drop_to_slot_movement(i_batch_no, i_e_rec, l_drop, 'XFR');
        
        END IF;

        IF ( l_status = SWMS_NORMAL ) THEN
            BEGIN
                UPDATE batch
                SET
                    kvi_distance = l_distance + l_pickup + l_drop + l_l_dist.tia_time + l_e_dist.tia_time,
                    abc_distance = l_l_dist.total_distance + l_e_dist.total_distance
                WHERE
                    batch_no = i_batch_no;

            EXCEPTION
                WHEN OTHERS THEN
                    pl_text_log.ins_msg_async('WARN', l_func_name, 'LMG ORACLE Update of kvi_distance for XFR batch failed. Distance= '||l_distance||' pickup= '||l_pickup||' Drop= '||l_drop, sqlcode, sqlerrm
                    );
                    l_status := RF.STATUS_LM_BATCH_UPD_FAIL;
            END;

            l_status := lmg_load_goaltime(i_batch_no, i_is_parent);
        END IF;

        pl_text_log.ins_msg_async('INFO', l_func_name, 'END lmg_calc_transfer_goaltime', sqlcode, sqlerrm);
        RETURN l_status;
    END lmg_calc_transfer_goaltime;

/*********************************************************************************
**   FUNCTION:
**    lmg_calc_haul_goaltime()
**   
**   Description:
**      This functions calculates the discreet LM goaltime for a
**      haul batch.  The resultant value is loaded into the kvi_distance
**      of the batch.
**
**   PARAMETERS:
**      i_batch_no  - Batch being processed.
**      i_e_rec     - Pointer to equipment tmus.
**      i_is_parent - Flag denoting if batch is parent or not.
**      
**      RETURN VALUES:
**     RF.STATUS_LM_BATCH_UPD_FAIL -- If unable to update labor batch.
**
**        DATE         DESIGNER       COMMENTS
**     01/04/2020      ksar9933     Initial version0.0
***********************************************************************************/

    FUNCTION lmg_calc_haul_goaltime (
        i_batch_no    IN            batch.batch_no%TYPE,
        i_e_rec       IN            pl_lm_goal_pb.type_lmc_equip_rec,
        i_is_parent   IN            VARCHAR2
    ) RETURN NUMBER AS

        l_func_name      VARCHAR2(50) := 'pl_lm_goaltime.lmg_calc_haul_goaltime';
        l_status         NUMBER := SWMS_NORMAL;
        l_distance       NUMBER := 0;
        l_l_dist         lmd_distance_obj := lmd_distance_obj(0,0,0,0,0,0);
        l_e_dist         lmd_distance_obj := lmd_distance_obj(0,0,0,0,0,0);
        l_last_point     VARCHAR2(11);
        l_pickup         NUMBER := 0;
        l_drop           NUMBER := 0;
        l_record_count   NUMBER;
    BEGIN
        pl_text_log.ins_msg_async('INFO', l_func_name, 'START lmg_calc_haul_goaltime(i_batch_no='
                                            || i_batch_no
                                            || ', i_e_rec.equip_id'
                                            || i_e_rec.equip_id
                                            || ', i_is_parent='
                                            || i_is_parent
                                            || ')', sqlcode, sqlerrm);

        g_travel_loaded := 'Y';
        l_status := pl_lm_distance.lmd_get_batch_dist(i_batch_no, i_is_parent, i_e_rec, 1, l_last_point, l_l_dist); 
        IF ( l_status = SWMS_NORMAL ) THEN
            l_l_dist.distance_rate := ( l_l_dist.accel_distance * i_e_rec.accel_rate_loaded ) + ( l_l_dist.decel_distance * i_e_rec
            .decel_rate_loaded ) + ( l_l_dist.travel_distance * i_e_rec.trav_rate_loaded );
      /*
        ** If the user is signing onto an indirect batch then
        ** there will be no "from" location for the indirect batch.
        ** The distance for the forklift batch being signed off of will
        ** be from the "from" location to the "to" location of the
        ** forklift batch.
        ** Function "lmd_get_next_point_dist" will return RF.STATUS_NO_LM_BATCH_FOUND
        ** when the user is signing onto an indirect batch.
        */

            g_travel_loaded := 'N';

        /*
        ** FALSE in call to lmd_get_batch_dist indicates not a 3 part move.
        */
            l_status := pl_lm_distance.lmd_get_next_point_dist(i_batch_no,  g_user_id, l_last_point, i_e_rec, 1, l_e_dist); 
            IF ( l_status = RF.STATUS_NO_LM_BATCH_FOUND ) THEN
                l_distance := l_l_dist.distance_rate;
                l_status := SWMS_NORMAL;
            ELSIF ( l_status = SWMS_NORMAL ) THEN
                l_e_dist.distance_rate := ( l_e_dist.accel_distance * i_e_rec.accel_rate_empty ) + ( l_e_dist.decel_distance * i_e_rec
                .decel_rate_empty ) + ( l_e_dist.travel_distance * i_e_rec.trav_rate_empty );

                l_distance := l_l_dist.distance_rate + l_e_dist.distance_rate;
            END IF;

        END IF;

        IF ( l_status = SWMS_NORMAL ) THEN
            l_status := lmg_get_pkup_dr_to_slt_mvmnt(i_batch_no, i_e_rec, l_pickup);
        END IF;

        IF ( l_status = SWMS_NORMAL ) THEN
 /*
        ** Check if there are putaways batches that are child batches of 
        ** the haul batch.
        */
            BEGIN
                SELECT
                    COUNT(*)
                INTO l_record_count
                FROM
                    batch
                WHERE
                    parent_batch_no = i_batch_no
                    AND batch_no LIKE 'FP%';

            EXCEPTION
                WHEN OTHERS THEN
                    pl_text_log.ins_msg_async('WARN', l_func_name, 'LMF ORACLE failed to find count of batches with parent batch# = KEY.', sqlcode
                    , sqlerrm);
                    l_status := RF.STATUS_NO_LM_BATCH_FOUND;
            END;

            IF ( l_status = SWMS_NORMAL ) THEN
                IF ( i_batch_no = 'X' AND i_is_parent = 'Y' AND l_record_count > 0 ) THEN

/*
                ** Func1 in putaway and the HX batch has child putaway batches.
                */
                    l_status := lmg_get_drop_to_slot_movement(i_batch_no, i_e_rec, l_drop, 'PUT');
                ELSE
                    l_status := lmg_get_drop_to_point_movement(i_batch_no, i_e_rec, l_drop);
                END IF;

            END IF;

        END IF;

        IF ( l_status = SWMS_NORMAL ) THEN
            BEGIN
                UPDATE batch
                SET
                    kvi_distance = l_distance + l_pickup + l_drop + l_l_dist.tia_time + l_e_dist.tia_time,
                    abc_distance = l_l_dist.total_distance + l_e_dist.total_distance
                WHERE
                    batch_no = i_batch_no;

            EXCEPTION
                WHEN OTHERS THEN
                    pl_text_log.ins_msg_async('WARN', l_func_name, 'LMG ORACLE Update of distance for batch failed. Distance= '||l_distance||' pickup= '||l_pickup||' Drop= '||l_drop, sqlcode, sqlerrm);
                    l_status := RF.STATUS_LM_BATCH_UPD_FAIL;
            END;

            l_status := lmg_load_goaltime(i_batch_no, i_is_parent);
        END IF;

        pl_text_log.ins_msg_async('INFO', l_func_name, 'END lmg_calc_haul_goaltime haul distance='
                                            || l_distance
                                            || ', pickup='
                                            || l_pickup
                                            || ', drop='
                                            || l_drop, sqlcode, sqlerrm);

        RETURN l_status;
    END lmg_calc_haul_goaltime;

/*********************************************************************************
**   FUNCTION:
**   lmg_calculate_goaltime()
**   
**   Description:
**      This functions calculates the discreet LM goaltime for a forklift
**      batch.
**
**   PARAMETERS:
**      i_batch_no  - Batch being processed.
**      i_equip_id  - Equipment ID.
**      i_is_parent - Flag denoting if batch is parent or not.
**      
**  Return Values:
**      Various values depending on what the called functions return.
**
**        DATE         DESIGNER       COMMENTS
**     01/04/2020      ksar9933     Initial version0.0
***********************************************************************************/

    FUNCTION lmg_calculate_goaltime (
        i_batch_no    IN            batch.batch_no%TYPE,
        i_equip_id    IN            batch.equip_id%TYPE,
        i_is_parent   IN            VARCHAR2
    ) RETURN NUMBER AS

        l_func_name        VARCHAR2(50) := 'pl_lm_goaltime.lmg_calculate_goaltime';
        l_status           NUMBER := SWMS_NORMAL;
        l_e_rec            pl_lm_goal_pb.type_lmc_equip_rec;
        l_r_audit_values   pl_lma.t_audit_values_rec;
        l_batch_no_1              batch.batch_no%TYPE ;
    BEGIN
        pl_text_log.ins_msg_async('INFO', l_func_name, 'START lmg_calculate_goaltime('
                                            || i_batch_no
                                            || ','
                                            || i_equip_id
                                            || ','
                                            || i_is_parent
                                            || ')', sqlcode, sqlerrm);
	/*
    ** Get value of syspar ENABLE_PALLET_FLOW and store in global variable.
    ** If not found, value is null or an error occurs then N is used
    ** as the value.
    */

        
            g_enable_pallet_flow_syspar := pl_common.f_get_syspar('ENABLE_PALLET_FLOW', 'N');
      
            pl_text_log.ins_msg_async('INFO', l_func_name, 'Config_flag_val for ENABLE_PALLET_FLOW = '||g_enable_pallet_flow_syspar, sqlcode, sqlerrm);
       
		
	/* 
    ** Populate the global batch number which is usually used in the forklift
    ** audit but may be used by regular aplog messages if an error occurred.
    ** A lot of functions do not need the batch number in their processing
    ** but if an error occurs having the batch number in the aplog message can
    ** help in identifying the problem.
    */

        g_audit_batch_no := i_batch_no;
	
	/*
    ** Set the audit forklift flag "g_forklift_audit".  If forklift audit is
    ** on then the forklift operations are saved to a table.
    */
        lmg_sel_forklift_audit_syspar(g_forklift_audit);
        
    /*
    ** Populate global variables used in the forklift audit.
    */

        IF ( g_forklift_audit = TRUE1) THEN
            g_e_rec := l_e_rec;
            l_r_audit_values.batch_no := i_batch_no;
            l_r_audit_values.user_id := user;
            l_r_audit_values.audit_func := pl_lma.ct_audit_func_fk;
            l_r_audit_values.r_equip.equip_id := i_equip_id;
            pl_lmg.get_equip_values(l_r_audit_values.r_equip);
            pl_lma.set_audit_on(l_r_audit_values);
        END IF;
	/*
    ** Get the tmu values for the equipment.
    */

        IF ( l_status = SWMS_NORMAL ) THEN
            l_e_rec.equip_id := i_equip_id;
            l_status := lmg_get_equip_values(l_e_rec);
            g_e_rec := l_e_rec;
        END IF;
        IF ( l_status = SWMS_NORMAL ) THEN

/*
        ** Write batch audit summary information.
        */
            IF ( g_forklift_audit = TRUE1) THEN
                lmg_audit_batch_summary(i_batch_no);
            END IF;
            IF ( substr(i_batch_no, 1, 1) = 'H' ) THEN
                l_status := lmg_calc_haul_goaltime(i_batch_no, l_e_rec, i_is_parent);
            ELSIF ( substr(i_batch_no, 1, 1) = 'T' ) THEN
        
            /*
            ** Returns putaway T batch.
            */
                l_status := lmg_calc_putaway_goaltime(i_batch_no, l_e_rec, i_is_parent);
            ELSIF ( substr(i_batch_no, 1, 1) = 'F' ) THEN
		
		/*
            ** The second character in the batch# designates the type of
            ** forklift batch.
            */
                CASE substr(i_batch_no, 2, 1)
                    WHEN 'P' THEN
                        l_status := lmg_calc_putaway_goaltime(i_batch_no, l_e_rec, i_is_parent);
                    WHEN 'N' THEN
                        l_status := lmg_calc_ndm_rpl_goaltime(i_batch_no, l_e_rec, i_is_parent);
                    WHEN 'U' THEN
                        l_status := lmg_calc_pallet_pull_goaltime(i_batch_no, l_e_rec, i_is_parent);
                    WHEN 'R' THEN
                        l_status := lmg_calc_demand_rpl_goaltime(i_batch_no, l_e_rec, i_is_parent);
                    WHEN 'D' THEN
                        l_status := lmg_calc_drop_home_goaltime(i_batch_no, l_e_rec, i_is_parent);
                    WHEN 'H' THEN
                        l_status := lmg_calc_hs_xfer_goaltime(i_batch_no, l_e_rec, i_is_parent);
                    WHEN 'E' THEN
                        l_status := lmg_calc_dmd_hs_xfer_goaltime(i_batch_no, l_e_rec, i_is_parent);
                    WHEN 'I' THEN
                        l_status := 0; --lmg_calc_inv_adj_goaltime(i_batch_no, l_e_rec, i_is_parent);
                    WHEN 'S' THEN
                        l_status := 0; --lmg_calc_swap_goaltime(i_batch_no, l_e_rec, i_is_parent);
                    WHEN 'X' THEN
                        l_status := lmg_calc_transfer_goaltime(i_batch_no, l_e_rec, i_is_parent);
                    ELSE
                        pl_text_log.ins_msg_async('WARN', l_func_name, 'LMG Goal time not calculated,
                                  Batch type not supported.'
                        , sqlcode, sqlerrm);
                        l_status := RF.STATUS_NO_LM_BATCH_FOUND;
                END CASE;
            ELSE
                pl_text_log.ins_msg_async('WARN', l_func_name, 'LMG Goal time not calculated,
                                  Batch type not supported.'
                , sqlcode, sqlerrm);
                l_status := RF.STATUS_NO_LM_BATCH_FOUND;
            END IF;

        END IF;

        pl_text_log.ins_msg_async('INFO', l_func_name, 'Finished  Return Status = ' || l_status, sqlcode, sqlerrm);
        RETURN l_status;
    END lmg_calculate_goaltime;

/*********************************************************************************
**   PROCEDURE:
**    lmg_sel_forklift_audit_syspar
**   
**   Description:
**      This function selects syspar FORKLIFT_AUDIT and puts the value
**      in global variable g_forklift_audit.  This syspar turns on/off
**      forklift auditing.   If the syspar is not found or an oracle
**      error occurs then auditing is set to off.
**
**   PARAMETERS:
**      o_forklift_audit_bln   - Designates if forklift audit is on or off.
**
**        DATE         DESIGNER       COMMENTS
**     01/04/2020      ksar9933     Initial version0.0
***********************************************************************************/

    PROCEDURE lmg_sel_forklift_audit_syspar (
        o_forklift_audit_bln OUT NUMBER
    ) AS
        l_func_name      VARCHAR2(50) := 'pl_lm_goaltime.lmg_sel_forklift_audit_syspar';
        l_syspar_value   VARCHAR2(20);
    BEGIN
        pl_text_log.ins_msg_async('INFO', l_func_name, 'START lmg_sel_forklift_audit_syspar', sqlcode, sqlerrm);
        BEGIN
            l_syspar_value := pl_common.f_get_syspar('FORKLIFT_AUDIT', 'N');
        EXCEPTION
            WHEN OTHERS THEN
                l_syspar_value := 'N';
                pl_text_log.ins_msg_async('WARN', l_func_name, 'Selecting syspar FORKLIFT_AUDIT failed, N will be used.', sqlcode, sqlerrm);
        END;

        IF ( l_syspar_value = 'Y' ) THEN
            o_forklift_audit_bln := true1;
        ELSE
            o_forklift_audit_bln := FALSE0;
        END IF;

        pl_text_log.ins_msg_async('END', l_func_name, 'END lmg_sel_forklift_audit_syspar l_syspar_value=' || l_syspar_value, sqlcode, sqlerrm

        );
    END lmg_sel_forklift_audit_syspar;

/*********************************************************************************
**   FUNCTION:
**   lmg_sel_stack_on_dock_syspar
**   
**   Description:
**      This function selects syspar GIVE_STACK_ON_DOCK_TIME.
**      This syspar designates to include or not include time to stack the
**      pallets on the dock during putaway.  If the syspar is not found or
**      an oracle error occurs then time will be give to stack the pallets.
**
**
**   PARAMETERS:
**      o_give_stack_on_dock_time
**      
**
**        DATE         DESIGNER       COMMENTS
**     01/04/2020      ksar9933     Initial version0.0
***********************************************************************************/

    PROCEDURE lmg_sel_stack_on_dock_syspar (
        o_give_stack_on_dock_time OUT NUMBER
    ) AS

        l_func_name      VARCHAR2(50) := 'pl_lm_goaltime.lmg_sel_stack_on_dock_syspar';
        l_status         NUMBER := SWMS_NORMAL;
        l_syspar_value   VARCHAR2(2);
    BEGIN
        pl_text_log.ins_msg_async('INFO', l_func_name, 'START lmg_sel_stack_on_dock_syspar', sqlcode, sqlerrm);
        BEGIN
            l_syspar_value := pl_common.f_get_syspar('GIVE_STACK_ON_DOCK_TIME', 'Y');
        EXCEPTION
            WHEN OTHERS THEN
                l_syspar_value := 'Y';
                pl_text_log.ins_msg_async('WARN', l_func_name, 'Selecting syspar GIVE_STACK_ON_DOCK_TIME failed, Y will be used.', sqlcode, sqlerrm
                );
        END;

        IF ( l_syspar_value = 'Y' ) THEN
            o_give_stack_on_dock_time := 1;
        ELSE
            o_give_stack_on_dock_time := 0;
        END IF;

        pl_text_log.ins_msg_async('END', l_func_name, 'END lmg_sel_stack_on_dock_syspar l_syspar_value=' || l_syspar_value, sqlcode, sqlerrm

        );
    END lmg_sel_stack_on_dock_syspar;

/*********************************************************************************
**   PROCEDURE:
**    lmg_drop_rotation
**   
**   Description:
**      This function determines if rotation is required for a drop
**      to a deep slot.
**
**   PARAMETERS:
**		i_pal_num_recs			- Number of pallet records in the list.
**      i_pals                  - Pointer to pallet list.
**      i_num_pallets           - Number of pallets in the pallet list.
**      i_inv                   - Pointer to pallets already in the destination.
**      o_drop_type             - Designates type of drop.
**      o_num_drops_completed   - The number of putaways completed on same PO.
**      o_num_pending_putaways  - The number of putaways on same PO not yet
**                                completed.  Does not include current putaway.
**      o_pallets_to_move       - Number of pallets to remove from slot for
**                                rotation.
**      o_remove_existing_inv   - Flag designating if existing inv needs to be
**                                removed.
**      o_putback_existing_inv  - Flag designating if existing inv needs to be
**                                putback.
**      o_existing_inv -          Designates if the existing pallets is in the
**                                slot or has been previous removed and is in
**                                the aisle.
**      o_total_pallets_IN_SLOT - Total number of pallets that will be in
**                                the slot after all the putaways on the PO
**                                are completed.
**
**        DATE         DESIGNER       COMMENTS
**     01/04/2020      ksar9933     Initial version0.0
***********************************************************************************/

    PROCEDURE lmg_drop_rotation (
        i_pal_num_recs            IN                        NUMBER,
        i_pals                    IN                        pl_lm_goal_pb.tbl_lmg_pallet_rec,
        i_num_pallets             IN                        NUMBER,
        i_num_recs                IN                        NUMBER,
        i_inv                     IN                        pl_lm_goal_pb.tbl_lmg_inv_rec,
        o_drop_type               OUT                       NUMBER,
        o_num_drops_completed     OUT                       NUMBER,
        o_num_pending_putaways    OUT                       NUMBER,
        o_pallets_to_move         OUT                       NUMBER,
        o_remove_existing_inv     OUT                       NUMBER,
        o_putback_existing_inv    OUT                       NUMBER,
        o_existing_inv            OUT                       NUMBER,
        o_total_pallets_IN_SLOT   OUT                       NUMBER
    ) AS

        l_func_name               VARCHAR2(50) := 'pl_lm_goaltime.lmg_drop_rotation';
        l_num_pallets_same_item   NUMBER;
        l_pindex                  NUMBER;
        l_ret_val                 NUMBER := SWMS_NORMAL;
        l_index                   NUMBER := 1;
    BEGIN
        pl_text_log.ins_msg_async('INFO', l_func_name, 'START lmg_drop_rotation', sqlcode, sqlerrm);
        l_pindex := i_num_pallets;
		/*
         ** Count the number of pallets already in the destination slot
         ** that are the same item as the pallet being dropped.
         */
        l_num_pallets_same_item := 0;
        WHILE ( l_index <= i_num_recs ) LOOP
            IF ( i_inv(l_index).prod_id = i_pals(l_pindex).prod_id ) AND ( i_inv(l_index).cpv = i_pals(l_pindex).cpv ) THEN
                l_num_pallets_same_item := l_num_pallets_same_item + 1;
            END IF;

            l_index := l_index + 1;
        END LOOP;

        IF ( ( substr(i_pals(l_pindex).batch_no, 1, 1) = LMF.FORKLIFT_BATCH_ID ) AND ( substr(i_pals(l_pindex).batch_no, 2, 1) = LMF.FORKLIFT_PUTAWAY

        ) ) THEN 
	        /* ret_val is ignored at this time. */
            l_ret_val := pl_lm_forklift.lmf_what_putaway_is_this(i_pals(l_pindex).pallet_id, o_drop_type, o_num_drops_completed, o_num_pending_putaways
            );

            IF ( ( l_num_pallets_same_item = 0 ) OR ( o_num_drops_completed - l_num_pallets_same_item = 0 ) ) THEN
                o_pallets_to_move := 0;
                o_remove_existing_inv := FALSE0;
                o_putback_existing_inv := FALSE0;
                o_existing_inv := IN_SLOT;
            ELSE
                o_pallets_to_move := i_num_recs - o_num_drops_completed;
	
	        /*
            ** o_pallets_to_move can be negative if it is a multi-pallet putaway
            ** to the same slot.
            */
                IF ( o_pallets_to_move < 0 ) THEN
                    o_pallets_to_move := 0;
                END IF;
                IF ( ( o_drop_type = ONLY_PUTAWAY_TO_SLOT OR o_drop_type = FIRST_PUTAWAY_TO_SLOT ) AND o_pallets_to_move > 0 ) THEN
                    o_remove_existing_inv := TRUE1;
                    o_existing_inv := IN_SLOT;
                ELSE
                    o_remove_existing_inv := FALSE0;
                    o_existing_inv := IN_AISLE;
                END IF;

                IF ( ( ( o_drop_type = ONLY_PUTAWAY_TO_SLOT ) OR ( o_drop_type = LAST_PUTAWAY_TO_SLOT ) ) AND ( o_pallets_to_move > 0 ) ) THEN
                    o_putback_existing_inv := TRUE1;
                ELSE
                    o_putback_existing_inv := FALSE0;
                END IF;

            END IF;
	
	         
	           /*
              ** Calculate the number of pallets that will be in the slot after
              ** all the putaways on the PO are completed.
              */

            o_total_pallets_IN_SLOT := 0;
            l_index := l_pindex - 1;
            WHILE ( l_index >= 0 ) LOOP
                IF ( i_pals(l_index).multi_pallet_drop_to_slot = 'Y' ) THEN
                    o_total_pallets_IN_SLOT := o_total_pallets_IN_SLOT + 1;
                END IF;

                l_index := l_index - 1;
            END LOOP;

        ELSE 
	        /*
             ** The drop is not a putaway.
             */
            o_drop_type := NON_PUTAWAY;
            o_num_drops_completed := 0;
            IF ( l_num_pallets_same_item = 0 ) THEN
                o_pallets_to_move := 0;
                o_remove_existing_inv := FALSE0;
                o_putback_existing_inv := FALSE0;
                o_existing_inv := IN_SLOT;
            ELSE
                o_pallets_to_move := i_num_recs;
                o_remove_existing_inv := TRUE1;
                o_putback_existing_inv := TRUE1;
                o_existing_inv := IN_SLOT;
            END IF;

        END IF;

        pl_text_log.ins_msg_async('INFO', l_func_name, 'END lmg_drop_rotation.'
                                    || ' Drop type= '
                                    || o_drop_type
                                    || ' drops completed= '
                                    || o_num_drops_completed
                                    || ' pending putaways= '
                                    || o_num_pending_putaways
                                    || ' palletes to move= '
                                    || o_pallets_to_move
                                    || ' remove existing inv= '
                                    || o_remove_existing_inv
                                    || ' putback existing inv= '
                                    || o_putback_existing_inv
                                    || ' existing inv= '
                                    || o_existing_inv
                                    || ' totals pallets in slot= '
                                    || o_total_pallets_in_slot, sqlcode, sqlerrm);
    END lmg_drop_rotation;

/*********************************************************************************
**   FUNCTION:
**   lmg_3_part_move_audit_message
**   
**   Description:
**      This function writes forklift audit comments about the 3 part move.
**      Called when 3 part move is active.
**
**   PARAMETERS:
**      i_psz_loc  - The location that has 3 part move active.
**      
**
**        DATE         DESIGNER       COMMENTS
**     01/04/2020      ksar9933     Initial version0.0
***********************************************************************************/

    PROCEDURE lmg_3_part_move_audit_message (
        i_psz_loc IN VARCHAR2
    ) AS
        l_func_name    VARCHAR2(50) := 'pl_lm_goaltime.lmg_3_part_move_audit_message';
        l_sz_message   VARCHAR2(200);
    BEGIN
        pl_text_log.ins_msg_async('INFO', l_func_name, 'START lmg_3_part_move_audit_message', sqlcode, sqlerrm);
        lmg_audit_cmt(g_audit_batch_no, '3 part move is active for demand replenishments', -1);
        l_sz_message := 'for the pallet type of slot ' || i_psz_loc;
        lmg_audit_cmt(g_audit_batch_no, l_sz_message, -1);
        lmg_audit_cmt(g_audit_batch_no, 'Time will be given to travel:', -1);
        lmg_audit_cmt(g_audit_batch_no, '  - From the home slot to the reserve slot.', -1);
        lmg_audit_cmt(g_audit_batch_no, '   - From the reserve slot to the home slot.', -1);
        lmg_audit_cmt(g_audit_batch_no, ' - From the home slot to the next home slot if the next batch is a demand replenishment otherwise to the next batchs from location.'
        , -1);
        pl_text_log.ins_msg_async('INFO', l_func_name, 'END lmg_3_part_move_audit_message', sqlcode, sqlerrm);
    END lmg_3_part_move_audit_message;

/*********************************************************************************
**   PROCEDURE:
**    lmg_audit_movement
**   
**   Description:
**     
**
**  PARAMETERS:
**      i_movement      - Type of forklift movement.
**      i_batch_no      - Batch number.
**      i_e_rec         - Equipment record.
**      i_fork_movement - Frequency.  Either 1 or a distance.  The distance can
**                        be either feet or inches.
**      i_cmt           - Comment.  It will be truncated if its length
**                        is greater than AUDIT_CMT_LEN.
**
**        DATE         DESIGNER       COMMENTS
**     01/04/2020      ksar9933     Initial version0.0
***********************************************************************************/

    PROCEDURE lmg_audit_movement (
        i_movement        IN                VARCHAR2,
        i_batch_no        IN                batch.batch_no%TYPE,
        i_e_rec           IN                pl_lm_goal_pb.type_lmc_equip_rec,
        i_fork_movement   IN                NUMBER,
        i_cmt             IN                VARCHAR2
    ) AS
        l_func_name   VARCHAR2(50) := 'pl_lm_goaltime.lmg_audit_movement';
        l_audit_rec   lmg_audit_rec;
    BEGIN
        pl_text_log.ins_msg_async('INFO', l_func_name, 'START lmg_audit_movement', sqlcode, sqlerrm);
        l_audit_rec.batch_no := i_batch_no;
        l_audit_rec.frequency := i_fork_movement;
        l_audit_rec.cmt := i_cmt;
        l_audit_rec.user_id := g_user_id;
        l_audit_rec.equip_id := i_e_rec.equip_id;
        lmg_audit_forklift_movement(i_movement, i_e_rec, l_audit_rec);
        pl_text_log.ins_msg_async('INFO', l_func_name, 'END lmg_audit_movement', sqlcode, sqlerrm);
    END lmg_audit_movement;

/*********************************************************************************
**   PROCEDURE:
**   lmg_audit_forklift_movement
**   
**   Description:
**   
**   PARAMETERS:
**      i_movement
**      i_e_rec
**      io_audit_rec
**
**        DATE         DESIGNER       COMMENTS
**     01/04/2020      ksar9933     Initial version0.0
***********************************************************************************/

    PROCEDURE lmg_audit_forklift_movement (
        i_movement     IN             VARCHAR2,
        i_e_rec        IN             pl_lm_goal_pb.type_lmc_equip_rec,
        io_audit_rec   IN OUT         lmg_audit_rec
    ) AS
        l_func_name   VARCHAR2(50) := 'pl_lm_goaltime.lmg_audit_forklift_movement';
        l_status      NUMBER := SWMS_NORMAL;
    BEGIN
        pl_text_log.ins_msg_async('INFO', l_func_name, 'START lmg_audit_forklift_movement', sqlcode, sqlerrm);
        IF ( i_movement = 'TRVLD' ) THEN
            io_audit_rec.operation := i_movement;
            io_audit_rec.time := i_e_rec.trav_rate_loaded;
        ELSIF i_movement = 'DECLD' THEN
            io_audit_rec.operation := i_movement;
            io_audit_rec.time := i_e_rec.decel_rate_loaded;
        ELSIF i_movement = 'ACCLD' THEN
            io_audit_rec.operation := i_movement;
            io_audit_rec.time := i_e_rec.accel_rate_loaded;
        ELSIF i_movement = 'LL' THEN
            io_audit_rec.operation := i_movement;
            io_audit_rec.time := i_e_rec.ll;
        ELSIF i_movement = 'RL' THEN
            io_audit_rec.operation := i_movement;
            io_audit_rec.time := i_e_rec.rl;
        ELSIF i_movement = 'TRVEMP' THEN
            io_audit_rec.operation := i_movement;
            io_audit_rec.time := i_e_rec.trav_rate_empty;
        ELSIF i_movement = 'DECEMP' THEN
            io_audit_rec.operation := i_movement;
            io_audit_rec.time := i_e_rec.decel_rate_empty;
        ELSIF i_movement = 'ACCEMP' THEN
            io_audit_rec.operation := i_movement;
            io_audit_rec.time := i_e_rec.accel_rate_empty;
        ELSIF i_movement = 'LE' THEN
            io_audit_rec.operation := i_movement;
            io_audit_rec.time := i_e_rec.le;
        ELSIF i_movement = 'RE' THEN
            io_audit_rec.operation := i_movement;
            io_audit_rec.time := i_e_rec.re;
        ELSIF i_movement = 'DS' THEN
            io_audit_rec.operation := i_movement;
            io_audit_rec.time := i_e_rec.ds;
        ELSIF i_movement = 'APOF' THEN
            io_audit_rec.operation := i_movement;
            io_audit_rec.time := i_e_rec.apof;
        ELSIF i_movement = 'MEPOF' THEN
            io_audit_rec.operation := i_movement;
            io_audit_rec.time := i_e_rec.mepof;
        ELSIF i_movement = 'PPOF' THEN
            io_audit_rec.operation := i_movement;
            io_audit_rec.time := i_e_rec.ppof;
        ELSIF i_movement = 'APOS' THEN
            io_audit_rec.operation := i_movement;
            io_audit_rec.time := i_e_rec.apos;
        ELSIF i_movement = 'MEPOS' THEN
            io_audit_rec.operation := i_movement;
            io_audit_rec.time := i_e_rec.mepos;
        ELSIF i_movement = 'PPOS' THEN
            io_audit_rec.operation := i_movement;
            io_audit_rec.time := i_e_rec.ppos;
        ELSIF i_movement = 'APIR' THEN
            io_audit_rec.operation := i_movement;
            io_audit_rec.time := i_e_rec.apir;
        ELSIF i_movement = 'MEPIR' THEN
            io_audit_rec.operation := i_movement;
            io_audit_rec.time := i_e_rec.mepir;
        ELSIF i_movement = 'PPIR' THEN
            io_audit_rec.operation := i_movement;
            io_audit_rec.time := i_e_rec.ppir;
        ELSIF i_movement = 'BT90' THEN
            io_audit_rec.operation := i_movement;
            io_audit_rec.time := i_e_rec.bt90;
        ELSIF i_movement = 'BP' THEN
            io_audit_rec.operation := i_movement;
            io_audit_rec.time := i_e_rec.bp;
        ELSIF i_movement = 'TID' THEN
            io_audit_rec.operation := i_movement;
            io_audit_rec.time := i_e_rec.tid;
        ELSIF i_movement = 'TIA' THEN
            io_audit_rec.operation := i_movement;
            io_audit_rec.time := i_e_rec.tia;
        ELSIF i_movement = 'TIR' THEN
            io_audit_rec.operation := i_movement;
            io_audit_rec.time := i_e_rec.tir;
        ELSIF i_movement = 'APIDI' THEN
            io_audit_rec.operation := i_movement;
            io_audit_rec.time := i_e_rec.apidi;
        ELSIF i_movement = 'MEPIDI' THEN
            io_audit_rec.operation := i_movement;
            io_audit_rec.time := i_e_rec.mepidi;
        ELSIF i_movement = 'PPIDI' THEN
            io_audit_rec.operation := i_movement;
            io_audit_rec.time := i_e_rec.ppidi;
        ELSIF i_movement = 'TIDI' THEN
            io_audit_rec.operation := i_movement;
            io_audit_rec.time := i_e_rec.tidi;
        ELSIF i_movement = 'APIPB' THEN
            io_audit_rec.operation := i_movement;
            io_audit_rec.time := i_e_rec.apipb;
        ELSIF i_movement = 'MEPIPB' THEN
            io_audit_rec.operation := i_movement;
            io_audit_rec.time := i_e_rec.mepipb;
        ELSIF i_movement = 'PPIPB' THEN
            io_audit_rec.operation := i_movement;
            io_audit_rec.time := i_e_rec.ppipb;
        ELSIF i_movement = 'APIDD' THEN
            io_audit_rec.operation := i_movement;
            io_audit_rec.time := i_e_rec.apidd;
        ELSIF i_movement = 'MEPIDD' THEN
            io_audit_rec.operation := i_movement;
            io_audit_rec.time := i_e_rec.mepidd;
        ELSIF i_movement = 'PPIDD' THEN
            io_audit_rec.operation := i_movement;
            io_audit_rec.time := i_e_rec.ppidd;
        ELSE
            pl_text_log.ins_msg_async('WARN', l_func_name, 'Unrecognized forklift movement '
                                                || i_movement
                                                || ' in parameter i_movement.  Movement not recorded.', sqlcode, sqlerrm);
        END IF;

        lmg_insert_forklift_audit_rec(io_audit_rec);
        pl_text_log.ins_msg_async('INFO', l_func_name, 'END lmg_audit_forklift_movement', sqlcode, sqlerrm);
    END lmg_audit_forklift_movement;

/*********************************************************************************
**   PROCEDURE:
**   lmg_audit_movement_generic
**   
**   Description:
**      This functions records the forklift movement for the functions 
**      that use generic variables for the different rack types.
**
**   PARAMETERS:
**      i_rack_type - The rack type.   P - Pushback
**                                     I - Drive In
**                                     D - Double Deep
**                                     G - General
**      i_movement  - Type of forklift movement.
**      i_batch_no  - Batch # being processed.
**      i_e_rec     - Equipment used.
**      i_distance  - Distance moved.
**      i_cmt       - Comment
**      
**  Return Values:
**      NONE
**
**        DATE         DESIGNER       COMMENTS
**     01/04/2020      ksar9933     Initial version0.0
***********************************************************************************/

    PROCEDURE lmg_audit_movement_generic (
        i_rack_type   IN            VARCHAR2,
        i_movement    IN            VARCHAR2,
        i_batch_no    IN            batch.batch_no%TYPE,
        i_e_rec       IN            pl_lm_goal_pb.type_lmc_equip_rec,
        i_distance    IN            NUMBER,
        i_cmt         IN            VARCHAR2
    ) AS
        l_func_name VARCHAR2(50) := 'pl_lm_goaltime.lmg_audit_movement_generic';
    BEGIN
        pl_text_log.ins_msg_async('INFO', l_func_name, 'START lmg_audit_movement_generic', sqlcode, sqlerrm);
     /* Validate the movement.  Only certain ones are handled in this
        function. */
        IF ( ( i_movement <> 'TIR' ) AND ( i_movement <> 'APIR' ) AND ( i_movement <> 'MEPIR' ) AND ( i_movement <> 'PPIR' ) ) THEN
   /* Unrecognized rack type.  Write aplog message.  This is not a
           fatal error.  The audit report will not be right though. */
            pl_text_log.ins_msg_async('WARN', l_func_name, 'Unrecognized forklift movement '
                                                || i_movement
                                                || ' in parameter i_movement.  Movement not recorded.', sqlcode, sqlerrm);

        ELSE
            CASE ( i_rack_type )
                WHEN 'P' THEN
                    IF i_movement = 'TIR' THEN
                        lmg_audit_movement('TIR', i_batch_no, i_e_rec, i_distance, i_cmt);
                    ELSIF i_movement = 'APIR' THEN
                        lmg_audit_movement('APIPB', i_batch_no, i_e_rec, i_distance, i_cmt);
                    ELSIF i_movement = 'MEPIR' THEN
                        lmg_audit_movement('MEPIPB', i_batch_no, i_e_rec, i_distance, i_cmt);
                    ELSIF i_movement = 'PPIR' THEN
                        lmg_audit_movement('PPIPB', i_batch_no, i_e_rec, i_distance, i_cmt);
                    END IF;
                WHEN 'I' THEN
                    IF i_movement = 'TIR' THEN
                        lmg_audit_movement('TIDI', i_batch_no, i_e_rec, i_distance, i_cmt);
                    ELSIF i_movement = 'APIR' THEN
                        lmg_audit_movement('APIDI', i_batch_no, i_e_rec, i_distance, i_cmt);
                    ELSIF i_movement = 'MEPIR' THEN
                        lmg_audit_movement('MEPIDI', i_batch_no, i_e_rec, i_distance, i_cmt);
                    ELSIF i_movement = 'PPIR' THEN
                        lmg_audit_movement('PPIDI', i_batch_no, i_e_rec, i_distance, i_cmt);
                    END IF;
                WHEN 'D' THEN
                    IF i_movement = 'TIR' THEN
                        lmg_audit_movement('TIR', i_batch_no, i_e_rec, i_distance, i_cmt);
                    ELSIF i_movement = 'APIR' THEN
                        lmg_audit_movement('APIDD', i_batch_no, i_e_rec, i_distance, i_cmt);
                    ELSIF i_movement = 'MEPIR' THEN
                        lmg_audit_movement('MEPIDD', i_batch_no, i_e_rec, i_distance, i_cmt);
                    ELSIF i_movement = 'PPIR' THEN
                        lmg_audit_movement('PPIDD', i_batch_no, i_e_rec, i_distance, i_cmt);
                    END IF;
                WHEN 'G' THEN
                    IF i_movement = 'TIR' THEN
                        lmg_audit_movement('TIR', i_batch_no, i_e_rec, i_distance, i_cmt);
                    ELSIF i_movement = 'APIR' THEN
                        lmg_audit_movement('APIR', i_batch_no, i_e_rec, i_distance, i_cmt);
                    ELSIF i_movement = 'MEPIR' THEN
                        lmg_audit_movement('MEPIR', i_batch_no, i_e_rec, i_distance, i_cmt);
                    ELSIF i_movement = 'PPIR' THEN
                        lmg_audit_movement('PPIR', i_batch_no, i_e_rec, i_distance, i_cmt);
                    END IF;
                ELSE
	/* Unrecognized rack type.  Write aplog message.  This is
                   not a fatal error but the audit report probably will not
                   be correct. */
                    pl_text_log.ins_msg_async('WARN', l_func_name, 'Unrecognized rack type '
                                                        || i_rack_type
                                                        || ' in parameter i_rack_type', sqlcode, sqlerrm);
            END CASE;
        END IF;

        pl_text_log.ins_msg_async('INFO', l_func_name, 'END lmg_audit_movement_generic', sqlcode, sqlerrm);
    END lmg_audit_movement_generic;

/*********************************************************************************
**   PROCEDURE:
**   lmg_insert_forklift_audit_rec
**   
**   Description:
**      This functions inserts the forklift audit record into the database.
**      If the audit record time or distance fields have a -1 then NULL
**      is inserted for the value.
**
**      If the insert fails then an aplog message is written.  Only
**      one message is written per batch to keep swms.log from growing
**      extremely large.  The most likely reason for the insert to fail
**      is reaching the maximum number of extents on the table or an index.
**      A size limit was placed on the table and indexes to keep database space
**      from being comsumed if the forklift audit syspar was inadvertently
**      left on for an extended period of time.
**
**   PARAMETERS:
**      i_audit_rec - Audit information record.
**      
**  Return Values:
**      NONE
**
**        DATE         DESIGNER       COMMENTS
**     01/04/2020      ksar9933     Initial version0.0
***********************************************************************************/

    PROCEDURE lmg_insert_forklift_audit_rec (
        i_audit_rec IN lmg_audit_rec
    ) AS

        l_func_name       VARCHAR2(50) := 'pl_lm_goaltime.lmg_insert_forklift_audit_rec';
        l_frequency_ind   NUMBER := 0;
        l_time_ind        NUMBER := 0;
        l_tmu_ind         NUMBER := 0;
        l_insert_failed   BOOLEAN := false;
    BEGIN
        pl_text_log.ins_msg_async('INFO', l_func_name, 'START lmg_insert_forklift_audit_rec', sqlcode, sqlerrm);
        IF ( i_audit_rec.tmu = -1 ) THEN
            l_tmu_ind := -1;
        END IF;

        IF ( i_audit_rec.time = -1 ) THEN
            l_time_ind := -1;
        END IF;

        IF ( i_audit_rec.frequency = -1 ) THEN
            l_frequency_ind := -1;
        END IF;

        BEGIN
            INSERT INTO forklift_audit (
                batch_no,
                operation,
                tmu,
                time,
                from_loc,
                to_loc,
                frequency,
                pallet_id,
                cmt,
                user_id,
                equip_id,
                add_date,
                seq_no
            ) VALUES (
                i_audit_rec.batch_no,
                i_audit_rec.operation,
                l_tmu_ind,
                l_time_ind,
                i_audit_rec.from_loc,
                i_audit_rec.to_loc,
                l_frequency_ind,
                i_audit_rec.pallet_id,
                i_audit_rec.cmt,
                i_audit_rec.user_id,
                i_audit_rec.equip_id,
                SYSDATE,
                forklift_audit_seq.NEXTVAL
            );

        EXCEPTION
/*
            ** Insert failed.  Only one aplog message is written per batch
            ** to keep swms.log from growing extremely large.  The insert
            ** failing is not a fatal error but the audit report will not
            ** be correct.
            */
            WHEN OTHERS THEN
                IF ( l_insert_failed = false ) THEN
                    l_insert_failed := true;
                    pl_text_log.ins_msg_async('WARN', l_func_name, 'Insert record into FORKLIFT_AUDIT table failed.', sqlcode, sqlerrm);
                END IF;
        END;

        pl_text_log.ins_msg_async('INFO', l_func_name, 'END lmg_insert_forklift_audit_rec', sqlcode, sqlerrm);
    END lmg_insert_forklift_audit_rec;

/*********************************************************************************
**   FUNCTION:
**    lmg_audit_cmt
**   
**   Description:
**     This function writes a comment to the forklift audit table.
**
**   INPUT PARAMETERS:   
**      i_batch_no  - Batch number being processed.
**      i_comment   - Comment.  It will be truncated if its length
**                    is greater than AUDIT_CMT_LEN.
**      i_distance  - Distance which will be inserted in the FORKLIFT_AUDIT
**                    table in the distance column.  If -1 then null is
**                    inserted into the FORKLIFT audit table.  Used mainly
**                    to record a segment distance between a source location
**                    and a destination location.  The forklift audit shows
**                    the total distance but we also want to show the
**                    distances between the segments.
**
**  RETURN VALUES:
**      None.
**
**        DATE         DESIGNER       COMMENTS
**     01/04/2020      ksar9933     Initial version0.0
***********************************************************************************/

    PROCEDURE lmg_audit_cmt (
        i_batch_no   IN           batch.batch_no%TYPE,
        i_comment    IN           VARCHAR2,
        i_distance   IN           NUMBER
    ) AS
        l_func_name   VARCHAR2(50) := 'pl_lm_goaltime.lmg_audit_cmt';
        l_audit_rec   lmg_audit_rec;
    BEGIN
        pl_text_log.ins_msg_async('INFO', l_func_name, 'START lmg_audit_cmt', sqlcode, sqlerrm);
	/*
    ** Note:  g_user_id and g_e_rec are populated in lmg_calculate_goaltime.
    */
        l_audit_rec.batch_no := i_batch_no;
        l_audit_rec.operation := 'CMT';
        l_audit_rec.frequency := i_distance;
        l_audit_rec.cmt := i_comment;
        l_audit_rec.user_id := g_user_id;
        l_audit_rec.equip_id := g_e_rec.equip_id;
        lmg_insert_forklift_audit_rec(l_audit_rec);
        pl_text_log.ins_msg_async('INFO', l_func_name, 'END lmg_audit_cmt', sqlcode, sqlerrm);
    END lmg_audit_cmt;
	
/*********************************************************************************
**   PROCEDURE:
**    lmg_drop_to_reserve_audit_msg
**   
**   Description:
**      This function writes forklift audit comments for a drop to a reserve
**      slot.
**
**   PARAMETERS:
**      i_pals                - Pointer to pallet list.
**      i_pindex              - Index of top pallet on stack.
**                              i_pindex + 1 is the number of pallets in the
**                              travel stack.
**      i_pallets_IN_SLOT     - # of pallets in the slot.
**      i_num_drops_completed - Number of completed putaways to the slot
**                              on the same PO.  Applies when the current
**                              drop is a putaway.
**
**        DATE         DESIGNER       COMMENTS
**     01/04/2020      ksar9933     Initial version0.0
***********************************************************************************/

    PROCEDURE lmg_drop_to_reserve_audit_msg (
        i_pals                  IN                      pl_lm_goal_pb.tbl_lmg_pallet_rec,
        i_pindex                IN                      NUMBER,
        i_pallets_IN_SLOT       IN                      NUMBER,
        i_num_drops_completed   IN                      NUMBER
    ) AS

        l_buf         VARCHAR2(256);
        l_message     VARCHAR2(1024);
        l_func_name   VARCHAR2(50) := 'pl_lm_goaltime.lmg_drop_to_reserve_audit_msg';
    BEGIN
        pl_text_log.ins_msg_async('INFO', l_func_name, 'START lmg_drop_to_reserve_audit_msg', sqlcode, sqlerrm);
        IF ( i_pindex = 0 ) THEN
            l_buf := 'There is '
                     || TO_CHAR(i_pindex + 1)
                     || ' pallet in the stack.';
        ELSE
            l_buf := 'There are '
                     || TO_CHAR(i_pindex + 1)
                     || ' pallets in the stack.';
        END IF;

        l_message := 'Drop pallet'
                     || i_pals(i_pindex).pallet_id
                     || ' containing '
                     || i_pals(i_pindex).qty_on_pallet / i_pals(i_pindex).spc
                     || ' cases to '
                     || i_pals(i_pindex).slot_type
                     || i_pals(i_pindex).pallet_type
                     || i_pals(i_pindex).slot_desc
                     || 'slot '
                     || i_pals(i_pindex).dest_loc
                     || ' containing '
                     || i_pallets_IN_SLOT
                     || 'pallet(s).'
                     || l_buf;

        IF ( i_num_drops_completed <= 0 ) THEN
            NULL; /* Value should not be negative */
        ELSIF ( i_num_drops_completed = 1 ) THEN
            l_buf := i_num_drops_completed || ' pallet on the PO has been putaway to this slot.  It will not be removed for rotation.'
            ;
        ELSE
            l_buf := i_num_drops_completed || ' pallets on the PO have been putaway to this slot.  They will not be removed for rotation.'
            ;
        END IF;

        l_message := l_message || l_buf;
        lmg_audit_cmt(g_audit_batch_no, l_message, -1);
        pl_text_log.ins_msg_async('INFO', l_func_name, 'END lmg_drop_to_reserve_audit_msg', sqlcode, sqlerrm);
    END lmg_drop_to_reserve_audit_msg;
	
/*********************************************************************************
**   PROCEDURE:
**    lmg_drop_to_home_audit_msg
**   
**   Description:
**      This function writes forklift audit comments for a drop to a home
**      slot.  Not used for drops to handstack slots or carton flow slots
**      as these use a separate function.
**
**      Not used for floor slots.
**
**   PARAMETERS:
**      i_pals                - Pointer to pallet list.
**      i_pindex              - Index of top pallet on stack.
**                              i_pindex + 1 is the number of pallets in the
**                              travel stack.
**      i_pallets_IN_SLOT     - # of pallets in the slot.
**      i_prev_qoh            - Quantity in the slot before the drop.
**      i_slot_type_num_positions - Number of positions in the slot as
**                                  indicated by the slot type.
**      i_adj_num_positions   - Number of positions in the slot after adjusting
**                              for the min qty.
**      i_open_positions      - Number of open positions in the slot.
**      i_multi_face_slot_bln - Designates if the slot is a multi-face slot.
**
**        DATE         DESIGNER       COMMENTS
**     01/04/2020      ksar9933     Initial version0.0
***********************************************************************************/

    PROCEDURE lmg_drop_to_home_audit_msg (
        i_pals                      IN                          pl_lm_goal_pb.tbl_lmg_pallet_rec,
        i_pindex                    IN                          NUMBER,
        i_pallets_IN_SLOT           IN                          NUMBER,
        i_prev_qoh                  IN                          NUMBER,
        i_slot_type_num_positions   IN                          NUMBER,
        i_adj_num_positions         IN                          NUMBER,
        i_open_positions            IN                          NUMBER,
        i_multi_face_slot_bln       IN                          NUMBER
    ) AS

        l_buf         VARCHAR2(150);
        l_message     VARCHAR2(1024);
        l_check       VARCHAR2(50);
        l_flow_msg    VARCHAR2(50);
        l_func_name   VARCHAR2(50) := 'pl_lm_goaltime.lmg_drop_to_home_audit_msg';
    BEGIN
        pl_text_log.ins_msg_async('INFO', l_func_name, 'START lmg_drop_to_home_audit_msg', sqlcode, sqlerrm);
        IF ( i_pindex = 0 ) THEN
            l_buf := 'There is '
                     || i_pindex
                     || ' pallet in the stack.';
        ELSE
            l_buf := 'There are '
                     || i_pindex
                     || ' pallets in the stack.';
        END IF;

        IF ( ( substr(i_pals(i_pindex).batch_no, 1, 1) = LMF.FORKLIFT_BATCH_ID ) AND ( substr(i_pals(i_pindex).batch_no, 2, 1) = LMF.FORKLIFT_DROP_TO_HOME

        ) ) THEN
            IF ( i_pals(i_pindex).uom = 1 ) THEN
                l_check := 'split';
            ELSE
                l_check := 'case';
            END IF;

            l_message := 'This is a bulk pull with a drop to home.  Drop '
                         || i_pals(i_pindex).qty_on_pallet / i_pals(i_pindex).spc
                         || ' case(s) from pallet '
                         || i_pals(i_pindex).pallet_id
                         || ' to '
                         || i_pals(i_pindex).slot_type
                         || ' '
                         || i_pals(i_pindex).pallet_type
                         || ' '
                         || l_check
                         || ' home slot '
                         || i_pals(i_pindex).dest_loc
                         || ' with qoh of '
                         || i_prev_qoh / i_pals(i_pindex).spc
                         || ' case(s) and '
                         || MOD( i_prev_qoh, i_pals(i_pindex).spc )
                         || ' split(s).  The drop quantity will always be handstacked.'
                         || l_buf;

        ELSE
            IF ( substr(i_pals(i_pindex).flow_slot_type, 1, 1) != 'N' ) THEN
                CASE ( substr(i_pals(i_pindex).flow_slot_type, 1, 1) )
                    WHEN 'N' THEN
                        l_check := '';
                    WHEN 'P' THEN
                        l_check := 'pallet flow';
                    WHEN 'C' THEN
                        l_check := 'carton flow';
                    ELSE
                        l_check := 'unhandled flow_slot_type[('
                                   || i_pals(i_pindex).flow_slot_type
                                   || ')]';
                END CASE;
            ELSE
                IF ( i_pals(i_pindex).uom = 1 ) THEN
                    l_check := 'split';
                ELSE
                    l_check := 'case';
                END IF;
            END IF;

            l_message := 'Drop pallet '
                         || i_pals(i_pindex).pallet_id
                         || ' containing '
                         || i_pals(i_pindex).qty_on_pallet / i_pals(i_pindex).spc
                         || ' case(s) to '
                         || i_pals(i_pindex).slot_type
                         || ' '
                         || i_pals(i_pindex).pallet_type
                         || ' '
                         || l_check
                         || ' slot '
                         || i_pals(i_pindex).dest_loc
                         || ' with qoh of '
                         || i_prev_qoh / i_pals(i_pindex).spc
                         || ' case(s) and '
                         || MOD(i_prev_qoh, i_pals(i_pindex).spc)
                         || ' split(s).'
                         || l_buf;

        END IF;

        lmg_audit_cmt(g_audit_batch_no, l_message, -1);
	
    /*
    ** Flow slots get additional information on the forklift audit report.
    */
        CASE ( substr(i_pals(i_pindex).flow_slot_type, 1, 1) )
            WHEN 'N' THEN
                l_flow_msg := '';
            WHEN 'P' THEN
                l_flow_msg := 'pallet flow';
            WHEN 'C' THEN
                l_flow_msg := 'carton flow';
            ELSE
                l_flow_msg := 'unhandled flow_slot_type[('
                              || i_pals(i_pindex).flow_slot_type
                              || ')]';
        END CASE;

        IF ( substr(i_pals(i_pindex).flow_slot_type, 1, 1) != 'N' ) THEN
            l_message := 'Slot '
                         || i_pals(i_pindex).dest_loc
                         || ' is a '
                         || l_flow_msg
                         || ' back slot.  No rotation will take place.  The pick location is '
                         || i_pals(i_pindex).inv_loc
                         || '.';

            lmg_audit_cmt(g_audit_batch_no, l_message, -1);
        END IF;

        IF ( i_pals(i_pindex).uom = 1 ) THEN
            lmg_audit_cmt(g_audit_batch_no, 'Since this is a split home slot the drop quantity is always handstacked.', -1);
        END IF;

        l_message := 'Positions in the slot as indicated by the slot type:' || i_slot_type_num_positions;
        lmg_audit_cmt(g_audit_batch_no, l_message, -1);
        l_message := 'Positions in the slot after adjusting for the min qty: ' || i_adj_num_positions;
        lmg_audit_cmt(g_audit_batch_no, l_message, -1);
        l_message := 'Open positions: '
                     || i_open_positions
                     || ' Ti: '
                     || i_pals(i_pindex).ti
                     || '  Hi: '
                     || i_pals(i_pindex).hi
                     || '  Min Qty: '
                     || i_pals(i_pindex).min_qty;
		lmg_audit_cmt(g_audit_batch_no, l_message, -1);
        IF ( i_multi_face_slot_bln = TRUE1 ) THEN
            l_message := 'This is a multi-face slot because the min qty number of positions('
                         || i_pals(i_pindex).min_qty_num_positions
                         || ') is >= slot type number of positions('
                         || i_slot_type_num_positions
                         || ').';

            lmg_audit_cmt(g_audit_batch_no, l_message, -1);
        END IF;

        pl_text_log.ins_msg_async('INFO', l_func_name, 'END lmg_drop_to_home_audit_msg', sqlcode, sqlerrm);
    END lmg_drop_to_home_audit_msg;
	
/*********************************************************************************
**   PROCEDURE:
**    lmg_pickup_for_next_dst
**   
**   Description:
**      This functions performs the necessary operations to pickup the travel
**      stack before continuing to the next destination.
**
**  PARAMETERS:
**      i_pals             - Pointer to pallet list.
**      i_pindex           - Index of top pallet in the travel stack.
**      i_e_rec            - Pointer to equipment tmu values.
**      o_drop             - Outgoing drop value.
**
**        DATE         DESIGNER       COMMENTS
**     01/04/2020      ksar9933     Initial version0.0
***********************************************************************************/

    PROCEDURE lmg_pickup_for_next_dst (
        i_pals     IN         pl_lm_goal_pb.tbl_lmg_pallet_rec,
        i_pindex   IN         NUMBER,
        i_e_rec    IN         pl_lm_goal_pb.type_lmc_equip_rec,
        io_drop    IN OUT     NUMBER
    ) AS
        l_func_name   VARCHAR2(50) := 'pl_lm_goaltime.lmg_pickup_for_next_dst';
        l_message     VARCHAR2(1024);
    BEGIN
        pl_text_log.ins_msg_async('INFO', l_func_name, 'START lmg_pickup_for_next_dst.', sqlcode, sqlerrm);
	       /*
         ** Pickup travel stack if there are pallets left and go to the
         ** next destination but only if the next pallet is not on a break haul.
         **
         ** The break away hauls are processed last so they will be at the bottom
         ** of the travel stack.  So, if the top pallet on the travel stack is a
         ** break away haul then all the rest are too.
         */
        IF ( i_pindex >= 1 ) THEN
            IF ( i_pals(i_pindex).break_away_haul_flag = 'N' ) THEN
            /*
            ** The next pallet is not a break away haul.
            ** Pick up stack and go to next destination.
            */
                io_drop := io_drop + i_e_rec.apof + i_e_rec.mepof;
                IF ( g_forklift_audit = TRUE1) THEN
                    l_message := 'Pickup stack and go to next destination= ' || i_pals(i_pindex).dest_loc;
                    lmg_audit_movement('APOF', g_audit_batch_no, i_e_rec, 1, l_message);
                    lmg_audit_movement('MEPOF', g_audit_batch_no, i_e_rec, 1, '');
                END IF;

            ELSE
	        /*
            ** The next pallet is a break away haul.
            ** Do not pick up the stack.
            */
                IF ( g_forklift_audit = TRUE1) THEN
                    l_message := 'The rest of the pallets are break away hauls. Leave them on the floor.';
                    lmg_audit_cmt(g_audit_batch_no, l_message, -1);
                END IF;
            END IF;

        END IF;

        pl_text_log.ins_msg_async('INFO', l_func_name, 'END lmg_pickup_for_next_dst - calculated o_drop = ' || io_drop, sqlcode, sqlerrm

        );
    END lmg_pickup_for_next_dst;
	
/*********************************************************************************
**   PROCEDURE:
**   lmg_audit_travel_distance
**   
**   Description:
**      This functions creates audit entries for the forklift travel distance.
**
**   PARAMETERS:
**      i_batch_no    - Batch being processed.
**      i_src_loc 	  - Source Location
**      i_dest_loc 	  - Destination Location
**		i_distance	  - Distance 
**
**        DATE         DESIGNER       COMMENTS
**     01/04/2020      ksar9933     Initial version0.0
***********************************************************************************/

    PROCEDURE lmg_audit_travel_distance (
        i_batch_no   IN           batch.batch_no%TYPE,
        i_src_loc    IN           VARCHAR2,
        i_dest_loc   IN           VARCHAR2,
        i_distance   IN           lmd_distance_obj
    ) AS
        l_func_name   VARCHAR2(50) := 'pl_lm_goaltime.lmg_audit_travel_distance';
        l_audit_rec   lmg_audit_rec;
    BEGIN
        pl_text_log.ins_msg_async('INFO', l_func_name, 'START lmg_audit_travel_distance', sqlcode, sqlerrm);
        l_audit_rec.batch_no := i_batch_no;
        l_audit_rec.from_loc := i_src_loc;
        l_audit_rec.to_loc := i_dest_loc;
        l_audit_rec.user_id := g_user_id;
        l_audit_rec.equip_id := g_e_rec.equip_id;
        CASE g_travel_loaded
            WHEN 'Y' THEN
                l_audit_rec.frequency := i_distance.accel_distance;
                lmg_audit_forklift_movement('ACCLD', g_e_rec, l_audit_rec);
                l_audit_rec.frequency := i_distance.travel_distance;
                lmg_audit_forklift_movement('TRVLD', g_e_rec, l_audit_rec);
                l_audit_rec.frequency := i_distance.decel_distance;
                lmg_audit_forklift_movement('DECLD', g_e_rec, l_audit_rec);
            WHEN 'N' THEN
                l_audit_rec.frequency := i_distance.accel_distance;
                lmg_audit_forklift_movement('ACCEMP', g_e_rec, l_audit_rec);
                l_audit_rec.frequency := i_distance.travel_distance;
                lmg_audit_forklift_movement('TRVEMP', g_e_rec, l_audit_rec);
                l_audit_rec.frequency := i_distance.decel_distance;
                lmg_audit_forklift_movement('DECEMP', g_e_rec, l_audit_rec);
            ELSE

 /* Unrecognized value in g_travel_loaded.  Write aplog message.
               This is not a fatal error but the audit report will not be
               correct. */
                pl_text_log.ins_msg_async('WARN', l_func_name, 'Unrecognized value '
                                                     || g_travel_loaded
                                                     || ' in g_travel_loaded.  Check program.', sqlcode, sqlerrm);
        END CASE;

        pl_text_log.ins_msg_async('INFO', l_func_name, 'END lmg_audit_travel_distance', sqlcode, sqlerrm);
    END lmg_audit_travel_distance;

/*********************************************************************************
**   PROCEDURE:
**   lmg_audit_manual_time
**   
**   Description:
**      This functions inserts the manual operations into the audit table
**      for a forklift labor mgmt batch.
**
**      The manual time is selected from a view which has done most of the
**      work. 
**
**   PARAMETERS:
**      i_batch_no  - The batch being processed.
**
**        DATE         DESIGNER       COMMENTS
**     01/04/2020      ksar9933     Initial version0.0
***********************************************************************************/

    PROCEDURE lmg_audit_manual_time (
        i_batch_no   IN           batch.batch_no%TYPE
    ) AS

        l_func_name            VARCHAR2(50) := 'pl_lm_goaltime.lmg_audit_manual_time';
        l_message              VARCHAR2(1024);
        l_cur_count            NUMBER := 0;
        l_audit_rec            lmg_audit_rec;	/* Audit record */
        TYPE l_jbcd_job_code_cmt_arr IS
            VARRAY(20) OF VARCHAR2(100); --2021/01/07 lwee1503 hardcoded lengths to support oracle 11g
        TYPE l_operation_arr IS
            VARRAY(20) OF VARCHAR2(10); --2021/01/07 lwee1503 hardcoded lengths to support oracle 11g
        TYPE l_tmu_arr IS
            VARRAY(20) OF NUMBER; --2021/01/07 lwee1503 hardcoded lengths to support oracle 11g
        TYPE l_tmu_min_arr IS
            VARRAY(20) OF NUMBER; --2021/01/07 lwee1503 hardcoded lengths to support oracle 11g
        TYPE l_use_pieces_arr IS
            VARRAY(20) OF VARCHAR2(20); --2021/01/07 lwee1503 hardcoded lengths to support oracle 11g
        TYPE l_total_kvi_arr IS
            VARRAY(20) OF NUMBER; --2021/01/07 lwee1503 hardcoded lengths to support oracle 11g
        l_operation            l_operation_arr := l_operation_arr();
        l_jbcd_job_code_cmt    l_jbcd_job_code_cmt_arr := l_jbcd_job_code_cmt_arr();
        l_tmu                  l_tmu_arr := l_tmu_arr();
        l_tmu_min              l_tmu_min_arr := l_tmu_min_arr();
        l_use_pieces           l_use_pieces_arr := l_use_pieces_arr();
        l_total_kvi            l_total_kvi_arr := l_total_kvi_arr();
        l_previous_rec_count   NUMBER;		/* Previous count of total records fetched */
        l_current_rec_count    NUMBER;		/* Total records fetched */
        l_index                NUMBER;		/* Index */
    /*
    ** This cursor selects the manual operations for the batch.
    */
        CURSOR c_batch_manual_time IS
        SELECT
            operation,
            jbcd_job_code_cmt,
            tmu,
            tmu_min,
            use_pieces,
            total_kvi
        FROM
            v_fk_audit_manual_operation
        WHERE
            batch_no = i_batch_no
        ORDER BY
            display_order;

    BEGIN
        pl_text_log.ins_msg_async('INFO', l_func_name, 'START lmg_audit_manual_time - i_batch_no=' || i_batch_no, sqlcode, sqlerrm);
		/*
        ** Note:  g_user_id and g_e_rec are populated in lmg_calculate_goaltime.
        **
        ** Batch#, user id and equip id are the same for all the records.
        */
        l_audit_rec.batch_no := i_batch_no;
        l_audit_rec.user_id := g_user_id;
        l_audit_rec.equip_id := g_e_rec.equip_id;
        l_previous_rec_count := 0;
        lmg_audit_cmt(g_audit_batch_no, 'Manual Time:', -1);
	
		/*
        ** Make a note on the audit report about when a TMU defined at the
        ** pallet type level used.
        */
        l_message := 'Note:  If a job code has a TMU defined at the pallet type level for either the "From" location or the "To" location then the TMU at the job code level will not be used.'
        ;
        lmg_audit_cmt(g_audit_batch_no, l_message, -1);
        FOR rec IN c_batch_manual_time LOOP
            l_cur_count := l_cur_count + 1;
            l_operation.EXTEND;
            l_jbcd_job_code_cmt.EXTEND;
            l_tmu.EXTEND;
            l_tmu_min.EXTEND;
            l_use_pieces.EXTEND;
            l_total_kvi.EXTEND;
            l_operation(l_cur_count) := rec.operation;
            l_jbcd_job_code_cmt(l_cur_count) := rec.jbcd_job_code_cmt;
            l_tmu(l_cur_count) := rec.tmu;
            l_tmu_min(l_cur_count) := rec.tmu_min;
            l_use_pieces(l_cur_count) := rec.use_pieces;
            l_total_kvi(l_cur_count) := rec.total_kvi;
            l_current_rec_count := l_cur_count;
            IF ( l_current_rec_count - l_previous_rec_count > 0 ) THEN
                FOR l_index IN 1..( l_current_rec_count - l_previous_rec_count ) LOOP
                    IF ( l_use_pieces(l_index) = 'Y' ) THEN
                        l_message := 'TMU Case and TMU Split for job code '
                                     || l_jbcd_job_code_cmt(l_index)
                                     || ' are both null or zero.  The number of pieces will be used in the calculation of the goal/target time and not the number of cases and splits.'
                                     ;
                        lmg_audit_cmt(i_batch_no, l_message, -1);
                    ELSIF ( l_use_pieces(l_index) = 'N' ) THEN
                        l_message := 'TMU Case or TMU Split for job code '
                                     || l_jbcd_job_code_cmt(l_index)
                                     || ' is non-zero.  The number of cases and splits will be used in the calculation of the goal/target time and not the number of pieces.'
                                     ;
                        lmg_audit_cmt(i_batch_no, l_message, -1);
                    END IF; /* end use pieces check */

                    /*
                    ** Write the values to the audit record.
                    */

                    l_audit_rec.cmt := l_jbcd_job_code_cmt(l_index);
                    l_audit_rec.operation := l_operation(l_index);
                    l_audit_rec.tmu := l_tmu(l_index);
                    l_audit_rec.time := l_tmu_min(l_index);
                    l_audit_rec.frequency := l_total_kvi(l_index);
                    lmg_insert_forklift_audit_rec(l_audit_rec);
                END LOOP; /* end audit loop */
            END IF; /* end record check */

            l_previous_rec_count := l_current_rec_count;
        END LOOP; /* end cursor records loop */

        pl_text_log.ins_msg_async('INFO', l_func_name, 'END lmg_audit_manual_time', sqlcode, sqlerrm);
     EXCEPTION
	 WHEN OTHERS THEN
	   pl_text_log.ins_msg_async('INFO', l_func_name, 'Error in lmg_audit_manual_time ', sqlcode, sqlerrm);
    END lmg_audit_manual_time; /* end lmg_audit_manual_time */	
	
   /*********************************************************************************
**   PROCEDURE:
**   lmg_drop_tohandstack_audit_msg
**   
**   Description:
**      This function writes forklift audit comments for a drop to a
**     handstack slot.  A handstack slot is a slot with a pallet type
**     of HS or a carton flow slot.  This function is also called for
**     a putaway or drop of a MSKU to a home slot.
**
**
**   PARAMETERS:
**      _pals           - Pointer to pallet list.
**     i_pindex         - Index of top pallet on the travel stack.
**                        i_pindex + 1 is the number of pallets in the
**                        travel stack.
**     i_prev_qoh       - Quantity in the slot before the drop.
**  Return Values:
**     None.
**        DATE         DESIGNER       COMMENTS
**     01/04/2020      ksar9933     Initial version0.0
***********************************************************************************/
PROCEDURE lmg_drop_tohandstack_audit_msg (
        i_pals       IN           pl_lm_goal_pb.tbl_lmg_pallet_rec,
        i_pindex     IN           NUMBER,
        i_prev_qoh   IN           NUMBER
    ) AS

        l_func_name       VARCHAR2(50) := 'pl_lm_goaltime.lmg_drop_tohandstack_audit_msg';
        l_message         VARCHAR2(1024);
        l_qty_on_pallet   NUMBER;
        l_type            VARCHAR2(15);
        l_type1           VARCHAR2(15);
        l_slot_kind       VARCHAR2(100);
        l_result          VARCHAR2(15);
        l_buf             VARCHAR2(150);
    BEGIN
        pl_text_log.ins_msg_async('INFO', l_func_name, 'START lmg_drop_tohandstack_audit_msg', sqlcode, sqlerrm);
        IF ( i_pindex = 1 OR i_pals(i_pindex).msku_batch_flag = 'Y' ) THEN
            l_buf := 'There is 1 pallet in the stack.';
        ELSE
            l_buf := 'There are '
                     || TO_CHAR(i_pindex + 1,9999)
                     || ' pallets in the stack.';
        END IF;
    /*
    ** The message is a little different for reserve, carton flow back location
    ** and home slots and MSKU pallets.
    */
		IF ( i_pals(i_pindex).uom = 1 ) THEN
			l_qty_on_pallet := i_pals(i_pindex).qty_on_pallet;
			l_type := 'split(s)';
			l_type1 := 'split home';
		ELSE
			l_qty_on_pallet := i_pals(i_pindex).qty_on_pallet / i_pals(i_pindex).spc;
			l_type := 'case(s)';
			l_type1 := 'case home';
		END IF;

		IF ( i_pals(i_pindex).flow_slot_type = 'N' ) THEN
			l_result := l_type1;
		ELSE
			IF ( i_pals(i_pindex).flow_slot_type = 'P' ) THEN
				l_result := 'pallet flow';
			ELSIF ( i_pals(i_pindex).flow_slot_type = 'C' ) THEN
				l_result := 'carton flow';
			ELSE
				l_result := 'unhandled flow_slot_type';
			END IF;
		END IF;

		IF ( SUBSTR(i_pals(i_pindex).slot_kind,1,1) <> 'H' ) THEN
			l_slot_kind := i_pals(i_pindex).slot_desc;
		ELSE
			l_slot_kind := l_result;
		END IF;
        IF ( i_pals(i_pindex).msku_batch_flag <> 'Y' ) THEN
        /*
        ** Not a MSKU pallet.
        */
            

            l_message := 'Drop pallet '
                         || i_pals(i_pindex).pallet_id
                         || ' containing '
                         || l_qty_on_pallet
                         || ' '
                         || l_type
                         || ' to '
                         || i_pals(i_pindex).slot_type
                         || ' '
                         || i_pals(i_pindex).pallet_type
                         || ' '
                         || l_slot_kind
                         || ' slot '
                         || i_pals(i_pindex).dest_loc
                         || ' with qoh of '
                         || i_prev_qoh / i_pals(i_pindex).spc
                         || ' case(s) and '
                         || MOD(i_prev_qoh, i_pals(i_pindex).spc)
                         || ' split(s).  Floor height is '
                         || i_pals(i_pindex).height
                         || ' inches.  Always handstack.'
                         || l_buf;

        ELSE
    
        /*
        ** MSKU pallet.  The initial part of the message is different.
        */
            l_message := 'Drop MSKU pallet to '
                         || i_pals(i_pindex).slot_type
                         || ' '
                         || i_pals(i_pindex).pallet_type
                         || ' '
                         || l_slot_kind
                         || ' slot '
                         || i_pals(i_pindex).dest_loc
                         || ' with qoh of '
                         || i_prev_qoh / i_pals(i_pindex).spc
                         || ' case(s) and '
                         || MOD(i_prev_qoh, i_pals(i_pindex).spc)
                         || ' split(s).  Always handstack.'
                         || l_buf;
        END IF;

        lmg_audit_cmt(g_audit_batch_no, l_message, -1);  
		IF ( i_pals(i_pindex).flow_slot_type = 'N' ) THEN
			l_result := '';
		ELSE
			IF ( i_pals(i_pindex).flow_slot_type = 'P' ) THEN
				l_result := 'pallet flow';
			ELSIF ( i_pals(i_pindex).flow_slot_type = 'C' ) THEN
				l_result := 'carton flow';
			ELSE
				l_result := 'unhandled flow_slot_type';
			END IF;
		END IF;		

    /*
    ** Flow slots get additional information on the forklift audit report.
    */
        IF ( i_pals(i_pindex).flow_slot_type <> 'N' ) THEN
            l_message := 'Slot '
                         || i_pals(i_pindex).dest_loc
                         || ' is a '
                         || l_result
                         || ' back slot.  The pick location is '
                         || i_pals(i_pindex).inv_loc;

            lmg_audit_cmt(g_audit_batch_no, l_message, -1);
        END IF;

        pl_text_log.ins_msg_async('INFO', l_func_name, 'END lmg_drop_tohandstack_audit_msg', sqlcode, sqlerrm);
    END lmg_drop_tohandstack_audit_msg;
    
	
 /*********************************************************************************
**   PROCEDURE:
**   lmg_set_generic_rate_values
**   
**   Description:
**      This functions set the generic rate values based on the slot type.
**      Called by generic functions that handle different slot types.
**      Some rate values can be different for the different slot types.
**
**
**   PARAMETERS:
**       i_slot_type   - Slot type.
**      i_deep_ind    - Deep indicator.
**      i_e_rec       - Pointer to equipment tmu values.
**      o_g_tir       - Generic Turn into rack.
**      o_g_apir      - Generic Approach Pallet in rack.
**      o_g_mepir     - Generic Manuv. and Enter Pallet in rack.
**      o_g_ppir      - Generic Position Pallet rack.
**      o_rack_type   - Rack type used by the forklift audit to determine the
**                      actual forklift operation.  Needed because of the use
**                      of the generic variables.
**
**  RETURN VALUES:
**      None.
**        DATE         DESIGNER       COMMENTS
**     01/04/2020      ksar9933     Initial version0.0
***********************************************************************************/

    PROCEDURE lmg_set_generic_rate_values (
        i_e_rec       IN            pl_lm_goal_pb.type_lmc_equip_rec,
        i_slot_type   IN            VARCHAR2,
        i_deep_ind    IN            VARCHAR2,
        o_rack_type   OUT           VARCHAR2,
        o_g_tir       OUT           NUMBER,
        o_g_apir      OUT           NUMBER,
        o_g_mepir     OUT           NUMBER,
        o_g_ppir      OUT           NUMBER
    ) AS
        l_func_name VARCHAR2(50) := 'pl_lm_goaltime.lmg_set_generic_rate_values';
    BEGIN
        pl_text_log.ins_msg_async('INFO', l_func_name, 'START lmg_set_generic_rate_values', sqlcode, sqlerrm);
        IF ( i_deep_ind = 'Y' ) THEN
            IF ( substr(i_slot_type, 1, 1) = 'P' ) THEN
        
            /*
            **  Is pushback rack entry.
            */
                o_g_tir := i_e_rec.tir;
                o_g_apir := i_e_rec.apipb;
                o_g_mepir := i_e_rec.mepipb;
                o_g_ppir := i_e_rec.ppipb;
                o_rack_type := 'P';
            ELSIF ( ( substr(i_slot_type, 1, 1) = 'D' ) AND ( substr(i_slot_type, 2, 1) = 'I' ) ) THEN
        
            /*
            **  Is drive in rack entry.
            */
                o_g_tir := i_e_rec.tidi;
                o_g_apir := i_e_rec.apidi;
                o_g_mepir := i_e_rec.mepidi;
                o_g_ppir := i_e_rec.ppidi;
                o_rack_type := 'I';
            ELSIF ( ( substr(i_slot_type, 1, 1) = 'D' ) AND ( substr(i_slot_type, 2, 1) = 'D' ) ) THEN
        
            /*
            **  Is double deep rack entry.
            */
                o_g_tir := i_e_rec.tir;
                o_g_apir := i_e_rec.apidd;
                o_g_mepir := i_e_rec.mepidd;
                o_g_ppir := i_e_rec.ppidd;
                o_rack_type := 'D';
            ELSE
        
            /*
            **  Uses general rack entries.
            */
                o_g_tir := i_e_rec.tir;
                o_g_apir := i_e_rec.apir;
                o_g_mepir := i_e_rec.mepir;
                o_g_ppir := i_e_rec.ppir;
                o_rack_type := 'G';
            END IF;

        ELSE
    
        /*
        **  Uses general rack entries.
        */
            o_g_tir := i_e_rec.tir;
            o_g_apir := i_e_rec.apir;
            o_g_mepir := i_e_rec.mepir;
            o_g_ppir := i_e_rec.ppir;
            o_rack_type := 'G';
        END IF;

        pl_text_log.ins_msg_async('INFO', l_func_name, 'END lmg_set_generic_rate_values', sqlcode, sqlerrm);
    END lmg_set_generic_rate_values;

/*********************************************************************************
**   PROCEDURE:
**   lmg_audit_batch_summary
**   
**   Description:
**      This function shows a summary of the batch which helps when reviewing
**     the audit report.  This function is called when the batch processing
**     starts so that it appears first on the audit report.  The batch(s)
**     are ordered by actual start time which my be different in how they
**     are processed because processing is by location.
**     The information shown is:
**
**        Batch# Job Code Parent Batch# Pallet ID From Loc To Loc
**        ------ -------- ------------- --------- -------- -------
**
**     If an error occurs an aplog message and processing stops within
**     this function but the calling function is not affected.
**
**   PARAMETERS:
**      i_batch_no  - The batch being processed.
** 
**   Return Values:
**     None.
**        DATE         DESIGNER       COMMENTS
**     01/04/2020      ksar9933     Initial version0.0
***********************************************************************************/

    PROCEDURE lmg_audit_batch_summary (
        i_batch_no   IN           batch.batch_no%TYPE
    ) AS

        l_func_name            VARCHAR2(50) := 'pl_lm_goaltime.lmg_audit_batch_summary';
        l_message              VARCHAR2(1024);
        l_current_rec_count    NUMBER := 0;             /* Total records fetched */
        TYPE l_batch_no_arr IS
            VARRAY(20) OF VARCHAR2(13); --2021/01/07 lwee1503 hardcoded lengths to support oracle 11g
        TYPE l_jbcd_job_code_arr IS
            VARRAY(20) OF VARCHAR2(6); --2021/01/07 lwee1503 hardcoded lengths to support oracle 11g
        TYPE l_parent_batch_no_arr IS
            VARRAY(20) OF VARCHAR2(13); --2021/01/07 lwee1503 hardcoded lengths to support oracle 11g
        TYPE l_ref_no_arr IS
            VARRAY(20) OF VARCHAR2(40); --2021/01/07 lwee1503 hardcoded lengths to support oracle 11g
        TYPE l_kvi_from_loc_arr IS
            VARRAY(20) OF VARCHAR2(10); --2021/01/07 lwee1503 hardcoded lengths to support oracle 11g
        TYPE l_kvi_to_loc_arr IS
            VARRAY(20) OF VARCHAR2(10); --2021/01/07 lwee1503 hardcoded lengths to support oracle 11g
        TYPE l_msku_batch_flag_arr IS
            VARRAY(20) OF VARCHAR2(1); --2021/01/07 lwee1503 hardcoded lengths to support oracle 11g
        l_batch_no             l_batch_no_arr := l_batch_no_arr();
        l_jbcd_job_code        l_jbcd_job_code_arr := l_jbcd_job_code_arr();
        l_parent_batch_no      l_parent_batch_no_arr := l_parent_batch_no_arr();
        l_ref_no               l_ref_no_arr := l_ref_no_arr();
        l_kvi_from_loc         l_kvi_from_loc_arr := l_kvi_from_loc_arr();
        l_kvi_to_loc           l_kvi_to_loc_arr := l_kvi_to_loc_arr();
        l_msku_batch_flag      l_msku_batch_flag_arr := l_msku_batch_flag_arr();
        l_first_record_bln     BOOLEAN;               /* Flag */
        l_previous_rec_count   NUMBER := 0;                 /* Previous count of records fetched */
        l_cur_count            NUMBER := 0;
        l_index                NUMBER := 0;
        --l_res                  NUMBER := -1;
        CURSOR c_batch IS
        SELECT
            b.batch_no,
            b.jbcd_job_code,
            b.parent_batch_no,
            b.ref_no,
            b.kvi_from_loc
            || DECODE(l1.pallet_type, NULL, NULL, ' ' || l1.pallet_type) kvi_from_loc,
            b.kvi_to_loc
            || DECODE(l2.pallet_type, NULL, NULL, ' ' || l2.pallet_type) kvi_to_loc,
            nvl(b.msku_batch_flag, 'N') msku_batch_flag
        FROM
            loc     l1,
            loc     l2,
            batch   b
        WHERE
            ( b.batch_no = i_batch_no
              OR b.parent_batch_no = i_batch_no )
            AND l1.logi_loc (+) = b.kvi_from_loc
            AND l2.logi_loc (+) = b.kvi_to_loc
        ORDER BY
            DECODE(substr(b.batch_no, 1, 2), 'FM', '2', 'HL', '2', '1'),
            DECODE(b.msku_batch_flag, 'Y', b.kvi_to_loc || b.ref_no, TO_CHAR(b.actl_start_time, 'YYYYMMDDHH24MISS')
                                                                     || b.kvi_to_loc);

    BEGIN
        pl_text_log.ins_msg_async('INFO', l_func_name, 'START lmg_audit_batch_summary', sqlcode, sqlerrm);
        l_first_record_bln := true;
        FOR rec IN c_batch LOOP
            l_cur_count := l_cur_count + 1;            
            l_batch_no.EXTEND;
            l_jbcd_job_code.EXTEND;
            l_parent_batch_no.EXTEND;
            l_ref_no.EXTEND;
            l_kvi_from_loc.EXTEND;
            l_kvi_to_loc.EXTEND;
            l_msku_batch_flag.EXTEND;
            l_batch_no(l_cur_count) := rec.batch_no;
            l_jbcd_job_code(l_cur_count) := rec.jbcd_job_code;
            l_parent_batch_no(l_cur_count) := rec.parent_batch_no;
            l_ref_no(l_cur_count) := rec.ref_no;
            l_kvi_from_loc(l_cur_count) := rec.kvi_from_loc;
            l_kvi_to_loc(l_cur_count) := rec.kvi_to_loc;
            l_msku_batch_flag(l_cur_count) := rec.msku_batch_flag;
            l_current_rec_count := l_cur_count;            
            IF ( l_current_rec_count - l_previous_rec_count > 0 ) THEN
                FOR l_index IN 1..(l_current_rec_count - l_previous_rec_count) LOOP
                    /*
                    ** Output headings before the first record.
                    */
                    IF ( l_first_record_bln ) THEN
                        l_first_record_bln := false;
                        IF ( l_msku_batch_flag(l_cur_count) = 'Y' ) THEN
                            lmg_audit_cmt(g_audit_batch_no, 'Batch Summary Ordered By To Loc, LP:', -1);
                        ELSE
                            lmg_audit_cmt(g_audit_batch_no, 'Batch Summary Ordered By Start Time:', -1);
                        END IF;/* end msku batch flag check */
    
                        l_message := 'Batch#        Jb Cde Parent Batch# LP                 From Loc   To Loc';
                        lmg_audit_cmt(g_audit_batch_no, l_message, -1);
                        
                        /* The dashes displayed are not dynamic. */
                        l_message := '------------- ------ ------------- ------------------ ---------- ----------';
                        lmg_audit_cmt(g_audit_batch_no, l_message, -1);
                        
                        /*
                        ** Show if it is a MSKU pallet.
                        */
                        IF ( l_msku_batch_flag(l_cur_count) = 'Y' ) THEN
                            lmg_audit_cmt(g_audit_batch_no, '***** MSKU Pallet *****', -1);
                        END IF;
    
                    END IF;/* end first record check */
    
                    l_message := RPAD(nvl(l_batch_no(l_cur_count),' '), 13, ' ')
                                 || ' '
                                 || RPAD(nvl(l_jbcd_job_code(l_cur_count), ' '), 6, ' ')
                                 || ' '
                                 || RPAD(nvl(l_parent_batch_no(l_cur_count), ' '), 13, ' ')
                                 || ' '
                                 || RPAD(nvl(l_ref_no(l_cur_count), ' '), 18, ' ')
                                 || ' '
                                 || RPAD(nvl(l_kvi_from_loc(l_cur_count), ' '), 10, ' ')
                                 || ' '
                                 || RPAD(nvl(l_kvi_to_loc(l_cur_count), ' '), 10, ' ');
    
                    lmg_audit_cmt(g_audit_batch_no, l_message, -1);
                END LOOP;
				
            END IF; /* End audit records */

            l_previous_rec_count := l_current_rec_count;            
        END LOOP; /* end record loop */
		
		/* Put in separator to improve readability. */

        lmg_audit_cmt(g_audit_batch_no, AUDIT_MSG_DIVIDER, -1);
        pl_text_log.ins_msg_async('INFO', l_func_name, 'END lmg_audit_batch_summary', sqlcode, sqlerrm);
    END lmg_audit_batch_summary;
	
/*********************************************************************************
**   PROCEDURE:
**   lmg_calc_actual_qty_dropped
**   
**   Description:
**     This function determines the actual qty dropped to a home slot
**     for a pallet by looking for a HST from the same slot for the same
**     item, pallet and user immediately following the drop.  If the operator
**     is given time to handstack to the slot and a HST follows the drop then
**     the quantity handstacked for the drop will be the drop qty minus the
**     HST quantity.  This function populates the field in the structure.
**     The function that is processing the drop to the home slot will check
**     the value in this field and do the required adjustment to the qty
**     handstacked if it is determined that handstacking needs to be done.
**     The actual qty dropped and the HST qty are save in the pallet record
**     structure.   The functions processing drops to home slots will use
**     these values.
**
**     Also set is a field to designate if the hst qty needs to be added
**     to the destination home slot when determing how much qty is currently
**     in the home slot at the time of the drop.  When a batch is being
**     completed the updating of inventory has already taken place.  To
**     accurately get the qty in the home slot at the time of the drop
**     the qty on the pallet being dropped needs to be subtracted from the
**     qty in the home slot.  In the situation where there is one pallet
**     picked up for a putaway or a NDM or DMD then a demand HST is performed
**     everything is OK.
**     In the situation where two pallets are picked up for putaway one to
**     a carton flow slot and one going to a reserve slot and the carton flow
**     slot is done first followed by a demand HST which will suspend the
**     putaway batch then when the putaway batch is being completed the HST
**     qty needs to be added to the qty in the carton flow slot to get an
**     accurate qty for the putaway batch.
**     Example:
**        2 pallet putaway.
**        1 pallet of 30 cases going to an empty carton flow slot.
**        1 pallet going to a reserve slot.
**        Carton flow pallet putaway.   qoh in carton flow slot changed
**           from 0 to 30.
**        Operator starts a demand HST of 10 cases from the carton flow slot.
**        Putaway batch is suspended.
**        The operator completes the demand HST.  qoh in carton flow slot
**           is now 20.  An HST transaction is created.
**        Operator completes the 2nd putaway.  This completes the demand HST.
**        Operator starts another putaway that completes the 2 pallet putaway.
**        The qoh in the carton flow slot is 20 because of the demand HST.
**        To find the qoh in the carton flow slot at the time the putaway
**        was done the qty on the pallet which is 30 is subtracted from the
**        qoh in the home slot which is 20.  This results in a -10 which
**        is incorrect.  The actual qoh at the time of the putaway was 0.
**        So in this case the HST qty needs to be added back to the qoh 
**        in the carton flow slot when the putaway batch is being completed.
**
**     The HST will be the batch the user is in the process of signing onto
**     or in the situation where the HST was completed within a suspended
**     batch the HST batch will be completed and a HST transaction record
**     will exist.  So we need to look for a PPH or HST transaction.
**
**   PARAMETERS:
**     io_pals    - Pointer to pallet list.
**     i_pindex   - The index to the pallet to process.
** 
**   Return Values:
**     None.  Any errors will logged.  The quantity will be left as is.
**
**        DATE         DESIGNER       COMMENTS
**     01/04/2020      ksar9933     Initial version0.0
***********************************************************************************/

    PROCEDURE lmg_calc_actual_qty_dropped (
        io_pals    IN OUT     pl_lm_goal_pb.tbl_lmg_pallet_rec,
        i_pindex   IN         NUMBER
    ) AS
        l_func_name                 VARCHAR2(60) := 'pl_lm_goaltime.lmg_calc_actual_qty_dropped';
        l_message                   VARCHAR2(512);
        l_add_qty_to_dest_inv       VARCHAR2(1);
        l_cpv                       trans.cust_pref_vendor%TYPE;
        l_enable_pallet_flow        sys_config.config_flag_val%TYPE;
        l_pallet_id                 trans.pallet_id%TYPE;
        l_prod_id                   trans.prod_id%TYPE;
        l_qty                       INTEGER := 0;
        l_trans_type                trans.trans_type%TYPE;
        l_user_id                   trans.user_id%TYPE;
        l_add_hst_qty_to_dest_inv   VARCHAR2(1);
        l_hst_qty                   NUMBER := 0;
        CURSOR c_trans_qty (
            cp_trans_type           trans.trans_type%TYPE,
            cp_pallet_id            trans.pallet_id%TYPE,
            cp_prod_id              trans.prod_id%TYPE,
            cp_cpv                  trans.cust_pref_vendor%TYPE,
            cp_user_id              trans.user_id%TYPE,
            cp_enable_pallet_flow   sys_config.config_flag_val%TYPE
        ) IS
        SELECT
            t.qty,
            DECODE(t.trans_type, 'HST', 'Y', 'N') add_qty_to_dest_inv
        FROM
            trans t
        WHERE
            t.trans_type IN (
                'PPH',
                'HST'
            )
            AND t.pallet_id = cp_pallet_id
            AND t.prod_id = cp_prod_id
            AND t.cust_pref_vendor = cp_cpv
            AND t.user_id = cp_user_id
            AND t.trans_date >     -- The PPH/HST has to be after
                                               -- the drop transaction.
             (
                SELECT
                    MAX(t2.trans_date)  -- Need the last one.
                FROM
                    loc_reference   lr,
                    trans           t2
                WHERE
                    (   t2.trans_type = cp_trans_type
                     OR (t2.trans_type IN ('TRP', 'MIS', 'PUX') AND cp_trans_type = 'PUT')
                    )
                    AND t2.pallet_id = t.pallet_id
                    AND t2.prod_id = t.prod_id
                    AND t2.cust_pref_vendor = t.cust_pref_vendor
                    AND t2.user_id = t.user_id
                    AND lr.plogi_loc (+) = t2.dest_loc
                    AND ( ( cp_enable_pallet_flow = 'Y'
                            AND nvl(lr.bck_logi_loc, t2.dest_loc) = t.src_loc )
                          OR ( cp_enable_pallet_flow = 'N'
                               AND t2.dest_loc = t.src_loc ) )
            )
                        -- Need to be looking at the last PPH/HST transaction
                        -- for the the pallet.  There can be multiple HST's.
                        -- There should be only one PPH.
            AND t.trans_date = (
                SELECT
                    MAX(t3.trans_date)
                FROM
                    trans t3
                WHERE
                    t3.trans_type IN (
                        'PPH',
                        'HST'
                    )
                    AND t3.pallet_id = t.pallet_id
                    AND t3.prod_id = t.prod_id
                    AND t3.cust_pref_vendor = t.cust_pref_vendor
                    AND t3.user_id = t.user_id
            );

    BEGIN
        pl_text_log.ins_msg_async('INFO', l_func_name, 'START lmg_calc_actual_qty_dropped', sqlcode, sqlerrm);
	 /*
    ** Only process home slots.
    ** It is important that only home slots are processed.
    */
        IF ( io_pals(i_pindex).perm = 'Y' ) THEN
    
        /*
        ** Check what kind of batch it is and set the trans type as
        ** required.  We are only interested in drops to a home slot where
        ** the operator may do a demand HST.
        */
            IF ( io_pals(i_pindex).batch_type = LMF.FORKLIFT_PUTAWAY ) THEN
                l_trans_type := 'PUT';
            ELSIF ( io_pals(i_pindex).batch_type = LMF.FORKLIFT_NONDEMAND_RPL ) THEN
                l_trans_type := 'RPL';
            ELSIF ( io_pals(i_pindex).batch_type = LMF.FORKLIFT_DEMAND_RPL ) THEN
                l_trans_type := 'DFK';
            END IF;

            IF ( length(l_trans_type) > 0 ) THEN
        
            /*
            ** Got a transaction to process.
            ** Populate a few more required variables then continue on.
            */
                l_pallet_id := io_pals(i_pindex).pallet_id;
                l_prod_id := io_pals(i_pindex).prod_id;
                l_cpv := io_pals(i_pindex).cpv;
                l_user_id := io_pals(i_pindex).user_id;
                BEGIN
                    l_enable_pallet_flow := pl_common.f_get_syspar('ENABLE_PALLET_FLOW', 'N');
                    
                    OPEN c_trans_qty(l_trans_type, l_pallet_id, l_prod_id, l_cpv, l_user_id, l_enable_pallet_flow);
                    FETCH c_trans_qty INTO
                        l_qty,
                        l_add_qty_to_dest_inv;
                    IF ( c_trans_qty%notfound ) THEN
                        l_qty := 0;
                        l_add_qty_to_dest_inv := 'N';
                    END IF;

                    CLOSE c_trans_qty;
                    l_hst_qty := l_qty;
                    l_add_hst_qty_to_dest_inv := l_add_qty_to_dest_inv;
                EXCEPTION
                    WHEN OTHERS THEN
                        l_message := l_func_name
                                     || ' TABLE=trans,loc_reference KEY=['
                                     || l_trans_type
                                     || ']'
                                     || ',['
                                     || l_pallet_id
                                     || ']'
                                     || ',['
                                     || l_prod_id
                                     || ']'
                                     || ',['
                                     || l_cpv
                                     || ']'
                                     || ',['
                                     || l_user_id
                                     || ']'
                                     || '(l_trans_type, l_pallet_id, l_prod_id, l_cpv l_user_id)'
                                     || ' ACTION=SELECT MESSAGE=Error when looking for home'
                                     || ' slot qty of a PPH/HST transaction';

                        pl_text_log.ins_msg_async('WARN', l_func_name, l_message, sqlcode, sqlerrm);
						CLOSE c_trans_qty;
                END;

                IF ( l_hst_qty > 0 ) THEN
                    pl_text_log.ins_msg_async('WARN', l_func_name, 'batch#'
                                                        || io_pals(i_pindex).batch_no
                                                        || ' drop qty '
                                                        || io_pals(i_pindex).qty_on_pallet
                                                        || '  hst qty '
                                                        || l_hst_qty
                                                        || ' Qty to drop adjusted because of a home slot transfer.', sqlcode, sqlerrm
                                                        );

                    io_pals(i_pindex).actual_qty_dropped := io_pals(i_pindex).qty_on_pallet - l_hst_qty;
                    io_pals(i_pindex).hst_qty := l_hst_qty;
                    io_pals(i_pindex).add_hst_qty_to_dest_inv := l_add_hst_qty_to_dest_inv;
                END IF;

            END IF; /*END OF TRANS TYPE IF*/

        END IF; /*END OF PERM IF*/

        pl_text_log.ins_msg_async('INFO', l_func_name, 'batch#'
                                            || io_pals(i_pindex).batch_no
                                            || ' drop qty '
                                            || io_pals(i_pindex).qty_on_pallet
                                            || ' actual qty dropped '
                                            || io_pals(i_pindex).actual_qty_dropped
                                            || '  hst qty '
                                            || l_hst_qty , sqlcode, sqlerrm
                                            );

        pl_text_log.ins_msg_async('INFO', l_func_name, 'END lmg_calc_actual_qty_dropped', sqlcode, sqlerrm);
    END lmg_calc_actual_qty_dropped;
	
/*********************************************************************************
**   PROCEDURE:
**   lmg_drop_qty_adjusted_auditmsg
**   
**   Description:
**     This function writes forklift audit comments for a drop to a home
**     slot where handstacking will occur when the qty dropped has been
**     adjusted because of a following HST.  The message should only write
**     a case quantity because a HST should be a case quantity.
**
**   PARAMETERS:
**      i_pals    - Pointer to pallet list.
**     i_pindex  - The index to the pallet to process.
** 
**   Return Values:
**     None.
**        DATE         DESIGNER       COMMENTS
**     01/04/2020      ksar9933     Initial version0.0
***********************************************************************************/

    PROCEDURE lmg_drop_qty_adjusted_auditmsg (
        i_pals     IN         pl_lm_goal_pb.tbl_lmg_pallet_rec,
        i_pindex   IN         NUMBER
    ) AS
        l_func_name   VARCHAR2(50) := 'pl_lm_goaltime.lmg_drop_qty_adjusted_auditmsg';
        l_message     VARCHAR2(1024);
    BEGIN
        pl_text_log.ins_msg_async('INFO', l_func_name, 'START lmg_drop_qty_adjusted_auditmsg', sqlcode, sqlerrm);
		 /*
    ** There needs to be HST qty to write the message.
    */
        IF ( i_pals(i_pindex).hst_qty > 0 ) THEN
            l_message := 'For batch '
                         || i_pals(i_pindex).batch_no
                         || ' there is a following home slot transfer from slot '
                         || i_pals(i_pindex).dest_loc
                         || ' for the same LP '
                         || i_pals(i_pindex).pallet_id
                         || ', same item '
                         || i_pals(i_pindex).prod_id
                         || ', and same user.  This indicates not all the quantity was physically put in the home slot by the user.  Time will be given to handstack '
                         || i_pals(i_pindex).actual_qty_dropped / i_pals(i_pindex).spc
                         || ' case(s) and '
                         || MOD(i_pals(i_pindex).actual_qty_dropped, i_pals(i_pindex).spc)
                         || ' split(s) which is the quantity on the pallet dropped which is '
                         || i_pals(i_pindex).qty_on_pallet / i_pals(i_pindex).spc
                         || ' case(s) and '
                         || MOD(i_pals(i_pindex).qty_on_pallet, i_pals(i_pindex).spc)
                         || ' split(s) minus the home slot transfer quantity of '
                         || i_pals(i_pindex).hst_qty / i_pals(i_pindex).spc
                         || ' case(s) and '
                         || MOD(i_pals(i_pindex).hst_qty, i_pals(i_pindex).spc)
                         || ' split(s).';
              
        /*
        ** When writing the audit message use the global batch number which
        ** will always be the parent batch for merged batches.
        ** i_pals.batch_no(i_pindex) can be a merged batch number.  The audit
        ** always uses the parent batch number.
        */

            lmg_audit_cmt(g_audit_batch_no, l_message, -1);

        /*
        ** Write the message to the log table.
        */
            pl_text_log.ins_msg_async('INFO', l_func_name, l_message, NULL, NULL);
        END IF;

        pl_text_log.ins_msg_async('INFO', l_func_name, 'END lmg_drop_qty_adjusted_auditmsg', sqlcode, sqlerrm);
    END lmg_drop_qty_adjusted_auditmsg;
	
/*********************************************************************************
**   FUNCTION:
**    lmg_calc_hst_handstack_qty
**   
**   Description:
**     This function calculates the quantity that the operator will get
**     credit to handstack from the home slot for a home slot transfer.
**     The quantity will be in splits.  This is done by checking if the
**     user last operation was a drop to the same slot and the same
**     pallet id as the home slot.  This last operation will be under a
**     completed or suspended batch.
**
**    The rule is if the operators previous operation before the home slot
**    transfer was a drop to the same slot with the same pallet id then the
**    operator will not be given time to handstack the home slot transfer
**    quantity because it was just left on the pallet during the drop.
**    This will mainly happen for carton flow and handstack slots.
**
**    Example:
**       The operator performs a demand replenishment (DMD) of 30 cases to
**       carton flow slot DA01A1 for pallet 12345.  A drop to a carton flow
**       slot will always be handstacked--this is the rule.  The operators
**       next operation is a HST of 10 cases from DA01A1 to DA03B5 for
**       pallet 12345.  The operator will get credit to handstack 20 cases
**       to the slot for the DMD.  The operator will not get any credit for
**       handstacking for the HST because he would have left the 10 cases
**       on the pallet during the DMD.
**
**  PARAMETERS:   
**     i_batch_no  - The home slot transfer batch being processed.
**     i_hst_qty   - The initial home slot transfer qty.  It will be
**                   what the operator keyed in and stored in the HST
**                   transaction record.
**
**  RETURN VALUES:
**      The quantity to handstack..
**
**        DATE         DESIGNER       COMMENTS
**     01/21/2020      Infosys     Initial version0.0
***********************************************************************************/

    FUNCTION lmg_calc_hst_handstack_qty (
        i_batch_no   IN           batch.batch_no%TYPE,
        i_hst_qty    IN           NUMBER
    ) RETURN NUMBER AS
        l_func_name   VARCHAR2(50) := 'pl_lm_goaltime.lmg_calc_hst_handstack_qty';
        l_hst_qty     NUMBER;
    BEGIN
        pl_text_log.ins_msg_async('INFO', l_func_name, 'START lmg_calc_hst_handstack_qty', sqlcode, sqlerrm);
        pl_text_log.ins_msg_async('INFO', l_func_name, l_func_name
                                            || '(i_batch_no='
                                            || i_batch_no
                                            || ', i_hst_qty='
                                            || i_hst_qty
                                            || ')', sqlcode, sqlerrm);

        BEGIN
            l_hst_qty := pl_lmg_adjust_qty.f_get_hst_handstack_qty(i_batch_no, i_hst_qty);
        EXCEPTION
            WHEN OTHERS THEN
					/*
					** Got an error in the oracle pl/sql block.
					** This will not be a fatal error.  What can happen is the
					** operator may get time to handstack when no handstacking
					** took place.
					*/
                pl_text_log.ins_msg_async('WARN', l_func_name, 'pl_lmg_adjust_qty.f_get_hst_handstack_qty generated an error.  Will use i_hst_qty as the hst handstack qty.  This favors the operator.'
                , sqlcode, sqlerrm);
                l_hst_qty := i_hst_qty;
        END;

        pl_text_log.ins_msg_async('INFO', l_func_name, l_func_name
                                            || '(i_batch_no='
                                            || i_batch_no
                                            || ', i_hst_qty='
                                            || i_hst_qty
                                            || ') HST handstack qty in splits = '
                                            || l_hst_qty, sqlcode, sqlerrm);

        pl_text_log.ins_msg_async('INFO', l_func_name, 'END lmg_calc_hst_handstack_qty', sqlcode, sqlerrm);
        RETURN l_hst_qty;
    END lmg_calc_hst_handstack_qty; /* end lmg_calc_hst_handstack_qty */
	
    /*********************************************************************************
**   FUNCTION:
**    lmg_msku_drop_to_home_slot
**   
**   Description:
**     This functions calculates the LM drop discreet value for a MSKU pallet
**     with child LP's going to a home/floating slot.  The cases will always be
**     handstacked.
**
**     A MKSU pallet will not have it's batches merged with any other batch.
**     Each child LP going to a home slot for floating slot will have a
**     separate batch.
**     The process flow is:
**        - If the MSKU is going to home/floating slots then to reserve:
**          This can happen with putaway, NDM and DMD.
**           - Travel to home/floating slot.
**           - Position pallet at home/floating slot.
**           - Handstack the child LP's going to the home slot.
**           - Travel to next home/floating slot.
**           - Position pallet at home/floating slot.
**           - Handstack the child LP's going to the home/floating slot.
**           - ...
**           - Travel to reserve slot
**           - Put pallet in reserve slot with no rotation.
**        - If the MSKU is going to home/floating slots only:
**          This can happen with putaway, NDM and DMD.
**           - Travel to home/floating slot.
**           - Position pallet at home/floating slot.
**           - Handstack the child LP's going to the home/floating slot.
**           - Travel to next home/floating slot.
**           - Position pallet at home/floating slot.
**           - Handstack the child LP's going to the home/floating slot.
**           - ...
**           - Drop skid.
**        - If the MSKU is going straight to a reserve slot:
**          This can happen with putaway only.
**           - Travel to reserve slot
**           - Put pallet in reserve slot with no rotation.
**
************************************************************************
**      NOTE:  This function is also called for MSKU drops to 
**             floating slots because MSKU drops to home or
**             floating slots are treated the same.
************************************************************************
**
**  PARAMETERS:   
**     i_pals             - Pointer to pallet list.
**     i_num_pallets      - Number of pallets in pallet list.  Each batch
**                          is considered a batch though with MKSU there will
**                          only be one physical pallet.
**     i_e_rec            - Pointer to equipment tmu values.
**     i_dest_total_qoh   - Total qoh in destination.  It does
**                           not include the qty being dropped.
**     o_drop             - Outgoing drop value.  This is the time in
**                           minutes to complete the drop.
**
**  RETURN VALUES:
**      None.
**
**        DATE         DESIGNER       COMMENTS
**     01/21/2020      Infosys     Initial version0.0
***********************************************************************************/

    PROCEDURE lmg_msku_drop_to_home_slot (
        i_pals             IN                 pl_lm_goal_pb.tbl_lmg_pallet_rec,
        i_num_pallets      IN                 NUMBER,
        i_e_rec            IN                 pl_lm_goal_pb.type_lmc_equip_rec,
        i_dest_total_qoh   IN                 NUMBER,
        o_drop             OUT                NUMBER
    ) AS

        l_func_name                    VARCHAR2(50) := 'pl_lm_goaltime.lmg_msku_drop_to_home_slot';
        l_message                      VARCHAR2(1024);
        l_apply_credit_at_case_level   NUMBER; 		/* Designates if to apply credit at
														the case level when uom = 1 */
        l_pindex                       NUMBER;         /* Index of top pallet on stack */
        l_slot_height                  NUMBER;        	/* Height to slot from floor */
        l_prev_qoh                     NUMBER;        	/* Quantity in the slot before the drop. */
        l_rack_type                    VARCHAR2(1);    /* Rack type used by the forklift audit to
																determine the actual forklift operation.
																Needed because of the use of the generic
																variables. */
        l_spc                          NUMBER;
        l_index                        NUMBER;
        l_tmp_index                    NUMBER;
        l_first_record_bln             NUMBER;     	/* Flag */
        l_slot_type                    VARCHAR2(4);    /* Type of slot pallet is going to */
        l_handstack_cases              NUMBER := 0;  	/* Cases handstacked for the drop. */
        l_handstack_splits             NUMBER := 0; 	/* Splits handstacked for the drop. */
        l_g_tir                        NUMBER := 0.0;  /* Generic Turn o rack */
        l_g_apir                       NUMBER := 0.0;  /* Generic Approach Pallet in rack */
        l_g_mepir                      NUMBER := 0.0;  /* Generic Manuv. and Enter Pallet in rack */
        l_g_ppir                       NUMBER := 0.0;  /* Generic Position Pallet rack */
        l_rf_ret_val                   rf.status := rf.status_normal;
        l_is_all_lp_dropped            BOOLEAN := TRUE;
    BEGIN
        pl_text_log.ins_msg_async('INFO', l_func_name, 'START lmg_msku_drop_to_home_slot', sqlcode, sqlerrm);
		
		/*
		** The operator will be handling a MSKU pallet by itself.  There is
		** only one physical pallet.
		*/
        l_pindex := i_num_pallets;
        l_slot_height := i_pals(l_pindex).height;
        l_spc := i_pals(l_pindex).spc;
        l_slot_type := i_pals(l_pindex).slot_type;
        pl_text_log.ins_msg_async('INFO', l_func_name, l_func_name
                                            || '('
                                            || i_pals(l_pindex).pallet_id
                                            || ', '
                                            || i_num_pallets
                                            || ', '
                                            || i_e_rec.equip_id
                                            || ', '
                                            || i_dest_total_qoh
                                            || 'o_drop), l_slot_type='
                                            || l_slot_type
                                            || ', slot_height='
                                            || l_slot_height
                                            || ', i_pals.hst_qty='
                                            || i_pals(l_pindex).hst_qty, sqlcode, sqlerrm);
		
		/*
		**  All the child LP's dropped to the same home/floating slot are processed
		**  the first time this function is called.
		*/

        IF ( i_pals(l_pindex).multi_pallet_drop_to_slot = 'Y' ) THEN
            return;
        END IF; /* end process */
        assign_equip_rates(i_e_rec, l_slot_type, substr(i_pals(l_pindex).deep_ind, 1, 1), l_g_tir, l_g_apir, l_g_mepir, l_g_ppir,
        l_rack_type);
		/*
		** Initialize.
		*/

        l_prev_qoh := i_dest_total_qoh;
        l_first_record_bln := TRUE1;
		
		/*
		** Get syspar that determines if to give credit at the case or
		** split level when dropping to a split home slot.
		** With a RDC MSKU we SHOULD only be dealing with cases.
		** With a returns MSKU we could be dealing with cases and splits.
		*/
        l_rf_ret_val := pl_lm_forklift.lm_sel_split_rpl_crdt_syspar(l_apply_credit_at_case_level);
		
		/*
		** The drop to handstack audit msg is writtin only once and not for each
		** child LP.
		*/
        IF ( g_forklift_audit = TRUE1) THEN
			/* 'Y' designates a home slot */
            lmg_drop_tohandstack_audit_msg(i_pals, l_pindex, l_prev_qoh);
        END IF; /* end audit */
		
		/*
		** Drop all the child LP's going to the same home slot and also account
		** for only one child LP going to the home slot.
		*/
        FOR l_tmp_index IN REVERSE 1..l_pindex LOOP
            l_index := l_tmp_index;
            IF ( ( i_pals(l_index).multi_pallet_drop_to_slot = 'N' ) AND ( l_first_record_bln != TRUE1 ) ) THEN
                l_is_all_lp_dropped := FALSE;
                EXIT;   /* No more child LP's to drop to the same slot. */
            END IF; /* end exit loop */

            IF ( l_first_record_bln = TRUE1 ) THEN
				/*
				** Processing the first child LP.
				** Position the pallet at the slot.
				*/
                o_drop := ( ( l_slot_height / 12.0 ) * i_e_rec.rl );
                IF ( g_forklift_audit = TRUE1) THEN
                    l_message := 'Position MSKU pallet at slot '
                                 || i_pals(l_index).dest_loc
                                 || ' and handstack.';
                    lmg_audit_movement('RL', g_audit_batch_no, i_e_rec, l_slot_height, l_message);
                END IF; /* end audit */

            END IF; /* end first record */

            IF ( i_pals(l_index).uom = 1 ) THEN
				/* 
				** Dropping to a home slot with uom = 1.  A RDC MSKU should
				** only be dealing with cases.  A returns could be both ???
				*/
                IF ( l_apply_credit_at_case_level = TRUE1 ) THEN
					/*
					** Case up splits.
					*/
                    l_handstack_cases := i_pals(l_index).actual_qty_dropped / l_spc;
                    l_handstack_splits := MOD(i_pals(l_index).actual_qty_dropped, l_spc);
                    IF ( ( g_forklift_audit = TRUE1) AND ( l_first_record_bln = TRUE1 ) ) THEN
                        lmg_audit_cmt(g_audit_batch_no, q'(Syspar "Split RPL Credit at Case Level" is set to 'Y' so credit will be applied at the case level.)'
                        , -1);
                    END IF;

                ELSE
                    l_handstack_cases := 0;
                    l_handstack_splits := i_pals(l_index).actual_qty_dropped;
                    IF ( ( g_forklift_audit = TRUE1) AND ( l_first_record_bln = TRUE1 ) ) THEN
                        lmg_audit_cmt(g_audit_batch_no, q'(Syspar "Split RPL Credit at Case Level" is set to 'N' so credit will be applied at the split level.)'
                        , -1);
                    END IF;

                END IF; /* end case splits */
            ELSE
				/*
				** The uom is for cases which is what it should be for a MSKU.
				** The number of splits should be 0.
				*/
                l_handstack_cases := i_pals(l_index).actual_qty_dropped / l_spc;
                l_handstack_splits := MOD(i_pals(l_index).actual_qty_dropped, l_spc);
            END IF; /* end uom check */

            IF ( g_forklift_audit = TRUE1) THEN
                l_message := 'Handstack '
                             || l_handstack_cases
                             || ' case(s) and '
                             || l_handstack_splits
                             || ' split(s) for child LP '
                             || i_pals(l_index).pallet_id
                             || '.';

                lmg_audit_cmt(g_audit_batch_no, l_message, -1);
            END IF; /* end audit */

			/*
			** Update the kvi cases and kvi splits for the batch.
			*/

            l_rf_ret_val := pl_lm_forklift.lmf_update_batch_kvi(i_pals(l_index).batch_no, l_handstack_cases, l_handstack_splits)

            ;
            

			/*
			**  Add the quantity drop to the quantity in the slot.
			*/

            l_prev_qoh := l_prev_qoh + i_pals(l_index).actual_qty_dropped;
            l_first_record_bln := FALSE0;
        END LOOP;
		
		/*
		** If all the child LP's on the MSKU have been dropped to home/floating
		** slots then give time for a drop skid otherwise get ready to travel to
		** the next slot.  i is the index used in the above for loop.
		*/

        IF ( l_is_all_lp_dropped ) THEN
            o_drop := o_drop + ( ( l_slot_height / 12.0 ) * i_e_rec.le ) + i_e_rec.ds;

            IF ( g_forklift_audit = TRUE1) THEN
                l_message := q'(All the child LP's on the MSKU have been dropped to home/floating slot(s).)';
                lmg_audit_cmt(g_audit_batch_no, l_message, -1);
                lmg_audit_movement('LE', g_audit_batch_no, i_e_rec, l_slot_height, '');
                lmg_audit_movement('DS', g_audit_batch_no, i_e_rec, 1, '');

				/* Put in separator to improve readability. */
                lmg_audit_cmt(g_audit_batch_no, AUDIT_MSG_DIVIDER, -1);
            END IF; /* end audit */

        ELSE
            o_drop := o_drop + ( ( l_slot_height / 12.0 ) * i_e_rec.ll );

            IF ( g_forklift_audit = TRUE1) THEN
                l_message := 'Go to next destination '
                             || i_pals(l_index).dest_loc
                             || '.';
                lmg_audit_movement('LL', g_audit_batch_no, i_e_rec, l_slot_height, l_message);

				/* Put in separator to improve readability. */
                lmg_audit_cmt(g_audit_batch_no, AUDIT_MSG_DIVIDER, -1);
            END IF; /* end audit */

        END IF; /* end next slot */

        pl_text_log.ins_msg_async('INFO', l_func_name, 'END lmg_msku_drop_to_home_slot', sqlcode, sqlerrm);
    END lmg_msku_drop_to_home_slot; /* end lmg_msku_drop_to_home_slot */
	
/*********************************************************************************
**   FUNCTION:
**    assign_equip_rates
**   
**   Description:
**      This function assigns the equipment rates to common operations that
**      depend on the type of racking.  Since there are different rate values
**      for different kinds of racking the functions that are called for
**      different racking call this routine to set generic variables which
**      are then used in the rate calculations.
**
**  PARAMETERS:   
**      i_e_rec_ptr        - Pointer to equipment tmu values.
**      i_psz_slot_type    - Slot type.
**      i_c_deep_ind       - Deep indicator.
**      o_pd_g_tir         - Turn into rack.
**      o_pd_g_apir;       - Approach Pallet in rack.
**      o_pd_g_mepir       - Manuv. and Enter Pallet in rack.
**      o_pd_g_ppir        - Position Pallet it rack.
**      o_psz_rack_type    - Rack type.
**
**  RETURN VALUES:
**      None.
**
**        DATE         DESIGNER       COMMENTS
**     01/21/2020      Infosys     Initial version0.0
***********************************************************************************/

    PROCEDURE assign_equip_rates (
        i_e_rec_ptr       IN                pl_lm_goal_pb.type_lmc_equip_rec,
        i_psz_slot_type   IN                VARCHAR2,
        i_c_deep_ind      IN                VARCHAR2,
        o_pd_g_tir        OUT               NUMBER,
        o_pd_g_apir       OUT               NUMBER,
        o_pd_g_mepir      OUT               NUMBER,
        o_pd_g_ppir       OUT               NUMBER,
        o_psz_rack_type   OUT               VARCHAR2
    ) AS
        l_func_name VARCHAR2(50) := 'pl_lm_goaltime.assign_equip_rates';
    BEGIN
        pl_text_log.ins_msg_async('INFO', l_func_name, 'START assign_equip_rates', sqlcode, sqlerrm);
        IF ( i_c_deep_ind = 'Y' ) THEN
            IF ( substr(i_psz_slot_type, 1, 1) = 'P' ) THEN
				/*
				**  Is pushback rack entry.
				*/
                o_pd_g_tir := i_e_rec_ptr.tir;
                o_pd_g_apir := i_e_rec_ptr.apipb;
                o_pd_g_mepir := i_e_rec_ptr.mepipb;
                o_pd_g_ppir := i_e_rec_ptr.ppipb;
                o_psz_rack_type := 'P';
            ELSIF ( ( substr(i_psz_slot_type, 1, 1) = 'D' ) AND ( substr(i_psz_slot_type, 2, 1) = 'I' ) ) THEN
				/*
				**  Is drive in rack entry.
				*/
                o_pd_g_tir := i_e_rec_ptr.tidi;
                o_pd_g_apir := i_e_rec_ptr.apidi;
                o_pd_g_mepir := i_e_rec_ptr.mepidi;
                o_pd_g_ppir := i_e_rec_ptr.ppidi;
                o_psz_rack_type := 'I';
            ELSIF ( ( substr(i_psz_slot_type, 1, 1) = 'D' ) AND ( substr(i_psz_slot_type, 2, 1) = 'D' ) ) THEN
				/*
				**  Is double deep rack entry.
				*/
                o_pd_g_tir := i_e_rec_ptr.tir;
                o_pd_g_apir := i_e_rec_ptr.apidd;
                o_pd_g_mepir := i_e_rec_ptr.mepidd;
                o_pd_g_ppir := i_e_rec_ptr.ppidd;
                o_psz_rack_type := 'D';
            ELSE
				/*
				**  Uses general rack entries.
				*/
                o_pd_g_tir := i_e_rec_ptr.tir;
                o_pd_g_apir := i_e_rec_ptr.apir;
                o_pd_g_mepir := i_e_rec_ptr.mepir;
                o_pd_g_ppir := i_e_rec_ptr.ppir;
                o_psz_rack_type := 'G';
            END IF; /* end slot type check */

        ELSE
			/*
			**  Uses general rack entries.
			*/
            o_pd_g_tir := i_e_rec_ptr.tir;
            o_pd_g_apir := i_e_rec_ptr.apir;
            o_pd_g_mepir := i_e_rec_ptr.mepir;
            o_pd_g_ppir := i_e_rec_ptr.ppir;
            o_psz_rack_type := 'G';
        END IF; /* end deep indicator check */

        pl_text_log.ins_msg_async('INFO', l_func_name, 'END assign_equip_rates', sqlcode, sqlerrm);
    END assign_equip_rates; /* end assign_equip_rates */

/*********************************************************************************
**   FUNCTION:
**    apply_freq
**   
**   Description:
**      This functions calculates the frequency and returns the value.
**
**  PARAMETERS:   
**      i_val                        - frequency value to be verified.
**      i_give_stack_on_dock_time    - give stack on dock time value.
**
**  RETURN VALUES:
**      l_ret_val                    - verified frequency.
**
**        DATE         DESIGNER       COMMENTS
**     01/07/2020      Infosys     Initial version0.0
***********************************************************************************/

    FUNCTION apply_freq (
        i_val                       IN                          NUMBER,
        i_give_stack_on_dock_time   IN                          NUMBER
    ) RETURN NUMBER AS
        l_ret_val NUMBER := 0;
    BEGIN
        IF ( i_give_stack_on_dock_time = TRUE1 ) THEN
            l_ret_val := i_val;
        ELSE
            l_ret_val := 0;
        END IF;

        RETURN l_ret_val;
    END apply_freq;	

    /*********************************************************************************
** Procedure:
**    calc_time_at_pallet_level
**
** Description:
**    This procedure detemines the time to apply for TMU's that may
**    be at the pallet type level.
**
**    For the pallet TMU if there is one setup at the pallet type
**    level for either the "from" location or the "to" location
**    then the TMU at the job code level is not used.
**
**   PARAMETERS:   
**      i_batch_rec  	- The batch being processed.
**      o_pallet_time 	- The time to handle a pallet.
**
**  RETURN VALUES:
**      None.
**
**        DATE         DESIGNER       COMMENTS
**     01/07/2020      Infosys     Initial version0.0
***********************************************************************************/

    PROCEDURE calc_time_at_pallet_level (
        i_batch_rec     IN              c_batch_cur%rowtype,
        o_pallet_time   OUT             NUMBER
    ) AS

        l_func_name                VARCHAR2(50) := 'pl_lm_goaltime.calc_time_at_pallet_level';
        l_pallet_time              NUMBER;  -- Pallet time (tmu * kvi count)
        l_tmu_at_pallet_type_bln   BOOLEAN; -- Designates if a TMU is setup
									-- at the pallet type level.
        l_tmu_no_pallet            NUMBER;  -- TMU at the pallet type level

  -- This cursor selects the pallet tmu based on the job code
  -- and the pallet type.
  -- Note that during processing if nothing is setup at the pallet
  -- level then what is setup for the job code will be used.
  -- Example setup in pallet tmu table:
  --    Job Code   Pallet Type  TMU    Apply at Location
  --    --------   -----------  ----   -----------------
  --    FZRNDR       CF         205       TO
  --    FZRHST       CF         200       FROM
        CURSOR c_pallet_type_tmu (
            cp_job_code       pallet_type_tmu.job_code%TYPE,
            cp_pallet_type    pallet_type_tmu.pallet_type%TYPE,
            cp_apply_at_loc   VARCHAR2
        ) IS
        SELECT
            tmu_no_pallet
        FROM
            pallet_type_tmu
        WHERE
            job_code = cp_job_code
            AND pallet_type = cp_pallet_type
            AND apply_at_loc = cp_apply_at_loc;

    BEGIN
        pl_text_log.ins_msg_async('INFO', l_func_name, 'START calc_time_at_pallet_level', sqlcode, sqlerrm);
        l_pallet_time := 0;
        l_tmu_at_pallet_type_bln := false;
       BEGIN
	  -- Get the pallet time for the "from" location.
        OPEN c_pallet_type_tmu(i_batch_rec.jbcd_job_code, i_batch_rec.from_loc_pallet_type, 'FROM');
        FETCH c_pallet_type_tmu INTO l_tmu_no_pallet;
        IF ( c_pallet_type_tmu%found ) THEN
            l_pallet_time := i_batch_rec.kvi_no_pallet * l_tmu_no_pallet;
            l_tmu_at_pallet_type_bln := true;
        END IF;

        CLOSE c_pallet_type_tmu;

	  -- Get the pallet time for the "to" location.
        OPEN c_pallet_type_tmu(i_batch_rec.jbcd_job_code, i_batch_rec.to_loc_pallet_type, 'TO');
        FETCH c_pallet_type_tmu INTO l_tmu_no_pallet;
        IF ( c_pallet_type_tmu%found ) THEN
            l_pallet_time := l_pallet_time + ( i_batch_rec.kvi_no_pallet * l_tmu_no_pallet );
            l_tmu_at_pallet_type_bln := true;
        END IF;

        CLOSE c_pallet_type_tmu;
       EXCEPTION
	   WHEN OTHERS THEN
	   pl_text_log.ins_msg_async('WARN', l_func_name, 'Error in getting values from the cursor c_pallet_type_tmu.', sqlcode, sqlerrm);
	   CLOSE c_pallet_type_tmu;
	   END;
	  -- If no TMU was found at the pallet type level for the batch
	  -- then use the TMU at the job code level.
        IF ( l_tmu_at_pallet_type_bln = false ) THEN
            l_pallet_time := i_batch_rec.kvi_no_pallet * i_batch_rec.tmu_no_pallet;
        END IF;

        o_pallet_time := l_pallet_time;
        pl_text_log.ins_msg_async('INFO', l_func_name, 'END calc_time_at_pallet_level', sqlcode, sqlerrm);
    END calc_time_at_pallet_level;  /* end of  calc_time_at_pallet_level */

/*****************************************************************************
**  Function:
**      lmg_drop_to_induction_slot()
**
**  Description:
**      This function calculates the LM drop discreet value for a pallet
**      going to a miniload induction location.  A drop to an induction
**      location will be treated similar to a drop to an empty floor
**      home slot.
**
**  Parameters:
**      i_pals            - Pointer to pallet list.
**      i_num_pallets     - Number of pallets in pallet list (the number of
**                          pallets in the travel stack).
**      i_e_rec           - Pointer to equipment tmu values.
**      i_dest_total_qoh  - Total qoh in destination.
**      o_drop            - Outgoing drop value.
**
**  Return Values:
**      None.
**  Modification History:
**     DATE         DESIGNER  COMMENTS
**     ----------   --------  --------------------------------------------------
**	   01/23/2020   Infosys   Initial version0.0
**
*****************************************************************************/

    PROCEDURE lmg_drop_to_induction_slot (
        i_pals             IN                 pl_lm_goal_pb.tbl_lmg_pallet_rec,
        i_num_pallets      IN                 NUMBER,
        i_e_rec            IN                 pl_lm_goal_pb.type_lmc_equip_rec,
        i_dest_total_qoh   IN                 NUMBER,
        o_drop             OUT                NUMBER
    ) AS

        l_func_name                 VARCHAR2(50) := 'pl_lm_goaltime.lmg_drop_to_induction_slot'; /* Function identifier in APLOG messages. */
        l_message                   VARCHAR2(1024);
        l_index                     NUMBER;                          /* Index */
        l_floor_slot_stack_height   NUMBER := 0;  /* Height of stack at the induction
                                            location the drop pallet will be
                                            placed on.  Will always be 0
                                            because the incoming pallet is
                                            always put on the floor. */
        l_pallet_height             NUMBER := 0;        /* Height from floor to top pallet on
                                        the travel stack */
        l_pallet_qty                NUMBER := 0;           /* Quantity on drop pallet */
        l_pindex                    NUMBER;                   /* Index of top pallet on stack */
        l_same_slot_drop            VARCHAR2(1);           /* More than one incoming pallet to same
                                        slot */
        l_slot_height               NUMBER;              /* Height from floor to slot */
        l_spc                       NUMBER := 0;                  /* Splits per case */
    BEGIN
        l_message := '(pallet_id:'
                     || i_pals(i_num_pallets).pallet_id
                     || 'i_num_pallets:'
                     || i_num_pallets
                     || 'equip_id:'
                     || i_e_rec.equip_id
                     || 'i_dest_total_qoh:'
                     || i_dest_total_qoh
                     || 'multi_pallet_drop_to_slot:'
                     || i_pals(i_num_pallets).multi_pallet_drop_to_slot;

        pl_text_log.ins_msg_async('INFO', l_func_name, 'START lmg_drop_to_induction_slot' || l_message, sqlcode, sqlerrm);

    /*
    ***********************************************************************
    ** The induction slot will always be empty as far as forklift labor
    ** is concerned.
    ***********************************************************************
    */
--    i_dest_total_qoh := 0;  
    
    /* Set travel stack array index to the
                                      top pallet */
        l_pindex := i_num_pallets;
        l_same_slot_drop := i_pals(l_pindex).multi_pallet_drop_to_slot;

    /*
    ** The same slot drops were processed by this function on the first pallet
    ** dropped to the slot.  The calling function processes the pallets one at
    ** a time and will call this routine for each pallet going to an induction
    ** location.
    */
        IF l_same_slot_drop = 'Y' THEN
            pl_text_log.ins_msg_async('WARN', l_func_name, 'same slot drop is Y', sqlcode, sqlerrm);
            return;
        END IF;/*Checks for the same slot*/

    /*
    ** Initialize a few local variables.
    */

        l_slot_height := i_pals(l_pindex).height;
        l_spc := i_pals(l_pindex).spc;

    /*
    ** Process the pallets in the travel stack going to the same induction
    ** location.
    */
        FOR l_index IN REVERSE 1..l_pindex LOOP
    
        /*
        ** Get out of the loop if all the drops to the same induction location
        ** have been processed.
        */
            IF ( ( l_index != l_pindex ) AND ( i_pals(l_index).multi_pallet_drop_to_slot = 'N' ) ) THEN
                EXIT;
            END IF;/*checks both l_index value and l_pindex value are not equal AND multi_pallet_drop_to_slot is 'N' */

        /*
        **  Initialize variables. They may have been assigned a value above
        **  this for loop to use in debug and forklift audit messages.
        */

            l_pallet_qty := i_pals(l_index).qty_on_pallet;
            l_pallet_height := STD_PALLET_HEIGHT * l_index;   /* Get the height of the
                                               top pallet in the stack.
                                               It will be from the floor to the
                                               bottom of the pallet. */

        /*
        ** Drop the pallet at the induction location.
        */
            IF i_num_pallets = 1 THEN
                    /*
            ** There is one pallet in the travel stack.
            ** Place it at the induction location.
            */
                o_drop := o_drop + i_e_rec.tir;
                IF ( g_forklift_audit = TRUE1) THEN
                    l_message := 'Place pallet '
                                 || i_pals(l_index).pallet_id
                                 || ' at induction location '
                                 || i_pals(l_index).dest_loc
                                 || '.';

                    lmg_audit_cmt(g_audit_batch_no, l_message, -1);
                    lmg_audit_movement('TIR', g_audit_batch_no, i_e_rec, 1, '');
                END IF; /* end audit */

            /*
            ** Place the pallet at the induction location.  Treat it like
            ** dropping a pallet to a floor slot.
            */

                pl_lm_goal_fl.lmgfl_place_pallet_in_flr_slt(l_floor_slot_stack_height, l_pallet_height, i_e_rec, o_drop);
                
            ELSE
                    /*
            ** There is more than one pallet in the travel stack.
            **
            ** Put the travel stack down (if not already down), take off the
            ** top pallet and place it at the induction location.
            ** If down to the last pallet in the stack then it will be picked
            ** up from the floor and placed at the induction location.
            */
                IF ( g_forklift_audit = TRUE1) THEN
                    IF l_index > 1 THEN
                        l_message := 'Remove pallet '
                                     || i_pals(l_index).pallet_id
                                     || ' from top of stack and place at induction location '
                                     || i_pals(l_index).dest_loc
                                     || '.';

                        lmg_audit_cmt(g_audit_batch_no, l_message, -1);
                    ELSE
                        l_message := 'Pallet '
                                     || i_pals(l_index).pallet_id
                                     || ' is the last pallet in the stack.  Pickup the pallet from the floor and place at induction location '
                                     || i_pals(l_index).dest_loc
                                     || '.';

                        lmg_audit_cmt(g_audit_batch_no, l_message, -1);
                    END IF;/*checks l_index is greater than zero*/
                END IF;/* end audit */

            /*
            ** Put travel stack down if this is the 1st pallet processed.
            */

                IF l_index = l_pindex THEN 
                /*
                ** This is the 1st pallet processed.  Put travel stack down.
                */
                    o_drop := i_e_rec.ppof + i_e_rec.bp;
                    IF ( g_forklift_audit = TRUE1) THEN
                        l_message := 'Put the stack down.  There are '
                                     || i_num_pallets
                                     || ' pallets in the stack.';
                        lmg_audit_movement('PPOF', g_audit_batch_no, i_e_rec, 1, l_message);
                        lmg_audit_movement('BP', g_audit_batch_no, i_e_rec, 1, '');
                    END IF;/* end audit */

                END IF;/* checks for the first pallaet processed*/

            /*
            **  Is this the last pallet in the travel stack.
            */

                IF l_index = 1 THEN
                /*
                ** This is the last pallet in the travel stack.  Pick it up
                ** off the floor.
                */
                    o_drop := o_drop + ( ( l_floor_slot_stack_height / 12.0 ) * i_e_rec.le ) + i_e_rec.apof + i_e_rec.mepof + i_e_rec
                    .bt90;

                    IF ( g_forklift_audit = TRUE1) THEN
                        lmg_audit_movement('LE', g_audit_batch_no, i_e_rec, l_floor_slot_stack_height, '');
                        lmg_audit_movement('APOF', g_audit_batch_no, i_e_rec, 1, '');
                        lmg_audit_movement('MEPOF', g_audit_batch_no, i_e_rec, 1, '');
                        lmg_audit_movement('BT90', g_audit_batch_no, i_e_rec, 1, '');
                    END IF; /* end audit */

                ELSE
            
                /*
                **  This is not the last pallet in the stack.  Get the pallet
                **  off the travel stack.
                */
                    o_drop := o_drop + i_e_rec.apos;
                    IF l_pallet_height > l_floor_slot_stack_height THEN
                        o_drop := o_drop + ( ( ( l_pallet_height - l_floor_slot_stack_height ) / 12.0 ) * i_e_rec.re );

                    ELSE
                        o_drop := o_drop + ( ( ( l_floor_slot_stack_height - l_pallet_height ) / 12.0 ) * i_e_rec.le );
                    END IF;/* checks  l_pallet_height is greater than l_floor_slot_stack_height */

                    o_drop := o_drop + i_e_rec.mepos + i_e_rec.bt90;
                    IF ( g_forklift_audit = TRUE1) THEN
                        lmg_audit_movement('APOS', g_audit_batch_no, i_e_rec, 1, '');
                        IF l_pallet_height > l_floor_slot_stack_height THEN
                            lmg_audit_movement('RE', g_audit_batch_no, i_e_rec, l_pallet_height - l_floor_slot_stack_height, '');
                        ELSE
                            lmg_audit_movement('LE', g_audit_batch_no, i_e_rec, l_floor_slot_stack_height - l_pallet_height, '');
                        END IF;/*checks l_pallet_height greater than l_floor_slot_stack_height*/

                        lmg_audit_movement('MEPOS', g_audit_batch_no, i_e_rec, 1, '');
                        lmg_audit_movement('BT90', g_audit_batch_no, i_e_rec, 1, '');
                    END IF; /* end audit */

                END IF;/*checks for the ast pallet in the travel stack*/

            /*
            ** Place the pallet at the induction location.  Treat it like
            ** dropping a pallet to a floor slot.
            */

                pl_lm_goal_fl.lmgfl_place_pallet_in_flr_slt(l_floor_slot_stack_height, l_pallet_height, i_e_rec, o_drop);
                
            END IF;/*checks whether one pallet in the travel stack*/

        END LOOP;     /* end   FOR  */

        o_drop := o_drop + ( ( l_floor_slot_stack_height / 12.0 ) * i_e_rec.le );

        IF ( g_forklift_audit = TRUE1) THEN
            lmg_audit_movement('LE', g_audit_batch_no, i_e_rec, l_floor_slot_stack_height, '');
        END IF;/* end audit*/

    /*
    ** Pickup stack and continue to next destination if there are pallets
    ** still in the travel stack.
    */

        IF ( l_index >= 1 ) THEN
        /*
        ** There are pallets still in the travel stack.
        ** Pick up stack and go to next destination.
        */
            lmg_pickup_for_next_dst(i_pals, l_index, i_e_rec, o_drop);
        END IF;/* checks whether pallets still exists in the travel stack */

        l_message := 'END lmg_drop_to_induction_slot';
        pl_text_log.ins_msg_async('INFO', l_func_name, l_message, sqlcode, sqlerrm);        
    END lmg_drop_to_induction_slot;/* end lmg_drop_to_induction_slot */
    
    
    /*****************************************************************************
**  FUNCTION:
**     lmg_msku_drop_to_res_slot()
**
**  DESCRIPTION:
**     This functions calculates the LM drop discreet value for a MSKU pallet
**     going to an empty or non-empty reserve slot.
**
**     The MSKU should be the only pallet in the travel stack.  It is
**     expected a MKSU is picked up by itself.  The MKSU should not be
**     going to a deep slot.
**
**     For a MKSU no time will be given to rotate if the destination slot has
**     pallets.  It is expected the operator will place the MSKU on top of any
**     existing pallets.  The height to lift the MSKU to the slot will be
**     the slots floor height +
**            (number of pallets in the slot * STD_PALLET_HEIGHT).
**     The lift height calculation not always correct.
**                      Changed to = the slot height for now.
**
**  PARAMETERS:
**     i_pals             - Pointer to pallet list.
**     i_num_pallets      - Number of pallets in pallet list.
**     i_e_rec            - Pointer to equipment tmu values.
**     o_drop             - Outgoing drop value.
**
**  RETURN VALUES:
**     None.
**
**     DATE         DESIGNER  COMMENTS
**     ----------   --------  --------------------------------------------------
**	   01/23/2020   Infosys   Initial version0.0
*****************************************************************************/

    PROCEDURE lmg_msku_drop_to_res_slot (
        i_pals           IN               pl_lm_goal_pb.tbl_lmg_pallet_rec,
        i_num_pallets    IN               NUMBER,
        i_e_rec          IN               pl_lm_goal_pb.type_lmc_equip_rec,
        o_drop           OUT              NUMBER
    ) AS

        l_func_name         VARCHAR2(50) := 'pl_lm_goaltime.lmg_msku_drop_to_res_slot'; /* Function identifier
                                                           in APLOG messages. */
        l_message           VARCHAR2(1024);
        l_pindex            NUMBER;         /* Index of top pallet on stack */
        l_slot_height       NUMBER;    /* Height to slot from floor */
        l_adj_slot_height   NUMBER;   /* Height from the floor to the top of existing
                                   pallets in the slot.  This is the height
                                   the operator gets credit to lift the
                                   forks. */
        l_pallet_height     NUMBER;  /* Height from floor to top pallet on stack */        
        l_slot_type         VARCHAR2(4);   /* Type of slot the pallet is going to */
        l_g_tir             NUMBER := 0.0;    /* Generic Turn into rack */
        l_g_apir            NUMBER := 0.0;   /* Generic Approach Pallet in rack */
        l_g_mepir           NUMBER := 0.0;  /* Generic Manuv. and Enter Pallet in rack */
        l_g_ppir            NUMBER := 0.0;   /* Generic Position Pallet rack */
        l_rack_type         VARCHAR2(1);      /* Rack type used by the forklift audit to
                                determine the actual forklift operation.
                                Needed because of the use of the generic
                                variables. */
    BEGIN    
    /*
    ** Always removing the top pallet on the stack.  There should only be one
    ** pallet in the travel stack for a MSKU.
    */
        l_pindex := i_num_pallets;
        l_slot_height := i_pals(l_pindex).height;
        l_pallet_height := STD_PALLET_HEIGHT * l_pindex;        
        l_slot_type := i_pals(l_pindex).slot_type;
        l_adj_slot_height := l_slot_height;
        l_message := ' pallet_id:'
                     || i_pals(l_pindex).pallet_id
                     || ' i_num_pallets:'
                     || i_num_pallets
                     || ' equip_id'
                     || i_e_rec.equip_id
                     || ' l_slot_type:'
                     || l_slot_type;

        pl_text_log.ins_msg_async('INFO', l_func_name, 'START lmg_msku_drop_to_res_slot ' || l_message, sqlcode, sqlerrm);
        IF ( g_forklift_audit = TRUE1) THEN
            l_message := 'Drop MSKU pallet to '
                         || i_pals(l_pindex).slot_type
                         || '  '
                         || i_pals(l_pindex).pallet_type
                         || '  '
                         || i_pals(l_pindex).slot_desc
                         || ' slot '
                         || i_pals(l_pindex).dest_loc
                         || '.  Floor height is '
                         || l_slot_height
                         || ' inches.';

            lmg_audit_cmt(g_audit_batch_no, l_message, -1);
        END IF;/*End Of Audit*/

        assign_equip_rates(i_e_rec, l_slot_type, i_pals(l_pindex).deep_ind, l_g_tir, l_g_apir, l_g_mepir, l_g_ppir, l_rack_type)

        ;

        IF i_num_pallets = 1 THEN
            /*
        ** One pallet in the stack which there should be for a MSKU.
        */
            IF i_pals(l_pindex).multi_pallet_drop_to_slot = 'N' THEN
                o_drop := l_g_tir;
                IF ( g_forklift_audit = TRUE1) THEN
                    lmg_audit_movement_generic(l_rack_type, 'TIR', g_audit_batch_no, i_e_rec, 1, '');
                END IF;/*End Of AUDIT*/

            ELSE
                o_drop := 0.0;
            END IF;/*checks multi_pallet_drop_to_slot status is 'N')*/

            o_drop := o_drop + l_g_apir + ( ( l_adj_slot_height / 12.0 ) * i_e_rec.rl ) + 
                        l_g_ppir + ( ( l_adj_slot_height / 12.0 ) * i_e_rec.le ) + i_e_rec.bt90;

            IF ( g_forklift_audit = TRUE1) THEN
                l_message := 'One pallet in the stack.  Put MSKU pallet in slot '
                             || i_pals(l_pindex).dest_loc
                             || '.';
                lmg_audit_movement_generic(l_rack_type, 'APIR', g_audit_batch_no, i_e_rec, 1, l_message);
                lmg_audit_movement('RL', g_audit_batch_no, i_e_rec, l_adj_slot_height, '');
                lmg_audit_movement_generic(l_rack_type, 'PPIR', g_audit_batch_no, i_e_rec, 1, '');
                lmg_audit_movement('LE', g_audit_batch_no, i_e_rec, l_adj_slot_height, '');
                lmg_audit_movement('BT90', g_audit_batch_no, i_e_rec, 1, '');
            END IF;/*End of Audit*/

        ELSE
        /*
        **  More than one pallet in the stack.
        **
        **  ***** This point should not be reached *****
        **
        **  Remove top pallet.
        */
            o_drop := i_e_rec.ppof + i_e_rec.bp + i_e_rec.apos + ( ( l_pallet_height / 12.0 ) * i_e_rec.re ) + i_e_rec.mepos;

            IF ( g_forklift_audit = TRUE1) THEN
                l_message := 'Remove pallet '
                             || i_pals(l_pindex).pallet_id
                             || ' from top of stack.  '
                             || i_num_pallets
                             || ' pallets in the stack.';

                lmg_audit_movement('PPOF', g_audit_batch_no, i_e_rec, 1, l_message);
                lmg_audit_movement('BP', g_audit_batch_no, i_e_rec, 1, '');
                lmg_audit_movement('APOS', g_audit_batch_no, i_e_rec, 1, '');
                lmg_audit_movement('RE', g_audit_batch_no, i_e_rec, l_pallet_height, '');
                lmg_audit_movement('MEPOS', g_audit_batch_no, i_e_rec, 1, '');
            END IF;/*End of Audit*/

        /*
        **  Have top pallet on forks.  Move up or down and put pallet
        **  in rack.
        */

            IF l_adj_slot_height > l_pallet_height THEN
                o_drop := o_drop + i_e_rec.bt90 + l_g_apir + ( ( ( l_adj_slot_height - l_pallet_height ) / 12.0 ) * i_e_rec.rl ) +
                l_g_ppir + ( ( l_adj_slot_height / 12.0 ) * i_e_rec.le ) + i_e_rec.bt90;
            ELSE
                o_drop := o_drop + i_e_rec.bt90 + l_g_apir + ( ( ( l_pallet_height - l_adj_slot_height ) / 12.0 ) * i_e_rec.ll ) +
                l_g_ppir + ( ( l_adj_slot_height / 12.0 ) * i_e_rec.le ) + i_e_rec.bt90;
            END IF;/*checksks l_adj_slot_height is greater than l_pallet_height*/

            IF ( g_forklift_audit = TRUE1) THEN
                l_message := 'Put MKSU pallet in slot '
                             || i_pals(l_pindex).dest_loc
                             || '.';
                lmg_audit_movement('BT90', g_audit_batch_no, i_e_rec, 1, l_message);
                lmg_audit_movement_generic(l_rack_type, 'APIR', g_audit_batch_no, i_e_rec, 1, '');
                IF l_adj_slot_height > l_pallet_height THEN
                    lmg_audit_movement('RL', g_audit_batch_no, i_e_rec, l_adj_slot_height - l_pallet_height, '');
                ELSE
                    lmg_audit_movement('LL', g_audit_batch_no, i_e_rec, l_pallet_height - l_adj_slot_height, '');
                END IF;/*checks l_adj_slot_height is greater than l_pallet_height*/

                lmg_audit_movement_generic(l_rack_type, 'PPIR', g_audit_batch_no, i_e_rec, 1, '');
                lmg_audit_movement('LE', g_audit_batch_no, i_e_rec, l_adj_slot_height, '');
                lmg_audit_movement('BT90', g_audit_batch_no, i_e_rec, 1, '');
            END IF;/*End of Audit*/

        /*
        **  Pick up stack and go to next destination.
        */

            o_drop := o_drop + i_e_rec.apof + i_e_rec.mepof;
            IF ( g_forklift_audit = TRUE1) THEN
                l_message := 'Pickup stack and go to next destination '
                             || i_pals(l_pindex - 1).dest_loc
                             || '.';
                lmg_audit_movement('APOF', g_audit_batch_no, i_e_rec, 1, l_message);
                lmg_audit_movement('MEPOF', g_audit_batch_no, i_e_rec, 1, '');
            END IF;/*End of Audit*/

        END IF;/*checks for the One pallet in the stack which there should be for a MSKU*/

        l_message := 'END lmg_msku_drop_to_res_slot and calculated o_drop=' || o_drop;
        pl_text_log.ins_msg_async('INFO', l_func_name, l_message, sqlcode, sqlerrm);
    END lmg_msku_drop_to_res_slot; /* end lmg_msku_drop_to_res_slot */
    
    /*****************************************************************************
**  Function:
**      lmg_msku_pickup_from_reserve()
**
**  Description:
**      This function calculates the LM drop discreet value for a MSKU pallet
**      picked from a reserve slot.  No rotation will take place.  It is
**      expected the MSKU will be the top front pallet in the slot.
**
**  Parameters:
**      i_pals         - Pointer to pallet list.
**      i_pindex       - Index of pallet being processed.
**      i_e_rec        - Pointer to equipment tmu values.
**      i_inv          - Pointer to pallets already in the slot.
**      i_is_diff_item - Flag denoting if the different item is in the
**                       destination location.
**      io_pickup      - Outgoing pickup value.
**
**  Return Values:
**      None.
**
**     DATE         DESIGNER  COMMENTS
**     ----------   --------  --------------------------------------------------
**	   01/23/2020   Infosys   Initial version0.0
*****************************************************************************/

    PROCEDURE lmg_msku_pickup_from_reserve (
        i_pals           IN               pl_lm_goal_pb.tbl_lmg_pallet_rec,
        i_pindex         IN               NUMBER,
        i_e_rec          IN               pl_lm_goal_pb.type_lmc_equip_rec,
        i_inv            IN               pl_lm_goal_pb.tbl_lmg_inv_rec,
        i_is_diff_item   IN               VARCHAR2,
        io_pickup        IN OUT           NUMBER
    ) AS

        l_func_name             VARCHAR2(50) := 'pl_lm_goaltime.lmg_msku_pickup_from_reserve'; /* Function identifier
                                                          in APLOG messages. */
        l_message               VARCHAR2(1024);
        l_slot_height           NUMBER := 0;
        l_stack_height          NUMBER := 0;
        l_pallet_height         NUMBER := 0;
        l_num_pallets_IN_SLOT   NUMBER;  /* Number of pallets in the slot EXCLUDING
                                    the pallet to be picked up. */
    /*
    ** If multi pallet drop is set to Y then this means the batch after the
    ** first batch is being processed.  Time has been given to pickup the
    ** MSKU on the first batch processed so do nothing.
    */
    BEGIN
        l_message := 'START lmg_msku_pickup_from_reserve'
                     || '(batch_no:'
                     || i_pals(i_pindex).batch_no
                     || ' i_pindex:'
                     || i_pindex
                     || ' equip_id:'
                     || i_e_rec.equip_id
                     || ' i_is_diff_item:'
                     || i_is_diff_item
                     || ')';

        pl_text_log.ins_msg_async('INFO', l_func_name, l_message, sqlcode, sqlerrm);
        IF i_pals(i_pindex).multi_pallet_drop_to_slot = 'Y' THEN
            return;
        END IF;/*checks multi_pallet_drop_to_slot status is 'Y'*/
        l_slot_height := i_pals(i_pindex).height;
        l_pallet_height := STD_PALLET_HEIGHT * i_pindex;
        l_num_pallets_IN_SLOT := i_inv.last;
        l_stack_height := STD_PALLET_HEIGHT * l_num_pallets_IN_SLOT;
        IF ( g_forklift_audit = TRUE1) THEN
            l_message := 'Pickup MSKU pallet '
                         || i_pals(i_pindex).pallet_id
                         || ' from '
                         || i_pals(i_pindex).slot_type
                         || '  '
                         || i_pals(i_pindex).pallet_type
                         || '  '
                         || i_pals(i_pindex).slot_desc
                         || ' slot '
                         || i_pals(i_pindex).loc
                         || '.';

            lmg_audit_cmt(g_audit_batch_no, l_message, -1);
        END IF;/*END of audit*/

        io_pickup := io_pickup + i_e_rec.tir;

    /*
    **  Remove MSKU from rack.
    */
        io_pickup := io_pickup + i_e_rec.tir + i_e_rec.apir + ( ( l_slot_height / 12.0 ) * i_e_rec.re ) + i_e_rec.mepir + ( ( l_slot_height
        / 12.0 ) * i_e_rec.ll ) + i_e_rec.bt90;

        IF ( g_forklift_audit = TRUE1) THEN
            l_message := 'Remove MSKU pallet from slot.';
            lmg_audit_movement('TIR', g_audit_batch_no, i_e_rec, 1, l_message);
            lmg_audit_movement('APIR', g_audit_batch_no, i_e_rec, 1, '');
            lmg_audit_movement('RE', g_audit_batch_no, i_e_rec, l_slot_height, '');
            lmg_audit_movement('MEPIR', g_audit_batch_no, i_e_rec, 1, '');
            lmg_audit_movement('LL', g_audit_batch_no, i_e_rec, l_slot_height, '');
            lmg_audit_movement('BT90', g_audit_batch_no, i_e_rec, 1, '');
        END IF;/*END Of Audit*/
         pl_text_log.ins_msg_async('INFO', l_func_name, 'END lmg_msku_pickup_from_reserve', sqlcode, sqlerrm);
        return;
        
    END lmg_msku_pickup_from_reserve; /* end lmg_msku_pickup_from_reserve */
    
END pl_lm_goaltime;
/

GRANT EXECUTE ON PL_LM_GOALTIME TO SWMS_USER;
