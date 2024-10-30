WITH ventas AS (
  SELECT
    DireccionCD,
    CategoriaCD,
    PluCd AS PluId,
    SUM(UnidadesVendidas) AS cantidad,
    COUNT(consecutivo) AS frecuencia
  FROM `co-grupoexito-datalake-prd.VistasDesdeOtrosProyectos.vwVentaLineaConClientes`
      WHERE SublineaCD NOT IN (1,2,3,4,5,6,99,505,91)
      AND CategoriaCD NOT IN (9999,99999,9998,0,8628,3835,8622)
      AND DireccionCD IN (40,10,50,30)
      AND CadenaCD IN ('E','N')
      AND Fecha BETWEEN DATE_SUB(CURRENT_DATE(), INTERVAL 6 MONTH) AND CURRENT_DATE()
      AND TarjetaCliente > 0
      AND PartyId is not null
      group by DireccionCD,CategoriaCD,PluCd
),
max_frecuencia AS (
  SELECT
    DireccionCD,
    CategoriaCD,
    MAX(frecuencia) AS max_cat
  FROM ventas
  GROUP BY DireccionCD, CategoriaCD
),
ranking_relevancia AS (
  SELECT
    v.DireccionCD,
    v.CategoriaCD,
    v.PluId,
    v.cantidad,
    v.frecuencia,
    (v.cantidad * v.frecuencia) / (mf.max_cat * 100) AS relacion_cat,
    RANK() OVER (PARTITION BY v.DireccionCD, v.CategoriaCD ORDER BY (v.cantidad * v.frecuencia) / (mf.max_cat * 100) DESC) AS rank_categoria
  FROM ventas v
  JOIN max_frecuencia mf
    ON v.DireccionCD = mf.DireccionCD AND v.CategoriaCD = mf.CategoriaCD
)
SELECT
    *
    , CURRENT_TIMESTAMP() as feature_timestamp
FROM(
    SELECT
      CAST(DireccionCD AS STRING) AS DireccionCD,
      CAST(CategoriaCD AS STRING) AS CategoriaCD,
      PluId,
      relacion_cat as RelacionCategoria,
      rank_categoria,
    FROM ranking_relevancia
    WHERE rank_categoria <= 5)
PIVOT (
  MAX(PluId) as PluId
  , MAX(RelacionCategoria) as RelacionCategoria
  FOR rank_categoria IN (1,2,3,4,5)
)