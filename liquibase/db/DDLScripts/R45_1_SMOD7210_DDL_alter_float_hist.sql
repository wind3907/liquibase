/****************************************************************************
** File: R45_1_SMOD7210_DDL_alter_float_hist.sql
*
** Desc: Script makes changes to QTY_SHORT_ON_SHORT column in FLOAT_HIST 
** to allow qhort on short of item with spc > 999.
**
** Modification History:
**    Date        Designer           Comments
**    ----------- --------     ------------------------------------------
**    07/16/21    nsel0716     Altered qty_short_on_short length to NUMBER (9)	
****************************************************************************/

DECLARE
  v_column_exists NUMBER := 0;
BEGIN

   SELECT COUNT(*)
   INTO v_column_exists
   FROM user_tab_cols
   WHERE column_name = 'QTY_SHORT_ON_SHORT'
     AND table_name  = 'FLOAT_HIST';

   IF (v_column_exists = 1) THEN
      EXECUTE IMMEDIATE 'ALTER TABLE FLOAT_HIST MODIFY QTY_SHORT_ON_SHORT NUMBER(9)';
   END IF;

END;
/
