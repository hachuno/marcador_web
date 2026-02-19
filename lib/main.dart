import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'dart:math'; 
import 'google_cast_button.dart';
import 'firebase_options.dart';

// Importamos tu diseño visual
import 'tv_scoreboard.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  await Firebase.initializeApp(options: firebaseOptions);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Marcador Pro Torneo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: Colors.black,
        colorScheme: const ColorScheme.dark(primary: Colors.blueAccent),
        dialogTheme: DialogThemeData(
          backgroundColor: Colors.grey[900],
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
      initialRoute: '/',
      onGenerateRoute: (settings) {
        if (settings.name == '/control') {
          final args = settings.arguments as Map<String, dynamic>;
          return MaterialPageRoute(
            builder: (context) => PantallaControl(firebasePath: args['path']),
          );
        }
        if (settings.name == '/tv_torneo') {
          final args = settings.arguments as Map<String, dynamic>;
          return MaterialPageRoute(
            builder: (context) => PantallaTVTorneo(
              clubKey: args['clubKey'], 
              mesasCount: args['mesas'],
            ),
          );
        }
        return null;
      },
      routes: {
        '/': (context) => const SeleccionModo(),
      },
    );
  }
}

// ==========================================
// UTILIDADES
// ==========================================
class PasswordGenerator {
  static const List<String> palabras = [
    "perro", "gatos", "tigre", "papel", "libro", "playa", "campo", "fuego",
    "audio", "video", "silla", "mesas", "lapiz", "raton", "boton", "gafas",
    "cielo", "nubes", "plato", "virus", "reloj", "luces", "pared", "suelo",
    "pasto", "arbol", "fruta", "limon", "melon", "barco", "avion", "coche",
    "rueda", "motor", "golpe", "salto", "correr", "jugar", "ganar", "punto"
  ];

  static String generar() {
    final random = Random();
    String p1 = palabras[random.nextInt(palabras.length)];
    String p2 = palabras[random.nextInt(palabras.length)];
    return "$p1.$p2";
  }
}

// Formateador para forzar mayúsculas visualmente mientras se escribe
class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    return TextEditingValue(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}

String sanitizeClubKey(String input) {
  return input.trim().toUpperCase().replaceAll(RegExp(r'[.#$\[\]]'), '');
}

// ==========================================
// 1. PANTALLA DE SELECCIÓN (MENU PRINCIPAL)
// ==========================================
class SeleccionModo extends StatefulWidget {
  const SeleccionModo({super.key});

  @override
  State<SeleccionModo> createState() => _SeleccionModoState();
}

class _SeleccionModoState extends State<SeleccionModo> {
  final TextEditingController _clubController = TextEditingController();
  final TextEditingController _passwordInputController = TextEditingController();
  
  // Lista de clubes cargados desde Firebase para los dropdowns
  List<Map<String, String>> _clubesDisponibles = [];
  bool _cargandoClubes = false;

  int _mesasTorneoSeleccionadas = 6; // DEFAULT 6

  @override
  void dispose() {
    _clubController.dispose();
    _passwordInputController.dispose();
    super.dispose();
  }

  // Método para buscar clubes existentes en la base de datos
  Future<void> _cargarClubesFromFirebase() async {
    setState(() => _cargandoClubes = true);
    _clubesDisponibles.clear();
    try {
      final snapshot = await FirebaseDatabase.instance.ref("torneos").get();
      if (snapshot.exists) {
        final data = Map<String, dynamic>.from(snapshot.value as Map);
        data.forEach((key, value) {
          if (value['config'] != null) {
            _clubesDisponibles.add({
              'key': key, // ID interno (ej: CLUBTENIS)
              'nombre': value['config']['nombre'].toString() // Nombre bonito (ej: CLUB TENIS)
            });
          }
        });
      }
    } catch (e) {
      debugPrint("Error cargando clubes: $e");
    } finally {
      setState(() => _cargandoClubes = false);
    }
  }

