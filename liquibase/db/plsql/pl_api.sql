create or replace PACKAGE pl_api AS

/*******************************************************************************
**Package:
**        pl_api. Newly created package for invoking the API from forms.
**
**Description:
**    This program is used for invoking the newly developed APP API's
**     and the newly migrated report API's from  forms.
**
**Called by:
**        This package is called from Forms.
**
**      DATE          USER                COMMENT                             
**     03/11/2020     SRAJ8407            Created PL_API package
*******************************************************************************/

PROCEDURE api_call_main (
        i_mod_name   IN   api_config.api_name%TYPE,
        o_url        OUT  VARCHAR2
);

PROCEDURE receiving_api (
        i_ermid               IN    erm.erm_id%TYPE,
        i_opcode              IN    api_config.api_val%TYPE,
        i_outstorage          IN    VARCHAR2,
        i_scheduledfromdate   IN    VARCHAR2, /* Format - 06:00 HH:MM */
        i_scheduledtodate     IN    VARCHAR2, /* Format - 17:00 HH:MM */
        i_mod_name            IN    VARCHAR2, 
        o_msg                 OUT   VARCHAR2
);

PROCEDURE display_rpt (
        i_printseq      IN   print_query.print_query_seq%TYPE,
        i_opconumber    IN   api_config.api_val%TYPE,
        i_type          IN   VARCHAR2,  /*Value - PDF or TEXT */
        i_languageid    IN   language.Id_language%TYPE,
        i_userid        IN   usr.user_id%TYPE,
        i_rpt_name      IN   print_reports.report%TYPE,
        i_rpt_dtls      IN   report_data.fname%TYPE,
		i_printername   IN   print_queues.user_queue%TYPE
);
    
PROCEDURE confirm_putaway (
        i_opco          IN    api_config.api_val%TYPE,
        i_userid        IN    usr.user_id%TYPE,
        i_mod_name      IN    api_config.api_name%TYPE,
        i_pallet_id     IN    putawaylst.pallet_id%TYPE,
		o_msg           OUT   VARCHAR2
);
    
PROCEDURE replen_create (
        i_area          IN replenlst.replen_area%TYPE,
        i_batchNo       IN replenlst.batch_no%TYPE,
        i_flgHist       IN api_config.api_enabled%TYPE,
        i_flgSplt       IN api_config.api_enabled%TYPE,
        i_fmaisle       IN aisle_info.name%TYPE,
        i_fmloc         IN replenlst.src_loc%TYPE,
        i_opcoCode      IN api_config.api_val%TYPE,
        i_pct           IN VARCHAR2, /* Format - Integer */
        i_prodId        IN replenlst.prod_id%TYPE,
        i_toAisle       IN aisle_info.name%TYPE,
        i_toLoc         IN replenlst.src_loc%TYPE,
        i_userId        IN usr.user_id%TYPE,
        i_mod_name      IN api_config.api_name%TYPE
);
    
PROCEDURE recover_order (
        i_opCoNumber      IN   api_config.api_val%TYPE,
        i_userName        IN   usr.user_id%TYPE,
		i_routeNumber     IN   route.route_no%TYPE,
        i_mod_name        IN   api_config.api_name%TYPE
);
    
PROCEDURE Order_generation (
        i_opCoNumber      IN   api_config.api_val%TYPE,
        i_userName        IN   usr.user_id%TYPE,
		i_routeNo         IN   route.route_no%TYPE,
		i_genType         IN   VARCHAR2,   /* Format : r or g */
        i_mod_name        IN   api_config.api_name%TYPE
);

PROCEDURE tp_signoff_forklift (
        i_opCoNumber         IN   api_config.api_val%TYPE,
        i_batch_no           IN   batch.batch_no%TYPE,
		i_forklift_batch_no  IN   batch.batch_no%TYPE,
        i_point_a            IN   api_config.api_name%TYPE,
        i_userName           IN   usr.user_id%TYPE,
        i_mod_name           IN   api_config.api_name%TYPE
);

PROCEDURE lm_writer (
        i_opco                        IN api_config.api_val%TYPE,
        i_abc                         IN inv.abc%TYPE,
		i_area                        IN swms_areas.area_code%TYPE,
        i_caseQtyPerCarrier           IN number,
        i_custPrefVendor              IN inv.cust_pref_vendor%TYPE,
        i_custShelfLife               IN pm.cust_shelf_life%TYPE,
        i_expDateTrk                  IN pm.exp_date_trk%TYPE,
        i_fifoTrk                     IN pm.fifo_trk%TYPE,
        i_hi                          IN pm.hi%TYPE,
        i_lotTrk                      IN pm.lot_trk%TYPE,
        i_maxTemperature              IN pm.max_temp%TYPE,
        i_mfgDateTrk                  IN pm.mfg_date_trk%TYPE,
        i_mfrShelfLife                IN pm.mfr_shelf_life%TYPE,
        i_minTemperature              IN pm.min_temp%TYPE,
        i_miniloadStorageIndicator    IN pm.miniload_storage_ind%TYPE,
        i_palletType                  IN pm.pallet_type%TYPE,
        i_productId                   IN pm.prod_id%TYPE,
        i_recordType                  IN pm.prod_id%TYPE,
        i_syscoShelfLife              IN pm.sysco_shelf_life%TYPE,
        i_tempTrk                     IN pm.temp_trk%TYPE,
        i_ti                          IN pm.ti%TYPE,
        i_mod_name                    IN api_config.api_name%TYPE         
);

PROCEDURE transfer_batch (
        i_opco            IN   api_config.api_val%TYPE,
        i_user            IN   usr.user_id%TYPE,
		i_transferMode    IN   VARCHAR2, /* Value - YES or NO */
        i_mod_name        IN   api_config.api_name%TYPE
);

PROCEDURE order_writer (
        i_opco                        IN api_config.api_val%TYPE,
        i_mod_name                    IN api_config.api_name%TYPE 
);

PROCEDURE rt_writer (
  		i_opco                        IN api_config.api_val%TYPE,
        i_mod_name                    IN api_config.api_name%TYPE  
);

PROCEDURE tr_writer (
  		i_opco                        IN api_config.api_val%TYPE,
        i_mod_name                    IN api_config.api_name%TYPE         
);

PROCEDURE po_writer (
        i_ermid 					  IN    erm.erm_id%TYPE,
		i_opco                        IN    api_config.api_val%TYPE,
        i_mod_name                    IN    api_config.api_name%TYPE         
);

PROCEDURE ir_writer (
  		i_opco                        IN api_config.api_val%TYPE,
        i_mod_name                    IN api_config.api_name%TYPE         
);

PROCEDURE demand_pallet (
        i_opCoNumber      IN    api_config.api_val%TYPE,
        i_userName        IN    usr.user_id%TYPE,
		i_cpv             IN    putawaylst.cust_pref_vendor%TYPE,
		i_prodId          IN    putawaylst.prod_id%TYPE,
        i_qtyRec          IN    putawaylst.Qty_Received%TYPE,
        i_queue           IN    print_queues.user_queue%TYPE,
        i_recId           IN    putawaylst.rec_id%TYPE,
        i_uom             IN    putawaylst.uom%TYPE,
        i_mod_name        IN    api_config.api_name%TYPE
);

PROCEDURE generic_labels (
        i_opconumber   IN  api_config.api_val%TYPE,
        i_type         IN  VARCHAR2,  /*Value - PDF or TEXT */
        i_languageid   IN  language.Id_language%TYPE,
        i_userid       IN  usr.user_id%TYPE,
        i_rpt_name     IN  print_reports.report%TYPE,
		i_qty          IN  language.Id_language%TYPE,
  		i_printerName  IN  print_queues.user_queue%TYPE  
        
);

