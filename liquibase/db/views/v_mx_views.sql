CREATE OR REPLACE VIEW SWMS.V_MX_OUT_ALL AS
SELECT 
SEQUENCE_NUMBER,
SYS_MSG_ID,
INTERFACE_REF_DOC,
REC_IND,
REC_COUNT,
RECORD_STATUS,
ADD_DATE,
ADD_USER,
UPD_DATE,
UPD_USER,
PRIORITY,
PROD_ID,
PARENT_PALLET_ID,
PALLET_ID,
LABEL_TYPE,
EXPIRATION_DATE,
CASE_QTY,
ERM_ID,
INV_STATUS,
ERROR_MSG,
ERROR_CODE,
BATCH_COMPLETE_TIMESTAMP,
ORDER_GENERATION_TIME,
TASK_ID,
DESTINATION_LOC,
EXACT_PALLET_IMP,
TRANS_TYPE,
WAVE_NUMBER,
NON_SYM_HEAVY_CASE_COUNT,
NON_SYM_LIGHT_CASE_COUNT,
ROUTE,
STOP,
ORDER_TYPE,
ORDER_SEQUENCE,
PRIORITY_IDENTIFIER,
CUSTOMER_ROTATION_RULES,
FLOAT_ID,
BATCH_ID,
ORDER_ID,
BATCH_STATUS,
CASE_BARCODE,
SPUR_LOC,
CASE_GRAB_TIMESTAMP,
FILE_NAME,
FILE_TIMESTAMP
FROM SWMS.MATRIX_OUT
ORDER BY ADD_DATE DESC, SEQUENCE_NUMBER DESC;

CREATE OR REPLACE VIEW SWMS.V_MX_OUT_SYS01 AS
SELECT 
SEQUENCE_NUMBER,
SYS_MSG_ID,
INTERFACE_REF_DOC,
REC_IND,
REC_COUNT,
RECORD_STATUS,
ADD_DATE,
ADD_USER,
UPD_DATE,
UPD_USER,
FUNC_CODE,
PROD_ID,
DESCRIPTION,
WAREHOUSE_AREA,
PACK,
PROD_SIZE,
PROD_SIZE_UNIT,
SLOTTING_FLAG,
CASE_LENGTH,
CASE_WIDTH,
CASE_HEIGHT,
WEIGHT,
PACK_SIZE,
UPC_PRESENT_FLAG,
UPC,
PROBLEM_CASE_UPC_FLAG,
HAZARDOUS_TYPE,
FOOD_TYPE ,
MX_SEL_ELIGIBILITY_FLAG,
MX_ITEM_ASSIGN_FLAG,
CUSTOMER_ROT_RULE_FLAG,
EXPIRATION_WINDOW,
SKU_TIP_FLAG,
ERROR_MSG,
ERROR_CODE
FROM SWMS.MATRIX_PM_OUT
WHERE INTERFACE_REF_DOC = 'SYS01'
ORDER BY ADD_DATE DESC, SEQUENCE_NUMBER DESC;

CREATE OR REPLACE VIEW SWMS.V_MX_OUT_SYS02 AS
SELECT 
SEQUENCE_NUMBER,
SYS_MSG_ID,
INTERFACE_REF_DOC,
REC_IND,
REC_COUNT,
RECORD_STATUS,
ADD_DATE,
ADD_USER,
UPD_DATE,
UPD_USER,
PRIORITY,
PROD_ID,
PARENT_PALLET_ID,
PALLET_ID,
LABEL_TYPE,
EXPIRATION_DATE,
CASE_QTY,
ERM_ID,
INV_STATUS,
ERROR_MSG,
ERROR_CODE,
BATCH_COMPLETE_TIMESTAMP,
ORDER_GENERATION_TIME,
TASK_ID,
DESTINATION_LOC,
EXACT_PALLET_IMP,
TRANS_TYPE,
WAVE_NUMBER,
NON_SYM_HEAVY_CASE_COUNT,
NON_SYM_LIGHT_CASE_COUNT,
ROUTE,
STOP,
ORDER_TYPE,
ORDER_SEQUENCE,
PRIORITY_IDENTIFIER,
CUSTOMER_ROTATION_RULES,
FLOAT_ID,
BATCH_ID,
ORDER_ID,
BATCH_STATUS,
CASE_BARCODE,
SPUR_LOC,
CASE_GRAB_TIMESTAMP,
FILE_NAME,
FILE_TIMESTAMP
FROM SWMS.MATRIX_OUT
WHERE INTERFACE_REF_DOC = 'SYS02'
ORDER BY ADD_DATE DESC, SEQUENCE_NUMBER DESC;

CREATE OR REPLACE VIEW SWMS.V_MX_OUT_SYS03 AS
SELECT 
SEQUENCE_NUMBER,
SYS_MSG_ID,
INTERFACE_REF_DOC,
REC_IND,
REC_COUNT,
RECORD_STATUS,
ADD_DATE,
ADD_USER,
UPD_DATE,
UPD_USER,
PRIORITY,
PROD_ID,
PARENT_PALLET_ID,
PALLET_ID,
LABEL_TYPE,
EXPIRATION_DATE,
CASE_QTY,
ERM_ID,
INV_STATUS,
ERROR_MSG,
ERROR_CODE,
BATCH_COMPLETE_TIMESTAMP,
ORDER_GENERATION_TIME,
TASK_ID,
DESTINATION_LOC,
EXACT_PALLET_IMP,
TRANS_TYPE,
WAVE_NUMBER,
NON_SYM_HEAVY_CASE_COUNT,
NON_SYM_LIGHT_CASE_COUNT,
ROUTE,
STOP,
ORDER_TYPE,
ORDER_SEQUENCE,
PRIORITY_IDENTIFIER,
CUSTOMER_ROTATION_RULES,
FLOAT_ID,
BATCH_ID,
ORDER_ID,
BATCH_STATUS,
CASE_BARCODE,
SPUR_LOC,
CASE_GRAB_TIMESTAMP,
FILE_NAME,
FILE_TIMESTAMP
FROM SWMS.MATRIX_OUT
WHERE INTERFACE_REF_DOC = 'SYS03'
ORDER BY ADD_DATE DESC, SEQUENCE_NUMBER DESC;

