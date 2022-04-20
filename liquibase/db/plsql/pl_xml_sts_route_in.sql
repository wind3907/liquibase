CREATE OR REPLACE PACKAGE      pl_xml_sts_route_in
IS
/*===========================================================================================================
-- Package
-- pl_xml_matrix_out
--
-- Description
--   This package is called by SWMS.
--   This package is to replace PI for STS Route Outbound using SOAP/XML
--
-- Modification History
--
-- Date                User                  Version            Defect  Comment
-- 08/01/18        mcha1213                   1.0              Initial Creation
-- 09/27/18                                                    add routesupdate
-- 11/01/18                                                    modify xpath as requested by SAE
-- 11/14/18                                                    add msg_id to STS_ROUTE_XML_IN
-- 12/12/18                                                    modify SR
-- 12/20/18                                                    add PI switch check
-- 01/10/19                                                    add STS to SWMS PI switch chk
-- 02/15/19                                                    fix one xml with more than one route with same msg_id,
-- 02/25/19                                                    fix the anonymous block in DriverProExport for update route no
                                                               and return 'true' to STS
-- 09/10/19                                                    Jira-OPCOF-2510 ENH-POD Hold all return transactions with T or D code
                                                               until manifest is closed
-- 10/02/19                                                    add alt_stop_no = l_stop_no
-- 10/25/19                                                    add 'N01' to stop processing for STC
-- 12/5/19                                                     take out D and T
-- 1/3/20                                                      For POD customer, for N01 and T01 put 'X'
--                                                               for Non POD put 'X' for Stop Close
-- 1/7/20                                                      Stop processing any Stop Close
-- 2/3/20                                                      barcode modification this is for STS client 6.07.05. 'X' for stop correction
--                                                             4/28 for RJ put 'X' for stop close if no barcode and also stop correction
--                                                             5/6 take out the no barcode part.
--                                                             5/14 for barcode <=8 and barcode is null don't do immediate credit, don't
--                                                                    insert into returns table
--                                                             6/1/20 for item id with 'F%' put 'X'
--  														   6/3/20 suppress imm credit for records with certain reason code, obligation
--                                                             6/17/20 suppress the whole obligation for records with certain reason code, obligation
--                                                             9/2/20 fix stop close with event type tag issues
--                                                             12/9/20 Jira 3256 fix duplicate returns. For non pod enable opco don't process stop close
--															   6/18/21 Jira 3514 route close with record_status 'X'
============================================================================================================*/

PROCEDURE check_webservice(i_interface_ref_doc  IN VARCHAR2,
                           o_active_flag        OUT VARCHAR2,
                           o_url_port           OUT VARCHAR2,
                           o_reason             OUT VARCHAR2);

--FUNCTION process_sts_route_in(i_xml IN XMLTYPE) return number;

--FUNCTION process_route_in_noparam return number;



PROCEDURE initiate_webservice(i_sys_msg_id    IN   NUMBER,
                              i_ref_doc       IN   VARCHAR2);

--FUNCTION process_route_in_string(i_xml IN XMLTYPE) return driverproexportresponse;

--FUNCTION DriverProExport(i_xml IN XMLTYPE) return driverproexportresponse;

     --return driverproexportresponse_tab ;

FUNCTION DriverProExport(i_xml IN XMLTYPE) return driverproexportresponse;

PROCEDURE generate_xml;

PROCEDURE get_rt_upd(seq_id IN NUMBER, t_msg_id in sts_route_in.msg_id%type, l_path in varchar2);

PROCEDURE get_st_upd(seq_id IN NUMBER, t_msg_id in sts_route_in.msg_id%type, l_path in varchar2);

PROCEDURE get_et_upd(seq_id IN NUMBER, t_msg_id in sts_route_in.msg_id%type, l_path in varchar2);

PROCEDURE get_ip_upd(seq_id IN NUMBER, t_msg_id in sts_route_in.msg_id%type, l_path in varchar2);

PROCEDURE get_rj_upd(seq_id IN NUMBER, t_msg_id in sts_route_in.msg_id%type, l_path in varchar2);

PROCEDURE get_sr_upd(seq_id IN NUMBER, t_msg_id in sts_route_in.msg_id%type, l_path in varchar2);

PROCEDURE get_iv_upd(seq_id IN NUMBER, t_msg_id in sts_route_in.msg_id%type, l_path in varchar2);

PROCEDURE get_sp_upd(seq_id IN NUMBER, t_msg_id in sts_route_in.msg_id%type, l_path in varchar2);

PROCEDURE get_at_upd(seq_id IN NUMBER, t_msg_id in sts_route_in.msg_id%type, l_path in varchar2);

PROCEDURE get_cw_upd(seq_id IN NUMBER, t_msg_id in sts_route_in.msg_id%type, l_path in varchar2);

PROCEDURE get_tf_upd(seq_id IN NUMBER, t_msg_id in sts_route_in.msg_id%type, l_path in varchar2);

PROCEDURE get_ti_upd(seq_id IN NUMBER, t_msg_id in sts_route_in.msg_id%type, l_path in varchar2);

PROCEDURE get_md_upd(seq_id IN NUMBER, t_msg_id in sts_route_in.msg_id%type, l_path in varchar2);

PROCEDURE get_ca_upd(seq_id IN NUMBER, t_msg_id in sts_route_in.msg_id%type, l_path in varchar2);

PROCEDURE get_ot_upd(seq_id IN NUMBER, t_msg_id in sts_route_in.msg_id%type, l_path in varchar2);

FUNCTION rt_type(seq_id IN NUMBER, r_path in varchar2) return number;

PROCEDURE get_rectyperc_upd(seq_id IN NUMBER, t_msg_id in sts_route_in.msg_id%type, l_path in varchar2); -- 9/2/20

PROCEDURE get_rectypesc_upd(seq_id IN NUMBER, t_msg_id in sts_route_in.msg_id%type, l_path in varchar2); -- 9/2/20




END pl_xml_sts_route_in;


/


CREATE OR REPLACE PACKAGE BODY pl_xml_sts_route_in
IS
  /*===========================================================================================================
  -- Package Body
  -- pl_xml_sts_route_in
  --
  -- Description
  --
  --   This package is to replace PI for STS Route Inbound using SOAP/XML
  --
  -- Modification History
  --
  -- Date                User                  Version            Defect  Comment
  -- 08/10/18          mcha1213                   1.0              Initial Creation
  --
  --                                                             9/2/20 fix stop close with event type tag issues

  ============================================================================================================*/

    l_error_msg         VARCHAR2(2000);
  l_error_code        VARCHAR2(100);

    c_limit             number :=1000;

PROCEDURE check_webservice(i_interface_ref_doc  IN VARCHAR2,
                           o_active_flag        OUT VARCHAR2,
                           o_url_port           OUT VARCHAR2,
                           o_reason             OUT VARCHAR2)
/*===========================================================================================================
  -- Procedure
  -- Check Webservice
  --
  -- Description
  --   This procedure verifies whether the webservices are active or turned off and gets the ip address
  --   of the SAE.
  --
  --
  -- Modification History
  --
  -- Date                User                  Version            Defect  Comment
  -- 8/1/18             mcha1213                 1.0              Initial Creation
  ============================================================================================================*/
IS
l_interface_ref_doc   VARCHAR2(10);
l_url                 VARCHAR2(20);
l_port                VARCHAR2(10);
l_sys_config_val      VARCHAR2(1);
l_active_flag         VARCHAR2(1);
l_reason              VARCHAR2(100);

BEGIN

l_interface_ref_doc := i_interface_ref_doc;
----Checking Whether the Interfaces between SAE and Sysco are Active or not----

        BEGIN

          SELECT config_flag_val
            INTO l_sys_config_val
            FROM sys_config
           WHERE config_flag_name = 'MX_INTERFACE_ACTIVE';

        EXCEPTION
         WHEN OTHERS THEN
          pl_text_log.ins_msg('INFO', 'pl_xml_matrix_out',
                     'Error Getting the Flag from sys_config',
                      NULL, NULL);
          RAISE;---Alert
        END;


----------Checking whether the Actual interface is turned on or not-------------
        IF l_sys_config_val = 'Y' THEN

            BEGIN
              SELECT active_flag
                INTO l_active_flag
                FROM matrix_interface_maint
               WHERE interface_name = l_interface_ref_doc;

            EXCEPTION
             WHEN OTHERS THEN
              pl_text_log.ins_msg('INFO', 'pl_xml_matrix_out',
                     'Error Getting the Flag from matrix_interface_maint',
                      NULL, NULL);
              RAISE;---Alert
            END;

-----------Obtaining Required credentials for webservices to matrix-------------
            IF l_active_flag = 'Y' THEN

               BEGIN

                  SELECT host, lower_port
                    INTO l_url, l_port
                    FROM dba_network_acls
                   WHERE acl like '%symbotic_webservice%';

               EXCEPTION
                WHEN OTHERS THEN
                 pl_text_log.ins_msg('INFO', 'pl_xml_matrix_out',
                     'Error Getting the data from dba_network_acls',
                      NULL, NULL);
                 RAISE;--ALERT
               END;

---------------Generating the o_url_port for the interface----------------------

               o_url_port     := 'http://'||l_url||':'||l_port||'/CaseManager';
               o_active_flag  := 'Y';
               o_reason       := NULL;

            ELSE

               o_url_port     := NULL;
               o_active_flag  := 'N';
               o_reason       := 'Interface Maintenance Flag is OFF for '||l_interface_ref_doc;

            END IF;

        ELSE

           o_url_port     := NULL;
           o_active_flag  := 'N';
           o_reason       := 'Sysconfig for the Symbotic Interface is OFF';

        END IF;
END check_webservice;


/*
FUNCTION process_route_in_noparam
    return number


IS
  ------------------------------soap_api parameters-----------------------------
  l_request           soap_api.t_request;
  l_response          soap_api.t_response;
  --l_return        VARCHAR2(32767);
  l_url               VARCHAR2(100);
  l_namespace         VARCHAR2(1000);
  l_method            VARCHAR2(100);
  l_soap_action       VARCHAR2(100);
  --l_result_name   VARCHAR2(32767);
  --------------------------------Local Variables-------------------------------
  l_xml               XMLTYPE;
  l_xml_build         CLOB;
  l_sys_msg_id        NUMBER(10):= NULL;
  l_label_type        VARCHAR2(4);
  l_timestamp         VARCHAR2(100);
  l_record_status     VARCHAR2(1);
  web_exception       EXCEPTION;
  l_error_msg         VARCHAR2(2000);
  l_error_code        VARCHAR2(100);
  l_retry_count       NUMBER;
  l_count             NUMBER;
  l_interface_flag    VARCHAR2(1);
  l_reason            VARCHAR2(100);

  l_route_in sts_routein_obj_tab;
  c_limit             number :=1000;

  seq number := 9999999;

  rtn number;



  CURSOR c_route_in
  IS
  SELECT
     sts_routein_obj(
     xt.dcid, xt.routeid, to_date( replace(xt.scheduleddate, 'T', ' ') , 'YYYY-MM-DD')
        --replace (xt.scheduleddate, 'T', ' ') sched_date,  --, xt.scheduleddate --xt.stop_1,
         ,st.sid, st.a_stop_no, st.manifest_no, st.driver_sign_ind
         )
       --, ev.ev_type
      -- , ip.ip_desc, ip.ip_value
  FROM   xml_tab2 x
    cross join
       XMLTABLE('$d/*:DriverProExport/*:exportData/*:DriverProExport/*:Routes/*:Route'
         PASSING x.xml_data as "d"
         COLUMNS
           DCID     VARCHAR2(4)  PATH '*:DCID',
           RouteID     VARCHAR2(10) PATH '*:RouteID',
           ScheduledDate  VARCHAR2(11) PATH '*:ScheduledDate',
           Stop_1       xmlType path '*:Stops',
           Input_1      xmlType path '*:Inputs'
         ) xt
     cross join
       xmltable('$d/*:Stops/*:Stop'
         passing xt.Stop_1 as "d"
         columns
         SID      varchar2(14) PATH '*:StopID',
         a_stop_no   number(7,2) path '*:AlternateStopNumber',
         manifest_no number(7,0) path '*:ManifestNumber'
         ) st
      where x.id = 2;


BEGIN


  check_webservice(i_interface_ref_doc  => 'SYS03',
                   o_active_flag        => l_interface_flag,
                   o_url_port           => l_url,
                   o_reason             => l_reason);


   --IF l_interface_flag = 'Y' THEN


     --insert into xml_tab2(id, xml_data)
     --values (10, i_xml);



     open c_route_in;

     loop

       fetch c_route_in bulk collect into l_route_in
       limit c_limit;

       exit when l_route_in.count = 0;


        for i in 1 .. l_route_in.count
        loop


        insert into sts_route_in(sequence_no, interface_type, record_status, datetime
              ,dcid, route_no, route_date, cust_id, alt_stop_no, manifest_no)
           values (seq, 'STR', 'N', sysdate
                   ,l_route_in(i).dcid, l_route_in(i).route_no, l_route_in(i).route_date,
                   l_route_in(i).cust_id, l_route_in(i).alt_stop_no, l_route_in(i).manifest_no );

        seq := seq +1;


        --   dbms_output.put_line('dcid = '||l_route_in(i).dcid);


          -- insert into sts_route_in_mc(dcid, route_no, route_date, cust_id, alt_stop_no, manifest_no)
          -- values (l_route_in(i).dcid, l_route_in(i).route_no, l_route_in(i).route_date,
            --       l_route_in(i).cust_id, l_route_in(i).alt_stop_no, l_route_in(i).manifest_no );



          -- exit when l_route_in.count = 0;

        end loop;



     end loop;

     close c_route_in;

     commit;

     return 0;


   --END IF;


-- $d/*

EXCEPTION
WHEN web_exception THEN
    null;
WHEN OTHERS THEN
   l_error_code := SUBSTR(SQLERRM,1,100);

   l_error_msg:= 'Error: Undefined Exception';
   l_error_code:= SUBSTR(SQLERRM,1,100);
   pl_log.ins_msg(pl_log.ct_fatal_msg, 'process_sts_route_in', l_error_msg,
											SQLCODE, SQLERRM,
											'sts',
											'pl_xml_sts_route_in',

END process_route_in_noparam;
*/

PROCEDURE initiate_webservice(
    i_sys_msg_id IN NUMBER,
    i_ref_doc    IN VARCHAR2)
  /*===========================================================================================================
  -- Procedure
  -- initiate_webservice
  --
  -- Description
  --   This procedure calls the actual webservice based on ref_doc
  --
  -- Modification History
  --
  -- Date                User                  Version            Defect  Comment
  --                      1.0              Initial Creation
  ============================================================================================================*/
IS
  --------------------------------Local Variables-------------------------------
  l_sys_msg_id    NUMBER(10):= NULL;
  l_ref_doc       VARCHAR2(10);
BEGIN
-----------------------Initializing the local variables-------------------------
  l_sys_msg_id := i_sys_msg_id;
  l_ref_doc    := i_ref_doc;



END initiate_webservice;


PROCEDURE generate_xml is
   l_xml xmltype;
   --rtn number;
   --rtn driverproexportresponse_tab;
   rtn driverproexportresponse;
begin
   select xml_data
   into l_xml
   from xml_tab2
   where id = 12; --11; --10; --5; --9; --8;   --6;   --7;     --4;   --2;

   --rtn := process_route_in_string(l_xml);

   --rtn := DriverProExport(l_xml);

   rtn := DriverProExport(l_xml);


   dbms_output.put_line('VALID='||rtn.valid);
   dbms_output.put_line('MSG='||rtn.msg);

exception
WHEN OTHERS THEN
   l_error_code := SUBSTR(SQLERRM,1,100);

   l_error_msg:= 'Error: Undefined Exception';
   l_error_code:= SUBSTR(SQLERRM,1,100);
   pl_log.ins_msg(pl_log.ct_fatal_msg, 'pl_xml_sts_route_in', l_error_msg,
											SQLCODE, SQLERRM,
											'sts',
											'generate_xml',
											'N');

END generate_xml;

FUNCTION rt_type(seq_id IN NUMBER, r_path in varchar2)
      return number is

   p_cnt number;


begin

     SELECT count(*)
     into p_cnt
     from sts_route_xml_in
     where sequence_number = seq_id
     and XMLExists(r_path PASSING xml_data);
     --and XMLExists('/*:DriverProExport/*:exportData/*:DriverProExport/*:RouteUpdates/*:Route' PASSING xml_data);

     return p_cnt;

exception
   WHEN OTHERS THEN
      l_error_code := SUBSTR(SQLERRM,1,100);

      l_error_msg:= 'Error: Undefined Exception';
      l_error_code:= SUBSTR(SQLERRM,1,100);
      pl_log.ins_msg(pl_log.ct_fatal_msg, 'pl_xml_sts_route_in', l_error_msg,
											SQLCODE, SQLERRM,
											'sts',
											'rt_type',
											'N');

      raise;

END rt_type;

PROCEDURE get_rt_upd(seq_id in number, t_msg_id in sts_route_in.msg_id%type, l_path in varchar2) is

      CURSOR c_rt (seq_id number, l_path varchar2)
      IS
        SELECT
         sts_routein_rt_obj(xt.dcid, xt.routeid, to_date( replace(xt.scheduleddate, 'T', ' ') , 'YYYY-MM-DD HH24:MI:SS' ))
        FROM sts_route_xml_in  x
        cross join
         XMLTABLE(l_path --'$d/*:DriverProExport/*:exportData/*:DriverProExport/*:Routes/*:Route'
         PASSING x.xml_data as "d"
         COLUMNS
           DCID     VARCHAR2(4)  PATH '*:DCID',
           RouteID     VARCHAR2(10) PATH '*:RouteID',
           ScheduledDate  VARCHAR2(19) PATH '*:ScheduledDate'
         ) xt
      where x.record_status = 'N'
       and x.sequence_number = seq_id;

      l_route_in sts_routein_rt_tab;

      t_cnt number;

begin

       open c_rt(seq_id, l_path);

        loop

           fetch c_rt bulk collect into l_route_in
           limit c_limit;

           exit when l_route_in.count = 0;


           for i in 1 .. l_route_in.count
           loop



               insert into sts_route_in(msg_id, sequence_no, interface_type, record_status, datetime, record_type
                   ,dcid, route_no, route_date)
               values (t_msg_id, sts_route_xml_in_seq.nextval, 'STR', 'N', sysdate, 'RT'
                   ,l_route_in(i).dcid, l_route_in(i).route_no, l_route_in(i).route_date
                );

           end loop;



        end loop;

        close c_rt;

        --commit;

