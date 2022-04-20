set echo off
create or replace package swms.pl_mx_gen_label as
	function ZplPickLabel
	(
		printLogo		in boolean,
		doFloatShading	in boolean,
		isShort			in boolean,								-- *SHORT*
		isMulti			in boolean,								-- *MULTI*
		floatChar		in v_sos_batch_info.float_char%type,	-- R/S/T/U
		floatZone		in v_sos_batch_info.zone%type,
		numFloats		in sos_batch.no_of_floats%type,			-- not printed; how many boxes to draw
		custName		in v_sos_batch_info.cust_name%type,
		custNumber		in v_sos_batch_info.cust_id%type,
		itemDesc		in v_sos_batch_info.item_descrip%type,
		pack			in v_sos_batch_info.pack%type,			-- pack/size__UOM
		floatNum		in v_sos_batch_info.float_seq%type,
		dockDoor		in v_sos_batch_info.door_no%type,
		slotNo			in v_sos_batch_info.src_loc%type,
		userId			in batch.user_id%type,					-- probably null for Symbotic labels
		qtySec			in v_sos_batch_info.bc_st_piece_seq%type,
		totQty			in v_sos_batch_info.qty_alloc%type,
		invoice			in v_sos_batch_info.order_id%type,
		batch			in v_sos_batch_info.batch_no%type,
		truck			in v_sos_batch_info.truck_no%type,
		stop			in v_sos_batch_info.stop_no%type,		-- NN or NN.nn
		caseBarCode		in varchar2,
		item			in v_sos_batch_info.prod_id%type,
		price			in v_sos_batch_info.price%type,
		custPo			in v_sos_batch_info.cust_po%type,
		invoiceDate		in v_sos_batch_info.ship_date%type
	) return clob;

	function ZplReplenLabel
	(
		caseBarCode		in varchar2,				-- concat of caseNo and 3 digit caseSeq
		destLoc			in inv.plogi_loc%type,
		lp				in inv.logi_loc%type,
		itemNum			in pm.prod_id%type,
		descrip			in pm.descrip%type,
		pack			in pm.pack%type,
		prod_size		in pm.prod_size%type,
		brand			in pm.brand%type,
		type			in replenlst.type%type
	)
	return clob;

	function ZplEscStr
	(
		dataIn			in string,
		hexIndicator	in string,	-- normally should be '_'
		escBs			in boolean default false
	)
	return string;

end pl_mx_gen_label;
/
show errors;


