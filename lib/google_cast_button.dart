import 'package:flutter/material.dart';
import 'package:universal_html/html.dart' as html;
import 'dart:ui_web' as ui; // Si usas Flutter 3.10+ usa este import

class GoogleCastButton extends StatelessWidget {
  const GoogleCastButton({super.key});

  @override
  Widget build(BuildContext context) {
    // Definimos un ID único para este elemento HTML
    const String viewType = 'google-cast-launcher-view';

    // Registramos el elemento HTML <google-cast-launcher>
    // Este es el componente web oficial de Google
    ui.platformViewRegistry.registerViewFactory(viewType, (int viewId) {
      final element = html.Element.tag('google-cast-launcher');
      
      // Estilos para forzar que sea blanco y visible en la AppBar oscura
      element.style.setProperty('--connected-color', 'white');
      element.style.setProperty('--disconnected-color', 'white');
      // Eliminamos fondo gris si lo tuviera
      element.style.backgroundColor = 'transparent';
      
      return element;
    });

    // Devolvemos el widget que incrusta el HTML en Flutter
    return const SizedBox(
      width: 40,
      height: 40,
      child: HtmlElementView(viewType: viewType),
    );
  }
}