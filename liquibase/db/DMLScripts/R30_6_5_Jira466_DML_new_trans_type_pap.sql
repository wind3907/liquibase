/****************************************************************************
** Date:       24-May-2018
** File:       Jira466_new_trans_type_pap.sql
**
** Script to insert new trans type for Finish Goods.
**
** 
**
** Modification History:
**    Date        Designer           Comments
**    -------- -------- ---------------------------------------------------
**    24-May-2018 Vishnupriya K.    create new trans type to be used in 
                                     Pick Adjustments Forms for Product out
**
****************************************************************************/
DECLARE
  v_column_exists NUMBER := 0;
BEGIN

  SELECT COUNT(*)
  INTO v_column_exists
  FROM  trans_type
  WHERE trans_type = 'PAP'
  AND descrip =   'Product Quantity Out (Meat Company)';
   
   
IF (v_column_exists = 0)  THEN

Insert into trans_type(trans_type, descrip, retention_days, inv_affecting)
values('PAP', 'Product Quantity Out (Meat Company)', 55, 'N');

End If;

End;							  
/