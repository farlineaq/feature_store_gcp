SELECT
    DISTINCT consecutivo as TransactionID,
    CAST(PluId as STRING),
    DireccionCD
FROM `co-grupoexito-datalake-prd.VistasDesdeOtrosProyectos.vwVentaLineaConClientes`
WHERE SublineaCD NOT IN (1,2,3,4,5,6,99,505,91)
    AND CategoriaCD NOT IN (9999,99999,9998,0,8628,3835,8622)
    AND DireccionCD IN (10,30,40,50)
    AND CadenaCD IN ('E','N')
    AND Fecha BETWEEN DATE_SUB(CURRENT_DATE(), INTERVAL 6 MONTH) AND CURRENT_DATE()
    AND TarjetaCliente > 0
    AND PartyId is not null