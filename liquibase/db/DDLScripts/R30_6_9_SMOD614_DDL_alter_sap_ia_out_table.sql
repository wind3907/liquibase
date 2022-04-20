/****************************************************************************
** File: R30_6_9_SMOD614_DDL_alter_sap_ia_out_table.sql
*
** Desc: Script makes changes to table SAP_IA_OUT related to Migrating Reader & Writer programs for Linux
**
** Modification History:
**    Date        Designer           Comments
**    ----------- --------     ------------------------------------------
**    10/10/19     igoo9289     added RECON_FLAG column to table SAP_IA_OUT
****************************************************************************/

DECLARE
  v_column_exists NUMBER := 0;
BEGIN
  SELECT COUNT(*)
  INTO v_column_exists
  FROM user_tab_cols
  WHERE column_name  in ('RECON_FLAG')
        AND table_name = 'SAP_IA_OUT';

  IF (v_column_exists = 0)
  THEN
    EXECUTE IMMEDIATE 'ALTER TABLE SWMS.SAP_IA_OUT ADD ( RECON_FLAG VARCHAR2(1 CHAR))';
	COMMIT;
  END IF;

END;
/
