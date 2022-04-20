REM
REM User--KIET on 09/20/2017 14:52 generated script to insert tables: ML_MODULES and ML_VALUES
PROMPT *** Insert PK: 102110   Form/Menu: ob1ri  ***
Insert into SWMS.ML_MODULES (PK_ML_MODULES,NAME_FORM,OBJECT_TYPE,NAME_OBJECT,AUX_INFO1,AUX_INFO2,TYPE_FORM) 
 Select 102110,'ob1ri',1,'ALERT_NO_DATA',NULL,NULL,10 from dual 
 Where not exists (select 1 from ml_modules m2 where m2.pk_ml_modules = 102110);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102110,3,1,'Selector ID Invalid' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102110 and m2.id_language=3 and m2.id_functionality=1);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102110,12,1,'Utilisateur' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102110 and m2.id_language=12 and m2.id_functionality=1);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102110,3,2,'Please enter correct selector ID or leave it blank' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102110 and m2.id_language=3 and m2.id_functionality=2);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102110,12,2,'??Ca-Fr-Please enter correct selector ID or leave it blank' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102110 and m2.id_language=12 and m2.id_functionality=2);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102110,3,3,'Ok' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102110 and m2.id_language=3 and m2.id_functionality=3);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102110,12,3,'??Ca-Fr-Ok' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102110 and m2.id_language=12 and m2.id_functionality=3);
PROMPT *** Insert PK: 102111   Form/Menu: ob1ri  ***
Insert into SWMS.ML_MODULES (PK_ML_MODULES,NAME_FORM,OBJECT_TYPE,NAME_OBJECT,AUX_INFO1,AUX_INFO2,TYPE_FORM) 
 Select 102111,'ob1ri',13,'SELECTOR_ID','ORDCW_HIST',NULL,10 from dual 
 Where not exists (select 1 from ml_modules m2 where m2.pk_ml_modules = 102111);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102111,3,6,'' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102111 and m2.id_language=3 and m2.id_functionality=6);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102111,12,6,'' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102111 and m2.id_language=12 and m2.id_functionality=6);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102111,3,7,'Enter the selector ID, use LOV or leave it blank' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102111 and m2.id_language=3 and m2.id_functionality=7);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102111,12,7,'Entrez Utilisateur' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102111 and m2.id_language=12 and m2.id_functionality=7);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102111,3,8,'Enter the selector ID, use LOV or leave it blank' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102111 and m2.id_language=3 and m2.id_functionality=8);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102111,12,8,'Entrez Utilisateur' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102111 and m2.id_language=12 and m2.id_functionality=8);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102111,3,15,'Selector ID' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102111 and m2.id_language=3 and m2.id_functionality=15);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102111,12,15,'Utilisateur' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102111 and m2.id_language=12 and m2.id_functionality=15);
PROMPT *** Insert PK: 102112   Form/Menu: ob1ri  ***
Insert into SWMS.ML_MODULES (PK_ML_MODULES,NAME_FORM,OBJECT_TYPE,NAME_OBJECT,AUX_INFO1,AUX_INFO2,TYPE_FORM) 
 Select 102112,'ob1ri',13,'SUBMIT','ORDCW_HIST',NULL,10 from dual 
 Where not exists (select 1 from ml_modules m2 where m2.pk_ml_modules = 102112);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102112,3,6,'Submit' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102112 and m2.id_language=3 and m2.id_functionality=6);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102112,12,6,'Soummetre' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102112 and m2.id_language=12 and m2.id_functionality=6);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102112,3,7,'Submit' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102112 and m2.id_language=3 and m2.id_functionality=7);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102112,12,7,'Soummetre' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102112 and m2.id_language=12 and m2.id_functionality=7);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102112,3,8,'Submit' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102112 and m2.id_language=3 and m2.id_functionality=8);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102112,12,8,'Soummetre' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102112 and m2.id_language=12 and m2.id_functionality=8);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102112,3,15,'' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102112 and m2.id_language=3 and m2.id_functionality=15);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102112,12,15,'' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102112 and m2.id_language=12 and m2.id_functionality=15);
PROMPT *** Insert PK: 102113   Form/Menu: ob1ri  ***
Insert into SWMS.ML_MODULES (PK_ML_MODULES,NAME_FORM,OBJECT_TYPE,NAME_OBJECT,AUX_INFO1,AUX_INFO2,TYPE_FORM) 
 Select 102113,'ob1ri',15,'LOV_SELECTOR',NULL,NULL,10 from dual 
 Where not exists (select 1 from ml_modules m2 where m2.pk_ml_modules = 102113);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102113,3,11,'List of Values for Selector to Choose' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102113 and m2.id_language=3 and m2.id_functionality=11);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102113,12,11,'Liste des valeurs' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102113 and m2.id_language=12 and m2.id_functionality=11);
