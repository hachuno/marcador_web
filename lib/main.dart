import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'google_cast_button.dart';

import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  await Firebase.initializeApp(options: firebaseOptions);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Marcador Pro',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: Colors.black,
        colorScheme: const ColorScheme.dark(primary: Colors.blueAccent),
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const SeleccionModo(),
        '/control': (context) => const PantallaControl(),
        '/tv': (context) => const PantallaTV(),
      },
    );
  }
}

// ==========================================
// 1. PANTALLA DE SELECCIÓN (MODIFICADA)
// ==========================================
class SeleccionModo extends StatefulWidget {
  const SeleccionModo({super.key});

  @override
  State<SeleccionModo> createState() => _SeleccionModoState();
}

class _SeleccionModoState extends State<SeleccionModo> {
  final DatabaseReference _ref = FirebaseDatabase.instance.ref("partido");
  int _setsSeleccionados = 5; // Por defecto a 5 sets

  void _iniciarNuevoPartido() {
    // Reseteamos todo y guardamos la configuración de sets
    _ref.update({
      'puntosA': 0, 'puntosB': 0, 
      'setsA': 0, 'setsB': 0,
      'historialSets': [],
      'saqueInicialA': null,
      'nombreA': "Jugador 1",
      'nombreB': "Jugador 2",
      'maxSets': _setsSeleccionados, // <--- GUARDAMOS LA ELECCIÓN
    }).then((_) {
      Navigator.pushNamed(context, '/control');
    });
  }

  void _continuarPartido() {
    // Solo navegamos, no tocamos la configuración
    Navigator.pushNamed(context, '/control');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.sports_tennis, size: 80, color: Colors.white),
              const SizedBox(height: 30),
              
              const Text("CONFIGURACIÓN NUEVO JUEGO", style: TextStyle(color: Colors.grey, fontSize: 12, letterSpacing: 1.5)),
              const SizedBox(height: 10),
              
              // --- SELECTOR DE SETS ---
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey[900],
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white24)
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _botonSetOption(3, "Mejor de 3"),
                    _botonSetOption(5, "Mejor de 5"),
                  ],
                ),
              ),
              
              const SizedBox(height: 30),

              // --- BOTÓN NUEVO PARTIDO ---
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.add_circle_outline, color: Colors.white),
                  label: const Text("INICIAR NUEVO PARTIDO", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[800],
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: _iniciarNuevoPartido,
                ),
              ),

              const SizedBox(height: 15),

              // --- BOTÓN CONTINUAR (CON LÓGICA DE BLOQUEO) ---
              StreamBuilder(
                stream: _ref.onValue,
                builder: (context, snapshot) {
                  bool hayPartidoEnCurso = false;
                  if (snapshot.hasData && snapshot.data!.snapshot.value != null) {
                    final data = Map<String, dynamic>.from(snapshot.data!.snapshot.value as Map);
                    int pA = data['puntosA'] ?? 0;
                    int pB = data['puntosB'] ?? 0;
                    int sA = data['setsA'] ?? 0;
                    int sB = data['setsB'] ?? 0;
                    // Si hay algún punto o set, hay partido.
                    if (pA > 0 || pB > 0 || sA > 0 || sB > 0) {
                      hayPartidoEnCurso = true;
                    }
                  }

                  return SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.play_arrow_rounded),
                      label: const Text("CONTINUAR ANTERIOR", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green[800],
                        disabledBackgroundColor: Colors.grey[900], // Color cuando está desactivado
                        disabledForegroundColor: Colors.grey[700],
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      // Si no hay partido, el botón es null (deshabilitado)
                      onPressed: hayPartidoEnCurso ? _continuarPartido : null,
                    ),
                  );
                }
              ),

              const SizedBox(height: 40),
              TextButton.icon(
                icon: const Icon(Icons.tv, color: Colors.white54),
                label: const Text("Ir a Pantalla TV", style: TextStyle(color: Colors.white54)),
                onPressed: () => Navigator.pushNamed(context, '/tv'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _botonSetOption(int valor, String texto) {
    bool seleccionado = _setsSeleccionados == valor;
    return GestureDetector(
      onTap: () => setState(() => _setsSeleccionados = valor),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: seleccionado ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          texto, 
          style: TextStyle(
            color: seleccionado ? Colors.black : Colors.white54, 
            fontWeight: FontWeight.bold
          )
        ),
      ),
    );
  }
}

