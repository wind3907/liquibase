REM @(#) src/schema/views/v_float_hist.sql, swms, swms.9, 10.1.1 9/7/06 1.3
REM File : @(#) src/schema/views/v_float_hist.sql, swms, swms.9, 10.1.1
REM Usage: sqlplus USR/PWD @src/schema/views/v_float_hist.sql, swms, swms.9, 10.1.1
REM

REM MODIFICATION HISTORY
REM 05/02/05 prpakp Created a new table ARCH_FLOAT_HIST to move all the data 
REM		    from float_hist that are not for todays ship date. The
REM                 float_hist table will only have data for one day. This view
REM		    is to combine both float_hist and arch_float_hist for
REM		    return error tracking reports.

CREATE or REPLACE view swms.v_float_hist as
SELECT  BATCH_NO,
 	ROUTE_NO,
 	USER_ID,
 	PROD_ID,
 	ORDER_ID,
 	ORDER_LINE_ID,
	CUST_ID,
 	QTY_ORDER,
 	QTY_ALLOC,
 	MERGE_ALLOC_FLAG,
 	STOP_NO,
 	UOM,
 	SHIP_DATE,
 	SRC_LOC,
 	CUST_PREF_VENDOR,
 	SLOT_NO,
 	QTY_SHORT,
 	SHORT_REASON,
 	CATCHWEIGHT,
 	PICKTIME,
 	EXP_DATE,
 	MFG_DATE,
 	REC_DATE,
 	LOT_ID,
 	CONTAINER_TEMPERATURE,
 	FLOAT_NO,
 	SCAN_TYPE,
 	ADD_DATE,
 	ADD_USER,
 	SHORT_BATCH_NO,
 	SHORT_USER_ID,
 	SHORT_PICKTIME
FROM FLOAT_HIST
UNION
SELECT  BATCH_NO,
 	ROUTE_NO,
 	USER_ID,
 	PROD_ID,
 	ORDER_ID,
 	ORDER_LINE_ID,
	CUST_ID,
 	QTY_ORDER,
 	QTY_ALLOC,
 	MERGE_ALLOC_FLAG,
 	STOP_NO,
 	UOM,
 	SHIP_DATE,
 	SRC_LOC,
 	CUST_PREF_VENDOR,
 	SLOT_NO,
 	QTY_SHORT,
 	SHORT_REASON,
 	CATCHWEIGHT,
 	PICKTIME,
 	EXP_DATE,
 	MFG_DATE,
 	REC_DATE,
 	LOT_ID,
 	CONTAINER_TEMPERATURE,
 	FLOAT_NO,
 	SCAN_TYPE,
 	ADD_DATE,
 	ADD_USER,
 	SHORT_BATCH_NO,
 	SHORT_USER_ID,
 	SHORT_PICKTIME
FROM ARCH_FLOAT_HIST
/

