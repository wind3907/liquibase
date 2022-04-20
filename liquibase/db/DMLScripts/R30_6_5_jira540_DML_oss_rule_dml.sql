/****************************************************************************
** Date:       24-May-2018
** File:       jira540_oss_rule_dml.sql
**
** Script to insert new Rule to be used by Foodpro Outside Storage Transfer process.
**
**
**
** Modification History:
**    Date        Designer           Comments
**    -------- -------- ---------------------------------------------------
**    7-Aug-2018 vkal9662      New rule for Outside Storage Transfer process
**
****************************************************************************/
DECLARE
  v_column_exists NUMBER := 0;
BEGIN
  SELECT COUNT(*)
  INTO v_column_exists
  FROM Rules
  WHERE Rule_id = 10;
  
IF (v_column_exists = 0)  THEN

INSERT
INTO Rules
  (RULE_ID,
   RULE_TYPE,
   RULE_DESC,
   DEF  )
  VALUES
  (  10,
    'PUT',
    'FoodPro Outside Storage',
    'N'  );
	
  COMMIT;
  
  End If;
End;							  
/