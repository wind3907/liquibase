/****************************************************************************
** File: JIRA613_DML_syspar_cc_group_sort_ny1ra.sql
**
** Desc: Script to add syspar CC_GROUP_SORT_NY1RA for sorting the report NY1RA by PIK/PUT slot
**        
**
** Modification History:
**    Date      Designer           Comments
**  ---------- ---------- -----------------------------------------
**  15-Oct-2018 sban3548   Intial script to create syspar CC_GROUP_SORT_NY1RA
**                                   
****************************************************************************/

DECLARE
	v_row_count NUMBER := 0;
BEGIN
    SELECT COUNT(*)
    INTO  v_row_count
    FROM  swms.sys_config
    WHERE config_flag_name = 'CC_GROUP_SORT_NY1RA';
    
    IF v_row_count = 0 THEN
        INSERT INTO swms.sys_config
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
                     sys_config_list, 
                     sys_config_help,
                     validation_type,
                     range_low, 
                     range_high) 
               SELECT MAX(seq_no)+1 seq_no,
                     'CYCLE COUNT',          --	application_func,
                     'CC_GROUP_SORT_NY1RA'  config_flag_name,
                     'CC report NY1RA Group Sort'   config_flag_desc,
                     'PIK'	config_flag_val,
                     'Y'	value_required,
                     'Y'	value_updateable,
                     'N'	value_is_boolean,
                     'CHAR'	data_type,
                     3		data_precision,
                     'L'	sys_config_list, 
                     'Cycle Count Assignment Report is usually sorted by Pick slot by default (PIK). 
                            or it can be sorted by Put slot (PUT)'	sys_config_help,
                     'LIST'	validation_type,
                     NULL,
                     NULL 
                FROM swms.sys_config;

		INSERT INTO SYS_CONFIG_VALID_VALUES
		   (CONFIG_FLAG_NAME, CONFIG_FLAG_VAL, DESCRIPTION)
		VALUES
		   ('CC_GROUP_SORT_NY1RA', 'PIK', 'Sort by Pick slot');

		INSERT INTO SYS_CONFIG_VALID_VALUES
		   (CONFIG_FLAG_NAME, CONFIG_FLAG_VAL, DESCRIPTION)
		VALUES
		   ('CC_GROUP_SORT_NY1RA', 'PUT', 'Sort by Put slot');

        COMMIT;
    END IF;
END;
/

