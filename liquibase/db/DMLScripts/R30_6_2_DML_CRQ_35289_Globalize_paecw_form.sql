REM
REM User--MICHAEL on 09/22/2017 11:14 generated script to insert tables: ML_MODULES and ML_VALUES
PROMPT *** Insert PK: 102190   Form/Menu: paecw  ***
Insert into SWMS.ML_MODULES (PK_ML_MODULES,NAME_FORM,OBJECT_TYPE,NAME_OBJECT,AUX_INFO1,AUX_INFO2,TYPE_FORM) 
 Select 102190,'paecw',13,'CW_KG_LB','ORDCW_1',NULL,10 from dual 
 Where not exists (select 1 from ml_modules m2 where m2.pk_ml_modules = 102190);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102190,3,6,'' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102190 and m2.id_language=3 and m2.id_functionality=6);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102190,12,6,'' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102190 and m2.id_language=12 and m2.id_functionality=6);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102190,3,7,'' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102190 and m2.id_language=3 and m2.id_functionality=7);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102190,12,7,'' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102190 and m2.id_language=12 and m2.id_functionality=7);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102190,3,8,'' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102190 and m2.id_language=3 and m2.id_functionality=8);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102190,12,8,'' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102190 and m2.id_language=12 and m2.id_functionality=8);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102190,3,15,'Catchweight' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102190 and m2.id_language=3 and m2.id_functionality=15);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102190,12,15,'Poids variable' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102190 and m2.id_language=12 and m2.id_functionality=15);
COMMIT;
