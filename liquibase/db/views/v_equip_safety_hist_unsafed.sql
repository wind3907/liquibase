REM
REM File : v_equip_safety_hist_unsafed.sql
REM
REM sccs_id = @(#) src/schema/views/v_equip_safety_hist_unsafed.sql, swms, swms.9, 10.1.1 5/10/07 1.1 
REM
REM MODIFICATION HISTORY
REM 02/28/07 prplhj D#12251 Initial version.
REM
CREATE OR REPLACE VIEW swms.v_equip_safety_hist_unsafed AS
  SELECT DISTINCT equip_id, appl_type, add_date, add_user, status_type, status
  FROM equip_safety_hist
  WHERE LTRIM(RTRIM(status)) IS NOT NULL
/

COMMENT ON TABLE v_equip_safety_hist_unsafed IS 'VIEW sccs_id=@(#) src/schema/views/v_equip_safety_hist_unsafed.sql, swms, swms.9, 10.1.1 5/10/07 1.1';

