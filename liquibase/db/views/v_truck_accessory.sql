REM
REM File : v_truck_accessory.sql
REM
REM sccs_id = @(#) src/schema/views/v_truck_accessory.sql, swms, swms.9, 10.1.1 1/23/09 1.2 
REM
REM MODIFICATION HISTORY
REM 02/28/07 prplhj D#12402 Initial version. It's created to allow the 
REM                 combinations of LAS_TRUCK_EQUIPMENT and
REM		    TRUCK_ACCESSORY_HISTORY tables.
REM 12/09/08 prplhj D#12446 Changed union to union all. No group by and sum
REM		    for truck_accessory_history to speed up the query time.
REM
CREATE OR REPLACE VIEW swms.v_truck_accessory AS
  SELECT truck truck_no,
	 type_seq,
	 NVL(MAX(ship_date), TRUNC(MAX(add_date))) ship_date,
	 barcode,
	 MAX(manifest_no) manifest_no,
	 MAX(route_no) route_no,
	 MAX(add_date) add_date,
	 SUM(NVL(loader_count, 0)) loader_count,
	 SUM(NVL(inbound_count, 0)) inbound_count
  FROM las_truck_equipment
  GROUP BY ship_date, truck, route_no, type_seq, barcode,
           NVL(ship_date, TRUNC(add_date))
  UNION ALL
  SELECT truck truck_no,
	 type_seq,
	 NVL(ship_date, TRUNC(add_date)) ship_date,
	 barcode,
	 manifest_no,
	 route_no,
	 add_date,
	 NVL(loader_count, 0) loader_count,
	 NVL(inbound_count, 0) inbound_count
  FROM truck_accessory_history
/

COMMENT ON TABLE v_truck_accessory IS 'VIEW sccs_id=@(#) src/schema/views/v_truck_accessory.sql, swms, swms.9, 10.1.1 1/23/09 1.2';

