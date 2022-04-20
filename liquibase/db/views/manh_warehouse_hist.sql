------------------------------------------------------------------------------
-- sccs_id=%Z% %W% %G% %I%
--
-- View:
--    manh_warehouse
--
-- Description:
--    This view is used by Manhattan Slot Info to retrieve picked locations
--    for items that will be used to list movements and hits.
--
-- Used by:
--    Report mi1rb.pc
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    05/01/10 prplhj   D#12581 Initial version
--
------------------------------------------------------------------------------

CREATE OR REPLACE VIEW swmsview.manh_warehouse_hist AS
  SELECT DISTINCT t.prod_id,
         t.location,
         t.loc_uom,
         t.ship_uom,
         w.begin_date, 
         ROUND(w.avg_invs, 2) avg_invs,
         w.ship_movements,
         w.hits
  FROM swmsview.manh_warehouse t,
       swms.weekly_slot_hist w
  WHERE t.prod_id = w.prod_id
  AND   t.ship_uom = DECODE(w.ship_uom, 1, 'E', 'C')
  AND   TO_CHAR(t.pick_date, 'J')
          BETWEEN TO_CHAR(w.begin_date, 'J')
          AND     TO_CHAR(w.begin_date, 'J') + 6
/
COMMENT ON TABLE manh_warehouse_hist IS 'VIEW sccs_id=%Z% %W% %G% %I%';
