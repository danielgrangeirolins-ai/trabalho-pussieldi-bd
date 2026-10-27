-- ============================================================
-- 29º TROFÉU ALEXANDRE PUSSIELDI (2025) - banco de resultados
-- PostgreSQL. Rodar inteiro:  \i trofeu_pussieldi.sql
-- Fonte dos dados: FASE Aquática (resultados oficiais do evento)
-- ============================================================

DROP TABLE IF EXISTS resultado, inscricao, equipe_revezamento, atleta, prova,
                     tabela_pontuacao, clube, categoria, etapa, evento CASCADE;

-- EVENTO: a competição em si. Separado para o banco aguentar
-- outras edições do troféu sem repetir nome/cidade em cada prova.
CREATE TABLE evento (
    id          SERIAL PRIMARY KEY,
    nome        VARCHAR(120) NOT NULL,
    edicao      INT          NOT NULL,
    cidade      VARCHAR(60)  NOT NULL,
    uf          CHAR(2)      NOT NULL,
    data_inicio DATE         NOT NULL,
    data_fim    DATE         NOT NULL,
    UNIQUE (nome, edicao),
    CHECK (data_fim >= data_inicio)
);

-- ETAPA: o regulamento divide o evento em 3 etapas (qui/sex/sáb).
-- Entidade fraca: só existe dentro de um evento.
CREATE TABLE etapa (
    id        SERIAL PRIMARY KEY,
    evento_id INT  NOT NULL REFERENCES evento(id) ON DELETE CASCADE,
    numero    INT  NOT NULL CHECK (numero BETWEEN 1 AND 3),
    data      DATE NOT NULL,
    UNIQUE (evento_id, numero)
);

-- CATEGORIA: a faixa é definida por ANO DE NASCIMENTO e muda a
-- cada temporada. Por isso não gravamos "idade" em lugar nenhum:
-- guardamos a faixa por temporada e a categoria sai da tabela.
CREATE TABLE categoria (
    id           SERIAL PRIMARY KEY,
    sigla        VARCHAR(3)  NOT NULL,
    descricao    VARCHAR(30) NOT NULL,
    temporada    INT         NOT NULL,
    ano_nasc_min INT         NOT NULL,
    ano_nasc_max INT         NOT NULL,
    UNIQUE (sigla, temporada),
    CHECK (ano_nasc_max >= ano_nasc_min)
);

CREATE TABLE clube (
    id    SERIAL PRIMARY KEY,
    sigla VARCHAR(30)  NOT NULL UNIQUE,
    nome  VARCHAR(100) NOT NULL
);

-- ATLETA: sexo fica aqui (é do atleta, não do resultado).
-- Clube fica aqui porque no festival o atleta nada por um só clube.
CREATE TABLE atleta (
    id             SERIAL PRIMARY KEY,
    nome           VARCHAR(100) NOT NULL,
    ano_nascimento INT          NOT NULL,
    sexo           CHAR(1)      NOT NULL CHECK (sexo IN ('F','M')),
    clube_id       INT          NOT NULL REFERENCES clube(id),
    UNIQUE (nome, ano_nascimento)
);

-- PROVA: ex.: "50m livre feminino Mirim 2". genero X = revezamento misto.
CREATE TABLE prova (
    id           SERIAL PRIMARY KEY,
    etapa_id     INT         NOT NULL REFERENCES etapa(id),
    categoria_id INT         NOT NULL REFERENCES categoria(id),
    numero       INT         NOT NULL,
    distancia    INT         NOT NULL CHECK (distancia IN (50,100,200,400)),
    estilo       VARCHAR(10) NOT NULL CHECK (estilo IN ('LIVRE','COSTAS','PEITO','BORBOLETA','MEDLEY')),
    genero       CHAR(1)     NOT NULL CHECK (genero IN ('F','M','X')),
    tipo         CHAR(1)     NOT NULL CHECK (tipo IN ('I','R')),   -- Individual / Revezamento
    realizada    BOOLEAN     NOT NULL DEFAULT TRUE,                 -- 6 provas ficaram sem inscritos
    UNIQUE (etapa_id, numero)
);

CREATE TABLE equipe_revezamento (
    id       SERIAL PRIMARY KEY,
    nome     VARCHAR(40) NOT NULL UNIQUE,
    clube_id INT         NOT NULL REFERENCES clube(id)
);

-- Art. 17: a pontuação é REGRA, não dado do resultado.
-- Guardar "pontos" em RESULTADO seria dependência transitiva
-- (colocacao -> pontos) e quebraria a 3FN.
CREATE TABLE tabela_pontuacao (
    colocacao INT PRIMARY KEY CHECK (colocacao BETWEEN 1 AND 16),
    pontos    INT NOT NULL CHECK (pontos > 0)
);

-- INSCRICAO: o clube inscreve o atleta (ou a equipe) na prova ANTES
-- de nadar. Série, raia e tempo de balizamento são definidos aqui,
-- no balizamento. Nem toda inscrição vira resultado: quem faltou
-- tem inscrição e não tem resultado (relação 1 : 0..1).
-- Valor: Art. 13 do regulamento (R$ 40 individual, R$ 160 revezamento).
CREATE TABLE inscricao (
    id                SERIAL PRIMARY KEY,
    prova_id          INT          NOT NULL REFERENCES prova(id) ON DELETE CASCADE,
    atleta_id         INT          REFERENCES atleta(id),
    equipe_id         INT          REFERENCES equipe_revezamento(id),
    serie             INT          NOT NULL CHECK (serie >= 1),
    raia              INT          NOT NULL CHECK (raia BETWEEN 1 AND 8),
    tempo_balizamento DECIMAL(7,2) CHECK (tempo_balizamento > 0),   -- nulo = sem tempo
    valor             DECIMAL(6,2) NOT NULL CHECK (valor >= 0),
    CHECK ((atleta_id IS NULL) <> (equipe_id IS NULL)),
    UNIQUE (prova_id, atleta_id),
    UNIQUE (prova_id, equipe_id),
    UNIQUE (prova_id, serie, raia)
);

-- RESULTADO: só existe para quem nadou (A = válido, D = desclassificado).
-- inscricao_id é UNIQUE: uma inscrição tem no máximo um resultado.
CREATE TABLE resultado (
    id             SERIAL PRIMARY KEY,
    inscricao_id   INT          NOT NULL UNIQUE REFERENCES inscricao(id) ON DELETE CASCADE,
    colocacao      INT          CHECK (colocacao >= 1),
    tempo          DECIMAL(7,2) CHECK (tempo > 0),    -- segundos
    indice_tecnico INT,
    status         CHAR(1)      NOT NULL CHECK (status IN ('A','D')),
    CHECK (status = 'A' OR (colocacao IS NULL AND tempo IS NULL))
);


-- ============================================================
-- DADOS REAIS (FASE Aquática, 27 a 29/03/2025, Maceió/AL)
-- ============================================================

INSERT INTO evento (id, nome, edicao, cidade, uf, data_inicio, data_fim) VALUES
  (1, 'Troféu Alexandre Pussieldi - Festival Nordestino Pré-Mirim a Mirim 2', 29, 'Maceió', 'AL', '2025-03-27', '2025-03-29');

INSERT INTO etapa (id, evento_id, numero, data) VALUES
  (1, 1, 1, '2025-03-27'), (2, 1, 2, '2025-03-28'), (3, 1, 3, '2025-03-29');

-- Faixas por ANO DE NASCIMENTO observadas nos resultados de 2025
-- (regra CBDA: idade = ano do evento - ano de nascimento).
INSERT INTO categoria (id, sigla, descricao, temporada, ano_nasc_min, ano_nasc_max) VALUES
  (1, 'PM', 'Pré-Mirim', 2025, 2017, 2018),
  (2, 'M1', 'Mirim 1',   2025, 2016, 2016),
  (3, 'M2', 'Mirim 2',   2025, 2015, 2015);

-- Art. 17 do regulamento (revezamento vale o dobro: tratado na consulta)
INSERT INTO tabela_pontuacao (colocacao, pontos) VALUES
  (1, 25),
  (2, 22),
  (3, 20),
  (4, 18),
  (5, 16),
  (6, 14),
  (7, 12),
  (8, 10),
  (9, 8),
  (10, 7),
  (11, 6),
  (12, 5),
  (13, 4),
  (14, 3),
  (15, 2),
  (16, 1);

