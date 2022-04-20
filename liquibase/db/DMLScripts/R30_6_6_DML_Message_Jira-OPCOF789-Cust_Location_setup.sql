REM
REM User--KIET on 04/08/2019 17:55 generated script to insert table: MESSAGE_TABLE
PROMPT *** Insert PK: 120155   Form/Menu: SYSCO_MENU.mmb  ***
Insert into MESSAGE_TABLE (id_message,ID_LANGUAGE,v_message)  
select 120155,3,'Syspar setting for Finish Goods Enabled flag is turned off. This functionality is not available.' from dual 
where not exists (select 1 from message_table where id_message = 120155 and id_language=3);
Insert into MESSAGE_TABLE (id_message,ID_LANGUAGE,v_message)  
select 120155,12,'??Ca-Fr-Syspar setting for Finish Goods Enabled flag is turned off. This functionality is not available.' from dual 
where not exists (select 1 from message_table where id_message = 120155 and id_language=12);
Insert into MESSAGE_TABLE (id_message,ID_LANGUAGE,v_message)  
select 120155,13,'??Spanish--Syspar setting for Finish Goods Enabled flag is turned off. This functionality is not available.' from dual 
where not exists (select 1 from message_table where id_message = 120155 and id_language=13);
COMMIT;
