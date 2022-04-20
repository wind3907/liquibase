/****************************************************************************
** File:       SWMS_RT_BACKOUT_MSG_DML.sql
**
** Desc: Script to update msg for RT_BACKOUT
**
**
** Modification History:
**    Date        Designer           Comments
**    -------- -------- ----------------------------------------------------
**    17-Dec-2019 Vishnupriya K.     MSG for RT_BACKOUT 
**    
****************************************************************************/

 update Message_table
 set v_message = 'Route Delete transaction, BRT has been sent to host system ( SUS / IDS / SAP /NAV)'
 where ID_MESSAGE = '13103'
 and ID_LANGUAGE ='3';

Commit;					  