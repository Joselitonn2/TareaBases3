CREATE TABLE TipoMovimientoLecturaMedidor (
    Id INT NOT NULL PRIMARY KEY,
    Nombre NVARCHAR(64) NOT NULL
);

-- Catálogo: Tipo de Uso de Propiedad
CREATE TABLE TipoUsoPropiedad (
    Id INT NOT NULL PRIMARY KEY,
    Nombre NVARCHAR(64) NOT NULL
);

-- Catálogo: Tipo de Zona de Propiedad
CREATE TABLE TipoZonaPropiedad (
    Id INT NOT NULL PRIMARY KEY,
    Nombre NVARCHAR(64) NOT NULL
);

-- Catálogo: Tipo de Usuario
CREATE TABLE TipoUsuario (
    Id INT NOT NULL PRIMARY KEY,
    Nombre NVARCHAR(64) NOT NULL
);

-- Catálogo: Tipo de Asociación
CREATE TABLE TipoAsociacion (
    Id INT NOT NULL PRIMARY KEY,
    Nombre NVARCHAR(64) NOT NULL
);

-- Catálogo: Tipo de Medio de Pago
CREATE TABLE TipoMedioPago (
    Id INT NOT NULL PRIMARY KEY,
    Nombre NVARCHAR(64) NOT NULL
);

-- Catálogo: Periodo Monto Concepto de Cobro
CREATE TABLE PeriodoMontoCC (
    Id INT NOT NULL PRIMARY KEY,
    Nombre NVARCHAR(64) NOT NULL,
    QMeses INT NOT NULL
);

-- Catálogo: Tipo de Monto Concepto de Cobro
CREATE TABLE TipoMontoCC (
    Id INT NOT NULL PRIMARY KEY,
    Nombre NVARCHAR(64) NOT NULL
);

-- Catálogo: Estado de Factura
CREATE TABLE EstadoFactura (
    Id INT NOT NULL PRIMARY KEY,
    Nombre NVARCHAR(64) NOT NULL
);

-- Catálogo: Estado de Orden de Corta
CREATE TABLE EstadoOrdenCorta (
    Id INT NOT NULL PRIMARY KEY,
    Nombre NVARCHAR(64) NOT NULL
);



CREATE TABLE ParametrosSistema (
    Id INT IDENTITY(1,1) PRIMARY KEY,
    Nombre NVARCHAR(128) NOT NULL UNIQUE,
    Valor INT NOT NULL,
    Descripcion NVARCHAR(256) NULL
);



-- Tabla: Personas
CREATE TABLE Persona (
    Id INT IDENTITY(1,1) PRIMARY KEY,
    Nombre NVARCHAR(256) NOT NULL,
    ValorDocumentoIdentidad NVARCHAR(64) NOT NULL UNIQUE,
    Email NVARCHAR(128) NULL,
    Telefono1 NVARCHAR(32) NULL,
    Telefono2 NVARCHAR(32) NULL,
    FechaCreacion DATETIME NOT NULL DEFAULT GETDATE()
);

-- Tabla: Propiedades
CREATE TABLE Propiedad (
    Id INT IDENTITY(1,1) PRIMARY KEY,
    NumeroFinca NVARCHAR(64) NOT NULL UNIQUE,
    MetrosCuadrados DECIMAL(10,2) NOT NULL,
    IdTipoUsoPropiedad INT NOT NULL,
    IdTipoZonaPropiedad INT NOT NULL,
    ValorFiscal DECIMAL(18,2) NOT NULL,
    FechaRegistro DATE NOT NULL,
    NumeroMedidor NVARCHAR(64) NULL UNIQUE,
    SaldoM3 DECIMAL(10,2) NOT NULL DEFAULT 0,
    SaldoM3UltimaFactura DECIMAL(10,2) NOT NULL DEFAULT 0,
    FechaCreacion DATETIME NOT NULL DEFAULT GETDATE(),
    CONSTRAINT FK_Propiedad_TipoUso FOREIGN KEY (IdTipoUsoPropiedad) 
        REFERENCES TipoUsoPropiedad(Id),
    CONSTRAINT FK_Propiedad_TipoZona FOREIGN KEY (IdTipoZonaPropiedad) 
        REFERENCES TipoZonaPropiedad(Id)
);

-- Tabla: Propietarios (relación entre Persona y Propiedad)
CREATE TABLE Propietario (
    Id INT IDENTITY(1,1) PRIMARY KEY,
    IdPersona INT NOT NULL,
    IdPropiedad INT NOT NULL,
    FechaInicio DATE NOT NULL,
    FechaFin DATE NULL,
    FechaCreacion DATETIME NOT NULL DEFAULT GETDATE(),
    CONSTRAINT FK_Propietario_Persona FOREIGN KEY (IdPersona) 
        REFERENCES Persona(Id),
    CONSTRAINT FK_Propietario_Propiedad FOREIGN KEY (IdPropiedad) 
        REFERENCES Propiedad(Id)
);

