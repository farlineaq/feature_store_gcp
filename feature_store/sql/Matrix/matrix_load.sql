WITH rfm_cliente_cadena AS (
  SELECT
    DISTINCT venta.PartyID
    ,CASE WHEN CadenaCD IN ('C', 'P') THEN 'C'
        WHEN CadenaCD IN ('N', 'E') THEN 'E'
        ELSE CadenaCD END Cadena
    , DATE_DIFF(CAST(CURRENT_DATE AS DATE), MAX(fecha), DAY) AS Recencia
    , COUNT(DISTINCT consecutivo) AS Frecuencia
    , CAST(SUM(UnidadesVendidas*PrecioVenta) AS NUMERIC) AS Monto
    , COUNT(DISTINCT CAST(FORMAT_TIMESTAMP('%Y%m', fecha) AS INTEGER)) AS Permanencia
  FROM `co-grupoexito-datalake-prd.VistasDesdeOtrosProyectos.vwVentaLineaConClientes` venta
  WHERE SublineaCD NOT IN (1, 2, 3, 4, 5, 6, 99, 505)
      AND CategoriaCD NOT IN (9999,99999, 9998, 0)
      AND DireccionCD IN (10, 30, 40, 50)
      AND CadenaCD IN ('E', 'C', 'A', 'S', 'N', 'P', 'M')
      AND Fecha BETWEEN DATE_SUB(CURRENT_DATE(), INTERVAL 1 MONTH) AND CURRENT_DATE()
  GROUP BY venta.PartyID, Cadena
)
, rfm_cliente AS (
  SELECT
    PartyId
    , MAX(CASE WHEN Cadena IN ('E') THEN Frecuencia ELSE 0 END) AS Frecuencia_exito
    , MAX(case when Cadena in ('C') then Frecuencia else 0 end) as frecuencia_carulla
    , MAX(CASE WHEN Cadena IN ('E') THEN Recencia END) AS Recencia_exito
    , MAX(CASE WHEN Cadena IN ('C') THEN Recencia END) AS Recencia_carulla
    , MAX(CASE WHEN Cadena IN ('E') THEN Monto ELSE 0 END) AS Monto_exito
    , MAX(CASE WHEN Cadena IN ('C') THEN Monto ELSE 0 END) AS Monto_carulla
    , MAX(CASE WHEN Cadena IN ('E') THEN Permanencia ELSE 0 END) AS Permanencia_exito
    , MAX(CASE WHEN Cadena IN ('C') THEN Permanencia ELSE 0 END) AS Permanencia_carulla
  FROM rfm_cliente_cadena
  GROUP BY PartyId
)
, monto_unidades_cliente_cadena_direccion AS (
SELECT
    DISTINCT venta.PartyID
    , CASE
        WHEN venta.CadenaCD IN ('C', 'P') THEN 'C'
        WHEN venta.CadenaCD IN ('N', 'E') THEN 'E'
        ELSE venta.CadenaCD END AS Cadena
    , venta.DireccionCD AS Negocio
    , venta.DireccionDesc
    , CAST(SUM(venta.UnidadesVendidas * venta.PrecioVenta) AS NUMERIC) AS Monto
    , SUM(venta.UnidadesVendidas) AS Unidades
    , SUM(SUM(venta.UnidadesVendidas)) OVER (PARTITION BY venta.PartyID, venta.CadenaCD) AS UnidadesTotales
    , SUM(SUM(venta.UnidadesVendidas * venta.PrecioVenta)) OVER (PARTITION BY venta.PartyID, venta.CadenaCD) AS MontoTotal
FROM `co-grupoexito-datalake-prd.VistasDesdeOtrosProyectos.vwVentaLineaConClientes` venta
WHERE venta.Fecha BETWEEN DATE_SUB(CURRENT_DATE(), INTERVAL 1 MONTH) AND CURRENT_DATE()
    AND venta.CadenaCD IN ('E', 'C', 'A', 'S', 'N', 'P', 'M')
    AND venta.SublineaCD NOT IN (1, 2, 3, 4, 5, 6, 99, 505)
    AND venta.CategoriaCD NOT IN (9999, 99999, 9998, 0)
    AND venta.DireccionCD IN (10, 30, 40, 50)
GROUP BY
    venta.PartyID,
    venta.CadenaCD,
    venta.DireccionCD,
    venta.DireccionDesc
)
, proporciones AS (
  SELECT
    PartyID
    , CONCAT(DireccionDesc, '_', Cadena) AS Direccion_Cadena
    , CASE WHEN ABS(MontoTotal) < 1e-6 THEN 0
        ELSE CAST((Monto / MontoTotal) AS NUMERIC) END AS Prop_Monto
    , CASE WHEN ABS(UnidadesTotales) < 1e-6 THEN 0
        ELSE CAST((Unidades / UnidadesTotales) AS NUMERIC) END AS Prop_Unds
  FROM monto_unidades_cliente_cadena_direccion
)
, proporciones_pivot AS (
    SELECT
      *
    FROM proporciones
    PIVOT (
        SUM(Prop_Monto) AS monto,
        SUM(Prop_Unds) AS unds
        FOR Direccion_Cadena IN (
            'ENTRETENIMIENTO_C', 'GRAN CONSUMO_C', 'TEXTIL HOGAR_C', 'FRESCOS_C',
            'ENTRETENIMIENTO_E', 'GRAN CONSUMO_E', 'TEXTIL HOGAR_E', 'FRESCOS_E',
            'ENTRETENIMIENTO_M', 'GRAN CONSUMO_M', 'TEXTIL HOGAR_M', 'FRESCOS_M',
            'ENTRETENIMIENTO_S', 'GRAN CONSUMO_S', 'TEXTIL HOGAR_S', 'FRESCOS_S',
            'ENTRETENIMIENTO_A', 'GRAN CONSUMO_A', 'TEXTIL HOGAR_A', 'FRESCOS_A'
        )
    )
)
, clientes AS (
    SELECT
        DISTINCT
        venta.PartyID,
        Fecha,
        CASE WHEN venta.CadenaCD IN ('C', 'P') THEN 'C'
            WHEN venta.CadenaCD IN ('N', 'E') THEN 'E'
            ELSE venta.CadenaCD END AS CadenaCD
    FROM `co-grupoexito-datalake-prd.VistasDesdeOtrosProyectos.vwVentaLineaConClientes` venta
    WHERE Fecha BETWEEN DATE_SUB(CURRENT_DATE(), INTERVAL 1 MONTH) AND CURRENT_DATE()
        AND venta.CadenaCD IN ('E', 'N', 'C', 'A', 'S', 'P', 'M')
    GROUP BY venta.PartyID, Fecha, CadenaCD
)
, cantidad AS (
SELECT
    COUNT(*) AS Cantidad,
    PartyID,
    CadenaCD
FROM clientes
GROUP BY PartyID, CadenaCD
)
, comp AS (
    SELECT idf.PartyID,
           canti.CadenaCD,
           canti.Cantidad,
           idf.Fecha AS fecha1,
           MIN(idf2.Fecha) AS fecha2,
           DATE_DIFF(MIN(idf2.Fecha), idf.Fecha, DAY) AS DifDay
    FROM clientes idf
    INNER JOIN cantidad as canti
    ON idf.PartyID = canti.PartyID AND idf.CadenaCD = canti.CadenaCD
    LEFT JOIN clientes idf2
    ON idf.PartyID = idf2.PartyID
       AND idf2.Fecha > idf.Fecha
    GROUP BY idf.PartyID, idf.Fecha, canti.CadenaCD, canti.Cantidad
)
, tmp as (
    SELECT
        comp.PartyID,
        comp.CadenaCD,
        PERCENTILE_CONT(CASE WHEN Cantidad = 1.0 THEN 365 ELSE DifDay END, 0.5)
        OVER (PARTITION BY comp.PartyID, comp.CadenaCD) AS MedianaRecompra
    FROM comp
    GROUP BY PartyID, CadenaCD, Cantidad, DifDay
)
, pivot_tmp AS (
    SELECT
        *
    FROM tmp
    PIVOT (SUM(MedianaRecompra) FOR CadenaCD IN ('E' AS Exito, 'C' as Carulla))
)
, matrix AS (
    SELECT
        CAST(rfm_cliente.PartyID as STRING)
        , frecuencia_exito
        , frecuencia_carulla
        , Recencia_exito
        , Recencia_carulla
        , Monto_exito
        , Monto_carulla
        , Permanencia_exito
        , Permanencia_carulla
        , IFNULL(proporciones_pivot.`monto_GRAN CONSUMO_E`, 0) AS desembolso_pgc_exito
        , IFNULL(proporciones_pivot.`unds_GRAN CONSUMO_E`, 0) AS unidades_pgc_exito
        , IFNULL(proporciones_pivot.`unds_FRESCOS_E`, 0) AS unidades_frescos_exito
        , IFNULL(proporciones_pivot.`monto_FRESCOS_E`, 0) AS desembolso_frescos_exito
        , IFNULL(proporciones_pivot.`unds_TEXTIL HOGAR_E`, 0) AS unidades_textil_exito
        , IFNULL(proporciones_pivot.`monto_TEXTIL HOGAR_E`, 0) AS desembolso_textil_exito
        , IFNULL(proporciones_pivot.`unds_ENTRETENIMIENTO_E`, 0) AS unidades_electro_exito
        , IFNULL(proporciones_pivot.`monto_ENTRETENIMIENTO_E`, 0) AS desembolso_electro_exito
        , IFNULL(proporciones_pivot.`monto_GRAN CONSUMO_C`, 0) AS desembolso_pgc_carulla
        , IFNULL(proporciones_pivot.`unds_GRAN CONSUMO_C`, 0) AS unidades_pgc_carulla
        , IFNULL(proporciones_pivot.`unds_FRESCOS_C`, 0) AS unidades_frescos_carulla
        , IFNULL(proporciones_pivot.`monto_FRESCOS_C`, 0) AS desembolso_frescos_carulla
        , pivot_tmp.Exito as mediana_recompra_exito
        , pivot_tmp.Carulla as mediana_recompra_carulla
        , CURRENT_TIMESTAMP() as feature_timestamp
    FROM rfm_cliente
    INNER JOIN proporciones_pivot
    ON rfm_cliente.PartyID = proporciones_pivot.PartyID
    INNER JOIN pivot_tmp
    ON rfm_cliente.PartyID = pivot_tmp.PartyID
)
SELECT
    *
FROM matrix