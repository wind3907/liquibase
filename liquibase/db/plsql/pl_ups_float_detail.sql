CREATE OR REPLACE PACKAGE      pl_ups_float_detail
IS
/*===========================================================================================================
-- Package
-- pl_ups_float_detail
--
-- Description
--   This package is called by SWMS.
--   This package is to send float detail info to UPS
--
-- Modification History
--
-- Date                User                  Version            Defect  Comment
-- 04/23/19        mcha1213                   1.0              Initial Creation
-- this version is to get status N, take out proc generate_xml, change xx_utl_http to ups_utl_http,
-- change ups_float_del_xmlgen to ups_float_det_xml
-- add seq_no
-- 5/10/19 Gary said the XML <ROUTES> will need to be between the processData Elements
-- 5/13/19 -- set the conversion of special xml characters to false 
--   DBMS_XMLGEN.setConvertSpecialChars(queryCtx, false); 
--   this will not convert ampersand and ' but response from ups is 500
--  5/15/19 modify the query to populate the staging table
--  5/20/19 add checking UPS_FLOAT_DTL_ON interface flag, add alert. change function to procedure
--  6/25/19 modify ups_float_det_xml v_ctx := DBMS_XMLGen.newContext by getting record_status = 'N' 
--  7/25/19 modify ups_float_det_xml url for shipexec2.0 PROD
--  2/18/20 modify ups_float_det_xml url to add more special char like "
--      add route to error message
--  6/25/20 fix missing xml by adding beg excption in ups_float_set_xml inside c_fd loop.
--  6/26/20 add add_date to cursor c_fd
--  6/29/20 add v2 to ups_float_det_xml. change 'E' to 'F' for float_xml_tab status if failed to send to UPS
============================================================================================================*/

PROCEDURE load_ups_float_detail_tab;


PROCEDURE ups_float_det_xml;

FUNCTION ups_utl_http(
      p_url VARCHAR2,
      p_request_body CLOB,
      p_route_no VARCHAR2  )
    RETURN VARCHAR2;


END pl_ups_float_detail;
/


CREATE OR REPLACE PACKAGE BODY pl_ups_float_detail
IS
  /*===========================================================================================================
  -- Package Body
  -- pl_ups_float_detail
  --
  -- Description
  --   
  --   This package is to 
  --
  -- Modification History
  --
  -- Date                User                  Version            Defect  Comment
  -- 04/23/19          mcha1213                   1.0              Initial Creation
  -- 

  ============================================================================================================*/

    l_error_msg         VARCHAR2(2000);
  l_error_code        VARCHAR2(100);

    c_limit             number :=1000;



PROCEDURE load_ups_float_detail_tab is

      CURSOR c_ups
      IS 

	  SELECT ups_float_dtl_obj(fd.float_no, fd.seq_no,
		fd.prod_id, fd.qty_alloc, fd.uom, fd.order_seq, 
		fd.order_id, fd.route_no, fd.alloc_time, fd.src_loc, 
		pm.descrip, pm.spc, pm.pack, pm.prod_size, ordd.seq, ordm.d_pieces, ordm.c_pieces, ordm.f_pieces, 
		ordm.cust_po, ordm.cust_id, ordm.cust_name, ordm.cust_contact, ordm.cust_addr1, ordm.cust_addr2,
		ordm.cust_city, ordm.cust_state, ordm.cust_zip, ordm.cust_cntry, pm.case_length, pm.case_width,
		pm.case_height, pm.case_cube, pm.split_cube, pm.g_weight, pm.weight, 
		decode(fd.uom,1,0, trunc(fd.qty_alloc/pm.spc)),
		decode(fd.uom,1,fd.qty_alloc,0), 
		cc.Country_Name, ci.Country_Of_Origin )
		from float_detail fd, pm pm, ordd, ordm, cool_item ci, coo_codes cc
		where fd.prod_id = pm.prod_id
		and fd.order_id = ordd.order_id
        and fd.order_seq = ordd.seq
		and fd.order_id = ordm.order_id
		and fd.prod_id = ci.prod_id(+)
		and cc.Country_Of_Origin(+) = ci.Country_Of_Origin
		and not exists (select 'x'
                from ups_float_detail ud
                where fd.route_no = ud.route_no
                   and fd.float_no = ud.float_no
                   and fd.seq_no = ud.seq_no                   
                   and fd.order_seq = ordd.seq);      

	    /*
		SELECT ups_float_dtl_obj(fd.float_no, fd.seq_no,
		fd.prod_id, fd.qty_alloc, fd.uom, fd.order_seq, 
		fd.order_id, fd.route_no, fd.alloc_time, fd.src_loc, 
		pm.descrip, pm.spc, pm.pack, pm.prod_size, ordd.seq, ordm.d_pieces, ordm.c_pieces, ordm.f_pieces, 
		ordm.cust_po, ordm.cust_id, ordm.cust_name, ordm.cust_contact, ordm.cust_addr1, ordm.cust_addr2,
		ordm.cust_city, ordm.cust_state, ordm.cust_zip, ordm.cust_cntry, pm.case_length, pm.case_width,
		pm.case_height, pm.case_cube, pm.split_cube, pm.g_weight, pm.weight, 
		decode(fd.uom,1,0, trunc(fd.qty_alloc/pm.spc)),
		decode(fd.uom,1,fd.qty_alloc,0), 
		cc.Country_Name, ci.Country_Of_Origin )
		from float_detail fd, pm pm, ordd, ordm, cool_item ci, coo_codes cc
		where fd.prod_id = pm.prod_id(+)
		and fd.order_id = ordd.order_id(+)
		and fd.order_id = ordm.order_id(+)
		and fd.prod_id = ci.prod_id(+)
		and cc.Country_Of_Origin(+) = ci.Country_Of_Origin
		and not exists (select 'x'
                from ups_float_detail ud
                where fd.float_no = ud.float_no
                   and fd.seq_no = ud.seq_no);
        */				   


        /*
        SELECT ups_float_dtl_obj(
		       float_detail.float_no, float_detail.prod_id, float_detail.qty_alloc, float_detail.uom, float_detail.order_seq, 
               float_detail.order_id, float_detail.route_no, float_detail.alloc_time, float_detail.src_loc, 
               pm.descrip, pm.spc, pm.pack, pm.prod_size, ordd.seq, ordm.d_pieces, ordm.c_pieces, ordm.f_pieces, 
               ordm.cust_po, ordm.cust_id, ordm.cust_name, ordm.cust_contact, ordm.cust_addr1, ordm.cust_addr2, ordm.cust_city, 
               ordm.cust_state, ordm.cust_zip, ordm.cust_cntry, pm.case_length, pm.case_width, pm.case_height, 
               pm.case_cube, pm.split_cube, pm.g_weight, pm.weight, 
               decode(float_detail.uom,1,0, trunc(float_detail.qty_alloc/pm.spc)), 
               decode(float_detail.uom,1,float_detail.qty_alloc,0), 
               Coo_Codes.Country_Name, Cool_Item.Country_Of_Origin  )
               from float_detail 
               left join pm on (float_detail.prod_id = pm.prod_id)
               left join ordd on (float_detail.order_id = ordd.order_id)
               left join ordm on (float_detail.order_id = ordm.order_id)
               left join cool_item on (float_detail.prod_id = Cool_Item.Prod_Id)
               left join coo_codes on (Coo_Codes.Country_Of_Origin = Cool_Item.Country_Of_Origin)
			   where rownum < 18;
                --where route_no=''293'' and rownum < 18
			*/

      float_dtl ups_float_dtl_tab;


      t_cnt number;

