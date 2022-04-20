
CREATE OR REPLACE TRIGGER swms.trg_insupd_pm_astmt
------------------------------------------------------------------------------
-- sccs_id=@(#) src/schema/triggers/trg_insupd_pm_astmt.sql, swms, swms.9, 10.1.1 4/22/08 1.1
--
-- Table:
--    PM
--
-- Description:
--    This trigger re-calulates the heights for an item if 
--    PL/SQL table pl_putaway_utilities. has any records.
--    The PL/SQL table is populated by the before update row trigger on
--    the PM table when putaway is by inches, the case height changed
--    and the item has inventory.
--
-- Exceptions raised:
--    -20001  - Oracle error occurred.
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    04/12/05 prpbcb   DN 12373
--                      Project: 491264-Case Height Change
--                      Created.
------------------------------------------------------------------------------
AFTER INSERT OR UPDATE ON pm
DECLARE
   l_index   PLS_INTEGER;
   l_status  NUMBER;
BEGIN

   --
   -- Create another block to trap errors.  We do not want to stop
   -- processing if an error occurs re-calculating the heights.
   --
   BEGIN
      l_index := pl_putaway_utilities.g_r_item_info_for_inches_tbl.FIRST;

      WHILE (l_index <=
             pl_putaway_utilities.g_r_item_info_for_inches_tbl.LAST) LOOP
 
         pl_putaway_utilities.p_update_heights_for_item
            (
 pl_putaway_utilities.g_r_item_info_for_inches_tbl(l_index).prod_id,
 pl_putaway_utilities.g_r_item_info_for_inches_tbl(l_index).cust_pref_vendor,
             l_status);

         --
         -- A failure status will not stop processing.
         -- 
         IF (l_status <> 0) THEN
            pl_log.ins_msg('WARN', 'trg_insupd_pm_astmt',
            'l_status ' || TO_CHAR(l_status) || ' not successful status.'
            || '   Will continue processing.', NULL, NULL,
            'MAINTENANCE', 'trg_insupd_pm_astmt');
         END IF;

         l_index :=
            pl_putaway_utilities.g_r_item_info_for_inches_tbl.NEXT(l_index);
      END LOOP;
   EXCEPTION
      WHEN OTHERS THEN
            pl_log.ins_msg('WARN', 'trg_insupd_pm_astmt',
               'Error re-calculating heights.  This does not stop processing',
               SQLCODE, SQLERRM, 'MAINTENANCE', 'trg_insupd_pm_astmt');
   END;

   --
   -- Remove all the items in the PL/SQL table.  We do not want to keep
   -- them around.
   --
  pl_putaway_utilities.g_r_item_info_for_inches_tbl.DELETE;

EXCEPTION
   WHEN OTHERS THEN
      pl_log.ins_msg('WARN', 'trg_insupd_pm_astmt',
           'Final WHEN-OTHERS catch all error re-calculating heights.',
           SQLCODE, SQLERRM, 'MAINTENANCE', 'trg_insupd_pm_astmt');
      RAISE_APPLICATION_ERROR(-20001, 'trg_insupd_pm_astmt'
          || ': '|| SQLERRM);
END trg_insupd_pm_astmt; 
/