CREATE OR REPLACE VIEW SWMS.V_MX_OUT_SYS04 AS
SELECT 
SEQUENCE_NUMBER,
SYS_MSG_ID,
INTERFACE_REF_DOC,
REC_IND,
REC_COUNT,
RECORD_STATUS,
ADD_DATE,
ADD_USER,
UPD_DATE,
UPD_USER,
PRIORITY,
PROD_ID,
PARENT_PALLET_ID,
PALLET_ID,
LABEL_TYPE,
EXPIRATION_DATE,
CASE_QTY,
ERM_ID,
INV_STATUS,
ERROR_MSG,
ERROR_CODE,
BATCH_COMPLETE_TIMESTAMP,
ORDER_GENERATION_TIME,
TASK_ID,
DESTINATION_LOC,
EXACT_PALLET_IMP,
TRANS_TYPE,
WAVE_NUMBER,
NON_SYM_HEAVY_CASE_COUNT,
NON_SYM_LIGHT_CASE_COUNT,
ROUTE,
STOP,
ORDER_TYPE,
ORDER_SEQUENCE,
PRIORITY_IDENTIFIER,
CUSTOMER_ROTATION_RULES,
FLOAT_ID,
BATCH_ID,
ORDER_ID,
BATCH_STATUS,
CASE_BARCODE,
SPUR_LOC,
CASE_GRAB_TIMESTAMP,
FILE_NAME,
FILE_TIMESTAMP
FROM SWMS.MATRIX_OUT
WHERE INTERFACE_REF_DOC = 'SYS04'
ORDER BY ADD_DATE DESC, SEQUENCE_NUMBER DESC;

CREATE OR REPLACE VIEW SWMS.V_MX_OUT_SYS05 AS
SELECT 
SEQUENCE_NUMBER,
SYS_MSG_ID,
INTERFACE_REF_DOC,
REC_IND,
REC_COUNT,
RECORD_STATUS,
ADD_DATE,
ADD_USER,
UPD_DATE,
UPD_USER,
PRIORITY,
PROD_ID,
PARENT_PALLET_ID,
PALLET_ID,
LABEL_TYPE,
EXPIRATION_DATE,
CASE_QTY,
ERM_ID,
INV_STATUS,
ERROR_MSG,
ERROR_CODE,
BATCH_COMPLETE_TIMESTAMP,
ORDER_GENERATION_TIME,
TASK_ID,
DESTINATION_LOC,
EXACT_PALLET_IMP,
TRANS_TYPE,
WAVE_NUMBER,
NON_SYM_HEAVY_CASE_COUNT,
NON_SYM_LIGHT_CASE_COUNT,
ROUTE,
STOP,
ORDER_TYPE,
ORDER_SEQUENCE,
PRIORITY_IDENTIFIER,
CUSTOMER_ROTATION_RULES,
FLOAT_ID,
BATCH_ID,
ORDER_ID,
BATCH_STATUS,
CASE_BARCODE,
SPUR_LOC,
CASE_GRAB_TIMESTAMP,
FILE_NAME,
FILE_TIMESTAMP
FROM SWMS.MATRIX_OUT
WHERE INTERFACE_REF_DOC = 'SYS05'
ORDER BY ADD_DATE DESC, SEQUENCE_NUMBER DESC;

CREATE OR REPLACE VIEW SWMS.V_MX_OUT_SYS06 AS
SELECT 
SEQUENCE_NUMBER,
SYS_MSG_ID,
INTERFACE_REF_DOC,
REC_IND,
REC_COUNT,
RECORD_STATUS,
ADD_DATE,
ADD_USER,
UPD_DATE,
UPD_USER,
PRIORITY,
PROD_ID,
PARENT_PALLET_ID,
PALLET_ID,
LABEL_TYPE,
EXPIRATION_DATE,
CASE_QTY,
ERM_ID,
INV_STATUS,
ERROR_MSG,
ERROR_CODE,
BATCH_COMPLETE_TIMESTAMP,
ORDER_GENERATION_TIME,
TASK_ID,
DESTINATION_LOC,
EXACT_PALLET_IMP,
TRANS_TYPE,
WAVE_NUMBER,
NON_SYM_HEAVY_CASE_COUNT,
NON_SYM_LIGHT_CASE_COUNT,
ROUTE,
STOP,
ORDER_TYPE,
ORDER_SEQUENCE,
PRIORITY_IDENTIFIER,
CUSTOMER_ROTATION_RULES,
FLOAT_ID,
BATCH_ID,
ORDER_ID,
BATCH_STATUS,
CASE_BARCODE,
SPUR_LOC,
CASE_GRAB_TIMESTAMP,
FILE_NAME,
FILE_TIMESTAMP
FROM SWMS.MATRIX_OUT
WHERE INTERFACE_REF_DOC = 'SYS06'
ORDER BY ADD_DATE DESC, SEQUENCE_NUMBER DESC;

CREATE OR REPLACE VIEW SWMS.V_MX_OUT_SYS07 AS
SELECT 
SEQUENCE_NUMBER,
SYS_MSG_ID,
INTERFACE_REF_DOC,
REC_IND,
REC_COUNT,
RECORD_STATUS,
ADD_DATE,
ADD_USER,
UPD_DATE,
UPD_USER,
PRIORITY,
PROD_ID,
PARENT_PALLET_ID,
PALLET_ID,
LABEL_TYPE,
EXPIRATION_DATE,
CASE_QTY,
ERM_ID,
INV_STATUS,
ERROR_MSG,
ERROR_CODE,
BATCH_COMPLETE_TIMESTAMP,
ORDER_GENERATION_TIME,
TASK_ID,
DESTINATION_LOC,
EXACT_PALLET_IMP,
TRANS_TYPE,
WAVE_NUMBER,
NON_SYM_HEAVY_CASE_COUNT,
NON_SYM_LIGHT_CASE_COUNT,
ROUTE,
STOP,
ORDER_TYPE,
ORDER_SEQUENCE,
PRIORITY_IDENTIFIER,
CUSTOMER_ROTATION_RULES,
FLOAT_ID,
BATCH_ID,
ORDER_ID,
BATCH_STATUS,
CASE_BARCODE,
SPUR_LOC,
CASE_GRAB_TIMESTAMP,
FILE_NAME,
FILE_TIMESTAMP
FROM SWMS.MATRIX_OUT
WHERE INTERFACE_REF_DOC = 'SYS07'
ORDER BY ADD_DATE DESC, SEQUENCE_NUMBER DESC;

