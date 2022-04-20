CREATE OR REPLACE PACKAGE pl_rtn_xdock_interface AS
  ----------------------
  -- Package constants
  ----------------------
  /************************************************************************
  -- pl_rtn_xdock_interface
  --
  -- Description:   Package for XDOCK Returns functionality related to Launchpad
  --
  --
  -- Modification log: jira 3394, 3462
  --
  -- Date         Developer     Change
  -- ------------------------------------------------------------------
  -- 22-Jun-2021  vkal9662      Initial version.
  -- 06-Jul-2021  vkal9662      extra commit added in the out tables before insert in to datahub
  -- 15-Jul-2021  vkal9662      new process to derive putaway staging location for site2 added
  -- 20_Aug-2021  vkal9662      Jira 3386, 3505 Prevent Manifest Close for Site1
  --                            until Site2 xdock Manifest is closed
  -- 21-Sept-2021 jkar6681      OPCOF-3669: Update DCI Ready flag when the manifest is closed at last mile site.
  -- 06-Oct-2021  vkal9662      Opcof -3704:Manifest Status update issue-1 manifest in site2 mapped to 2 or more in Site1
  -- 25-Oct-2021  vkal9662      opcof -3764:one site1 Manifest to site2 many Manifests mapping scenario for for MFC
  *************************************************************************/
  PACKAGE_NAME        CONSTANT swms_log.program_name%TYPE     := 'PL_RTN_XDOCK_INTERFACE';
  APPLICATION_FUNC    CONSTANT swms_log.application_func%TYPE := 'DRIVER CHECKIN';
  VAL_TRIPMASTER_FAIL CONSTANT NUMBER                         := -1;

  ---------------------------------
  -- function/procedure signatures
  ---------------------------------
  
  PROCEDURE Populate_imdt_rtns_out(
      i_manifest_no      IN returns.manifest_no%TYPE,
      i_stop_no          IN returns.stop_no%TYPE) ; 
      
  PROCEDURE Populate_mfc_rtns_out(
      i_manifest_no IN returns.manifest_no%TYPE);
      
  PROCEDURE Populate_imdt_rtns_in(
      i_batch_id    IN xdock_returns_in.batch_id%TYPE,
      i_manifest_no IN returns.manifest_no%TYPE,
      i_site_from   IN returns.site_from%TYPE,
      i_site_to     IN returns.site_to%TYPE) ;
      
  PROCEDURE Populate_mfc_rtns_in(
      i_manifest_no IN returns.manifest_no%TYPE,
      i_site_from   IN returns.site_from%TYPE,
      i_site_to     IN returns.site_to%TYPE);
      
  PROCEDURE Get_xdock_Manifest(
      i_manifest_no   IN returns.manifest_no%TYPE,
      i_site_type     IN VARCHAR2,
      i_obligation_no IN returns.obligation_no%TYPE,
      o_manifest_no OUT returns.manifest_no%TYPE,
      o_route_no OUT manifests.route_no%TYPE);
      
Procedure get_xdock_dest_loc(p_site_from returns.site_from%TYPE, 
                            p_item pm.prod_id%TYPE,  
                            o_dest_loc  OUT putawaylst.dest_loc%TYPE,
                            o_rtn_err OUT returns.err_comment%TYPE) ;
                            
 PROCEDURE Get_Manifest_status(
      i_manifest_no   IN returns.manifest_no%TYPE,
      i_site_type     IN VARCHAR2,
      i_site_from     IN VARCHAR2,
      i_site_to       IN VARCHAR2,
      o_manifest_status OUT VARCHAR2) ;                          
  --   ====================================end specs==========================================================
END pl_rtn_xdock_interface;
/

/************************************************************************/

