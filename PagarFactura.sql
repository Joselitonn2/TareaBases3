CREATE OR ALTER PROCEDURE sp_PagarFacturaPortal
    @NumeroFinca VARCHAR(50),
    @TipoMedioPago INT,
    @OutResult INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET @OutResult = 0;

    DECLARE @IdFacturaVieja INT;
    DECLARE @TotalPagar DECIMAL(18,2);
    DECLARE @FechaVencimiento DATE;
    DECLARE @MontoMoroso DECIMAL(18,2);
    DECLARE @IdCCMoratorio INT = 7; 
    DECLARE @FechaActual DATE = GETDATE();
    DECLARE @NumComprobante VARCHAR(50);

    BEGIN TRY
        BEGIN TRANSACTION;

        --Buscar factura
        SELECT TOP 1 
            @IdFacturaVieja = F.Id, 
            @TotalPagar = F.TotalAPagarFinal, 
            @FechaVencimiento = F.FechaVencimiento
        FROM Factura F
        INNER JOIN Propiedad P ON P.Id = F.IdPropiedad
        WHERE P.NumeroFinca = @NumeroFinca AND F.IdEstadoFactura = 1
        ORDER BY F.FechaVencimiento ASC;

        
        IF @IdFacturaVieja IS NULL
        BEGIN
            ROLLBACK TRANSACTION;
            SET @OutResult = 50001;
            
            
            SELECT @OutResult AS ResultCode; 
            
            RETURN;
        END

        --Calcular Intereses
        IF @FechaActual > @FechaVencimiento
        BEGIN
            DECLARE @DiasAtraso INT = DATEDIFF(DAY, @FechaVencimiento, @FechaActual);
            SET @MontoMoroso = (@TotalPagar * 0.04 / 30.0) * @DiasAtraso;

            INSERT INTO DetalleFactura (IdFactura, IdConceptoCobro, Descripcion, Monto)
            VALUES (@IdFacturaVieja, @IdCCMoratorio, 'Intereses Moratorios (Portal)', @MontoMoroso);

            UPDATE Factura SET TotalAPagarFinal = TotalAPagarFinal + @MontoMoroso WHERE Id = @IdFacturaVieja;
            SET @TotalPagar = @TotalPagar + @MontoMoroso;
        END

        --Pagar
        SET @NumComprobante = CONCAT('WEB-', FORMAT(@FechaActual, 'yyyyMMdd'), '-', RIGHT(CAST(NEWID() AS VARCHAR(36)), 8));

        INSERT INTO ComprobantePago (IdFactura, NumeroComprobante, IdTipoMedioPago, MontoPago, FechaPago)
        VALUES (@IdFacturaVieja, @NumComprobante, @TipoMedioPago, @TotalPagar, @FechaActual);

        UPDATE Factura SET IdEstadoFactura = 2 WHERE Id = @IdFacturaVieja;
        UPDATE OrdenCorta SET IdEstadoOrden = 2 WHERE IdFactura = @IdFacturaVieja AND IdEstadoOrden = 1;

        COMMIT TRANSACTION;
        
        --ÉXITO
        SELECT @OutResult AS ResultCode; 
        RETURN; 
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        
        SET @OutResult = 50005; 
        PRINT 'Error procesando pago: ' + ERROR_MESSAGE();
        
        SELECT @OutResult AS ResultCode; 
        RETURN; 
    END CATCH
END;
GO
