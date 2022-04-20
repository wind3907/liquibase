REM @(#) src/schema/views/v_add_on_route_check.sql, swms, swms.9, 11.1 3/2/09 1.2 
REM File : @(#) src/schema/views/v_add_on_route_check.sql, swms, swms.9, 11.1
REM Usage: sqlplus USR/PWD @src/schema/views/v_add_on_route_check.sql, swms, swms.9, 11.1
REM
REM      MODIFICATION HISTORY
REM  03/04/10 gsaj0457 D#12554 New View Created for fetching details for add on 
REM                    route

create or replace view swms.v_add_on_route_check as
select truck_no truck_no,
       SUM(stops) stops,
       CASE 
       WHEN SUM(NVL(add_on_route_seq,0)) > 0
       THEN 'Y'
       ELSE 'N' 
       END add_on_route_flag
 from route 
 where status NOT IN ('NEW', 'RCV')
 group by truck_no;
 
