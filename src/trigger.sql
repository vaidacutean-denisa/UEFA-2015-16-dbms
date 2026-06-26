---- trigger lmd row-level: verific daca stadionul pe care se desfasoara meciul apartine echipei gazda (daca nu e finala europeana)
--CREATE OR REPLACE TRIGGER trg_STADION
--    BEFORE INSERT OR UPDATE ON MECI
--    FOR EACH ROW
--DECLARE
--    v_stadion_gazda             STADION.ID_STADION%TYPE;
--    v_nume_faza                 FAZA_COMPETITIE.NUME_FAZA%TYPE;
--    v_este_finala               VARCHAR2(2);        -- 'da' sau 'nu'
--
--BEGIN
--    -- preiau stadionul echipei gazda
--    SELECT id_stadion
--    INTO v_stadion_gazda
--    FROM echipa
--    WHERE id_echipa = :NEW.id_echipa_gazda;
--    
--    -- verific daca meciul este finala europeana, caz in care stadionul este neutru
--    BEGIN
--        SELECT f.nume_faza
--        INTO v_nume_faza
--        FROM meci_euro me
--        JOIN faza_competitie f ON me.id_competitie = f.id_competitie        -- join cu id_competitie pentru ca faza are pk compus
--                              AND me.id_faza_competitie = f.id_faza_competitie
--        WHERE me.id_meci = :NEW.id_meci;
--        
--        IF UPPER(v_nume_faza) LIKE '%FINAL%' THEN
--            v_este_finala := 'DA';
--        END IF;
--        
--    EXCEPTION
--        WHEN NO_DATA_FOUND THEN                 -- nu gaseste meci european cu id-ul cerut
--            v_este_finala := 'NU';
--    END;
--    
--    IF v_este_finala = 'NU' THEN
--        IF :NEW.id_stadion != v_stadion_gazda THEN
--            RAISE_APPLICATION_ERROR(-20001, 'Meciul trebuie să se desfășoare pe stadionul echipei gazdă, cu excepția finalelor europene.');
--        END IF;
--    END IF;
--END;
--/



-- probleme privind implementarea: cand introduc un meci in tabela meci, nu am cum sa stiu daca este finala europeana


CREATE OR REPLACE TRIGGER trg_STADION_EURO
    BEFORE INSERT OR UPDATE ON MECI_EURO
    FOR EACH ROW
DECLARE
    v_stadion_gazda             STADION.ID_STADION%TYPE;
    v_stadion_meci              STADION.ID_STADION%TYPE;
    v_nume_faza                 FAZA_COMPETITIE.NUME_FAZA%TYPE;

BEGIN
    -- preiau stadionul pe care se desfasoara meciul; in meci_euro nu am id_stadion ca sa fac :NEW.id_stadion
    SELECT id_stadion
    INTO v_stadion_meci
    FROM meci
    WHERE id_meci = :NEW.id_meci;
    
    -- preiau stadionul echipei gazda
    SELECT e.id_stadion
    INTO v_stadion_gazda
    FROM meci m
    JOIN echipa e ON m.id_echipa_gazda = e.id_echipa
    WHERE m.id_meci = :NEW.id_meci;
    
    -- preiau numele fazei pentru meciul european curent; in meci euro am date despre competitia in care se desfasoara -> :NEW.
    SELECT nume_faza
    INTO v_nume_faza
    FROM faza_competitie f
    WHERE id_competitie = :NEW.id_competitie 
          AND id_faza_competitie = :NEW.id_faza_competitie;
        
    -- daca meciul nu este finala si stadionul echipei gazda difera de stadionul pe care se desfasoara meciul -> eroare
    IF v_nume_faza <> 'Finala' THEN
        IF v_stadion_gazda <> v_stadion_meci THEN
            RAISE_APPLICATION_ERROR(-20001, 'Meciul trebuie să se desfășoare pe stadionul echipei gazdă, cu excepția finalelor europene.');
        END IF;
    END IF;
END;
/



CREATE OR REPLACE TRIGGER trg_STADION_INTERN
    BEFORE INSERT OR UPDATE ON MECI_INTERN
    FOR EACH ROW
DECLARE
    v_stadion_gazda             STADION.ID_STADION%TYPE;
    v_stadion_meci              STADION.ID_STADION%TYPE;

