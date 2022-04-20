REM
REM User--ELAINE on 05/22/2018 13:27 generated script to insert table: MESSAGE_TABLE
PROMPT *** Insert PK: 120121   Form/Menu: MC3CD  ***
Insert into MESSAGE_TABLE (id_message,ID_LANGUAGE,v_message)  
select 120121,3,'Can not delete Restrict Zone: %s1 exists in Zone Overview' from dual 
where not exists (select 1 from message_table where id_message = 120121 and id_language=3);
Insert into MESSAGE_TABLE (id_message,ID_LANGUAGE,v_message)  
select 120121,12,'??Ca-FrCan not delete Restrict Zone: %s1 exists in Zone Overview' from dual 
where not exists (select 1 from message_table where id_message = 120121 and id_language=12);
Insert into MESSAGE_TABLE (id_message,ID_LANGUAGE,v_message)  
select 120121,13,'??SpanishCan not delete Restrict Zone: %s1 exists in Zone Overview' from dual 
where not exists (select 1 from message_table where id_message = 120121 and id_language=13);
PROMPT *** Insert PK: 120122   Form/Menu: MC3CD  ***
Insert into MESSAGE_TABLE (id_message,ID_LANGUAGE,v_message)  
select 120122,3,'Restrict Zone: %s1 already exist' from dual 
where not exists (select 1 from message_table where id_message = 120122 and id_language=3);
Insert into MESSAGE_TABLE (id_message,ID_LANGUAGE,v_message)  
select 120122,12,'??Ca-FrRestrict Zone: %s1 already exist' from dual 
where not exists (select 1 from message_table where id_message = 120122 and id_language=12);
Insert into MESSAGE_TABLE (id_message,ID_LANGUAGE,v_message)  
select 120122,13,'??SpanishRestrict Zone: %s1 already exist' from dual 
where not exists (select 1 from message_table where id_message = 120122 and id_language=13);
COMMIT;