CREATE OR REPLACE PACKAGE BODY pl_rtn_xdock_interface
AS
  
    PROCEDURE Populate_imdt_rtns_out(
              i_manifest_no      IN returns.manifest_no%TYPE,
              i_stop_no IN returns.stop_no%TYPE)
  IS
  
  /************************************************************************
  -- Populate_imdt_rtns_out
  --
  -- Description:  populates staging table as each immidiate return is inserted in to the return table
  --
  -- Return/output: populates swms_log if there is any issue
  --
  -- Modification log: jira 3394
  --
  -- Date         Developer     Change
  -- ------------------------------------------------------------------
  -- 24-MAY-2021  vkal9662      Initial version.
  --
  *************************************************************************/
  
    l_func_name CONSTANT swms_log.procedure_name%TYPE := 'Populate_imdt_returns_out';
    l_msg swms_log.msg_text%TYPE;
    l_batch_id VARCHAR2(14);
    l_seq_no   NUMBER;
    l_route_no VARCHAR2(10);
    l_out_param PLS_INTEGER;
    l_manifest_out NUMBER;
    l_route_out    VARCHAR2(10);
    l_rec_count  NUMBER;
    l_site_from VARCHAR2(6);
    l_site_to   VARCHAR2(6);
    
    
     CURSOR c_get_rtn_info
    IS
      SELECT r.site_from,
        r.site_to,
        r.site_id,
        r.delivery_document_id,
        r.manifest_no,
        r.route_no,
        r.stop_no,
        r.rec_type,
        r.obligation_no,
        r.prod_id,
        r.cust_pref_vendor,
        r.return_reason_cd,
        r.returned_qty,
        r.returned_split_cd,
        r.catchweight,
        r.disposition,
        r.returned_prod_id,
        r.erm_line_id,
        r.shipped_qty,
        r.shipped_split_cd,
        r.cust_id,
        r.temperature,
        r.status,
        r.rtn_sent_ind,
        r.pod_rtn_ind,
        r.lock_chg,
        r.Add_user,
        r.Add_source,
        r.Add_date,
        r.upd_user ,
        r.upd_source ,
        r.upd_date
      FROM returns r
      WHERE r.manifest_no   = i_manifest_no
      AND r.xdock_ind       = 'X'  --for last mile returns this comes in marked as X from STS_IN
      AND r.pod_rtn_ind     ='S' 
      AND r.rtn_sent_ind    ='Y'
      AND r.stop_no         = i_stop_no
      AND r.status          = 'VAL';
    
    
  BEGIN
  
    BEGIN
    SELECT pl_xdock_common.get_batch_id
    INTO l_batch_id
    FROM dual;
    
  EXCEPTION
    WHEN OTHERS THEN
      pl_log.ins_msg('FATAL',l_func_name, 'Failed to get batch_id from pl_xdock_common.get_batch_id', sqlcode, SUBSTR(SQLERRM, 1, 500), APPLICATION_FUNC, PACKAGE_NAME);
    END;
    
       
    SELECT route_no
    INTO l_route_no
    FROM manifests
    WHERE manifest_no = i_manifest_no;
    
    FOR i IN c_get_rtn_info LOOP
    
      SELECT XDOCK_SEQNO_SEQ.nextval INTO l_seq_no FROM dual;
    
      Get_xdock_Manifest(i_manifest_no, 'FULFIL', i.obligation_no ,l_manifest_out, l_route_out);
    
      INSERT
      INTO xdock_returns_out
       (batch_id,
        sequence_no,
        record_status,
        site_from,
        site_to,
        site_id,
        delivery_document_id,
        manifest_no,
        route_no,
        stop_no,
        rec_type,
        obligation_no,
        prod_id,
        cust_pref_vendor,
        return_reason_cd,
        returned_qty,
        returned_split_cd,
        catchweight,
        disposition,
        returned_prod_id,
        erm_line_id,
        shipped_qty,
        shipped_split_cd,
        cust_id,
        temperature,
        status,
        rtn_sent_ind,
        pod_rtn_ind,
        lock_chg,
        imdt_rtn_ind,
        Add_user,
        add_source,
        Add_date,
        upd_user ,
        upd_source ,
        upd_date)
      VALUES
       (l_batch_id,
        l_seq_no,
        'N',
        i.site_from,
        i.site_to,
        i.site_id,
        i.delivery_document_id,
        l_manifest_out,
        l_route_out,
        i.stop_no,
        i.rec_type,
        i.obligation_no,
        i.prod_id ,
        i.cust_pref_vendor,
        i.return_reason_cd,
        i.returned_qty,
        i.returned_split_cd,
        i.catchweight,
        i.disposition,
        i.returned_prod_id,
        i.erm_line_id,
        i.shipped_qty,
        i.shipped_split_cd,
        i.cust_id,
        i.temperature,
        'VAL',
        i.rtn_sent_ind,
        i.pod_rtn_ind,
        NULL,
        'Y',
        REPLACE ( USER, 'OPS$' ) ,
        'INT',
        sysdate,
        REPLACE ( USER, 'OPS$' ) ,
        'INT',
        SYSDATE  );
        
      l_rec_count := l_rec_count+1;
      l_site_from := i.site_from;
      l_site_to   := i.site_to;
      
    End Loop;    
	 COMMIT;
    --data source here is lastmile site(i_site_to), data destination here is fulfilment site(i_site_from)
    l_out_param := PL_MSG_HUB_UTLITY.insert_meta_header( l_batch_id, 'XDOCK_RETURNS_OUT', l_site_to ,  l_site_from, l_rec_count);
    Commit;
    pl_log.ins_msg('INFO', l_func_name, 'Return added to xdoc_returns_out for site1 manifest: '||l_manifest_out||' from site2 manifest: ' ||i_manifest_no
                                         ||', Stop:'||i_stop_no, SQLCODE, SUBSTR(SQLERRM, 1, 500), APPLICATION_FUNC, PACKAGE_NAME);
  EXCEPTION
  WHEN OTHERS THEN
    l_msg := 'Insert of Returns to xdock_returns_out failed for manifest#[' || i_manifest_no|| ']';
    pl_log.ins_msg('FATAL', l_func_name, l_msg, SQLCODE, SUBSTR(SQLERRM, 1, 500), APPLICATION_FUNC, PACKAGE_NAME);
  END;

/************************************************************************/  

  PROCEDURE Populate_mfc_rtns_out
    (i_manifest_no IN returns.manifest_no%TYPE)
  IS
  
  /************************************************************************
--  Populate_mfc_rtns_out
--
-- Description:  populates staging table xdock_returns when manifest is closed
--
-- Return/output: populates swms_log if there is any issue
--
-- Modification log: jira 3394
--
-- Date         Developer     Change
-- ------------------------------------------------------------------
-- 24-MAY-2021  vkal9662      Initial version.
--
*************************************************************************/
  
CURSOR c_get_rtn_info
IS
  SELECT 
    r.site_from,
    r.site_to,
    r.site_id,
    r.delivery_document_id,
    r.manifest_no,
    r.route_no,
    r.stop_no,
    r.rec_type,
    r.obligation_no,
    r.prod_id,
    r.cust_pref_vendor,
    r.return_reason_cd,
    r.returned_qty,
    r.returned_split_cd,
    r.catchweight,
    r.disposition,
    r.returned_prod_id,
    r.erm_line_id,
    r.shipped_qty,
    r.shipped_split_cd,
    r.cust_id,
    r.temperature,
    r.status,
    r.rtn_sent_ind,
    r.pod_rtn_ind,
    r.lock_chg,
    r.Add_user,
    r.Add_source,
    r.Add_date,
    r.upd_user ,
    r.upd_source ,
    r.upd_date
  FROM returns r,
    manifests m
  WHERE r.manifest_no   = i_manifest_no
  AND r.manifest_no     = m.manifest_no
  AND r.xdock_ind       ='X' -- for last mile site returns come in marked as X from STS_IN
  AND m.manifest_status = 'CLS'
UNION
SELECT d.site_from,
  d.site_to,
  d.site_id,
  d.delivery_document_id,
  m.manifest_no,
  m.route_no,
  NULL,
  'M',
  d.obligation_no,
  '0',
  '-',
  'X00',
  0,
  null,
  NULL,
  NULL,
  NULL,
  0,
  NULL,
  NULL,
  NULL,
  NULL,
  m.manifest_status,
  NULL,
  NULL,
  NULL,
  'SWMS',
  'INT',
  sysdate,
  'SWMS' ,
  'INT' ,
  sysdate