CREATE OR REPLACE VIEW SWMS.V_MX_OUT_SYS08 AS
SELECT 
SEQUENCE_NUMBER,
SYS_MSG_ID,
INTERFACE_REF_DOC,
REC_IND,
REC_COUNT,
RECORD_STATUS,
ADD_DATE,
ADD_USER,
UPD_DATE,
UPD_USER,
PRIORITY,
PROD_ID,
PARENT_PALLET_ID,
PALLET_ID,
LABEL_TYPE,
EXPIRATION_DATE,
CASE_QTY,
ERM_ID,
INV_STATUS,
ERROR_MSG,
ERROR_CODE,
BATCH_COMPLETE_TIMESTAMP,
ORDER_GENERATION_TIME,
TASK_ID,
DESTINATION_LOC,
EXACT_PALLET_IMP,
TRANS_TYPE,
WAVE_NUMBER,
NON_SYM_HEAVY_CASE_COUNT,
NON_SYM_LIGHT_CASE_COUNT,
ROUTE,
STOP,
ORDER_TYPE,
ORDER_SEQUENCE,
PRIORITY_IDENTIFIER,
CUSTOMER_ROTATION_RULES,
FLOAT_ID,
BATCH_ID,
ORDER_ID,
BATCH_STATUS,
CASE_BARCODE,
SPUR_LOC,
CASE_GRAB_TIMESTAMP,
FILE_NAME,
FILE_TIMESTAMP
FROM SWMS.MATRIX_OUT
WHERE INTERFACE_REF_DOC = 'SYS08'
ORDER BY ADD_DATE DESC, SEQUENCE_NUMBER DESC;

CREATE OR REPLACE VIEW SWMS.V_MX_OUT_SYS09 AS
SELECT 
SEQUENCE_NUMBER,
SYS_MSG_ID,
INTERFACE_REF_DOC,
REC_IND,
REC_COUNT,
RECORD_STATUS,
ADD_DATE,
ADD_USER,
UPD_DATE,
UPD_USER,
PRIORITY,
PROD_ID,
PARENT_PALLET_ID,
PALLET_ID,
LABEL_TYPE,
EXPIRATION_DATE,
CASE_QTY,
ERM_ID,
INV_STATUS,
ERROR_MSG,
ERROR_CODE,
BATCH_COMPLETE_TIMESTAMP,
ORDER_GENERATION_TIME,
TASK_ID,
DESTINATION_LOC,
EXACT_PALLET_IMP,
TRANS_TYPE,
WAVE_NUMBER,
NON_SYM_HEAVY_CASE_COUNT,
NON_SYM_LIGHT_CASE_COUNT,
ROUTE,
STOP,
ORDER_TYPE,
ORDER_SEQUENCE,
PRIORITY_IDENTIFIER,
CUSTOMER_ROTATION_RULES,
FLOAT_ID,
BATCH_ID,
ORDER_ID,
BATCH_STATUS,
CASE_BARCODE,
SPUR_LOC,
CASE_GRAB_TIMESTAMP,
FILE_NAME,
FILE_TIMESTAMP
FROM SWMS.MATRIX_OUT
WHERE INTERFACE_REF_DOC = 'SYS09'
ORDER BY ADD_DATE DESC, SEQUENCE_NUMBER DESC;

CREATE OR REPLACE VIEW SWMS.V_MX_OUT_SYS10 AS
SELECT 
SEQUENCE_NUMBER,
SYS_MSG_ID,
INTERFACE_REF_DOC,
REC_IND,
REC_COUNT,
RECORD_STATUS,
ADD_DATE,
ADD_USER,
UPD_DATE,
UPD_USER,
PRIORITY,
PROD_ID,
PARENT_PALLET_ID,
PALLET_ID,
LABEL_TYPE,
EXPIRATION_DATE,
CASE_QTY,
ERM_ID,
INV_STATUS,
ERROR_MSG,
ERROR_CODE,
BATCH_COMPLETE_TIMESTAMP,
ORDER_GENERATION_TIME,
TASK_ID,
DESTINATION_LOC,
EXACT_PALLET_IMP,
TRANS_TYPE,
WAVE_NUMBER,
NON_SYM_HEAVY_CASE_COUNT,
NON_SYM_LIGHT_CASE_COUNT,
ROUTE,
STOP,
ORDER_TYPE,
ORDER_SEQUENCE,
PRIORITY_IDENTIFIER,
CUSTOMER_ROTATION_RULES,
FLOAT_ID,
BATCH_ID,
ORDER_ID,
BATCH_STATUS,
CASE_BARCODE,
SPUR_LOC,
CASE_GRAB_TIMESTAMP,
FILE_NAME,
FILE_TIMESTAMP
FROM SWMS.MATRIX_OUT
WHERE INTERFACE_REF_DOC = 'SYS10'
ORDER BY ADD_DATE DESC, SEQUENCE_NUMBER DESC;

