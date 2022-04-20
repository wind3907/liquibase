CREATE OR REPLACE PACKAGE SWMS.pl_xml_matrix_out
IS 
/*===========================================================================================================
-- Package
-- pl_xml_matrix_out
--
-- Description
--   This package is called by SWMS.
--   This package is used to pack the data that is going out to Symbotic.
--
-- Modification History
--
-- Date                User                  Version            Defect  Comment
-- 08/4/14        Sunil Ontipalli             1.0              Initial Creation
--
-- 10/22/14       Sunil Ontipalli             1.1              Added a cursor to run without SYS_MSG_ID and will
--                                                             process all the queue messages one after other.
--
-- 12/03/14       Sunil Ontipalli             1.2              Added the retry mechanism for system failures,
--                                                             also waits depending upon the no of retry.
--
-- 01/22/15       Sunil Ontipalli             1.3              Modified the XML structure for SYS04, SYS05, SYS14
--                                                             and also fixed bug, when failed, will continue processing
--                                                             other messages.
--
-- 01/29/15       Sunil Ontipalli             1.4              Adding the new functionality to maintain the interfaces, and also to query
--                                                             the IP address from dba_network_acls table which was configured
--                                                             to communicate to Symbotic.
--
-- 08/22/16        Adi Al Bataineh            1.5              sys06_spur_case_removal: Put SYS06 on hold until the case is diverted 
--                                                             to spurs
============================================================================================================*/

PROCEDURE check_webservice(i_interface_ref_doc  IN VARCHAR2,
                           o_active_flag        OUT VARCHAR2,
                           o_url_port           OUT VARCHAR2,
                           o_reason             OUT VARCHAR2);

PROCEDURE sys03_mx_inv_induct(i_sys_msg_id    IN   NUMBER DEFAULT NULL);

PROCEDURE sys01_item_master(i_sys_msg_id      IN   NUMBER DEFAULT NULL);

PROCEDURE sys04_add_order(i_sys_msg_id   IN   NUMBER DEFAULT NULL);

PROCEDURE sys05_internal_order(i_sys_msg_id   IN   NUMBER DEFAULT NULL);

PROCEDURE sys06_spur_case_removal(i_sys_msg_id   IN   NUMBER DEFAULT NULL);

PROCEDURE sys07_batch_status(i_sys_msg_id   IN   NUMBER DEFAULT NULL);

PROCEDURE sys08_pallet_update(i_sys_msg_id    IN   NUMBER DEFAULT NULL);

PROCEDURE sys09_bulk_request(i_sys_msg_id    IN   NUMBER DEFAULT NULL);

PROCEDURE sys10_bulk_notification(i_sys_msg_id    IN   NUMBER DEFAULT NULL);

PROCEDURE sys11_update_batch_priority(i_sys_msg_id    IN   NUMBER DEFAULT NULL);

PROCEDURE sys12_cancel_order_batch(i_sys_msg_id    IN   NUMBER DEFAULT NULL);

PROCEDURE sys13_cancel_order_detail(i_sys_msg_id    IN   NUMBER DEFAULT NULL);

PROCEDURE sys14_add_order_detail(i_sys_msg_id    IN   NUMBER DEFAULT NULL);

PROCEDURE sys15_wave_status(i_sys_msg_id   IN   NUMBER DEFAULT NULL);

PROCEDURE generate_pm_bulk_file;

PROCEDURE initiate_webservice(i_sys_msg_id    IN   NUMBER,
                              i_ref_doc       IN   VARCHAR2);

END pl_xml_matrix_out;
/


CREATE OR REPLACE 
PACKAGE BODY      pl_xml_matrix_out
IS
  /*===========================================================================================================
  -- Package Body
  -- pl_xml_matrix_out
  --
  -- Description
  --   This package is called by SWMS.
  --   This package is used to pack the data that is going out to symbotic.
  --
  -- Modification History
  --
  -- Date                User                  Version            Defect  Comment
  -- 08/4/14        Sunil Ontipalli             1.0              Initial Creation
  --
  -- 10/22/14       Sunil Ontipalli             1.1              Added a cursor to run without SYS_MSG_ID and will
  --                                                             process all the queue messages one after other.
  --
  -- 12/03/14       Sunil Ontipalli             1.2              Added the retry mechanism for system failures,
  --                                                             also waits depending upon the no of retry.
  --
  -- 01/22/15       Sunil Ontipalli             1.3              Modified the XML structure for SYS04, SYS05, SYS14
  --                                                             and also fixed bug, when failed, will continue processing
  --                                                             other messages.
  --
  -- 01/29/15       Sunil Ontipalli             1.4              Adding the new functinality to maintain the interfaces, and also to query
  --                                                             the ip address from dba_network_acls table which was configured
  --                                                             to communicate to Symbotic.
  ============================================================================================================*/

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
  --   of the Symbotic System.
  --
  --
  -- Modification History
  --
  -- Date                User                  Version            Defect  Comment
  -- 01/29/15        Sunil Ontipalli             1.0              Initial Creation
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
----Checking Whether the Interfaces between Symbotic and Sysco are Active or not----

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

PROCEDURE sys03_mx_inv_induct(
    i_sys_msg_id IN NUMBER DEFAULT NULL)
  /*===========================================================================================================
  -- Procedure
  -- sys03_mx_inv_induct
  --
  -- Description
  --   This procedure is to send a particular sys_msg_id data to symbotic.
  --   This procedure is used to pack the SYS03 data that is going out to symbotic.
  --
  -- Modification History
  --
  -- Date                User                  Version            Defect  Comment
  -- 08/4/14        Sunil Ontipalli             1.0              Initial Creation
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

  CURSOR c_sys_msg_id
         IS
  SELECT DISTINCT(sys_msg_id)
    FROM matrix_out
   WHERE interface_ref_doc = 'SYS03'
     AND record_status     = 'N'
     AND (add_date   <  systimestamp - 1/(24*60) OR i_sys_msg_id IS NOT NULL)
     AND sys_msg_id = NVL(i_sys_msg_id, sys_msg_id);
  ------------------------------for testing-------------------------------------
  l_prod_id           VARCHAR2(10);
  l_licence_plate_no  VARCHAR2(18);
  l_po_no             VARCHAR2(20);
  l_cases_inducted    NUMBER;


BEGIN

  check_webservice(i_interface_ref_doc  => 'SYS03',
                   o_active_flag        => l_interface_flag,
                   o_url_port           => l_url,
                   o_reason             => l_reason);

   IF l_interface_flag = 'Y' THEN

     FOR i IN c_sys_msg_id

      LOOP
       EXIT WHEN c_sys_msg_id%NOTFOUND;

    -----------------------Initializing the local variables-------------------------
         l_sys_msg_id := i.sys_msg_id;
         l_timestamp  := TO_CHAR(SYSTIMESTAMP,'YYYY-MM-DD HH24:MI:SS');
    ---------------------------Getting the Record status----------------------------
        BEGIN
           SELECT DISTINCT(record_status)
             INTO l_record_status
             FROM matrix_out
            WHERE sys_msg_id = l_sys_msg_id;
        EXCEPTION
        WHEN OTHERS THEN
         l_error_msg  := 'Error: Getting the Record Status';
         l_error_code := SUBSTR(SQLERRM,1,100);
         RAISE web_exception;
        END;
    -----------Checking Whether the Status is 'N' and Locking the Record------------
        IF UPPER(l_record_status) = 'N' THEN
          BEGIN
           UPDATE matrix_out
              SET record_status = 'Q'
            WHERE sys_msg_id  = l_sys_msg_id
              AND record_status = 'N';
           COMMIT;
          EXCEPTION
          WHEN OTHERS THEN
           ROLLBACK;
           l_error_msg := 'Error: Updating the Record status to Q';
           l_error_code:= SUBSTR(SQLERRM,1,100);
          RAISE web_exception;
          END;
    -----------------------Generating the XML for Webservice------------------------
          BEGIN

            SELECT  XMLELEMENT("metadata",
                     XMLFOREST(l_sys_msg_id AS "MessageId",
                              l_timestamp  AS "RequestDateTime")
                              )
             INTO l_xml
             FROM dual;
          EXCEPTION
          WHEN OTHERS THEN
           l_error_msg := 'Error: Generating the XML 1';
           l_error_code:= SUBSTR(SQLERRM,1,100);
           RAISE web_exception;
          END;

          l_xml_build := l_xml.getstringval();
          l_xml := NULL;

          BEGIN
             SELECT XMLFOREST(nvl(mo.label_type,' ')         AS "labelType",
                              nvl(mo.trans_type,' ')         AS "inductionType",
                              nvl(mo.parent_pallet_id,' ')   AS "parentLpn")
               INTO l_xml
               FROM matrix_out mo
              WHERE sys_msg_id = l_sys_msg_id
                AND (rec_ind    = 'H' or rec_ind = 'S');
          EXCEPTION
          WHEN OTHERS THEN
           l_error_msg := 'Error: Generating the XML 2';
           l_error_code:= SUBSTR(SQLERRM,1,100);
           RAISE web_exception;
          END;

         l_xml_build := l_xml_build||l_xml.getstringval();

         l_xml  := NULL;

          BEGIN

                 SELECT XMLELEMENT("palletDetailList",
                         XMLAGG(XMLELEMENT("PalletDetail",
                                XMLFOREST(nvl(mo.case_qty,0)                                            AS "CaseQuantity",
                                          nvl(mo.inv_status,' ')                                        AS "HoldStatus",
                                          nvl(mo.prod_id,' ')                                           AS "ItemId",
                                          nvl(mo.pallet_id,' ')                                         AS "LicensePlateNumber",
                                          nvl(to_char(mo.expiration_date,'YYYY-MM-DD HH24:MI:SS'),' ')  AS "ProductDate",
                                          nvl(mo.erm_id,' ')                                            AS "PurchaseOrder"
                                         )
                                    )
                                    )
                                    )
               INTO l_xml
               FROM matrix_out mo
              WHERE sys_msg_id     = l_sys_msg_id
                AND rec_ind       != 'H';
          EXCEPTION
          WHEN OTHERS THEN
           l_error_msg := 'Error: Generating the XML 3';
           l_error_code:= SUBSTR(SQLERRM,1,100);
           RAISE web_exception;
          END;

          l_xml_build := '<AddPallet>'||l_xml_build||l_xml.getstringval()||'</AddPallet>';

          l_xml_build := replace(l_xml_build, '<','<sym:');
          l_xml_build := replace(l_xml_build, '<sym:/','</sym:');


    -----------------------for testing----------------------------------------------
         /*
        INSERT
         INTO test_table1
          VALUES (l_xml);
         COMMIT;
          */
        l_retry_count := 1;

          LOOP

            IF l_retry_count < 4 THEN

              BEGIN

    ---------------------Initilaizing the Webservice Parameters---------------------
              --l_url         := 'http://10.254.4.130:7800/CaseManager';
               l_namespace   := 'xmlns:sym="Symbotic" xmlns:arr="http://schemas.microsoft.com/2003/10/Serialization/Arrays"';
              --l_method      := 'tns:AddPalletInput';
               l_soap_action := 'Symbotic/ICaseManager/AddPallet';
              --l_result_name := 'ROWSET';
    --------------------------Initiating the Webservice Call------------------------
               l_request := soap_api.new_request(p_method         => l_method,
                                                 p_namespace      => l_namespace,
                                                 p_envelope_tag   => 'soapenv');
    -------------------------Passing the XML Parameter------------------------------
                soap_api.add_complex_parameter(p_request => l_request,
                                               p_xml     => l_xml_build);

                soap_api.debug_on();
    ------------------------------Getting the Response------------------------------
               l_response := soap_api.invoke(p_request => l_request,
                                             p_url     => l_url,
                                             p_action  => l_soap_action);
    -----------------------------Verifying the Response-----------------------------
               l_xml_build := l_response.doc.getstringval();

               l_count     := INSTR(l_xml_build,'<s:Fault>',1);

                IF l_count != 0 THEN
                  l_xml_build := SUBSTR (l_xml_build,INSTR(l_xml_build,'<s:Fault>')+9,INSTR(l_xml_build,'</s:Fault>')-INSTR(l_xml_build,'<s:Fault>')-9);
                  l_error_msg := SUBSTR(l_xml_build,1,2000);
                  l_error_code:= 'SEE ERROR MSG';
                 RAISE web_exception;
                END IF;

               EXIT;

              EXCEPTION
               WHEN web_exception THEN
                 RAISE web_exception;
               WHEN OTHERS THEN
                l_error_code:= SUBSTR(SQLERRM,1,100);
                dbms_lock.sleep(l_retry_count*10);
                l_retry_count := l_retry_count+1;
                l_error_msg   := 'Retry: '||(l_retry_count-1)||' as it failed to connect';
                UPDATE matrix_out
                   SET error_msg     = l_error_msg
                 WHERE sys_msg_id    = l_sys_msg_id;
              END;

            ELSE
             l_error_msg   := 'Failed All the Retry Attempts, see error code';
             RAISE web_exception;
            END IF;

          END LOOP;
    -------------------Updating the Record Status in Matrix_out---------------------

          BEGIN
           UPDATE matrix_out
              SET record_status = 'S'
            WHERE sys_msg_id = l_sys_msg_id;
           COMMIT;
          EXCEPTION
          WHEN OTHERS THEN
           ROLLBACK;
           l_error_msg := 'Error: Updating to Success';
           l_error_code:= SUBSTR(SQLERRM,1,100);
           RAISE web_exception;
          END;

        END IF;

      END LOOP;

   END IF;
-----------------------for testing----------------------------------------------
/*l_number := MX_XML_ID_SEQ.NEXTVAL;

BEGIN

SELECT prod_id, pallet_id, erm_id, case_qty
           INTO l_prod_id , l_licence_plate_no, l_po_no, l_cases_inducted
           FROM matrix_out mo
          WHERE sys_msg_id = l_sys_msg_id;
 INSERT
    INTO matrix_in
      (
        mx_msg_id , msg_time , interface_ref_doc , rec_ind ,
        prod_id , pallet_id , erm_id , stored_time , qty_inducted , qty_stored ,
        qty_damaged , qty_out_of_tolerance , qty_wrong_item , qty_short , qty_over
      )
      VALUES
      (
        l_number ,SYSTIMESTAMP ,'SYM03' ,'S' ,
        l_prod_id, l_licence_plate_no, l_po_no, SYSTIMESTAMP, l_cases_inducted,
      -- l_cases_inducted-2, 1, 1, 0, 0, 0);
        l_cases_inducted, 0, 0, 0, 0, 0);
COMMIT;
 EXCEPTION
    WHEN OTHERS THEN
      l_error_msg := SQLERRM;
      RAISE web_exception;
END;

pl_mx_stg_to_swms.sym03_inv_update(l_number); */

EXCEPTION
WHEN web_exception THEN
  UPDATE matrix_out
     SET record_status = 'F',
         error_msg     = l_error_msg,
         error_code    = l_error_code
   WHERE sys_msg_id    = l_sys_msg_id;
  COMMIT;
WHEN OTHERS THEN
 l_error_code := SUBSTR(SQLERRM,1,100);
  UPDATE matrix_out
     SET record_status = 'F',
         error_msg     = 'Unknown Error: See Error_code',
         error_code    = l_error_code
   WHERE sys_msg_id    = l_sys_msg_id;
  COMMIT;
END sys03_mx_inv_induct;

PROCEDURE sys01_item_master(
    i_sys_msg_id IN NUMBER DEFAULT NULL)
  /*===========================================================================================================
  -- Procedure
  -- sys01_item_master
  --
  -- Description
  --   This procedure is to send a particular sys_msg_id data to symbotic.
  --   This procedure is used to pack the SYS01 data that is going out to symbotic.
  --
  -- Modification History
  --
  -- Date                User                  Version            Defect  Comment
  -- 08/27/14        Sunil Ontipalli             1.0              Initial Creation
  ============================================================================================================*/
IS
  ------------------------------soap_api parameters-----------------------------
  l_request       soap_api.t_request;
  l_response      soap_api.t_response;
  --l_return        VARCHAR2(32767);
  l_url           VARCHAR2(100);
  l_namespace     VARCHAR2(1000);
  l_method        VARCHAR2(100);
  l_soap_action   VARCHAR2(100);
  --l_result_name   VARCHAR2(32767);
  --------------------------------Local Variables-------------------------------
  l_xml               XMLTYPE;
  l_xml_build         CLOB;
  l_sys_msg_id        NUMBER(10):= NULL;
  l_timestamp         VARCHAR2(100);
  l_record_status     VARCHAR2(1);
  web_exception       EXCEPTION;
  l_error_msg         VARCHAR2(2000);
  l_error_code        VARCHAR2(100);
  l_count             NUMBER;
  l_retry_count       NUMBER;
  l_interface_flag    VARCHAR2(1);
  l_reason            VARCHAR2(100);
  CURSOR c_sys_msg_id
         IS
  SELECT DISTINCT(sys_msg_id)
    FROM matrix_pm_out
   WHERE interface_ref_doc = 'SYS01'
     AND record_status     = 'N'
     AND (add_date   <  systimestamp - 1/(24*60) OR i_sys_msg_id IS NOT NULL)
     AND sys_msg_id = NVL(i_sys_msg_id, sys_msg_id);