exception
WHEN OTHERS THEN
   l_error_code := SUBSTR(SQLERRM,1,100);

   l_error_msg:= 'Error: Undefined Exception';
   l_error_code:= SUBSTR(SQLERRM,1,100);
   pl_log.ins_msg(pl_log.ct_fatal_msg, 'pl_xml_sts_route_in', l_error_msg,
											SQLCODE, SQLERRM,
											'sts',
											'get_rt_upd',
											'N');

   raise;

END get_rt_upd;

PROCEDURE get_rectyperc_upd(seq_id in number, t_msg_id in sts_route_in.msg_id%type, l_path in varchar2) is

      CURSOR c_rt (seq_id number, l_path varchar2)
      IS
        SELECT
         sts_routein_rt_obj(xt.dcid, xt.routeid, to_date( replace(xt.scheduleddate, 'T', ' ') , 'YYYY-MM-DD HH24:MI:SS' ))
        FROM sts_route_xml_in  x
        cross join
         XMLTABLE(l_path --'$d/*:DriverProExport/*:exportData/*:DriverProExport/*:Routes/*:Route'
         PASSING x.xml_data as "d"
         COLUMNS
           DCID     VARCHAR2(4)  PATH '*:DCID',
           RouteID     VARCHAR2(10) PATH '*:RouteID',
           ScheduledDate  VARCHAR2(19) PATH '*:ScheduledDate'
         ) xt
      where x.record_status = 'N'
       and x.sequence_number = seq_id;

      l_route_in sts_routein_rt_tab;

      t_cnt number;

begin

       open c_rt(seq_id, l_path);

        loop

           fetch c_rt bulk collect into l_route_in
           limit c_limit;

           exit when l_route_in.count = 0;


           for i in 1 .. l_route_in.count
           loop



               insert into sts_route_in(msg_id, sequence_no, interface_type, record_status, datetime, record_type
                   ,dcid, route_no, route_date)
               values (t_msg_id, sts_route_xml_in_seq.nextval, 'STR', 'N', sysdate, 'RC'
                   ,l_route_in(i).dcid, l_route_in(i).route_no, l_route_in(i).route_date
                );

           end loop;



        end loop;

        close c_rt;

        --commit;

exception
WHEN OTHERS THEN
   l_error_code := SUBSTR(SQLERRM,1,100);

   l_error_msg:= 'Error: Undefined Exception';
   l_error_code:= SUBSTR(SQLERRM,1,100);
   pl_log.ins_msg(pl_log.ct_fatal_msg, 'pl_xml_sts_route_in', l_error_msg,
											SQLCODE, SQLERRM,
											'sts',
											'get_rectyperc_upd',
											'N');

   raise;

END get_rectyperc_upd;

PROCEDURE get_rectypesc_upd(seq_id in number, t_msg_id in sts_route_in.msg_id%type, l_path in varchar2) is

      CURSOR c_rt (seq_id number, l_path varchar2)
      IS
        SELECT
         sts_routein_rt_obj(xt.dcid, xt.routeid, to_date( replace(xt.scheduleddate, 'T', ' ') , 'YYYY-MM-DD HH24:MI:SS' ))
        FROM sts_route_xml_in  x
        cross join
         XMLTABLE(l_path --'$d/*:DriverProExport/*:exportData/*:DriverProExport/*:Routes/*:Route'
         PASSING x.xml_data as "d"
         COLUMNS
           DCID     VARCHAR2(4)  PATH '*:DCID',
           RouteID     VARCHAR2(10) PATH '*:RouteID',
           ScheduledDate  VARCHAR2(19) PATH '*:ScheduledDate'
         ) xt
      where x.record_status = 'N'
       and x.sequence_number = seq_id;

      l_route_in sts_routein_rt_tab;

      t_cnt number;

begin

       open c_rt(seq_id, l_path);

        loop

           fetch c_rt bulk collect into l_route_in
           limit c_limit;

           exit when l_route_in.count = 0;


           for i in 1 .. l_route_in.count
           loop



               insert into sts_route_in(msg_id, sequence_no, interface_type, record_status, datetime, record_type
                   ,dcid, route_no, route_date)
               values (t_msg_id, sts_route_xml_in_seq.nextval, 'STR', 'N', sysdate, 'SC'
                   ,l_route_in(i).dcid, l_route_in(i).route_no, l_route_in(i).route_date
                );

           end loop;



        end loop;

        close c_rt;

        --commit;

exception
WHEN OTHERS THEN
   l_error_code := SUBSTR(SQLERRM,1,100);

   l_error_msg:= 'Error: Undefined Exception';
   l_error_code:= SUBSTR(SQLERRM,1,100);
   pl_log.ins_msg(pl_log.ct_fatal_msg, 'pl_xml_sts_route_in', l_error_msg,
											SQLCODE, SQLERRM,
											'sts',
											'get_rectypesc_upd',
											'N');

   raise;

END get_rectypesc_upd;


PROCEDURE get_rj_upd(seq_id in number, t_msg_id in sts_route_in.msg_id%type, l_path in varchar2) is

      CURSOR c_rj (seq_id number, l_path varchar2)
      IS
      SELECT
     sts_routein_rj_obj(xt.dcid, xt.routeid,
     to_date( replace(xt.scheduleddate, 'T', ' ') , 'YYYY-MM-DD HH24:MI:SS' )
     --'YYYY-MM-DD') sched_date
         ,st.sid, st.a_stop_no, st.manifest_no
        , rj.prod_id, rj.return_reason_cd, rj.return_qty, rj.return_prod_id, rj.weight, rj.item_class
        , rj.invoice_num , rj.wms_item_type , rj.item_id , rj.quantity, rj.seq_no, rj.lot_no
	     ,rj.tax_per_item, rj.taxtot, rj.add_chg_per_item, rj.add_chg_tot, rj.credit_amt
	     ,rj.descript, rj.alt_prod_id, rj.price
        ,to_date( replace(rj.time_stamp, 'T', ' ') , 'YYYY-MM-DD HH24:MI:SS' )
         --,rj.time_stamp
         ,rj.action, rj.barcode, rj.multi_pick_ind	)
      FROM  sts_route_xml_in  x
      cross join
       XMLTABLE(l_path --'$d/*:DriverProExport/*:exportData/*:DriverProExport/*:Routes/*:Route'
         PASSING x.xml_data as "d"
         COLUMNS
           DCID     VARCHAR2(4)  PATH '*:DCID',
           RouteID     VARCHAR2(10) PATH '*:RouteID',
           ScheduledDate  VARCHAR2(19) PATH '*:ScheduledDate',
           Stop_1       xmlType path '*:Stops',
           Input_1      xmlType path '*:Inputs'
         ) xt
      cross join
       xmltable('$d/*:Stops/*:Stop'
         passing xt.Stop_1 as "d"
         columns
         SID      varchar2(14) PATH '*:StopID',
         a_stop_no   number path '*:AlternateStopNumber',
         manifest_no number path '*:ManifestNumber'
         ,Reject       xmlType path '*:RejectItems'
         ) st
       cross join
       xmltable('$d/*:RejectItems/*:RejectItem'
         passing st.Reject as "d"
         columns
         prod_id      varchar2(9) PATH '*:ProductID' default null
         ,return_reason_cd VARCHAR2(3) PATH '*:RejectReasonCode' default null
         ,return_qty NUMBER(3,0) PATH '*:RejectQuantity' default null
         ,return_prod_id VARCHAR2(9) PATH '*:ReturnedProductID' default null
         ,weight NUMBER(9,3)PATH '*:Weight' default null
         ,item_class VARCHAR2(2) PATH '*:ItemClass' default null
         ,invoice_num VARCHAR2(16) PATH '*:InvoiceNumber' default null
         ,wms_item_type VARCHAR2(4) PATH '*:UOM' default null
         ,item_id VARCHAR2(12) PATH '*:ItemID' default null
         ,quantity NUMBER(3,0) PATH '*:OriginalQuantity' default null
         ,seq_no VARCHAR2(3) PATH '*:InvoiceSequence' default null
         ,lot_no VARCHAR2(30) PATH '*:LotNumber' default null
	     ,tax_per_item NUMBER(9,2) PATH '*:TaxPerItem' default null
         ,taxtot NUMBER(9,2) PATH '*:TaxTotal' default null
         ,add_chg_per_item NUMBER(9,2) PATH '*:AddChgPerItem' default null
         ,add_chg_tot NUMBER(9,2) PATH '*:AddChgTotal' default null
         ,credit_amt NUMBER(9,2) PATH '*:CreditAmount' default null
	     ,descript VARCHAR2(40) PATH '*:ItemDescription' default null
         ,alt_prod_id VARCHAR2(20) PATH '*:AlternateProductID' default null
         ,price NUMBER(9,2) PATH '*:Price' default null
         ,time_stamp VARCHAR2(19) PATH '*:TimeStamp' default null
         ,action	VARCHAR2(1) PATH '*:Action' default null
         ,barcode	VARCHAR2(11) PATH '*:Barcode' default null
		 ,multi_pick_ind	VARCHAR2(6) PATH '*:MultiPickIndicator' default null
       ) rj
      where x.record_status = 'N'
       and x.sequence_number = seq_id;



      l_route_in sts_routein_rj_tab;

      t_cnt number;

begin

       open c_rj(seq_id, l_path);

        loop

           fetch c_rj bulk collect into l_route_in
           limit c_limit;

           exit when l_route_in.count = 0;


           for i in 1 .. l_route_in.count
           loop

              insert into sts_route_in(msg_id, sequence_no, interface_type, record_status, datetime, record_type
                   ,dcid, route_no, route_date, alt_stop_no, manifest_no
                   ,prod_id,return_reason_cd ,return_qty
	               ,return_prod_id, weight,item_class,invoice_num,wms_item_type
                   ,item_id,quantity,seq_no,lot_no,tax_per_item,tax_tot
                   ,add_chg_per_item,add_chg_tot,credit_amt,descript,alt_prod_id,price
                   ,time_stamp,action, barcode, multi_pick_ind  )
               values (t_msg_id, sts_route_xml_in_seq.nextval, 'STR', 'N', sysdate, 'RJ'
                   ,l_route_in(i).dcid, l_route_in(i).route_no, l_route_in(i).route_date, l_route_in(i).alt_stop_no, l_route_in(i).manifest_no
                   ,l_route_in(i).prod_id,l_route_in(i).return_reason_cd ,l_route_in(i).return_qty
	               ,l_route_in(i).return_prod_id, l_route_in(i).weight,l_route_in(i).item_class,l_route_in(i).invoice_num,l_route_in(i).wms_item_type
                   ,l_route_in(i).item_id,l_route_in(i).quantity,l_route_in(i).seq_no,l_route_in(i).lot_no,l_route_in(i).tax_per_item,l_route_in(i).taxtot
                   ,l_route_in(i).add_chg_per_item,l_route_in(i).add_chg_tot,l_route_in(i).credit_amt,l_route_in(i).descript,l_route_in(i).alt_prod_id
                   ,l_route_in(i).price,l_route_in(i).time_stamp,l_route_in(i).action
                   ,l_route_in(i).barcode
				   ,decode(l_route_in(i).multi_pick_ind, 'true', 'Y', 'false', 'N'));


           end loop;



        end loop;

        close c_rj;

        --commit;


exception
WHEN OTHERS THEN
   l_error_code := SUBSTR(SQLERRM,1,100);

   l_error_msg:= 'Error: Undefined Exception';
   l_error_code:= SUBSTR(SQLERRM,1,100);
   pl_log.ins_msg(pl_log.ct_fatal_msg, 'pl_xml_sts_route_in', l_error_msg,
											SQLCODE, SQLERRM,
											'sts',
											'get_rj_upd',
											'N');

   raise;

END get_rj_upd;

PROCEDURE get_et_upd(seq_id in number, t_msg_id in sts_route_in.msg_id%type, l_path varchar2) is

      CURSOR c_event (seq_id number)
      IS
      SELECT
      sts_routein_et_obj(
           xt.dcid, xt.routeid, to_date( replace(xt.scheduleddate, 'T', ' ') , 'YYYY-MM-DD HH24:MI:SS' )
       , ev.event_type, ev.cust_id, ev.prod_id, ev.compartment )
       FROM sts_route_xml_in x
       cross join
           XMLTABLE(l_path --'$d/*:DriverProExport/*:exportData/*:DriverProExport/*:Routes/*:Route'
            PASSING x.xml_data as "d"
            COLUMNS
               DCID     VARCHAR2(4)  PATH '*:DCID',
               RouteID     VARCHAR2(10) PATH '*:RouteID',
               ScheduledDate  VARCHAR2(19) PATH '*:ScheduledDate',
               Input_1      xmlType path '*:Inputs'
            ) xt
       cross join
            xmltable('$d/*:Inputs/*:Event'
                      passing xt.Input_1 as "d"
                      columns
                       event_type      varchar2(30) PATH '*:Type'
                       , cust_id       varchar2(14) PATH '*:StopID' default null
                       , prod_id       varchar2(14) PATH '*:ProductID' default null
                       , compartment   varchar2(1) PATH '*:Compartment' default null
                     ) ev
       where x.record_status = 'N'
       and x.sequence_number = seq_id;


   --l_xml xmltype;
   --rtn driverproexportresponse;

   l_route_in sts_routein_et_tab;

   t_cnt number;

begin

       open c_event(seq_id);

        loop

           fetch c_event bulk collect into l_route_in
           limit c_limit;

           exit when l_route_in.count = 0;


           for i in 1 .. l_route_in.count
           loop

               insert into sts_route_in(msg_id, sequence_no, interface_type, record_status, datetime, record_type
                   ,dcid, route_no, route_date, event_type, cust_id, prod_id, compartment)
               values (t_msg_id, sts_route_xml_in_seq.nextval, 'STR', 'N', sysdate, 'ET'
                   ,l_route_in(i).dcid, l_route_in(i).route_no, l_route_in(i).route_date,
                    l_route_in(i).event_type, l_route_in(i).cust_id, l_route_in(i).prod_id, l_route_in(i).compartment);

           end loop;



        end loop;

        close c_event;


        --commit;


exception
WHEN OTHERS THEN
   l_error_code := SUBSTR(SQLERRM,1,100);

   l_error_msg:= 'Error: Undefined Exception';
   l_error_code:= SUBSTR(SQLERRM,1,100);
   pl_log.ins_msg(pl_log.ct_fatal_msg, 'pl_xml_sts_route_in', l_error_msg,
											SQLCODE, SQLERRM,
											'sts',
											'get_et_upd',
											'N');

   raise;

END get_et_upd;

PROCEDURE get_st_upd(seq_id in number, t_msg_id in sts_route_in.msg_id%type, l_path in varchar2) is

  CURSOR c_st (seq_id number, l_path varchar2)
  IS
  SELECT
   sts_routein_st_obj(
     xt.dcid, xt.routeid --, to_date( replace(xt.scheduleddate, 'T', ' ') , 'YYYY-MM-DD')
     ,to_date( replace(xt.scheduleddate, 'T', ' ') , 'YYYY-MM-DD HH24:MI:SS' )
        --replace (xt.scheduleddate, 'T', ' ') sched_date,  --, xt.scheduleddate --xt.stop_1,
         ,st.sid, st.a_stop_no, st.manifest_no, st.driver_sign_ind, st.driver_id
         , st.deliv_scan_qty, st.deliv_manual_pick_qty
         , to_date( replace(st.arrival_time, 'T', ' ') , 'YYYY-MM-DD HH24:MI:SS' )
         --, st.arrival_time
         , to_date( replace(st.dept_time, 'T', ' ') , 'YYYY-MM-DD HH24:MI:SS' )
         --, st.dept_time
         , st.stop_wrk_duration
        , st.deliv_receipt_pdf
        --,null
       --  ,null,null,null
         , st.gps_latitude, st.gps_longititude --, st.gps_date_time
         , to_date( replace(st.gps_date_time, 'T', ' ') , 'YYYY-MM-DD HH24:MI:SS' )
		 , stop_correction
         )
  FROM sts_route_xml_in x
    cross join
       XMLTABLE(l_path --'$d/*:DriverProExport/*:exportData/*:DriverProExport/*:Routes/*:Route'
         PASSING x.xml_data as "d" --i_xml as "d"  -- x.xml_data as "d"
         COLUMNS
           DCID     VARCHAR2(4)  PATH '*:DCID' default null,
           RouteID     VARCHAR2(10) PATH '*:RouteID' default null,
           ScheduledDate  VARCHAR2(19) PATH '*:ScheduledDate' default null,
           Stop_1       xmlType path '*:Stops',
           Input_1      xmlType path '*:Inputs'
         ) xt
     cross join
       xmltable('$d/*:Stops/*:Stop'
         passing xt.Stop_1 as "d"
         columns
         SID      varchar2(14) PATH '*:StopID' default null,
         a_stop_no   number(7,2) path '*:AlternateStopNumber' default null,
         manifest_no number(7,0) path '*:ManifestNumber' default null,
         driver_sign_ind  varchar2(5) path '*:DriverSignIndicator' default null,
         driver_id varchar2(24) path '*:DriverID' default null,
         deliv_scan_qty varchar2(3) path '*:DelivScanQty' default null,
         deliv_manual_pick_qty varchar2(3) path '*:DelivManualPickQty' default null,
         arrival_time VARCHAR2(19) path '*:ArrivalTime' default null,
         dept_time VARCHAR2(19) path '*:DepartureTime' default null,
         stop_wrk_duration number path '*:StopWorkDuration' default null
         --,
         ,deliv_receipt_pdf varchar2(40) path '*:DeliveryReceiptPDF' default null
         ,gps_latitude varchar2(40) path '*:GPSLatitude' default null
         ,gps_longititude varchar2(40) path '*:GPSLongitude' default null
         ,gps_date_time VARCHAR2(19) path '*:GPSDateTime' default null
		 ,stop_correction VARCHAR2(6) path '*:StopCorrection' default null
         ) st
      where x.record_status = 'N'
         and x.sequence_number = seq_id;



      l_route_in sts_routein_st_tab;

      t_cnt number;

