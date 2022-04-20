CREATE OR REPLACE TRIGGER swms.trg_insupddel_usr_brow
------------------------------------------------------------------------------
-- @(#) src/schema/triggers/trg_insupddel_usr_brow.sql, swms, swms.9, 10.1.1 5/20/08 1.1
--
-- Table:
--    USR
--
-- Description:
--    This trigger performs the necessary actions when a USR record is
--    inserted, updated or deleted.
--
--    On DELETE
--       -  Check if it OK to delete the user.  A procedure is called to
--          do the check.
--
-- Exceptions raised:
--    -20001  - Oracle error occurred.
--    -20002  - It is not OK to delete the user from USR table.
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    05/20/08 prpbcb   DN 12388
--                      Project: 607473-SWMS User Removed But Still a SOS User
--                      Created.
--
------------------------------------------------------------------------------
BEFORE INSERT OR UPDATE OR DELETE ON swms.usr
FOR EACH ROW
DECLARE
   l_msg                    VARCHAR2(200); -- Work area
   l_ok_to_delete_user_bln  BOOLEAN;       -- Flag if OK to delete the user.
   e_not_ok_to_delete_user  EXCEPTION;
BEGIN
   IF DELETING THEN
      --
      -- See if it is OK to delete the user.
      --
      pl_common.safe_to_delete_user(:OLD.user_id,
                                    l_ok_to_delete_user_bln,
                                    l_msg);

      IF (l_ok_to_delete_user_bln = FALSE) THEN
         RAISE e_not_ok_to_delete_user;
      END IF;
   END IF;  -- end if deleting
EXCEPTION
   WHEN e_not_ok_to_delete_user THEN
      --
      -- It is not OK to delete the user.  l_msg has why.
      --
      RAISE_APPLICATION_ERROR(-20002, 'trg_insupddel_usr_brow: ' || l_msg);
   WHEN OTHERS THEN
      RAISE_APPLICATION_ERROR(-20001, 'trg_insupddel_usr_brow: '|| SQLERRM);
END trg_insupddel_usr_brow;
/

