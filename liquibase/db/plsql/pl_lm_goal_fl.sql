CREATE OR REPLACE PACKAGE pl_lm_goal_fl AS
/*********************************************************************************
**  PACKAGE:                                                                    **
**      pl_lm_goal_fl                                                           **
**  Files                                                                       **
**      pl_lm_goal_fl created from lm_goal_fl.pc                                **
**                                                                              **
**  DESCRIPTION: This file contains the functions and subroutes necessary to    **
**      calculate discreet Labor Management values for floor slots.             **
**                                                                              **
**  MODIFICATION HISTORY:                                                       **
**      DATE          USER              COMMENT                                 **
**   02/17/2020      Infosys           Initial version0.0                       **  
**********************************************************************************/
    FUNCTION lmgfl_drp_to_flr_hm_with_qoh (
        i_pals             IN      pl_lm_goal_pb.tbl_lmg_pallet_rec,
        i_num_pallets      IN      NUMBER,
        i_e_rec            IN      pl_lm_goal_pb.type_lmc_equip_rec,
        i_dest_total_qoh   IN      NUMBER,
        o_drop             OUT     NUMBER
    ) RETURN NUMBER;

    FUNCTION lmgfl_drp_flr_res_with_qoh (
        i_pals           IN      pl_lm_goal_pb.tbl_lmg_pallet_rec,
        i_num_pallets    IN      NUMBER,
        i_e_rec          IN      pl_lm_goal_pb.type_lmc_equip_rec,
        i_inv            IN      pl_lm_goal_pb.tbl_lmg_inv_rec,
        i_num_recs       IN      NUMBER,
        i_is_same_item   IN      VARCHAR2,
        o_drop           OUT     NUMBER
    ) RETURN NUMBER;

    FUNCTION lmgfl_pickup_from_floor_res (
        i_pals           IN    pl_lm_goal_pb.tbl_lmg_pallet_rec,
        i_pindex         IN    NUMBER,
        i_e_rec          IN    pl_lm_goal_pb.type_lmc_equip_rec,
        i_inv            IN    pl_lm_goal_pb.tbl_lmg_inv_rec,
        i_is_diff_item   IN    VARCHAR2,
        i_num_recs       IN    NUMBER,
        o_pickup         OUT   NUMBER
    ) RETURN NUMBER;

    PROCEDURE lmgfl_rem_plts_frm_flr_slot (
        i_location                IN    VARCHAR2,
        i_e_rec                   IN    pl_lm_goal_pb.type_lmc_equip_rec,
        i_num_pallets_to_remove   IN    NUMBER,
        i_num_positions           IN    NUMBER,
        i_home_slot_bln           IN    NUMBER,
        o_pallets_in_stack        OUT   NUMBER,
        o_drop                    OUT   NUMBER
    );

    PROCEDURE lmgfl_putbk_plts_in_flr_slot (
        i_location                 IN     VARCHAR2,
        i_total_pallets_in_slot    IN     NUMBER,
        i_num_pallets_to_putback   IN     NUMBER,
        i_num_positions            IN     NUMBER,
        i_home_slot_bln            IN     NUMBER,
        i_current_fork_height      IN     NUMBER,
        i_e_rec                    IN     pl_lm_goal_pb.type_lmc_equip_rec,
        o_drop                     OUT    NUMBER
    );

    PROCEDURE lmgfl_drop_to_floor_slot (
        i_stacking_positions           IN      NUMBER,
        i_total_pallets_in_slot        IN      NUMBER,
        i_pallets_already_putaway      IN      NUMBER,
        i_num_pallets_to_put_in_slot   IN      NUMBER,
        i_e_rec                        IN      pl_lm_goal_pb.type_lmc_equip_rec,
        i_pallet_height                IN      NUMBER,
        o_drop                         OUT     NUMBER
    );

    FUNCTION lmgfl_floor_slot_stack_height (
        i_stacking_positions        IN   NUMBER,
        i_total_pallets_in_slot     IN   NUMBER,
        i_pallets_already_putaway   IN   NUMBER
    ) RETURN NUMBER;

    PROCEDURE lmgfl_place_pallet_in_flr_slt (
        i_floor_slot_stack_height   IN       NUMBER,
        i_pallet_height             IN       NUMBER,
        i_e_rec                     IN       pl_lm_goal_pb.type_lmc_equip_rec,
        o_drop                      OUT      NUMBER
    );

END pl_lm_goal_fl;
/

CREATE OR REPLACE PACKAGE BODY pl_lm_goal_fl AS
/*********************************************************************************
**  PACKAGE:                                                                    **
**      pl_lm_goal_fl                                                           **
**  Files                                                                       **
**      pl_lm_goal_fl created from lm_goal_fl.pc                                **
**                                                                              **
**  DESCRIPTION: This file contains the functions and subroutes necessary to    **
**      calculate discreet Labor Management values for floor slots.             **
**                                                                              **
**  MODIFICATION HISTORY:                                                       **
**      DATE          USER              COMMENT                                 **
**   02/17/2020      Infosys           Initial version0.0                       **  
**********************************************************************************/
    C_TRUE                    CONSTANT NUMBER := 1;
    C_FALSE                   CONSTANT NUMBER := 0;
    g_forklift_audit          NUMBER := C_FALSE; 
    C_ONLY_PUTAWAY_TO_SLOT    CONSTANT NUMBER := 1;
    C_FIRST_PUTAWAY_TO_SLOT   CONSTANT NUMBER := 2;
    C_LAST_PUTAWAY_TO_SLOT    CONSTANT NUMBER := 3;
    C_IN_SLOT                 CONSTANT NUMBER := 1;
    C_IN_AISLE                CONSTANT NUMBER := 2;
    C_NON_PUTAWAY             CONSTANT NUMBER := 5;
    C_STD_PALLET_HEIGHT       CONSTANT NUMBER := 48;
    C_MAX_PALS_PER_STACK      CONSTANT NUMBER := 2;

/*****************************************************************************
**  FUNCTION:
**      lmgfl_drp_to_flr_hm_with_qoh()
**
**  DESCRIPTION:
**      This function calculates the LM drop discreet value FOR a pallet
**      going to a floor home slot that is EMPTY OR WITH EXISTING QOH.
**      Should only be dealing with case quantities.
**
**  PARAMETERS:
**      i_pals            - Pointer to pallet list.
**      i_num_pallets     - Number of pallets in pallet list.
**      i_e_rec           - Pointer to equipment tmu values.
**      i_dest_total_qoh  - Total qoh in destination.
**      o_drop            - Outgoing drop value.
**
**  RETURN VALUES:
**      Return 0
**  MODIFICATION HISTORY:                                                       **
**      DATE          USER              COMMENT                                 **
**   02/17/2020      Infosys           Initial version0.0                       **  
*****************************************************************************/

    FUNCTION lmgfl_drp_to_flr_hm_with_qoh (
        i_pals             IN                 pl_lm_goal_pb.tbl_lmg_pallet_rec,
        i_num_pallets      IN                 NUMBER,
        i_e_rec            IN                 pl_lm_goal_pb.type_lmc_equip_rec,
        i_dest_total_qoh   IN                 NUMBER,
        o_drop             OUT                NUMBER
    ) RETURN NUMBER AS

        l_func_name                     VARCHAR2(50) := 'pl_lm_goal_fl.lmgfl_drp_to_flr_hm_with_qoh';
        l_adj_num_positions             NUMBER := 0;
        l_drop_type                     NUMBER;
        l_existing_inv                  NUMBER;
        l_floor_slot_stack_height       NUMBER;
        l_last_pal_qty                  NUMBER := 0;
        l_pallet_count                  NUMBER := 0;
        l_pallet_height                 NUMBER := 0;
        l_pallet_qty                    NUMBER := 0;
        l_num_pending_putaways          NUMBER := 0;
        l_num_drops_completed           NUMBER := 0;
        l_pallets_in_slot               NUMBER := 0;
        l_pallets_in_stack              NUMBER := 0;
        l_pallets_to_move               NUMBER := 0;
        l_pindex                        NUMBER := 1;
        l_prev_qoh                      NUMBER := 0;
        l_putback_existing_inv          BOOLEAN;
        l_remove_existing_inv           BOOLEAN;
        l_same_slot_drop                VARCHAR2(1);
        l_slot_type_num_positions       NUMBER;
        l_spc                           NUMBER := 0;
        l_start_height                  NUMBER := 0;
        l_ti_hi                         NUMBER := 0;
        l_total_pallets_in_slot         NUMBER := 0;
        l_message                       VARCHAR2(1024);
        l_ret_val                       NUMBER := RF.STATUS_NORMAL;
        l_putaway_batch                 VARCHAR2(2);
        l_temp                          NUMBER;
        l_num_pallets_temp              NUMBER;
        l_slot_type_num_positions_tmp   NUMBER;
		
    BEGIN
        pl_text_log.ins_msg_async('INFO', l_func_name, 'Starting lmgfl_drp_to_flr_hm_with_qoh. i_pals.batch_no= '
                                            || i_pals(l_pindex).batch_no
                                            || 'i_num_pallets = '
                                            || i_num_pallets, sqlcode, sqlerrm);

        l_num_pallets_temp := i_num_pallets;
        l_putaway_batch := substr(i_pals(l_pindex).batch_no, 1, 2);
        IF l_putaway_batch = 'FP' THEN
            l_temp := 1;
        ELSE
            l_temp := 0;
        END IF;

        pl_text_log.ins_msg_async('INFO', l_func_name, 'i_pals.pallet_id(l_num_pallets_temp), '
                                            || i_pals(l_num_pallets_temp).pallet_id
                                            || ' l_num_pallets_temp= '
                                            || l_num_pallets_temp
                                            || ' i_e_rec.equip_id '
                                            || i_e_rec.equip_id
                                            || ' i_dest_total_qoh= '
                                            || i_dest_total_qoh
                                            || ' i_pals.multi_pallet_drop_to_slot(i_num_pallets) = '
                                            || i_pals(l_num_pallets_temp).multi_pallet_drop_to_slot, sqlcode, sqlerrm);
    /*
    **  Always removing the top pallet on the stack.
    */
        l_pindex := l_num_pallets_temp;
        l_same_slot_drop := i_pals(l_pindex).multi_pallet_drop_to_slot;
		/*
    **  Same slot drops were processed by this function on first pallet dropped
    **  to the slot.
    */
        IF ( l_same_slot_drop = 'Y' ) THEN
            RETURN C_IN_SLOT;
        END IF;
        l_prev_qoh := i_dest_total_qoh;
        l_spc := i_pals(l_pindex).spc;
        l_ti_hi := i_pals(l_pindex).ti * i_pals(l_pindex).hi * l_spc;

        l_pallets_in_slot := l_prev_qoh / l_ti_hi;
        l_last_pal_qty := MOD(l_prev_qoh, l_ti_hi);
        IF ( l_last_pal_qty > 0 ) THEN
            l_pallets_in_slot := l_pallets_in_slot + 1;
        END IF;
		/*
		** IF l_last_pal_qty is 0 then each pallet in the slot is a full pallet so
		** set l_last_pal_qty to a full pallet.
		*/
        IF ( l_last_pal_qty = 0 ) THEN
            l_last_pal_qty := l_ti_hi;
        END IF;
		/*
		** Extract the number of positions in the slot from the slot type.
		*/
        /*slot type is in 10th position in the argument passing from Input. Here l_slot_type_num_positions defined as 10 instead of slot type*/
        l_slot_type_num_positions := 10; /*i_pals(l_pindex).slot_type;*/
		/*
		** Adjust the number of positions based on the min quantity.
		** Note that this does not get used FOR anything when dealing with floor
		** slots.
		*/
        l_adj_num_positions := i_pals(l_pindex).min_qty_num_positions + l_slot_type_num_positions;
		
		/*
		** Determine IF the existing inventory in the slot needs to be removed.
		** FOR putaways going to the same slot on a PO the inventory is removed
		** when the first putaway is perFORmed and put back after the last
		** putaway is perFORmed.  Pallets from previous puts on the same PO
		** are not removed.
		*/
        IF ( l_temp = 1 ) THEN
            l_ret_val := pl_lm_forklift.lmf_what_putaway_is_this(i_pals(l_pindex).pallet_id, l_drop_type, l_num_drops_completed, l_num_pending_putaways
            );

            l_pallets_to_move := l_pallets_in_slot - l_num_drops_completed;
            IF ( l_pallets_to_move < 0 ) THEN
                l_pallets_to_move := 0;
            END IF;
            IF ( ( l_drop_type = C_ONLY_PUTAWAY_TO_SLOT OR l_drop_type = C_FIRST_PUTAWAY_TO_SLOT ) AND l_pallets_to_move > 0 ) THEN
                l_remove_existing_inv := TRUE;
                l_existing_inv := C_IN_SLOT;
            ELSE
                l_remove_existing_inv := FALSE;
                l_existing_inv := C_IN_AISLE;
            END IF;

            IF ( (l_drop_type = C_ONLY_PUTAWAY_TO_SLOT OR l_drop_type = C_LAST_PUTAWAY_TO_SLOT) AND l_pallets_to_move > 0 ) THEN
                l_putback_existing_inv := TRUE;
            ELSE
                l_putback_existing_inv := FALSE;
            END IF;
			/*
			** Calculate the number of pallets that will be in the slot after
			** all the putaways on the PO are completed.
			*/

            FOR i IN REVERSE 1..l_pindex LOOP
                IF ( i_pals(i).multi_pallet_drop_to_slot = 'Y' ) THEN
                    l_total_pallets_in_slot := l_total_pallets_in_slot + 1;
                END IF;

            END LOOP;
             l_total_pallets_in_slot := l_total_pallets_in_slot + l_num_pending_putaways + l_pallets_in_slot + 1;
        ELSE
            l_drop_type := C_NON_PUTAWAY;
            l_pallets_to_move := l_pallets_in_slot;
            l_num_drops_completed := 0;
            l_remove_existing_inv := TRUE;
            l_putback_existing_inv := TRUE;
        END IF; /*end of temp=1*/
		/*
		**  Previous pallets putaway to the slot that are on the same PO as the
		**  current pallet are not removed from the slot.
		*/

        l_pallet_count := l_pallets_to_move;
        IF ( g_forklift_audit = C_TRUE ) THEN
            pl_text_log.ins_msg_async('INFO', l_func_name, 'Drop pallet '
                                                || i_pals(l_pindex).pallet_id
                                                || ' containing '
                                                || i_pals(l_pindex).qty_on_pallet / l_spc
                                                || ' cases to '
                                                || i_pals(l_pindex).slot_type
                                                || ' floor home slot '
                                                || i_pals(l_pindex).dest_loc
                                                || 'with qoh of '
                                                || i_dest_total_qoh / l_spc
                                                || ' cases on '
                                                || l_pallets_in_slot
                                                || ' pallet(s).', sqlcode, sqlerrm);

            IF ( l_num_drops_completed > 0 ) THEN
                l_message := l_num_drops_completed || ' pallet(s) on the PO has/have been putaway to this slot. It/They will not be removed FOR rotation.'
                ;
                pl_lm_goaltime.lmg_audit_cmt(pl_lm_goaltime.g_audit_batch_no, l_message, -1);
            END IF;
			

        END IF;
            /*
			**  Put travel stack down IF there is more than one pallet in the travel
			**  stack or IF the existing pallets in the slot need to be removed and
			**  there are pallets to remove.
			*/
        IF ( l_num_pallets_temp > 1 OR ( l_remove_existing_inv != FALSE AND l_pallets_to_move > 0 ) ) THEN
            o_drop := i_e_rec.ppof;
            IF ( g_forklift_audit = C_TRUE ) THEN
                IF ( l_num_pallets_temp > 1 AND l_existing_inv = C_IN_AISLE AND i_dest_total_qoh > 0 ) THEN
                    l_message := 'The existing inventory stacked in the aisle on a previous drop. Put stack down because there is more than one pallet ('
                                 || l_num_pallets_temp
                                 || ') in the stack';
                ELSE
                    l_message := 'Put stack down. '
                                 || l_num_pallets_temp
                                 || ' Pallet(s) in the stack.';
                    pl_lm_goaltime.lmg_audit_movement('PPOF', pl_lm_goaltime.g_audit_batch_no, i_e_rec, 1, l_message);
                END IF;

            END IF;

        END IF;
        /*
    **  Remove the pallets from the home slot if existing inventory is to
    **  be removed and there are pallets to remove.
    */
        IF ( l_remove_existing_inv != FALSE AND l_pallets_to_move > 0 ) THEN
            IF ( g_forklift_audit = C_TRUE ) THEN
                l_message := 'Remove the existing '||l_pallets_to_move||' pallet(s) from the home slot.';
                pl_lm_goaltime.lmg_audit_cmt(pl_lm_goaltime.g_audit_batch_no, l_message, -1);
            END IF;
