CREATE OR REPLACE PACKAGE pl_cmu_ins_cross_dock AS
/********************************************
  Name:  pl_cmu_ins_cross_dock
  Purpose: Processing staging table per SN into staging tables
  REVISIONS:
  Jira		Date		Author 		Description
  ------------	--------------	-------		---------------------------------------------------	
		Sept 14, 2019	knha8378	Modify how to process swms_floats_in, swms_float_detail_in
						and swms_orcdw_in along with ERD_LPN
 
************************************************/
  
-----------------------------------------------------------------------------------
-- Procedures
-----------------------------------------------------------------------------------


PROCEDURE ins_cdk_from_erd_lpn (i_erm_id  IN erm.erm_id%type);
PROCEDURE upd_cdk_from_float (i_erm_id  IN erm.erm_id%TYPE);
PROCEDURE process_cmu_sn;
PROCEDURE ins_sn_rdc_po (i_erm_id IN erm.erm_id%TYPE);
END pl_cmu_ins_cross_dock;
/

CREATE OR REPLACE PACKAGE BODY pl_cmu_ins_cross_dock AS

ct_application_function VARCHAR2(30) := 'RECEIVING';
gl_pkg_name	 varchar2(30) := 'PL_CMU_INS_CROSS_DOCK';
g_parameter_null EXCEPTION;

 PROCEDURE ins_cdk_from_erd_lpn (i_erm_id  in erm.erm_id%type) IS
   
   l_object_name		varchar2(30) := 'ins_cdk_from_erd_lpn';
   l_default_retail_cust_no   	varchar2(30) := '0000';
   l_default_ship_date		date := trunc(sysdate);
   l_area			varchar2(1) := 'D';
   l_seq			number;

   CURSOR Header_erd_lpn (c_erm_id IN erm.erm_id%TYPE) is
     SELECT DISTINCT
	    parent_pallet_id,
	    SUBSTR(sn_no,instr(sn_no,'-')+1,1) area,
	    cmu_indicator
     from erd_lpn
     where sn_no = c_erm_id
     and   nvl(cmu_indicator,'X') = 'C';
 
   CURSOR Detail_erd_lpn (c_erm_id IN erm.erm_id%TYPE) is
     SELECT parent_pallet_id, master_order_id, sn_no, 
	   SUBSTR(sn_no,instr(sn_no,'-')+1,1) area,
	   erm_line_id, prod_id, qty, po_no, pallet_id, cmu_indicator,
	   exp_date, mfg_date, catch_weight
     FROM erd_lpn
     where sn_no = c_erm_id
     and   nvl(cmu_indicator,'X') = 'C';

BEGIN

    pl_log.ins_msg
    (pl_log.ct_info_msg, l_object_name,
     'Starting procedure for extract from erd_lpn on SN#=' || '[i_erm_id]=' || i_erm_id,
     NULL,NULL,
     ct_application_function, gl_pkg_name);
    SELECT mx_batch_no_seq.nextval into l_seq from dual;

    /* We will put record_status as H to Hold off from processing
       until we update and complete for other staging tables such as
       SWMS_FLOATS_IN, SWMS_FLOAT_DETAIL_IN, SWMS_ORDCW_IN 
    */
    FOR H_rec IN Header_erd_lpn (i_erm_id) LOOP
      IF nvl(H_rec.area,'X') not in ('F','D','C') then
	 l_area := 'X'; /* Update area later from SWMS_FLOATS_IN */
      ELSE
	 l_area := H_rec.area;
      END IF;	  
      INSERT INTO cross_dock_data_collect_in
        (sequence_number, msg_id,interface_type,record_status,
         retail_cust_no,ship_date,parent_pallet_id,
         erm_id,rec_type,area, cmu_indicator, add_user,add_date)
       VALUES
         (cross_dock_data_collect_seq.nextval, l_seq, 'CMU','H',
          l_default_retail_cust_no, l_default_ship_date, H_rec.parent_pallet_id,
	  i_erm_id, 'P', l_area, H_rec.cmu_indicator,USER,SYSDATE);
     END LOOP;
     FOR D_rec in Detail_erd_lpn (i_erm_id) LOOP
         IF nvl(D_rec.area,'X') not in ('F','D','C') then
	    l_area := 'X'; /* Update area later from SWMS_FLOATS_IN */
         END IF;	  
	 INSERT INTO cross_dock_data_collect_in
            (sequence_number, msg_id,interface_type,record_status,
             retail_cust_no, ship_date, parent_pallet_id,
             erm_id, rec_type, area, master_order_id, line_no, prod_id,
	     qty, uom, cmu_indicator, pallet_id, sys_order_id,
	     exp_date, mfg_date, add_user, add_date, catch_wt, pallet_type)
         SELECT cross_dock_data_collect_seq.nextval, l_seq, 'CMU', 'H', 
             l_default_retail_cust_no, l_default_ship_date, D_rec.parent_pallet_id,
	     D_rec.sn_no, 'D', l_area, D_rec.master_order_id, D_rec.erm_line_id, D_rec.prod_id,
	     D_rec.qty, '2', D_rec.cmu_indicator, D_rec.pallet_id, D_rec.po_no,
	     D_rec.exp_date, D_rec.mfg_date, USER, SYSDATE, 
             DECODE(nvl(D_rec.catch_weight,0),0,null,D_rec.catch_weight),'LW'
          FROM DUAL;
      END LOOP;
      COMMIT;