BEGIN

   check_webservice(i_interface_ref_doc  => 'SYS01',
                    o_active_flag        => l_interface_flag,
                    o_url_port           => l_url,
                    o_reason             => l_reason);

   IF l_interface_flag = 'Y' THEN

     FOR i IN c_sys_msg_id
       LOOP
         EXIT WHEN c_sys_msg_id%NOTFOUND;
    -----------------------Initializing the local variables-------------------------
         l_sys_msg_id := i.sys_msg_id;
         l_timestamp  := TO_CHAR(SYSTIMESTAMP,'YYYY-MM-DD HH24:MI:SS');
    ---------------------------Getting the Record status----------------------------
          BEGIN
           SELECT DISTINCT(record_status)
             INTO l_record_status
             FROM matrix_pm_out
            WHERE sys_msg_id = l_sys_msg_id;
          EXCEPTION
           WHEN OTHERS THEN
            l_error_msg := 'Error: Getting the Record Status';
            RAISE web_exception;
          END;
    -----------Checking Whether the Status is 'N' and Locking the Record------------
         IF UPPER(l_record_status) = 'N' THEN

           BEGIN
            UPDATE matrix_pm_out
               SET record_status = 'Q'
             WHERE sys_msg_id    = l_sys_msg_id
               AND record_status = 'N';
              COMMIT;
           EXCEPTION
            WHEN OTHERS THEN
             l_error_msg := 'Error: Updating the Record status to Q';
             l_error_code:= SUBSTR(SQLERRM,1,100);
             RAISE web_exception;
           END;
    -----------------------Generating the XML for Webservice------------------------
           BEGIN

            SELECT  XMLELEMENT("metadata",
                     XMLFOREST(l_sys_msg_id AS "MessageId",
                               l_timestamp  AS "RequestDateTime")
                               )
             INTO l_xml
             FROM dual;
           EXCEPTION
            WHEN OTHERS THEN
             l_error_msg := 'Error: Generating the XML 1';
             l_error_code:= SUBSTR(SQLERRM,1,100);
             RAISE web_exception;
           END;

          l_xml_build := l_xml.getstringval();
          l_xml       := NULL;

           BEGIN
            SELECT XMLFOREST (nvl(mpo.func_code,' ')                             AS "funcCode",
                              nvl(mpo.prod_id,' ')                               AS "itemId",
                              nvl(mpo.description,' ')                           AS "itemDescription",
                              nvl(mpo.warehouse_area,' ')                        AS "warehouseArea",
                              nvl(mpo.pack,' ')                                  AS "pack",
                              nvl(mpo.prod_size,' ')                             AS "size",
                              nvl(mpo.prod_size_unit,' ')                        AS "prodSizeUnit",
                              nvl(mpo.slotting_flag,'MS_PRIMARY')                AS "slottingType",
                              nvl(mpo.case_length,0)                             AS "cartonLength",
                              nvl(mpo.case_width,0)                              AS "cartonWidth",
                              nvl(mpo.case_height,0)                             AS "cartonHeight",
                              nvl(mpo.weight,0)                                  AS "cartonWeight",
                              DECODE(mpo.upc_present_flag, 'Y', 'true', 'false') AS "isUPCPresent"
                              )
                        INTO l_xml
                        FROM matrix_pm_out mpo
                       WHERE sys_msg_id = l_sys_msg_id
                         AND rec_ind='H';
           EXCEPTION
            WHEN OTHERS THEN
             l_error_msg := 'Error: Generating the XML 2';
             l_error_code:= SUBSTR(SQLERRM,1,100);
             RAISE web_exception;
           END;

           l_xml_build := l_xml_build||l_xml.getstringval();

           l_xml  := NULL;

           BEGIN

              SELECT XMLELEMENT("upcList",
                         XMLAGG(XMLELEMENT("string", nvl(mpo.upc,' ')
                                          )
                                    )
                                    )
               INTO l_xml
               FROM matrix_pm_out mpo
              WHERE sys_msg_id = l_sys_msg_id
                AND rec_ind    = 'D';
           EXCEPTION
            WHEN OTHERS THEN
             l_error_msg := 'Error: Generating the XML 3';
             l_error_code:= SUBSTR(SQLERRM,1,100);
             RAISE web_exception;
           END;

           l_xml_build := l_xml_build||l_xml.getstringval();

           l_xml  := NULL;

           BEGIN

            SELECT XMLFOREST (DECODE(mpo.problem_case_upc_flag, 'Y', 'true', 'false')     AS "isProblemUPC",
                              DECODE(mpo.hazardous_type,'NOT HAZARDOUS', 'NOT_HAZARDOUS',
                                                        'EXPANDED FORM', 'EXPANDED_FORM',
                                                         nvl(mpo.hazardous_type,' '))     AS "hazardousType",
                              nvl(mpo.food_type,' ')                                      AS "foodType",
                              DECODE(mpo.mx_sel_eligibility_flag, 'Y', 'true', 'false')   AS "isMSE",
                             -- DECODE(mpo.customer_rot_rule_flag, 'Y', 'true', 'false')    AS "isFEFO",
                              nvl(mpo.expiration_window,0)                                AS "rotationWindow",
                              DECODE(mpo.sku_tip_flag, 'Y', 'true', 'false')              AS "tipRequired"
                             )
                       INTO l_xml
                       FROM matrix_pm_out mpo
                      WHERE sys_msg_id = l_sys_msg_id
                        AND rec_ind='H';
           EXCEPTION
            WHEN OTHERS THEN
             l_error_msg := 'Error: Generating the XML 4';
             l_error_code:= SUBSTR(SQLERRM,1,100);
             RAISE web_exception;
           END;

          l_xml_build := '<ItemMaster>'||l_xml_build||l_xml.getstringval()||'</ItemMaster>';

          l_xml_build := replace(l_xml_build, '<','<sym:');
          l_xml_build := replace(l_xml_build, '<sym:/','</sym:');
          l_xml_build := replace(l_xml_build, '<sym:string','<arr:string');
          l_xml_build := replace(l_xml_build, '</sym:string', '</arr:string' );

          --l_xml  := XMLTYPE(l_xml_build);

         /* INSERT
            INTO test_table1
           VALUES (l_xml);
           COMMIT;*/

          l_retry_count := 1;

           LOOP

             IF l_retry_count < 4 THEN

               BEGIN
    ---------------------Initilaizing the Webservice Parameters---------------------
                --l_url         := 'http://10.254.4.130:7800/CaseManager';
                l_namespace   := 'xmlns:sym="Symbotic" xmlns:arr="http://schemas.microsoft.com/2003/10/Serialization/Arrays"';
                --l_method      := 'tns:ItemMasterInput';
                l_soap_action := 'Symbotic/ICaseManager/ItemMaster';
                --l_result_name := 'ROWSET';
    --------------------------Initiating the Webservice Call------------------------
                l_request := soap_api.new_request(p_method         => l_method,
                                                  p_namespace      => l_namespace,
                                                  p_envelope_tag   => 'soapenv');
    -------------------------Passing the XML Parameter------------------------------
                soap_api.add_complex_parameter(p_request => l_request,
                                               p_xml     => l_xml_build);

                soap_api.debug_on();
    ------------------------------Getting the Response------------------------------
                l_response := soap_api.invoke(p_request => l_request,
                                              p_url     => l_url,
                                              p_action  => l_soap_action);

    -----------------------------Verifying the Response-----------------------------
                l_xml_build := l_response.doc.getstringval();

                l_count     := INSTR(l_xml_build,'<s:Fault>',1);

                 IF l_count != 0 THEN
                   l_xml_build := SUBSTR (l_xml_build,INSTR(l_xml_build,'<s:Fault>')+9,INSTR(l_xml_build,'</s:Fault>')-INSTR(l_xml_build,'<s:Fault>')-9);
                   l_error_msg := SUBSTR(l_xml_build,1,2000);
                   l_error_code:= 'SEE ERROR MSG';
                   RAISE web_exception;
                 END IF;

               EXIT;

               EXCEPTION
                WHEN web_exception THEN
                 RAISE web_exception;
                WHEN OTHERS THEN
                 l_error_code:= SUBSTR(SQLERRM,1,100);
                 dbms_lock.sleep(l_retry_count*10);
                 l_retry_count := l_retry_count+1;
                 l_error_msg   := 'Retry: '||(l_retry_count-1)||' as it failed to connect';
                UPDATE matrix_out
                   SET error_msg     = l_error_msg
                 WHERE sys_msg_id    = l_sys_msg_id;
               END;

             ELSE
              l_error_msg   := 'Failed All the Retry Attempts, see error code';
              RAISE web_exception;
             END IF;

           END LOOP;
    -------------------Updating the Record Status in Matrix_out---------------------
           BEGIN
              UPDATE matrix_pm_out
                 SET record_status = 'S'
               WHERE sys_msg_id = l_sys_msg_id;
              COMMIT;
           EXCEPTION
            WHEN OTHERS THEN
             l_error_msg := 'Error: Updating to Success';
             l_error_code:= SUBSTR(SQLERRM,1,100);
             RAISE web_exception;
           END;

         END IF;

       END LOOP;
   END IF;
EXCEPTION
WHEN web_exception THEN
  UPDATE matrix_pm_out
     SET record_status = 'F',
         error_msg     = l_error_msg,
         error_code    = l_error_code
   WHERE sys_msg_id    = l_sys_msg_id;
  -- insert into log_test values(1,l_error_msg);
  COMMIT;
WHEN OTHERS THEN
 l_error_code := SUBSTR(SQLERRM,1,100);
  UPDATE matrix_pm_out
     SET record_status = 'F',
         error_msg     = 'Unknown Error: See Error_code',
         error_code    = l_error_code
   WHERE sys_msg_id    = l_sys_msg_id;
  -- insert into log_test values(1,l_error_msg);
  COMMIT;
END sys01_item_master;

PROCEDURE sys04_add_order(
    i_sys_msg_id IN NUMBER DEFAULT NULL)
  /*===========================================================================================================
  -- Procedure
  -- sys04_add_order
  --
  -- Description
  --   This procedure is to send a particular sys_msg_id data to symbotic.
  --   This procedure is used to pack the SYS04 data that is going out to symbotic.
  --
  -- Modification History
  --
  -- Date                User                  Version            Defect  Comment
  -- 10/09/14        Sunil Ontipalli             1.0              Initial Creation
  ============================================================================================================*/
IS
  ------------------------------soap_api parameters-----------------------------
  l_request           soap_api.t_request;
  l_response          soap_api.t_response;
  --l_return            VARCHAR2(32767);
  l_url               VARCHAR2(100);
  l_namespace         VARCHAR2(1000);
  l_method            VARCHAR2(100);
  l_soap_action       VARCHAR2(100);
  --l_result_name       VARCHAR2(32767);
  --------------------------------Local Variables-------------------------------
  l_xml               XMLTYPE;
  l_xml_build         CLOB;
  l_xml_build1        CLOB;
  l_xml_build2        CLOB;
  l_xml_build3        CLOB;
  l_xml_build4        CLOB;
  l_xml_build5        CLOB;
  l_xml_build6        CLOB;
  l_sys_msg_id        NUMBER(10):= NULL;
  l_timestamp         VARCHAR2(100);
  l_record_status     VARCHAR2(1);
  web_exception       EXCEPTION;
  l_error_msg         VARCHAR2(2000);
  l_error_code        VARCHAR2(100);
  l_count             NUMBER;
  l_retry_count       NUMBER;
  l_interface_flag    VARCHAR2(1);
  l_reason            VARCHAR2(100);
  l_min_wave_number   NUMBER;
  l_msg_wave_number   NUMBER;  
   CURSOR c_sys_msg_id
         IS
  SELECT DISTINCT(sys_msg_id)
    FROM matrix_out
   WHERE interface_ref_doc = 'SYS04'
     AND record_status     = 'N'
     AND (add_date   <  systimestamp - 1/(24*60) OR i_sys_msg_id IS NOT NULL)
     AND sys_msg_id = NVL(i_sys_msg_id, sys_msg_id);

BEGIN

   check_webservice(i_interface_ref_doc  => 'SYS04',
                    o_active_flag        => l_interface_flag,
                    o_url_port           => l_url,
                    o_reason             => l_reason);

   IF l_interface_flag = 'Y' THEN 
    
      
     FOR i IN c_sys_msg_id
      LOOP
       EXIT WHEN c_sys_msg_id%NOTFOUND;
    -----------------------Initializing the local variables-------------------------
       l_sys_msg_id := i.sys_msg_id;
       l_timestamp  := TO_CHAR(SYSTIMESTAMP,'YYYY-MM-DD HH24:MI:SS');
    ---------------------------Getting the Record status----------------------------
         BEGIN
           SELECT DISTINCT(record_status)
             INTO l_record_status
             FROM matrix_out
            WHERE sys_msg_id = l_sys_msg_id;
         EXCEPTION
          WHEN OTHERS THEN
          l_error_msg := 'Error: Getting the Record Status';
          RAISE web_exception;
         END;
    -----------Checking Whether the Status is 'N' and Locking the Record------------
         IF UPPER(l_record_status) = 'N' THEN

           BEGIN
            UPDATE matrix_out
               SET record_status = 'Q'
             WHERE sys_msg_id  = l_sys_msg_id
               AND record_status = 'N';
            COMMIT;
           EXCEPTION
            WHEN OTHERS THEN
             l_error_msg := 'Error: Updating the Record status to Q';
             l_error_code:= SUBSTR(SQLERRM,1,100);
             RAISE web_exception;
           END;
           
            pl_text_log.ins_msg('INFO', 'pl_xml_matrix_out.SYS04',
                                         'Starting 1 message ID'||l_sys_msg_id,
                                          NULL, NULL);
           
              IF l_sys_msg_id IS NOT NULL THEN
        
                   BEGIN
        
                     LOOP
    
                         SELECT wave_number INTO l_min_wave_number FROM
                               (SELECT wave_number FROM matrix_out WHERE record_status IN ('N', 'Q') 
                                                   AND interface_ref_doc = 'SYS04' ORDER BY sequence_number) WHERE ROWNUM = 1;
    
                         SELECT wave_number 
                           INTO l_msg_wave_number 
                           FROM matrix_out 
                          WHERE rec_ind = 'H' AND sys_msg_id =  l_sys_msg_id;
                
                         IF l_min_wave_number = l_msg_wave_number THEN
                          EXIT;
                         END IF;
    
                     END LOOP;
         
                  EXCEPTION
                   WHEN OTHERS THEN
                    pl_text_log.ins_msg('W', 'pl_xml_matrix_out.SYS04',
                                        'SYM04: Printing Msg Id: '||l_sys_msg_id,
                                         SQLCODE, SQLERRM);
        
                  END;
        
                    pl_text_log.ins_msg('INFO', 'pl_xml_matrix_out.SYS04',
                                         'Starting SYS04 message process for message ID'||l_sys_msg_id||' Wavenumber: '||l_msg_wave_number,
                                          NULL, NULL);
        
                 END IF;
           
           
    -----------------------Generating the XML for Webservice------------------------
           BEGIN

              SELECT  XMLELEMENT("metadata",
                       XMLFOREST(l_sys_msg_id AS "MessageId",
                                 l_timestamp  AS "RequestDateTime")
                                 )
               INTO l_xml
               FROM dual;
           EXCEPTION
            WHEN OTHERS THEN
             l_error_msg := 'Error: Generating the XML 1';
             l_error_code:= SUBSTR(SQLERRM,1,100);
             RAISE web_exception;
           END;

         l_xml_build := l_xml.getstringval();
         l_xml       := NULL;

           BEGIN
            SELECT XMLFOREST (nvl(mo.batch_id,0)                      AS "batchId",
                              nvl(mo.wave_number,0)                   AS "waveNumber",
                              nvl(mo.order_generation_time,' ')       AS "orderTime",
                              nvl(mo.priority,0)                      AS "priorityId",
                              nvl(mo.NON_SYM_HEAVY_CASE_COUNT,0)      AS "nonSymboticHeavyCaseCount",
                              nvl(mo.NON_SYM_light_CASE_COUNT,0)      AS "nonSymboticLightCaseCount"
                              )
                        INTO l_xml
                        FROM matrix_out mo
                       WHERE sys_msg_id = l_sys_msg_id
                         AND rec_ind    = 'H';
           EXCEPTION
            WHEN OTHERS THEN
             l_error_msg := 'Error: Generating the XML 2';
             l_error_code:= SUBSTR(SQLERRM,1,100);
             RAISE web_exception;
           END;

          l_xml_build := l_xml_build||l_xml.getstringval();

          l_xml  := NULL;

          FOR I IN (SELECT DISTINCT(order_id)
                      FROM matrix_out
                     WHERE sys_msg_id     = l_sys_msg_id
                       AND rec_ind       != 'H')
           LOOP

              BEGIN

                 SELECT XMLFOREST (nvl(mo.order_id,' ')                       AS "OrderId",
                                   nvl(mo.route,' ')                          AS "RouteNumber",
                                   nvl(mo.stop,0)                             AS "Stop",
                                   nvl(mo.order_type,' ')                     AS "OrderType",
                                   nvl(mo.order_sequence,0)                   AS "OrderSequence",
                                   nvl(mo.priority_identifier,0)              AS "PriorityIdentifier",
                                   nvl(mo.customer_rotation_rules,' ')        AS "SelectionMode"
                                  )
                  INTO l_xml
                  FROM matrix_out mo
                 WHERE order_id   = I.order_id
                   AND rownum     < 2;
              EXCEPTION
               WHEN OTHERS THEN
                l_error_msg := 'Error: Generating the XML 3';
                l_error_code:= SUBSTR(SQLERRM,1,100);
                RAISE web_exception;
              END;

            l_xml_build2  := l_xml.getstringval();

            l_xml  := NULL;

            FOR J IN (SELECT sequence_number
                        FROM matrix_out
                       WHERE sys_msg_id     = l_sys_msg_id
                         AND order_id       = I.order_id
                         AND rec_ind       != 'H')
              LOOP

                BEGIN

                  SELECT XMLFOREST(nvl(mo.prod_id,' ')           AS "ItemId",
                                   nvl(mo.case_qty,0)            AS "CaseQuantity",
                                   nvl(mo.float_id,0)            AS "FloatId",
                                   nvl(mo.pallet_id,' ')         AS "RequestedSourcePallet",
                                   nvl(mo.exact_pallet_imp,' ')  AS "ExactPalletImportance"
                                   )


                   INTO l_xml
                   FROM matrix_out mo
                  WHERE sequence_number = J.sequence_number;

                EXCEPTION
                 WHEN OTHERS THEN
                  l_error_msg := 'Error: Generating the XML 4';
                  l_error_code:= SUBSTR(SQLERRM,1,100);
                  RAISE web_exception;
                END;

                l_xml_build4  := l_xml.getstringval();

                l_xml  := NULL;

                 FOR K IN (SELECT rowid
                             FROM matrix_out_label
                            WHERE sequence_number = J.sequence_number)
                   LOOP

                      BEGIN

                        SELECT XMLELEMENT("string",nvl(barcode,' ')
                                       )
                          INTO l_xml
                          FROM matrix_out_label
                         WHERE rowid = K.rowid;

                      EXCEPTION
                       WHEN OTHERS THEN
                        l_error_msg := 'Error: Generating the XML 5';
                        l_error_code:= SUBSTR(SQLERRM,1,100);
                        RAISE web_exception;
                      END;

                      IF l_xml_build5 IS NULL THEN

                       l_xml_build5  := l_xml.getstringval();
                      ELSE
                       l_xml_build5  := l_xml_build5||l_xml.getstringval();
                      END IF;

                      l_xml  := NULL;
                   END LOOP;

                   l_xml_build5 := '<CaseBarcode>'||l_xml_build5||'</CaseBarcode>';

                   FOR K IN (SELECT rowid
                               FROM matrix_out_label
                              WHERE sequence_number = J.sequence_number)
                   LOOP

                       BEGIN

                         SELECT XMLELEMENT("string",nvl(encoded_print_stream,' ')
                                      )
                           INTO l_xml
                           FROM matrix_out_label
                          WHERE rowid = K.rowid;

                       EXCEPTION
                        WHEN OTHERS THEN
                         l_error_msg := 'Error: Generating the XML 6';
                         l_error_code:= SUBSTR(SQLERRM,1,100);
                         RAISE web_exception;
                       END;

                       IF l_xml_build6 IS NULL THEN

                        l_xml_build6  := l_xml.getstringval();
                       ELSE
                        l_xml_build6  := l_xml_build6||l_xml.getstringval();
                       END IF;

                       l_xml  := NULL;

                   END LOOP;

                   l_xml_build6 := '<CaseLabels>'||l_xml_build6||'</CaseLabels>';

                   l_xml_build4 :=  l_xml_build4||l_xml_build5||l_xml_build6;
                   l_xml_build5 :=  NULL;
                   l_xml_build6 :=  NULL;
                   l_xml_build4 := '<OrderSkuDetail>'||l_xml_build4||'</OrderSkuDetail>';

                   IF l_xml_build3 IS NULL THEN

                     l_xml_build3  := l_xml_build4;
                   ELSE
                     l_xml_build3  := l_xml_build3||l_xml_build4;
                   END IF;

                   l_xml_build4 :=  NULL;

              END LOOP;

              l_xml_build3  := '<OrderSkuDetails>'||l_xml_build3||'</OrderSkuDetails>';

              l_xml_build2  := l_xml_build2||l_xml_build3;

              l_xml_build3  := NULL;

              l_xml_build2  := '<OrderDetail>'||l_xml_build2||'</OrderDetail>';

              IF l_xml_build1 IS NULL THEN

                 l_xml_build1  := l_xml_build2;
              ELSE
                 l_xml_build1  := l_xml_build1||l_xml_build2;
              END IF;

              l_xml_build2  := NULL;

           END LOOP;

           l_xml_build1:= '<orderDetails>'||l_xml_build1||'</orderDetails>';
           l_xml_build :=  l_xml_build||l_xml_build1;
           l_xml_build := '<AddOrder>'||l_xml_build||'</AddOrder>';


           l_xml_build := replace(l_xml_build, '<','<sym:');
           l_xml_build := replace(l_xml_build, '<sym:/','</sym:');
           l_xml_build := replace(l_xml_build, '<sym:string','<arr:string');
           l_xml_build := replace(l_xml_build, '</sym:string', '</arr:string' );

           /*INSERT
             INTO test_table
            VALUES (l_xml_build);
            COMMIT;*/
            
            pl_text_log.ins_msg('INFO', 'pl_xml_matrix_out.SYS04',
                                                     'Completed XML message for the message ID'||l_sys_msg_id||' Wavenumber: '||l_msg_wave_number,
                        NULL, NULL);

           l_retry_count := 1;
           
           
           LOOP

             IF l_retry_count < 4 THEN

                BEGIN

    ---------------------Initilaizing the Webservice Parameters---------------------
                  --l_url         := 'http://10.254.4.130:7800/CaseManager';
                  l_namespace   := 'xmlns:sym="Symbotic" xmlns:arr="http://schemas.microsoft.com/2003/10/Serialization/Arrays"';
                  --l_method      := 'tns:AddPalletInput';
                  l_soap_action := 'Symbotic/ICaseManager/AddOrder';
                  --l_result_name := 'ROWSET';
    --------------------------Initiating the Webservice Call------------------------
                  l_request := soap_api.new_request(p_method         => l_method,
                                                   p_namespace      => l_namespace,
                                                   p_envelope_tag   => 'soapenv');
    -------------------------Passing the XML Parameter------------------------------
                  soap_api.add_complex_parameter(p_request => l_request,
                                                 p_xml     => l_xml_build);

                  soap_api.debug_on();
    ------------------------------Getting the Response------------------------------
                  l_response := soap_api.invoke(p_request => l_request,
                                                p_url     => l_url,
                                                p_action  => l_soap_action);
                                                
                  pl_text_log.ins_msg('INFO', 'pl_xml_matrix_out.SYS04',
                                                                       'Received the response for the message ID'||l_sys_msg_id||' Wavenumber: '||l_msg_wave_number,
                        NULL, NULL);
    -----------------------------Verifying the Response-----------------------------
                  l_xml_build := l_response.doc.getstringval();

                  l_count     := INSTR(l_xml_build,'<s:Fault>',1);

                  IF l_count != 0 THEN
                    l_xml_build := SUBSTR (l_xml_build,INSTR(l_xml_build,'<s:Fault>')+9,INSTR(l_xml_build,'</s:Fault>')-INSTR(l_xml_build,'<s:Fault>')-9);
                    l_error_msg := SUBSTR(l_xml_build,1,2000);
                    l_error_code:= 'SEE ERROR MSG';
                   RAISE web_exception;
                  END IF;

                 EXIT;

                EXCEPTION
                 WHEN web_exception THEN
                  RAISE web_exception;

                 WHEN OTHERS THEN
                  l_error_code:= SUBSTR(SQLERRM,1,100);
                  dbms_lock.sleep(l_retry_count*10);
                  l_retry_count := l_retry_count+1;
                  l_error_msg   := 'Retry: '||(l_retry_count-1)||' as it failed to connect';
                  UPDATE matrix_out
                     SET error_msg     = l_error_msg
                   WHERE sys_msg_id    = l_sys_msg_id;
                END;

             ELSE
              l_error_msg   := 'Failed All the Retry Attempts, see error code';
              RAISE web_exception;
             END IF;

           END LOOP;
    -------------------Updating the Record Status in Matrix_out---------------------

            BEGIN
               UPDATE matrix_out
                  SET record_status = 'S'
                WHERE sys_msg_id = l_sys_msg_id;
               COMMIT;
            EXCEPTION
             WHEN OTHERS THEN
              l_error_msg := 'Error: Updating to Success';
              l_error_code:= SUBSTR(SQLERRM,1,100);
              RAISE web_exception;
            END;

         END IF;

      END LOOP;

   END IF;
