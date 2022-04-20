/****************************************************************************
** Date:       22-JAN-2020
** File:       40_DROP_HOST_COL_DDL.sql
**
** Script to create table
**
** Modification History:
**    Date        Designer           Comments
**    -------- -------- --------------------------------------------------------------
**    22-JAN-2020 Karthik Rajan    Drop column HOST from table RF_CLIENT_VERSION
**
***************************************************************************************/
DECLARE
    v_column NUMBER := 0;
BEGIN
    
	 SELECT
            COUNT(*)
        INTO v_column
        FROM
            user_tab_columns
        WHERE
            table_name = 'RF_CLIENT_VERSION'
            AND column_name = 'HOST';

        IF ( v_column = 1 ) THEN
		    EXECUTE IMMEDIATE 'ALTER TABLE RF_CLIENT_VERSION DROP CONSTRAINT RF_CLIENT_VERSION_PK';
            EXECUTE IMMEDIATE 'ALTER TABLE RF_CLIENT_VERSION DROP COLUMN HOST';
        END IF;
END;
/

