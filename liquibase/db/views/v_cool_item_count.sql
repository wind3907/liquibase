
rem *****************************************************************
rem * This view enables sorting of prod_id/coo codes so that SOS 
rem * can provide users with a list ranked by popularity of data
rem * to reduce scrolling thru the whole list to select coo/w,f codes
rem * For example, US is alphabetically near the bottom and thus 
rem * requires many keystrokes to reach.
rem * Usage: select ...  
rem *        from v_cool_item_count i
rem *        order by prod_id, count desc, country_of_origin
rem *****************************************************************

CREATE OR REPLACE VIEW swms.v_cool_item_count
	(prod_id, cust_pref_vendor, country_of_origin, country_name, wild, farm, count)
AS
SELECT	ci.prod_id, ci.cust_pref_vendor, ci.country_of_origin, coc.country_name,
	MAX (DECODE (ci.wild_farm, 'W', 'Y', NULL)) WILD,
	MAX (DECODE (ci.wild_farm, 'F', 'Y', NULL)) FARM,
        count(*)
  FROM	coo_codes coc, cool_item ci, trans t            
 WHERE	coc.country_of_origin = ci.country_of_origin
 AND    ci.prod_id = t.prod_id(+)
 AND    ci.cust_pref_vendor = t.cust_pref_vendor(+)
 AND    ci.country_of_origin = t.country_of_origin(+)
 AND    t.trans_type(+) = 'PAM'
 GROUP	BY ci.prod_id, ci.cust_pref_vendor, ci.country_of_origin, coc.country_name
/

