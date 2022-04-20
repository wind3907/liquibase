CREATE or REPLACE PACKAGE swms.pl_cubitron_interfaces 
IS 
-- sccs_id=@(#) src/schema/plsql/pl_cubitron_interfaces.sql,  
----------------------------------------------------------------------------- 
-- Package Name: 
--   pl_cubitron_interfaces 
-- 
-- Description: 
--    Stored procedures and table functions for Cubitron interfaces 
-- 
-- Modification History: 
--    Date     Designer Comments 
--    -------- -------- ----------------------------------------------------- 
--    05/04/10 prao0580 Created. 
-- 
--    07/03/12 bgul2852 Removed stored procedure and changed procedure
--                      RCV_CUBITRON_MEASUREMENT to use scan_date with data type
--                      date -CRQ37911.
--
--    07/11/12 bgul2852 Changed procedure RCV_CUBITRON_MEASUREMENT 
--                      - CRQ38787. 
-- 
--    07/26/12 bgul2852 Changed procedure RCV_CUBITRON_MEASUREMENT
--                      - CRQ39184. 
--  28-OCT-2014 spot3255   Charm# 6000003789 - Ireland Cubic values - Metric conversion project
--                           Increased length of below variables to hold Cubic centimetre. 
--                           in_case_cube
----------------------------------------------------------------------------- 
 
 
    -- Stored procedure for SCI068 
    PROCEDURE RCV_CUBITRON_MEASUREMENT; 
    
    -- Stored procedure for SCI105
    PROCEDURE snd_cubitron_itemmaster;
    
    -- Table function for SCI105
    FUNCTION swms_cubitron_func RETURN CUBI_ITEMMASTER_OBJECT_TABLE;
     
END pl_cubitron_interfaces; 

/ 
 
--************************************************************************* 
--Package Body 
--************************************************************************* 
 
CREATE OR REPLACE PACKAGE BODY swms.pl_cubitron_interfaces 
AS 
 
--------------------------------------------------------------------------- 
-- PROCEDURE 
--    RCV_CUBITRON_MEASUREMENT 
-- 
-- Description: 
--  The procedure updates the item master table PM with the cube dimensions  
--  and inserts the records into dimensions table PM_DIM_EXCEPTION 
-- 
-- Parameters: 
--  None 
-- 
-- Exceptions Raised: 
--      update_pm_exception 
--      insert_pm_dim_exception  
-- 
-- Modification History: 
--    Date     Designer Comments 
--    -------- -------- ---------------------------------------------------  
--    05/05/10 prao0580 Created. 
--    07/03/12 bgul2852 Changed data type of scan_date field to date -CRQ37911.
--    07/11/12 bgul2852 Changed calculation of g_weight to be stored as split weight.
--                      - CRQ38787.
--    07/26/12 bgul2852 Changed updation of cubitron flag in pm table to 'N'
--                      -CRQ39184.
---------------------------------------------------------------------------   
    PROCEDURE RCV_CUBITRON_MEASUREMENT IS 
        in_sequence_number number; 
        in_prod_id varchar2(9); 
        in_g_weight varchar2(9); 
		in_case_cube varchar2(14); /*was 8*/
        in_ti varchar2(4); 
        in_hi varchar2(4); 
       -- in_scan_date varchar2(16); 
        in_scan_date date;
        in_case_height varchar2(10); 
        in_case_length varchar2(10); 
        in_case_width varchar2(10); 
	in_case_qty_per_carrier varchar2(4); 
        in_chk_g_weight number(8,4); 
	/*Charm# 6000003789*/
        --in_chk_case_cube number(7,4); 
        rec_cnt number;
        update_pm_exception EXCEPTION; 
        insert_pm_dim_exception EXCEPTION; 
        message varchar2(2000); 

 
        CURSOR get_item_measurement IS 
            SELECT sequence_number, prod_id, g_weight, case_cube, ti, hi, scan_date, 
            case_height, case_length, case_width, case_qty_per_carrier 
            FROM CUBITRON_MEASUREMENT_IN 
            WHERE record_status = 'N' 
            ORDER BY sequence_number; 
 
	BEGIN		 
	open get_item_measurement; 
	loop	 
	

            FETCH get_item_measurement into  
            in_sequence_number, 
            in_prod_id, 
            in_g_weight, 
            in_case_cube, 
            in_ti, 
            in_hi, 
            in_scan_date, 
            in_case_height, 
            in_case_length, 
            in_case_width, 
            in_case_qty_per_carrier; 

       exit when get_item_measurement%NOTFOUND;	 
            
            message :='UPDATE:PM PROD#:' || in_prod_id ||',DATE:'|| in_scan_date ||',CASE_CUBE:'|| in_case_cube;
            pl_log.ins_msg ('FATAL','RCV_CUBITRON_MEASUREMENT',message, SQLCODE, SQLERRM, 'CUBITRON','PL_CUBITRON_INTERFACES','Y');
             
 
                --update PM table 
                --CRQ38787:Changed calculation of g_weight to be stored as split weight.
                --CRQ39184:Changed updation of cubitron flag in pm table to 'N'.

                UPDATE PM SET g_weight = to_number(in_g_weight,'9999.9999')/spc, 
                case_cube = to_number(in_case_cube,'99999999.9999'), 
                case_length = to_number(in_case_length),  
                case_width = to_number(in_case_width), 
                case_height = to_number(in_case_height), 
                ti = to_number(in_ti), hi = to_number(in_hi),  
                case_qty_per_carrier = to_number(in_case_qty_per_carrier),  
                --cubitron = 'Y' 
                cubitron = 'N'
                WHERE prod_id = in_prod_id; 
            
                IF SQLCODE <> 0 THEN  
                	RAISE update_pm_exception; 
                ELSE 
                    --insert record in PM_DIM_EXCEPTION table 
                    INSERT INTO PM_DIM_EXCEPTION(prod_id,cust_pref_vendor, case_height, case_length,  
                    case_width, case_cube, case_weight, add_date) 
                    VALUES(in_prod_id,'-', to_number(in_case_height), to_number(in_case_length), 
                    to_number(in_case_width), to_number(in_case_cube,'99999999.9999'), to_number(in_g_weight,'9999.9999'),  
                    --to_date(in_scan_date,'YYYYMMDD HH24:MI')); 
                    in_scan_date); 
                   
                    --update the staging table record status 
                    IF SQLCODE = 0 THEN 
                     
                        UPDATE CUBITRON_MEASUREMENT_IN  
                        SET record_status ='S', upd_user = REPLACE(USER,'OPS$',NULL), 
                        Upd_date = SYSDATE  
                        WHERE sequence_number = in_sequence_number  
                        AND record_status = 'N'; 
                    ELSE 
        				ROLLBACK; 
        				UPDATE CUBITRON_MEASUREMENT_IN  
                        SET record_status ='F', upd_user = REPLACE(USER,'OPS$',NULL), 
        				Upd_date = SYSDATE 
                        WHERE sequence_number = in_sequence_number  
                        AND record_status = 'N'; 
                         
                        RAISE insert_pm_dim_exception; 
        			END IF; 
 
        			IF SQLCODE = 0 THEN 
                        COMMIT; 
                    ELSE 
                        ROLLBACK; 
                    END IF; 
                END IF; 
             
        end loop; 
		close get_item_measurement; 
       	EXCEPTION 
    	WHEN update_pm_exception THEN 
    		ROLLBACK; 
            message := 'UPDATE:PM PROD#:' || in_prod_id ||',DATE:'|| in_scan_date ||',CASE_CUBE:'|| in_case_cube; 
            pl_log.ins_msg('FATAL','RCV_CUBITRON_MEASUREMENT',message, SQLCODE, SQLERRM,'CUBITRON','PL_CUBITRON_INTERFACES','Y'); 
 
        WHEN insert_pm_dim_exception THEN 
            ROLLBACK; 
            message := 'INSERT:PM_DIM_EXCEPTION PROD#:' || in_prod_id ||',DATE:'|| in_scan_date ||',CASE_CUBE:' || in_case_cube; 
            pl_log.ins_msg('FATAL','RCV_CUBITRON_MEASUREMENT',message, SQLCODE, SQLERRM, 'CUBITRON','PL_CUBITRON_INTERFACES','Y'); 
 
        WHEN others THEN 
            ROLLBACK; 
            message :='UPDATE:PM PROD#:' || in_prod_id ||',DATE:'|| in_scan_date ||',CASE_CUBE:'|| in_case_cube; 
            pl_log.ins_msg ('FATAL','RCV_CUBITRON_MEASUREMENT',message, SQLCODE, SQLERRM, 'CUBITRON','PL_CUBITRON_INTERFACES','Y'); 
         
    End RCV_CUBITRON_MEASUREMENT; 
    
    
