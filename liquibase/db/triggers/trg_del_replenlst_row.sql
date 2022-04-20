/******************************************************************************
  @(#) TRG_DEL_replenlst_ROW.sql
  01/10/13 sray0453 CRQ38719: MFG_DATE is wrong in DMD RPL
-----------------------------------------------------------------------------
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
--    06/29/16 bben0556 Brian Bent
--                      Symbotic project:
--       R30.4.2--WIB#646--Charm6000013323_Symbotic_replenishment_fixes
--
--                      DFK transaction created if matrix replenlst in PND status.
--                      Account for PND status.
--                      Change
-- IF ((:OLD.type IN ('DMD', 'BLK', 'DXL', 'DSP'))  AND (:OLD.status != 'NEW')) THEN
--                      to
-- IF ((:OLD.type IN ('DMD', 'BLK', 'DXL', 'DSP'))  AND (:OLD.status NOT IN ('NEW', 'PND'))) THEN
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
--
--    10/21/21 bben0556 Brian Bent
--                      R1 cross dock.
--                      Card: R47_0-xdock-OPCOF3725_Site_2_Create_PIK_transaction_for_cross_dock_pallet
--
--                      Add cross_dock_type in call to procedure ""pl_insert_replen_trans".
--
-----------------------------------------------------------------------------
******************************************************************************/

CREATE OR REPLACE TRIGGER SWMS.TRG_DEL_replenlst_ROW
BEFORE DELETE ON swms.replenlst
FOR EACH ROW
DECLARE
	sccs_id		VARCHAR2 (128) := '@(#) src/schema/triggers/trg_del_replenlst_row.sql, swms, swms.9, 10.1.1 9/8/06 1.4';
BEGIN
	IF ((:OLD.type IN ('DMD', 'BLK', 'XDK', 'DXL', 'DSP'))  AND (:OLD.status NOT IN ('NEW', 'PND'))) THEN
		pl_insert_replen_trans
                       (r_prod_id              => :OLD.prod_id,
			r_drop_qty             => :OLD.drop_qty,
			r_uom                  => :OLD.uom,
			r_src_loc              => :OLD.src_loc,
			r_dest_loc             => :OLD.dest_loc,
			r_pallet_id            => :OLD.pallet_id,
			r_user_id              => :OLD.user_id,
			r_order_id             => :OLD.order_id,
			r_route_no             => :OLD.route_no,
			r_cust_pref_vendor     => :OLD.cust_pref_vendor,
			r_batch_no             => :OLD.batch_no,
			r_float_no             => :OLD.float_no,
			r_type                 => :OLD.type,
			r_status               => :OLD.status,
			r_qty                  => :OLD.qty,
			r_task_id              => :OLD.task_id,
			r_door_no              => :OLD.door_no,
			r_exp_date             => :OLD.exp_date,
			r_mfg_date             => :OLD.mfg_date,
			operation              => 'DELETE',
			r_inv_dest_loc         => :OLD.inv_dest_loc,
			r_parent_pallet_id     => :OLD.parent_pallet_id,
			r_labor_batch_no       => :OLD.labor_batch_no,
			i_replen_creation_type => :OLD.replen_type,
			i_cross_dock_type      => :OLD.cross_dock_type);
	END IF;
END;
/