/* TRUE in argument list indicates a home slot. */
            lmgfl_rem_plts_frm_flr_slot(i_pals(l_pindex).dest_loc, i_e_rec, l_pallets_to_move, l_slot_type_num_positions, C_TRUE, l_pallets_in_stack, o_drop);

        END IF;

        IF ( g_forklift_audit = C_TRUE AND l_remove_existing_inv = FALSE AND l_pallets_to_move > 0 ) THEN
		 /*
        ** There are pallets to remove and the flag set to not remove
        ** existing inv move which means the pallets were removed on a
        ** previous putaway.
        */
            l_message := 'The existing '
                         || l_pallets_to_move
                         || ' pallet(s) removed from the home slot on a previous putaway  '
                         || l_pallets_to_move;
            pl_lm_goaltime.lmg_audit_cmt(pl_lm_goaltime.g_audit_batch_no, l_message, -1);
        END IF;
/*
    **  The existing pallets in the slot have been removed if they were not
    **  removed on a previous putaway on the same PO.
    **  Drop the new pallet into the slot.
    */
        l_pallet_height := C_STD_PALLET_HEIGHT * l_pindex;
        l_pallet_qty := i_pals(l_pindex).qty_on_pallet;
		  /*
    **  Drop the new pallet into the slot.
    **
    **  If the existing pallets in the slot were removed for this drop then
    **  the forks will be at the level of the last pallet removed otherwise
    **  the forks will be at the floor.  Set l_start_height to the height
    **  of the forks.
    */
        IF ( l_remove_existing_inv != FALSE AND l_pallets_to_move > 0 ) THEN
            IF ( l_pallets_in_stack = 0 ) THEN
                l_start_height := 0;
            ELSE
                l_start_height := C_STD_PALLET_HEIGHT * ( l_pallets_in_stack - 1 );
            END IF;
        ELSE
            l_start_height := 0;
        END IF;
/*
    ** Determine the height of the stack in the slot the new pallet
    ** will be placed on.  Note for floor home slots one position is reserved
    ** for the pick pallet.
    */
        IF ( ( l_slot_type_num_positions - 1 ) = 0 ) THEN
            l_slot_type_num_positions_tmp := 1;
        ELSE
            l_slot_type_num_positions_tmp := l_slot_type_num_positions - 1;
        END IF;

        l_floor_slot_stack_height := lmgfl_floor_slot_stack_height(l_slot_type_num_positions_tmp, l_total_pallets_in_slot - 1, l_num_drops_completed

        );
        IF ( l_num_pallets_temp > 1 ) THEN
		/*
        **  There is more than one pallet in the travel stack.  The needed
        **  pallet will be on the top of the travel stack.  Take the pallet
        **  off the travel stack and place it in the floor slot.
        */
            o_drop := nvl(o_drop, 0) + i_e_rec.bp + i_e_rec.apos;
            IF ( g_forklift_audit = C_TRUE ) THEN
                l_message := 'Put pallet '
                             || i_pals(l_pindex).pallet_id
                             || ' in slot '
                             || i_pals(l_pindex).dest_loc;

                pl_lm_goaltime.lmg_audit_movement('BP', pl_lm_goaltime.g_audit_batch_no, i_e_rec, 1, l_message);
                pl_lm_goaltime.lmg_audit_movement('APOS', pl_lm_goaltime.g_audit_batch_no, i_e_rec, 1, '');
            END IF;
/*
        **  Must move fork from last known position to top of last stack to
        **  height of the new pallet in the travel pallet stack.
        */
            IF ( l_pallet_height > l_start_height ) THEN
                o_drop := nvl(o_drop, 0) + ( ( ( l_pallet_height - l_start_height ) / 12.0 ) * i_e_rec.re );
            ELSE
                o_drop := nvl(o_drop, 0) + ( ( ( l_start_height - l_pallet_height ) / 12.0 ) * i_e_rec.le );
            END IF;
/*
        ** Take the pallet off the travel stack.
        */
            o_drop := nvl(o_drop, 0) + i_e_rec.mepos + i_e_rec.bt90;
            IF ( g_forklift_audit = C_TRUE ) THEN
                IF ( l_pallet_height > l_start_height ) THEN
                    pl_lm_goaltime.lmg_audit_movement('RE', pl_lm_goaltime.g_audit_batch_no, i_e_rec, l_pallet_height - l_start_height
                    , '');
                ELSE
                    pl_lm_goaltime.lmg_audit_movement('LE', pl_lm_goaltime.g_audit_batch_no, i_e_rec, l_start_height - l_pallet_height
                    , '');
                END IF;

                pl_lm_goaltime.lmg_audit_movement('MEPOS', pl_lm_goaltime.g_audit_batch_no, i_e_rec, 1, '');
                pl_lm_goaltime.lmg_audit_movement('BT90', pl_lm_goaltime.g_audit_batch_no, i_e_rec, 1, '');
            END IF;
 /*
        ** Place the pallet in the floor slot.
        */
            lmgfl_place_pallet_in_flr_slt(l_floor_slot_stack_height, l_pallet_height, i_e_rec, o_drop);
        ELSE
            IF ( l_existing_inv != C_IN_AISLE AND l_pallets_to_move != 0 ) THEN
			/*
            ** The existing inventory in the slot has been removed for this
            ** drop.  Prepare to pickup the pallet in the travel stack.
            */
                o_drop := nvl(o_drop, 0) + i_e_rec.bp + i_e_rec.apof;
                IF ( g_forklift_audit = C_TRUE ) THEN
                    l_message := 'The existing inventory in slot '
                                 || i_pals(l_pindex).dest_loc
                                 || ' has been removed. Pickup pallet '
                                 || i_pals(l_pindex).pallet_id
                                 || ' in stack and put in slot '
                                 || i_pals(l_pindex).dest_loc;

                    pl_lm_goaltime.lmg_audit_movement('BP', pl_lm_goaltime.g_audit_batch_no, i_e_rec, 1, l_message);
                    pl_lm_goaltime.lmg_audit_movement('APOF', pl_lm_goaltime.g_audit_batch_no, i_e_rec, 1, '');
                END IF;

            END IF;
/*
        **  Drop new pallet into slot.
        **  If the existing inventory in the slot was removed for this drop
        **  then the forks are at the height of the last pallet removed from
        **  the slot otherwise the pallet to drop is on the forks.
        */
            IF ( l_remove_existing_inv != FALSE AND l_pallets_to_move > 0 ) THEN
			/*
            **  The existing inventory in the slot was removed on this drop.
            **  Their is 1 pallet in the travel stack so lower the forks to
            **  the floor, pickup the pallet and place it in the slot.
            */
                o_drop := nvl(o_drop, 0) + ( ( l_start_height / 12.0 ) * i_e_rec.le ) + i_e_rec.mepof + i_e_rec.bt90;

                IF ( g_forklift_audit = C_TRUE ) THEN
                    pl_lm_goaltime.lmg_audit_movement('LE', pl_lm_goaltime.g_audit_batch_no, i_e_rec, l_start_height, '');
                    pl_lm_goaltime.lmg_audit_movement('MEPOF', pl_lm_goaltime.g_audit_batch_no, i_e_rec, 1, '');
                    pl_lm_goaltime.lmg_audit_movement('BT90', pl_lm_goaltime.g_audit_batch_no, i_e_rec, 1, '');
                END IF;

                l_pallet_height := 0;
				/*
            ** Place the pallet in the floor slot.
            */
                lmgfl_place_pallet_in_flr_slt(l_floor_slot_stack_height, l_pallet_height, i_e_rec, o_drop);
            ELSE
			/*
            ** Pallets removed from the slot on a previous putaway.  Put the
            ** pallet on the forks into the slot.
            **
            ** If there are other pallets on the same PO that have been
            ** putaway to the slot then the new pallet is stacked on top
            ** of these pallets.
            */
                o_drop := nvl(o_drop, 0) + i_e_rec.tir;
                IF ( g_forklift_audit = C_TRUE ) THEN
                    pl_lm_goaltime.lmg_audit_movement('TIR', pl_lm_goaltime.g_audit_batch_no, i_e_rec, 1, '');
                END IF;

                l_pallet_height := 0;
				/*
            ** Place the pallet in the floor slot.
            */
                lmgfl_place_pallet_in_flr_slt(l_floor_slot_stack_height, l_pallet_height, i_e_rec, o_drop);
            END IF;

        END IF; /*End of num_pallets_temp > 1 */
/*
    ** Indicate the pallet has been dropped to the slot.
    */
        l_num_pallets_temp := l_num_pallets_temp - 1;
        l_num_drops_completed := l_num_drops_completed + 1;
		/*
    **  Process same slot drops now.
    */
        FOR i IN REVERSE 1..l_pindex LOOP
            l_pallet_height := C_STD_PALLET_HEIGHT * i;
            l_pallet_qty := i_pals(i).qty_on_pallet;
            IF ( i_pals(i).multi_pallet_drop_to_slot = 'Y' ) THEN
			/*
            **  There next pallet in the stack is going to the same slot.
            **  Put the pallet in the slot.
            */

                IF ( g_forklift_audit = C_TRUE ) THEN
                    l_message := 'Put pallet in slot. Pallet= '
                                 || i_pals(i).pallet_id
                                 || ' Slot= '
                                 || i_pals(i).dest_loc;

                    pl_lm_goaltime.lmg_audit_cmt(pl_lm_goaltime.g_audit_batch_no, l_message, -1);
                END IF;
/*
            **  Is this the last pallet in the incoming stack.
            */
                IF ( i = 1 ) THEN
				
                /*
                **  This is the last pallet in the travel stack.  Pick it up
                **  off the floor.
                */
                    o_drop := nvl(o_drop, 0) + i_e_rec.apof + ( ( l_floor_slot_stack_height / 12.0 ) * i_e_rec.le ) + i_e_rec.mepof
                    + i_e_rec.bt90;

                    IF ( g_forklift_audit = C_TRUE ) THEN
                        pl_lm_goaltime.lmg_audit_movement('APOF', pl_lm_goaltime.g_audit_batch_no, i_e_rec, 1, '');
                        pl_lm_goaltime.lmg_audit_movement('LE', pl_lm_goaltime.g_audit_batch_no, i_e_rec, l_floor_slot_stack_height
                        , '');
                        pl_lm_goaltime.lmg_audit_movement('MEPOF', pl_lm_goaltime.g_audit_batch_no, i_e_rec, 1, '');
                        pl_lm_goaltime.lmg_audit_movement('BT90', pl_lm_goaltime.g_audit_batch_no, i_e_rec, 1, '');
                    END IF;

                ELSE
				 /*
                **  This is not the last pallet in the stack.  Get the pallet
                **  off the travel stack.
                */
                    o_drop := nvl(o_drop, 0) + i_e_rec.apos;
                    IF ( l_pallet_height > l_floor_slot_stack_height ) THEN
                        o_drop := nvl(o_drop, 0) + ( ( ( l_pallet_height - l_floor_slot_stack_height ) / 12.0 ) * i_e_rec.le );

                    ELSE
                        o_drop := nvl(o_drop, 0) + ( ( ( l_floor_slot_stack_height - l_pallet_height ) / 12.0 ) * i_e_rec.le );
                    END IF;

                    o_drop := nvl(o_drop, 0) + i_e_rec.mepos + i_e_rec.bt90;
                    IF ( g_forklift_audit = C_TRUE ) THEN
                        pl_lm_goaltime.lmg_audit_movement('APOS', pl_lm_goaltime.g_audit_batch_no, i_e_rec, 1, '');
                        IF ( l_pallet_height > l_floor_slot_stack_height ) THEN
                            pl_lm_goaltime.lmg_audit_movement('RE', pl_lm_goaltime.g_audit_batch_no, i_e_rec, l_pallet_height - l_floor_slot_stack_height
                            , '');

                        ELSE
                            pl_lm_goaltime.lmg_audit_movement('LE', pl_lm_goaltime.g_audit_batch_no, i_e_rec, l_floor_slot_stack_height
                            - l_pallet_height, '');
                        END IF;

                        pl_lm_goaltime.lmg_audit_movement('MEPOS', pl_lm_goaltime.g_audit_batch_no, i_e_rec, 1, '');
                        pl_lm_goaltime.lmg_audit_movement('BT90', pl_lm_goaltime.g_audit_batch_no, i_e_rec, 1, '');
                    END IF;

                END IF; /* End of i = 0 IF */

                IF ( ( l_slot_type_num_positions - 1 ) = 0 ) THEN
                    l_slot_type_num_positions_tmp := 1;
                ELSE
                    l_slot_type_num_positions_tmp := l_slot_type_num_positions - 1;
                END IF;
/*
            ** Determine the height of the stack in the slot the new pallet
            ** will be placed on.  Note for floor home slots one position is reserved
            ** for the pick pallet.
            */
                l_floor_slot_stack_height := lmgfl_floor_slot_stack_height(l_slot_type_num_positions_tmp, l_total_pallets_in_slot - 1, l_num_drops_completed);
				/*
            ** Place the pallet in the floor slot.
            */
                lmgfl_place_pallet_in_flr_slt(l_floor_slot_stack_height, l_pallet_height, i_e_rec, o_drop);
                l_num_pallets_temp := l_num_pallets_temp - 1;
                l_num_drops_completed := l_num_drops_completed + 1;
            END IF; /* End of multi_pallet_drop_to_slot = 'Y' */

        END LOOP;
 /*
    **  Put back the existing inventory pallets if appropriate.
    **  For non putaway drops the pallets are always put back into the slot.
    **  For putaways the pallets are put back if this is the only putaway
    **  or the last putaway to the slot on the PO.
    */
        IF ( l_putback_existing_inv != FALSE AND l_pallets_to_move > 0 ) THEN
		/* The TRUE in the function call designates the slot as a home slot. */
            lmgfl_putbk_plts_in_flr_slot(i_pals(l_pindex).dest_loc, l_total_pallets_in_slot, l_pallets_to_move, l_slot_type_num_positions, C_TRUE, l_floor_slot_stack_height, i_e_rec, o_drop);
        ELSE
            o_drop := nvl(o_drop, 0) + ( ( l_floor_slot_stack_height / 12.0 ) * i_e_rec.le );

            IF ( g_forklift_audit = C_TRUE ) THEN
			
                pl_lm_goaltime.lmg_audit_movement('LE', pl_lm_goaltime.g_audit_batch_no, i_e_rec, l_floor_slot_stack_height, '');
            END IF;

        END IF;
