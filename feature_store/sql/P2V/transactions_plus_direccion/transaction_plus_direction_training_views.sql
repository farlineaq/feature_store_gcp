CREATE OR REPLACE VIEW `mlops_feature_store.transactions_plus_direction_10`AS (
SELECT
    PluId
FROM `co-grupoexito-mlopsad-dev.mlops_feature_store.transactions_plus_direction`
WHERE DireccionCD IN (10)
);

CREATE OR REPLACE VIEW `mlops_feature_store.transactions_plus_direction_30_40`AS (
SELECT
    PluId
FROM `co-grupoexito-mlopsad-dev.mlops_feature_store.transactions_plus_direction`
WHERE DireccionCD IN (30,40)
);

CREATE OR REPLACE VIEW `mlops_feature_store.transactions_plus_direction_50`AS (
SELECT
    PluId
FROM `co-grupoexito-mlopsad-dev.mlops_feature_store.transactions_plus_direction`
WHERE DireccionCD IN (50)
);