PROCEDURE dod_labels (
        i_opconumber   IN  api_config.api_val%TYPE,
		i_userId       IN  usr.user_id%TYPE,
        i_type         IN  VARCHAR2,  /*Value - PDF or TEXT */
        i_languageid   IN  language.Id_language%TYPE,
        i_printerName  IN  print_queues.user_queue%TYPE ,
		i_area  	   IN  VARCHAR2, /* Value - FCD - */
        i_route_no     IN  route.route_no%TYPE,
		i_order_id     IN  dod_label_header.order_id%TYPE,
		i_cust_id      IN  dod_label_header.cust_id%TYPE,
		i_prod_id      IN  dod_label_detail.prod_id%TYPE,
		i_pallet_id    IN  dod_label_detail.pallet_id%TYPE,
		i_start_seq    IN  dod_label_detail.start_seq%TYPE,
		i_end_seq      IN  dod_label_detail.end_seq%TYPE,
        i_rpt_name     IN  print_reports.report%TYPE
);

PROCEDURE terminate_session (
        i_userId       IN  usr.user_id%TYPE,
        i_opconumber   IN  api_config.api_val%TYPE,
        i_sid          IN  v_swms_session.sid%TYPE,
        i_mod_name     IN  api_config.api_name%TYPE,
        o_msg          OUT VARCHAR2
);
    
END pl_api;
/

create or replace PACKAGE BODY pl_api AS
/***************************************************************** 
**  Name: api_call_main
**
**  PARAMETERS:  
**      i_mod_name         - Module Name
**      o_url              - Url of the API
**
**  Description: Main Procedure to get the url and Port info
 **               of the API called.
**
**  Called From : Commonly Called by All the API Procedure 
**    
**  RETURN VALUES: 
**    o_url - Url of the API will be returned        
**       
**      DATE          USER                COMMENT                             
**     03/11/2020     SRAJ8407            Created api_call_main     
****************************************************************/

PROCEDURE api_call_main (
        i_mod_name   IN    api_config.api_name%TYPE,
        o_url        OUT   VARCHAR2
) IS

        l_func_name     VARCHAR2(30) := 'pl_api.api_call_main';
        l_swms_url      api_config.api_val%TYPE;
        l_swms_port     api_config.api_val%TYPE;
        l_swms_method   api_config.api_val%TYPE;
BEGIN
		 pl_text_log.ins_msg_async('INFO', l_func_name, 'Starting api_call_main for ' || i_mod_name, sqlcode, sqlerrm);
        BEGIN
            SELECT
                api_val
            INTO l_swms_url
            FROM
                api_config
            WHERE
                api_name = 'API_URL';

        EXCEPTION
            WHEN no_data_found THEN
                pl_text_log.ins_msg_async('WARN', l_func_name, 'Unable to get SWMS URL for webservices for ' || i_mod_name, sqlcode, sqlerrm);
                return  ;
        END;

        BEGIN
            SELECT
                api_val
            INTO l_swms_port
            FROM
                api_config
            WHERE
                api_name = 'API_PORT';

        EXCEPTION
            WHEN no_data_found THEN
                pl_text_log.ins_msg_async('WARN', l_func_name, 'Unable to get SWMS PORT for webservices for ' || i_mod_name, sqlcode, sqlerrm);
                return ;
        END;

        BEGIN
            SELECT
                api_val
            INTO l_swms_method
            FROM
                api_config
            WHERE
                api_name = i_mod_name;

        EXCEPTION
            WHEN no_data_found THEN
                pl_text_log.ins_msg_async('WARN', l_func_name, 'Unable to get Method for webservices for ' || i_mod_name, sqlcode, sqlerrm);
                return ;
        END;

        IF l_swms_port = '0' THEN
		o_url := l_swms_url
				 ||l_swms_method;
				 
		ELSE
		
        o_url := l_swms_url
				 || ':'
                 || l_swms_port
                 || l_swms_method;
		END IF;
		 pl_text_log.ins_msg_async('INFO', l_func_name, 'Ending api_call_main for ' || i_mod_name, sqlcode, sqlerrm);		 
END api_call_main;
	
/***************************************************************** 
**  
**   NAME:  receiving_api
**  
**   PARAMETERS:  
**      i_ermid                - Passed from RP1SA form
**      i_opcode               - Opco number
**      i_outstorage           - outstorage Indicator(Y/N)
**      i_scheduledfromdate    - Schedule From Time
**      i_scheduledtodate      - Schedule To Time
**      i_mod_name             - Module Name
**
**   Description: To Open a PO using an API 
**
**   Called From : RP1SA and PO_OVERVIEW form
**
**   RETURN VALUES: 
**       o_msg -  Output response from the API
**       
**      DATE          USER                 COMMENT                             
**     03/11/2020     SRAJ8407             Created receiving_api     
*******************************************************************/

PROCEDURE receiving_api (
        i_ermid               IN    erm.erm_id%TYPE,
        i_opcode              IN    api_config.api_val%TYPE,
        i_outstorage          IN    VARCHAR2,
        i_scheduledfromdate   IN    VARCHAR2, /* Format - 06:00 HH:MM */
        i_scheduledtodate     IN    VARCHAR2, /* Format - 17:00 HH:MM */
        i_mod_name            IN    VARCHAR2, 
        o_msg                 OUT   VARCHAR2
) IS

        l_func_name   VARCHAR2(30) := 'pl_api.receiving_api';
        l_url_name    VARCHAR2(500);
        l_buffer      VARCHAR2(4000);
        l_req         utl_http.req;
        l_res         utl_http.resp;
        l_content     VARCHAR2(4000) := '{"ermId":"'
                                    || i_ermid
                                    || '", "opcode":"'
                                    || i_opcode
                                    || '","outStorage":"'
                                    || i_outstorage
                                    || '", "scheduledFromDate":"'
                                    || i_scheduledfromdate
                                    || '","scheduledToDate":"'
                                    || i_scheduledtodate
                                    || '"}';
BEGIN
		pl_text_log.ins_msg_async('INFO', l_func_name, 'Starting receiving_api for ' || i_mod_name, sqlcode, sqlerrm);
        api_call_main(i_mod_name, l_url_name);
        l_req := utl_http.begin_request(l_url_name, 'POST', ' HTTP/1.1');
        utl_http.set_header(l_req, 'content-type', 'application/json');
        utl_http.set_header(l_req, 'userName', USER);
        utl_http.set_header(l_req, 'Content-Length', LENGTH(l_content));
        utl_http.write_text(l_req, l_content);
        l_res := utl_http.get_response(l_req);
       
        
        BEGIN
            LOOP
                utl_http.read_line(l_res, l_buffer);
                dbms_output.put_line(l_buffer);
                 o_msg := l_buffer;
            END LOOP;

            utl_http.end_response(l_res);
        EXCEPTION
            WHEN utl_http.end_of_body THEN
                utl_http.end_response(l_res);
        END;
	    pl_text_log.ins_msg_async('INFO', l_func_name, 'Ending receiving_api for ' || i_mod_name, sqlcode, sqlerrm);
END receiving_api;


/***************************************************************** 
**  
**  Name : display_rpt
**  
**   PARAMETERS:  
**      i_printseq         - Print Sequence value
**      i_opconumber       - Opco number
**      i_type             - Output format
**      i_languageid       - Language ID
**      i_userid           - User Id
**      i_rpt_name         - Report name
**      i_rpt_dtls         - Name of the report to be stored in CLOB 
**      i_printername      - Printer Queue
**
**   Description: To Invoke a Report API  
**
**   Called From : Display_rpt form
**
**   RETURN VALUES: 
**       None
**       
**     DATE           USER                 COMMENT                             
**     03/11/2020     SRAJ8407             Created display_rpt    
**     
**********************************************************************/

