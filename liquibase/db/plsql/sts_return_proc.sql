/* 3/25/20 M.C
  modify the pod_rtn_ind change 'U' to 'A' when MFR already created rec in returns table and SR is process from the return process

*/
CREATE OR REPLACE
PROCEDURE        SWMS.STS_RETURN         (
    sz_manifest_no IN VARCHAR,
    sz_route_no IN VARCHAR,
    sz_stop_no IN VARCHAR,
    sz_rec_type IN VARCHAR,
    sz_invoice_num IN VARCHAR,
    sz_prod_id IN VARCHAR,
    sz_cust_pref_vendor IN VARCHAR,
    sz_return_reason_cd IN VARCHAR,
    sz_returned_qty IN VARCHAR,
    sz_returned_split_cd IN VARCHAR,
    sz_catchweight IN VARCHAR,
    sz_disposition IN VARCHAR,
    sz_returned_prod_id IN VARCHAR,
    sz_erm_line_id IN VARCHAR,
    sz_shipped_qty IN VARCHAR,
    sz_shipped_split_cd IN VARCHAR,
    sz_cust_id IN VARCHAR,
    sz_temperature IN VARCHAR
)

IS  
    i_erm_line_id NUMBER;
    n_stop_no NUMBER;
    sz_delivery_doc_num MANIFEST_STOPS.invoice_no%TYPE := sz_invoice_num;
    i_dci_rtn_exists NUMBER;
    l_ret_count NUMBER;
    v_stc_trans_count NUMBER;
    v_rtn_count NUMBER;
    v_cmp_count NUMBER := 0; -- If count is > 0 then Tripmaster is completed. Do not update/insert
    v_pod_flag manifest_stops.pod_flag%type;
    status manifests.manifest_status%type;

    v_pod_rtn_ind returns.pod_rtn_ind%TYPE := NULL;
    v_rtn_sent_ind returns.rtn_sent_ind%TYPE := 'N';
    v_org_rsn_cd returns.org_rtn_reason_cd%TYPE := NULL;
    v_org_catchweight returns.org_catchweight%TYPE := NULL;
    v_org_qty returns.org_rtn_qty%TYPE := NULL;