// 2. PANTALLA CONTROL
class PantallaControl extends StatefulWidget {
  const PantallaControl({super.key});
  @override
  State<PantallaControl> createState() => _PantallaControlState();
}

class _PantallaControlState extends State<PantallaControl> {
  final DatabaseReference _ref = FirebaseDatabase.instance.ref("partido");
  
  final TextEditingController _nombreAController = TextEditingController();
  final TextEditingController _nombreBController = TextEditingController();

  final FocusNode _focusA = FocusNode();
  final FocusNode _focusB = FocusNode();

  bool _procesando = false;

  @override
  void initState() {
    super.initState();
    _ref.child('nombreA').get().then((s) { if(s.exists) _nombreAController.text = s.value.toString(); });
    _ref.child('nombreB').get().then((s) { if(s.exists) _nombreBController.text = s.value.toString(); });

    _focusA.addListener(() {
      if (!_focusA.hasFocus && _nombreAController.text.trim().isEmpty) {
        _nombreAController.text = "Jugador 1";
        actualizarNombre('A', "Jugador 1");
      }
    });

    _focusB.addListener(() {
      if (!_focusB.hasFocus && _nombreBController.text.trim().isEmpty) {
        _nombreBController.text = "Jugador 2";
        actualizarNombre('B', "Jugador 2");
      }
    });
  }

  @override
  void dispose() {
    _nombreAController.dispose();
    _nombreBController.dispose();
    _focusA.dispose();
    _focusB.dispose();
    super.dispose();
  }

  void _limpiarSiEsDefault(TextEditingController controller, String defaultName) {
    if (controller.text == defaultName) {
      controller.clear();
    }
  }

