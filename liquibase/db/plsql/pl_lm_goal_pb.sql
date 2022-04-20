create or replace PACKAGE pl_lm_goal_pb AS
/*******************************************************************************
**Package:
**        pl_lm_goal_pb.
**
**  Description: This is a common package that contains the functions and subroutes 
**         necessary to calculate discreet Labor Management values for pushback racking.     
**                                                                                        
**Called by:
**        This is called from many packages.
*******************************************************************************/

    TYPE type_lmg_pallet_rec IS RECORD (
        pallet_id                       VARCHAR2(18),
        prod_id                         VARCHAR2(9),
        cpv                             VARCHAR2(10),
        qty_on_pallet                   NUMBER,
        loc                             VARCHAR2(11),
        dest_loc                        VARCHAR2(11),/* Used by pickup side */
        perm                            VARCHAR2(2),
        uom                             NUMBER,
        height                          NUMBER,
        slot_type                       VARCHAR2(4),
        deep_ind                        VARCHAR2(2),
        spc                             NUMBER,
        case_weight                     NUMBER,
        case_cube                       NUMBER,
        case_density                    NUMBER,
        ti                              NUMBER,
        hi                              NUMBER,
        exp_date                        NUMBER,
        multi_pallet_drop_to_slot       VARCHAR2(1),
        batch_no                        VARCHAR2(14),
        pallet_type                     VARCHAR2(3),
        min_qty                         NUMBER,
        min_qty_num_positions           NUMBER,
        flow_slot_type                  VARCHAR2(2),
        inv_loc                         VARCHAR2(11),
        batch_type                      VARCHAR2(2),
        demand_hst_active               VARCHAR2(2),
        actual_qty_dropped              NUMBER,
        hst_qty                         NUMBER,
        user_id                         VARCHAR2(30),
        add_hst_qty_to_dest_inv         VARCHAR2(2),
        msku_batch_flag                 VARCHAR2(2),
        msku_sort_order                 VARCHAR2(16),
        ignore_batch_flag               VARCHAR2(2),
        slot_desc                       VARCHAR2(10),
        slot_kind                       VARCHAR2(2),
        ref_batch_no                    VARCHAR2(14),
        miniload_reserve_put_back_flag  VARCHAR2(2),
        haul_sort_order                 NUMBER,
        dropped_for_a_break_away_flag   VARCHAR2(1),
        resumed_after_break_away_flag   VARCHAR2(1),
        break_away_haul_flag            VARCHAR2(1) 
        );
    TYPE tbl_lmg_pallet_rec IS TABLE OF type_lmg_pallet_rec;
        
    TYPE type_lmc_equip_rec IS RECORD ( 
        equip_id            VARCHAR2(11),
        trav_rate_loaded    NUMBER,
        decel_rate_loaded   NUMBER,
        accel_rate_loaded   NUMBER,
        ll                  NUMBER,
        rl                  NUMBER,
        trav_rate_empty     NUMBER,
        decel_rate_empty    NUMBER,
        accel_rate_empty    NUMBER,
        le                  NUMBER,
        re                  NUMBER,
        ds                  NUMBER,
        apof                NUMBER,
        mepof               NUMBER,
        ppof                NUMBER,
        apos                NUMBER,
        mepos               NUMBER,
        ppos                NUMBER,
        apir                NUMBER,
        mepir               NUMBER,
        ppir                NUMBER,
        bt90                NUMBER,
        bp                  NUMBER,
        tid                 NUMBER,
        tia                 NUMBER,
        tir                 NUMBER,
        apidi               NUMBER,
        mepidi              NUMBER,
        ppidi               NUMBER,
        tidi                NUMBER,
        apipb               NUMBER,
        mepipb              NUMBER,
        ppipb               NUMBER,
        apidd               NUMBER,
        mepidd              NUMBER,
        ppidd               NUMBER 
        );
        
    TYPE type_lmg_inv_rec IS RECORD ( 
        pallet_id     VARCHAR2(18),
        prod_id       VARCHAR2(10),
        cpv           VARCHAR2(11),
        qoh           NUMBER,
        exp_date      NUMBER 
        );
        
    TYPE tbl_lmg_inv_rec IS TABLE OF type_lmg_inv_rec;
        
    PROCEDURE lmpb_drp_to_pshbk_hm_with_qoh (
        i_pals             IN tbl_lmg_pallet_rec,
        i_pal_num_recs     IN NUMBER,
        i_num_pallets      IN NUMBER,
        i_e_rec            IN type_lmc_equip_rec,
        i_dest_total_qoh   IN NUMBER,
        o_drop             OUT NUMBER
    );

    PROCEDURE lmgpb_drp_pshbk_res_with_qoh (
        i_pals           IN tbl_lmg_pallet_rec,
        i_pal_num_recs   IN NUMBER,
        i_num_pallets    IN NUMBER,
        i_e_rec          IN type_lmc_equip_rec,
        i_num_recs       IN NUMBER,
        i_inv            IN tbl_lmg_inv_rec,
        i_is_same_item   IN VARCHAR2,
        o_drop           OUT NUMBER
    );

    PROCEDURE lmgpb_pickup_from_pushback_res (
        i_pals           IN tbl_lmg_pallet_rec,
        i_pal_num_recs   IN NUMBER,
        i_pindex         IN NUMBER,
        i_e_rec          IN type_lmc_equip_rec,
        i_num_recs       IN NUMBER,
        i_inv            IN tbl_lmg_inv_rec,
        i_is_diff_item   IN VARCHAR2,
        o_pickup         OUT NUMBER
    );

    FUNCTION raiseloaded (
        i_inches   IN NUMBER,
        i_e_rec    IN type_lmc_equip_rec
    ) RETURN NUMBER;

    FUNCTION lowerloaded (
        i_inches   IN NUMBER,
        i_e_rec    IN type_lmc_equip_rec
    ) RETURN NUMBER;

    FUNCTION raiseempty (
        i_inches   IN NUMBER,
        i_e_rec    IN type_lmc_equip_rec
    ) RETURN NUMBER;

    FUNCTION lowerempty (
        i_inches   IN NUMBER,
        i_e_rec    IN type_lmc_equip_rec
    ) RETURN NUMBER;

END pl_lm_goal_pb;
/

create or replace PACKAGE BODY pl_lm_goal_pb AS

    STD_PALLET_HEIGHT   CONSTANT NUMBER := 48;
    IN_AISLE            CONSTANT NUMBER := 2;
    IN_SLOT             CONSTANT NUMBER := 1;
    g_forklift_audit    NUMBER;
    g_audit_batch_no    batch.batch_no%TYPE:=pl_lm_goaltime.g_audit_batch_no;

