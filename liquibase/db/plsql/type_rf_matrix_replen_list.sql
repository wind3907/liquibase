/*=============================================================================================
  Types for the matrix replenishment list
  Date           Designer         Comments
  -----------    ---------------  --------------------------------------------------------
  02-JUL-2014    sred5131         Initial Version
  =============================================================================================*/
CREATE OR REPLACE
TYPE      swms.replen_list_inner_type FORCE AS OBJECT(
          dest_loc          VARCHAR2(10),
          qty               NUMBER(7),
          task_id           VARCHAR2(10),
          prod_id           VARCHAR2(10),
          descrip           VARCHAR2(100),
          mfg_sku           VARCHAR2(14),
          cust_pref_vendor  VARCHAR2(10),
          case_no           VARCHAR2(10),
          logi_loc          VARCHAR2(10),
          brand             VARCHAR2(7),
          exp_date          VARCHAR2(10),
          pallet_type       VARCHAR2(2),
          uom               NUMBER(2),
          erm_id            VARCHAR2(12),
          erm_date          VARCHAR2(10),
          pack              VARCHAR2(4),
          prod_size         VARCHAR2(6),
          constructor function replen_list_inner_type(
                                                         dest_loc VARCHAR2,
                                                         qty NUMBER,
                                                         task_id VARCHAR2,
                                                         prod_id VARCHAR2,
                                                         descrip VARCHAR2,
                                                         mfg_sku VARCHAR2,
                                                         cust_pref_vendor VARCHAR2,
                                                         case_no VARCHAR2,
                                                         logi_loc VARCHAR2,
                                                         brand VARCHAR2,
                                                         exp_date VARCHAR2,
                                                         pallet_type VARCHAR2,
                                                         uom NUMBER,
                                                         erm_id VARCHAR2,
                                                         erm_date VARCHAR2,
                                                         pack VARCHAR2,
                                                         prod_size VARCHAR2
                                                         ) RETURN SELF AS RESULT
);
/

CREATE OR REPLACE TYPE BODY swms.replen_list_inner_type AS
    constructor function replen_list_inner_type(
        dest_loc VARCHAR2,
        qty NUMBER,
        task_id VARCHAR2,
        prod_id VARCHAR2,
        descrip VARCHAR2,
        mfg_sku VARCHAR2,
        cust_pref_vendor VARCHAR2,
        case_no VARCHAR2,
        logi_loc VARCHAR2,
        brand VARCHAR2,
        exp_date VARCHAR2,
        pallet_type VARCHAR2,
        uom NUMBER,
        erm_id VARCHAR2,
        erm_date VARCHAR2,
        pack VARCHAR2,
        prod_size VARCHAR2
        ) RETURN SELF AS RESULT
        IS
        BEGIN
            SELF.dest_loc := dest_loc;
            SELF.qty := NVL(qty, 0);
            SELF.task_id := task_id;
            SELF.prod_id := prod_id;
            SELF.descrip := descrip;
            SELF.mfg_sku := mfg_sku;
            SELF.cust_pref_vendor := cust_pref_vendor;
            SELF.case_no := case_no;
            SELF.logi_loc := logi_loc;
            SELF.brand := brand;
            SELF.exp_date := exp_date;
            SELF.pallet_type := pallet_type;
            SELF.uom := NVL(uom, 0);
            SELF.erm_id := erm_id;
            SELF.erm_date := erm_date;
            SELF.pack := pack;
            SELF.prod_size := prod_size;
            RETURN;
        END;
END;
/

CREATE OR REPLACE
TYPE      replen_list_result_table1 FORCE
    AS TABLE OF swms.replen_list_inner_type;
/

CREATE OR REPLACE
TYPE      swms.replen_list_result_record FORCE AS OBJECT(
          priority        NUMBER(2),
          type            VARCHAR2(3),
          src_loc         VARCHAR2(10),
          pallet_id       VARCHAR2(18),
          ti              NUMBER(4),
          hi              NUMBER(4),
          print_lpn       VARCHAR2(1),
          show_travel_key VARCHAR2(1),
          innertable    swms.replen_list_result_table1,
          constructor function replen_list_result_record(
              priority NUMBER,
              type VARCHAR2,
              src_loc VARCHAR2,
              pallet_id VARCHAR2,
              ti NUMBER,
              hi NUMBER,
              print_lpn VARCHAR2,
              show_travel_key VARCHAR2,
              innertable      swms.replen_list_result_table1
              ) RETURN SELF AS RESULT
);
/

CREATE OR REPLACE TYPE BODY swms.replen_list_result_record AS
    constructor function replen_list_result_record(
        priority NUMBER,
        type VARCHAR2,
        src_loc VARCHAR2,
        pallet_id VARCHAR2,
        ti NUMBER,
        hi NUMBER,
        print_lpn VARCHAR2,
        show_travel_key VARCHAR2,
        innertable swms.replen_list_result_table1
        ) RETURN SELF AS RESULT
        IS
        BEGIN
            SELF.priority := NVL(priority,0);
            SELF.type := type;
            SELF.src_loc := src_loc;
            SELF.pallet_id := pallet_id;
            SELF.ti := NVL(ti,0);
            SELF.hi := NVL(hi,0);
            SELF.print_lpn := print_lpn;
            SELF.show_travel_key := show_travel_key;
            SELF.innertable := innertable;
            RETURN;
        END;
END;
/

CREATE OR REPLACE
TYPE      replen_list_result_table FORCE
    AS TABLE OF swms.replen_list_result_record;
/

CREATE OR REPLACE TYPE swms.replen_list_result_obj Force
    AS OBJECT(result_table  swms.replen_list_result_table);
/

GRANT EXECUTE ON swms.replen_list_result_obj TO swms_user;