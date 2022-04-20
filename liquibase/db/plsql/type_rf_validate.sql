/****************************************************************************
** Date:       25-NOV-2019
** File:       type_rf_validate.sql
**
**             Script for creating objects for Validate
**
****************************************************************************/

/********    Server Objects  ************/

Create or Replace TYPE validate_client_obj FORCE AS OBJECT (
		
		pallet_id		 VARCHAR2(18),	
		expr_date		 VARCHAR2(6),	
		mfg_date		 VARCHAR2(6),	
        prod_id			 VARCHAR2(9),	
        cust_pref_vendor VARCHAR2(10),	
        req_option		 VARCHAR2(1)
);
/
grant execute on validate_client_obj  to swms_user;
/

