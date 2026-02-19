import 'package:flutter/material.dart';

class TvScoreboard extends StatelessWidget {
  final String player1Name;
  final String player2Name;
  final int player1Score;
  final int player2Score;
  final int player1Sets;
  final int player2Sets;
  final List<String> setHistory;
  final int? servingPlayer; // 1: Jugador 1 (Izq), 2: Jugador 2 (Der)

  const TvScoreboard({
    super.key,
    required this.player1Name,
    required this.player2Name,
    required this.player1Score,
    required this.player2Score,
    required this.player1Sets,
    required this.player2Sets,
    required this.setHistory,
    required this.servingPlayer,
  });

  @override
  Widget build(BuildContext context) {
    if (servingPlayer == null) {
      return Container(
        color: Colors.black,
        child: const Center(
          child: Text(
            "Sin Conexión",
            style: TextStyle(
              color: Colors.white24, 
              fontSize: 100, 
              decoration: TextDecoration.none,
              fontWeight: FontWeight.normal
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // --- 1. Encabezado con Nombres y Saque ---
            _buildHeader(),
            
            const SizedBox(height: 10),
            
            // --- 2. Tabla de Historial (Estilo Control) ---
            // Usamos un Container con altura fija pequeña para que no se expanda gigante
            SizedBox(
              height: 110, 
              child: _buildSetHistoryGrid(),
            ),

            const Spacer(), // Empuja el marcador hacia el centro/abajo

            // --- 3. Puntaje Grande + FLECHA DE SAQUE ---
            _buildBigScoreWithArrow(),
            
            const Spacer(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    bool p1Serving = servingPlayer == 1;
    bool p2Serving = servingPlayer == 2;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // JUGADOR 1
        Row(
          children: [
             Text(
              player1Name.toUpperCase(),
              style: const TextStyle(color: Colors.blueAccent, fontSize: 28, fontWeight: FontWeight.bold),
            ),
            if (p1Serving) ...[
              const SizedBox(width: 10),
              const Icon(Icons.sports_tennis, color: Colors.white, size: 20),
            ]
          ],
        ),
        
        const Text("vs", style: TextStyle(color: Colors.grey, fontSize: 18)),
        
        // JUGADOR 2
        Row(
          children: [
            if (p2Serving) ...[
              const Icon(Icons.sports_tennis, color: Colors.white, size: 20),
              const SizedBox(width: 10),
            ],
            Text(
              player2Name.toUpperCase(),
              style: const TextStyle(color: Colors.redAccent, fontSize: 28, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ],
    );
  }

  // Construye la grilla idéntica a PantallaControl (_TablaPuntuacion)
  Widget _buildSetHistoryGrid() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E), // Gris oscuro background
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        children: [
          // Fila Jugador 1
          Expanded(child: _buildPlayerRow(
            playerIndex: 1, 
            name: player1Name, 
            totalSets: player1Sets,
            baseColor: Colors.blue.shade900,
            highlightColor: Colors.blueAccent.withOpacity(0.4),
            showBottomBorder: true
          )),
          // Fila Jugador 2
          Expanded(child: _buildPlayerRow(
            playerIndex: 2, 
            name: player2Name, 
            totalSets: player2Sets,
            baseColor: Colors.red.shade900,
            highlightColor: Colors.redAccent.withOpacity(0.4),
            showBottomBorder: false
          )),
        ],
      ),
    );
  }

  Widget _buildPlayerRow({
    required int playerIndex,
    required String name,
    required int totalSets,
    required Color baseColor,
    required Color highlightColor,
    required bool showBottomBorder,
  }) {
    // Generamos las 5 celdas de sets
    List<Widget> setCells = List.generate(5, (index) {
      String scoreText = "";
      Color cellBg = Colors.transparent;
      Color textColor = Colors.white38;
      FontWeight weight = FontWeight.normal;

      if (index < setHistory.length) {
        // Parseamos "11-9"
        var parts = setHistory[index].split("-");
        if (parts.length == 2) {
          int s1 = int.parse(parts[0]);
          int s2 = int.parse(parts[1]);
          
          // Score de ESTE jugador
          int myScore = playerIndex == 1 ? s1 : s2;
          int opponentScore = playerIndex == 1 ? s2 : s1;
          scoreText = myScore.toString();

          // Lógica de Ganador de Set (Igual al Control)
          bool IWon = myScore > opponentScore;
          
          if (IWon) {
            cellBg = highlightColor; // Azul o Rojo translúcido
            textColor = Colors.white;
            weight = FontWeight.bold;
          }
        }
      }

      return Expanded(
        flex: 1,
        child: Container(
          decoration: BoxDecoration(
            color: cellBg, // El color de fondo si ganó
            border: const Border(left: BorderSide(color: Colors.white10)),
          ),
          alignment: Alignment.center,
          child: Text(
            scoreText, 
            style: TextStyle(color: textColor, fontWeight: weight, fontSize: 38)
          ),
        ),
      );
    });

    return Container(
      decoration: BoxDecoration(
        border: showBottomBorder ? const Border(bottom: BorderSide(color: Colors.white24)) : null,
      ),
      child: Row(
        children: [
          // Nombre (Ocupa más espacio)
          Expanded(
            flex: 3, 
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0),
              child: Text(
                name.toUpperCase(),
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 38),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          // Celdas de Sets
          ...setCells,
          // Total Sets (Cuadro Sólido Final)
          Expanded(
            flex: 2,
            child: Container(
              color: baseColor,
              alignment: Alignment.center,
              child: Text(
                totalSets.toString(),
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 38),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBigScoreWithArrow() {
    bool saqueParaA = servingPlayer == 1; 
    Color colorBorde = saqueParaA ? Colors.blueAccent : Colors.redAccent;
    IconData iconoFlecha = saqueParaA ? Icons.arrow_back : Icons.arrow_forward;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // Score 1
        Text(
          player1Score.toString(),
          style: const TextStyle(
            color: Colors.white, 
            fontSize: 200, 
            fontWeight: FontWeight.bold,
            height: 1,
          ),
        ),

        // FLECHA CENTRAL (Estilo idéntico a PantallaControl)
        Container(
           width: 100, 
           height: 60, 
           alignment: Alignment.center,
           decoration: BoxDecoration(
             color: Colors.grey[900], 
             border: Border.all(color: colorBorde, width: 3),
             borderRadius: BorderRadius.circular(50) // Bordes redondeados
           ),
           child: Icon(
             iconoFlecha, 
             color: Colors.white, 
             size: 40, 
             shadows: const [
               Shadow(color: Colors.white, offset: Offset(0.5, 0)), 
               Shadow(color: Colors.white, offset: Offset(-0.5, 0)), 
               Shadow(color: Colors.white, offset: Offset(0, 0.5)), 
               Shadow(color: Colors.white, offset: Offset(0, -0.5))
             ]
           ),
         ),

        // Score 2
        Text(
          player2Score.toString(),
          style: const TextStyle(
            color: Colors.white, 
            fontSize: 200, 
            fontWeight: FontWeight.bold,
            height: 1,
          ),
        ),
      ],
    );
  }
}