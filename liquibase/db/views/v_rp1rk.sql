------------------------------------------------------------------------------
-- sccs_id=%Z% %W% %G% %I%
--
-- View:
--    v_rp1rk
--
-- Description:
--     This view is used in printing a receiving pallet license plate.
--     Report rp1rk.pc uses it.
--
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    03/19/09 prpbcb   DN 12474
--                      Project: CRQ7373-Split SN pallet if over SWMS Ti Hi
--                      Created this script to add column
--                      putawaylst.from_splitting_sn_pallet_flag to the view.
--                      The view is an existing view.
--    03/25/09 prpbcb   DN 12474
--                      Change file Description.
--    04/01/10 sth0458  DN12554 - 212 Enh - SCE057 - 
--                      Add UOM field to SWMS.Expanded the length
--                      of prod size to accomodate for prod size
--                      unit.Changed queries to fetch
--                      prod_size_unit along with prod_size
--
--    04/05/12 prpbcb   DN 12615
--                      8i Project:  CRQ33166-Pallet_flow_in_reserve_fixes
--                      11g Project: CRQ33166-Pallet_flow_in_reserve_fixes
--
--                      Print two license plate labels when a pallet is
--                      directed to a pallet flow slot.
--                      Added:
--                         - rsv_plt_flow_lp_fmt_opt
--                         - rsv_plt_flow_lp_fmt_flg_chr
--                         - rsv_plt_flow_num_extra_lp
--
--                      Also added
--                         - new_warehouse_staging_aisle
--                      This is for a warehouse move change made before
--                      the San Antonio move.
------------------------------------------------------------------------------

