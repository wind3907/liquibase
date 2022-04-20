SET ECHO OFF
SET SCAN OFF
--COLUMN maxseq_no NOPRINT NEW_VALUE maxseq;

/********************************************************************
**    Create sypar ENABLE_LIVE_RECEIVING
********************************************************************/

DELETE sys_config_valid_values WHERE config_flag_name = 'ENABLE_LIVE_RECEIVING';

DELETE sys_config              WHERE config_flag_name = 'ENABLE_LIVE_RECEIVING';

COMMIT;

/* Get the max sequence number used in sys_config table. */
--SELECT MAX( seq_no ) maxseq
--  FROM sys_config;

/* Define the new system parameter */
INSERT INTO sys_config
        ( seq_no,
          application_func,
          config_flag_name,
          config_flag_desc,
          config_flag_val,
          value_required,
          value_updateable,
          value_is_boolean,
          data_type,
          data_precision,
          data_scale,
          sys_config_list,
          sys_config_help
        )
  VALUES ( (SELECT MAX(seq_no) + 1 FROM sys_config),
           'RECEIVING',
           'ENABLE_LIVE_RECEIVING',
           'Turn live receiving on/off ',
           'N',
           'Y',
           'Y',
           'Y',
           'CHAR',
           2,
           0,
           'L',
           'SWMS coordinators will be able to turn live receiving on or off with this system wide parameter'
         ) ;

INSERT INTO sys_config_valid_values
         ( config_flag_name,
           config_flag_val,
           description
         )
  SELECT 'ENABLE_LIVE_RECEIVING' config_flag_name,
         'N' config_flag_val,
         'Disable live receiving (print receiving labels in bulk).' description
    FROM DUAL ;

INSERT INTO sys_config_valid_values
         ( config_flag_name,
           config_flag_val,
           description
         )
  SELECT 'ENABLE_LIVE_RECEIVING' config_flag_name,
         'Y' config_flag_val,
         'Enable live receiving (print receiving labels individually during checking process).' description
    FROM DUAL ;

COMMIT;