INSERT INTO clube (id, sigla, nome) VALUES
  (1, 'AABB-RECIFE', 'ASS ATL BANCO DO BRASIL-RECIFE'),
  (2, 'AABB/CG', 'ASSOC ATLET BANCO DO BRASIL/CG'),
  (3, 'AADC/AL', 'AADC - ASSOCIAÇÃO ATLETICA DIEGO CALADO'),
  (4, 'AGITAÇÃO', 'AGITAÇÃO'),
  (5, 'AMBIANCE ESPORTE', 'AMBIANCE ESPORTE PRODUÇÕES E EVENTOS LTDA'),
  (6, 'BNB CLUBE', 'BNB CLUBE DE FORTALEZA'),
  (7, 'CEPE - NATAL', 'CLUBE DOS EMPREGADOS DA PETROBRAS CEPE - NATAL'),
  (8, 'CEPE/BA', 'CLUBE DOS EMPREGADOS DA PETROBRÁS'),
  (9, 'COPM - PB', 'CLUBE DOS OFICIAIS DA POLICIA MILITAR - PB'),
  (10, 'ECCB/ACQUA R1', 'ESPORTE CLUBE CABO BRANCO/ACQUA R1'),
  (11, 'FBDA/NATAÇÃO EM REDE', 'NATAÇÃO EM REDE'),
  (12, 'FENIX/NADART/AL', 'FENIX/NADART'),
  (13, 'JIM WILLSON', 'COLÉGIO JIM WILLSON ENSINO FEND. S/C LTDA'),
  (14, 'L4 TEAM', 'L4 TREINAMENTO LTDA'),
  (15, 'MARCIO CUNHA NATAÇÃO', 'MARCIO CUNHA NATAÇÃO'),
  (16, 'MASSAYO/STYLO/AL', 'ESPORTE CLUBE MASSAYÓ ECM'),
  (17, 'PORTUGUES/PE', 'CLUBE PORTUGUES DO RECIFE'),
  (18, 'SESC PERNAMBUCO', 'SERVIÇO SOCIAL DO COMERCIO - PE'),
  (19, 'SESI/PB', 'SESI PARAÍBA'),
  (20, 'SPORT/PE', 'SPORT CLUB DO RECIFE'),
  (21, 'SWIMMING SPORTS', 'SWIMMING SPORTS'),
  (22, 'UFERSA/UERN/ADNP', 'UNIVERSIDADE FEDERAL RURAL DO SEMI-ÁRIDO'),
  (23, 'VILA PARAHYBA', 'GRêMIO VILA OLÍMPICA PARAHYBA'),
  (24, 'YACHT CLUB/BA', 'YACHT CLUBE DA BAHIA');

INSERT INTO prova (id, etapa_id, categoria_id, numero, distancia, estilo, genero, tipo, realizada) VALUES
  (1, 1, 2, 1, 100, 'BORBOLETA', 'F', 'I', TRUE),
  (2, 1, 2, 2, 100, 'BORBOLETA', 'M', 'I', FALSE),
  (3, 1, 3, 3, 100, 'BORBOLETA', 'F', 'I', TRUE),
  (4, 1, 3, 4, 100, 'BORBOLETA', 'M', 'I', TRUE),
  (5, 1, 1, 5, 50, 'LIVRE', 'F', 'I', TRUE),
  (6, 1, 1, 6, 50, 'LIVRE', 'M', 'I', TRUE),
  (7, 1, 2, 7, 50, 'COSTAS', 'F', 'I', TRUE),
  (8, 1, 2, 8, 50, 'COSTAS', 'M', 'I', TRUE),
  (9, 1, 3, 9, 50, 'COSTAS', 'F', 'I', TRUE),
  (10, 1, 3, 10, 50, 'COSTAS', 'M', 'I', TRUE),
  (11, 1, 1, 11, 50, 'BORBOLETA', 'F', 'I', TRUE),
  (12, 1, 1, 12, 50, 'BORBOLETA', 'M', 'I', TRUE),
  (13, 1, 2, 13, 100, 'LIVRE', 'F', 'I', TRUE),
  (14, 1, 2, 14, 100, 'LIVRE', 'M', 'I', TRUE),
  (15, 1, 3, 15, 200, 'LIVRE', 'F', 'I', TRUE),
  (16, 1, 3, 16, 200, 'LIVRE', 'M', 'I', TRUE),
  (17, 1, 2, 17, 200, 'MEDLEY', 'X', 'R', TRUE),
  (18, 1, 3, 18, 200, 'MEDLEY', 'X', 'R', TRUE),
  (19, 2, 2, 19, 50, 'BORBOLETA', 'F', 'I', TRUE),
  (20, 2, 2, 20, 50, 'BORBOLETA', 'M', 'I', TRUE),
  (21, 2, 3, 21, 50, 'BORBOLETA', 'F', 'I', TRUE),
  (22, 2, 3, 22, 50, 'BORBOLETA', 'M', 'I', TRUE),
  (23, 2, 1, 23, 50, 'COSTAS', 'F', 'I', TRUE),
  (24, 2, 1, 24, 50, 'COSTAS', 'M', 'I', TRUE),
  (25, 2, 2, 25, 50, 'LIVRE', 'F', 'I', TRUE),
  (26, 2, 2, 26, 50, 'LIVRE', 'M', 'I', TRUE),
  (27, 2, 3, 27, 50, 'LIVRE', 'F', 'I', TRUE),
  (28, 2, 3, 28, 50, 'LIVRE', 'M', 'I', TRUE),
  (29, 2, 1, 29, 100, 'MEDLEY', 'F', 'I', TRUE),
  (30, 2, 1, 30, 100, 'MEDLEY', 'M', 'I', TRUE),
  (31, 2, 2, 31, 100, 'PEITO', 'F', 'I', TRUE),
  (32, 2, 2, 32, 100, 'PEITO', 'M', 'I', TRUE),
  (33, 2, 3, 33, 100, 'PEITO', 'F', 'I', TRUE),
  (34, 2, 3, 34, 100, 'PEITO', 'M', 'I', TRUE),
  (35, 2, 1, 35, 200, 'LIVRE', 'X', 'R', FALSE),
  (36, 2, 2, 36, 200, 'LIVRE', 'F', 'R', FALSE),
  (37, 2, 2, 37, 200, 'LIVRE', 'M', 'R', FALSE),
  (38, 2, 3, 38, 200, 'LIVRE', 'F', 'R', TRUE),
  (39, 2, 3, 39, 200, 'LIVRE', 'M', 'R', TRUE),
  (40, 3, 3, 40, 50, 'PEITO', 'F', 'I', TRUE),
  (41, 3, 3, 41, 50, 'PEITO', 'M', 'I', TRUE),
  (42, 3, 2, 42, 50, 'PEITO', 'F', 'I', TRUE),
  (43, 3, 2, 43, 50, 'PEITO', 'M', 'I', TRUE),
  (44, 3, 1, 44, 50, 'PEITO', 'F', 'I', TRUE),
  (45, 3, 1, 45, 50, 'PEITO', 'M', 'I', TRUE),
  (46, 3, 3, 46, 100, 'COSTAS', 'F', 'I', TRUE),
  (47, 3, 3, 47, 100, 'COSTAS', 'M', 'I', TRUE),
  (48, 3, 2, 48, 100, 'COSTAS', 'F', 'I', TRUE),
  (49, 3, 2, 49, 100, 'COSTAS', 'M', 'I', TRUE),
  (50, 3, 3, 50, 100, 'LIVRE', 'F', 'I', TRUE),
  (51, 3, 3, 51, 100, 'LIVRE', 'M', 'I', TRUE),
  (52, 3, 2, 52, 100, 'MEDLEY', 'F', 'I', TRUE),
  (53, 3, 2, 53, 100, 'MEDLEY', 'M', 'I', TRUE),
  (54, 3, 3, 54, 200, 'MEDLEY', 'F', 'I', TRUE),
  (55, 3, 3, 55, 200, 'MEDLEY', 'M', 'I', TRUE),
  (56, 3, 2, 56, 200, 'MEDLEY', 'F', 'R', FALSE),
  (57, 3, 2, 57, 200, 'MEDLEY', 'M', 'R', FALSE),
  (58, 3, 3, 58, 200, 'MEDLEY', 'F', 'R', TRUE),
  (59, 3, 3, 59, 200, 'MEDLEY', 'M', 'R', TRUE);