begin

       open c_st(seq_id, l_path);

     --open c_route_in(seq_id);

     loop

       fetch c_st bulk collect into l_route_in
       limit c_limit;

       exit when l_route_in.count = 0;


        for i in 1 .. l_route_in.count
        loop

         insert into sts_route_in(msg_id, sequence_no, interface_type, record_status, datetime, record_type
              ,dcid, route_no, route_date, cust_id, alt_stop_no, manifest_no
              , driver_sign_ind, driver_id, deliv_scan_qty, deliv_manual_pick_qty, arrival_time
              , dept_time, stop_wrk_duration, deliv_receipt_pdf
              , gps_latitude, gps_longitude, gps_date_time, stop_correction
              )
         values (t_msg_id, sts_route_xml_in_seq.nextval, 'STR', 'N', sysdate, nvl2(l_route_in(i).cust_id, 'ST', null)
                   ,l_route_in(i).dcid, l_route_in(i).route_no, l_route_in(i).route_date,
                   l_route_in(i).cust_id, l_route_in(i).alt_stop_no, l_route_in(i).manifest_no
                   , decode(l_route_in(i).driver_sign_ind, 'true', 'Y', 'false', 'N')
                   , l_route_in(i).driver_id, l_route_in(i).deliv_scan_qty, l_route_in(i).deliv_manual_pick_qty
                   , l_route_in(i).arrival_time, l_route_in(i).dept_time, l_route_in(i).stop_wrk_duration, l_route_in(i).deliv_receipt_pdf
                   , l_route_in(i).gps_latitude, l_route_in(i).gps_longtitude, l_route_in(i).gps_date_time
				   , decode(l_route_in(i).stop_correction, 'true', 'Y', 'false', 'N')
                   );

        end loop;



     end loop;

     close c_st;



exception
WHEN OTHERS THEN
   l_error_code := SUBSTR(SQLERRM,1,100);

   l_error_msg:= 'Error: Undefined Exception';
   l_error_code:= SUBSTR(SQLERRM,1,100);
   pl_log.ins_msg(pl_log.ct_fatal_msg, 'pl_xml_sts_route_in', l_error_msg,
											SQLCODE, SQLERRM,
											'sts',
											'get_st_upd',
											'N');

   -- this will end the whole process but we want to continue to do rest of the proc
   raise;

END get_st_upd;

PROCEDURE get_ip_upd(seq_id in number, t_msg_id in sts_route_in.msg_id%type, l_path varchar2) is

      CURSOR c_ip (seq_id number)
      IS
        SELECT
         sts_routein_ip_obj(xt.dcid, xt.routeid, to_date( replace(xt.scheduleddate, 'T', ' ') , 'YYYY-MM-DD HH24:MI:SS' )
        , ip.ip_desc, ip.ip_value
        , ip.ip_product_id, ip.ip_barcode, ip.ip_id1, ip.ip_id2, ip.ip_id3, ip.ip_id4
        , to_date( replace(ip.ip_time_stamp, 'T', ' ') , 'YYYY-MM-DD HH24:MI:SS' ))
        FROM sts_route_xml_in  x
        cross join
         XMLTABLE(l_path --'$d/*:DriverProExport/*:exportData/*:DriverProExport/*:Routes/*:Route'
         PASSING x.xml_data as "d"
         COLUMNS
           DCID     VARCHAR2(4)  PATH '*:DCID',
           RouteID     VARCHAR2(10) PATH '*:RouteID',
           ScheduledDate  VARCHAR2(19) PATH '*:ScheduledDate',
           Input_1      xmlType path '*:Inputs'
         ) xt
       cross join
          xmltable('$d/*:Inputs/*:Event'
          passing xt.Input_1 as "d"
          columns
            ev_type      varchar2(30) PATH '*:Type'
            ,Input_2      xmlType path '*:Input'
         ) ev
        cross join
       xmltable('$d/*:Input'
         passing ev.Input_2 as "d"
         columns
          ip_desc     varchar2(40) PATH '*:Description'
          , ip_value      varchar2(30) PATH '*:Value'
          , ip_product_id varchar2(9) path '*:ProductID' default null
          , ip_barcode varchar2(11) path '*:Barcode' default null
          , ip_id1 varchar2(30) path '*:ID1' default null
          , ip_id2 varchar2(30) path '*:ID2' default null
          , ip_id3 varchar2(30) path '*:ID3' default null
          , ip_id4 varchar2(30) path '*:ID4' default null
          , ip_time_stamp      VARCHAR2(19) PATH '*:TimeStamp' default null
         ) ip
      where x.record_status = 'N'
       and x.sequence_number = seq_id;



      --l_xml xmltype;

      --rtn driverproexportresponse;

      l_route_in sts_routein_ip_tab;

      t_cnt number;

begin

       open c_ip(seq_id);



        loop

           fetch c_ip bulk collect into l_route_in
           limit c_limit;

           exit when l_route_in.count = 0;


           for i in 1 .. l_route_in.count
           loop



               insert into sts_route_in(msg_id, sequence_no, interface_type, record_status, datetime, record_type
                   ,dcid, route_no, route_date, descript, input_value, prod_id,
                   barcode, id1, id2, id3, id4, time_stamp)
               values (t_msg_id, sts_route_xml_in_seq.nextval, 'STR', 'N', sysdate, 'IP'
                   ,l_route_in(i).dcid, l_route_in(i).route_no, l_route_in(i).route_date
                , l_route_in(i).descript, l_route_in(i).input_value, l_route_in(i).prod_id
                , l_route_in(i).bar_code, l_route_in(i).id1, l_route_in(i).id2
                , l_route_in(i).id3, l_route_in(i).id4, l_route_in(i).time_stamp
                );

           end loop;



        end loop;

        close c_ip;

        --commit;


exception
WHEN OTHERS THEN
   l_error_code := SUBSTR(SQLERRM,1,100);

   l_error_msg:= 'Error: Undefined Exception';
   l_error_code:= SUBSTR(SQLERRM,1,100);
   pl_log.ins_msg(pl_log.ct_fatal_msg, 'pl_xml_sts_route_in', l_error_msg,
											SQLCODE, SQLERRM,
											'sts',
											'get_ip_upd',
											'N');

   raise;

END get_ip_upd;

PROCEDURE get_sr_upd(seq_id in number, t_msg_id in sts_route_in.msg_id%type, l_path in varchar2) is

      CURSOR c_sr (seq_id number)
      IS
      select
        sts_routein_sr_obj(
        xt.dcid, xt.routeid,
        to_date( replace(xt.scheduleddate, 'T', ' ') , 'YYYY-MM-DD HH24:MI:SS' )
        ,st.sid, st.a_stop_no, st.manifest_no
        , sr.invoice_no, sr.prod_id, sr.quantity, sr.credit_ref_num
        , sr.orig_wms_item_type , sr.wms_item_type, sr.disposition
        , sr.return_reason_cd, sr.credit_amt, sr.weight, sr.return_prod_id
        , sr.return_qty, sr.tax_per_item, sr.tax_tot, sr.add_chg_per_item
        , sr.add_chg_tot, sr.price, sr.refusal_reason_cd )
      FROM sts_route_xml_in  x
      cross join
         XMLTABLE(l_path --'$d/*:DriverProExport/*:exportData/*:DriverProExport/*:Routes/*:Route'
         PASSING x.xml_data as "d"
         COLUMNS
           DCID     VARCHAR2(4)  PATH '*:DCID',
           RouteID     VARCHAR2(10) PATH '*:RouteID',
           ScheduledDate  VARCHAR2(19) PATH '*:ScheduledDate',
           Stop_1       xmlType path '*:Stops',
           Input_1      xmlType path '*:Inputs'
         ) xt
      cross join
         xmltable('$d/*:Stops/*:Stop'
         passing xt.Stop_1 as "d"
         columns
         SID      varchar2(14) PATH '*:StopID',
         a_stop_no   number path '*:AlternateStopNumber',
         manifest_no number path '*:ManifestNumber'
         ,schret       xmlType path '*:ScheduledReturns'
         ) st
      cross join
        xmltable('$d/*:ScheduledReturns/*:ScheduledReturn'
         passing st.schret as "d"
         columns
         invoice_no varchar2(16) PATH '*:PickupID' default null
         ,prod_id      varchar2(9) PATH '*:ProductID' default null
         ,quantity NUMBER(3,0) PATH '*:Quantity' default null
         ,credit_ref_num VARCHAR2(20) PATH '*:CreditReferenceID' default null
         ,orig_wms_item_type VARCHAR2(4) PATH '*:OriginalUOM' default null
         ,wms_item_type VARCHAR2(4) PATH '*:UOM' default null
         ,disposition VARCHAR2(3) PATH '*:Disposition' default null
         ,return_reason_cd VARCHAR2(3) PATH '*:ReturnReasonCode' default null
         ,credit_amt NUMBER(9,2) PATH '*:CreditAmount' default null
         ,weight NUMBER(9,3)PATH '*:Weight' default null
         ,return_prod_id VARCHAR2(9) PATH '*:ReturnedProductID' default null
         ,return_qty NUMBER(3,0) PATH '*:ReturnQuantity' default null
         ,tax_per_item NUMBER(9,2) PATH '*:TaxPerItem' default null
         ,tax_tot NUMBER(9,2) PATH '*:TaxTotal' default null
         ,add_chg_per_item NUMBER(9,2) PATH '*:AddChgPerItem' default null
         ,add_chg_tot NUMBER(9,2) PATH '*:AddChgTotal' default null
         ,price NUMBER(9,2) PATH '*:Price' default null
         ,refusal_reason_cd VARCHAR2(3) PATH '*:RefusalReasonCode' default null
       ) sr
       where x.record_status = 'N'
       and x.sequence_number = seq_id;

      l_route_in sts_routein_sr_tab;

      t_cnt number;

begin


       open c_sr(seq_id);



        loop

           fetch c_sr bulk collect into l_route_in
           limit c_limit;

           exit when l_route_in.count = 0;


           for i in 1 .. l_route_in.count
           loop

              insert into sts_route_in(msg_id, sequence_no, interface_type, record_status, datetime, record_type
                   ,dcid, route_no, route_date, alt_stop_no, manifest_no
                   , invoice_num
                   , prod_id, quantity, credit_ref_num
                   , orig_wms_item_type , wms_item_type, disposition
                   , return_reason_cd, credit_amt, weight, return_prod_id
                   , return_qty, tax_per_item, tax_tot, add_chg_per_item
                   , add_chg_tot, price, refusal_reason_cd)

               values (t_msg_id, sts_route_xml_in_seq.nextval, 'STR', 'N', sysdate, 'SR'
                   ,l_route_in(i).dcid, l_route_in(i).route_no, l_route_in(i).route_date, l_route_in(i).alt_stop_no, l_route_in(i).manifest_no
                   , l_route_in(i).invoice_no, l_route_in(i).prod_id, l_route_in(i).quantity, l_route_in(i).credit_ref_num
                   , l_route_in(i).orig_wms_item_type , l_route_in(i).wms_item_type, l_route_in(i).disposition
                   , l_route_in(i).return_reason_cd, l_route_in(i).credit_amt, l_route_in(i).weight, l_route_in(i).return_prod_id
                   , l_route_in(i).return_qty, l_route_in(i).tax_per_item, l_route_in(i).tax_tot, l_route_in(i).add_chg_per_item
                   , l_route_in(i).add_chg_tot, l_route_in(i).price, l_route_in(i).refusal_reason_cd);

           end loop;



        end loop;

        close c_sr;

        --commit;

exception
WHEN OTHERS THEN
   l_error_code := SUBSTR(SQLERRM,1,100);

   l_error_msg:= 'Error: Undefined Exception';
   l_error_code:= SUBSTR(SQLERRM,1,100);
   pl_log.ins_msg(pl_log.ct_fatal_msg, 'pl_xml_sts_route_in', l_error_msg,
											SQLCODE, SQLERRM,
											'sts',
											'get_sr_upd',
											'N');

   -- this will end the whole process but we want to continue to do rest of the proc
   raise;

END get_sr_upd;

PROCEDURE get_sp_upd(seq_id in number, t_msg_id in sts_route_in.msg_id%type, l_path in varchar2) is

      CURSOR c_sp (seq_id number)
      IS
      SELECT
     sts_routein_sp_obj(xt.dcid, xt.routeid,
     to_date( replace(xt.scheduleddate, 'T', ' ') , 'YYYY-MM-DD HH24:MI:SS' )
     --'YYYY-MM-DD') sched_date
         ,st.sid, st.a_stop_no, st.manifest_no
         ,sp.prod_id, sp.pack_qty_split, sp.refusal_reason_cd, sp.invoice_amt, sp.weight
         ,sp.high_qty, sp.qty_split, sp.invoice_num, sp.wms_item_type
         ,sp.quantity, sp.item_id, sp.seq_no, sp.weight, sp.tax_per_case
         ,sp.tax_tot, sp.credit_amt, sp.tax_per_item, sp.tax_tot_split
         ,sp.split_change_amt, sp.spc, sp.return_qty, sp.descript
         ,sp.alt_prod_id, sp.price, sp.price_split
        ,to_date( replace(sp.time_stamp, 'T', ' ') , 'YYYY-MM-DD HH24:MI:SS' )
         ,sp.action	)
      FROM  sts_route_xml_in  x
      cross join
       XMLTABLE(l_path --'$d/*:DriverProExport/*:exportData/*:DriverProExport/*:Routes/*:Route'
         PASSING x.xml_data as "d"
         COLUMNS
           DCID     VARCHAR2(4)  PATH '*:DCID',
           RouteID     VARCHAR2(10) PATH '*:RouteID',
           ScheduledDate  VARCHAR2(19) PATH '*:ScheduledDate',
           Stop_1       xmlType path '*:Stops'
         ) xt
      cross join
       xmltable('$d/*:Stops/*:Stop'
         passing xt.Stop_1 as "d"
         columns
         SID      varchar2(14) PATH '*:StopID',
         a_stop_no   number path '*:AlternateStopNumber',
         manifest_no number path '*:ManifestNumber'
         ,inroutespl       xmlType path '*:InRouteSplits'
         ) st
       cross join
       xmltable('$d/*:InRouteSplits/*:InRouteSplit'
         passing st.inroutespl as "d"
         columns
         prod_id      varchar2(9) PATH '*:ProductID' default null
         ,pack_qty_split number PATH '*:PackQuantitySplit' default null
         ,refusal_reason_cd varchar2(3) PATH '*:SplitReasonCode' default null
         ,invoice_amt NUMBER(9,2) PATH '*:InvoicedAmount' default null
         ,weight_adj NUMBER(9,3)PATH '*:AdjustedWeight' default null
         ,high_qty VARCHAR2(1) PATH '*:MultiPickIndicator' default null
         ,qty_split NUMBER PATH '*:InRouteSplitQuantity' default null
         ,invoice_num VARCHAR2(16) PATH '*:InvoiceNumber' default null
         ,wms_item_type VARCHAR2(4) PATH '*:UOM' default null
         ,quantity NUMBER(3,0) PATH '*:OriginalQuantity' default null
         ,item_id VARCHAR2(12) PATH '*:ItemID' default null
         ,seq_no VARCHAR2(3) PATH '*:InvoiceSequence' default null
         ,weight NUMBER(9,3) PATH '*:CaseWeight' default null
	     ,tax_per_case NUMBER(9,2) PATH '*:TaxPerCase' default null
         ,tax_tot NUMBER(9,2) PATH '*:CaseTaxTotal' default null
         ,credit_amt NUMBER(9,2) PATH '*:CaseCreditAmount' default null
         ,tax_per_item NUMBER(9,2) PATH '*:TaxPerSplit' default null
         ,tax_tot_split NUMBER(9,2) PATH '*:SplitTaxTotal' default null
	     ,split_change_amt NUMBER(9,2) PATH '*:SplitChargeAmount' default null
         ,spc NUMBER(4,0) PATH '*:SplitPerCase' default null
         ,return_qty NUMBER(3,0) PATH '*:PackQuantityReturned' default null
         ,descript VARCHAR2(40) PATH '*:ItemDescription' default null
         ,alt_prod_id VARCHAR2(20) PATH '*:AlternateProductID' default null
         ,price NUMBER(9,2) PATH '*:Price' default null
         ,price_split NUMBER(9,2) PATH '*:SplitPrice' default null
         ,time_stamp VARCHAR2(19) PATH '*:TimeStamp' default null
         ,action	VARCHAR2(1) PATH '*:Action' default null
       ) sp
      where x.record_status = 'N'
       and x.sequence_number = seq_id;

      l_route_in sts_routein_sp_tab;

      t_cnt number;

begin

       open c_sp(seq_id);

        loop

           fetch c_sp bulk collect into l_route_in
           limit c_limit;

           exit when l_route_in.count = 0;


           for i in 1 .. l_route_in.count
           loop

              insert into sts_route_in(msg_id, sequence_no, interface_type, record_status, datetime, record_type
                   ,dcid, route_no, route_date, alt_stop_no, manifest_no
                   ,prod_id,pack_qty_split,refusal_reason_cd,invoice_amt,weight_adj
                   --,multi
                   ,qty_split,invoice_num,wms_item_type,quantity
                   ,item_id,seq_no,weight,tax_per_case,tax_tot
                   ,credit_amt,tax_per_item,tax_tot_split,split_charge_amt
                   ,spc,return_qty,descript,alt_prod_id,price
                   ,price_split,time_stamp,action )
               values (t_msg_id, sts_route_xml_in_seq.nextval, 'STR', 'N', sysdate, 'SP'
                   ,l_route_in(i).dcid, l_route_in(i).route_no, l_route_in(i).route_date, l_route_in(i).alt_stop_no, l_route_in(i).manifest_no
                   ,l_route_in(i).prod_id,l_route_in(i).pack_qty_split,l_route_in(i).refusal_reason_cd,l_route_in(i).invoice_amt,l_route_in(i).weight_adj
                   --,l_route_in(i).multi_pick
                   ,l_route_in(i).qty_split,l_route_in(i).invoice_num,l_route_in(i).wms_item_type,l_route_in(i).quantity
                   ,l_route_in(i).item_id,l_route_in(i).seq_no,l_route_in(i).weight,l_route_in(i).tax_per_case,l_route_in(i).tax_tot
                   ,l_route_in(i).credit_amt,l_route_in(i).tax_per_item,l_route_in(i).tax_tot_split,l_route_in(i).split_charge_amt
                   ,l_route_in(i).spc,l_route_in(i).return_qty,l_route_in(i).descript,l_route_in(i).alt_prod_id,l_route_in(i).price
                   ,l_route_in(i).price_split,l_route_in(i).time_stamp,l_route_in(i).action );


           end loop;



        end loop;

        close c_sp;

        --commit;


