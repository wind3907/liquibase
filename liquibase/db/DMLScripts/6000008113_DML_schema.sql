/****************************************************************************
** Date:       11-Sep-2015
** File:       Charm-6000008113_DML_dba_schema.sql
**
**             Script to 
**             1. Modify 'Prompt_Text' of item MASTER.PALLET_ID from 'Licence #:' to 'License #:'
**
**    - SCRIPTS
**
**    Modification History:
**    Date      Designer Comments
**    --------  -------- --------------------------------------------------- **    
**    11-Sep-2015 CHUA6448 Charm#6000008113
**                       Project: Correct spelling of License in SWMS_Maintenance
**
****************************************************************************/

UPDATE ml_values SET TEXT='License #:' where fk_ml_modules=7495 and id_functionality=15 AND ID_LANGUAGE=3;

COMMIT;
