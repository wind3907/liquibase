/****************************************************************************
** Date:       18-Oct-2018
** File:       DML_create_sts_routin_alert_notif.sql
**
** Script to insert Initial Alert Notification
**
**
** Modification History:
**    Date        Designer           Comments
**    -------- -------- ---------------------------------------------------
**    18-Oct-2018 mcha1213.     Alert Notification setup 
**
****************************************************************************/
DECLARE
  v_column_exists NUMBER := 0;
BEGIN
  SELECT COUNT(*)
  INTO v_column_exists
  FROM SWMS_ALERT_NOTIFICATION
  WHERE MODULES = 'PL_STS_TO_SWMS'
   and ERROR_TYPE = 'WARN';

IF (v_column_exists = 0)  THEN

Insert into SWMS_ALERT_NOTIFICATION(MODULES,
ERROR_TYPE,
CREATE_TICKET,
SEND_EMAIL,
PRIMARY_RECIPIENT,
ALTERNATE_RECIPIENT) 
Values('PL_STS_TO_SWMS', 
'WARN',
'N',
'Y', 
'000-IT-APPDEV-SWMS@corp.sysco.com', 
'000-IT-APPDEV-SWMS@corp.sysco.com');
COMMIT;
End If;
End;
/	