/****************************************************************************
**
** Desc: Script adds MEAT column to table RULES
**
** Modification History:
**    Date        Designer           Comments
**    -----------    --------     ------------------------------------------
**    Oct 30 2019 vkal9662          add below column to table RULES
**                                   (AUTO_CONFRM)
**       
****************************************************************************/

DECLARE
  v_column_exists NUMBER := 0;  
  BEGIN
  SELECT COUNT(*)
  INTO v_column_exists
  FROM user_tab_cols
  WHERE column_name = 'AUTO_CONFRM'
  AND table_name = 'RULES';

  IF (v_column_exists = 0)  THEN
    EXECUTE IMMEDIATE 'ALTER TABLE SWMS.RULES ADD AUTO_CONFRM varchar2(1)';
  END IF;
 END;
/ 



