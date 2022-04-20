rem *************************************************************************
rem Date   :  23-JUL-2003
rem File   :  v_rp1sd.sql
rem Defect#:  D# 11336 ACPPPK OSD changes
rem Project:  Added trans_type to the where clause
rem Defect#:  D# 11346 ACPPPK SN Receipt changes 
rem Project:  RDC 26-Sep-2003 
rem           This view has been modified by ACPPPK for SN Receipt changes.
rem           The view now includes pallets on closed vendor and RDC POs
rem           with the PO number in the rec_id field and pallets on closed 
rem           but open RDC POs with the SN number in the rec_id field.
rem            
rem Date       User    Comments
rem 12/01/05   prplhj  D#12048 Added parent_pallet_id, warehouse_id, mfg_date
rem		       and exp_date from TRANS table and miniload_storage_ind
rem		       from PM table.
rem
rem 12/31/07   prpbcb  DN: 12317
rem                    Project: Miniload Proforma Correction
rem                    Modified to select the pallets inducted into the
rem                    miniloader from a receiving pallet.
rem                    This was done by joining the PUT transaction for the
rem                    receiving pallet and the MII transaction for the
rem                    induction to get the required info.  The MII transaction
rem                    used is the one deducting the induction qty from the
rem                    receiving LP.  This MII transaction has the carrier
rem                    in the trans.ref_pallet_id column and the receiving LP
rem                    in the trans.pallet_id column.
rem                    Three select statements were added.
rem
rem                    The user now has the ability to do a proforma correction
rem                    on a carrier inducted in the miniloader from a receiving
rem                    pallet.
rem
rem                    Added receiving_uom which will be the same as the
rem                    uom except for miniload carriers where it may be
rem                    different because you may receive cases and induct
rem                    as splits.  The receiving_uom is used in form
rem                    rp1sd.fmb and is used when creating the correction
rem                    transaction record.
rem
rem                    Added pallet_id_order_by.  It will be used by form
rem                    rp1sd as the primary order by value.
rem
rem                    Added miniload_carrier_flag.  It will be Y if the LP
rem                    is a miniload carrier otherwise N.
rem
rem                    Added inducted_from_pallet_id.  This will be displayed
rem                    in form rp1sn as the pallet id a miniload carrier
rem                    was inducted from.
rem
rem                    Added induction_date.  This will be displayed in form
rem                    rp1sn as the date the miniload carrier was inducted
rem                    into the miniloader.  It will lag a little behind the
rem                    true induction on the miniloader because SWMS has to
rem                    receive and process the miniload inventory increase
rem                    message from the miniloader.  The MII transaction is
rem                    created from this message.
rem                    For non-miniload carriers the induction_date is set
rem                    to '01-JAN-1900' since we need a valid date to UNION
rem                    against.
rem                                
rem 04/22/09   prpbcb  DN: 12500
rem                    Project:  
rem                 CRQ9069-QTY Received not sent to SUS for SN pallet split
rem                                
rem                    Add sn_no.  For a PO it will be null.
rem
rem 10/12/09 ctvgg000  ASN to all OPCOs Project
rem
rem                    Add 'VN' to erm_type in the where clause when
rem                    selecting pallets from a regular PO.
rem                    Also when selecting pallets inducted into the
rem                    miniloader from a receiving pallet.
rem 
rem 10/22/14 Vani Reddy Modified the view to show trans_type 'MXP'
rem                        'Matrix Exception PUT' for Proforma
rem                         for Symbotic/Matrix Project
rem 
rem *************************************************************************

CREATE OR REPLACE VIEW swms.v_rp1sd
  (pallet_id,
   trans_id,
   rec_id,
   uom,
   receiving_uom,
   new_status,
   brand,
   prod_id,
   cust_pref_vendor,
   mfg_sku,
   trans_type,
   s_brand,
   qty,
   weight,
   dest_loc,
   trans_date,po_no,
   parent_pallet_id,
   warehouse_id,
   miniload_storage_ind,
   mfg_date,
   exp_date,
   pallet_id_order_by,
   miniload_carrier_flag,
   inducted_from_pallet_id,
   induction_date,
   sn_no)
