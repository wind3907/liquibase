/****************************************************************************
** File:       CRQ34059_DDL_ALTER_manifest_trans.sql
**
** Desc: 1. creates POD_STATUS_FLAG in manifest_stops to hold 
**			S- Successfully processed Stop close from STS 
**			F- Failed to process stop close from STS
**			M- Manually processed RETURNS from DCI
**		
** 		 2. Creates CUST_ID field in TRANS for STC transaction
**
** Modification History:
**    Date        Designer           Comments
**    -------- 	  -------- 		---------------------------------------------------
**    17/07/17 	  chyd9155    	CRQ34059-POD project iteration 2
**	06/12/17	  CHYD9155          DDL and DML standardization for merge  
****************************************************************************/
DECLARE
  v_column_exists NUMBER := 0;
BEGIN
  SELECT COUNT(*)
  INTO v_column_exists
  FROM user_tab_cols
  WHERE  table_name = 'MANIFEST_STOPS' AND column_name = 'POD_STATUS_FLAG';
        

  IF (v_column_exists = 0)
  THEN
    EXECUTE IMMEDIATE 'ALTER TABLE SWMS.MANIFEST_STOPS ADD POD_STATUS_FLAG varchar2(1)';
  END IF;
END;
/

DECLARE
  v_column_exists NUMBER := 0;
BEGIN
  SELECT COUNT(*)
  INTO v_column_exists
  FROM user_tab_cols
  WHERE table_name = 'TRANS' AND column_name = 'CUST_ID';
        

  IF (v_column_exists = 0)
  THEN
    EXECUTE IMMEDIATE 'ALTER TABLE SWMS.TRANS ADD CUST_ID VARCHAR2 (14 CHAR)';
  END IF;
END;
/