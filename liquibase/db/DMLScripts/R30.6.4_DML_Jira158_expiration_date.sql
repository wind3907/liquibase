insert into swms_alert_notification (modules, error_type, create_ticket, send_email, primary_recipient, alternate_recipient)
select 'EXPIRATION_DATE', 'WARN', 'N', 'N', null, null from dual
where not exists (select 1 from swms_alert_notification where modules = 'EXPIRATION_DATE');
commit;


REM
REM User--MICHAEL on 05/03/2018 09:48 generated script to insert table: MESSAGE_TABLE
PROMPT *** Insert PK: 120119   Form/Menu: collect_data  ***
Insert into MESSAGE_TABLE (id_message,ID_LANGUAGE,v_message)  
select 120119,3,'Expiration Date Warning for Item %s1 on LPN %s2 in PO#%s3' from dual 
where not exists (select 1 from message_table where id_message = 120119 and id_language=3);
Insert into MESSAGE_TABLE (id_message,ID_LANGUAGE,v_message)  
select 120119,12,'??Ca-Fr Expiration Date Warning for Item %s1 on LPN %s2 in PO#%s3' from dual 
where not exists (select 1 from message_table where id_message = 120119 and id_language=12);
Insert into MESSAGE_TABLE (id_message,ID_LANGUAGE,v_message)  
select 120119,13,'??Spanish Expiration Date Warning for Item %s1 on LPN %s2 in PO#%s3' from dual 
where not exists (select 1 from message_table where id_message = 120119 and id_language=13);
COMMIT;


Insert into MESSAGE_TABLE (id_message,ID_LANGUAGE,v_message)
select 120116, 3, 'Please verify item#%s1 on LPN %s2 in PO#%s3.' || chr(10) || 'The expiration date [%s4] is more than 7 days over the receive date.' from dual
where not exists (select 1 from message_table where id_message = 120116 and id_language=3);
Insert into MESSAGE_TABLE (id_message,ID_LANGUAGE,v_message)
select 120116, 12, '??Ca-Fr Please verify item#%s1 on LPN %s2 in PO#%s3.' || chr(10) || 'The expiration date [%s4] is more than 7 days over the receive date.' from dual
where not exists (select 1 from message_table where id_message = 120116 and id_language=12);
Insert into MESSAGE_TABLE (id_message,ID_LANGUAGE,v_message)
select 120116, 13, '??Spanish Please verify item#%s1 on LPN %s2 in PO#%s3.' || chr(10) || 'The expiration date [%s4] is more than 7 days over the receive date.' from dual
where not exists (select 1 from message_table where id_message = 120116 and id_language=13);

COMMIT;