create or replace package pl_xdock_mnft_dtls_interface as
    ----------------------
    -- Package constants
    ----------------------
    /************************************************************************
    -- pl_xdock_mnft_dtls_interface
    --
    -- Description:   Package for xdock manifest details functionalities related to cross dock
    --
    --
    -- Modification log: jira 3381
    --
    -- Date         Developer     Change
    -- ------------------------------------------------------------------
    -- 10-Aug-2021  cjay3161      Initial version.
	-- 07-Oct-2021  pdas8114      Jira# 3702 Site 2 Pickup request is not showing on STS
	--                            added procedure to load prod details to xdock_pm_out for P record
    *************************************************************************/

    ---------------------------------
    -- function/procedure signatures
    ---------------------------------

    PACKAGE_NAME CONSTANT swms_log.program_name%TYPE := 'pl_xdock_mnft_dtls_interface';
    APPLICATION_FUNC CONSTANT swms_log.application_func%TYPE := 'POPULATE_XDOCK_MANIFEST_DTLS';

    PROCEDURE Populate_xdock_mnft_dtls_out(
        i_manifest_no IN xdock_manifest_dtls_out.manifest_no%TYPE
    );

    PROCEDURE Populate_xdock_mnft_dtls_in(
        i_batch_id in xdock_manifest_dtls_in.batch_id%type,
        i_manifest_no_from_source in xdock_manifest_dtls_in.manifest_no%type,
        i_delivery_document_id in xdock_manifest_dtls_in.delivery_document_id%type,
        i_site_from in xdock_manifest_dtls_in.site_from%type
    );

    PROCEDURE Populate_xdock_meta_header;

END pl_xdock_mnft_dtls_interface;
/