--------------------------------------------------------------------------- 
-- PROCEDURE 
--    snd_cubitron_itemmaster 
-- 
-- Description: 
--  The procedure reads item master information from the PM table and writes it
--  into the staging table CUBITRON_ITEMMASTER_OUT from where the PI team will
--  read the data and send it to Cubitron.
-- 
-- Exceptions Raised: 
--      None
-- 
-- Modification History: 
--    Date     Designer Comments 
--    -------- -------- ---------------------------------------------------  
--    06/04/10 prao0580 Created. 
---------------------------------------------------------------------------   
    PROCEDURE snd_cubitron_itemmaster IS

        message VARCHAR2(2000);
        lv_pm_prod_size_unit VARCHAR2(9);
        lv_count NUMBER;
        st_count NUMBER;
		loc_key NUMBER;

        -- CURSOR to retrieve item information from PM table
        CURSOR get_item_itemmaster IS
        SELECT prod_id, pack, prod_size, brand, descrip, mfg_sku,
        ti, hi, case_cube, weight, g_weight, split_trk, last_ship_slot,
        catch_wt_trk, container, vendor_id, buyer, pallet_type, master_case,
        NVL(spc,1) spc, external_upc, internal_upc, prod_size_unit FROM PM;
        BEGIN
                SELECT COUNT(*) INTO st_count FROM CUBITRON_ITEMMASTER_OUT;
                
                IF st_count > 0 THEN
                DELETE FROM CUBITRON_ITEMMASTER_OUT;
                END IF;
                
                FOR lv IN get_item_itemmaster
                LOOP

                lv_count := 0;
                lv_pm_prod_size_unit := '000';
                lv_pm_prod_size_unit := lv.prod_size || lv.prod_size_unit;
				SELECT DECODE(config_flag_val, 'CM',99999999.9999,999.99)
				  INTO loc_key
				  FROM sys_config
				 WHERE config_flag_name = 'LENGTH_UNIT';
                
                -- Check whether case_cube and gross weight and net weight < 999.99
                IF to_number(lv.case_cube)> loc_key OR to_number(lv.g_weight)> 999.99 OR to_number(lv.weight)>999.99 THEN
                    CONTINUE;
                ELSE
                    -- If location is NULL in PM table, get the LOCATION from LOC table
                    IF lv.last_ship_slot IS NULL THEN

                        SELECT COUNT(*) INTO lv_count FROM LOC
                        WHERE prod_id=lv.prod_id AND
                        Uom IN (0,1,2) AND rank=1 AND logi_loc IS NOT NULL;

                        IF lv_count > 0 THEN

                        SELECT logi_loc INTO lv.last_ship_slot FROM LOC
                        WHERE prod_id=lv.prod_id AND
                        Uom IN (0,1,2) AND rank=1 AND logi_loc IS NOT NULL AND ROWNUM=1;

                                -- If location is NULL in LOC table, get it from INV table
                                IF lv.last_ship_slot IS NULL THEN

                                    lv_count := 0;

                                    SELECT COUNT(*) INTO lv_count FROM INV WHERE prod_id = lv.prod_id
                                    AND exp_date=(SELECT MIN(exp_date) FROM INV WHERE prod_id= lv.prod_id);

                                    IF lv_count > 0 THEN

                                    SELECT plogi_loc INTO lv.last_ship_slot FROM INV WHERE prod_id = lv.prod_id
                                    AND exp_date=(SELECT MIN(exp_date) FROM INV WHERE prod_id= lv.prod_id) AND ROWNUM=1;

                                    ELSE

                                    message := 'SELECT:Prod id:'||lv.prod_id || 'Location NULL';
                                    pl_log.ins_msg('WARN','SND_CUBITRON_ITEMMASTER',message, SQLCODE,SQLERRM, NULL,'PL_CUBITRON_INTERFACES','N');

                                    END IF;

                                END IF;
                         END IF;
                    END IF;

                message := 'INSERT:CUBITRON_ITEMMASTER_OUT:Prod id:'|| lv.prod_id ||'DESCRIP:'|| lv.descrip;

                -- INSERT data into staging table
                INSERT INTO CUBITRON_ITEMMASTER_OUT(sequence_number, interface_type, record_status,
                datetime, prod_id, pack, prod_size, brand, descrip, mfg_sku, ti, hi, case_cube,
                weight, g_weight, split, location, catch_wt_trk, container, vendor_id, buyer,
                pallet_type, master_case, spc, external_upc, internal_upc, add_user, add_date, upd_user, upd_date)
                VALUES(SWMS_CUBITRON_ITEMMASTER_SEQ.nextval, 'CMS', 'N', SYSDATE,
                lv.prod_id, lv.pack, substr(lv_pm_prod_size_unit,1,6) , lv.brand, lv.descrip,
                lv.mfg_sku, lv.ti, lv.hi, lv.case_cube, lv.weight,
                lv.g_weight, decode(lv.split_trk,'Y','1','0'), lv.last_ship_slot, lv.catch_wt_trk,
                lv.container, lv.vendor_id, lv.buyer,lv.pallet_type,
                lv.master_case, lv.spc, lv.external_upc, lv.internal_upc,
                REPLACE(USER,'OPS$',NULL), SYSDATE, REPLACE(USER,'OPS$',NULL), SYSDATE);
                COMMIT;
                END IF;

                END LOOP;

                EXCEPTION

                WHEN OTHERS THEN
                    --dbms_output.put_line('EXCEPTION:'||SQLERRM);
                    pl_log.ins_msg('FATAL','SND_CUBITRON_ITEMMASTER',message, SQLCODE,SQLERRM, NULL,'PL_CUBITRON_INTERFACES','Y');


      CLOSE get_item_itemmaster;

    END SND_CUBITRON_ITEMMASTER;

