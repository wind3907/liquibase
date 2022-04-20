REM
REM User--KIET on 09/20/2017 15:00 generated script to insert table: MESSAGE_TABLE
PROMPT *** Insert PK: 120000   Form/Menu: ob1ri  ***
Insert into MESSAGE_TABLE (id_message,ID_LANGUAGE,v_message)  
select 120000,3,'Please enter the TO DATE either same or after the FROM DATE. Invalid TO DATE.' from dual 
where not exists (select 1 from message_table where id_message = 120000 and id_language=3);
Insert into MESSAGE_TABLE (id_message,ID_LANGUAGE,v_message)  
select 120000,12,'Please enter the TO DATE either same or after the FROM DATE. Invalid TO DATE.' from dual 
where not exists (select 1 from message_table where id_message = 120000 and id_language=12);
Insert into MESSAGE_TABLE (id_message,ID_LANGUAGE,v_message)  
select 120000,13,'??Spanish' from dual 
where not exists (select 1 from message_table where id_message = 120000 and id_language=13);
PROMPT *** Insert PK: 120001   Form/Menu: ob1ri  ***
Insert into MESSAGE_TABLE (id_message,ID_LANGUAGE,v_message)  
select 120001,3,'Enter invalid From or To Date.' from dual 
where not exists (select 1 from message_table where id_message = 120001 and id_language=3);
Insert into MESSAGE_TABLE (id_message,ID_LANGUAGE,v_message)  
select 120001,12,'??Ca-Fr-Enter invalid From or To Date.' from dual 
where not exists (select 1 from message_table where id_message = 120001 and id_language=12);
Insert into MESSAGE_TABLE (id_message,ID_LANGUAGE,v_message)  
select 120001,13,'??Spanish' from dual 
where not exists (select 1 from message_table where id_message = 120001 and id_language=13);
COMMIT;
