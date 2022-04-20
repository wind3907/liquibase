REM
REM User--SARA on 07/13/2018 15:32 generated script to insert tables: ML_MODULES and ML_VALUES
PROMPT *** Insert PK: 102296   Form/Menu: mr1cs  ***
Insert into SWMS.ML_MODULES (PK_ML_MODULES,NAME_FORM,OBJECT_TYPE,NAME_OBJECT,AUX_INFO1,AUX_INFO2,TYPE_FORM) 
 Select 102296,'mr1cs',1,'CAUTION_ALERT',NULL,NULL,10 from dual 
 Where not exists (select 1 from ml_modules m2 where m2.pk_ml_modules = 102296);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102296,3,1,'Confirmation before deletion' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102296 and m2.id_language=3 and m2.id_functionality=1);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102296,12,1,'??Ca-Fr-Confirmation Before Deletion' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102296 and m2.id_language=12 and m2.id_functionality=1);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102296,3,2,'Are you sure you want to delete customer location?' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102296 and m2.id_language=3 and m2.id_functionality=2);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102296,12,2,'??Ca-Fr-Are you sure you want to delete customer location?' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102296 and m2.id_language=12 and m2.id_functionality=2);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102296,3,3,'Yes' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102296 and m2.id_language=3 and m2.id_functionality=3);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102296,12,3,'Qui' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102296 and m2.id_language=12 and m2.id_functionality=3);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102296,3,4,'No' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102296 and m2.id_language=3 and m2.id_functionality=4);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102296,12,4,'Non' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102296 and m2.id_language=12 and m2.id_functionality=4);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102296,3,5,'' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102296 and m2.id_language=3 and m2.id_functionality=5);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102296,12,5,'' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102296 and m2.id_language=12 and m2.id_functionality=5);
PROMPT *** Insert PK: 102297   Form/Menu: mr1cs  ***
Insert into SWMS.ML_MODULES (PK_ML_MODULES,NAME_FORM,OBJECT_TYPE,NAME_OBJECT,AUX_INFO1,AUX_INFO2,TYPE_FORM) 
 Select 102297,'mr1cs',35,'PAGE_1',NULL,NULL,10 from dual 
 Where not exists (select 1 from ml_modules m2 where m2.pk_ml_modules = 102297);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102297,3,13,'Customer Staging Location Setup - [MR1CS]' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102297 and m2.id_language=3 and m2.id_functionality=13);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102297,12,13,'??Ca-Fr-Customer Staging Location Setup - [MR1CS]' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102297 and m2.id_language=12 and m2.id_functionality=13);
PROMPT *** Insert PK: 102302   Form/Menu: mr1cs  ***
Insert into SWMS.ML_MODULES (PK_ML_MODULES,NAME_FORM,OBJECT_TYPE,NAME_OBJECT,AUX_INFO1,AUX_INFO2,TYPE_FORM) 
 Select 102302,'mr1cs',1,'STOP_ALERT',NULL,NULL,10 from dual 
 Where not exists (select 1 from ml_modules m2 where m2.pk_ml_modules = 102302);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102302,3,1,'Forms Alert' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102302 and m2.id_language=3 and m2.id_functionality=1);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102302,12,1,'Alertes de formulaires' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102302 and m2.id_language=12 and m2.id_functionality=1);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102302,3,2,'The location cannot be deleted as there is Inventory' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102302 and m2.id_language=3 and m2.id_functionality=2);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102302,12,2,'L''emplacement ne peut pas etre supprime car il y a Inventaire' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102302 and m2.id_language=12 and m2.id_functionality=2);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102302,3,3,'Yes' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102302 and m2.id_language=3 and m2.id_functionality=3);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102302,12,3,'Oui' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102302 and m2.id_language=12 and m2.id_functionality=3);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102302,3,4,'' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102302 and m2.id_language=3 and m2.id_functionality=4);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102302,12,4,'' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102302 and m2.id_language=12 and m2.id_functionality=4);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102302,3,5,'' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102302 and m2.id_language=3 and m2.id_functionality=5);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102302,12,5,'' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102302 and m2.id_language=12 and m2.id_functionality=5);
