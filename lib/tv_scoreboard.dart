import 'package:flutter/material.dart';
import 'dart:async'; // Necesario para el Timer en la TV

class TvScoreboard extends StatelessWidget {
  final String player1Name;
  final String player2Name;
  final int player1Score;
  final int player2Score;
  final int player1Sets;
  final int player2Sets;
  final List<String> setHistory;
  final int? servingPlayer; 
  final int? initialServer; 
  final int? timeoutEndMs;
  final int maxSets; // <-- Añadido: Para saber si es a 3 o 5 sets

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
    required this.initialServer,
    required this.timeoutEndMs,
    required this.maxSets, // <-- Añadido
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
      body: Stack(
        children: [
          // CONTENIDO PRINCIPAL (Marcador)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(
                  height: 140, 
                  child: _buildSetHistoryGrid(),
                ),
                const Spacer(),
                _buildBigScoreWithArrow(),
                const Spacer(),
              ],
            ),
          ),

          // CAPA SUPERPUESTA: CRONÓMETRO DE TIEMPO MUERTO
          if (timeoutEndMs != null)
            Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 20.0), // Margen desde abajo
                child: _TvTimerDisplay(endTimeMs: timeoutEndMs!),
              ),
            ),
        ],
      ),
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
            showBottomBorder: true,
            isInitialServer: initialServer == 1,
          )),
          Expanded(child: _buildPlayerRow(
            playerIndex: 2, 
            name: player2Name, 
            totalSets: player2Sets,
            baseColor: Colors.red.shade900,
            highlightColor: Colors.redAccent.withOpacity(0.4),
            showBottomBorder: false,
            isInitialServer: initialServer == 2,
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
    required bool isInitialServer,
  }) {
    List<Widget> setCells = List.generate(5, (index) {
      String scoreText = "";
      Color cellBg = Colors.transparent;
      Color textColor = Colors.white38;
      FontWeight weight = FontWeight.normal;

      // LÓGICA DE GUIONES: Si es a 3 sets y es el 4to o 5to set (index 3 o 4)
      if (maxSets == 3 && index >= 3) {
        scoreText = "-";
        textColor = Colors.white24;
      } 
      // LÓGICA NORMAL DE PUNTOS
      else if (index < setHistory.length) {
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
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      name.toUpperCase(),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 36),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (isInitialServer)
                    Padding(
                      padding: const EdgeInsets.only(left: 10.0),
                      child: ClipOval(child: Image.asset('assets/pelota_donic.jpg', width: 34, height: 34, fit: BoxFit.cover)),
                    )
                ],
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

// ==========================================
// WIDGET INTERNO: CRONÓMETRO DE TV
// ==========================================
class _TvTimerDisplay extends StatefulWidget {
  final int endTimeMs;
  const _TvTimerDisplay({required this.endTimeMs});

  @override
  State<_TvTimerDisplay> createState() => _TvTimerDisplayState();
}

class _TvTimerDisplayState extends State<_TvTimerDisplay> {
  late Timer _timer;
  int _secondsLeft = 0;

  @override
  void initState() {
    super.initState();
    _calculateTime();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _calculateTime();
    });
  }

  @override
  void didUpdateWidget(_TvTimerDisplay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.endTimeMs != widget.endTimeMs) {
      _calculateTime();
    }
  }

  void _calculateTime() {
    int now = DateTime.now().millisecondsSinceEpoch;
    int diff = ((widget.endTimeMs - now) / 1000).ceil();
    if (diff < 0) diff = 0; 
    
    if (mounted) {
      setState(() {
        _secondsLeft = diff;
      });
    }
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    String min = (_secondsLeft ~/ 60).toString().padLeft(2, '0');
    String sec = (_secondsLeft % 60).toString().padLeft(2, '0');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.8),
        border: Border.all(color: Colors.redAccent, width: 4), 
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        "$min:$sec", 
        style: const TextStyle(
          color: Colors.white,
          fontSize: 60,
          fontWeight: FontWeight.bold,
          letterSpacing: 4
        ),
      ),
    );
  }
}