  // ALERTA: FALTA SAQUE
  void _mostrarAlertaSaque(BuildContext context) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: const [
            Icon(Icons.pan_tool_rounded, color: Colors.white, size: 26),
            SizedBox(width: 15),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("¡FALTA EL SAQUE!", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
                  Text("Toca el recuadro a la derecha del Jugador que inicia sacando.", style: TextStyle(fontSize: 13, color: Colors.white70)),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: Colors.red[900],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        margin: EdgeInsets.only(
          bottom: MediaQuery.of(context).size.height - 275, 
          left: 20, 
          right: 20
        ),
        duration: const Duration(milliseconds: 2500),
      )
    );
  }

  // ALERTA: PARTIDO TERMINADO
  void _mostrarAlertaFinPartido(BuildContext context, String ganador) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.emoji_events_rounded, color: Colors.white, size: 28),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("¡PARTIDO FINALIZADO!", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
                  Text("Ganador: $ganador. Usa 'Reset' para jugar de nuevo.", style: TextStyle(fontSize: 13, color: Colors.white70)),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: Colors.green[800],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        margin: EdgeInsets.only(
          bottom: MediaQuery.of(context).size.height - 275, 
          left: 20, 
          right: 20
        ),
        duration: const Duration(milliseconds: 3000),
      )
    );
  }

  void actualizarPunto(String equipo, int cantidad, bool? saqueLocal) {
    if (cantidad > 0 && saqueLocal == null) {
      _mostrarAlertaSaque(context);
      return; 
    }

    if (_procesando) return;
    setState(() => _procesando = true);

    _ref.once().then((event) {
      if (event.snapshot.value == null) {
        setState(() => _procesando = false);
        return;
      }
      final data = Map<String, dynamic>.from(event.snapshot.value as Map);
      
      int pA = data['puntosA'] ?? 0;
      int pB = data['puntosB'] ?? 0;
      int sA = data['setsA'] ?? 0;
      int sB = data['setsB'] ?? 0;
      
      // LEER CONFIGURACIÓN DE SETS (Default 5 si no existe)
      int maxSets = data['maxSets'] ?? 5;
      
      // CALCULAR SETS PARA GANAR (Ej: Si es 5, gana con 3. Si es 3, gana con 2)
      int setsParaGanar = (maxSets / 2).ceil();

      // CHEQUEO PREVIO: Si ya terminó
      bool partidoYaTerminado = (sA >= setsParaGanar || sB >= setsParaGanar);
      
      if (cantidad > 0 && partidoYaTerminado) {
        String nombreGanador = sA > sB ? (data['nombreA'] ?? "Jugador 1") : (data['nombreB'] ?? "Jugador 2");
        setState(() => _procesando = false);
        _mostrarAlertaFinPartido(context, nombreGanador);
        return;
      }
      
      List<Map<String, dynamic>> historial = [];
      if (data['historialSets'] != null) {
         try {
           final dynamic raw = data['historialSets'];
           if (raw is List) { historial = List<Map<String, dynamic>>.from(raw.map((e) => Map<String, dynamic>.from(e as Map))); }
           else if (raw is Map) { historial = List<Map<String, dynamic>>.from(raw.values.map((e) => Map<String, dynamic>.from(e as Map))); }
         } catch (e) { historial = []; }
      }

      // CASO A: DESHACER
      if (cantidad < 0 && ((equipo == 'A' && pA == 0) || (equipo == 'B' && pB == 0))) {
         if (historial.isNotEmpty) {
           final ultimoSet = historial.last;
           String ganadorUltimo = ultimoSet['ganador'];
           if (equipo == ganadorUltimo) {
             historial.removeLast();
             int pARestaurado = ultimoSet['puntosA'];
             int pBRestaurado = ultimoSet['puntosB'];
             if (ganadorUltimo == 'A') { pARestaurado--; sA--; } else { pBRestaurado--; sB--; }
             _ref.update({
               'puntosA': pARestaurado, 'puntosB': pBRestaurado,
               'setsA': sA, 'setsB': sB,
               'historialSets': historial
             }).whenComplete(() => setState(() => _procesando = false));
             return;
           }
         }
         setState(() => _procesando = false);
         return;
      }

      // CASO B: JUGADA NORMAL
      int nuevoPA = pA;
      int nuevoPB = pB;
      if (equipo == 'A') nuevoPA += cantidad; else nuevoPB += cantidad;
      if (nuevoPA < 0) nuevoPA = 0;
      if (nuevoPB < 0) nuevoPB = 0;

      if (nuevoPA >= 11 && (nuevoPA - nuevoPB) >= 2) {
         historial.add({'ganador': 'A', 'puntosA': nuevoPA, 'puntosB': nuevoPB});
         int nuevosSetsA = sA + 1;
         
         _ref.update({ 'puntosA': 0, 'puntosB': 0, 'setsA': nuevosSetsA, 'historialSets': historial
         }).whenComplete(() {
            setState(() => _procesando = false);
            if (nuevosSetsA >= setsParaGanar) {
              _mostrarAlertaFinPartido(context, data['nombreA'] ?? "Jugador 1");
            }
         });

      } else if (nuevoPB >= 11 && (nuevoPB - nuevoPA) >= 2) {
         historial.add({'ganador': 'B', 'puntosA': nuevoPA, 'puntosB': nuevoPB});
         int nuevosSetsB = sB + 1;

         _ref.update({ 'puntosA': 0, 'puntosB': 0, 'setsB': nuevosSetsB, 'historialSets': historial
         }).whenComplete(() {
            setState(() => _procesando = false);
            if (nuevosSetsB >= setsParaGanar) {
              _mostrarAlertaFinPartido(context, data['nombreB'] ?? "Jugador 2");
            }
         });

      } else {
         _ref.update({ 'puntosA': nuevoPA, 'puntosB': nuevoPB
         }).whenComplete(() => setState(() => _procesando = false));
      }

    }).catchError((e) {
      setState(() => _procesando = false);
    });
  }

  void actualizarNombre(String equipo, String nombre) {
    _ref.update({'nombre$equipo': nombre});
  }
  
  void cambiarSaqueInicial(bool esA) {
    _ref.update({'saqueInicialA': esA});
  }

  void reset() {
    _ref.update({
      'puntosA': 0, 'puntosB': 0, 'setsA': 0, 'setsB': 0, 
      'historialSets': [], 
      'saqueInicialA': null, 
      'nombreA': "Jugador 1", 'nombreB': "Jugador 2",
      'maxSets': 5 // Default al resetear desde acá
    });
  }

  @override
  Widget build(BuildContext context) {
    final esHorizontal = MediaQuery.of(context).orientation == Orientation.landscape;

    if (esHorizontal) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: const [Icon(Icons.screen_lock_portrait, size: 80, color: Colors.white), SizedBox(height: 20), Text("GIRA TU TELÉFONO", style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold))])),
      );
    }
    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: const Text("Control de Mesa"), 
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: SizedBox(width: 40, height: 40, child: GoogleCastButton()),
          ),
          IconButton(icon: const Icon(Icons.refresh, color: Colors.white), onPressed: reset)
        ],          
      ),
      body: StreamBuilder(
        stream: _ref.onValue,
        builder: (context, snapshot) {
          int pA = 0, pB = 0, sA = 0, sB = 0;
          bool? saqueInicialA;
          String nombreA = "Jugador 1";
          String nombreB = "Jugador 2";
          List<Map<String, dynamic>> historialSets = [];

          if (snapshot.hasData && snapshot.data!.snapshot.value != null) {
            final data = Map<String, dynamic>.from(snapshot.data!.snapshot.value as Map);
            pA = data['puntosA'] ?? 0;
            pB = data['puntosB'] ?? 0;
            sA = data['setsA'] ?? 0;
            sB = data['setsB'] ?? 0;
            saqueInicialA = data['saqueInicialA'];
            nombreA = data['nombreA'] ?? "Jugador 1";
            nombreB = data['nombreB'] ?? "Jugador 2";
            
            if (data['historialSets'] != null) {
              try {
                final dynamic raw = data['historialSets'];
                if (raw is List) {
                   historialSets = List<Map<String, dynamic>>.from(raw.map((e) => Map<String, dynamic>.from(e as Map)));
                } else if (raw is Map) {
                   historialSets = List<Map<String, dynamic>>.from(raw.values.map((e) => Map<String, dynamic>.from(e as Map)));
                }
              } catch (e) { historialSets = []; }
            }
          }

          if (_nombreAController.text != nombreA && !_focusA.hasFocus) _nombreAController.text = nombreA;
          if (_nombreBController.text != nombreB && !_focusB.hasFocus) _nombreBController.text = nombreB;

          bool bloqueado = (pA + pB) >= 2 || sA > 0 || sB > 0;
          
          int totalPuntos = pA + pB;
          int setActual = sA + sB + 1;
          bool esSetImpar = (setActual % 2 == 1);
          
          bool safeSaque = saqueInicialA ?? true;
          bool haySaqueDefinido = saqueInicialA != null;

          bool saqueInicialEnEsteSet = esSetImpar ? safeSaque : !safeSaque;
          bool turnoBaseParaA;
          if (pA >= 10 && pB >= 10) turnoBaseParaA = (totalPuntos % 2 == 0);
          else turnoBaseParaA = ((totalPuntos ~/ 2) % 2 == 0);
          
          bool saqueParaA = saqueInicialEnEsteSet ? turnoBaseParaA : !turnoBaseParaA;
          bool invertirLados = (sA + sB) % 2 != 0;

          // WIDGETS
          Widget topAzul = Row(children: [
             Expanded(child: TextField(controller: _nombreAController, focusNode: _focusA, style: const TextStyle(color: Colors.blueAccent, fontSize: 18), cursorColor: Colors.blueAccent, decoration: const InputDecoration(isDense: true, focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.blueAccent, width: 2)), enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)), hintStyle: TextStyle(color: Colors.white24)), onChanged: (v) => actualizarNombre('A', v), onTap: () => _limpiarSiEsDefault(_nombreAController, "Jugador 1"))),
             const SizedBox(width: 5),
             _BotonSaqueConPelota(seleccionado: saqueInicialA == true, bloqueado: bloqueado, color: Colors.blue[800]!, onTap: () => cambiarSaqueInicial(true)),
          ]);
          Widget topRojo = Row(children: [
             Expanded(child: TextField(controller: _nombreBController, focusNode: _focusB, style: const TextStyle(color: Colors.redAccent, fontSize: 18), cursorColor: Colors.redAccent, decoration: const InputDecoration(isDense: true, focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.redAccent, width: 2)), enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)), hintStyle: TextStyle(color: Colors.white24)), onChanged: (v) => actualizarNombre('B', v), onTap: () => _limpiarSiEsDefault(_nombreBController, "Jugador 2"))),
             const SizedBox(width: 5),
             _BotonSaqueConPelota(seleccionado: saqueInicialA == false, bloqueado: bloqueado, color: Colors.red[800]!, onTap: () => cambiarSaqueInicial(false)),
          ]);

          Widget scoreAzul = Column(children: [Text("$pA", style: const TextStyle(color: Colors.white, fontSize: 80, height: 1, fontWeight: FontWeight.bold))]);
          Widget scoreRojo = Column(children: [Text("$pB", style: const TextStyle(color: Colors.white, fontSize: 80, height: 1, fontWeight: FontWeight.bold))]);

          Widget botonAzul = _BotonJugador(
             color: Colors.blue[900]!, label: "AZUL", 
             onSumar: () => actualizarPunto('A', 1, saqueInicialA), 
             onRestar: () => actualizarPunto('A', -1, saqueInicialA));
          
          Widget botonRojo = _BotonJugador(
             color: Colors.red[900]!, label: "ROJO", 
             onSumar: () => actualizarPunto('B', 1, saqueInicialA), 
             onRestar: () => actualizarPunto('B', -1, saqueInicialA));

          Widget separadorVS = const Padding(padding: EdgeInsets.symmetric(horizontal: 8.0), child: Text("VS", style: TextStyle(color: Colors.grey, fontSize: 10)));
          
          bool flechaIzquierda = (saqueParaA == !invertirLados);

          Widget indicadorSaque = Opacity(
             opacity: haySaqueDefinido ? 1.0 : 0.0,
             child: Container(
               width: 65, height: 38, alignment: Alignment.center,
               decoration: BoxDecoration(color: Colors.grey[900], border: Border.all(color: saqueParaA ? Colors.blueAccent : Colors.redAccent, width: 2), borderRadius: BorderRadius.circular(30)),
               child: Icon(flechaIzquierda ? Icons.arrow_back : Icons.arrow_forward, color: Colors.white, size: 26, shadows: const [Shadow(color: Colors.white, offset: Offset(0.5, 0)), Shadow(color: Colors.white, offset: Offset(-0.5, 0)), Shadow(color: Colors.white, offset: Offset(0, 0.5)), Shadow(color: Colors.white, offset: Offset(0, -0.5))]),
             ),
          );

          return Column(
            children: [
              Padding(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), child: Row(children: [Expanded(child: invertirLados ? topRojo : topAzul), separadorVS, Expanded(child: invertirLados ? topAzul : topRojo)])),
              
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                child: _TablaPuntuacion(
                  nombreA: nombreA,
                  nombreB: nombreB,
                  setsA: sA,
                  setsB: sB,
                  historial: historialSets,
                ),
              ),

              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  children: [
                    Expanded(child: Center(child: invertirLados ? scoreRojo : scoreAzul)),
                    indicadorSaque,
                    Expanded(child: Center(child: invertirLados ? scoreAzul : scoreRojo)),
                  ],
                )
              ),
              
              Expanded(child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: invertirLados ? [botonRojo, botonAzul] : [botonAzul, botonRojo])),
            ],
          );
        }
      ),
    );
  }
}

