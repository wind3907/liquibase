CREATE OR REPLACE PACKAGE SWMS."PL_VR_MATRIX_ELIGIBLE"  IS
g_form_check  VARCHAR2(1):= 'N'; 
/*=============================================================================================
 This package contain all the common functions and procedures require to validate matrix eligibility

Functions:   chk_required_data
             chk_item_eligible  -- checks if item is matrix eligible and return values
                                  Y=Eligible, N=Not Eligible, E=Error,null=Not process
             return_min
             return_median
             return_max

Procedures:  chk_dimension_tolerance
             chk_temp_tolerance
             get_matrix_config  -- will get the configurations

Modification History
-----------    ------------     --------------------------------------------------------
Date           Designer          Comments
-----------    ------------     --------------------------------------------------------
07-OCT-2014    Vani Reddy        Initial Creation
29-Dec-2014    sunil Ontipalli   Added the recalc length, width and height. Handled the diag_measurement.
12-Jan-2015    sunil Ontipalli   Added the tip over flag calculation to decide whether to recalculate.
12-Jan-2015    sunil Ontipalli   Fixed minor bugs ralated to l_count_incomplete and handled diag_measurement 
                                 with regular length, width and height calc.
=============================================================================================*/
FUNCTION chk_required_data(i_mx_eligible         in varchar2,
                           i_auto_ship_flag      in varchar2,
                           i_mx_master_case_flag in varchar2,
                           i_mx_package_type     in varchar2,
                           i_mx_hazardous_type   in varchar2,
                           i_case_length         in number,
                           i_case_width          in number,
                           i_case_height         in number,
                           i_spc                 in number,
                           i_g_weight            in number) return boolean;

FUNCTION return_min(i_case_length in number,
                    i_case_width  in number,
                    i_case_height in number) return number;

FUNCTION return_median(i_case_length in number,
                       i_case_width  in number,
                       i_case_height in number) return number;

FUNCTION return_max(i_case_length in number,
                    i_case_width  in number,
                    i_case_height in number) return number;

PROCEDURE chk_item_eligible(i_mx_eligible            in out varchar2,
                            i_auto_ship_flag         in varchar2,
                            i_mx_master_case_flag    in varchar2,
                            i_mx_package_type        in varchar2,
                            i_mx_hazardous_type      in varchar2,
                            i_case_length            in number,
                            i_case_width             in number,
                            i_case_height            in number,
                            i_recal_length           in out number,
                            i_recal_width            in out number,
                            i_recal_height           in out number,
                            i_spc                    in number,
                            i_g_weight               in number,
                            i_mx_item_assign_flag    in varchar2,
                            i_area                   in varchar2,
                            i_mx_why_not_eligible    out varchar2,
                            i_diagonal_measurement   in out number,
                            i_mx_stability_calc      in out number,
                            i_mx_stability_flag      in varchar2,
                            i_mx_stability_recalc    in out number);

PROCEDURE chk_dimension_tolerance(i_len_wid_ht_wt        in varchar2,
                                  i_edit_eligible        in boolean,
                                  i_case_length          in number,
                                  i_case_width           in number,
                                  i_case_height          in number,
                                  i_spc                  in number,
                                  i_g_weight             in number,
                                  i_min_length           in number,
                                  i_max_length           in number,
                                  i_min_width            in number,
                                  i_max_width            in number,
                                  i_min_height           in number,
                                  i_max_height           in number,
                                  i_min_weight           in number,
                                  i_max_weight           in number,
                                  i_mx_why_not_eligible  in out varchar2,
                                  o_tolerance_fail       out varchar2);

PROCEDURE chk_temp_tolerance(i_len_wid_ht_wt     in varchar2,
                             i_min_length        in number,
                             i_max_length        in number,
                             i_min_width         in number,
                             i_max_width         in number,
                             i_min_height        in number,
                             i_max_height        in number,
                             i_tmp_recalc_length in number,
                             i_tmp_recalc_width  in number,
                             i_tmp_recalc_height in number,
                             i_diag_measurement  in number,
                             i_diag_control      in number,
                             o_tolerance_fail    out varchar2);

