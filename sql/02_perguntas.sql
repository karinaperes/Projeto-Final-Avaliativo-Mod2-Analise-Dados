-- =============================================================================
-- 02_perguntas.sql  -  As 6 perguntas de negócio da Controladoria
-- Banco: pncp_controladoria (modelo estrela carregado pelo src/carregar.py)
-- Regras usadas em todas as consultas:
--   * percentual = SOMA ÷ SOMA (nunca média de percentuais);
--   * economia só nos itens comparáveis (comparavel = 1, regra 6);
--   * NULLIF(denominador, 0) evita divisão por zero (ex.: Credenciamento não tem item comparável).
-- =============================================================================


-- -----------------------------------------------------------------------------
-- P1. ECONOMIA GLOBAL
-- Qual o percentual e o valor nominal economizado (estimado − homologado)?
-- -----------------------------------------------------------------------------
SELECT
    COUNT(*)                                                                    AS itens,
    SUM(CASE WHEN comparavel = 1 THEN 1 ELSE 0 END)                             AS itens_comparaveis,
    SUM(valor_total_homologado)                                                 AS volume_homologado,
    SUM(CASE WHEN comparavel = 1 THEN valor_total_estimado   ELSE 0 END)        AS estimado_comparavel,
    SUM(CASE WHEN comparavel = 1 THEN valor_total_homologado ELSE 0 END)        AS homologado_comparavel,
    SUM(CASE WHEN comparavel = 1 THEN economia_valor         ELSE 0 END)        AS economia_valor,
    ROUND(100 * SUM(CASE WHEN comparavel = 1 THEN economia_valor ELSE 0 END)
              / NULLIF(SUM(CASE WHEN comparavel = 1 THEN valor_total_estimado ELSE 0 END), 0), 2) AS economia_pct,
    SUM(CASE WHEN comparavel = 1 AND valor_total_homologado > valor_total_estimado THEN 1 ELSE 0 END) AS itens_sobrepreco
FROM fato_item_contratado;


-- -----------------------------------------------------------------------------
-- P2. CONCENTRAÇÃO DE FORNECEDORES
-- Quem são os 10 maiores fornecedores em volume e quanto do total está com eles?
-- -----------------------------------------------------------------------------
SELECT
    d.nome_fornecedor,
    d.ni_fornecedor,
    COUNT(*)                                       AS itens,
    SUM(f.valor_total_homologado)                  AS volume_homologado,
    ROUND(100 * SUM(f.valor_total_homologado)
              / (SELECT SUM(valor_total_homologado) FROM fato_item_contratado), 2) AS pct_do_total
FROM fato_item_contratado f
JOIN dim_fornecedor d ON d.sk_fornecedor = f.sk_fornecedor
GROUP BY d.nome_fornecedor, d.ni_fornecedor
ORDER BY volume_homologado DESC
LIMIT 10;

-- P2 (complemento). Quanto do volume total está concentrado nos 10 maiores
SELECT
    ROUND(100 * SUM(volume) / (SELECT SUM(valor_total_homologado) FROM fato_item_contratado), 2) AS pct_top10
FROM (SELECT SUM(valor_total_homologado) AS volume
      FROM fato_item_contratado
      GROUP BY sk_fornecedor
      ORDER BY volume DESC
      LIMIT 10) AS top10;


-- -----------------------------------------------------------------------------
-- P3. EFICÁCIA POR MODALIDADE
-- Quais modalidades trazem maior economia e quais concentram mais recursos?
-- -----------------------------------------------------------------------------
SELECT
    m.nome_modalidade,
    COUNT(*)                                                                    AS itens,
    SUM(f.valor_total_homologado)                                               AS volume_homologado,
    ROUND(100 * SUM(f.valor_total_homologado)
              / (SELECT SUM(valor_total_homologado) FROM fato_item_contratado), 2) AS pct_volume,
    SUM(CASE WHEN f.comparavel = 1 THEN f.economia_valor ELSE 0 END)            AS economia_valor,
    ROUND(100 * SUM(CASE WHEN f.comparavel = 1 THEN f.economia_valor ELSE 0 END)
              / NULLIF(SUM(CASE WHEN f.comparavel = 1 THEN f.valor_total_estimado ELSE 0 END), 0), 2) AS economia_pct
