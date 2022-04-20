REM
REM User--MICHAEL on 09/26/2017 11:51 generated script to insert table: MESSAGE_TABLE
PROMPT *** Insert PK: 120020   Form/Menu: soswhst  ***
Insert into MESSAGE_TABLE (id_message,ID_LANGUAGE,v_message)  
select 120020,3,'Sort By:' from dual 
where not exists (select 1 from message_table where id_message = 120020 and id_language=3);
Insert into MESSAGE_TABLE (id_message,ID_LANGUAGE,v_message)  
select 120020,12,'Trier par:' from dual 
where not exists (select 1 from message_table where id_message = 120020 and id_language=12);
Insert into MESSAGE_TABLE (id_message,ID_LANGUAGE,v_message)  
select 120020,13,'??Spanish' from dual 
where not exists (select 1 from message_table where id_message = 120020 and id_language=13);
PROMPT *** Insert PK: 120023   Form/Menu: soswhst  ***
Insert into MESSAGE_TABLE (id_message,ID_LANGUAGE,v_message)  
select 120023,3,'DRY' from dual 
where not exists (select 1 from message_table where id_message = 120023 and id_language=3);
Insert into MESSAGE_TABLE (id_message,ID_LANGUAGE,v_message)  
select 120023,12,'SEC' from dual 
where not exists (select 1 from message_table where id_message = 120023 and id_language=12);
Insert into MESSAGE_TABLE (id_message,ID_LANGUAGE,v_message)  
select 120023,13,'??Spanish' from dual 
where not exists (select 1 from message_table where id_message = 120023 and id_language=13);
PROMPT *** Insert PK: 120024   Form/Menu: soswhst  ***
Insert into MESSAGE_TABLE (id_message,ID_LANGUAGE,v_message)  
select 120024,3,'COOLER' from dual 
where not exists (select 1 from message_table where id_message = 120024 and id_language=3);
Insert into MESSAGE_TABLE (id_message,ID_LANGUAGE,v_message)  
select 120024,12,'Réfrigéré' from dual 
where not exists (select 1 from message_table where id_message = 120024 and id_language=12);
Insert into MESSAGE_TABLE (id_message,ID_LANGUAGE,v_message)  
select 120024,13,'??Spanish' from dual 
where not exists (select 1 from message_table where id_message = 120024 and id_language=13);
PROMPT *** Insert PK: 120025   Form/Menu: soswhst  ***
Insert into MESSAGE_TABLE (id_message,ID_LANGUAGE,v_message)  
select 120025,3,'FREEZER' from dual 
where not exists (select 1 from message_table where id_message = 120025 and id_language=3);
Insert into MESSAGE_TABLE (id_message,ID_LANGUAGE,v_message)  
select 120025,12,'Surgelé' from dual 
where not exists (select 1 from message_table where id_message = 120025 and id_language=12);
Insert into MESSAGE_TABLE (id_message,ID_LANGUAGE,v_message)  
select 120025,13,'??Spanish' from dual 
where not exists (select 1 from message_table where id_message = 120025 and id_language=13);
PROMPT *** Insert PK: 120021   Form/Menu: soswhst  ***
Insert into MESSAGE_TABLE (id_message,ID_LANGUAGE,v_message)  
select 120021,3,'Selector ID' from dual 
where not exists (select 1 from message_table where id_message = 120021 and id_language=3);
Insert into MESSAGE_TABLE (id_message,ID_LANGUAGE,v_message)  
select 120021,12,'Utilisateur' from dual
where not exists (select 1 from message_table where id_message = 120021 and id_language=12);
Insert into MESSAGE_TABLE (id_message,ID_LANGUAGE,v_message)  
select 120021,13,'??Spanish' from dual 
where not exists (select 1 from message_table where id_message = 120021 and id_language=13);
PROMPT *** Insert PK: 120022   Form/Menu: soswhst  ***
Insert into MESSAGE_TABLE (id_message,ID_LANGUAGE,v_message)  
select 120022,3,'Batch' from dual 
where not exists (select 1 from message_table where id_message = 120022 and id_language=3);
Insert into MESSAGE_TABLE (id_message,ID_LANGUAGE,v_message)  
select 120022,12,'Tâche' from dual 
where not exists (select 1 from message_table where id_message = 120022 and id_language=12);
Insert into MESSAGE_TABLE (id_message,ID_LANGUAGE,v_message)  
select 120022,13,'??Spanish' from dual 
where not exists (select 1 from message_table where id_message = 120022 and id_language=13);
COMMIT;
