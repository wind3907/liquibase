CREATE OR REPLACE PACKAGE pl_swms_sts_routeout
AS
/****************************************************************************
** File:       pl_swms_sts_routeout.sql
**
** Desc: Package to send STS_Route_Out data from SWMS to STS
**
**
** Modification History:
**    Date        Designer           Comments
**    -------- -------- ----------------------------------------------------
**    19-Nov-2018 Vishnupriya K.     Initial version
**    22-Feb-2019 Vishnuprita K.     Logic added to handle stuck routes. 
**    22-Apr-2019 Vishnupriya K.     Logic added to eliminate < from order_no 
**                                   and remove char(26)that comes in from erp 
**    01-05-2021  Vishnupriya K.     Jira 3258-Handle extra space issue for ALternate stop number
**                                   add check to process only when the entire route data is ready
**    03-10-2021  Vishnupriya K.     Extra space issue due to the replace of #, % etc is handled 
****************************************************************************/

  FUNCTION swms_sts_xmlgen(
      p_route VARCHAR2, p_batch VARCHAR2, p_date varchar2)
    RETURN CLOB ;
  PROCEDURE send_route;
END pl_swms_sts_routeout;
/
CREATE OR REPLACE PACKAGE BODY pl_swms_sts_routeout
AS
  FUNCTION swms_sts_xmlgen(
      p_route VARCHAR2, p_batch VARCHAR2, p_date varchar2)
    RETURN CLOB
  IS
    resultset_xml CLOB := NULL;
    resultset_xml_cw CLOB := NULL;
    l_offset        NUMBER DEFAULT 1;
    l_st_count      NUMBER      :=0;
    l_bc_count      NUMBER      :=0;
    l_di_count      NUMBER      :=0;
    l_cw_flag       NUMBER      :=0;
    l_sr_count      NUMBER      :=0;
    l_al_count      NUMBER      :=0;
    l_st_lp_count   NUMBER      :=0;
    l_bc_lp_count   NUMBER      :=0;
    l_di_lp_count   NUMBER      :=0;
    l_iv_lp_count   NUMBER      :=0;
    l_sr_lp_count   NUMBER      :=0;
    l_al_lp_count   NUMBER      :=0;
    l_curr_stop     NUMBER      := 0;
    l_prv_stop      NUMBER      := 0;
    l_batch         VARCHAR2(20);
    st_tag_set      NUMBER      := 0;
    l_di_tag        NUMBER      :=0;
    l_prv_rec_type  VARCHAR2(5) := 'none';
    l_curr_rec_type VARCHAR2(5) := 'none';
    l_ship_name     VARCHAR2(250);
    l_ship_address  VARCHAR2(250);
    d_counter       NUMBER :=0;
    s_counter       NUMBER :=0;
    b_counter       NUMBER :=0;
    l_dcid          NUMBER;
    l_tmplt_id      VARCHAR2(50);
    l_tmplt_txt     VARCHAR2(10000) :='';
    
    CURSOR c1
    IS
      SELECT RECORD_TYPE,
        ROUTE_NO ,
        ROUTE_DATE,
        DRIVER_ID,
        TRAILER,
        TRAILER_LOC,
        DECODE(USEITEMSEQ, 'Y', 'True', 'False') USEITEMSEQ,
        DECODE(USEITEMZONE, 'Y', 'True', 'False') USEITEMZONE,
        REPLACE(REPLACE(REPLACE(REPLACE(INSTRUCTIONS,chr(13),''), chr(10), ''),'<', ' '), '>', ' ') INSTRUCTIONS,
        DECODE(CHECKIN_ASSETS_IND, 'Y', 'True', 'False') CHECKIN_ASSETS_IND,
        STOP_NO,
        CUST_ID,
        replace(replace(SHIP_NAME,'<', ' '), '>', ' ') SHIP_NAME,
        replace(replace(SHIP_ADDR1,'<', ' '), '>', ' ') SHIP_ADDR1,
        replace(replace(SHIP_ADDR2,'<', ' '), '>', ' ') SHIP_ADDR2,
        REPLACE(REPLACE(REPLACE(REPLACE(STOP_CSZ,chr(13),''), chr(10), ''),'<', ' '), '>', ' ') STOP_CSZ,
        REPLACE(REPLACE(REPLACE(REPLACE(CUST_CONTACT,chr(13),''), chr(10), ''),'<', ' '), '>', ' ') CUST_CONTACT,
        STOP_PHONE,
        STOP_ALERTS,
        STOP_DIRECTIONS,
        to_char(ALT_STOP_NO,'00.00') ALT_STOP_NO,
        MANIFEST_NO,
        LOC_SCAN_TIMEOUT,
        INVOICE_PRINT_MODE,
        STRATTIFICATION,
        DELIVERY_DAYS,
        INVOICE_NO,
        REPLACE(REPLACE(REPLACE(REPLACE(TERMS,chr(13),''), chr(10), ''),'<', ' '), '>', ' ') TERMS,
        DELIV_TYPE,
        SALESPERSON_ID,
        REPLACE(REPLACE(REPLACE(REPLACE(SALESPERSON,chr(13),''), chr(10), ''),'<', ' '), '>', ' ') SALESPERSON,
        nvl(INVOICE_CUBE,0) INVOICE_CUBE,
        REMIT_TO_ADDR1,
        REMIT_TO_ADDR2,
        nvl(INVOICE_WGT,0) INVOICE_WGT,
        nvl(INVOICE_AMT,0) INVOICE_AMT ,
        INVOICE_TYPE,
        INVOICE_PRINT_TYPE,
        DECODE(SHOW_PRINCE_IND,'Y', 'True', 'False') SHOW_PRINCE_IND,
        DECODE(TAX_IND,'Y', 'True', 'False') TAX_IND,
        PO_NO,
        TAX_ID,
        SALES_PHONE,
        TAX,
        SEQ_NO,
        PROD_ID,
        REPLACE(REPLACE(REPLACE(REPLACE(DESCRIP,chr(13),''), chr(10), ''),'<', ' '), '>', ' ') DESCRIP,
        nvl(QTY,0) QTY,
        CREDIT_REF_NO,
        ORIG_WMS_ITEM_TYPE,
        WMS_ITEM_TYPE,
        DISPOSITION,
        RETURN_REASON_CD,
        RETURN_PROD_ID,
        ORDD_SEQ,
        ITEM_ID,
        PARENT_ITEM_ID,
        nvl(PLANNED_QTY,0) PLANNED_QTY,
        DECODE(HIGH_QTY,'Y', 'True', 'False') HIGH_QTY,
        DECODE(BULK_ITEM,'Y', 'True', 'False') BULK_ITEM,
        ITEM_CLASS,
        replace(replace(ORDER_NO, '<',''),'>', '') ORDER_NO, 
        ZONE_NAME,
        DECODE(ALLOW_UNLOAD,'Y', 'True', 'False') ALLOW_UNLOAD,
        DECODE(UNLOAD_PARENT,'Y', 'True', 'False') UNLOAD_PARENT,
        DECODE(SPLITFLAG,'Y', 'True', 'False') SPLITFLAG,
        DECODE(CATCH_WEIGHT_FLAG,'Y', 'True', 'False') CATCH_WEIGHT_FLAG,
        ALT_PROD_ID,
        nvl(PACK,0) PACK,
        PROD_SIZE,
        COMPARTMENT,
        INVOICE_GROUP,
        DECODE(OTHERZONE_FLOAT,'Y', 'True', 'False') OTHERZONE_FLOAT,
        DECODE(LOT_NO_IND,'Y', 'True', 'False') LOT_NO_IND,
        BARCODE,
        CATCH_WEIGHTS,
        IN_ROUTE_SPLIT_MODE,
        SPLIT_PRICE,
        SPLIT_TAX,
        PROMOATION_DESC,
        PROMOATION_DISCOUNT,
        ADD_CHG_DESC,
        ADD_CHG_AMT,
        ADD_INVOICE_DESC,
        FLOAT_ID,
        ORDER_LINE_STATE,
        SCHED_ARRIV_TIME,
        SCHED_DEPT_TIME,
        STOP_OPEN_TIME,
        STOP_CLOSE_TIME,
        DELIVERY_WINDOW_START,
        DELIVERY_WINDOW_END,
        DUE_DATE,
        nvl(GS1_BARCODE_FLAG, 'False') GS1_BARCODE_FLAG
      FROM TABLE
        (SELECT CAST(pl_sts_interfaces.swms_sts_func AS STS_ROUTE_OUT_OBJECT_TABLE) FROM dual  )
      WHERE route_no = p_route
      and record_type not in ('RB');
        
    CURSOR c2(p_tmplt_id VARCHAR2)
    IS 
      SELECT DECODE(tag_value, '/','','<'
        ||trim(tag_name))
        ||DECODE(tag_value, '/','','>')
        ||DECODE(tag_value, '/','',trim(NVL(tag_value,'')))
        ||DECODE(tag_value, NULL, '', '</'
        ||trim(tag_name)
        ||'>') txt
      FROM sts_templates
      WHERE tname = p_tmplt_id
      order by sequence_no; --
      
    CURSOR c_cw(p_route varchar2, p_prod_id varchar2,p_ordd_seq varchar2 )
    is
     select catch_weights, prod_id
        from sts_route_out a
        where route_no = p_route
        and prod_id = p_prod_id
        and record_type ='BC'
        and substr(barcode,1,length(p_ordd_seq))= p_ordd_seq
        and nvl(catch_weights,0) <> 0
        and record_status in   ('Q', 'N')
        order by barcode; 
      
  BEGIN
    -- find counts of each type of records
    -- check count and add the end tags
    -- add route end tage after the loop
   --  dbms_output.put_line('in xmlgen func:'||p_route);
        
     SELECT COUNT(*)
    INTO l_st_count
    FROM TABLE
        (SELECT CAST(pl_sts_interfaces.swms_sts_func AS STS_ROUTE_OUT_OBJECT_TABLE) FROM dual  )
    WHERE route_no = p_route
    and record_type='ST';
    
    
    SELECT COUNT(*)
    INTO l_bc_count
    FROM TABLE
        (SELECT CAST(pl_sts_interfaces.swms_sts_func AS STS_ROUTE_OUT_OBJECT_TABLE) FROM dual  )
      WHERE route_no = p_route
    AND record_type='BC';

    
  
    BEGIN
      SELECT trim(attribute_value)
      INTO l_dcid
      FROM maintenance
      WHERE 1         =1
      AND component   ='DCID'
      AND application = 'SWMS'
      AND attribute   = 'MACHINE';
    EXCEPTION
    WHEN OTHERS THEN
      l_dcid := 000;
      pl_log.ins_msg('INFO','swms_sts_xmlgen', 'cannot find dcid',  nvl(SQLCODE,0), nvl(SQLERRM,' '), 'STS', 'pl_swms_sts_routeout', 'Y');
   END;
   BEGIN
      SELECT trim(attribute_value)
      INTO l_tmplt_id
      FROM maintenance
      WHERE 1         =1
      AND component   ='STS_TMPLT'
      AND application = 'SWMS'
      AND attribute   = 'MACHINE';
    EXCEPTION
    WHEN OTHERS THEN
      l_tmplt_id := 'temp_eng';
      pl_log.ins_msg('INFO','swms_sts_xmlgen', 'cannot find sts_tmplt',  nvl(SQLCODE,0), nvl(SQLERRM,' '), 'STS', 'pl_swms_sts_routeout', 'Y');
     
    END;
    BEGIN
      FOR j IN c2(l_tmplt_id)
      LOOP
        l_tmplt_txt := l_tmplt_txt||j.txt;
      END LOOP;
    EXCEPTION
    WHEN OTHERS THEN
      NULL;
    END;
    FOR i IN c1
    LOOP
    
     --   dbms_output.put_line('in xmlgen func main loop');
    
      l_curr_rec_type := i.record_type;
      IF i.record_type ='RT' THEN
      
      
        resultset_xml := concat(resultset_xml,
        '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:sae="http://SAE.DriverPro.CommService">'||''|| 
        '<soapenv:Header/>'||''|| '<soapenv:Body>'||''|| '<sae:ImportHostData>'||''|| '<sae:input>'||''|| '<DriverProImport>'||''|| 
        '<Routes>'||''|| '<Route>'||''|| 
        '<DCID>'||l_dcid||'</DCID>'||''|| 
        '<RouteID>'|| i.Route_no||'</RouteID>'||''|| 
        '<ScheduledDate>'||i.Route_date||'</ScheduledDate>'||''|| 
        '<DriverID>'||i.Driver_id||'</DriverID>'||''|| 
        '<TrailerID>'||i.Trailer||'</TrailerID>'||''|| 
        '<TrailerLocation>'||i.Trailer_loc||'</TrailerLocation>'||''|| 
        '<UseItemSequenceIndicator>'||i.UseItemSeq||'</UseItemSequenceIndicator>'||''|| 
        '<UseItemZoneIndicator>'||i.UseItemZone||'</UseItemZoneIndicator>'||''|| 
        '<RouteInstructions>'||i.Instructions ||'</RouteInstructions>'||''|| 
        '<InvoiceMessage>'||i.ADD_INVOICE_DESC ||'</InvoiceMessage>'||''|| 
        '<CheckInAssetsIndicator>'||i.CheckIn_Assets_Ind ||'</CheckInAssetsIndicator>'|| '');
        
      END IF;
      IF l_prv_rec_type = 'DI' AND l_curr_rec_type NOT IN ('none','DI') THEN
        resultset_xml  := concat(resultset_xml,'</DeliveryItems>'||'');
      END IF;
      IF l_prv_rec_type = 'IV' AND l_curr_rec_type NOT IN ('none','IV') THEN
        resultset_xml  := concat(resultset_xml,'</Invoices>'||'');
      END IF;
      IF l_prv_rec_type = 'AD' AND l_curr_rec_type NOT IN ('none','AD') THEN
        resultset_xml  := concat(resultset_xml,'</Adjustments>'||'');
      END IF;
      IF l_prv_rec_type = 'AL' AND l_curr_rec_type NOT IN ('none','AL') THEN
        resultset_xml  := concat(resultset_xml,'</AltLocations>'||'');
      END IF;
      IF l_prv_rec_type = 'SA' AND l_curr_rec_type NOT IN ('none','SA') THEN
        resultset_xml  := concat(resultset_xml,'</StopAssets>'||'');
      END IF;
      IF l_prv_rec_type = 'SR' AND l_curr_rec_type NOT IN ('none','SR') THEN
        resultset_xml  := concat(resultset_xml,'</ScheduledReturns>');
      END IF;
      IF i.record_type   ='ST' THEN
        l_prv_stop      := l_curr_stop;
        l_curr_stop     := i.stop_no;
        l_di_tag        :=0;
        l_ship_name     := NULL;
        l_ship_address  := NULL;
        IF l_st_lp_count = 0 THEN
          resultset_xml := concat(resultset_xml,'<Stops>'||'');
        ELSE
          resultset_xml := concat(resultset_xml, '</Stop>'||'');
        END IF;
        
        resultset_xml := concat(resultset_xml,'<Stop>'||''|| 
        '<StopSequenceNumber>'||i.Stop_no||'</StopSequenceNumber>'||''|| 
        '<StopID>'|| i.cust_ID||'</StopID>'||''|| 
        '<StopName>'|| i.Ship_Name||'</StopName>'||''|| 
        '<StopAddress1>'|| i.Ship_Addr1||'</StopAddress1>'||''|| 
        '<StopAddress2>'|| trim(i.stop_csz) ||'</StopAddress2>'||''|| 
        '<StopContact>'|| trim(i.cust_contact) ||'</StopContact>'||''|| 
        '<StopPhoneNumber>'|| i.Stop_Phone ||'</StopPhoneNumber>'||''|| 
        '<StopAlerts>'|| i.Stop_Alerts ||'</StopAlerts>'||''|| 
        '<AlternateStopNumber>'|| LTRIM(i.Alt_Stop_No) ||'</AlternateStopNumber>'||''|| 
        '<ManifestNumber>'|| i.Manifest_No ||'</ManifestNumber>'||''|| 
        '<ScheduledArrivalTime>'|| i.Sched_Arriv_Time ||'</ScheduledArrivalTime>'||''|| 
        '<ScheduledDepartureTime>'|| i.Sched_Dept_Time ||'</ScheduledDepartureTime>'||''|| 
        '<StopOpenTime>'|| i.Stop_Open_Time ||'</StopOpenTime>'||''||   
        '<StopCloseTime>'|| i.Stop_Close_Time ||'</StopCloseTime>'||''|| 
        '<LocationScanTimeout>'|| NVL(i.loc_scan_timeout,0) ||'</LocationScanTimeout>'||''|| 
        '<InvoicePrintMode>'|| i.Invoice_Print_type ||'</InvoicePrintMode>'||'');
       
        l_st_lp_count := l_st_lp_count +1;
        l_ship_name   := i.Ship_Name;
        l_ship_address:= i.Ship_Addr1;
        s_counter     := s_counter +1;
        d_counter     := 0;
        
      END IF;
      IF i.record_type     ='IV' THEN
        IF l_prv_rec_type <> 'IV' AND l_curr_rec_type ='IV' THEN
          resultset_xml   := concat(resultset_xml,'<Invoices>'||'');
        END IF;
        resultset_xml:= concat(resultset_xml, '<Invoice>'||''|| 
        '<InvoiceNumber>'|| i.Invoice_No||'</InvoiceNumber>'||''|| 
     --   '<CustomerCorporateName>'||l_ship_name||'</CustomerCorporateName>'||''|| 
   --     '<CustomerCorporateAddress1>'||l_ship_address||'</CustomerCorporateAddress1>'||''|| 
        '<InvoiceDate>'||i.route_date||'</InvoiceDate>'||''|| 
        '<Terms>'||i.terms||'</Terms>'||''|| 
        '<DeliveryType>'||i.deliv_type||'</DeliveryType>'||''|| 
        '<SalesCode>'||i.salesperson_id||'</SalesCode>'||''|| 
        '<SalesName>'||i.salesperson||'</SalesName>'||''|| 
        '<InvoiceCube>'||i.Invoice_Cube||'</InvoiceCube>'||''|| 
        '<InvoiceTotalWeight>'||i.Invoice_Wgt||'</InvoiceTotalWeight>'||''|| 
        '<RemitToAddr1>'||i.Remit_To_Addr1||'</RemitToAddr1>'||''|| 
        '<RemitToAddr2>'||i.Remit_To_Addr2||'</RemitToAddr2>'||''|| 
        '<NetInvoiceAmount>'||i.Invoice_amt||'</NetInvoiceAmount>'||''|| 
        '<InvoiceType>'||i.Invoice_Type||'</InvoiceType>'||''|| 
        '<InvoicePrintType>'||i.Invoice_Print_Type||'</InvoicePrintType>'||''|| 
        '<ShowPricesIndicator>'||i.Show_Prince_Ind||'</ShowPricesIndicator>'||''|| 
        '<ShowTaxSubTotal>'||i.tax_ind||'</ShowTaxSubTotal>'||''|| 
        '<PO_Number>'||i.po_no||'</PO_Number>'||''|| 
        '<TaxID>'||i.tax_id||'</TaxID>'||''|| 
        '<SpecialInstructions>'||i.Instructions||'</SpecialInstructions>'||''|| 
        '<DateDue>'||i.due_date||'</DateDue>'|| 
        '<SalesPhone>'||i.Sales_Phone||'</SalesPhone>'||''||'</Invoice>'||'');
        
      END IF;
      IF i.record_type     ='AD' THEN
        IF l_prv_rec_type <> 'AD' AND l_curr_rec_type = 'AD' THEN
          resultset_xml   := concat(resultset_xml,'<Adjustments>'||'');
        END IF;
        
        resultset_xml:= concat(resultset_xml, '<Adjustment>'|| 
        '<Description>'||i.Descrip||'</Description>'|| 
        '<Amount>'||i.Invoice_amt||'</Amount>'|| 
        '<Tax>'||i.Tax||'</Tax>'||'</Adjustment>');
        
      END IF;
      IF i.record_type  ='DI' THEN
       
        
        IF l_prv_stop <> l_curr_stop AND l_di_tag <> 1 THEN
          --  dbms_output.put_line('DI- l_prv_stop <> l_curr_stop'||l_prv_stop ||','||l_curr_stop);
          resultset_xml := concat(resultset_xml,'<DeliveryItems>'||'');
          l_di_tag      := 1 ;
        END IF;
        
        resultset_xml   := concat(resultset_xml, '<DI>'||''|| 
        '<ItemID>'||i.Item_ID||'</ItemID>'||''|| 
        '<ContainerID>'||i.PARENT_ITEM_ID||'</ContainerID>'||''|| 
        '<PlannedQuantity>'||i.Planned_Qty||'</PlannedQuantity>'||''|| 
        '<Quantity>'||i.Qty||'</Quantity>'||''|| 
        '<MultiPickIndicator>'||i.HIGH_QTY||'</MultiPickIndicator>'||''|| 
        '<MultiStopBulkIndicator>'||i.BULK_ITEM||'</MultiStopBulkIndicator>'||''|| 
        '<ItemClass>'||trim(i.Item_Class)||'</ItemClass>'||''|| 
        '<ItemUOM>'||i.wms_item_type||'</ItemUOM>'||''|| 
        '<OrderNumber>'||i.order_no||'</OrderNumber>'||''|| 
        '<ProductID>'||i.Prod_ID||'</ProductID>'||''|| 
        '<ItemDescription>'||i.Descrip||'</ItemDescription>'||''|| 
        '<TrailerZone>'||i.Zone_name||'</TrailerZone>'||''|| 
        '<AllowUnloadIndicator>'||i.Allow_Unload||'</AllowUnloadIndicator>'||''|| 
        '<UnloadParentIndicator>'||i.Unload_Parent||'</UnloadParentIndicator>'||'');
      
        IF i.Invoice_No IS NOT NULL THEN
          resultset_xml := concat(resultset_xml, '<InvoiceNumber>'||i.Invoice_No||'</InvoiceNumber>'||''|| 
          '<InvoiceSequence>'||i.Seq_no||'</InvoiceSequence>'||'');
        END IF;
        
        resultset_xml:= concat(resultset_xml,'<CatchWeightIndicator>'||i.Catch_Weight_flag||'</CatchWeightIndicator>'||''|| 
        '<TaxIndicator>'||trim(i.Tax_Ind)||'</TaxIndicator>'||''|| 
        '<AlternateProductID>'||i.Alt_Prod_ID||'</AlternateProductID>'||''|| 
        '<Size>'||trim(i.prod_size)||'</Size>'||''|| 
        '<SplitsPerCase>'||i.Pack||'</SplitsPerCase>'||''|| 
        '<Compartment>'||i.Compartment||'</Compartment>'||''||
        -- below new columns as per sheet sent by yogi
        '<InvoiceGroup>'||i.INVOICE_GROUP||'</InvoiceGroup>'||''||
        '<OtherZoneContainerIndicator>'||i.OTHERZONE_FLOAT||'</OtherZoneContainerIndicator>'||''||
        '<LotNumberIndicator>'||i.LOT_NO_IND||'</LotNumberIndicator>'||''||
      --  '<CatchWeights>'||i.CATCH_WEIGHTS||'</CatchWeights>'||''||
        '<LocationBarcode>'||i.BARCODE||'</LocationBarcode>'||''||
        '<InRouteSplitMode>'||i.IN_ROUTE_SPLIT_MODE||'</InRouteSplitMode>'||''||
        '<PromotionDesc>'||trim(i.PROMOATION_DESC)||'</PromotionDesc>'||''||
        '<AddChgDesc>'||trim(i.ADD_CHG_DESC)||'</AddChgDesc>'||''||
        '<AddInvoiceDesc>'||trim(i.ADD_INVOICE_DESC)||'</AddInvoiceDesc>'||''||
        '<GS1ScanIndicator>'||i.GS1_BARCODE_FLAG||'</GS1ScanIndicator>'||'');
          
        resultset_xml_cw:='';    
       if upper(i.Catch_Weight_flag) = 'TRUE' then
         resultset_xml_cw:= '<CatchWeights>'; 
            
         For k in c_cw (i.Route_no,i.Prod_ID, i.ordd_seq)
           loop
           
             resultset_xml_cw:= concat(resultset_xml_cw, '<CatchWeight>'||k.CATCH_WEIGHTS||'</CatchWeight>'||'');
          
           End Loop;
           --add the end tags
                     
           resultset_xml_cw:= concat(resultset_xml_cw,'</CatchWeights>'||'</DI>'||'');
          
          -- concat the catchweights to end of DI xml 
           resultset_xml:= concat(resultset_xml,resultset_xml_cw);
       else 
          resultset_xml:= concat(resultset_xml,'</DI>'||'');
       End If;  
          
     
           
        d_counter    := d_counter +1;
        
      END IF;
      
          
      IF i.record_type   ='SR' THEN
  
       IF l_prv_rec_type <> 'SR' AND l_curr_rec_type = 'SR' THEN
          resultset_xml := concat(resultset_xml,'<ScheduledReturns>');
        END IF;
        --
        resultset_xml:= concat(resultset_xml, '<ScheduledReturn>'|| 
        '<PickupSequenceNumber>'||i.seq_no||'</PickupSequenceNumber>'|| 
        '<ProductID>'||i.Prod_id||'</ProductID>'|| 
        '<ItemDescription>'||i.descrip||'</ItemDescription>'|| 
        '<Quantity>'||i.qty||'</Quantity>'|| 
        '<CreditReferenceID>'||i.CREDIT_REF_NO||'</CreditReferenceID>'|| 
        '<OriginalUOM>'||i.orig_wms_item_type||'</OriginalUOM>'|| 
        '<UOM>'||i.wms_item_type||'</UOM>'|| 
        '<Disposition>'||i.Disposition||'</Disposition>'|| 
        '<ReturnReasonCode>'||i.Return_Reason_Cd||'</ReturnReasonCode>'|| 
        '<CreditAmount>'||i.invoice_amt||'</CreditAmount>'|| 
        '<Weight>'||i.invoice_wgt||'</Weight>'||
        '<PickupID>'||i.invoice_no||'</PickupID>'||
        '<Barcode>'||i.ORDD_SEQ||'</Barcode>'||
        '<AddChgDesc>'||i.ADD_CHG_DESC||'</AddChgDesc>'||
        '<Comment>'||i.ADD_INVOICE_DESC||'</Comment>'|| '</ScheduledReturn>');
        
        l_sr_lp_count := l_sr_lp_count +1;
        
      END IF;
      
      IF i.record_type     ='AL' THEN
      
        IF l_prv_rec_type <> 'AL' AND l_curr_rec_type = 'AL' THEN
        
          resultset_xml   := concat(resultset_xml,'<AltLocations>'||'');
          
        END IF;
        
        resultset_xml:= concat(resultset_xml, '<AltLocation>'|| 
        '<Barcode>'||i.Barcode||'</Barcode>'|| 
        '<AltContainerID>'||i.FLOAT_ID||'</AltContainerID>'|| 
        '<AltTrailerZone>'||i.ZONE_NAME||'</AltTrailerZone>'|| '</AltLocation>');
     
      END IF;
      
      IF i.record_type     ='SA' THEN
        IF l_prv_rec_type <> 'SA' AND l_curr_rec_type = 'SA' THEN
          resultset_xml   := concat(resultset_xml,'<StopAssets>'||'');
        END IF;
        
        resultset_xml:= concat(resultset_xml, '<StopAsset>'|| 
        '<Barcode>'||i.Barcode||'</Barcode>'|| 
        '<Quantity>'||i.qty||'</Quantity>'|| '</StopAsset>');
        
      END IF;
      
      IF i.record_type   ='BC' THEN
        IF l_st_lp_count = l_st_count AND st_tag_set <>1 THEN
          resultset_xml := concat(resultset_xml,'</Stop>'||''||'</Stops>'||'');
          st_tag_set    := 1;
        END IF;
        
        IF l_bc_lp_count = 0 THEN
          resultset_xml := concat(resultset_xml,'<Barcodes>'||'');
        END IF;
        
        
        resultset_xml   := concat(resultset_xml, '<BC>'||''|| 
        '<ItemID>'||i.item_id||'</ItemID>'|| 
        '<Barcode>'||i.Barcode||'</Barcode>'|| 
        '<ProductID>'||i.prod_id||'</ProductID>'|| 
        '<MultiStopBulkIndicator>'||i.BULK_ITEM||'</MultiStopBulkIndicator>'|| 
        '<OrderLineState>'||i.ORDER_LINE_STATE||'</OrderLineState>'|| 
        '<SelectedQuantity>'||i.qty ||'</SelectedQuantity>'||'</BC>');
        
        l_bc_lp_count   := l_bc_lp_count +1;
        b_counter       := b_counter     +1;
        
        
        IF l_bc_lp_count = l_bc_count THEN
          resultset_xml := concat(resultset_xml,'</Barcodes>'||'');
        END IF;
        
      END IF;
      
      l_prv_rec_type := i.record_type;
      
    END LOOP;
    
    If resultset_xml is not null then    -- Jira 3258
    ---in the xml include the input and event templates related to STS temperature when there is data in the above variable.
    resultset_xml := concat(resultset_xml,l_tmplt_txt);
    
    resultset_xml := concat(resultset_xml, '</Route>'||''||'</Routes>'||''|| 
    '</DriverProImport>'||''||'</sae:input>'||''|| 
    '</sae:ImportHostData>'||''||'</soapenv:Body>'||''|| '</soapenv:Envelope>');
   End If; 
  
    
    RETURN resultset_xml;
    
  EXCEPTION
  WHEN OTHERS THEN
    RETURN ' ';
  END;
  
   PROCEDURE add_alert(
      p_add_user STS_ROUTE_OUT.ADD_USER%type,
      p_message SWMS_FAILURE_EVENT.MSG_BODY%type,
      p_error_id SWMS_FAILURE_EVENT.UNIQUE_ID%type,
      p_company varchar2)
  IS
  BEGIN
    BEGIN
      INSERT
      INTO SWMS_FAILURE_EVENT
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
          'PL_SWMS_TO_STS',
          'WARN',
          'N',
          nvl(p_error_id,0),
          'Error in SWMS to STS for :'||p_company,
          nvl(p_message,'na'),
          sysdate,
          nvl(p_add_user, 'SWMS')
        );
        
   --      dbms_output.put_line ('in addalert');
    EXCEPTION
    WHEN OTHERS THEN
    pl_log.ins_msg('INFO','add_alert', 'Error inserting in to SWMS_FAILURE_EVENT',  nvl(SQLCODE,0), nvl(SQLERRM,' '), 'STS', 'pl_swms_sts_routeout', 'Y');
     
    dbms_output.put_line ('Error inserting in to SWMS_FAILURE_EVENT:'||SQLERRM);
    END;
  END add_alert;
   
  FUNCTION xx_utl_http(
      p_url VARCHAR2,
      p_request_body CLOB )
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
   
    utl_req := UTL_HTTP.begin_request (p_url, 'POST', 'HTTP/1.1');
    utl_http.set_header(utl_req, 'SOAPAction', 'http://SAE.DriverPro.CommService/IDriverProCommService/ImportHostData');
    utl_http.set_header(utl_req, 'User-Agent', 'Mozilla/4.0');
    UTL_HTTP.set_header(utl_req, 'Content-Type', 'text/xml');
    req_length := DBMS_LOB.getlength (p_request_body);
   
    -- If Message data under 32kb limit
    IF req_length<=32767 THEN
      UTL_HTTP.set_header (utl_req, 'Content-Length', req_length);
      
 --         dbms_output.put_line( p_request_body); --enable this to show xml generated
       
      UTL_HTTP.write_text (utl_req, p_request_body);
      --If Message data more than 32kb then transfer chunked
    elsif req_length>32767 THEN
      UTL_HTTP.set_header (utl_req, 'Transfer-Encoding', 'chunked');
      WHILE (offset < req_length)
      LOOP
        DBMS_LOB.read (p_request_body, amount, offset, buffer);
        
   --   dbms_output.put_line(buffer); --enable this to show xml generated
        
        UTL_HTTP.write_text(utl_req, buffer);
        offset := offset + amount;
      END LOOP;
    END IF;
    BEGIN
      utl_resp := UTL_HTTP.get_response (utl_req);
      UTL_HTTP.read_text (utl_resp, response_body, 32767);
      DBMS_OUTPUT.PUT_LINE ('status code: ' || utl_resp.STATUS_CODE);
      
      DBMS_OUTPUT.PUT_LINE ('reason: ' || utl_resp.REASON_PHRASE);
      
      l_status := substr(response_body,instr(response_body, '<Valid>')+7,4) ;
      
      l_msg := substr(response_body,instr(response_body, '<Msg>')+5,100) ;
      
       DBMS_OUTPUT.PUT_LINE ( 'l_status :=' ||  l_status );
      
      If utl_resp.STATUS_CODE = 200 and upper(l_status) = 'TRUE' then
        
         pl_log.ins_msg('INFO','xx_utl_http', 'Route sucessfully sent',  utl_resp.STATUS_CODE, l_msg, 'STS', 'pl_swms_sts_routeout', 'Y');
      Else
         pl_log.ins_msg('FATAL','xx_utl_http', 'Error sending Route', utl_resp.STATUS_CODE, l_msg, 'STS', 'pl_swms_sts_routeout', 'Y');
      
      End If;
      
     
      
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
      pl_log.ins_msg('FATAL', 'xx_utl_http', 'Error generating Route :errorcode -'||utl_resp.STATUS_CODE,  nvl(SQLCODE,0), nvl(SQLERRM,' '), 'STS', 'pl_swms_sts_routeout', 'Y');
    END;
    RETURN response_body;
  END;
  PROCEDURE send_route
  IS
    req utl_http.req;
    RESP UTL_HTTP.RESP;
    l_url VARCHAR2(1000);
    x_clob CLOB;
    l_buffer VARCHAR2(32767);
    value CLOB;
    P_DATA_TYPE VARCHAR2(600):= 'text/xml';
    l_status varchar2(20);
    l_sts_server varchar2(20);
    ex_swms_sts_off exception;
    ex_swms_sts_dup exception;
    ex_swms_sts_notrdy exception;
    l_company varchar2(100);
    l_rt_count number;
    l_rt_list VARCHAR2(5000) := '0';
    
    CURSOR c_routes
    IS
      SELECT  route_no, add_date, batch_id
      from  sts_route_out  
     where Record_Type ='RT'
    and Record_Status in ('N')
    order by add_date;
    
     
   /*   FROM TABLE
        (SELECT CAST(pl_sts_interfaces. swms_sts_func AS STS_ROUTE_OUT_OBJECT_TABLE)
        FROM dual  )
    WHERE 1 =1
    AND record_type ='RT' ;*/
    
    CURSOR c_route_stk
    IS
    SELECT distinct Route_no
    FROM sts_route_out
    WHERE 1=1
    and record_status = 'Q';
    
    soap_resp_msg VARCHAR2 (32760);
    l_swms_sts_on VARCHAR2(5);
    
    p_data_in CLOB;
    
