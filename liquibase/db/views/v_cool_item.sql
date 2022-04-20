CREATE OR REPLACE VIEW swms.v_cool_item
	(prod_id, cust_pref_vendor, country_of_origin, country_name, wild, farm)
AS
SELECT	prod_id, cust_pref_vendor, ci.country_of_origin, coc.country_name,
	MAX (DECODE (wild_farm, 'W', 'Y', NULL)) WILD,
	MAX (DECODE (wild_farm, 'F', 'Y', NULL)) FARM
  FROM	coo_codes coc, cool_item ci
 WHERE	coc.country_of_origin = ci.country_of_origin
 GROUP	BY prod_id, cust_pref_vendor, ci.country_of_origin, coc.country_name
/
