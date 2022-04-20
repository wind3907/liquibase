REM
REM User--ELAINE on 10/05/2017 09:43 generated script to insert tables: ML_MODULES and ML_VALUES
PROMPT *** Insert PK: 102155   Form/Menu: arch_batch  ***
Insert into SWMS.ML_MODULES (PK_ML_MODULES,NAME_FORM,OBJECT_TYPE,NAME_OBJECT,AUX_INFO1,AUX_INFO2,TYPE_FORM) 
 Select 102155,'arch_batch',13,'SENT_TO_LXLI_IND','CONTROL',NULL,10 from dual 
 Where not exists (select 1 from ml_modules m2 where m2.pk_ml_modules = 102155);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102155,3,6,'' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102155 and m2.id_language=3 and m2.id_functionality=6);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102155,12,6,'' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102155 and m2.id_language=12 and m2.id_functionality=6);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102155,3,7,'Sent From SWMS To Flex? (Y/N)' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102155 and m2.id_language=3 and m2.id_functionality=7);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102155,12,7,'??Ca-Fr-Sent From SWMS To Flex? (Y/N)' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102155 and m2.id_language=12 and m2.id_functionality=7);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102155,3,8,'Sent From SWMS To Flex? (Y/N)' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102155 and m2.id_language=3 and m2.id_functionality=8);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102155,12,8,'??Ca-Fr-Sent From SWMS To Flex? (Y/N)' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102155 and m2.id_language=12 and m2.id_functionality=8);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102155,3,15,'Sent From SWMS To Flex? (Y/N)' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102155 and m2.id_language=3 and m2.id_functionality=15);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102155,12,15,'Envoye de SWM en Flex ? (O/N)' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102155 and m2.id_language=12 and m2.id_functionality=15);
PROMPT *** Insert PK: 102162   Form/Menu: arch_batch  ***
Insert into SWMS.ML_MODULES (PK_ML_MODULES,NAME_FORM,OBJECT_TYPE,NAME_OBJECT,AUX_INFO1,AUX_INFO2,TYPE_FORM) 
 Select 102162,'arch_batch',13,'GOALTIME_RECIEVED_IND','CONTROL',NULL,10 from dual 
 Where not exists (select 1 from ml_modules m2 where m2.pk_ml_modules = 102162);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102162,3,6,'' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102162 and m2.id_language=3 and m2.id_functionality=6);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102162,12,6,'' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102162 and m2.id_language=12 and m2.id_functionality=6);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102162,3,7,'Goal Time Received From Flex? (Y/N)' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102162 and m2.id_language=3 and m2.id_functionality=7);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102162,12,7,'??Ca-Fr-Goal Time Received From Flex? (Y/N)' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102162 and m2.id_language=12 and m2.id_functionality=7);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102162,3,8,'Goal Time Received From Flex? (Y/N)' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102162 and m2.id_language=3 and m2.id_functionality=8);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102162,12,8,'??Ca-Fr-Goal Time Received From Flex? (Y/N)' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102162 and m2.id_language=12 and m2.id_functionality=8);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102162,3,15,'Goal Time Received From Flex? (Y/N)' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102162 and m2.id_language=3 and m2.id_functionality=15);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102162,12,15,'Objectif temps recu de Flex ? (O/N)' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102162 and m2.id_language=12 and m2.id_functionality=15);
PROMPT *** Insert PK: 102164   Form/Menu: arch_batch  ***
Insert into SWMS.ML_MODULES (PK_ML_MODULES,NAME_FORM,OBJECT_TYPE,NAME_OBJECT,AUX_INFO1,AUX_INFO2,TYPE_FORM) 
 Select 102164,'arch_batch',13,'LXLI_SEND_TIME1','BATCH',NULL,10 from dual 
 Where not exists (select 1 from ml_modules m2 where m2.pk_ml_modules = 102164);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102164,3,6,'' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102164 and m2.id_language=3 and m2.id_functionality=6);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102164,12,6,'' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102164 and m2.id_language=12 and m2.id_functionality=6);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102164,3,7,'Sent Time From SWMS To Flex' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102164 and m2.id_language=3 and m2.id_functionality=7);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102164,12,7,'??Ca-Fr-Sent Time From SWMS To Flex' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102164 and m2.id_language=12 and m2.id_functionality=7);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102164,3,8,'Sent Time From SWMS To Flex' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102164 and m2.id_language=3 and m2.id_functionality=8);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102164,12,8,'??Ca-Fr-Sent Time From SWMS To Flex' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102164 and m2.id_language=12 and m2.id_functionality=8);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102164,3,15,'Sent Time From 
SWMS To Flex' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102164 and m2.id_language=3 and m2.id_functionality=15);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102164,12,15,'Envoye le temps 
de SWM pour Flex' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102164 and m2.id_language=12 and m2.id_functionality=15);
PROMPT *** Insert PK: 102166   Form/Menu: arch_batch  ***
Insert into SWMS.ML_MODULES (PK_ML_MODULES,NAME_FORM,OBJECT_TYPE,NAME_OBJECT,AUX_INFO1,AUX_INFO2,TYPE_FORM) 
 Select 102166,'arch_batch',13,'LXLI_GOAL_UPD_TIME','BATCH',NULL,10 from dual 
 Where not exists (select 1 from ml_modules m2 where m2.pk_ml_modules = 102166);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102166,3,6,'' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102166 and m2.id_language=3 and m2.id_functionality=6);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102166,12,6,'' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102166 and m2.id_language=12 and m2.id_functionality=6);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102166,3,7,'Received Goal Time From Flex' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102166 and m2.id_language=3 and m2.id_functionality=7);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102166,12,7,'??Ca-Fr-Received Goal Time From Flex' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102166 and m2.id_language=12 and m2.id_functionality=7);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102166,3,8,'Received Goal Time From Flex' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102166 and m2.id_language=3 and m2.id_functionality=8);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102166,12,8,'??Ca-Fr-Received Goal Time From Flex' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102166 and m2.id_language=12 and m2.id_functionality=8);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102166,3,15,'Received Goal Time 
From Flex' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102166 and m2.id_language=3 and m2.id_functionality=15);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102166,12,15,'Objectif recu fois 
Partir de Flex' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102166 and m2.id_language=12 and m2.id_functionality=15);
COMMIT;
