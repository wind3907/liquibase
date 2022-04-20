/****************************************************************************
** File: R30_6_9_1_SMOD3010_DDL_alter_ordcw_hist_table.sql
*
** Desc: Add new columns to ORDCW_HIST table to correspond with ORDCW table.
**
** Modification History:
**    Date           Designer           Comments
**    -----------    --------     ------------------------------------------
**    05/27/2020     jkar6681     added PKG_SHORT_USED column to table ORDCW_HIST
****************************************************************************/

--------------------------------------------------------------------------
-- Add column PKG_SHORT_USED to ORDCW_HIST
--------------------------------------------------------------------------

DECLARE
  v_column_exists NUMBER := 0;
 BEGIN 
	/* Add new column in ORDCW_HIST */
	SELECT COUNT(*)
    INTO v_column_exists
    FROM user_tab_cols
    WHERE column_name = 'PKG_SHORT_USED'
        AND table_name = 'ORDCW_HIST';
    IF v_column_exists = 0 THEN
        EXECUTE IMMEDIATE 'ALTER TABLE SWMS.ORDCW_HIST ADD PKG_SHORT_USED CHAR(1 CHAR)';
    END IF;
END;
/
