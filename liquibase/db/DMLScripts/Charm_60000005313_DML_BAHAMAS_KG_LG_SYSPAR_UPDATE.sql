
/**************************************************************************
**    Update syspar for ITEM_LEVEL_WEIGHT_UNIT FOR charm No: 6000005313
***************************************************************************/

UPDATE SYS_CONFIG SET CONFIG_FLAG_VAL = 'N' WHERE CONFIG_FLAG_NAME = 'ITEM_LEVEL_WEIGHT_UNITS';

COMMIT;


