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

CREATE OR REPLACE VIEW swmsview.manh_warehouse AS
  SELECT DISTINCT t.prod_id,
         l.logi_loc location,
         DECODE(l.uom,
                1, 'E',
                2, 'C',
                DECODE(t.uom, 1, 'E', 'C')) loc_uom,
         DECODE(t.uom, 1, 'E', 'C') ship_uom,
         TRUNC(t.trans_date) pick_date
  FROM swms.loc l,
       swms.zone z,
       swms.lzone lz,
       swms.v_trans t
  WHERE l.logi_loc = lz.logi_loc
  AND   z.zone_id = lz.zone_id
  AND   z.zone_type = 'PUT'
  AND   l.perm = 'Y'
  AND   t.trans_type = 'PIK'
  AND   t.src_loc = l.logi_loc
/
COMMENT ON TABLE manh_warehouse IS 'VIEW sccs_id=%Z% %W% %G% %I%';
