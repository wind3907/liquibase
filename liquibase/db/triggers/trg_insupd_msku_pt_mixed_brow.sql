CREATE OR REPLACE TRIGGER swms.trg_insupd_msku_pt_mixed_brow
------------------------------------------------------------------------------
-- sccs_id=@(#) src/schema/triggers/trg_insupd_msku_pt_mixed_brow.sql, swms, swms.9, 10.1.1 9/8/06 1.3
--
-- Table:
--    msku_pallet_type_mixed
--
-- Description:
--    This trigger does the following:
--       - Assigns the upd_user and upd_date when a record is updated.
--
-- Exceptions raised:
--    -20001  - Oracle error occurred.
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    12/06/04 prpbcb   Oracle 7 rs239a DN None 
--                      Oracle 8 rs239b swms8 DN None
--                      Oracle 8 rs239b swms9 DN 11838
--                      Created.
--                      At this time nothing is done on insert.
------------------------------------------------------------------------------
BEFORE INSERT OR UPDATE ON swms.msku_pallet_type_mixed
FOR EACH ROW
DECLARE
   l_object_name        VARCHAR2(30) := 'trg_insupd_msku_pt_mixed_brow';
BEGIN
   IF UPDATING THEN
      :new.upd_user := REPLACE(USER, 'OPS$');
      :new.upd_date := SYSDATE;
   END IF;
EXCEPTION
   WHEN OTHERS THEN
      RAISE_APPLICATION_ERROR(-20001, l_object_name || ': '|| SQLERRM);

END trg_insupd_msku_pt_mixed_brow;
/

