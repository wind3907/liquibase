/****************************************************************************
** Date:       11-MAR-2020
** File:       40_API_CONFIG_DDL.sql
**
** Script to create table
**
**
** Modification History:
**    Date        Designer    Comments
**    --------    --------     ---------------------------------------------
**    11-MAR-2020 SRAJ8407    Table creation  for api_config
**
****************************************************************************/

DECLARE
    v_exists   NUMBER := 0;
BEGIN
    BEGIN
        SELECT
            COUNT(*)
        INTO v_exists
        FROM
            user_tables
        WHERE
            table_name = 'API_CONFIG';

    EXCEPTION
        WHEN OTHERS THEN
            v_exists := 1;
    END;

    IF ( v_exists = 0 ) THEN
        EXECUTE IMMEDIATE 'CREATE TABLE API_CONFIG(
						APPLICATION_FUNC VARCHAR2(24 CHAR) NOT NULL,
						API_NAME VARCHAR2(30 CHAR) NOT NULL,
						API_DESC VARCHAR2(50 CHAR) NOT NULL,
						API_VAL VARCHAR2(100 CHAR) NOT NULL,
						API_ENABLED VARCHAR2(1 CHAR) NOT NULL
				)';
				EXECUTE IMMEDIATE 'GRANT ALL ON API_CONFIG to swms_user';
    END IF;
END;
/
