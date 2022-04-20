---------------------------------
-- Package STRING_TRANSLATION
---------------------------------
Create or Replace
Package swms.String_Translation Is
--****************************************************************************************************************************************
--****************************************************************************************************************************************
k_id_default_language          Number := -1;
g_id_current_language          Number := k_id_default_language;
--****************************************************************************************************************************************
--****************************************************************************************************************************************
Function  Get_Current_Language           Return Number;
--****************************************************************************************************************************************
--****************************************************************************************************************************************
Function  Get_Default_Language           Return Number;
--****************************************************************************************************************************************
--****************************************************************************************************************************************
Function  Get_String                    (   p_id_mess                 IN        Number               ,
                                            p_string1                 IN        Varchar2 Default Null,
                                            p_string2                 IN        Varchar2 Default Null,
                                            p_string3                 IN        Varchar2 Default Null,
                                            p_string4                 IN        Varchar2 Default Null,
                                            p_string5                 IN        Varchar2 Default Null,
                                            p_string6                 IN        Varchar2 Default Null,
                                            p_string7                 IN        Varchar2 Default Null,
                                            p_string8                 IN        Varchar2 Default Null,
                                            p_string9                 IN        Varchar2 Default Null) Return Varchar2;
--****************************************************************************************************************************************
--****************************************************************************************************************************************
Procedure Set_Current_Language          (   p_id_language             IN        Number Default Null);
--****************************************************************************************************************************************
--****************************************************************************************************************************************
End;
/
---------------------------------
-- Package body STRING_TRANSLATION
---------------------------------
Create or Replace
Package Body swms.String_Translation Is
--****************************************************************************************************************************************
--****************************************************************************************************************************************
Function  Get_Current_Language           Return Number Is
Begin
    Return g_id_current_language;
End;
--****************************************************************************************************************************************
--****************************************************************************************************************************************
Function  Get_Default_Language           Return Number Is
l_ret_id_language              Number;
Begin
    --For rec In ( select id_language from language where current_language = 'Y') Loop
    --    l_ret_id_language := rec.id_language;
    --    Exit;
    --End Loop;
    
    If l_ret_id_language Is Null Then
        l_ret_id_language := k_id_default_language;
    End If;
    Return l_ret_id_language;
End;
--****************************************************************************************************************************************
--****************************************************************************************************************************************
Function  Get_String                    (   p_id_mess                 IN        Number               ,
                                            p_string1                 IN        Varchar2 Default Null,
                                            p_string2                 IN        Varchar2 Default Null,
                                            p_string3                 IN        Varchar2 Default Null,
                                            p_string4                 IN        Varchar2 Default Null,
                                            p_string5                 IN        Varchar2 Default Null,
                                            p_string6                 IN        Varchar2 Default Null,
                                            p_string7                 IN        Varchar2 Default Null,
                                            p_string8                 IN        Varchar2 Default Null,
                                            p_string9                 IN        Varchar2 Default Null) Return Varchar2 Is
l_message                      Varchar2(1000);
l_current_language             Number;
Begin
    If p_id_mess >= 0 Then
        Begin
            select   v_message
              into	 l_message
              from   message_table
             where   id_message  = p_id_mess
               and   id_language = Get_Current_Language;
        Exception
            When No_Data_Found Then
                l_message := 'Message ' || p_id_mess || ' is not defined for this language.';
        End;

        l_message := Replace (l_message, '%s1', p_string1);
        l_message := Replace (l_message, '%s2', p_string2);
        l_message := Replace (l_message, '%s3', p_string3);
        l_message := Replace (l_message, '%s4', p_string4);
        l_message := Replace (l_message, '%s5', p_string5);
        l_message := Replace (l_message, '%s6', p_string6);
        l_message := Replace (l_message, '%s7', p_string7);
        l_message := Replace (l_message, '%s8', p_string8);
        l_message := Replace (l_message, '%s9', p_string9);

    End if;

    l_message := Substr(l_message, 1, 500);

    Return(l_message);

End;
--****************************************************************************************************************************************
--****************************************************************************************************************************************
Procedure Set_Current_Language          (   p_id_language             IN        Number Default Null) Is
Begin
    If p_id_language Is Null Then
        g_id_current_language := Get_Default_Language;
    Else
        g_id_current_language := p_id_language;
    End If;
End;
--****************************************************************************************************************************************
--****************************************************************************************************************************************
End; -- Package Body STRING_TRANSLATION
/
--***************************************************************************************************************************************
--*** Create public synonym ******
--***************************************************************************************************************************************

CREATE OR REPLACE PUBLIC SYNONYM STRING_TRANSLATION 
   FOR SWMS.STRING_TRANSLATION;

--***************************************************************************************************************************************