BEGIN
    -- preiau stadionul pe care se desfasoara meciul
    SELECT id_stadion
    INTO v_stadion_meci
    FROM meci                                   
    WHERE id_meci = :NEW.id_meci;
    
    -- preiau stadionul echipei gazda
    SELECT e.id_stadion
    INTO v_stadion_gazda
    FROM meci m
    JOIN echipa e ON m.id_echipa_gazda = e.id_echipa
    WHERE m.id_meci = :NEW.id_meci;
    
    IF v_stadion_meci <> v_stadion_gazda THEN
        RAISE_APPLICATION_ERROR(-20002, 'Meciul trebuie să se desfășoare pe stadionul echipei gazdă.');
    END IF;
END;
/

-- testare: 
INSERT INTO MECI(ID_STADION, DATA_MECI, ID_ECHIPA_GAZDA, ID_ECHIPA_OASPETE)
VALUES (18, TO_DATE('23-08-2015', 'DD-MM-YYYY'), 'SEV', 'LIV');                 -- sevilla este gazda, are id_stadion = 4

-- 1. introduc date in tabela meci_intern

INSERT INTO MECI_INTERN(ID_MECI, ID_CAMPIONAT, NUMAR_ETAPA)
VALUES (47, 10, 1);

-- 2. introduc date in tabela meci_euro
INSERT INTO MECI_EURO(ID_MECI, ID_COMPETITIE, ID_FAZA_COMPETITIE)
VALUES (47, 2, 5);



-- trigger row-level: atunci cand inserez date in tabela gol, sa se actualizeze coloana golurilor din tabela MECI, corespunzatoare echipei care a marcat
CREATE OR REPLACE TRIGGER trg_GOL_MECI
    AFTER INSERT OR DELETE ON GOL     -- in gol am id meci, id jucator si numar gol
    FOR EACH ROW
DECLARE
    v_echipa_jucator            ECHIPA.ID_ECHIPA%TYPE;
    v_gazda                     ECHIPA.ID_ECHIPA%TYPE;
    v_oaspete                   ECHIPA.ID_ECHIPA%TYPE;
    
BEGIN
    -- cazul 1: insert in tabela gol; folosesc :NEW -> valoarea randului dupa operatie
    IF INSERTING THEN
    
        -- preiau echipa jucatorului care a marcat
        SELECT id_echipa
        INTO v_echipa_jucator
        FROM jucator
        WHERE id_jucator = :NEW.id_jucator;
        
        -- preiau id-urile echipelor care joaca
        SELECT id_echipa_gazda, id_echipa_oaspete
        INTO v_gazda, v_oaspete
        FROM meci
        WHERE id_meci = :NEW.id_meci;
        
        -- update doar daca golul este valid
        IF :NEW.validat <> 'DA' THEN
            RETURN;
        END IF;
        
        -- daca golul este autogol, se aduna la golurile echipei adverse
        IF :NEW.autogol = 'DA' THEN
            IF v_echipa_jucator = v_gazda THEN              -- jucator gazda -> update pe oaspeti
                UPDATE meci
                SET goluri_oaspete = goluri_oaspete + 1
                WHERE id_meci = :NEW.id_meci;
            ELSE                                            -- jucatorul este oaspete, deci update pentru gazde
                UPDATE meci     
                SET goluri_gazda = goluri_gazda + 1
                WHERE id_meci = :NEW.id_meci;
            END IF;
        ELSE                                                -- nu e autogol, deci golul se aduna pentru echipa jucatorului            
            IF v_echipa_jucator = v_gazda THEN
                UPDATE meci
                SET goluri_gazda = goluri_gazda + 1
                WHERE id_meci = :NEW.id_meci;
            ELSE
                UPDATE meci
                SET goluri_oaspete = goluri_oaspete + 1
                WHERE id_meci = :NEW.id_meci;
            END IF;
        END IF;
    END IF;
    
    -- cazul 2: delete pe tabela gol; folosesc :OLD pentru ca randul nu mai exista
    IF DELETING THEN
        -- preiau echipa jucatorului care a marcat
        SELECT id_echipa
        INTO v_echipa_jucator
        FROM jucator
        WHERE id_jucator = :OLD.id_jucator;
        
        -- preiau id-urile echipelor care joaca
        SELECT id_echipa_gazda, id_echipa_oaspete
        INTO v_gazda, v_oaspete
        FROM meci
        WHERE id_meci = :OLD.id_meci;
        
        IF :OLD.validat <> 'DA' THEN                            
           RETURN;
        END IF;
        
        IF :OLD.autogol = 'DA' THEN                             -- daca este autogol si il sterg, scad numarul de goluri pentru echipa adversa
            IF v_echipa_jucator = v_gazda THEN              
                UPDATE meci
                SET goluri_oaspete = goluri_oaspete - 1
                WHERE id_meci = :OLD.id_meci;
            ELSE                                            
                UPDATE meci     
                SET goluri_gazda = goluri_gazda - 1
                WHERE id_meci = :OLD.id_meci;
            END IF;
        ELSE                                                    -- daca e gol normal si il sterg, scad numarul de goluri pentru echipa jucatorului               
            IF v_echipa_jucator = v_gazda THEN
                UPDATE meci
                SET goluri_gazda = goluri_gazda - 1
                WHERE id_meci = :OLD.id_meci;
            ELSE
                UPDATE meci
                SET goluri_oaspete = goluri_oaspete - 1
                WHERE id_meci = :OLD.id_meci;
            END IF;
        END IF;
    END IF;
