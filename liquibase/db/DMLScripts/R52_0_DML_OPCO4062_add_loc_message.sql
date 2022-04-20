SET ECHO OFF
SET LINESIZE 300
SET PAGESIZE 60
SET SERVEROUTPUT ON SIZE UNLIMITED
/*
**********************************************************************************
** File:       R52_0_DML_OPCO4062_add_loc_message.sql
**
** Purpose:    Add message for wrong zone is selected for location with a location status of RAC
**
** Modification History:
**   Date         Designer  Comments
**   -----------  --------- ------------------------------------------------------
**   03/11/2022   kchi7065  Created opcof 4062
**********************************************************************************
*/

define v_ID_MESSAGE = 120177

Insert into MESSAGE_TABLE
   (ID_MESSAGE, V_MESSAGE, ID_LANGUAGE)
SELECT &v_ID_MESSAGE, 'Locations with the Mobile Rack Status must use the appropriate zone. ', 3 FROM DUAL
    WHERE NOT EXISTS (SELECT 1 FROM MESSAGE_TABLE WHERE ID_MESSAGE = &v_ID_MESSAGE AND ID_LANGUAGE = 3);

Insert into MESSAGE_TABLE
   (ID_MESSAGE, V_MESSAGE, ID_LANGUAGE)
SELECT &v_ID_MESSAGE, 'Les emplacements avec l''etat du rack mobile doivent utiliser la zone appropriee.', 12 FROM DUAL
    WHERE NOT EXISTS (SELECT 1 FROM MESSAGE_TABLE WHERE ID_MESSAGE = &v_ID_MESSAGE AND ID_LANGUAGE = 12);	


define v_ID_MESSAGE = 120178

Insert into MESSAGE_TABLE
   (ID_MESSAGE, V_MESSAGE, ID_LANGUAGE)
SELECT &v_ID_MESSAGE, 'Locations with the Mobile Rack Status must be non-picking location. ', 3 FROM DUAL
    WHERE NOT EXISTS (SELECT 1 FROM MESSAGE_TABLE WHERE ID_MESSAGE = &v_ID_MESSAGE AND ID_LANGUAGE = 3);

Insert into MESSAGE_TABLE
   (ID_MESSAGE, V_MESSAGE, ID_LANGUAGE)
SELECT &v_ID_MESSAGE, 'Les emplacements avec l''etat de rack mobile doivent etre des emplacements non picking.', 12 FROM DUAL
    WHERE NOT EXISTS (SELECT 1 FROM MESSAGE_TABLE WHERE ID_MESSAGE = &v_ID_MESSAGE AND ID_LANGUAGE = 12);