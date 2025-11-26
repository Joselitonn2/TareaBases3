
CREATE OR ALTER PROCEDURE sp_ProcesarSimulacionCompleta
    @xmlData XML
AS
BEGIN
    SET NOCOUNT ON;

    --Tabla de control de fechas
    DECLARE @FechasOperacion TABLE (Fecha DATE, Procesado BIT DEFAULT 0);
    
    --Insertar fechas ordenadas
    INSERT INTO @FechasOperacion (Fecha)
    SELECT DISTINCT x.value('@fecha', 'DATE')
    FROM @xmlData.nodes('/Operaciones/FechaOperacion') AS T(x);

    DECLARE @FechaActual DATE;
    
    --Bucle
    WHILE EXISTS (SELECT 1 FROM @FechasOperacion WHERE Procesado = 0)
    BEGIN
        --Obtener la fecha más antigua pendiente
        SELECT TOP 1 @FechaActual = Fecha 
        FROM @FechasOperacion 
        WHERE Procesado = 0 
        ORDER BY Fecha ASC;

        PRINT '>>> Procesando Fecha: ' + CONVERT(VARCHAR, @FechaActual);
        
        BEGIN TRY
            BEGIN TRANSACTION;
            
            --Insertar Personas
            INSERT INTO Persona (Nombre, ValorDocumentoIdentidad, Email, Telefono1)
            SELECT x.value('@nombre', 'VARCHAR(100)'), x.value('@valorDocumento', 'VARCHAR(50)'), x.value('@email', 'VARCHAR(100)'), x.value('@telefono', 'VARCHAR(20)')
            FROM @xmlData.nodes('/Operaciones/FechaOperacion[@fecha=sql:variable("@FechaActual")]/Personas/Persona') AS T(x) 
            WHERE NOT EXISTS (SELECT 1 FROM Persona WHERE ValorDocumentoIdentidad = x.value('@valorDocumento', 'VARCHAR(50)'));
            
            --Insertar Propiedades
            INSERT INTO Propiedad (NumeroFinca, NumeroMedidor, MetrosCuadrados, IdTipoUsoPropiedad, IdTipoZonaPropiedad, ValorFiscal, FechaRegistro)
            SELECT x.value('@numeroFinca', 'VARCHAR(50)'), x.value('@numeroMedidor', 'VARCHAR(50)'), x.value('@metrosCuadrados', 'DECIMAL(10,2)'), x.value('@tipoUsoId', 'INT'), x.value('@tipoZonaId', 'INT'), x.value('@valorFiscal', 'DECIMAL(18,2)'), x.value('@fechaRegistro', 'DATE')
            FROM @xmlData.nodes('/Operaciones/FechaOperacion[@fecha=sql:variable("@FechaActual")]/Propiedades/Propiedad') AS T(x) 
            WHERE NOT EXISTS (SELECT 1 FROM Propiedad WHERE NumeroFinca = x.value('@numeroFinca', 'VARCHAR(50)'));

            --Asignar CC
            EXEC sp_AsignarCC_Propiedad @FechaActual;

            --Gestión Propiedad-Persona
            EXEC sp_ProcesarRelacionPropiedadPersona @xmlData, @FechaActual;

            --Gestión CC-Propiedad Manuales
            EXEC sp_ProcesarRelacionCCPropiedad @xmlData, @FechaActual;

            --Cambios Valor Fiscal
            UPDATE P SET ValorFiscal = x.value('@nuevoValor', 'DECIMAL(18,2)') 
            FROM Propiedad P CROSS APPLY @xmlData.nodes('/Operaciones/FechaOperacion[@fecha=sql:variable("@FechaActual")]/PropiedadCambio/Cambio') AS T(x) 
            WHERE P.NumeroFinca = x.value('@numeroFinca', 'VARCHAR(50)');

            --Ejecutar Operaciones Diarias (Lecturas, Pagos, Cierre)
            EXEC sp_ProcesarLecturas @xmlData, @FechaActual;
            EXEC sp_ProcesarPagos @xmlData, @FechaActual;
            EXEC sp_ProcesosMasivosDiarios @FechaActual;

            --Marcar fecha como procesada
            UPDATE @FechasOperacion SET Procesado = 1 WHERE Fecha = @FechaActual;
            
            COMMIT TRANSACTION;
        END TRY
        BEGIN CATCH
            ROLLBACK TRANSACTION;
            PRINT 'Error en fecha: ' + CONVERT(VARCHAR, @FechaActual) + ' - ' + ERROR_MESSAGE();
            BREAK;
        END CATCH
    END
    PRINT '>>> Simulación Finalizada Correctamente.';
END;
GO