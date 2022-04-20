CREATE OR REPLACE TRIGGER SWMS.trg_upd_goaltime_in
--------------------------------------------------------------------
   -- trg_upd_staging_ld.sql
   --
   -- Description:
   --     This script contains a trigger which generates a sequence
   --     for lxli_goaltime_in table
   --
   -- Modification History:
   --    Date      Designer Comments
   --    --------- -------- -------------------------------------------
   --  08-aug-14   pdas8114 Created as part of lxli staging tables
--------------------------------------------------------------------
   BEFORE UPDATE ON LXLI_GOALTIME_IN
   FOR EACH ROW
BEGIN

    :NEW.UPD_DATE :=SYSDATE;
    :NEW.UPD_USER := USER;

END;
/