FROM manifest_dtls d,
     manifests m,
     xdock_order_xref x
WHERE m.manifest_no   = i_manifest_no -- for last mile site returns come in marked as X from STS_IN
AND m.manifest_no     =d.manifest_no
AND m.manifest_status = 'CLS'
AND d.xdock_ind       = 'X'
AND d.rec_type <> 'P'
AND x.manifest_no_to =  m.manifest_no
AND x.delivery_document_id = d.delivery_document_id; -- Jira3704

    l_func_name CONSTANT swms_log.procedure_name%TYPE := 'Populate_mfc_rtns_out';
    l_msg swms_log.msg_text%TYPE;
    l_batch_id  varchar2(14);
    l_seq_no    NUMBER;
    l_rec_count NUMBER := 0;
    l_site_from VARCHAR2(6);
    l_site_to   VARCHAR2(6);
    l_out_param PLS_INTEGER;   
    l_deliver_doc_id VARCHAR2(14);
    l_manifest_out   NUMBER;
    l_route_out      VARCHAR2(10);
    l_obligation_no  VARCHAR2(10);
  BEGIN
    --
      pl_log.ins_msg('INFO', l_func_name, 'before Insert of Returns to xdock_returns_out for site1 manifest: ' , SQLCODE, SUBSTR(SQLERRM, 1, 500), APPLICATION_FUNC, PACKAGE_NAME);
  BEGIN
    SELECT pl_xdock_common.get_batch_id
    INTO l_batch_id
    FROM dual;
  EXCEPTION
    WHEN OTHERS THEN
      pl_log.ins_msg('FATAL',l_func_name, 'Failed to get batch_id from pl_xdock_common.get_batch_id', sqlcode, SUBSTR(SQLERRM, 1, 500), APPLICATION_FUNC, PACKAGE_NAME);
    END;
    
  
    FOR i IN c_get_rtn_info
    LOOP
      SELECT XDOCK_SEQNO_SEQ.nextval INTO l_seq_no FROM dual;
      
      Get_xdock_Manifest(i_manifest_no, 'FULFIL', nvl(i.obligation_no, l_obligation_no), l_manifest_out, l_route_out );
      
      INSERT
      INTO xdock_returns_out
        ( batch_id,
          sequence_no,
          record_status,
          site_from,
          site_to,
          site_id,
          delivery_document_id,
          manifest_no,
          route_no,
          stop_no,
          rec_type,
          obligation_no,
          prod_id,
          cust_pref_vendor,
          return_reason_cd,
          returned_qty,
          returned_split_cd,
          catchweight,
          disposition,
          returned_prod_id,
          erm_line_id,
          shipped_qty,
          shipped_split_cd,
          cust_id,
          temperature,
          status,
          rtn_sent_ind,
          pod_rtn_ind,
          lock_chg,
          Add_user,
          add_source,
          Add_date,
          upd_user ,
          upd_source ,
          upd_date
        )
        VALUES
        (
          l_batch_id,
          l_seq_no,
          'N',
          i.site_from,
          i.site_to,
          i.site_id,
          i.delivery_document_id,
          l_manifest_out,
          l_route_out,
          i.stop_no,
          i.rec_type,
          i.obligation_no,
          i.prod_id ,
          i.cust_pref_vendor,
          i.return_reason_cd,
          i.returned_qty,
          i.returned_split_cd,
          i.catchweight,
          i.disposition,
          i.returned_prod_id,
          i.erm_line_id,
          i.shipped_qty,
          i.shipped_split_cd,
          i.cust_id,
          i.temperature,
          i.Status,
          i.rtn_sent_ind,
          i.pod_rtn_ind,
          NULL,
          REPLACE ( USER, 'OPS$' ) ,
          'INT',
          sysdate,
          REPLACE ( USER, 'OPS$' ) ,
          'INT',
          SYSDATE
        );
      l_rec_count := l_rec_count+1;
      l_site_from := i.site_from;
      l_site_to   := i.site_to;
      l_obligation_no  := i.obligation_no;
    END LOOP;
	 COMMIT;
    l_out_param := PL_MSG_HUB_UTLITY.insert_meta_header(l_batch_id, 'XDOCK_RETURNS_OUT', l_site_to , --data source here is lastmile site
    l_site_from ,                                                                                    --data destination here is fulfilment site
    l_rec_count);
    COMMIT;
    pl_log.ins_msg('INFO', l_func_name, 'Insert of Returns to xdock_returns_out for site1 manifest: '||l_manifest_out ||' sucessful after MFC for site2 manifest:' || i_manifest_no , SQLCODE, SUBSTR(SQLERRM, 1, 500), APPLICATION_FUNC, PACKAGE_NAME);
  EXCEPTION
  WHEN OTHERS THEN
    ROLLBACK;
    l_msg := 'Insert of Returns to xdock_returns_out failed for manifest#[' || i_manifest_no|| ']';
    pl_log.ins_msg('FATAL', l_func_name, l_msg, SQLCODE, SUBSTR(SQLERRM, 1, 500), APPLICATION_FUNC, PACKAGE_NAME);
  END;
  
  /************************************************************************/

  PROCEDURE Populate_imdt_rtns_in
    ( i_batch_id    IN xdock_returns_in.batch_id%TYPE,
      i_manifest_no IN returns.manifest_no%TYPE,
      i_site_from   IN returns.site_from%TYPE,
      i_site_to     IN returns.site_to%TYPE )  IS
      
      
