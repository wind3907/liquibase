REM
REM User--MICHAEL on 10/24/2017 10:46 generated script to insert table: MESSAGE_TABLE
PROMPT *** Insert PK: 120046   Form/Menu: mn1sa  ***
Insert into MESSAGE_TABLE (id_message,ID_LANGUAGE,v_message)  
select 120046,3,'IND is less than %s1 minutes.' from dual 
where not exists (select 1 from message_table where id_message = 120046 and id_language=3);
Insert into MESSAGE_TABLE (id_message,ID_LANGUAGE,v_message)  
select 120046,12,'IND est inferieur a %s1 minutes.' from dual 
where not exists (select 1 from message_table where id_message = 120046 and id_language=12);
Insert into MESSAGE_TABLE (id_message,ID_LANGUAGE,v_message)  
select 120046,13,'??Spanish IND is less than %s1 minutes.' from dual 
where not exists (select 1 from message_table where id_message = 120046 and id_language=13);

REM
REM User--MICHAEL on 11/09/2017 17:02 generated script to insert table: MESSAGE_TABLE
PROMPT *** Insert PK: 120059   Form/Menu: mn1sa  ***
Insert into MESSAGE_TABLE (id_message,ID_LANGUAGE,v_message)  
select 120059,3,'Cannot find IND transaction nor replenishment task. Please choose a temporary reserve location so that this inventory can be adjusted as needed.' from dual 
where not exists (select 1 from message_table where id_message = 120059 and id_language=3);
Insert into MESSAGE_TABLE (id_message,ID_LANGUAGE,v_message)  
select 120059,12,'??Ca-Fr Cannot find IND transaction nor replenishment task. Please choose a temporary reserve location so that this inventory can be adjusted as needed' from dual 
where not exists (select 1 from message_table where id_message = 120059 and id_language=12);
Insert into MESSAGE_TABLE (id_message,ID_LANGUAGE,v_message)  
select 120059,13,'??Spanish Cannot find IND transaction nor replenishment task. Please choose a temporary reserve location so that this inventory can be adjusted as needed' from dual 
where not exists (select 1 from message_table where id_message = 120059 and id_language=13);
COMMIT;