begin

       open c_ups;

        loop

           fetch c_ups bulk collect into float_dtl
           limit c_limit;     

           exit when float_dtl.count = 0;


           for i in 1 .. float_dtl.count
           loop

		      insert into ups_float_detail
			  (SEQUENCE_NUMBER,
    			RECORD_STATUS,
				FLOAT_NO,
				SEQ_NO,
				PROD_ID,
				QTY_ALLOC,
				UOM,
				ORDER_SEQ,
				ORDER_ID,
				ROUTE_NO,
				ALLOC_TIME,
				SRC_LOC,
				DESCRIP,
				SPC,
				PACK,
				PROD_SIZE,
				SEQ,
				D_PIECES,
				C_PIECES,
				F_PIECES,
				CUST_PO,
				CUST_ID,
				CUST_NAME,
				CUST_CONTACT,
				CUST_ADDR1,
				CUST_ADDR2,
				CUST_CITY,
				CUST_STATE,
				CUST_ZIP,
				CUST_CNTRY,
				CASE_LENGTH,
				CASE_WIDTH,
				CASE_HEIGHT,
				CASE_CUBE,
				SPLIT_CUBE,
				G_WEIGHT,
				WEIGHT,
				CASES,
				SPLITS,
				COUNTRY_NAME,
				COUNTRY_OF_ORIGIN
				)
			  values(ups_float_dtl_seq.nextval,
			  'N',
				float_dtl(i).FLOAT_NO,
				float_dtl(i).SEQ_NO,				
				float_dtl(i).PROD_ID,
				float_dtl(i).QTY_ALLOC,
				float_dtl(i).UOM,
				float_dtl(i).ORDER_SEQ,
				float_dtl(i).ORDER_ID,
				float_dtl(i).ROUTE_NO,
				float_dtl(i).ALLOC_TIME,
				float_dtl(i).SRC_LOC,
				float_dtl(i).DESCRIP,
				float_dtl(i).SPC,
				float_dtl(i).PACK,
				float_dtl(i).PROD_SIZE,
				float_dtl(i).SEQ,
				float_dtl(i).D_PIECES,
				float_dtl(i).C_PIECES,
				float_dtl(i).F_PIECES,
				float_dtl(i).CUST_PO,
				float_dtl(i).CUST_ID,
				float_dtl(i).CUST_NAME,
				float_dtl(i).CUST_CONTACT,
				float_dtl(i).CUST_ADDR1,
				float_dtl(i).CUST_ADDR2,
				float_dtl(i).CUST_CITY,
				float_dtl(i).CUST_STATE,
				float_dtl(i).CUST_ZIP,
				float_dtl(i).CUST_CNTRY,
				float_dtl(i).CASE_LENGTH,
				float_dtl(i).CASE_WIDTH,
				float_dtl(i).CASE_HEIGHT,
				float_dtl(i).CASE_CUBE,
				float_dtl(i).SPLIT_CUBE,
				float_dtl(i).G_WEIGHT,
				float_dtl(i).WEIGHT,
				float_dtl(i).CASES,
				float_dtl(i).SPLITS,
				float_dtl(i).COUNTRY_NAME,
				float_dtl(i).COUNTRY_OF_ORIGIN	
               );				    

           end loop;



        end loop; 

        close c_ups;

        commit;