AS
--
-- PO
--
SELECT t.pallet_id                       pallet_id,
       t.trans_id                        trans_id,
       t.rec_id                          rec_id,
       t.uom                             uom,
       t.uom                             receving_uom,
       t.new_status                      new_status,
       p.brand                           brand,
       p.prod_id                         prod_id,
       p.cust_pref_vendor                cust_pref_vendor,
       p.mfg_sku                         mfg_sku,
       t.trans_type                      trans_type,
       DECODE(SUBSTR(p.brand,1,3), 'SYS', 'SYS', 'Z') ||
         DECODE(SUBSTR(p.brand,1,3), 'SYS',p.prod_id,nvl(mfg_sku,'ZZ')) s_brand,
       NVL(t.qty, 0)                     qty,
       t.weight                          weight,
       t.dest_loc                        dest_loc,
       t.trans_date                      trans_date,
       t.po_no                           po_no,
       t.parent_pallet_id                parent_pallet_id,
       t.warehouse_id                    warehouse_id,
       NVL(p.miniload_storage_ind, 'N')  miniload_storage_ind,
       t.mfg_date                        mfg_date,
       t.exp_date                        exp_date,
       t.pallet_id                       pallet_id_order_by,
       'N'                               miniload_carrier_flag,
       NULL                              inducted_from_pallet_id,
       TO_DATE('01-JAN-1900', 'DD-MON-YYYY')  induction_date,
       NULL                              sn_no
  FROM trans t,
       pm p,
       erm e
 WHERE t.rec_id            = e.erm_id
   AND e.erm_type          IN ('PO','VN')
   AND t.prod_id           = p.prod_id
   AND t.cust_pref_vendor  = p.cust_pref_vendor
   AND t.trans_type        IN ('PUT', 'TRP', 'MXP')               -- Vani Reddy modified on 10/22/2014
UNION
--
-- SN    When the SN PO is not yet closed
--
SELECT t.pallet_id                       pallet_id,
       t.trans_id                        trans_id,
       t.rec_id                          rec_id,
       t.uom                             uom,
       t.uom                             receiving_uom,
       t.new_status                      new_status,
       p.brand                           brand,
       p.prod_id                         prod_id,
       p.cust_pref_vendor                cust_pref_vendor,
       p.mfg_sku                         mfg_sku,
       t.trans_type                      trans_type,
       DECODE(SUBSTR(p.brand,1,3), 'SYS', 'SYS', 'Z') ||
         DECODE(SUBSTR(p.brand,1,3), 'SYS',p.prod_id,nvl(mfg_sku,'ZZ')) s_brand,
       NVL(t.qty, 0)                     qty,
       t.weight                          weight,
       t.dest_loc                        dest_loc,
       t.trans_date                      trans_date,
       t.po_no                           po_no,
       t.parent_pallet_id                parent_pallet_id,
       t.warehouse_id                    warehouse_id,
       NVL(p.miniload_storage_ind, 'N')  miniload_storage_ind,
       t.mfg_date                        mfg_date,
       t.exp_date                        exp_date,
       t.pallet_id                       pallet_id_order_by,
       'N'                               miniload_carrier_flag,
       NULL                              inducted_from_pallet_id,
       TO_DATE('01-JAN-1900', 'DD-MON-YYYY')  induction_date,
       t.rec_id                          sn_no
  FROM trans t,
       pm p,
       erm e,
       v_sn_po_xref v
 WHERE t.rec_id            = e.erm_id
   AND e.erm_type          = 'SN'
   AND t.rec_id            = v.sn_no
   AND t.po_no             = v.po_no
   AND v.po_status         = 'NEW'
   AND t.prod_id           = p.prod_id
   AND t.cust_pref_vendor  = p.cust_pref_vendor
   AND t.trans_type        IN ('PUT', 'TRP', 'MXP')               -- Vani Reddy modified on 10/22/2014