  // --- LÓGICA: INICIAR TORNEO (CREAR) ---
  void _mostrarDialogoIniciarTorneo() {
    _clubController.clear();
    // Restaurar default 6 al abrir
    _mesasTorneoSeleccionadas = 6; 

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          bool cargando = false;

          return AlertDialog(
            title: const Text("Crear Nuevo Torneo"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _clubController,
                  textCapitalization: TextCapitalization.characters,
                  // Forzamos mayúsculas al escribir
                  inputFormatters: [UpperCaseTextFormatter()],
                  decoration: const InputDecoration(
                    labelText: "Nombre del Club",
                    hintText: "Ej: SPIN TENIS"
                  ),
                ),
                const SizedBox(height: 20),
                const Text("Cantidad de Mesas:"),
                const SizedBox(height: 10),
                if (cargando) 
                  const Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator())
                else
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [2, 4, 6, 8].map((e) {
                      return ChoiceChip(
                        label: Text(e.toString()),
                        selected: _mesasTorneoSeleccionadas == e,
                        onSelected: (bool selected) {
                          setStateDialog(() => _mesasTorneoSeleccionadas = e);
                        },
                      );
                    }).toList(),
                  ),
              ],
            ),
            actions: [
              if (!cargando) TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancelar")),
              if (!cargando)
                ElevatedButton(
                  onPressed: () async {
                    if (_clubController.text.isNotEmpty) {
                      setStateDialog(() => cargando = true);
                      try {
                        String passwordGenerada = await _crearEstructuraTorneo(
                          _clubController.text, 
                          _mesasTorneoSeleccionadas
                        );
                        
                        if (context.mounted) {
                          Navigator.pop(context);
                          _mostrarDialogoPassword(passwordGenerada);
                          // Recargamos la lista de clubes para que aparezca en las otras opciones
                          _cargarClubesFromFirebase(); 
                        }
                      } catch (e) {
                        setStateDialog(() => cargando = false);
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
                      }
                    }
                  },
                  child: const Text(
                    "CREAR TORNEO", 
                    style: TextStyle(color: Colors.white70)
                  ),                  
                ),
            ],
          );
        }
      ),
    );
  }

  void _mostrarDialogoPassword(String password) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("¡Torneo Creado!", style: TextStyle(color: Colors.green)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Guarda esta contraseña para iniciar los partidos:"),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: Colors.white12,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.blueAccent)
              ),
              child: SelectableText(
                password,
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 1.5),
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(onPressed: () => Navigator.pop(context), child: const Text("ENTENDIDO"))
        ],
      ),
    );
  }

  Future<String> _crearEstructuraTorneo(String clubInput, int cantidadMesas) async {
    // 1. FORZAR MAYÚSCULAS Y LIMPIAR
    String nombreDisplay = clubInput.trim().toUpperCase();
    String clubKey = sanitizeClubKey(clubInput);
    
    final ref = FirebaseDatabase.instance.ref("torneos/$clubKey");
    
    // 2. VALIDAR EXISTENCIA
    final snapshot = await ref.get();
    if (snapshot.exists) {
      throw "El club '$nombreDisplay' ya existe. Usa otro nombre.";
    }

    // 3. GENERAR PASSWORD
    String password = PasswordGenerator.generar();

    // 4. GUARDAR ESTRUCTURA
    await ref.update({
      'config': {
        'nombre': nombreDisplay,
        'cantidadMesas': cantidadMesas,
        'password': password,
        'fechaCreacion': ServerValue.timestamp,
      }
    });

    for (int i = 1; i <= cantidadMesas; i++) {
      await ref.child("mesa_$i").set({
        'puntosA': 0, 'puntosB': 0,
        'setsA': 0, 'setsB': 0,
        'nombreA': "JUGADOR 1", 'nombreB': "JUGADOR 2",
        'historialSets': [],
        'saqueInicialA': null,
        'maxSets': 3, // Default sets base
      });
    }

    return password;
  }

  // --- LÓGICA: CONTROLAR UN PARTIDO (LOGIN + SETS) ---
  void _mostrarDialogoControlarPartido() async {
    // Cargamos clubes antes de mostrar el diálogo
    await _cargarClubesFromFirebase();

    _passwordInputController.clear();
    
    // Variables de estado
    String? selectedClubKey; // El ID del club seleccionado
    bool loadingConfig = false;
    
    // Datos del club seleccionado
    String realPassword = "";
    int totalMesas = 0;
    
    int mesaSeleccionada = 1;
    int setsSeleccionados = 3; // DEFAULT 3

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          
          // Función para cargar la config específica del club seleccionado
          void fetchClubConfig(String key) async {
             setStateDialog(() => loadingConfig = true);
             try {
                final ref = FirebaseDatabase.instance.ref("torneos/$key/config");
                final snap = await ref.get();
                if (snap.exists) {
                   final data = Map<String, dynamic>.from(snap.value as Map);
                   setStateDialog(() {
                      realPassword = data['password'].toString();
                      totalMesas = int.parse(data['cantidadMesas'].toString());
                      loadingConfig = false;
                      mesaSeleccionada = 1; // Reset mesa al cambiar club
                   });
                }
             } catch (e) {
                setStateDialog(() => loadingConfig = false);
             }
          }

          return AlertDialog(
            title: const Text("Iniciar Partido"),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // PASO 1: Selector de Club
                  const Text("Selecciona el Club:", style: TextStyle(color: Colors.white70)),
                  const SizedBox(height: 5),
                  if (_cargandoClubes)
                    const Center(child: Padding(padding: EdgeInsets.all(8.0), child: CircularProgressIndicator()))
                  else if (_clubesDisponibles.isEmpty)
                     const Padding(
                       padding: EdgeInsets.all(8.0),
                       child: Text("No hay torneos creados.", style: TextStyle(color: Colors.orange)),
                     )
                  else
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(8)),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: selectedClubKey,
                          hint: const Text("Elige un club..."),
                          isExpanded: true,
                          dropdownColor: Colors.grey[850],
                          items: _clubesDisponibles.map((club) {
                            return DropdownMenuItem<String>(
                              value: club['key'],
                              child: Text(club['nombre']!),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setStateDialog(() => selectedClubKey = val);
                              fetchClubConfig(val);
                            }
                          },
                        ),
                      ),
                    ),

                  // Si se seleccionó club y está cargando config
                  if (loadingConfig)
                     const Padding(padding: EdgeInsets.only(top: 20), child: Center(child: CircularProgressIndicator())),

                  // PASO 2: Controles (Solo si ya cargó la config del club)
                  if (selectedClubKey != null && !loadingConfig && totalMesas > 0) ...[
                    const SizedBox(height: 20),
                    const Divider(color: Colors.white24),
                    const SizedBox(height: 10),

                    // Password (YA NO ESTÁ OCULTO)
                    TextField(
                      controller: _passwordInputController,
                      obscureText: false, // NO OCULTAR
                      decoration: const InputDecoration(
                        labelText: "Contraseña del Torneo",
                        prefixIcon: Icon(Icons.lock_open), // Icono abierto para indicar visibilidad
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Selección de Mesa
                    const Text("Seleccionar Mesa:", style: TextStyle(color: Colors.white70)),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: Colors.white10,
                        borderRadius: BorderRadius.circular(8)
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int>(
                          value: mesaSeleccionada,
                          isExpanded: true,
                          dropdownColor: Colors.grey[850],
                          items: List.generate(totalMesas, (index) {
                            int num = index + 1;
                            return DropdownMenuItem(value: num, child: Text("Mesa $num"));
                          }), 
                          onChanged: (val) => setStateDialog(() => mesaSeleccionada = val!)
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),
                    // Selección de Sets (3 o 5)
                    const Text("Modo de Juego:", style: TextStyle(color: Colors.white70)),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: ChoiceChip(
                            label: const Center(child: Text("Mejor de 3")),
                            selected: setsSeleccionados == 3,
                            onSelected: (s) => setStateDialog(() => setsSeleccionados = 3),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ChoiceChip(
                            label: const Center(child: Text("Mejor de 5")),
                            selected: setsSeleccionados == 5,
                            onSelected: (s) => setStateDialog(() => setsSeleccionados = 5),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancelar")),
              // Solo habilitar botón si hay club seleccionado y hay mesas cargadas
              if (selectedClubKey != null && totalMesas > 0)
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[800],
                    foregroundColor: Colors.white70,
                  ),
                  onPressed: () async {
                    // VALIDAR PASSWORD
                    if (_passwordInputController.text.trim() != realPassword) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Contraseña incorrecta"), backgroundColor: Colors.red));
                      return;
                    }

                    String path = "torneos/$selectedClubKey/mesa_$mesaSeleccionada";
                    
                    // Actualizamos maxSets
                    await FirebaseDatabase.instance.ref(path).update({
                      "maxSets": setsSeleccionados
                    });

                    if (context.mounted) {
                      Navigator.pop(context);
                      Navigator.pushNamed(context, '/control', arguments: {'path': path});
                    }
                  },
                  child: const Text("INICIAR PARTIDO"),
                ),
            ],
          );
        }
      ),
    );
  }

  // --- LÓGICA: VER RESULTADOS ONLINE (TV) ---
  void _mostrarDialogoTVTorneo() async {
    await _cargarClubesFromFirebase(); // Cargar lista fresca

    String? selectedClubKey;
    bool buscando = false;

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            title: const Text("Pantalla TV - Torneo"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Selecciona el Club:", style: TextStyle(color: Colors.white70)),
                const SizedBox(height: 10),
                
                 if (_cargandoClubes)
                    const Center(child: Padding(padding: EdgeInsets.all(8.0), child: CircularProgressIndicator()))
                  else if (_clubesDisponibles.isEmpty)
                     const Padding(
                       padding: EdgeInsets.all(8.0),
                       child: Text("No hay torneos disponibles.", style: TextStyle(color: Colors.orange)),
                     )
                  else
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(8)),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: selectedClubKey,
                          hint: const Text("Elige un club..."),
                          isExpanded: true,
                          dropdownColor: Colors.grey[850],
                          items: _clubesDisponibles.map((club) {
                            return DropdownMenuItem<String>(
                              value: club['key'],
                              child: Text(club['nombre']!),
                            );
                          }).toList(),
                          onChanged: (val) {
                            setStateDialog(() => selectedClubKey = val);
                          },
                        ),
                      ),
                    ),

                const SizedBox(height: 15),
                if (buscando) const Center(child: CircularProgressIndicator()),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancelar")),
              if (!buscando && selectedClubKey != null)
                ElevatedButton(
                  onPressed: () {
                    setStateDialog(() => buscando = true);
                    
                    // Consultamos cantidad de mesas para ese club
                    FirebaseDatabase.instance.ref("torneos/$selectedClubKey/config/cantidadMesas").get().then((snapshot) {
                      if (snapshot.exists && snapshot.value != null) {
                        int mesas = int.tryParse(snapshot.value.toString()) ?? 6;
                        if (context.mounted) {
                          Navigator.pop(context);
                          Navigator.pushNamed(context, '/tv_torneo', arguments: {
                            'clubKey': selectedClubKey,
                            'mesas': mesas
                          });
                        }
                      }
                    }).catchError((e) {
                       setStateDialog(() => buscando = false);
                    });
                  },
                  child: const Text(
                    "VER PANTALLA", 
                    style: TextStyle(color: Colors.white70)
                  ),
                ),
            ],
          );
        }
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(30.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.emoji_events, size: 80, color: Colors.amber),
                const SizedBox(height: 20),
                const Center(child: Text("TORNEO PRO", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 2))),
                const SizedBox(height: 40),
        
                _botonMenu(icon: Icons.add_business, text: "CREAR TORNEO", color: Colors.blue[900]!, onTap: _mostrarDialogoIniciarTorneo),
                const SizedBox(height: 20),
                _botonMenu(icon: Icons.sports_tennis, text: "INICIAR PARTIDO", color: Colors.green[800]!, onTap: _mostrarDialogoControlarPartido),
                const SizedBox(height: 20),
                _botonMenu(icon: Icons.tv, text: "PANTALLA TV", color: Colors.purple[800]!, onTap: _mostrarDialogoTVTorneo),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _botonMenu({required IconData icon, required String text, required Color color, required VoidCallback onTap}) {
    return SizedBox(
      height: 60,
      child: ElevatedButton.icon(
        icon: Icon(icon, size: 28),
        label: Text(text, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white70,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        onPressed: onTap,
      ),
    );
  }
}

