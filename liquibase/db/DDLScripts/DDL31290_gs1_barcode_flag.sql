/****************************************************************************
** File:       DDL_gs1_barcode_flag.sql
**
** Desc: Script creates a column in the PM, STS_ROUTE_OUT tables 
**       to hold vales TRUE or FALSE.
**
** Modification History:
**    Date        Designer           Comments
**    -------- -------- ---------------------------------------------------
**    03-Aug-2017 Vishnupriya K.    GS1_BARCODE_FLAG added to tables 
**                                  PM, STS_ROUTE_OUT, STS_ROUTE_IN,
**                                  TYPE STS_ROUTE_OUT_OBJECT
****************************************************************************/

DECLARE
  v_column_exists NUMBER := 0;
BEGIN
  SELECT COUNT(*)
  INTO v_column_exists
  FROM user_tab_cols
  WHERE column_name = 'GS1_BARCODE_FLAG'
        AND table_name = 'PM';

  IF (v_column_exists = 0)
  THEN
    EXECUTE IMMEDIATE 'ALTER TABLE SWMS.PM ADD GS1_BARCODE_FLAG VARCHAR2(10 CHAR) NULL';
  END IF;
END;
/

DECLARE
  v_column_exists NUMBER := 0;
BEGIN
  SELECT COUNT(*)
  INTO v_column_exists
  FROM user_tab_cols
  WHERE column_name = 'GS1_BARCODE_FLAG'
        AND table_name = 'STS_ROUTE_OUT';

  IF (v_column_exists = 0)
  THEN
    EXECUTE IMMEDIATE 'ALTER TABLE SWMS.STS_ROUTE_OUT ADD GS1_BARCODE_FLAG VARCHAR2(10 CHAR) NULL';
  END IF;
END;
/

DECLARE
  v_column_exists NUMBER := 0;
BEGIN
  SELECT COUNT(*)
  INTO v_column_exists
  FROM user_tab_cols
  WHERE column_name = 'GS1_BARCODE_FLAG'
        AND table_name = 'STS_ROUTE_IN';

  IF (v_column_exists = 0)
  THEN
    EXECUTE IMMEDIATE 'ALTER TABLE SWMS.STS_ROUTE_IN ADD GS1_BARCODE_FLAG VARCHAR2(10 CHAR) NULL';
  END IF;
END;
/

DECLARE
  v_column_exists NUMBER := 0;
BEGIN
  SELECT COUNT(*)
  INTO v_column_exists
  FROM user_tab_cols
  WHERE column_name = 'GS1_BARCODE_ACTIVE'
        AND table_name = 'SPL_RQST_CUSTOMER';

  IF (v_column_exists = 0)
  THEN
    EXECUTE IMMEDIATE 'ALTER TABLE SWMS.SPL_RQST_CUSTOMER ADD GS1_BARCODE_ACTIVE VARCHAR2(1 CHAR) NULL';
  END IF;
END;
/

DECLARE
  v_attr_exists NUMBER := 0;
BEGIN
  SELECT COUNT(*)
  INTO v_attr_exists
  FROM DBA_TYPE_ATTRS
  WHERE TYPE_NAME = 'STS_ROUTE_OUT_OBJECT'
        AND ATTR_NAME = 'GS1_BARCODE_FLAG';

  IF (v_attr_exists = 0)
  THEN
    EXECUTE IMMEDIATE 'ALTER TYPE STS_ROUTE_OUT_OBJECT ADD ATTRIBUTE (GS1_BARCODE_FLAG VARCHAR2(5) ) CASCADE';
  END IF;
END;
/
ALTER TYPE "STS_ROUTE_OUT_OBJECT" COMPILE;