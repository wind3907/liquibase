-- changes for R_13_1 for performance the values should be fetched from database if the flag value is Y

INSERT INTO sys_config
   (seq_no,  application_func,  config_flag_name, config_flag_desc, config_flag_val,   value_required,   value_updateable, value_is_boolean,data_type,
data_precision, data_scale,sys_config_list,sys_config_help)
(SELECT  max(seq_no) + 1,'GENERAL','MULTI_LANGUAGE_DATABASE_USE','use DB for multi language','N','Y','N', 'Y','CHAR',1, 0,'L','The syspar is used to set database use for multi language.' 
FROM sys_config);

COMMIT;

