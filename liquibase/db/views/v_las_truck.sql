REM @(#) src/schema/views/v_las_truck.sql, swms, swms.9, 11.1 1/27/09 1.5 
REM File : @(#) src/schema/views/v_las_truck.sql, swms, swms.9, 11.1
REM Usage: sqlplus USR/PWD @src/schema/views/v_las_truck.sql, swms, swms.9, 11.1
REM
REM      MODIFICATION HISTORY
REM  07/15/03 acpakp Added the condition to check for PAT transaction
REM                  so that if is same truck number from previous day still
REM                  exists it will not come up in the view.
REM  05/01/08 prplhj D#12402 Added LAS_TRUCK.truck_status.
REM  12/09/08 prplhj D#12446 Used union all. No group by in truck_acc_history.
REM  03/04/10 gsaj0457 D#12554 Added v_add_on_route_check in from clause 
REM    	    	       for add_on routes and modified the stops select, 
REM                    which will now be fetched from the new view

create or replace view swms.v_las_truck as
select t.truck truck,
          t.trailer trailer,
          t.trailer_type trailer_type,
          t.freezer_status freezer_status,
          t.cooler_status cooler_status,
          t.dry_status dry_status,
          decode(RTrim(t.freezer_status) || RTrim(t.cooler_status) ||
            RTrim(t.dry_status), '', 'N', Null, 'N', 'Y') mapping_status,
          t.loader loader,
          t.start_time start_time,
          t.complete_time complete_time,
          r.sch_time dispatch_time,
          t.last_pallet last_pallet,
          substr( ( substr( to_char( nvl( r.f_door, 0 ), 'B99' ), 2, 2 )
                    || '/' ||
                    substr( to_char( nvl( r.c_door, 0 ), 'B99' ), 2, 2 )
                    || '/' ||
                    substr( to_char( nvl( r.d_door, 0 ), 'B99' ), 2, 2 )
                    ), 1, 8 ) doors,
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
		  va.add_on_route_flag add_on_route_flag,
	      pl_nos.get_map_status(t.truck) new_mapping_status
   FROM ROUTE r, LAS_TRUCK t, V_LAS_TRUCK_CHECK v,V_ADD_ON_ROUTE_CHECK va
   WHERE rtrim( t.truck ) = r.truck_no
   AND   v.route_no = r.route_no
   AND   t.route_no = r.route_no
   AND   t.truck = va.truck_no
   AND   r.status NOT IN ('NEW', 'RCV')
/

