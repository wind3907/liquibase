
CREATE OR REPLACE TRIGGER swms.trg_insupd_sos_batch_brow
------------------------------------------------------------------------------
-- sccs_id=@(#) src/schema/triggers/trg_insupd_sos_batch_brow.sql, swms, swms.9, 10.1.1 12/19/07 1.1
--
-- Table:
--    SOS_BATCH
--
-- Description:
--    This trigger performs necessary actions when a SOS_BATCH record is
--    inserted or updated.  These actions are:
--       1.  On update, setting the upd_date and upd_user.
--
-- Exceptions raised:
--    -20001  - Oracle error occurred.
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    12/17/07 prpbcb   DN 12322  (Jandy's defect)
--                      Project:
--                      Created.
------------------------------------------------------------------------------
BEFORE INSERT OR UPDATE ON swms.sos_batch
FOR EACH ROW
BEGIN
   IF UPDATING THEN
      :new.upd_user := REPLACE(USER, 'OPS$');
      :new.upd_date := SYSDATE;
   END IF;

EXCEPTION
   WHEN OTHERS THEN
      RAISE_APPLICATION_ERROR(-20001, 'trg_insupd_sos_batch' || ': '|| SQLERRM);

END trg_insupd_sos_batch_brow;
/