exception   
WHEN OTHERS THEN
   l_error_code := SUBSTR(SQLERRM,1,100);

   l_error_msg:= 'Error: Undefined Exception';
   l_error_code:= SUBSTR(SQLERRM,1,100);   
   pl_log.ins_msg(pl_log.ct_fatal_msg, 'pl_ups_float_detail', l_error_msg,
											SQLCODE, SQLERRM,
											'ups',
											'load_ups_float_detail_tab',
											'N');

   --raise; 

   INSERT INTO SWMS_FAILURE_EVENT
        (
          ALERT_ID,
          MODULES,
          ERROR_TYPE,
          STATUS,
          UNIQUE_ID,
          MSG_SUBJECT,
          MSG_BODY,
          ADD_DATE,
          ADD_USER
        )
    VALUES
        (
          failure_seq.NEXTVAL,
          'PL_UPS_FLOAT_DTL',
          'WARN',
          'N',
          substr(l_error_code, 1, 48),
          'Error from UPS interface inserting into ups_float_detail from pl_ups_float_detail.load_ups_float_detail_tab WOT exception',
		  substr('Error '||l_error_code, 1, 400),
          --substr('Error '||nvl(SQLERRM,' '), 1, 400),
          sysdate,
          'SWMS'
        );


    commit;	     

	--raise_application_error(-20001,'An error was encountered in pl_ups_float_detail.load_ups_float_detail_tab - '||SQLCODE||' -ERROR- '||SQLERRM);

END load_ups_float_detail_tab;


