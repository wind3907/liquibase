create or replace type swms.rf_log_init_record force as object(
	device			varchar2(20),
	application		varchar2(10),
	mac_address		varchar2(17),	-- eg. 00-15-70-f3-17-8f
	ap_mac_address	varchar2(17),
	culture_name	varchar2(12),	-- in Microsoft .Net format, eg. "fr-CA", "es-ES_tradnl", or blank */
	sequence		number(9),		-- client transaction sequence number
	resending		varchar2(1)		-- Y or N
);
/
show errors

grant execute on swms.rf_log_init_record to swms_user;