FUNCTION ffu_calc_diag_measurement (i_length in number,
                                    i_width  in number) RETURN NUMBER;

PROCEDURE calling_from_form(i_val  in varchar2);                                    
END pl_vr_matrix_eligible;
/


CREATE OR REPLACE PACKAGE BODY SWMS."PL_VR_MATRIX_ELIGIBLE"
    IS
/*=======================================================================================================
 This package contain all the common functions and procedures require to validate matrix eligibility

Functions:   chk_required_data
             return_min
             return_median
             return_max

Procedures:  chk_dimension_tolerance
             chk_temp_tolerance
              chk_item_eligible  -- checks if item is matrix eligible and return values
                                  I==Incomplete, Y=Eligible, N=Not Eligible, E=Error,null=Not process

How it works:  Calling function pl_matrix_eligible.chk_item_eligible(prod_id)
                            to return mx_eligible as Y, N, I or null.
               At this point not updating PM table for 3 fields that are calculated or updated

Modification History
-----------    ------------     --------------------------------------------------------------------------
Date           Designer          Comments
-----------    ------------     --------------------------------------------------------------------------
07-OCT-2014    Vani Reddy        Initial Creation
29-Dec-2014    sunil Ontipalli   Added the recalc length, width and height. Handled the diag_measurement.
12-Jan-2015    sunil Ontipalli   Added the tip over flag calculation to decide whether to recalculate.
12-Jan-2015    sunil Ontipalli   Fixed minor bugs ralated to l_count_incomplete and handled diag_measurement 
                                 with regular length, width and height calc.

=============================================================================================*/
function chk_required_data (i_mx_eligible         in varchar2,
                            i_auto_ship_flag      in varchar2,
                            i_mx_master_case_flag in varchar2,
                            i_mx_package_type     in varchar2,
                            i_mx_hazardous_type   in varchar2,
                            i_case_length         in number,
                            i_case_width          in number,
                            i_case_height         in number,
                            i_spc                 in number,
                            i_g_weight            in number) return boolean is
  l_count_incomplete  number := 0;

begin
      --Starting this point on is the determination for eligibility
      if i_mx_master_case_flag is null then
           l_count_incomplete := l_count_incomplete + 1;
      end if;
      --
      if i_auto_ship_flag is null then
           l_count_incomplete := l_count_incomplete + 1;
      end if;

      if i_mx_package_type is null then
           l_count_incomplete := l_count_incomplete + 1;
      end if;

      if i_mx_hazardous_type is null then
           l_count_incomplete := l_count_incomplete + 1;
      end if;

      if nvl(i_case_length,0) < nvl(i_case_width,0) then
           l_count_incomplete := l_count_incomplete + 1;
      else
          if nvl(i_case_length,0) = 0 then
             l_count_incomplete := l_count_incomplete + 1;
          end if;

          if nvl(i_case_width,0) = 0 then
             l_count_incomplete := l_count_incomplete + 1;
          end if;
      end if;

      if nvl(i_case_height,0) = 0 then
          l_count_incomplete := l_count_incomplete + 1;
      end if;

      if nvl(round(i_spc * i_g_weight, 2), 0) = 0 then
           l_count_incomplete := l_count_incomplete + 1;
      end if;

      if l_count_incomplete = 0 OR i_mx_eligible in ('Y','N') then
          return TRUE;
      else
          return FALSE;
      end if;
end chk_required_data;

function return_min(i_case_length in number,
                    i_case_width  in number,
                    i_case_height in number) return number is

    l_case_width_length    number;
begin
      if i_case_length < i_case_width then
           if i_case_length < i_case_height then
                 l_case_width_length := i_case_length;
                 return l_case_width_length;    --i_case_length;
           else
                 l_case_width_length := i_case_height;
                 return l_case_width_length;    --i_case_height;
           end if;
      else
           if i_case_width < i_case_height then
                l_case_width_length := i_case_width;
                return l_case_width_length;    --i_case_width;
           else
                l_case_width_length := i_case_height;
                return l_case_width_length;    --i_case_height;
           end if;
      end if;
