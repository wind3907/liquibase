  CREATE OR REPLACE TRIGGER "SWMS"."TRG_UPD_MQ_MAINT" 
   BEFORE UPDATE ON MQ_INTERFACE_MAINT
   FOR EACH ROW
--------------------------------------------------------------------
   -- trg_upd_mq_maint.sql
   --
   -- Description:
   --     This script contains a trigger which generates upd date and
   --     upd user details.
   --
   -- Modification History:
   --    Date      Designer              Comments
   --    --------- --------------------- -------------------------------------------
   --    1-AUG-18  mcha1213         Initial Creation
--------------------------------------------------------------------
BEGIN
   IF UPDATING
   THEN
   SELECT SYSDATE, USER
        INTO :NEW.UPD_DATE, :NEW.UPD_USER
        FROM DUAL;
   END IF;
END;
/

ALTER TRIGGER "SWMS"."TRG_UPD_MQ_MAINT" ENABLE;
/