/************************************************************************
-- Populate_imdt_rtns_in
--
-- Description:  populates immidiate returns in to the returns table from staging table
--
-- Return/output: populates swms_log if there is any issue
--
-- Modification log: jira 3394
--
-- Date         Developer     Change
-- ------------------------------------------------------------------
-- 24-MAY-2021  vkal9662      Initial version.
-- 17-Nov-2021 pdas8114      Jira 3841, Do not send temp xdock Returns at Site 2 to site1
--                           commented out temperature field
*************************************************************************/
      
    l_func_name CONSTANT swms_log.procedure_name%TYPE := 'Populate_imdt_returns_in';
    l_msg swms_log.msg_text%TYPE;
    l_batch_id NUMBER;
    l_seq_no   NUMBER;
    l_route_no VARCHAR2(10);
    l_out_param PLS_INTEGER;
    l_site1_manifest NUMBER;
    l_upload_time    DATE;
    l_stop_no        NUMBER;
    l_cust_id Varchar2(15);
    l_rtntrns_cnt NUMBER :=0;
    
    CURSOR c_returns_in
    IS
      SELECT r.site_from,
        r.site_to,
        r.site_id,
        r.delivery_document_id,
        r.manifest_no,
        r.route_no,
        r.stop_no,
        r.rec_type,
        r.obligation_no,
        r.prod_id,
        r.cust_pref_vendor,
        r.return_reason_cd,
        r.returned_qty,
        r.returned_split_cd,
        r.catchweight,
        r.disposition,
        r.returned_prod_id,
        r.erm_line_id,
        r.shipped_qty,
        r.shipped_split_cd,
        r.cust_id,
        r.temperature,
        r.status,
        r.rtn_sent_ind,
        r.pod_rtn_ind,
        r.lock_chg,
        r.Add_user,
        r.Add_source,
        r.Add_date,
        r.upd_user ,
        r.upd_source ,
        r.upd_date
      FROM xdock_returns_in r
      WHERE manifest_no =i_manifest_no
      AND record_status ='N'
      AND site_from     = i_site_from
      AND site_to       = i_site_to
      AND batch_id      = i_batch_id
      AND imdt_rtn_ind  ='Y'
      AND status        ='VAL';
      
  BEGIN
   
    l_upload_time := TO_DATE('01-JAN-1980', 'DD-MON-YYYY');
  
    FOR i IN c_returns_in
    LOOP
      --derive stop number for the fulfilment site
      
    BEGIN
   
      SELECT stop_no, customer_id
      INTO l_stop_no, l_cust_id
      FROM manifest_stops
      WHERE obligation_no = i.obligation_no
      AND manifest_no     = i_manifest_no;
      
    EXCEPTION
    WHEN NO_DATA_FOUND THEN
      
      pl_log.ins_msg('FATAL',l_func_name, 'Failed to get stop_no for manifest, Obligation:'||i_manifest_no||','||i.obligation_no, sqlcode, SUBSTR(SQLERRM, 1, 500), APPLICATION_FUNC, PACKAGE_NAME);
    WHEN OTHERS THEN
      pl_log.ins_msg('FATAL',l_func_name, 'Failed to get stop_no for manifest, Obligation:'||i_manifest_no||','||i.obligation_no, sqlcode, SUBSTR(SQLERRM, 1, 500), APPLICATION_FUNC, PACKAGE_NAME);
    END;  
    
    BEGIN
      INSERT
      INTO returns
        ( site_from,
          site_to,
          site_id,
          delivery_document_id,
          manifest_no,
          route_no,
          stop_no,
          rec_type,
          obligation_no,
          prod_id,
          cust_pref_vendor,
          return_reason_cd,
          returned_qty,
          returned_split_cd,
          catchweight,
          disposition,
          returned_prod_id,
          erm_line_id,
          shipped_qty,
          shipped_split_cd,
          cust_id,
        --  temperature,
          status,
          rtn_sent_ind,
          pod_rtn_ind,
          lock_chg, -- review this column,
          xdock_ind,
          add_user,
          add_source,
          add_date,
          upd_user ,
          upd_source ,
          upd_date )
        VALUES
        ( i_site_from,
          i_site_to,
          i.site_id,
          i.delivery_document_id,
          i_manifest_no,
          i.route_no,
          l_stop_no,
          i.rec_type,
          i.obligation_no,
          i.prod_id ,
          i.cust_pref_vendor,
          i.return_reason_cd,
          i.returned_qty,
          i.returned_split_cd,
          i.catchweight,
          i.disposition,
          i.returned_prod_id,
          i.erm_line_id,
          i.shipped_qty,
          i.shipped_split_cd,
          i.cust_id,
        --  i.temperature,
          i.status,
          i.rtn_sent_ind,
          i.pod_rtn_ind,
          NULL,
          'S',
          REPLACE ( USER, 'OPS$' ) ,
          'INT',
          sysdate,
          REPLACE ( USER, 'OPS$' ) ,
          'INT',
          SYSDATE
        );
        
        l_route_no := i.route_no;
   EXCEPTION
    WHEN OTHERS THEN
    
          pl_log.ins_msg('FATAL',l_func_name, 'Failed to insert return for manifest, Obligation:'||i_manifest_no||','||i.obligation_no, sqlcode, SUBSTR(SQLERRM, 1, 500), APPLICATION_FUNC, PACKAGE_NAME);
    END;
    
    BEGIN
      --insert RTN transaction
      INSERT  INTO TRANS
        (
          TRANS_ID,
          TRANS_TYPE,
          TRANS_DATE,
          batch_no,
          ROUTE_NO,
          STOP_NO,
          ORDER_ID,
          PROD_ID,
          CUST_PREF_VENDOR,
          REC_ID,
          WEIGHT,
          temp,
          QTY,
          UOM,
          REASON_CODE,
          lot_id,
          ORDER_TYPE,
          order_line_id,
          RETURNED_PROD_ID,
          UPLOAD_TIME,
          cmt,
          ADJ_FLAG,
          USER_ID
        )
        VALUES
        (
          TRANS_ID_SEQ.NEXTVAL,
          'RTN',
          SYSDATE,
          '99',
          i.route_no,
          l_STOP_NO,
          i.obligation_no,
          i.PROD_ID,
          i.CUST_PREF_VENDOR,
          i.MANIFEST_NO,
          i.CATCHWEIGHT,
          i.temperature,
          i.returned_qty,
          i.RETURNED_SPLIT_CD,
          i.return_reason_cd,
          i.obligation_no,
          i.REC_TYPE,
          i.erm_line_id,
          i.RETURNED_PROD_ID,
          l_upload_time,
          'POD Return added from SWMS',
          'A',
          USER );
          
          l_rtntrns_cnt := l_rtntrns_cnt +1;
    EXCEPTION
    WHEN OTHERS THEN
    
          pl_log.ins_msg('FATAL',l_func_name, 'Failed to insert RTN trasaction for manifest, item:'||i_manifest_no||','||i.prod_id, sqlcode, SUBSTR(SQLERRM, 1, 500), APPLICATION_FUNC, PACKAGE_NAME);
    END;     
    END LOOP; 
      --insert STC transaction 
      IF l_rtntrns_cnt >0 then 
      
      BEGIN
        INSERT  INTO TRANS
        (
          TRANS_ID,
          TRANS_TYPE,
          TRANS_DATE,
          batch_no,
          ROUTE_NO,
          STOP_NO,
          REC_ID,
          UPLOAD_TIME,
          CUST_ID,
          USER_ID
        )
        VALUES
        (
          TRANS_ID_SEQ.NEXTVAL,
          'STC',
          SYSDATE,
          '99',
          l_route_no,
          l_stop_no,
          i_manifest_no,
          l_upload_time,
          l_cust_id,
          USER     );
          
        EXCEPTION
        WHEN OTHERS THEN
           pl_log.ins_msg('FATAL',l_func_name, 'Failed to insert STC trasaction for manifest, stop:'||i_manifest_no||','||l_stop_no, sqlcode, SUBSTR(SQLERRM, 1, 500), APPLICATION_FUNC, PACKAGE_NAME);
        END;      
        
      End If; -- l_rtntrns_cnt
      
    --Update staging table
    UPDATE xdock_returns_in
    SET record_status ='S'
    WHERE manifest_no =i_manifest_no
    AND record_status ='N'
    AND site_from     = i_site_from
    AND site_to       = i_site_to
    AND batch_id      = i_batch_id
    AND imdt_rtn_ind  = 'Y';
    COMMIT;
    pl_log.ins_msg('INFO', l_func_name, 'Return added from xdoc_returns_in for manifest:' ||i_manifest_no, SQLCODE, SUBSTR(SQLERRM, 1, 500), APPLICATION_FUNC, PACKAGE_NAME);
  EXCEPTION
  WHEN OTHERS THEN
    ROLLBACK;
    --Update staging table with failed status
    UPDATE xdock_returns_in
    SET record_status ='F'
    WHERE manifest_no =i_manifest_no
    AND record_status ='N'
    AND site_from     = i_site_from
    AND site_to       = i_site_to
    AND batch_id      = i_batch_id
    AND imdt_rtn_ind  = 'Y';
    COMMIT;
    l_msg := 'Insert of Returns from xdock_returns_in failed for manifest#[' || i_manifest_no|| ']';
    pl_log.ins_msg('FATAL', l_func_name, l_msg, SQLCODE, SUBSTR(SQLERRM, 1, 500), APPLICATION_FUNC, PACKAGE_NAME);
  END;
  
