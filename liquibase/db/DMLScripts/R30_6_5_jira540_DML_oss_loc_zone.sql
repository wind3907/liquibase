/****************************************************************************
** Date:       24-May-2018
** File:       jira540_oss_loc_lzn_dml.sql
**
** Script to insert new locations to be used by Foodpro Outside Storage Transfer process.
**
**
**
** Modification History:
**    Date        Designer           Comments
**    -------- -------- ---------------------------------------------------
**    7-Aug-2018 vkal9662      New locations for Outside Storage Transfer process
**
****************************************************************************/
DECLARE
  v_column_exists NUMBER := 0;
BEGIN
  SELECT COUNT(*)
  INTO v_column_exists
  FROM LOC
  WHERE  logi_loc like'OS%';
  
IF (v_column_exists = 0)  THEN

INSERT
INTO LOC
  ( LOGI_LOC,
    STATUS,
    PALLET_TYPE,
    RANK,
    UOM,
    PERM,
    PIK_AISLE,
    PIK_SLOT,
    PIK_LEVEL,
    PIK_PATH,
    PUT_AISLE,
    PUT_SLOT,
    PUT_LEVEL,
    PUT_PATH,
    CUBE,
    DESCRIP,
    PROD_ID,
    SLOT_TYPE,
    ASSIGN,
    AISLE_SIDE,
    OLD_CUBE,
    CUST_PREF_VENDOR,
    RACK_LABEL_TYPE,
    FLOOR_HEIGHT,
    SLOT_HEIGHT,
    TRUE_SLOT_HEIGHT,
    WIDTH_POSITIONS,
    AVAILABLE_HEIGHT,
    OCCUPIED_HEIGHT,
    ADD_DATE,
    ADD_USER  )
  VALUES
  ( 'OS1111',
    'AVL',
    'LW',
    NULL,
    NULL,
    'N',
    999,
    999,
    999,
    999999999,
    999,
    999,
    999,
    999999999,
    9999,
    'Outside Storage Location 1',
    NULL,
    'LWC',
    NULL,
    'O',
    NULL,
    NULL,
    'H',
    9999,
    99,
    99,
    9,
    891,
    0,
    TRUNC(sysdate),
    'SWMS'  ); 

INSERT
INTO LOC
  ( LOGI_LOC,
    STATUS,
    PALLET_TYPE,
    RANK,
    UOM,
    PERM,
    PIK_AISLE,
    PIK_SLOT,
    PIK_LEVEL,
    PIK_PATH,
    PUT_AISLE,
    PUT_SLOT,
    PUT_LEVEL,
    PUT_PATH,
    CUBE,
    DESCRIP,
    PROD_ID,
    SLOT_TYPE,
    ASSIGN,
    AISLE_SIDE,
    OLD_CUBE,
    CUST_PREF_VENDOR,
    RACK_LABEL_TYPE,
    FLOOR_HEIGHT,
    SLOT_HEIGHT,
    TRUE_SLOT_HEIGHT,
    WIDTH_POSITIONS,
    AVAILABLE_HEIGHT,
    OCCUPIED_HEIGHT,
    ADD_DATE,
    ADD_USER  )
  VALUES
  ( 'OS2222',
    'AVL',
    'LW',
    NULL,
    NULL,
    'N',
    999,
    999,
    999,
    999999999,
    999,
    999,
    999,
    999999999,
    9999,
    'Outside Storage Location 2',
    NULL,
    'LWC',
    NULL,
    'O',
    NULL,
    NULL,
    'H',
    9999,
    99,
    99,
    9,
    891,
    0,
    TRUNC(sysdate),
    'SWMS'  ); 
	
INSERT
INTO LOC
  ( LOGI_LOC,
    STATUS,
    PALLET_TYPE,
    RANK,
    UOM,
    PERM,
    PIK_AISLE,
    PIK_SLOT,
    PIK_LEVEL,
    PIK_PATH,
    PUT_AISLE,
    PUT_SLOT,
    PUT_LEVEL,
    PUT_PATH,
    CUBE,
    DESCRIP,
    PROD_ID,
    SLOT_TYPE,
    ASSIGN,
    AISLE_SIDE,
    OLD_CUBE,
    CUST_PREF_VENDOR,
    RACK_LABEL_TYPE,
    FLOOR_HEIGHT,
    SLOT_HEIGHT,
    TRUE_SLOT_HEIGHT,
    WIDTH_POSITIONS,
    AVAILABLE_HEIGHT,
    OCCUPIED_HEIGHT,
    ADD_DATE,
    ADD_USER  )
  VALUES
  ( 'OS3333',
    'AVL',
    'LW',
    NULL,
    NULL,
    'N',
    999,
    999,
    999,
    999999999,
    999,
    999,
    999,
    999999999,
    9999,
    'Outside Storage Location 3',
    NULL,
    'LWC',
    NULL,
    'O',
    NULL,
    NULL,
    'H',
    9999,
    99,
    99,
    9,
    891,
    0,
    TRUNC(sysdate),
    'SWMS'  ); 
	
	
INSERT INTO AISLE_INFO(PICK_AISLE,NAME,DIRECTION,DIRECTED,SUB_AREA_CODE)
VALUES('999', 'OS', '0', 'Y','F');	
	
INSERT
INTO LZONE(LOGI_LOC,ZONE_ID)
VALUES('OS1111', 'OSS1');

INSERT
INTO LZONE(LOGI_LOC,ZONE_ID)
VALUES('OS2222', 'OSS2');
	
	INSERT
INTO LZONE(LOGI_LOC,ZONE_ID)
VALUES('OS3333', 'OSS3');


Insert into inv_stat(DESCRIP, STATUS) Values('Outside Storage','OSS');
	
  COMMIT;
  
  End If;
End;							  
/