CREATE OR REPLACE TRIGGER swms.trg_insupddel_sos_usr_arow
------------------------------------------------------------------------------
-- @(#) src/schema/triggers/trg_insupddel_sos_usr_arow.sql, swms, swms.9, 10.1.1 5/20/08 1.1
--
-- Table:
--    SOS_USR_CONFIG
--
-- Description:
--    This after trigger performs the necessary actions when a
--    SOS_USR_CONFIG record is inserted, updated or deleted.
--
--    After DELETE
--       -  Log the delete.
--
-- Exceptions raised:
--    -20001  - Oracle error occurred.
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    05/20/08 prpbcb   DN 12388
--                      Project: 607473-SWMS User Removed But Still a SOS User
--                      Created.
--                      Log when a SOS user is deleted.
--
------------------------------------------------------------------------------
AFTER INSERT OR UPDATE OR DELETE ON swms.sos_usr_config
FOR EACH ROW
DECLARE
BEGIN
   IF DELETING THEN
      --
      -- Log the delete of the user.
      --
      -- Set global package variables used in the audit.
      pl_audit.g_application_func := 'M';  -- Maintenance
      pl_audit.g_program_name := 'trg_insupddel_sos_usr_arow';

      pl_audit.ins_trail('User ' || :OLD.user_id || ' deleted from'
                   || ' SOS configuration.  Table SOS_USR_CONFIG.', NULL);
   END IF;  -- end if deleting
EXCEPTION
   WHEN OTHERS THEN
      RAISE_APPLICATION_ERROR(-20001, 'trg_insupddel_sos_usr_arow: '|| SQLERRM);
END trg_insupddel_sos_usr_arow;
/

