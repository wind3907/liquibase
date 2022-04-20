SET ECHO OFF
SET LINESIZE 300
SET PAGESIZE 60
SET SERVEROUTPUT ON SIZE UNLIMITED
/*
**********************************************************************************
** File:       R47_DML_OPCO3376_msg_table.sql
**
** Purpose:    Add message to stop order gen for missing route info
**
** Modification History:
**   Date         Designer  Comments
**   -----------  --------- ------------------------------------------------------
**   07/07/2021   pdas8114  S4R - OPCOF-3376 Don't Generate X-dock Order at SWMS1 w/o SWMS2 Stop/trk
**********************************************************************************
*/

Insert into MESSAGE_TABLE
   (ID_MESSAGE, V_MESSAGE, ID_LANGUAGE)
SELECT 120176, 'Cannot generate route due to missing cross dock info for route #', 3 FROM DUAL
    WHERE NOT EXISTS (SELECT 1 FROM MESSAGE_TABLE WHERE ID_MESSAGE = 120176 AND ID_LANGUAGE = 3);

Insert into MESSAGE_TABLE
   (ID_MESSAGE, V_MESSAGE, ID_LANGUAGE)
SELECT 120176, '??Cannot generate route due to missing cross dock info for route #', 12 FROM DUAL
    WHERE NOT EXISTS (SELECT 1 FROM MESSAGE_TABLE WHERE ID_MESSAGE = 120176 AND ID_LANGUAGE = 12);	

Insert into MESSAGE_TABLE
   (ID_MESSAGE, V_MESSAGE, ID_LANGUAGE)
SELECT 120176, '??Cannot generate route due to missing cross dock info for route #', 13 FROM DUAL
    WHERE NOT EXISTS (SELECT 1 FROM MESSAGE_TABLE WHERE ID_MESSAGE = 120176 AND ID_LANGUAGE = 13);
COMMIT;