CREATE OR REPLACE VIEW SWMS.V_MX_OUT_SYS11 AS
SELECT 
SEQUENCE_NUMBER,
SYS_MSG_ID,
INTERFACE_REF_DOC,
REC_IND,
REC_COUNT,
RECORD_STATUS,
ADD_DATE,
ADD_USER,
UPD_DATE,
UPD_USER,
PRIORITY,
PROD_ID,
PARENT_PALLET_ID,
PALLET_ID,
LABEL_TYPE,
EXPIRATION_DATE,
CASE_QTY,
ERM_ID,
INV_STATUS,
ERROR_MSG,
ERROR_CODE,
BATCH_COMPLETE_TIMESTAMP,
ORDER_GENERATION_TIME,
TASK_ID,
DESTINATION_LOC,
EXACT_PALLET_IMP,
TRANS_TYPE,
WAVE_NUMBER,
NON_SYM_HEAVY_CASE_COUNT,
NON_SYM_LIGHT_CASE_COUNT,
ROUTE,
STOP,
ORDER_TYPE,
ORDER_SEQUENCE,
PRIORITY_IDENTIFIER,
CUSTOMER_ROTATION_RULES,
FLOAT_ID,
BATCH_ID,
ORDER_ID,
BATCH_STATUS,
CASE_BARCODE,
SPUR_LOC,
CASE_GRAB_TIMESTAMP,
FILE_NAME,
FILE_TIMESTAMP
FROM SWMS.MATRIX_OUT
WHERE INTERFACE_REF_DOC = 'SYS11'
ORDER BY ADD_DATE DESC, SEQUENCE_NUMBER DESC;

CREATE OR REPLACE VIEW SWMS.V_MX_OUT_SYS12 AS
SELECT 
SEQUENCE_NUMBER,
SYS_MSG_ID,
INTERFACE_REF_DOC,
REC_IND,
REC_COUNT,
RECORD_STATUS,
ADD_DATE,
ADD_USER,
UPD_DATE,
UPD_USER,
PRIORITY,
PROD_ID,
PARENT_PALLET_ID,
PALLET_ID,
LABEL_TYPE,
EXPIRATION_DATE,
CASE_QTY,
ERM_ID,
INV_STATUS,
ERROR_MSG,
ERROR_CODE,
BATCH_COMPLETE_TIMESTAMP,
ORDER_GENERATION_TIME,
TASK_ID,
DESTINATION_LOC,
EXACT_PALLET_IMP,
TRANS_TYPE,
WAVE_NUMBER,
NON_SYM_HEAVY_CASE_COUNT,
NON_SYM_LIGHT_CASE_COUNT,
ROUTE,
STOP,
ORDER_TYPE,
ORDER_SEQUENCE,
PRIORITY_IDENTIFIER,
CUSTOMER_ROTATION_RULES,
FLOAT_ID,
BATCH_ID,
ORDER_ID,
BATCH_STATUS,
CASE_BARCODE,
SPUR_LOC,
CASE_GRAB_TIMESTAMP,
FILE_NAME,
FILE_TIMESTAMP
FROM SWMS.MATRIX_OUT
WHERE INTERFACE_REF_DOC = 'SYS12'
ORDER BY ADD_DATE DESC, SEQUENCE_NUMBER DESC;

CREATE OR REPLACE VIEW SWMS.V_MX_OUT_SYS13 AS
SELECT 
SEQUENCE_NUMBER,
SYS_MSG_ID,
INTERFACE_REF_DOC,
REC_IND,
REC_COUNT,
RECORD_STATUS,
ADD_DATE,
ADD_USER,
UPD_DATE,
UPD_USER,
PRIORITY,
PROD_ID,
PARENT_PALLET_ID,
PALLET_ID,
LABEL_TYPE,
EXPIRATION_DATE,
CASE_QTY,
ERM_ID,
INV_STATUS,
ERROR_MSG,
ERROR_CODE,
BATCH_COMPLETE_TIMESTAMP,
ORDER_GENERATION_TIME,
TASK_ID,
DESTINATION_LOC,
EXACT_PALLET_IMP,
TRANS_TYPE,
WAVE_NUMBER,
NON_SYM_HEAVY_CASE_COUNT,
NON_SYM_LIGHT_CASE_COUNT,
ROUTE,
STOP,
ORDER_TYPE,
ORDER_SEQUENCE,
PRIORITY_IDENTIFIER,
CUSTOMER_ROTATION_RULES,
FLOAT_ID,
BATCH_ID,
ORDER_ID,
BATCH_STATUS,
CASE_BARCODE,
SPUR_LOC,
CASE_GRAB_TIMESTAMP,
FILE_NAME,
FILE_TIMESTAMP
FROM SWMS.MATRIX_OUT
WHERE INTERFACE_REF_DOC = 'SYS13'
ORDER BY ADD_DATE DESC, SEQUENCE_NUMBER DESC;

CREATE OR REPLACE VIEW SWMS.V_MX_OUT_SYS14 AS
SELECT 
SEQUENCE_NUMBER,
SYS_MSG_ID,
INTERFACE_REF_DOC,
REC_IND,
REC_COUNT,
RECORD_STATUS,
ADD_DATE,
ADD_USER,
UPD_DATE,
UPD_USER,
PRIORITY,
PROD_ID,
PARENT_PALLET_ID,
PALLET_ID,
LABEL_TYPE,
EXPIRATION_DATE,
CASE_QTY,
ERM_ID,
INV_STATUS,
ERROR_MSG,
ERROR_CODE,
BATCH_COMPLETE_TIMESTAMP,
ORDER_GENERATION_TIME,
TASK_ID,
DESTINATION_LOC,
EXACT_PALLET_IMP,
TRANS_TYPE,
WAVE_NUMBER,
NON_SYM_HEAVY_CASE_COUNT,
NON_SYM_LIGHT_CASE_COUNT,
ROUTE,
STOP,
ORDER_TYPE,
ORDER_SEQUENCE,
PRIORITY_IDENTIFIER,
CUSTOMER_ROTATION_RULES,
FLOAT_ID,
BATCH_ID,
ORDER_ID,
BATCH_STATUS,
CASE_BARCODE,
SPUR_LOC,
CASE_GRAB_TIMESTAMP,
FILE_NAME,
FILE_TIMESTAMP
FROM SWMS.MATRIX_OUT
WHERE INTERFACE_REF_DOC = 'SYS14'
ORDER BY ADD_DATE DESC, SEQUENCE_NUMBER DESC;

