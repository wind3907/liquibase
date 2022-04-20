-- View to filter Load# for which Food Safety temperature is 
-- not collected for even a PO# in the load

CREATE OR REPLACE FORCE VIEW SWMS.V_RP1SPA ("ERM_ID","LOAD_NO","STATUS","AREA","ERM_TYPE","REC_DATE")
AS
SELECT DISTINCT e.erm_id,DECODE(e.load_no,NULL,'No Load No',e.load_no),e.status,
    p.area,e.erm_type,e.rec_date 
    FROM erm e,erd d,pm p 
    WHERE e.erm_id=d.erm_id 
    AND d.prod_id =p.prod_id 
    AND p.area ='C' 
	AND e.food_safety_print_flag='Y'
    AND TRUNC(rec_date)>=(SELECT TO_DATE(TRIM(config_flag_val),'DD-MON-YY') from sys_config WHERE config_flag_name='FOOD_SAFETY_START_DATE') 
	AND NOT EXISTS (SELECT e.load_no FROM food_safety_inbound FS where FS.load_no = E.load_no)
	AND NOT EXISTS (SELECT e.erm_id FROM food_safety_inbound FS where FS.erm_id = E.erm_id)
	AND e.status NOT IN('NEW','SCH')
	AND e.erm_type IN('PO','VN','SN')
	ORDER BY e.rec_date asc,e.erm_id;

--
-- Create public synonym.
--

CREATE OR REPLACE PUBLIC SYNONYM V_RP1SPA FOR swms.V_RP1SPA;

--
--Grant permissions
--

GRANT ALL ON SWMS.V_RP1SPA TO SWMS_USER;


/
