REM @(#) src/schema/views/v_las_truck_check.sql, swms, swms.9, 10.1.1 9/7/06 1.3
REM File : @(#) src/schema/views/v_las_truck_check.sql, swms, swms.9, 10.1.1
REM Usage: sqlplus USR/PWD @src/schema/views/v_las_truck_check.sql, swms, swms.9, 10.1.1
REM
REM      MODIFICATION HISTORY
REM  acpakp 9/29/03  New view to get the route numbers that are from current 
REM                  day when order purge didn't run.


create or replace view swms.v_las_truck_check as
select r.ROUTE_NO
from   ROUTE r,TRANS t
where  t.ROUTE_NO = r.ROUTE_NO
and    r.STATUS = 'CLS'
and    t. TRANS_TYPE = 'PAT'
and    t.TRANS_DATE > sysdate -1
union
select ROUTE_NO
from ROUTE
where STATUS <> 'CLS'
/