end return_min;


function return_median(i_case_length in number,
                       i_case_width  in number,
                       i_case_height in number) return number is

    l_case_width_length    number;
begin
      if ((i_case_length - i_case_width) * (i_case_height - i_case_length)) >= 0 then
           l_case_width_length := i_case_length;
           return l_case_width_length;    --- i_case_length;
      elsif (i_case_width - i_case_length) * (i_case_height - i_case_width) >= 0 then
           l_case_width_length := i_case_height;
           return l_case_width_length; -- i_case_width;
      else
           l_case_width_length := i_case_height;
           return l_case_width_length; --i_case_height;
      end if;
end return_median;


function return_max(i_case_length in number,
                    i_case_width  in number,
                    i_case_height in number) return number is

     l_case_width_length    number;
begin
      if i_case_length > i_case_width then
           if i_case_length > i_case_height then
                 l_case_width_length := i_case_length;
                 return l_case_width_length;  --i_case_length;
           else
                 l_case_width_length := i_case_height;
                 return l_case_width_length;  --i_case_height;
           end if;
      else
           if i_case_width > i_case_height then
                l_case_width_length := i_case_width;
                return l_case_width_length;  --i_case_width;
           else
                l_case_width_length := i_case_height;
                return l_case_width_length;  --i_case_height;
           end if;
      end if;
end return_max;

procedure chk_item_eligible(i_mx_eligible          in out varchar2,
                            i_auto_ship_flag       in varchar2,
                            i_mx_master_case_flag  in varchar2,
                            i_mx_package_type      in varchar2,
                            i_mx_hazardous_type    in varchar2,
                            i_case_length          in number,
                            i_case_width           in number,
                            i_case_height          in number,
                            i_recal_length         in out number,
                            i_recal_width          in out number,
                            i_recal_height         in out number,
                            i_spc                  in number,
                            i_g_weight             in number,
                            i_mx_item_assign_flag  in varchar2,
                            i_area                 in varchar2,
                            i_mx_why_not_eligible  out varchar2,
                            i_diagonal_measurement in out number,
                            i_mx_stability_calc    in out number,
                            i_mx_stability_flag    in varchar2,
                            i_mx_stability_recalc  in out number) is

   l_item_has_data          boolean;
   l_o_weight_normalizer    number;
   l_o_stability_limit      number;
   l_o_diag_measurement     number;
   l_o_min_length           number;
   l_o_max_length           number;
   l_o_min_width            number;
   l_o_max_width            number;
   l_o_min_height           number;
   l_o_max_height           number;
   l_o_min_weight           number;
   l_o_max_weight           number;
   l_count_incomplete       number := 0;  --counting incomplete setup value
   l_count_not_eligible     number := 0;  --Counting how many were ineligible
   l_apply_recalc_method    varchar2(1);  --Y for yes recalculate,N for No, I for Incomplete
   l_new_mx_eligible        varchar2(1) := null;
   l_tmp_tolerance_fail     varchar2(1);
   l_tmp_recalc_length      number;
   l_tmp_recalc_width       number;
   l_tmp_recalc_height      number;

   cursor get_mx_config is
                        select config_name,config_value
                          from mx_config_eligible;