// ==========================================
// 2. PANTALLA CONTROL (DINÁMICA)
// ==========================================
class PantallaControl extends StatefulWidget {
  final String firebasePath; 
  const PantallaControl({super.key, required this.firebasePath});
  
  @override
  State<PantallaControl> createState() => _PantallaControlState();
}

class _PantallaControlState extends State<PantallaControl> {
  late DatabaseReference _ref;
  final TextEditingController _nombreAController = TextEditingController();
  final TextEditingController _nombreBController = TextEditingController();
  final FocusNode _focusA = FocusNode();
  final FocusNode _focusB = FocusNode();
  bool _procesando = false;

  @override
  void initState() {
    super.initState();
    _ref = FirebaseDatabase.instance.ref(widget.firebasePath);
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
    if (controller.text == defaultName) controller.clear();
  }

  void actualizarPunto(String equipo, int cantidad, bool? saqueLocal) {
    if (cantidad > 0 && saqueLocal == null) {
      _mostrarAlertaSaque(context);
      return; 
    }
    if (_procesando) return;
    setState(() => _procesando = true);

    _ref.once().then((event) {
      if (event.snapshot.value == null) { setState(() => _procesando = false); return; }
      final data = Map<String, dynamic>.from(event.snapshot.value as Map);
      
      int pA = data['puntosA'] ?? 0;
      int pB = data['puntosB'] ?? 0;
      int sA = data['setsA'] ?? 0;
      int sB = data['setsB'] ?? 0;
      int maxSets = data['maxSets'] ?? 3; // Lee la configuración que guardamos al entrar
      int setsParaGanar = (maxSets / 2).ceil();

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

      if (cantidad < 0 && ((equipo == 'A' && pA == 0) || (equipo == 'B' && pB == 0))) {
         if (historial.isNotEmpty) {
           final ultimoSet = historial.last;
           String ganadorUltimo = ultimoSet['ganador'];
           if (equipo == ganadorUltimo) {
             historial.removeLast();
             int pARestaurado = ultimoSet['puntosA'];
             int pBRestaurado = ultimoSet['puntosB'];
             if (ganadorUltimo == 'A') { pARestaurado--; sA--; } else { pBRestaurado--; sB--; }
             _ref.update({'puntosA': pARestaurado, 'puntosB': pBRestaurado, 'setsA': sA, 'setsB': sB, 'historialSets': historial}).whenComplete(() => setState(() => _procesando = false));
             return;
           }
         }
         setState(() => _procesando = false);
         return;
      }

      int nuevoPA = pA; int nuevoPB = pB;
      if (equipo == 'A') nuevoPA += cantidad; else nuevoPB += cantidad;
      if (nuevoPA < 0) nuevoPA = 0; if (nuevoPB < 0) nuevoPB = 0;

      if (nuevoPA >= 11 && (nuevoPA - nuevoPB) >= 2) {
         historial.add({'ganador': 'A', 'puntosA': nuevoPA, 'puntosB': nuevoPB});
         int nuevosSetsA = sA + 1;
         _ref.update({ 'puntosA': 0, 'puntosB': 0, 'setsA': nuevosSetsA, 'historialSets': historial }).whenComplete(() => setState(() => _procesando = false));
      } else if (nuevoPB >= 11 && (nuevoPB - nuevoPA) >= 2) {
         historial.add({'ganador': 'B', 'puntosA': nuevoPA, 'puntosB': nuevoPB});
         int nuevosSetsB = sB + 1;
         _ref.update({ 'puntosA': 0, 'puntosB': 0, 'setsB': nuevosSetsB, 'historialSets': historial }).whenComplete(() => setState(() => _procesando = false));
      } else {
         _ref.update({ 'puntosA': nuevoPA, 'puntosB': nuevoPB }).whenComplete(() => setState(() => _procesando = false));
      }
    }).catchError((e) { setState(() => _procesando = false); });
  }

