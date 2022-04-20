--
-- Wed Mar  2 11:51:36 CST 2016
-- Throttling changes.
-- This script inserts the syspar that sets the target number of cases to select from the matrix for the day.
--

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
    lov_query,
    validation_type,
    range_low,
    range_high,
    disabled_flag,
    sys_config_help)
SELECT
   (SELECT MAX(seq_no) + 1 FROM sys_config)   seq_no, 
   'MATRIX'                                   application_func,
   'MX_THROTTLE_ORDER_MAX'                    config_flag_name,
   'Number of cases output per day'           config_flag_desc,
   '9900'                                     config_flag_val,
   'Y'                                        value_required,
   'Y'                                        value_updateable,
   'N'                                        value_is_boolean,
   'NUMBER'                                   data_type,
   4                                          data_precision,
   0                                          data_scale,
   'R'                                        sys_config_list,
   NULL                                       lov_query,
   'RANGE'                                    validation_type,
   1                                          range_low,
   9999                                       range_high,
   NULL                                       disabled_flag,
'Throttling Functionality--This syspar sets the target number of cases to select'
|| ' from the matrix for the day in order to leverage the full capacity of the matrix system.'
||  '  If the projected number (based on historical orders) of cases to select from the matrix'
|| ' is below this value then non-demand replenishments can be created from the main warehouse'
|| ' to the matrix to achieve this target provided there are items setup to be "throttled".'     sys_config_help
FROM DUAL
/