EXCEPTION
WHEN web_exception THEN
  UPDATE matrix_out
     SET record_status = 'F',
         error_msg     = l_error_msg,
         error_code    = l_error_code
   WHERE sys_msg_id    = l_sys_msg_id;
  -- insert into log_test values(1,l_error_msg);
  COMMIT;
WHEN OTHERS THEN
 l_error_code := SUBSTR(SQLERRM,1,100);
  UPDATE matrix_out
     SET record_status = 'F',
         error_msg     = 'Unknown Error: See Error_code',
         error_code    = l_error_code
   WHERE sys_msg_id    = l_sys_msg_id;
  -- insert into log_test values(1,l_error_msg);
  COMMIT;
END sys04_add_order;

PROCEDURE sys05_internal_order(
    i_sys_msg_id IN NUMBER DEFAULT NULL)
  /*===========================================================================================================
  -- Procedure
  -- sys05_internal_order
  --
  -- Description
  --   This procedure is to send a particular sys_msg_id data to symbotic.
  --   This procedure is used to pack the SYS05 data that is going out to symbotic.
  --
  -- Modification History
  --
  -- Date                User                  Version            Defect  Comment
  -- 10/02/14        Sunil Ontipalli             1.0              Initial Creation
  ============================================================================================================*/
IS
  ------------------------------soap_api parameters-----------------------------
  l_request           soap_api.t_request;
  l_response          soap_api.t_response;
  --l_return            VARCHAR2(32767);
  l_url               VARCHAR2(100);
  l_namespace         VARCHAR2(1000);
  l_method            VARCHAR2(100);
  l_soap_action       VARCHAR2(100);
  --l_result_name       VARCHAR2(32767);
  --------------------------------Local Variables-------------------------------
  l_xml               XMLTYPE;
  l_xml_build         CLOB;
  l_xml_build1        CLOB;
  l_xml_build2        CLOB;
  l_xml_build3        CLOB;
  l_xml_build4        CLOB;
  l_sys_msg_id        NUMBER(10):= NULL;
  l_timestamp         VARCHAR2(100);
  l_record_status     VARCHAR2(1);
  web_exception       EXCEPTION;
  l_error_msg         VARCHAR2(2000);
  l_error_code        VARCHAR2(100);
  l_count             NUMBER;
  l_retry_count       NUMBER;
  l_interface_flag    VARCHAR2(1);
  l_reason            VARCHAR2(100);
  CURSOR c_sys_msg_id
         IS
  SELECT DISTINCT(sys_msg_id)
    FROM matrix_out
   WHERE interface_ref_doc = 'SYS05'
     AND record_status     = 'N'
     AND (add_date   <  systimestamp - 1/(24*60) OR i_sys_msg_id IS NOT NULL)
     AND sys_msg_id = NVL(i_sys_msg_id, sys_msg_id);

BEGIN

   check_webservice(i_interface_ref_doc  => 'SYS05',
                    o_active_flag        => l_interface_flag,
                    o_url_port           => l_url,
                    o_reason             => l_reason);

   IF l_interface_flag = 'Y' THEN

     FOR i IN c_sys_msg_id
      LOOP
       EXIT WHEN c_sys_msg_id%NOTFOUND;
    -----------------------Initializing the local variables-------------------------
        l_sys_msg_id := i.sys_msg_id;
        l_timestamp  := TO_CHAR(SYSTIMESTAMP,'YYYY-MM-DD HH24:MI:SS');
    ---------------------------Getting the Record status----------------------------
         BEGIN
          SELECT DISTINCT(record_status)
            INTO l_record_status
            FROM matrix_out
           WHERE sys_msg_id = l_sys_msg_id;
         EXCEPTION
         WHEN OTHERS THEN
           l_error_msg := 'Error: Getting the Record Status';
           RAISE web_exception;
         END;
    -----------Checking Whether the Status is 'N' and Locking the Record------------
        IF UPPER(l_record_status) = 'N' THEN

           BEGIN
             UPDATE matrix_out
                SET record_status = 'Q'
              WHERE sys_msg_id  = l_sys_msg_id
                AND record_status = 'N';
             COMMIT;
           EXCEPTION
            WHEN OTHERS THEN
             l_error_msg := 'Error: Updating the Record status to Q';
             l_error_code:= SUBSTR(SQLERRM,1,100);
             RAISE web_exception;
           END;

    -----------------------Generating the XML for Webservice------------------------
           BEGIN

             SELECT  XMLELEMENT("metadata",
                      XMLFOREST(l_sys_msg_id AS "MessageId",
                              l_timestamp  AS "RequestDateTime")
                              )
              INTO l_xml
              FROM dual;
           EXCEPTION
            WHEN OTHERS THEN
             l_error_msg := 'Error: Generating the XML 1';
             l_error_code:= SUBSTR(SQLERRM,1,100);
             RAISE web_exception;
           END;

           l_xml_build := l_xml.getstringval();
           l_xml       := NULL;

           BEGIN

             SELECT XMLFOREST (nvl(mo.trans_type,' ')                  AS "releaseType",
                               nvl(mo.batch_id,0)                      AS "batchId",
                               nvl(mo.order_generation_time,' ')       AS "orderTime",
                               nvl(mo.priority,0)                      AS "priority"
                               )
                         INTO l_xml
                         FROM matrix_out mo
                        WHERE sys_msg_id = l_sys_msg_id
                          AND (rec_ind   = 'H' or rec_ind = 'S');
           EXCEPTION
            WHEN OTHERS THEN
             l_error_msg := 'Error: Generating the XML 2';
             l_error_code:= SUBSTR(SQLERRM,1,100);
             RAISE web_exception;
           END;

           l_xml_build := l_xml_build||l_xml.getstringval();

           l_xml  := NULL;
        ----------------------------------------
           FOR I IN (SELECT sequence_number
                       FROM matrix_out
                      WHERE sys_msg_id     = l_sys_msg_id
                        AND rec_ind       != 'H')
           LOOP

             BEGIN

              SELECT XMLFOREST(nvl(mo.case_qty,0)                AS "CaseQuantity",
                               nvl(mo.destination_loc,' ')       AS "DestinationLocation",
                               nvl(mo.exact_pallet_imp,' ')      AS "ExactPalletImportance",
                               nvl(mo.prod_id,' ')               AS "ItemId",
                               nvl(mo.pallet_id,' ')             AS "RequestedSourcePallet",
                               nvl(mo.task_id,' ')               AS "TaskId")
                INTO l_xml
                FROM matrix_out mo
               WHERE sequence_number = I.sequence_number;

             EXCEPTION
              WHEN OTHERS THEN
               l_error_msg := 'Error: Generating the XML 3';
               l_error_code:= SUBSTR(SQLERRM,1,100);
               RAISE web_exception;
             END;

             l_xml_build1  := l_xml.getstringval();

             l_xml  := NULL;

             FOR J IN (SELECT rowid
                         FROM matrix_out_label
                        WHERE sequence_number = I.sequence_number)
              LOOP

                BEGIN

                     SELECT XMLELEMENT("string",nvl(barcode,' ')
                                       )
                       INTO l_xml
                       FROM matrix_out_label
                      WHERE rowid = J.rowid;

                EXCEPTION
                 WHEN OTHERS THEN
                  l_error_msg := 'Error: Generating the XML 4';
                  l_error_code:= SUBSTR(SQLERRM,1,100);
                RAISE web_exception;
                END;

                IF l_xml_build2 IS NULL THEN

                  l_xml_build2  := l_xml.getstringval();
                ELSE
                  l_xml_build2  := l_xml_build2||l_xml.getstringval();
                END IF;

                l_xml  := NULL;

              END LOOP;

              l_xml_build2 := '<CaseBarcode>'||l_xml_build2||'</CaseBarcode>';

              FOR J IN (SELECT rowid
                          FROM matrix_out_label
                         WHERE sequence_number = I.sequence_number)
              LOOP

                  BEGIN

                     SELECT XMLELEMENT("string",nvl(encoded_print_stream,' ')
                                      )
                       INTO l_xml
                       FROM matrix_out_label
                      WHERE rowid = J.rowid;

                  EXCEPTION
                   WHEN OTHERS THEN
                    l_error_msg := 'Error: Generating the XML 6';
                    l_error_code:= SUBSTR(SQLERRM,1,100);
                    RAISE web_exception;
                  END;

                  IF l_xml_build4 IS NULL THEN

                  l_xml_build4  := l_xml.getstringval();
                  ELSE
                  l_xml_build4  := l_xml_build4||l_xml.getstringval();
                  END IF;

                  l_xml  := NULL;

              END LOOP;

              l_xml_build4 := '<CaseLabels>'||l_xml_build4||'</CaseLabels>';

              l_xml_build1 :=  l_xml_build1||l_xml_build2||l_xml_build4;
              l_xml_build2 :=  NULL;
              l_xml_build4 :=  NULL;
              l_xml_build1 := '<InternalOrderSkuDetail>'||l_xml_build1||'</InternalOrderSkuDetail>';

               IF l_xml_build3 IS NULL THEN

                  l_xml_build3  := l_xml_build1;
               ELSE
                  l_xml_build3  := l_xml_build3||l_xml_build1;
               END IF;

            l_xml_build1 :=  NULL;

           END LOOP;

           l_xml_build3  := '<internalOrderSkuDetails>'||l_xml_build3||'</internalOrderSkuDetails>';

      /*

         BEGIN

            SELECT XMLELEMENT("internalOrderSkuDetails",
                     XMLAGG(XMLELEMENT("InternalOrderSkuDetail",
                             (SELECT XMLELEMENT("caseBarcode",
                                       XMLAGG(XMLELEMENT("string",nvl(barcode,' '))))
                                FROM matrix_out_label
                               WHERE sequence_number = mo.sequence_number ),
                             (SELECT XMLELEMENT("CaseLabels",
                                       XMLAGG(XMLELEMENT("string",nvl(print_stream,' '))))
                                FROM matrix_out_label
                               WHERE sequence_number = mo.sequence_number),
                              XMLELEMENT("casequantity", nvl(mo.case_qty,0)),
                              XMLELEMENT("DestinationLocation", nvl(mo.destination_loc,' ')),
                              XMLELEMENT("ItemId", nvl(mo.prod_id,' ')),
                              XMLELEMENT("requestedSourcePallet", nvl(mo.pallet_id,' ')),
                              XMLELEMENT("TaskId", nvl(mo.task_id,' ')),
                              XMLELEMENT("exactPalletImportance", nvl(mo.exact_pallet_imp,' '))
                                       )
                             )
                              )
               INTO l_xml
               FROM matrix_out mo
              WHERE sys_msg_id     = l_sys_msg_id
                AND rec_ind       != 'H';
        EXCEPTION
        WHEN OTHERS THEN
          l_error_msg := 'Error: Generating the XML 3';
          l_error_code:= SUBSTR(SQLERRM,1,100);
          RAISE web_exception;
        END;*/

           l_xml_build := l_xml_build||l_xml_build3;
           l_xml_build := '<AddInternalOrder>'||l_xml_build||'</AddInternalOrder>';

           l_xml_build := replace(l_xml_build, '<','<sym:');
           l_xml_build := replace(l_xml_build, '<sym:/','</sym:');
           l_xml_build := replace(l_xml_build, '<sym:string','<arr:string');
           l_xml_build := replace(l_xml_build, '</sym:string', '</arr:string' );

           l_retry_count := 1;

           LOOP

              IF l_retry_count < 4 THEN

                 BEGIN

    ---------------------Initilaizing the Webservice Parameters---------------------
                    --l_url         := 'http://10.254.4.130:7800/CaseManager';
                    l_namespace   := 'xmlns:sym="Symbotic" xmlns:arr="http://schemas.microsoft.com/2003/10/Serialization/Arrays"';
                    --l_method      := 'tns:AddPalletInput';
                    l_soap_action := 'Symbotic/ICaseManager/AddInternalOrder';
                    --l_result_name := 'ROWSET';
    --------------------------Initiating the Webservice Call------------------------
                    l_request := soap_api.new_request(p_method         => l_method,
                                                      p_namespace      => l_namespace,
                                                      p_envelope_tag   => 'soapenv');
    -------------------------Passing the XML Parameter------------------------------
                    soap_api.add_complex_parameter(p_request => l_request,
                                                   p_xml     => l_xml_build);

                    soap_api.debug_on();
    ------------------------------Getting the Response------------------------------
                    l_response := soap_api.invoke(p_request => l_request,
                                                  p_url     => l_url,
                                                  p_action  => l_soap_action);
    -----------------------------Verifying the Response-----------------------------
                    l_xml_build := l_response.doc.getstringval();

                    l_count     := INSTR(l_xml_build,'<s:Fault>',1);

                     IF l_count != 0 THEN
                       l_xml_build := SUBSTR (l_xml_build,INSTR(l_xml_build,'<s:Fault>')+9,INSTR(l_xml_build,'</s:Fault>')-INSTR(l_xml_build,'<s:Fault>')-9);
                       l_error_msg := SUBSTR(l_xml_build,1,2000);
                       l_error_code:= 'SEE ERROR MSG';
                       RAISE web_exception;
                     END IF;

                     EXIT;

                 EXCEPTION
                  WHEN web_exception THEN
                   RAISE web_exception;
                  WHEN OTHERS THEN
                   l_error_code:= SUBSTR(SQLERRM,1,100);
                   dbms_lock.sleep(l_retry_count*10);
                   l_retry_count := l_retry_count+1;
                   l_error_msg   := 'Retry: '||(l_retry_count-1)||' as it failed to connect';
                   UPDATE matrix_out
                      SET error_msg     = l_error_msg
                    WHERE sys_msg_id    = l_sys_msg_id;
                 END;

              ELSE
                l_error_msg   := 'Failed All the Retry Attempts, see error code';
                RAISE web_exception;
              END IF;

           END LOOP;
    -------------------Updating the Record Status in Matrix_out---------------------

           BEGIN
             UPDATE matrix_out
                SET record_status = 'S'
              WHERE sys_msg_id = l_sys_msg_id;
             COMMIT;
           EXCEPTION
            WHEN OTHERS THEN
             l_error_msg := 'Error: Updating to Success';
             l_error_code:= SUBSTR(SQLERRM,1,100);
             RAISE web_exception;
           END;

        END IF;

      END LOOP;

   END IF;

EXCEPTION
WHEN web_exception THEN
  UPDATE matrix_out
     SET record_status = 'F',
         error_msg     = l_error_msg,
         error_code    = l_error_code
   WHERE sys_msg_id    = l_sys_msg_id;
  -- insert into log_test values(1,l_error_msg);
  COMMIT;
WHEN OTHERS THEN
 l_error_code := SUBSTR(SQLERRM,1,100);
  UPDATE matrix_out
     SET record_status = 'F',
         error_msg     = 'Unknown Error: See Error_code',
         error_code    = l_error_code
   WHERE sys_msg_id    = l_sys_msg_id;
  -- insert into log_test values(1,l_error_msg);
  COMMIT;
END sys05_internal_order;


PROCEDURE sys06_spur_case_removal(
    i_sys_msg_id IN NUMBER DEFAULT NULL)
  /*===========================================================================================================
  -- Procedure
  -- sys06_spur_case_removal
  --
  -- Description
  --   This procedure is to send a particular sys_msg_id data to symbotic.
  --   This procedure is used to pack the SYS06 data that is going out to symbotic.
  --
  -- Modification History
  --
  -- Date                User                  Version            Defect  Comment
  -- 10/09/14        Sunil Ontipalli             1.0              Initial Creation
  ============================================================================================================*/
IS
 ------------------------------soap_api parameters-----------------------------
  l_request           soap_api.t_request;
  l_response          soap_api.t_response;
  --l_return            VARCHAR2(32767);
  l_url               VARCHAR2(100);
  l_namespace         VARCHAR2(1000);
  l_method            VARCHAR2(100);
  l_soap_action       VARCHAR2(100);
  --l_result_name       VARCHAR2(32767);
  --------------------------------Local Variables-------------------------------
  l_xml               XMLTYPE;
  l_xml_build         CLOB;
  l_sys_msg_id        NUMBER(10):= NULL;
  l_batch_id          matrix_out.batch_id%type;
  l_case_barcode      matrix_out.case_barcode%type;
  l_prod_id           matrix_out.prod_id%type;
  l_timestamp         VARCHAR2(100);
  l_record_status     VARCHAR2(1);
  web_exception       EXCEPTION;
  l_error_msg         VARCHAR2(2000);
  l_error_code        VARCHAR2(100);
  l_count             NUMBER;
  l_retry_count       NUMBER;
  l_interface_flag    VARCHAR2(1);
  l_reason            VARCHAR2(100);
  l_sym12_exist       VARCHAR2(1);
  CURSOR c_sys_msg_id
         IS
  SELECT DISTINCT(sys_msg_id),batch_id,case_barcode,prod_id   
    FROM matrix_out
   WHERE interface_ref_doc = 'SYS06'
     AND record_status     = 'N'
     AND (add_date   <  systimestamp - 1/(24*60) OR i_sys_msg_id IS NOT NULL)
     AND sys_msg_id = NVL(i_sys_msg_id, sys_msg_id);