UNION
--
-- SN
--
SELECT t.pallet_id                       pallet_id,
       t.trans_id                        trans_id,
       t.po_no                           po_no,
       t.uom                             uom,
       t.uom                             receiving_uom,
       t.new_status                      new_status,
       p.brand                           brand,
       p.prod_id                         prod_id,
       p.cust_pref_vendor                cust_pref_vendor,
       p.mfg_sku                         mfg_sku,
       t.trans_type                      trans_type,
       DECODE(SUBSTR(p.brand,1,3), 'SYS', 'SYS', 'Z') ||
         DECODE(SUBSTR(p.brand,1,3), 'SYS',p.prod_id,nvl(mfg_sku,'ZZ')) s_brand,
       NVL(t.qty, 0)                     qty,
       t.weight                          weight,
       t.dest_loc                        dest_loc,
       t.trans_date                      trans_date,
       t.po_no                           po_no,
       t.parent_pallet_id                parent_pallet_id,
       t.warehouse_id                    warehouse_id,
       NVL(p.miniload_storage_ind, 'N')  miniload_storage_ind,
       t.mfg_date                        mfg_date,
       t.exp_date                        exp_date,
       t.pallet_id                       pallet_id_order_by,
       'N'                               miniload_carrier_flag,
       NULL                              inducted_from_pallet_id,
       TO_DATE('01-JAN-1900', 'DD-MON-YYYY')  induction_date,
       t.rec_id                          sn_no
  FROM trans t,
       pm p,
       erm e
 WHERE t.rec_id            = e.erm_id
   AND e.erm_type          = 'SN'
   AND t.prod_id           = p.prod_id
   AND t.cust_pref_vendor  = p.cust_pref_vendor
   AND t.trans_type        IN ('PUT', 'TRP', 'MXP')                   -- Vani Reddy modified on 10/22/2014
UNION
--
-- PO
-- Miniloader carrier.
-- Select pallets inducted into the miniloader from a receiving pallet.
-- The PUT transaction for the receiving pallet and the MII transaction
-- for the induction are used to get the required info.
-- Brian Bent I was using v_trans but changed it to miniload_trans
--            because v_trans caused full table scans.
--
SELECT t_mii.ref_pallet_id               pallet_id,
       t_mii.trans_id                    trans_id,
       t_put.rec_id                      rec_id,
       t_mii.uom                         uom,      -- The MII transaction
                                                   -- UOM (induction uom)
       t_put.uom                         receiving_uom,  -- PUT/TRP uom
       t_put.new_status                  new_status,
       p.brand                           brand,
       p.prod_id                         prod_id,
       p.cust_pref_vendor                cust_pref_vendor,
       p.mfg_sku                         mfg_sku,
       t_mii.trans_type                  trans_type,
       DECODE(SUBSTR(p.brand,1,3), 'SYS', 'SYS', 'Z') ||
         DECODE(SUBSTR(p.brand,1,3), 'SYS',p.prod_id,nvl(mfg_sku,'ZZ')) s_brand,
       ABS(NVL(t_mii.qty, 0))  qty,  -- We are selecting the MII transaction
                               -- that is deducting the induction qty from the
                               -- receiving LP so we need the ABS to get the
                               -- qty as a positive nunber.
       t_put.weight,
       t_put.dest_loc    dest_loc,   -- Use the receiving LP PUT transaction
                                     -- location which will be the induction
                                     -- location.  For carriers inducted into
                                     -- miniloader we are not concerned about
                                     -- the location as long as it is in a
                                     -- rule 3 zone location which the
                                     -- induction location is.
       t_mii.trans_date                  trans_date,
       t_put.po_no                       po_no,
       t_mii.parent_pallet_id            parent_pallet_id,
       t_put.warehouse_id                warehouse_id,
       NVL(p.miniload_storage_ind, 'N')  miniload_storage_ind,
       t_put.mfg_date                    mfg_date,
       t_put.exp_date                    exp_date,
       t_put.pallet_id                   pallet_id_order_by,
       'Y'                               miniload_carrier_flag,
       t_mii.pallet_id                   inducted_from_pallet_id,
       t_mii.trans_date                  induction_date,
       NULL                              sn_no
  FROM miniload_trans t_mii,  -- Carrier MII transaction
       trans t_put,           -- Receiving LP PUT transaction
       pm p,
       erm e
 WHERE t_put.rec_id            = e.erm_id
   AND e.erm_type              IN ('PO','VN')
   AND t_put.prod_id           = p.prod_id
   AND t_put.cust_pref_vendor  = p.cust_pref_vendor
   AND t_put.trans_type        IN ('PUT', 'TRP', 'MXP')                 -- Vani Reddy modified on 10/22/2014
   AND t_mii.prod_id           = t_put.prod_id
   AND t_mii.cust_pref_vendor  = t_put.cust_pref_vendor
   AND t_mii.pallet_id         = t_put.pallet_id
   AND t_mii.trans_type        = 'MII'
