REM @(#) src/schema/views/v_sos_short_sum.sql, swms, swms.9, 10.1.1 9/7/06 1.2
REM File : @(#) src/schema/views/v_sos_short_sum.sql, swms, swms.9, 10.1.1
REM Usage: sqlplus USR/PWD @src/schema/views/v_sos_short_sum.sql, swms, swms.9, 10.1.1
REM
REM      MODIFICATION HISTORY
REM 06/30/06  prpakp Initial Creation

create or replace view swms.v_sos_short_sum as 
   select s.area,
          s.short_batch_no,
          b.jbcd_job_code
   FROM v_sos_short s, batch b
   WHERE 'S'||s.short_batch_no = b.batch_no(+)
   group by s.area,s.short_batch_no,b.jbcd_job_code;
/