BEGIN

   check_webservice(i_interface_ref_doc  => 'SYS06',
                    o_active_flag        => l_interface_flag,
                    o_url_port           => l_url,
                    o_reason             => l_reason);

   IF l_interface_flag = 'Y' THEN
     FOR i IN c_sys_msg_id
      LOOP

       EXIT WHEN c_sys_msg_id%NOTFOUND;
    -----------------------Initializing the local variables-------------------------
        l_sys_msg_id := i.sys_msg_id;
        l_batch_id   := i.batch_id;
        l_case_barcode :=i.case_barcode;
        l_prod_id    :=i.prod_id;
        l_timestamp  := TO_CHAR(SYSTIMESTAMP,'YYYY-MM-DD HH24:MI:SS');
    
   -----------Checking Whether the case is diverted to Spurs---------------------
        BEGIN
         SELECT 'Y' 
           INTO  l_sym12_exist
          FROM  matrix_in
          WHERE interface_ref_doc = 'SYM12'
          AND rec_ind = 'S'
          AND batch_id= l_batch_id
          AND case_barcode = l_case_barcode
          AND prod_id = l_prod_id;
        EXCEPTION 
          WHEN no_data_found  THEN 
            l_sym12_exist:='N';
          WHEN OTHERS THEN
            l_error_code:= SUBSTR(SQLERRM,1,100);
            l_error_msg := 'Error: Getting matching Sym12 record';
            RAISE web_exception;
        END;
        
        BEGIN
        IF l_sym12_exist = 'N' then
           
           UPDATE matrix_out 
             SET record_status ='H' 
           WHERE sys_msg_id = l_sys_msg_id;
           
        END IF;
         EXCEPTION
             WHEN OTHERS THEN
              l_error_msg := 'Error: Updating the Record status to H';
              l_error_code:= SUBSTR(SQLERRM,1,100);
              RAISE web_exception;
        END;
  ---------------------------Getting the Record status----------------------------
         BEGIN
            SELECT DISTINCT(record_status)
              INTO l_record_status
              FROM matrix_out
             WHERE sys_msg_id = l_sys_msg_id;
         EXCEPTION
          WHEN OTHERS THEN
           l_error_msg := 'Error: Getting the Record Status';
           RAISE web_exception;
         END;
    -----------Checking Whether the record is diverted to Spurs---------------------
    -----------Checking Whether the Status is 'N' and Locking the Record------------
         IF UPPER(l_record_status) = 'N' THEN

            BEGIN
              UPDATE matrix_out
                 SET record_status = 'Q'
               WHERE sys_msg_id  = l_sys_msg_id
                 AND record_status = 'N';
               COMMIT;
            EXCEPTION
             WHEN OTHERS THEN
              l_error_msg := 'Error: Updating the Record status to Q';
              l_error_code:= SUBSTR(SQLERRM,1,100);
              RAISE web_exception;
            END;
    -----------------------Generating the XML for Webservice------------------------
            BEGIN

                SELECT  XMLELEMENT("metadata",
                         XMLFOREST(l_sys_msg_id AS "MessageId",
                                   l_timestamp  AS "RequestDateTime")
                                   )
                  INTO l_xml
                  FROM dual;
            EXCEPTION
             WHEN OTHERS THEN
              l_error_msg := 'Error: Generating the XML 1';
              l_error_code:= SUBSTR(SQLERRM,1,100);
              RAISE web_exception;
            END;

            l_xml_build := l_xml.getstringval();
            l_xml       := NULL;

            BEGIN
                 SELECT XMLFOREST (nvl(mo.batch_id,' ')                      AS "batchId",
                                   nvl(mo.prod_id,' ')                       AS "itemId",
                                   nvl(mo.case_barcode,' ')                  AS "caseBarcode",
                                   nvl(mo.spur_loc,' ')                      AS "spurLocation",
                                   nvl(mo.case_grab_timestamp,' ')           AS "caseGrabTimestamp"
                                   )
                             INTO l_xml
                             FROM matrix_out mo
                            WHERE sys_msg_id = l_sys_msg_id
                              AND rec_ind = 'S';
            EXCEPTION
             WHEN OTHERS THEN
              l_error_msg := 'Error: Generating the XML 2';
              l_error_code:= SUBSTR(SQLERRM,1,100);
              RAISE web_exception;
            END;

            l_xml_build := l_xml_build||l_xml.getstringval();

            l_xml  := NULL;


            l_xml_build := '<NotifyCaseRemovedFromSpur>'||l_xml_build||'</NotifyCaseRemovedFromSpur>';

            l_xml_build := replace(l_xml_build, '<','<sym:');
            l_xml_build := replace(l_xml_build, '<sym:/','</sym:');
            l_xml_build := replace(l_xml_build, '<sym:string','<arr:string');
            l_xml_build := replace(l_xml_build, '</sym:string', '</arr:string' );

        /*INSERT
          INTO test_table1
        VALUES (l_xml);
        COMMIT;*/

           l_retry_count := 1;

           LOOP

              IF l_retry_count < 4 THEN

                 BEGIN

    ---------------------Initilaizing the Webservice Parameters---------------------
                   -- l_url         := 'http://10.254.4.130:7800/CaseManager';
                    l_namespace   := 'xmlns:sym="Symbotic" xmlns:arr="http://schemas.microsoft.com/2003/10/Serialization/Arrays"';
                    --l_method      := 'tns:AddPalletInput';
                    l_soap_action := 'Symbotic/ICaseManager/NotifyCaseRemovedFromSpur';
                    --l_result_name := 'ROWSET';
    --------------------------Initiating the Webservice Call------------------------
                    l_request := soap_api.new_request(p_method         => l_method,
                                                      p_namespace      => l_namespace,
                                                      p_envelope_tag   => 'soapenv');
    -------------------------Passing the XML Parameter------------------------------
                    soap_api.add_complex_parameter(p_request => l_request,
                                                   p_xml     => l_xml_build);

                    soap_api.debug_on();
    ------------------------------Getting the Response------------------------------
                    l_response := soap_api.invoke(p_request => l_request,
                                                  p_url     => l_url,
                                                  p_action  => l_soap_action);
    -----------------------------Verifying the Response-----------------------------
                    l_xml_build := l_response.doc.getstringval();

                    l_count     := INSTR(l_xml_build,'<s:Fault>',1);

                        IF l_count != 0 THEN
                           l_xml_build := SUBSTR (l_xml_build,INSTR(l_xml_build,'<s:Fault>')+9,INSTR(l_xml_build,'</s:Fault>')-INSTR(l_xml_build,'<s:Fault>')-9);
                           l_error_msg := SUBSTR(l_xml_build,1,2000);
                           l_error_code:= 'SEE ERROR MSG';
                           RAISE web_exception;
                        END IF;
                     EXIT;

                 EXCEPTION
                  WHEN web_exception THEN
                   RAISE web_exception;
                  WHEN OTHERS THEN
                   l_error_code:= SUBSTR(SQLERRM,1,100);
                   dbms_lock.sleep(l_retry_count*10);
                   l_retry_count := l_retry_count+1;
                   l_error_msg   := 'Retry: '||(l_retry_count-1)||' as it failed to connect';
                   UPDATE matrix_out
                      SET error_msg     = l_error_msg
                    WHERE sys_msg_id    = l_sys_msg_id;
                 END;

              ELSE

               l_error_msg   := 'Failed All the Retry Attempts, see error code';
               RAISE web_exception;

              END IF;

           END LOOP;
    -------------------Updating the Record Status in Matrix_out---------------------

           BEGIN
             UPDATE matrix_out
                SET record_status = 'S'
              WHERE sys_msg_id = l_sys_msg_id;
             COMMIT;
           EXCEPTION
            WHEN OTHERS THEN
             l_error_msg := 'Error: Updating to Success';
             l_error_code:= SUBSTR(SQLERRM,1,100);
             RAISE web_exception;
           END;

         END IF;

      END LOOP;

   END IF;

EXCEPTION
WHEN web_exception THEN
  UPDATE matrix_out
     SET record_status = 'F',
         error_msg     = l_error_msg,
         error_code    = l_error_code
   WHERE sys_msg_id    = l_sys_msg_id;
  -- insert into log_test values(1,l_error_msg);
  COMMIT;
WHEN OTHERS THEN
 l_error_code := SUBSTR(SQLERRM,1,100);
  UPDATE matrix_out
     SET record_status = 'F',
         error_msg     = 'Unknown Error: See Error_code',
         error_code    = l_error_code
   WHERE sys_msg_id    = l_sys_msg_id;
  -- insert into log_test values(1,l_error_msg);
  COMMIT;
END sys06_spur_case_removal;

PROCEDURE sys07_batch_status(
    i_sys_msg_id IN NUMBER DEFAULT NULL)
  /*===========================================================================================================
  -- Procedure
  -- sys07_batch_complete
  --
  -- Description
  --   This procedure is to send a particular sys_msg_id data to symbotic.
  --   This procedure is used to pack the SYS07 data that is going out to symbotic.
  --
  -- Modification History
  --
  -- Date                User                  Version            Defect  Comment
  -- 09/11/14        Sunil Ontipalli             1.0              Initial Creation
  ============================================================================================================*/
IS
  ------------------------------soap_api parameters-----------------------------
  l_request           soap_api.t_request;
  l_response          soap_api.t_response;
  --l_return            VARCHAR2(32767);
  l_url               VARCHAR2(100);
  l_namespace         VARCHAR2(1000);
  l_method            VARCHAR2(100);
  l_soap_action       VARCHAR2(100);
  --l_result_name       VARCHAR2(32767);
  --------------------------------Local Variables-------------------------------
  l_xml               XMLTYPE;
  l_xml_build         CLOB;
  l_sys_msg_id        NUMBER(10):= NULL;
  l_timestamp         VARCHAR2(100);
  l_record_status     VARCHAR2(1);
  web_exception       EXCEPTION;
  l_error_msg         VARCHAR2(2000);
  l_error_code        VARCHAR2(100);
  l_count             NUMBER;
  l_retry_count       NUMBER;
  l_interface_flag    VARCHAR2(1);
  l_reason            VARCHAR2(100);
  CURSOR c_sys_msg_id
         IS
  SELECT DISTINCT(sys_msg_id)
    FROM matrix_out
   WHERE interface_ref_doc = 'SYS07'
     AND record_status     = 'N'
     AND (add_date   <  systimestamp - 1/(24*60) OR i_sys_msg_id IS NOT NULL)
     AND sys_msg_id = NVL(i_sys_msg_id, sys_msg_id);

BEGIN

   check_webservice(i_interface_ref_doc  => 'SYS07',
                    o_active_flag        => l_interface_flag,
                    o_url_port           => l_url,
                    o_reason             => l_reason);

   IF l_interface_flag = 'Y' THEN

     FOR i IN c_sys_msg_id
      LOOP
       EXIT WHEN c_sys_msg_id%NOTFOUND;
    -----------------------Initializing the local variables-------------------------
        l_sys_msg_id := i.sys_msg_id;
        l_timestamp  := TO_CHAR(SYSTIMESTAMP,'YYYY-MM-DD HH24:MI:SS');
    ---------------------------Getting the Record status----------------------------
         BEGIN
           SELECT DISTINCT(record_status)
             INTO l_record_status
             FROM matrix_out
            WHERE sys_msg_id = l_sys_msg_id;
         EXCEPTION
          WHEN OTHERS THEN
           l_error_msg := 'Error: Getting the Record Status';
           RAISE web_exception;
         END;
    -----------Checking Whether the Status is 'N' and Locking the Record------------
         IF UPPER(l_record_status) = 'N' THEN

            BEGIN
               UPDATE matrix_out
                  SET record_status = 'Q'
                WHERE sys_msg_id  = l_sys_msg_id
                  AND record_status = 'N';
               COMMIT;
            EXCEPTION
             WHEN OTHERS THEN
              l_error_msg := 'Error: Updating the Record status to Q';
              l_error_code:= SUBSTR(SQLERRM,1,100);
              RAISE web_exception;
            END;
    -----------------------Generating the XML for Webservice------------------------
            BEGIN

               SELECT  XMLELEMENT("metadata",
                        XMLFOREST(l_sys_msg_id AS "MessageId",
                                  l_timestamp  AS "RequestDateTime")
                                  )
                 INTO l_xml
                 FROM dual;
            EXCEPTION
             WHEN OTHERS THEN
              l_error_msg := 'Error: Generating the XML 1';
              l_error_code:= SUBSTR(SQLERRM,1,100);
              RAISE web_exception;
            END;

            l_xml_build := l_xml.getstringval();
            l_xml       := NULL;

            BEGIN

               SELECT XMLFOREST (nvl(mo.batch_id,' ')                      AS "batchId",
                                 nvl(mo.batch_complete_timestamp,' ')      AS "batchStatusTimestamp",
                                 nvl(mo.batch_status,' ')                  AS "batchStatus"
                                  )
                           INTO l_xml
                           FROM matrix_out mo
                          WHERE sys_msg_id = l_sys_msg_id
                            AND rec_ind    = 'S';
            EXCEPTION
             WHEN OTHERS THEN
              l_error_msg := 'Error: Generating the XML 2';
              l_error_code:= SUBSTR(SQLERRM,1,100);
              RAISE web_exception;
            END;

            l_xml_build := l_xml_build||l_xml.getstringval();

            l_xml  := NULL;

            l_xml_build := '<NotifyBatchStatusChanged>'||l_xml_build||'</NotifyBatchStatusChanged>';

            l_xml_build := replace(l_xml_build, '<','<sym:');
            l_xml_build := replace(l_xml_build, '<sym:/','</sym:');
            l_xml_build := replace(l_xml_build, '<sym:string','<arr:string');
            l_xml_build := replace(l_xml_build, '</sym:string', '</arr:string' );

           /*INSERT
               INTO test_table1
             VALUES (l_xml);
             COMMIT;*/

            l_retry_count := 1;

            LOOP

               IF l_retry_count < 4 THEN

                  BEGIN

    ---------------------Initilaizing the Webservice Parameters---------------------
                     --l_url         := 'http://10.254.4.130:7800/CaseManager';
                     l_namespace   := 'xmlns:sym="Symbotic" xmlns:arr="http://schemas.microsoft.com/2003/10/Serialization/Arrays"';
                     --l_method      := 'tns:AddPalletInput';
                     l_soap_action := 'Symbotic/ICaseManager/NotifyBatchStatusChanged';
                     --l_result_name := 'ROWSET';
    --------------------------Initiating the Webservice Call------------------------
                     l_request := soap_api.new_request(p_method         => l_method,
                                                       p_namespace      => l_namespace,
                                                       p_envelope_tag   => 'soapenv');
    -------------------------Passing the XML Parameter------------------------------
                     soap_api.add_complex_parameter(p_request => l_request,
                                                    p_xml     => l_xml_build);

                     soap_api.debug_on();
    ------------------------------Getting the Response------------------------------
                     l_response := soap_api.invoke(p_request => l_request,
                                                   p_url     => l_url,
                                                   p_action  => l_soap_action);
    -----------------------------Verifying the Response-----------------------------
                     l_xml_build := l_response.doc.getstringval();

                     l_count     := INSTR(l_xml_build,'<s:Fault>',1);

                       IF l_count != 0 THEN
                         l_xml_build := SUBSTR (l_xml_build,INSTR(l_xml_build,'<s:Fault>')+9,INSTR(l_xml_build,'</s:Fault>')-INSTR(l_xml_build,'<s:Fault>')-9);
                         l_error_msg := SUBSTR(l_xml_build,1,2000);
                         l_error_code:= 'SEE ERROR MSG';
                         RAISE web_exception;
                       END IF;

                     EXIT;

                  EXCEPTION
                   WHEN web_exception THEN
                    RAISE web_exception;
                   WHEN OTHERS THEN
                    l_error_code:= SUBSTR(SQLERRM,1,100);
                    dbms_lock.sleep(l_retry_count*10);
                    l_retry_count := l_retry_count+1;
                    l_error_msg   := 'Retry: '||(l_retry_count-1)||' as it failed to connect';
                    UPDATE matrix_out
                       SET error_msg     = l_error_msg
                     WHERE sys_msg_id    = l_sys_msg_id;
                  END;

               ELSE
                l_error_msg   := 'Failed All the Retry Attempts, see error code';
                RAISE web_exception;
               END IF;

            END LOOP;

    -------------------Updating the Record Status in Matrix_out---------------------

            BEGIN
              UPDATE matrix_out
                 SET record_status = 'S'
               WHERE sys_msg_id = l_sys_msg_id;
              COMMIT;
            EXCEPTION
             WHEN OTHERS THEN
              l_error_msg := 'Error: Updating to Success';
              l_error_code:= SUBSTR(SQLERRM,1,100);
              RAISE web_exception;
            END;

         END IF;

      END LOOP;

   END IF;

EXCEPTION
WHEN web_exception THEN
  UPDATE matrix_out
     SET record_status = 'F',
         error_msg     = l_error_msg,
         error_code    = l_error_code
   WHERE sys_msg_id    = l_sys_msg_id;
  -- insert into log_test values(1,l_error_msg);
  COMMIT;
WHEN OTHERS THEN
 l_error_code := SUBSTR(SQLERRM,1,100);
  UPDATE matrix_out
     SET record_status = 'F',
         error_msg     = 'Unknown Error: See Error_code',
         error_code    = l_error_code
   WHERE sys_msg_id    = l_sys_msg_id;
  -- insert into log_test values(1,l_error_msg);
  COMMIT;
END sys07_batch_status;

PROCEDURE sys08_pallet_update(
    i_sys_msg_id IN NUMBER DEFAULT NULL)
  /*===========================================================================================================
  -- Procedure
  -- sys08_pallet_update
  --
  -- Description
  --   This procedure is to send a particular sys_msg_id data to symbotic.
  --   This procedure is used to pack the SYS08 data that is going out to symbotic.
  --
  -- Modification History
  --
  -- Date                User                  Version            Defect  Comment
  -- 09/11/14        Sunil Ontipalli             1.0              Initial Creation
  ============================================================================================================*/
IS
------------------------------soap_api parameters-----------------------------
  l_request           soap_api.t_request;
  l_response          soap_api.t_response;
  --l_return            VARCHAR2(32767);
  l_url               VARCHAR2(100);
  l_namespace         VARCHAR2(1000);
  l_method            VARCHAR2(100);
  l_soap_action       VARCHAR2(100);
  --l_result_name       VARCHAR2(32767);
  --------------------------------Local Variables-------------------------------
  l_xml               XMLTYPE;
  l_xml_build         CLOB;
  l_sys_msg_id        NUMBER(10):= NULL;
  l_timestamp         VARCHAR2(100);
  l_record_status     VARCHAR2(1);
  web_exception       EXCEPTION;
  l_error_msg         VARCHAR2(2000);
  l_error_code        VARCHAR2(100);
  l_count             NUMBER;
  l_retry_count       NUMBER;
  l_interface_flag    VARCHAR2(1);
  l_reason            VARCHAR2(100);
  CURSOR c_sys_msg_id
         IS
  SELECT DISTINCT(sys_msg_id)
    FROM matrix_out
   WHERE interface_ref_doc = 'SYS08'
     AND record_status     = 'N'
     AND (add_date   <  systimestamp - 1/(24*60) OR i_sys_msg_id IS NOT NULL)
     AND sys_msg_id = NVL(i_sys_msg_id, sys_msg_id);

BEGIN

   check_webservice(i_interface_ref_doc  => 'SYS08',
                    o_active_flag        => l_interface_flag,
                    o_url_port           => l_url,
                    o_reason             => l_reason);

   IF l_interface_flag = 'Y' THEN

     FOR i IN c_sys_msg_id
      LOOP

       EXIT WHEN c_sys_msg_id%NOTFOUND;
    -----------------------Initializing the local variables-------------------------
        l_sys_msg_id := i.sys_msg_id;
        l_timestamp  := TO_CHAR(SYSTIMESTAMP,'YYYY-MM-DD HH24:MI:SS');
    ---------------------------Getting the Record status----------------------------
         BEGIN
           SELECT DISTINCT(record_status)
             INTO l_record_status
             FROM matrix_out
            WHERE sys_msg_id = l_sys_msg_id;
         EXCEPTION
          WHEN OTHERS THEN
           l_error_msg := 'Error: Getting the Record Status';
           RAISE web_exception;
         END;
    -----------Checking Whether the Status is 'N' and Locking the Record------------
         IF UPPER(l_record_status) = 'N' THEN

            BEGIN
              UPDATE matrix_out
                 SET record_status = 'Q'
               WHERE sys_msg_id  = l_sys_msg_id
                 AND record_status = 'N';
              COMMIT;
            EXCEPTION
             WHEN OTHERS THEN
              l_error_msg := 'Error: Updating the Record status to Q';
              l_error_code:= SUBSTR(SQLERRM,1,100);
              RAISE web_exception;
            END;
    -----------------------Generating the XML for Webservice------------------------
            BEGIN

               SELECT  XMLELEMENT("metadata",
                        XMLFOREST(l_sys_msg_id AS "MessageId",
                                  l_timestamp  AS "RequestDateTime")
                                  )
                 INTO l_xml
                 FROM dual;
            EXCEPTION
             WHEN OTHERS THEN
              l_error_msg := 'Error: Generating the XML 1';
              l_error_code:= SUBSTR(SQLERRM,1,100);
              RAISE web_exception;
            END;

            l_xml_build := l_xml.getstringval();
            l_xml       := NULL;

            BEGIN
               SELECT XMLFOREST (nvl(mo.prod_id,' ')                                            AS "itemId",
                                 nvl(mo.pallet_id,' ')                                          AS "palletId",
                                 nvl(mo.inv_status,' ')                                         AS "holdStatus",
                                 nvl(TO_CHAR(mo.expiration_date,'YYYY-MM-DD HH24:MI:SS'),' ')   AS "productDate"
                                 )
                           INTO l_xml
                           FROM matrix_out mo
                          WHERE sys_msg_id = l_sys_msg_id
                            AND rec_ind = 'S';
            EXCEPTION
             WHEN OTHERS THEN
              l_error_msg := 'Error: Generating the XML 2';
              l_error_code:= SUBSTR(SQLERRM,1,100);
              RAISE web_exception;
            END;

            l_xml_build := l_xml_build||l_xml.getstringval();

            l_xml  := NULL;

            l_xml_build := '<UpdatePallet>'||l_xml_build||'</UpdatePallet>';

            l_xml_build := replace(l_xml_build, '<','<sym:');
            l_xml_build := replace(l_xml_build, '<sym:/','</sym:');
            l_xml_build := replace(l_xml_build, '<sym:string','<arr:string');
            l_xml_build := replace(l_xml_build, '</sym:string', '</arr:string' );


            l_retry_count := 1;

            LOOP

               IF l_retry_count < 4 THEN

                  BEGIN

    ---------------------Initilaizing the Webservice Parameters---------------------
                     --l_url         := 'http://10.254.4.135:7800/CaseManager';
                     l_namespace   := 'xmlns:sym="Symbotic" xmlns:arr="http://schemas.microsoft.com/2003/10/Serialization/Arrays"';
                     --l_method      := 'tns:AddPalletInput';
                     l_soap_action := 'Symbotic/ICaseManager/UpdatePallet';
                     --l_result_name := 'ROWSET';
    --------------------------Initiating the Webservice Call------------------------
                     l_request := soap_api.new_request(p_method         => l_method,
                                                       p_namespace      => l_namespace,
                                                       p_envelope_tag   => 'soapenv');
    -------------------------Passing the XML Parameter------------------------------
                     soap_api.add_complex_parameter(p_request => l_request,
                                                    p_xml     => l_xml_build);

                     soap_api.debug_on();
    ------------------------------Getting the Response------------------------------
                     l_response := soap_api.invoke(p_request => l_request,
                                                   p_url     => l_url,
                                                   p_action  => l_soap_action);
    -----------------------------Verifying the Response-----------------------------
                     l_xml_build := l_response.doc.getstringval();

                     l_count     := INSTR(l_xml_build,'<s:Fault>',1);

                      IF l_count != 0 THEN
                        l_xml_build := SUBSTR (l_xml_build,INSTR(l_xml_build,'<s:Fault>')+9,INSTR(l_xml_build,'</s:Fault>')-INSTR(l_xml_build,'<s:Fault>')-9);
                        l_error_msg := SUBSTR(l_xml_build,1,2000);
                        l_error_code:= 'SEE ERROR MSG';
                        RAISE web_exception;
                      END IF;

                   EXIT;

                  EXCEPTION
                   WHEN web_exception THEN
                    RAISE web_exception;
                   WHEN OTHERS THEN
                    l_error_code:= SUBSTR(SQLERRM,1,100);
                    dbms_lock.sleep(l_retry_count*10);
                    l_retry_count := l_retry_count+1;
                    l_error_msg   := 'Retry: '||(l_retry_count-1)||' as it failed to connect';
                    UPDATE matrix_out
                       SET error_msg     = l_error_msg
                     WHERE sys_msg_id    = l_sys_msg_id;
                  END;

               ELSE

                l_error_msg   := 'Failed All the Retry Attempts, see error code';
                RAISE web_exception;

               END IF;

            END LOOP;
    -------------------Updating the Record Status in Matrix_out---------------------

            BEGIN
              UPDATE matrix_out
                 SET record_status = 'S'
               WHERE sys_msg_id = l_sys_msg_id;
              COMMIT;
            EXCEPTION
             WHEN OTHERS THEN
              l_error_msg := 'Error: Updating to Success';
              l_error_code:= SUBSTR(SQLERRM,1,100);
              RAISE web_exception;
            END;

         END IF;

      END LOOP;

   END IF;

