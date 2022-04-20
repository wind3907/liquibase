/****************************************************************************
** File:       R30_6_7_DDL_Jira2218_add_ship_date.sql
*
** Desc: Script creates  column,  SHIP_DATE and add to INV table
**
** Modification History:
**    Date        Designer           Comments
**    ----------- --------     ------------------------------------------
**    06/12/19     knha8378     add SHIP_DATE to INV table
****************************************************************************/

DECLARE
  v_column_exists NUMBER := 0;  
  BEGIN
  SELECT COUNT(*)
  INTO v_column_exists
  FROM user_tab_cols
  WHERE column_name  = 'SHIP_DATE'
        AND table_name = 'INV';

  IF (v_column_exists = 0)
  THEN
    EXECUTE IMMEDIATE 'ALTER TABLE SWMS.INV ADD (SHIP_DATE DATE)';
	  
	
  END IF;

 END;
/
