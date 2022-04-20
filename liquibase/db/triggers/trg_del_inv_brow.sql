/*------------------------------------------------------------------------------
-- sccs_id=@(#) src/schema/triggers/trg_del_inv_brow.sql, swms, swms.9, 10.2 5/20/09 1.4
--
-- Table:
--    INV
--
-- Description:
--    This trigger inserts the INV record into the INV_HIST before
--    it is deleted.
--
-- Exceptions raised:
--    None.  If an error occurs a message in inserted log message
--           is created and processing continues.
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    04/30/09 prpbcb   DN 12500
--                      Project:
--                   CRQ9069-QTY Received not sent to SUS for SN pallet split
--                      Added dmg_ind and inv_uom.
--    07/15/19 pkab6563 Jira 2457 - added new columns: 
--                      - qty_produced 
--                      - sigma_qty_produced 
--                      - ship_date
-- 
------------------------------------------------------------------------------*/

CREATE OR REPLACE TRIGGER swms.trg_del_inv_brow
BEFORE DELETE ON swms.inv
FOR EACH ROW
BEGIN
   INSERT INTO inv_hist
               (
                prod_id,
                rec_id,
                mfg_date,
                rec_date,
                exp_date,
                inv_date,
                logi_loc,
                plogi_loc,
                qoh,
                qty_alloc,
                qty_planned,
                min_qty,
                cube,
                lst_cycle_date,
                lst_cycle_reason,
                abc,
                abc_gen_date,
                status,
                lot_id,
                weight,
                temperature,
                exp_ind,
                cust_pref_vendor,
                case_type_tmu,
                pallet_height,
                parent_pallet_id,
                dmg_ind,
                inv_uom,
                inv_add_user,
                inv_add_date,
                inv_cust_id,
                inv_order_id,
                qty_produced,
                sigma_qty_produced,
                ship_date
               )
         VALUES
              (
               :OLD.prod_id,
               :OLD.rec_id,
               :OLD.mfg_date,
               :OLD.rec_date,
               :OLD.exp_date,
               :OLD.inv_date,
               :OLD.logi_loc,
               :OLD.plogi_loc,
               :OLD.qoh,
               :OLD.qty_alloc,
               :OLD.qty_planned,
               :OLD.min_qty,
               :OLD.cube,
               :OLD.lst_cycle_date,
               :OLD.lst_cycle_reason,
               :OLD.abc,
               :OLD.abc_gen_date,
               :OLD.status,
               :OLD.lot_id,
               :OLD.weight,
               :OLD.temperature,
               :OLD.exp_ind,
               :OLD.cust_pref_vendor,
               :OLD.case_type_tmu,
               :OLD.pallet_height,
               :OLD.parent_pallet_id,
               :OLD.dmg_ind,
               :OLD.inv_uom,
               :OLD.add_user,
               NVL(:OLD.add_date, TRUNC (SYSDATE)),
               :OLD.inv_cust_id,
               :OLD.inv_order_id,
               :OLD.qty_produced,
               :OLD.sigma_qty_produced,
               :OLD.ship_date
              );
END;
/