EXCEPTION
WHEN web_exception THEN
  UPDATE matrix_out
     SET record_status = 'F',
         error_msg     = l_error_msg,
         error_code    = l_error_code
   WHERE sys_msg_id    = l_sys_msg_id;
  -- insert into log_test values(1,l_error_msg);
  COMMIT;
WHEN OTHERS THEN
 l_error_code := SUBSTR(SQLERRM,1,100);
  UPDATE matrix_out
     SET record_status = 'F',
         error_msg     = 'Unknown Error: See Error_code',
         error_code    = l_error_code
   WHERE sys_msg_id    = l_sys_msg_id;
  -- insert into log_test values(1,l_error_msg);
  COMMIT;
END sys08_pallet_update;

PROCEDURE sys09_bulk_request(
    i_sys_msg_id IN NUMBER DEFAULT NULL)
  /*===========================================================================================================
  -- Procedure
  -- sys09_bulk_request
  --
  -- Description
  --   This procedure is to send a particular sys_msg_id data to symbotic.
  --   This procedure is used to pack the SYS09 data that is going out to symbotic.
  --
  -- Modification History
  --
  -- Date                User                  Version            Defect  Comment
  -- 12/10/14        Sunil Ontipalli             1.0              Initial Creation
  ============================================================================================================*/
IS
  ------------------------------soap_api parameters-----------------------------
  l_request           soap_api.t_request;
  l_response          soap_api.t_response;
  --l_return            VARCHAR2(32767);
  l_url               VARCHAR2(100);
  l_namespace         VARCHAR2(1000);
  l_method            VARCHAR2(100);
  l_soap_action       VARCHAR2(100);
  --l_result_name       VARCHAR2(32767);
  --------------------------------Local Variables-------------------------------
  l_xml               XMLTYPE;
  l_xml_build         CLOB;
  l_sys_msg_id        NUMBER(10):= NULL;
  l_timestamp         VARCHAR2(100);
  l_record_status     VARCHAR2(1);
  web_exception       EXCEPTION;
  l_error_msg         VARCHAR2(2000);
  l_error_code        VARCHAR2(100);
  l_retry_count       NUMBER;
  l_count             NUMBER;
  l_interface_flag    VARCHAR2(1);
  l_reason            VARCHAR2(100);
  CURSOR c_sys_msg_id
         IS
  SELECT DISTINCT(sys_msg_id)
    FROM matrix_out
   WHERE interface_ref_doc = 'SYS09'
     AND record_status     = 'N'
     AND (add_date   <  systimestamp - 2/(24*60) OR i_sys_msg_id IS NOT NULL)
     AND sys_msg_id = NVL(i_sys_msg_id, sys_msg_id);

BEGIN

   check_webservice(i_interface_ref_doc  => 'SYS09',
                    o_active_flag        => l_interface_flag,
                    o_url_port           => l_url,
                    o_reason             => l_reason);

   IF l_interface_flag = 'Y' THEN

     FOR i IN c_sys_msg_id
      LOOP
       EXIT WHEN c_sys_msg_id%NOTFOUND;
    -----------------------Initializing the local variables-------------------------
        l_sys_msg_id := i.sys_msg_id;
        l_timestamp  := TO_CHAR(SYSTIMESTAMP,'YYYY-MM-DD HH24:MI:SS');
    ---------------------------Getting the Record status----------------------------
         BEGIN
           SELECT DISTINCT(record_status)
             INTO l_record_status
             FROM matrix_out
            WHERE sys_msg_id = l_sys_msg_id;
         EXCEPTION
          WHEN OTHERS THEN
           l_error_msg  := 'Error: Getting the Record Status';
           l_error_code := SUBSTR(SQLERRM,1,100);
           RAISE web_exception;
         END;
    -----------Checking Whether the Status is 'N' and Locking the Record------------
         IF UPPER(l_record_status) = 'N' THEN

            BEGIN
              UPDATE matrix_out
                 SET record_status = 'Q'
               WHERE sys_msg_id  = l_sys_msg_id
                 AND record_status = 'N';
              COMMIT;
            EXCEPTION
             WHEN OTHERS THEN
              ROLLBACK;
              l_error_msg := 'Error: Updating the Record status to Q';
              l_error_code:= SUBSTR(SQLERRM,1,100);
              RAISE web_exception;
            END;
    -----------------------Generating the XML for Webservice------------------------
            BEGIN

               SELECT  XMLELEMENT("metadata",
                        XMLFOREST(l_sys_msg_id AS "MessageId",
                                  l_timestamp  AS "RequestDateTime")
                                  )
                 INTO l_xml
                 FROM dual;
            EXCEPTION
             WHEN OTHERS THEN
              l_error_msg := 'Error: Generating the XML 1';
              l_error_code:= SUBSTR(SQLERRM,1,100);
              RAISE web_exception;
            END;

            l_xml_build := l_xml.getstringval();
            l_xml := NULL;

            BEGIN
              SELECT XMLFOREST('DET_INV_RECON'   AS "messageName")
                INTO l_xml
                FROM dual;
            EXCEPTION
             WHEN OTHERS THEN
              l_error_msg := 'Error: Generating the XML 2';
              l_error_code:= SUBSTR(SQLERRM,1,100);
              RAISE web_exception;
            END;

            l_xml_build := l_xml_build||l_xml.getstringval();

            l_xml  := NULL;

            l_xml_build := '<BulkRequest>'||l_xml_build||'</BulkRequest>';

            l_xml_build := replace(l_xml_build, '<','<sym:');
            l_xml_build := replace(l_xml_build, '<sym:/','</sym:');

            l_retry_count := 1;

            LOOP

               IF l_retry_count < 4 THEN

                  BEGIN

    ---------------------Initilaizing the Webservice Parameters---------------------
                     --l_url         := 'http://10.254.4.130:7800/CaseManager';
                     l_namespace   := 'xmlns:sym="Symbotic" xmlns:arr="http://schemas.microsoft.com/2003/10/Serialization/Arrays"';
                     --l_method      := 'tns:AddPalletInput';
                     l_soap_action := 'Symbotic/ICaseManager/BulkRequest';
                     --l_result_name := 'ROWSET';
    --------------------------Initiating the Webservice Call------------------------
                     l_request := soap_api.new_request(p_method         => l_method,
                                                       p_namespace      => l_namespace,
                                                       p_envelope_tag   => 'soapenv');
    -------------------------Passing the XML Parameter------------------------------
                     soap_api.add_complex_parameter(p_request => l_request,
                                                    p_xml     => l_xml_build);

                     soap_api.debug_on();
    ------------------------------Getting the Response------------------------------
                     l_response := soap_api.invoke(p_request => l_request,
                                                   p_url     => l_url,
                                                   p_action  => l_soap_action);
    -----------------------------Verifying the Response-----------------------------
                     l_xml_build := l_response.doc.getstringval();

                     l_count     := INSTR(l_xml_build,'<s:Fault>',1);

                       IF l_count != 0 THEN
                         l_xml_build := SUBSTR (l_xml_build,INSTR(l_xml_build,'<s:Fault>')+9,INSTR(l_xml_build,'</s:Fault>')-INSTR(l_xml_build,'<s:Fault>')-9);
                         l_error_msg := SUBSTR(l_xml_build,1,2000);
                         l_error_code:= 'SEE ERROR MSG';
                         RAISE web_exception;
                       END IF;

                     EXIT;

                  EXCEPTION
                   WHEN web_exception THEN
                    RAISE web_exception;
                   WHEN OTHERS THEN
                    l_error_code:= SUBSTR(SQLERRM,1,100);
                    dbms_lock.sleep(l_retry_count*10);
                    l_retry_count := l_retry_count+1;
                    l_error_msg   := 'Retry: '||(l_retry_count-1)||' as it failed to connect';
                    UPDATE matrix_out
                       SET error_msg     = l_error_msg
                     WHERE sys_msg_id    = l_sys_msg_id;
                  END;

               ELSE

                l_error_msg   := 'Failed All the Retry Attempts, see error code';
                RAISE web_exception;

               END IF;

            END LOOP;
    -------------------Updating the Record Status in Matrix_out---------------------

            BEGIN
              UPDATE matrix_out
                 SET record_status = 'S'
               WHERE sys_msg_id = l_sys_msg_id;
              COMMIT;
            EXCEPTION
             WHEN OTHERS THEN
              ROLLBACK;
              l_error_msg := 'Error: Updating to Success';
              l_error_code:= SUBSTR(SQLERRM,1,100);
              RAISE web_exception;
            END;

         END IF;

      END LOOP;

   END IF;

EXCEPTION
WHEN web_exception THEN
  UPDATE matrix_out
     SET record_status = 'F',
         error_msg     = l_error_msg,
         error_code    = l_error_code
   WHERE sys_msg_id    = l_sys_msg_id;
  COMMIT;
WHEN OTHERS THEN
 l_error_code := SUBSTR(SQLERRM,1,100);
  UPDATE matrix_out
     SET record_status = 'F',
         error_msg     = 'Unknown Error: See Error_code',
         error_code    = l_error_code
   WHERE sys_msg_id    = l_sys_msg_id;
  COMMIT;
END sys09_bulk_request;

PROCEDURE sys10_bulk_notification(
    i_sys_msg_id IN NUMBER DEFAULT NULL)
  /*===========================================================================================================
  -- Procedure
  -- sys10_bulk_notification
  --
  -- Description
  --   This procedure is to send a particular sys_msg_id data to symbotic.
  --   This procedure is used to pack the SYS10 data that is going out to symbotic.
  --
  -- Modification History
  --
  -- Date                User                  Version            Defect  Comment
  -- 12/1/14        Sunil Ontipalli             1.0              Initial Creation
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
  CURSOR c_sys_msg_id
         IS
  SELECT DISTINCT(sys_msg_id)
    FROM matrix_out
   WHERE interface_ref_doc = 'SYS10'
     AND record_status     = 'N'
     AND (add_date   <  systimestamp - 2/(24*60) OR i_sys_msg_id IS NOT NULL)
     AND sys_msg_id = NVL(i_sys_msg_id, sys_msg_id);

BEGIN

   check_webservice(i_interface_ref_doc  => 'SYS10',
                    o_active_flag        => l_interface_flag,
                    o_url_port           => l_url,
                    o_reason             => l_reason);

   IF l_interface_flag = 'Y' THEN

     FOR i IN c_sys_msg_id
      LOOP
       EXIT WHEN c_sys_msg_id%NOTFOUND;
    -----------------------Initializing the local variables-------------------------
        l_sys_msg_id := i.sys_msg_id;
        l_timestamp  := TO_CHAR(SYSTIMESTAMP,'YYYY-MM-DD HH24:MI:SS');
    ---------------------------Getting the Record status----------------------------
         BEGIN
           SELECT DISTINCT(record_status)
             INTO l_record_status
             FROM matrix_out
            WHERE sys_msg_id = l_sys_msg_id;
         EXCEPTION
          WHEN OTHERS THEN
           l_error_msg  := 'Error: Getting the Record Status';
           l_error_code := SUBSTR(SQLERRM,1,100);
           RAISE web_exception;
         END;
    -----------Checking Whether the Status is 'N' and Locking the Record------------
         IF UPPER(l_record_status) = 'N' THEN
            BEGIN
              UPDATE matrix_out
                 SET record_status = 'Q'
               WHERE sys_msg_id  = l_sys_msg_id
                 AND record_status = 'N';
              COMMIT;
            EXCEPTION
             WHEN OTHERS THEN
              ROLLBACK;
              l_error_msg := 'Error: Updating the Record status to Q';
              l_error_code:= SUBSTR(SQLERRM,1,100);
              RAISE web_exception;
            END;
    -----------------------Generating the XML for Webservice------------------------
            BEGIN

               SELECT  XMLELEMENT("metadata",
                        XMLFOREST(l_sys_msg_id AS "MessageId",
                                  l_timestamp  AS "RequestDateTime")
                              )
                 INTO l_xml
                 FROM dual;
            EXCEPTION
             WHEN OTHERS THEN
              l_error_msg := 'Error: Generating the XML 1';
              l_error_code:= SUBSTR(SQLERRM,1,100);
              RAISE web_exception;
            END;

            l_xml_build := l_xml.getstringval();
            l_xml := NULL;

            BEGIN
               SELECT XMLFOREST('SUCCESS'                      AS "messageStatus",---hard coding for now needed clarity
                                'DET_ITEM_RECON'               AS "messageName",  ---hard coding for now needed clarity
                                nvl(mo.file_timestamp,' ')     AS "fileTimestamp",
                                nvl(mo.file_name,' ')          AS "fileName",
                                nvl(mo.rec_count,0)            AS "rowCount")
                 INTO l_xml
                 FROM matrix_out mo
                WHERE sys_msg_id = l_sys_msg_id
                  AND (rec_ind    = 'H' or rec_ind = 'S');
            EXCEPTION
             WHEN OTHERS THEN
              l_error_msg := 'Error: Generating the XML 2';
              l_error_code:= SUBSTR(SQLERRM,1,100);
              RAISE web_exception;
            END;

            l_xml_build := l_xml_build||l_xml.getstringval();

            l_xml  := NULL;

            l_xml_build := '<BulkNotification>'||l_xml_build||'</BulkNotification>';

            l_xml_build := replace(l_xml_build, '<','<sym:');
            l_xml_build := replace(l_xml_build, '<sym:/','</sym:');

            l_retry_count := 1;

            LOOP

               IF l_retry_count < 4 THEN

                   BEGIN

    ---------------------Initilaizing the Webservice Parameters---------------------
                      --l_url         := 'http://10.254.4.130:7800/CaseManager';
                      l_namespace   := 'xmlns:sym="Symbotic" xmlns:arr="http://schemas.microsoft.com/2003/10/Serialization/Arrays"';
                      --l_method      := 'tns:AddPalletInput';
                      l_soap_action := 'Symbotic/ICaseManager/BulkNotification';
                      --l_result_name := 'ROWSET';
    --------------------------Initiating the Webservice Call------------------------
                      l_request := soap_api.new_request(p_method         => l_method,
                                                        p_namespace      => l_namespace,
                                                        p_envelope_tag   => 'soapenv');
    -------------------------Passing the XML Parameter------------------------------
                      soap_api.add_complex_parameter(p_request => l_request,
                                                     p_xml     => l_xml_build);

                      soap_api.debug_on();
    ------------------------------Getting the Response------------------------------
                      l_response := soap_api.invoke(p_request => l_request,
                                                    p_url     => l_url,
                                                    p_action  => l_soap_action);
    -----------------------------Verifying the Response-----------------------------
                      l_xml_build := l_response.doc.getstringval();

                      l_count     := INSTR(l_xml_build,'<s:Fault>',1);

                        IF l_count != 0 THEN
                          l_xml_build := SUBSTR (l_xml_build,INSTR(l_xml_build,'<s:Fault>')+9,INSTR(l_xml_build,'</s:Fault>')-INSTR(l_xml_build,'<s:Fault>')-9);
                          l_error_msg := SUBSTR(l_xml_build,1,2000);
                          l_error_code:= 'SEE ERROR MSG';
                          RAISE web_exception;
                        END IF;

                      EXIT;

                   EXCEPTION
                    WHEN web_exception THEN
                     RAISE web_exception;
                    WHEN OTHERS THEN
                     l_error_code:= SUBSTR(SQLERRM,1,100);
                     dbms_lock.sleep(l_retry_count*10);
                     l_retry_count := l_retry_count+1;
                     l_error_msg   := 'Retry: '||(l_retry_count-1)||' as it failed to connect';
                     UPDATE matrix_out
                        SET error_msg     = l_error_msg
                      WHERE sys_msg_id    = l_sys_msg_id;
                   END;

               ELSE

                l_error_msg   := 'Failed All the Retry Attempts, see error code';
                RAISE web_exception;

               END IF;

            END LOOP;
    -------------------Updating the Record Status in Matrix_out---------------------

            BEGIN
               UPDATE matrix_out
                  SET record_status = 'S'
                WHERE sys_msg_id = l_sys_msg_id;
               COMMIT;
            EXCEPTION
             WHEN OTHERS THEN
              ROLLBACK;
              l_error_msg := 'Error: Updating to Success';
              l_error_code:= SUBSTR(SQLERRM,1,100);
              RAISE web_exception;
            END;

         END IF;

      END LOOP;

   END IF;

EXCEPTION
WHEN web_exception THEN
  UPDATE matrix_out
     SET record_status = 'F',
         error_msg     = l_error_msg,
         error_code    = l_error_code
   WHERE sys_msg_id    = l_sys_msg_id;
  COMMIT;
WHEN OTHERS THEN
 l_error_code := SUBSTR(SQLERRM,1,100);
  UPDATE matrix_out
     SET record_status = 'F',
         error_msg     = 'Unknown Error: See Error_code',
         error_code    = l_error_code
   WHERE sys_msg_id    = l_sys_msg_id;
  COMMIT;
END sys10_bulk_notification;

PROCEDURE sys11_update_batch_priority(
    i_sys_msg_id IN NUMBER DEFAULT NULL)
  /*===========================================================================================================
  -- Procedure
  -- sys11_update_batch_priority
  --
  -- Description
  --   This procedure is to send a particular sys_msg_id data to symbotic.
  --   This procedure is used to pack the SYS11 data that is going out to symbotic.
  --
  -- Modification History
  --
  -- Date                User                  Version            Defect  Comment
  -- 11/03/14        Sunil Ontipalli             1.0              Initial Creation
  ============================================================================================================*/
IS
------------------------------soap_api parameters-----------------------------
  l_request           soap_api.t_request;
  l_response          soap_api.t_response;
  --l_return            VARCHAR2(32767);
  l_url               VARCHAR2(100);
  l_namespace         VARCHAR2(1000);
  l_method            VARCHAR2(100);
  l_soap_action       VARCHAR2(100);
  --l_result_name       VARCHAR2(32767);
  --------------------------------Local Variables-------------------------------
  l_xml               XMLTYPE;
  l_xml_build         CLOB;
  l_sys_msg_id        NUMBER(10):= NULL;
  l_timestamp         VARCHAR2(100);
  l_record_status     VARCHAR2(1);
  web_exception       EXCEPTION;
  l_error_msg         VARCHAR2(2000);
  l_error_code        VARCHAR2(100);
  l_count             NUMBER;
  l_retry_count       NUMBER;
  l_interface_flag    VARCHAR2(1);
  l_reason            VARCHAR2(100);
  CURSOR c_sys_msg_id
         IS
  SELECT DISTINCT(sys_msg_id)
    FROM matrix_out
   WHERE interface_ref_doc = 'SYS11'
     AND record_status     = 'N'
     AND (add_date   <  systimestamp - 1/(24*60) OR i_sys_msg_id IS NOT NULL)
     AND sys_msg_id = NVL(i_sys_msg_id, sys_msg_id);

