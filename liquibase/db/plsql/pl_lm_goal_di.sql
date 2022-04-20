create or replace PACKAGE pl_lm_goal_di AS
/*********************************************************************************
**  PACKAGE:                                                                    **
**      pl_lm_goal_di                                                           **
**  Files                                                                       **
**      pl_lm_goal_di created from lm_goal_di.pc                                **
**                                                                              **
**  DESCRIPTION: This file contains the functions and subroutes necessary to    **
** calculate discreet Labor Management values for drive in racking.             **
**                                                                              **
**  MODIFICATION HISTORY:                                                       **
**      DATE          USER              COMMENT                                 **
**   03/09/2020      Infosys           Initial version0.0                       **  
**********************************************************************************/

    FUNCTION lmgdi_get_next_level_inv (
        i_pals                IN                    pl_lm_goal_pb.tbl_lmg_pallet_rec,
        i_pallet_index        IN                    NUMBER,
        i_num_pals_on_stack   IN                    NUMBER,
        o_i_rec               OUT                   pl_lm_goal_pb.tbl_lmg_inv_rec,
        o_dest_total_qoh      OUT                   NUMBER,
        o_next_slot_height    OUT                   NUMBER,
        o_num_recs            OUT                   NUMBER
    ) RETURN NUMBER;

    FUNCTION lmgdi_drp_drvin_hm_with_qoh (
        i_pals             IN                 pl_lm_goal_pb.tbl_lmg_pallet_rec,
        i_num_pallets      IN                 NUMBER,
        i_e_rec            IN                 pl_lm_goal_pb.type_lmc_equip_rec,
        i_inv              IN                 pl_lm_goal_pb.tbl_lmg_inv_rec,
        i_dest_total_qoh   IN                 NUMBER,
        o_drop             OUT                NUMBER
    ) RETURN NUMBER;

    FUNCTION lmgdi_get_pals_below_to_posx (
        i_curr_loc   IN           VARCHAR2,
        i_dest_loc   IN           VARCHAR2,
        i_dest_qty   IN           NUMBER,
        i_x          IN           NUMBER,
        o_pals       OUT          pl_lm_goal_pb.tbl_lmg_pallet_rec,
        o_num_recs   OUT          NUMBER
    ) RETURN NUMBER;

    FUNCTION lmgdi_drp_drvin_res_with_qoh (
        i_pals           IN               pl_lm_goal_pb.tbl_lmg_pallet_rec,
        i_num_pallets    IN               NUMBER,
        i_e_rec          IN               pl_lm_goal_pb.type_lmc_equip_rec,
        i_inv            IN               pl_lm_goal_pb.tbl_lmg_inv_rec,
        i_num_recs       IN               NUMBER,
        i_is_same_item   IN               VARCHAR2,
        o_drop           OUT              NUMBER
    ) RETURN NUMBER;

    FUNCTION lmgdi_rem_plts_from_res_slt (
        i_e_rec                   IN                        pl_lm_goal_pb.type_lmc_equip_rec,
        i_location                IN                        VARCHAR2,
        i_slot_height             IN                        NUMBER,
        i_num_pallets_to_remove   IN                        NUMBER,
        i_home_slot_bln           IN                        NUMBER,
        io_current_fork_height    IN OUT                    NUMBER,
        o_drop                    OUT                       NUMBER
    ) RETURN NUMBER;

    FUNCTION lmgdi_remove_below_pallets (
        i_e_rec                  IN                       pl_lm_goal_pb.type_lmc_equip_rec,
        i_location               IN                       VARCHAR2,
        io_posx_pals             IN OUT                   pl_lm_goal_pb.tbl_lmg_pallet_rec,
        io_num_recs              IN OUT                   NUMBER,
        io_current_fork_height   IN OUT                   NUMBER,
        o_drop                   OUT                      NUMBER
    ) RETURN NUMBER;

    PROCEDURE lmgdi_putbk_plts_in_res_slt (
        i_e_rec                    IN                         pl_lm_goal_pb.type_lmc_equip_rec,
        i_location                 IN                         VARCHAR2,
        i_slot_height              IN                         NUMBER,
        i_num_pallets_to_putback   IN                         NUMBER,
        i_home_slot_bln            IN                         NUMBER,
        i_current_fork_height      IN                         NUMBER,
        o_drop                     OUT                        NUMBER
    );

    PROCEDURE lmgdi_putback_below_pallets (
        i_e_rec                 IN                      pl_lm_goal_pb.type_lmc_equip_rec,
        i_location              IN                      VARCHAR2,
        i_current_fork_height   IN                      NUMBER,
        i_posx_pals             IN                      pl_lm_goal_pb.tbl_lmg_pallet_rec,
        i_num_recs              IN                      NUMBER,
        o_drop                  OUT                     NUMBER
    );

    FUNCTION lmgdi_pickup_from_drivein_res (
        i_pals           IN               pl_lm_goal_pb.tbl_lmg_pallet_rec,
        i_pindex         IN               NUMBER,
        i_e_rec          IN               pl_lm_goal_pb.type_lmc_equip_rec,
        i_inv            IN               pl_lm_goal_pb.tbl_lmg_inv_rec,
        i_is_diff_item   IN               VARCHAR2,
        i_num_recs       IN               NUMBER,
        o_pickup         OUT              NUMBER
    ) RETURN NUMBER;

END pl_lm_goal_di;
/

create or replace PACKAGE BODY pl_lm_goal_di AS
/*********************************************************************************
**  PACKAGE:                                                                    **
**      pl_lm_goal_di                                                           **
**  Files                                                                       **
**      pl_lm_goal_di created from lm_goal_di.pc                                **
**                                                                              **
**  DESCRIPTION: This file contains the functions and subroutes necessary to    **
** calculate discreet Labor Management values for drive in racking.             **
**                                                                              **
**  MODIFICATION HISTORY:                                                       **
**      DATE          USER              COMMENT                                 **
**   03/09/2020      Infosys           Initial version0.0                       **  
**********************************************************************************/

    C_FALSE                   CONSTANT NUMBER := 0;
    C_TRUE                    CONSTANT NUMBER := 1;
    G_FORKLIFT_AUDIT          NUMBER := C_TRUE;
    C_STD_PALLET_HEIGHT       CONSTANT NUMBER := 48;
    C_SWMS_NORMAL             CONSTANT NUMBER := 0;
    C_IN_AISLE                CONSTANT NUMBER := 2;
    C_IN_SLOT                 CONSTANT NUMBER := 1;
    C_MAX_PALS_PER_STACK_DI   CONSTANT NUMBER := 1;
    C_ORACLE_NOT_FOUND        CONSTANT NUMBER := 1403;
	
/*****************************************************************************
**  FUNCTION:
**      lmgdi_get_next_level_inv()
**
**  DESCRIPTION:
**      This functions fetches the inventory in the level above the home 
**      destination location.
**      The pallets on the stack are excluded from the inventory.
**
**  PARAMETERS:
**      i_pals              - Pointer to pallets on FORk.
**      i_pallet_index      - Index of current pallet being processed on FORk.
**      i_num_pals_on_stack - Number of pallets on FORk stack.
**      o_i_rec             - Pointer to storage to hold inventory in next
**                            level location.
**      o_dest_total_qoh    - Total qoh in the destination location.
**      o_next_slot_height  - Pointer to storage FOR floor to next level slot
**                            height.
**
**  RETURN VALUES:
**      SWMS_NORMAL      - Found inventory above the destination location.
**      ORACLE_NOT_FOUND - Found no inventory above the destination location.
**      SEL_INV_FAIL     - Select failed WHILE looking FOR inventory FOR
**                         specIFied slot.
**      INV_PRODID       - Select failed WHILE looking FOR pick slot item
**                         in next level.
**      SEL_LOC_FAIL     - Select failed WHILE looking FOR the slot next
**                         level up.
*****************************************************************************/

    FUNCTION lmgdi_get_next_level_inv (
        i_pals                IN                    pl_lm_goal_pb.tbl_lmg_pallet_rec,
        i_pallet_index        IN                    NUMBER,
        i_num_pals_on_stack   IN                    NUMBER,
        o_i_rec               OUT                   pl_lm_goal_pb.tbl_lmg_inv_rec,
        o_dest_total_qoh      OUT                   NUMBER,
        o_next_slot_height    OUT                   NUMBER,
        o_num_recs            OUT                   NUMBER
    ) RETURN NUMBER AS

        l_func_name           VARCHAR2(40) := 'lmgdi_get_next_level_inv';
        l_ret_val             NUMBER := c_swms_normal;
        l_message             VARCHAR2(1024);
        l_sqlstmt             VARCHAR2(1500);
        l_next_slot           loc.logi_loc%TYPE;
        l_perm                loc.perm%TYPE;
        l_dest_loc            VARCHAR2(11) := i_pals(i_pallet_index).loc;
        l_pallet_id           VARCHAR2(18) := i_pals(i_pallet_index).pallet_id;
        l_item                VARCHAR2(9) := i_pals(i_pallet_index).prod_id;
        l_cpv                 VARCHAR2(10) := i_pals(i_pallet_index).cpv;
        l_next_floor_height   loc.floor_height%TYPE;
        l_pindex              NUMBER := 1;
        TYPE curs_type IS REF CURSOR;
        next_inv_cur          curs_type;
        t_inv                 pl_lm_goal_pb.type_lmg_inv_rec;
    BEGIN
        t_inv.pallet_id := '';
        t_inv.prod_id := '';
        t_inv.cpv := '';
        t_inv.qoh := '';
        t_inv.exp_date := '';
        o_i_rec := pl_lm_goal_pb.tbl_lmg_inv_rec(t_inv);
        pl_text_log.ins_msg_async('INFO', l_func_name, 'l_dest_loc= '
                                            || l_dest_loc
                                            || ' l_pallet_id= '
                                            || l_pallet_id
                                            || ' l_item= '
                                            || l_item
                                            || ' l_cpv= '
                                            || l_cpv
                                            || ' i_pallet_index= '
                                            || i_pallet_index
                                            || ' i_num_pals_on_stack= '
                                            || i_num_pals_on_stack, sqlcode, sqlerrm);

        BEGIN
            SELECT
                l.logi_loc,
                l.perm,
                nvl(l.floor_height, 0)
            INTO
                l_next_slot,
                l_perm,
                l_next_floor_height
            FROM
                loc   l,
                loc   l2
            WHERE
                l.put_level = l2.put_level + 1
                AND l.put_slot = l2.put_slot
                AND l.put_aisle = l2.put_aisle
                AND l2.logi_loc = l_dest_loc;

          
            o_next_slot_height := l_next_floor_height;
        EXCEPTION
            WHEN no_data_found THEN
                o_num_recs := 0;
                l_ret_val := c_oracle_not_found;
                pl_text_log.ins_msg_async('WARN', l_func_name, 'Found no slot above the destination location. Location= ' || l_dest_loc, sqlcode
                , sqlerrm);
            WHEN OTHERS THEN
                pl_text_log.ins_msg_async('WARN', l_func_name, 'Failed to find loc FOR next level slot.', sqlcode, sqlerrm);
                l_ret_val := rf.status_sel_loc_fail;
        END;

        IF ( l_ret_val = c_swms_normal ) THEN
            l_sqlstmt := q'(SELECT logi_loc, qoh, prod_id, cust_pref_vENDor, TO_NUMBER(TO_CHAR(NVL(exp_date, SYSDATE), 'YYYYMMDD')) FROM inv WHERE qoh > 0 AND plogi_loc = ')'
            ;
            l_sqlstmt := l_sqlstmt || l_next_slot;
            l_sqlstmt := l_sqlstmt || q'(' AND logi_loc NOT IN(')';
            l_sqlstmt := l_sqlstmt
                         || i_pals(l_pindex).pallet_id
                         || q'(')';
            FOR i IN 1..i_num_pals_on_stack LOOP l_sqlstmt := l_sqlstmt || i_pals(i).pallet_id;
            END LOOP;

            l_sqlstmt := l_sqlstmt || ')';
            pl_text_log.ins_msg_async('INFO', l_func_name, 'l_sqlstmt= ' || l_sqlstmt, sqlcode, sqlerrm);
            OPEN next_inv_cur FOR l_sqlstmt;

            BEGIN
                FETCH next_inv_cur INTO
                        o_i_rec(l_pindex)
                    .pallet_id,
                    o_i_rec(l_pindex).qoh,
                    o_i_rec(l_pindex).prod_id,
                    o_i_rec(l_pindex).cpv,
                    o_i_rec(l_pindex).exp_date;

                IF next_inv_cur%notfound THEN
                    pl_text_log.ins_msg_async('WARN', l_func_name, 'Failed to find inv FOR next level slot. l_sqlstmt= ' || l_sqlstmt, sqlcode
                    , sqlerrm);
                    RETURN rf.status_sel_inv_fail;
                END IF;

            END;

            CLOSE next_inv_cur;
            o_dest_total_qoh := 0;    /* This variable is not used FOR anything */
            o_num_recs := 0;
            o_num_recs := SQL%rowcount;  /*sqlca.sqlerrd(2)*/
            pl_text_log.ins_msg_async('INFO', l_func_name, 'Number of Row counts =' || o_num_recs, sqlcode, sqlerrm);
            IF ( o_num_recs > 0 ) THEN
                pl_text_log.ins_msg_async('INFO', l_func_name, 'Num recs in next up = ' || o_num_recs, sqlcode, sqlerrm);
                FOR i IN 1..o_num_recs LOOP o_dest_total_qoh := nvl(o_dest_total_qoh, 0) + o_i_rec(i).qoh;
                END LOOP;

                IF ( l_perm = 'Y' ) THEN
                    FOR i IN 1..i_num_pals_on_stack LOOP IF ( i_pals(i).loc = l_next_slot ) THEN
                        o_dest_total_qoh := nvl(o_dest_total_qoh, 0) - i_pals(i).qty_on_pallet;
                    END IF;
                    END LOOP;

                    BEGIN
                        SELECT
                            DECODE(mod(nvl(o_dest_total_qoh, 0),(p.ti * p.hi * p.spc)), 0, nvl(o_dest_total_qoh, 0) /(p.ti * p.hi
                            * p.spc),((nvl(o_dest_total_qoh, 0) /(p.ti * p.hi * p.spc)) + 1))
                        INTO o_num_recs
                        FROM
                            pm p
                        WHERE
                            p.prod_id = o_i_rec(1).prod_id
                            AND p.cust_pref_vendor = o_i_rec(1).cpv;

                    EXCEPTION
                        WHEN no_data_found THEN
                            pl_text_log.ins_msg_async('WARN', l_func_name, 'Failed to get item info in next level slot.', sqlcode, sqlerrm);
                            l_ret_val := rf.status_inv_prodid;
                    END;

                END IF;

            END IF;

        END IF;

        RETURN l_ret_val;
    END lmgdi_get_next_level_inv;

