import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'google_cast_button.dart';

import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,   // Solo vertical normal
    DeviceOrientation.portraitDown, // (Opcional) Vertical invertido
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

// 1. PANTALLA DE SELECCIÓN
class SeleccionModo extends StatelessWidget {
  const SeleccionModo({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.sports_tennis, size: 80, color: Colors.white),
            const SizedBox(height: 40),
            ElevatedButton.icon(
              icon: const Icon(Icons.phone_iphone),
              label: const Text("Mesa de Control", style: TextStyle(fontSize: 20)),
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.all(20)),
              onPressed: () => Navigator.pushNamed(context, '/control'),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              icon: const Icon(Icons.tv),
              label: const Text("Pantalla de Marcador", style: TextStyle(fontSize: 20)),
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.all(20)),
              onPressed: () => Navigator.pushNamed(context, '/tv'),
            ),
          ],
        ),
      ),
    );
  }
}

// 2. PANTALLA CONTROL (IPHONE) - ¡CON BLOQUEO AUTOMÁTICO!
class PantallaControl extends StatefulWidget {
  const PantallaControl({super.key});
  @override
  State<PantallaControl> createState() => _PantallaControlState();
}

class _PantallaControlState extends State<PantallaControl> {
  final DatabaseReference _ref = FirebaseDatabase.instance.ref("partido");
  
  // Controladores de texto para los nombres
  final TextEditingController _nombreAController = TextEditingController();
  final TextEditingController _nombreBController = TextEditingController();

  final FocusNode _focusA = FocusNode();
  final FocusNode _focusB = FocusNode();

  bool _procesando = false;

