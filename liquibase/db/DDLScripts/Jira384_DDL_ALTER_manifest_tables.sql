/****************************************************************************
** File:       JIRA384_DDL_ALTER_manifest_return_tables.sql
**
** Desc: Script creates a column POD_RTN_IND, RTN_SENT_IND in RETURNS, MANIFEST_DTLS tables 
**       to hold vales ['A', 'C', 'U' OR NULL]  [Y,N or NULL] and ORG columns to hold original
**       transaction Values for the returns.
**
** Modification History:
**    Date        Designer           Comments
**    --------    --------     ---------------------------------------------------
**    29/03/18    vkal9662          POD_RTN_IND, RTN_SENT_IND added to tables 
**                                  Returns, MANIFEST_DTLS              
****************************************************************************/

DECLARE
  v_column_exists NUMBER := 0;
BEGIN
  SELECT COUNT(*)
  INTO v_column_exists
  FROM user_tab_cols
  WHERE column_name = 'ORG_RTN_REASON_CD'
        AND table_name = 'RETURNS';

  IF (v_column_exists = 0)
  THEN
    EXECUTE IMMEDIATE 'ALTER TABLE SWMS.RETURNS ADD ORG_RTN_REASON_CD VARCHAR2(3 char) NULL';
  END IF;
END;
/

DECLARE
  v_column_exists NUMBER := 0;
BEGIN
  SELECT COUNT(*)
  INTO v_column_exists
  FROM user_tab_cols
  WHERE column_name = 'ORG_RTN_QTY'
        AND table_name = 'RETURNS';

  IF (v_column_exists = 0)
  THEN
    EXECUTE IMMEDIATE 'ALTER TABLE SWMS.RETURNS ADD ORG_RTN_QTY NUMBER(4) NULL';
  END IF;
END;
/

DECLARE
  v_column_exists NUMBER := 0;
BEGIN
  SELECT COUNT(*)
  INTO v_column_exists
  FROM user_tab_cols
  WHERE column_name = 'ORG_CATCHWEIGHT'
        AND table_name = 'RETURNS';

  IF (v_column_exists = 0)
  THEN
    EXECUTE IMMEDIATE 'ALTER TABLE SWMS.RETURNS ADD ORG_CATCHWEIGHT NUMBER(9,3) NULL';
  END IF;
END;
/

DECLARE
  v_column_exists NUMBER := 0;
BEGIN
  SELECT COUNT(*)
  INTO v_column_exists
  FROM user_tab_cols
  WHERE column_name = 'RTN_SENT_IND'
        AND table_name = 'RETURNS';

  IF (v_column_exists = 0)
  THEN
    EXECUTE IMMEDIATE 'ALTER TABLE SWMS.RETURNS ADD RTN_SENT_IND char(1 char) NULL';
  END IF;
END;
/

DECLARE
  v_column_exists NUMBER := 0;
BEGIN
  SELECT COUNT(*)
  INTO v_column_exists
  FROM user_tab_cols
  WHERE column_name = 'POD_RTN_IND'
        AND table_name = 'RETURNS';

  IF (v_column_exists = 0)
  THEN
    EXECUTE IMMEDIATE 'ALTER TABLE SWMS.RETURNS ADD POD_RTN_IND char(1 char) NULL';
  END IF;
END;
/




