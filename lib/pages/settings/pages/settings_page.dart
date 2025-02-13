import 'package:flutter/material.dart';
import 'package:flutter_material_design_icons/flutter_material_design_icons.dart';
import 'package:get/get.dart';
import 'package:beatconnect_launch_mvp/lib.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Configuración de la app'),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Configuración de localización",
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[500],
                ),
              ),
              _locationSwitch(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _locationSwitch() {
    final ctrl = Get.find<LocationCtrl>();
    return Obx(() {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            selected: ctrl.hasPermissions,
            leading: const Icon(MdiIcons.mapMarker),
            title: const Text('Ubicación'),
            subtitle: const Text('Permitir acceso a la ubicación'),
            trailing: ctrl.permissionsBlocked
                ? TextButton(
                    onPressed: () {
                      ctrl.goToSettings();
                    },
                    child: const Text('Permitir'),
                  )
                : Switch(
                    value: ctrl.hasPermissions,
                    onChanged: (value) {
                      ctrl.requestPermissions();
                    },
                  ),
          ),
        ],
      );
    });
  }
}
