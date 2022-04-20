/****************************************************************************
** Date:       08-Sep-2016
** File:       CRQ000000007691_dml_message_table.sql
**
**             Script to 
**             1. Add new message into message_table
**
**    - SCRIPTS
**
**    Modification History:
**    Date      	Designer	Comments
**    -----------  	--------	------------------------------------------ **    
**    08-Sep-2016	spot3255 	CRQ000000007691: Labor batch deletion charm requirements
**
****************************************************************************/
Insert into SWMS.MESSAGE_TABLE
   (ID_MESSAGE, V_MESSAGE, ID_LANGUAGE)
 Values
   (119979, '%s1 batches are not deleted due to OPN or SHT route', 3);
Insert into SWMS.MESSAGE_TABLE
   (ID_MESSAGE, V_MESSAGE, ID_LANGUAGE)
 Values
   (119979, 'lots %s1 ne sont pas supprimés en raison de OPN ou SHT itinéraire', 12);
COMMIT;