END;
/

-- testare 
INSERT INTO MECI(ID_STADION, DATA_MECI, ID_ECHIPA_GAZDA, ID_ECHIPA_OASPETE)
VALUES (1, TO_DATE('24-02-2016', 'DD-MM-YYYY'), 'RMA', 'ROM');

INSERT INTO GOL(ID_MECI, NUMAR_GOL, ID_JUCATOR, VALIDAT, MOD_INSCRIERE, AUTOGOL, MINUT_GOL)
VALUES(50, 1, 30, 'DA', 'Corner', 'NU', 57);

INSERT INTO GOL(ID_MECI, NUMAR_GOL, ID_JUCATOR, VALIDAT, MOD_INSCRIERE, AUTOGOL, MINUT_GOL)
VALUES(50, 2, 33, 'DA', 'Șut din interiorul careului', 'NU', 54);

INSERT INTO GOL(ID_MECI, NUMAR_GOL, ID_JUCATOR, VALIDAT, MOD_INSCRIERE, AUTOGOL, MINUT_GOL)
VALUES(50, 3, 32, 'DA', 'Șut din interiorul careului', 'DA', 70);

INSERT INTO GOL(ID_MECI, NUMAR_GOL, ID_JUCATOR, VALIDAT, MOD_INSCRIERE, AUTOGOL, MINUT_GOL)
VALUES(50, 4, 32, 'NU', 'Șut din interiorul careului', 'NU', 71);

INSERT INTO GOL(ID_MECI, NUMAR_GOL, ID_JUCATOR, VALIDAT, MOD_INSCRIERE, AUTOGOL, MINUT_GOL)
VALUES(50, 5, 119, 'DA', 'Șut din interiorul careului', 'NU', 70);




-- trigger row-level: intr-un meci intern, echipele participante trebuie sa apartina aceluiasi campionat

CREATE OR REPLACE TRIGGER trg_MECI_CMI
    BEFORE INSERT OR UPDATE ON MECI_INTERN
    FOR EACH ROW

DECLARE 
    v_cmi_gazda                 campionat_intern.id_campionat%TYPE;
    v_cmi_oaspete               campionat_intern.id_campionat%TYPE;

BEGIN
    -- preiau campionatul echipelor
    SELECT e1.id_campionat, e2.id_campionat
    INTO v_cmi_gazda, v_cmi_oaspete
    FROM meci m
    JOIN echipa e1 ON e1.id_echipa = m.id_echipa_gazda
    JOIN echipa e2 ON e2.id_echipa = m.id_echipa_oaspete
    WHERE m.id_meci = :NEW.id_meci;
  
    -- conditia 1: echipele trebuie sa apartina aceluiasi campionat    
    IF v_cmi_gazda <> v_cmi_oaspete THEN
        RAISE_APPLICATION_ERROR(-20058, 'În cadrul unui meci intern, ambele echipe trebuie să aparțină aceluiași campionat.');
    END IF;

    -- conditia 2: campionatul de care apartin echipele trebuie sa coincida cu campionatul in care se desfasoara meciul
    IF :NEW.id_campionat <> v_cmi_gazda THEN
        RAISE_APPLICATION_ERROR(-20059, 'Campionatul în care se desfășoară meciul trebuie să coincidă cu campionatul de care aparțin echipele.');
    END IF;