CREATE OR REPLACE VIEW SWMS.V_MX_IN_ALL AS
SELECT 
SEQUENCE_NUMBER,
MX_MSG_ID,
INTERFACE_REF_DOC,
REC_IND,
REC_COUNT,
RECORD_STATUS,
ADD_DATE,
ADD_USER,
UPD_DATE,
UPD_USER,
PROD_ID,
ERM_ID,
PARENT_PALLET_ID,
PALLET_ID,
MX_REASON_CODE,
CASE_QTY,
QTY_STORED,
SPUR_LOC,
ORDER_TYPE,
SELECTION_REL_SEQ,
BATCH_ID,
TASK_ID,
RELEASE_TYPE,
QTY_INDUCTED,
QTY_DAMAGED,
QTY_OUT_OF_TOLERANCE,
QTY_WRONG_ITEM,
QTY_SHORT,
QTY_OVER,
TO_CHAR(STORED_TIME,'DD-MON-YY HH24:MI:SS.FF3') STORED_TIME,
TO_CHAR(MSG_TIME,'DD-MON-YY HH24:MI:SS.FF3') MSG_TIME,
ERROR_MSG,
ERROR_CODE,
TRANS_TYPE,
TO_CHAR(SEQUENCE_TIMESTAMP,'DD-MON-YY HH24:MI:SS.FF3') SEQUENCE_TIMESTAMP,
CASE_BARCODE,
SKIP_REASON,
LANE_ID,
LAST_CASE,
TO_CHAR(DIVERT_TIME,'DD-MON-YY HH24:MI:SS.FF3') DIVERT_TIME,
LABEL_TYPE,
MESSAGE_NAME,
SYMBOTIC_STATUS,
FILE_NAME,
TO_CHAR(FILE_TIMESTAMP,'DD-MON-YY HH24:MI:SS.FF3') FILE_TIMESTAMP,
ROW_COUNT,
ORDER_ID,
ACTION_CODE,
REASON_CODE,
INTERFACE_TYPE,
USER_ID,
CELL_ID,
TO_CHAR(EVENT_TIMESTAMP,'DD-MON-YY HH24:MI:SS.FF3') EVENT_TIMESTAMP,
REWORKED_QTY,
VERIFIED_QTY,
REJECTED_QTY
FROM SWMS.MATRIX_IN
ORDER BY ADD_DATE DESC, SEQUENCE_NUMBER DESC;

CREATE OR REPLACE VIEW SWMS.V_MX_IN_SYM01 AS
SELECT 
SEQUENCE_NUMBER,
MX_MSG_ID,
INTERFACE_REF_DOC,
REC_IND,
REC_COUNT,
RECORD_STATUS,
ADD_DATE,
ADD_USER,
UPD_DATE,
UPD_USER,
PROD_ID,
ERM_ID,
PARENT_PALLET_ID,
PALLET_ID,
MX_REASON_CODE,
CASE_QTY,
QTY_STORED,
SPUR_LOC,
ORDER_TYPE,
SELECTION_REL_SEQ,
BATCH_ID,
TASK_ID,
RELEASE_TYPE,
QTY_INDUCTED,
QTY_DAMAGED,
QTY_OUT_OF_TOLERANCE,
QTY_WRONG_ITEM,
QTY_SHORT,
QTY_OVER,
TO_CHAR(STORED_TIME,'DD-MON-YY HH24:MI:SS.FF3') STORED_TIME,
TO_CHAR(MSG_TIME,'DD-MON-YY HH24:MI:SS.FF3') MSG_TIME,
ERROR_MSG,
ERROR_CODE,
TRANS_TYPE,
TO_CHAR(SEQUENCE_TIMESTAMP,'DD-MON-YY HH24:MI:SS.FF3') SEQUENCE_TIMESTAMP,
CASE_BARCODE,
SKIP_REASON,
LANE_ID,
LAST_CASE,
TO_CHAR(DIVERT_TIME,'DD-MON-YY HH24:MI:SS.FF3') DIVERT_TIME,
LABEL_TYPE,
MESSAGE_NAME,
SYMBOTIC_STATUS,
FILE_NAME,
TO_CHAR(FILE_TIMESTAMP,'DD-MON-YY HH24:MI:SS.FF3') FILE_TIMESTAMP,
ROW_COUNT,
ORDER_ID,
ACTION_CODE,
REASON_CODE,
INTERFACE_TYPE,
USER_ID,
CELL_ID,
TO_CHAR(EVENT_TIMESTAMP,'DD-MON-YY HH24:MI:SS.FF3') EVENT_TIMESTAMP,
REWORKED_QTY,
VERIFIED_QTY,
REJECTED_QTY
FROM SWMS.MATRIX_IN
WHERE INTERFACE_REF_DOC = 'SYM01'
ORDER BY ADD_DATE DESC, SEQUENCE_NUMBER DESC;

CREATE OR REPLACE VIEW SWMS.V_MX_IN_SYM03 AS
SELECT 
SEQUENCE_NUMBER,
MX_MSG_ID,
INTERFACE_REF_DOC,
REC_IND,
REC_COUNT,
RECORD_STATUS,
ADD_DATE,
ADD_USER,
UPD_DATE,
UPD_USER,
PROD_ID,
ERM_ID,
PARENT_PALLET_ID,
PALLET_ID,
MX_REASON_CODE,
CASE_QTY,
QTY_STORED,
QTY_SUSPECT,
SPUR_LOC,
ORDER_TYPE,
SELECTION_REL_SEQ,
BATCH_ID,
TASK_ID,
RELEASE_TYPE,
QTY_INDUCTED,
QTY_DAMAGED,
QTY_OUT_OF_TOLERANCE,
QTY_WRONG_ITEM,
QTY_SHORT,
QTY_OVER,
TO_CHAR(STORED_TIME,'DD-MON-YY HH24:MI:SS.FF3') STORED_TIME,
TO_CHAR(MSG_TIME,'DD-MON-YY HH24:MI:SS.FF3') MSG_TIME,
ERROR_MSG,
ERROR_CODE,
TRANS_TYPE,
TO_CHAR(SEQUENCE_TIMESTAMP,'DD-MON-YY HH24:MI:SS.FF3') SEQUENCE_TIMESTAMP,
CASE_BARCODE,
SKIP_REASON,
LANE_ID,
LAST_CASE,
TO_CHAR(DIVERT_TIME,'DD-MON-YY HH24:MI:SS.FF3') DIVERT_TIME,
LABEL_TYPE,
MESSAGE_NAME,
SYMBOTIC_STATUS,
FILE_NAME,
TO_CHAR(FILE_TIMESTAMP,'DD-MON-YY HH24:MI:SS.FF3') FILE_TIMESTAMP,
ROW_COUNT,
ORDER_ID,
ACTION_CODE,
REASON_CODE,
INTERFACE_TYPE,
USER_ID,
CELL_ID,
TO_CHAR(EVENT_TIMESTAMP,'DD-MON-YY HH24:MI:SS.FF3') EVENT_TIMESTAMP,
REWORKED_QTY,
VERIFIED_QTY,
REJECTED_QTY
FROM SWMS.MATRIX_IN
WHERE INTERFACE_REF_DOC = 'SYM03'
ORDER BY ADD_DATE DESC, SEQUENCE_NUMBER DESC;