create or replace PACKAGE BODY pl_xdock_mnft_dtls_interface as

    PROCEDURE Populate_xdock_mnft_dtls_out(
        i_manifest_no in xdock_manifest_dtls_out.manifest_no%type
    ) AS

        l_func_name CONSTANT swms_log.procedure_name%TYPE := 'Populate_xdock_mnft_dtls_out';
        l_msg                swms_log.msg_text%TYPE;
        l_batch_id           xdock_manifest_dtls_out.batch_id%TYPE;
        l_site_from          xdock_manifest_dtls_out.site_from%TYPE;
        l_site_to            xdock_manifest_dtls_out.site_to%TYPE;
        l_seq_no             xdock_manifest_dtls_out.sequence_no%TYPE;
        l_response           PLS_INTEGER;
        l_record_count       PLS_INTEGER := 0;
        CURSOR c_get_manifest_dtls_returns
            IS
            SELECT m.manifest_no,
                   m.site_id,
                   m.site_from,
                   m.site_to,
                   m.delivery_document_id,
                   m.stop_no,
                   m.rec_type,
                   m.obligation_no,
                   m.prod_id,
                   m.cust_pref_vendor,
                   m.shipped_qty,
                   m.shipped_split_cd,
                   m.manifest_dtl_status,
                   m.orig_invoice,
                   m.invoice_no,
                   m.pod_flag,
                   r.return_reason_cd,
                   r.disposition,
                   r.erm_line_id,
                   r.route_no,
                   r.add_user,
                   r.add_source,
                   r.add_date
            FROM manifest_dtls m
                     LEFT JOIN returns r
                               ON m.manifest_no = r.manifest_no
                                   AND m.stop_no = r.stop_no
                                   AND m.obligation_no = r.obligation_no
                                   AND m.prod_id = r.prod_id
                                   AND m.cust_pref_vendor = r.cust_pref_vendor
                                   AND m.rec_type = 'P'
                     LEFT JOIN xdock_manifest_dtls_out mo
                                ON m.manifest_no = mo.manifest_no
                                    AND m.stop_no = mo.stop_no
                                    AND m.obligation_no = mo.obligation_no
                                    AND m.prod_id = mo.prod_id
                                    AND m.cust_pref_vendor = mo.cust_pref_vendor
            WHERE m.manifest_no = i_manifest_no
              AND m.xdock_ind = 'S'
              AND mo.manifest_no is null;

    BEGIN

        BEGIN
            SELECT mo.batch_id
            INTO l_batch_id
            FROM xdock_manifest_dtls_out mo
            WHERE mo.manifest_no = i_manifest_no AND mo.record_status = 'N'
            AND ROWNUM=1;

        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                SELECT pl_xdock_common.get_batch_id
                INTO l_batch_id
                FROM dual;
            WHEN OTHERS THEN
                pl_log.ins_msg('ERROR', l_func_name, 'Failed to get batch_id from pl_xdock_common.get_batch_id',
                               sqlcode, SUBSTR(SQLERRM, 1, 500), APPLICATION_FUNC, PACKAGE_NAME);
                RETURN;
        END;

        FOR i IN c_get_manifest_dtls_returns
            LOOP

                SELECT XDOCK_SEQNO_SEQ.nextval INTO l_seq_no FROM dual;


                INSERT
                INTO xdock_manifest_dtls_out
                (batch_id,
                 sequence_no,
                 record_status,
                 site_id,
                 site_from,
                 site_to,
                 delivery_document_id,
                 manifest_no,
                 stop_no,
                 rec_type,
                 obligation_no,
                 prod_id,
                 cust_pref_vendor,
                 shipped_qty,
                 shipped_split_cd,
                 manifest_dtl_status,
                 orig_invoice,
                 invoice_no,
                 pod_flag,
                 return_reason_cd,
                 disposition,
                 erm_line_id,
                 route_no,
                 add_user,
                 add_source,
                 add_date)
                VALUES (l_batch_id,
                        l_seq_no,
                        'N',
                        i.site_id,
                        i.site_from,
                        i.site_to,
                        i.delivery_document_id,
                        i.manifest_no,
                        i.stop_no,
                        i.rec_type,
                        i.obligation_no,
                        i.prod_id,
                        i.cust_pref_vendor,
                        i.shipped_qty,
                        i.shipped_split_cd,
                        i.manifest_dtl_status,
                        i.orig_invoice,
                        i.invoice_no,
                        i.pod_flag,
                        i.return_reason_cd,
                        i.disposition,
                        i.erm_line_id,
                        i.route_no,
                        nvl(i.add_user,USER),
                        i.add_source,
                        nvl(i.add_date,sysdate));

                l_site_from := i.site_from;
                l_site_to := i.site_to;
                l_record_count := l_record_count+1;
            End LOOP;
            
			--Jira# 3702 calling proc to populate xdock_pm_out to load P records prod details to be sent to site 2
			PL_XDOCK_PM_OUT.PROCESS_XDOCK_MANIFEST_PM(i_manifest_no);
			
        pl_log.ins_msg('DEBUG', l_func_name,
                       'Maifest dtls added to xdoc_manifest_dtls_out for manifest: ' || i_manifest_no, SQLCODE,
                       SUBSTR(SQLERRM, 1, 500), APPLICATION_FUNC, PACKAGE_NAME);

    EXCEPTION
        WHEN OTHERS THEN
            l_msg := 'Insert of Manifest to xdoc_manifest_dtls_out failed for manifest#[' || i_manifest_no || ']';
            pl_log.ins_msg('ERROR', l_func_name, l_msg, SQLCODE, SUBSTR(SQLERRM, 1, 500), APPLICATION_FUNC,
                           PACKAGE_NAME);
    END Populate_xdock_mnft_dtls_out;


    PROCEDURE Populate_xdock_mnft_dtls_in(
        i_batch_id in xdock_manifest_dtls_in.batch_id%type,
        i_manifest_no_from_source in xdock_manifest_dtls_in.manifest_no%type,
        i_delivery_document_id in xdock_manifest_dtls_in.delivery_document_id%type,
        i_site_from in xdock_manifest_dtls_in.site_from%type
    ) AS
        l_func_name CONSTANT  swms_log.procedure_name%TYPE := 'Populate_xdock_mnft_dtls_in';
        l_manifest_no_in_dest manifests.manifest_no%TYPE;
        l_route_no            manifests.route_no%TYPE;
        l_manifest_count      NUMBER;
        l_stop_no             manifest_dtls.stop_no%TYPE;
        l_xdock_ind           manifest_dtls.xdock_ind%TYPE;
        l_site_id             manifest_dtls.site_id%TYPE;
        l_pod_flag            manifest_dtls.pod_flag%TYPE;
        l_erm_line_id         returns.erm_line_id%TYPE;
        CURSOR c_get_manifest_dtls_ins
            IS
            SELECT manifest_no,
                   site_from,
                   site_to,
                   stop_no,
                   rec_type,
                   obligation_no,
                   prod_id,
                   cust_pref_vendor,
                   shipped_qty,
                   shipped_split_cd,
                   manifest_dtl_status,
                   orig_invoice,
                   invoice_no,
                   pod_flag,
                   delivery_document_id
            FROM xdock_manifest_dtls_in
            WHERE batch_id = i_batch_id
                AND manifest_no = i_manifest_no_from_source
                AND delivery_document_id = i_delivery_document_id
                AND site_from = i_site_from
                AND record_status = 'N'
            GROUP BY manifest_no, site_from, site_to, stop_no, rec_type, obligation_no, prod_id, cust_pref_vendor,
                     shipped_qty, shipped_split_cd, manifest_dtl_status, orig_invoice, invoice_no, pod_flag,
                     delivery_document_id;

        CURSOR c_get_mnft_dtls_ins_for_rtn
            IS
            SELECT batch_id,
                   site_from,
                   site_to,
                   manifest_no,
                   stop_no,
                   rec_type,
                   obligation_no,
                   prod_id,
                   cust_pref_vendor,
                   return_reason_cd,
                   disposition,
                   shipped_qty,
                   shipped_split_cd,
                   erm_line_id,
                   route_no,
                   delivery_document_id,
                   add_user,
                   add_date
            FROM xdock_manifest_dtls_in
            WHERE batch_id = i_batch_id
              AND manifest_no = i_manifest_no_from_source
              AND delivery_document_id = i_delivery_document_id
              AND site_from = i_site_from
              AND record_status = 'N'
              AND rec_type = 'P'
            GROUP BY batch_id,manifest_no, site_from, site_to, stop_no, rec_type, obligation_no, prod_id, cust_pref_vendor,
                     return_reason_cd,disposition,shipped_qty, shipped_split_cd,erm_line_id,route_no,
                     delivery_document_id,add_user,add_date;

    BEGIN
        BEGIN
            SELECT manifest_no_to
            INTO l_manifest_no_in_dest
            FROM xdock_order_xref
            WHERE DELIVERY_DOCUMENT_ID = i_delivery_document_id
            AND site_from = i_site_from
            AND ROWNUM = 1;
        EXCEPTION
            WHEN no_data_found THEN
            BEGIN
                -- if xdock_order_xref doesn't have a record for the given delivery doc id
                -- if rec type is P then -> go and fetch l_manifest_no_in_dest using a non P delivery doc id in same batch
                select distinct(x.manifest_no_to)
                    INTO l_manifest_no_in_dest
                    from xdock_manifest_dtls_in mfdi1
                    inner join xdock_manifest_dtls_in mfdi2 on mfdi1.batch_id = mfdi2.batch_id and mfdi2.rec_type!='P'
                    inner join xdock_order_xref x on mfdi2.delivery_document_id = x.delivery_document_id
                    where mfdi1.batch_id = i_batch_id and mfdi1.rec_type = 'P'
                    AND ROWNUM = 1;
            EXCEPTION
                WHEN no_data_found THEN
                    pl_log.ins_msg('DEBUG', l_func_name,
                                                       'Destination manifest no not found for delivery document id :'
                                                       || i_delivery_document_id || ' for entire batch_id records'
                                                       , sqlcode, SUBSTR(SQLERRM, 1, 500),
                                                       APPLICATION_FUNC, PACKAGE_NAME);
            END;
        END;

        UPDATE xdock_order_xref
            SET manifest_no_from = i_manifest_no_from_source
            WHERE DELIVERY_DOCUMENT_ID = i_delivery_document_id
            AND site_from = i_site_from;

        SELECT count(manifest_no)
        INTO l_manifest_count
        FROM manifests
        WHERE manifest_no = l_manifest_no_in_dest;

        IF l_manifest_no_in_dest IS NOT NULL AND l_manifest_count > 0 THEN
            BEGIN
                FOR i IN c_get_manifest_dtls_ins
                    LOOP
                        BEGIN

                            select stop_no,xdock_ind,site_id,pod_flag
                            into l_stop_no,l_xdock_ind,l_site_id,l_pod_flag
                            from manifest_stops
                            where manifest_no = l_manifest_no_in_dest AND DELIVERY_DOCUMENT_ID = i_delivery_document_id
                            AND ROWNUM = 1;


                            INSERT
                            INTO manifest_dtls
                            (manifest_no,
                             site_from,
                             site_to,
                             stop_no,
                             rec_type,
                             obligation_no,
                             prod_id,
                             cust_pref_vendor,
                             shipped_qty,
                             shipped_split_cd,
                             manifest_dtl_status,
                             orig_invoice,
                             invoice_no,
                             pod_flag,
                             delivery_document_id,
                             xdock_ind,
                             site_id)
                            VALUES (l_manifest_no_in_dest,
                                    i.site_from,
                                    i.site_to,
                                    l_stop_no,
                                    i.rec_type,
                                    i.obligation_no,
                                    i.prod_id,
                                    i.cust_pref_vendor,
                                    i.shipped_qty,
                                    i.shipped_split_cd,
                                    i.manifest_dtl_status,
                                    i.orig_invoice,
                                    i.invoice_no,
                                    l_pod_flag,
                                    i.delivery_document_id,
                                    l_xdock_ind,
                                    l_site_id);
                        END;
                    END LOOP;

                FOR i IN c_get_mnft_dtls_ins_for_rtn
                    LOOP
                        BEGIN
                            select route_no
                            INTO l_route_no
                            from manifests
                            where manifest_no = l_manifest_no_in_dest
                                AND ROWNUM = 1;

                            select stop_no,xdock_ind,site_id
                            into l_stop_no,l_xdock_ind,l_site_id
                            from manifest_stops
                            where manifest_no = l_manifest_no_in_dest AND DELIVERY_DOCUMENT_ID = i_delivery_document_id
                                AND ROWNUM = 1;

                            select nvl(max(erm_line_id),0)+1
                            into l_erm_line_id
                            from returns
                            where manifest_no = l_manifest_no_in_dest;

                            INSERT INTO returns
                            (manifest_no,
                             site_from,
                             site_to,
                             route_no,
                             stop_no,
                             rec_type,
                             obligation_no,
                             prod_id,
                             cust_pref_vendor,
                             return_reason_cd,
                             disposition,
                             erm_line_id,
                             shipped_qty,
                             shipped_split_cd,
                             lock_chg,
                             xdock_ind,
                             add_user,
                             add_source,
                             add_date,
                             upd_user,
                             upd_source,
                             upd_date,
                             delivery_document_id,
                             site_id)
                            VALUES (l_manifest_no_in_dest,
                                    i.site_from,
                                    i.site_to,
                                    l_route_no,
                                    l_stop_no,
                                    i.rec_type,
                                    i.obligation_no,
                                    i.prod_id,
                                    i.cust_pref_vendor,
                                    i.return_reason_cd,
                                    i.disposition,
                                    l_erm_line_id,
                                    i.shipped_qty,
                                    i.shipped_split_cd,
                                    NULL,
                                    'X',
                                    i.add_user,
                                    l_xdock_ind,
                                    i.add_date,
                                    NULL,
                                    NULL,
                                    NULL,
                                    i.delivery_document_id,
                                    l_site_id);

                        END;
                    END LOOP;

                UPDATE xdock_manifest_dtls_in
                SET record_status ='S'
                WHERE manifest_no = i_manifest_no_from_source
                  AND delivery_document_id = i_delivery_document_id
                  AND record_status = 'N';
                COMMIT;
                pl_log.ins_msg('DEBUG', l_func_name,
                               'Manifest details record created to for manifest:' ||
                               l_manifest_no_in_dest ||' for the records from site :' ||i_site_from , SQLCODE, SUBSTR(SQLERRM, 1, 500), APPLICATION_FUNC,
                               PACKAGE_NAME);

            EXCEPTION
                WHEN OTHERS THEN
                    ROLLBACK;
                    UPDATE xdock_manifest_dtls_in
                    SET record_status ='F'
                    WHERE manifest_no = i_manifest_no_from_source
                      AND delivery_document_id = i_delivery_document_id
                      AND record_status = 'N';
                    COMMIT;
                    pl_log.ins_msg('ERROR', l_func_name,
                                   'Failed to create manifest dtls for manifest :' || l_manifest_no_in_dest ||
                                   ' for the records from site  : ' || i_site_from, sqlcode, SUBSTR(SQLERRM, 1, 500),
                                   APPLICATION_FUNC, PACKAGE_NAME);
            END;
        END IF;
    END Populate_xdock_mnft_dtls_in;


    PROCEDURE Populate_xdock_meta_header AS
        l_func_name CONSTANT  swms_log.procedure_name%TYPE := 'Populate_xdock_meta_header';
        l_out_param          PLS_INTEGER;
        CURSOR c_get_new_meta_headers
            IS
            SELECT m.batch_id,
                   m.site_from,
                   m.site_to,
                   count(m.sequence_no) as rec_count
            FROM xdock_manifest_dtls_out m
                     LEFT JOIN xdock_meta_header h
                               ON m.batch_id = h.batch_id
            WHERE h.batch_id is null AND m.record_status = 'N'
            GROUP BY m.batch_id,
                    m.site_from,
                    m.site_to;
    BEGIN

        FOR i IN c_get_new_meta_headers
            LOOP
                l_out_param :=
                      PL_MSG_HUB_UTLITY.insert_meta_header(i.batch_id, 'XDOCK_MANIFEST_DTLS_OUT', i.site_from, i.site_to,
                                                           i.rec_count);

                IF l_out_param = 0 THEN
                  pl_log.ins_msg('INFO', l_func_name,
                                 'Meta header added to xdoc_manifest_dtls_out for batch_id: ' || i.batch_id, SQLCODE,
                                 SUBSTR(SQLERRM, 1, 500), APPLICATION_FUNC, PACKAGE_NAME);
                ELSE
                  pl_log.ins_msg('ERROR', l_func_name,
                                 'Meta header adding to xdoc_manifest_dtls_out for batch_id: ' || i.batch_id ||
                                 'process failed', SQLCODE,
                                 SUBSTR(SQLERRM, 1, 500), APPLICATION_FUNC, PACKAGE_NAME);
                END IF;
            END LOOP;
    END Populate_xdock_meta_header;

END pl_xdock_mnft_dtls_interface;
/

GRANT EXECUTE ON swms.pl_xdock_mnft_dtls_interface TO swms_user;
CREATE OR REPLACE PUBLIC SYNONYM pl_xdock_mnft_dtls_interface FOR swms.pl_xdock_mnft_dtls_interface;