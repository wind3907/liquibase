CREATE OR REPLACE PACKAGE SWMS.PL_DOD_LABEL_GEN
AS
---------------------------------------------------------------------------
-- Package Name:
--   PL_DOD_LABEL_GEN
--
-- Description:
--    This package inserts data into DOD specific tables.
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    3/4/2016 skam7488 Charm# 6000009943 - Created for DOD labels Project.
--    6/3/2016 skam7488 Production defect fix to correct start seq on the label
--    03/05/18 mpha8134 Calculate/populate mfg_date and exp_date if they are null.
---------------------------------------------------------------------------

---------------------------------------------------------------------------
-- Procedure:
--    DOD_LABEL_GEN_HEADER
--
-- Description:
--    This procedure inserts data into DOD_LABEL_HEADER.
---------------------------------------------------------------------------
   PROCEDURE DOD_LABEL_GEN_HEADER (i_route_batch_no IN route.route_batch_no%TYPE);
---------------------------------------------------------------------------
-- Procedure:
--    DOD_LABEL_GEN_DTL
--
-- Description:
--    This procedure inserts data into DOD_LABEL_DETAIL.
---------------------------------------------------------------------------
  PROCEDURE DOD_LABEL_GEN_DTL (i_route_no IN ordd.route_no%TYPE, i_order_id IN ordd.order_id%TYPE);
   
END PL_DOD_LABEL_GEN;
/

