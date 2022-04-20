/****************************************************************************
** File:       SWMS_STS_SERVER_SYSPAR_DML.sql
**
** Desc: Script to insert Sysconfig data for swms-sts server
**
**
** Modification History:
**    Date        Designer           Comments
**    -------- -------- ----------------------------------------------------
**    07-Feb-2018 Vishnupriya K.     setup sts server for Opco  
**    
****************************************************************************/
DECLARE
  v_column_exists NUMBER := 0;
  l_server varchar2(5) := 'A';
BEGIN
  SELECT COUNT(*)
  INTO v_column_exists
  FROM sys_config
  WHERE APPLICATION_FUNC = 'DRIVER-CHECK-IN'
   and CONFIG_FLAG_NAME = 'SWMS_STS_SERVER'
  and  CONFIG_FLAG_DESC ='Set up STS server for the Opco';

IF (v_column_exists = 0)  THEN


 Begin
  select decode(mod(a.opco_id,2), 0, 'A', 'B') 
  into l_server 
  from  maintenance b, STS_OPCO_DCID a
  where b.APPLICATION = 'SWMS'
  and b.COMPONENT = 'COMPANY'
  and b.ATTRIBUTE = 'MACHINE'  
  and a.OPCO_ID = substr(b.ATTRIBUTE_VALUE,1,3);
 Exception when Others then 
  l_server := 'A';
 End ;  

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
    (SELECT MAX(seq_no) + 1 FROM sys_config),
    'DRIVER-CHECK-IN',
    'SWMS_STS_SERVER',
    'Set up STS server for the Opco',
    l_server,
    'Y',
    'Y',
    'N',
    'CHAR',
    20,
    NULL,
    'L',
    'Choose the STS server for this Opco',
    NULL,
    NULL,
    NULL,
    NULL,
    NULL
  );

INSERT INTO sys_config_valid_values (config_flag_name, config_flag_val, description, Param_values)
                              VALUES('SWMS_STS_SERVER',       'A',        'STS Server a', 'swms_sts_server_a');
                           
                               
INSERT INTO sys_config_valid_values (config_flag_name, config_flag_val, description, Param_values)
                              VALUES('SWMS_STS_SERVER', 'B',           'STS Server B', 'swms_sts_server_b');
							  
                         
End If;
End;	
/						  