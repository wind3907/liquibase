REM
REM User--MICHAEL on 09/25/2017 12:08 generated script to insert tables: ML_MODULES and ML_VALUES
PROMPT *** Insert PK: 102191   Form/Menu: sossd1  ***
Insert into SWMS.ML_MODULES (PK_ML_MODULES,NAME_FORM,OBJECT_TYPE,NAME_OBJECT,AUX_INFO1,AUX_INFO2,TYPE_FORM) 
 Select 102191,'sossd1',13,'SELECTOR','SHORT_DETAIL',NULL,10 from dual 
 Where not exists (select 1 from ml_modules m2 where m2.pk_ml_modules = 102191);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102191,3,6,'' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102191 and m2.id_language=3 and m2.id_functionality=6);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102191,12,6,'' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102191 and m2.id_language=12 and m2.id_functionality=6);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102191,3,7,'' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102191 and m2.id_language=3 and m2.id_functionality=7);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102191,12,7,'' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102191 and m2.id_language=12 and m2.id_functionality=7);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102191,3,8,'' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102191 and m2.id_language=3 and m2.id_functionality=8);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102191,12,8,'' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102191 and m2.id_language=12 and m2.id_functionality=8);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102191,3,15,'Selector ID' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102191 and m2.id_language=3 and m2.id_functionality=15);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102191,12,15,'Utilisateur' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102191 and m2.id_language=12 and m2.id_functionality=15);
PROMPT *** Insert PK: 102192   Form/Menu: sossd1  ***
Insert into SWMS.ML_MODULES (PK_ML_MODULES,NAME_FORM,OBJECT_TYPE,NAME_OBJECT,AUX_INFO1,AUX_INFO2,TYPE_FORM) 
 Select 102192,'sossd1',13,'BATCH_NO','SHORT_DETAIL',NULL,10 from dual 
 Where not exists (select 1 from ml_modules m2 where m2.pk_ml_modules = 102192);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102192,3,6,'' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102192 and m2.id_language=3 and m2.id_functionality=6);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102192,12,6,'' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102192 and m2.id_language=12 and m2.id_functionality=6);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102192,3,7,'' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102192 and m2.id_language=3 and m2.id_functionality=7);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102192,12,7,'' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102192 and m2.id_language=12 and m2.id_functionality=7);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102192,3,8,'' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102192 and m2.id_language=3 and m2.id_functionality=8);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102192,12,8,'' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102192 and m2.id_language=12 and m2.id_functionality=8);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102192,3,15,'Batch' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102192 and m2.id_language=3 and m2.id_functionality=15);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102192,12,15,'Tâche' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102192 and m2.id_language=12 and m2.id_functionality=15);
PROMPT *** Insert PK: 102193   Form/Menu: sossd1  ***
Insert into SWMS.ML_MODULES (PK_ML_MODULES,NAME_FORM,OBJECT_TYPE,NAME_OBJECT,AUX_INFO1,AUX_INFO2,TYPE_FORM) 
 Select 102193,'sossd1',13,'QTY_SHORT','SHORT_DETAIL',NULL,10 from dual 
 Where not exists (select 1 from ml_modules m2 where m2.pk_ml_modules = 102193);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102193,3,6,'' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102193 and m2.id_language=3 and m2.id_functionality=6);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102193,12,6,'' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102193 and m2.id_language=12 and m2.id_functionality=6);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102193,3,7,'' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102193 and m2.id_language=3 and m2.id_functionality=7);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102193,12,7,'' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102193 and m2.id_language=12 and m2.id_functionality=7);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102193,3,8,'' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102193 and m2.id_language=3 and m2.id_functionality=8);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102193,12,8,'' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102193 and m2.id_language=12 and m2.id_functionality=8);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102193,3,15,'Qty Short' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102193 and m2.id_language=3 and m2.id_functionality=15);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102193,12,15,'Qte manq.' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102193 and m2.id_language=12 and m2.id_functionality=15);