END ins_cdk_from_erd_lpn;

 PROCEDURE upd_cdk_from_float (i_erm_id  IN erm.erm_id%TYPE) IS

    l_object_name	VARCHAR2(30) := 'UPD_CDK_FROM_FLOAT';
    l_route_no   	route.route_no%TYPE; 
    l_end_cust_id	swms_float_detail_in.end_cust_id%TYPE;
    l_float_no		floats.float_no%TYPE;
    l_parent_pallet_id	inv.parent_pallet_id%TYPE;
    l_ship_date		date;
    l_door_area		floats.door_area%TYPE;

    CURSOR H_data_collect_in IS
      SELECT sequence_number,interface_type,erm_id,ship_date,area,
           record_status,retail_cust_no, parent_pallet_id
      FROM cross_dock_data_collect_in
      WHERE rec_type = 'P'
      and   cmu_indicator = 'C'
      and   record_status = 'H'
      and   erm_id = i_erm_id;

    CURSOR get_floats (c_route_no           IN route.route_no%TYPE,
		       c_parent_pallet_id   IN inv.parent_pallet_id%TYPE) IS
      SELECT DISTINCT
	 float_no,rdc_outbound_parent_pallet_id, 
	 f.ship_date, f.door_area
      FROM swms_floats_in f
      WHERE route_no = c_route_no
      AND   rdc_outbound_parent_pallet_id = c_parent_pallet_id;

    CURSOR get_retail_cust_no (c_float_no floats.float_no%TYPE,
			       c_route_no route.route_no%TYPE) IS
      SELECT distinct end_cust_id
      FROM swms_float_detail_in
      WHERE route_no = c_route_no
      and   float_no = c_float_no
      and   cmu_indicator = 'C';

    CURSOR D_data_collect_in IS
       SELECT *
       FROM cross_dock_data_collect_in
       WHERE rec_type = 'D'
       and  erm_id = i_erm_id
       and  record_status = 'H';

    l_uom		swms_float_detail_in.uom%TYPE;
    l_carrier_id	swms_float_detail_in.carrier_id%TYPE;
    l_lot_id		swms_float_detail_in.lot_id%TYPE;
    l_order_seq		swms_float_detail_in.order_seq%TYPE;
    l_item_seq		swms_float_detail_in.item_seq%TYPE;
    l_order_id		swms_float_detail_in.order_id%TYPE;
    l_order_line_id	swms_float_detail_in.order_line_id%TYPE;
    CURSOR get_float_detail (c_route_no		ROUTE.route_no%TYPE,
			     c_float_no		floats.float_no%TYPE,
			     c_pallet_id	swms_float_detail_in.rdc_outbound_child_pallet_id%TYPE,
			     c_prod_id		pm.prod_id%TYPE) IS
	SELECT distinct order_id,order_line_id,uom,carrier_id,lot_id,order_seq,item_seq,end_cust_id
	FROM swms_float_detail_in
	WHERE route_no = c_route_no
	AND   float_no = c_float_no
	AND   rdc_outbound_child_pallet_id = c_pallet_id
	AND   prod_id  = c_prod_id;

    CURSOR get_ordcw 	(c_cw_float_no  	swms_ordcw_in.cw_float_no%TYPE,
			    c_order_id		swms_ordcw_in.order_id%TYPE,
			    c_order_line_id	swms_ordcw_in.order_line_id%type,
			    c_prod_id		swms_ordcw_in.prod_id%TYPE,
			    c_order_seq		swms_ordcw_in.order_seq%TYPE) IS
       SELECT *
       FROM swms_ordcw_in
       WHERE cw_float_no = c_cw_float_no
       AND   order_id = c_order_id
       AND   order_line_id = c_order_line_id
       AND   prod_id = c_prod_id
       AND   order_seq = c_order_seq
       AND   record_status = 'N';
