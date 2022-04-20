REM
REM User--PRIYA on 09/19/2017 09:52 generated script to insert tables: ML_MODULES and ML_VALUES
PROMPT *** Insert PK: 102129   Form/Menu: mi1sb  ***
Insert into SWMS.ML_MODULES (PK_ML_MODULES,NAME_FORM,OBJECT_TYPE,NAME_OBJECT,AUX_INFO1,AUX_INFO2,TYPE_FORM) 
 Select 102129,'mi1sb',13,'GS1_BARCODE_FLAG','PM_DETAIL',NULL,10 from dual 
 Where not exists (select 1 from ml_modules m2 where m2.pk_ml_modules = 102129);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102129,3,6,'' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102129 and m2.id_language=3 and m2.id_functionality=6);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102129,12,6,'' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102129 and m2.id_language=12 and m2.id_functionality=6);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102129,3,7,'Choose TRUE or FALSE to indicate GS1 Scan' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102129 and m2.id_language=3 and m2.id_functionality=7);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102129,12,7,'??Ca-Fr-Choose TRUE or FALSE to indicate GS1 Scan' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102129 and m2.id_language=12 and m2.id_functionality=7);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102129,3,8,'Choose TRUE or FALSE to indicate GS1 Scan' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102129 and m2.id_language=3 and m2.id_functionality=8);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102129,12,8,'??Ca-Fr-Choose TRUE or FALSE to indicate GS1 Scan' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102129 and m2.id_language=12 and m2.id_functionality=8);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102129,3,15,'GS1 Scan Indicator:' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102129 and m2.id_language=3 and m2.id_functionality=15);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102129,12,15,'??Ca-Fr-GS1 Scan Indicator:' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102129 and m2.id_language=12 and m2.id_functionality=15);
COMMIT;
