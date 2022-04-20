REM
REM User--ELAINE on 07/06/2018 09:48 generated script to insert table: MESSAGE_TABLE
PROMPT *** Insert PK: 120128   Form/Menu: RP1SA  ***
Insert into MESSAGE_TABLE (id_message,ID_LANGUAGE,v_message)  
select 120128,3,'Can not close internal PO manually' from dual 
where not exists (select 1 from message_table where id_message = 120128 and id_language=3);
Insert into MESSAGE_TABLE (id_message,ID_LANGUAGE,v_message)  
select 120128,12,'??Ca-FrCan not close internal PO manually' from dual 
where not exists (select 1 from message_table where id_message = 120128 and id_language=12);
Insert into MESSAGE_TABLE (id_message,ID_LANGUAGE,v_message)  
select 120128,13,'??SpanishCan not close internal PO manually' from dual 
where not exists (select 1 from message_table where id_message = 120128 and id_language=13);
COMMIT;