exception
WHEN OTHERS THEN
   l_error_code := SUBSTR(SQLERRM,1,100);

   l_error_msg:= 'Error: Undefined Exception';
   l_error_code:= SUBSTR(SQLERRM,1,100);
   pl_log.ins_msg(pl_log.ct_fatal_msg, 'pl_xml_sts_route_in', l_error_msg,
											SQLCODE, SQLERRM,
											'sts',
											'get_sp_upd',
											'N');

   raise;

END get_sp_upd;

PROCEDURE get_iv_upd(seq_id in number, t_msg_id in sts_route_in.msg_id%type, l_path in varchar2) is

      CURSOR c_iv (seq_id number)
      IS
      select
        sts_routein_iv_obj(
        xt.dcid, xt.routeid,
        to_date( replace(xt.scheduleddate, 'T', ' ') , 'YYYY-MM-DD HH24:MI:SS' )
        ,st.sid, st.a_stop_no, st.manifest_no
        , iv.invoice_num, iv.pd_on_acct, iv.credit_ref_num, iv.deliv_receipt_pdf
        , iv.amt_due, pay.event_type, pay.credit_amt, pay.check_no )
      FROM sts_route_xml_in  x
      cross join
         XMLTABLE(l_path --'$d/*:DriverProExport/*:exportData/*:DriverProExport/*:Routes/*:Route'
         PASSING x.xml_data as "d"
         COLUMNS
           DCID     VARCHAR2(4)  PATH '*:DCID',
           RouteID     VARCHAR2(10) PATH '*:RouteID',
           ScheduledDate  VARCHAR2(19) PATH '*:ScheduledDate',
           Stop_1       xmlType path '*:Stops',
           Input_1      xmlType path '*:Inputs'
         ) xt
      cross join
         xmltable('$d/*:Stops/*:Stop'
         passing xt.Stop_1 as "d"
         columns
         SID      varchar2(14) PATH '*:StopID',
         a_stop_no   number path '*:AlternateStopNumber',
         manifest_no number path '*:ManifestNumber'
         ,invoices       xmlType path '*:Invoices'
         ) st
      cross join
        xmltable('$d/*:Invoices/*:Invoice'
         passing st.invoices as "d"
         columns
         invoice_num varchar2(16) PATH '*:InvoiceNumber' default null
         ,pd_on_acct      varchar2(10) PATH '*:PaidOnAccountIndicator' default null
         ,credit_ref_num VARCHAR2(20) PATH '*:CreditReferenceID' default null
         ,deliv_receipt_pdf VARCHAR2(40) PATH '*:InvoicePDF' default null
         ,amt_due NUMBER(9,2) PATH '*:AmountDue' default null
         ,payment_1       xmlType path '*:Payments'
       ) iv
      cross join
        xmltable('$d/*:Payments/*:Payment'
         passing iv.payment_1 as "d"
         columns
         event_type varchar2(30) PATH '*:Type' default null
         ,credit_amt NUMBER(9,2) PATH '*:Amount' default null
         ,check_no varchar2(12) path '*:CheckNumber'
       ) pay
       where x.record_status = 'N'
       and x.sequence_number = seq_id;

      l_route_in sts_routein_iv_tab;

      t_cnt number;

begin

       open c_iv(seq_id);



        loop

           fetch c_iv bulk collect into l_route_in
           limit c_limit;

           exit when l_route_in.count = 0;


           for i in 1 .. l_route_in.count
           loop

              insert into sts_route_in(msg_id, sequence_no, interface_type, record_status, datetime, record_type
                   ,dcid, route_no, route_date, alt_stop_no, manifest_no
                   , invoice_num , pd_on_acct, credit_ref_num, deliv_receipt_pdf, amt_due
                   , event_type, credit_amt, check_no
                   )
                values (t_msg_id, sts_route_xml_in_seq.nextval, 'STR', 'N', sysdate, 'IV'
                   ,l_route_in(i).dcid, l_route_in(i).route_no, l_route_in(i).route_date, l_route_in(i).alt_stop_no, l_route_in(i).manifest_no
                   , l_route_in(i).invoice_num
                   , decode(l_route_in(i).pd_on_acct, 'true', 'Y', 'false', 'N')
                   , l_route_in(i).credit_ref_num, l_route_in(i).deliv_receipt_pdf
                   , l_route_in(i).amt_due, l_route_in(i).event_type, l_route_in(i).credit_amt, l_route_in(i).check_no  );

           end loop;



        end loop;

        close c_iv;

        --commit;


exception
WHEN OTHERS THEN
   l_error_code := SUBSTR(SQLERRM,1,100);

   l_error_msg:= 'Error: Undefined Exception';
   l_error_code:= SUBSTR(SQLERRM,1,100);
   pl_log.ins_msg(pl_log.ct_fatal_msg, 'pl_xml_sts_route_in', l_error_msg,
											SQLCODE, SQLERRM,
											'sts',
											'get_iv_upd',
											'N');

   raise;

END get_iv_upd;

PROCEDURE get_at_upd(seq_id in number, t_msg_id in sts_route_in.msg_id%type, l_path in varchar2) is

      CURSOR c_at (seq_id number)
      IS
      SELECT
     sts_routein_at_obj(xt.dcid, xt.routeid,
     to_date( replace(xt.scheduleddate, 'T', ' ') , 'YYYY-MM-DD HH24:MI:SS' )
         ,st.sid, st.a_stop_no, st.manifest_no
         ,at.event_type, at.barcode, at.quantity
         ,to_date( replace(at.time_stamp, 'T', ' ') , 'YYYY-MM-DD HH24:MI:SS' )
         )
      FROM  sts_route_xml_in  x
      cross join
       XMLTABLE(l_path --'$d/*:DriverProExport/*:exportData/*:DriverProExport/*:Routes/*:Route'
         PASSING x.xml_data as "d"
         COLUMNS
           DCID     VARCHAR2(4)  PATH '*:DCID',
           RouteID     VARCHAR2(10) PATH '*:RouteID',
           ScheduledDate  VARCHAR2(19) PATH '*:ScheduledDate',
           Stop_1       xmlType path '*:Stops'
         ) xt
      cross join
       xmltable('$d/*:Stops/*:Stop'
         passing xt.Stop_1 as "d"
         columns
         SID      varchar2(14) PATH '*:StopID',
         a_stop_no   number path '*:AlternateStopNumber',
         manifest_no number path '*:ManifestNumber'
         ,assettran       xmlType path '*:AssetTransactions'
         ) st
       cross join
       xmltable('$d/*:AssetTransactions/*:AssetTransaction'
         passing st.assettran as "d"
         columns
         event_type      varchar2(30) PATH '*:PickupType' default null
         ,barcode VARCHAR2(11) PATH '*:Barcode' default null
         ,quantity NUMBER(3,0) PATH '*:Quantity' default null
         ,time_stamp VARCHAR2(19) PATH '*:TimeStamp' default null
       ) at
      where x.record_status = 'N'
       and x.sequence_number = seq_id;



      l_route_in sts_routein_at_tab;

      t_cnt number;

begin



       open c_at(seq_id);



        loop

           fetch c_at bulk collect into l_route_in
           limit c_limit;

           exit when l_route_in.count = 0;


           for i in 1 .. l_route_in.count
           loop

              insert into sts_route_in(msg_id, sequence_no, interface_type, record_status, datetime, record_type
                   ,dcid, route_no, route_date, alt_stop_no, manifest_no
                   ,event_type, barcode, quantity, time_stamp)
               values (t_msg_id, sts_route_xml_in_seq.nextval, 'STR', 'N', sysdate, 'AT'
                   ,l_route_in(i).dcid, l_route_in(i).route_no, l_route_in(i).route_date, l_route_in(i).alt_stop_no, l_route_in(i).manifest_no
                   ,l_route_in(i).event_type,l_route_in(i).barcode,l_route_in(i).quantity,l_route_in(i).time_stamp  );
           end loop;

        end loop;

        close c_at;

        --commit;


exception
WHEN OTHERS THEN
   l_error_code := SUBSTR(SQLERRM,1,100);

   l_error_msg:= 'Error: Undefined Exception';
   l_error_code:= SUBSTR(SQLERRM,1,100);
   pl_log.ins_msg(pl_log.ct_fatal_msg, 'pl_xml_sts_route_in', l_error_msg,
											SQLCODE, SQLERRM,
											'sts',
											'get_at_upd',
											'N');

   raise;

END get_at_upd;

PROCEDURE get_cw_upd(seq_id in number, t_msg_id in sts_route_in.msg_id%type, l_path varchar2) is

      CURSOR c_cw (seq_id number)
      IS
      SELECT
      sts_routein_cw_obj(
     xt.dcid, xt.routeid,
     to_date( replace(xt.scheduleddate, 'T', ' ') , 'YYYY-MM-DD HH24:MI:SS' )
         ,st.sid, st.a_stop_no, st.manifest_no
         ,cw.item_id, cw.prod_id, cw.invoice_num, cw.seq_no
         ,cw.weight, cw.weight_adj, cw.tax_per_item
         ,cw.tax_tot, cw.credit_amt, cw.price
         )
      FROM  sts_route_xml_in  x
      cross join
       XMLTABLE(l_path --'$d/*:DriverProExport/*:exportData/*:DriverProExport/*:Routes/*:Route'
         PASSING x.xml_data as "d"
         COLUMNS
           DCID     VARCHAR2(4)  PATH '*:DCID',
           RouteID     VARCHAR2(10) PATH '*:RouteID',
           ScheduledDate  VARCHAR2(19) PATH '*:ScheduledDate',
           Stop_1       xmlType path '*:Stops'
         ) xt
      cross join
       xmltable('$d/*:Stops/*:Stop'
         passing xt.Stop_1 as "d"
         columns
         SID      varchar2(14) PATH '*:StopID',
         a_stop_no   number path '*:AlternateStopNumber',
         manifest_no number path '*:ManifestNumber'
         ,catchwt       xmlType path '*:CatchWeightAdjustments'
         ) st
       cross join
       xmltable('$d/*:CatchWeightAdjustments/*:CatchWeightAdjustment'
         passing st.catchwt as "d"
         columns
         item_id      varchar2(12) PATH '*:ItemID' default null
         ,prod_id      varchar2(9) PATH '*:ProductID' default null
         ,invoice_num VARCHAR2(16) PATH '*:InvoiceNumber' default null
         ,seq_no VARCHAR2(3) PATH '*:InvoiceSequence' default null
         ,weight number(9,3) PATH '*:OriginalWeight' default null
         ,weight_adj number(9,3) PATH '*:AdjustedWeight' default null
         ,tax_per_item number(9,2) PATH '*:TaxPerItem' default null
         ,tax_tot number(9,2) PATH '*:TaxTotal' default null
         ,credit_amt number(9,2) PATH '*:CreditAmount' default null
         ,price number(9,2) PATH '*:Price' default null
       ) cw
      where x.record_status = 'N'
       and x.sequence_number = seq_id;



      l_route_in sts_routein_cw_tab;

      t_cnt number;

begin



       open c_cw(seq_id);

        loop

           fetch c_cw bulk collect into l_route_in
           limit c_limit;

           exit when l_route_in.count = 0;


           for i in 1 .. l_route_in.count
           loop

              insert into sts_route_in(msg_id, sequence_no, interface_type, record_status, datetime, record_type
                   ,dcid, route_no, route_date, alt_stop_no, manifest_no
                   ,item_id, prod_id, invoice_num, seq_no
                   ,weight, weight_adj, tax_per_item
                   ,tax_tot, credit_amt, price)
               values (t_msg_id, sts_route_xml_in_seq.nextval, 'STR', 'N', sysdate, 'CW'
                   ,l_route_in(i).dcid, l_route_in(i).route_no, l_route_in(i).route_date, l_route_in(i).alt_stop_no, l_route_in(i).manifest_no
                   ,l_route_in(i).item_id, l_route_in(i).prod_id, l_route_in(i).invoice_num, l_route_in(i).seq_no
                   ,l_route_in(i).weight, l_route_in(i).weight_adj, l_route_in(i).tax_per_item
                   ,l_route_in(i).tax_tot, l_route_in(i).credit_amt, l_route_in(i).price);

           end loop;

        end loop;

        close c_cw;

        --commit;


exception
WHEN OTHERS THEN
   l_error_code := SUBSTR(SQLERRM,1,100);

   l_error_msg:= 'Error: Undefined Exception';
   l_error_code:= SUBSTR(SQLERRM,1,100);
   pl_log.ins_msg(pl_log.ct_fatal_msg, 'pl_xml_sts_route_in', l_error_msg,
											SQLCODE, SQLERRM,
											'sts',
											'get_cw_upd',
											'N');

   raise;

END get_cw_upd;

PROCEDURE get_tf_upd(seq_id in number, t_msg_id in sts_route_in.msg_id%type, l_path varchar2) is

      CURSOR c_tf (seq_id number)
      IS
      SELECT
      sts_routein_tf_obj(
     xt.dcid, xt.routeid,
     to_date( replace(xt.scheduleddate, 'T', ' ') , 'YYYY-MM-DD HH24:MI:SS' )
         ,st.sid, st.a_stop_no, st.manifest_no
         , to_date( replace(tf.time_stamp, 'T', ' ') , 'YYYY-MM-DD HH24:MI:SS' )
         ,tf.code, tf.auth_code, tf.deliv_receipt_pdf
         )
      FROM  sts_route_xml_in  x
      cross join
       XMLTABLE(l_path --'$d/*:DriverProExport/*:exportData/*:DriverProExport/*:Routes/*:Route'
         PASSING x.xml_data as "d"
         COLUMNS
           DCID     VARCHAR2(4)  PATH '*:DCID',
           RouteID     VARCHAR2(10) PATH '*:RouteID',
           ScheduledDate  VARCHAR2(19) PATH '*:ScheduledDate',
           Stop_1       xmlType path '*:Stops'
         ) xt
      cross join
       xmltable('$d/*:Stops/*:Stop'
         passing xt.Stop_1 as "d"
         columns
         SID      varchar2(14) PATH '*:StopID',
         a_stop_no   number path '*:AlternateStopNumber',
         manifest_no number path '*:ManifestNumber'
         ,transfers       xmlType path '*:Transfers'
         ) st
      cross join
       xmltable('$d/*:Transfers/*:Transfer'
         passing st.transfers as "d"
         columns
         time_stamp VARCHAR2(19) PATH '*:TTime' default null
         ,code      varchar2(3) PATH '*:TCode' default null
         ,auth_code VARCHAR2(6) PATH '*:TAuthCode' default null
         ,deliv_receipt_pdf VARCHAR2(40) PATH '*:TReceiptPDF' default null
       ) tf
      where x.record_status = 'N'
       and x.sequence_number = seq_id;

      l_route_in sts_routein_tf_tab;

      t_cnt number;

begin



       open c_tf(seq_id);



        loop

           fetch c_tf bulk collect into l_route_in
           limit c_limit;

           exit when l_route_in.count = 0;


           for i in 1 .. l_route_in.count
           loop

              insert into sts_route_in(msg_id, sequence_no, interface_type, record_status, datetime, record_type
                   ,dcid, route_no, route_date, alt_stop_no, manifest_no
                   ,time_stamp, code, auth_code, deliv_receipt_pdf)
               values (t_msg_id, sts_route_xml_in_seq.nextval, 'STR', 'N', sysdate, 'TF'
                   ,l_route_in(i).dcid, l_route_in(i).route_no, l_route_in(i).route_date, l_route_in(i).alt_stop_no, l_route_in(i).manifest_no
                   ,l_route_in(i).time_stamp, l_route_in(i).code, l_route_in(i).auth_code, l_route_in(i).deliv_receipt_pdf);

           end loop;

        end loop;

        close c_tf;

        --commit;


exception
WHEN OTHERS THEN
   l_error_code := SUBSTR(SQLERRM,1,100);

   l_error_msg:= 'Error: Undefined Exception';
   l_error_code:= SUBSTR(SQLERRM,1,100);
   pl_log.ins_msg(pl_log.ct_fatal_msg, 'pl_xml_sts_route_in', l_error_msg,
											SQLCODE, SQLERRM,
											'sts',
											'get_tf_upd',
											'N');

   raise;

END get_tf_upd;

PROCEDURE get_ti_upd(seq_id in number, t_msg_id in sts_route_in.msg_id%type, l_path varchar2) is

      CURSOR c_ti (seq_id number)
      is
      SELECT
         sts_routein_ti_obj(xt.dcid, xt.routeid, to_date( replace(xt.scheduleddate, 'T', ' ') , 'YYYY-MM-DD HH24:MI:SS' )
         , st.sid ,st.a_stop_no, st.manifest_no
         , ti.item_id, ti.prod_id, ti.quantity, null --, ti.pack_qty_split
         , ti.weight, ti.invoice_num, ti.seq_no)
        FROM sts_route_xml_in  x
        cross join
         XMLTABLE(l_path --'$d/*:DriverProExport/*:exportData/*:DriverProExport/*:Routes/*:Route'
         PASSING x.xml_data as "d"
         COLUMNS
           DCID     VARCHAR2(4)  PATH '*:DCID',
           RouteID     VARCHAR2(10) PATH '*:RouteID',
           ScheduledDate  VARCHAR2(19) PATH '*:ScheduledDate',
           Stop_1       xmlType path '*:Stops'
         ) xt
      cross join
         xmltable('$d/*:Stops/*:Stop'
         passing xt.Stop_1 as "d"
         columns
         SID      varchar2(14) PATH '*:StopID',
         a_stop_no   number path '*:AlternateStopNumber',
         manifest_no number path '*:ManifestNumber',
         Transfer_1      xmlType path '*:Transfers'
         ) st
       cross join
          xmltable('$d/*:Transfers/*:Transfer'                     --'$d/*:Transfer/*:TItems'
          passing st.Transfer_1 as "d"
          columns
            ti_1      xmlType path '*:TItems'
         ) tii
        cross join
       xmltable('$d/*:TItems/*:TI'
         passing tii.ti_1 as "d"
         columns
          item_id     varchar2(12) PATH '*:ItemID'
          , prod_id varchar2(9) path '*:ProductID' default null
          , quantity number(3,0) path '*:Quantity' default null
          , pack_qty_split number path '*:PackQtySplit' default null
          , weight number(3,0) path '*:Weight' default null
          , invoice_num varchar2(16) path '*:InvoiceNumber' default null
          , seq_no varchar2(3) path '*:InvoiceSequence' default null
         ) ti
      where x.record_status = 'N'
       and x.sequence_number = seq_id;

      l_route_in sts_routein_ti_tab;

      t_cnt number;

