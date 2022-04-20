REM
REM User--MICHAEL on 09/21/2017 11:27 generated script to insert tables: ML_MODULES and ML_VALUES
PROMPT *** Insert PK: 102169   Form/Menu: paewo  ***
Insert into SWMS.ML_MODULES (PK_ML_MODULES,NAME_FORM,OBJECT_TYPE,NAME_OBJECT,AUX_INFO1,AUX_INFO2,TYPE_FORM) 
 Select 102169,'paewo',13,'ITEM','MASTER',NULL,10 from dual 
 Where not exists (select 1 from ml_modules m2 where m2.pk_ml_modules = 102169);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102169,3,6,'' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102169 and m2.id_language=3 and m2.id_functionality=6);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102169,12,6,'' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102169 and m2.id_language=12 and m2.id_functionality=6);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102169,3,7,'Enter the item number for query' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102169 and m2.id_language=3 and m2.id_functionality=7);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102169,12,7,'??Ca-Fr' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102169 and m2.id_language=12 and m2.id_functionality=7);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102169,3,8,'Enter the item number for query' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102169 and m2.id_language=3 and m2.id_functionality=8);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102169,12,8,'??Fr--Enter the item number for query' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102169 and m2.id_language=12 and m2.id_functionality=8);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102169,3,15,'Item:' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102169 and m2.id_language=3 and m2.id_functionality=15);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102169,12,15,'Produit:' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102169 and m2.id_language=12 and m2.id_functionality=15);

PROMPT *** Insert PK: 102172   Form/Menu: paewo  ***
Insert into SWMS.ML_MODULES (PK_ML_MODULES,NAME_FORM,OBJECT_TYPE,NAME_OBJECT,AUX_INFO1,AUX_INFO2,TYPE_FORM) 
 Select 102172,'paewo',13,'CASE_QTY','DETAIL',NULL,10 from dual 
 Where not exists (select 1 from ml_modules m2 where m2.pk_ml_modules = 102172);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102172,3,6,'' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102172 and m2.id_language=3 and m2.id_functionality=6);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102172,12,6,'' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102172 and m2.id_language=12 and m2.id_functionality=6);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102172,3,7,'Case Quantity' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102172 and m2.id_language=3 and m2.id_functionality=7);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102172,12,7,'?Fr-Case quantity' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102172 and m2.id_language=12 and m2.id_functionality=7);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102172,3,8,'Case quantity' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102172 and m2.id_language=3 and m2.id_functionality=8);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102172,12,8,'?Fr-Case quantity' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102172 and m2.id_language=12 and m2.id_functionality=8);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102172,3,15,'QOH
Cases' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102172 and m2.id_language=3 and m2.id_functionality=15);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102172,12,15,'QEM
Cs' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102172 and m2.id_language=12 and m2.id_functionality=15);

PROMPT *** Insert PK: 102173   Form/Menu: paewo  ***
Insert into SWMS.ML_MODULES (PK_ML_MODULES,NAME_FORM,OBJECT_TYPE,NAME_OBJECT,AUX_INFO1,AUX_INFO2,TYPE_FORM) 
 Select 102173,'paewo',13,'SPLIT_QTY','DETAIL',NULL,10 from dual 
 Where not exists (select 1 from ml_modules m2 where m2.pk_ml_modules = 102173);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102173,3,6,'' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102173 and m2.id_language=3 and m2.id_functionality=6);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102173,12,6,'' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102173 and m2.id_language=12 and m2.id_functionality=6);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102173,3,7,'Split quantity' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102173 and m2.id_language=3 and m2.id_functionality=7);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102173,12,7,'?Fr-Split quantity' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102173 and m2.id_language=12 and m2.id_functionality=7);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102173,3,8,'Split quantity' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102173 and m2.id_language=3 and m2.id_functionality=8);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102173,12,8,'?Fr-Split quantity' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102173 and m2.id_language=12 and m2.id_functionality=8);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102173,3,15,'QOH
Split' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102173 and m2.id_language=3 and m2.id_functionality=15);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102173,12,15,'QEM
Un' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102173 and m2.id_language=12 and m2.id_functionality=15);

PROMPT *** Insert PK: 102175   Form/Menu: paewo  ***
Insert into SWMS.ML_MODULES (PK_ML_MODULES,NAME_FORM,OBJECT_TYPE,NAME_OBJECT,AUX_INFO1,AUX_INFO2,TYPE_FORM) 
 Select 102175,'paewo',13,'COOL_COUNT','DETAIL',NULL,10 from dual 
 Where not exists (select 1 from ml_modules m2 where m2.pk_ml_modules = 102175);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102175,3,6,'' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102175 and m2.id_language=3 and m2.id_functionality=6);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102175,12,6,'' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102175 and m2.id_language=12 and m2.id_functionality=6);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102175,3,7,'COOL count' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102175 and m2.id_language=3 and m2.id_functionality=7);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102175,12,7,'?Fr-COOL count' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102175 and m2.id_language=12 and m2.id_functionality=7);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102175,3,8,'COOL count' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102175 and m2.id_language=3 and m2.id_functionality=8);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102175,12,8,'?Fr-COOL count' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102175 and m2.id_language=12 and m2.id_functionality=8);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102175,3,15,'COOL
Entered' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102175 and m2.id_language=3 and m2.id_functionality=15);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102175,12,15,'EPO
Saisi' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102175 and m2.id_language=12 and m2.id_functionality=15);

PROMPT *** Update PK: 10028    Form/Menu: paewo ***
Update SWMS.ML_VALUES set text='CWT
Entered' where fk_ml_modules=10028 and id_language=3 and id_functionality=15;
Update SWMS.ML_VALUES set text='PV
Saisi' where fk_ml_modules=10028 and id_language=12 and id_functionality=15;

COMMIT;