PROMPT *** Insert PK: 102114   Form/Menu: ob1ri  ***
Insert into SWMS.ML_MODULES (PK_ML_MODULES,NAME_FORM,OBJECT_TYPE,NAME_OBJECT,AUX_INFO1,AUX_INFO2,TYPE_FORM) 
 Select 102114,'ob1ri',16,'USER_ID','LOV_SELECTOR','1',10 from dual 
 Where not exists (select 1 from ml_modules m2 where m2.pk_ml_modules = 102114);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102114,3,12,'Selector ID' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102114 and m2.id_language=3 and m2.id_functionality=12);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102114,12,12,'Utilisateur' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102114 and m2.id_language=12 and m2.id_functionality=12);
PROMPT *** Insert PK: 102115   Form/Menu: ob1ri  ***
Insert into SWMS.ML_MODULES (PK_ML_MODULES,NAME_FORM,OBJECT_TYPE,NAME_OBJECT,AUX_INFO1,AUX_INFO2,TYPE_FORM) 
 Select 102115,'ob1ri',16,'USER_NAME','LOV_SELECTOR','2',10 from dual 
 Where not exists (select 1 from ml_modules m2 where m2.pk_ml_modules = 102115);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102115,3,12,'Selector Name' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102115 and m2.id_language=3 and m2.id_functionality=12);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102115,12,12,'prenom' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102115 and m2.id_language=12 and m2.id_functionality=12);
PROMPT *** Insert PK: 102117   Form/Menu: ob1ri  ***
Insert into SWMS.ML_MODULES (PK_ML_MODULES,NAME_FORM,OBJECT_TYPE,NAME_OBJECT,AUX_INFO1,AUX_INFO2,TYPE_FORM) 
 Select 102117,'ob1ri',13,'FROM_DATE','ORDCW_HIST',NULL,10 from dual 
 Where not exists (select 1 from ml_modules m2 where m2.pk_ml_modules = 102117);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102117,3,6,'' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102117 and m2.id_language=3 and m2.id_functionality=6);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102117,12,6,'' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102117 and m2.id_language=12 and m2.id_functionality=6);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102117,3,7,'Enter From Date' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102117 and m2.id_language=3 and m2.id_functionality=7);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102117,12,7,'Du (Date)' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102117 and m2.id_language=12 and m2.id_functionality=7);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102117,3,8,'Enter From Date' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102117 and m2.id_language=3 and m2.id_functionality=8);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102117,12,8,'Du (Date)' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102117 and m2.id_language=12 and m2.id_functionality=8);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102117,3,15,'From Date' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102117 and m2.id_language=3 and m2.id_functionality=15);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102117,12,15,'Du (Date)' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102117 and m2.id_language=12 and m2.id_functionality=15);
PROMPT *** Insert PK: 102118   Form/Menu: ob1ri  ***
Insert into SWMS.ML_MODULES (PK_ML_MODULES,NAME_FORM,OBJECT_TYPE,NAME_OBJECT,AUX_INFO1,AUX_INFO2,TYPE_FORM) 
 Select 102118,'ob1ri',35,'PAGE_1',NULL,NULL,10 from dual 
 Where not exists (select 1 from ml_modules m2 where m2.pk_ml_modules = 102118);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102118,3,13,'Catch Weight Scan Report --  [OB1RI]' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102118 and m2.id_language=3 and m2.id_functionality=13);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102118,12,13,'Rapport Balayage poids variables [OB1RI]' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102118 and m2.id_language=12 and m2.id_functionality=13);
PROMPT *** Insert PK: 102121   Form/Menu: ob1ri  ***
Insert into SWMS.ML_MODULES (PK_ML_MODULES,NAME_FORM,OBJECT_TYPE,NAME_OBJECT,AUX_INFO1,AUX_INFO2,TYPE_FORM) 
 Select 102121,'ob1ri',13,'TO_DATE','ORDCW_HIST',NULL,10 from dual 
 Where not exists (select 1 from ml_modules m2 where m2.pk_ml_modules = 102121);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102121,3,6,'' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102121 and m2.id_language=3 and m2.id_functionality=6);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102121,12,6,'' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102121 and m2.id_language=12 and m2.id_functionality=6);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102121,3,7,'Enter To Date and it cannot be less than FROM Date' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102121 and m2.id_language=3 and m2.id_functionality=7);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102121,12,7,'??Ca-Fr-Enter To Date and it cannot be less than FROM Date' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102121 and m2.id_language=12 and m2.id_functionality=7);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102121,3,8,'Enter To Date and it cannot be less than FROM Date' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102121 and m2.id_language=3 and m2.id_functionality=8);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102121,12,8,'Au (Date)' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102121 and m2.id_language=12 and m2.id_functionality=8);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102121,3,15,'To Date' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102121 and m2.id_language=3 and m2.id_functionality=15);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102121,12,15,'Au (Date)' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102121 and m2.id_language=12 and m2.id_functionality=15);
COMMIT;
