REM
REM User--ELAINE on 10/05/2017 09:40 generated script to insert tables: ML_MODULES and ML_VALUES
PROMPT *** Insert PK: 102146   Form/Menu: batches  ***
Insert into SWMS.ML_MODULES (PK_ML_MODULES,NAME_FORM,OBJECT_TYPE,NAME_OBJECT,AUX_INFO1,AUX_INFO2,TYPE_FORM) 
 Select 102146,'batches',13,'LXLI_GOAL_UPD_TIME','BATCH',NULL,10 from dual 
 Where not exists (select 1 from ml_modules m2 where m2.pk_ml_modules = 102146);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102146,3,6,'' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102146 and m2.id_language=3 and m2.id_functionality=6);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102146,12,6,'' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102146 and m2.id_language=12 and m2.id_functionality=6);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102146,3,7,'Received Goal Time From Flex' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102146 and m2.id_language=3 and m2.id_functionality=7);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102146,12,7,'??Ca-Fr-Received Goal Time From Flex' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102146 and m2.id_language=12 and m2.id_functionality=7);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102146,3,8,'Received Goal Time From Flex' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102146 and m2.id_language=3 and m2.id_functionality=8);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102146,12,8,'??Ca-Fr-Received Goal Time From Flex' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102146 and m2.id_language=12 and m2.id_functionality=8);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102146,3,15,'Received Goal Time 
From Flex' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102146 and m2.id_language=3 and m2.id_functionality=15);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102146,12,15,'Objectif recu 
temps de Flex' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102146 and m2.id_language=12 and m2.id_functionality=15);
PROMPT *** Insert PK: 102149   Form/Menu: batches  ***
Insert into SWMS.ML_MODULES (PK_ML_MODULES,NAME_FORM,OBJECT_TYPE,NAME_OBJECT,AUX_INFO1,AUX_INFO2,TYPE_FORM) 
 Select 102149,'batches',13,'LXLI_SEND_TIME1','BATCH',NULL,10 from dual 
 Where not exists (select 1 from ml_modules m2 where m2.pk_ml_modules = 102149);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102149,3,6,'' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102149 and m2.id_language=3 and m2.id_functionality=6);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102149,12,6,'' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102149 and m2.id_language=12 and m2.id_functionality=6);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102149,3,7,'Sent Time from 
SWMS to Flex' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102149 and m2.id_language=3 and m2.id_functionality=7);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102149,12,7,'??Ca-Fr-Sent Time from SWMS to Flex' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102149 and m2.id_language=12 and m2.id_functionality=7);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102149,3,8,'Sent Time from SWMS to Flex' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102149 and m2.id_language=3 and m2.id_functionality=8);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102149,12,8,'??Ca-Fr-Sent Time from SWMS to Flex' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102149 and m2.id_language=12 and m2.id_functionality=8);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102149,3,15,'Sent Time From 
SWMS to Flex' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102149 and m2.id_language=3 and m2.id_functionality=15);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102149,12,15,'Envoye le temps 
de SWM pour Flex' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102149 and m2.id_language=12 and m2.id_functionality=15);
PROMPT *** Insert PK: 102151   Form/Menu: batches  ***
Insert into SWMS.ML_MODULES (PK_ML_MODULES,NAME_FORM,OBJECT_TYPE,NAME_OBJECT,AUX_INFO1,AUX_INFO2,TYPE_FORM) 
 Select 102151,'batches',13,'SENT_TO_LXLI_IND','CONTROL',NULL,10 from dual 
 Where not exists (select 1 from ml_modules m2 where m2.pk_ml_modules = 102151);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102151,3,6,'' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102151 and m2.id_language=3 and m2.id_functionality=6);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102151,12,6,'' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102151 and m2.id_language=12 and m2.id_functionality=6);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102151,3,7,'Sent From SWMS To Flex? (Y/N)' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102151 and m2.id_language=3 and m2.id_functionality=7);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102151,12,7,'??Ca-Fr-Sent From SWMS To Flex? (Y/N)' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102151 and m2.id_language=12 and m2.id_functionality=7);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102151,3,8,'Sent From SWMS To Flex? (Y/N)' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102151 and m2.id_language=3 and m2.id_functionality=8);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102151,12,8,'??Ca-Fr-Sent From SWMS To Flex? (Y/N)' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102151 and m2.id_language=12 and m2.id_functionality=8);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102151,3,15,'Sent From SWMS To Flex? (Y/N)' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102151 and m2.id_language=3 and m2.id_functionality=15);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102151,12,15,'Envoye de SWM en Flex ? (O/N)' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102151 and m2.id_language=12 and m2.id_functionality=15);
PROMPT *** Insert PK: 102153   Form/Menu: batches  ***
Insert into SWMS.ML_MODULES (PK_ML_MODULES,NAME_FORM,OBJECT_TYPE,NAME_OBJECT,AUX_INFO1,AUX_INFO2,TYPE_FORM) 
 Select 102153,'batches',13,'GOALTIME_RECIEVED_IND','CONTROL',NULL,10 from dual 
 Where not exists (select 1 from ml_modules m2 where m2.pk_ml_modules = 102153);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102153,3,6,'' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102153 and m2.id_language=3 and m2.id_functionality=6);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102153,12,6,'' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102153 and m2.id_language=12 and m2.id_functionality=6);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102153,3,7,'Goal Time Received From Flex? (Y/N)' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102153 and m2.id_language=3 and m2.id_functionality=7);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102153,12,7,'??Ca-Fr-Goal Time Received From Flex? (Y/N)' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102153 and m2.id_language=12 and m2.id_functionality=7);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102153,3,8,'Goal Time Received From Flex? (Y/N)' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102153 and m2.id_language=3 and m2.id_functionality=8);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102153,12,8,'??Ca-Fr-Goal Time Received From Flex? (Y/N)' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102153 and m2.id_language=12 and m2.id_functionality=8);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102153,3,15,'Goal Time Received From Flex? (Y/N)' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102153 and m2.id_language=3 and m2.id_functionality=15);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102153,12,15,'Objectif temps recu de Flex ? (O/N)' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102153 and m2.id_language=12 and m2.id_functionality=15);
COMMIT;
