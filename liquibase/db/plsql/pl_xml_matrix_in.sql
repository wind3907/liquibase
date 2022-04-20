CREATE OR REPLACE 
PACKAGE      pl_xml_matrix_in
IS
  /*===========================================================================================================
  -- Package
  -- pl_xml_matrix_in
  --
  -- Description
  --  This package is called by webservice(Symbotic).
  --  This package processes the data that is coming into Sysco via Webservice
  --  from Symbotic.
  --
  -- Modification History
  --
  -- Date                User                  Version            Defect  Comment
  -- 08/12/14        Sunil Ontipalli             1.0              Initial Creation
  -- 11/24/14        Sunil Ontipalli             1.1              Added Validations for the Data Received from Symbotic.
  -- 02/04/15        Sunil Ontipalli             1.2              Adding the new functionality to maintain the interfaces,
  --                                                              and adding the ability to switch On/Off.
  -- 04/28/15        Sunil Ontipalli             1.3              Modified case barcode as a part of requirement change.
  -- 05/06/15        Sunil Ontipalli             1.4              Modified to handle SYM17 without detail portion.
  -- 06/17/15        Sunil Ontipalli             1.5              Modified code to Store the rejected messages.
  -- 06/29/16        Scott Pinchback             1.6              Modified to not fail a SYM12 to Jackpot because it
  --                                                              has a NULL batch ID.
  ============================================================================================================*/

PROCEDURE check_webservice(i_interface_ref_doc  IN VARCHAR2,
                           o_active_flag        OUT VARCHAR2,
                           o_reason             OUT VARCHAR2);

FUNCTION sym03_mx_inv_induct(
    i_msg_time_obj           IN msg_time_obj,
    i_label_type             IN VARCHAR2,
    i_induction_type         IN VARCHAR2,
    i_parent_lpn             IN VARCHAR2,
    i_pallet_details         IN pallet_details_obj,
    o_status_msg            OUT VARCHAR2)
  RETURN NUMBER;

FUNCTION sym05_batch_ready(
    i_msg_time_obj           IN msg_time_obj,
    i_batch_id               IN VARCHAR2,
    i_sequence_timestamp     IN VARCHAR2,
    i_spur_location          IN VARCHAR2,
    o_status_msg            OUT VARCHAR2)
  RETURN NUMBER;

FUNCTION sym06_case_skipped(
    i_msg_time_obj           IN msg_time_obj,
    i_batch_id               IN VARCHAR2,
    i_case_barcode           IN VARCHAR2,
    i_sku                    IN VARCHAR2,
    i_skip_reason            IN VARCHAR2,
    o_status_msg            OUT VARCHAR2)
  RETURN NUMBER;

FUNCTION sym07_product_ready(
    i_msg_time_obj           IN msg_time_obj,
    i_sequence_timestamp     IN VARCHAR2,
    i_release_type           IN VARCHAR2,
    i_batch_id               IN VARCHAR2,
    i_spur_location          IN VARCHAR2,
    i_product_details        IN product_details_obj,
    o_status_msg            OUT VARCHAR2)
  RETURN NUMBER;

FUNCTION sym12_case_delivered_spur(
    i_msg_time_obj           IN msg_time_obj,
    i_batch_id               IN VARCHAR2,
    i_task_id                IN VARCHAR2,
    i_case_barcode           IN VARCHAR2,
    i_sku                    IN VARCHAR2,
    i_spur_location          IN VARCHAR2,
    i_licence_plate_no       IN VARCHAR2,
    i_lane_id                IN NUMBER,
    i_divert_time            IN VARCHAR2,
    i_last_case_batch        IN VARCHAR2,
    o_status_msg            OUT VARCHAR2)
  RETURN NUMBER;

FUNCTION sym15_bulk_notification(
    i_msg_time_obj           IN msg_time_obj,
    i_message_status         IN VARCHAR2,
    i_message_name           IN VARCHAR2,
    i_file_timestamp         IN VARCHAR2,
    i_file_name              IN VARCHAR2,
    i_row_count              IN NUMBER,
    o_status_msg            OUT VARCHAR2)
  RETURN NUMBER;

FUNCTION sym16_order_response(
    i_msg_time_obj           IN msg_time_obj,
    i_batch_id               IN VARCHAR2,
    i_order_resp_details     IN order_response_details_obj,
    o_status_msg            OUT VARCHAR2)
  RETURN NUMBER;

FUNCTION sym17_labor_management(
    i_msg_time_obj          IN msg_time_obj,
    i_interface_type        IN VARCHAR2,
    i_user_id               IN VARCHAR2,
    i_cell_id               IN VARCHAR2,
    i_event_timestamp       IN VARCHAR2,
    i_pallet_id_list        IN pallet_id_list_obj DEFAULT NULL,
    i_inducted_qty          IN NUMBER,
    i_reworked_qty          IN NUMBER,
    i_verified_qty          IN NUMBER,
    i_rejected_qty          IN NUMBER,
    o_status_msg           OUT VARCHAR2)
  RETURN NUMBER;

END pl_xml_matrix_in;
/


CREATE OR REPLACE 
PACKAGE BODY      pl_xml_matrix_in
IS
  /*===========================================================================================================
  -- Package Body
  -- pl_xml_matrix_in
  --
  -- Description
  --  This package is called by webservice(Symbotic).
  --  This package processes the data that is coming into Sysco via Webservice
  --  from Symbotic.
  --
  -- Modification History
  --
  -- Date                User                  Version            Defect  Comment
  -- 08/12/14        Sunil Ontipalli             1.0              Initial Creation
  -- 11/24/14        Sunil Ontipalli             1.1              Added Validations for the Data Received from Symbotic.
  -- 02/04/15        Sunil Ontipalli             1.2              Adding the new functinality to maintain the interfaces,
  --                                                              and adding the ability to switch On/Off.
  -- 04/28/15        Sunil Ontipalli             1.3              Modified case barcode as a part of requirement change.
  -- 05/06/15        Sunil Ontipalli             1.4              Modified to handle SYM17 without detail portion.
  -- 06/17/15        Sunil Ontipalli             1.5              Modified code to Store the rejected messages.
  ============================================================================================================*/
PROCEDURE check_webservice(i_interface_ref_doc  IN VARCHAR2,
                           o_active_flag        OUT VARCHAR2,
                           o_reason             OUT VARCHAR2)
/*===========================================================================================================
  -- Procedure
  -- Check Webservice
  --
  -- Description
  --   This procedure verifies whether the webservices are active or turned off.
  --
  -- Modification History
  --
  -- Date                User                  Version            Defect  Comment
  -- 02/04/15        Sunil Ontipalli             1.0              Initial Creation
  ============================================================================================================*/
