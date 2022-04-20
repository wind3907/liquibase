------------------------------------------------------------------------------
-- sccs_id=@(#) src/schema/views/v_mh2ra.sql, swms, swms.9, 10.1.1 9/7/06 1.3
--
-- View:
--    v_mh2ra
--
-- Description:
--    This view is used in the mh2ra.sql and mh2rb.sql reports.  These reports
--    list the case and split dimension fields for the items.  A view was used
--    so that the home locations for the items can be printed on the report.
--    Function pl_common.f_get_first_pick_slot is called to get the
--    minimum location in inventory for floating items.
--
--   NOTE:  On oracle 7.2 a stand alone function name f_get_first_pick_slot
--          was created as putting it in package pl_common (or any package)
--          prevented it from being called from a select statement.
--          So the view between oracle 7.2 and 8i is slightly different.
--
-- Used by:
--    Report mh2ra.sql
--    Report mh2rb.sql
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    10/01/02 prpbcb   rs239a DN  11043  rs239b DN 11074  Created.  
--                      RDC non-dependent changes.
------------------------------------------------------------------------------

PROMPT Create view v_mh2ra

-- The pick_loc can be a home slot or the first floating slot for a floating
-- item.

CREATE OR REPLACE VIEW swms.v_mh2ra
AS
SELECT p.prod_id,
       p.cust_pref_vendor,
       p.descrip,
       p.case_height,
       p.case_length,
       p.case_width,
       p.split_height,
       p.split_length,
       p.split_width,
       NVL(l.logi_loc,
           pl_common.f_get_first_pick_slot(p.prod_id,
                                           p.cust_pref_vendor)) pick_loc,
       l.rank,
       l.uom
  FROM loc l, pm p
 WHERE l.prod_id (+)           = p.prod_id
   AND l.cust_pref_vendor (+)  = p.cust_pref_vendor
/

