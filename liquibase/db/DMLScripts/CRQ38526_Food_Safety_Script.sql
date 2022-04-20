DECLARE
CURSOR c_load IS
SELECT DISTINCT e.load_no
  FROM erm e,
       erd d,
       pm p
 WHERE e.erm_type in ('PO','SN')
   AND e.status IN ('SCH', 'NEW')
   AND e.erm_id = d.erm_id
   AND d.prod_id = p.prod_id
   AND p.area = 'C'
   AND e.load_no IS NOT NULL;

BEGIN

/* Update PO with Status=NEW||SCH and load_no NULL */

UPDATE erm 
   SET food_safety_print_flag = 'Y' 
 WHERE status in ('NEW', 'SCH') 
   AND load_no IS NULL 
   AND erm_id IN (SELECT distinct e.erm_id 
                    FROM erd d, 
                         erm e, 
                         pm p 
                   WHERE e.erm_type in ('PO','SN')
		     AND e.erm_id = d.erm_id 
                     AND d.prod_id = p.prod_id 
                     AND p.area = 'C' 
                     AND NOT EXISTS (SELECT 'x' 
                                       FROM food_safety_inbound i 
                                      WHERE i.erm_id = e.erm_id));

/* Update one cooler PO per load with Status=SCH. LOAD_NO <> NULL */

FOR c1 IN c_load LOOP
  BEGIN
        UPDATE erm
        SET food_safety_print_flag='Y'
        WHERE status = 'SCH'
        AND load_no=c1.load_no
        AND erm_id IN(
                SELECT distinct e.erm_id
                FROM erd d,erm e,pm p
                WHERE e.erm_type in ('PO','SN')
		AND e.load_no = c1.load_no
                AND e.erm_id=d.erm_id
                AND d.prod_id=p.prod_id
                AND p.area='C'
                AND NOT EXISTS (SELECT 'x' FROM food_safety_inbound i WHERE i.erm_id = e.erm_id)
                AND NOT EXISTS (SELECT 'x' FROM erm WHERE load_no=c1.load_no AND food_safety_print_flag ='Y')
                AND ROWNUM =1);
  END;
END LOOP;
END;
/
