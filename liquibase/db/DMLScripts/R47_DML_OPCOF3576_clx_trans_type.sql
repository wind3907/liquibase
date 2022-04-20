/****************************************************************************
** Date:       23-Aug-2021
** File:       R47_DML_OPCOF3576_clx_trans_type.sql
**
** Script to insert new Trans Type CLX in to TRANS_TYPE table.
** CLX Trans type is used for Close XSN Trnasaction.
**
**
** Modification History:
**    Date         Designer           Comments
**    --------     -------- ---------------------------------------------------
**    23-Aug-2018  jkar6681      Trans Type CLX for XDOCK (CLOSE XSN)
**
****************************************************************************/
DECLARE
  v_exists NUMBER := 0;
BEGIN
  SELECT COUNT(*)
  INTO v_exists
  FROM TRANS_TYPE
  WHERE TRANS_TYPE ='CLX';
  
 IF (v_exists = 0)  THEN

  INSERT INTO TRANS_TYPE(TRANS_TYPE, DESCRIP,retention_days, inv_affecting)
  values('CLX', 'XSN Close', 55, 'N');
  COMMIT;
 End If;
End;							  
/
