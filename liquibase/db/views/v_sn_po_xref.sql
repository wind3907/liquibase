/* sccs_id= @(#) src/schema/views/v_sn_po_xref.sql, swms, swms.9, 10.1.1 9/7/06 1.4                                                */
rem *************************************************************************
rem Date   :  23-JUL-2003
rem File   :  v_sn_po_xref.sql
rem Defect#:  11346 
rem              
rem Project:  RDC 
rem           ACPAKS: This is the new view of 3 Tables SN_HEADER,RDC_PO and 
rem                   SN_RDC_PO.
rem            
rem *************************************************************************

create or replace view swms.v_sn_po_xref(sn_no, PO_no, sn_status, po_status)  as 
select x.sn_no,
       x.po_no,
       s.status,
       r.po_status
from SN_RDC_PO x, rdc_po r, SN_Header s
where x.sn_no = s.sn_no
  and x.po_no = r.po_no
/