  @override
  void initState() {
    super.initState();
    // Cargamos los nombres existentes una sola vez al iniciar
    _ref.child('nombreA').get().then((s) { if(s.exists) _nombreAController.text = s.value.toString(); });
    _ref.child('nombreB').get().then((s) { if(s.exists) _nombreBController.text = s.value.toString(); });

    // Vigilante para Jugador 1 (A)
    _focusA.addListener(() {
      // Si perdió el foco (ya no escribe) Y está vacío
      if (!_focusA.hasFocus && _nombreAController.text.trim().isEmpty) {
        _nombreAController.text = "Jugador 1"; // Restaurar texto visual
        actualizarNombre('A', "Jugador 1");    // Guardar en Firebase
      }
    });

    // Vigilante para Jugador 2 (B)
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

  // Función auxiliar para borrar si es el nombre por defecto
  void _limpiarSiEsDefault(TextEditingController controller, String defaultName) {
    if (controller.text == defaultName) {
      controller.clear();
    }
  }

  void actualizarPunto(String equipo, int cantidad) {
    // 1. EL CANDADO (Para evitar clics dobles)
    if (_procesando) return;
    setState(() => _procesando = true);

    // 2. LEEMOS LA SITUACIÓN ACTUAL
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
      
      List<Map<String, dynamic>> historial = [];
      if (data['historialSets'] != null) {
        historial = List<Map<String, dynamic>>.from(
          (data['historialSets'] as List).map((e) => Map<String, dynamic>.from(e as Map))
        );
      }

      // --- CASO A: DESHACER SET (VOLVER AL PASADO) ---
      // Si estamos en 0, apretamos RESTAR (-1), y tenemos historial para recuperar...
      if (cantidad < 0 && ((equipo == 'A' && pA == 0) || (equipo == 'B' && pB == 0))) {
         
         if (historial.isNotEmpty) {
           final ultimoSet = historial.last; // Miramos el último set guardado
           String ganadorUltimo = ultimoSet['ganador'];

           // REGLA: Solo dejamos deshacer si tocas el botón del que GANÓ ese set.
           // (Porque fue su punto el que cerró el set)
           if (equipo == ganadorUltimo) {
             
             historial.removeLast(); // 1. Borramos el set del historial

             // 2. Recuperamos los puntos viejos
             int pARestaurado = ultimoSet['puntosA'];
             int pBRestaurado = ultimoSet['puntosB'];

             // 3. Le restamos 1 al ganador para volver al momento "Match Point" (ej: de 11 baja a 10)
             if (ganadorUltimo == 'A') {
               pARestaurado--; 
               sA--; // Le quitamos el set a A
             } else {
               pBRestaurado--;
               sB--; // Le quitamos el set a B
             }

             // 4. Guardamos todo junto
             _ref.update({
               'puntosA': pARestaurado,
               'puntosB': pBRestaurado,
               'setsA': sA,
               'setsB': sB,
               'historialSets': historial
             }).whenComplete(() => setState(() => _procesando = false));
             return; // ¡Listo! Terminamos por aquí.
           }
         }
         // Si no se cumple lo anterior, liberamos el candado y no hacemos nada
         setState(() => _procesando = false);
         return;
      }

      // --- CASO B: JUGADA NORMAL (SUMAR O RESTAR PUNTOS) ---
      
      // Calculamos cuánto sería el nuevo puntaje
      int nuevoPA = pA;
      int nuevoPB = pB;

      if (equipo == 'A') nuevoPA += cantidad;
      else nuevoPB += cantidad;

      // Protecciones básicas (no bajar de 0)
      if (nuevoPA < 0) nuevoPA = 0;
      if (nuevoPB < 0) nuevoPB = 0;

      // CHEQUEO DE VICTORIA (¿Alguien gana el set ahora?)
      if (nuevoPA >= 11 && (nuevoPA - nuevoPB) >= 2) {
         // Gana A
         historial.add({'ganador': 'A', 'puntosA': nuevoPA, 'puntosB': nuevoPB});
         _ref.update({
           'puntosA': 0, 'puntosB': 0,
           'setsA': sA + 1,
           'historialSets': historial
         }).whenComplete(() => setState(() => _procesando = false));

      } else if (nuevoPB >= 11 && (nuevoPB - nuevoPA) >= 2) {
         // Gana B
         historial.add({'ganador': 'B', 'puntosA': nuevoPA, 'puntosB': nuevoPB});
         _ref.update({
           'puntosA': 0, 'puntosB': 0,
           'setsB': sB + 1,
           'historialSets': historial
         }).whenComplete(() => setState(() => _procesando = false));

      } else {
         // PUNTO NORMAL (Ni set, ni deshacer set)
         _ref.update({
           'puntosA': nuevoPA,
           'puntosB': nuevoPB
         }).whenComplete(() => setState(() => _procesando = false));
      }

    }).catchError((e) {
      // Si falla internet o algo, liberamos el candado
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
      'puntosA': 0, 
      'puntosB': 0, 
      'setsA': 0, 
      'setsB': 0, 
      'historialSets': [], 
      'saqueInicialA': true,
      'nombreA': "Jugador 1",
      'nombreB': "Jugador 2",
    });
  }

  @override
  Widget build(BuildContext context) {
    // 1. DETECTOR DE ORIENTACIÓN (SOLO PARA ESTA PANTALLA)
    final esHorizontal = MediaQuery.of(context).orientation == Orientation.landscape;

    // 2. SI ESTÁ HORIZONTAL -> MOSTRAR AVISO DE BLOQUEO
    if (esHorizontal) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(Icons.screen_lock_portrait, size: 80, color: Colors.white),
              SizedBox(height: 20),
              Text(
                "GIRA TU TELÉFONO",
                style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 10),
              Text(
                "El control solo funciona en vertical",
                style: TextStyle(color: Colors.grey, fontSize: 16),
              ),
            ],
          ),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text("Control de Mesa"),
        actions: [
          // AQUI ESTA EL BOTON NUEVO
          const Padding(
            padding: EdgeInsets.only(right: 10),
            child: GoogleCastButton(), 
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.redAccent), 
            onPressed: reset
          )
        ],          
      ),
      body: StreamBuilder(
        stream: _ref.onValue,
        builder: (context, snapshot) {
          // --- 1. RECUPERAR DATOS ---
          int pA = 0, pB = 0, sA = 0, sB = 0;
          bool saqueInicialA = true;
          String nombreA = "Jugador 1";
          String nombreB = "Jugador 2";
          List<Map<String, dynamic>> historialSets = []; // Lista para el historial

          if (snapshot.hasData && snapshot.data!.snapshot.value != null) {
            final data = Map<String, dynamic>.from(snapshot.data!.snapshot.value as Map);
            pA = data['puntosA'] ?? 0;
            pB = data['puntosB'] ?? 0;
            sA = data['setsA'] ?? 0;
            sB = data['setsB'] ?? 0;
            saqueInicialA = data['saqueInicialA'] ?? true;
            nombreA = data['nombreA'] ?? "AZUL";
            nombreB = data['nombreB'] ?? "ROJO";
            
            // Recuperamos el historial
            if (data['historialSets'] != null) {
              historialSets = List<Map<String, dynamic>>.from(
                (data['historialSets'] as List).map((e) => Map<String, dynamic>.from(e as Map))
              );
            }
          }

          // Actualizamos controladores de texto si cambiaron externamente
          if (_nombreAController.text != nombreA) _nombreAController.text = nombreA;
          if (_nombreBController.text != nombreB) _nombreBController.text = nombreB;

          bool bloqueado = (pA + pB) >= 2 || sA > 0 || sB > 0;
          
          // Lógica de Saque
          int totalPuntos = pA + pB;
          int setActual = sA + sB + 1;
          bool esSetImpar = (setActual % 2 == 1);
          bool saqueInicialEnEsteSet = esSetImpar ? saqueInicialA : !saqueInicialA;
          bool turnoBaseParaA;
          if (pA >= 10 && pB >= 10) turnoBaseParaA = (totalPuntos % 2 == 0);
          else turnoBaseParaA = ((totalPuntos ~/ 2) % 2 == 0);
          bool saqueParaA = saqueInicialEnEsteSet ? turnoBaseParaA : !turnoBaseParaA;

          // --- 2. LOGICA DE INVERSIÓN TOTAL ---
          // Si la suma de sets es impar, invertimos TODO (Nombres, Puntos, Historial, Botones)
          bool invertirLados = (sA + sB) % 2 != 0;

          // --- 3. DEFINICIÓN DE BLOQUES ---
          
          // A. BLOQUE SUPERIOR (Nombre y Saque)
          Widget topAzul = Row(children: [
             Expanded(
               child: TextField(
                 controller: _nombreAController,
                 focusNode: _focusA,
                 style: const TextStyle(color: Colors.blueAccent, fontSize: 18),
                 cursorColor: Colors.blueAccent,
                 decoration: const InputDecoration(
                   isDense: true,
                   focusedBorder: UnderlineInputBorder(
                     borderSide: BorderSide(color: Colors.blueAccent, width: 2),
                   ),
                   enabledBorder: UnderlineInputBorder(
                     borderSide: BorderSide(color: Colors.white24),
                   ),
                   hintStyle: TextStyle(color: Colors.white24)
                 ), 
                 onChanged: (v) => actualizarNombre('A', v),
                 onTap: () => _limpiarSiEsDefault(_nombreAController, "Jugador 1"),
               )
             ),
             const SizedBox(width: 5),
             _BotonSaqueConPelota(seleccionado: saqueInicialA, bloqueado: bloqueado, color: Colors.blue[800]!, onTap: () => cambiarSaqueInicial(true)),
          ]);
          Widget topRojo = Row(children: [
             Expanded(
               child: TextField(
                 controller: _nombreBController,
                 focusNode: _focusB,
                 style: const TextStyle(color: Colors.redAccent, fontSize: 18),
                 cursorColor: Colors.redAccent,
                 decoration: const InputDecoration(
                   isDense: true,
                   focusedBorder: UnderlineInputBorder(
                     borderSide: BorderSide(color: Colors.redAccent, width: 2),
                   ),
                   enabledBorder: UnderlineInputBorder(
                     borderSide: BorderSide(color: Colors.white24),
                   ),
                   hintStyle: TextStyle(color: Colors.white24)
                 ), 
                 onChanged: (v) => actualizarNombre('B', v),
                 onTap: () => _limpiarSiEsDefault(_nombreBController, "Jugador 2"),
               )
             ),
             const SizedBox(width: 5),
             _BotonSaqueConPelota(seleccionado: !saqueInicialA, bloqueado: bloqueado, color: Colors.red[800]!, onTap: () => cambiarSaqueInicial(false)),
          ]);

          // B. BLOQUE MEDIO (Marcador y Sets)
          Widget scoreAzul = Column(children: [
             Text("$pA", style: const TextStyle(color: Colors.white, fontSize: 60, height: 1, fontWeight: FontWeight.bold)), 
             Text("SETS: $sA", style: const TextStyle(color: Colors.blueAccent, fontSize: 20, fontWeight: FontWeight.bold))
          ]);
          Widget scoreRojo = Column(children: [
             Text("$pB", style: const TextStyle(color: Colors.white, fontSize: 60, height: 1, fontWeight: FontWeight.bold)), 
             Text("SETS: $sB", style: const TextStyle(color: Colors.redAccent, fontSize: 20, fontWeight: FontWeight.bold))
          ]);

          // C. BLOQUE INFERIOR (Botones Gigantes)
          Widget botonAzul = _BotonJugador(color: Colors.blue[900]!, label: "AZUL", onSumar: () => actualizarPunto('A', 1), onRestar: () => actualizarPunto('A', -1));
          Widget botonRojo = _BotonJugador(color: Colors.red[900]!, label: "ROJO", onSumar: () => actualizarPunto('B', 1), onRestar: () => actualizarPunto('B', -1));

          // ELEMENTOS FIJOS
          Widget separadorVS = const Padding(padding: EdgeInsets.symmetric(horizontal: 8.0), child: Text("VS", style: TextStyle(color: Colors.grey, fontSize: 10)));
          // Determinar dirección visual de la flecha
          // Si saca A y NO están invertidos (A a la izq) -> Flecha Izquierda
          // Si saca B y SÍ están invertidos (B a la izq) -> Flecha Izquierda
          // En cualquier otro caso -> Flecha Derecha
          bool flechaIzquierda = (saqueParaA == !invertirLados);

          Widget indicadorSaque = Container(
             width: 65, // ANCHO FIJO: Para que la caja no cambie de tamaño al cambiar el ícono
             height: 38, // ALTO FIJO
             alignment: Alignment.center, // Centramos el icono
             decoration: BoxDecoration(
               color: Colors.grey[900], 
               border: Border.all(color: saqueParaA ? Colors.blueAccent : Colors.redAccent, width: 2), 
               borderRadius: BorderRadius.circular(30)
             ),
             child: Icon(
               flechaIzquierda ? Icons.arrow_back : Icons.arrow_forward,
               color: Colors.white,
               size: 26,
               shadows: const [
                 Shadow(color: Colors.white, offset: Offset(0.5, 0)),
                 Shadow(color: Colors.white, offset: Offset(-0.5, 0)),
                 Shadow(color: Colors.white, offset: Offset(0, 0.5)),
                 Shadow(color: Colors.white, offset: Offset(0, -0.5)),
               ],
             ),
          );

          return Column(
            children: [
              // 1. FILA NOMBRES (INVERTIBLE)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                child: Row(
                  children: [
                    Expanded(child: invertirLados ? topRojo : topAzul),
                    separadorVS,
                    Expanded(child: invertirLados ? topAzul : topRojo),
                  ],
                ),
              ),

              // 2. HISTORIAL DE SETS (¡AQUÍ ESTÁ!)
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Container(
                  height: 82,
                  width: double.infinity,
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.grey[900],
                    border: Border.all(color: Colors.white24, width: 1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (historialSets.isEmpty)
                        const Center(child: Text("Sin sets jugados", style: TextStyle(color: Colors.white38, fontSize: 14)))
                      else
                        Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 5,
                          runSpacing: 5,
                          children: historialSets.asMap().entries.map((entry) {
                            int index = entry.key + 1;
                            Map<String, dynamic> set = entry.value;
                            int pA_set = set['puntosA'] ?? 0;
                            int pB_set = set['puntosB'] ?? 0;
                            bool ganaA = set['ganador'] == 'A';
                            
                            // TRUCO: Si invertimos lados, mostramos "PuntosB - PuntosA" para que coincida con lo que ves
                            String resultadoTexto = invertirLados 
                                ? "$pB_set-$pA_set" 
                                : "$pA_set-$pB_set";

                            return Container(
                              width: 90,
                              padding: const EdgeInsets.symmetric(vertical: 5),
                              decoration: BoxDecoration(
                                color: ganaA ? Colors.blue[900] : Colors.red[900],
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: ganaA ? Colors.blueAccent : Colors.redAccent, width: 1),
                              ),
                              child: Text(
                                "Set $index: $resultadoTexto",
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                              ),
                            );
                          }).toList(),
                        ),
                    ],
                  ),
                ),
              ),

              // 3. FILA MARCADOR CENTRAL (INVERTIBLE)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    invertirLados ? scoreRojo : scoreAzul,
                    indicadorSaque, 
                    invertirLados ? scoreAzul : scoreRojo,
                  ],
                ),
              ),

              // 4. FILA BOTONES GIGANTES (INVERTIBLE)
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: invertirLados 
                    ? [botonRojo, botonAzul] 
                    : [botonAzul, botonRojo], 
                ),
              ),
            ],
          );
        }
      ),
    );
  }
}

