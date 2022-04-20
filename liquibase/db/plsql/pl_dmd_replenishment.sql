
PROMPT Creating package PL_DMD_REPLENISHMENT ..

CREATE OR REPLACE PACKAGE swms.pl_dmd_replenishment
AS
--  sccs_id=@(#) src/schema/plsql/pl_dmd_replenishment.sql, swms, swms.9, 10.1.1 9/7/06 1.3

---------------------------------------------------------------------------
-- Package Name:
--    pl_dmd_replenishment.
--
-- Description:
--    Common procedures and functions within SWMS for DMD Replenishment.
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    08/01/05 acppsp   Initial Version.
--    08/02/05 acppsp   Added procedure to create the DMD replenishment.
--    05/06/06 prppxx   D#12092 Corrected sql stmt for trans_id of DFK.
--
--    07/19/16 bben0556 Brian Bent
--                      Project:
--                R30.5--WIB#663--CRQ000000007533_Save_what_created_NDM_in_trans_RPL_record
--
--                      Specify parameters by name in call to "pl_insert_replen_trans".
--
--------------------------------------------------------------------------

   ---------------------------------------------------------------------------
   -- Global Variables
   --------------------------------------------------------------------------
   gv_crt_message    VARCHAR2(4000);--for CRT messages
   gv_program_name   VARCHAR2(50) := 'pl_dmd_replenishment'; -- Package name.
   g_send_dmd_rpl_to_rf		VARCHAR2 (1) := NULL;
   g_enable_pallet_flow		VARCHAR2 (1) := NULL;                                   
   ---------------------------------------------------------------------------
   -- Public Constants
   ---------------------------------------------------------------------------

  
  ---------------------------------------------------------------------------
   -- Procedure Declarations
  ---------------------------------------------------------------------------

   PROCEDURE Insert_DMD_Replenishment (i_pallet_id	floats.pallet_id%TYPE,
                                       i_drop_qty   replenlst.drop_qty%TYPE,
									   i_src_loc    loc.logi_loc%TYPE);

   ---------------------------------------------------------------------------
   -- Function Declarations
   ---------------------------------------------------------------------------



   FUNCTION f_insert_ppd_transaction(i_option       IN  VARCHAR2,
                                     i_src_loc      IN  loc.logi_loc%TYPE,
									 i_pallet_id    IN  replenlst.pallet_id%TYPE,
									 i_transfer_qty IN  trans.qty%TYPE,
									 o_trans_id     OUT trans.trans_id%TYPE)
   RETURN NUMBER;

END pl_dmd_replenishment;
/


PROMPT Creating package body PL_DMD_REPLENISHMENT ..

CREATE OR REPLACE PACKAGE BODY swms.pl_dmd_replenishment
AS
   --  sccs_id=@(#) src/schema/plsql/pl_dmd_replenishment.sql, swms, swms.9, 10.1.1 9/7/06 1.3

----------------------------------------------------------------------------
/*   -----------------------------------------------------------------------
    -- Function:
    --    f_insert_ppd_transaction
    --
    -- Description:
    --    This function inserts the PPD transaction that desigates
    --    that the HST during DMD replenishment has strated.  
    --
    -- Parameters:
    --     i_option         - How the HST was initiated.
    --                        Valid values:
    --                         P  HST initiated during putaway.
    --                         R  HST during replenishment.
    --     i_src_loc        - The HST source location. 
    --                        If it is not a perm slot then an error is returned.
    --     i_pallet_id      - Pallet id.
    --     i_transfer_qty   - Quantity in cases being transferred.  The qty
    --                        quantity in the trans record will be splits.
    --     o_trans_id       - Transaction id of the PPD transaction created.
    --                        It needs to be sent back to the RF unit because
    --                        it is needed when completing the HST.
    --
    --
    -- Return Values:
    --    NORMAL       - Successfully created the PPD transaction.
    --                   Anything else donotes a failure.
    -- Exceptions raised:
    --
   ---------------------------------------------------------------------*/

 FUNCTION f_insert_ppd_transaction(i_option       IN  VARCHAR2,
                                   i_src_loc      IN  loc.logi_loc%TYPE,
								   i_pallet_id    IN  replenlst.pallet_id%TYPE,
								   i_transfer_qty IN  trans.qty%TYPE,
								   o_trans_id     OUT trans.trans_id%TYPE)
 RETURN NUMBER
 IS

   lv_object_name       VARCHAR2(30) := 'lmf_insert_ppd_transaction';
   lv_message           VARCHAR2(512);    -- Message buffer
   lv_cmt               trans.cmt%TYPE;   -- Transaction comment
   lv_fname             VARCHAR2(50)  := 'f_insert_ppd_transaction';
   lv_home_slot         loc.logi_loc%TYPE := i_src_loc;   -- Home slot.
   lv_src_loc           loc.logi_loc%TYPE;  -- The source location of the transfer.  For flow slots it will
                                      -- be the back location.
   lv_temp_loc          loc.logi_loc%TYPE;  -- Work area.
   
   l_status             NUMBER;
   e_no_record_inserted EXCEPTION; -- NO PPH Transaction created. 
   
BEGIN
  
   -- Build the value for column trans.cmt.  When the user completes
   -- the home slot transfer the PPD transaction is updated to a
   -- DHT transaction and the cmt column is updated to the trans id.
   -- This is similar to the PPH and HST transactions.
   
   IF (i_option = 'R') THEN
     lv_cmt := 'PALLET PICKED FOR NORMAL Home Slot Transfer';
   ELSIF (i_option = 'P') THEN
     lv_cmt := 'PALLET PICKED FOR HOME SLOT TRANSFER DURING A DROP';
   ELSE
     -- Got an handled value but do not let it stop processing
     lv_cmt := lv_object_name || ' Unhandled value[' ||
              i_option || '] for i_option.';
     pl_log.ins_msg('WARN', lv_object_name,  lv_cmt, NULL, NULL);
   END IF;

   SELECT trans_id_seq.NEXTVAL INTO o_trans_id FROM DUAL;
   /*
   ** Home slot transfer is only for cases so the trans uom is set to 0.
   ** Make adjustments for flow slots.  The source location passed in
   ** should be the home slot but if it is a back location then it will
   ** be handled correctly.
   */
   
   IF (pl_common.f_get_syspar('ENABLE_PALLET_FLOW', 'N') = 'Y') THEN
       
	   lv_temp_loc := pl_pflow.f_get_back_loc(lv_home_slot);

       IF (lv_temp_loc = 'NONE') THEN
            -- lv_home_slot not a home location of a flow slot.  Check
            -- if it is a back location.
            lv_temp_loc := pl_pflow.f_get_pick_loc(lv_home_slot);
            IF (lv_temp_loc = 'NONE') THEN
               -- lv_home_slot is not a back location. It is a home slot for
               -- a non-flow slot.
               lv_src_loc := lv_home_slot;
            ELSE
               -- lv_home_slot is a back location.
               lv_src_loc := lv_home_slot;
               lv_home_slot := lv_temp_loc;
            END IF;
       ELSE
            -- lv_home_slot is the home location of a flow slot.
            lv_src_loc := lv_temp_loc;  -- The source loc of the HST
                                      -- is the back location.
       END IF;
   ELSE
       lv_src_loc := lv_home_slot;
   END IF;

   INSERT INTO trans (trans_id,
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
                      cmt)
              SELECT  o_trans_id                     trans_id,
                      'PPD'                          trans_type,
                      SYSDATE                        trans_date,
                      USER                           user_id,
                      l.prod_id                      prod_id,
                      l.cust_pref_vendor             cust_pref_vendor,
                      lv_src_loc                     src_loc,
                      '?'                            dest_loc,
                      i_pallet_id                    pallet_id,
                      i_transfer_qty * NVL(p.spc,1)  qty,
                      0                              uom,
                      99                             batch_no, -- Done by forklift
                      lv_cmt                         cmt
                FROM pm p, loc l
               WHERE l.logi_loc         = lv_home_slot
                 AND l.perm             = 'Y'
                 AND p.prod_id          = l.prod_id
                 AND p.cust_pref_vendor = l.cust_pref_vendor;
   
   IF (SQL%ROWCOUNT = 0) THEN
     RAISE e_no_record_inserted;
   END IF;
   
   l_status := 0;
   RETURN l_status;

   EXCEPTION
     WHEN e_no_record_inserted THEN
         lv_message := lv_object_name ||
            ' TABLE=loc_reference,pm,loc  ACTION=SELECT' ||
            ' loc[ ' || lv_home_slot || '] Insert into trans to' ||
            ' create PPD transaction using select from tables returned' ||
            ' 0 ROWCOUNT';
         pl_log.ins_msg('FATAL', lv_object_name, lv_message,
                         SQLCODE, SQLERRM);
         l_status := 1;
         RETURN l_status;
    WHEN OTHERS THEN
         pl_log.ins_msg('FATAL', lv_object_name,
            'Failed to create PPD transaction for location[' ||
            lv_home_slot || ']', SQLCODE, SQLERRM);
         l_status := 1;
         RETURN l_status;

END f_insert_ppd_transaction;
------------------------------------------------------------------------------
/*   -----------------------------------------------------------------------
    -- Function:
    --    Insert_DMD_Replenishment
    --
    -- Description:
    --    This procedure creates the DMD replenishment task when the 
    --    original DMD task is completed partially due to the space constraint in 
    --    pick slot and some qty has been HST to the reserve.
    --    The procedure will create the DMD replnishment task for the HST qty.
    --
    -- Parameters:
    --     i_pallet_id         - This is the pallet_id of the pallet which had a DMD replenishment
    --                           task originally.
    --     i_drop_qty          - The DMD replenishment will be generated for HST qty.
    --
    --
    --
   ---------------------------------------------------------------------*/
PROCEDURE Insert_DMD_Replenishment (i_pallet_id	floats.pallet_id%TYPE,
                                    i_drop_qty   replenlst.drop_qty%TYPE,
									i_src_loc    loc.logi_loc%TYPE) IS
		l_object_name	VARCHAR2(61) := gv_program_name || '.Insert_DMD_Replenishment';

		CURSOR	c_floats (i_pallet_id VARCHAR2,
		                  i_trans_id NUMBER) IS
			SELECT	f.equip_id, f.pallet_pull,
				    f.home_slot dest_loc,
				    DECODE (f.pallet_pull, 'R', NULL,
					        DECODE (f.door_area,
						            'C', r.c_door,
						            'F', r.f_door,
						             r.d_door)) door_no,
				    f.route_no, f.float_no,
				    r.route_batch_no, r.truck_no,
				    fd.prod_id,
				    MAX (fd.order_id) order_id,
				    MAX (fd.order_line_id) order_line_id,
				    NVL(MAX (fd.uom),0) uom,
				    t.exp_date,
				    t.rec_id, p.cust_pref_vendor,
				    p.spc
			  FROM	pm p, loc l, trans t, route r, float_detail fd, floats f
			 WHERE	f.pallet_id = i_pallet_id
			   AND	fd.float_no = f.float_no
			   AND  t.trans_id  = i_trans_id
			   AND  t.float_no  = fd.float_no
			   AND	r.route_no = f.route_no
			   AND	p.prod_id = fd.prod_id
			   AND	p.cust_pref_vendor = fd.cust_pref_vendor
			 GROUP	BY f.equip_id, f.pallet_pull,
					   f.home_slot,
				       DECODE (f.door_area,
					           'C', r.c_door,
					           'F', r.f_door,
					           r.d_door),
				       f.route_no, f.float_no,
				       r.route_batch_no, r.truck_no,
				       fd.prod_id,
				       t.exp_date,t.rec_id, p.cust_pref_vendor,
				       p.spc;
				       
		CURSOR	c_loc_ref (sLogiLoc	VARCHAR2) IS
			SELECT	plogi_loc
			  FROM	loc_reference
			 WHERE	bck_logi_loc = sLogiLoc;

		r_floats	c_floats%ROWTYPE;
		l_trans_id  trans.trans_id%TYPE;
		l_pik_path  loc.pik_path%TYPE;
		r_plogi_loc	loc_reference.plogi_loc%TYPE;
		l_qty_order	replenlst.qty%TYPE;
		l_drop_qty	replenlst.drop_qty%TYPE;
		l_dmd_attempts replenlst.dmd_repl_attempts%TYPE;		
		
	BEGIN
		IF (pl_dmd_replenishment.g_send_dmd_rpl_to_rf IS NULL) THEN
			g_send_dmd_rpl_to_rf := pl_common.f_get_syspar ('SEND_DMD_RPL_TO_RF', 'N');
		END IF;
		IF (pl_dmd_replenishment.g_enable_pallet_flow IS NULL) THEN
			g_enable_pallet_flow := pl_common.f_get_syspar ('ENABLE_PALLET_FLOW', 'N');
		END IF;
		
		/* D#12092 prppxx corrected the stmt that may result multi-records */
		BEGIN
		  SELECT trans_id 
		    INTO l_trans_id
		    FROM trans
		   WHERE pallet_id  = i_pallet_id
		     AND trans_type = 'DFK'
		     AND trans_date = (SELECT MAX(trans_date) 
		                         FROM trans
		                        WHERE pallet_id  = i_pallet_id
		                          AND trans_type = 'DFK'); 
		EXCEPTION 
		  WHEN OTHERS THEN
		     RAISE;
		END;
		                        
        /* Retrieve the Pik path for the reserve location*/
		SELECT pik_path 
          	  INTO l_pik_path
		  FROM loc
		 WHERE logi_loc = i_src_loc;		                        
		
		OPEN	c_floats (i_pallet_id,l_trans_id);
		FETCH	c_floats INTO r_floats;
		
		/* Retriev the DMD replenishment attempts */
		SELECT COUNT(trans_id) 
		  INTO l_dmd_attempts
		  FROM trans
		 WHERE pallet_id = i_pallet_id
		   AND trans_type = 'DFK';
		
		IF (c_floats%FOUND) THEN
			r_plogi_loc := NULL;
			IF (pl_dmd_replenishment.g_enable_pallet_flow = 'Y' AND r_floats.pallet_pull = 'R') THEN
			BEGIN
				OPEN c_loc_ref (r_floats.dest_loc);
				FETCH c_loc_ref INTO r_plogi_loc;
				
				IF (c_loc_ref%NOTFOUND) THEN
				  r_plogi_loc := r_floats.dest_loc;
				END IF;
			END;
			END IF;
			
			--l_qty_order := r_floats.qty_order / r_floats.spc;
			l_drop_qty  := i_drop_qty / r_floats.spc;
			
			IF (pl_dmd_replenishment.g_send_dmd_rpl_to_rf = 'Y') THEN
				BEGIN
					INSERT	INTO replenlst (
						task_id,
						prod_id,
						uom,
						qty,
						type,
						status,
						src_loc,
						pallet_id,
						dest_loc,
						s_pikpath,
						d_pikpath,
						batch_no,
						equip_id,
						order_id,
						user_id,
						op_acquire_flag,
						cust_pref_vendor,
						gen_uid,
						gen_date,
						exp_date,
						route_no,
						float_no,
						seq_no,
						route_batch_no,
						truck_no,
						inv_dest_loc,
						drop_qty,
						door_no,
						dmd_repl_attempts)
					VALUES (repl_id_seq.NEXTVAL,
						r_floats.prod_id,
						r_floats.uom,
						l_drop_qty,
						'DMD',
						'NEW',
						i_src_loc,
						i_pallet_id,
						r_floats.dest_loc,
						l_pik_path,
						NULL,
						0,
						r_floats.equip_id,
						r_floats.order_id,
						NULL,
						'Y',
						r_floats.cust_pref_vendor,
						REPLACE (USER, 'OPS$'),
						SYSDATE,
						r_floats.exp_date,
						r_floats.route_no,
						r_floats.float_no,
						1,
						r_floats.route_batch_no,
						r_floats.truck_no,
						r_plogi_loc,
						0,
						NULL,
						DECODE(l_dmd_attempts,0,NULL,l_dmd_attempts));
				END;
			ELSE
				BEGIN
					
						swms.pl_insert_replen_trans
                                                         (r_prod_id          => r_floats.prod_id,
                                                          r_drop_qty         => 0,
                                                          r_uom              => r_floats.uom,
                                                          r_src_loc          => i_src_loc,
                                                          r_dest_loc         => r_plogi_loc,
                                                          r_pallet_id        => i_pallet_id,
                                                          r_user_id          => REPLACE(USER, 'OPS$'),
                                                          r_order_id         => r_floats.order_id,
                                                          r_route_no         => r_floats.route_no,
                                                          r_cust_pref_vendor => r_floats.cust_pref_vendor,
                                                          r_batch_no         => 0,
                                                          r_float_no         => r_floats.float_no,
                                                          r_type             => 'DMD',
                                                          r_status           => 'NEW',
                                                          r_qty              => l_drop_qty,
                                                          r_task_id          => 0,
                                                          r_door_no          => NULL,
                                                          r_exp_date         => r_floats.exp_date,
                                                          r_mfg_date         => NULL,
                                                          operation          => 'INSERT',
                                                          r_inv_dest_loc     => r_floats.dest_loc);
				END;
			END IF;
			IF (c_loc_ref%ISOPEN) THEN
				CLOSE	c_loc_ref;
			END IF;
		END IF;
		CLOSE	c_floats;
	EXCEPTION
	   WHEN OTHERS THEN
         	pl_log.ins_msg('FATAL', l_object_name,
            		'Failed to create DMD in replenlst for pallet/loc/qty[' ||
            		i_pallet_id || '/' ||
			i_src_loc || '/' ||
			to_char(i_drop_qty) || ']', SQLCODE, SQLERRM);
		RAISE_APPLICATION_ERROR(pl_exc.ct_database_error,
					l_object_name || ': ' || SQLERRM);
	END Insert_DMD_Replenishment;
------------------------------------------------------------------------------
BEGIN
  --this is used for initialising global variables once
  --global variables set for logging the errors in swms_log table

     pl_log.g_application_func := 'REPLENISHMENT';

END pl_dmd_replenishment;
/

