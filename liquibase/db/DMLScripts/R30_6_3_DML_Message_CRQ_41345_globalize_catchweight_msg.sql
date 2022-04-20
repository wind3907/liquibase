REM
REM User--MICHAEL on 12/07/2017 11:23 generated script to insert table: MESSAGE_TABLE
PROMPT *** Insert PK: 120067   Form/Menu: collect_data  ***
Insert into MESSAGE_TABLE (id_message,ID_LANGUAGE,v_message)  
select 120067,3,'Weight is out of tolerance range. Are you sure the weight %s1 is correct?
(Note: If correct, select YES then press F7 to commit.)' from dual 
where not exists (select 1 from message_table where id_message = 120067 and id_language=3);
Insert into MESSAGE_TABLE (id_message,ID_LANGUAGE,v_message)  
select 120067,12,'??Ca-Fr Weight is out of tolerance range. Are you sure the weight %s1 is correct?
(Note: If correct, select YES then press F7 to commit.)' from dual 
where not exists (select 1 from message_table where id_message = 120067 and id_language=12);
Insert into MESSAGE_TABLE (id_message,ID_LANGUAGE,v_message)  
select 120067,13,'??Spanish Weight is out of tolerance range. Are you sure the weight %s1 is correct?
(Note: If correct, select YES then press F7 to commit.)' from dual 
where not exists (select 1 from message_table where id_message = 120067 and id_language=13);
COMMIT;
