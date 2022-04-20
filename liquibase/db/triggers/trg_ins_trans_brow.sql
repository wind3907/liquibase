/******************************************************************************
  @(#) trg_insupd_trans_arow.sql
  @(#) src/schema/triggers/trg_ins_trans_brow.sql, swms, swms.9, 10.1.1 9/8/06 1.4
******************************************************************************/

/******************************************************************************
  Modification History
  Date      User   Defect  Comment
  05/23/03  prpnxk         initial version
******************************************************************************/

--
-- Purpose: To Round off weight on a PAC transaction for selected customers.
--
--

CREATE OR REPLACE TRIGGER swms.trg_ins_trans_brow
 BEFORE INSERT ON swms.trans
   FOR EACH ROW
WHEN (NEW.trans_type IN ('SPR', 'PAC'))
BEGIN
	IF (:NEW.trans_type = 'PAC') THEN
	DECLARE
		l_round_off	NUMBER (02);
		l_order_id	ordm.order_id%TYPE;
		l_cust_id	ordm.cust_id%TYPE;
	BEGIN
		l_order_id := :NEW.order_id;
		SELECT	cust_id, catch_wt_dec
		  INTO	l_cust_id, l_round_off
		  FROM	spl_rqst_customer s, ordm o
		 WHERE	o.order_id = l_order_id
		   AND	s.customer_id = o.cust_id;
		IF (l_round_off IS NOT NULL) THEN
			:NEW.cmt := 'Customer Id = ' || l_cust_id || ', Entered Weight = ' || :NEW.weight;
			:NEW.WEIGHT := ROUND (:NEW.WEIGHT, l_round_off);
		END IF;
		EXCEPTION
			WHEN NO_DATA_FOUND THEN
				NULL;
			WHEN OTHERS THEN
				pl_log.ins_msg ('F','Catch Wt. Rndg.',
					'Route No = ' || :new.route_no || ', Order = ' || :NEW.order_id || 
					', Prod = ' || :NEW.prod_id, null, SQLERRM);

	END;
	ELSE
	DECLARE
		l_pallet_id	trans.pallet_id%TYPE;
	BEGIN
		l_pallet_id := LTRIM (RTRIM (REPLACE (:NEW.cmt, 'Old Pallet = ', NULL)));
		UPDATE	trans
		   SET	pallet_id = :NEW.pallet_id,
			cmt = 'Orig Pallet Id = '  || l_pallet_id
		 WHERE	pallet_id = l_pallet_id
		   AND	trans_type = 'RPL'
		   AND	user_id = 'ORDER'
		   AND	trans_date = (SELECT	MAX (trans_date)
					FROM	trans
				       WHERE	pallet_id = l_pallet_id
					 AND	trans_type = 'RPL'
					 AND	user_id = 'ORDER');
		UPDATE	floats
		   SET	pallet_id = :NEW.pallet_id
		 WHERE	pallet_id = l_pallet_id
		   AND	pallet_pull IN ('R', 'B', 'Y')
		   AND	STATUS IN ('OPN', 'PIK');
	END;
	END IF;
END;
/