/************************************************************************/

  PROCEDURE Populate_mfc_rtns_in(
      i_manifest_no IN returns.manifest_no%TYPE,
      i_site_from   IN returns.site_from%TYPE,
      i_site_to     IN returns.site_to%TYPE)  IS
      
/************************************************************************
--  Populate_mfc_rtns_out
--
-- Description:  populates staging table xdock_returns when manifest is closed
--
-- Return/output: populates swms_log if there is any issue
--
-- Modification log: jira 3394
--
-- Date         Developer     Change
-- ------------------------------------------------------------------
-- 24-MAY-2021  vkal9662      Initial version.
-- 25-Oct-2021  vkal9662      Jira 3764 2 issues(Fix delete of multi Manifest returns, 
--                            update XDOCK_ORDER_XREF status after Returns from all
--                            Site2 Manifests are in Site1)
-- 17-Nov-2021 pdas8114      Jira 3841, Do not send temp xdock Returns at Site 2 to site1
--                           commented out temperature field
*************************************************************************/
      
    CURSOR c_get_rtn_info
    IS
      SELECT r.site_from,
        r.site_to,
        r.site_id,
        r.delivery_document_id,
        r.manifest_no,
        r.route_no,
        r.stop_no,
        r.rec_type,
        r.obligation_no,
        r.prod_id,
        r.cust_pref_vendor,
        r.return_reason_cd,
        r.returned_qty,
        r.returned_split_cd,
        r.catchweight,
        r.disposition,
        r.returned_prod_id,
        r.erm_line_id,
        r.shipped_qty,
        r.shipped_split_cd,
        r.cust_id,
        r.temperature,
        r.status,
        r.rtn_sent_ind,
        r.pod_rtn_ind,
        r.lock_chg,
        r.Add_user,
        r.Add_source,
        r.Add_date,
        r.upd_user ,
        r.upd_source ,
        r.upd_date
      FROM xdock_returns_in r
      WHERE r.manifest_no                              = i_manifest_no
      AND r.record_status                              ='N'
      AND site_from                                    = i_site_from
      AND r.rec_type                                   <>'M' -- to eliminate the record that indicates manifest close
      AND site_to                                      = i_site_to
      AND r.status                                     = 'CLS';
      
    l_func_name CONSTANT swms_log.procedure_name%TYPE := 'Populate_mfc_rtns_in';
    l_msg swms_log.msg_text%TYPE;
    l_batch_id  NUMBER;
    l_seq_no    NUMBER;
    l_rec_count NUMBER := 0;
    l_out_param PLS_INTEGER;
    l_upload_time DATE;
    l_stop_no     NUMBER;
    l_mfc_cnt     NUMBER;
    l_xref_cnt    NUMBER;
    l_status      Varchar2(3);
  BEGIN
    --
    -- delete the exsisting immidiate returns 
        
    Begin       
    
      DELETE
      FROM returns
      WHERE manifest_no = i_manifest_no
      AND site_from     = i_site_from
      AND site_to       = i_site_to
      AND xdock_ind     ='S' -- fulfilmentsite returns
      AND delivery_document_id in (select delivery_document_id   --Jira 3764
      FROM xdock_returns_in r
      WHERE r.manifest_no  = i_manifest_no
      AND r.record_status  ='N'
      AND site_from        = i_site_from
      AND r.rec_type       <>'M' 
      AND site_to          = i_site_to
      AND r.status         = 'CLS');  
     Exception 
       When No_data_found then 
         null;
       When Others then
         l_msg := 'Unable to delete immidiate Returns original records for: ' || i_manifest_no;
         pl_log.ins_msg('FATAL', l_func_name, l_msg, SQLCODE, SUBSTR(SQLERRM, 1, 500), APPLICATION_FUNC, PACKAGE_NAME);
     END;  
    -- add code to count records and put a message to swms_log
    FOR i IN c_get_rtn_info
    LOOP
      --derive stop number for the fulfilment site
      Begin
        SELECT stop_no
        INTO l_stop_no
        FROM manifest_stops
        WHERE obligation_no = i.obligation_no
        AND manifest_no     = i_manifest_no;
      
      Exception 
      When No_data_found then 
        l_stop_no := null;
        l_msg := 'Unable to find Sop number in the Fulfilment site for Manifest:' || i_manifest_no;
        pl_log.ins_msg('FATAL', l_func_name, l_msg, SQLCODE, SUBSTR(SQLERRM, 1, 500), APPLICATION_FUNC, PACKAGE_NAME);
      When Others then
         l_msg := 'Unable to find Sop number in the Fulfilment site for Manifest:' || i_manifest_no;
         pl_log.ins_msg('FATAL', l_func_name, l_msg, SQLCODE, SUBSTR(SQLERRM, 1, 500), APPLICATION_FUNC, PACKAGE_NAME);
      End;
      
      INSERT
      INTO returns
        ( site_from,
          site_to,
          site_id,
          delivery_document_id,
          manifest_no,
          route_no,
          stop_no,
          rec_type,
          obligation_no,
          prod_id,
          cust_pref_vendor,
          return_reason_cd,
          returned_qty,
          returned_split_cd,
          catchweight,
          disposition,
          returned_prod_id,
          erm_line_id,
          shipped_qty,
          shipped_split_cd,
          cust_id,
        --  temperature,
          status,
          rtn_sent_ind,
          pod_rtn_ind,
          lock_chg, -- review this column
          xdock_ind,
          add_user,
          add_source,
          add_date,
          upd_user ,
          upd_source ,
          upd_date
        )
        VALUES
        ( i.site_from,
          i.site_to,
          i.site_id,
          i.delivery_document_id,
          i_manifest_no,
          i.route_no,
          l_stop_no,
          i.rec_type,
          i.obligation_no,
          i.prod_id ,
          i.cust_pref_vendor,
          i.return_reason_cd,
          i.returned_qty,
          i.returned_split_cd,
          i.catchweight,
          i.disposition,
          i.returned_prod_id,
          i.erm_line_id,
          i.shipped_qty,
          i.shipped_split_cd,
          i.cust_id,
        --  i.temperature,
          'VAL',
          i.rtn_sent_ind,
          i.pod_rtn_ind,
          NULL,
          'S',
          REPLACE ( USER, 'OPS$' ) ,
          'INT',
          sysdate,
          REPLACE ( USER, 'OPS$' ) ,
          'INT',
          SYSDATE
        );
      BEGIN
        UPDATE manifest_dtls
        SET manifest_dtl_status = 'RTN'
        WHERE manifest_no       = i_manifest_no
        AND (stop_no            = i.stop_no
        OR stop_no             IS NULL)
        AND prod_id             = i.prod_id
        AND cust_pref_vendor    = i.cust_pref_vendor
        AND obligation_no       = i.obligation_no
        AND shipped_split_cd    = i.shipped_split_cd;
      EXCEPTION
      WHEN OTHERS THEN
        l_msg := 'ERROR. Attempted to update manifest_dtls to RTN status during '||l_func_name;
        pl_log.ins_msg('WARN', l_func_name, l_msg, NULL, NULL, APPLICATION_FUNC, PACKAGE_NAME);
      END ; -- updating manifest_dtls
    END LOOP;
    
  --changes done below for Jira 3764 issue2(update XDOCK_ORDER_XREF status after Returns from all Site2 Manifests are in Site1)
     
   Begin
    --Update staging table status to S
      UPDATE xdock_returns_in
      SET record_status ='S'
      WHERE manifest_no =i_manifest_no
      AND record_status ='N'
      AND site_from     = i_site_from        
      AND site_to       = i_site_to;
      COMMIT;
      l_status := 'S';
      pl_log.ins_msg('INFO', l_func_name, 'Retruns Inserted sucessful after MFC for manifest:' || i_manifest_no , SQLCODE, SUBSTR(SQLERRM, 1, 500), APPLICATION_FUNC, PACKAGE_NAME);
   EXCEPTION WHEN OTHERS THEN
      ROLLBACK;
    --Update staging table with failed status
    l_status := 'F';
    UPDATE xdock_returns_in
    SET record_status ='F'
    WHERE manifest_no =i_manifest_no
    AND record_status ='N'
    AND site_from     = i_site_from
    AND site_to       = i_site_to;
    COMMIT;
    l_msg := 'Insert of Returns  failed for manifest#[' || i_manifest_no|| ']';
    pl_log.ins_msg('FATAL', l_func_name, l_msg, SQLCODE, SUBSTR(SQLERRM, 1, 500), APPLICATION_FUNC, PACKAGE_NAME);
    
   End;
      
    If l_status = 'S' then
      select count(Route_no_to) into l_xref_cnt 
      FROM XDOCK_ORDER_XREF r
      WHERE r.manifest_no_from = i_manifest_no;
      
      select count(*) into l_mfc_cnt
      FROM xdock_returns_in r
      WHERE r.manifest_no                              = i_manifest_no
      AND r.record_status                              ='S'
      AND site_from                                    = i_site_from
      AND site_to                                      = i_site_to
      AND r.rec_type                                   ='M' -- to eliminate the record that indicates manifest close
      AND r.status                                     = 'CLS';
     
      If l_mfc_cnt = l_xref_cnt  then
      Begin
         --update xdock_order_xref status columns if all of the Manifest Returns data for the Routes mapped to site one route have been sucessfully imported
      
        UPDATE XDOCK_ORDER_XREF 
        SET s_fullfillment_status ='MANIFEST'
        WHERE manifest_no_from =i_manifest_no
        AND site_from     = i_site_from        
        AND site_to       = i_site_to;
        
        pl_log.ins_msg('INFO', l_func_name, 'Update of XDOCK_ORDER_XREF last_mile_status sucessful for manifest:' || i_manifest_no , SQLCODE, SUBSTR(SQLERRM, 1, 500), APPLICATION_FUNC, PACKAGE_NAME);
      Exception when Others  then
        pl_log.ins_msg('INFO', l_func_name, 'Update of XDOCK_ORDER_XREF last_mile_status unsucessful for manifest:' || i_manifest_no , SQLCODE, SUBSTR(SQLERRM, 1, 500), APPLICATION_FUNC, PACKAGE_NAME);
      End;  
      
         /* OPCOF-3669: Update DCI Ready flag when the manifest is closed at last mile site. Update manifests.sts_completed_ind = 'Y' */
        BEGIN
          UPDATE manifests 
          SET sts_completed_ind ='Y'
          WHERE manifest_no = i_manifest_no;
          COMMIT;
          pl_log.ins_msg('INFO', l_func_name, 'Updating manifests.sts_completed_ind to Y for manifest: ' || i_manifest_no , SQLCODE, SUBSTR(SQLERRM, 1, 500), APPLICATION_FUNC, PACKAGE_NAME);
        EXCEPTION WHEN OTHERS THEN
          pl_log.ins_msg('WARN', l_func_name, 'Failed to update manifests.sts_completed_ind to Y for manifest: ' || i_manifest_no , SQLCODE, SUBSTR(SQLERRM, 1, 500), APPLICATION_FUNC, PACKAGE_NAME);
        End;
        /* OPCOF-3669 Ends. */
      
      End If;  --l_mfc_cnt = l_xref_cnt
      
   End If; --l_status = 'S'
   
   
    EXCEPTION
    WHEN OTHERS THEN
      ROLLBACK;
    --Update staging table with failed status
    UPDATE xdock_returns_in
    SET record_status ='F'
    WHERE manifest_no =i_manifest_no
    AND record_status ='N'
    AND site_from     = i_site_from
    AND site_to       = i_site_to;
    COMMIT;
    l_msg := 'Insert of Returns  failed for manifest#[' || i_manifest_no|| ']';
    pl_log.ins_msg('FATAL', l_func_name, l_msg, SQLCODE, SUBSTR(SQLERRM, 1, 500), APPLICATION_FUNC, PACKAGE_NAME);
    
       
    
  END;
  /************************************************************************/
  
  PROCEDURE Get_xdock_Manifest(
      i_manifest_no   IN returns.manifest_no%TYPE,
      i_site_type     IN VARCHAR2,
      i_obligation_no IN returns.obligation_no%TYPE,
      o_manifest_no OUT returns.manifest_no%TYPE,
      o_route_no OUT manifests.route_no%TYPE)  IS
      