/*****************************************************************************
**  FUNCTION:
**      lmgdi_drp_drvin_hm_with_qoh()
**
**  DESCRIPTION:
**      This function calculates the LM drop discreet value FOR a pallet
**      going to a drive-in home slot with existing qoh.
**      Should only be dealing with case quantities.
**      When removing pallets from the slot FOR rotation purposes
**      the number of pallets removed will not be greater than what
**      the slot type indicates as the number of positions in the slot.
**      This is to handle multi-face slots.
**
**  PARAMETERS:
**      i_pals            - Pointer to pallet list.
**      i_num_pallets     - Number of pallets in pallet list.
**      i_e_rec           - Pointer to equipment tmu values.
**      i_inv             - Pointer to pallets already in slot.
**      i_dest_total_qoh  - Total qoh in destination.
**      o_drop            - Outgoing drop value.
**
**  RETURN VALUES:
**      None.
*****************************************************************************/

    FUNCTION lmgdi_drp_drvin_hm_with_qoh (
        i_pals             IN                 pl_lm_goal_pb.tbl_lmg_pallet_rec,
        i_num_pallets      IN                 NUMBER,
        i_e_rec            IN                 pl_lm_goal_pb.type_lmc_equip_rec,
        i_inv              IN                 pl_lm_goal_pb.tbl_lmg_inv_rec,
        i_dest_total_qoh   IN                 NUMBER,
        o_drop             OUT                NUMBER
    ) RETURN NUMBER AS

        l_func_name                 VARCHAR2(40) := 'lmgdi_drp_drvin_hm_with_qoh';
        l_ret_val                   NUMBER := c_swms_normal;
        l_message                   VARCHAR2(1024);
        l_adj_num_positions         NUMBER := 0;
        l_buf                       VARCHAR2(128);
        l_curr_stack_height         NUMBER;
        l_handstack_cases           NUMBER := 0;
        l_handstack_splits          NUMBER := 0;
        l_home_stack                NUMBER := 0;
        l_home_stack_height         NUMBER := 0;
        l_last_pal_qty              NUMBER := 0;
        l_level_stack               NUMBER := 0;
        l_next_slot_total_qoh       NUMBER := 0;
        l_next_slot_height          NUMBER := 0;
        l_pallet_height             NUMBER := 0;
        l_pallet_qty                NUMBER := 0;
        l_pallets_in_slot           NUMBER := 0;
        l_pindex                    NUMBER := 0;
        l_prev_qoh                  NUMBER := 0;
        l_same_slot_flag            VARCHAR2(1);
        l_slot_height               NUMBER := 0;
        l_slot_type_num_positions   NUMBER;
        l_spc                       NUMBER := 0;
        l_ti_hi                     NUMBER := 0;
        l_next_inv                  pl_lm_goal_pb.tbl_lmg_inv_rec;
        l_num_recs                  NUMBER;
        l_open_position             NUMBER := 0;
        l_removed_pallet            NUMBER := 0;
    BEGIN
        pl_text_log.ins_msg_async('INFO', l_func_name, 'Starting lmgdi_drp_drvin_hm_with_qoh..', sqlcode, sqlerrm);
        l_pindex := i_num_pallets - 1;
        pl_text_log.ins_msg_async('INFO', l_func_name, 'i_num_pallets= '
                                            || i_num_pallets
                                            || ' l_pindex= '
                                            || l_pindex, sqlcode, sqlerrm);

        l_pallet_qty := i_pals(l_pindex).qty_on_pallet;
        l_prev_qoh := i_dest_total_qoh;
        l_slot_height := i_pals(l_pindex).height;
        l_pallet_height := c_std_pallet_height * l_pindex;
        l_spc := i_pals(l_pindex).spc;
        l_ti_hi := i_pals(l_pindex).ti * i_pals(l_pindex).hi * l_spc;

        l_pallets_in_slot := l_prev_qoh / l_ti_hi;
        l_same_slot_flag := i_pals(l_pindex).multi_pallet_drop_to_slot;
        l_last_pal_qty := MOD(l_prev_qoh, l_ti_hi);
        IF ( l_last_pal_qty > 0 ) THEN
            l_pallets_in_slot := l_pallets_in_slot + 1;
        END IF;
        IF ( l_last_pal_qty = 0 ) THEN
            l_last_pal_qty := l_ti_hi;
        END IF;
        l_spc := i_pals(l_pindex).spc;
        /*slot type is in 10th position in the argument passing from Input. Here l_slot_type_num_positions defined as 10 instead of slot type*/
        l_slot_type_num_positions := 10; /*i_pals(l_pindex).slot_type;*/
        l_adj_num_positions := i_pals(l_pindex).min_qty_num_positions + l_slot_type_num_positions;
        pl_text_log.ins_msg_async('INFO', l_func_name, 'pallet to put in slot= '
                                            || i_pals(l_pindex).pallet_id
                                            || ' No of pallets in stack= '
                                            || i_num_pallets
                                            || ' Equip id= '
                                            || i_e_rec.equip_id
                                            || ' total qoh in the slot= '
                                            || i_dest_total_qoh, sqlcode, sqlerrm);

        IF ( g_forklift_audit = c_true ) THEN
            IF ( i_num_pallets = 1 ) THEN
                l_buf := 'Pallet in the stack= ' || i_num_pallets;
            ELSE
                l_buf := 'Number of pallets in the Stack= ' || i_num_pallets;
            END IF;

            l_message := 'Drop pallet '
                         || i_pals(l_pindex).pallet_id
                         || ' containing '
                         || l_pallet_qty / l_spc
                         || ' cases to '
                         || i_pals(l_pindex).slot_type
                         || ' '
                         || i_pals(l_pindex).pallet_type
                         || ' drive-in home slot '
                         || i_pals(l_pindex).dest_loc
                         || ' with qoh of '
                         || i_dest_total_qoh / l_spc
                         || ' cases. '
                         || l_buf;

            pl_lm_goaltime.lmg_audit_cmt(pl_lm_goaltime.g_audit_batch_no, l_message, -1);
            l_message := 'Positions in the slot as indicated by the slot type ' || l_slot_type_num_positions;
            pl_lm_goaltime.lmg_audit_cmt(pl_lm_goaltime.g_audit_batch_no, l_message, -1);
            l_message := 'Positions in the slot after adjusting FOR the min qty ' || l_adj_num_positions;
            pl_lm_goaltime.lmg_audit_cmt(pl_lm_goaltime.g_audit_batch_no, l_message, -1);
            IF ( ( l_adj_num_positions - l_pallets_in_slot ) < 0 ) THEN
                l_open_position := 0;
            ELSE
                l_open_position := l_adj_num_positions - l_pallets_in_slot;
            END IF;

            l_message := ' Open positions '
                         || l_open_position
                         || ' Ti '
                         || i_pals(l_pindex).ti
                         || ' Hi '
                         || i_pals(l_pindex).hi
                         || ' Min Qty= '
                         || i_pals(l_pindex).min_qty;

        END IF;

        IF ( l_same_slot_flag = 'N' ) THEN
            l_ret_val := lmgdi_get_next_level_inv(i_pals, l_pindex, i_num_pallets, l_next_inv, l_next_slot_total_qoh, l_next_slot_height
            , l_num_recs);

            IF ( l_ret_val = c_oracle_not_found ) THEN
                l_ret_val := c_swms_normal;
            ELSE
                RETURN l_ret_val;
            END IF;

            o_drop := i_e_rec.ppof;
            IF ( g_forklift_audit = c_true ) THEN
                l_message := 'Put stack down.';
                pl_lm_goaltime.lmg_audit_movement('PPOF', pl_lm_goaltime.g_audit_batch_no, i_e_rec, 1, l_message);
            END IF;

            IF ( l_num_recs > 1 ) THEN
                FOR i IN 0..l_num_recs - 1 LOOP
                    o_drop := nvl(o_drop, 0) + i_e_rec.bt90 + i_e_rec.apidi;
                    IF ( l_next_slot_height > ( c_std_pallet_height * l_level_stack ) ) THEN
                        o_drop := nvl(o_drop, 0) + ( ( ( l_next_slot_height - ( c_std_pallet_height * l_level_stack ) ) / 12.0 ) *
                        i_e_rec.re );

                    ELSE
                        o_drop := nvl(o_drop, 0) + ( ( ( ( c_std_pallet_height * l_level_stack ) - l_next_slot_height ) / 12.0 ) *
                        i_e_rec.le );
                    END IF;

                    o_drop := nvl(o_drop, 0) + i_e_rec.mepidi;
					/*
					**  IF to-slot is higher than from-slot then raise to to-slot.
					**  ELSE lower to to-slot.
					*/
                    IF ( ( c_std_pallet_height * l_level_stack ) > l_next_slot_height ) THEN
                        o_drop := nvl(o_drop, 0) + ( ( ( ( c_std_pallet_height * l_level_stack ) - l_next_slot_height ) / 12.0 ) *
                        i_e_rec.rl );
                    ELSE
                        o_drop := nvl(o_drop, 0) + ( ( ( l_next_slot_height - ( c_std_pallet_height * l_level_stack ) ) / 12.0 ) *
                        i_e_rec.ll );
                    END IF;

                    o_drop := nvl(o_drop, 0) + i_e_rec.bt90;
                    IF ( l_level_stack > 0 ) THEN
                        o_drop := nvl(o_drop, 0) + i_e_rec.ppos;
                    ELSE
                        o_drop := nvl(o_drop, 0) + i_e_rec.ppof;
                    END IF;

                    IF ( g_forklift_audit = c_true ) THEN
                        IF ( i = 0 ) THEN
                            l_message := 'Remove the pallets from the slot above.'
                                         || l_num_recs - 1
                                         || ' pallet(s) to remove.';
                            pl_lm_goaltime.lmg_audit_cmt(pl_lm_goaltime.g_audit_batch_no, l_message, -1);
                        END IF;

                        pl_lm_goaltime.lmg_audit_movement('BT90', pl_lm_goaltime.g_audit_batch_no, i_e_rec, 1, '');
                        pl_lm_goaltime.lmg_audit_movement('APIDI', pl_lm_goaltime.g_audit_batch_no, i_e_rec, 1, '');
                        IF ( l_next_slot_height > ( c_std_pallet_height * l_level_stack ) ) THEN
                            pl_lm_goaltime.lmg_audit_movement('RE', pl_lm_goaltime.g_audit_batch_no, i_e_rec, l_next_slot_height -
                            (c_std_pallet_height * l_level_stack), '');
                        ELSE
                            pl_lm_goaltime.lmg_audit_movement('LE', pl_lm_goaltime.g_audit_batch_no, i_e_rec,(c_std_pallet_height
                            * l_level_stack) - l_next_slot_height, '');
                        END IF;

                        pl_lm_goaltime.lmg_audit_movement('MEPIDI', pl_lm_goaltime.g_audit_batch_no, i_e_rec, 1, '');
                        IF ( ( c_std_pallet_height * l_level_stack ) > l_next_slot_height ) THEN
                            pl_lm_goaltime.lmg_audit_movement('RL', pl_lm_goaltime.g_audit_batch_no, i_e_rec,(c_std_pallet_height
                            * l_level_stack) - l_next_slot_height, '');
                        ELSE
                            pl_lm_goaltime.lmg_audit_movement('LL', pl_lm_goaltime.g_audit_batch_no, i_e_rec, l_next_slot_height -
                            (c_std_pallet_height * l_level_stack), '');
                        END IF;

                        pl_lm_goaltime.lmg_audit_movement('BT90', pl_lm_goaltime.g_audit_batch_no, i_e_rec, 1, '');
                        IF ( l_level_stack > 0 ) THEN
                            pl_lm_goaltime.lmg_audit_movement('PPOS', pl_lm_goaltime.g_audit_batch_no, i_e_rec, 1, '');
                        ELSE
                            pl_lm_goaltime.lmg_audit_movement('PPOF', pl_lm_goaltime.g_audit_batch_no, i_e_rec, 1, '');
                        END IF;

                    END IF;

                    l_level_stack := l_level_stack + 1;
                END LOOP; /* l_num_recs > 1 LOOP */
            END IF;

            l_home_stack := 0;
            l_home_stack_height := 0;
            FOR i IN 1..l_pallets_in_slot LOOP IF ( i <= l_slot_type_num_positions ) THEN
                o_drop := nvl(o_drop, 0) + i_e_rec.bt90 + i_e_rec.apidi;
					/*
					**  Move the FORks up or down to get them at the level of the
					**  pallet in the home slot.
					*/
                IF ( l_slot_height > l_home_stack_height ) THEN
                    o_drop := nvl(o_drop, 0) + ( ( l_slot_height - l_home_stack_height / 12.0 ) * i_e_rec.re );

                ELSE
                    o_drop := nvl(o_drop, 0) + ( ( ( l_home_stack_height - l_slot_height ) / 12.0 ) * i_e_rec.le );
                END IF;
					/* Pickup pallet from home slot. */

                o_drop := nvl(o_drop, 0) + i_e_rec.mepidi;
					/*
					**  Move the FORks up or down to get them at the top of the
					**  home stack.
					*/
                IF ( l_home_stack = 0 ) THEN
                    o_drop := nvl(o_drop, 0) + ( ( 0 / 12.0 ) * i_e_rec.rl );
                ELSIF ( l_slot_height > ( l_home_stack_height + c_std_pallet_height ) ) THEN
                    o_drop := nvl(o_drop, 0) + ( ( l_slot_height - ( l_home_stack_height + c_std_pallet_height ) / 12.0 ) * i_e_rec
                    .ll );
                ELSE
                    o_drop := nvl(o_drop, 0) + ( ( ( ( l_home_stack_height + c_std_pallet_height ) - l_slot_height ) / 12.0 ) * i_e_rec
                    .rl );
                END IF;

                o_drop := nvl(o_drop, 0) + i_e_rec.bt90;
					/*
					** Place the pallet on the home stack.
					*/
                IF ( l_home_stack != 0 ) THEN
                    o_drop := nvl(o_drop, 0) + i_e_rec.ppos;
                ELSE
                    o_drop := nvl(o_drop, 0) + i_e_rec.ppof;
                END IF;

                IF ( g_forklift_audit = c_true ) THEN
                    IF ( i = 1 ) THEN
                        IF ( l_pallets_in_slot < l_slot_type_num_positions ) THEN
                            l_removed_pallet := l_pallets_in_slot;
                        ELSE
                            l_removed_pallet := l_slot_type_num_positions;
                        END IF;

                        l_message := 'Remove '
                                     || l_removed_pallet
                                     || ' pallet(s) in home slot '
                                     || i_pals(l_pindex).dest_loc
                                     || ' putting the pallet(s) in a stack.';

                        pl_lm_goaltime.lmg_audit_cmt(pl_lm_goaltime.g_audit_batch_no, l_message, -1);
                    END IF;

                    pl_lm_goaltime.lmg_audit_movement('BT90', pl_lm_goaltime.g_audit_batch_no, i_e_rec, 1, 'Remove pallet.');
                    pl_lm_goaltime.lmg_audit_movement('APIDI', pl_lm_goaltime.g_audit_batch_no, i_e_rec, 1, '');
                    IF ( l_slot_height > l_home_stack_height ) THEN
                        pl_lm_goaltime.lmg_audit_movement('RE', pl_lm_goaltime.g_audit_batch_no, i_e_rec, l_slot_height - l_home_stack_height
                        , '');
                    ELSE
                        pl_lm_goaltime.lmg_audit_movement('LE', pl_lm_goaltime.g_audit_batch_no, i_e_rec, l_home_stack_height - l_slot_height
                        , '');
                    END IF;

                    pl_lm_goaltime.lmg_audit_movement('MEPIDI', pl_lm_goaltime.g_audit_batch_no, i_e_rec, 1, '');
                    IF ( l_home_stack = 0 ) THEN
                        pl_lm_goaltime.lmg_audit_movement('RL', pl_lm_goaltime.g_audit_batch_no, i_e_rec, 0, '');
                    ELSIF ( l_slot_height > ( l_home_stack_height + c_std_pallet_height ) ) THEN
                        pl_lm_goaltime.lmg_audit_movement('LL', pl_lm_goaltime.g_audit_batch_no, i_e_rec, l_slot_height -(l_home_stack_height
                        + c_std_pallet_height), '');
                    ELSE
                        pl_lm_goaltime.lmg_audit_movement('RL', pl_lm_goaltime.g_audit_batch_no, i_e_rec,(l_home_stack_height + c_std_pallet_height
                        ) - l_slot_height, '');
                    END IF;

                    pl_lm_goaltime.lmg_audit_movement('BT90', pl_lm_goaltime.g_audit_batch_no, i_e_rec, 1, '');
                    IF ( l_home_stack != 0 ) THEN
                        pl_lm_goaltime.lmg_audit_movement('PPOS', pl_lm_goaltime.g_audit_batch_no, i_e_rec, 1, '');
                    ELSE
                        pl_lm_goaltime.lmg_audit_movement('PPOF', pl_lm_goaltime.g_audit_batch_no, i_e_rec, 1, '');
                    END IF;

                END IF;

                l_home_stack := l_home_stack + 1;
					/*
					**  l_home_stack_height is the height of the actual pallet of
					**  the top pallet in the home stack.
					*/
                l_home_stack_height := c_std_pallet_height * ( i - 1 );
            END IF;
            END LOOP; /* END of l_pallets_in_slot LOOP */

        END IF;
		/*
		**  Pull top pallet from stack.
		*/

        IF ( g_forklift_audit = c_true ) THEN
            l_message := 'Pull top pallet '
                         || i_pals(l_pindex).pallet_id
                         || ' from stack and put in slot '
                         || i_pals(l_pindex).dest_loc;

            pl_lm_goaltime.lmg_audit_cmt(pl_lm_goaltime.g_audit_batch_no, l_message, -1);
        END IF;

        IF ( i_num_pallets > 1 ) THEN
			/*
			** There is more than one pallet in the pallet stack.  Get the top
			** pallet from the stack.
			*/
            o_drop := nvl(o_drop, 0) + i_e_rec.bp + i_e_rec.apos;
			/*
			** The FORks will be at the level of the top pallet on the home stack.
			** Move them up or down to get to the level of the top pallet on
			** the stack.
			*/
            IF ( l_pallet_height > ( c_std_pallet_height * ( l_home_stack - 1 ) ) ) THEN
                o_drop := nvl(o_drop, 0) + ( ( ( l_pallet_height - ( c_std_pallet_height * ( l_home_stack - 1 ) ) ) / 12.0 ) * i_e_rec
                .re );

            ELSE
                o_drop := nvl(o_drop, 0) + ( ( ( ( c_std_pallet_height * ( l_home_stack - 1 ) ) - l_pallet_height ) / 12.0 ) * i_e_rec
                .le );
            END IF;

            o_drop := nvl(o_drop, 0) + i_e_rec.mepos;
            IF ( g_forklift_audit = c_true ) THEN
                pl_lm_goaltime.lmg_audit_movement('BP', pl_lm_goaltime.g_audit_batch_no, i_e_rec, 1, '');
                pl_lm_goaltime.lmg_audit_movement('APOS', pl_lm_goaltime.g_audit_batch_no, i_e_rec, 1, '');
                IF ( l_pallet_height > ( c_std_pallet_height * ( l_home_stack - 1 ) ) ) THEN
                    pl_lm_goaltime.lmg_audit_movement('RE', pl_lm_goaltime.g_audit_batch_no, i_e_rec, l_pallet_height -(c_std_pallet_height
                    *(l_home_stack - 1)), '');
                ELSE
                    pl_lm_goaltime.lmg_audit_movement('LE', pl_lm_goaltime.g_audit_batch_no, i_e_rec, c_std_pallet_height *(l_home_stack
                    - 1) - l_pallet_height, '');
                END IF;

                pl_lm_goaltime.lmg_audit_movement('MEPOS', pl_lm_goaltime.g_audit_batch_no, i_e_rec, 1, '');
            END IF;
			/*
			** The top pallet on the stack is now on the FORks.  IF there are open
			** positions in the home slot then put the pallet in the home slot
			** otherwise handstack.
			*/

            IF ( l_pallets_in_slot < l_adj_num_positions ) THEN
				/*
				** There are open positions in the home slot.  Put the pallet in
				** the home slot.
				*/
                IF ( l_slot_height > l_pallet_height ) THEN
                    o_drop := nvl(o_drop, 0) + ( ( ( l_slot_height - l_pallet_height ) / 12.0 ) * i_e_rec.rl );
                ELSE
                    o_drop := nvl(o_drop, 0) + ( ( ( l_pallet_height - l_slot_height ) / 12.0 ) * i_e_rec.ll );
                END IF;

                o_drop := nvl(o_drop, 0) + i_e_rec.bt90 + i_e_rec.apidi + i_e_rec.ppidi;

                IF ( g_forklift_audit = c_true ) THEN
                    IF ( l_slot_height > l_pallet_height ) THEN
                        pl_lm_goaltime.lmg_audit_movement('RL', pl_lm_goaltime.g_audit_batch_no, i_e_rec, l_slot_height - l_pallet_height
                        , '');
                    ELSE
                        pl_lm_goaltime.lmg_audit_movement('LL', pl_lm_goaltime.g_audit_batch_no, i_e_rec, l_pallet_height - l_slot_height
                        , '');
                    END IF;

                    pl_lm_goaltime.lmg_audit_movement('BT90', pl_lm_goaltime.g_audit_batch_no, i_e_rec, 1, '');
                    pl_lm_goaltime.lmg_audit_movement('APIDI', pl_lm_goaltime.g_audit_batch_no, i_e_rec, 1, '');
                    pl_lm_goaltime.lmg_audit_movement('PPIDI', pl_lm_goaltime.g_audit_batch_no, i_e_rec, 1, '');
                END IF;

            ELSE 
				/*
				** There are no open positions in the slot.  Handstack.
				*/
                IF ( g_forklift_audit = c_true ) THEN
                    l_message := 'No open positions in home slot '
                                 || i_pals(l_pindex).dest_loc
                                 || ' Handstack.';
                    pl_lm_goaltime.lmg_audit_cmt(pl_lm_goaltime.g_audit_batch_no, l_message, -1);
                END IF;

                IF ( l_pallet_height > ( c_std_pallet_height * ( l_home_stack - 1 ) ) ) THEN
                    o_drop := nvl(o_drop, 0) + ( ( ( l_pallet_height - ( c_std_pallet_height * ( l_home_stack - 1 ) ) ) / 12.0 ) *
                    i_e_rec.re );

                ELSE
                    o_drop := nvl(o_drop, 0) + ( ( ( ( c_std_pallet_height * ( l_home_stack - 1 ) ) - l_pallet_height ) / 12.0 ) *
                    i_e_rec.re );
                END IF;

                o_drop := nvl(o_drop, 0) + i_e_rec.bp + i_e_rec.apof + i_e_rec.mepof + i_e_rec.ppof;

                IF ( l_last_pal_qty > l_pallet_qty ) THEN
                    l_handstack_cases := l_pallet_qty / l_spc;
                ELSE
                    l_handstack_cases := l_last_pal_qty / l_spc;
                END IF;

                o_drop := nvl(o_drop, 0) + i_e_rec.ds + i_e_rec.bt90 + i_e_rec.apidi + ( ( l_slot_height / 12.0 ) * i_e_rec.rl )

                + i_e_rec.ppidi;

                l_ret_val := pl_lm_forklift.lmf_update_batch_kvi(i_pals(l_pindex).batch_no, l_handstack_cases, l_handstack_splits

                );

                IF ( g_forklift_audit = c_true ) THEN
                    IF ( l_pallet_height > ( c_std_pallet_height * ( l_home_stack - 1 ) ) ) THEN
                        pl_lm_goaltime.lmg_audit_movement('RE', pl_lm_goaltime.g_audit_batch_no, i_e_rec, l_pallet_height -(c_std_pallet_height
                        *(l_home_stack - 1)), '');
                    ELSE
                        pl_lm_goaltime.lmg_audit_movement('RE', pl_lm_goaltime.g_audit_batch_no, i_e_rec,(c_std_pallet_height *(l_home_stack
                        - 1)) - l_pallet_height, '');
                    END IF;

                    pl_lm_goaltime.lmg_audit_movement('BP', pl_lm_goaltime.g_audit_batch_no, i_e_rec, 1, '');
                    pl_lm_goaltime.lmg_audit_movement('APOF', pl_lm_goaltime.g_audit_batch_no, i_e_rec, 1, '');
                    pl_lm_goaltime.lmg_audit_movement('MEPOF', pl_lm_goaltime.g_audit_batch_no, i_e_rec, 1, '');
                    pl_lm_goaltime.lmg_audit_movement('PPOF', pl_lm_goaltime.g_audit_batch_no, i_e_rec, 1, '');
                    l_message := 'Handstack '
                                 || l_handstack_cases
                                 || ' cases.';
                    pl_lm_goaltime.lmg_audit_cmt(pl_lm_goaltime.g_audit_batch_no, l_message, -1);
                    pl_lm_goaltime.lmg_audit_movement('DS', pl_lm_goaltime.g_audit_batch_no, i_e_rec, 1, '');
                    pl_lm_goaltime.lmg_audit_movement('BT90', pl_lm_goaltime.g_audit_batch_no, i_e_rec, 1, '');
                    pl_lm_goaltime.lmg_audit_movement('APIDI', pl_lm_goaltime.g_audit_batch_no, i_e_rec, 1, '');
                    pl_lm_goaltime.lmg_audit_movement('RL', pl_lm_goaltime.g_audit_batch_no, i_e_rec, l_slot_height, '');
                    pl_lm_goaltime.lmg_audit_movement('PPIDI', pl_lm_goaltime.g_audit_batch_no, i_e_rec, 1, '');
                END IF;

            END IF;

            IF ( ( c_std_pallet_height * ( l_home_stack - 1 ) ) > l_slot_height ) THEN
                o_drop := nvl(o_drop, 0) + ( ( ( ( c_std_pallet_height * ( l_home_stack - 1 ) ) - l_slot_height ) / 12.0 ) * i_e_rec
                .le );
            ELSE
                o_drop := nvl(o_drop, 0) + ( ( ( l_slot_height - ( c_std_pallet_height * ( l_home_stack - 1 ) ) ) / 12.0 ) * i_e_rec
                .re );
            END IF;

            o_drop := nvl(o_drop, 0) + i_e_rec.bt90;
            IF ( g_forklift_audit = c_true ) THEN
                IF ( ( c_std_pallet_height * ( l_home_stack - 1 ) ) > l_slot_height ) THEN
                    pl_lm_goaltime.lmg_audit_movement('LE', pl_lm_goaltime.g_audit_batch_no, i_e_rec,(c_std_pallet_height *(l_home_stack
                    - 1)) - l_slot_height, '');

                ELSE
                    pl_lm_goaltime.lmg_audit_movement('RE', pl_lm_goaltime.g_audit_batch_no, i_e_rec, l_slot_height -(c_std_pallet_height
                    *(l_home_stack - 1)), '');
                END IF;
            END IF;

        ELSE 
			/*
			** There is one pallet in the pallet stack.
			*/
            IF ( l_home_stack = 0 ) THEN
                l_home_stack_height := 0;
            ELSE
                l_home_stack_height := c_std_pallet_height * ( l_home_stack - 1 );
            END IF;

            o_drop := nvl(o_drop, 0) + ( ( l_home_stack_height / 12.0 ) * i_e_rec.le );
			/*
			**  Prepare to put the new pallet in the home slot IF there is
			**  an open position or IF the cases to handstack will be
			**  coming from the home slot.
			*/

            IF ( ( l_pallets_in_slot < l_adj_num_positions ) OR ( ( l_pallets_in_slot >= l_adj_num_positions ) AND ( l_last_pal_qty

            <= l_pallet_qty ) ) ) THEN
                o_drop := nvl(o_drop, 0) + i_e_rec.bp + i_e_rec.apof + i_e_rec.mepof;
            END IF;

            IF ( l_pallets_in_slot >= l_adj_num_positions ) THEN
				/*
				**  No open positions in slot.  Handstack.
				*/
                o_drop := nvl(o_drop, 0) + i_e_rec.ds;
                IF ( l_last_pal_qty > l_pallet_qty ) THEN
                    l_handstack_cases := l_pallet_qty / l_spc;
                ELSE
                    l_handstack_cases := l_last_pal_qty / l_spc;
                END IF;

                l_ret_val := pl_lm_forklift.lmf_update_batch_kvi(i_pals(l_pindex).batch_no, l_handstack_cases, l_handstack_splits

                );

            END IF;

            o_drop := nvl(o_drop, 0) + i_e_rec.bt90 + i_e_rec.apidi + ( ( l_slot_height / 12.0 ) * i_e_rec.rl ) + i_e_rec.ppidi;

            IF ( l_home_stack_height > l_slot_height ) THEN
                o_drop := nvl(o_drop, 0) + ( ( ( l_home_stack_height - l_slot_height ) / 12.0 ) * i_e_rec.re );
            ELSE
                o_drop := nvl(o_drop, 0) + ( ( ( l_slot_height - l_home_stack_height ) / 12.0 ) * i_e_rec.le );
            END IF;

            o_drop := nvl(o_drop, 0) + i_e_rec.bt90;
            IF ( g_forklift_audit = c_true ) THEN
                pl_lm_goaltime.lmg_audit_movement('LE', pl_lm_goaltime.g_audit_batch_no, i_e_rec, l_home_stack_height, '');
                IF ( ( l_pallets_in_slot < l_adj_num_positions ) OR ( ( l_pallets_in_slot >= l_adj_num_positions ) AND ( l_last_pal_qty
                <= l_pallet_qty ) ) ) THEN
                    pl_lm_goaltime.lmg_audit_movement('BP', pl_lm_goaltime.g_audit_batch_no, i_e_rec, 1, 'Put new pallet in slot.'
                    );
                    pl_lm_goaltime.lmg_audit_movement('APOF', pl_lm_goaltime.g_audit_batch_no, i_e_rec, 1, '');
                    pl_lm_goaltime.lmg_audit_movement('MEPOF', pl_lm_goaltime.g_audit_batch_no, i_e_rec, 1, '');
                END IF;

                IF ( l_pallets_in_slot >= l_adj_num_positions ) THEN
                    l_message := 'No open positions in slot '
                                 || i_pals(l_pindex).dest_loc
                                 || ' .  Handstack '
                                 || l_handstack_cases
                                 || ' cases.';

                    pl_lm_goaltime.lmg_audit_cmt(pl_lm_goaltime.g_audit_batch_no, l_message, -1);
                    pl_lm_goaltime.lmg_audit_movement('DS', pl_lm_goaltime.g_audit_batch_no, i_e_rec, 1, '');
                END IF;

                pl_lm_goaltime.lmg_audit_movement('BT90', pl_lm_goaltime.g_audit_batch_no, i_e_rec, 1, '');
                pl_lm_goaltime.lmg_audit_movement('APIDI', pl_lm_goaltime.g_audit_batch_no, i_e_rec, 1, '');
                pl_lm_goaltime.lmg_audit_movement('RL', pl_lm_goaltime.g_audit_batch_no, i_e_rec, l_slot_height, '');
                pl_lm_goaltime.lmg_audit_movement('PPIDI', pl_lm_goaltime.g_audit_batch_no, i_e_rec, 1, '');
                IF ( l_home_stack_height > l_slot_height ) THEN
                    pl_lm_goaltime.lmg_audit_movement('RE', pl_lm_goaltime.g_audit_batch_no, i_e_rec, l_home_stack_height - l_slot_height
                    , '');
                ELSE
                    pl_lm_goaltime.lmg_audit_movement('LE', pl_lm_goaltime.g_audit_batch_no, i_e_rec, l_slot_height - l_home_stack_height
                    , '');
                END IF;

                pl_lm_goaltime.lmg_audit_movement('BT90', pl_lm_goaltime.g_audit_batch_no, i_e_rec, 1, '');
            END IF;

        END IF;

        IF ( l_same_slot_flag = 'N' ) THEN	
			/*
			**  The next pallet in the stack, IF there is one, is not going to the
			**  same slot.  Put the pallets in the home stack back into the slot.
			*/
            FOR i IN REVERSE 1..l_home_stack LOOP
				/*
				**  The FORks start out at the level of the top pallet in
				**  the home stack.
				*/
                IF ( i != l_home_stack ) THEN
                    IF ( l_slot_height > ( c_std_pallet_height * ( i - 1 ) ) ) THEN
                        o_drop := nvl(o_drop, 0) + ( ( ( l_slot_height - ( c_std_pallet_height * ( i - 1 ) ) ) / 12.0 ) * i_e_rec
                        .le );

                    ELSE
                        o_drop := nvl(o_drop, 0) + ( ( ( ( c_std_pallet_height * ( i - 1 ) ) - l_slot_height ) / 12.0 ) * i_e_rec
                        .re );
                    END IF;
                END IF;

                IF ( i > 1 ) THEN
                    o_drop := nvl(o_drop, 0) + i_e_rec.apos + i_e_rec.mepos;
                ELSE
                    o_drop := nvl(o_drop, 0) + i_e_rec.apof + i_e_rec.mepof;
                END IF;

                o_drop := o_drop + i_e_rec.bt90 + i_e_rec.apidi;
                IF ( l_slot_height > ( c_std_pallet_height * ( i - 1 ) ) ) THEN
                    o_drop := nvl(o_drop, 0) + ( ( ( l_slot_height - ( c_std_pallet_height * ( i - 1 ) ) ) / 12.0 ) * i_e_rec.rl )
                    ;
                ELSE
                    o_drop := nvl(o_drop, 0) + ( ( ( ( c_std_pallet_height * ( i - 1 ) ) - l_slot_height ) / 12.0 ) * i_e_rec.ll )
                    ;
                END IF;

                o_drop := nvl(o_drop, 0) + i_e_rec.ppidi + i_e_rec.bt90;
                IF ( g_forklift_audit = c_true ) THEN
                    IF ( i = l_home_stack ) THEN
                        l_message := 'Put pallet(s) back in home slot ' || i_pals(l_pindex).dest_loc;
                        pl_lm_goaltime.lmg_audit_cmt(pl_lm_goaltime.g_audit_batch_no, l_message, -1);
                    END IF;

                    IF ( i != l_home_stack ) THEN
                        IF ( l_slot_height > ( c_std_pallet_height * ( i - 1 ) ) ) THEN
                            pl_lm_goaltime.lmg_audit_movement('LE', pl_lm_goaltime.g_audit_batch_no, i_e_rec,(l_slot_height -(c_std_pallet_height
                            *(i - 1))), '');

                        ELSE
                            pl_lm_goaltime.lmg_audit_movement('RE', pl_lm_goaltime.g_audit_batch_no, i_e_rec,((c_std_pallet_height
                            *(i - 1)) - l_slot_height), '');
                        END IF;

                    END IF;

                    IF ( i > 1 ) THEN
                        pl_lm_goaltime.lmg_audit_movement('APOS', pl_lm_goaltime.g_audit_batch_no, i_e_rec, 1, 'Put pallet back in home slot.'
                        );
                        pl_lm_goaltime.lmg_audit_movement('MEPOS', pl_lm_goaltime.g_audit_batch_no, i_e_rec, 1, '');
                    ELSE
                        pl_lm_goaltime.lmg_audit_movement('APOF', pl_lm_goaltime.g_audit_batch_no, i_e_rec, 1, 'Put pallet back in home slot.'
                        );
                        pl_lm_goaltime.lmg_audit_movement('MEPOF', pl_lm_goaltime.g_audit_batch_no, i_e_rec, 1, '');
                    END IF;

                    pl_lm_goaltime.lmg_audit_movement('BT90', pl_lm_goaltime.g_audit_batch_no, i_e_rec, 1, '');
                    pl_lm_goaltime.lmg_audit_movement('APIDI', pl_lm_goaltime.g_audit_batch_no, i_e_rec, 1, '');
                    IF ( l_slot_height > ( c_std_pallet_height * ( i - 1 ) ) ) THEN
                        pl_lm_goaltime.lmg_audit_movement('RL', pl_lm_goaltime.g_audit_batch_no, i_e_rec, l_slot_height -(c_std_pallet_height
                        *(i - 1)), '');
                    ELSE
                        pl_lm_goaltime.lmg_audit_movement('LL', pl_lm_goaltime.g_audit_batch_no, i_e_rec,(c_std_pallet_height *(i
                        - 1)) - l_slot_height, '');
                    END IF;

                    pl_lm_goaltime.lmg_audit_movement('PPIDI', pl_lm_goaltime.g_audit_batch_no, i_e_rec, 1, '');
                    pl_lm_goaltime.lmg_audit_movement('BT90', pl_lm_goaltime.g_audit_batch_no, i_e_rec, 1, '');
                END IF;
				/*
				**  IF last pallet in home stack move the FORks to l_level_stack
				**  height.  This is the level of the top pallet in the stack of
				**  the pallets removed from the slot above.
				*/

                IF ( ( i - 1 ) = 0 AND l_level_stack > 0 ) THEN
                    l_curr_stack_height := c_std_pallet_height * ( l_level_stack - 1 );
                    o_drop := nvl(o_drop, 0) + ( ( l_curr_stack_height / 12.0 ) * i_e_rec.re );

                    IF ( g_forklift_audit = c_true ) THEN
                        pl_lm_goaltime.lmg_audit_movement('RE', pl_lm_goaltime.g_audit_batch_no, i_e_rec, l_curr_stack_height, 'Move FORks to level of the top pallet in the stack of pallets removed from the slot above.'
                        );
                    END IF;

                END IF;

            END LOOP; /* END of l_home_stack LOOP */
			/*
			**  Put back the pallets removed from the slot above.  They will
			**  be in a stack.
			*/

            l_curr_stack_height := c_std_pallet_height * ( l_level_stack - 1 );
            FOR i IN REVERSE 1..l_level_stack LOOP
                IF ( i > 1 ) THEN
                    o_drop := nvl(o_drop, 0) + i_e_rec.apos + i_e_rec.mepos;
                ELSE
                    o_drop := nvl(o_drop, 0) + i_e_rec.apof + i_e_rec.mepof;
                END IF;

                o_drop := nvl(o_drop, 0) + i_e_rec.bt90 + i_e_rec.apidi;
                IF ( l_next_slot_height > l_curr_stack_height ) THEN
                    o_drop := nvl(o_drop, 0) + ( ( ( l_next_slot_height - l_curr_stack_height ) / 12.0 ) * i_e_rec.rl );
                ELSE
                    o_drop := nvl(o_drop, 0) + ( ( ( l_curr_stack_height - l_next_slot_height ) / 12.0 ) * i_e_rec.ll );
                END IF;

                o_drop := nvl(o_drop, 0) + i_e_rec.ppidi;
                IF ( g_forklift_audit = c_true ) THEN
                    IF ( i = l_level_stack ) THEN
                        l_message := 'Put back the pallets removed from the slot above ' || i_pals(l_pindex).dest_loc;
                        pl_lm_goaltime.lmg_audit_cmt(pl_lm_goaltime.g_audit_batch_no, l_message, -1);
                    END IF;

                    IF ( i > 1 ) THEN
                        pl_lm_goaltime.lmg_audit_movement('APOS', pl_lm_goaltime.g_audit_batch_no, i_e_rec, 1, '');
                        pl_lm_goaltime.lmg_audit_movement('MEPOS', pl_lm_goaltime.g_audit_batch_no, i_e_rec, 1, '');
                    ELSE
                        pl_lm_goaltime.lmg_audit_movement('APOF', pl_lm_goaltime.g_audit_batch_no, i_e_rec, 1, '');
                        pl_lm_goaltime.lmg_audit_movement('MEPOF', pl_lm_goaltime.g_audit_batch_no, i_e_rec, 1, '');
                    END IF;

                    pl_lm_goaltime.lmg_audit_movement('BT90', pl_lm_goaltime.g_audit_batch_no, i_e_rec, 1, '');
                    pl_lm_goaltime.lmg_audit_movement('APIDI', pl_lm_goaltime.g_audit_batch_no, i_e_rec, 1, '');
                    IF ( l_next_slot_height > l_curr_stack_height ) THEN
                        pl_lm_goaltime.lmg_audit_movement('RL', pl_lm_goaltime.g_audit_batch_no, i_e_rec, l_next_slot_height - l_curr_stack_height
                        , '');
                    ELSE
                        pl_lm_goaltime.lmg_audit_movement('LL', pl_lm_goaltime.g_audit_batch_no, i_e_rec, l_curr_stack_height - l_next_slot_height
                        , '');
                    END IF;

                    pl_lm_goaltime.lmg_audit_movement('PPIDI', pl_lm_goaltime.g_audit_batch_no, i_e_rec, 1, '');
                END IF;

                IF ( l_curr_stack_height > 0 ) THEN
                    l_curr_stack_height := l_curr_stack_height - c_std_pallet_height;
                END IF;
                IF ( l_curr_stack_height > l_next_slot_height ) THEN
                    o_drop := nvl(o_drop, 0) + ( ( ( l_curr_stack_height - l_next_slot_height ) / 12.0 ) * i_e_rec.re );
                ELSE
                    o_drop := nvl(o_drop, 0) + ( ( ( l_next_slot_height - l_curr_stack_height ) / 12.0 ) * i_e_rec.le );
                END IF;

                o_drop := nvl(o_drop, 0) + i_e_rec.bt90;
                IF ( g_forklift_audit = c_true ) THEN
                    IF ( l_curr_stack_height > l_next_slot_height ) THEN
                        pl_lm_goaltime.lmg_audit_movement('RE', pl_lm_goaltime.g_audit_batch_no, i_e_rec, l_curr_stack_height - l_next_slot_height
                        , '');
                    ELSE
                        pl_lm_goaltime.lmg_audit_movement('LE', pl_lm_goaltime.g_audit_batch_no, i_e_rec, l_next_slot_height - l_curr_stack_height
                        , '');
                    END IF;

                    pl_lm_goaltime.lmg_audit_movement('BT90', pl_lm_goaltime.g_audit_batch_no, i_e_rec, 1, '');
                END IF;

                l_level_stack := l_level_stack - 1;
            END LOOP; /* END of l_level_stack LOOP */

        END IF;
		/*
		** Pickup stack IF there are pallets left and go to the
		** next destination.
		*/

        IF ( i_num_pallets > 1 ) THEN
			/*
			** There are pallets still in the travel stack.
			** Pick up stack and go to next destination.
			*/
            pl_lm_goaltime.lmg_pickup_for_next_dst(i_pals, i_num_pallets - 2, i_e_rec, o_drop);
        END IF;

        RETURN l_ret_val;
    END lmgdi_drp_drvin_hm_with_qoh;

