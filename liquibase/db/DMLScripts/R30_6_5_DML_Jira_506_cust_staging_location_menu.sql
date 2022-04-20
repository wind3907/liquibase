REM
REM User--SARA on 07/13/2018 16:34 generated script to insert tables: ML_MODULES and ML_VALUES
PROMPT *** Insert PK: 102298   Form/Menu: ZONE_MENU  ***
SET DEFINE OFF;
Insert into SWMS.ML_MODULES (PK_ML_MODULES,NAME_FORM,OBJECT_TYPE,NAME_OBJECT,AUX_INFO1,AUX_INFO2,TYPE_FORM) 
 Select 102298,'ZONE_MENU',18,'NEW','MR1CS',NULL,19 from dual 
 Where not exists (select 1 from ml_modules m2 where m2.pk_ml_modules = 102298);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102298,3,14,'New' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102298 and m2.id_language=3 and m2.id_functionality=14);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102298,12,14,'Nouveau' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102298 and m2.id_language=12 and m2.id_functionality=14);
PROMPT *** Insert PK: 102299   Form/Menu: ZONE_MENU  ***
Insert into SWMS.ML_MODULES (PK_ML_MODULES,NAME_FORM,OBJECT_TYPE,NAME_OBJECT,AUX_INFO1,AUX_INFO2,TYPE_FORM) 
 Select 102299,'ZONE_MENU',18,'DELETE','MR1CS',NULL,19 from dual 
 Where not exists (select 1 from ml_modules m2 where m2.pk_ml_modules = 102299);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102299,3,14,'Delete' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102299 and m2.id_language=3 and m2.id_functionality=14);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102299,12,14,'Supprimer' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102299 and m2.id_language=12 and m2.id_functionality=14);
PROMPT *** Insert PK: 102300   Form/Menu: ZONE_MENU  ***
Insert into SWMS.ML_MODULES (PK_ML_MODULES,NAME_FORM,OBJECT_TYPE,NAME_OBJECT,AUX_INFO1,AUX_INFO2,TYPE_FORM) 
 Select 102300,'ZONE_MENU',18,'EXIT','MR1CS',NULL,19 from dual 
 Where not exists (select 1 from ml_modules m2 where m2.pk_ml_modules = 102300);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102300,3,14,'Exit' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102300 and m2.id_language=3 and m2.id_functionality=14);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102300,12,14,'Quitter' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102300 and m2.id_language=12 and m2.id_functionality=14);
PROMPT *** Insert PK: 102317   Form/Menu: SYSCO_MENU  ***
Insert into SWMS.ML_MODULES (PK_ML_MODULES,NAME_FORM,OBJECT_TYPE,NAME_OBJECT,AUX_INFO1,AUX_INFO2,TYPE_FORM) 
 Select 102317,'SYSCO_MENU',18,'RCV_CONFIG','MAINTENANCE',NULL,19 from dual 
 Where not exists (select 1 from ml_modules m2 where m2.pk_ml_modules = 102317);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102317,3,14,'Rc&v Config' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102317 and m2.id_language=3 and m2.id_functionality=14);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102317,12,14,'Rc & v Config' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102317 and m2.id_language=12 and m2.id_functionality=14);
PROMPT *** Insert PK: 102318   Form/Menu: SYSCO_MENU  ***
Insert into SWMS.ML_MODULES (PK_ML_MODULES,NAME_FORM,OBJECT_TYPE,NAME_OBJECT,AUX_INFO1,AUX_INFO2,TYPE_FORM) 
 Select 102318,'SYSCO_MENU',18,'CUST_STG_LOC','RCV_CONF_MENU',NULL,19 from dual 
 Where not exists (select 1 from ml_modules m2 where m2.pk_ml_modules = 102318);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102318,3,14,'Cust Staging Loc' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102318 and m2.id_language=3 and m2.id_functionality=14);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102318,12,14,'Cust Staging Loc' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102318 and m2.id_language=12 and m2.id_functionality=14);
COMMIT;
