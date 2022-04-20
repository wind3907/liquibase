------------------------------------------------------------------------------
-- sccs_id=@(#) src/schema/views/v_whmove_newloc.sql, swms, swms.9, 10.1.1 7/31/08 1.1
--
-- View:
--    v_whmove_newloc
--
-- Description:
--     This is a view of the SWMS.LOC table and the swms
--     WHMVELOC_AREA_XREF table showing the temporary new warehouse
--     location and the new warehouse location.
--
--     This view was created to use in form mw1sc in the record groups
--     and for validation.  It is also used in other warehouse move forms.
--
--    Example of what this view will show:
--       Table WHMVELOC_AREA_XREF has this record:
--          Column                      Value
--          -------------------------   -----
--          TMP_NEW_WH_AREA               Z
--          ORIG_OLD_WH_AREA              F
--          PUTBACK_WH_AREA               F
--          TMP_FR_OLD_TO_NEW_PASS        0
--          TMP_FR_OLD_TO_NEW_FAIL        M
--
--       The LOC table has these locations:
--           logi_loc   perm rank uom slot_type pallet_type status prod_id cpv
--           ---------- ---- ---- --- --------- ----------- ------ ------- ---
--           ZA11A1     Y    1    0   LWC       LW          AVL    1234567 -
--           ZA11A2     N             LWC       LW          AVL
--
--       This view will show:
--     tmp_new newloc   perm rank uom slot_type pallet_type status prod_id cpv
--     ------- -------  ---- ---- --- --------- ----------- ------ ------- ---
--     ZA11A1  FA11A1   Y    1    0   LWC       LW          AVL    1234567 -
--     ZA11A2  FA11A2   N             LWC       LW          AVL
--
--
--
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    07/25/08 prpbcb   DN: 12401
--                      Project: 562935-Warehouse Move MiniLoad Enhancement
--                      Created.
------------------------------------------------------------------------------

CREATE OR REPLACE VIEW swms.v_whmove_newloc
AS
SELECT l.logi_loc                                     tmp_logi_loc,
       xref.putback_wh_area || SUBSTR(l.logi_loc, 2)  logi_loc,
       l.perm                                         perm,
       l.rank                                         rank,
       l.uom                                          uom,
       l.slot_type                                    slot_type,
       l.pallet_type                                  pallet_type,
       l.aisle_side                                   aisle_side,
       l.status                                       status,
       l.cube                                         cube,
       l.prod_id                                      prod_id,
       l.cust_pref_vendor                             cust_pref_vendor
  FROM whmveloc_area_xref xref,
       loc l
 WHERE l.logi_loc LIKE xref.tmp_new_wh_area || '%' 
/


--
-- Create public synonym.
--
CREATE OR REPLACE PUBLIC SYNONYM v_whmove_newloc
   FOR swms.v_whmove_newloc
/