/*
    ** Pickup stack if there are pallets left and go to the
    ** next destination.
    */
        IF ( l_num_pallets_temp > 0 ) THEN
		 /*
        ** There are pallets still in the travel stack.
        ** Pick up stack and go to next destination.
        */
            pl_lm_goaltime.lmg_pickup_for_next_dst(i_pals, l_num_pallets_temp - 1, i_e_rec, o_drop);
        END IF;

        RETURN 0;
    END lmgfl_drp_to_flr_hm_with_qoh;

/*****************************************************************************
**  FUNCTION:
**      lmgfl_drp_flr_res_with_qoh()
**
**  DESCRIPTION:
**      This functions calculates the LM drop discreet value FOR a pallet
**      going to a reserve floor slot that is EMPTY OR HAS EXISTING INVENTORY.
**      There should only be one level FOR these locations.
**      !!!! At the present time same item and dIFferent item will be processed
**      !!!! in the same manner.
**
**      IF there is more than one pallet going to the same slot then they
**      are all processed the first time this function is called.
**
**  PARAMETERS:
**      i_pals         - Pointer to pallet list.
**      i_num_pallets  - Number of pallets in the pallet list.
**      i_e_rec        - Pointer to equipment tmu values.
**      i_inv          - Pointer to pallets already in the destination.
**      i_is_same_item - Flag denoting IF the same item is already in the
**                       destination location.
**      o_drop         - Outgoing drop value.
**
**  RETURN VALUES:
**      returns 0 or 1.
**  MODIFICATION HISTORY:                                                       **
**      DATE          USER              COMMENT                                 **
**   02/17/2020      Infosys           Initial version0.0                       **  
*****************************************************************************/

    FUNCTION lmgfl_drp_flr_res_with_qoh (
        i_pals           IN               pl_lm_goal_pb.tbl_lmg_pallet_rec,
        i_num_pallets    IN               NUMBER,
        i_e_rec          IN               pl_lm_goal_pb.type_lmc_equip_rec,
        i_inv            IN               pl_lm_goal_pb.tbl_lmg_inv_rec,
        i_num_recs       IN               NUMBER,
        i_is_same_item   IN               VARCHAR2,
        o_drop           OUT              NUMBER
    ) RETURN NUMBER AS

        l_adj_num_positions         NUMBER := 0;
        l_drop_type                 NUMBER;
        l_existing_inv              NUMBER;
        l_floor_slot_stack_height   NUMBER;
        l_func_name                 VARCHAR2(50) := 'pl_lm_goal_fl.lmgfl_drp_flr_res_with_qoh';
        l_pallet_count              NUMBER := 0;
        l_pallet_height             NUMBER := 0;
        l_num_pending_putaways      NUMBER := 0;
        l_num_drops_completed       NUMBER := 0;
        l_pallets_in_slot           NUMBER := 0;
        l_pallets_in_stack          NUMBER := 0;
        l_pallets_to_move           NUMBER := 0;
        l_pindex                    NUMBER := 1;
        l_putback_existing_inv      BOOLEAN;
        l_remove_existing_inv       BOOLEAN;
        l_same_slot_drop            VARCHAR2(1);
        l_slot_type_num_positions   NUMBER;
        l_spc                       NUMBER := 0;
        l_start_height              NUMBER := 0;
        l_total_pallets_in_slot     NUMBER := 0;
        l_message                   VARCHAR2(1024);
        l_ret_val                   NUMBER := RF.STATUS_NORMAL;
        l_putaway_batch             VARCHAR2(2);
        l_temp                      NUMBER;
        l_num_pallets_temp          NUMBER;
    BEGIN
        pl_text_log.ins_msg_async('INFO', l_func_name, 'starting lmgfl_drp_flr_res_with_qoh...', sqlcode, sqlerrm);
        l_num_pallets_temp := i_num_pallets;
        l_putaway_batch := substr(i_pals(l_pindex).batch_no, 1, 2);
        IF l_putaway_batch = 'FP' THEN
            l_temp := 1;
        ELSE
            l_temp := 0;
        END IF;

        pl_text_log.ins_msg_async('INFO', l_func_name, 'i_pals.pallet_id(l_num_pallets_temp)= '
                                            || i_pals(l_num_pallets_temp).pallet_id
                                            || ' l_num_pallets_temp= '
                                            || l_num_pallets_temp
                                            || '  i_e_rec.equip_id,= '
                                            || i_e_rec.equip_id
                                            || '  i_num_recs= '
                                            || i_num_recs
                                            || ' i_is_same_item= '
                                            || i_is_same_item, sqlcode, sqlerrm);

        l_pindex := l_num_pallets_temp;
        l_same_slot_drop := i_pals(l_pindex).multi_pallet_drop_to_slot;
		  /*
    **  Same slot drops were processed by this function on first pallet dropped
    **  to the slot.
    */
        IF ( l_same_slot_drop = 'Y' ) THEN
            RETURN 1;
        END IF;
        l_pallets_in_slot := i_num_recs;
        l_pallet_height := C_STD_PALLET_HEIGHT * l_pindex;
        l_pallets_in_stack := 1;
        l_spc := i_pals(l_pindex).spc;
        /*slot type is in 10th position in the argument passing from Input. Here l_slot_type_num_positions defined as 10 instead of slot type*/
        l_slot_type_num_positions := 10;
		/*
    ** Adjust the number of positions based on the min quantity.
    ** Note that this does not get used for anything when dealing with floor
    ** slots.
    */
        l_adj_num_positions := i_pals(l_pindex).min_qty_num_positions + l_slot_type_num_positions;
		/*
    ** Determine if the existing inventory in the slot needs to be removed.
    ** For putaways going to the same slot on a PO the inventory is removed
    ** when the first putaway is performed and put back after the last
    ** putaway is performed.  Pallets from previous puts on the same PO
    ** are not removed.
    */
        IF ( l_temp = 1 ) THEN
            l_ret_val := pl_lm_forklift.lmf_what_putaway_is_this(i_pals(l_pindex).pallet_id, l_drop_type, l_num_drops_completed, l_num_pending_putaways
            );

            l_pallets_to_move := l_pallets_in_slot - l_num_drops_completed;
            IF ( l_pallets_to_move < 0 ) THEN
                l_pallets_to_move := 0;
            END IF;
            IF ( ( l_drop_type = C_ONLY_PUTAWAY_TO_SLOT OR l_drop_type = C_FIRST_PUTAWAY_TO_SLOT ) AND l_pallets_to_move > 0 ) THEN
                l_remove_existing_inv := TRUE;
                l_existing_inv := C_IN_SLOT;
            ELSE
                l_remove_existing_inv := FALSE;
                l_existing_inv := C_IN_AISLE;
            END IF;

            IF ( ( l_drop_type = C_ONLY_PUTAWAY_TO_SLOT OR l_drop_type = C_LAST_PUTAWAY_TO_SLOT ) AND l_pallets_to_move > 0 ) THEN
                l_putback_existing_inv := TRUE;
            ELSE
                l_putback_existing_inv := FALSE;
            END IF;
/*
        ** Calculate the number of pallets that will be in the slot after
        ** all the putaways on the PO are completed.
        */
            FOR i IN REVERSE 1..l_pindex LOOP IF ( i_pals(i).multi_pallet_drop_to_slot = 'Y' ) THEN
                l_total_pallets_in_slot := l_total_pallets_in_slot + 1;
            END IF;
            END LOOP;

            l_total_pallets_in_slot := l_total_pallets_in_slot + l_num_pending_putaways + l_pallets_in_slot + 1;
        ELSE
            l_drop_type := C_NON_PUTAWAY;
            l_pallets_to_move := l_pallets_in_slot;
            l_num_drops_completed := 0;
            l_remove_existing_inv := TRUE;
            l_putback_existing_inv := TRUE;
        END IF; /* End of l_temp = 1 */
/*
    **  Previous pallets putaway to the slot that are on the same PO as the
    **  current pallet are not removed from the slot.
    */
        l_pallet_count := l_pallets_to_move;
        IF ( g_forklift_audit = C_TRUE ) THEN
            pl_text_log.ins_msg_async('INFO', l_func_name, 'Drop pallet '
                                                || i_pals(l_pindex).pallet_id
                                                || ' containing '
                                                || i_pals(l_pindex).qty_on_pallet / l_spc
                                                || ' cases to '
                                                || i_pals(l_pindex).slot_type
                                                || ' reserve floor slot '
                                                || i_pals(l_pindex).dest_loc
                                                || ' containing pallet(s) '
                                                || l_pallets_in_slot, sqlcode, sqlerrm);

            IF ( l_num_drops_completed > 0 ) THEN
                l_message := 'pallet(s) on the PO been putaway to this slot. Will not be removed FOR rotation';
                pl_lm_goaltime.lmg_audit_cmt(pl_lm_goaltime.g_audit_batch_no, l_message, -1);
            END IF;

        END IF;
/*
    **  Put travel stack down if there is more than one pallet in the travel
    **  stack or if the existing pallets in the slot need to be removed.
    */
        IF ( l_num_pallets_temp > 1 OR l_remove_existing_inv != FALSE ) THEN
            o_drop := i_e_rec.ppof;
            IF ( g_forklift_audit = C_TRUE ) THEN
                IF ( l_num_pallets_temp > 1 AND l_existing_inv = C_IN_AISLE AND l_pallets_in_slot > 0 ) THEN
                    l_message := 'The existing inventory stacked in the aisle on a previous drop.  Put stack down because there is more than one pallet in the stack. pallets total= '
                    || l_num_pallets_temp;
                ELSE
                    l_message := 'Put stack down.Pallet(s) '
                                 || l_num_pallets_temp
                                 || ' in the stack';
                    pl_lm_goaltime.lmg_audit_movement('PPOF', pl_lm_goaltime.g_audit_batch_no, i_e_rec, 1, l_message);
                END IF;

            END IF;

        END IF;
/*
    **  Remove the pallets from the slot if existing inventory is to
    **  be removed and there are pallets to remove.
    */
        IF ( l_remove_existing_inv != FALSE AND l_pallets_to_move > 0 ) THEN
            IF ( g_forklift_audit = C_TRUE ) THEN
                l_message := 'Remove the existing pallet(s) '
                             || l_pallets_to_move
                             || ' from the slot.';
                pl_lm_goaltime.lmg_audit_cmt(pl_lm_goaltime.g_audit_batch_no, l_message, -1);
            END IF;

            lmgfl_rem_plts_frm_flr_slot(i_pals(l_pindex).dest_loc, i_e_rec, l_pallets_to_move, l_slot_type_num_positions

            , C_FALSE, l_pallets_in_stack, o_drop);

        END IF;

        IF ( g_forklift_audit = C_TRUE AND l_remove_existing_inv = FALSE AND l_pallets_to_move > 0 ) THEN
		/*
        ** There are pallets to remove and the flag set to not remove
        ** existing inv move which means the pallets were removed on a
        ** previous putaway.
        */
            l_message := 'The existing pallet(s) '
                         || l_pallets_to_move
                         || ' removed from the slot on a previous putaway.';
            pl_lm_goaltime.lmg_audit_cmt(pl_lm_goaltime.g_audit_batch_no, l_message, -1);
        END IF;
/*
    **  The existing pallets in the slot have been removed if they were not
    **  removed on a previous putaway on the same PO.
    **  Drop the new pallet into the slot.
    */

        l_pallet_height := C_STD_PALLET_HEIGHT * l_pindex;
		/*
    **  Drop the new pallet into the slot.
    **
    **  If the existing pallets in the slot were removed for this drop then
    **  the forks will be at the level of the last pallet removed otherwise
    **  the forks will be at the floor.  Set l_start_height to the height
    **  of the forks.
    */
        IF ( l_remove_existing_inv != FALSE AND l_pallets_to_move > 0 ) THEN
            IF ( l_pallets_in_stack = 0 ) THEN
                l_start_height := 0;
            ELSE
                l_start_height := C_STD_PALLET_HEIGHT * ( l_pallets_in_stack - 1 );
            END IF;
        ELSE
            l_start_height := 0;
        END IF;
/*
    ** Determine the height of the stack in the slot the new pallet
    ** will be placed on.
    */
        l_floor_slot_stack_height := lmgfl_floor_slot_stack_height(l_slot_type_num_positions, l_total_pallets_in_slot, l_num_drops_completed

        );
        IF ( l_num_pallets_temp > 1 ) THEN
		/*
        **  There is more than one pallet in the travel stack.  The needed
        **  pallet will be on the top of the travel stack.  Take the pallet
        **  off the travel stack and place it in the floor slot.
        */
            o_drop := nvl(o_drop, 0) + i_e_rec.bp + i_e_rec.apos;
            IF ( g_forklift_audit = C_TRUE ) THEN
                l_message := 'Put pallet '
                             || i_pals(l_pindex).pallet_id
                             || ' in slot '
                             || i_pals(l_pindex).dest_loc;

                pl_lm_goaltime.lmg_audit_movement('BP', pl_lm_goaltime.g_audit_batch_no, i_e_rec, 1, l_message);
                pl_lm_goaltime.lmg_audit_movement('APOS', pl_lm_goaltime.g_audit_batch_no, i_e_rec, 1, '');
            END IF;
/*
        **  Must move fork from last known position to top of last stack to
        **  height of the new pallet in the travel pallet stack.
        */
            IF ( l_pallet_height > l_start_height ) THEN
                o_drop := nvl(o_drop, 0) + ( ( ( l_pallet_height - l_start_height ) / 12.0 ) * i_e_rec.re );
            ELSE
                o_drop := nvl(o_drop, 0) + ( ( ( l_start_height - l_pallet_height ) / 12.0 ) * i_e_rec.le );
            END IF;

        /*
        ** Take the pallet off the travel stack.
        */
            o_drop := nvl(o_drop, 0) + i_e_rec.mepos + i_e_rec.bt90;
            IF ( g_forklift_audit = C_TRUE ) THEN
                IF ( l_pallet_height > l_start_height ) THEN
                    pl_lm_goaltime.lmg_audit_movement('RE', pl_lm_goaltime.g_audit_batch_no, i_e_rec, l_pallet_height - l_start_height
                    , '');
                ELSE
                    pl_lm_goaltime.lmg_audit_movement('LE', pl_lm_goaltime.g_audit_batch_no, i_e_rec, l_start_height - l_pallet_height
                    , '');
                END IF;

                pl_lm_goaltime.lmg_audit_movement('MEPOS', pl_lm_goaltime.g_audit_batch_no, i_e_rec, 1, '');
                pl_lm_goaltime.lmg_audit_movement('BT90', pl_lm_goaltime.g_audit_batch_no, i_e_rec, 1, '');
            END IF;