/************************************************************************
--  Get_xdock_Manifest
--
-- Description: Derives xdock manifest and route
--
-- Return/output: xdock manifest, route
--
-- Modification log: jira 3394
--
-- Date         Developer     Change
-- ------------------------------------------------------------------
-- 24-MAY-2021  vkal9662      Initial version.
--
*************************************************************************/      
      
    l_manifest_no NUMBER;
    l_route_no    VARCHAR2(10);
    l_func_name   CONSTANT swms_log.procedure_name%TYPE := 'Get_xdock_Manifest';
    l_msg swms_log.msg_text%TYPE;
  BEGIN
    IF i_site_type ='FULFIL' THEN
    
      SELECT Manifest_no_From, Route_no_from
      INTO l_manifest_no, l_route_no
      FROM XDOCK_ORDER_XREF  
      WHERE manifest_no_to = i_manifest_no
      AND obligation_no    = i_obligation_no;
      
    Elsif i_site_type      ='LASTMILE' THEN
    
      SELECT Manifest_no_to, Route_no_to
      INTO l_manifest_no,   l_route_no
      FROM XDOCK_ORDER_XREF
      WHERE manifest_no_from = i_manifest_no
      AND obligation_no      = i_obligation_no;
      
    ELSE
      l_msg := 'Cannot derive xdock '||i_site_type|| ' Manifest info for :' || i_manifest_no|| ', Obligation_no:'||i_obligation_no;
      pl_log.ins_msg('FATAL', l_func_name, l_msg, SQLCODE, SUBSTR(SQLERRM, 1, 500), APPLICATION_FUNC, PACKAGE_NAME);
    END IF;
    o_manifest_no := l_manifest_no;
    o_route_no    := l_route_no;
    
  EXCEPTION
  WHEN NO_DATA_FOUND  THEN
     l_msg := 'No data found to derive xdock '||i_site_type|| ' Manifest info for :' || i_manifest_no|| ', Obligation_no:'||i_obligation_no;
     pl_log.ins_msg('FATAL', l_func_name, l_msg, SQLCODE, SUBSTR(SQLERRM, 1, 500), APPLICATION_FUNC, PACKAGE_NAME);
  WHEN OTHERS THEN
     l_msg := 'Cannot derive xdock '||i_site_type|| ' Manifest info for :' || i_manifest_no|| ', Obligation_no:'||i_obligation_no;
     pl_log.ins_msg('FATAL', l_func_name, l_msg, SQLCODE, SUBSTR(SQLERRM, 1, 500), APPLICATION_FUNC, PACKAGE_NAME);
  END;
  
  /************************************************************************
    -- get_xdock_dest_loc 
    --
    -- Description:       process to get xdock destination location during create puts.
    --      
    -- Return/output:    o_rtn_err: status code indicating success or error.
    --
    -- Modification log:
    --
    -- Date         Developer     Change
    -- ------------------------------------------------------------------
    -- 15-JUL-2021  vkal9662      Initial version.
    --
    *************************************************************************/
