set echo off
CREATE OR REPLACE PACKAGE swms.pl_rpt_order_status AS

---------------------------------------------------------------------------
   -- Package Name:
   -- 	 pl_rpt_order_status
   --
   -- Description:
   --    Common procedures and functions for populating the staging table with order status.
   --	 Get all the routes from Route table.
   -- 	 For each route get all order line items.
   -- 	 If the route is in OPN status get the qty_allocated, etc.
   -- 	 If the Route is closed, populate WH_OUT_QTY, PAD, PAL, etc.
   --	 The main procedure rpt_order_status_main is called by a cronjob script
   --
   -- Modification History:
   --    Date     Designer Comments  
   --    -------- -------- --------------------------------------------------
   --    12/11/19 sban3548   Jira-OPCOF-2664: Initial Version
   --                     
   --------------------------------------------------------------------------

   -- Global Type Declarations
    
  ------------------------------------------------------------------------
  -- Procedure Declarations
  ------------------------------------------------------------------------

PROCEDURE rpt_order_status_main; 

PROCEDURE get_route_order_line( p_route_no IN    route.route_no%TYPE,
                                p_status IN    route.status%TYPE);

PROCEDURE update_short_order (i_route_batch	IN NUMBER,
							  i_route_no IN route.route_no%TYPE,
							  i_order_id IN ordm.order_id%TYPE,
							  i_order_line_id IN ordd.order_line_id%TYPE,
							  i_prod_id	 IN pm.prod_id%TYPE
							 );								 
PROCEDURE update_pick_adjustments (i_route_batch	IN NUMBER,
							  i_route_no IN route.route_no%TYPE,
							  i_sys_order_id IN ordd.sys_order_id%TYPE,
							  i_sys_order_line_id IN ordd.sys_order_line_id%TYPE,
							  i_prod_id	 IN pm.prod_id%TYPE,
							  i_deleted IN ordd.deleted%TYPE
							 );
PROCEDURE update_shipped_qty (i_route_batch	IN NUMBER,
							  i_route_no IN route.route_no%TYPE,
							  i_order_id IN ordm.order_id%TYPE,
							  i_order_line_id IN ordd.order_line_id%TYPE,
							  i_prod_id	 IN pm.prod_id%TYPE
							 );
END pl_rpt_order_status;
/

CREATE OR REPLACE
PACKAGE BODY swms.pl_rpt_order_status IS

---------------------------------------------------------------------------
-- Private Global Variables
---------------------------------------------------------------------------
gl_pkg_name   VARCHAR2(30) := $$PLSQL_UNIT;  -- Package name.
                                             -- Used in error messages.
/*
gl_e_parameter_null  EXCEPTION;  -- A required parameter to a procedure or
                                 -- function is null.
*/

--------------------------------------------------------------------------
-- Private Constants
--------------------------------------------------------------------------

ct_application_function VARCHAR2(30) := 'INTERFACE';


---------------------------------------------------------------------------
-- Public Modules
---------------------------------------------------------------------------

PROCEDURE rpt_order_status_main 
IS 
    CURSOR c_route 
    IS
	SELECT DISTINCT 
		  r.route_no,
		  r.status
	 FROM SWMS.route r
	WHERE status IN ('NEW','SHT','OPN','CLS')
	  AND (route_no, status) NOT IN (
		   SELECT route_no, route_status
			 FROM SWMS.RPT_ORDER_STATUS_OUT
		  );

	l_object_name        	    VARCHAR2(30) := 'rpt_order_status_main';
	l_enable_order_status       VARCHAR (1) := 'N';

BEGIN
    l_enable_order_status := pl_common.f_get_syspar ('ENABLE_RPT_ORDER_STATUS_OUT', 'N');
    pl_log.ins_msg (pl_lmc.ct_debug_msg, 
                         l_object_name,
                         'Syspar for RPT_ORDER_STATUS_OUT ['
                                    || l_enable_order_status ||'])',
                         NULL, 
                         NULL,
                         ct_application_function,
                         gl_pkg_name);

    IF l_enable_order_status = 'Y' THEN
		FOR r_route IN c_route 
		LOOP
			pl_rpt_order_status.get_route_order_line(r_route.route_no, r_route.status);
		end loop;
	ELSE
        pl_log.ins_msg (pl_lmc.ct_debug_msg, 
                         l_object_name,
                         'Route status syspar is Disabled',
                         NULL, 
                         NULL,
                         ct_application_function,
                         gl_pkg_name);
    END IF;
	
