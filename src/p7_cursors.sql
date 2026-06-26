-- 7. formulati in limbaj natural o problema pe care sa o rezolvati folosind un subprogram stocat independent care sa utilizeze doua tipuri diferite de cursoare studiate,
-- unul dintre acesta fiind cursor parametrizat, dependent de celalalt cursor

-- pentru un campionat intern dat ca parametru, sa se afiseze echipele participante in competitiile europene de club care au obtinut o performanta remarcabila in cadrul acestora, 
-- in conditiile unei sponsorizari sub media sponsorizarilor pe echipa din competitie. Prin performanta remarcabila se intelege un golaveraj pozitiv, 
-- iar valoarea totala a contractelor de sponsorizare ale unei echipe este raportata la media competitiei in care aceasta activeaza, nu la media tututor competitiilor europene.


CREATE OR REPLACE PROCEDURE proc_SPONSOR_EURO(p_id_campionat IN campionat_intern.id_campionat%TYPE) IS
    v_nume_campionat                    campionat_intern.nume%TYPE;
    v_nume_competitie                   competitie_euro_club.nume_competitie%TYPE;

    -- ciclu cursor in care retin valorile contractelor de sponsorizare pentru o echipa data ca parametru
    CURSOR contracte(p_id_echipa echipa.id_echipa%TYPE) IS
        SELECT valoare_contract
        FROM sponsorizare
        WHERE id_echipa = p_id_echipa;
        
    v_total_echipa                   NUMBER := 0;
    
    -- tablou indexat in care retin valorile medii ale contractelor per competitie europeana
    TYPE tablou_medii IS TABLE OF NUMBER INDEX BY PLS_INTEGER;
    
    t_medii                             tablou_medii;
    v_goluri_marcate                    NUMBER;
    v_goluri_primite                    NUMBER;
    v_golaveraj                         NUMBER;
    
    v_gasit                             BOOLEAN := FALSE;
BEGIN
    -- pentru afisare
    SELECT nume
    INTO v_nume_campionat
    FROM campionat_intern
    WHERE id_campionat = p_id_campionat;
    
    DBMS_OUTPUT.PUT_LINE('Campionat: ' || v_nume_campionat);
    
    -- calculez mediile sponsorizarilor echipelor dintr-o competitie (echipa A are contractele x:100, y:100; echipa B are z:50 -> media este (200+50)/2)
    -- imi trebuie sum pe echipa, apoi avg pe totaluri
    FOR m IN (
        SELECT id_competitie,
               AVG(total_echipa) AS medie_contracte
        FROM (
            -- calculez media contractelor pe echipa, in functie de competitia la care participa (deci sunt excluse echipele fara competitie)
            SELECT e.id_echipa, e.id_competitie,
                   SUM(s.valoare_contract) AS total_echipa
            FROM sponsorizare s
            JOIN echipa e ON s.id_echipa = e.id_echipa
            WHERE e.id_competitie IS NOT NULL
            GROUP BY e.id_echipa, e.id_competitie
        )
        GROUP BY id_competitie
    ) LOOP
        
        -- actualizez media pentru fiecare competitie    
        t_medii(m.id_competitie) := m.medie_contracte;
        
        DBMS_OUTPUT.PUT_LINE('Medie sponsorizări competiție ' || m.id_competitie || ' = ' || ROUND(m.medie_contracte, 2));
    END LOOP;
        
    -- ciclu cursor cu subcereri: procesez echipele din campionat care activeaza intr-o competitie europeana de club
    FOR e IN (
        SELECT id_echipa, id_competitie
        FROM echipa
        WHERE id_campionat = p_id_campionat AND id_competitie IS NOT NULL
    ) LOOP
    
        v_total_echipa := 0;
        
        -- pentru fiecare echipa, calculez totalul sponsorizarilor
        FOR c IN contracte(e.id_echipa) LOOP
            v_total_echipa := v_total_echipa + c.valoare_contract;
        END LOOP;
        
        -- calculez golaverajul fiecarei echipe -> verific daca echipa e gazda / oaspete si adun golurile corespunzatoare la total
        -- join cu meci_euro ca sa calculez golaverajul din cadrul competitiei (fara sa includ meciurile din cm_intern)
        SELECT 
        -- calculez numarul de goluri marcate; nvl pentru echipele care participa in competitie, dar nu au disputat meciuri
               NVL(SUM (CASE WHEN e.id_echipa = m.id_echipa_gazda 
                        THEN m.goluri_gazda ELSE m.goluri_oaspete
                    END
               ), 0) AS goluri_marcate,
                
        -- simetric, calculez numarul de goluri primite
                NVL(SUM (CASE WHEN e.id_echipa = m.id_echipa_gazda
                          THEN m.goluri_oaspete ELSE m.goluri_gazda
                     END
                ), 0) AS goluri_primite
        
        INTO v_goluri_marcate, v_goluri_primite
        FROM meci m
        JOIN meci_euro me ON m.id_meci = me.id_meci
        WHERE e.id_echipa IN (m.id_echipa_gazda, m.id_echipa_oaspete);

        v_golaveraj := v_goluri_marcate - v_goluri_primite;
                                 
        IF v_total_echipa < t_medii(e.id_competitie) AND v_golaveraj > 0 THEN
            v_gasit := TRUE;
        
            -- preiau numele competitiei pentru afisare
            SELECT nume_competitie
            INTO v_nume_competitie
            FROM competitie_euro_club
            WHERE id_competitie = e.id_competitie;
            
            DBMS_OUTPUT.PUT_LINE('Echipa: ' || e.id_echipa 
                                || ' | competiție: ' || v_nume_competitie || ' (id: ' || e.id_competitie ||')'
                                || ' | valoare sponsorizări: ' || v_total_echipa ||
                                 ' | golaveraj: ' || v_goluri_marcate || ':' || v_goluri_primite);
        END IF;
    END LOOP;
    
    IF NOT v_gasit THEN
        DBMS_OUTPUT.PUT_LINE('Nu există echipe din campionatul specificat care să participe în competiții europene sau care să îndeplinească criteriile de performanță și sponsorizare cerute.');
    END IF;

EXCEPTION 
    WHEN NO_DATA_FOUND THEN
        DBMS_OUTPUT.PUT_LINE('Nu există date corespunzătoare campionatului specificat.');
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('A apărut o eroare: ' || SQLERRM);
END;
/

BEGIN
    proc_SPONSOR_EURO(9);
END;
/