  void actualizarNombre(String equipo, String nombre) { _ref.update({'nombre$equipo': nombre}); }
  void cambiarSaqueInicial(bool esA) { _ref.update({'saqueInicialA': esA}); }
  void reset() { 
    // Al resetear, mantenemos el maxSets
    _ref.update({ 'puntosA': 0, 'puntosB': 0, 'setsA': 0, 'setsB': 0, 'historialSets': [], 'saqueInicialA': null, 'nombreA': "Jugador 1", 'nombreB': "Jugador 2" }); 
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

  @override
  Widget build(BuildContext context) {
    final esHorizontal = MediaQuery.of(context).orientation == Orientation.landscape;
    if (esHorizontal) return const Scaffold(backgroundColor: Colors.black, body: Center(child: Text("GIRA EL TELÉFONO", style: TextStyle(color: Colors.white))));

    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: Text("Mesa: ${widget.firebasePath.split('_').last}"),
        actions: [
          Padding(padding: const EdgeInsets.only(right: 10), child: SizedBox(width: 40, height: 40, child: GoogleCastButton())),
          IconButton(icon: const Icon(Icons.refresh), onPressed: reset)
        ],          
      ),
      body: StreamBuilder(
        stream: _ref.onValue,
        builder: (context, snapshot) {
            if (!snapshot.hasData || snapshot.data!.snapshot.value == null) return const Center(child: CircularProgressIndicator());
            final data = Map<String, dynamic>.from(snapshot.data!.snapshot.value as Map);
            
            int pA = data['puntosA'] ?? 0; int pB = data['puntosB'] ?? 0;
            int sA = data['setsA'] ?? 0; int sB = data['setsB'] ?? 0;
            String nA = data['nombreA'] ?? "Jugador 1"; String nB = data['nombreB'] ?? "Jugador 2";
            bool? saqueInicialA = data['saqueInicialA'];
            List<Map<String, dynamic>> historial = [];
            if (data['historialSets'] != null) {
               try { final dynamic raw = data['historialSets'];
               if (raw is List) historial = List<Map<String, dynamic>>.from(raw.map((e) => Map<String, dynamic>.from(e as Map)));
               else if (raw is Map) historial = List<Map<String, dynamic>>.from(raw.values.map((e) => Map<String, dynamic>.from(e as Map)));
               } catch (e) { historial = []; }
            }

            if (_nombreAController.text != nA && !_focusA.hasFocus) _nombreAController.text = nA;
            if (_nombreBController.text != nB && !_focusB.hasFocus) _nombreBController.text = nB;

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
            bool flechaIzquierda = (saqueParaA == !invertirLados);

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

            Widget botonAzul = _BotonJugador(color: Colors.blue[900]!, label: "AZUL", onSumar: () => actualizarPunto('A', 1, saqueInicialA), onRestar: () => actualizarPunto('A', -1, saqueInicialA));
            Widget botonRojo = _BotonJugador(color: Colors.red[900]!, label: "ROJO", onSumar: () => actualizarPunto('B', 1, saqueInicialA), onRestar: () => actualizarPunto('B', -1, saqueInicialA));

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
                Padding(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), child: Row(children: [Expanded(child: invertirLados ? topRojo : topAzul), const Padding(padding: EdgeInsets.symmetric(horizontal: 8.0), child: Text("VS", style: TextStyle(color: Colors.grey, fontSize: 10))), Expanded(child: invertirLados ? topAzul : topRojo)])),
                Padding(padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0), child: _TablaPuntuacion(nombreA: nA, nombreB: nB, setsA: sA, setsB: sB, historial: historial)),
                Padding(padding: const EdgeInsets.symmetric(vertical: 10), child: Row(children: [Expanded(child: Center(child: invertirLados ? scoreRojo : scoreAzul)), indicadorSaque, Expanded(child: Center(child: invertirLados ? scoreAzul : scoreRojo))])),
                Expanded(child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: invertirLados ? [botonRojo, botonAzul] : [botonAzul, botonRojo])),
              ],
            );
        }
      )
    );
  }
}

