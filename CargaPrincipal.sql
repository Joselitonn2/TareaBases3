SET NOCOUNT ON;

DECLARE @xmlCatalogos XML;
DECLARE @xmlOperaciones XML;


--CARGAR Y PROCESAR CATÁLOGOS

PRINT '>>> 1. Leyendo archivo de Catálogos desde disco...';

BEGIN TRY
 
    SELECT @xmlCatalogos = BulkColumn 
    FROM OPENROWSET(BULK 'C:\TEMPORAL\catalogosV2.xml', SINGLE_BLOB) AS x;

    PRINT '    Archivo leído correctamente.';
    
    PRINT '    Ejecutando sp_CargarCatalogos...';
    EXEC sp_CargarCatalogos @xmlData = @xmlCatalogos;
    PRINT '>>> Catálogos cargados exitosamente.';
END TRY
BEGIN CATCH
    PRINT ' Error cargando Catálogos.';
    PRINT 'Error: ' + ERROR_MESSAGE();
    RETURN; 
END CATCH

PRINT '---------------------------------------------------------';


--CARGAR Y PROCESAR SIMULACIÓN (OPERACIONES)

PRINT '>>> 2. Leyendo archivo de Operaciones';

BEGIN TRY
    
    SELECT @xmlOperaciones = BulkColumn 
    FROM OPENROWSET(BULK 'C:\TEMPORAL\xmlUltimo.xml', SINGLE_BLOB) AS x;

    PRINT '    Archivo leído correctamente.';
    
    PRINT '    Iniciando simulación cronológica';
    EXEC sp_ProcesarSimulacionCompleta @xmlData = @xmlOperaciones;
    PRINT '>>> Simulación Completada Exitosamente.';
END TRY
BEGIN CATCH
    PRINT 'Error en la Simulación.';
    PRINT 'Error: ' + ERROR_MESSAGE();
END CATCH