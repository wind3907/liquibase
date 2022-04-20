/*******************************************************************************

**Package:

**        pl_rf_tm_close_receipt. Migrated from tm_close_receipt.pc

**

**Description:

**        Function To close a Purchase Order from the RF

**

**Called by:

**        This package is called from java web service.

*******************************************************************************/
create or replace PACKAGE                   pl_rf_tm_close_receipt AS
    FUNCTION tm_close_receipt_main (
        i_rf_log_init_record   IN  rf_log_init_record,
        i_client               IN  close_rec_client_obj,
        i_str_supplier_qty     IN  str_supplier_qty_obj,
        o_server               OUT close_rec_server_obj,
        o_supplier_name        OUT str_supplier_name_obj
    ) RETURN rf.status;
	
	FUNCTION tm_close_receipt(
        i_client               IN   close_rec_client_obj,
        i_str_supplier_qty     IN   str_supplier_qty_obj,
        o_server               OUT  close_rec_server_obj,
        o_supplier_name        OUT  str_supplier_name_obj
    ) RETURN rf.status;
	
END pl_rf_tm_close_receipt;

/

create or replace PACKAGE BODY                                     pl_rf_tm_close_receipt AS

---------------------------------------------------------------------------
  -- FUNCTION:
  --    tm_close_receipt_main
  -- called by Java service
  -- Description:
  --  To close a Purchase Order from the RF
  --
  -- IN Parameters:
  --    i_rf_log_init_record      
  --    i_client          	--> tm_close_receipt client obj
  --	i_str_supplier_qty	-->holds supplier name and qty
  -- OUT PARAMETERS
  --	o_server			-->tm_close_receipt server obj
  --	o_supplier_name		-->holds required flag for each supplier
  -- RETURN VALUE:
  -- 	rf status code
  --  29/11/19    CHYD9155    initial version0.0
---------------------------------------------------------------------------

    FUNCTION tm_close_receipt_main(
		i_rf_log_init_record   IN 	rf_log_init_record,
        i_client               IN 	close_rec_client_obj,
        i_str_supplier_qty     IN 	str_supplier_qty_obj,
        o_server               OUT 	close_rec_server_obj,
        o_supplier_name        OUT 	str_supplier_name_obj
	) RETURN rf.status AS
	
		l_func_name        VARCHAR2(50) := 'tm_close_receipt_main';
		rf_status          rf.status := rf.STATUS_NORMAL;
	BEGIN
		rf_status := rf.initialize(i_rf_log_init_record);
		IF rf_status = RF.status_normal THEN
			rf_status:=tm_close_receipt(i_client,i_str_supplier_qty,o_server,o_supplier_name);
		END IF;
		rf.complete(rf_status);
        RETURN rf_status;
    EXCEPTION
        WHEN OTHERS THEN
			pl_text_log.ins_msg_async('FATAL',l_func_name, 'tm_close_receipt call failed', sqlcode, sqlerrm);
            rf.logexception(); -- log it
            RAISE;
	END tm_close_receipt_main;
	
---------------------------------------------------------------------------
  -- FUNCTION:
  --    tm_close_receipt
  -- called by tm_close_receipt_main
  -- Description:
  --  To close a Purchase Order from the RF
  --
  -- IN Parameters:
  --    
  --    i_client          	--> tm_close_receipt client obj
  --	i_str_supplier_qty	-->holds supplier name and qty
  -- OUT PARAMETERS
  --	o_server			-->tm_close_receipt server obj
  --	o_supplier_name		-->holds required flag for each supplier
  -- RETURN VALUE:
  -- 	rf status code
