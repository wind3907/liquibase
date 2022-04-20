/****************************************************************************
** Date:       11-NOV-2019
** File:       calc_avw_client_obj_ddl.sql
**
**             Script for creating objects for calc_avw
**            
**    - SCRIPTS
**
**    Modification History:
**    Date       Designer Comments
**    --------   -------- ---------------------------------------------------
**    22/11/19   1072666  calc_avw_client_obj_ddl.sql
**                  
****************************************************************************/

/********    Server Objects  ************/

create or replace TYPE calc_avw_client_obj FORCE AS OBJECT 
(
    erm_id			 varchar2(12),	
    prod_id			 varchar2(7),	
    cust_pref_vendor varchar2(6),	
    total_cases		 varchar2(7),	
    total_splits	 varchar2(7),	
    total_wt		 varchar2(9),	
    func1_option	 varchar2(1)	
);
/
grant execute on calc_avw_client_obj  to swms_user;
