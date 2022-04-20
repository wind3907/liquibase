------------------------------------------------------------------------------
-- sccs_id=@(#) src/schema/views/v_whmove_valid_ml_ind_loc_item.sql, swms, swms.9, 10.1.1 7/25/08 1.1
--
-- View:
--    v_whmove_valid_ml_ind_loc_item
--
-- Description:
--     View of the valid induction locations for an item based on the
--     warehouse move setup.
--     It is based on the miniload PUT zone so the PUT zone needs to
--     be completely setup which includes:
--        - ZONE.RULE_ID set to 3
--        - ZONE.Z_AREA_CODE is entered
--        - ZONE.Z_SUB_AREA_CODE is entered
--        - ZONE.Z_INDUCTION_LOC is entered
--
--     The ZONE.INDUCTION_LOC needs to exist in the LOC table.
--
--     This view was created to use in form mw1sd which is the form where
--     items to move to the miniloader are entered for a warehouse move.
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    07/17/08 prpbcb   DN: 12401
--                      Project: 562935-Warehouse Move MiniLoad Enhancement
--                      Created.
------------------------------------------------------------------------------

CREATE OR REPLACE VIEW swms.v_whmove_valid_ml_ind_loc_item
AS
SELECT pm.prod_id             prod_id,
       pm.cust_pref_vendor    cust_pref_vendor,
       pm.area                area,
       xref.putback_wh_area || SUBSTR(zone.induction_loc, 2)  induction_loc,
       zone.induction_loc     tmp_induction_loc -- Temporary induction loc
                                        -- Put in view just as a reference
  FROM swms.zone zone,
       swms.whmveloc_area_xref xref,  -- For tying the item area to the
                                      -- temporary new warehouse area
       swms.pm pm,
       swms.loc loc -- To check that the induction loc
                                       -- is in the LOC table.
 WHERE zone.rule_id          = 3     -- rule id 3 is a miniload PUT zone
   AND loc.logi_loc          = zone.induction_loc
   AND xref.tmp_new_wh_area  = SUBSTR(zone.induction_loc, 1, 1)
   AND pm.area               = xref.orig_old_wh_area
/

--
-- Create public synonym.
--
CREATE OR REPLACE PUBLIC SYNONYM v_whmove_valid_ml_ind_loc_item
   FOR swms.v_whmove_valid_ml_ind_loc_item
/

