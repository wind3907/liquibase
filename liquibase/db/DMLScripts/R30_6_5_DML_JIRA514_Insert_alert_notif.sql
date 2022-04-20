/******************************************************************
*  Insert_alert_notification 
*  for Sales Order Not Shipped Report email address 
*  The default value will be null, so user can add email addresses
*  07/30/2018 xzhe5043
******************************************************************/ 
DECLARE
v_row_count NUMBER := 0;
BEGIN
    SELECT COUNT(*)
     INTO  v_row_count
      from swms_alert_notification     
      WHERE modules='SO_NOT_SHIPPED_RPT';
	  
    IF v_row_count = 0 THEN	  
		Insert into swms.swms_alert_notification
		(MODULES,ERROR_TYPE,CREATE_TICKET,SEND_EMAIL,PRIMARY_RECIPIENT,ALTERNATE_RECIPIENT) 
		values ('SO_NOT_SHIPPED_RPT','INFO','N','N',NULL,NULL);
     End If;
  commit;
END;
/