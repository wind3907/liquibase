CREATE OR REPLACE TRIGGER swms.trg_insdel_usr_arow
------------------------------------------------------------------------------
-- @(#) src/schema/triggers/trg_insdel_usr_arow.sql, swms, swms.9, 10.1.1 5/20/08 1.3
--
-- @(#) File :  trg_insdel_usr_arow.sql
-- @(#) Usage: sqlplus USR/PWD  trg_insdel_usr_arow.sql
-- Description:
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    10/21/05 prpakp Initial Creation.
--
--    05/20/08 prpbcb   DN 12388
--                      Project: 607473-SWMS User Removed But Still a SOS User
--                      Created.
--                      Log deleting a user
------------------------------------------------------------------------------
AFTER INSERT OR DELETE ON swms.usr FOR EACH ROW
BEGIN
   IF INSERTING THEN
      insert into wis_usr (type, user_id)
      values ('U', replace(:new.user_id, 'OPS$', ''));
   ELSIF DELETING THEN
      delete wis_usr
       where type = 'U'
         and 'OPS$' || user_id = :old.user_id;

      --
      -- Log the delete of the user.
      --
      -- Set global package variables used in the audit.
      pl_audit.g_application_func := 'M';  -- Maintenance
      pl_audit.g_screen_type := NULL;
      pl_audit.g_program_name := 'trg_insdel_usr_arow';

      pl_audit.ins_trail('User ' || :OLD.user_id || ' deleted from'
                         || ' USR table.', NULL);
   END IF;
EXCEPTION
   WHEN OTHERS THEN
      RAISE_APPLICATION_ERROR(-20001, 'trg_insdel_usr_arow: ' || SQLERRM);
END trg_insdel_usr_arow;
/

