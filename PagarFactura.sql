CREATE OR ALTER PROCEDURE sp_PagarFacturaPortal
    @NumeroFinca VARCHAR(50),
    @TipoMedioPago INT -- 1: Efectivo, 2: Tarjeta
AS
BEGIN
    SET NOCOUNT ON;
    
    --Variables
    DECLARE @IdFacturaVieja INT;
    DECLARE @TotalPagar DECIMAL(18,2);
    DECLARE @FechaVencimiento DATE;
    DECLARE @MontoMoroso DECIMAL(18,2);
    DECLARE @IdCCMoratorio INT = 7; 
    DECLARE @FechaActual DATE = GETDATE();
    
    -- Variable para el comprobante
    DECLARE @NumComprobante VARCHAR(50);

    BEGIN TRY
        BEGIN TRANSACTION;

        --Buscar la factura pendiente más vieja
        SELECT TOP 1 
            @IdFacturaVieja = F.Id, 
            @TotalPagar = F.TotalAPagarFinal, 
            @FechaVencimiento = F.FechaVencimiento
        FROM Factura F
        INNER JOIN Propiedad P ON P.Id = F.IdPropiedad
        WHERE P.NumeroFinca = @NumeroFinca 
          AND F.IdEstadoFactura = 1 -- Pendiente
        ORDER BY F.FechaVencimiento ASC;

        IF @IdFacturaVieja IS NULL
        BEGIN
            ROLLBACK TRANSACTION;
            PRINT 'La propiedad no tiene facturas pendientes.';
            RETURN 1; 
        END

        --Calcular Intereses Moratorios
        IF @FechaActual > @FechaVencimiento
        BEGIN
            DECLARE @DiasAtraso INT = DATEDIFF(DAY, @FechaVencimiento, @FechaActual);
            SET @MontoMoroso = (@TotalPagar * 0.04 / 30.0) * @DiasAtraso;

            INSERT INTO DetalleFactura (IdFactura, IdConceptoCobro, Descripcion, Monto)
            VALUES (@IdFacturaVieja, @IdCCMoratorio, 'Intereses Moratorios (Portal)', @MontoMoroso);

            UPDATE Factura 
            SET TotalAPagarFinal = TotalAPagarFinal + @MontoMoroso 
            WHERE Id = @IdFacturaVieja;
            
            SET @TotalPagar = @TotalPagar + @MontoMoroso;
        END

        --Registrar el Pago
        SET @NumComprobante = CONCAT('WEB-', FORMAT(@FechaActual, 'yyyyMMdd'), '-', RIGHT(CAST(NEWID() AS VARCHAR(36)), 8));

        INSERT INTO ComprobantePago (IdFactura, NumeroComprobante, IdTipoMedioPago, MontoPago, FechaPago)
        VALUES (@IdFacturaVieja, @NumComprobante, @TipoMedioPago, @TotalPagar, @FechaActual);

        --Actualizar Estado Factura
        UPDATE Factura SET IdEstadoFactura = 2 WHERE Id = @IdFacturaVieja;

        --Reconexión Automática
        UPDATE OrdenCorta 
        SET IdEstadoOrden = 2 
        WHERE IdFactura = @IdFacturaVieja AND IdEstadoOrden = 1;

        COMMIT TRANSACTION;
        
        
        PRINT 'Pago realizado con éxito. Comprobante: ' + @NumComprobante;
        RETURN 0;

    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        PRINT 'Error procesando pago: ' + ERROR_MESSAGE();
        RETURN -500;
    END CATCH
END;
GO