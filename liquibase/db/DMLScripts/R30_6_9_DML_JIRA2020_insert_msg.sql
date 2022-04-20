REM
REM User--ELAINE on 12/04/2019 14:14 generated script to insert table: MESSAGE_TABLE
PROMPT *** Insert PK: 120165   Form/Menu: RTNSCLS  ***
Insert into MESSAGE_TABLE (id_message,ID_LANGUAGE,v_message)  
select 120165,3,'Temperature is not collected for items.  Click OK to collect the Temperature.' from dual 
where not exists (select 1 from message_table where id_message = 120165 and id_language=3);
Insert into MESSAGE_TABLE (id_message,ID_LANGUAGE,v_message)  
select 120165,12,'La temperature n''est pas collectee pour les articles. Cliquez sur OK pour collecter la temperature.' from dual 
where not exists (select 1 from message_table where id_message = 120165 and id_language=12);
Insert into MESSAGE_TABLE (id_message,ID_LANGUAGE,v_message)  
select 120165,13,'La temperatura no se recoge para los articulos. Haga clic en Aceptar para recopilar la temperatura' from dual 
where not exists (select 1 from message_table where id_message = 120165 and id_language=13);
PROMPT *** Insert PK: 120166   Form/Menu: RTNSFSD  ***
Insert into MESSAGE_TABLE (id_message,ID_LANGUAGE,v_message)  
select 120166,3,'Temperature is not collected yet, can not close manifest.' from dual 
where not exists (select 1 from message_table where id_message = 120166 and id_language=3);
Insert into MESSAGE_TABLE (id_message,ID_LANGUAGE,v_message)  
select 120166,12,'La temperature n''est pas encore collectee, ne peut pas fermer manifeste.' from dual 
where not exists (select 1 from message_table where id_message = 120166 and id_language=12);
Insert into MESSAGE_TABLE (id_message,ID_LANGUAGE,v_message)  
select 120166,13,'La temperatura aun no se ha recogido, no se puede cerrar el manifiesto.' from dual 
where not exists (select 1 from message_table where id_message = 120166 and id_language=13);
COMMIT;

