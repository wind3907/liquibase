---------------------------------------------------------------------------
-- sccs_id=%Z% %W% %G% %I%
--
-- View:
--    v_rp2ri_detl
--
-- Description:
--    This view is used in the return receiving report.
--
-- Used by:
--    Report rp2rioracle.pc
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    09/10/04 prppxx   Add erm_line_id in the view for printing single
--                      return receiving label.
--    04/01/10 sth0458  DN12554 - 212 Enh - SCE057 - 
--                      Add UOM field to SWMS
--                      Expanded the length of prod size to accomodate 
--                      for prod size unit.
--                      Changed queries to fetch prod_size_unit 
--                      along with prod_size
---------------------------------------------------------------------------
CREATE OR REPLACE VIEW swms.v_rp2ri_detl AS
		/* 04/01/10 - 12554 - sth0458 - Added for 212 Enh - SCE057 - Begin */
		/* select prod size unit */
         SELECT p.prod_id, LPAD(RTRIM(m.pack), 4, ' ') pack, m.prod_size,m.prod_size_unit,            
		/* 04/01/10 - 12554 - sth0458 - Added for 212 Enh - SCE057 - End */		 
                m.brAND, m.descrip, m.mfg_sku,                                  
                m.ti, m.pallet_type, m.hi,                                      
                p.qty_expected, m.spc, p.uom,                                   
                p.pallet_id, p.dest_loc, m.master_case,                         
                p.lot_trk, p.exp_date_trk, p.date_code,                         
                p.temp_trk, p.catch_wt, l.logi_loc,                             
                p.lot_id, r.cust_id, p.reason_code,                             
                f.route_no, nvl(r.stop_no,0) stop_no, NVL(l.put_path,0) put_path,
		p.pallet_batch_no batch_no, p.rec_id erm_id, rtn_label_printed,
		r.return_reason_cd, r.erm_line_id 
          FROM putawaylst p,returns r, pm m, loc l, manifests f 
          WHERE p.rec_id = 'S' || r.manifest_no 
	  AND   f.manifest_no = r.manifest_no
          AND   substr(p.rec_id,1,1) = 'S'
          AND   p.lot_id = r.obligation_no 
          AND   ((p.prod_id = r.prod_id AND (r.return_reason_cd != 'W10' 
                               or r.return_reason_cd != 'W30'))
               OR (p.prod_id = returned_prod_id AND (return_reason_cd = 'W10'
                                             or return_reason_cd = 'W30')))
          AND   r.return_reason_cd not like 'D%'
	  AND   r.return_reason_cd not in ('W45','T30')
	  AND   p.prod_id = m.prod_id
	  AND   p.cust_pref_vendor = m.cust_pref_vendor
	  AND   l.logi_loc (+) = p.dest_loc 
	  AND   nvl(p.rtn_label_printed,'N') != 'Y'
UNION
		/* 04/01/10 - 12554 - sth0458 - Added for 212 Enh - SCE057 - Begin */
		/* select prod size unit */
         SELECT p.prod_id, LPAD(RTRIM(m.pack), 4, ' ') pack, m.prod_size,m.prod_size_unit,
		/* 04/01/10 - 12554 - sth0458 - Added for 212 Enh - SCE057 - End*/
                m.brAND, m.descrip, m.mfg_sku,
                m.ti, m.pallet_type, m.hi,
                p.qty_expected, m.spc, p.uom,
                p.pallet_id, p.dest_loc, m.master_case,
                p.lot_trk, p.exp_date_trk, p.date_code,
                p.temp_trk, p.catch_wt, l.logi_loc,
                nvl(p.lot_id,'*********') lot_id, 
	        nvl(r.cust_id,'----') cust_id, p.reason_code,
                '****' route_no, 0 stop_no, NVL(l.put_path,0) put_path,
		p.pallet_batch_no batch_no, p.rec_id erm_id, rtn_label_printed,
		r.return_reason_cd, r.erm_line_id
          FROM putawaylst p,returns r, pm m, loc l
          WHERE p.rec_id = 'S' || r.manifest_no 
          AND   substr(p.rec_id,1,1) = 'S'
          AND   return_reason_cd in ('W45','T30')
	  AND   (p.lot_id is null AND r.obligation_no is null)
	  AND   p.prod_id = m.prod_id
	  AND   p.cust_pref_vendor = m.cust_pref_vendor
	  AND   l.logi_loc (+) = p.dest_loc
	  AND   nvl(p.rtn_label_printed,'N') != 'Y'
/