begin

       open c_ti(seq_id);

        loop

           fetch c_ti bulk collect into l_route_in
           limit c_limit;

           exit when l_route_in.count = 0;


           for i in 1 .. l_route_in.count
           loop



               insert into sts_route_in(msg_id, sequence_no, interface_type, record_status, datetime, record_type
                   ,dcid, route_no, route_date, cust_id, alt_stop_no, manifest_no
                   ,item_id, prod_id, quantity, pack_qty_split, weight
                   ,invoice_num, seq_no)

               values (t_msg_id, sts_route_xml_in_seq.nextval, 'STR', 'N', sysdate, 'TI'
                   ,l_route_in(i).dcid, l_route_in(i).route_no, l_route_in(i).route_date, l_route_in(i).cust_id
                   , l_route_in(i).alt_stop_no, l_route_in(i).manifest_no
                  ,l_route_in(i).item_id, l_route_in(i).prod_id, l_route_in(i).quantity, l_route_in(i).pack_qty_split
                  ,l_route_in(i).weight ,l_route_in(i).invoice_num, l_route_in(i).seq_no);


           end loop;



        end loop;

        close c_ti;

        --commit;

exception
WHEN OTHERS THEN
   l_error_code := SUBSTR(SQLERRM,1,100);

   l_error_msg:= 'Error: Undefined Exception';
   l_error_code:= SUBSTR(SQLERRM,1,100);
   pl_log.ins_msg(pl_log.ct_fatal_msg, 'pl_xml_sts_route_in', l_error_msg,
											SQLCODE, SQLERRM,
											'sts',
											'get_ti_upd',
											'N');

   raise;

END get_ti_upd;

PROCEDURE get_md_upd(seq_id in number, t_msg_id in sts_route_in.msg_id%type, l_path varchar2) is



      CURSOR c_di (seq_id number)
      IS
      SELECT
         sts_routein_di_obj(xt.dcid, xt.routeid,
         to_date( replace(xt.scheduleddate, 'T', ' ') , 'YYYY-MM-DD HH24:MI:SS' )
         ,st.sid, st.a_stop_no, st.manifest_no
         ,di.barcode ,di.prod_id ,di.quantity,di.weight
         ,di.item_class,di.invoice_num,di.wms_item_type
         ,di.item_id,di.seq_no,di.tax_per_item
         ,di.tax_tot,di.add_chg_per_item,di.add_chg_tot
         ,di.invoice_amt,di.spc,di.descript
         ,di.price,di.alt_prod_id
         ,to_date( replace(di.time_stamp, 'T', ' ') , 'YYYY-MM-DD HH24:MI:SS' )
         )
      FROM  sts_route_xml_in  x
      cross join
       XMLTABLE(l_path --'$d/*:DriverProExport/*:exportData/*:DriverProExport/*:Routes/*:Route'
         PASSING x.xml_data as "d"
         COLUMNS
           DCID     VARCHAR2(4)  PATH '*:DCID',
           RouteID     VARCHAR2(10) PATH '*:RouteID',
           ScheduledDate  VARCHAR2(19) PATH '*:ScheduledDate',
           Stop_1       xmlType path '*:Stops'
         ) xt
      cross join
       xmltable('$d/*:Stops/*:Stop'
         passing xt.Stop_1 as "d"
         columns
         SID      varchar2(14) PATH '*:StopID',
         a_stop_no   number path '*:AlternateStopNumber',
         manifest_no number path '*:ManifestNumber'
         ,mandi       xmlType path '*:ManualDelivItems'
         ) st
       cross join
       xmltable('$d/*:ManualDelivItems/*:ManualDelivItem'
         passing st.mandi as "d"
         columns
         barcode      varchar2(11) PATH '*:Barcode' default null
         ,prod_id     varchar2(9) PATH '*:ProductID' default null
         ,quantity NUMBER(3,0) PATH '*:Quantity' default null
         ,weight NUMBER(9,3) PATH '*:Weight' default null
         ,item_class VARCHAR2(2) PATH '*:ItemClass' default null
         ,invoice_num VARCHAR2(16) PATH '*:InvoiceNumber' default null
         ,wms_item_type VARCHAR2(4) PATH '*:UOM' default null
         ,item_id VARCHAR2(12) PATH '*:ItemID' default null
         ,seq_no VARCHAR2(3) PATH '*:InvoiceSequence' default null
         ,tax_per_item NUMBER(9,2) PATH '*:TaxPerItem' default null
         ,tax_tot NUMBER(9,2) PATH '*:TaxTotal' default null
         ,add_chg_per_item NUMBER(9,2) PATH '*:AddChgPerItem' default null
         ,add_chg_tot NUMBER(9,2) PATH '*:AddChgTotal' default null
         ,invoice_amt NUMBER(9,2) PATH '*:Amount' default null
         ,spc NUMBER(4,0) PATH '*:SplitsPerCase' default null
         ,descript VARCHAR2(40) PATH '*:ItemDescription' default null
         ,price NUMBER(9,2) PATH '*:Price' default null
         ,alt_prod_id VARCHAR2(20) PATH '*:AlternateProductID' default null
         ,time_stamp VARCHAR2(19) PATH '*:TimeStamp' default null
       ) di
      where x.record_status = 'N'
       and x.sequence_number = seq_id;

      l_route_in sts_routein_di_tab;

      t_cnt number;

begin

       open c_di(seq_id);

        loop

           fetch c_di bulk collect into l_route_in
           limit c_limit;

           exit when l_route_in.count = 0;


           for i in 1 .. l_route_in.count
           loop

              insert into sts_route_in(msg_id, sequence_no, interface_type, record_status, datetime, record_type
                   ,dcid, route_no, route_date, alt_stop_no, manifest_no
                   ,barcode ,prod_id ,quantity,weight
                   ,item_class,invoice_num,wms_item_type
                   ,item_id,seq_no,tax_per_item
                   ,tax_tot,add_chg_per_item,add_chg_tot
                   ,invoice_amt,spc,descript
                   ,price,alt_prod_id,time_stamp)
               values (t_msg_id, sts_route_xml_in_seq.nextval, 'STR', 'N', sysdate, 'MD'
                   ,l_route_in(i).dcid, l_route_in(i).route_no, l_route_in(i).route_date, l_route_in(i).alt_stop_no, l_route_in(i).manifest_no
                    ,l_route_in(i).barcode ,l_route_in(i).prod_id ,l_route_in(i).quantity,l_route_in(i).weight
                   ,l_route_in(i).item_class,l_route_in(i).invoice_num,l_route_in(i).wms_item_type
                   ,l_route_in(i).item_id,l_route_in(i).seq_no,l_route_in(i).tax_per_item
                   ,l_route_in(i).tax_tot,l_route_in(i).add_chg_per_item,l_route_in(i).add_chg_tot
                   ,l_route_in(i).invoice_amt,l_route_in(i).spc,l_route_in(i).descript
                   ,l_route_in(i).price,l_route_in(i).alt_prod_id,l_route_in(i).time_stamp);

           end loop;



        end loop;

        close c_di;

        --commit;


exception
WHEN OTHERS THEN
   l_error_code := SUBSTR(SQLERRM,1,100);

   l_error_msg:= 'Error: Undefined Exception';
   l_error_code:= SUBSTR(SQLERRM,1,100);
   pl_log.ins_msg(pl_log.ct_fatal_msg, 'pl_xml_sts_route_in', l_error_msg,
											SQLCODE, SQLERRM,
											'sts',
											'get_md_upd',
											'N');

   raise;

END get_md_upd;

PROCEDURE get_ca_upd(seq_id in number, t_msg_id in sts_route_in.msg_id%type, l_path varchar2) is

      CURSOR c_ca (seq_id number)
      IS
        SELECT
         sts_routein_ca_obj(xt.dcid, xt.routeid, to_date( replace(xt.scheduleddate, 'T', ' ') , 'YYYY-MM-DD HH24:MI:SS' )
         , null, null, null
         ,ca.barcode, ca.quantity
        , to_date( replace(ca.time_stamp, 'T', ' ') , 'YYYY-MM-DD HH24:MI:SS' ))
        FROM sts_route_xml_in  x
        cross join
         XMLTABLE(l_path --'$d/*:DriverProExport/*:exportData/*:DriverProExport/*:Routes/*:Route'
         PASSING x.xml_data as "d"
         COLUMNS
           DCID     VARCHAR2(4)  PATH '*:DCID',
           RouteID     VARCHAR2(10) PATH '*:RouteID',
           ScheduledDate  VARCHAR2(19) PATH '*:ScheduledDate',
           ca_1      xmlType path '*:CheckInAssets'
         ) xt
       cross join
          xmltable('$d/*:CheckInAssets/*:CheckInAsset'
          passing xt.ca_1 as "d"
          columns
            barcode      varchar2(11) PATH '*:Barcode'
            ,quantity    number(3,0) path '*:Quantity'
            , time_stamp      VARCHAR2(19) PATH '*:TimeStamp' default null
         ) ca
      where x.record_status = 'N'
       and x.sequence_number = seq_id;

      l_route_in sts_routein_ca_tab;

      t_cnt number;

begin

       open c_ca(seq_id);

        loop

           fetch c_ca bulk collect into l_route_in
           limit c_limit;

           exit when l_route_in.count = 0;


           for i in 1 .. l_route_in.count
           loop

               insert into sts_route_in(msg_id, sequence_no, interface_type, record_status, datetime, record_type
                   ,dcid, route_no, route_date, cust_id, alt_stop_no, manifest_no
                   ,barcode, quantity, time_stamp)
               values (t_msg_id, sts_route_xml_in_seq.nextval, 'STR', 'N', sysdate, 'CA'
                   ,l_route_in(i).dcid, l_route_in(i).route_no, l_route_in(i).route_date
                , l_route_in(i).cust_id, l_route_in(i).alt_stop_no, l_route_in(i).manifest_no
                   ,l_route_in(i).barcode, l_route_in(i).quantity, l_route_in(i).time_stamp);


           end loop;



        end loop;

        close c_ca;

        --commit;


exception
WHEN OTHERS THEN
   l_error_code := SUBSTR(SQLERRM,1,100);

   l_error_msg:= 'Error: Undefined Exception';
   l_error_code:= SUBSTR(SQLERRM,1,100);
   pl_log.ins_msg(pl_log.ct_fatal_msg, 'pl_xml_sts_route_in', l_error_msg,
											SQLCODE, SQLERRM,
											'sts',
											'get_ca_upd',
											'N');

   raise;

END get_ca_upd;


PROCEDURE get_ot_upd(seq_id in number, t_msg_id in sts_route_in.msg_id%type, l_path varchar2) is

      CURSOR c_ot (seq_id number)
      IS
      SELECT
         sts_routein_ot_obj(xt.dcid, xt.routeid,
         to_date( replace(xt.scheduleddate, 'T', ' ') , 'YYYY-MM-DD HH24:MI:SS' )
         ,st.sid, st.a_stop_no, st.manifest_no
         ,ot.seq_no, ot.prod_id, ot.wms_item_type, ot.descript
         ,ot.price, ot.invoice_num, ot.quantity
         ,ot.tax_per_item, ot.alt_prod_id, ot.weight
         ,ot.lot_no, ot.item_id, ot.barcode, ot.add_chg_tot
         ,ot.add_chg_desc
         ,to_date( replace(ot.time_stamp, 'T', ' ') , 'YYYY-MM-DD HH24:MI:SS' )
         , ot.action
         )
      FROM  sts_route_xml_in  x
      cross join
       XMLTABLE(l_path --'$d/*:DriverProExport/*:exportData/*:DriverProExport/*:Routes/*:Route'
         PASSING x.xml_data as "d"
         COLUMNS
           DCID     VARCHAR2(4)  PATH '*:DCID',
           RouteID     VARCHAR2(10) PATH '*:RouteID',
           ScheduledDate  VARCHAR2(19) PATH '*:ScheduledDate',
           Stop_1       xmlType path '*:Stops'
         ) xt
      cross join
       xmltable('$d/*:Stops/*:Stop'
         passing xt.Stop_1 as "d"
         columns
         SID      varchar2(14) PATH '*:StopID',
         a_stop_no   number path '*:AlternateStopNumber',
         manifest_no number path '*:ManifestNumber'
         ,sot       xmlType path '*:SalesOffTruck'
         ) st
       cross join
       xmltable('$d/*:SalesOffTruck/*:SaleOffTruck'
         passing st.sot as "d"
         columns
         seq_no VARCHAR2(3) PATH '*:SaleSequenceNumber' default null
         ,prod_id     varchar2(9) PATH '*:ProductID' default null
         ,wms_item_type VARCHAR2(4) PATH '*:ItemUOM' default null
         ,descript VARCHAR2(40) PATH '*:ItemDescription' default null
         ,price NUMBER(9,2) PATH '*:Price' default null
         ,invoice_num VARCHAR2(16) PATH '*:InvoiceNumber' default null
         ,quantity NUMBER(3,0) PATH '*:Quantity' default null
         ,tax_per_item NUMBER(9,2) PATH '*:TaxPerItem' default null
         ,alt_prod_id VARCHAR2(20) PATH '*:AlternateProductID' default null
         ,weight NUMBER(9,3) PATH '*:Weight' default null
         ,lot_no VARCHAR2(30) PATH '*:LotNumber' default null
         ,item_id VARCHAR2(12) PATH '*:ItemID' default null
         ,barcode      varchar2(11) PATH '*:Barcode' default null
         ,add_chg_tot NUMBER(9,2) PATH '*:AddChgAmount' default null
         ,add_chg_desc varchar2(50) PATH '*:AddChgDesc' default null
         ,time_stamp VARCHAR2(19) PATH '*:TimeStamp' default null
         ,action VARCHAR2(1) PATH '*:Action' default null
       ) ot
      where x.record_status = 'N'
       and x.sequence_number = seq_id;

      l_route_in sts_routein_ot_tab;

      t_cnt number;

begin

       open c_ot(seq_id);

        loop

           fetch c_ot bulk collect into l_route_in
           limit c_limit;

           exit when l_route_in.count = 0;


           for i in 1 .. l_route_in.count
           loop

              insert into sts_route_in(msg_id, sequence_no, interface_type, record_status, datetime, record_type
                   ,dcid, route_no, route_date, alt_stop_no, manifest_no
                   ,seq_no, prod_id, wms_item_type, descript
                   ,price, invoice_num, quantity
                   ,tax_per_item, alt_prod_id, weight
                   ,lot_no, item_id, barcode, add_chg_tot
                   ,add_chg_desc, time_stamp, action)
               values (t_msg_id, sts_route_xml_in_seq.nextval, 'STR', 'N', sysdate, 'OT'
                   ,l_route_in(i).dcid, l_route_in(i).route_no, l_route_in(i).route_date, l_route_in(i).alt_stop_no, l_route_in(i).manifest_no
                    ,l_route_in(i).seq_no, l_route_in(i).prod_id, l_route_in(i).wms_item_type, l_route_in(i).descript
                   ,l_route_in(i).price, l_route_in(i).invoice_num, l_route_in(i).quantity
                   ,l_route_in(i).tax_per_item, l_route_in(i).alt_prod_id, l_route_in(i).weight
                   ,l_route_in(i).lot_no, l_route_in(i).item_id, l_route_in(i).barcode, l_route_in(i).add_chg_tot
                   ,l_route_in(i).add_chg_desc, l_route_in(i).time_stamp, l_route_in(i).action);

           end loop;



        end loop;

        close c_ot;

        --commit;


exception
WHEN OTHERS THEN
   l_error_code := SUBSTR(SQLERRM,1,100);

   l_error_msg:= 'Error: Undefined Exception';
   l_error_code:= SUBSTR(SQLERRM,1,100);
   pl_log.ins_msg(pl_log.ct_fatal_msg, 'pl_xml_sts_route_in', l_error_msg,
											SQLCODE, SQLERRM,
											'sts',
											'get_ot_upd',
											'N');

   raise;

END get_ot_upd;



FUNCTION DriverProExport(i_xml IN XMLTYPE)
   return driverproexportresponse
  --    return driverproexportresponse_tab
  --    return number


  /*===========================================================================================================
  -- Procedure
  -- process_sts_route_in
  --
  -- Description
  --
  --   This procedure is used to pack the STS Route in data that is sent from STS
  --
  -- Modification History
  --
  -- Date                User                  Version            Defect  Comment
  -- 08/4/18        mcha1213             1.0              Initial Creation
  ============================================================================================================*/
IS
  ------------------------------soap_api parameters-----------------------------
  l_request           soap_api.t_request;
  l_response          soap_api.t_response;
  --l_return        VARCHAR2(32767);
  l_url               VARCHAR2(100);
  l_namespace         VARCHAR2(1000);
  l_method            VARCHAR2(100);
  l_soap_action       VARCHAR2(100);
  --l_result_name   VARCHAR2(32767);
  --------------------------------Local Variables-------------------------------
  l_xml               XMLTYPE;
  l_xml_build         CLOB;
  l_sys_msg_id        NUMBER(10):= NULL;
  l_label_type        VARCHAR2(4);
  l_timestamp         VARCHAR2(100);
  l_record_status     VARCHAR2(1);
  web_exception       EXCEPTION;
  l_error_msg         VARCHAR2(2000);
  l_error_code        VARCHAR2(100);
  l_retry_count       NUMBER;
  l_count             NUMBER;
  l_interface_flag    VARCHAR2(1);
  l_reason            VARCHAR2(100);

  l_route_in sts_routein_st_tab; --new_sts_routein_obj_tab;
  c_limit             number :=1000;

  seq_id   number;

    --seq number := 9999999;

    seq number;

    t_cnt integer;

    t_msg_id sts_route_in.msg_id%type;

    l_path varchar2(200);

    r_path varchar2(200);

	t_pi_switch  sys_config.config_flag_val%type;

    no_xml_data_err exception;

	pi_switch_on_err    exception;
	l_host_name v$instance.host_name%type;