/*
        ** Place the pallet in the floor slot.
        */
            lmgfl_place_pallet_in_flr_slt(l_floor_slot_stack_height, l_pallet_height, i_e_rec, o_drop);
        ELSE
		/*
        **  There is one pallet in the travel stack.
        */
            IF ( l_existing_inv != C_IN_AISLE ) THEN
			/*
            ** The existing inventory in the slot has been removed for this
            ** drop.  Prepare to pickup the pallet in the travel stack.
            */
                o_drop := nvl(o_drop, 0) + i_e_rec.bp + i_e_rec.apof;
                IF ( g_forklift_audit = C_TRUE ) THEN
                    l_message := 'The existing inventory in slot has been removed. Pickup pallet in stack and put in slot.';
                    pl_lm_goaltime.lmg_audit_movement('BP', pl_lm_goaltime.g_audit_batch_no, i_e_rec, 1, l_message);
                    pl_lm_goaltime.lmg_audit_movement('APOF', pl_lm_goaltime.g_audit_batch_no, i_e_rec, 1, '');
                END IF;

            END IF;
/*
        **  Drop new pallet into slot.
        **  If the existing inventory in the slot was removed for this drop
        **  then the forks are at the height of the last pallet removed from
        **  the slot otherwise the pallet to drop is on the forks.
        */
            IF ( l_remove_existing_inv != FALSE ) THEN
                o_drop := nvl(o_drop, 0) + ( ( l_start_height / 12.0 ) * i_e_rec.le ) + i_e_rec.mepof + i_e_rec.bt90;

                IF ( g_forklift_audit = C_TRUE ) THEN
                    pl_lm_goaltime.lmg_audit_movement('LE', pl_lm_goaltime.g_audit_batch_no, i_e_rec, l_start_height, '');
                    pl_lm_goaltime.lmg_audit_movement('MEPOF', pl_lm_goaltime.g_audit_batch_no, i_e_rec, 1, '');
                    pl_lm_goaltime.lmg_audit_movement('BT90', pl_lm_goaltime.g_audit_batch_no, i_e_rec, 1, '');
                END IF;

                l_pallet_height := 0;
                lmgfl_place_pallet_in_flr_slt(l_floor_slot_stack_height, l_pallet_height, i_e_rec, o_drop);
            ELSE
			/*
            ** Pallets removed from the slot on a previous putaway.  Put the
            ** pallet on the forks into the slot.
            **
            ** If there are other pallets on the same PO that have been
            ** putaway to the slot then the new pallet is stacked on top
            ** of these pallets.
            */
                o_drop := nvl(o_drop, 0) + i_e_rec.tir;
                IF ( g_forklift_audit = C_TRUE ) THEN
                    pl_lm_goaltime.lmg_audit_movement('TIR', pl_lm_goaltime.g_audit_batch_no, i_e_rec, 1, '');
                END IF;

                l_pallet_height := 0;
				/* The drop pallet is at the floor. */

            /*
            ** Place the pallet in the floor slot.
            */
                lmgfl_place_pallet_in_flr_slt(l_floor_slot_stack_height, l_pallet_height, i_e_rec, o_drop);
            END IF;

        END IF; /*End of l_num_pallets_temp > 1 IF */

        l_num_pallets_temp := l_num_pallets_temp - 1;
        l_num_drops_completed := l_num_drops_completed + 1; /* Indicate a drop completed. */
        FOR i IN REVERSE 1..l_pindex  LOOP
            l_pallet_height := C_STD_PALLET_HEIGHT * i;
            IF ( i_pals(i).multi_pallet_drop_to_slot = 'Y' ) THEN
                IF ( g_forklift_audit = C_TRUE ) THEN
                    l_message := 'Put pallet '
                                 || i_pals(i).pallet_id
                                 || ' in slot '
                                 || i_pals(i).dest_loc;

                    pl_lm_goaltime.lmg_audit_cmt(pl_lm_goaltime.g_audit_batch_no, l_message, -1);
                END IF;

                IF ( i = 0 ) THEN
                    o_drop := nvl(o_drop, 0) + i_e_rec.apof + ( ( l_floor_slot_stack_height / 12.0 ) * i_e_rec.le ) + i_e_rec.mepof
                    + i_e_rec.bt90;
/*
            **  There next pallet in the stack is going to the same slot.
            **  Put the pallet in the slot.
            */
                    IF ( g_forklift_audit = C_TRUE ) THEN
                        pl_lm_goaltime.lmg_audit_movement('APOF', pl_lm_goaltime.g_audit_batch_no, i_e_rec, 1, '');
                        pl_lm_goaltime.lmg_audit_movement('LE', pl_lm_goaltime.g_audit_batch_no, i_e_rec, l_floor_slot_stack_height
                        , '');
                        pl_lm_goaltime.lmg_audit_movement('MEPOF', pl_lm_goaltime.g_audit_batch_no, i_e_rec, 1, '');
                        pl_lm_goaltime.lmg_audit_movement('BT90', pl_lm_goaltime.g_audit_batch_no, i_e_rec, 1, '');
                    END IF;

                ELSE
				/*
                **  This is not the last pallet in the stack.  Get the pallet
                **  off the travel stack.
                */
                    o_drop := nvl(o_drop, 0) + i_e_rec.apos;
                    IF ( l_pallet_height > l_floor_slot_stack_height ) THEN
                        o_drop := nvl(o_drop, 0) + ( ( ( l_pallet_height - l_floor_slot_stack_height ) / 12.0 ) * i_e_rec.re );

                    ELSE
                        o_drop := nvl(o_drop, 0) + ( ( ( l_floor_slot_stack_height - l_pallet_height ) / 12.0 ) * i_e_rec.le );
                    END IF;

                    o_drop := nvl(o_drop, 0) + i_e_rec.mepos + i_e_rec.bt90;
                    IF ( g_forklift_audit = C_TRUE ) THEN
                        pl_lm_goaltime.lmg_audit_movement('APOS', pl_lm_goaltime.g_audit_batch_no, i_e_rec, 1, '');
                        IF ( l_pallet_height > l_floor_slot_stack_height ) THEN
                            pl_lm_goaltime.lmg_audit_movement('RE', pl_lm_goaltime.g_audit_batch_no, i_e_rec, l_pallet_height - l_floor_slot_stack_height
                            , '');

                        ELSE
                            pl_lm_goaltime.lmg_audit_movement('LE', pl_lm_goaltime.g_audit_batch_no, i_e_rec, l_floor_slot_stack_height
                            - l_pallet_height, '');
                        END IF;

                        pl_lm_goaltime.lmg_audit_movement('MEPOS', pl_lm_goaltime.g_audit_batch_no, i_e_rec, 1, '');
                        pl_lm_goaltime.lmg_audit_movement('BT90', pl_lm_goaltime.g_audit_batch_no, i_e_rec, 1, '');
                    END IF;

                END IF;
/*
            ** Determine the height of the stack in the slot the new pallet
            ** will be placed on.
            */
                l_floor_slot_stack_height := lmgfl_floor_slot_stack_height(l_slot_type_num_positions, l_total_pallets_in_slot, l_num_drops_completed

                );
				/*
            ** Place the pallet in the floor slot.
            */
                lmgfl_place_pallet_in_flr_slt(l_floor_slot_stack_height, l_pallet_height, i_e_rec, o_drop);
                l_num_pallets_temp := l_num_pallets_temp - 1;
                l_num_drops_completed := l_num_drops_completed + 1;
            END IF; /* End of multi_pallet_drop_to_slot = 'Y' IF */

        END LOOP;
    /*
    **  Put back the existing inventory pallets that were removed if
    **  appropriate.
    **  For non putaway drops the pallets are always put back into the slot.
    **  For putaways the pallets are put back if this is the only putaway
    **  or the last putaway to the slot on the PO.
    */
        IF ( l_putback_existing_inv != FALSE ) THEN
            lmgfl_putbk_plts_in_flr_slot(i_pals(l_pindex).dest_loc, l_total_pallets_in_slot, l_pallets_to_move, l_slot_type_num_positions
            , C_FALSE, l_floor_slot_stack_height, i_e_rec, o_drop);
        ELSE
            o_drop := nvl(o_drop, 0) + ( ( l_floor_slot_stack_height / 12.0 ) * i_e_rec.le );

            IF ( g_forklift_audit = C_TRUE ) THEN
                pl_lm_goaltime.lmg_audit_movement('LE', pl_lm_goaltime.g_audit_batch_no, i_e_rec, l_floor_slot_stack_height, '');
            END IF;

        END IF;
/*
    ** Pickup stack if there are pallets left and go to the
    ** next destination.
    */
        IF ( l_num_pallets_temp > 0 ) THEN
            pl_lm_goaltime.lmg_pickup_for_next_dst(i_pals, i_num_pallets - 1, i_e_rec, o_drop);
        END IF;

        RETURN 0;
    END lmgfl_drp_flr_res_with_qoh;

/*****************************************************************************
**  FUNCTION:
**      lmgfl_pickup_from_floor_res()
**
**  DESCRIPTION:
**      This function calculates the LM drop discreet value FOR a pallet
**      picked from a reserve floor location.
**      There should only be one level FOR these locations.
**      FOR dIFferent items in the slot, assume that the needed pallet is
**      last.
**
**  PARAMETERS:
**      i_pals         - Pointer to pallet list.
**      i_pindex       - i of pallet being processed.
**      i_e_rec        - Pointer to equipment tmu values.
**      i_inv          - Pointer to pallets already in the destination.
**      i_is_dIFf_item - Flag denoting IF their are dIFferent items in the slot.
        i_num_recs    - number of records.
**      o_pickup       - Outgoing pickup value.
**
**  RETURN VALUES:
**      Returns 0
**  MODIFICATION HISTORY:                                                       **
**      DATE          USER              COMMENT                                 **
**   02/17/2020      Infosys           Initial version0.0                       **  
*****************************************************************************/

    FUNCTION lmgfl_pickup_from_floor_res (
        i_pals           IN               pl_lm_goal_pb.tbl_lmg_pallet_rec,
        i_pindex         IN               NUMBER,
        i_e_rec          IN               pl_lm_goal_pb.type_lmc_equip_rec,
        i_inv            IN               pl_lm_goal_pb.tbl_lmg_inv_rec,
        i_is_diff_item   IN               VARCHAR2,
        i_num_recs       IN               NUMBER,
        o_pickup         OUT              NUMBER
    ) RETURN NUMBER AS

        l_func_name            VARCHAR2(50) := 'pl_lm_goal_fl.lmgfl_pickup_from_floor_res';
        l_message              VARCHAR2(1024);
        l_pallet_count         NUMBER := 0;
        l_pallets_in_slot      NUMBER := 0;
        l_slot_pallet_stack    NUMBER := 0;
        l_aisle_pallet_stack   NUMBER := 0;
        l_slot_height          NUMBER := 0;
        l_stack_height         NUMBER := 0;
    BEGIN
      
        pl_text_log.ins_msg_async('INFO', l_func_name, 'starting lmgfl_pickup_from_floor_res.. i_pals.batch_no(i_pindex) ='
                                            || i_pals(i_pindex).batch_no
                                            || ' i_pindex= '
                                            || i_pindex
                                            || '  i_e_rec.equip_id = '
                                            || i_e_rec.equip_id
                                            || ' i_is_dIFf_item= '
                                            || i_is_diff_item, sqlcode, sqlerrm);

        IF ( g_forklift_audit = C_TRUE ) THEN
            l_message := 'Pickup pallet '
                         || i_pals(i_pindex).pallet_id
                         || ' containing '
                         || i_pals(i_pindex).qty_on_pallet / i_pals(i_pindex).spc
                         || ' cases from '
                         || i_pals(i_pindex).slot_type
                         || ' reserve floor slot '
                         || i_pals(i_pindex).dest_loc;

            pl_lm_goaltime.lmg_audit_cmt(pl_lm_goaltime.g_audit_batch_no, l_message, -1);
        END IF;

        IF ( i_pindex = 0 ) THEN
            o_pickup := nvl(o_pickup, 0) + i_e_rec.tir;
        ELSE
            o_pickup := nvl(o_pickup, 0) + i_e_rec.bt90;
        END IF;

        IF ( g_forklift_audit = C_TRUE ) THEN
            IF ( i_pindex = 0 ) THEN
                pl_lm_goaltime.lmg_audit_movement('TIR', pl_lm_goaltime.g_audit_batch_no, i_e_rec, 1, '');
            ELSE
                pl_lm_goaltime.lmg_audit_movement('BT90', pl_lm_goaltime.g_audit_batch_no, i_e_rec, 1, '');
            END IF;
        END IF;

        IF ( i_pals(i_pindex).multi_pallet_drop_to_slot = 'N' ) THEN
            IF ( i_is_diff_item = 'Y' ) THEN
                l_pallets_in_slot := i_num_recs + ( i_num_recs - i_pindex );
				/*
            **  Remove all pallets from slot including the pallet needed.
            */
                IF ( g_forklift_audit = C_TRUE ) THEN
                    pl_lm_goaltime.lmg_audit_cmt(pl_lm_goaltime.g_audit_batch_no, 'Remove all pallets from slot including pallet needed.'
                    , -1);
                END IF;

                l_pallet_count := l_pallets_in_slot;
                IF ( MOD(l_pallet_count, C_MAX_PALS_PER_STACK) != 0 ) THEN
                    l_slot_pallet_stack := MOD(l_pallet_count, C_MAX_PALS_PER_STACK);
                ELSE
                    l_slot_pallet_stack := C_MAX_PALS_PER_STACK;
                END IF;

                l_aisle_pallet_stack := 0;
                WHILE ( l_pallet_count > ( i_num_recs - i_pindex ) ) LOOP
                    IF ( l_slot_pallet_stack > 0 ) THEN
                        l_slot_height := ( l_slot_pallet_stack - 1 ) * C_STD_PALLET_HEIGHT;
                    ELSE
                        l_slot_height := 0;
                    END IF;
					/*
					**  Raise to pallet on top of slot stack.
					*/

                    IF ( l_slot_height > l_stack_height ) THEN
                        o_pickup := nvl(o_pickup, 0) + ( ( ( l_slot_height - l_stack_height ) / 12.0 ) * i_e_rec.re );

                    ELSE
                        o_pickup := nvl(o_pickup, 0) + ( ( ( l_stack_height - l_slot_height ) / 12.0 ) * i_e_rec.le );
                    END IF; 
					/*
					**  Get pallet from slot.
					*/

                    IF ( l_slot_height = 0 ) THEN
                        o_pickup := nvl(o_pickup, 0) + i_e_rec.apof + i_e_rec.mepof;
                    ELSE
                        o_pickup := nvl(o_pickup, 0) + i_e_rec.apos + i_e_rec.mepos;
                    END IF;

                    IF ( g_forklift_audit = C_TRUE ) THEN
                        l_message := 'Get pallet from slot.';
                        IF ( l_slot_height > l_stack_height ) THEN
                            pl_lm_goaltime.lmg_audit_movement('RE', pl_lm_goaltime.g_audit_batch_no, i_e_rec,(l_slot_height - l_stack_height
                            ), l_message);

                        ELSE
                            pl_lm_goaltime.lmg_audit_movement('LE', pl_lm_goaltime.g_audit_batch_no, i_e_rec,(l_stack_height - l_slot_height
                            ), l_message);
                        END IF;

                        IF ( l_slot_height = 0 ) THEN
                            pl_lm_goaltime.lmg_audit_movement('APOF', pl_lm_goaltime.g_audit_batch_no, i_e_rec, 1, '');
                            pl_lm_goaltime.lmg_audit_movement('MEPOF', pl_lm_goaltime.g_audit_batch_no, i_e_rec, 1, '');
                        ELSE
                            pl_lm_goaltime.lmg_audit_movement('APOS', pl_lm_goaltime.g_audit_batch_no, i_e_rec, 1, '');
                            pl_lm_goaltime.lmg_audit_movement('MEPOS', pl_lm_goaltime.g_audit_batch_no, i_e_rec, 1, '');
                        END IF;

                    END IF;
       /*
                **  Put pallet on stack in aisle.
                */
                    o_pickup := nvl(o_pickup, 0) + i_e_rec.bt90;
                    IF ( g_forklift_audit = C_TRUE ) THEN
                        pl_lm_goaltime.lmg_audit_movement('BT90', pl_lm_goaltime.g_audit_batch_no, i_e_rec, 1, 'Put pallet on stack in aisle.'
                        );
                    END IF;

                    l_slot_pallet_stack := l_slot_pallet_stack - 1;
                    IF ( l_slot_pallet_stack < 1 ) THEN
                        l_slot_pallet_stack := C_MAX_PALS_PER_STACK;
                    END IF;
                    l_stack_height := l_aisle_pallet_stack * C_STD_PALLET_HEIGHT;
                    IF ( l_stack_height > l_slot_height ) THEN
                        o_pickup := nvl(o_pickup, 0) + ( ( ( l_stack_height - l_slot_height ) / 12.0 ) * i_e_rec.rl );
                    ELSE
                        o_pickup := nvl(o_pickup, 0) + ( ( ( l_slot_height - l_stack_height ) / 12.0 ) * i_e_rec.ll );
                    END IF;

                    IF ( l_stack_height = 0 ) THEN
                        o_pickup := nvl(o_pickup, 0) + i_e_rec.ppof;
                    ELSE
                        o_pickup := nvl(o_pickup, 0) + i_e_rec.ppos;
                    END IF;

                    o_pickup := nvl(o_pickup, 0) + i_e_rec.bt90;
                    IF ( g_forklift_audit = C_TRUE ) THEN
                        IF ( l_stack_height > l_slot_height ) THEN
                            pl_lm_goaltime.lmg_audit_movement('RL', pl_lm_goaltime.g_audit_batch_no, i_e_rec,(l_stack_height - l_slot_height
                            ), l_message);
                        ELSE
                            pl_lm_goaltime.lmg_audit_movement('LL', pl_lm_goaltime.g_audit_batch_no, i_e_rec,(l_slot_height - l_stack_height
                            ), l_message);
                        END IF;

                        IF ( l_stack_height = 0 ) THEN
                            pl_lm_goaltime.lmg_audit_movement('PPOF', pl_lm_goaltime.g_audit_batch_no, i_e_rec, 1, '');
                        ELSE
                            pl_lm_goaltime.lmg_audit_movement('PPOS', pl_lm_goaltime.g_audit_batch_no, i_e_rec, 1, '');
                        END IF;

                        pl_lm_goaltime.lmg_audit_movement('BT90', pl_lm_goaltime.g_audit_batch_no, i_e_rec, 1, '');
                    END IF;

                    IF ( l_aisle_pallet_stack = C_MAX_PALS_PER_STACK ) THEN
                        l_aisle_pallet_stack := 0;
                    ELSE
                        l_aisle_pallet_stack := l_aisle_pallet_stack + 1;
                    END IF;

                    l_pallet_count := l_pallet_count - 1;
                END LOOP;

            END IF; /* END of i_is_diff_item = 'Y' IF */
        END IF; /* END of multi_pallet_drop_to_slot = 'N' IF */
		/*
		**  IF same item pull top item from stack.
		**  IF multi pallet pickup from same slot, then pull pallet from 
		**  needed pallet stack.  Unneeded pallets have already been removed.
		*/

        IF ( i_is_diff_item = 'N' ) THEN
            l_pallet_count := l_pallet_count + i_num_recs + ( i_num_recs - i_pindex );
            l_slot_pallet_stack := l_pallet_count;
            WHILE ( l_slot_pallet_stack > C_MAX_PALS_PER_STACK ) 
			LOOP l_slot_pallet_stack := l_slot_pallet_stack - C_MAX_PALS_PER_STACK;
            END LOOP;
            IF ( l_slot_pallet_stack = 0 ) THEN
                l_slot_height := 0;
            ELSE
                l_slot_height := C_STD_PALLET_HEIGHT * ( l_slot_pallet_stack - 1 );
            END IF;

        ELSE
            l_pallet_count := ( i_num_recs - i_pindex );
            l_slot_height := C_STD_PALLET_HEIGHT * ( l_pallet_count - 1 );
        END IF;

        IF ( i_pals(i_pindex).multi_pallet_drop_to_slot = 'Y' ) THEN
            l_stack_height := C_STD_PALLET_HEIGHT * ( i_pindex - 1 );
        END IF;
