CREATE OR ALTER PROCEDURE sp_ConsultarFacturasPortal
    @TerminoBusqueda NVARCHAR(120) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    --Limpieza de parámetro
    IF @TerminoBusqueda IS NOT NULL
    BEGIN
        SET @TerminoBusqueda = LTRIM(RTRIM(@TerminoBusqueda));
        IF @TerminoBusqueda = '' SET @TerminoBusqueda = NULL;
    END

    IF @TerminoBusqueda IS NULL RETURN;

    DECLARE @FiltroLike NVARCHAR(122) = '%' + @TerminoBusqueda + '%';

    --Consulta
    SELECT DISTINCT
        F.Id AS IdFactura,
        P.NumeroFinca,
        F.NumeroFactura,
        F.FechaEmision,
        F.FechaVencimiento,
        F.IdEstadoFactura,
        
        CASE 
            WHEN F.IdEstadoFactura = 1 AND GETDATE() > F.FechaVencimiento 
            THEN DATEDIFF(DAY, F.FechaVencimiento, GETDATE())
            ELSE 0
        END AS DiasAtraso,

        F.TotalAPagarFinal AS MontoTotal,
        EF.Nombre AS Estado,
        
        CASE 
            WHEN F.IdEstadoFactura = 1 THEN 'Pendiente de Pago'
            WHEN F.IdEstadoFactura = 2 THEN 'Pagada el ' + ISNULL(CONVERT(VARCHAR, CP.FechaPago), 'N/A')
            ELSE EF.Nombre
        END AS DetalleEstado

    FROM Factura F
    INNER JOIN EstadoFactura EF ON F.IdEstadoFactura = EF.Id
    INNER JOIN Propiedad P ON F.IdPropiedad = P.Id
    LEFT JOIN ComprobantePago CP ON CP.IdFactura = F.Id
    LEFT JOIN Propietario PRO ON PRO.IdPropiedad = P.Id
    LEFT JOIN Persona PER ON PER.Id = PRO.IdPersona

    WHERE 
        (
            P.NumeroFinca LIKE @FiltroLike
            OR
            PER.ValorDocumentoIdentidad LIKE @FiltroLike
        )

    ORDER BY 
        F.IdEstadoFactura ASC, 
        F.FechaVencimiento ASC;
END;
GO
