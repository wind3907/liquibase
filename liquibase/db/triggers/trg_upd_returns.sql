CREATE OR REPLACE TRIGGER TRG_UPD_RETURNS_BROW
------------------------------------------------------------------------------
-- sccs_id=@(#) src/schema/triggers/trg_upd_returns.sql, swms, swms.9, 11.1 9/28/09 1.1
--
-- Trigger Name: trg_upd_returns
-- Table:
--    RETURNS
--
-- Description:
--    This trigger logs the RETURNS table update operations to somewhere and
--    update the upd_date and upd_user columns.
--
-- Exceptions raised:
--    None
--
-- Modification History:
--    Date       Designer Comments
--    --------   -------- ---------------------------------------------------
--    09/21/2009 prplhj   D#12521 Initial version.
--    08/31/2020 kna8378  Update new columns in RETURNS and delete redundant insert statements
------------------------------------------------------------------------------
BEFORE UPDATE ON swms.returns
FOR EACH ROW
DECLARE
  sAction	VARCHAR2(30) := 'UPDATE';
  sObject	VARCHAR2(30) := 'TRG_UPD_RETURNS_BROW';
BEGIN
  :new.upd_date := SYSDATE;
  :new.upd_user := REPLACE(USER, 'OPS$', '');

  pl_log.ins_msg('D', sObject,
    sAction || ': MANIFEST[' || TO_CHAR(:old.manifest_no) || '/' ||
    TO_CHAR(:new.manifest_no) || '] ROUTE[' || :new.route_no || '] STOP[' ||
    TO_CHAR(:new.stop_no) || '] ERM_LINE_ID[' ||
    TO_CHAR(:old.erm_line_id) || '/' || TO_CHAR(:new.erm_line_id) ||
    '] REC_TYPE[' || :new.rec_type || '] OBLIGATION[' || :old.obligation_no || '/' ||
    :new.obligation_no || '] PROD_ID[' || :old.prod_id || '/' ||
    :new.prod_id || '] REASON_CD[' || :old.return_reason_cd || '/' ||
    :new.return_reason_cd || '] RETURN_QTY[' ||
    TO_CHAR(:old.returned_qty) || '/' || TO_CHAR(:new.returned_qty) ||
    '] RETURN_UOM[' || :old.returned_split_cd || '/' ||  :new.returned_split_cd ||
    '] RETURNED_PROD_ID[' || :old.returned_prod_id || '/' || :new.returned_prod_id ||
    '] CATCHWEIGHT[' || TO_CHAR(:old.catchweight) || '/' || TO_CHAR(:new.catchweight) || 
    '] STATUS[' || :old.status || '/' || :new.status ||
    '] RTN_SENT_IND[' || :old.rtn_sent_ind || '/' || :new.rtn_sent_ind || '] POD_RTN_IND[' ||
    :old.pod_rtn_ind || '/' || :new.pod_rtn_ind || ']  LOCK_CHG[' ||
    :old.lock_chg || '/' || :new.lock_chg || '] TEMPERATURE[' ||
    TO_CHAR(:old.temperature) || '/' || TO_CHAR(:new.temperature) || '] BARCODE_REF_NO['  ||
    :old.barcode_ref_no || '/' || :new.barcode_ref_no || ']' ,
    NULL, NULL);

EXCEPTION
  WHEN OTHERS THEN
    NULL;  
END trg_upd_returns_brow;
/

