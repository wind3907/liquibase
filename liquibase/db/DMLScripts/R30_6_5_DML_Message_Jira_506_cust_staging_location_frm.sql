REM
REM User--SARA on 07/13/2018 15:50 generated script to insert table: MESSAGE_TABLE
PROMPT *** Insert PK: 120129   Form/Menu: mr1cs  ***
Insert into MESSAGE_TABLE (id_message,ID_LANGUAGE,v_message)  
select 120129,3,'Customer Id %s1 already exists' from dual 
where not exists (select 1 from message_table where id_message = 120129 and id_language=3);
Insert into MESSAGE_TABLE (id_message,ID_LANGUAGE,v_message)  
select 120129,12,'??Ca-Fr-Customer Id %s1 already exists' from dual 
where not exists (select 1 from message_table where id_message = 120129 and id_language=12);
Insert into MESSAGE_TABLE (id_message,ID_LANGUAGE,v_message)  
select 120129,13,'??Spanish- Customer Id %s1 already exists' from dual 
where not exists (select 1 from message_table where id_message = 120129 and id_language=13);
PROMPT *** Insert PK: 120130   Form/Menu: mr1cs  ***
Insert into MESSAGE_TABLE (id_message,ID_LANGUAGE,v_message)  
select 120130,3,'Cannot delete record from query block' from dual 
where not exists (select 1 from message_table where id_message = 120130 and id_language=3);
Insert into MESSAGE_TABLE (id_message,ID_LANGUAGE,v_message)  
select 120130,12,'??Ca-Fr-Cannot delete record from query block' from dual 
where not exists (select 1 from message_table where id_message = 120130 and id_language=12);
Insert into MESSAGE_TABLE (id_message,ID_LANGUAGE,v_message)  
select 120130,13,'??Spanish-Cannot delete record from query block' from dual 
where not exists (select 1 from message_table where id_message = 120130 and id_language=13);
PROMPT *** Insert PK: 120131   Form/Menu: mr1cs  ***
Insert into MESSAGE_TABLE (id_message,ID_LANGUAGE,v_message)  
select 120131,3,'The location cannot be deleted as the location has Inventory!' from dual 
where not exists (select 1 from message_table where id_message = 120131 and id_language=3);
Insert into MESSAGE_TABLE (id_message,ID_LANGUAGE,v_message)  
select 120131,12,'??Ca-Fr-The location cannot be deleted as the location has Inventory!' from dual 
where not exists (select 1 from message_table where id_message = 120131 and id_language=12);
Insert into MESSAGE_TABLE (id_message,ID_LANGUAGE,v_message)  
select 120131,13,'??Spanish-The location cannot be deleted as the location has Inventory!' from dual 
where not exists (select 1 from message_table where id_message = 120131 and id_language=13);
PROMPT *** Insert PK: 120132   Form/Menu: mr1cs  ***
Insert into MESSAGE_TABLE (id_message,ID_LANGUAGE,v_message)  
select 120132,3,'Are you sure you want to delete Customer Location?' from dual 
where not exists (select 1 from message_table where id_message = 120132 and id_language=3);
Insert into MESSAGE_TABLE (id_message,ID_LANGUAGE,v_message)  
select 120132,12,'??Ca-Fr-Are you sure you want to delete Customer Location?' from dual 
where not exists (select 1 from message_table where id_message = 120132 and id_language=12);
Insert into MESSAGE_TABLE (id_message,ID_LANGUAGE,v_message)  
select 120132,13,'??Spanish-Are you sure you want to delete Customer Location?' from dual 
where not exists (select 1 from message_table where id_message = 120132 and id_language=13);
PROMPT *** Insert PK: 120133   Form/Menu: mr1cs  ***
Insert into MESSAGE_TABLE (id_message,ID_LANGUAGE,v_message)  
select 120133,3,'The location %s1 is already assigned to customer %s2' from dual 
where not exists (select 1 from message_table where id_message = 120133 and id_language=3);
Insert into MESSAGE_TABLE (id_message,ID_LANGUAGE,v_message)  
select 120133,12,'??Ca-Fr-The location %s1 is already assigned to customer %s2' from dual 
where not exists (select 1 from message_table where id_message = 120133 and id_language=12);
Insert into MESSAGE_TABLE (id_message,ID_LANGUAGE,v_message)  
select 120133,13,'??Spanish-The location %s1 is already assigned to customer %s2' from dual 
where not exists (select 1 from message_table where id_message = 120133 and id_language=13);
COMMIT;