CREATE OR REPLACE VIEW SWMS.V_MX_IN_SYM05 AS
SELECT 
SEQUENCE_NUMBER,
MX_MSG_ID,
INTERFACE_REF_DOC,
REC_IND,
REC_COUNT,
RECORD_STATUS,
ADD_DATE,
ADD_USER,
UPD_DATE,
UPD_USER,
PROD_ID,
ERM_ID,
PARENT_PALLET_ID,
PALLET_ID,
MX_REASON_CODE,
CASE_QTY,
QTY_STORED,
SPUR_LOC,
ORDER_TYPE,
SELECTION_REL_SEQ,
BATCH_ID,
TASK_ID,
RELEASE_TYPE,
QTY_INDUCTED,
QTY_DAMAGED,
QTY_OUT_OF_TOLERANCE,
QTY_WRONG_ITEM,
QTY_SHORT,
QTY_OVER,
TO_CHAR(STORED_TIME,'DD-MON-YY HH24:MI:SS.FF3') STORED_TIME,
TO_CHAR(MSG_TIME,'DD-MON-YY HH24:MI:SS.FF3') MSG_TIME,
ERROR_MSG,
ERROR_CODE,
TRANS_TYPE,
TO_CHAR(SEQUENCE_TIMESTAMP,'DD-MON-YY HH24:MI:SS.FF3') SEQUENCE_TIMESTAMP,
CASE_BARCODE,
SKIP_REASON,
LANE_ID,
LAST_CASE,
TO_CHAR(DIVERT_TIME,'DD-MON-YY HH24:MI:SS.FF3') DIVERT_TIME,
LABEL_TYPE,
MESSAGE_NAME,
SYMBOTIC_STATUS,
FILE_NAME,
TO_CHAR(FILE_TIMESTAMP,'DD-MON-YY HH24:MI:SS.FF3') FILE_TIMESTAMP,
ROW_COUNT,
ORDER_ID,
ACTION_CODE,
REASON_CODE,
INTERFACE_TYPE,
USER_ID,
CELL_ID,
TO_CHAR(EVENT_TIMESTAMP,'DD-MON-YY HH24:MI:SS.FF3') EVENT_TIMESTAMP,
REWORKED_QTY,
VERIFIED_QTY,
REJECTED_QTY
FROM SWMS.MATRIX_IN
WHERE INTERFACE_REF_DOC = 'SYM05'
ORDER BY ADD_DATE DESC, SEQUENCE_NUMBER DESC;

CREATE OR REPLACE VIEW SWMS.V_MX_IN_SYM06 AS
SELECT 
SEQUENCE_NUMBER,
MX_MSG_ID,
INTERFACE_REF_DOC,
REC_IND,
REC_COUNT,
RECORD_STATUS,
ADD_DATE,
ADD_USER,
UPD_DATE,
UPD_USER,
PROD_ID,
ERM_ID,
PARENT_PALLET_ID,
PALLET_ID,
MX_REASON_CODE,
CASE_QTY,
QTY_STORED,
SPUR_LOC,
ORDER_TYPE,
SELECTION_REL_SEQ,
BATCH_ID,
TASK_ID,
RELEASE_TYPE,
QTY_INDUCTED,
QTY_DAMAGED,
QTY_OUT_OF_TOLERANCE,
QTY_WRONG_ITEM,
QTY_SHORT,
QTY_OVER,
TO_CHAR(STORED_TIME,'DD-MON-YY HH24:MI:SS.FF3') STORED_TIME,
TO_CHAR(MSG_TIME,'DD-MON-YY HH24:MI:SS.FF3') MSG_TIME,
ERROR_MSG,
ERROR_CODE,
TRANS_TYPE,
TO_CHAR(SEQUENCE_TIMESTAMP,'DD-MON-YY HH24:MI:SS.FF3') SEQUENCE_TIMESTAMP,
CASE_BARCODE,
SKIP_REASON,
LANE_ID,
LAST_CASE,
TO_CHAR(DIVERT_TIME,'DD-MON-YY HH24:MI:SS.FF3') DIVERT_TIME,
LABEL_TYPE,
MESSAGE_NAME,
SYMBOTIC_STATUS,
FILE_NAME,
TO_CHAR(FILE_TIMESTAMP,'DD-MON-YY HH24:MI:SS.FF3') FILE_TIMESTAMP,
ROW_COUNT,
ORDER_ID,
ACTION_CODE,
REASON_CODE,
INTERFACE_TYPE,
USER_ID,
CELL_ID,
TO_CHAR(EVENT_TIMESTAMP,'DD-MON-YY HH24:MI:SS.FF3') EVENT_TIMESTAMP,
REWORKED_QTY,
VERIFIED_QTY,
REJECTED_QTY
FROM SWMS.MATRIX_IN
WHERE INTERFACE_REF_DOC = 'SYM06'
ORDER BY ADD_DATE DESC, SEQUENCE_NUMBER DESC;

