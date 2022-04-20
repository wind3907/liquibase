/****************************************************************************
** Date:       01/05/2017
** Programmer: Elaine Zheng
** File:       CRQ000000018983_SysPar_Unitize_ind.sql
** Defect#:    xxx
** Ticket:     xxx
** Project:
**
** Modification History:
**    Date     Designer Comments
**    -------- -------- ---------------------------------------------------
**    01/025/2017 xzhe5043 Created
**
****************************************************************************/


/********************************************************************
**    Insert the syspars
********************************************************************/

COL maxseq_no NOPRINT NEW_VALUE maxseq;


/********************************************************************
**    Create sypar full_plt_minimize_option_clr
********************************************************************/
/* Get the max sequence number used in sys_config table. */
SELECT MAX(seq_no) maxseq_no FROM sys_config
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
    validation_type,
    range_low,
    range_high,
    sys_config_help)
SELECT
     &maxseq + 1 seq_no,
   'ORDER_PROCESSING'                application_func, 
   'UNITIZE_IND'                     config_flag_name,
   'Make 1st Stop Unitized'           config_flag_desc,
   'N'                                 config_flag_val,
   'N'                                 value_required,
   'Y'                                 value_updateable,
   'Y'                                 value_is_boolean,
   'CHAR'                              data_type,
   1                                   data_precision,
   0                                   data_scale,
   'L'                                 sys_config_list,
   'LIST'                              validation_type,
   NULL                                range_low,
   NULL                                range_high,
'Turn on or off for the Unitize Indicator of the 1st stop
------------------------------------------------------------------------
This syspar designates that when generating the routes if OPCO would like 
to turn on or off the unitize indicator for the 1st stop.'
|| chr(10) || chr(10) ||
'The valid values for this syspar are:
Value  Effect
-----  --------------------------------------------------------------
  Y    Turn on Unitize Indicator for Stop 1 of the routes.
  N    NOT Turn on Unitize Indicator for Stop 1 of the routes.' sys_config_help
 FROM DUAL
WHERE NOT EXISTS ( SELECT 1
 FROM sys_config WHERE config_flag_name='UNITIZE_IND')
/
INSERT INTO sys_config_valid_values
   (config_flag_name, config_flag_val, description)
SELECT
   'UNITIZE_IND' config_flag_name,
   'Y'                            config_flag_val,
   'Turn on Unitize Indicator for Stop 1 of the routes'        description
FROM DUAL
WHERE NOT EXISTS ( SELECT 1
 FROM sys_config_valid_values WHERE config_flag_name='UNITIZE_IND'
  AND config_flag_val = 'Y' )
/
INSERT INTO sys_config_valid_values
   (config_flag_name, config_flag_val, description)
SELECT
   'UNITIZE_IND'     config_flag_name,
   'N'                                config_flag_val,
   'Not Turn on Unitize Indicator for Stop 1 of the routes' description
FROM DUAL
WHERE NOT EXISTS ( SELECT 1
 FROM sys_config_valid_values WHERE config_flag_name='UNITIZE_IND'
  AND config_flag_val = 'N' )
/


