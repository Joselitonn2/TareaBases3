
CREATE OR ALTER PROCEDURE sp_AsignarCC_Propiedad
    @FechaOperacion DATE
AS
BEGIN
    

    -- 1. Impuesto Propiedad
    INSERT INTO ConceptoCobroPropiedad (IdPropiedad, IdConceptoCobro, FechaInicio) 
    SELECT Id, 3, @FechaOperacion FROM Propiedad 
    WHERE NOT EXISTS (SELECT 1 FROM ConceptoCobroPropiedad WHERE IdPropiedad=Propiedad.Id AND IdConceptoCobro=3);
    
    -- 2. Agua (Solo Residencial, Comercial, Industrial)
    INSERT INTO ConceptoCobroPropiedad (IdPropiedad, IdConceptoCobro, FechaInicio) 
    SELECT Id, 1, @FechaOperacion FROM Propiedad 
    WHERE IdTipoUsoPropiedad IN (1, 2, 3) 
    AND NOT EXISTS (SELECT 1 FROM ConceptoCobroPropiedad WHERE IdPropiedad=Propiedad.Id AND IdConceptoCobro=1);
    
    -- 3. Basura (menos Zona Agrícola)
    INSERT INTO ConceptoCobroPropiedad (IdPropiedad, IdConceptoCobro, FechaInicio) 
    SELECT Id, 4, @FechaOperacion FROM Propiedad 
    WHERE IdTipoZonaPropiedad <> 2 
    AND NOT EXISTS (SELECT 1 FROM ConceptoCobroPropiedad WHERE IdPropiedad=Propiedad.Id AND IdConceptoCobro=4);
    
    -- 4. Parques (Solo Residencial o Comercial)
    INSERT INTO ConceptoCobroPropiedad (IdPropiedad, IdConceptoCobro, FechaInicio) 
    SELECT Id, 5, @FechaOperacion FROM Propiedad 
    WHERE IdTipoZonaPropiedad IN (1, 5) 
    AND NOT EXISTS (SELECT 1 FROM ConceptoCobroPropiedad WHERE IdPropiedad=Propiedad.Id AND IdConceptoCobro=5);
END;
GO