BEGIN

   check_webservice(i_interface_ref_doc  => 'SYS11',
                    o_active_flag        => l_interface_flag,
                    o_url_port           => l_url,
                    o_reason             => l_reason);

   IF l_interface_flag = 'Y' THEN

     FOR i IN c_sys_msg_id
      LOOP

       EXIT WHEN c_sys_msg_id%NOTFOUND;
    -----------------------Initializing the local variables-------------------------
        l_sys_msg_id := i.sys_msg_id;
        l_timestamp  := TO_CHAR(SYSTIMESTAMP,'YYYY-MM-DD HH24:MI:SS');
    ---------------------------Getting the Record status----------------------------
         BEGIN

          SELECT DISTINCT(record_status)
            INTO l_record_status
            FROM matrix_out
           WHERE sys_msg_id = l_sys_msg_id;
         EXCEPTION
          WHEN OTHERS THEN
          l_error_msg := 'Error: Getting the Record Status';
          RAISE web_exception;
         END;
    -----------Checking Whether the Status is 'N' and Locking the Record------------
         IF UPPER(l_record_status) = 'N' THEN

            BEGIN

              UPDATE matrix_out
                 SET record_status = 'Q'
               WHERE sys_msg_id  = l_sys_msg_id
                 AND record_status = 'N';
              COMMIT;
            EXCEPTION
             WHEN OTHERS THEN
              l_error_msg := 'Error: Updating the Record status to Q';
              l_error_code:= SUBSTR(SQLERRM,1,100);
              RAISE web_exception;
            END;
    -----------------------Generating the XML for Webservice------------------------
            BEGIN

               SELECT  XMLELEMENT("metadata",
                        XMLFOREST(l_sys_msg_id AS "MessageId",
                                  l_timestamp  AS "RequestDateTime")
                                  )
                 INTO l_xml
                 FROM dual;
            EXCEPTION
             WHEN OTHERS THEN
              l_error_msg := 'Error: Generating the XML 1';
              l_error_code:= SUBSTR(SQLERRM,1,100);
              RAISE web_exception;
            END;

            l_xml_build := l_xml.getstringval();
            l_xml       := NULL;

            BEGIN

              SELECT XMLFOREST (nvl(mo.batch_id,' ')                                 AS "batchId",
                                nvl(mo.priority, 0)                                  AS "priority"
                                )
                          INTO l_xml
                          FROM matrix_out mo
                         WHERE sys_msg_id = l_sys_msg_id
                           AND rec_ind = 'S';
            EXCEPTION
             WHEN OTHERS THEN
              l_error_msg := 'Error: Generating the XML 2';
              l_error_code:= SUBSTR(SQLERRM,1,100);
              RAISE web_exception;
            END;

            l_xml_build := l_xml_build||l_xml.getstringval();

            l_xml  := NULL;

            l_xml_build := '<UpdateOrderBatch>'||l_xml_build||'</UpdateOrderBatch>';

            l_xml_build := replace(l_xml_build, '<','<sym:');
            l_xml_build := replace(l_xml_build, '<sym:/','</sym:');
            l_xml_build := replace(l_xml_build, '<sym:string','<arr:string');
            l_xml_build := replace(l_xml_build, '</sym:string', '</arr:string' );


            l_retry_count := 1;

            LOOP

               IF l_retry_count < 4 THEN

                   BEGIN

    ---------------------Initilaizing the Webservice Parameters---------------------
                       --l_url         := 'http://10.254.4.130:7800/CaseManager';
                       l_namespace   := 'xmlns:sym="Symbotic" xmlns:arr="http://schemas.microsoft.com/2003/10/Serialization/Arrays"';
                       --l_method      := 'tns:AddPalletInput';
                       l_soap_action := 'Symbotic/ICaseManager/UpdateOrderBatch';
                       --l_result_name := 'ROWSET';
    --------------------------Initiating the Webservice Call------------------------
                       l_request := soap_api.new_request(p_method         => l_method,
                                                         p_namespace      => l_namespace,
                                                         p_envelope_tag   => 'soapenv');
    -------------------------Passing the XML Parameter------------------------------
                       soap_api.add_complex_parameter(p_request => l_request,
                                                      p_xml     => l_xml_build);

                       soap_api.debug_on();
    ------------------------------Getting the Response------------------------------
                       l_response := soap_api.invoke(p_request => l_request,
                                                     p_url     => l_url,
                                                     p_action  => l_soap_action);
    -----------------------------Verifying the Response-----------------------------
                       l_xml_build := l_response.doc.getstringval();

                       l_count     := INSTR(l_xml_build,'<s:Fault>',1);

                          IF l_count != 0 THEN
                            l_xml_build := SUBSTR (l_xml_build,INSTR(l_xml_build,'<s:Fault>')+9,INSTR(l_xml_build,'</s:Fault>')-INSTR(l_xml_build,'<s:Fault>')-9);
                            l_error_msg := SUBSTR(l_xml_build,1,2000);
                            l_error_code:= 'SEE ERROR MSG';
                            RAISE web_exception;
                          END IF;

                        EXIT;

                   EXCEPTION
                    WHEN web_exception THEN
                     RAISE web_exception;
                    WHEN OTHERS THEN
                     l_error_code:= SUBSTR(SQLERRM,1,100);
                     dbms_lock.sleep(l_retry_count*10);
                     l_retry_count := l_retry_count+1;
                     l_error_msg   := 'Retry: '||(l_retry_count-1)||' as it failed to connect';
                     UPDATE matrix_out
                        SET error_msg     = l_error_msg
                      WHERE sys_msg_id    = l_sys_msg_id;
                   END;

               ELSE

                l_error_msg   := 'Failed All the Retry Attempts, see error code';
                RAISE web_exception;

               END IF;

            END LOOP;
    -------------------Updating the Record Status in Matrix_out---------------------

            BEGIN

              UPDATE matrix_out
                 SET record_status = 'S'
               WHERE sys_msg_id = l_sys_msg_id;
              COMMIT;
            EXCEPTION
             WHEN OTHERS THEN
              l_error_msg := 'Error: Updating to Success';
              l_error_code:= SUBSTR(SQLERRM,1,100);
              RAISE web_exception;
            END;

         END IF;

      END LOOP;

   END IF;
EXCEPTION
WHEN web_exception THEN
  UPDATE matrix_out
     SET record_status = 'F',
         error_msg     = l_error_msg,
         error_code    = l_error_code
   WHERE sys_msg_id    = l_sys_msg_id;
  -- insert into log_test values(1,l_error_msg);
  COMMIT;
WHEN OTHERS THEN
 l_error_code := SUBSTR(SQLERRM,1,100);
  UPDATE matrix_out
     SET record_status = 'F',
         error_msg     = 'Unknown Error: See Error_code',
         error_code    = l_error_code
   WHERE sys_msg_id    = l_sys_msg_id;
  -- insert into log_test values(1,l_error_msg);
  COMMIT;
END sys11_update_batch_priority;

PROCEDURE sys12_cancel_order_batch(
    i_sys_msg_id IN NUMBER DEFAULT NULL)
  /*===========================================================================================================
  -- Procedure
  -- sys12_cancel_order_batch
  --
  -- Description
  --   This procedure is to send a particular sys_msg_id data to symbotic.
  --   This procedure is used to pack the SYS11 data that is going out to symbotic.
  --
  -- Modification History
  --
  -- Date                User                  Version            Defect  Comment
  -- 11/03/14        Sunil Ontipalli             1.0              Initial Creation
  ============================================================================================================*/
IS
------------------------------soap_api parameters-----------------------------
  l_request           soap_api.t_request;
  l_response          soap_api.t_response;
  --l_return            VARCHAR2(32767);
  l_url               VARCHAR2(100);
  l_namespace         VARCHAR2(1000);
  l_method            VARCHAR2(100);
  l_soap_action       VARCHAR2(100);
  --l_result_name       VARCHAR2(32767);
  --------------------------------Local Variables-------------------------------
  l_xml               XMLTYPE;
  l_xml_build         CLOB;
  l_sys_msg_id        NUMBER(10):= NULL;
  l_timestamp         VARCHAR2(100);
  l_record_status     VARCHAR2(1);
  web_exception       EXCEPTION;
  l_error_msg         VARCHAR2(2000);
  l_error_code        VARCHAR2(100);
  l_count             NUMBER;
  l_retry_count       NUMBER;
  l_interface_flag    VARCHAR2(1);
  l_reason            VARCHAR2(100);
  CURSOR c_sys_msg_id
         IS
  SELECT DISTINCT(sys_msg_id)
    FROM matrix_out
   WHERE interface_ref_doc = 'SYS12'
     AND record_status     = 'N'
     AND (add_date   <  systimestamp - 1/(24*60) OR i_sys_msg_id IS NOT NULL)
     AND sys_msg_id = NVL(i_sys_msg_id, sys_msg_id);

BEGIN

   check_webservice(i_interface_ref_doc  => 'SYS12',
                    o_active_flag        => l_interface_flag,
                    o_url_port           => l_url,
                    o_reason             => l_reason);

   IF l_interface_flag = 'Y' THEN

    FOR i IN c_sys_msg_id
      LOOP
       EXIT WHEN c_sys_msg_id%NOTFOUND;
    -----------------------Initializing the local variables-------------------------
        l_sys_msg_id := i.sys_msg_id;
        l_timestamp  := TO_CHAR(SYSTIMESTAMP,'YYYY-MM-DD HH24:MI:SS');
    ---------------------------Getting the Record status----------------------------
          BEGIN
            SELECT DISTINCT(record_status)
              INTO l_record_status
              FROM matrix_out
             WHERE sys_msg_id = l_sys_msg_id;
          EXCEPTION
           WHEN OTHERS THEN
            l_error_msg := 'Error: Getting the Record Status';
            RAISE web_exception;
          END;
    -----------Checking Whether the Status is 'N' and Locking the Record------------
          IF UPPER(l_record_status) = 'N' THEN

             BEGIN
               UPDATE matrix_out
                  SET record_status = 'Q'
                WHERE sys_msg_id  = l_sys_msg_id
                  AND record_status = 'N';
               COMMIT;
             EXCEPTION
              WHEN OTHERS THEN
               l_error_msg := 'Error: Updating the Record status to Q';
               l_error_code:= SUBSTR(SQLERRM,1,100);
               RAISE web_exception;
             END;
    -----------------------Generating the XML for Webservice------------------------
             BEGIN

               SELECT  XMLELEMENT("metadata",
                        XMLFOREST(l_sys_msg_id AS "MessageId",
                                  l_timestamp  AS "RequestDateTime")
                                  )
                 INTO l_xml
                 FROM dual;
             EXCEPTION
              WHEN OTHERS THEN
               l_error_msg := 'Error: Generating the XML 1';
               l_error_code:= SUBSTR(SQLERRM,1,100);
               RAISE web_exception;
             END;

             l_xml_build := l_xml.getstringval();
             l_xml       := NULL;

             BEGIN

               SELECT XMLFOREST (nvl(mo.batch_id,' ')                                 AS "batchId"
                                 )
                           INTO l_xml
                           FROM matrix_out mo
                          WHERE sys_msg_id = l_sys_msg_id
                            AND rec_ind = 'S';
             EXCEPTION
              WHEN OTHERS THEN
               l_error_msg := 'Error: Generating the XML 2';
               l_error_code:= SUBSTR(SQLERRM,1,100);
               RAISE web_exception;
             END;

             l_xml_build := l_xml_build||l_xml.getstringval();

             l_xml  := NULL;

             l_xml_build := '<CancelOrderBatch>'||l_xml_build||'</CancelOrderBatch>';

             l_xml_build := replace(l_xml_build, '<','<sym:');
             l_xml_build := replace(l_xml_build, '<sym:/','</sym:');
             l_xml_build := replace(l_xml_build, '<sym:string','<arr:string');
             l_xml_build := replace(l_xml_build, '</sym:string', '</arr:string' );


             l_retry_count := 1;

             LOOP

                IF l_retry_count < 4 THEN

                    BEGIN

    ---------------------Initilaizing the Webservice Parameters---------------------
                       --l_url         := 'http://10.254.4.130:7800/CaseManager';
                       l_namespace   := 'xmlns:sym="Symbotic" xmlns:arr="http://schemas.microsoft.com/2003/10/Serialization/Arrays"';
                       --l_method      := 'tns:AddPalletInput';
                       l_soap_action := 'Symbotic/ICaseManager/CancelOrderBatch';
                       --l_result_name := 'ROWSET';
    --------------------------Initiating the Webservice Call------------------------
                       l_request := soap_api.new_request(p_method         => l_method,
                                                         p_namespace      => l_namespace,
                                                         p_envelope_tag   => 'soapenv');
    -------------------------Passing the XML Parameter------------------------------
                       soap_api.add_complex_parameter(p_request => l_request,
                                                      p_xml     => l_xml_build);

                       soap_api.debug_on();
    ------------------------------Getting the Response------------------------------
                       l_response := soap_api.invoke(p_request => l_request,
                                                     p_url     => l_url,
                                                     p_action  => l_soap_action);
    -----------------------------Verifying the Response-----------------------------
                       l_xml_build := l_response.doc.getstringval();

                       l_count     := INSTR(l_xml_build,'<s:Fault>',1);

                       IF l_count != 0 THEN
                         l_xml_build := SUBSTR (l_xml_build,INSTR(l_xml_build,'<s:Fault>')+9,INSTR(l_xml_build,'</s:Fault>')-INSTR(l_xml_build,'<s:Fault>')-9);
                         l_error_msg := SUBSTR(l_xml_build,1,2000);
                         l_error_code:= 'SEE ERROR MSG';
                         RAISE web_exception;
                       END IF;

                     EXIT;

                    EXCEPTION
                     WHEN web_exception THEN
                      RAISE web_exception;
                     WHEN OTHERS THEN
                      l_error_code:= SUBSTR(SQLERRM,1,100);
                      dbms_lock.sleep(l_retry_count*10);
                      l_retry_count := l_retry_count+1;
                      l_error_msg   := 'Retry: '||(l_retry_count-1)||' as it failed to connect';
                     UPDATE matrix_out
                        SET error_msg     = l_error_msg
                      WHERE sys_msg_id    = l_sys_msg_id;
                    END;

                ELSE

                 l_error_msg   := 'Failed All the Retry Attempts, see error code';
                 RAISE web_exception;

                END IF;

             END LOOP;
    -------------------Updating the Record Status in Matrix_out---------------------

             BEGIN
               UPDATE matrix_out
                  SET record_status = 'S'
                WHERE sys_msg_id = l_sys_msg_id;
               COMMIT;
             EXCEPTION
              WHEN OTHERS THEN
               l_error_msg := 'Error: Updating to Success';
               l_error_code:= SUBSTR(SQLERRM,1,100);
               RAISE web_exception;
             END;

          END IF;

      END LOOP;

   END IF;

EXCEPTION
WHEN web_exception THEN
  UPDATE matrix_out
     SET record_status = 'F',
         error_msg     = l_error_msg,
         error_code    = l_error_code
   WHERE sys_msg_id    = l_sys_msg_id;
  -- insert into log_test values(1,l_error_msg);
  COMMIT;
WHEN OTHERS THEN
 l_error_code := SUBSTR(SQLERRM,1,100);
  UPDATE matrix_out
     SET record_status = 'F',
         error_msg     = 'Unknown Error: See Error_code',
         error_code    = l_error_code
   WHERE sys_msg_id    = l_sys_msg_id;
  -- insert into log_test values(1,l_error_msg);
  COMMIT;
END sys12_cancel_order_batch;

PROCEDURE sys13_cancel_order_detail(
    i_sys_msg_id IN NUMBER DEFAULT NULL)
  /*===========================================================================================================
  -- Procedure
  -- sys13_cancel_order_detail
  --
  -- Description
  --   This procedure is to send a particular sys_msg_id data to symbotic.
  --   This procedure is used to pack the SYS11 data that is going out to symbotic.
  --
  -- Modification History
  --
  -- Date                User                  Version            Defect  Comment
  -- 11/03/14        Sunil Ontipalli             1.0              Initial Creation
  ============================================================================================================*/
IS
------------------------------soap_api parameters-----------------------------
  l_request           soap_api.t_request;
  l_response          soap_api.t_response;
  --l_return            VARCHAR2(32767);
  l_url               VARCHAR2(100);
  l_namespace         VARCHAR2(1000);
  l_method            VARCHAR2(100);
  l_soap_action       VARCHAR2(100);
  --l_result_name       VARCHAR2(32767);
  --------------------------------Local Variables-------------------------------
  l_xml               XMLTYPE;
  l_xml_build         CLOB;
  l_sys_msg_id        NUMBER(10):= NULL;
  l_timestamp         VARCHAR2(100);
  l_record_status     VARCHAR2(1);
  web_exception       EXCEPTION;
  l_error_msg         VARCHAR2(2000);
  l_error_code        VARCHAR2(100);
  l_count             NUMBER;
  l_retry_count       NUMBER;
  l_interface_flag    VARCHAR2(1);
  l_reason            VARCHAR2(100);
  CURSOR c_sys_msg_id
         IS
  SELECT DISTINCT(sys_msg_id)
    FROM matrix_out
   WHERE interface_ref_doc = 'SYS13'
     AND record_status     = 'N'
     AND (add_date   <  systimestamp - 1/(24*60) OR i_sys_msg_id IS NOT NULL)
     AND sys_msg_id = NVL(i_sys_msg_id, sys_msg_id);