UNION
--
-- SN
-- Miniloader carrier.
-- Select pallets inducted into the miniloader from a receiving pallet.
-- The PUT transaction for the receiving pallet and the MII transaction
-- for the induction are used to get the required info.
-- Brian Bent I was using v_trans but changed it to miniload_trans
--            because v_trans caused full table scans.
--
SELECT t_mii.ref_pallet_id              pallet_id,
       t_mii.trans_id                   trans_id,
       t_put.rec_id                     rec_id,
       t_mii.uom                        uom,       -- The MII transaction
                                                   -- UOM (induction uom)
       t_put.uom                        receiving_uom,  -- PUT/TRP uom
       t_put.new_status                 new_status,
       p.brand                          brand,
       p.prod_id                        prod_id,
       p.cust_pref_vendor               cust_pref_vendor,
       p.mfg_sku                        mfg_sku,
       t_mii.trans_type                 trans_type,
       DECODE(SUBSTR(p.brand,1,3), 'SYS', 'SYS', 'Z') ||
         DECODE(SUBSTR(p.brand,1,3), 'SYS',p.prod_id,nvl(mfg_sku,'ZZ')) s_brand,
       ABS(NVL(t_mii.qty, 0))  qty,  -- We are selecting the MII transaction
                               -- that is deducting the induction qty from the
                               -- receiving LP so we need the ABS to get the
                               -- qty as a positive nunber.
       t_put.weight      put_weight,
       t_put.dest_loc    dest_loc,   -- Use the receiving LP PUT transaction
                                     -- location which will be the induction
                                     -- location.  For carriers inducted into
                                     -- miniloader we are not concerned about
                                     -- the location as long as it is in a
                                     -- rule 3 zone location which the
                                     -- induction location is.
       t_mii.trans_date                  trans_date,
       t_put.po_no                       po_no,
       t_mii.parent_pallet_id            parent_pallet_id,
       t_mii.warehouse_id                warehouse_id,
       NVL(p.miniload_storage_ind, 'N')  miniload_storage_ind,
       t_put.mfg_date                    mfg_date,
       t_put.exp_date                    exp_date,
       t_put.pallet_id                   pallet_id_order_by,
       'Y'                               miniload_carrier_flag,
       t_mii.pallet_id                   inducted_from_pallet_id,
       t_mii.trans_date                  induction_date,
       t_put.rec_id                      sn_no
  FROM miniload_trans t_mii,  -- Carrier MII transaction
       trans t_put,           -- Receiving LP PUT transaction
       pm p,
       erm e,
       v_sn_po_xref v
 WHERE t_put.rec_id            = e.erm_id
   AND e.erm_type              = 'PO'
   AND t_put.prod_id           = p.prod_id
   AND t_put.cust_pref_vendor  = p.cust_pref_vendor
   AND t_put.trans_type        IN ('PUT', 'TRP', 'MXP')                      -- Vani Reddy modified on 10/22/2014
   AND t_mii.prod_id           = t_put.prod_id
   AND t_mii.cust_pref_vendor  = t_put.cust_pref_vendor
   AND t_mii.pallet_id         = t_put.pallet_id
   AND t_mii.trans_type        = 'MII'
   AND t_put.rec_id            = v.sn_no
   AND t_put.po_no             = v.po_no
   AND v.po_status             = 'NEW'
