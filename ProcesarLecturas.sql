
CREATE OR ALTER PROCEDURE sp_ProcesarLecturas
    @xmlData XML, 
    @FechaActual DATE
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        
        BEGIN TRANSACTION;

        --Insertar movimientos en el historial
        INSERT INTO MovimientoLecturaMedidor (IdPropiedad, NumeroMedidor, IdTipoMovimiento, Monto, SaldoAnterior, SaldoNuevo, FechaMovimiento)
        SELECT 
            P.Id, 
            x.value('@numeroMedidor', 'VARCHAR(50)'), 
            x.value('@tipoMovimientoId', 'INT'),
            -- Calculo del Monto (Consumo o Ajuste)
            CASE 
                WHEN x.value('@tipoMovimientoId', 'INT') = 1 THEN (x.value('@valor', 'DECIMAL(10,2)') - P.SaldoM3) -- Lectura
                ELSE x.value('@valor', 'DECIMAL(10,2)') -- Ajuste
            END,
            P.SaldoM3, -- Saldo Anterior
            -- Calculo del Nuevo Saldo
            CASE 
                WHEN x.value('@tipoMovimientoId', 'INT') = 1 THEN x.value('@valor', 'DECIMAL(10,2)') 
                WHEN x.value('@tipoMovimientoId', 'INT') = 2 THEN P.SaldoM3 - x.value('@valor', 'DECIMAL(10,2)') 
                WHEN x.value('@tipoMovimientoId', 'INT') = 3 THEN P.SaldoM3 + x.value('@valor', 'DECIMAL(10,2)') 
            END,
            @FechaActual
        FROM @xmlData.nodes('/Operaciones/FechaOperacion[@fecha=sql:variable("@FechaActual")]/LecturasMedidor/Lectura') AS T(x)
        INNER JOIN Propiedad P ON P.NumeroMedidor = x.value('@numeroMedidor', 'VARCHAR(50)');

        --Actualizar Saldo
        
        UPDATE P 
        SET P.SaldoM3 = MLM.SaldoNuevo 
        FROM Propiedad P 
        INNER JOIN MovimientoLecturaMedidor MLM ON MLM.IdPropiedad = P.Id 
        WHERE MLM.FechaMovimiento = @FechaActual;

        
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
            
        PRINT 'Error en sp_ProcesarLecturas (Fecha ' + CONVERT(VARCHAR, @FechaActual) + '): ' + ERROR_MESSAGE();
        
    END CATCH
END;
GO