INSERT INTO atleta (id, nome, ano_nascimento, sexo, clube_id) VALUES
  (1, 'ALICE ROCHA CAVALCANTI', 2015, 'F', 1),
  (2, 'ANA CARLA CARACAS', 2015, 'F', 6),
  (3, 'ANA JULIA CEDRIM', 2018, 'F', 12),
  (4, 'ANTONIO TELES SILVA', 2015, 'M', 1),
  (5, 'ARTHUR VIEIRA ROCHA', 2017, 'M', 23),
  (6, 'AYLA SANTOS DE MELO', 2015, 'F', 20),
  (7, 'BERNARDO ACIOLI SOUZA', 2015, 'M', 1),
  (8, 'BERNARDO NASCIMENTO BONIFACIO', 2015, 'M', 8),
  (9, 'CAROLINA GUEIROS FAUSTINO', 2016, 'F', 1),
  (10, 'CAROLINE SILVA GADELHA', 2018, 'F', 20),
  (11, 'DANIEL FONTES HERESI', 2018, 'M', 21),
  (12, 'DAVI CAETANO OLIVEIRA MONTEIRO', 2016, 'M', 11),
  (13, 'DIEGO GAMA RODRIGUES', 2015, 'M', 12),
  (14, 'EDUARDO FERRAZ DANTAS', 2017, 'M', 8),
  (15, 'EDUARDO FONTES HERESI', 2018, 'M', 21),
  (16, 'ENRICO BEZERUSKA TESTONI', 2015, 'M', 10),
  (17, 'ENZO GABRIEL SANTOS', 2016, 'M', 23),
  (18, 'ESTER MANUELA GOMES', 2015, 'F', 16),
  (19, 'EZEQUIEL SILVA SANTOS', 2016, 'M', 19),
  (20, 'FABIO SANTOS MARINHO FILHO', 2017, 'M', 8),
  (21, 'FELIPE LEONARDO LIRA', 2015, 'M', 8),
  (22, 'FERNANDA LIMA LEON', 2016, 'F', 1),
  (23, 'FRANCISCO CLEMENTE DUARTE', 2017, 'M', 3),
  (24, 'GABRIEL BATISTA CORREIA', 2015, 'M', 4),
  (25, 'GABRIEL LOURENCO RIELLA', 2016, 'M', 5),
  (26, 'GABRIELLY MIRELLA BEZERRA', 2015, 'F', 23),
  (27, 'GUILHERME SENA SILVA NUNO DE SOUZA', 2015, 'M', 5),
  (28, 'GUSTAVO INOJOSA BAPTISTA', 2015, 'M', 1),
  (29, 'HANNY SILVA SALVADEU', 2015, 'F', 8),
  (30, 'HEITOR CABRAL LIMA', 2016, 'M', 23),
  (31, 'HELOISA SOUSA', 2015, 'F', 19),
  (32, 'ISAAC MEDEIROS DUARTE', 2015, 'M', 7),
  (33, 'ISABELLA MARQUES UCHOA', 2015, 'F', 13),
  (34, 'JOAO MIGUEL PEDROSA', 2015, 'M', 10),
  (35, 'JOAO PEDRO AZEVEDO', 2016, 'M', 1),
  (36, 'JOAQUIM SILVA NOVOLETO', 2015, 'M', 1),
  (37, 'JOSE MATEUS MARTINS SANTANA', 2015, 'M', 8),
  (38, 'JOÃO LUCAS FERREIRA DASMACENO COSTA', 2016, 'M', 7),
  (39, 'JULIA GOMES RIBEIRO', 2016, 'F', 23),
  (40, 'JULIA MEDEIROS PRADO', 2015, 'F', 21),
  (41, 'LAURA MARIA RODRIGUES', 2015, 'F', 1),
  (42, 'LEALDO REGO VIANA', 2016, 'M', 20),
  (43, 'LETICIA VILARIM SOBRINHO', 2016, 'F', 2),
  (44, 'LORENA SIQUEIRA MATOS', 2015, 'F', 20),
  (45, 'LUCAS ELY FRANCO VIANA', 2015, 'M', 15),
  (46, 'LUCAS MAIA ROCHA', 2015, 'M', 17),
  (47, 'LUNA TEIXEIRA BRASILEIRO', 2016, 'F', 14),
  (48, 'MARCELO INOJOSA BAPTISTA', 2015, 'M', 1),
  (49, 'MARCELO NEVES BELCHIOR', 2015, 'M', 18),
  (50, 'MARIA ANTONIA MELO', 2017, 'F', 1),
  (51, 'MARIA BEATRIZ BEZERRA DA SILVA', 2015, 'F', 9),
  (52, 'MARIA BEATRIZ CAVALCANTE', 2015, 'F', 1),
  (53, 'MARIA CECILIA FREITAS', 2017, 'F', 1),
  (54, 'MARIA CLARA CARNEIRO', 2015, 'F', 13),
  (55, 'MARIA CLARA LEITE', 2016, 'F', 18),
  (56, 'MARIA CLARA LIMA', 2015, 'F', 21),
  (57, 'MARIA EDUARDA GURGEL', 2015, 'F', 6),
  (58, 'MARIA ELIZA SIMOES', 2015, 'F', 21),
  (59, 'MARIA HELENA MEIRA NEVES', 2015, 'F', 8),
  (60, 'MARIA ISIS BARBOSA', 2015, 'F', 16),
  (61, 'MARIA ISIS MELO', 2015, 'F', 1),
  (62, 'MARIA JULIA ALMEIDA SOUZA', 2015, 'F', 24),
  (63, 'MARIA JULIA CAVALCANTI', 2017, 'F', 1),
  (64, 'MARIA LAURA TELES', 2016, 'F', 21),
  (65, 'MARIA LUISA ANDRADE', 2015, 'F', 1),
  (66, 'MARIA THEREZA RORIZ', 2015, 'F', 14),
  (67, 'MARIA VITORIA MAIA', 2016, 'F', 10),
  (68, 'MARYANNA SOUSA SILVA', 2015, 'F', 11),
  (69, 'MELINA FERRAZ CORREIA', 2016, 'F', 1),
  (70, 'MIGUEL LUZ ALBUQUERQUE', 2015, 'M', 6),
  (71, 'PEDRO BATISTA CORREIA', 2016, 'M', 4),
  (72, 'PEDRO MIGUEL COSTA', 2017, 'M', 12),
  (73, 'RAFAELA MONTENEGRO ARAUJO', 2015, 'F', 23),
  (74, 'RHAUAN VICTOR AMORIM', 2015, 'M', 23),
  (75, 'RODRIGO CABRAL SANTOS', 2016, 'M', 1),
  (76, 'ROGERIO FILIPE CATÃO', 2015, 'M', 10),
  (77, 'SOFIA PRATA SOBRAL', 2015, 'F', 21),
  (78, 'SOPHIA LAIS SILVA', 2016, 'F', 22),
  (79, 'TERCIO CORDEIRO LIMA', 2016, 'M', 20),
  (80, 'THALES MANOEL SANTANA NEVES', 2017, 'M', 8),
  (81, 'VALENTINA CARVALHO SHUNK', 2016, 'F', 14),
  (82, 'VICTOR RAFAEL SOUZA', 2015, 'M', 18),
  (83, 'VINICIUS ROBERTO ALBUQUERQUE', 2015, 'M', 1);

-- Equipes de revezamento (o site não publica a composição dos quartetos)
INSERT INTO equipe_revezamento (id, nome, clube_id) VALUES
  (1, 'AABB RECIFE A', 1),
  (2, 'AABB RECIFE B', 1),
  (3, 'CEPE/BA A', 8),
  (4, 'CS SERGIPE F', 21);

