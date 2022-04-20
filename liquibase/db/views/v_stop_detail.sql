------------------------------------------------------------------------------
-- sccs_id=%Z% %W% %G% %I%
--
-- View:
--    stop_detail   (Note the view name it does not start with "v_")
--
-- Description:
--    This view is used by the order generation build float processing.
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    09/23/19 bben0556 Brian Bent
--                      Project: R30.6.8-Jira-OPCOF-2517-CMU-Project_cross_dock_picking
--
--                      Created this script as we did not have one for the "stop_detail" view
--                      and I needed to add columns to the view.
--                      Added columns:
--                         - remote_local_flg
--                         - remote_qty
--            
--    10/01/19 bben0556 Brian Bent
--                      Project: R30.6.8-Jira-OPCOF-2517-CMU-Project_cross_dock_picking
--                      Getting error in the order generation screen when drilling down
--                      to the order details.
--                      I had mistakenly named "order_line_id" as "seq" instead of seq_no".
--                      Changed
--                         order_line_id       seq,
--                      to
--                         order_line_id       seq_no,

--    07/21/21 bben0556 Brian Bent
--                      R1 cross dock.
--                      Card: R47-xdock-OPCOF3380_OP_Site_1_Build_pallets_by_number_of_stops_syspar
--
--                      Add table ORDM to get the site_to_stop_no.  This should not affect performance.
--                      Add:
--                         - NVL(m.site_to_stop_no, d.stop_no)  stop_no
--                         - d.stop_no                          site_from_stop_no
--                         - site_to_stop_no                    site_to_stop_no
--
------------------------------------------------------------------------------
CREATE OR REPLACE VIEW swms.stop_detail
AS
SELECT d.route_no                         route_no,
       --
       NVL(m.site_to_stop_no, d.stop_no)  stop_no,
       d.stop_no                          site_from_stop_no,
       m.site_to_stop_no                  site_to_stop_no,
       --
       d.order_id                         order_id,
       d.order_line_id                    seq_no,
       d.prod_id                          prod_id,
       d.cust_pref_vendor                 cust_pref_vendor,
       d.area                             area,
       d.zone_id                          zone_id,
       d.qty_ordered                      qty_order,
       d.qty_alloc                        qty_alloc,
       d.pallet_pull                      pallet_pull,
       d.status                           status,
       d.uom                              uom,
       d.qa_ticket_ind                    qa_ticket_ind,
       d.remote_local_flg                 remote_local_flg,
       d.remote_qty                       remote_qty
  FROM ordd d,
       ordm m
 WHERE m.order_id = d.order_id
/


CREATE OR REPLACE PUBLIC SYNONYM stop_detail FOR swms.stop_detail;

GRANT SELECT ON swms.stop_detail TO swms_user;
GRANT SELECT ON swms.stop_detail TO swms_viewer;


