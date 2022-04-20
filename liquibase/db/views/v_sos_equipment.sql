REM
REM  File: v_sos_equipment.sql
REM  sccs_id = @(#) src/schema/views/v_sos_equipment.sql, swms, swms.9, 10.1.1 5/18/07 1.1
REM
REM  MODIFICATION HISTORY
REM  02/28/07 prpnxk D#12251 Initial version
REM
CREATE OR REPLACE VIEW swms.v_sos_equipment (EQUIPMENT_NO, EQUIPMENT_TYPE, DESCRIP) AS
  SELECT equipment_no, equipment_type, descrip
    FROM sos_equipment
  UNION
  SELECT equip_id, equip_type, descrip
    FROM equipment
/

COMMENT ON TABLE swms.v_sos_equipment IS 'VIEW sccs_id=@(#) src/schema/views/v_sos_equipment.sql, swms, swms.9, 10.1.1 5/18/07 1.1'
/

