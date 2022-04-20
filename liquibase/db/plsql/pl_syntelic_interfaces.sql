CREATE or REPLACE PACKAGE swms.pl_syntelic_interfaces
IS
   -- sccs_id=@(#) src/schema/plsql/pl_syntelic_interfaces.sql, 
   -----------------------------------------------------------------------------
   -- Package Name:
   --   pl_syntelic_interfaces
   --
   -- Description:
   --    Processing of Stored procedures and table functions for Syntelic interfaces
   --    using staging tables.
   --
   -- Modification History:
   --    Date     Designer Comments
   --    -------- -------- -----------------------------------------------------
   --    04/23/10 rkum0357 Created.
   --    06/29/12 bgul2852 Removed stored procedure as part of CRQ37911,
   --                      Direct insert into staging tables from PI.
   --    09/22/16 sraj8407 Added a round function in snd_syntelic_material_master to modify the case_cube value to 3 decimal digits.
   -----------------------------------------------------------------------------
 
   -- Table function for SCI056-A
   
    FUNCTION swms_syntelic_material_func RETURN syntelic_material_object_table;
    
   -- Table function for SCI043-A 
   
    FUNCTION swms_syntelic_route_func  RETURN SYNTELIC_ROUTE_OBJECT_TABLE;
    
    FUNCTION swms_syntelic_order_func RETURN SYNTELIC_ORDER_OBJECT_TABLE ;
    
    -- Procudure for SCI056-A
    PROCEDURE snd_syntelic_material_master;
    
    -- Procudure for SCI043-A
    
    PROCEDURE snd_syntelic_route_order;
    
    -- Procedure for SCI044-A
    PROCEDURE rcv_syntelic_loadmap;

END pl_syntelic_interfaces;
/
--*************************************************************************
--Package Body

--*************************************************************************

CREATE OR REPLACE PACKAGE BODY swms.pl_syntelic_interfaces
AS

-- Table Function for SCI056-A
-------------------------------------------------------------------------------
-- FUNCTION 
--    swms_syntelic_material_func
--
-- Description:
--     This function retrieves the data from Oracle staging table SYNTELIC_MATERIAL_OUT  
--     and sends the material data to SAP through PI middleware.
--
-- Parameters:
--    None          
--
-- Return Values:
--    syntelic_material_object_table
--     
-- Exceptions Raised:
--   The when OTHERS propagates the exception.
--
-- Called by:
--    SAP-PI
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    04/23/10 rkum0357 Created. 
--    10/12/10 sray0453 Added batch_id handling logic CR#4054.
----------------------------------------------------------------------------
    Function swms_syntelic_material_func
    return syntelic_material_object_table
    IS
      PRAGMA AUTONOMOUS_TRANSACTION; 
      l_syntelic_material_obj_table syntelic_material_object_table := syntelic_material_object_table();
      message varchar2(70);  
      lv_batch_id Number;
      batch_id_resend number;
      lv_loop Number;
      
    BEGIN  
        
        UPDATE SYNTELIC_MATERIAL_OUT SET record_status = 'N' WHERE record_status = 'Q';
        COMMIT;
        
        SELECT MIN(batch_id) INTO batch_id_resend from SYNTELIC_MATERIAL_OUT where record_status = 'N' and batch_id is not null;
        
        IF batch_id_resend IS NOT NULL THEN

            lv_batch_id := batch_id_resend;
            
            FOR i_index in (SELECT sequence_number,prod_id, descrip, area, case_cube, g_weight, 
            spc, catch_wt_trk, ti, hi, zone_id, split_trk, uom, mfg_sku, 
            prod_size, prod_size_unit, pack, logi_loc
            FROM SYNTELIC_MATERIAL_OUT 
            WHERE record_status='N' and batch_id = batch_id_resend  
            ORDER BY sequence_number)

            LOOP 
                

            message := 'SYNTELIC_MATERIAL:PROD#'|| i_index.prod_id ||'SEQ#' || i_index.sequence_number;
            
                l_syntelic_material_obj_table.extend; 	
                l_syntelic_material_obj_table(l_syntelic_material_obj_table.count) := SYNTELIC_MATERIAL_OBJECT(
                    lv_batch_id,i_index.prod_id, i_index.descrip, i_index.area,
        			i_index.case_cube, i_index.g_weight, i_index.spc,
        	 		i_index.catch_wt_trk, i_index.ti, i_index.hi, i_index.zone_id,
        			i_index.split_trk, i_index.uom, i_index.mfg_sku, i_index.prod_size, 
        			i_index.prod_size_unit, i_index.pack, i_index.logi_loc); 
                
            update  SYNTELIC_MATERIAL_OUT set record_status ='Q' where batch_id = lv_batch_id and sequence_number = i_index.sequence_number;                  
            COMMIT;         
            END LOOP;

        ELSE 
        
        lv_loop := 0;    
        
        FOR i_index in (SELECT sequence_number,prod_id, descrip, area, case_cube, g_weight, 
            spc, catch_wt_trk, ti, hi, zone_id, split_trk, uom, mfg_sku, 
            prod_size, prod_size_unit, pack, logi_loc
            FROM SYNTELIC_MATERIAL_OUT 
            WHERE record_status='N' 
            ORDER BY sequence_number)

            LOOP 
                
                IF lv_loop = 0 THEN
            
                    select max(batch_id) into lv_batch_id from SYNTELIC_MATERIAL_OUT;
                    IF lv_batch_id is NULL THEN
                        lv_batch_id := 1;
                    ELSE
                        lv_batch_id := lv_batch_id + 1;
                    END IF;

                  lv_loop := 1;
                END IF;
                message := 'SYNTELIC_MATERIAL:PROD#'|| i_index.prod_id ||'SEQ#' || i_index.sequence_number;

                l_syntelic_material_obj_table.extend; 	
                l_syntelic_material_obj_table(l_syntelic_material_obj_table.count) := SYNTELIC_MATERIAL_OBJECT(
                    lv_batch_id,i_index.prod_id, i_index.descrip, i_index.area,
        			i_index.case_cube, i_index.g_weight, i_index.spc,
        			i_index.catch_wt_trk, i_index.ti, i_index.hi, i_index.zone_id,
        			i_index.split_trk, i_index.uom, i_index.mfg_sku, i_index.prod_size, 
        			i_index.prod_size_unit, i_index.pack, i_index.logi_loc); 
                
                update  SYNTELIC_MATERIAL_OUT set batch_id = lv_batch_id,record_status ='Q' where sequence_number = i_index.sequence_number;  
                COMMIT;         
            END LOOP;
        END IF;    
	    RETURN l_syntelic_material_obj_table;

    EXCEPTION
        WHEN OTHERS THEN
    	pl_log.ins_msg('FATAL','SWMS_SYNTELIC_MATERIAL_FUNC', message, SQLCODE, SQLERRM, 'SYNTELIC','PL_SYNTELIC_INTERFACES','Y');
    END swms_syntelic_material_func;


-- Table Function for SCI043-A
-------------------------------------------------------------------------------
-- FUNCTION 
--    swms_syntelic_route_func
--
-- Description:
--     This function retrieves the data from Oracle staging table SYNTELIC_ROUTE_ORDER_OUT   
--     and sends the route information.
--
-- Parameters:
--    None          
--
-- Return Values:
--    SYNTELIC_ROUTE_OBJECT_TABLE 
--     
-- Exceptions Raised:
--   The when OTHERS propagates the exception.
--
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    04/26/10 kraj0356 Created. 
----------------------------------------------------------------------------
FUNCTION  swms_syntelic_route_func  RETURN SYNTELIC_ROUTE_OBJECT_TABLE 
IS
	PRAGMA AUTONOMOUS_TRANSACTION;
    l_SYNTELIC_ROUTE_OBJECT_TABLE SYNTELIC_ROUTE_OBJECT_TABLE := SYNTELIC_ROUTE_OBJECT_TABLE();
    message varchar2(70);  
    lv_batch_id Number;
    batch_id_resend number;
    lv_loop Number;
    
BEGIN
        UPDATE SYNTELIC_ROUTE_ORDER_OUT SET record_status = 'N' WHERE record_status = 'Q'
        AND route_order_flag = 'R';
        COMMIT;
        
        SELECT MIN(batch_id) INTO batch_id_resend FROM SYNTELIC_ROUTE_ORDER_OUT WHERE record_status = 'N' AND batch_id IS NOT NULL
        AND route_order_flag = 'R';
        
        IF batch_id_resend IS NOT NULL THEN

            lv_batch_id := batch_id_resend;
          FOR i_index IN (SELECT SEQUENCE_NUMBER,ROUTE_NO,ROUTE_DATE,TRUCK_NO,F_DOOR,
                        C_DOOR,D_DOOR from  SYNTELIC_ROUTE_ORDER_OUT 
                        WHERE record_status='N' AND batch_id = batch_id_resend
                        AND route_order_flag = 'R' ORDER BY sequence_number)
		
    	 LOOP 
            
            message := 'SYNTELIC_ROUTE_ORDER:ROUTE#'||i_index.ROUTE_NO ||':TRUCK#:'||i_index.TRUCK_NO;	 
       		l_SYNTELIC_ROUTE_OBJECT_TABLE.extend; 	
            l_SYNTELIC_ROUTE_OBJECT_TABLE(l_SYNTELIC_ROUTE_OBJECT_TABLE.COUNT) := SYNTELIC_ROUTE_OBJECT(
            lv_batch_id,i_index.ROUTE_NO, i_index.ROUTE_DATE, i_index.TRUCK_NO, i_index.F_DOOR,
            i_index.C_DOOR, i_index.D_DOOR); 
     		
            UPDATE  SYNTELIC_ROUTE_ORDER_OUT SET record_status ='Q' WHERE batch_id = lv_batch_id AND sequence_number = i_index.sequence_number;  
        
            COMMIT;
    	 END LOOP;  
        ELSE    
         
         lv_loop := 0;
        
    	 FOR i_index IN (SELECT SEQUENCE_NUMBER,ROUTE_NO,ROUTE_DATE,TRUCK_NO,F_DOOR,
                        C_DOOR,D_DOOR FROM  SYNTELIC_ROUTE_ORDER_OUT 
                        WHERE record_status='N' AND
                        route_order_flag = 'R' ORDER BY sequence_number)
		
    	 LOOP 
            IF lv_loop = 0 THEN 
            
                  SELECT MAX(batch_id) INTO lv_batch_id FROM SYNTELIC_ROUTE_ORDER_OUT;
                  IF lv_batch_id IS NULL THEN
                        lv_batch_id := 1;
                  ELSE
                        lv_batch_id := lv_batch_id + 1;
                  END IF;

                  lv_loop := 1;
            END IF;
            
            message := 'SYNTELIC_ROUTE_ORDER:ROUTE#'||i_index.ROUTE_NO ||':TRUCK#:'||i_index.TRUCK_NO;	 
       		l_SYNTELIC_ROUTE_OBJECT_TABLE.extend; 	
            l_SYNTELIC_ROUTE_OBJECT_TABLE(l_SYNTELIC_ROUTE_OBJECT_TABLE.COUNT) := SYNTELIC_ROUTE_OBJECT(
            lv_batch_id,i_index.ROUTE_NO, i_index.ROUTE_DATE, i_index.TRUCK_NO, i_index.F_DOOR,
            i_index.C_DOOR, i_index.D_DOOR); 
     		
            UPDATE  SYNTELIC_ROUTE_ORDER_OUT SET record_status='Q', batch_id = lv_batch_id WHERE sequence_number = i_index.sequence_number;  
        
            COMMIT;
    	 END LOOP;
         END IF;
         	
RETURN l_SYNTELIC_ROUTE_OBJECT_TABLE;

EXCEPTION
     	WHEN OTHERS THEN
        pl_log.ins_msg('FATAL', 'SWMS_SYNTELIC_ROUTE_FUNC',message, 
        SQLCODE, SQLERRM, 'SYNTELIC', 'PL_SYNTELIC_INTERFACES','Y');
END swms_syntelic_route_func;

-------------------------------------------------------------------------------
-- FUNCTION 
--    swms_syntelic_order_func
--
-- Description:
--     This function retrieves the data from Oracle staging table SYNTELIC_ROUTE_ORDER_OUT   
--     and sends the order information.
--
-- Parameters:
--    None          
--
-- Return Values:
--    SYNTELIC_ORDER_OBJECT_TABLE 
--     
-- Exceptions Raised:
--   when OTHERS propagates the exception.
--
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    04/26/10 kraj0356 Created. 
----------------------------------------------------------------------------
FUNCTION swms_syntelic_order_func  RETURN SYNTELIC_ORDER_OBJECT_TABLE 
AS 
	PRAGMA AUTONOMOUS_TRANSACTION;
    l_SYNTELIC_ORDER_OBJECT_TABLE SYNTELIC_ORDER_OBJECT_TABLE := SYNTELIC_ORDER_OBJECT_TABLE();
    message VARCHAR2(70); 
    lv_batch_id NUMBER;
    batch_id_resend NUMBER;
    lv_loop NUMBER;
    
BEGIN
        UPDATE SYNTELIC_ROUTE_ORDER_OUT SET record_status = 'N' WHERE record_status = 'Q'
        AND ROUTE_ORDER_FLAG = 'O';
        COMMIT;
        
        SELECT MIN(batch_id) INTO batch_id_resend FROM SYNTELIC_ROUTE_ORDER_OUT 
        WHERE record_status = 'N' AND route_order_flag = 'O' AND batch_id IS NOT NULL;
        
        IF batch_id_resend IS NOT NULL THEN

             lv_batch_id := batch_id_resend;
             FOR i_index IN (SELECT SEQUENCE_NUMBER,ROUTE_NO,ROUTE_DATE,CUST_ID,
    				STOP_NO,ORDER_ID,ORDER_LINE_ID,PROD_ID,
    				FLOAT_SEQ,UOM,QTY_ORDER,SPC,UNITIZE_IND,
    				SEL_TYPE,ZONE_ID,AREA,SRC_LOC,SEQ_NO,
    				IMMEDIATE_IND,SELECTION_BATCH_NO,
    				LOADER_BATCH_NO,METHOD_ID
                    FROM SYNTELIC_ROUTE_ORDER_OUT
                    WHERE record_status='N' AND batch_id = batch_id_resend 
                    AND route_order_flag = 'O' ORDER BY sequence_number)
                    
             LOOP 
                
                message := 'SYNTELIC_ROUTE_ORDER:ROUTE#'||i_index.ROUTE_NO ||':STOP#:'||i_index.STOP_NO;	 
           		l_SYNTELIC_ORDER_OBJECT_TABLE.extend; 	
                l_SYNTELIC_ORDER_OBJECT_TABLE(l_SYNTELIC_ORDER_OBJECT_TABLE.count) := SYNTELIC_ORDER_OBJECT(
                            lv_batch_id,i_index.ROUTE_NO, i_index.ROUTE_DATE, i_index.CUST_ID, i_index.STOP_NO,
                            i_index.ORDER_ID, i_index.ORDER_LINE_ID,
                            i_index.PROD_ID, i_index.FLOAT_SEQ, i_index.UOM, i_index.QTY_ORDER, i_index.SPC,
                            i_index.UNITIZE_IND, i_index.SEL_TYPE, i_index.ZONE_ID, i_index.AREA, i_index.SRC_LOC,
                            i_index.SEQ_NO, i_index.IMMEDIATE_IND,i_index.SELECTION_BATCH_NO,
    				        i_index.LOADER_BATCH_NO, i_index.METHOD_ID
                            ); 
         		
                UPDATE  SYNTELIC_ROUTE_ORDER_OUT SET  record_status ='Q' 
                        WHERE batch_id = lv_batch_id AND sequence_number = i_index.sequence_number;  
                COMMIT;
        	  END LOOP; 
        
        ELSE    
             lv_loop := 0;
        	 FOR i_index IN (SELECT SEQUENCE_NUMBER,ROUTE_NO,ROUTE_DATE,CUST_ID,
    				STOP_NO,ORDER_ID,ORDER_LINE_ID,PROD_ID,
    				FLOAT_SEQ,UOM,QTY_ORDER,SPC,UNITIZE_IND,
    				SEL_TYPE,ZONE_ID,AREA,SRC_LOC,SEQ_NO,
    				IMMEDIATE_IND,SELECTION_BATCH_NO,
    				LOADER_BATCH_NO,METHOD_ID
                    FROM SYNTELIC_ROUTE_ORDER_OUT
                    WHERE record_status='N' AND 
                    route_order_flag = 'O' ORDER BY sequence_number)
                    
            LOOP          
                IF lv_loop = 0 THEN
                        
                      SELECT MAX(batch_id) INTO lv_batch_id FROM SYNTELIC_ROUTE_ORDER_OUT;
                      IF lv_batch_id IS NULL THEN
                            lv_batch_id := 1;
                      ELSE
                            lv_batch_id := lv_batch_id + 1;
                      END IF;
                      lv_loop := 1;
                END IF;
                
                message := 'SYNTELIC_ROUTE_ORDER:ROUTE#'||i_index.ROUTE_NO ||':STOP#:'||i_index.STOP_NO;	 
           		l_SYNTELIC_ORDER_OBJECT_TABLE.extend; 	
                l_SYNTELIC_ORDER_OBJECT_TABLE(l_SYNTELIC_ORDER_OBJECT_TABLE.COUNT) := SYNTELIC_ORDER_OBJECT(
                            lv_batch_id,i_index.ROUTE_NO, i_index.ROUTE_DATE, i_index.CUST_ID, i_index.STOP_NO,
                            i_index.ORDER_ID, i_index.ORDER_LINE_ID,
                            i_index.PROD_ID, i_index.FLOAT_SEQ, i_index.UOM, i_index.QTY_ORDER, i_index.SPC,
                            i_index.UNITIZE_IND, i_index.SEL_TYPE, i_index.ZONE_ID, i_index.AREA, i_index.SRC_LOC,
                            i_index.SEQ_NO, i_index.IMMEDIATE_IND,i_index.SELECTION_BATCH_NO,
    				        i_index.LOADER_BATCH_NO, i_index.METHOD_ID
                            ); 
         		
               UPDATE  SYNTELIC_ROUTE_ORDER_OUT SET  record_status ='Q', 
                       batch_id = lv_batch_id  WHERE sequence_number = i_index.sequence_number;
                COMMIT;
        	 END LOOP;
           END IF;
         	
RETURN l_SYNTELIC_ORDER_OBJECT_TABLE;

EXCEPTION
     	WHEN OTHERS THEN
            pl_log.ins_msg('FATAL','SWMS_SYNTELIC_ORDER_FUNC',message,
                           SQLCODE, SQLERRM, 'SYNTELIC', 'PL_SYNTELIC_INTERFACES','Y');
END swms_syntelic_order_func;



---------------------------------------------------------------------------
-- Private Modules
---------------------------------------------------------------------------
---------------------------------------------------------------------------
-- PROCEDURE
--    snd_syntelic_material_master
--
-- Description:
--  The procedure reads the material master data from the SWMS application table
--  and inserts in to the staging table SYNTELIC_MATERIAL_OUT.  
--
-- Parameters:
--  None.
--
-- Exceptions Raised:
--      duplicate_record_exception
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- --------------------------------------------------- 
--    04/23/10 rkum0357 Created.
-----------------------------------------------------------------------------                                   

    PROCEDURE snd_syntelic_material_master
    IS
        message VARCHAR2(70);
        l_area_code varchar2(1);

    	CURSOR get_material_batch IS 
        SELECT distinct pm.PROD_ID, pm.DESCRIP, pm.AREA, pm.CASE_CUBE,
        NVL(pm.G_WEIGHT,0) g_weight, pm.SPC, pm.CATCH_WT_TRK, pm.TI,
        pm.HI,lz.ZONE_ID, pm.SPLIT_TRK, inv.INV_UOM, pm.MFG_SKU, pm.PROD_SIZE,
         pm.Pack ,loc.logi_loc
        FROM SWMS.PM pm,SWMS.INV inv,  SWMS.LOC loc , SWMS.LZONE lz, SWMS.ZONE z
        WHERE pm.PROD_ID = inv.PROD_ID
        AND pm.PROD_ID =loc.PROD_ID
        AND inv.PLOGI_LOC = lz.LOGI_LOC
        AND inv.PLOGI_LOC = loc.LOGI_LOC
        AND loc.RANK =1
        AND loc.UOM in (0,2)
        AND lz.ZONE_ID = z.ZONE_ID
        AND z.ZONE_TYPE = 'PUT'
        AND  loc.PERM ='Y'
        UNION
        SELECT pm.PROD_ID, pm.DESCRIP, pm.AREA, pm.CASE_CUBE,
                NVL(pm.G_WEIGHT,0) g_weight, pm.SPC, pm.CATCH_WT_TRK, pm.TI,
                pm.HI,lz.ZONE_ID, pm.SPLIT_TRK, min(inv.inv_UOM), pm.MFG_SKU, pm.PROD_SIZE,
                 pm.Pack ,MAX(inv.plogi_loc)
        FROM SWMS.PM pm,SWMS.INV inv,  SWMS.LZONE lz, SWMS.ZONE z
        WHERE pm.PROD_ID = inv.PROD_ID
        AND inv.PLOGI_LOC = lz.LOGI_LOC
        AND lz.ZONE_ID = z.ZONE_ID
        AND z.ZONE_TYPE='PUT'
        And not exists (select 1 from loc where loc.prod_id=pm.prod_id)
        GROUP BY pm.PROD_ID, pm.DESCRIP, pm.AREA, pm.CASE_CUBE,
                pm.G_WEIGHT, pm.SPC, pm.CATCH_WT_TRK, pm.TI,
                pm.HI,lz.ZONE_ID, pm.SPLIT_TRK, pm.MFG_SKU, pm.PROD_SIZE,
                pm.pack;
                
        CURSOR get_area_cd(c_location IN LOC.LOGI_LOC%TYPE) IS
        select area_code
        from swms_sub_areas s, aisle_info i
        where i.name = substr(c_location,1,2)
        and   i.sub_area_code = s.sub_area_code;
   BEGIN
	FOR g IN get_material_batch
        loop
            
            l_area_code := g.area;
            
            message := 'Error in snd_syntelic_material_master procedure. g.prod_id: ' || g.prod_id;
            IF g.area NOT in ('F','C','D') then
                OPEN get_area_cd(g.logi_loc);
                FETCH get_area_cd INTO l_area_code;
                
                IF get_area_cd%NOTFOUND THEN
                    l_area_code := g.area;
                END IF;
                
                CLOSE get_area_cd;
            END IF;    
            --insert into staging table
			-- CRQ000000007732 - Added a Round function to modify the case_cube value to 3 decimal digits in-order to fix the communication channel error.
            INSERT INTO SYNTELIC_MATERIAL_OUT (sequence_number, interface_type, record_status, datetime,
                prod_id, descrip, area, case_cube, 
        		g_weight, spc, catch_wt_trk, ti, 
        		hi, zone_id, split_trk, uom, mfg_sku, prod_size, 
        		pack, logi_loc,
                add_user, add_date, upd_user, upd_date) 
            VALUES (
                SYNTELIC_MATERIAL_SEQ.NEXTVAL, 'SIM', 'N', SYSDATE, 
                g.prod_id, g.descrip, l_area_code, round(g.case_cube,3),
                g.g_weight, g.spc, g.catch_wt_trk, g.ti, 
                g.hi, g.zone_id, g.split_trk, g.inv_uom, g.mfg_sku, g.prod_size,
                g.pack, g.logi_loc,
                REPLACE(USER,'OPS$',NULL),SYSDATE,REPLACE(USER,'OPS$',NULL),SYSDATE);

                COMMIT;
	end loop;

        EXCEPTION
            WHEN OTHERS THEN
            pl_log.ins_msg ('FATAL', 'snd_syntelic_material_master', message, SQLCODE, SQLERRM, 'SYNTELIC', 'PL_SYNTELIC_INTERFACES', 'Y');

    END snd_syntelic_material_master;
---------------------------------------------------------------------------
-- PROCEDURE
--    snd_syntelic_route_order 
--
-- Description:
-- The procedure reads the route and order data from the SWMS application table
--  and inserts in to the staging table SYNTELIC_ROUTE_ORDER_OUT  
--
-- Parameters:
--  None.
--
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- --------------------------------------------------- 
--    04/26/10 kraj0356 Created.
-----------------------------------------------------------------------------  
PROCEDURE  snd_syntelic_route_order IS
		lv_route_no        varchar2(10);
		lv_route_date      date;
		lv_truck_no        varchar2(10);
		lv_f_door		   varchar2(3);
		lv_c_door		   varchar2(3);
		lv_d_door		   varchar2(3);
		lv_cust_id		   varchar2(10);
		lv_stop_no		   varchar2(7);
		lv_order_id		   varchar2(14);
		lv_order_line_id   varchar2(3);
		lv_prod_id		   varchar2(9);
		lv_float_seq       varchar2(4);
		lv_uom			   varchar2(2);
		lv_qty_order       varchar2(9);
		lv_spc			   varchar2(4);
		lv_unitize_ind	   varchar2(1);
		lv_sel_type		   varchar2(3);
		lv_zone_id		   varchar2(5);
		lv_area			   varchar2(2);
		lv_src_loc		   varchar2(10);
		lv_seq_no		   varchar2(3);
		lv_immediate_ind    varchar2(1);
		lv_selection_batch_no  varchar2(9);
		lv_loader_batch_no  varchar2(9);
		lv_method_id       varchar2(10);
        lv_route_status    varchar2(3);
		message            VARCHAR2(70);
        lv_qty_order_double  number(9);
        
		record_count NUMBER;
        CURSOR get_selection_batch IS
	SELECT ordm.ROUTE_NO, ordm.SHIP_DATE,ordm.truck_no,
	     rte.F_DOOR, rte.C_DOOR, rte.D_DOOR,ordm.CUST_ID,
	     ordm.STOP_NO, ordm.ORDER_ID, fd.ORDER_LINE_ID,
	     fd.PROD_ID,fs.FLOAT_SEQ, fd.UOM, sum(fd.QTY_ORDER), 
	     pm.SPC,ordm.UNITIZE_IND, sm.SEL_TYPE, fs.ZONE_ID, 
	     pm.AREA, fd.SRC_LOC,min(fd.SEQ_NO),ordm.IMMEDIATE_IND,
	     fs.batch_no , fs.float_no,rte.METHOD_ID,rte.STATUS
	     
	FROM SWMS.ORDM ordm, SWMS.ROUTE rte,
	    SWMS.FLOATS fs, SWMS.FLOAT_DETAIL fd, SWMS.PM pm,
	    SWMS.SEL_METHOD sm,SWMS.ZONE z
	    
	WHERE NOT EXISTS
        (SELECT * FROM SYNTELIC_ROUTE_ORDER_OUT sr
        WHERE sr.ROUTE_NO = ordm.ROUTE_NO
        AND sr.route_status = rte.STATUS)
	AND ordm.ROUTE_NO = fd.ROUTE_NO
	AND ordm.ORDER_ID = fd.ORDER_ID
	AND fd.FLOAT_NO = fs.FLOAT_NO
	AND fd.PROD_ID = pm.PROD_ID
    AND fs.pallet_pull <> 'R'   
	AND fs.ROUTE_NO = rte.ROUTE_NO
	AND fs.GROUP_NO = sm.GROUP_NO
	AND rte.METHOD_ID = sm.METHOD_ID
	AND fs.ZONE_ID = z.ZONE_ID
	AND rte.STATUS In ('OPN','SHT')
	
	GROUP BY ordm.ROUTE_NO, ordm.truck_no,ordm.SHIP_DATE, ordm.CUST_ID,
	     rte.METHOD_ID,ordm.STOP_NO, ordm.ORDER_ID, fd.ORDER_LINE_ID,
	     fd.PROD_ID,fs.FLOAT_SEQ, fd.UOM, pm.SPC, ordm.UNITIZE_IND, 
	     sm.SEL_TYPE, fs.ZONE_ID, pm.AREA, fd.SRC_LOC,rte.F_DOOR, 
	     rte.C_DOOR, rte.D_DOOR ,ordm.IMMEDIATE_IND,fs.batch_no, 
	     fs.float_no,rte.METHOD_ID,rte.STATUS
	     
	ORDER BY ordm.Route_NO, ordm.Stop_No;
	
	BEGIN		
		OPEN get_selection_batch;
		LOOP	
                    FETCH get_selection_batch into 
					lv_route_no,
					lv_route_date,
					lv_truck_no,
					lv_f_door,
					lv_c_door,
					lv_d_door,
					lv_cust_id,
					lv_stop_no,
					lv_order_id,
					lv_order_line_id,
					lv_prod_id,
					lv_float_seq,
					lv_uom,
					lv_qty_order,
					lv_spc,
					lv_unitize_ind,
					lv_sel_type,
					lv_zone_id,
					lv_area,
					lv_src_loc,
					lv_seq_no,
					lv_immediate_ind,
					lv_selection_batch_no,
					lv_loader_batch_no,
					lv_method_id,
                    lv_route_status;
		exit when  get_selection_batch%NOTFOUND; 	
        
        SELECT COUNT(*) INTO record_count FROM SYNTELIC_ROUTE_ORDER_OUT WHERE route_no = lv_route_no AND
        route_order_flag = 'R' AND to_char(ADD_DATE,'MMDDYY') = to_char(SYSDATE,'MMDDYY') AND route_status = lv_route_status;         
        
        IF record_count = 0 THEN
               
            message := 'ERROR IN INSERTING ROUTE DATA:ROUTE#'||lv_route_no||':TRUCK#:'||lv_truck_no;	 
    		--insert for only route data
            INSERT INTO SYNTELIC_ROUTE_ORDER_OUT (sequence_number, interface_type, record_status,datetime,
            route_order_flag, route_no, route_date, 
            truck_no, f_door, c_door, d_door,route_status,add_user, add_date, upd_user, upd_date)
            values(syntelic_route_order_seq.nextVal, ' ','N',SYSDATE,'R', lv_route_no, lv_route_date, lv_truck_no, lv_f_door, lv_c_door, 
            lv_d_door,lv_route_status,REPLACE(USER,'OPS$',NULL),SYSDATE,REPLACE(USER,'OPS$',NULL),SYSDATE);
            
        END IF;
         
            message := 'ERROR IN INSERTING ORDER DATA:ROUTE#'||lv_route_no||':STOP#:'||lv_stop_no;
            --insert for only order data
            IF lv_uom = 2 then
                lv_qty_order_double := lv_qty_order/lv_spc ;
                lv_qty_order := lv_qty_order_double;                
            END IF;    
            
            INSERT INTO SYNTELIC_ROUTE_ORDER_OUT(sequence_number, interface_type, record_status,datetime,
                    route_order_flag, route_no, route_date,
                    cust_id, stop_no, order_id,order_line_id,prod_id,
    				float_seq,uom,qty_order,spc,unitize_ind,sel_type,zone_id,area,
    				src_loc,seq_no,immediate_ind,selection_batch_no,loader_batch_no,
    				method_id,add_user, add_date, upd_user, upd_date)
                    values(syntelic_route_order_seq.nextVal, ' ','N',SYSDATE,'O', lv_route_no,lv_route_date, lv_cust_id, lv_stop_no, lv_order_id,
                    lv_order_line_id,lv_prod_id,
    				lv_float_seq,lv_uom,lv_qty_order,lv_spc,lv_unitize_ind,lv_sel_type,
    				lv_zone_id,lv_area,lv_src_loc,lv_seq_no,lv_immediate_ind,lv_selection_batch_no,
    				lv_loader_batch_no,lv_method_id,REPLACE(USER,'OPS$',NULL),SYSDATE,REPLACE(USER,'OPS$',NULL),
                    SYSDATE);
            COMMIT;

	END LOOP;
	CLOSE get_selection_batch;
    EXCEPTION
    	 when others then
	pl_log.ins_msg ('FATAL', 'snd_syntelic_route_order',message, SQLCODE, SQLERRM,'SYNTELIC','PL_SYNTELIC_INTERFACES','Y');
    
End snd_syntelic_route_order;		



---------------------------------------------------------------------------
-- PROCEDURE
--    RCV_SYNTELIC_LOADMAP
--
-- Description:
-- The procedure inserts item level zone information into the application table
--      SLS_LOAD_MAP and trailer type detail in table LAS_TRUCK
--
-- Parameters:
--    None
--
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    04/28/10 prao0580 Created.
--    07/30/10 prao0580 Updated the Cursor FROM clause from SLS_LOAD_MAP_DETAIL
--             to SYNTELIC_LOADMAPPING_IN
-----------------------------------------------------------------------------
     PROCEDURE rcv_syntelic_loadmap IS
        lm_route_no varchar2(10);
        lm_truck_no varchar2(10);
        lm_trailer_type varchar2(20);
        lm_float_sequence varchar2(3);
        fs_float_sequence varchar2(3);
        lm_load_type varchar2(1);
        lm_trailer_zone number(2);
        lm_orientation varchar2(1);
        lm_sequence_number NUMBER;
        record_count NUMBER;
        map_exists NUMBER;
        message varchar2(70);

        CURSOR get_float_sequence IS
        SELECT DISTINCT float_sequence FROM SYNTELIC_LOADMAPPING_IN where record_status = 'N';

        BEGIN

        open get_float_sequence;

        loop
        FETCH get_float_sequence into fs_float_sequence;

        SELECT route_no, truck_no, float_sequence,sequence_number,orientation,
        load_type, trailer_type, min(trailer_zone)
        INTO lm_route_no,lm_truck_no,lm_float_sequence,lm_sequence_number,
        lm_orientation,lm_load_type, lm_trailer_type,lm_trailer_zone
        FROM SYNTELIC_LOADMAPPING_IN where record_status = 'N' AND float_sequence = fs_float_sequence AND rownum =1
        group by route_no, truck_no, float_sequence,sequence_number,orientation,load_type,
        trailer_type,trailer_zone;

        map_exists := 0;

        SELECT COUNT(*) INTO map_exists FROM SLS_LOAD_MAP WHERE
        route_no = lm_route_no AND
        load_type = lm_load_type AND
        pallet = lm_float_sequence AND
        map_zone = lm_trailer_zone AND
        NVL(orientation,'X') = NVL(lm_orientation,'X');

        IF map_exists <> 0 THEN

            UPDATE SYNTELIC_LOADMAPPING_IN
            SET record_status ='F', upd_user = REPLACE(USER,'OPS$',NULL),
                Upd_date = SYSDATE
            WHERE route_no = lm_route_no AND truck_no = lm_truck_no AND float_sequence = lm_float_sequence
            AND record_status = 'N';
            message := 'DUPLICATE:ROUTE_NO:'|| lm_route_no || ':TRUCK_NO:' || lm_truck_no ;
            pl_log.ins_msg('WARN','RCV_SYNTELIC_LOADMAP',message,SQLCODE,'DUPLICATE RECORD EXIST IN SLS_LOAD_MAP','SYNTELIC','PL_SYNTELIC_INTERFACES','N');

            COMMIT;

        ELSE

        IF (lm_float_sequence IS NULL OR lm_trailer_zone IS NULL) THEN

            UPDATE SYNTELIC_LOADMAPPING_IN
            SET record_status ='F', upd_user = REPLACE(USER,'OPS$',NULL),
            Upd_date = SYSDATE
            WHERE route_no = lm_route_no AND truck_no = lm_truck_no AND float_sequence = lm_float_sequence
            AND record_status = 'N';
            
            message := 'INCORRECT FLOAT SEQ:ROUTE_NO:'|| lm_route_no;
            pl_log.ins_msg('WARN','RCV_SYNTELIC_LOADMAP',message,SQLCODE,'FLOAT SEQUENCE OR TRAILER ZONE IS NULL','SYNTELIC','PL_SYNTELIC_INTERFACES','N');
            
            COMMIT;

        ELSE

        --insert into SLS_LOAD_MAP
        INSERT INTO SLS_LOAD_MAP (route_no, truck_no, load_type, map_zone, orientation, pallet, add_date, add_user, upd_date, upd_user)
        values(lm_route_no, lm_truck_no, lm_load_type, lm_trailer_zone, lm_orientation, lm_float_sequence, SYSDATE, REPLACE(USER,'OPS$',NULL),
        SYSDATE, REPLACE(USER,'OPS$',NULL));

        IF SQLCODE <> 0 THEN
        -- update record_status to 'F' for failed insertion

            UPDATE SYNTELIC_LOADMAPPING_IN
            SET record_status ='F', upd_user = REPLACE(USER,'OPS$',NULL),
                Upd_date = SYSDATE
                WHERE route_no = lm_route_no AND truck_no = lm_truck_no AND float_sequence = lm_float_sequence
                AND record_status = 'N';
            COMMIT;
            

        ELSE
            SELECT count(*) into record_count FROM LAS_TRUCK WHERE truck = lm_truck_no;
            IF record_count = 0 THEN
                ROLLBACK;
                message := 'LAS_TRUCK:TRUCK:' || lm_truck_no ||',RTE:'|| lm_route_no;
                pl_log.ins_msg('FATAL','RCV_SYNTELIC_LOADMAP',message,SQLCODE,'MISSING TRAILER/TRAILER_TYPE in LAS_TRUCK','SYNTELIC','PL_SYNTELIC_INTERFACES','Y');

                -- update record_status to 'F' as record not available in LAS_TRUCK table
                UPDATE SYNTELIC_LOADMAPPING_IN
                SET record_status ='F', upd_user = REPLACE(USER,'OPS$',NULL),
                    Upd_date = SYSDATE

                  WHERE route_no = lm_route_no AND truck_no = lm_truck_no AND float_sequence = lm_float_sequence
                   AND record_status = 'N';

            ELSE
                --update record in LAS_TRUCK table
                UPDATE LAS_TRUCK
                SET trailer_type = lm_trailer_type
                WHERE truck = lm_truck_no;

                --update the staging table record status
                IF SQLCODE = 0 THEN
                    UPDATE SYNTELIC_LOADMAPPING_IN
                    SET record_status ='S', upd_user = REPLACE(USER,'OPS$',NULL),
                    Upd_date = SYSDATE
                   WHERE route_no = lm_route_no AND truck_no = lm_truck_no AND float_sequence = lm_float_sequence
                   AND record_status = 'N';

                ELSE
                    ROLLBACK;
                    UPDATE SYNTELIC_LOADMAPPING_IN
                    SET record_status ='F', upd_user = REPLACE(USER,'OPS$',NULL),
                        Upd_date = SYSDATE
                    WHERE route_no = lm_route_no AND truck_no = lm_truck_no;

                END IF;
            END IF;

            IF SQLCODE = 0 THEN
                COMMIT;
            ELSE
                ROLLBACK;
            END IF;
        END IF;

        END IF;
        END IF;
        END LOOP;
        CLOSE get_float_sequence;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN NULL;
            
            WHEN OTHERS THEN
            message := 'FATAL,INSERT:SLS_LOAD_MAP-TRUCK: '|| lm_truck_no ||',RTE: '|| lm_route_no;
            pl_log.ins_msg ('FATAL','RCV_SYNTELIC_LOADMAP',message, SQLCODE, SQLERRM,'SYNTELIC','PL_SYNTELIC_INTERFACES','Y');

    END RCV_SYNTELIC_LOADMAP;
END pl_syntelic_interfaces;
/
