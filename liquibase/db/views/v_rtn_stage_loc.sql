REM @(#) src/schema/views/v_rtn_stage_loc.sql, swms, swms.9, 10.1.1 9/7/06 1.3
REM File : @(#) src/schema/views/v_rtn_stage_loc.sql, swms, swms.9, 10.1.1
REM Usage: sqlplus USR/PWD @src/schema/views/v_rtn_stage_loc.sql, swms, swms.9, 10.1.1
REM             -- View that shows the valid staging locations for returns.
REM
REM 03/08/05  DN 11884
REM
CREATE OR REPLACE VIEW swms.v_rtn_stage_loc (rtn_stage_loc) AS
   SELECT logi_loc
     FROM loc
    WHERE status = 'AVL'
UNION 
   SELECT door_no
     FROM door
/