EXCEPTION
      WHEN NO_DATA_FOUND THEN
        NULL;

      WHEN OTHERS
      THEN
         -- Log the error message and raise application error 
            pl_log.ins_msg ('FATAL', 
                         l_object_name,
                          'Error occurred while fetching the routes.',
                       SQLCODE,
                       SQLERRM,
                         ct_application_function,
                         gl_pkg_name);
END rpt_order_status_main;
		
		
PROCEDURE get_route_order_line( p_route_no IN    route.route_no%TYPE,
                                p_status IN    route.status%TYPE) 
IS 
    CURSOR c_order_lines (i_route_no IN ordm.route_no%TYPE)
    IS
	SELECT 
        om.route_no,
        om.truck_no,
        om.ship_date,
        od.master_order_id,
        od.remote_local_flg,
        od.remote_qty,
        od.rdc_po_no,
        om.cust_id,
        om.order_type,
        om.cross_dock_type,
        om.order_id,
        om.status order_status,
        od.stop_no,
        od.order_line_id,
        od.sys_order_id,
        od.sys_order_line_id,
        od.status order_line_status,
		od.deleted,
        od.prod_id,
        od.cust_pref_vendor,
        pm.spc,
        od.cw_type,
        od.qty_ordered,
        od.qty_alloc,
        od.qty_shipped, 
        od.uom,
        od.wh_out_qty, 
        od.product_out_qty qty_sht,
        NVL(od.reason_cd,' ') reason_code
   FROM 
		ordm om,
        ordd od,
        pm
  WHERE 
		om.order_id = od.order_id
    AND od.prod_id = pm.prod_id
    AND od.cust_pref_vendor = pm.cust_pref_vendor
    AND om.route_no = i_route_no 
  ORDER BY om.order_id, od.order_line_id, od.prod_id;
    
    l_object_name        	    VARCHAR2 (30 CHAR) := 'get_route_order_line';
    l_rec_seq                   NUMBER(7);           
    l_batch_seq                 NUMBER(7);
	
