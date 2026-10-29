import 'perfil_negocio.dart';

/// Extensiones copyWith para los modelos de PerfilNegocio.
///
/// Permiten actualizaciones inmutables desde el form:
///   _perfil = _perfil.copyWith(horario: nuevoHorario);
///
/// Se mantienen en archivo separado para evitar tocar el archivo
/// principal (522 líneas) y permitir rollback granular.

extension DireccionEstructuradaCopyWith on DireccionEstructurada {
  DireccionEstructurada copyWith({
    String? calle,
    String? numero,
    String? unidad,
    String? comuna,
    String? region,
    String? pais,
    String? codigoPostal,
    String? referencia,
  }) {
    return DireccionEstructurada(
      calle: calle ?? this.calle,
      numero: numero ?? this.numero,
      unidad: unidad ?? this.unidad,
      comuna: comuna ?? this.comuna,
      region: region ?? this.region,
      pais: pais ?? this.pais,
      codigoPostal: codigoPostal ?? this.codigoPostal,
      referencia: referencia ?? this.referencia,
    );
  }
}

extension CoordenadasCopyWith on Coordenadas {
  Coordenadas copyWith({double? lat, double? lng}) =>
      Coordenadas(lat: lat ?? this.lat, lng: lng ?? this.lng);
}

extension HorarioRangoCopyWith on HorarioRango {
  HorarioRango copyWith({String? abre, String? cierra}) =>
      HorarioRango(abre: abre ?? this.abre, cierra: cierra ?? this.cierra);
}

extension CategoriasGbpCopyWith on CategoriasGbp {
  CategoriasGbp copyWith({String? principal, List<String>? secundarias}) =>
      CategoriasGbp(
        principal: principal ?? this.principal,
        secundarias: secundarias ?? this.secundarias,
      );
}

extension PagosConfigCopyWith on PagosConfig {
  PagosConfig copyWith({List<String>? metodos, List<String>? monedas}) =>
      PagosConfig(
        metodos: metodos ?? this.metodos,
        monedas: monedas ?? this.monedas,
      );
}

extension HorarioSemanalCopyWith on HorarioSemanal {
  HorarioSemanal copyWith({
    List<HorarioRango>? lunes,
    List<HorarioRango>? martes,
    List<HorarioRango>? miercoles,
    List<HorarioRango>? jueves,
    List<HorarioRango>? viernes,
    List<HorarioRango>? sabado,
    List<HorarioRango>? domingo,
  }) => HorarioSemanal(
    lunes: lunes ?? this.lunes,
    martes: martes ?? this.martes,
    miercoles: miercoles ?? this.miercoles,
    jueves: jueves ?? this.jueves,
    viernes: viernes ?? this.viernes,
    sabado: sabado ?? this.sabado,
    domingo: domingo ?? this.domingo,
  );
}

extension AtributosGbpCopyWith on AtributosGbp {
  AtributosGbp copyWith({
    List<String>? pagos,
    List<String>? servicios,
    List<String>? accesibilidad,
    List<String>? comodidades,
    List<String>? planificacion,
  }) => AtributosGbp(
    pagos: pagos ?? this.pagos,
    servicios: servicios ?? this.servicios,
    accesibilidad: accesibilidad ?? this.accesibilidad,
    comodidades: comodidades ?? this.comodidades,
    planificacion: planificacion ?? this.planificacion,
  );
}

extension AreaServicioCopyWith on AreaServicio {
  AreaServicio copyWith({
    double? radioKm,
    List<String>? regiones,
    List<String>? ciudades,
  }) => AreaServicio(
    radioKm: radioKm ?? this.radioKm,
    regiones: regiones ?? this.regiones,
    ciudades: ciudades ?? this.ciudades,
  );
}

extension RedesSocialesPerfilCopyWith on RedesSocialesPerfil {
  RedesSocialesPerfil copyWith({
    String? instagram,
    String? facebook,
    String? tiktok,
    String? youtube,
    String? googleBusiness,
    String? tripadvisor,
  }) => RedesSocialesPerfil(
    instagram: instagram ?? this.instagram,
    facebook: facebook ?? this.facebook,
    tiktok: tiktok ?? this.tiktok,
    youtube: youtube ?? this.youtube,
    googleBusiness: googleBusiness ?? this.googleBusiness,
    tripadvisor: tripadvisor ?? this.tripadvisor,
  );
}

extension DescripcionesNegocioCopyWith on DescripcionesNegocio {
  DescripcionesNegocio copyWith({String? corta, String? gbp, String? larga}) =>
      DescripcionesNegocio(
        corta: corta ?? this.corta,
        gbp: gbp ?? this.gbp,
        larga: larga ?? this.larga,
      );
}

extension FotoNegocioCopyWith on FotoNegocio {
  FotoNegocio copyWith({String? url, String? tipo, String? alt}) => FotoNegocio(
    url: url ?? this.url,
    tipo: tipo ?? this.tipo,
    alt: alt ?? this.alt,
  );
}

extension FotosNegocioCopyWith on FotosNegocio {
  FotosNegocio copyWith({
    String? logo512,
    String? portada,
    List<FotoNegocio>? galeria,
  }) => FotosNegocio(
    logo512: logo512 ?? this.logo512,
    portada: portada ?? this.portada,
    galeria: galeria ?? this.galeria,
  );
}

extension ReservaConfigCopyWith on ReservaConfig {
  ReservaConfig copyWith({
    String? bookingUrl,
    bool? mensajeriaHabilitada,
    int? tiempoRespuestaHoras,
  }) => ReservaConfig(
    bookingUrl: bookingUrl ?? this.bookingUrl,
    mensajeriaHabilitada: mensajeriaHabilitada ?? this.mensajeriaHabilitada,
    tiempoRespuestaHoras: tiempoRespuestaHoras ?? this.tiempoRespuestaHoras,
  );
}

extension PerfilNegocioCopyWith on PerfilNegocio {
  PerfilNegocio copyWith({
    DireccionEstructurada? direccionEstructurada,
    Coordenadas? coordenadas,
    HorarioSemanal? horario,
    CategoriasGbp? categoriasGbp,
    AtributosGbp? atributos,
    PagosConfig? pagos,
    String? precioRango,
    AreaServicio? areaServicio,
    RedesSocialesPerfil? redes,
    DescripcionesNegocio? descripciones,
    FotosNegocio? fotos,
    ReservaConfig? reserva,
    Map<String, dynamic>? verticalAtributos,
  }) => PerfilNegocio(
    direccionEstructurada: direccionEstructurada ?? this.direccionEstructurada,
    coordenadas: coordenadas ?? this.coordenadas,
    horario: horario ?? this.horario,
    categoriasGbp: categoriasGbp ?? this.categoriasGbp,
    atributos: atributos ?? this.atributos,
    pagos: pagos ?? this.pagos,
    precioRango: precioRango ?? this.precioRango,
    areaServicio: areaServicio ?? this.areaServicio,
    redes: redes ?? this.redes,
    descripciones: descripciones ?? this.descripciones,
    fotos: fotos ?? this.fotos,
    reserva: reserva ?? this.reserva,
    verticalAtributos: verticalAtributos ?? this.verticalAtributos,
  );
}
