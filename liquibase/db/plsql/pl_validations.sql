CREATE OR REPLACE PACKAGE PL_VALIDATIONS IS
    FUNCTION validate_upc(upc VARCHAR2) RETURN BOOLEAN;
END PL_VALIDATIONS;
/

CREATE OR REPLACE PACKAGE BODY PL_VALIDATIONS IS

    FUNCTION calculate_upc_value(upc VARCHAR2) RETURN INT IS
        total INT := 0;
        digit INT;
    BEGIN
        FOR i IN 1..length(upc) LOOP
            digit := to_number(substr(upc, i, 1));
            IF i IN (1, 3, 5, 7, 9, 11, 13) THEN
                total := total + (digit * 3);
            ELSIF i IN (2, 4, 6, 8, 10, 12) THEN
                total := total + digit;
            END IF;
        END LOOP;
        RETURN total;
    END calculate_upc_value;

    FUNCTION calculate_upc_check_digit(upc VARCHAR2) RETURN INT IS
    BEGIN
        RETURN 10 - mod(calculate_upc_value(upc), 10);
    END calculate_upc_check_digit;

    FUNCTION get_upc_last_digit(upc VARCHAR2) RETURN INT IS
    BEGIN
        RETURN to_number(substr(upc, -1));
    END get_upc_last_digit;

    FUNCTION validate_upc_check_digit(upc VARCHAR2) RETURN BOOLEAN IS
    BEGIN
        RETURN calculate_upc_check_digit(upc) <> get_upc_last_digit(upc);
    END validate_upc_check_digit;

    FUNCTION is_numeric(string IN VARCHAR2) RETURN BOOLEAN IS
        number_value NUMBER;
    BEGIN
        number_value := to_number(string);
        RETURN true;
    EXCEPTION WHEN VALUE_ERROR THEN
        RETURN false;
    END is_numeric;

    FUNCTION validate_upc(upc VARCHAR2) RETURN BOOLEAN IS
    BEGIN
        RETURN is_numeric(upc) AND length(upc) = 14 AND calculate_upc_value(upc) <> 0 AND validate_upc_check_digit(upc);
    END validate_upc;

END PL_VALIDATIONS;
/