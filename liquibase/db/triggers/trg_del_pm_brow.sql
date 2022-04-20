CREATE OR REPLACE TRIGGER swms.trg_del_pm_brow
------------------------------------------------------------------------------
-- @(#) src/schema/triggers/trg_del_pm_brow.sql, swms, swms.9, 11.2 3/10/10 1.4
--
-- Table:
--    PM
--
-- Description:
--    This trigger deletes PM_UPC table records for the matching prod_id in PM
--    table that is being deleted.
--
-- Exceptions raised:
--    -20001  - Oracle error occurred.
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    11/01/04 prplhj   D#11xxx Initial version.
--    10/25/08 prpbcb   DN 12434
--                      Project:
--                   CRQ000000001006-Embed meaningful messages in miniload
--
--                     Delete item from COOL_ITEM table.
--    03/11/10 prplhj   DN 12562. CR15207. Delete also from PM_UPC, COOL_ITEM
--			and COOL_ITEM_MASTER tables if not already.
------------------------------------------------------------------------------
BEFORE DELETE ON swms.pm
FOR EACH ROW
DECLARE
   szObjectName  VARCHAR2(30) := 'trg_del_pm_brow';
BEGIN
pl_mx_swms_to_pm_out.pm_insert_del := 'Y';
   DELETE pm_upc
    WHERE prod_id = :old.prod_id
      AND cust_pref_vendor = :old.cust_pref_vendor;

   --
   -- Delete the item from the cool item table.
   --
   DELETE FROM cool_item
    WHERE prod_id          = :old.prod_id
      AND cust_pref_vendor = :old.cust_pref_vendor;

   --
   -- Delete the item from the cool item table.
   --
   DELETE FROM cool_item_master
    WHERE prod_id          = :old.prod_id
      AND cust_pref_vendor = :old.cust_pref_vendor;

pl_mx_swms_to_pm_out.pm_insert_del := 'N';

EXCEPTION
  WHEN OTHERS THEN
    pl_mx_swms_to_pm_out.pm_insert_del := 'N';
    RAISE_APPLICATION_ERROR(-20001, szObjectName || ': '|| SQLERRM);
END trg_del_pm_brow;
/