BEGIN

  /*
  check_webservice(i_interface_ref_doc  => 'SYS03',
                   o_active_flag        => l_interface_flag,
                   o_url_port           => l_url,
                   o_reason             => l_reason);
   */

   --IF l_interface_flag = 'Y' THEN


     --insert into xml_tab2(id, xml_data)
     --values (10, i_xml);

     /*
	 --xmltype(
        bfilename('/home2/prp/test', 'SC1012_STS_RouteClose.xml'),
        nls_charset_id ('AL32UTF8')
        )
        );
     */

     --tab2_id := 11;

    DBMS_OUTPUT.PUT_LINE ('in rs237dev pl_xml_sts_route_in.driverproexport ');

          pl_log.ins_msg('INFO', 'pl_xml_sts_route_in',
                        'in pl_xml_sts_route_in.driverproexport',
                         SQLCODE, SQLERRM, 'STS', 'driverproexport', 'N');

      select host_name
	  into l_host_name
	  from v$instance;

     select sys_guid()
     into t_msg_id
     from dual;

      if i_xml is null then
               pl_log.ins_msg('INFO', 'pl_xml_sts_route_in',
                        'in pl_xml_sts_route_in.driverproexport and i_xml is null',
                         SQLCODE, SQLERRM, 'STS', 'driverproexport', 'N');

            raise no_xml_data_err;
      end if;


         -- if config_flag_val = 'Y' it means PI is off
      select config_flag_val
		 into t_pi_switch
         from sys_config
         where APPLICATION_FUNC = 'DRIVER-CHECK-IN'
         and CONFIG_FLAG_NAME = 'STS_SWMS_ON';

	  if t_pi_switch = 'N' then
	     pl_log.ins_msg('INFO', 'pl_xml_sts_route_in',
                        'in pl_xml_sts_route_in.driverproexport and PI switch is ON',
                         SQLCODE, SQLERRM, 'STS', 'driverproexport', 'N');
         raise pi_switch_on_err;
	  end if;

      /*
      select host_name
	  into l_host_name
	  from v$instance;

      select sys_guid()
      into t_msg_id
      from dual;
       */

     select sts_route_xml_in_seq.nextval
     into seq_id
     from dual;

     dbms_output.put_line('in DriverProExport before insert into sts_route_xml_in for seq_id '||to_char(seq_id));

           pl_log.ins_msg('INFO', 'pl_xml_sts_route_in',
                        'in pl_xml_sts_route_in.driverproexport before insert into sts_route_xml_in',
                         SQLCODE, SQLERRM, 'STS', 'driverproexport', 'N');

     insert into sts_route_xml_in(sequence_number, msg_id, record_status, xml_data)
     values (seq_id, t_msg_id, 'N', i_xml);

     commit;

     -- rt

     r_path := '/*:DriverProExport/*:Routes/*:Route';

	 -- 11/1/18 r_path := '/*:DriverProExport/*:exportData/*:DriverProExport/*:Routes/*:Route';

     t_cnt := rt_type(seq_id, r_path);

     if (t_cnt >= 1) then
       -- get_rt(seq_id, t_msg_id);

       dbms_output.put_line('get_rt_upd routes t_cnt = '||to_char(t_cnt));
       l_path := '$d/*:DriverProExport/*:Routes/*:Route';
	   --l_path := '$d/*:DriverProExport/*:exportData/*:DriverProExport/*:Routes/*:Route';
       get_rt_upd(seq_id, t_msg_id, l_path);
       get_rectyperc_upd(seq_id, t_msg_id, l_path);
     end if;

     r_path := '/*:DriverProExport/*:RouteUpdates/*:Route';

	 -- r_path := '/*:DriverProExport/*:exportData/*:DriverProExport/*:RouteUpdates/*:Route';


     t_cnt := rt_type(seq_id, r_path);

     --dbms_output.put_line('in driverProExport before call st routeupdates stop t_cnt = '||to_char(t_cnt));

     if (t_cnt >= 1) then
       -- get_rt(seq_id, t_msg_id);
       dbms_output.put_line('get_rt_upd routeupdates t_cnt = '||to_char(t_cnt));
       l_path := '$d/*:DriverProExport/*:RouteUpdates/*:Route';
	   --l_path := '$d/*:DriverProExport/*:exportData/*:DriverProExport/*:RouteUpdates/*:Route';
          --'/*:DriverProExport/*:exportData/*:DriverProExport/*:RouteUpdates/*:Route';
       get_rt_upd(seq_id, t_msg_id, l_path);
     end if;

     -- rt end

     -- st

	 r_path := '/*:DriverProExport/*:Routes/*:Route/*:Stops/*:Stop';

     -- r_path := '/*:DriverProExport/*:exportData/*:DriverProExport/*:Routes/*:Route/*:Stops/*:Stop';

     t_cnt := rt_type(seq_id, r_path);


     if (t_cnt >= 1) then
       -- get_rt(seq_id, t_msg_id);
       dbms_output.put_line('get_st_upd routes t_cnt = '||to_char(t_cnt));
       l_path := '$d/*:DriverProExport/*:Routes/*:Route';
	   --l_path := '$d/*:DriverProExport/*:exportData/*:DriverProExport/*:Routes/*:Route';
          --'/*:DriverProExport/*:exportData/*:DriverProExport/*:RouteUpdates/*:Route';
       get_st_upd(seq_id, t_msg_id, l_path);
     end if;

     r_path := '/*:DriverProExport/*:RouteUpdates/*:Route/*:Stops/*:Stop';
     --r_path := '/*:DriverProExport/*:exportData/*:DriverProExport/*:RouteUpdates/*:Route/*:Stops/*:Stop';

     t_cnt := rt_type(seq_id, r_path);

     if (t_cnt >= 1) then
       -- get_rt(seq_id, t_msg_id);
       dbms_output.put_line('get_st_upd routeupdates t_cnt = '||to_char(t_cnt));
       l_path := '$d/*:DriverProExport/*:RouteUpdates/*:Route';
	   --l_path := '$d/*:DriverProExport/*:exportData/*:DriverProExport/*:RouteUpdates/*:Route';
          --'/*:DriverProExport/*:exportData/*:DriverProExport/*:RouteUpdates/*:Route';
       get_st_upd(seq_id, t_msg_id, l_path);
     end if;

     -- end st

     -- IV


     r_path := '/*:DriverProExport/*:Routes/*:Route/*:Stops/*:Stop/*:Invoices/*:Invoice';
	 --r_path := '/*:DriverProExport/*:exportData/*:DriverProExport/*:Routes/*:Route/*:Stops/*:Stop/*:Invoices/*:Invoice';

     t_cnt := rt_type(seq_id, r_path);


     if (t_cnt >= 1) then
       -- get_rt(seq_id, t_msg_id);
       dbms_output.put_line('get_iv_upd routes t_cnt = '||to_char(t_cnt));
       l_path := '$d/*:DriverProExport/*:Routes/*:Route';
	   --l_path := '$d/*:DriverProExport/*:exportData/*:DriverProExport/*:Routes/*:Route';
          --'/*:DriverProExport/*:exportData/*:DriverProExport/*:RouteUpdates/*:Route';
       get_iv_upd(seq_id, t_msg_id, l_path);
     end if;

     r_path := '/*:DriverProExport/*:RouteUpdates/*:Route/*:Stops/*:Stop/*:Invoices/*:Invoice';
	 --r_path := '/*:DriverProExport/*:exportData/*:DriverProExport/*:RouteUpdates/*:Route/*:Stops/*:Stop/*:Invoices/*:Invoice';

     t_cnt := rt_type(seq_id, r_path);


     if (t_cnt >= 1) then
       -- get_rt(seq_id, t_msg_id);
       dbms_output.put_line('get_iv_upd routeupdates t_cnt = '||to_char(t_cnt));
       l_path := '$d/*:DriverProExport/*:RouteUpdates/*:Route';
	   --l_path := '$d/*:DriverProExport/*:exportData/*:DriverProExport/*:RouteUpdates/*:Route';
          --'/*:DriverProExport/*:exportData/*:DriverProExport/*:RouteUpdates/*:Route';
       get_iv_upd(seq_id, t_msg_id, l_path);
     end if;

     -- end IV

     -- sr

     r_path := '/*:DriverProExport/*:Routes/*:Route/*:Stops/*:Stop/*:ScheduledReturns/*:ScheduledReturn';
	 --r_path := '/*:DriverProExport/*:exportData/*:DriverProExport/*:Routes/*:Route/*:Stops/*:Stop/*:ScheduledReturns/*:ScheduledReturn';

     t_cnt := rt_type(seq_id, r_path);


     if (t_cnt >= 1) then
       -- get_rt(seq_id, t_msg_id);
       dbms_output.put_line('get_sr_upd routes t_cnt = '||to_char(t_cnt));
       l_path := '$d/*:DriverProExport/*:Routes/*:Route';
	   --l_path := '$d/*:DriverProExport/*:exportData/*:DriverProExport/*:Routes/*:Route';
          --'/*:DriverProExport/*:exportData/*:DriverProExport/*:RouteUpdates/*:Route';
       get_sr_upd(seq_id, t_msg_id, l_path);
     end if;

     r_path := '/*:DriverProExport/*:RouteUpdates/*:Route/*:Stops/*:Stop/*:ScheduledReturns/*:ScheduledReturn';
     --r_path := '/*:DriverProExport/*:exportData/*:DriverProExport/*:RouteUpdates/*:Route/*:Stops/*:Stop/*:ScheduledReturns/*:ScheduledReturn';

     t_cnt := rt_type(seq_id, r_path);


     if (t_cnt >= 1) then
       -- get_rt(seq_id, t_msg_id);
       dbms_output.put_line('get_sr_upd routes t_cnt = '||to_char(t_cnt));
       l_path := '$d/*:DriverProExport/*:RouteUpdates/*:Route';
	   --l_path := '$d/*:DriverProExport/*:exportData/*:DriverProExport/*:Routes/*:Route';
          --'/*:DriverProExport/*:exportData/*:DriverProExport/*:RouteUpdates/*:Route';
       get_sr_upd(seq_id, t_msg_id, l_path);
     end if;

     -- end sr

     -- rj

     r_path := '/*:DriverProExport/*:Routes/*:Route/*:Stops/*:Stop/*:RejectItems/*:RejectItem';
	 --r_path := '/*:DriverProExport/*:exportData/*:DriverProExport/*:Routes/*:Route/*:Stops/*:Stop/*:RejectItems/*:RejectItem';

     t_cnt := rt_type(seq_id, r_path);

     if (t_cnt >= 1) then
       -- get_rt(seq_id, t_msg_id);
       l_path := '$d/*:DriverProExport/*:Routes/*:Route';
	   --l_path := '$d/*:DriverProExport/*:exportData/*:DriverProExport/*:Routes/*:Route';
          --'/*:DriverProExport/*:exportData/*:DriverProExport/*:RouteUpdates/*:Route';
       dbms_output.put_line('get_rj_upd routes t_cnt = '||to_char(t_cnt));
       get_rj_upd(seq_id, t_msg_id, l_path);
     end if;

     r_path := '/*:DriverProExport/*:RouteUpdates/*:Route/*:Stops/*:Stop/*:RejectItems/*:RejectItem';
	 --r_path := '/*:DriverProExport/*:exportData/*:DriverProExport/*:RouteUpdates/*:Route/*:Stops/*:Stop/*:RejectItems/*:RejectItem';

     t_cnt := rt_type(seq_id, r_path);

     if (t_cnt >= 1) then
       -- get_rt(seq_id, t_msg_id);
       l_path := '$d/*:DriverProExport/*:RouteUpdates/*:Route';
	   --l_path := '$d/*:DriverProExport/*:exportData/*:DriverProExport/*:RouteUpdates/*:Route';
          --'/*:DriverProExport/*:exportData/*:DriverProExport/*:RouteUpdates/*:Route';
       dbms_output.put_line('get_rj_upd routeupdates t_cnt = '||to_char(t_cnt));
       get_rj_upd(seq_id, t_msg_id, l_path);
     end if;

     -- end rj

     -- sp

     r_path := '/*:DriverProExport/*:Routes/*:Route/*:Stops/*:Stop/*:InRouteSplits/*:InRouteSplit';
	 --r_path := '/*:DriverProExport/*:exportData/*:DriverProExport/*:Routes/*:Route/*:Stops/*:Stop/*:InRouteSplits/*:InRouteSplit';

     t_cnt := rt_type(seq_id, r_path);


     if (t_cnt >= 1) then
       -- get_rt(seq_id, t_msg_id);
       dbms_output.put_line('get_sp_upd routes t_cnt = '||to_char(t_cnt));
       l_path := '$d/*:DriverProExport/*:Routes/*:Route';
	   --l_path := '$d/*:DriverProExport/*:exportData/*:DriverProExport/*:Routes/*:Route';
          --'/*:DriverProExport/*:exportData/*:DriverProExport/*:RouteUpdates/*:Route';
       get_sp_upd(seq_id, t_msg_id, l_path);
     end if;

     r_path := '/*:DriverProExport/*:RouteUpdates/*:Route/*:Stops/*:Stop/*:InRouteSplits/*:InRouteSplit';
     --r_path := '/*:DriverProExport/*:exportData/*:DriverProExport/*:RouteUpdates/*:Route/*:Stops/*:Stop/*:InRouteSplits/*:InRouteSplit';

     t_cnt := rt_type(seq_id, r_path);

     if (t_cnt >= 1) then

       dbms_output.put_line('get_sp_upd routeupdates t_cnt = '||to_char(t_cnt));
       l_path := '$d/*:DriverProExport/*:RouteUpdates/*:Route';
	   --l_path := '$d/*:DriverProExport/*:exportData/*:DriverProExport/*:RouteUpdates/*:Route';
       get_sp_upd(seq_id, t_msg_id, l_path);
     end if;



     -- end sp

     -- et

     r_path := '/*:DriverProExport/*:Routes/*:Route/*:Inputs/*:Event';
	 --r_path := '/*:DriverProExport/*:exportData/*:DriverProExport/*:Routes/*:Route/*:Inputs/*:Event';

     t_cnt := rt_type(seq_id, r_path);


     if (t_cnt >= 1) then
       -- get_rt(seq_id, t_msg_id);
       dbms_output.put_line('get_et_upd routes t_cnt = '||to_char(t_cnt));
       l_path := '$d/*:DriverProExport/*:Routes/*:Route';
	   --l_path := '$d/*:DriverProExport/*:exportData/*:DriverProExport/*:Routes/*:Route';
          --'/*:DriverProExport/*:exportData/*:DriverProExport/*:RouteUpdates/*:Route';
       get_et_upd(seq_id, t_msg_id, l_path);
     end if;

     r_path := '/*:DriverProExport/*:RouteUpdates/*:Route/*:Inputs/*:Event';
     --r_path := '/*:DriverProExport/*:exportData/*:DriverProExport/*:RouteUpdates/*:Route/*:Inputs/*:Event';

     t_cnt := rt_type(seq_id, r_path);

     if (t_cnt >= 1) then
       -- get_rt(seq_id, t_msg_id);
       dbms_output.put_line('get_st_upd routeupdates t_cnt = '||to_char(t_cnt));
       l_path := '$d/*:DriverProExport/*:RouteUpdates/*:Route';
	   --l_path := '$d/*:DriverProExport/*:exportData/*:DriverProExport/*:RouteUpdates/*:Route';
          --'/*:DriverProExport/*:exportData/*:DriverProExport/*:RouteUpdates/*:Route';
       get_et_upd(seq_id, t_msg_id, l_path);
     end if;

     -- end et

     -- ip

     r_path := '/*:DriverProExport/*:Routes/*:Route/*:Inputs/*:Event/*:Input';
	 --r_path := '/*:DriverProExport/*:exportData/*:DriverProExport/*:Routes/*:Route/*:Inputs/*:Event/*:Input';

     t_cnt := rt_type(seq_id, r_path);


     if (t_cnt >= 1) then
       -- get_rt(seq_id, t_msg_id);
       dbms_output.put_line('get_ip_upd routes t_cnt = '||to_char(t_cnt));
       l_path := '$d/*:DriverProExport/*:Routes/*:Route';
	   --l_path := '$d/*:DriverProExport/*:exportData/*:DriverProExport/*:Routes/*:Route';
          --'/*:DriverProExport/*:exportData/*:DriverProExport/*:RouteUpdates/*:Route';
       get_ip_upd(seq_id, t_msg_id, l_path);
     end if;

     r_path := '/*:DriverProExport/*:RouteUpdates/*:Route/*:Inputs/*:Event/*:Input';
     --r_path := '/*:DriverProExport/*:exportData/*:DriverProExport/*:RouteUpdates/*:Route/*:Inputs/*:Event/*:Input';

     t_cnt := rt_type(seq_id, r_path);

     if (t_cnt >= 1) then
       -- get_rt(seq_id, t_msg_id);
       dbms_output.put_line('get_ip_upd routeupdates t_cnt = '||to_char(t_cnt));
       l_path := '$d/*:DriverProExport/*:RouteUpdates/*:Route';
	   --l_path := '$d/*:DriverProExport/*:exportData/*:DriverProExport/*:RouteUpdates/*:Route';
          --'/*:DriverProExport/*:exportData/*:DriverProExport/*:RouteUpdates/*:Route';
       get_ip_upd(seq_id, t_msg_id, l_path);
     end if;


     -- end ip

     -- at

     r_path := '/*:DriverProExport/*:Routes/*:Route/*:Stops/*:Stop/*:AssetTransactions/*:AssetTransaction';
	 --r_path := '/*:DriverProExport/*:exportData/*:DriverProExport/*:Routes/*:Route/*:Stops/*:Stop/*:AssetTransactions/*:AssetTransaction';

     t_cnt := rt_type(seq_id, r_path);


     if (t_cnt >= 1) then
       -- get_rt(seq_id, t_msg_id);
       dbms_output.put_line('get_st routes t_cnt = '||to_char(t_cnt));
       l_path := '$d/*:DriverProExport/*:Routes/*:Route';
	   --l_path := '$d/*:DriverProExport/*:exportData/*:DriverProExport/*:Routes/*:Route';
          --'/*:DriverProExport/*:exportData/*:DriverProExport/*:RouteUpdates/*:Route';
       get_at_upd(seq_id, t_msg_id, l_path);
     end if;

     r_path := '/*:DriverProExport/*:RouteUpdates/*:Route/*:Stops/*:Stop/*:AssetTransactions/*:AssetTransaction';
     --r_path := '/*:DriverProExport/*:exportData/*:DriverProExport/*:RouteUpdates/*:Route/*:Stops/*:Stop/*:AssetTransactions/*:AssetTransaction';

     t_cnt := rt_type(seq_id, r_path);

     if (t_cnt >= 1) then
       -- get_rt(seq_id, t_msg_id);
       dbms_output.put_line('get_st routeupdates t_cnt = '||to_char(t_cnt));
       l_path := '$d/*:DriverProExport/*:RouteUpdates/*:Route';
	   --l_path := '$d/*:DriverProExport/*:exportData/*:DriverProExport/*:RouteUpdates/*:Route';
          --'/*:DriverProExport/*:exportData/*:DriverProExport/*:RouteUpdates/*:Route';
       get_at_upd(seq_id, t_msg_id, l_path);
     end if;

     -- end at

     -- cw

     r_path := '/*:DriverProExport/*:Routes/*:Route/*:Stops/*:Stop/*:CatchWeightAdjustments/*:CatchWeightAdjustment';
	 --r_path := '/*:DriverProExport/*:exportData/*:DriverProExport/*:Routes/*:Route/*:Stops/*:Stop/*:CatchWeightAdjustments/*:CatchWeightAdjustment';

     t_cnt := rt_type(seq_id, r_path);


     if (t_cnt >= 1) then
       -- get_rt(seq_id, t_msg_id);
       dbms_output.put_line('get_cw routes t_cnt = '||to_char(t_cnt));
       l_path := '$d/*:DriverProExport/*:Routes/*:Route';
	   --l_path := '$d/*:DriverProExport/*:exportData/*:DriverProExport/*:Routes/*:Route';
          --'/*:DriverProExport/*:exportData/*:DriverProExport/*:RouteUpdates/*:Route';
       get_cw_upd(seq_id, t_msg_id, l_path);
     end if;

     r_path := '/*:DriverProExport/*:Routes/*:Route/*:Stops/*:Stop/*:CatchWeightAdjustments/*:CatchWeightAdjustment';
     --r_path := '/*:DriverProExport/*:exportData/*:DriverProExport/*:Routes/*:Route/*:Stops/*:Stop/*:CatchWeightAdjustments/*:CatchWeightAdjustment';

     t_cnt := rt_type(seq_id, r_path);

     if (t_cnt >= 1) then
       -- get_rt(seq_id, t_msg_id);
       dbms_output.put_line('get_cw routeupdates t_cnt = '||to_char(t_cnt));
       l_path := '$d/*:DriverProExport/*:RouteUpdates/*:Route';
	   --l_path := '$d/*:DriverProExport/*:exportData/*:DriverProExport/*:RouteUpdates/*:Route';
          --'/*:DriverProExport/*:exportData/*:DriverProExport/*:RouteUpdates/*:Route';
       get_cw_upd(seq_id, t_msg_id, l_path);
     end if;
     -- end cw

     -- tf

     r_path := '/*:DriverProExport/*:Routes/*:Route/*:Stops/*:Stop/*:Transfers/*:Transfer';

	 --r_path := '/*:DriverProExport/*:exportData/*:DriverProExport/*:Routes/*:Route/*:Stops/*:Stop/*:Transfers/*:Transfer';

     t_cnt := rt_type(seq_id, r_path);


     if (t_cnt >= 1) then
       -- get_rt(seq_id, t_msg_id);
       dbms_output.put_line('get_tf routes t_cnt = '||to_char(t_cnt));
       l_path := '$d/*:DriverProExport/*:Routes/*:Route';
	   --l_path := '$d/*:DriverProExport/*:exportData/*:DriverProExport/*:Routes/*:Route';
          --'/*:DriverProExport/*:exportData/*:DriverProExport/*:RouteUpdates/*:Route';
       get_tf_upd(seq_id, t_msg_id, l_path);
     end if;

     r_path := '/*:DriverProExport/*:RouteUpdates/*:Route/*:Stops/*:Stop/*:Transfers/*:Transfer';
	 --r_path := '/*:DriverProExport/*:exportData/*:DriverProExport/*:RouteUpdates/*:Route/*:Stops/*:Stop/*:Transfers/*:Transfer';

     t_cnt := rt_type(seq_id, r_path);

     if (t_cnt >= 1) then
       -- get_rt(seq_id, t_msg_id);
       dbms_output.put_line('get_tf routeupdates t_cnt = '||to_char(t_cnt));
       l_path := '$d/*:DriverProExport/*:RouteUpdates/*:Route';
	   --l_path := '$d/*:DriverProExport/*:exportData/*:DriverProExport/*:RouteUpdates/*:Route';
          --'/*:DriverProExport/*:exportData/*:DriverProExport/*:RouteUpdates/*:Route';
       get_tf_upd(seq_id, t_msg_id, l_path);
     end if;

     -- end tf

     -- ti

     r_path := '/*:DriverProExport/*:Routes/*:Route/*:Stops/*:Stop/*:Transfers/*:Transfer/*:TItems/*:TI';
	 --r_path := '/*:DriverProExport/*:exportData/*:DriverProExport/*:Routes/*:Route/*:Stops/*:Stop/*:Transfers/*:Transfer/*:TItems/*:TI';

     t_cnt := rt_type(seq_id, r_path);


     if (t_cnt >= 1) then
       -- get_rt(seq_id, t_msg_id);
       dbms_output.put_line('get_ti_upd routes t_cnt = '||to_char(t_cnt));
       l_path := '$d/*:DriverProExport/*:Routes/*:Route';
	   --l_path := '$d/*:DriverProExport/*:exportData/*:DriverProExport/*:Routes/*:Route';
          --'/*:DriverProExport/*:exportData/*:DriverProExport/*:RouteUpdates/*:Route';
       get_ti_upd(seq_id, t_msg_id, l_path);
     end if;

     r_path := '/*:DriverProExport/*:RouteUpdates/*:Route/*:Stops/*:Stop/*:Transfers/*:Transfer/*:TItems/*:TI';
     --r_path := '/*:DriverProExport/*:exportData/*:DriverProExport/*:RouteUpdates/*:Route/*:Stops/*:Stop/*:Transfers/*:Transfer/*:TItems/*:TI';

     t_cnt := rt_type(seq_id, r_path);

     if (t_cnt >= 1) then
       -- get_rt(seq_id, t_msg_id);
       dbms_output.put_line('get_ti_upd routeupdates t_cnt = '||to_char(t_cnt));
       l_path := '$d/*:DriverProExport/*:RouteUpdates/*:Route';
	   --l_path := '$d/*:DriverProExport/*:exportData/*:DriverProExport/*:RouteUpdates/*:Route';
          --'/*:DriverProExport/*:exportData/*:DriverProExport/*:RouteUpdates/*:Route';
       get_ti_upd(seq_id, t_msg_id, l_path);
     end if;


     -- md

     r_path := '/*:DriverProExport/*:Routes/*:Route/*:Stops/*:Stop/*:ManualDelivItems/*:ManualDelivItem';
	 --r_path := '/*:DriverProExport/*:exportData/*:DriverProExport/*:Routes/*:Route/*:Stops/*:Stop/*:ManualDelivItems/*:ManualDelivItem';

     t_cnt := rt_type(seq_id, r_path);


     if (t_cnt >= 1) then
       -- get_rt(seq_id, t_msg_id);
       dbms_output.put_line('get_md routes t_cnt = '||to_char(t_cnt));
       l_path := '$d/*:DriverProExport/*:Routes/*:Route';
	   --l_path := '$d/*:DriverProExport/*:exportData/*:DriverProExport/*:Routes/*:Route';
          --'/*:DriverProExport/*:exportData/*:DriverProExport/*:RouteUpdates/*:Route';
       get_md_upd(seq_id, t_msg_id, l_path);
     end if;

     r_path := '/*:DriverProExport/*:RouteUpdates/*:Route/*:Stops/*:Stop/*:ManualDelivItems/*:ManualDelivItem';
	 --r_path := '/*:DriverProExport/*:exportData/*:DriverProExport/*:RouteUpdates/*:Route/*:Stops/*:Stop/*:ManualDelivItems/*:ManualDelivItem';

     t_cnt := rt_type(seq_id, r_path);

     if (t_cnt >= 1) then
       -- get_rt(seq_id, t_msg_id);
       dbms_output.put_line('get_md routeupdates t_cnt = '||to_char(t_cnt));
       l_path := '$d/*:DriverProExport/*:RouteUpdates/*:Route';
	   --l_path := '$d/*:DriverProExport/*:exportData/*:DriverProExport/*:RouteUpdates/*:Route';
          --'/*:DriverProExport/*:exportData/*:DriverProExport/*:RouteUpdates/*:Route';
       get_md_upd(seq_id, t_msg_id, l_path);
     end if;

     -- end md

     -- ca

     r_path := '/*:DriverProExport/*:Routes/*:Route/*:CheckInAssets/*:CheckInAsset';
	 --r_path := '/*:DriverProExport/*:exportData/*:DriverProExport/*:Routes/*:Route/*:CheckInAssets/*:CheckInAsset';

     t_cnt := rt_type(seq_id, r_path);


     if (t_cnt >= 1) then
       -- get_rt(seq_id, t_msg_id);
       dbms_output.put_line('get_ca routes t_cnt = '||to_char(t_cnt));
       l_path := '$d/*:DriverProExport/*:Routes/*:Route';
	   --l_path := '$d/*:DriverProExport/*:exportData/*:DriverProExport/*:Routes/*:Route';
          --'/*:DriverProExport/*:exportData/*:DriverProExport/*:RouteUpdates/*:Route';
       get_ca_upd(seq_id, t_msg_id, l_path);
     end if;

     r_path := '/*:DriverProExport/*:RouteUpdates/*:Route/*:CheckInAssets/*:CheckInAsset';
     --r_path := '/*:DriverProExport/*:exportData/*:DriverProExport/*:RouteUpdates/*:Route/*:CheckInAssets/*:CheckInAsset';

     t_cnt := rt_type(seq_id, r_path);

     if (t_cnt >= 1) then
       -- get_rt(seq_id, t_msg_id);
       dbms_output.put_line('get_ca routeupdates t_cnt = '||to_char(t_cnt));
       l_path := '$d/*:DriverProExport/*:RouteUpdates/*:Route';
	   --l_path := '$d/*:DriverProExport/*:exportData/*:DriverProExport/*:RouteUpdates/*:Route';
          --'/*:DriverProExport/*:exportData/*:DriverProExport/*:RouteUpdates/*:Route';
       get_ca_upd(seq_id, t_msg_id, l_path);
     end if;

     -- end ca

     -- ot

     r_path := '/*:DriverProExport/*:Routes/*:Route/*:Stops/*:Stop/*:SalesOffTruck/*:SaleOffTruck';
	 --r_path := '/*:DriverProExport/*:exportData/*:DriverProExport/*:Routes/*:Route/*:Stops/*:Stop/*:SalesOffTruck/*:SaleOffTruck';

     t_cnt := rt_type(seq_id, r_path);


     if (t_cnt >= 1) then
       -- get_rt(seq_id, t_msg_id);
       dbms_output.put_line('get_ot_upd routes t_cnt = '||to_char(t_cnt));
       l_path := '$d/*:DriverProExport/*:Routes/*:Route';
	   --l_path := '$d/*:DriverProExport/*:exportData/*:DriverProExport/*:Routes/*:Route';
          --'/*:DriverProExport/*:exportData/*:DriverProExport/*:RouteUpdates/*:Route';
       get_ot_upd(seq_id, t_msg_id, l_path);
     end if;

     r_path := '/*:DriverProExport/*:RouteUpdates/*:Route/*:Stops/*:Stop/*:SalesOffTruck/*:SaleOffTruck';
	 --r_path := '/*:DriverProExport/*:exportData/*:DriverProExport/*:RouteUpdates/*:Route/*:Stops/*:Stop/*:SalesOffTruck/*:SaleOffTruck';

     t_cnt := rt_type(seq_id, r_path);

     if (t_cnt >= 1) then
       -- get_rt(seq_id, t_msg_id);
       dbms_output.put_line('get_ot_upd routeupdates t_cnt = '||to_char(t_cnt));
       l_path := '$d/*:DriverProExport/*:RouteUpdates/*:Route';
	   --l_path := '$d/*:DriverProExport/*:exportData/*:DriverProExport/*:RouteUpdates/*:Route';
          --'/*:DriverProExport/*:exportData/*:DriverProExport/*:RouteUpdates/*:Route';
       get_ot_upd(seq_id, t_msg_id, l_path);
     end if;

     -- end ot




	-- 09/10/19 modify this for Jira OPCOF-2510

	declare

		cursor fix_mult_fetch is

	       select distinct route_no
           from sts_route_in
           where record_status = 'N'
		   and msg_id = t_msg_id
           order by route_no;

		cursor fix_mult_fetch_stc is

	       select distinct route_no, manifest_no, alt_stop_no, cust_id
           from sts_route_in
           where record_status = 'N'
		   and msg_id = t_msg_id
		   and record_type = 'ST'
           order by route_no;

        -- 6/17/20 add
        cursor c_invno (v_msgid varchar2, v_routeno varchar2, v_stopno number) is
            select distinct invoice_num
            from sts_route_in
            where alt_stop_no= v_stopno
            and route_no = v_routeno
            and msg_id = v_msgid
            and record_status = 'T';

	  /*
	  cursor fix_mult_fetch_cls is
		   select
           distinct route_no, manifest_no, alt_stop_no
           from sts_rt_in
           where record_status = 'N'
		   and msg_id = t_msg_id
		   and (record_type = 'ST' or record_type = 'ET')
           order by route_no;
	  */

	  l_msg_id sts_route_in.msg_id%type;
      l_route_no    sts_route_in.route_no%type;

       l_error_msg         VARCHAR2(2000);
       l_error_code        VARCHAR2(100);

       cnt_stop number;
       v_pod_flag            manifest_stops.pod_flag%type;
       v_opco_pod_flag       sys_config.config_flag_val%type;
       l_manifest_no         sts_route_in.manifest_no%type;
       l_stop_no         sts_route_in.alt_stop_no%type;
       l_cust_id         sts_route_in.cust_id%type;
       i_cnt               number;

    begin

	    pl_log.ins_msg('INFO', 'pl_xml_sts_route_in',
                        'in pl_xml_sts_route_in.driverproexport anonymous block msg_id = '||t_msg_id,
                         SQLCODE, SQLERRM, 'STS', 'driverproexport', 'N');

		select nvl(config_flag_val, 'N')   -- 12/9/20 add nvl
        INTO v_opco_pod_flag
        from sys_config
        where config_flag_name='POD_ENABLE';

        /* 9/2/20 take out for fixing event tag created by stop close
	    select count(*)
		   into cnt_stop  -- if is 1 it is stop close, > 1 it is route close
           from sts_route_in
           where record_status = 'N'
		   and msg_id = t_msg_id
		   and (record_type = 'ST' or record_type = 'ET')
           order by route_no;
         */

 --9/2/20 add for fixing event tag created by stop close

	    select count(*)
		   into cnt_stop  -- if is 1 it is route close
           from sts_route_in
           where record_status = 'N'
		   and msg_id = t_msg_id
		   and (record_type = 'RC')
           order by route_no;

        pl_log.ins_msg('INFO', 'pl_xml_sts_route_in',
                        'in pl_xml_sts_route_in.driverproexport anonymous block msg_id= '||t_msg_id||
                        'cnt_stop = '||to_char(cnt_stop)||' 0 is stop close or corr and more than 1 is route close' ,
                         SQLCODE, SQLERRM, 'STS', 'driverproexport', 'N');

        -- take out 9/2/20if cnt_stop = 1 then

        if cnt_stop = 0 then

			    pl_log.ins_msg('INFO', 'pl_xml_sts_route_in',
                        'in pl_xml_sts_route_in.driverproexport anonymous block cnt_stop = 0 stop close or corr and msg_id= '||t_msg_id,
                         SQLCODE, SQLERRM, 'STS', 'driverproexport', 'N');


			open fix_mult_fetch_stc;

            loop

				fetch fix_mult_fetch_stc
                into l_route_no, l_manifest_no, l_stop_no, l_cust_id;


                exit when fix_mult_fetch_stc%notfound;

                pl_log.ins_msg('INFO', 'pl_xml_sts_route_in',
                        'in pl_xml_sts_route_in.driverproexport anonymous block cnt_stop = 0 msg_id= '||t_msg_id||
                          ' in fix_mult_fetch_stc loop l_routre_no = '||l_route_no||' l_stop_no '||l_stop_no,
                         SQLCODE, SQLERRM, 'STS', 'driverproexport', 'N');


		        select sys_guid()
                into l_msg_id
                from dual;

                 /* 5/12/20 take out this could cause no data found
                select distinct pod_flag
				INTO v_pod_flag
                from manifest_stops
				where manifest_no=l_manifest_no
				and stop_no=floor( to_number(l_stop_no))
				and customer_id=l_cust_id;
                */

				/* add 1/7/19 put x for all stop close
				update sts_route_in
					set record_status = 'X', -- don't process it
						msg_id= l_msg_id
					where route_no = l_route_no
                            --and record_type = 'RJ'
					and msg_id = t_msg_id;
				*/

				/* 3/12/20 for 6.07.05
				update sts_route_in
				set record_status = 'X'
				where msg_id in (
					select distinct msg_id
					from sts_route_in
					where route_no = l_route_no
					and record_type = 'ST'
					and nvl(stop_correction,'N') = 'Y')
				and route_no = l_route_no;
                */


                   update sts_route_in
				   set record_status = 'X',
				       upd_date = sysdate
				    where msg_id in (
					select distinct msg_id
					from sts_route_in
					where route_no = l_route_no
					and record_type = 'ST'
					and msg_id = t_msg_id  -- add and modify 6/18/21
                    --and barcode is null
                    --and nvl(stop_correction,'N') = 'Y')
					and nvl(stop_correction,'N') = 'Y' 
					and route_no = l_route_no
					and record_status = 'N'	);

                    --and route_no = l_route_no
					--and record_status = 'N');


                   if sql%found then  -- add 6/18/21
                      pl_log.ins_msg('INFO', 'pl_xml_sts_route_in',
                        'in pl_xml_sts_route_in.driverproexport anonymous block cnt_stop = 0 msg_id= '||t_msg_id||' route_no='||l_route_no||
                          ' in fix_mult_fetch_stc loop after set record_status to x for stop_correction = Y in sqlfound',
                         SQLCODE, SQLERRM, 'STS', 'driverproexport', 'N');
                         --null;
                    end if;					





                 if v_opco_pod_flag = 'N' then

                    update sts_route_in
				    set record_status = 'X',
					    upd_date = sysdate					    
                    where msg_id in (
					select distinct msg_id
					from sts_route_in
					where route_no = l_route_no
					and msg_id = t_msg_id  -- add 6/18/21
					and record_type = 'ST'
                    and record_status = 'N');  -- add 6/18/21

                    --and route_no = l_route_no;

                    if sql%found then  -- modify 6/18/21
                        pl_log.ins_msg('INFO', 'pl_xml_sts_route_in',
                        'in pl_xml_sts_route_in.driverproexport anonymous block cnt_stop = 0 msg_id= '||t_msg_id||' route_no='||l_route_no||
                          ' in fix_mult_fetch_stc loop v_opco_pod_flag is not Y and after update x for rec type is stop in sqlfound',
                         SQLCODE, SQLERRM, 'STS', 'driverproexport', 'N');
                         --null;
                    end if;

                  end if;



                -- put x for barcode <= 8 for bulk pull
                /*
                pl_log.ins_msg('INFO', 'pl_xml_sts_route_in',
                        'in pl_xml_sts_route_in.driverproexport anonymous block cnt_stop = 1 msg_id= '||t_msg_id||
                          ' in fix_mult_fetch_stc loop before update x for barcode less 8 digit',
                         SQLCODE, SQLERRM, 'STS', 'driverproexport', 'N');

               */

               -- kiet say we put 'x' for bulkpull which has barcode length = 8
               update sts_route_in
               set record_status = 'X',
			       upd_date = sysdate
               where route_no = l_route_no
               and msg_id = t_msg_id
               and record_type in ('RJ', 'SR',  'SP')
               and alt_stop_no = l_stop_no
               and record_status = 'N'
               and ((length(barcode) <= 8) or (barcode is null) );

               if sql%found then  -- add 5/12/20
                           pl_log.ins_msg('INFO', 'pl_xml_sts_route_in',
                        'in pl_xml_sts_route_in.driverproexport anonymous block cnt_stop = 0 msg_id= '||t_msg_id||
                        ' route= '||l_route_no||
                          ' in fix_mult_fetch_stc loop after update x for barcode less 8 digit in sqlfound',
                         SQLCODE, SQLERRM, 'STS', 'driverproexport', 'N');
                 --null;
               end if;


               -- 6/1/20 add

               update sts_route_in
               set record_status = 'X',
			       upd_date = sysdate
               where route_no = l_route_no
               and msg_id = t_msg_id
               and record_type in ('RJ', 'SR',  'SP')
               and alt_stop_no = l_stop_no
               and record_status = 'N'
               and substr(item_id, 1,1) = 'F';


               if sql%found then  -- add 5/12/20
                           pl_log.ins_msg('INFO', 'pl_xml_sts_route_in',
                        'in pl_xml_sts_route_in.driverproexport anonymous block cnt_stop = 0 msg_id= '||t_msg_id||' route_no='||l_route_no||
                          ' in fix_mult_fetch_stc loop after update x for item_id with F in sqlfound',
                         SQLCODE, SQLERRM, 'STS', 'driverproexport', 'N');

               end if;


               -- 6/3/20 add

               update sts_route_in sri
               set record_status = 'T',
			       upd_date = sysdate
			   where exists (select 'x'
			                 from reason_cds rc
							 where rc.reason_cd = sri.return_reason_cd
							 and rc.reason_cd_type = 'RTN'
							 and nvl(rc.suppress_imm_credit, 'N') = 'Y')
               and sri.route_no = l_route_no
               and msg_id = t_msg_id
               and sri.alt_stop_no = l_stop_no
               and record_status = 'N';


               if sql%found then  -- add 5/12/20
                           pl_log.ins_msg('INFO', 'pl_xml_sts_route_in',
                        'in pl_xml_sts_route_in.driverproexport anonymous block cnt_stop = 0 msg_id= '||t_msg_id||' route_no='||l_route_no||
                          ' in fix_mult_fetch_stc loop after update x for reason_cds.suppress_imm_credit in sqlfound',
                         SQLCODE, SQLERRM, 'STS', 'driverproexport', 'N');

               end if;


               -- 6/17/20 add this

               FOR r_invno IN c_invno(t_msg_id, l_route_no, l_stop_no) LOOP

                    update sts_route_in sri
                    set record_status = 'X',
					    upd_date = sysdate
                    where sri.alt_stop_no= l_stop_no
                    and sri.route_no = l_route_no
                    and sri.msg_id = t_msg_id
                    and invoice_num = r_invno.invoice_num
                    and sri.record_status in ( 'T','N');


                    if sql%found then  -- add 5/12/20
                           pl_log.ins_msg('INFO', 'pl_xml_sts_route_in',
                        'in pl_xml_sts_route_in.driverproexport anonymous block cnt_stop = 0 msg_id= '||t_msg_id||' route_no='||l_route_no||' inv no='||r_invno.invoice_num||
                          ' in fix_mult_fetch_stc loop after update x for reason_cds.suppress_imm_credit in sqlfound',
                         SQLCODE, SQLERRM, 'STS', 'driverproexport', 'N');

                    end if;

                end loop;  --r_invno

               /* replace by above

               update sts_route_in sri
               set record_status = 'X'
               where sri.alt_stop_no= l_stop_no
               and sri.route_no = l_route_no
               and sri.msg_id = t_msg_id
               and sri.record_status in ( 'X','N');

               */

               /* replace by above
               update sts_route_in sri
               set sri.record_status = 'X',
                   add_date = sysdate
               where sri.alt_stop_no in (select sri_1.alt_stop_no
                                from sts_route_in sri_1
                                where sri_1.route_no = sri.route_no --l_route_no
                               and sri_1.msg_id = sri.msg_id
                               and sri_1.alt_stop_no = sri_1.alt_stop_no
                               and sri_1.record_status = 'X')
              and sri.route_no = l_route_no
              and sri.msg_id = t_msg_id
              and sri.alt_stop_no = l_stop_no
              and record_status = 'N';
              */



            /*
            pl_log.ins_msg('INFO', 'pl_xml_sts_route_in',
                        'in pl_xml_sts_route_in.driverproexport anonymous block cnt_stop = 1 msg_id= '||t_msg_id||
                          ' in fix_mult_fetch_stc loop after update x for barcode less 8 digit',
                         SQLCODE, SQLERRM, 'STS', 'driverproexport', 'N');
                */

				/* taking out 1/7/19
	            if ( (v_pod_flag='N') and (v_opco_pod_flag ='Y') ) then -- non POD

					pl_log.ins_msg('INFO', 'pl_xml_sts_route_in',
                        'in pl_xml_sts_route_in.driverproexport anonymous block cnt_stop = 1 non pod msg_id= '||t_msg_id,
                         SQLCODE, SQLERRM, 'STS', 'driverproexport', 'N');

                    -- take out on 1/3/20
					--update sts_route_in
                    --set msg_id= l_msg_id
                    --where msg_id = t_msg_id;


					-- add 1/3/20
					update sts_route_in
					set record_status = 'X', -- don't process it
						msg_id= l_msg_id
					where route_no = l_route_no
                            --and record_type = 'RJ'
					and msg_id = t_msg_id;

				elsif ( (v_pod_flag='Y') and (v_opco_pod_flag ='Y') ) then -- POD

					pl_log.ins_msg('INFO', 'pl_xml_sts_route_in',
                        'in pl_xml_sts_route_in.driverproexport anonymous block cnt_stop = 1 pod msg_id= '||t_msg_id,
                         SQLCODE, SQLERRM, 'STS', 'driverproexport', 'N');

					    select count(*)
						into i_cnt
						from sts_route_in s   --, manifests m
						WHERE s.alt_stop_no = l_stop_no
						and msg_id = t_msg_id
						and ((s.return_reason_cd like 'T01%') or (s.return_reason_cd = 'N01')); -- 1/3/20
						--and s.return_reason_cd = 'N01';
						--and ((s.return_reason_cd like 'D%') or (s.return_reason_cd like 'T%') or (s.return_reason_cd = 'N01'));


						if i_cnt >= 1 then

						pl_log.ins_msg('INFO', 'pl_xml_sts_route_in',
                        'in pl_xml_sts_route_in.driverproexport anonymous block cnt_stop = 1 pod  has t_d msg_id= '||t_msg_id,
                         SQLCODE, SQLERRM, 'STS', 'driverproexport', 'N');

							update sts_route_in
							set record_status = 'X', -- don't process it
							msg_id= l_msg_id
							where route_no = l_route_no
                            --and record_type = 'RJ'
							and msg_id = t_msg_id;

							--and alt_stop_no = l_stop_no; -- add 10/02/19

						else

						pl_log.ins_msg('INFO', 'pl_xml_sts_route_in',
                        'in pl_xml_sts_route_in.driverproexport anonymous block cnt_stop = 1 pod  has no t_d msg_id= '||t_msg_id,
                         SQLCODE, SQLERRM, 'STS', 'driverproexport', 'N');

							update sts_route_in
							set record_status = 'N',
							msg_id= l_msg_id
							where route_no = l_route_no
							and msg_id = t_msg_id;

							--and alt_stop_no = l_stop_no; -- add 10/02/19;

						end if;

				end if;

				*/

			end loop;

			close fix_mult_fetch_stc;

		-- take out 9/2/20 elsif cnt_stop > 1 then

        elsif cnt_stop >= 1 then -- added 9/2/20 it was = 1 has to be >= 1

			pl_log.ins_msg('INFO', 'pl_xml_sts_route_in',
                        'in pl_xml_sts_route_in.driverproexport anonymous block cnt_stop = 1 route close msg_id= '||t_msg_id,
                         SQLCODE, SQLERRM, 'STS', 'driverproexport', 'N');

			open fix_mult_fetch;

			loop

				fetch fix_mult_fetch into l_route_no;


				exit when fix_mult_fetch%notfound;


				select sys_guid()
				into l_msg_id
				from dual;

				update sts_route_in
				set record_status = 'N',
				msg_id= l_msg_id,
            upd_date = sysdate
				where route_no = l_route_no
				and msg_id = t_msg_id;  -- 02/25/19 add this line

                if sql%found then  -- add 5/12/20
                    pl_log.ins_msg('INFO', 'pl_xml_sts_route_in',
                        'in pl_xml_sts_route_in.driverproexport anonymous block cnt_stop = 1 route close msg_id= '||t_msg_id||' route_no='||l_route_no||
                          ' in fix_mult_fetch loop after update N in sqlfound for msg_id = '||l_msg_id,
                         SQLCODE, SQLERRM, 'STS', 'driverproexport', 'N');
                    null;
                end if;

               -- 6/1/20 add

               update sts_route_in
               set record_status = 'X',
			       upd_date = sysdate
               where route_no = l_route_no
               and msg_id = l_msg_id
               --and record_type in ('RJ', 'SR',  'SP')
               and record_status = 'N'
               --and prod_id = '7108349'
               and substr(item_id, 1,1) = 'F';


                if sql%found then  -- add 5/12/20
                    pl_log.ins_msg('INFO', 'pl_xml_sts_route_in',
                        'in pl_xml_sts_route_in.driverproexport anonymous block cnt_stop = 1 route close msg_id= '||l_msg_id||' route_no='||l_route_no||
                          ' in fix_mult_fetch loop after update record_status to x for item_id starts with F in sqlfound',
                         SQLCODE, SQLERRM, 'STS', 'driverproexport', 'N');

                end if;



               /* kiet say we put 'x' for bulkpull which has barcode length = 8 for immediate credit only
               update sts_route_in
               set record_status = 'X'
               where route_no = l_route_no
               and msg_id = t_msg_id
               and record_type in ('RJ', 'SR',  'SP')
               and alt_stop_no = l_stop_no
               and record_status = 'N'
               and ((length(barcode) <= 8) or (barcode is null) );

               if sql%notfound then  -- add 5/12/20
                    pl_log.ins_msg('INFO', 'pl_xml_sts_route_in',
                        'in pl_xml_sts_route_in.driverproexport anonymous block cnt_stop = 1 route close msg_id= '||l_msg_id||
                        ' route= '||l_route_no||
                          ' in fix_mult_fetch loop after update x for barcode length less then 8 bulkpull',
                         SQLCODE, SQLERRM, 'STS', 'driverproexport', 'N');
                    null;
                end if;
                */

			end loop;

			close fix_mult_fetch;

		end if;


        --commit;

    exception
    WHEN OTHERS THEN


       l_error_code := SUBSTR(SQLERRM,1,100);

       l_error_msg:= 'Error: WOT error from anonymous block to rename msg_id';
       l_error_code:= SUBSTR(SQLERRM,1,100);

	   pl_log.ins_msg(pl_log.ct_fatal_msg, 'pl_xml_sts_route_in', l_error_msg,
											SQLCODE, SQLERRM,
											'sts',
											'anonymous block',
											'N');


       raise;


    END;


	 -- add 02/15/19 fix one xml with more than one route and all got the same msg_id
	/*
	declare

	  cursor fix_mult_fetch is

	       select distinct route_no
           from sts_route_in
           where record_status = 'N'
		   and msg_id = t_msg_id
           order by route_no;

	  l_msg_id sts_route_in.msg_id%type;
      l_route_no    sts_route_in.route_no%type;

       l_error_msg         VARCHAR2(2000);
       l_error_code        VARCHAR2(100);


    begin

       open fix_mult_fetch;

        loop

           fetch fix_mult_fetch into l_route_no;


           exit when fix_mult_fetch%notfound;


		   select sys_guid()
             into l_msg_id
             from dual;

           update sts_route_in
            set record_status = 'N',
            msg_id= l_msg_id
          where route_no = l_route_no
		    and msg_id = t_msg_id;  -- 02/25/19 add this line



        end loop;

       close fix_mult_fetch;

        --commit;

    exception
    WHEN OTHERS THEN


       l_error_code := SUBSTR(SQLERRM,1,100);

       l_error_msg:= 'Error: WOT error from anonymous block to rename msg_id';
       l_error_code:= SUBSTR(SQLERRM,1,100);

	   pl_log.ins_msg(pl_log.ct_fatal_msg, 'pl_xml_sts_route_in', l_error_msg,
											SQLCODE, SQLERRM,
											'sts',
											'anonymous block',
											'N');


       raise;


    END;

	*/

	 -- end of 02/15/19 fix one xml with more than one route and all got the same msg_id


     commit;

     update sts_route_xml_in
     set record_status = 'S'
     where sequence_number = seq_id;

     return driverproexportresponse('true', 'OK');



