------------------------------------------------------------------------------
-- sccs_id=%Z% %W% %G% %I%
--
-- View:
--    v_ord_cool
--
-- Description:
--    This view is used to retrieve distinct COOL data information during
--    order processing.
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    02/18/05 prplhj   D#11870 Initial version.
--    04/01/10 sth0458  DN12554 - 212 Enh - SCE057 - 
--                      Add UOM field to SWMS.Expanded the length
--                      of prod size to accomodate for prod size
--                      unit.Changed queries to fetch
--                      prod_size_unit along with prod_size
--
------------------------------------------------------------------------------

PROMPT Create view v_ord_cool

CREATE OR REPLACE VIEW swms.v_ord_cool AS
    SELECT
       d.seq, m.cust_id, m.route_no, m.stop_no, m.truck_no,
       m.order_id, d.order_line_id, d.prod_id, d.cust_pref_vendor,
       d.qty_ordered, d.uom,
	   /* 04/01/10 - 12554 - sth0458 - Added for 212 Enh - SCE057 - Begin */
	   /*  Declare prod size unit */
       p.descrip, p.brand, p.mfg_sku, p.pack, p.prod_size, p.prod_size_unit, p.spc
	   /* 04/01/10 - 12554 - sth0458 - Added for 212 Enh - SCE057 - End */
    FROM ord_cool c, ordm m, ordd d, pm p
    WHERE d.prod_id = p.prod_id
    AND   d.cust_pref_vendor = p.cust_pref_vendor
    AND   m.order_id = d.order_id
    AND   c.order_id = d.order_id
    AND   c.order_line_id = d.order_line_id
    AND   c.seq_no = 1
/