BEGIN
   l_route_no := 'CS' || substr(i_erm_id,1,(instr(i_erm_id,'-')-1));

    pl_log.ins_msg
    (pl_log.ct_info_msg, l_object_name,
     'Starting procedure for cross dock from float data and SN#=[' || i_erm_id || ']' ||
     '  Route# translated as [' || l_route_no || ']',
     NULL,NULL,
     ct_application_function, gl_pkg_name);

   FOR H_rec IN H_data_collect_in LOOP
    pl_log.ins_msg
    (pl_log.ct_info_msg, l_object_name,
     'Starting FOR H_rec H_date_collect SN#=[' || i_erm_id || ']' ||
     '  Route# translated as [' || l_route_no || ']',
     NULL,NULL,
     ct_application_function, gl_pkg_name);
      OPEN get_floats (l_route_no, H_rec.parent_pallet_id);
      FETCH get_floats into l_float_no,l_parent_pallet_id,l_ship_date,l_door_area;
      IF get_floats%NOTFOUND THEN
         pl_log.ins_msg(pl_log.ct_fatal_msg, l_object_name, 'cursor get_floats NOTFOUND Return error',null,null,
		       ct_application_function,gl_pkg_name);

      ELSE
         IF H_rec.retail_cust_no = '0000' THEN
	    OPEN get_retail_cust_no (l_float_no,l_route_no);
	    FETCH get_retail_cust_no INTO l_end_cust_id;
	    IF get_retail_cust_no%NOTFOUND THEN
               pl_log.ins_msg(pl_log.ct_fatal_msg, l_object_name, 'cursor get_retail_cust_no NOTFOUND Return error',null,null,
		       ct_application_function,gl_pkg_name);
	    ELSE
              pl_log.ins_msg
              (pl_log.ct_info_msg, l_object_name,
               'get_retail_cust_no cursor FOUND and SN#=[' || i_erm_id || ']' ||
              '  original retail_cust_no [' || H_rec.retail_cust_no || ']  l_end_cust_id:' || l_end_cust_id || '  Seq#:'|| to_char(H_rec.sequence_number),
              NULL,NULL,
              ct_application_function, gl_pkg_name);
	      UPDATE cross_dock_data_collect_in
	        set retail_cust_no = l_end_cust_id,
		   record_status = 'N',
		   ship_date = l_ship_date,
		   area = decode(H_rec.area,'X',l_door_area,area)
               where rec_type = 'P'
	       and   erm_id = i_erm_id
	       and   record_status = 'H'
	       and   sequence_number = H_rec.sequence_number;
	       IF SQL%NOTFOUND THEN
                  pl_log.ins_msg
                    (pl_log.ct_fatal_msg, l_object_name,
                     'FAIL Updating cross_dock_collect_in SN#=[' || i_erm_id || ']' ||
                     '  SEQUENCE NUMBER [' || to_char(H_rec.sequence_number) || ']',
                     NULL,NULL,
                     ct_application_function, gl_pkg_name);
	       END IF;

	       UPDATE swms_floats_in
		 set record_status = 'S'
		 where record_status = 'N'
		 and   route_no = l_route_no
		 and   rdc_outbound_parent_pallet_id = H_rec.parent_pallet_id;
               IF SQL%NOTFOUND THEN
                  pl_log.ins_msg
                    (pl_log.ct_fatal_msg, l_object_name,
                     'FAIL Updating swms_floats SN#=[' || i_erm_id || ']' ||
                     '  rdc_outbound_parent_pallet_id [' || to_char(H_rec.parent_pallet_id) || ']',
                     NULL,NULL,
                     ct_application_function, gl_pkg_name);
		END IF;
	    END IF; --get_retail_cust_no cursor
	    CLOSE get_retail_cust_no;
              pl_log.ins_msg
                (pl_log.ct_info_msg, l_object_name,
                'Before close get_retail_cust_no cursor SN#=[' || i_erm_id || ']' ||
                '  Route# translated as [' || l_route_no || ']  l_end_cust_id or retail_cust_no:[' || l_end_cust_id || ']',
                NULL,NULL,
                 ct_application_function, gl_pkg_name);
        END IF; --retail_cust_no = 0000
    END IF; --cursor get_floats
    CLOSE get_floats;
  END LOOP; /* H_data_collect_in cursor loop */
  COMMIT;

   FOR D_rec IN D_data_collect_in LOOP
       OPEN get_floats (l_route_no,D_rec.parent_pallet_id);
       FETCH get_floats into l_float_no,l_parent_pallet_id,l_ship_date,l_door_area;
       IF get_floats%FOUND then
	  OPEN get_float_detail (l_route_no,l_float_no,D_rec.pallet_id,D_rec.prod_id);
	  FETCH get_float_detail INTO l_order_id,l_order_line_id,l_uom,l_carrier_id,l_lot_id,
				      l_order_seq,l_item_seq,l_end_cust_id;
	  IF get_float_detail%FOUND then
              	UPDATE cross_dock_data_collect_in
			set record_status = 'N',
			    retail_cust_no = l_end_cust_id,
			    ship_date = l_ship_date,
			    area = decode(D_rec.area,'X',l_door_area,area),
			    uom = l_uom,
			    carrier_id = l_carrier_id,
			    lot_id = l_lot_id,
			    order_seq = l_order_seq,
			    item_seq = l_item_seq,
			    upd_user = USER,
			    upd_date = sysdate
                WHERE record_status='H'
		and   rec_type = 'D'
		and   sequence_number = D_rec.sequence_number
		and   erm_id = i_erm_id
		and   pallet_id = D_rec.pallet_id
		and   prod_id = D_rec.prod_id;
		IF SQL%NOTFOUND THEN
                  pl_log.ins_msg
                    (pl_log.ct_fatal_msg, l_object_name,
                     'FAIL Updating cross_dock_data_collect_in SN#=[' || i_erm_id || ']' ||
                     '  SEQUENCE NUMBER [' || to_char(D_rec.sequence_number) || ']  Pallet ID:' || D_rec.pallet_id || '  ProdID:' || D_rec.prod_id,
                     NULL,NULL,
                     ct_application_function, gl_pkg_name);
		END IF; 


		UPDATE swms_float_detail_in
		  set record_status = 'S'
		  WHERE route_no = l_route_no
		  AND   record_status = 'N'
		  AND   float_no = l_float_no
		  AND   rdc_outbound_child_pallet_id = D_rec.pallet_id
		  AND   order_id = l_order_id
		  AND   order_line_id = l_order_line_id
		  AND   prod_id = D_rec.prod_id;
		IF SQL%NOTFOUND THEN
                  pl_log.ins_msg
                    (pl_log.ct_fatal_msg, l_object_name,
                     'FAIL Updating swms_float_detail_in SN#=[' || i_erm_id || ']' ||
                     '  rdc_outbound_child_pallet_id [' || to_char(D_rec.pallet_id) || '] Pallet ID:' || D_rec.pallet_id || '  ProdID:' || D_rec.prod_id ,
                     NULL,NULL,
                     ct_application_function, gl_pkg_name);
		END IF;
		FOR C_cwt_rec IN get_ordcw (l_float_no,l_order_id,l_order_line_id,D_rec.prod_id,l_order_seq) LOOP
		    INSERT INTO cross_dock_data_collect_in
		      (sequence_number,interface_type,record_status,datetime,retail_cust_no,ship_date,erm_id,rec_type,
		       prod_id,line_no,area,catch_wt,catch_wt_uom,msg_id,add_user,add_date,master_order_id,case_id,
		       order_seq,item_seq,cmu_indicator,pallet_id,cw_type,sys_order_id)
                    SELECT
		     cross_dock_data_collect_seq.nextval,'CMU','N',SYSDATE,l_end_cust_id,l_ship_date,i_erm_id,'C',
		      C_cwt_rec.prod_id,D_rec.line_no,decode(D_rec.area,'X',l_door_area,D_rec.area),C_cwt_rec.catch_weight,
		      C_cwt_rec.uom,D_rec.msg_id,USER,SYSDATE,D_rec.master_order_id,C_cwt_rec.case_id,
		      C_cwt_rec.order_seq,l_item_seq,D_rec.cmu_indicator,D_rec.pallet_id,C_cwt_rec.cw_type,D_rec.sys_order_id
                    FROM dual;
		    
		    UPDATE swms_ordcw_in
		          set record_status='S'
		       WHERE sequence_number = C_cwt_rec.sequence_number
		       AND   record_status='N'
		       AND   order_id = C_cwt_rec.order_id
		       AND   order_line_id = C_cwt_rec.order_line_id
		       AND   case_id = C_cwt_rec.case_id
		       AND   prod_id = C_cwt_rec.prod_id;
                END LOOP; /* get_ordcw cursor loop */

	   ELSE /* get_float_detail NOTFOUND */
               pl_log.ins_msg(pl_log.ct_fatal_msg, l_object_name, 'cursor get_float_detail NOTFOUND Return error',null,null,
		       ct_application_function,gl_pkg_name);

           END IF; /* get_float_detail cursor */
	   CLOSE get_float_detail;
        ELSE /* cursor get_floats NOTFOUND */
               pl_log.ins_msg(pl_log.ct_fatal_msg, l_object_name, 'cursor get_floats NOTFOUND Return error',null,null,
		       ct_application_function,gl_pkg_name);
        END IF; /* get_floats cursor */
	CLOSE get_floats;
        
    END LOOP; /* D_data_collect cursor loop */
    COMMIT;