// Widget para botón de saque cuadrado con pelota
class _BotonSaqueConPelota extends StatelessWidget {
  final bool seleccionado;
  final bool bloqueado;
  final Color color;
  final VoidCallback onTap;

  const _BotonSaqueConPelota({
    required this.seleccionado,
    required this.bloqueado,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 30,
      height: 30,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: seleccionado ? color : Colors.grey[800],
          disabledBackgroundColor: seleccionado ? color.withOpacity(0.6) : Colors.grey[850],
          padding: const EdgeInsets.all(0),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        onPressed: bloqueado ? null : onTap,
        child: seleccionado
            ? Image.asset('assets/pelota_donic.jpg', width: 15, height: 15, fit: BoxFit.cover)
            : const SizedBox(),
      ),
    );
  }
}

// Widget auxiliar para el botón de saque con tamaño fijo
class _BotonSaqueFijo extends StatelessWidget {
  final String label;
  final bool seleccionado;
  final bool bloqueado;
  final Color color;
  final VoidCallback onTap;

  const _BotonSaqueFijo({
    required this.label,
    required this.seleccionado,
    required this.bloqueado,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 120, // ANCHO FIJO: No cambia si aparece el tilde
      height: 45, // ALTO FIJO
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          // Si está seleccionado, usa su color. Si no, gris oscuro.
          backgroundColor: seleccionado ? color : Colors.grey[800],
          // Si está bloqueado, bajamos la opacidad visualmente
          disabledBackgroundColor: seleccionado ? color.withOpacity(0.6) : Colors.grey[850],
          disabledForegroundColor: Colors.white60,
          padding: const EdgeInsets.symmetric(horizontal: 5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        // Si está bloqueado, pasamos null para deshabilitar el click
        onPressed: bloqueado ? null : onTap,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
            // Mostrar tilde solo si está seleccionado
            if (seleccionado) ...[
              const SizedBox(width: 5),
              const Icon(Icons.check, size: 18),
            ]
          ],
        ),
      ),
    );
  }
}

