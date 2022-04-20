REM
REM User--ELAINE on 01/08/2018 08:55 generated script to insert table: MESSAGE_TABLE
PROMPT *** Insert PK: 120071   Form/Menu: ml1ml  ***
Insert into MESSAGE_TABLE (id_message,ID_LANGUAGE,v_message)  
select 120071,3,'Pallet type, Case Qty Per Tray, Max ML Trays, SPC and TI, HI can not be null or 0' from dual 
where not exists (select 1 from message_table where id_message = 120071 and id_language=3);
Insert into MESSAGE_TABLE (id_message,ID_LANGUAGE,v_message)  
select 120071,12,'??Ca-Fr-Pallet type, Case Qty Per Tray, Max ML Trays, SPC and TI, HI can not be null or 0' from dual 
where not exists (select 1 from message_table where id_message = 120071 and id_language=12);
Insert into MESSAGE_TABLE (id_message,ID_LANGUAGE,v_message)  
select 120071,13,'??Spanish-Pallet type, Case Qty Per Tray, Max ML Trays, SPC and TI, HI can not be null or 0' from dual 
where not exists (select 1 from message_table where id_message = 120071 and id_language=13);
COMMIT;
