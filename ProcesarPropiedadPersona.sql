CREATE OR ALTER PROCEDURE sp_ProcesarRelacionPropiedadPersona
    @xmlData XML,
    @FechaActual DATE
AS
BEGIN
    --ASOCIAR
    -- Busca Persona y Propiedad por sus códigos únicos y crea la relación
    INSERT INTO Propietario (IdPersona, IdPropiedad, FechaInicio)
    SELECT Per.Id, Prop.Id, @FechaActual 
    FROM @xmlData.nodes('/Operaciones/FechaOperacion[@fecha=sql:variable("@FechaActual")]/PropiedadPersona/Movimiento') AS T(x) 
    INNER JOIN Persona Per ON Per.ValorDocumentoIdentidad = x.value('@valorDocumento', 'VARCHAR(50)') 
    INNER JOIN Propiedad Prop ON Prop.NumeroFinca = x.value('@numeroFinca', 'VARCHAR(50)')
    WHERE x.value('@tipoAsociacionId', 'INT') = 1 
      -- Validación para no duplicar si ya es dueño activo
      AND NOT EXISTS (SELECT 1 FROM Propietario WHERE IdPersona=Per.Id AND IdPropiedad=Prop.Id AND FechaFin IS NULL);
    
    --DESASOCIAR
    --Cierra la relación poniendo FechaFin
    UPDATE Pro 
    SET FechaFin = @FechaActual 
    FROM Propietario Pro 
    INNER JOIN Persona Per ON Per.Id = Pro.IdPersona 
    INNER JOIN Propiedad Prop ON Prop.Id = Pro.IdPropiedad 
    INNER JOIN (
        SELECT x.value('@valorDocumento', 'VARCHAR(50)') Doc, x.value('@numeroFinca', 'VARCHAR(50)') Fin 
        FROM @xmlData.nodes('/Operaciones/FechaOperacion[@fecha=sql:variable("@FechaActual")]/PropiedadPersona/Movimiento') AS T(x) 
        WHERE x.value('@tipoAsociacionId', 'INT') = 2
    ) XMLData ON XMLData.Doc = Per.ValorDocumentoIdentidad AND XMLData.Fin = Prop.NumeroFinca 
    WHERE Pro.FechaFin IS NULL; -- Solo cierra las que están abiertas
END;
GO
