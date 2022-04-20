CREATE OR REPLACE TRIGGER swms.trg_upd_ordcw_brow
BEFORE UPDATE ON swms.ordcw
FOR EACH ROW
------------------------------------------------------------------------------
-- sccs_id=%Z% %W% %G% %I%
--
-- Table:
--    ORDCW
--
-- Description:
--    This trigger performs task when the ORDCW table is updated.
--
-- Exceptions raised:
--    None
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    06/27/11 prjxl000 CR23613/PBI3112 Initial version.
--
------------------------------------------------------------------------------
BEGIN
  IF UPDATING THEN
    :new.upd_date := SYSDATE;
    :new.upd_user := REPLACE(USER, 'OPS$', '');
    pl_nos.insert_slt_action_log('TRK_ORDCW_UPD',
     'Order[' || :new.order_id || '/' || TO_CHAR(:new.order_line_id) || '] ' ||
     'seq o/n[' || TO_CHAR(:old.seq_no) || '/' || TO_CHAR(:new.seq_no) ||
     '] item[' || :old.prod_id || ',' || :old.cust_pref_vendor || '/' ||
     :new.prod_id || ',' || :new.cust_pref_vendor || '] ' ||
     'type[' || :old.cw_type || '/' || :new.cw_type || '] u[' ||
     TO_CHAR(:old.uom) || '/' || TO_CHAR(:new.uom) || '] wt[' ||
     TO_CHAR(:old.catch_weight) || '/' || TO_CHAR(:new.catch_weight) || '] ' ||
     'ins date[' || TO_CHAR(:new.add_date, 'MM/DD/RR HH24:MI:SS') || '] ' ||
     'ins user[' || REPLACE(:new.add_user, 'OPS$', '') || '] ' ||
     'upd date[' || TO_CHAR(:old.upd_date, 'MM/DD/RR HH24:MI:SS') || ',' ||
     TO_CHAR(:new.upd_date, 'MM/DD/RR HH24:MI:SS') || '] upd user[' ||
     :old.upd_user || '/' || :new.upd_user || ']');
  END IF;
EXCEPTION
  WHEN OTHERS THEN
    NULL;
END;
/