/*****************************************************************************
**  FUNCTION:
**      lmgdi_get_pals_below_to_posx()
**
**  DESCRIPTION:
**      This function gets all the pallets to pos X below the specIFied slot.
**
**  PARAMETERS:
**      i_curr_loc - Current location being processed.
**      i_dest_loc - Destination location FOR pallets being processed.
**      i_dest_qty - Incoming qty to destination slot.
**      i_x        - Position to remove to from the slots below.
**      o_pals     - Pointer to storage to hold returned pallets.
**
**  RETURN VALUES:
**      SEL_INV_FAIL - Selection of inventory failed.
*****************************************************************************/

    FUNCTION lmgdi_get_pals_below_to_posx (
        i_curr_loc   IN           VARCHAR2,
        i_dest_loc   IN           VARCHAR2,
        i_dest_qty   IN           NUMBER,
        i_x          IN           NUMBER,
        o_pals       OUT          pl_lm_goal_pb.tbl_lmg_pallet_rec,
        o_num_recs   OUT          NUMBER
    ) RETURN NUMBER AS

        l_func_name             VARCHAR2(40) := 'lmgdi_get_pals_below_to_posx';
        l_ret_val               NUMBER := c_swms_normal;
        l_message               VARCHAR2(1024);
        l_i                     NUMBER;
        l_loc                   VARCHAR2(10);
        l_last_loc              VARCHAR2(10);
        l_pallet_id             VARCHAR2(10);
        l_prod_id               VARCHAR2(10);
        l_cpv                   VARCHAR2(11);
        l_height                NUMBER;
        l_qoh                   NUMBER;
        l_perm                  VARCHAR2(2);
        l_spc                   NUMBER;
        l_ti                    NUMBER;
        l_hi                    NUMBER;
        l_num_pallets           NUMBER := 1;
        l_num_of_pals_in_slot   NUMBER;
        lmg_pallet              pl_lm_goal_pb.type_lmg_pallet_rec;
        CURSOR c_posx_inv IS
        SELECT
            i.plogi_loc,
            i.logi_loc,
            nvl(l.floor_height, 0),
            l.perm,
            i.qoh,
            p.spc,
            p.ti,
            p.hi,
            p.prod_id,
            p.cust_pref_vendor
        FROM
            pm    p,
            inv   i,
            loc   l,
            loc   l2
        WHERE
            p.prod_id = i.prod_id
            AND i.plogi_loc = l.logi_loc
            AND l.put_level < l2.put_level
            AND l.put_slot = l2.put_slot
            AND l.put_aisle = l2.put_aisle
            AND l2.logi_loc = i_curr_loc
        ORDER BY
            i.plogi_loc;

    BEGIN
        lmg_pallet.pallet_id := '';
        lmg_pallet.prod_id := '';
        lmg_pallet.cpv := '';
        lmg_pallet.qty_on_pallet := '';
        lmg_pallet.loc := '';
        lmg_pallet.dest_loc := '';
        lmg_pallet.perm := '';
        lmg_pallet.uom := '';
        lmg_pallet.height := '';
        lmg_pallet.slot_type := '';
        lmg_pallet.deep_ind := '';
        lmg_pallet.spc := 2;
        lmg_pallet.case_weight := '';
        lmg_pallet.case_cube := '';
        lmg_pallet.case_density := '';
        lmg_pallet.ti := 2;
        lmg_pallet.hi := 1;
        lmg_pallet.exp_date := '';
        lmg_pallet.multi_pallet_drop_to_slot := 'N';
        lmg_pallet.batch_no := '1234';
        lmg_pallet.pallet_type := '';
        lmg_pallet.min_qty := '';
        lmg_pallet.min_qty_num_positions := '';
        lmg_pallet.flow_slot_type := '';
        lmg_pallet.inv_loc := '';
        lmg_pallet.batch_type := '';
        lmg_pallet.demand_hst_active := '';
        lmg_pallet.actual_qty_dropped := '';
        lmg_pallet.hst_qty := '';
        lmg_pallet.user_id := '';
        lmg_pallet.add_hst_qty_to_dest_inv := '';
        lmg_pallet.msku_batch_flag := '';
        lmg_pallet.msku_sort_order := '';
        lmg_pallet.ignore_batch_flag := '';
        lmg_pallet.slot_desc := '';
        lmg_pallet.slot_kind := '';
        lmg_pallet.ref_batch_no := '';
        lmg_pallet.miniload_reserve_put_back_flag := '';
        lmg_pallet.haul_sort_order := '';
        lmg_pallet.dropped_for_a_break_away_flag := '';
        lmg_pallet.resumed_after_break_away_flag := '';
        lmg_pallet.break_away_haul_flag := '';
        o_pals := pl_lm_goal_pb.tbl_lmg_pallet_rec(lmg_pallet);
        l_qoh := 0;
        l_height := 0;
        pl_text_log.ins_msg_async('INFO', l_func_name, 'i_curr_loc= '
                                            || i_curr_loc
                                            || ' i_dest_loc= '
                                            || i_dest_loc
                                            || ' i_dest_qty= '
                                            || i_dest_qty
                                            || ' i_x= '
                                            || i_x, sqlcode, sqlerrm);

		/*
		**  Find all pallets where number of pallets in each slot below the
		**  current reserve slot.
		**  Order by location to help find out IF more than one pallet is in
		**  any of the slots below current reserve slot.
		*/

        OPEN c_posx_inv;
        WHILE ( l_ret_val = c_swms_normal ) LOOP
            BEGIN
                FETCH c_posx_inv INTO
                    l_loc,
                    l_pallet_id,
                    l_height,
                    l_perm,
                    l_qoh,
                    l_spc,
                    l_ti,
                    l_hi,
                    l_prod_id,
                    l_cpv;

                IF c_posx_inv%notfound THEN
                    pl_text_log.ins_msg_async('WARN', l_func_name, 'Failed when getting inventory below location', sqlcode, sqlerrm);
                    l_ret_val := rf.status_sel_inv_fail;
                END IF;

            END;
			/*
			**  IF permanent, must count the number of pallets in slot.
			*/

            IF ( l_perm = 'Y' ) THEN

				/*
				**  Remove the quantity going to the slot from the slot.
				**  This is FOR replenishments.
				*/
                IF ( i_dest_loc = l_loc ) THEN
                    IF i_dest_qty > l_qoh THEN
                        l_qoh := 0;
                    ELSE
                        l_qoh := l_qoh - i_dest_qty;
                    END IF;
                END IF;

                IF ( l_qoh != 0 ) THEN
                    l_num_of_pals_in_slot := l_qoh / ( l_ti * l_hi * l_spc );
                    IF ( MOD(l_qoh,(l_ti * l_hi * l_spc)) != 0 ) THEN
                        l_num_of_pals_in_slot := l_num_of_pals_in_slot + 1;
                    END IF;

                ELSE
                    l_num_of_pals_in_slot := 0;
                END IF;
				/*
				**  Leave X pallets in the slot.
				*/

                FOR i IN i_x..l_num_of_pals_in_slot LOOP
                    o_pals(l_num_pallets).loc := l_loc;
                    o_pals(l_num_pallets).pallet_id := l_i;
                    o_pals(l_num_pallets).perm := l_perm;
                    o_pals(l_num_pallets).height := l_height;
                    o_pals(l_num_pallets).qty_on_pallet := l_qoh;
                    l_num_pallets := l_num_pallets + 1;
                END LOOP;

            ELSE
				/*
				**  Must be reserve: IF location is same then more than one pallet
				**  was in the slot.  IF only when the same, then the position one
				**  pallet will always be skipped.
				*/
                IF ( l_last_loc = l_loc ) THEN
                    o_pals(l_num_pallets).loc := l_loc;
                    o_pals(l_num_pallets).pallet_id := l_pallet_id;
                    o_pals(l_num_pallets).perm := l_perm;
                    o_pals(l_num_pallets).height := l_height;
                    o_pals(l_num_pallets).qty_on_pallet := l_qoh;
                    l_num_pallets := l_num_pallets + 1;
                END IF;
            END IF;

            l_last_loc := l_loc;
        END LOOP; /* END of l_ret_val = c_swms_normal LOOP */

        CLOSE c_posx_inv;
        IF ( l_ret_val = c_swms_normal ) THEN
            o_num_recs := l_num_pallets;
        END IF;
        pl_text_log.ins_msg_async('INFO', l_func_name, 'l_num_pallets= ' || l_num_pallets, sqlcode, sqlerrm);
        RETURN l_ret_val;
    END lmgdi_get_pals_below_to_posx;

