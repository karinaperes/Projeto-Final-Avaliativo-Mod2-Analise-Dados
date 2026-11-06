-- =============================================================================
-- 01_criar_banco.sql  -  Modelo estrela: 4 dimensões + 1 fato
-- Executado pelo src/carregar.py depois que o banco é recriado.
-- Ordem: dimensões primeiro, porque a fato tem chaves estrangeiras para elas.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- DIMENSÃO ÓRGÃO: quem comprou (uma linha por CNPJ de unidade compradora)
-- -----------------------------------------------------------------------------
CREATE TABLE dim_orgao (
    sk_orgao     INTEGER      PRIMARY KEY,               -- chave substituta (vem do Python: 1, 2, 3...)
    cnpj_orgao   VARCHAR(14)  NOT NULL UNIQUE,           -- chave natural, só dígitos
    nome_orgao   VARCHAR(255) NOT NULL,
    poder        VARCHAR(20)  NOT NULL
        CHECK (poder IN ('Executivo', 'Legislativo', 'Judiciário', 'Não informado'))
);

-- -----------------------------------------------------------------------------
-- DIMENSÃO FORNECEDOR: quem vendeu (uma linha por CNPJ/CPF)
-- -----------------------------------------------------------------------------
CREATE TABLE dim_fornecedor (
    sk_fornecedor   INTEGER      PRIMARY KEY,
    ni_fornecedor   VARCHAR(30)  NOT NULL UNIQUE,        -- CNPJ (14), CPF (11) ou documento estrangeiro
    nome_fornecedor VARCHAR(255) NOT NULL,
    tipo_pessoa     VARCHAR(2)   CHECK (tipo_pessoa IN ('PJ', 'PF', 'PE')),
    porte           VARCHAR(30)                          -- vazio quando a origem não informa
);

-- -----------------------------------------------------------------------------
-- DIMENSÃO MODALIDADE: como comprou
-- -----------------------------------------------------------------------------
CREATE TABLE dim_modalidade (
    sk_modalidade   INTEGER     PRIMARY KEY,
    modalidade_id   SMALLINT    NOT NULL UNIQUE,         -- código do PNCP (regra 9)
    nome_modalidade VARCHAR(50) NOT NULL
);

-- -----------------------------------------------------------------------------
-- DIMENSÃO LOCALIDADE: onde (uma linha por UF)
-- -----------------------------------------------------------------------------
CREATE TABLE dim_localidade (
    sk_localidade INTEGER     PRIMARY KEY,
    uf_sigla      CHAR(2)     NOT NULL UNIQUE,
    uf_nome       VARCHAR(30) NOT NULL,
    regiao        VARCHAR(15) NOT NULL
        CHECK (regiao IN ('Norte', 'Nordeste', 'Centro-Oeste', 'Sudeste', 'Sul', 'Não informado'))
);

-- -----------------------------------------------------------------------------
-- LINHAS DE EXCEÇÃO "Não informado" (sk = -1)
-- Fora da sequência 1, 2, 3... para nunca colidir com as chaves do Python.
-- Garantem destino para uma FK sem dado; nesta base nenhuma FK ficou sem destino.
-- -----------------------------------------------------------------------------
INSERT INTO dim_orgao      VALUES (-1, '-1', 'NÃO INFORMADO', 'Não informado');
INSERT INTO dim_fornecedor VALUES (-1, '-1', 'NÃO INFORMADO', NULL, NULL);
INSERT INTO dim_modalidade VALUES (-1, -1, 'Não informado');
INSERT INTO dim_localidade VALUES (-1, 'NI', 'NÃO INFORMADO', 'Não informado');

-- -----------------------------------------------------------------------------
-- FATO: um item contratado por linha, com o vencedor (regras 1 a 8)
-- -----------------------------------------------------------------------------
CREATE TABLE fato_item_contratado (
    sk_fato                   INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    numero_controle_pncp      VARCHAR(30)    NOT NULL,
    numero_item               INTEGER        NOT NULL,
    sk_orgao                  INTEGER        NOT NULL REFERENCES dim_orgao (sk_orgao),
    sk_fornecedor             INTEGER        NOT NULL REFERENCES dim_fornecedor (sk_fornecedor),
    sk_modalidade             INTEGER        NOT NULL REFERENCES dim_modalidade (sk_modalidade),
    sk_localidade             INTEGER        NOT NULL REFERENCES dim_localidade (sk_localidade),
    data_publicacao           DATE           NOT NULL,
    data_homologacao          DATE,                      -- vazia quando a regra 7 anula a homologação
    descricao_item            TEXT,
    perfil_gasto              VARCHAR(20)    NOT NULL
        CHECK (perfil_gasto IN ('Bens', 'Serviços', 'Obras e engenharia')),
    quantidade                DECIMAL(18,4)  NOT NULL CHECK (quantidade > 0),
    valor_unitario_estimado   DECIMAL(18,4)  NOT NULL CHECK (valor_unitario_estimado > 0),
    valor_total_estimado      DECIMAL(18,2)  NOT NULL CHECK (valor_total_estimado >= 0),
    valor_unitario_homologado DECIMAL(18,4)  NOT NULL CHECK (valor_unitario_homologado > 0),
    valor_total_homologado    DECIMAL(18,2)  NOT NULL CHECK (valor_total_homologado >= 0),
    comparavel                SMALLINT       NOT NULL CHECK (comparavel IN (0, 1)),
    economia_valor            DECIMAL(18,2),             -- pode ser negativa (sobrepreço)
    dias_ciclo                INTEGER        CHECK (dias_ciclo >= 0),

    -- grão da fato: um item por contratação
    CONSTRAINT uq_fato_item UNIQUE (numero_controle_pncp, numero_item),
    -- regra 7: homologação nunca antes da publicação
    CONSTRAINT ck_fato_cronologia CHECK (data_homologacao IS NULL OR data_homologacao >= data_publicacao)
);

-- Índices nas chaves estrangeiras: aceleram as junções com as dimensões
CREATE INDEX ix_fato_orgao      ON fato_item_contratado (sk_orgao);
CREATE INDEX ix_fato_fornecedor ON fato_item_contratado (sk_fornecedor);
CREATE INDEX ix_fato_modalidade ON fato_item_contratado (sk_modalidade);
CREATE INDEX ix_fato_localidade ON fato_item_contratado (sk_localidade);
