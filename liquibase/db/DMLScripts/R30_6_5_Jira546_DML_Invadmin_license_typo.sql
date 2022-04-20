/****************************************************************************
** Date:       27-Sep-2018
** File:       Jira546_DML_Invadmin_license_typo.sql
**
** Script to update message/hint in message table for mia1sa 
**
** 
**
** Modification History:
**    Date        Designer           Comments
**    -------- -------- ---------------------------------------------------
**    27-Sep-2018 Sban3548          Corrected the typo error with license    
**
****************************************************************************/
REM
PROMPT *** Updating message_table with License typo error for message id 4460 english ***

    UPDATE message_table 
    SET v_message='Item # License #' 
    WHERE id_message=4460
    AND ID_LANGUAGE=3
    AND EXISTS ( SELECT 1 FROM message_table 
                 WHERE v_message='Item # Lisence #'
                 AND id_message=4460
                 AND ID_LANGUAGE=3 );   

    COMMIT;

