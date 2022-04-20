/****************************************************************************
** Date:       25-APR-2016
** File:       6000009429_dml_sts_build_fix.sql
**
** Script to insert information for table: CROSS_DOCK_TYPE created as part of 
**		European Imports integration and Updating alert notification for SOS_DATA_COLLECT
**
**
** Modification History:
**    Date     Designer Comments
**    -------- -------- ---------------------------------------------------
**    25/05/16 spot3255 Created DML script
**
****************************************************************************/
INSERT INTO SWMS.CROSS_DOCK_TYPE
   (CROSS_DOCK_TYPE, RECEIVE_WHOLE_PALLET, DESCRIPTION)
 VALUES
   ('EI', 'N', 'Cross dock pallets');

UPDATE SWMS.SWMS_ALERT_NOTIFICATION
   SET PRIMARY_RECIPIENT = NULL
 WHERE MODULES = 'SOS_DATA_COLLECT';

COMMIT;
