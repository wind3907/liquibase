DROP MATERIALIZED VIEW swms.v_avg_bulk_pull
/
CREATE MATERIALIZED VIEW swms.v_avg_bulk_pull
(prod_id, day_of_week, avg_bulk_pull)
REFRESH START WITH SYSDATE
NEXT NEXT_DAY (TRUNC (SYSDATE), 'FRIDAY') + 22/24
AS
SELECT prod_id, TO_CHAR (trans_date, 'd') day_of_week, TRUNC (SUM (qty) / COUNT (DISTINCT (TRUNC (trans_date))))
  FROM trans
 WHERE trans_type = 'PIK'
   AND order_id = 'PP'
 GROUP BY prod_id, TO_CHAR (trans_date, 'd')
/
CREATE OR REPLACE PUBLIC SYNONYM v_avg_bulk_pull FOR swms.v_avg_bulk_pull
/
GRANT SELECT ON v_avg_bulk_pull TO swms_user, swms_viewer
/

