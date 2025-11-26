
CREATE OR ALTER PROCEDURE sp_ProcesarPagos
    @xmlData XML, 
    @FechaActual DATE
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        -- Iniciar Transacción
        BEGIN TRANSACTION;

        --Cargar pagos del día en tabla variable
        DECLARE @PagosDia TABLE (
            NumeroFinca VARCHAR(50), 
            MedioPago INT, 
            NumRef VARCHAR(100), 
            Procesado BIT DEFAULT 0
        );
        
        INSERT INTO @PagosDia (NumeroFinca, MedioPago, NumRef) 
        SELECT 
            x.value('@numeroFinca', 'VARCHAR(50)'), 
            x.value('@tipoMedioPagoId', 'INT'), 
            x.value('@numeroReferencia', 'VARCHAR(100)') 
        FROM @xmlData.nodes('/Operaciones/FechaOperacion[@fecha=sql:variable("@FechaActual")]/Pagos/Pago') AS T(x);

        
        DECLARE @NumFinca VARCHAR(50), @MedioPago INT, @NumRef VARCHAR(100); 
        DECLARE @IdFacturaVieja INT, @TotalPagar DECIMAL(18,2), @FechaVencimiento DATE, @MontoMoroso DECIMAL(18,2);

        --Procesar pago por pago
        WHILE EXISTS (SELECT 1 FROM @PagosDia WHERE Procesado = 0)
        BEGIN
            --Obtener siguiente pago
            SELECT TOP 1 
                @NumFinca = NumeroFinca, 
                @MedioPago = MedioPago, 
                @NumRef = NumRef 
            FROM @PagosDia WHERE Procesado = 0;
            
            --Buscar factura pendiente más antigua
            SELECT TOP 1 
                @IdFacturaVieja = F.Id, 
                @TotalPagar = F.TotalAPagarFinal, 
                @FechaVencimiento = F.FechaVencimiento 
            FROM Factura F 
            INNER JOIN Propiedad P ON P.Id = F.IdPropiedad 
            WHERE P.NumeroFinca = @NumFinca 
              AND F.IdEstadoFactura = 1 -- Pendiente
            ORDER BY F.FechaVencimiento ASC;

            -- Solo procesamos si existe una deuda pendiente
            IF @IdFacturaVieja IS NOT NULL
            BEGIN
                --Cálculo de Intereses Moratorios
                IF @FechaActual > @FechaVencimiento
                BEGIN
                    
                    SET @MontoMoroso = (@TotalPagar * 0.04 / 30.0) * DATEDIFF(DAY, @FechaVencimiento, @FechaActual);
                    
                    --Agregar detalle de multa
                    INSERT INTO DetalleFactura (IdFactura, IdConceptoCobro, Descripcion, Monto) 
                    VALUES (@IdFacturaVieja, 7, 'Intereses Moratorios', @MontoMoroso);
                    
                    -- Actualizar total factura
                    UPDATE Factura 
                    SET TotalAPagarFinal = TotalAPagarFinal + @MontoMoroso 
                    WHERE Id = @IdFacturaVieja;
                    
                    SET @TotalPagar = @TotalPagar + @MontoMoroso;
                END

                --Registrar el Pago
                INSERT INTO ComprobantePago (IdFactura, NumeroComprobante, IdTipoMedioPago, MontoPago, FechaPago) 
                VALUES (@IdFacturaVieja, @NumRef, @MedioPago, @TotalPagar, @FechaActual);
                
                --Marcar Factura como Pagada
                UPDATE Factura SET IdEstadoFactura = 2 WHERE Id = @IdFacturaVieja;
                
                --Actualizar Órdenes de Corta (Reconectar si aplica)
                
                UPDATE OrdenCorta 
                SET IdEstadoOrden = 2 
                WHERE IdFactura = @IdFacturaVieja AND IdEstadoOrden = 1;
            END
            
            -- Marcar pago como procesado
            UPDATE @PagosDia SET Procesado = 1 WHERE NumeroFinca = @NumFinca AND NumRef = @NumRef; 
            
            
            SET @IdFacturaVieja = NULL;
        END

        
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
            
        PRINT 'Error en sp_ProcesarPagos (Fecha ' + CONVERT(VARCHAR, @FechaActual) + '): ' + ERROR_MESSAGE();
        
    END CATCH
END;
GO