/*
    **  Move the forks from the last stacked pallet to the needed pallet
    **  in the slot.
    */
        IF ( l_slot_height > l_stack_height ) THEN
            o_pickup := nvl(o_pickup, 0) + ( ( ( l_slot_height - l_stack_height ) / 12.0 ) * i_e_rec.re );
        ELSE
            o_pickup := nvl(o_pickup, 0) + ( ( ( l_stack_height - l_slot_height ) / 12.0 ) * i_e_rec.le );
        END IF;

        o_pickup := nvl(o_pickup, 0) + i_e_rec.apos + i_e_rec.mepos + i_e_rec.bt90;

        IF ( g_forklift_audit = C_TRUE ) THEN
            l_message := 'Move the FORks from the last stacked pallet to the needed pallet in the slot';
            IF ( l_slot_height > l_stack_height ) THEN
                pl_lm_goaltime.lmg_audit_movement('RE', pl_lm_goaltime.g_audit_batch_no, i_e_rec, l_slot_height - l_stack_height,
                l_message);

            ELSE
                pl_lm_goaltime.lmg_audit_movement('LE', pl_lm_goaltime.g_audit_batch_no, i_e_rec, l_stack_height - l_slot_height,
                l_message);
            END IF;

            pl_lm_goaltime.lmg_audit_movement('APOS', pl_lm_goaltime.g_audit_batch_no, i_e_rec, 1, '');
            pl_lm_goaltime.lmg_audit_movement('MEPOS', pl_lm_goaltime.g_audit_batch_no, i_e_rec, 1, '');
            pl_lm_goaltime.lmg_audit_movement('BT90', pl_lm_goaltime.g_audit_batch_no, i_e_rec, 1, '');
        END IF;

        l_stack_height := ( C_STD_PALLET_HEIGHT * i_pindex );
        IF ( l_stack_height > l_slot_height ) THEN
            o_pickup := nvl(o_pickup, 0) + ( ( ( l_stack_height - l_slot_height ) / 12.0 ) * i_e_rec.rl );

            IF ( g_forklift_audit = C_TRUE ) THEN
                pl_lm_goaltime.lmg_audit_movement('RL', pl_lm_goaltime.g_audit_batch_no, i_e_rec,(l_stack_height - l_slot_height)
                , '');

            END IF;

        ELSE
            o_pickup := nvl(o_pickup, 0) + ( ( ( l_slot_height - l_stack_height ) / 12.0 ) * i_e_rec.ll );

            IF ( g_forklift_audit = C_TRUE ) THEN
                pl_lm_goaltime.lmg_audit_movement('LL', pl_lm_goaltime.g_audit_batch_no, i_e_rec,(l_slot_height - l_stack_height)
                , '');

            END IF;

        END IF;

        IF ( i_pindex > 0 ) THEN
            o_pickup := nvl(o_pickup, 0) + i_e_rec.ppos;
            IF ( g_forklift_audit = C_TRUE ) THEN
                pl_lm_goaltime.lmg_audit_movement('PPOS', pl_lm_goaltime.g_audit_batch_no, i_e_rec, 1, '');
                IF ( ( i_pindex = ( i_num_recs - 1 ) ) AND ( i_is_diff_item = 'N' ) ) THEN
                    o_pickup := nvl(o_pickup, 0) + ( ( l_stack_height / 12.0 ) * i_e_rec.le ) + i_e_rec.bp + i_e_rec.apof + i_e_rec
                    .mepof;

                    IF ( g_forklift_audit = C_TRUE ) THEN
                        pl_lm_goaltime.lmg_audit_movement('LE', pl_lm_goaltime.g_audit_batch_no, i_e_rec, l_stack_height, '');
                        pl_lm_goaltime.lmg_audit_movement('BP', pl_lm_goaltime.g_audit_batch_no, i_e_rec, 1, '');
                        pl_lm_goaltime.lmg_audit_movement('APOF', pl_lm_goaltime.g_audit_batch_no, i_e_rec, 1, '');
                        pl_lm_goaltime.lmg_audit_movement('MEPOF', pl_lm_goaltime.g_audit_batch_no, i_e_rec, 1, '');
                    END IF;

                END IF;

            END IF;

        ELSIF ( ( i_num_recs > 1 ) OR ( i_is_diff_item = 'Y' ) ) THEN
            o_pickup := nvl(o_pickup, 0) + i_e_rec.ppof;
            IF ( g_forklift_audit = C_TRUE ) THEN
                pl_lm_goaltime.lmg_audit_movement('PPOF', pl_lm_goaltime.g_audit_batch_no, i_e_rec, 1, '');
            END IF;

        END IF;

        IF ( i_pals(i_pindex).multi_pallet_drop_to_slot = 'N' ) THEN
            IF ( i_is_diff_item = 'Y' ) THEN
                o_pickup := nvl(o_pickup, 0) + i_e_rec.bp;
                IF ( g_forklift_audit = C_TRUE ) THEN
                    pl_lm_goaltime.lmg_audit_movement('BP', pl_lm_goaltime.g_audit_batch_no, i_e_rec, 1, 'Put pallets back in slot.'
                    );
                END IF;

                l_pallets_in_slot := i_num_recs;
				/*
            **  Replace remaining pallets into slot.  These are the pallets
            **  removed from the slot and placed in stacks in the aisle.
            */
                l_pallet_count := l_pallets_in_slot;
                IF ( MOD(l_pallet_count, C_MAX_PALS_PER_STACK) != 0 ) THEN
                    l_aisle_pallet_stack := MOD(l_pallet_count, C_MAX_PALS_PER_STACK);
                ELSE
                    l_aisle_pallet_stack := C_MAX_PALS_PER_STACK;
                END IF;
/*
            **  The slot is empty but the height is set to the value from the
            **  last needed pallet placement on the outgoing stack.
            */
                l_slot_pallet_stack := 0;
                l_slot_height := C_STD_PALLET_HEIGHT * ( i_num_recs - 1 );
                WHILE ( l_pallet_count <> 0 ) LOOP
                    IF ( l_aisle_pallet_stack > 0 ) THEN
                        l_stack_height := ( l_aisle_pallet_stack - 1 ) * C_STD_PALLET_HEIGHT;
                    ELSE
                        l_stack_height := 0;
                    END IF;
/*
                **  Raise to pallet on top of aisle stack.
                */
                    IF ( l_stack_height > l_slot_height ) THEN
                        o_pickup := nvl(o_pickup, 0) + ( ( ( l_stack_height - l_slot_height ) / 12.0 ) * i_e_rec.re );

                    ELSE
                        o_pickup := nvl(o_pickup, 0) + ( ( ( l_slot_height - l_stack_height ) / 12.0 ) * i_e_rec.le );
                    END IF;
  /*
                **  Get pallet from aisle stack.
                */
                    IF ( l_stack_height = 0 ) THEN
                        o_pickup := nvl(o_pickup, 0) + i_e_rec.apof + i_e_rec.mepof;
                    ELSE
                        o_pickup := nvl(o_pickup, 0) + i_e_rec.apos + i_e_rec.mepos;
                    END IF;

                    o_pickup := nvl(o_pickup, 0) + i_e_rec.bt90;
                    IF ( g_forklift_audit = C_TRUE ) THEN
                        IF ( l_stack_height > l_slot_height ) THEN
                            pl_lm_goaltime.lmg_audit_movement('RE', pl_lm_goaltime.g_audit_batch_no, i_e_rec,(l_stack_height - l_slot_height
                            ), '');
                        ELSE
                            pl_lm_goaltime.lmg_audit_movement('LE', pl_lm_goaltime.g_audit_batch_no, i_e_rec,(l_slot_height - l_stack_height
                            ), '');
                        END IF;

                        IF ( l_stack_height = 0 ) THEN
                            pl_lm_goaltime.lmg_audit_movement('APOF', pl_lm_goaltime.g_audit_batch_no, i_e_rec, 1, '');
                            pl_lm_goaltime.lmg_audit_movement('MEPOF', pl_lm_goaltime.g_audit_batch_no, i_e_rec, 1, '');
                        ELSE
                            pl_lm_goaltime.lmg_audit_movement('APOS', pl_lm_goaltime.g_audit_batch_no, i_e_rec, 1, '');
                            pl_lm_goaltime.lmg_audit_movement('MEPOS', pl_lm_goaltime.g_audit_batch_no, i_e_rec, 1, '');
                        END IF;

                        pl_lm_goaltime.lmg_audit_movement('BT90', pl_lm_goaltime.g_audit_batch_no, i_e_rec, 1, '');
                    END IF;