// === WIDGETS AUXILIARES ===

class _TablaPuntuacion extends StatelessWidget {
  final String nombreA;
  final String nombreB;
  final int setsA;
  final int setsB;
  final List<Map<String, dynamic>> historial;

  const _TablaPuntuacion({
    required this.nombreA,
    required this.nombreB,
    required this.setsA,
    required this.setsB,
    required this.historial,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        children: [
          _FilaJugador(
            nombre: nombreA,
            esJugadorA: true,
            historial: historial,
            totalSets: setsA,
            colorEquipo: Colors.blueAccent, 
            colorFondoTotal: Colors.blue[900]!,
            mostrarBordeInferior: true,
          ),
          _FilaJugador(
            nombre: nombreB,
            esJugadorA: false,
            historial: historial,
            totalSets: setsB,
            colorEquipo: Colors.redAccent,
            colorFondoTotal: Colors.red[900]!,
            mostrarBordeInferior: false,
          ),
        ],
      ),
    );
  }
}

class _FilaJugador extends StatelessWidget {
  final String nombre;
  final bool esJugadorA;
  final List<Map<String, dynamic>> historial;
  final int totalSets;
  final Color colorEquipo;
  final Color colorFondoTotal;
  final bool mostrarBordeInferior;

  const _FilaJugador({
    required this.nombre,
    required this.esJugadorA,
    required this.historial,
    required this.totalSets,
    required this.colorEquipo,
    required this.colorFondoTotal,
    required this.mostrarBordeInferior,
  });