IS
l_interface_ref_doc   VARCHAR2(10);
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
          pl_text_log.ins_msg('INFO', 'pl_xml_matrix_in',
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
              pl_text_log.ins_msg('INFO', 'pl_xml_matrix_in',
                     'Error Getting the Flag from matrix_interface_maint',
                      NULL, NULL);
              RAISE;---Alert
            END;

------------------Sending the Flag to Interface Accept Program------------------
            IF l_active_flag = 'Y' THEN

               o_active_flag  := 'Y';
               o_reason       := NULL;

            ELSE

               o_active_flag  := 'N';
               o_reason       := 'Interface Maintenance Flag is OFF for '||l_interface_ref_doc;

            END IF;

        ELSE

           o_active_flag  := 'N';
           o_reason       := 'Sysconfig for the Symbotic Interface is OFF';

        END IF;
END check_webservice;

FUNCTION sym03_mx_inv_induct(
    i_msg_time_obj           IN msg_time_obj,
    i_label_type             IN VARCHAR2,
    i_induction_type         IN VARCHAR2,
    i_parent_lpn             IN VARCHAR2,
    i_pallet_details         IN pallet_details_obj,
    o_status_msg            OUT VARCHAR2)
  RETURN NUMBER
  /*===========================================================================================================
  -- Function
  -- sym03_mx_inv_induct
  --
  -- Description
  --   This Function collects the SYM-03 data from Symbotic.
  --   This Function validates the data received and takes Ownership
  --   of the Request received from Symbotic.
  --
  -- Modification History
  --
  -- Date                User                  Version            Defect  Comment
  -- 08/12/14        Sunil Ontipalli             1.0              Initial Creation
  ============================================================================================================*/
IS
  --------------------------local variables-----------------------------
  l_msg_time_obj           MSG_TIME_OBJ;
  l_mx_msg_id              swms.matrix_in.mx_msg_id%TYPE;
  l_msg_time               TIMESTAMP;
  l_label_type             swms.matrix_in.label_type%type;
  l_induction_type         swms.matrix_in.trans_type%TYPE;
  l_parent_lpn             swms.matrix_in.pallet_id%TYPE;
  l_licence_plate_no       swms.matrix_in.pallet_id%TYPE;
  l_prod_id                swms.matrix_in.prod_id%TYPE;
  l_po_no                  swms.matrix_in.erm_id%TYPE;
  l_stored_time            TIMESTAMP;
  l_cases_inducted         swms.matrix_in.qty_inducted%TYPE;
  l_cases_stored           swms.matrix_in.qty_stored%TYPE;
  l_cases_damaged          swms.matrix_in.qty_damaged%TYPE;
  l_cases_out_of_tolerance swms.matrix_in.qty_out_of_tolerance%TYPE;
  l_cases_wrong_item       swms.matrix_in.qty_wrong_item%TYPE;
  l_cases_suspect          swms.matrix_in.qty_suspect%TYPE;
  l_cases_short            swms.matrix_in.qty_short%TYPE;
  l_cases_over             swms.matrix_in.qty_over%TYPE;
  l_back_table             pallet_details_table;
  l_count_no               NUMBER;
  validation_error         EXCEPTION;
  l_interface_flag         VARCHAR2(1);
  l_reason                 VARCHAR2(100);
  l_err_count              NUMBER DEFAULT 0;

BEGIN

   pl_text_log.ins_msg('INFO', 'pl_xml_matrix_in.SYM03',
                       'SYM03: Message delivery started',
                        NULL, NULL);

   check_webservice(i_interface_ref_doc  => 'SYM03',
                    o_active_flag        => l_interface_flag,
                    o_reason             => l_reason);

   IF l_interface_flag = 'Y' THEN

      ------------------Initializing the local variables-----------------------
      l_msg_time_obj           := i_msg_time_obj;
      l_label_type             := i_label_type;
      l_induction_type         := i_induction_type;
      l_parent_lpn             := i_parent_lpn;
      l_back_table             := i_pallet_details.pallet_details_data;


      -----------Extracting the object Values into the variables----------------
      l_mx_msg_id              := l_msg_time_obj.msg_meta_data(1).message_id;
      l_msg_time               := TO_TIMESTAMP(l_msg_time_obj.msg_meta_data(1).time_stamp,'YYYY-MM-DD HH24:MI:SS');


      pl_text_log.ins_msg('INFO', 'pl_xml_matrix_in.SYM03',
                       'SYM03: Printing Msg Id: '||l_mx_msg_id,
                        NULL, NULL);

      ---------------Validating the data as per the bussiness-------------------
      -------Validating Matrix message id and will not accept null values-------
      IF l_mx_msg_id  = TO_CHAR(0) THEN
        l_err_count  := l_err_count + 1;
        IF l_err_count = 1 THEN
        o_status_msg := 'FAILED: Matrix_msg_id is 0 and Invalid';
        END IF;
        --RAISE validation_error;
      ELSIF l_mx_msg_id IS NULL THEN
        l_err_count  := l_err_count + 1;
        IF l_err_count = 1 THEN
         o_status_msg    := 'FAILED: Matrix_msg_id is Null and Invalid';
        END IF;
        --RAISE validation_error;
      END IF;

      ---Validating Matrix message timestamp and will not accept null values----
      IF l_msg_time  IS NULL THEN
        l_err_count  := l_err_count + 1;
        IF l_err_count = 1 THEN
        o_status_msg := 'FAILED: Matrix_msg_timestamp is Null and Invalid';
        END IF;
        --RAISE validation_error;
      END IF;

      --Inserting the Header record with parent lpn, labeltype and induction types--

      BEGIN
        INSERT
        INTO matrix_in
          (
            mx_msg_id, msg_time, interface_ref_doc, rec_ind,
            parent_pallet_id, label_type, trans_type
          )
          VALUES
          (
            l_mx_msg_id, l_msg_time, 'SYM03', 'H',
            l_parent_lpn, l_label_type, l_induction_type
          );
      EXCEPTION
      WHEN OTHERS THEN
        ROLLBACK;
        o_status_msg:= 'FAILED: Problem Occured during Header Insert';
        RETURN 1;
      END;

      -----Taking the values from the object and validating against business-----

      FOR I IN l_back_table.first..l_back_table.last

      LOOP

          l_licence_plate_no      :=  l_back_table(I).pallet_id;
          l_po_no                 :=  l_back_table(I).erm_id;
          l_prod_id               :=  l_back_table(I).sku;
          l_stored_time           :=  TO_TIMESTAMP(l_back_table(I).stored_time,'YYYY-MM-DD HH24:MI:SS');
          l_cases_inducted        :=  l_back_table(I).cases_delivered;
          l_cases_stored          :=  l_back_table(I).cases_stored;
          l_cases_damaged         :=  l_back_table(I).cases_damaged;
          l_cases_out_of_tolerance:=  l_back_table(I).cases_oot;
          l_cases_wrong_item      :=  l_back_table(I).cases_wrong;
          l_cases_suspect         :=  l_back_table(I).cases_suspect;


          pl_text_log.ins_msg('INFO', 'pl_xml_matrix_in.SYM03',
                              'SYM03: Printing  LPN: '||l_licence_plate_no||' Printing  PROD ID: '||l_prod_id,
                               NULL, NULL);

          -------Validating License Plate No,Prod Id and must exist in SWMS---------
          BEGIN
            SELECT COUNT(*)
              INTO l_count_no
              FROM inv
             WHERE prod_id   = l_prod_id
               AND logi_loc  = l_licence_plate_no;
          EXCEPTION
          WHEN NO_DATA_FOUND THEN
            -- ROLLBACK;
            l_err_count  := l_err_count + 1;
            IF l_err_count = 1 THEN
             o_status_msg:= 'FAILED: Executing Count';
            END IF;
            --RETURN 1;
          END;
          IF l_count_no   = 0 THEN
            --ROLLBACK;
            l_err_count  := l_err_count + 1;
            IF l_err_count = 1 THEN
            o_status_msg := 'FAILED: Invalid Product Id and Licence Plate combination';
            END IF;
            --RAISE validation_error;
          END IF;

          -------Validating Stored time and will not accept null values-------------
         /* IF l_stored_time IS NULL THEN
            o_status_msg   := 'FAILED: Stored Time is Null and Invalid';
            RAISE validation_error;
          END IF;
         */
      ----Validating Cases Inducted and will not accept zero or null values-----
          IF l_cases_inducted = 0 THEN
            l_err_count  := l_err_count + 1;
            IF l_err_count = 1 THEN
            o_status_msg     := 'FAILED: Cases Delivered is 0 and Invalid';
            END IF;
            --ROLLBACK;
            --RAISE validation_error;
          ELSIF l_cases_inducted IS NULL THEN
             --ROLLBACK;
            l_err_count  := l_err_count + 1;
            IF l_err_count = 1 THEN
            o_status_msg     := 'FAILED: Cases Delivered is Null and Invalid';
            END IF;
            --RAISE validation_error;
          END IF;

          ---------------------Calculating Cases Short or Over----------------------
          l_cases_stored            := nvl(l_cases_stored,0);
          l_cases_damaged           := nvl(l_cases_damaged,0);
          l_cases_out_of_tolerance  := nvl(l_cases_out_of_tolerance,0);
          l_cases_wrong_item        := nvl(l_cases_wrong_item,0);
          l_cases_suspect           := nvl(l_cases_suspect,0);
          l_count_no                := NULL;
          l_count_no                := l_cases_stored + l_cases_damaged + l_cases_out_of_tolerance + l_cases_wrong_item + l_cases_suspect;

         /* IF l_cases_stored = 0 THEN

             l_cases_short :=0;
             l_cases_over  :=0;

          ELSE*/

               IF l_count_no          > l_cases_inducted THEN
                  l_cases_over        := l_count_no - l_cases_inducted;
                  l_cases_short       := 0;
               ELSIF l_cases_inducted > l_count_no THEN
                  l_cases_short       := l_cases_inducted - l_count_no;
                  l_cases_over        := 0;
               ELSE
                  l_cases_short :=0;
                  l_cases_over  :=0;
               END IF;

         --END IF;

          pl_text_log.ins_msg('INFO', 'pl_xml_matrix_in.SYM03',
                              'SYM03: Printing  Short Cases: '||l_cases_short||' Printing  Over cases: '||l_cases_over,
                               NULL, NULL);

      --------------------Inserting the data after validations------------------
          BEGIN
            INSERT
            INTO matrix_in
              (
                mx_msg_id, msg_time, interface_ref_doc, rec_ind,
                prod_id, pallet_id, erm_id, trans_type, stored_time,
                qty_inducted, qty_stored, qty_damaged, qty_out_of_tolerance,
                qty_wrong_item, qty_suspect, qty_short, qty_over
              )
              VALUES
              (
                l_mx_msg_id, l_msg_time, 'SYM03', 'D',
                l_prod_id, l_licence_plate_no, l_po_no, l_induction_type, l_stored_time,
                l_cases_inducted, l_cases_stored, l_cases_damaged, l_cases_out_of_tolerance,
                l_cases_wrong_item, l_cases_suspect, l_cases_short, l_cases_over
              );
          EXCEPTION
          WHEN OTHERS THEN
            ROLLBACK;
            o_status_msg:= 'FAILED: Problem Occured during Detail Insert';
            RETURN 1;
          END;

      END LOOP;

      COMMIT;
      
      IF l_err_count >= 1 THEN
        RAISE validation_error;
      END IF;  
      -------------Submitting a Job to initiate the SWMS processing----------------
      BEGIN
        dbms_scheduler.create_job
        (
          job_name        =>  'SYM03_'||l_mx_msg_id,
          job_type        =>  'PLSQL_BLOCK',
          job_action      =>  'BEGIN pl_mx_stg_to_swms.sym03_inv_update('||l_mx_msg_id||'); END;',
          start_date      =>  SYSDATE,
          enabled         =>  TRUE,
          auto_drop       =>  TRUE,
          comments        =>  'Submiting a job to invoke SYM03 webservice');
      END;
      o_status_msg:= 'SUCCESS';
      RETURN 0;

   ELSE

   o_status_msg:= 'SWMS is Currently Under Maintanance, Please Send the message Later';

   pl_text_log.ins_msg('INFO', 'pl_xml_matrix_in.SYM03',
                       'Printing: Error_msg: '||o_status_msg,
                        NULL, NULL);

   RETURN 1;

   END IF;
EXCEPTION
WHEN validation_error THEN
--ROLLBACK;
     UPDATE matrix_in
        SET record_status = 'F',
            error_msg     = o_status_msg
      WHERE mx_msg_id     = l_mx_msg_id;
    COMMIT; 

  pl_text_log.ins_msg('INFO', 'pl_xml_matrix_in.SYM03',
                       'Printing: Error_msg: '||o_status_msg,
                        NULL, NULL);
  RETURN 1;
WHEN OTHERS THEN
ROLLBACK;
  o_status_msg:= 'FAILED';

  pl_text_log.ins_msg('INFO', 'pl_xml_matrix_in.SYM03',
                       'Printing: Error_msg: '||SQLERRM,
                        NULL, NULL);

  RETURN 1;
END sym03_mx_inv_induct;

FUNCTION sym05_batch_ready(
    i_msg_time_obj           IN msg_time_obj,
    i_batch_id               IN VARCHAR2,
    i_sequence_timestamp     IN VARCHAR2,
    i_spur_location          IN VARCHAR2,
    o_status_msg            OUT VARCHAR2)
  RETURN NUMBER
 /*===========================================================================================================
  -- Function
  -- sym05_batch_ready
  --
  -- Description
  --   This Function collects the SYM-05 data from Symbotic.
  --   This Function validates the data received and takes Ownership
  --   of the Request received from Symbotic.
  --
  -- Modification History
  --
  -- Date                User                  Version            Defect  Comment
  -- 10/27/14        Sunil Ontipalli             1.0              Initial Creation
  ============================================================================================================*/
IS
  --------------------------local variables-----------------------------
  l_msg_time_obj           MSG_TIME_OBJ;
  l_mx_msg_id              swms.matrix_in.mx_msg_id%TYPE;
  l_msg_time               TIMESTAMP;
  l_batch_id               swms.matrix_in.batch_id%TYPE;
  l_seq_timestamp          swms.matrix_in.sequence_timestamp%TYPE;
  l_spur_loc               swms.matrix_in.spur_loc%TYPE;
  l_count_no               NUMBER;
  l_flag                   VARCHAR2(1);
  validation_error         EXCEPTION;
  l_interface_flag         VARCHAR2(1);
  l_reason                 VARCHAR2(100);
  l_err_count              NUMBER DEFAULT 0;
  l_lock_handle            VARCHAR2(128 BYTE);
  l_lock_request           INTEGER;


BEGIN

   pl_text_log.ins_msg('INFO', 'pl_xml_matrix_in.SYM05',
                       'SYM05: Message delivery started batch_id: '||i_batch_id,
                        NULL, NULL);

   check_webservice(i_interface_ref_doc  => 'SYM05',
                    o_active_flag        => l_interface_flag,
                    o_reason             => l_reason);

   IF l_interface_flag = 'Y' THEN
   
       --To avoid parallel processing of multiple SYM05 and SYM07 messages for SPUR monitor
      
      dbms_lock.allocate_unique(lockname=> 'SYM05_SYM07_SERIAL_PROC', lockhandle => l_lock_handle);
      LOOP
         l_lock_request := dbms_lock.request(lockhandle        => l_lock_handle,
                                             timeout           => 5,
                                             release_on_commit => FALSE);
         CASE l_lock_request
            WHEN 0 THEN
               pl_text_log.ins_msg('INFO', 'pl_xml_matrix_in.SYM05',
                          'Lock acquired for SYM05 for batch_no '||i_batch_id, NULL, NULL);  
               EXIT; -- success
            WHEN 1 THEN
               pl_text_log.ins_msg('INFO', 'pl_xml_matrix_in.SYM05',
                          'Lock already reserved for SYM05, wait... for batch_no '||i_batch_id, NULL, NULL);                  
               dbms_lock.sleep(1/20); -- sleep 5 seconds before retrying
            ELSE
               pl_text_log.ins_msg('INFO', 'pl_xml_matrix_in.SYM07',
                          'Failed to acquired lock for SYM05 for batch_no '||i_batch_id, NULL, NULL);  
               EXIT; -- Failed
         END CASE; --
      END LOOP;
     ------------------Initializing the local variables-----------------------
      l_msg_time_obj           := i_msg_time_obj;
      l_batch_id               := i_batch_id;
      l_seq_timestamp          := TO_TIMESTAMP(i_sequence_timestamp,'YYYY-MM-DD HH24:MI:SS');
      l_spur_loc               := i_spur_location;

     -----------Extracting the object Values into the variables----------------
      l_mx_msg_id              := l_msg_time_obj.msg_meta_data(1).message_id;
      l_msg_time               := TO_TIMESTAMP(l_msg_time_obj.msg_meta_data(1).time_stamp,'YYYY-MM-DD HH24:MI:SS');

      pl_text_log.ins_msg('INFO', 'pl_xml_matrix_in.SYM05',
                          'Printing: Spur loc: '||l_spur_loc,
                           NULL, NULL);

      ---------------Validating the data as per the bussiness-------------------
      -------Validating Matrix message id and will not accept null values-------
      IF l_mx_msg_id  = TO_CHAR(0) THEN
        l_err_count  := l_err_count + 1;
        IF l_err_count = 1 THEN
        o_status_msg := 'FAILED: Matrix_msg_id is 0 and Invalid';
        END IF;
        --RAISE validation_error;
      ELSIF l_mx_msg_id IS NULL THEN
        l_err_count  := l_err_count + 1;
        IF l_err_count = 1 THEN
        o_status_msg    := 'FAILED: Matrix_msg_id is Null and Invalid';
        END IF;
        --RAISE validation_error;
      END IF;

      ---Validating Matrix message timestamp and will not accept null values----
      IF l_msg_time  IS NULL THEN
        l_err_count  := l_err_count + 1;
        IF l_err_count = 1 THEN
        o_status_msg := 'FAILED: Matrix_msg_timestamp is Null and Invalid';
        END IF;
        --RAISE validation_error;
      END IF;

      pl_text_log.ins_msg('INFO', 'pl_xml_matrix_in.SYM05',
                          'Printing: Msg_Id: '||l_mx_msg_id,
                           NULL, NULL);

      -------Validating Batch ID, must be valid and Assigned to Symbotic---------
      BEGIN

        SELECT COUNT(*)
          INTO l_count_no
          FROM sos_batch
         WHERE batch_no = l_batch_id;

      EXCEPTION
      WHEN NO_DATA_FOUND THEN
        l_err_count  := l_err_count + 1;
        IF l_err_count = 1 THEN
        o_status_msg:= 'FAILED: Verifying the Batch';
        END IF;
        --RETURN 1;
        --RAISE validation_error;
      END;
      IF l_count_no   = 0 THEN
        l_err_count  := l_err_count + 1;
        IF l_err_count = 1 THEN
        o_status_msg := 'FAILED: Invalid Batch Id';
        END IF;
        --RAISE validation_error;
      END IF;

      pl_text_log.ins_msg('INFO', 'pl_xml_matrix_in.SYM05',
                     'Printing: Batch_Id: '||l_batch_id,
                      NULL, NULL);

      -------------Validating Spur Location and must exist in SWMS---------------
      BEGIN
        SELECT COUNT(*)
          INTO l_count_no
          FROM loc
         WHERE slot_type   = 'MXS'
           AND logi_loc    = l_spur_loc;
      EXCEPTION
      WHEN NO_DATA_FOUND THEN
        l_err_count  := l_err_count + 1;
        IF l_err_count = 1 THEN
        o_status_msg:= 'FAILED: Executing Count for SPUR Location';
        END IF;
        --RETURN 1;
      END;
      IF l_count_no   = 0 THEN
        l_err_count  := l_err_count + 1;
        IF l_err_count = 1 THEN
        o_status_msg := 'FAILED: Invalid Spur Location';
        END IF;
        --RAISE validation_error;
      END IF;

      --------------------Inserting the data after validations------------------
      BEGIN
        INSERT
          INTO matrix_in
          (
            mx_msg_id, msg_time, interface_ref_doc, rec_ind,
            batch_id, sequence_timestamp, spur_loc
          )
        VALUES
          (
            l_mx_msg_id, l_msg_time, 'SYM05', 'S',
            l_batch_id, l_seq_timestamp, l_spur_loc
          );
        COMMIT;
      EXCEPTION
      WHEN OTHERS THEN
        ROLLBACK;
        o_status_msg:= 'FAILED: Problem Occured during Insert';
        RETURN 1;
      END;
      
      IF l_err_count >= 1 THEN
        RAISE validation_error;
      END IF;

      -------------Submitting a Job to initiate the SWMS processing----------------
      BEGIN
        dbms_scheduler.create_job
        (
          job_name        =>  'SYM05_'||l_mx_msg_id,
          job_type        =>  'PLSQL_BLOCK',
          job_action      =>  'BEGIN pl_mx_stg_to_swms.sym05_sos_batch_update('||l_mx_msg_id||'); END;',
          start_date      =>  SYSDATE,
          enabled         =>  TRUE,
          auto_drop       =>  TRUE,
          comments        =>  'Submiting a job to invoke SYM05 webservice');
      END;
      o_status_msg:= 'SUCCESS';
	   l_lock_request := dbms_lock.release(lockhandle => l_lock_handle); --To avoid parallel processing of multiple SYM05 and SYM07 messages for SPUR monitor
      RETURN 0;
	  

   ELSE

   o_status_msg:= 'SWMS is Currently Under Maintanance, Please Send the message Later';

   pl_text_log.ins_msg('INFO', 'pl_xml_matrix_in.SYM05',
                       'Printing: Error_msg: '||o_status_msg,
                        NULL, NULL);
   RETURN 1;

   END IF;
EXCEPTION
WHEN validation_error THEN
    l_lock_request := dbms_lock.release(lockhandle => l_lock_handle); --To avoid parallel processing of multiple SYM05 and SYM07 messages for SPUR monitor
   pl_text_log.ins_msg('INFO', 'pl_xml_matrix_in.SYM05',
                       'Printing: Error_msg: '||o_status_msg,
                        NULL, NULL);
     UPDATE matrix_in
        SET record_status = 'F',
            error_msg     = o_status_msg
      WHERE mx_msg_id     = l_mx_msg_id;
    COMMIT;
  RETURN 1;
WHEN OTHERS THEN
  l_lock_request := dbms_lock.release(lockhandle => l_lock_handle); --To avoid parallel processing of multiple SYM05 and SYM07 messages for SPUR monitor
  pl_text_log.ins_msg('INFO', 'pl_xml_matrix_in.SYM05',
                     'Printing: Error_msg: '||SQLERRM,
                      NULL, NULL);
  o_status_msg:= 'FAILED: Internal Error';
  RETURN 1;
END sym05_batch_ready;

FUNCTION sym06_case_skipped(
    i_msg_time_obj           IN msg_time_obj,
    i_batch_id               IN VARCHAR2,
    i_case_barcode           IN VARCHAR2,
    i_sku                    IN VARCHAR2,
    i_skip_reason            IN VARCHAR2,
    o_status_msg            OUT VARCHAR2)
  RETURN NUMBER
  /*===========================================================================================================
  -- Function
  -- sym06_case_skipped
  --
  -- Description
  --   This Function collects the SYM-06 data from Symbotic.
  --   This Function validates the data received and takes Ownership
  --   of the Request received from Symbotic.
  --
  -- Modification History
  --
  -- Date                User                  Version            Defect  Comment
  -- 10/28/14        Sunil Ontipalli             1.0              Initial Creation
  ============================================================================================================*/
IS
 --------------------------local variables-----------------------------
  l_msg_time_obj           MSG_TIME_OBJ;
  l_mx_msg_id              swms.matrix_in.mx_msg_id%TYPE;
  l_msg_time               TIMESTAMP;
  l_batch_id               swms.matrix_in.batch_id%TYPE;
  l_case_barcode           swms.matrix_in.case_barcode%TYPE;
  l_sku                    swms.matrix_in.prod_id%TYPE;
  l_skip_reason            swms.matrix_in.skip_reason%TYPE;
  l_count_no               NUMBER;
  l_flag                   VARCHAR2(1);
  validation_error         EXCEPTION;
  l_interface_flag         VARCHAR2(1);
  l_reason                 VARCHAR2(100);
  l_err_count              NUMBER DEFAULT 0;


BEGIN

   pl_text_log.ins_msg('INFO', 'pl_xml_matrix_in.SYM06',
                       'SYM06: Message delivery started batch_id: '||i_batch_id,
                        NULL, NULL);

   check_webservice(i_interface_ref_doc  => 'SYM06',
                    o_active_flag        => l_interface_flag,
                    o_reason             => l_reason);

   IF l_interface_flag = 'Y' THEN

     ------------------Initializing the local variables-----------------------
      l_msg_time_obj           := i_msg_time_obj;
      l_batch_id               := i_batch_id;
      l_case_barcode           := i_case_barcode;
      l_sku                    := i_sku;
      l_skip_reason            := i_skip_reason;

     -----------Extracting the object Values into the variables----------------
      l_mx_msg_id              := l_msg_time_obj.msg_meta_data(1).message_id;
      l_msg_time               := TO_TIMESTAMP(l_msg_time_obj.msg_meta_data(1).time_stamp,'YYYY-MM-DD HH24:MI:SS');

      pl_text_log.ins_msg('INFO', 'pl_xml_matrix_in.SYM06',
                          'SYM06: Printing MSG ID: '||l_mx_msg_id,
                           NULL, NULL);

      ---------------Validating the data as per the bussiness-------------------
      -------Validating Matrix message id and will not accept null values-------
      IF l_mx_msg_id  = TO_CHAR(0) THEN
        l_err_count  := l_err_count + 1;
        IF l_err_count = 1 THEN       
         o_status_msg := 'FAILED: Matrix_msg_id is 0 and Invalid';
        END IF;
        --RAISE validation_error;
      ELSIF l_mx_msg_id IS NULL THEN
        l_err_count  := l_err_count + 1;
        IF l_err_count = 1 THEN
        o_status_msg    := 'FAILED: Matrix_msg_id is Null and Invalid';
        END IF;
        --RAISE validation_error;
      END IF;

      ---Validating Matrix message timestamp and will not accept null values----
      IF l_msg_time  IS NULL THEN
        l_err_count  := l_err_count + 1;
        IF l_err_count = 1 THEN      
        o_status_msg := 'FAILED: Matrix_msg_timestamp is Null and Invalid';
        END IF;
        --RAISE validation_error;
      END IF;

      -------Validating Batch ID, must be valid and Assigned to Symbotic---------
      BEGIN

         SELECT COUNT(*)
           INTO l_count_no
           FROM sos_batch
          WHERE batch_no = l_batch_id;

      EXCEPTION
      WHEN NO_DATA_FOUND THEN
        l_err_count  := l_err_count + 1;
        IF l_err_count = 1 THEN
        o_status_msg:= 'FAILED: Verifying the Batch';
        END IF;
        --RETURN 1;
        --RAISE validation_error;
      END;
      IF l_count_no   = 0 THEN
        l_err_count  := l_err_count + 1;
        IF l_err_count = 1 THEN
        o_status_msg := 'FAILED: Invalid Batch Id';
        END IF;
        --RAISE validation_error;
      END IF;

      pl_text_log.ins_msg('INFO', 'pl_xml_matrix_in.SYM06',
                          'SYM06: Printing Case Barcode: '||l_case_barcode,
                           NULL, NULL);
     ----Validating Case Barcode, Barcode and Batch Id combination must be unique---
      BEGIN

        SELECT COUNT(*)
          INTO l_count_no
          FROM mx_float_detail_cases fd, floats f
         WHERE fd.float_no = f.float_no
           AND fd.case_id  = l_case_barcode
           AND f.batch_no  = l_batch_id;

      EXCEPTION
      WHEN NO_DATA_FOUND THEN
        l_err_count  := l_err_count + 1;
        IF l_err_count = 1 THEN
         o_status_msg:= 'FAILED: Executing Count for Case Barcode';
        END IF;
        --RETURN 1;
      END;
      IF l_count_no   = 0 THEN
        l_err_count  := l_err_count + 1;
        IF l_err_count = 1 THEN
         o_status_msg := 'FAILED: Invalid Case Barcode or Barcode, Batch Id combination ';
        END IF;
        --RAISE validation_error;
      END IF;

      pl_text_log.ins_msg('INFO', 'pl_xml_matrix_in.SYM06',
                          'SYM06: Printing Prod Id: '||l_sku,
                           NULL, NULL);

     -----------------Validating Prod Id and must exist in SWMS------------------
  /*    BEGIN
        SELECT COUNT(*)
          INTO l_count_no
          FROM mx_float_detail_cases fd, floats f
         WHERE fd.float_no = f.float_no
           AND fd.case_id  = l_case_barcode
           AND f.batch_no  = l_batch_id
           AND fd.prod_id  = l_sku;
      EXCEPTION
      WHEN NO_DATA_FOUND THEN
        o_status_msg:= 'FAILED: Executing Count for Prod Id';
        RETURN 1;
      END;
      IF l_count_no   = 0 THEN
        o_status_msg := 'FAILED: Invalid Product Id or Invalid Product Id, barcode, batch_id Combination';
        RAISE validation_error;
      END IF;*/

      --------------------Inserting the data after validations------------------
      BEGIN
        INSERT
          INTO matrix_in
          (
            mx_msg_id, msg_time, interface_ref_doc, rec_ind,
            batch_id, case_barcode, prod_id, skip_reason
          )
        VALUES
          (
            l_mx_msg_id, l_msg_time, 'SYM06', 'S',
            l_batch_id, l_case_barcode, l_sku, l_skip_reason
          );
        COMMIT;
      EXCEPTION
      WHEN OTHERS THEN
        ROLLBACK;
        o_status_msg:= 'FAILED: Problem Occured during Insert';
        RETURN 1;
      END;
      
      IF l_err_count >= 1 THEN
        RAISE validation_error;
      END IF;

      -------------Submitting a Job to initiate the SWMS processing----------------
      BEGIN
        dbms_scheduler.create_job
        (
          job_name        =>  'SYM06_'||l_mx_msg_id,
          job_type        =>  'PLSQL_BLOCK',
          job_action      =>  'BEGIN pl_mx_stg_to_swms.sym06_case_skipped_update('||l_mx_msg_id||'); END;',
          start_date      =>  SYSDATE,
          enabled         =>  TRUE,
          auto_drop       =>  TRUE,
          comments        =>  'Submiting a job to invoke SYM06 webservice');
      END;

      o_status_msg:= 'SUCCESS';
      RETURN 0;

   ELSE

   o_status_msg:= 'SWMS is Currently Under Maintanance, Please Send the message Later';

   pl_text_log.ins_msg('INFO', 'pl_xml_matrix_in.SYM06',
                       'SYM06: Printing: Error_msg: '||o_status_msg,
                        NULL, NULL);
   RETURN 1;

   END IF;
EXCEPTION
WHEN validation_error THEN
  pl_text_log.ins_msg('INFO', 'pl_xml_matrix_in.SYM06',
                       'SYM06: Printing: Error_msg: '||o_status_msg,
                        NULL, NULL);
     UPDATE matrix_in
        SET record_status = 'F',
            error_msg     = o_status_msg
      WHERE mx_msg_id     = l_mx_msg_id;
    COMMIT;
  RETURN 1;
WHEN OTHERS THEN
  pl_text_log.ins_msg('INFO', 'pl_xml_matrix_in.SYM06',
                       'SYM06: Printing: Error_msg: '||SQLERRM,
                        NULL, NULL);

  o_status_msg:= 'FAILED';

  RETURN 1;
END sym06_case_skipped;


FUNCTION sym07_product_ready(
    i_msg_time_obj           IN msg_time_obj,
    i_sequence_timestamp     IN VARCHAR2,
    i_release_type           IN VARCHAR2,
    i_batch_id               IN VARCHAR2,
    i_spur_location          IN VARCHAR2,
    i_product_details        IN product_details_obj,
    o_status_msg            OUT VARCHAR2)
  RETURN NUMBER
/*===========================================================================================================
  -- Function
  -- sym07_product_ready
  --
  -- Description
  --   This Function collects the SYM-07 data from Symbotic.
  --   This Function validates the data received and takes Ownership
  --   of the Request received from Symbotic.
  --
  -- Modification History
  --
  -- Date                User                  Version            Defect  Comment
  -- 10/29/14        Sunil Ontipalli             1.0              Initial Creation
  ============================================================================================================*/
IS
  --------------------------local variables-----------------------------
  l_msg_time_obj           MSG_TIME_OBJ;
  l_mx_msg_id              swms.matrix_in.mx_msg_id%TYPE;
  l_msg_time               TIMESTAMP;
  l_batch_id               swms.matrix_in.batch_id%TYPE;
  l_seq_timestamp          swms.matrix_in.sequence_timestamp%TYPE;
  l_spur_loc               swms.matrix_in.spur_loc%TYPE;
  l_release_type           swms.matrix_in.trans_type%TYPE;
  l_back_table             product_details_table;
  l_task_id                swms.matrix_in.task_id%TYPE;
  l_sku                    swms.matrix_in.prod_id%TYPE;
  l_pallet_id              swms.matrix_in.pallet_id%TYPE;
  l_case_qty               swms.matrix_in.case_qty%TYPE;
  l_count_no               NUMBER;
  l_flag                   VARCHAR2(1);
  validation_error         EXCEPTION;
  l_interface_flag         VARCHAR2(1);
  l_reason                 VARCHAR2(100);
  l_err_count              NUMBER DEFAULT 0;
  l_lock_handle            VARCHAR2(128 BYTE);
  l_lock_request           INTEGER;

BEGIN

   pl_text_log.ins_msg('INFO', 'pl_xml_matrix_in.SYM07',
                       'SYM07: Message delivery started batch_id: '||i_batch_id,
                        NULL, NULL);

   check_webservice(i_interface_ref_doc  => 'SYM07',
                    o_active_flag        => l_interface_flag,
                    o_reason             => l_reason);

   IF l_interface_flag = 'Y' THEN
   
     --To avoid parallel processing of multiple SYM05 and SYM07 messages for SPUR monitor  
      
      dbms_lock.allocate_unique(lockname=> 'SYM05_SYM07_SERIAL_PROC', lockhandle => l_lock_handle);
      LOOP
         l_lock_request := dbms_lock.request(lockhandle        => l_lock_handle,
                                             timeout           => 5,
                                             release_on_commit => FALSE);
         CASE l_lock_request
            WHEN 0 THEN
               pl_text_log.ins_msg('INFO', 'pl_xml_matrix_in.SYM07',
                          'Lock acquired for SYM07 for batch_no '||i_batch_id, NULL, NULL);  
               EXIT; -- success
            WHEN 1 THEN
               pl_text_log.ins_msg('INFO', 'pl_xml_matrix_in.SYM05',
                          'Lock already reserved for SYM07, wait... for batch_no '||i_batch_id, NULL, NULL);                  
               dbms_lock.sleep(1/20); -- sleep 5 seconds before retrying
            ELSE
               pl_text_log.ins_msg('INFO', 'pl_xml_matrix_in.SYM07',
                          'Failed to acquired lock for SYM07 for batch_no '||i_batch_id, NULL, NULL);  
               EXIT; -- Failed
               
         END CASE; --
      END LOOP;

     ------------------Initializing the local variables-----------------------
      l_msg_time_obj           := i_msg_time_obj;
      l_batch_id               := i_batch_id;
      l_seq_timestamp          := TO_TIMESTAMP(i_sequence_timestamp,'YYYY-MM-DD HH24:MI:SS');
      l_spur_loc               := i_spur_location;
      l_release_type           := i_release_type;
      l_back_table             := i_product_details.product_details_data;

     -----------Extracting the object Values into the variables----------------
      l_mx_msg_id              := l_msg_time_obj.msg_meta_data(1).message_id;
      l_msg_time               := TO_TIMESTAMP(l_msg_time_obj.msg_meta_data(1).time_stamp,'YYYY-MM-DD HH24:MI:SS');

      pl_text_log.ins_msg('INFO', 'pl_xml_matrix_in.SYM07',
                          'SYM07: Printing Msg Id: '||l_mx_msg_id,
                           NULL, NULL);

      ---------------Validating the data as per the bussiness-------------------
      -------Validating Matrix message id and will not accept null values-------
      IF l_mx_msg_id  = TO_CHAR(0) THEN
        l_err_count  := l_err_count + 1;
        IF l_err_count = 1 THEN
        o_status_msg := 'FAILED: Matrix_msg_id is 0 and Invalid';
        END IF;
        --RAISE validation_error;
      ELSIF l_mx_msg_id IS NULL THEN
        l_err_count  := l_err_count + 1;
        IF l_err_count = 1 THEN
        o_status_msg    := 'FAILED: Matrix_msg_id is Null and Invalid';
        END IF;
        --RAISE validation_error;
      END IF;

      ---Validating Matrix message timestamp and will not accept null values----
      IF l_msg_time  IS NULL THEN
        l_err_count  := l_err_count + 1;
        IF l_err_count = 1 THEN
        o_status_msg := 'FAILED: Matrix_msg_timestamp is Null and Invalid';
        END IF;
        --RAISE validation_error;
      END IF;

      pl_text_log.ins_msg('INFO', 'pl_xml_matrix_in.SYM07',
                          'SYM07: Printing Release Type: '||l_release_type,
                           NULL, NULL);

      -------------Validating Release Type and must exist in SWMS---------------
      BEGIN
        SELECT COUNT(*)
          INTO l_count_no
          FROM dual
         WHERE l_release_type IN ('DSP', 'NSP', 'UNA', 'MRL', 'IIR');
      EXCEPTION
      WHEN NO_DATA_FOUND THEN
        l_err_count  := l_err_count + 1;
        IF l_err_count = 1 THEN
        o_status_msg:= 'FAILED: Executing Count';
        END IF;
        --RETURN 1;
      END;
      IF l_count_no   = 0 THEN
        l_err_count  := l_err_count + 1;
        IF l_err_count = 1 THEN
        o_status_msg := 'FAILED: Invalid Release Type';
        END IF;
        --RAISE validation_error;
      END IF;

     /* -------Validating Batch ID, must be valid and Assigned to Symbotic---------
      BEGIN
        SELECT pl_matrix_common.sos_batch_to_matrix_yn(l_batch_id)
          INTO l_flag
          FROM dual;
      EXCEPTION
      WHEN NO_DATA_FOUND THEN
        o_status_msg:= 'FAILED: Verifying the Batch';
        RETURN 1;
        RAISE validation_error;
      END;
      IF l_flag   = 'N' THEN
        o_status_msg := 'FAILED: Invalid Batch Id';
        RAISE validation_error;
      END IF;

      -------------Validating Spur Location and must exist in SWMS---------------
      BEGIN
        SELECT COUNT(*)
          INTO l_count_no
          FROM loc
         WHERE slot_type   = 'MXS'
           AND logi_loc    = l_spur_loc;
      EXCEPTION
      WHEN NO_DATA_FOUND THEN
        o_status_msg:= 'FAILED: Executing Count for SPUR Location';
        RETURN 1;
      END;
      IF l_count_no   = 0 THEN
        o_status_msg := 'FAILED: Invalid Spur Location';
        RAISE validation_error;
      END IF;
      */
      --------------------Inserting the data after validations------------------
      BEGIN
        INSERT
          INTO matrix_in
          (
            mx_msg_id, msg_time, interface_ref_doc, rec_ind,
            batch_id, sequence_timestamp, trans_type, spur_loc
          )
        VALUES
          (
            l_mx_msg_id, l_msg_time, 'SYM07', 'H',
            l_batch_id, l_seq_timestamp, l_release_type, l_spur_loc
          );
      EXCEPTION
      WHEN OTHERS THEN
        ROLLBACK;
        o_status_msg:= 'FAILED: Problem Occured during Insert';
        RETURN 1;
      END;

      FOR I IN l_back_table.first..l_back_table.last

      LOOP

      l_task_id        :=  l_back_table(I).task_id;
      l_sku            :=  l_back_table(I).sku;
      l_pallet_id      :=  l_back_table(I).pallet_id;
      l_case_qty       :=  l_back_table(I).case_quantity;

      pl_text_log.ins_msg('INFO', 'pl_xml_matrix_in.SYM07',
                          'SYM07: Printing Prod Id: '||l_sku||' SYM07: Printing Pallet Id: '||l_pallet_id,
                           NULL, NULL);

      -------Validating License Plate No,Prod Id and must exist in SWMS---------
         /* BEGIN
            SELECT COUNT(*)
              INTO l_count_no
              FROM inv
             WHERE prod_id   = l_sku
               AND logi_loc  = l_pallet_id;
          EXCEPTION
          WHEN NO_DATA_FOUND THEN
            l_err_count  := l_err_count + 1;
            IF l_err_count = 1 THEN
            o_status_msg:= 'FAILED: Executing Count';
            END IF;
            --RETURN 1;
          END;
          IF l_count_no   = 0 THEN
              --ROLLBACK;
              l_err_count  := l_err_count + 1;
              IF l_err_count = 1 THEN
               o_status_msg := 'FAILED: Invalid Product Id and Licence Plate combination';
              END IF;
              --RAISE validation_error;
          END IF;
		  */

          BEGIN
            INSERT
              INTO matrix_in
                (
                 mx_msg_id, msg_time, interface_ref_doc, rec_ind,
                 task_id, prod_id, pallet_id, case_qty
                )
            VALUES
               (
                l_mx_msg_id, l_msg_time, 'SYM07', 'D',
                l_task_id, l_sku, l_pallet_id, l_case_qty
               );
          EXCEPTION
           WHEN OTHERS THEN
            ROLLBACK;
            o_status_msg:= 'FAILED: Problem Occured during Insert';
            RETURN 1;
          END;

      END LOOP;

      COMMIT;
      
      IF l_err_count >= 1 THEN
        RAISE validation_error;
      END IF;

      -------------Submitting a Job to initiate the SWMS processing----------------
      BEGIN
        dbms_scheduler.create_job
        (
          job_name        =>  'SYM07_'||l_mx_msg_id,
          job_type        =>  'PLSQL_BLOCK',
          job_action      =>  'BEGIN pl_mx_stg_to_swms.sym07_rpln_inv_update('||l_mx_msg_id||'); END;',
          start_date      =>  SYSDATE,
          enabled         =>  TRUE,
          auto_drop       =>  TRUE,
          comments        =>  'Submiting a job to invoke SYM07 webservice');
      END;
      o_status_msg:= 'SUCCESS';
	   l_lock_request := dbms_lock.release(lockhandle => l_lock_handle); --To avoid parallel processing of multiple SYM05 and SYM07 messages for SPUR monitor
      RETURN 0;

   ELSE

   o_status_msg:= 'SWMS is Currently Under Maintanance, Please Send the message Later';

   pl_text_log.ins_msg('INFO', 'pl_xml_matrix_in.SYM07',
                       'SYM07: Printing: Error_msg: '||o_status_msg,
                        NULL, NULL);

   RETURN 1;

   END IF;
EXCEPTION
WHEN validation_error THEN
ROLLBACK;
  l_lock_request := dbms_lock.release(lockhandle => l_lock_handle); --To avoid parallel processing of multiple SYM05 and SYM07 messages for SPUR monitor
  pl_text_log.ins_msg('INFO', 'pl_xml_matrix_in.SYM07',
                       'SYM07: Printing: Error_msg: '||o_status_msg,
                        NULL, NULL);
     UPDATE matrix_in
        SET record_status = 'F',
            error_msg     = o_status_msg
      WHERE mx_msg_id     = l_mx_msg_id;
    COMMIT;
  RETURN 1;
WHEN OTHERS THEN
ROLLBACK;
   l_lock_request := dbms_lock.release(lockhandle => l_lock_handle); --To avoid parallel processing of multiple SYM05 and SYM07 messages for SPUR monitor
  pl_text_log.ins_msg('INFO', 'pl_xml_matrix_in.SYM07',
                       'SYM07: Printing: Error_msg: '||SQLERRM,
                        NULL, NULL);
  o_status_msg:= 'FAILED';
  RETURN 1;
END sym07_product_ready;

FUNCTION sym12_case_delivered_spur(
    i_msg_time_obj           IN msg_time_obj,
    i_batch_id               IN VARCHAR2,
    i_task_id                IN VARCHAR2,
    i_case_barcode           IN VARCHAR2,
    i_sku                    IN VARCHAR2,
    i_spur_location          IN VARCHAR2,
    i_licence_plate_no       IN VARCHAR2,
    i_lane_id                IN NUMBER,
    i_divert_time            IN VARCHAR2,
    i_last_case_batch        IN VARCHAR2,
    o_status_msg            OUT VARCHAR2)
  RETURN NUMBER
/*===========================================================================================================
  -- Function
  -- sym12_case_delivered_spur
  --
  -- Description
  --   This Function collects the SYM-12 data from Symbotic.
  --   This Function validates the data received and takes Ownership
  --   of the Request received from Symbotic.
  --
  -- Modification History
  --
  -- Date                User                  Version            Defect  Comment
  -- 10/28/14        Sunil Ontipalli             1.0              Initial Creation
  ============================================================================================================*/
IS
 --------------------------local variables-----------------------------
  l_msg_time_obj           MSG_TIME_OBJ;
  l_mx_msg_id              swms.matrix_in.mx_msg_id%TYPE;
  l_msg_time               TIMESTAMP;
  l_batch_id               swms.matrix_in.batch_id%TYPE;
  l_task_id                swms.matrix_in.task_id%TYPE;
  l_case_barcode           swms.matrix_in.case_barcode%TYPE;
  l_sku                    swms.matrix_in.prod_id%TYPE;
  l_spur_loc               swms.matrix_in.spur_loc%TYPE;
  l_pallet_id              swms.matrix_in.pallet_id%TYPE;
  l_lane_id                swms.matrix_in.lane_id%TYPE;
  l_divert_time            swms.matrix_in.divert_time%TYPE;
  l_last_case              swms.matrix_in.last_case%TYPE;
  l_count_no               NUMBER;
  l_flag                   VARCHAR2(1);
  validation_error         EXCEPTION;
  l_interface_flag         VARCHAR2(1);
  l_reason                 VARCHAR2(100);
  l_err_count              NUMBER DEFAULT 0;


BEGIN

   pl_text_log.ins_msg('INFO', 'pl_xml_matrix_in.SYM12',
                       'SYM12: Message delivery started batch_id: '||i_batch_id,
                        NULL, NULL);

   check_webservice(i_interface_ref_doc  => 'SYM12',
                    o_active_flag        => l_interface_flag,
                    o_reason             => l_reason);

   IF l_interface_flag = 'Y' THEN

     ------------------Initializing the local variables-----------------------
      l_msg_time_obj           := i_msg_time_obj;
      l_batch_id               := i_batch_id;
      l_task_id                := i_task_id;
      l_case_barcode           := i_case_barcode;
      l_sku                    := i_sku;
      l_spur_loc               := i_spur_location;
      l_pallet_id              := i_licence_plate_no;
      l_lane_id                := i_lane_id;
      l_divert_time            := TO_TIMESTAMP(i_divert_time, 'YYYY-MM-DD HH24:MI:SS');
      l_last_case              := i_last_case_batch;


     -----------Extracting the object Values into the variables----------------
      l_mx_msg_id              := l_msg_time_obj.msg_meta_data(1).message_id;
      l_msg_time               := TO_TIMESTAMP(l_msg_time_obj.msg_meta_data(1).time_stamp,'YYYY-MM-DD HH24:MI:SS');

        pl_text_log.ins_msg('INFO', 'pl_xml_matrix_in.SYM12',
                            'SYM12: Printing: Spur loc: '||l_spur_loc,
                             NULL, NULL);

      ---------------Validating the data as per the bussiness-------------------
      -------Validating Matrix message id and will not accept null values-------
      IF l_mx_msg_id  = TO_CHAR(0) THEN
        l_err_count  := l_err_count + 1;
        IF l_err_count = 1 THEN
        o_status_msg := 'FAILED: Matrix_msg_id is 0 and Invalid';
        END IF;
        --RAISE validation_error;
      ELSIF l_mx_msg_id IS NULL THEN
        l_err_count  := l_err_count + 1;
        IF l_err_count = 1 THEN
        o_status_msg    := 'FAILED: Matrix_msg_id is Null and Invalid';
        END IF;
        --RAISE validation_error;
      END IF;

      ---Validating Matrix message timestamp and will not accept null values----
      IF l_msg_time  IS NULL THEN
        l_err_count  := l_err_count + 1;
        IF l_err_count = 1 THEN
        o_status_msg := 'FAILED: Matrix_msg_timestamp is Null and Invalid';
        END IF;
        --RAISE validation_error;
      END IF;

      pl_text_log.ins_msg('INFO', 'pl_xml_matrix_in.SYM12',
                          'SYM12: Printing: Msg Id: '||l_mx_msg_id,
                           NULL, NULL);
                           
      IF l_batch_id IS NULL AND l_spur_loc LIKE 'SP%J%' THEN
         -- Ignore the empty message to jackpot.  Just get out.
         o_status_msg:= 'SUCCESS';
         RETURN 0;        
      ELSIF l_batch_id IS NULL THEN
         l_err_count  := l_err_count + 1;
         IF l_err_count = 1 THEN
            o_status_msg := 'FAILED: Batch Id is Null';
         END IF;
      END IF;    
     
      -------Validating Batch ID, must be valid and Assigned to Symbotic---------
     /* BEGIN

        SELECT COUNT(*)
          INTO l_count_no
          FROM sos_batch
         WHERE batch_no = l_batch_id;

      EXCEPTION
      WHEN NO_DATA_FOUND THEN
        l_err_count  := l_err_count + 1;
        IF l_err_count = 1 THEN
        o_status_msg:= 'FAILED: Verifying the Batch';
        END IF;
        --RETURN 1;
        --RAISE validation_error;
      END;
      IF l_count_no   = 0 THEN
        l_err_count  := l_err_count + 1;
        IF l_err_count = 1 THEN
        o_status_msg := 'FAILED: Invalid Batch Id';
        END IF;
        --RAISE validation_error;
      END IF;
*/
      /*----------------Validating Task id and must exist in SWMS-----------------
      BEGIN
        SELECT COUNT(*)
          INTO l_count_no
          FROM replenlst
         WHERE task_id   = l_task_id;
      EXCEPTION
      WHEN NO_DATA_FOUND THEN
        o_status_msg:= 'FAILED: Executing Count';
        RETURN 1;
      END;
      IF l_count_no   = 0 THEN
        o_status_msg := 'FAILED: Invalid Task Id';
        RAISE validation_error;
      END IF;

     ----Validating Case Barcode, Barcode and Batch Id combination must be unique---
      BEGIN
        SELECT COUNT(*)
          INTO l_count_no
          FROM mx_float_detail_cases fd, floats f
         WHERE fd.float_no = f.float_no
           AND fd.case_id  = l_case_barcode
           AND f.batch_no  = l_batch_id;
      EXCEPTION
      WHEN NO_DATA_FOUND THEN
        o_status_msg:= 'FAILED: Executing Count for Case Barcode';
        RETURN 1;
      END;
      IF l_count_no   = 0 THEN
        o_status_msg := 'FAILED: Invalid Case Barcode';
        RAISE validation_error;
      END IF;
      */

      pl_text_log.ins_msg('INFO', 'pl_xml_matrix_in.SYM12',
                          'SYM12: Printing: Prod Id: '||l_sku||' SYM12: Printing: Pallet Id: '||l_pallet_id,
                           NULL, NULL);

       -------Validating License Plate No,Prod Id and must exist in SWMS---------
  /*    BEGIN
        SELECT COUNT(*)
          INTO l_count_no
          FROM inv
         WHERE prod_id   = l_sku
           AND logi_loc  = l_pallet_id;
      EXCEPTION
      WHEN NO_DATA_FOUND THEN
        o_status_msg:= 'FAILED: Executing Count';
        RETURN 1;
      END;
      IF l_count_no   = 0 THEN
        o_status_msg := 'FAILED: Invalid Product Id and Licence Plate combination';
        RAISE validation_error;
      END IF;
    */

      --------------------Inserting the data after validations------------------
      BEGIN
        INSERT
          INTO matrix_in
          (
            mx_msg_id, msg_time, interface_ref_doc, rec_ind,
            batch_id, task_id, case_barcode, prod_id, spur_loc,
            pallet_id, lane_id, divert_time, last_case
          )
        VALUES
          (
            l_mx_msg_id, l_msg_time, 'SYM12', 'S',
            l_batch_id, l_task_id, l_case_barcode, l_sku, l_spur_loc,
            l_pallet_id, l_lane_id, l_divert_time, l_last_case
          );
        COMMIT;
      EXCEPTION
      WHEN OTHERS THEN
        ROLLBACK;
        o_status_msg:= 'FAILED: Problem Occured during Insert';
        RETURN 1;
      END;
      
      IF l_err_count >= 1 THEN
        RAISE validation_error;
      END IF;

      -------------Submitting a Job to initiate the SWMS processing----------------
      BEGIN
        dbms_scheduler.create_job
        (
          job_name        =>  'SYM12_'||l_mx_msg_id,
          job_type        =>  'PLSQL_BLOCK',
          job_action      =>  'BEGIN pl_mx_stg_to_swms.sym12_case_div_update('||l_mx_msg_id||'); END;',
          start_date      =>  SYSDATE,
          enabled         =>  TRUE,
          auto_drop       =>  TRUE,
          comments        =>  'Submiting a job to invoke SYM12 webservice');
      END;
      o_status_msg:= 'SUCCESS';
      RETURN 0;

   ELSE

   o_status_msg:= 'SWMS is Currently Under Maintanance, Please Send the message Later';
   pl_text_log.ins_msg('INFO', 'pl_xml_matrix_in.SYM12',
                      'Printing: Error_msg: '||o_status_msg,
                       NULL, NULL);
   RETURN 1;

   END IF;
EXCEPTION
WHEN validation_error THEN
  pl_text_log.ins_msg('INFO', 'pl_xml_matrix_in.SYM12',
                      'Printing: Error_msg: '||o_status_msg,
                       NULL, NULL);
                       
     UPDATE matrix_in
        SET record_status = 'F',
            error_msg     = o_status_msg
      WHERE mx_msg_id     = l_mx_msg_id;
    COMMIT;
  RETURN 1;
WHEN OTHERS THEN
  pl_text_log.ins_msg('INFO', 'pl_xml_matrix_in.SYM12',
                      'Printing: Error_msg: '||SQLERRM,
                       NULL, NULL);
  o_status_msg:= 'FAILED';
  RETURN 1;
END sym12_case_delivered_spur;

FUNCTION sym15_bulk_notification(
    i_msg_time_obj           IN msg_time_obj,
    i_message_status         IN VARCHAR2,
    i_message_name           IN VARCHAR2,
    i_file_timestamp         IN VARCHAR2,
    i_file_name              IN VARCHAR2,
    i_row_count              IN NUMBER,
    o_status_msg            OUT VARCHAR2)
  RETURN NUMBER
/*===========================================================================================================
  -- Function
  -- sym15_bulk_notification
  --
  -- Description
  --   This Function collects the SYM-15 data from Symbotic.
  --   This Function validates the data received and takes Ownership
  --   of the Request received from Symbotic.
  --
  -- Modification History
  --
  -- Date                User                  Version            Defect  Comment
  -- 12/12/14        Sunil Ontipalli             1.0              Initial Creation
  ============================================================================================================*/
IS
  --------------------------local variables-----------------------------
  l_msg_time_obj           MSG_TIME_OBJ;
  l_mx_msg_id              swms.matrix_in.mx_msg_id%TYPE;
  l_msg_time               TIMESTAMP;
  l_message_name           swms.matrix_in.message_name%TYPE;
  l_message_status         swms.matrix_in.symbotic_status%TYPE;
  l_file_name              swms.matrix_in.file_name%TYPE;
  l_file_timestamp         swms.matrix_in.file_timestamp%TYPE;
  l_row_count              swms.matrix_in.row_count%TYPE;
  l_file                   UTL_FILE.FILE_TYPE;
  validation_error         EXCEPTION;
  l_interface_flag         VARCHAR2(1);
  l_reason                 VARCHAR2(100);
  l_host_call              VARCHAR2(1000);
  l_err_count              NUMBER DEFAULT 0;

BEGIN

   pl_text_log.ins_msg('INFO', 'pl_xml_matrix_in.SYM15',
                       'SYM15: Message delivery started',
                        NULL, NULL);

   check_webservice(i_interface_ref_doc  => 'SYM15',
                    o_active_flag        => l_interface_flag,
                    o_reason             => l_reason);

   IF l_interface_flag = 'Y' THEN

     ------------------Initializing the local variables-----------------------
      l_msg_time_obj           := i_msg_time_obj;
      l_message_name           := i_message_name;
      l_message_status         := i_message_status;
      l_file_name              := i_file_name;
      l_file_timestamp         := TO_TIMESTAMP(i_file_timestamp,'YYYY-MM-DD HH24:MI:SS');
      l_row_count              := i_row_count;

     -----------Extracting the object Values into the variables----------------
      l_mx_msg_id              := l_msg_time_obj.msg_meta_data(1).message_id;
      l_msg_time               := TO_TIMESTAMP(l_msg_time_obj.msg_meta_data(1).time_stamp,'YYYY-MM-DD HH24:MI:SS');

      pl_text_log.ins_msg('INFO', 'pl_xml_matrix_in.SYM15',
                       'SYM15: Printing Msg Id: '||l_mx_msg_id||' Printing Message Status: '||l_message_status,
                        NULL, NULL);

      IF l_message_status = 'SUCCESS' THEN

          ---------------Validating the data as per the bussiness-------------------
          -------Validating Matrix message id and will not accept null values-------
          IF l_mx_msg_id  = TO_CHAR(0) THEN
           l_err_count  := l_err_count + 1;
           IF l_err_count = 1 THEN
            o_status_msg := 'FAILED: Matrix_msg_id is 0 and Invalid';
           END IF;
            --RAISE validation_error;
          ELSIF l_mx_msg_id IS NULL THEN
           l_err_count  := l_err_count + 1;
           IF l_err_count = 1 THEN
            o_status_msg    := 'FAILED: Matrix_msg_id is Null and Invalid';
           END IF;
           --RAISE validation_error;
          END IF;

          ---Validating Matrix message timestamp and will not accept null values----
          IF l_msg_time  IS NULL THEN
            l_err_count  := l_err_count + 1;
            IF l_err_count = 1 THEN
             o_status_msg := 'FAILED: Matrix_msg_timestamp is Null and Invalid';
            END IF;
            --RAISE validation_error;
          END IF;

          pl_text_log.ins_msg('INFO', 'pl_xml_matrix_in.SYM15',
                       'SYM15: Printing File Name: '||l_file_name,
                        NULL, NULL);

          --------------Vlaidating the file in the Symbotic Location----------------

         /* BEGIN

           l_file := UTL_FILE.FOPEN('SYMBOTIC',l_file_name,'R');

           UTL_FILE.FCLOSE(l_file);

          EXCEPTION
           WHEN UTL_FILE.INVALID_OPERATION THEN
            UTL_FILE.FCLOSE(l_file);
            o_status_msg := 'Invalid File: File Not Exists or Not Readable';
            RAISE validation_error;
          END;*/

         --------------------Inserting the data after validations------------------
          BEGIN
            INSERT
              INTO matrix_in
              (
                mx_msg_id, msg_time, interface_ref_doc, rec_ind,
                message_name, symbotic_status, file_name, file_timestamp, row_count
              )
           VALUES
             (
               l_mx_msg_id, l_msg_time, 'SYM15', 'S',
               l_message_name, l_message_status, l_file_name, l_file_timestamp, l_row_count
             );
           COMMIT;
          EXCEPTION
           WHEN OTHERS THEN
            ROLLBACK;
            o_status_msg:= 'FAILED: Problem Occured during Insert';
            RETURN 1;
          END;
          
          IF l_err_count >= 1 THEN
              RAISE validation_error;
          END IF;
         

        ------------------------Invoking the shell script---------------------------      
          
       BEGIN

        l_host_call := DBMS_HOST_COMMAND_FUNC('swms', 'sh /swms/curr/bin/symbotic_bulk_inv.sh '||l_file_name);

       EXCEPTION
        WHEN OTHERS THEN
          pl_text_log.ins_msg('INFO', 'pl_xml_matrix_out.generate_pm_bulk_file',
                              'Error Calling the host Shell Program',
                              SQLCODE, SQLERRM);
          RAISE;
       END;

      o_status_msg:= 'SUCCESS';
      RETURN 0;

      ELSE

        pl_text_log.ins_msg('INFO', 'pl_xml_matrix_in.SYM15',
                       'SYM15: File Not exists ',
                        NULL, NULL);
       --Inserting the data when there is a failure in generating the file by Symbotic--
            INSERT
              INTO matrix_in
              (
                mx_msg_id, msg_time, interface_ref_doc, rec_ind,
                message_name, symbotic_status, file_name, file_timestamp, row_count
              )
           VALUES
             (
               l_mx_msg_id, l_msg_time, 'SYM15', 'S',
               l_message_name, l_message_status, l_file_name, l_file_timestamp, l_row_count
             );

          UPDATE matrix_in
             SET record_status = 'F'
           WHERE mx_msg_id     = l_mx_msg_id;
          COMMIT;
      END IF;

   ELSE

   o_status_msg:= 'SWMS is Currently Under Maintanance, Please Send the message Later';

   pl_text_log.ins_msg('INFO', 'pl_xml_matrix_in.SYM15',
                       'Printing: Error_msg: '||o_status_msg,
                        NULL, NULL);

   RETURN 1;

   END IF;
EXCEPTION
WHEN validation_error THEN
   pl_text_log.ins_msg('INFO', 'pl_xml_matrix_in.SYM15',
                       'Printing: Error_msg: '||o_status_msg,
                        NULL, NULL);
     UPDATE matrix_in
        SET record_status = 'F',
            error_msg     = o_status_msg
      WHERE mx_msg_id     = l_mx_msg_id;
    COMMIT;
  RETURN 1;
WHEN OTHERS THEN
   pl_text_log.ins_msg('INFO', 'pl_xml_matrix_in.SYM15',
                       'Printing: Error_msg: '||SQLERRM,
                        NULL, NULL);
  o_status_msg:= 'FAILED';
  RETURN 1;
END sym15_bulk_notification;

FUNCTION sym16_order_response(
    i_msg_time_obj           IN msg_time_obj,
    i_batch_id               IN VARCHAR2,
    i_order_resp_details     IN order_response_details_obj,
    o_status_msg            OUT VARCHAR2)
  RETURN NUMBER
/*===========================================================================================================
  -- Function
  -- sym16_order_response
  --
  -- Description
  --   This Function collects the SYM-16 data from Symbotic.
  --   This Function validates the data received and takes Ownership
  --   of the Request received from Symbotic.
  --
  -- Modification History
  --
  -- Date                User                  Version            Defect  Comment
  -- 01/06/14        Sunil Ontipalli             1.0              Initial Creation
  ============================================================================================================*/
IS
  --------------------------local variables-----------------------------
  l_msg_time_obj           MSG_TIME_OBJ;
  l_mx_msg_id              swms.matrix_in.mx_msg_id%TYPE;
  l_msg_time               TIMESTAMP;
  l_batch_id               swms.matrix_in.batch_id%TYPE;
  l_back_table             order_response_details_table;
  l_order_id               swms.matrix_in.order_id%TYPE;
  l_sku                    swms.matrix_in.prod_id%TYPE;
  l_action_code            swms.matrix_in.action_code%TYPE;
  l_reason_code            swms.matrix_in.reason_code%TYPE;
  l_case_qty               swms.matrix_in.case_qty%TYPE;
  l_count_no               NUMBER;
  l_flag                   VARCHAR2(1);
  validation_error         EXCEPTION;
  l_interface_flag         VARCHAR2(1);
  l_reason                 VARCHAR2(100);
  l_err_count              NUMBER DEFAULT 0;

BEGIN

   pl_text_log.ins_msg('INFO', 'pl_xml_matrix_in.SYM16',
                     'SYM16: Message delivery started batch_id: '||i_batch_id,
                      NULL, NULL);

   check_webservice(i_interface_ref_doc  => 'SYM16',
                    o_active_flag        => l_interface_flag,
                    o_reason             => l_reason);

   IF l_interface_flag = 'Y' THEN

     ------------------Initializing the local variables-----------------------
      l_msg_time_obj           := i_msg_time_obj;
      l_batch_id               := i_batch_id;
      l_back_table             := i_order_resp_details.order_response_details_data;

     -----------Extracting the object Values into the variables----------------
      l_mx_msg_id              := l_msg_time_obj.msg_meta_data(1).message_id;
      l_msg_time               := TO_TIMESTAMP(l_msg_time_obj.msg_meta_data(1).time_stamp,'YYYY-MM-DD HH24:MI:SS');

      pl_text_log.ins_msg('INFO', 'pl_xml_matrix_in.SYM16',
                          'SYM16: Printing: Message Id: '||l_mx_msg_id,
                           NULL, NULL);

      ---------------Validating the data as per the bussiness-------------------
      -------Validating Matrix message id and will not accept null values-------
      IF l_mx_msg_id  = TO_CHAR(0) THEN
        l_err_count  := l_err_count + 1;
        IF l_err_count = 1 THEN
        o_status_msg := 'FAILED: Matrix_msg_id is 0 and Invalid';
        END IF;
        --RAISE validation_error;
      ELSIF l_mx_msg_id IS NULL THEN
        l_err_count  := l_err_count + 1;
        IF l_err_count = 1 THEN
        o_status_msg    := 'FAILED: Matrix_msg_id is Null and Invalid';
        END IF;
        --RAISE validation_error;
      END IF;

      ---Validating Matrix message timestamp and will not accept null values----
      IF l_msg_time  IS NULL THEN
        l_err_count  := l_err_count + 1;
        IF l_err_count = 1 THEN
        o_status_msg := 'FAILED: Matrix_msg_timestamp is Null and Invalid';
        END IF;
        --RAISE validation_error;
      END IF;

      /*
      -------Validating Batch ID, must be valid and Assigned to Symbotic---------
      BEGIN
        SELECT pl_matrix_common.sos_batch_to_matrix_yn(l_batch_id)
          INTO l_flag
          FROM dual;
      EXCEPTION
      WHEN NO_DATA_FOUND THEN
        o_status_msg:= 'FAILED: Verifying the Batch';
        RETURN 1;
        RAISE validation_error;
      END;
      IF l_flag   = 'N' THEN
        o_status_msg := 'FAILED: Invalid Batch Id';
        RAISE validation_error;
      END IF;
      */

      --------------------Inserting the data after validations------------------
      BEGIN
        INSERT
          INTO matrix_in
          (
            mx_msg_id, msg_time, interface_ref_doc, rec_ind,
            batch_id
          )
        VALUES
          (
            l_mx_msg_id, l_msg_time, 'SYM16', 'H',
            l_batch_id
          );
      EXCEPTION
      WHEN OTHERS THEN
        ROLLBACK;
        o_status_msg:= 'FAILED: Problem Occured during Insert';
        RETURN 1;
      END;

      FOR I IN l_back_table.first..l_back_table.last

       LOOP

        l_order_id       :=  l_back_table(I).order_id;
        l_sku            :=  l_back_table(I).sku;
        l_action_code    :=  l_back_table(I).action_code;
        l_reason_code    :=  l_back_table(I).reason_code;
        l_case_qty       :=  l_back_table(I).case_quantity;

      -----------------Validating Prod Id and must exist in SWMS----------------
        /* BEGIN
           SELECT COUNT(*)
             INTO l_count_no
             FROM inv
            WHERE prod_id   = l_sku;
         EXCEPTION
         WHEN NO_DATA_FOUND THEN
           o_status_msg:= 'FAILED: Executing Count';
         RETURN 1;
         END;

         IF l_count_no   = 0 THEN
          ROLLBACK;
          o_status_msg := 'FAILED: Invalid Product Id';
          RAISE validation_error;
         END IF;
      */

         pl_text_log.ins_msg('INFO', 'pl_xml_matrix_in.SYM16',
                             'SYM16: Printing: Order Id: '||l_order_id||'Printing: Reason Code: '||l_reason_code,
                              NULL, NULL);
          BEGIN
            INSERT
              INTO matrix_in
                (
                 mx_msg_id, msg_time, interface_ref_doc, rec_ind,
                 order_id, prod_id, action_code, reason_code, case_qty, batch_id
                )
            VALUES
               (
                l_mx_msg_id, l_msg_time, 'SYM16', 'D',
                l_order_id, l_sku, l_action_code, l_reason_code, l_case_qty, l_batch_id
               );
          EXCEPTION
           WHEN OTHERS THEN
            ROLLBACK;
            o_status_msg:= 'FAILED: Problem Occured during Insert';
            RETURN 1;
          END;

       END LOOP;

       COMMIT;
       
      IF l_err_count >= 1 THEN
        RAISE validation_error;
      END IF;

-------------Submitting a Job to initiate the SWMS processing----------------
      BEGIN
        dbms_scheduler.create_job
        (
          job_name        =>  'SYM16_'||l_mx_msg_id,
          job_type        =>  'PLSQL_BLOCK',
          job_action      =>  'BEGIN pl_mx_stg_to_swms.sym16_case_skip_update('||l_mx_msg_id||'); END;',
          start_date      =>  SYSDATE,
          enabled         =>  TRUE,
          auto_drop       =>  TRUE,
          comments        =>  'Submiting a job to invoke SYM05 webservice');
      END;

        o_status_msg:= 'SUCCESS';
        RETURN 0;

   ELSE

    o_status_msg:= 'SWMS is Currently Under Maintanance, Please Send the message Later';

    pl_text_log.ins_msg('INFO', 'pl_xml_matrix_in.SYM16',
                        'SYM16: Printing: Error: '||o_status_msg,
                         NULL, NULL);

   RETURN 1;

   END IF;
EXCEPTION
WHEN validation_error THEN
ROLLBACK;
  pl_text_log.ins_msg('INFO', 'pl_xml_matrix_in.SYM16',
                     'SYM16: Printing: Error: '||o_status_msg,
                      NULL, NULL);
     UPDATE matrix_in
        SET record_status = 'F',
            error_msg     = o_status_msg
      WHERE mx_msg_id     = l_mx_msg_id;
    COMMIT;
  RETURN 1;

WHEN OTHERS THEN
ROLLBACK;
  o_status_msg:= 'FAILED';
  pl_text_log.ins_msg('INFO', 'pl_xml_matrix_in.SYM16',
                     'SYM16: Printing: Error: '||SQLERRM,
                      NULL, NULL);
  RETURN 1;
END sym16_order_response;

FUNCTION sym17_labor_management(
    i_msg_time_obj          IN msg_time_obj,
    i_interface_type        IN VARCHAR2,
    i_user_id               IN VARCHAR2,
    i_cell_id               IN VARCHAR2,
    i_event_timestamp       IN VARCHAR2,
    i_pallet_id_list        IN pallet_id_list_obj DEFAULT NULL,
    i_inducted_qty          IN NUMBER,
    i_reworked_qty          IN NUMBER,
    i_verified_qty          IN NUMBER,
    i_rejected_qty          IN NUMBER,
    o_status_msg           OUT VARCHAR2)
  RETURN NUMBER
/*===========================================================================================================
  -- Function
  -- sym17_labor_management
  --
  -- Description
  --   This Function collects the SYM-17 data from Symbotic.
  --   This Function validates the data received and takes Ownership
  --   of the Request received from Symbotic.
  --
  -- Modification History
  --
  -- Date                User                  Version            Defect  Comment
  -- 01/09/15        Sunil Ontipalli             1.0              Initial Creation
  ============================================================================================================*/
IS
 --------------------------local variables-----------------------------
  l_msg_time_obj           MSG_TIME_OBJ;
  l_mx_msg_id              swms.matrix_in.mx_msg_id%TYPE;
  l_msg_time               TIMESTAMP;
  l_interface_type         swms.matrix_in.interface_type%TYPE;
  l_user_id                swms.matrix_in.user_id%TYPE;
  l_cell_id                swms.matrix_in.cell_id%TYPE;
  l_event_timestamp        swms.matrix_in.event_timestamp%TYPE;
  l_back_table             pallet_id_list_table;
  l_inducted_qty           swms.matrix_in.qty_inducted%TYPE;
  l_reworked_qty           swms.matrix_in.reworked_qty%TYPE;
  l_verified_qty           swms.matrix_in.verified_qty%TYPE;
  l_rejected_qty           swms.matrix_in.rejected_qty%TYPE;
  l_pallet_id              swms.matrix_in.pallet_id%TYPE;
  l_count_no               NUMBER;
  l_flag                   VARCHAR2(1);
  validation_error         EXCEPTION;
  l_interface_flag         VARCHAR2(1);
  l_reason                 VARCHAR2(100);
  l_rec_ind                VARCHAR2(1);
  l_err_count              NUMBER DEFAULT 0;

BEGIN

   pl_text_log.ins_msg('INFO', 'pl_xml_matrix_in.SYM17',
                       'SYM17: Message delivery started User Id:'||i_user_id||' Cell Id: '||i_cell_id,
                        NULL, NULL);

   check_webservice(i_interface_ref_doc  => 'SYM17',
                    o_active_flag        => l_interface_flag,
                    o_reason             => l_reason);

   IF l_interface_flag = 'Y' THEN

     ------------------Initializing the local variables-----------------------
      l_msg_time_obj           := i_msg_time_obj;
      l_interface_type         := i_interface_type;
      l_user_id                := i_user_id;
      l_cell_id                := i_cell_id;
      l_event_timestamp        := TO_TIMESTAMP(i_event_timestamp,'YYYY-MM-DD HH24:MI:SS');
      l_inducted_qty           := i_inducted_qty;
      l_reworked_qty           := i_reworked_qty;
      l_verified_qty           := i_verified_qty;
      l_rejected_qty           := i_rejected_qty;

      IF l_interface_type = 'START' OR l_interface_type = 'COMPLETE' THEN
         l_back_table             := i_pallet_id_list.pallet_id_list_data;
         l_rec_ind                := 'H';
      ELSE
         l_rec_ind                := 'S';
      END IF;
     -----------Extracting the object Values into the variables----------------
      l_mx_msg_id              := l_msg_time_obj.msg_meta_data(1).message_id;
      l_msg_time               := TO_TIMESTAMP(l_msg_time_obj.msg_meta_data(1).time_stamp,'YYYY-MM-DD HH24:MI:SS');

      pl_text_log.ins_msg('INFO', 'pl_xml_matrix_in.SYM17',
                          'SYM17: Printing Msg Id:'||l_mx_msg_id,
                           NULL, NULL);

      ---------------Validating the data as per the bussiness-------------------
      -------Validating Matrix message id and will not accept null values-------
      IF l_mx_msg_id  = TO_CHAR(0) THEN
        l_err_count  := l_err_count + 1;
        IF l_err_count = 1 THEN
        o_status_msg := 'FAILED: Matrix_msg_id is 0 and Invalid';
        END IF;
        --RAISE validation_error;
      ELSIF l_mx_msg_id IS NULL THEN
        l_err_count  := l_err_count + 1;
        IF l_err_count = 1 THEN
        o_status_msg    := 'FAILED: Matrix_msg_id is Null and Invalid';
        END IF;
        --RAISE validation_error;
      END IF;

      ---Validating Matrix message timestamp and will not accept null values----
      IF l_msg_time  IS NULL THEN
        l_err_count  := l_err_count + 1;
        IF l_err_count = 1 THEN
        o_status_msg := 'FAILED: Matrix_msg_timestamp is Null and Invalid';
        END IF;
        --RAISE validation_error;
      END IF;


      --------------------Inserting the data after validations------------------
      BEGIN
        INSERT
          INTO matrix_in
          (
            mx_msg_id, msg_time, interface_ref_doc, rec_ind,
            interface_type, user_id, cell_id, event_timestamp, qty_inducted,
            reworked_qty, verified_qty, rejected_qty
          )
        VALUES
          (
            l_mx_msg_id, l_msg_time, 'SYM17', l_rec_ind,
            l_interface_type, l_user_id, l_cell_id, l_event_timestamp, l_inducted_qty,
            l_reworked_qty, l_verified_qty, l_rejected_qty
          );
      EXCEPTION
      WHEN OTHERS THEN
        ROLLBACK;
        o_status_msg:= 'FAILED: Problem Occured during Header Insert';
        RETURN 1;
      END;

      IF l_interface_type = 'START' OR l_interface_type = 'COMPLETE' THEN

      FOR I IN l_back_table.first..l_back_table.last

       LOOP

        l_pallet_id       :=  l_back_table(I).pallet_id;

        pl_text_log.ins_msg('INFO', 'pl_xml_matrix_in.SYM17',
                            'SYM17: Printing Pallet Id:'||l_pallet_id,
                             NULL, NULL);
    /*
      -----------------Validating Prod Id and must exist in SWMS----------------
         BEGIN
           SELECT COUNT(*)
             INTO l_count_no
             FROM inv
            WHERE logi_loc   = l_pallet_id;
         EXCEPTION
         WHEN NO_DATA_FOUND THEN
           o_status_msg:= 'FAILED: Executing Count';
         RETURN 1;
         END;

         IF l_count_no   = 0 THEN
          ROLLBACK;
          o_status_msg := 'FAILED: Invalid Pallet Id';
          RAISE validation_error;
         END IF;
      */
          BEGIN
            INSERT
              INTO matrix_in
                (
                 mx_msg_id, msg_time, interface_ref_doc, rec_ind,
                 pallet_id
                )
            VALUES
               (
                l_mx_msg_id, l_msg_time, 'SYM17', 'D',
                l_pallet_id
               );
          EXCEPTION
           WHEN OTHERS THEN
            ROLLBACK;
            o_status_msg:= 'FAILED: Problem Occured during Detail Insert';
            RETURN 1;
          END;

       END LOOP;

      END IF;

      COMMIT;
      
      IF l_err_count >= 1 THEN
        RAISE validation_error;
      END IF;
      
        o_status_msg:= 'SUCCESS';
        RETURN 0;

   ELSE

    o_status_msg:= 'SWMS is Currently Under Maintanance, Please Send the message Later';

    pl_text_log.ins_msg('INFO', 'pl_xml_matrix_in.SYM17',
                        'SYM17: Printing: Error: '||o_status_msg,
                         NULL, NULL);
   RETURN 1;

   END IF;
EXCEPTION
WHEN validation_error THEN
ROLLBACK;
  pl_text_log.ins_msg('INFO', 'pl_xml_matrix_in.SYM17',
                      'SYM17: Printing: Error: '||o_status_msg,
                       NULL, NULL);
     UPDATE matrix_in
        SET record_status = 'F',
            error_msg     = o_status_msg
      WHERE mx_msg_id     = l_mx_msg_id;
    COMMIT;
  RETURN 1;
WHEN OTHERS THEN
ROLLBACK;
  pl_text_log.ins_msg('INFO', 'pl_xml_matrix_in.SYM17',
                      'SYM17: Printing: Error: '||SQLERRM,
                       NULL, NULL);
  o_status_msg:= 'FAILED';
  RETURN 1;
END sym17_labor_management;
END pl_xml_matrix_in;
/

CREATE OR REPLACE PUBLIC SYNONYM pl_xml_matrix_in FOR swms.pl_xml_matrix_in;

grant execute on swms.pl_xml_matrix_in to swms_user;

grant execute on swms.pl_xml_matrix_in to swms_mx;
