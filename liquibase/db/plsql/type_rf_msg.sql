create or replace type swms.rf_msg_record force as object(
	sender			varchar2(30),		-- RF_MSG.add_user
	when_queued		varchar2(19),		-- RF_MSG.add_date, as yyyy-mm-dd hh:mm:ss
	msg_text		varchar2(256)		-- RF_MSG.msg_text
);
/

create or replace type swms.rf_msg_table force
	as table of swms.rf_msg_record;
/

create or replace type swms.rf_msg_obj force as object(
	msg_table	swms.rf_msg_table
);
/

grant execute on swms.rf_msg_obj to swms_user;