create or replace package body swms.pl_mx_gen_label as

	/*----------------------------------------------------------------*/
	/* Function ZplPickLabel                                          */
	/*----------------------------------------------------------------*/

	function ZplPickLabel
	(
		printLogo		in boolean,
		doFloatShading	in boolean,
		isShort			in boolean,								-- *SHORT*
		isMulti			in boolean,								-- *MULTI*
		floatChar		in v_sos_batch_info.float_char%type,	-- R/S/T/U
		floatZone		in v_sos_batch_info.zone%type,
		numFloats		in sos_batch.no_of_floats%type,			-- not printed; how many boxes to draw
		custName		in v_sos_batch_info.cust_name%type,
		custNumber		in v_sos_batch_info.cust_id%type,
		itemDesc		in v_sos_batch_info.item_descrip%type,
		pack			in v_sos_batch_info.pack%type,			-- pack/size__UOM
		floatNum		in v_sos_batch_info.float_seq%type,
		dockDoor		in v_sos_batch_info.door_no%type,
		slotNo			in v_sos_batch_info.src_loc%type,
		userId			in batch.user_id%type,					-- probably null for Symbotic labels
		qtySec			in v_sos_batch_info.bc_st_piece_seq%type,
		totQty			in v_sos_batch_info.qty_alloc%type,
		invoice			in v_sos_batch_info.order_id%type,
		batch			in v_sos_batch_info.batch_no%type,
		truck			in v_sos_batch_info.truck_no%type,
		stop			in v_sos_batch_info.stop_no%type,		-- NN or NN.nn
		caseBarCode		in varchar2,
		item			in v_sos_batch_info.prod_id%type,
		price			in v_sos_batch_info.price%type,
		custPo			in v_sos_batch_info.cust_po%type,
		invoiceDate		in v_sos_batch_info.ship_date%type
	)
	return clob
	IS
		result			clob := NULL;
		CRLF			constant string(2) := utl_tcp.CRLF;

		stop_integer	v_sos_batch_info.stop_no%type;
		stop_fraction	v_sos_batch_info.stop_no%type;

	BEGIN
		-- Notes:  Each emitted line of output MUST end with a \r\n (CRLF) sequence,
		-- that is, DOS-style newline sequence.


		-- Emit initial sequences

		result := result	|| 
			'^XA'			|| CRLF ||
			'^PON'			|| CRLF ||	-- Don't invert page orientation 180 degrees
			'^CI13'			|| CRLF;	-- Change to Zebra Code Page 850; allows printing of backslash
										--     Note, backslashes must be escaped as double backslashes
										--     for downloaded fonts

		-- Optionally Emit *Multi*

		if isMulti then
			result := result				|| 
				'^FT245,177^A0N,19,24^FD'	||
				'*MULTI*'					||
				'^FS'						|| CRLF;
		end if;


		-- Optionally Emit *Short*

		if isShort then
			result := result				|| 
				'^FT243,195^A0N,19,24^FD'	||
				'*SHORT*'					||
				'^FS'						|| CRLF;
		end if;


		-- Emit floatChar-floatZone

		result := result || 
			'^FB577,1,0,R,0'				|| CRLF ||
			'^FT0,40^A@N,45,45,TT0003M_'	|| CRLF ||
			'^FH_^FD'						|| CRLF ||
			ZplEscStr(floatChar,'_',true)	|| CRLF ||
			'-'								|| CRLF ||
			ZplEscStr(floatZone,'_',true)	||
			'^FS'							|| CRLF;


		-- Optionally emit company logo graphic

		if printLogo then
			result := result							||
				'^FO390,20'								|| CRLF ||
				'^GFA,726,726,11,' 						|| 
					'00000000000000000000000000000000'	||
					'00000000000007FE0000000000000000'	||
					'001FFE0000000000000000003FFE0000'	||
					'000000000000007FFE00000000000000'	||
					'00007E000000000000000000007C0000'	||
					'00000000000000007C04000000000000'	||
					'0000007C03C00F87F80FF01FC0407C01'	||
					'E01F3FF83FF07FF0807F00F81F7FF87F'	||
					'F1FFF8007FC0FC1E7C18FF31F9FC003F'	||
					'F07E3E7C00FC03F07E000FFC3E3E7C01'	||
					'F803E03E0007FE3E3C7E01F007E03E00'	||
					'01FF1E7C7FC1F007C01F00003F1E7C3F'	||
					'F1F007C01F00001F8E780FF9F007C01F'	||
					'00001F8EF803F9F007C01F00001F8CF0'	||
					'00F9F007C03E00001F05F000FDF807E0'	||
					'3E00703F01F000F8FC03E07E007FFF01'	||
					'E071F8FF31FDFC007FFE03E07FF87FF1'	||
					'FFF8007FFC03C07FF03FF07FF0003FF0'	||
					'03C0FF800FF03FE000000007C0000000'	||
					'00000000000007800000000000000000'	||
					'000F800000000000000000000F000000'	||
					'000000000000000F0000000000000000'	||
					'00001F0000000000000000'			|| CRLF;
			end if;


		-- Optionally emit float shading/graphic boxes

		if doFloatShading then
			if numFloats > 0 then
				result := result || '^FT424,20^GB13,10,1^FS' || CRLF;
			end if;
			if numFloats > 1 then
				result := result || '^FT435,20^GB13,10,1^FS' || CRLF;
			end if;
			if numFloats > 2 then
				result := result || '^FT448,20^GB13,10,1^FS' || CRLF;
			end if;
			if numFloats > 3 then
				result := result || '^FT460,20^GB13,10,1^FS' || CRLF;
			end if;


			if floatChar = 'R' then
				result := result || '^FT425,17^AAN,9,9,^FH_^FD_DB   ^FS' || CRLF;
			elsif floatChar = 'S' then
				result := result || '^FT425,17^AAN,9,9,^FH_^FD _DB  ^FS' || CRLF;
			elsif floatChar = 'T' then
				result := result || '^FT425,17^AAN,9,9,^FH_^FD  _DB ^FS' || CRLF;
			elsif floatChar = 'U' then
				result := result || '^FT425,17^AAN,9,9,^FH_^FD   _DB^FS' || CRLF;
			end if;
		end if;


		-- Emit custName	@@ need to fixup for special chars

		result := result				|| 
			'^FT0,95^ADN,1,1^FH_^FD'	||
			ZplEscStr(custName,'_')		||
			'^FS'						|| CRLF;


		-- Emit custNumber

		result := result				||
			'^FT300,95^ADN,1,1^FH_^FD'	||
			ZplEscStr(custNumber,'_')	||
			'^FS'						|| CRLF;


		-- Emit itemDesc

		result := result				||
			'^FT0,115^ADN,1,1^FH_^FD'	||
			ZplEscStr(itemDesc,'_')		||
			'^FS'						|| CRLF;


		-- Emit pack (which is actually "Pack/Size  UOM")

		result := result				||
			'^FT0,135^ADN,1,1^FH_^FD'	||
			ZplEscStr(pack,'_')			||
			'^FS'						|| CRLF;


		-- Emit floatNum-DockDoor
	
		result := result				||
			'^FB577,1,0,R,0'			|| CRLF ||
			'^FT0,60^ADN,1,1'			|| CRLF ||
			'^FH_^FD'					|| CRLF ||
			ZplEscStr(floatNum,'_')		|| CRLF ||
			'-'							|| CRLF ||
			ZplEscStr(dockDoor,'_')		|| 
			'^FS'						|| CRLF;


		-- Emit slotNo (Note, using the right-justify option on FT requires minimum firmware version)

		result := result				||
			'^FB577,1,0,R,0'			|| CRLF || 
			'^FT0,80^ADN,1,1^FH_^FD'	||
			ZplEscStr(slotNo,'_')		||
			'^FS'						|| CRLF;


		-- Emit userId

		result := result				||
			'^FT0,150^AAN,13,7^FH_^FD'	|| 
			ZplEscStr(userId,'_')		||
			'^FS'						|| CRLF;


		-- Emit qtySeq of totalQty (Note spaces before and after 'of')

		result := result							||
			'^FB95,1,0,R,0'							|| CRLF ||
			'^FT0,195^A@N,45,45,TT0003M_^FH_^FD'	||
			ZplEscStr(qtySec,'_',true)				||
			'^FS'									|| CRLF ||
			'^FT95,170^AAN,1,1^FH_^FD'				||
			' of '									||
			'^FS'									|| CRLF ||
			'^FT115,195^A@N,45,45,TT0003M_^FH_^FD'	||
			ZplEscStr(totQty,'_',true)				||
			'^FS'									|| CRLF;


		-- Emit invoice

		result := result				||
			'^FT180,135^ADN,1,1^FH_^FD'	||
			ZplEscStr(invoice,'_')		||
			'^FS'						|| CRLF;


		-- Emit batch

		result := result				||
			'^FT300,135^ADN,1,1^FH_^FD'	|| 
			ZplEscStr(batch,'_')		||
			'^FS'						|| CRLF;


		-- Emit truck

		result := result							||
			'^FB577,1,0,R,0'						|| CRLF ||
			'^FT0,115^A@N,45,45,TT0003M_^FH_^FD'	||
			ZplEscStr(truck,'_',true)				||
			'^FS'									|| CRLF;


		-- Emit stop, and shading/rectangle if it has fractional component

		stop_integer := trunc(stop,0);
		stop_fraction := stop - stop_integer;

		if stop_fraction <> 0 then		-- emit stop w/o decimal point but with shading/rectangle
			result := result								||
				'^FO477,125,0,R,0'							|| CRLF ||
				'^GB 99,80,4,B,0^FS'						|| CRLF ||
				'^FB577,1,0,R,0'							|| CRLF ||
				'^FT0,195^A@N,90,90,TT0003M_^FH_^FD'		||
				stop_integer								|| 
				ltrim(to_char(stop_fraction * 100,'00'))	||
				'^FS'										|| CRLF;

		else							-- emit stop w/o decimal point, no shading/rectangle
			result := result								||
				'^FB577,1,0,R,0'							|| CRLF ||
				'^FT0,195^A@N,90,90,TT0003M_^FH_^FD'		||
				stop_integer								||
				'^FS'										|| CRLF;
		end if;


		-- Emit caseBarCode

		result := result					||
			'^FO15,0'						|| CRLF ||
			'^BY3,3.0,70'					|| CRLF ||
			'^BCN,70,N,N,N,A'				|| CRLF ||
			'^FH_^FD'						|| 
			ZplEscStr(caseBarCode,'_')		||
			'^FS'							|| CRLF;


		-- Emit item number

		result := result				||
			'^FT370,115^ADN,1,1^FH_^FD'	||
			ZplEscStr(item,'_')			||
			'^FS'						|| CRLF;


		-- Emit price (Note, in same position as custPo; caller should supply only one or the other)

		result := result				||
			'^FT95,155^ADN,1,1^FH_^FD'	||
			ZplEscStr(price,'_')		||
			'^FS'						|| CRLF;


		-- Emit custPo (Note in the same position as price; caller should supply only one or the other)

		result := result				||
			'^FT95,155^ADN,1,1^FH_^FD'	||
			ZplEscStr(custPo,'_')		||
			'^FS'						|| CRLF;


		-- Emit invoiceDate

		result := result					||
			'^FT300,155^ADN,1,1^FH_^FD'		||
			to_char(invoiceDate,'MMDDYY')	||
			'^FS'							|| CRLF;


		-- Emit ending sequence

		result := result			||
			'^XZ'					|| CRLF;

		return result;
	end ZplPickLabel;


	/*----------------------------------------------------------------*/
	/* Function ZplReplenLabel                                        */
	/*----------------------------------------------------------------*/

	function ZplReplenLabel
	(
		caseBarCode		in varchar2,				-- concat of caseNo and 3 digit caseSeq
		destLoc			in inv.plogi_loc%type,
		lp				in inv.logi_loc%type,
		itemNum			in pm.prod_id%type,
		descrip			in pm.descrip%type,
		pack			in pm.pack%type,
		prod_size		in pm.prod_size%type,
		brand			in pm.brand%type,
		type			in replenlst.type%type
	)
	return clob
	IS
		result			clob := NULL;
		CRLF			constant string(2) := utl_tcp.CRLF;

	BEGIN
		-- Notes:  Each emitted line of output MUST end with a \r\n (CRLF) sequence,
		-- that is, DOS-style newline sequence.


		-- Emit initial sequences

		result := result	|| 
			'^XA'			|| CRLF ||
			'^PON'			|| CRLF ||	-- Don't invert page orientation 180 degrees
			'^CI13'			|| CRLF;	-- Change to Zebra Code Page 850; allows printing of backslash
										--     Note, backslashes must be escaped as double backslashes
										--     for downloaded fonts


		-- Emit caseBarCode

		result := result					||
			'^FO15,0'						|| CRLF ||
			'^AAN,13,7'						|| CRLF ||
			'^BY3,3.0,70'					|| CRLF ||
			'^BCN,70,Y,N,N,A'				|| CRLF ||
			'^FH_^FD'						||
			ZplEscStr(caseBarCode,'_')		||
			'^FS'							|| CRLF;


		-- Emit LPN

		result := result					||
			'^FT0,110^ADN,1,1^FH_^FD'		||
			'   LP: '						||
			ZplEscStr(lp,'_')				||
			'^FS'							|| CRLF;


		-- Emit Description

		result := result					||
			'^FT0,130^ADN,1,1^FH_^FD'		||
			' Desc: '						||
			ZplEscStr(descrip,'_')			||
			'^FS'							|| CRLF;


		-- Emit Item

		result := result					||
			'^FT0,150^ADN,1,1^FH_^FD'		||
			' Item: '						||
			ZplEscStr(itemNum,'_')			||
			'^FS'							|| CRLF;
		
		
		-- Emit Pk/Sz

		result := result					||
			'^FT0,170^ADN,1,1^FH_^FD'		||
			'Pk/Sz: '						||
			ZplEscStr(pack,'_')				||
			'/'								||
			ZplEscStr(prod_size,'_')		||
			'^FS'							|| CRLF;
		

		-- Emit Brand

		result := result					||
			'^FT0,190^ADN,1,1^FH_^FD'		||
			'Brand: '						||
			ZplEscStr(brand,'_')			||
			'^FS'							|| CRLF;


		-- Emit destLoc, inverse printed in a shaded box

		result := result						||
			'^FO575,138,1^GB220,60,60,,1^FS'	|| CRLF ||
			'^FT565,190,1^ADN,60,22^FH_^FR^FD'	||
			ZplEscStr(destLoc,'_')				||
			'^FS'								|| CRLF;


		-- Emit replen type

		result := result					||
			'^FO575,10,1,^ADN,60,22^FH_^FD'	||
			ZplEscStr(type,'_')				||
			'^FS'							|| CRLF;

		-- Emit ending sequence

		result := result			||
			'^XZ'					|| CRLF;

		return result;
	end ZplReplenLabel;


	/*----------------------------------------------------------------*/
	/* Function ZplEscStr                                             */
	/*                                                                */
	/* This is a private function to 'escape' certain characters for  */
	/* output as ZPL printer data.                                    */
	/*                                                                */
	/* If escBs is true, then each backslash is replaced by a double  */
	/* backslash (\\).  Generally speaking, if ^A is used to specify  */
	/* the font then FALSE should be supplied for escBs.  If ^A@ is   */
	/* used then TRUE should be specified.                            */
	/*                                                                */
	/* This routine requires that each ^FD, ^FV, and ^SN command used */
	/* to print the data returned by this function to be preceded by  */
	/* a ^FH command, specifying hexIndicator as its option value.    */
	/*                                                                */
	/* Special characters caret ^ and tilde ~ are replace by their    */
	/* hex equivalents, as is the supplied hexIndicator character.    */
	/*----------------------------------------------------------------*/

	function ZplEscStr
	(
		dataIn			in string,
		hexIndicator	in string,	-- normally should be '_'
		escBs			in boolean default false

	)
	return string
	IS
		dataOut				string(32767);

		tilde_hex			constant string(2) := '7E';
		caret_hex			constant string(2) := '5E';
		backslash_hex		constant string(2) := '5C';
		hexIndicator_hex	constant string(2) := RawToHex(utl_raw.Cast_To_Raw(hexIndicator));

	BEGIN
		dataOut := dataIn;

		if escBs then
			dataOut := replace(dataOut,'\','\\');
		end if;

		dataOut := replace(dataOut,hexIndicator,	hexIndicator || hexIndicator_hex); -- must be 1st
		dataOut := replace(dataOut,'^',				hexIndicator || caret_hex);
		dataOut := replace(dataOut,'~',				hexIndicator || tilde_hex);

		return dataOut;

	end ZplEscStr;

end pl_mx_gen_label;
/
show errors;


alter package swms.pl_mx_gen_label compile plsql_code_type = native;

grant execute on swms.pl_mx_gen_label to swms_user;
create or replace public synonym pl_mx_gen_label for swms.pl_mx_gen_label;