BEGIN
        SELECT MX_BATCH_NO_SEQ.NEXTVAL
                  INTO l_batch_seq 
                  FROM DUAL;
       pl_log.ins_msg
        (pl_lmc.ct_info_msg, 
         l_object_name,
         'Starting procedure get_route_order_line for route_no['
                    || p_route_no || '], status['|| p_status ||'])',
         NULL, 
         NULL,
         ct_application_function,
         gl_pkg_name);

        FOR r_order IN c_order_lines (p_route_no) 
		LOOP    
				SELECT SWMS.RPT_ORDER_STATUS_SEQ.NEXTVAL
				  INTO l_rec_seq 
                  FROM DUAL;

				INSERT INTO rpt_order_status_out (sequence_number,
                                            batch_id,
                                            record_status,
                                            route_no,
                                            truck_no,
                                            route_status,
                                            ship_date,
                                            master_order_id,
                                            remote_local_flg,
                                            remote_qty,
                                            rdc_po_no,
                                            cust_id,
                                            order_type,
                                            cross_dock_type,
                                            stop_no,
                                            order_id,
                                            order_status,
                                            order_line_id,
                                            sys_order_id,
                                            sys_order_line_id,
                                            order_line_status,
                                            prod_id,
                                            cust_pref_vendor,
                                            spc,
                                            cw_type,
                                            qty_ordered,
                                            qty_alloc,
                                            qty_shipped,
                                            uom,
                                            qty_sht,
                                            qty_wh_out,
                                            qty_paw,
                                            qty_pad,
                                            reason_code,
                                            pallet_pull,
                                            cmt,
                                            add_user,
                                            add_date,
                                            upd_user,
                                            upd_date)
                                    VALUES (
                                            l_rec_seq,
                                            l_batch_seq,
                                            'N',
                                            r_order.route_no,
                                            r_order.truck_no,
                                            p_status,
                                            r_order.ship_date,
                                            r_order.master_order_id,
                                            r_order.remote_local_flg,
                                            r_order.remote_qty,
                                            r_order.rdc_po_no,
                                            r_order.cust_id,
                                            r_order.order_type,
                                            r_order.cross_dock_type,
                                            r_order.stop_no,
                                            r_order.order_id,
                                            r_order.order_status,
                                            r_order.order_line_id,
                                            r_order.sys_order_id,
                                            r_order.sys_order_line_id,
                                            r_order.order_line_status,
                                            r_order.prod_id,
                                            r_order.cust_pref_vendor,
                                            r_order.spc,
                                            r_order.cw_type,
                                            r_order.qty_ordered,
                                            r_order.qty_alloc,
                                            r_order.qty_shipped,
                                            r_order.uom,
                                            r_order.qty_sht,	--over written by trans record
                                            r_order.wh_out_qty,
                                            NULL,               -- r_order.QTY_PAW, --same as WH_OUT_QTY
                                            NULL,               -- r_order.QTY_PAD,
                                            r_order.reason_code,
                                            NULL,               -- r_order.PALLET_PULL,
                                            NULL,               -- r_order.CMT,
                                            USER,               --r_order.ADD_USER,
                                            SYSDATE,            -- r_order.ADD_DATE,
                                            NULL,               -- r_order.UPD_USER,
                                            NULL                -- r_order.UPD_DATE           
                                        );
			IF ((p_status ='SHT') OR (r_order.order_line_status = 'SHT')) THEN
				update_short_order(l_batch_seq,
								   r_order.ROUTE_NO,
								   r_order.ORDER_ID,
								   r_order.ORDER_LINE_ID, 
								   r_order.PROD_ID
								   );
			END IF;
			
			IF (p_status ='CLS') AND (r_order.REASON_CODE='PAD') AND (r_order.ORDER_LINE_STATUS != 'PAD') THEN
				update_pick_adjustments(l_batch_seq,
								   r_order.ROUTE_NO,
								   r_order.SYS_ORDER_ID,
								   r_order.SYS_ORDER_LINE_ID, 
								   r_order.PROD_ID,
								   r_order.DELETED
								   );
			END IF;	
			
			IF (p_status ='CLS') AND (r_order.REASON_CODE <>'PAD') THEN
				 pl_log.ins_msg (pl_lmc.ct_debug_msg, 
							 l_object_name,
							 'Calling update for shipped qty....',
							 NULL, 
							 NULL,
							 ct_application_function,
							 gl_pkg_name);

				update_shipped_qty(l_batch_seq,
								   r_order.ROUTE_NO,
								   r_order.ORDER_ID,
								   r_order.ORDER_LINE_ID, 
								   r_order.PROD_ID
								   );
			END IF;		
            
        END LOOP;
		COMMIT;
		pl_log.ins_msg (pl_lmc.ct_info_msg, 
                         l_object_name,
                         'Succesfully inserted Route status into staging for route_no['
                                    || p_route_no || '], status['|| p_status ||'])',
                         NULL, 
                         NULL,
                         ct_application_function,
                         gl_pkg_name);
    
EXCEPTION
      WHEN NO_DATA_FOUND THEN
        NULL;

      WHEN OTHERS
      THEN
         -- Log the error message and raise application error 
            pl_log.ins_msg ('FATAL', 
                         l_object_name,
                          'ERROR OCCURRED WHILE GETTING ORDER LINE DETAILS FOR ROUT_NO['
                       || p_route_no
                       || ']',
                       SQLCODE,
                       SQLERRM,
                         ct_application_function,
                         gl_pkg_name);

     /*raise_application_error (pl_exc.ct_data_error,
                                     gl_pkg_name
                                  || '.'
                                  || l_object_name
                                  || ': '
                                  || SQLERRM
                                 ); */

