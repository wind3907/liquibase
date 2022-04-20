rem *************************************************************************
rem Date   :  04/10/2019
rem File   :  trg_del_inbound_cust_brow.sql
rem  
rem User Id:  XZHE5043           
rem  
rem *************************************************************************
CREATE OR REPLACE TRIGGER "SWMS"."trg_del_inbound_cust_brow" 
BEFORE DELETE ON SWMS.INBOUND_CUST_SETUP
FOR EACH ROW
DECLARE
 l_user_id     VARCHAR2 (30);
 l_old_priv    NUMBER;
 l_upd_type    VARCHAR2 (10);
BEGIN
  l_user_id := REPLACE(USER,'OPS$',NULL);

	    INSERT INTO MEAT_CL_OUT
		(SEQUENCE_NUMBER,
		CUST_ID,
		RACK_CUT_LOC,
		STAGING_LOC,
		WILLCALL_LOC,
		RECORD_STATUS,
		FUNC_CODE,
		ADD_USER,
		ADD_DATE,
		UPD_USER,
		UPD_DATE,
		ERROR_MSG)
		VALUES (
		 meat_cl_out_seq.nextVal,
		:OLD.CUST_ID,
		:OLD.RACK_CUT_LOC,
		:OLD.STAGING_LOC,
		:OLD.WILLCALL_LOC,
		'N',
		'D',
		l_user_id,
		SYSDATE,
		NULL,
		NULL,
		' '	
		);
		 
END;
/