PROCEDURE display_rpt (
        i_printseq     IN  print_query.print_query_seq%TYPE,
        i_opconumber   IN  api_config.api_val%TYPE,
        i_type         IN  VARCHAR2,  /*Value - PDF or TEXT */
        i_languageid   IN  language.Id_language%TYPE,
        i_userid       IN  usr.user_id%TYPE,
        i_rpt_name     IN  print_reports.report%TYPE,
        i_rpt_dtls     IN  report_data.fname%TYPE,
		i_printername  IN  print_queues.user_queue%TYPE  
) IS

        l_func_name   VARCHAR2(30) := 'pl_api.display_rpt';
        l_url_name    VARCHAR2(500);
        l_buffer      VARCHAR2(32767);
        l_req         utl_http.req;
        l_res         utl_http.resp;
        l_blob        BLOB;
        l_clob        CLOB;
        l_id          NUMBER;
        l_len         NUMBER;
        l_content     VARCHAR2(4000) := '{"languageID":"'
                                    || i_languageid
                                    || '","opcoNumber":"'
                                    || i_opconumber
                                    || '","printSeq":"'
                                    || i_printseq
                                    || '","type":"'
                                    || i_type
                                    || '","userId":"'
                                    || i_userid
									|| '","printerName":"'
                                    || i_printername
                                    || '"}';
BEGIN
        pl_text_log.ins_msg_async('INFO', l_func_name, 'Starting display_rpt for ' || i_rpt_name, sqlcode, sqlerrm);
		api_call_main(i_rpt_name, l_url_name);
        l_req := utl_http.begin_request(l_url_name, 'POST', ' HTTP/1.1');
        utl_http.set_header(l_req, 'User-Agent', 'Mozilla/4.0');
        utl_http.set_header(l_req, 'content-type', 'application/json');
        utl_http.set_header(l_req, 'userName', i_userid);
        --utl_http.set_header(l_req, 'accept', 'plain/text');
        utl_http.set_header(l_req, 'Content-Length', LENGTH(l_content));
        utl_http.write_text(l_req, l_content);
        l_res := utl_http.get_response(l_req);
		IF i_type ='TEXT' THEN
        utl_http.get_header_by_name(l_res, 'Content-Length', l_len, 1);       
        dbms_lob.createtemporary(l_clob, FALSE);
        dbms_lob.OPEN(l_clob, dbms_lob.lob_readwrite);
        FOR i IN 1..CEIL(l_len / 32767) LOOP
            utl_http.read_text(l_res, l_buffer,
                CASE
                    WHEN i < CEIL(l_len / 32767) THEN
                        32767
                    ELSE MOD(l_len, 32767)
                END
            );

            l_clob := l_clob || l_buffer; -- build the CLOB variable
        END LOOP;

        SELECT
            nvl(MAX(id) + 1, 1)
        INTO l_id
        FROM
            report_data;

        INSERT INTO report_data VALUES (
            l_id,
            i_rpt_dtls,
            l_clob
        ); -- Insert the CLOB data into the Table

        COMMIT;
        dbms_lob.freetemporary(l_clob);
		END IF;
        utl_http.end_response(l_res);
		pl_text_log.ins_msg_async('INFO', l_func_name, 'Ending display_rpt for ' || i_rpt_name, sqlcode, sqlerrm);
    EXCEPTION
        WHEN utl_http.end_of_body THEN
            utl_http.end_response(l_res);
        WHEN utl_http.too_many_requests THEN
            utl_http.end_response(l_res);
		
END display_rpt;


/***************************************************************** 
**  
**  Description : To Invoke a Confirm Putaway API  
**  Called From : RP1SI form
**  PARAMETERS:  
**      
**      i_opco             - Opco number
**      i_userid           - User Id
**      i_pallet_id        - Pallet Id
**      i_mod_name         - Module Name 
**
**  RETURN VALUES: 
**       o_msg -  Output response from the API
**
**     DATE           USER                 COMMENT                             
**     03/11/2020     SRAJ8407             Created confirm_putaway    
**     
*********************************************************************/

PROCEDURE confirm_putaway (
        i_opco          IN    api_config.api_val%TYPE,
        i_userid        IN    usr.user_id%TYPE,
        i_mod_name      IN    api_config.api_name%TYPE,
        i_pallet_id     IN    putawaylst.pallet_id%TYPE,
		o_msg           OUT   VARCHAR2
    ) IS

        l_func_name     VARCHAR2(30) := 'pl_api.confirm_putaway';
        l_url_name      VARCHAR2(500);
        l_buffer        VARCHAR2(32767);
        l_req           utl_http.req;
        l_res           utl_http.resp;
BEGIN
	    pl_text_log.ins_msg_async('INFO', l_func_name, 'Starting Confirm_putaway api for ' || i_mod_name, sqlcode, sqlerrm);
        api_call_main(i_mod_name, l_url_name);
        l_url_name := l_url_name
                      || '?'
                      || 'opCo='
                      || i_opco
                      || '&'
                      || 'palletId='
                      || i_pallet_id
                      || '&'
                      || 'userId='
                      || i_userid;      
        l_req := utl_http.begin_request(l_url_name, 'POST', ' HTTP/1.1');
        utl_http.set_header(l_req, 'User-Agent', 'Mozilla/4.0');
        utl_http.set_header(l_req, 'content-type', 'application/json');
        utl_http.set_header(l_req,'userName',i_userid);
        l_res := utl_http.get_response(l_req);
        BEGIN
            LOOP
                utl_http.read_line(l_res, l_buffer);
                dbms_output.put_line(l_buffer);
                o_msg := l_buffer;
            END LOOP;
            utl_http.end_response(l_res);
        EXCEPTION
            WHEN utl_http.end_of_body THEN
                utl_http.end_response(l_res);
        END;
         pl_text_log.ins_msg_async('INFO', l_func_name, 'Ending Confirm_putaway for ' || i_mod_name, sqlcode, sqlerrm);
END confirm_putaway;
	
/***************************************************************** 
**  
**  Description : To Invoke the Replen create API  
**  Called From : PN1SA form
**  PARAMETERS:  
**      i_area           - Area Code
**      i_batchNo        - Batch numberer
**      i_flgHist        - Output format
**      i_flgSplt        - Split Flag
**      i_fmaisle        - From Aisle
**      i_fmloc          - From Location
**      i_opcoCode       - Opco number
**	    i_pct            - Percentage value
**      i_prodId         - Item Number
**      i_toAisle        - To Aisle
**      i_toLoc          - To Loc
**      i_userId         - User Id
**      i_mod_name     - Module Name
**
**  RETURN VALUES: 
**       None
**
**     DATE           USER                 COMMENT                             
**     03/11/2020     SRAJ8407             Created replen_create   
**     
******************************************************************/

PROCEDURE replen_create (
        i_area          IN replenlst.replen_area%TYPE,
        i_batchNo       IN replenlst.batch_no%TYPE,
        i_flgHist       IN api_config.api_enabled%TYPE,
        i_flgSplt       IN api_config.api_enabled%TYPE,
        i_fmaisle       IN aisle_info.name%TYPE,
        i_fmloc         IN replenlst.src_loc%TYPE,
        i_opcoCode      IN api_config.api_val%TYPE,
        i_pct           IN VARCHAR2, /* Format - Integer */
        i_prodId        IN replenlst.prod_id%TYPE,
        i_toAisle       IN aisle_info.name%TYPE,
        i_toLoc         IN replenlst.src_loc%TYPE,
        i_userId        IN usr.user_id%TYPE,
        i_mod_name      IN api_config.api_name%TYPE
) IS

        l_func_name   VARCHAR2(30) := 'pl_api.replen_create';
        l_url_name    VARCHAR2(500);
        l_buffer      VARCHAR2(4000);
        l_req           utl_http.req;
        l_res           utl_http.resp;
        l_content     VARCHAR2(4000) := '{"area":"'
                                    || i_area
                                    || '", "batchNo":"'
                                    || i_batchNo
                                    || '","flgHist":"'
                                    || i_flgHist
                                    || '", "flgSplt":"'
                                    || i_flgSplt
                                    || '","fmaisle":"'
                                    || i_fmaisle
                                    || '","fmloc":"'
                                    || i_fmloc
                                    || '","opcoCode":"'
                                    || i_opcoCode
                                    || '","pct":"'
                                    || i_pct
                                    || '","prodId":"'
                                    || i_prodId
                                    || '","toAisle":"'
                                    || i_toAisle
                                    || '","toLoc":"'
                                    || i_toLoc
                                    || '","userId":"'
                                    || i_userId
                                    || '"}';