CREATE OR REPLACE VIEW SWMS.V_MX_IN_SYM07 AS
SELECT 
SEQUENCE_NUMBER,
MX_MSG_ID,
INTERFACE_REF_DOC,
REC_IND,
REC_COUNT,
RECORD_STATUS,
ADD_DATE,
ADD_USER,
UPD_DATE,
UPD_USER,
PROD_ID,
ERM_ID,
PARENT_PALLET_ID,
PALLET_ID,
MX_REASON_CODE,
CASE_QTY,
QTY_STORED,
SPUR_LOC,
ORDER_TYPE,
SELECTION_REL_SEQ,
BATCH_ID,
TASK_ID,
RELEASE_TYPE,
QTY_INDUCTED,
QTY_DAMAGED,
QTY_OUT_OF_TOLERANCE,
QTY_WRONG_ITEM,
QTY_SHORT,
QTY_OVER,
TO_CHAR(STORED_TIME,'DD-MON-YY HH24:MI:SS.FF3') STORED_TIME,
TO_CHAR(MSG_TIME,'DD-MON-YY HH24:MI:SS.FF3') MSG_TIME,
ERROR_MSG,
ERROR_CODE,
TRANS_TYPE,
TO_CHAR(SEQUENCE_TIMESTAMP,'DD-MON-YY HH24:MI:SS.FF3') SEQUENCE_TIMESTAMP,
CASE_BARCODE,
SKIP_REASON,
LANE_ID,
LAST_CASE,
TO_CHAR(DIVERT_TIME,'DD-MON-YY HH24:MI:SS.FF3') DIVERT_TIME,
LABEL_TYPE,
MESSAGE_NAME,
SYMBOTIC_STATUS,
FILE_NAME,
TO_CHAR(FILE_TIMESTAMP,'DD-MON-YY HH24:MI:SS.FF3') FILE_TIMESTAMP,
ROW_COUNT,
ORDER_ID,
ACTION_CODE,
REASON_CODE,
INTERFACE_TYPE,
USER_ID,
CELL_ID,
TO_CHAR(EVENT_TIMESTAMP,'DD-MON-YY HH24:MI:SS.FF3') EVENT_TIMESTAMP,
REWORKED_QTY,
VERIFIED_QTY,
REJECTED_QTY
FROM SWMS.MATRIX_IN
WHERE INTERFACE_REF_DOC = 'SYM07'
ORDER BY ADD_DATE DESC, SEQUENCE_NUMBER DESC;

CREATE OR REPLACE VIEW SWMS.V_MX_IN_SYM12 AS
SELECT 
SEQUENCE_NUMBER,
MX_MSG_ID,
INTERFACE_REF_DOC,
REC_IND,
REC_COUNT,
RECORD_STATUS,
ADD_DATE,
ADD_USER,
UPD_DATE,
UPD_USER,
PROD_ID,
ERM_ID,
PARENT_PALLET_ID,
PALLET_ID,
MX_REASON_CODE,
CASE_QTY,
QTY_STORED,
SPUR_LOC,
ORDER_TYPE,
SELECTION_REL_SEQ,
BATCH_ID,
TASK_ID,
RELEASE_TYPE,
QTY_INDUCTED,
QTY_DAMAGED,
QTY_OUT_OF_TOLERANCE,
QTY_WRONG_ITEM,
QTY_SHORT,
QTY_OVER,
TO_CHAR(STORED_TIME,'DD-MON-YY HH24:MI:SS.FF3') STORED_TIME,
TO_CHAR(MSG_TIME,'DD-MON-YY HH24:MI:SS.FF3') MSG_TIME,
ERROR_MSG,
ERROR_CODE,
TRANS_TYPE,
TO_CHAR(SEQUENCE_TIMESTAMP,'DD-MON-YY HH24:MI:SS.FF3') SEQUENCE_TIMESTAMP,
CASE_BARCODE,
SKIP_REASON,
LANE_ID,
LAST_CASE,
TO_CHAR(DIVERT_TIME,'DD-MON-YY HH24:MI:SS.FF3') DIVERT_TIME,
LABEL_TYPE,
MESSAGE_NAME,
SYMBOTIC_STATUS,
FILE_NAME,
TO_CHAR(FILE_TIMESTAMP,'DD-MON-YY HH24:MI:SS.FF3') FILE_TIMESTAMP,
ROW_COUNT,
ORDER_ID,
ACTION_CODE,
REASON_CODE,
INTERFACE_TYPE,
USER_ID,
CELL_ID,
TO_CHAR(EVENT_TIMESTAMP,'DD-MON-YY HH24:MI:SS.FF3') EVENT_TIMESTAMP,
REWORKED_QTY,
VERIFIED_QTY,
REJECTED_QTY
FROM SWMS.MATRIX_IN
WHERE INTERFACE_REF_DOC = 'SYM12'
ORDER BY ADD_DATE DESC, SEQUENCE_NUMBER DESC;

CREATE OR REPLACE VIEW SWMS.V_MX_IN_SYM15 AS
SELECT 
SEQUENCE_NUMBER,
MX_MSG_ID,
INTERFACE_REF_DOC,
REC_IND,
REC_COUNT,
RECORD_STATUS,
ADD_DATE,
ADD_USER,
UPD_DATE,
UPD_USER,
PROD_ID,
ERM_ID,
PARENT_PALLET_ID,
PALLET_ID,
MX_REASON_CODE,
CASE_QTY,
QTY_STORED,
SPUR_LOC,
ORDER_TYPE,
SELECTION_REL_SEQ,
BATCH_ID,
TASK_ID,
RELEASE_TYPE,
QTY_INDUCTED,
QTY_DAMAGED,
QTY_OUT_OF_TOLERANCE,
QTY_WRONG_ITEM,
QTY_SHORT,
QTY_OVER,
TO_CHAR(STORED_TIME,'DD-MON-YY HH24:MI:SS.FF3') STORED_TIME,
TO_CHAR(MSG_TIME,'DD-MON-YY HH24:MI:SS.FF3') MSG_TIME,
ERROR_MSG,
ERROR_CODE,
TRANS_TYPE,
TO_CHAR(SEQUENCE_TIMESTAMP,'DD-MON-YY HH24:MI:SS.FF3') SEQUENCE_TIMESTAMP,
CASE_BARCODE,
SKIP_REASON,
LANE_ID,
LAST_CASE,
TO_CHAR(DIVERT_TIME,'DD-MON-YY HH24:MI:SS.FF3') DIVERT_TIME,
LABEL_TYPE,
MESSAGE_NAME,
SYMBOTIC_STATUS,
FILE_NAME,
TO_CHAR(FILE_TIMESTAMP,'DD-MON-YY HH24:MI:SS.FF3') FILE_TIMESTAMP,
ROW_COUNT,
ORDER_ID,
ACTION_CODE,
REASON_CODE,
INTERFACE_TYPE,
USER_ID,
CELL_ID,
TO_CHAR(EVENT_TIMESTAMP,'DD-MON-YY HH24:MI:SS.FF3') EVENT_TIMESTAMP,
REWORKED_QTY,
VERIFIED_QTY,
REJECTED_QTY
FROM SWMS.MATRIX_IN
WHERE INTERFACE_REF_DOC = 'SYM15'
ORDER BY ADD_DATE DESC, SEQUENCE_NUMBER DESC;

