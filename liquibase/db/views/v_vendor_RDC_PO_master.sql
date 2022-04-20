/* sccs_id= @(#) src/schema/views/v_vendor_RDC_PO_master.sql, swms, swms.9, 10.1.1 9/7/06 1.5                                                */
rem *************************************************************************
rem Date   :  19_SEP-2003
rem File   :  v_vendor_RDC_PO_master.sql
rem Defect#:  11346
rem              
rem Project:  RDC ( SN Receipt Changes)
rem           ACPAKS: This is a new view that was created for use in the 
rem           Proforma Screen which was modified to enable SN corrections 
rem           and Proforma Corrections for RDC POs.
rem            
rem            
rem Modification History:
rem   Date     Designer Comments
rem   -------- -------- ---------------------------------------------------
rem   04/27/05 prpbcb   rs239b Oracle 8 DN 11909
rem                     Ticket: HD22308
rem                     Test Director: 5785
rem                     Modified the select from rdc_po as follows:
rem                        Target Column       Old Value   New Value
rem                        -----------------   ---------   ---------
rem                        source_id             ' '         NULL
rem                        load_no               ' '         NULL
rem                        carr_id               ' '         NULL
rem                        warehouse_id          ' '         '000'
rem                        to_warehouse_id       ' '         NULL
rem                        from_warehouse_id     ' '         NULL
rem                     Using a space for the warehouse id's was causing a
rem                     problem in the proforma correction form rp1sd.
rem
rem   04/23/10 gsaj0457 DN 12554 - 212 Legacy Enhancement - SCE066
rem                     Added select for freight
rem
rem   06/14/10 ctvgg000 This view was selecting two records for a VN. one
rem                     from the erm table and the second from  rdc_po.
rem                     so included a where clause in the rdc_po select
rem                     to ignore vn records stored in rdc_po.
rem   08/21/14 Infosys  R13.0-Charm#6000000054-
rem			Changes done for excluding Cross Dock Orders in
rem			Proforma correction screen list
rem *************************************************************************

CREATE OR REPLACE view swms.v_vendor_RDC_PO_master ( erm_id, exp_arriv_date, 
                        status, source_id, sched_date, erm_type, load_no, 
                        carr_id,warehouse_id, to_warehouse_id, 
                        from_warehouse_id,freight)
   AS SELECT erm_id,
             exp_arriv_date,
             status,
             source_id,
             sched_date, 
             erm_type,
             load_no,
             carr_id,
             warehouse_id,
             to_warehouse_id, 
             from_warehouse_id,
             freight
         FROM erm
        WHERE cross_dock_type IS NULL
   UNION
      SELECT  DISTINCT po_no  erm_id,
              SYSDATE         exp_arriv_date,
              po_status       status,
              NULL            source_id,
              SYSDATE         sched_date,
              'PO'            erm_type, 
              NULL            load_no,
              NULL            carr_id,
              '000'           warehouse_id,
              NULL            to_warehouse_id,
              NULL            from_warehouse_id,
              NULL            freight  
          FROM rdc_po           
   WHERE NOT EXISTS (SELECT 1 FROM erm where erm_id = po_no)
/