BEGIN
    
    l_rt_list  := '0';
    
   BEGIN
   
     
    SELECT config_flag_val
     INTO l_swms_sts_on
  FROM sys_config
  WHERE APPLICATION_FUNC = 'DRIVER-CHECK-IN'
  and CONFIG_FLAG_NAME = 'SWMS_STS_ON';
  EXCEPTION
    WHEN OTHERS THEN
       l_swms_sts_on := 'N' ;
       pl_log.ins_msg('FATAL','send_route', 'Issue getting SWMS_STS_ON info from sysconfig', nvl(SQLCODE,0), nvl(SQLERRM,' '), 'STS', 'pl_swms_sts_routeout', 'Y');
       
       dbms_output.put_line ('Issue retrieving SWMS to STS is on info  from sysconfig');
       Raise ex_swms_sts_off;
  END; 
  
   BEGIN
      SELECT trim(attribute_value)
      INTO l_company
      FROM maintenance
      WHERE 1         =1
      AND component   ='COMPANY'
      AND application = 'SWMS'
      AND attribute   = 'MACHINE';
    EXCEPTION
    WHEN OTHERS THEN
      l_company := 000;
    END;
 
 Begin
 
  If l_swms_sts_on <> 'Y' then
    Raise ex_swms_sts_off; --custom exception
  End If;  
 
 End;
 
   
  BEGIN
    SELECT Param_values
    INTO l_sts_server
    FROM sys_config a,
      sys_config_valid_values b
    WHERE a.APPLICATION_FUNC = 'DRIVER-CHECK-IN'
    AND a.CONFIG_FLAG_NAME   = 'SWMS_STS_SERVER'
    AND a.CONFIG_FLAG_NAME   = b.CONFIG_FLAG_NAME
    AND a.CONFIG_FLAG_val    = b.CONFIG_FLAG_VAL;
   EXCEPTION
    WHEN OTHERS THEN
       pl_log.ins_msg('FATAL', 'send_route', 'Issue getting STS server name from sysconfig', nvl(SQLCODE,0), nvl(SQLERRM,' '), 'STS', 'pl_swms_sts_routeout', 'Y');
       
       dbms_output.put_line ('Issue retrieving STS server name from sysconfig');
    END;  
 
  
   -- get the URL from ACL setups
    BEGIN
      SELECT 'http://'
        ||Host
        ||':'
        ||upper_port
        ||'/DriverPro/CommService/soap11' lurl
      INTO l_url
      FROM dba_network_acls
      WHERE acl = '/sys/acls/'||l_sts_server||'.xml';
   -- DBMS_OUTPUT.PUT_LINE (l_url);
    EXCEPTION
    WHEN OTHERS THEN
       pl_log.ins_msg('FATAL','send_route', 'Issue retrieving STS URL from ACL', nvl(SQLCODE,0), nvl(SQLERRM,' '), 'STS', 'pl_swms_sts_routeout', 'Y');
       
       dbms_output.put_line ('Issue retrieving URL details from the ACL table');
    END;
    

  Begin
         
 
      For j in c_route_stk loop
      
      Begin
      
        update sts_route_out
        set record_status = 'K'
        where route_no = j.Route_no;
        
        Commit;        

         pl_log.ins_msg('INFO','Send_Route', 'Updated status of stuck route:'||j.Route_no,  nvl(SQLCODE,j.Route_no), nvl(SQLERRM,' '), 'STS', 'pl_swms_sts_routeout', 'Y');
         
    
      
     Exception when others then 
         pl_log.ins_msg('INFO','Send_Route', 'Unable to update Stuck route:'||j.Route_no,  nvl(SQLCODE,j.Route_no), nvl(SQLERRM,' '), 'STS', 'pl_swms_sts_routeout', 'Y');
     End;   
     
     End loop;     
    
   Exception when others then 
    dbms_output.put_line('there are no stuck routes');
     Null;
  End;
    
    
    
  --loop through all the available routes to be processed
    FOR i IN c_routes
     LOOP
   
     
   
    Begin 
    
     --- check if the route is porocessed already; if it is mark it to D-Duplicate
      Select count(*)
      into l_rt_count
      from sts_route_out
      where record_status  = 'S'
      and route_no = i.route_no
      and record_type ='RT'
      and trunc(add_date) = trunc(i.add_date);
      
      If l_rt_count > 0 then
           Raise ex_swms_sts_dup;
      End If;
    
    
    -- use local function to get the XML for the Route to transmit
    p_data_in := swms_sts_xmlgen(i.route_no, i.batch_id, to_char(trunc(i.add_date)));
    
     If p_data_in is null then   -- -- Jira 3258 (only process when the route XML data is ready)
      Raise ex_swms_sts_notrdy;
     End If;
    
   --replace the special charecters in the XML use  regexp_replace(col,'[[:punct:]]')
    p_data_in := REPLACE(REPLACE(REPLACE(REPLACE(REPLACE( p_data_in, '&', ' and ' ), '#', ''), chr(26),''), chr(13),''), chr(10),''); --extra replace added for chr26, chr10, chr13
    
    p_data_in := replace(Replace(REPLACE(REPLACE( p_data_in, '%', '' ), '(', ' '), ')', ' '), '+', '');
 
   -- call local function by passing the url and the xml data to transmit to sts
   
    l_buffer := xx_utl_http(l_url, p_data_in);
    
    --get the response string from the call
     dbms_output.put_line('response:'||l_buffer );
     
     
       l_status := substr(l_buffer,instr(l_buffer, '<Valid>')+7,4) ;
     
      If  upper(l_status) = 'TRUE' then
        
         pl_log.ins_msg('INFO','send_route', 'Sucessfully sent SWMS-STS Route:'||i.route_no,  200, l_status, 'STS', 'pl_swms_sts_routeout', 'Y');
         
           -- update the record status = s in sts_route_out table
           
          Begin 
            UPDATE sts_route_out
            SET record_status      = 'S',
			          upd_date = sysdate
            WHERE route_no = i.route_no
            AND trunc(ADD_DATE) = trunc(i.add_date)
            AND record_status   = 'Q';
           --  and batch_id =i.batch_id;
           
            COMMIT;
           EXCEPTION  WHEN OTHERS THEN  
                pl_log.ins_msg('FATAL', 'send_route', 'Issue updating status for route:'||i.route_no,  nvl(SQLCODE,0), nvl(SQLERRM,' '), 'STS', 'pl_swms_sts_routeout', 'Y');
          End;  
      Else
         pl_log.ins_msg('FATAL', 'send_route', 'Error sending SWMS-STS Route'||i.route_no, nvl(SQLCODE,0), nvl(l_status,' '), 'STS', 'pl_swms_sts_routeout', 'Y');
         
          UPDATE sts_route_out
            SET record_status      = 'F',
			          upd_date = sysdate
            WHERE route_no = i.route_no
            AND trunc(ADD_DATE) = trunc(i.add_date)
            AND record_status  in   ('Q');
           -- and batch_id =i.batch_id;
            
            p_data_in := replace(p_data_in, '><', '>'||chr(10)||'<');
            
          INSERT
          INTO STS_RTOUT_FAIL_XML
           (PROCESS_NO, ROUTE_NO , ERR_CODE , ERR_MSG , XML_DATA , ADD_DATE ,  ADD_USER )
          VALUES
           (STS_RTOUT_FAIL_XML_SN.NEXTVAL, i.route_no,0,l_status, p_data_in, sysdate,'SWMS' ); 
           
            COMMIT;
            
            l_rt_list := l_rt_list||','||i.route_no;
         
     --    ADD_ALERT('SWMS', 'Issue sending SWMS-STS Route:'||i.route_no, i.route_no, l_company);   
      End If;
     
    EXCEPTION  
     when ex_swms_sts_notrdy then 
         Null; -- the route is not yet ready to be processed with all the data, so no action
     when ex_swms_sts_dup then
     
      dbms_output.put_line('Already Processed route:'|| i.route_no||' ,adddate '|| trunc(i.add_date));
          
           UPDATE sts_route_out
            SET record_status      = 'D',
			      upd_date = sysdate
            WHERE route_no = i.route_no
            AND trunc(add_date) = trunc(i.add_date)
            AND record_status  = 'N';  
            
            Commit;
            
       dbms_output.put_line('Already Processed route:'|| i.route_no);
       pl_log.ins_msg('INFO','send_route', 'Already Processed route:'|| i.route_no,  0, '  ', 'STS', 'pl_swms_sts_routeout', 'Y');     
    
    WHEN OTHERS THEN
     --insert in to swms log
     pl_log.ins_msg('FATAL', 'send_route', 'Issue sending SWMS-STS Route:'||i.route_no,  nvl(SQLCODE,0), nvl(SQLERRM,' '), 'STS', 'pl_swms_sts_routeout', 'Y');
     dbms_output.put_line('response:'||l_buffer ); 
     
            UPDATE sts_route_out
            SET record_status      = 'F',
			          upd_date = sysdate
            WHERE route_no = i.route_no
             AND trunc(ADD_DATE) = trunc(i.add_date)
             AND record_status   in ('Q');
           -- and batch_id =i.batch_id;
           
            COMMIT;
     
    -- ADD_ALERT('SWMS', 'Issue sending SWMS-STS Route:'||i.route_no, i.route_no, l_company); 
       l_rt_list := l_rt_list||','||i.route_no;
       
    End; 
   End loop;
   
     if l_rt_list <>'0' then 
       ADD_ALERT('SWMS', 'Issue in SWMS-STS interface sending Route(s):'||l_rt_list, 0, l_company); 
     End If;
     
     
  EXCEPTION
  when ex_swms_sts_off then
   dbms_output.put_line('SWMS to STS process is switched off');
   --pl_log.ins_msg('INFO','send_route', 'SWMS_STS_ON flag=N;no routes are processed',  0, '  ', 'STS', 'pl_swms_sts_routeout', 'Y');
   
        
   WHEN OTHERS THEN
  
      --insert in to swms log
        pl_log.ins_msg('FATAL','send_route', 'Exception sending Route SWMS-STS',  nvl(SQLCODE,0), nvl(SQLERRM,'When Others exception'), 'STS', 'pl_swms_sts_routeout', 'Y');
  END;
END pl_swms_sts_routeout;
/
