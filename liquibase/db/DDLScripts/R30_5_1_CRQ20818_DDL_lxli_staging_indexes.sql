
CREATE INDEX swms.lxli_staging_hdr_out_nk1
   ON swms.lxli_staging_hdr_out(file_name)
   STORAGE (INITIAL 256K NEXT 64K PCTINCREASE 0)
   PCTFREE 1
TABLESPACE swms_its1
/

CREATE INDEX swms.lxli_staging_sl_out_nk1
   ON swms.lxli_staging_sl_out (batch_no, batch_date, float_no, float_detail_seq_no)
   STORAGE (INITIAL 1M NEXT 64K PCTINCREASE 0)
   PCTFREE 1
TABLESPACE swms_its1
/

