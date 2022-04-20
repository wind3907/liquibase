REM
REM User--MICHAEL on 02/19/2018 15:05 generated script to insert table: MESSAGE_TABLE
PROMPT *** Insert PK: 120095   Form/Menu: batches_hold  ***
Insert into MESSAGE_TABLE (id_message,ID_LANGUAGE,v_message)  
select 120095,3,'Batches On Hold' from dual 
where not exists (select 1 from message_table where id_message = 120095 and id_language=3);
Insert into MESSAGE_TABLE (id_message,ID_LANGUAGE,v_message)  
select 120095,12,'??Ca-Fr' from dual 
where not exists (select 1 from message_table where id_message = 120095 and id_language=12);
Insert into MESSAGE_TABLE (id_message,ID_LANGUAGE,v_message)  
select 120095,13,'??Spanish' from dual 
where not exists (select 1 from message_table where id_message = 120095 and id_language=13);
COMMIT;

REM
REM User--MICHAEL on 02/22/2018 16:46 generated script to insert table: MESSAGE_TABLE
PROMPT *** Insert PK: 120096   Form/Menu: batches  ***
Insert into MESSAGE_TABLE (id_message,ID_LANGUAGE,v_message)  
select 120096,3,'Are you sure you want to move the selected future Loader batches to the holding screen?' from dual 
where not exists (select 1 from message_table where id_message = 120096 and id_language=3);
Insert into MESSAGE_TABLE (id_message,ID_LANGUAGE,v_message)  
select 120096,12,'??Ca-Fr' from dual 
where not exists (select 1 from message_table where id_message = 120096 and id_language=12);
Insert into MESSAGE_TABLE (id_message,ID_LANGUAGE,v_message)  
select 120096,13,'??Spanish' from dual 
where not exists (select 1 from message_table where id_message = 120096 and id_language=13);
COMMIT;