BEGIN
        pl_text_log.ins_msg_async('INFO', l_func_name, 'Starting replen_create api for ' || i_mod_name, sqlcode, sqlerrm);
        api_call_main(i_mod_name, l_url_name);
        l_req := utl_http.begin_request(l_url_name, 'POST', ' HTTP/1.1');
        utl_http.set_header(l_req, 'content-type', 'application/json');
        utl_http.set_header(l_req, 'userName', i_userId);
        utl_http.set_header(l_req, 'Content-Length', length(l_content));
        utl_http.write_text(l_req, l_content);
        l_res := utl_http.get_response(l_req);    
         BEGIN
            LOOP
                utl_http.read_line(l_res, l_buffer);
            END LOOP;

            utl_http.end_response(l_res);
        EXCEPTION
            WHEN utl_http.end_of_body THEN
                utl_http.end_response(l_res);
        END;
         pl_text_log.ins_msg_async('INFO', l_func_name, 'Ending replen_create api for ' || i_mod_name, sqlcode, sqlerrm);
END replen_create;
	   
/***************************************************************** 
**  
**  Description: To Invoke the  Order Recovery API  
**  Called From : OO1SA form
**  PARAMETERS:  
**      i_opCoNumber        - Opco number
**      i_routeNumber       - Route number
**      i_userName          - User Id
**      i_mod_name          - Module Name
**      
**  RETURN VALUES: 
**       None
**     
**     DATE           USER                 COMMENT                             
**     03/11/2020     SRAJ8407             Created recover_order 
**     
****************************************************************/
    
PROCEDURE recover_order (
        i_opCoNumber      IN   api_config.api_val%TYPE,
        i_userName        IN   usr.user_id%TYPE,
		i_routeNumber     IN   route.route_no%TYPE,
        i_mod_name        IN   api_config.api_name%TYPE
           
) IS

        l_func_name     VARCHAR2(30) := 'pl_api.recover_order';
        l_url_name      VARCHAR2(500);
        l_buffer        VARCHAR2(32767);
        l_req           utl_http.req;
        l_res           utl_http.resp;
BEGIN
        pl_text_log.ins_msg_async('INFO', l_func_name, 'Starting recover_order api for ' || i_mod_name, sqlcode, sqlerrm);
        api_call_main(i_mod_name, l_url_name);
        l_url_name := l_url_name
                      || '?'
                      || 'routeNumber='
                      || i_routeNumber;
        l_req := utl_http.begin_request(l_url_name, 'POST', ' HTTP/1.1');
        utl_http.set_header(l_req, 'User-Agent', 'Mozilla/4.0');
        utl_http.set_header(l_req, 'content-type', 'application/json');
		utl_http.set_header(l_req, 'userName', i_userName);
		utl_http.set_header(l_req, 'opCoNumber', i_opCoNumber);
        l_res := utl_http.get_response(l_req);
        BEGIN
            LOOP
                utl_http.read_line(l_res, l_buffer);
            END LOOP;
            utl_http.end_response(l_res);
        EXCEPTION
            WHEN utl_http.end_of_body THEN
                utl_http.end_response(l_res);
        END;
        pl_text_log.ins_msg_async('INFO', l_func_name, 'Ending recover_order api for ' || i_mod_name, sqlcode, sqlerrm);
END recover_order;
    
/***************************************************************** 
**  
**  Description: To Invoke the  Order Generation API  
**  Called From : OO1SA form
**  PARAMETERS:  
**      opCoNumber        - Opco number
**      routeNo           - Route number
**      userName          - User Id
**      genType           - Generate Type 
**      i_mod_name        - Module Name
**      
**  RETURN VALUES: 
**       None
**   
**     DATE           USER                 COMMENT                             
**     03/11/2020     SRAJ8407             Created Order_generation 
**     
********************************************************************/
	
PROCEDURE Order_generation (
        i_opCoNumber      IN   api_config.api_val%TYPE,
        i_userName        IN   usr.user_id%TYPE,
		i_routeNo         IN   route.route_no%TYPE,
		i_genType         IN   VARCHAR2,   /* Format : r or g */
        i_mod_name        IN   api_config.api_name%TYPE
           
) IS

        l_func_name     VARCHAR2(30) := 'pl_api.Order_generation';
        l_url_name      VARCHAR2(500);
        l_buffer        VARCHAR2(32767);
        l_req           utl_http.req;
        l_res           utl_http.resp;
		l_content       VARCHAR2(4000) := '{"genType":"'
                                           || i_genType
                                           || '", "routeNo":"'
                                           || i_routeNo
									       || '"}';
BEGIN
        pl_text_log.ins_msg_async('INFO', l_func_name, 'Starting Order_generation api for ' || i_mod_name, sqlcode, sqlerrm);
        api_call_main(i_mod_name, l_url_name);
        l_req := utl_http.begin_request(l_url_name, 'POST', ' HTTP/1.1');
        utl_http.set_header(l_req, 'User-Agent', 'Mozilla/4.0');
        utl_http.set_header(l_req, 'content-type', 'application/json');
		utl_http.set_header(l_req, 'userName', i_userName);
		utl_http.set_header(l_req, 'opCoNumber', i_opCoNumber);
        utl_http.set_header(l_req, 'Content-Length', length(l_content));
        utl_http.write_text(l_req, l_content);
        l_res := utl_http.get_response(l_req);
        BEGIN
            LOOP
                utl_http.read_line(l_res, l_buffer);
            END LOOP;
            utl_http.end_response(l_res);
        EXCEPTION
            WHEN utl_http.end_of_body THEN
                utl_http.end_response(l_res);
        END;
        pl_text_log.ins_msg_async('INFO', l_func_name, 'Ending Order_generation api for ' || i_mod_name, sqlcode, sqlerrm); 
END Order_generation;

/*******************************************************************
**  
**  Description: To Invoke the  tp_signoff_forklift API  
**  Called From : VALID form
**  PARAMETERS:  
**      i_opCoNumber        - Opco number
**      i_batch_no          - Batch number
**      i_forklift_batch_no - Fork Batch number
**      i_point_a           - Point Distance
**      i_userName          - User id
**      i_mod_name          - Module Name
**      
**  RETURN VALUES: 
**       None
**     
**     DATE           USER                 COMMENT                             
**     03/11/2020     SRAJ8407             Created tp_signoff_forklift 
**     
***********************************************************************/
    
PROCEDURE tp_signoff_forklift (
        i_opCoNumber         IN   api_config.api_val%TYPE,
        i_batch_no           IN   batch.batch_no%TYPE,
		i_forklift_batch_no  IN   batch.batch_no%TYPE,
        i_point_a            IN   api_config.api_name%TYPE,
        i_userName           IN   usr.user_id%TYPE,
        i_mod_name           IN   api_config.api_name%TYPE
           
) IS

        l_func_name     VARCHAR2(30) := 'pl_api.tp_signoff_forklift';
        l_url_name      VARCHAR2(500);
        l_buffer        VARCHAR2(32767);
        l_req           utl_http.req;
        l_res           utl_http.resp;
        l_content     VARCHAR2(4000) := '{"batchNo":"'
                                    || i_batch_no
                                    || '","forkLiftBatchNo":"'
                                    || i_forklift_batch_no
                                    || '","pointDistance":"'
                                    || i_point_a
                                    || '"}';