// ==========================================
// 3. PANTALLA TV TORNEO
// ==========================================
class PantallaTVTorneo extends StatelessWidget {
  final String clubKey; // Clave saneada (ej: CLUBTENIS)
  final int mesasCount;

  const PantallaTVTorneo({super.key, required this.clubKey, required this.mesasCount});

  @override
  Widget build(BuildContext context) {
    int columnas = (mesasCount / 2).ceil();
    if (columnas < 1) columnas = 1;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Column(
        children: [
          Expanded(
            child: Row(
              children: List.generate(columnas, (index) {
                int mesaNum = index + 1;
                return Expanded(child: _CeldaMesaConectada(clubKey: clubKey, mesaIndex: mesaNum));
              }),
            ),
          ),
          Expanded(
            child: Row(
              children: List.generate(columnas, (index) {
                int mesaNum = index + 1 + columnas;
                if (mesaNum > mesasCount) return Expanded(child: Container(color: Colors.black)); 
                return Expanded(child: _CeldaMesaConectada(clubKey: clubKey, mesaIndex: mesaNum));
              }),
            ),
          ),
        ],
      ),
    );
  }
}

class _CeldaMesaConectada extends StatelessWidget {
  final String clubKey;
  final int mesaIndex;

  const _CeldaMesaConectada({required this.clubKey, required this.mesaIndex});

