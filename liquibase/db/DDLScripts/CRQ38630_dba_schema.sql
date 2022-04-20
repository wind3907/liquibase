DROP TRIGGER swms.trg_ins_planned_order_dtl
/
DROP INDEX swms.trans_bulk_pull_ind
/
CREATE INDEX trans_bulk_pull_ind ON swms.trans (
	DECODE (order_id, 'PP', trans_type, DECODE (trans_type, 'COG', trans_type, NULL)),
	DECODE (order_id, 'PP', order_id, DECODE (trans_type, 'COG', order_id, NULL)),
	DECODE (order_id, 'PP', trans_date, DECODE (trans_type, 'COG', trans_date, NULL)),
	DECODE (order_id, 'PP', prod_id, DECODE (trans_type, 'COG', prod_id, NULL)),
	DECODE (order_id, 'PP', qty, DECODE (trans_type, 'COG', qty, NULL)))
STORAGE (
	INITIAL 1M
	NEXT 512K
	PCTINCREASE 0)
/
DROP MATERIALIZED VIEW swms.v_avg_bulk_pull
/