BEGIN
        pl_text_log.ins_msg_async('INFO', l_func_name, 'Starting Tp_signoff_forklift api for ' || i_mod_name, sqlcode, sqlerrm);
        api_call_main(i_mod_name, l_url_name);
        l_req := utl_http.begin_request(l_url_name, 'POST', ' HTTP/1.1');
        utl_http.set_header(l_req, 'User-Agent', 'Mozilla/4.0');
        utl_http.set_header(l_req, 'content-type', 'application/json');
		utl_http.set_header(l_req, 'userName', i_userName);
		utl_http.set_header(l_req, 'opCoNumber', i_opCoNumber);
        utl_http.set_header(l_req, 'Content-Length', length(l_content));
        utl_http.write_text(l_req, l_content);
        l_res := utl_http.get_response(l_req);
        BEGIN
            LOOP
                utl_http.read_line(l_res, l_buffer);
            END LOOP;
            utl_http.end_response(l_res);
        EXCEPTION
            WHEN utl_http.end_of_body THEN
                utl_http.end_response(l_res);
        END;
        pl_text_log.ins_msg_async('INFO', l_func_name, 'Ending Tp_signoff_forklift api for ' || i_mod_name, sqlcode, sqlerrm);
END tp_signoff_forklift;

/*******************************************************************
**  
**  Description: To Invoke the  lm_writer API  
**  Called From : Mutiple forms
**  PARAMETERS:  
**      i_opco                        -Opco number
**      i_abc                         -abc
**      i_area                        -Area code
**      i_caseQtyPerCarrier           -Case Qty per carrier
**      i_custPrefVendor              -CPV
**      i_custShelfLife               -Customer Shelf Life
**      i_expDateTrk                  -Exp Date Track
**      i_fifoTrk                     -Fifo track
**      i_hi                          -Hi
**      i_lotTrk                      -Lot Track
**      i_maxTemperature              -Maximum Temperature
**      i_mfgDateTrk                  -Manfacturer Date track
**      i_mfrShelfLife                -Manfacturer Shelf Life
**      i_minTemperature              -Minimum Temperature
**      i_miniloadStorageIndicator    -MiniloadStorageIndicator
**      i_palletType                  -PalletType 
**      i_productId                   -ProductId    
**      i_recordType                  -RecordType
**      i_syscoShelfLife              -Sysco Shelf Life 
**      i_tempTrk                     -Temp track
**      i_ti                          -Ti value
**      i_mod_name                    -Module name   
**      
**  RETURN VALUES: 
**       None
**     
**     DATE           USER                 COMMENT                             
**     03/11/2020     SRAJ8407             Created lm_writer 
**     
***********************************************************************/
 
PROCEDURE lm_writer (
        i_opco                        IN api_config.api_val%TYPE,
        i_abc                         IN inv.abc%TYPE,
        i_area                        IN swms_areas.area_code%TYPE,
        i_caseQtyPerCarrier           IN number,
        i_custPrefVendor              IN inv.cust_pref_vendor%TYPE,
        i_custShelfLife               IN pm.cust_shelf_life%TYPE,
        i_expDateTrk                  IN pm.exp_date_trk%TYPE,
        i_fifoTrk                     IN pm.fifo_trk%TYPE,
        i_hi                          IN pm.hi%TYPE,
        i_lotTrk                      IN pm.lot_trk%TYPE,
        i_maxTemperature              IN pm.max_temp%TYPE,
        i_mfgDateTrk                  IN pm.mfg_date_trk%TYPE,
        i_mfrShelfLife                IN pm.mfr_shelf_life%TYPE,
        i_minTemperature              IN pm.min_temp%TYPE,
        i_miniloadStorageIndicator    IN pm.miniload_storage_ind%TYPE,
        i_palletType                  IN pm.pallet_type%TYPE,
        i_productId                   IN pm.prod_id%TYPE,
        i_recordType                  IN pm.prod_id%TYPE,
        i_syscoShelfLife              IN pm.sysco_shelf_life%TYPE,
        i_tempTrk                     IN pm.temp_trk%TYPE,
        i_ti                          IN pm.ti%TYPE, 
        i_mod_name                    IN api_config.api_name%TYPE         
) IS

        l_func_name     VARCHAR2(30) := 'pl_api.lm_writer';
        l_url_name      VARCHAR2(500);
        l_buffer        VARCHAR2(32767);
        l_req           utl_http.req;
        l_res           utl_http.resp;
       l_content     VARCHAR2(4000) := '{"opco": "'
                                    || i_opco
                                    ||  '","productMaster": ['
                                    || '{"abc": "'
                                    || i_abc
                                    || '","area": "'
                                    || i_area
                                    || '","caseQtyPerCarrier": "'
                                    || i_caseQtyPerCarrier
                                    || '","custPrefVendor": "'
                                    || i_custPrefVendor
                                    || '","custShelfLife": "'
                                    || i_custShelfLife
                                    || '","expDateTrk": "'
                                    || i_expDateTrk
                                    || '","fifoTrk": "'
                                    || i_fifoTrk
                                    || '","hi": "'
                                    || i_hi
                                    || '","lotTrk": "'
                                    || i_lotTrk
                                    || '","maxTemperature": "'
                                    || i_maxTemperature
                                    || '","mfgDateTrk": "'
                                    || i_mfgDateTrk
                                    || '","mfrShelfLife": "'
                                    || i_mfrShelfLife
                                    || '","minTemperature": "'
                                    || i_minTemperature
                                    || '","miniloadStorageIndicator": "'
                                    || i_miniloadStorageIndicator
                                    || '","palletType": "'
                                    || i_palletType
                                    || '","productId": "'
                                    || i_productId
                                    || '","recordType": "'
                                    || i_recordType
                                    || '","syscoShelfLife": "'
                                    || i_syscoShelfLife
                                    || '","tempTrk": "'
                                    || i_tempTrk
                                    || '","ti": "'
                                    || i_ti  
                                    || '"}]'
                                    || '}'; 
BEGIN
        pl_text_log.ins_msg_async('INFO', l_func_name, 'Starting lm_writer api for ' || i_mod_name, sqlcode, sqlerrm);
        api_call_main(i_mod_name, l_url_name);
        l_req := utl_http.begin_request(l_url_name, 'POST', ' HTTP/1.1');
        utl_http.set_header(l_req, 'User-Agent', 'Mozilla/4.0');
        utl_http.set_header(l_req, 'Content-Type', 'application/json;charset=UTF-8');
        utl_http.set_header(l_req, 'Content-Length', length(l_content));
        utl_http.write_text(l_req, l_content);
        l_res := utl_http.get_response(l_req);
        BEGIN
            LOOP
                utl_http.read_line(l_res, l_buffer);
            END LOOP;
            utl_http.end_response(l_res);
        EXCEPTION
            WHEN utl_http.end_of_body THEN
                utl_http.end_response(l_res);
        END;
        pl_text_log.ins_msg_async('INFO', l_func_name, 'Ending lm_writer api for ' || i_mod_name, sqlcode, sqlerrm);
END lm_writer;

/***************************************************************** 
**  
**  Description: To Invoke the  Order Generation API  
**  Called From : OO1SA form
**  PARAMETERS:  
**      i_opco           - Opco number
**      i_user           - User id
**      i_transferMode   - Transfer mode
**      i_mod_name       - Module Name
**      
**  RETURN VALUES: 
**       None
**   
**     DATE           USER                 COMMENT                             
**     03/11/2020     SRAJ8407             Created transfer_batch 
**     
********************************************************************/
	
PROCEDURE transfer_batch (
        i_opco            IN   api_config.api_val%TYPE,
        i_user            IN   usr.user_id%TYPE,
		i_transferMode    IN   VARCHAR2, /* Value - YES or NO */
        i_mod_name        IN   api_config.api_name%TYPE
) IS

        l_func_name     VARCHAR2(30) := 'pl_api.transfer_batch';
        l_url_name      VARCHAR2(500);
        l_buffer        VARCHAR2(32767);
        l_req           utl_http.req;
        l_res           utl_http.resp;
		l_content       VARCHAR2(4000) := '{"opco":"'
                                           || i_opco
                                           || '", "userToBeProcessed":"'
                                           || i_user
                                           || '", "transferMode":"'
                                           || i_transferMode
									       || '"}';