class _BotonJugador extends StatelessWidget {
  final Color color; final String label; final VoidCallback onSumar; final VoidCallback onRestar;
  const _BotonJugador({required this.color, required this.label, required this.onSumar, required this.onRestar});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        color: color,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
               style: ElevatedButton.styleFrom(shape: const CircleBorder(), padding: const EdgeInsets.all(25), backgroundColor: Colors.white24),
               onPressed: onSumar, 
               child: const Icon(Icons.add, size: 100, color: Colors.white70)
            ),
            const SizedBox(height: 30),
            ElevatedButton(
               style: ElevatedButton.styleFrom(shape: const CircleBorder(), padding: const EdgeInsets.all(15), backgroundColor: Colors.black26),
               onPressed: onRestar, 
               child: const Icon(Icons.remove, size: 40, color: Colors.white70)
            )
          ],
        ),
      ),
    );
  }
}

// 3. PANTALLA TV - Lógica de puntos y sets
class PantallaTV extends StatelessWidget {
  const PantallaTV({super.key});

  @override
  Widget build(BuildContext context) {
    final ref = FirebaseDatabase.instance.ref("partido");

    return Scaffold(
      body: StreamBuilder(
        stream: ref.onValue,
        builder: (context, snapshot) {
          if (!snapshot.hasData || snapshot.data!.snapshot.value == null) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = Map<String, dynamic>.from(snapshot.data!.snapshot.value as Map);
          
          final int pA = data['puntosA'] ?? 0;
          final int pB = data['puntosB'] ?? 0;
          final int sA = data['setsA'] ?? 0; // <--- Nuevo: Sets Azul
          final int sB = data['setsB'] ?? 0; // <--- Nuevo: Sets Rojo
          final String nA = data['nombreA'] ?? "JUGADOR A";
          final String nB = data['nombreB'] ?? "JUGADOR B";
          final bool saqueInicialA = data['saqueInicialA'] ?? true;
          
          int setActual = sA + sB + 1;  // Set en el que estamos jugando
          bool esSetImpar = (setActual % 2 == 1);  // true si set es impar (1, 3, 5...)
          
          // Determinar quién saca primero EN ESTE SET
          bool saqueInicialEnEsteSet = esSetImpar ? saqueInicialA : !saqueInicialA;
          
          int totalPuntos = pA + pB;
          bool turnoBaseParaA; 
          
          if (pA >= 10 && pB >= 10) {
             turnoBaseParaA = (totalPuntos % 2 == 0);
          } else {
            turnoBaseParaA = ((totalPuntos ~/ 2) % 2 == 0);
          }

          bool saqueParaA = saqueInicialEnEsteSet ? turnoBaseParaA : !turnoBaseParaA;

          return Row(
            children: [
              // LADO AZUL
              Expanded(child: _PanelJugador(
                nombre: nA, puntos: pA, puntosOtro: pB, sets: sA, color: Colors.black, colorEquipo: Colors.blue[800]!, tieneSaque: saqueParaA
              )),
              // LÍNEA DE SEPARACIÓN
              Container(width: 3, color: Colors.white30),
              // LADO ROJO
              Expanded(child: _PanelJugador(
                nombre: nB, puntos: pB, puntosOtro: pA, sets: sB, color: Colors.black, colorEquipo: Colors.red[800]!, tieneSaque: !saqueParaA
              )),
            ],
          );
        },
      ),
    );
  }
}