PROMPT *** Insert PK: 102303   Form/Menu: mr1cs  ***
Insert into SWMS.ML_MODULES (PK_ML_MODULES,NAME_FORM,OBJECT_TYPE,NAME_OBJECT,AUX_INFO1,AUX_INFO2,TYPE_FORM) 
 Select 102303,'mr1cs',15,'LOV_CUST_ID',NULL,NULL,10 from dual 
 Where not exists (select 1 from ml_modules m2 where m2.pk_ml_modules = 102303);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102303,3,11,'Choose customer Id' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102303 and m2.id_language=3 and m2.id_functionality=11);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102303,12,11,'Choisissez l''identifiant du client' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102303 and m2.id_language=12 and m2.id_functionality=11);
PROMPT *** Insert PK: 102304   Form/Menu: mr1cs  ***
Insert into SWMS.ML_MODULES (PK_ML_MODULES,NAME_FORM,OBJECT_TYPE,NAME_OBJECT,AUX_INFO1,AUX_INFO2,TYPE_FORM) 
 Select 102304,'mr1cs',15,'LOV_LOC',NULL,NULL,10 from dual 
 Where not exists (select 1 from ml_modules m2 where m2.pk_ml_modules = 102304);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102304,3,11,'Choose Staging Location' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102304 and m2.id_language=3 and m2.id_functionality=11);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102304,12,11,'Choisir l''emplacement de mise en attente' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102304 and m2.id_language=12 and m2.id_functionality=11);
PROMPT *** Insert PK: 102305   Form/Menu: mr1cs  ***
Insert into SWMS.ML_MODULES (PK_ML_MODULES,NAME_FORM,OBJECT_TYPE,NAME_OBJECT,AUX_INFO1,AUX_INFO2,TYPE_FORM) 
 Select 102305,'mr1cs',16,'CUST_ID','LOV_CUST_ID','1',10 from dual 
 Where not exists (select 1 from ml_modules m2 where m2.pk_ml_modules = 102305);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102305,3,12,'Customer Id' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102305 and m2.id_language=3 and m2.id_functionality=12);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102305,12,12,'N ? de client' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102305 and m2.id_language=12 and m2.id_functionality=12);
PROMPT *** Insert PK: 102306   Form/Menu: mr1cs  ***
Insert into SWMS.ML_MODULES (PK_ML_MODULES,NAME_FORM,OBJECT_TYPE,NAME_OBJECT,AUX_INFO1,AUX_INFO2,TYPE_FORM) 
 Select 102306,'mr1cs',16,'CUST_NAME','LOV_CUST_ID','2',10 from dual 
 Where not exists (select 1 from ml_modules m2 where m2.pk_ml_modules = 102306);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102306,3,12,'Customer Name' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102306 and m2.id_language=3 and m2.id_functionality=12);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102306,12,12,'Nom du client' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102306 and m2.id_language=12 and m2.id_functionality=12);
PROMPT *** Insert PK: 102307   Form/Menu: mr1cs  ***
Insert into SWMS.ML_MODULES (PK_ML_MODULES,NAME_FORM,OBJECT_TYPE,NAME_OBJECT,AUX_INFO1,AUX_INFO2,TYPE_FORM) 
 Select 102307,'mr1cs',16,'LOGI_LOC','LOV_LOC','1',10 from dual 
 Where not exists (select 1 from ml_modules m2 where m2.pk_ml_modules = 102307);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102307,3,12,'Location' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102307 and m2.id_language=3 and m2.id_functionality=12);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102307,12,12,'Emplacement' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102307 and m2.id_language=12 and m2.id_functionality=12);
PROMPT *** Insert PK: 102308   Form/Menu: mr1cs  ***
Insert into SWMS.ML_MODULES (PK_ML_MODULES,NAME_FORM,OBJECT_TYPE,NAME_OBJECT,AUX_INFO1,AUX_INFO2,TYPE_FORM) 
 Select 102308,'mr1cs',16,'ZONE_ID','LOV_LOC','2',10 from dual 
 Where not exists (select 1 from ml_modules m2 where m2.pk_ml_modules = 102308);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102308,3,12,'Zone Id' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102308 and m2.id_language=3 and m2.id_functionality=12);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102308,12,12,'Identifiant de zone' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102308 and m2.id_language=12 and m2.id_functionality=12);