CREATE OR REPLACE VIEW swms.v_rp1rk
AS
SELECT DISTINCT RPAD(TRUNC(((p.seq_no + 7) / 8), 0), 3)  page,
       p.rec_id                                          erm_id,
       e.erm_type                                        erm_type,
       RPAD(TO_CHAR(e.rec_date, 'MM-DD'), 5)             rec_date,
       RPAD(p.seq_no, 4)                                 seq_no,
       p.prod_id                                         prod_id,
       m.cust_pref_vendor                                cpv,
	   /* 04/01/10 - 12554 - sth0458 - Added for 212 Enh - SCE057 - Begin */
	   /* Concatenate prod size unit */
       LTRIM(RTRIM(m.pack)) || '/' ||trim(m.prod_size)||trim(m.prod_size_unit)        pack_size,
	   /* 04/01/10 - 12554 - sth0458 - Added for 212 Enh - SCE057 - End */
       m.brand                                           brand,
       m.descrip                                         descrip,
       m.mfg_sku                                         mfg_sku,
       LPAD(m.ti, 3)                                     ti,
       RPAD(m.hi, 3)                                     hi,
       p.qty_expected                                    qty,
       p.pallet_id                                       pallet_id,
       DECODE(p.dest_loc, '*', '*',
                          'DDDDDD', 'DDDDDD',
                          SUBSTR(p.dest_loc, 1, 2) || '-'
                          || SUBSTR(p.dest_loc, 3, 2) || '-'
                          || SUBSTR(p.dest_loc, 5, 2))   dest_loc,
       RPAD(l.logi_loc, 6)                               logi_loc,
       p.date_code                                       date_code,
       p.lot_trk                                         lot_trk,
       p.exp_date_trk                                    exp_date_trk,
       p.catch_wt                                        catch_wt,
       p.temp_trk                                        temp_trk,
       p.uom                                             uom,
       m.spc                                             spc,
       d.order_id                                        order_id,
       m.pallet_type                                    pallet_type,
       p.from_splitting_sn_pallet_flag          from_splitting_sn_pallet_flag,
       DECODE(loc_for_loc_ref.perm,
              NULL, NULL,
              'Y', NULL,
              DECODE(e.erm_type,
                     'PO', SUBSTR(pl_common.f_get_syspar('RSV_PLT_FLOW_LP_FMT_OPT_PO', 'A'), 1, 1),
                     'SN', SUBSTR(pl_common.f_get_syspar('RSV_PLT_FLOW_LP_FMT_OPT_SN', 'A'), 1, 1),
                     'VN', SUBSTR(pl_common.f_get_syspar('RSV_PLT_FLOW_LP_FMT_OPT_VN', 'A'), 1, 1),
                     NULL)) rsv_plt_flow_lp_fmt_opt,
       DECODE(loc_for_loc_ref.perm,
              NULL, NULL,
              'Y', NULL,
              DECODE(e.erm_type,
                     'PO', SUBSTR(pl_common.f_get_syspar('RSV_PLT_FLOW_LP_FMT_FLG_CHR_PO', '+'), 1, 1),
                     'SN', SUBSTR(pl_common.f_get_syspar('RSV_PLT_FLOW_LP_FMT_FLG_CHR_SN', '+'), 1, 1),
                     'VN', SUBSTR(pl_common.f_get_syspar('RSV_PLT_FLOW_LP_FMT_FLG_CHR_VN', '+'), 1, 1),
                     NULL)) rsv_plt_flow_lp_fmt_flg_chr,
       DECODE(loc_for_loc_ref.perm,
              NULL, NULL,
              'Y', NULL,
              DECODE(e.erm_type,
                     'PO', SUBSTR(pl_common.f_get_syspar('RSV_PLT_FLOW_NUM_EXTRA_LP_PO', '1'), 1, 1),
                     'SN', SUBSTR(pl_common.f_get_syspar('RSV_PLT_FLOW_NUM_EXTRA_LP_SN', '0'), 1, 1),
                     'VN', SUBSTR(pl_common.f_get_syspar('RSV_PLT_FLOW_NUM_EXTRA_LP_VN', '0'), 1, 1),
                     NULL)) rsv_plt_flow_num_extra_lp,
       SUBSTR(DECODE(whmove_syspar.value,
              'Y', pl_wh_move.get_new_whse_staging_aisle(whmveloc_hist.newloc),
              NULL), 1, 2) new_warehouse_staging_aisle
  FROM loc l,
       pm m,
       erm e,
       erd d,
       putawaylst p,
       loc_reference lr,
       loc           loc_for_loc_ref,
       --
       -- Warehouse move functionality to get the new warehouse staging aisle
       -- Note that warehouse move will be off 99.99% of the time.
       whmveloc_hist,
       (SELECT MAX(config_flag_val) value     -- inline view
          FROM swms.sys_config                -- Look at the SWMS schema
         WHERE  config_flag_name = 'ENABLE_WAREHOUSE_MOVE') whmove_syspar
       --
 WHERE l.perm              = 'Y'
   AND ((l.uom = 0) OR (l.uom = 2))
   AND l.rank              = 1
   AND l.prod_id           = m.prod_id
   AND l.cust_pref_vendor  = m.cust_pref_vendor
   AND m.prod_id           = d.prod_id
   AND m.cust_pref_vendor  = d.cust_pref_vendor
   AND e.erm_id            = d.erm_id
   AND d.prod_id           = p.prod_id
   AND d.cust_pref_vendor  = p.cust_pref_vendor
   AND d.erm_id            = p.rec_id
   AND lr.bck_logi_loc (+)          = p.dest_loc
   AND loc_for_loc_ref.logi_loc (+) = lr.plogi_loc
   AND whmveloc_hist.oldloc (+)     = l.logi_loc
   AND whmveloc_hist.prod_id (+)    = l.prod_id
