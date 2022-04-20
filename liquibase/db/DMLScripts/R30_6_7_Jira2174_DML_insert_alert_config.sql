/******************************************************************************
**
** Script to insert row into swms_alert_notification.
** Jira card #2174
**
*******************************************************************************/

DECLARE
	v_row_count NUMBER := 0;
BEGIN
    SELECT COUNT(*)
    INTO  v_row_count
    FROM  swms.swms_alert_notification
    WHERE modules = 'PO_EMAIL_ALERT'
      AND error_type = 'WARN';
    
    IF v_row_count = 0 THEN
       INSERT INTO swms.swms_alert_notification 
                     (modules, error_type, create_ticket, send_email, primary_recipient, alternate_recipient)
              VALUES 
                     ('PO_EMAIL_ALERT', 'WARN', 'N', 'Y', 'kabran.patrice@corp.sysco.com', NULL);

        COMMIT;
    END IF;
END;
/

