import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';

// --- CONFIGURACIÓN DE FIREBASE (WEB) ---
// Obtén estos datos en: Firebase Console > Configuración del proyecto > General > Tu app > Web (</>)
const firebaseOptions = FirebaseOptions(
  apiKey: "AIzaSyAyh0oULCsxC7OAeac2np-MF4bpmSsHFmU", 
  appId: "1:28038778526:web:379d25e219058e1cb9358f", 
  messagingSenderId: "28038778526", 
  projectId: "marcadorpingpong",
  databaseURL: "https://marcadorpingpong-default-rtdb.firebaseio.com" // ¡Importante!
);



void main() async {
  WidgetsFlutterBinding.ensureInitialized();
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
              label: const Text("SOY EL IPHONE (Control)", style: TextStyle(fontSize: 20)),
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.all(20)),
              onPressed: () => Navigator.pushNamed(context, '/control'),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              icon: const Icon(Icons.tv),
              label: const Text("SOY LA TV (Pantalla)", style: TextStyle(fontSize: 20)),
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

  @override
  void initState() {
    super.initState();
    // Cargamos los nombres existentes una sola vez al iniciar
    _ref.child('nombreA').get().then((s) { if(s.exists) _nombreAController.text = s.value.toString(); });
    _ref.child('nombreB').get().then((s) { if(s.exists) _nombreBController.text = s.value.toString(); });
  }

  void actualizarPunto(String equipo, int cantidad) {
    _ref.child('puntos$equipo').runTransaction((mutableData) {
      int valorActual = (mutableData as int?) ?? 0;
      int nuevoValor = valorActual + cantidad;
      return Transaction.success(nuevoValor < 0 ? 0 : nuevoValor);
    }).then((_) {
      // Después de actualizar, verificar si se alcanzó la condición ganadora
      _ref.once().then((event) {
        if (event.snapshot.value != null) {
          final data = Map<String, dynamic>.from(event.snapshot.value as Map);
          final pA = data['puntosA'] ?? 0;
          final pB = data['puntosB'] ?? 0;
          
          // Si A gana el set (>= 11 puntos y diferencia >= 2)
          if (pA >= 11 && (pA - pB) >= 2) {
            // Guardar en el histórico
            List<Map<String, dynamic>> historial = [];
            if (data['historialSets'] != null) {
              historial = List<Map<String, dynamic>>.from(
                (data['historialSets'] as List).map((e) => Map<String, dynamic>.from(e as Map))
              );
            }
            historial.add({
              'ganador': 'A',
              'puntosA': pA,
              'puntosB': pB,
            });
            
            _ref.update({
              'setsA': (data['setsA'] ?? 0) + 1,
              'lastWinningStateA': {'puntosA': pA, 'puntosB': pB},
              'historialSets': historial,
              'puntosA': 0,
              'puntosB': 0,
            });
          }
          // Si B gana el set (>= 11 puntos y diferencia >= 2)
          else if (pB >= 11 && (pB - pA) >= 2) {
            // Guardar en el histórico
            List<Map<String, dynamic>> historial = [];
            if (data['historialSets'] != null) {
              historial = List<Map<String, dynamic>>.from(
                (data['historialSets'] as List).map((e) => Map<String, dynamic>.from(e as Map))
              );
            }
            historial.add({
              'ganador': 'B',
              'puntosA': pA,
              'puntosB': pB,
            });
            
            _ref.update({
              'setsB': (data['setsB'] ?? 0) + 1,
              'lastWinningStateB': {'puntosA': pA, 'puntosB': pB},
              'historialSets': historial,
              'puntosA': 0,
              'puntosB': 0,
            });
          }
          // Si se resta de 0 y hay un estado anterior guardado, restaurarlo
          else if ((equipo == 'A' && pA == 0 && cantidad < 0) ||
                   (equipo == 'B' && pB == 0 && cantidad < 0)) {
            final lastStateA = data['lastWinningStateA'] as Map?;
            final lastStateB = data['lastWinningStateB'] as Map?;
            
            if (lastStateA != null) {
              // Restaurar el último estado ganador y restar un set a A
              // También eliminar el último elemento del histórico
              List<Map<String, dynamic>> historial = [];
              if (data['historialSets'] != null) {
                historial = List<Map<String, dynamic>>.from(
                  (data['historialSets'] as List).map((e) => Map<String, dynamic>.from(e as Map))
                );
                if (historial.isNotEmpty) {
                  historial.removeLast();
                }
              }
              
              _ref.update({
                'puntosA': lastStateA['puntosA'] ?? pA,
                'puntosB': lastStateA['puntosB'] ?? pB,
                'setsA': ((data['setsA'] ?? 0) - 1).clamp(0, 999),
                'historialSets': historial,
                'lastWinningStateA': null,
              });
            } else if (lastStateB != null) {
              // Restaurar el último estado ganador y restar un set a B
              // También eliminar el último elemento del histórico
              List<Map<String, dynamic>> historial = [];
              if (data['historialSets'] != null) {
                historial = List<Map<String, dynamic>>.from(
                  (data['historialSets'] as List).map((e) => Map<String, dynamic>.from(e as Map))
                );
                if (historial.isNotEmpty) {
                  historial.removeLast();
                }
              }
              
              _ref.update({
                'puntosA': lastStateB['puntosA'] ?? pA,
                'puntosB': lastStateB['puntosB'] ?? pB,
                'setsB': ((data['setsB'] ?? 0) - 1).clamp(0, 999),
                'historialSets': historial,
                'lastWinningStateB': null,
              });
            }
          }
        }
      });
    });
  }

  void actualizarNombre(String equipo, String nombre) {
    _ref.update({'nombre$equipo': nombre});
  }
  
  void cambiarSaqueInicial(bool esA) {
    _ref.update({'saqueInicialA': esA});
  }

  void reset() {
    _ref.update({'puntosA': 0, 'puntosB': 0, 'setsA': 0, 'setsB': 0, 'historialSets': [], 'saqueInicialA': true});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Control de Mesa"),
        actions: [IconButton(icon: const Icon(Icons.refresh, color: Colors.redAccent), onPressed: reset)],
      ),
      // Usamos StreamBuilder aquí también para reaccionar a los puntos en tiempo real
      body: StreamBuilder(
        stream: _ref.onValue,
        builder: (context, snapshot) {
          // Datos por defecto si aún no carga
          int pA = 0;
          int pB = 0;
          int sA = 0;
          int sB = 0;
          bool saqueInicialA = true;
          String nombreA = "AZUL";
          String nombreB = "ROJO";

          if (snapshot.hasData && snapshot.data!.snapshot.value != null) {
            final data = Map<String, dynamic>.from(snapshot.data!.snapshot.value as Map);
            pA = data['puntosA'] ?? 0;
            pB = data['puntosB'] ?? 0;
            sA = data['setsA'] ?? 0;
            sB = data['setsB'] ?? 0;
            saqueInicialA = data['saqueInicialA'] ?? true;
            nombreA = data['nombreA'] ?? "AZUL";
            nombreB = data['nombreB'] ?? "ROJO";
          }

          // Lógica de bloqueo: Si hay 2 o más puntos sumados, o si hay sets ganados, se bloquea.
          bool bloqueado = (pA + pB) >= 2 || sA > 0 || sB > 0;
          
          // --- LÓGICA DE TURNO DE SAQUE (igual que en PantallaTV) ---
          int totalPuntos = pA + pB;
          bool turnoBaseParaA;
          if (pA >= 10 && pB >= 10) {
            turnoBaseParaA = (totalPuntos % 2 == 0);
          } else {
            turnoBaseParaA = ((totalPuntos ~/ 2) % 2 == 0);
          }
          bool saqueParaA = saqueInicialA ? turnoBaseParaA : !turnoBaseParaA;
          
          // --- EXTRAER HISTÓRICO ---
          List<Map<String, dynamic>> historialSets = [];
          if (snapshot.hasData && snapshot.data!.snapshot.value != null) {
            final data = Map<String, dynamic>.from(snapshot.data!.snapshot.value as Map);
            if (data['historialSets'] != null) {
              historialSets = List<Map<String, dynamic>>.from(
                (data['historialSets'] as List).map((e) => Map<String, dynamic>.from(e as Map))
              );
            }
          }

          return Column(
            children: [
              // --- SECCIÓN NOMBRES ---
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    SizedBox(
                      width: 300, 
                      child: TextField(
                      controller: _nombreAController,
                      style: const TextStyle(color: Colors.blueAccent),
                      decoration: const InputDecoration(labelText: "Nombre Azul", prefixIcon: Icon(Icons.person, color: Colors.blue)),
                      onChanged: (v) => actualizarNombre('A', v),
                    )),
                    // BOTÓN SAQUE AZUL
                    _BotonSaqueConPelota(
                      seleccionado: saqueInicialA,
                      bloqueado: bloqueado,
                      color: Colors.blue[800]!,
                      onTap: () => cambiarSaqueInicial(true),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      width: 300,
                      child: TextField(
                      controller: _nombreBController,
                      style: const TextStyle(color: Colors.redAccent),
                      decoration: const InputDecoration(labelText: "Nombre Rojo", prefixIcon: Icon(Icons.person, color: Colors.red)),
                      onChanged: (v) => actualizarNombre('B', v),
                    )),
                    // BOTÓN SAQUE ROJO
                    _BotonSaqueConPelota(
                      seleccionado: !saqueInicialA,
                      bloqueado: bloqueado,
                      color: Colors.red[800]!,
                      onTap: () => cambiarSaqueInicial(false),
                    ),
                  ],
                ),
              ),
              // --- HISTÓRICO DE SETS ---
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Container(
                  constraints: const BoxConstraints(minHeight: 65), 
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[900],
                    border: Border.all(color: Colors.white24, width: 1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    // CAMBIO: Center tanto vertical como horizontalmente
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center, 
                    children: [
                      if (historialSets.isEmpty)
                        const Center(
                          child: Text(
                            "Sin sets jugados",
                            style: TextStyle(color: Colors.white38, fontSize: 14),
                          ),
                        )
                      else
                        // Wrap ahora sí se centrará porque su padre (Column) lo permite
                        Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 8,
                          runSpacing: 8,
                          children: historialSets.asMap().entries.map((entry) {
                            int index = entry.key + 1;
                            Map<String, dynamic> set = entry.value;
                            int pA_set = set['puntosA'] ?? 0;
                            int pB_set = set['puntosB'] ?? 0;
                            bool ganaA = set['ganador'] == 'A';
                            
                            return Container(
                              width: 100,
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              decoration: BoxDecoration(
                                color: ganaA ? Colors.blue[900] : Colors.red[900],
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: ganaA ? Colors.blueAccent : Colors.redAccent, width: 1),
                              ),
                              child: Text(
                                "Set $index: $pA_set-$pB_set",
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.white, 
                                  fontSize: 14, 
                                  fontWeight: FontWeight.w600
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                    ],
                  ),
                ),
              ),
              // --- MARCADOR DE PUNTAJES, SETS Y SAQUE ---
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // PUNTAJE Y SETS AZUL
                    Row(
                      children: [
                        Text("$pA", style: const TextStyle(color: Colors.white, fontSize: 70, fontWeight: FontWeight.bold)),
                        const SizedBox(width: 50),
                        Text("$sA", style: const TextStyle(color: Colors.blueAccent, fontSize: 50, fontWeight: FontWeight.bold)),
                      ],
                    ),
              // --- INDICADOR DE QUIEN SACA ---
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Container(
                  width: 200,
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey[900],
                    border: Border.all(color: saqueParaA ? Colors.blueAccent : Colors.redAccent, width: 2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('SACA: ${saqueParaA ? nombreA : nombreB}', style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold))
                    ],
                  ),
                ),
              ),
                    // PUNTAJE Y SETS ROJO
                    Row(
                      children: [
                        Text("$pB", style: const TextStyle(color: Colors.white, fontSize: 70, fontWeight: FontWeight.bold)),
                        const SizedBox(width: 50),
                        Text("$sB", style: const TextStyle(color: Colors.redAccent, fontSize: 50, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ],
                ),
              ),
              
              // --- BOTONES DE PUNTOS ---
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _BotonJugador(color: Colors.blue[900]!, label: "AZUL", onSumar: () => actualizarPunto('A', 1), onRestar: () => actualizarPunto('A', -1)),
                    _BotonJugador(color: Colors.red[900]!, label: "ROJO", onSumar: () => actualizarPunto('B', 1), onRestar: () => actualizarPunto('B', -1)),
                  ],
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
      width: 60,
      height: 60,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: seleccionado ? color : Colors.grey[800],
          disabledBackgroundColor: seleccionado ? color.withOpacity(0.6) : Colors.grey[850],
          padding: const EdgeInsets.all(0),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        onPressed: bloqueado ? null : onTap,
        child: seleccionado
            ? Image.asset('assets/pelota_donic.jpg', width: 40, height: 40, fit: BoxFit.cover)
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
               child: const Icon(Icons.add, size: 140, color: Colors.white70)
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
          
          int totalPuntos = pA + pB;
          bool turnoBaseParaA; 
          
          if (pA >= 10 && pB >= 10) {
             turnoBaseParaA = (totalPuntos % 2 == 0);
          } else {
            turnoBaseParaA = ((totalPuntos ~/ 2) % 2 == 0);
          }

          bool saqueParaA = saqueInicialA ? turnoBaseParaA : !turnoBaseParaA;

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