COL maxseq_no NOPRINT NEW_VALUE maxseq;

SELECT MAX(seq_no) maxseq_no FROM sys_config;

Insert into SWMS.SYS_CONFIG
   (SEQ_NO, APPLICATION_FUNC, CONFIG_FLAG_NAME, CONFIG_FLAG_DESC, CONFIG_FLAG_VAL, VALUE_REQUIRED, VALUE_UPDATEABLE, VALUE_IS_BOOLEAN, DATA_TYPE, DATA_PRECISION, SYS_CONFIG_LIST, SYS_CONFIG_HELP, VALIDATION_TYPE)
 Values
   (&maxseq + 1, 'SWMS', 'LANGUAGE_ENABLE', 'opco level language setting', '3', 'Y', 'Y', 'N', 'CHAR', 1, 'L', 'opco level language setting', 'LIST');
   

INSERT INTO sys_config_valid_values
   (config_flag_name, config_flag_val, description)
SELECT
   'LANGUAGE_ENABLE' config_flag_name,
   '3' config_flag_val,
   'Selected/Choosen Language is in English(en_US)' description
FROM DUAL;

INSERT INTO sys_config_valid_values
   (config_flag_name, config_flag_val, description)
SELECT
   'LANGUAGE_ENABLE' config_flag_name,
   '12' config_flag_val,
   'Selected/Choosen Language is in Canadian French(fr_CA)' description
FROM DUAL;

INSERT INTO sys_config_valid_values
   (config_flag_name, config_flag_val, description)
SELECT
   'LANGUAGE_ENABLE' config_flag_name,
   '35' config_flag_val,
   'Selected/Choosen Language is in European(en_IE)' description
FROM DUAL;

COMMIT;
