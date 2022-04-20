REM @(#) src/schema/views/v_las_truck_sort.sql, swms, swms.9, 10.2 3/2/09 1.2 
REM File : @(#) src/schema/views/v_las_truck_sort.sql, swms, swms.9, 10.2
REM Usage: sqlplus USR/PWD @src/schema/views/v_las_truck_sort.sql, swms, swms.9, 10.2
REM
REM      MODIFICATION HISTORY
REM  05/01/08 prplhj D#12402 Initial version. The view is mainly used by the
REM		     truck status screen to display truck detail information
REM		     with sorting of different screen request.
REM  02/24/09 prplhj D#12463 Include closed routes.
REM  03/15/10 gsaj0457 D#12554 Added v_add_on_route_check in from clause 
REM                    for add_on routes and modified the stops select,  
REM                    which will now be fetched from the new view

CREATE OR REPLACE VIEW swms.v_las_truck_sort AS
SELECT	t.truck truck,
	t.trailer trailer,
	t.trailer_type trailer_type,
	t.freezer_status freezer_status,
	t.cooler_status cooler_status,
	t.dry_status dry_status,
	t.start_time start_time,
	t.complete_time complete_time,
	t.freezer_complete_time freezer_complete_time,
	t.freezer_complete_user freezer_complete_user,
	t.cooler_complete_time cooler_complete_time,
	t.cooler_complete_user cooler_complete_user,
	t.dry_complete_time dry_complete_time,
	t.dry_complete_user dry_complete_user,
	r.sch_time dispatch_time,
	SUBSTR((SUBSTR(TO_CHAR(NVL(r.f_door, 0), 'B99'), 2, 2) || '/' ||
		SUBSTR(TO_CHAR(NVL(r.c_door, 0), 'B99'), 2, 2) || '/' ||
		SUBSTR(TO_CHAR(NVL(r.d_door, 0), 'B99'), 2, 2)), 1, 8) doors,
	va.stops stops,
	t.freezer_pallets freezer_pallets,
	t.freezer_cases freezer_cases,
	t.freezer_stops freezer_stops,
	t.freezer_cube freezer_cube,
	t.freezer_remaining freezer_remaining,
	t.freezer_stackheight freezer_stackheight,
	t.cooler_pallets cooler_pallets,
	t.cooler_cases cooler_cases,
	t.cooler_stops cooler_stops,
	t.cooler_cube cooler_cube,
	t.cooler_remaining cooler_remaining,
	t.cooler_stackheight cooler_stackheight,
	t.dry_pallets dry_pallets,
	t.dry_cases dry_cases,
	t.dry_stops dry_stops,
	t.dry_cube dry_cube,
	t.dry_remaining dry_remaining,
	t.dry_stackheight dry_stackheight,
	t.truck_status truck_status,
	t.route_no route_no,
	pl_nos.get_truck_func_sort(t.truck) status_sort
FROM route r, las_truck t, v_las_truck_check v,v_add_on_route_check va
WHERE RTRIM(t.truck) = r.truck_no
AND   v.route_no = r.route_no
AND   t.route_no = r.route_no
AND   t.truck = va.truck_no
AND   r.status NOT IN ('NEW', 'RCV')
/

