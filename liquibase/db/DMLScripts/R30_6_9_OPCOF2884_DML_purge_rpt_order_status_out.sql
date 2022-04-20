/****************************************************************************************
** Desc: Script to Add rpt_order_status_out to purge table 
**
** Modification History:
**    Date          Designer           Comments
**    -----------  --------     ---------------------------------------------------------
**    19/03/2020    sban3548    Jira-2884: added rpt_order_status_out table to purge data
**
*****************************************************************************************/

DECLARE
	v_row_count NUMBER := 0;
BEGIN
    SELECT COUNT(*)
    INTO  v_row_count
    FROM  swms.sap_interface_purge
    WHERE table_name = 'RPT_ORDER_STATUS_OUT';

    IF v_row_count = 0 THEN
		INSERT INTO swms.sap_interface_purge 
					(table_name,
					retention_days,
					description) 
			VALUES ('RPT_ORDER_STATUS_OUT', 
					7 ,
					'Staging table for order line item status');
        COMMIT;
    END IF;
END;
/
