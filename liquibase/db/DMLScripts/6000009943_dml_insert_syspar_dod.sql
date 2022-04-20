/****************************************************************************
** Date:       06-May-2016
** File:       6000009943_dml_insert_syspar_dod.sql
**
** Insert new system parameter for DOD project.
**
** Records are inserted into tables:
**    - SYS_CONFIG
**
** Modification History:
**    Date     Developer Comments
**    -------- --------  ---------------------------------------------------
**    05/06/16 skam7488  Initial version created. Charm 6000009943
**                       Insert DOD_ENABLED_APCOM into SYS_CONFIG
****************************************************************************/

Insert into SWMS.SYS_CONFIG
   (SEQ_NO, APPLICATION_FUNC, CONFIG_FLAG_NAME, CONFIG_FLAG_DESC, CONFIG_FLAG_VAL, 
    VALUE_REQUIRED, VALUE_UPDATEABLE, VALUE_IS_BOOLEAN, DATA_TYPE, DATA_PRECISION, 
    DATA_SCALE, SYS_CONFIG_LIST, VALIDATION_TYPE)
 Values
   ((SELECT MAX(seq_no)+1 FROM SYS_CONFIG), 'INTERFACE', 'DOD_ENABLED_APCOM', 
   'Apcom with DOD info (Y/N)', 'N', 
    'Y', 'N', 'Y', 'CHAR', 1, 
    0, 'L', 'LIST');
COMMIT;