PROMPT *** Insert PK: 102313   Form/Menu: mr1cs  ***
Insert into SWMS.ML_MODULES (PK_ML_MODULES,NAME_FORM,OBJECT_TYPE,NAME_OBJECT,AUX_INFO1,AUX_INFO2,TYPE_FORM) 
 Select 102313,'mr1cs',13,'CUST_ID','MASTER',NULL,10 from dual 
 Where not exists (select 1 from ml_modules m2 where m2.pk_ml_modules = 102313);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102313,3,6,'' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102313 and m2.id_language=3 and m2.id_functionality=6);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102313,12,6,'' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102313 and m2.id_language=12 and m2.id_functionality=6);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102313,3,7,'Enter value for: Customer Id' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102313 and m2.id_language=3 and m2.id_functionality=7);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102313,12,7,'??Ca-Fr-Enter value for: Customer Id' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102313 and m2.id_language=12 and m2.id_functionality=7);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102313,3,8,'Enter value for: Customer Id' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102313 and m2.id_language=3 and m2.id_functionality=8);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102313,12,8,'??Ca-Fr-Enter value for: Customer Id' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102313 and m2.id_language=12 and m2.id_functionality=8);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102313,3,15,'Customer Id:' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102313 and m2.id_language=3 and m2.id_functionality=15);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102313,12,15,'??Ca-Fr-Customer Id:' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102313 and m2.id_language=12 and m2.id_functionality=15);
PROMPT *** Insert PK: 102314   Form/Menu: mr1cs  ***
Insert into SWMS.ML_MODULES (PK_ML_MODULES,NAME_FORM,OBJECT_TYPE,NAME_OBJECT,AUX_INFO1,AUX_INFO2,TYPE_FORM) 
 Select 102314,'mr1cs',13,'STAGE_LOC','MASTER',NULL,10 from dual 
 Where not exists (select 1 from ml_modules m2 where m2.pk_ml_modules = 102314);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102314,3,6,'' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102314 and m2.id_language=3 and m2.id_functionality=6);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102314,12,6,'' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102314 and m2.id_language=12 and m2.id_functionality=6);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102314,3,7,'Enter value for: Staging Location' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102314 and m2.id_language=3 and m2.id_functionality=7);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102314,12,7,'??Ca-Fr-Enter value for: Staging Location' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102314 and m2.id_language=12 and m2.id_functionality=7);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102314,3,8,'Enter value for: Staging Location' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102314 and m2.id_language=3 and m2.id_functionality=8);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102314,12,8,'??Ca-Fr-Enter value for: Staging Location' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102314 and m2.id_language=12 and m2.id_functionality=8);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102314,3,15,'Staging Location:' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102314 and m2.id_language=3 and m2.id_functionality=15);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102314,12,15,'??Staging Location:' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102314 and m2.id_language=12 and m2.id_functionality=15);
PROMPT *** Insert PK: 102315   Form/Menu: mr1cs  ***
Insert into SWMS.ML_MODULES (PK_ML_MODULES,NAME_FORM,OBJECT_TYPE,NAME_OBJECT,AUX_INFO1,AUX_INFO2,TYPE_FORM) 
 Select 102315,'mr1cs',13,'CUST_ID','STAGE_LOC',NULL,10 from dual 
 Where not exists (select 1 from ml_modules m2 where m2.pk_ml_modules = 102315);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102315,3,6,'' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102315 and m2.id_language=3 and m2.id_functionality=6);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102315,12,6,'' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102315 and m2.id_language=12 and m2.id_functionality=6);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102315,3,7,'Enter/Select a value for: Customer Id' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102315 and m2.id_language=3 and m2.id_functionality=7);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102315,12,7,'??Ca-Fr-Enter/Select a value for: Customer Id' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102315 and m2.id_language=12 and m2.id_functionality=7);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102315,3,8,'Enter/Select a value for: Customer Id' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102315 and m2.id_language=3 and m2.id_functionality=8);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102315,12,8,'??Ca-Fr-Enter/Select a value for: Customer Id' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102315 and m2.id_language=12 and m2.id_functionality=8);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102315,3,15,'Customer Id' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102315 and m2.id_language=3 and m2.id_functionality=15);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102315,12,15,'??Ca-Fr-Customer Id' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102315 and m2.id_language=12 and m2.id_functionality=15);
