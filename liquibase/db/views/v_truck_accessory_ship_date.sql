REM
REM File : v_truck_accessory_ship_date.sql
REM
REM sccs_id = @(#) src/schema/views/v_truck_accessory_ship_date.sql, swms, swms.9, 10.1.1 1/2/09 1.3 
REM
REM MODIFICATION HISTORY
REM 02/28/07 prplhj D#12402 Initial version. It's created to allow the 
REM                 combinations of LAS_TRUCK_EQUIPMENT and
REM		    TRUCK_ACCESSORY_HISTORY tables.
REM 10/24/08 prplhj D#12430 Added barcode and manifest #.
REM 12/09/08 prplhj D#12446 Get rid of TRUCK_ACCESSORY table. Use union all
REM		    instead of union. Get rid of group by and max clauses for
REM		    TRUCK_ACCESSORY_HISTORY.
REM
CREATE OR REPLACE VIEW swms.v_truck_accessory_ship_date AS
  SELECT NVL(MAX(ship_date), TRUNC(MAX(add_date))) ship_date,
	 truck truck_no,
         route_no,
	 type_seq,
	 barcode,
         MAX(manifest_no) manifest_no,
	 SUM(loader_count) loader_count,
	 0 inbound_count
  FROM las_truck_equipment
  GROUP BY ship_date, truck, route_no, type_seq, barcode
  UNION ALL
  SELECT NVL(ship_date, TRUNC(add_date)) ship_date,
	 truck truck_no,
         route_no,
	 type_seq,
	 barcode,
         manifest_no,
	 loader_count,
	 inbound_count
  FROM truck_accessory_history
/

COMMENT ON TABLE v_truck_accessory_ship_date IS 'VIEW sccs_id=@(#) src/schema/views/v_truck_accessory_ship_date.sql, swms, swms.9, 10.1.1 1/2/09 1.3';