Procedure get_xdock_dest_loc(p_site_from returns.site_from%TYPE, 
                             p_item pm.prod_id%TYPE,  
                             o_dest_loc  OUT putawaylst.dest_loc%TYPE,
                             o_rtn_err OUT returns.err_comment%TYPE) 
is
  l_des_loc varchar2(12);
  l_func_name CONSTANT swms_log.procedure_name%TYPE := 'get_xdock_dest_loc';
  l_msg VARCHAR2(4000) := NULL;
  l_site_from  returns.site_from%TYPE :=p_site_from;
  l_prod_id   pm.prod_id%TYPE := p_item;

Begin


Begin
  SELECT l.logi_loc into l_des_loc
  FROM loc l,
  lzone lz,
  zone z,
  aisle_info f,
  pm p,
  swms_sub_areas s
  WHERE lz.zone_id    = z.zone_id
  AND lz.logi_loc     = l.logi_loc
  AND l.status        = 'AVL'
  AND z.rule_id       = 15
  AND z.zone_type     = 'PUT'
  AND f.name          = SUBSTR(l.logi_loc,1,2)
  AND p.area          = s.area_code
  AND s.sub_area_code = f.sub_area_code
  AND z.site_from     = l_site_from
  AND p.prod_id       = l_prod_id;
  
  o_dest_loc := l_des_loc;
  