BEGIN
        pl_text_log.ins_msg_async('INFO', l_func_name, 'Starting transfer_batch api for ' || i_mod_name, sqlcode, sqlerrm);
        api_call_main(i_mod_name, l_url_name);
        l_req := utl_http.begin_request(l_url_name, 'POST', ' HTTP/1.1');
        utl_http.set_header(l_req, 'User-Agent', 'Mozilla/4.0');
        utl_http.set_header(l_req, 'content-type', 'application/json');
		utl_http.set_header(l_req, 'Content-Length', length(l_content));
        utl_http.write_text(l_req, l_content);
        l_res := utl_http.get_response(l_req);
        BEGIN
            LOOP
                utl_http.read_line(l_res, l_buffer);
            END LOOP;
            utl_http.end_response(l_res);
        EXCEPTION
            WHEN utl_http.end_of_body THEN
                utl_http.end_response(l_res);
        END;
        pl_text_log.ins_msg_async('INFO', l_func_name, 'Ending transfer_batch api for ' || i_mod_name, sqlcode, sqlerrm); 
END transfer_batch;

/***************************************************************** 
**  
**  Description: To Invoke the  order_writer API  
**  Called From : OO1SA form
**  PARAMETERS:  
**      i_opco           - Opco number
**      i_mod_name       - Module Name
**      
**  RETURN VALUES: 
**       None
**   
**     DATE           USER                 COMMENT                             
**     03/11/2020     SRAJ8407             Created order_writer 
**     
********************************************************************/

PROCEDURE order_writer (
        i_opco                        IN api_config.api_val%TYPE,
        i_mod_name                    IN api_config.api_name%TYPE         
) IS

        l_func_name     VARCHAR2(30) := 'pl_api.order_writer';
        l_url_name      VARCHAR2(500);
        l_buffer        VARCHAR2(32767);
        l_req           utl_http.req;
        l_res           utl_http.resp;
        l_content     VARCHAR2(4000) := '{"opco": "'
                                    || i_opco
                                    || '"}';
BEGIN
        pl_text_log.ins_msg_async('INFO', l_func_name, 'Starting order_writer api for ' || i_mod_name, sqlcode, sqlerrm);
        api_call_main(i_mod_name, l_url_name);
        l_req := utl_http.begin_request(l_url_name, 'POST', ' HTTP/1.1');
        utl_http.set_header(l_req, 'User-Agent', 'Mozilla/4.0');
        utl_http.set_header(l_req, 'Content-Type', 'application/json;charset=UTF-8');
        utl_http.set_header(l_req, 'Content-Length', length(l_content));
        utl_http.write_text(l_req, l_content);
        l_res := utl_http.get_response(l_req);
        BEGIN
            utl_http.end_response(l_res);
        EXCEPTION
            WHEN utl_http.end_of_body THEN
                utl_http.end_response(l_res);
        END;
        pl_text_log.ins_msg_async('INFO', l_func_name, 'Ending order_writer api for ' || i_mod_name, sqlcode, sqlerrm);
END order_writer;

/***************************************************************** 
**  
**  Description: To Invoke the  RT writer API  
**  Called From : RTNSCLS form
**  PARAMETERS:  
**      i_opco           - Opco number
**      i_mod_name       - Module Name
**      
**  RETURN VALUES: 
**       None
**   
**     DATE           USER                 COMMENT                             
**     03/11/2020     SRAJ8407             Created rt_writer 
**     
********************************************************************/

PROCEDURE rt_writer (
  		i_opco                        IN api_config.api_val%TYPE,
        i_mod_name                    IN api_config.api_name%TYPE         
) IS

        l_func_name     VARCHAR2(30) := 'pl_api.rt_writer';
        l_url_name      VARCHAR2(500);
        l_buffer        VARCHAR2(32767);
        l_req           utl_http.req;
        l_res           utl_http.resp;
        l_content     VARCHAR2(4000) := '{"opco": "'
                                    || i_opco
                                      || '"}';
BEGIN
        pl_text_log.ins_msg_async('INFO', l_func_name, 'Starting rt_writer api for ' || i_mod_name, sqlcode, sqlerrm);
        dbms_output.put_line('l_content is '|| l_content);
        api_call_main(i_mod_name, l_url_name);
          dbms_output.put_line('url is '|| l_url_name);
        l_req := utl_http.begin_request(l_url_name, 'POST', ' HTTP/1.1');
        utl_http.set_header(l_req, 'User-Agent', 'Mozilla/4.0');
        utl_http.set_header(l_req, 'Content-Type', 'application/json;charset=UTF-8');
        utl_http.set_header(l_req, 'Content-Length', length(l_content));
        utl_http.write_text(l_req, l_content);
        l_res := utl_http.get_response(l_req);
        BEGIN
            utl_http.end_response(l_res);
        EXCEPTION
            WHEN utl_http.end_of_body THEN
                utl_http.end_response(l_res);
        END;
        pl_text_log.ins_msg_async('INFO', l_func_name, 'Ending rt_writer api for ' || i_mod_name, sqlcode, sqlerrm);
END rt_writer;

/***************************************************************** 
**  
**  Description: To Invoke the  TR writer API  
**  Called From : Multiple form
**  PARAMETERS:  
**      i_opco           - Opco number
**      i_mod_name       - Module Name
**      
**  RETURN VALUES: 
**       None
**   
**     DATE           USER                 COMMENT                             
**     03/11/2020     SRAJ8407             Created tr_writer 
**     
********************************************************************/

PROCEDURE tr_writer (
  		i_opco                        IN api_config.api_val%TYPE,
        i_mod_name                    IN api_config.api_name%TYPE         
) IS

        l_func_name     VARCHAR2(30) := 'pl_api.tr_writer';
        l_url_name      VARCHAR2(500);
        l_buffer        VARCHAR2(32767);
        l_req           utl_http.req;
        l_res           utl_http.resp;
        l_content     VARCHAR2(4000) := '{"opco": "'
                                    || i_opco
                                      || '"}';
BEGIN
        pl_text_log.ins_msg_async('INFO', l_func_name, 'Starting tr_writer api for ' || i_mod_name, sqlcode, sqlerrm);
        api_call_main(i_mod_name, l_url_name);
        l_req := utl_http.begin_request(l_url_name, 'POST', ' HTTP/1.1');
        utl_http.set_header(l_req, 'User-Agent', 'Mozilla/4.0');
        utl_http.set_header(l_req, 'Content-Type', 'application/json;charset=UTF-8');
        utl_http.set_header(l_req, 'Content-Length', length(l_content));
        utl_http.write_text(l_req, l_content);
        l_res := utl_http.get_response(l_req);
        BEGIN
            utl_http.end_response(l_res);
        EXCEPTION
            WHEN utl_http.end_of_body THEN
                utl_http.end_response(l_res);
        END;
        pl_text_log.ins_msg_async('INFO', l_func_name, 'Ending tr_writer api for ' || i_mod_name, sqlcode, sqlerrm);
END tr_writer;

/***************************************************************** 
**  
**  Description: To Invoke the  PO writer API  
**  Called From : RP1SA form
**  PARAMETERS:  
**       i_ermid         - Erm ID
**      i_opco           - Opco number
**      i_mod_name       - Module Name
**      
**  RETURN VALUES: 
**       None
**   
**     DATE           USER                 COMMENT                             
**     03/11/2020     SRAJ8407             Created po_writer 
**     
********************************************************************/

PROCEDURE po_writer (
        i_ermid 					  IN    erm.erm_id%TYPE,
		i_opco                        IN    api_config.api_val%TYPE,
        i_mod_name                    IN    api_config.api_name%TYPE         
) IS

        l_func_name     VARCHAR2(30) := 'pl_api.po_writer';
        l_url_name      VARCHAR2(500);
        l_buffer        VARCHAR2(32767);
        l_req           utl_http.req;
        l_res           utl_http.resp;
        l_content     VARCHAR2(4000) := '{"ermId":"'
                                    || i_ermid
                                    || '", "opco":"'
                                    || i_opco
									 || '"}';
