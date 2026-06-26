-- formulati in limbaj natural o problema pe care sa o rezolvati folosind un subprogram stocat independent de tip procedura care sa aiba minim doi parametri si sa utilizeze 
-- intr-o singura comanda SQL 5 dintre tabelele create. Definiti minim doua exceptii proprii, altele decat cele predefinite la nivel de sistem.

-- !! pentru o echipa si un numar intreg k, sa se determine adversarul impotriva caruia echipa a inregistrat cele mai multe goluri primite in primele k minute dintr-un singur meci
-- nu vor fi luate in considerare autogolurile.
            
CREATE OR REPLACE PROCEDURE proc_ADVERSAR_K (
    p_id_echipa IN echipa.id_echipa%TYPE, 
    p_k IN NUMBER,
    p_echipa_adversa OUT echipa.id_echipa%TYPE,
    p_tip_competitie OUT VARCHAR2,
    p_nr_goluri OUT NUMBER
) IS
    
    -- contor pentru a verifica daca exista echipa specificata
    v_count                                     NUMBER;

    ex_K_INVALID                                EXCEPTION;
    ex_ECHIPA_INEXISTENTA                       EXCEPTION;
    
BEGIN
    -- k este cuprins intre limitele duratei unui meci (nu am atribut durata_meci explicit, dar un gol poate fi inscris intre minutele 1-130, considerand prelungiri / cazuri exceptionale)
    IF p_k < 1 OR p_k > 130 THEN
        RAISE ex_K_INVALID;
    END IF;
    
    -- echipa data ca parametru este inexistenta
    SELECT COUNT(*)
    INTO v_count
    FROM echipa
    WHERE id_echipa = p_id_echipa;
    
    IF v_count = 0 THEN
        RAISE ex_ECHIPA_INEXISTENTA;
    END IF;
        
    -- preiau (adversar, tip_competitie, nr_goluri) din lista de astfel de valori
    SELECT adversar, tip_competitie, nr_goluri
    INTO p_echipa_adversa, p_tip_competitie, p_nr_goluri
    FROM (
        SELECT 
            -- tipul competitiei (euro / intern) in care a fost inregistrat meciul
            CASE WHEN mi.id_meci IS NOT NULL THEN 'intern'
                 ELSE 'european'
            END AS tip_competitie,
            
            -- am nevoie de adversar, deci verific rolul in meci al echipei date ca parametru
            CASE WHEN m.id_echipa_gazda = p_id_echipa 
                 THEN m.id_echipa_oaspete
                 ELSE m.id_echipa_gazda
            END AS adversar,
            
            -- numarul de goluri marcate
            COUNT(*) AS nr_goluri,
            m.id_meci
            
        FROM meci m
        -- MI si ME ca sa aflu tipul competitiei; left join ca sa includ si valorile NULL (un meci nu poate fi simultan european si intern -> 1/2 = null)
        LEFT JOIN meci_euro me ON m.id_meci = me.id_meci
        LEFT JOIN meci_intern mi ON m.id_meci = mi.id_meci
        JOIN gol g ON m.id_meci = g.id_meci
        JOIN jucator j ON g.id_jucator = j.id_jucator
        
        WHERE p_id_echipa IN (m.id_echipa_gazda, m.id_echipa_oaspete)
             AND g.minut_gol <= p_k                                             -- goluri marcate in primele k minute
             AND j.id_echipa <> p_id_echipa                                     -- jucatorul sa activeze la echipa adversa (fara autogoluri)
             AND g.validat = 'DA'
             AND g.autogol = 'NU'
        GROUP BY                                                                -- grupez dupa (meci, adversar, competitie)
            CASE WHEN m.id_echipa_gazda = p_id_echipa
                 THEN m.id_echipa_oaspete
                 ELSE m.id_echipa_gazda
            END,
            CASE WHEN mi.id_meci IS NOT NULL THEN 'intern' 
                 ELSE 'european'
            END,
            m.id_meci                                                           -- daca nu grupez dupa meci, includ golurile din TOATE meciurile disputate intre aceleasi doua echipe
        ORDER BY nr_goluri DESC
        )
    -- iau echipa cu nr maxim de goluri; daca exista mai multe astfel de echipe, alege una dintre ele -> nu apare too_many_rows
    FETCH FIRST 1 ROW ONLY;

EXCEPTION
    WHEN ex_K_INVALID THEN
        RAISE_APPLICATION_ERROR(-20030, 'Parametrul k furnizat este invalid. Valoarea acestuia trebuie să fie în intervalul [1, 130].');
    
    WHEN ex_ECHIPA_INEXISTENTA THEN
        RAISE_APPLICATION_ERROR(-20031, 'Echipa furnizată ca parametru nu există în baza de date.');

    WHEN NO_DATA_FOUND THEN
        RAISE_APPLICATION_ERROR(-20032, 'Nu au fost înregistrate goluri împotriva echipei în primele ' || p_k || ' minute.');

END;
/

SET SERVEROUTPUT ON;

DECLARE 
    v_id_echipa                         echipa.id_echipa%TYPE;
    v_k                                 NUMBER;
    
    -- parametrii OUT
    v_adversar                          echipa.id_echipa%TYPE;
    v_tip_competitie                    VARCHAR2(40); 
    v_nr_goluri                         NUMBER;
    
BEGIN
    -- upper ca sa permit si variante lower ale id-urilor ('liv' si 'LIV')
    v_id_echipa := UPPER('abc');
    v_k := 10;
    
    proc_ADVERSAR_K(v_id_echipa, v_k, v_adversar, v_tip_competitie, v_nr_goluri);

    DBMS_OUTPUT.PUT_LINE('Echipa ' || v_adversar || ' a marcat ' || v_nr_goluri ||
                         CASE 
                            WHEN v_nr_goluri = 1 THEN ' gol'
                            ELSE ' goluri'
                         END ||
                         ' în primele ' || v_k || ' minute împotriva echipei ' || v_id_echipa || ', în cadrul unui meci ' || v_tip_competitie || '.');
END;
/
    
    

             