EXCEPTION
WHEN web_exception THEN
   null;


when pi_switch_on_err then

   l_error_code:= SUBSTR(SQLERRM,1,100);
   l_error_msg:= 'Error: PI switch is ON for OPCO '||l_host_name;
   pl_log.ins_msg(pl_log.ct_fatal_msg, 'pl_xml_sts_route_in', l_error_msg,
											SQLCODE, SQLERRM,
											'sts',
											'driverproexport',
											'N');

     rollback;

    dbms_output.put_line('in driverproexport from when pi_switch_on_err before update sts_route_xml_in seq_id = '||to_char(seq_id));

     update sts_route_xml_in
     set record_status = 'F',
         error_code = substr(L_error_code,1,100), -- 02/25/19 L_error_code,
         error_msg = substr(l_error_msg,1,100) -- 02/25/19 l_error_msg
     where sequence_number = seq_id;

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
          'PL_STS_TO_SWMS',
          'WARN',
          'N',
          substr(l_error_code, 1, 48),
          'Error passing data from STS to SWMS',
          l_error_msg||' '||L_error_code,
          sysdate,
          'SWMS'
        );


     commit;

       --  return v_ret('false', l_error_code);
    --return driverproexportresponse('false', l_error_msg); --l_error_code);
    return driverproexportresponse('true', l_error_msg); --l_error_code);