CREATE OR REPLACE PACKAGE BODY SWMS.PL_DOD_LABEL_GEN
IS   

    PROCEDURE DOD_LABEL_GEN_HEADER (i_route_batch_no IN route.route_batch_no%TYPE)
    IS
   
        l_route_no ordm.route_no%TYPE;
        l_order_id ordm.order_id%TYPE;
        l_stop_no ordm.stop_no%TYPE;
        l_truck_no ordm.truck_no%TYPE;
        l_cust_id ordm.cust_id%TYPE;
        l_cust_name ordm.cust_name%TYPE;
        l_dod_contract_no ordm.dod_contract_no%TYPE;
        l_ship_date ordm.ship_date%TYPE;
        l_status ordm.status%TYPE;
                        
        CURSOR c_get_ord_hdr IS
           SELECT  o.route_no, o.order_id, o.stop_no,
                   o.truck_no, o.status, o.ship_date, o.cust_id, o.cust_name,
                   o.dod_contract_no
           FROM    route r, ordm o
           WHERE   o.route_no = r.route_no
           AND     o.truck_no = r.truck_no
           AND     r.route_batch_no = i_route_batch_no;
      
        BEGIN
        pl_text_log.ins_msg('INFO', 'PL_DOD_LABEL_GEN',
        'Started Execution of DOD_LABEL_GEN_HEADER for Route Batch ' || i_route_batch_no || ' at ' || to_char(sysdate,'MM/DD/YYYY HH24:MI:SS') , NULL, NULL);
        OPEN c_get_ord_hdr;
        LOOP 
           
            FETCH c_get_ord_hdr INTO l_route_no, l_order_id, l_stop_no,
                                l_truck_no, l_status, l_ship_date, l_cust_id, l_cust_name, l_dod_contract_no;
                                
            IF c_get_ord_hdr%NOTFOUND THEN
                pl_text_log.ins_msg('INFO', 'DOD_LABEL_GEN_HEADER',
                'No More Records found for c_get_ord_hdr', NULL, NULL);
                EXIT;
            END IF;

            IF (l_dod_contract_no IS NULL) THEN
                pl_text_log.ins_msg('INFO', 'DOD_LABEL_GEN_HEADER',
                'DOD Contract No is Null.. Skipping the route: ' || l_route_no || ' ', NULL, NULL);
                CONTINUE;
            END IF;  
            
            pl_text_log.ins_msg('INFO', 'DOD_LABEL_GEN_HEADER',
            'Val [' || l_route_no || l_order_id || l_stop_no || l_truck_no || l_status || 
            l_ship_date || l_cust_id || l_cust_name || l_dod_contract_no || ']', NULL, NULL);
            
            INSERT INTO SWMS.DOD_LABEL_HEADER
            (route_no, 
             truck_no, 
             order_id, 
             ship_date,
             dod_contract_no,
             cust_id, 
             cust_name, 
             stop_no, 
             status,
             add_date, 
             add_user)
            values
            (l_route_no,
             l_truck_no,
             l_order_id,
             l_ship_date,
             l_dod_contract_no,
             l_cust_id,
             l_cust_name,
             l_stop_no,
             l_status,
             SYSDATE,
             USER);
             
             BEGIN         
               DOD_LABEL_GEN_DTL(l_route_no,l_order_id);
             END;
               
        END LOOP;
		
        EXCEPTION
        WHEN OTHERS THEN
            pl_text_log.ins_msg('ERROR', 'DOD_LABEL_GEN_HEADER',
	    'DOD_LABEL_GEN_HEADER Failed For route ' || l_route_no || to_char(sysdate,'MM/DD/YYYY HH24:MI:SS') , NULL, NULL);
            IF (c_get_ord_hdr%ISOPEN) THEN
                CLOSE c_get_ord_hdr;
            END IF;
            RAISE;

        CLOSE c_get_ord_hdr;

    END DOD_LABEL_GEN_HEADER;  


    PROCEDURE DOD_LABEL_GEN_DTL (i_route_no IN ordd.route_no%TYPE, i_order_id IN ordd.order_id%TYPE)
    IS
   
        l_ord_line float_detail.order_line_id%TYPE;
        l_prod_id float_detail.prod_id%TYPE;
        l_src_loc float_detail.src_loc%TYPE;
        l_qty_alloc float_detail.qty_alloc%TYPE;
        l_pallet_id floats.pallet_id%TYPE;
        l_batch_no floats.batch_no%TYPE;
        l_mfg_date float_detail.mfg_date%TYPE;
        l_exp_date float_detail.exp_date%TYPE;
        l_lot_id float_detail.lot_id%TYPE;
        l_dod_cust_item_barcode dod_label_detail.dod_cust_item_barcode%TYPE;
        l_dod_fic dod_label_detail.dod_fic%TYPE;
        l_stop_no float_detail.stop_no%TYPE;
        l_order_seq float_detail.order_seq%TYPE;        
        l_prev_ord_line float_detail.order_line_id%TYPE;
        l_prev_prod_id float_detail.prod_id%TYPE;
        l_prev_order_seq float_detail.order_seq%TYPE;
        l_start_seq NUMBER(9);
        l_end_seq NUMBER(9);
        l_prev_end_range NUMBER(9);
        l_tot_cs NUMBER(9);
        l_prev_src_loc float_detail.src_loc%TYPE;
        l_prev_mfg_date float_detail.mfg_date%TYPE;
        l_prev_exp_date float_detail.exp_date%TYPE;
        l_prev_tot_cs NUMBER(9);
        l_uom ordd.UOM%TYPE;
        l_cpv ordd.cust_pref_vendor%TYPE;
        l_spc pm.spc%TYPE;

        l_mfr_shelf_life pm.mfr_shelf_life%TYPE;
            

        CURSOR c_get_ord_dtl IS
         SELECT fd.order_line_id, fd.prod_id, fd.src_loc, fd.qty_alloc, 
                f.pallet_id, f.batch_no, fd.mfg_date, fd.exp_date, fd.lot_id, fd.order_seq,
				d.dod_cust_item_barcode,d.dod_fic,d.uom,d.cust_pref_vendor
         FROM   floats f, float_detail fd, ordd d
         WHERE  f.float_no = fd.float_no
         AND    f.route_no = fd.route_no
         AND    d.route_no = f.route_no
         AND    d.route_no = fd.route_no
         AND    d.order_id = fd.order_id
         AND    d.order_line_id = fd.order_line_id
         AND    d.prod_id = fd.prod_id
         AND    f.route_no = i_route_no
         AND    fd.route_no = i_route_no
         AND    fd.order_id = i_order_id
         AND    fd.status != 'SHT'
		 AND    f.pallet_pull != 'R'
         ORDER BY fd.order_id,fd.order_line_id,fd.order_seq;

         BEGIN

            OPEN c_get_ord_dtl;
            LOOP 
                FETCH c_get_ord_dtl INTO l_ord_line, l_prod_id, l_src_loc,
                                         l_qty_alloc,  l_pallet_id, l_batch_no,
                                         l_mfg_date, l_exp_date, l_lot_id, l_order_seq,
					 l_dod_cust_item_barcode, l_dod_fic, l_uom, l_cpv;

                IF c_get_ord_dtl%NOTFOUND THEN
				   pl_text_log.ins_msg('INFO', 'DOD_LABEL_GEN_DTL',
                   'No More Records found for c_get_ord_dtl', NULL, NULL);
                   EXIT;
                END IF;
                
                pl_text_log.ins_msg('INFO', 'DOD_LABEL_GEN_DTL',
                 'Val1 [' || l_ord_line || l_prod_id || l_src_loc || l_qty_alloc || l_pallet_id || 
                  l_mfg_date || l_exp_date || l_lot_id || l_order_seq || ']', NULL, NULL);
                
                
                
                IF (l_mfg_date is NULL) THEN
                    IF (l_exp_date is NULL) THEN -- if exp_date is null then grab the date from trans table
                        SELECT exp_date
                        INTO l_exp_date
                        FROM op_trans
                        WHERE prod_id = l_prod_id
                            AND src_loc = l_src_loc
                            AND route_no = i_route_no
                            AND (sysdate - 1) < trans_date -- Make sure the trans we are looking at is less than a day old (sysdate-1 < trans_date < sysdate)
                            AND trans_date < sysdate
                            AND (order_id = i_order_id or order_id = 'PP')
                            AND rownum = 1
                        ORDER BY trans_date desc;
                    END IF;
                    
                    -- do pack_date calcuation
                    SELECT mfr_shelf_life
                    INTO l_mfr_shelf_life
                    FROM pm
                    WHERE prod_id = l_prod_id;

                    l_mfg_date := l_exp_date - l_mfr_shelf_life;
                END IF;
                


                IF (l_uom != 1) THEN
		    SELECT spc INTO l_spc
	            FROM pm
                    WHERE prod_id = l_prod_id
		    AND   cust_pref_vendor = l_cpv;

	            l_qty_alloc := l_qty_alloc/l_spc;
		END IF;	
            
                l_start_seq := 1;
                l_end_seq := l_qty_alloc;

                IF (l_prev_ord_line = l_ord_line AND
                   l_prev_prod_id = l_prod_id AND
                   l_prev_order_seq = l_order_seq AND l_prev_src_loc = l_src_loc AND
                   ((l_prev_mfg_date IS NULL AND l_mfg_date is NULL) OR
                    l_prev_mfg_date = l_mfg_date) AND
                   ((l_prev_exp_date IS NULL AND l_exp_date is NULL) OR
                    l_prev_exp_date = l_exp_date)) THEN
                                                    
                   UPDATE SWMS.DOD_LABEL_DETAIL
                   SET qty_alloc = qty_alloc + l_qty_alloc,
                       end_seq = end_seq + l_qty_alloc,
                       upd_user = USER,
                       upd_date = SYSDATE
                       WHERE route_no = i_route_no
                       AND order_id = i_order_id
                       AND order_line_id = l_ord_line
                       AND prod_id = l_prod_id;
                       
                   l_end_seq := l_prev_end_range + l_qty_alloc;   
                   l_prev_end_range := l_end_seq;

                   CONTINUE;
                   
                ELSIF (l_prev_ord_line = l_ord_line AND
                   l_prev_prod_id = l_prod_id AND
                   l_prev_order_seq = l_order_seq ) THEN
                    
                   l_start_seq := l_prev_end_range + 1;
                   l_end_seq := l_prev_end_range + l_qty_alloc;
                   l_tot_cs := l_prev_tot_cs;
                ELSE               
                   SELECT SUM(fd.QTY_ALLOC) INTO l_tot_cs
                   FROM    float_detail fd, floats f
                   WHERE fd.route_no = i_route_no
                   AND   fd.order_id = i_order_id
                   AND   fd.order_line_id = l_ord_line
                   AND   fd.prod_id = l_prod_id
		   AND   f.route_no = fd.route_no
		   AND   f.float_no = fd.float_no
                   AND   f.pallet_pull != 'R'				   
                   GROUP  BY fd.order_id,fd.order_line_id,fd.order_seq; 
				   
		   IF (l_uom != 1) THEN
		       l_tot_cs := l_tot_cs/l_spc;
		   END IF;	
				
                END IF;
                       
                INSERT INTO SWMS.DOD_LABEL_DETAIL 
                (route_no, 
                 order_id , 
                 order_line_id, 
                 prod_id, 
                 src_loc, 
                 qty_alloc,
                 max_case_seq,                 
                 pallet_id, 
		 batch_no,
                 pack_date, 
                 exp_date , 
                 lot_id,
		 dod_cust_item_barcode,
                 dod_fic,
                 start_seq,
                 end_seq,
                 add_date,
                 add_user)
                 values
                (i_route_no,
                 i_order_id,
                 l_ord_line, 
                 l_prod_id,
                 l_src_loc,
                 l_qty_alloc,
                 l_tot_cs,
                 l_pallet_id,
                 l_batch_no,				 
                 l_mfg_date,
                 l_exp_date,
                 l_lot_id,
		 l_dod_cust_item_barcode,
                 l_dod_fic,
                 l_start_seq,
                 l_end_seq,
                 SYSDATE,
                 USER);

                 l_prev_ord_line := l_ord_line;
                 l_prev_prod_id := l_prod_id;
                 l_prev_order_seq := l_order_seq;    
                 l_prev_end_range := l_end_seq;                  
                 l_prev_src_loc := l_src_loc;
                 l_prev_tot_cs := l_tot_cs;
                 
                 IF l_mfg_date is NULL then
                    l_prev_mfg_date := NULL;
                 ELSE
                    l_prev_mfg_date := l_mfg_date;
                 END IF;
                 
                 IF l_exp_date is NULL then
                    l_prev_exp_date := NULL;
                 ELSE       
                    l_prev_exp_date := l_exp_date;
                 END IF;               
                 
            END LOOP;
		
	EXCEPTION
        WHEN OTHERS THEN
            pl_text_log.ins_msg('ERROR', 'DOD_LABEL_GEN_DTL',
	    'DOD_LABEL_GEN_DTL Failed For route ' || i_route_no || to_char(sysdate,'MM/DD/YYYY HH24:MI:SS') , NULL, NULL);
            IF (c_get_ord_dtl%ISOPEN) THEN
                CLOSE c_get_ord_dtl;
            END IF;
            RAISE;

        CLOSE c_get_ord_dtl;

    END DOD_LABEL_GEN_DTL;  
 
END PL_DOD_LABEL_GEN;
/

CREATE OR REPLACE PUBLIC SYNONYM PL_DOD_LABEL_GEN FOR SWMS.PL_DOD_LABEL_GEN;