---------------------------------------------------------------------------

    FUNCTION tm_close_receipt(
        i_client               IN close_rec_client_obj,
        i_str_supplier_qty     IN str_supplier_qty_obj,
        o_server               OUT close_rec_server_obj,
        o_supplier_name        OUT str_supplier_name_obj
    ) RETURN rf.status AS

        l_func_name             	VARCHAR2(50) := 'tm_close_receipt';
        l_supplier_name         	VARCHAR2(50);
        l_c_dummy               	VARCHAR2(1);
        l_c_osdflag             	VARCHAR2(1);
        l_hvc_recid             	erm.erm_id%TYPE;
        l_hvc_ermtype           	erm.erm_type%TYPE;
        l_vc_inrecid            	erm.erm_id%TYPE;
        l_hvc_warehouseid       	erm.warehouse_id%TYPE;
        l_hvc_towarehouseid     	erm.to_warehouse_id%TYPE;
        l_food_safety_flag      	erm.food_safety_print_flag%TYPE;
        l_po_cool_item_insert   	NUMBER := 0; 
        l_count                		NUMBER := 0;
		l_rec_id                	erm.erm_id%TYPE; 		/* store PO ID */
		l_sp_supplier_name    		VARCHAR2(500);
		l_sp_supplier_qty     		VARCHAR2(100);
		o_sp_suppliers          	VARCHAR2(2000);
		l_sup_name					VARCHAR2(21);
		l_supplier_qty          	NUMBER;
		l_tilde                 	VARCHAR2(2);
		l_flag               		VARCHAR2(1);
		l_sp_flag             		VARCHAR2(1);
		o_sp_current_total    		NUMBER;
		o_sp_supplier_count   		NUMBER;
		o_erm_id              		erm.erm_id%TYPE;
		o_prod_id             		pm.prod_id%TYPE;
		o_cust_pref_vendor    		pm.cust_pref_vendor%TYPE;
		o_exp_splits          		NUMBER;
		o_exp_qty             		NUMBER;
		o_rec_splits          		NUMBER;
		o_rec_qty             		NUMBER;
		o_hld_cases           		NUMBER;
		o_hld_splits          		NUMBER;
		o_hld_pallet          		NUMBER;
		o_total_pallet        		NUMBER;
		o_num_pallet          		NUMBER;
		o_status              		NUMBER;
		l_defaultweightunit     	pm.default_weight_unit%TYPE; 		/* Added to pass the Weight unit to RF */
        rf_status               	rf.status := rf.STATUS_NORMAL;
		l_c_callprocedureflag   	VARCHAR2(1);
        l_sztemp                	VARCHAR2(12);
        l_prod_id                   pm.prod_id%TYPE;
        l_required                  VARCHAR2(1);
		l_result_table              str_supplier_name_table:=str_supplier_name_table();
		ORACLE_PRIMARY_KEY_CONSTRAINT EXCEPTION;
        PRAGMA EXCEPTION_INIT(ORACLE_PRIMARY_KEY_CONSTRAINT, -1400);
		
        CURSOR c_supplier (
            i_sp_suppliers VARCHAR2
        ) IS SELECT
                 regexp_substr(i_sp_suppliers,'[^~]+',1,level)
             FROM
                 dual
             CONNECT BY
                 regexp_substr(i_sp_suppliers,'[^~]+',1,level) IS NOT NULL;

        
        CURSOR c_ponum_cursor IS SELECT
                                     erm_id,
                                     nvl(warehouse_id,'000'),
                                     nvl(to_warehouse_id,'000'),
                                     erm_type
                                 FROM
                                     erm
                                 WHERE
                                     erm_id LIKE l_vc_inrecid || '%';

    BEGIN
        pl_text_log.ins_msg_async('INFO',l_func_name,'Closing PO client. Rec_id = '
																	||i_client.erm_id
																	||' flag = '
																	||i_client.flag
																    ||' sp_flag = '
																	||i_client.sp_flag
																    ||' sp_count = '
																	||i_client.sp_count,sqlcode,sqlerrm);
																
      /* copy client data into Oracle variables */
        l_rec_id := i_client.erm_id;
        l_vc_inrecid := i_client.erm_id;
        l_flag := i_client.flag;
        l_sp_flag := i_client.sp_flag;
        o_server:=close_rec_server_obj(' ',' ',' ',' ',' ',' ',' ',' ',' ',' ',' ',' ',' ',' ',' ');
	o_supplier_name:= str_supplier_name_obj(str_supplier_name_table(str_supplier_name_obj1(' ',' ')));
        
        
        IF ( l_sp_flag = 'C' ) THEN
			IF i_str_supplier_qty.result_table.count !=0 THEN
				FOR i IN 1..to_number(i_client.sp_count) LOOP
					l_supplier_qty := to_number(i_str_supplier_qty.result_table(i).qty);
					l_supplier_name := i_str_supplier_qty.result_table(i).name;
					l_sp_supplier_name := concat(l_sp_supplier_name,l_tilde);
					l_sp_supplier_name := concat(l_sp_supplier_name,l_supplier_name);
					l_sztemp := l_supplier_qty;
					l_sp_supplier_qty := concat(l_sp_supplier_qty,l_tilde);
					l_sp_supplier_qty := concat(l_sp_supplier_qty,l_sztemp);
					l_tilde := '~';
				END LOOP;
			END IF;
        END IF;

        pl_text_log.ins_msg_async('INFO',l_func_name,'Special Pallet Supplier Info.sp_supplier_name = '
																|| l_sp_supplier_name
																|| ' sp_supplier_qty = '
																|| l_sp_supplier_qty,sqlcode,sqlerrm);

		/*Check for Food Safety Data for a PO* START*/

        BEGIN
            SELECT
                food_safety_print_flag
            INTO l_food_safety_flag
            FROM
                erm
            WHERE
                erm_id = l_vc_inrecid;

        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                pl_text_log.ins_msg_async('WARN',l_func_name,'unable to get food safety flag for erm_id ' || l_vc_inrecid,sqlcode,sqlerrm);
        END;

        BEGIN
            SELECT
                COUNT(*)
            INTO l_po_cool_item_insert
            FROM
                food_safety_inbound
            WHERE
                erm_id LIKE l_vc_inrecid || '%';

        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                pl_text_log.ins_msg_async('WARN',l_func_name,'unable to get total count for erm_id ' || l_vc_inrecid||' in food_safety_inbound',sqlcode,sqlerrm);
        END;

        IF ( l_food_safety_flag = 'Y' AND l_po_cool_item_insert = 0 ) THEN
            rf_status := rf.STATUS_NEED_FOOD_SAFETY_TEMPS;
            
        ELSE
			/* Check for Food Safety Data for a PO--END */
			/* Check 'PND' status of the PO */
            l_c_dummy := pl_common.f_get_syspar('OSD_REASON_CODE','N');
            IF l_c_dummy = 'Y' THEN
                pl_text_log.ins_msg_async('INFO',l_func_name,'This is a OSD track company. ',sqlcode,sqlerrm);
                l_c_osdflag := 'Y';
            ELSE
                l_c_osdflag := 'N';
            END IF;

            IF ( l_c_osdflag = 'Y' ) THEN
                BEGIN
                    SELECT
                        'x'
                    INTO l_c_dummy
                    FROM
                        erm
                    WHERE
                        erm_id LIKE l_vc_inrecid || '%'
                        AND status = 'PND'
                        AND ROWNUM = 1;

					/* there is 'PND' PO */

                    l_c_callprocedureflag := 'N';

					/* Select the pending POs that have */
					/* damaged reason code not assigned.*/
                    BEGIN
                        SELECT
                            'x'
                        INTO l_c_dummy
                        FROM
                            putawaylst
                        WHERE
                            rec_id LIKE l_vc_inrecid || '%'
                            AND pallet_id IN (
                                SELECT
                                    orig_pallet_id
                                FROM
                                    osd
                                WHERE
                                    reason_code IN (
                                        'DDD',
                                        'OOO',
                                        'SSS'))
                            AND ROWNUM = 1;

                        rf_status:= rf.STATUS_OSD_PENDING;
                    EXCEPTION
                        WHEN NO_DATA_FOUND THEN
                            BEGIN
                                OPEN c_ponum_cursor;
                                LOOP
                                    FETCH c_ponum_cursor INTO
                                        l_hvc_recid,
                                        l_hvc_warehouseid,
                                        l_hvc_towarehouseid,
                                        l_hvc_ermtype;
                                    EXIT WHEN c_ponum_cursor%notfound;
                                    BEGIN
                                        UPDATE erm
                                        SET
                                            status = 'CLO'
                                        WHERE
                                            erm_id = l_hvc_recid;
										
                                    EXCEPTION
                                        WHEN OTHERS THEN
                                            pl_text_log.ins_msg_async('WARN',l_func_name,'unable to update erm. Erm_id = '||l_hvc_recid,sqlcode,sqlerrm);
                                            rf_status := rf.STATUS_DATA_ERROR;
                                    END;

                                    IF l_hvc_recid = l_vc_inrecid THEN
                                        BEGIN
                                            INSERT INTO trans (
                                                trans_id,
                                                trans_type,
                                                rec_id,
                                                trans_date,
                                                user_id,
                                                upload_time,
                                                batch_no,
                                                warehouse_id)
                                             VALUES (
                                                trans_id_seq.NEXTVAL,
                                                DECODE(l_hvc_ermtype,'SN','CSN','TR','TRC','CLO'),
                                                l_vc_inrecid,
                                                SYSDATE,
                                                USER,
                                                TO_DATE('01-JAN-1980','FXDD-MON-YYYY'),
                                                99,
                                                DECODE(l_hvc_ermtype,'TR',l_hvc_towarehouseid,l_hvc_warehouseid));
                                            
                                            pl_text_log.ins_msg_async('INFO',l_func_name,'CLO/TRC trans created for rec_id '||l_vc_inrecid,sqlcode,sqlerrm);
                                        
										EXCEPTION
											WHEN DUP_VAL_ON_INDEX OR ORACLE_PRIMARY_KEY_CONSTRAINT THEN
												pl_text_log.ins_msg_async('WARN',l_func_name,'unable to insert trans.Rec_id = '||l_vc_inrecid,sqlcode,sqlerrm);
												rf_status:=rf.STATUS_INSERT_FAIL;
											
                                            WHEN OTHERS THEN
                                                pl_text_log.ins_msg_async('WARN',l_func_name,'unable to insert trans.Rec_id = '||l_vc_inrecid,sqlcode,sqlerrm);
                                                rf_status := rf.STATUS_DATA_ERROR;
                                        END;
                                    ELSE
                                        BEGIN
                                            INSERT INTO trans (
                                                trans_id,
                                                trans_type,
                                                rec_id,
                                                trans_date,
                                                user_id)
                                             VALUES (
                                                trans_id_seq.NEXTVAL,
                                                'ECL',
                                                l_hvc_recid,
                                                SYSDATE,
                                                USER);
                                            

                                            pl_text_log.ins_msg_async('INFO',l_func_name,'ECL trans created for rec_id '||l_hvc_recid,sqlcode,sqlerrm);
                                        EXCEPTION
											WHEN DUP_VAL_ON_INDEX OR ORACLE_PRIMARY_KEY_CONSTRAINT THEN
												pl_text_log.ins_msg_async('WARN',l_func_name,'Unable to create ECL transaction.Rec_id = '||l_hvc_recid,sqlcode,sqlerrm);
												rf_status:=rf.STATUS_INSERT_FAIL;
											
                                            WHEN OTHERS THEN
                                                pl_text_log.ins_msg_async('WARN',l_func_name,'Unable to create ECL transaction.Rec_id = '||l_hvc_recid,sqlcode,sqlerrm);
                                                rf_status := rf.STATUS_DATA_ERROR;
                                        END;
                                    END IF;

                                END LOOP;
                               CLOSE c_ponum_cursor;
                        
                            EXCEPTION
                                WHEN NO_DATA_FOUND THEN
                                    pl_text_log.ins_msg_async('WARN',l_func_name,'unable to fetch cursor c_ponum_cursor. ',sqlcode,sqlerrm);
                                    rf_status := rf.STATUS_DATA_ERROR;
                            END;
                    END;

                EXCEPTION
                    WHEN NO_DATA_FOUND THEN
						/* No 'PND' PO exists, go ahead to call stored procedure */
                        l_c_callprocedureflag := 'Y';
                END;
            ELSE /* l_c_OsdFlag = 'N', go ahead to call stored procedure */
                l_c_callprocedureflag := 'Y';
            END IF;
            IF l_c_callprocedureflag = 'Y' THEN     
                    BEGIN
                        pl_rcv_po_close.mainproc_rf(l_rec_id,l_flag,l_sp_flag,user,l_sp_supplier_name,l_sp_supplier_qty,o_sp_current_total,
                        o_sp_supplier_count,o_erm_id,o_prod_id,o_cust_pref_vendor,o_exp_splits,o_exp_qty,o_rec_splits,o_rec_qty,
                        o_hld_cases,o_hld_splits,o_hld_pallet,o_total_pallet,o_num_pallet,o_status,o_sp_suppliers);

                    EXCEPTION
                        WHEN OTHERS THEN
					
							/* Check if the package pl_rcv_po_close had an error.
							** Got same kind of database error.
							** Return data error to the RF.*/
                              
                            rf_status := rf.STATUS_DATA_ERROR;
                            pl_text_log.ins_msg_async('WARN',l_func_name,'Package procedure pl_rcv_po_close.mainproc had an error',sqlcode,sqlerrm);
                            
                    END;
           END IF; 
               

			/* Added to pass the Weight unit to RF  --start */

                BEGIN                
                    o_prod_id:=trim(o_prod_id); 
           
                    SELECT
                        default_weight_unit
                    INTO l_defaultweightunit
                    FROM
                        pm
                    WHERE
                        prod_id = o_prod_id;

                    pl_text_log.ins_msg_async('INFO',l_func_name,'rec_id = '
                                                        || l_rec_id
                                                        || ' prod_id = '
                                                        || o_prod_id
                                                        || ' DefaultWeightUnit = '
                                                        || l_defaultweightunit,sqlcode,sqlerrm);
		EXCEPTION
                    WHEN NO_DATA_FOUND THEN
                        pl_text_log.ins_msg_async('WARN',l_func_name,'Unable to get Weight unit from PM for prod_id '||o_prod_id,sqlcode,sqlerrm);
                        l_defaultweightunit := 'LB';
                END;

                    IF  rf_status = rf.STATUS_NORMAL  THEN
                        o_server.erm_id := nvl(o_erm_id,'');
                        o_server.prod_id := nvl(o_prod_id,'');
                        o_server.cust_pref_vendor := nvl(o_cust_pref_vendor,'');
                        o_server.exp_splits := nvl(o_exp_splits,'');
                        o_server.rec_splits := nvl(o_rec_splits,'');
                        o_server.rec_qty := nvl(o_rec_qty,'');
                        o_server.exp_qty := nvl(o_exp_qty,'');
                        o_server.hld_cases := nvl(o_hld_cases,'');
                        o_server.hld_splits := nvl(o_hld_splits,'');
                        o_server.hld_pallet := nvl(o_hld_pallet,'');
                        o_server.total_pallet := nvl(o_total_pallet,'');
                        o_server.num_pallet := nvl(o_num_pallet,'');
                        o_server.sp_current_total := nvl(o_sp_current_total,'');
                        o_server.sp_supplier_count := nvl(o_sp_supplier_count,'');

						/* Added to pass the Weight unit to RF  */
						
                       o_server.defaultweightunit := nvl(l_defaultweightunit,'');
                        IF o_status IS NOT NULL THEN
                            rf_status := o_status;
                        END IF;
		        BEGIN
                            
                            OPEN c_supplier(o_sp_suppliers);
                            LOOP
                                FETCH c_supplier INTO l_sup_name;
                                EXIT WHEN c_supplier%NOTFOUND;
                                IF c_supplier%ROWCOUNT=1 AND l_sup_name IS NULL THEN
                                    EXIT;
                                END IF;   
								/*Get required flag for each supplier */								
                                BEGIN
                                    SELECT
                                        COUNT(required)
                                    INTO l_count
                                    FROM
                                        pallet_supplier
                                    WHERE
                                        supplier = l_sup_name
                                        AND required = 'Y'
                                        AND ROWNUM = 1;

                                    IF l_count > 0  THEN
                                        l_required:= 'Y';
                                    ELSE 
                                        l_required:= 'N';
                                    END IF;
                                pl_text_log.ins_msg_async('WARN',l_func_name,'Supplier = '||l_sup_name||' Required = '||l_required,sqlcode,sqlerrm);
                                                        
                                EXCEPTION
                                    WHEN NO_DATA_FOUND THEN
                                        pl_text_log.ins_msg_async('WARN',l_func_name,'Unable to get required flag for supplier '
                                                        || l_sup_name,sqlcode,sqlerrm);
                                        l_required:=' ';
                                END;
                                l_result_table.extend;
                                l_result_table(l_result_table.count):= str_supplier_name_obj1(nvl(l_sup_name,''),nvl(l_required,''));
								o_supplier_name:=str_supplier_name_obj(l_result_table);
                            END LOOP;
                            
                            CLOSE c_supplier;
                            
                        EXCEPTION
                            WHEN NO_DATA_FOUND THEN
                                pl_text_log.ins_msg_async('WARN',l_func_name,'unable to fetch cursor c_supplier.',sqlcode,sqlerrm);
                        END;
                        
                    END IF;
        END IF;

		/* If all goes well, commit then quit */

        IF rf_status = rf.STATUS_NORMAL THEN
            COMMIT;
        ELSE
            ROLLBACK;
        END IF;
		pl_text_log.ins_msg_async('INFO',l_func_name,'Ending tm_close_receipt.For PO '||l_rec_id||' return status to RF = '||rf_status,sqlcode,sqlerrm);
                                                      
        RETURN rf_status;
    END tm_close_receipt;

END pl_rf_tm_close_receipt;

/
grant execute on pl_rf_tm_close_receipt  to swms_user;
/
