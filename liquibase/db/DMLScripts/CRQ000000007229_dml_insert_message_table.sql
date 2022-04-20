/****************************************************************************
** Date:       02-Aug-2016
** File:       _dml_insert_message_table.sql
**
** Insert record in message table to handle Form error of collect_data.fmb.
**
** Records are inserted into tables:
**    - MESSAGE_TABLE
**
** Modification History:
**    Date     Developer Comments
**    -------- --------  ---------------------------------------------------
**    08/02/16 KRAJ6630  Initial version created. Charm 
**                       
****************************************************************************/
   Insert into SWMS.MESSAGE_TABLE    (ID_MESSAGE, V_MESSAGE, ID_LANGUAGE)
 Values (13390,' Date should be in MM/DD/YYYY format', 3);
   
   Insert into SWMS.MESSAGE_TABLE  (ID_MESSAGE, V_MESSAGE, ID_LANGUAGE)
 Values (13390,' La date devrait etre saisie en format MM/DD/YYYY ', 12);
   
    Insert into SWMS.MESSAGE_TABLE  (ID_MESSAGE, V_MESSAGE, ID_LANGUAGE)
 Values  (13391,'  Legal characters are 0-9 + and -. ', 3);
   
    Insert into SWMS.MESSAGE_TABLE (ID_MESSAGE, V_MESSAGE, ID_LANGUAGE)
 Values  (13391,'Caracteres legaux sont 0-9 + et -. ', 12);
   
    Insert into SWMS.MESSAGE_TABLE (ID_MESSAGE, V_MESSAGE, ID_LANGUAGE)
 Values (13392,' has an unhandled value.. ', 3);
   
   Insert into SWMS.MESSAGE_TABLE (ID_MESSAGE, V_MESSAGE, ID_LANGUAGE)
 Values (13392,'a une valeur $non geree$. ', 12);
 
     Insert into SWMS.MESSAGE_TABLE (ID_MESSAGE, V_MESSAGE, ID_LANGUAGE)
 Values (13393,' %s1 - %s2 ', 3);
   
   Insert into SWMS.MESSAGE_TABLE (ID_MESSAGE, V_MESSAGE, ID_LANGUAGE)
 Values (13393,' %s1 - %s2 ', 12);  
COMMIT;
   

