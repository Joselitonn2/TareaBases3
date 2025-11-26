CREATE OR ALTER PROCEDURE sp_CargarCatalogos
    @xmlData XML
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @TieneIdentityFactura BIT = 0;
    DECLARE @TieneIdentityCorta BIT = 0;

    BEGIN TRY
        BEGIN TRANSACTION;
        
        --Tablas Diccionario
        INSERT INTO TipoMovimientoLecturaMedidor (Id, Nombre) SELECT x.value('@id', 'INT'), x.value('@nombre', 'NVARCHAR(64)') FROM @xmlData.nodes('/Catalogos/TipoMovimientoLecturaMedidor/TipoMov') AS T(x) WHERE NOT EXISTS (SELECT 1 FROM TipoMovimientoLecturaMedidor WHERE Id = x.value('@id', 'INT'));
        INSERT INTO TipoUsoPropiedad (Id, Nombre) SELECT x.value('@id', 'INT'), x.value('@nombre', 'NVARCHAR(64)') FROM @xmlData.nodes('/Catalogos/TipoUsoPropiedad/TipoUso') AS T(x) WHERE NOT EXISTS (SELECT 1 FROM TipoUsoPropiedad WHERE Id = x.value('@id', 'INT'));
        INSERT INTO TipoZonaPropiedad (Id, Nombre) SELECT x.value('@id', 'INT'), x.value('@nombre', 'NVARCHAR(64)') FROM @xmlData.nodes('/Catalogos/TipoZonaPropiedad/TipoZona') AS T(x) WHERE NOT EXISTS (SELECT 1 FROM TipoZonaPropiedad WHERE Id = x.value('@id', 'INT'));
        INSERT INTO TipoAsociacion (Id, Nombre) SELECT x.value('@id', 'INT'), x.value('@nombre', 'NVARCHAR(64)') FROM @xmlData.nodes('/Catalogos/TipoAsociacion/TipoAso') AS T(x) WHERE NOT EXISTS (SELECT 1 FROM TipoAsociacion WHERE Id = x.value('@id', 'INT'));
        INSERT INTO TipoMedioPago (Id, Nombre) SELECT x.value('@id', 'INT'), x.value('@nombre', 'NVARCHAR(64)') FROM @xmlData.nodes('/Catalogos/TipoMedioPago/MedioPago') AS T(x) WHERE NOT EXISTS (SELECT 1 FROM TipoMedioPago WHERE Id = x.value('@id', 'INT'));
        INSERT INTO TipoMontoCC (Id, Nombre) SELECT x.value('@id', 'INT'), x.value('@nombre', 'NVARCHAR(64)') FROM @xmlData.nodes('/Catalogos/TipoMontoCC/TipoMonto') AS T(x) WHERE NOT EXISTS (SELECT 1 FROM TipoMontoCC WHERE Id = x.value('@id', 'INT'));
        INSERT INTO PeriodoMontoCC (Id, Nombre, QMeses) SELECT x.value('@id', 'INT'), x.value('@nombre', 'NVARCHAR(64)'), x.value('@qMeses', 'INT') FROM @xmlData.nodes('/Catalogos/PeriodoMontoCC/PeriodoMonto') AS T(x) WHERE NOT EXISTS (SELECT 1 FROM PeriodoMontoCC WHERE Id = x.value('@id', 'INT'));

        --Tipos de Usuario
        IF NOT EXISTS (SELECT 1 FROM TipoUsuario WHERE Id = 1) INSERT INTO TipoUsuario(Id, Nombre) VALUES (1, 'Administrador');
        IF NOT EXISTS (SELECT 1 FROM TipoUsuario WHERE Id = 2) INSERT INTO TipoUsuario(Id, Nombre) VALUES (2, 'Propietario');

        
        
        -- Estados de Factura
        IF NOT EXISTS (SELECT 1 FROM EstadoFactura WHERE Id = 1)
        BEGIN
            
            IF OBJECTPROPERTY(OBJECT_ID('EstadoFactura'), 'TableHasIdentity') = 1
            BEGIN
                SET IDENTITY_INSERT EstadoFactura ON;
                SET @TieneIdentityFactura = 1;
            END
            
            INSERT INTO EstadoFactura (Id, Nombre) VALUES (1, 'Pendiente');
            INSERT INTO EstadoFactura (Id, Nombre) VALUES (2, 'Pagada');
            INSERT INTO EstadoFactura (Id, Nombre) VALUES (3, 'ArregloPago');
            INSERT INTO EstadoFactura (Id, Nombre) VALUES (4, 'Anulada');
            
            IF @TieneIdentityFactura = 1 SET IDENTITY_INSERT EstadoFactura OFF;
        END

        -- Estados de Orden de Corta
        IF NOT EXISTS (SELECT 1 FROM EstadoOrdenCorta WHERE Id = 1)
        BEGIN
            IF OBJECTPROPERTY(OBJECT_ID('EstadoOrdenCorta'), 'TableHasIdentity') = 1
            BEGIN
                SET IDENTITY_INSERT EstadoOrdenCorta ON;
                SET @TieneIdentityCorta = 1;
            END

            INSERT INTO EstadoOrdenCorta (Id, Nombre) VALUES (1, 'Pendiente');
            INSERT INTO EstadoOrdenCorta (Id, Nombre) VALUES (2, 'Pagada/Reconectar');
            INSERT INTO EstadoOrdenCorta (Id, Nombre) VALUES (3, 'Procesada');

            IF @TieneIdentityCorta = 1 SET IDENTITY_INSERT EstadoOrdenCorta OFF;
        END
        

        --Parámetros del Sistema
        DECLARE @DiasVenc INT = @xmlData.value('(/Catalogos/ParametrosSistema/DiasVencimientoFactura)[1]', 'INT');
        DECLARE @DiasGra INT = @xmlData.value('(/Catalogos/ParametrosSistema/DiasGraciaCorta)[1]', 'INT');
        
        IF NOT EXISTS (SELECT 1 FROM ParametrosSistema WHERE Nombre='DiasVencimientoFactura') 
            INSERT INTO ParametrosSistema(Nombre, Valor) VALUES ('DiasVencimientoFactura', ISNULL(@DiasVenc, 15));
        IF NOT EXISTS (SELECT 1 FROM ParametrosSistema WHERE Nombre='DiasGraciaCorta') 
            INSERT INTO ParametrosSistema(Nombre, Valor) VALUES ('DiasGraciaCorta', ISNULL(@DiasGra, 10));

        --Conceptos de Cobro
        INSERT INTO ConceptoCobro (Id, Nombre, IdPeriodoMontoCC, IdTipoMontoCC, ValorMinimo, ValorMinimoM3, ValorFijoM3Adicional, ValorPorcentual, ValorFijo, ValorM2Minimo, ValorTractosM2, Activo)
        SELECT 
            x.value('@id', 'INT'), x.value('@nombre', 'NVARCHAR(128)'), x.value('@PeriodoMontoCC', 'INT'), x.value('@TipoMontoCC', 'INT'),
            CAST(NULLIF(x.value('@ValorMinimo', 'VARCHAR(20)'), '') AS DECIMAL(18,2)), 
            CAST(NULLIF(x.value('@ValorMinimoM3', 'VARCHAR(20)'), '') AS DECIMAL(10,2)),
            CAST(NULLIF(x.value('@ValorFijoM3Adicional', 'VARCHAR(20)'), '') AS DECIMAL(18,2)), 
            CAST(NULLIF(x.value('@ValorPorcentual', 'VARCHAR(20)'), '') AS DECIMAL(5,4)),
            CAST(NULLIF(x.value('@ValorFijo', 'VARCHAR(20)'), '') AS DECIMAL(18,2)), 
            CAST(NULLIF(x.value('@ValorM2Minimo', 'VARCHAR(20)'), '') AS DECIMAL(10,2)),
            CAST(NULLIF(x.value('@ValorTramosM2', 'VARCHAR(20)'), '') AS DECIMAL(10,2)), 
            1
        FROM @xmlData.nodes('/Catalogos/CCs/CC') AS T(x) 
        WHERE NOT EXISTS (SELECT 1 FROM ConceptoCobro WHERE Id = x.value('@id', 'INT'));

        --Usuario Administrador
        DECLARE @AdminNombre NVARCHAR(64), @AdminPass NVARCHAR(256);
        SELECT @AdminNombre = x.value('@nombre', 'NVARCHAR(64)'), @AdminPass = x.value('@password', 'NVARCHAR(256)') 
        FROM @xmlData.nodes('/Catalogos/UsuarioAdmin/Admin') AS T(x);
        
        IF @AdminNombre IS NOT NULL AND NOT EXISTS (SELECT 1 FROM Usuario WHERE NombreUsuario = @AdminNombre)
        BEGIN
            
            
            INSERT INTO Persona (Nombre, ValorDocumentoIdentidad, Email, Telefono1) VALUES ('Administrador', '000000000', 'admin@sys.com', '0000');
            INSERT INTO Usuario (IdPersona, IdTipoUsuario, NombreUsuario, Clave, Activo) VALUES (SCOPE_IDENTITY(), 1, @AdminNombre, @AdminPass, 1);
        END

        COMMIT TRANSACTION;
        PRINT 'Carga de catálogos completada exitosamente.';
    END TRY
    BEGIN CATCH
        
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        PRINT 'Error en Carga Catalogos: ' + ERROR_MESSAGE();
    END CATCH
END;
GO