UNION
--
-- SN
-- Miniloader carrier.
-- Select pallets inducted into the miniloader from a receiving pallet.
-- The PUT transaction for the receiving pallet and the MII transaction
-- for the induction are used to get the required info.
-- Brian Bent I was using v_trans but changed it to miniload_trans
--            because v_trans caused full table scans.
--
SELECT t_mii.ref_pallet_id               pallet_id,
       t_mii.trans_id                    trans_id,
       t_put.po_no                       po_no,
       t_mii.uom                         uom,      -- The MII transaction
                                                   -- UOM (induction uom)
       t_put.uom                         receiving_uom,  -- PUT/TRP uom
       t_put.new_status                  new_status,
       p.brand                           brand,
       p.prod_id                         prod_id,
       p.cust_pref_vendor                cust_pref_vendor,
       p.mfg_sku                         mfg_sku,
       t_mii.trans_type                  trans_type,
       DECODE(SUBSTR(p.brand,1,3), 'SYS', 'SYS', 'Z') ||
         DECODE(SUBSTR(p.brand,1,3), 'SYS',p.prod_id,nvl(mfg_sku,'ZZ')) s_brand,
       ABS(NVL(t_mii.qty, 0))  qty,  -- We are selecting the MII transaction
                               -- that is deducting the induction qty from the
                               -- receiving LP so we need the ABS to get the
                               -- qty as a positive nunber.
       t_put.weight      weight,
       t_put.dest_loc    dest_loc,   -- Use the receiving LP PUT transaction
                                     -- location which will be the induction
                                     -- location.  For carriers inducted into
                                     -- miniloader we are not concerned about
                                     -- the location as long as it is in a
                                     -- rule 3 zone location which the
                                     -- induction location is.
       t_mii.trans_date                  trans_date,
       t_put.po_no                       po_no,
       t_mii.parent_pallet_id            parent_pallet_id,
       t_mii.warehouse_id                warehouse_id,
       NVL(p.miniload_storage_ind, 'N')  miniload_storage_ind,
       t_put.mfg_date                    mfg_date,
       t_put.exp_date                    exp_date,
       t_put.pallet_id                   pallet_id_order_by,
       'Y'                               miniload_carrier_flag,
       t_mii.pallet_id                   inducted_from_pallet_id,
       t_mii.trans_date                  induction_date,
       t_put.rec_id                      sn_no
  FROM miniload_trans t_mii,  -- Carrier MII transaction
       trans t_put,           -- Receiving LP PUT transaction
       pm p,
       erm e
 WHERE t_put.rec_id            = e.erm_id
   AND e.erm_type              = 'SN'
   AND t_put.prod_id           = p.prod_id
   AND t_put.cust_pref_vendor  = p.cust_pref_vendor
   AND t_put.trans_type        IN ('PUT', 'TRP', 'MXP')                  -- Vani Reddy modified on 10/22/2014
   AND t_mii.prod_id           = t_put.prod_id
   AND t_mii.cust_pref_vendor  = t_put.cust_pref_vendor
   AND t_mii.pallet_id         = t_put.pallet_id
   AND t_mii.trans_type        = 'MII'
/


