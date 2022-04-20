REM @(#) src/schema/views/sos_training_view.sql, swms, swms.9, 11.1 12/19/07 1.6
REM File : @(#) src/schema/views/sos_training_view.sql, swms, swms.9, 11.1
REM Usage: sqlplus USR/PWD @src/schema/views/sos_training_view.sql, swms, swms.9, 11.1
REM
REM      MODIFICATION    HISTORY
REM  09/23/03 prpakp     Changed to add the kvi values of child batches if the 
REM                      batch is a parent batch and check for the sum(kvi_no_stops)
REM                      This will allow all MULTI batches to get displayed in the
REM                      SOS->TRaining screen.
REM  10/01/07 prplhj     D#12288 Added SOS_BATCH table into the view.
REM  12/18/07 prplhj     D#12322 Added v_sos_training into SOS_BATCH data fetch.
REM  03/04/10 gsaj0457   D#12554 Added route_no in the first select for  
REM                       add_on routes
REM  10/15/14 Vani Reddy Added Priority column and commented out the status in where clause
REM                         to allow all records including pending to show for the view


CREATE OR REPLACE VIEW swms.sos_training_view AS
SELECT b.batch_no batch_no,
         b.truck_no truck_no,
         b.status status,
         b.no_of_stops no_of_stops,
         b.no_of_items no_of_items,
         b.no_of_cases no_of_cases,
         j.whar_area area,
         b.job_code job_code,
         b1.kvi_cube batch_cube,
         b1.kvi_wt batch_wt,
         b.route_no route_no,
         b.priority priority
  FROM sos_batch b, job_code j, v_sos_training b1
  WHERE b.no_of_stops > 0  
  --AND   b.status IN ('F', 'P')     -- Vani Reddy commented
  AND   b.job_code = j.jbcd_job_code
  AND    'S' || b.batch_no = b1.batch_no
  UNION
  SELECT SUBSTR(b.batch_no, 2) batch_no,
         b.ref_no truck_no,
         b.status status,
         b1.kvi_no_stop no_of_stops,
         b1.kvi_no_item no_of_items,
         b1.kvi_no_case no_of_cases,
         j.whar_area area,
         b.jbcd_job_code job_code,
         b1.kvi_cube batch_cube,
         b1.kvi_wt batch_wt,
         NULL  route_no,
         NULL priority
  FROM  batch b, v_sos_training b1, job_code j
  WHERE b.batch_no = b1.batch_no
  AND   b.batch_no LIKE 'S%'
  AND   b1.kvi_no_stop > 0
  -- AND   b.status LIKE '%F'    -- Vani Reddy commented
  AND   b.jbcd_job_code = j.jbcd_job_code
  AND   NOT EXISTS (SELECT 1
                    FROM sos_batch
                    WHERE batch_no = SUBSTR(b.batch_no, 2))
/

COMMENT ON TABLE swms.sos_training_view IS 'VIEW sccs_id=@(#) src/schema/views/sos_training_view.sql, swms, swms.9, 11.1 12/19/07 1.6';
