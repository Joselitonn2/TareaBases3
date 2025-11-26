
CREATE OR ALTER PROCEDURE sp_ProcesosMasivosDiarios
    @FechaActual DATE
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        
        BEGIN TRANSACTION;

        --Leer Parámetros del Sistema
        DECLARE @DiasVencimiento INT, @DiasGracia INT;
        SELECT @DiasVencimiento = Valor FROM ParametrosSistema WHERE Nombre = 'DiasVencimientoFactura';
        SELECT @DiasGracia = Valor FROM ParametrosSistema WHERE Nombre = 'DiasGraciaCorta';
        
        
        SET @DiasVencimiento = ISNULL(@DiasVencimiento, 15);
        SET @DiasGracia = ISNULL(@DiasGracia, 10);

        --Identificar propiedades que cumplen mes hoy
        DECLARE @PropsFacturar TABLE (
            Id INT, 
            SaldoAgua DECIMAL(10,2), 
            UltimoSaldo DECIMAL(10,2), 
            ValorFiscal DECIMAL(18,2), 
            Metros DECIMAL(10,2)
        );
        
        INSERT INTO @PropsFacturar 
        SELECT Id, SaldoM3, SaldoM3UltimaFactura, ValorFiscal, MetrosCuadrados 
        FROM Propiedad 
        WHERE DAY(FechaRegistro) = DAY(@FechaActual);

        --Si hay propiedades, procedemos a facturar
        IF EXISTS (SELECT 1 FROM @PropsFacturar)
        BEGIN
            --Generar Encabezados de Factura
            INSERT INTO Factura (NumeroFactura, IdPropiedad, FechaEmision, FechaVencimiento, FechaLimiteCorta, TotalAPagarOriginal, TotalAPagarFinal, IdEstadoFactura)
            SELECT 
                CONCAT('FAC-', P.Id, '-', FORMAT(@FechaActual, 'yyyyMMdd')), 
                P.Id, 
                @FechaActual, 
                DATEADD(DAY, @DiasVencimiento, @FechaActual), 
                DATEADD(DAY, (@DiasVencimiento + @DiasGracia), @FechaActual), 
                0, 0, 1 -- Estado Pendiente
            FROM @PropsFacturar P;

            --Detalle Agua
            INSERT INTO DetalleFactura (IdFactura, IdConceptoCobro, Descripcion, Monto)
            SELECT F.Id, 1, 'Consumo Agua', 
                   CASE WHEN (P.SaldoAgua - P.UltimoSaldo) <= CC.ValorMinimoM3 THEN CC.ValorMinimo 
                        ELSE CC.ValorMinimo + ((P.SaldoAgua - P.UltimoSaldo - CC.ValorMinimoM3) * CC.ValorFijoM3Adicional) END
            FROM Factura F 
            JOIN @PropsFacturar P ON P.Id = F.IdPropiedad 
            JOIN ConceptoCobroPropiedad CCP ON CCP.IdPropiedad = P.Id AND CCP.IdConceptoCobro = 1 
            JOIN ConceptoCobro CC ON CC.Id = 1
            WHERE F.FechaEmision = @FechaActual AND CCP.Activo = 1;

            --Detalle Impuesto Propiedad
            INSERT INTO DetalleFactura (IdFactura, IdConceptoCobro, Descripcion, Monto)
            SELECT F.Id, 3, 'Impuesto Propiedad', (P.ValorFiscal * CC.ValorPorcentual / 12.0)
            FROM Factura F 
            JOIN @PropsFacturar P ON P.Id = F.IdPropiedad 
            JOIN ConceptoCobroPropiedad CCP ON CCP.IdPropiedad = P.Id AND CCP.IdConceptoCobro = 3 
            JOIN ConceptoCobro CC ON CC.Id = 3
            WHERE F.FechaEmision = @FechaActual AND CCP.Activo = 1;

            --Detalle Basura
            INSERT INTO DetalleFactura (IdFactura, IdConceptoCobro, Descripcion, Monto)
            SELECT F.Id, 4, 'Recoleccion Basura', 
                   CASE WHEN P.Metros <= CC.ValorM2Minimo THEN CC.ValorMinimo 
                        ELSE CC.ValorMinimo + (FLOOR((P.Metros - CC.ValorM2Minimo)/200.0) * CC.ValorTractosM2) END
            FROM Factura F 
            JOIN @PropsFacturar P ON P.Id = F.IdPropiedad 
            JOIN ConceptoCobroPropiedad CCP ON CCP.IdPropiedad = P.Id AND CCP.IdConceptoCobro = 4 
            JOIN ConceptoCobro CC ON CC.Id = 4
            WHERE F.FechaEmision = @FechaActual AND CCP.Activo = 1;

            --Detalle Parques
            INSERT INTO DetalleFactura (IdFactura, IdConceptoCobro, Descripcion, Monto)
            SELECT F.Id, 5, 'Mantenimiento Parques', CC.ValorFijo
            FROM Factura F 
            JOIN @PropsFacturar P ON P.Id = F.IdPropiedad 
            JOIN ConceptoCobroPropiedad CCP ON CCP.IdPropiedad = P.Id AND CCP.IdConceptoCobro = 5 
            JOIN ConceptoCobro CC ON CC.Id = 5
            WHERE F.FechaEmision = @FechaActual AND CCP.Activo = 1;

            --Detalle Patente Comercial
            
            INSERT INTO DetalleFactura (IdFactura, IdConceptoCobro, Descripcion, Monto)
            SELECT F.Id, 2, 'Patente Comercial', (CC.ValorFijo / PM.QMeses)
            FROM Factura F 
            JOIN @PropsFacturar P ON P.Id = F.IdPropiedad 
            JOIN ConceptoCobroPropiedad CCP ON CCP.IdPropiedad = P.Id AND CCP.IdConceptoCobro = 2 
            JOIN ConceptoCobro CC ON CC.Id = 2
            JOIN PeriodoMontoCC PM ON PM.Id = CC.IdPeriodoMontoCC
            WHERE F.FechaEmision = @FechaActual AND CCP.Activo = 1;

            --Actualizar Totales
            UPDATE F 
            SET TotalAPagarOriginal = D.Total, TotalAPagarFinal = D.Total 
            FROM Factura F 
            INNER JOIN (
                SELECT IdFactura, SUM(Monto) as Total 
                FROM DetalleFactura 
                GROUP BY IdFactura
            ) D ON D.IdFactura = F.Id 
            WHERE F.FechaEmision = @FechaActual;

            --Actualizar Saldo Histórico en Propiedad
            UPDATE P 
            SET SaldoM3UltimaFactura = SaldoM3 
            FROM Propiedad P 
            JOIN @PropsFacturar PF ON PF.Id = P.Id;
        END

        --Generar Cortas
        INSERT INTO OrdenCorta (IdPropiedad, IdFactura, FechaOrden, IdEstadoOrden)
        SELECT F.IdPropiedad, F.Id, @FechaActual, 1 -- Estado 1: Pendiente
        FROM Factura F 
        WHERE F.FechaLimiteCorta <= @FechaActual 
          AND F.IdEstadoFactura = 1 -- No pagada
          -- Que no tenga orden ya
          AND NOT EXISTS (SELECT 1 FROM OrdenCorta WHERE IdFactura = F.Id)
          -- Que tenga servicio de agua activo
          AND EXISTS (SELECT 1 FROM ConceptoCobroPropiedad WHERE IdPropiedad = F.IdPropiedad AND IdConceptoCobro = 1 AND Activo = 1);

        --Generar Reconexiones
        INSERT INTO OrdenReconexion (IdOrdenCorta, IdPropiedad, IdFactura, FechaOrden)
        SELECT Id, IdPropiedad, IdFactura, @FechaActual 
        FROM OrdenCorta 
        WHERE IdEstadoOrden = 2 -- Estado 2: Pagada/Lista para reconectar
          AND NOT EXISTS (SELECT 1 FROM OrdenReconexion WHERE IdOrdenCorta = OrdenCorta.Id);

        -- Confirmar cambios del cierre diario
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        -- Si algo falla en el proceso masivo, se revierte todo el día
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
            
        PRINT 'Error en sp_ProcesosMasivosDiarios (Fecha ' + CONVERT(VARCHAR, @FechaActual) + '): ' + ERROR_MESSAGE();
        
    END CATCH
END;
GO