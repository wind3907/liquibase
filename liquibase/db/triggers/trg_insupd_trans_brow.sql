/******************************************************************************
  @(#) trg_insupd_trans_brow.sql
  @(#) src/schema/triggers/trg_insupd_trans_brow.sql, swms, swms.9, 11.2 11/13/09 1.8
******************************************************************************/
rem *************************************************************************
rem Date   :  26-AUG-2003
rem File   :  trg_insupd_trans_brow.sql
rem Defect#:  D# 11346  SN Receipt Changes 
rem User Id:  acpppk           
rem Project:  RDC 
rem           This script is used to create a new 'on-insert and update'   
rem           trigger on trans to automatically update SN No and PO No  
rem           fields whenever rec_id field is updated.
rem 11/01/04  prpakp Added to check putawaylst if not found in erd_lpn
rem                  and update the po_no and po_line_id. This is for 
rem                  demand license plate on an SN.
rem 10/17/06  prpswp Added an additional attempt to retrieve the po_no and
rem                  po_line_id from the erd_lpn table for a demand license
rem                  plate on an SN.
rem	
rem 10/12/09  ctvgg000 ASN to all OPCOs Project
rem		       Copy VN PO# to po_no field in trans table, if 
rem                    ERM_TYPE is 'VN' 
rem *************************************************************************

CREATE OR REPLACE TRIGGER swms.trg_insupd_trans_brow   
BEFORE INSERT OR UPDATE  
ON swms.trans
REFERENCING NEW AS NEW OLD AS OLD
FOR EACH ROW
DECLARE                                                                         
   lv_object_name  VARCHAR2(30) := 'trg_insupd_trans_brow'; 
   lv_erm_type VARCHAR2(3);
   lv_erm_status VARCHAR2(3);
BEGIN
   if :new.rec_id is NOT NULL then
   BEGIN
      SELECT erm_type into lv_erm_type
         FROM erm 
            WHERE erm_id=:new.rec_id;
   EXCEPTION
      when NO_DATA_FOUND then
         NULL;
      when OTHERS then
         RAISE_APPLICATION_ERROR(-20001, lv_object_name || ': '|| SQLERRM);  
   END;
   
   if lv_erm_type = 'PO' or lv_erm_type = 'VN' then
   
     -- for vendor POs sn_no is set to NULL,
     -- the vendor po number is copied into po_no
     -- and po_line_id is set to NULL.
     
     
      :new.sn_no := NULL;
      :new.po_no := :new.rec_id;
      :new.po_line_id := NULL;
      
   elsif lv_erm_type ='SN' then
   
      -- for SNs the sn_no is copied from rec_id to sn_no field.
   
      :new.sn_no := :new.rec_id;
      
      if :new.pallet_id is NOT NULL then
         
         -- if pallet_id for the record is not NULL then 
         -- po_no and po_line_id for that pallet_id are retrieved 
         -- from erd_lpn table.
         
         BEGIN
           SELECT po_no, po_line_id INTO :new.po_no, :new.po_line_id
             FROM erd_lpn 
            WHERE pallet_id = :new.pallet_id
              AND sn_no = :new.rec_id;
         EXCEPTION
           when NO_DATA_FOUND then
             begin
               select po_no, po_line_id
                 into :new.po_no, :new.po_line_id
                 from erd_lpn
                where prod_id = :new.prod_id
                  and cust_pref_vendor = :new.cust_pref_vendor
                  and po_no = (select min(po_no) 
                                 from erd_lpn 
                                where sn_no = :new.rec_id
                                  and prod_id = :new.prod_id
                                  and cust_pref_vendor = :new.cust_pref_vendor)
                  and rownum < 2;
             exception
               when NO_DATA_FOUND then
                 begin
                   select po_no, po_line_id INTO :new.po_no,:new.po_line_id
                     from putawaylst
                    where pallet_id = :new.pallet_id
                      and rec_id = :new.rec_id;
                 exception
                   when others then
                     null;
                 end;
               when OTHERS then
                 RAISE_APPLICATION_ERROR(-20001, lv_object_name || ': '|| SQLERRM);  
             end;
         END;
        
      end if;
     else
        :new.po_no := :new.rec_id; 
  end if;
 end if; -- if :new.rec_id is NOT NULL. 
                                                         
EXCEPTION                                                                       
   WHEN OTHERS THEN                                                             
      RAISE_APPLICATION_ERROR(-20001, lv_object_name || ': '|| SQLERRM);  

End;
/