END get_route_order_line;

 
---------------------------------------------------------------------------
-- Procedure:
--    update_short_order
--
-- Description:
--    This procedure will update short qty for an order line item
--
-- Parameters:
--     
--      
--
---------------------------------------------------------------------------
PROCEDURE update_short_order (i_route_batch	IN NUMBER,
							  i_route_no IN route.route_no%TYPE,
							  i_order_id IN ordm.order_id%TYPE,
							  i_order_line_id IN ordd.order_line_id%TYPE,
							  i_prod_id	 IN pm.prod_id%TYPE
							 )
IS
    l_short_qty 	NUMBER 	:= 0;
	l_temp 	NUMBER 	:= 0;
	l_object_name   VARCHAR2 (30) := 'update_short_order';

BEGIN
	
	SELECT max(trans_id), NVL(qty_expected,0) - NVL(qty,0)  
	  INTO l_temp, l_short_qty   
	  FROM TRANS t
	 WHERE route_no = i_route_no
	   AND order_id = i_order_id
	   AND order_line_id = i_order_line_id
	   AND prod_id = i_prod_id
	   AND trans_type = 'SHT'
	   group by order_id, order_line_id, prod_id ,NVL(qty_expected,0) - NVL(qty,0);
	 
	IF l_short_qty > 0 THEN
		-- update short_qty for the order line item 
			  UPDATE SWMS.RPT_ORDER_STATUS_OUT  
				 SET QTY_SHT = l_short_qty
			   WHERE route_no = i_route_no
				 AND order_id = i_order_id
				 AND order_line_id = i_order_line_id
				 AND prod_id = i_prod_id
				 AND batch_id = i_route_batch;			  				 
	END IF;

EXCEPTION
      WHEN OTHERS
      THEN
         -- Log the error message and raise application error 
         pl_log.ins_msg ('FATAL', 
                         l_object_name,
                          'ERROR OCCURRED WHILE UPDATING QTY_SHT FOR ROUTE_NO['
                       || i_route_no
                       || '], order_id[' 
					   || i_order_id
					   ||'], order_line['
					   ||i_order_line_id
					   ||'], prod_id['
					   ||i_prod_id
					   ||']',
                       SQLCODE,
                       SQLERRM,
                         ct_application_function,
                         gl_pkg_name);
		 
         /*raise_application_error (pl_exc.ct_data_error,
                                     gl_pkg_name
                                  || '.'
                                  || l_object_name
                                  || ': '
                                  || SQLERRM
                                 ); */
END update_short_order;

 
---------------------------------------------------------------------------
-- Procedure:
--    update_pick_adjustments
--
-- Description:
--    This procedure will update pick adjustments like PAL, PAD, etc. for an order/line item
--
-- Parameters:
--     
--      
--
---------------------------------------------------------------------------
PROCEDURE update_pick_adjustments (i_route_batch	IN NUMBER,
							  i_route_no IN route.route_no%TYPE,
							  i_sys_order_id IN ordd.sys_order_id%TYPE,
							  i_sys_order_line_id IN ordd.sys_order_line_id%TYPE,
							  i_prod_id	 IN pm.prod_id%TYPE,
							  i_deleted IN ordd.deleted%TYPE
							 )
IS
    l_pad_qty NUMBER 	:= 0;
	l_object_name   VARCHAR2 (30) := 'update_pick_adjustments';

