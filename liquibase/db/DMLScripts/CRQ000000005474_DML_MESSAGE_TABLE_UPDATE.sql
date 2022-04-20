COL maxseq_no NOPRINT NEW_VALUE maxseq;

/**************************************************************************
**    Update message_table for 13106 FOR CRQ000000005474
***************************************************************************/

Update Message_table set v_message = 'Click "Yes" to continue Order Generate. Go to Order Processing, Generation, Missing Batches to retrieve missing batches. Click "No" to stop Order Generation. Pls call in a critical ticket to fix PrintQ'
where id_message = '13106' and id_language = 3;

Update Message_table set v_message = 'Cliquez "Yes" pour continuer. Aller au traitement des commandes-Generation-Missing Batches pour récupérer des lots manquants. Cliquez sur "No" pour arrêtez la génération Ordre. Soulever un billet critique pour fixer printQ'
where id_message = '13106' and id_language = 12;

/* Get the max sequence number used in sys_config table. */

SELECT MAX(PK_ML_MODULES) maxseq_no FROM ml_modules;

Insert into ML_MODULES (PK_ML_MODULES,NAME_FORM,OBJECT_TYPE,NAME_OBJECT,AUX_INFO1,AUX_INFO2,TYPE_FORM) values (&maxseq + 1,'oo1sa',1,'SSL_SAE_WARNING',null,null,10);

Insert into ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT) values (&maxseq + 1,3,3,'Yes');
Insert into ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT) values (&maxseq + 1,3,4,'No');
Insert into ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT) values (&maxseq + 1,12,3,'Oui');
Insert into ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT) values (&maxseq + 1,12,4,'Non');

COMMIT;