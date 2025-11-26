
CREATE OR ALTER PROCEDURE sp_ProcesarRelacionCCPropiedad
    @xmlData XML,
    @FechaActual DATE
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        -- Iniciar Transacción
        BEGIN TRANSACTION;

        --ASOCIAR
        -- Agrega el servicio si no lo tiene activo
        INSERT INTO ConceptoCobroPropiedad (IdPropiedad, IdConceptoCobro, FechaInicio)
        SELECT Prop.Id, x.value('@idCC', 'INT'), @FechaActual 
        FROM @xmlData.nodes('/Operaciones/FechaOperacion[@fecha=sql:variable("@FechaActual")]/CCPropiedad/Movimiento') AS T(x) 
        INNER JOIN Propiedad Prop ON Prop.NumeroFinca = x.value('@numeroFinca', 'VARCHAR(50)')
        WHERE x.value('@tipoAsociacionId', 'INT') = 1 
          AND NOT EXISTS (SELECT 1 FROM ConceptoCobroPropiedad WHERE IdPropiedad=Prop.Id AND IdConceptoCobro=x.value('@idCC', 'INT') AND FechaFin IS NULL);
        
        --DESASOCIAR
        --Cierra el servicio
        UPDATE CCP 
        SET FechaFin = @FechaActual, Activo = 0 
        FROM ConceptoCobroPropiedad CCP 
        INNER JOIN Propiedad Prop ON Prop.Id = CCP.IdPropiedad 
        INNER JOIN (
            SELECT x.value('@numeroFinca', 'VARCHAR(50)') Fin, x.value('@idCC', 'INT') C 
            FROM @xmlData.nodes('/Operaciones/FechaOperacion[@fecha=sql:variable("@FechaActual")]/CCPropiedad/Movimiento') AS T(x) 
            WHERE x.value('@tipoAsociacionId', 'INT') = 2
        ) XMLData ON XMLData.Fin = Prop.NumeroFinca AND XMLData.C = CCP.IdConceptoCobro 
        WHERE CCP.FechaFin IS NULL;

        
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
            
        PRINT 'Error en sp_ProcesarRelacionCCPropiedad: ' + ERROR_MESSAGE();
        
        
    END CATCH
END;
GO