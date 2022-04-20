REM
REM  File: v_equip_safety_hist.sql
REM  sccs_id = @(#) src/schema/views/v_equip_safety_hist.sql, swms, swms.9, 10.1.1 5/10/07 1.1
REM
REM  MODIFICATION HISTORY
REM  02/28/07 prplhj D#12251 Initial version
REM  10/31/13 mdev3739 CRQ46091- Added two new column to the existing view 
REM  12/05/14 SPOT3255 Charm# 6000000871- Removed seq from the view

CREATE OR REPLACE VIEW SWMS.V_EQUIP_SAFETY_HIST
AS
   SELECT DISTINCT
          equip_id,
          appl_type,
          add_date,
          add_user,
          status_type,
          TO_DATE (TO_CHAR (add_date, 'mm/dd/yy hh24:mi'),
                   'mm/dd/yy hh24:mi') ADD_DATE_Q,
		  status,
		  inspec_type
     FROM equip_safety_hist
/

COMMENT ON TABLE v_equip_safety_hist IS 'VIEW sccs_id=@(#) src/schema/views/v_equip_safety_hist.sql, swms, swms.9, 10.1.1 5/10/07 1.1';