/*****************************************************************************
**  FUNCTION:
**      lmgdi_drp_drvin_res_with_qoh()
**
**  DESCRIPTION:
**      This functions calculates the LM drop discreet value FOR a pallet
**      going to a reserve drive in slot this is EMPTY OR HAS EXISTING
**      INVENTORY.
**
**      IF there is more than one pallet going to the same slot then they
**      are all processed the first time this function is called.
**
**
**  PARAMETERS:
**      i_pals         - Pointer to pallet list.
**      i_num_pallets  - Number of pallets in pallet list.
**      i_e_rec        - Pointer to equipment tmu values.
**      i_inv          - Pointer to pallets already in the destination.
**      i_is_same_item - Flag denoting IF the same item is already in the
**                       destination location.
**      o_drop         - Outgoing drop value.
**
**  RETURN VALUES:
**      Result from lmgdi_get_pals_to_posx().
*****************************************************************************/

    FUNCTION lmgdi_drp_drvin_res_with_qoh (
        i_pals           IN               pl_lm_goal_pb.tbl_lmg_pallet_rec,
        i_num_pallets    IN               NUMBER,
        i_e_rec          IN               pl_lm_goal_pb.type_lmc_equip_rec,
        i_inv            IN               pl_lm_goal_pb.tbl_lmg_inv_rec,
        i_num_recs       IN               NUMBER,
        i_is_same_item   IN               VARCHAR2,
        o_drop           OUT              NUMBER
    ) RETURN NUMBER AS

        l_posx_pals                     pl_lm_goal_pb.tbl_lmg_pallet_rec;
        l_aisle_stack_height            NUMBER := 0;
        l_drop_type                     NUMBER;
        l_existing_inv                  NUMBER;
        l_func_name                     VARCHAR2(40) := 'lmgdi_drp_drvin_res_with_qoh';
        l_home_slot_bln                 NUMBER := c_false;
        l_pallet_height                 NUMBER := 0;
        l_num_pallets_in_travel_stack   NUMBER;
        l_num_pending_putaways          NUMBER := 0;
        l_num_drops_completed           NUMBER := 0;
        l_pallets_in_slot               NUMBER := 0;
        l_pallets_to_move               NUMBER := 0;
        l_pindex                        NUMBER := 1;
        l_putback_existing_inv          NUMBER;
        l_remove_existing_inv           NUMBER;
        l_selected_below_pallets_bln    NUMBER;
        l_slot_height                   NUMBER := 0;
        l_slot_type_num_positions       NUMBER;
        l_total_pallets_in_slot         NUMBER := 0;
        l_message                       VARCHAR2(1024);
        l_ret_val                       NUMBER := c_swms_normal;
        l_num_recs                      NUMBER;
    BEGIN
        pl_text_log.ins_msg_async('INFO', l_func_name, 'Starting lmgdi_drp_drvin_res_with_qoh..i_num_pallets= ' || i_num_pallets, sqlcode
        , sqlerrm);
        pl_text_log.ins_msg_async('INFO', l_func_name, 'i_pals.pallet_id(i_num_pallets-1)= '
                                            || i_pals(i_num_pallets - 1).pallet_id
                                            || ' i_num_pallets= '
                                            || i_num_pallets
                                            || ' i_e_rec.equip_id= '
                                            || i_e_rec.equip_id
                                            || ' i_num_recs= '
                                            || i_num_recs
                                            || ' i_is_same_item= '
                                            || i_is_same_item, sqlcode, sqlerrm);
	  
		/*
		**  Always removing the top pallet on the stack.
		*/

        l_pindex := i_num_pallets - 1;
        l_num_pallets_in_travel_stack := i_num_pallets;
        l_slot_height := i_pals(l_pindex).height;
        l_selected_below_pallets_bln := c_false;
		/*
		**  Same slot drops were processed by this function on first pallet dropped
		**  to the slot.
		*/
        IF ( i_pals(l_pindex).multi_pallet_drop_to_slot = 'Y' ) THEN
            RETURN l_ret_val;
        END IF;
        l_pallets_in_slot := i_num_recs;
        o_drop := 0.0;
		/*
		** Extract the number of positions in the slot from the slot type.
		*/
        /*slot type is in 10th position in the argument passing from Input. Here l_slot_type_num_positions defined as 10 instead of slot type*/
        l_slot_type_num_positions := 10; /*i_pals(l_pindex).slot_type;*/ 
		/*
		** Determine IF the existing inventory in the slot needs to be removed.
		** FOR putaways going to the same slot on a PO the inventory is removed
		** when the first putaway is perFORmed and put back after the last
		** putaway is perFORmed.  Pallets from previous puts on the same PO
		** are not removed.
		*/
        pl_lm_goaltime.lmg_drop_rotation(i_num_recs, i_pals, i_num_pallets, i_num_recs, i_inv, l_drop_type, l_num_drops_completed
        , l_num_pending_putaways, l_pallets_to_move, l_remove_existing_inv, l_putback_existing_inv, l_existing_inv, l_total_pallets_in_slot
        );
        /*
		** Process the pallets in the stack going to the same slot.
		*/

        FOR i IN REVERSE 1..l_pindex LOOP
			/*
			**  Get out of the loop IF all the drops to the same slot
			**  have been processed.
			*/
            IF ( i != l_pindex AND i_pals(i).multi_pallet_drop_to_slot = 'N' ) THEN
                pl_text_log.ins_msg_async('INFO', l_func_name, 'Break statement', sqlcode, sqlerrm);
            END IF;

            IF ( g_forklift_audit = c_true ) THEN
                pl_lm_goaltime.lmg_drop_to_reserve_audit_msg(i_pals, i, l_pallets_in_slot, l_num_drops_completed);
            END IF;
			/*
			**  Put travel stack down IF there is more than one pallet in the travel
			**  stack or IF the existing pallets in the slot need to be removed
			**  and the travel stack is not already down.
			*/

            IF ( ( i = l_pindex ) AND ( i_num_pallets > 1 OR l_remove_existing_inv != 0 ) ) THEN
                o_drop := nvl(o_drop, 0) + i_e_rec.ppof;
                IF ( ( i_num_pallets > 1 ) AND ( l_existing_inv = c_in_aisle ) AND ( l_pallets_in_slot > 0 ) ) THEN
                    o_drop := nvl(o_drop, 0) + i_e_rec.bp;
                    IF ( g_forklift_audit = c_true ) THEN
                        l_message := 'The existing inventory stacked in the aisle on a previous drop.  Put stack down because there is more than one pallet('
                                     || i_num_pallets
                                     || ' pallets total) in the stack.';
                        pl_lm_goaltime.lmg_audit_movement('PPOF', pl_lm_goaltime.g_audit_batch_no, i_e_rec, 1, l_message);
                        pl_lm_goaltime.lmg_audit_movement('BP', pl_lm_goaltime.g_audit_batch_no, i_e_rec, 1, l_message);
                    END IF;

                ELSE 
					/*
					**  The existing inventory will be removed.
					*/
                    o_drop := nvl(o_drop, 0) + i_e_rec.bt90;
                    IF ( g_forklift_audit = c_true ) THEN
                        pl_lm_goaltime.lmg_audit_movement('PPOF', pl_lm_goaltime.g_audit_batch_no, i_e_rec, 1, 'Put stack down.')
                        ;
                        pl_lm_goaltime.lmg_audit_movement('BT90', pl_lm_goaltime.g_audit_batch_no, i_e_rec, 1, '');
                    END IF; /* END audit */

                END IF;

            END IF;
			/*
			**  Remove the pallets from the slot IF existing inventory is to
			**  be removed and there are pallets to remove and processing the
			**  first pallet in the travel stack.
			*/

            IF ( ( l_remove_existing_inv != 0 ) AND ( l_pallets_to_move > 0 ) AND ( i = l_pindex ) ) THEN
                IF ( g_forklift_audit = c_true ) THEN
                    l_message := 'Have the same item in slot '
                                 || i_pals(l_pindex).dest_loc
                                 || ' . Take current inventory of '
                                 || i_num_recs
                                 || ' pallet(s) out of the slot.';

                    pl_lm_goaltime.lmg_audit_cmt(pl_lm_goaltime.g_audit_batch_no, l_message, -1);
                END IF;

                l_aisle_stack_height := 0;
                l_ret_val := lmgdi_rem_plts_from_res_slt(i_e_rec, i_pals(l_pindex).dest_loc, l_slot_height, i_num_recs, l_home_slot_bln
                , l_aisle_stack_height, o_drop);
                /* 
				** Remove the pallets below the slot.
				*/
