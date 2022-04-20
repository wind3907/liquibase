/****************************************************************************
** File:       Jira371_DML_Message_FlexGoal_time.sql
**
** Desc: Script to insert message data
**
**
** Modification History:
**    Date        Designer           Comments
**    -------- -------- ----------------------------------------------------
**    
**    21-May-2018 Vishnupriya K.    Insert the messages for FlexGoal time
**
****************************************************************************/
REM
REM User--PRIYA on 05/22/2018 15:52 generated script to insert table: MESSAGE_TABLE
PROMPT *** Insert PK: 120123   Form/Menu: batch  ***
Insert into MESSAGE_TABLE (id_message,ID_LANGUAGE,v_message)  
select 120123,3,'Cannot move to hold due to waiting on Flex goal time data' from dual 
where not exists (select 1 from message_table where id_message = 120123 and id_language=3);
Insert into MESSAGE_TABLE (id_message,ID_LANGUAGE,v_message)  
select 120123,12,'??Ca-Fr' from dual 
where not exists (select 1 from message_table where id_message = 120123 and id_language=12);
Insert into MESSAGE_TABLE (id_message,ID_LANGUAGE,v_message)  
select 120123,13,'??Spanish' from dual 
where not exists (select 1 from message_table where id_message = 120123 and id_language=13);
COMMIT;
