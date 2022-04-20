/*******************************************************************************
**Package:
**        pl_rf_chkin_upd. Migrated from chkin_upd.pc
**
**Description:
**		  This program validates the pallet tag ID by verifying
** 		that it exists in the putawaylst table. If not existed the program
** 		return invalid pallet label message else it returns normal message.
** 		Once the pallet is validated, the program updates the receipt quantity
** 		as well as any other data and then create transaction record.
**
**Called by:
**        This package is called by java web service.
*******************************************************************************/ 
CREATE OR REPLACE PACKAGE pl_rf_chkin_upd AS 
	
	FUNCTION chkin_upd_main(
		 i_rf_log_init_record   	IN rf_log_init_record,
		 i_client_obj           	IN upd_chkin_client_obj
	) RETURN rf.status;
	
	FUNCTION chkin_upd(
        i_client_obj            IN      upd_chkin_client_obj
    )RETURN rf.STATUS;
    
    FUNCTION Process_receiving_checkin RETURN rf.STATUS;
    
    FUNCTION Check_po_status RETURN rf.STATUS;
    
    FUNCTION Validate_mfg_date(i_mfg_date VARCHAR2) RETURN rf.STATUS;
    
    FUNCTION Validate_exp_date(i_exp_date VARCHAR2) RETURN rf.STATUS;
    
    FUNCTION Validate_hrv_date(i_hrv_date VARCHAR2) RETURN rf.STATUS;
    
    FUNCTION Insert_rhb_trans RETURN rf.STATUS;
    
END pl_rf_chkin_upd;
/

