
CREATE OR REPLACE TRIGGER swms.trg_insupd_cc
------------------------------------------------------------------------------
-- sccs_id=@(#) src/schema/triggers/trg_insupd_cc.sql, swms, swms.9, 10.1.1 10/29/07 1.1
--
-- Table:
--    CC
--
-- Description:
--    Perform necessary actions when a CC record is inserted
--    or updated.
--
-- Exceptions raised:
--    -20001  - Oracle error occurred.
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    09/17/07 prpbcb   DN 12280
--                      Ticket: 458478
--                      Project: 458478-Miniload Fixes
--                      Created to assign the update user and update date.
------------------------------------------------------------------------------
BEFORE INSERT OR UPDATE ON swms.cc
FOR EACH ROW
DECLARE
   l_object_name        VARCHAR2(30) := 'trg_insupd_cc';
BEGIN
   IF UPDATING THEN
      :new.upd_user := REPLACE(USER, 'OPS$');
      :new.upd_date := SYSDATE;
   END IF;

EXCEPTION
   WHEN OTHERS THEN
      RAISE_APPLICATION_ERROR(-20001, l_object_name || ': '|| SQLERRM);

END trg_insupd_cc;
/

