/****************************************************************************
** Date:       24-May-2018
** File:       Jira519_Auto_Gen_Route_Syspar_dml.sql
**
** Script to create SYSPAR values AUTO_GEN_CUST_ID.
**
** Create below SYSPAR entries note Customer_ID that needs AUto Generation of Routes.
**
** Modification History:
**    Date        Designer           Comments
**    -------- -------- ---------------------------------------------------
**    12-Jul-2018 Vishnupriya K.     Check this Syspar in SWMSORREADER
**
****************************************************************************/
DECLARE
  v_column_exists NUMBER := 0;
BEGIN
  SELECT COUNT(*)
  INTO v_column_exists
  FROM sys_config
  WHERE APPLICATION_FUNC = 'ORDER_PROCESSING'
   and CONFIG_FLAG_NAME =   'AUTO_GEN_CUST_ID';
   
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
    'ORDER_PROCESSING',
    'AUTO_GEN_CUST_ID',
    'Auto Gen Routes Customer ID',
    'XXX',
    'N',
    'Y',
    'N',
    'CHAR',
    10,
    NULL,
    'N',
    'Enter Auto Gen Routes CustID',
    NULL,
    'NONE',
    NULL,
    NULL,
    NULL
  );
  COMMIT;
  
  End If;
End;							  
/