BEGIN
    -- 3/2/2007 - As per E. Freeman, stop number should be integer portion
    n_stop_no := floor( to_number( sz_stop_no  ) );
    i_dci_rtn_exists := 0;

    -- Anything other than pickup, get the invoice number from the manifest stop
    if( sz_rec_type != 'P' ) THEN
        BEGIN
        SELECT DISTINCT OBLIGATION_NO INTO sz_delivery_doc_num
        FROM MANIFEST_STOPS
        WHERE MANIFEST_NO = sz_manifest_no AND INVOICE_NO = sz_invoice_num AND ROWNUM = 1;

        EXCEPTION WHEN NO_DATA_FOUND THEN sz_delivery_doc_num := sz_invoice_num;
        END;
    END IF;

    -- CRQ46986 Returns were entered by CRT - Driver check-in clerk
    --			So reject STS upload from Driver which is of low precedence

    BEGIN 
        -- CRQ48953 - STS returns issue due to pick up order 
        --
        select count(*) into v_stc_trans_count from trans 
            where rec_id= sz_manifest_no
            and route_no=sz_route_no
            and stop_no=sz_stop_no
            and trans_type='STC';

        select count(*) into v_rtn_count 
            from returns
            where manifest_no = to_number( sz_manifest_no ) 
            and stop_no = n_stop_no 
            and rec_type = sz_rec_type 
            and obligation_no = sz_delivery_doc_num 
            and prod_id = sz_prod_id 
            and cust_pref_vendor = sz_cust_pref_vendor 
            and return_reason_cd = sz_return_reason_cd 
            and shipped_split_cd = sz_shipped_split_cd 
            and (returned_split_cd is null or returned_split_cd = sz_returned_split_cd);


        SELECT distinct NVL(pod_flag, 'N') INTO v_pod_flag
            FROM manifest_stops
            WHERE manifest_no= to_number ( sz_manifest_no )
            and stop_no=floor( to_number(sz_stop_no))
            and obligation_no=sz_delivery_doc_num;

        SELECT manifest_status INTO status 
            FROM manifests 
            WHERE manifest_no=to_number ( sz_manifest_no );

        --
        -- If there are any CMP status returns for the manifest, then tripmaster is complete.
        --
        SELECT count(*) 
        INTO v_cmp_count
        FROM returns r
        WHERE r.manifest_no = TO_NUMBER(sz_manifest_no)
        AND r.status = 'CMP';

        -- Only when manifest status is OPN and tripmaster has not been done yet.
        IF status='OPN' AND v_cmp_count = 0 THEN    
            IF (v_pod_flag='N') or (v_stc_trans_count=0 and v_pod_flag='Y') or (v_pod_flag is NULL) or (v_stc_trans_count > 0 and v_pod_flag = 'Y') THEN
                SELECT COUNT(*) INTO i_dci_rtn_exists
                FROM RETURNS 
                WHERE	MANIFEST_NO = to_number( sz_manifest_no )
                AND   NVL(ADD_SOURCE, 'STS') NOT IN ('STS', 'MFR');

                IF(i_dci_rtn_exists = 0) THEN

                -- No records in RETURNS by DCI clerk from CRT continue
                -- Attempt to update an existing record           

                    IF v_pod_flag <> 'Y' THEN
                        v_org_rsn_cd := NULL;
                        v_org_qty := NULL;
                        v_org_catchweight := NULL;

                    ELSIF v_pod_flag = 'Y' THEN
                        v_org_rsn_cd := sz_return_reason_cd;
                        v_org_qty := to_number(sz_returned_qty);
                        v_org_catchweight := to_number(sz_catchweight);

                        IF v_stc_trans_count > 0 THEN
                            IF v_rtn_count > 0 THEN -- If POD, a STC trans exists, and a return record exists, then set indicator to U
                                v_pod_rtn_ind := 'U';
                            ELSE
                                v_pod_rtn_ind := 'A';
                            END IF; 

                        ELSIF v_stc_trans_count = 0 THEN
                            v_pod_rtn_ind := 'A'; -- This will get updated later to 'S' when the RTN transaction is created 
                        ELSE
                            v_pod_rtn_ind := NULL;
                        END IF;

                    END IF;
                    
                    --
                    -- Update before trying to insert since Pick ups (rec_type = 'P' and add_source = 'MFR') are inserted into returns
                    -- when SWMS receives the manifest.
                    -- If the customer is NOT on POD, then do not set the POD_RTN_IND,
                    -- else, if the POD_RTN_IND is an 'A', then it should stay as 'A'
                    -- else, check if the new returned_qty is different from the current returned_qty, change the  POD_RTN_IND to 'U'.
                    --
                    UPDATE RETURNS 
                    SET POD_RTN_IND = 
                            DECODE(v_pod_flag,  'N', NULL,
                                                DECODE(POD_RTN_IND, 'A', POD_RTN_IND,
												                    DECODE(RETURNED_QTY, sz_returned_qty, POD_RTN_IND, 'A'))), -- 3/25/20
                                                                --    DECODE(RETURNED_QTY, sz_returned_qty, POD_RTN_IND, 'U'))),
                        RETURNED_QTY = to_number(sz_returned_qty),
                        RETURNED_SPLIT_CD =  sz_returned_split_cd,
                        CATCHWEIGHT = nvl(CATCHWEIGHT,0) + to_number(sz_catchweight),
                        UPD_SOURCE='STS'
                    WHERE  MANIFEST_NO = to_number( sz_manifest_no ) AND 
                            STOP_NO = n_stop_no AND 
                            REC_TYPE = sz_rec_type AND 
                            OBLIGATION_NO = sz_delivery_doc_num AND 
                            PROD_ID = sz_prod_id AND 
                            CUST_PREF_VENDOR = sz_cust_pref_vendor AND 
                            RETURN_REASON_CD = sz_return_reason_cd AND 
                            SHIPPED_SPLIT_CD = sz_shipped_split_cd AND 
                            (RETURNED_SPLIT_CD  IS NULL OR RETURNED_SPLIT_CD = sz_returned_split_cd);
                            
                    IF SQL%NOTFOUND THEN
                    -- The update failed, so the record does not already exist, therefore insert it.
                    BEGIN

                        -- Find the ermline id
                        IF ( sz_erm_line_id IS NULL ) THEN
                        BEGIN
                            SELECT nvl( MAX(ERM_LINE_ID), 0 )  + 1 INTO i_erm_line_id 
                                FROM RETURNS 
                                WHERE MANIFEST_NO = to_number( sz_manifest_no );
                        END;
                        ELSE
                            i_erm_line_id := to_number( sz_erm_line_id );
                        END IF;

                    --  raise_application_error( -20000, 'sz_returned_split_cd = >' || sz_returned_split_cd || '<' );
                                -- Added for CRQ34059 to insert RTN for same prod_id with different reason codes
                        SELECT COUNT(*) INTO l_ret_count
                        from returns 
                        where manifest_no=sz_manifest_no
                            and route_no=sz_route_no
                            and stop_no=n_stop_no
                            and prod_id=sz_prod_id
                            and RETURNED_QTY=sz_returned_qty
                            and OBLIGATION_NO=sz_delivery_doc_num
                            and return_reason_cd=sz_return_reason_cd;
                            
                        IF (l_ret_count=0) THEN     
                            
                            INSERT INTO RETURNS ( MANIFEST_NO,
                                            ROUTE_NO,
                                            STOP_NO,
                                            REC_TYPE,
                                            OBLIGATION_NO,
                                            PROD_ID,
                                            CUST_PREF_VENDOR,
                                            RETURN_REASON_CD,
                                            RETURNED_QTY,
                                            RETURNED_SPLIT_CD,
                                            CATCHWEIGHT,
                                            DISPOSITION,
                                            RETURNED_PROD_ID,
                                            ERM_LINE_ID,
                                            SHIPPED_QTY,
                                            SHIPPED_SPLIT_CD,
                                            CUST_ID,
                                            TEMPERATURE,
                                            ADD_SOURCE,
                                            POD_RTN_IND,
                                            RTN_SENT_IND,
                                            ORG_RTN_REASON_CD,
                                            ORG_RTN_QTY,
                                            ORG_CATCHWEIGHT)
                                VALUES ( to_number(sz_manifest_no),
                                            sz_route_no,
                                            n_stop_no,
                                            decode(sz_return_reason_cd,'T30','O','W45','O',sz_rec_type),
                                            sz_delivery_doc_num,
                                            sz_prod_id,
                                            sz_cust_pref_vendor,
                                            sz_return_reason_cd,
                                            to_number(sz_returned_qty),
                                            sz_returned_split_cd,
                                            to_number( sz_catchweight),
                                            sz_disposition,
                                            sz_returned_prod_id,
                                            i_erm_line_id,
                                            to_number( sz_shipped_qty),
                                            sz_shipped_split_cd,
                                            sz_cust_id,
                                            to_number( sz_temperature ),
                                            'STS',
                                            DECODE(v_pod_flag, 'Y', 'A', NULL),
                                            'N',
                                            v_org_rsn_cd,
                                            v_org_qty,
                                            v_org_catchweight);
                                    COMMIT;
                        ELSE
                            NULL;
                        END IF;
                                
                            END;
                        END IF;
                    ELSE 
                        pl_log.ins_msg( 'I', 'sts_return_proc','Returns for Manifest# ' || sz_manifest_no || ' Obligation#' || sz_delivery_doc_num || ' Stop# ' || n_stop_no || ' Prod_id# '|| sz_prod_id || ' has been processed already.', NULL,  NULL, 'O', 'STS_RETURN' );         
                END IF;

            ELSE
                NULL;
            END IF;

        ELSE
            IF v_cmp_count > 0 THEN
                pl_log.ins_msg('I', 'sts_return_proc', 'Tripmaster has been done for this manifest. Not updating/inserting returns', NULL,  NULL, 'O', 'STS_RETURN');
            ELSE
                pl_log.ins_msg( 'I', 'sts_return_proc','Returns for Manifest# '|| sz_manifest_no || ' Obligation#' || sz_delivery_doc_num || ' Stop# ' || n_stop_no || ' Prod_id# '|| sz_prod_id ||'Cannot be processed.Manifest is already Closed', NULL,  NULL, 'O', 'STS_RETURN' );         
            END IF;
        END IF; -- END IF status='OPN' AND v_cmp_count = 0 THEN    
    END;          
END;
/

create or replace public synonym STS_RETURN for SWMS.STS_RETURN;