/*
                **  Have pallet on the forks.  Put it in the slot.
                */
                    l_aisle_pallet_stack := l_aisle_pallet_stack - 1;
                    IF ( l_aisle_pallet_stack < 1 ) THEN
                        l_aisle_pallet_stack := C_MAX_PALS_PER_STACK;
                    END IF;
                    l_slot_height := l_slot_pallet_stack * C_STD_PALLET_HEIGHT;
                    IF ( l_slot_height > l_stack_height ) THEN
                        o_pickup := nvl(o_pickup, 0) + ( ( ( l_slot_height - l_stack_height ) / 12.0 ) * i_e_rec.rl );
                    ELSE
                        o_pickup := nvl(o_pickup, 0) + ( ( ( l_stack_height - l_slot_height ) / 120.0 ) * i_e_rec.ll );
                    END IF;

                    IF ( l_slot_height = 0 ) THEN
                        o_pickup := nvl(o_pickup, 0) + i_e_rec.ppof;
                    ELSE
                        o_pickup := nvl(o_pickup, 0) + i_e_rec.ppos;
                    END IF;

                    o_pickup := nvl(o_pickup, 0) + i_e_rec.bt90;
                    IF ( g_forklift_audit = C_TRUE ) THEN
                        IF ( l_slot_height > l_stack_height ) THEN
                            pl_lm_goaltime.lmg_audit_movement('RL', pl_lm_goaltime.g_audit_batch_no, i_e_rec,(l_slot_height - l_stack_height
                            ), '');
                        ELSE
                            pl_lm_goaltime.lmg_audit_movement('LL', pl_lm_goaltime.g_audit_batch_no, i_e_rec,(l_stack_height - l_slot_height
                            ), '');
                        END IF;

                        IF ( l_slot_height = 0 ) THEN
                            pl_lm_goaltime.lmg_audit_movement('PPOF', pl_lm_goaltime.g_audit_batch_no, i_e_rec, 1, '');
                        ELSE
                            pl_lm_goaltime.lmg_audit_movement('PPOS', pl_lm_goaltime.g_audit_batch_no, i_e_rec, 1, '');
                        END IF;

                        pl_lm_goaltime.lmg_audit_movement('BT90', pl_lm_goaltime.g_audit_batch_no, i_e_rec, 1, '');
                    END IF;

                    IF ( l_slot_pallet_stack = C_MAX_PALS_PER_STACK ) THEN
                        l_slot_pallet_stack := 0;
                    ELSE
                        l_slot_pallet_stack := l_slot_pallet_stack + 1;
                    END IF;

                    l_pallet_count := l_pallet_count - 1;
                END LOOP;

                o_pickup := nvl(o_pickup, 0) + ( ( l_slot_height / 12.0 ) * i_e_rec.le ) + i_e_rec.apof + i_e_rec.mepof;

                IF ( g_forklift_audit = C_TRUE ) THEN
                    pl_lm_goaltime.lmg_audit_movement('LE', pl_lm_goaltime.g_audit_batch_no, i_e_rec, l_slot_height, '');
                    pl_lm_goaltime.lmg_audit_movement('APOF', pl_lm_goaltime.g_audit_batch_no, i_e_rec, 1, '');
                    pl_lm_goaltime.lmg_audit_movement('MEPOF', pl_lm_goaltime.g_audit_batch_no, i_e_rec, 1, '');
                END IF;

            END IF; /* END of i_is_diff_item = 'Y' IF */
        END IF; /* END of multi_pallet_drop_to_slot = 'N' IF */

        RETURN 0;
    END lmgfl_pickup_from_floor_res;

/*****************************************************************************
**  FUNCTION:
**      lmgfl_rem_plts_frm_flr_slot()
**
**  DESCRIPTION:
**      This function removes the existing pallets in a floor slot
**      and stacks them in the aisle.  The pallets are stacked in the aisle
**      with no more than MAX_PALS_PER_STACK in a stack.  IF it is a home
**      slot then the pick pallet is placed by itself in the aisle.
**
**  PARAMETERS:
**      i_location              - Floor slot to remove the pallets from.
**      i_e_rec                 - Pointer to equipment tmu values.
**      i_num_pallets_to_remove - Number of pallets to remove from the slot.
**      i_num_positions         - Number of positions in the slot.
**      i_home_slot_bln         - Indicates IF the slot is a home slot.
**      o_pallets_in_stack      - Number of pallets in last stack in aisle.
**                                This determines the position of the FORks
**                                after the last pallet is removed from the
**                                slot.
**      o_drop                  - Outgoing drop value.
**
**  RETURN VALUES:
**      None.
**  MODIFICATION HISTORY:                                                       **
**      DATE          USER              COMMENT                                 **
**   02/17/2020      Infosys           Initial version0.0                       **  
*****************************************************************************/

    PROCEDURE lmgfl_rem_plts_frm_flr_slot (
        i_location                IN                        VARCHAR2,
        i_e_rec                   IN                        pl_lm_goal_pb.type_lmc_equip_rec,
        i_num_pallets_to_remove   IN                        NUMBER,
        i_num_positions           IN                        NUMBER,
        i_home_slot_bln           IN                        NUMBER,
        o_pallets_in_stack        OUT                       NUMBER,
        o_drop                    OUT                       NUMBER
    ) AS

        l_func_name                 VARCHAR2(60) := 'pl_lm_goal_fl.lmgfl_rem_plts_frm_flr_slot';
        l_floor_slot_stack_height   NUMBER;
        l_height_diff               NUMBER;
        l_num_pallets_to_remove     NUMBER;
        l_num_positions             NUMBER;
        l_pallet_count              NUMBER;
        l_pallets_in_aisle_stack    NUMBER := 0;
        l_aisle_stack_height        NUMBER;
        l_message                   VARCHAR2(1024);
        i_pindex                    NUMBER := 1;
    BEGIN
        pl_text_log.ins_msg_async('INFO', l_func_name, 'Starting lmgfl_rem_plts_frm_flr_slot. i_location= '
                                            || i_location
                                            || ' i_num_pallets_to_remove= '
                                            || i_num_pallets_to_remove
                                            || ' i_num_positions= '
                                            || i_num_positions
                                            || ' i_home_slot_bln= '
                                            || i_home_slot_bln, sqlcode, sqlerrm);

        l_num_pallets_to_remove := i_num_pallets_to_remove;
        l_num_positions := i_num_positions;
        l_pallet_count := i_num_pallets_to_remove;
        IF ( i_home_slot_bln != 0 ) THEN
		/*
        **  Remove the pick pallet from the home slot.
        **
        **  If its a 1F floor slot and there is more than 1 pallet in the
        **  slot then the pick pallet is on top of the other pallets
        **  otherwise the pick pallet is on the floor.
        */
            IF ( l_num_pallets_to_remove > 1 AND l_num_positions = 1 ) THEN
                l_height_diff := ( l_num_pallets_to_remove - 1 ) * C_STD_PALLET_HEIGHT;
                o_drop := nvl(o_drop, 0) + i_e_rec.bt90 + i_e_rec.apos + ( ( l_height_diff / 12.0 ) * i_e_rec.re ) + i_e_rec.mepos
                + i_e_rec.bt90 + ( ( l_height_diff / 12.0 ) * i_e_rec.ll ) + i_e_rec.ppof + i_e_rec.bt90;

                IF ( g_forklift_audit = C_TRUE ) THEN
                    pl_lm_goaltime.lmg_audit_movement('BT90', pl_lm_goaltime.g_audit_batch_no, i_e_rec, 1, 'Remove pick pallet from the home slot.'
                    );
                    pl_lm_goaltime.lmg_audit_movement('APOS', pl_lm_goaltime.g_audit_batch_no, i_e_rec, 1, '');
                    pl_lm_goaltime.lmg_audit_movement('RE', pl_lm_goaltime.g_audit_batch_no, i_e_rec, l_height_diff, '');
                    pl_lm_goaltime.lmg_audit_movement('MEPOS', pl_lm_goaltime.g_audit_batch_no, i_e_rec, 1, '');
                    pl_lm_goaltime.lmg_audit_movement('BT90', pl_lm_goaltime.g_audit_batch_no, i_e_rec, 1, '');
                    pl_lm_goaltime.lmg_audit_movement('LL', pl_lm_goaltime.g_audit_batch_no, i_e_rec, l_height_diff, '');
                    pl_lm_goaltime.lmg_audit_movement('PPOF', pl_lm_goaltime.g_audit_batch_no, i_e_rec, 1, '');
                    pl_lm_goaltime.lmg_audit_movement('BT90', pl_lm_goaltime.g_audit_batch_no, i_e_rec, 1, '');
                END IF;

            ELSE
                o_drop := nvl(o_drop, 0) + i_e_rec.bt90 + i_e_rec.apof + i_e_rec.mepof + i_e_rec.bt90 + i_e_rec.ppof + i_e_rec.bt90
                ;

                IF ( g_forklift_audit = C_TRUE ) THEN
                    pl_lm_goaltime.lmg_audit_movement('BT90', pl_lm_goaltime.g_audit_batch_no, i_e_rec, 1, 'Remove pick pallet from the home slot.'
                    );
                    pl_lm_goaltime.lmg_audit_movement('APOF', pl_lm_goaltime.g_audit_batch_no, i_e_rec, 1, '');
                    pl_lm_goaltime.lmg_audit_movement('MEPOF', pl_lm_goaltime.g_audit_batch_no, i_e_rec, 1, '');
                    pl_lm_goaltime.lmg_audit_movement('BT90', pl_lm_goaltime.g_audit_batch_no, i_e_rec, 1, '');
                    pl_lm_goaltime.lmg_audit_movement('PPOF', pl_lm_goaltime.g_audit_batch_no, i_e_rec, 1, '');
                    pl_lm_goaltime.lmg_audit_movement('BT90', pl_lm_goaltime.g_audit_batch_no, i_e_rec, 1, '');
                END IF;

            END IF; /* END of num_pallets_to_remove > 1 IF */

            l_pallet_count := l_pallet_count - 1;
            l_num_pallets_to_remove := l_num_pallets_to_remove - 1;
            IF ( l_num_positions > 1 ) THEN
                l_num_positions := l_num_positions - 1;
            END IF;
        END IF; /* END of i_home_slot_bln != 0 IF */
/*
    **  Remove the rest of the pallets from the slot assuming the pallets
    **  are stacked evenly in the slot. The pallets will be stacked in the
    **  aisle with a max of MAX_PALS_PER_STACK pallets in a stack.
    */
        IF ( g_forklift_audit = C_TRUE AND l_pallet_count > 0 ) THEN
		/* A home slot gets a slightly different message. */
            l_message := 'Remove the pallet(s) in slot, stacking them in the aisle with no more than pallets in a stack';
            pl_lm_goaltime.lmg_audit_cmt(pl_lm_goaltime.g_audit_batch_no, l_message, -1);
        END IF;

        l_aisle_stack_height := 0;
        l_pallet_count := 3;
        WHILE ( l_pallet_count > 0 ) LOOP
            l_pallets_in_aisle_stack := 0;
            FOR i IN 1..C_MAX_PALS_PER_STACK LOOP IF ( l_pallet_count > 0 ) THEN
			/*
            **  Get pallet from stack in slot.
            */
                IF ( g_forklift_audit = C_TRUE ) THEN
                    pl_lm_goaltime.lmg_audit_cmt(pl_lm_goaltime.g_audit_batch_no, 'Remove pallet from slot and stack in aisle.', -
                    1);
                END IF;
/*
            **  Determine the height of the pallet in the stack in the home
            **  slot. Function lmgfl_floor_slot_stack_height() originally 
            **  written to user when putting pallets back into the floor slot
            **  but can be used when removing pallets as long as the third
            **  parameter is set correctly.
            */
                l_floor_slot_stack_height := lmgfl_floor_slot_stack_height(l_num_positions, l_num_pallets_to_remove, l_pallet_count

                - 1);
                l_height_diff := l_floor_slot_stack_height - l_aisle_stack_height;
                IF ( l_height_diff > 0 ) THEN
                    o_drop := nvl(o_drop, 0) + ( ( abs(l_height_diff) / 12.0 ) * i_e_rec.re );
                ELSE
                    o_drop := nvl(o_drop, 0) + ( ( abs(l_height_diff) / 12.0 ) * i_e_rec.le );
                END IF;

                IF ( l_floor_slot_stack_height = 0 ) THEN
                    o_drop := nvl(o_drop, 0) + i_e_rec.apof + i_e_rec.mepof + i_e_rec.bt90;
                ELSE
                    o_drop := nvl(o_drop, 0) + i_e_rec.apos + i_e_rec.mepos + i_e_rec.bt90;
                END IF;

                IF ( g_forklift_audit = C_TRUE ) THEN
                    IF ( l_height_diff > 0 ) THEN
                        pl_lm_goaltime.lmg_audit_movement('RE', pl_lm_goaltime.g_audit_batch_no, i_e_rec, abs(l_height_diff), '')
                        ;
                    ELSE
                        pl_lm_goaltime.lmg_audit_movement('LE', pl_lm_goaltime.g_audit_batch_no, i_e_rec, abs(l_height_diff), '')
                        ;
                    END IF;

                    IF ( l_floor_slot_stack_height = 0 ) THEN
                        pl_lm_goaltime.lmg_audit_movement('APOF', pl_lm_goaltime.g_audit_batch_no, i_e_rec, 1, '');
                        pl_lm_goaltime.lmg_audit_movement('MEPOF', pl_lm_goaltime.g_audit_batch_no, i_e_rec, 1, '');
                        pl_lm_goaltime.lmg_audit_movement('BT90', pl_lm_goaltime.g_audit_batch_no, i_e_rec, 1, '');
                    ELSE
                        pl_lm_goaltime.lmg_audit_movement('APOS', pl_lm_goaltime.g_audit_batch_no, i_e_rec, 1, '');
                        pl_lm_goaltime.lmg_audit_movement('MEPOS', pl_lm_goaltime.g_audit_batch_no, i_e_rec, 1, '');
                        pl_lm_goaltime.lmg_audit_movement('BT90', pl_lm_goaltime.g_audit_batch_no, i_e_rec, 1, '');
                    END IF;

                END IF;
/*
            **  Got the pallet on the forks.  Place it on the stack in the
            **  aisle.
            */
                l_aisle_stack_height := l_pallets_in_aisle_stack * C_STD_PALLET_HEIGHT;
                l_height_diff := l_floor_slot_stack_height - l_aisle_stack_height;
                IF ( l_height_diff > 0 ) THEN
                    o_drop := nvl(o_drop, 0) + ( ( abs(l_height_diff) / 12.0 ) * i_e_rec.ll );
                ELSE
                    o_drop := nvl(o_drop, 0) + ( ( abs(l_height_diff) / 12.0 ) * i_e_rec.rl );
                END IF;

                IF ( l_aisle_stack_height = 0 ) THEN
                    o_drop := nvl(o_drop, 0) + i_e_rec.ppof;
                ELSE
                    o_drop := nvl(o_drop, 0) + i_e_rec.apos + i_e_rec.ppos;
                END IF;

                o_drop := nvl(o_drop, 0) + i_e_rec.bt90;
                IF ( g_forklift_audit = C_TRUE ) THEN
                    IF ( l_height_diff > 0 ) THEN
                        pl_lm_goaltime.lmg_audit_movement('LL', pl_lm_goaltime.g_audit_batch_no, i_e_rec, abs(l_height_diff), '')
                        ;
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
            END IF; /* END of  l_pallet_count > 0 IF */
            END LOOP;

        END LOOP;

        o_pallets_in_stack := l_pallets_in_aisle_stack;
    END lmgfl_rem_plts_frm_flr_slot;