CREATE OR REPLACE PACKAGE BODY pl_rf_chkin_upd AS
------------------------------------------------------------------------------
/*                      GLOBAL DECLARATIONS                                */
------------------------------------------------------------------------------

    g_pallet_id              putawaylst.pallet_id%TYPE;						/* store pallet_id from client */
    g_rec_id                 putawaylst.rec_id%TYPE;						/* store erm_id */
    g_qty                    VARCHAR2(7); 									/* store qty from client */
    g_uom                    putawaylst.uom%TYPE; 							/* unit of measure */
    g_lot_id                 putawaylst.lot_id%TYPE;  						/* store lot_id from client */
    g_exp_date               VARCHAR2(6); 									/* store expiration date from client */
    g_mfg_date               VARCHAR2(6); 									/* store mfg date from client */
    g_temp                   VARCHAR2(6);									/* store temperature from client */
    g_prod_id                putawaylst.prod_id%TYPE; 						/* store product ID */
    g_cust_pref_vendor       putawaylst.cust_pref_vendor%TYPE; 				/* Customer prefered vendor */
    g_spc                    pm.spc%TYPE;								    /* spc for prod_id */
    g_erm_status             erm.status%TYPE ; 								/* store status of PO */
    g_harvest_date           VARCHAR2(6); 									/* store harvest date from client */
    g_clam_bed_num           VARCHAR2(10); 									/* store clam bed number from client */
    g_tti_value              putawaylst.tti%TYPE; 							/* store tti information */
    g_cryovac_value          putawaylst.cryovac%TYPE; 						/* store tti information */
    g_temp_trk               VARCHAR2(1); 									/* Store temp_trk */
    g_sz_indmgqty            VARCHAR2(7);									/*  store demaged qty from client */
    g_cool_trk               VARCHAR2(1); 									/* store cool trk */
    g_parent_pallet_id       putawaylst.parent_pallet_id%TYPE;
    g_vc_pallet_batch_no     putawaylst.pallet_batch_no%TYPE;				/* FK LM labor batch #, arbitrarily large size */
    g_vc_dest_loc            putawaylst.dest_loc%TYPE;						/* putawaylst.dest_loc */
    g_l_qty_received         putawaylst.qty_received%TYPE;					/* putawaylst.qty_received */
    g_trailer_cooler_temp    VARCHAR2(6);									/* store cooler temp from client */
    g_trailer_freezer_temp   VARCHAR2(6); 									/* store freezer temp from client */
    g_cooler_trk             VARCHAR2(1); 									/* store cooler trk */
    g_freezer_trk            VARCHAR2(1); 									/* store freezer trk */
    g_reason_code            putawaylst.reason_code%TYPE; 					/*reason code for difference in quantity*/
    g_dmd_flag               putawaylst.demand_flag%TYPE; 					/*Putawaylst.demand_flag*/
	
	-------------------------------------------------------------------------------
	/**                     PUBLIC MODULES                                      **/
	-------------------------------------------------------------------------------
  /*********************************************************************************
  ** FUNCTION:
  **    chkin_upd_main
  ** called by Java service
  ** Description:
  **  main program for Check In Update
  **
  **  INPUT PARAMETERS:   
  **	i_rf_log_init_record 
  **	i_client_obj - holds pallet id,lot number,manufacturing date,temperature,
  **					receiving quantity,expiration date 
  ** RETURN VALUE:
  ** rf status code
  **  21/11/19    CHYD9155    initial version0.0
  ***********************************************************************************/
	FUNCTION chkin_upd_main(
		 i_rf_log_init_record   	IN rf_log_init_record,
		 i_client_obj           	IN upd_chkin_client_obj
	) RETURN rf.status AS
		l_func_name        VARCHAR2(50) := 'chkin_upd_main';
		rf_status          rf.status := rf.STATUS_NORMAL;
	BEGIN
		rf_status := rf.initialize(i_rf_log_init_record);
		IF rf_status = RF.status_normal THEN
			rf_status:=chkin_upd(i_client_obj);
		END IF;
		rf.complete(rf_status);
        RETURN rf_status;
    EXCEPTION
        WHEN OTHERS THEN
			pl_text_log.ins_msg_async('FATAL',l_func_name, 'chkin_upd call failed', sqlcode, sqlerrm);
            rf.logexception(); -- log it
            RAISE;
	END chkin_upd_main;
	
  /*****************************************************************************
  **  FUNCTION:
  **      chkin_upd
  **  Called by : chkin_upd_main
  **  DESCRIPTION:
  **      	This program validates the pallet tag ID by verifying
  ** 		that it exists in the putawaylst table. If not existed the program
  ** 		return invalid pallet label message else it returns normal message.
  ** 		Once the pallet is validated, the program updates the receipt quantity
  ** 		as well as any other data and then create a transaction record.
  **  INPUT PARAMETERS:   
  **	
  **	i_client_obj - holds pallet id,lot number,manufacturing date,temperature,
  **					receiving quantity,expiration date 
  **  RETURN VALUES:
  **      rf_status code
  *****************************************************************************/

    FUNCTION chkin_upd (           
        i_client_obj           IN upd_chkin_client_obj
    ) RETURN rf.status AS

        l_func_name   VARCHAR2(50) := 'chkin_upd';
        rf_status     rf.status := rf.STATUS_NORMAL;
		
    BEGIN
        
        pl_text_log.ins_msg_async('INFO',l_func_name,'Input from scanner. pallet_id = '
																||i_client_obj.pallet_id
																||' qty = '
																||i_client_obj.qty
																||' lot_id = '
																||i_client_obj.lot_id
																||' exp_date = '
																||i_client_obj.exp_date
																||' mfg_date = '
																||i_client_obj.mfg_date
																||' temp = '
																||i_client_obj.temp
																||' clam_bed_num = '
																||i_client_obj.clam_bed_num
																||' harvest_date = '
																||i_client_obj.harvest_date
																||' tti_value = '
																||i_client_obj.tti_value
																||' cryovac_value = '
																||i_client_obj.cryovac_value
																||' cooler_temp = '
																||i_client_obj.cooler_temp
																||' freezer_temp = '
																||i_client_obj.freezer_temp
																||' reason_code = '
																||i_client_obj.reason_code,sqlcode,sqlerrm);
        
        g_pallet_id := i_client_obj.pallet_id;
        g_qty := i_client_obj.qty;
        g_lot_id := i_client_obj.lot_id;
        g_exp_date := i_client_obj.exp_date;
        g_mfg_date := i_client_obj.mfg_date;
        g_temp := i_client_obj.temp;
        g_clam_bed_num := i_client_obj.clam_bed_num;
        g_harvest_date := i_client_obj.harvest_date;
        g_tti_value := i_client_obj.tti_value;
        g_cryovac_value := i_client_obj.cryovac_value;
		/* Copy the value from the client structure to local variables */
        g_trailer_cooler_temp := i_client_obj.cooler_temp;
        g_trailer_freezer_temp := i_client_obj.freezer_temp;
		/* Copy the reason code from the client structure */
        g_reason_code := i_client_obj.reason_code;

		/* Validate the exp date. */
        rf_status := validate_exp_date(g_exp_date);

		/* If the exp date is valid then validate the mfg date. */
        IF rf_status = rf.STATUS_NORMAL THEN
            rf_status := validate_mfg_date(g_mfg_date);
        END IF;

		/* if the mfg date is valid then process the request */
        IF rf_status = rf.STATUS_NORMAL THEN
            rf_status := process_receiving_checkin();
        END IF;

		/* if process request is successful, then check PO status */
        IF rf_status = rf.STATUS_NORMAL THEN
            rf_status := check_po_status();
        END IF;

		/* if all goes well, commit then quit */
        IF rf_status = rf.STATUS_NORMAL THEN
            COMMIT;
        ELSE
            ROLLBACK;
        END IF;
        
        pl_text_log.ins_msg_async('INFO',l_func_name,'Ending Chkin_upd. Status = ' || rf_status,sqlcode,sqlerrm);
        RETURN rf_status;
    END chkin_upd;

  /*****************************************************************************
  **  FUNCTION:
  **      process_receiving_checkin
  **  Called by : chkin_upd
  **  DESCRIPTION:
  **      This program updates receiving quantity and all of the associated data
  ** 		after checkin process has been initiated
  **  
  **  RETURN VALUES:
  **      rf_status code
  **
  **  MODIFICATION LOG:
  **
  **    Date           By          Description
  **    ------------ ---------   ----------------------------------------------
  **    26-Jan-2021  pkab6563    Jira 3290 - Added logic to set the adj_flag 
  **                             of the CHK trans record to 'O' (uppercase 
  **                             letter O) if the temperature is out of range.
  **
  *****************************************************************************/
    FUNCTION process_receiving_checkin RETURN rf.status AS

        l_func_name       				VARCHAR2(50) := 'Process_receiving_checkin';
        l_clam_bed_trk    				putawaylst.clam_bed_trk%TYPE;
        l_hd_casecube       			NUMBER := 0.0;
        l_hd_skidcube       			NUMBER := 0.0;
        l_hi_qtyexpected    			NUMBER;
        l_qty             				NUMBER;
        l_dmgqty          				NUMBER;
        l_sz_temp_qty       			VARCHAR2(8); 					/* Work area */
        rf_status         				rf.status := rf.STATUS_NORMAL;
        l_length_unit     				VARCHAR2(2);

        l_out_of_range        VARCHAR2(1) := 'N';
        l_pm_temp_trk         pm.temp_trk%TYPE;
        l_min_temp            pm.min_temp%TYPE;
        l_max_temp            pm.max_temp%TYPE;
        l_temp                pm.max_temp%TYPE;
		
    BEGIN
		pl_text_log.ins_msg_async('INFO',l_func_name,'starting process_receiving_checkin',sqlcode,sqlerrm);
		/*fetching LENGTH_UNIT syspar*/
        
            l_length_unit := pl_common.f_get_syspar('LENGTH_UNIT','IN');
        
        l_sz_temp_qty := g_qty;
        l_qty := to_number(l_sz_temp_qty);
        l_sz_temp_qty := g_sz_indmgqty;
        l_dmgqty := to_number(l_sz_temp_qty);

		  /*
		  **  Validate pallet ID and retrieve product ID at the same time
		  */
        BEGIN
            SELECT
                prod_id,
                cust_pref_vendor,
                uom,
                rec_id,
                clam_bed_trk,
                qty_expected,
                temp_trk,
                cool_trk,
                nvl(parent_pallet_id,' '),
                pallet_batch_no,
                dest_loc,
                qty_received,
                demand_flag
            INTO
                g_prod_id,
                g_cust_pref_vendor,
                g_uom,
                g_rec_id,
                l_clam_bed_trk,
                l_hi_qtyexpected,
                g_temp_trk,
                g_cool_trk,
                g_parent_pallet_id,
                g_vc_pallet_batch_no,
                g_vc_dest_loc,
                g_l_qty_received,
                g_dmd_flag
            FROM
                putawaylst
            WHERE
                pallet_id = g_pallet_id;

        EXCEPTION
            WHEN OTHERS THEN
                pl_text_log.ins_msg_async('WARN',l_func_name,'putawaylst: Pallet id is invalid. pallet_id = ' 
										|| g_pallet_id,sqlcode,sqlerrm);
                RETURN rf.STATUS_INV_LABEL;
        END;

        -- see if the temperature is out of range
        BEGIN
             SELECT nvl(temp_trk, 'N'), nvl(min_temp, -999), nvl(max_temp, 999)
              INTO l_pm_temp_trk, l_min_temp, l_max_temp
            FROM   pm
            WHERE  prod_id          = g_prod_id
              AND  cust_pref_vendor = g_cust_pref_vendor; 

            IF l_pm_temp_trk = 'Y' THEN
                l_temp := to_number(g_temp);
                IF (l_temp < l_min_temp) OR (l_temp > l_max_temp) THEN
                    l_out_of_range := 'Y';
                END IF;
            END IF;

        EXCEPTION
            WHEN OTHERS THEN
                null;

        END;  -- see if the temperature is out of range

        BEGIN
            SELECT
                prod_id,
                cust_pref_vendor,
                uom,
                rec_id,
                clam_bed_trk,
                temp_trk,
                pallet_batch_no,
                dest_loc,
                qty_received,
                demand_flag
            INTO
                g_prod_id,
                g_cust_pref_vendor,
                g_uom,
                g_rec_id,
                l_clam_bed_trk,
                g_temp_trk,
                g_vc_pallet_batch_no,
                g_vc_dest_loc,
                g_l_qty_received,
                g_dmd_flag
            FROM
                putawaylst
            WHERE
                pallet_id = g_pallet_id
                AND putaway_put = 'Y';

            pl_text_log.ins_msg_async('WARN',l_func_name,'putawaylst:Pallet id is invalid.Putaway already done for pallet_id  ' 
											|| g_pallet_id,sqlcode,sqlerrm);
            RETURN rf.STATUS_PUT_DONE;
        EXCEPTION
            WHEN OTHERS THEN
                pl_text_log.ins_msg_async('INFO',l_func_name,'No data found for pallet_id  '
                                                    || g_pallet_id
                                                    || ' with putaway flag set to Y',sqlcode,sqlerrm);
        END;

        IF g_qty = '0' THEN
			/* The quantity received is 0. */
            BEGIN
                UPDATE putawaylst
                SET
                    status = 'CHK',
                    qty_received = 0,
                    reason_code = DECODE(g_dmd_flag,'Y','O',substr(g_reason_code,1,1) )
                WHERE
                    pallet_id = g_pallet_id;
				
				IF SQL%rowcount = 0 THEN
                
                    pl_text_log.ins_msg_async('WARN',l_func_name,'No records to update to zero quantity in putawaylst. pallet_id = ' 
															|| g_pallet_id,sqlcode,sqlerrm);
                                                    
					RETURN rf.STATUS_PUTAWAYLST_UPDATE_FAIL; 
				END IF;
                BEGIN
                    INSERT INTO trans (
                        trans_id,
                        trans_type,
                        prod_id,
                        qty,
                        pallet_id,
                        trans_date,
                        user_id,
                        rec_id,
                        batch_no,
                        cust_pref_vendor,
                        reason_code)
                     VALUES (
                        trans_id_seq.NEXTVAL,
                        'CHK',
                        g_prod_id,
                        0,
                        g_pallet_id,
                        SYSDATE,
                        user,
                        g_rec_id,
                        99,
                        g_cust_pref_vendor,
                        DECODE(g_dmd_flag,'Y','O',substr(g_reason_code,1,1) ));
                    
                EXCEPTION
                    WHEN OTHERS THEN
                        pl_text_log.ins_msg_async('WARN',l_func_name,'Unable to create CHK transaction. pallet_id = ' 
															|| g_pallet_id,sqlcode,sqlerrm);
                        RETURN rf.STATUS_TRANS_INSERT_FAILED;
                END;
				
            EXCEPTION
                WHEN OTHERS THEN
                    pl_text_log.ins_msg_async('WARN',l_func_name,'Failed to update zero quantity in putawaylst. pallet_id = ' 
															|| g_pallet_id,sqlcode,sqlerrm);
                    RETURN rf.STATUS_PUTAWAYLST_UPDATE_FAIL;
            END;
			  /*
			  ** If everything succeeded at this point then delete the the forklfit
			  ** labor mgmt putaway batch if the putaway task has it populated.
			  ** If an error occurs an aplog message
			  ** is written and processing will continue.  We do not want to
			  ** stop the check-in process with an issue with labor mgmt.
			  */

            IF rf_status = rf.STATUS_NORMAL THEN
				DECLARE
					l_delete_future_only_bln   		BOOLEAN := TRUE;
					l_pallet_batch_no          		putawaylst.pallet_batch_no%TYPE := g_vc_pallet_batch_no;
					l_pallet_id                		putawaylst.pallet_id%TYPE := g_pallet_id;
                BEGIN
                    IF ( l_pallet_batch_no IS NOT NULL ) THEN
                        pl_lmf.delete_putaway_batch(l_pallet_batch_no,l_delete_future_only_bln);
						 
						 /*The next step is to clear the labor batch number field
						   in the putaway task.*/
						BEGIN  
							UPDATE putawaylst
							SET
								pallet_batch_no = NULL
							WHERE
								pallet_id = l_pallet_id;
							
							IF SQL%rowcount = 0 THEN
                
								pl_text_log.ins_msg_async('WARN',l_func_name,'No recors found to update to zero quantity in putawaylst. pallet_id = ' 
															|| g_pallet_id,sqlcode,sqlerrm);
                                                    
								RETURN rf.STATUS_PUTAWAYLST_UPDATE_FAIL; 
							END IF;
						EXCEPTION
							WHEN OTHERS THEN
								pl_text_log.ins_msg_async('WARN',l_func_name,'Failed to update zero quantity in putawaylst. pallet_id = ' 
															|| g_pallet_id,sqlcode,sqlerrm);
								RETURN rf.STATUS_PUTAWAYLST_UPDATE_FAIL;
						END;
                    END IF;

                EXCEPTION
                    WHEN OTHERS THEN
                        pl_text_log.ins_msg_async('WARN',l_func_name,'pl_lmf.delete_putaway_batch failed',sqlcode,sqlerrm);
				END;

            END IF;
            RETURN rf_status;
        END IF; 			/* end if qty_received = 0 */
		 /*
		 **  Select spc and convert qty to split qty
		 **   retrive case_cube and skid_cube for
		 **  OSD processing usage.
		 */

        BEGIN
            SELECT
                spc,
                case_cube,
                skid_cube
            INTO
                g_spc,
                l_hd_casecube,
                l_hd_skidcube
            FROM
                pm p,
                pallet_type pt
            WHERE
                p.prod_id = g_prod_id
                AND p.cust_pref_vendor = g_cust_pref_vendor
                AND p.pallet_type = pt.pallet_type;

        EXCEPTION
            WHEN OTHERS THEN
                pl_text_log.ins_msg_async('WARN',l_func_name,'Unable to get spc case_cube of item. prod_id = '
                                                    || g_prod_id
                                                    || ' cust_pref_vendor = '
                                                    || g_cust_pref_vendor,sqlcode,sqlerrm);

                RETURN rf.STATUS_INV_LABEL;
        END;

		 /*
		 **  Update pallet with data and set cool_trk to 'C' when it is 'Y'
		 */

        BEGIN
            UPDATE putawaylst
            SET
                status = 'CHK',
                qty_received = to_number(g_qty),
                cool_trk = DECODE(cool_trk,'Y','C',cool_trk),
                reason_code = DECODE(g_dmd_flag,'Y','O',substr(g_reason_code,1,1) )
            WHERE
                pallet_id = g_pallet_id;
		
			IF SQL%rowcount = 0 THEN
                
                    pl_text_log.ins_msg_async('WARN',l_func_name,'No records found to update qty information. pallet_id = '
                                                    || g_pallet_id
                                                    || ' qty = '
                                                    || g_qty,sqlcode,sqlerrm);
					RETURN rf.STATUS_PUTAWAYLST_UPDATE_FAIL; 
            END IF;
                
        EXCEPTION
            WHEN OTHERS THEN
                pl_text_log.ins_msg_async('WARN',l_func_name,'Unable to update qty information. pallet_id = '
                                                    || g_pallet_id
                                                    || ' qty = '
                                                    || g_qty,sqlcode,sqlerrm);
                rf_status:= rf.STATUS_PUTAWAYLST_UPDATE_FAIL;
        END;
   
		  /*
		  ** If the qty received was changed from 0 to > 0 and forklift labor
		  ** mgmt is active re-create the putaway labor batch.
		  */

        IF ( g_l_qty_received = 0 ) THEN
            DECLARE
				l_pallet_id                		putawaylst.pallet_id%TYPE := g_pallet_id;
				l_dest_loc                 		putawaylst.dest_loc%TYPE  := g_vc_dest_loc;
				l_no_records_processed     		NUMBER;					-- # of putawaylst records processed.  Should be 1.
				l_no_batches_created       		NUMBER; 				-- # of labor mgmt batches created. 0 or 1.
				l_no_batches_existing      		NUMBER;			 		-- # of labor mgmt batches already existing.
				l_no_batches_not_created   		NUMBER; 				-- # of batches not created because of either a setup issue or an error.   
            BEGIN
				  /*
				   Create the batch only when forklift labor mgmt is active.
				  */
                IF ( pl_lmf.f_forklift_active = true ) THEN
                    pl_lmf.create_putaway_batch_for_lp(l_pallet_id,l_dest_loc,l_no_records_processed,l_no_batches_created,
														l_no_batches_existing,l_no_batches_not_created);
                END IF;

            EXCEPTION
                WHEN OTHERS THEN
                    pl_text_log.ins_msg_async('WARN',l_func_name,'pl_lmf.create_putaway_batch_for_lp failed ',sqlcode,sqlerrm);
                                               
            END;
        END IF;

			/* check for empty data */

        IF g_lot_id != '                              ' THEN
            BEGIN
                UPDATE putawaylst
                SET
                    lot_trk = 'C',
                    lot_id = g_lot_id
                WHERE
                    pallet_id = g_pallet_id;
				
				IF SQL%rowcount = 0 THEN
                
                    pl_text_log.ins_msg_async('WARN',l_func_name,'No rec found to update lot information. pallet_id = '
                                                        || g_pallet_id
                                                        || ' lot_id = '
                                                        || g_lot_id,sqlcode,sqlerrm);
					RETURN rf.STATUS_PUTAWAYLST_UPDATE_FAIL;
 
                END IF;
                
			EXCEPTION
				WHEN OTHERS THEN
					pl_text_log.ins_msg_async('WARN',l_func_name,'Unable to get lot information. pallet_id = '
                                                        || g_pallet_id
                                                        || ' lot_id = '
                                                        || g_lot_id,sqlcode,sqlerrm);
					RETURN rf.STATUS_PUTAWAYLST_UPDATE_FAIL;
			END;
   
        END IF;

		/* check for whether tti_value is Y */

        IF ( ( g_tti_value = 'Y' ) OR ( ( g_tti_value = 'N' ) AND ( g_cryovac_value = 'Y' ) AND ( g_temp != '      ' ) ) ) THEN
            BEGIN
                UPDATE putawaylst
                SET
                    tti_trk = 'C',
                    tti = g_tti_value,
                    cryovac = g_cryovac_value,
                    temp = g_temp
                WHERE
                    prod_id = g_prod_id
                    AND cust_pref_vendor = g_cust_pref_vendor
                    AND rec_id = g_rec_id;
				
				IF SQL%rowcount = 0 THEN
                
                    pl_text_log.ins_msg_async('WARN',l_func_name,'No records found to update tti information prod_id = ' 
													|| g_prod_id,sqlcode,sqlerrm);
					RETURN rf.STATUS_PUTAWAYLST_UPDATE_FAIL;
 
                END IF;
                
			EXCEPTION
				WHEN OTHERS THEN
					pl_text_log.ins_msg_async('WARN',l_func_name,'Unable to update tti information prod_id = ' 
													|| g_prod_id,sqlcode,sqlerrm);
					RETURN rf.STATUS_PUTAWAYLST_UPDATE_FAIL;
			END;            
        END IF;

        IF ( g_parent_pallet_id != ' ' ) THEN
			/* check if cool_trk is Y */
            IF ( g_cool_trk = 'Y' ) THEN
                BEGIN
                    UPDATE putawaylst
                    SET
                        cool_trk = 'C'
                    WHERE
                        prod_id = g_prod_id
                        AND cust_pref_vendor = g_cust_pref_vendor
                        AND rec_id = g_rec_id
                        AND parent_pallet_id = g_parent_pallet_id;
					
					IF SQL%rowcount = 0 THEN
                
						pl_text_log.ins_msg_async('WARN',l_func_name,'No records found to update COOL information. prod_id = ' 
														|| g_prod_id,sqlcode,sqlerrm);
						RETURN rf.STATUS_PUTAWAYLST_UPDATE_FAIL;
 
					END IF;
                
				EXCEPTION
					WHEN OTHERS THEN
						pl_text_log.ins_msg_async('WARN',l_func_name,'Unable to update COOL information. prod_id = ' 
														|| g_prod_id,sqlcode,sqlerrm);
						RETURN rf.STATUS_PUTAWAYLST_UPDATE_FAIL;
				END;    
            END IF;
        END IF;

        IF g_exp_date != '      ' THEN
			/* The expiration date was entered by the user on the RF unit. */
            BEGIN
                UPDATE putawaylst
                SET
                    exp_date_trk = 'C',
                    exp_date = TO_DATE(g_exp_date,'FXMMDDRR')
                WHERE
                    pallet_id = g_pallet_id;
				
				IF SQL%rowcount = 0 THEN
                
					pl_text_log.ins_msg_async('WARN',l_func_name,'No records found to set expiration date information. pallet_id = '
                                                        || g_pallet_id
                                                        || ' exp_date = '
                                                        || g_exp_date,sqlcode,sqlerrm);
						RETURN rf.STATUS_PUTAWAYLST_UPDATE_FAIL;
 
					END IF;
                
			EXCEPTION
				WHEN OTHERS THEN
                    pl_text_log.ins_msg_async('WARN',l_func_name,'Unable to set expiration date information. pallet_id = '
                                                        || g_pallet_id
                                                        || ' exp_date = '
                                                        || g_exp_date,sqlcode,sqlerrm);
                
                    IF sqlcode >= -1899 AND sqlcode <= -1800 THEN
                        RETURN rf.STATUS_INVALID_EXP_DATE;
                    ELSE
                        RETURN rf.STATUS_PUTAWAYLST_UPDATE_FAIL;
                    END IF;
			END;    
        END IF;

        IF ( g_mfg_date != '      ' ) THEN
		  /* The manufacture date was entered by the user on the RF unit.*/
            BEGIN
                UPDATE putawaylst
                SET
                    date_code = 'C',
                    mfg_date = TO_DATE(g_mfg_date,'FXMMDDRR')
                WHERE
                    pallet_id = g_pallet_id;
				
				IF SQL%rowcount = 0 THEN
                
					pl_text_log.ins_msg_async('WARN',l_func_name,'No records to set manufacturers date information. pallet_id = '
                                                        || g_pallet_id
                                                        || ' mfg_date = '
                                                        || g_mfg_date,sqlcode,sqlerrm);
						RETURN rf.STATUS_PUTAWAYLST_UPDATE_FAIL;
 
				END IF;
                
			EXCEPTION
				WHEN OTHERS THEN
                    pl_text_log.ins_msg_async('WARN',l_func_name,'Unable to set manufacturers date information. pallet_id = '
                                                        || g_pallet_id
                                                        || ' mfg_date = '
                                                        || g_mfg_date,sqlcode,sqlerrm);
                
                    IF sqlcode >= -1899 AND sqlcode <= -1800 THEN
                        RETURN rf.STATUS_INVALID_MFG_DATE;
                    ELSE
                        RETURN rf.STATUS_PUTAWAYLST_UPDATE_FAIL;
                    END IF;
			END;    
        END IF;

        IF g_temp is not null AND g_temp_trk = 'Y' THEN
            BEGIN
                UPDATE putawaylst
                SET
                    temp_trk = 'C',
                    temp = g_temp
                WHERE
                    prod_id = g_prod_id
                    AND cust_pref_vendor = g_cust_pref_vendor
                    AND rec_id = g_rec_id;
				IF SQL%rowcount = 0 THEN
                
					pl_text_log.ins_msg_async('WARN',l_func_name,'no records to set temperature information. pallet_id = '
                                                        || g_pallet_id
                                                        || ' temp = '
                                                        || g_temp
                                                        || ' cust_pref_vendor = '
                                                        || g_cust_pref_vendor
                                                        || ' prod_id = '
                                                        || g_prod_id,sqlcode,sqlerrm);
						RETURN rf.STATUS_PUTAWAYLST_UPDATE_FAIL;
 
				END IF;
            EXCEPTION
                WHEN OTHERS THEN
                    pl_text_log.ins_msg_async('WARN',l_func_name,'Unable to set temperature information. pallet_id = '
                                                        || g_pallet_id
                                                        || ' temp = '
                                                        || g_temp
                                                        || ' cust_pref_vendor = '
                                                        || g_cust_pref_vendor
                                                        || ' prod_id = '
                                                        || g_prod_id,sqlcode,sqlerrm);

                    RETURN rf.STATUS_PUTAWAYLST_UPDATE_FAIL;
            END;
        END IF;

		  /*
		  **  Only validate the harvest date if clam bed flag is set
		  */

        IF ( l_clam_bed_trk = 'Y' ) THEN
            rf_status := validate_hrv_date(g_harvest_date);
            IF ( rf_status = rf.STATUS_NORMAL ) THEN
                IF ( g_harvest_date != '      ' ) THEN
                    rf_status := insert_rhb_trans ();
                END IF;

			  /*
			  **  If data enter ok, change collection flag
			  */
                IF ( rf_status = rf.STATUS_NORMAL ) THEN
                    BEGIN
                        UPDATE putawaylst
                        SET
                            clam_bed_trk = 'C'
                        WHERE
                            prod_id = g_prod_id
                            AND cust_pref_vendor = g_cust_pref_vendor
                            AND rec_id = g_rec_id;
						
						IF SQL%rowcount = 0 THEN
                
							 pl_text_log.ins_msg_async('WARN',l_func_name,'No records found to update clam_bed_trk flag.Rec_id = '
                                                                || g_rec_id
                                                                || ' prod_id = '
                                                                || g_prod_id,sqlcode,sqlerrm);
							RETURN rf.STATUS_PUTAWAYLST_UPDATE_FAIL;
 
						END IF;
                    EXCEPTION
                        WHEN OTHERS THEN
                            pl_text_log.ins_msg_async('WARN',l_func_name,'Unable to update clam_bed_trk flag.Rec_id = '
                                                                || g_rec_id
                                                                || ' prod_id = '
                                                                || g_prod_id,sqlcode,sqlerrm);

                            RETURN rf.STATUS_PUTAWAYLST_UPDATE_FAIL;
                    END;
                END IF;
            END IF;

            IF ( rf_status != rf.STATUS_NORMAL ) THEN
                RETURN rf_status;
            END IF;
        END IF;

		/* insert transaction record */

        BEGIN
			BEGIN
				SELECT
					TO_CHAR(exp_date,'MMDDYY')
				INTO g_exp_date
				FROM
					putawaylst
				WHERE
					date_code = 'C'
					AND pallet_id = g_pallet_id;
			EXCEPTION
				WHEN NO_DATA_FOUND THEN
					pl_text_log.ins_msg_async('WARN',l_func_name,'unable to get exp_date for pallet id '||g_pallet_id,sqlcode,sqlerrm);
			END;
			
            INSERT INTO trans (
                trans_id,
                trans_type,
                prod_id,
                cust_pref_vendor,
                uom,
                lot_id,
                exp_date,
                mfg_date,
                qty,
                pallet_id,
                trans_date,
                user_id,
                rec_id,
                temp,
                batch_no,
                tti,
                cryovac,
                reason_code,
                adj_flag)
            VALUES (
                trans_id_seq.NEXTVAL,
                'CHK',
                g_prod_id,
                g_cust_pref_vendor,
                g_uom,
                g_lot_id,
                TO_DATE(g_exp_date,'FXMMDDRR'),
                TO_DATE(g_mfg_date,'FXMMDDRR'),
                to_number(g_qty),
                g_pallet_id,
                SYSDATE,
                user,
                g_rec_id,
                g_temp,
                99,
                g_tti_value,
                g_cryovac_value,
                DECODE(g_dmd_flag,'Y','O',substr(g_reason_code,1,1) ),
                DECODE(l_out_of_range, 'Y', 'O', null));

        EXCEPTION
            WHEN OTHERS THEN
                pl_text_log.ins_msg_async('WARN',l_func_name,'Unable to insert CHK transaction . pallet_id = ' 
										|| g_pallet_id,sqlcode,sqlerrm);
                RETURN rf.STATUS_TRANS_INSERT_FAILED;
        END;
		pl_text_log.ins_msg_async('INFO',l_func_name,'Ending process_receiving_checkin. Status = ' || rf_status,sqlcode,sqlerrm);
        RETURN rf_status;
    END process_receiving_checkin; /* end Process_receiving_checkin */
	
  /*****************************************************************************
  **  FUNCTION:
  **      check_po_status
  **  Called by : chkin_upd
  **  DESCRIPTION:
  **      This function checks for po status and updates
  **		trailer track flags
  **  
  **  RETURN VALUES:
  **      rf_status code
  *****************************************************************************/

    FUNCTION check_po_status RETURN rf.status AS
		
		l_func_name   VARCHAR2(50) := 'Check_po_status';
        rf_status     rf.status := rf.STATUS_NORMAL;
		ORACLE_REC_LOCKED   EXCEPTION;
		PRAGMA EXCEPTION_INIT(ORACLE_REC_LOCKED, -54);
        
    BEGIN
		pl_text_log.ins_msg_async('INFO',l_func_name,'starting check_po_status',sqlcode,sqlerrm);
        BEGIN
          /* Select trailer track flags in addition to status */
            SELECT
                status,
                cooler_trailer_trk,
                freezer_trailer_trk
            INTO
                g_erm_status,
                g_cooler_trk,
                g_freezer_trk
            FROM
                erm
            WHERE
                erm_id = g_rec_id
                AND status = 'OPN'
            FOR UPDATE OF status NOWAIT;

        EXCEPTION            
            WHEN ORACLE_REC_LOCKED THEN
                    rf_status := rf.STATUS_LOCK_PO;
                    pl_text_log.ins_msg_async('WARN',l_func_name,'PO is locked by another user. rec_id = ' || g_rec_id,sqlcode,sqlerrm);
			WHEN OTHERS THEN
                rf_status := rf.STATUS_UNAVL_PO;
                pl_text_log.ins_msg_async('WARN',l_func_name,'PO is unavailable. Rec_id = ' || g_rec_id,sqlcode,sqlerrm);
        END;

        IF rf_status = rf.STATUS_NORMAL THEN
			/* If both cooler and  freezer flag are  set , update cooler and 
			freezer temp and flags */
            BEGIN
                IF ( g_cooler_trk = 'Y' AND g_freezer_trk = 'Y' ) THEN
                    UPDATE erm
                    SET
                        cooler_trailer_temp = g_trailer_cooler_temp,
                        freezer_trailer_temp = g_trailer_freezer_temp,
                        cooler_trailer_trk = 'C',
                        freezer_trailer_trk = 'C'
                    WHERE
                        erm_id = g_rec_id;
					
					IF SQL%rowcount = 0 THEN
                
						pl_text_log.ins_msg_async('WARN',l_func_name,'No records to update temperature and track flags. Rec_id = '
																			|| g_rec_id,sqlcode,sqlerrm);
						rf_status := rf.STATUS_ERM_UPDATE_FAIL;
 
					END IF;
					/* If only cooler flag is set , update cooler temp and flag */

                ELSIF ( g_cooler_trk = 'Y' AND g_freezer_trk = 'N' ) THEN
                    UPDATE erm
                    SET
                        cooler_trailer_temp = g_trailer_cooler_temp,
                        cooler_trailer_trk = 'C'
                    WHERE
                        erm_id = g_rec_id;
					
					IF SQL%rowcount = 0 THEN
                
						pl_text_log.ins_msg_async('WARN',l_func_name,'No records to update temperature and track flags. Rec_id = '
																			|| g_rec_id,sqlcode,sqlerrm);
						rf_status := rf.STATUS_ERM_UPDATE_FAIL;
 
					END IF;
				/* If only freezer flag is set , update freezer temp and flag */

                ELSIF ( g_cooler_trk = 'N' AND g_freezer_trk = 'Y' ) THEN
                    UPDATE erm
                    SET
                        freezer_trailer_temp = g_trailer_freezer_temp,
                        freezer_trailer_trk = 'C'
                    WHERE
                        erm_id = g_rec_id;
					
					IF SQL%rowcount = 0 THEN
                
						pl_text_log.ins_msg_async('WARN',l_func_name,'No records to update temperature and track flags. Rec_id = '
																			|| g_rec_id,sqlcode,sqlerrm);
						rf_status := rf.STATUS_ERM_UPDATE_FAIL;
 
					END IF;

                ELSE
                    IF ( g_cooler_trk = 'Y' AND g_freezer_trk = 'Y' ) THEN
					/* Insert a CHK transaction for cooler temperature */
                        BEGIN
                            INSERT INTO trans (
                                trans_id,
                                trans_type,
                                qty,
                                trans_date,
                                user_id,
                                rec_id,
                                temp,
                                cmt) 
							VALUES (
                                trans_id_seq.NEXTVAL,
                                'CHK',
                                0,
                                SYSDATE,
                                user,
                                g_rec_id,
                                g_trailer_cooler_temp,
                                'Cooler Temperature');
 
                        EXCEPTION	
                            WHEN OTHERS THEN
                                rf_status := rf.STATUS_TRANS_INSERT_FAILED;
                                pl_text_log.ins_msg_async('WARN',l_func_name,'Unable to create CHK transaction for cooler temeprature. rec_id = '
																	|| g_rec_id,sqlcode,sqlerrm);
                        END;

                        BEGIN
							/* Insert a CHK transaction for freezer temperature */
                            INSERT INTO trans (
                                trans_id,
                                trans_type,
                                qty,
                                trans_date,
                                user_id,
                                rec_id,
                                temp,
                                cmt)
							VALUES (
                                trans_id_seq.NEXTVAL,
                                'CHK',
                                0,
                                SYSDATE,
                                user,
                                g_rec_id,
                                g_trailer_freezer_temp,
                                'Freezer Temperature');
                            

                        EXCEPTION
                            WHEN OTHERS THEN
                                rf_status := rf.STATUS_TRANS_INSERT_FAILED;
                                pl_text_log.ins_msg_async('WARN',l_func_name,'Unable to create CHK transaction for freezer temeprature. Rec_id = '
																	|| g_rec_id,sqlcode,sqlerrm);
                        END;

                    ELSIF g_cooler_trk = 'Y' AND g_freezer_trk = 'N' THEN
						/* Insert a CHK transaction for cooler temperature */
                        BEGIN
                            INSERT INTO trans (
                                trans_id,
                                trans_type,
                                qty,
                                trans_date,
                                user_id,
                                rec_id,
                                temp,
                                cmt)
							VALUES (
                                trans_id_seq.NEXTVAL,
                                'CHK',
                                0,
                                SYSDATE,
                                user,
                                g_rec_id,
                                g_trailer_cooler_temp,
                                'Cooler Temperature');
                            

                        EXCEPTION
                            WHEN OTHERS THEN
                                rf_status := rf.STATUS_TRANS_INSERT_FAILED;
                                pl_text_log.ins_msg_async('WARN',l_func_name,'Unable to create CHK transaction for cooler temeprature. Rec_id = '
																		|| g_rec_id,sqlcode,sqlerrm);
                        END;
                    ELSIF g_cooler_trk = 'N' AND g_freezer_trk = 'Y' THEN
						/* Insert a CHK transaction for freezer temperature */
                        BEGIN
                            INSERT INTO trans (
                                trans_id,
                                trans_type,
                                qty,
                                trans_date,
                                user_id,
                                rec_id,
                                temp,
                                cmt)
							VALUES (
                                trans_id_seq.NEXTVAL,
                                'CHK',
                                0,
                                SYSDATE,
                                user,
                                g_rec_id,
                                g_trailer_freezer_temp,
                                'Freezer Temperature');
                            

                        EXCEPTION
                            WHEN OTHERS THEN
                                rf_status := rf.STATUS_TRANS_INSERT_FAILED;
                                pl_text_log.ins_msg_async('WARN',l_func_name,'Unable to create CHK transaction for freezer temeprature. Rec_id = '
																	|| g_rec_id,sqlcode,sqlerrm);
                        END;
                    END IF;
                END IF;
			
			
            EXCEPTION
                WHEN OTHERS THEN
                    rf_status := rf.STATUS_ERM_UPDATE_FAIL;
                    pl_text_log.ins_msg_async('WARN',l_func_name,'Failed to update temperature and track flags. Rec_id = '
																			|| g_rec_id,sqlcode,sqlerrm);
            END;
        END IF;
		pl_text_log.ins_msg_async('INFO',l_func_name,'Ending check_po_status. Status = ' || rf_status,sqlcode,sqlerrm);
        RETURN rf_status;
    END check_po_status;
	
  /*****************************************************************************
  **  FUNCTION:
  **      validate_mfg_date
  **  Called by : chkin_upd
  **  DESCRIPTION:
  **      This function validates the manufacturer date sent by the RF unit.
  **      It must be in format FXMMDDRR and cannot be greater than the sysdate.
  **  PARAMETERS:
  **      i_mfg_date      - The mfg date sent by the RF unit.
  **  RETURN VALUES:
  **      NORMAL                 - Okay.
  **      INVALID_MFG_DATE       - Invalid mfg date.
  **      PUTAWAYLST_UPDATE_FAIL - Oracle error other than an invalid mfg date.
  *****************************************************************************/

    FUNCTION validate_mfg_date (
        i_mfg_date VARCHAR2
    ) RETURN rf.status IS

		l_func_name   VARCHAR2(50) := 'Validate_mfg_date';
        l_dummy       VARCHAR2(1);
        l_mfg_date    VARCHAR2(12); 					/* mfg date populated from parameter. */        
        rf_status     rf.status := rf.STATUS_NORMAL; 	/* Function return status. */
		
    BEGIN
		pl_text_log.ins_msg_async('INFO',l_func_name,'starting validate_mfg_date',sqlcode,sqlerrm);
        IF i_mfg_date = '      ' THEN
            rf_status := rf.STATUS_NORMAL; 		/* The mfg date is blank which is OK. */
        ELSE
            l_mfg_date := i_mfg_date;
			/* Copy the parameter to the local variable. */
            l_dummy := 'N';
            BEGIN
                SELECT
                    'Y'
                INTO l_dummy
                FROM
                    dual
                WHERE
                    TO_DATE(l_mfg_date,'FXMMDDRR') > trunc(SYSDATE);

				/* Check that the mfg date is > than the sysdate. */

                rf_status := rf.STATUS_INVALID_MFG_DATE;
                pl_text_log.ins_msg_async('WARN',l_func_name,'l_mfg_date '
                                                    || l_mfg_date
                                                    || ' format FXMMDDRR.mfg date is > than the sysdate',sqlcode,sqlerrm);

            EXCEPTION
                WHEN NO_DATA_FOUND THEN
                    pl_text_log.ins_msg_async('WARN',l_func_name,'mfg date is < than the sysdate.Validation successful ',sqlcode,sqlerrm);                    
                WHEN OTHERS THEN
                    pl_text_log.ins_msg_async('WARN',l_func_name,'mfg date failed validation, required format FXMMDDRR ',sqlcode,sqlerrm);
                    IF sqlcode >= -1899 AND sqlcode <= -1800 THEN
                        rf_status := rf.STATUS_INVALID_MFG_DATE;
                    ELSE
                        rf_status := rf.STATUS_PUTAWAYLST_UPDATE_FAIL;
                    END IF;

            END;
        END IF;
		pl_text_log.ins_msg_async('INFO',l_func_name,'Ending validate_mfg_date. Status = ' || rf_status,sqlcode,sqlerrm);
        return rf_status;
    END validate_mfg_date;
	
  /*****************************************************************************
  **  FUNCTION:
  **      validate_exp_date
  **  Called by : chkin_upd
  **  DESCRIPTION:
  **      This function validates the expiration date sent by the RF unit.
  **      It must be in format FXMMDDRR and cannot be less than the sysdate.
  **  PARAMETERS:
  **      i_exp_date      - The exp date sent by the RF unit.
  **  RETURN VALUES:
  **      NORMAL                 - Okay.
  **      INVALID_EXP_DATE       - Invalid exp date.
  **      PUTAWAYLST_UPDATE_FAIL - Oracle error other than an invalid date.
  *****************************************************************************/

    FUNCTION validate_exp_date (
        i_exp_date VARCHAR2
    ) RETURN rf.status IS

		l_func_name   VARCHAR2(50) := 'Validate_exp_date';
        l_dummy       VARCHAR2(1);
        l_exp_date    VARCHAR2(12); 					/* exp date populated from parameter. */        
        rf_status     rf.status := rf.STATUS_NORMAL; 	/* Function return status. */
		
    BEGIN
		pl_text_log.ins_msg_async('INFO',l_func_name,'starting validate_exp_date',sqlcode,sqlerrm);
        IF i_exp_date = '      ' THEN
            rf_status := rf.status_normal; 		/* The exp date is blank which is OK. */
        ELSE
            l_exp_date := i_exp_date;
			/* Copy the parameter to the local variable. */
            l_dummy := 'N';
            BEGIN
                SELECT
                    'Y'
                INTO l_dummy
                FROM
                    dual
                WHERE
                    TO_DATE(l_exp_date,'FXMMDDRR') < trunc(SYSDATE);

                rf_status := rf.STATUS_INVALID_EXP_DATE;
                pl_text_log.ins_msg_async('WARN',l_func_name,'exp_date '
                                                    || l_exp_date
                                                    || ' format FXMMDDRR.exp date is > than the sysdate',sqlcode,sqlerrm);

            EXCEPTION
                WHEN NO_DATA_FOUND THEN
                    pl_text_log.ins_msg_async('WARN',l_func_name,'exp date is < than the sysdate.Validation successful ',sqlcode,sqlerrm);
                WHEN OTHERS THEN
                    pl_text_log.ins_msg_async('WARN',l_func_name,'exp date failed validation, required format FXMMDDRR ',sqlcode,sqlerrm);
                    IF sqlcode >=-1899 AND sqlcode <=-1800 THEN
                        rf_status := rf.STATUS_INVALID_EXP_DATE;
                    ELSE
                        rf_status := rf.STATUS_PUTAWAYLST_UPDATE_FAIL;
                    END IF;

            END;

        END IF;
		pl_text_log.ins_msg_async('INFO',l_func_name,'Ending validate_exp_date. Status = ' || rf_status,sqlcode,sqlerrm);
        RETURN rf_status;
    END validate_exp_date; /* end Validate_exp_date */
	
  /*****************************************************************************
  **  FUNCTION:
  **      Validate_hrv_date
  **  Called by: process_receiving_checkin
  **  DESCRIPTION:
  **      This function validates the clam bed harvest date sent by the RF unit.
  **      It must be in format FXMMDDRR and cannot be greater than the sysdate.
  **  PARAMETERS:
  **      i_hrv_date      - The harvest date sent by the RF unit.
  **  RETURN VALUES:
  **      NORMAL                 - Okay.
  **      INVALID_MFG_DATE       - Invalid harvest date.
  **      PUTAWAYLST_UPDATE_FAIL - Oracle error other than an invalid hrv date.
  *****************************************************************************/

    FUNCTION validate_hrv_date (
        i_hrv_date VARCHAR2
    ) RETURN rf.status IS

		l_func_name   VARCHAR2(50) := 'Validate_exp_date';
        l_dummy       VARCHAR2(1);
        l_hrv_date    VARCHAR2(12); 			/* exp date populated from parameter. */
        rf_status     rf.status := rf.STATUS_NORMAL;
		
    BEGIN
        pl_text_log.ins_msg_async('INFO',l_func_name,'Inside Validate_hrv_date,Hrv_date = ' || i_hrv_date,sqlcode,sqlerrm);
        IF i_hrv_date = '      ' THEN
            rf_status := rf.STATUS_NORMAL;
			/* The harvest date is blank which is OK. */
        ELSE
            l_hrv_date := i_hrv_date;
			/* Copy the parameter to the local variable. */
            l_dummy := 'N';
            BEGIN
                SELECT
                    'Y'
                INTO l_dummy
                FROM
                    dual
                WHERE
                    TO_DATE(l_hrv_date,'FXMMDDRR') > trunc(SYSDATE);

                rf_status := rf.STATUS_INVALID_HRV_DATE;
                pl_text_log.ins_msg_async('WARN',l_func_name,'l_hrv_date '
                                                    || l_hrv_date
                                                    || ' format FXMMDDRR.harvest date is > than the sysdate',sqlcode,sqlerrm);

            EXCEPTION
                WHEN NO_DATA_FOUND THEN
                    pl_text_log.ins_msg_async('WARN',l_func_name,'harvest date is < than the sysdate.Validation successful ',sqlcode,sqlerrm);
                WHEN OTHERS THEN
                    pl_text_log.ins_msg_async('WARN',l_func_name,'hrv date failed validation, required format FXMMDDRR ',sqlcode,sqlerrm);
                    IF sqlcode >=-1899 AND sqlcode <=-1800 THEN
                        rf_status := rf.STATUS_INVALID_HRV_DATE;
                    ELSE
                        rf_status := rf.STATUS_PUTAWAYLST_UPDATE_FAIL;
                    END IF;

            END;
        END IF;
		pl_text_log.ins_msg_async('INFO',l_func_name,'Ending validate_hrv_date. Status = ' || rf_status,sqlcode,sqlerrm);
        RETURN rf_status;
    END validate_hrv_date; /* end Validate_hrv_date */
	
  /*****************************************************************************
  **  FUNCTION:
  **      Insert_rhb_trans
  **  Called by : process_receiving_checkin
  **  DESCRIPTION:
  **       This function inserts/updates the RHB transaction for the 
  **      receiving clam bed information
  **  PARAMETERS:
  **      None
  **  RETURN VALUES:
  **      NORMAL                 - Okay.
  **      PUTAWAYLST_UPDATE_FAIL - Oracle error
  *****************************************************************************/

    FUNCTION insert_rhb_trans RETURN rf.status IS

		l_func_name         VARCHAR2(50) := 'Insert_rhb_trans';
        l_tot_qty           putawaylst.qty_received%TYPE; 				/* Arbitrarily large */
        l_trans_id          trans.trans_id%TYPE;  						/* Arbitrarily large */
        l_po_seq_id         trans.lot_id%TYPE; 							/* To hold lot id */
        l_rec_date          VARCHAR2(10); 								/* MMDDYYYY */
        l_no_pallet_found   NUMBER := 0;
        rf_status           rf.status := rf.STATUS_NORMAL;				/* Function return status. */
        
    BEGIN
		 pl_text_log.ins_msg_async('INFO',l_func_name,'Inside insert_rhb_trans',sqlcode,sqlerrm);
		/* Search for an existing transaction */
        BEGIN
            SELECT
                TO_CHAR(trans_id)
            INTO l_trans_id
            FROM
                trans
            WHERE
                rec_id = g_rec_id
                AND prod_id = g_prod_id
                AND cust_pref_vendor = g_cust_pref_vendor
                AND trans_type = 'RHB'
                AND uom = g_uom
                AND ROWNUM = 1;

            pl_text_log.ins_msg_async('INFO',l_func_name,'trans_id = ' || l_trans_id,sqlcode,sqlerrm);
			
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                l_no_pallet_found := 1;
            WHEN OTHERS THEN
                pl_text_log.ins_msg_async('WARN',l_func_name,'SELECT of RHB transaction failed.rec_id = '
                                                    || g_rec_id
                                                    || ' prod_id = '
                                                    || g_prod_id,sqlcode,sqlerrm);

                RETURN rf.STATUS_SEL_TRN_FAIL;
        END;

		  /* Get the total # of quantity (in splits) received for the item, */
		  /* including multiple pallet IDs for an item */

        BEGIN
            SELECT
                TO_CHAR(SUM(nvl(qty_received,0) ) )
            INTO l_tot_qty
            FROM
                putawaylst
            WHERE
                rec_id = g_rec_id
                AND prod_id = g_prod_id
                AND cust_pref_vendor = g_cust_pref_vendor
                AND uom = g_uom;

            pl_text_log.ins_msg_async('INFO',l_func_name,'Number of pallet found = '
                                                || l_no_pallet_found
                                                || ' tot_qty = '
                                                || l_tot_qty,sqlcode,sqlerrm);

        EXCEPTION
            WHEN OTHERS THEN
                pl_text_log.ins_msg_async('WARN',l_func_name,'SELECT of PUTAWAYLST for qty sum failed .Rec_id = '
                                                    || g_rec_id
                                                    || ' prod_id = '
                                                    || g_prod_id,sqlcode,sqlerrm);

                RETURN rf.STATUS_SEL_PUTAWAYLST_FAIL;
        END;

        BEGIN
            SELECT
                lot_id
            INTO l_po_seq_id
            FROM
                trans
            WHERE
                prod_id = g_prod_id
                AND cust_pref_vendor = g_cust_pref_vendor
                AND TO_CHAR(exp_date,'MMDDRR') = g_harvest_date
                AND clam_bed_no = rtrim(ltrim(ltrim(g_clam_bed_num),'0') )
                AND trans_type = 'RHB'
                AND ROWNUM = 1;

        EXCEPTION
            WHEN NO_DATA_FOUND THEN
				/* No matched combination is found. Need to use a new PO */
				/* sequence ID for the transaction */
                BEGIN
                    SELECT
                        TO_CHAR(po_seq_id_seq.NEXTVAL)
                    INTO l_po_seq_id
                    FROM
                        dual;

                EXCEPTION
                    WHEN OTHERS THEN
                        pl_text_log.ins_msg_async('WARN',l_func_name,'SELECT of PO next sequence failed.clam_bed_no = '
                                                            || g_clam_bed_num
                                                            || ' prod_id = '
                                                            || g_prod_id
                                                            || ' harvest_date = '
                                                            || g_harvest_date,sqlcode,sqlerrm);

                        RETURN rf.STATUS_SEL_SEQ_FAIL;
                END;
            WHEN OTHERS THEN
                pl_text_log.ins_msg_async('WARN',l_func_name,'SELECT of RHB transaction PO sequence ID failed.clam_bed_no = '
                                                    || g_clam_bed_num
                                                    || ' prod_id = '
                                                    || g_prod_id
                                                    || ' harvest_date = '
                                                    || g_harvest_date
                                                    || ' rec_id = '
                                                    || g_rec_id,sqlcode,sqlerrm);

                RETURN rf.STATUS_SEL_TRN_FAIL;
        END;

        BEGIN
            SELECT
                TO_CHAR(rec_date,'MMDDYYYY')
            INTO l_rec_date
            FROM
                erm
            WHERE
                erm_id = g_rec_id;

        EXCEPTION
            WHEN OTHERS THEN
                pl_text_log.ins_msg_async('WARN',l_func_name,'SELECT of ERM for rec_date failed.rec_id = ' || g_rec_id,sqlcode,sqlerrm);
                RETURN rf.STATUS_SEL_ERM_FAIL;
        END;

        IF ( l_no_pallet_found = 0 ) THEN
			/* RHB transaction is found. Just update the transaction with the */
			/* latest information along with the found or generated PO */
			/* sequence ID */
            BEGIN
                UPDATE trans
                SET
                    mfg_date = TO_DATE(l_rec_date,'MMDDYYYY'),
                    exp_date = TO_DATE(g_harvest_date,'MMDDRR'),
                    user_id = user,
                    trans_date = SYSDATE,
                    clam_bed_no = rtrim(ltrim(ltrim(g_clam_bed_num),'0') ),
                    uom = g_uom,
                    qty = to_number(l_tot_qty),
                    temp = g_temp,
                    lot_id = l_po_seq_id,
                    batch_no = 99
                WHERE
                    trans_id = to_number(l_trans_id);
				
				IF SQL%rowcount = 0 THEN
                
					pl_text_log.ins_msg_async('WARN',l_func_name,'No records found to update RHB TRANS.Rec_id = '
                                                        || g_rec_id
                                                        || ' prod_id ='
                                                        || g_prod_id
                                                        || ' clam_bed_num = '
                                                        || g_clam_bed_num
                                                        || ' harvest_date = '
                                                        || g_harvest_date
                                                        || ' po_seq_id = '
                                                        || l_po_seq_id,sqlcode,sqlerrm);
						rf_status := rf.STATUS_TRN_UPDATE_FAIL;
 
				END IF;
            EXCEPTION
                WHEN OTHERS THEN
                    pl_text_log.ins_msg_async('WARN',l_func_name,'UPDATE of RHB TRANS failed.Rec_id = '
                                                        || g_rec_id
                                                        || ' prod_id ='
                                                        || g_prod_id
                                                        || ' clam_bed_num = '
                                                        || g_clam_bed_num
                                                        || ' harvest_date = '
                                                        || g_harvest_date
                                                        || ' po_seq_id = '
                                                        || l_po_seq_id,sqlcode,sqlerrm);

                    RETURN rf.STATUS_TRN_UPDATE_FAIL;
            END;
        ELSE
			/* RHB transaction corresponding to the pallet ID is not found. Need */
			/* to insert a new transaction */
            BEGIN
                INSERT INTO trans (
                    trans_id,
                    trans_type,
                    trans_date,
                    rec_id,
                    user_id,
                    prod_id,
                    cust_pref_vendor,
                    exp_date,
                    mfg_date,
                    clam_bed_no,
                    lot_id,
                    qty,
                    uom,
                    temp,
                    batch_no,
                    cmt)
                
                    SELECT
                        trans_id_seq.NEXTVAL,
                        'RHB',
                        SYSDATE,
                        g_rec_id,
                        user,
                        g_prod_id,
                        g_cust_pref_vendor,
                        TO_DATE(g_harvest_date,'MMDDRR'),
                        TO_DATE(l_rec_date,'MMDDYYYY'),
                        rtrim(ltrim(ltrim(g_clam_bed_num),'0') ),
                        l_po_seq_id,
                        to_number(l_tot_qty),
                        g_uom,
                        g_temp,
                        99,
                        'PO SEQ ID = LOT #, REC DAT = MFG DATE, HRVST DAT = EXP DATE'
                    FROM
                        dual;

            EXCEPTION
				WHEN OTHERS THEN
                    pl_text_log.ins_msg_async('WARN',l_func_name,'INSERT of RHB TRANS failed.rec_id = '
                                                        || g_rec_id
                                                        || ' prod_id ='
                                                        || g_prod_id
                                                        || ' clam_bed_num = '
                                                        || g_clam_bed_num
                                                        || ' harvest_date = '
                                                        || g_harvest_date
                                                        || ' po_seq_id = '
                                                        || l_po_seq_id,sqlcode,sqlerrm);

                    RETURN rf.STATUS_TRANS_INSERT_FAILED;
            END;
        END IF;
		pl_text_log.ins_msg_async('INFO',l_func_name,'Ending insert_rhb_trans. Status = ' || rf_status,sqlcode,sqlerrm);
        RETURN rf_status;
    END insert_rhb_trans;

END pl_rf_chkin_upd;
/
grant execute on pl_rf_chkin_upd  to swms_user;
