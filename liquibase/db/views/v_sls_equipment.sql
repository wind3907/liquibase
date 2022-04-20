REM
REM File : v_sls_equipment.sql
REM
REM sccs_id = @(#) src/schema/views/v_sls_equipment.sql, swms, swms.9, 10.1.1 7/15/08 1.1 
REM
REM MODIFICATION HISTORY
REM 07/31/07 prplhj D#12402 Initial version. It's created to allow the 
REM                 combinations of LAS_RF_EQUIPMENT, LAS_PALLET_JACK and
REM                 EQUIPMENT tables.
REM
CREATE OR REPLACE VIEW swms.v_sls_equipment (equipment_no) AS
  SELECT equipment_no
  FROM las_rf_equipment
  UNION
  SELECT equipment_no
  FROM las_pallet_jack
  UNION
  SELECT equip_id
  FROM equipment
/

COMMENT ON TABLE v_sls_equipment IS 'VIEW sccs_id=@(#) src/schema/views/v_sls_equipment.sql, swms, swms.9, 10.1.1 7/15/08 1.1';

