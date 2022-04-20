CREATE OR REPLACE TRIGGER trg_upd_inv_cmpnd
-- /******************************************************************************
--   (#) TRG_INS_replenlst_ROW.sql
--   sccs_id=@(#) src/schema/triggers/trg_ins_inv_brow.sql, swms, swms.9, 10.1.1 11/8/06 1.3
-- ******************************************************************************/
--
-- Table:
--    INV(Inventory table)
--
-- Description:
--    This trigger populates the inv.inv_uom if it is null.
--    One occurance was found where this column was not populated
--    by the calling program and hence got the default value of 0.
--    This can cause unexpected behavior of the software due to 
--    all the complications associated with the miniload processing
--    This trigger would try to catch this error before it gets
--    propagated to all other parts of the application.
--
-- Exceptions raised:
--    -20001  - Oracle error occurred.
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    04/20/06 prpnxk   Initial Version
--    08/15/06 prpakp   Removed the when clause since the default is 0 
--                      for inv_uom.
--    11/08/06 prpakp   Added check for inv_uom.
-----------------------------------------------------------------------------
	FOR UPDATE OF qoh ON inv COMPOUND TRIGGER
		l_index			NUMBER		:= 0;
		l_received_items	BOOLEAN		:= FALSE;
		l_prod_id_array	t_prod_ids	:= t_prod_ids();
		BEFORE EACH ROW IS
			BEGIN
				IF pl_common.f_get_syspar('ENABLE_RPT_ORDER_STATUS_OUT', 'N') = 'Y' AND :OLD.qoh = 0 AND :NEW.qoh > 0 THEN
					l_received_items := TRUE;
					l_prod_id_array.EXTEND;
					l_index := l_index + 1;
					l_prod_id_array(l_index) := :NEW.prod_id;
				END IF;
		END BEFORE EACH ROW;
		AFTER STATEMENT IS
			BEGIN
				IF pl_common.f_get_syspar('ENABLE_RPT_ORDER_STATUS_OUT', 'N') = 'Y' AND l_received_items THEN
					pl_cmu_inv_stgng_rpt.qoh_into_stgng_tbl(l_prod_id_array);
				END IF;
		END AFTER STATEMENT;
END trg_upd_inv_cmpnd;
/
