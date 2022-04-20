CREATE OR REPLACE TRIGGER "SWMS"."TRG_INS_PM_AROW" AFTER
INSERT ON SWMS.PM FOR EACH ROW
------------------------------------------------------------------------------
-- @(#) src/schema/triggers/trg_ins_pm_arow.sql, swms, swms.9, 10.1.1 9/8/06 1.2
--
-- Table:
--    PM
--
-- Description:
--    This trigger creates a PM_UPC record for the matching prod_id in PM
--    table that is being inserted.
--
-- Exceptions raised:
--    -20001  - Oracle error occurred.
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    12/01/05 prpswp   D#11xxx Initial version.
--
------------------------------------------------------------------------------
BEGIN

pl_mx_swms_to_pm_out.pm_insert_del := 'Y';

  INSERT INTO PM_UPC (PROD_ID, CUST_PREF_VENDOR, VENDOR_ID,
    INTERNAL_UPC, EXTERNAL_UPC)
  VALUES (:NEW.PROD_ID, :NEW.CUST_PREF_VENDOR, :NEW.VENDOR_ID,
    :NEW.INTERNAL_UPC, :NEW.EXTERNAL_UPC);

pl_mx_swms_to_pm_out.pm_insert_del := 'N';
EXCEPTION
  WHEN OTHERS THEN
  pl_mx_swms_to_pm_out.pm_insert_del := 'N';
    NULL;
END;
/

