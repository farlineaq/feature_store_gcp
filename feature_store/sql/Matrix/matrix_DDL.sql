CREATE TABLE `mlops_feature_store.matrix_feature_group` (
    PartyID STRING
    , frecuencia_exito FLOAT64
    , frecuencia_carulla FLOAT64
    , Recencia_exito INT64
    , Recencia_carulla INT64
    , Monto_exito FLOAT64
    , Monto_carulla FLOAT64
    , Permanencia_exito INT64
    , Permanencia_carulla INT64
    , desembolso_pgc_exito FLOAT64
    , unidades_pgc_exito FLOAT64
    , unidades_frescos_exito FLOAT64
    , desembolso_frescos_exito FLOAT64
    , unidades_textil_exito FLOAT64
    , desembolso_textil_exito FLOAT64
    , unidades_electro_exito FLOAT64
    , desembolso_electro_exito FLOAT64
    , desembolso_pgc_carulla FLOAT64
    , unidades_pgc_carulla FLOAT64
    , unidades_frescos_carulla FLOAT64
    , desembolso_frescos_carulla FLOAT64
    , mediana_recompra_exito FLOAT64
    , mediana_recompra_carulla FLOAT64
    , feature_timestamp TIMESTAMP
)