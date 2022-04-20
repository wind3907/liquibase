REM
REM  File: v_sos_status.sql
REM  sccs_id = @(#) src/schema/views/v_sos_status.sql, swms, swms.9, 10.1.1 9/25/07 1.2
REM
REM  MODIFICATION HISTORY
REM  06/06/07 prpnxk D#12258 Initial version
REM
CREATE OR REPLACE VIEW swms.v_sos_status
	(selector_id, batch_no, route_no, truck_no,
	 start_time, last_pik_loc,no_cases,
	 no_splits, area, picked_time, job_code)
AS
SELECT	picked_by, batch_no, route_no, truck_no,
	start_time, last_pik_loc,no_of_cases,
	no_of_splits, area, picked_time, job_code
  FROM	sos_batch
 WHERE	status = 'A'
UNION
SELECT	su.user_id, null, null, null, sysdate, null,
	0, 0, whar_area, su.add_date, j.jbcd_job_code
  FROM	job_code j, sos_usr_config su
 WHERE	j.jbcd_job_code = su.primary_jc
   AND	su.pallet_jack_id IS NOT NULL
   AND	NOT EXISTS (
		SELECT	0
		  FROM	sos_batch
		 WHERE	picked_by = su.user_id
		   AND	status = 'A')
/
COMMENT ON TABLE swms.v_sos_status IS 'VIEW sccs_id=@(#) src/schema/views/v_sos_status.sql, swms, swms.9, 10.1.1 9/25/07 1.2'
/