begin

 pl_text_log.ins_msg('INFO', 'eligibility',
                              'Package 1',
                              NULL, NULL);
  l_item_has_data := chk_required_data(i_mx_eligible,
                                       i_auto_ship_flag,
                                       i_mx_master_case_flag,
                                       i_mx_package_type,
                                       i_mx_hazardous_type,
                                       i_case_length,
                                       i_case_width,
                                       i_case_height,
                                       i_spc,
                                       i_g_weight);
    
  pl_text_log.ins_msg('INFO', 'eligibility',
                              'Package 2',
                              NULL, NULL);                                   
                
  if l_item_has_data = TRUE then
  
  pl_text_log.ins_msg('INFO', 'eligibility',
                              'Package 3',
                              NULL, NULL);
  
      for r_config in get_mx_config loop
         case r_config.config_name
           when 'WEIGHT_NORMALIZER'    then l_o_weight_normalizer := to_number(r_config.config_value);
           when 'STABILITY_LIMIT'      then l_o_stability_limit   := to_number(r_config.config_value);
           when 'DIAGONAL_MEASUREMENT' then l_o_diag_measurement  := to_number(r_config.config_value); -- Added the new diag_measurement
           when 'MIN_CASE_LENGTH'      then l_o_min_length        := to_number(r_config.config_value);
           when 'MAX_CASE_LENGTH'      then l_o_max_length        := to_number(r_config.config_value);
           when 'MIN_CASE_WIDTH'       then l_o_min_width         := to_number(r_config.config_value);
           when 'MAX_CASE_WIDTH'       then l_o_max_width         := to_number(r_config.config_value);
           when 'MIN_CASE_HEIGHT'      then l_o_min_height        := to_number(r_config.config_value);
           when 'MAX_CASE_HEIGHT'      then l_o_max_height        := to_number(r_config.config_value);
           when 'MIN_CASE_WEIGHT'      then l_o_min_weight        := to_number(r_config.config_value);
           when 'MAX_CASE_WEIGHT'      then l_o_max_weight        := to_number(r_config.config_value);
           else null;
         end case;
      end loop;
 
      --This function is process by exception; if the count for not eligble is zero then item considers as pass
      i_mx_why_not_eligible := null;

    pl_text_log.ins_msg('INFO', 'eligibility',
                              'Package 4',
                              NULL, NULL);
                              
      if i_mx_master_case_flag = 'Y' then
         i_mx_why_not_eligible := 'Master Case is NOT Eligible;';
         l_count_not_eligible := l_count_not_eligible + 1;
      end if;

      if i_area != 'D' then
          i_mx_why_not_eligible := i_mx_why_not_eligible || ' Not Dry Area Item=' || i_area || ';';
          l_count_not_eligible := l_count_not_eligible + 1;
       end if;

      if i_auto_ship_flag = 'Y' then
          i_mx_why_not_eligible := i_mx_why_not_eligible || ' Ship Split Only NOT Eligible;';
          l_count_not_eligible := l_count_not_eligible + 1;
      end if;

      if i_mx_package_type is null then
          i_mx_why_not_eligible := i_mx_why_not_eligible || 'I==>Package is blank;';
          l_count_incomplete := l_count_incomplete + 1;
      elsif i_mx_package_type != 'BOX/CASE' then
          i_mx_why_not_eligible := i_mx_why_not_eligible || 'Package is ' || i_mx_package_type || ';';
          l_count_not_eligible := l_count_not_eligible + 1;
      end if;
           --
      if i_mx_hazardous_type is null then
          i_mx_why_not_eligible := i_mx_why_not_eligible || 'Hazardous is blank;';
          l_count_incomplete := l_count_incomplete + 1;
      elsif i_mx_hazardous_type != 'NOT_HAZARDOUS' then
          i_mx_why_not_eligible := i_mx_why_not_eligible || 'Hazardous is ' || i_mx_hazardous_type || ' NOT Eligible;';
          l_count_not_eligible := l_count_not_eligible + 1;
      end if;

      if i_case_length is null or i_case_width is null or i_case_height is null or round(i_spc * i_g_weight, 2) is null then
          i_mx_why_not_eligible := i_mx_why_not_eligible || 'One of length/Width/Height/Weight is blank;';
          l_count_incomplete := l_count_incomplete + 1;
      else
          --First Calculation for Stability Limit
          i_mx_stability_calc := ROUND((i_case_height/i_case_width) - (round(i_spc * i_g_weight, 2)/l_o_weight_normalizer),1);
          if i_mx_stability_calc > l_o_stability_limit and i_mx_stability_flag = 'Y' then
          
          pl_text_log.ins_msg('INFO', 'eligibility',
                              'Package 5',
                              NULL, NULL);
              --l_count_incomplete := l_count_incomplete + 1;
              i_mx_stability_calc := null;                                                               ----=============== need to update pm
              --i_mx_why_not_eligible := i_mx_why_not_eligible || 'Recalc needed but not done;';         ----=============== need to update pm
              l_apply_recalc_method := 'Y';
          else
           
           pl_text_log.ins_msg('INFO', 'eligibility',
                              'Package 6',
                              NULL, NULL);
              l_apply_recalc_method := 'N';
              --i_mx_stability_flag := 'N/A';                                                               ----=============== need to update pm
          end if;       --compare stability_calc with round of case height/width

           --do not allow update of stability flag after user has chosen Y or N
          if l_apply_recalc_method = 'N' then
          
          pl_text_log.ins_msg('INFO', 'eligibility',
                              'Package 7',
                              NULL, NULL);
                              
              chk_dimension_tolerance('LEN',
                                       TRUE,
                                       i_case_length,
                                       i_case_width,
                                       i_case_height,
                                       i_spc,
                                       i_g_weight,
                                       l_o_min_length,
                                       l_o_max_length,
                                       l_o_min_width,
                                       l_o_max_width,
                                       l_o_min_height,
                                       l_o_max_height,
                                       l_o_min_weight,
                                       l_o_max_weight,
                                       i_mx_why_not_eligible,
                                       l_tmp_tolerance_fail);
               if l_tmp_tolerance_fail = 'Y' then
                 l_count_not_eligible := l_count_not_eligible + 1;
                 i_mx_why_not_eligible := i_mx_why_not_eligible || 'Length is out of tolerance=' || i_case_length  || ';';
               end if;

               chk_dimension_tolerance('WID',
                                       TRUE,
                                       i_case_length,
                                       i_case_width,
                                       i_case_height,
                                       i_spc,
                                       i_g_weight,
                                       l_o_min_length,
                                       l_o_max_length,
                                       l_o_min_width,
                                       l_o_max_width,
                                       l_o_min_height,
                                       l_o_max_height,
                                       l_o_min_weight,
                                       l_o_max_weight,
                                       i_mx_why_not_eligible,
                                       l_tmp_tolerance_fail);
               if l_tmp_tolerance_fail = 'Y' then
                     l_count_not_eligible := l_count_not_eligible + 1;
                     i_mx_why_not_eligible := i_mx_why_not_eligible || 'Width is out of tolerance=' || i_case_width || ';';
               end if;

               chk_dimension_tolerance('HT',
                                       TRUE,
                                       i_case_length,
                                       i_case_width,
                                       i_case_height,
                                       i_spc,
                                       i_g_weight,
                                       l_o_min_length,
                                       l_o_max_length,
                                       l_o_min_width,
                                       l_o_max_width,
                                       l_o_min_height,
                                       l_o_max_height,
                                       l_o_min_weight,
                                       l_o_max_weight,
                                       i_mx_why_not_eligible,
                                       l_tmp_tolerance_fail);
               if l_tmp_tolerance_fail = 'Y' then
                     l_count_not_eligible := l_count_not_eligible + 1;
                     i_mx_why_not_eligible := i_mx_why_not_eligible || 'Height is out of tolerance=' || i_case_height || ';';
               end if;

               chk_dimension_tolerance('WT',
                                       TRUE,
                                       i_case_length,
                                       i_case_width,
                                       i_case_height,
                                       i_spc,
                                       i_g_weight,
                                       l_o_min_length,
                                       l_o_max_length,
                                       l_o_min_width,
                                       l_o_max_width,
                                       l_o_min_height,
                                       l_o_max_height,
                                       l_o_min_weight,
                                       l_o_max_weight,
                                       i_mx_why_not_eligible,
                                       l_tmp_tolerance_fail);
               if l_tmp_tolerance_fail = 'Y' then
                     l_count_not_eligible := l_count_not_eligible + 1;
                --This part does not need setting value for why_not_eligible b/c it is set in fpr_chk_dimension_tolerance
               end if;
               
               ----modifying to handle the diagonal calculation--------
               i_diagonal_measurement := FFU_CALC_DIAG_MEASUREMENT(i_case_length, i_case_width);
       
               chk_temp_tolerance('DIA',
                                  l_o_min_length,
                                  l_o_max_length,
                                  l_o_min_width,
                                  l_o_max_width,
                                  l_o_min_height,
                                  l_o_max_height,
                                  i_case_length,
                                  i_case_width,
                                  i_case_height,
                                  i_diagonal_measurement,
                                  l_o_diag_measurement,
                                  l_tmp_tolerance_fail);                
               if l_tmp_tolerance_fail = 'Y' then
                   l_count_not_eligible := l_count_not_eligible + 1;
                   i_mx_why_not_eligible := i_mx_why_not_eligible || 'Diagonal Measurement out of tolerance=' || i_diagonal_measurement || ';';
               end if;

               if i_mx_stability_calc > l_o_stability_limit then
                     l_count_not_eligible := l_count_not_eligible + 1;
                     i_mx_why_not_eligible := i_mx_why_not_eligible || ' Stability calculation > limit;';
               end if;
               
          elsif l_apply_recalc_method = 'Y' then
          
           pl_text_log.ins_msg('INFO', 'eligibility',
                              'Package 8',
                              NULL, NULL);
                              
               l_tmp_recalc_length := return_max(i_case_length,
                                                 i_case_width,
                                                 i_case_height);
               l_tmp_recalc_width  := return_median(i_case_length,
                                                    i_case_width,
                                                    i_case_height);
               l_tmp_recalc_height := return_min(i_case_length,
                                                 i_case_width,
                                                 i_case_height);
               
                                                 
               --------modified to store the new values--------
               
                i_recal_length     := l_tmp_recalc_length;
                i_recal_width      := l_tmp_recalc_width;
                i_recal_height     := l_tmp_recalc_height;

               i_mx_stability_recalc := round((l_tmp_recalc_height/l_tmp_recalc_width) - (round(i_spc * i_g_weight, 2)/l_o_weight_normalizer),1);
               if i_mx_stability_recalc > l_o_stability_limit then
                   l_count_not_eligible := l_count_not_eligible + 1;
                   i_mx_why_not_eligible := i_mx_why_not_eligible || 'Stability recalc exceed limit=' || to_char(i_mx_stability_recalc) || ';';
               end if;

               chk_temp_tolerance('LEN',
                                 l_o_min_length,
                                 l_o_max_length,
                                 l_o_min_width,
                                 l_o_max_width,
                                 l_o_min_height,
                                 l_o_max_height,
                                 l_tmp_recalc_length,
                                 l_tmp_recalc_width,
                                 l_tmp_recalc_height,
                                 i_diagonal_measurement,
                                 l_o_diag_measurement,
                                 l_tmp_tolerance_fail);
               if l_tmp_tolerance_fail = 'Y' then
                   l_count_not_eligible := l_count_not_eligible + 1;
                   i_mx_why_not_eligible := i_mx_why_not_eligible || 'Recalc Length out of tolerance=' || l_tmp_recalc_length || ';';
               end if;
                    --
               chk_temp_tolerance('WID',
                                 l_o_min_length,
                                 l_o_max_length,
                                 l_o_min_width,
                                 l_o_max_width,
                                 l_o_min_height,
                                 l_o_max_height,
                                 l_tmp_recalc_length,
                                 l_tmp_recalc_width,
                                 l_tmp_recalc_height,
                                 i_diagonal_measurement,
                                 l_o_diag_measurement,
                                 l_tmp_tolerance_fail);
               if l_tmp_tolerance_fail = 'Y' then
                   l_count_not_eligible := l_count_not_eligible + 1;
                   i_mx_why_not_eligible := i_mx_why_not_eligible || 'Recalc Width out of tolerance=' || l_tmp_recalc_width || ';';
               end if;

               chk_temp_tolerance('HT',
                                 l_o_min_length,
                                 l_o_max_length,
                                 l_o_min_width,
                                 l_o_max_width,
                                 l_o_min_height,
                                 l_o_max_height,
                                 l_tmp_recalc_length,
                                 l_tmp_recalc_width,
                                 l_tmp_recalc_height,
                                 i_diagonal_measurement,
                                 l_o_diag_measurement,
                                 l_tmp_tolerance_fail);
               if l_tmp_tolerance_fail = 'Y' then
                   l_count_not_eligible := l_count_not_eligible + 1;
                   i_mx_why_not_eligible := i_mx_why_not_eligible || 'Recalc Height out of tolerance=' || l_tmp_recalc_height || ';';
               end if;
               
               ----modifying to handle the diagonal calculation--------
              i_diagonal_measurement := FFU_CALC_DIAG_MEASUREMENT(l_tmp_recalc_length, l_tmp_recalc_width);
       
              chk_temp_tolerance('DIA',
                                 l_o_min_length,
                                 l_o_max_length,
                                 l_o_min_width,
                                 l_o_max_width,
                                 l_o_min_height,
                                 l_o_max_height,
                                 l_tmp_recalc_length,
                                 l_tmp_recalc_width,
                                 l_tmp_recalc_height,
                                 i_diagonal_measurement,
                                 l_o_diag_measurement,
                                 l_tmp_tolerance_fail);                 
               if l_tmp_tolerance_fail = 'Y' then
                   l_count_not_eligible := l_count_not_eligible + 1;
                   i_mx_why_not_eligible := i_mx_why_not_eligible || 'Recalc Diagonal Measurement out of tolerance=' || i_diagonal_measurement || ';';
               end if;
               
               
          else
              l_count_incomplete := l_count_incomplete + 1;
          end if; --l_apply_recalc_method compare
         
      end if; --check length,width,height,weight to have a positive value

      if l_count_incomplete > 0 then
      
       pl_text_log.ins_msg('INFO', 'eligibility',
                              'Package 9',
                              NULL, NULL);
                              
          l_new_mx_eligible  := NULL;
      else
      
       pl_text_log.ins_msg('INFO', 'eligibility',
                              'Package 10',
                              NULL, NULL);
                              
          if l_count_not_eligible > 0 then
          
           pl_text_log.ins_msg('INFO', 'eligibility',
                               'Package 11',
                               NULL, NULL);
                              
              if i_mx_stability_flag is null OR i_mx_stability_flag = 'N/A' then
               
               pl_text_log.ins_msg('INFO', 'eligibility',
                                   'Package 12',
                                   NULL, NULL);
                                   
                 l_new_mx_eligible := null;
                 
              else
                 
               pl_text_log.ins_msg('INFO', 'eligibility',
                                   'Package 13',
                                   NULL, NULL);
                                   
                 l_new_mx_eligible := 'N';
                 
              end if;   
              
          else
          
           pl_text_log.ins_msg('INFO', 'eligibility',
                               'Package 14',
                               NULL, NULL);
                               
              l_new_mx_eligible := 'Y';
              
          end if;
          
      end if;

      i_mx_eligible := nvl(l_new_mx_eligible,i_mx_eligible);
      --return l_new_mx_eligible;
  else       dbms_output.put_line('else'||i_mx_eligible);
     i_mx_eligible := nvl(l_new_mx_eligible,i_mx_eligible);
     
     pl_text_log.ins_msg('INFO', 'eligibility',
                              'Package 15',
                              NULL, NULL);
     --return l_new_mx_eligible;         --- mx_eligible blank
  end if;
