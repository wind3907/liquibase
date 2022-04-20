------------------------------------------------------------------------------
--
-- View:
--    stops     (Note the view name it does not start with "v_")
--
-- Description:
--    This view is used by the order generation build float processing.
--
-- Used By:
--    Order generation
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    07/21/21 bben0556 Brian Bent
--                      R1 cross dock.
--                      Card: R47-xdock-OPCOF3380_OP_Site_1_Build_pallets_by_number_of_stops_syspar
--
--                      Created this script as we did not have one for the "stops" view
--                      and I needed to add columns to the view.
--                      The view text was:
--     SELECT distinct route_no, stop_no, unitize_ind, sum(d_pieces),
--            sum(f_pieces), sum(c_pieces)
--     FROM ordm
--     GROUP BY route_no, stop_no, unitize_ind
--
--                      Do not know why the distinct was there.  I removed it.
--
--                      Added columns:
--                         - site_to_stop_no
--            
--   08/17/21 pdas8114 Jira-3573- Add Xdock Indicator and OpCo # to Stop & Invoice Screen
--                         Added cross_dock_type , site_to columns
------------------------------------------------------------------------------
CREATE OR REPLACE VIEW swms.stops
AS
SELECT route_no,
       NVL(site_to_stop_no, stop_no)   stop_no,
       stop_no                         site_from_stop_no,
       site_to_stop_no                 site_to_stop_no,
       unitize_ind                     unitized,
       SUM(d_pieces)                   d_pieces,
       SUM(f_pieces)                   f_pieces,
       SUM(c_pieces)                   c_pieces,
	   cross_dock_type                 cross_dock_type,
	   decode( cross_dock_type, 'X',site_from, 'S', site_to) xdock_site
  FROM ordm
 GROUP BY
       route_no,
       NVL(site_to_stop_no, stop_no),
       stop_no,
       site_to_stop_no,
       unitize_ind,
	   cross_dock_type,
	   site_to,
	   site_from
/


CREATE OR REPLACE PUBLIC SYNONYM stops FOR swms.stops;

GRANT SELECT ON swms.stops TO swms_user;
GRANT SELECT ON swms.stops TO swms_viewer;

