CREATE OR REPLACE TRIGGER swms.trg_ordm_upd
Before INSERT ON swms.ordm
FOR EACH ROW

DECLARE
--------------------------------------------------------------------------
-- Table: ORDM
--    
-- Description: This trigger is added to update trunch number on ORDM 
--              and ROUTE tables for a given customer.
-- Exceptions raised:
-- Modification History:
--    Date                Designer               Comments
--    06/17/2019          Priya Kalidindi
--    --------------------------------------------------------------------
--------------------------------------------------------------------------
 l_sysconfig number;
 l_err_msg  VARCHAR2(500);
 
 
BEGIN

Begin
   SELECT count(*)
               INTO l_sysconfig
               FROM sys_config s
               WHERE config_flag_name = 'AUTO_GEN_CUST_ID'
			   and  nvl(config_flag_val,'N') = :new.cust_id;
Exception when others then
 l_sysconfig := 0;
End;   

if  l_sysconfig >0 then

       :new.truck_no :='AGR';
Begin	   
	   Update ROUTE
	   set truck_no = 'AGR',
     old_truck_no = null,
	   add_on_route_seq = null
	   where route_no =:new.route_no;
	   
	  Exception when others then 
      l_err_msg := 'update on trg_ordm_upd FAILED. ' ||
                    'route_no = [' || :new.route_no || '] ' ||
                    'Order_id = [' || :new.order_id || '] ' ;
       pl_log.ins_msg('FATAL', 'trg_ordm_upd', l_err_msg, SQLCODE, SQLERRM); 
	   
End;	   
	   
	   
End if;	   

  Exception when others then 
      l_err_msg := 'Trigger trg_ordm_upd FAILED. ' ||
                    'route_no = [' || :new.route_no || '] ' ||
                    'Order_id = [' || :new.order_id || '] ' ;
       pl_log.ins_msg('FATAL', 'trg_ordm_upd', l_err_msg, SQLCODE, SQLERRM); 
    
END trg_ordm_upd;
/ 