BEGIN
	
	IF i_deleted='PAL' THEN	
		SELECT NVL(qty,0)  
		  INTO l_pad_qty   
		  FROM TRANS t
		 WHERE route_no = i_route_no
		   AND sys_order_id = i_sys_order_id
		   AND sys_order_line_id = i_sys_order_line_id
		   AND prod_id = i_prod_id
		   AND trans_type in ('PAL');

		  -- update PAL qty, status for the order line item 
		  UPDATE SWMS.RPT_ORDER_STATUS_OUT  
			 SET qty_pad = l_pad_qty,
				 qty_shipped = 0,
				 order_line_status = i_deleted 
		   WHERE route_no = i_route_no
			 AND sys_order_id = i_sys_order_id
			 AND sys_order_line_id = i_sys_order_line_id
			 AND prod_id = i_prod_id
			 AND batch_id = i_route_batch;	

	ELSE
		  -- update PAD qty, status for the entire order 
		  UPDATE SWMS.RPT_ORDER_STATUS_OUT s 
			 SET qty_pad = qty_ordered, 
				 qty_shipped = 0,
				 order_line_status = i_deleted 
		   WHERE route_no = i_route_no
			 AND sys_order_id = i_sys_order_id
			 AND batch_id = i_route_batch 			  				 
			 AND EXISTS (
							SELECT 1 
							FROM trans 
							WHERE trans_type='PAD'
							 AND route_no = s.route_no
							 AND sys_order_id = s.sys_order_id
						);
	END IF;
	
   EXCEPTION
      WHEN OTHERS
      THEN
         -- Log the error message and raise application error 
            pl_log.ins_msg ('FATAL', 
                         l_object_name,
                          'ERROR OCCURRED WHILE UPDATING PAD/PAL QTY FOR ROUTE_NO['
                       || i_route_no
                       || '], sys_order_id[' 
					   || i_sys_order_id
					   ||'], sys_order_line['
					   ||i_sys_order_line_id
					   ||'], prod_id['
					   ||i_prod_id
					   ||']',
                       SQLCODE,
                       SQLERRM,
                       ct_application_function,
                       gl_pkg_name);

     /*raise_application_error (pl_exc.ct_data_error,
                                     gl_pkg_name
                                  || '.'
                                  || l_object_name
                                  || ': '
                                  || SQLERRM
                                 ); */
END update_pick_adjustments;

---------------------------------------------------------------------------
-- Procedure:
--    update_shipped_qty
--
-- Description:
--    This procedure will update shipped qty for an order line item
--
-- Parameters:
--     
--      
--
---------------------------------------------------------------------------
PROCEDURE update_shipped_qty (i_route_batch	IN NUMBER,
							  i_route_no IN route.route_no%TYPE,
							  i_order_id IN ordm.order_id%TYPE,
							  i_order_line_id IN ordd.order_line_id%TYPE,
							  i_prod_id	 IN pm.prod_id%TYPE
							 )
IS
    l_shipped_qty NUMBER 	:= 0;
	l_object_name   VARCHAR2 (30) := 'update_shipped_qty';

BEGIN
	  -- update shipped qty for the route 
	  UPDATE SWMS.RPT_ORDER_STATUS_OUT  
		 SET qty_shipped = nvl(qty_alloc, 0) - nvl(qty_wh_out, 0) 
	   WHERE route_no = i_route_no
		 AND order_id = i_order_id
		 AND order_line_id = i_order_line_id
		 AND prod_id = i_prod_id
		 AND batch_id = i_route_batch
		 AND qty_alloc > 0;

   EXCEPTION
      WHEN OTHERS
      THEN
        -- Log the error message and raise application error 
        pl_log.ins_msg ('FATAL', 
                         l_object_name,
                          'ERROR OCCURRED WHILE UPDATING QTY_SHIPPED FOR ROUTE_NO['
                       || i_route_no
                       || '], order_id[' 
					   || i_order_id
					   ||'], order_line['
					   ||i_order_line_id
					   ||'], prod_id['
					   ||i_prod_id
					   ||']',
                       SQLCODE,
                       SQLERRM,
                       ct_application_function,
                       gl_pkg_name);

        /* raise_application_error (pl_exc.ct_data_error,
                                     gl_pkg_name
                                  || '.'
                                  || l_object_name
                                  || ': '
                                  || SQLERRM
                                 ); */
END update_shipped_qty;

END pl_rpt_order_status;
/

CREATE OR REPLACE PUBLIC SYNONYM pl_rpt_order_status FOR swms.pl_rpt_order_status;
GRANT EXECUTE ON swms.pl_rpt_order_status TO SWMS_USER;
SHOW ERRORS;