/*****************************************************************************
**  FUNCTION:
**      lmgfl_putbk_plts_in_flr_slot()
**
**  DESCRIPTION:
**      This function puts back the existing pallets removed from the
**      floor slot.
**
**  PARAMETERS:
**      i_location               - Floor slot to put the pallets back into.
**      i_total_pallets_in_slot  - Total number of pallets that will be in
**                                 the slot.
**      i_num_pallets_to_putback - Number of pallets to put back into the slot.
**      i_num_positions          - Number of positions in the slot.
**      i_home_slot_bln          - Indicates IF the slot is a home slot.
**      i_current_FORk_height    - Current height of FORks.
**      i_e_rec                  - Pointer to equipment tmu values.
**      o_drop                   - Outgoing drop value.
**
**  MODIFICATION HISTORY:                                                       **
**      DATE          USER              COMMENT                                 **
**   02/17/2020      Infosys           Initial version0.0                       **  
*****************************************************************************/

    PROCEDURE lmgfl_putbk_plts_in_flr_slot (
        i_location                 IN                         VARCHAR2,
        i_total_pallets_in_slot    IN                         NUMBER,
        i_num_pallets_to_putback   IN                         NUMBER,
        i_num_positions            IN                         NUMBER,
        i_home_slot_bln            IN                         NUMBER,
        i_current_fork_height      IN                         NUMBER,
        i_e_rec                    IN                         pl_lm_goal_pb.type_lmc_equip_rec,
        o_drop                     OUT                        NUMBER
    ) AS

        l_func_name                   VARCHAR2(50) := 'pl_lm_goal_fl.lmgfl_putbk_plts_in_flr_slot';
        l_aisle_stack_height          NUMBER := 0;
        l_first_putback_bln           BOOLEAN;
        l_floor_slot_stack_height     NUMBER;
        l_height_diff                 NUMBER;
        l_num_positions               NUMBER;
        l_pallet_count                NUMBER;
        l_pallets_in_aisle_stack      NUMBER;
        l_pallets_currently_in_slot   NUMBER;
        l_total_pallets_in_slot       NUMBER;
        l_message                     VARCHAR2(1024);
        l_pindex                      NUMBER := 1;
    BEGIN
        pl_text_log.ins_msg_async('INFO', l_func_name, 'i_location= '
                                            || i_location
                                            || ' i_total_pallets_in_slot= '
                                            || i_total_pallets_in_slot
                                            || ' i_num_pallets_to_putback= '
                                            || i_num_pallets_to_putback
                                            || ' i_num_positions= '
                                            || i_num_positions
                                            || 'i_home_slot_bln= '
                                            || i_home_slot_bln, sqlcode, sqlerrm);

        IF ( g_forklift_audit = C_TRUE AND i_num_pallets_to_putback > 0 ) THEN
            l_message := 'Put the existing inventory back into slot '
                         || i_location
                         || ' pallet(s) to put back. Pallet = '
                         || i_num_pallets_to_putback;
            pl_lm_goaltime.lmg_audit_cmt(pl_lm_goaltime.g_audit_batch_no, l_message, -1);
        END IF;

        l_first_putback_bln := TRUE;
        l_floor_slot_stack_height := 0;
        l_num_positions := i_num_positions;
        l_pallets_currently_in_slot := i_total_pallets_in_slot - i_num_pallets_to_putback;
        l_total_pallets_in_slot := i_total_pallets_in_slot;
		/*
    **  For home slots put back the pallets that are behind the pick pallet.
    **  The pick pallet which will be moved last and will always be on the
    **  floor except for a 1F home slot where the pick pallet is placed
    **  on top of the other pallets.
    */
        IF ( i_home_slot_bln != 0 ) THEN
            l_pallet_count := i_num_pallets_to_putback - 1;
            l_total_pallets_in_slot := l_total_pallets_in_slot - 1;
			/*
        **  One position in floor home slots is for the pick pallet.
        **  Leave 1F floor slots at 1 position.
        */
            IF ( l_num_positions > 1 ) THEN
                l_num_positions := l_num_positions - 1;
            END IF;
        ELSE
            l_pallet_count := i_num_pallets_to_putback;
        END IF;

        WHILE ( l_pallet_count > 0 ) LOOP
		/*
        **  Determine the number of pallets in the aisle stack.  The maximum
        **  number of pallets in an aisle stack is MAX_PALS_PER_STACK.
        */
            l_pallets_in_aisle_stack := MOD(l_pallet_count, C_MAX_PALS_PER_STACK);
            IF ( l_pallets_in_aisle_stack = 0 ) THEN
                l_pallets_in_aisle_stack := C_MAX_PALS_PER_STACK;
            END IF;
            l_aisle_stack_height := ( l_pallets_in_aisle_stack - 1 ) * C_STD_PALLET_HEIGHT;
			/*
        **  Take the pallets in the aisle stack and place in the slot.
        */
            FOR i IN REVERSE 0..l_pallets_in_aisle_stack LOOP
                IF ( g_forklift_audit = C_TRUE ) THEN
                    IF ( i = l_pallets_in_aisle_stack ) THEN
                        l_message := 'Put pallets in aisle stack back into the slot. Pallet(s)= '
                                     || l_pallets_in_aisle_stack
                                     || ' in the aisle stack';
                        pl_lm_goaltime.lmg_audit_cmt(pl_lm_goaltime.g_audit_batch_no, l_message, -1);
                    END IF;

                    l_message := 'Pickup pallet from aisle stack and put in slot';
                    pl_lm_goaltime.lmg_audit_cmt(pl_lm_goaltime.g_audit_batch_no, l_message, -1);
                END IF;
/*
            **  Move the forks to the height if the pallet in the aisle stack.
            */
                IF ( l_first_putback_bln != FALSE ) THEN
				/*
                **  This is the first putback.  Move the forks from their
                **  current position to the level of the putback pallet.
                */
                    l_first_putback_bln := FALSE;
                    l_height_diff := i_current_fork_height - l_aisle_stack_height;
                ELSE
				/*
                **  Move the forks from the level of the pallet just put in
                **  the slot to the level of the next pallet in the aisle stack.
                */
                    l_height_diff := l_floor_slot_stack_height - l_aisle_stack_height;
                END IF;

                IF ( l_height_diff > 0 ) THEN
                    o_drop := nvl(o_drop, 0) + ( ( abs(l_height_diff) / 12.0 ) * i_e_rec.le );
                ELSE
                    o_drop := nvl(o_drop, 0) + ( ( abs(l_height_diff) / 12.0 ) * i_e_rec.re );
                END IF;

                IF ( g_forklift_audit = C_TRUE ) THEN
                    IF ( l_height_diff > 0 ) THEN
                        pl_lm_goaltime.lmg_audit_movement('LE', pl_lm_goaltime.g_audit_batch_no, i_e_rec, abs(l_height_diff), '')
                        ;

                    ELSE
                        pl_lm_goaltime.lmg_audit_movement('RE', pl_lm_goaltime.g_audit_batch_no, i_e_rec, abs(l_height_diff), '')
                        ;
                    END IF;
                END IF;
/*
            **  Pickup the pallet in the aisle stack.
            */
                IF ( l_aisle_stack_height = 0 ) THEN
                    o_drop := nvl(o_drop, 0) + i_e_rec.apof + i_e_rec.mepof + i_e_rec.bt90;
                ELSE
                    o_drop := nvl(o_drop, 0) + i_e_rec.apos + i_e_rec.mepos + i_e_rec.bt90;
                END IF;

                IF ( g_forklift_audit = C_TRUE ) THEN
                    IF ( l_aisle_stack_height = 0 ) THEN
                        pl_lm_goaltime.lmg_audit_movement('APOF', pl_lm_goaltime.g_audit_batch_no, i_e_rec, 1, '');
                        pl_lm_goaltime.lmg_audit_movement('MEPOF', pl_lm_goaltime.g_audit_batch_no, i_e_rec, 1, '');
                        pl_lm_goaltime.lmg_audit_movement('BT90', pl_lm_goaltime.g_audit_batch_no, i_e_rec, 1, '');
                    ELSE
                        pl_lm_goaltime.lmg_audit_movement('APOS', pl_lm_goaltime.g_audit_batch_no, i_e_rec, 1, '');
                        pl_lm_goaltime.lmg_audit_movement('MEPOS', pl_lm_goaltime.g_audit_batch_no, i_e_rec, 1, '');
                        pl_lm_goaltime.lmg_audit_movement('BT90', pl_lm_goaltime.g_audit_batch_no, i_e_rec, 1, '');
                    END IF;
                END IF;
/*
            **  Determine the height of the stack in the slot the new pallet
            **  will be placed on.
            */
                l_floor_slot_stack_height := lmgfl_floor_slot_stack_height(l_num_positions, l_total_pallets_in_slot, l_pallets_currently_in_slot

                );
                l_height_diff := l_aisle_stack_height - l_floor_slot_stack_height;
                IF ( l_height_diff > 0 ) THEN
                    o_drop := nvl(o_drop, 0) + ( ( abs(l_height_diff) / 12.0 ) * i_e_rec.ll );

                    IF ( g_forklift_audit = C_TRUE ) THEN
                        pl_lm_goaltime.lmg_audit_movement('LL', pl_lm_goaltime.g_audit_batch_no, i_e_rec, abs(l_height_diff), '')
                        ;

                    END IF;

                ELSE
                    o_drop := nvl(o_drop, 0) + ( ( abs(l_height_diff) / 12.0 ) * i_e_rec.rl );

                    IF ( g_forklift_audit = C_TRUE ) THEN
                        pl_lm_goaltime.lmg_audit_movement('RL', pl_lm_goaltime.g_audit_batch_no, i_e_rec, abs(l_height_diff), '')
                        ;

                    END IF;

                END IF;

                IF ( l_floor_slot_stack_height = 0 ) THEN
                    o_drop := nvl(o_drop, 0) + i_e_rec.ppof + i_e_rec.bt90;
                ELSE
                    o_drop := nvl(o_drop, 0) + i_e_rec.apos + i_e_rec.ppos + i_e_rec.bt90;
                END IF;

                IF ( g_forklift_audit = C_TRUE ) THEN
                    IF ( l_floor_slot_stack_height = 0 ) THEN
                        pl_lm_goaltime.lmg_audit_movement('PPOF', pl_lm_goaltime.g_audit_batch_no, i_e_rec, 1, '');
                        pl_lm_goaltime.lmg_audit_movement('BT90', pl_lm_goaltime.g_audit_batch_no, i_e_rec, 1, '');
                    ELSE
                        pl_lm_goaltime.lmg_audit_movement('APOS', pl_lm_goaltime.g_audit_batch_no, i_e_rec, 1, '');
                        pl_lm_goaltime.lmg_audit_movement('PPOS', pl_lm_goaltime.g_audit_batch_no, i_e_rec, 1, '');
                        pl_lm_goaltime.lmg_audit_movement('BT90', pl_lm_goaltime.g_audit_batch_no, i_e_rec, 1, '');
                    END IF;
                END IF;

                l_aisle_stack_height := l_aisle_stack_height - C_STD_PALLET_HEIGHT;
                l_pallet_count := l_pallet_count - 1;
                l_pallets_currently_in_slot := l_pallets_currently_in_slot + 1;
            END LOOP;

        END LOOP;
/*
    **  Lower the forks to the floor.
    */
        IF ( l_first_putback_bln != FALSE AND i_home_slot_bln != 0 ) THEN
		/*
        **  Putting back into the home slot and the only pallet to putback
        **  is the pick pallet.
        */
            o_drop := nvl(o_drop, 0) + ( ( i_current_fork_height / 12.0 ) * i_e_rec.le );

            IF ( g_forklift_audit = C_TRUE ) THEN
                pl_lm_goaltime.lmg_audit_movement('LE', pl_lm_goaltime.g_audit_batch_no, i_e_rec, i_current_fork_height, '');
            END IF;

        ELSE
		 /*
        **  Either putting back into a home slot with more than one pallet
        **  to putback or putting back into a reserve slot.
        */
            o_drop := nvl(o_drop, 0) + ( ( l_floor_slot_stack_height / 12.0 ) * i_e_rec.le );

            IF ( g_forklift_audit = C_TRUE ) THEN
                pl_lm_goaltime.lmg_audit_movement('LE', pl_lm_goaltime.g_audit_batch_no, i_e_rec, l_floor_slot_stack_height, '');
            END IF;

        END IF;
/*
    **  For home slots put the pick pallet back in the slot.
    **  For 1F home slots the pick pallet is placed on top of the
    **  other pallets.
    */
        IF ( i_home_slot_bln != 0 ) THEN
            o_drop := nvl(o_drop, 0) + i_e_rec.apof + i_e_rec.mepof + i_e_rec.bt90;

            IF ( g_forklift_audit = C_TRUE ) THEN
                pl_lm_goaltime.lmg_audit_movement('APOF', pl_lm_goaltime.g_audit_batch_no, i_e_rec, 1, 'Put pick pallet back into the slot.'
                );
                pl_lm_goaltime.lmg_audit_movement('MEPOF', pl_lm_goaltime.g_audit_batch_no, i_e_rec, 1, '');
                pl_lm_goaltime.lmg_audit_movement('BT90', pl_lm_goaltime.g_audit_batch_no, i_e_rec, 1, '');
            END IF;
/*
        **  Place the pick pallet in the slot.
        */
            IF ( i_num_positions = 1 ) THEN
			/*
            **  1F floor slot that has other pallets stacked in the slot.
            **  Put the pick pallet on top of the stack.
            */

            /*
            **  Set the floor slot stack height.
            */
                l_floor_slot_stack_height := l_pallets_currently_in_slot * C_STD_PALLET_HEIGHT;
                o_drop := nvl(o_drop, 0) + i_e_rec.apos + ( ( l_floor_slot_stack_height / 12.0 ) * i_e_rec.rl ) + i_e_rec.ppos + (
                ( l_floor_slot_stack_height / 12.0 ) * i_e_rec.le ) + i_e_rec.bt90;

                IF ( g_forklift_audit = C_TRUE ) THEN
                    pl_lm_goaltime.lmg_audit_movement('APOS', pl_lm_goaltime.g_audit_batch_no, i_e_rec, 1, '');
                    pl_lm_goaltime.lmg_audit_movement('RL', pl_lm_goaltime.g_audit_batch_no, i_e_rec, l_floor_slot_stack_height, ''
                    );
                    pl_lm_goaltime.lmg_audit_movement('PPOS', pl_lm_goaltime.g_audit_batch_no, i_e_rec, 1, '');
                    pl_lm_goaltime.lmg_audit_movement('LE', pl_lm_goaltime.g_audit_batch_no, i_e_rec, l_floor_slot_stack_height, ''
                    );
                    pl_lm_goaltime.lmg_audit_movement('BT90', pl_lm_goaltime.g_audit_batch_no, i_e_rec, 1, '');
                END IF;

            ELSE
			/*
            **  2F, 3F, 4F or 5F floor slot.  Put the pick pallet on the
            **  floor.
            */
                o_drop := nvl(o_drop, 0) + i_e_rec.ppof + i_e_rec.bt90;
                IF ( g_forklift_audit = C_TRUE ) THEN
                    pl_lm_goaltime.lmg_audit_movement('PPOF', pl_lm_goaltime.g_audit_batch_no, i_e_rec, 1, '');
                    pl_lm_goaltime.lmg_audit_movement('BT90', pl_lm_goaltime.g_audit_batch_no, i_e_rec, 1, '');
                END IF;

            END IF;

        END IF; /* END of i_home_slot_bln != 0 IF */

    END lmgfl_putbk_plts_in_flr_slot;

