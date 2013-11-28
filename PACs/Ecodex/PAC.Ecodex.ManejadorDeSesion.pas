unit PAC.Ecodex.ManejadorDeSesion;

interface

uses EcodexWsSeguridad,
     FacturaTipos;

type

  TEcodexManejadorDeSesion = class
  private
    fCredenciales: TFEPACCredenciales;
    wsSeguridad : IEcodexServicioSeguridad;
    fNumeroTransaccion: Integer;
    function GetNumeroDeTransaccion: Integer;
    function ObtenerNuevoTokenDeServicio: String;
  public
    procedure AfterConstruction; override;
    procedure AsignarCredenciales(const aCredenciales: TFEPACCredenciales);
    function ObtenerNuevoTokenDeUsuario: String;
    property NumeroDeTransaccion: Integer read GetNumeroDeTransaccion;
  end;

implementation

uses SysUtils,
     {$IFDEF CODESITE}
     CodeSiteLogging,
     {$ENDIF}
     FacturacionHashes;

procedure TEcodexManejadorDeSesion.AfterConstruction;
begin
  inherited;
  wsSeguridad := GetWsEcodexSeguridad();

  // El numero de transacci�n comenzar� como un numero aleatorio
  // (excepto en las pruebas de unidad)
  Randomize;
  fNumeroTransaccion := Random(10000);
end;

procedure TEcodexManejadorDeSesion.AsignarCredenciales(const aCredenciales: TFEPACCredenciales);
begin
  Assert(aCredenciales.RFC <> '', 'El RFC de las credenciales estuvo vac�o');
  Assert(aCredenciales.Clave <> '', 'La clave de las credenciales estuvo vac�a');
  Assert(aCredenciales.DistribuidorID <> '', 'El ID de Integrador estuvo vac�o');

  fCredenciales := aCredenciales;
end;

function TEcodexManejadorDeSesion.GetNumeroDeTransaccion: Integer;
begin
  Result := fNumeroTransaccion;
end;

function TEcodexManejadorDeSesion.ObtenerNuevoTokenDeServicio: String;
var
  nuevaSolicitudDeToken: TEcodexSolicitudDeToken;
  respuestaSolicitudDeToken: TEcodexRespuestaObtenerToken;
begin
  Assert(fCredenciales.RFC <> '', 'Las credenciales del PAC no fueron asignadas');
  {$IFDEF CODESITE} CodeSite.EnterMethod('ObtenerNuevoTokenDeServicio'); {$ENDIF}
  try
    nuevaSolicitudDeToken := TEcodexSolicitudDeToken.Create;
    nuevaSolicitudDeToken.RFC := fCredenciales.RFC;
    nuevaSolicitudDeToken.TransaccionID := fNumeroTransaccion;

    respuestaSolicitudDeToken := wsSeguridad.ObtenerToken(nuevaSolicitudDeToken);
    {$IFDEF CODESITE} CodeSite.Send('Token de servicio obtenido', respuestaSolicitudDeToken.Token); {$ENDIF}
    Result := respuestaSolicitudDeToken.Token;
  finally
    nuevaSolicitudDeToken.Free;
    {$IFDEF CODESITE} CodeSite.ExitMethod('ObtenerNuevoTokenDeServicio'); {$ENDIF}
  end;
end;

function TEcodexManejadorDeSesion.ObtenerNuevoTokenDeUsuario: String;
var
  tokenDeServicio: string;
begin
  Assert(fCredenciales.RFC <> '', 'Las credenciales del PAC no fueron asignadas');

  // Incrementamos el numero de transaccion
  Inc(fNumeroTransaccion);

  try
     tokenDeServicio := ObtenerNuevoTokenDeServicio();

     // El token de usuario ser� la combinacion del token de servicio y el ID del integrador
     // concatenados por un "pipe" codificados con el agoritmo SHA1
     Result := TFacturacionHashing.CalcularHash(fCredenciales.DistribuidorID + '|' + tokenDeServicio,
                                                haSHA1)
  except
    On E:Exception do
      raise;
  end;
end;



end.