UNION
SELECT DISTINCT RPAD(TRUNC(((p.seq_no + 7) / 8), 0), 3)  page,
       p.rec_id                                          erm_id,
       e.erm_type                                        erm_type,
       RPAD(TO_CHAR(e.rec_date, 'MM-DD'), 5)             rec_date,
       RPAD(p.seq_no, 4)                                 seq_no,
       p.prod_id                                         prod_id,
       m.cust_pref_vendor                                cpv,
	   /* 04/01/10 - 12554 - sth0458 - Added for 212 Enh - SCE057 - Begin */
	   /* concatenate prod size unit*/
       LTRIM(RTRIM(m.pack)) || '/' || trim(m.prod_size)||trim(m.prod_size_unit)        pack_size,
	   /* 04/01/10 - 12554 - sth0458 - Added for 212 Enh - SCE057 - End*/
       m.brand                                           brand,
       m.descrip                                         descrip,
       m.mfg_sku                                         mfg_sku,
       LPAD(m.ti, 3)                                     ti,
       RPAD(m.hi, 3)                                     hi,
       p.qty_expected                                    qty,
       p.pallet_id                                       pallet_id,
       DECODE(p.dest_loc, '*', '*',
                          'DDDDDD', 'DDDDDD',
                          SUBSTR(p.dest_loc, 1, 2) || '-'
                          || SUBSTR(p.dest_loc, 3, 2) || '-'
                          || SUBSTR(p.dest_loc, 5, 2))   dest_loc,
       NULL                                              logi_loc,
       p.date_code                                       date_code,
       p.lot_trk                                         lot_trk,
       p.exp_date_trk                                    exp_date_trk,
       p.catch_wt                                        catch_wt,
       p.temp_trk                                        temp_trk,
       p.uom                                             uom,
       m.spc                                             spc,
       d.order_id                                        order_id,
       m.pallet_type                                     pallet_type,
       p.from_splitting_sn_pallet_flag        from_splitting_sn_pallet_flag,
       DECODE(loc_for_loc_ref.perm,
              NULL, NULL,
              'Y', NULL,
              DECODE(e.erm_type,
                     'PO', SUBSTR(pl_common.f_get_syspar('RSV_PLT_FLOW_LP_FMT_OPT_PO', 'A'), 1, 1),
                     'SN', SUBSTR(pl_common.f_get_syspar('RSV_PLT_FLOW_LP_FMT_OPT_SN', 'A'), 1, 1),
                     'VN', SUBSTR(pl_common.f_get_syspar('RSV_PLT_FLOW_LP_FMT_OPT_VN', 'A'), 1, 1),
                     NULL)) rsv_plt_flow_lp_fmt_opt,
       DECODE(loc_for_loc_ref.perm,
              NULL, NULL,
              'Y', NULL,
              DECODE(e.erm_type,
                     'PO', SUBSTR(pl_common.f_get_syspar('RSV_PLT_FLOW_LP_FMT_FLG_CHR_PO', '+'), 1, 1),
                     'SN', SUBSTR(pl_common.f_get_syspar('RSV_PLT_FLOW_LP_FMT_FLG_CHR_SN', '+'), 1, 1),
                     'VN', SUBSTR(pl_common.f_get_syspar('RSV_PLT_FLOW_LP_FMT_FLG_CHR_VN', '+'), 1, 1),
                     NULL)) rsv_plt_flow_lp_fmt_flg_chr,
       DECODE(loc_for_loc_ref.perm,
              NULL, NULL,
              'Y', NULL,
              DECODE(e.erm_type,
                     'PO', SUBSTR(pl_common.f_get_syspar('RSV_PLT_FLOW_NUM_EXTRA_LP_PO', '1'), 1, 1),
                     'SN', SUBSTR(pl_common.f_get_syspar('RSV_PLT_FLOW_NUM_EXTRA_LP_SN', '0'), 1, 1),
                     'VN', SUBSTR(pl_common.f_get_syspar('RSV_PLT_FLOW_NUM_EXTRA_LP_VN', '0'), 1, 1),
                     NULL)) rsv_plt_flow_num_extra_lp,
       NULL new_warehouse_staging_aisle  -- This select is selecting items not slotted therefore
                                         -- the new_whse_staging_aisle will always be null since
                                         -- it cannot yet have a home slot assigned in the
                                         -- new warehouse.
  FROM pm m,
       erm e,
       erd d,
       putawaylst p,
       loc_reference lr,
       loc           loc_for_loc_ref
 WHERE NOT EXISTS (SELECT 'x' 
                     FROM loc
                    WHERE loc.cust_pref_vendor = p.cust_pref_vendor
                      AND loc.prod_id          = p.prod_id)
   AND m.prod_id           = d.prod_id
   AND m.cust_pref_vendor  = d.cust_pref_vendor
   AND e.erm_id            = d.erm_id
   AND d.prod_id           = p.prod_id
   AND d.cust_pref_vendor  = p.cust_pref_vendor
   AND d.erm_id            = p.rec_id
   AND lr.bck_logi_loc (+)          = p.dest_loc
   AND loc_for_loc_ref.logi_loc (+) = lr.plogi_loc
/


--
-- Create public synonym.
--
CREATE OR REPLACE PUBLIC SYNONYM v_rp1rk
   FOR swms.v_rp1rk
/

