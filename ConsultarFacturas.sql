CREATE OR ALTER PROCEDURE sp_ConsultarFacturasPortal
    @NumeroFinca VARCHAR(50) = NULL,
    @ValorDocumentoIdentidad VARCHAR(50) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @ResultCode INT = 0;

    BEGIN TRY
        BEGIN TRANSACTION;

        --Validación
        IF @NumeroFinca IS NULL AND @ValorDocumentoIdentidad IS NULL
        BEGIN
            PRINT 'Error: Debe proporcionar al menos un parámetro.';
            ROLLBACK TRANSACTION;
            RETURN -1;
        END

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
            (@NumeroFinca IS NOT NULL AND P.NumeroFinca = @NumeroFinca)
            OR
            (@ValorDocumentoIdentidad IS NOT NULL AND PER.ValorDocumentoIdentidad = @ValorDocumentoIdentidad)

        ORDER BY 
            F.IdEstadoFactura ASC, 
            F.FechaVencimiento ASC;

        --Verificación
        IF @@ROWCOUNT = 0
        BEGIN
            SET @ResultCode = 50001;--No encontrado
            PRINT 'Aviso: No se encontraron registros.';
        END
        ELSE
        BEGIN
            SET @ResultCode = 0; -- Éxito
        END

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        PRINT 'Error Interno: ' + ERROR_MESSAGE();
        RETURN -500;
    END CATCH

    RETURN @ResultCode;
END;
GO