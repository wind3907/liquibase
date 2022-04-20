REM
REM User--PRIYA on 07/07/2020 16:34 generated script to insert table: MESSAGE_TABLE
--PROMPT *** Insert PK: 120171   Form/Menu: MA2MA  ***
Insert into MESSAGE_TABLE (id_message,ID_LANGUAGE,v_message)  
select 120171,3,'Rule Maintenance flag is set to N for this Aisle, it cannot be deleted.' from dual 
where not exists (select 1 from message_table where id_message = 120171 and id_language=3);
Insert into MESSAGE_TABLE (id_message,ID_LANGUAGE,v_message)  
select 120171,12,'Lindicateur de maintenance des regles est defini sur N pour cette allee, il ne peut pas etre supprime' from dual 
where not exists (select 1 from message_table where id_message = 120171 and id_language=12);
Insert into MESSAGE_TABLE (id_message,ID_LANGUAGE,v_message)  
select 120171,13,'??Spanish' from dual 
where not exists (select 1 from message_table where id_message = 120171 and id_language=13);

--PROMPT *** Insert PK: 120172   Form/Menu: MA2MA  ***
Insert into MESSAGE_TABLE (id_message,ID_LANGUAGE,v_message)  
select 120172,3,'Locations exist for this Aisle, it cannot be deleted.' from dual 
where not exists (select 1 from message_table where id_message = 120172 and id_language=3);
Insert into MESSAGE_TABLE (id_message,ID_LANGUAGE,v_message)  
select 120172,12,'Des emplacements existent pour cette allee, elle ne peut pas etre supprimee.' from dual 
where not exists (select 1 from message_table where id_message = 120172 and id_language=12);
Insert into MESSAGE_TABLE (id_message,ID_LANGUAGE,v_message)  
select 120172,13,'??Spanish' from dual 
where not exists (select 1 from message_table where id_message = 120172 and id_language=13);

COMMIT;
