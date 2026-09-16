import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:frontend_tecsys/theme/app_colors.dart';

class Navbar extends StatefulWidget {
  const Navbar({super.key});

  @override
  State<Navbar> createState() => _NavbarState();
}

class _NavbarState extends State<Navbar> {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 70.0,
      child: BottomNavigationBar(
        backgroundColor: AppColors.navBarBackground,
        selectedItemColor: AppColors.textPrimaryColor,
        unselectedItemColor: AppColors.unselectedItemColor,
        type: BottomNavigationBarType.fixed,
        items: [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            label: "Início",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.layers_outlined),
            label: "Estudos"
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.description_outlined),
            label: "Biblioteca"  
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            label: "Perfil"  
          )
        ],
      ),
    );
  }
}
