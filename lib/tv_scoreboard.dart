import 'package:flutter/material.dart';

class TvScoreboard extends StatelessWidget {
  final String player1Name;
  final String player2Name;
  final int player1Score;
  final int player2Score;
  final int player1Sets;
  final int player2Sets;
  final List<String> setHistory;
  final int? servingPlayer; // 1: Jugador 1 (Izq), 2: Jugador 2 (Der) [Dinámico para la flecha]
  final int? initialServer; // 1: Jugador 1, 2: Jugador 2 [Fijo para la pelota]

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
    required this.initialServer, // <-- Añadido
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
            // --- 1. Encabezado con Nombres y Saque Fijo ---
            _buildHeader(),
            
            const SizedBox(height: 10),
            
            // --- 2. Tabla de Historial ---
            SizedBox(
              height: 110, 
              child: _buildSetHistoryGrid(),
            ),

            const Spacer(),

            // --- 3. Puntaje Grande + FLECHA DE SAQUE DINÁMICA ---
            _buildBigScoreWithArrow(),
            
            const Spacer(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    // Usamos initialServer para que la pelota quede fija en quien arrancó
    bool p1Started = initialServer == 1;
    bool p2Started = initialServer == 2;

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
            if (p1Started) ...[
              const SizedBox(width: 10),
              ClipOval(child: Image.asset('assets/pelota_donic.jpg', width: 28, height: 28, fit: BoxFit.cover)),
            ]
          ],
        ),
        
        const Text("vs", style: TextStyle(color: Colors.grey, fontSize: 18)),
        
        // JUGADOR 2
        Row(
          children: [
            if (p2Started) ...[
              ClipOval(child: Image.asset('assets/pelota_donic.jpg', width: 28, height: 28, fit: BoxFit.cover)),
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

  Widget _buildSetHistoryGrid() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E), 
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        children: [
          Expanded(child: _buildPlayerRow(
            playerIndex: 1, 
            name: player1Name, 
            totalSets: player1Sets,
            baseColor: Colors.blue.shade900,
            highlightColor: Colors.blueAccent.withOpacity(0.4),
            showBottomBorder: true
          )),
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
    List<Widget> setCells = List.generate(5, (index) {
      String scoreText = "";
      Color cellBg = Colors.transparent;
      Color textColor = Colors.white38;
      FontWeight weight = FontWeight.normal;

      if (index < setHistory.length) {
        var parts = setHistory[index].split("-");
        if (parts.length == 2) {
          int s1 = int.parse(parts[0]);
          int s2 = int.parse(parts[1]);
          
          int myScore = playerIndex == 1 ? s1 : s2;
          int opponentScore = playerIndex == 1 ? s2 : s1;
          scoreText = myScore.toString();

          bool IWon = myScore > opponentScore;
          
          if (IWon) {
            cellBg = highlightColor;
            textColor = Colors.white;
            weight = FontWeight.bold;
          }
        }
      }

      return Expanded(
        flex: 1,
        child: Container(
          decoration: BoxDecoration(
            color: cellBg, 
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
          ...setCells,
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
        Text(
          player1Score.toString(),
          style: const TextStyle(color: Colors.white, fontSize: 200, fontWeight: FontWeight.bold, height: 1),
        ),

        Container(
           width: 100, 
           height: 60, 
           alignment: Alignment.center,
           decoration: BoxDecoration(
             color: Colors.grey[900], 
             border: Border.all(color: colorBorde, width: 3),
             borderRadius: BorderRadius.circular(50) 
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

        Text(
          player2Score.toString(),
          style: const TextStyle(color: Colors.white, fontSize: 200, fontWeight: FontWeight.bold, height: 1),
        ),
      ],
    );
  }
}