BEGIN
        pl_text_log.ins_msg_async('INFO', l_func_name, 'Starting po_writer api for ' || i_mod_name, sqlcode, sqlerrm);
        api_call_main(i_mod_name, l_url_name);
        l_req := utl_http.begin_request(l_url_name, 'POST', ' HTTP/1.1');
        utl_http.set_header(l_req, 'User-Agent', 'Mozilla/4.0');
        utl_http.set_header(l_req, 'Content-Type', 'application/json;charset=UTF-8');
        utl_http.set_header(l_req, 'Content-Length', length(l_content));
        utl_http.write_text(l_req, l_content);
        l_res := utl_http.get_response(l_req);
        BEGIN
            utl_http.end_response(l_res);
        EXCEPTION
            WHEN utl_http.end_of_body THEN
                utl_http.end_response(l_res);
        END;
        pl_text_log.ins_msg_async('INFO', l_func_name, 'Ending po_writer api for ' || i_mod_name, sqlcode, sqlerrm);
END po_writer;

/***************************************************************** 
**  
**  Description: To Invoke the  IR writer API  
**  Called From : Multiple form
**  PARAMETERS:  
**      i_opco           - Opco number
**      i_mod_name       - Module Name
**      
**  RETURN VALUES: 
**       None
**   
**     DATE           USER                 COMMENT                             
**     03/11/2020     SRAJ8407             Created ir_writer 
**     
********************************************************************/

PROCEDURE ir_writer (
  		i_opco                        IN api_config.api_val%TYPE,
        i_mod_name                    IN api_config.api_name%TYPE         
) IS

        l_func_name     VARCHAR2(30) := 'pl_api.ir_writer';
        l_url_name      VARCHAR2(500);
        l_buffer        VARCHAR2(32767);
        l_req           utl_http.req;
        l_res           utl_http.resp;
        l_content     VARCHAR2(4000) := '{"opco": "'
                                    || i_opco
                                     || '"}';
BEGIN
        pl_text_log.ins_msg_async('INFO', l_func_name, 'Starting ir_writer api for ' || i_mod_name, sqlcode, sqlerrm);
        api_call_main(i_mod_name, l_url_name);
        l_req := utl_http.begin_request(l_url_name, 'POST', ' HTTP/1.1');
        utl_http.set_header(l_req, 'User-Agent', 'Mozilla/4.0');
        utl_http.set_header(l_req, 'Content-Type', 'application/json;charset=UTF-8');
        utl_http.set_header(l_req, 'Content-Length', length(l_content));
        utl_http.write_text(l_req, l_content);
        l_res := utl_http.get_response(l_req);
        BEGIN
            utl_http.end_response(l_res);
        EXCEPTION
            WHEN utl_http.end_of_body THEN
                utl_http.end_response(l_res);
        END;
        pl_text_log.ins_msg_async('INFO', l_func_name, 'Ending ir_writer api for ' || i_mod_name, sqlcode, sqlerrm);
END ir_writer;

/*******************************************************************
**  
**  Description: To Invoke the  demand_pallet API  
**  Called From : DEMAND_PALLET form
**  PARAMETERS:  
**      i_opCoNumber        - Opco number
**      i_userName          - User Id
**      i_cpv               - Cust pref Vendor
**      i_prodId            - Prod Id
**      i_qtyRec            - Qty Received
**      i_recId             - Erm Id
**      i_uom               - Uom 
**      i_mod_name          - Module Name
**      
**  RETURN VALUES: 
**       None
**     
**     DATE           USER                 COMMENT                             
**     03/11/2020     SRAJ8407             Created demand_pallet 
**     
***********************************************************************/
    
PROCEDURE demand_pallet (
        i_opCoNumber      IN    api_config.api_val%TYPE,
        i_userName        IN    usr.user_id%TYPE,
		i_cpv             IN    putawaylst.cust_pref_vendor%TYPE,
		i_prodId          IN    putawaylst.prod_id%TYPE,
        i_qtyRec          IN    putawaylst.Qty_Received%TYPE,
        i_queue           IN    print_queues.user_queue%TYPE,
        i_recId           IN    putawaylst.rec_id%TYPE,
        i_uom             IN    putawaylst.uom%TYPE,
        i_mod_name        IN    api_config.api_name%TYPE
           
) IS

        l_func_name     VARCHAR2(30) := 'pl_api.demand_pallet';
        l_url_name      VARCHAR2(500);
        l_buffer        VARCHAR2(32767);
        l_req           utl_http.req;
        l_res           utl_http.resp;
        l_content     VARCHAR2(4000) := '{"cpv":"'
                                    || i_cpv
                                    || '","prodId":"'
                                    || i_prodId
                                    || '","qtyRec":"'
                                    || i_qtyRec
                                    || '","queue":"'
                                    || i_queue
                                    || '","recId":"'
                                    || i_recId
                                    || '","uom":"'
                                    || i_uom
                                    || '"}';
BEGIN
        pl_text_log.ins_msg_async('INFO', l_func_name, 'Starting demand_pallet api for ' || i_mod_name, sqlcode, sqlerrm);
        api_call_main(i_mod_name, l_url_name);
        l_req := utl_http.begin_request(l_url_name, 'POST', ' HTTP/1.1');
        utl_http.set_header(l_req, 'User-Agent', 'Mozilla/4.0');
        utl_http.set_header(l_req, 'content-type', 'application/json');
		utl_http.set_header(l_req, 'userName', i_userName);
		utl_http.set_header(l_req, 'opCoNumber', i_opCoNumber);
        utl_http.set_header(l_req, 'Content-Length', length(l_content));
        utl_http.write_text(l_req, l_content);
        l_res := utl_http.get_response(l_req);
        BEGIN
            LOOP
                utl_http.read_line(l_res, l_buffer);
            END LOOP;
            utl_http.end_response(l_res);
        EXCEPTION
            WHEN utl_http.end_of_body THEN
                utl_http.end_response(l_res);
        END;
        pl_text_log.ins_msg_async('INFO', l_func_name, 'Ending demand_pallet api for ' || i_mod_name, sqlcode, sqlerrm);
END demand_pallet;

/***************************************************************** 
**  
**  Name : generic_labels
**  
**   PARAMETERS:  
**      i_opconumber       - Opco number
**      i_type             - Output format
**      i_languageid       - Language ID
**      i_userid           - User Id
**      i_rpt_name         - Report name
**      i_qty         	   - Total number of labels 
**      i_printerName      - Printer Queue
**
**   Description: To Invoke Generic Labels API  
**
**   Called From : Display_rpt form
**
**   RETURN VALUES: 
**       None
**       
**     DATE           USER                 COMMENT                             
**     03/11/2020     SRAJ8407             Created generic_labels    
**     
**********************************************************************/

PROCEDURE generic_labels (
        i_opconumber   IN  api_config.api_val%TYPE,
        i_type         IN  VARCHAR2,  /*Value - PDF or TEXT */
        i_languageid   IN  language.Id_language%TYPE,
        i_userid       IN  usr.user_id%TYPE,
        i_rpt_name     IN  print_reports.report%TYPE,
		i_qty          IN  language.Id_language%TYPE,
  		i_printerName  IN  print_queues.user_queue%TYPE  
) IS

        l_func_name   VARCHAR2(30) := 'pl_api.generic_labels';
        l_url_name    VARCHAR2(500);
        l_buffer      VARCHAR2(32767);
        l_req         utl_http.req;
        l_res         utl_http.resp;
        l_content     VARCHAR2(4000) := '{"languageID":"'
                                    || i_languageid
                                    || '","opcoNumber":"'
                                    || i_opconumber
                                    || '","printerName":"'
                                    || i_printerName
                                    || '","qty":"'
                                    || i_qty
                                    || '","type":"'
                                    || i_type
									|| '","userId":"'
                                    || i_userId
                                    || '"}';
