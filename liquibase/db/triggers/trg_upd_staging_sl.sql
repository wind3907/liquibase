CREATE OR REPLACE TRIGGER trg_upd_staging_sl
--------------------------------------------------------------------
   -- trg_upd_staging_sl.sql
   --
   -- Description:
   --     This script contains a trigger which generates a sequence
   --     for lxli_staging_sl_out table
   --
   -- Modification History:
   --    Date      Designer Comments
   --    --------- -------- -------------------------------------------
   --  08-aug-14   pdas8114 Created as part of lxli staging tables
--------------------------------------------------------------------
   BEFORE UPDATE ON lxli_staging_sl_out
   FOR EACH ROW
BEGIN

    :NEW.UPD_DATE :=SYSDATE;
    :NEW.UPD_USER := USER;

END;
/
