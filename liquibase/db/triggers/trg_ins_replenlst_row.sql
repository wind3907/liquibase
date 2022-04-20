/******************************************************************************
  @(#) TRG_INS_replenlst_ROW.sql
  @(#) src/schema/triggers/trg_ins_replenlst_row.sql, swms, swms.9, 10.1.1 9/8/06 1.3
  01/10/13 sray0453 CRQ38719 Corrected MFG_DATE which is wrong in DMD RPL

-- Modification History:
--    Date     Designer Comments
--    -------- -------- -----------------------------------------------------
--    10/01/15 bben0556 Brian Bent
--                      Symbotic project.  WIB 543
--
--                      Bug fix--user getting "No LM batch" error message
--                      on RF when attempting to perform a DXL or DSP
--                      replenishment.  No transactions cretaed for DXL and DSP.
--
--                      Add DXL and DSP replenishment types.
--
--
--    07/19/16 bben0556 Brian Bent
--                      Project:
--                R30.5--WIB#663--CRQ000000007533_Save_what_created_NDM_in_trans_RPL_record
--
--                      Specify parameters by name in call to "pl_insert_replen_trans".
--                      Add parameter "i_replen_creation_type" in call to
--                      "pl_insert_replen_trans".
--
--    09/28/21 bben0556 Brian Bent
--                      R1 cross dock.
--                      Card: R47_0-xdock-OPCOF3611_Site_2_XDK_task_PFK_DFK_transactions_not_created
--
--                      PFK and DFK transactions are not created when completing a XDK task.
--                      Add handling XDK task.
--
--    10/21/21 bben0556 Brian Bent
--                      R1 cross dock.
--                      Card: R47_0-xdock-OPCOF3725_Site_2_Create_PIK_transaction_for_cross_dock_pallet
--
--                      Add cross_dock_type in call to procedure ""pl_insert_replen_trans".
--
-----------------------------------------------------------------------------
******************************************************************************/

CREATE OR REPLACE TRIGGER swms.TRG_INS_replenlst_ROW
AFTER INSERT ON swms.Replenlst
FOR EACH ROW
BEGIN
	DECLARE
		sccs_id		VARCHAR2 (128) := '@(#) src/schema/triggers/trg_ins_replenlst_row.sql, swms, swms.9, 10.1.1 9/8/06 1.3';
		l_type  VARCHAR (4) := :NEW.type;
		l_door  NUMBER  (4) := :NEW.door_no;
	BEGIN

		IF (:NEW.type IN ('DMD', 'BLK', 'XDK', 'DXL', 'DSP')) THEN
		BEGIN
			SELECT  DECODE (l_type, 'DMD', NULL,
                                                'DXL', NULL,
                                                'DSP', NULL,
                                                l_door)
			  INTO  l_door
			  FROM  DUAL;
			pl_insert_replen_trans
                               (r_prod_id              => :NEW.prod_id,
				r_drop_qty             => :NEW.drop_qty,
				r_uom                  => :NEW.uom,
				r_src_loc              => :NEW.src_loc,
				r_dest_loc             => :NEW.dest_loc,
				r_pallet_id            => :NEW.pallet_id,
				r_user_id              => :NEW.user_id,
				r_order_id             => :NEW.order_id,
				r_route_no             => :NEW.route_no,
				r_cust_pref_vendor     => :NEW.cust_pref_vendor,
				r_batch_no             => :NEW.batch_no,
				r_float_no             => :NEW.float_no,
				r_type                 => :NEW.type,
				r_status               => :NEW.status,
				r_qty                  => :NEW.qty,
				r_task_id              => :NEW.task_id,
				r_door_no              => l_door,
				r_exp_date             => :NEW.exp_date,
				r_mfg_date             => :NEW.mfg_date,
				operation              => 'INSERT',
				r_inv_dest_loc         => :NEW.inv_dest_loc,
                                i_replen_creation_type => :NEW.replen_type,
                                i_cross_dock_type      => :NEW.cross_dock_type);
		END;
		END IF;
	END;
END;
/

