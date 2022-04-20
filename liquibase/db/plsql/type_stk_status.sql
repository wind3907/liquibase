create or replace type swms.stk_status_result_record force as object(
	pallet_id	varchar2(18),			-- INV.logi_loc
	qoh			number(7),				-- INV.qoh
	spc			number(7),				-- PM.spc
	plogi_loc	varchar2(10),			-- INV.plogi_loc
	constructor function stk_status_result_record(
        pallet_id varchar2,
        qoh number,
        spc number,
        plogi_loc varchar2
        ) return self as result
);
/

create or replace type body swms.stk_status_result_record as
    constructor function stk_status_result_record(
        pallet_id varchar2,
        qoh number,
        spc number,
        plogi_loc varchar2
        ) return self as result
        IS
        begin
            SELF.pallet_id := pallet_id;
            SELF.qoh := NVL(qoh, 0);
            SELF.spc := NVL(spc, 0);
            SELF.plogi_loc := plogi_loc;
            RETURN;
        end;
end ;
/

create or replace type swms.stk_status_result_table force
	as table of swms.stk_status_result_record;
/

create or replace type swms.stk_status_result_obj force as object(
	result_table	swms.stk_status_result_table
);
/

grant execute on swms.stk_status_result_obj to swms_user;
