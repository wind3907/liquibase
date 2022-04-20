REM
REM User--KIET on 04/16/2020 11:29 generated script to insert table: MESSAGE_TABLE
PROMPT *** Insert PK: 120169   Form/Menu: rtncls.fmb  ***
Insert into MESSAGE_TABLE (id_message,ID_LANGUAGE,v_message)  
select 120169,3,'All Return records must have CMP status in order for manifest to close. Please return to manifest detail for completion.' from dual 
where not exists (select 1 from message_table where id_message = 120169 and id_language=3);
Insert into MESSAGE_TABLE (id_message,ID_LANGUAGE,v_message)  
select 120169,12,'??Ca-Fr-All Return records must have CMP status in order for manifest to close. Please return to manifest detail for completion.' from dual 
where not exists (select 1 from message_table where id_message = 120169 and id_language=12);
Insert into MESSAGE_TABLE (id_message,ID_LANGUAGE,v_message)  
select 120169,13,'??Spanish--All Return records must have CMP status in order for manifest to close. Please return to manifest detail for completion.' from dual 
where not exists (select 1 from message_table where id_message = 120169 and id_language=13);
COMMIT;