end chk_item_eligible;


procedure chk_dimension_tolerance(i_len_wid_ht_wt        in varchar2,
                                  i_edit_eligible        in boolean,
                                  i_case_length          in number,
                                  i_case_width           in number,
                                  i_case_height          in number,
                                  i_spc                  in number,
                                  i_g_weight             in number,
                                  i_min_length           in number,
                                  i_max_length           in number,
                                  i_min_width            in number,
                                  i_max_width            in number,
                                  i_min_height           in number,
                                  i_max_height           in number,
                                  i_min_weight           in number,
                                  i_max_weight           in number,
                                  i_mx_why_not_eligible  in out varchar2,
                                  o_tolerance_fail        out varchar2) is

begin
    -- LEN value pass in for Length; WID for width, HT for height, and WT for Weight
    if i_len_wid_ht_wt = 'LEN' then
        if nvl(i_case_length,0) = 0 then
           o_tolerance_fail := 'I';--I for Incomplete
        else
             if i_case_length between i_min_length and i_max_length then
                 o_tolerance_fail := 'N';
             else
                 o_tolerance_fail := 'Y';
             end if;
        end if;
    elsif i_len_wid_ht_wt = 'WID' then
        if nvl(i_case_width,0) = 0 then
             o_tolerance_fail := 'I';
        else
             if i_case_width between i_min_width and i_max_width then
                o_tolerance_fail := 'N';
             else
                o_tolerance_fail := 'Y';
             end if;
        end if;
    elsif i_len_wid_ht_wt = 'HT' then
        if nvl(i_case_height,0) = 0 then
             o_tolerance_fail := 'I';
        else
             if i_case_height between i_min_height and i_max_height then
                 o_tolerance_fail := 'N';
             else
                 o_tolerance_fail := 'Y';
             end if;
        end if;
    elsif i_len_wid_ht_wt = 'WT' then
        if nvl(round(i_spc * i_g_weight ,2), 0) = 0 then
             o_tolerance_fail := 'I';
        else
              if round(i_spc * i_g_weight ,2) not between i_min_weight and i_max_weight then
                   if i_edit_eligible = TRUE then
                        o_tolerance_fail := 'Y';  --- moved inside
                        -- Vani commented not to pass mx_eligible as o_tolerance_fail  = 'Y'
                        --mx_eligible := 'N';
                        i_mx_why_not_eligible := i_mx_why_not_eligible || 'Weight is out of tolerance;';
                   end if;
                   ---o_tolerance_fail := 'Y';   moving inside if condition
              else
                   o_tolerance_fail := 'N';
              end if;
        end if;
    else
        null;
    end if; --comparing i_len_wid_ht_wt value