INSERT INTO inscricao (id, prova_id, atleta_id, equipe_id, serie, raia, tempo_balizamento, valor) VALUES
  (1, 1, 39, NULL, 1, 1, 137.48, 40.00),
  (2, 3, 6, NULL, 1, 4, 83.89, 40.00),
  (3, 3, 44, NULL, 1, 5, 98.18, 40.00),
  (4, 3, 65, NULL, 1, 2, NULL, 40.00),
  (5, 3, 2, NULL, 1, 3, 107.35, 40.00),
  (6, 3, 59, NULL, 1, 6, 121.08, 40.00),
  (7, 3, 56, NULL, 1, 7, NULL, 40.00),
  (8, 4, 70, NULL, 1, 5, NULL, 40.00),
  (9, 4, 46, NULL, 1, 4, 107.71, 40.00),
  (10, 5, 53, NULL, 1, 4, 53.97, 40.00),
  (11, 5, 50, NULL, 1, 3, 63.02, 40.00),
  (12, 5, 3, NULL, 1, 2, NULL, 40.00),
  (13, 5, 10, NULL, 1, 6, NULL, 40.00),
  (14, 5, 63, NULL, 1, 5, 58.38, 40.00),
  (15, 6, 72, NULL, 1, 4, 41.06, 40.00),
  (16, 6, 5, NULL, 1, 3, 48.11, 40.00),
  (17, 6, 23, NULL, 1, 6, NULL, 40.00),
  (18, 6, 20, NULL, 1, 2, NULL, 40.00),
  (19, 6, 14, NULL, 1, 5, 47.97, 40.00),
  (20, 6, 11, NULL, 1, 7, NULL, 40.00),
  (21, 6, 15, NULL, 1, 1, NULL, 40.00),
  (22, 7, 81, NULL, 1, 4, 46.92, 40.00),
  (23, 7, 55, NULL, 1, 5, 50.14, 40.00),
  (24, 7, 64, NULL, 1, 3, 54.74, 40.00),
  (25, 7, 69, NULL, 1, 6, 64.31, 40.00),
  (26, 7, 22, NULL, 1, 2, 64.91, 40.00),
  (27, 8, 12, NULL, 1, 2, NULL, 40.00),
  (28, 8, 35, NULL, 1, 4, 48.19, 40.00),
  (29, 8, 38, NULL, 1, 5, 48.93, 40.00),
  (30, 8, 17, NULL, 1, 6, 53.48, 40.00),
  (31, 8, 79, NULL, 1, 3, 51.57, 40.00),
  (32, 9, 29, NULL, 2, 4, 42.72, 40.00),
  (33, 9, 57, NULL, 2, 5, 43.56, 40.00),
  (34, 9, 68, NULL, 2, 3, 44.28, 40.00),
  (35, 9, 62, NULL, 2, 1, 48.21, 40.00),
  (36, 9, 44, NULL, 2, 6, 44.55, 40.00),
  (37, 9, 40, NULL, 2, 7, 46.13, 40.00),
  (38, 9, 52, NULL, 2, 2, 45.35, 40.00),
  (39, 9, 77, NULL, 1, 4, 52.39, 40.00),
  (40, 9, 1, NULL, 2, 8, 51.08, 40.00),
  (41, 9, 26, NULL, 1, 2, NULL, 40.00),
  (42, 9, 58, NULL, 1, 3, 61.77, 40.00),
  (43, 9, 60, NULL, 1, 5, 58.40, 40.00),
  (44, 9, 18, NULL, 1, 6, 63.23, 40.00),
  (45, 10, 27, NULL, 2, 4, 42.34, 40.00),
  (46, 10, 8, NULL, 2, 3, 45.88, 40.00),
  (47, 10, 36, NULL, 1, 4, NULL, 40.00),
  (48, 10, 49, NULL, 2, 5, 43.34, 40.00),
  (49, 10, 37, NULL, 2, 6, 47.35, 40.00),
  (50, 10, 24, NULL, 2, 2, 51.39, 40.00),
  (51, 10, 4, NULL, 2, 7, 52.52, 40.00),
  (52, 10, 28, NULL, 1, 3, NULL, 40.00),
  (53, 10, 48, NULL, 1, 5, NULL, 40.00),
  (54, 11, 53, NULL, 1, 4, 62.09, 40.00),
  (55, 11, 50, NULL, 1, 5, 72.29, 40.00),
  (56, 11, 3, NULL, 1, 3, NULL, 40.00),
  (57, 12, 23, NULL, 1, 4, NULL, 40.00),
  (58, 12, 20, NULL, 1, 5, NULL, 40.00),
  (59, 12, 11, NULL, 1, 3, NULL, 40.00),
  (60, 12, 15, NULL, 1, 6, NULL, 40.00),
  (61, 13, 81, NULL, 1, 7, NULL, 40.00),
  (62, 13, 78, NULL, 1, 5, 90.97, 40.00),
  (63, 13, 55, NULL, 1, 4, 88.89, 40.00),
  (64, 13, 9, NULL, 1, 6, 118.15, 40.00),
  (65, 13, 69, NULL, 1, 2, 122.10, 40.00),
  (66, 13, 22, NULL, 1, 3, 116.21, 40.00),
  (67, 14, 12, NULL, 1, 7, NULL, 40.00),
  (68, 14, 38, NULL, 1, 1, NULL, 40.00),
  (69, 14, 75, NULL, 1, 5, 92.10, 40.00),
  (70, 14, 35, NULL, 1, 4, 91.75, 40.00),
  (71, 14, 30, NULL, 1, 2, NULL, 40.00),
  (72, 14, 79, NULL, 1, 3, 102.31, 40.00),
  (73, 14, 17, NULL, 1, 6, NULL, 40.00),
  (74, 15, 6, NULL, 1, 4, 163.40, 40.00),
  (75, 15, 68, NULL, 1, 5, 181.60, 40.00),
  (76, 15, 31, NULL, 1, 3, 193.08, 40.00),
  (77, 15, 26, NULL, 1, 7, 215.56, 40.00),
  (78, 15, 61, NULL, 1, 2, 206.67, 40.00),
  (79, 15, 33, NULL, 1, 6, 201.69, 40.00),
  (80, 15, 73, NULL, 1, 1, 223.97, 40.00),
  (81, 15, 54, NULL, 1, 8, NULL, 40.00),
  (82, 16, 27, NULL, 1, 3, 170.52, 40.00),
  (83, 16, 70, NULL, 1, 4, 165.69, 40.00),
  (84, 16, 49, NULL, 1, 5, 167.24, 40.00),
  (85, 16, 83, NULL, 1, 2, NULL, 40.00),
  (86, 16, 7, NULL, 1, 6, 193.13, 40.00),
  (87, 16, 36, NULL, 2, 2, NULL, 40.00),
  (88, 16, 45, NULL, 1, 1, NULL, 40.00),
  (89, 17, NULL, 1, 1, 2, 216.20, 160.00),
  (90, 18, NULL, 3, 1, 3, NULL, 160.00),
  (91, 18, NULL, 1, 1, 4, 182.35, 160.00),
  (92, 18, NULL, 2, 1, 5, 198.83, 160.00),
  (93, 19, 78, NULL, 1, 4, 45.06, 40.00),
  (94, 19, 55, NULL, 1, 5, 46.72, 40.00),
  (95, 19, 81, NULL, 1, 3, 50.96, 40.00),
  (96, 19, 47, NULL, 1, 7, 72.49, 40.00),
  (97, 19, 64, NULL, 1, 8, NULL, 40.00),
  (98, 19, 9, NULL, 1, 6, 55.75, 40.00),
  (99, 19, 39, NULL, 1, 1, NULL, 40.00),
  (100, 19, 22, NULL, 1, 2, 66.16, 40.00),
  (101, 20, 12, NULL, 1, 4, 40.51, 40.00),
  (102, 20, 71, NULL, 1, 2, NULL, 40.00),
  (103, 20, 19, NULL, 1, 7, NULL, 40.00),
  (104, 20, 30, NULL, 1, 6, NULL, 40.00),
  (105, 20, 79, NULL, 1, 3, 50.73, 40.00),
  (106, 20, 75, NULL, 1, 5, 43.26, 40.00),
  (107, 21, 6, NULL, 2, 4, 38.78, 40.00),
  (108, 21, 44, NULL, 2, 3, 40.47, 40.00),
  (109, 21, 65, NULL, 2, 6, 41.49, 40.00),
  (110, 21, 62, NULL, 2, 5, 39.82, 40.00),
  (111, 21, 59, NULL, 2, 7, 46.06, 40.00),
  (112, 21, 52, NULL, 2, 2, 43.80, 40.00),
  (113, 21, 2, NULL, 1, 6, NULL, 40.00),
  (114, 21, 41, NULL, 1, 5, 54.20, 40.00),
  (115, 21, 33, NULL, 2, 8, 50.71, 40.00),
  (116, 21, 58, NULL, 1, 3, 58.24, 40.00),
  (117, 21, 54, NULL, 1, 4, 52.23, 40.00),
  (118, 21, 56, NULL, 1, 2, NULL, 40.00),
  (119, 21, 51, NULL, 2, 1, 48.57, 40.00),
  (120, 22, 82, NULL, 2, 4, 35.17, 40.00),
  (121, 22, 27, NULL, 2, 5, 37.53, 40.00),
  (122, 22, 70, NULL, 2, 3, 39.30, 40.00),
  (123, 22, 83, NULL, 2, 6, 42.00, 40.00),
  (124, 22, 34, NULL, 1, 3, NULL, 40.00),
  (125, 22, 21, NULL, 1, 4, 51.96, 40.00),
  (126, 22, 46, NULL, 2, 2, 44.71, 40.00),
  (127, 22, 7, NULL, 2, 7, 45.77, 40.00),
  (128, 22, 4, NULL, 2, 1, 51.55, 40.00),
  (129, 22, 16, NULL, 1, 5, NULL, 40.00),
  (130, 23, 53, NULL, 1, 5, 65.07, 40.00),
  (131, 23, 3, NULL, 1, 6, NULL, 40.00),
  (132, 23, 10, NULL, 1, 3, 69.48, 40.00),
  (133, 23, 63, NULL, 1, 4, 60.15, 40.00),
  (134, 24, 72, NULL, 1, 4, 48.35, 40.00),
  (135, 24, 5, NULL, 1, 5, 54.92, 40.00),
  (136, 24, 14, NULL, 1, 3, 69.40, 40.00),
  (137, 24, 20, NULL, 1, 2, NULL, 40.00),
  (138, 24, 80, NULL, 1, 6, NULL, 40.00),
  (139, 24, 11, NULL, 1, 7, NULL, 40.00),
  (140, 24, 15, NULL, 1, 1, NULL, 40.00),
  (141, 25, 81, NULL, 1, 4, 38.35, 40.00),
  (142, 25, 78, NULL, 1, 5, 39.82, 40.00),
  (143, 25, 43, NULL, 1, 3, 41.58, 40.00),
  (144, 25, 64, NULL, 1, 6, 46.52, 40.00),
  (145, 25, 47, NULL, 1, 2, 47.84, 40.00),
  (146, 25, 67, NULL, 1, 7, 49.75, 40.00),
  (147, 25, 69, NULL, 1, 8, 55.04, 40.00),
  (148, 25, 22, NULL, 1, 1, 51.93, 40.00),
  (149, 26, 12, NULL, 2, 4, 35.03, 40.00),
  (150, 26, 71, NULL, 1, 3, NULL, 40.00),
  (151, 26, 38, NULL, 2, 2, 40.88, 40.00),
  (152, 26, 35, NULL, 2, 3, 39.93, 40.00),
  (153, 26, 75, NULL, 2, 5, 39.16, 40.00),
  (154, 26, 79, NULL, 2, 6, 40.66, 40.00),
  (155, 26, 17, NULL, 2, 1, 44.93, 40.00),
  (156, 26, 30, NULL, 2, 7, 44.21, 40.00),
  (157, 26, 19, NULL, 2, 8, 45.03, 40.00),
  (158, 26, 42, NULL, 1, 5, NULL, 40.00),
  (159, 26, 25, NULL, 1, 4, 47.71, 40.00),
  (160, 27, 62, NULL, 2, 4, 34.20, 40.00),
  (161, 27, 29, NULL, 2, 5, 36.85, 40.00),
  (162, 27, 57, NULL, 2, 7, 40.72, 40.00),
  (163, 27, 26, NULL, 2, 1, 41.83, 40.00),
  (164, 27, 58, NULL, 1, 4, 43.09, 40.00),
  (165, 27, 31, NULL, 2, 6, 38.86, 40.00),
  (166, 27, 33, NULL, 2, 2, 40.71, 40.00),
  (167, 27, 73, NULL, 2, 8, 42.64, 40.00),
  (168, 27, 66, NULL, 1, 6, 48.43, 40.00),
  (169, 27, 41, NULL, 1, 3, 47.02, 40.00),
  (170, 27, 18, NULL, 1, 5, 46.08, 40.00),
  (171, 27, 60, NULL, 1, 2, 51.36, 40.00),
  (172, 27, 51, NULL, 2, 3, 38.28, 40.00),
  (173, 28, 82, NULL, 3, 4, 31.40, 40.00),
  (174, 28, 13, NULL, 3, 3, 35.87, 40.00),
  (175, 28, 32, NULL, 3, 7, 37.51, 40.00),
  (176, 28, 8, NULL, 3, 6, 36.28, 40.00),
  (177, 28, 46, NULL, 2, 4, 38.96, 40.00),
  (178, 28, 83, NULL, 3, 1, 37.81, 40.00),
  (179, 28, 7, NULL, 3, 2, 37.48, 40.00),
  (180, 28, 37, NULL, 3, 8, 38.42, 40.00),
  (181, 28, 34, NULL, 2, 5, 40.09, 40.00),
  (182, 28, 24, NULL, 2, 6, 41.07, 40.00),
  (183, 28, 76, NULL, 2, 3, 40.81, 40.00),
  (184, 28, 74, NULL, 2, 7, 43.15, 40.00),
  (185, 28, 28, NULL, 1, 5, 47.99, 40.00),
  (186, 28, 4, NULL, 1, 4, 45.66, 40.00),
  (187, 28, 48, NULL, 1, 3, 50.57, 40.00),
  (188, 28, 16, NULL, 2, 2, 42.21, 40.00),
  (189, 28, 45, NULL, 3, 5, 34.40, 40.00),
  (190, 29, 53, NULL, 1, 1, 143.60, 40.00),
  (191, 30, 72, NULL, 1, 6, NULL, 40.00),
  (192, 30, 5, NULL, 1, 5, NULL, 40.00),
  (193, 30, 20, NULL, 1, 3, NULL, 40.00),
  (194, 30, 14, NULL, 1, 4, NULL, 40.00),
  (195, 30, 11, NULL, 1, 2, NULL, 40.00),
  (196, 30, 15, NULL, 1, 7, NULL, 40.00),
  (197, 31, 43, NULL, 1, 4, 119.74, 40.00),
  (198, 31, 67, NULL, 1, 5, 129.19, 40.00),
  (199, 31, 39, NULL, 1, 3, 129.36, 40.00),
  (200, 32, 42, NULL, 1, 5, NULL, 40.00),
  (201, 32, 38, NULL, 1, 3, NULL, 40.00),
  (202, 32, 25, NULL, 1, 4, NULL, 40.00),
  (203, 33, 61, NULL, 1, 5, 110.48, 40.00),
  (204, 33, 1, NULL, 1, 4, 110.07, 40.00),
  (205, 33, 44, NULL, 1, 7, NULL, 40.00),
  (206, 33, 40, NULL, 1, 6, 121.62, 40.00),
  (207, 33, 73, NULL, 1, 3, 119.67, 40.00),
  (208, 33, 77, NULL, 1, 2, 154.58, 40.00),
  (209, 34, 8, NULL, 1, 4, 115.75, 40.00),
  (210, 34, 32, NULL, 1, 1, NULL, 40.00),
  (211, 34, 13, NULL, 1, 2, NULL, 40.00),
  (212, 34, 21, NULL, 1, 5, 116.50, 40.00),
  (213, 34, 74, NULL, 1, 3, 122.38, 40.00),
  (214, 34, 76, NULL, 1, 6, 133.71, 40.00),
  (215, 34, 45, NULL, 1, 7, NULL, 40.00),
  (216, 38, NULL, 1, 1, 4, 168.89, 160.00),
  (217, 38, NULL, 4, 1, 5, NULL, 160.00),
  (218, 39, NULL, 1, 1, 6, 184.87, 160.00),
  (219, 40, 62, NULL, 2, 2, 53.27, 40.00),
  (220, 40, 1, NULL, 2, 5, 51.63, 40.00),
  (221, 40, 61, NULL, 2, 3, 51.65, 40.00),
  (222, 40, 40, NULL, 2, 4, 50.65, 40.00),
  (223, 40, 73, NULL, 2, 7, 55.70, 40.00),
  (224, 40, 59, NULL, 1, 3, NULL, 40.00),
  (225, 40, 31, NULL, 2, 6, 52.40, 40.00),
  (226, 40, 77, NULL, 2, 1, 57.74, 40.00),
  (227, 40, 54, NULL, 1, 5, NULL, 40.00),
  (228, 40, 58, NULL, 1, 6, NULL, 40.00),
  (229, 40, 60, NULL, 2, 8, 72.71, 40.00),
  (230, 40, 18, NULL, 1, 2, NULL, 40.00),
  (231, 40, 51, NULL, 1, 4, NULL, 40.00),
  (232, 41, 8, NULL, 2, 4, 48.22, 40.00),
  (233, 41, 13, NULL, 2, 5, 48.93, 40.00),
  (234, 41, 32, NULL, 2, 7, 54.13, 40.00),
  (235, 41, 21, NULL, 2, 6, 52.69, 40.00),
  (236, 41, 24, NULL, 2, 3, 52.43, 40.00),
  (237, 41, 34, NULL, 2, 1, 55.01, 40.00),
  (238, 41, 37, NULL, 2, 8, 57.48, 40.00),
  (239, 41, 74, NULL, 1, 3, NULL, 40.00),
  (240, 41, 48, NULL, 1, 4, 69.53, 40.00),
  (241, 41, 28, NULL, 1, 5, 83.69, 40.00),
  (242, 41, 76, NULL, 2, 2, 53.95, 40.00),
  (243, 42, 55, NULL, 1, 4, 54.74, 40.00),
  (244, 42, 43, NULL, 1, 5, 56.11, 40.00),
  (245, 42, 67, NULL, 1, 2, NULL, 40.00),
  (246, 42, 39, NULL, 1, 6, NULL, 40.00),
  (247, 42, 64, NULL, 1, 7, NULL, 40.00),
  (248, 42, 9, NULL, 1, 3, NULL, 40.00),
  (249, 43, 71, NULL, 1, 6, NULL, 40.00),
  (250, 43, 42, NULL, 1, 4, 61.63, 40.00),
  (251, 43, 19, NULL, 1, 5, 62.44, 40.00),
  (252, 43, 25, NULL, 1, 3, 72.11, 40.00),
  (253, 44, 50, NULL, 1, 2, 66.36, 40.00),
  (254, 45, 72, NULL, 1, 4, 55.45, 40.00),
  (255, 45, 5, NULL, 1, 3, NULL, 40.00),
  (256, 45, 14, NULL, 1, 5, 73.41, 40.00),
  (257, 46, 57, NULL, 2, 4, 95.35, 40.00),
  (258, 46, 68, NULL, 2, 3, 99.69, 40.00),
  (259, 46, 29, NULL, 1, 4, NULL, 40.00),
  (260, 46, 65, NULL, 2, 5, 99.10, 40.00),
  (261, 46, 52, NULL, 2, 6, 101.96, 40.00),
  (262, 46, 2, NULL, 2, 2, 102.55, 40.00),
  (263, 46, 40, NULL, 2, 7, 107.38, 40.00),
  (264, 46, 41, NULL, 2, 1, NULL, 40.00),
  (265, 46, 56, NULL, 1, 5, NULL, 40.00),
  (266, 46, 66, NULL, 1, 3, NULL, 40.00),
  (267, 47, 82, NULL, 1, 4, 83.22, 40.00),
  (268, 47, 36, NULL, 1, 5, NULL, 40.00),
  (269, 47, 37, NULL, 1, 2, NULL, 40.00),
  (270, 47, 21, NULL, 1, 6, NULL, 40.00),
  (271, 47, 24, NULL, 1, 7, NULL, 40.00),
  (272, 47, 16, NULL, 1, 3, NULL, 40.00),
  (273, 48, 47, NULL, 1, 4, NULL, 40.00),
  (274, 49, 35, NULL, 1, 5, 108.60, 40.00),
  (275, 50, 68, NULL, 2, 4, 86.07, 40.00),
  (276, 50, 2, NULL, 2, 5, 86.53, 40.00),
  (277, 50, 26, NULL, 2, 7, 108.36, 40.00),
  (278, 50, 31, NULL, 2, 3, 87.99, 40.00),
  (279, 50, 33, NULL, 1, 5, NULL, 40.00),
  (280, 50, 1, NULL, 2, 6, 101.29, 40.00),
  (281, 50, 41, NULL, 2, 2, 107.29, 40.00),
  (282, 50, 18, NULL, 1, 3, NULL, 40.00),
  (283, 50, 54, NULL, 1, 4, NULL, 40.00),
  (284, 50, 60, NULL, 2, 1, 115.54, 40.00),
  (285, 50, 51, NULL, 2, 8, NULL, 40.00),
  (286, 51, 82, NULL, 2, 4, 70.28, 40.00),
  (287, 51, 13, NULL, 1, 6, NULL, 40.00),
  (288, 51, 49, NULL, 2, 5, 75.98, 40.00),
  (289, 51, 32, NULL, 2, 2, 90.42, 40.00),
  (290, 51, 46, NULL, 2, 3, 84.40, 40.00),
  (291, 51, 34, NULL, 2, 7, 90.90, 40.00),
  (292, 51, 36, NULL, 1, 4, NULL, 40.00),
  (293, 51, 16, NULL, 1, 3, NULL, 40.00),
  (294, 51, 76, NULL, 2, 1, 107.03, 40.00),
  (295, 51, 74, NULL, 1, 5, NULL, 40.00),
  (296, 51, 4, NULL, 2, 8, 109.03, 40.00),
  (297, 51, 45, NULL, 2, 6, 86.17, 40.00),
  (298, 52, 78, NULL, 1, 4, 110.18, 40.00),
  (299, 52, 47, NULL, 1, 2, NULL, 40.00),
  (300, 52, 67, NULL, 1, 6, NULL, 40.00),
  (301, 52, 43, NULL, 1, 3, NULL, 40.00),
  (302, 52, 9, NULL, 1, 5, 122.79, 40.00),
  (303, 53, 71, NULL, 1, 7, NULL, 40.00),
  (304, 53, 75, NULL, 1, 4, 106.64, 40.00),
  (305, 53, 17, NULL, 1, 3, NULL, 40.00),
  (306, 53, 30, NULL, 1, 6, NULL, 40.00),
  (307, 53, 19, NULL, 1, 1, NULL, 40.00),
  (308, 53, 42, NULL, 1, 2, NULL, 40.00),
  (309, 53, 25, NULL, 1, 5, 127.57, 40.00),
  (310, 54, 6, NULL, 2, 4, 190.28, 40.00),
  (311, 54, 29, NULL, 2, 7, NULL, 40.00),
  (312, 54, 65, NULL, 2, 2, NULL, 40.00),
  (313, 54, 52, NULL, 2, 5, 213.90, 40.00),
  (314, 54, 57, NULL, 2, 3, 216.67, 40.00),
  (315, 54, 61, NULL, 2, 6, 225.42, 40.00),
  (316, 54, 59, NULL, 1, 4, NULL, 40.00),
  (317, 54, 77, NULL, 1, 5, NULL, 40.00),
  (318, 54, 56, NULL, 1, 3, NULL, 40.00),
  (319, 55, 27, NULL, 1, 2, NULL, 40.00),
  (320, 55, 70, NULL, 1, 4, 191.52, 40.00),
  (321, 55, 49, NULL, 1, 5, 197.33, 40.00),
  (322, 55, 83, NULL, 1, 6, 219.23, 40.00),
  (323, 55, 7, NULL, 1, 3, 213.02, 40.00),
  (324, 58, NULL, 1, 1, 4, 195.99, 160.00),
  (325, 58, NULL, 4, 1, 5, NULL, 160.00),
  (326, 59, NULL, 1, 1, 6, 209.56, 160.00);