--                pl_lm_goaltime.lmg_clear_pallet_struct(l_posx_pals);

                l_ret_val := lmgdi_get_pals_below_to_posx(i_pals(l_pindex).dest_loc, '', 0, 1, l_posx_pals, l_num_recs);

                IF ( l_ret_val != c_swms_normal) THEN
                    RETURN l_ret_val;
                END IF;
                l_selected_below_pallets_bln := c_true;
                l_ret_val := lmgdi_remove_below_pallets(i_e_rec, i_pals(l_pindex).dest_loc, l_posx_pals, l_num_recs, l_aisle_stack_height
                , o_drop);

            END IF;

            IF ( g_forklift_audit = c_true AND l_remove_existing_inv = 0 AND l_pallets_to_move > 0 ) THEN
				/*
				** There are pallets to remove and the flag set to not remove
				** existing inv move which means the pallets were removed on a
				** previous putaway.
				*/
                l_message := 'The existing '
                             || l_pallets_to_move
                             || ' pallet(s) removed from the slot on a previous putaway.';
                pl_lm_goaltime.lmg_audit_cmt(pl_lm_goaltime.g_audit_batch_no, l_message, -1);
            END IF;

            l_pallet_height := c_std_pallet_height * i;  /* Travel stack height */
            IF ( i_num_pallets = 1 ) THEN
                IF ( l_existing_inv = c_in_aisle ) THEN
                    NULL;
                ELSIF ( l_existing_inv = c_in_slot AND l_remove_existing_inv != 0 ) THEN
				/*
                ** The existing inventory in the slot has been removed FOR this
                ** drop.  Prepare to pickup the pallet in the travel stack.
                **
                ** Move the FORks from the height of the last pallet removed
                ** from the slot to the top pallet in the travel stack.
                */
                    IF ( l_aisle_stack_height > l_pallet_height ) THEN
                        o_drop := nvl(o_drop, 0) + ( ( ( l_aisle_stack_height - l_pallet_height ) / 12.0 ) * i_e_rec.le );
                    ELSE
                        o_drop := nvl(o_drop, 0) + ( ( ( l_pallet_height - l_aisle_stack_height ) / 12.0 ) * i_e_rec.re );
                    END IF;

                    o_drop := nvl(o_drop, 0) + i_e_rec.apof;
                    IF ( g_forklift_audit = c_true ) THEN
                        l_message := 'The existing inventory in slot '
                                     || i_pals(i).dest_loc
                                     || ' has been removed.  Pickup pallet '
                                     || i_pals(i).pallet_id
                                     || ' in stack and put in slot '
                                     || i_pals(i).dest_loc;

                        pl_lm_goaltime.lmg_audit_cmt(pl_lm_goaltime.g_audit_batch_no, l_message, -1);
                        IF ( l_aisle_stack_height > l_pallet_height ) THEN
                            pl_lm_goaltime.lmg_audit_movement('LE', pl_lm_goaltime.g_audit_batch_no, i_e_rec, l_aisle_stack_height
                            - l_pallet_height, '');
                        ELSE
                            pl_lm_goaltime.lmg_audit_movement('RE', pl_lm_goaltime.g_audit_batch_no, i_e_rec, l_pallet_height - l_aisle_stack_height
                            , '');
                        END IF;

                        pl_lm_goaltime.lmg_audit_movement('APOF', pl_lm_goaltime.g_audit_batch_no, i_e_rec, 1, '');
                    END IF;

                END IF;
				/*
				**  Drop new pallet into slot.
				**  IF the existing inventory in the slot was removed FOR this drop
				**  then the FORks are at the level of the last pallet removed
				**  otherwise the pallet to drop is on the FORks.
				*/

                IF ( l_remove_existing_inv != 0 ) THEN
					/*
					**  The existing inventory in the slot was removed on this drop.
					**  Their is 1 pallet in the travel stack so lower the FORks to
					**  the floor, pickup the pallet and place it in the slot.
					*/
                    o_drop := nvl(o_drop, 0) + i_e_rec.mepof + i_e_rec.bt90;
                    IF ( g_forklift_audit = c_true ) THEN
                        pl_lm_goaltime.lmg_audit_movement('MEPOF', pl_lm_goaltime.g_audit_batch_no, i_e_rec, 1, '');
                        pl_lm_goaltime.lmg_audit_movement('BT90', pl_lm_goaltime.g_audit_batch_no, i_e_rec, 1, '');
                    END IF;

                ELSE
                    o_drop := nvl(o_drop, 0) + i_e_rec.tir;
                    IF ( g_forklift_audit = c_true ) THEN
                        pl_lm_goaltime.lmg_audit_movement('TIR', pl_lm_goaltime.g_audit_batch_no, i_e_rec, 1, '');
                    END IF;

                END IF;
				/*
				** Place the pallet in the slot.
				*/

                o_drop := nvl(o_drop, 0) + i_e_rec.apidi + ( ( l_slot_height / 12.0 ) * i_e_rec.rl ) + i_e_rec.ppidi + i_e_rec.bt90

                ;

                IF ( g_forklift_audit = c_true ) THEN
                    pl_lm_goaltime.lmg_audit_movement('APIDI', pl_lm_goaltime.g_audit_batch_no, i_e_rec, 1, '');
                    pl_lm_goaltime.lmg_audit_movement('RL', pl_lm_goaltime.g_audit_batch_no, i_e_rec, l_slot_height, '');
                    pl_lm_goaltime.lmg_audit_movement('PPIDI', pl_lm_goaltime.g_audit_batch_no, i_e_rec, 1, '');
                    pl_lm_goaltime.lmg_audit_movement('BT90', pl_lm_goaltime.g_audit_batch_no, i_e_rec, 1, '');
                END IF;

            ELSE 
				/*
				**  There is more than one pallet in the pallet stack.
				**
				**  Put the stack down (IF not already down), take off the
				**  top pallet and put it in the slot.
				*/
                IF ( g_forklift_audit = c_true ) THEN
                    l_message := 'Remove pallet %s from top of stack ' || i_pals(i).pallet_id;
                    pl_lm_goaltime.lmg_audit_cmt(pl_lm_goaltime.g_audit_batch_no, l_message, -1);
                END IF;

                IF ( i = l_pindex ) THEN
					/*
					**  First pallet being processed.  The stack has already
					**  been put down.  Get the top pallet off the stack.
					*/
                    o_drop := nvl(o_drop, 0) + i_e_rec.bp + i_e_rec.apos + ( ( l_pallet_height / 12.0 ) * i_e_rec.re ) + i_e_rec.
                    mepos;

                    IF ( g_forklift_audit = c_true ) THEN
                        pl_lm_goaltime.lmg_audit_movement('BP', pl_lm_goaltime.g_audit_batch_no, i_e_rec, 1, '');
                        pl_lm_goaltime.lmg_audit_movement('APOS', pl_lm_goaltime.g_audit_batch_no, i_e_rec, 1, '');
                        pl_lm_goaltime.lmg_audit_movement('RE', pl_lm_goaltime.g_audit_batch_no, i_e_rec, l_pallet_height, '');
                        pl_lm_goaltime.lmg_audit_movement('MEPOS', pl_lm_goaltime.g_audit_batch_no, i_e_rec, 1, '');
                    END IF;

                ELSE 
					/*
					**  The previous pallet has been put in the slot, remove
					**  the top pallet from the stack.  The FORks are at the
					**  level of the slot.
					*/
                    IF ( l_slot_height > l_pallet_height ) THEN
                        o_drop := nvl(o_drop, 0) + ( ( ( l_slot_height - l_pallet_height ) / 12.0 ) * i_e_rec.le );

                        IF ( g_forklift_audit = c_true ) THEN
                            pl_lm_goaltime.lmg_audit_movement('LE', pl_lm_goaltime.g_audit_batch_no, i_e_rec, l_slot_height - l_pallet_height
                            , '');

                        END IF;

                    ELSE
                        o_drop := nvl(o_drop, 0) + ( ( ( l_pallet_height - l_slot_height ) / 12.0 ) * i_e_rec.re );

                        IF ( g_forklift_audit = c_true ) THEN
                            pl_lm_goaltime.lmg_audit_movement('RE', pl_lm_goaltime.g_audit_batch_no, i_e_rec, l_pallet_height - l_slot_height
                            , '');

                        END IF;

                    END IF;

                    IF ( i = 0 ) THEN
						/*
						**  At the last pallet in the stack so it is
						**  on the floor.
						*/
                        o_drop := nvl(o_drop, 0) + i_e_rec.apof + i_e_rec.mepof;
                        IF ( g_forklift_audit = c_true ) THEN
                            pl_lm_goaltime.lmg_audit_movement('APOF', pl_lm_goaltime.g_audit_batch_no, i_e_rec, 1, '');
                            pl_lm_goaltime.lmg_audit_movement('MEPOF', pl_lm_goaltime.g_audit_batch_no, i_e_rec, 1, '');
                        END IF;

                    ELSE 
						/*
						**  Get the pallet off the stack.
						*/
                        o_drop := nvl(o_drop, 0) + i_e_rec.apos + i_e_rec.mepos;
                        IF ( g_forklift_audit = c_true ) THEN
                            pl_lm_goaltime.lmg_audit_movement('APOS', pl_lm_goaltime.g_audit_batch_no, i_e_rec, 1, '');
                            pl_lm_goaltime.lmg_audit_movement('MEPOS', pl_lm_goaltime.g_audit_batch_no, i_e_rec, 1, '');
                        END IF;

                    END IF;

                END IF;
				/*
				**  The pallet is on the FORks.  Move the FORks up or down as
				**  appropriate and put the pallet in the slot.
				*/

                IF ( l_slot_height > l_pallet_height ) THEN
                    o_drop := nvl(o_drop, 0) + i_e_rec.bt90 + i_e_rec.apidi + ( ( ( l_slot_height - l_pallet_height ) / 12.0 ) * i_e_rec
                    .rl ) + i_e_rec.ppidi + i_e_rec.bt90;
                ELSE
                    o_drop := nvl(o_drop, 0) + i_e_rec.bt90 + i_e_rec.apidi + ( ( ( l_pallet_height - l_slot_height ) / 12.0 ) * i_e_rec
                    .ll ) + i_e_rec.ppidi + i_e_rec.bt90;
                END IF;

                IF ( g_forklift_audit = c_true ) THEN
                    l_message := 'Put pallet '
                                 || i_pals(i).pallet_id
                                 || ' in slot '
                                 || i_pals(i).dest_loc;

                    pl_lm_goaltime.lmg_audit_movement('BT90', pl_lm_goaltime.g_audit_batch_no, i_e_rec, 1, l_message);
                    pl_lm_goaltime.lmg_audit_movement('APIDI', pl_lm_goaltime.g_audit_batch_no, i_e_rec, 1, '');
                    IF ( l_slot_height > l_pallet_height ) THEN
                        pl_lm_goaltime.lmg_audit_movement('RL', pl_lm_goaltime.g_audit_batch_no, i_e_rec, l_slot_height - l_pallet_height
                        , '');
                    ELSE
                        pl_lm_goaltime.lmg_audit_movement('LL', pl_lm_goaltime.g_audit_batch_no, i_e_rec, l_pallet_height - l_slot_height
                        , '');
                    END IF;

                    pl_lm_goaltime.lmg_audit_movement('PPIDI', pl_lm_goaltime.g_audit_batch_no, i_e_rec, 1, '');
                    pl_lm_goaltime.lmg_audit_movement('BT90', pl_lm_goaltime.g_audit_batch_no, i_e_rec, 1, '');
                END IF;

            END IF;

            l_num_drops_completed := l_num_drops_completed + 1;
            l_pallets_in_slot := l_pallets_in_slot + 1;
            l_num_pallets_in_travel_stack := l_num_pallets_in_travel_stack - 1;
        END LOOP;
        /*
		**  Put back the existing inventory pallets that were removed IF
		**  appropriate.
		**  FOR non putaway drops the pallets are always put back into the slot.
		**  FOR putaways the pallets are put back IF this is the only putaway
		**  or the last putaway to the slot on the PO.
		*/

        IF ( l_putback_existing_inv != 0 ) THEN
            lmgdi_putbk_plts_in_res_slt(i_e_rec, i_pals(l_pindex).dest_loc, l_slot_height, l_pallets_to_move, l_home_slot_bln
            , l_slot_height, o_drop);
			/*
			** Get the pallets below IF not already done so.
			** Need to do this in order by populate the
			** l_posx_pals structure.  This situation would occur during
			** putaway when there is more than one pallet going to the slot
			** and the pallets are on dIFferent batches.
			*/

            IF ( l_selected_below_pallets_bln = 0 ) THEN
                l_ret_val := lmgdi_get_pals_below_to_posx(i_pals(l_pindex).dest_loc, '', 0, 1, l_posx_pals, l_num_recs);

                IF ( l_ret_val != c_swms_normal ) THEN
                    RETURN l_ret_val;
                END IF;
            END IF;
			/*
			** Putback the pallets removed from the slots below.  The FORks
			** are at the slot height.
			*/

            lmgdi_putback_below_pallets(i_e_rec, i_pals(l_pindex).dest_loc, l_slot_height, l_posx_pals, i_num_recs, o_drop);

        ELSE	
			/*
			**  The FORks are at the slot height.  Lower the FORks to the floor.
			*/
            o_drop := nvl(o_drop, 0) + ( ( l_slot_height / 12.0 ) * i_e_rec.le );

            IF ( g_forklift_audit = c_true ) THEN
                pl_lm_goaltime.lmg_audit_movement('LE', pl_lm_goaltime.g_audit_batch_no, i_e_rec, l_slot_height, '');
            END IF;

        END IF;
		/*
		** Pickup stack IF there are pallets left and go to the
		** next destination.
		*/

        IF ( l_num_pallets_in_travel_stack >= 1 ) THEN
			/*
			** There are pallets still in the travel stack.
			** Pick up stack and go to next destination.
			*/
            pl_lm_goaltime.lmg_pickup_for_next_dst(i_pals, l_num_pallets_in_travel_stack - 1, i_e_rec, o_drop);
        END IF;

        RETURN l_ret_val;
    END lmgdi_drp_drvin_res_with_qoh;

/*****************************************************************************
**  FUNCTION:
**      lmgdi_rem_plts_from_res_slt()
**
**  DESCRIPTION:
**      This function removes the existing pallets from a reserve drive-in
**      slot and stacks them in the aisle.  The pallets in the slot cannot
**      be stacked.  The pallets are stacked in the aisle with no more than
**      MAX_PALS_PER_STACK_DI in a stack.  IF it is a home slot then the
**      pick pallet is placed by itself in the aisle.
**
**      05/10/01  This function could be modIFied FOR home slots IF needed.
**      Code exists FOR home slots but does not fit the current requirements.
**
**  PARAMETERS:
**      i_e_rec                 - Pointer to equipment tmu values.
**      i_location              - Slot to remove the pallets from.
**      i_slot_height           - Slot height.
**      i_num_pallets_to_remove - Number of pallets to remove from the slot.
**      i_home_slot_bln         - Indicates IF the slot is a home slot.
**                                Always FALSE.
**      io_current_FORk_height  - Current height of FORks.
**      o_drop                  - Outgoing drop value.
**
**  RETURN VALUES:
**      None.
*****************************************************************************/

    FUNCTION lmgdi_rem_plts_from_res_slt (
        i_e_rec                   IN                        pl_lm_goal_pb.type_lmc_equip_rec,
        i_location                IN                        VARCHAR2,
        i_slot_height             IN                        NUMBER,
        i_num_pallets_to_remove   IN                        NUMBER,
        i_home_slot_bln           IN                        NUMBER,
        io_current_fork_height    IN OUT                    NUMBER,
        o_drop                    OUT                       NUMBER
    ) RETURN NUMBER AS

        l_func_name                VARCHAR2(40) := 'lmgdi_rem_plts_from_res_slt';
        l_height_diff              NUMBER;
        l_num_pallets_to_remove    NUMBER;
        l_pallet_count             NUMBER;
        l_pallets_in_aisle_stack   NUMBER := 0;
        l_aisle_stack_height       NUMBER;
        l_message                  VARCHAR2(1024);
        l_pindex                   NUMBER := 1;
        i_home_slot_bln_tmp        VARCHAR2(10);
    BEGIN
        pl_text_log.ins_msg_async('INFO', l_func_name, 'Starting lmgdi_rem_plts_from_res_slt.. ', sqlcode, sqlerrm);
        IF i_home_slot_bln = c_true THEN
            i_home_slot_bln_tmp := 'True';
        ELSE
            i_home_slot_bln_tmp := 'False';
        END IF;

        pl_text_log.ins_msg_async('INFO', l_func_name, 'i_location = '
                                            || i_location
                                            || ' i_num_pallets_to_remove= '
                                            || i_num_pallets_to_remove
                                            || ' i_home_slot_bln= '
                                            || i_home_slot_bln_tmp
                                            || ' io_current_FORk_height= '
                                            || io_current_fork_height, sqlcode, sqlerrm);

        l_num_pallets_to_remove := i_num_pallets_to_remove;
        l_pallet_count := i_num_pallets_to_remove;
		/*
		**  FOR home slots remove the pick pallet.  The pick pallet is at the
		**  front of the slot and is the pallet the order selectors pick from.
		**  It should be on the floor.
		*/
        IF ( i_home_slot_bln != 0 ) THEN
			/*
			**  Remove the pick pallet from the home slot.
			*/
            o_drop := nvl(o_drop, 0) + i_e_rec.bt90 + i_e_rec.apidi;
            l_height_diff := io_current_fork_height - i_slot_height;
            IF ( l_height_diff > 0 ) THEN
                o_drop := nvl(o_drop, 0) + ( ( l_height_diff / 12.0 ) * i_e_rec.le );
            ELSE
                o_drop := nvl(o_drop, 0) + ( ( abs(l_height_diff) / 12.0 ) * i_e_rec.re );
            END IF;

            o_drop := nvl(o_drop, 0) + i_e_rec.mepidi + i_e_rec.bt90 + ( ( i_slot_height / 12.0 ) * i_e_rec.ll ) + i_e_rec.ppof +

            i_e_rec.bt90;

            IF ( g_forklift_audit = c_true ) THEN
                pl_lm_goaltime.lmg_audit_movement('BT90', pl_lm_goaltime.g_audit_batch_no, i_e_rec, 1, 'Remove pick pallet from the home slot.'
                );
                pl_lm_goaltime.lmg_audit_movement('APIDI', pl_lm_goaltime.g_audit_batch_no, i_e_rec, 1, '');
                IF ( l_height_diff > 0 ) THEN
                    pl_lm_goaltime.lmg_audit_movement('LE', pl_lm_goaltime.g_audit_batch_no, i_e_rec, l_height_diff, '');
                ELSE
                    pl_lm_goaltime.lmg_audit_movement('RE', pl_lm_goaltime.g_audit_batch_no, i_e_rec, abs(l_height_diff), '');
                END IF;

                pl_lm_goaltime.lmg_audit_movement('MEPIDI', pl_lm_goaltime.g_audit_batch_no, i_e_rec, 1, '');
                pl_lm_goaltime.lmg_audit_movement('BT90', pl_lm_goaltime.g_audit_batch_no, i_e_rec, 1, '');
                pl_lm_goaltime.lmg_audit_movement('LL', pl_lm_goaltime.g_audit_batch_no, i_e_rec, i_slot_height, '');
                pl_lm_goaltime.lmg_audit_movement('PPOF', pl_lm_goaltime.g_audit_batch_no, i_e_rec, 1, '');
                pl_lm_goaltime.lmg_audit_movement('BT90', pl_lm_goaltime.g_audit_batch_no, i_e_rec, 1, '');
            END IF;
			/*
			**  Show that the pick pallet was removed.
			*/

            l_pallet_count := l_pallet_count - 1;
            l_num_pallets_to_remove := l_num_pallets_to_remove - 1;
        END IF;
		/*
		**  Remove the rest of the pallets from the slot.
		**  The pallets will be stacked in the aisle with a max of
		**  MAX_PALS_PER_STACK_DI pallets in a stack.
		*/

        IF ( g_forklift_audit = c_true AND l_pallet_count > 0 ) THEN
			/* A home slot gets a slightly dIFferent message. */
            l_message := 'Remove the pallet(s) in slot '
                         || i_location
                         || ' stacking them in the aisle with no more than '
                         || c_max_pals_per_stack_di
                         || ' pallet(s) in a stack.';
            pl_lm_goaltime.lmg_audit_cmt(pl_lm_goaltime.g_audit_batch_no, l_message, -1);
        END IF;

        l_aisle_stack_height := 0;
        WHILE ( l_pallet_count > 0 ) LOOP
            l_pallets_in_aisle_stack := 0;
            FOR i IN 1..c_max_pals_per_stack_di LOOP IF ( l_pallet_count > 0 ) THEN
                IF ( g_forklift_audit = c_true ) THEN
                    pl_lm_goaltime.lmg_audit_cmt(pl_lm_goaltime.g_audit_batch_no, 'Remove pallet from slot and stack in aisle.', -
                    1);
                END IF;

                l_height_diff := i_slot_height - l_aisle_stack_height;
                IF ( l_height_diff > 0 ) THEN
                    o_drop := nvl(o_drop, 0) + ( ( abs(l_height_diff) / 12.0 ) * i_e_rec.re );
                ELSE
                    o_drop := nvl(o_drop, 0) + ( ( abs(l_height_diff) / 12.0 ) * i_e_rec.le );
                END IF;

                o_drop := nvl(o_drop, 0) + i_e_rec.apidi + i_e_rec.mepidi + i_e_rec.bt90;

                IF ( g_forklift_audit = c_true ) THEN
                    IF ( l_height_diff > 0 ) THEN
                        pl_lm_goaltime.lmg_audit_movement('RE', pl_lm_goaltime.g_audit_batch_no, i_e_rec, l_height_diff, '');
                    ELSE
                        pl_lm_goaltime.lmg_audit_movement('LE', pl_lm_goaltime.g_audit_batch_no, i_e_rec, abs(l_height_diff), '')
                        ;
                    END IF;

                    pl_lm_goaltime.lmg_audit_movement('APIDI', pl_lm_goaltime.g_audit_batch_no, i_e_rec, 1, '');
                    pl_lm_goaltime.lmg_audit_movement('MEPIDI', pl_lm_goaltime.g_audit_batch_no, i_e_rec, 1, '');
                    pl_lm_goaltime.lmg_audit_movement('BT90', pl_lm_goaltime.g_audit_batch_no, i_e_rec, 1, '');
                END IF;

                l_aisle_stack_height := l_pallets_in_aisle_stack * c_std_pallet_height;
                l_height_diff := i_slot_height - l_aisle_stack_height;
                IF ( l_height_diff > 0 ) THEN
                    o_drop := nvl(o_drop, 0) + ( ( l_height_diff / 12.0 ) * i_e_rec.ll );
                ELSE
                    o_drop := nvl(o_drop, 0) + ( ( abs(l_height_diff) / 12.0 ) * i_e_rec.rl );
                END IF;

                IF ( l_aisle_stack_height = 0 ) THEN
                    o_drop := nvl(o_drop, 0) + i_e_rec.ppof;
                ELSE
                    o_drop := nvl(o_drop, 0) + i_e_rec.apos + i_e_rec.ppos;
                END IF;

                o_drop := nvl(o_drop, 0) + i_e_rec.bt90;
                IF ( g_forklift_audit = c_true ) THEN
                    IF ( l_height_diff > 0 ) THEN
                        pl_lm_goaltime.lmg_audit_movement('LL', pl_lm_goaltime.g_audit_batch_no, i_e_rec, l_height_diff, '');
                    ELSE
                        pl_lm_goaltime.lmg_audit_movement('RL', pl_lm_goaltime.g_audit_batch_no, i_e_rec, abs(l_height_diff), '')
                        ;
                    END IF;

                    IF ( l_aisle_stack_height = 0 ) THEN
                        pl_lm_goaltime.lmg_audit_movement('PPOF', pl_lm_goaltime.g_audit_batch_no, i_e_rec, 1, '');
                    ELSE
                        pl_lm_goaltime.lmg_audit_movement('APOS', pl_lm_goaltime.g_audit_batch_no, i_e_rec, 1, '');
                        pl_lm_goaltime.lmg_audit_movement('PPOS', pl_lm_goaltime.g_audit_batch_no, i_e_rec, 1, '');
                    END IF;

                    pl_lm_goaltime.lmg_audit_movement('BT90', pl_lm_goaltime.g_audit_batch_no, i_e_rec, 1, '');
                END IF;

                l_pallet_count := l_pallet_count - 1;
                l_pallets_in_aisle_stack := l_pallets_in_aisle_stack + 1;
            END IF;
            END LOOP; /* END of l_pallet_count > 0 LOOP */

        END LOOP;

        io_current_fork_height := ( l_pallets_in_aisle_stack - 1 ) * c_std_pallet_height;
        RETURN 0;
    END lmgdi_rem_plts_from_res_slt;

