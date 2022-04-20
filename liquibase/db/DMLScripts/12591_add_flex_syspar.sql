--    06-JUL-10 PRPPXX   D12591 Add syspar to control sending file for FLEX parallel 
--                       server after going live.

delete from sys_config
 where CONFIG_FLAG_NAME in ('LXLI_SEND_SL_BOTH','LXLI_SEND_FL_BOTH','LXLI_SEND_LD_BOTH','LXLI_USER_ID')
/
delete sys_config_valid_values
 where CONFIG_FLAG_NAME in ('LXLI_SEND_SL_BOTH','LXLI_SEND_FL_BOTH','LXLI_SEND_LD_BOTH','LXLI_USER_ID')
/

INSERT INTO sys_config
   (seq_no,
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
    sys_config_help)
SELECT
   max(seq_no) + 1 seq_no,
   'LABOR MGMT'                     application_func,
   'LXLI_SEND_SL_BOTH'             config_flag_name,
   'Send sel file to both servers'     config_flag_desc,
   'N'     config_flag_val,
   'Y'     value_required,
   'N'     value_updateable,
   'Y'     value_is_boolean,
   'CHAR'  data_type,
   1      data_precision,
   0       data_scale,
   'L'     sys_config_list,
'The syspar is used to control sending selection batch file to production and parallel servers
 after selector goal_time live with FLEX. 
 Y - send to parallel server after live, 
 N - do not send to parallel server after live.
 This flag is controlled by corporate office. ' sys_config_help
 FROM sys_config
/
INSERT INTO sys_config
   (seq_no,
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
    sys_config_help)
SELECT
   max(seq_no) + 1 seq_no,
   'LABOR MGMT'                     application_func,
   'LXLI_SEND_LD_BOTH'             config_flag_name,
   'Send ld file to both servers'     config_flag_desc,
   'N'     config_flag_val,
   'Y'     value_required,
   'N'     value_updateable,
   'Y'     value_is_boolean,
   'CHAR'  data_type,
   1      data_precision,
   0       data_scale,
   'L'     sys_config_list,
'The syspar is used to control sending loader batch file to production and parallel servers 
 after loader goal_time live with FLEX. 
 Y - send to parallel server after live, 
 N - do not send to parallel server after live.
 This flag is controlled by cooperate office. ' sys_config_help
 FROM sys_config
/

INSERT INTO sys_config
   (seq_no,
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
    sys_config_help)
SELECT
   max(seq_no) + 1 seq_no,
   'LABOR MGMT'                     application_func,
   'LXLI_SEND_FL_BOTH'             config_flag_name,
   'Send fl file to both servers'     config_flag_desc,
   'N'     config_flag_val,
   'Y'     value_required,
   'N'     value_updateable,
   'Y'     value_is_boolean,
   'CHAR'  data_type,
   1      data_precision,
   0       data_scale,
   'L'     sys_config_list,
'The syspar is used to control sending forklift batch file to production and parallel servers
 after forklift goal_time live with FLEX. 
 Y - send to parallel server after live, 
 N - do not send to parallel server after live.
 This flag is controlled by cooperate office. ' sys_config_help
 FROM sys_config
/


INSERT INTO sys_config_valid_values
            (config_flag_name, config_flag_val, description)
     VALUES
            ('LXLI_SEND_SL_BOTH', 'N', 'Selection batch not sent to parallel server after live.')
/
INSERT INTO sys_config_valid_values
            (config_flag_name, config_flag_val, description)
     VALUES
            ('LXLI_SEND_SL_BOTH', 'Y', 'Selection batch sent to parallel after live.')
/
INSERT INTO sys_config_valid_values
            (config_flag_name, config_flag_val, description)
     VALUES
            ('LXLI_SEND_FL_BOTH', 'N', 'Forklift batch not sent to parallel server after live.')
/
INSERT INTO sys_config_valid_values
            (config_flag_name, config_flag_val, description)
     VALUES
            ('LXLI_SEND_FL_BOTH', 'Y', 'Forklift batch sent to parallel after live.')
/
INSERT INTO sys_config_valid_values
            (config_flag_name, config_flag_val, description)
     VALUES
            ('LXLI_SEND_LD_BOTH', 'N', 'Loader batch not sent to parallel server after live.')
/
INSERT INTO sys_config_valid_values
            (config_flag_name, config_flag_val, description)
     VALUES
            ('LXLI_SEND_LD_BOTH', 'Y', 'Loader batch sent to parallel after live.')
/

commit
/

