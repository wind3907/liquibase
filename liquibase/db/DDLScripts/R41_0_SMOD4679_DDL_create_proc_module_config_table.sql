/****************************************************************************
** Date:       28-Jul-2020
** File:       PROC_MODULE_CONFIG.sql
**
** Script to create table
**
**
** Modification History:
**    Date        Designer    Comments
**    --------    --------     ---------------------------------------------
**    28-Jul-2020 ADIS5789    Table creation  for PROC_MODULE_CONFIG table
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
            table_name = 'PROC_MODULE_CONFIG';

    EXCEPTION
        WHEN OTHERS THEN
            v_exists := 1;
    END;

    IF ( v_exists = 0 ) THEN
        EXECUTE IMMEDIATE 'CREATE TABLE PROC_MODULE_CONFIG(	
	PROC_MODULE VARCHAR2(50 CHAR) NOT NULL , 
	PLSQL_PACKAGE VARCHAR2(50 CHAR) NOT NULL , 
	ENABLED VARCHAR2(1 CHAR) NOT NULL,
    ITERATION NUMBER(2),
    CONSTRAINT PK_PROC_MODULE_CONFIG PRIMARY KEY (PROC_MODULE))'
        ;
        EXECUTE IMMEDIATE 'GRANT ALL ON PROC_MODULE_CONFIG to swms_user';
    END IF;
END;
/