/*****************************************************************************
**  FUNCTION:
**      lmgdi_remove_below_pallets()
**
**  DESCRIPTION:
**      This function removes the pallets to position one from below the
**      drive-in drop slot and stacks them in one stack in the aisle.
**
**  PARAMETERS:
**      i_e_rec                 - Pointer to equipment tmu values.
**      i_location              - The slot to remove the pallets below.
**      io_posx_pals            - Pallet list to position one
**      io_current_FORk_height  - Height of FORks.
**      o_drop                  - Outgoing drop value.
**
**  RETURN VALUES:
**      None.
*****************************************************************************/

    FUNCTION lmgdi_remove_below_pallets (
        i_e_rec                  IN                       pl_lm_goal_pb.type_lmc_equip_rec,
        i_location               IN                       VARCHAR2,
        io_posx_pals             IN OUT                   pl_lm_goal_pb.tbl_lmg_pallet_rec,
        io_num_recs              IN OUT                   NUMBER,
        io_current_fork_height   IN OUT                   NUMBER,
        o_drop                   OUT                      NUMBER
    ) RETURN NUMBER AS

        l_message                 VARCHAR2(1024);
        l_func_name               VARCHAR2(40) := 'lmgdi_remove_below_pallets';
        l_to_pos_x_stack_height   NUMBER := 0;
        l_pindex                  NUMBER := 0;
    BEGIN
        pl_text_log.ins_msg_async('INFO', l_func_name, 'Starting lmgdi_remove_below_pallets ...', sqlcode, sqlerrm);
        pl_text_log.ins_msg_async('INFO', l_func_name, 'i_location= '
                                            || i_location
                                            || 'io_num_recs= '
                                            || io_num_recs
                                            || ' io_current_FORk_height = '
                                            || io_current_fork_height, sqlcode, sqlerrm);

        l_to_pos_x_stack_height := io_current_fork_height;
        FOR i IN 0..io_num_recs LOOP
            o_drop := nvl(o_drop, 0) + i_e_rec.apidi;
			/*
			**  IF to-slot is higher than from-slot then raise to to-slot.
			**  ELSE lower to to-slot.
			*/
            IF ( io_posx_pals(i).height > l_to_pos_x_stack_height ) THEN
                o_drop := nvl(o_drop, 0) + ( ( ( io_posx_pals(i).height - l_to_pos_x_stack_height ) / 12.0 ) * i_e_rec.re );

            ELSE
                o_drop := nvl(o_drop, 0) + ( ( ( l_to_pos_x_stack_height - io_posx_pals(i).height ) / 12.0 ) * i_e_rec.le );
            END IF;

            o_drop := nvl(o_drop, 0) + i_e_rec.mepidi + i_e_rec.bt90;
            IF ( g_forklift_audit = c_true ) THEN
                IF ( i = 0 ) THEN
                    l_message := 'Remove all pallets below slot '
                                 || i_location
                                 || ' to position one.'
                                 || io_num_recs
                                 || ' pallet(s) to remove.';
                    pl_lm_goaltime.lmg_audit_cmt(pl_lm_goaltime.g_audit_batch_no, l_message, -1);
                END IF;

                l_message := 'Remove pallet from slot ' || io_posx_pals(i).loc;
                pl_lm_goaltime.lmg_audit_cmt(pl_lm_goaltime.g_audit_batch_no, l_message, -1);
                pl_lm_goaltime.lmg_audit_movement('APIDI', pl_lm_goaltime.g_audit_batch_no, i_e_rec, 1, '');
                IF ( io_posx_pals(i).height > l_to_pos_x_stack_height ) THEN
                    pl_lm_goaltime.lmg_audit_movement('RE', pl_lm_goaltime.g_audit_batch_no, i_e_rec, io_posx_pals(i).height - l_to_pos_x_stack_height
                    , '');
                ELSE
                    pl_lm_goaltime.lmg_audit_movement('LE', pl_lm_goaltime.g_audit_batch_no, i_e_rec, l_to_pos_x_stack_height - io_posx_pals
                    (i).height, '');
                END IF;

                pl_lm_goaltime.lmg_audit_movement('MEPIDI', pl_lm_goaltime.g_audit_batch_no, i_e_rec, 1, '');
                pl_lm_goaltime.lmg_audit_movement('BT90', pl_lm_goaltime.g_audit_batch_no, i_e_rec, 1, '');
            END IF;

            IF ( i != 0 ) THEN
                l_to_pos_x_stack_height := l_to_pos_x_stack_height + c_std_pallet_height;
            END IF;
			/*
			**  IF to-slot is higher than from-slot then raise to to-slot.
			**  ELSE lower to to-slot.
			*/
            IF ( l_to_pos_x_stack_height > io_posx_pals(i).height ) THEN
                o_drop := nvl(o_drop, 0) + ( ( ( l_to_pos_x_stack_height - io_posx_pals(i).height ) / 12.0 ) * i_e_rec.rl );
            ELSE
                o_drop := nvl(o_drop, 0) + ( ( ( io_posx_pals(i).height - l_to_pos_x_stack_height ) / 12.0 ) * i_e_rec.ll );
            END IF;

            IF ( i = 0 ) THEN
                o_drop := nvl(o_drop, 0) + i_e_rec.ppof;
            ELSE
                o_drop := nvl(o_drop, 0) + i_e_rec.ppos;
            END IF;

            o_drop := nvl(o_drop, 0) + i_e_rec.bt90;
            IF ( g_forklift_audit = c_true ) THEN
                IF ( l_to_pos_x_stack_height > io_posx_pals(i).height ) THEN
                    pl_lm_goaltime.lmg_audit_movement('RL', pl_lm_goaltime.g_audit_batch_no, i_e_rec, l_to_pos_x_stack_height - io_posx_pals
                    (i).height, '');
                ELSE
                    pl_lm_goaltime.lmg_audit_movement('LL', pl_lm_goaltime.g_audit_batch_no, i_e_rec, io_posx_pals(i).height - l_to_pos_x_stack_height
                    , '');
                END IF;

                IF ( i = 0 ) THEN
                    pl_lm_goaltime.lmg_audit_movement('PPOF', pl_lm_goaltime.g_audit_batch_no, i_e_rec, 1, '');
                ELSE
                    pl_lm_goaltime.lmg_audit_movement('PPOS', pl_lm_goaltime.g_audit_batch_no, i_e_rec, 1, '');
                END IF;

                pl_lm_goaltime.lmg_audit_movement('BT90', pl_lm_goaltime.g_audit_batch_no, i_e_rec, 1, '');
            END IF;

        END LOOP;

        io_current_fork_height := l_to_pos_x_stack_height;
        RETURN 1;
    END lmgdi_remove_below_pallets; 

/*****************************************************************************
**  FUNCTION:
**      lmgdi_putbk_plts_in_res_slt()
**
**  DESCRIPTION:
**      This function puts back the existing pallets removed from the
**      reserve slot.  After the pallets are putback the FORks will be
**      at the height of the slot.
**
**      05/10/01  This function could be modIFied FOR home slots IF needed.
**      Code exists FOR home slots but does not fit the current requirements.
**
**  PARAMETERS:
**      i_location               - Slot to put the pallets back into.
**      i_slot_height            - Slot height.
**      i_e_rec                  - Pointer to equipment tmu values.
**      i_num_pallets_to_putback - Number of pallets to put back into the slot.
**      i_home_slot_bln          - Indicates IF the slot is a home slot.
**                                 Always FALSE.
**      i_current_FORk_height    - Current height of FORks.
**      o_drop                   - Outgoing drop value.
**
**  RETURN VALUES:
**      None.
*****************************************************************************/

    PROCEDURE lmgdi_putbk_plts_in_res_slt (
        i_e_rec                    IN                         pl_lm_goal_pb.type_lmc_equip_rec,
        i_location                 IN                         VARCHAR2,
        i_slot_height              IN                         NUMBER,
        i_num_pallets_to_putback   IN                         NUMBER,
        i_home_slot_bln            IN                         NUMBER,
        i_current_fork_height      IN                         NUMBER,
        o_drop                     OUT                        NUMBER
    ) AS

        l_func_name                VARCHAR2(40) := 'lmgdi_putbk_plts_in_res_slt';
        l_aisle_stack_height       NUMBER := 0;
        l_first_putback_bln        NUMBER;
        l_height_diff              NUMBER;
        l_pallet_count             NUMBER;
        l_pallets_in_aisle_stack   NUMBER;
        l_message                  VARCHAR2(1024);
        i_home_slot_bln_tmp        VARCHAR2(10);
        l_pindex                   NUMBER := 1;
    BEGIN
        IF i_home_slot_bln = c_true THEN
            i_home_slot_bln_tmp := 'True';
        ELSE
            i_home_slot_bln_tmp := 'False';
        END IF;

        pl_text_log.ins_msg_async('INFO', l_func_name, 'i_location= '
                                            || i_location
                                            || ' i_slot_height = '
                                            || i_slot_height
                                            || 'i_num_pallets_to_putback= '
                                            || i_num_pallets_to_putback
                                            || 'i_home_slot_bln= '
                                            || i_home_slot_bln_tmp
                                            || 'i_current_FORk_height= '
                                            || i_current_fork_height, sqlcode, sqlerrm);

        IF ( g_forklift_audit = c_true AND i_num_pallets_to_putback > 0 ) THEN
            l_message := 'Put the existing inventory back into slot '
                         || i_location
                         || '. '
                         || i_num_pallets_to_putback
                         || ' pallet(s) to put back.';
            pl_lm_goaltime.lmg_audit_cmt(pl_lm_goaltime.g_audit_batch_no, l_message, -1);
        END IF;

        l_first_putback_bln := c_true;
		/*
		**  FOR home slots put back the pallets that are behind the pick pallet.
		**  The pick pallet will be moved last.  The pallet will always be by
		**  itself in the aisle.
		*/
        IF ( i_home_slot_bln != 0 ) THEN
            l_pallet_count := i_num_pallets_to_putback - 1;
        ELSE
            l_pallet_count := i_num_pallets_to_putback;
        END IF;

        WHILE ( l_pallet_count > 0 ) LOOP
			/*
			**  Determine the number of pallets in the aisle stack.  The maximum
			**  number of pallets in an aisle stack is MAX_PALS_PER_STACK_DI.
			*/
            l_pallets_in_aisle_stack := MOD(l_pallet_count, c_max_pals_per_stack_di);
            IF ( l_pallets_in_aisle_stack = 0 ) THEN
                l_pallets_in_aisle_stack := c_max_pals_per_stack_di;
            END IF;
            l_aisle_stack_height := ( l_pallets_in_aisle_stack - 1 ) * c_std_pallet_height;
			/*
			**  Take the pallets in the aisle stack and place in the slot.
			*/
            FOR i IN REVERSE 0..l_pallets_in_aisle_stack LOOP
                IF ( g_forklift_audit = c_true ) THEN
                    IF ( i = l_pallets_in_aisle_stack ) THEN
                        l_message := 'Put pallets in aisle stack back into the slot '
                                     || l_pallets_in_aisle_stack
                                     || ' pallet(s) in the aisle stack.';
                        pl_lm_goaltime.lmg_audit_cmt(pl_lm_goaltime.g_audit_batch_no, l_message, -1);
                    END IF;

                    l_message := 'Pickup pallet from aisle stack and put in slot';
                    pl_lm_goaltime.lmg_audit_cmt(pl_lm_goaltime.g_audit_batch_no, l_message, -1);
                END IF;
				/*
				**  Move the FORks to the height IF the pallet in the aisle stack.
				*/

                IF ( l_first_putback_bln != 0 ) THEN
					/*
					**  This is the first putback.  Move the FORks from their
					**  current position to the level of the putback pallet.
					*/
                    l_first_putback_bln := c_false;
                    l_height_diff := i_current_fork_height - l_aisle_stack_height;
                ELSE 
					/*
					**  Move the FORks from the level of the pallet just put in
					**  the slot to the level of the next pallet in the aisle stack.
					*/
                    l_height_diff := i_slot_height - l_aisle_stack_height;
                END IF;

                IF ( l_height_diff > 0 ) THEN
                    o_drop := nvl(o_drop, 0) + ( ( abs(l_height_diff) / 12.0 ) * i_e_rec.le );
                ELSE
                    o_drop := nvl(o_drop, 0) + ( ( abs(l_height_diff) / 12.0 ) * i_e_rec.re );
                END IF;

                IF ( g_forklift_audit = c_true ) THEN
                    IF ( l_height_diff > 0 ) THEN
                        pl_lm_goaltime.lmg_audit_movement('LE', pl_lm_goaltime.g_audit_batch_no, i_e_rec, abs(l_height_diff), '')
                        ;

                    ELSE
                        pl_lm_goaltime.lmg_audit_movement('RE', pl_lm_goaltime.g_audit_batch_no, i_e_rec, abs(l_height_diff), '')
                        ;
                    END IF;
                END IF;
				/*
				**  Pickup the pallet in the aisle stack and put in the slot.
				*/

                IF ( l_aisle_stack_height = 0 ) THEN
                    o_drop := nvl(o_drop, 0) + i_e_rec.apof + i_e_rec.mepof;
                ELSE
                    o_drop := nvl(o_drop, 0) + i_e_rec.apos + i_e_rec.mepos;
                END IF;

                o_drop := nvl(o_drop, 0) + i_e_rec.bt90 + i_e_rec.apidi;
                l_height_diff := l_aisle_stack_height - i_slot_height;
                IF ( l_height_diff > 0 ) THEN
                    o_drop := nvl(o_drop, 0) + ( ( l_height_diff / 12.0 ) * i_e_rec.ll );
                ELSE
                    o_drop := nvl(o_drop, 0) + ( ( abs(l_height_diff) / 12.0 ) * i_e_rec.rl );
                END IF;

                o_drop := nvl(o_drop, 0) + i_e_rec.ppidi + i_e_rec.bt90;
                IF ( g_forklift_audit = c_true ) THEN
                    IF ( l_aisle_stack_height = 0 ) THEN
                        pl_lm_goaltime.lmg_audit_movement('APOF', pl_lm_goaltime.g_audit_batch_no, i_e_rec, 1, '');
                        pl_lm_goaltime.lmg_audit_movement('MEPOF', pl_lm_goaltime.g_audit_batch_no, i_e_rec, 1, '');
                    ELSE
                        pl_lm_goaltime.lmg_audit_movement('APOS', pl_lm_goaltime.g_audit_batch_no, i_e_rec, 1, '');
                        pl_lm_goaltime.lmg_audit_movement('MEPOS', pl_lm_goaltime.g_audit_batch_no, i_e_rec, 1, '');
                    END IF;

                    pl_lm_goaltime.lmg_audit_movement('BT90', pl_lm_goaltime.g_audit_batch_no, i_e_rec, 1, '');
                    pl_lm_goaltime.lmg_audit_movement('APIDI', pl_lm_goaltime.g_audit_batch_no, i_e_rec, 1, '');
                    IF ( l_height_diff > 0 ) THEN
                        pl_lm_goaltime.lmg_audit_movement('LL', pl_lm_goaltime.g_audit_batch_no, i_e_rec, l_height_diff, '');
                    ELSE
                        pl_lm_goaltime.lmg_audit_movement('RL', pl_lm_goaltime.g_audit_batch_no, i_e_rec, abs(l_height_diff), '')
                        ;
                    END IF;

                    pl_lm_goaltime.lmg_audit_movement('PPIDI', pl_lm_goaltime.g_audit_batch_no, i_e_rec, 1, '');
                    pl_lm_goaltime.lmg_audit_movement('BT90', pl_lm_goaltime.g_audit_batch_no, i_e_rec, 1, '');
                END IF;

                l_aisle_stack_height := l_aisle_stack_height - c_std_pallet_height;
                l_pallet_count := l_pallet_count - 1;
            END LOOP;/* END putback pallets in aisle stack FOR loop */

        END LOOP; /* END putback pallets WHILE loop */
		/*
		**  IF a home slot then put back the pick pallet.  The pick pallet will
		**  always be on the floor in the aisle.
		*/

        IF ( i_home_slot_bln != 0 ) THEN
            IF ( l_first_putback_bln != 0 ) THEN
				/*
				**  The only pallet to putback is the pick pallet.
				*/
                o_drop := nvl(o_drop, 0) + ( ( i_current_fork_height / 12.0 ) * i_e_rec.le );

                IF ( g_forklift_audit = c_true ) THEN
                    pl_lm_goaltime.lmg_audit_movement('LE', pl_lm_goaltime.g_audit_batch_no, i_e_rec, i_current_fork_height, '');
                END IF;

            ELSE 
				/*
				**  Other pallets put back in slot. Now put back the pick pallet.
				*/
                o_drop := nvl(o_drop, 0) + ( ( i_slot_height / 12.0 ) * i_e_rec.le );

                IF ( g_forklift_audit = c_true ) THEN
                    pl_lm_goaltime.lmg_audit_movement('LE', pl_lm_goaltime.g_audit_batch_no, i_e_rec, i_slot_height, '');
                END IF;

            END IF;

            o_drop := nvl(o_drop, 0) + i_e_rec.apof + i_e_rec.mepof + i_e_rec.bt90 + i_e_rec.apidi + ( ( i_slot_height / 12.0 ) *

            i_e_rec.rl ) + i_e_rec.ppidi + i_e_rec.bt90;

            IF ( g_forklift_audit = c_true ) THEN
                pl_lm_goaltime.lmg_audit_movement('APOF', pl_lm_goaltime.g_audit_batch_no, i_e_rec, 1, 'Put pick pallet back into the slot.'
                );
                pl_lm_goaltime.lmg_audit_movement('MEPOF', pl_lm_goaltime.g_audit_batch_no, i_e_rec, 1, '');
                pl_lm_goaltime.lmg_audit_movement('BT90', pl_lm_goaltime.g_audit_batch_no, i_e_rec, 1, '');
                pl_lm_goaltime.lmg_audit_movement('APIDI', pl_lm_goaltime.g_audit_batch_no, i_e_rec, 1, '');
                pl_lm_goaltime.lmg_audit_movement('RL', pl_lm_goaltime.g_audit_batch_no, i_e_rec, i_slot_height, '');
                pl_lm_goaltime.lmg_audit_movement('PPIDI', pl_lm_goaltime.g_audit_batch_no, i_e_rec, 1, '');
                pl_lm_goaltime.lmg_audit_movement('BT90', pl_lm_goaltime.g_audit_batch_no, i_e_rec, 1, '');
            END IF;

        END IF;

    END lmgdi_putbk_plts_in_res_slt;

