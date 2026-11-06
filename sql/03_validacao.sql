-- =============================================================================
-- 03_validacao.sql  -  Validação da carga: contagens, integridade e prova real
-- Rodar depois do src/carregar.py:
--   psql -h localhost -U postgres -d pncp_controladoria -f sql/03_validacao.sql
-- Cada consulta mostra o valor obtido ao lado do esperado (anexo 8 do enunciado).
-- =============================================================================

-- 1) Linhas por tabela (sem a linha "Não informado", sk = -1)
SELECT 'fato_item_contratado' AS tabela, COUNT(*) AS linhas, 6126 AS esperado FROM fato_item_contratado
UNION ALL SELECT 'dim_orgao',      COUNT(*), 363  FROM dim_orgao      WHERE sk_orgao > 0
UNION ALL SELECT 'dim_fornecedor', COUNT(*), 2652 FROM dim_fornecedor WHERE sk_fornecedor > 0
UNION ALL SELECT 'dim_modalidade', COUNT(*), 7    FROM dim_modalidade WHERE sk_modalidade > 0
UNION ALL SELECT 'dim_localidade', COUNT(*), 27   FROM dim_localidade WHERE sk_localidade > 0;

-- 2) Integridade referencial: itens da fato sem par na dimensão (esperado 0 em todas)
SELECT
    (SELECT COUNT(*) FROM fato_item_contratado f LEFT JOIN dim_orgao d      ON d.sk_orgao      = f.sk_orgao      WHERE d.sk_orgao IS NULL)      AS orfaos_orgao,
    (SELECT COUNT(*) FROM fato_item_contratado f LEFT JOIN dim_fornecedor d ON d.sk_fornecedor = f.sk_fornecedor WHERE d.sk_fornecedor IS NULL) AS orfaos_fornecedor,
    (SELECT COUNT(*) FROM fato_item_contratado f LEFT JOIN dim_modalidade d ON d.sk_modalidade = f.sk_modalidade WHERE d.sk_modalidade IS NULL) AS orfaos_modalidade,
    (SELECT COUNT(*) FROM fato_item_contratado f LEFT JOIN dim_localidade d ON d.sk_localidade = f.sk_localidade WHERE d.sk_localidade IS NULL) AS orfaos_localidade,
    (SELECT COUNT(*) FROM fato_item_contratado WHERE sk_orgao = -1 OR sk_fornecedor = -1
                                                  OR sk_modalidade = -1 OR sk_localidade = -1)                                      AS usando_nao_informado;

-- 3) Grão: nenhum item repetido (esperado 0)
SELECT COUNT(*) AS itens_repetidos
FROM (SELECT numero_controle_pncp, numero_item
      FROM fato_item_contratado
      GROUP BY numero_controle_pncp, numero_item
      HAVING COUNT(*) > 1) AS repetidos;

-- 4) Totais da prova real
SELECT  1 AS n, 'Contratações distintas'         AS indicador, COUNT(DISTINCT numero_controle_pncp)::TEXT AS obtido, '1.962' AS esperado FROM fato_item_contratado
UNION ALL SELECT  2, 'Volume homologado (R$)',     SUM(valor_total_homologado)::TEXT, '8.044.498.805,74' FROM fato_item_contratado
UNION ALL SELECT  3, 'Estimado, todos os itens (R$)', SUM(valor_total_estimado)::TEXT, '32.629.639.732,13' FROM fato_item_contratado
UNION ALL SELECT  4, 'Estimado comparável (R$)',   SUM(valor_total_estimado) FILTER (WHERE comparavel = 1)::TEXT, '6.867.663.469,91' FROM fato_item_contratado
UNION ALL SELECT  5, 'Itens comparáveis',          COUNT(*) FILTER (WHERE comparavel = 1)::TEXT, '5.457' FROM fato_item_contratado
UNION ALL SELECT  6, 'Economia (R$)',              SUM(economia_valor) FILTER (WHERE comparavel = 1)::TEXT, '992.861.686,95' FROM fato_item_contratado
UNION ALL SELECT  7, 'Economia (%)',
          ROUND(100 * SUM(economia_valor) FILTER (WHERE comparavel = 1)
                    / SUM(valor_total_estimado) FILTER (WHERE comparavel = 1), 2)::TEXT, '14,46' FROM fato_item_contratado
UNION ALL SELECT  8, 'Itens com sobrepreço',       COUNT(*) FILTER (WHERE comparavel = 1 AND valor_total_homologado > valor_total_estimado)::TEXT, '27' FROM fato_item_contratado
UNION ALL SELECT  9, 'Itens com ciclo',            COUNT(dias_ciclo)::TEXT, '5.896' FROM fato_item_contratado
UNION ALL SELECT 10, 'Ciclo médio (dias)',         ROUND(AVG(dias_ciclo), 1)::TEXT, '48,1' FROM fato_item_contratado
UNION ALL SELECT 11, 'Ciclo máximo (dias)',        MAX(dias_ciclo)::TEXT, '611' FROM fato_item_contratado
UNION ALL SELECT 12, 'Itens sem ciclo',            (COUNT(*) - COUNT(dias_ciclo))::TEXT, '230' FROM fato_item_contratado
ORDER BY n;

-- 5) Perfil do gasto (% do volume homologado). Esperado: Obras 60,8 | Serviços 36,6 | Bens 2,6
SELECT perfil_gasto,
       ROUND(100 * SUM(valor_total_homologado) / (SELECT SUM(valor_total_homologado) FROM fato_item_contratado), 1) AS pct_volume
FROM fato_item_contratado
GROUP BY perfil_gasto
ORDER BY pct_volume DESC;
