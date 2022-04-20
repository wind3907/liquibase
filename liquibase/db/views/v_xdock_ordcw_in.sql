------------------------------------------------------------------------------
-- File:
--    v_xdock_ordcw_in.sql
--
-- View:
--    v_xdock_ordcw_in
--
-- Description:
--    Script to create a view of the XDOCK_ORDCW_IN table.
--    This view is used at Site 2 to merge in the ordcw records for the cross dock floats sent from Site 1.
--
--    These 'X' cross dock info needs to be in these tables:
--       ORDM
--       ORDD
--       XDOCK_FLOATS_IN
--       XDOCK_FLOAT_DETAIL_IN
--       XDOCK_ORDCW_IN  (if there are catchweight items)
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    09/07/21 bben0556 Brian Bent
--                      R1 cross dock  (Xdock)
--                      Card: Card: R47-xdock-OPCOF3663_OP_Site_2_Merge_float_ordcw_sent_from_Site_1
--                      Created.
--                      ***** 09/08/21  Brian Bent  Selecting latest ordcw record not done yet.
--
------------------------------------------------------------------------------
CREATE OR REPLACE VIEW v_xdock_ordcw_in
AS
SELECT
       ordcw_x.sequence_number,
       ordcw_x.batch_id,
       ordcw_x.record_status,
       ordcw_x.route_no,                  -- This is the Site 1 route number.
                                          -- The Site 2 route number is inserted into ORDCW.
       --
       -- Need the Site 2 route number
       (SELECT ordd.route_no              
          FROM ordd
         WHERE ordd.seq = ordcw_x.order_seq)    site_to_route_no,
       --
       ordcw_x.order_id,                  -- This is the Site 1 order id.  The Site 2 order id is inserted into ORDCW.
       --
       -- Need the Site 2 order id.
       (SELECT ordd.order_id              
          FROM ordd
         WHERE ordd.seq = ordcw_x.order_seq)    site_to_order_id,
       --
       ordcw_x.order_line_id,
       ordcw_x.seq_no,
       ordcw_x.prod_id,
       ordcw_x.cust_pref_vendor,
       ordcw_x.catch_weight,
       ordcw_x.cw_type,
       ordcw_x.uom,
       ordcw_x.cw_float_no,               -- This is the Site 1 float number.  The Site 2 float number is inserted into ORDCW.
       ordcw_x.cw_scan_method,
       ordcw_x.order_seq,
       ordcw_x.case_id,
       ordcw_x.cw_kg_lb,
       ordcw_x.pkg_short_used,
       ordcw_x.add_date,
       ordcw_x.add_user,
       ordcw_x.upd_date,
       ordcw_x.upd_user
  FROM
       xdock_ordcw_in ordcw_x
/



CREATE OR REPLACE PUBLIC SYNONYM v_xdock_ordcw_in FOR swms.v_xdock_ordcw_in;

GRANT SELECT ON swms.v_xdock_ordcw_in TO swms_user;
GRANT SELECT ON swms.v_xdock_ordcw_in TO swms_viewer;

