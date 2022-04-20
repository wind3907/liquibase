REM
REM File : v_sls_loader.sql
REM
REM sccs_id = @(#) src/schema/views/v_sls_loader.sql, swms, swms.9, 10.1.1 8/1/08 1.1 
REM
REM MODIFICATION HISTORY
REM 07/31/08 prplhj D#12402 Initial version. It's created to allow the 
REM                 combinations of V_LAS_PALLET and LAS_USR_CONFIG tables
REM                 to retrieve current working or login loaders.
REM
CREATE OR REPLACE VIEW swms.v_sls_loader AS
  SELECT user_id loader_id, 'A' action_type
  FROM batch
  WHERE user_id IS NOT NULL
  AND   (batch_no LIKE 'L%' OR jbcd_job_code LIKE 'IL%')
  AND   status = 'A'
  UNION
  (SELECT user_id loader_id, 'L' action_type
   FROM las_usr_config
   WHERE pallet_jack_id IS NOT NULL
   MINUS
   SELECT user_id loader_id, 'L' action_type
   FROM batch
   WHERE user_id IS NOT NULL
   AND   (batch_no LIKE 'L%' OR jbcd_job_code LIKE 'IL%')
   AND   status = 'A')
/

COMMENT ON TABLE v_sls_loader IS 'VIEW sccs_id=@(#) src/schema/views/v_sls_loader.sql, swms, swms.9, 10.1.1 8/1/08 1.1';

