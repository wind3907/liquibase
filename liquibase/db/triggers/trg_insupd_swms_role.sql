
CREATE OR REPLACE TRIGGER swms.trg_insupd_swms_role
------------------------------------------------------------------------------
-- sccs_id=@(#) src/schema/triggers/trg_insupd_swms_role.sql, swms, swms.9, 10.1.1 11/2/07 1.1
--
-- Table:
--    SWMS_ROLE
--
-- Description:
--    Perform necessary actions when a SWMS_ROLE record is inserted
--    or updated.
--
-- Exceptions raised:
--    -20001  - Oracle error occurred.
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    10/24/07 prpbcb   DN 12297
--                      Ticket: 484515
--                      Project: 484515-Menu Access Security

------------------------------------------------------------------------------
BEFORE INSERT OR UPDATE ON swms.swms_role
FOR EACH ROW
DECLARE
   l_object_name        VARCHAR2(30) := 'trg_insupd_swms_role';
BEGIN
   IF UPDATING THEN
      :new.upd_user := REPLACE(USER, 'OPS$');
      :new.upd_date := SYSDATE;
   END IF;

EXCEPTION
   WHEN OTHERS THEN
      RAISE_APPLICATION_ERROR(-20001, l_object_name || ': '|| SQLERRM);

END trg_insupd_swms_role;
/