when no_xml_data_err then

   l_error_code:= SUBSTR(SQLERRM,1,100);
   --l_error_msg:= 'Error: XML IN is NULL ';
   l_error_msg:= 'Error: XML IN is NULL for OPCO '||l_host_name||' msg id '||t_msg_id;
   pl_log.ins_msg(pl_log.ct_fatal_msg, 'pl_xml_sts_route_in', l_error_msg,
											SQLCODE, SQLERRM,
											'sts',
											'driverproexport',
											'N');

     rollback;

    dbms_output.put_line('in driverproexport from when no_xml_data_err before update sts_route_xml_in seq_id = '||to_char(seq_id));

     update sts_route_xml_in
     set record_status = 'F',
         error_code = substr(L_error_code,1,100), -- 02/25/19 L_error_code,
         error_msg = substr(l_error_msg,1,100) -- 02/25/19 l_error_msg,
     where sequence_number = seq_id;

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
          'PL_STS_TO_SWMS',
          'WARN',
          'N',
          substr(l_error_code, 1, 48),
		  'Error passing data from STS to SWMS',
          l_error_msg||' '||L_error_code,
          sysdate,
          'SWMS'
        );


     commit;

       --  return v_ret('false', l_error_code);
    --return driverproexportresponse('false', l_error_msg); --l_error_code);
    return driverproexportresponse('true', l_error_code);   -- 02/25/19


WHEN OTHERS THEN

   l_error_code:= SUBSTR(SQLERRM,1,100);
   --l_error_msg:= 'Error: When others error from pl_xml_sts_route_in.driverproexport ';
   l_error_msg:= 'Error: When others error from pl_xml_sts_route_in.driverproexport for OPCO '||l_host_name||' msg id '||t_msg_id;
   pl_log.ins_msg(pl_log.ct_fatal_msg, 'pl_xml_sts_route_in', l_error_msg,
											SQLCODE, SQLERRM,
											'sts',
											'driverproexport',
											'N');

     rollback;

    dbms_output.put_line('in driverproexport function when others then before update sts_route_xml_in seq_id = '||to_char(seq_id));

     update sts_route_xml_in
     set record_status = 'F',
         error_code = substr(L_error_code,1,100), -- 02/25/19 L_error_code,
         error_msg = substr(l_error_msg,1,100) -- 02/25/19 l_error_msg,
     where sequence_number = seq_id;

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
          'PL_STS_TO_SWMS',
          'WARN',
          'N',
          substr(l_error_code, 1, 48), --sqlcode,
          'Error passing data from STS to SWMS',
          l_error_msg||' '||L_error_code,
          sysdate,
          'SWMS'
        );

     commit;

       --  return v_ret('false', l_error_code);
    --return driverproexportresponse('false', l_error_code);
    return driverproexportresponse('true', l_error_code);   -- 02/25/19


END DriverProExport
;


END pl_xml_sts_route_in;
/