  @override
  Widget build(BuildContext context) {
    final ref = FirebaseDatabase.instance.ref("torneos/$clubKey/mesa_$mesaIndex");

    return _CeldaTV(
      nombre: "MESA $mesaIndex",
      child: StreamBuilder(
        stream: ref.onValue,
        builder: (context, snapshot) {
          if (!snapshot.hasData || snapshot.data!.snapshot.value == null) {
            return const TvScoreboard(
               player1Name: "", player2Name: "", player1Score: 0, player2Score: 0, 
               player1Sets: 0, player2Sets: 0, setHistory: [], servingPlayer: null
            );
          }

          final data = Map<String, dynamic>.from(snapshot.data!.snapshot.value as Map);
          
          final int pA = data['puntosA'] ?? 0;
          final int pB = data['puntosB'] ?? 0;
          final int sA = data['setsA'] ?? 0;
          final int sB = data['setsB'] ?? 0;
          final String nA = data['nombreA'] ?? "JUG 1";
          final String nB = data['nombreB'] ?? "JUG 2";
          final bool? saqueInicialA = data['saqueInicialA'];

          List<String> historialFormateado = [];
          if (data['historialSets'] != null) {
            try {
              final dynamic raw = data['historialSets'];
              List<Map<String, dynamic>> listaSets = [];
              if (raw is List) {
                 listaSets = List<Map<String, dynamic>>.from(raw.map((e) => Map<String, dynamic>.from(e as Map)));
              } else if (raw is Map) {
                 listaSets = List<Map<String, dynamic>>.from(raw.values.map((e) => Map<String, dynamic>.from(e as Map)));
              }
              for (var s in listaSets) {
                historialFormateado.add("${s['puntosA']}-${s['puntosB']}");
              }
            } catch (e) { historialFormateado = []; }
          }

          int? quienSaca;
          if (saqueInicialA != null) {
            int totalPuntos = pA + pB;
            int setActual = sA + sB + 1;
            bool esSetImpar = (setActual % 2 == 1);
            bool safeSaque = saqueInicialA;
            bool saqueInicialEnEsteSet = esSetImpar ? safeSaque : !safeSaque;
            bool turnoBaseParaA;
            if (pA >= 10 && pB >= 10) turnoBaseParaA = (totalPuntos % 2 == 0);
            else turnoBaseParaA = ((totalPuntos ~/ 2) % 2 == 0);
            bool saqueParaA = saqueInicialEnEsteSet ? turnoBaseParaA : !turnoBaseParaA;
            quienSaca = saqueParaA ? 1 : 2;
          }

          return FittedBox(
            fit: BoxFit.contain,
            child: SizedBox(
              width: 1000, 
              height: 600,
              child: TvScoreboard(
                player1Name: nA,
                player2Name: nB,
                player1Score: pA,
                player2Score: pB,
                player1Sets: sA,
                player2Sets: sB,
                setHistory: historialFormateado,
                servingPlayer: quienSaca,
              ),
            ),
          );
        }
      ),
    );
  }
}

class _CeldaTV extends StatelessWidget {
  final String nombre;
  final Widget? child;
  const _CeldaTV({required this.nombre, this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(border: Border.all(color: Colors.white24, width: 1)),
      child: Stack(
        children: [
          if (child != null) Padding(padding: const EdgeInsets.only(top: 25.0), child: Center(child: child)),
          Positioned(
            top: 5, left: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(4)),
              child: Text(nombre.toUpperCase(), style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
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