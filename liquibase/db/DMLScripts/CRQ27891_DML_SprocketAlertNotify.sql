/****************************************************************************
** Date:       05-May-2017
** File:       SprocketAlertNotifyDML.sql
**
** Script to insert Initial Alert Notification
**
**
** Modification History:
**    Date        Designer           Comments
**    -------- -------- ---------------------------------------------------
**    18-May-2017 Vishnupriya K.     Alert Notification setup 
**
****************************************************************************/
DECLARE
  v_column_exists NUMBER := 0;
BEGIN
  SELECT COUNT(*)
  INTO v_column_exists
  FROM SWMS_ALERT_NOTIFICATION
  WHERE MODULES = 'PL_SWMS_TO_SPROCKET'
   and ERROR_TYPE = 'WARN';

IF (v_column_exists = 0)  THEN

Insert into SWMS_ALERT_NOTIFICATION(MODULES,
ERROR_TYPE,
CREATE_TICKET,
SEND_EMAIL,
PRIMARY_RECEIPIENT,
ALTERNATE_RECEIPIENT) 
Values('PL_SWMS_TO_SPROCKET', 
'WARN',
'N',
'Y', 
'000-IT-APPDEV-SWMS@corp.sysco.com', 
'000-IT-APPDEV-SWMS@corp.sysco.com');
COMMIT;
End If;
End;	