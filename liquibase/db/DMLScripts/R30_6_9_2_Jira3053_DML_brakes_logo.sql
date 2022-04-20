/****************************************************************************
**
** Script to insert a logo type for Brakes into sys_config_valid_values.
** Jira card OPCOF-3053.
**
**                                   
****************************************************************************/

DECLARE
	v_count_1 NUMBER := 0;
	v_count_2 NUMBER := 0;
BEGIN
    SELECT COUNT(*)
    INTO  v_count_1
    FROM  swms.sys_config
    WHERE config_flag_name = 'SYSCO_LOGO_TYPE';

    IF v_count_1 > 0 THEN
        SELECT COUNT(*)
        INTO  v_count_2
        FROM  swms.sys_config_valid_values
        WHERE config_flag_name = 'SYSCO_LOGO_TYPE'
          AND config_flag_val = 'Sysco Brakes';
    
        IF v_count_2 = 0 THEN
            INSERT INTO swms.sys_config_valid_values
                        (config_flag_name, 
                         config_flag_val, 
                         description 
                         ) 
                   VALUES 
                        ('SYSCO_LOGO_TYPE',
                         'Sysco Brakes',
                         'Sysco Logo Type - Sysco Brakes'
                        );

            COMMIT;
        END IF; -- v_count_2
    END IF; -- v_count_1
END;
/