BEGIN

   check_webservice(i_interface_ref_doc  => 'SYS13',
                    o_active_flag        => l_interface_flag,
                    o_url_port           => l_url,
                    o_reason             => l_reason);

   IF l_interface_flag = 'Y' THEN

    FOR i IN c_sys_msg_id
      LOOP
       EXIT WHEN c_sys_msg_id%NOTFOUND;
    -----------------------Initializing the local variables-------------------------
        l_sys_msg_id := i.sys_msg_id;
        l_timestamp  := TO_CHAR(SYSTIMESTAMP,'YYYY-MM-DD HH24:MI:SS');
    ---------------------------Getting the Record status----------------------------
          BEGIN
            SELECT DISTINCT(record_status)
              INTO l_record_status
              FROM matrix_out
             WHERE sys_msg_id = l_sys_msg_id;
          EXCEPTION
           WHEN OTHERS THEN
            l_error_msg := 'Error: Getting the Record Status';
            RAISE web_exception;
          END;
    -----------Checking Whether the Status is 'N' and Locking the Record------------
          IF UPPER(l_record_status) = 'N' THEN

             BEGIN
               UPDATE matrix_out
                  SET record_status = 'Q'
                WHERE sys_msg_id  = l_sys_msg_id
                  AND record_status = 'N';
               COMMIT;
             EXCEPTION
              WHEN OTHERS THEN
               l_error_msg := 'Error: Updating the Record status to Q';
               l_error_code:= SUBSTR(SQLERRM,1,100);
               RAISE web_exception;
             END;
    -----------------------Generating the XML for Webservice------------------------
             BEGIN

                SELECT  XMLELEMENT("metadata",
                         XMLFOREST(l_sys_msg_id AS "MessageId",
                                   l_timestamp  AS "RequestDateTime")
                                   )
                  INTO l_xml
                  FROM dual;
             EXCEPTION
              WHEN OTHERS THEN
               l_error_msg := 'Error: Generating the XML 1';
               l_error_code:= SUBSTR(SQLERRM,1,100);
               RAISE web_exception;
             END;

             l_xml_build := l_xml.getstringval();
             l_xml       := NULL;

             BEGIN
                SELECT XMLFOREST (nvl(mo.batch_id,' ')                                 AS "batchId",
                                  nvl(mo.order_id,' ')                                 AS "orderId")
                  INTO l_xml
                  FROM matrix_out mo
                 WHERE sys_msg_id = l_sys_msg_id
                   AND (rec_ind = 'H' or rec_ind = 'S');

             EXCEPTION
              WHEN OTHERS THEN
               l_error_msg := 'Error: Generating the XML 2';
               l_error_code:= SUBSTR(SQLERRM,1,100);
               RAISE web_exception;
             END;

             l_xml_build := l_xml_build||l_xml.getstringval();

             l_xml  := NULL;

             BEGIN

               SELECT XMLELEMENT("cancelOrderSkuDetails",
                       XMLAGG(XMLELEMENT("CancelOrderSkuDetail",
                                XMLFOREST(nvl(mo.prod_id,' ')                                AS "ItemId",
                                          nvl(mo.case_qty,0)                                 AS "CaseQuantity"
                                          )
                                         )
                               )
                                  )
                 INTO l_xml
                 FROM matrix_out mo
                WHERE sys_msg_id     = l_sys_msg_id
                  AND record_status != 'H';
             EXCEPTION
              WHEN OTHERS THEN
               l_error_msg := 'Error: Generating the XML 3';
               l_error_code:= SUBSTR(SQLERRM,1,100);
               RAISE web_exception;
             END;

             l_xml_build := '<CancelOrderDetail>'||l_xml_build||l_xml.getstringval()||'</CancelOrderDetail>';

             l_xml_build := replace(l_xml_build, '<','<sym:');
             l_xml_build := replace(l_xml_build, '<sym:/','</sym:');
             l_xml_build := replace(l_xml_build, '<sym:string','<arr:string');
             l_xml_build := replace(l_xml_build, '</sym:string', '</arr:string' );


             l_retry_count := 1;

             LOOP

                IF l_retry_count < 4 THEN

                    BEGIN

    ---------------------Initilaizing the Webservice Parameters---------------------
                        --l_url         := 'http://10.254.4.130:7800/CaseManager';
                        l_namespace   := 'xmlns:sym="Symbotic" xmlns:arr="http://schemas.microsoft.com/2003/10/Serialization/Arrays"';
                        --l_method      := 'tns:AddPalletInput';
                        l_soap_action := 'Symbotic/ICaseManager/CancelOrderDetail';
                        --l_result_name := 'ROWSET';
    --------------------------Initiating the Webservice Call------------------------
                        l_request := soap_api.new_request(p_method         => l_method,
                                                          p_namespace      => l_namespace,
                                                          p_envelope_tag   => 'soapenv');
    -------------------------Passing the XML Parameter------------------------------
                        soap_api.add_complex_parameter(p_request => l_request,
                                                       p_xml     => l_xml_build);

                        soap_api.debug_on();
    ------------------------------Getting the Response------------------------------
                       l_response := soap_api.invoke(p_request => l_request,
                                                     p_url     => l_url,
                                                     p_action  => l_soap_action);
    -----------------------------Verifying the Response-----------------------------
                       l_xml_build := l_response.doc.getstringval();

                       l_count     := INSTR(l_xml_build,'<s:Fault>',1);

                          IF l_count != 0 THEN
                            l_xml_build := SUBSTR (l_xml_build,INSTR(l_xml_build,'<s:Fault>')+9,INSTR(l_xml_build,'</s:Fault>')-INSTR(l_xml_build,'<s:Fault>')-9);
                            l_error_msg := SUBSTR(l_xml_build,1,2000);
                            l_error_code:= 'SEE ERROR MSG';
                            RAISE web_exception;
                          END IF;

                     EXIT;

                    EXCEPTION
                     WHEN web_exception THEN
                      RAISE web_exception;
                     WHEN OTHERS THEN
                      l_error_code:= SUBSTR(SQLERRM,1,100);
                      dbms_lock.sleep(l_retry_count*10);
                      l_retry_count := l_retry_count+1;
                      l_error_msg   := 'Retry: '||(l_retry_count-1)||' as it failed to connect';
                      UPDATE matrix_out
                         SET error_msg     = l_error_msg
                       WHERE sys_msg_id    = l_sys_msg_id;
                    END;

                ELSE

                 l_error_msg   := 'Failed All the Retry Attempts, see error code';
                 RAISE web_exception;

                END IF;

             END LOOP;
    -------------------Updating the Record Status in Matrix_out---------------------

             BEGIN
              UPDATE matrix_out
                 SET record_status = 'S'
               WHERE sys_msg_id = l_sys_msg_id;
              COMMIT;
             EXCEPTION
              WHEN OTHERS THEN
               l_error_msg := 'Error: Updating to Success';
               l_error_code:= SUBSTR(SQLERRM,1,100);
               RAISE web_exception;
             END;

          END IF;

      END LOOP;

   END IF;

EXCEPTION
WHEN web_exception THEN
  UPDATE matrix_out
     SET record_status = 'F',
         error_msg     = l_error_msg,
         error_code    = l_error_code
   WHERE sys_msg_id    = l_sys_msg_id;
  -- insert into log_test values(1,l_error_msg);
  COMMIT;
WHEN OTHERS THEN
 l_error_code := SUBSTR(SQLERRM,1,100);
  UPDATE matrix_out
     SET record_status = 'F',
         error_msg     = 'Unknown Error: See Error_code',
         error_code    = l_error_code
   WHERE sys_msg_id    = l_sys_msg_id;
  -- insert into log_test values(1,l_error_msg);
  COMMIT;
END sys13_cancel_order_detail;

PROCEDURE sys14_add_order_detail(
    i_sys_msg_id IN NUMBER DEFAULT NULL)
  /*===========================================================================================================
  -- Procedure
  -- sys14_add_order_detail
  --
  -- Description
  --   This procedure is to send a particular sys_msg_id data to symbotic.
  --   This procedure is used to pack the SYS14 data that is going out to symbotic.
  --
  -- Modification History
  --
  -- Date                User                  Version            Defect  Comment
  -- 10/09/14        Sunil Ontipalli             1.0              Initial Creation
  ============================================================================================================*/
IS
  ------------------------------soap_api parameters-----------------------------
  l_request           soap_api.t_request;
  l_response          soap_api.t_response;
  --l_return            VARCHAR2(32767);
  l_url               VARCHAR2(100);
  l_namespace         VARCHAR2(1000);
  l_method            VARCHAR2(100);
  l_soap_action       VARCHAR2(100);
  --l_result_name       VARCHAR2(32767);
  --------------------------------Local Variables-------------------------------
  l_xml               XMLTYPE;
  l_xml_build         CLOB;
  l_xml_build1        CLOB;
  l_xml_build2        CLOB;
  l_xml_build3        CLOB;
  l_xml_build4        CLOB;
  l_xml_build5        CLOB;
  l_xml_build6        CLOB;
  l_sys_msg_id        NUMBER(10):= NULL;
  l_timestamp         VARCHAR2(100);
  l_record_status     VARCHAR2(1);
  web_exception       EXCEPTION;
  l_error_msg         VARCHAR2(2000);
  l_error_code        VARCHAR2(100);
  l_count             NUMBER;
  l_retry_count       NUMBER;
  l_interface_flag    VARCHAR2(1);
  l_reason            VARCHAR2(100);
   CURSOR c_sys_msg_id
         IS
  SELECT DISTINCT(sys_msg_id)
    FROM matrix_out
   WHERE interface_ref_doc = 'SYS14'
     AND record_status     = 'N'
     AND (add_date   <  systimestamp - 1/(24*60) OR i_sys_msg_id IS NOT NULL)
     AND sys_msg_id = NVL(i_sys_msg_id, sys_msg_id);

BEGIN

   check_webservice(i_interface_ref_doc  => 'SYS14',
                    o_active_flag        => l_interface_flag,
                    o_url_port           => l_url,
                    o_reason             => l_reason);

   IF l_interface_flag = 'Y' THEN

    FOR i IN c_sys_msg_id
      LOOP
       EXIT WHEN c_sys_msg_id%NOTFOUND;
    -----------------------Initializing the local variables-------------------------
        l_sys_msg_id := i.sys_msg_id;
        l_timestamp  := TO_CHAR(SYSTIMESTAMP,'YYYY-MM-DD HH24:MI:SS');
    ---------------------------Getting the Record status----------------------------
         BEGIN
           SELECT DISTINCT(record_status)
             INTO l_record_status
             FROM matrix_out
            WHERE sys_msg_id = l_sys_msg_id;
         EXCEPTION
          WHEN OTHERS THEN
           l_error_msg := 'Error: Getting the Record Status';
           RAISE web_exception;
         END;
    -----------Checking Whether the Status is 'N' and Locking the Record------------
         IF UPPER(l_record_status) = 'N' THEN

            BEGIN
              UPDATE matrix_out
                 SET record_status = 'Q'
               WHERE sys_msg_id  = l_sys_msg_id
                 AND record_status = 'N';
              COMMIT;
            EXCEPTION
             WHEN OTHERS THEN
              l_error_msg := 'Error: Updating the Record status to Q';
              l_error_code:= SUBSTR(SQLERRM,1,100);
              RAISE web_exception;
            END;
    -----------------------Generating the XML for Webservice------------------------
            BEGIN

              SELECT  XMLELEMENT("metadata",
                       XMLFOREST(l_sys_msg_id AS "MessageId",
                                 l_timestamp  AS "RequestDateTime")
                              )
                INTO l_xml
                FROM dual;
            EXCEPTION
             WHEN OTHERS THEN
              l_error_msg := 'Error: Generating the XML 1';
              l_error_code:= SUBSTR(SQLERRM,1,100);
              RAISE web_exception;
            END;

            l_xml_build := l_xml.getstringval();
            l_xml       := NULL;

            BEGIN
              SELECT XMLFOREST (nvl(mo.batch_id,0)  AS "batchId"
                                )
                          INTO l_xml
                          FROM matrix_out mo
                         WHERE sys_msg_id = l_sys_msg_id
                           AND rec_ind    = 'H';
            EXCEPTION
             WHEN OTHERS THEN
              l_error_msg := 'Error: Generating the XML 2';
              l_error_code:= SUBSTR(SQLERRM,1,100);
              RAISE web_exception;
            END;

            l_xml_build := l_xml_build||l_xml.getstringval();

            l_xml  := NULL;

            FOR I IN (SELECT DISTINCT(order_id)
                        FROM matrix_out
                       WHERE sys_msg_id     = l_sys_msg_id
                         AND rec_ind       != 'H')
            LOOP

                BEGIN

                  SELECT XMLFOREST (nvl(mo.order_id,' ')  AS "OrderId"
                            )
                    INTO l_xml
                    FROM matrix_out mo
                   WHERE order_id   = I.order_id
                     AND rownum     < 2;
                EXCEPTION
                 WHEN OTHERS THEN
                  l_error_msg := 'Error: Generating the XML 3';
                  l_error_code:= SUBSTR(SQLERRM,1,100);
                  RAISE web_exception;
                END;

                l_xml_build2  := l_xml.getstringval();

                l_xml  := NULL;

                FOR J IN (SELECT sequence_number
                            FROM matrix_out
                           WHERE sys_msg_id     = l_sys_msg_id
                             AND order_id       = I.order_id
                             AND rec_ind       != 'H')
                LOOP

                   BEGIN

                      SELECT XMLFOREST(nvl(mo.prod_id,' ')           AS "ItemId",
                                       nvl(mo.case_qty,0)            AS "CaseQuantity",
                                       nvl(mo.float_id,0)            AS "FloatId",
                                       nvl(mo.pallet_id,' ')         AS "RequestedSourcePallet",
                                       nvl(mo.exact_pallet_imp,' ')  AS "ExactPalletImportance"
                                       )


                        INTO l_xml
                        FROM matrix_out mo
                       WHERE sequence_number = J.sequence_number;

                   EXCEPTION
                    WHEN OTHERS THEN
                     l_error_msg := 'Error: Generating the XML 4';
                     l_error_code:= SUBSTR(SQLERRM,1,100);
                     RAISE web_exception;
                   END;

                   l_xml_build4  := l_xml.getstringval();

                   l_xml  := NULL;

                   FOR K IN (SELECT rowid
                               FROM matrix_out_label
                              WHERE sequence_number = J.sequence_number)
                      LOOP

                          BEGIN

                               SELECT XMLELEMENT("string",nvl(barcode,' ')
                                       )
                                 INTO l_xml
                                 FROM matrix_out_label
                                WHERE rowid = K.rowid;

                          EXCEPTION
                           WHEN OTHERS THEN
                            l_error_msg := 'Error: Generating the XML 5';
                            l_error_code:= SUBSTR(SQLERRM,1,100);
                            RAISE web_exception;
                          END;

                          IF l_xml_build5 IS NULL THEN

                             l_xml_build5  := l_xml.getstringval();
                          ELSE
                             l_xml_build5  := l_xml_build5||l_xml.getstringval();
                          END IF;

                        l_xml  := NULL;

                      END LOOP;

                      l_xml_build5 := '<CaseBarcode>'||l_xml_build5||'</CaseBarcode>';

                     FOR K IN (SELECT rowid
                                 FROM matrix_out_label
                                WHERE sequence_number = J.sequence_number)
                      LOOP

                         BEGIN

                           SELECT XMLELEMENT("string",nvl(encoded_print_stream,' ')
                                      )
                             INTO l_xml
                             FROM matrix_out_label
                            WHERE rowid = K.rowid;

                         EXCEPTION
                          WHEN OTHERS THEN
                           l_error_msg := 'Error: Generating the XML 6';
                           l_error_code:= SUBSTR(SQLERRM,1,100);
                           RAISE web_exception;
                         END;

                         IF l_xml_build6 IS NULL THEN

                          l_xml_build6  := l_xml.getstringval();
                         ELSE
                          l_xml_build6  := l_xml_build6||l_xml.getstringval();
                         END IF;

                        l_xml  := NULL;

                      END LOOP;

                      l_xml_build6 := '<CaseLabels>'||l_xml_build6||'</CaseLabels>';

                      l_xml_build4 :=  l_xml_build4||l_xml_build5||l_xml_build6;
                      l_xml_build5 :=  NULL;
                      l_xml_build6 :=  NULL;
                      l_xml_build4 := '<OrderSkuDetail>'||l_xml_build4||'</OrderSkuDetail>';

                      IF l_xml_build3 IS NULL THEN

                         l_xml_build3  := l_xml_build4;
                      ELSE
                         l_xml_build3  := l_xml_build3||l_xml_build4;
                      END IF;

                      l_xml_build4 :=  NULL;
                END LOOP;

                l_xml_build3  := '<OrderSkuDetails>'||l_xml_build3||'</OrderSkuDetails>';

                l_xml_build2  := l_xml_build2||l_xml_build3;

                l_xml_build3  := NULL;

                l_xml_build2  := '<AddOrderBatchOrderDetail>'||l_xml_build2||'</AddOrderBatchOrderDetail>';

                 IF l_xml_build1 IS NULL THEN

                    l_xml_build1  := l_xml_build2;
                 ELSE
                    l_xml_build1  := l_xml_build1||l_xml_build2;
                 END IF;

                l_xml_build2  := NULL;

            END LOOP;

            l_xml_build1:= '<addOrderBatchOrderDetails>'||l_xml_build1||'</addOrderBatchOrderDetails>';
            l_xml_build :=  l_xml_build||l_xml_build1;
            l_xml_build := '<AddOrderBatchDetail>'||l_xml_build||'</AddOrderBatchDetail>';


            l_xml_build := replace(l_xml_build, '<','<sym:');
            l_xml_build := replace(l_xml_build, '<sym:/','</sym:');
            l_xml_build := replace(l_xml_build, '<sym:string','<arr:string');
            l_xml_build := replace(l_xml_build, '</sym:string', '</arr:string' );

           /*INSERT
               INTO test_table
             VALUES (l_xml_build);
            COMMIT;*/

           l_retry_count := 1;

           LOOP

              IF l_retry_count < 4 THEN

                 BEGIN

    ---------------------Initilaizing the Webservice Parameters---------------------
                     --l_url         := 'http://10.254.4.130:7800/CaseManager';
                     l_namespace   := 'xmlns:sym="Symbotic" xmlns:arr="http://schemas.microsoft.com/2003/10/Serialization/Arrays"';
                     --l_method      := 'tns:AddPalletInput';
                     l_soap_action := 'Symbotic/ICaseManager/AddOrderBatchDetail';
                     --l_result_name := 'ROWSET';
    --------------------------Initiating the Webservice Call------------------------
                     l_request := soap_api.new_request(p_method         => l_method,
                                                       p_namespace      => l_namespace,
                                                       p_envelope_tag   => 'soapenv');
    -------------------------Passing the XML Parameter------------------------------
                     soap_api.add_complex_parameter(p_request => l_request,
                                                    p_xml     => l_xml_build);

                     soap_api.debug_on();
    ------------------------------Getting the Response------------------------------
                     l_response := soap_api.invoke(p_request => l_request,
                                                   p_url     => l_url,
                                                   p_action  => l_soap_action);
    -----------------------------Verifying the Response-----------------------------
                     l_xml_build := l_response.doc.getstringval();

                     l_count     := INSTR(l_xml_build,'<s:Fault>',1);

                       IF l_count != 0 THEN
                         l_xml_build := SUBSTR (l_xml_build,INSTR(l_xml_build,'<s:Fault>')+9,INSTR(l_xml_build,'</s:Fault>')-INSTR(l_xml_build,'<s:Fault>')-9);
                         l_error_msg := SUBSTR(l_xml_build,1,2000);
                         l_error_code:= 'SEE ERROR MSG';
                         RAISE web_exception;
                       END IF;
                     EXIT;

                 EXCEPTION
                  WHEN web_exception THEN
                   RAISE web_exception;
                  WHEN OTHERS THEN
                   l_error_code:= SUBSTR(SQLERRM,1,100);
                   dbms_lock.sleep(l_retry_count*10);
                   l_retry_count := l_retry_count+1;
                   l_error_msg   := 'Retry: '||(l_retry_count-1)||' as it failed to connect';
                   UPDATE matrix_out
                      SET error_msg     = l_error_msg
                    WHERE sys_msg_id    = l_sys_msg_id;
                 END;

              ELSE
               l_error_msg   := 'Failed All the Retry Attempts, see error code';
               RAISE web_exception;
              END IF;

           END LOOP;
    -------------------Updating the Record Status in Matrix_out---------------------

           BEGIN
              UPDATE matrix_out
                 SET record_status = 'S'
               WHERE sys_msg_id = l_sys_msg_id;
              COMMIT;
           EXCEPTION
            WHEN OTHERS THEN
             l_error_msg := 'Error: Updating to Success';
             l_error_code:= SUBSTR(SQLERRM,1,100);
             RAISE web_exception;
           END;

         END IF;

      END LOOP;

   END IF;

EXCEPTION
WHEN web_exception THEN
  UPDATE matrix_out
     SET record_status = 'F',
         error_msg     = l_error_msg,
         error_code    = l_error_code
   WHERE sys_msg_id    = l_sys_msg_id;
  -- insert into log_test values(1,l_error_msg);
  COMMIT;
WHEN OTHERS THEN
 l_error_code := SUBSTR(SQLERRM,1,100);
  UPDATE matrix_out
     SET record_status = 'F',
         error_msg     = 'Unknown Error: See Error_code',
         error_code    = l_error_code
   WHERE sys_msg_id    = l_sys_msg_id;
  -- insert into log_test values(1,l_error_msg);
  COMMIT;
END sys14_add_order_detail;

PROCEDURE sys15_wave_status(
    i_sys_msg_id IN NUMBER DEFAULT NULL)
  /*===========================================================================================================
  -- Procedure
  -- sys15_wave_status
  --
  -- Description
  --   This procedure is to send a particular sys_msg_id data to symbotic.
  --   This procedure is used to pack the SYS15 data that is going out to symbotic.
  --
  -- Modification History
  --
  -- Date                User                  Version            Defect  Comment
  -- 09/11/14        Sunil Ontipalli             1.0              Initial Creation
  ============================================================================================================*/
IS
  ------------------------------soap_api parameters-----------------------------
  l_request           soap_api.t_request;
  l_response          soap_api.t_response;
  --l_return            VARCHAR2(32767);
  l_url               VARCHAR2(100);
  l_namespace         VARCHAR2(1000);
  l_method            VARCHAR2(100);
  l_soap_action       VARCHAR2(100);
  --l_result_name       VARCHAR2(32767);
  --------------------------------Local Variables-------------------------------
  l_xml               XMLTYPE;
  l_xml_build         CLOB;
  l_sys_msg_id        NUMBER(10):= NULL;
  l_timestamp         VARCHAR2(100);
  l_record_status     VARCHAR2(1);
  web_exception       EXCEPTION;
  l_error_msg         VARCHAR2(2000);
  l_error_code        VARCHAR2(100);
  l_count             NUMBER;
  l_retry_count       NUMBER;
  l_interface_flag    VARCHAR2(1);
  l_reason            VARCHAR2(100);
  CURSOR c_sys_msg_id
         IS
  SELECT DISTINCT(sys_msg_id)
    FROM matrix_out
   WHERE interface_ref_doc = 'SYS15'
     AND record_status     = 'N'
     AND (add_date   <  systimestamp - 1/(24*60) OR i_sys_msg_id IS NOT NULL)
     AND sys_msg_id = NVL(i_sys_msg_id, sys_msg_id);

