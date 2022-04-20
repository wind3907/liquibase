create or replace PACKAGE pl_lm_goal_dd AS

/*******************************************************************************
** Package:
**        pl_lm_goal_dd. Migrated from lm_goal_dd.pc
**
** Description:
**		  This file contains the functions and subroutes necessary to calculate
**    discreet Labor Management values for Double Deep racking.
**
** Called by:
**        This is a common package called from many other packages
** Modification History :                                                                  
** Author       Date        Ver   Description                                 
**------------ ----------  ----  -----------------------------------------   
** chyd9155	   10/03/2020  1.0    Initial Version                            
******************************************************************************/

    PROCEDURE lmgdd_dro_dbl_deep_hm_qoh (
        i_pals             IN 		pl_lm_goal_pb.tbl_lmg_pallet_rec,
        i_num_pallets      IN 		NUMBER,
        i_e_rec            IN 		pl_lm_goal_pb.type_lmc_equip_rec,
        i_dest_total_qoh   IN 		NUMBER,
        io_drop 		   IN OUT 	NUMBER
    );

    PROCEDURE lmgdd_drp_dbl_deep_res_qoh (
        i_pals           IN 	pl_lm_goal_pb.tbl_lmg_pallet_rec,
        i_num_pallets    IN 	NUMBER,
        i_e_rec          IN 	pl_lm_goal_pb.type_lmc_equip_rec,
        i_num_recs       IN 	NUMBER,
        i_inv            IN 	pl_lm_goal_pb.tbl_lmg_inv_rec,
        i_is_same_item   IN 	VARCHAR2,
        io_drop 		 IN OUT NUMBER
    );

    PROCEDURE lmgdd_pkup_dbl_deep_res (
        i_pals           IN 	pl_lm_goal_pb.tbl_lmg_pallet_rec,
        i_pal_num_recs   IN 	NUMBER,
        i_pindex         IN 	NUMBER,
        i_e_rec          IN 	pl_lm_goal_pb.type_lmc_equip_rec,
        i_num_recs       IN 	NUMBER,
        i_inv            IN 	pl_lm_goal_pb.tbl_lmg_inv_rec,
        i_is_diff_item   IN 	VARCHAR2,
        io_pickup        IN OUT NUMBER
    );

END pl_lm_goal_dd;
/

create or replace PACKAGE BODY pl_lm_goal_dd AS

    STD_PALLET_HEIGHT 	CONSTANT NUMBER:= 48;
    FALSE             	CONSTANT NUMBER := 0;
    TRUE              	CONSTANT NUMBER := 1;
    g_forklift_audit    NUMBER;
    g_audit_batch_no    batch.batch_no%TYPE :=pl_lm_goaltime.g_audit_batch_no;
	