end chk_dimension_tolerance;


procedure chk_temp_tolerance(i_len_wid_ht_wt     in varchar2,
                             i_min_length        in number,
                             i_max_length        in number,
                             i_min_width         in number,
                             i_max_width         in number,
                             i_min_height        in number,
                             i_max_height        in number,
                             i_tmp_recalc_length in number,
                             i_tmp_recalc_width  in number,
                             i_tmp_recalc_height in number,
                             i_diag_measurement  in number,
                             i_diag_control      in number,
                             o_tolerance_fail    out varchar2)is
begin
  if i_len_wid_ht_wt = 'LEN' then
       if i_tmp_recalc_length between i_min_length and i_max_length then
          o_tolerance_fail := 'N';
       else
          o_tolerance_fail := 'Y';
       end if;
  elsif i_len_wid_ht_wt = 'WID' then
       if i_tmp_recalc_width between i_min_width and i_max_width then
          o_tolerance_fail := 'N';
       else
          o_tolerance_fail := 'Y';
       end if;
  elsif i_len_wid_ht_wt = 'HT' then
       if i_tmp_recalc_height between i_min_height and i_max_height then
          o_tolerance_fail := 'N';
       else
          o_tolerance_fail := 'Y';
       end if;
  elsif i_len_wid_ht_wt = 'DIA' then
       if i_diag_measurement < i_diag_control then             
          o_tolerance_fail := 'N';
       else
          o_tolerance_fail := 'Y';
       end if;      
  end if;
end chk_temp_tolerance;

FUNCTION ffu_calc_diag_measurement (i_length in number,
                                    i_width  in number) RETURN NUMBER IS
BEGIN
  return round(sqrt(power(i_length,2) + power(i_width,2)),2);
END;

PROCEDURE calling_from_form(i_val  in varchar2) IS
BEGIN
--i_val must be 'Y' or 'N'
g_form_check := i_val;
END;
END pl_vr_matrix_eligible;
/

create or replace public synonym pl_vr_matrix_eligible for swms.pl_vr_matrix_eligible;
grant execute on swms.pl_vr_matrix_eligible to swms_user;
grant execute on swms.pl_vr_matrix_eligible to swms_viewer;
