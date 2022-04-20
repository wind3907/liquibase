CREATE OR REPLACE VIEW SWMS.V_MX_OUT_SYS15 AS
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
WHERE INTERFACE_REF_DOC = 'SYS15'
ORDER BY ADD_DATE DESC, SEQUENCE_NUMBER DESC;

create or replace public synonym v_mx_out_sys15 for swms.v_mx_out_sys15;

grant select on v_mx_out_sys15 to swms_viewer;

grant all on v_mx_out_sys15 to swms_user;
