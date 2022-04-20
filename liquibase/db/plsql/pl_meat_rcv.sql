

/**************************************************************************/
-- Package Specification
/**************************************************************************/

CREATE OR REPLACE PACKAGE pl_meat_rcv IS

FUNCTION f_erm_status (i_erm_id  IN erm.erm_id%TYPE) RETURN CHAR;
FUNCTION f_del_inv_put (i_erm_id IN erm.erm_id%TYPE) RETURN NUMBER;


END pl_meat_rcv;
/


CREATE OR REPLACE PACKAGE BODY pl_meat_rcv IS

  
  FUNCTION f_erm_status (i_erm_id  IN erm.erm_id%TYPE) RETURN CHAR IS
     l_status   ERM.STATUS%TYPE := 'XXX'; 
   BEGIN
       SELECT status 
       into l_status
       FROM erm
       WHERE erm_id = i_erm_id;
       
       RETURN l_status;

     EXCEPTION when no_data_found then
	return 'XXX';
   END f_erm_status;

   FUNCTION f_del_inv_put (i_erm_id IN erm.erm_id%TYPE) RETURN NUMBER IS

       l_count_del   number:= 0;

       CURSOR get_inv IS
       SELECT i.prod_id,i.qoh,i.plogi_loc,i.logi_loc,i.exp_date,
	      i.qty_produced, sigma_qty_produced,qty_planned,i.mfg_date
       FROM INV i
       WHERE rec_id = i_erm_id
       AND   nvl(qty_produced,0) = 0
       AND   nvl(sigma_qty_produced,0) = 0
       AND   EXISTS (select 1 
                    FROM putawaylst p 
                    where i.rec_id = p.rec_id 
		       and p.putaway_put = 'N' 
		       and p.prod_id = i.prod_id
		       and p.status = 'NEW'
		       and p.pallet_id = i.logi_loc);
   BEGIN
      FOR i_rec IN get_inv LOOP
	DELETE FROM putawaylst
	   WHERE rec_id = i_erm_id
	   AND   prod_id = i_rec.prod_id
	   AND   pallet_id = i_rec.logi_loc;
	DELETE FROM inv
	  where logi_loc = i_rec.logi_loc
	  and   rec_id = i_erm_id
	  and   prod_id = i_rec.prod_id;
        IF SQL%FOUND THEN
	   l_count_del := l_count_del + 1;
		  INSERT INTO trans
		  (TRANS_ID, TRANS_TYPE, TRANS_DATE, PROD_ID, REC_ID, EXP_DATE, QTY_EXPECTED,
		   QTY, UOM, SRC_LOC, USER_ID, OLD_STATUS, REASON_CODE, PALLET_ID,
		   CUST_PREF_VENDOR, WAREHOUSE_ID, PO_NO, CMT, MFG_DATE)
		  SELECT trans_id_seq.nextval, 'ADJ', sysdate, i_rec.prod_id,
		    i_erm_id,   i_rec.exp_date,
		    i_rec.qoh   QTY_EXPECTED,
		    (-1 * i_rec.qoh)    QTY,
		    2                        uom,
		    i_rec.plogi_loc          SRC_LOC,
		    USER     	                user_id,
		   'AVL'                                     OLD_STATUS,
		   'OB'                                      REASON_CODE,
		    i_rec.logi_loc                          pallet_id,
		  '-'                                       CUST_PREF_VENDOR,
		  '000'                                     WAREHOUSE_ID,
		  i_erm_id                                  PO_NO,
		  'DELETE INV DUE TO 0 RECEIVED AND 0 SIGMA' ,
		  i_rec.mfg_date
		   FROM dual;
        END IF;
      END LOOP;
      RETURN l_count_del;
  END f_del_inv_put;
END  pl_meat_rcv;
/
