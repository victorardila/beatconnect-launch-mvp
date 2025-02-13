import 'package:flutter/material.dart';
import 'package:flutter_material_design_icons/flutter_material_design_icons.dart';
import 'package:get/get.dart';
import 'package:beatconnect_launch_mvp/lib.dart';

class HomeDrawer extends StatelessWidget {
  const HomeDrawer({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: Get.theme.colorScheme.background,
      child: Column(
        children: [
          Expanded(
            child: ListView(
              children: [
                Container(
                  color: Get.theme.colorScheme.onBackground,
                  width: double.infinity,
                  height: 200,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          AppDefaults.titleName,
                          style: TextStyle(
                            fontSize: 30.0,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          "Opciones de configuración",
                          style: TextStyle(
                            fontSize: 12.0,
                            color: Colors.grey[300],
                          ),
                        )
                      ],
                    ),
                  ),
                ),
                Container(
                  color: const Color.fromRGBO(13, 92, 171, 1),
                  child: Center(
                    child: Image.asset("assets/img/publicidad-aguardiente.png",
                        height: 150),
                  ),
                ),
                const SizedBox(
                  height: 20.0,
                ),
                ...accountOptions.keys.map(
                  (e) => GestureDetector(
                    onTapUp: (details) {
                      final onTap =
                          accountOptions[e]!["onTap"] as void Function(
                        TapUpDetails details,
                        BuildContext context,
                      );
                      onTap(details, context);
                    },
                    child: ListTile(
                      leading: Icon(
                        accountOptions[e]!["icon"] as IconData,
                        size: 30,
                      ),
                      title: Text(
                        accountOptions[e]!["label"] as String,
                        style: const TextStyle(
                          fontSize: 15.0,
                        ),
                      ),
                    ),
                  ),
                )
              ],
            ),
          ),
          ListTile(
            onTap: () {
              Get.find<AuthenticationCtrl>().logout();
            },
            leading: const Icon(
              MdiIcons.logout,
              size: 30,
            ),
            title: const Text(
              "Cerrar Sesión",
              style: TextStyle(
                fontSize: 15.0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
