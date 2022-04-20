set echo on
create or replace package swms.pl_rf_item_master as
-------------------------------------------------------------------------------
-- Modification History:
--    Date     Designer Comments
--    -------- -------- -------------------------------------------------------
--    09/01/15 bnim1623 package created for sending item level details to RF client
--                      based on the product id sent from RF client 
------------------------------------------------------------------------------

	function GetDefaultItemWeightUnit
	(
		i_rf_log_init_record     	in swms.rf_log_init_record,
		i_prod_id			in varchar2,
		i_cpv                   in varchar2,
		o_defaultweightunit		out varchar2
	) return swms.rf.STATUS;

	
end pl_rf_item_master;
/
show errors;


create or replace package body swms.pl_rf_item_master as

	/*----------------------------------------------------------------*/
	/* Function GetDefaultWeightUnit                                  */
	/*----------------------------------------------------------------*/

	function GetDefaultItemWeightUnit
	(
		i_rf_log_init_record	in swms.rf_log_init_record,
		i_prod_id				in varchar2,
		i_cpv                   in varchar2,
		o_DefaultWeightUnit		out varchar2
	) 
	return swms.rf.STATUS
	IS
		rf_status				swms.rf.STATUS := swms.rf.STATUS_NORMAL;

	BEGIN
		-- Step 1:  Initialize OUT parameters (cannot be null or ora-01405 will result).
		-- This must be done before calling rf.Initialize().

		o_DefaultWeightUnit	:= ' '; 


		-- Step 2:  Call rf.Initialize().  If successful then continue with main business logic.

		rf_status := rf.Initialize(i_rf_log_init_record);
		if rf_status = swms.rf.STATUS_NORMAL then

			begin
				-- main business logic begins...

				-- Step 3:  retrieve scalar field(s)

				SELECT rf.NoNull(p.default_weight_unit)
				INTO o_DefaultWeightUnit						-- output directly into OUT parameter
				FROM pm p
				WHERE
					p.prod_id			= i_prod_id
					AND p.cust_pref_vendor	= i_cpv;

				exception 
					when no_data_found then
						rf_status := rf.STATUS_INV_PRODID;
			end;

		end if;	/* rf.Initialize() returned NORMAL */


		-- Step 4:  Call rf.Complete() with final status

		rf.Complete(rf_status);
		return rf_status;

		exception
			when others then
				rf.LogException();	-- log it
				raise;				-- then throw up to next handler, if any
	end GetDefaultItemWeightUnit;

end pl_rf_item_master;
/
show errors;


alter package swms.pl_rf_item_master compile plsql_code_type = native;

grant execute on swms.pl_rf_item_master to swms_user;
create or replace public synonym pl_rf_item_master for swms.pl_rf_item_master;