-------------------------------------------------------------------------------
-- FUNCTION 
--    swms_cubitron_func
--
-- Description:
--     This function retrieves the data from Oracle staging table CUBITRON_ITEMMASTER_OUT   
--     and sends the item master information.
--
-- Parameters:
--    None          
--
-- Return Values:
--    CUBI_ITEMMASTER_OBJECT_TABLE 
--     
-- Exceptions Raised:
--   when OTHERS propagates the exception.
--
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    06/04/10 prao0580 Created. 
----------------------------------------------------------------------------
    FUNCTION swms_cubitron_func RETURN CUBI_ITEMMASTER_OBJECT_TABLE
    AS
        PRAGMA AUTONOMOUS_TRANSACTION;
        L_CUBI_ITEMMASTER_OBJECT_TABLE CUBI_ITEMMASTER_OBJECT_TABLE:= CUBI_ITEMMASTER_OBJECT_TABLE();

        message varchar2(80);

        BEGIN
        
            UPDATE cubitron_itemmaster_out set RECORD_STATUS ='N' where RECORD_STATUS = 'Q';
            COMMIT;
        

            FOR i_index in (SELECT sequence_number,prod_id, pack, prod_size, brand, descrip, mfg_sku, ti, hi, case_cube, weight,
        		g_weight, split, location, catch_wt_trk, container, vendor_id, buyer, pallet_type,
        		master_case, spc, external_upc, internal_upc FROM CUBITRON_ITEMMASTER_OUT
                       	WHERE record_status='N'
                       	ORDER BY sequence_number)
            LOOP

            message := 'ERROR IN READING:PROD_ID:'||i_index.prod_id ||',DESCRIP:'||i_index.descrip;
          
            UPDATE cubitron_itemmaster_out set RECORD_STATUS ='Q' where sequence_number = i_index.sequence_number;
            COMMIT;
            
            L_CUBI_ITEMMASTER_OBJECT_TABLE.extend;
            L_CUBI_ITEMMASTER_OBJECT_TABLE(L_CUBI_ITEMMASTER_OBJECT_TABLE.count) := CUBITRON_ITEMMASTER_OBJECT
        		(i_index.sequence_number,i_index.prod_id, i_index.pack, i_index.prod_size, i_index.brand, i_index.descrip, i_index.mfg_sku,
        		 i_index.ti, i_index.hi, i_index.case_cube, i_index.weight, i_index.g_weight,
        	     i_index.split, i_index.location, i_index.catch_wt_trk, i_index.container, i_index.vendor_id, i_index.buyer,
        		 i_index.pallet_type, i_index.master_case, i_index.spc, i_index.external_upc, i_index.internal_upc);
            END LOOP;

        RETURN L_CUBI_ITEMMASTER_OBJECT_TABLE;

        EXCEPTION
        	WHEN OTHERS THEN
                pl_log.ins_msg('FATAL','SWMS_CUBITRON_FUNC',message,
        	SQLCODE, SQLERRM, 'CUBITRON', 'PL_CUBITRON_INTERFACES','Y');

    END swms_cubitron_func;

END pl_cubitron_interfaces;
/ 