PROCEDURE ups_float_det_xml  
  IS

	v_ctx DBMS_XMLGen.ctxHandle;
    v_xml CLOB;
	v_xml_1 XMLTYPE;


    resultset_xml CLOB := NULL;
	v_route_no ups_float_detail.route_no%type;
    v1 ups_float_detail.route_no%type;

    v2 ups_float_detail.add_date%type; -- 6/29/20
    --v_cnt number :=0;

    resultset_xml_cw CLOB := NULL;
    l_offset        NUMBER DEFAULT 1;



    t_result varchar2(1):= 'S';

    t_result_f varchar2(1) := 'F';

    l_buffer VARCHAR2(32767);

	t_ups_switch  sys_config.config_flag_val%type;

	l_host_name v$instance.host_name%type;

    -- temp hardcode
    l_status varchar2(20);
	l_err_msg varchar2(100);

    -- this is for shipexec 1.12
   -- 6/25/20 replace by below l_url VARCHAR2(1000) := 'http://shipexec.iship.com/Sysco/amp/soap';

	-- this for production 
    l_url VARCHAR2(1000) := 'http://ast.iship.com/Sysco3/amp/soap';  -- this is for shipexec 2.0 PROD


    v_add_date   ups_float_detail.add_date%type;

    /* 6/25/20 this is the new cursor to use temp take out for debug
    cursor c_fd       
    is select distinct route_no, trunc(add_date,'DD') ad_date
       from ups_float_detail
       where record_status = 'N';
       */

    /* 6/25/20 temp take out for debuging 

	cursor c_fd
    is select distinct route_no
       from ups_float_detail
       where record_status = 'N';   

    */       

    -- 6/25/20 temp use for debuging
    /*  
	cursor c_fd
    is select distinct route_no
       from ups_float_detail
       where record_status = 'N'
       and route_no = '008W1'
       and trunc(add_date,'DD') = to_date('2020-05-12', 'YYYY-MM-DD');
       */

     /* 6/25/20 temp use for debuging   */

	cursor c_fd       
    is select distinct route_no, trunc(add_date,'DD') ad_date
       from ups_float_detail
       where record_status = 'N';
       
       --and route_no = '002W1'; --'008W1';

       -- and trunc(add_date,'DD') = to_date('2020-01-28', 'YYYY-MM-DD');       

       --to_date('2020-05-12', 'YYYY-MM-DD');       



  BEGIN

      select host_name
	  into l_host_name
	  from v$instance;


	open c_fd;
	loop

      begin  -- add 6/25/20

        resultset_xml := null;  -- reset to null

		-- 6/26/20 this is for distinct route_no it works fetch c_fd into v_route_no;

        fetch c_fd into v_route_no, v_add_date; --v_route_no;
		exit when c_fd%notfound;



    --    dbms_output.put_line('in c_fd loop v_route_no= '||v_route_no);

      --  dbms_output.put_line('in c_fd loop v_add_date= '||v_add_date);



        /*
		v_ctx := DBMS_XMLGen.newContext
		('select
		float_no, prod_id, qty_alloc, uom, order_seq, 
		order_id, route_no, alloc_time, src_loc, 
		descrip, spc, pack, prod_size, seq, d_pieces, c_pieces, f_pieces, 
		cust_po, cust_id, cust_name, cust_contact, cust_addr1, cust_addr2, cust_city, 
		cust_state, cust_zip, cust_cntry, case_length, case_width, case_height, 
		case_cube, split_cube, g_weight, weight, 
		cases, splits, Country_Name, Country_Of_Origin
		from ups_float_detail d
		where d.route_no = v_route_no '
		);
        */

		/* 6/25/20 this is the original one it works
        v_ctx := DBMS_XMLGen.newContext
		('select
		float_no, seq_no, prod_id, qty_alloc, uom, order_seq, 
		order_id, route_no, alloc_time, src_loc, 
		descrip, spc, pack, prod_size, seq, d_pieces, c_pieces, f_pieces, 
		cust_po, cust_id, cust_name, cust_contact, cust_addr1, cust_addr2, cust_city, 
		cust_state, cust_zip, cust_cntry, case_length, case_width, case_height, 
		case_cube, split_cube, g_weight, weight, 
		cases, splits, Country_Name, Country_Of_Origin
		from ups_float_detail d
		where d.record_status = ''N''
		and d.route_no = :1 '
        );
        */

        /* 6/25/20 try this see if it get rid of ora-31061    
        v_ctx := DBMS_XMLGen.newContext
		('select REGEXP_REPLACE(float_no, ''[[:cntrl:]]'', '''') float_no,
        REGEXP_REPLACE(seq_no, ''[[:cntrl:]]'', '''') seq_no,
        REGEXP_REPLACE(prod_id, ''[[:cntrl:]]'', '''') prod_id,
        REGEXP_REPLACE(qty_alloc, ''[[:cntrl:]]'', '''') qty_alloc,
        REGEXP_REPLACE(uom, ''[[:cntrl:]]'', '''') uom,
        REGEXP_REPLACE(order_seq, ''[[:cntrl:]]'', '''') order_seq,
        REGEXP_REPLACE(order_id, ''[[:cntrl:]]'', '''') order_id,        
        REGEXP_REPLACE(route_no, ''[[:cntrl:]]'', '''') route_no,        
        REGEXP_REPLACE(alloc_time, ''[[:cntrl:]]'', '''') alloc_time,        
        REGEXP_REPLACE(src_loc, ''[[:cntrl:]]'', '''') src_loc,        
        REGEXP_REPLACE(descrip, ''[[:cntrl:]]'', '''') descrip,
        REGEXP_REPLACE(spc, ''[[:cntrl:]]'', '''') spc,       
        REGEXP_REPLACE(pack, ''[[:cntrl:]]'', '''') pack,        
        REGEXP_REPLACE(prod_size, ''[[:cntrl:]]'', '''') prod_size,           
        REGEXP_REPLACE(seq, ''[[:cntrl:]]'', '''') seq,         
        REGEXP_REPLACE(d_pieces, ''[[:cntrl:]]'', '''') d_pieces,         
        REGEXP_REPLACE(c_pieces, ''[[:cntrl:]]'', '''') c_pieces,
        REGEXP_REPLACE(f_pieces, ''[[:cntrl:]]'', '''') f_pieces,
        REGEXP_REPLACE(cust_po, ''[[:cntrl:]]'', '''') cust_po,
        REGEXP_REPLACE(cust_id, ''[[:cntrl:]]'', '''') cust_id,
        REGEXP_REPLACE(cust_name, ''[[:cntrl:]]'', '''') cust_name,
        REGEXP_REPLACE(cust_contact, ''[[:cntrl:]]'', '''') cust_contact,
        REGEXP_REPLACE(cust_addr1, ''[[:cntrl:]]'', '''') cust_addr1,
        REGEXP_REPLACE(cust_addr2, ''[[:cntrl:]]'', '''') cust_addr2,
        REGEXP_REPLACE(cust_city, ''[[:cntrl:]]'', '''') cust_city,
        REGEXP_REPLACE(cust_state, ''[[:cntrl:]]'', '''') cust_state,
        REGEXP_REPLACE(cust_zip, ''[[:cntrl:]]'', '''') cust_zip,
        REGEXP_REPLACE(cust_cntry, ''[[:cntrl:]]'', '''') cust_cntry,
        REGEXP_REPLACE(case_length, ''[[:cntrl:]]'', '''') case_length,
        REGEXP_REPLACE(case_width, ''[[:cntrl:]]'', '''') case_width,   
        REGEXP_REPLACE(case_height, ''[[:cntrl:]]'', '''') case_height,   
        REGEXP_REPLACE(case_cube, ''[[:cntrl:]]'', '''') case_cube,   
        REGEXP_REPLACE(split_cube, ''[[:cntrl:]]'', '''') split_cube,   
        REGEXP_REPLACE(g_weight, ''[[:cntrl:]]'', '''') g_weight,   
        REGEXP_REPLACE(weight, ''[[:cntrl:]]'', '''') weight, 
        REGEXP_REPLACE(cases, ''[[:cntrl:]]'', '''') cases, 
        REGEXP_REPLACE(splits, ''[[:cntrl:]]'', '''') splits, 
        REGEXP_REPLACE(Country_Name, ''[[:cntrl:]]'', '''') Country_Name, 
        REGEXP_REPLACE(Country_Of_Origin, ''[[:cntrl:]]'', '''') Country_Of_Origin         
		from ups_float_detail d
		where d.record_status = ''F''
		and d.route_no = :1 '
        );
        */

        -- 6/29/20 this is the original code where d.record_status = ''N'', i change it to F for testing

        -- add v2 6/29/20
          v_ctx := DBMS_XMLGen.newContext
		('select REGEXP_REPLACE(float_no, ''[[:cntrl:]]'', '''') float_no,
        REGEXP_REPLACE(seq_no, ''[[:cntrl:]]'', '''') seq_no,
        REGEXP_REPLACE(prod_id, ''[[:cntrl:]]'', '''') prod_id,
        REGEXP_REPLACE(qty_alloc, ''[[:cntrl:]]'', '''') qty_alloc,
        REGEXP_REPLACE(uom, ''[[:cntrl:]]'', '''') uom,
        REGEXP_REPLACE(order_seq, ''[[:cntrl:]]'', '''') order_seq,
        REGEXP_REPLACE(order_id, ''[[:cntrl:]]'', '''') order_id,        
        REGEXP_REPLACE(route_no, ''[[:cntrl:]]'', '''') route_no,        
        REGEXP_REPLACE(alloc_time, ''[[:cntrl:]]'', '''') alloc_time,        
        REGEXP_REPLACE(src_loc, ''[[:cntrl:]]'', '''') src_loc,        
        REGEXP_REPLACE(descrip, ''[[:cntrl:]]'', '''') descrip,
        REGEXP_REPLACE(spc, ''[[:cntrl:]]'', '''') spc,       
        REGEXP_REPLACE(pack, ''[[:cntrl:]]'', '''') pack,        
        REGEXP_REPLACE(prod_size, ''[[:cntrl:]]'', '''') prod_size,           
        REGEXP_REPLACE(seq, ''[[:cntrl:]]'', '''') seq,         
        REGEXP_REPLACE(d_pieces, ''[[:cntrl:]]'', '''') d_pieces,         
        REGEXP_REPLACE(c_pieces, ''[[:cntrl:]]'', '''') c_pieces,
        REGEXP_REPLACE(f_pieces, ''[[:cntrl:]]'', '''') f_pieces,
        REGEXP_REPLACE(cust_po, ''[[:cntrl:]]'', '''') cust_po,
        REGEXP_REPLACE(cust_id, ''[[:cntrl:]]'', '''') cust_id,
        REGEXP_REPLACE(cust_name, ''[[:cntrl:]]'', '''') cust_name,
        REGEXP_REPLACE(cust_contact, ''[[:cntrl:]]'', '''') cust_contact,
        REGEXP_REPLACE(cust_addr1, ''[[:cntrl:]]'', '''') cust_addr1,
        REGEXP_REPLACE(cust_addr2, ''[[:cntrl:]]'', '''') cust_addr2,
        REGEXP_REPLACE(cust_city, ''[[:cntrl:]]'', '''') cust_city,
        REGEXP_REPLACE(cust_state, ''[[:cntrl:]]'', '''') cust_state,
        REGEXP_REPLACE(cust_zip, ''[[:cntrl:]]'', '''') cust_zip,
        REGEXP_REPLACE(cust_cntry, ''[[:cntrl:]]'', '''') cust_cntry,
        REGEXP_REPLACE(case_length, ''[[:cntrl:]]'', '''') case_length,
        REGEXP_REPLACE(case_width, ''[[:cntrl:]]'', '''') case_width,   
        REGEXP_REPLACE(case_height, ''[[:cntrl:]]'', '''') case_height,   
        REGEXP_REPLACE(case_cube, ''[[:cntrl:]]'', '''') case_cube,   
        REGEXP_REPLACE(split_cube, ''[[:cntrl:]]'', '''') split_cube,   
        REGEXP_REPLACE(g_weight, ''[[:cntrl:]]'', '''') g_weight,   
        REGEXP_REPLACE(weight, ''[[:cntrl:]]'', '''') weight, 
        REGEXP_REPLACE(cases, ''[[:cntrl:]]'', '''') cases, 
        REGEXP_REPLACE(splits, ''[[:cntrl:]]'', '''') splits, 
        REGEXP_REPLACE(Country_Name, ''[[:cntrl:]]'', '''') Country_Name, 
        REGEXP_REPLACE(Country_Of_Origin, ''[[:cntrl:]]'', '''') Country_Of_Origin         
		from ups_float_detail d
		where d.route_no = :1
		and trunc(d.add_date, ''DD'') = :2 '
        );


        /* this compiled
		v_ctx := DBMS_XMLGen.newContext
		('select
		float_no, seq_no, prod_id, qty_alloc, uom, order_seq, 
		order_id, route_no, alloc_time, src_loc, 
		descrip, spc, pack, prod_size, seq, d_pieces, c_pieces, f_pieces, 
		cust_po, cust_id, cust_name, cust_contact, cust_addr1, cust_addr2, cust_city, 
		cust_state, cust_zip, cust_cntry, case_length, case_width, case_height, 
		case_cube, split_cube, g_weight, weight, 
		cases, splits, Country_Name, Country_Of_Origin
		from ups_float_detail d
		where d.route_no = :1 '
        );
       */

		--where d.route_no = ''ROTSLOAD'' '

		DBMS_XMLGEN.setPrettyPrinting(v_ctx, TRUE);
		DBMS_XMLGEN.setIndentationWidth(v_ctx, 2);
		DBMS_XMLGen.setRowsetTag(v_ctx, 'ROUTES');
		DBMS_XMLGen.setRowTag(v_ctx, 'ROUTE');

		dbms_xmlgen.SETNULLHANDLING (v_ctx, dbms_xmlgen.EMPTY_TAG);
		--v_xml := DBMS_XMLGen.GetXML(v_ctx);

        v1 := v_route_no; -- add this 5/2/19

        v2 := v_add_date; -- add this 6/29/20

        dbms_output.put_line('before setbindvalue v1= '||v1);

        DBMS_XMLGEN.setbindvalue (v_ctx, '1', V1);  -- add this 5/2/19

        DBMS_XMLGEN.setbindvalue (v_ctx, '2', V2);  -- add this 6/29/20

		-- add 5/13/19 for set the conversion of special xml characters to false. this cause 500 error from ups return
		-- use this to test exception from ups

		--DBMS_XMLGEN.setConvertSpecialChars(v_ctx, false);

        --DBMS_XMLGEN.setConvertSpecialChars(v_ctx, false); -- 6/26/20 enable it see if it works for route 008W1

   --     dbms_output.put_line('before v_xml_1 get it ');  -- 6/26/20 add

		v_xml_1 := DBMS_XMLGEN.GETXMLTYPE(v_ctx);

   --     dbms_output.put_line('after v_xml_1 get it ');  -- 6/26/20 add

		DBMS_XMLGen.closeContext(v_ctx);

    --    dbms_output.put_line('before v_xml get it value v_xml= '||v_xml);  -- 6/26/20 add but take it out for ora-30625?

		v_xml := v_xml_1.GETCLOBVAL();

        --dbms_output.put_line('after v_xml get it value v_xml= '||v_xml);  -- 6/26/20 add
        -- There are limitations to dbms_output.put_line that cause issues when processing large data : namely, 
        --clobs larger than 32k do fail to be printed this way, with error ORA-06502.


     /*
        resultset_xml := concat(resultset_xml,
		'<s:Envelope xmlns:s="http://www.w3.org/2003/05/soap-envelope">||''||<s:Body>||''||
         <urn:customOperationRequest xmlns:urn="urn:connectship-com:ampcore">||''||
         <urn:processName>UPS</urn:processName>||''||
         <urn:processData/>||''');
      */   

       resultset_xml := concat(resultset_xml,
		'<s:Envelope xmlns:s="http://www.w3.org/2003/05/soap-envelope">'||''||'<s:Body>'||''||
         '<urn:customOperationRequest xmlns:urn="urn:connectship-com:ampcore">'||''||
         '<urn:processName>UPS</urn:processName>'||''||
         '<urn:processData>');         

		resultset_xml := concat(resultset_xml, v_xml||''); 

		resultset_xml := concat(resultset_xml, 
		'</urn:processData>'||''||'</urn:customOperationRequest>'||''||'</s:Body>'||''||'</s:Envelope>');

    --p_data_in := REPLACE(REPLACE(REPLACE(REPLACE(REPLACE( p_data_in, '&', ' and ' ), '#', ' '), chr(26),''), chr(13),''), chr(10),''); --extra replace added for chr26, chr10, chr13

	-- temp take out on 5/13/19 see if DBMS_XMLGEN.setConvertSpecialChars(queryCtx, false); works

	--
	resultset_xml := REPLACE(REPLACE(REPLACE(REPLACE(REPLACE( resultset_xml, '&', ' and ' ), '#', ' '), chr(26),''), chr(13),''), chr(10),''); --extra replace added for chr26, chr10, chr13

    --p_data_in := replace(Replace(REPLACE(REPLACE( p_data_in, '%', ' ' ), '(', ' '), ')', ' '), '+', ' ');

	-- temp take out on 5/13/19 see if DBMS_XMLGEN.setConvertSpecialChars(queryCtx, false); works

	--
	resultset_xml := replace(Replace(REPLACE(REPLACE( resultset_xml, '%', ' ' ), '(', ' '), ')', ' '), '+', ' ');

		   dbms_output.put_line('before insert float_xml_tab');

        --v_cnt := v_cnt+1;

		insert into FLOAT_XML_TAB(id, status, route_no, xml_data, err_msg, add_date)
        values (ups_float_xml_seq.nextval, 'N', v_route_no, resultset_xml, null, v_add_date);  -- 6/29 replace with v_add_date sysdate);


		   dbms_output.put_line('after insert float_xml_tab');			   

         commit;	 		 

		 		   dbms_output.put_line('after insert float_xml_tab commit before call ups_utl_http');


		-- 5/2/19 temp comment out for testing xml 
        l_buffer := ups_utl_http(l_url, resultset_xml, v_route_no);


		--get the response string from the call
		dbms_output.put_line('response:'||l_buffer );


		l_status := substr(l_buffer,instr(l_buffer, '<code>')+6,1) ;



		dbms_output.put_line('before chking l_status l_status :='||l_status );

		If l_status = '0' then
		    --upper(l_status) = 'TRUE' then

			--pl_log.ins_msg('INFO','ups_float_det_xml', 'Sucessfully sent UPS Float Detail Route:'||v_route_no,  200, l_status, 'UPS', 'pl_ups_float_detail', 'Y');
		dbms_output.put_line('in if l_status =0 before pl_log.ins_msg' );			
            pl_log.ins_msg('INFO','ups_float_det_xml', 'Sucessfully sent UPS Float Detail Route:'||v_route_no||' add_date= '||v_add_date,  null, 'No Errors', 'UPS', 'pl_ups_float_detail', 'Y');
        dbms_output.put_line('in if l_status =0 after pl_log.ins_msg' );			

          Begin
            UPDATE ups_float_detail
            SET record_status      = 'S',
				upd_date = sysdate,
				error_msg = null
            WHERE route_no = v_route_no
            and trunc(add_date,'DD') = v_add_date; -- 6/26/20 add
            --AND trunc(ADD_DATE) = trunc(i.add_date)
           -- AND record_status   = 'N'; --'Q';
           --  and batch_id =i.batch_id;

            --COMMIT;
          EXCEPTION  WHEN OTHERS THEN
                pl_log.ins_msg('FATAL', 'ups_float_det_xml', 'Error with update UPS Float Detail to S for Route:'||v_route_no||' add_date= '||v_add_date,
                nvl(SQLCODE,0), nvl(SQLERRM,' '), 'UPS', 'pl_ups_float_detail', 'Y');
                --raise_application_error(-20001,'An error was encountered in pl_ups_float_detail.ups_float_det_xml update ups_float_detail with S - '
				  --  ||SQLCODE||' -ERROR- '||SQLERRM);				
          End;

          Begin
             dbms_output.put_line('before update float_xml_tab err_msg');

             update FLOAT_XML_TAB
			 set status = 'S',
			     upd_date = sysdate,
			     err_msg = 'NONE'
			 where route_no = v_route_no
             and trunc(add_date,'DD') = v_add_date; -- 6/26/20 add;

             --insert into FLOAT_XML_TAB(id, route_no, xml_data, err_msg, add_date)
             --values (ups_float_xml_seq.nextval, v_route_no, resultset_xml, null, sysdate);


		     dbms_output.put_line('after update float_xml_tab with errf_msg = NONE');			   

             --commit;	 		 



          EXCEPTION  WHEN OTHERS THEN
                pl_log.ins_msg('FATAL', 'ups_float_det_xml', 'Error with insert xml data to float_xml_tab for route;'||v_route_no||' add_date= '||v_add_date,
                nvl(SQLCODE,0), nvl(SQLERRM,' '), 'UPS', 'pl_ups_float_detail', 'Y');
                --raise_application_error(-20001,'An error was encountered in pl_ups_float_detail.ups_float_det_xml update float_xml_tab with S - '
				  --  ||SQLCODE||' -ERROR- '||SQLERRM);							
          End;         
		Else  -- if l_status = '0'

          dbms_output.put_line('in chking l_status l_status is not 0');

          pl_log.ins_msg('FATAL', 'ups_float_det_xml', 'Error sending UPS Float Detail Route:'||v_route_no||' add_date= '||v_add_date, nvl(SQLCODE,0), nvl(l_status,' '), 'UPS', 'pl_ups_float_detail', 'Y');

		  l_err_msg := substr(l_buffer,instr(l_buffer, 'message>')+8,100) ;

          begin
             UPDATE ups_float_detail
             SET record_status = 'F',
			    upd_date = sysdate,
                --error_code = sqlcode,
                error_msg = l_err_msg --'Error sending UPS Float Detail Route:'||v_route_no                
              WHERE route_no = v_route_no
              and trunc(add_date,'DD') = v_add_date; -- 6/26/20 add
              --AND trunc(ADD_DATE) = trunc(i.add_date)
              --AND record_status  = 'N'; --in   ('Q');

			  --commit;
          EXCEPTION  WHEN OTHERS THEN
                pl_log.ins_msg('FATAL', 'ups_float_det_xml', 'Error with update UPS Float Detail to F for Route:'||v_route_no||' add_date= '||v_add_date,  nvl(SQLCODE,0), l_err_msg, 'UPS', 'pl_ups_float_detail', 'Y');
                --raise_application_error(-20001,'An error was encountered in pl_ups_float_detail.ups_float_det_xml update ups_float_detail with F - '
				  --  ||SQLCODE||' -ERROR- '||SQLERRM);						
          End;  
            --p_data_in := replace(p_data_in, '><', '>'||chr(10)||'<');

		  Begin
             dbms_output.put_line('before update float_xml_tab err_msg');

             update FLOAT_XML_TAB
			 set status = 'F',  -- 6/29/20 change from E to F
			     upd_date = sysdate,
			     err_msg = l_err_msg
			 where route_no = v_route_no
             and trunc(add_date,'DD') = v_add_date; -- 6/26/20 add

             --insert into FLOAT_XML_TAB(id, route_no, xml_data, err_msg, add_date)
             --values (ups_float_xml_seq.nextval, v_route_no, resultset_xml, l_buffer, sysdate);


		     dbms_output.put_line('after update float_xml_tab for UPS error response');			   

             --commit;	 		 



          EXCEPTION  WHEN OTHERS THEN
                pl_log.ins_msg('FATAL', 'ups_float_det_xml', 'Error with insert xml data to float_xml_tab for route;'||v_route_no||' add_date= '||v_add_date,  nvl(SQLCODE,0), nvl(SQLERRM,' '), 'UPS', 'pl_ups_float_detail', 'Y');
                --raise_application_error(-20001,'An error was encountered in pl_ups_float_detail.ups_float_det_xml update ups_float_detail with E - '
				  --  ||SQLCODE||' -ERROR- '||SQLERRM);							
          End;         


     --    ADD_ALERT('SWMS', 'Issue sending SWMS-STS Route:'||i.route_no, i.route_no, l_company);
          End If;  -- l_status = '0'

       EXCEPTION  WHEN OTHERS THEN  -- add 6/25/20
             -- 6/26/20 add
             UPDATE ups_float_detail
             SET record_status = 'F',
			    upd_date = sysdate,
                --error_code = sqlcode,
                error_msg = l_err_msg --'Error sending UPS Float Detail Route:'||v_route_no                
              WHERE route_no = v_route_no
              and trunc(add_date,'DD') = v_add_date;

              --AND trunc(ADD_DATE) = trunc(i.add_date)
              --AND record_status  = 'N'; --in   ('Q');

            pl_log.ins_msg('FATAL', 'ups_float_det_xml', 'Error from ups_float_det_xml inside c_fd loop wto eror for Route:'||v_route_no||' add_date= '||v_add_date,  nvl(SQLCODE,0), nvl(SQLERRM,' '), 'UPS', 'pl_ups_float_detail', 'Y');
                --raise_application_error(-20001,'An error was encountered in pl_ups_float_detail.ups_float_det_xml update ups_float_detail with S - '
				  --  ||SQLCODE||' -ERROR- '||SQLERRM);				
        End;

      end loop; -- c_fd

      commit;

        --RETURN t_result ; --resultset_xml;

  EXCEPTION
  WHEN OTHERS THEN

     l_error_code:= SUBSTR(SQLERRM,1,100); 
     l_error_msg:= 'Error: When others error from pl_ups_float_detail.ups_float_det_xml route '||v_route_no||
	    ' error code '|| l_error_code;
     pl_log.ins_msg(pl_log.ct_fatal_msg, 'pl_ups_float_detail', l_error_msg,
											SQLCODE, SQLERRM,
											'ups',
											'ups_float_det_xml',
											'u');
       /*
       insert into FLOAT_XML_TAB(id, xml_data)
               values (2, l_error_msg);
		   dbms_output.put_line('after insert float_xml_tab in when others');			   

         commit;	 		 
        */

         INSERT INTO SWMS_FAILURE_EVENT
        (
          ALERT_ID,
          MODULES,
          ERROR_TYPE,
          STATUS,
          UNIQUE_ID,
          MSG_SUBJECT,
          MSG_BODY,
          ADD_DATE,
          ADD_USER
        )
        VALUES
        (
          failure_seq.NEXTVAL,
          'PL_UPS_FLOAT_DTL',
          'WARN',
          'N',
          'error raise from ups_utl_http',--nvl(substr(l_error_code, 1, 48),'error raise from ups_utl_http'),  -- 2/19/20 add nvl
          'Error from ups interface, pl_ups_float_detail.ups_float_det_xml WOT error for route '||v_route_no,
		  substr(l_error_msg||' '||L_error_code, 1, 400),
          --l_error_msg||' '||L_error_code,
          sysdate,
          'SWMS'
        );

        commit;		

        --raise_application_error(-20001,'From WOT an error was encountered in pl_ups_float_detail.ups_float_det_xml  - '
			--	    ||SQLCODE||' -ERROR- '||SQLERRM);				


  END ups_float_det_xml;

FUNCTION ups_utl_http(
      p_url VARCHAR2,
      p_request_body CLOB ,
	  p_route_no varchar2)
    RETURN VARCHAR2
  AS
    utl_req UTL_HTTP.req;
    utl_resp UTL_HTTP.resp;
    req_length binary_integer;
    response_body CLOB;
    resp_length binary_integer;
    buffer VARCHAR2 (2000);
    amount pls_integer := 2000;
    offset pls_integer := 1;
    l_status varchar2(10);
    l_msg varchar2(500);
  BEGIN

  dbms_output.put_line('beging ups_utl_http');

    utl_req := UTL_HTTP.begin_request (p_url, 'POST', 'HTTP/1.1');
    utl_http.set_header(utl_req, 'SOAPAction', 'http://urn:connectship-com:ampcore/CoreXmlPort/CustomOperationRequest');

    utl_http.set_header(utl_req, 'User-Agent', 'Mozilla/4.0');
    UTL_HTTP.set_header(utl_req, 'Content-Type', 'application/soap+xml;charset=UTF-8');

      dbms_output.put_line('in ups_utl_http after tul_http.set_header route '||p_route_no);

    req_length := DBMS_LOB.getlength (p_request_body);

    -- If Message data under 32kb limit
    IF req_length<=32767 THEN
      UTL_HTTP.set_header (utl_req, 'Content-Length', req_length);

 --         dbms_output.put_line( p_request_body); --enable this to show xml generated

   dbms_output.put_line('ups_utl_http before 1st UTL_HTTP.write_text');

      UTL_HTTP.write_text (utl_req, p_request_body);
      --If Message data more than 32kb then transfer chunked
    elsif req_length>32767 THEN
      UTL_HTTP.set_header (utl_req, 'Transfer-Encoding', 'chunked');

    dbms_output.put_line('ups_utl_http before 2nd UTL_HTTP.write_text LOOP');

      WHILE (offset < req_length)
      LOOP
        DBMS_LOB.read (p_request_body, amount, offset, buffer);

   --   dbms_output.put_line(buffer); --enable this to show xml generated

        UTL_HTTP.write_text(utl_req, buffer);
        offset := offset + amount;
      END LOOP;
    END IF;

  dbms_output.put_line('ups_utl_http before UTL_HTTP.get_response route '||p_route_no);

    BEGIN
      utl_resp := UTL_HTTP.get_response (utl_req);
      UTL_HTTP.read_text (utl_resp, response_body, 32767);
      DBMS_OUTPUT.PUT_LINE ('status code: ' || utl_resp.STATUS_CODE);

      DBMS_OUTPUT.PUT_LINE ('reason: ' || utl_resp.REASON_PHRASE);

	  DBMS_OUTPUT.PUT_LINE ('in upa_tul_http response_body: ' || response_body);

	  /* this is done in ups_float_det_xml

      l_status := substr(response_body,instr(response_body, '<Valid>')+7,4) ;

      l_msg := substr(response_body,instr(response_body, '<Msg>')+5,100) ;

       DBMS_OUTPUT.PUT_LINE ( 'l_status :=' ||  l_status );

      If utl_resp.STATUS_CODE = 200 and upper(l_status) = 'TRUE' then

         pl_log.ins_msg('INFO','ups_utl_http', 'Float Detail sucessfully sent',  utl_resp.STATUS_CODE, l_msg, 'UPS', 'pl_ups_float_detail', 'Y');
      Else
         pl_log.ins_msg('FATAL','ups_utl_http', 'Error sending Float Detail', utl_resp.STATUS_CODE, l_msg, 'UPS', 'pl_ups_float_detail', 'Y');

      End If;

      */

      UTL_HTTP.end_response (utl_resp);
    EXCEPTION
    WHEN utl_http.end_of_body THEN
      utl_http.end_response(utl_resp);
    WHEN UTL_HTTP.TOO_MANY_REQUESTS THEN
      UTL_HTTP.END_RESPONSE(utl_resp);
    WHEN OTHERS THEN
      dbms_output.put_line(Utl_Http.Get_Detailed_Sqlerrm);
      dbms_output.put_line(DBMS_UTILITY.FORMAT_ERROR_STACK);
      dbms_output.put_line(DBMS_UTILITY.format_error_backtrace);
      dbms_output.put_line(DBMS_UTILITY.format_call_stack);
      pl_log.ins_msg('FATAL', 'ups_utl_http', 'Error sending Float Detail :errorcode -'||utl_resp.STATUS_CODE,  nvl(SQLCODE,0), nvl(SQLERRM,' '), 'STS', 'pl_ups_float_detail', 'Y');


        INSERT INTO SWMS_FAILURE_EVENT
        (
          ALERT_ID,
          MODULES,
          ERROR_TYPE,
          STATUS,
          UNIQUE_ID,
          MSG_SUBJECT,
          MSG_BODY,
          ADD_DATE,
          ADD_USER
        )
        VALUES
        (
          failure_seq.NEXTVAL,
          'PL_UPS_FLOAT_DTL',
          'WARN',
          'N',
          substr(l_error_code, 1, 48),
          'Error from ups interface sending xml to UPS pl_ups_float_detail.ups_utl_http for route '||p_route_no,
		  --substr('Error sending Float Detail :errorcode -'||utl_resp.STATUS_CODE||' '||nvl(SQLERRM,' '), 1, 400),
          --substr('Error sending Float Detail :errorcode -'||utl_resp.STATUS_CODE||' '||SQLERRM, 1, 400),
          substr('Error sending Float Detail :errorcode -'||utl_resp.STATUS_CODE, 1, 400),
		  --substr(l_error_msg||' '||L_error_code, 1, 400);
          --l_error_msg||' '||L_error_code,
          sysdate,
          'SWMS'
        );


        commit;	  

        raise;
    END;
    RETURN response_body;
  END ups_utl_http;





END pl_ups_float_detail;
/