/*****************************************************************************
**  FUNCTION:
**      lmpb_drp_to_pshbk_hm_with_qoh()
**
**  DESCRIPTION:
**      This functions calculates the LM drop discreet value for a pallet
**      going to a pushback home slot that is EMPTY OR WITH EXISTING QOH.
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
**      o_drop             - Outgoing drop value.
**
**  RETURN VALUES:
**      None.
**
*****************************************************************************/

    PROCEDURE lmpb_drp_to_pshbk_hm_with_qoh (
        i_pals             IN tbl_lmg_pallet_rec,
        i_pal_num_recs     IN NUMBER,
        i_num_pallets      IN NUMBER,
        i_e_rec            IN type_lmc_equip_rec,
        i_dest_total_qoh   IN NUMBER,
        o_drop             OUT NUMBER
    ) AS

        l_func_name                    VARCHAR2(50) := 'lmpb_drp_to_pshbk_hm_with_qoh';
        l_apply_credit_at_case_level   NUMBER;					/* Designates if to apply credit at the case level when uom = 1. */                                             
        l_handstack_cases              NUMBER := 0; 			/* Cases handstacked */
        l_handstack_splits             NUMBER := 0; 			/* Splits handstacked */
        l_last_pal_qty                 NUMBER; 					/* Quantity on last pallet in slot */
		l_i                            NUMBER;
        l_multi_face_slot_bln          NUMBER; 					/* Multi-face slot designator */
        l_adj_num_positions            NUMBER;					/* Number of positions in the slot adjusted for the min qty */                                    
        l_slot_type_num_positions      NUMBER;					/* Number of positions in the slot as indicated by the slot type */                                         
        l_open_positions               NUMBER;					/* Number of open positions in the slot */
        l_pallet_height                NUMBER;					/* Height from floor to top pallet on stack */
        l_pallet_qty                   NUMBER;					/* Quantity on drop pallet or if the batch is
																a drop to home then the quantity to drop to the home slot */																	
        FALSE                          CONSTANT NUMBER := 0;
        TRUE                           CONSTANT NUMBER := 1;
        l_pallet_removed               NUMBER := FALSE;			/* Indicates if a pallet removed from the
																	home slot for rotation purposes. */
        l_pallets_in_slot              NUMBER;	 				/* Number of pallets for l_prev_qoh.
																	Incremented for each new pallet put in the slot. */
        l_prev_qoh                     NUMBER;					/* Approximate quantity in the slot before drop */
        l_pindex                       NUMBER; 					/* Index of top pallet on stack */
        l_slot_height                  NUMBER; 					/* Height to slot from floor */
        l_spc                          NUMBER; 					/* Splits per case */
        l_splits_per_pallet            NUMBER; 					/* Number of splits on a pallet */
        rf_status                      rf.status := rf.status_normal;
    BEGIN
        l_pindex := i_num_pallets - 1;
        pl_text_log.ins_msg_async('INFO', l_func_name, ' pallet_id = '
                                            || i_pals(l_pindex).pallet_id
                                            || ' num_pallets = '
                                            || i_num_pallets
                                            || ' equip_id = '
                                            || i_e_rec.equip_id
                                            || ' dest_total_qoh = '
                                            || i_dest_total_qoh
                                            || ' multi_pallet_drop_to_slot '
                                            || i_pals(l_pindex).multi_pallet_drop_to_slot, sqlcode, sqlerrm);

        pl_lm_goaltime.lmg_sel_forklift_audit_syspar(g_forklift_audit);

      /*
      **  All the pallets being dropped to the same slot are processed
      **  the first time this function is called.
      */
        IF ( i_pals(l_pindex).multi_pallet_drop_to_slot = 'Y' ) THEN
            return;
        END IF;
           
      /*
      **  Always removing the top pallet on the stack.
      */
        l_pallet_qty := i_pals(l_pindex).qty_on_pallet;
        l_prev_qoh := i_dest_total_qoh;
        l_slot_height := i_pals(l_pindex).height;
        l_spc := i_pals(l_pindex).spc;
        l_pallet_height := std_pallet_height * l_pindex;
        l_splits_per_pallet := i_pals(l_pindex).ti * i_pals(l_pindex).hi * l_spc;

        l_pallets_in_slot := l_prev_qoh / l_splits_per_pallet;
        l_last_pal_qty := MOD(l_prev_qoh,l_splits_per_pallet);
        IF ( l_last_pal_qty > 0 ) THEN /* A partial pallet counts as a pallet. */
            l_pallets_in_slot := l_pallets_in_slot + 1;
        END IF;
 
      /*
      ** if l_last_pal_qty is 0 then each pallet in the slot is a full pallet so
      ** set l_last_pal_qty to a full pallet.
      */
        IF ( l_last_pal_qty = 0 ) THEN
            l_last_pal_qty := l_splits_per_pallet;
        END IF;
 
      /*
      ** Extract out the number positions in the slot as indicated by
      ** the slot type.
      */
        l_slot_type_num_positions := i_pals(l_pindex).slot_type;

      /*
      ** Adjust the number of positions in the slot based on the min quantity.
      */
        l_adj_num_positions := i_pals(l_pindex).min_qty_num_positions + l_slot_type_num_positions;

      /*
      ** Determine if this is a multi-face slot.
      */
        IF (i_pals(l_pindex).min_qty_num_positions >= l_slot_type_num_positions ) THEN
            l_multi_face_slot_bln := TRUE;
        ELSE
            l_multi_face_slot_bln := FALSE;
        END IF;
 
	  /*
	  ** Get syspar that determines if to give credit at the case or
	  ** split level when dropping to a split home slot.
	  */

        rf_status := pl_lm_forklift.lm_sel_split_rpl_crdt_syspar(l_apply_credit_at_case_level);

	  /*
	  ** Process the pallets in the stack going to the same home slot.
	  */ 
      
        FOR i IN REVERSE 1..l_pindex LOOP
			/*
			**  Get out of the loop if all the drops to the same home slot
		    **  have been processed.*/
      
            IF ( i != l_pindex AND i_pals(i).multi_pallet_drop_to_slot = 'N' ) THEN
                EXIT;
            END IF;

      /*
      **  Initialize variables. They may have been assigned a value above
      **  this for loop to use in debug and forklift audit messages. 
      */

            l_pallet_qty := i_pals(i).qty_on_pallet;
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
            IF ( g_forklift_audit = 1 ) THEN
                pl_lm_goaltime.lmg_drop_to_home_audit_msg(i_pals, 
															l_pindex, 
															l_pallets_in_slot, 
															l_prev_qoh, 
															l_slot_type_num_positions,
															l_adj_num_positions, 
															l_open_positions, 
															l_multi_face_slot_bln);
            END IF; /* end audit */
      /*
      ** If this is the first pallet in the stack then put the stack down.
      */

            IF ( i = l_pindex ) THEN
                o_drop := o_drop + i_e_rec.ppof;
                IF ( g_forklift_audit = 1 ) THEN
                    pl_lm_goaltime.lmg_audit_movement('PPOF',pl_lm_goaltime.g_audit_batch_no,i_e_rec,1,'Put stack down.');
                END IF;
            END IF;

      /*
      **  If there are open positions in the slot and this is not a
      **  drop to home batch then put the pallet in the slot otherwise
      **  handstack.
      */

            IF ( ( l_pallets_in_slot < l_adj_num_positions ) AND lmf.droptohomebatch(i_pals(i).batch_no) = 0 ) THEN
				/*
				**  There are open positions in the slot and its not a drop to home.
				**
				**  If this is the first pallet in the stack then remove one
				**  pallet from the slot.  The rule is the forklift operator
				**  is given credit to remove one pallet from the slot.
				*/
                IF ( i = l_pindex ) THEN
                    o_drop := o_drop + i_e_rec.bt90 + i_e_rec.apipb + raiseempty(l_slot_height,i_e_rec) + i_e_rec.mepipb + lowerloaded
                    (l_slot_height,i_e_rec) + i_e_rec.bt90 + i_e_rec.ppof;

                    l_pallet_removed := TRUE;
                    IF ( g_forklift_audit = 1 ) THEN
                        pl_lm_goaltime.lmg_audit_movement('BT90', pl_lm_goaltime.g_audit_batch_no,i_e_rec, 1, 'For pushback home slots always give 
						time to remove one pallet from the slot for rotation.');                       
                        pl_lm_goaltime.lmg_audit_movement('APIPB', pl_lm_goaltime.g_audit_batch_no,i_e_rec, 1, NULL);
                        pl_lm_goaltime.lmg_audit_movement('RE', pl_lm_goaltime.g_audit_batch_no,i_e_rec,l_slot_height, NULL);
                        pl_lm_goaltime.lmg_audit_movement('MEPIPB', pl_lm_goaltime.g_audit_batch_no,i_e_rec, 1, NULL);
                        pl_lm_goaltime.lmg_audit_movement('LL', pl_lm_goaltime.g_audit_batch_no,i_e_rec,l_slot_height, NULL);
                        pl_lm_goaltime.lmg_audit_movement('BT90', pl_lm_goaltime.g_audit_batch_no, i_e_rec, 1, NULL);
                        pl_lm_goaltime.lmg_audit_movement('PPOF', pl_lm_goaltime.g_audit_batch_no, i_e_rec, 1, NULL);
                    END IF;

                END IF;

		  /*
		  **  Put the pallet in the slot.
		  */

                IF ( i_num_pallets = 1 ) THEN
					/*
					**  There is one pallet in the pallet stack.
					**  Pickup the pallet and put it in the slot.
					*/
                    o_drop := o_drop + i_e_rec.bp + i_e_rec.apof + i_e_rec.mepof + i_e_rec.bt90 + i_e_rec.apipb + raiseloaded(l_slot_height,
                    i_e_rec) + i_e_rec.ppipb + lowerempty(l_slot_height,i_e_rec) + i_e_rec.bt90;

                    IF ( g_forklift_audit = 1 ) THEN
                        pl_text_log.ins_msg_async('INFO', l_func_name, 'Put pallet '
                                                            || i_pals(i).pallet_id
                                                            || ' in home slot '
                                                            || i_pals(i).dest_loc, sqlcode, sqlerrm);

                        pl_lm_goaltime.lmg_audit_movement('BP', pl_lm_goaltime.g_audit_batch_no,i_e_rec, 1, 'Put pallet '
                                                                                            || i_pals(i).pallet_id
                                                                                            || ' in home slot '
                                                                                            || i_pals(i).dest_loc);

                        pl_lm_goaltime.lmg_audit_movement('APOF', pl_lm_goaltime.g_audit_batch_no,i_e_rec, 1, NULL);
                        pl_lm_goaltime.lmg_audit_movement('MEPOF', pl_lm_goaltime.g_audit_batch_no,i_e_rec, 1, NULL);
                        pl_lm_goaltime.lmg_audit_movement('BT90', pl_lm_goaltime.g_audit_batch_no,i_e_rec, 1, NULL);
                        pl_lm_goaltime.lmg_audit_movement('APIPB', pl_lm_goaltime.g_audit_batch_no,i_e_rec, 1, NULL);
                        pl_lm_goaltime.lmg_audit_movement('RL', pl_lm_goaltime.g_audit_batch_no,i_e_rec, l_slot_height, NULL);
                        pl_lm_goaltime.lmg_audit_movement('PPIPB', pl_lm_goaltime.g_audit_batch_no,i_e_rec, 1, NULL);
                        pl_lm_goaltime.lmg_audit_movement('LE', pl_lm_goaltime.g_audit_batch_no,i_e_rec, l_slot_height, NULL);
                        pl_lm_goaltime.lmg_audit_movement('BT90', pl_lm_goaltime.g_audit_batch_no,i_e_rec, 1, NULL);
                    END IF; /* end audit */

                ELSE
					/*
					**  There is more than one pallet in the pallet stack.
					**
					**  Take off the top pallet and put it in the slot.
					*/
                    IF ( g_forklift_audit = 1 ) THEN
                        pl_text_log.ins_msg_async('WARN', l_func_name, 'Remove pallet '
                                                            || i_pals(i).pallet_id
                                                            || ' from top of stack. ', sqlcode, sqlerrm);

                        pl_lm_goaltime.lmg_audit_cmt(pl_lm_goaltime.g_audit_batch_no,'Remove pallet '
                                                                        || i_pals(i).pallet_id
                                                                        || ' from top of stack. ',-1);

                    END IF;

                    IF ( i = l_pindex ) THEN
						/*
						**  First pallet being processed.
						**  Get the top pallet off the stack.
						*/
                        o_drop := o_drop + i_e_rec.bp + i_e_rec.apos + raiseempty(l_pallet_height,i_e_rec) + i_e_rec.mepos;

                        IF ( g_forklift_audit = 1 ) THEN
							/*
							**  The BP is for maneuvering away from the pallet
							**  removed from the slot.
							*/
                            pl_lm_goaltime.lmg_audit_movement('BP', pl_lm_goaltime.g_audit_batch_no, i_e_rec, 1,NULL);
                            pl_lm_goaltime.lmg_audit_movement('APOS', pl_lm_goaltime.g_audit_batch_no, i_e_rec, 1,NULL);
                            pl_lm_goaltime.lmg_audit_movement('RE', pl_lm_goaltime.g_audit_batch_no, i_e_rec, l_pallet_height, NULL);
                            pl_lm_goaltime.lmg_audit_movement('MEPOS', pl_lm_goaltime.g_audit_batch_no,i_e_rec, 1, NULL);
                        END IF;

                    ELSE
						/*
						**  The previous pallet has been put in the slot, remove
						**  the top pallet from the stack.  The forks are at the
						**  level of the slot.
						*/
                        IF ( l_slot_height > l_pallet_height ) THEN
                            o_drop := o_drop + lowerempty(l_slot_height - l_pallet_height,i_e_rec);
                            IF ( g_forklift_audit = 1 ) THEN
                                pl_lm_goaltime.lmg_audit_movement('LE',pl_lm_goaltime.g_audit_batch_no,i_e_rec,l_slot_height - l_pallet_height,NULL);
                            END IF;

                        ELSE
                            o_drop := o_drop + raiseempty(l_pallet_height - l_slot_height,i_e_rec);
                            IF ( g_forklift_audit = 1 ) THEN
                                pl_lm_goaltime.lmg_audit_movement('RE', pl_lm_goaltime.g_audit_batch_no, i_e_rec, l_pallet_height - l_slot_height, NULL);
                               
                            END IF;

                        END IF;

                        IF ( i = 0 ) THEN
							/*
							**  At the last pallet in the stack so it is
							**  on the floor.
							*/
                            o_drop := o_drop + i_e_rec.apof + i_e_rec.mepof;
                            IF ( g_forklift_audit = 1 ) THEN
                                pl_lm_goaltime.lmg_audit_movement('APOF', pl_lm_goaltime.g_audit_batch_no, i_e_rec, 1, NULL);
                                pl_lm_goaltime.lmg_audit_movement('MEPOF', pl_lm_goaltime.g_audit_batch_no, i_e_rec, 1, NULL);
                            END IF;

                        ELSE
							/*
							**  The stack has more than one pallet.
							*/
                            o_drop := o_drop + i_e_rec.apos + i_e_rec.mepos;
                            IF ( g_forklift_audit = 1 ) THEN
                                pl_lm_goaltime.lmg_audit_movement('APOS', pl_lm_goaltime.g_audit_batch_no, i_e_rec, 1, NULL);
                                pl_lm_goaltime.lmg_audit_movement('MEPOS', pl_lm_goaltime.g_audit_batch_no, i_e_rec, 1, NULL);
                            END IF;

                        END IF;

                    END IF;

					/*
					**  The pallet is on the forks.  Move the forks up or down as
					**  appropriate and put the pallet in the slot.
					*/

                    IF ( l_slot_height > l_pallet_height ) THEN
                        o_drop := o_drop + i_e_rec.bt90 + i_e_rec.apipb + raiseloaded( (l_slot_height - l_pallet_height),i_e_rec)
                        + i_e_rec.ppipb + i_e_rec.bt90;
                    ELSE
                        o_drop := o_drop + i_e_rec.bt90 + i_e_rec.apipb + lowerloaded( (l_pallet_height - l_slot_height),i_e_rec)
                        + i_e_rec.ppipb + i_e_rec.bt90;
                    END IF;

                    IF ( g_forklift_audit = 1 ) THEN
                        pl_text_log.ins_msg_async('INFO', l_func_name, 'Put pallet '
                                                            || i_pals(i).pallet_id
                                                            || ' in home slot '
                                                            || i_pals(i).dest_loc, sqlcode, sqlerrm);

                        IF ( l_slot_height > l_pallet_height ) THEN
                            pl_lm_goaltime.lmg_audit_movement('BT90', pl_lm_goaltime.g_audit_batch_no,i_e_rec, 1, 'Put pallet '
                                                            || i_pals(i).pallet_id
                                                            || ' in home slot '
                                                            || i_pals(i).dest_loc);
                            pl_lm_goaltime.lmg_audit_movement('APIPB', pl_lm_goaltime.g_audit_batch_no,i_e_rec, 1, NULL);
                            pl_lm_goaltime.lmg_audit_movement('RL', pl_lm_goaltime.g_audit_batch_no, i_e_rec, l_slot_height - l_pallet_height, NULL);                            
                            pl_lm_goaltime.lmg_audit_movement('PPIPB', pl_lm_goaltime.g_audit_batch_no,i_e_rec, 1, NULL);
                            pl_lm_goaltime.lmg_audit_movement('BT90', pl_lm_goaltime.g_audit_batch_no,i_e_rec, 1, NULL);
                        ELSE
                            pl_lm_goaltime.lmg_audit_movement('BT90', pl_lm_goaltime.g_audit_batch_no,i_e_rec, 1, 'Put pallet '
                                                            || i_pals(i).pallet_id
                                                            || ' in home slot '
                                                            || i_pals(i).dest_loc);
                            pl_lm_goaltime.lmg_audit_movement('APIPB', pl_lm_goaltime.g_audit_batch_no,i_e_rec, 1, NULL);
                            pl_lm_goaltime.lmg_audit_movement('LL', pl_lm_goaltime.g_audit_batch_no, i_e_rec, l_pallet_height - l_slot_height, NULL);
                            pl_lm_goaltime.lmg_audit_movement('PPIPB', pl_lm_goaltime.g_audit_batch_no,i_e_rec, 1, NULL);
                            pl_lm_goaltime.lmg_audit_movement('BT90', pl_lm_goaltime.g_audit_batch_no,i_e_rec, 1, NULL);
                        END IF;

                    END IF; /* end audit */

                END IF;

				  /*
				  ** If this is the first pallet in the stack going to the slot
				  ** and the qoh in the slot is less than a full pallet and it is
				  ** a multi-face slot then give credit to handstack qoh/2 cases.
				  */

                IF ( ( i = l_pindex ) AND ( l_prev_qoh < l_splits_per_pallet ) AND l_multi_face_slot_bln = 1 ) THEN
                    l_handstack_cases := ( l_prev_qoh / l_spc ) / 2;
                    l_handstack_splits := 0;
                    rf_status := pl_lm_forklift.lmf_update_batch_kvi(i_pals(i).batch_no,l_handstack_cases,l_handstack_splits);

                    IF ( g_forklift_audit = 1 ) THEN
                        pl_text_log.ins_msg_async('INFO', l_func_name, 'Multi-face slot and less than a full pallet in the slot.  Give credit to handstack '
                                                            || l_handstack_cases
                                                            || ' case(s) which is the qoh / 2.', sqlcode, sqlerrm);

                        pl_lm_goaltime.lmg_audit_cmt(pl_lm_goaltime.g_audit_batch_no,'Multi-face slot and less than a full pallet in the slot.  Give credit to handstack '
                                                                        || l_handstack_cases
                                                                        || ' case(s) which is the qoh / 2.',-1);
                    END IF;

                END IF;

                l_pallets_in_slot := l_pallets_in_slot + 1;
            ELSE
			  /*
			  **  There are no open positions in the slot or this is a
			  **  drop to home batch.  Handstack.
			  **
			  **  Remove pallet from the slot.  The forklift operator should
			  **  be removing the pallet that has the fewest cases if
			  **  there are multiple pallets in the slot.
			  */
                o_drop := o_drop + i_e_rec.bt90 + i_e_rec.apipb + raiseempty(l_slot_height,i_e_rec) + i_e_rec.mepipb + lowerloaded
                (l_slot_height,i_e_rec) + i_e_rec.bt90 + i_e_rec.ppof;

                IF ( g_forklift_audit = 1 ) THEN
					/*
					** Leave out audit message if drop to home.
					*/
                    IF ( lmf.droptohomebatch(i_pals(i).batch_no) = 0 ) THEN
                        pl_text_log.ins_msg_async('INFO', l_func_name, 'There are no open positions in home slot '
                                                            || i_pals(i).dest_loc
                                                            || ' Handstack.', sqlcode, sqlerrm);

                        pl_lm_goaltime.lmg_audit_cmt(pl_lm_goaltime.g_audit_batch_no,'There are no open positions in home slot '
                                                                        || i_pals(i).dest_loc
                                                                        || ' Handstack.',-1);

                    END IF;

                    pl_lm_goaltime.lmg_audit_movement('BT90',pl_lm_goaltime.g_audit_batch_no,i_e_rec,1,'Pull pallet from home slot.');
                    pl_lm_goaltime.lmg_audit_movement('APIPB',pl_lm_goaltime.g_audit_batch_no,i_e_rec,1,NULL);
                    pl_lm_goaltime.lmg_audit_movement('RE',pl_lm_goaltime.g_audit_batch_no,i_e_rec,l_slot_height,NULL);
                    pl_lm_goaltime.lmg_audit_movement('MEPIPB',pl_lm_goaltime.g_audit_batch_no,i_e_rec,1,NULL);
                    pl_lm_goaltime.lmg_audit_movement('LL',pl_lm_goaltime.g_audit_batch_no,i_e_rec,l_slot_height,NULL);
                    pl_lm_goaltime.lmg_audit_movement('BT90',pl_lm_goaltime.g_audit_batch_no,i_e_rec,1,NULL);
                    pl_lm_goaltime.lmg_audit_movement('PPOF',pl_lm_goaltime.g_audit_batch_no,i_e_rec,1,NULL);
                END IF; /* end audit */
				  /*
				  **  If there is more than 1 pallet in the stack then get the top
				  **  pallet and lower it to the floor.
				  */

                IF ( i > 0 ) THEN
                    o_drop := o_drop + i_e_rec.bp + i_e_rec.apos + raiseempty(l_pallet_height,i_e_rec) + i_e_rec.mepos + lowerloaded
                    (l_pallet_height,i_e_rec);

                    IF ( g_forklift_audit = 1 ) THEN
                        pl_text_log.ins_msg_async('INFO', l_func_name, 'Remove pallet '
                                                            || i_pals(i).pallet_id
                                                            || ' from top of stack and lower to the floor.', sqlcode, sqlerrm);
						                                                       
                        pl_lm_goaltime.lmg_audit_movement('BP',pl_lm_goaltime.g_audit_batch_no,i_e_rec,1,'Remove pallet '
                                                            || i_pals(i).pallet_id
                                                            || ' from top of stack and lower to the floor.');
                        pl_lm_goaltime.lmg_audit_movement('APOS',pl_lm_goaltime.g_audit_batch_no,i_e_rec,1,NULL);
                        pl_lm_goaltime.lmg_audit_movement('RE',pl_lm_goaltime.g_audit_batch_no,i_e_rec,l_pallet_height,NULL);
                        pl_lm_goaltime.lmg_audit_movement('MEPOS',pl_lm_goaltime.g_audit_batch_no,i_e_rec,1,NULL);
                        pl_lm_goaltime.lmg_audit_movement('LL',pl_lm_goaltime.g_audit_batch_no,i_e_rec,l_pallet_height,NULL);
                    END IF; /* end audit */

                END IF;

			  /*
			  **  Handstack the appropriate qty.
			  */

                IF ( l_last_pal_qty <= l_pallet_qty AND ( lmf.droptohomebatch(i_pals(i).batch_no) = 0 ) ) THEN
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
                    IF ( i = 0 ) THEN
                        o_drop := o_drop + i_e_rec.bp + i_e_rec.apof + i_e_rec.mepof;
                    END IF;

                    IF ( i_pals(i).uom = 1 ) THEN
					  /*
					  ** Split home.
					  */
                        IF ( l_apply_credit_at_case_level = 1 ) THEN
							/*
							 ** Case up splits.
							 */
                            l_handstack_cases := l_last_pal_qty / l_spc;
                            l_handstack_splits := MOD(l_last_pal_qty,l_spc);
                            IF ( g_forklift_audit = 1 ) THEN
                                pl_lm_goaltime.lmg_audit_cmt(pl_lm_goaltime.g_audit_batch_no,'Syspar Split RPL Credit at Case Level is set to Y
											so credit will be applied at the case level.',-1);                               
                            END IF;

                        ELSE
                            l_handstack_cases := 0;
                            l_handstack_splits := l_last_pal_qty;
                            IF ( g_forklift_audit = 1 ) THEN
                                pl_lm_goaltime.lmg_audit_cmt(pl_lm_goaltime.g_audit_batch_no,'Syspar Split RPL Credit at Case Level is set to N 
																so credit will be applied at the split level.',-1);                               
                            END IF;

                        END IF;

                    ELSE
					  /*
					  ** Case home which can have splits.
					  */
                        l_handstack_cases := l_last_pal_qty / l_spc;
                        l_handstack_splits := MOD(l_last_pal_qty,l_spc);
                    END IF;

                    IF ( g_forklift_audit = 1 ) THEN
                        IF ( i = 0 ) THEN
                            pl_lm_goaltime.lmg_audit_movement('BP',pl_lm_goaltime.g_audit_batch_no,i_e_rec,1,'Position the new pallet on the forks.');
                            pl_lm_goaltime.lmg_audit_movement('APOF',pl_lm_goaltime.g_audit_batch_no,i_e_rec,1,NULL);
                            pl_lm_goaltime.lmg_audit_movement('MEPOF',pl_lm_goaltime.g_audit_batch_no,i_e_rec,1,NULL);
                        END IF;

                        pl_text_log.ins_msg_async('INFO', l_func_name, 'Handstack the '
                                                            || l_handstack_cases
                                                            || ' case(s) and '
                                                            || l_handstack_splits
                                                            || 'split(s) on the pallet pulled from the slot onto the new pallet.', sqlcode, sqlerrm);
                                                           

                        pl_lm_goaltime.lmg_audit_cmt(pl_lm_goaltime.g_audit_batch_no,'Handstack the '
                                                                        || l_handstack_cases
                                                                        || ' case(s) and '
                                                                        || l_handstack_splits
                                                                        || 'split(s) on the pallet pulled from the slot onto the new pallet.',-1);
                                                                       

                    END IF; /* end audit */

                ELSE
				  /*
				  **  The number of pieces on the pallet pulled from the
				  **  home slot is > the number of pieces on the new pallet
				  **  or this is a drop to home batch.
				  **  Handstack the pieces on the new pallet onto the pallet
				  **  pulled from the home slot.
				  */
                    IF ( i_pals(i).uom = 1 ) THEN
						/*
						** Split home.
						*/
                        IF ( l_apply_credit_at_case_level = 1 OR lmf.droptohomebatch(i_pals(i).batch_no) = 1 ) THEN
							  /*
							  ** Case up the splits.
							  */
                            l_handstack_cases := l_pallet_qty / l_spc;
                            l_handstack_splits := MOD(l_pallet_qty,l_spc);

							  /*
							  ** Leave out audit message if drop to home.
							  */
                            IF ( g_forklift_audit = 1 AND ( lmf.droptohomebatch(i_pals(i).batch_no) = 0 ) ) THEN
                                pl_lm_goaltime.lmg_audit_cmt(pl_lm_goaltime.g_audit_batch_no,'Syspar Split RPL Credit at Case Level is set to 
												Y so credit will be applied at the case level.',-1);                               
                            END IF;

                        ELSE
                            l_handstack_cases := 0;
                            l_handstack_splits := l_pallet_qty;

						  /*
						  ** Leave out audit message if drop to home.
						  */
                            IF ( g_forklift_audit = 1 AND ( lmf.droptohomebatch(i_pals(i).batch_no) = 0 ) ) THEN
                                pl_lm_goaltime.lmg_audit_cmt(pl_lm_goaltime.g_audit_batch_no,'Syspar Split RPL Credit at Case Level is set to N 
								so credit will be applied at the split level.',-1);                               
                            END IF;

                        END IF;
                    ELSE
					  /*
					  ** Case home which can have splits.
					  */
                        l_handstack_cases := l_pallet_qty / l_spc;
                        l_handstack_splits := MOD(l_pallet_qty,l_spc);
                    END IF;

				  /* 
				  **  If there was more than one pallet in the stack then 
				  **  the pallet removed from the top of the stack is on
				  **  the forks.  The pallet pulled from the slot is the
				  **  pallet to put in the slot so position the forks on
				  **  this pallet.
				  */

                    IF ( i > 0 ) THEN
                        o_drop := o_drop + i_e_rec.bp + i_e_rec.apof + i_e_rec.mepof;
                    END IF;

                    IF ( g_forklift_audit = 1 ) THEN
                        pl_text_log.ins_msg_async('INFO', l_func_name, 'Handstack the '
                                                            || l_handstack_cases
                                                            || ' case(s) and '
                                                            || l_handstack_splits
                                                            || 'split(s) on the pallet pulled from home slot '
                                                            || i_pals(i).dest_loc, sqlcode, sqlerrm);

                        pl_lm_goaltime.lmg_audit_cmt(pl_lm_goaltime.g_audit_batch_no,'Handstack the '
                                                                        || l_handstack_cases
                                                                        || ' case(s) and '
                                                                        || l_handstack_splits
                                                                        || 'split(s) on the pallet pulled from home slot '
                                                                        || i_pals(i).dest_loc,-1);

                        IF ( i > 0 ) THEN
                            pl_lm_goaltime.lmg_audit_movement('BP',pl_lm_goaltime.g_audit_batch_no,i_e_rec,1,'Position the pallet pulled from the home slot on the forks.'
                            );
                            pl_lm_goaltime.lmg_audit_movement('APOF',pl_lm_goaltime.g_audit_batch_no,i_e_rec,1,NULL);
                            pl_lm_goaltime.lmg_audit_movement('MEPOF',pl_lm_goaltime.g_audit_batch_no,i_e_rec,1,NULL);
                        END IF;

                    END IF; /* end audit */

                END IF;

			  /*
			  **  Put pallet in slot.  This will be either the pallet pulled from
			  **  the home slot or the new pallet.
			  */

                o_drop := o_drop + i_e_rec.ds + i_e_rec.bt90 + i_e_rec.apipb + raiseloaded(l_slot_height,i_e_rec) + i_e_rec.ppipb

                + lowerempty(l_slot_height,i_e_rec) + i_e_rec.bt90;

                IF ( g_forklift_audit = 1 ) THEN
                    pl_lm_goaltime.lmg_audit_movement('DS',pl_lm_goaltime.g_audit_batch_no,i_e_rec,1,'Put pallet in home slot.');
                    pl_lm_goaltime.lmg_audit_movement('BT90',pl_lm_goaltime.g_audit_batch_no,i_e_rec,1,NULL);
                    pl_lm_goaltime.lmg_audit_movement('APIPB',pl_lm_goaltime.g_audit_batch_no,i_e_rec,1,NULL);
                    pl_lm_goaltime.lmg_audit_movement('RL',pl_lm_goaltime.g_audit_batch_no,i_e_rec,l_slot_height,NULL);
                    pl_lm_goaltime.lmg_audit_movement('PPIPB',pl_lm_goaltime.g_audit_batch_no,i_e_rec,1,NULL);
                    pl_lm_goaltime.lmg_audit_movement('LE',pl_lm_goaltime.g_audit_batch_no,i_e_rec,l_slot_height,NULL);
                    pl_lm_goaltime.lmg_audit_movement('BT90',pl_lm_goaltime.g_audit_batch_no,i_e_rec,1,NULL);
                END IF; /* end audit */

                l_last_pal_qty := i_pals(i).qty_on_pallet;
                rf_status := pl_lm_forklift.lmf_update_batch_kvi(i_pals(i).batch_no,l_handstack_cases,l_handstack_splits);

            END IF; /* end else of if (l_pallets_in_slot < l_adj_num_positions) */

            l_pallet_height := l_pallet_height - std_pallet_height;
            l_prev_qoh := l_prev_qoh + l_pallet_qty;
            pl_text_log.ins_msg_async('INFO', l_func_name, 'o_drop = ' || o_drop, sqlcode, sqlerrm);
        END LOOP; /* end for loop */
		/*
		**  If a pallet was removed from the home slot then put it back.
		*/

        IF ( l_pallet_removed = 1 ) THEN
            IF ( i_num_pallets > 1 ) THEN
				/*
				**  If there was more than one pallet in the stack then the
				**  forks are currently at the slot height.  Lower the forks
				**  to the floor.
				*/
                o_drop := o_drop + lowerempty(l_slot_height,i_e_rec);
                IF ( g_forklift_audit = 1 ) THEN
                    pl_lm_goaltime.lmg_audit_movement('LE',pl_lm_goaltime.g_audit_batch_no,i_e_rec,l_slot_height,NULL);
                END IF;

            END IF;

            o_drop := o_drop + i_e_rec.apof + i_e_rec.mepof + i_e_rec.bt90 + i_e_rec.apipb + raiseloaded(l_slot_height,i_e_rec) +

            i_e_rec.ppipb + lowerempty(l_slot_height,i_e_rec) + i_e_rec.bt90;

            IF ( g_forklift_audit = 1 ) THEN
                pl_text_log.ins_msg_async('INFO', l_func_name, 'Put back the pallet removed from the slot ', sqlcode, sqlerrm);
                pl_lm_goaltime.lmg_audit_movement('APOF',pl_lm_goaltime.g_audit_batch_no,i_e_rec,1,'Put back the pallet removed from the slot ');
                pl_lm_goaltime.lmg_audit_movement('MEPOF',pl_lm_goaltime.g_audit_batch_no,i_e_rec,1,NULL);
                pl_lm_goaltime.lmg_audit_movement('BT90',pl_lm_goaltime.g_audit_batch_no,i_e_rec,1,NULL);
                pl_lm_goaltime.lmg_audit_movement('APIPB',pl_lm_goaltime.g_audit_batch_no,i_e_rec,1,NULL);
                pl_lm_goaltime.lmg_audit_movement('RL',pl_lm_goaltime.g_audit_batch_no,i_e_rec,l_slot_height,NULL);
                pl_lm_goaltime.lmg_audit_movement('PPIPB',pl_lm_goaltime.g_audit_batch_no,i_e_rec,1,NULL);
                pl_lm_goaltime.lmg_audit_movement('LE',pl_lm_goaltime.g_audit_batch_no,i_e_rec,l_slot_height,NULL);
                pl_lm_goaltime.lmg_audit_movement('BT90',pl_lm_goaltime.g_audit_batch_no,i_e_rec,1,NULL);
            END IF;

        END IF;

		/*
		** Pickup stack if there are pallets left and go to the
		** next destination.
		*/

        IF ( l_i >= 0 ) THEN
		  /*
		  ** There are pallets still in the travel stack.
		  ** Pick up stack and go to next destination.
		  */
            pl_lm_goaltime.lmg_pickup_for_next_dst(i_pals,l_i,i_e_rec,o_drop);
        END IF;

    END lmpb_drp_to_pshbk_hm_with_qoh;  /* end lmpb_drp_to_pshbk_hm_with_qoh */
	
  /*****************************************************************************
  **  PROCEDURE:
  **      lmgpb_drp_pshbk_res_with_qoh()
  **
  **  DESCRIPTION:
  **      This procedure calculates the LM drop discreet value for a pallet
  **      going to a reserve pushback slot this is EMPTY OR HAS EXISTING
  **      INVENTORY.
  **
  **      If there is more than one pallet going to the same slot then they
  **      are all processed the first time this function is called.
  **
  **  PARAMETERS:
  **      i_pals         - Pointer to pallet list.
  **      i_num_pallets  - Number of pallets in pallet list.
  **      i_e_rec        - Pointer to equipment tmu values.
  **      i_inv          - Pointer to pallets already in the destination.
  **      i_is_same_item - Flag denoting if the same item is already in the
  **                       destination location.
  **      o_drop         - Outgoing drop value.
  **
  **  RETURN VALUES:
  **      None.
  **
  **  
  *****************************************************************************/

    PROCEDURE lmgpb_drp_pshbk_res_with_qoh (
        i_pals           IN tbl_lmg_pallet_rec,
        i_pal_num_recs   IN NUMBER,
        i_num_pallets    IN NUMBER,
        i_e_rec          IN type_lmc_equip_rec,
        i_num_recs       IN NUMBER,
        i_inv            IN tbl_lmg_inv_rec,
        i_is_same_item   IN VARCHAR2,
        o_drop           OUT NUMBER
    ) AS

        l_aisle_stack_height            NUMBER := 0;	/* Height of pallets stacked in aisle. */
        l_drop_type                     NUMBER;			/* Designates if this is the first, last
															or a middle pallet going to the same
															slot on the same PO for putaways. */
        l_existing_inv                  NUMBER;			/* Designates if the existing inventory
														   is in the slot or is stacked in the
														   aisle. */
        l_func_name                     VARCHAR2(50) := 'lmgpb_drp_pshbk_res_with_qoh';
        l_pallet_height                 NUMBER := 0;	/* Height from floor to top pallet on
														the travel stack */
        l_num_pallets_in_travel_stack   NUMBER;			/* Number of pallets in travel stack.
															Decremented for each pallet dropped. */
        l_num_pending_putaways          NUMBER := 0;	/* The number of pending putaways to the
														slot on the PO. */
        l_num_drops_completed           NUMBER := 0;	/* The number of completed drops
															to the slot. */
        l_pallets_in_slot               NUMBER := 0;	/* Number of pallets currently in the slot.
															  It does not include the pallets in
															  the travel stack that are going to
															  the slot. */
        l_pallets_to_move               NUMBER := 0;	/* Number of pallets to remove from slot
															for rotation */
        l_pindex                        NUMBER := 0;	/* Index of top pallet on stack */
        l_putback_existing_inv          NUMBER;			/* Designates if the existing inventory
														   in the slot needs to be putback in the
														   slot. */
        l_remove_existing_inv           NUMBER;			/* Designates if the existing inventory
														  in the slot needs to be removed and
														  stacked in the aisle. */
        l_same_slot_drop                VARCHAR2(1);	/* More than one incoming pallet to same  slot */
                                
        l_slot_height                   NUMBER := 0; 	/* Height from floor to slot */
        l_slot_type_num_positions       NUMBER;			/* Number of positions in the slot
															as indicated by the slot type */
        l_ti_hi                         NUMBER := 0; 	/* Number of cases on pallet */
        l_total_pallets_in_slot         NUMBER := 0;	/* Total number of pallets that will be in
														  the slot after all the putaways on a PO
														  are completed.  Used for putaways. */
    BEGIN
        pl_text_log.ins_msg_async('INFO', l_func_name, 'Pallet_id = '
                                            || i_pals(i_num_pallets - 1).pallet_id
                                            || ' num_pallets ='
                                            || i_num_pallets
                                            || ' equip_id = '
                                            || i_e_rec.equip_id
                                            || ' num_recs = '
                                            || i_num_recs
                                            || ' is_same_item = '
                                            || i_is_same_item, sqlcode, sqlerrm);

      /*
      **  Always removing the top pallet on the stack.
      */

        l_pindex := i_num_pallets - 1;
        l_num_pallets_in_travel_stack := i_num_pallets;
        l_slot_height := i_pals(l_pindex).height;

      /*
      **  Same slot drops were processed by this function on first pallet dropped
      **  to the slot.
      */
        IF ( i_pals(l_pindex).multi_pallet_drop_to_slot = 'Y' ) THEN
            return;
        END IF;
        l_pallets_in_slot := i_num_recs;

      /*
      ** Extract the number of positions in the slot from the slot type.
      */
        l_slot_type_num_positions := i_pals(l_pindex).slot_type;

      /*
      ** Determine if the existing inventory in the slot needs to be removed.
      ** For putaways going to the same slot on a PO the inventory is removed
      ** when the first putaway is performed and put back after the last
      ** putaway is performed.  Pallets from previous puts on the same PO
      ** are not removed.
      */
        pl_lm_goaltime.lmg_drop_rotation(i_pal_num_recs,
											i_pals,
											i_num_pallets,
											i_num_recs,
											i_inv,
											l_drop_type,
											l_num_drops_completed,
											l_num_pending_putaways,
											l_pallets_to_move,
											l_remove_existing_inv,
											l_putback_existing_inv,
											l_existing_inv,
											l_total_pallets_in_slot);

      /*
      ** Process the pallets in the stack going to the same slot.
      */

        FOR i IN REVERSE 1..l_pindex LOOP
          /*
          **  Get out of the loop if all the drops to the same slot
          **  have been processed.
          */
            IF ( i != l_pindex AND i_pals(i).multi_pallet_drop_to_slot = 'N' ) THEN
                EXIT;
            END IF;

            IF ( g_forklift_audit = 1 ) THEN
                pl_lm_goaltime.lmg_drop_to_reserve_audit_msg(i_pals,i,l_pallets_in_slot,l_num_drops_completed);                
            END IF;

          /*
          **  Put travel stack down if there is more than one pallet in the travel
          **  stack or if the existing pallets in the slot need to be removed
          **  and the travel stack is not already down.
          */
            IF ( ( i_num_pallets > 1 OR l_remove_existing_inv = 1 ) AND ( i = l_pindex ) ) THEN
                o_drop := i_e_rec.ppof;
                IF ( g_forklift_audit = 1 ) THEN
                    IF ( i_num_pallets > 1 AND l_existing_inv = IN_AISLE AND l_pallets_in_slot > 0 ) THEN
                        pl_text_log.ins_msg_async('INFO', l_func_name, 'The existing inventory stacked in the aisle on a previous drop.  Put stack down because there is more than one pallet ( '
                                                            || i_num_pallets
                                                            || '  pallets total) in the stack. ', sqlcode, sqlerrm);

                    ELSE
                        pl_text_log.ins_msg_async('INFO', l_func_name, 'Put stack down.', sqlcode, sqlerrm);
                        pl_lm_goaltime.lmg_audit_movement('PPOF',pl_lm_goaltime.g_audit_batch_no,i_e_rec,1,'Put stack down.');
                    END IF; /* end audit */

                END IF;

            END IF;

			/*
			**  Remove the pallets from the slot if existing inventory is to
			**  be removed and there are pallets to remove and processing the
			**  first pallet in the travel stack.  Each pallet is put on the
			**  floor.  They will not be stacked.
			*/

            IF ( l_remove_existing_inv = 1 AND l_pallets_to_move > 0 AND i = l_pindex ) THEN
                l_aisle_stack_height := 0; /* Each pallet put on floor */
                FOR j IN 0..i_num_recs LOOP
                    o_drop := o_drop + i_e_rec.bt90 + i_e_rec.apipb + raiseempty(l_slot_height,i_e_rec) + i_e_rec.mepipb + lowerloaded
                    (l_slot_height,i_e_rec) + i_e_rec.bt90 + i_e_rec.ppof;

                    IF ( g_forklift_audit = 1 ) THEN
                        IF ( j = 0 ) THEN
                            pl_text_log.ins_msg_async('INFO', l_func_name, 'Have the same item in slot '
                                                                || i_pals(i).dest_loc
                                                                || ' Take current inventory of '
                                                                || i_num_recs
                                                                || ' pallet(s) out of the slot. Each pallet is put on the floor.' ,sqlcode, sqlerrm);
                                                               

                            pl_lm_goaltime.lmg_audit_cmt(pl_lm_goaltime.g_audit_batch_no,'Have the same item in slot '
                                                                            || i_pals(i).dest_loc
                                                                            || ' Take current inventory of '
                                                                            || i_num_recs
                                                                            || ' pallet(s) out of the slot. Each pallet is put on the floor.',-1);

                        END IF;

                        pl_lm_goaltime.lmg_audit_movement('BT90',pl_lm_goaltime.g_audit_batch_no,i_e_rec,1,'Remove pallet from slot.');
                        pl_lm_goaltime.lmg_audit_movement('APIPB',pl_lm_goaltime.g_audit_batch_no,i_e_rec,1,NULL);
                        pl_lm_goaltime.lmg_audit_movement('RE',pl_lm_goaltime.g_audit_batch_no,i_e_rec,l_slot_height,NULL);
                        pl_lm_goaltime.lmg_audit_movement('MEPIPB',pl_lm_goaltime.g_audit_batch_no,i_e_rec,1,NULL);
                        pl_lm_goaltime.lmg_audit_movement('LL',pl_lm_goaltime.g_audit_batch_no,i_e_rec,l_slot_height,NULL);
                        pl_lm_goaltime.lmg_audit_movement('BT90',pl_lm_goaltime.g_audit_batch_no,i_e_rec,1,NULL);
                        pl_lm_goaltime.lmg_audit_movement('PPOF',pl_lm_goaltime.g_audit_batch_no,i_e_rec,1,NULL);
                    END IF; /* end audit */

                END LOOP; /* end remove existing pallets for loop */

            END IF;

            IF ( g_forklift_audit = 1 AND l_remove_existing_inv != 0 AND l_pallets_to_move > 0 ) THEN
			  /*
			  ** There are pallets to remove and the flag set to not remove
			  ** existing inv move which means the pallets were removed on a
			  ** previous putaway.
			  */
                pl_text_log.ins_msg_async('INFO', l_func_name, 'The existing '
                                                    || l_pallets_to_move
                                                    || ' pallet(s) removed from the slot on a previous putaway', sqlcode, sqlerrm);

                pl_lm_goaltime.lmg_audit_cmt(pl_lm_goaltime.g_audit_batch_no,'The existing '
                                                                || l_pallets_to_move
                                                                || ' pallet(s) removed from the slot on a previous putaway',-1);
            END IF;

			/*
			**  The existing pallets in the slot have been removed if they were not
			**  removed on a previous putaway on the same PO.
			**  Drop the new pallet into the slot.
			*/

            l_pallet_height := std_pallet_height * i; /* Travel stack height */
            IF ( g_forklift_audit = 1 ) THEN
                pl_text_log.ins_msg_async('INFO', l_func_name, 'Put pallet '
                                                    || i_pals(i).pallet_id
                                                    || ' in slot '
                                                    || i_pals(i).dest_loc, sqlcode, sqlerrm);

                pl_lm_goaltime.lmg_audit_cmt(pl_lm_goaltime.g_audit_batch_no,'Put pallet '
                                                                || i_pals(i).pallet_id
                                                                || ' in slot '
                                                                || i_pals(i).dest_loc,-1);

            END IF;

            IF ( i_num_pallets = 1 ) THEN
			  /*
			  **  There is one pallet in the travel stack.
			  */
                IF ( l_existing_inv = IN_AISLE ) THEN
					/*
					** The existing inventory in the slot was removed on a previous
					** drop.  The forklift driver will drive up to the slot and put
					** the pallet on the forks into the slot.
					** Note: l_existing_inv can be set to IN_AISLE even though 
					**       no pallets actually are in the aisle.  This happens
					**       when the existing inv was previous putaways on the 
					**       same PO.  These previous putaways stay in the slot.
					*/
                    pl_text_log.ins_msg_async('INFO', l_func_name, 'The existing inventory in the slot was removed on a previous drop', sqlcode, sqlerrm);
                                                    
                ELSIF ( l_existing_inv = IN_SLOT AND l_remove_existing_inv = 1 ) THEN
					/*
					** The existing inventory in the slot has been removed for this
					** drop.  Prepare to pickup the pallet in the travel stack.
					*/
                    o_drop := o_drop + i_e_rec.bp;

					/*
					** Move the forks from the height of the last pallet removed
					** from the slot to the top pallet in the travel stack.
					*/
                    IF ( l_aisle_stack_height > l_pallet_height ) THEN
                        o_drop := o_drop + lowerempty(l_aisle_stack_height - l_pallet_height,i_e_rec);
                    ELSE
                        o_drop := o_drop + raiseempty(l_pallet_height - l_aisle_stack_height,i_e_rec);
                        o_drop := o_drop + i_e_rec.apof;
                    END IF;

                    IF ( g_forklift_audit = 1 ) THEN
                        pl_text_log.ins_msg_async('INFO', l_func_name, 'The existing inventory in slot '
                                                            || i_pals(i).dest_loc
                                                            || ' has been removed.  Pickup pallet '
                                                            || i_pals(i).pallet_id
                                                            || '  in stack and put in slot '
                                                            || i_pals(i).dest_loc, sqlcode, sqlerrm);

                        pl_lm_goaltime.lmg_audit_cmt(pl_lm_goaltime.g_audit_batch_no,'The existing inventory in slot '
                                                                        || i_pals(i).dest_loc
                                                                        || ' has been removed.  Pickup pallet '
                                                                        || i_pals(i).pallet_id
                                                                        || '  in stack and put in slot '
                                                                        || i_pals(i).dest_loc,-1);

                        pl_lm_goaltime.lmg_audit_movement('BP',pl_lm_goaltime.g_audit_batch_no,i_e_rec,1,NULL);
                        IF ( l_aisle_stack_height > l_pallet_height ) THEN
                            pl_lm_goaltime.lmg_audit_movement('LE',pl_lm_goaltime.g_audit_batch_no,i_e_rec,l_aisle_stack_height - l_pallet_height,
                            NULL);
                        ELSE
                            pl_lm_goaltime.lmg_audit_movement('RE',pl_lm_goaltime.g_audit_batch_no,i_e_rec,l_pallet_height - l_aisle_stack_height,
                            NULL);
                            pl_lm_goaltime.lmg_audit_movement('APOF',pl_lm_goaltime.g_audit_batch_no,i_e_rec,1,NULL);
                        END IF; /* end audit */

                    END IF;

                END IF;

			  /*
			  **  Drop new pallet into slot.
			  **  If the existing inventory in the slot was removed for this drop
			  **  then the forks are at the floor otherwise the pallet to drop is
			  **  on the forks.
			  */

                IF ( l_remove_existing_inv = 1 ) THEN
					/*
					**  The existing inventory in the slot was removed on this drop.
					**  Their is 1 pallet in the travel stack so lower the forks to
					**  the floor, pickup the pallet and place it in the slot.
					*/
                    o_drop := o_drop + i_e_rec.mepof + i_e_rec.bt90;
                    IF ( g_forklift_audit = 1 ) THEN
                        pl_lm_goaltime.lmg_audit_movement('MEPOF',pl_lm_goaltime.g_audit_batch_no,i_e_rec,1,NULL);
                        pl_lm_goaltime.lmg_audit_movement('BT90',pl_lm_goaltime.g_audit_batch_no,i_e_rec,1,NULL);
                    END IF;

                ELSE
                    o_drop := o_drop + i_e_rec.tir;
                    IF ( g_forklift_audit = 1 ) THEN
                        pl_lm_goaltime.lmg_audit_movement('TIR',pl_lm_goaltime.g_audit_batch_no,i_e_rec,1,NULL);
                    END IF;

                END IF;

				  /*
				  ** Place the pallet in the slot.
				  */

                o_drop := o_drop + i_e_rec.apipb + raiseloaded(l_slot_height,i_e_rec) + i_e_rec.ppipb + i_e_rec.bt90;

                IF ( g_forklift_audit = 1 ) THEN
                    pl_lm_goaltime.lmg_audit_movement('APIPB',pl_lm_goaltime.g_audit_batch_no,i_e_rec,1,NULL);
                    pl_lm_goaltime.lmg_audit_movement('RL',pl_lm_goaltime.g_audit_batch_no,i_e_rec,l_slot_height,NULL);
                    pl_lm_goaltime.lmg_audit_movement('PPIPB',pl_lm_goaltime.g_audit_batch_no,i_e_rec,1,NULL);
                    pl_lm_goaltime.lmg_audit_movement('BT90',pl_lm_goaltime.g_audit_batch_no,i_e_rec,1,NULL);
                END IF; /* end audit */

            ELSE
			  /*
			  **  There is more than one pallet in the pallet stack.
			  **
			  **  Put the stack down (if not already down), take off the
			  **  top pallet and put it in the slot.
			  */
                IF ( g_forklift_audit = 1 ) THEN
                    pl_text_log.ins_msg_async('INFO', l_func_name, 'Remove pallet '
                                                        || i_pals(i).pallet_id
                                                        || 'from top of stack.', sqlcode, sqlerrm);

                    pl_lm_goaltime.lmg_audit_cmt(pl_lm_goaltime.g_audit_batch_no,'Remove pallet '
                                                                    || i_pals(i).pallet_id
                                                                    || 'from top of stack.',-1);

                END IF;

                IF ( i = l_pindex ) THEN
					/*
					**  First pallet being processed.  The stack has already
					**  been put down.  Get the top pallet off the stack.
					*/
                    o_drop := o_drop + i_e_rec.bp + i_e_rec.apos + raiseempty(l_pallet_height,i_e_rec) + i_e_rec.mepos;

                    IF ( g_forklift_audit = 1 ) THEN
                        pl_lm_goaltime.lmg_audit_movement('BP',pl_lm_goaltime.g_audit_batch_no,i_e_rec,1,NULL);
                        pl_lm_goaltime.lmg_audit_movement('APOS',pl_lm_goaltime.g_audit_batch_no,i_e_rec,1,NULL);
                        pl_lm_goaltime.lmg_audit_movement('RE',pl_lm_goaltime.g_audit_batch_no,i_e_rec,l_pallet_height,NULL);
                        pl_lm_goaltime.lmg_audit_movement('MEPOS',pl_lm_goaltime.g_audit_batch_no,i_e_rec,1,NULL);
                    END IF;

                ELSE
					/*
					**  The previous pallet has been put in the slot, remove
					**  the top pallet from the stack.  The forks are at the
					**  level of the slot.
					*/
                    IF ( l_slot_height > l_pallet_height ) THEN
                        o_drop := o_drop + lowerempty(l_slot_height - l_pallet_height,i_e_rec);
                        IF ( g_forklift_audit = 1 ) THEN
                            pl_lm_goaltime.lmg_audit_movement('LE',pl_lm_goaltime.g_audit_batch_no,i_e_rec,l_slot_height - l_pallet_height,NULL)
                            ;
                        END IF;

                    ELSE
                        o_drop := o_drop + raiseempty(l_pallet_height - l_slot_height,i_e_rec);
                        IF ( g_forklift_audit = 1 ) THEN
                            pl_lm_goaltime.lmg_audit_movement('RE',pl_lm_goaltime.g_audit_batch_no,i_e_rec,l_pallet_height - l_slot_height,NULL)
                            ;
                        END IF;

                    END IF;

                    IF ( i = 0 ) THEN
					  /*
					  **  At the last pallet in the stack so it is
					  **  on the floor.
					  */
                        o_drop := o_drop + i_e_rec.apof + i_e_rec.mepof;
                        IF ( g_forklift_audit = 1 ) THEN
                            pl_lm_goaltime.lmg_audit_movement('APOF',pl_lm_goaltime.g_audit_batch_no,i_e_rec,1,NULL);
                            pl_lm_goaltime.lmg_audit_movement('MEPOF',pl_lm_goaltime.g_audit_batch_no,i_e_rec,1,NULL);
                        END IF;

                    ELSE
						  /*
						  **  Get the pallet off the stack.
						  */
                        o_drop := o_drop + i_e_rec.apos + i_e_rec.mepos;
                        IF ( g_forklift_audit = 1 ) THEN
                            pl_lm_goaltime.lmg_audit_movement('APOS',pl_lm_goaltime.g_audit_batch_no,i_e_rec,1,NULL);
                            pl_lm_goaltime.lmg_audit_movement('MEPOS',pl_lm_goaltime.g_audit_batch_no,i_e_rec,1,NULL);
                        END IF;

                    END IF;

                END IF;

			  /*
			  **  The pallet is on the forks.  Move the forks up or down as
			  **  appropriate and put the pallet in the slot.
			  */

                IF ( l_slot_height > l_pallet_height ) THEN
                    o_drop := o_drop + i_e_rec.bt90 + i_e_rec.apipb + raiseloaded( (l_slot_height - l_pallet_height),i_e_rec) +
					i_e_rec.ppipb + i_e_rec.bt90;
                    
                ELSE
                    o_drop := o_drop + i_e_rec.bt90 + i_e_rec.apipb + lowerloaded( (l_pallet_height - l_slot_height),i_e_rec) +
					i_e_rec.ppipb + i_e_rec.bt90;
                    
                END IF;

                IF ( g_forklift_audit = 1 ) THEN
                    pl_text_log.ins_msg_async('INFO', l_func_name, 'Put pallet '
                                                        || i_pals(i).pallet_id
                                                        || ' in slot '
                                                        || i_pals(i).dest_loc, sqlcode, sqlerrm);

                    pl_lm_goaltime.lmg_audit_movement('BT90',pl_lm_goaltime.g_audit_batch_no,i_e_rec,1,'Put pallet '
                                                                                          || i_pals(i).pallet_id
                                                                                          || ' in slot '
                                                                                          || i_pals(i).dest_loc);

                    pl_lm_goaltime.lmg_audit_movement('APIPB',pl_lm_goaltime.g_audit_batch_no,i_e_rec,1,NULL);
                    IF ( l_slot_height > l_pallet_height ) THEN
                        pl_lm_goaltime.lmg_audit_movement('RL',pl_lm_goaltime.g_audit_batch_no,i_e_rec,l_slot_height - l_pallet_height,NULL);
                    ELSE
                        pl_lm_goaltime.lmg_audit_movement('LL',pl_lm_goaltime.g_audit_batch_no,i_e_rec,l_pallet_height - l_slot_height,NULL);
                        pl_lm_goaltime.lmg_audit_movement('PPIPB',pl_lm_goaltime.g_audit_batch_no,i_e_rec,1,NULL);
                        pl_lm_goaltime.lmg_audit_movement('BT90',pl_lm_goaltime.g_audit_batch_no,i_e_rec,1,NULL);
                    END IF;

                END IF; /* end audit */

            END IF; /* end more than one pallet in stack */

            l_num_drops_completed := l_num_drops_completed + 1;		/* Indicate a drop completed. */
            l_pallets_in_slot := l_pallets_in_slot + 1; 			/* Indicate a drop completed. */
            l_num_pallets_in_travel_stack := l_num_pallets_in_travel_stack - 1;		/* Indicate pallet removed from travel stack. */                                          
        END LOOP; /* end main drop to slot for loop */
		/*
		**  The forks are at the slot height.
		**  Lower the forks to the floor.
		*/

        o_drop := o_drop + lowerempty(l_slot_height,i_e_rec);
        IF ( g_forklift_audit = 1 ) THEN
            pl_lm_goaltime.lmg_audit_movement('LE',pl_lm_goaltime.g_audit_batch_no,i_e_rec,l_slot_height,NULL);
        END IF;

		/*
		**  Put back the existing inventory pallets that were removed if
		**  appropriate.
		**  For non putaway drops the pallets are always put back into the slot.
		**  For putaways the pallets are put back if this is the only putaway
		**  or the last putaway to the slot on the PO.
		*/

        IF ( l_putback_existing_inv = 1 ) THEN
            FOR i IN 0..(l_pallets_to_move - 1)
             LOOP
                o_drop := o_drop + i_e_rec.apof + i_e_rec.mepof + i_e_rec.bt90 + i_e_rec.apipb + raiseloaded(l_slot_height,i_e_rec
                ) + i_e_rec.mepipb + lowerempty(l_slot_height,i_e_rec) + i_e_rec.bt90;

                IF ( g_forklift_audit = 1 ) THEN
                    IF ( i = 0 ) THEN
                        pl_text_log.ins_msg_async('INFO', l_func_name, 'Replace existing inventory of  '
                                                            || l_pallets_to_move
                                                            || ' pallet(s) back in slot '
                                                            || i_pals(l_pindex).dest_loc, sqlcode, sqlerrm);

                        pl_lm_goaltime.lmg_audit_cmt(pl_lm_goaltime.g_audit_batch_no,'Replace existing inventory of  '
                                                                        || l_pallets_to_move
                                                                        || ' pallet(s) back in slot '
                                                                        || i_pals(l_pindex).dest_loc,-1);

                    END IF;

                    pl_lm_goaltime.lmg_audit_movement('APOF',pl_lm_goaltime.g_audit_batch_no,i_e_rec,1,'Put pallet back.');
                    pl_lm_goaltime.lmg_audit_movement('MEPOF',pl_lm_goaltime.g_audit_batch_no,i_e_rec,1,NULL);
                    pl_lm_goaltime.lmg_audit_movement('BT90',pl_lm_goaltime.g_audit_batch_no,i_e_rec,1,NULL);
                    pl_lm_goaltime.lmg_audit_movement('APIPB',pl_lm_goaltime.g_audit_batch_no,i_e_rec,1,NULL);
                    pl_lm_goaltime.lmg_audit_movement('RL',pl_lm_goaltime.g_audit_batch_no,i_e_rec,l_slot_height,NULL);
                    pl_lm_goaltime.lmg_audit_movement('MEPIPB',pl_lm_goaltime.g_audit_batch_no,i_e_rec,1,NULL);
                    pl_lm_goaltime.lmg_audit_movement('LE',pl_lm_goaltime.g_audit_batch_no,i_e_rec,l_slot_height,NULL);
                    pl_lm_goaltime.lmg_audit_movement('BT90',pl_lm_goaltime.g_audit_batch_no,i_e_rec,1,NULL);
                END IF;

            END LOOP;
        END IF;

		/*
		** Pickup stack if there are pallets left and go to the
		** next destination.
		*/

        IF ( l_num_pallets_in_travel_stack >= 1 ) THEN
			 /*
			 ** There are pallets still in the travel stack.
		     ** Pick up stack and go to next destination.
		     */
            pl_lm_goaltime.lmg_pickup_for_next_dst(i_pals,l_num_pallets_in_travel_stack - 1,i_e_rec,o_drop);
        END IF;

    END lmgpb_drp_pshbk_res_with_qoh; /* end lmgpb_drp_pshbk_res_with_qoh */
	
  /*****************************************************************************
  **  PROCEDURE:
  **      lmgpb_pickup_from_pushback_res()
  **
  **  DESCRIPTION:
  **      This Procedure calculates the LM drop discreet value for a pallet
  **      picked from a reserve pushback location.
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
  **      o_pickup       - Outgoing pickup value.
  **
  **  RETURN VALUES:
  **      None.
  *****************************************************************************/

    PROCEDURE lmgpb_pickup_from_pushback_res (
        i_pals           IN tbl_lmg_pallet_rec,
        i_pal_num_recs   IN NUMBER,
        i_pindex         IN NUMBER,
        i_e_rec          IN type_lmc_equip_rec,
        i_num_recs       IN NUMBER,
        i_inv            IN tbl_lmg_inv_rec,
        i_is_diff_item   IN VARCHAR2,
        o_pickup         OUT NUMBER
    ) AS

        l_func_name             VARCHAR2(50) := 'lmgpb_pickup_from_pushback_res';                                               
        l_ret_val               rf.status := rf.status_normal;
        l_slot_height           NUMBER := 0;
        l_pallet_height         NUMBER := 0;
        l_num_pallets_in_slot   NUMBER := 0;
        l_message               VARCHAR2(1025);
    BEGIN
        pl_text_log.ins_msg_async('INFO', l_func_name, 'Batch_no = '
                                            || i_pals(i_pindex).batch_no
                                            || ' pindex ='
                                            || i_pindex
                                            || ' equip_id = '
                                            || i_e_rec.equip_id
                                            || ' is_diff_item = '
                                            || i_is_diff_item, sqlcode, sqlerrm);

        l_slot_height := i_pals(i_pindex).height;
        l_num_pallets_in_slot := i_num_recs;
        l_pallet_height := std_pallet_height * i_pindex;
        IF ( g_forklift_audit = 1 ) THEN
            l_message := 'Pickup pallet = '
                       || i_pals(i_pindex).pallet_id
                       || ' slot_type = '
                       || i_pals(i_pindex).slot_type
                       || ' pallet_type = '
                       || i_pals(i_pindex).pallet_type
                       || ' loc = '
                       || i_pals(i_pindex).loc;

            pl_lm_goaltime.lmg_audit_cmt(pl_lm_goaltime.g_audit_batch_no,l_message,-1);
        END IF;

        IF ( i_pindex = 0 ) THEN
            o_pickup := o_pickup + i_e_rec.tir;
            IF ( g_forklift_audit = 1 ) THEN
                pl_lm_goaltime.lmg_audit_movement('TIR',pl_lm_goaltime.g_audit_batch_no,i_e_rec,1,NULL);
            END IF;

        ELSIF ( i_pindex > 0 ) THEN
            o_pickup := o_pickup + i_e_rec.bt90;
            IF ( g_forklift_audit = 1 ) THEN
                pl_lm_goaltime.lmg_audit_movement('BT90',pl_lm_goaltime.g_audit_batch_no,i_e_rec,1,NULL);
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

        IF ( i_pals(i_pindex).multi_pallet_drop_to_slot = 'N' ) THEN
            IF ( i_is_diff_item = 'Y' ) THEN
          /* Have a different item in slot, assume that the needed pallet
          ** is last.  Remove not needed pallets from rack.
          ** Pallets will not be stacked.
          */
                FOR i IN 0..l_num_pallets_in_slot - 1
                 LOOP
                    o_pickup := o_pickup + i_e_rec.apipb + raiseempty(l_slot_height,i_e_rec) + i_e_rec.mepipb + lowerloaded(l_slot_height,
                    i_e_rec) + i_e_rec.bt90 + i_e_rec.ppof + i_e_rec.bt90;

                    IF ( g_forklift_audit = 1 ) THEN
                        IF ( i = 0 ) THEN
                            l_message := 'Have different item in slot.  Remove not needed pallets ( '
                                       || l_num_pallets_in_slot
                                       || ' of them) from slot '
                                       || i_pals(i_pindex).loc;

                            pl_lm_goaltime.lmg_audit_cmt(pl_lm_goaltime.g_audit_batch_no,l_message,-1);
                            pl_lm_goaltime.lmg_audit_cmt(pl_lm_goaltime.g_audit_batch_no,'Pallets will not be stacked.  
							Assume the needed pallet is last in the slot.',-1);                           
                            pl_lm_goaltime.lmg_audit_cmt(pl_lm_goaltime.g_audit_batch_no,l_message,-1);
                        END IF;

                        l_message := 'Remove pallet from slot ' || i_pals(i_pindex).loc;
                        pl_lm_goaltime.lmg_audit_movement('APIPB',pl_lm_goaltime.g_audit_batch_no,i_e_rec,1,l_message);
                        pl_lm_goaltime.lmg_audit_movement('RE',pl_lm_goaltime.g_audit_batch_no,i_e_rec,l_slot_height,NULL);
                        pl_lm_goaltime.lmg_audit_movement('MEPIPB',pl_lm_goaltime.g_audit_batch_no,i_e_rec,1,NULL);
                        pl_lm_goaltime.lmg_audit_movement('LL',pl_lm_goaltime.g_audit_batch_no,i_e_rec,l_slot_height,NULL);
                        pl_lm_goaltime.lmg_audit_movement('BT90',pl_lm_goaltime.g_audit_batch_no,i_e_rec,1,NULL);
                        pl_lm_goaltime.lmg_audit_movement('PPOF',pl_lm_goaltime.g_audit_batch_no,i_e_rec,1,NULL);
                        pl_lm_goaltime.lmg_audit_movement('BT90',pl_lm_goaltime.g_audit_batch_no,i_e_rec,1,NULL);
                    END IF;

                END LOOP;

            END IF;
        END IF;

	  /*
	  **  Remove needed pallet from rack.
	  */

        o_pickup := o_pickup + i_e_rec.apipb;
        IF ( g_forklift_audit = 1 ) THEN
            l_message := 'Remove pallet '
                       || i_pals(i_pindex).pallet_id
                       || ' from slot '
                       || i_pals(i_pindex).loc;

            pl_lm_goaltime.lmg_audit_movement('APIPB',pl_lm_goaltime.g_audit_batch_no,i_e_rec,1,l_message);
        END IF;

	  /*
	  ** Move the forks to the level of the needed pallet.
	  */

        IF ( i_pals(i_pindex).multi_pallet_drop_to_slot = 'Y' ) THEN
			/*
			** The previous pallet picked up came from this same slot.  The
			** forks are at the height of where this previous pallet was placed.
			** Move the forks up or down to get them at the same height as the
			** pallet being removed from the slot.
			*/
            IF ( l_slot_height > ( std_pallet_height * ( i_pindex - 1 ) ) ) THEN
                o_pickup := o_pickup + raiseempty( (l_slot_height - (std_pallet_height * (i_pindex - 1) ) ),i_e_rec);

                IF ( g_forklift_audit = 1 ) THEN
                    pl_lm_goaltime.lmg_audit_movement('RE',pl_lm_goaltime.g_audit_batch_no,i_e_rec, (l_slot_height - (std_pallet_height * (i_pindex
                    - 1) ) ),NULL);

                END IF;

            ELSE
                o_pickup := o_pickup + lowerempty( ( (std_pallet_height * (i_pindex - 1) ) - l_slot_height),i_e_rec);

                IF ( g_forklift_audit = 1 ) THEN
                    pl_lm_goaltime.lmg_audit_movement('LE',pl_lm_goaltime.g_audit_batch_no,i_e_rec, ( (std_pallet_height * (i_pindex - 1) ) - l_slot_height
                    ),NULL);

                END IF;

            END IF;
        ELSE
			/*
			** This is the first pallet picked up from this slot.  The forks will
			** be at the floor.
			*/
            o_pickup := o_pickup + raiseempty(l_slot_height,i_e_rec);
            IF ( g_forklift_audit = 1 ) THEN
                pl_lm_goaltime.lmg_audit_movement('RE',pl_lm_goaltime.g_audit_batch_no,i_e_rec,l_slot_height,NULL);
            END IF;

        END IF;

		  /*
		  ** The forks are at the level of the needed pallet. Get it out of the
		  ** slot.
		  */

        o_pickup := o_pickup + i_e_rec.mepipb;
        IF ( g_forklift_audit = 1 ) THEN
            pl_lm_goaltime.lmg_audit_movement('MEPIPB',pl_lm_goaltime.g_audit_batch_no,i_e_rec,1,NULL);
        END IF;

        IF ( i_pindex > 0 ) THEN
			/*
			** There are other pallets that have been picked up.  Put the pallet
			** removed from the slot onto the stack.
			*/
            IF ( l_pallet_height > l_slot_height ) THEN
                o_pickup := o_pickup + raiseloaded( (l_pallet_height - l_slot_height),i_e_rec);
            ELSE
                o_pickup := o_pickup + lowerloaded( (l_slot_height - l_pallet_height),i_e_rec);
            END IF;

            o_pickup := o_pickup + i_e_rec.bt90 + i_e_rec.ppos;
            IF ( g_forklift_audit = 1 ) THEN
                IF ( l_pallet_height > l_slot_height ) THEN
                    pl_lm_goaltime.lmg_audit_movement('RL',pl_lm_goaltime.g_audit_batch_no,i_e_rec,l_pallet_height - l_slot_height,NULL);
                ELSE
                    pl_lm_goaltime.lmg_audit_movement('LL',pl_lm_goaltime.g_audit_batch_no,i_e_rec,l_slot_height - l_pallet_height,NULL);
                    pl_lm_goaltime.lmg_audit_movement('BT90',pl_lm_goaltime.g_audit_batch_no,i_e_rec,1,NULL);
                    pl_lm_goaltime.lmg_audit_movement('PPOS',pl_lm_goaltime.g_audit_batch_no,i_e_rec,1,NULL);
                END IF;

                IF ( i_pindex = ( i_pal_num_recs - 1 ) ) THEN
                    o_pickup := o_pickup + lowerempty(l_pallet_height,i_e_rec);
                    IF ( g_forklift_audit = 1 ) THEN
                        pl_lm_goaltime.lmg_audit_movement('LE',pl_lm_goaltime.g_audit_batch_no,i_e_rec,l_pallet_height,NULL);
                    END IF;

                END IF;

            ELSE
			  /*
			  ** This is the first pallet picked up (there is nothing in the stack).
			  */
                o_pickup := o_pickup + lowerloaded(l_slot_height,i_e_rec) + i_e_rec.bt90;
                IF ( ( i_pal_num_recs > 1 ) OR ( i_is_diff_item = 'Y' ) ) THEN
                    o_pickup := o_pickup + i_e_rec.ppof;
                    IF ( g_forklift_audit = 1 ) THEN
                        pl_lm_goaltime.lmg_audit_movement('LL',pl_lm_goaltime.g_audit_batch_no,i_e_rec,l_slot_height,NULL);
                        pl_lm_goaltime.lmg_audit_movement('BT90',pl_lm_goaltime.g_audit_batch_no,i_e_rec,1,NULL);
                        IF ( ( i_pal_num_recs > 1 ) OR ( i_is_diff_item = 'Y' ) ) THEN
                            pl_lm_goaltime.lmg_audit_movement('PPOF',pl_lm_goaltime.g_audit_batch_no,i_e_rec,1,NULL);
                        END IF;

                    END IF;

                END IF;

            END IF;

        END IF;

	  /*
	  ** If this is the last pallet to pickup from the slot and pallets were
	  ** removed from the slot in order to get to the pallet then put these
	  ** pallets back in the slot.
	  */

        IF ( i_pals(i_pindex).multi_pallet_drop_to_slot = 'N' ) THEN
            IF ( i_is_diff_item = 'Y' ) THEN
                o_pickup := o_pickup + i_e_rec.bp;
                IF ( g_forklift_audit = 1 ) THEN
                    pl_lm_goaltime.lmg_audit_movement('BP',pl_lm_goaltime.g_audit_batch_no,i_e_rec,1,NULL);
                END IF;

			  /*
			  **  Replace remaining pallets into rack.
			  **  Pallets are not stacked.
			  */

                FOR i IN 0..(l_num_pallets_in_slot-1) 

                 LOOP
                    o_pickup := o_pickup + i_e_rec.apof + i_e_rec.mepof + i_e_rec.bt90 + raiseloaded(l_slot_height,i_e_rec) 
					+ i_e_rec.apipb + i_e_rec.ppipb + lowerempty(l_slot_height,i_e_rec) + i_e_rec.bt90;
                    
                    IF ( g_forklift_audit = 1 ) THEN
                        IF ( i = 0 ) THEN
                            pl_text_log.ins_msg_async('INFO', l_func_name, 'Put pallets  '
                                                                || l_num_pallets_in_slot
                                                                || ' Of them back in slot '
                                                                || i_pals(i_pindex).loc, sqlcode, sqlerrm);

                            pl_lm_goaltime.lmg_audit_cmt(pl_lm_goaltime.g_audit_batch_no,'Put pallets  '
                                                                            || l_num_pallets_in_slot
                                                                            || ' Of them back in slot '
                                                                            || i_pals(i_pindex).loc,-1);

                        END IF;

                        pl_text_log.ins_msg_async('INFO', l_func_name, 'Put pallet back in slot  ' || i_pals(i_pindex).loc, sqlcode, sqlerrm);

                        pl_lm_goaltime.lmg_audit_movement('APOF',pl_lm_goaltime.g_audit_batch_no,i_e_rec,1,'Put pallet back in slot  ' 
																					|| i_pals(i_pindex).loc);
                     
                        pl_lm_goaltime.lmg_audit_movement('MEPOF',pl_lm_goaltime.g_audit_batch_no,i_e_rec,1,NULL);
                        pl_lm_goaltime.lmg_audit_movement('BT90',pl_lm_goaltime.g_audit_batch_no,i_e_rec,1,NULL);
                        pl_lm_goaltime.lmg_audit_movement('RL',pl_lm_goaltime.g_audit_batch_no,i_e_rec,l_slot_height,NULL);
                        pl_lm_goaltime.lmg_audit_movement('APIPB',pl_lm_goaltime.g_audit_batch_no,i_e_rec,1,NULL);
                        pl_lm_goaltime.lmg_audit_movement('PPIPB',pl_lm_goaltime.g_audit_batch_no,i_e_rec,1,NULL);
                        pl_lm_goaltime.lmg_audit_movement('LE',pl_lm_goaltime.g_audit_batch_no,i_e_rec,l_slot_height,NULL);
                        pl_lm_goaltime.lmg_audit_movement('BT90',pl_lm_goaltime.g_audit_batch_no,i_e_rec,1,NULL);
                    END IF;

                END LOOP;

            END IF;
        END IF;

        IF ( i_pindex = 0 ) THEN
			/*
			**  Pickup stack and go to next slot.
			*/
            IF ( i_is_diff_item = 'Y' ) THEN
                o_pickup := o_pickup + i_e_rec.apof + i_e_rec.mepof;
                IF ( g_forklift_audit = 1 ) THEN
                    pl_lm_goaltime.lmg_audit_movement('APOF',pl_lm_goaltime.g_audit_batch_no,i_e_rec,1,NULL);
                    pl_lm_goaltime.lmg_audit_movement('MEPOF',pl_lm_goaltime.g_audit_batch_no,i_e_rec,1,NULL);
                END IF;

            ELSIF ( i_pal_num_recs > 1 ) THEN
                o_pickup := o_pickup + i_e_rec.bp + i_e_rec.apof + i_e_rec.mepof;
                IF ( g_forklift_audit = 1 ) THEN
                    pl_lm_goaltime.lmg_audit_movement('BP',pl_lm_goaltime.g_audit_batch_no,i_e_rec,1,NULL);
                    pl_lm_goaltime.lmg_audit_movement('APOF',pl_lm_goaltime.g_audit_batch_no,i_e_rec,1,NULL);
                    pl_lm_goaltime.lmg_audit_movement('MEPOF',pl_lm_goaltime.g_audit_batch_no,i_e_rec,1,NULL);
                END IF;

            END IF;
        END IF;

        return;
    END lmgpb_pickup_from_pushback_res; /* end lmgpb_pickup_from_pushback_res */
	
/*******************************************************************************
      NAME            : raiseempty
      DESCRIPTION     : calculates distance
      CALLED BY       : lmpb_drp_to_pshbk_hm_with_qoh
      IN PARAMETERS   :
          i_inches 
          i_e_rec   
      
      RETURN VALUE:
  		calculated distance
  ********************************************************************************/  

    FUNCTION raiseempty (
        i_inches   IN NUMBER,
        i_e_rec    IN type_lmc_equip_rec
    ) RETURN NUMBER AS
    BEGIN
        return( ( (i_inches) / 12.0) * (i_e_rec.re) );
    END raiseempty;

/*******************************************************************************
      NAME            : lowerloaded
      DESCRIPTION     : calculates distance
      CALLED BY       : lmpb_drp_to_pshbk_hm_with_qoh
      IN PARAMETERS   :
          i_inches 
          i_e_rec   
      
      RETURN VALUE:
  		calculated distance
********************************************************************************/  
  
    FUNCTION lowerloaded (
        i_inches   IN NUMBER,
        i_e_rec    IN type_lmc_equip_rec
    ) RETURN NUMBER AS
    BEGIN
        return( ( (i_inches) / 12.0) * (i_e_rec.ll) );
    END lowerloaded;

/*******************************************************************************
      NAME            : raiseloaded
      DESCRIPTION     : calculates distance
      CALLED BY       : lmpb_drp_to_pshbk_hm_with_qoh
      IN PARAMETERS   :
          i_inches 
          i_e_rec   
      
      RETURN VALUE:
  		calculated distance
********************************************************************************/  

    FUNCTION raiseloaded (
        i_inches   IN NUMBER,
        i_e_rec    IN type_lmc_equip_rec
    ) RETURN NUMBER AS
    BEGIN
        return( ( (i_inches) / 12.0) * (i_e_rec.rl) );
    END raiseloaded;

/*******************************************************************************
      NAME            : lowerempty
      DESCRIPTION     : calculates distance
      CALLED BY       : lmpb_drp_to_pshbk_hm_with_qoh
      IN PARAMETERS   :
          i_inches 
          i_e_rec   
      
      RETURN VALUE:
  		calculated distance
********************************************************************************/  

    FUNCTION lowerempty (
        i_inches   IN NUMBER,
        i_e_rec    IN type_lmc_equip_rec
    ) RETURN NUMBER AS
    BEGIN
        return( ( (i_inches) / 12.0) * (i_e_rec.le) );
    END lowerempty;

END pl_lm_goal_pb;
/

GRANT EXECUTE ON pl_lm_goal_pb TO swms_user;