/*****************************************************************************
**  FUNCTION:
**      lmgdi_putback_below_pallets()
**
**  DESCRIPTION:
**      This function puts back the pallets removed below the slot.
**      The pallets are in one big stack in the aisle.
**      After the pallets are put back the FORks are lowered to the floor.
**
**  PARAMETERS:
**      i_e_rec                 - Pointer to equipment tmu values.
**      i_location              - Putback pallets below this slot.
**      i_current_FORk_height   - Current height of FORks.
**      o_posx_pals             - Pallet list to position one of pallets below
**                                i_location.  This is the list of pallets
**                                below i_location that were removed.
**      o_drop                  - Outgoing drop value.
**
**  RETURN VALUES:
**      None.
*****************************************************************************/

    PROCEDURE lmgdi_putback_below_pallets (
        i_e_rec                 IN                      pl_lm_goal_pb.type_lmc_equip_rec,
        i_location              IN                      VARCHAR2,
        i_current_fork_height   IN                      NUMBER,
        i_posx_pals             IN                      pl_lm_goal_pb.tbl_lmg_pallet_rec,
        i_num_recs              IN                      NUMBER,
        o_drop                  OUT                     NUMBER
    ) AS

        l_func_name               VARCHAR2(40) := 'lmgdi_putback_below_pallets';
        l_slot_height             NUMBER;
        l_to_pos_x_stack_height   NUMBER := 0;
        l_message                 VARCHAR2(1024);
        l_pindex                  NUMBER := 1;
    BEGIN
		/*
		** IF there are pallets to put back then set the stack height and move
		** the FORks to the top pallet in the stack.
		*/
        pl_text_log.ins_msg_async('INFO', l_func_name, 'Starting lmgdi_putback_below_pallets...', sqlcode, sqlerrm);
        pl_text_log.ins_msg_async('INFO', l_func_name, ' i_num_recs= ' || i_num_recs, sqlcode, sqlerrm);
        IF ( i_num_recs > 0 ) THEN
            l_to_pos_x_stack_height := ( i_num_recs - 1 ) * c_std_pallet_height;
            IF ( l_to_pos_x_stack_height > i_current_fork_height ) THEN
                o_drop := nvl(o_drop, 0) + ( ( ( l_to_pos_x_stack_height - i_current_fork_height ) / 12.0 ) * i_e_rec.re );

            ELSE
                o_drop := nvl(o_drop, 0) + ( ( ( i_current_fork_height - l_to_pos_x_stack_height ) / 12.0 ) * i_e_rec.le );
            END IF;

            IF ( g_forklift_audit = c_true ) THEN
                l_message := 'Put back the pallets removed below slot '
                             || i_location
                             || '. '
                             || i_num_recs
                             || ' pallet(s) to put back.';
                pl_lm_goaltime.lmg_audit_cmt(pl_lm_goaltime.g_audit_batch_no, l_message, -1);
                IF ( l_to_pos_x_stack_height > l_slot_height ) THEN
                    pl_lm_goaltime.lmg_audit_movement('RE', pl_lm_goaltime.g_audit_batch_no, i_e_rec, l_to_pos_x_stack_height - i_current_fork_height
                    , '');
                ELSE
                    pl_lm_goaltime.lmg_audit_movement('LE', pl_lm_goaltime.g_audit_batch_no, i_e_rec, i_current_fork_height - l_to_pos_x_stack_height
                    , '');
                END IF;

            END IF;

        END IF;

        FOR i IN REVERSE 1..i_num_recs LOOP
			/*
			** IF this is not the first pallet being processed then move the FORks
			** to the height of the top pallet in the stack.  The FORks are at the
			** slot height.
			*/
            IF ( i != ( i_num_recs - 1 ) ) THEN
                IF ( l_to_pos_x_stack_height > l_slot_height ) THEN
                    o_drop := nvl(o_drop, 0) + ( ( ( l_to_pos_x_stack_height - l_slot_height ) / 12.0 ) * i_e_rec.re );
                ELSE
                    o_drop := nvl(o_drop, 0) + ( ( ( l_slot_height - l_to_pos_x_stack_height ) / 12.0 ) * i_e_rec.le );
                END IF;

                IF ( g_forklift_audit = c_true ) THEN
                    IF ( l_to_pos_x_stack_height > l_slot_height ) THEN
                        pl_lm_goaltime.lmg_audit_movement('RE', pl_lm_goaltime.g_audit_batch_no, i_e_rec, l_to_pos_x_stack_height
                        - l_slot_height, '');

                    ELSE
                        pl_lm_goaltime.lmg_audit_movement('LE', pl_lm_goaltime.g_audit_batch_no, i_e_rec, l_slot_height - l_to_pos_x_stack_height
                        , '');
                    END IF;

                END IF;

            END IF;

            l_slot_height := i_posx_pals(l_pindex).height;
            IF ( l_to_pos_x_stack_height = 0 ) THEN
                o_drop := nvl(o_drop, 0) + i_e_rec.apof + i_e_rec.mepof;
            ELSE
                o_drop := nvl(o_drop, 0) + i_e_rec.apos + i_e_rec.mepos;
            END IF;

            o_drop := nvl(o_drop, 0) + i_e_rec.bt90 + i_e_rec.apidi;
			/*
			**  IF to-slot is higher than from-slot then raise to to-slot.
			**  ELSE lower to to-slot.
			*/
            IF ( l_slot_height > l_to_pos_x_stack_height ) THEN
                o_drop := nvl(o_drop, 0) + ( ( ( l_slot_height - l_to_pos_x_stack_height ) / 12.0 ) * i_e_rec.rl );
            ELSE
                o_drop := nvl(o_drop, 0) + ( ( ( l_to_pos_x_stack_height - l_slot_height ) / 12.0 ) * i_e_rec.ll );
            END IF;

            o_drop := nvl(o_drop, 0) + i_e_rec.ppidi + i_e_rec.bt90;
            IF ( g_forklift_audit = c_true ) THEN
                l_message := 'Put pallet back in slot ' || i_posx_pals(i).loc;
                IF ( l_to_pos_x_stack_height = 0 ) THEN
                    pl_lm_goaltime.lmg_audit_movement('APOF', pl_lm_goaltime.g_audit_batch_no, i_e_rec, 1, l_message);
                    pl_lm_goaltime.lmg_audit_movement('MEPOF', pl_lm_goaltime.g_audit_batch_no, i_e_rec, 1, '');
                ELSE
                    pl_lm_goaltime.lmg_audit_movement('APOS', pl_lm_goaltime.g_audit_batch_no, i_e_rec, 1, l_message);
                    pl_lm_goaltime.lmg_audit_movement('MEPOS', pl_lm_goaltime.g_audit_batch_no, i_e_rec, 1, '');
                END IF;

                pl_lm_goaltime.lmg_audit_movement('BT90', pl_lm_goaltime.g_audit_batch_no, i_e_rec, 1, '');
                pl_lm_goaltime.lmg_audit_movement('APIDI', pl_lm_goaltime.g_audit_batch_no, i_e_rec, 1, '');
                IF ( l_slot_height > l_to_pos_x_stack_height ) THEN
                    pl_lm_goaltime.lmg_audit_movement('RL', pl_lm_goaltime.g_audit_batch_no, i_e_rec, l_slot_height - l_to_pos_x_stack_height
                    , '');
                ELSE
                    pl_lm_goaltime.lmg_audit_movement('LL', pl_lm_goaltime.g_audit_batch_no, i_e_rec, l_to_pos_x_stack_height - l_slot_height
                    , '');
                END IF;

                pl_lm_goaltime.lmg_audit_movement('PPIDI', pl_lm_goaltime.g_audit_batch_no, i_e_rec, 1, '');
                pl_lm_goaltime.lmg_audit_movement('BT90', pl_lm_goaltime.g_audit_batch_no, i_e_rec, 1, '');
            END IF;

        END LOOP;/* END FOR loop */
		/*
		** Lower the FORks to the floor.
		*/

        IF ( i_num_recs > 0 ) THEN
            o_drop := nvl(o_drop, 0) + ( ( l_slot_height / 12.0 ) * i_e_rec.le );

            IF ( g_forklift_audit = c_true ) THEN
                pl_lm_goaltime.lmg_audit_movement('LE', pl_lm_goaltime.g_audit_batch_no, i_e_rec, l_slot_height, 'Lower FORks to the floor.'
                );
            END IF;

        END IF;

    END lmgdi_putback_below_pallets;

/*****************************************************************************
**  FUNCTION:
**      lmgdi_pickup_from_drivein_res()
**
**  DESCRIPTION:
**      This function calculates the LM drop discreet value FOR a pallet
**      picked from a reserve drive-in location.
**      FOR dIFferent item in slot, assume that the needed pallet is last.
**
**  PARAMETERS:
**      i_pals         - Pointer to pallet list.
**      i_pindex       - Index of pallet being processed.
**      i_e_rec        - Pointer to equipment tmu values.
**      i_inv          - Pointer to pallets already in the destination.
**      i_is_dIFf_item - Flag denoting IF the dIFferent item is in the
**                       destination location.
**      o_pickup       - Outgoing pickup value.
**
**  RETURN VALUES:
**      None.
*****************************************************************************/

    FUNCTION lmgdi_pickup_from_drivein_res (
        i_pals           IN               pl_lm_goal_pb.tbl_lmg_pallet_rec,
        i_pindex         IN               NUMBER,
        i_e_rec          IN               pl_lm_goal_pb.type_lmc_equip_rec,
        i_inv            IN               pl_lm_goal_pb.tbl_lmg_inv_rec,
        i_is_diff_item   IN               VARCHAR2,
        i_num_recs       IN               NUMBER,
        o_pickup         OUT              NUMBER
    ) RETURN NUMBER AS

        l_func_name             VARCHAR2(40) := 'lmgdi_pickup_from_drivein_res';
        l_ret_val               NUMBER := c_swms_normal;
        l_message               VARCHAR2(1024);
        l_slot_height           NUMBER := 0;
        l_start_height          NUMBER := 0;
        l_pos_x_stack_height    NUMBER := 0;
        l_res_stack_height      NUMBER := 0;
        l_num_positions         NUMBER := 0;
        l_num_pallets_below     NUMBER := 0;
        l_num_pallets_in_slot   NUMBER := 0;
        l_home_qty              NUMBER := 0;
        l_posx_pals             pl_lm_goal_pb.tbl_lmg_pallet_rec;
        l_num_recs              NUMBER;
    BEGIN
        pl_text_log.ins_msg_async('INFO', l_func_name, 'batch_no= '
                                            || i_pals(i_pindex).batch_no
                                            || 'i_pindex= '
                                            || i_pindex
                                            || 'equip_id= '
                                            || i_e_rec.equip_id
                                            || 'i_is_dIFf_item= '
                                            || i_is_diff_item, sqlcode, sqlerrm);

        IF ( g_forklift_audit = c_true ) THEN
            l_message := 'Pickup pallet '
                         || i_pals(i_pindex).pallet_id
                         || ' from '
                         || i_pals(i_pindex).slot_type
                         || ' , '
                         || i_pals(i_pindex).pallet_type
                         || ' drive-in reserve slot.'
                         || i_pals(i_pindex).loc;

            pl_lm_goaltime.lmg_audit_cmt(pl_lm_goaltime.g_audit_batch_no, l_message, -1);
        END IF;
        /*slot type is in 10th position in the argument passing from Input. Here l_slot_type_num_positions defined as 10 instead of slot type*/

        l_num_positions := 10; /*i_pals(i_pindex).slot_type;*/
        l_num_pallets_in_slot := i_num_recs;
        IF ( i_pals(i_pindex).multi_pallet_drop_to_slot = 'N' ) THEN
--            pl_lm_goaltime.lmg_clear_pallet_struct(l_posx_pals);
            FOR i IN 1..i_num_recs LOOP l_home_qty := l_home_qty + i_pals(i).qty_on_pallet;
            END LOOP;

            IF ( i_is_diff_item = 'Y' ) THEN
--                pl_lm_goaltime.lmg_clear_pallet_struct(l_posx_pals);
                l_ret_val := lmgdi_get_pals_below_to_posx(i_pals(i_pindex).loc, i_pals(i_pindex).dest_loc, l_home_qty, 1, l_posx_pals
                , l_num_recs);

            ELSIF ( l_num_positions > ( l_num_pallets_in_slot + 1 ) ) THEN