Exception when No_data_found then
  
 l_msg := 'No xdock Putaway Location setup for: '|| l_site_from;
 o_rtn_err := 'No Putaway Loc setup for: '|| l_site_from;
 pl_log.ins_msg('FATAL', l_func_name, l_msg, SQLCODE, SUBSTR(SQLERRM, 1, 500), APPLICATION_FUNC, PACKAGE_NAME);
 o_dest_loc := Null;
when too_many_rows then  
 l_msg := 'Too xdock many Locations setup for: '|| l_site_from;
 o_rtn_err := 'Too many Putaway Loc setup for: '|| l_site_from;
 pl_log.ins_msg('FATAL', l_func_name, l_msg, SQLCODE, SUBSTR(SQLERRM, 1, 500), APPLICATION_FUNC, PACKAGE_NAME);
 o_dest_loc := Null;
When Others then
 o_dest_loc := Null;
 o_rtn_err := 'Cannot derive xdock Return Putaway Loc.';
 pl_log.ins_msg('FATAL', l_func_name, l_msg, SQLCODE, SUBSTR(SQLERRM, 1, 500), APPLICATION_FUNC, PACKAGE_NAME);
End;  
  
End; --get_xdock_dest_loc

PROCEDURE Get_Manifest_status(
      i_manifest_no   IN returns.manifest_no%TYPE,
      i_site_type     IN VARCHAR2,
      i_site_from     IN VARCHAR2,
      i_site_to     IN VARCHAR2,
      o_manifest_status OUT VARCHAR2)  IS

/************************************************************************
--  Get_Manifest_status
--
-- Description: Derives xdock manifest status
--
-- Return/output: status
--
-- Modification log: jira 3396, 3505
--
-- Date         Developer     Change
-- ------------------------------------------------------------------
-- 18-Aug-2021  vkal9662      Initial version.
--
*************************************************************************/      
      
    l_manifest_no NUMBER;
    l_status      VARCHAR2(10);
    l_route_no    VARCHAR2(10);
    l_func_name   CONSTANT swms_log.procedure_name%TYPE := 'Get_xdock_Manifest';
    l_msg swms_log.msg_text%TYPE;
  BEGIN
    IF i_site_type ='LASTMILE' THEN
    
      SELECT distinct x_lastmile_status
      INTO l_status
      FROM XDOCK_ORDER_XREF  
      WHERE manifest_no_to = i_manifest_no
      AND site_from        = i_site_from        
      AND site_to          = i_site_to;
     
   
    Elsif i_site_type  ='FULFIL' THEN
    
      SELECT distinct s_fullfillment_status
      INTO l_status
      FROM XDOCK_ORDER_XREF
      WHERE manifest_no_from = i_manifest_no
      AND site_from          = i_site_from        
      AND site_to            = i_site_to;
   
    ELSE
      l_status := null;
      l_msg := 'Cannot derive xdock '||i_site_type|| ' Manifest Status for :' || i_manifest_no;
      pl_log.ins_msg('FATAL', l_func_name, l_msg, SQLCODE, SUBSTR(SQLERRM, 1, 500), APPLICATION_FUNC, PACKAGE_NAME);
    END IF;
    
     o_manifest_status := l_status;
    
  EXCEPTION
  WHEN NO_DATA_FOUND  THEN
     l_msg := 'No data found to derive xdock '||i_site_type|| ' Manifest status for :' || i_manifest_no;
     pl_log.ins_msg('FATAL', l_func_name, l_msg, SQLCODE, SUBSTR(SQLERRM, 1, 500), APPLICATION_FUNC, PACKAGE_NAME);
  WHEN OTHERS THEN
     l_msg := 'Cannot derive xdock '||i_site_type|| ' Manifest status for :' || i_manifest_no;
     pl_log.ins_msg('FATAL', l_func_name, l_msg, SQLCODE, SUBSTR(SQLERRM, 1, 500), APPLICATION_FUNC, PACKAGE_NAME);
  END;

END pl_rtn_xdock_interface;
/
GRANT EXECUTE ON swms.pl_rtn_xdock_interface TO swms_user;
CREATE OR REPLACE PUBLIC SYNONYM pl_rtn_xdock_interface FOR swms.pl_rtn_xdock_interface;