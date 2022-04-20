/****************************************************************************
** File: R46_0_OPCOF3530_DDL_alter_float_detail_table_for_CFA.sql
*
** Desc: Add new column GS1_TRK to Float_Detail table for CFA
**
** Modification History:
**    Date           Designer           Comments
**    -----------    --------     ------------------------------------------
**    08/16/2021     Sraj8407     added GS1_TRK column to table Float_Detail
****************************************************************************/

--------------------------------------------------------------------------
-- Add column GS1_TRK to FLOAT_DETAIL TABLE
--------------------------------------------------------------------------

DECLARE
  v_column_exists NUMBER := 0;
 BEGIN 
	/* Add new column in FLOAT_DETAIL */
	SELECT COUNT(*)
    INTO v_column_exists
    FROM user_tab_cols
    WHERE column_name = 'GS1_TRK'
        AND table_name = 'FLOAT_DETAIL';
    IF v_column_exists = 0 THEN
        EXECUTE IMMEDIATE 'ALTER TABLE SWMS.FLOAT_DETAIL ADD GS1_TRK VARCHAR2(1 CHAR)';
    END IF;
END;
/