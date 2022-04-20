/****************************************************************************
**
** Desc: Script adds CMU column to table SN_RDC_PO
**
** Modification History:
**    Date        Designer           Comments
**    -----------    --------     ------------------------------------------
**    Aug 12 2019 vkal9662          add below CMU column to table SN_RDC_PO
**                                   (CMU_INDICATOR)
**       
****************************************************************************/

DECLARE
  v_column_exists NUMBER := 0;  
  BEGIN
  SELECT COUNT(*)
  INTO v_column_exists
  FROM user_tab_cols
  WHERE column_name = 'CMU_INDICATOR'
        AND table_name = 'SN_RDC_PO';

  IF (v_column_exists = 0)
  THEN
    EXECUTE IMMEDIATE 'ALTER TABLE SWMS.sn_rdc_po ADD (CMU_INDICATOR VARCHAR2(1 CHAR))';
  END IF;
 END;
/ 



