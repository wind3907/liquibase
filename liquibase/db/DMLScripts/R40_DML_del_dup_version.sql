/************************************************************************************************
** Date:       22-JAN-2020
** File:       40_DEL_DUP_VERSION_DML.sql
**
** Script to create table
**
** Modification History:
**    Date        Designer           Comments
**    -------- -------- ----------------------------------------------------------------------
**    22-JAN-2020 Karthik Rajan    DML to delete duplicate records in rf_client_version table
**
**************************************************************************************************/

BEGIN

    DELETE FROM rf_client_version
	WHERE
    ROWID NOT IN (
        SELECT
            MAX(ROWID)
        FROM
            rf_client_version
        GROUP BY
            device,
            application,
            client_version
    );

COMMIT;	
END;
/