class _PanelJugador extends StatelessWidget {
  final String nombre; final int puntos; final int puntosOtro; final int sets; final Color color; final Color colorEquipo; final bool tieneSaque;
  const _PanelJugador({super.key, required this.nombre, required this.puntos, required this.puntosOtro, required this.sets, required this.color, required this.colorEquipo, required this.tieneSaque});

  Color _getColorPuntos(int puntos, int puntosOtro) {
    if (puntos >= 11 && (puntos - puntosOtro) >= 2) {
      return Colors.red;
    } else if (puntos >= 10) {
      return Colors.yellow;
    } else {
      return Colors.white;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: color,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // MARCADOR DE SETS
          Positioned(
            top: 500,
            right: 30,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 60, vertical: 10),
              decoration: BoxDecoration(
                color: colorEquipo,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text("$sets", style: const TextStyle(fontSize: 110, fontWeight: FontWeight.bold, color: Colors.white)),
            ),
          ),
          
          Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              const SizedBox(height: 40),
              // PELOTA DONIC
              Opacity(
                opacity: tieneSaque ? 1.0 : 0.0,
                child: Container(
                  decoration: const BoxDecoration(shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black45, blurRadius: 10, offset: Offset(0, 5))]),
                  child: Image.asset('assets/pelota_donic.jpg', width: 60, height: 60),
                ),
              ),
              const SizedBox(height: 10),
              // PUNTOS
              Text("$puntos", style: TextStyle(fontSize: 280, fontWeight: FontWeight.bold, color: _getColorPuntos(puntos, puntosOtro), height: 1)),
              // NOMBRE
              Text(nombre.toUpperCase(), style: const TextStyle(fontSize: 45, color: Colors.white70, fontWeight: FontWeight.w300)),
            ],
          ),
        ],
      ),
    );
  }
}