BEGIN

   check_webservice(i_interface_ref_doc  => 'SYS15',
                    o_active_flag        => l_interface_flag,
                    o_url_port           => l_url,
                    o_reason             => l_reason);

   IF l_interface_flag = 'Y' THEN

     FOR i IN c_sys_msg_id
      LOOP
       EXIT WHEN c_sys_msg_id%NOTFOUND;
    -----------------------Initializing the local variables-------------------------
        l_sys_msg_id := i.sys_msg_id;
        l_timestamp  := TO_CHAR(SYSTIMESTAMP,'YYYY-MM-DD HH24:MI:SS');
    ---------------------------Getting the Record status----------------------------
         BEGIN
           SELECT DISTINCT(record_status)
             INTO l_record_status
             FROM matrix_out
            WHERE sys_msg_id = l_sys_msg_id;
         EXCEPTION
          WHEN OTHERS THEN
           l_error_msg := 'Error: Getting the Record Status';
           RAISE web_exception;
         END;
    -----------Checking Whether the Status is 'N' and Locking the Record------------
         IF UPPER(l_record_status) = 'N' THEN

            BEGIN
               UPDATE matrix_out
                  SET record_status = 'Q'
                WHERE sys_msg_id  = l_sys_msg_id
                  AND record_status = 'N';
               COMMIT;
            EXCEPTION
             WHEN OTHERS THEN
              l_error_msg := 'Error: Updating the Record status to Q';
              l_error_code:= SUBSTR(SQLERRM,1,100);
              RAISE web_exception;
            END;
    -----------------------Generating the XML for Webservice------------------------
            BEGIN

               SELECT  XMLELEMENT("metadata",
                        XMLFOREST(l_sys_msg_id AS "MessageId",
                                  l_timestamp  AS "RequestDateTime")
                                  )
                 INTO l_xml
                 FROM dual;
            EXCEPTION
             WHEN OTHERS THEN
              l_error_msg := 'Error: Generating the XML 1';
              l_error_code:= SUBSTR(SQLERRM,1,100);
              RAISE web_exception;
            END;

            l_xml_build := l_xml.getstringval();
            l_xml       := NULL;

            BEGIN

               SELECT XMLFOREST (nvl(mo.task_id,' ')                       AS "waveStatusID",
                                 nvl(mo.wave_number,0)                   AS "waveNumber",
                                 nvl(mo.batch_status,' ')                  AS "waveStatus"
                                  )
                           INTO l_xml
                           FROM matrix_out mo
                          WHERE sys_msg_id = l_sys_msg_id
                            AND rec_ind    = 'S';
            EXCEPTION
             WHEN OTHERS THEN
              l_error_msg := 'Error: Generating the XML 2';
              l_error_code:= SUBSTR(SQLERRM,1,100);
              RAISE web_exception;
            END;

            l_xml_build := l_xml_build||l_xml.getstringval();

            l_xml  := NULL;

            l_xml_build := '<NotifyWaveStatusChanged>'||l_xml_build||'</NotifyWaveStatusChanged>';

            l_xml_build := replace(l_xml_build, '<','<sym:');
            l_xml_build := replace(l_xml_build, '<sym:/','</sym:');
            l_xml_build := replace(l_xml_build, '<sym:string','<arr:string');
            l_xml_build := replace(l_xml_build, '</sym:string', '</arr:string' );

           /*INSERT
               INTO test_table1
             VALUES (l_xml);
             COMMIT;*/

            l_retry_count := 1;

            LOOP

               IF l_retry_count < 4 THEN

                  BEGIN

    ---------------------Initilaizing the Webservice Parameters---------------------
                     --l_url         := 'http://10.254.4.130:7800/CaseManager';
                     l_namespace   := 'xmlns:sym="Symbotic" xmlns:arr="http://schemas.microsoft.com/2003/10/Serialization/Arrays"';
                     --l_method      := 'tns:AddPalletInput';
                     l_soap_action := 'Symbotic/ICaseManager/NotifyWaveStatusChanged';
                     --l_result_name := 'ROWSET';
    --------------------------Initiating the Webservice Call------------------------
                     l_request := soap_api.new_request(p_method         => l_method,
                                                       p_namespace      => l_namespace,
                                                       p_envelope_tag   => 'soapenv');
    -------------------------Passing the XML Parameter------------------------------
                     soap_api.add_complex_parameter(p_request => l_request,
                                                    p_xml     => l_xml_build);

                     soap_api.debug_on();
    ------------------------------Getting the Response------------------------------
                     l_response := soap_api.invoke(p_request => l_request,
                                                   p_url     => l_url,
                                                   p_action  => l_soap_action);
    -----------------------------Verifying the Response-----------------------------
                     l_xml_build := l_response.doc.getstringval();

                     l_count     := INSTR(l_xml_build,'<s:Fault>',1);

                       IF l_count != 0 THEN
                         l_xml_build := SUBSTR (l_xml_build,INSTR(l_xml_build,'<s:Fault>')+9,INSTR(l_xml_build,'</s:Fault>')-INSTR(l_xml_build,'<s:Fault>')-9);
                         l_error_msg := SUBSTR(l_xml_build,1,2000);
                         l_error_code:= 'SEE ERROR MSG';
                         RAISE web_exception;
                       END IF;

                     EXIT;

                  EXCEPTION
                   WHEN web_exception THEN
                    RAISE web_exception;
                   WHEN OTHERS THEN
                    l_error_code:= SUBSTR(SQLERRM,1,100);
                    dbms_lock.sleep(l_retry_count*10);
                    l_retry_count := l_retry_count+1;
                    l_error_msg   := 'Retry: '||(l_retry_count-1)||' as it failed to connect';
                    UPDATE matrix_out
                       SET error_msg     = l_error_msg
                     WHERE sys_msg_id    = l_sys_msg_id;
                  END;

               ELSE
                l_error_msg   := 'Failed All the Retry Attempts, see error code';
                RAISE web_exception;
               END IF;

            END LOOP;

    -------------------Updating the Record Status in Matrix_out---------------------

            BEGIN
              UPDATE matrix_out
                 SET record_status = 'S'
               WHERE sys_msg_id = l_sys_msg_id;
              COMMIT;
            EXCEPTION
             WHEN OTHERS THEN
              l_error_msg := 'Error: Updating to Success';
              l_error_code:= SUBSTR(SQLERRM,1,100);
              RAISE web_exception;
            END;

         END IF;

      END LOOP;

   END IF;

EXCEPTION
WHEN web_exception THEN
  UPDATE matrix_out
     SET record_status = 'F',
         error_msg     = l_error_msg,
         error_code    = l_error_code
   WHERE sys_msg_id    = l_sys_msg_id;
  -- insert into log_test values(1,l_error_msg);
  COMMIT;
WHEN OTHERS THEN
 l_error_code := SUBSTR(SQLERRM,1,100);
  UPDATE matrix_out
     SET record_status = 'F',
         error_msg     = 'Unknown Error: See Error_code',
         error_code    = l_error_code
   WHERE sys_msg_id    = l_sys_msg_id;
  -- insert into log_test values(1,l_error_msg);
  COMMIT;
END sys15_wave_status;

PROCEDURE generate_pm_bulk_file
  /*===========================================================================================================
  -- Procedure
  -- generate_pm_bulk_file
  --
  -- Description
  --   1)This procedure generates a bulk file seeded from pm table and also inserts the data into
  --   matrix_pm_bulk_out table for debugging purposes.
  --   2) This procedure also creates a record for SYS10 bulk notification.
  --
  -- Modification History
  --
  -- Date                User                  Version            Defect  Comment
  -- 11/14/14        Sunil Ontipalli             1.0              Initial Creation
  ============================================================================================================*/
IS
  --------------------------------Local Variables-------------------------------
  l_file              UTL_FILE.FILE_TYPE;
  l_file_name         VARCHAR2(100);
  l_file_timestamp    VARCHAR2(50);
  l_clob              VARCHAR2(10000);
  l_length            NUMBER;
  l_count             NUMBER := 0;
  TYPE l_pm_table IS TABLE OF pm%ROWTYPE;
  l_bulk_data         l_pm_table;
  l_var               VARCHAR2(5);
  l_var1              VARCHAR2(5);
  l_var2              VARCHAR2(5);
  l_var3              VARCHAR2(5);
  l_prod_id           VARCHAR2(10);
  l_upc               VARCHAR2(100);
  l_sys_msg_id        NUMBER;
  l_exp_window        NUMBER;
  l_descrip_new       VARCHAR2(50);
  l_host_call         VARCHAR2(1000);
  l_case_length       VARCHAR2(10);
  l_case_width        VARCHAR2(10);
  l_case_height       VARCHAR2(10);
  l_case_weight       VARCHAR2(10);
  CURSOR c_get_all_data
      IS
        SELECT *
          FROM pm
         WHERE area
            IN (
                SELECT
              DISTINCT z_area_code
                  FROM zone
                 WHERE rule_id = 5);
  CURSOR c_upc
      IS
        SELECT DISTINCT(external_upc)
          FROM pm_upc a
         WHERE prod_id = l_prod_id
          AND NOT EXISTS( SELECT 1 
                            FROM pm_upc b
                           WHERE b.prod_id != a.prod_id
                             AND b.external_upc = a.external_upc);

BEGIN

--l_file := UTL_FILE.fopen('SYMBOTIC',l_file_name,'w');

 l_sys_msg_id := MX_SYS_MSG_ID_SEQ.NEXTVAL();

 l_file_name  := 'Item_master_'||l_sys_msg_id||'.txt';

----------------opening a file to write using utl file procedure----------------
 l_file := UTL_FILE.fopen('SYMBOTIC',l_file_name,'w');



-----------------Bulk collecting the data into a collection----------------------

 OPEN c_get_all_data;

 LOOP

   FETCH c_get_all_data BULK COLLECT INTO  l_bulk_data LIMIT 1000;

   EXIT WHEN c_get_all_data%NOTFOUND;
   
       FOR i IN l_bulk_data.FIRST..l_bulk_data.LAST
        LOOP

         l_prod_id      := l_bulk_data(i).prod_id;
         l_var          := CASE WHEN l_bulk_data(i).mx_upc_present_flag     = 'Y' THEN 'Y' ELSE 'N' END;
         l_var1         := CASE WHEN l_bulk_data(i).mx_multi_upc_problem    = 'Y' THEN 'Y' ELSE 'N' END;
         l_var2         := CASE WHEN l_bulk_data(i).mx_eligible             = 'Y' THEN 'Y' ELSE 'N' END;
         l_var3         := CASE WHEN l_bulk_data(i).mx_stability_flag       = 'Y' THEN 'Y' ELSE 'N' END;
         l_descrip_new  := l_bulk_data(i).brand||'_'||l_bulk_data(i).pack||'/'||l_bulk_data(i).prod_size||'_'||l_bulk_data(i).descrip;

            BEGIN
              SELECT nvl(mft.mx_days_rotate_allow,0)
                INTO l_exp_window
                FROM mx_food_type mft, pm
               WHERE mft.mx_food_type = pm.mx_food_type
                 AND pm.prod_id       = l_prod_id ;
            EXCEPTION
             WHEN OTHERS THEN
             NULL;
              --pl_text_log.ins_msg('INFO', 'pl_xml_matrix_out.generate_pm_bulk_file',
                   --  'Error Getting the mx_days_rotate_allow from mx_food_type',
                   --   SQLCODE, SQLERRM);
              --RAISE;
            END;
-------------Inserting the data into bulk table for debugging puposes-----------

                   BEGIN
                        INSERT
                          INTO matrix_pm_bulk_out
                               (sys_msg_id, rec_ind, prod_id, description, area,
                                pack, prod_size, prod_size_unit, mx_designate_slot, case_length, case_width,
                                case_height, case_weight, mx_upc_present_flag,-- upc,
                                mx_multi_upc_problem, mx_hazardous_type, mx_food_type, mx_eligible,
                                expiration_window, mx_tip_over_flag)
                        VALUES (l_sys_msg_id, 'H', l_bulk_data(i).prod_id, l_descrip_new, l_bulk_data(i).area,
                                l_bulk_data(i).pack, l_bulk_data(i).prod_size, l_bulk_data(i).prod_size_unit, nvl(l_bulk_data(i).mx_designate_slot,'NOT_MS_SLOTTED'),
                                l_bulk_data(i).case_length, l_bulk_data(i).case_width, l_bulk_data(i).case_height, (l_bulk_data(i).g_weight*l_bulk_data(i).spc),
                                l_var, l_var1, l_bulk_data(i).mx_hazardous_type, l_bulk_data(i).mx_food_type, l_var2, l_exp_window, l_var3);
                   EXCEPTION
                    WHEN OTHERS THEN
                     pl_text_log.ins_msg('INFO', 'pl_xml_matrix_out.generate_pm_bulk_file',
                     'Error Inserting Header in Matrix_pm_bulk_out',
                      NULL, NULL);
                       RAISE;
                   END;

           FOR J IN c_upc
             LOOP

                   BEGIN
                        INSERT
                          INTO matrix_pm_bulk_out(sys_msg_id, rec_ind,prod_id, upc)
                        VALUES (l_sys_msg_id, 'D', l_prod_id, J.external_upc);
                   EXCEPTION
                    WHEN OTHERS THEN
                     pl_text_log.ins_msg('INFO', 'pl_xml_matrix_out.generate_pm_bulk_file',
                     'Error Inserting Detail in Matrix_pm_bulk_out',
                      NULL, NULL);
                       RAISE;
                   END;

                   IF l_upc IS NULL THEN
                    l_upc     := LPAD(nvl(J.external_upc, ' '),14,' ');
                   ELSE
                    l_upc     := l_upc||LPAD(nvl(J.external_upc, ' '),14,' ');
                   END IF;

             END LOOP;
-------Writing the line data into a variable and passing to utl_file proc-------
             l_case_length  := TRIM(CASE WHEN INSTR(TO_CHAR(nvl(l_bulk_data(i).case_length,0)),'.') = 0 THEN TO_CHAR(nvl(l_bulk_data(i).case_length,0),'99999990.9') ELSE TO_CHAR (nvl(l_bulk_data(i).case_length,0)) END);
             l_case_width   := TRIM(CASE WHEN INSTR(TO_CHAR(nvl(l_bulk_data(i).case_width,0)),'.') = 0 THEN TO_CHAR(nvl(l_bulk_data(i).case_width,0),'99999990.9') ELSE TO_CHAR (nvl(l_bulk_data(i).case_width,0)) END);
             l_case_height  := TRIM(CASE WHEN INSTR(TO_CHAR(nvl(l_bulk_data(i).case_height,0)),'.') = 0 THEN TO_CHAR(nvl(l_bulk_data(i).case_height,0),'99999990.9') ELSE TO_CHAR (nvl(l_bulk_data(i).case_height,0)) END);
             l_case_weight  := TRIM(CASE WHEN INSTR(TO_CHAR(nvl(l_bulk_data(i).g_weight*l_bulk_data(i).spc,0)),'.') = 0 THEN TO_CHAR(nvl(l_bulk_data(i).g_weight*l_bulk_data(i).spc,0),'99999990.9') ELSE TO_CHAR (nvl(l_bulk_data(i).g_weight*l_bulk_data(i).spc,0)) END);

         l_clob    := RPAD(nvl(l_bulk_data(i).prod_id,' '),9)||RPAD(nvl(l_descrip_new,' '),50)||RPAD(nvl(l_bulk_data(i).area,' '),1)||
                      RPAD(nvl(l_bulk_data(i).pack,0),4)||RPAD(nvl(l_bulk_data(i).prod_size,' '),6)||RPAD(nvl(l_bulk_data(i).prod_size_unit, ' '),3)||
                      RPAD(nvl(l_bulk_data(i).mx_designate_slot,'NOT_MS_SLOTTED'),15)||LPAD(l_case_length,10,'0')||
                      lPAD(l_case_width,10,'0')||lPAD(l_case_height,10,'0')||
                      LPAD(l_case_weight,10,'0')||RPAD(l_var,1)||RPAD(nvl(l_upc, ' '), 70,' ')||
                      RPAD(l_var1,1)||RPAD(nvl(l_bulk_data(i).mx_hazardous_type,' '),20)||RPAD(nvl(l_bulk_data(i).mx_food_type,' '),8)||
                      RPAD(l_var2,1)||lPAD(nvl(l_exp_window,0),10,'0')||RPAD(l_var3,1);

         l_upc := NULL;
         l_count := l_count+1;

        /* -- calculating the length of the file in bytes
          IF l_length IS NULL THEN
           l_length := LENGTH(l_clob)+1;
          ELSE
           l_length := l_length + LENGTH(l_clob)+1;
          END IF;*/

         UTL_FILE.put_line(l_file, l_clob);
        END LOOP;


 END LOOP;

 CLOSE c_get_all_data;

 UTL_FILE.fclose(l_file);

--------------------Inserting the data for bulk notification--------------------

 --l_sys_msg_id := MX_SYS_MSG_ID_SEQ.NEXTVAL();
  l_file_timestamp := TO_CHAR(SYSTIMESTAMP,'YYYY-MM-DD HH24:MI:SS');

 BEGIN

   INSERT
     INTO MATRIX_OUT(sys_msg_id, rec_ind, interface_ref_doc, rec_count, file_name, file_timestamp)
   VALUES (l_sys_msg_id, 'S', 'SYS10', l_count, l_file_name, l_file_timestamp);

   COMMIT;

 EXCEPTION
  WHEN OTHERS THEN
   pl_text_log.ins_msg('INFO', 'pl_xml_matrix_out.generate_pm_bulk_file',
                     'Error Inserting record in Matrix_out',
                      NULL, NULL);
    RAISE;
 END;

 BEGIN
 
 l_host_call := DBMS_HOST_COMMAND_FUNC('swms', 'sh /swms/curr/bin/symbotic_bulk_item.sh');
 
 EXCEPTION
  WHEN OTHERS THEN
   pl_text_log.ins_msg('INFO', 'pl_xml_matrix_out.generate_pm_bulk_file',
                     'Error Calling the host Shell Program',
                      SQLCODE, SQLERRM);
    RAISE;
 END;
  --dbms_output.put_line('write done');
  --dbms_output.put_line(' the file length: '||l_length);
  --dbms_output.put_line(' the row count: '||l_count);
  --UTL_FILE.fremove('/tmp',l_file_name);
EXCEPTION
  WHEN OTHERS THEN
    -- Closing the file if something goes wrong.

    IF UTL_FILE.is_open(l_file) THEN
      UTL_FILE.fclose(l_file);
      UTL_FILE.fremove('SYMBOTIC',l_file_name);
    END IF;
    pl_text_log.ins_msg('INFO', 'pl_xml_matrix_out.generate_pm_bulk_file',
                     'Error Unknown Exception',
                      SQLCODE, SQLERRM);
    RAISE;

END generate_pm_bulk_file;

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
  -- 09/11/14        Sunil Ontipalli             1.0              Initial Creation
  ============================================================================================================*/
IS
  --------------------------------Local Variables-------------------------------
  l_sys_msg_id    NUMBER(10):= NULL;
  l_ref_doc       VARCHAR2(10);
BEGIN
-----------------------Initializing the local variables-------------------------
  l_sys_msg_id := i_sys_msg_id;
  l_ref_doc    := i_ref_doc;

    IF      l_ref_doc  = 'SYS03' THEN
        sys03_mx_inv_induct(l_sys_msg_id);
    ELSIF   l_ref_doc  = 'SYS04' THEN
        sys04_add_order(l_sys_msg_id);
    ELSIF   l_ref_doc  = 'SYS05' THEN
        sys05_internal_order(l_sys_msg_id);
    ELSIF   l_ref_doc  = 'SYS06' THEN
        sys06_spur_case_removal(l_sys_msg_id);
    ELSIF   l_ref_doc  = 'SYS07' THEN
        sys07_batch_status(l_sys_msg_id);
    ELSIF   l_ref_doc  = 'SYS08' THEN
        sys08_pallet_update(l_sys_msg_id);
    ELSIF   l_ref_doc  = 'SYS09' THEN
        sys09_bulk_request(l_sys_msg_id);
    ELSIF   l_ref_doc  = 'SYS11' THEN
        sys11_update_batch_priority(l_sys_msg_id);
    ELSIF   l_ref_doc  = 'SYS12' THEN
        sys12_cancel_order_batch(l_sys_msg_id);
    ELSIF   l_ref_doc  = 'SYS13' THEN
        sys13_cancel_order_detail(l_sys_msg_id);
    ELSIF   l_ref_doc  = 'SYS14' THEN
        sys14_add_order_detail(l_sys_msg_id);
    ELSIF   l_ref_doc  = 'SYS15' THEN
        sys15_wave_status(l_sys_msg_id);
    END IF;

END initiate_webservice;

END pl_xml_matrix_out;
/


CREATE OR REPLACE PUBLIC SYNONYM pl_xml_matrix_out FOR swms.pl_xml_matrix_out;

grant execute on swms.pl_xml_matrix_out to swms_user;

grant execute on swms.pl_xml_matrix_out to swms_mx;