--                pl_lm_goaltime.lmg_clear_pallet_struct(l_posx_pals);
                l_ret_val := lmgdi_get_pals_below_to_posx(i_pals(i_pindex).loc, i_pals(i_pindex).dest_loc, l_home_qty, l_num_pallets_in_slot
                , l_posx_pals, l_num_recs);
            END IF;

            IF ( l_ret_val <> c_swms_normal) THEN
                RETURN l_ret_val;
            ELSE
                l_num_pallets_below := l_num_recs;
            END IF;

        END IF;

        IF ( i_pindex = 0 ) THEN
            o_pickup := nvl(o_pickup, 0) + i_e_rec.tidi;
            IF ( g_forklift_audit = c_true ) THEN
                pl_lm_goaltime.lmg_audit_movement('TIDI', pl_lm_goaltime.g_audit_batch_no, i_e_rec, 1, '');
            END IF;

        ELSE
            o_pickup := nvl(o_pickup, 0) + i_e_rec.bt90;
            IF ( g_forklift_audit = c_true ) THEN
                pl_lm_goaltime.lmg_audit_movement('BT90', pl_lm_goaltime.g_audit_batch_no, i_e_rec, 1, '');
            END IF;

        END IF;
		/*
		**  IF the previous pallet picked up (IF there was one) was not from 
		**  the same slot then the pallets below the required pallet need to
		**  be removed (they will be put in a stack) in order to get to the pallet.
		**  IF there was a previous pallet picked up from the same slot then
		**  the pallets below the required pallet have already been removed.
		*/

        IF ( i_pals(i_pindex).multi_pallet_drop_to_slot = 'N' ) THEN
            IF ( l_num_pallets_below > 0 ) THEN
				/*
				**  Remove the pallets from the slots below to X position.
				*/
                FOR i IN 1..l_num_pallets_below LOOP
                    l_slot_height := l_posx_pals(i).height;
                    o_pickup := nvl(o_pickup, 0) + i_e_rec.apidi;
                    IF ( l_slot_height > l_pos_x_stack_height ) THEN
                        o_pickup := nvl(o_pickup, 0) + ( ( ( l_slot_height - l_pos_x_stack_height ) / 12.0 ) * i_e_rec.re );
                    ELSE
                        o_pickup := nvl(o_pickup, 0) + ( ( ( l_pos_x_stack_height - l_slot_height ) / 12.0 ) * i_e_rec.le );
                    END IF;

                    o_pickup := nvl(o_pickup, 0) + i_e_rec.mepidi + i_e_rec.bt90;
                    IF ( g_forklift_audit = c_true ) THEN
                        IF ( i = 0 ) THEN
                            l_message := 'Remove the pallets from the slots below and put in a stack. '
                                         || l_num_pallets_below
                                         || ' pallet(s) to remove.';
                            pl_lm_goaltime.lmg_audit_cmt(pl_lm_goaltime.g_audit_batch_no, l_message, -1);
                        END IF;

                        pl_lm_goaltime.lmg_audit_movement('APIDI', pl_lm_goaltime.g_audit_batch_no, i_e_rec, 1, 'Remove pallet.'

                        );
                        IF ( l_slot_height > l_pos_x_stack_height ) THEN
                            pl_lm_goaltime.lmg_audit_movement('RE', pl_lm_goaltime.g_audit_batch_no, i_e_rec, l_slot_height - l_pos_x_stack_height
                            , '');
                        ELSE
                            pl_lm_goaltime.lmg_audit_movement('LE', pl_lm_goaltime.g_audit_batch_no, i_e_rec, l_pos_x_stack_height
                            - l_slot_height, '');
                        END IF;

                        pl_lm_goaltime.lmg_audit_movement('MEPIDI', pl_lm_goaltime.g_audit_batch_no, i_e_rec, 1, '');
                        pl_lm_goaltime.lmg_audit_movement('BT90', pl_lm_goaltime.g_audit_batch_no, i_e_rec, 1, '');
                    END IF;/* END audit */

                    IF ( i > 0 ) THEN
                        l_pos_x_stack_height := l_pos_x_stack_height + c_std_pallet_height;
                    END IF;
                    IF ( l_pos_x_stack_height > l_slot_height ) THEN
                        o_pickup := nvl(o_pickup, 0) + ( ( ( l_pos_x_stack_height - l_slot_height ) / 12.0 ) * i_e_rec.rl );
                    ELSE
                        o_pickup := nvl(o_pickup, 0) + ( ( ( l_slot_height - l_pos_x_stack_height ) / 12.0 ) * i_e_rec.ll );
                    END IF;

                    IF ( l_pos_x_stack_height = 0 ) THEN
                        o_pickup := nvl(o_pickup, 0) + i_e_rec.ppof;
                    ELSE
                        o_pickup := nvl(o_pickup, 0) + i_e_rec.ppos;
                    END IF;

                    o_pickup := nvl(o_pickup, 0) + i_e_rec.bt90;
                    IF ( g_forklift_audit = c_true ) THEN
                        IF ( l_pos_x_stack_height > l_slot_height ) THEN
                            pl_lm_goaltime.lmg_audit_movement('RL', pl_lm_goaltime.g_audit_batch_no, i_e_rec, l_pos_x_stack_height
                            - l_slot_height, '');
                        ELSE
                            pl_lm_goaltime.lmg_audit_movement('LL', pl_lm_goaltime.g_audit_batch_no, i_e_rec, l_slot_height - l_pos_x_stack_height
                            , '');
                        END IF;

                        IF ( l_pos_x_stack_height = 0 ) THEN
                            pl_lm_goaltime.lmg_audit_movement('PPOF', pl_lm_goaltime.g_audit_batch_no, i_e_rec, 1, '');
                        ELSE
                            pl_lm_goaltime.lmg_audit_movement('PPOS', pl_lm_goaltime.g_audit_batch_no, i_e_rec, 1, '');
                        END IF;

                        pl_lm_goaltime.lmg_audit_movement('BT90', pl_lm_goaltime.g_audit_batch_no, i_e_rec, 1, '');
                    END IF;/* END audit */

                END LOOP; /* END of l_num_pallets_below LOOP */
            END IF;

            l_res_stack_height := l_pos_x_stack_height;
            IF ( i_is_diff_item = 'Y' ) THEN
				/*
				**  There are dIFferent items in the reserve slot.
				*/
                l_slot_height := i_pals(i_pindex).height;
				/*
				**  Pull the not needed pallets from the reserve slot because
				**  the location of the needed pallet is not known.  Assume the
				**  needed pallet will be the last pallet in the slot.
				*/
                FOR i IN 0..i_num_recs LOOP
                    o_pickup := nvl(o_pickup, 0) + i_e_rec.apidi;
                    IF ( l_slot_height > l_res_stack_height ) THEN
                        o_pickup := nvl(o_pickup, 0) + ( ( ( l_slot_height - l_res_stack_height ) / 12.0 ) * i_e_rec.re );

                    ELSE
                        o_pickup := nvl(o_pickup, 0) + ( ( ( l_res_stack_height - l_slot_height ) / 12.0 ) * i_e_rec.le );
                    END IF;

                    o_pickup := nvl(o_pickup, 0) + i_e_rec.mepidi + i_e_rec.bt90;
                    IF ( g_forklift_audit = c_true ) THEN
                        IF ( i = 0 ) THEN
                            l_message := 'There are dIFferent items in the reserve slot.  Assume the required pallet is in the back of the slot'
                            ;
                            pl_lm_goaltime.lmg_audit_cmt(pl_lm_goaltime.g_audit_batch_no, l_message, -1);
                            l_message := 'Remove '
                                         || i_num_recs
                                         || ' pallets from the reserve slot.';
                            pl_lm_goaltime.lmg_audit_cmt(pl_lm_goaltime.g_audit_batch_no, l_message, -1);
                        END IF;

                        pl_lm_goaltime.lmg_audit_movement('APIDI', pl_lm_goaltime.g_audit_batch_no, i_e_rec, 1, '');
                        IF ( l_slot_height > l_res_stack_height ) THEN
                            pl_lm_goaltime.lmg_audit_movement('RE', pl_lm_goaltime.g_audit_batch_no, i_e_rec, l_slot_height - l_res_stack_height
                            , '');
                        ELSE
                            pl_lm_goaltime.lmg_audit_movement('LE', pl_lm_goaltime.g_audit_batch_no, i_e_rec, l_res_stack_height -
                            l_slot_height, '');
                        END IF;

                        pl_lm_goaltime.lmg_audit_movement('MEPIDI', pl_lm_goaltime.g_audit_batch_no, i_e_rec, 1, '');
                        pl_lm_goaltime.lmg_audit_movement('BT90', pl_lm_goaltime.g_audit_batch_no, i_e_rec, 1, '');
                    END IF;/* END audit */

                    IF ( i > 0 ) THEN
                        l_res_stack_height := l_res_stack_height + c_std_pallet_height;
                    ELSE
                        l_res_stack_height := 0;
                    END IF;

                    IF ( l_res_stack_height > l_slot_height ) THEN
                        o_pickup := nvl(o_pickup, 0) + ( ( ( l_res_stack_height - l_slot_height ) / 12.0 ) * i_e_rec.rl );
                    ELSE
                        o_pickup := nvl(o_pickup, 0) + ( ( ( l_slot_height - l_res_stack_height ) / 12.0 ) * i_e_rec.ll );
                    END IF;

                    IF ( l_res_stack_height > 0 ) THEN
                        o_pickup := nvl(o_pickup, 0) + i_e_rec.ppos;
                    ELSE
                        o_pickup := nvl(o_pickup, 0) + i_e_rec.ppof;
                    END IF;

                    o_pickup := nvl(o_pickup, 0) + i_e_rec.bt90;
                    IF ( g_forklift_audit = c_true ) THEN
                        IF ( l_res_stack_height > l_slot_height ) THEN
                            pl_lm_goaltime.lmg_audit_movement('RL', pl_lm_goaltime.g_audit_batch_no, i_e_rec, l_res_stack_height -
                            l_slot_height, '');
                        ELSE
                            pl_lm_goaltime.lmg_audit_movement('LL', pl_lm_goaltime.g_audit_batch_no, i_e_rec, l_slot_height - l_res_stack_height
                            , '');
                        END IF;

                        IF ( l_res_stack_height > 0 ) THEN
                            pl_lm_goaltime.lmg_audit_movement('PPOS', pl_lm_goaltime.g_audit_batch_no, i_e_rec, 1, '');
                        ELSE
                            pl_lm_goaltime.lmg_audit_movement('PPOF', pl_lm_goaltime.g_audit_batch_no, i_e_rec, 1, '');
                        END IF;

                        pl_lm_goaltime.lmg_audit_movement('BT90', pl_lm_goaltime.g_audit_batch_no, i_e_rec, 1, '');
                    END IF;/* END audit */

                END LOOP;

            END IF;

        END IF;
		/*
		**  Get needed pallet from rack.
		*/

        l_slot_height := i_pals(i_pindex).height;
        IF ( i_pals(i_pindex).multi_pallet_drop_to_slot = 'Y' ) THEN
            l_start_height := c_std_pallet_height * ( i_pindex - 1 );
        ELSE
            l_start_height := l_res_stack_height;
        END IF;

        o_pickup := nvl(o_pickup, 0) + i_e_rec.apidi;
        IF ( l_slot_height > l_start_height ) THEN
            o_pickup := nvl(o_pickup, 0) + ( ( ( l_slot_height - l_start_height ) / 12.0 ) * i_e_rec.re );
        ELSE
            o_pickup := nvl(o_pickup, 0) + ( ( ( l_start_height - l_slot_height ) / 12.0 ) * i_e_rec.le );
        END IF;

        o_pickup := nvl(o_pickup, 0) + i_e_rec.mepidi + i_e_rec.bt90;
        IF ( ( c_std_pallet_height * i_pindex ) > l_slot_height ) THEN
            o_pickup := nvl(o_pickup, 0) + ( ( ( ( c_std_pallet_height * i_pindex ) - l_slot_height ) / 12.0 ) * i_e_rec.rl );
        ELSE
            o_pickup := nvl(o_pickup, 0) + ( ( ( l_slot_height - ( c_std_pallet_height * i_pindex ) ) / 12.0 ) * i_e_rec.ll );
        END IF;

        IF ( g_forklift_audit = c_true ) THEN
            l_message := 'Remove pallet '
                         || i_pals(i_pindex).pallet_id
                         || ' from slot '
                         || i_pals(i_pindex).loc;

            pl_lm_goaltime.lmg_audit_movement('APIDI', pl_lm_goaltime.g_audit_batch_no, i_e_rec, 1, l_message);
            IF ( l_slot_height > l_start_height ) THEN
                pl_lm_goaltime.lmg_audit_movement('RE', pl_lm_goaltime.g_audit_batch_no, i_e_rec, l_slot_height - l_start_height,
                '');
            ELSE
                pl_lm_goaltime.lmg_audit_movement('LE', pl_lm_goaltime.g_audit_batch_no, i_e_rec, l_start_height - l_slot_height,
                '');
            END IF;

            pl_lm_goaltime.lmg_audit_movement('MEPIDI', pl_lm_goaltime.g_audit_batch_no, i_e_rec, 1, '');
            pl_lm_goaltime.lmg_audit_movement('BT90', pl_lm_goaltime.g_audit_batch_no, i_e_rec, 1, '');
            IF ( ( c_std_pallet_height * i_pindex ) > l_slot_height ) THEN
                pl_lm_goaltime.lmg_audit_movement('RL', pl_lm_goaltime.g_audit_batch_no, i_e_rec,(c_std_pallet_height * i_pindex)
                - l_slot_height, '');
            ELSE
                pl_lm_goaltime.lmg_audit_movement('LL', pl_lm_goaltime.g_audit_batch_no, i_e_rec, l_slot_height -(c_std_pallet_height
                * i_pindex), '');
            END IF;

        END IF;/* END audit */
		/*
		**  Put pallet down IF there are more pallets being pulled
		**  or IF there are pallets to put back.
		*/

        IF ( ( i_pindex = 0 ) AND ( ( i_num_recs > 1 ) OR ( l_num_pallets_below > 0 ) OR ( ( i_is_diff_item = 'Y' ) OR ( i_num_recs

        > 0 ) ) ) ) THEN
            o_pickup := nvl(o_pickup, 0) + i_e_rec.ppof;
            IF ( g_forklift_audit = c_true ) THEN
                pl_lm_goaltime.lmg_audit_movement('PPOF', pl_lm_goaltime.g_audit_batch_no, i_e_rec, 1, '');
            END IF;

        ELSIF ( i_pindex > 0 ) THEN
            o_pickup := nvl(o_pickup, 0) + i_e_rec.ppos;
            IF ( g_forklift_audit = c_true ) THEN
                pl_lm_goaltime.lmg_audit_movement('PPOS', pl_lm_goaltime.g_audit_batch_no, i_e_rec, 1, '');
            END IF;

        END IF;
		/*
		**  Put the pallets back in the reserve slot IF this is the last pallet
		**  to pick from the slot and pallets were removed from the slot because
		**  there were dIFferent items in the slot.
		*/

        IF ( i_pals(i_pindex).multi_pallet_drop_to_slot = 'N' ) THEN
            IF ( i_is_diff_item = 'Y' ) THEN
                o_pickup := nvl(o_pickup, 0) + i_e_rec.bp;
				/*
				**  Move FORks to top pallet of reserve stack.
				*/
                IF ( l_res_stack_height > ( c_std_pallet_height * ( i_num_recs - 1 ) ) ) THEN
                    o_pickup := nvl(o_pickup, 0) + ( ( ( l_res_stack_height - ( c_std_pallet_height * ( i_num_recs - 1 ) ) ) / 12.0 ) * i_e_rec.re );

                ELSE
                    o_pickup := nvl(o_pickup, 0) + ( ( ( ( c_std_pallet_height * ( i_num_recs - 1 ) ) - l_res_stack_height ) / 12.0 ) * i_e_rec.le );
                END IF;

                IF ( g_forklift_audit = c_true ) THEN
                    pl_lm_goaltime.lmg_audit_movement('BP', pl_lm_goaltime.g_audit_batch_no, i_e_rec, 1, 'Put reserve pallets back in the slot.'
                    );
                    l_message := 'Move FORks to top pallet of reserve stack';
                    IF ( l_res_stack_height > ( c_std_pallet_height * ( i_num_recs - 1 ) ) ) THEN
                        pl_lm_goaltime.lmg_audit_movement('RE', pl_lm_goaltime.g_audit_batch_no, i_e_rec, l_res_stack_height -(c_std_pallet_height
                        *(i_num_recs - 1)), l_message);
                    ELSE
                        pl_lm_goaltime.lmg_audit_movement('LE', pl_lm_goaltime.g_audit_batch_no, i_e_rec,(c_std_pallet_height *(i_num_recs
                        - 1)) - l_res_stack_height, l_message);
                    END IF;

                END IF;/* END audit */
				/*
				**  Replace the pallets from the reserve slot.
				*/

                FOR i IN REVERSE 1..i_num_recs LOOP
                    IF ( l_res_stack_height = 0 ) THEN
                        o_pickup := nvl(o_pickup, 0) + i_e_rec.apof + i_e_rec.mepof;
                    ELSE
                        o_pickup := nvl(o_pickup, 0) + i_e_rec.apos + i_e_rec.mepos;
                    END IF;

                    o_pickup := nvl(o_pickup, 0) + i_e_rec.bt90 + i_e_rec.apidi;
                    IF ( l_slot_height > l_res_stack_height ) THEN
                        o_pickup := nvl(o_pickup, 0) + ( ( ( l_slot_height - l_res_stack_height ) / 12.0 ) * i_e_rec.rl );
                    ELSE
                        o_pickup := nvl(o_pickup, 0) + ( ( ( l_res_stack_height - l_slot_height ) / 12.0 ) * i_e_rec.ll );
                    END IF;

                    o_pickup := nvl(o_pickup, 0) + i_e_rec.ppidi;
                    IF ( g_forklift_audit = c_true ) THEN
                        IF ( i = i_num_recs ) THEN
                            l_message := 'Put reserve pallets back in slot '
                                         || i_pals(i_pindex).loc
                                         || '. '
                                         || i_num_recs
                                         || ' pallet(s) to put back.';

                            pl_lm_goaltime.lmg_audit_cmt(pl_lm_goaltime.g_audit_batch_no, l_message, -1);
                        END IF;

                        IF ( l_res_stack_height = 0 ) THEN
                            pl_lm_goaltime.lmg_audit_movement('APOF', pl_lm_goaltime.g_audit_batch_no, i_e_rec, 1, '');
                            pl_lm_goaltime.lmg_audit_movement('MEPOF', pl_lm_goaltime.g_audit_batch_no, i_e_rec, 1, '');
                        ELSE
                            pl_lm_goaltime.lmg_audit_movement('APOS', pl_lm_goaltime.g_audit_batch_no, i_e_rec, 1, '');
                            pl_lm_goaltime.lmg_audit_movement('MEPOS', pl_lm_goaltime.g_audit_batch_no, i_e_rec, 1, '');
                        END IF;

                        pl_lm_goaltime.lmg_audit_movement('BT90', pl_lm_goaltime.g_audit_batch_no, i_e_rec, 1, '');
                        pl_lm_goaltime.lmg_audit_movement('APIDI', pl_lm_goaltime.g_audit_batch_no, i_e_rec, 1, '');
                        IF ( l_slot_height > l_res_stack_height ) THEN
                            pl_lm_goaltime.lmg_audit_movement('RL', pl_lm_goaltime.g_audit_batch_no, i_e_rec, l_slot_height - l_res_stack_height
                            , '');
                        ELSE
                            pl_lm_goaltime.lmg_audit_movement('LL', pl_lm_goaltime.g_audit_batch_no, i_e_rec, l_res_stack_height -
                            l_slot_height, '');
                        END IF;

                        pl_lm_goaltime.lmg_audit_movement('PPIDI', pl_lm_goaltime.g_audit_batch_no, i_e_rec, 1, '');
                    END IF;

                    IF ( l_res_stack_height = 0 ) THEN
                        l_res_stack_height := l_pos_x_stack_height;
                    ELSE
                        l_res_stack_height := l_res_stack_height - c_std_pallet_height;
                    END IF;

                    IF ( l_res_stack_height > l_slot_height ) THEN
                        o_pickup := nvl(o_pickup, 0) + ( ( ( l_res_stack_height - l_slot_height ) / 12.0 ) * i_e_rec.re );
                    ELSE
                        o_pickup := nvl(o_pickup, 0) + ( ( ( l_slot_height - l_res_stack_height ) / 12.0 ) * i_e_rec.le );
                    END IF;

                    o_pickup := nvl(o_pickup, 0) + i_e_rec.bt90;
                    IF ( g_forklift_audit = c_true ) THEN
                        IF ( l_res_stack_height > l_slot_height ) THEN
                            pl_lm_goaltime.lmg_audit_movement('RE', pl_lm_goaltime.g_audit_batch_no, i_e_rec, l_res_stack_height -
                            l_slot_height, '');
                        ELSE
                            pl_lm_goaltime.lmg_audit_movement('LE', pl_lm_goaltime.g_audit_batch_no, i_e_rec, l_slot_height - l_res_stack_height
                            , '');
                        END IF;

                        pl_lm_goaltime.lmg_audit_movement('BT90', pl_lm_goaltime.g_audit_batch_no, i_e_rec, 1, '');
                    END IF;

                END LOOP;

            END IF;

            IF ( l_num_pallets_below > 0 ) THEN
				/*
				**  Move FORk to top pallet of posx below stack IF the reserve
				**  had the same item in it.
				*/
                IF ( i_is_diff_item = 'N' ) THEN
                    o_pickup := nvl(o_pickup, 0) + i_e_rec.bp;
                    IF ( l_pos_x_stack_height > ( c_std_pallet_height * ( i_num_recs - 1 ) ) ) THEN
                        o_pickup := nvl(o_pickup, 0) + ( ( ( l_pos_x_stack_height - ( c_std_pallet_height * ( i_num_recs - 1 ) ) )
                        / 12.0 ) * i_e_rec.re );

                    ELSE
                        o_pickup := nvl(o_pickup, 0) + ( ( ( ( c_std_pallet_height * ( i_num_recs - 1 ) ) - l_pos_x_stack_height )
                        / 12.0 ) * i_e_rec.le );
                    END IF;

                    IF ( g_forklift_audit = c_true ) THEN
                        pl_lm_goaltime.lmg_audit_movement('BP', pl_lm_goaltime.g_audit_batch_no, i_e_rec, 1, '');
                        IF ( l_pos_x_stack_height > ( c_std_pallet_height * ( i_num_recs - 1 ) ) ) THEN
                            pl_lm_goaltime.lmg_audit_movement('RE', pl_lm_goaltime.g_audit_batch_no, i_e_rec, l_pos_x_stack_height
                            -(c_std_pallet_height *(i_num_recs - 1)), '');

                        ELSE
                            pl_lm_goaltime.lmg_audit_movement('LE', pl_lm_goaltime.g_audit_batch_no, i_e_rec,(c_std_pallet_height
                            *(i_num_recs - 1)) - l_pos_x_stack_height, '');
                        END IF;

                    END IF;

                END IF;
				/*
				**  Replace the pallets from the slots below to 1 position.
				*/

                FOR i IN REVERSE 1..l_num_pallets_below LOOP
                    l_slot_height := l_posx_pals(i).height;
                    IF ( l_pos_x_stack_height = 0 ) THEN
                        o_pickup := nvl(o_pickup, 0) + i_e_rec.apof + i_e_rec.mepof;
                    ELSE
                        o_pickup := nvl(o_pickup, 0) + i_e_rec.apos + i_e_rec.mepos;
                    END IF;

                    o_pickup := nvl(o_pickup, 0) + i_e_rec.bt90 + i_e_rec.apidi;
                    IF ( l_slot_height > l_pos_x_stack_height ) THEN
                        o_pickup := nvl(o_pickup, 0) + ( ( ( l_slot_height - l_pos_x_stack_height ) / 1.0 ) * i_e_rec.rl );
                    ELSE
                        o_pickup := nvl(o_pickup, 0) + ( ( ( l_pos_x_stack_height - l_slot_height ) / 12.0 ) * i_e_rec.ll );
                    END IF;

                    o_pickup := nvl(o_pickup, 0) + i_e_rec.ppidi;
                    IF ( g_forklift_audit = c_true ) THEN
                        IF ( i = l_num_pallets_below ) THEN
                            l_message := 'Replace the pallets removed from the slots below. '
                                         || l_num_pallets_below
                                         || 'pallet(s) to put back.';
                            pl_lm_goaltime.lmg_audit_cmt(pl_lm_goaltime.g_audit_batch_no, l_message, -1);
                        END IF;

                        IF ( l_pos_x_stack_height = 0 ) THEN
                            pl_lm_goaltime.lmg_audit_movement('APOF', pl_lm_goaltime.g_audit_batch_no, i_e_rec, 1, 'Put pallet back.'
                            );
                            pl_lm_goaltime.lmg_audit_movement('MEPOF', pl_lm_goaltime.g_audit_batch_no, i_e_rec, 1, '');
                        ELSE
                            pl_lm_goaltime.lmg_audit_movement('APOS', pl_lm_goaltime.g_audit_batch_no, i_e_rec, 1, 'Put pallet back.'
                            );
                            pl_lm_goaltime.lmg_audit_movement('MEPOS', pl_lm_goaltime.g_audit_batch_no, i_e_rec, 1, '');
                        END IF;

                        pl_lm_goaltime.lmg_audit_movement('BT90', pl_lm_goaltime.g_audit_batch_no, i_e_rec, 1, '');
                        pl_lm_goaltime.lmg_audit_movement('APIDI', pl_lm_goaltime.g_audit_batch_no, i_e_rec, 1, '');
                        IF ( l_slot_height > l_pos_x_stack_height ) THEN
                            pl_lm_goaltime.lmg_audit_movement('RL', pl_lm_goaltime.g_audit_batch_no, i_e_rec, l_slot_height - l_pos_x_stack_height
                            , '');
                        ELSE
                            pl_lm_goaltime.lmg_audit_movement('LL', pl_lm_goaltime.g_audit_batch_no, i_e_rec, l_pos_x_stack_height
                            - l_slot_height, '');
                        END IF;

                        pl_lm_goaltime.lmg_audit_movement('PPIDI', pl_lm_goaltime.g_audit_batch_no, i_e_rec, 1, '');
                    END IF;/* END audit */

                    IF ( i > 1 ) THEN
                        l_pos_x_stack_height := l_pos_x_stack_height - c_std_pallet_height;
                    END IF;
                    IF ( l_pos_x_stack_height > l_slot_height ) THEN
                        o_pickup := nvl(o_pickup, 0) + ( ( ( l_pos_x_stack_height - l_slot_height ) / 12.0 ) * i_e_rec.re );
                    ELSE
                        o_pickup := nvl(o_pickup, 0) + ( ( ( l_slot_height - l_pos_x_stack_height ) / 12.0 ) * i_e_rec.le );
                    END IF;

                    o_pickup := nvl(o_pickup, 0) + i_e_rec.bt90;
                    IF ( g_forklift_audit = c_true ) THEN
                        IF ( l_pos_x_stack_height > l_slot_height ) THEN
                            pl_lm_goaltime.lmg_audit_movement('RE', pl_lm_goaltime.g_audit_batch_no, i_e_rec, l_pos_x_stack_height
                            - l_slot_height, '');
                        ELSE
                            pl_lm_goaltime.lmg_audit_movement('LE', pl_lm_goaltime.g_audit_batch_no, i_e_rec, l_slot_height - l_pos_x_stack_height
                            , '');
                        END IF;

                        pl_lm_goaltime.lmg_audit_movement('BT90', pl_lm_goaltime.g_audit_batch_no, i_e_rec, 1, '');
                    END IF;/* END audit */

                END LOOP;

            END IF;

        END IF;

        IF ( i_pindex = 0 ) THEN
			/*
			**  Pickup up pallets.
			*/
            IF ( ( i_is_diff_item = 'Y' ) OR ( l_num_pallets_below > 0 ) ) THEN
                o_pickup := nvl(o_pickup, 0) + i_e_rec.apof + i_e_rec.mepof;
                IF ( g_forklift_audit = c_true ) THEN
                    pl_lm_goaltime.lmg_audit_movement('APOF', pl_lm_goaltime.g_audit_batch_no, i_e_rec, 1, 'Pickup pallets.');
                    pl_lm_goaltime.lmg_audit_movement('MEPOF', pl_lm_goaltime.g_audit_batch_no, i_e_rec, 1, '');
                END IF;

            ELSIF ( i_num_recs > 1 ) THEN
                o_pickup := nvl(o_pickup, 0) + ( ( ( c_std_pallet_height * ( i_num_recs - 1 ) ) / 12.0 ) * i_e_rec.le );

                o_pickup := nvl(o_pickup, 0) + i_e_rec.bp + i_e_rec.apof + i_e_rec.mepof;

                IF ( g_forklift_audit = c_true ) THEN
                    pl_lm_goaltime.lmg_audit_movement('LE', pl_lm_goaltime.g_audit_batch_no, i_e_rec, c_std_pallet_height *(i_num_recs
                    - 1), 'Pickup pallets');

                    pl_lm_goaltime.lmg_audit_movement('BP', pl_lm_goaltime.g_audit_batch_no, i_e_rec, 1, '');
                    pl_lm_goaltime.lmg_audit_movement('APOF', pl_lm_goaltime.g_audit_batch_no, i_e_rec, 1, '');
                    pl_lm_goaltime.lmg_audit_movement('MEPOF', pl_lm_goaltime.g_audit_batch_no, i_e_rec, 1, '');
                END IF;

            END IF;
        END IF;

        RETURN l_ret_val;
    END lmgdi_pickup_from_drivein_res;

END pl_lm_goal_di;
/

GRANT EXECUTE ON PL_LM_GOAL_DI TO swms_user;