END;
/

-- insert in tabela meci_intern
-- meci intre echipe din premier league
INSERT INTO MECI(ID_STADION, DATA_MECI, ID_ECHIPA_GAZDA, ID_ECHIPA_OASPETE)
VALUES (8, TO_DATE('10-08-2015', 'DD-MM-YYYY'), 'LIV', 'ARS');

-- il introduc in meci cu id_campionat = 2 (ligue 1)
INSERT INTO MECI_INTERN(ID_MECI, ID_CAMPIONAT, NUMAR_ETAPA)
VALUES (51, 2, 1);


-- meci intre echipe din campionate diferite

INSERT INTO MECI(ID_STADION, DATA_MECI, ID_ECHIPA_GAZDA, ID_ECHIPA_OASPETE)
VALUES (8, TO_DATE('10-08-2015', 'DD-MM-YYYY'), 'LIV', 'RMA');

-- il introduc in meci cu id_campionat = 1 (premier league, corespunzator echipei LIV)
INSERT INTO MECI_INTERN(ID_MECI, ID_CAMPIONAT, NUMAR_ETAPA)
VALUES (52, 1, 1);



-- trigger statement-level: numarul de echipe participante intr-o competitie europeana de club nu poate depasi numarul maxim declarat pentru competitia respectiva
-- after insert pentru ca ma intereseaza starea finala a tabelei, nu randul care urmeaza sa fie inserat
-- in plus, daca era row-level, as fi putut primi eroarea mutating table

-- cu before insert, nu am de unde sa stiu cate echipe vor fi inserate, deci nu stiu cand se incalca regula (de ex. cazul in care adaug mai multe echipe deodata)
CREATE OR REPLACE TRIGGER trg_ECHIPE_COMPETITIE
    AFTER INSERT OR UPDATE ON ECHIPA
DECLARE
    v_nr_echipe         NUMBER;
BEGIN
    FOR c IN (
        SELECT id_competitie, numar_echipe
        FROM competitie_euro_club
    ) LOOP
        SELECT COUNT(*)
        INTO v_nr_echipe
        FROM echipa e
        WHERE e.id_competitie = c.id_competitie;
        
        IF v_nr_echipe > c.numar_echipe THEN
            RAISE_APPLICATION_ERROR(-20011, 'Numărul de echipe participante depășește limita admisă pentru competiția curentă.');
        END IF;
    END LOOP;
END;
/

-- procedura care insereaza 20 de echipe (in id_competitie = 1 exista deja 14 echipe participante dintr-un maxim de 32)
BEGIN
    FOR i IN 1..20 LOOP
        INSERT INTO ECHIPA(ID_ECHIPA, ID_CAMPIONAT, ID_COMPETITIE, ID_STADION, TIP_STADION, NUME)
        VALUES ('E' || LPAD(i, 2, '0'), 1, 1, 1, 'PROPRIU', 'echipa test');
    END LOOP;
END;
/


-- trigger ldd: sa se salveze orice modificare de tip LDD asupra schemei denisa_test
CREATE TABLE audit_UEFA (
    utilizator          VARCHAR2(30),
    eveniment           VARCHAR2(30),
    nume_BD             VARCHAR2(30),
    obiect              VARCHAR2(50),
    tip_obiect          VARCHAR2(30),
    data                DATE
);

CREATE OR REPLACE TRIGGER trg_LDD
    BEFORE CREATE OR DROP OR ALTER ON SCHEMA
BEGIN
    
    INSERT INTO audit_UEFA 
    VALUES(SYS.LOGIN_USER, SYS.SYSEVENT, SYS.DATABASE_NAME, SYS.DICTIONARY_OBJ_NAME, SYS.DICTIONARY_OBJ_TYPE, SYSDATE);
END;
/

-- pentru testare, creez un tabel nou, apoi verific inregistrarile din tabela AUDIT_UEFA
CREATE TABLE test_trigger (
    id NUMBER
);