/*****************************************************************************
**  FUNCTION:
**      lmgfl_drop_to_floor_slot()
**
**  DESCRIPTION:
**      This function calculates the LM drop discreet value FOR a pallet
**      going to a floor slot.  Used FOR putaways.  Only the actions of
**      putting the pallet in the slot are set.  These actions are:
**          LL, PPOF, BT90    (placing the pallet on the floor)
**            or
**          APOS, RL or LL, PPOS, BT90  (placing the pallet on existing pallets)
**
**
**
**  PARAMETERS:
**      i_stacking_positions         - Number of positions in the slot that
**                                     the pallets can be placed in.
**      i_total_pallets_in_slot      - Total number of pallets that will be
**                                     in the slot.
**      i_pallets_already_putaway    - Number of pallets already putaway to the
**                                     slot on other labor mgmt batches.
**      i_num_pallets_to_put_in_slot - Number of pallets to put in the slot.
**      i_e_rec                      - Pointer to equipment tmu values.
**      i_pallet_height              - Height of pallet on the travel stack.
**      o_drop                       - Outgoing drop value.
**
**  MODIFICATION HISTORY:                                                       **
**      DATE          USER              COMMENT                                 **
**   02/17/2020      Infosys           Initial version0.0                       **  
*****************************************************************************/

    PROCEDURE lmgfl_drop_to_floor_slot (
        i_stacking_positions           IN                             NUMBER,
        i_total_pallets_in_slot        IN                             NUMBER,
        i_pallets_already_putaway      IN                             NUMBER,
        i_num_pallets_to_put_in_slot   IN                             NUMBER,
        i_e_rec                        IN                             pl_lm_goal_pb.type_lmc_equip_rec,
        i_pallet_height                IN                             NUMBER,
        o_drop                         OUT                            NUMBER
    ) AS

        l_func_name                  VARCHAR2(50) := 'pl_lm_goal_fl.lmgfl_drop_to_floor_slot';
        l_done_bln                   BOOLEAN := FALSE;
        l_pallets_per_position       NUMBER;
        l_adj_pallets_per_position   NUMBER;
        l_curr_pallet_no             NUMBER;
        l_curr_position              NUMBER;
        l_curr_position_pallet_seq   NUMBER;
        l_pallets_putup              NUMBER := 0;
        l_stack_height               NUMBER := 0;
        l_left_over                  NUMBER;     /* mod(pallets to put in slot, stacking positions) */
        l_start_pallet_seq           NUMBER;
        l_end_pallet_seq             NUMBER;
        l_pindex                     NUMBER := 1;
    BEGIN
        pl_text_log.ins_msg_async('INFO', l_func_name, 'starting lmgfl_drop_to_floor_slot. i_stacking_positions= '
                                            || i_stacking_positions
                                            || ' i_total_pallets_in_slot= '
                                            || i_total_pallets_in_slot
                                            || ' i_pallets_already_putaway= '
                                            || i_pallets_already_putaway
                                            || ' i_num_pallets_to_put_in_slot= '
                                            || i_num_pallets_to_put_in_slot
                                            || ' i_pallet_height= '
                                            || i_pallet_height, sqlcode, sqlerrm);

        l_pallets_per_position := i_total_pallets_in_slot / i_stacking_positions;
        l_left_over := MOD(i_total_pallets_in_slot, i_stacking_positions);
        l_start_pallet_seq := i_pallets_already_putaway + 1;
        l_end_pallet_seq := ( l_start_pallet_seq + i_num_pallets_to_put_in_slot ) - 1;
        l_curr_pallet_no := 1;
        l_curr_position := 1;
        WHILE ( l_curr_position <= i_stacking_positions AND l_done_bln = FALSE ) LOOP
            l_stack_height := 0;
            IF ( l_left_over > 0 ) THEN
                l_adj_pallets_per_position := l_pallets_per_position + 1;
                l_left_over := l_left_over - 1;
            ELSE
                l_adj_pallets_per_position := l_pallets_per_position;
            END IF;

            l_curr_position_pallet_seq := 1;
            WHILE ( l_curr_position_pallet_seq <= l_adj_pallets_per_position AND l_done_bln = FALSE ) LOOP
                IF ( l_curr_pallet_no >= l_start_pallet_seq AND l_curr_pallet_no <= l_end_pallet_seq ) THEN
                    IF ( l_stack_height = 0 ) THEN
                        o_drop := nvl(o_drop, 0) + ( ( i_pallet_height / 12.0 ) * i_e_rec.ll ) + i_e_rec.ppof + i_e_rec.bt90;

                        IF ( g_forklift_audit = C_TRUE ) THEN
                            pl_lm_goaltime.lmg_audit_movement('LL', pl_lm_goaltime.g_audit_batch_no, i_e_rec, i_pallet_height, ''
                            );
                            pl_lm_goaltime.lmg_audit_movement('PPOF', pl_lm_goaltime.g_audit_batch_no, i_e_rec, 1, '');
                            pl_lm_goaltime.lmg_audit_movement('BT90', pl_lm_goaltime.g_audit_batch_no, i_e_rec, 1, '');
                        END IF;

                    ELSE
                        o_drop := nvl(o_drop, 0) + i_e_rec.apos;
                        IF ( l_stack_height > i_pallet_height ) THEN
                            o_drop := nvl(o_drop, 0) + ( ( ( l_stack_height - i_pallet_height ) / 12.0 ) * i_e_rec.rl );

                        ELSE
                            o_drop := nvl(o_drop, 0) + ( ( ( i_pallet_height - l_stack_height ) / 12.0 ) * i_e_rec.ll );
                        END IF;

                        o_drop := nvl(o_drop, 0) + i_e_rec.ppos + i_e_rec.bt90;
                        IF ( g_forklift_audit = C_TRUE ) THEN
                            pl_lm_goaltime.lmg_audit_movement('APOS', pl_lm_goaltime.g_audit_batch_no, i_e_rec, 1, '');
                            IF ( l_stack_height > i_pallet_height ) THEN
                                pl_lm_goaltime.lmg_audit_movement('RL', pl_lm_goaltime.g_audit_batch_no, i_e_rec, l_stack_height -
                                i_pallet_height, '');

                            ELSE
                                pl_lm_goaltime.lmg_audit_movement('LL', pl_lm_goaltime.g_audit_batch_no, i_e_rec, i_pallet_height
                                - l_stack_height, '');
                            END IF;

                            pl_lm_goaltime.lmg_audit_movement('PPOS', pl_lm_goaltime.g_audit_batch_no, i_e_rec, 1, '');
                            pl_lm_goaltime.lmg_audit_movement('BT90', pl_lm_goaltime.g_audit_batch_no, i_e_rec, 1, '');
                        END IF;

                    END IF;

                    l_pallets_putup := l_pallets_putup + 1;
                END IF; /* END of l_curr_pallet_no >= l_start_pallet_seq IF */

                l_stack_height := l_stack_height + C_STD_PALLET_HEIGHT;
                l_curr_pallet_no := l_curr_pallet_no + 1;
                l_curr_position_pallet_seq := l_curr_position_pallet_seq + 1;
                IF ( l_pallets_putup = i_num_pallets_to_put_in_slot ) THEN
                    l_done_bln := TRUE;
                END IF;
            END LOOP;

            l_curr_position := l_curr_position + 1;
        END LOOP;

    END lmgfl_drop_to_floor_slot;

/*****************************************************************************
**  FUNCTION:
**      lmgfl_floor_slot_stack_height()
**
**  DESCRIPTION:
**      This function calculates the height of the stack a pallet will be
**      placed on FOR floor slots.
**
**
**  PARAMETERS:
**      i_stacking_positions       - Number of positions in the slot that
**                                   the pallets can be placed in.
**      i_total_pallets_in_slot    - Total number of pallets that will be
**                                   in the slot.
**      i_pallets_already_putaway  - Number of pallets already putaway to the
**                                   slot on other labor mgmt batches.
**
**  RETURN VALUES:
**      The height of the stack in the floor slot the pallet is being
**       placed on.
**
**  MODIFICATION HISTORY:                                                       **
**      DATE          USER              COMMENT                                 **
**   02/17/2020      Infosys           Initial version0.0                       **  
*****************************************************************************/

    FUNCTION lmgfl_floor_slot_stack_height (
        i_stacking_positions        IN                          NUMBER,
        i_total_pallets_in_slot     IN                          NUMBER,
        i_pallets_already_putaway   IN                          NUMBER
    ) RETURN NUMBER AS

        l_func_name                  VARCHAR2(50) := 'pl_lm_goal_fl.lmgfl_floor_slot_stack_height';
        l_done_bln                   BOOLEAN := FALSE;
        l_pallets_per_position       NUMBER;
        l_adj_pallets_per_position   NUMBER;
        l_curr_pallet_no             NUMBER;
        l_curr_position              NUMBER;
        l_curr_position_pallet_seq   NUMBER;
        l_stack_height               NUMBER := 0;
        l_left_over                  NUMBER;     /* mod(pallets to put in slot, stacking positions) */
        l_start_pallet_seq           NUMBER;
        l_end_pallet_seq             NUMBER;
    BEGIN
        pl_text_log.ins_msg_async('INFO', l_func_name, ' Starting lmgfl_floor_slot_stack_height. i_stacking_positions= '
                                            || i_stacking_positions
                                            || ' i_total_pallets_in_slot= '
                                            || i_total_pallets_in_slot
                                            || ' i_pallets_already_putaway= '
                                            || i_pallets_already_putaway, sqlcode, sqlerrm);

        l_pallets_per_position := i_total_pallets_in_slot / i_stacking_positions;
        l_left_over := MOD(i_total_pallets_in_slot, i_stacking_positions);
        l_start_pallet_seq := i_pallets_already_putaway + 1;
        l_end_pallet_seq := l_start_pallet_seq;
        l_curr_pallet_no := 1;
        l_curr_position := 1;
        WHILE ( l_curr_position <= i_stacking_positions AND l_done_bln = FALSE ) LOOP
            l_stack_height := 0;
            IF ( l_left_over > 0 ) THEN
                l_adj_pallets_per_position := l_pallets_per_position + 1;
                l_left_over := l_left_over - 1;
            ELSE
                l_adj_pallets_per_position := l_pallets_per_position;
            END IF;

            l_curr_position_pallet_seq := 1;
            WHILE ( l_curr_position_pallet_seq <= l_adj_pallets_per_position AND l_done_bln = FALSE ) LOOP IF ( l_curr_pallet_no >= l_start_pallet_seq
            AND l_curr_pallet_no <= l_end_pallet_seq ) THEN
                l_done_bln := TRUE;
            ELSE
                l_stack_height := l_stack_height + C_STD_PALLET_HEIGHT;
                l_curr_pallet_no := l_curr_pallet_no + 1;
                l_curr_position_pallet_seq := l_curr_position_pallet_seq + 1;
            END IF;
            END LOOP;

            l_curr_position := l_curr_position + 1;
        END LOOP;

        RETURN l_stack_height;
    END lmgfl_floor_slot_stack_height;

/*****************************************************************************
**  FUNCTION:
**      lmgfl_place_pallet_in_flr_slt()
**
**  DESCRIPTION:
**      This function calculates the LM drop discreet value to drop a pallet
**      to a floor slot.  The operations will be one of the following
**      depENDing on the height of the drop pallet on the FORks relative
**      to the stack in the slot to place the pallet on and IF the floor
**      slot is empty.
**         - APOS, RL or LL, PPOS, BT90   Pallet goes on a stack in the slot.
**         - RL or LL, PPOF, BT90         Floor slot empty or the pallet goes
**                                        on the floor in front of an existing
**                                        stack.
**
**  PARAMETERS:
**      i_floor_slot_stack_height - Height of the stack in the slot the
**                                  drop pallet is to be placed on.
**      i_pallet_height           - Height of the drop pallet.
**      i_e_rec                   - Pointer to equipment tmu values.
**      o_drop                    - Outgoing drop value.
**
**  MODIFICATION HISTORY:                                                       **
**      DATE          USER              COMMENT                                 **
**   02/17/2020      Infosys           Initial version0.0                       **  
*****************************************************************************/

    PROCEDURE lmgfl_place_pallet_in_flr_slt (
        i_floor_slot_stack_height   IN                          NUMBER,
        i_pallet_height             IN                          NUMBER,
        i_e_rec                     IN                          pl_lm_goal_pb.type_lmc_equip_rec,
        o_drop                      OUT                         NUMBER
    ) AS
        l_func_name   VARCHAR2(50) := 'pl_lm_goal_fl.lmgfl_place_pallet_in_flr_slt';
        l_pindex      NUMBER := 1;
    BEGIN
        pl_text_log.ins_msg_async('INFO', l_func_name, 'starting lmgfl_place_pallet_in_flr_slt. i_floor_slot_stack_height= '
                                            || i_floor_slot_stack_height
                                            || 'i_pallet_height= '
                                            || i_pallet_height, sqlcode, sqlerrm);

        IF ( i_floor_slot_stack_height > 0 ) THEN
            o_drop := nvl(o_drop, 0) + i_e_rec.apos;
            IF ( g_forklift_audit = C_TRUE ) THEN
                pl_lm_goaltime.lmg_audit_movement('APOS', pl_lm_goaltime.g_audit_batch_no, i_e_rec, 1, ' ');
            END IF;

        END IF;
/*
    ** Move the pallet up or down to get the pallet at the level of
    ** the stack in the floor slot.  Note that the floor slot could
    ** be empty.
    */
        IF ( i_floor_slot_stack_height > i_pallet_height ) THEN
            o_drop := nvl(o_drop, 0) + ( ( ( i_floor_slot_stack_height - i_pallet_height ) / 12.0 ) * i_e_rec.rl ) + i_e_rec.ppos
            ;

            IF ( g_forklift_audit = C_TRUE ) THEN
                pl_lm_goaltime.lmg_audit_movement('RL', pl_lm_goaltime.g_audit_batch_no, i_e_rec,(i_floor_slot_stack_height - i_pallet_height
                ), '');

                pl_lm_goaltime.lmg_audit_movement('PPOS', pl_lm_goaltime.g_audit_batch_no, i_e_rec, 1, '');
            END IF;

        ELSE
            o_drop := nvl(o_drop, 0) + ( ( ( i_pallet_height - i_floor_slot_stack_height ) / 12.0 ) * i_e_rec.ll );

            IF ( i_floor_slot_stack_height = 0 ) THEN
                o_drop := nvl(o_drop, 0) + i_e_rec.ppof;
            ELSE
                o_drop := nvl(o_drop, 0) + i_e_rec.ppos;
            END IF;

            IF ( g_forklift_audit = C_TRUE ) THEN
                pl_lm_goaltime.lmg_audit_movement('LL', pl_lm_goaltime.g_audit_batch_no, i_e_rec, i_pallet_height - i_floor_slot_stack_height
                , '');

                IF ( i_floor_slot_stack_height = 0 ) THEN
                    pl_lm_goaltime.lmg_audit_movement('PPOF', pl_lm_goaltime.g_audit_batch_no, i_e_rec, 1, '');
                ELSE
                    pl_lm_goaltime.lmg_audit_movement('PPOS', pl_lm_goaltime.g_audit_batch_no, i_e_rec, 1, '');
                END IF;

            END IF;

        END IF;

    END lmgfl_place_pallet_in_flr_slt;

END pl_lm_goal_fl;
/

GRANT EXECUTE ON pl_lm_goal_fl TO swms_user;