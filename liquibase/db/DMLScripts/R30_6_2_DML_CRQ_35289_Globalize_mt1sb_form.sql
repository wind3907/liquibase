REM
REM User--MICHAEL on 09/21/2017 15:28 generated script to insert tables: ML_MODULES and ML_VALUES
PROMPT *** Insert PK: 102198   Form/Menu: mt1sb  ***
Insert into SWMS.ML_MODULES (PK_ML_MODULES,NAME_FORM,OBJECT_TYPE,NAME_OBJECT,AUX_INFO1,AUX_INFO2,TYPE_FORM) 
 Select 102198,'mt1sb',13,'TASK_PRIORITY','MASTER',NULL,10 from dual 
 Where not exists (select 1 from ml_modules m2 where m2.pk_ml_modules = 102198);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102198,3,6,'' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102198 and m2.id_language=3 and m2.id_functionality=6);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102198,12,6,'' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102198 and m2.id_language=12 and m2.id_functionality=6);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102198,3,7,'Replenishment task priority' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102198 and m2.id_language=3 and m2.id_functionality=7);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102198,12,7,'?Fr-Replenishment task priority' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102198 and m2.id_language=12 and m2.id_functionality=7);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102198,3,8,'' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102198 and m2.id_language=3 and m2.id_functionality=8);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102198,12,8,'' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102198 and m2.id_language=12 and m2.id_functionality=8);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102198,3,15,'Task Priority' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102198 and m2.id_language=3 and m2.id_functionality=15);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102198,12,15,'Priorité de tâche:' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102198 and m2.id_language=12 and m2.id_functionality=15);

PROMPT *** Insert PK: 102199   Form/Menu: mt1sb  ***
Insert into SWMS.ML_MODULES (PK_ML_MODULES,NAME_FORM,OBJECT_TYPE,NAME_OBJECT,AUX_INFO1,AUX_INFO2,TYPE_FORM) 
 Select 102199,'mt1sb',13,'SUGGESTED_TASK_PRIORITY','MASTER',NULL,10 from dual 
 Where not exists (select 1 from ml_modules m2 where m2.pk_ml_modules = 102199);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102199,3,6,'' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102199 and m2.id_language=3 and m2.id_functionality=6);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102199,12,6,'' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102199 and m2.id_language=12 and m2.id_functionality=6);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102199,3,7,'This is the highest priority replenishment task that was displayed on the RF when the user performed a task off the list.' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102199 and m2.id_language=3 and m2.id_functionality=7);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102199,12,7,'?Fr-This is the highest priority replenishment task that was displayed on the RF when the user performed a task off the list.' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102199 and m2.id_language=12 and m2.id_functionality=7);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102199,3,8,'' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102199 and m2.id_language=3 and m2.id_functionality=8);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102199,12,8,'' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102199 and m2.id_language=12 and m2.id_functionality=8);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102199,3,15,'Highest Task Priority:' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102199 and m2.id_language=3 and m2.id_functionality=15);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102199,12,15,'Priorité maximale:' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102199 and m2.id_language=12 and m2.id_functionality=15);

PROMPT *** Insert PK: 102200   Form/Menu: mt1sb  ***
Insert into SWMS.ML_MODULES (PK_ML_MODULES,NAME_FORM,OBJECT_TYPE,NAME_OBJECT,AUX_INFO1,AUX_INFO2,TYPE_FORM) 
 Select 102200,'mt1sb',13,'REPLEN_CREATION_TYPE','MASTER',NULL,10 from dual 
 Where not exists (select 1 from ml_modules m2 where m2.pk_ml_modules = 102200);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102200,3,6,'' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102200 and m2.id_language=3 and m2.id_functionality=6);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102200,12,6,'' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102200 and m2.id_language=12 and m2.id_functionality=6);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102200,3,7,'This is the 1 character "code" of what action created the non-demand replenishment for a non-demand RPL transaction.' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102200 and m2.id_language=3 and m2.id_functionality=7);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102200,12,7,'?Fr-This is the 1 character "code" of what action created the non-demand replenishment for a non-demand RPL transaction.' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102200 and m2.id_language=12 and m2.id_functionality=7);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102200,3,8,'' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102200 and m2.id_language=3 and m2.id_functionality=8);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102200,12,8,'' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102200 and m2.id_language=12 and m2.id_functionality=8);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102200,3,15,'Replen Created By:' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102200 and m2.id_language=3 and m2.id_functionality=15);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102200,12,15,'Réapro créé par:' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102200 and m2.id_language=12 and m2.id_functionality=15);
COMMIT;
