REM
REM User--ELAINE on 04/26/2019 09:52 generated script to insert table: MESSAGE_TABLE
PROMPT *** Insert PK: 120156   Form/Menu: ML2SA  ***
Insert into MESSAGE_TABLE (id_message,ID_LANGUAGE,v_message)  
select 120156,3,'Can not change existing rule ID(9,10,11,13,14)' from dual 
where not exists (select 1 from message_table where id_message = 120156 and id_language=3);
Insert into MESSAGE_TABLE (id_message,ID_LANGUAGE,v_message)  
select 120156,12,'??Ca-Fr' from dual 
where not exists (select 1 from message_table where id_message = 120156 and id_language=12);
Insert into MESSAGE_TABLE (id_message,ID_LANGUAGE,v_message)  
select 120156,13,'??Spanish' from dual 
where not exists (select 1 from message_table where id_message = 120156 and id_language=13);
COMMIT;
