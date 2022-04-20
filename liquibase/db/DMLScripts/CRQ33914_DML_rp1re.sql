/****************************************************************************
** File:       DML_SYSPAR_rp1re.sql
**
** Desc: Script to insert Sysconfig data
**
**
** Modification History:
**    Date        Designer           Comments
**    -------- -------- ----------------------------------------------------
**    8-Jun-2017 Vishnupriya K.     Dynamic setup for Order by  
**    23-Aug-2017 Vishnupriya K.    3rd Order by  included, VALIDATION_TYPE value corrected to 'L'
**
****************************************************************************/
DECLARE
  v_column_exists NUMBER := 0;
BEGIN
  SELECT COUNT(*)
  INTO v_column_exists
  FROM sys_config
  WHERE APPLICATION_FUNC = 'RECEIVING'
   and CONFIG_FLAG_NAME = 'RP1RE_SORT'
  and  CONFIG_FLAG_DESC ='PO WorkSheet Sort Options';

IF (v_column_exists = 0)  THEN

INSERT
INTO sys_config
  (
    SEQ_NO,
    APPLICATION_FUNC,
    CONFIG_FLAG_NAME,
    CONFIG_FLAG_DESC,
    CONFIG_FLAG_VAL,
    VALUE_REQUIRED,
    VALUE_UPDATEABLE,
    VALUE_IS_BOOLEAN,
    DATA_TYPE,
    DATA_PRECISION,
    DATA_SCALE,
    SYS_CONFIG_LIST,
    SYS_CONFIG_HELP,
    LOV_QUERY,
    VALIDATION_TYPE,
    RANGE_LOW,
    RANGE_HIGH,
    DISABLED_FLAG
  )
  VALUES
  (
    (SELECT MAX(seq_no) + 1 FROM sys_config
    )
    ,
    'RECEIVING',
    'RP1RE_SORT',
    'PO WorkSheet Sort Options',
    'P',
    'Y',
    'Y',
    'N',
    'CHAR',
    8,
    NULL,
    'L',
    'Choose the desired Sort Order to print the PO Work Sheet',
    NULL,
    NULL,
    NULL,
    NULL,
    NULL
  );

INSERT INTO sys_config_valid_values (config_flag_name, config_flag_val, description, Param_values)
                              VALUES('RP1RE_SORT', 'P', 'Sort by PO number', 'Order by e.erm_id');
                           
                               
INSERT INTO sys_config_valid_values (config_flag_name, config_flag_val, description, Param_values)
                              VALUES('RP1RE_SORT', 'D-L-S', 'Sort by Door No, Load No, Sched Date','Order by Door_No, Load_No, Sched_date');
							  
INSERT INTO sys_config_valid_values (config_flag_name, config_flag_val, description, Param_values)
                              VALUES('RP1RE_SORT', 'D-L-P', 'Sort by Door No, Load No, PO No', 'Order by Door_No, Load_No, e.erm_id');
End If;
End;							  