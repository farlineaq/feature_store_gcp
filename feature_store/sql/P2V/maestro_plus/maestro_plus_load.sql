    SELECT
        PluCD as PluCD,
        PluID as PluID,
        PluName as PluDesc,
        SubLineCD as SubLineaCD,
        CategoryCD	as CategoriaCD,
        SubcategoryCD as SubcategoriaCD,
        dir.DireccionCD as DireccionCD,
        CURRENT_TIMESTAMP() as feature_timestamp
    FROM `co-grupoexito-datalake-prd.comercial_data.PLU` plu
    INNER JOIN `co-grupoexito-datalake-prd.comercial_view.vwSubLinea` sublinea
        ON sublinea.SublineaCD = plu.SubLineCD
    INNER JOIN `co-grupoexito-datalake-prd.comercial_view.vwSubDireccion` direccion
        ON direccion.SubDireccionCD = sublinea.SubDireccionCD