CREATE OR REPLACE VIEW SWMS.V_MX_IN_SYM16 AS
SELECT 
SEQUENCE_NUMBER,
MX_MSG_ID,
INTERFACE_REF_DOC,
REC_IND,
REC_COUNT,
RECORD_STATUS,
ADD_DATE,
ADD_USER,
UPD_DATE,
UPD_USER,
PROD_ID,
ERM_ID,
PARENT_PALLET_ID,
PALLET_ID,
MX_REASON_CODE,
CASE_QTY,
QTY_STORED,
SPUR_LOC,
ORDER_TYPE,
SELECTION_REL_SEQ,
BATCH_ID,
TASK_ID,
RELEASE_TYPE,
QTY_INDUCTED,
QTY_DAMAGED,
QTY_OUT_OF_TOLERANCE,
QTY_WRONG_ITEM,
QTY_SHORT,
QTY_OVER,
TO_CHAR(STORED_TIME,'DD-MON-YY HH24:MI:SS.FF3') STORED_TIME,
TO_CHAR(MSG_TIME,'DD-MON-YY HH24:MI:SS.FF3') MSG_TIME,
ERROR_MSG,
ERROR_CODE,
TRANS_TYPE,
TO_CHAR(SEQUENCE_TIMESTAMP,'DD-MON-YY HH24:MI:SS.FF3') SEQUENCE_TIMESTAMP,
CASE_BARCODE,
SKIP_REASON,
LANE_ID,
LAST_CASE,
TO_CHAR(DIVERT_TIME,'DD-MON-YY HH24:MI:SS.FF3') DIVERT_TIME,
LABEL_TYPE,
MESSAGE_NAME,
SYMBOTIC_STATUS,
FILE_NAME,
TO_CHAR(FILE_TIMESTAMP,'DD-MON-YY HH24:MI:SS.FF3') FILE_TIMESTAMP,
ROW_COUNT,
ORDER_ID,
ACTION_CODE,
REASON_CODE,
INTERFACE_TYPE,
USER_ID,
CELL_ID,
TO_CHAR(EVENT_TIMESTAMP,'DD-MON-YY HH24:MI:SS.FF3') EVENT_TIMESTAMP,
REWORKED_QTY,
VERIFIED_QTY,
REJECTED_QTY
FROM SWMS.MATRIX_IN
WHERE INTERFACE_REF_DOC = 'SYM16'
ORDER BY ADD_DATE DESC, SEQUENCE_NUMBER DESC;

CREATE OR REPLACE VIEW SWMS.V_MX_IN_SYM17 AS
SELECT 
SEQUENCE_NUMBER,
MX_MSG_ID,
INTERFACE_REF_DOC,
REC_IND,
REC_COUNT,
RECORD_STATUS,
ADD_DATE,
ADD_USER,
UPD_DATE,
UPD_USER,
PROD_ID,
ERM_ID,
PARENT_PALLET_ID,
PALLET_ID,
MX_REASON_CODE,
CASE_QTY,
QTY_STORED,
SPUR_LOC,
ORDER_TYPE,
SELECTION_REL_SEQ,
BATCH_ID,
TASK_ID,
RELEASE_TYPE,
QTY_INDUCTED,
QTY_DAMAGED,
QTY_OUT_OF_TOLERANCE,
QTY_WRONG_ITEM,
QTY_SHORT,
QTY_OVER,
TO_CHAR(STORED_TIME,'DD-MON-YY HH24:MI:SS.FF3') STORED_TIME,
TO_CHAR(MSG_TIME,'DD-MON-YY HH24:MI:SS.FF3') MSG_TIME,
ERROR_MSG,
ERROR_CODE,
TRANS_TYPE,
TO_CHAR(SEQUENCE_TIMESTAMP,'DD-MON-YY HH24:MI:SS.FF3') SEQUENCE_TIMESTAMP,
CASE_BARCODE,
SKIP_REASON,
LANE_ID,
LAST_CASE,
TO_CHAR(DIVERT_TIME,'DD-MON-YY HH24:MI:SS.FF3') DIVERT_TIME,
LABEL_TYPE,
MESSAGE_NAME,
SYMBOTIC_STATUS,
FILE_NAME,
TO_CHAR(FILE_TIMESTAMP,'DD-MON-YY HH24:MI:SS.FF3') FILE_TIMESTAMP,
ROW_COUNT,
ORDER_ID,
ACTION_CODE,
REASON_CODE,
INTERFACE_TYPE,
USER_ID,
CELL_ID,
TO_CHAR(EVENT_TIMESTAMP,'DD-MON-YY HH24:MI:SS.FF3') EVENT_TIMESTAMP,
REWORKED_QTY,
VERIFIED_QTY,
REJECTED_QTY
FROM SWMS.MATRIX_IN
WHERE INTERFACE_REF_DOC = 'SYM17'
ORDER BY ADD_DATE DESC, SEQUENCE_NUMBER DESC;