BEGIN
        pl_text_log.ins_msg_async('INFO', l_func_name, 'Starting generic_labels API for ' || i_rpt_name, sqlcode, sqlerrm);
		api_call_main(i_rpt_name, l_url_name);
        l_req := utl_http.begin_request(l_url_name, 'POST', ' HTTP/1.1');
        utl_http.set_header(l_req, 'User-Agent', 'Mozilla/4.0');
        utl_http.set_header(l_req, 'content-type', 'application/json');
        utl_http.set_header(l_req, 'userName', i_userId);
        utl_http.set_header(l_req, 'Content-Length', LENGTH(l_content));
        utl_http.write_text(l_req, l_content);
        l_res := utl_http.get_response(l_req);
		BEGIN
            LOOP
                utl_http.read_line(l_res, l_buffer);
            END LOOP;

            utl_http.end_response(l_res);
        EXCEPTION
            WHEN utl_http.end_of_body THEN
                utl_http.end_response(l_res);
        END;
         pl_text_log.ins_msg_async('INFO', l_func_name, 'Ending generic_labels API for ' || i_rpt_name, sqlcode, sqlerrm);
END generic_labels;

/***************************************************************** 
**  
**  Name : dod_labels
**  
**   PARAMETERS:  
**      i_opconumber       - Opco number
**      i_type             - Output format
**      i_languageid       - Language ID
**      i_userid           - User Id
**      i_rpt_name         - Report name
**      i_area         	   - Area 
**      i_printerName      - Printer Queue
**		i_route_no		   - Route no
**		i_order_id		   - Order Id	
**		i_cust_id		   - Customer Id
**		i_prod_id		   - Item no.
**		i_pallet_id		   - Pallet_id	 
**		i_start_seq        - Start Sequence
**		i_end_seq          - End Sequence
**
**   Description: To Invoke Dod Labels API  
**
**   Called From : DOD form
**
**   RETURN VALUES: 
**       None
**       
**     DATE           USER                 COMMENT                             
**     03/11/2020     SRAJ8407             Created dod_labels    
**     
**********************************************************************/

PROCEDURE dod_labels (
        i_opconumber   IN  api_config.api_val%TYPE,
		i_userId       IN  usr.user_id%TYPE,
        i_type         IN  VARCHAR2,  /*Value - PDF or TEXT */
        i_languageid   IN  language.Id_language%TYPE,
        i_printerName  IN  print_queues.user_queue%TYPE ,
		i_area  	   IN  VARCHAR2, /* Value - FCD - */
        i_route_no     IN  route.route_no%TYPE,
		i_order_id     IN  dod_label_header.order_id%TYPE,
		i_cust_id      IN  dod_label_header.cust_id%TYPE,
		i_prod_id      IN  dod_label_detail.prod_id%TYPE,
		i_pallet_id    IN  dod_label_detail.pallet_id%TYPE,
		i_start_seq    IN  dod_label_detail.start_seq%TYPE,
		i_end_seq      IN  dod_label_detail.end_seq%TYPE,
        i_rpt_name     IN  print_reports.report%TYPE
		
  		
) IS

        l_func_name   VARCHAR2(30) := 'pl_api.dod_labels';
        l_url_name    VARCHAR2(500);
        l_buffer      VARCHAR2(32767);
        l_req         utl_http.req;
        l_res         utl_http.resp;
        l_content     VARCHAR2(4000) := '{"languageID":"'
                                    || i_languageid
                                    || '","opcoNumber":"'
                                    || i_opconumber
                                    || '","printerName":"'
                                    || i_printerName
                                    || '","areas":"'
                                    || i_area
                                    || '","type":"'
                                    || i_type
									|| '","userId":"'
                                    || i_userId
									|| '","custId":"'
                                    || i_cust_id
									|| '","itemNbr":"'
                                    || i_prod_id
									|| '","orderId":"'
                                    || i_order_id
									|| '","pallet":"'
                                    || i_pallet_id
									|| '","routeNo":"'
                                    || i_route_no
									|| '","startSeq":"'
                                    || i_start_seq
									|| '","endSeq":"'
                                    || i_end_seq
                                    || '"}';
BEGIN
        pl_text_log.ins_msg_async('INFO', l_func_name, 'Starting dod_labels API for ' || i_rpt_name, sqlcode, sqlerrm);
		api_call_main(i_rpt_name, l_url_name);
        l_req := utl_http.begin_request(l_url_name, 'POST', ' HTTP/1.1');
        utl_http.set_header(l_req, 'User-Agent', 'Mozilla/4.0');
        utl_http.set_header(l_req, 'content-type', 'application/json');
        utl_http.set_header(l_req, 'userName', i_userId);
        utl_http.set_header(l_req, 'Content-Length', LENGTH(l_content));
        utl_http.write_text(l_req, l_content);
        l_res := utl_http.get_response(l_req);
		  BEGIN
            LOOP
                utl_http.read_line(l_res, l_buffer);
            END LOOP;

            utl_http.end_response(l_res);
        EXCEPTION
            WHEN utl_http.end_of_body THEN
                utl_http.end_response(l_res);
        END;
         pl_text_log.ins_msg_async('INFO', l_func_name, 'Ending dod_labels API for ' || i_rpt_name, sqlcode, sqlerrm);
END dod_labels;

/***************************************************************** 
**  
**  Name : terminate_session
**  
**   PARAMETERS:  
**      i_opconumber       - Opco number
**      i_sid              - Serial ID
**      i_userId           - User Id
**      i_mod_name         - Module Name
**
**   Description: To Invoke Terminate Session API  
**
**   Called From : Session_Lock form
**
**   RETURN VALUES: 
**       o_msg - Output response from the API
**       
**     DATE           USER                 COMMENT                             
**     03/11/2020     SRAJ8407             Created terminate_session    
**     
**********************************************************************/

PROCEDURE terminate_session (
        i_userId       IN  usr.user_id%TYPE,
        i_opconumber   IN  api_config.api_val%TYPE,
        i_sid          IN  v_swms_session.sid%TYPE,
        i_mod_name     IN  api_config.api_name%TYPE,
        o_msg          OUT   VARCHAR2
        
)IS
        l_func_name     VARCHAR2(30) := 'pl_api.terminate_session';
        l_url_name      VARCHAR2(500);
        l_buffer        VARCHAR2(32767);
        l_req           utl_http.req;
        l_res           utl_http.resp;
		l_content       VARCHAR2(4000) := '{"sessionId":'
                                           || i_sid
									       || '}';
BEGIN
        pl_text_log.ins_msg_async('INFO', l_func_name, 'Starting terminate_session api for ' || i_mod_name, sqlcode, sqlerrm);
        api_call_main(i_mod_name, l_url_name);
        l_req := utl_http.begin_request(l_url_name, 'POST', ' HTTP/1.1');
        utl_http.set_header(l_req, 'User-Agent', 'Mozilla/4.0');
        utl_http.set_header(l_req, 'content-type', 'application/json');
        utl_http.set_header(l_req, 'opCoNumber', i_opconumber);
        utl_http.set_header(l_req, 'userName', i_userId);
        utl_http.set_header(l_req, 'Content-Length', length(l_content));
        utl_http.write_text(l_req, l_content);
        l_res := utl_http.get_response(l_req);
        BEGIN
            LOOP
                utl_http.read_line(l_res, l_buffer);
                o_msg := l_buffer;
            END LOOP;
            utl_http.end_response(l_res);
        EXCEPTION
            WHEN utl_http.end_of_body THEN
                utl_http.end_response(l_res);
        END;
        pl_text_log.ins_msg_async('INFO', l_func_name, 'Ending terminate_session api for ' || i_mod_name, sqlcode, sqlerrm); 
END terminate_session;
END pl_api;
/

GRANT Execute on pl_api to swms_user;

