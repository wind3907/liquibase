

--
-- Fri Feb  4 10:57:27 CST 2022
-- ENH-R51_0_OPCOF-3800_Xdock_Site_2_Scanning xdock_lp_at_receiving_will_determine_direct_to_staging_or_door
-- Scanning the XN cross dock pallet at Site 2 for putaway.
 -- Info needed by the RF to direct the pallet to the door.
-- This happens either when:
--    the pallet was directed to the outbound door when the XN was opened
--    OR
--    when th XN was opened the pallet was directed to staging but now selection has started
--    for the route and the pallet needs to go to the outbound door.
-- Need float info, etc.  Most of the info comes from REPLENLST, FLOATS and FLOAT_DETAIL.
--
CREATE OR REPLACE VIEW swms.v_xdock_put_xdk
AS
SELECT
       r.pallet_id            pallet_id,
       r.task_id              task_id,
       r.type                 type,
       r.status               status,
       r.prod_id              prod_id,              -- If the pallet has different items then this will be 'MULTI'.
       r.cust_pref_vendor     cust_pref_vendor,
       --
       -- If replenlst.prod_id is 'MULTI' then the item dscription will also be 'MULTI'.
       NVL(pm.descrip, 'MULTI') item_descrip,
       --
       r.src_loc,
       r.dest_loc,
       r.door_no,
       --
       r.s_pikpath             put_path_val,
       1                       spc,               -- Use 1.  The pallet can have diffeent items on it.
       r.qty,                                     -- replenlst.qty is the number of pieces on the pallet.
       --
       r.cross_dock_type       cross_dock_type,
       r.route_no              route_no,
       r.truck_no              truck_no,
       f.float_seq             float_seq,
       NULL                    brand,
       f.pallet_pull           bp_type,           -- floats.pallet_pull
       NULL                    pack,
       f.batch_no              batch_no,
       'N'                     catch_wt_trk,      -- NA for XDK so use 'N'
       999.99                  avg_wt,            -- NA for XDK so use 999.99
       100                     tolerance,         -- NA for XDK so use 100
       1                       NumCust,           -- NA for XDK so use 1.  RF needs a value.
       cdt.description         instructions,
       50                      priority,          -- Won't use but the RF needs a value.
       --
       fd_details.order_seq    order_seq,
       fd_details.order_id     order_id,
       fd_details.ship_date    ship_date,         -- Will go into the xdock pre_putaway server object "inv_date" field.
       fd_details.cust_id      cust_id,
       fd_details.cust_name    cust_name,
       fd_details.stop_no      stop_no
  FROM
       cross_dock_type  cdt,    -- To get the cross dock type description which is sent to the RF in the "instructions"
       pm               pm,     -- To get the item description
       floats           f,      -- FLOATS has some needed data.
       replenlst        r,
       --
       -- Start inline view to get info about the pallet from float detail.  Needed for the XDK bulk pull label
       -- Must return only one record for an XDK.
       (SELECT           
               fd.float_no                                                                    float_no,
               DECODE(COUNT(DISTINCT fd.order_seq), 1, MIN(fd.order_seq), 0)                  order_seq,     -- Sent 0 to RF for order seq if pallet has multiple order seqs
               DECODE(COUNT(DISTINCT fd.order_id),  1, MIN(fd.order_id),  'MULTIORDR'   )     order_id,
               MIN(TO_CHAR(o.ship_date, 'MMDDYY'))                                            ship_date,     --  10/05/21 Always select min ship date. RF always needs a valid date
               DECODE(COUNT(DISTINCT o.cust_id),    1, MIN(o.cust_id),    'MULTI CUST')       cust_id,
               DECODE(COUNT(DISTINCT o.cust_name),  1, MIN(o.cust_name),  'MULTI CUSTOMERS')  cust_name,
               DECODE(COUNT(DISTINCT fd.stop_no),   1, MIN(fd.stop_no),   999)                stop_no,       -- Sent 999 to RF for stop# if pallet has multiple stops
               SUM(DECODE(fd.uom, 1, fd.qty_alloc, fd.qty_alloc / p.spc))                     qty
          FROM
               pm p,
               ordm o,
               float_detail fd
         WHERE
               o.order_id           = fd.order_id
           AND p.prod_id            = fd.prod_id
           AND p.cust_pref_vendor   = fd.cust_pref_vendor
           AND fd.qty_alloc         > 0
         GROUP BY fd.float_no) fd_details
       -- end inline view
       --
 WHERE cdt.cross_dock_type      = r.cross_dock_type
   AND f.float_no           (+) = r.float_no
   AND fd_details.float_no  (+) = r.float_no
   AND pm.prod_id           (+) = r.prod_id              -- Outer join to PM table since replenlst.prod_id could be 'MULTI'
   AND pm.cust_pref_vendor  (+) = r.cust_pref_vendor
/


CREATE OR REPLACE PUBLIC SYNONYM v_xdock_put_xdk FOR swms.v_xdock_put_xdk;

GRANT SELECT ON swms.v_xdock_put_xdk TO swms_user;
GRANT SELECT ON swms.v_xdock_put_xdk TO swms_viewer;


