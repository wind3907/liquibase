/****************************************************************************
** File:       CRQ31703_DDL_ALTER_manifest_tables.sql
**
** Desc: Script creates a column POD_FLAG in MANIFEST_STOPS, MANIFEST_DTLS tables 
**       to hold vales Y,N or NULL.
**
** Modification History:
**    Date        Designer           Comments
**    --------    --------     ---------------------------------------------------
**    26/05/17    CHYD9155          POD_FLAG added to tables 
**                                  MANIFEST_STOPS, MANIFEST_DTLS
**    06/12/17	  CHYD9155          DDL and DML standardization for merge                    
****************************************************************************/

DECLARE
  v_column_exists NUMBER := 0;
BEGIN
  SELECT COUNT(*)
  INTO v_column_exists
  FROM user_tab_cols
  WHERE column_name = 'POD_FLAG'
        AND table_name = 'MANIFEST_DTLS';

  IF (v_column_exists = 0)
  THEN
    EXECUTE IMMEDIATE 'ALTER TABLE SWMS.MANIFEST_DTLS ADD POD_FLAG char(1 char) NULL';
  END IF;
END;
/

DECLARE
  v_column_exists NUMBER := 0;
BEGIN
  SELECT COUNT(*)
  INTO v_column_exists
  FROM user_tab_cols
  WHERE column_name = 'POD_FLAG'
        AND table_name = 'MANIFEST_STOPS';

  IF (v_column_exists = 0)
  THEN
    EXECUTE IMMEDIATE 'ALTER TABLE SWMS.MANIFEST_STOPS ADD POD_FLAG char(1 char) NULL';
  END IF;
END;
/




