/****************************************************************************
** Date:       11-Jun-2016
** File:       6000009943_dml_update_alert_notification.sql
**
** Update SWMS alert notification 
**
** Records updated into table:
**    - swms_alert_notification
**
** Modification History:
**    Date     Developer Comments
**    -------- --------  ---------------------------------------------------
**    06/11/16 skam7488  Initial version created. Charm 6000009943
****************************************************************************/

update swms_alert_notification set send_email = 'N'
where  modules in ('MINILOAD_EXCEPTION','PL_AUTO_ROUTE_CLOSE','COLLECTDATA','PAECW','SOS_DATA_COLLECT');

COMMIT;

