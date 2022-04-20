/****************************************************************************
** File:       Jira327_DML_Message_food_contam_forms.sql
**
** Desc: Script to insert message data
**
**
** Modification History:
**    Date        Designer           Comments
**    -------- -------- ----------------------------------------------------
**    
**    21-May-2018 Vishnupriya K.    Insert the messages for food contamination forms
**
****************************************************************************/
REM
REM User--PRIYA on 05/22/2018 13:14 generated script to insert table: MESSAGE_TABLE
PROMPT *** Insert PK: 120120   Form/Menu: swap  ***
Insert into MESSAGE_TABLE (id_message,ID_LANGUAGE,v_message)  
select 120120,3,'Cannot transfer from/to restricted zone(s):' from dual 
where not exists (select 1 from message_table where id_message = 120120 and id_language=3);
Insert into MESSAGE_TABLE (id_message,ID_LANGUAGE,v_message)  
select 120120,12,'??Ca-Fr' from dual 
where not exists (select 1 from message_table where id_message = 120120 and id_language=12);
Insert into MESSAGE_TABLE (id_message,ID_LANGUAGE,v_message)  
select 120120,13,'??Spanish' from dual 
where not exists (select 1 from message_table where id_message = 120120 and id_language=13);
COMMIT;
