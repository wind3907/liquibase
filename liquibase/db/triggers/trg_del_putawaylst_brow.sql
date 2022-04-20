/*------------------------------------------------------------------------------
-- src/schema/triggers/trg_del_putawaylst_brow.sql
--
-- Table:
--    putawaylst
--
-- Description:
--    This trigger inserts the putawaylst record into the putawaylst_hist before
--    it is deleted.
--
-- Modification History:
--    Date     Designer Comments
-- --------    -------- ---------------------------------------------------
-- 11/5/2021   pdas8114	Jira-3786 Trigger populates to putawaylst_hist when deleted from putawaylst
-- 12/10/21    pkab6563 Removed column demand_flag1
-- 14-Jan-2022 pkab6563 Jira 3943: Added column OSD_LR_REASON_CD
-- 03-Feb-2022 pkab6563 Jira 3867: Added column ADD_DATE
-- 23-Feb-2022 kchi7065 Jira 3960: Added column XDOCK_SHIP_CONFIRM
------------------------------------------------------------------------------*/

CREATE OR REPLACE TRIGGER swms.trg_del_putawaylst_brow
BEFORE DELETE ON swms.putawaylst
FOR EACH ROW
BEGIN
   INSERT INTO putawaylst_hist
               (  pallet_id                    
			    , rec_id                       
			    , prod_id                     
			    , dest_loc                     
			    , qty                          
			    , uom                         
			    , status                      
			    , inv_status                   
			    , equip_id                     
			    , putpath                      
			    , rec_lane_id                  
			    , zone_id                      
			    , lot_id                       
			    , exp_date                     
			    , weight                       
			    , temp                         
			    , mfg_date                     
			    , qty_expected                 
			    , qty_received                 
			    , date_code                    
			    , exp_date_trk                 
			    , lot_trk                      
			    , catch_wt                     
			    , temp_trk                     
			    , putaway_put                  
			    , seq_no                       
			    , mispick                      
			    , cust_pref_vendor             
			    , erm_line_id                  
			    , print_status                 
			    , reason_code                  
			    , orig_invoice                 
			    , pallet_batch_no              
			    , out_src_loc                  
			    , out_inv_date                 
			    , rtn_label_printed            
			    , clam_bed_trk                 
			    , inv_dest_loc                 
			    , tti_trk                      
			    , tti                          
			    , cryovac                      
			    , parent_pallet_id             
			    , qty_dmg                      
			    , po_line_id                   
			    , sn_no                        
			    , po_no                        
			    , printed_date                 
			    , cool_trk                     
			    , from_splitting_sn_pallet_flag
			    , demand_flag                  
			    , qty_produced                 
			    , master_order_id              
			    , task_id                      
			    , lm_rcv_batch_no              
			    , door_no                      
			    , putaway_add_user        	 
			    , putaway_add_date        	        	 
          , osd_lr_reason_cd
          , add_date
          , xdock_ship_confirm
				)
         VALUES
              (   :OLD.pallet_id                    
			    , :OLD.rec_id                       
			    , :OLD.prod_id                     
			    , :OLD.dest_loc                     
			    , :OLD.qty                          
			    , :OLD.uom                         
			    , :OLD.status                      
			    , :OLD.inv_status                   
			    , :OLD.equip_id                     
			    , :OLD.putpath                      
			    , :OLD.rec_lane_id                  
			    , :OLD.zone_id                      
			    , :OLD.lot_id                       
			    , :OLD.exp_date                     
			    , :OLD.weight                       
			    , :OLD.temp                         
			    , :OLD.mfg_date                     
			    , :OLD.qty_expected                 
			    , :OLD.qty_received                 
			    , :OLD.date_code                    
			    , :OLD.exp_date_trk                 
			    , :OLD.lot_trk                      
			    , :OLD.catch_wt                     
			    , :OLD.temp_trk                     
			    , :OLD.putaway_put                  
			    , :OLD.seq_no                       
			    , :OLD.mispick                      
			    , :OLD.cust_pref_vendor             
			    , :OLD.erm_line_id                  
			    , :OLD.print_status                 
			    , :OLD.reason_code                  
			    , :OLD.orig_invoice                 
			    , :OLD.pallet_batch_no              
			    , :OLD.out_src_loc                  
			    , :OLD.out_inv_date                 
			    , :OLD.rtn_label_printed            
			    , :OLD.clam_bed_trk                 
			    , :OLD.inv_dest_loc                 
			    , :OLD.tti_trk                      
			    , :OLD.tti                          
			    , :OLD.cryovac                      
			    , :OLD.parent_pallet_id             
			    , :OLD.qty_dmg                      
			    , :OLD.po_line_id                   
			    , :OLD.sn_no                        
			    , :OLD.po_no                        
			    , :OLD.printed_date                 
			    , :OLD.cool_trk                     
			    , :OLD.from_splitting_sn_pallet_flag
			    , :OLD.demand_flag                  
			    , :OLD.qty_produced                 
			    , :OLD.master_order_id              
			    , :OLD.task_id                      
			    , :OLD.lm_rcv_batch_no              
			    , :OLD.door_no                      
			    , :OLD.add_user        	 
			    , NVL(:OLD.add_date, TRUNC (SYSDATE))        	 
          , :OLD.osd_lr_reason_cd
          , SYSDATE
          , :OLD.XDOCK_SHIP_CONFIRM
              );
	EXCEPTION
     WHEN OTHERS THEN
     Pl_log.ins_Msg('WARN','trg_del_putawaylst_brow', 'Trigger trg_del_putawaylst_brow failed ', SQLCODE, SQLERRM);
END;
/