END upd_cdk_from_float;


PROCEDURE process_cmu_sn IS

  l_object_name  VARCHAR2(30) := 'PROCESS_CMU_SN';
  CURSOR get_unprocess_sn IS
     select erm_id
     from erm
     where erm_type = 'SN'
     and   status in ('NEW','SCH')
     and   erm_id = po
     and   cmu_process_complete is null;
  BEGIN
    FOR i_rec in get_unprocess_sn LOOP
           pl_log.ins_msg
             (pl_log.ct_info_msg, l_object_name,
              'GET_UNPROCESS_SN BEFORE ins_sn_rdc_po SN#=' || '[i_rec.erm_id]=' || i_rec.erm_id,
               NULL,NULL,
               ct_application_function, gl_pkg_name);
        pl_cmu_ins_cross_dock.ins_sn_rdc_po(i_rec.erm_id);
           pl_log.ins_msg
             (pl_log.ct_info_msg, l_object_name,
              'GET_UNPROCESS_SN AFTER ins_sn_rdc_po SN#=' || '[i_rec.erm_id]=' || i_rec.erm_id,
               NULL,NULL,
               ct_application_function, gl_pkg_name);
        pl_rcv_cross_dock.Split_CMU_SN(i_rec.erm_id);	
    END LOOP;

   EXCEPTION WHEN OTHERS THEN
    pl_log.ins_msg
    (pl_log.ct_fatal_msg, l_object_name,
     'EXCEPTION WHEN OTHERS ERROR',
     SQLCODE,SQLERRM,
     ct_application_function, gl_pkg_name);
      RAISE_APPLICATION_ERROR(pl_exc.ct_database_error,
            l_object_name || ': ' || SQLERRM);
