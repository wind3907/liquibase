REM %Z% %W% %G% %I%
REM File : %Z% %W%
REM Usage: sqlplus USR/PWD @%W%
REM             -- Maintenance Log --
REM     19-APR-2004  D# 11555 acphxs: Selecting RDC Address Info for SNs.
REM	24-MAY-2004  D# 11613 prppxx: Add location to the report.
REM	24-NOV-2007  D# 12313 prppxx: Add case_per_carrier & auto_ship_flag.
REM     27-MAR-2008  D# 12359 prppxx: Add master_case in the report.
REM     04/01/10     sth0458  DN12554 - 212 Enh - SCE057 - 
REM                           Add UOM field to SWMS.Expanded the length
REM                           of prod size to accomodate for prod size
REM                           unit.Changed queries to fetch
REM                           prod_size_unit along with prod_size
REM

CREATE OR REPLACE VIEW SWMS.V_RP4RA (ERM_ID,PROD_ID,DEST_LOC,
    CUST_PREF_VENDOR,PALLET_ID,VEND_NAME,VEND_ADDR,STATUS,
    SCHED_DATE,EXP_ARRIV_DATE,ERM_TYPE,CARR_ID,SHIP_ADDR1,
	/* 04/01/10 - 12554 - sth0458 - Added for 212 Enh - SCE057 - Begin */
	/* Declared prod size unit */
    SHIP_ADDR2,SHIP_ADDR3,SHIP_ADDR4,PACK,PROD_SIZE,PROD_SIZE_UNIT,
	/* 04/01/10 - 12554 - sth0458 - Added for 212 Enh - SCE057 - End*/
    BRAND,DESCRIP,MFG_SKU,TI,PALLET_TYPE,HI,CASES,
    SPLITS,CS_CARRIER,SHIP_SPLIT,MASTER_CS) AS 
    SELECT e.erm_id erm_id,
              p.prod_id prod_id,
	      p.dest_loc dest_loc,
              p.cust_pref_vendor cust_pref_vendor,
              p.pallet_id pallet_id,
              e.vend_name vend_name,
              e.vend_addr vend_addr,
              e.status status,
              e.sched_date sched_date,
              e.exp_arriv_date exp_arriv_date,
              e.erm_type erm_type,
              e.carr_id  carr_id,
              e.ship_addr1 ship_addr1,
              e.ship_addr2 ship_addr2,
              e.ship_addr3 ship_addr3,
              e.ship_addr4 ship_addr4,
              m.pack pack,
              m.prod_size prod_size,
			  /* 04/01/10 - 12554 - sth0458 - Added for 212 Enh - SCE057 - Begin */
			  /* Declare prod size unit*/
			  m.prod_size_unit prod_size_unit,
			  /* 04/01/10 - 12554 - sth0458 - Added for 212 Enh - SCE057 - End */
              m.brand brand,
              m.descrip descrip,
              m.mfg_sku mfg_sku,
              m.ti ti,
              m.pallet_type pallet_type,
              m.hi hi,
              decode(p.uom,0,p.qty_expected/nvl(m.spc,1),0) cases,
              decode(p.uom,1,p.qty_expected,0) splits,
              decode(pl_ml_common.f_is_induction_loc(dest_loc),'Y',m.case_qty_per_carrier,0) cs_carrier,
              decode(pl_ml_common.f_is_induction_loc(dest_loc),'Y', nvl(m.auto_ship_flag,'N'), 'N') ship_split,
              decode(pl_ml_common.f_is_induction_loc(dest_loc),'Y',
                                        decode(sign(m.master_case - 1), 1, 'UNPACK', ' '), ' ') master_cs
         FROM  putawaylst p, pm m, erm e
         WHERE 1=1 AND p.prod_id = m.prod_id
           AND p.cust_pref_vendor = m.cust_pref_vendor
           AND p.rec_id = e.erm_id
           AND e.erm_type <> 'CM'
           AND e.erm_type <> 'SN'
           AND e.status not in ('VCH')
           AND substr(e.po,1,1) <> 'S'
           AND substr(e.po,1,1) <> 'D'
    UNION
    SELECT e.erm_id erm_id,
              p.prod_id prod_id,
	      p.dest_loc dest_loc,
              p.cust_pref_vendor cust_pref_vendor,
              p.pallet_id pallet_id,
              e.vend_name vend_name,
              e.vend_addr vend_addr,
              e.status status,
              e.sched_date sched_date,
              e.exp_arriv_date exp_arriv_date,
              e.erm_type erm_type,
              e.carr_id  carr_id,
              r.name ship_addr1,
              r.address1 ship_addr2,
              r.address2 ship_addr3,
              r.address3 ship_addr4,
              m.pack pack,
              m.prod_size prod_size,
			  /* 04/01/10 - 12554 - sth0458 - Added for 212 Enh - SCE057 - Begin */
			  /*  Declare prod size unit*/
			  m.prod_size_unit prod_size_unit,
			  /* 04/01/10 - 12554 - sth0458 - Added for 212 Enh - SCE057 - End */
              m.brand brand,
              m.descrip descrip,
              m.mfg_sku mfg_sku,
              m.ti ti,
              m.pallet_type pallet_type,
              m.hi hi,
              decode(p.uom,0,p.qty_expected/nvl(m.spc,1),0) cases,
              decode(p.uom,1,p.qty_expected,0) splits,
              decode(pl_ml_common.f_is_induction_loc(dest_loc),'Y',m.case_qty_per_carrier,0) cs_carrier,
              decode(pl_ml_common.f_is_induction_loc(dest_loc),'Y', nvl(m.auto_ship_flag,'N'), 'N') ship_split,
              decode(pl_ml_common.f_is_induction_loc(dest_loc),'Y',
                                        decode(sign(m.master_case - 1), 1, 'UNPACK', ' '), ' ') master_cs
         FROM  putawaylst p, pm m, erm e ,sn_header s,  rdc_address r
         WHERE 1=1 AND p.prod_id = m.prod_id
           AND p.cust_pref_vendor = m.cust_pref_vendor
           AND p.rec_id = e.erm_id
           AND e.erm_id = s.sn_no
           AND s.rdc_nbr = r.rdc_nbr
           AND e.erm_type = 'SN'
           AND e.status not in ('VCH')
           AND substr(e.po,1,1) <> 'S'
           AND substr(e.po,1,1) <> 'D';
		   
CREATE OR REPLACE PUBLIC SYNONYM V_RP4RA FOR SWMS.V_RP4RA;

GRANT DELETE, INSERT, SELECT, UPDATE ON SWMS.V_RP4RA TO SWMS_USER;

GRANT SELECT ON SWMS.V_RP4RA TO SWMS_VIEWER;




