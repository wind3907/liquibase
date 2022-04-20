/* sccs_id= @(#) src/schema/views/v_prp1sc.sql, swms, swms.9, 10.1.1 9/7/06 1.6                                                */
rem *************************************************************************
rem Date   :  11-Aug-2003
rem File   :  v_rp1sd.sql
rem Defect#:  D# 11336 OSD changes
rem           ACPPPK Added  print_status and qty_dmg fields
rem Defect#:  D# 11309 MSKU changes 
rem Project:  RDC 26-Sep-2003 
rem           ACPHXS Added the field IS_MSKU to the view.
rem           PRPAKP Added tti_trk to the view
rem Defect#:  D#12554 Reason Code Changes SCE014
rem           01/19/10 ssha0443 Added the field reason code
rem           02/16/15 mdev3739 Charm2000014331 Sort receiving check in screen
rem			  08/26/15 mdev3739 Charm6000008291 Changed the column name 
rem *************************************************************************

CREATE OR replace VIEW swms.v_prp1sc AS
SELECT brand, putawaylst.prod_id,
        mfg_sku, putawaylst.cust_pref_vendor,
        decode(substr(brand,1,3), 'SYS', ' SYS', 'Z') ||
        decode(substr(brand,1,3), 'SYS', putawaylst.prod_id,
               decode(mfg_sku, NULL, rpad('~', 15, '~'),
                               rpad(mfg_sku, 15, ' '))) OTHER,
        putawaylst.PALLET_ID,
       /* 08/11/03 acphxs      DN:11309 Multi SKU related changes*/
        decode(parent_pallet_id,NULL,' ','M') IS_MSKU,
       /* END 08/11/03 acphxs      DN:11309 Multi SKU related changes*/
        putawaylst.REC_ID,
        putawaylst.DEST_LOC,
        putawaylst.INV_DEST_LOC,
        putawaylst.QTY,
        putawaylst.UOM,
        putawaylst.STATUS,
        putawaylst.INV_STATUS,
        putawaylst.EQUIP_ID,
        putawaylst.PUTPATH,
        putawaylst.REC_LANE_ID,
        putawaylst.ZONE_ID,
        putawaylst.LOT_ID,
        putawaylst.EXP_DATE,
        putawaylst.WEIGHT,
        putawaylst.TEMP,
        putawaylst.MFG_DATE,
        putawaylst.QTY_EXPECTED,
        putawaylst.QTY_RECEIVED,
        putawaylst.DATE_CODE,
        putawaylst.EXP_DATE_TRK,
        putawaylst.LOT_TRK,
        putawaylst.CATCH_WT,
        putawaylst.TEMP_TRK,
        putawaylst.TTI_TRK,
        putawaylst.CLAM_BED_TRK,
        putawaylst.PUTAWAY_PUT,
        putawaylst.SEQ_NO,
        putawaylst.MISPICK, 
        putawaylst.print_status,
        putawaylst.qty_dmg,    
        putawaylst.cool_trk,    
        -- 01/19/10 - DN12554 - ssha0443 - Added for 212 Enh - SCE014 - Begin
        putawaylst.reason_code,
        -- 01/19/10 - DN12554 - ssha0443 - Added for 212 Enh - SCE014 - End
        -- Charm2000014331 Start
                (CASE
                     WHEN    putawaylst.catch_wt = 'Y'
                          OR putawaylst.date_code = 'Y'
                          OR putawaylst.temp_trk = 'Y'
                          OR putawaylst.lot_trk = 'Y'
                          OR putawaylst.exp_date_trk = 'Y'
                          OR putawaylst.clam_bed_trk = 'Y'
                          OR putawaylst.tti_trk = 'Y'
                          OR putawaylst.cool_trk = 'Y'
                     THEN
                        DECODE (putawaylst.qty_received, 0, 'C', 'Y')
                     WHEN    putawaylst.catch_wt = 'C'
                          OR putawaylst.date_code = 'C'
                          OR putawaylst.temp_trk = 'C'
                          OR putawaylst.lot_trk = 'C'
                          OR putawaylst.exp_date_trk = 'C'
                          OR putawaylst.clam_bed_trk = 'C'
                          OR putawaylst.tti_trk = 'C'
                          OR putawaylst.cool_trk = 'C'
                     THEN
                        'C'
                     ELSE
                        'N'
                END) Data_collect
         -- Charm2000014331 End    
   FROM putawaylst left outer join pm
   ON putawaylst.prod_id = pm.prod_id
   AND putawaylst.cust_pref_vendor = pm.cust_pref_vendor
/
