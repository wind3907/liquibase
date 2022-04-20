CREATE OR REPLACE VIEW swms.v_available_inv AS
SELECT pm.prod_id, pm.cust_pref_vendor, NVL(TRUNC(SUM(i.qoh/pm.spc)),0) avl_cases, NVL(MOD(SUM(i.qoh),MIN(pm.spc)),0) avl_splits
  FROM inv i, pm
 WHERE i.prod_id(+) = pm.prod_id
   AND i.cust_pref_vendor(+) = pm.cust_pref_vendor
   AND i.status(+) = 'AVL'
 GROUP BY pm.prod_id, pm.cust_pref_vendor;

CREATE OR REPLACE PUBLIC SYNONYM v_available_inv FOR swms.v_available_inv;

GRANT SELECT ON v_available_inv TO SWMS_VIEWER;
GRANT ALL ON v_available_inv TO SWMS_USER;