  @override
  Widget build(BuildContext context) {
    List<Widget> celdasSets = List.generate(5, (index) {
      String textoPuntos = "";
      Color colorFondo = Colors.transparent;
      Color colorTexto = Colors.white54;

      if (index < historial.length) {
        final set = historial[index];
        final pA = set['puntosA'];
        final pB = set['puntosB'];
        final ganador = set['ganador'];

        int puntosMios = esJugadorA ? pA : pB;
        bool ganeEsteSet = (esJugadorA && ganador == 'A') || (!esJugadorA && ganador == 'B');

        textoPuntos = puntosMios.toString();
        
        if (ganeEsteSet) {
          colorFondo = esJugadorA ? Colors.blue[900]!.withOpacity(0.5) : Colors.red[900]!.withOpacity(0.5);
          colorTexto = Colors.white; 
        } else {
           colorTexto = Colors.white38; 
        }
      }

      return Expanded(
        flex: 1, 
        child: Container(
          height: 35,
          decoration: BoxDecoration(
             color: colorFondo,
             border: const Border(left: BorderSide(color: Colors.white10)),
          ),
          alignment: Alignment.center,
          child: Text(textoPuntos, style: TextStyle(color: colorTexto, fontWeight: FontWeight.bold)),
        ),
      );
    });

    return Container(
      decoration: BoxDecoration(
        border: mostrarBordeInferior ? const Border(bottom: BorderSide(color: Colors.white24)) : null,
      ),
      child: Row(
        children: [
          Expanded(
            flex: 4, 
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Text(
                nombre.toUpperCase(),
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          ...celdasSets,
          Expanded(
            flex: 2,
            child: Container(
              height: 35,
              color: colorFondoTotal,
              alignment: Alignment.center,
              child: Text(
                "$totalSets",
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BotonSaqueConPelota extends StatelessWidget {
  final bool seleccionado; final bool bloqueado; final Color color; final VoidCallback onTap;
  const _BotonSaqueConPelota({required this.seleccionado, required this.bloqueado, required this.color, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return SizedBox(width: 30, height: 30, child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: seleccionado ? color : Colors.grey[800], disabledBackgroundColor: seleccionado ? color.withOpacity(0.6) : Colors.grey[850], padding: const EdgeInsets.all(0), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))), onPressed: bloqueado ? null : onTap, child: seleccionado ? Image.asset('assets/pelota_donic.jpg', width: 15, height: 15, fit: BoxFit.cover) : const SizedBox()));
  }
}

class _BotonJugador extends StatelessWidget {
  final Color color; final String label; final VoidCallback onSumar; final VoidCallback onRestar;
  const _BotonJugador({required this.color, required this.label, required this.onSumar, required this.onRestar});
  @override
  Widget build(BuildContext context) {
    return Expanded(child: Container(color: color, child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [ElevatedButton(style: ElevatedButton.styleFrom(shape: const CircleBorder(), padding: const EdgeInsets.all(25), backgroundColor: Colors.white24), onPressed: onSumar, child: const Icon(Icons.add, size: 100, color: Colors.white70)), const SizedBox(height: 30), ElevatedButton(style: ElevatedButton.styleFrom(shape: const CircleBorder(), padding: const EdgeInsets.all(15), backgroundColor: Colors.black26), onPressed: onRestar, child: const Icon(Icons.remove, size: 40, color: Colors.white70))])));
  }
}

class PantallaTV extends StatelessWidget {
  const PantallaTV({super.key});
  @override
  Widget build(BuildContext context) {
    final ref = FirebaseDatabase.instance.ref("partido");
    return Scaffold(body: StreamBuilder(stream: ref.onValue, builder: (context, snapshot) {
          if (!snapshot.hasData || snapshot.data!.snapshot.value == null) return const Center(child: CircularProgressIndicator());
          final data = Map<String, dynamic>.from(snapshot.data!.snapshot.value as Map);
          final int pA = data['puntosA'] ?? 0; final int pB = data['puntosB'] ?? 0; final int sA = data['setsA'] ?? 0; final int sB = data['setsB'] ?? 0;
          final String nA = data['nombreA'] ?? "JUGADOR A"; final String nB = data['nombreB'] ?? "JUGADOR B"; final bool saqueInicialA = data['saqueInicialA'] ?? true;
          int setActual = sA + sB + 1; bool esSetImpar = (setActual % 2 == 1);
          bool saqueInicialEnEsteSet = esSetImpar ? saqueInicialA : !saqueInicialA; int totalPuntos = pA + pB;
          bool turnoBaseParaA; if (pA >= 10 && pB >= 10) turnoBaseParaA = (totalPuntos % 2 == 0); else turnoBaseParaA = ((totalPuntos ~/ 2) % 2 == 0);
          bool saqueParaA = saqueInicialEnEsteSet ? turnoBaseParaA : !turnoBaseParaA;
          return Row(children: [Expanded(child: _PanelJugador(nombre: nA, puntos: pA, puntosOtro: pB, sets: sA, color: Colors.black, colorEquipo: Colors.blue[800]!, tieneSaque: saqueParaA)), Container(width: 3, color: Colors.white30), Expanded(child: _PanelJugador(nombre: nB, puntos: pB, puntosOtro: pA, sets: sB, color: Colors.black, colorEquipo: Colors.red[800]!, tieneSaque: !saqueParaA))]);
    }));
  }
}

class _PanelJugador extends StatelessWidget {
  final String nombre; final int puntos; final int puntosOtro; final int sets; final Color color; final Color colorEquipo; final bool tieneSaque;
  const _PanelJugador({super.key, required this.nombre, required this.puntos, required this.puntosOtro, required this.sets, required this.color, required this.colorEquipo, required this.tieneSaque});
  Color _getColorPuntos(int puntos, int puntosOtro) { if (puntos >= 11 && (puntos - puntosOtro) >= 2) return Colors.red; else if (puntos >= 10) return Colors.yellow; else return Colors.white; }
  @override
  Widget build(BuildContext context) {
    return Container(color: color, child: Stack(alignment: Alignment.center, children: [Positioned(top: 500, right: 30, child: Container(padding: const EdgeInsets.symmetric(horizontal: 60, vertical: 10), decoration: BoxDecoration(color: colorEquipo, borderRadius: BorderRadius.circular(10)), child: Text("$sets", style: const TextStyle(fontSize: 110, fontWeight: FontWeight.bold, color: Colors.white)))), Column(mainAxisAlignment: MainAxisAlignment.start, children: [const SizedBox(height: 40), Opacity(opacity: tieneSaque ? 1.0 : 0.0, child: Container(decoration: const BoxDecoration(shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black45, blurRadius: 10, offset: Offset(0, 5))]), child: Image.asset('assets/pelota_donic.jpg', width: 60, height: 60))), const SizedBox(height: 10), Text("$puntos", style: TextStyle(fontSize: 280, fontWeight: FontWeight.bold, color: _getColorPuntos(puntos, puntosOtro), height: 1)), Text(nombre.toUpperCase(), style: const TextStyle(fontSize: 45, color: Colors.white70, fontWeight: FontWeight.w300))])]));
  }
}