-- status: A = válido, D = desclassificado (quem faltou não tem linha aqui)
INSERT INTO resultado (inscricao_id, colocacao, tempo, indice_tecnico, status) VALUES
  (1, 1, 133.58, 66, 'A'),
  (2, 1, 83.85, 267, 'A'),
  (3, 2, 95.65, 180, 'A'),
  (4, 3, 98.46, 165, 'A'),
  (5, 4, 106.07, 132, 'A'),
  (6, 5, 107.61, 126, 'A'),
  (7, 6, 137.45, 60, 'A'),
  (8, 1, 90.18, 148, 'A'),
  (9, 2, 101.06, 105, 'A'),
  (10, 1, 49.58, 98, 'A'),
  (11, 2, 55.79, 69, 'A'),
  (12, 3, 56.78, 65, 'A'),
  (13, 4, 60.21, 55, 'A'),
  (15, 1, 40.21, 126, 'A'),
  (16, 2, 43.22, 101, 'A'),
  (17, 3, 43.49, 99, 'A'),
  (18, 4, 43.58, 98, 'A'),
  (19, 5, 43.81, 97, 'A'),
  (22, 1, 45.19, 174, 'A'),
  (23, 2, 49.81, 130, 'A'),
  (24, 3, 55.42, 94, 'A'),
  (25, 4, 67.49, 52, 'A'),
  (26, 5, 69.40, 48, 'A'),
  (27, 1, 42.77, 138, 'A'),
  (28, 2, 47.56, 100, 'A'),
  (29, 3, 49.32, 90, 'A'),
  (30, 4, 51.53, 78, 'A'),
  (31, 5, 53.67, 69, 'A'),
  (32, 1, 42.03, 216, 'A'),
  (33, 2, 42.11, 215, 'A'),
  (34, 3, 42.82, 205, 'A'),
  (35, 4, 44.89, 177, 'A'),
  (36, 5, 45.84, 167, 'A'),
  (37, 6, 46.07, 164, 'A'),
  (38, 7, 48.33, 142, 'A'),
  (39, 8, 49.89, 129, 'A'),
  (40, 9, 50.55, 124, 'A'),
  (41, 10, 50.66, 123, 'A'),
  (42, 11, 55.03, 96, 'A'),
  (43, 12, 59.51, 76, 'A'),
  (44, 13, 62.67, 65, 'A'),
  (45, 1, 40.54, 162, 'A'),
  (46, 2, 41.92, 146, 'A'),
  (47, 3, 42.61, 139, 'A'),
  (48, 4, 43.12, 134, 'A'),
  (49, 5, 44.38, 123, 'A'),
  (50, 6, 47.59, 100, 'A'),
  (51, 7, 51.57, 78, 'A'),
  (52, 8, 60.96, 47, 'A'),
  (53, 9, 63.36, 42, 'A'),
  (54, 1, 58.82, 71, 'A'),
  (55, 2, 67.82, 46, 'A'),
  (56, 3, 87.39, 21, 'A'),
  (57, 1, 54.23, 64, 'A'),
  (58, 2, 56.90, 55, 'A'),
  (61, 1, 86.94, 193, 'A'),
  (62, 2, 87.14, 191, 'A'),
  (63, 3, 91.54, 165, 'A'),
  (64, 4, 113.13, 87, 'A'),
  (65, 5, 119.97, 73, 'A'),
  (66, 6, 120.21, 73, 'A'),
  (67, 1, 77.59, 194, 'A'),
  (68, 2, 90.57, 122, 'A'),
  (69, 3, 91.33, 119, 'A'),
  (70, 4, 94.42, 107, 'A'),
  (71, 5, 97.01, 99, 'A'),
  (72, 6, 98.07, 96, 'A'),
  (73, 7, 99.18, 93, 'A'),
  (74, 1, 160.75, 324, 'A'),
  (75, 2, 171.13, 268, 'A'),
  (76, 3, 194.33, 183, 'A'),
  (77, 4, 200.23, 167, 'A'),
  (78, 5, 200.84, 166, 'A'),
  (79, 6, 201.01, 165, 'A'),
  (80, 7, 223.74, 120, 'A'),
  (81, NULL, NULL, NULL, 'D'),
  (82, 1, 154.79, 264, 'A'),
  (83, 2, 155.80, 259, 'A'),
  (84, 3, 173.93, 186, 'A'),
  (85, 4, 200.21, 122, 'A'),
  (86, 5, 201.89, 119, 'A'),
  (87, 6, 203.69, 116, 'A'),
  (89, 1, 216.80, NULL, 'A'),
  (90, 1, 172.58, NULL, 'A'),
  (91, 2, 174.50, NULL, 'A'),
  (92, 3, 192.42, NULL, 'A'),
  (93, 1, 44.35, 166, 'A'),
  (94, 2, 46.20, 146, 'A'),
  (95, 3, 49.59, 118, 'A'),
  (96, 4, 50.97, 109, 'A'),
  (97, 5, 53.90, 92, 'A'),
  (98, 6, 54.81, 88, 'A'),
  (99, 7, 61.86, 61, 'A'),
  (100, 8, 66.03, 50, 'A'),
  (101, 1, 39.09, 172, 'A'),
  (102, 2, 47.69, 94, 'A'),
  (103, 3, 50.39, 80, 'A'),
  (104, 4, 52.80, 69, 'A'),
  (105, 5, 54.21, 64, 'A'),
  (106, NULL, NULL, NULL, 'D'),
  (107, 1, 36.07, 308, 'A'),
  (108, 2, 38.53, 253, 'A'),
  (109, 3, 40.56, 217, 'A'),
  (110, 4, 40.65, 215, 'A'),
  (111, 5, 42.91, 183, 'A'),
  (112, 6, 44.22, 167, 'A'),
  (113, 7, 48.10, 130, 'A'),
  (114, 8, 49.54, 119, 'A'),
  (115, 9, 51.20, 107, 'A'),
  (116, 10, 56.23, 81, 'A'),
  (117, 11, 59.99, 67, 'A'),
  (118, 12, 61.43, 62, 'A'),
  (120, 1, 34.49, 250, 'A'),
  (121, 2, 35.25, 234, 'A'),
  (122, 3, 36.49, 211, 'A'),
  (123, 4, 40.64, 153, 'A'),
  (124, 5, 44.49, 116, 'A'),
  (125, 6, 44.59, 116, 'A'),
  (126, 7, 45.16, 111, 'A'),
  (127, 8, 45.34, 110, 'A'),
  (128, 9, 47.42, 96, 'A'),
  (129, 10, 56.46, 57, 'A'),
  (130, 1, 62.24, 66, 'A'),
  (131, 2, 62.97, 64, 'A'),
  (132, 3, 71.29, 44, 'A'),
  (134, 1, 46.18, 109, 'A'),
  (135, 2, 54.22, 67, 'A'),
  (136, 3, 57.86, 55, 'A'),
  (137, 4, 58.53, 53, 'A'),
  (138, 5, 81.60, 19, 'A'),
  (141, 1, 38.37, 213, 'A'),
  (142, 2, 38.60, 209, 'A'),
  (143, 3, 41.18, 172, 'A'),
  (144, 4, 41.81, 164, 'A'),
  (145, 5, 42.85, 153, 'A'),
  (146, 6, 46.62, 118, 'A'),
  (147, 7, 54.26, 75, 'A'),
  (148, 8, 54.43, 74, 'A'),
  (149, 1, 34.42, 200, 'A'),
  (150, 2, 38.04, 148, 'A'),
  (151, 3, 39.72, 130, 'A'),
  (152, 4, 39.98, 128, 'A'),
  (153, 5, 40.47, 123, 'A'),
  (154, 6, 40.49, 123, 'A'),
  (155, 7, 43.73, 97, 'A'),
  (156, 8, 43.74, 97, 'A'),
  (157, 9, 44.49, 93, 'A'),
  (158, 10, 53.82, 52, 'A'),
  (160, 1, 34.06, 305, 'A'),
  (161, 2, 35.19, 276, 'A'),
  (162, 3, 36.52, 247, 'A'),
  (163, 4, 38.64, 208, 'A'),
  (164, 5, 39.07, 202, 'A'),
  (165, 6, 39.18, 200, 'A'),
  (166, 7, 42.00, 162, 'A'),
  (167, 8, 42.77, 154, 'A'),
  (168, 9, 44.57, 136, 'A'),
  (169, 10, 47.50, 112, 'A'),
  (170, 11, 49.55, 99, 'A'),
  (171, 12, 49.70, 98, 'A'),
  (173, 1, 31.32, 266, 'A'),
  (174, 2, 33.31, 221, 'A'),
  (175, 3, 34.16, 205, 'A'),
  (176, 4, 34.32, 202, 'A'),
  (177, 5, 37.46, 155, 'A'),
  (178, 6, 37.80, 151, 'A'),
  (179, 7, 37.90, 150, 'A'),
  (180, 8, 38.61, 142, 'A'),
  (181, 9, 39.13, 136, 'A'),
  (182, 10, 39.80, 129, 'A'),
  (183, 11, 41.88, 111, 'A'),
  (184, 12, 42.76, 104, 'A'),
  (185, 13, 43.40, 100, 'A'),
  (186, 14, 44.97, 90, 'A'),
  (187, 15, 44.98, 90, 'A'),
  (188, 16, 45.03, 89, 'A'),
  (190, 1, 127.34, 87, 'A'),
  (191, 1, 101.57, 114, 'A'),
  (192, 2, 115.56, 77, 'A'),
  (193, 3, 120.74, 67, 'A'),
  (194, 4, 121.10, 67, 'A'),
  (197, 1, 114.02, 163, 'A'),
  (198, 2, 123.61, 128, 'A'),
  (199, 3, 128.31, 114, 'A'),
  (200, 1, 124.76, 86, 'A'),
  (201, 2, 125.56, 85, 'A'),
  (203, 1, 107.74, 193, 'A'),
  (204, 2, 109.36, 185, 'A'),
  (205, 3, 111.67, 174, 'A'),
  (206, 4, 112.69, 169, 'A'),
  (207, 5, 120.33, 139, 'A'),
  (208, 6, 124.56, 125, 'A'),
  (209, 1, 100.00, 168, 'A'),
  (210, 2, 107.08, 137, 'A'),
  (211, 3, 107.23, 137, 'A'),
  (212, 4, 109.46, 128, 'A'),
  (213, 5, 117.76, 103, 'A'),
  (214, 6, 123.21, 90, 'A'),
  (216, 1, 156.41, 206, 'A'),
  (217, 2, 167.70, 167, 'A'),
  (218, 1, 161.66, 129, 'A'),
  (219, 1, 47.40, 214, 'A'),
  (220, 2, 49.88, 183, 'A'),
  (221, 3, 50.15, 181, 'A'),
  (222, 4, 50.76, 174, 'A'),
  (223, 5, 51.60, 166, 'A'),
  (224, 6, 52.77, 155, 'A'),
  (225, 7, 53.10, 152, 'A'),
  (226, 8, 56.80, 124, 'A'),
  (227, 9, 60.60, 102, 'A'),
  (228, 10, 62.68, 92, 'A'),
  (229, 11, 68.53, 70, 'A'),
  (230, 12, 69.39, 68, 'A'),
  (232, 1, 44.81, 172, 'A'),
  (233, 2, 46.95, 150, 'A'),
  (234, 3, 47.19, 147, 'A'),
  (235, 4, 49.12, 131, 'A'),
  (236, 5, 51.17, 115, 'A'),
  (237, 6, 52.42, 107, 'A'),
  (238, 7, 53.63, 100, 'A'),
  (239, 8, 53.82, 99, 'A'),
  (240, 9, 66.53, 52, 'A'),
  (241, 10, 78.60, 31, 'A'),
  (242, NULL, NULL, NULL, 'D'),
  (243, 1, 54.32, 142, 'A'),
  (244, 2, 54.80, 138, 'A'),
  (245, 3, 57.86, 117, 'A'),
  (246, 4, 58.43, 114, 'A'),
  (247, 5, 66.78, 76, 'A'),
  (248, NULL, NULL, NULL, 'D'),
  (249, 1, 51.88, 111, 'A'),
  (250, 2, 56.44, 86, 'A'),
  (251, NULL, NULL, NULL, 'D'),
  (253, 1, 62.78, 92, 'A'),
  (254, 1, 52.90, 104, 'A'),
  (255, 2, 60.61, 69, 'A'),
  (256, 3, 62.23, 64, 'A'),
  (257, 1, 91.94, 212, 'A'),
  (258, 2, 93.67, 201, 'A'),
  (259, 3, 93.73, 200, 'A'),
  (260, 4, 96.89, 181, 'A'),
  (261, 5, 100.75, 161, 'A'),
  (262, 6, 103.39, 149, 'A'),
  (263, 7, 107.16, 134, 'A'),
  (264, 8, 116.48, 104, 'A'),
  (265, 9, 130.61, 74, 'A'),
  (266, 10, 137.48, 63, 'A'),
  (267, 1, 82.55, 200, 'A'),
  (268, 2, 98.05, 119, 'A'),
  (269, 3, 99.80, 113, 'A'),
  (270, 4, 105.40, 96, 'A'),
  (271, 5, 107.26, 91, 'A'),
  (272, 6, 118.27, 68, 'A'),
  (273, 1, 115.75, 106, 'A'),
  (274, 1, 110.38, 83, 'A'),
  (275, 1, 79.23, 255, 'A'),
  (276, 2, 87.66, 188, 'A'),
  (277, 3, 88.04, 185, 'A'),
  (278, 4, 88.37, 183, 'A'),
  (279, 5, 92.33, 161, 'A'),
  (280, 6, 94.58, 149, 'A'),
  (281, 7, 108.16, 100, 'A'),
  (282, 8, 110.55, 93, 'A'),
  (283, 9, 111.55, 91, 'A'),
  (284, 10, 116.09, 81, 'A'),
  (286, 1, 69.98, 264, 'A'),
  (287, 2, 79.87, 178, 'A'),
  (288, 3, 80.16, 176, 'A'),
  (289, 4, 80.35, 174, 'A'),
  (290, 5, 81.74, 166, 'A'),
  (291, 6, 91.61, 118, 'A'),
  (292, 7, 92.19, 115, 'A'),
  (293, 8, 95.69, 103, 'A'),
  (294, 9, 97.61, 97, 'A'),
  (295, 10, 97.95, 96, 'A'),
  (296, 11, 103.54, 81, 'A'),
  (298, 1, 104.46, 158, 'A'),
  (299, 2, 116.79, 113, 'A'),
  (300, 3, 117.66, 110, 'A'),
  (301, NULL, NULL, NULL, 'D'),
  (302, NULL, NULL, NULL, 'D'),
  (303, 1, 99.30, 122, 'A'),
  (304, 2, 103.40, 108, 'A'),
  (305, 3, 114.26, 80, 'A'),
  (306, 4, 121.25, 67, 'A'),
  (307, NULL, NULL, NULL, 'D'),
  (308, NULL, NULL, NULL, 'D'),
  (310, 1, 188.40, 270, 'A'),
  (311, 2, 207.43, 202, 'A'),
  (312, 3, 209.28, 197, 'A'),
  (313, 4, 211.27, 191, 'A'),
  (314, 5, 213.62, 185, 'A'),
  (315, 6, 216.08, 179, 'A'),
  (316, 7, 222.43, 164, 'A'),
  (317, 8, 242.25, 127, 'A'),
  (318, 9, 274.29, 87, 'A'),
  (319, 1, 181.67, 219, 'A'),
  (320, 2, 182.24, 217, 'A'),
  (321, 3, 200.01, 164, 'A'),
  (322, NULL, NULL, NULL, 'D'),
  (323, NULL, NULL, NULL, 'D'),
  (324, 1, 180.44, NULL, 'A'),
  (325, 2, 208.00, NULL, 'A'),
  (326, 1, 185.70, 112, 'A');

