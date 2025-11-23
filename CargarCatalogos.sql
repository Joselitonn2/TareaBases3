CREATE OR ALTER PROCEDURE sp_CargarCatalogos
    @xmlData XML
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        -- ============================================================
        -- 1. CARGA DE TIPOS SIMPLES (Tablas Diccionario)
        -- ============================================================

        -- TipoMovimientoLecturaMedidor
        INSERT INTO TipoMovimientoLecturaMedidor (Id, Nombre)
        SELECT 
            x.value('@id', 'INT'),
            x.value('@nombre', 'NVARCHAR(64)')
        FROM @xmlData.nodes('/Catalogos/TipoMovimientoLecturaMedidor/TipoMov') AS T(x)
        WHERE NOT EXISTS (SELECT 1 FROM TipoMovimientoLecturaMedidor WHERE Id = x.value('@id', 'INT'));

        -- TipoUsoPropiedad
        INSERT INTO TipoUsoPropiedad (Id, Nombre)
        SELECT 
            x.value('@id', 'INT'),
            x.value('@nombre', 'NVARCHAR(64)')
        FROM @xmlData.nodes('/Catalogos/TipoUsoPropiedad/TipoUso') AS T(x)
        WHERE NOT EXISTS (SELECT 1 FROM TipoUsoPropiedad WHERE Id = x.value('@id', 'INT'));

        -- TipoZonaPropiedad
        INSERT INTO TipoZonaPropiedad (Id, Nombre)
        SELECT 
            x.value('@id', 'INT'),
            x.value('@nombre', 'NVARCHAR(64)')
        FROM @xmlData.nodes('/Catalogos/TipoZonaPropiedad/TipoZona') AS T(x)
        WHERE NOT EXISTS (SELECT 1 FROM TipoZonaPropiedad WHERE Id = x.value('@id', 'INT'));

        -- TipoAsociacion
        INSERT INTO TipoAsociacion (Id, Nombre)
        SELECT 
            x.value('@id', 'INT'),
            x.value('@nombre', 'NVARCHAR(64)')
        FROM @xmlData.nodes('/Catalogos/TipoAsociacion/TipoAso') AS T(x)
        WHERE NOT EXISTS (SELECT 1 FROM TipoAsociacion WHERE Id = x.value('@id', 'INT'));

        -- TipoMedioPago
        INSERT INTO TipoMedioPago (Id, Nombre)
        SELECT 
            x.value('@id', 'INT'),
            x.value('@nombre', 'NVARCHAR(64)')
        FROM @xmlData.nodes('/Catalogos/TipoMedioPago/MedioPago') AS T(x)
        WHERE NOT EXISTS (SELECT 1 FROM TipoMedioPago WHERE Id = x.value('@id', 'INT'));

        -- TipoMontoCC
        INSERT INTO TipoMontoCC (Id, Nombre)
        SELECT 
            x.value('@id', 'INT'),
            x.value('@nombre', 'NVARCHAR(64)')
        FROM @xmlData.nodes('/Catalogos/TipoMontoCC/TipoMonto') AS T(x)
        WHERE NOT EXISTS (SELECT 1 FROM TipoMontoCC WHERE Id = x.value('@id', 'INT'));

        -- PeriodoMontoCC
        INSERT INTO PeriodoMontoCC (Id, Nombre, QMeses)
        SELECT 
            x.value('@id', 'INT'),
            x.value('@nombre', 'NVARCHAR(64)'),
            x.value('@qMeses', 'INT')
        FROM @xmlData.nodes('/Catalogos/PeriodoMontoCC/PeriodoMonto') AS T(x)
        WHERE NOT EXISTS (SELECT 1 FROM PeriodoMontoCC WHERE Id = x.value('@id', 'INT'));

        -- ============================================================
        -- 1.1 CARGA DE TIPO USUARIO (No está en XML, pero es requerido por FK)
        -- ============================================================
        IF NOT EXISTS (SELECT 1 FROM TipoUsuario WHERE Id = 1) INSERT INTO TipoUsuario(Id, Nombre) VALUES (1, 'Administrador');
        IF NOT EXISTS (SELECT 1 FROM TipoUsuario WHERE Id = 2) INSERT INTO TipoUsuario(Id, Nombre) VALUES (2, 'Propietario');

        -- ============================================================
        -- 2. CARGA DE PARÁMETROS DEL SISTEMA
        -- ============================================================
        -- Extraemos nodo por nodo ya que la estructura XML es nombre de tag = nombre parámetro

        -- DiasVencimientoFactura
        DECLARE @DiasVencimiento INT = @xmlData.value('(/Catalogos/ParametrosSistema/DiasVencimientoFactura)[1]', 'INT');
        IF NOT EXISTS (SELECT 1 FROM ParametrosSistema WHERE Nombre = 'DiasVencimientoFactura')
            INSERT INTO ParametrosSistema (Nombre, Valor, Descripcion) VALUES ('DiasVencimientoFactura', @DiasVencimiento, 'Días para vencimiento de factura');

        -- DiasGraciaCorta
        DECLARE @DiasGracia INT = @xmlData.value('(/Catalogos/ParametrosSistema/DiasGraciaCorta)[1]', 'INT');
        IF NOT EXISTS (SELECT 1 FROM ParametrosSistema WHERE Nombre = 'DiasGraciaCorta')
            INSERT INTO ParametrosSistema (Nombre, Valor, Descripcion) VALUES ('DiasGraciaCorta', @DiasGracia, 'Días de gracia antes de la corta');

        -- ============================================================
        -- 3. CARGA DE CONCEPTOS DE COBRO (Manejo de NULLs)
        -- ============================================================
        
        INSERT INTO ConceptoCobro (
            Id, Nombre, IdPeriodoMontoCC, IdTipoMontoCC, 
            ValorMinimo, ValorMinimoM3, ValorFijoM3Adicional, 
            ValorPorcentual, ValorFijo, ValorM2Minimo, ValorTractosM2, Activo
        )
        SELECT 
            x.value('@id', 'INT'),
            x.value('@nombre', 'NVARCHAR(128)'),
            x.value('@PeriodoMontoCC', 'INT'),
            x.value('@TipoMontoCC', 'INT'),
            -- Truco para convertir string vacio "" a NULL antes de convertir a DECIMAL
            CAST(NULLIF(x.value('@ValorMinimo', 'VARCHAR(20)'), '') AS DECIMAL(18,2)),
            CAST(NULLIF(x.value('@ValorMinimoM3', 'VARCHAR(20)'), '') AS DECIMAL(10,2)),
            CAST(NULLIF(x.value('@ValorFijoM3Adicional', 'VARCHAR(20)'), '') AS DECIMAL(18,2)),
            CAST(NULLIF(x.value('@ValorPorcentual', 'VARCHAR(20)'), '') AS DECIMAL(5,4)),
            CAST(NULLIF(x.value('@ValorFijo', 'VARCHAR(20)'), '') AS DECIMAL(18,2)),
            CAST(NULLIF(x.value('@ValorM2Minimo', 'VARCHAR(20)'), '') AS DECIMAL(10,2)),
            CAST(NULLIF(x.value('@ValorTramosM2', 'VARCHAR(20)'), '') AS DECIMAL(10,2)), -- Ojo: XML dice Tramos, Tabla dice Tractos
            1 -- Activo
        FROM @xmlData.nodes('/Catalogos/CCs/CC') AS T(x)
        WHERE NOT EXISTS (SELECT 1 FROM ConceptoCobro WHERE Id = x.value('@id', 'INT'));

        -- ============================================================
        -- 4. CARGA DE USUARIO ADMINISTRADOR
        -- ============================================================
        -- Requiere insertar primero en Persona y luego en Usuario
        
        DECLARE @AdminNombre NVARCHAR(64), @AdminPass NVARCHAR(256);
        SELECT 
            @AdminNombre = x.value('@nombre', 'NVARCHAR(64)'),
            @AdminPass = x.value('@password', 'NVARCHAR(256)')
        FROM @xmlData.nodes('/Catalogos/UsuarioAdmin/Admin') AS T(x);

        IF @AdminNombre IS NOT NULL
        BEGIN
            -- Verificar si ya existe la persona (asumimos un ID ficticio o buscamos por nombre para no duplicar)
            -- Para este ejemplo, crearemos la Persona si no existe un Usuario 'Administrador'
            IF NOT EXISTS (SELECT 1 FROM Usuario WHERE NombreUsuario = @AdminNombre)
            BEGIN
                DECLARE @IdPersonaAdmin INT;
                
                -- Insertar Persona
                INSERT INTO Persona (Nombre, ValorDocumentoIdentidad, Email, Telefono1)
                VALUES ('Usuario Administrador', '000000000', 'admin@muni.cr', '88888888');
                
                SET @IdPersonaAdmin = SCOPE_IDENTITY();

                -- Insertar Usuario (TipoUsuario 1 = Admin)
                INSERT INTO Usuario (IdPersona, IdTipoUsuario, NombreUsuario, Clave, Activo)
                VALUES (@IdPersonaAdmin, 1, @AdminNombre, @AdminPass, 1);
            END
        END

        COMMIT TRANSACTION;
        PRINT 'Carga de catálogos completada exitosamente.';
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        PRINT 'Error cargando catálogos: ' + ERROR_MESSAGE();
    END CATCH
END;
GO