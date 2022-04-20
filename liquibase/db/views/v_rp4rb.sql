/* Formatted on 4/10/2015 9:43:13 PM (QP5 v5.163.1008.3004) */
CREATE OR REPLACE FORCE VIEW SWMS.V_RP4RB
(
   ERM_ID,
   PROD_ID,
   WEIGHT,
   G_WEIGHT
)
AS
   SELECT DISTINCT e.erm_id,
                   e.prod_id,
                   t.total_weight,
                   p.weight
     FROM erd e, tmp_weight t, pm p
    WHERE     t.prod_id = p.prod_id
          AND t.prod_id = e.prod_id
          AND e.prod_id = p.prod_id
   UNION
   SELECT DISTINCT e.erm_id,
                   e.prod_id,
                   e.weight,
                   p.weight
     FROM erd e, pm p
    WHERE     e.prod_id = p.prod_id
          AND NOT EXISTS
                 (SELECT 'x'
                    FROM tmp_weight w
                   WHERE w.prod_id = p.prod_id);
             

CREATE OR REPLACE PUBLIC SYNONYM V_RP4RB FOR SWMS.V_RP4RB;

GRANT DELETE, INSERT, SELECT, UPDATE ON SWMS.V_RP4RB TO SWMS_USER;

GRANT SELECT ON SWMS.V_RP4RB TO SWMS_VIEWER;