-- ajusta as sequências depois de inserir com id explícito
SELECT setval(pg_get_serial_sequence('evento', 'id'), (SELECT MAX(id) FROM evento));
SELECT setval(pg_get_serial_sequence('etapa', 'id'), (SELECT MAX(id) FROM etapa));
SELECT setval(pg_get_serial_sequence('categoria', 'id'), (SELECT MAX(id) FROM categoria));
SELECT setval(pg_get_serial_sequence('clube', 'id'), (SELECT MAX(id) FROM clube));
SELECT setval(pg_get_serial_sequence('prova', 'id'), (SELECT MAX(id) FROM prova));
SELECT setval(pg_get_serial_sequence('atleta', 'id'), (SELECT MAX(id) FROM atleta));
SELECT setval(pg_get_serial_sequence('equipe_revezamento', 'id'), (SELECT MAX(id) FROM equipe_revezamento));
SELECT setval(pg_get_serial_sequence('inscricao', 'id'), (SELECT MAX(id) FROM inscricao));

-- ============================================================
-- PROCEDURES
-- No PostgreSQL, PROCEDURE não devolve linhas (só faz ações, tipo
-- INSERT/UPDATE). Para "retornar uma tabela" que dá para consultar
-- com SELECT, o jeito padrão é FUNCTION ... RETURNS TABLE.
-- Mantive o prefixo sp_ pedido no enunciado.
-- ============================================================

