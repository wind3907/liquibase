INSERT INTO SYS_CONFIG (
    seq_no, application_func, config_flag_name,
    config_flag_desc, config_flag_val, value_required,
    value_updateable, value_is_boolean, data_type,
    data_precision, sys_config_list, validation_type,
    lov_query,
    sys_config_help)
SELECT
    (select max(seq_no) + 1 from sys_config), 'RECEIVING', 'AUTO_OPEN_PO_DOOR_NO',
    'Auto Open POs set door number', null, 'N',
    'Y', 'N', 'CHAR',
    4, 'L', 'LIST',
    'select door_no, dock_no, physical_door_no from door order by door_no',
    'The door no. is used to auto open/receive POs for a meat company. For POs that are set to auto open, the door no. will get assigned the value of this syspar.'
FROM dual
WHERE NOT EXISTS (SELECT 1 FROM sys_config where config_flag_name = 'AUTO_OPEN_PO_DOOR_NO');
COMMIT;


INSERT INTO SYS_CONFIG (
    seq_no, application_func, config_flag_name,
    config_flag_desc, config_flag_val, value_required,
    value_updateable, value_is_boolean, data_type,
    data_precision, sys_config_list, validation_type,
    sys_config_help)
SELECT
    (select max(seq_no) + 1 from sys_config), 'RECEIVING', 'SPECIALTY_VENDOR_ID',
    'Auto Open POs using vendor ID', 'XXX', 'Y',
    'Y', 'N', 'CHAR',
    10, 'T', 'NONE',
    'The vendor ID is used to auto open/receive POs for a meat company. If the opco is a meat company, and if the vendor ID syspar is equal to the vendor ID of the PO, then the PO will auto open/receive.'
FROM dual
WHERE NOT EXISTS (SELECT 1 FROM sys_config where config_flag_name = 'SPECIALTY_VENDOR_ID');
COMMIT;