PROMPT *** Insert PK: 102194   Form/Menu: sossd1  ***
Insert into SWMS.ML_MODULES (PK_ML_MODULES,NAME_FORM,OBJECT_TYPE,NAME_OBJECT,AUX_INFO1,AUX_INFO2,TYPE_FORM) 
 Select 102194,'sossd1',13,'UOM','SHORT_DETAIL',NULL,10 from dual 
 Where not exists (select 1 from ml_modules m2 where m2.pk_ml_modules = 102194);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102194,3,6,'' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102194 and m2.id_language=3 and m2.id_functionality=6);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102194,12,6,'' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102194 and m2.id_language=12 and m2.id_functionality=6);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102194,3,7,'' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102194 and m2.id_language=3 and m2.id_functionality=7);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102194,12,7,'' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102194 and m2.id_language=12 and m2.id_functionality=7);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102194,3,8,'' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102194 and m2.id_language=3 and m2.id_functionality=8);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102194,12,8,'' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102194 and m2.id_language=12 and m2.id_functionality=8);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102194,3,15,'UOM' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102194 and m2.id_language=3 and m2.id_functionality=15);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102194,12,15,'UDM' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102194 and m2.id_language=12 and m2.id_functionality=15);
PROMPT *** Insert PK: 102195   Form/Menu: sossd1  ***
Insert into SWMS.ML_MODULES (PK_ML_MODULES,NAME_FORM,OBJECT_TYPE,NAME_OBJECT,AUX_INFO1,AUX_INFO2,TYPE_FORM) 
 Select 102195,'sossd1',13,'SHORT_REASON','SHORT_DETAIL',NULL,10 from dual 
 Where not exists (select 1 from ml_modules m2 where m2.pk_ml_modules = 102195);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102195,3,6,'' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102195 and m2.id_language=3 and m2.id_functionality=6);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102195,12,6,'' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102195 and m2.id_language=12 and m2.id_functionality=6);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102195,3,7,'' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102195 and m2.id_language=3 and m2.id_functionality=7);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102195,12,7,'' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102195 and m2.id_language=12 and m2.id_functionality=7);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102195,3,8,'' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102195 and m2.id_language=3 and m2.id_functionality=8);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102195,12,8,'' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102195 and m2.id_language=12 and m2.id_functionality=8);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102195,3,15,'Short reason' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102195 and m2.id_language=3 and m2.id_functionality=15);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102195,12,15,'Raison manq.' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102195 and m2.id_language=12 and m2.id_functionality=15);
PROMPT *** Insert PK: 102197   Form/Menu: sossd1  ***
Insert into SWMS.ML_MODULES (PK_ML_MODULES,NAME_FORM,OBJECT_TYPE,NAME_OBJECT,AUX_INFO1,AUX_INFO2,TYPE_FORM) 
 Select 102197,'sossd1',13,'PICKTIME','SHORT_DETAIL',NULL,10 from dual 
 Where not exists (select 1 from ml_modules m2 where m2.pk_ml_modules = 102197);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102197,3,6,'' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102197 and m2.id_language=3 and m2.id_functionality=6);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102197,12,6,'' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102197 and m2.id_language=12 and m2.id_functionality=6);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102197,3,7,'' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102197 and m2.id_language=3 and m2.id_functionality=7);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102197,12,7,'' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102197 and m2.id_language=12 and m2.id_functionality=7);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102197,3,8,'' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102197 and m2.id_language=3 and m2.id_functionality=8);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102197,12,8,'' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102197 and m2.id_language=12 and m2.id_functionality=8);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102197,3,15,'Pick Time' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102197 and m2.id_language=3 and m2.id_functionality=15);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102197,12,15,'Heure Prél.' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102197 and m2.id_language=12 and m2.id_functionality=15);

PROMPT *** Update PK: 14030   Form/Menu: sossd1  ***
Update ml_values set text='Util. Ram. 
Manquant:' where FK_ML_MODULES=14030 and ID_LANGUAGE=12 and ID_FUNCTIONALITY=15;
COMMIT;