/*****************************************************************************
**  PROCEDURE:
**      lmgdd_dro_dbl_deep_hm_qoh()
**
**  DESCRIPTION:
**      This functions calculates the LM drop discreet value for a pallet
**      going to a double deep home slot that is EMPTY OR WITH EXISTING QOH.
**      Should only be dealing with case quantities.
**
**      For drop to home batches the drop quantity will always be handstacked.
**      Note that for drop to home batches i_pals->qty_on_pallet[] will be the
**      quantity to drop to the home slot and not the total quantity on the
**      pallet.
**
**  PARAMETERS:
**      i_pals             - Pointer to pallet list.
**      i_num_pallets      - Number of pallets in pallet list.
**      i_e_rec            - Pointer to equipment tmu values.
**      i_dest_total_qoh   - Total qoh in destination.
**      io_drop             - Outgoing drop value.
**
**  RETURN VALUES:
**      None.
**
*****************************************************************************/

    PROCEDURE lmgdd_dro_dbl_deep_hm_qoh (
        i_pals             IN                 pl_lm_goal_pb.tbl_lmg_pallet_rec,
        i_num_pallets      IN                 NUMBER,
        i_e_rec            IN                 pl_lm_goal_pb.type_lmc_equip_rec,
        i_dest_total_qoh   IN                 NUMBER,
        io_drop            IN OUT             NUMBER
    )  IS

        l_func_name                    VARCHAR2(50) := 'lmgdd_dro_dbl_deep_hm_qoh';
        l_message                      VARCHAR2(500);
        rf_status rf.status := rf.STATUS_NORMAL;
        l_apply_credit_at_case_level   NUMBER;/* Designates if to apply credit at
                                          the case level when uom = 1. */
        l_buf                          VARCHAR2(128);
        l_handstack_cases              NUMBER := 0;/* Cases handstacked */
        l_handstack_splits             NUMBER := 0; /* Splits handstacked */
        l_i                            NUMBER;
        l_index                        NUMBER:=1;
        l_last_pal_qty                 NUMBER;/* Quantity on last pallet in slot */
        l_multi_face_slot_bln          NUMBER;/* Multi-face slot designator */
        l_adj_num_positions            NUMBER;/* Number of positions in the slot
                                   adjusted for the min qty */
        l_slot_type_num_positions      NUMBER;/* Number of positions in the slot
                                        as indicated by the slot type */
        l_open_positions               NUMBER;/* Number of open positions in the slot */
        l_pallet_height                NUMBER;/* Height from floor to top pallet on stack */
        l_pallet_qty                   NUMBER;/* Quantity on drop pallet or if the batch is
                                 a drop to home then the quantity to drop to
                                 the home slot */
        l_pallet_removed               NUMBER := false;/* Indicates if a pallet removed from the
                                      home slot for rotation purposes. */
        l_pallets_in_slot              NUMBER;/* Number of pallets for l_prev_qoh.
                                 Incremented for each new pallet put in the
                                 slot. */
        l_prev_qoh                     NUMBER; /* Approximate quantity in the slot before drop */
        l_pindex                       NUMBER;/* Index of top pallet on stack */
        l_slot_height                  NUMBER;/* Height to slot from floor */
        l_spc                          NUMBER;/* Splits per case */
        l_splits_per_pallet            NUMBER;/* Number of splits on a pallet */
    BEGIN
        l_pindex := i_num_pallets - 1;
        pl_text_log.ins_msg_async('INFO', l_func_name, '('||i_pals(l_pindex).pallet_id||', '||i_num_pallets||', '||i_e_rec.equip_id||', '||i_dest_total_qoh||'  multi_pallet_drop_to_slot '||i_pals(l_pindex).multi_pallet_drop_to_slot, NULL, NULL);
        /*
        **  All the pallets being dropped to the same slot are processed
        **  the first time this function is called.
        */        
        IF i_pals(l_pindex).multi_pallet_drop_to_slot='Y' THEN
			 pl_text_log.ins_msg_async('INFO', l_func_name, 'multi_pallet_drop_to_slot = Y ', sqlcode, sqlerrm);
            RETURN;
        END IF;
        /*
        **  Always removing the top pallet on the stack.
        */
        l_pallet_qty := i_pals(l_pindex).qty_on_pallet;
        l_prev_qoh := i_dest_total_qoh;
        l_slot_height := i_pals(l_pindex).height;
        l_spc := i_pals(l_pindex).spc;
        l_pallet_height := STD_PALLET_HEIGHT*l_pindex;
        l_splits_per_pallet := i_pals(l_pindex).ti * i_pals(l_pindex).hi * l_spc;
        l_pallets_in_slot := l_prev_qoh / l_splits_per_pallet;
        l_last_pal_qty := MOD(l_prev_qoh, l_splits_per_pallet);
        IF l_last_pal_qty > 0 THEN    /* A partial pallet counts as a pallet. */
            l_pallets_in_slot:=l_pallets_in_slot+1;
        END IF;
        /*
        ** if l_last_pal_qty is 0 then each pallet in the slot is a full pallet so
        ** set l_last_pal_qty to a full pallet.
        */
        IF l_last_pal_qty = 0 THEN
            l_last_pal_qty := l_splits_per_pallet;
        END IF;
        /*
        ** Extract out the number positions in the slot as indicated by
        ** the slot type.
        */

        /*
        ** Adjust the number of positions in the slot based on the min quantity.
        */

        IF i_pals(l_pindex).min_qty_num_positions >= l_slot_type_num_positions THEN
            l_multi_face_slot_bln := TRUE;
        ELSE 
            l_multi_face_slot_bln := FALSE;
        END IF;
        /*
        ** Get syspar that determines if to give credit at the case or
        ** split level when dropping to a split home slot.
        */
        rf_status :=pl_lm_forklift.lm_sel_split_rpl_crdt_syspar(l_apply_credit_at_case_level);
        /*
        ** Process the pallets in the stack going to the same home slot.
        */

        while l_pindex >= 1
        LOOP
            /*
            **  Get out of the loop if all the drops to the same home slot
            **  have been processed.
            */
            IF (l_index <> l_pindex AND i_pals(l_index).multi_pallet_drop_to_slot = 'N')  THEN
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
            IF l_open_positions < 0 THEN
                l_open_positions := 0;
            END IF;

            IF g_forklift_audit = 1 THEN
                pl_lm_goaltime.lmg_drop_to_home_audit_msg(i_pals,
                                       l_pindex,
                                       l_pallets_in_slot,
                                       l_prev_qoh,
                                       l_slot_type_num_positions,
                                       l_adj_num_positions,
                                       l_open_positions,
                                       l_multi_face_slot_bln);
            END IF;/* end audit */
            /*
            ** If this is the first pallet in the stack then put the stack down.
            */
            IF l_index=l_pindex THEN
                io_drop:=io_drop + i_e_rec.ppof;
                IF g_forklift_audit = 1 THEN
                    pl_lm_goaltime.lmg_audit_movement('PPOF', g_audit_batch_no, i_e_rec, 1, 'Put stack down.');

                END IF;
            END IF;

            /*
            **  If there are open positions in the slot and this is not a
            **  drop to home batch then put the pallet in the slot otherwise
            **  handstack.
            */
            IF (l_pallets_in_slot < l_adj_num_positions) AND (lmf.droptohomebatch(i_pals(l_index).batch_no) = 0) THEN
                /*
                **  There are open positions in the slot and its not a drop to home.
                **
                **  If this is the first pallet in the stack then remove one
                **  pallet from the slot.  The rule is the forklift operator
                **  is given credit to remove one pallet from the slot.
                */
                IF l_index = l_pindex THEN
                    io_drop:= io_drop + i_e_rec.bt90 + i_e_rec.apidd + pl_lm_goal_pb.RaiseEmpty(l_slot_height, i_e_rec) + i_e_rec.mepidd + pl_lm_goal_pb.LowerLoaded(l_slot_height, i_e_rec) + i_e_rec.bt90 + i_e_rec.ppof;
                    l_pallet_removed := TRUE;       
                    IF g_forklift_audit=1 THEN
                        pl_lm_goaltime.lmg_audit_movement('BT90', g_audit_batch_no, i_e_rec, 1, 'For double deep home slots always give time to remove one pallet from the slot for rotation.');
                        pl_lm_goaltime.lmg_audit_movement('APIDD', g_audit_batch_no, i_e_rec, 1, NULL);
                        pl_lm_goaltime.lmg_audit_movement('RE', g_audit_batch_no, i_e_rec, l_slot_height, NULL);
                        pl_lm_goaltime.lmg_audit_movement('MEPIDD', g_audit_batch_no, i_e_rec, 1, NULL);
                        pl_lm_goaltime.lmg_audit_movement('LL', g_audit_batch_no, i_e_rec, l_slot_height, NULL);
                        pl_lm_goaltime.lmg_audit_movement('BT90', g_audit_batch_no, i_e_rec, 1, NULL);
                        pl_lm_goaltime.lmg_audit_movement('PPOF', g_audit_batch_no, i_e_rec, 1, NULL);                            
                    END IF;          
                END IF;
                /*
                **  Put the pallet in the slot.
                */

                IF i_num_pallets = 1 THEN
                    /*
                    **  There is one pallet in the pallet stack.
                    **  Pickup the pallet and put it in the slot.
                    */
                    io_drop := io_drop + i_e_rec.bp + i_e_rec.apof + i_e_rec.mepof + i_e_rec.bt90 + i_e_rec.apidd + pl_lm_goal_pb.RaiseLoaded(l_slot_height, i_e_rec) + i_e_rec.ppidd + pl_lm_goal_pb.LowerEmpty(l_slot_height, i_e_rec) + i_e_rec.bt90;                          
                    IF g_forklift_audit=1 THEN
                        pl_lm_goaltime.lmg_audit_movement('BP', g_audit_batch_no, i_e_rec, 1, 'Put pallet '||i_pals(l_index).pallet_id||' in home slot '||i_pals(l_index).dest_loc||'.');
                        pl_lm_goaltime.lmg_audit_movement('APOF', g_audit_batch_no, i_e_rec, 1, NULL);
                        pl_lm_goaltime.lmg_audit_movement('MEPOF', g_audit_batch_no, i_e_rec, 1, NULL);
                        pl_lm_goaltime.lmg_audit_movement('BT90', g_audit_batch_no, i_e_rec, 1, NULL);
                        pl_lm_goaltime.lmg_audit_movement('APIDD', g_audit_batch_no, i_e_rec, 1, NULL);
                        pl_lm_goaltime.lmg_audit_movement('RL', g_audit_batch_no, i_e_rec, l_slot_height, NULL);
                        pl_lm_goaltime.lmg_audit_movement('PPIDD', g_audit_batch_no, i_e_rec, 1, NULL);
                        pl_lm_goaltime.lmg_audit_movement('LE', g_audit_batch_no, i_e_rec, l_slot_height, NULL);
                        pl_lm_goaltime.lmg_audit_movement('BT90', g_audit_batch_no, i_e_rec, 1, NULL);
                    END IF; /* end audit */
                ELSE
                    /*
                    **  There is more than one pallet in the pallet stack.
                    **
                    **  Take off the top pallet and put it in the slot.
                    */
                    IF g_forklift_audit=1 THEN
                        pl_lm_goaltime.lmg_audit_cmt(g_audit_batch_no, 'Remove pallet '||i_pals(l_index).pallet_id||' from top of stack.', -1);
                    END IF;

                    IF l_index = l_pindex THEN
                        /*
                        **  First pallet being processed.
                        **  Get the top pallet off the stack.
                        */
                        io_drop :=io_drop+ i_e_rec.bp + i_e_rec.apos + pl_lm_goal_pb.RaiseEmpty(l_pallet_height, i_e_rec) + i_e_rec.mepos;
                        IF g_forklift_audit=1 THEN
                            /*
                            **  The BP is for maneuvering away from the pallet
                            **  removed from the slot.
                            */
                            pl_lm_goaltime.lmg_audit_movement('BP', g_audit_batch_no, i_e_rec, 1, NULL);
                            pl_lm_goaltime.lmg_audit_movement('APOS', g_audit_batch_no, i_e_rec, 1, NULL);
                            pl_lm_goaltime.lmg_audit_movement('RE', g_audit_batch_no, i_e_rec, l_pallet_height, NULL);
                            pl_lm_goaltime.lmg_audit_movement('MEPOS', g_audit_batch_no, i_e_rec, 1, NULL);
                        END IF;
                    ELSE
                        /*
                        **  The previous pallet has been put in the slot, remove
                        **  the top pallet from the stack.  The forks are at the
                        **  level of the slot.
                        */
                        IF l_slot_height > l_pallet_height THEN
                            io_drop := io_drop + pl_lm_goal_pb.LowerEmpty(l_slot_height - l_pallet_height, i_e_rec);
                            IF g_forklift_audit = 1 THEN
                                pl_lm_goaltime.lmg_audit_movement('LE', g_audit_batch_no, i_e_rec, l_slot_height - l_pallet_height, NULL);
                            END IF;
                        ELSE
                            io_drop := io_drop + pl_lm_goal_pb.RaiseEmpty(l_pallet_height - l_slot_height, i_e_rec);
                            IF g_forklift_audit=1  THEN
                                pl_lm_goaltime.lmg_audit_movement('RE', g_audit_batch_no, i_e_rec, l_pallet_height - l_slot_height, NULL);
                            END IF;
                        END IF;

                        IF l_index = 0 THEN
                            /*
                            **  At the last pallet in the stack so it is
                            **  on the floor.
                            */
                            io_drop := io_drop + i_e_rec.apof + i_e_rec.mepof;
                            IF g_forklift_audit =1  THEN
                                pl_lm_goaltime.lmg_audit_movement('APOF', g_audit_batch_no, i_e_rec, 1, NULL);
                                pl_lm_goaltime.lmg_audit_movement('MEPOF', g_audit_batch_no, i_e_rec, 1, NULL);
                            END IF;
                        ELSE
                            /*
                            **  The stack has more than one pallet.
                            */
                            io_drop := io_drop + i_e_rec.apos + i_e_rec.mepos;

                            IF g_forklift_audit=1 THEN
                                pl_lm_goaltime.lmg_audit_movement('APOS', g_audit_batch_no, i_e_rec, 1, NULL);
                                pl_lm_goaltime.lmg_audit_movement('MEPOS', g_audit_batch_no, i_e_rec, 1, NULL);
                            END IF;
                        END IF;
                    END IF;
                    /*
                    **  The pallet is on the forks.  Move the forks up or down as
                    **  appropriate and put the pallet in the slot.
                    */
                    IF l_slot_height > l_pallet_height THEN
                        io_drop := io_drop + i_e_rec.bt90 + i_e_rec.apidd + pl_lm_goal_pb.RaiseLoaded((l_slot_height - l_pallet_height), i_e_rec) + i_e_rec.ppidd + i_e_rec.bt90;
                    ELSE               
                        io_drop := io_drop + i_e_rec.bt90 + i_e_rec.apidd + pl_lm_goal_pb.LowerLoaded((l_pallet_height - l_slot_height), i_e_rec) + i_e_rec.ppidd + i_e_rec.bt90;                             
                    END IF;

                    IF g_forklift_audit=1 THEN
                        IF l_slot_height > l_pallet_height THEN
                            pl_lm_goaltime.lmg_audit_movement('BT90', g_audit_batch_no, i_e_rec, 1, 'Put pallet '||i_pals(l_index).pallet_id||' in home slot '||i_pals(l_index).dest_loc||'.');
                            pl_lm_goaltime.lmg_audit_movement('APIDD', g_audit_batch_no, i_e_rec, 1, NULL);
                            pl_lm_goaltime.lmg_audit_movement('RL', g_audit_batch_no, i_e_rec, l_slot_height - l_pallet_height, NULL);
                            pl_lm_goaltime.lmg_audit_movement('PPIDD', g_audit_batch_no, i_e_rec, 1, NULL);
                            pl_lm_goaltime.lmg_audit_movement('BT90', g_audit_batch_no, i_e_rec, 1, NULL);
                        ELSE
                            pl_lm_goaltime.lmg_audit_movement('BT90', g_audit_batch_no, i_e_rec, 1, 'Put pallet '||i_pals(l_index).pallet_id||' in home slot '||i_pals(l_index).dest_loc||'.');
                            pl_lm_goaltime.lmg_audit_movement('APIDD', g_audit_batch_no, i_e_rec, 1, NULL);
                            pl_lm_goaltime.lmg_audit_movement('LL', g_audit_batch_no, i_e_rec, l_pallet_height - l_slot_height, NULL);
                            pl_lm_goaltime.lmg_audit_movement('PPIDD', g_audit_batch_no, i_e_rec, 1, NULL);
                            pl_lm_goaltime.lmg_audit_movement('BT90', g_audit_batch_no, i_e_rec, 1, NULL);
                        END IF; 
                    END IF; /* end audit */ 
                END IF;
                /*
                ** If this is the first pallet in the stack going to the slot
                ** and the qoh in the slot is less than a full pallet and it is
                ** a multi-face slot then give credit to handstack qoh/2 cases.
                */ 

                IF (l_index = l_pindex AND l_prev_qoh < l_splits_per_pallet AND l_multi_face_slot_bln =1) THEN
                    l_handstack_cases := (l_prev_qoh / l_spc) / 2;
                    l_handstack_splits := 0;
                    rf_status:=pl_lm_forklift.lmf_update_batch_kvi(i_pals(l_index).batch_no, l_handstack_cases, l_handstack_splits);
                    IF g_forklift_audit=1 THEN
                        pl_lm_goaltime.lmg_audit_cmt(g_audit_batch_no, 'Multi-face slot and less than a full pallet in the slot.  Give credit to handstack '||l_handstack_cases||' case(s) which is the qoh / 2.', -1);   
                    END IF;             
                END IF;
                l_pallets_in_slot :=l_pallets_in_slot+1;
            ELSE
                /*
                **  There are no open positions in the slot or this is a
                **  drop to home batch.  Handstack.
                **
                **  Remove pallet from the slot.  The forklift operator should
                **  be removing the pallet that has the fewest cases if
                **  there are multiple pallets in the slot.
                */
                io_drop := io_drop + i_e_rec.bt90 + i_e_rec.apidd + pl_lm_goal_pb.RaiseEmpty(l_slot_height, i_e_rec) + i_e_rec.mepidd + pl_lm_goal_pb.LowerLoaded(l_slot_height, i_e_rec) + i_e_rec.bt90 + i_e_rec.ppof;
                IF g_forklift_audit=1 THEN      
                    /*
                    ** Leave out audit message if drop to home.
                    */
                    IF  lmf.DropToHomeBatch(i_pals(l_index).batch_no)=0 THEN
                        pl_lm_goaltime.lmg_audit_cmt(g_audit_batch_no, 'There are no open positions in home slot '||i_pals(l_index).dest_loc||'.  Handstack.', -1);
                    END IF;
                    pl_lm_goaltime.lmg_audit_movement('BT90', g_audit_batch_no, i_e_rec, 1, 'Pull pallet from home slot.');                    
                    pl_lm_goaltime.lmg_audit_movement('APIDD', g_audit_batch_no, i_e_rec, 1, NULL);                      
                    pl_lm_goaltime.lmg_audit_movement('RE', g_audit_batch_no, i_e_rec, l_slot_height, NULL);                       
                    pl_lm_goaltime.lmg_audit_movement('MEPIDD', g_audit_batch_no, i_e_rec, 1, NULL);                           
                    pl_lm_goaltime.lmg_audit_movement('LL', g_audit_batch_no, i_e_rec, l_slot_height, NULL);                        
                    pl_lm_goaltime.lmg_audit_movement('BT90', g_audit_batch_no, i_e_rec, 1, NULL);                          
                    pl_lm_goaltime.lmg_audit_movement('PPOF', g_audit_batch_no, i_e_rec, 1, NULL);

                END IF;  /* end audit */    
                /*
                **  If there is more than 1 pallet in the stack then get the top
                **  pallet and lower it to the floor.
                */
                IF l_index > 0 THEN
                    io_drop := io_drop + i_e_rec.bp + i_e_rec.apos + pl_lm_goal_pb.RaiseEmpty(l_pallet_height, i_e_rec) + i_e_rec.mepos + pl_lm_goal_pb.LowerLoaded(l_pallet_height, i_e_rec);
                    IF g_forklift_audit=1 THEN
                        pl_lm_goaltime.lmg_audit_movement('BP', g_audit_batch_no, i_e_rec, 1, 'Remove pallet '||i_pals(l_index).pallet_id||' from top of stack and lower to the floor.');                      
                        pl_lm_goaltime.lmg_audit_movement('APOS', g_audit_batch_no, i_e_rec, 1, NULL);                  
                        pl_lm_goaltime.lmg_audit_movement('RE', g_audit_batch_no, i_e_rec, l_pallet_height, NULL);                        
                        pl_lm_goaltime.lmg_audit_movement('MEPOS', g_audit_batch_no, i_e_rec, 1, NULL);                           
                        pl_lm_goaltime.lmg_audit_movement('LL', g_audit_batch_no, i_e_rec, l_pallet_height, NULL);                       
                    END IF;/* end audit */
                END IF;
                /*
                **  Handstack the appropriate qty.
                */
                IF l_last_pal_qty <= l_pallet_qty AND lmf.DropToHomeBatch(i_pals(l_index).batch_no)=0 THEN
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
                    IF l_index = 0 THEN
                        io_drop := io_drop + i_e_rec.bp + i_e_rec.apof + i_e_rec.mepof;
                    END IF;

                    IF i_pals(l_index).uom = 1 THEN
                        /*
                        ** Split home.
                        */
                        IF l_apply_credit_at_case_level=1 THEN
                            /*
                            ** Case up splits.
                            */
                            l_handstack_cases := l_last_pal_qty / l_spc;
                            l_handstack_splits := MOD(l_last_pal_qty, l_spc);
                            IF g_forklift_audit=1 THEN
                                pl_lm_goaltime.lmg_audit_cmt(g_audit_batch_no, 'Syspar \"Split RPL Credit at Case Level\" is set to "Y" so credit will be applied at the case level.', -1);
                            END IF;
                        ELSE
                            l_handstack_cases := 0;
                            l_handstack_splits := l_last_pal_qty; 
                            IF g_forklift_audit=1 THEN
                                pl_lm_goaltime.lmg_audit_cmt(g_audit_batch_no, 'Syspar \"Split RPL Credit at Case Level\" is set to "N" so credit will be applied at the split level.', -1);
                            END IF;
                        END IF;
                    ELSE
                        /*
                        ** Case home which can have splits.
                        */
                        l_handstack_cases := l_last_pal_qty/l_spc;
                        l_handstack_splits := MOD(l_last_pal_qty, l_spc);
                    END IF;
                    IF g_forklift_audit=1 THEN
                        IF l_index = 0 THEN
                            pl_lm_goaltime.lmg_audit_movement('BP', g_audit_batch_no, i_e_rec, 1, 'Position the new pallet on the forks.');  
                            pl_lm_goaltime.lmg_audit_movement('APOF', g_audit_batch_no, i_e_rec, 1, NULL);
                            pl_lm_goaltime.lmg_audit_movement('MEPOF', g_audit_batch_no, i_e_rec, 1, NULL);
                        END IF;
                        pl_lm_goaltime.lmg_audit_cmt(g_audit_batch_no, 'Handstack the '||l_handstack_cases||' case(s) and '||l_handstack_splits||' split(s) on the pallet pulled from the slot onto the new pallet.', -1);
                    END IF; /* end audit */
                ELSE
                    /*
                    **  The number of pieces on the pallet pulled from the
                    **  home slot is > the number of pieces on the new pallet
                    **  or this is a drop to home batch.
                    **  Handstack the pieces on the new pallet onto the pallet
                    **  pulled from the home slot.
                    */   
                    IF i_pals(l_index).uom = 1 THEN
                        /*
                        ** Split home.
                        */
                        IF l_apply_credit_at_case_level=1 OR lmf.DropToHomeBatch(i_pals(l_index).batch_no)=1 THEN
                            /*
                            ** Case up the splits.
                            */
                            l_handstack_cases := l_pallet_qty / l_spc;
                            l_handstack_splits := MOD(l_pallet_qty, l_spc); 
                            /*
                            ** Leave out audit message if drop to home.
                            */
                            IF g_forklift_audit=1 AND  lmf.DropToHomeBatch(i_pals(l_index).batch_no)=0 THEN
                                pl_lm_goaltime.lmg_audit_cmt(g_audit_batch_no, 'Syspar \"Split RPL Credit at Case Level\" is set to "Y" so credit will be applied at the case level.', -1);
                            END IF;
                        ELSE
                            l_handstack_cases := 0;
                            l_handstack_splits := l_pallet_qty; 
                            /*
                            ** Leave out audit message if drop to home.
                            */
                            IF g_forklift_audit=1 AND  lmf.DropToHomeBatch(i_pals(l_index).batch_no)=0 THEN
                                pl_lm_goaltime.lmg_audit_cmt(g_audit_batch_no, 'Syspar \"Split RPL Credit at Case Level\" is set to "N" so credit will be applied at the case level.', -1);
                            END IF;
                        END IF;
                    ELSE
                        /*
                        ** Case home which can have splits.
                        */
                        l_handstack_cases := l_pallet_qty / l_spc;
                        l_handstack_splits := MOD(l_pallet_qty, l_spc);
                    END IF;
                    /* 
                    **  If there was more than one pallet in the stack then 
                    **  the pallet removed from the top of the stack is on
                    **  the forks.  The pallet pulled from the slot is the
                    **  pallet to put in the slot so position the forks on
                    **  this pallet.
                    */ 
                    IF l_index > 0 THEN
                        io_drop := io_drop + i_e_rec.bp + i_e_rec.apof + i_e_rec.mepof;
                    END IF;

                    IF g_forklift_audit=1 THEN
                        IF lmf.DropToHomeBatch(i_pals(l_index).batch_no)=1 THEN
                            l_message:='bulk pull';
                        ELSE
                            l_message:='new';
                        END IF;
                        pl_lm_goaltime.lmg_audit_cmt(g_audit_batch_no, 'Handstack the '||l_handstack_cases||' case(s) and '||l_handstack_splits||' split(s) on the '||l_message||' pallet onto the pallet pulled from home slot '||i_pals(l_index).dest_loc||'.', -1);  
                        IF l_index > 0 THEN
                            pl_lm_goaltime.lmg_audit_movement('BP', g_audit_batch_no, i_e_rec, 1, 'Position the pallet pulled from the home slot on the forks.');
                            pl_lm_goaltime.lmg_audit_movement('APOF', g_audit_batch_no, i_e_rec, 1, NULL);
                            pl_lm_goaltime.lmg_audit_movement('MEPOF', g_audit_batch_no, i_e_rec, 1, NULL);
                        END IF;
                    END IF; /* end audit */   
                END IF;
                /*
                **  Put pallet in slot.  This will be either the pallet pulled from
                **  the home slot or the new pallet.
                */
                io_drop := i_e_rec.ds + i_e_rec.bt90 + i_e_rec.apidd + pl_lm_goal_pb.RaiseLoaded(l_slot_height, i_e_rec) + i_e_rec.ppidd + pl_lm_goal_pb.LowerEmpty(l_slot_height, i_e_rec) + i_e_rec.bt90;                      
                IF g_forklift_audit=0 THEN
                    pl_lm_goaltime.lmg_audit_movement('DS', g_audit_batch_no, i_e_rec, 1, 'Put pallet in home slot.');
                    pl_lm_goaltime.lmg_audit_movement('BT90', g_audit_batch_no, i_e_rec, 1, NULL);                
                    pl_lm_goaltime.lmg_audit_movement('APIDD', g_audit_batch_no, i_e_rec, 1, NULL); 
                    pl_lm_goaltime.lmg_audit_movement('RL', g_audit_batch_no, i_e_rec, l_slot_height, NULL);
                    pl_lm_goaltime.lmg_audit_movement('PPIDD', g_audit_batch_no, i_e_rec, 1, NULL);
                    pl_lm_goaltime.lmg_audit_movement('LE', g_audit_batch_no, i_e_rec, l_slot_height, NULL);
                    pl_lm_goaltime.lmg_audit_movement('BT90', g_audit_batch_no, i_e_rec, 1, NULL);                 
                END IF;/* end audit */
                l_last_pal_qty := i_pals(l_index).qty_on_pallet;
                rf_status:=pl_lm_forklift.lmf_update_batch_kvi(i_pals(l_index).batch_no, l_handstack_cases, l_handstack_splits);                   
            END IF; /* end else of if (l_pallets_in_slot < l_adj_num_positions) */
            l_pallet_height := l_pallet_height - STD_PALLET_HEIGHT;
            l_prev_qoh := l_prev_qoh + l_pallet_qty;
            l_pindex:=l_pindex-1;
            l_index:=l_index+1;
            pl_text_log.ins_msg_async('INFO', l_func_name, ' io_drop '||io_drop , sqlcode, sqlerrm);
        END LOOP; /* end for loop */
        /*
        **  If a pallet was removed from the home slot then put it back.
        */
        IF l_pallet_removed = 1 THEN
            IF i_num_pallets > 1 THEN
                /*
                **  If there was more than one pallet in the stack then the
                **  forks are currently at the slot height.  Lower the forks
                **  to the floor.
                */
                io_drop := pl_lm_goal_pb.LowerEmpty(l_slot_height, i_e_rec);
                IF g_forklift_audit = 1 THEN
                    pl_lm_goaltime.lmg_audit_movement('LE', g_audit_batch_no, i_e_rec, l_slot_height, NULL);                       
                END IF;
            END IF;
            io_drop := i_e_rec.apof + i_e_rec.mepof + i_e_rec.bt90 + i_e_rec.apidd + pl_lm_goal_pb.RaiseLoaded(l_slot_height, i_e_rec) + i_e_rec.ppidd + pl_lm_goal_pb.LowerEmpty(l_slot_height, i_e_rec) + i_e_rec.bt90;
            IF g_forklift_audit = 1 THEN
                pl_lm_goaltime.lmg_audit_movement('APOF', g_audit_batch_no, i_e_rec, 1, 'Put back the pallet removed from the slot.');
                pl_lm_goaltime.lmg_audit_movement('MEPOF', g_audit_batch_no, i_e_rec, 1, NULL);
                pl_lm_goaltime.lmg_audit_movement('BT90', g_audit_batch_no, i_e_rec, 1, NULL);
                pl_lm_goaltime.lmg_audit_movement('APIDD', g_audit_batch_no, i_e_rec, 1, NULL);
                pl_lm_goaltime.lmg_audit_movement('RL', g_audit_batch_no, i_e_rec, l_slot_height, NULL);                        
                pl_lm_goaltime.lmg_audit_movement('PPIDD', g_audit_batch_no, i_e_rec, 1, NULL);
                pl_lm_goaltime.lmg_audit_movement('LE', g_audit_batch_no, i_e_rec, l_slot_height, NULL);
                pl_lm_goaltime.lmg_audit_movement('BT90', g_audit_batch_no, i_e_rec, 1, NULL);
            END IF;
        END IF;
        /*
        ** Pickup stack if there are pallets left and go to the
        ** next destination.
        */
        IF l_i >= 0 THEN
            /*
            ** There are pallets still in the travel stack.
            ** Pick up stack and go to next destination.
            */
            pl_lm_goaltime.lmg_pickup_for_next_dst(i_pals, l_i, i_e_rec, io_drop);
        END IF;
		pl_text_log.ins_msg_async('INFO', l_func_name,'ending lmgdd_dro_dbl_deep_hm_qoh', sqlcode, sqlerrm);
    END lmgdd_dro_dbl_deep_hm_qoh; /* end lmgdd_dro_dbl_deep_hm_qoh */

    /*****************************************************************************
    **  PROCEDURE:
    **      lmgdd_drp_dbl_deep_res_qoh()
    **
    **  DESCRIPTION:
    **      This functions calculates the LM drop discreet value for a pallet
    **      going to a reserve double deep destination where inventory already
    **      exists.
    **
    **  PARAMETERS:
    **      i_pals         - Pointer to pallet list.
    **      i_num_pallets  - Number of pallets in pallet list.
    **      i_e_rec        - Pointer to equipment tmu values.
    **      i_inv          - Pointer to pallets already in the destination.
    **      i_is_same_item - Flag denoting if the same item is already in the
    **                       destination location.
    **      io_drop        - Outgoing drop value.
    **
    **  RETURN VALUES:
    **      None.
    *****************************************************************************/
	
    PROCEDURE lmgdd_drp_dbl_deep_res_qoh (
        i_pals  		IN 		pl_lm_goal_pb.tbl_lmg_pallet_rec,
        i_num_pallets 	IN 		NUMBER,
        i_e_rec 		IN 		pl_lm_goal_pb.type_lmc_equip_rec,
        i_num_recs      IN 		NUMBER,
        i_inv 			IN 		pl_lm_goal_pb.tbl_lmg_inv_rec,
        i_is_same_item 	IN 		VARCHAR2,
        io_drop 		IN OUT 	NUMBER
    ) 
    IS
        l_func_name 		VARCHAR2(60) := 'pl_lm_goal_dd.lmgdd_drp_dbl_deep_res_qoh';	
        l_pindex 			NUMBER;			 										/* Index of top pallet on stack */
        l_slot_height 		NUMBER;    												/* Height from floor to slot */
        l_pallet_height 	NUMBER;  												/* Height from floor to pallet on top of stack */
        l_i 				NUMBER;
		
    BEGIN
        /*
        **  Always removing the top pallet on the stack.
        */
        l_pindex := i_num_pallets - 1;
        l_slot_height := i_pals(l_pindex).height;
        l_pallet_height := STD_PALLET_HEIGHT * l_pindex;
        pl_text_log.ins_msg_async('INFO', l_func_name,i_pals(l_pindex).pallet_id||', '||i_num_pallets||', '||i_e_rec.equip_id||')' , sqlcode, sqlerrm);
        IF g_forklift_audit = 1 THEN
            pl_lm_goaltime.lmg_audit_cmt(g_audit_batch_no, 'Drop pallet '||i_pals(l_pindex).pallet_id||' to '||i_pals(l_pindex).slot_type
					||' '||i_pals(l_pindex).pallet_type||' double deep reserve slot '||i_pals(l_pindex).dest_loc||'.', -1);
        END IF;
        /*
        **  If this is a multi pallet drop to same slot, these values are only
        **  added to the previous pallet values.
        */
        IF i_pals(l_pindex).multi_pallet_drop_to_slot = 'N' THEN
            /*
            **  Not a multi pallet drop to slot--the previous pallet in the
            **  stack did not go to this slot.  If there is one pallet in the
            **  stack and the same item is not already in the slot then
            **  the pallet will be placed directly in the slot otherwise
            **  the stack will be put down.
            */
            IF (i_num_pallets = 1) AND (i_is_same_item = 'N') THEN
                /*
                ** The pallet will go directly in the slot.
                */
                io_drop := i_e_rec.tir;
                IF g_forklift_audit = 1 THEN
                    pl_lm_goaltime.lmg_audit_movement('TIR', g_audit_batch_no, i_e_rec, 1, 'One pallet in the stack and the item is not already in the slot');
                END IF;
            ELSE
                io_drop := i_e_rec.ppof;
                IF g_forklift_audit = 1 THEN
                    pl_lm_goaltime.lmg_audit_movement('PPOF', g_audit_batch_no, i_e_rec, 1, NULL);                                      
                END IF;
            END IF;
            /*
            **  Take current inventory out of slot if same item is in the slot.
            **  The assumption is if the same item is in the slot then it is at
            **  the back of the slot.  The new pallet needs to go behind the 
            **  pallets already in the slot so all the pallets need to be 
            **  removed from the slot.
            */
            IF i_is_same_item = 'Y' THEN
                l_i :=0;
                WHILE l_i < i_num_recs
                LOOP
                    io_drop := io_drop + i_e_rec.bt90 + i_e_rec.apidd + pl_lm_goal_pb.RaiseEmpty(l_slot_height, i_e_rec) 
								+ i_e_rec.mepidd + pl_lm_goal_pb.LowerLoaded(l_slot_height, i_e_rec) + i_e_rec.bt90 + i_e_rec.ppof;
                    IF g_forklift_audit=1 THEN
                        IF l_i = 0 THEN
                            pl_lm_goaltime.lmg_audit_cmt(g_audit_batch_no, 'The same item is in slot '||i_pals(l_pindex).dest_loc
											||'.  Remove the '||i_num_recs||' pallets currently in the slot.', -1);
                            pl_lm_goaltime.lmg_audit_cmt(g_audit_batch_no, 'Pallet '||i_pals(l_pindex).pallet_id||' will be put in the back of the slot.', -1);
                        END IF;
                        pl_lm_goaltime.lmg_audit_movement('BT90', g_audit_batch_no, i_e_rec, 1, NULL);                        
                        pl_lm_goaltime.lmg_audit_movement('APIDD', g_audit_batch_no, i_e_rec, 1, NULL);                                               
                        pl_lm_goaltime.lmg_audit_movement('RE', g_audit_batch_no, i_e_rec, l_slot_height, NULL);                                          
                        pl_lm_goaltime.lmg_audit_movement('MEPIDD', g_audit_batch_no, i_e_rec, 1, NULL);
                        pl_lm_goaltime.lmg_audit_movement('LL', g_audit_batch_no, i_e_rec, l_slot_height, NULL);
                        pl_lm_goaltime.lmg_audit_movement('BT90', g_audit_batch_no, i_e_rec, 1, NULL);
                        pl_lm_goaltime.lmg_audit_movement('PPOF', g_audit_batch_no, i_e_rec, 1, NULL);                                
                    END IF;/* end audit */
                    l_i :=l_i + 1;
                END LOOP;
            END IF;
        END IF;
        /*
        **  Put new pallet into slot.
        */
        IF i_num_pallets = 1 THEN
            /*
            **  There is one pallet in the stack.
            */
            IF i_is_same_item = 'Y' THEN
                /*
                 **  The existing pallets in the slot have been removed.
                 **  Pickup the new pallet.
                 */
                 io_drop := i_e_rec.bp + i_e_rec.apof + i_e_rec.mepof + i_e_rec.bt90;
                 IF g_forklift_audit = 1 THEN
                    pl_lm_goaltime.lmg_audit_movement('BP', g_audit_batch_no, i_e_rec, 1, 'Pickup pallet '||i_pals(l_pindex).pallet_id);
                    pl_lm_goaltime.lmg_audit_movement('APOF', g_audit_batch_no, i_e_rec, 1, NULL);                          
                    pl_lm_goaltime.lmg_audit_movement('MEPOF', g_audit_batch_no, i_e_rec, 1, NULL);
                    pl_lm_goaltime.lmg_audit_movement('BT90', g_audit_batch_no, i_e_rec, 1, NULL);
                 END IF;        
            END IF;
            /*
            **  Put the new pallet in the slot.
            */
            io_drop := i_e_rec.apidd + pl_lm_goal_pb.RaiseLoaded(l_slot_height, i_e_rec) + i_e_rec.ppidd 
						+ pl_lm_goal_pb.LowerEmpty(l_slot_height, i_e_rec) + i_e_rec.bt90;
            IF g_forklift_audit = 1 THEN
                pl_lm_goaltime.lmg_audit_movement('APIDD', g_audit_batch_no, i_e_rec, 1, NULL);
                pl_lm_goaltime.lmg_audit_movement('RL', g_audit_batch_no, i_e_rec, l_slot_height, NULL);                          
                pl_lm_goaltime.lmg_audit_movement('PPIDD', g_audit_batch_no, i_e_rec, 1, NULL);
                pl_lm_goaltime.lmg_audit_movement('LE', g_audit_batch_no, i_e_rec, l_slot_height, NULL);
                pl_lm_goaltime.lmg_audit_movement('BT90', g_audit_batch_no, i_e_rec, 1, NULL);
            END IF;
        ELSIF i_num_pallets > 1 THEN
            /*
            **  There is more than one pallet in the stack.  Get the top pallet
            **  from the stack and put it in the slot.
            */
            io_drop := io_drop + i_e_rec.bp + i_e_rec.apos + pl_lm_goal_pb.RaiseEmpty(l_pallet_height, i_e_rec) + i_e_rec.mepos + i_e_rec.bt90 + i_e_rec.apidd;
            /*
            **  If to-slot is higher than from-slot then raise to to-slot.
            **  else lower to to-slot.
            */
            IF l_slot_height > l_pallet_height THEN
                io_drop := io_drop + pl_lm_goal_pb.RaiseLoaded((l_slot_height - l_pallet_height), i_e_rec);
            ELSE
                io_drop := io_drop + pl_lm_goal_pb.LowerLoaded((l_pallet_height - l_slot_height), i_e_rec);
            END IF;
            io_drop := io_drop + i_e_rec.ppidd + pl_lm_goal_pb.LowerEmpty(l_slot_height, i_e_rec) + i_e_rec.bt90;

            IF g_forklift_audit =1 THEN
                pl_lm_goaltime.lmg_audit_movement('BP', g_audit_batch_no, i_e_rec, 1, 'Get pallet from top of stack and put in slot');    
                pl_lm_goaltime.lmg_audit_movement('APOS', g_audit_batch_no, i_e_rec, 1, NULL);
                pl_lm_goaltime.lmg_audit_movement('RE', g_audit_batch_no, i_e_rec, l_pallet_height, NULL);
                pl_lm_goaltime.lmg_audit_movement('MEPOS', g_audit_batch_no, i_e_rec, 1, NULL);
                pl_lm_goaltime.lmg_audit_movement('BT90', g_audit_batch_no, i_e_rec, 1, NULL);
                pl_lm_goaltime.lmg_audit_movement('APIDD', g_audit_batch_no, i_e_rec, 1, NULL);
                IF l_slot_height > l_pallet_height THEN
                    pl_lm_goaltime.lmg_audit_movement('RL', g_audit_batch_no, i_e_rec, l_slot_height - l_pallet_height, NULL);
                ELSE
                    pl_lm_goaltime.lmg_audit_movement('LL', g_audit_batch_no, i_e_rec, l_pallet_height - l_slot_height, NULL);    
                END IF;
                pl_lm_goaltime.lmg_audit_movement('PPIDD', g_audit_batch_no, i_e_rec, 1, NULL);
                pl_lm_goaltime.lmg_audit_movement('LE', g_audit_batch_no, i_e_rec, l_slot_height, NULL);                         
                pl_lm_goaltime.lmg_audit_movement('BT90', g_audit_batch_no, i_e_rec, 1, NULL);
            END IF; /* end audit */              
        END IF;
        /*
        **  If this is a multi pallet drop to same slot, these values are only
        **  added to the previous pallet values.  If not a multi drop to the
        **  same slot and the item was already in the slot then put back the
        **  pallets removed from the slot.
        */
        IF i_pals(l_pindex).multi_pallet_drop_to_slot = 'N' THEN
            /*
            **  Replace existing inventory into slot if same item.
            */
            IF i_is_same_item = 'Y' THEN
                l_i := 0;
                WHILE l_i < i_num_recs
                LOOP
                    io_drop := io_drop + i_e_rec.apof + i_e_rec.mepof + i_e_rec.bt90 + i_e_rec.apidd + pl_lm_goal_pb.RaiseLoaded(l_slot_height, i_e_rec) 
								+ i_e_rec.mepidd + pl_lm_goal_pb.LowerEmpty(l_slot_height, i_e_rec) + i_e_rec.bt90;
                    IF g_forklift_audit=1 THEN
                        IF l_i = 0 THEN
                            pl_lm_goaltime.lmg_audit_cmt(g_audit_batch_no, 'Put back the '||i_num_recs||' pallets removed from the slot.', -1);
                        END IF;
                        pl_lm_goaltime.lmg_audit_movement('APOF', g_audit_batch_no, i_e_rec, 1, NULL);                 
                        pl_lm_goaltime.lmg_audit_movement('MEPOF', g_audit_batch_no, i_e_rec, 1, NULL);
                        pl_lm_goaltime.lmg_audit_movement('BT90', g_audit_batch_no, i_e_rec, 1, NULL);
                        pl_lm_goaltime.lmg_audit_movement('APIDD', g_audit_batch_no, i_e_rec, 1, NULL);
                        pl_lm_goaltime.lmg_audit_movement('RL', g_audit_batch_no, i_e_rec, l_slot_height, NULL);
                        pl_lm_goaltime.lmg_audit_movement('MEPIDD', g_audit_batch_no, i_e_rec, 1, NULL);
                        pl_lm_goaltime.lmg_audit_movement('LE', g_audit_batch_no, i_e_rec, l_slot_height, NULL);
                        pl_lm_goaltime.lmg_audit_movement('BT90', g_audit_batch_no, i_e_rec, 1, NULL);
                    END IF; /* end audit */
                    l_i := l_i + 1;
                END LOOP;
            END IF;
            /*
            ** Pickup stack if there are pallets left and go to the
            ** next destination.
            */
            IF i_num_pallets > 1 THEN
                /*
                ** There are pallets still in the travel stack.
                ** Pick up stack and go to next destination.
                */
                pl_lm_goaltime.lmg_pickup_for_next_dst(i_pals, l_pindex - 1, i_e_rec, io_drop);                    
            END IF;
        END IF;
		pl_text_log.ins_msg_async('INFO', l_func_name,'ending lmgdd_drp_dbl_deep_res_qoh', sqlcode, sqlerrm);
    END lmgdd_drp_dbl_deep_res_qoh; /* end lmgdd_drp_dbl_deep_res_qoh */
	
    /*****************************************************************************
    **  PROCEDURE:
    **      lmgdd_pkup_dbl_deep_res()
    **
    **  DESCRIPTION:
    **      This function calculates the LM drop discreet value for a pallet
    **      picked from a reserve double deep location.
    **      Pallets from reserve are not stacked.
    **      For different item in slot, assume that the needed pallet is last.
    **
    **  PARAMETERS:
    **      i_pals         - Pointer to pallet list.
    **      i_pindex       - Index of pallet being processed.
    **      i_e_rec        - Pointer to equipment tmu values.
    **      i_inv          - Pointer to pallets already in the destination.
    **      i_is_diff_item - Flag denoting if the different item is in the
    **                       destination location.
    **      io_pickup       - Outgoing pickup value.
    **
    **  RETURN VALUES:
    **      None.
    *****************************************************************************/ 
	
    PROCEDURE lmgdd_pkup_dbl_deep_res (
        i_pals           IN               pl_lm_goal_pb.tbl_lmg_pallet_rec,
        i_pal_num_recs   IN NUMBER,
        i_pindex         IN               NUMBER,
        i_e_rec          IN               pl_lm_goal_pb.type_lmc_equip_rec,
        i_num_recs       IN NUMBER,
        i_inv            IN               pl_lm_goal_pb.tbl_lmg_inv_rec,
        i_is_diff_item   IN               VARCHAR2,
        io_pickup        IN OUT           NUMBER
    )
    IS
        l_func_name 			VARCHAR2(60) := 'pl_lm_goal_dd.lmgdd_pkup_dbl_deep_res';
        l_ret_val 				NUMBER :=0;
        l_slot_height	 		NUMBER :=0;
        l_pallet_height 		NUMBER :=0; 
        l_num_pallets_in_slot 	NUMBER :=0;
        l_i 					NUMBER;
		
    BEGIN
        pl_text_log.ins_msg_async('INFO', l_func_name,' ('||i_pals(i_pindex).batch_no||', '||i_pindex||', '
						||i_e_rec.equip_id||', '||i_is_diff_item||')' , sqlcode, sqlerrm);
        l_slot_height := i_pals(i_pindex).height;
        l_num_pallets_in_slot := i_num_recs;
        l_pallet_height := STD_PALLET_HEIGHT * i_pindex;
        IF g_forklift_audit = 1 THEN
            pl_lm_goaltime.lmg_audit_cmt(g_audit_batch_no, 'Pickup pallet '||i_pals(i_pindex).pallet_id||' from '
			||i_pals(i_pindex).slot_type||' '||i_pals(i_pindex).pallet_type||' double deep reserve slot '||i_pals(i_pindex).loc||'.', -1);   
        END IF;

        IF i_pindex = 0 THEN
            io_pickup := i_e_rec.tir;
            IF g_forklift_audit = 1 THEN
                pl_lm_goaltime.lmg_audit_movement('TIR', g_audit_batch_no, i_e_rec, 1, NULL);
            END IF;
        ELSIF i_pindex > 0 THEN
            io_pickup := io_pickup + i_e_rec.bt90;
            IF g_forklift_audit = 1 THEN
                pl_lm_goaltime.lmg_audit_movement('BT90', g_audit_batch_no, i_e_rec, 1, NULL);
            END IF;
        END IF;

        /*
        ** If necessary remove the existing pallets from the slot to get
        ** to the one needed.
        **
        ** If i_pals->multi_pallet_drop_to_slot[i_pindex] is 'N' then this
        ** means the pallet picked before this (if there was one) did not come
        ** from the same slot.  If there was a pallet picked before this one
        ** and it came from the same slot then all the pallets have already been
        ** removed from the slot.  
        */
        IF i_pals(i_pindex).multi_pallet_drop_to_slot = 'N' THEN
            IF i_is_diff_item = 'Y' THEN
                /* Have a different item in slot, assume that the needed pallet
                ** is last.  Remove not needed pallets from rack.
                ** Pallets will not be stacked.
                */
                l_i :=0;
                WHILE l_i < l_num_pallets_in_slot
                LOOP 
                    io_pickup := io_pickup + i_e_rec.apidd + pl_lm_goal_pb.RaiseEmpty(l_slot_height, i_e_rec) + i_e_rec.mepidd 
								+ pl_lm_goal_pb.LowerLoaded(l_slot_height, i_e_rec) + i_e_rec.bt90 + i_e_rec.ppof + i_e_rec.bt90;
                    IF g_forklift_audit = 1 THEN
                        IF l_i = 0 THEN
                            pl_lm_goaltime.lmg_audit_cmt(g_audit_batch_no, 'Have different item in slot.  Remove not needed pallets ('||l_num_pallets_in_slot||' of them) from slot '||i_pals(i_pindex).loc||'.', -1);
                            pl_lm_goaltime.lmg_audit_cmt(g_audit_batch_no, 'Pallets will not be stacked.  Assume the needed pallet is last in the slot.', -1);
                            pl_lm_goaltime.lmg_audit_cmt(g_audit_batch_no, 'Have different item in slot.  Remove not needed pallets ('||l_num_pallets_in_slot||' of them) from slot '||i_pals(i_pindex).loc||'.', -1);
                        END IF;
                        pl_lm_goaltime.lmg_audit_movement('APIDD', g_audit_batch_no, i_e_rec, 1, 'Remove pallet from slot '||i_pals(i_pindex).loc||'.');                        
                        pl_lm_goaltime.lmg_audit_movement('RE', g_audit_batch_no, i_e_rec, l_slot_height, NULL);
                        pl_lm_goaltime.lmg_audit_movement('MEPIDD', g_audit_batch_no, i_e_rec, 1, NULL);
                        pl_lm_goaltime.lmg_audit_movement('LL', g_audit_batch_no, i_e_rec, l_slot_height, NULL);
                        pl_lm_goaltime.lmg_audit_movement('BT90', g_audit_batch_no, i_e_rec, 1, NULL);
                        pl_lm_goaltime.lmg_audit_movement('PPOF', g_audit_batch_no, i_e_rec, 1, NULL);
                        pl_lm_goaltime.lmg_audit_movement('BT90', g_audit_batch_no, i_e_rec, 1, NULL);
                    END IF;
                    l_i := l_i + 1;
                END LOOP;
            END IF;
        END IF;
        /*
        **  Remove needed pallet from rack.
        */
        io_pickup := i_e_rec.apidd;
        IF g_forklift_audit = 1 THEN
            pl_lm_goaltime.lmg_audit_movement('APIDD', g_audit_batch_no, i_e_rec, 1, 'Remove pallet '||i_pals(i_pindex).pallet_id||' from slot '||i_pals(i_pindex).loc||'.');                               
        END IF;
        /*
        ** Move the forks to the level of the needed pallet.
        */
        IF i_pals(i_pindex).multi_pallet_drop_to_slot = 'Y' THEN
            /*
            ** The previous pallet picked up came from this same slot.  The
            ** forks are at the height of where this previous pallet was placed.
            ** Move the forks up or down to get them at the same height as the
            ** pallet being removed from the slot.
            */
            IF l_slot_height > (STD_PALLET_HEIGHT * (i_pindex - 1)) THEN
                io_pickup := io_pickup + pl_lm_goal_pb.RaiseEmpty((l_slot_height - (STD_PALLET_HEIGHT * (i_pindex - 1))), i_e_rec);
                IF g_forklift_audit = 1 THEN
                    pl_lm_goaltime.lmg_audit_movement('RE', g_audit_batch_no, i_e_rec, (l_slot_height - (STD_PALLET_HEIGHT * (i_pindex - 1))), NULL);       
                END IF;
            ELSE
                io_pickup := io_pickup + pl_lm_goal_pb.LowerEmpty(((STD_PALLET_HEIGHT * (i_pindex - 1)) - l_slot_height), i_e_rec);
                IF g_forklift_audit= 1 THEN
                    pl_lm_goaltime.lmg_audit_movement('LE', g_audit_batch_no, i_e_rec, ((STD_PALLET_HEIGHT * (i_pindex - 1)) - l_slot_height), NULL);
                END IF;
            END IF;
        ELSE
            /*
            ** This is the first pallet picked up from this slot.  The forks will
            ** be at the floor.
            */
            io_pickup := io_pickup + pl_lm_goal_pb.RaiseEmpty(l_slot_height, i_e_rec);
            IF g_forklift_audit= 1 THEN
                pl_lm_goaltime.lmg_audit_movement('RE', g_audit_batch_no, i_e_rec, l_slot_height, NULL);
            END IF;                            
        END IF;
        /*
        ** The forks are at the level of the needed pallet. Get it out of the
        ** slot.
        */
        io_pickup := io_pickup + i_e_rec.mepidd;
        IF g_forklift_audit=1 THEN
            pl_lm_goaltime.lmg_audit_movement('MEPIDD', g_audit_batch_no, i_e_rec, 1, NULL);                          
        END IF;
        IF i_pindex > 0 THEN
            /*
            ** There are other pallets that have been picked up.  Put the pallet
            ** removed from the slot onto the stack.
            */
            IF l_pallet_height > l_slot_height THEN
                io_pickup := io_pickup + pl_lm_goal_pb.RaiseLoaded((l_pallet_height - l_slot_height), i_e_rec);
            ELSE
                io_pickup := pl_lm_goal_pb.LowerLoaded((l_slot_height - l_pallet_height), i_e_rec);
            END IF;
            io_pickup := io_pickup + i_e_rec.bt90 + i_e_rec.ppos;
            IF g_forklift_audit=1 THEN
                IF l_pallet_height > l_slot_height THEN
                    pl_lm_goaltime.lmg_audit_movement('RL', g_audit_batch_no, i_e_rec, l_pallet_height - l_slot_height, NULL);
                ELSE
                    pl_lm_goaltime.lmg_audit_movement('LL', g_audit_batch_no, i_e_rec, l_slot_height - l_pallet_height, NULL);
                    pl_lm_goaltime.lmg_audit_movement('BT90', g_audit_batch_no, i_e_rec, 1, NULL);
                    pl_lm_goaltime.lmg_audit_movement('PPOS', g_audit_batch_no, i_e_rec, 1, NULL);                       
                END IF;
            END IF;

            IF i_pindex = (i_pal_num_recs - 1) THEN
                io_pickup := io_pickup + pl_lm_goal_pb.LowerEmpty(l_pallet_height, i_e_rec);
                IF g_forklift_audit=1 THEN
                    pl_lm_goaltime.lmg_audit_movement('LE', g_audit_batch_no, i_e_rec, l_pallet_height, NULL);                         
                END IF;
            END IF;
        ELSE
            /*
            ** This is the first pallet picked up (there is nothing in the stack).
            */
            io_pickup := io_pickup + pl_lm_goal_pb.LowerLoaded(l_slot_height, i_e_rec) + i_e_rec.bt90;
            IF (i_pal_num_recs > 1) OR (i_is_diff_item = 'Y') THEN
                io_pickup := io_pickup + i_e_rec.ppof;
            END IF;
            IF g_forklift_audit=1 THEN
                pl_lm_goaltime.lmg_audit_movement('LL', g_audit_batch_no, i_e_rec, l_slot_height, NULL);                    
                pl_lm_goaltime.lmg_audit_movement('BT90', g_audit_batch_no, i_e_rec, 1, NULL);
                IF (i_pal_num_recs > 1) OR (i_is_diff_item = 'Y') THEN
                    pl_lm_goaltime.lmg_audit_movement('PPOF', g_audit_batch_no, i_e_rec, 1, NULL);                            
                END IF;
            END IF;
        END IF;
        /*
        ** If this is the last pallet to pickup from the slot and pallets were
        ** removed from the slot in order to get to the pallet then put these
        ** pallets back in the slot.
        */
        IF i_pals(i_pindex).multi_pallet_drop_to_slot = 'N' THEN
            IF i_is_diff_item = 'Y' THEN
                io_pickup := i_e_rec.bp;
                IF g_forklift_audit=1 THEN
                    pl_lm_goaltime.lmg_audit_movement('BP', g_audit_batch_no, i_e_rec, 1, NULL);
                END IF;
                /*
                **  Replace remaining pallets into rack.
                **  Pallets are not stacked.
                */
                l_i := 0;
                WHILE l_i < l_num_pallets_in_slot
                LOOP
                    io_pickup := io_pickup + i_e_rec.apof + i_e_rec.mepof + i_e_rec.bt90 + pl_lm_goal_pb.RaiseLoaded(l_slot_height, i_e_rec) + i_e_rec.apidd + i_e_rec.ppidd + pl_lm_goal_pb.LowerEmpty(l_slot_height, i_e_rec) + i_e_rec.bt90;
                    IF g_forklift_audit=1 THEN
                        IF l_i = 0 THEN
                            pl_lm_goaltime.lmg_audit_cmt(g_audit_batch_no, 'Put pallets ('||l_num_pallets_in_slot||' of them) back in slot '||i_pals(i_pindex).loc||'.', -1);
                        END IF;
                        pl_lm_goaltime.lmg_audit_movement('APOF', g_audit_batch_no, i_e_rec, 1, 'Put pallet back in slot '||i_pals(i_pindex).loc||'.');                   
                        pl_lm_goaltime.lmg_audit_movement('MEPOF', g_audit_batch_no, i_e_rec, 1, NULL);
                        pl_lm_goaltime.lmg_audit_movement('BT90', g_audit_batch_no, i_e_rec, 1, NULL);
                        pl_lm_goaltime.lmg_audit_movement('RL', g_audit_batch_no, i_e_rec, l_slot_height, NULL);
                        pl_lm_goaltime.lmg_audit_movement('APIDD', g_audit_batch_no, i_e_rec, 1, NULL);
                        pl_lm_goaltime.lmg_audit_movement('PPIDD', g_audit_batch_no, i_e_rec, 1, NULL);
                        pl_lm_goaltime.lmg_audit_movement('LE', g_audit_batch_no, i_e_rec, l_slot_height, NULL);
                        pl_lm_goaltime.lmg_audit_movement('BT90', g_audit_batch_no, i_e_rec, 1, NULL);
                    END IF;
                END LOOP;
            END IF;
        END IF;
        IF i_pindex = 0 THEN
            /*
            **  Pickup stack and go to next slot.
            */
            IF i_is_diff_item = 'Y' THEN
                io_pickup := io_pickup + i_e_rec.apof + i_e_rec.mepof;
                IF g_forklift_audit = 1 THEN
                    pl_lm_goaltime.lmg_audit_movement('APOF', g_audit_batch_no, i_e_rec, 1, NULL);                    
                    pl_lm_goaltime.lmg_audit_movement('MEPOF', g_audit_batch_no, i_e_rec, 1, NULL);
                END IF;
            ELSIF i_pal_num_recs > 1 THEN
                io_pickup := io_pickup + i_e_rec.bp + i_e_rec.apof + i_e_rec.mepof;
                IF g_forklift_audit=1 THEN
                    pl_lm_goaltime.lmg_audit_movement('BP', g_audit_batch_no, i_e_rec, 1, NULL);                      
                    pl_lm_goaltime.lmg_audit_movement('APOF', g_audit_batch_no, i_e_rec, 1, NULL);
                    pl_lm_goaltime.lmg_audit_movement('MEPOF', g_audit_batch_no, i_e_rec, 1, NULL);
                END IF;
            END IF;
        END IF;
		pl_text_log.ins_msg_async('INFO', l_func_name,'ending lmgdd_pkup_dbl_deep_res', sqlcode, sqlerrm);
    END lmgdd_pkup_dbl_deep_res; /* end lmgdd_pkup_dbl_deep_res */

END pl_lm_goal_dd;
/

grant execute on pl_lm_goal_dd  to swms_user;
