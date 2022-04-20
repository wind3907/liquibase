COL maxseq_no NOPRINT NEW_VALUE maxseq;


/********************************************************************
**    Deleting the syspar ITEM_RECON_AFTER_DAY_CLS from sys_config
********************************************************************/

DELETE FROM swms.sys_config where CONFIG_FLAG_NAME='ITEM_RECON_AFTER_DAY_CLS';
commit;
/

/********************************************************************
**    Create syspar ITEM_RECON_AFTER_DAY_CLS
********************************************************************/

-- Get the max sequence number used in sys_config table.
SELECT MAX(seq_no) maxseq_no FROM sys_config
/

INSERT INTO SWMS."SYS_CONFIG" 
(SEQ_NO, 
APPLICATION_FUNC, 
CONFIG_FLAG_NAME, 
CONFIG_FLAG_DESC, 
CONFIG_FLAG_VAL, 
VALUE_REQUIRED, 
VALUE_UPDATEABLE, 
VALUE_IS_BOOLEAN, 
DATA_TYPE,DATA_PRECISION, 
SYS_CONFIG_LIST,SYS_CONFIG_HELP, 
VALIDATION_TYPE)
SELECT &maxseq + 1 seq_no, 
'ORDER PROCESSING' APPLICATION_FUNC, 
'ITEM_RECON_AFTER_DAY_CLS'  CONFIG_FLAG_NAME,
'Item recon rpt after day cls'  CONFIG_FLAG_DESC, 
'N'                             CONFIG_FLAG_VAL,
'Y'                             VALUE_REQUIRED, 
'Y'                             VALUE_UPDATEABLE, 
'N'                             VALUE_IS_BOOLEAN, 
'CHAR'                          DATA_TYPE,
'1'                             DATA_PRECISION,
'R'                             SYS_CONFIG_LIST,
'Item recon Report is generated after the day close is done'   SYS_CONFIG_HELP, 
'LIST'                          VALIDATION_TYPE from DUAL
/


INSERT INTO sys_config_valid_values
   (config_flag_name, config_flag_val, description)
SELECT
   'ITEM_RECON_AFTER_DAY_CLS' config_flag_name,
   'N' config_flag_val,
   'Do not generate item recon report after day close. This is default.' description
FROM DUAL
/

INSERT INTO sys_config_valid_values
   (config_flag_name, config_flag_val, description)
SELECT
   'ITEM_RECON_AFTER_DAY_CLS' config_flag_name,
   'Y' config_flag_val,
   'Generate item recon report after day close.' description
FROM DUAL;

commit;
/


