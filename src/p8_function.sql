-- ex. 8: formulati in limbaj natural o problema pe care sa o rezolvati folosind un subprogram stocat independent de tip functie care sa utilizeze intr-o singura comanda SQL trei dintre tabelele create
-- tratati toate exceptiile care pot aparea, incluzand exceptiile predefinite NO_DATA_FOUND si TOO_MANY_ROWS

-- sa se determine numele stadionului pe care joaca echipa sponsorizata de un sponsor al carui id este dat ca parametru

CREATE OR REPLACE FUNCTION f_STADION_SPONSOR(p_id_sponsor IN sponsor.id_sponsor%TYPE)
    RETURN stadion.nume%TYPE IS
    
    v_nume_stadion                      stadion.nume%TYPE;
    v_sponsor                           NUMBER;
    
BEGIN
    -- verific mai intai daca exista sponsorul dat ca parametru (caz de no_data_found)
    SELECT COUNT(*)
    INTO v_sponsor
    FROM sponsor
    WHERE id_sponsor = p_id_sponsor;
    
    IF v_sponsor = 0 THEN
        RAISE_APPLICATION_ERROR(-20020, 'Nu există un sponsor cu id-ul specificat.');
    END IF;
    
    -- daca sponsorul exista, atunci preiau numele stadionului raportat la echipa sponsorizata
    SELECT s.nume
    INTO v_nume_stadion
    FROM stadion s
    JOIN echipa e ON e.id_stadion = s.id_stadion
    JOIN sponsorizare sz ON sz.id_echipa = e.id_echipa AND sz.id_sponsor = p_id_sponsor;
    
    RETURN v_nume_stadion;

EXCEPTION 
    -- caz de no_data_found -> sponsor existent, fara sponsorizari active
    WHEN NO_DATA_FOUND THEN
        RAISE_APPLICATION_ERROR(-20021, 'Nu există echipe care au încheiat un contract de sponsorizare cu sponsorul specificat.');
    
    WHEN TOO_MANY_ROWS THEN
        RAISE_APPLICATION_ERROR(-20022, 'Sponsorul specificat este asociat cu mai mult de o echipă');
END;
/

SET SERVEROUTPUT ON;

DECLARE
    v_stadion                           stadion.nume%TYPE;
    v_id_sponsor                        sponsor.id_sponsor%TYPE := 10;
    v_nume_sponsor                      sponsor.nume%TYPE;
    
BEGIN
    v_stadion := f_STADION_SPONSOR(v_id_sponsor);
    
    -- pentru afisare:
    SELECT nume
    INTO v_nume_sponsor
    FROM sponsor
    WHERE id_sponsor = v_id_sponsor;
    
    DBMS_OUTPUT.PUT_LINE('Sponsor: ' || v_nume_sponsor);
    
    DBMS_OUTPUT.PUT_LINE('Stadionul echipei: ' || v_stadion);
END;
/
    
