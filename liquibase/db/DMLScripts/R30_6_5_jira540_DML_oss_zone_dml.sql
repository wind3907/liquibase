/****************************************************************************
** Date:       24-May-2018
** File:       jira540_oss_zone_dml.sql
**
** Script to insert new zone to be used by Foodpro Outside Storage Transfer process.
**
**
**
** Modification History:
**    Date        Designer           Comments
**    -------- -------- ---------------------------------------------------
**    7-Aug-2018 vkal9662      New zone for Outside Storage Transfer process
**
****************************************************************************/
DECLARE
  v_column_exists NUMBER := 0;
BEGIN
  SELECT COUNT(*)
  INTO v_column_exists
  FROM ZONE
  WHERE Rule_id =10;
  
IF (v_column_exists = 0)  THEN

INSERT
INTO ZONE
  (ZONE_ID,
   ZONE_TYPE,
   RULE_ID,
   DESCRIP,
   WAREHOUSE_ID)
  VALUES
  ( 'OSS1',
    'PUT',
	 10,
    'FoodPro Outside Storage Zone 1',
    '000' );
	
 INSERT
 INTO ZONE
  (ZONE_ID,
   ZONE_TYPE,
   RULE_ID,
   DESCRIP,
   WAREHOUSE_ID)
  VALUES
  ( 'OSS2',
    'PUT',
	 10,
    'FoodPro Outside Storage Zone 2',
    '000' );
	
 INSERT
 INTO ZONE
  (ZONE_ID,
   ZONE_TYPE,
   RULE_ID,
   DESCRIP,
   WAREHOUSE_ID)
  VALUES
  ( 'OSS3',
    'PUT',
	 10,
    'FoodPro Outside Storage Zone 3',
    '000' );	

	INSERT
 INTO ZONE
  (ZONE_ID,
   ZONE_TYPE,
   RULE_ID,
   DESCRIP,
   WAREHOUSE_ID)
  VALUES
  ( 'OSS1P',
    'PIK',
	 10,
    'FoodPro Outside Storage Zone 1',
    '000' );
	
 INSERT
 INTO ZONE
  (ZONE_ID,
   ZONE_TYPE,
   RULE_ID,
   DESCRIP,
   WAREHOUSE_ID)
  VALUES
  ( 'OSS2P',
    'PIK',
	 10,
    'FoodPro Outside Storage Zone 2',
    '000' );
	
 INSERT
 INTO ZONE
  (ZONE_ID,
   ZONE_TYPE,
   RULE_ID,
   DESCRIP,
   WAREHOUSE_ID)
  VALUES
  ( 'OSS3P',
    'PIK',
	 10,
    'FoodPro Outside Storage Zone 3',
    '000' );
	
  COMMIT;
  
  End If;
End;							  
/