REM
REM File : v_slt_equip_log.sql
REM
REM sccs_id = @(#) src/schema/views/v_slt_equip_log.sql, swms, swms.9, 10.1.1 5/24/07 1.1
REM
REM MODIFICATION HISTORY
REM 02/28/07 prplhj D#12251 Initial version. It's created to allow the
REM                 combinations of EQUIPMENT, SOS_USR_CONFIG and LAS_USR_CONFIG
REM                 tables.
REM
CREATE OR REPLACE VIEW swms.v_slt_equip_log AS
  SELECT e.equip_id, e.appl_type, e.equip_type, e.descrip, e.status,
         u.user_id, e.add_date, e.add_user, e.upd_date, e.upd_user
  FROM sos_usr_config u, equipment e
  WHERE u.pallet_jack_id (+) = e.equip_id
  UNION
  SELECT e.equip_id, e.appl_type, e.equip_type, e.descrip, e.status,
         u.user_id, e.add_date, e.add_user, e.upd_date, e.upd_user
  FROM las_usr_config u, equipment e
  WHERE u.pallet_jack_id (+) = e.equip_id
/

COMMENT ON TABLE v_slt_equip_log IS 'VIEW sccs_id=@(#) src/schema/views/v_slt_equip_log.sql, swms, swms.9, 10.1.1 5/24/07 1.1';

