/**********************************************************************************************
** Desc: Script to Add GS1_OUT table name to purge table 
**
** Modification History:
**    Date          Designer           Comments
**    -----------  --------     --------------------------------------------------------------
**    08/04/2021    SRAJ8407   : added GS1_OUT table name to sap_interface_purge table for CFA
**
*************************************************************************************************/

DECLARE
	v_row_count NUMBER := 0;
BEGIN
    SELECT COUNT(*)
    INTO  v_row_count
    FROM  swms.sap_interface_purge
    WHERE table_name = 'GS1_OUT';

    IF v_row_count = 0 THEN
		INSERT INTO SWMS.SAP_INTERFACE_PURGE
   (		TABLE_NAME, RETENTION_DAYS, DESCRIPTION, UPD_USER, UPD_DATE)
		VALUES
			('GS1_OUT', 20, 'Purge old GS1 data from SWMS ', 'SWMS', sysdate);
        COMMIT;
    END IF;
END;
/