END process_cmu_sn;

PROCEDURE ins_sn_rdc_po (i_erm_id IN erm.erm_id%TYPE) IS
  l_object_name  VARCHAR2(30) := 'INS_SN_RDC_PO';
  CURSOR get_po (c_erm_id erm.erm_id%TYPE) IS
    select distinct po_no
    from erd_lpn
    where sn_no = c_erm_id;

  l_tmp_var  varchar2(1);
  CURSOR ck_sn_po_exist (c_sn_no  erm.erm_id%TYPE,
			 c_po_no  erm.erm_id%TYPE) IS
    SELECT 'X'
    FROM sn_rdc_po
    WHERE po_no = c_po_no
    AND   sn_no = c_sn_no;

 BEGIN
     FOR i_rec IN get_po (i_erm_id) LOOP
        OPEN ck_sn_po_exist (i_erm_id, i_rec.po_no);
	FETCH ck_sn_po_exist into l_tmp_var;
	IF ck_sn_po_exist%NOTFOUND THEN
	   insert into SN_RDC_PO
	    (po_no,sn_no)
	    VALUES
	    (i_rec.po_no, i_erm_id);
           pl_log.ins_msg
             (pl_log.ct_info_msg, l_object_name,
              'INSERTING INTO SN_RDC_PO WITH SN#=' || '[i_erm_id]=' || i_erm_id || ' PO#:' || i_rec.po_no,
               NULL,NULL,
               ct_application_function, gl_pkg_name);
            COMMIT;
	END IF;
	CLOSE ck_sn_po_exist;
     END LOOP;
   EXCEPTION WHEN OTHERS THEN
    pl_log.ins_msg
    (pl_log.ct_fatal_msg, l_object_name,
     'EXCEPTION WHEN OTHERS ERROR FOR SN#=' || '[i_erm_id]=' || i_erm_id,
     SQLCODE,SQLERRM,
     ct_application_function, gl_pkg_name);
 END ins_sn_rdc_po;
END pl_cmu_ins_cross_dock;
/
