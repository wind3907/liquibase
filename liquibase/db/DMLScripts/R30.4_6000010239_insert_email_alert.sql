--------------------------------------------------------------------
-- File Name : DML_swms_email_alert.sql
-- Description : Adding swms notification email alert for SOS_DATA_COLLECT
--
-- Change History:
--    Date     Authour   Description
-- 04-20-16    skam7488  Initial Version
--                       Added a new entry into swms_alert_notification
--------------------------------------------------------------------

Insert into SWMS.SWMS_ALERT_NOTIFICATION
   (MODULES, ERROR_TYPE, CREATE_TICKET, SEND_EMAIL, PRIMARY_RECIPIENT,ALTERNATE_RECIPIENT)
 Values
   ('SOS_DATA_COLLECT', 'CRIT', 'N', 'Y', 'Tehrani.Kaz@corp.sysco.com',NULL);

update swms.message_table set 
v_message = 'Click "No" to continue Order Generate.Go to Order Processing, Generation, Missing Batches to retrieve missing batches. Click "Yes" to stop Order Generation. Pls call in a critical ticket to fix PrintQ'
where id_message = 13106 and id_language = '3' ; 

update swms.message_table set 
v_message = 'Cliquez "NO" pour continuer. Aller au traitement des commandes-Generation-MissingBatches pour récupérer des lots manquants. Cliquez sur "Yes" pour arrêter la génération Ordre. Soulever un billet critique pour fixer printq.'
where id_message = 13106 and id_language = '12' ;

COMMIT;

