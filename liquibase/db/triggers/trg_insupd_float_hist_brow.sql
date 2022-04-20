CREATE OR REPLACE TRIGGER swms.trg_insupd_float_hist_brow
------------------------------------------------------------------------------
-- sccs_id=@(#) src/schema/triggers/trg_insupd_float_hist_brow.sql, swms, swms.9, 10.1.1 12/19/07 1.4
--
-- Table:
--    FLOAT_HIST
--
-- Description:
--    This trigger does the following:
--       - Strips OPS$ from the user_id on insert and update.
--
-- Exceptions raised:
--    -20001  - Oracle error occurred.
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    01/27/04 prpbcb   Oracle 8 rs239b swms9 DN 11899
--                      Test Director: TD5688
--                      Ticket: HD15006
--                      Created.
--                      Strip OPS$ from the user_id column if the user_id
--                      is not null.  Function lmc_insert_into_float_hist
--                      in lm_common.pc inserts a record into FLOAT_HIST when
--                      a bulk pull is being processed.  Initially the insert
--                      statement had an incorrect join condition that resulted
--                      in no record being inserted (it was like this since
--                      day one of forklift labor mgmt).  This was fixed but
--                      then a problem arose with the user id because the
--                      insert statement is using USER so the user id will be
--                      10 characters but float_hist.user_id is varchar2(8)
--                      so the insert failed.  To assure the OPS$ is removed
--                      from the user id this trigger was created.
--                      We do not want to rely on the application to remove
--                      the OPS$.
--
--                      We do not want OPS$ as part of the user_id in
--                      FLOAT_HIST.
--
--    12/17/07 prpbcb   DN 12322  (Jandy's defect)
--                      Project:
--                      Added setting upd_date and upd user on update.
------------------------------------------------------------------------------
BEFORE INSERT OR UPDATE ON swms.float_hist
FOR EACH ROW
DECLARE
BEGIN
   IF INSERTING OR UPDATING THEN
      IF (:new.user_id IS NOT NULL) THEN
         :new.user_id := REPLACE(:new.user_id, 'OPS$');
      END IF;

      IF UPDATING THEN
         :new.upd_user := REPLACE(USER, 'OPS$');
         :new.upd_date := SYSDATE;
      END IF;
   END IF;

EXCEPTION
   WHEN OTHERS THEN
      RAISE_APPLICATION_ERROR(-20001, 'trg_insupd_float_hist_brow' || ': '|| SQLERRM);
END trg_insupd_float_hist_brow;
/

