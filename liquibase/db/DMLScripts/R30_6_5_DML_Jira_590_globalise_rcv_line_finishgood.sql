REM
REM User--SARA on 09/19/2018 15:38 generated script to insert tables: ML_MODULES and ML_VALUES
PROMPT *** Insert PK: 102324   Form/Menu: rp1sb  ***
Insert into SWMS.ML_MODULES (PK_ML_MODULES,NAME_FORM,OBJECT_TYPE,NAME_OBJECT,AUX_INFO1,AUX_INFO2,TYPE_FORM) 
 Select 102324,'rp1sb',13,'FINISH_GOOD_FLAG1','DETAIL',NULL,10 from dual 
 Where not exists (select 1 from ml_modules m2 where m2.pk_ml_modules = 102324);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102324,3,6,'' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102324 and m2.id_language=3 and m2.id_functionality=6);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102324,12,6,'' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102324 and m2.id_language=12 and m2.id_functionality=6);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102324,3,7,'Finish Good (Y/N)?' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102324 and m2.id_language=3 and m2.id_functionality=7);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102324,12,7,'??Ca-Fr' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102324 and m2.id_language=12 and m2.id_functionality=7);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102324,3,8,'??English' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102324 and m2.id_language=3 and m2.id_functionality=8);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102324,12,8,'??Ca-Fr' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102324 and m2.id_language=12 and m2.id_functionality=8);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102324,3,15,'FinishGood' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102324 and m2.id_language=3 and m2.id_functionality=15);
Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)  
select 102324,12,15,'??Ca-Fr' from dual 
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102324 and m2.id_language=12 and m2.id_functionality=15);

REM
REM User--SARA on 09/19/2018 16:57 generated script to insert table: MESSAGE_TABLE
PROMPT *** Insert PK: 120141   Form/Menu: rp1sb  ***
Insert into MESSAGE_TABLE (id_message,ID_LANGUAGE,v_message)  
select 120141,3,'Error while getting Cust Staging Loc' from dual 
where not exists (select 1 from message_table where id_message = 120141 and id_language=3);
Insert into MESSAGE_TABLE (id_message,ID_LANGUAGE,v_message)  
select 120141,12,'??Ca-Fr' from dual 
where not exists (select 1 from message_table where id_message = 120141 and id_language=12);
Insert into MESSAGE_TABLE (id_message,ID_LANGUAGE,v_message)  
select 120141,13,'??Spanish' from dual 
where not exists (select 1 from message_table where id_message = 120141 and id_language=13);
PROMPT *** Insert PK: 120146   Form/Menu: rp1sb  ***
Insert into MESSAGE_TABLE (id_message,ID_LANGUAGE,v_message)  
select 120146,3,'Error while getting Finish Goods Flag' from dual 
where not exists (select 1 from message_table where id_message = 120146 and id_language=3);
Insert into MESSAGE_TABLE (id_message,ID_LANGUAGE,v_message)  
select 120146,12,'??Ca-Fr' from dual 
where not exists (select 1 from message_table where id_message = 120146 and id_language=12);
Insert into MESSAGE_TABLE (id_message,ID_LANGUAGE,v_message)  
select 120146,13,'??Spanish' from dual 
where not exists (select 1 from message_table where id_message = 120146 and id_language=13);
PROMPT *** Insert PK: 120150   Form/Menu: rp1sb  ***

COMMIT;
