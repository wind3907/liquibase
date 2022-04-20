CREATE OR REPLACE VIEW swms.v_missing_labels
	(route_batch_no, route_no, truck_no, batch_no, float_no, float_status, route_status,
	 group_no, zone_id, equip_id, pull_type, recreate)
AS
	SELECT	r.route_batch_no, f.route_no, r.truck_no, f.batch_no, f.float_no, f.status, r.status,
		f.group_no, f.zone_id, f.equip_id,
		DECODE (f.pallet_pull, 'R', 'RPL', 'N', 'NOR', 'Y', 'BLK', 'B', 'BLK', 'D', 'VRT'),
		r.sel_lock
	  FROM	label_master l, floats f, route r
	 WHERE	r.route_no = f.route_no
	   AND	r.status IN ('SHT', 'OPN')
	   AND	f.batch_no = l.batch_no (+)
	   AND	((l.batch_no IS NULL AND f.batch_no != 0) OR
		 (l.batch_no = 0))
/
CREATE OR REPLACE PUBLIC SYNONYM v_missing_labels FOR swms.v_missing_labels
/