PROMPT *** Insert PK: 102316   Form/Menu: mr1cs  ***
Insert into SWMS.ML_MODULES (PK_ML_MODULES,NAME_FORM,OBJECT_TYPE,NAME_OBJECT,AUX_INFO1,AUX_INFO2,TYPE_FORM) 
 Select 102316,'mr1cs',13,'LOC','STAGE_LOC',NULL,10 from dual 
 Where not exists (select 1 from ml_modules m2 where m2.pk_ml_modules = 102316);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102316,3,6,'' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102316 and m2.id_language=3 and m2.id_functionality=6);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102316,12,6,'' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102316 and m2.id_language=12 and m2.id_functionality=6);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102316,3,7,'Enter/Select a value for: Staging Location' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102316 and m2.id_language=3 and m2.id_functionality=7);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102316,12,7,'??Ca-Fr-Enter/Select a value for: Staging Location' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102316 and m2.id_language=12 and m2.id_functionality=7);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102316,3,8,'Enter/Select a value for: Staging Location' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102316 and m2.id_language=3 and m2.id_functionality=8);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102316,12,8,'??Ca-Fr-Enter/Select a value for: Staging Location' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102316 and m2.id_language=12 and m2.id_functionality=8);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102316,3,15,'Staging Location' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102316 and m2.id_language=3 and m2.id_functionality=15);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102316,12,15,'??Ca-Fr-Staging Location' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102316 and m2.id_language=12 and m2.id_functionality=15);
PROMPT *** Insert PK: 102319   Form/Menu: mr1cs  ***
Insert into SWMS.ML_MODULES (PK_ML_MODULES,NAME_FORM,OBJECT_TYPE,NAME_OBJECT,AUX_INFO1,AUX_INFO2,TYPE_FORM) 
 Select 102319,'mr1cs',13,'ZONE_ID','STAGE_LOC',NULL,10 from dual 
 Where not exists (select 1 from ml_modules m2 where m2.pk_ml_modules = 102319);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102319,3,6,'' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102319 and m2.id_language=3 and m2.id_functionality=6);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102319,12,6,'' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102319 and m2.id_language=12 and m2.id_functionality=6);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102319,3,7,'Zone Id' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102319 and m2.id_language=3 and m2.id_functionality=7);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102319,12,7,'Identifiant de zone' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102319 and m2.id_language=12 and m2.id_functionality=7);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102319,3,8,'Zone Id' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102319 and m2.id_language=3 and m2.id_functionality=8);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102319,12,8,'Identifiant de zone' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102319 and m2.id_language=12 and m2.id_functionality=8);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102319,3,15,'Zone Id' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102319 and m2.id_language=3 and m2.id_functionality=15);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102319,12,15,'Identifiant de zone' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102319 and m2.id_language=12 and m2.id_functionality=15);
PROMPT *** Insert PK: 102320   Form/Menu: mr1cs  ***
Insert into SWMS.ML_MODULES (PK_ML_MODULES,NAME_FORM,OBJECT_TYPE,NAME_OBJECT,AUX_INFO1,AUX_INFO2,TYPE_FORM) 
 Select 102320,'mr1cs',13,'ZONE_DESC','STAGE_LOC',NULL,10 from dual 
 Where not exists (select 1 from ml_modules m2 where m2.pk_ml_modules = 102320);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102320,3,6,'' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102320 and m2.id_language=3 and m2.id_functionality=6);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102320,12,6,'' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102320 and m2.id_language=12 and m2.id_functionality=6);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102320,3,7,'Zone Description' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102320 and m2.id_language=3 and m2.id_functionality=7);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102320,12,7,'Description de la zone' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102320 and m2.id_language=12 and m2.id_functionality=7);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102320,3,8,'Zone Description' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102320 and m2.id_language=3 and m2.id_functionality=8);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102320,12,8,'Description de la zone' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102320 and m2.id_language=12 and m2.id_functionality=8);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102320,3,15,'Zone Description' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102320 and m2.id_language=3 and m2.id_functionality=15);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102320,12,15,'Description de la zone' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102320 and m2.id_language=12 and m2.id_functionality=15);
COMMIT;