FROM fato_item_contratado f
JOIN dim_modalidade m ON m.sk_modalidade = f.sk_modalidade
GROUP BY m.nome_modalidade
ORDER BY volume_homologado DESC;


-- -----------------------------------------------------------------------------
-- P4. TEMPO DO CICLO DE COMPRAS POR ÓRGÃO
-- Duração média (dias) entre a publicação e a homologação, por órgão.
-- Agrupa pelo NOME do órgão (um órgão tem várias unidades/CNPJ), conta só itens
-- com ciclo (COUNT(dias_ciclo) ignora vazios) e mantém órgãos com 5 ou mais.
-- -----------------------------------------------------------------------------
SELECT
    o.nome_orgao,
    COUNT(f.dias_ciclo)               AS itens_com_ciclo,
    ROUND(AVG(f.dias_ciclo), 1)       AS ciclo_medio_dias,
    MAX(f.dias_ciclo)                 AS ciclo_maximo_dias
FROM fato_item_contratado f
JOIN dim_orgao o ON o.sk_orgao = f.sk_orgao
GROUP BY o.nome_orgao
HAVING COUNT(f.dias_ciclo) >= 5
ORDER BY ciclo_medio_dias DESC;

-- P4 (referência). Ciclo médio geral
SELECT
    COUNT(dias_ciclo)             AS itens_com_ciclo,
    ROUND(AVG(dias_ciclo), 1)     AS ciclo_medio_dias,
    MAX(dias_ciclo)               AS ciclo_maximo_dias
FROM fato_item_contratado;


-- -----------------------------------------------------------------------------
-- P5. DISTRIBUIÇÃO REGIONAL
-- Quais estados e regiões concentram as maiores despesas e os melhores descontos?
-- -----------------------------------------------------------------------------
-- Por região
SELECT
    l.regiao,
    COUNT(*)                                                                    AS itens,
    SUM(f.valor_total_homologado)                                               AS volume_homologado,
    ROUND(100 * SUM(f.valor_total_homologado)
              / (SELECT SUM(valor_total_homologado) FROM fato_item_contratado), 2) AS pct_volume,
    ROUND(100 * SUM(CASE WHEN f.comparavel = 1 THEN f.economia_valor ELSE 0 END)
              / NULLIF(SUM(CASE WHEN f.comparavel = 1 THEN f.valor_total_estimado ELSE 0 END), 0), 2) AS economia_pct
FROM fato_item_contratado f
JOIN dim_localidade l ON l.sk_localidade = f.sk_localidade
GROUP BY l.regiao
ORDER BY volume_homologado DESC;

-- Por estado
SELECT
    l.uf_sigla,
    l.regiao,
    COUNT(*)                                                                    AS itens,
    SUM(f.valor_total_homologado)                                               AS volume_homologado,
    ROUND(100 * SUM(f.valor_total_homologado)
              / (SELECT SUM(valor_total_homologado) FROM fato_item_contratado), 2) AS pct_volume,
    ROUND(100 * SUM(CASE WHEN f.comparavel = 1 THEN f.economia_valor ELSE 0 END)
              / NULLIF(SUM(CASE WHEN f.comparavel = 1 THEN f.valor_total_estimado ELSE 0 END), 0), 2) AS economia_pct
FROM fato_item_contratado f
JOIN dim_localidade l ON l.sk_localidade = f.sk_localidade
GROUP BY l.uf_sigla, l.regiao
ORDER BY volume_homologado DESC;


-- -----------------------------------------------------------------------------
-- P6. PERFIL DOS GASTOS
-- Como os recursos se distribuem entre bens, serviços e obras e engenharia?
-- (perfil_gasto é coluna da própria fato: não precisa de JOIN)
-- -----------------------------------------------------------------------------
SELECT
    perfil_gasto,
    COUNT(*)                                                                    AS itens,
    SUM(valor_total_homologado)                                                 AS volume_homologado,
    ROUND(100 * SUM(valor_total_homologado)
              / (SELECT SUM(valor_total_homologado) FROM fato_item_contratado), 1) AS pct_volume
FROM fato_item_contratado
GROUP BY perfil_gasto
ORDER BY volume_homologado DESC;
