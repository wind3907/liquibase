/****************************************************************************
** Date:       24-May-2016
** File:       6000009943_dml_update_message_dod.sql
**
** Insert new system parameter for DOD project.
**
** Records updated into table:
**    - MESSAGE_TABLE
**
** Modification History:
**    Date     Developer Comments
**    -------- --------  ---------------------------------------------------
**    05/24/16 skam7488  Initial version created. Charm 6000009943
**                       corrected the spelling in message_table entry
****************************************************************************/

UPDATE SWMS.MESSAGE_TABLE
SET V_MESSAGE = 'Printing the labels to printer: %s1'
WHERE ID_MESSAGE = 119971
AND   ID_LANGUAGE = 3;

UPDATE SWMS.MESSAGE_TABLE
SET V_MESSAGE = 'Impression des étiquettes à l''imprimante: %s1'
WHERE ID_MESSAGE = 119971
AND   ID_LANGUAGE = 12;

COMMIT;