-- Tabla: Usuarios
CREATE TABLE Usuario (
    Id INT IDENTITY(1,1) PRIMARY KEY,
    IdPersona INT NOT NULL,
    IdTipoUsuario INT NOT NULL,
    NombreUsuario NVARCHAR(64) NOT NULL UNIQUE,
    Clave NVARCHAR(256) NOT NULL,
    Activo BIT NOT NULL DEFAULT 1,
    FechaCreacion DATETIME NOT NULL DEFAULT GETDATE(),
    CONSTRAINT FK_Usuario_Persona FOREIGN KEY (IdPersona) 
        REFERENCES Persona(Id),
    CONSTRAINT FK_Usuario_TipoUsuario FOREIGN KEY (IdTipoUsuario) 
        REFERENCES TipoUsuario(Id)
);

-- Tabla: Usuario-Propiedad (usuarios no admin asociados a propiedades)
CREATE TABLE UsuarioPropiedad (
    Id INT IDENTITY(1,1) PRIMARY KEY,
    IdUsuario INT NOT NULL,
    IdPropiedad INT NOT NULL,
    FechaInicio DATE NOT NULL,
    FechaFin DATE NULL,
    FechaCreacion DATETIME NOT NULL DEFAULT GETDATE(),
    CONSTRAINT FK_UsuarioPropiedad_Usuario FOREIGN KEY (IdUsuario) 
        REFERENCES Usuario(Id),
    CONSTRAINT FK_UsuarioPropiedad_Propiedad FOREIGN KEY (IdPropiedad) 
        REFERENCES Propiedad(Id)
);



-- Tabla: Concepto de Cobro (base)
CREATE TABLE ConceptoCobro (
    Id INT NOT NULL PRIMARY KEY,
    Nombre NVARCHAR(128) NOT NULL,
    IdPeriodoMontoCC INT NOT NULL,
    IdTipoMontoCC INT NOT NULL,
    ValorMinimo DECIMAL(18,2) NULL,
    ValorMinimoM3 DECIMAL(10,2) NULL,
    ValorFijoM3Adicional DECIMAL(18,2) NULL,
    ValorPorcentual DECIMAL(5,4) NULL,
    ValorFijo DECIMAL(18,2) NULL,
    ValorM2Minimo DECIMAL(10,2) NULL,
    ValorTractosM2 DECIMAL(10,2) NULL,
    Activo BIT NOT NULL DEFAULT 1,
    CONSTRAINT FK_ConceptoCobro_Periodo FOREIGN KEY (IdPeriodoMontoCC) 
        REFERENCES PeriodoMontoCC(Id),
    CONSTRAINT FK_ConceptoCobro_TipoMonto FOREIGN KEY (IdTipoMontoCC) 
        REFERENCES TipoMontoCC(Id)
);

-- Tabla: Concepto de Cobro por Propiedad
CREATE TABLE ConceptoCobroPropiedad (
    Id INT IDENTITY(1,1) PRIMARY KEY,
    IdPropiedad INT NOT NULL,
    IdConceptoCobro INT NOT NULL,
    FechaInicio DATE NOT NULL,
    FechaFin DATE NULL,
    Activo BIT NOT NULL DEFAULT 1,
    FechaCreacion DATETIME NOT NULL DEFAULT GETDATE(),
    CONSTRAINT FK_CCPropiedad_Propiedad FOREIGN KEY (IdPropiedad) 
        REFERENCES Propiedad(Id),
    CONSTRAINT FK_CCPropiedad_CC FOREIGN KEY (IdConceptoCobro) 
        REFERENCES ConceptoCobro(Id)
);



-- Tabla: Movimiento de Lectura de Medidor
CREATE TABLE MovimientoLecturaMedidor (
    Id INT IDENTITY(1,1) PRIMARY KEY,
    IdPropiedad INT NOT NULL,
    NumeroMedidor NVARCHAR(64) NOT NULL,
    IdTipoMovimiento INT NOT NULL,
    Monto DECIMAL(10,2) NOT NULL,
    SaldoAnterior DECIMAL(10,2) NOT NULL,
    SaldoNuevo DECIMAL(10,2) NOT NULL,
    FechaMovimiento DATE NOT NULL,
    FechaCreacion DATETIME NOT NULL DEFAULT GETDATE(),
    CONSTRAINT FK_MovimientoMedidor_Propiedad FOREIGN KEY (IdPropiedad) 
        REFERENCES Propiedad(Id),
    CONSTRAINT FK_MovimientoMedidor_Tipo FOREIGN KEY (IdTipoMovimiento) 
        REFERENCES TipoMovimientoLecturaMedidor(Id)
);



