-- 6. formulati in limbaj natural o problema pe care sa o rezolvati folosind un subprogram stocat independent care sa utilizeze toate cele trei tipuri de colectii studiate

-- pentru toate echipele care evolueaza in cadrul unui campionat intern dat ca parametru, sa se afiseze informatii despre primii trei marcatori ai acestora, 
-- precum si date despre golurile marcate in toate competitiile la care au participat in acest sezon

SET SERVEROUTPUT ON;
CREATE OR REPLACE PROCEDURE proc_ECHIPE_MARCATORI (p_id_campionat IN campionat_intern.id_campionat%TYPE) IS
    -- tablou imbricat in care retin echipele
    TYPE tablou_echipe IS TABLE OF echipa.id_echipa%TYPE;
    t_echipe                    tablou_echipe := tablou_echipe();
    
    -- record cu informatii despre jucatori
    TYPE rec_jucatori IS RECORD (
        id_jucator              jucator.id_jucator%TYPE,
        nume                    jucator.nume%TYPE,
        prenume                 jucator.prenume%TYPE,
        nr_goluri               NUMBER
    );
    
    -- varray cu top 3 marcatori (contine record-uri cu informatii despre acestia)
    TYPE vector_jucatori IS VARRAY(3) OF rec_jucatori;
    v_jucatori                  vector_jucatori;
    
    -- record cu informatii despre golurile marcate
    TYPE rec_goluri IS RECORD (
        id_jucator              jucator.id_jucator%TYPE,
        mod_inscriere           gol.mod_inscriere%TYPE,
        minut_gol               gol.minut_gol%TYPE,
        adversar                echipa.id_echipa%TYPE
    );
    
    -- tablou indexat in care retin cate un record pentru fiecare gol marcat
    TYPE tablou_goluri IS TABLE OF rec_goluri INDEX BY PLS_INTEGER;
    t_goluri                    tablou_goluri;
    
    v_cnt                       PLS_INTEGER := 0;
    
BEGIN
    -- preiau toate echipele care activeaza in cadrul campionatului intern dat ca parametru
    SELECT id_echipa
    BULK COLLECT INTO t_echipe
    FROM echipa
    WHERE id_campionat = p_id_campionat;
    
    IF t_echipe.COUNT = 0 THEN
        RAISE_APPLICATION_ERROR(-20050, 'Nu există niciun campionat intern cu id-ul specificat sau nu există echipe asociate acestuia.');
    END IF;
    
    -- pentru fiecare echipa, selectez primii trei marcatori cu cele mai multe goluri
    FOR e IN t_echipe.FIRST .. t_echipe.LAST LOOP
    
        -- resetez vectorul pentru fiecare iteratie
        v_jucatori := vector_jucatori();
        
        -- in varray tin top 3 jucatori
        SELECT id_jucator, nume, prenume, nr_goluri
        BULK COLLECT INTO v_jucatori
        FROM (
            SELECT j.id_jucator, j.nume, j.prenume,
                   COUNT(*) AS nr_goluri
            FROM jucator j
            JOIN gol g ON g.id_jucator = j.id_jucator
            WHERE j.id_echipa = t_echipe(e)
                  AND g.validat = 'DA'                                -- atentie la golurile nevalidate
                  AND g.autogol = 'NU'
            GROUP BY j.id_jucator, j.nume, j.prenume
            ORDER BY nr_goluri DESC
        )
        WHERE ROWNUM <= 3;

        DBMS_OUTPUT.PUT_LINE('---------------------------------------------------------------------------------------------------------');

        DBMS_OUTPUT.PUT_LINE('Echipa: ' || t_echipe(e));
        
        IF v_jucatori.COUNT = 0 THEN
            DBMS_OUTPUT.PUT_LINE('Echipa nu a marcat niciun gol în acest sezon.');
            CONTINUE;
        END IF;
        
        -- pentru fiecare jucator din echipa curenta, preiau informatii despre golurile marcate
        FOR i IN 1..v_jucatori.COUNT LOOP
            -- resetez contorul pentru a afisa numarul golului curent, raportat la jucator
            v_cnt := 0;
            DBMS_OUTPUT.PUT_LINE('Jucator: ' || v_jucatori(i).prenume || ' ' || v_jucatori(i).nume ||
                         ' | Goluri marcate: ' || v_jucatori(i).nr_goluri);
                         
            FOR g IN (
                SELECT g.mod_inscriere, g.minut_gol,
                       CASE
                            WHEN m.id_echipa_gazda = j.id_echipa THEN m.id_echipa_oaspete
                            ELSE m.id_echipa_gazda
                        END AS echipa_adversa
                FROM gol g
                JOIN meci m ON g.id_meci = m.id_meci
                JOIN jucator j ON j.id_jucator = g.id_jucator
                WHERE g.id_jucator = v_jucatori(i).id_jucator
                      AND g.validat = 'DA'
                      AND g.autogol = 'NU'
            ) LOOP
                v_cnt := v_cnt + 1;
                
                t_goluri(v_cnt).id_jucator    := v_jucatori(i).id_jucator;
                t_goluri(v_cnt).mod_inscriere := g.mod_inscriere;
                t_goluri(v_cnt).minut_gol     := g.minut_gol;
                t_goluri(v_cnt).adversar      := g.echipa_adversa;

                                              
                DBMS_OUTPUT.PUT_LINE('Golul ' || v_cnt || ' | mod inscriere: ' || t_goluri(v_cnt).mod_inscriere || ' | minut gol: ' || t_goluri(v_cnt).minut_gol || 
                                     ' | echipa adversa: ' || t_goluri(v_cnt).adversar);
                DBMS_OUTPUT.PUT_LINE('');
                
            END LOOP;
        END LOOP;
    END LOOP;
END;
/

BEGIN
    proc_echipe_marcatori(8);
END;
/



-- intrebari de la prezentare lab:
-- cum am gestionat mutating trigger error
-- daca as transforma o functie in procedura, ce as face
-- pentru un nested table: unde folosesc constructorul, unde initializez tabelul, unde il populez; daca l-as schimba in tablou indexat, ar mai trebui sa initializez?
-- cum am gestionat dependenta dintre cele doua cursoare; daca as transforma primul cursor (ciclu cu subcereri) in cursor explicit, ce ar trebui sa fac?
-- rezumat exercitiul 13 (pachet) + ce colectii am folosit
