REM
REM User--MICHAEL on 12/10/2018 15:51 generated script to insert table: MESSAGE_TABLE
PROMPT *** Insert PK: 120153   Form/Menu: rp1sa  ***
Insert into MESSAGE_TABLE (id_message,ID_LANGUAGE,v_message)  
select 120153,3,'Cannot close finish good PO manually. PO is not complete.' from dual 
where not exists (select 1 from message_table where id_message = 120153 and id_language=3);

Insert into MESSAGE_TABLE (id_message,ID_LANGUAGE,v_message)  
select 120153,12,'??Ca-Fr' from dual 
where not exists (select 1 from message_table where id_message = 120153 and id_language=12);

Insert into MESSAGE_TABLE (id_message,ID_LANGUAGE,v_message)  
select 120153,13,'??Spanish' from dual 
where not exists (select 1 from message_table where id_message = 120153 and id_language=13);

insert into rec_type (rec_type, descrip) 
select 'FG', 'Finish Good PO' from dual 
where not exists (select 1 from rec_type where rec_type = 'FG'); 
COMMIT;
