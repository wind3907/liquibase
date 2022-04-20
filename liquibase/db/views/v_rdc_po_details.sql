/* sccs_id= @(#) src/schema/views/v_rdc_po_details.sql, swms, swms.9, 10.1.1 9/7/06 1.5                                                */
rem *************************************************************************
rem Date   :  23-JUL-2003
rem File   :  v_RDC_PO_details .sql
rem Defect#:  11346 
rem              
rem Project:  RDC 
rem        :  ACPAKS: This view contains the qty received for each po line id 
rem        :  of all RDC Pos. This view is necessary because we are recording  
rem        :  the qty received not at the PO line id level but at the 
rem        :  pallet_id level (in putawaylst) and at SN_line_id 
rem        :  level (in erd table) in case of RDC Pos whereas the erd table 
rem        :  will contain the qty received at po line id level for vendor Pos.
rem
rem Modification History 
rem Date	Author	Comments
rem ----------- ------- -----------------------------------------------------
rem 09/29/04	prplhj	D#11762 Sum of received qtys must also consider all
rem			profoma corrections (COR, CSQ.)
rem
rem *************************************************************************
Create or replace view swms.v_RDC_PO_details (erm_id,erm_line_id, prod_id, 
          cust_pref_vendor, qty, weight, qty_rec ,sn_no ) As 
select e.po_no,
       e.po_line_id,
       e.prod_id,
       e.cust_pref_vendor,
       sum(d.qty),
       sum(d.weight),
       sum(d.qty_rec),
       e.sn_no
from  erd_lpn e, erd d
where d.erm_line_id = e.erm_line_id
and   d.erm_id = e.sn_no
and   not exists (select 1
                  from trans
                  where trans_type in ('PUT', 'COR', 'CSQ')
                  and   sn_no = d.erm_id
                  and   po_no = e.po_no
                  and   pallet_id = e.pallet_id)
group by e.po_no, e.po_line_id, e.prod_id, e.cust_pref_vendor,e.sn_no
union
select e.po_no, 
       e.po_line_id, 
       e.prod_id,
       e.cust_pref_vendor,
       sum(decode(t.trans_type, 'CSQ', 0, 'COR', 0, d.qty)) qty,
       sum(d.weight),
       sum(t.qty) qty_rec,
       e.sn_no  
from  erd_lpn e, erd d, pm p, trans t
where d.erm_line_id = e.erm_line_id
and   d.erm_id = e.sn_no
and   d.prod_id = p.prod_id
and   e.sn_no = t.rec_id
and   e.po_no = t.po_no
and   d.erm_id = t.sn_no
and   d.prod_id = t.prod_id
and   e.prod_id = t.prod_id
and   t.prod_id = p.prod_id
and   t.pallet_id = e.pallet_id
and   t.trans_type in ('PUT', 'CSQ', 'COR')
group by e.po_no, e.po_line_id, e.prod_id, e.cust_pref_vendor,e.sn_no
/

