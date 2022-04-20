
--
-- Fri Jan 28 08:44:13 CST 2022
--

----------------------------------------------------------------------------
-- Object for pre_putaway data from the RF.
----------------------------------------------------------------------------
CREATE OR REPLACE TYPE swms.xdock_pre_putaway_client_obj FORCE AS OBJECT
(
   equip_id            VARCHAR2(10),
   pallet_id           VARCHAR2(18),
   merge_flag          VARCHAR2(1),     -- N or Y.  Y is user picking up multiple pallets so merge the forklift labor batches.
   scan_method         VARCHAR2(1)       -- User scanned/keyed the LP.
);
/

----------------------------------------------------------------------------
-- Object for pre_putaway data to send from the host to the RF.
----------------------------------------------------------------------------
CREATE OR REPLACE TYPE swms.xdock_pre_putaway_server_obj FORCE AS OBJECT
(
   pallet_id               VARCHAR2(18),      
   task_type               VARCHAR2(3),       -- Either PUT or XDK ???.  Set by host.  For the RF to use in deciding what to do.
   task_id                 VARCHAR2(10),      -- Either putawaylst.task_id or replenlst.task_id depending on the task_type.
   prod_id                 VARCHAR2(9),       -- If one item on the pallet then the prod_id otherwise 'MULTI'.
   cpv                     VARCHAR2(10),      -- If one cpv on the pallet then the cpv otherwise '-'.
   descrip                 VARCHAR2(30),      -- If one item on the pallet then the pm.descrip otherwise 'MULTI'.
   --
   src_loc                 VARCHAR2(10),      -- door number/haul location/staging location
   dest_loc                VARCHAR2(10),      -- If the pallet is going to a staging location then the staging location, for XDK the outbound door number.
   door_no                 VARCHAR2(4),       -- If the pallet is going to a door--XDK--then the door number otherwise null.  We may end up not using this.
   --
   put_path_val            VARCHAR2(10),      -- If the pallet is going to a staging location then the put path of the staging locations otherwise '000000000' ???.
   spc                     VARCHAR2(5),       -- hmmmmm, don't really need since the pallet can have multiple items.  Always set to 1.
   qty                     VARCHAR2(7),       -- The number of pieces on the pallet.
   --
   cross_dock_type         VARCHAR2(1),       -- floats.cross_dock_type
   route_no                VARCHAR2(10),      -- floats.route_no
   truck_no                VARCHAR2(10),      -- floats.truck_no
   float_seq               VARCHAR2(4),       -- floats.float_seq
   brand                   VARCHAR2(7),       -- null                  really needed ???  But the XDK bulk label has Brand on it.
   bp_type                 VARCHAR2(1),       -- floats.pallet_pull    really needed ???
   pack                    VARCHAR2(15),      -- null                  really needed ???
   batch_no                VARCHAR2(13),      -- floats.batch_no
   catch_wt_trk            VARCHAR2(1),       -- 'N'      NA for XDK   really needed ???
   avg_wt                  VARCHAR2(10),      -- 999.99   NA for XDK   really needed ???
   tolerance               VARCHAR2(5),       -- 100      NA for XDK   really needed ???
   NumCust                 VARCHAR2(2),       -- 0        NA for XDK   really needed ???
   instructions            VARCHAR2(30),      -- cross_dock_type.description for XDK otherwise null
   priority                VARCHAR2(2),       -- If task_type is XDM then the task priority--get from view v_replen_xdock--for XDM door->door--otherwise null
   --
   order_seq               VARCHAR2(8),       -- float_detail.order_seq if only one order_seq on the pallet otherwise 0
   order_id                VARCHAR2(14),      -- float_detail.order_id if only one order on the pallet otherwise 'MULTIORDR'
   inv_date                VARCHAR2(6),       -- MIN ordm.ship_date  for the orders on the pallet
   cust_id                 VARCHAR2(10),      -- If one customer on the pallet then ordm.cust_id otherwise 'MULTI CUST'
   cust_name               VARCHAR2(30),      -- If one customer on the pallet then ordm.cust_name otherwise 'MULTI CUSTOMERS'
   stop_no                 VARCHAR2(7)        -- If one stop on the pallet then the stop number otherwise 999.
);
/


GRANT EXECUTE ON swms.xdock_pre_putaway_client_obj TO swms_user;
GRANT EXECUTE ON swms.xdock_pre_putaway_server_obj TO swms_user;