-- ------------------------------------------------------------
-- sp_quatro_de_migalhas  ->  QUADRO DE MEDALHAS
-- Uso:  SELECT * FROM sp_quatro_de_migalhas(1);         -- geral
--       SELECT * FROM sp_quatro_de_migalhas(1, 'M2');   -- só Mirim 2
-- Regras:
--   * medalha = 1º, 2º ou 3º lugar com status 'A' (desclassificado não conta)
--   * revezamento conta medalha (como no quadro do site)
--   * ordenação olímpica: ouro, depois prata, depois bronze
--   * DENSE_RANK: empate divide a posição e o próximo segue (10º,10º,11º), igual ao site
--   * pontos = tabela do Art. 17, em dobro no revezamento
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION sp_quatro_de_migalhas(
    p_evento_id INT,
    p_categoria VARCHAR DEFAULT NULL          -- 'PM', 'M1', 'M2' ou NULL = todas
)
RETURNS TABLE (
    posicao   BIGINT,
    clube     VARCHAR,
    ouro      BIGINT,
    prata     BIGINT,
    bronze    BIGINT,
    total     BIGINT,
    pontos    BIGINT
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    WITH res AS (
        -- cada resultado válido, já com o clube (do atleta OU da equipe)
        SELECT  cl.sigla                                 AS clube,
                r.colocacao,
                tp.pontos * CASE WHEN pr.tipo = 'R' THEN 2 ELSE 1 END AS pts
        FROM resultado r
        JOIN inscricao ins ON ins.id = r.inscricao_id
        JOIN prova     pr ON pr.id = ins.prova_id
        JOIN etapa     et ON et.id = pr.etapa_id
        JOIN categoria ca ON ca.id = pr.categoria_id
        LEFT JOIN atleta             a  ON a.id  = ins.atleta_id
        LEFT JOIN equipe_revezamento eq ON eq.id = ins.equipe_id
        JOIN clube cl ON cl.id = COALESCE(a.clube_id, eq.clube_id)
        LEFT JOIN tabela_pontuacao tp ON tp.colocacao = r.colocacao
        WHERE et.evento_id = p_evento_id
          AND r.status = 'A'
          AND (p_categoria IS NULL OR ca.sigla = p_categoria)
    ),
    quadro AS (
        SELECT  res.clube,
                COUNT(*) FILTER (WHERE colocacao = 1) AS ouro,
                COUNT(*) FILTER (WHERE colocacao = 2) AS prata,
                COUNT(*) FILTER (WHERE colocacao = 3) AS bronze,
                COALESCE(SUM(pts), 0)                 AS pontos
        FROM res
        GROUP BY res.clube
    )
    SELECT  DENSE_RANK() OVER (ORDER BY q.ouro DESC, q.prata DESC, q.bronze DESC),
            q.clube,
            q.ouro, q.prata, q.bronze,
            q.ouro + q.prata + q.bronze,
            q.pontos::BIGINT
    FROM quadro q
    WHERE q.ouro + q.prata + q.bronze > 0           -- só quem subiu no pódio
    ORDER BY 1, q.pontos DESC, q.clube;
END;
$$;


-- ------------------------------------------------------------
-- sp_atlas_e_cubos  ->  ATLETAS E CLUBES (desempenho por equipe)
-- Uso:  SELECT * FROM sp_atlas_e_cubos(1);                  -- todos os clubes
--       SELECT * FROM sp_atlas_e_cubos(1, 'AABB-RECIFE');   -- um clube
-- Uma linha por clube: quantos atletas levou, quantas vezes nadou,
-- faltas, desclassificações, medalhas individuais, pontos e o
-- atleta destaque (quem mais pontuou pelo clube).
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION sp_atlas_e_cubos(
    p_evento_id INT,
    p_clube     VARCHAR DEFAULT NULL
)
RETURNS TABLE (
    clube              VARCHAR,
    atletas            BIGINT,
    nados              BIGINT,      -- inscrições em que nadou (válidas)
    faltas             BIGINT,
    desclassificacoes  BIGINT,
    medalhas_indiv     BIGINT,
    pontos_indiv       BIGINT,
    pontos_revez       BIGINT,
    pontos_total       BIGINT,
    media_it           NUMERIC,
    destaque           VARCHAR,
    pontos_destaque    BIGINT
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    WITH ind AS (                         -- inscrições individuais do evento
        -- LEFT JOIN: inscrição sem resultado = atleta faltou (status 'F')
        SELECT a.clube_id, a.id AS atleta_id, a.nome,
               COALESCE(r.status, 'F') AS status, r.colocacao,
               r.indice_tecnico, COALESCE(tp.pontos, 0) AS pts
        FROM inscricao ins
        JOIN atleta a ON a.id = ins.atleta_id
        LEFT JOIN resultado r ON r.inscricao_id = ins.id
        JOIN prova  pr ON pr.id = ins.prova_id
        JOIN etapa  et ON et.id = pr.etapa_id
        LEFT JOIN tabela_pontuacao tp ON tp.colocacao = r.colocacao AND r.status = 'A'
        WHERE et.evento_id = p_evento_id
    ),
    rev AS (                              -- pontos de revezamento (valem o dobro)
        SELECT eq.clube_id, SUM(tp.pontos * 2) AS pts
        FROM resultado r
        JOIN inscricao ins ON ins.id = r.inscricao_id
        JOIN equipe_revezamento eq ON eq.id = ins.equipe_id
        JOIN prova  pr ON pr.id = ins.prova_id
        JOIN etapa  et ON et.id = pr.etapa_id
        JOIN tabela_pontuacao tp ON tp.colocacao = r.colocacao
        WHERE et.evento_id = p_evento_id AND r.status = 'A'
        GROUP BY eq.clube_id
    ),
    por_atleta AS (                       -- ranking interno de cada clube
        SELECT ind.clube_id, ind.nome, SUM(ind.pts) AS pts,
               ROW_NUMBER() OVER (PARTITION BY ind.clube_id
                                  ORDER BY SUM(ind.pts) DESC, ind.nome) AS rk
        FROM ind
        GROUP BY ind.clube_id, ind.atleta_id, ind.nome
    )
    SELECT  c.sigla,
            COUNT(DISTINCT i.atleta_id),
            COUNT(*) FILTER (WHERE i.status = 'A'),
            COUNT(*) FILTER (WHERE i.status = 'F'),
            COUNT(*) FILTER (WHERE i.status = 'D'),
            COUNT(*) FILTER (WHERE i.status = 'A' AND i.colocacao <= 3),
            SUM(i.pts)::BIGINT,
            COALESCE(MAX(rv.pts), 0)::BIGINT,
            (SUM(i.pts) + COALESCE(MAX(rv.pts), 0))::BIGINT,
            ROUND(AVG(i.indice_tecnico), 1),
            MAX(pa.nome)::VARCHAR,
            MAX(pa.pts)::BIGINT
    FROM clube c
    JOIN ind i             ON i.clube_id = c.id
    LEFT JOIN rev rv       ON rv.clube_id = c.id
    LEFT JOIN por_atleta pa ON pa.clube_id = c.id AND pa.rk = 1
    WHERE p_clube IS NULL OR c.sigla = p_clube
    GROUP BY c.sigla
    ORDER BY 9 DESC, 1;
END;
$$;


-- ============================================================
-- CONSULTAS DE TESTE / PRINTS
-- ============================================================
-- SELECT * FROM sp_quatro_de_migalhas(1);
-- SELECT * FROM sp_quatro_de_migalhas(1, 'PM');
-- SELECT * FROM sp_atlas_e_cubos(1);
-- SELECT * FROM sp_atlas_e_cubos(1, 'AABB-RECIFE');
--
-- Conferência das categorias (todo atleta caiu na faixa da prova?):
-- SELECT ca.sigla, a.ano_nascimento, COUNT(DISTINCT a.id) AS atletas
-- FROM inscricao i
-- JOIN atleta a     ON a.id = i.atleta_id
-- JOIN prova p      ON p.id = i.prova_id
-- JOIN categoria ca ON ca.id = p.categoria_id
-- GROUP BY ca.sigla, a.ano_nascimento ORDER BY 1, 2;

-- Inscrições e arrecadação por clube (Art. 13):
-- SELECT c.sigla, COUNT(*) AS inscricoes, SUM(i.valor) AS valor_total,
--        COUNT(*) FILTER (WHERE r.id IS NULL) AS sem_resultado
-- FROM inscricao i
-- LEFT JOIN atleta a             ON a.id = i.atleta_id
-- LEFT JOIN equipe_revezamento e ON e.id = i.equipe_id
-- JOIN clube c ON c.id = COALESCE(a.clube_id, e.clube_id)
-- LEFT JOIN resultado r ON r.inscricao_id = i.id
-- GROUP BY c.sigla ORDER BY valor_total DESC;