-- Tabla: Facturas
CREATE TABLE Factura (
    Id INT IDENTITY(1,1) PRIMARY KEY,
    NumeroFactura NVARCHAR(64) NOT NULL UNIQUE,
    IdPropiedad INT NOT NULL,
    FechaEmision DATE NOT NULL,
    FechaVencimiento DATE NOT NULL,
    FechaLimiteCorta DATE NOT NULL,
    TotalAPagarOriginal DECIMAL(18,2) NOT NULL,
    TotalAPagarFinal DECIMAL(18,2) NOT NULL,
    IdEstadoFactura INT NOT NULL DEFAULT 1,
    FechaCreacion DATETIME NOT NULL DEFAULT GETDATE(),
    CONSTRAINT FK_Factura_Propiedad FOREIGN KEY (IdPropiedad) 
        REFERENCES Propiedad(Id),
    CONSTRAINT FK_Factura_Estado FOREIGN KEY (IdEstadoFactura) 
        REFERENCES EstadoFactura(Id)
);

-- Tabla: Detalle de Factura
CREATE TABLE DetalleFactura (
    Id INT IDENTITY(1,1) PRIMARY KEY,
    IdFactura INT NOT NULL,
    IdConceptoCobro INT NOT NULL,
    Descripcion NVARCHAR(256) NULL,
    Monto DECIMAL(18,2) NOT NULL,
    FechaCreacion DATETIME NOT NULL DEFAULT GETDATE(),
    CONSTRAINT FK_DetalleFactura_Factura FOREIGN KEY (IdFactura) 
        REFERENCES Factura(Id),
    CONSTRAINT FK_DetalleFactura_CC FOREIGN KEY (IdConceptoCobro) 
        REFERENCES ConceptoCobro(Id)
);

-- Tabla: Comprobantes de Pago
CREATE TABLE ComprobantePago (
    Id INT IDENTITY(1,1) PRIMARY KEY,
    IdFactura INT NOT NULL,
    NumeroComprobante NVARCHAR(64) NOT NULL UNIQUE,
    IdTipoMedioPago INT NOT NULL,
    MontoPago DECIMAL(18,2) NOT NULL,
    FechaPago DATE NOT NULL,
    FechaCreacion DATETIME NOT NULL DEFAULT GETDATE(),
    CONSTRAINT FK_ComprobantePago_Factura FOREIGN KEY (IdFactura) 
        REFERENCES Factura(Id),
    CONSTRAINT FK_ComprobantePago_MedioPago FOREIGN KEY (IdTipoMedioPago) 
        REFERENCES TipoMedioPago(Id)
);



-- Tabla: Órdenes de Corta de Agua
CREATE TABLE OrdenCorta (
    Id INT IDENTITY(1,1) PRIMARY KEY,
    IdPropiedad INT NOT NULL,
    IdFactura INT NOT NULL,
    FechaOrden DATE NOT NULL,
    IdEstadoOrden INT NOT NULL DEFAULT 1,
    FechaCreacion DATETIME NOT NULL DEFAULT GETDATE(),
    CONSTRAINT FK_OrdenCorta_Propiedad FOREIGN KEY (IdPropiedad) 
        REFERENCES Propiedad(Id),
    CONSTRAINT FK_OrdenCorta_Factura FOREIGN KEY (IdFactura) 
        REFERENCES Factura(Id),
    CONSTRAINT FK_OrdenCorta_Estado FOREIGN KEY (IdEstadoOrden) 
        REFERENCES EstadoOrdenCorta(Id)
);

-- Tabla: Órdenes de Reconexión de Agua
CREATE TABLE OrdenReconexion (
    Id INT IDENTITY(1,1) PRIMARY KEY,
    IdOrdenCorta INT NOT NULL,
    IdPropiedad INT NOT NULL,
    IdFactura INT NOT NULL,
    FechaOrden DATE NOT NULL,
    FechaCreacion DATETIME NOT NULL DEFAULT GETDATE(),
    CONSTRAINT FK_OrdenReconexion_OrdenCorta FOREIGN KEY (IdOrdenCorta) 
        REFERENCES OrdenCorta(Id),
    CONSTRAINT FK_OrdenReconexion_Propiedad FOREIGN KEY (IdPropiedad) 
        REFERENCES Propiedad(Id),
    CONSTRAINT FK_OrdenReconexion_Factura FOREIGN KEY (IdFactura) 
        REFERENCES Factura(Id)
);



CREATE TABLE BitacoraCambios (
    Id INT IDENTITY(1,1) PRIMARY KEY,
    NombreTabla NVARCHAR(128) NOT NULL,
    IdRegistro INT NOT NULL,
    TipoOperacion NVARCHAR(32) NOT NULL,
    ValorAnterior NVARCHAR(MAX) NULL,
    ValorNuevo NVARCHAR(MAX) NULL,
    IdUsuario INT NULL,
    FechaOperacion DATETIME NOT NULL DEFAULT GETDATE(),
    CONSTRAINT FK_Bitacora_Usuario FOREIGN KEY (IdUsuario) 
        REFERENCES Usuario(Id)
);
